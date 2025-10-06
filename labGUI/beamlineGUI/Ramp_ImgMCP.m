function Ramp_ImgMCP(monMCP_Va,monMCP_vOut)
    prompt = {'Enter desired set voltage:','Enter step size [V]:','Enter dwell time [s]:'};
    dlgtitle = 'IMG MCP Ramp';
    fieldsize = [1 45; 1 45; 1 45];
    try
        chLastRead = char(string(monMCP_Va.lastRead));
    catch
        chLastRead = '0';
    end

    definput = {chLastRead,'20','10'};
    answer = inputdlg(prompt,dlgtitle,fieldsize,definput);

    vSet = abs(str2double(answer{1}));
    step = abs(str2double(answer{2}));
    dwell = str2double(answer{3});
    
    if or(isnan(vSet),isnan(step)) || isnan(dwell)
        errordlg('A valid voltage value must be entered!','Invalid input!');
        return
    end    

    % define coupled voltage set func
    function setVImgMCP(vA)
        vOut = vA*2100/2400;
        monMCP_Va.set(vA);
        monMCP_vOut.set(vOut);
    end

    %define voltage ramp stop function
    function stop_func(src,evt)
        monMCP_Va.parent.read();
        monMCP_Va.lock = false;

        delete(monMCP_Va.monTimer);
        monMCP_vOut.lock = false;
    end

    function startFunc(src,evt)
        monMCP_Va.lock = true;
        monMCP_vOut.lock = true;
    end

    %check the voltage being applied and ramp the voltage in steps if need be
    vStart = monMCP_Va.lastRead;
        
    if abs(vSet-vStart)>step
        multivolt = linspace(vStart,vSet,ceil((abs(vSet-monMCP_Va.lastRead))/step)+1);
        multivolt = multivolt(2:end);
        
        monMCP_Va.monTimer = timer('Period',dwell,... %period
                  'ExecutionMode','fixedSpacing',... %{singleShot,fixedRate,fixedSpacing,fixedDelay}
                  'BusyMode','queue',... %{drop, error, queue}
                  'TasksToExecute',numel(multivolt),...          
                  'StartDelay',0,...
                  'TimerFcn',@(src,evt)setVImgMCP(multivolt(get(src,'TasksExecuted'))),...
                  'StartFcn',@startFunc,...
                  'StopFcn',@stop_func,...
                  'ErrorFcn',@stop_func);
        start(monMCP_Va.monTimer);
    else
        setVImgMCP(vSet);
        monMCP_Va.lock = false;
        monMCP_vOut.lock = false;
    end
end