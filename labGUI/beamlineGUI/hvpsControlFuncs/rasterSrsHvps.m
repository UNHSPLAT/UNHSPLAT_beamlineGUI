function rasterSrsHvps(mon, upperVal, lowerVal, stepNum, dwellTime)
%RASTERSRSHVPS Rasters an srsHVPS monitor through a voltage range in the background
%   rasterSrsHvps(mon, upperVal, lowerVal, stepNum, dwellTime)
%
%   Stops the parent instrument's polling timer, closes its VISA handle,
%   then launches a background parfeval worker that opens its own VISA
%   session and steps through a triangular raster pattern entirely on the
%   worker thread. The ABORT button cancels the worker, which closes the
%   VISA session via onCleanup, and restores the GUI state and timer.
%
%   Inputs:
%       mon       - Monitor object whose parent is an srsHVPS
%       upperVal  - Upper voltage limit of the raster range
%       lowerVal  - Lower voltage limit of the raster range
%       stepNum   - Number of steps per half-cycle (must be >= 2)
%       dwellTime - Dwell time at each step (seconds, must be > 0)
%
%   Example:
%       rasterSrsHvps(myHvMon, 1000, 0, 50, 0.5)
%       % To abort: press the ABORT button in the GUI

    % Input validation
    if nargin < 5
        error('rasterSrsHvps requires 5 inputs: mon, upperVal, lowerVal, stepNum, dwellTime');
    end

    if ~isnumeric(upperVal) || ~isnumeric(lowerVal) || ~isnumeric(stepNum) || ~isnumeric(dwellTime)
        error('upperVal, lowerVal, stepNum, and dwellTime must be numeric');
    end

    if stepNum < 2
        error('stepNum must be at least 2');
    end

    if dwellTime <= 0
        error('dwellTime must be positive');
    end

    % Ensure upperVal is greater than lowerVal
    if upperVal < lowerVal
        temp = upperVal;
        upperVal = lowerVal;
        lowerVal = temp;
    end

    % --- Kill parent instrument timer ---
    timerWasRunning = false;
    if ~isempty(mon.parent) && isprop(mon.parent, 'Timer') && ...
       isvalid(mon.parent.Timer) && strcmp(mon.parent.Timer.Running, 'on')
        timerWasRunning = true;
        stop(mon.parent.Timer);
        fprintf('Parent instrument timer stopped.\n');
    end

    % Generate the raster pattern (triangular wave, no duplicated endpoints)
    stepValues    = linspace(lowerVal, upperVal, stepNum);
    rasterPattern = [stepValues, fliplr(stepValues(2:end-1))];

    % Lock the monitor
    if isprop(mon, 'lock')
        if mon.lock
            fprintf('Monitor locked: Raster Aborted\n');
            if timerWasRunning && isvalid(mon.parent.Timer)
                start(mon.parent.Timer);
            end
            return
        else
            mon.lock = true;
        end
    end

    % Store original button state before changing to ABORT
    originalText     = 'SET';
    originalCallback = @mon.guiSetCallback;

    if ~isempty(mon.guiHand) && isfield(mon.guiHand, 'statusGrpSetBtn') && ...
       isvalid(mon.guiHand.statusGrpSetBtn)
        set(mon.guiHand.statusGrpSetBtn, 'String',   'ABORT');
        set(mon.guiHand.statusGrpSetBtn, 'Callback', @(~,~) abortRaster());
    end

    % Close the main thread's hVisa handle so the background worker can
    % open its own exclusive session to the same VISA address.
    if ~isempty(mon.parent.hVisa) && strcmp(mon.parent.hVisa.Status, 'open')
        fclose(mon.parent.hVisa);
    end

    % Launch the raster loop on a background worker.
    % The worker constructs its own instrument object using the class name
    % and address (both serializable strings), giving it identical
    % connection and command behaviour to the main-thread instrument.
    pool = gcp();
    f    = parfeval(pool, @rasterSrsHvpsWorker, 0, mon.parent.Address, class(mon.parent), rasterPattern, dwellTime);

    fprintf('Raster started (background worker).\n');
    fprintf('Range: %.3f to %.3f V\n', lowerVal, upperVal);
    fprintf('Steps: %d per half-cycle, Dwell: %.3f s\n', stepNum, dwellTime);
    fprintf('Total cycle time: %.3f s\n', numel(rasterPattern) * dwellTime);
    fprintf('To abort: press ABORT button\n\n');

    % --- Nested callback functions (share the parent workspace) ---

    function abortRaster()
        cancel(f);
        restoreState();
        fprintf('Raster aborted by user.\n');
    end

    function restoreState()
        % Restore GUI button
        if ~isempty(mon.guiHand) && isfield(mon.guiHand, 'statusGrpSetBtn') && ...
           isvalid(mon.guiHand.statusGrpSetBtn)
            set(mon.guiHand.statusGrpSetBtn, 'String',   originalText);
            set(mon.guiHand.statusGrpSetBtn, 'Callback', originalCallback);
        end

        % Unlock the monitor
        if isprop(mon, 'lock')
            mon.lock = false;
        end

        % Restart parent instrument timer if it was running before
        if timerWasRunning && ~isempty(mon.parent) && isprop(mon.parent, 'Timer') && ...
           isvalid(mon.parent.Timer) && strcmp(mon.parent.Timer.Running, 'off')
            start(mon.parent.Timer);
            fprintf('Parent instrument timer restarted.\n');
        end
    end

end
