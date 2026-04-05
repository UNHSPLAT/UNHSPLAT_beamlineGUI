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
  
     instruments = struct('Opal_Kelly',SWIPS_OK(),...
                                    'caen_HVPS1',caen_hvps('',@(x) x,0,'config_caenPS.ini'),...
                                    "HvMCPn",srsPS350('GPIB0::04::INSTR'),...
                                    'newportStage',NewportStageControl('192.168.0.254'),...
                         "picoPHD",keithley6485('GPIB0::14::INSTR',@config_picoFaraday)...
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
             self.configurePPA_ok([107,60,60,60, 60,60,60,60, 60,60,91,107, 146,117,109,150]);
         end
     end
     instruments.Opal_Kelly.funcConfig = @config_ok;


    % @2000V - 
    % instruments.Opal_Kelly.configurePPA_ok([68,60,60,60, 60,60,60,60, 60,60,60,61, 60,60,60,76]);
    % @2100V -
    % instruments.Opal_Kelly.configurePPA_ok([110,80,60,60, 75,60,72,60, 60,60,61,74, 86,84,87,115]);
    % @2200V post-vib -
    % instruments.Opal_Kelly.configurePPA_ok([110,80,72,72, 72,76,69,76, 75,75,75,75, 75,75,75,115]);
    % @2200V new exit grid mask -
    %instruments.Opal_Kelly.configurePPA_ok([154,119,107,97, 67,67,67,67, 69,68,95,112, 123,183,179,255]);
    % @2400V new exit grid mask Jan072026 -
    % instruments.Opal_Kelly.configurePPA_ok([107,60,60,60, 60,60,60,60, 60,60,91,107, 146,117,109,150]);
    
    %assign tags to instrument structures
    fields = fieldnames(instruments);
    for i=1:numel(fields)
        instruments.(fields{i}).Tag = fields{i};
    end


end