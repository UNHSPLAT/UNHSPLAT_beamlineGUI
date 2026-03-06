classdef CallbackProfiler < handle
    % CallbackProfiler - Live diagnostic tool for instrument timer callbacks
    %
    % Visualizes timer execution timeline, read_delay, and lockup detection
    % for all hwDevice objects in a labGUI.
    %
    %   Three panels:
    %     1. Gantt-style timeline  — shows WHEN each device callback ran and
    %        HOW LONG it took, color-coded by status (green/red/gray)
    %     2. Rolling delay chart   — read_delay history per device
    %     3. Summary table         — live stats (period, delay, duty%, drops)
    %
    %   Lockup detection: highlights callbacks that exceed 80% of their
    %   timer period in red and logs warnings.
    %
    % Usage:
    %   app = CallbackProfiler(myLabGUI);

    properties
        guiRef           % Reference to labGUI object
        hFigure          % Main figure handle
        hRefreshTimer    % Own refresh timer

        % Axes and UI handles
        hGanttAxes       % Timeline / Gantt axes
        hDelayAxes       % Rolling delay axes
        hTable           % Summary uitable
        hStatusBar       % Bottom status bar
        hWarnList        % Warning / event log listbox

        % Visual window
        windowSec  = 30  % Seconds of timeline to display
        warnThresh = 0.8 % Duty-cycle fraction that triggers a warning
    end

    properties (Constant)
        RefreshRate  = 1
        OwnTimerTag  = 'CallbackProfiler_Refresh'
    end

    % =====================================================================
    methods

        function obj = CallbackProfiler(guiRef)
            if nargin < 1
                error('CallbackProfiler:NoGUI','Pass a labGUI object.');
            end
            obj.guiRef = guiRef;
            obj.buildUI();
            obj.startRefresh();
            obj.refresh();
        end

        % -----------------------------------------------------------------
        function buildUI(obj)
            obj.hFigure = figure(...
                'Name',            'Callback Profiler',...
                'NumberTitle',     'off',...
                'MenuBar',         'none',...
                'ToolBar',         'none',...
                'Position',        [120 80 1200 780],...
                'Color',           [0.10 0.10 0.12],...
                'CloseRequestFcn', @(~,~) obj.close());

            % ---- Left column: gantt (top) + delay (bottom) ----
            leftW  = 0.62;

            % Gantt / timeline
            obj.hGanttAxes = axes('Parent', obj.hFigure,...
                'Units','normalized','Position',[0.06 0.56 leftW-0.04 0.38],...
                'Color',[0.06 0.06 0.08],...
                'XColor',[.7 .7 .7],'YColor',[.7 .7 .7],...
                'GridColor',[.3 .3 .3],'GridAlpha',0.5,...
                'XGrid','on','YGrid','on','FontSize',8);
            title(obj.hGanttAxes,'Callback Execution Timeline','Color','w','FontSize',10);
            xlabel(obj.hGanttAxes,'Seconds ago','Color',[.7 .7 .7]);

            % Rolling delay plot
            obj.hDelayAxes = axes('Parent', obj.hFigure,...
                'Units','normalized','Position',[0.06 0.12 leftW-0.04 0.36],...
                'Color',[0.06 0.06 0.08],...
                'XColor',[.7 .7 .7],'YColor',[.7 .7 .7],...
                'GridColor',[.3 .3 .3],'GridAlpha',0.5,...
                'XGrid','on','YGrid','on','FontSize',8);
            title(obj.hDelayAxes,'Read Delay History','Color','w','FontSize',10);
            xlabel(obj.hDelayAxes,'Seconds ago','Color',[.7 .7 .7]);
            ylabel(obj.hDelayAxes,'read\_delay (s)','Color',[.7 .7 .7]);

            % ---- Right column: table (top) + warning log (bottom) ----
            rightX = leftW + 0.02;
            rightW = 1 - rightX - 0.02;

            % Summary table
            colNames = {'Device','Period','Delay','Duty%','Drops','Status'};
            obj.hTable = uitable('Parent', obj.hFigure,...
                'Units','normalized','Position',[rightX 0.56 rightW 0.38],...
                'ColumnName',colNames,...
                'RowName',{},...
                'ColumnWidth',{110,52,62,52,42,50},...
                'FontSize',8,...
                'BackgroundColor',[0.14 0.14 0.16; 0.18 0.18 0.20],...
                'ForegroundColor',[0.92 0.92 0.92]);

            % Warning log
            uicontrol('Parent',obj.hFigure,'Style','text',...
                'Units','normalized','Position',[rightX 0.49 rightW 0.025],...
                'String','  Event / Warning Log',...
                'HorizontalAlignment','left',...
                'BackgroundColor',[0.10 0.10 0.12],...
                'ForegroundColor',[1 0.65 0.2],'FontSize',8,'FontWeight','bold');

            obj.hWarnList = uicontrol('Parent',obj.hFigure,...
                'Style','listbox',...
                'Units','normalized','Position',[rightX 0.12 rightW 0.37],...
                'FontName','Consolas','FontSize',7,...
                'BackgroundColor',[0.08 0.08 0.10],...
                'ForegroundColor',[0.85 0.85 0.85],...
                'Max',2,'Enable','inactive');

            % Status bar
            obj.hStatusBar = uicontrol('Parent',obj.hFigure,...
                'Style','text','Units','normalized',...
                'Position',[0 0 1 0.04],...
                'String',' Starting...',...
                'HorizontalAlignment','left',...
                'BackgroundColor',[0.06 0.06 0.08],...
                'ForegroundColor',[0.55 0.55 0.55],'FontSize',8);

            % ---- Window controls ----
            uicontrol('Parent',obj.hFigure,'Style','text',...
                'Units','normalized','Position',[0.06 0.95 0.12 0.03],...
                'String','Window (sec):',...
                'BackgroundColor',[0.10 0.10 0.12],...
                'ForegroundColor',[.7 .7 .7],'FontSize',8,...
                'HorizontalAlignment','right');

            winOptions = {'15','30','60','120','300'};
            uicontrol('Parent',obj.hFigure,'Style','popupmenu',...
                'Units','normalized','Position',[0.19 0.955 0.08 0.025],...
                'String',winOptions,'Value',2,...
                'Callback',@(src,~) obj.setWindow(str2double(winOptions{src.Value})));

            uicontrol('Parent',obj.hFigure,'Style','pushbutton',...
                'Units','normalized','Position',[0.29 0.955 0.08 0.028],...
                'String','Clear Logs',...
                'Callback',@(~,~) obj.clearAll());
        end

        % -----------------------------------------------------------------
        function startRefresh(obj)
            obj.hRefreshTimer = timer(...
                'Name',          obj.OwnTimerTag,...
                'ExecutionMode', 'fixedSpacing',...
                'Period',        obj.RefreshRate,...
                'BusyMode',      'drop',...
                'TimerFcn',      @(~,~) obj.refresh());
            start(obj.hRefreshTimer);
        end

        % -----------------------------------------------------------------
        function refresh(obj)
            if isempty(obj.hFigure) || ~isvalid(obj.hFigure)
                obj.close(); return;
            end

            try
                [names, devices] = obj.getDevices();
                now_t  = now(); %#ok<TNOW1>
                nDev   = numel(names);
                palette = lines(max(nDev,1));

                obj.drawGantt(names, devices, now_t, palette);
                obj.drawDelayPlot(names, devices, now_t, palette);
                obj.drawTable(names, devices);
                obj.updateStatusBar(now_t, nDev);
            catch ME
                if isvalid(obj.hStatusBar)
                    set(obj.hStatusBar,'String',['  Error: ' ME.message]);
                end
            end
        end

        % -----------------------------------------------------------------
        function [names, devices] = getDevices(obj)
            hw = obj.guiRef.Hardware;
            if ~isstruct(hw)
                names = {}; devices = {}; return;
            end
            fnames = fieldnames(hw);
            names   = cell(size(fnames));
            devices = cell(size(fnames));
            for k = 1:numel(fnames)
                dev = hw.(fnames{k});
                if isprop(dev,'Timer') && isvalid(dev.Timer)
                    names{k}   = dev.Timer.Name;
                else
                    names{k}   = fnames{k};
                end
                devices{k} = dev;
            end
        end

        % =================================================================
        %  GANTT TIMELINE
        % =================================================================
        function drawGantt(obj, names, devices, now_t, palette)
            cla(obj.hGanttAxes);
            hold(obj.hGanttAxes, 'on');

            nDev = numel(names);
            if nDev == 0
                text(obj.hGanttAxes, 0.5, 0.5, 'No devices', ...
                     'Color','w','HorizontalAlignment','center','Units','normalized');
                hold(obj.hGanttAxes,'off'); return;
            end

            cutoff = now_t - obj.windowSec / 86400;
            yTick  = [];
            yLabel = {};

            for k = 1:nDev
                dev  = devices{k};
                yPos = nDev - k + 1;
                yTick(end+1)  = yPos; %#ok<AGROW>
                yLabel{end+1} = names{k}; %#ok<AGROW>

                if ~isprop(dev,'profLog'), continue; end
                log = dev.profLog;
                if isempty(log), continue; end

                % Filter to visible window
                mask = log(:,1) >= cutoff;
                log  = log(mask,:);
                if isempty(log), continue; end

                for j = 1:size(log,1)
                    t0  = (log(j,1) - now_t) * 86400;  % seconds ago (negative)
                    dur = log(j,2);
                    st  = log(j,3);

                    % Color by status
                    if st == 1
                        % Check duty cycle for this device
                        period = dev.Timer.Period;
                        if dur / period > obj.warnThresh
                            c = [1 0.3 0.15];   % red — lockup risk
                            obj.addWarning(sprintf('%s: %.3fs / %.1fs period (%.0f%%)', ...
                                names{k}, dur, period, dur/period*100));
                        elseif dur / period > 0.5
                            c = [1 0.85 0.2];   % yellow — high
                        else
                            c = [0.2 0.85 0.4]; % green — normal
                        end
                    elseif st == 0
                        c = [0.4 0.4 0.4];      % gray — disconnected
                    else
                        c = [1 0.15 0.15];       % bright red — error
                        obj.addWarning(sprintf('%s: read ERROR at %s', ...
                            names{k}, datestr(log(j,1),'HH:MM:SS')));
                    end

                    % Draw bar
                    rectangle(obj.hGanttAxes,...
                        'Position', [t0, yPos-0.35, max(dur,0.05), 0.7],...
                        'FaceColor', c, 'EdgeColor', 'none',...
                        'Curvature', [0.3 0.3]);
                end
            end

            % Axes config
            set(obj.hGanttAxes, 'YTick', yTick, 'YTickLabel', yLabel,...
                'TickLabelInterpreter','none','YDir','normal');
            xlim(obj.hGanttAxes, [-obj.windowSec, 2]);
            ylim(obj.hGanttAxes, [0.3, nDev+0.7]);

            % Legend patches
            patch(obj.hGanttAxes, nan,nan,[0.2 0.85 0.4],'DisplayName','Normal');
            patch(obj.hGanttAxes, nan,nan,[1 0.85 0.2], 'DisplayName','>50% duty');
            patch(obj.hGanttAxes, nan,nan,[1 0.3 0.15], 'DisplayName','Lockup risk');
            patch(obj.hGanttAxes, nan,nan,[0.4 0.4 0.4],'DisplayName','Disconnected');
            patch(obj.hGanttAxes, nan,nan,[1 0.15 0.15],'DisplayName','Error');
            legend(obj.hGanttAxes,'show','TextColor','w',...
                'Color',[0.12 0.12 0.14],'EdgeColor',[.3 .3 .3],...
                'Location','northeast','FontSize',7);

            hold(obj.hGanttAxes,'off');
        end

        % =================================================================
        %  ROLLING DELAY PLOT
        % =================================================================
        function drawDelayPlot(obj, names, devices, now_t, palette)
            cla(obj.hDelayAxes);
            hold(obj.hDelayAxes,'on');

            for k = 1:numel(devices)
                dev = devices{k};
                if ~isprop(dev,'profLog'), continue; end
                log = dev.profLog;
                if isempty(log), continue; end

                cutoff = now_t - obj.windowSec / 86400;
                mask   = log(:,1) >= cutoff & log(:,3) == 1;
                vis    = log(mask,:);
                if isempty(vis), continue; end

                t_ago = (vis(:,1) - now_t) * 86400;

                plot(obj.hDelayAxes, t_ago, vis(:,2), '.-',...
                    'Color', palette(k,:), 'LineWidth',1.2,...
                    'MarkerSize',8, 'DisplayName',names{k});

                % Draw period reference line
                if isprop(dev,'Timer') && isvalid(dev.Timer)
                    yline(obj.hDelayAxes, dev.Timer.Period, '--',...
                        'Color', [palette(k,:) 0.35], 'LineWidth',0.8,...
                        'HandleVisibility','off');
                end
            end

            xlim(obj.hDelayAxes, [-obj.windowSec, 2]);
            ylim(obj.hDelayAxes, 'auto');

            if ~isempty(obj.hDelayAxes.Children)
                legend(obj.hDelayAxes,'show','TextColor','w',...
                    'Color',[0.12 0.12 0.14],'EdgeColor',[.3 .3 .3],...
                    'Location','northwest','FontSize',7,...
                    'Interpreter','none');
            end
            hold(obj.hDelayAxes,'off');
        end

        % =================================================================
        %  SUMMARY TABLE
        % =================================================================
        function drawTable(obj, names, devices)
            data = {};
            for k = 1:numel(devices)
                dev = devices{k};

                % Period
                if isprop(dev,'Timer') && isvalid(dev.Timer)
                    period = dev.Timer.Period;
                    running = strcmp(dev.Timer.Running,'on');
                else
                    period = NaN; running = false;
                end

                % Current delay
                if isprop(dev,'read_delay')
                    delay = dev.read_delay;
                else
                    delay = NaN;
                end

                % Duty cycle
                if ~isnan(delay) && ~isnan(period) && period > 0
                    duty = sprintf('%.1f', delay/period*100);
                else
                    duty = '—';
                end

                % Drop count (if available)
                if isprop(dev,'dropCount')
                    drops = dev.dropCount;
                else
                    drops = 0;
                end

                % Status string
                if ~dev.Connected
                    statusStr = 'OFF';
                elseif running
                    statusStr = 'RUN';
                else
                    statusStr = 'STOP';
                end

                delayStr = '—';
                if ~isnan(delay)
                    delayStr = sprintf('%.3f', delay);
                end

                data(end+1,:) = {names{k}, period, delayStr, duty, drops, statusStr}; %#ok<AGROW>
            end

            if ~isempty(data)
                obj.hTable.Data = data;
            else
                obj.hTable.Data = {'No devices','—','—','—','—','—'};
            end
        end

        % =================================================================
        %  HELPERS
        % =================================================================
        function addWarning(obj, msg)
            % Append a timestamped warning to the event log (max 200 entries)
            ts  = datestr(now(),'HH:MM:SS'); %#ok<TNOW1>
            str = sprintf('[%s] %s', ts, msg);

            existing = get(obj.hWarnList, 'String');
            if isempty(existing)
                existing = {};
            elseif ischar(existing)
                existing = {existing};
            end

            % Deduplicate: don't repeat the exact same message consecutively
            if ~isempty(existing) && strcmp(existing{end}, str)
                return;
            end

            existing{end+1} = str;
            if numel(existing) > 200
                existing = existing(end-199:end);
            end
            set(obj.hWarnList, 'String', existing, 'Value', numel(existing));
        end

        function updateStatusBar(obj, now_t, nDev)
            allTimers = timerfind();
            nTimers = 0;
            if ~isempty(allTimers), nTimers = numel(allTimers); end
            set(obj.hStatusBar,'String',...
                sprintf('  %s  |  %d device(s)  |  %d total timer(s)  |  Window: %ds  |  Warn threshold: %.0f%%',...
                    datestr(now_t,'HH:MM:SS'), nDev, nTimers, obj.windowSec, obj.warnThresh*100));
        end

        function setWindow(obj, sec)
            obj.windowSec = sec;
        end

        function clearAll(obj)
            % Clear profiling logs on all devices and the warning list
            try
                hw = obj.guiRef.Hardware;
                if isstruct(hw)
                    fnames = fieldnames(hw);
                    for k = 1:numel(fnames)
                        dev = hw.(fnames{k});
                        if isprop(dev,'clearProfLog')
                            dev.clearProfLog();
                        elseif isprop(dev,'profLog')
                            dev.profLog = zeros(0,3);
                        end
                    end
                end
            catch
            end
            set(obj.hWarnList,'String',{},'Value',1);
        end

        % -----------------------------------------------------------------
        function close(obj)
            try
                if ~isempty(obj.hRefreshTimer) && isvalid(obj.hRefreshTimer)
                    stop(obj.hRefreshTimer);
                    delete(obj.hRefreshTimer);
                end
            catch, end
            try
                if ~isempty(obj.hFigure) && isvalid(obj.hFigure)
                    delete(obj.hFigure);
                end
            catch, end
        end

        function delete(obj)
            obj.close();
        end
    end
end
