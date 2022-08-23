function monitors = setupMonitors(instruments)
    % Function initializing and defining properties of measured values


    % =======================================================================
    % define read functions monitors will call to manipulate instrument output 
    % =======================================================================
    function val = read_srsHVPS(self)
        val = self.parent.measV;
    end

    function set_srsHVPS(self,volt)

        if volt ==0
            volt =2;
        end
        if isnan(volt)
            errordlg('A valid voltage value must be entered!','Invalid input!');
            return
        elseif abs(volt) > abs(self.parent.VMax) || abs(volt) < abs(self.parent.VMin)
            errordlg(['Defl voltage setpoint must be between ',num2str(hDefl.VMin),' and ',num2str(hDefl.VMax),' V!'],'Invalid input!');
            return
        end    

        %check the voltage being applied and ramp the voltage in steps if need be
        minstep = 50;
        if abs(volt)-abs(self.lastRead)>minstep
            multivolt = linspace(self.lastRead,volt,ceil((abs(volt)-abs(self.lastRead))/minstep));
            disp('Ramping HV')
            for i = 1:numel(multivolt)
                self.parent.setVSet(multivolt(i));
                pause(2);
            end
        else
            self.parent.setVSet(volt);
        end
    end

    function val = read_voltEXB(self)
        HvExbp = self.parent(1);
        HvExbn = self.parent(2);
        val = HvExbp.measV()-HvExbn.measV();
    end

    % =======================================================================
    % define set functions monitors will use to set parameters
    % =======================================================================
    function set_voltEXB(self,volt)
        HvExbp = self.parent(1);
        HvExbn = self.parent(2);
        if volt ==0
            volt =2;
        end

        %check the voltage being applied and ramp the voltage in steps if need be
        minstep = 50;
        if abs(volt)-abs(self.lastRead)/2>minstep
            multivolt = linspace(self.lastRead,volt,ceil((volt-self.lastRead)/minstep));
            for i = 1:numel(multivolt)
                HvExbp.setVSet(multivolt(i)/2);
                pause(1);
                HvExbn.setVSet(-multivolt(i)/2);
                pause(1);
            end
        else
            HvExbp.setVSet(volt/2);
            pause(1);
            HvExbn.setVSet(-volt/2);
        end

    end

    % =======================================================================
    % Define monitors and set parameters 
    %   monitors that dont have parent instruments (such as a datetime measurement)
    %   to pull parameters from should assign 
    %       - parent = struct("Type",'local','Connected',true)
    %   to bypass instrument connection checks correctly
    % =======================================================================

    monitors = struct(...       
                'voltChicane1',monitor('readFunc',@read_srsHVPS,...
                                     'setFunc',@set_srsHVPS,...
                                     'textLabel','Chicane Voltage 1',...
                                     'unit','V',...
                                     'active',true,...
                                     'formatSpec','%.0f',...
                                     'group','Chicane',...
                                     'parent',instruments.HvChicane1...
                                     ),...
                'voltChicane2',monitor('readFunc',@read_srsHVPS,...
                                     'setFunc',@set_srsHVPS,...
                                     'textLabel','Chicane Voltage 2',...
                                     'unit','V',...
                                     'active',true,...
                                     'formatSpec','%.0f',...
                                     'group','Chicane',...
                                     'parent',instruments.HvChicane2...
                                     ),...
                 'voltDefl',monitor('readFunc',@read_srsHVPS,...
                                     'setFunc',@set_srsHVPS,...
                                     'textLabel','Defl Voltage',...
                                     'unit','V',...
                                     'active',true,...
                                     'formatSpec','%.0f',...
                                     'group','HV',...
                                     'parent',instruments.HvDefl...
                                     ),...
                 'voltXsteer',monitor('readFunc',@read_srsHVPS,...
                                     'setFunc',@set_srsHVPS,...
                                     'textLabel','X-Steer Voltage',...
                                     'unit','V',...
                                     'active',true,...
                                     'formatSpec','%.0f',...
                                     'group','HV',...
                                     'parent',instruments.HvEsa...
                                     ),...
                 'voltYsteer',monitor('readFunc',@read_srsHVPS,...
                                     'setFunc',@set_srsHVPS,...
                                     'textLabel','Y-Steer Voltage',...
                                     'unit','V',...
                                     'active',true,...
                                     'formatSpec','%.0f',...
                                     'group','HV',...
                                     'parent',instruments.HvYsteer...
                                     ),...
                 'voltExbn',monitor('readFunc',@read_srsHVPS,...
                                     'setFunc',@(self,x) set_srsHVPS(self,-abs(x)),...
                                     'textLabel','ExB- Voltage',...
                                     'unit','V',...
                                     'active',true,...
                                     'formatSpec','%.0f',...
                                     'group','HV',...
                                     'parent',instruments.HvExbn...
                                     ),...
                 'voltExbp',monitor('readFunc',@read_srsHVPS,...
                                     'setFunc',@set_srsHVPS,...
                                     'textLabel','ExB+ Voltage',...
                                     'unit','V',...
                                     'active',true,...
                                     'formatSpec','%.0f',...
                                     'parent',instruments.HvExbp...
                                     ),...
                 'voltEXB',monitor('readFunc',@read_voltEXB,...
                                     'setFunc',@set_voltEXB,...
                                     'textLabel','ExB Voltage',...
                                     'unit','V',...
                                     'active',true,...
                                     'formatSpec','%.0f',...
                                     'group','HV',...
                                     'parent',[instruments.HvExbp,instruments.HvExbn]...
                                     ),...
                 'voltExt',monitor('readFunc',@(x) x.parent.performScan(1,1)*4000,...
                                     'textLabel','Extraction Voltage',...
                                     'unit','V',...
                                     'formatSpec','%.0f',...
                                     'group','HV',...
                                     'parent',instruments.keithleyMultimeter1...
                                     ),...
                 'voltLens',monitor('readFunc',@(x) x.parent.performScan(2,2)*1000,...
                                     'textLabel','Lens Voltage',...
                                     'unit','V',...
                                     'group','HV',...
                                     'formatSpec','%.0f',...
                                     'parent',instruments.keithleyMultimeter1...
                                     ),...
                 'voltMFC',monitor('readFunc',@(x) x.parent(1).performScan(3,3),...
                                     'setFunc',@(self,x) self.parent(2).setVSet(x,1),...
                                     'textLabel','MFC Voltage',...
                                     'unit','V',...
                                     'active',true,...
                                     'group','LV',...
                                     'parent',[instruments.keithleyMultimeter1,...
                                                instruments.LvMass]...
                                     ),...
                 'pressureBeamIG1',monitor('readFunc',@(x) x.parent.readPressure(1),...
                                     'textLabel','Beam Pressure (IG1)',...
                                     'unit','T',...
                                     'group','pressure',...
                                     'parent',instruments.leyboldPressure2...
                                     ),...
                 'pressureChamberIG1',monitor('readFunc',@(x) x.parent.readPressure(2),...
                                     'textLabel','Chamber Pressure (IG1)',...
                                     'unit','T',...
                                     'group','pressure',...
                                     'parent',instruments.leyboldPressure2...
                                     ),...
                 'pressureChamberIG2',monitor('readFunc',@(x) x.parent.readPressure(3),...
                                     'textLabel','Chamber Pressure (IG2)',...
                                     'unit','T',...
                                     'group','pressure',...
                                     'parent',instruments.leyboldPressure2...
                                     ),...
                 'pressureBeamIG2',monitor('readFunc',@(x) x.parent.readPressure(1),...
                                     'textLabel','Beam Pressure (IG2)',...
                                     'unit','T',...
                                     'group','pressure',...
                                     'parent',instruments.leyboldPressure3...
                                     ),...
                 'pressureChamberRough1',monitor('readFunc',@(x) x.parent.readPressure(2),...
                                     'textLabel','Chamber Rough Pressure (TTR1)',...
                                     'unit','T',...
                                     'group','pressure',...
                                     'parent',instruments.leyboldPressure3...
                                     ),...
                 'pressureSourceGas',monitor('readFunc',@(x) x.parent.readPressure(1),...
                                     'textLabel','Source Gas Inflow Pressure',...
                                     'unit','T',...
                                     'formatSpec','%.2f',...
                                     'group','pressure',...
                                     'parent',instruments.leyboldPressure1...
                                     ),...
                 'pressureBeamRough',monitor('readFunc',@(x) x.parent.readPressure(2),...
                                     'textLabel','Beam Rough Pressure',...
                                     'unit','T',...
                                     'group','pressure',...
                                     'parent',instruments.leyboldPressure1...
                                     ),...
                  'dateTime',monitor('readFunc',@(x) datetime(now(),'ConvertFrom','datenum'),...
                                     'textLabel','Date Time',...
                                     'unit','D-M-Y H:M:S',...
                                     'parent',struct("Type",'local','Connected',true),...
                                     'formatSpec',"%s"...
                                     ),...
                  'T',monitor('readFunc',@(x) now(),...
                                     'textLabel','Time',...
                                     'unit','DateNum',...
                                     'parent',struct("Type",'local','Connected',true),...
                                     'formatSpec',"%d"...
                                     ),...
                  'Ifaraday',monitor('readFunc',@(x) x.parent.read(),...
                                     'textLabel','I Faraday Cup',...
                                     'unit','A',...
                                     'formatSpec','%.3e',...
                                     'parent',instruments.picoFaraday...
                                     )...
                 );

    %assign tags to instrument tag parameters, may just want to have these and the 
    %   instrument structs setup as lists
     fields = fieldnames(monitors);
     for i=1:numel(fields)
         monitors.(fields{i}).setfield('Tag',fields{i});
     end
end