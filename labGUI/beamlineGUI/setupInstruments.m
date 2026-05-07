 function instruments = setupInstruments

    % Define configuration funcitons to be executed on connection
    %
     function fluke_config(fluke)
        fprintf('Configuring Fluke Hydra...\n');

        % disable scan for configure
        fluke.devRW("SCAN 0");
        
        % disable all channels for configure
        for ch = 1:10
            fluke.devRW(sprintf("FUNC %d OFF", ch));
            display(fluke.devRW(sprintf("FUNC? %d", ch)));
        end

        %% Enable and config Thermocouples
        % Attached to instrument chasis
        fluke.devRW("FUNC 1,TEMP,J");
        display(fluke.devRW("FUNC? 1"));
        
%         fluke.devRW("FUNC 3,TEMP,J");
%         display(fluke.devRW("FUNC? 3"));
        
        % Attached to opalkelly
        fluke.devRW("FUNC 4,TEMP,J");
        display(fluke.devRW("FUNC? 4"));
        
        % Attached to chamber 
        fluke.devRW("FUNC 5,TEMP,J");
        display(fluke.devRW("FUNC? 5"));
        
        fluke.devRW("INTVL 0,0,3");
        display(fluke.devRW("INTVL?"));
        
        fluke.devRW("SCAN 1");
     end

    %Config Multimeter
    function config_keithleyMultimeter(hDMM)
        fprintf('Configuring Keithley Multimeter...\n');
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

    function config_sr620(count)
        fprintf('Configuring SR620 Counter...');
        % Disable auto measurement  mode
        stat = count.devRW('AUTM 0; AUTM?');
        fprintf('AUTM 0 -> %s\n', strtrim(stat));

        % Set to count mode
        stat = count.devRW('MODE 6; MODE?');
        fprintf('MODE 6 -> %s\n', strtrim(stat));

        % Set sample number:
        stat = count.devRW('SIZE 1; SIZE?');
        fprintf('SIZE 1 -> %s\n', strtrim(stat));

        % Set Gate arm/gate mode to 1s
        stat = count.devRW('ARMM 5; ARMM?');
        fprintf('ARMM 5 -> %s\n', strtrim(stat));

        % Set Gate redundant with arm
        %stat = count.devRW('GATE 3; GATE?');
        
        %set Levels, not currently imp
        % » stat = count.devRW('LEVL? 0')
        % stat ='1.95'
        % » stat = count.devRW('LEVL? 1')
        % stat ='0.92'
        % » stat = count.devRW('LEVL? 2')
        % stat = '0.01
    end

    % Define hardware objects for each instrument, with appropriate configuration functions
    instruments = struct("leyboldPressure1",leyboldCenter2("ASRL7::INSTR",'autoConnect',true),...
                         "leyboldPressure3",leyboldGraphix3("ASRL10::INSTR",'autoConnect',true),...
                         "picoFaraday",keithley6485('GPIB0::14::INSTR','funcConfig',@config_picoFaraday),...
                         "HvExbn",srsPS350('GPIB0::19::INSTR'),...
                         "HvExbp",srsPS350('GPIB0::15::INSTR'),...
                         "HvEsa",srsPS350('GPIB0::16::INSTR'),...
                         "HvDefl",srsPS350('GPIB0::17::INSTR'),...
                         "HvYsteer",srsPS350('GPIB0::18::INSTR'),...
                         "LvMass",keysightE36313A('GPIB0::5::INSTR'),...
                         "leyboldPressure2",leyboldGraphix3("ASRL8::INSTR", ...
                                                        'autoConnect',true, ...
                                                        'refreshRate',2),...
                         "keithleyMultimeter1",keithleyDAQ6510('USB0::0x05E6::0x6510::04524689::0::INSTR',...
                                                               'funcConfig',@config_keithleyMultimeter, ...
                                                               'autoConnect',true),...
                         "MCPwebCam",camControl(),...
                         "caen_HVPS2",caen_hvps([],'LBus_Address',2,'equip_config_filename','config_caenPS2.ini'),...
                         "sr620counter",srsSR620("GPIB0::30::INSTR",'funcConfig',@config_sr620),...
                         "flukeHydra",flukeHydra2620A("GPIB0::6::INSTR", ...
                                                'funcConfig',@fluke_config,'autoConnect',true),...
                         "webpowerstrip1",webpowerstrip("192.168.0.110", ...
                                                        'autoConnect',true, ...
                                                         'refreshRate',2)...
                         );
     function scan_val = read_keithley(self)
            scan_val = self.performScan(1,3);
     end
    instruments.keithleyMultimeter1.readFunc = @read_keithley;
    %assign tags to instrument structures
    fields = fieldnames(instruments);
    for i=1:numel(fields)
        instruments.(fields{i}).Tag = fields{i};
    end

end