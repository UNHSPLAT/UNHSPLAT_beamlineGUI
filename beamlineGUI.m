classdef beamlineGUI < handle
    %BEAMLINEGUI - Defines a GUI used to interface with the Peabody Scientific beamline in lab 145
    
    properties
        Hardware % Object handle array to contain all hardware connected to beamline PC
        Monitors % Object handle array to contain all hardware connected to beamline PC
        TestSequence double % Unique test sequence identifier number
        TestDate string % Test date derived from TestSequence
        DataDir string % Data directory derived from TestSequence
        TestOperator string % Test operator string identifier
        GasType string % Gas type string identifier
        AcquisitionType string % Acquisition type string identifier
        hTimer % Handle to timer used to update beamline status read fields
        
        hFigure % Handle to GUI figure
        hStatusGrp % Handle to beamline status uicontrol group
        hTestGrp %
        hHWConnStatusGrp%
        hHWConnBtn%
        HWConnStatusListeners %
        hMonitorPlt% Handle to monitor plot generated at startup

        hFileMenu % Handle to file top menu dropdown
        hEditMenu % Handle to edit top menu dropdown
        hCopyTS % Handle to copy test sequence menu button
        hSequenceText % Handle to test sequence label
        hSequenceEdit % Handle to test sequence field
        hDateText % Handle to test date label
        hDateEdit % Handle to test date field
        
        hOperatorText % Handle to test operator label
        hOperatorEdit % Handle to test operator popupmenu
        OperatorList cell = {'Isabella Householder', 'Amanda Wester','Jonathan Bower','Arlo Johnson', 'Daniel Abel','Skylar Vogler'} % Test operators available for selection
        
        hGasText % Handle to gas type label
        hGasEdit % Handle to gas type popupmenu
        GasList cell = {'Air','Argon','Nitrogen','Helium','Deuterium','Oxygen','Magic gas'} % Gas types available for selection
        
        hAcquisitionText % Handle to acquisition type label
        hAcquisitionEdit % Handle to acquisition type popupmenu
        AcquisitionList cell = {'Sweep 1D','Faraday cup sweep 2D','Beamline Monitor'} % Acquisition types available for selection
        Acquisitions = []%
        
        hRunBtn % Handle to run test button
        hCamGUI; % IHandle to cam conctrol init button
        hCamButton %

    end

    properties (SetObservable)
        LastRead struct % Last readings of beamline timer
    end
    
    methods
        function obj = beamlineGUI
            %BEAMLINEGUI Construct an instance of this class

            % Make user confirm control power on
            % uiwait(msgbox('Confirm that control power to high voltage rack is turned on.','Control Power Check'));

            % Generate a test sequence, test date, and data directory
            obj.genTestSequence;

            % Gather and populate required hardware
            obj.gatherHardware;
            % obj.Hardware = struct2cell(setupInstruments)

            % Create GUI components
            obj.createGUI;

            % Create and start beamline status update timer
            % obj.createTimer;
            obj.hTimer = timer('Name','readTimer',...
                'Period',4,...
                'ExecutionMode','fixedRate',...
                'TimerFcn',@obj.updateReadings,...
                'ErrorFcn',@obj.restartTimer);
            start(obj.hTimer);

            % Generate monitor plot panel
            pause(1);
            obj.hMonitorPlt = beamlineMonitor(obj);
            obj.hMonitorPlt.runSweep();
        end

        function readings = updateReadings(obj,~,~,fname)
            %UPDATEREADINGS Read and update all beamline status reading fields
            % Gather readings
            if isempty(obj.LastRead)
                obj.LastRead = struct;
            end


            %Read the stuff from the hardware
            readList = structfun(@(x)x.read(),obj.Monitors,'UniformOutput',false);

            %Share the monitor values with the last reading variable 
            fields = fieldnames(obj.Monitors);
            newRead =struct();
            for i = 1:numel(fields)
                lab = fields{i};
                val = obj.Monitors.(fields{i}).lastRead;
                newRead.(lab)=val;
            end
            obj.LastRead=newRead;
            readings = struct(['r',num2str(round(now*1e6))],obj.LastRead);

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
            %DELETE Handle class destructor to stop timer and close figure when obj is deleted

            % Stop timer if running
            if strcmp(obj.hTimer.Running,'on')
                stop(obj.hTimer);
            end

            % Delete figure
            if isvalid(obj.hFigure)
                delete(obj.hFigure);
            end

        end
        
        function setRefreshRate(obj,~,~)
            stop(obj.hTimer);
            
            prompt = {'Enter desired rate [S]'};
            dlgtitle = 'Refresh Rate';
            dims = [1 35];
            definput = {'4'};
            answer = inputdlg(prompt,dlgtitle,dims,definput);

            obj.hTimer.set('period',str2double(answer));
            start(obj.hTimer);

        end

        function garbo = readHardware(obj)
            t1 = now();
            garbo = structfun(@(x)x.read(),obj.Hardware,'UniformOutput',false);
            disp(now()-t1);
            disp(structfun(@(x)x.lastRead,obj.Hardware,'UniformOutput',false));

            t2 = now();
            garbo = structfun(@(x)parfeval(@x.read,0),obj.Hardware,'UniformOutput',false);
            disp(now()-t2);
            disp(structfun(@(x)x.lastRead,obj.Hardware,'UniformOutput',false));
        end
    
    end


    methods (Access = private)

        function genTestSequence(obj)
            %GENTESTSEQUENCE Generates a test sequence, test date, and data directory and populates respective obj properties
            
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
            obj.Hardware = setupInstruments();
            obj.Monitors = setupMonitors(obj.Hardware);
        end

        function createGUI(obj)
            %CREATEGUI Create beamline GUI components

            %define relative posiiton so we only need to change one number when adding/removing buttons
            yBorderBuffer = 30 ;
            ypanelBuffer = 20;
            xBorderBuffer = 30;
            xpanelBuffer = 20;

            % Create figure
            obj.hFigure = figure('MenuBar','none',...
                'ToolBar','none',...
                'Position',[0,0,1250,750],...
                'NumberTitle','off',...
                'Name','Beamline GUI',...
                'DeleteFcn',@obj.closeGUI);

            %====================================================================================
            % Create file menu
            obj.hFileMenu = uimenu(obj.hFigure,'Text','File');

            % Create edit menu
            obj.hEditMenu = uimenu(obj.hFigure,'Text','Edit');

            % Create copy test sequence menu button
            obj.hCopyTS = uimenu(obj.hEditMenu,'Text','Copy Test Sequence',...
                'MenuSelectedFcn',@obj.copyTSCallback);

            % add option to set sample rate
            uimenu(obj.hEditMenu,'Text','Set Sample Rate',...
                'MenuSelectedFcn',@obj.setRefreshRate);
            % add option to disable Timer
            uimenu(obj.hEditMenu,'Text','Disable Timer',...
                'MenuSelectedFcn',@obj.stopTimer);
            uimenu(obj.hEditMenu,'Text','Restart Timer',...
                'MenuSelectedFcn',@obj.restartTimer);

            % Turn off dock controls (defaults to on when first uimenu created)
            set(obj.hFigure,'DockControls','off');

            %===================================================================================
            % Create instrument connection status uicontrol group

            % Set positions for components
            ysize = 22;
            ygap = 6;
            ystart = ypanelBuffer;
            ypos = ystart;
            xgap = 15;
            xstart = 10;
            colSize = [180];

            obj.hHWConnStatusGrp = uipanel(obj.hFigure,...
                'Title','Hardware Conectivity',...
                'FontWeight','bold',...
                'FontSize',12,...
                'Units','pixels',...
                'Position',[xBorderBuffer,yBorderBuffer,sum(colSize)+xgap*numel(colSize),10]);

            obj.HWConnStatusListeners.Panel = obj.hHWConnStatusGrp;
            function x = guiHWConnStatusGrpSet(x)    
                colInd = 1;
                xColStart = xstart;
                button = uicontrol(obj.hHWConnStatusGrp,'Style','radiobutton',...
                'Position',[xColStart,ypos,colSize(colInd),ysize],...
                'String',sprintf('%s',x.Tag),...
                'FontWeight','bold','Value',x.Connected);
                set(button,'enable','off');
                ypos = ypos+ysize+ygap;

                %         set(hwStats(i),'Value',obj.Hardware.(nam).Connected)
                % % Define listener to auto update status text when parameter is changed
                obj.HWConnStatusListeners.(x.Tag) = guiListener(x,'Connected',...
                                                                    button,...
                                            @(self) set(self.guiHand,'Value',self.parent.Connected));
            end

            structfun(@guiHWConnStatusGrpSet,obj.Hardware,'UniformOutput',false)

            colInd = 1;
            xColStart = xstart;
            obj.hHWConnBtn = uicontrol(obj.hHWConnStatusGrp, ...
                'Style','pushbutton',...
               'Position',[xColStart,ypos,colSize(colInd),ysize],...
               'String','Refresh',...
               'FontSize',12,...
               'FontWeight','bold',...
                'HorizontalAlignment','center',...
                'Callback',@obj.HwRefreshCallback);
            ypos = ypos+ysize+ygap;
            obj.hHWConnStatusGrp.Position(4) = ypos+yBorderBuffer;
            ypos = ypos+ysize+ygap+yBorderBuffer;

            %===================================================================================
            % Create imaging MCP control group
            
            obj.hCamGUI = uipanel(obj.hFigure,...
                'Title','MCP Cam Control',...
                'FontWeight','bold',...
                'FontSize',12,...
                'Units','pixels',...
                'Position',[xBorderBuffer,ypos+yBorderBuffer,sum(colSize)+xgap*numel(colSize),10]);

            colInd = 1;
            xColStart = xstart;
            obj.hCamButton = uicontrol(obj.hCamGUI, ...
                'Style','pushbutton',...
               'Position',[xColStart,ygap,colSize(colInd),ysize],...
               'String','Start',...
               'FontSize',12,...
               'FontWeight','bold',...
                'HorizontalAlignment','center',...
                'Callback',@obj.trigCamController);
