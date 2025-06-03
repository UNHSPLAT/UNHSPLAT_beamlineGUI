classdef Sweep1d < acquisition
    %Sweep1d Configures and runs a sweep of Faraday cup current vs selectable voltage supply

    properties (Constant)
        Type string = "Sweep 1D" % Acquisition type identifier string
        MinDefault double = 100 % Default minimum voltage
        MaxDefault double = 300 % Default maximum voltage
        StepsDefault double = 4 % Default number of steps
        DwellDefault double = 1 % Default dwell time
        % PSList string = ["ExB","ESA","Defl","Ysteer"] % List of sweep supplies
    end

    properties
        PSTag string % String identifying user-selected HVPS
        resultTag string % String identifying user-selected HVPS

        hHVPS % Handle to desired power supply
        hConfFigure % Handle to configuration GUI figure
        hFigure1 % Handle to I-V data plot
        hFigure2 % Handle to I-1/V^2 data plot
        hAxes1 % Handle to I-V data axes
        hAxes2 % Handle to I-1/V^2 data axes
        hSupplyText % Handle to sweep supply label
        hSupplyEdit % Handle to sweep supply field
        hResultText % Handle to Result Readout label
        hResultEdit % Handle to Result readout field
        
        hMinText % Handle to minimum voltage label
        hMinEdit % Handle to minimum voltage field
        hStepsText % Handle to number of steps label
        hStepsEdit % Handle to number of steps field
        hSpacingEdit % Handle to log spacing checkbox
        hMaxText % Handle to maximum voltage label
        hMaxEdit % Handle to maximum voltage field
        hDwellText % Handle to dwell time label
        hDwellEdit % Handle to dwell time field
        hSweepBtn % Handle to run sweep button
        VPoints double % Array of ExB voltage setpoints
        DwellTime double % Dwell time setting
        PSList %
        resultList %

        scanTimer timer%
        scan_mon %
        listo%
    end

    methods
        function obj = Sweep1d(hGUI)
            %FARADAYCUPVSEXBSWEEP Construct an instance of this class

            obj@acquisition(hGUI);
            
            % Add listener to delete configuration GUI figure if main beamline GUI deleted
            listener(obj.hBeamlineGUI,'ObjectBeingDestroyed',@obj.beamlineGUIDeleted);
        end

        function runSweep(obj)
            %RUNSWEEP Establishes configuration GUI, with run sweep button triggering actual sweep execution

            % Disable and relabel beamline GUI run test button
            set(obj.hBeamlineGUI.hRunBtn,'Enable','off');
            set(obj.hBeamlineGUI.hRunBtn,'String','Test in progress...');
            
            % Create figure
            obj.hConfFigure = figure('MenuBar','none',...
                'ToolBar','none',...
                'Resize','off',...
                'Position',[400,160,300,240],...
                'NumberTitle','off',...
                'Name','Sweep Config',...
                'DeleteFcn',@obj.closeGUI);

            % get active and unactive monitors for scanning
            function tag = get_active(mon)
                if mon.active
                    obj.PSList(end+1) = mon.Tag;
                else
                    obj.resultList(end+1) = mon.Tag;
                end
            end

            obj.PSList = [""];
            obj.resultList = [""];

            structfun(@get_active,obj.hBeamlineGUI.Monitors);

            
            % Set positions
            ystart = 210;
            ypos = ystart;
            ysize = 20;
            xpos = 150;
            xtextsize = 100;
            xeditsize = 60;

            obj.hSupplyText = uicontrol(obj.hConfFigure,'Style','text',...
                'Position',[xpos-xtextsize,ystart,xtextsize,ysize],...
                'String','Sweep Supply: ',...
                'FontSize',9,...
                'HorizontalAlignment','right');
            obj.hSupplyEdit = uicontrol(obj.hConfFigure,'Style','popupmenu',...
                'Position',[xpos,ystart,xeditsize,ysize],...
                'String',obj.PSList,...
                'Value',10,...
                'HorizontalAlignment','right');
            
            ypos = ypos-ysize;

            obj.hResultText = uicontrol(obj.hConfFigure,'Style','text',...
                'Position',[xpos-xtextsize,ypos,xtextsize,ysize],...
                'String','Plot Value: ',...
                'FontSize',9,...
                'HorizontalAlignment','right');
            obj.hResultEdit = uicontrol(obj.hConfFigure,'Style','popupmenu',...
                'Position',[xpos,ypos,xeditsize,ysize],...
                'String',obj.resultList,...
                'Value',10,...
                'HorizontalAlignment','right');
            
            
            % Set positions
            ystart = 155;
            ypos = ystart;
            ysize = 20;
            ygap = 16;
            xpos = 30;
            xtextsize = 100;
            xeditsize = 60;
            
            % Create components
            obj.hMinText = uicontrol(obj.hConfFigure,'Style','text',...
                'Position',[xpos,ypos,xtextsize,ysize],...
                'String','Min Voltage [V]: ',...
                'FontSize',8,...
                'HorizontalAlignment','center');
            
            ypos = ypos-ysize;
            
            obj.hMinEdit = uicontrol(obj.hConfFigure,'Style','edit',...
                'Position',[xpos+(xtextsize-xeditsize)/2,ypos,xeditsize,ysize],...
                'String',num2str(obj.MinDefault),...
                'HorizontalAlignment','right');
            
            ypos = ypos-ysize-ygap;
            
            obj.hStepsText = uicontrol(obj.hConfFigure,'Style','text',...
                'Position',[xpos,ypos,xtextsize,ysize],...
                'String','Number of Steps: ',...
                'FontSize',8,...
                'HorizontalAlignment','center');
            
            ypos = ypos-ysize;
            
            obj.hStepsEdit = uicontrol(obj.hConfFigure,'Style','edit',...
                'Position',[xpos+(xtextsize-xeditsize)/2,ypos,xeditsize,ysize],...
                'String',num2str(obj.StepsDefault),...
                'HorizontalAlignment','right');
            
            ypos = ypos-ysize*2;
            
            obj.hSpacingEdit = uicontrol(obj.hConfFigure,'Style','checkbox',...
                'Position',[xpos-10,ypos,xtextsize+20,ysize],...
                'String',' Logarithmic Spacing',...
                'Value',0,...
                'HorizontalAlignment','right');
            
            ypos = ystart;
            xpos = 170;
            
            obj.hMaxText = uicontrol(obj.hConfFigure,'Style','text',...
                'Position',[xpos,ypos,xtextsize,ysize],...
                'String','Max Voltage [V]: ',...
                'FontSize',8,...
                'HorizontalAlignment','center');
            
            ypos = ypos-ysize;
            
            obj.hMaxEdit = uicontrol(obj.hConfFigure,'Style','edit',...
                'Position',[xpos+(xtextsize-xeditsize)/2,ypos,xeditsize,ysize],...
                'String',num2str(obj.MaxDefault),...
                'HorizontalAlignment','right');
            
            ypos = ypos-ysize-ygap;
            
            obj.hDwellText = uicontrol(obj.hConfFigure,'Style','text',...
                'Position',[xpos,ypos,xtextsize,ysize],...
                'String','Dwell Time [s]: ',...
                'FontSize',8,...
                'HorizontalAlignment','center');
            
            ypos = ypos-ysize;
            
            obj.hDwellEdit = uicontrol(obj.hConfFigure,'Style','edit',...
                'Position',[xpos+(xtextsize-xeditsize)/2,ypos,xeditsize,ysize],...
                'String',num2str(obj.DwellDefault),...
                'HorizontalAlignment','right');
            
            ypos = ypos-ysize*2-ygap;
            
            obj.hSweepBtn = uicontrol(obj.hConfFigure,'Style','pushbutton',...
                'Position',[xpos,ypos,xtextsize,ysize+ygap],...
                'String','RUN SWEEP',...
                'FontSize',10,...
                'FontWeight','bold',...
                'HorizontalAlignment','center',...
                'Callback',@obj.sweepBtnCallback);

        end

        function beamlineGUIDeleted(obj,~,~)
            %BEAMLINEGUIDELETED Delete configuration GUI figure

            if isvalid(obj) && isvalid(obj.hConfFigure)
                delete(obj.hConfFigure);
            end
            
        end
    end

    methods (Access = private)

        function sweepBtnCallback(obj,~,~)
            %SWEEPBTNCALLBACK Begin sweep execution based on configuration info
            
            % Run inside a try-catch to reset beamline GUI run test button if error occurs
            try
    
                % Retrieve config values
                psTag = obj.PSList(obj.hSupplyEdit.Value);
                obj.resultTag = obj.resultList(obj.hResultEdit.Value);
                minVal = str2double(obj.hMinEdit.String);
                maxVal = str2double(obj.hMaxEdit.String);
                stepsVal = str2double(obj.hStepsEdit.String);
                dwellVal = str2double(obj.hDwellEdit.String);
    
                % % Error checking
                if isnan(minVal) || isnan(maxVal) || isnan(stepsVal) || isnan(dwellVal) || isempty(psTag)
                    errordlg('All fields must be filled with a valid numeric entry!','User input error!');
                    return
                elseif minVal > maxVal || minVal < 0 || maxVal < 0
                    errordlg('Invalid min and max voltages! Must be increasing positive values.','User input error!');
                    return
                elseif dwellVal <= 0
                    errordlg('Invalid dwell time! Must be a positive value.','User input error!');
                    return
                elseif uint64(stepsVal) ~= stepsVal || ~stepsVal
                    errordlg('Invalid number of steps! Must be a positive integer.','User input error!');
                    return
                end
    
                % Determine log vs linear spacing
                logSpacing = logical(obj.hSpacingEdit.Value);

                % Retrieve config info
                operator = obj.hBeamlineGUI.TestOperator;
                gasType = obj.hBeamlineGUI.GasType;
                testSequence = obj.hBeamlineGUI.TestSequence;
    
                % Create voltage setpoint array
                if logSpacing
                    vPoints = logspace(log10(minVal),log10(maxVal),stepsVal);
                else
                    vPoints = linspace(minVal,maxVal,stepsVal);
                end
                % Reshape to square output
                obj.VPoints = reshape(vPoints,1,[]);

                % Save config info
                save(fullfile(obj.hBeamlineGUI.DataDir,'config.mat'),'vPoints','minVal','maxVal','stepsVal','dwellVal','logSpacing','operator','gasType','testSequence');
    
                % Set DwellTime property
                obj.DwellTime = dwellVal;
    
                % Set config figure to invisible
                set(obj.hConfFigure,'Visible','off');

                % Stop beamline timer (timer callback executed manually during test)
                stop(obj.hBeamlineGUI.hTimer);

                % Create figures and axes
                obj.hFigure1 = figure('NumberTitle','off',...
                                      'Name','Voltage Sweep',...
                                      'DeleteFcn',@obj.closeGUI);
                obj.hAxes1 = axes(obj.hFigure1);

                % Preallocate arrays
                obj.scan_mon = struct();
                fields = fieldnames(obj.hBeamlineGUI.Monitors);
                for i=1:numel(fields)
                    tag = fields{i};
                    monitor = obj.hBeamlineGUI.Monitors.(tag);
                    if contains(monitor.formatSpec,'%s')
                        obj.scan_mon.(tag)=strings(length(obj.VPoints),1);
                    else
                        obj.scan_mon.(tag) = zeros(length(obj.VPoints),1);
                    end
                end
                
                iV = 0;
                % Listener to sample measurements after voltage ramp and
                % dwell time
                obj.listo = listener(obj.hBeamlineGUI.Monitors.(psTag),'lock',...
                                                 'PostSet',...
                                                    @read_buffer);
                % trigger voltage ramp
                scan_step();

            catch MExc
                % Delete figure if error, triggering closeGUI callback
                delete(obj.hConfFigure);
                % Rethrow caught exception
                rethrow(MExc);

            end

                           % Run sweep
            function scan_step(varargin)
                iV=iV+1;
                if isempty(obj.hFigure1) || ~isvalid(obj.hFigure1)
                    obj.hFigure1 = figure('NumberTitle','off',...
                        'Name','Voltage sweep');
                    obj.hAxes1 = axes(obj.hFigure1); %#ok<LAXES> Only executed if figure deleted or not instantiated
                end

                fprintf('Setting voltage to %.2f V...\n',obj.VPoints(iV));
                obj.hBeamlineGUI.Monitors.(psTag).set(obj.VPoints(iV));    
            end

            function read_buffer(varargin)
                tRead = timer('ExecutionMode','singleShot',...
                'StartDelay',obj.DwellTime,...
                'TimerFcn',@read_results);
                 start(tRead);
            end

            function read_results(varargin)
                if ~obj.hBeamlineGUI.Monitors.(psTag).lock
                    % Wait for voltage ramp to complete

                    % Obtain readings
                    fname = fullfile(obj.hBeamlineGUI.DataDir,[strrep(sprintf('%s_%.2fV',psTag,obj.VPoints(iV)),'.','p'),'.mat']);
                    readings = obj.hBeamlineGUI.updateReadings([],[],fname);
                    
                    fprintf('Setting: [%6.1f] V...\n',obj.VPoints(iV));
                    fprintf('Result:  [%6.1f] V...\n',...
                            obj.hBeamlineGUI.Monitors.(psTag).lastRead);
                    % Assign variables
                    fields = fieldnames(obj.hBeamlineGUI.Monitors);
                    for i=1:numel(fields)
                        tag = fields{i};
                        obj.scan_mon.(tag)(iV) = obj.hBeamlineGUI.Monitors.(tag).lastRead;
                    end
                    plot(obj.hAxes1,obj.scan_mon.(psTag)(1:iV),abs(obj.scan_mon.(obj.resultTag)(1:iV)));
                    %set(obj.hAxes1,'YScale','log');
                    xlabel(obj.hAxes1,obj.hBeamlineGUI.Monitors.(psTag).sPrint());
                    ylabel(obj.hAxes1,obj.hBeamlineGUI.Monitors.(obj.resultTag).sPrint());
                    if iV<numel(obj.VPoints)
                        scan_step();
                    else
                        end_scan();
                    end
                end
            end
            % Save results .csv file
            function end_scan(src,evt)
                fname = 'results.csv';
                writetable(struct2table(obj.scan_mon), fullfile(obj.hBeamlineGUI.DataDir,fname));
                obj.complete()
                fprintf('\nTest complete!\n');
            end

        end

        function complete(obj,~,~)
            %CLOSEGUI Re-enable beamline GUI run test button, restart timer, and delete obj when figure is closed
            if isvalid(obj.scanTimer)
                stop(obj.scanTimer);
                delete(obj.scanTimer);
            end

            % Enable beamline GUI run test button if still valid
            if isvalid(obj.hBeamlineGUI)
                set(obj.hBeamlineGUI.hRunBtn,'String','RUN TEST');
                set(obj.hBeamlineGUI.hRunBtn,'Enable','on');
            end

            if strcmp(obj.hBeamlineGUI.hTimer.Running,'off')
                start(obj.hBeamlineGUI.hTimer);
            end
        end

        function closeGUI(obj,~,~)
            %Re-enable beamline GUI run test button, restart timer, and delete obj when figure is closed
            obj.complete();
            
            % stop(obj.scanTimer);
                % Delete obj
            delete(obj);
        end
    end

end