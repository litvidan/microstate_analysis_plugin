function com = pop_ShowIndMSDyn(AllEEG)
    % pop_ShowIndMSDyn - Интерактивный просмотр динамики микросостояний
    % с отображением карт (по шаблону из MSStats), процента покрытия,
    % условных вероятностей переходов и кнопкой для открытия окна статистики.

    [~, nogui] = eegplugin_simplemicrostate;
    if nogui
        error('Эта функция требует графического интерфейса');
    end

    com = '';
    global CURRENTSET;

    % === 1. Выбор наборов ===
    [selected, ~] = select_datasets(AllEEG, CURRENTSET);
    if isempty(selected); return; end

    % === 2. Выбор числа классов ===
    n_classes = select_nclasses(AllEEG, selected);
    if isempty(n_classes); return; end

    % === 3. Определение размера экрана ===
    figSize = get_screen_size();

    % === 4. Создание фигуры и вкладок ===
	fig = figure('ToolBar', 'none', 'MenuBar', 'figure', 'NumberTitle', 'off', ...
    	'Name', 'Динамика микросостояний', 'Position', figSize);
	tab_group = uitabgroup(fig, 'Units', 'normalized', 'Position', [0 0 1 1]);
	set(fig, 'CloseRequestFcn', {@close_main_fig, tab_group});

    % === 5. Создание вкладок для каждого выбранного набора ===
    for s = 1:numel(selected)
        create_tab(tab_group, AllEEG, selected(s), n_classes, figSize);
    end

    com = sprintf('pop_ShowIndMSDyn(%s);', inputname(1));
end

% -------------------------------------------------------------------------
function [selected, available] = select_datasets(AllEEG, CURRENTSET)
    has_stats = arrayfun(@(x) hasStats(AllEEG(x)), 1:numel(AllEEG));
    has_dyn = arrayfun(@(x) isDynamicsSet(AllEEG(x)), 1:numel(AllEEG));
    available = find(has_stats & ~has_dyn);

    if isempty(available)
        errordlg2('Нет наборов с временными параметрами.', 'Ошибка');
        selected = [];
        return;
    end

    setnames = {AllEEG(available).setname};
    default = find(available == CURRENTSET, 1, 'first');
    if isempty(default); default = 1; end

    [geometry, geomvert, uilist, title] = get_dataset_selection_dyn_ui(setnames, default);
    [res, ~, ~, out] = inputgui('geometry', geometry, 'geomvert', geomvert, 'uilist', uilist, 'title', title);
    if isempty(res)
        selected = [];
        return;
    end
    selected = available(out.SelectedSets);
end

% -------------------------------------------------------------------------
function n_classes = select_nclasses(AllEEG, selected)
    class_ranges = arrayfun(@(x) AllEEG(x).msinfo.FitPar.Classes, selected, 'UniformOutput', false);
    common = class_ranges{1};
    for i = 2:numel(selected)
        common = intersect(common, class_ranges{i});
    end
    if isempty(common)
        errordlg2('Нет общего числа классов среди выбранных наборов.', 'Ошибка');
        n_classes = [];
        return;
    end
    choices = arrayfun(@(x) sprintf('%i классов', x), common, 'UniformOutput', false);
    [geometry, geomvert, uilist, title] = get_nclasses_selection_ui(choices);
    [res, ~, ~, out] = inputgui('geometry', geometry, 'geomvert', geomvert, 'uilist', uilist, 'title', title);
    if isempty(res)
        n_classes = [];
        return;
    end
    n_classes = common(out.Classes);
end

% -------------------------------------------------------------------------
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

% -------------------------------------------------------------------------
function create_tab(tab_group, AllEEG, set_idx, n_classes, figSize)
    EEG = AllEEG(set_idx);
    tab = uitab(tab_group, 'Title', sprintf('%s (%i кл.)', EEG.setname, n_classes));
    
    ud = ShowIndMSDyn_logic(EEG, n_classes, AllEEG);
    create_dyn_tab_ui(tab, ud, figSize);
end

% -------------------------------------------------------------------------
function close_main_fig(src, ~, tab_group)
    if ishandle(tab_group)
        tabs = tab_group.Children;
        for i = 1:numel(tabs)
            if ishandle(tabs(i))
                try, ud = get(tabs(i), 'UserData'); if isfield(ud, 'stats_fig') && ishandle(ud.stats_fig), delete(ud.stats_fig); end, catch, end
            end
        end
    end
    delete(src);
end

% ===== Вспомогательные функции =====
function hasStats = hasStats(in), hasStats = isfield(in,'msinfo') && isfield(in.msinfo, 'MSStats'); end
function hasDyn = isDynamicsSet(in), hasDyn = isfield(in,'msinfo') && isfield(in.msinfo, 'FitPar') && isfield(in.msinfo.FitPar, 'Rectify'); end
