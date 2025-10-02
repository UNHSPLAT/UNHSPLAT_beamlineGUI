
% Add all subfolders to path
addPathsSansGit;

% Initialize GUI

% Create dialog figure for GUI selection and options
dlg = dialog('Name', 'GUI Startup Options', ...
    'Position', [300 300 300 250]);

% Add GUI selection list
guiTypes = {'Beamline GUI', 'SWIPS GUI', 'MCP Cam Control'};
uicontrol(dlg, 'Style', 'text', ...
    'Position', [20 200 260 30], ...
    'String', 'Select GUI to launch:', ...
    'HorizontalAlignment', 'left');
    
guiList = uicontrol(dlg, 'Style', 'listbox', ...
    'Position', [20 140 260 60], ...
    'String', guiTypes, ...
    'Value', 1, ...
    'BackgroundColor', 'white');

% Add timer clearing radio button
uicontrol(dlg, 'Style', 'text', ...
    'Position', [20 100 260 20], ...
    'String', 'Timer Management:', ...
    'HorizontalAlignment', 'left');
timerRadio = uicontrol(dlg, 'Style', 'checkbox', ...
    'Position', [20 70 260 30], ...
    'String', 'Clear existing timers before launch', ...
    'Value', 1);

% Add OK and Cancel buttons
uicontrol(dlg, 'Style', 'pushbutton', ...
    'Position', [60 20 80 30], ...
    'String', 'OK', ...
    'Callback', @(~,~) uiresume(dlg));
uicontrol(dlg, 'Style', 'pushbutton', ...
    'Position', [160 20 80 30], ...
    'String', 'Cancel', ...
    'Callback', @(~,~) delete(dlg));

% Wait for user response
uiwait(dlg);

% Check if dialog still exists (not cancelled)
if isvalid(dlg)
    % Get selected values
    guiIdx = get(guiList, 'Value');
    clearTimers = get(timerRadio, 'Value');
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
        % Code to execute if 'OK' is pressed
        switch guiIdx
            case 1
                mybeamlineGUI = beamlineGUI;
            case 2
                mySWIPS_GUI = SWIPS_GUI;
            case 3
                MainScript;
        end
    case 'Cancel'
        % Code to execute if 'Cancel' is pressed
        disp('Gui Powerup Aborted');
    case '' % This case handles when the user closes the dialog without clicking a button
        disp('Gui Powerup Aborted');
end


