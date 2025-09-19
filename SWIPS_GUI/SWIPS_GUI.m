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
            obj@labGUI('SWIPS');

            obj.AcquisitionList = {'Sweep 1D','Sweep 2D'};

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
            uimenu(obj.hToolsMenu,'Text','Ramp MCP Voltage',...
                'MenuSelectedFcn',@obj.mcpRampCallback);

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
   
            obj.guiPanelTest([rightColStart, obj.hInstGrp.Position(4)+obj.hInstGrp.Position(2)+20, 360, 250]);

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
