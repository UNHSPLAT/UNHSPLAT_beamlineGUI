classdef NewportStageControl < handle

    properties
        Tag string =""%
        textLabel string = ""% 
        unit string = ""%
        address string = ""%
        asmInfo %
        groups = ["Group1","Group2","Group3"] % Define the group names for the stage
    end

    properties (SetObservable) 
        Timer=timer%
        Connected%
        lastRead%
        myxps
    end

    methods
        function obj = NewportStageControl(address)
            % Initialize control
            obj.Connected = false;
            obj.Tag = '3axisNewportStage';
            obj.lastRead = nan;
            obj.address = address;

            % initialize timer to grab position data at some cadence
            obj.Timer =  timer('Period',1,... %period
                      'ExecutionMode','fixedSpacing',... %{singleShot,fixedRate,fixedSpacing,fixedDelay}
                      'BusyMode','drop',... %{drop, error, queue}
                      'StartDelay',0,...
                      'TimerFcn',@obj.read ...
                      );

            obj.asmInfo = NET.addAssembly('Newport.XPS.CommandInterface');
            obj.myxps = CommandInterfaceXPS.XPS();
        end

        function val = read(obj)
            obj.lastRead=getAllPositions();
            val = obj.lastRead;
        end

        function shutdown(obj,~,~)
            if obj.Connected
                if isvalid(obj.myxps)
                    obj.myxps.Groupkill('Group1');
                    obj.myxps.CloseInstrument;
                end
                stop(obj.Timer);
                obj.Connected = false;
                obj.lastRead = nan;
            end
        end

        function connectDevice(obj)
            if ~ obj.Connected
                code=obj.myxps.OpenInstrument(obj.address,5001,1000);
                if code == 0
                    obj.Timer.StartDelay = 0.1; % start after a short delay
                    start(obj.Timer);
                    for i = 1:length(obj.groups)
                        gp = obj.groups(i);
                        code=obj.myxps.GroupInitialize(gp);
                        if code ~= 0
                            warning('Failed to initialize group %s: %s', gp, obj.myxps.GetErrorMessage(code));
                            obj.Connected = false;
                            return;
                        end
                    end
                    obj.Connected = true;
                else
                    warning('Failed to connect to Newport XPS stage: %s', obj.myxps.GetErrorMessage(code));
                end
            end
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

        function home(obj)
            if obj.Connected
                code = obj.myxps.GroupHome('Group1');
                if code ~= 0
                    warning('Failed to home stage: %s', obj.myxps.GetErrorMessage(code));
                end
            else
                warning('Device not connected');
            end
        end

        % Set and get position methods
        function setPosition(obj,group,position)
            if obj.myxps.IsDeviceConnected()
                code = obj.myxps.GroupMoveAbsolute(group,position);
                if code ~= 0
                    warning('Failed to set position: %s', obj.myxps.GetErrorMessage(code));
                end
            else
                obj.Connected = false;
                warning('Device not connected');
            end
        end
        
        function val = getPosition(obj,group,nbItems)
            if obj.myxps.IsDeviceConnected()
                output = obj.myxps.GroupPositionCurrentGet(group,nbItems);
                % val,code = obj.myxps.GroupPositionTargetGet('Group1');
                % allPositions = obj.myxps.getCurrentPosition();
                val = output(1); 
                code = output(2);
                if code ~= 0
                    warning('Failed to get position: %s', obj.myxps.GetErrorMessage(code));
                end
            else
                obj.Connected = false;
                warning('Device not connected');
                val = nan;
            end
        end

        function positions = getAllPositions(obj)
            if obj.myxps.IsDeviceConnected()
                % positions = obj.myxps.getCurrentPosition();
                positions = zeros(1, length(obj.groups));
                for i = 1:length(obj.groups)
                    positions(i) = obj.getPosition(obj.groups(i),1);
                end    
            else
                obj.Connected = false;
                warning('Device not connected');
                positions = zeros(1, length(obj.groups))*nan;
            end
        end

    end
end


