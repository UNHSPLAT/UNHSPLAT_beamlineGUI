classdef SWIPS_GUI < labGUI
    %SWIPS_GUI - Defines a GUI used to interface with the SWIPS system
    
    properties
        % SWIPS-specific properties
        hStatusGrp % Handle to status uicontrol group
        hHVStatusGrp % Handle to high voltage status uicontrol group
        hPosStatusGrp % Handle to position status panel group
        hInstGrp % Handle to instrument monitors panel
        mcpRampListener
        hMCPRamp
    end
    
    properties (Access = protected)
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
            % Create CAEN HV Control submenu
            hCaenMenu = uimenu(obj.hToolsMenu,'Text','CAEN HV Control');
            
            % Create Opal Kelly Settings submenu
            hOpalMenu = uimenu(obj.hToolsMenu,'Text','Opal Kelly Settings');
            
            % Add acquisition time control
            uimenu(hOpalMenu,'Text','Set Acquisition Time',...
                'MenuSelectedFcn',@obj.setAcqTimeCallback);
            
            % Add menu items for each HV channel
            uimenu(hCaenMenu,'Text','Upper Deflector',...
                'MenuSelectedFcn',@(~,~) obj.HVenableCallback('voltCh0_upDefl',0));
            uimenu(hCaenMenu,'Text','Lower Deflector',...
                'MenuSelectedFcn',@(~,~) obj.HVenableCallback('voltCh1_lowDefl',1));
            uimenu(hCaenMenu,'Text','Flux Reducer',...
                'MenuSelectedFcn',@(~,~) obj.HVenableCallback('voltCh2_flRed',2));
            uimenu(hCaenMenu,'Text','inner Dome',...
                'MenuSelectedFcn',@(~,~) obj.HVenableCallback('voltCh3_inDome',3));

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
            
            % Create HV status panel at the bottom
            obj.hHVStatusGrp = obj.guiPanelMake(obj.hFigure,...
                leftMargin, 30,...
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

            % Create position status panel with monitors
            obj.hPosStatusGrp = obj.guiPanelMake(obj.hFigure,...
                leftMargin, ...
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

            % Create SWIPS status panel
            obj.hStatusGrp = obj.guiPanelMake(obj.hFigure,...
                leftMargin,...
                obj.hPosStatusGrp.Position(4)+obj.hPosStatusGrp.Position(2),...
                'SWIPS',...
                'colSizes',colSize,... % Use existing column sizes
                'monitorGroup', 'status');  

         %===================================================================================
            % create column 2
            
            % Define second column position
            rightColStart = leftMargin*2 + panelWidth;
            
            % Create instrument monitor panel in right column
            ypos = 10;  % Reset Y position for new panel
            obj.hInstGrp = obj.guiPanelMake(obj.hFigure, rightColStart, 30, ...
            'Instrument Monitors', ...
            'colSizes',[100,200,40,60,60],...
            'monitorGroup', 'inst');
            
            obj.guiPanelTest([rightColStart, obj.hInstGrp.Position(4)+obj.hInstGrp.Position(2)+20, 360, 250]);
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

        function HVenableCallback(obj, channelName,chan)
            % Get the monitor for this channel
            if ~isfield(obj.Monitors, channelName)
                errordlg(['Channel ' channelName ' not found'], 'Error');
                return;
            end
            monitor = obj.Monitors.(channelName);
            % Create confirmation dialog with channel-specific message
            channelLabel = monitor.textLabel;
            choice = questdlg([sprintf('%s:',channelLabel) channelName], ...
                'Enable/Disable HV', ...
                'Enable','Disable','Disable');
            
            % Handle response
            if strcmp(choice, 'Enable')
                fprintf('Enabling %s\n', channelLabel);
                try
                    monitor.set(0); % Set to 0V when enabling
                    monitor.parent.setON(chan);
                catch ME
                    errordlg(['Error enabling ' channelLabel ': ' ME.message], 'Error');
                end
            elseif strcmp(choice, 'Disable')
                fprintf('Disabling %s\n', channelLabel);
                try
                    monitor.parent.setOFF(chan);
                catch ME
                    errordlg(['Error disabling ' channelLabel ': ' ME.message], 'Error');
                end
            end
        end

        
        function setAcqTimeCallback(obj, ~, ~)
            % Create dialog for acquisition time selection
            choice = questdlg('Select Acquisition Time:', ...
                'Set Acquisition Time', ...
                '1 second','10 seconds','1 second');
            
            % Get the Opal Kelly device
            ok_device = obj.Hardware.Opal_Kelly;
            
            % Handle response
            if ~isempty(choice)
                try
                    if strcmp(choice, '1 second')
                        ok_device.acq_time = 0;
                    else  % 10 seconds
                        ok_device.acq_time = 1;
                    end
                    ok_device.configurePPA_ok(); % Apply the new setting
                catch ME
                    errordlg(['Error setting acquisition time: ' ME.message], 'Error');
                end
            end
        end
    end

end
