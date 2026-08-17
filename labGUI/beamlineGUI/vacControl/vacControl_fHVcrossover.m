function vacControl_fHVcrossover(vacController)
    % Function to execute the HV Crossover process in the vacuum control system.
    cryoOutlet = 5;
    crossoverPressure = 4.0e-2; % Define the crossover pressure threshold
    pressureMonitor = vacController.Monitors.pressureChamberIG1; % Monitor for chamber pressure
    monplot = [];  % Initialize monplot as empty to track if it's created

    %% Verify all hardware is connected
    pressureHW = pressureMonitor.parent;
    valveControlHW = vacController.Monitors.valveState.parent;
    cryoTempHardware = vacController.Monitors.cryoTemp.parent;
    parents = [pressureHW, valveControlHW, cryoTempHardware];

    if all([parents.Connected])
        display('All hardware components are connected. Proceeding with HV crossover process.');
    else
        disconnected = [];
        for idx = 1:length(parents)
            parent = parents(idx);
            if ~parent.Connected
                warning('Hardware component "%s" is not connected.', parent.Tag);
                disconnected = [disconnected,parent.Tag];
            end
        end

        % Set up options for the user
        options = {'Ignore', 'Abort'};
        % Display confirmation dialog box
        errorAbortPopup(sprintf('Hardware Connection Error In HV Crossover: please connect %s to continue', strjoin(disconnected, ', ')));
        if vacController.processRunning == false
            return;
        end
    end

    %% Verify valve state ready for HV crossover
    cryoStatus = vacController.Monitors.valveState.lastRead(cryoOutlet);
    chamberBeamStatus = vacController.Monitors.valveState.lastRead(6);
    chamberRoughV2Status = vacController.Monitors.valveState.lastRead(7);
    chamberRoughV1Status = vacController.Monitors.valveState.lastRead(8);

    if cryoStatus ~= 0 || chamberBeamStatus ~= 0 || chamberRoughV2Status ~= 1 || chamberRoughV1Status ~= 1
        warning('One or more chamber valves are not in the correct state for HV crossover.');
        errordlg('One or more chamber valves are not in the correct state for HV crossover. System not configured for HV crossover:Aborting Process');
        abort();
        return;
    else
        display('Valve states indicate system is configured for HV crossover. Proceeding with process.');
    end

    %% Verify cryoTemp is ready for HV crossover
    cryoTemp = vacController.Monitors.cryoTemp.lastRead;

    if cryoTemp>19
        errorAbortPopup('Cryo temperature is above 19K, which is not suitable for HV crossover. Recommended Perform cryo regeneration before continuing');
        if vacController.processRunning == false
            return;
        end
    else
        display('Cryo temperature is suitable for HV crossover. Proceeding with process.');
    end

    %% plot monitor during process
    monplot = monitorPlot(vacController.hFigure, ...
                        vacController.processPanel, ...
                vacController.Monitors.dateTime, ... 
                vacController.Monitors.pressureChamberIG1);
    
    % scale plot to margin
    inset = get(monplot.ax, 'TightInset');
    % Set axes Position to fill the panel accounting for margins
    set(monplot.ax, 'Position', [inset(1), inset(2), 1 - inset(1) - inset(3), 1 - inset(2) - inset(4)]);

    yline(monplot.ax,crossoverPressure, 'r--', 'Crossover Pressure');

    %% Crossover process dwell loop
    while pressureMonitor.lastRead > crossoverPressure 
        if ~vacController.processRunning
            abort();
            return
        end
        pause(1); % Pause to allow GUI to update
    end

    %% Perform leak check
    display('Crossover pressure reached. performing leak check');
    valveControlHW.setOff(7); %close chamber Roughv2

    p_start = pressureMonitor.lastRead;
    leakTimer = tic;
    fprintf('starting leak check: system Pressure %s\n', pressureMonitor.sPrint());

    while toc(leakTimer) < 60 % Monitor for 60 seconds
        if ~vacController.processRunning
            abort();
            return
        end
        pause(1); % Pause to allow GUI to update
    end
    p_end = pressureMonitor.lastRead;
    fprintf('leak check complete: system Pressure %s\n', pressureMonitor.sPrint());
    
    if ~vacController.processRunning
        abort();
        return
    end
    valveControlHW.setOn(7); %open chamber Roughv2
    valveControlHW.read();
    if p_end>5e-2
        errorAbortPopup('Leak check failed: system pressure is above acceptable limit. Reccomed fixing leak before proceeding to HV crossover');
        if vacController.processRunning == false
            return;
        end        
    end 

    %% HV crossover
    display('Leak check passed. Proceeding with HV crossover: closing chamber rough v1 and chamber rough v2');
    
    % Close chamber roughing valves
    if ~vacController.processRunning
        abort();
        return
    end
    valveControlHW.setOff(7); %close chamber Roughv2
    valveControlHW.setOff(8); %close chamber Roughv1
    vState = valveControlHW.checkState();

    % Verify Valves Closed
    if vState(7) ~= 0 || vState(8) ~= 0
        warning('Failed to close chamber roughing valves for HV crossover. Please check valve control hardware and connections.');
        errordlg('Failed to close chamber roughing valves for HV crossover. Please check valve control hardware and connections. Aborting Process');
        abort();
        return;
    else
        display('Chamber roughing valves successfully closed.');
    end

    % Open cryo GV
    if ~vacController.processRunning
        abort();
        return
    end
    valveControlHW.setOn(cryoOutlet);

    % Verify cryo GV opened
    vState = valveControlHW.checkState();
    if vState(cryoOutlet) ~= 1 
        warning('Failed to open cryo GV for HV crossover. Please check valve control hardware and connections.');
        errordlg('Failed to open cryo GV for HV crossover. Please check valve control hardware and connections. Attempting to restablish rough vac before Aborting Process');
    
        if ~vacController.processRunning
            abort();
            return
        end
        valveControlHW.setOn(8); % Attempt to re-open chamber rough v1
        valveControlHW.setOn(7); % Attempt to re-open chamber rough v2
        abort();
        return;
    else
        display('Cryo GV successfully opened. HV crossover process complete.');
        msgbox('Cryo GV successfully opened. HV crossover process complete. Shutdown Chamber Rough Pump');
    end

    % Close monitor plot if it exists
    if ~isempty(monplot) && isvalid(monplot)
        delete(monplot.ax);
        delete(monplot);
    end

    %% Utility Funcitons
    function abort()
        vacController.processRunning = false;
        % Close monitor plot if it exists
        display('Aborting HV Crossover process...');
        if ~isempty(monplot) && isvalid(monplot)
            delete(monplot.ax);
            delete(monplot);
        end
    end

    function errorAbortPopup(errorString)
        % Set up options for the user
        options = {'Ignore', 'Abort'};
        % Display confirmation dialog box
        selection = questdlg(errorString, ...
            'Error Encountered', 'Abort','Ignore','Abort');
            % Process choice
        switch selection
            case 'Ignore'
                % Insert code to continue program execution
                display('User chose to ignore the error and continue execution. Please monitor system closely for any issues.');
            case 'Abort'
                abort();
        end
    end
end