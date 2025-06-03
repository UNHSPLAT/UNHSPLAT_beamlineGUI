classdef camControl < handle

    properties
        Tag string =""%
        textLabel string = ""% 
        unit string = ""%
    end

    properties (SetObservable) 
        figmanager%
        datamanager%
        uimanager%
        Timer%
        cam%
        Connected%
        lastRead%
    end

    methods
        function obj = camControl(varargin)
            % Initialize Webcam
            obj.Connected = false;
            obj.Tag = 'MCPcam';
            obj.lastRead = nan;
        end

        function run(obj,~,~)
            try obj.cam = webcam; %cam.ColorEnable = 0;
            catch
                link = 'https://www.mathworks.com/matlabcentral/fileexchange/45182-matlab-support-package-for-usb-webcams';
                error(['Missing MATLAB Support Package for USB Webcams!' ...
                    '\nSee <a href="' link '">' link '</a> for installation information%s'],"")
            end
            
            if ~isfolder("input\")
                mkdir input\
            end
            addpath(genpath('.'));
            % Initialize Figure, UI, and Data Manager objects
            obj.figmanager = FigureManager(obj.cam);
            obj.uimanager = UIManager(obj.cam);
            obj.datamanager = DataManager(obj.figmanager,obj.uimanager,obj.cam);

            connectComponents(obj.uimanager,obj.figmanager,obj.datamanager);
            
            % Test if using supported gpu
            try
                gpuDevice;
                obj.datamanager.gpuSupport = true;
                warning("NVIDIA GPU Detected, activated GPU acceleration")
            catch
                obj.datamanager.gpuSupport = false;
            end
            
            % Run Main Loop
            obj.datamanager.setupPreview;
            
            % initialize timer to execute peakfinding
            obj.Timer =  timer('Period',.5,... %period
                      'ExecutionMode','fixedSpacing',... %{singleShot,fixedRate,fixedSpacing,fixedDelay}
                      'BusyMode','queue',... %{drop, error, queue}
                      'StartDelay',0,...
                      'TimerFcn',@obj.update ...
                      );

            start(obj.Timer);
            obj.Connected = true;
        end

        function update(obj,~,~)
            if obj.Connected
                obj.datamanager.mainLoop;
                obj.lastRead = obj.datamanager.CountRate;
            else
                obj.lastRead = nan;
            end
        end

        function val = read(obj);
            if obj.Connected
                val = obj.lastRead;
            else
                val = nan;
            end
        end

        function shutdown(obj,~,~)
            if obj.Connected
            close(obj.figmanager.RecordingFigure);
            close(obj.figmanager.RateGraphFigure);
            close(obj.figmanager.PreviewFigure);
            close(obj.uimanager.WebcamUIFigure);
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

    end
end


