function ui_stats_window(tab)
    ud = get(tab,'UserData');
    % Проверяем, что поле stats_fig существует, является скаляром и валидным handle
    if isfield(ud, 'stats_fig') && isscalar(ud.stats_fig) && ishandle(ud.stats_fig)
        figure(ud.stats_fig);
        return;
    end

    fig = figure('Name', sprintf('Статистика: %s', get(tab,'Title')), ...
        'NumberTitle','off','MenuBar','none','ToolBar','none',...
        'Position',[200 200 550 850], 'CloseRequestFcn',{@close_stats}); % Увеличена высота
    ud.stats_fig = fig;
    set(tab,'UserData',ud);

    % --- Панели ---
    h_panel_epoch = uipanel(fig, 'Units','normalized','Position',[0.05 0.70 0.9 0.28],...
        'Title','Переходы (текущая эпоха)','FontSize',11);
    h_panel_global = uipanel(fig, 'Units','normalized','Position',[0.05 0.40 0.9 0.28],...
        'Title','Переходы (глобально)','FontSize',11);
    h_panel_event = uipanel(fig, 'Units','normalized','Position',[0.05 0.05 0.9 0.33],...
        'Title','Метрики по событиям','FontSize',11);

    % --- Таблица текущей эпохи ---
    uitable(h_panel_epoch, 'Units','normalized','Position',[0.05 0.1 0.9 0.8],...
        'ColumnName',arrayfun(@(x) char(64+x), 1:ud.nClasses,'UniformOutput',false),...
        'RowName',arrayfun(@(x) char(64+x), 1:ud.nClasses,'UniformOutput',false),...
        'Data',zeros(ud.nClasses), 'ColumnFormat',repmat({'numeric'},1,ud.nClasses),...
        'ColumnEditable',false(1,ud.nClasses), 'ColumnWidth',repmat({50},1,ud.nClasses),...
        'FontSize',12, 'Tag','table_epoch');

    % --- Таблица глобально ---
    uitable(h_panel_global, 'Units','normalized','Position',[0.05 0.1 0.9 0.8],...
        'ColumnName',arrayfun(@(x) char(64+x), 1:ud.nClasses,'UniformOutput',false),...
        'RowName',arrayfun(@(x) char(64+x), 1:ud.nClasses,'UniformOutput',false),...
        'Data',ud.global_transitions, 'ColumnFormat',repmat({'numeric'},1,ud.nClasses),...
        'ColumnEditable',false(1,ud.nClasses), 'ColumnWidth',repmat({60},1,ud.nClasses),...
        'FontSize',12, 'Tag','table_global');
        
    % --- Текст покрытия (перемещен наверх) ---
    uicontrol(fig, 'Style','text','Units','normalized','Position',[0.05 0.98 0.9 0.02],...
        'HorizontalAlignment','left','FontSize',10,'String','','Tag','text_cov');

    % --- Элементы для метрик по событиям ---
    % Получаем уникальные типы событий
    if isfield(ud, 'event') && ~isempty(ud.event)
        event_types = unique({ud.event.type});
        is_numeric = cellfun(@isnumeric, event_types);
        event_types(is_numeric) = cellfun(@num2str, event_types(is_numeric), 'UniformOutput', false);
    else
        event_types = {'Нет событий'};
    end

    uicontrol(h_panel_event, 'Style','text','String','Тип события:','Units','normalized',...
        'Position',[0.05 0.85 0.25 0.1],'HorizontalAlignment','left');
    uicontrol(h_panel_event, 'Style','popupmenu', 'String',event_types, 'Tag','dropdown_event_type',...
        'Units','normalized','Position',[0.3 0.85 0.65 0.1], ...
        'Callback', {@(src, event) ui_update_stats_window(fig, get(tab, 'UserData'))});

    uicontrol(h_panel_event, 'Style','text','String','Окно (мс):','Units','normalized',...
        'Position',[0.05 0.7 0.25 0.1],'HorizontalAlignment','left');
    uicontrol(h_panel_event, 'Style','edit', 'String','-200', 'Tag','edit_time_from',...
        'Units','normalized','Position',[0.3 0.7 0.3 0.1], ...
        'Callback', {@(src, event) ui_update_stats_window(fig, get(tab, 'UserData'))});
    uicontrol(h_panel_event, 'Style','edit', 'String','800', 'Tag','edit_time_to',...
        'Units','normalized','Position',[0.65 0.7 0.3 0.1], ...
        'Callback', {@(src, event) ui_update_stats_window(fig, get(tab, 'UserData'))});

    col_names = arrayfun(@(x) sprintf('Класс %c',char(64+x)), 1:ud.nClasses,'UniformOutput',false);
    row_names = {'Частота (на стимул)', 'Длительность (мс)', 'Покрытие (%)'};
    uitable(h_panel_event, 'Units','normalized','Position',[0.05 0.05 0.9 0.6],...
        'ColumnName',col_names, 'RowName',row_names, 'Tag','table_event',...
        'Data',zeros(3, ud.nClasses), 'ColumnFormat',repmat({'numeric'},1,ud.nClasses),...
        'ColumnEditable',false(1,ud.nClasses), 'ColumnWidth',repmat({80},1,ud.nClasses));

    % --- Первичное обновление ---
    set(fig, 'UserData', tab); % Сохраняем handle на основную вкладку
    ui_update_stats_window(fig, ud);
end

function close_stats(src,~)
    % Получаем handle на вкладку из UserData фигуры
    tab = get(src, 'UserData');
    if ishandle(tab)
        ud = get(tab,'UserData');
        if isfield(ud,'stats_fig') && ishandle(ud.stats_fig) && ud.stats_fig==src
            ud.stats_fig = [];
            set(tab,'UserData',ud);
        end
    end
    delete(src);
end
