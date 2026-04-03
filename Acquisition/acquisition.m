classdef acquisition < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here

    properties
        hBeamlineGUI % Handle to beamline GUI

        testLab = string
        guiParentStatListener = event.listener.empty;
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
            obj.guiParentStatListener = listener(obj.hBeamlineGUI,'ObjectBeingDestroyed',@obj.beamlineGUIDeleted);
        end

        function beamlineGUIDeleted(obj,~,~)
            %BEAMLINEGUIDELETED Delete configuration GUI figure
            
            obj.closeGUI();
            
        end

    end

    methods (Abstract)
        runSweep(obj)

        closeGUI(obj)

        function complete(obj,~,~)
            % Stop timer if valid and running, 
            if isvalid(obj.scanTimer)
                if strcmp(obj.scanTimer.Running,'on')
                    stop(obj.scanTimer);
                end
                delete(obj.scanTimer);
            end

            if obj.testRunning
                % Save results to CSV
                fname = fullfile(obj.hBeamlineGUI.DataDir,sprintf('%s_results.csv',obj.testLab));
                writetable(struct2table(obj.scan_mon), fname);
                fprintf('\nTest complete!\n');

                obj.testRunning = false;
            end
            %CLOSEGUI Re-enable beamline GUI run test button, restart timer, and delete obj when figure is closed
            % Enable beamline GUI run test button if still valid
            if isvalid(obj.hBeamlineGUI)
                set(obj.hBeamlineGUI.hRunBtn,'String','RUN TEST');
                set(obj.hBeamlineGUI.hRunBtn,'Enable','on');
            end
            obj.hBeamlineGUI.genTestSequence();
            % Restart beamline timers
            if isequal(obj.hBeamlineGUI.hLogTimer.Running, 'off')
                obj.hBeamlineGUI.restartTimer();
            end
        end
    end

end

