function instruments = setupSWIPSInstruments()
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

  
     instruments = struct('Opal_Kelly',SWIPS_OK(),...
                                    'caen_HVPS1',caen_hvps([],[],0,'config_caenPS.ini'),...
                                    "HvMCPn",srsPS350('GPIB0::04::INSTR'),...
                                    'newportStage',NewportStageControl('192.168.0.254'),...
                         "flukeHydra",flukeHydra2620A("GPIB0::6::INSTR")...
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

     % connect to devices
    instruments.caen_HVPS1.connectDevice();

    %Connect and configure Newport stage
    instruments.newportStage.connectDevice();
    instruments.newportStage.initDevice();
    
    function self = config_newport(self)
        if self.Connected
            self.myxps.PositionerUserTravelLimitsSet('Group1.Pos',-70,70);
            self.myxps.PositionerUserTravelLimitsSet('Group2.Pos',-150,150);
            self.myxps.PositionerUserTravelLimitsSet('Group3.Pos',-45,45);
        end
    end
    instruments.newportStage.funcConfig = @config_newport;
    config_newport(instruments.newportStage);

    %Connect and config opalkelly
    instruments.Opal_Kelly.connectDevice();

    % @2000V - 
    % instruments.Opal_Kelly.configurePPA_ok([68,60,60,60, 60,60,60,60, 60,60,60,61, 60,60,60,76]);
    % @2100V -
    % instruments.Opal_Kelly.configurePPA_ok([110,80,60,60, 75,60,72,60, 60,60,61,74, 86,84,87,115]);
    % @2200V post-vib -
    % instruments.Opal_Kelly.configurePPA_ok([110,80,72,72, 72,76,69,76, 75,75,75,75, 75,75,75,115]);
    % @2200V new exit grid mask -
    %instruments.Opal_Kelly.configurePPA_ok([154,119,107,97, 67,67,67,67, 69,68,95,112, 123,183,179,255]);
    % @2400V new exit grid mask Jan072026 -
    instruments.Opal_Kelly.configurePPA_ok([107,60,60,60, 60,60,60,60, 60,60,91,107, 146,117,109,150]);
    
    %assign tags to instrument structures
    fields = fieldnames(instruments);
    for i=1:numel(fields)
        instruments.(fields{i}).Tag = fields{i};
    end


end