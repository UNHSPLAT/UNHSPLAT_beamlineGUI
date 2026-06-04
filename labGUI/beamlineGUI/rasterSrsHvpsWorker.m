function rasterSrsHvpsWorker(address, className, rasterPattern, dwellTime)
%RASTERSRSHVPSWORKER Background parfeval worker for rasterSrsHvps
%   Instantiates a fresh instrument object of the same class as the parent
%   device, connects it, and rasters through rasterPattern indefinitely
%   using setVSet. Runs until the parallel Future is cancelled, at which
%   point onCleanup disconnects the instrument automatically.
%
%   Inputs:
%       address       - VISA address string of the srsHVPS instrument
%       className     - Class name used to construct the instrument object
%                       (e.g. 'srsHVPS') — passed as a string so it is
%                       serializable for the parallel worker
%       rasterPattern - Row vector of voltage setpoints (full up/down cycle)
%       dwellTime     - Dwell time at each step (seconds)

    % Instantiate and connect a fresh instrument object on this worker thread
    hvps = feval(className, char(address));
    hvps.connectDevice();

    % Guarantee disconnect when the worker exits for any reason (incl. cancel)
    cleanupHvps = onCleanup(@() hvps.disconnectDevice()); %#ok<NASGU>

    numSteps = numel(rasterPattern);
    idx = 0;
    while true
        idx = mod(idx, numSteps) + 1;
        hvps.setVSet(rasterPattern(idx));
        pause(dwellTime);
    end
end
