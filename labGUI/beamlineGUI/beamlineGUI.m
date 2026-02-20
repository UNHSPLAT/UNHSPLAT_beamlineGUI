classdef beamlineGUI < labGUI
    %BEAMLINEGUI - Defines a GUI used to interface with the Peabody Scientific beamline in lab 145
    
    properties
        % Beamline-specific properties and controls
        hValveFigure % Handle to valve control figure
        
        hStatusGrp % Handle to beamline status uicontrol group
        hCamGUI % Handle to camera control init button
        hCamButton % Handle to camera button
        hBeamMonFigure
    end
    
    properties (Access = protected)
        % Override operator, gas, and acquisition lists with beamline-specific options
        hStageGUI; % IHandle to stage conctrol init button
        hStageButton %

        hHWConnStatusGrp % Handle to hardware connection status uicontrol group
        HWConnStatusListeners
        hHWConnBtn % Handle to hardware connection refresh button

        hControlMenu % Handle to control top menu dropdown

        mcpRampListener
        cemRampListener
        hcaenMenu    % Handle to CAEN menu handler
        hHardwareMenu
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
            
            obj.hHardwareMenu = uimenu(obj.hFigure,'Text','Hardware');
             % Create CAEN menu handler
            obj.hcaenMenu = caen_gui_menu(obj.Hardware.caen_HVPS2, obj.hHardwareMenu, ...
                                        [0,1,3], ...
                                        ["mcpVout", "mcpVa", "CEM"]);

            % Create GUI components and layout
            obj.createLayout();

            obj.updateReadings();
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
            %VALVECONTROLCALLBACK Creates a valve control window with web interface
            %   This function creates a figure with two main components:
            %   1. A web panel displaying the power strip control interface
            %   2. A system layout diagram showing the valve configuration
            %
            %   The window includes:
            %   - Power strip web control interface in bottom 40% of window
            %   - System layout diagram in top 60% of window
            %   - Refresh button to reload the web interface
            %
            %   Parameters:
            %   obj - The beamlineGUI object
            %   ~,~ - Unused callback parameters
            
           vfrac = .4; % Fraction of window height for valve control panel
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

           % Create refresh button at the top
           uicontrol(obj.hValveFigure,...
                'Style', 'pushbutton',...
                'String', 'Refresh',...
                'FontSize', 12,...
                'FontWeight', 'bold',...
                'Units', 'normalized',...
                'Position', [0.01 vfrac+0.01 0.1 0.05],...
                'Callback', @(~,~)displayWebPage('http://192.168.0.110/',pan_valveControl));

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
            obj.hFigure.Position =[0,0,1250,750];

            %====================================================================================
            % Create Tools menu
            obj.hControlMenu = uimenu(obj.hFigure,'Text','Control');

            uimenu(obj.hControlMenu,'Text','ValveControl',...
                'MenuSelectedFcn',@obj.valveControlCallback);

            %===================================================================================
            % Create instrument connection status uicontrol group
            
            % Set positions for components (used by multiple panels)
            ysize = 22;
            ygap = 6;
            xgap = 15;
            xstart = 10;
            colSize = [180];
            colInd = 1;
            xColStart = xstart;
            
            [obj.hHWConnStatusGrp, obj.HWConnStatusListeners, obj.hHWConnBtn] = ...
                createHWConnectionStatusPanel(obj.hMainControlsTab, obj.Hardware, ...
                                              xBorderBuffer, yBorderBuffer);
            ypos = obj.hHWConnStatusGrp.Position(2) + obj.hHWConnStatusGrp.Position(4);

            %===================================================================================
            % Create imaging MCP control group
            
            obj.hCamGUI = uipanel(obj.hMainControlsTab,...
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
            % Panel column 2
            % Create beamline status uicontrol group
            % Set positions for components
            
            ypos = yBorderBuffer;
            colSize = [180,140,60,60,60];
            grps = {'HV','beam','pressure','status'};
            for i = 1:numel(grps)
                grp = grps(i);
                out = obj.guiPanelMake(obj.hMainControlsTab,...
                255, ...
                ypos,...
                grp,...
                'colSizes',colSize,...
                'monitorGroup', grp);
                ypos = out.Position(4)+out.Position(2);
            end
            
            %====================================================================================
            % Panel column 3

            pan3x =out.Position(1)+out.Position(3)+xBorderBuffer;
            p3colSizes =[90,100,60,60,60];
            %====================================================================================
            %Test Panel group
            % Set positions for right-side GUI components
            
            obj.guiPanelTest([pan3x,...
                                yBorderBuffer,360, 250],obj.hMainControlsTab);
            out = obj.hTestPanel;

            %====================================================================================
            % Imaging MCP control panel
            imgMCP = obj.guiPanelMake(obj.hMainControlsTab,...
                pan3x, ...
                out.Position(4)+out.Position(2),...
                'ImgMCP',...
                'colSizes',p3colSizes,...
                'monitorGroup', 'ImgMCP');

             %=========================================
             % MCP ramp activate and abort button
            hMCPRamp = uicontrol(imgMCP, ...
                'Style','pushbutton',...
               'Position',[sum(p3colSizes(1:3))+xgap*3,ygap,sum(p3colSizes(4:end))+xgap*2,obj.ysize],...
               'String','Ramp MCP',...
               'FontSize',12,...
               'FontWeight','bold',...
                'HorizontalAlignment','center',...
                'Callback',@obj.mcpRampCallback);

            function ramp_stat(self)
                if self.parent.lock
                    curr_string = 'Abort Ramp';
                else
                    curr_string = 'Ramp MCP';
                end
                set(self.guiHand,'String',curr_string);
            end

            obj.mcpRampListener = guiListener(obj.Monitors.voltCh2_mcpVA,'lock',...
                                        hMCPRamp,@ramp_stat);
            out = imgMCP;

            %===================================================================================
             % Control and mon for CEM
            panCEM = obj.guiPanelMake(obj.hMainControlsTab,...
                pan3x, ...
                out.Position(4)+out.Position(2),...
                'CEM',...
                'colSizes',p3colSizes,...
                'monitorGroup', 'CEM');

             %=========================================
             % CEM ramp activate and abort button
            butCemRamp = uicontrol(panCEM, ...
                'Style','pushbutton',...
               'Position',[sum(p3colSizes(1:3))+xgap*3,ygap,sum(p3colSizes(4:end))+xgap*2,obj.ysize],...
               'String','Ramp CEM',...
               'FontSize',12,...
               'FontWeight','bold',...
                'HorizontalAlignment','center',...
                'Callback',@obj.cemRampCallback);

            function ramp_CEMstat(self)
                if self.parent.lock
                    curr_string = 'Abort Ramp';
                else
                    curr_string = 'Ramp CEM';
                end
                set(self.guiHand,'String',curr_string);
            end

            obj.cemRampListener = guiListener(obj.Monitors.voltCh4_cemVA,'lock',...
                                        butCemRamp,@ramp_CEMstat);
            
            obj.guiAutoScale(obj.hFigure);
        end
    end
    methods (Access = private)
        function cemRampCallback(obj,~,~)
            mcpMon = obj.Monitors.voltCh4_cemVA;
            if mcpMon.lock
                stop(mcpMon.monTimer);
            else
                ramp_singleChanCaen(mcpMon);
            end
        end

        function mcpRampCallback(obj,~,~)
            mcpMon = obj.Monitors.voltCh2_mcpVA;
            if mcpMon.lock
                stop(mcpMon.monTimer);
            else
                Ramp_ImgMCP(mcpMon,obj.Monitors.voltCh1_mcpVout);
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

        function trigStageController(obj,~,~)
            if obj.Hardware.newportStage.Connected
                obj.Hardware.newportStage.shutdown();
                obj.hStageButton.set('String','Start');
            else
                obj.Hardware.newportStage.run();
                obj.hStageButton.set('String','Stop');
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

