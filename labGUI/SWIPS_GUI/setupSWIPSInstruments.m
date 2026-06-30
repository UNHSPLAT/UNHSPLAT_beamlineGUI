function instruments = setupSWIPSInstruments()
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

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

    function config_lvps(self)
        states = self.getOutputState();
        if states(2)==0
            self.setVSet(6,2)
            self.setISet(1,2)
        end
        
        if states(3)==0
            self.setVSet(6,3)
            self.setISet(1,3)
        end

        self.getAllSettings();
        display(self.VSet);
        display(self.ISet);
        display(self.OutputState);
    end
    
    function read_LVPS(self)
        if self.Connected
            self.lastIRead = self.measI;
            pause(0.1);
            drawnow();
            self.lastRead = self.measV;
        else
            self.lastIRead = [nan,nan,nan];
            self.lastRead = [nan,nan,nan];
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
    end

     instruments = struct('Opal_Kelly',SWIPS_OK(),...
                        'caen_HVPS1',caen_hvps('','LBus_Address',0,'equip_config_filename','config_caenPS.ini'),...
                        "HvMCPn",srsPS350('GPIB0::04::INSTR'),...
                        'newportStage',NewportStageControl('192.168.0.254'),...
                         "picoPHD",keithley6485('GPIB0::14::INSTR','funcConfig',@config_picoFaraday),...
                         "sr620counter",srsSR620("GPIB0::30::INSTR",'funcConfig',@config_sr620),...
                         "swipsLVPS",keysightE36313A('GPIB0::5::INSTR', ...
                                                        'readFunc',@read_LVPS, ...
                                                        'funcConfig',@config_lvps)...
                                );

     % Configure the Stanford research read functions
     function val = read_srsHVPS(self)
         val = zeros(2,1);
         if self.Connected
             val(1) = self.measV;
             val(2) = self.measI;
         end
     end
     instruments.HvMCPn.readFunc = @read_srsHVPS;

     % Configure the picoammeter read function
     function val = read_pico(self)
            val  = self.readDev();
     end
     instruments.picoPHD.readFunc = @read_pico;

    %configure Newport stage
    
    function self = config_newport(self)
        if self.Connected
            self.myxps.PositionerUserTravelLimitsSet('Group1.Pos',-70,70);
            self.myxps.PositionerUserTravelLimitsSet('Group2.Pos',-150,150);
            self.myxps.PositionerUserTravelLimitsSet('Group3.Pos',-135,45);
        end
    end
    instruments.newportStage.funcConfig = @config_newport;

     %configure Opal Kelly PPA settings
     function self = config_ok(self)
         if self.Connected
             self.configurePPA_ok([75,72,78,75, 81,75,72,66, 66,75,75,87, 84,84,81,90]);
         end
     end
     instruments.Opal_Kelly.funcConfig = @config_ok;


                                                            
    
    %assign tags to instrument structures
    fields = fieldnames(instruments);
    for i=1:numel(fields)
        instruments.(fields{i}).Tag = fields{i};
    end


end