classdef acquisition < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here

    properties
        hBeamlineGUI % Handle to beamline GUI

        hFigure
        testLab = string
    end

    properties (Abstract, Constant)
        Type string % Acquisition type identifier string
    end

    methods

        function obj = acquisition(hGUI)
            %UNTITLED Construct an instance of this class
            %   Detailed explanation goes here
            obj.hBeamlineGUI = hGUI;
            
            obj.testLab = sprintf('%s_%s',num2str(obj.hBeamlineGUI.TestSequence),obj.Type);
            % Add listener to delete configuration GUI figure if main beamline GUI deleted
            listener(obj.hBeamlineGUI,'ObjectBeingDestroyed',@obj.beamlineGUIDeleted);
        end

        function beamlineGUIDeleted(obj,~,~)
            %BEAMLINEGUIDELETED Delete configuration GUI figure
            
            obj.closeGUI();
            if isvalid(obj) && isvalid(obj.hConfFigure)
                delete(obj.hConfFigure);
                delete(obj.hFigure);
            end
        end

    end

    methods (Abstract)
        runSweep(obj)

        closeGUI(obj)

        
    end

end

