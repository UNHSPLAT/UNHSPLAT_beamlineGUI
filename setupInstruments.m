 function instruments = setupInstruments

    % Define configuration funcitons to be executed on connection

    %Config Multimeter
    function config_keithleyMultimeter(hDMM)
        if hDMM.Connected
            hDMM.devRW('SENS:FUNC "VOLT", (@101:103)');
            hDMM.devRW('SENS:VOLT:INP MOHM10, (@101:103)');
            hDMM.devRW('SENS:VOLT:NPLC 1, (@101:103)');
            hDMM.devRW('ROUT:SCAN:CRE (@101:103)');
        end
    end

    % Configure picoammeter
    function config_picoFaraday(hFaraday)
        trynum = 3;
        if hFaraday.Connected
%             hFaraday.Tag = "Faraday";
            hFaraday.devRW(':SYST:ZCH OFF');
            dataOut = strtrim(hFaraday.devRW(':SYST:ZCH?'));
            i = 1;
            while ~strcmp(dataOut,'0') && trynum<i
                warning('beamlineGUI:keithleyNonresponsive','Keithley not listening! Zcheck did not shut off as expected...');
                hFaraday.devRW(':SYST:ZCH OFF');
                dataOut = strtrim(hFaraday.devRW(':SYST:ZCH?'));
                trynum=trynum+1;
            end
            hFaraday.devRW('ARM:COUN 1');
            dataOut = strtrim(hFaraday.devRW('ARM:COUN?'));
            i = 1;
            while ~strcmp(dataOut,'1') && trynum<i
                warning('beamlineGUI:keithleyNonresponsive','Keithley not listening! Arm count did not set to 1 as expected...');
                hFaraday.devRW('ARM:COUN 1');
                dataOut = strtrim(hFaraday.devRW('ARM:COUN?'));
                trynum=trynum+1;
            end
            hFaraday.devRW('FORM:ELEM READ');
            dataOut = strtrim(hFaraday.devRW('FORM:ELEM?'));
            i = 1;
            while ~strcmp(dataOut,'READ') && trynum<i
                warning('beamlineGUI:keithleyNonresponsive','Keithley not listening! Output format not set to ''READ'' as expected...');
                hFaraday.devRW('FORM:ELEM READ');
                dataOut = strtrim(hFaraday.devRW('FORM:ELEM?'));
                trynum=trynum+1;
            end
            hFaraday.devRW(':SYST:LOC');
        end
    end

    % Generate list of available hardware

%     
    instruments = struct("leyboldPressure1",leyboldCenter2("ASRL7::INSTR"),...
                         "leyboldPressure3",leyboldGraphix3("ASRL10::INSTR"),...
                         "picoFaraday",keithley6485('GPIB0::14::INSTR',@config_picoFaraday),...
                         "HvExbn",srsPS350('GPIB0::19::INSTR'),...
                         "HvExbp",srsPS350('GPIB0::15::INSTR'),...
                         "HvEsa",srsPS350('GPIB0::16::INSTR'),...
                         "HvDefl",srsPS350('GPIB0::17::INSTR'),...
                         "HvYsteer",srsPS350('GPIB0::18::INSTR'),...
                         "LvMass",keysightE36313A('GPIB0::5::INSTR'),...
                         "leyboldPressure2",leyboldGraphix3("ASRL8::INSTR"),...
                         "keithleyMultimeter1",keithleyDAQ6510('USB0::0x05E6::0x6510::04524689::0::INSTR',...
                                                               @config_keithleyMultimeter),...
                         "MCPwebCam",camControl(),...
                         "newportStage",NewportStageControl('192.168.0.254')...
                         );

    

    %assign tags to instrument structures
    fields = fieldnames(instruments);
    for i=1:numel(fields)
        instruments.(fields{i}).Tag = fields{i};
    end

    % =======================================================================
    % define read functions monitors will call to manipulate instrument output 
    % need to move these to the instrument classes
    % =======================================================================
    function val = read_srsHVPS(self)
         if self.Connected
             val = self.measV;
         end
    end
    
    function val = read_pressure(self)

         if self.Connected
            val = self.readPressure();
         end
    end

     function val = read_pico(self)
         if self.Connected
            val  = self.readDev();
         end
     end

     function val = read_keithley(self)
         if self.Connected
            val =  self.performScan(1,3);
         end
     end

     function val = read_keysight(self)
         if self.Connected
            val =  self.measV;
         end
     end
     readStruct = struct("leyboldPressure1",@read_pressure,...
                         "leyboldPressure2",@read_pressure,...
                         "leyboldPressure3",@read_pressure,...
                         "picoFaraday",@read_pico,...
                         "HvExbn",@read_srsHVPS,...
                         "HvExbp",@read_srsHVPS,...
                         "HvEsa",@read_srsHVPS,...
                         "HvDefl",@read_srsHVPS,...
                         "HvYsteer",@read_srsHVPS,...
                         "keithleyMultimeter1",@read_keithley,...
                         "LvMass",@read_keysight...
                         );
    % assign the read functions to their struct
    fields = fieldnames(readStruct);
    for i=1:numel(fields)
        instruments.(fields{i}).readFunc = readStruct.(fields{i});
    end
end