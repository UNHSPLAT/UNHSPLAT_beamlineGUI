function ramp_singleChanCaen(monCaenVolt)
    prompt = {'Enter desired set voltage:','Enter step size [V]:','Enter dwell time [s]:'};
    dlgtitle = 'Caen Voltage Ramp';
    fieldsize = [1 45; 1 45; 1 45];
    try
        chLastRead = char(string(monCaenVolt.lastRead));
    catch
        chLastRead = '0';
    end

    definput = {chLastRead,'20','10'};
    answer = inputdlg(prompt,dlgtitle,fieldsize,definput);
    
    % abort if cancel button pressed
    if isempty(answer)
        fprintf('Ramp Aborted\n')
        return
    end

    vSet = abs(str2double(answer{1}));
    step = abs(str2double(answer{2}));
    dwell = str2double(answer{3});
    
    if or(isnan(vSet),isnan(step)) || isnan(dwell)
        errordlg('A valid voltage value must be entered!','Invalid input!');
        return
    end    
    monCaenVolt.lock = true;

    % define coupled voltage set func
    function setV(vOut)
        monCaenVolt.parent.read();
        monCaenVolt.set(vOut);
    end

    %define voltage ramp stop function
    function stop_func(src,evt)
        monCaenVolt.parent.read();
        monCaenVolt.lock = false;

        delete(monCaenVolt.monTimer);
    end

    function startFunc(src,evt)
        monCaenVolt.lock = true;
    end

    %check the voltage being applied and ramp the voltage in steps if need be
    vStart = monCaenVolt.lastRead;
        
    if abs(vSet-vStart)>step
        multivolt = linspace(vStart,vSet,ceil((abs(vSet-monCaenVolt.lastRead))/step)+1);
        multivolt = multivolt(2:end);
        
        monCaenVolt.monTimer = timer('Period',dwell,... %period
                  'ExecutionMode','fixedSpacing',... %{singleShot,fixedRate,fixedSpacing,fixedDelay}
                  'BusyMode','queue',... %{drop, error, queue}
                  'TasksToExecute',numel(multivolt),...          
                  'StartDelay',0,...
                  'TimerFcn',@(src,evt)setV(multivolt(get(src,'TasksExecuted'))),...
                  'StartFcn',@startFunc,...
                  'StopFcn',@stop_func,...
                  'ErrorFcn',@stop_func);
        start(monCaenVolt.monTimer);
    else
        setVImgMCP(vSet);
        monCaenVolt.lock = false;
    end
end