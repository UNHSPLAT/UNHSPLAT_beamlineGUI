classdef beamlineMonitor < acquisition
    % TODO: 1 - Test and uncomment hardware-dependent lines
    %FARADAYCUPVSEXBSWEEP Configures and runs a sweep of Faraday cup current vs ExB voltage

    properties (Constant)
        Type string = "Pressure Monitor" % Acquisition type identifier string
    end

    properties (SetAccess = private)
        hFigure % Handle to readings figure
        hAxesP % Handle to pressure readings axes
        hAxesI % Handle to current readings axes
        hAxesV % Handle to voltage readings axes
        Readings struct % Structure containing all readings
        ReadingsListener % Listener for beamlineGUI readings
    end

    methods
        function obj = beamlineMonitor(hGUI)
            %BEAMLINEMONITOR Construct an instance of this class
            obj@acquisition(hGUI);

            % Add listener to delete configuration GUI figure if main beamline GUI deleted
            listener(obj.hBeamlineGUI,'ObjectBeingDestroyed',@obj.beamlineGUIDeleted);

        end

        function runSweep(obj)
            %RUNSWEEP Establishes configuration GUI, with run sweep button triggering actual sweep execution

            % Disable and relabel beamline GUI run test button
            %set(obj.hBeamlineGUI.hRunBtn,'String','Test in progress...');
            %set(obj.hBeamlineGUI.hRunBtn,'Enable','off');

            % Create figures
            obj.hFigure = figure('NumberTitle','off',...
                'Name','Beamline Monitor - Close Window to Exit Test',...
                'Position',[100,100,900,600],...
                'DeleteFcn',@obj.closeFigure);
            try
                % Create axes
                obj.hAxesP = axes(obj.hFigure);
                subplot(2,2,[1 2],obj.hAxesP);
                obj.hAxesI = axes(obj.hFigure);
                subplot(2,2,3,obj.hAxesI);
                obj.hAxesV = axes(obj.hFigure);
                subplot(2,2,4,obj.hAxesV);

                % legend(obj.hAxesP,'Rough Vac','Gas Line','Beamline','Chambe
    
                % Add listener to update data when new readings are taken by main beamlineGUI
                obj.ReadingsListener = listener(obj.hBeamlineGUI,...
                                'LastRead','PostSet',@obj.updateFigures);
                % Initialize Readings with LastRead from beamlineGUI
                obj.Readings = obj.hBeamlineGUI.LastRead;
                % Retrieve config info
                operator = obj.hBeamlineGUI.TestOperator;
                gasType = obj.hBeamlineGUI.GasType;
                testSequence = obj.hBeamlineGUI.TestSequence;
    
                % Save config info
                save(fullfile(obj.hBeamlineGUI.DataDir,'config.mat'),'operator','gasType','testSequence');

            catch MExc

                % Delete figure if error, triggering closeGUI callback
                delete(obj.hFigure);

                % Rethrow caught exception
                rethrow(MExc);

            end

        end

        function beamlineGUIDeleted(obj,~,~)
            %BEAMLINEGUIDELETED Delete configuration GUI figure

            if isvalid(obj) && isvalid(obj.hFigure)
                delete(obj.hFigure);
            end

        end

        function closeFigure(obj,~,~)
            %CLOSEFIGURE Re-enable beamline GUI run test button, plot all data, and delete obj when figure is closed
            
            % Enable beamline GUI run test button if still valid
%             if isvalid(obj.hBeamlineGUI)
%                 set(obj.hBeamlineGUI.hRunBtn,'String','RUN TEST');
%                 set(obj.hBeamlineGUI.hRunBtn,'Enable','on');
%                 obj.mkFigure();
%                 obj.plotVals();
%             end

            % Delete obj
%             readings = obj.Readings;
%             save(fullfile(obj.hBeamlineGUI.DataDir,'beamlineMonitor.mat'),'readings');
            delete(obj.ReadingsListener);
            delete(obj);

        end

    end

    methods (Access = private)
        function mkFigure(obj,~,~)

                 obj.hFigure = figure('NumberTitle','off',...
                'Name','Beamline Monitor - Close Window to Exit Test',...
                'Position',[100,100,900,600],...
                'DeleteFcn',@obj.closeFigure);
                % Create axes
                obj.hAxesP = axes(obj.hFigure);
                subplot(2,2,[1 2],obj.hAxesP);
                obj.hAxesI = axes(obj.hFigure);
                subplot(2,2,3,obj.hAxesI);
                obj.hAxesV = axes(obj.hFigure);
                subplot(2,2,4,obj.hAxesV);
        end
        
        function plotVals(obj)
            if isvalid(obj)
                hold(obj.hAxesP,'on');
                hold(obj.hAxesV,'on');
                fields = fieldnames(obj.hBeamlineGUI.Monitors);
                p_ledge = {};
                v_ledge = {};
                time = [obj.Readings.dateTime];
                %define time range to plot 
                % (plot range can be extended with the fractional day value
                %   being subtracted)
                log_plot = time>max(time)-.01;
                for i =1:numel(fields)
                    group = obj.hBeamlineGUI.Monitors.(fields{i}).group;
                    val = [obj.Readings.(fields{i})];
                    if strcmp(group,"pressure")
                        plot(obj.hAxesP,time(log_plot),...
                                        val(log_plot));
                        p_ledge{end+1} = strrep(fields{i},'pressure','');
                    elseif strcmp(group,"HV")
                        plot(obj.hAxesV,time(log_plot),...
                                        val(log_plot))
                        v_ledge{end+1} = strrep(fields{i},'volt','');
                    end
                end
                hold(obj.hAxesP,'off');
                hold(obj.hAxesV,'off');
                plot(obj.hAxesI,[obj.Readings.T],...
                                [obj.Readings.Ifaraday],'r-');
    
                legend(obj.hAxesP,p_ledge,'Location','northwest');
                legend(obj.hAxesV,v_ledge,'Location','northwest');
    
                set(obj.hAxesP,'YScale','log');
                %datetick(obj.hAxesP,'x','HH:MM:SS');
                ylabel(obj.hAxesP,'Pressure [torr]');
                title(obj.hAxesP,'System Pressure');
    
                %datetick(obj.hAxesI,'x','HH:MM:SS');
                ylabel(obj.hAxesI,'I_{Faraday} [A]');
                title(obj.hAxesI,'Beam Current');
    
                %datetick(obj.hAxesV,'x','HH:MM:SS');
                ylabel(obj.hAxesV,'Voltage [V]');
                title(obj.hAxesV,'Optics Voltage');
                set(obj.hAxesV,'YScale','log');
            end
        end

        function updateFigures(obj,~,~)

            % Check that a new timestamp was recorded

            if obj.Readings(end).T ~= obj.hBeamlineGUI.LastRead.T
                try
                    % Append LastRead to Readings property
                    obj.Readings(end+1) = obj.hBeamlineGUI.LastRead;

                    % Update pressure monitor
                    obj.plotVals()

                    % Append new data to file
%                     readings = obj.Readings;
%                     save(fullfile(obj.hBeamlineGUI.DataDir,'beamlineMonitor.mat'),'readings');
    
                catch MExc
    
                    % Delete figure if error, triggering closeGUI callback
                    delete(obj.hFigure);
    
                    % Rethrow caught exception
                    rethrow(MExc);
    
                end

            end

        end

    end

end