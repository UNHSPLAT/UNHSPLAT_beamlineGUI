function vacControl_fHVcrossover(vacController)
    % Function to execute the HV Crossover process in the vacuum control system.
    
    monplot = monitorPlot(vacController.hFigure, ...
                        vacController.processPanel, ...
                vacController.Monitors.dateTime, ... 
                vacController.Monitors.pressureChamberRough1);

    
    % Retrieve TightInset margins [left, bottom, right, top]
    inset = get(monplot.ax, 'TightInset');
    % Set axes Position to fill the panel accounting for margins
    set(monplot.ax, 'Position', [inset(1), inset(2), 1 - inset(1) - inset(3), 1 - inset(2) - inset(4)]);

    while vacController.processRunning
        pause(1); % Pause to allow GUI to update
    end

    delete(monplot.ax); % Close the figure when process is done
    delete(monplot)
    display('HV Crossover process completed.');

end