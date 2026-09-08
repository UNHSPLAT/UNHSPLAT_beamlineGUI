function vacControl_fCryoRegen(vacController)
    % Function to execute the Cryo Regeneration process in the vacuum control system.
    chamberRoughV1 = 8;  % valveState1 channel
    chamberRoughV2 = 7;  % valveState1 channel
    beamRoughV2    = 2;  % valveState1 channel
    cryoRoughV     = 1;  % valveState2 channel
    n2PurgeV       = 2;  % valveState2 channel

    roughPressure = 5.0e-2;  % Rough vacuum threshold [T]
    purgePressure = 450;     % N2 purge target pressure [T]

    pressureMonitor = vacController.Monitors.pressureChamberRough1;  % Rough gauge covers full range
    monplot = [];  % Initialize monplot as empty to track if it's created

    %% Verify all hardware is connected
    pressureHW      = pressureMonitor.parent;
    valveControlHW1 = vacController.Monitors.valveState1.parent;
    valveControlHW2 = vacController.Monitors.valveState2.parent;
    parents = [pressureHW, valveControlHW1, valveControlHW2];

    if all([parents.Connected])
        display('All hardware components are connected. Proceeding with cryo regeneration process.');
    else
        disconnected = [];
        for idx = 1:length(parents)
            parent = parents(idx);
            if ~parent.Connected
                warning('Hardware component "%s" is not connected.', parent.Tag);
                disconnected = [disconnected,parent.Tag];
            end
        end

        errorAbortPopup(sprintf('Hardware Connection Error In Cryo Regen: please connect %s to continue', strjoin(disconnected, ', ')));
        if vacController.processRunning == false
            return;
        end
    end

    %% Verify valve state ready for cryo regeneration
    chamberRoughV2Status = vacController.Monitors.valveState1.lastRead(chamberRoughV2);
    beamRoughV2Status    = vacController.Monitors.valveState1.lastRead(beamRoughV2);
    chamberRoughV1Status = vacController.Monitors.valveState1.lastRead(chamberRoughV1);

    if chamberRoughV2Status ~= 0 || beamRoughV2Status ~= 0 || chamberRoughV1Status ~= 0
        warning('One or more chamber valves are not in the correct state for cryo regeneration.');
        errordlg('Chamber Rough V2, Beam Rough V2, and Chamber Rough V1 must all be closed before cryo regeneration. Aborting Process');
        abort();
        return;
    else
        display('Valve states indicate system is configured for cryo regeneration. Proceeding with process.');
    end

    %% Ask user for number of regen cycles
    answer = inputdlg('Enter number of cryo regen cycles to perform:', 'Cryo Regen Cycles', [1 50], {'1'});
    if isempty(answer)
        display('User cancelled cryo regeneration process.');
        return;
    end
    nCycles = str2double(answer{1});
    if isnan(nCycles) || nCycles < 1
        errordlg('Invalid number of cycles entered. Aborting Process');
        return;
    end

    vacController.processRunning = true;

    %% plot monitor during process
    monplot = monitorPlot(vacController.hFigure, ...
                        vacController.processPanel, ...
                vacController.Monitors.dateTime, ...
                pressureMonitor);

    % scale plot to margin
    inset = get(monplot.ax, 'TightInset');
    set(monplot.ax, 'Position', [inset(1), inset(2), 1 - inset(1) - inset(3), 1 - inset(2) - inset(4)]);

    yline(monplot.ax, roughPressure, 'r--', 'Rough Pressure');
    yline(monplot.ax, purgePressure, 'b--', 'Purge Pressure');

    %% Open cryo rough valve for the duration of the regeneration process
    if ~vacController.processRunning
        abort();
        return
    end
    valveControlHW2.setOn(cryoRoughV);
    vState = valveControlHW2.checkState();
    if vState(cryoRoughV) ~= 1
        warning('Failed to open cryo rough valve for cryo regeneration. Please check valve control hardware and connections.');
        errordlg('Failed to open cryo rough valve for cryo regeneration. Please check valve control hardware and connections. Aborting Process');
        abort();
        return;
    else
        display('Cryo rough valve successfully opened.');
    end

    %% Regeneration cycles
    for cycle = 1:nCycles
        fprintf('Starting cryo regen cycle %d of %d\n', cycle, nCycles);

        % Rough down the cryo volume
        if ~vacController.processRunning
            abort();
            return
        end
        valveControlHW1.setOn(chamberRoughV1);
        while pressureMonitor.lastRead > roughPressure
            if ~vacController.processRunning
                abort();
                return
            end
            pause(1); % Pause to allow GUI to update
        end
        valveControlHW1.setOff(chamberRoughV1);

        % Purge with N2 up to target pressure
        if ~vacController.processRunning
            abort();
            return
        end
        valveControlHW2.setOn(n2PurgeV);
        while pressureMonitor.lastRead < purgePressure
            if ~vacController.processRunning
                abort();
                return
            end
            pause(1); % Pause to allow GUI to update
        end
        valveControlHW2.setOff(n2PurgeV);

        fprintf('Cryo regen cycle %d of %d complete\n', cycle, nCycles);
    end

    %% Final rough down and shutdown
    display('Cryo regen cycles complete. Performing final rough down.');
    if ~vacController.processRunning
        abort();
        return
    end
    valveControlHW1.setOn(chamberRoughV1);
    while pressureMonitor.lastRead > roughPressure
        if ~vacController.processRunning
            abort();
            return
        end
        pause(1); % Pause to allow GUI to update
    end

    valveControlHW2.setOff(cryoRoughV);
    valveControlHW1.setOff(chamberRoughV1);

    display('Cryo regeneration process complete.');
    msgbox('Cryo regeneration process complete.');

    vacController.processRunning = false;

    % Close monitor plot if it exists
    if ~isempty(monplot) && isvalid(monplot)
        delete(monplot);
    end

    %% Utility Functions
    function abort()
        vacController.processRunning = false;
        display('Aborting Cryo Regen process...');
        if ~isempty(monplot) && isvalid(monplot)
            delete(monplot);
        end
    end

    function errorAbortPopup(errorString)
        selection = questdlg(errorString, ...
            'Error Encountered', 'Abort','Ignore','Abort');
        switch selection
            case 'Ignore'
                display('User chose to ignore the error and continue execution. Please monitor system closely for any issues.');
            case 'Abort'
                abort();
        end
    end
end
