classdef (Abstract) labGUI < handle
    %LABGUI - Abstract base class for lab instrument GUI interfaces
    
    properties
        Hardware % Object handle array to contain all connected hardware
        Monitors % Object handle array to contain all monitoring devices
        
        % Test information
        TestSequence double % Unique test sequence identifier number
        TestDate string % Test date derived from TestSequence
        DataDir string % Data directory derived from TestSequence
        TestGas string % Test Gas string identifier
        AcquisitionType string % Acquisition type string identifier
        
        % Timers
        hLogTimer % Handle to timer used to update the status save log
        
        % Main GUI elements
        hFigure % Handle to GUI figure
        
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
        function obj = labGUI(guiLab)
            % Construct an instance of this class
            %   Detailed explanation goes here
            
            % Create main GUI figure
            obj.hFigure = figure('Name',guiLab,...
                'NumberTitle','off',...
                'MenuBar','none',...
                'ToolBar','none',...
                'Position',[100 100 800 600],...
                'CloseRequestFcn',@obj.closeGUI);
            
            % Generate initial test sequence, date, and data directory
            obj.genTestSequence;
            
            % Create file menu
            obj.hFileMenu = uimenu(obj.hFigure,'Text','File');
            
            % Create copy test sequence menu button
            uimenu(obj.hFileMenu,'Text','Copy Test Sequence',...
                'MenuSelectedFcn',@obj.copyTSCallback);

            % Create Timer menu and all its menu items
            obj.createTimerMenu();
            
            % Create timer to periodically update readings
            obj.createTimer();
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
            readings = obj.updateReadings;

            if ~exist('fname','var')
                fname = fullfile(obj.DataDir,['readings_',num2str(obj.TestSequence),'.mat']);
            end

            if isfile(fname)
                save(fname,'-struct','readings','-append');
            else
                save(fname,'-struct','readings');
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
            
            
            if strcmp(obj.hLogTimer.Running,'on')
                stop(obj.hLogTimer);
            end

            
            % Delete the object
            obj.delete();
            delete(obj);
        end

        function delete(obj)
            %DELETE Handle class destructor
            
            % Stop timer if running
            obj.stopTimer();

            % Delete figure
            if isvalid(obj.hFigure)
                delete(obj.hFigure);
            end

            % Clean up monitors and hardware
            structfun(@(x)delete(x),obj.Monitors,'UniformOutput',false);
            structfun(@(x)delete(x),obj.Hardware,'UniformOutput',false);
        end
        
        
    end

    methods (Access = protected)

        function genTestSequence(obj)
            %GENTESTSEQUENCE Generates test sequence, date, and data directory
            
            obj.TestSequence = round(now*1e6);
            obj.TestDate = datestr(obj.TestSequence/1e6,'mmm dd, yyyy HH:MM:SS');
            if ~isempty(obj.AcquisitionType)
                obj.DataDir = fullfile(getenv("USERPROFILE"),"data",strrep(obj.AcquisitionType,' ',''),num2str(obj.TestSequence));
            else
                obj.DataDir = fullfile(getenv("USERPROFILE"),"data","General",num2str(obj.TestSequence));
            end
            if ~exist(obj.DataDir,'dir')
                mkdir(obj.DataDir);
            end
        end

        %% Timer management
        function createTimer(obj)
            %CREATETIMER Creates timer to periodically update readings

            % Create logging timer
            obj.hLogTimer = timer('Name','logTimer',...
                'Period',5,...
                'ExecutionMode','fixedRate',...
                'TimerFcn',@obj.updateLog,...
                'ErrorFcn',@obj.restartTimer);
        end

        %% Timer menu callbacks
        function setLogRate(obj,~,~)
            obj.stopTimer()

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
            obj.stopTimer()

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

        function viewActiveTimers(obj, ~, ~)
            % Create a figure for the timer information
            timerFig = figure('Name', 'Active Timers', ...
                'NumberTitle', 'off', ...
                'MenuBar', 'none', ...
                'ToolBar', 'none', ...
                'Position', [100 100 500 400]);
            
            % Create a table to display timer information
            data = {};
            headers = {'Timer Name', 'Period (s)', 'Running', 'Execution Mode'};
            
            % Add hardware timers info
            hwFields = fieldnames(obj.Hardware);
            for i = 1:length(hwFields)
                hw = obj.Hardware.(hwFields{i});
                if isprop(hw, 'Timer') && ~isempty(hw.Timer)
                    data(end+1,:) = {char(hw.Timer.Name), ...
                        double(hw.Timer.Period), ...
                        char(hw.Timer.Running), ...
                        char(hw.Timer.ExecutionMode)}; %#ok<AGROW>
                end
            end
            
            % Add log timer info
            if ~isempty(obj.hLogTimer)
                data(end+1,:) = {char(obj.hLogTimer.Name), ...
                    double(obj.hLogTimer.Period), ...
                    char(obj.hLogTimer.Running), ...
                    char(obj.hLogTimer.ExecutionMode)}; %#ok<AGROW>
            end
            
            % Create the uitable
            uitable(timerFig, ...
                'Data', data, ...
                'ColumnName', headers, ...
                'RowName', [], ...
                'Position', [20 20 460 360], ...
                'ColumnWidth', {120 80 80 120});
        end

        function createTimerMenu(obj)
            % Creates the Timer menu and all its menu items
            
            % Create main Timer menu
            obj.hTimerMenu = uimenu(obj.hFigure,'Text','Timer');
            
            % Add timer control options
            uimenu(obj.hTimerMenu,'Text','Set Sample Rate',...
                'MenuSelectedFcn',@obj.setSampleRate);
            
            uimenu(obj.hTimerMenu,'Text','Set Data Log Rate',...
                'MenuSelectedFcn',@obj.setLogRate);
            
            uimenu(obj.hTimerMenu,'Text','Disable Timer',...
                'MenuSelectedFcn',@obj.stopTimer);
            
            uimenu(obj.hTimerMenu,'Text','Restart Timer',...
                'MenuSelectedFcn',@obj.restartTimer);
            
            uimenu(obj.hTimerMenu,'Text','View Active Timers',...
                'MenuSelectedFcn',@obj.viewActiveTimers);
        end

        %% Menu and Control callbacks
        function copyTSCallback(obj,~,~)
            %COPYTSCALLBACK Copies current test sequence to clipboard
            clipboard('copy',num2str(obj.TestSequence));
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

            % Update GUI test sequence and test date fields
            set(obj.hSequenceEdit,'String',num2str(obj.TestSequence));
            set(obj.hDateEdit,'String',obj.TestDate);

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

        function guiPanelTest(obj,position)
            %===================================================================================
            % Create test control panel
            obj.hTestPanel = uipanel(obj.hFigure,...
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
end
