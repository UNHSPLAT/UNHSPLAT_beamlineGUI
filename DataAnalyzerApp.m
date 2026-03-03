classdef DataAnalyzerApp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                 matlab.ui.Figure
        GridLayout              matlab.ui.container.GridLayout
        LeftPanel               matlab.ui.container.Panel
        LoadDataButton          matlab.ui.control.Button
        FilePathLabel           matlab.ui.control.Label
        DataColumnsListBox      matlab.ui.control.ListBox
        DataColumnsLabel        matlab.ui.control.Label
        XAxisDropDown           matlab.ui.control.DropDown
        XAxisLabel              matlab.ui.control.Label
        YAxisListBox            matlab.ui.control.ListBox
        YAxisLabel              matlab.ui.control.Label
        PlotButton              matlab.ui.control.Button
        ClearPlotButton         matlab.ui.control.Button
        ExportFigureButton      matlab.ui.control.Button
        RightPanel              matlab.ui.container.Panel
        UIAxes                  matlab.ui.control.UIAxes
        GridCheckBox            matlab.ui.control.CheckBox
        LogXCheckBox            matlab.ui.control.CheckBox
        LogYCheckBox            matlab.ui.control.CheckBox
        LegendCheckBox          matlab.ui.control.CheckBox
        SmoothingLabel          matlab.ui.control.Label
        SmoothingSlider         matlab.ui.control.Slider
        SmoothingValueLabel     matlab.ui.control.Label
    end

    properties (Access = private)
        DataTable % Loaded data table
        DataFilePath % Path to loaded data file
        PlotHandles % Handles to plot lines
        DefaultDataDir % Default directory for file picker
        SmoothingSpan = 1 % Smoothing window span (1 = no smoothing)
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
                    csvFiles = dir(fullfile(path, '**', 'readings_*.csv'));
                    matFiles = dir(fullfile(path, '**', 'readings_*.mat'));
                    allFiles = [csvFiles; matFiles];
                    
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
                                % Combine tables, matching columns
                                app.DataTable = [app.DataTable; tempTable]; %#ok<AGROW>
                            end
                            fileCount = fileCount + 1;
                        catch ME
                            warning('Failed to load %s: %s', allFiles(i).name, ME.message);
                        end
                    end
                    
                    app.DataFilePath = path;
                    app.FilePathLabel.Text = sprintf('Loaded %d files from folder', fileCount);
                end
                
                % Populate the data columns lists
                if ~isempty(app.DataTable)
                    columnNames = app.DataTable.Properties.VariableNames;
                    app.DataColumnsListBox.Items = columnNames;
                    app.XAxisDropDown.Items = columnNames;
                    app.YAxisListBox.Items = columnNames;
                    
                    % Set default selections
                    if ~isempty(columnNames)
                        app.XAxisDropDown.Value = columnNames{1};
                        if length(columnNames) > 1
                            app.YAxisListBox.Value = columnNames{2};
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
                xData = app.DataTable.(xColumn);
                
                % Handle non-numeric X data
                if ~isnumeric(xData)
                    % Try to convert datetime or duration
                    if isdatetime(xData) || isduration(xData)
                        % Keep as is
                    else
                        % Try to convert to numeric
                        xData = str2double(string(xData));
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
                    yData = app.DataTable.(yColumn);
                    
                    % Handle non-numeric Y data
                    if ~isnumeric(yData)
                        if isdatetime(yData) || isduration(yData)
                            % Keep as is
                        else
                            % Try to convert to numeric
                            yData = str2double(string(yData));
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
                
                % Set labels
                xlabel(app.UIAxes, xColumn, 'Interpreter', 'none');
                ylabel(app.UIAxes, 'Value', 'Interpreter', 'none');
                title(app.UIAxes, 'Data Analysis Plot', 'Interpreter', 'none');
                
                % Apply grid setting
                if app.GridCheckBox.Value
                    grid(app.UIAxes, 'on');
                else
                    grid(app.UIAxes, 'off');
                end
                
                % Apply log scale settings
                if app.LogXCheckBox.Value
                    set(app.UIAxes, 'XScale', 'log');
                else
                    set(app.UIAxes, 'XScale', 'linear');
                end
                
                if app.LogYCheckBox.Value
                    set(app.UIAxes, 'YScale', 'log');
                else
                    set(app.UIAxes, 'YScale', 'linear');
                end
                
                % Show legend if enabled
                if app.LegendCheckBox.Value
                    legend(app.UIAxes, 'Location', 'best', 'Interpreter', 'none');
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

        % Value changed function: GridCheckBox
        function GridCheckBoxValueChanged(app, ~)
            if app.GridCheckBox.Value
                grid(app.UIAxes, 'on');
            else
                grid(app.UIAxes, 'off');
            end
        end

        % Value changed function: LogXCheckBox
        function LogXCheckBoxValueChanged(app, ~)
            if app.LogXCheckBox.Value
                set(app.UIAxes, 'XScale', 'log');
            else
                set(app.UIAxes, 'XScale', 'linear');
            end
        end

        % Value changed function: LogYCheckBox
        function LogYCheckBoxValueChanged(app, ~)
            if app.LogYCheckBox.Value
                set(app.UIAxes, 'YScale', 'log');
            else
                set(app.UIAxes, 'YScale', 'linear');
            end
        end

        % Value changed function: LegendCheckBox
        function LegendCheckBoxValueChanged(app, ~)
            if app.LegendCheckBox.Value && ~isempty(app.PlotHandles)
                legend(app.UIAxes, 'Location', 'best', 'Interpreter', 'none');
            else
                legend(app.UIAxes, 'off');
            end
        end

        % Value changed function: SmoothingSlider
        function SmoothingSliderValueChanged(app, ~)
            app.SmoothingSpan = round(app.SmoothingSlider.Value);
            app.SmoothingValueLabel.Text = sprintf('Window: %d', app.SmoothingSpan);
            
            % Re-plot if data exists
            if ~isempty(app.DataTable) && ~isempty(app.PlotHandles)
                app.ClearPlotButtonPushed();
                app.PlotButtonPushed();
            end
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

            % Create DataColumnsLabel
            app.DataColumnsLabel = uilabel(app.LeftPanel);
            app.DataColumnsLabel.Position = [10 475 230 22];
            app.DataColumnsLabel.Text = 'Available Data Columns:';
            app.DataColumnsLabel.FontWeight = 'bold';

            % Create DataColumnsListBox
            app.DataColumnsListBox = uilistbox(app.LeftPanel);
            app.DataColumnsListBox.Position = [10 380 230 90];
            app.DataColumnsListBox.Multiselect = 'on';

            % Create XAxisLabel
            app.XAxisLabel = uilabel(app.LeftPanel);
            app.XAxisLabel.Position = [10 355 230 22];
            app.XAxisLabel.Text = 'X-Axis:';
            app.XAxisLabel.FontWeight = 'bold';

            % Create XAxisDropDown
            app.XAxisDropDown = uidropdown(app.LeftPanel);
            app.XAxisDropDown.Position = [10 330 230 22];

            % Create YAxisLabel
            app.YAxisLabel = uilabel(app.LeftPanel);
            app.YAxisLabel.Position = [10 305 230 22];
            app.YAxisLabel.Text = 'Y-Axis (multiple selection allowed):';
            app.YAxisLabel.FontWeight = 'bold';

            % Create YAxisListBox
            app.YAxisListBox = uilistbox(app.LeftPanel);
            app.YAxisListBox.Position = [10 190 230 110];
            app.YAxisListBox.Multiselect = 'on';

            % Create GridCheckBox
            app.GridCheckBox = uicheckbox(app.LeftPanel);
            app.GridCheckBox.ValueChangedFcn = createCallbackFcn(app, @GridCheckBoxValueChanged, true);
            app.GridCheckBox.Text = 'Show Grid';
            app.GridCheckBox.Position = [10 180 230 22];
            app.GridCheckBox.Value = true;

            % Create LogXCheckBox
            app.LogXCheckBox = uicheckbox(app.LeftPanel);
            app.LogXCheckBox.ValueChangedFcn = createCallbackFcn(app, @LogXCheckBoxValueChanged, true);
            app.LogXCheckBox.Text = 'Log X Scale';
            app.LogXCheckBox.Position = [10 155 230 22];

            % Create LogYCheckBox
            app.LogYCheckBox = uicheckbox(app.LeftPanel);
            app.LogYCheckBox.ValueChangedFcn = createCallbackFcn(app, @LogYCheckBoxValueChanged, true);
            app.LogYCheckBox.Text = 'Log Y Scale';
            app.LogYCheckBox.Position = [10 130 230 22];

            % Create LegendCheckBox
            app.LegendCheckBox = uicheckbox(app.LeftPanel);
            app.LegendCheckBox.ValueChangedFcn = createCallbackFcn(app, @LegendCheckBoxValueChanged, true);
            app.LegendCheckBox.Text = 'Show Legend';
            app.LegendCheckBox.Position = [10 105 230 22];
            app.LegendCheckBox.Value = true;

            % Create SmoothingLabel
            app.SmoothingLabel = uilabel(app.LeftPanel);
            app.SmoothingLabel.Position = [10 100 230 22];
            app.SmoothingLabel.Text = 'Data Smoothing:';
            app.SmoothingLabel.FontWeight = 'bold';

            % Create SmoothingSlider
            app.SmoothingSlider = uislider(app.LeftPanel);
            app.SmoothingSlider.Limits = [1 100];
            app.SmoothingSlider.Value = 1;
            app.SmoothingSlider.Position = [10 80 170 3];
            app.SmoothingSlider.ValueChangedFcn = createCallbackFcn(app, @SmoothingSliderValueChanged, true);
            app.SmoothingSlider.MajorTicks = [1 25 50 75 100];
            app.SmoothingSlider.MinorTicks = [];

            % Create SmoothingValueLabel
            app.SmoothingValueLabel = uilabel(app.LeftPanel);
            app.SmoothingValueLabel.Position = [185 75 55 22];
            app.SmoothingValueLabel.Text = 'Window: 1';
            app.SmoothingValueLabel.FontSize = 9;

            % Create PlotButton
            app.PlotButton = uibutton(app.LeftPanel, 'push');
            app.PlotButton.ButtonPushedFcn = createCallbackFcn(app, @PlotButtonPushed, true);
            app.PlotButton.Position = [10 40 230 30];
            app.PlotButton.Text = 'Plot Data';
            app.PlotButton.FontSize = 14;
            app.PlotButton.FontWeight = 'bold';
            app.PlotButton.BackgroundColor = [0.4667 0.6745 0.1882];

            % Create ClearPlotButton
            app.ClearPlotButton = uibutton(app.LeftPanel, 'push');
            app.ClearPlotButton.ButtonPushedFcn = createCallbackFcn(app, @ClearPlotButtonPushed, true);
            app.ClearPlotButton.Position = [10 5 110 30];
            app.ClearPlotButton.Text = 'Clear Plot';

            % Create ExportFigureButton
            app.ExportFigureButton = uibutton(app.LeftPanel, 'push');
            app.ExportFigureButton.ButtonPushedFcn = createCallbackFcn(app, @ExportFigureButtonPushed, true);
            app.ExportFigureButton.Position = [130 5 110 30];
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
