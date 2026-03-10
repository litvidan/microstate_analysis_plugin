function com = pop_ShowIndMSDyn(AllEEG)
    % pop_ShowIndMSDyn - Интерактивный просмотр динамики микросостояний
    % с отображением карт (по шаблону из MSStats), процента покрытия,
    % условных вероятностей переходов и кнопкой для открытия окна статистики.

    [~, nogui] = eegplugin_simplemicrostate;
    if nogui
        error('Эта функция требует графического интерфейса');
    end

    com = '';
    global CURRENTSET MSTATES_TEMPLATES;

    % === 1. Выбор наборов ===
    [selected, available] = select_datasets(AllEEG, CURRENTSET);
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
    % --- ИСПРАВЛЕНИЕ 2: Правильный колбэк для закрытия ---
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

    [res, ~, ~, out] = inputgui(...
        'geometry', [1 1 1 1], 'geomvert', [1 1 1 4], ...
        'uilist', {...
            {'Style', 'text', 'string', 'Выберите наборы для отрисовки', 'FontWeight', 'bold'}, ...
            {'Style', 'text', 'string', 'Используйте Ctrl/Shift для множественного выбора'}, ...
            {'Style', 'text', 'string', 'Если выбрано несколько, для каждого будет создана вкладка.'}, ...
            {'Style', 'listbox', 'string', setnames, 'Min', 0, 'Max', 2, ...
                'Value', default, 'tag', 'SelectedSets'} ...
        }, 'title', 'Отрисовка временной динамики');
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
    [res, ~, ~, out] = inputgui(...
        'geometry', [1 1], 'geomvert', [1 4], ...
        'uilist', {...
            {'Style', 'text', 'string', 'Выберите количество классов'}, ...
            {'Style', 'listbox', 'string', strjoin(choices, '|'), 'Value', 1, 'Tag', 'Classes'} ...
        }, 'title', 'Отрисовка динамики');
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

    ms = EEG.msinfo.MSStats(n_classes);
    time = EEG.times(:);
    n_epochs = EEG.trials;
    n_points = length(time);

	if size(ms.GFP, 1) == 1 && size(ms.GFP, 2) == n_points * n_epochs, gfp = reshape(ms.GFP, n_points, n_epochs);
	elseif size(ms.GFP, 1) == n_points && size(ms.GFP, 2) == n_epochs, gfp = ms.GFP;
	else, error('Непредвиденный размер GFP: [%d, %d]', size(ms.GFP,1), size(ms.GFP,2)); end
	
	if size(ms.MSClass, 1) == n_points * n_epochs && size(ms.MSClass, 2) == 1, assign = reshape(ms.MSClass, n_points, n_epochs);
	elseif size(ms.MSClass, 1) == n_points && size(ms.MSClass, 2) == n_epochs, assign = ms.MSClass;
	else, error('Непредвиденный размер MSClass: [%d, %d]', size(ms.MSClass,1), size(ms.MSClass,2)); end

    template_name = ms.FittingTemplate;
    showMaps = true;
    ChosenTemplate = [];
    global MSTATES_TEMPLATES;

    if strcmp(template_name, '<<собственные>>')
        if isfield(EEG.msinfo, 'MSMaps') && numel(EEG.msinfo.MSMaps) >= n_classes && isfield(EEG.msinfo.MSMaps(n_classes), 'Maps')
            ChosenTemplate = EEG;
        else, showMaps = false; end
    else
        mean_sets = find(arrayfun(@(x) DoesItHaveChildren(AllEEG(x)), 1:numel(AllEEG)));
        for i = mean_sets, if strcmp(AllEEG(i).setname, template_name), ChosenTemplate = AllEEG(i); break; end, end
        if isempty(ChosenTemplate) && ~isempty(MSTATES_TEMPLATES)
            for i = 1:numel(MSTATES_TEMPLATES), if strcmp(MSTATES_TEMPLATES(i).setname, template_name), ChosenTemplate = MSTATES_TEMPLATES(i); break; end, end
        end
        if isempty(ChosenTemplate), showMaps = false; end
    end

    if showMaps
        map_colors = ChosenTemplate.msinfo.MSMaps(n_classes).ColorMap;
        colors = getColors(n_classes);
        unassigned = all(map_colors == 0.75, 2);
        if any(unassigned)
            unassigned_indices = find(unassigned);
            valid_indices_to_update = unassigned_indices(unassigned_indices <= size(colors, 1));
            if ~isempty(valid_indices_to_update), map_colors(valid_indices_to_update, :) = colors(valid_indices_to_update, :); end
        end
        cmap_full = [0.75 0.75 0.75; map_colors];
    else
        colors = getColors(n_classes);
        cmap_full = [0.75 0.75 0.75; colors];
    end

    fit_data = cell(1, n_epochs);
    for ep = 1:n_epochs
        fit = nan(n_classes+1, n_points);
        assign_ep = assign(:, ep);
        gfp_ep = gfp(:, ep);
        for c = 1:n_classes
            mask = assign_ep == c;
            mask_ext = [false; mask(1:end-1)] | mask;
            fit(c+1, mask_ext) = gfp_ep(mask_ext);
        end
        fit_data{ep} = fit;
    end

    ud = struct();
    ud.nClasses = n_classes;
    ud.gfp = gfp;
    ud.Assignment = assign;
    ud.Time = time;
    ud.nSegments = n_epochs;
    ud.Segment = 1;
    ud.Start = 0;
    ud.XRange = min(10000, time(end) - time(1));
    ud.MaxY = 25;
    ud.event = EEG.event;
    ud.cmap = cmap_full;
    ud.global_cov = compute_global_coverage(assign, n_classes);
    ud.global_transitions = compute_global_transitions(assign, n_classes);
    ud.fit_data = fit_data;
    ud.stats_fig = [];
    ud.event_handles = [];

    if showMaps
        ud.AllMaps = ChosenTemplate.msinfo.MSMaps;
        ud.ClustPar = ChosenTemplate.msinfo.ClustPar;
        ud.chanlocs = ChosenTemplate.chanlocs;
        ud.Visible = true; ud.Edit = false; ud.Scroll = false;
        minGridWidth = 60;
        if figSize(3)*0.98/n_classes >= minGridWidth
            map_panel_width = 0.88;
            ud.MapPanel = uipanel(tab, 'Units', 'normalized', 'Position', [0.01 0.82 map_panel_width 0.15], 'BorderType', 'none');
            ud.ax = axes(tab, 'Position', [0.05 0.25 map_panel_width-0.04 0.55]);
            minusY = 0.35; plusY  = 0.52;
            set(tab, 'UserData', ud);
            PlotMSMaps(tab, n_classes);
        else
            ud.ax = axes(tab, 'Position', [0.05 0.22 0.88 0.70]);
            uicontrol('Style', 'pushbutton', 'String', 'Карты', 'Units', 'normalized', 'Position', [0.94 0.64 0.05 0.15], 'Callback', {@show_maps_button, ChosenTemplate, n_classes});
            minusY = 0.40; plusY  = 0.57;
        end
    else
        ud.ax = axes(tab, 'Position', [0.05 0.22 0.88 0.70]);
        minusY = 0.40; plusY  = 0.57;
    end

    uicontrol(tab, 'Style', 'pushbutton', 'String', '|<<', 'Units', 'normalized', 'Position', [0.05 0.05 0.08 0.05], 'Callback', {@goto_epoch, tab, 'prev'});
    ud.epochBox = uicontrol(tab, 'Style', 'edit', 'String', '1', 'Units', 'normalized', 'Position', [0.14 0.05 0.08 0.05], 'Callback', {@goto_epoch, tab, 'edit'});
    uicontrol(tab, 'Style', 'pushbutton', 'String', '>>|', 'Units', 'normalized', 'Position', [0.23 0.05 0.08 0.05], 'Callback', {@goto_epoch, tab, 'next'});
    uicontrol(tab, 'Style', 'pushbutton', 'String', 'Гор. зум +', 'Units', 'normalized', 'Position', [0.35 0.05 0.12 0.05], 'Callback', {@zoom_x, tab, -1000});
    uicontrol(tab, 'Style', 'pushbutton', 'String', 'Гор. зум -', 'Units', 'normalized', 'Position', [0.48 0.05 0.12 0.05], 'Callback', {@zoom_x, tab, 1000});
    uicontrol(tab, 'Style', 'pushbutton', 'String', 'Статистика', 'Units', 'normalized', 'Position', [0.65 0.05 0.12 0.05], 'Callback', {@show_stats, tab});
    uicontrol(tab, 'Style', 'pushbutton', 'String', '-', 'Units', 'normalized', 'Position', [0.94 minusY 0.05 0.15], 'Callback', {@zoom_y, tab, 1/0.75});
    uicontrol(tab, 'Style', 'pushbutton', 'String', '+', 'Units', 'normalized', 'Position', [0.94 plusY  0.05 0.15], 'Callback', {@zoom_y, tab, 0.75});
    ud.slider = uicontrol(tab, 'Style', 'slider', 'Min', time(1), 'Max', time(end), 'Value', time(1), 'Units', 'normalized', 'Position', [0.05 0.02 0.88 0.03], 'BackgroundColor', [0.6 0.6 0.6], 'Callback', {@slider_move, tab});

    set(tab, 'UserData', ud);
    update_display(tab);

    function goto_epoch(~, ~, tab, mode)
        ud = get(tab, 'UserData');
        if strcmp(mode, 'edit'), val = str2double(get(ud.epochBox, 'String')); if isnan(val) || val < 1 || val > ud.nSegments, set(ud.epochBox, 'String', num2str(ud.Segment)); return; end, new_ep = round(val);
        elseif strcmp(mode, 'prev'), new_ep = ud.Segment - 1;
        elseif strcmp(mode, 'next'), new_ep = ud.Segment + 1;
        else, return; end
        if new_ep >= 1 && new_ep <= ud.nSegments, ud.Segment = new_ep; set(tab, 'UserData', ud); update_display(tab);
        else, set(ud.epochBox, 'String', num2str(ud.Segment)); end
    end
    function zoom_x(~, ~, t, delta), ud = get(t, 'UserData'); ud.XRange = max(100, min(ud.XRange + delta, ud.Time(end) - ud.Time(1))); set(t, 'UserData', ud); update_display(t); end
    function zoom_y(~, ~, t, factor), ud = get(t, 'UserData'); ud.MaxY = ud.MaxY * factor; set(t, 'UserData', ud); update_display(t); end
    function slider_move(~, ~, t), ud = get(t, 'UserData'); ud.Start = get(ud.slider, 'Value'); set(t, 'UserData', ud); update_display(t); end
    function show_maps_button(~, ~, template, nC), pop_ShowIndMSMaps(template, 1, 'Classes', nC); end
    function show_stats(~, ~, tab)
        ud = get(tab, 'UserData');
        if isfield(ud, 'stats_fig') & ishandle(ud.stats_fig), figure(ud.stats_fig); return; end
        fig = figure('Name', sprintf('Статистика: %s', get(tab, 'Title')), 'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', 'Position', [200 200 500 600], 'CloseRequestFcn', @(src,~) close_stats(src, tab));
        ud.stats_fig = fig;
        set(tab, 'UserData', ud);
        
        % --- ИСПРАВЛЕНИЕ 1: Создаем таблицы внутри панелей ---
        h_panel_epoch = uipanel(fig, 'Units', 'normalized', 'Position', [0.05 0.55 0.9 0.4], 'Title', 'Переходы (текущая эпоха)', 'FontSize', 11);
        uitable(h_panel_epoch, 'Units', 'normalized', 'Position', [0.05 0.1 0.9 0.8], 'ColumnName', arrayfun(@(x) char(64+x), 1:n_classes, 'UniformOutput', false), 'RowName', arrayfun(@(x) char(64+x), 1:n_classes, 'UniformOutput', false), 'Data', zeros(n_classes), 'ColumnFormat', repmat({'numeric'}, 1, n_classes), 'ColumnEditable', false(1, n_classes), 'ColumnWidth', repmat({50}, 1, n_classes), 'FontSize', 12, 'Tag', 'table_epoch');
        
        h_panel_global = uipanel(fig, 'Units', 'normalized', 'Position', [0.05 0.1 0.9 0.4], 'Title', 'Переходы (глобально)', 'FontSize', 11);
        uitable(h_panel_global, 'Units', 'normalized', 'Position', [0.05 0.1 0.9 0.8], 'ColumnName', arrayfun(@(x) char(64+x), 1:n_classes, 'UniformOutput', false), 'RowName', arrayfun(@(x) char(64+x), 1:n_classes, 'UniformOutput', false), 'Data', ud.global_transitions, 'ColumnFormat', repmat({'numeric'}, 1, n_classes), 'ColumnEditable', false(1, n_classes), 'ColumnWidth', repmat({60}, 1, n_classes), 'FontSize', 12, 'Tag', 'table_global');
        
        uicontrol(fig, 'Style', 'text', 'Units', 'normalized', 'Position', [0.05 0.03 0.9 0.1], 'HorizontalAlignment', 'left', 'FontSize', 10, 'String', '', 'Tag', 'text_cov');
        
        update_stats_window(tab);
    end
    function close_stats(src, tab)
    	if ishandle(tab), ud = get(tab, 'UserData'); if isfield(ud, 'stats_fig') && ishandle(ud.stats_fig) && ud.stats_fig == src, ud.stats_fig = []; set(tab, 'UserData', ud); end, end
    	delete(src);
    end
