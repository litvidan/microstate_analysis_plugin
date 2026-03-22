function n_classes = ui_select_nclasses(AllEEG, selected)
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
            {'Style','text','string','Выберите количество классов'}, ...
            {'Style','listbox','string',strjoin(choices,'|'),'Value',1,'Tag','Classes'} ...
        }, 'title', 'Отрисовка динамики');
    if isempty(res)
        n_classes = [];
    else
        n_classes = common(out.Classes);
    end
end