classdef monitorPlot < handle
    % TODO: 1 - Test and uncomment hardware-dependent lines
    %FARADAYCUPVSEXBSWEEP Configures and runs a sweep of Faraday cup current vs ExB voltage

    properties (Constant)
        Type string = "Pressure Monitor" % Acquisition type identifier string
    end

    properties (SetAccess = private)
        Readings struct % Structure containing all readings
        ReadingsListener % Listener for beamlineGUI readings
        xMonStr%
        yMonStr%
        xvals = []%
        yvals = {}  % Cell array to store multiple y-value arrays
        numYvals = 0  % Number of y-values to track
        panel%
        ax%
        hGUI %
        listo
    end

    methods
        function obj = monitorPlot(hGUI,panel,xMonStr,yMonStr)
            %BEAMLINEMONITOR Construct an instance of this class
            obj.hGUI = hGUI;
            obj.panel = panel;
            obj.xMonStr = xMonStr;
            obj.yMonStr = yMonStr;
            
            
            % Create and position the new axis
            obj.ax = obj.addAxes();
            axtoolbar(obj.ax,{'zoomin','zoomout','restoreview','pan','datacursor','export'});

            grid(obj.ax, 'on');
            
            % Get the axes position
            axPos = get(obj.ax, 'Position');
            
            % Create a single checkbox for log scale, positioned relative to the axes
            uicontrol('Parent', obj.panel,...
                'Style', 'checkbox',...
                'String', 'Log Scale',...
                'Units', 'normalized',...
                'Position', [axPos(1) axPos(2)-0.04 0.1 0.03],... % Position below the axes
                'Value', 0,... % Start with linear scale
                'Callback', @(~,~)obj.yScaleChanged());
            
            % Add listener for y monitor value changes
            obj.listo = addlistener(obj.hGUI.Monitors.(obj.yMonStr), 'lastRead', 'PostSet', @(src,evt)obj.pltVal());
            
            % Initial plot
            obj.pltVal();
        end
        
        function pltVal(obj)
            try
                % Get current values
                xval = obj.hGUI.Monitors.(obj.xMonStr).lastRead;
                yval = obj.hGUI.Monitors.(obj.yMonStr).lastRead;
                
                if ~isempty(xval) && ~isempty(yval)
                    % Initialize arrays if this is the first data point
                    if isempty(obj.yvals)
                        obj.numYvals = length(yval);
                        obj.yvals = cell(1, obj.numYvals);
                        for i = 1:obj.numYvals
                            obj.yvals{i} = [];
                        end
                    end
                    
                    % Add x value
                    obj.xvals(end+1) = xval;
                    
                    % Add y values
                    if isscalar(yval)
                        % If scalar, add to first line only
                        obj.yvals{1}(end+1) = yval;
                        for i = 2:obj.numYvals
                            obj.yvals{i}(end+1) = NaN;  % Fill others with NaN
                        end
                    else
                        % Add each element of yval to its corresponding array
                        for i = 1:obj.numYvals
                            if i <= length(yval)
                                obj.yvals{i}(end+1) = yval(i);
                            else
                                obj.yvals{i}(end+1) = NaN;  % Fill missing values with NaN
                            end
                        end
                    end
                    
                    % Keep only last 1000 points to prevent memory issues
                    if length(obj.xvals) > 1000
                        obj.xvals = obj.xvals(end-999:end);
                        for i = 1:obj.numYvals
                            obj.yvals{i} = obj.yvals{i}(end-999:end);
                        end
                    end
                    
                    % Clear the axes
                    cla(obj.ax);
                    
                    % Plot each line with a different color
                    colors = {'b', 'r', 'g', 'm', 'c', 'k', 'y'};  % Color cycle
                    hold(obj.ax, 'on');
                    for i = 1:obj.numYvals
                        color_idx = mod(i-1, length(colors)) + 1;
                        plot(obj.ax, obj.xvals, obj.yvals{i}, [colors{color_idx} '.-']);
                    end
                    hold(obj.ax, 'off');

                    xlabel(obj.ax, obj.hGUI.Monitors.(obj.xMonStr).sPrint());
                    ylabel(obj.ax, obj.hGUI.Monitors.(obj.yMonStr).sPrint());
                    
                    % Update title with current values
                    if obj.numYvals == 1
                        titleStr = sprintf('Current: [x,y]= [%s, %s]', ...
                            obj.hGUI.Monitors.(obj.xMonStr).sPrintVal(), ...
                            obj.hGUI.Monitors.(obj.yMonStr).sPrintVal());
                    else
                        titleStr = sprintf('Current: x=%s, y=[', ...
                            obj.hGUI.Monitors.(obj.xMonStr).sPrintVal());
                        yvals = obj.hGUI.Monitors.(obj.yMonStr).lastRead;
                        for i = 1:length(yvals)
                            if i > 1
                                titleStr = [titleStr, ', '];
                            end
                            titleStr = [titleStr, sprintf('%.3g', yvals(i))];
                        end
                        titleStr = [titleStr, ']'];
                    end
                    title(obj.ax, titleStr);
                end
            catch
                % delete(obj.listo);
                fprintf('[%s,%s] MonPlot Failed\n', ...
                    obj.hGUI.Monitors.(obj.xMonStr).sPrint(), ...
                    obj.hGUI.Monitors.(obj.yMonStr).sPrint());
            end
        end
        
        function yScaleChanged(obj)
            %YSCALECHANGED Callback for y-axis scale checkbox
            if get(gcbo, 'Value') % If checkbox is checked
                set(obj.ax, 'YScale', 'log');
            else
                set(obj.ax, 'YScale', 'linear');
            end
        end

        function ax = addAxes(obj)
            % ADDAXES Creates a new axis in the panel and adjusts layout of existing axes
            %   ax = obj.addAxes() adds a new axis to the panel and returns its handle.
            %   The function automatically arranges all axes in a grid layout to prevent
            %   overlap.
            
            % Find existing axes in the panel
            existing_axes = findall(obj.panel, 'Type', 'axes');
            num_axes = length(existing_axes);
            
            % Calculate grid layout based on number of plots
            num_rows = ceil(sqrt(num_axes + 1));  % +1 for the new axis
            num_cols = ceil((num_axes + 1) / num_rows);
            
            % Define margins and spacing
            margin = 0.08;  % 8% margin around edges
            spacing = 0.08; % 8% spacing between plots

            % Calculate available space after margins
            available_width = 1 - 2*margin;
            available_height = 1 - 2*margin;
            
            % Calculate plot dimensions including spacing
            plot_width = (available_width - (num_cols-1)*spacing) / num_cols;
            plot_height = (available_height - (num_rows-1)*spacing) / num_rows;
            
            % Reposition existing axes
            for i = 1:num_axes
                col = mod(i-1, num_cols);
                row = floor((i-1) / num_cols);
                
                x_pos = margin + col * (plot_width + spacing);
                y_pos = 1 - margin - plot_height - row * (plot_height + spacing);
                
                pos = [x_pos, y_pos, plot_width, plot_height];
                set(existing_axes(i), 'Position', pos);
            end
            
            % Create and position new axis
            ax = axes(obj.panel);
            col = mod(num_axes, num_cols);
            row = floor(num_axes / num_cols);
            
            x_pos = margin + col * (plot_width + spacing);
            y_pos = 1 - margin - plot_height - row * (plot_height + spacing);
            
            pos = [x_pos, y_pos, plot_width, plot_height];
            set(ax, 'Position', pos);
        end

    end

end