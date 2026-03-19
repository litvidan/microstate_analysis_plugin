function [geometry, geomvert, uilist, title] = get_nclasses_selection_ui(choices)
    % get_nclasses_selection_ui - Определяет UI для выбора количества классов
    geometry = [1 1];
    geomvert = [1 4];
    uilist = {...
        {'Style', 'text', 'string', 'Выберите количество классов'}, ...
        {'Style', 'listbox', 'string', strjoin(choices, '|'), 'Value', 1, 'Tag', 'Classes'} ...
    };
    title = 'Отрисовка динамики';
end
