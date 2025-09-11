classdef beamlineGUI < labGUI
    %BEAMLINEGUI - Defines a GUI used to interface with the Peabody Scientific beamline in lab 145
    
    properties
        % Beamline-specific properties and controls
        hValveFigure % Handle to valve control figure
        
        hStatusGrp % Handle to beamline status uicontrol group
        hCamGUI % Handle to camera control init button
        hCamButton % Handle to camera button
        hGasText % Handle to gas type label
        hGasEdit % Handle to gas type popupmenu
    end
    
    properties (Access = protected)
        % Override operator, gas, and acquisition lists with beamline-specific options
        hStageGUI; % IHandle to stage conctrol init button
        hStageButton %

        hHWConnStatusGrp % Handle to hardware connection status uicontrol group
        HWConnStatusListeners
        hHWConnBtn % Handle to hardware connection refresh button

        hControlMenu % Handle to control top menu dropdown
    end

    properties (SetObservable)
        LastRead struct % Last readings of beamline timer
    end
    
    methods (Access = protected)
        
    end
    
    methods
        function obj = beamlineGUI
            %BEAMLINEGUI Construct an instance of this class

            % Check for and clean up any running timers
            if ~isempty(timerfindall)
                warning('Matlab timers found running, deleting all timers');
                stop(timerfindall);
                delete(timerfindall);
            end

            obj@labGUI('Beamline GUI');
            % Initialize hardware and monitors
            obj.createHardware();
            obj.createMonitors();

            % Create GUI components and layout
            obj.createLayout();

            % Create and start status update timer
            obj.createTimer();
        end
        
        function createHardware(obj)
            % Implementation of abstract method from labGUI
            % Setup beamline hardware
            obj.Hardware = setupInstruments();
        end
        
        function createMonitors(obj)
            % Implementation of abstract method from labGUI
            % Setup monitors for hardware
            obj.Monitors = setupMonitors(obj.Hardware);
        end

        function valveControlCallback(obj,~,~)
           vfrac = .4;
           obj.hValveFigure = figure('MenuBar','none',...
                'ToolBar','none',...
                'Position',[658 245 876 687],...
                'NumberTitle','off',...
                'Name','Valve Control');

           pan_valveControl = uipanel(obj.hValveFigure,...
                'Title','PowerStrip',...
                'FontWeight','bold',...
                'FontSize',12,...
                'Position',[0,0,1,vfrac] ...
                );

           displayWebPage('http://192.168.0.110/',pan_valveControl);
           
           panSystem = uipanel(obj.hValveFigure,...
                'Position',[0,vfrac,1,1] ...
                );

           ax = axes('Parent',panSystem,'units','normalized','position',[0,0,1,1-vfrac]);
           img  = imread('system_layoutV04.png');
           imshow(img, 'Parent', ax);
           set(ax,'handlevisibility','off','visible','off')

        end
    end


    methods (Access = public)
        function createLayout(obj)
            %CREATEGUI Create main GUI window and menus

            %define relative posiiton so we only need to change one number when adding/removing buttons
            yBorderBuffer = 30 ;
            ypanelBuffer = 20;
            xBorderBuffer = 30;
            xpanelBuffer = 20;

            % Create figure
            obj.hFigure.Position =[0,0,1250,750]

            %====================================================================================
            % Create Tools menu
            obj.hControlMenu = uimenu(obj.hFigure,'Text','Control');

            uimenu(obj.hControlMenu,'Text','ValveControl',...
                'MenuSelectedFcn',@obj.valveControlCallback);

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
            ypos = obj.hHWConnStatusGrp.Position(2)+obj.hHWConnStatusGrp.Position(4);

            %===================================================================================
            % Create imaging MCP control group
            
            obj.hCamGUI = uipanel(obj.hFigure,...
                'Title','MCP Cam Control',...
                'FontWeight','bold',...
                'FontSize',12,...
                'Units','pixels',...
                'Position',[xBorderBuffer,ypos,sum(colSize)+xgap*numel(colSize),10]);

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
            ypos = obj.hCamGUI.Position(2)+obj.hCamGUI.Position(4);

            %===================================================================================
            % Create position system control group
            
            obj.hStageGUI = uipanel(obj.hFigure,...
                'Title','Newport Stage Control',...
                'FontWeight','bold',...
                'FontSize',12,...
                'Units','pixels',...
                'Position',[xBorderBuffer,ypos,sum(colSize)+xgap*numel(colSize),10]);

            colInd = 1;
            xColStart = xstart;
            obj.hStageButton = uicontrol(obj.hStageGUI, ...
                'Style','pushbutton',...
               'Position',[xColStart,ygap,colSize(colInd),ysize],...
               'String','Start',...
               'FontSize',12,...
               'FontWeight','bold',...
                'HorizontalAlignment','center',...
                'Callback',@obj.trigStageController);
%             ypos = ypos+ygap;
            
            obj.hStageGUI.Position(4) = ysize+ygap+yBorderBuffer;
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
            

            obj.guiPanelTest([obj.hStatusGrp.Position(1)+obj.hStatusGrp.Position(3)+xBorderBuffer,...
                                yBorderBuffer,sum(colSize)+xgap*numel(colSize),500]);

        end
    end
    methods (Access = private)
        function trigCamController(obj,~,~)
            if obj.Hardware.MCPwebCam.Connected
                obj.Hardware.MCPwebCam.shutdown();
                obj.hCamButton.set('String','Start');
            else
                obj.Hardware.MCPwebCam.run();
                obj.hCamButton.set('String','Stop');
            end
        end

        function trigStageController(obj,~,~)
            if obj.Hardware.newportStage.Connected
                obj.Hardware.newportStage.shutdown();
                obj.hStageButton.set('String','Start');
            else
                obj.Hardware.newportStage.run();
                obj.hStageButton.set('String','Stop');
            end
        end

        function HwRefreshCallback(obj,~,~)
            hwStats = obj.hHWConnStatusGrp.Children;
            tags = fieldnames(obj.Hardware);
            for i = 1:numel(hwStats)
                nam = hwStats(i).String;
                disp(nam)
                if any(strcmp(tags,nam))
                    obj.Hardware.(nam).connectDevice();
                    obj.Hardware.(nam).restartTimer();
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

    end

    methods (Static, Access = private)

    end

end

