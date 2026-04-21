function ui_study_stats_window(study_data, template_name)
    if nargin < 2, template_name = 'Study'; end

    n_classes = study_data.n_classes;
    class_names = arrayfun(@(x) char(64+x), 1:n_classes, 'UniformOutput', false);
    fig = figure('Name', sprintf('Статистика STUDY: %s', template_name), ...
        'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
        'Position', [100 100 950 750]);
    
    setappdata(fig, 'study_data', study_data);
    setappdata(fig, 'current_indices', 1:study_data.n_sets);
    setappdata(fig, 'filter_values', struct());

    % --- Панель фильтров ---
    filter_panel = uipanel(fig, 'Units','normalized',...
        'Position',[0.05, 0.92, 0.9, 0.08], 'Title','Фильтры','FontSize',11);
    
    var_names = fieldnames(study_data.filters);
    n_vars = length(var_names);
    if n_vars > 0
        step = 0.9 / n_vars;
        for iv = 1:n_vars
            var_name = var_names{iv};
            vals = study_data.filters.(var_name);
            % vals уже должны быть cell-массивом строк, но на всякий случай проверим
            if ~iscell(vals)
                vals = cellstr(num2str(vals(:)));
            end
            unique_vals = unique(vals);
            % Гарантируем, что все элементы — строки
            unique_str = cellfun(@(x) char(x), unique_vals, 'UniformOutput', false);
            items = [{'Все'}, unique_str];
            x_pos = 0.05 + (iv-1)*step;
            uicontrol(filter_panel, 'Style','text','String',[var_name ':'],'Units','normalized',...
                'Position',[x_pos, 0.2, 0.12, 0.6], 'HorizontalAlignment','right');
            uicontrol(filter_panel, 'Style','popupmenu','String',items,'Units','normalized',...
                'Position',[x_pos+0.12, 0.2, 0.2, 0.6], 'Tag',['filter_' var_name], ...
                'Callback', {@on_filter_change, fig});
        end
    else
        uicontrol(filter_panel, 'Style','text','String','Нет переменных для фильтрации','Units','normalized',...
            'Position',[0.05,0.2,0.9,0.6], 'HorizontalAlignment','center');
    end
    
    % --- Панель переходов ---
    trans_panel = uipanel(fig, 'Units','normalized',...
        'Position',[0.05, 0.40, 0.9, 0.42], 'Title','Переходы (усреднённые по группе)','FontSize',11);
    uitable(trans_panel, 'Units','normalized','Position',[0.05,0.05,0.9,0.9],...
        'ColumnName',class_names, 'RowName',class_names, ...
        'Data',zeros(n_classes), 'ColumnFormat',repmat({'numeric'},1,n_classes),...
        'ColumnEditable',false(1,n_classes), 'ColumnWidth',repmat({60},1,n_classes),...
        'FontSize',12, 'Tag','table_global');
    
    % --- Панель покрытия ---
    cov_panel = uipanel(fig, 'Units','normalized',...
        'Position',[0.05, 0.30, 0.9, 0.09], 'Title','Покрытие и кол-во наборов','FontSize',11);
    uicontrol(cov_panel, 'Style','text', 'Units','normalized',...
        'Position',[0.02,0.1,0.96,0.8], 'HorizontalAlignment','left', 'FontSize',10, ...
        'String','', 'Tag','text_cov');
    
    % --- Панель метрик по событиям ---
    event_panel = uipanel(fig, 'Units','normalized',...
        'Position',[0.05, 0.05, 0.9, 0.24], 'Title','Метрики по событиям (средние по группе)','FontSize',11);
    create_event_controls(event_panel, study_data, @(varargin) update_display(fig));
    
    % Первичное обновление
    update_display(fig);
    
    % -------------------------------------------------------------------------
    function on_filter_change(~, ~, fig)
        study_data = getappdata(fig, 'study_data');
        var_names = fieldnames(study_data.filters);
        selected_indices = 1:study_data.n_sets;
        for iv = 1:length(var_names)
            var_name = var_names{iv};
            filter_control = findobj(fig, 'Tag', ['filter_' var_name]);
            if isempty(filter_control), continue; end
            items = get(filter_control, 'String');
            val = get(filter_control, 'Value');
            if val > 1
                selected_item = items{val};
                var_vals = study_data.filters.(var_name);
                if ~iscell(var_vals)
                    var_vals = cellstr(num2str(var_vals(:)));
                end
                is_match = strcmp(var_vals, selected_item);
                selected_indices = intersect(selected_indices, find(is_match));
            end
        end
        if isempty(selected_indices)
            selected_indices = 1:study_data.n_sets;
            warndlg('Нет совпадения с данным набором фильтров. Отображение по всем наборам.', 'Фильтрация');
        end
        setappdata(fig, 'current_indices', selected_indices);
        update_display(fig);
    end
    
    function create_event_controls(panel, sdata, callback)
        if isfield(sdata, 'event') && ~isempty(sdata.event)
            raw_types = {sdata.event.type};
            event_types = cellfun(@(x) num2str(x), raw_types, 'UniformOutput', false);
            event_types = unique(event_types);
        else
            event_types = {'Нет событий'};
        end
        
        uicontrol(panel, 'Style','text','String','Тип события:','Units','normalized',...
            'Position',[0.05,0.80,0.20,0.12],'HorizontalAlignment','left');
        uicontrol(panel, 'Style','popupmenu','String',event_types,'Tag','dropdown_event_type',...
            'Units','normalized','Position',[0.27,0.80,0.30,0.12],'Callback',callback);
        
        uicontrol(panel, 'Style','text','String','Окно (мс):','Units','normalized',...
            'Position',[0.60,0.80,0.15,0.12],'HorizontalAlignment','left');
        uicontrol(panel, 'Style','edit','String','-200','Tag','edit_time_from',...
            'Units','normalized','Position',[0.77,0.80,0.08,0.12],'Callback',callback);
        uicontrol(panel, 'Style','edit','String','800','Tag','edit_time_to',...
            'Units','normalized','Position',[0.87,0.80,0.08,0.12],'Callback',callback);
        
        col_names = arrayfun(@(x) sprintf('Класс %c',char(64+x)), 1:sdata.n_classes,'UniformOutput',false);
        row_names = {'Частота (на стимул)','Длительность (мс)','Покрытие (%)'};
        uitable(panel, 'Units','normalized','Position',[0.05,0.05,0.9,0.68],...
            'ColumnName',col_names,'RowName',row_names,'Tag','table_event',...
            'Data',zeros(3,sdata.n_classes),'ColumnEditable',false(1,sdata.n_classes));
    end
    
    function update_display(fig)
        sdata = getappdata(fig, 'study_data');
        idx = getappdata(fig, 'current_indices');
        if isempty(idx), idx = 1:sdata.n_sets; end
        idx = idx(idx >= 1 & idx <= sdata.n_sets);
        if isempty(idx), idx = 1:sdata.n_sets; end
        
        n_sel = length(idx);
        if n_sel == 0
            set(findobj(fig,'Tag','table_global'), 'Data', zeros(sdata.n_classes));
            set(findobj(fig,'Tag','text_cov'), 'String', 'Нет данных для выбранных фильтров');
            set(findobj(fig,'Tag','table_event'), 'Data', zeros(3, sdata.n_classes));
            return;
        end
        
        % Покрытие и переходы
        cov_sum = zeros(1, sdata.n_classes);
        trans_sum = zeros(sdata.n_classes);
        for i = idx
            assign = sdata.MSClass_all{i};
            cov_sum = cov_sum + logic_compute_coverage(assign, sdata.n_classes);
            trans_sum = trans_sum + logic_compute_transitions(assign, sdata.n_classes);
        end
        avg_cov = cov_sum / n_sel;
        avg_trans = trans_sum / n_sel;
        set(findobj(fig,'Tag','table_global'), 'Data', avg_trans);
        
        cov_str = 'Среднее покрытие: ';
        for c = 1:sdata.n_classes
            cov_str = [cov_str, sprintf('%s: %.1f%%  ', char(64+c), avg_cov(c))];
        end
        set(findobj(fig,'Tag','text_cov'), 'String', sprintf('Наборов в выборке: %d\n%s', n_sel, cov_str));
        
        % Метрики по событиям
        dropdown = findobj(fig,'Tag','dropdown_event_type');
        if ~isempty(dropdown)
            ev_list = get(dropdown,'String');
            ev_sel = get(dropdown,'Value');
            if ev_sel <= length(ev_list)
                ev_type = ev_list{ev_sel};
                t_from = str2double(get(findobj(fig,'Tag','edit_time_from'),'String'));
                t_to   = str2double(get(findobj(fig,'Tag','edit_time_to'),'String'));
                if ~isnan(t_from) && ~isnan(t_to)
                    metrics = compute_group_event_metrics(sdata, idx, ev_type, t_from, t_to);
                    set(findobj(fig,'Tag','table_event'), 'Data', metrics);
                end
            end
        end
    end
    
    function metrics = compute_group_event_metrics(sdata, idx, ev_type, t_from, t_to)
        n_classes = sdata.n_classes;
        sum_metrics = zeros(3, n_classes);
        ud_base.Time = sdata.times;
        ud_base.nClasses = n_classes;
        ud_base.event = sdata.event;
        for i = idx
            ud = ud_base;
            ud.Assignment = sdata.MSClass_all{i}(:);
            m = logic_calculate_event_metrics(ud, ev_type, t_from, t_to);
            if ~isempty(m), sum_metrics = sum_metrics + m; end
        end
        metrics = sum_metrics / length(idx);
    end
end