classdef SWIPS_GUI < handle
    %SWIPS_GUI - Defines a GUI used to interface with the SWIPS system
    
    properties
        Hardware % Object handle array to contain all hardware connected to SWIPS
        Monitors % Object handle array to contain all monitoring devices
        
        TestSequence double % Unique test sequence identifier number
        TestDate string % Test date derived from TestSequence
        DataDir string % Dat            % Adjust figure size to fit all panels
            % Calculate required figure size based on panels
            
        TestOperator string % Test operator string identifier
        AcquisitionType string % Acquisition type string identifier
        
        hTimer % Handle to timer used to update monitor read timer
        hLogTimer % Handle to timer used to update the status save log
        hHardwareTimer % Handle to timer used to refresh hardware status
        
        hFigure % Handle to GUI figure
        hHVStatusGrp % Handle to status uicontrol group
        hTestGrp % Handle to test control group
        hStatusGrp % Handle to status uicontrol group
        hHWConnStatusGrp % Handle to hardware connection status group
        hHWConnBtn % Handle to hardware connection refresh button
        HWConnStatusListeners % Listeners for hardware connection status
        hMonitorPlt % Handle to monitor plot
        hPosStatusGrp % Handle to position status panel group
        hInstGrp % Handle to instrument monitors panel
        
        hRunBtn % Handle to run test button
        hSequenceText % Handle to test sequence label
        hSequenceEdit % Handle to test sequence field
        hDateText % Handle to test date label
        hDateEdit % Handle to test date field
        
        hOperatorText % Handle to test operator label
        hOperatorEdit % Handle to test operator popupmenu
        OperatorList cell = {'Operator 1', 'Operator 2', 'Operator 3'} % Test operators available for selection
        
        hAcquisitionText % Handle to acquisition type label
        hAcquisitionEdit % Handle to acquisition type popupmenu
        AcquisitionList cell = {'Sweep 1D','Faraday cup sweep 2D','Beamline Monitor'} % Acquisition type string identifier
        Acquisitions = [] % Storage for acquisition instances
        
        hFileMenu % Handle to file top menu dropdown
        hEditMenu % Handle to edit top menu dropdown
        hToolsMenu % Handle to tools top menu dropdown
        hCopyTS % Handle to copy test sequence menu button

    end

    properties (SetObservable)
        LastRead struct % Last readings from the monitor timer
    end
    
    methods
        function obj = SWIPS_GUI
            %SWIPS_GUI Construct an instance of this class
            
            % Generate a test sequence, test date, and data directory
            obj.genTestSequence;

            % Gather and populate required hardware
            obj.gatherHardware;

            % Create GUI components
            obj.createGUI;

            % Create and start status update timer
            % obj.createTimer;
        end

        function newRead = updateReadings(obj,~,~)
            %UPDATEREADINGS Read and update all status reading fields
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
            readings = obj.LastRead;

            if ~exist('fname','var')
                fname = fullfile(obj.DataDir,['readings_',num2str(obj.TestSequence),'.mat']);
            end

            if isfile(fname)
                save(fname,'-struct','readings','-append');
            else
                save(fname,'-struct','readings');
            end
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
                    obj.Hardware.(hwFields{i}).Timer.set('period', str2double(answer{i}));
                end
            end
            obj.restartTimer();
        end

        function setRefreshRate(obj,~,~)
            obj.stopTimer()

            prompt = {'Enter desired Refresh rate [S]'};
            dlgtitle = 'Refresh Rate';
            dims = [1 35];
            definput = {char(string(obj.hTimer.period))};
            answer = inputdlg(prompt,dlgtitle,dims,definput);

            if ~isempty(answer)
                obj.hTimer.set('period',str2double(answer));
            end
            obj.restartTimer();
        end

        function setLogRate(obj,~,~)
            obj.stopTimer()

            prompt = {'Enter desired Log rate [S]'};
            dlgtitle = 'Log Rate';
            dims = [1 35];
            definput = {char(string(obj.hLogTimer.period))};
            answer = inputdlg(prompt,dlgtitle,dims,definput);

            if ~isempty(answer)
                obj.hLogTimer.set('period',str2double(answer));
            end
            obj.restartTimer();
        end

        function createTimer(obj)
            %CREATETIMER Creates timer to periodically update readings
            
            % Create main update timer
            obj.hTimer = timer('Name','readTimer',...
                'Period',2,...
                'ExecutionMode','fixedRate',...
                'TimerFcn',@obj.updateReadings,...
                'ErrorFcn',@obj.restartTimer);
            start(obj.hTimer);

            % Create logging timer
            obj.hLogTimer = timer('Name','logTimer',...
                'Period',5,...
                'ExecutionMode','fixedRate',...
                'TimerFcn',@obj.updateLog,...
                'ErrorFcn',@obj.restartTimer);
            start(obj.hLogTimer);
        end

        function restartTimer(obj,~,~)
            %RESTARTTIMER Restarts timers if error occurs
            
            % Restart main timer
            if strcmp(obj.hTimer.Running,'on')
                stop(obj.hTimer);
            end
            start(obj.hTimer);
            
            % Restart hardware timers
            function restartFunc(x)
                x.restartTimer();
                pause(.1);
            end
            structfun(@restartFunc,obj.Hardware,'UniformOutput',false);

            % Restart log timer
            if strcmp(obj.hLogTimer.Running,'on')
                stop(obj.hLogTimer);
            end
            start(obj.hLogTimer);
        end

        function stopTimer(obj,~,~)
            % Stop main timer
            if strcmp(obj.hTimer.Running,'on')
                stop(obj.hTimer);
            end
            
            % Stop hardware timers
            structfun(@(x)x.stopTimer(),obj.Hardware,'UniformOutput',false);

            % Stop log timer
            if strcmp(obj.hLogTimer.Running,'on')
                stop(obj.hLogTimer);
            end
        end
    end

    methods (Access = private)
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
        
        function gatherHardware(obj)
            % Setup SWIPS hardware and monitors
            obj.Hardware = struct('Opal_Kelly',SWIPS_OK(),...
                                'caen_HVPS1',caen_hvps(),...
                                'newportStage',NewportStageControl('192.168.0.254')...
                            );
            
            % Setup monitors for hardware
            obj.Monitors = setupSWIPSMonitors(obj.Hardware);
        end

        function createGUI(obj)
            %CREATEGUI Create SWIPS GUI components
            
            % Create main figure window
            obj.hFigure = figure('MenuBar','none',...
                'ToolBar','none',...
                'Position',[0,0,1000,600],...
                'NumberTitle','off',...
                'Name','SWIPS Control GUI',...
                'DeleteFcn',@obj.closeGUI);

            % Define common GUI parameters
            ysize = 22;    % Height of each control
            ygap = 6;      % Vertical gap between controls
            xgap = 15;     % Horizontal gap between controls
            xstart = 10;   % Initial X position
            panelGap = 20; % Gap between panels
            leftMargin = 10; % Left margin for panels

            % Column sizes for different elements
            colSize = [130,140,60,60,60];  % [Label, Value, Units, Set Value, Set Button]
            panelWidth = sum(colSize)+xgap*numel(colSize);
            
            % Create HV status panel at the bottom
            ypos = 10;  % Reset Y position for new panel
            obj.hHVStatusGrp = uipanel(obj.hFigure,...
                'Title','HVPS',...
                'FontWeight','bold',...
                'FontSize',12,...
                'Units','pixels',...
                'Position',[leftMargin,30,panelWidth,150]);

            % Create controls for all monitors in the HV group
            monitorFields = fieldnames(obj.Monitors);
            for i = 1:length(monitorFields)
                monitor = obj.Monitors.(monitorFields{i});
                if strcmp(monitor.group, 'HV')
                    guiStatusGrpSet(monitor);
                end
            end

            % Adjust panel height to fit all controls
            obj.hHVStatusGrp.Position(4) = ypos+20;  % Add some padding at the bottom

            % Initialize position for first panel's controls
            ypos = 10;  % Initial Y position within panel
   
            obj.hPosStatusGrp = uipanel(obj.hFigure,...
                'Title','StagePosition',...
                'FontWeight','bold',...
                'FontSize',12,...
                'Units','pixels',...
                'Position',[leftMargin,obj.hHVStatusGrp.Position(4)+obj.hHVStatusGrp.Position(2),panelWidth,100]);
 
            % Create position monitor controls at the bottom
            monitorFields = fieldnames(obj.Monitors);
            for i = 1:length(monitorFields)
                monitor = obj.Monitors.(monitorFields{i});
                if strcmp(monitor.group, 'position')
                    guiStatusGrpSet(monitor, obj.hPosStatusGrp);
                end
            end
            controlsHeight = ypos + 10;  % Height needed for controls
            
            % Create Position status panel with extra height for image
            imageHeight = 400;  % Height for the image
            
            % Create axes for the image above the controls
            ax = axes('Parent', obj.hPosStatusGrp,...
                     'Units', 'pixels',...
                     'Position', [60, controlsHeight, panelWidth-60, imageHeight-30]);  % Add padding
            
            % Load and display the image
            try
                img = imread('SWIPS_Pic.png');
                imshow(img, 'Parent', ax, 'InitialMagnification', 'fit');
                axis(ax, 'off');  % Hide axes
            catch
                text(0.5, 0.5, 'SWIPS_Pic.png not found',...
                     'Parent', ax,...
                     'HorizontalAlignment', 'center');
            end
            
            obj.hPosStatusGrp.Position(4) = controlsHeight+imageHeight;  % Add some padding at the bottom

            ypos = 10;  % Reset Y position for new panel
            obj.hStatusGrp = uipanel(obj.hFigure,...
                'Title','SWIPS',...
                'FontWeight','bold',...
                'FontSize',12,...
                'Units','pixels',...
                'Position',[leftMargin,obj.hPosStatusGrp.Position(4)+obj.hPosStatusGrp.Position(2),...
                panelWidth,100]);
 
            % Create position monitor controls at the bottom
            monitorFields = fieldnames(obj.Monitors);
            for i = 1:length(monitorFields)
                monitor = obj.Monitors.(monitorFields{i});
                if strcmp(monitor.group, 'status')
                    fprintf('sdfdsf');
                    guiStatusGrpSet(monitor, obj.hStatusGrp);
                end
            end

            obj.hStatusGrp.Position(4) = ypos+20;  

         %===================================================================================
            % create column 2

            % Define common GUI parameters
            % Column sizes for different elements
            colSize = [60,200,60,60,60];  % [Label, Value, Units, Set Value, Set Button]
            panel2Width = sum(colSize)+xgap*numel(colSize);
            
            % Define second column position
            rightColStart = leftMargin*2 + panelWidth;
            
            % Create instrument monitor panel in right column
            ypos = 10;  % Reset Y position for new panel
            obj.hInstGrp = uipanel(obj.hFigure,...
                'Title', 'Instrument Monitors',...
                'FontWeight', 'bold',...
                'FontSize', 12,...
                'Units', 'pixels',...
                'Position', [rightColStart, 30, panel2Width, 150]);
                
            % Add instrument monitors
            monitorFields = fieldnames(obj.Monitors);
            for i = 1:length(monitorFields)
                monitor = obj.Monitors.(monitorFields{i});
                if strcmp(monitor.group, 'inst')
                    guiStatusGrpSet(monitor, obj.hInstGrp);
                end
            end
            
            % Adjust panel height
            obj.hInstGrp.Position(4) = ypos + 20;  % Add padding
   
            %===================================================================================
            % Create test control panel in right column
            obj.hTestGrp = uipanel(obj.hFigure,...
                'Title', 'Testing',...
                'FontWeight', 'bold',...
                'FontSize', 12,...
                'Units', 'pixels',...
                'Position', [rightColStart, obj.hInstGrp.Position(4)+obj.hInstGrp.Position(2)+20, 360, 250]);

            % Test panel controls setup
            testYpos = 10;
            testXgap = 15;
            testXstart = 10;
            testYgap = 15;
            testColSize = [140, 140];

            % Run Test button
            obj.hRunBtn = uicontrol(obj.hTestGrp, 'Style', 'pushbutton',...
                'Position', [testXstart, testYpos, testColSize(1), ysize],...
                'String', 'RUN TEST',...
                'FontSize', 16,...
                'FontWeight', 'bold',...
                'HorizontalAlignment', 'center',...
                'Callback', @obj.runTestCallback);
            testYpos = testYpos + ysize + testYgap;

            % Acquisition Type
            obj.hAcquisitionText = uicontrol(obj.hTestGrp, 'Style', 'text',...
                'Position', [testXstart, testYpos, testColSize(1), ysize],...
                'String', 'Acquisition Type:',...
                'FontSize', 12,...
                'FontWeight', 'bold',...
                'HorizontalAlignment', 'right');
            obj.hAcquisitionEdit = uicontrol(obj.hTestGrp, 'Style', 'popupmenu',...
                'Position', [testXstart + testColSize(1) + testXgap, testYpos, testColSize(2), ysize],...
                'String', [{''}, obj.AcquisitionList],...
                'FontSize', 11,...
                'HorizontalAlignment', 'left',...
                'Callback', @obj.acquisitionCallback);
            testYpos = testYpos + ysize + testYgap;

            % Test Sequence
            obj.hSequenceText = uicontrol(obj.hTestGrp, 'Style', 'text',...
                'Position', [testXstart, testYpos, testColSize(1), ysize],...
                'String', 'Test Sequence:',...
                'FontSize', 12,...
                'FontWeight', 'bold',...
                'HorizontalAlignment', 'right');
            obj.hSequenceEdit = uicontrol(obj.hTestGrp, 'Style', 'text',...
                'Position', [testXstart + testColSize(1) + testXgap, testYpos, testColSize(2), ysize],...
                'String', num2str(obj.TestSequence),...
                'FontSize', 12,...
                'FontWeight', 'bold',...
                'HorizontalAlignment', 'left');
            testYpos = testYpos + ysize + testYgap;

            % Test Date
            obj.hDateText = uicontrol(obj.hTestGrp, 'Style', 'text',...
                'Position', [testXstart, testYpos, testColSize(1), ysize],...
                'String', 'Test Date:',...
                'FontSize', 12,...
                'FontWeight', 'bold',...
                'HorizontalAlignment', 'right');
            obj.hDateEdit = uicontrol(obj.hTestGrp, 'Style', 'text',...
                'Position', [testXstart + testColSize(1) + testXgap, testYpos, testColSize(2), ysize],...
                'String', obj.TestDate,...
                'FontSize', 12,...
                'FontWeight', 'bold',...
                'HorizontalAlignment', 'left');
            testYpos = testYpos + ysize + testYgap;

            % Test Operator
            obj.hOperatorText = uicontrol(obj.hTestGrp, 'Style', 'text',...
                'Position', [testXstart, testYpos, testColSize(1), ysize],...
                'String', 'Test Operator:',...
                'FontSize', 12,...
                'FontWeight', 'bold',...
                'HorizontalAlignment', 'right');
            obj.hOperatorEdit = uicontrol(obj.hTestGrp, 'Style', 'popupmenu',...
                'Position', [testXstart + testColSize(1) + testXgap, testYpos, testColSize(2), ysize],...
                'String', [{''}, obj.OperatorList],...
                'FontSize', 11,...
                'HorizontalAlignment', 'left',...
                'Callback', @obj.operatorCallback);
            testYpos = testYpos + ysize + testYgap;

            % Adjust test panel height
            obj.hTestGrp.Position(4) = testYpos + 20;

            % Function to create monitor controls for a channel
            function guiStatusGrpSet(mon, panel)    
                % Use specified panel or default to HV status panel
                if nargin < 2
                    panel = obj.hHVStatusGrp;
                end
                
                % Label column
                colInd = 1;
                xColStart = xstart;
                mon.guiHand.statusGrpText = uicontrol(panel,'Style','text',...
                    'Position',[xColStart,ypos,colSize(colInd),ysize],...
                    'String',sprintf('%s ',mon.textLabel),...
                    'FontWeight','bold',...
                    'FontSize',9,...
                    'HorizontalAlignment','right');

                % Reading value column
                xColStart = sum(colSize(1:colInd))+xgap*(colInd);
                colInd = colInd+1;
                readingTxt = uicontrol(panel,'Style','edit',...
                    'Position',[xColStart,ypos,colSize(colInd),ysize],...
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
                    'Position',[xColStart,ypos,colSize(colInd),ysize],...
                    'String',sprintf('[%s]: ',mon.unit),...
                    'FontSize',9,...
                    'HorizontalAlignment','right');

                % Set value field and button (only for active monitors)
                if mon.active
                    % Set value input field
                    xColStart = sum(colSize(1:colInd))+xgap*(colInd);
                    colInd = colInd+1;
                    mon.guiHand.statusGrpSetField = uicontrol(panel,'Style','edit',...
                        'Position',[xColStart,ypos,colSize(colInd),ysize],...
                        'FontSize',9,...
                        'HorizontalAlignment','right');

                    % Set button
                    xColStart = sum(colSize(1:colInd))+xgap*(colInd);
                    colInd = colInd+1;
                    mon.guiHand.statusGrpSetBtn = uicontrol(panel,'Style','pushbutton',...
                        'Position',[xColStart,ypos,colSize(colInd),ysize],...
                        'String','SET',...
                        'FontWeight','bold',...
                        'FontSize',9,...
                        'HorizontalAlignment','center',...
                        'Callback',@mon.guiSetCallback);
                end
                
                % Update vertical position for next control
                ypos = ypos+ysize+ygap;
            end

            % Adjust figure size to fit all panels
            % Calculate required figure size based on panels
            allPanels = [obj.hPosStatusGrp, obj.hHVStatusGrp, obj.hStatusGrp,obj.hInstGrp];
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
            figureMargin = leftMargin;  % pixels of margin around the edges
            newWidth = maxX + figureMargin;
            newHeight = maxY + figureMargin;
            
            % Get current figure position (to maintain screen location)
            currentPos = obj.hFigure.Position;
            
            % Update figure size while maintaining position
            obj.hFigure.Position = [currentPos(1), currentPos(2), newWidth, newHeight];
            
            % Center the figure on screen
            movegui(obj.hFigure, 'center');
        end        
        
        function closeGUI(obj,~,~)
            %CLOSEGUI Clean up when GUI is closed
            
            % Stop timers
            if strcmp(obj.hTimer.Running,'on')
                stop(obj.hTimer);
            end
            if strcmp(obj.hLogTimer.Running,'on')
                stop(obj.hLogTimer);
            end

            % Clean up hardware
            if isvalid(obj.hMonitorPlt)
                delete(obj.hMonitorPlt.hFigure);
            end
            
            % Delete the object
            obj.delete();
            delete(obj);
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

            % Throw error if test operator not selected
            if isempty(obj.TestOperator)
                errordlg('A test operator must be selected before proceeding!','Don''t be lazy!');
                return
            end

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
