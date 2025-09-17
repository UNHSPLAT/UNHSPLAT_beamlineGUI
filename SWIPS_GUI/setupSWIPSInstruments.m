function instruments = setupSWIPSInstruments()
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

  
     instruments = struct('Opal_Kelly',SWIPS_OK(),...
                                    'caen_HVPS1',caen_hvps([],[],0),...
                                    "HvMCPn",srsPS350('GPIB0::04::INSTR'),...
                                    'newportStage',NewportStageControl('192.168.0.254')...
                                );

     % Configure the Stanford research read functions
     function val = read_srsHVPS(self)
         if self.Connected
             val = self.measV;
         end
     end
     instruments.HvMCPn.readFunc = @read_srsHVPS;

     % connect to devices
    instruments.caen_HVPS1.connectDevice();

    %Connect and configure Newport stage
    instruments.newportStage.connectDevice();
    instruments.newportStage.initDevice();
%     instruments.newportStage.Home();
    
    function self = config_newport(self)
        if self.Connected
            self.myxps.PositionerUserTravelLimitsSet('Group1.Pos',-70,70);
            self.myxps.PositionerUserTravelLimitsSet('Group2.Pos',-150,150);
            self.myxps.PositionerUserTravelLimitsSet('Group3.Pos',-45,45);
        end
    end
%     config_newport(instruments.newportStage);

    %Connect and config opalkelly
    instruments.Opal_Kelly.connectDevice();
    instruments.Opal_Kelly.configurePPA_ok;
     
    %assign tags to instrument structures
    fields = fieldnames(instruments);
    for i=1:numel(fields)
        instruments.(fields{i}).Tag = fields{i};
    end


end