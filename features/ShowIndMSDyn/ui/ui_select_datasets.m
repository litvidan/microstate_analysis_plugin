function selected = ui_select_datasets(AllEEG, CURRENTSET)
    has_stats = arrayfun(@(x) utils_has_stats(AllEEG(x)), 1:numel(AllEEG));
    has_dyn = arrayfun(@(x) utils_is_dynamics_set(AllEEG(x)), 1:numel(AllEEG));
    available = find(has_stats & ~has_dyn);

    if isempty(available)
        errordlg2('Нет наборов с временными параметрами.', 'Ошибка');
        selected = [];
        return;
    end

    setnames = {AllEEG(available).setname};
    default = find(available == CURRENTSET, 1, 'first');
    if isempty(default), default = 1; end

    [res, ~, ~, out] = inputgui(...
        'geometry', [1 1 1 1], 'geomvert', [1 1 1 4], ...
        'uilist', {...
            {'Style','text','string','Выберите наборы для отрисовки','FontWeight','bold'}, ...
            {'Style','text','string','Используйте Ctrl/Shift для множественного выбора'}, ...
            {'Style','text','string','Если выбрано несколько, для каждого будет создана вкладка.'}, ...
            {'Style','listbox','string',setnames,'Min',0,'Max',2,'Value',default,'tag','SelectedSets'} ...
        }, 'title', 'Отрисовка временной динамики');

    if isempty(res)
        selected = [];
    else
        selected = available(out.SelectedSets);
    end
end