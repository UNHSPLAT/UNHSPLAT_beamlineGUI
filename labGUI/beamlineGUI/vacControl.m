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
        pressureMonitors struct  % Monitors whose group is 'pressure'
        stateMonitors    struct  % Monitors whose group is 'valveState'
    end

    properties (Access = private)
        hFigure           % Handle to the control figure
        monitorListeners=event.listener.empty  % Listener array keeping PostSet listeners alive
    end

    methods
        function obj = vacControl(monitors)
            %VACCONTROL  Construct the vacuum control app
            %   Extracts pressure and valveState monitors from the provided
            %   monitors struct, then builds the GUI.

            obj.pressureMonitors = struct();
            obj.stateMonitors    = struct();

            fields = fieldnames(monitors);
            for i = 1:numel(fields)
                mon = monitors.(fields{i});
                if strcmp(mon.group, 'pressure')
                    obj.pressureMonitors.(fields{i}) = mon;
                elseif strcmp(mon.group, 'systemState')
                    obj.stateMonitors.(fields{i}) = mon;
                end
            end

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

%                 'MenuBar',     'none', ...
            obj.hFigure = figure( ...
                'Position',    [658 245 876 687], ...
                'NumberTitle', 'off', ...
                'Name',        'Vac Control');

            % --- Power-strip web panel (bottom 40 %) ---
            pan_valveControl = uipanel(obj.hFigure, ...
                'Title',      'PowerStrip', ...
                'FontWeight', 'bold', ...
                'FontSize',   12, ...
                'Position',   [0, 0, 1, vfrac]);

            uicontrol(obj.hFigure, ...
                'Style',      'pushbutton', ...
                'String',     'Refresh', ...
                'FontSize',   12, ...
                'FontWeight', 'bold', ...
                'Units',      'normalized', ...
                'Position',   [0.01, vfrac + 0.01, 0.1, 0.05], ...
                'Callback',   @(~,~) displayWebPage('http://192.168.0.110/', pan_valveControl));
            try
                displayWebPage('http://192.168.0.110/', pan_valveControl);
            catch
                warning('Failed to display web page.');
            end

            % --- System layout diagram (top 60 %) ---
            panSystem = uipanel(obj.hFigure, ...
                'Position', [0, vfrac, 1, 1]);

            ax = axes('Parent',   panSystem, ...
                      'Units',    'normalized', ...
                      'Position', [0, 0, 1, 1 - vfrac]);
            img = imread('system_layoutV04.png');
            imshow(img, 'Parent', ax);
            set(ax, 'HandleVisibility', 'off', 'Visible', 'off');

            % Transparent overlay axes — text() supports VerticalAlignment, uicontrol does not
            axOverlay = axes('Parent',   panSystem, ...
                             'Units',    'normalized', ...
                             'Position', [0, 0, 1, 1 - vfrac], ...
                             'Color',    'none', ...
                             'XColor',   'none', ...
                             'YColor',   'none', ...
                             'XLim',     [0 1], ...
                             'YLim',     [0 1], ...
                             'HitTest',  'off');

            % --- Pressure readouts overlaid on layout diagram ---
            % Positions are [cx, cy, w, h] in panSystem normalised coords.
            % cy is divided by (1-vfrac) to convert into axOverlay data space.
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
                cx = pos(1) + pos(3)/2;
                cy = (pos(2) + pos(4)/2) / (1 - vfrac);
                hTxt = text(axOverlay, cx, cy, '---', ...
                    'FontSize',            10, ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment',   'middle', ...
                    'BackgroundColor',     [0 0.8 0 0.2], ...  % transparent green
                    'EdgeColor',           'none');
                if isfield(obj.pressureMonitors, monName)
                    mon = obj.pressureMonitors.(monName);
                    obj.monitorListeners(end+1) = listener(mon, 'lastRead', 'PostSet', ...
                        @(~,~) set(hTxt, 'String', sprintf('%s%s', mon.sPrintVal(), mon.unit)));
                end
            end

            % --- System-state readouts overlaid on layout diagram ---
            systemStateOverlays = { ...
                'cryoTemp', [0.794748293002288, 0.174228060238596, 0.08, 0.031145717463849]; ...
            };

            for k = 1:size(systemStateOverlays, 1)
                monName = systemStateOverlays{k,1};
                pos     = systemStateOverlays{k,2};
                cx = pos(1) + pos(3)/2;
                cy = (pos(2) + pos(4)/2) / (1 - vfrac);
                hTxt = text(axOverlay, cx, cy, '---', ...
                    'FontSize',            10, ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment',   'middle', ...
                    'BackgroundColor',     [0 0.4 1 0.45], ...  % semi-transparent blue
                    'EdgeColor',           'none');
                if isfield(obj.stateMonitors, monName)
                    mon = obj.stateMonitors.(monName);
                    obj.monitorListeners(end+1) = listener(mon, 'lastRead', 'PostSet', ...
                        @(~,~) set(hTxt, 'String', sprintf('%s%s', mon.sPrintVal(), mon.unit)));
                end
            end
            
        end
    end
end
