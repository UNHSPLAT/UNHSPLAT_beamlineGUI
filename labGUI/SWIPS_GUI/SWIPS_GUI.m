classdef SWIPS_GUI < labGUI
    %SWIPS_GUI - Defines a GUI used to interface with the SWIPS system
    
    properties
        % SWIPS-specific properties
        hHardwareMenu % Handle to hardware menu
        hStatusGrp % Handle to status uicontrol group
        hHVStatusGrp % Handle to high voltage status uicontrol group
        hPosStatusGrp % Handle to position status panel group
        hInstGrp % Handle to instrument monitors panel
        mcpRampListener
        hMCPRamp
        hHWConnStatusGrp % Handle to hardware connection status panel
        HWConnStatusListeners % Listeners for hardware connection status
        hHWConnBtn % Handle to hardware connection refresh button
    end
    
    properties (Access = protected)
        caenMenu    % Handle to CAEN menu handler
        newportMenu % Handle to Newport stage menu
        OKMenu      % Handle to Opal Kelly menu handler
        % Override operator and acquisition lists
   end

    properties (SetObservable)
        LastRead struct % Last readings from the monitor timer
    end
    
    methods
        function obj = SWIPS_GUI
            
            %SWIPS_GUI Construct an instance of this class
            obj@labGUI('SWIPS',fullfile(getenv("USERPROFILE"),"data/SWIPS"));

            obj.AcquisitionList = {'Sweep 1D','Sweep 2D'};

            obj.hHardwareMenu = uimenu(obj.hFigure,'Text','Hardware');

            % Create CAEN menu handler
            obj.caenMenu = caen_gui_menu(obj.Hardware.caen_HVPS1, obj.hHardwareMenu, ...
                                        [0,1,2,3], ...
                                        ["Upper Deflection", "Lower Deflection", "Flux Red.", "Inner Dome"]);

            obj.newportMenu = newport_gui_menu(obj.Hardware.newportStage, obj.hHardwareMenu);

            obj.OKMenu = swips_ok_gui_menu(obj.Hardware.Opal_Kelly, obj.hHardwareMenu);

            % Create GUI components and layout
            obj.createLayout();

        end

        function createHardware(obj)
            % Implementation of abstract method from labGUI
            % Setup SWIPS hardware
            obj.Hardware = setupSWIPSInstruments;
        end
        
        function createMonitors(obj)
            % Implementation of abstract method from labGUI
            % Setup monitors for hardware
            obj.Monitors = setupSWIPSMonitors(obj.Hardware);
        end
    end

    methods (Access = public)

        function createLayout(obj)
            
            % Implementation of abstract method from labGUI
            %CREATEGUI Create SWIPS GUI components
            
            % Create main figure window
            obj.hFigure.Position = [0,0,1000,600];
            
            %====================================================================================
            % Define common GUI parameters
            
            ygap = 6;      % Vertical gap between controls
            xgap = 15;     % Horizontal gap between controls
            xstart = 10;   % Initial X position
            panelGap = 20; % Gap between panels
            leftMargin = 10; % Left margin for panels

            % Column sizes for different elements
            colSize = [130,140,60,60,60];  % [Label, Value, Units, Set Value, Set Button]
            panelWidth = sum(colSize)+xgap*numel(colSize);
            
            %===================================================================================
            % Create hardware connection status panel in leftmost column
            [obj.hHWConnStatusGrp, obj.HWConnStatusListeners, obj.hHWConnBtn] = ...
                createHWConnectionStatusPanel(obj.hMainControlsTab, obj.Hardware, ...
                                              leftMargin, 30);
            
            % Define column 2 starting position (after hardware connection status panel)
            col2Start = obj.hHWConnStatusGrp.Position(1) + obj.hHWConnStatusGrp.Position(3) + panelGap;
            
            %===================================================================================
            % Create HV status panel in column 2
            obj.hHVStatusGrp = obj.guiPanelMake(obj.hMainControlsTab,...
                col2Start, 30,...
                'HVPS',...
                'colSizes',colSize,...
                'monitorGroup', 'HV');

            %===================================================================================
             % MCP ramp activate and abort button
            obj.hMCPRamp = uicontrol(obj.hHVStatusGrp, ...
                'Style','pushbutton',...
               'Position',[sum(colSize(1:3))+xgap*3,ygap,sum(colSize(4:end))+xgap*3,obj.ysize],...
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
            obj.mcpRampListener = guiListener(obj.Monitors.voltMCP,'lock',...
                                        obj.hMCPRamp,@ramp_stat);

            % Panel height is automatically adjusted by guiPanelMake

            % Create position status panel with monitors in column 2
            obj.hPosStatusGrp = obj.guiPanelMake(obj.hMainControlsTab,...
                col2Start, ...
                obj.hHVStatusGrp.Position(4)+obj.hHVStatusGrp.Position(2),...
                'StagePosition',...
                'colSizes',colSize,...
                'monitorGroup', 'position');
            
            % Get the height needed for controls
            controlsHeight = obj.hPosStatusGrp.Position(4);
            
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

         %===================================================================================
            % create column 3
            
            % Define third column position
            rightColStart = col2Start + panelWidth + panelGap;
            
            % Create detectors panel in right column
            ypos = 30;
            detectorsPanel = obj.guiPanelMake(obj.hMainControlsTab, rightColStart, ypos, ...
            'Detectors', ...
            'colSizes',[100,200,40,60,60],...
            'monitorGroup', 'detectors');
            
            % Create instrument monitor panel below detectors
            obj.hInstGrp = obj.guiPanelMake(obj.hMainControlsTab, rightColStart, ...
            detectorsPanel.Position(4)+detectorsPanel.Position(2)+20, ...
            'Instrument Monitors', ...
            'colSizes',[100,200,40,60,60],...
            'monitorGroup', 'inst');
            
            % Create SWIPS status panel below instrument monitors
            obj.hStatusGrp = obj.guiPanelMake(obj.hMainControlsTab,...
                rightColStart,...
                obj.hInstGrp.Position(4)+obj.hInstGrp.Position(2)+20,...
                'SWIPS',...
                'colSizes',colSize,... % Use existing column sizes
                'monitorGroup', 'status');
            
            obj.guiPanelTest([rightColStart, obj.hStatusGrp.Position(4)+obj.hStatusGrp.Position(2)+20, 360, 250],obj.hMainControlsTab);
            % Adjust figure size to fit all panels  
            % Calculate required figure size based on panels
            obj.guiAutoScale(obj.hFigure);
            
        end

        function mcpRampCallback(obj,~,~)
            mcpMon = obj.Monitors.voltMCP;
            if mcpMon.lock
                stop(mcpMon.monTimer);
            else
                Ramp_MCPHVPS(mcpMon);
            end
        end



    end

end
