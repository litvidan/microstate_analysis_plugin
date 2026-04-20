function com = pop_ShowIndMSDyn(AllEEG, varargin)
    [~, nogui] = eegplugin_simplemicrostate;
    if nogui, error('Требуется GUI'); end

    global CURRENTSET;
    com = '';

    % Парсинг входных аргументов
    p = inputParser;
    addRequired(p, 'AllEEG', @isstruct);
    addParameter(p, 'nclasses', [], @isnumeric);
    parse(p, AllEEG, varargin{:});
    
    n_classes = p.Results.nclasses;

    % Выбор наборов
    selected = ui_select_datasets(AllEEG, CURRENTSET);
    if isempty(selected), return; end

    % Выбор классов, если они не были переданы
    if isempty(n_classes)
        n_classes = ui_select_nclasses(AllEEG, selected);
        if isempty(n_classes), return; end
    end

    % Определение размера экрана
    figSize = utils_get_screen_size();

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