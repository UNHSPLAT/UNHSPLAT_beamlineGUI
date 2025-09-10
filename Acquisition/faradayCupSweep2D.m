classdef faradayCupSweep2D < acquisition
    %FARADAYCUPSWEEP Configures and runs a sweep of Faraday cup current vs selectable voltage supply

    properties (Constant)
        Type string = "Faraday cup Sweep 2D" % Acquisition type identifier string
        MinDefault double = 100 % Default minimum voltage
        MaxDefault double = 150 % Default maximum voltage
        StepsDefault double = 5 % Default number of steps
        DwellDefault double = 1 % Default dwell time
        % PSList string = ["ExB","ESA","Defl","Ysteer"] % List of sweep supplies
    end

    properties
        PSTag string % String identifying user-selected HVPS
        hHVPS % Handle to desired power supply
        hConfFigure % Handle to configuration GUI figure
        hFigure1 % Handle to I-V data plot
        hFigure2 % Handle to I-1/V^2 data plot
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

        hDwellText % Handle to dwell time label
        hDwellEdit % Handle to dwell time field
        hSweepBtn % Handle to run sweep button
        VPoints double % Array of ExB voltage setpoints
        VPoints2 double % Array of ExB voltage setpoints
        

        DwellTime double % Dwell time setting
        PSList %

        scanTimer timer%
        scan_mon %
    end

    methods
        function obj = faradayCupSweep2D(hGUI)
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
                'Position',[400,160,600,220],...
                'NumberTitle','off',...
                'Name','Sweep Config',...
                'DeleteFcn',@obj.closeGUI);


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


            function tag = get_active(mon)
                if mon.active
                    obj.PSList(end+1) = mon.Tag;
                end
            end
            obj.PSList = [""];
            structfun(@get_active,obj.hBeamlineGUI.Monitors);
            
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
                minVal = str2double(obj.hMinEdit.String);
                maxVal = str2double(obj.hMaxEdit.String);
                stepsVal = str2double(obj.hStepsEdit.String);

                psTag2 = obj.PSList(obj.hSupplyEdit2.Value);
                minVal2 = str2double(obj.hMinEdit2.String);
                maxVal2= str2double(obj.hMaxEdit2.String);
                stepsVal2 = str2double(obj.hStepsEdit2.String);

                dwellVal = str2double(obj.hDwellEdit.String);
    
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
                operator = obj.hBeamlineGUI.TestOperator;
                gasType = obj.hBeamlineGUI.GasType;
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
                        'dwellVal','logSpacing','operator','gasType','testSequence');
    
                % Set DwellTime property
                obj.DwellTime = dwellVal;
    
                % Set config figure to invisible
                set(obj.hConfFigure,'Visible','off');

                % Stop beamline timers (timer callback executed manually during test)
                obj.hBeamlineGUI.stopTimer();

                % Create figures and axes
                obj.hFigure1 = figure('NumberTitle','off',...
                                      'Name','Faraday Cup Current vs Voltage',...
                                      'DeleteFcn',@obj.closeGUI);


                obj.hAxes1 = axes(obj.hFigure1);

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
                        if isempty(obj.hFigure1) || ~isvalid(obj.hFigure1)
                            obj.hFigure1 = figure('NumberTitle','off',...
                                'Name','Faraday Cup Current vs Voltage');
                            obj.hAxes1 = axes(obj.hFigure1); %#ok<LAXES> Only executed if figure deleted or not instantiated
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
                        waitfor(obj.hBeamlineGUI.Monitors,psTag2,false);
                        waitfor(obj.hBeamlineGUI.Monitors,psTag,false);
                        % pause(obj.DwellTime);
                        % Obtain readings
                        fname = fullfile(obj.hBeamlineGUI.DataDir,[strrep(sprintf('%s_%.2fV',psTag,obj.VPoints(iV)),'.','p'),'.mat']);
                        readings = obj.hBeamlineGUI.updateReadings([],[],fname);

                        fprintf('Setting: [%6.1f,%6.1f] V...\n',vsetx,vsety);
                        fprintf('Result:  [%6.1f,%6.1f] V...\n',...
                            obj.hBeamlineGUI.Monitors.(psTag).lastRead,...
                            obj.hBeamlineGUI.Monitors.(psTag2).lastRead);
                        % Assign variables
                        fields = fieldnames(obj.hBeamlineGUI.Monitors);
                        for i=1:numel(fields)
                            tag = fields{i};
                            obj.scan_mon.(tag)(iV) = obj.hBeamlineGUI.Monitors.(tag).lastRead;
                        end
                        
                        FF = reshape(obj.scan_mon.Ifaraday,[stepsVal,stepsVal2])';
                        %FF(2:2:end,:) = fliplr(FF(2:2:end,:));
                        
                        imagesc(obj.hAxes1,vPointsX,vPointsY,FF);
                        
                        cBar = colorbar(obj.hAxes1);
                        cBar.Label.String = obj.hBeamlineGUI.Monitors.Ifaraday.sPrint();
                        set(obj.hAxes1,'ColorScale','log')
                        xlabel(obj.hAxes1,obj.hBeamlineGUI.Monitors.(psTag).sPrint());
                        ylabel(obj.hAxes1,obj.hBeamlineGUI.Monitors.(psTag2).sPrint());
                        set(obj.hAxes1,'YDir','normal');
                        drawnow();
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

            % Restart beamline timers
            obj.hBeamlineGUI.restartTimer();
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