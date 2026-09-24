function ud = logic_prepare_ms_data(EEG, n_classes, AllEEG)
    global MSTATES_TEMPLATES;   % обязательно!

    ms = EEG.msinfo.MSStats(n_classes);
    time = EEG.times(:);
    n_epochs = EEG.trials;
    n_points = length(time);

    % Преобразование GFP и MSClass
    [gfp, assign] = reshape_ms_data(ms, n_points, n_epochs);

    % Поиск шаблона
    [ChosenTemplate, showMaps] = find_template(EEG, n_classes, AllEEG, ms.FittingTemplate);

    % Цвета
    if showMaps
        map_colors = ChosenTemplate.msinfo.MSMaps(n_classes).ColorMap;
        colors = getColors(n_classes);
        unassigned = all(map_colors == 0.75, 2);
        if any(unassigned)
            valid = find(unassigned) <= size(colors,1);
            map_colors(unassigned & valid, :) = colors(unassigned & valid, :);
        end
        cmap_full = [0.75 0.75 0.75; map_colors];
    else
        colors = getColors(n_classes);
        cmap_full = [0.75 0.75 0.75; colors];
    end

    % fit_data
    fit_data = cell(1, n_epochs);
    for ep = 1:n_epochs
        fit = nan(n_classes+1, n_points);
        assign_ep = assign(:, ep);
        gfp_ep = gfp(:, ep);
        for c = 1:n_classes
            mask = assign_ep == c;
            mask_ext = [false; mask(1:end-1)] | mask;
            fit(c+1, mask_ext) = gfp_ep(mask_ext);
        end
        fit_data{ep} = fit;
    end

    % Итоговая структура
    ud = struct();
    ud.nClasses = n_classes;
    ud.gfp = gfp;
    ud.Assignment = assign;
    ud.Time = time;
    ud.nSegments = n_epochs;
    ud.Segment = 1;
    ud.Start = time(1);
    ud.XRange = min(10000, time(end)-time(1));
    ud.MaxY = 25;
    ud.event = EEG.event;
    ud.cmap = cmap_full;
    ud.global_cov = logic_compute_coverage(assign, n_classes);
    ud.global_transitions = logic_compute_transitions(assign, n_classes);
    ud.fit_data = fit_data;
    ud.stats_fig = [];
    ud.event_lines = [];
    ud.showMaps = showMaps;
    ud.ChosenTemplate = ChosenTemplate;
    if showMaps
        ud.AllMaps = ChosenTemplate.msinfo.MSMaps;
        ud.ClustPar = ChosenTemplate.msinfo.ClustPar;
        ud.chanlocs = ChosenTemplate.chanlocs;
    end
    ud.Visible = true;
    ud.Edit = false;
    ud.Scroll = false;
end

% Вспомогательные локальные функции
function [gfp, assign] = reshape_ms_data(ms, n_points, n_epochs)
    if size(ms.GFP,1) == 1 && size(ms.GFP,2) == n_points*n_epochs
        gfp = reshape(ms.GFP, n_points, n_epochs);
    elseif size(ms.GFP,1) == n_points && size(ms.GFP,2) == n_epochs
        gfp = ms.GFP;
    else
        error('Непредвиденный размер GFP: [%d,%d]', size(ms.GFP,1), size(ms.GFP,2));
    end

    if size(ms.MSClass,1) == n_points*n_epochs && size(ms.MSClass,2) == 1
        assign = reshape(ms.MSClass, n_points, n_epochs);
    elseif size(ms.MSClass,1) == n_points && size(ms.MSClass,2) == n_epochs
        assign = ms.MSClass;
    else
        error('Непредвиденный размер MSClass: [%d,%d]', size(ms.MSClass,1), size(ms.MSClass,2));
    end
end

function [template, show] = find_template(EEG, n_classes, AllEEG, template_name)
    global MSTATES_TEMPLATES;
    show = true;
    template = [];

    if strcmp(template_name, '<<собственные>>')
        if isfield(EEG.msinfo,'MSMaps') && numel(EEG.msinfo.MSMaps) >= n_classes && ...
                isfield(EEG.msinfo.MSMaps(n_classes),'Maps')
            template = EEG;
        else
            show = false;
        end
        return;
    end

    % поиск среди средних наборов
    mean_sets = find(arrayfun(@(x) isfield(AllEEG(x).msinfo,'children'), 1:numel(AllEEG)));
    for i = mean_sets
        if strcmp(AllEEG(i).setname, template_name)
            template = AllEEG(i);
            return;
        end
    end

    % поиск среди опубликованных
    if ~isempty(MSTATES_TEMPLATES)
        for i = 1:numel(MSTATES_TEMPLATES)
            if strcmp(MSTATES_TEMPLATES(i).setname, template_name)
                template = MSTATES_TEMPLATES(i);
                return;
            end
        end
    end

    show = false;
end