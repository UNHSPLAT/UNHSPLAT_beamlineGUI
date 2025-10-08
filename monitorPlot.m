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
        yvals = []
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
                % Add to data arrays
                obj.xvals(end+1) = xval;
                obj.yvals(end+1) = yval;
                
                % Keep only last 1000 points to prevent memory issues
                if length(obj.xvals) > 1000
                    obj.xvals = obj.xvals(end-999:end);
                    obj.yvals = obj.yvals(end-999:end);
                end
                
                % Update plot
                plot(obj.ax, obj.xvals, obj.yvals, 'b.-');

                xlabel(obj.ax, obj.hGUI.Monitors.(obj.xMonStr).sPrint());
                ylabel(obj.ax, obj.hGUI.Monitors.(obj.yMonStr).sPrint());
                grid(obj.ax, 'on');
                
                % Update title with current values
                title(obj.ax, sprintf('Current: [x,y]= [%s, %s]', ...
                    obj.hGUI.Monitors.(obj.xMonStr).sPrintVal(), ...
                    obj.hGUI.Monitors.(obj.yMonStr).sPrintVal()));
            end
            catch
                % delete(obj.listo);
                fprintf('[%s,%s] MonPlot Failed\n', ...
                    obj.hGUI.Monitors.(obj.xMonStr).sPrint(), ...
                    obj.hGUI.Monitors.(obj.yMonStr).sPrint());
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