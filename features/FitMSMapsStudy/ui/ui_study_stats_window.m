function ui_study_stats_window(study_data, template_name)
    % Отображает усреднённую статистику по всему STUDY.
    % study_data должен содержать поля:
    %   .MSClass_all    - cell array матриц [n_epochs x n_points] меток классов
    %   .times          - вектор времени (мс)
    %   .n_classes      - количество классов
    %   .event          - структура событий (из первого набора, опционально)
    %   .setnames       - имена наборов (для справки)
    %   .n_sets         - количество субъектов
    %   .n_epochs       - количество эпох (должно быть одинаково)
    %   .n_points       - количество точек на эпоху
    %   .srate          - частота дискретизации
    % template_name     - строка для заголовка (например, имя использованного шаблона)

    if nargin < 2
        template_name = 'Study';
    end

    n_classes = study_data.n_classes;
    class_names = arrayfun(@(x) char(64+x), 1:n_classes, 'UniformOutput', false);
    n_sets = study_data.n_sets;

    % --- Вычисляем усреднённые покрытие и матрицу переходов (если ещё нет) ---
    if ~isfield(study_data, 'global_coverage') || ~isfield(study_data, 'global_transitions')
        cov_sum = zeros(1, n_classes);
        trans_sum = zeros(n_classes);
        for s = 1:n_sets
            assign = study_data.MSClass_all{s};
            cov_sum = cov_sum + logic_compute_coverage(assign, n_classes);
            trans_sum = trans_sum + logic_compute_transitions(assign, n_classes);
        end
        study_data.global_coverage = cov_sum / n_sets;
        study_data.global_transitions = trans_sum / n_sets;
    end

    % --- Создаём фигуру ---
    fig = figure('Name', sprintf('Статистика STUDY: %s', template_name), ...
        'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
        'Position', [200 200 800 650], ...
        'CloseRequestFcn', @close_fig);

    % === 1. Панель переходов (усреднённая) ===
    panel_height = 0.48;
    panel_y = 0.50;
    panel_width = 0.90;
    left_margin = 0.05;
    
    h_panel_global = uipanel(fig, 'Units','normalized',...
        'Position',[left_margin, panel_y, panel_width, panel_height],...
        'Title','Переходы (усреднённые по группе)','FontSize',11);
    uitable(h_panel_global, 'Units','normalized','Position',[0.05 0.05 0.9 0.9],...
        'ColumnName',class_names, 'RowName',class_names, ...
        'Data',study_data.global_transitions, 'ColumnFormat',repmat({'numeric'},1,n_classes),...
        'ColumnEditable',false(1,n_classes), 'ColumnWidth',repmat({60},1,n_classes),...
        'FontSize',12, 'Tag','table_global');

    % === 2. Панель покрытия ===
    cov_panel_height = 0.12;
    cov_panel_y = panel_y - cov_panel_height - 0.02;
    h_panel_cov = uipanel(fig, 'Units','normalized',...
        'Position',[left_margin, cov_panel_y, panel_width, cov_panel_height],...
        'Title','Покрытие классов (%, среднее по группе)','FontSize',11);
    
    cov_str = sprintf('Среднее: ');
    for c = 1:n_classes
        cov_str = [cov_str, sprintf('%s: %.1f%%  ', class_names{c}, study_data.global_coverage(c))];
    end
    uicontrol(h_panel_cov, 'Style','text','Units','normalized',...
        'Position',[0.02 0.1 0.96 0.8],...
        'HorizontalAlignment','left','FontSize',10,'String',cov_str,'Tag','text_cov');

    % === 3. Панель метрик по событиям ===
    event_panel_height = 0.28;
    event_panel_y = 0.05;
    h_panel_event = uipanel(fig, 'Units','normalized',...
        'Position',[left_margin, event_panel_y, panel_width, event_panel_height],...
        'Title','Метрики по событиям (средние по группе)','FontSize',11);
    
    % Выпадающий список типов событий
    if isfield(study_data, 'event') && ~isempty(study_data.event)
        event_types = unique({study_data.event.type});
        is_numeric = cellfun(@isnumeric, event_types);
        event_types(is_numeric) = cellfun(@num2str, event_types(is_numeric), 'UniformOutput', false);
    else
        event_types = {'Нет событий'};
    end
    uicontrol(h_panel_event, 'Style','text','String','Тип события:','Units','normalized',...
        'Position',[0.05 0.80 0.20 0.12],'HorizontalAlignment','left');
    uicontrol(h_panel_event, 'Style','popupmenu', 'String',event_types, 'Tag','dropdown_event_type',...
        'Units','normalized','Position',[0.27 0.80 0.30 0.12], ...
        'Callback', {@update_stats, fig, study_data});
    
    % Поля ввода окна
    uicontrol(h_panel_event, 'Style','text','String','Окно (мс):','Units','normalized',...
        'Position',[0.60 0.80 0.15 0.12],'HorizontalAlignment','left');
    uicontrol(h_panel_event, 'Style','edit', 'String','-200', 'Tag','edit_time_from',...
        'Units','normalized','Position',[0.77 0.80 0.08 0.12], ...
        'Callback', {@update_stats, fig, study_data});
    uicontrol(h_panel_event, 'Style','edit', 'String','800', 'Tag','edit_time_to',...
        'Units','normalized','Position',[0.87 0.80 0.08 0.12], ...
        'Callback', {@update_stats, fig, study_data});
    
    % Таблица метрик
    col_names = arrayfun(@(x) sprintf('Класс %c', char(64+x)), 1:n_classes, 'UniformOutput', false);
    row_names = {'Частота (на стимул)', 'Длительность (мс)', 'Покрытие (%)'};
    uitable(h_panel_event, 'Units','normalized','Position',[0.05 0.05 0.9 0.68],...
        'ColumnName',col_names, 'RowName',row_names, 'Tag','table_event',...
        'Data',zeros(3, n_classes), 'ColumnFormat',repmat({'numeric'},1,n_classes),...
        'ColumnEditable',false(1,n_classes), 'ColumnWidth',repmat({80},1,n_classes));
    
    % Первичное обновление
    update_stats([], [], fig, study_data);
    
    % -------------------------------------------------------------------------
    function update_stats(~, ~, fig, sdata)
        dropdown = findobj(fig, 'Tag', 'dropdown_event_type');
        edit_from = findobj(fig, 'Tag', 'edit_time_from');
        edit_to = findobj(fig, 'Tag', 'edit_time_to');
        table_event = findobj(fig, 'Tag', 'table_event');
        if isempty(dropdown) || isempty(table_event)
            return;
        end
        
        event_type_list = get(dropdown, 'String');
        selected_idx = get(dropdown, 'Value');
        event_type = event_type_list{selected_idx};
        time_from = str2double(get(edit_from, 'String'));
        time_to = str2double(get(edit_to, 'String'));
        
        % Вычисляем групповые метрики
        metrics = compute_group_event_metrics(sdata, event_type, time_from, time_to);
        formatted_metrics = arrayfun(@(x) sprintf('%.2f', x), metrics, 'UniformOutput', false);
        set(table_event, 'Data', formatted_metrics);
        
        % debug print
        fprintf('Metrics for %s: freq = %s, dur = %s, cov = %s\n', ...
            event_type, mat2str(metrics(1,:),3), mat2str(metrics(2,:),3), mat2str(metrics(3,:),3));
    end
    
    function metrics = compute_group_event_metrics(sdata, event_type, time_from, time_to)
        % Вызывает logic_calculate_event_metrics для каждого субъекта и усредняет
        n_sets = sdata.n_sets;
        n_classes = sdata.n_classes;
        metrics_sum = zeros(3, n_classes);
        
        % Создаём базовую структуру ud (общую для всех)
        ud_base = struct();
        ud_base.Time = sdata.times;
        ud_base.nClasses = n_classes;
        ud_base.event = sdata.event;  % события одинаковы для всех
        ud_base.Assignment = [];      % будет подставлен для каждого субъекта
        
        for s = 1:n_sets
            ud = ud_base;
            ud.Assignment = sdata.MSClass_all{s}(:);  % вектор всех меток
            metrics_ind = logic_calculate_event_metrics(ud, event_type, time_from, time_to);
            
            % debug print
            fprintf('Metrics for %s: freq = %s, dur = %s, cov = %s\n', ...
                event_type, mat2str(metrics_ind(1,:),3), mat2str(metrics_ind(2,:),3), mat2str(metrics_ind(3,:),3));

            if ~isempty(metrics_ind)
                metrics_sum = metrics_sum + metrics_ind;
            end
        end
        metrics = metrics_sum / n_sets;
    end
    
    function close_fig(~, ~)
        delete(fig);
    end
end