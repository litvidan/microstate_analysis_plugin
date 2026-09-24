function ui_stats_window(tab)
    ud = get(tab,'UserData');
    % Проверяем, что поле stats_fig существует, является скаляром и валидным handle
    if isfield(ud, 'stats_fig') && isscalar(ud.stats_fig) && ishandle(ud.stats_fig)
        figure(ud.stats_fig);
        return;
    end

    fig = figure('Name', sprintf('Статистика: %s', get(tab,'Title')), ...
        'NumberTitle','off','MenuBar','none','ToolBar','none',...
        'Position',[200 200 800 650], ... % Чуть шире для комфорта
        'CloseRequestFcn',{@close_stats, tab}); % Передаём tab в close_stats
    ud.stats_fig = fig;
    set(tab,'UserData',ud);

    % Сохраняем handle на вкладку в фигуре (для callback'ов)
    set(fig, 'UserData', tab);

    % === 1. Панели переходов (рядом, 50% высоты) ===
    panel_height = 0.48;
    panel_y = 0.50; % от низа фигуры
    panel_width = 0.42;
    left_margin = 0.05;
    gap = 0.06; % между панелями

    % Панель текущей эпохи
    h_panel_epoch = uipanel(fig, 'Units','normalized',...
        'Position',[left_margin, panel_y, panel_width, panel_height],...
        'Title','Переходы (текущая эпоха)','FontSize',11);
    % Панель глобальная
    h_panel_global = uipanel(fig, 'Units','normalized',...
        'Position',[left_margin+panel_width+gap, panel_y, panel_width, panel_height],...
        'Title','Переходы (глобально)','FontSize',11);

    % --- Таблица текущей эпохи ---
    uitable(h_panel_epoch, 'Units','normalized','Position',[0.05 0.05 0.9 0.9],...
        'ColumnName',arrayfun(@(x) char(64+x), 1:ud.nClasses,'UniformOutput',false),...
        'RowName',arrayfun(@(x) char(64+x), 1:ud.nClasses,'UniformOutput',false),...
        'Data',zeros(ud.nClasses), 'ColumnFormat',repmat({'numeric'},1,ud.nClasses),...
        'ColumnEditable',false(1,ud.nClasses), 'ColumnWidth',repmat({50},1,ud.nClasses),...
        'FontSize',12, 'Tag','table_epoch');

    % --- Таблица глобальная ---
    uitable(h_panel_global, 'Units','normalized','Position',[0.05 0.05 0.9 0.9],...
        'ColumnName',arrayfun(@(x) char(64+x), 1:ud.nClasses,'UniformOutput',false),...
        'RowName',arrayfun(@(x) char(64+x), 1:ud.nClasses,'UniformOutput',false),...
        'Data',ud.global_transitions, 'ColumnFormat',repmat({'numeric'},1,ud.nClasses),...
        'ColumnEditable',false(1,ud.nClasses), 'ColumnWidth',repmat({60},1,ud.nClasses),...
        'FontSize',12, 'Tag','table_global');

    % === 2. Панель покрытия ===
    cov_panel_height = 0.12;
    cov_panel_y = panel_y - cov_panel_height - 0.02; % под панелями переходов
    h_panel_cov = uipanel(fig, 'Units','normalized',...
        'Position',[left_margin, cov_panel_y, 1-2*left_margin, cov_panel_height],...
        'Title','Покрытие классов (%)','FontSize',11);

    % Текстовое поле для покрытия (можно использовать две строки или таблицу)
    uicontrol(h_panel_cov, 'Style','text','Units','normalized',...
        'Position',[0.02 0.1 0.96 0.8],...
        'HorizontalAlignment','left','FontSize',10,'String','','Tag','text_cov');

    % === 3. Панель метрик по событиям ===
    event_panel_height = 0.28;
    event_panel_y = 0.05; % внизу
    h_panel_event = uipanel(fig, 'Units','normalized',...
        'Position',[left_margin, event_panel_y, 1-2*left_margin, event_panel_height],...
        'Title','Метрики по событиям','FontSize',11);

    % Выпадающий список типов событий
    if isfield(ud, 'event') && ~isempty(ud.event)
        event_types = unique({ud.event.type});
        is_numeric = cellfun(@isnumeric, event_types);
        event_types(is_numeric) = cellfun(@num2str, event_types(is_numeric), 'UniformOutput', false);
    else
        event_types = {'Нет событий'};
    end
    uicontrol(h_panel_event, 'Style','text','String','Тип события:','Units','normalized',...
        'Position',[0.05 0.80 0.20 0.12],'HorizontalAlignment','left');
    uicontrol(h_panel_event, 'Style','popupmenu', 'String',event_types, 'Tag','dropdown_event_type',...
        'Units','normalized','Position',[0.27 0.80 0.30 0.12], ...
        'Callback', {@(src,~) ui_update_stats_window(fig, get(tab, 'UserData'))});

    % Поля ввода окна
    uicontrol(h_panel_event, 'Style','text','String','Окно (мс):','Units','normalized',...
        'Position',[0.60 0.80 0.15 0.12],'HorizontalAlignment','left');
    uicontrol(h_panel_event, 'Style','edit', 'String','-200', 'Tag','edit_time_from',...
        'Units','normalized','Position',[0.77 0.80 0.08 0.12], ...
        'Callback', {@(src,~) ui_update_stats_window(fig, get(tab, 'UserData'))});
    uicontrol(h_panel_event, 'Style','edit', 'String','800', 'Tag','edit_time_to',...
        'Units','normalized','Position',[0.87 0.80 0.08 0.12], ...
        'Callback', {@(src,~) ui_update_stats_window(fig, get(tab, 'UserData'))});

    % Таблица метрик
    col_names = arrayfun(@(x) sprintf('Класс %c',char(64+x)), 1:ud.nClasses,'UniformOutput',false);
    row_names = {'Частота (на стимул)', 'Длительность (мс)', 'Покрытие (%)'};
    uitable(h_panel_event, 'Units','normalized','Position',[0.05 0.05 0.9 0.68],...
        'ColumnName',col_names, 'RowName',row_names, 'Tag','table_event',...
        'Data',zeros(3, ud.nClasses), 'ColumnFormat',repmat({'numeric'},1,ud.nClasses),...
        'ColumnEditable',false(1,ud.nClasses), 'ColumnWidth',repmat({80},1,ud.nClasses));

    % --- Первичное обновление ---
    ui_update_stats_window(fig, ud);
end

function close_stats(src, ~, tab)
    % Получаем handle на вкладку из переданного аргумента или из UserData фигуры
    if nargin < 3
        tab = get(src, 'UserData');
    end
    if ishandle(tab)
        ud = get(tab,'UserData');
        if isfield(ud,'stats_fig') && ishandle(ud.stats_fig) && ud.stats_fig==src
            ud.stats_fig = [];
            set(tab,'UserData',ud);
        end
    end
    delete(src);
end