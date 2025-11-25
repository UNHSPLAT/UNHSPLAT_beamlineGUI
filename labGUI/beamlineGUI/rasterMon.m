function rasterMon(mon, upperVal, lowerVal, stepNum, dwellTime)
    %RASTERMON Continuously rasters a monitor parameter through a range of values
    %   rasterMon(mon, upperVal, lowerVal, stepNum, dwellTime)
    %   
    %   Inputs:
    %       mon - Monitor object with a .set() method
    %       upperVal - Upper limit of the raster range
    %       lowerVal - Lower limit of the raster range
    %       stepNum - Number of steps in the range
    %       dwellTime - Time to dwell at each step (in seconds)
    %   
    %   The function continuously rasters between lowerVal and upperVal,
    %   creating a triangular wave pattern using a timer. The timer is stored
    %   in mon.monTimer and can be stopped with: stop(mon.monTimer)
    %   
    %   Example:
    %       rasterMon(myMonitor, 100, 0, 20, 1.0)
    %       % To stop: stop(myMonitor.monTimer)
    
    % Input validation
    if nargin < 5
        error('rasterMon requires 5 inputs: mon, upperVal, lowerVal, stepNum, dwellTime');
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
    
    % Stop existing raster timer if it exists
    if isprop(mon, 'monTimer') && ~isempty(mon.monTimer) && isvalid(mon.monTimer)
        stop(mon.monTimer);
        delete(mon.monTimer);
    end
    
    % Generate the step values
    stepValues = linspace(lowerVal, upperVal, stepNum);
    
    % Create full raster pattern (up and down)
    % Going up: lowerVal -> upperVal
    % Going down: upperVal -> lowerVal (excluding endpoints to avoid duplication)
    rasterPattern = [stepValues, fliplr(stepValues(2:end-1))];
    numSteps = length(rasterPattern);
    
    fprintf('Starting raster scan with timer...\n');
    fprintf('Range: %.3f to %.3f\n', lowerVal, upperVal);
    fprintf('Steps: %d per cycle\n', stepNum);
    fprintf('Dwell time: %.3f s\n', dwellTime);
    fprintf('Total cycle time: %.3f s\n', numSteps * dwellTime);
    fprintf('To stop: stop(mon.monTimer)\n\n');
    
    % Lock the monitor
    if isprop(mon, 'lock')
        mon.lock = true;
    end
    
    % Timer callback function
    function timerCallback(src, ~)
        % Get current task number (1-indexed)
        currentStep = get(src, 'TasksExecuted');
        
        % Calculate position in raster pattern (cycles continuously)
        patternIndex = mod(currentStep - 1, numSteps) + 1;
        currentVal = rasterPattern(patternIndex);
        
        % Set the monitor value
        try
            mon.set(currentVal);
            
            % Display progress at the start of each cycle
%             if patternIndex == 1
%                 cycleNum = floor((currentStep - 1) / numSteps) + 1;
%                 fprintf('Starting cycle %d\n', cycleNum);
%             end
%             
%             % Periodic progress display within cycle
%             if mod(patternIndex - 1, max(1, floor(numSteps/5))) == 0
%                 fprintf('  Step %d/%d: Set to %.3f\n', patternIndex, numSteps, currentVal);
%             end
        catch ME
            fprintf('Error setting monitor value: %s\n', ME.message);
            stop(src);
        end
    end
    
    % Timer start function
    function startFunc(src, ~)
        if isprop(mon, 'lock')
            mon.lock = true;
        end
        fprintf('Raster timer started.\n');
    end
    
    % Timer stop function
    function stopFunc(src, ~)
        if isprop(mon, 'lock')
            mon.lock = false;
        end
        fprintf('Raster timer stopped. Total steps executed: %d\n', get(src, 'TasksExecuted'));
    end
    
    % Create and configure the timer
    mon.monTimer = timer('Name', 'rasterMonTimer',...
        'Period', dwellTime,...
        'ExecutionMode', 'fixedRate',...
        'BusyMode', 'queue',...
        'TasksToExecute', inf,...  % Run indefinitely
        'StartDelay', 0,...
        'TimerFcn', @timerCallback,...
        'StartFcn', @startFunc,...
        'StopFcn', @stopFunc,...
        'ErrorFcn', @stopFunc);
    
    % Start the timer
    start(mon.monTimer);
end
