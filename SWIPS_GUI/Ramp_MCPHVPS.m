function Ramp_MCPHVPS(monMCP)
    prompt = {'Enter desired set voltage:','Enter step size [V]:','Enter dwell time [s]:'};
    dlgtitle = 'MCP Ramp';
    fieldsize = [1 45; 1 45; 1 45];
    
    definput = {char(string(monMCP.lastRead)),'20','10'};
    answer = inputdlg(prompt,dlgtitle,fieldsize,definput);

    vSet = -abs(str2double(answer{1}));
    step = abs(str2double(answer{2}));
    dwell = str2double(answer{3});
    
    if or(isnan(vSet)|isnan(step),isnan(dwell))
        errordlg('A valid voltage value must be entered!','Invalid input!');
        return
    elseif abs(vSet) > abs(monMCP.parent.VMax) || abs(vSet) < abs(monMCP.parent.VMin)
        errordlg(['Defl voltage setpoint must be between ',num2str(hDefl.VMin),' and ',num2str(hDefl.VMax),' V!'],'Invalid input!');
        return
    end    

    function stop_func(src,evt)
        monMCP.read();
        monMCP.lock = false;
        delete(monMCP.monTimer);
    end
    monMCP.lock = true;
    %check the voltage being applied and ramp the voltage in steps if need be
    vStart = monMCP.lastRead;
        
    if abs(vSet-vStart)>step
        multivolt = linspace(vStart,vSet,ceil((abs(vSet-monMCP.lastRead))/step)+1);
        multivolt = multivolt(2:end);
        monMCP.monTimer = timer('Period',dwell,... %period
                  'ExecutionMode','fixedSpacing',... %{singleShot,fixedRate,fixedSpacing,fixedDelay}
                  'BusyMode','queue',... %{drop, error, queue}
                  'TasksToExecute',numel(multivolt),...          
                  'StartDelay',0,...
                  'TimerFcn',@(src,evt)monMCP.parent.setVSet(multivolt(get(src,'TasksExecuted'))),...
                  'StartFcn',@(src,evt)setfield( monMCP , 'lock' , true ),...
                  'StopFcn',@stop_func,...
                  'ErrorFcn',@stop_func);
        start(monMCP.monTimer);
    else
        monMCP.parent.setVSet(vSet);
        monMCP.lock = false;
    end
end