function instruments = setupSWIPSInstruments()
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

  
     instruments = struct('Opal_Kelly',SWIPS_OK(),...
                                    'caen_HVPS1',caen_hvps(),...
                                    'newportStage',NewportStageControl('192.168.0.254')...
                                );
    
    instruments.caen_HVPS1.connectDevice;

%     instruments.newportStage.run;
    instruments.newportStage.initDevice();
%     instruments.newportStage.home();
    
    instruments.Opal_Kelly.connectDevice;
    instruments.Opal_Kelly.configurePPA_ok;
    %assign tags to instrument structures
    fields = fieldnames(instruments);
    for i=1:numel(fields)
        instruments.(fields{i}).Tag = fields{i};
    end


end