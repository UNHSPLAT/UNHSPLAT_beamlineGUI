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
        valveMonitors    struct  % Monitors whose group is 'valveState'
    end

    properties (Access = private)
        hFigure  % Handle to the control figure
    end

    methods
        function obj = vacControl(monitors)
            %VACCONTROL  Construct the vacuum control app
            %   Extracts pressure and valveState monitors from the provided
            %   monitors struct, then builds the GUI.

            obj.pressureMonitors = struct();
            obj.valveMonitors    = struct();

            fields = fieldnames(monitors);
            for i = 1:numel(fields)
                mon = monitors.(fields{i});
                if strcmp(mon.group, 'pressure')
                    obj.pressureMonitors.(fields{i}) = mon;
                elseif strcmp(mon.group, 'valveState')
                    obj.valveMonitors.(fields{i}) = mon;
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

            obj.hFigure = figure( ...
                'MenuBar',     'none', ...
                'ToolBar',     'none', ...
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

            displayWebPage('http://192.168.0.110/', pan_valveControl);

            % --- System layout diagram (top 60 %) ---
            panSystem = uipanel(obj.hFigure, ...
                'Position', [0, vfrac, 1, 1]);

            ax = axes('Parent',   panSystem, ...
                      'Units',    'normalized', ...
                      'Position', [0, 0, 1, 1 - vfrac]);
            img = imread('system_layoutV04.png');
            imshow(img, 'Parent', ax);
            set(ax, 'HandleVisibility', 'off', 'Visible', 'off');
        end
    end
end
