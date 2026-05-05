function [hPanel, listeners, hRefreshBtn] = createHWConnectionStatusPanel(parentPanel, Hardware, xPosition, yPosition)
%CREATEHWCONNECTIONSTATUSPANEL Create hardware connection status panel
%   Creates a panel with radio buttons showing connection status for each
%   hardware device and a refresh button with built-in callback
%
%   Inputs:
%       parentPanel - Parent UI container for the panel
%       Hardware - Structure containing hardware devices
%       xPosition - X position for the panel
%       yPosition - Y position for the panel
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
    btnSize = 20; % Size for small I/O buttons
    btnGap = 3;   % Gap between buttons
    yBorderBuffer = 30;

    % Create the main panel
    hPanel = uipanel(parentPanel,...
        'Title','Hardware Connectivity',...
        'FontWeight','bold',...
        'FontSize',12,...
        'Units','pixels',...
        'Position',[xPosition, yPosition, sum(colSize)+xgap*numel(colSize), 10]);

    listeners.Panel = hPanel;
    
    % Nested function to create status button for each hardware device
    function x = guiHWConnStatusGrpSet(x)    
        colInd = 1;
        xColStart = xstart;
        
        % Radio button width adjusted to make room for I/O buttons
        radioWidth = colSize(colInd) - (2 * btnSize + 2 * btnGap);
        
        % Create status radio button
        button = uicontrol(hPanel,'Style','radiobutton',...
            'Position',[xColStart, ypos, radioWidth, ysize],...
            'String',sprintf('%s', x.Tag),...
            'FontWeight','bold','Value', x.Connected);
        set(button,'enable','off');
        
        % Create Connect button (I - green)
        uicontrol(hPanel, ...
            'Style','pushbutton',...
            'Position',[xColStart + radioWidth + btnGap, ypos, btnSize, ysize],...
            'String','I',...
            'FontSize',10,...
            'FontWeight','bold',...
            'BackgroundColor',[0.6, 1, 0.6],...
            'Callback',@(~,~) connectCallback(x));
        
        % Create Disconnect button (O - red)
        uicontrol(hPanel, ...
            'Style','pushbutton',...
            'Position',[xColStart + radioWidth + btnSize + 2*btnGap, ypos, btnSize, ysize],...
            'String','O',...
            'FontSize',10,...
            'FontWeight','bold',...
            'BackgroundColor',[1, 0.6, 0.6],...
            'Callback',@(~,~) disconnectCallback(x));
        
        ypos = ypos + ysize + ygap;

        % Define listener to auto update status when Connected property changes
        listeners.(x.Tag) = guiListener(x, 'Connected',...
                                        button,...
                                        @(self) set(self.guiHand, 'Value', self.parent.Connected));
        
        % Callback to connect device
        function connectCallback(hwDevice)
            hwDevice.connectDevice();
        end
        
        % Callback to disconnect device
        function disconnectCallback(hwDevice)
            hwDevice.disconnectDevice();
        end
    end

    % Create status buttons for all hardware devices
    structfun(@guiHWConnStatusGrpSet, Hardware, 'UniformOutput', false);

    % Internal callback function for refresh button
    function HwRefreshCallback(~,~)
        % Refresh hardware connection status
        hwStats = hPanel.Children;
        tags = fieldnames(Hardware);
        for i = 1:numel(hwStats)
            nam = hwStats(i).String;
            disp(nam)
            if any(strcmp(tags, nam))
                Hardware.(nam).connectDevice();
            end
        end
    end

    % Internal callback function for disconnect all button
    function HwDisconnectAllCallback(~,~)
        % Disconnect all hardware devices
        hwStats = hPanel.Children;
        tags = fieldnames(Hardware);
        for i = 1:numel(hwStats)
            nam = hwStats(i).String;
            disp(['Disconnecting: ' nam])
            if any(strcmp(tags, nam))
                Hardware.(nam).disconnectDevice();
            end
        end
    end

    % Create disconnect all button
    colInd = 1;
    xColStart = xstart;
    uicontrol(hPanel, ...
        'Style','pushbutton',...
        'Position',[xColStart, ypos, colSize(colInd), ysize],...
        'String','Disconnect All',...
        'FontSize',12,...
        'FontWeight','bold',...
        'HorizontalAlignment','center',...
        'Callback', @HwDisconnectAllCallback);
    
    ypos = ypos + ysize + ygap;

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
        'Callback', @HwRefreshCallback);
    
    ypos = ypos + ysize + ygap;
    
    % Set final panel height
    hPanel.Position(4) = ypos + yBorderBuffer;

end
