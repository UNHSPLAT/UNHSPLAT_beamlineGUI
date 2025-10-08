classdef (Abstract) labGUI < handle
    %LABGUI - Abstract base class for lab instrument GUI interfaces
    
    properties
        Hardware % Object handle array to contain all connected hardware
        Monitors % Object handle array to contain all monitoring devices
        
        % Test information
        TestSequence double % Unique test sequence identifier number
        TestDate string % Test date derived from TestSequence
        DataDir string % Data directory derived from TestSequence
        DataLoc string % Data directory location
        TestGas string % Test Gas string identifier
        AcquisitionType string % Acquisition type string identifier
        
        % Timers
        hLogTimer % Handle to timer used to update the status save log
        
        % Main GUI elements
        hFigure % Handle to GUI figure
        
        % Tab controls
        hTabGroup % Handle to the main tab group
        hMainControlsTab % Handle to main controls tab
        hMonitoringTab % Handle to monitoring tab
        
        % Test control elements
        hRunBtn % Handle to run test button
        hSequenceEdit % Handle to test sequence field
        hDateEdit % Handle to test date field
        
        % Gas selection
        hGasEdit % Handle to test Gas popupmenu
        
        % Acquisition control
        hAcquisitionEdit % Handle to acquisition type popupmenu
        Acquisitions = [] % Storage for acquisition instances
    end

    properties (SetAccess = protected)
        %linesize
        ysize = 22;    % Height of each control
        figureMargin = 10; % Margin to add around figure when auto-scaling

        GasList cell = {'MTG Gas', 'H', 'He','Ar','Ne'} % Test operators available for selection
        AcquisitionList cell = {'Sweep 1D','Sweep 2D','Faraday cup sweep 2D','Beamline Monitor'} % Acquisition type string identifier
        gasType string = "" % Test Gas string identifier

        % Menus
        hFileMenu % Handle to file top menu dropdown
        hTimerMenu % Handle to Timer top menu dropdown
        hToolsMenu % Handle to tools top menu dropdown

        hCopyTS % Handle to copy test sequence menu button

        % Panels
        hTestPanel % Handle to test control group
    end

    methods (Abstract)
        createLayout(obj) % Create the GUI layout
        createHardware(obj) % Initialize hardware connections
        createMonitors(obj) % Initialize monitors
    end
    
    methods
        function obj = labGUI(guiLab,dataLoc)
            % Construct an instance of this class
            %   Detailed explanation goes here
            if nargin < 2
                obj.DataLoc = fullfile(getenv("USERPROFILE"),"data");
            else
                obj.DataLoc = dataLoc;
            end

            % Create main GUI figure
            obj.hFigure = figure('Name',guiLab,...
                'NumberTitle','off',...
                'MenuBar','none',...
                'Position',[100 100 800 600],...
                'CloseRequestFcn',@obj.closeGUI);
            
            % Generate initial test sequence, date, and data directory
            obj.genTestSequence;
            
            % Create file menu
            obj.hFileMenu = uimenu(obj.hFigure,'Text','File');
            
            % Create copy test sequence menu button
            uimenu(obj.hFileMenu,'Text','Copy Test Sequence',...
                'MenuSelectedFcn',@obj.copyTSCallback);
            
            % Create select data directory menu button
            uimenu(obj.hFileMenu,'Text','Select Data Directory',...
                'MenuSelectedFcn',@obj.selectDataDirCallback);

            uimenu(obj.hFileMenu,'Text','New Test Sequence',...
                'MenuSelectedFcn',@obj.genTestSequence);

            % Create tools menu
            obj.hToolsMenu = uimenu(obj.hFigure,'Text','Tools');
            
            % Add hardware inspection option
            uimenu(obj.hToolsMenu,'Text','Inspect Hardware',...
                'MenuSelectedFcn',@obj.inspectHardwareCallback);
                
            % Add monitor inspection option
            uimenu(obj.hToolsMenu,'Text','Inspect Monitors',...
                'MenuSelectedFcn',@obj.inspectMonitorsCallback);
                
            % Add hardware simulation option
            uimenu(obj.hToolsMenu,'Text','Simulate Hardware',...
                'MenuSelectedFcn',@obj.simHWCallback);
                
            % Create Timer menu and all its menu items
            obj.createTimerMenu();            % Create timer to periodically update readings
            obj.createTimer();

            % Initialize hardware and monitors
            obj.createHardware();
            obj.createMonitors();

            obj.Monitors.dateTime = monitor('readFunc', @(x) datetime(now(), 'ConvertFrom', 'datenum'), ...
                        'textLabel', 'Date Time', ...
                        'unit', 'D-M-Y H:M:S', ...
                        'group','status',...
                        'formatSpec', "%s" ...
                        );
            obj.Monitors.T = monitor('readFunc', @(x) round(now()*1e6), ...
                            'textLabel', 'Time', ...
                            'unit', 'DateNum', ...
                            'group','status',...
                            'formatSpec', "%d" ...
                            );
            obj.Monitors.cmd_cnt = monitor('readFunc', @(x) obj.hLogTimer.TasksExecuted, ...
                            'textLabel', 'Log Count', ...
                            'unit', 'cnt', ...
                            'group','status',...
                            'formatSpec', "%d" ...
                            );

            % Create tab group
            obj.hTabGroup = uitabgroup('Parent', obj.hFigure);

            % Create first tab for existing controls
            obj.hMainControlsTab = uitab('Parent', obj.hTabGroup, 'Title', 'Main Controls');
            
            % Create tabs for monitor groups
            obj.makeMonTabs2();
        end
        
        function stopTimer(obj,~,~)
            % Stop hardware timers
            structfun(@(x)x.stopTimer(),obj.Hardware,'UniformOutput',false);

            % Stop log timer if running
            if strcmp(obj.hLogTimer.Running,'on')
                stop(obj.hLogTimer);
            end
        end
        
        function restartTimer(obj,~,~)
            %RESTARTTIMER Restarts timer if error
            function restartFunc(x)
                x.restartTimer();
                pause(.1);
            end
            structfun(@restartFunc,obj.Hardware,'UniformOutput',false);
           
            % Stop log timer if still running
            if strcmp(obj.hLogTimer.Running,'on')
                stop(obj.hLogTimer);
            end
          
            % Restart log timer
            start(obj.hLogTimer);
        end
        
        %% Data logging and reading
        function newRead = updateReadings(obj,~,~)
            %UPDATEREADINGS update lastread buffer
            if isempty(obj.LastRead)
                obj.LastRead = struct;
            end

            % Read data from hardware
            readList = structfun(@(x)x.read(),obj.Monitors,'UniformOutput',false);

            % Share monitor values with the last reading variable 
            fields = fieldnames(obj.Monitors);
            newRead = struct();
            for i = 1:numel(fields)
                lab = fields{i};
                val = obj.Monitors.(fields{i}).lastRead;
                newRead.(lab) = val;
            end
            obj.LastRead = newRead;
        end

        function updateLog(obj,~,~,fname)
            %UPDATELOG Save current readings to a .mat file
            readings = struct(sprintf('r%s',string(round(now()*1e6))),obj.updateReadings);

            if ~exist('fname','var')
                fname = fullfile(obj.DataDir,['readings_',num2str(obj.TestSequence),'.mat']);
            end
            csvName = strrep(fname,'.mat','.csv');

            if isfile(csvName)
                writetable(struct2table(obj.LastRead), csvName,'WriteMode','append','WriteVariableNames',false);
            else
                writetable(struct2table(obj.LastRead), csvName);
            end
        end

        function garbo = readHardware(obj)
            t1 = now();
            structfun(@(x)x.read(),obj.Hardware,'UniformOutput',false);
            disp(now()-t1);
            disp(structfun(@(x)x.lastRead,obj.Hardware,'UniformOutput',false));
        end

        %% Destructors
        function closeGUI(obj,~,~)
            %CLOSEGUI Clean up when GUI is closed            

            % Delete the object
            obj.delete();
            delete(obj);
        end

        function delete(obj)
            %DELETE Handle class destructor
            
            % Stop timer if running
            obj.stopTimer();

            % delete timers on instruments, log and acq
            obj.destroyTimer();

            % Delete figure
            if isvalid(obj.hFigure)
                delete(obj.hFigure);
            end

            % Clean up monitors and hardware
            % run instrument and monitor delete in try-catch during shutdown
            function try_delete(x)
                try
                    delete(x);
                catch
                    % pass to avoid error during cleanup
                end
            end
            structfun(@(x)try_delete(x),obj.Monitors,'UniformOutput',false);
            structfun(@(x)try_delete(x),obj.Hardware,'UniformOutput',false);
        end

        function destroyTimer(obj)
            % Destroy all timers
            if isvalid(obj.hLogTimer)
                delete(obj.hLogTimer);
            end
            function time2die(tmr)
                if isvalid(tmr)
                    delete(tmr);
                end
            end
            structfun(@(x)time2die(x.Timer),obj.Hardware,'UniformOutput',false);
        end
        
        function genTestSequence(obj)
            %GENTESTSEQUENCE Generates test sequence, date, and data directory
            
            obj.TestSequence = round(now*1e6);
            obj.TestDate = datestr(obj.TestSequence/1e6,'mmm dd, yyyy HH:MM:SS');
            obj.DataDir = fullfile(obj.DataLoc,datestr(obj.TestSequence/1e6,'yyyymmdd'),num2str(obj.TestSequence));
            
            if ~exist(obj.DataDir,'dir')
                mkdir(obj.DataDir);
            end
            
            % Update GUI test sequence and test date fields
            set(obj.hSequenceEdit,'String',num2str(obj.TestSequence));
            set(obj.hDateEdit,'String',obj.TestDate);
        end

        function isRunning = isAcquisition(obj)
            %ISACQUISITIONRUNNING Check if there is an active acquisition running
            isRunning = false;
            if ~isempty(obj.Acquisitions)
                if isvalid(obj.Acquisitions) && isprop(obj.Acquisitions, 'scanTimer') && ...
                   ~isempty(obj.Acquisitions.scanTimer) && isvalid(obj.Acquisitions.scanTimer)
                    isRunning = true;
                end
            end
        end

        function pauseAcquisition(obj, ~, ~)
            %pauseAcquisition Stops the current acquisition if one is running
            if obj.isAcquisition()
                if strcmp(obj.Acquisitions.scanTimer.Running, 'on')
                    try
                        stop(obj.Acquisitions.scanTimer);
                        msgbox('Acquisition stopped successfully', 'Stop Acquisition');
                        obj.restartTimer();
                    catch ME
                        errordlg(['Failed to stop acquisition: ' ME.message], 'Stop Acquisition Error');
                    end
                else
                    msgbox('No acquisition currently running', 'Stop Acquisition');
                end
            else
                msgbox('No acquisition available. Please set up an acquisition first.', 'Stop Acquisition');
            end
        end

        function unPauseAcquisition(obj, ~, ~)
            %unPauseAcquisition Starts the current acquisition if one exists but isn't running
            if obj.isAcquisition()
                if strcmp(obj.Acquisitions.scanTimer.Running, 'off')
                    try
                        obj.stopTimer();
                        start(obj.Acquisitions.scanTimer);
                        msgbox('Acquisition started successfully', 'Start Acquisition');
                    catch ME
                        errordlg(['Failed to start acquisition: ' ME.message], 'Start Acquisition Error');
                    end
                else
                    msgbox('Acquisition is already running', 'Start Acquisition');
                end
            else
                msgbox('No acquisition available to start. Please set up an acquisition first.', 'Start Acquisition');
            end
        end

        function pan_out = guiPanelMake(obj, fig, panx, pany, panName, varargin)
            %GUIPANELMAKE Creates a standardized panel with monitor controls
            %   pan_out = guiPanelMake(obj, fig, panx, pany, panName, monitorGroup)
            %   pan_out = guiPanelMake(obj, fig, panx, pany, panName, monitorGroup, 'Parameter', Value, ...)
            %
            %   Parameters:
            %   obj - The SWIPS_GUI object
            %   fig - Handle to parent figure
            %   panx - X position of panel
            %   pany - Y position of panel
            %   panName - Title of the panel
            %   monitorGroup - Group name for monitors to include
            %
            %   Optional Parameters (Name-Value pairs):
            %   'ColumnSizes' - Array of column widths [default: [100,200,40,60,60]]
            %   'Margin' - Panel margin size [default: 10]
            %   'XGap' - Gap between columns [default: 15]
            %   'YGap' - Gap between rows [default: 6]
            %
            %   Returns:
            %   pan_out - Handle to created panel
            
            % Parse optional parameters
            p = inputParser;
            addParameter(p, 'monitorGroup', 'all'); % Default monitor group
            addParameter(p, 'colSizes', [100,200,40,60,60]); % Default column sizes
            addParameter(p, 'Margin', 10);
            addParameter(p, 'XGap', 15);
            addParameter(p, 'YGap', 6);
            parse(p, varargin{:});
            
            % Get parsed values
            colSize = p.Results.colSizes;
            margin = p.Results.Margin;
            xgap = p.Results.XGap;
            ygap = p.Results.YGap;
            monitorGroup = p.Results.monitorGroup;
            
            % Calculate panel width
            panel2Width = sum(colSize)+xgap*numel(colSize);
            
            % Create instrument monitor panel in right column
            ypos = 10;  % Reset Y position for new panel
            pan_out = uipanel(fig,...
                'Title', panName,...
                'FontWeight', 'bold',...
                'FontSize', 12,...
                'Units', 'pixels',...
                'Position', [panx, pany, panel2Width, 150]);
                
            % Add instrument monitors
            monitorFields = fieldnames(obj.Monitors);
            for i = 1:length(monitorFields)
                monitor = obj.Monitors.(monitorFields{i});
                if strcmp(monitor.group, monitorGroup) || strcmp(monitorGroup, 'all')
                    guiStatusGrpSet(monitor, pan_out);
                end
            end
            
            % Adjust panel height
            pan_out.Position(4) = ypos + 20;  % Add padding
   
            % Function to create monitor controls for a channel
            function guiStatusGrpSet(mon, panel)    
                % Use specified panel or default to HV status panel
                if nargin < 2
                    panel = obj.hHVStatusGrp;
                end
                
                % Label column
                colInd = 1;
                xColStart = margin;
                mon.guiHand.statusGrpText = uicontrol(panel,'Style','text',...
                    'Position',[xColStart,ypos,colSize(colInd),obj.ysize],...
                    'String',sprintf('%s ',mon.textLabel),...
                    'FontWeight','bold',...
                    'FontSize',9,...
                    'HorizontalAlignment','right');

                % Reading value column
                xColStart = sum(colSize(1:colInd))+xgap*(colInd);
                colInd = colInd+1;
                readingTxt = uicontrol(panel,'Style','edit',...
                    'Position',[xColStart,ypos,colSize(colInd),obj.ysize],...
                    'Enable','inactive',...
                    'FontSize',9,...
                    'HorizontalAlignment','right');

                % Create listener for auto-updating the reading
                mon.guiHand.listener = guiListener(mon,'lastRead',...
                    readingTxt,...
                    @(self) set(self.guiHand,'String',sprintf(self.parent.formatSpec,self.parent.lastRead)));

                % Units column
                xColStart = sum(colSize(1:colInd))+xgap*(colInd);
                colInd = colInd+1;
                mon.guiHand.statusGrpSetText = uicontrol(panel,'Style','text',...
                    'Position',[xColStart,ypos,colSize(colInd),obj.ysize],...
                    'String',sprintf('[%s]: ',mon.unit),...
                    'FontSize',9,...
                    'HorizontalAlignment','right');

                % Set value field and button (only for active monitors)
                if mon.active
                    % Set value input field
                    xColStart = sum(colSize(1:colInd))+xgap*(colInd);
                    colInd = colInd+1;
                    mon.guiHand.statusGrpSetField = uicontrol(panel,'Style','edit',...
                        'Position',[xColStart,ypos,colSize(colInd),obj.ysize],...
                        'FontSize',9,...
                        'HorizontalAlignment','right');

                    % Set button
                    xColStart = sum(colSize(1:colInd))+xgap*(colInd);
                    colInd = colInd+1;
                    mon.guiHand.statusGrpSetBtn = uicontrol(panel,'Style','pushbutton',...
                        'Position',[xColStart,ypos,colSize(colInd),obj.ysize],...
                        'String','SET',...
                        'FontWeight','bold',...
                        'FontSize',9,...
                        'HorizontalAlignment','center',...
                        'Callback',@mon.guiSetCallback);
                end
                
                % Update vertical position for next control
                ypos = ypos+obj.ysize+ygap;
            end
        end
    end

    methods (Access = protected)
        function simHWCallback(obj, ~, ~, simFig)
            %SIMHWCALLBACK Opens a window to simulate hardware readings with random values
            
            % Create or refresh the figure
            if nargin < 4 || ~isvalid(simFig)
                simFig = figure('Name', 'Hardware Simulation', ...
                    'NumberTitle', 'off', ...
                    'MenuBar', 'none', ...
                    'ToolBar', 'none', ...
                    'Position', [100 100 600 400]);
            end

            % Get hardware fields
            hwFields = fieldnames(obj.Hardware);
            
            % Prepare data for table
            data = cell(length(hwFields), 3); % 3 columns: Name, Current, Random
            celdata = cell(length(hwFields), 3); % 3 columns: Name, Current, Random
            for i = 1:length(hwFields)
                hw = obj.Hardware.(hwFields{i});
                if isprop(hw, 'lastRead')
                    currentVal = hw.lastRead;
                    % Generate random value within ±20% of current value
                    randomVal = randi(300,length(currentVal),1);
                else
                    currentVal = 'N/A';
                    randomVal = rand();
                end
                data{i,1} = hwFields{i};
                data{i,2} = currentVal;
                data{i,3} = randomVal;

                celdata{i,1} = hwFields{i};
                celdata{i,2} = sprintf('%f,',currentVal);
                celdata{i,3} = sprintf('%f,',randomVal);
                
            end
            
            % Create table
            t = uitable(simFig, ...
                'Data', celdata, ...
                'ColumnName', {'Hardware', 'Current Value', 'Random Value'}, ...
                'RowName', [], ...
                'Position', [20 60 560 320], ...
                'ColumnWidth', {150 150 150}, ...
                'ColumnEditable', [false false true]); % Allow editing random values
            
            % Add Send Values button
            uicontrol(simFig, 'Style', 'pushbutton', ...
                'String', 'Send Values', ...
                'Position', [20 20 100 30], ...
                'Callback', @(~,~)sendValues(obj, data));
            
            % Add Refresh Random button
            uicontrol(simFig, 'Style', 'pushbutton', ...
                'String', 'New Random', ...
                'Position', [140 20 100 30], ...
                'Callback', @(~,~)obj.simHWCallback([],[],simFig));
            
            % Add Close button
            uicontrol(simFig, 'Style', 'pushbutton', ...
                'String', 'Close', ...
                'Position', [260 20 100 30], ...
                'Callback', @(~,~)close(simFig));

            % Helper function to send values to hardware
            function sendValues(obj, data)
                hwFields = data(:,1);
                newValues = data(:,3);
                
                % Update each hardware device
                for idx = 1:length(hwFields)
                    try
                        obj.Hardware.(hwFields{idx}).lastRead = newValues{idx};
                    catch ME
                        warning('Failed to set %s: %s', hwFields{idx}, ME.message);
                    end
                end
            end
        end

        %% Timer management
        function createTimer(obj)
            %CREATETIMER Creates timer to periodically update readings

            % Create logging timer
            obj.hLogTimer = timer('Name','logTimer',...
                'Period',2,...
                'ExecutionMode','fixedDelay',...
                'BusyMode','drop',...
                'TimerFcn',@obj.updateLog,...
                'ErrorFcn',@obj.stopTimer);
        end

        %% Timer menu callbacks
        function setLogRate(obj,~,~)
            obj.stopTimer();

            prompt = {'Enter desired Log rate [S]'};
            dlgtitle = 'Refresh Rate';
            dims = [1 35];
            definput = {char(string(obj.hLogTimer.period))};
            answer = inputdlg(prompt,dlgtitle,dims,definput);

            if ~isempty(answer)
                obj.hLogTimer.set('period',str2double(answer));
            end
            obj.restartTimer();
        end

        function setSampleRate(obj,~,~)
            obj.stopTimer();

            prompt = cellfun(@(x)x.Tag, struct2cell(obj.Hardware), 'UniformOutput', false);
            dlgtitle = 'Instrument Sample Rate';
            dims = [1 45];
            definput = cellfun(@(x)char(string(x.Timer.period)), struct2cell(obj.Hardware), 'UniformOutput', false);
            answer = inputdlg(prompt,dlgtitle,dims,definput);

            if ~isempty(answer)
                hwFields = fieldnames(obj.Hardware);
                for i = 1:numel(answer)
                    if ~isempty(obj.Hardware.(hwFields{i}).Timer)
                    obj.Hardware.(hwFields{i}).Timer.set('period', str2double(answer{i}));
                    end
                end
            end
            obj.restartTimer();
        end

        function viewActiveTimers(obj, ~, ~,timerFig)
            % Create a figure for the timer information
            if nargin < 4 || ~isvalid(timerFig)
                timerFig = figure('Name', 'Active Timers', ...
                    'NumberTitle', 'off', ...
                    'MenuBar', 'none', ...
                    'ToolBar', 'none', ...
                    'Position', [100 100 800 400]);
            end
            % Create a table to display timer information
            data = {};
            headers = {'Index', 'Timer Name', 'Period (s)', 'Running', 'Execution Mode', 'Owner', 'Tasks To Execute', 'Tasks Executed'};
            
            % Get all timers in MATLAB
            allTimers = timerfindall;
            
            % Add all timer info
            for i = 1:length(allTimers)
                t = allTimers(i);
                if isvalid(t)
                    % Get owner info
                    try
                        if isobject(t.UserData) && isvalid(t.UserData)
                            ownerInfo = class(t.UserData);
                        else
                            ownerInfo = 'Unknown';
                        end
                    catch
                        ownerInfo = 'Unknown';
                    end
                    
                    % Get tasks information
                    try
                        tasksToExec = num2str(t.TasksToExecute);
                    catch
                        tasksToExec = 'Inf';
                    end
                    
                    try
                        tasksExec = num2str(t.TasksExecuted);
                    catch
                        tasksExec = '0';
                    end
                    
                    % Add row to data
                    data(end+1,:) = {...
                        i, ...
                        char(t.Name), ...
                        double(t.Period), ...
                        char(t.Running), ...
                        char(t.ExecutionMode), ...
                        ownerInfo, ...
                        tasksToExec, ...
                        tasksExec}; %#ok<AGROW>
                end
            end
            
            
            % Create the uitable
            t = uitable(timerFig, ...
                'Data', data, ...
                'ColumnName', headers, ...
                'RowName', [], ...
                'Position', [20 20 760 360], ...
                'ColumnWidth', {50 120 80 80 100 120 100 100}, ...
                'ColumnEditable', false);
            
            % Enable text wrapping and set column formats
            t.ColumnFormat = {'numeric', 'char', 'numeric', 'char', 'char', 'char', 'char', 'char'};
            
            % Add a refresh button
            uicontrol(timerFig, 'Style', 'pushbutton', ...
                'String', 'Refresh', ...
                'Position', [20 385 100 20], ...
                'Callback', @(~,~) obj.viewActiveTimers([],[],timerFig));
                
            % Make the figure visible and bring it to front
            figure(timerFig);
        end

        function createTimerMenu(obj)
            % Creates the Timer menu and all its menu items
            
            % Create main Timer menu
            obj.hTimerMenu = uimenu(obj.hFigure,'Text','Timer');
            
            uimenu(obj.hTimerMenu,'Text','Restart Timer',...
                'MenuSelectedFcn',@obj.restartTimer);

            uimenu(obj.hTimerMenu,'Text','Disable Timer',...
                'MenuSelectedFcn',@obj.stopTimer);
            
            hSystemTimerMenu = uimenu(obj.hTimerMenu,'Text','System Timer Control');
            % Add timer control options
            uimenu(hSystemTimerMenu,'Text','Set Sample Rate',...
                'MenuSelectedFcn',@obj.setSampleRate);
            
            uimenu(hSystemTimerMenu,'Text','Set Data Log Rate',...
                'MenuSelectedFcn',@obj.setLogRate);
            
            uimenu(hSystemTimerMenu,'Text','View Active Timers',...
                'MenuSelectedFcn',@obj.viewActiveTimers);

            % Add acquisition control menu items
            hAcqMenu = uimenu(obj.hTimerMenu,'Text','Acquisition Timer Control');

            uimenu(hAcqMenu,'Text','Pause Acquisition',...
                'MenuSelectedFcn',@obj.pauseAcquisition);

            uimenu(hAcqMenu,'Text','Un-Pause Acquisition',...
                'MenuSelectedFcn',@obj.unPauseAcquisition);
        end

        %% Menu and Control callbacks
        function copyTSCallback(obj,~,~)
            %COPYTSCALLBACK Copies current test sequence to clipboard
            clipboard('copy',num2str(obj.TestSequence));
        end
        
        function selectDataDirCallback(obj,~,~)
            %SELECTDATADIRCALLBACK Opens a folder selection dialog and updates DataDir
            % Open folder selection dialog
            newDir = uigetdir(obj.DataLoc, 'Select Data Directory');
            
            % If user didn't cancel and selected a folder
            if newDir ~= 0
                % Update the DataDir property
                obj.DataLoc = string(newDir);
                obj.genTestSequence;

            end
        end

        function operatorCallback(obj,src,~)
            %OPERATORCALLBACK Populate test operator obj property with user selected value
            
            % Delete blank popupmenu option
            obj.popupBlankDelete(src);
            
            % Populate obj property with user selection
            if ~strcmp(src.String{src.Value},"")
                obj.TestOperator = src.String{src.Value};
            end
        end

        function acquisitionCallback(obj,src,~)
            %ACQUISITIONCALLBACK Populate acquisition type obj property with user selected value

            % Delete blank popupmenu option
            obj.popupBlankDelete(src);

            % Populate obj property with user selection
            if ~strcmp(src.String{src.Value},"")
                obj.AcquisitionType = src.String{src.Value};
            end
        end

        function runTestCallback(obj,~,~)
            %RUNTESTCALLBACK Check for required user input, generate new test sequence, and execute selected acquisition type


            % % Throw error if gas type not selected
            if isempty(obj.gasType)
                errordlg('A gas type must be selected before proceeding!','Don''t be lazy!');
                return
            end
            % Throw error if test operator not selected
            % if isempty(obj.TestOperator)
            %     errordlg('A test operator must be selected before proceeding!','Don''t be lazy!');
            %     return
            % end

            % Throw error if acquisition type not selected
            if isempty(obj.AcquisitionType)
                errordlg('An acquisition type must be selected before proceeding!','Don''t be lazy!');
                return
            end

            % Generate new test sequence, test date, and data directory
            obj.genTestSequence;

            

            % Find test acquisition class, instantiate, and execute
            acqPath = which(strrep(obj.AcquisitionType,' ',''));
            tokes = regexp(acqPath,'\\','split');
            fcnStr = tokes{end}(1:end-2);
            hFcn = str2func(fcnStr);
            myAcq = hFcn(obj);
            myAcq.runSweep;
            obj.Acquisitions = myAcq; 
        end
        
        function gasCallback(obj,src,~)
            %gasCallback Populate gas type obj property with user selected value

            % Delete blank popupmenu option
            obj.popupBlankDelete(src);

            % Populate obj property with user selection
            if ~strcmp(src.String{src.Value},"")
                obj.gasType = src.String{src.Value};
            end

        end

        function guiPanelTest(obj, position, figure)
            %===================================================================================
            % Create test control panel
            % If figure is not provided, use obj.hFigure
            if nargin < 3
                figure = obj.hFigure;
            end
            
            obj.hTestPanel = uipanel(figure,...
                'Title', 'Testing',...
                'FontWeight', 'bold',...
                'FontSize', 12,...
                'Units', 'pixels',...
                'Position', position);

            % Test panel controls setup
            testYpos = 10;  % Start from bottom of panel with padding
            testXgap = 15;
            testXstart = 10; % Start from left edge of panel with padding
            testYgap = 15;
            testColSize = [140, 140];

            % Run Test button
            obj.hRunBtn = uicontrol(obj.hTestPanel, 'Style', 'pushbutton',...
                'Position', [testXstart, testYpos, testColSize(1), obj.ysize],...
                'String', 'RUN TEST',...
                'FontSize', 16,...
                'FontWeight', 'bold',...
                'HorizontalAlignment', 'center',...
                'Callback', @obj.runTestCallback);
            testYpos = testYpos + obj.ysize + testYgap;

            % Acquisition Type
            uicontrol(obj.hTestPanel, 'Style', 'text',...
                'Position', [testXstart, testYpos, testColSize(1), obj.ysize],...
                'String', 'Acquisition Type:',...
                'FontSize', 12,...
                'FontWeight', 'bold',...
                'HorizontalAlignment', 'right');
            obj.hAcquisitionEdit = uicontrol(obj.hTestPanel, 'Style', 'popupmenu',...
                'Position', [testXstart + testColSize(1) + testXgap, testYpos, testColSize(2), obj.ysize],...
                'String', [{''}, obj.AcquisitionList],...
                'FontSize', 11,...
                'HorizontalAlignment', 'left',...
                'Callback', @obj.acquisitionCallback);
            testYpos = testYpos + obj.ysize + testYgap;

            % Test Sequence
            uicontrol(obj.hTestPanel, 'Style', 'text',...
                'Position', [testXstart, testYpos, testColSize(1), obj.ysize],...
                'String', 'Test Sequence:',...
                'FontSize', 12,...
                'FontWeight', 'bold',...
                'HorizontalAlignment', 'right');
            obj.hSequenceEdit = uicontrol(obj.hTestPanel, 'Style', 'text',...
                'Position', [testXstart + testColSize(1) + testXgap, testYpos, testColSize(2), obj.ysize],...
                'String', num2str(obj.TestSequence),...
                'FontSize', 12,...
                'FontWeight', 'bold',...
                'HorizontalAlignment', 'left');
            testYpos = testYpos + obj.ysize + testYgap;

            % Test Date
            uicontrol(obj.hTestPanel, 'Style', 'text',...
                'Position', [testXstart, testYpos, testColSize(1), obj.ysize],...
                'String', 'Test Date:',...
                'FontSize', 12,...
                'FontWeight', 'bold',...
                'HorizontalAlignment', 'right');
            obj.hDateEdit = uicontrol(obj.hTestPanel, 'Style', 'text',...
                'Position', [testXstart + testColSize(1) + testXgap, testYpos, testColSize(2), obj.ysize],...
                'String', obj.TestDate,...
                'FontSize', 12,...
                'FontWeight', 'bold',...
                'HorizontalAlignment', 'left');
            testYpos = testYpos + obj.ysize + testYgap;

            % Test Gas
            uicontrol(obj.hTestPanel, 'Style', 'text',...
                'Position', [testXstart, testYpos, testColSize(1), obj.ysize],...
                'String', 'Test Gas:',...
                'FontSize', 12,...
                'FontWeight', 'bold',...
                'HorizontalAlignment', 'right');
            obj.hGasEdit = uicontrol(obj.hTestPanel, 'Style', 'popupmenu',...
                'Position', [testXstart + testColSize(1) + testXgap, testYpos, testColSize(2), obj.ysize],...
                'String', [{''}, obj.GasList],...
                'FontSize', 11,...
                'HorizontalAlignment', 'left',...
                'Callback', @obj.gasCallback);
            testYpos = testYpos + obj.ysize + testYgap;
            % Adjust test panel height
            obj.hTestPanel.Position(4) = testYpos + 20;
        end

        function guiAutoScale(obj,figure)
            % Adjust figure size to fit all panels
            % Calculate required figure size based on panels
            allPanels = findall(figure,'Type','uipanel');

            maxX = 0;
            maxY = 0;
            
            % Find the rightmost and topmost points of all panels
            for i = 1:length(allPanels)
                panel = allPanels(i);
                panelRight = panel.Position(1) + panel.Position(3);
                panelTop = panel.Position(2) + panel.Position(4);
                maxX = max(maxX, panelRight);
                maxY = max(maxY, panelTop);
            end
            
            % Add margins for the figure size
            newWidth = maxX + obj.figureMargin;
            newHeight = maxY + obj.figureMargin;
            
            % Get current figure position (to maintain screen location)
            currentPos = figure.Position;
            

            % Update figure size while maintaining position
            figure.Position = [currentPos(1), currentPos(2), newWidth, newHeight];

            % Center the figure on screen
            movegui(figure, 'center');
        end

        function inspectHardwareCallback(obj, ~, ~,hwFig)
            if nargin < 4 || ~isvalid(hwFig)
                % Create a figure for the hardware information
                hwFig = figure('Name', 'Hardware Inspector', ...
                    'NumberTitle', 'off', ...
                    'MenuBar', 'none', ...
                    'ToolBar', 'none', ...
                    'Position', [100 100 800 400]);
            end
            % Get hardware fields
            hwFields = fieldnames(obj.Hardware);
            
            % Create a table to display hardware information
            data = {};
            headers = {'Hardware Name', 'Type', 'Model Number', 'Address', 'Connected', 'Timer Running','Read Delay', 'Other Properties'};
            
            % Populate data for each hardware component
            for i = 1:length(hwFields)
                hw = obj.Hardware.(hwFields{i});
                propStr = '';
                
                % Get the standard properties with error handling
                try
                    hwType = char(hw.Type);
                catch
                    hwType = 'N/A';
                end
                
                try
                    modelNum = char(string(hw.ModelNum));
                catch
                    modelNum = 'N/A';
                end

                try
                    address = char(string(hw.Address));
                catch
                    address = 'N/A';
                end
                
                try
                    if hw.Connected
                        connected = 'true';
                    else   
                        connected = 'false';
                    end
                catch
                    connected = 'N/A';
                end
                
                try
                    if ~isempty(hw.Timer) && isvalid(hw.Timer)
                        timerRunning = char(hw.Timer.Running);
                    else
                        timerRunning = 'No Timer';
                    end
                catch
                    timerRunning = 'N/A';
                end

                try
                    read_delay = char(string(hw.read_delay));
                catch
                    read_delay = 'N/A';
                end
                
                % Get remaining properties
                props = properties(hw);
                standardProps = {'Type', 'ModelNum', 'Address', 'Connected', 'Timer'};
                
                % Add remaining properties to propStr
                for j = 1:length(props)
                    if ~any(strcmp(props{j}, standardProps))
                        try
                            propVal = hw.(props{j});
                            if isnumeric(propVal) || islogical(propVal) || ischar(propVal) || isstring(propVal)
                                propStr = [propStr, props{j}, ': ', char(string(propVal)), '| '];
                            end
                        catch
                            % Skip properties that can't be accessed or converted
                        end
                    end
                end
                
                % Add row to data
                data(end+1,:) = {hwFields{i}, hwType, modelNum, address, connected, timerRunning, read_delay, propStr}; %#ok<AGROW>
            end
            
            % Create the uitable with hardware information
            uitable(hwFig, ...
                'Data', data, ...
                'ColumnName', headers, ...
                'RowName', [], ...
                'Position', [20 20 860 360], ...
                'ColumnWidth', {120 100 100 100 80 100 80 240}, ...
                'ColumnEditable', false);

            % Add a refresh button
            uicontrol(hwFig, 'Style', 'pushbutton', ...
                'String', 'Refresh', ...
                'Position', [20 385 100 20], ...
                'Callback', @(~,~) obj.inspectHardwareCallback([],[],hwFig));
            
            % Make the figure visible and bring it to front
            figure(hwFig);
        end

        function inspectMonitorsCallback(obj, ~, ~,monFig)
            
            if nargin < 4 || ~isvalid(monFig)
                % Create a figure for the monitor information
                monFig = figure('Name', 'Monitor Inspector', ...
                    'NumberTitle', 'off', ...
                    'MenuBar', 'none', ...
                    'ToolBar', 'none', ...
                    'Position', [100 100 900 400]);
            end
            % Get monitor fields
            monFields = fieldnames(obj.Monitors);
            
            % Create table to display monitor information
            data = {};
            headers = {'Monitor Name', 'Group', 'Parent HW', 'Read Function', 'Last Read', ...
                 'Last Read Time', 'Controllable'};
            
            % Populate data for each monitor
            for i = 1:length(monFields)
                mon = obj.Monitors.(monFields{i});
                
                % Get the last read time in a readable format
                try
                    lastReadTime = datestr(mon.lastReadTime, 'HH:MM:SS');
                catch
                    lastReadTime = 'N/A';
                end
                
                % Format the last read value
                try
                    lastRead = char(sprintf(mon.formatSpec,mon.lastRead));
                    % if isnumeric(mon.lastRead)
                    %     lastRead = num2str(mon.lastRead, '%.4g');
                    % else
                    %     lastRead = char(string(mon.lastRead));
                    % end
                catch
                    lastRead = 'N/A';
                end
                
                % Get the hardware name
                try
                    if isprop(mon, 'parent') && ~isempty(mon.parent)
                        hwName = char(mon.parent.Tag);
                    else
                        hwName = 'None';
                    end
                catch
                    hwName = 'N/A';
                end
                
                % Get read function info
                try
                    if isa(mon.readFunc, 'function_handle')
                        readFunc = func2str(mon.readFunc);
                    else
                        readFunc = 'None';
                    end
                catch
                    readFunc = 'N/A';
                end
                
                % Get active status
                try
                    if mon.active
                        activeStatus = 'Yes';
                    else
                        activeStatus = 'No';
                    end
                catch
                    activeStatus = 'N/A';
                end
                
                % Add row to data
                data(end+1,:) = {...
                    monFields{i}, ...
                    char(string(mon.group)), ...
                    hwName, ...
                    readFunc, ...
                    lastRead, ...
                    lastReadTime, ...
                    activeStatus}; %#ok<AGROW>
            end
            
            % Sort data by group and then by monitor name
            if ~isempty(data)
                % Convert cell array to table for easier sorting
                dataTable = cell2table(data, 'VariableNames', ...
                    {'MonitorName', 'Group', 'Hardware', 'ReadFunction', 'LastRead', 'LastReadTime', 'Active'});
                % Sort by Group first, then by MonitorName
                dataTable = sortrows(dataTable, {'Group', 'MonitorName'});
                % Convert back to cell array
                data = table2cell(dataTable);
            end
            
            % Create the uitable with monitor information
            t = uitable(monFig, ...
                'Data', data, ...
                'ColumnName', headers, ...
                'RowName', [], ...
                'Position', [20 20 860 360], ...
                'ColumnWidth', {120 80 120 150 100 100 100}, ...
                'ColumnEditable', false);
                
            % Enable text wrapping
            t.ColumnFormat = {'char', 'char', 'char', 'char', 'char', 'char', 'char'};
            
            % Add a refresh button
            uicontrol(monFig, 'Style', 'pushbutton', ...
                'String', 'Refresh', ...
                'Position', [20 385 100 20], ...
                'Callback', @(~,~) obj.inspectMonitorsCallback([],[],monFig));
                
            % Make the figure visible and bring it to front
            figure(monFig);
        end
        

    end

    methods (Static, Access = private)
        

        function popupBlankDelete(src)
            %POPUPBLANKDELETE Deletes blank option from popupmenu
            
            if isempty(src.String{1})
                if src.Value ~= 1
                    oldVal = src.Value;
                    src.String = src.String(2:end);
                    src.Value = oldVal-1;
                else
                    return
                end
            end
        end
        
    end
    
    methods (Access = protected)
        function makeMonTabs2(obj)
            %MAKEMONTABS Creates tabs for each unique monitor group
            %   This function creates tabs for each unique monitor group in the 
            %   monitors collection, excluding the "status" group. Each tab will
            %   contain a panel showing the monitors for that group.
            
            
            % Find unique groups (excluding 'status')
            groups = unique(structfun(@(x)x.group,obj.Monitors));
            
            function MonPlt(mon,obj,groupTab)
                grp = mon.group;
                if strcmp(grp,groups{i})
                    monitorPlot(obj,groupTab,'T',mon.Tag);
                end
            end
            % Create tab for each group
            for i = 1:length(groups)
                if ~strcmp(groups{i}, 'status')
                    % Create tab
                    groupTab = uitab('Parent', obj.hTabGroup, ...
                                'Title', ['mon', upper(groups{i})]);
                    structfun(@(x)MonPlt(x,obj,groupTab),obj.Monitors);
                end
            end
            
            % Auto-scale figure after adding tabs
            obj.guiAutoScale(obj.hFigure);
        end

    end
end
