function create_dyn_tab_ui(tab, ud, figSize)
    % create_dyn_tab_ui - Создает UI элементы на вкладке динамики

    if ud.showMaps
        minGridWidth = 60;
        if figSize(3)*0.98/ud.nClasses >= minGridWidth
            map_panel_width = 0.88;
            ud.MapPanel = uipanel(tab, 'Units', 'normalized', 'Position', [0.01 0.82 map_panel_width 0.15], 'BorderType', 'none');
            ud.ax = axes(tab, 'Position', [0.05 0.25 map_panel_width-0.04 0.55]);
            minusY = 0.35; plusY  = 0.52;
            set(tab, 'UserData', ud);
            PlotMSMaps(tab, ud.nClasses);
        else
            ud.ax = axes(tab, 'Position', [0.05 0.22 0.88 0.70]);
            uicontrol('Style', 'pushbutton', 'String', 'Карты', 'Units', 'normalized', 'Position', [0.94 0.64 0.05 0.15], 'Callback', {@show_maps_button, ud.ChosenTemplate, ud.nClasses});
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
    ud.slider = uicontrol(tab, 'Style', 'slider', 'Min', ud.Time(1), 'Max', ud.Time(end), 'Value', ud.Time(1), 'Units', 'normalized', 'Position', [0.05 0.02 0.88 0.03], 'BackgroundColor', [0.6 0.6 0.6], 'Callback', {@slider_move, tab});

    set(tab, 'UserData', ud);
    update_display(tab);
end

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
    
    h_panel_epoch = uipanel(fig, 'Units', 'normalized', 'Position', [0.05 0.55 0.9 0.4], 'Title', 'Переходы (текущая эпоха)', 'FontSize', 11);
    uitable(h_panel_epoch, 'Units', 'normalized', 'Position', [0.05 0.1 0.9 0.8], 'ColumnName', arrayfun(@(x) char(64+x), 1:ud.nClasses, 'UniformOutput', false), 'RowName', arrayfun(@(x) char(64+x), 1:ud.nClasses, 'UniformOutput', false), 'Data', zeros(ud.nClasses), 'ColumnFormat', repmat({'numeric'}, 1, ud.nClasses), 'ColumnEditable', false(1, ud.nClasses), 'ColumnWidth', repmat({50}, 1, ud.nClasses), 'FontSize', 12, 'Tag', 'table_epoch');
    
    h_panel_global = uipanel(fig, 'Units', 'normalized', 'Position', [0.05 0.1 0.9 0.4], 'Title', 'Переходы (глобально)', 'FontSize', 11);
    uitable(h_panel_global, 'Units', 'normalized', 'Position', [0.05 0.1 0.9 0.8], 'ColumnName', arrayfun(@(x) char(64+x), 1:ud.nClasses, 'UniformOutput', false), 'RowName', arrayfun(@(x) char(64+x), 1:ud.nClasses, 'UniformOutput', false), 'Data', ud.global_transitions, 'ColumnFormat', repmat({'numeric'}, 1, ud.nClasses), 'ColumnEditable', false(1, ud.nClasses), 'ColumnWidth', repmat({60}, 1, ud.nClasses), 'FontSize', 12, 'Tag', 'table_global');
    
    uicontrol(fig, 'Style', 'text', 'Units', 'normalized', 'Position', [0.05 0.03 0.9 0.1], 'HorizontalAlignment', 'left', 'FontSize', 10, 'String', '', 'Tag', 'text_cov');
    
    update_stats_window(tab);
end
function close_stats(src, tab)
    if ishandle(tab), ud = get(tab, 'UserData'); if isfield(ud, 'stats_fig') && ishandle(ud.stats_fig) && ud.stats_fig == src, ud.stats_fig = []; set(tab, 'UserData', ud); end, end
    delete(src);
end

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

function epoch_trans_matrix = compute_epoch_transitions(assign_epoch, n_classes)
    epoch_trans_matrix = zeros(n_classes); changes = find(diff(assign_epoch) ~= 0);
    for i = 1:numel(changes)
        from = assign_epoch(changes(i)); to = assign_epoch(changes(i)+1);
        if from > 0 && to > 0 && from ~= to, epoch_trans_matrix(from, to) = epoch_trans_matrix(from, to) + 1; end
    end
    for from = 1:n_classes
        total_from = sum(epoch_trans_matrix(from, :));
        if total_from > 0, epoch_trans_matrix(from, :) = epoch_trans_matrix(from, :) / total_from * 100; end
    end
end

function str = format_time(t_sec)
    if t_sec >= 3600, str = datestr(t_sec/86400, 'HH:MM:SS');
    elseif t_sec >= 60, str = datestr(t_sec/86400, 'MM:SS');
    else, str = sprintf('%.3f', t_sec); end
end
