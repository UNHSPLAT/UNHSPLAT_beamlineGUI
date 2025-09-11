classdef Sweep2D < acquisition
    %FARADAYCUPSWEEP Configures and runs a sweep of Faraday cup current vs selectable voltage supply

    properties (Constant)
        Type string = "Sweep 2D" % Acquisition type identifier string
        MinDefault double = 0 % Default minimum voltage
        MaxDefault double = 1 % Default maximum voltage
        StepsDefault double = 5 % Default number of steps
        DwellDefault double = 1 % Default dwell time
        stepDwell double = 1 % Time to wait after setting voltage before acquiring data
        % PSList string = ["ExB","ESA","Defl","Ysteer"] %    List of sweep supplies
    end

    properties
        PSTag string % String identifying user-selected HVPS
        hHVPS % Handle to desired power supply

        hAxes1 % Handle to I-V data axes
        hAxes2 % Handle to I-1/V^2 data axes
        
        hSupplyText % Handle to sweep supply label
        hSupplyEdit % Handle to sweep supply field
        hMinText % Handle to minimum voltage label
        hMinEdit % Handle to minimum voltage field
        hStepsText % Handle to number of steps label
        hStepsEdit % Handle to number of steps field
        hSpacingEdit % Handle to log spacing checkbox
        hMaxText % Handle to maximum voltage label
        hMaxEdit % Handle to maximum voltage field
        
        hSupplyText2 % Handle to sweep supply label
        hSupplyEdit2 % Handle to sweep supply field
        hMinText2 % Handle to minimum voltage label
        hMinEdit2 % Handle to minimum voltage field
        hStepsText2 % Handle to number of steps label
        hStepsEdit2 % Handle to number of steps field
        hSpacingEdit2 % Handle to log spacing checkbox
        hMaxText2 % Handle to maximum voltage label
        hMaxEdit2 % Handle to maximum voltage field

        hDaqEdit % Handle to data acquisition supply field

        hDwellText % Handle to dwell time label
        hDwellEdit % Handle to dwell time field
        hSweepBtn % Handle to run sweep button
        VPoints double % Array of ExB voltage setpoints
        VPoints2 double % Array of ExB voltage setpoints
        hConfFigure
        

        DwellTime double % Dwell time setting
        PSList %
        resultList

        scanTimer timer%
        scan_mon %

        testLab = string
    end

    methods
        
        function obj = Sweep2D(hGUI)
            %FARADAYCUPVSEXBSWEEP Construct an instance of this class

            obj@acquisition(hGUI);
            
            
            
            % set testLabel
            obj.testLab = sprintf('%s_%s',num2str(obj.hBeamlineGUI.TestSequence),obj.Type);

            % get active and inactive monitors for scanning
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
                'Position',[400,160,600,240],...
                'NumberTitle','off',...
                'Name','Sweep Config',...
                'DeleteFcn',@obj.closeGUI);

            % ==================================================================
            % Select DAQ supply
            % Set positions
            ystart = 220;
            ysize = 20;
            xpos = 200;
            xtextsize = 100;
            xeditsize = 60;
            ypos = ystart;

            uicontrol(obj.hConfFigure,'Style','text',...
                'Position',[xpos-xtextsize,ystart,xtextsize,ysize],...
                'String','Data Acquisition: ',...
                'FontSize',9,...
                'HorizontalAlignment','right');


            obj.hDaqEdit = uicontrol(obj.hConfFigure,'Style','popupmenu',...
                'Position',[xpos,ystart,xeditsize,ysize],...
                'String',obj.resultList,...
                'Value',1,...
                'HorizontalAlignment','right');
                

            % ==================================================================
            % Select sweep Supply 1
            % Set positions
            ystart = 190;
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
                'Value',2,...
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

            ypos = ypos-ysize*2;
            
            obj.hSpacingEdit = uicontrol(obj.hConfFigure,'Style','checkbox',...
                'Position',[xpos-10,ypos,xtextsize+20,ysize],...
                'String',' Logarithmic Spacing',...
                'Value',0,...
                'HorizontalAlignment','right');
            
            ypos = ypos-ysize-ygap;
            
            % ==================================================================
            % Select sweep Supply 2
            % Set positions
            ystart = 190;
            ysize = 20;
            xpos = 150+300;
            xtextsize = 100;
            xeditsize = 60;
            ypos = ystart;

            obj.hSupplyText2 = uicontrol(obj.hConfFigure,'Style','text',...
                'Position',[xpos-xtextsize,ystart,xtextsize,ysize],...
                'String','Sweep Supply: ',...
                'FontSize',9,...
                'HorizontalAlignment','right');


            obj.hSupplyEdit2 = uicontrol(obj.hConfFigure,'Style','popupmenu',...
                'Position',[xpos,ystart,xeditsize,ysize],...
                'String',obj.PSList,...
                'Value',5,...
                'HorizontalAlignment','right');

            % Set positions
            ystart = 155;
            ypos = ystart;
            ysize = 20;
            ygap = 16;
            xpos = 30+300;
            xtextsize = 100;
            xeditsize = 60;

            % Create components
            obj.hMinText2 = uicontrol(obj.hConfFigure,'Style','text',...
                'Position',[xpos,ypos,xtextsize,ysize],...
                'String','Min Voltage [V]: ',...
                'FontSize',8,...
                'HorizontalAlignment','center');
            
            ypos = ypos-ysize;
            
            obj.hMinEdit2 = uicontrol(obj.hConfFigure,'Style','edit',...
                'Position',[xpos+(xtextsize-xeditsize)/2,ypos,xeditsize,ysize],...
                'String',num2str(obj.MinDefault),...
                'HorizontalAlignment','right');
            
            ypos = ypos-ysize-ygap;
            
            obj.hStepsText2 = uicontrol(obj.hConfFigure,'Style','text',...
                'Position',[xpos,ypos,xtextsize,ysize],...
                'String','Number of Steps: ',...
                'FontSize',8,...
                'HorizontalAlignment','center');
            
            ypos = ypos-ysize;
            
            obj.hStepsEdit2 = uicontrol(obj.hConfFigure,'Style','edit',...
                'Position',[xpos+(xtextsize-xeditsize)/2,ypos,xeditsize,ysize],...
                'String',num2str(obj.StepsDefault),...
                'HorizontalAlignment','right');
            
            ypos = ystart;
            xpos = 170+300;
            
            obj.hMaxText2 = uicontrol(obj.hConfFigure,'Style','text',...
                'Position',[xpos,ypos,xtextsize,ysize],...
                'String','Max Voltage [V]: ',...
                'FontSize',8,...
                'HorizontalAlignment','center');
            
            ypos = ypos-ysize;
            
            obj.hMaxEdit2 = uicontrol(obj.hConfFigure,'Style','edit',...
                'Position',[xpos+(xtextsize-xeditsize)/2,ypos,xeditsize,ysize],...
                'String',num2str(obj.MaxDefault),...
                'HorizontalAlignment','right');
            
            ypos = ypos-ysize*2;
            
            obj.hSpacingEdit2 = uicontrol(obj.hConfFigure,'Style','checkbox',...
                'Position',[xpos-10,ypos,xtextsize+20,ysize],...
                'String',' Logarithmic Spacing',...
                'Value',0,...
                'HorizontalAlignment','right');

            
            % ==================================================================
            ypos = ypos-ysize*2-ygap;
            xpos = 170;
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
            
            xpos = 330;

            obj.hSweepBtn = uicontrol(obj.hConfFigure,'Style','pushbutton',...
                'Position',[xpos,ypos,xtextsize,ysize+ygap],...
                'String','RUN SWEEP',...
                'FontSize',10,...
                'FontWeight','bold',...
                'HorizontalAlignment','center',...
                'Callback',@obj.sweepBtnCallback);

        end

        
    end

    methods (Access = private)

        function sweepBtnCallback(obj,~,~)
            %SWEEPBTNCALLBACK Begin sweep execution based on configuration info
            
            % Run inside a try-catch to reset beamline GUI run test button if error occurs
            try
    
                % Retrieve config values
                psTag = obj.PSList(obj.hSupplyEdit.Value);
                minVal = str2double(obj.hMinEdit.String);
                maxVal = str2double(obj.hMaxEdit.String);
                stepsVal = str2double(obj.hStepsEdit.String);

                psTag2 = obj.PSList(obj.hSupplyEdit2.Value);
                minVal2 = str2double(obj.hMinEdit2.String);
                maxVal2= str2double(obj.hMaxEdit2.String);
                stepsVal2 = str2double(obj.hStepsEdit2.String);

                dwellVal = str2double(obj.hDwellEdit.String);

                daqTag = obj.resultList(obj.hDaqEdit.Value);

                % % Error checking
                if isnan(minVal) || isnan(maxVal) || isnan(stepsVal) || isnan(dwellVal)
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
                % Determine log vs linear spacing
                logSpacing2= logical(obj.hSpacingEdit2.Value);


                % Retrieve config info
                gasType = obj.hBeamlineGUI.gasType;
                testSequence = obj.hBeamlineGUI.TestSequence;
    
                % Create voltage setpoint array
                if logSpacing
                    vPointsX = logspace(log10(minVal),log10(maxVal),stepsVal);
                else
                    vPointsX = linspace(minVal,maxVal,stepsVal);
                end
                
                if logSpacing2
                    vPointsY = logspace(log10(minVal2),log10(maxVal2),stepsVal2);
                else
                    vPointsY = linspace(minVal2,maxVal2,stepsVal2);
                end
                %Define meshgrid from scan vectors
                [xx,yy] = meshgrid(vPointsX,vPointsY);
                %Reorder meshgrid so we scan in triangles instead of knife edges
                %xx(2:2:end,:) = fliplr(xx(2:2:end,:));
                %yy(2:2:end,:) = fliplr(yy(2:2:end,:));
                
                %Flatten mat values and assign
                obj.VPoints = reshape(xx',1,[]);
                obj.VPoints2 = reshape(yy',1,[]);

                % Save config info
                save(fullfile(obj.hBeamlineGUI.DataDir,'config.mat'),...
                        'vPointsX','minVal','maxVal','stepsVal',...
                        'vPointsY','minVal2','maxVal2','stepsVal2',...
                        'dwellVal','logSpacing','gasType','testSequence');
    
                % Set DwellTime property
                obj.DwellTime = dwellVal;
    
                % Set config figure to invisible
                set(obj.hConfFigure,'Visible','off');

                % Stop beamline timers (timer callback executed manually during test)
                obj.hBeamlineGUI.stopTimer();

                % Create figures and axes
                obj.hFigure = figure('NumberTitle','off',...
                                      'Name','Faraday Cup Current vs Voltage',...
                                      'DeleteFcn',@obj.closeGUI);


                obj.hAxes1 = axes(obj.hFigure);

                % Preallocate arrays
                FX = reshape(obj.VPoints,[stepsVal,stepsVal2])';
                FX(2:2:end,:) = fliplr(FX(2:2:end,:));
                
                FY = reshape(obj.VPoints2,[stepsVal,stepsVal2])';
                FY(2:2:end,:) = fliplr(FY(2:2:end,:));

                obj.scan_mon = struct();
                fields = fieldnames(obj.hBeamlineGUI.Monitors);
                disp(fields);
                for i=1:numel(fields)
                    tag = fields{i};
                    disp(tag);
                    monitor = obj.hBeamlineGUI.Monitors.(tag);
                    if contains(monitor.formatSpec,'%s')
                        obj.scan_mon.(tag)=strings(length(obj.VPoints),1);
                    else
                        obj.scan_mon.(tag) = zeros(length(obj.VPoints),1)*nan;
                    end
                end

                % Run sweep
                vsetx = nan;
                vsety = nan;

                obj.scanTimer = timer('Period',obj.DwellTime,... %period
                          'ExecutionMode','fixedDelay',... %{singleShot,fixedRate,fixedSpacing,fixedDelay}
                          'BusyMode','drop',... %{drop, error, queue}
                          'TasksToExecute',numel(obj.VPoints),...          
                          'StartDelay',0,...
                          'TimerFcn',@scan_step,...
                          'StartFcn',[],...
                          'StopFcn',@end_scan,...
                          'ErrorFcn',[]);
                start(obj.scanTimer);

            catch MExc

                % Delete figure if error, triggering closeGUI callback
                delete(obj.hConfFigure);

                % Rethrow caught exception
                rethrow(MExc);

            end
            function scan_step(src,evt)
                        iV = get(src,'TasksExecuted');
                        if isempty(obj.hFigure) || ~isvalid(obj.hFigure)
                            obj.hFigure = figure('NumberTitle','off',...
                                'Name','Faraday Cup Current vs Voltage');
                            obj.hAxes1 = axes(obj.hFigure); %#ok<LAXES> Only executed if figure deleted or not instantiated
                        end

                        % Set ExB voltage
                        if obj.VPoints(iV) ~= vsetx
                            vsetx = obj.VPoints(iV);
                            fprintf('Setting %s voltage to %.2f V...\n',psTag,obj.VPoints(iV));
                            obj.hBeamlineGUI.Monitors.(psTag).set(obj.VPoints(iV));
                        end
                        if obj.VPoints2(iV) ~= vsety
                            vsety = obj.VPoints2(iV);
                            fprintf('Setting %s voltage to %.1f V...\n',psTag2,obj.VPoints2(iV));
                            obj.hBeamlineGUI.Monitors.(psTag2).set(obj.VPoints2(iV));
                        end
                        % Pause for ramp time
                
                        pause(obj.stepDwell);
                        % Obtain readings
                        fname = fullfile(obj.hBeamlineGUI.DataDir,sprintf('%s.mat',obj.testLab));
                        obj.hBeamlineGUI.readHardware();
                        obj.hBeamlineGUI.updateLog([],[],fname);

                        fprintf('Setting: [%6.1f,%6.1f] V...\n',vsetx,vsety);
                        fprintf('Result:  [%6.1f,%6.1f] V...\n',...
                            obj.hBeamlineGUI.Monitors.(psTag).lastRead,...
                            obj.hBeamlineGUI.Monitors.(psTag2).lastRead);
                        % Assign variables
                        fields = fieldnames(obj.hBeamlineGUI.Monitors);
                        for i=1:numel(fields)
                            tag = fields{i};
                            try
                                obj.scan_mon.(tag)(iV) = obj.hBeamlineGUI.Monitors.(tag).lastRead;
                            catch
%                                 warning(sprintf('data collect failed for %s',tag))
                                obj.scan_mon.(tag)(iV) = sprintf(obj.hBeamlineGUI.Monitors.(tag).formatSpec,obj.hBeamlineGUI.Monitors.(tag).lastRead);
                            end
                        end
                        
                        FF = reshape(obj.scan_mon.(daqTag),[stepsVal,stepsVal2])';
                        %FF(2:2:end,:) = fliplr(FF(2:2:end,:));
                        
                        imagesc(obj.hAxes1,vPointsX,vPointsY,FF);
                        
                        cBar = colorbar(obj.hAxes1);
                        cBar.Label.String = obj.hBeamlineGUI.Monitors.(daqTag).sPrint();
                        set(obj.hAxes1,'ColorScale','log')
                        xlabel(obj.hAxes1,obj.hBeamlineGUI.Monitors.(psTag).sPrint());
                        ylabel(obj.hAxes1,obj.hBeamlineGUI.Monitors.(psTag2).sPrint());
                        set(obj.hAxes1,'YDir','normal');
                        drawnow();
                    end

                    % Save results .csv file
                    function end_scan(src,evt)
                        fname = fullfile(obj.hBeamlineGUI.DataDir,sprintf('%s_results.csv',obj.testLab));
                        writetable(struct2table(obj.scan_mon), fname);
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

            % Restart beamline timers
            obj.hBeamlineGUI.restartTimer();
        end

    end

    methods (Access = public)
        function closeGUI(obj,~,~)
            %Re-enable beamline GUI run test button, restart timer, and delete obj when figure is closed
            obj.complete();
            
            % stop(obj.scanTimer);
                % Delete obj
            delete(obj);
        end
    end

end