end

% -------------------------------------------------------------------------
function global_cov = compute_global_coverage(assign, n_classes)
    assign_flat = assign(:); valid = assign_flat > 0; total_valid = sum(valid);
    if total_valid == 0, global_cov = zeros(1, n_classes); return; end
    global_cov = zeros(1, n_classes);
    for c = 1:n_classes, global_cov(c) = sum(assign_flat == c) / total_valid * 100; end
end

% -------------------------------------------------------------------------
function trans_matrix = compute_epoch_transitions(assign_epoch, n_classes)
    trans_matrix = zeros(n_classes); changes = find(diff(assign_epoch) ~= 0);
    for i = 1:numel(changes)
        from = assign_epoch(changes(i)); to = assign_epoch(changes(i)+1);
        if from > 0 && to > 0 && from ~= to, trans_matrix(from, to) = trans_matrix(from, to) + 1; end
    end
    for from = 1:n_classes
        total_from = sum(trans_matrix(from, :));
        if total_from > 0, trans_matrix(from, :) = trans_matrix(from, :) / total_from * 100; end
    end
end

% -------------------------------------------------------------------------
function global_trans_matrix = compute_global_transitions(assign, n_classes)
    global_trans_matrix = zeros(n_classes); n_epochs = size(assign, 2);
    for ep = 1:n_epochs
        assign_epoch = assign(:, ep); changes = find(diff(assign_epoch) ~= 0);
        for i = 1:numel(changes)
            from = assign_epoch(changes(i)); to = assign_epoch(changes(i)+1);
            if from > 0 && to > 0 && from ~= to, global_trans_matrix(from, to) = global_trans_matrix(from, to) + 1; end
        end
    end
    for from = 1:n_classes
        total_from = sum(global_trans_matrix(from, :));
        if total_from > 0, global_trans_matrix(from, :) = global_trans_matrix(from, :) / total_from * 100; end
    end
