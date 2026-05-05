
% Add all subfolders to path
addPathsSansGit;

% Initialize GUI

% Create dialog figure for GUI selection and options
dlg = dialog('Name', 'GUI Startup Options', ...
    'Position', [300 300 300 290]);

% Add GUI selection list
guiTypes = {'Beamline GUI', 'SWIPS GUI', 'MCP Cam Control'};
uicontrol(dlg, 'Style', 'text', ...
    'Position', [20 240 260 30], ...
    'String', 'Select GUI to launch:', ...
    'HorizontalAlignment', 'left');

guiList = uicontrol(dlg, 'Style', 'listbox', ...
    'Position', [20 180 260 60], ...
    'String', guiTypes, ...
    'Value', 1, ...
    'BackgroundColor', 'white');

% Add launch options
uicontrol(dlg, 'Style', 'text', ...
    'Position', [20 145 260 20], ...
    'String', 'Launch Options:', ...
    'HorizontalAlignment', 'left');
newInstanceCheck = uicontrol(dlg, 'Style', 'checkbox', ...
    'Position', [20 115 260 30], ...
    'String', 'Launch in new MATLAB instance (no desktop)', ...
    'Value', 0);

% Add timer clearing checkbox
uicontrol(dlg, 'Style', 'text', ...
    'Position', [20 85 260 20], ...
    'String', 'Timer Management:', ...
    'HorizontalAlignment', 'left');
timerRadio = uicontrol(dlg, 'Style', 'checkbox', ...
    'Position', [20 55 260 30], ...
    'String', 'Clear existing timers before launch', ...
    'Value', 1);

% Add OK and Cancel buttons
uicontrol(dlg, 'Style', 'pushbutton', ...
    'Position', [60 15 80 30], ...
    'String', 'OK', ...
    'Callback', @(~,~) uiresume(dlg));
uicontrol(dlg, 'Style', 'pushbutton', ...
    'Position', [160 15 80 30], ...
    'String', 'Cancel', ...
    'Callback', @(~,~) delete(dlg));

% Wait for user response
uiwait(dlg);

% Check if dialog still exists (not cancelled)
if isvalid(dlg)
    % Get selected values
    guiIdx         = get(guiList,         'Value');
    clearTimers    = get(timerRadio,      'Value');
    launchNew      = get(newInstanceCheck,'Value');
    delete(dlg);
    button = 'OK';
else
    button = 'Cancel';
end

switch button
    case 'OK'
        % Clear timers if option selected
        if clearTimers
            alltimers = timerfindall;
            if ~isempty(alltimers)
                stop(alltimers);
                delete(alltimers);
                disp('Existing timers cleared.');
            end
        end

        if launchNew
            % Build the MATLAB command to run in the new instance
            startupDir = fileparts(which('startup'));
            if isempty(startupDir)
                startupDir = pwd;
            end
            switch guiIdx
                case 1
                    runCmd = 'mybeamlineGUI = beamlineGUI;';
                case 2
                    runCmd = 'mySWIPS_GUI = SWIPS_GUI;';
                case 3
                    runCmd = 'MainScript;';
            end
            % Escape single quotes in the path for the -r string
            escapedDir = strrep(startupDir, "'", "''");
            matlabCmd = sprintf("cd('%s'); addPathsSansGit; %s", escapedDir, runCmd);
            % Launch detached new MATLAB instance with no desktop
            system(sprintf('start "" matlab -nodesktop -nosplash -r "%s"', matlabCmd));
        else
            % Launch in current instance
            switch guiIdx
                case 1
                    mybeamlineGUI = beamlineGUI;
                case 2
                    mySWIPS_GUI = SWIPS_GUI;
                case 3
                    MainScript;
            end
        end

    case 'Cancel'
        disp('Gui Powerup Aborted');
    case ''
        disp('Gui Powerup Aborted');
end


