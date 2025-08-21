
% Add all subfolders to path
addPathsSansGit;

% Initialize GUI

button = questdlg('Powering on Beamline GUI. Do you want to proceed?', 'Confirmation', 'OK', 'Cancel', 'OK');

switch button
    case 'OK'
        % Code to execute if 'OK' is pressed
        myGUI = beamlineGUI;
    case 'Cancel'
        % Code to execute if 'Cancel' is pressed
        disp('Gui Powerup Aborted');
    case '' % This case handles when the user closes the dialog without clicking a button
        disp('Gui Powerup Aborted');
end


