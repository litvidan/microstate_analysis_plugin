function ud = ShowIndMSDyn_logic(EEG, n_classes, AllEEG)
    global MSTATES_TEMPLATES;
    % ShowIndMSDyn_logic - Подготовка данных для отображения динамики микросостояний

    ms = EEG.msinfo.MSStats(n_classes);
    time = EEG.times(:);
    n_epochs = EEG.trials;
    n_points = length(time);

    if size(ms.GFP, 1) == 1 && size(ms.GFP, 2) == n_points * n_epochs, gfp = reshape(ms.GFP, n_points, n_epochs);
    elseif size(ms.GFP, 1) == n_points && size(ms.GFP, 2) == n_epochs, gfp = ms.GFP;
    else, error('Непредвиденный размер GFP: [%d, %d]', size(ms.GFP,1), size(ms.GFP,2)); end
    
    if size(ms.MSClass, 1) == n_points * n_epochs && size(ms.MSClass, 2) == 1, assign = reshape(ms.MSClass, n_points, n_epochs);
    elseif size(ms.MSClass, 1) == n_points && size(ms.MSClass, 2) == n_epochs, assign = ms.MSClass;
    else, error('Непредвиденный размер MSClass: [%d, %d]', size(ms.MSClass,1), size(ms.MSClass,2)); end

    template_name = ms.FittingTemplate;
    showMaps = true;
    ChosenTemplate = [];
    global MSTATES_TEMPLATES;

    if strcmp(template_name, '<<собственные>>')
        if isfield(EEG.msinfo, 'MSMaps') && numel(EEG.msinfo.MSMaps) >= n_classes && isfield(EEG.msinfo.MSMaps(n_classes), 'Maps')
            ChosenTemplate = EEG;
        else, showMaps = false; end
    else
        mean_sets = find(arrayfun(@(x) DoesItHaveChildren(AllEEG(x)), 1:numel(AllEEG)));
        for i = mean_sets, if strcmp(AllEEG(i).setname, template_name), ChosenTemplate = AllEEG(i); break; end, end
        if isempty(ChosenTemplate) && ~isempty(MSTATES_TEMPLATES)
            for i = 1:numel(MSTATES_TEMPLATES), if strcmp(MSTATES_TEMPLATES(i).setname, template_name), ChosenTemplate = MSTATES_TEMPLATES(i); break; end, end
        end
        if isempty(ChosenTemplate), showMaps = false; end
    end

    ud = struct();
    % Инициализация полей Visible, Edit, Scroll независимо от showMaps
    ud.Visible = true; 
    ud.Edit = false; 
    ud.Scroll = false;

    if showMaps
        map_colors = ChosenTemplate.msinfo.MSMaps(n_classes).ColorMap;
        colors = getColors(n_classes);
        unassigned = all(map_colors == 0.75, 2);
        if any(unassigned)
            unassigned_indices = find(unassigned);
            valid_indices_to_update = unassigned_indices(unassigned_indices <= size(colors, 1));
            if ~isempty(valid_indices_to_update), map_colors(valid_indices_to_update, :) = colors(valid_indices_to_update, :); end
        end
        cmap_full = [0.75 0.75 0.75; map_colors];
        ud.AllMaps = ChosenTemplate.msinfo.MSMaps;
        ud.ClustPar = ChosenTemplate.msinfo.ClustPar;
        ud.chanlocs = ChosenTemplate.chanlocs;
    else
        colors = getColors(n_classes);
        cmap_full = [0.75 0.75 0.75; colors];
    end

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


    ud.nClasses = n_classes;
    ud.gfp = gfp;
    ud.Assignment = assign;
    ud.Time = time;
    ud.nSegments = n_epochs;
    ud.Segment = 1;
    ud.Start = 0;
    ud.XRange = min(10000, time(end) - time(1));
    ud.MaxY = 25;
    ud.event = EEG.event;
    ud.cmap = cmap_full;
    ud.global_cov = compute_global_coverage(assign, n_classes);
    ud.global_transitions = compute_global_transitions(assign, n_classes);
    ud.fit_data = fit_data;
    ud.stats_fig = [];
    ud.event_handles = [];
    ud.showMaps = showMaps;
    ud.ChosenTemplate = ChosenTemplate;
end

function global_cov = compute_global_coverage(assign, n_classes)
    assign_flat = assign(:); valid = assign_flat > 0; total_valid = sum(valid);
    if total_valid == 0, global_cov = zeros(1, n_classes); return; end
    global_cov = zeros(1, n_classes);
    for c = 1:n_classes, global_cov(c) = sum(assign_flat == c) / total_valid * 100; end
end

function global_trans_matrix = compute_global_transitions(assign, n_classes)
    global_trans_matrix = zeros(n_classes); n_epochs = size(assign, 2);
    for ep = 1:n_epochs
        assign_epoch = assign(:, ep); changes = find(diff(assign_epoch) ~= 0);
        for i = 1:numel(changes)
            from = assign_epoch(changes(i)); to = assign_epoch(changes(i)+1);
            if from > 0 && to > 0 && from ~= to, global_trans_matrix(from, to) = global_trans_matrix(from, to) + 1; end
        end
    end
    for from = 1:n_classes
        total_from = sum(global_trans_matrix(from, :));
        if total_from > 0, global_trans_matrix(from, :) = global_trans_matrix(from, :) / total_from * 100; end
    end
end

function answer = DoesItHaveChildren(in)
    answer = isfield(in,'msinfo') && isfield(in.msinfo,'children');
end
