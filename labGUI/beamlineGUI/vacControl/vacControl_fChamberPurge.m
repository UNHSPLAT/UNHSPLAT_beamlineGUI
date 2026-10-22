function vacControl_fChamberPurge(vacController)
    % Function to execute the Chamber N2 Purge process in the vacuum control system.
    cryoGV         = 5;  % valveState1 channel
    chamberBeamGV  = 6;  % valveState1 channel
    chamberRoughV2 = 7;  % valveState1 channel
    n2PurgeV       = 2;  % valveState2 channel

    pressureMonitor = vacController.Monitors.pressureChamberIG1;
    doorMonitor     = vacController.Monitors.doorState;
    monplot = [];  % Initialize monplot as empty to track if it's created
    purgeOpened = false;

    %% Verify all hardware is connected
    pressureHW      = pressureMonitor.parent;
    valveControlHW1 = vacController.Monitors.valveState1.parent;
    valveControlHW2 = vacController.Monitors.valveState2.parent;
    doorHW          = doorMonitor.parent;
    parents = [pressureHW, valveControlHW1, valveControlHW2, doorHW];

    if all([parents.Connected])
        display('All hardware components are connected. Proceeding with chamber purge process.');
    else
        disconnected = [];
        for idx = 1:length(parents)
            parent = parents(idx);
            if ~parent.Connected
                warning('Hardware component "%s" is not connected.', parent.Tag);
                disconnected = [disconnected,parent.Tag];
            end
        end

        errorAbortPopup(sprintf('Hardware Connection Error In Chamber Purge: please connect %s to continue', strjoin(disconnected, ', ')));
        if vacController.processRunning == false
            return;
        end
    end

    %% Verify valve state ready for chamber purge
    chamberBeamStatus    = vacController.Monitors.valveState1.lastRead(chamberBeamGV);
    cryoStatus           = vacController.Monitors.valveState1.lastRead(cryoGV);
    chamberRoughV2Status = vacController.Monitors.valveState1.lastRead(chamberRoughV2);

    if chamberBeamStatus ~= 0 || cryoStatus ~= 0 || chamberRoughV2Status ~= 0
        warning('One or more chamber valves are not in the correct state for chamber purge.');
        errordlg('Chamber Beam GV, Cryo GV, and Chamber Rough V2 must all be closed before chamber purge. Aborting Process');
        abort();
        return;
    else
        display('Valve states indicate system is configured for chamber purge. Proceeding with process.');
    end

    %% Confirm manual checklist with user
    checklist = sprintf(['Confirm the system is configured for purge:\n\n' ...
        '1. The chamber doors are unlatched\n' ...
        '2. Chamber Equiptment disabled\n' ...
        '3. The N2 purge system is configured per chamber purge procedure']);
    selection = questdlg(checklist, 'Chamber Purge Confirmation', 'Confirm', 'Cancel', 'Cancel');
    if ~strcmp(selection, 'Confirm')
        display('User cancelled chamber purge process.');
        vacController.processRunning = false;
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

    %% Open N2 purge valve
    if ~vacController.processRunning
        abort();
        return
    end
    valveControlHW2.setOn(n2PurgeV);
    purgeOpened = true;
    vState = valveControlHW2.checkState();
    if vState(n2PurgeV) ~= 1
        warning('Failed to open N2 purge valve. Please check valve control hardware and connections.');
        errordlg('Failed to open N2 purge valve. Please check valve control hardware and connections. Aborting Process');
        abort();
        return;
    else
        display('N2 purge valve successfully opened.');
    end

    %% Purge until the chamber door opens
    while ~doorMonitor.lastRead
        if ~vacController.processRunning
            abort();
            return
        end
        pause(1); % Pause to allow GUI to update
    end

    %% Door open: close purge valve and finish
    display('Chamber door open. Closing N2 purge valve.');
    valveControlHW2.setOff(n2PurgeV);
    purgeOpened = false;

    display('Chamber purge process complete.');
    msgbox('Chamber purge process complete.');

    vacController.processRunning = false;

    % Close monitor plot if it exists
    if ~isempty(monplot) && isvalid(monplot)
        delete(monplot);
    end

    %% Utility Functions
    function abort()
        vacController.processRunning = false;
        display('Aborting Chamber Purge process...');
        if purgeOpened
            valveControlHW2.setOff(n2PurgeV);
            purgeOpened = false;
        end
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
