classdef DataAnalyzerApp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                 matlab.ui.Figure
        GridLayout              matlab.ui.container.GridLayout
        LeftPanel               matlab.ui.container.Panel
        LoadDataButton          matlab.ui.control.Button
        FilePathLabel           matlab.ui.control.Label
        XAxisDropDown           matlab.ui.control.DropDown
        XAxisLabel              matlab.ui.control.Label
        YAxisListBox            matlab.ui.control.ListBox
        YAxisLabel              matlab.ui.control.Label
        PlotButton              matlab.ui.control.Button
        ClearPlotButton         matlab.ui.control.Button
        ExportFigureButton      matlab.ui.control.Button
        FilterDataButton        matlab.ui.control.Button
        CalculateButton         matlab.ui.control.Button
        RightPanel              matlab.ui.container.Panel
        UIAxes                  matlab.ui.control.UIAxes
        PlotOptionsButton       matlab.ui.control.Button
        CoordLabel              matlab.ui.control.Label
    end

    properties (Access = private)
        DataTable % Loaded data table
        DataFilePath % Path to loaded data file
        PlotHandles % Handles to plot lines
        DefaultDataDir % Default directory for file picker
        SmoothingSpan = 1 % Smoothing window span (1 = no smoothing)
        ShowGrid = true % Grid display option
        LogXScale = false % Log scale for X axis
        LogYScale = false % Log scale for Y axis
        ShowLegend = true % Legend display option
        OptionsWindow % Handle to plot options window
        XLimits = [] % X axis limits [min max], empty = auto
        YLimits = [] % Y axis limits [min max], empty = auto
        CustomXLabel = '' % Custom X axis label
        CustomYLabel = '' % Custom Y axis label
        CustomTitle = '' % Custom plot title
        FilteredDataTable % Data table after applying filters
        FilterColumn = '' % Column name being filtered
        FilterMin = [] % Minimum value for filter range
        FilterMax = [] % Maximum value for filter range
        FilterActive = false % Whether filter is currently active
    end

    methods (Access = private)

        % Button pushed function: LoadDataButton
        function LoadDataButtonPushed(app, ~)
            % Determine starting directory
            if ~isempty(app.DefaultDataDir) && isfolder(app.DefaultDataDir)
                startDir = app.DefaultDataDir;
            else
                startDir = pwd;
            end
            
            % Ask user if they want to select a file or folder
            choice = questdlg('Load data from:', ...
                'Load Data', ...
                'Single File', ...
                'Folder (All readings_* files)', ...
                'Cancel', ...
                'Single File');
            
            if strcmp(choice, 'Cancel') || isempty(choice)
                return;
            end

            try
                if strcmp(choice, 'Single File')
                    % Open file picker for CSV or MAT files
                    [file, path] = uigetfile({'*.csv;*.mat', 'Data Files (*.csv, *.mat)'; ...
                                              '*.csv', 'CSV Files (*.csv)'; ...
                                              '*.mat', 'MAT Files (*.mat)'; ...
                                              '*.*', 'All Files (*.*)'}, ...
                                             'Select Data File', startDir);
                    
                    if isequal(file, 0)
                        return; % User cancelled
                    end
                    
                    app.DataFilePath = fullfile(path, file);
                    app.DataTable = app.loadSingleFile(app.DataFilePath);
                    app.FilePathLabel.Text = ['Loaded: ' file];
                    
                else % Load all readings files from folder
                    % Open folder picker
                    path = uigetdir(startDir, 'Select Folder with readings_* files');
                    
                    if isequal(path, 0)
                        return; % User cancelled
                    end

                    % Find all readings_*.csv and readings_*.mat files recursively
                    allFiles = dir(fullfile(path, '**', 'readings_*.csv'));
                    
                    if isempty(allFiles)
                        uialert(app.UIFigure, ...
                            'No readings_* files found in selected folder or subfolders', ...
                            'No Files Found', 'Icon', 'warning');
                        return;
                    end
                    
                    % Load and combine all files
                    app.DataTable = [];
                    fileCount = 0;
                    
                    for i = 1:length(allFiles)
                        filePath = fullfile(allFiles(i).folder, allFiles(i).name);
                        try
                            tempTable = app.loadSingleFile(filePath);
                            if isempty(app.DataTable)
                                app.DataTable = tempTable;
                            else
                                % Combine tables, matching columns and filling missing with NaN
                                existingCols = app.DataTable.Properties.VariableNames;
                                newCols = tempTable.Properties.VariableNames;
                                % Add missing columns to app.DataTable
                                for mc = newCols(~ismember(newCols, existingCols))
                                    app.DataTable.(mc{1}) = nan(height(app.DataTable), 1);
                                end
                                % Add missing columns to tempTable
                                for mc = existingCols(~ismember(existingCols, newCols))
                                    tempTable.(mc{1}) = nan(height(tempTable), 1);
                                end
                                % Reorder tempTable to match app.DataTable column order
                                tempTable = tempTable(:, app.DataTable.Properties.VariableNames);
                                app.DataTable = [app.DataTable; tempTable]; %#ok<AGROW>
                            end
                            fileCount = fileCount + 1;
                        catch ME
                            warning('Failed to load %s: %s', allFiles(i).name, ME.message);
                        end
                    end
                    
                    app.DataFilePath = path;
                    app.DefaultDataDir = path;
                    app.FilePathLabel.Text = sprintf('Loaded %d files from folder', fileCount);
                end
                
                % Populate the data columns lists
                if ~isempty(app.DataTable)
                    columnNames = app.DataTable.Properties.VariableNames;
                    app.XAxisDropDown.Items = columnNames;
                    app.YAxisListBox.Items = columnNames;
                    
                    % Set default selections
                    if ~isempty(columnNames)
                        % Prefer 'dateTime' as the default X axis if present
                        if ismember('dateTime', columnNames)
                            app.XAxisDropDown.Value = 'dateTime';
                        else
                            app.XAxisDropDown.Value = columnNames{1};
                        end
                        % Default Y to the first column that isn't the selected X
                        nonXCols = columnNames(~strcmp(columnNames, app.XAxisDropDown.Value));
                        if ~isempty(nonXCols)
                            app.YAxisListBox.Value = nonXCols{1};
                        end
                    end
                    
                    uialert(app.UIFigure, ...
                        sprintf('Successfully loaded %d rows and %d columns', ...
                        height(app.DataTable), width(app.DataTable)), ...
                        'Data Loaded', 'Icon', 'success');
                end
                
            catch ME
                uialert(app.UIFigure, ...
                    ['Error loading data: ' ME.message], ...
                    'Load Error', 'Icon', 'error');
            end
        end

        % Helper function to load a single file
        function dataTable = loadSingleFile(~, filePath)
            % Load the data based on file type
            [~, ~, ext] = fileparts(filePath);
            
            if strcmp(ext, '.csv')
                % Load CSV file
                dataTable = readtable(filePath);
            elseif strcmp(ext, '.mat')
                % Load MAT file
                data = load(filePath);
                fields = fieldnames(data);
                
                % Try to convert structure to table
                if ~isempty(fields)
                    % If it's a single structure, convert it
                    if isstruct(data.(fields{1}))
                        dataTable = struct2table(data.(fields{1}), 'AsArray', true);
                    else
                        % Try to make a table from all variables
                        dataTable = struct2table(data);
                    end
                else
                    error('No data found in MAT file');
                end
            else
                error('Unsupported file format');
            end
        end

        % Helper function for moving average smoothing
        function smoothedData = movingAverage(~, data, windowSize)
            % Simple moving average implementation
            % data: input vector
            % windowSize: number of points in the averaging window
            
            n = length(data);
            smoothedData = zeros(size(data));
            halfWindow = floor(windowSize / 2);
            
            for i = 1:n
                % Calculate window bounds
                startIdx = max(1, i - halfWindow);
                endIdx = min(n, i + halfWindow);
                
                % Compute average over window
                smoothedData(i) = mean(data(startIdx:endIdx));
            end
        end

        % Button pushed function: PlotButton
        function PlotButtonPushed(app, ~)
            if isempty(app.DataTable)
                uialert(app.UIFigure, 'Please load data first', 'No Data', 'Icon', 'warning');
                return;
            end
            
            % Use filtered data if filter is active, otherwise use original data
            if app.FilterActive && ~isempty(app.FilteredDataTable)
                dataToPlot = app.FilteredDataTable;
            else
                dataToPlot = app.DataTable;
            end
            
            xColumn = app.XAxisDropDown.Value;
            yColumns = app.YAxisListBox.Value;
            
            if isempty(xColumn) || isempty(yColumns)
                uialert(app.UIFigure, 'Please select X and Y axes', 'Selection Required', 'Icon', 'warning');
                return;
            end
            
            % Ensure yColumns is a cell array
            if ~iscell(yColumns)
                yColumns = {yColumns};
            end
            
            try
                % Get X data
                xData = dataToPlot.(xColumn);
                
                % Handle non-numeric X data
                if ~isnumeric(xData)
                    % Try to convert datetime or duration
                    if isdatetime(xData) || isduration(xData)
                        % Keep as is
                    else
                        % Try to parse as datetime string first
                        try
                            xData = datetime(xData);
                        catch
                            % Fall back to numeric conversion
                            xData = str2double(string(xData));
                        end
                    end
                end
                
                % Sort data by X values
                [xDataSorted, sortIdx] = sort(xData);
                
                % Plot each Y column
                hold(app.UIAxes, 'on');
                
                if isempty(app.PlotHandles)
                    app.PlotHandles = [];
                end
                
                for i = 1:length(yColumns)
                    yColumn = yColumns{i};
                    yData = dataToPlot.(yColumn);
                    
                    % Handle non-numeric Y data
                    if ~isnumeric(yData)
                        if isdatetime(yData) || isduration(yData)
                            % Keep as is
                        else
                            % Try to parse as datetime string first
                            try
                                yData = datetime(yData);
                            catch
                                % Fall back to numeric conversion
                                yData = str2double(string(yData));
                            end
                        end
                    end
                    
                    % Sort Y data according to X sort order
                    yDataSorted = yData(sortIdx);
                    
                    % Apply smoothing if enabled
                    if app.SmoothingSpan > 1
                        % Use simple moving average
                        yDataSorted = app.movingAverage(yDataSorted, app.SmoothingSpan);
                    end
                    
                    % Plot the data
                    h = plot(app.UIAxes, xDataSorted, yDataSorted, '-o', 'DisplayName', yColumn, ...
                        'LineWidth', 1.5, 'MarkerSize', 4);
                    app.PlotHandles(end+1) = h;
                end
                
                hold(app.UIAxes, 'off');
                
                % Set labels (use custom labels if set)
                if isempty(app.CustomXLabel)
                    xLabelText = xColumn;
                else
                    xLabelText = app.CustomXLabel;
                end
                if isempty(app.CustomYLabel)
                    yLabelText = 'Value';
                else
                    yLabelText = app.CustomYLabel;
                end
                if isempty(app.CustomTitle)
                    titleText = 'Data Analysis Plot';
                else
                    titleText = app.CustomTitle;
                end
                
                hXLabel = xlabel(app.UIAxes, xLabelText, 'Interpreter', 'none');
                hYLabel = ylabel(app.UIAxes, yLabelText, 'Interpreter', 'none');
                hTitle = title(app.UIAxes, titleText, 'Interpreter', 'none');
                
                % Make labels editable on double-click
                app.makeLabelsEditable(hXLabel, hYLabel, hTitle);
                
                % Apply grid setting
                if app.ShowGrid
                    grid(app.UIAxes, 'on');
                else
                    grid(app.UIAxes, 'off');
                end
                
                % Apply log scale settings
                if app.LogXScale
                    set(app.UIAxes, 'XScale', 'log');
                else
                    set(app.UIAxes, 'XScale', 'linear');
                end
                
                if app.LogYScale
                    set(app.UIAxes, 'YScale', 'log');
                else
                    set(app.UIAxes, 'YScale', 'linear');
                end
                
                % Show legend if enabled
                if app.ShowLegend
                    legend(app.UIAxes, 'Location', 'best', 'Interpreter', 'none');
                end
                
                % Apply axis limits if set
                if ~isempty(app.XLimits)
                    xlim(app.UIAxes, app.XLimits);
                end
                if ~isempty(app.YLimits)
                    ylim(app.UIAxes, app.YLimits);
                end
                
            catch ME
                uialert(app.UIFigure, ...
                    ['Error plotting data: ' ME.message], ...
                    'Plot Error', 'Icon', 'error');
            end
        end

        % Button pushed function: ClearPlotButton
        function ClearPlotButtonPushed(app, ~)
            cla(app.UIAxes);
            app.PlotHandles = [];
            legend(app.UIAxes, 'off');
        end

        % Button pushed function: ExportFigureButton
        function ExportFigureButtonPushed(app, ~)
            % Create a new figure with the current plot
            newFig = figure('Name', 'Exported Plot');
            newAxes = copyobj(app.UIAxes, newFig);
            newAxes.Position = [0.1 0.1 0.85 0.85];
            
            % Enable standard figure toolbar
            set(newFig, 'MenuBar', 'figure', 'ToolBar', 'figure');
        end

        % Button pushed function: PlotOptionsButton
        function PlotOptionsButtonPushed(app, ~)
            % Create or bring forward the options window
            if isempty(app.OptionsWindow) || ~isvalid(app.OptionsWindow)
                app.createOptionsWindow();
            else
                figure(app.OptionsWindow);
            end
        end

        % Create plot options window
        function createOptionsWindow(app)
            app.OptionsWindow = uifigure('Name', 'Plot Options', ...
                'Position', [100 100 300 540]);
            
            % Grid checkbox
            gridCheck = uicheckbox(app.OptionsWindow, ...
                'Text', 'Show Grid', ...
                'Position', [20 420 260 22], ...
                'Value', app.ShowGrid);
            gridCheck.ValueChangedFcn = @(src, ~) app.updatePlotOption('Grid', src.Value);
            
            % Log X checkbox
            logXCheck = uicheckbox(app.OptionsWindow, ...
                'Text', 'Log X Scale', ...
                'Position', [20 390 260 22], ...
                'Value', app.LogXScale);
            logXCheck.ValueChangedFcn = @(src, ~) app.updatePlotOption('LogX', src.Value);
            
            % Log Y checkbox
            logYCheck = uicheckbox(app.OptionsWindow, ...
                'Text', 'Log Y Scale', ...
                'Position', [20 360 260 22], ...
                'Value', app.LogYScale);
            logYCheck.ValueChangedFcn = @(src, ~) app.updatePlotOption('LogY', src.Value);
            
            % Legend checkbox
            legendCheck = uicheckbox(app.OptionsWindow, ...
                'Text', 'Show Legend', ...
                'Position', [20 330 260 22], ...
                'Value', app.ShowLegend);
            legendCheck.ValueChangedFcn = @(src, ~) app.updatePlotOption('Legend', src.Value);
            
            % Smoothing label
            uilabel(app.OptionsWindow, ...
                'Text', 'Data Smoothing:', ...
                'Position', [20 290 260 22], ...
                'FontWeight', 'bold');
            
            % Smoothing slider
            smoothSlider = uislider(app.OptionsWindow, ...
                'Position', [20 280 220 3], ...
                'Limits', [1 100], ...
                'Value', app.SmoothingSpan, ...
                'MajorTicks', [1 25 50 75 100]);
            
            % Smoothing value label
            smoothLabel = uilabel(app.OptionsWindow, ...
                'Text', sprintf('Window: %d', app.SmoothingSpan), ...
                'Position', [240 275 50 22], ...
                'FontSize', 9);
            
            smoothSlider.ValueChangedFcn = @(src, ~) app.updateSmoothing(src.Value, smoothLabel);
            
            % X Axis Limits section
            uilabel(app.OptionsWindow, ...
                'Text', 'X Axis Limits:', ...
                'Position', [20 220 260 22], ...
                'FontWeight', 'bold');
            
            uilabel(app.OptionsWindow, ...
                'Text', 'Min:', ...
                'Position', [20 195 40 22]);
            
            xMinEdit = uieditfield(app.OptionsWindow, 'text', ...
                'Position', [60 195 60 22], ...
                'Value', '');
            if ~isempty(app.XLimits)
                xMinEdit.Value = num2str(app.XLimits(1));
            end
            
            uilabel(app.OptionsWindow, ...
                'Text', 'Max:', ...
                'Position', [130 195 40 22]);
            
            xMaxEdit = uieditfield(app.OptionsWindow, 'text', ...
                'Position', [170 195 60 22], ...
                'Value', '');
            if ~isempty(app.XLimits)
                xMaxEdit.Value = num2str(app.XLimits(2));
            end
            
            uibutton(app.OptionsWindow, 'push', ...
                'Text', 'Apply', ...
                'Position', [240 195 40 22], ...
                'ButtonPushedFcn', @(~,~) app.applyXLimits(xMinEdit.Value, xMaxEdit.Value));
            
            % Y Axis Limits section
            uilabel(app.OptionsWindow, ...
                'Text', 'Y Axis Limits:', ...
                'Position', [20 165 260 22], ...
                'FontWeight', 'bold');
            
            uilabel(app.OptionsWindow, ...
                'Text', 'Min:', ...
                'Position', [20 140 40 22]);
            
            yMinEdit = uieditfield(app.OptionsWindow, 'text', ...
                'Position', [60 140 60 22], ...
                'Value', '');
            if ~isempty(app.YLimits)
                yMinEdit.Value = num2str(app.YLimits(1));
            end
            
            uilabel(app.OptionsWindow, ...
                'Text', 'Max:', ...
                'Position', [130 140 40 22]);
            
            yMaxEdit = uieditfield(app.OptionsWindow, 'text', ...
                'Position', [170 140 60 22], ...
                'Value', '');
            if ~isempty(app.YLimits)
                yMaxEdit.Value = num2str(app.YLimits(2));
            end
            
            uibutton(app.OptionsWindow, 'push', ...
                'Text', 'Apply', ...
                'Position', [240 140 40 22], ...
                'ButtonPushedFcn', @(~,~) app.applyYLimits(yMinEdit.Value, yMaxEdit.Value));
            
            % Info label
            uilabel(app.OptionsWindow, ...
                'Text', 'Leave limits empty for auto-scale', ...
                'Position', [20 100 260 22], ...
                'FontSize', 9, ...
                'FontAngle', 'italic', ...
                'HorizontalAlignment', 'center');
            
            % Note about editable labels
            uilabel(app.OptionsWindow, ...
                'Text', 'Double-click labels on plot to edit', ...
                'Position', [20 75 260 22], ...
                'FontSize', 9, ...
                'FontAngle', 'italic', ...
                'HorizontalAlignment', 'center');
            
            % Reset Labels button
            uibutton(app.OptionsWindow, 'push', ...
                'Text', 'Reset Labels to Default', ...
                'Position', [60 45 180 25], ...
                'ButtonPushedFcn', @(~,~) app.resetLabels());
            
            % Close button
            uibutton(app.OptionsWindow, 'push', ...
                'Text', 'Close', ...
                'Position', [100 10 100 30], ...
                'ButtonPushedFcn', @(~,~) close(app.OptionsWindow));
        end

        % Update plot option callback
        function updatePlotOption(app, option, value)
            switch option
                case 'Grid'
                    app.ShowGrid = value;
                    if value
                        grid(app.UIAxes, 'on');
                    else
                        grid(app.UIAxes, 'off');
                    end
                case 'LogX'
                    app.LogXScale = value;
                    if value
                        set(app.UIAxes, 'XScale', 'log');
                    else
                        set(app.UIAxes, 'XScale', 'linear');
                    end
                case 'LogY'
                    app.LogYScale = value;
                    if value
                        set(app.UIAxes, 'YScale', 'log');
                    else
                        set(app.UIAxes, 'YScale', 'linear');
                    end
                case 'Legend'
                    app.ShowLegend = value;
                    if value && ~isempty(app.PlotHandles)
                        legend(app.UIAxes, 'Location', 'best', 'Interpreter', 'none');
                    else
                        legend(app.UIAxes, 'off');
                    end
            end
        end

        % Update smoothing callback
        function updateSmoothing(app, value, label)
            app.SmoothingSpan = round(value);
            label.Text = sprintf('Window: %d', app.SmoothingSpan);
            
            % Re-plot if data exists
            if ~isempty(app.DataTable) && ~isempty(app.PlotHandles)
                app.ClearPlotButtonPushed();
                app.PlotButtonPushed();
            end
        end

        % Apply X limits
        function applyXLimits(app, minStr, maxStr)
            if isempty(minStr) && isempty(maxStr)
                app.XLimits = [];
                if ~isempty(app.PlotHandles)
                    xlim(app.UIAxes, 'auto');
                end
            else
                minVal = str2double(minStr);
                maxVal = str2double(maxStr);
                
                if isnan(minVal) || isnan(maxVal)
                    uialert(app.OptionsWindow, 'Please enter valid numeric values', 'Invalid Input');
                    return;
                end
                
                if minVal >= maxVal
                    uialert(app.OptionsWindow, 'Min value must be less than Max value', 'Invalid Range');
                    return;
                end
                
                app.XLimits = [minVal maxVal];
                if ~isempty(app.PlotHandles)
                    xlim(app.UIAxes, app.XLimits);
                end
            end
        end

        % Apply Y limits
        function applyYLimits(app, minStr, maxStr)
            if isempty(minStr) && isempty(maxStr)
                app.YLimits = [];
                if ~isempty(app.PlotHandles)
                    ylim(app.UIAxes, 'auto');
                end
            else
                minVal = str2double(minStr);
                maxVal = str2double(maxStr);
                
                if isnan(minVal) || isnan(maxVal)
                    uialert(app.OptionsWindow, 'Please enter valid numeric values', 'Invalid Input');
                    return;
                end
                
                if minVal >= maxVal
                    uialert(app.OptionsWindow, 'Min value must be less than Max value', 'Invalid Range');
                    return;
                end
                
                app.YLimits = [minVal maxVal];
                if ~isempty(app.PlotHandles)
                    ylim(app.UIAxes, app.YLimits);
                end
            end
        end

        % Make axis labels and title editable on double-click
        function makeLabelsEditable(app, hXLabel, hYLabel, hTitle)
            % Set ButtonDownFcn for X label
            set(hXLabel, 'ButtonDownFcn', @(src, ~) app.editLabel(src, 'X'));
            
            % Set ButtonDownFcn for Y label
            set(hYLabel, 'ButtonDownFcn', @(src, ~) app.editLabel(src, 'Y'));
            
            % Set ButtonDownFcn for Title
            set(hTitle, 'ButtonDownFcn', @(src, ~) app.editLabel(src, 'Title'));
        end

        % Edit label callback
        function editLabel(app, labelHandle, labelType)
            % Get current text
            currentText = get(labelHandle, 'String');
            
            % Prompt user for new text
            switch labelType
                case 'X'
                    promptText = 'Enter new X-axis label:';
                case 'Y'
                    promptText = 'Enter new Y-axis label:';
                case 'Title'
                    promptText = 'Enter new plot title:';
            end
            
            answer = inputdlg(promptText, ['Edit ' labelType ' Label'], [1 50], {currentText});
            
            if ~isempty(answer)
                newText = answer{1};
                set(labelHandle, 'String', newText);
                
                % Store custom label
                switch labelType
                    case 'X'
                        app.CustomXLabel = newText;
                    case 'Y'
                        app.CustomYLabel = newText;
                    case 'Title'
                        app.CustomTitle = newText;
                end
            end
        end

        % Reset labels to default
        function resetLabels(app)
            app.CustomXLabel = '';
            app.CustomYLabel = '';
            app.CustomTitle = '';
            
            % Re-plot if data exists
            if ~isempty(app.DataTable) && ~isempty(app.PlotHandles)
                app.ClearPlotButtonPushed();
                app.PlotButtonPushed();
            end
        end

        % Button pushed function: FilterDataButton
        function FilterDataButtonPushed(app, ~)
            if isempty(app.DataTable)
                uialert(app.UIFigure, 'Please load data first', 'No Data', 'Icon', 'warning');
                return;
            end
            
            % Create filter dialog
            app.createFilterDialog();
        end

        % Create filter dialog window
        function createFilterDialog(app)
            % Create dialog window
            filterDlg = uifigure('Name', 'Filter Data', ...
                'Position', [300 300 350 330]);
            
            % Quick select from plotted lines section
            uilabel(filterDlg, ...
                'Text', 'Apply Filter to selected plotted lines:', ...
                'Position', [20 290 310 22], ...
                'FontWeight', 'bold');
            
            % Get currently selected Y columns
            yColumns = app.YAxisListBox.Value;
            if ~iscell(yColumns)
                yColumns = {yColumns};
            end
            
            % Create listbox for plotted lines
            plottedLinesBox = uilistbox(filterDlg, ...
                'Items', yColumns, ...
                'Position', [20 245 310 40]);
            
            % Column selection label
            uilabel(filterDlg, ...
                'Text', 'Select Filter Column:', ...
                'Position', [20 215 310 22], ...
                'FontWeight', 'bold');
            
            % Column dropdown
            columnNames = app.DataTable.Properties.VariableNames;
            columnDropdown = uidropdown(filterDlg, ...
                'Items', columnNames, ...
                'Position', [20 185 310 22]);
            
            if ~isempty(app.FilterColumn) && ismember(app.FilterColumn, columnNames)
                columnDropdown.Value = app.FilterColumn;
                % Also select in plotted lines if it's there
                if ismember(app.FilterColumn, yColumns)
                    plottedLinesBox.Value = app.FilterColumn;
                end
            else
                columnDropdown.Value = columnNames{1};
            end
            
            % Sync selections between plotted lines and dropdown
            plottedLinesBox.ValueChangedFcn = @(src, ~) set(columnDropdown, 'Value', src.Value);
            columnDropdown.ValueChangedFcn = @(src, ~) syncPlottedLinesSelection(src.Value, plottedLinesBox, yColumns);
            
            % Range filter section
            uilabel(filterDlg, ...
                'Text', 'Filter Range:', ...
                'Position', [20 145 310 22], ...
                'FontWeight', 'bold');
            
            % Minimum value
            uilabel(filterDlg, ...
                'Text', 'Minimum:', ...
                'Position', [20 115 80 22]);
            
            minEdit = uieditfield(filterDlg, 'text', ...
                'Position', [100 115 100 22], ...
                'Value', '');
            if ~isempty(app.FilterMin)
                minEdit.Value = num2str(app.FilterMin);
            end
            
            % Maximum value
            uilabel(filterDlg, ...
                'Text', 'Maximum:', ...
                'Position', [20 85 80 22]);
            
            maxEdit = uieditfield(filterDlg, 'text', ...
                'Position', [100 85 100 22], ...
                'Value', '');
            if ~isempty(app.FilterMax)
                maxEdit.Value = num2str(app.FilterMax);
            end
            
            % Info label
            uilabel(filterDlg, ...
                'Text', 'Leave empty for no limit on that end', ...
                'Position', [20 55 310 22], ...
                'FontSize', 9, ...
                'FontAngle', 'italic');
            
            % Button panel
            buttonPanel = uipanel(filterDlg, ...
                'Position', [20 20 310 30], ...
                'BorderType', 'none');
            
            % Apply button
            uibutton(buttonPanel, 'push', ...
                'Text', 'Apply Filter', ...
                'Position', [5 2 90 25], ...
                'ButtonPushedFcn', @(~,~) app.applyDataFilter(columnDropdown.Value, minEdit.Value, maxEdit.Value, filterDlg));
            
            % Clear filter button
            uibutton(buttonPanel, 'push', ...
                'Text', 'Clear Filter', ...
                'Position', [105 2 90 25], ...
                'ButtonPushedFcn', @(~,~) app.clearDataFilter(filterDlg));
            
            % Close button
            uibutton(buttonPanel, 'push', ...
                'Text', 'Close', ...
                'Position', [205 2 90 25], ...
                'ButtonPushedFcn', @(~,~) close(filterDlg));
            
            % Nested function to sync plotted lines selection
            function syncPlottedLinesSelection(value, listbox, items)
                if ismember(value, items)
                    listbox.Value = value;
                end
            end
        end

        % Apply data filter
        function applyDataFilter(app, column, minStr, maxStr, dialogHandle)
            try
                % Get the data from selected column
                columnData = app.DataTable.(column);
                
                % Try to convert to numeric if not already
                if ~isnumeric(columnData)
                    if isdatetime(columnData)
                        % For datetime, convert strings to datetime
                        if ~isempty(minStr)
                            minVal = datetime(minStr);
                        else
                            minVal = min(columnData);
                        end
                        if ~isempty(maxStr)
                            maxVal = datetime(maxStr);
                        else
                            maxVal = max(columnData);
                        end
                    else
                        % Try numeric conversion
                        columnData = str2double(string(columnData));
                        if isempty(minStr)
                            minVal = -inf;
                        else
                            minVal = str2double(minStr);
                        end
                        if isempty(maxStr)
                            maxVal = inf;
                        else
                            maxVal = str2double(maxStr);
                        end
                    end
                else
                    % Numeric column
                    if isempty(minStr)
                        minVal = -inf;
                    else
                        minVal = str2double(minStr);
                    end
                    if isempty(maxStr)
                        maxVal = inf;
                    else
                        maxVal = str2double(maxStr);
                    end
                end
                
                % Validate inputs
                if (~isinf(minVal) && isnan(minVal)) || (~isinf(maxVal) && isnan(maxVal))
                    uialert(dialogHandle, 'Please enter valid numeric values', 'Invalid Input');
                    return;
                end
                
                % Apply filter
                filterMask = (columnData >= minVal) & (columnData <= maxVal);
                app.FilteredDataTable = app.DataTable(filterMask, :);
                
                % Store filter settings
                app.FilterColumn = column;
                app.FilterMin = minVal;
                app.FilterMax = maxVal;
                app.FilterActive = true;
                
                % Update UI
                rowsRemoved = height(app.DataTable) - height(app.FilteredDataTable);
                uialert(app.UIFigure, ...
                    sprintf('Filter applied: %d rows remaining (%d removed)', ...
                    height(app.FilteredDataTable), rowsRemoved), ...
                    'Filter Applied', 'Icon', 'success');
                
                % Update file path label to show filter is active
                currentText = app.FilePathLabel.Text;
                if ~contains(currentText, '[FILTERED]')
                    app.FilePathLabel.Text = ['[FILTERED] ' currentText];
                end
                
                % Plot the filtered data (without clearing existing plots)
                app.PlotButtonPushed();
                
            catch ME
                uialert(dialogHandle, ...
                    ['Error applying filter: ' ME.message], ...
                    'Filter Error', 'Icon', 'error');
            end
        end

        % Button pushed function: CalculateButton
        function CalculateButtonPushed(app, ~)
            if isempty(app.DataTable)
                uialert(app.UIFigure, 'Please load data first', 'No Data', 'Icon', 'warning');
                return;
            end
            app.createCalculateWindow();
        end

        % Create statistics/calculations window
        function createCalculateWindow(app)
            % Use filtered data if active, otherwise full data
            if app.FilterActive && ~isempty(app.FilteredDataTable)
                dataToUse = app.FilteredDataTable;
                dataLabel = 'filtered';
            else
                dataToUse = app.DataTable;
                dataLabel = 'full';
            end

            calcFig = uifigure('Name', 'Calculate', 'Position', [200 150 520 480]);

            % ---- Column selector ----
            uilabel(calcFig, 'Text', 'Y column:', ...
                'Position', [15 440 70 22], 'FontWeight', 'bold');

            % Populate with currently selected Y columns first, then all numeric
            ySelected = app.YAxisListBox.Value;
            if ~iscell(ySelected), ySelected = {ySelected}; end
            allCols = app.DataTable.Properties.VariableNames;
            numericCols = allCols(varfun(@isnumeric, dataToUse, 'OutputFormat', 'uniform'));
            % Put selected Y cols first, then remaining numeric cols
            orderedCols = [ySelected, numericCols(~ismember(numericCols, ySelected))];
            if isempty(orderedCols)
                uialert(calcFig, 'No numeric columns found', 'Error', 'Icon', 'error');
                return;
            end

            colDropdown = uidropdown(calcFig, 'Items', orderedCols, ...
                'Position', [90 440 200 22]);

            % X column selector (for peak X location)
            uilabel(calcFig, 'Text', 'X column:', ...
                'Position', [300 440 70 22], 'FontWeight', 'bold');
            xColDropdown = uidropdown(calcFig, 'Items', orderedCols, ...
                'Position', [375 440 130 22]);
            if ~isempty(app.XAxisDropDown.Value) && ismember(app.XAxisDropDown.Value, orderedCols)
                xColDropdown.Value = app.XAxisDropDown.Value;
            end

            % Run button
            uibutton(calcFig, 'push', 'Text', 'Calculate', ...
                'Position', [15 405 100 25], ...
                'ButtonPushedFcn', @(~,~) runCalculations());

            % Copy-to-clipboard button
            copyBtn = uibutton(calcFig, 'push', 'Text', 'Copy to Clipboard', ...
                'Position', [125 405 130 25], ...
                'ButtonPushedFcn', @(~,~) copyResults());
            copyBtn.Enable = 'off';

            % Data label
            dataLbl = uilabel(calcFig, ...
                'Text', sprintf('Dataset: %s data (%d rows)', dataLabel, height(dataToUse)), ...
                'Position', [265 405 245 25], 'FontSize', 9, 'FontAngle', 'italic');

            % Results text area
            resultsArea = uitextarea(calcFig, ...
                'Position', [15 15 490 380], ...
                'Editable', 'off', ...
                'FontName', 'Courier New', ...
                'FontSize', 12, ...
                'Value', {'Select columns and press Calculate.'});

            % ---- Nested calculation function ----
            function runCalculations()
                yCol = colDropdown.Value;
                xCol = xColDropdown.Value;

                % Re-read in case filter changed
                if app.FilterActive && ~isempty(app.FilteredDataTable)
                    d = app.FilteredDataTable;
                    dataLabel = 'filtered';
                else
                    d = app.DataTable;
                    dataLabel = 'full';
                end
                dataLbl.Text = sprintf('Dataset: %s data (%d rows)', dataLabel, height(d));

                yData = d.(yCol);
                xData = d.(xCol);
                if ~isnumeric(yData)
                    yData = str2double(string(yData));
                end
                if ~isnumeric(xData)
                    xData = str2double(string(xData));
                end

                % Remove NaNs
                valid = ~isnan(yData) & ~isnan(xData);
                yData = yData(valid);
                xData = xData(valid);
                n = numel(yData);

                if n == 0
                    resultsArea.Value = {'No valid numeric data in selected column.'};
                    return;
                end

                % --- Compute statistics ---
                yMean   = mean(yData);
                yMedian = median(yData);
                yStd    = std(yData);
                ySEM    = yStd / sqrt(n);
                yMin    = min(yData);
                yMax    = max(yData);
                yRange  = yMax - yMin;

                [~, iMax] = max(yData);
                [~, iMin] = min(yData);
                xAtMax   = xData(iMax);
                xAtMin   = xData(iMin);

                % FWHM (half-max relative to baseline = min)
                halfMax = (yMax + yMin) / 2;
                above   = yData >= halfMax;
                idxAbove = find(above);
                if numel(idxAbove) >= 2
                    fwhm = abs(xData(idxAbove(end)) - xData(idxAbove(1)));
                    fwhmStr = sprintf('%.6g', fwhm);
                else
                    fwhmStr = 'N/A';
                end

                % Integral (trapz)
                [xSorted, si] = sort(xData);
                ySorted = yData(si);
                integVal = trapz(xSorted, ySorted);

                % Centroid
                posY = ySorted - min(ySorted);
                if sum(posY) > 0
                    centroid = sum(xSorted .* posY) / sum(posY);
                    centStr = sprintf('%.6g', centroid);
                else
                    centStr = 'N/A';
                end

                % --- Format output ---
                sep   = repmat('-', 1, 46);
                lines = {
                    sprintf('  Y column : %s', yCol)
                    sprintf('  X column : %s', xCol)
                    sprintf('  N points : %d', n)
                    sep
                    sprintf('  Mean     : %+.6g', yMean)
                    sprintf('  Median   : %+.6g', yMedian)
                    sprintf('  Std Dev  : %.6g',  yStd)
                    sprintf('  SEM      : %.6g',  ySEM)
                    sep
                    sprintf('  Min      : %+.6g  (at X = %.6g)', yMin, xAtMin)
                    sprintf('  Max      : %+.6g  (at X = %.6g)', yMax, xAtMax)
                    sprintf('  Range    : %.6g',  yRange)
                    sep
                    sprintf('  Peak X   : %.6g',  xAtMax)
                    sprintf('  FWHM     : %s',     fwhmStr)
                    sprintf('  Centroid : %s',     centStr)
                    sep
                    sprintf('  Integral (trapz) : %.6g', integVal)
                };
                resultsArea.Value = lines;
                copyBtn.Enable = 'on';
            end

            function copyResults()
                txt = strjoin(resultsArea.Value, newline);
                 clipboard('copy', txt);
            end
        end

        % Update cursor position label when mouse moves over axes
        function updateCursorPosition(app)
            cp = app.UIAxes.CurrentPoint;
            xl = xlim(app.UIAxes);
            yl = ylim(app.UIAxes);
            xIsDatetime = isdatetime(xl(1));
            yIsDatetime = isdatetime(yl(1));
            xFrac = cp(1,1);
            yFrac = cp(1,2);
            % When the axis is datetime, CurrentPoint gives a [0,1] fraction
            % of the axis range; convert to datetime by interpolation.
            if xIsDatetime
                x = num2ruler(cp(1,1), app.UIAxes.XAxis);
                xInRange = x >= xl(1) && x <= xl(2);
            else
                x = xFrac;
                xInRange = x >= xl(1) && x <= xl(2);
            end
            if yIsDatetime
                y = num2ruler(cp(1,2), app.UIAxes.YAxis);
                yInRange = y >= yl(1) && y <= yl(2);
            else
                y = yFrac;
                yInRange = y >= yl(1) && y <= yl(2);
            end

            if xInRange && yInRange
                if xIsDatetime
                    xStr = char(x, 'yyyy-MM-dd HH:mm:ss');
                else
                    xStr = sprintf('%.5g', x);
                end
                if yIsDatetime
                    yStr = char(y, 'yyyy-MM-dd HH:mm:ss');
                else
                    yStr = sprintf('%.5g', y);
                end
                app.CoordLabel.Text = ['x: ' xStr '   y: ' yStr];
            else
                app.CoordLabel.Text = '';
            end
        end

        % Clear data filter
        function clearDataFilter(app, dialogHandle)
            app.FilteredDataTable = [];
            app.FilterColumn = '';
            app.FilterMin = [];
            app.FilterMax = [];
            app.FilterActive = false;
            
            % Update file path label to remove filter indicator
            currentText = app.FilePathLabel.Text;
            app.FilePathLabel.Text = strrep(currentText, '[FILTERED] ', '');
            
            % Plot the unfiltered data (without clearing existing plots)
            app.PlotButtonPushed();
            
            uialert(app.UIFigure, 'Filter cleared', 'Filter Cleared', 'Icon', 'info');
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1000 600];
            app.UIFigure.Name = 'Data Analyzer';

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {'1x', '3x'};
            app.GridLayout.RowHeight = {'1x'};

            % Create LeftPanel
            app.LeftPanel = uipanel(app.GridLayout);
            app.LeftPanel.Title = 'Controls';
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;
            app.LeftPanel.FontWeight = 'bold';
            app.LeftPanel.Scrollable = 'on';
            app.LeftPanel.AutoResizeChildren = 'off';

            % Create LoadDataButton
            app.LoadDataButton = uibutton(app.LeftPanel, 'push');
            app.LoadDataButton.ButtonPushedFcn = createCallbackFcn(app, @LoadDataButtonPushed, true);
            app.LoadDataButton.Position = [10 540 230 30];
            app.LoadDataButton.Text = 'Load Data File';
            app.LoadDataButton.FontSize = 14;
            app.LoadDataButton.FontWeight = 'bold';

            % Create FilePathLabel
            app.FilePathLabel = uilabel(app.LeftPanel);
            app.FilePathLabel.Position = [10 505 230 30];
            app.FilePathLabel.Text = 'No file loaded';
            app.FilePathLabel.FontSize = 10;
            app.FilePathLabel.WordWrap = 'on';

            % Create XAxisLabel
            app.XAxisLabel = uilabel(app.LeftPanel);
            app.XAxisLabel.Position = [10 475 230 22];
            app.XAxisLabel.Text = 'X-Axis:';
            app.XAxisLabel.FontWeight = 'bold';

            % Create XAxisDropDown
            app.XAxisDropDown = uidropdown(app.LeftPanel);
            app.XAxisDropDown.Position = [10 450 230 22];

            % Create YAxisLabel
            app.YAxisLabel = uilabel(app.LeftPanel);
            app.YAxisLabel.Position = [10 420 230 22];
            app.YAxisLabel.Text = 'Y-Axis (multiple selection allowed):';
            app.YAxisLabel.FontWeight = 'bold';

            % Create YAxisListBox
            app.YAxisListBox = uilistbox(app.LeftPanel);
            app.YAxisListBox.Position = [10 290 230 125];
            app.YAxisListBox.Multiselect = 'on';

            % Create PlotOptionsButton
            app.PlotOptionsButton = uibutton(app.LeftPanel, 'push');
            app.PlotOptionsButton.ButtonPushedFcn = createCallbackFcn(app, @PlotOptionsButtonPushed, true);
            app.PlotOptionsButton.Position = [10 250 230 30];
            app.PlotOptionsButton.Text = 'Plot Options';
            app.PlotOptionsButton.FontSize = 12;

            % Create FilterDataButton
            app.FilterDataButton = uibutton(app.LeftPanel, 'push');
            app.FilterDataButton.ButtonPushedFcn = createCallbackFcn(app, @FilterDataButtonPushed, true);
            app.FilterDataButton.Position = [10 210 230 30];
            app.FilterDataButton.Text = 'Filter Data';
            app.FilterDataButton.FontSize = 12;

            % Create PlotButton
            app.PlotButton = uibutton(app.LeftPanel, 'push');
            app.PlotButton.ButtonPushedFcn = createCallbackFcn(app, @PlotButtonPushed, true);
            app.PlotButton.Position = [10 170 230 30];
            app.PlotButton.Text = 'Plot Data';
            app.PlotButton.FontSize = 14;
            app.PlotButton.FontWeight = 'bold';
            app.PlotButton.BackgroundColor = [0.4667 0.6745 0.1882];

            % Create CalculateButton
            app.CalculateButton = uibutton(app.LeftPanel, 'push');
            app.CalculateButton.ButtonPushedFcn = createCallbackFcn(app, @CalculateButtonPushed, true);
            app.CalculateButton.Position = [10 130 230 30];
            app.CalculateButton.Text = 'Calculate';
            app.CalculateButton.FontSize = 12;

            % Create ClearPlotButton
            app.ClearPlotButton = uibutton(app.LeftPanel, 'push');
            app.ClearPlotButton.ButtonPushedFcn = createCallbackFcn(app, @ClearPlotButtonPushed, true);
            app.ClearPlotButton.Position = [10 90 110 30];
            app.ClearPlotButton.Text = 'Clear Plot';

            % Create ExportFigureButton
            app.ExportFigureButton = uibutton(app.LeftPanel, 'push');
            app.ExportFigureButton.ButtonPushedFcn = createCallbackFcn(app, @ExportFigureButtonPushed, true);
            app.ExportFigureButton.Position = [130 90 110 30];
            app.ExportFigureButton.Text = 'Export Figure';

            % Create RightPanel
            app.RightPanel = uipanel(app.GridLayout);
            app.RightPanel.Title = 'Plot';
            app.RightPanel.Layout.Row = 1;
            app.RightPanel.Layout.Column = 2;
            app.RightPanel.FontWeight = 'bold';

            % Create UIAxes
            app.UIAxes = uiaxes(app.RightPanel);
            title(app.UIAxes, 'Data Analysis Plot')
            xlabel(app.UIAxes, 'X')
            ylabel(app.UIAxes, 'Y')
            app.UIAxes.Position = [10 10 690 550];
            grid(app.UIAxes, 'on');

            % Create CoordLabel at bottom-right of plot area
            app.CoordLabel = uilabel(app.RightPanel);
            app.CoordLabel.Position = [490 560 210 20];
            app.CoordLabel.Text = '';
            app.CoordLabel.HorizontalAlignment = 'right';
            app.CoordLabel.FontSize = 10;
            app.CoordLabel.FontName = 'Courier New';
            app.CoordLabel.BackgroundColor = 'none';

            % Wire mouse-motion callback to update coordinate display
            app.UIFigure.WindowButtonMotionFcn = @(~,~) app.updateCursorPosition();

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = DataAnalyzerApp(defaultDataDir)

            % Set default data directory if provided
            if nargin > 0 && ~isempty(defaultDataDir)
                app.DefaultDataDir = defaultDataDir;
            else
                app.DefaultDataDir = '';
            end

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end
