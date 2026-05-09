function com = pop_ShowIndMSDyn(AllEEG)
    [~, nogui] = eegplugin_mcstates;
    if nogui, error('Требуется GUI'); end

    global CURRENTSET;
    com = '';

    % Выбор наборов
    selected = ui_select_datasets(AllEEG, CURRENTSET);
    if isempty(selected), return; end

    % Выбор классов
    n_classes = ui_select_nclasses(AllEEG, selected);
    if isempty(n_classes), return; end

    % Определение размера экрана
    figSize = get_screen_size();

    % Создание главного окна
    fig = figure('ToolBar','none','MenuBar','figure','NumberTitle','off',...
                 'Name','Динамика микросостояний','Position',figSize);
    tab_group = uitabgroup(fig, 'Units','normalized','Position',[0 0 1 1]);
    set(fig, 'CloseRequestFcn', {@close_main_fig, tab_group});

    % Создание вкладок
    for s = 1:numel(selected)
        ui_create_tab(tab_group, AllEEG, selected(s), n_classes, figSize);
    end

    com = sprintf('pop_ShowIndMSDyn(%s);', inputname(1));
end

function close_main_fig(src, ~, tab_group)
    % закрывает все окна статистики, затем главное окно
    if ishandle(tab_group)
        tabs = tab_group.Children;
        for i = 1:numel(tabs)
            if ishandle(tabs(i))
                try
                    ud = get(tabs(i), 'UserData');
                    if isfield(ud, 'stats_fig') && ishandle(ud.stats_fig)
                        delete(ud.stats_fig);
                    end
                catch
                end
            end
        end
    end
    delete(src);
end

function figSize = get_screen_size()
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