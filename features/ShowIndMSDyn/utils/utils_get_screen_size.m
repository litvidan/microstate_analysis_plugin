function figSize = utils_get_screen_size()
    toolkit = java.awt.Toolkit.getDefaultToolkit();
    jframe = javax.swing.JFrame;
    insets = toolkit.getScreenInsets(jframe.getGraphicsConfiguration());
    tempFig = figure('ToolBar', 'none', 'MenuBar', 'figure', 'Position', [-1000 -1000 0 0]);
    pause(0.2);
    titleBarHeight = tempFig.OuterPosition(4) - tempFig.InnerPosition(4) + tempFig.OuterPosition(2) - tempFig.InnerPosition(2);
    delete(tempFig);
    monitorPositions = get(0, 'MonitorPositions');
    if size(monitorPositions, 1) > 1
        screenSizes = arrayfun(@(x) monitorPositions(x, 3)*monitorPositions(x,4), 1:size(monitorPositions, 1));
        [~, i] = max(screenSizes);
        screenSize = monitorPositions(i, :);
    else
        screenSize = get(0, 'ScreenSize');
    end
    figSize = screenSize + [insets.left, insets.bottom, -insets.left-insets.right, -titleBarHeight-insets.bottom-insets.top];
end