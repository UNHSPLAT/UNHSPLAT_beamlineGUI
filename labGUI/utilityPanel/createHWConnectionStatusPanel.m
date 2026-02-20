function [hPanel, listeners, hRefreshBtn] = createHWConnectionStatusPanel(parentPanel, Hardware, xPosition, yPosition, callback)
%CREATEHWCONNECTIONSTATUSPANEL Create hardware connection status panel
%   Creates a panel with radio buttons showing connection status for each
%   hardware device and a refresh button
%
%   Inputs:
%       parentPanel - Parent UI container for the panel
%       Hardware - Structure containing hardware devices
%       xPosition - X position for the panel
%       yPosition - Y position for the panel
%       callback - Callback function for the refresh button
%
%   Outputs:
%       hPanel - Handle to the created panel
%       listeners - Structure containing listeners for each hardware device
%       hRefreshBtn - Handle to the refresh button

    % Set positions for components
    ysize = 22;
    ygap = 6;
    ystart = 20; % ypanelBuffer
    ypos = ystart;
    xgap = 15;
    xstart = 10;
    colSize = [180];
    yBorderBuffer = 30;

    % Create the main panel
    hPanel = uipanel(parentPanel,...
        'Title','Hardware Conectivity',...
        'FontWeight','bold',...
        'FontSize',12,...
        'Units','pixels',...
        'Position',[xPosition, yPosition, sum(colSize)+xgap*numel(colSize), 10]);

    listeners.Panel = hPanel;
    
    % Nested function to create status button for each hardware device
    function x = guiHWConnStatusGrpSet(x)    
        colInd = 1;
        xColStart = xstart;
        button = uicontrol(hPanel,'Style','radiobutton',...
            'Position',[xColStart, ypos, colSize(colInd), ysize],...
            'String',sprintf('%s', x.Tag),...
            'FontWeight','bold','Value', x.Connected);
        set(button,'enable','off');
        ypos = ypos + ysize + ygap;

        % Define listener to auto update status when Connected property changes
        listeners.(x.Tag) = guiListener(x, 'Connected',...
                                        button,...
                                        @(self) set(self.guiHand, 'Value', self.parent.Connected));
    end

    % Create status buttons for all hardware devices
    structfun(@guiHWConnStatusGrpSet, Hardware, 'UniformOutput', false);

    % Create refresh button
    colInd = 1;
    xColStart = xstart;
    hRefreshBtn = uicontrol(hPanel, ...
        'Style','pushbutton',...
        'Position',[xColStart, ypos, colSize(colInd), ysize],...
        'String','Refresh',...
        'FontSize',12,...
        'FontWeight','bold',...
        'HorizontalAlignment','center',...
        'Callback', callback);
    
    ypos = ypos + ysize + ygap;
    
    % Set final panel height
    hPanel.Position(4) = ypos + yBorderBuffer;

end
