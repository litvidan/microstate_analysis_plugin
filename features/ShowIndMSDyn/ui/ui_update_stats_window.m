function ui_update_stats_window(fig, ud)
    % Обновляет содержимое окна статистики
    
    % --- Поиск стандартных элементов ---
    table_epoch = findobj(fig, 'Tag', 'table_epoch');
    table_global = findobj(fig, 'Tag', 'table_global');
    text_cov = findobj(fig, 'Tag', 'text_cov');
    if isempty(table_epoch) || isempty(table_global) || isempty(text_cov)
        return;
    end

    % --- Обновление таблиц переходов ---
    epoch_trans = logic_compute_transitions(ud.Assignment, ud.nClasses, ud.Segment);
    set(table_epoch, 'Data', epoch_trans);
    set(table_global, 'Data', ud.global_transitions);

    % --- Обновление текста покрытия ---
    epoch_cov = logic_compute_coverage(ud.Assignment(:, ud.Segment), ud.nClasses);
    cov_str = 'Покрытие (текущая эпоха): ';
    for c = 1:ud.nClasses
        cov_str = [cov_str, sprintf('%s: %.1f%%  ', char(64+c), epoch_cov(c))];
    end
    cov_str = [cov_str, sprintf('\nПокрытие (глобально): ')];
    for c = 1:ud.nClasses
        cov_str = [cov_str, sprintf('%s: %.1f%%  ', char(64+c), ud.global_cov(c))];
    end
    set(text_cov, 'String', cov_str);

    % --- Обновление метрик по событиям ---
    dropdown = findobj(fig, 'Tag', 'dropdown_event_type');
    edit_from = findobj(fig, 'Tag', 'edit_time_from');
    edit_to = findobj(fig, 'Tag', 'edit_time_to');
    table_event = findobj(fig, 'Tag', 'table_event');

    if isempty(dropdown) || isempty(edit_from) || isempty(edit_to) || isempty(table_event)
        return; % Если элементы еще не созданы
    end
    
    % Получаем значения из uicontrol
    event_type_list = get(dropdown, 'String');
    selected_index = get(dropdown, 'Value');
    event_type = event_type_list{selected_index};
    
    time_from = str2double(get(edit_from, 'String'));
    time_to = str2double(get(edit_to, 'String'));
    
    % Проверка, что в ud есть нужные поля
    if ~isfield(ud, 'Assignment') || ~isfield(ud, 'Time')
        disp('Отсутствуют необходимые поля в UserData для расчета метрик по событиям.');
        return;
    end

    % Вызов новой логики
    metrics = logic_calculate_event_metrics(ud, event_type, time_from, time_to);
    
    % Форматирование и обновление таблицы
    formatted_metrics = arrayfun(@(x) sprintf('%.2f', x), metrics, 'UniformOutput', false);
    set(table_event, 'Data', formatted_metrics);
end
