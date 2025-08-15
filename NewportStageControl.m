classdef NewportStageControl < handle

    properties
        Tag string =""%
        textLabel string = ""% 
        unit string = ""%
        asmInfo %
    end

    properties (SetObservable) 
        Timer=timer%
        Connected%
        lastRead%
    end

    methods
        function obj = NewportStageControl(varargin)
            % Initialize control
            obj.Connected = false;
            obj.Tag = '3axisNewportStage';
            obj.lastRead = nan;
            % initialize timer to grab position data
            obj.Timer =  timer('Period',1,... %period
                      'ExecutionMode','fixedSpacing',... %{singleShot,fixedRate,fixedSpacing,fixedDelay}
                      'BusyMode','drop',... %{drop, error, queue}
                      'StartDelay',0,...
                      'TimerFcn',@obj.read ...
                      );
        end

        function val = read(obj)
            if obj.Connected
                val = obj.lastRead;
            else
                val = nan;
            end
        end

        function shutdown(obj,~,~)
            if obj.Connected
                
                stop(obj.Timer);
                obj.Connected = false;
                obj.lastRead = nan;
            end
        end

        function connectDevice(obj)
            % Dummy function to allow for structure to work as a hwDevice.
        end

        function restart(obj,~,~)
            obj.shutdown();
            obj.run();
        end
        
        function restartTimer(obj)
            %RESTARTTIMER Restarts timer if error

            % Stop timer if still running
            if strcmp(obj.Timer.Running,'on')
                stop(obj.Timer);
            end

            % Restart timer
            if obj.Connected
                start(obj.Timer);
            end
        end

        function stopTimer(obj)
            % Stop timer if still running
            if strcmp(obj.Timer.Running,'on')
                stop(obj.Timer);
            end
        end

        function delete(obj)
            % Delete the webcam object
            obj.shutdown();
        end

    end
end