%             ypos = ypos+ygap;
            
            obj.hCamGUI.Position(4) = ysize+ygap+yBorderBuffer;
            %===================================================================================
            % Create beamline status uicontrol group
            % Set positions for components
            ysize = 22;
            ygap = 6;
            ystart = ypanelBuffer;
            ypos = ystart;
            xgap = 15;
            xstart = 10;

            colSize = [180,140,60,60,60];

            obj.hStatusGrp = uipanel(obj.hFigure,...
                'Title','Beamline Status',...
                'FontWeight','bold',...
                'FontSize',12,...
                'Units','pixels',...
                'Position',[obj.hHWConnStatusGrp.Position(3)+xBorderBuffer*2,yBorderBuffer,sum(colSize)+xgap*numel(colSize),10]);

            function x = guiStatusGrpSet(x)    
                colInd = 1;
                xColStart = xstart;
                x.guiHand.statusGrpText=uicontrol(obj.hStatusGrp,'Style','text',...
                'Position',[xColStart,ypos,colSize(colInd),ysize],...
                'String',sprintf('%s ',x.textLabel),...
                'FontWeight','bold',...
                'FontSize',9,...
                'HorizontalAlignment','right');

                xColStart = sum(colSize(1:colInd))+xgap*(colInd);
                colInd = colInd+1;
                readingTxt = uicontrol(obj.hStatusGrp,'Style','edit',...
                'Position',[xColStart,ypos,colSize(colInd),ysize],...
                'Enable','inactive',...
                'FontSize',9,...
                'HorizontalAlignment','right');

                % Define listener to auto update status text when parameter is changed
                x.guiHand.listener = guiListener(x,'lastRead',...
                                                     readingTxt,...
                            @(self) set(self.guiHand,'String',sprintf(self.parent.formatSpec,self.parent.lastRead)));

                
                
                % column for units following readouts
                xColStart = sum(colSize(1:colInd))+xgap*(colInd);
                colInd = colInd+1;
                x.guiHand.statusGrpSetText = uicontrol(obj.hStatusGrp,'Style','text',...
                    'Position',[xColStart,ypos,colSize(colInd),ysize],...
                    'String',sprintf('[%s]: ',x.unit),...
                    'FontSize',9,...
                    'HorizontalAlignment','right');

                if x.active

                    xColStart = sum(colSize(1:colInd))+xgap*(colInd);
                    colInd = colInd+1;
                    x.guiHand.statusGrpSetField = uicontrol(obj.hStatusGrp,'Style','edit',...
                        'Position',[xColStart,ypos,colSize(colInd),ysize],...
                        'FontSize',9,...
                        'HorizontalAlignment','right');

                    xColStart = sum(colSize(1:colInd))+xgap*(colInd);
                    colInd = colInd+1;
                    x.guiHand.statusGrpSetBtn = uicontrol(obj.hStatusGrp,'Style','pushbutton',...
                        'Position',[xColStart,ypos,colSize(colInd),ysize],...
                        'String','SET',...
                        'FontWeight','bold',...
                        'FontSize',9,...
                        'HorizontalAlignment','center',...
                        'Callback',@x.guiSetCallback);

                    xColStart = sum(colSize(1:colInd))+xgap*(colInd);
                end
                ypos = ypos+ysize+ygap;
                obj.hStatusGrp.Position(4) = ypos+yBorderBuffer;
            end
            
            structfun(@guiStatusGrpSet,obj.Monitors);

            %====================================================================================
            %Test Panel group
            % Set positions for right-side GUI components
            ysize = 22;
            ygap = 20;
            ystart = ypanelBuffer;
            ypos = ystart;
            xgap = 15;
            xstart = 10;
            colSize = [160,180];
            
            xtextsize = 160;
            xeditsize = 180;
            
            obj.hTestGrp = uipanel(obj.hFigure,...
                'Title','Testing',...
                'FontWeight','bold',...
                'FontSize',12,...
                'Units','pixels',...
                'Position',[obj.hStatusGrp.Position(1)+obj.hStatusGrp.Position(3)+xBorderBuffer,...
                                yBorderBuffer,sum(colSize)+xgap*numel(colSize),500]);

            % Create remaning GUI components
            %==============================================
            colInd = 1;
            xColStart = xstart;
            obj.hRunBtn = uicontrol(obj.hTestGrp,'Style','pushbutton',...
                'Position',[xColStart,ypos,colSize(colInd),ysize],...
                'String','RUN TEST',...
                'FontSize',16,...
                'FontWeight','bold',...
                'HorizontalAlignment','center',...
                'Callback',@obj.runTestCallback);
            ypos = ypos+ysize+ygap;
            %==============================================
            colInd = 1;
            xColStart = xstart;
            obj.hAcquisitionText = uicontrol(obj.hTestGrp,'Style','text',...
                'Position',[xColStart,ypos,colSize(colInd),ysize],...
                'String','Acquisition Type:',...
                'FontSize',12,...
                'FontWeight','bold',...
                'HorizontalAlignment','right');

            xColStart = sum(colSize(1:colInd))+xgap*(colInd);
            colInd = colInd+1;
            obj.hAcquisitionEdit = uicontrol(obj.hTestGrp,'Style','popupmenu',...
                'Position',[xColStart,ypos,colSize(colInd),ysize],...
                'String',[{''},obj.AcquisitionList],...
                'FontSize',11,...
                'HorizontalAlignment','left',...
                'Callback',@obj.acquisitionCallback);
            ypos = ypos+ysize+ygap;

            %==============================================
            colInd = 1;
            xColStart = xstart;
            obj.hGasText = uicontrol(obj.hTestGrp,'Style','text',...
                'Position',[xColStart,ypos,colSize(colInd),ysize],...
                'String','Gas Type:',...
                'FontSize',12,...
                'FontWeight','bold',...
                'HorizontalAlignment','right');
            xColStart = sum(colSize(1:colInd))+xgap*(colInd);
            colInd = colInd+1;
            obj.hGasEdit = uicontrol(obj.hTestGrp,'Style','popupmenu',...
                'Position',[xColStart,ypos,colSize(colInd),ysize],...
                'String',[{''},obj.GasList],...
                'FontSize',11,...
                'HorizontalAlignment','left',...
                'Callback',@obj.gasCallback);
            ypos = ypos+ysize+ygap;
            %==============================================
            colInd = 1;
            xColStart = xstart;
            obj.hSequenceText = uicontrol(obj.hTestGrp,'Style','text',...
                'Position',[xColStart,ypos,colSize(colInd),ysize],...
                'String','Test Sequence:',...
                'FontSize',12,...
                'FontWeight','bold',...
                'HorizontalAlignment','right');

            xColStart = sum(colSize(1:colInd))+xgap*(colInd);
            colInd = colInd+1;
            obj.hSequenceEdit = uicontrol(obj.hTestGrp,'Style','text',...
                'Position',[xColStart,ypos,colSize(colInd),ysize],...
                'String',num2str(obj.TestSequence),...
                'FontSize',12,...
                'FontWeight','bold',...
                'HorizontalAlignment','left');

            ypos = ypos+ysize+ygap;
            %==============================================
            colInd = 1;
            xColStart = xstart;
            obj.hDateText = uicontrol(obj.hTestGrp,'Style','text',...
                'Position',[xColStart,ypos,colSize(colInd),ysize],...
                'String','Test Date:',...
                'FontSize',12,...
                'FontWeight','bold',...
                'HorizontalAlignment','right');
            xColStart = sum(colSize(1:colInd))+xgap*(colInd);
            colInd = colInd+1;
            obj.hDateEdit = uicontrol(obj.hTestGrp,'Style','text',...
                'Position',[xColStart,ypos,colSize(colInd),ysize],...
                'String',obj.TestDate,...
                'FontSize',12,...
                'FontWeight','bold',...
                'HorizontalAlignment','left');
            ypos = ypos+ysize+ygap;
            %==============================================
            colInd = 1;
            xColStart = xstart;
            obj.hOperatorText = uicontrol(obj.hTestGrp,'Style','text',...
                'Position',[xColStart,ypos,colSize(colInd),ysize],...
                'String','Test Operator:',...
                'FontSize',12,...
                'FontWeight','bold',...
                'HorizontalAlignment','right');

            xColStart = sum(colSize(1:colInd))+xgap*(colInd);
            colInd = colInd+1;
            obj.hOperatorEdit = uicontrol(obj.hTestGrp,'Style','popupmenu',...
                'Position',[xColStart,ypos,colSize(colInd),ysize],...
                'String',[{''},obj.OperatorList],...
                'FontSize',11,...
                'HorizontalAlignment','left',...
                'Callback',@obj.operatorCallback);
            ypos = ypos+ysize+ygap;

            obj.hTestGrp.Position(4) = ypos+yBorderBuffer;
        end

        function createTimer(obj)
            %CREATETIMER Creates timer to periodically update readings from beamline hardware

            % Create timer object and populate respective obj property
            obj.hTimer = timer('Name','readTimer',...
                'Period',4,...
                'ExecutionMode','fixedRate',...
                'TimerFcn',@obj.updateReadings,...
                'ErrorFcn',@obj.restartTimer);

            % Start timer
            start(obj.hTimer);

        end



        function restartTimer(obj,~,~)
            %RESTARTTIMER Restarts timer if error

            % Stop timer if still running
            if strcmp(obj.hTimer.Running,'on')
                stop(obj.hTimer);
            end

            % Restart timer
            start(obj.hTimer);

        end

        function stopTimer(obj,~,~)
            % Stop timer if still running
            if strcmp(obj.hTimer.Running,'on')
                stop(obj.hTimer);
            end
        end

        function trigCamController(obj,~,~)
            if obj.Hardware.MCPwebCam.Connected
                obj.Hardware.MCPwebCam.shutdown();
                obj.hCamButton.set('String','Start');
            else
                obj.Hardware.MCPwebCam.run();
                obj.hCamButton.set('String','Stop');
            end
        end


        function copyTSCallback(obj,~,~)
            %COPYTSCALLBACK Copies test sequence to clipboard

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

        function gasCallback(obj,src,~)
            %GASCALLBACK Populate gas type obj property with user selected value

            % Delete blank popupmenu option
            obj.popupBlankDelete(src);

            % Populate obj property with user selection
            if ~strcmp(src.String{src.Value},"")
                obj.GasType = src.String{src.Value};
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

            % Throw error if gas type not selected
            if isempty(obj.GasType)
                errordlg('A gas type must be selected before proceeding!','Don''t be lazy!');
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

        function HwRefreshCallback(obj,~,~)
            hwStats = obj.hHWConnStatusGrp.Children;
            tags = fieldnames(obj.Hardware);
            for i = 1:numel(hwStats)
                nam = hwStats(i).String;
                disp(nam)
                if any(strcmp(tags,nam))
                    obj.Hardware.(nam).connectDevice();
                end
            end
        end

        function HwComStatusCallback(obj,~,~)
            hwStats = obj.hHWConnStatusGrp.Children;
            tags = fieldnames(obj.Hardware);
            for i = 1:numel(hwStats)
                nam = hwStats(i).String;
                if any(strcmp(tags,nam))
                    set(hwStats(i),'Value',obj.Hardware.(nam).Connected)
                end
            end
        end

        function closeGUI(obj,~,~)
            %CLOSEGUI Stop timer and delete obj when figure is closed
            % Stop timer if running
            if strcmp(obj.hTimer.Running,'on')
                stop(obj.hTimer);
            end
            obj.Hardware.MCPwebCam.shutdown();
            % Delete obj
            delete(obj);
        end



    end

    methods (Static, Access = private)

        function popupBlankDelete(src)
            %POPUPBLANKDELETE Deletes blank option of popupmenu if user selected another value

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