end

% -------------------------------------------------------------------------
function update_display(tab)
    data = get(tab, 'UserData');
    
    cla(data.ax); 
    hold(data.ax, 'on'); 

    window_start = data.Start; window_end = data.Start + data.XRange;
    visible_idx = data.Time >= window_start & data.Time <= window_end;
    visible_time = data.Time(visible_idx);
    fit_epoch = data.fit_data{data.Segment};
    fit_visible = fit_epoch(:, visible_idx);
    for k = 1:data.nClasses+1
        area(data.ax, visible_time, fit_visible(k,:), 'LineStyle', 'none', 'FaceColor', data.cmap(k,:), 'ShowBaseLine', 'off');
    end
    line(data.ax, [data.Time(1) data.Time(end)], [0 0], 'Color', 'k', 'LineWidth', 0.5);

    n_points_total = numel(data.Time); time_step = data.Time(2) - data.Time(1);
    for ev_idx = 1:numel(data.event)
        if ~isfield(data.event(ev_idx), 'epoch'), epoch = 1; else, epoch = data.event(ev_idx).epoch; end
        if epoch ~= data.Segment, continue; end
        event_time = (data.event(ev_idx).latency - (data.Segment-1) * n_points_total) * time_step;
        if event_time < window_start || event_time > window_end, continue; end
        
        plot(data.ax, [event_time,event_time],[0,data.MaxY],'-k');
        if isnumeric(data.event(ev_idx).type), txt = sprintf('%1.0i', data.event(ev_idx).type); else, txt = data.event(ev_idx).type; end
		text(data.ax, event_time,data.MaxY,txt, 'Interpreter','none','VerticalAlignment','top','HorizontalAlignment','right','Rotation',90);
    end
    
    hold(data.ax, 'off'); 

    axis(data.ax, [window_start-0.5, window_end+0.5, 0, data.MaxY]);
    xticks = get(data.ax, 'XTick');
    set(data.ax, 'XTickLabel', arrayfun(@(x) format_time(x/1000), xticks, 'UniformOutput', false), 'FontSize', 9);
    xlabel(data.ax, 'Время', 'FontSize', 10); ylabel(data.ax, 'GFP', 'FontSize', 10);
    title(data.ax, sprintf('Эпоха %d из %d (%d классов)', data.Segment, data.nSegments, data.nClasses));
    
    set(data.slider, 'Value', data.Start); set(data.epochBox, 'String', num2str(data.Segment));

    if isfield(data, 'stats_fig') & ishandle(data.stats_fig), update_stats_window(tab); end
    
    drawnow limitrate;
