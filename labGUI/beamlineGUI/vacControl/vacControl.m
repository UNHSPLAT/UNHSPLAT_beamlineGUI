classdef vacControl < matlab.apps.AppBase
    %VACCONTROL - Vacuum system control panel
    %   Provides a valve control window with a web power-strip interface and a
    %   system layout diagram.  The app accepts the beamlineGUI monitors struct
    %   and retains the 'pressure' and 'valveState' group monitors as properties.
    %
    %   Inherits from matlab.apps.AppBase, which registers the window with
    %   MATLAB's Running Apps system and provides runStartupFcn for safe
    %   post-construction initialisation.
    %
    %   Usage:
    %       app = vacControl(monitors)
    %
    %   Parameters:
    %       monitors - struct of monitor objects from beamlineGUI (obj.Monitors)

    properties
        Monitors struct  % All monitors from beamlineGUI (pressure, systemState, status, etc.)
    end

    properties (SetObservable)
        processRunning = false     % True if vac control process is running (e.g. venting, pumping, etc.)
        hFigure           % Handle to the control figure
        processPanel
    end

    properties (Access = private)
        monitorListeners=event.listener.empty  % Listener array keeping PostSet listeners alive
        processStatusListener = event.listener.empty  % Listener for process status changes
        
        processes = {'HV Crossover'}  % List of available processes to run
        hProcessText
        hProcessDropdown  % Handle to the process function dropdown menu
        hRunButton        % Handle to the run button
        idleCol = [0.53,0.89,0.53]
        runningCol = [0.99,0.77,0.77]
        hValveBoxes   = gobjects(0)  % Rectangle handles for valve state boxes
        valveChannels = []            % Webpowerstrip channel index for each box
    end

    methods
        function obj = vacControl(monitors)
            %VACCONTROL  Construct the vacuum control app
            %   Stores all monitors from the provided monitors struct.

            obj.Monitors = monitors;

            % Build UI, then register with MATLAB's Running Apps system
            obj.createLayout();
            registerApp(obj, obj.hFigure);

            % Run any post-construction startup via AppBase helper so the
            % figure is guaranteed to be fully built before startup fires
            runStartupFcn(obj, @obj.startupFcn);
        end

        function delete(obj)
            %DELETE  Close figure; AppManagementService handles unregistration automatically
            delete(obj.monitorListeners);
            delete(obj.processStatusListener);
            if isvalid(obj.hFigure)
                delete(obj.hFigure);
            end
        end
    end

    methods (Access = private)

        function startupFcn(obj, ~)
            %STARTUPFCN  Runs after construction via runStartupFcn (AppBase pattern)
            %   The second argument (the app handle) is passed by runStartupFcn
            %   internally and is ignored here since obj is already bound.
            %   Place any initialisation that must wait until the figure exists here.
        end

        function createLayout(obj)
            %CREATELAYOUT  Build the valve / vacuum control figure

            vfrac = 0.4;  % Fraction of window height reserved for the web panel

            % 'ToolBar',     'none', ...

            % 'MenuBar',     'none', ...
            obj.hFigure = figure( ...
                'Position',    [658 100 876 870], ...
                'NumberTitle', 'off', ...
                'Name',        'Vac Control');

            % --- Bottom panel: tabbed valve control area ---
            pan_bottom = uipanel(obj.hFigure, ...
                'BorderType', 'none', ...
                'Position',   [0, 0, 1, vfrac]);

            tabGroup = uitabgroup(pan_bottom, ...
                'Units',    'normalized', ...
                'Position', [0, 0, 1, 1]);

            % Tab 1 — Power strip web interface
            tabPowerStrip = uitab(tabGroup, 'Title', 'Power Strip 1');
            pan_valveControl = uipanel(tabPowerStrip, ...
                'BorderType', 'none', ...
                'Units',      'normalized', ...
                'Position',   [0, 0, 1, 1]);

            uicontrol(tabPowerStrip, ...
                'Style',      'pushbutton', ...
                'String',     'Refresh', ...
                'FontSize',   12, ...
                'FontWeight', 'bold', ...
                'Units',      'normalized', ...
                'Position',   [0.01, 0.88, 0.1, 0.1], ...
                'Callback',   @(~,~) displayWebPage('http://192.168.0.110/', pan_valveControl));
            try
                displayWebPage('http://192.168.0.110/', pan_valveControl);
            catch
                warning('Failed to display web page.');
            end

            %% Tab 2 Process control
            tabProcessControl = uitab(tabGroup, 'Title', 'Process Control');
            obj.processPanel = uipanel(tabProcessControl, ...
                'Units',      'normalized', ...
                'Position',   [.3, 0, 0.7, 1]);

            % "Process Status" text box in upper left corner
            uicontrol(tabProcessControl, ...
                'Style',      'text', ...
                'String',     'Process Status', ...
                'FontSize',   12, ...
                'FontWeight', 'bold', ...
                'Units',      'normalized', ...
                'Position',   [0.01, 0.85, 0.15, 0.1]);

            % Add "Process Status" text box in upper left corner
            obj.hProcessText = uicontrol(tabProcessControl, ...
                'Style',      'text', ...
                'String',     'Idle', ...
                'FontSize',   12, ...
                'FontWeight', 'bold', ...
                'Units',      'normalized', ...
                'HorizontalAlignment', 'center', ...
                'BackgroundColor',     obj.idleCol, ...
                'Position',   [0.16, 0.85, 0.1, 0.1]);

            % "Select Process" label below status
            uicontrol(tabProcessControl, ...
                'Style',      'text', ...
                'String',     'Select Process:', ...
                'FontSize',   12, ...
                'FontWeight', 'bold', ...
                'Units',      'normalized', ...
                'Position',   [0.01, 0.73, 0.15, 0.1]);

            % Process function dropdown menu
            obj.hProcessDropdown = uicontrol(tabProcessControl, ...
                'Style',      'popupmenu', ...
                'String',     obj.processes, ...
                'FontSize',   10, ...
                'Units',      'normalized', ...
                'HorizontalAlignment', 'center', ...
                'Position',   [0.033015873015872,0.639967637540453,0.229122315592904,0.046763754045297]);

            % Run button below dropdown
            obj.hRunButton = uicontrol(tabProcessControl, ...
                'Style',      'pushbutton', ...
                'String',     'Run', ...
                'FontSize',   12, ...
                'FontWeight', 'bold', ...
                'Units',      'normalized', ...
                'Position',   [0.033015873015873,0.423139158576047,0.096535947712418,0.124757281553391], ...
                'Callback',   @(~,~) obj.runSelectedProcess());

            obj.processStatusListener = listener(obj, 'processRunning', 'PostSet', @obj.updateProcessStatus);


            %% Tab 3 — Placeholder
            uitab(tabGroup, 'Title', 'Interlocs');

            %% System layout diagram (top 60 %)
            panSystem = uipanel(obj.hFigure, ...
                'Position', [0, vfrac, 1, 1]);

            ax = axes('Parent',   panSystem, ...
                      'Units',    'normalized', ...
                      'Position', [0, 0, 1, 1 - vfrac]);
            img = imread('system_layoutV04.png');
            imshow(img, 'Parent', ax);
            [imgH, imgW, ~] = size(img);
            % Text objects go directly on ax in image-pixel coordinates so they
            % stay locked to the image when the window is resized.
            % imshow sets YDir='reverse' (row 1 = top), so y is flipped:
            %   py = 0.5 + (1 - ax_cy) * imgH
            % where ax_cy is the normalised [0,1] position within the ax extent.
            set(ax, 'HandleVisibility', 'off', 'Visible', 'off');

            % --- Pressure readouts overlaid on layout diagram ---
            % Positions are [cx, cy, w, h] in panSystem normalised coords.
            pressureOverlays = { ...
                'pressureChamberRough1',  [0.559294832795218,0.025516116444685,0.08,0.031145717463849]; ...
                'pressureChamberIG1',     [0.718240146654442,0.336905304618978,0.08,0.031145717463849]; ...
                'pressureBeamIG2',        [0.431934169755276,0.425856399765014,0.08,0.031145717463849]; ...
                'pressureBeamIG1',        [0.310476987878127,0.280696752149979,0.08,0.031145717463849]; ...
                'pressureBeamTurboRough', [0.321356553620515,0.054703899466778,0.08,0.031145717463849]; ...
            };

            for k = 1:size(pressureOverlays, 1)
                monName = pressureOverlays{k,1};
                pos     = pressureOverlays{k,2};
                ax_cx = pos(1) + pos(3)/2;
                ax_cy = (pos(2) + pos(4)/2) / (1 - vfrac);
                px = 0.5 + ax_cx * imgW;
                py = 0.5 + (1 - ax_cy) * imgH;
                hTxt = text(ax, px, py, '---', ...
                    'FontSize',            10, ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment',   'middle', ...
                    'BackgroundColor',     [0 0.8 0 0.2], ...
                    'EdgeColor',           'none');
                if isfield(obj.Monitors, monName)
                    mon = obj.Monitors.(monName);
                    obj.monitorListeners(end+1) = listener(mon, 'lastRead', 'PostSet', ...
                        @(~,~) set(hTxt, 'String', sprintf('%s%s', mon.sPrintVal(), mon.unit)));
                end
            end

            % --- System-state readouts overlaid on layout diagram ---
            systemStateOverlays = { ...
                'cryoTemp', [0.83, 0.174228060238596, 0.08, 0.031145717463849]; ...
            };

            for k = 1:size(systemStateOverlays, 1)
                monName = systemStateOverlays{k,1};
                pos     = systemStateOverlays{k,2};
                ax_cx = pos(1) + pos(3)/2;
                ax_cy = (pos(2) + pos(4)/2) / (1 - vfrac);
                px = 0.5 + ax_cx * imgW;
                py = 0.5 + (1 - ax_cy) * imgH;
                hTxt = text(ax, px, py, '---', ...
                    'FontSize',            10, ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment',   'middle', ...
                    'BackgroundColor',     [0 0.4 1 0.45], ...
                    'EdgeColor',           'none');
                if isfield(obj.Monitors, monName)
                    mon = obj.Monitors.(monName);
                    obj.monitorListeners(end+1) = listener(mon, 'lastRead', 'PostSet', ...
                        @(~,~) set(hTxt, 'String', sprintf('%s%s', mon.sPrintVal(), mon.unit)));
                end
            end



            % --- Valve state indicators overlaid on layout diagram ---
            % [label, webpowerstrip_channel, [x, y, w, h] in panSystem normalised coords]
            valveOverlays = { ...
                'Turbo1GV',       4, [0.288126183986701, 0.234487534626039, 0.035122496713833, 0.030470914127424]; ...
                'BeamRoughV',     1, [0.256789197208691, 0.090443213296399, 0.035122496713833, 0.030470914127424]; ...
                'Turbo2GV',       3, [0.51375248878837,  0.335133887349954, 0.035122496713833, 0.030470914127424]; ...
                'ChamberBeamGV',  6, [0.608459826606354, 0.377608494921514, 0.035122496713833, 0.030470914127424]; ...
                'BeamRoughV2',    2, [0.582389063105424, 0.28944097852671,  0.035122496713833, 0.030470914127424]; ...
                'Cryo1GV',        5, [0.73788254541455,  0.228058530403746, 0.035122496713833, 0.030470914127424]; ...
                'ChamberRoughV1', 8, [0.799335059381031, 0.089669010999243, 0.035122496713833, 0.030470914127424]; ...
                'ChamberRoughV2', 7, [0.6053,0.1965,0.0351,0.0305]; ...
            };

            obj.hValveBoxes   = gobjects(size(valveOverlays, 1), 1);
            obj.valveChannels = cell2mat(valveOverlays(:, 2));

            for k = 1:size(valveOverlays, 1)
                pos    = valveOverlays{k, 3};
                x_rect = 0.5 + pos(1) * imgW;
                y_rect = 0.5 + (1 - (pos(2) + pos(4)) / (1 - vfrac)) * imgH;
                w_rect = pos(3) * imgW;
                h_rect = pos(4) / (1 - vfrac) * imgH;
                obj.hValveBoxes(k) = rectangle(ax, ...
                    'Position',  [x_rect, y_rect, w_rect, h_rect], ...
                    'EdgeColor', [0.7 0.7 0.7], ...
                    'FaceColor', 'none', ...
                    'LineWidth', 2);
            end

            obj.monitorListeners(end+1) = listener(obj.Monitors.valveState, 'lastRead', 'PostSet', ...
                @(~,~) obj.updateValveBoxes());
        end

        function updateProcessStatus(obj,src,evt)
            %UPDATEPROCESSSTATUS  Update the process status text and color
            %   newStatus should be a struct with fields 'text' and 'color' (RGB triplet)
            if obj.processRunning
                text = 'Running';
                color = obj.runningCol;
                set(obj.hRunButton,'String', 'Abort');
                set(obj.hProcessDropdown, 'Enable', 'off');
            else
                text = 'Idle';
                color = obj.idleCol;
                set(obj.hRunButton,'String', 'Run');
                set(obj.hProcessDropdown, 'Enable', 'on');
            end
            set(obj.hProcessText, 'String', text, 'BackgroundColor', color);
        end

        function runSelectedProcess(obj)
            %RUNSELECTEDPROCESS  Execute the process function currently selected in the dropdown
            %   Retrieves the selected process from the dropdown and runs it
            
            if obj.processRunning
                % If a process is already running, we could implement an abort mechanism here
                obj.stopProcess();  % This would signal the running process to stop via the listener
                return;
            end

            selections = get(obj.hProcessDropdown, 'String');
            selectedIdx = get(obj.hProcessDropdown, 'Value');
            selectedFunction = selections{selectedIdx};
            
            % Execute the selected process function
            switch selectedFunction
                case 'HV Crossover'
                    % Execute HV Crossover process
                    obj.processRunning = true; 
                    disp('Running HV Crossover process...');
                    % Call the actual process function here
                    vacControl_fHVcrossover(obj);
                otherwise
                    disp(['Cannot run: ' selectedFunction]);
            end
        end

        function stopProcess(obj)
            %STOPPROCESS  Signal the currently running process to stop
            if obj.processRunning
                disp('Aborting current process...');
                obj.processRunning = false;  % This would signal the running process to stop via the listener
            else
                disp('No process is currently running.');
            end
        end

        function updateValveBoxes(obj)
            %UPDATEVALVEBOXES  Colour valve boxes green (open) / red (closed) / grey (unknown)
            states     = obj.Monitors.valveState.lastRead;
            colOpen    = [0.2 0.8 0.2];
            colClosed  = [0.9 0.2 0.2];
            colUnknown = [0.7 0.7 0.7];
            for i = 1:numel(obj.hValveBoxes)
                ch = obj.valveChannels(i);
                if ch <= numel(states) && ~isnan(states(ch))
                    if states(ch); col = colOpen; else; col = colClosed; end
                else
                    col = colUnknown;
                end
                set(obj.hValveBoxes(i), 'EdgeColor', col);
            end
        end
    end
end
