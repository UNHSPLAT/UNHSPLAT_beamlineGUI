classdef NewportStageControl < handle

    properties
        Tag string =""%
        textLabel string = ""% 
        unit string = ""%
        address string = ""%
        asmInfo %
        groups = ["Group1","Group2","Group3"] % Define the group names for the stage
        group_status = [0,0,0]
    end

    properties (SetObservable) 
        Timer=timer%
        Connected%
        lastRead%
        myxps
    end

    methods
        function obj = NewportStageControl(address,groups)
            % Initialize control
            obj.Connected = false;
            obj.Tag = '3axisNewportStage';
            
            obj.address = address;
            if nargin >1
                obj.groups = groups;
            end
            obj.lastRead = zeros(1,length(obj.groups))*nan;
                
            % initialize timer to grab position data at some cadence
            obj.Timer =  timer('Period',1,... %period
                      'ExecutionMode','fixedSpacing',... %{singleShot,fixedRate,fixedSpacing,fixedDelay}
                      'BusyMode','drop',... %{drop, error, queue}
                      'StartDelay',0,...
                      'TimerFcn',@obj.read ...
                      );
            try
                obj.asmInfo = NET.addAssembly('Newport.XPS.CommandInterface');
                obj.myxps = CommandInterfaceXPS.XPS();
            catch 
                warning('Newport Stage not integrated');
                obj.Connected = false;
            end
            
        end

        function val = read(obj,~,~)
            obj.lastRead=obj.getAllPositions();
            val = obj.lastRead;
        end

        function shutdown(obj,~,~)
                if isvalid(obj.myxps)
                    things = obj.myxps.KillAll();
                    obj.myxps.CloseInstrument;
                end
                stop(obj.Timer);
                obj.Connected = false;
                obj.lastRead = nan;
        end

        function connectDevice(obj)
            obj.initDevice();
            obj.home();
            start(obj.Timer);
        end

        function initDevice(obj)
            if ~ obj.Connected
                if ~isempty(obj.myxps)
                    open_code=obj.myxps.OpenInstrument(obj.address,5001,1000);
                    if open_code == 0
                        init_codes = NaN(1,length(obj.groups));
                        for i = 1:length(obj.groups)
                            gp = obj.groups(i);
                            code=obj.myxps.GroupInitialize(gp);
                            init_codes(i) = code;
                            if code ~= 0
                                fprintf('Failed to initialize group %s\n', gp);
                            end
                        end
                        display(init_codes);

                        obj.group_status = ~init_codes;
                        if ~all(init_codes)
                            obj.Connected = true;
                        end
                    else
                        warning('Failed to connect to Newport XPS stage: %s', obj.myxps.GetErrorMessage(open_code));
                    end
                end
            end
        end

        function restart(obj,~,~)
            obj.shutdown();
            obj.initDevice();
            obj.home();
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
                for i = 1:length(obj.groups)
                    if obj.group_status(i)
                        [code,err] = obj.myxps.GroupHomeSearch(char(obj.groups(i)));
                        
                        if code ~= 0
                            warning('Failed to home stage: %s', err);
                        end
                    end
                end
            else
                warning('Device not connected');
            end
        end

        % Set and get position methods
        function setPosition(obj,group,position)
            run_status = obj.Timer.Running;
            if obj.Connected
                code = obj.myxps.GroupMoveAbsolute(group,position,1);
                if code ~= 0
                    warning('Failed to set position: %s', code);
                end
            else
                warning('Device not connected');
            end
        end
        
        function val = getPosition(obj,group)
            if obj.Connected
                % For some reason calling the group position on just the group followed by the pos
                % prevents error state
                obj.myxps.GroupPositionCurrentGet(char(group),1);
                [err,vals,errnum] = obj.myxps.GroupPositionCurrentGet([char(group),'.pos'],1);
                val = vals.double; 
                code = err;
                if code ~= 0
                    fprintf('Failed to get position: %s', errnum);
                end
            else
                val = nan;
            end
        end

        function positions = getAllPositions(obj)
            if obj.Connected()
                % positions = obj.myxps.getCurrentPosition();
                positions = zeros(1, length(obj.groups))*nan;
                for i = 1:length(obj.groups)
                    if obj.group_status(i)
                        positions(i) = obj.getPosition(obj.groups(i));
                    end
                end    
            else
                positions = zeros(1, length(obj.groups))*nan;
            end
        end

    end
end


