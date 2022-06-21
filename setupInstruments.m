function instruments = setupInstruments
    instruments = struct("leyboldPressure1",leyboldCenter2("ASRL7::INSTR"),...
                         "leyboldPressure2",leyboldGraphix3("ASRL8::INSTR"),...
                         "picoFaraday",keithley6485('__addressPicoammeter__'),...
                         "HvExbn",srsPS350('GPIB0::14::INSTR'),...
                         "HvExbp",srsPS350('GPIB0::15::INSTR'),...
                         "HvEsa",srsPS350('GPIB0::16::INSTR'),...
                         "HvDefl",srsPS350('GPIB0::17::INSTR'),...
                         "HvYsteer",srsPS350('GPIB0::18::INSTR'),...
                         "LvMass",keysightE36313A('GPIB0::5::INSTR'),...
                         "keithleyMultimeter1",keithleyDAQ6510('__addressMultimiter__')...
                         )
    tags = struct("leyboldPressure1","Gas,Rough",...
                 "leyboldPressure2","Beamline,Chamber",...
                 "picoFaraday","Faraday",...
                 "HvExbn","Exbn",...
                 "HvExbp","Exbp",...
                 "HvEsa","Esa",...
                 "HvDefl","Defl",...
                 "HvYsteer","Ysteer",...
                 "LvMass","Mass",...
                 "keithleyMultimeter1","Extraction,Einzel,Mass"...
                 )

    %assign tags to instrument structures
    fields = fieldnames(instruments)
    for i=1:numel(fields)
        setfield(getfield(instruments,fields{i}),'Tag',getfield(tags,fields{i}))
end