end

% -------------------------------------------------------------------------
function update_stats_window(tab)
    data = get(tab, 'UserData');
    if ~isfield(data, 'stats_fig') || ~ishandle(data.stats_fig), return; end
    
    fig = data.stats_fig;
    table_epoch = findobj(fig, 'Tag', 'table_epoch');
    table_global = findobj(fig, 'Tag', 'table_global');
    text_cov = findobj(fig, 'Tag', 'text_cov');

    if isempty(table_epoch) || isempty(table_global) || isempty(text_cov), return; end

    assign_epoch = data.Assignment(:, data.Segment);
    epoch_trans = compute_epoch_transitions(assign_epoch, data.nClasses);
	set(table_epoch, 'Data', arrayfun(@(x) sprintf('%.1f', x), epoch_trans, 'UniformOutput', false));
	set(table_global, 'Data', arrayfun(@(x) sprintf('%.1f', x), data.global_transitions, 'UniformOutput', false));
    
    fit_epoch_full = data.fit_data{data.Segment};
    epoch_coverage = zeros(1, data.nClasses); total_valid_epoch = 0;
    for class = 1:data.nClasses
        active = ~isnan(fit_epoch_full(class+1, :));
        epoch_coverage(class) = sum(active);
        total_valid_epoch = total_valid_epoch + sum(active);
    end
    if total_valid_epoch > 0, epoch_coverage = epoch_coverage / total_valid_epoch * 100; end
    
    cov_str = 'Покрытие (текущая эпоха): ';
    for class = 1:data.nClasses, cov_str = [cov_str, sprintf('%s: %.1f%%  ', char(64 + class), epoch_coverage(class))]; end
    cov_str = [cov_str, sprintf('\nПокрытие (глобально): ')];
    for class = 1:data.nClasses, cov_str = [cov_str, sprintf('%s: %.1f%%  ', char(64 + class), data.global_cov(class))]; end
    set(text_cov, 'String', cov_str);
end

% --- ИСПРАВЛЕНИЕ 2: Правильная сигнатура функции ---
function close_main_fig(src, event, tab_group)
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

% -------------------------------------------------------------------------
function str = format_time(t_sec)
    if t_sec >= 3600, str = datestr(t_sec/86400, 'HH:MM:SS');
    elseif t_sec >= 60, str = datestr(t_sec/86400, 'MM:SS');
    else, str = sprintf('%.3f', t_sec); end
end

% ===== Вспомогательные функции =====
function hasStats = hasStats(in), hasStats = isfield(in,'msinfo') && isfield(in.msinfo, 'MSStats'); end
function answer = DoesItHaveChildren(in), answer = isfield(in,'msinfo') && isfield(in.msinfo,'children'); end
function hasDyn = isDynamicsSet(in), hasDyn = isfield(in,'msinfo') && isfield(in.msinfo, 'FitPar') && isfield(in.msinfo.FitPar, 'Rectify'); end
