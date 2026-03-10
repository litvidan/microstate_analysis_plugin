function [EEGout, com] = pop_FitMSMaps_simple(AllEEG)
    % pop_FitMSMaps_simple - Упрощённое обратное наложение микросостояний
    % Загружает параметры из fit_config.json

    com = '';
    global EEG CURRENTSET MSTATES_TEMPLATES;
    EEGout = EEG;

    % === 1. Загрузка конфигурации из JSON ===
    config = load_fit_config();
    if isempty(config)
        return;
    end

    % === 2. Выбор наборов ===
    [selected_sets, ~] = select_datasets(AllEEG);
    if isempty(selected_sets)
        return;
    end

    % === 3. Выбор источника шаблонов ===
    [template_source, template_EEG] = select_template_source(AllEEG);
    if isempty(template_source)
        return;
    end

    % === 4. Выполнение обратного наложения ===
    [AllEEG, success_count] = perform_backfitting(AllEEG, selected_sets, template_source, template_EEG, config);

    if success_count == 0
        errordlg2('Ни один набор не был успешно обработан.', 'Ошибка');
        return;
    end
    
    processed_indices = selected_sets(1:success_count);
    EEGout = AllEEG(processed_indices);

    % === 5. Отображение динамики ===
    if success_count > 0
        drawnow;
        % Вызываем pop_ShowIndMSDyn в интерактивном режиме.
        % Он сам спросит, что показывать.
        pop_ShowIndMSDyn(AllEEG);
    end

    % === 6. Сохранение ===
    offer_saving(AllEEG, processed_indices);

    com = 'pop_FitMSMaps_simple(ALLEEG);';
end

% =========================================================================
% Подфункции (возвращены к исходной логике)
% =========================================================================

function config = load_fit_config()
    config = [];
    try
        plugin_path = fileparts(which('eegplugin_simplemicrostate.m'));
        config_file = fullfile(plugin_path, 'fit_config.json');
    catch
         errordlg2('Не удалось найти директорию плагина eegplugin_simplemicrostate.', 'Ошибка');
         return;
    end

    if ~exist(config_file, 'file')
        errordlg2(sprintf('Файл конфигурации не найден:\n%s', config_file), 'Ошибка');
        return;
    end

    try
        json_text = fileread(config_file); 
        config = jsondecode(json_text);
    catch ME
        errordlg2(sprintf('Ошибка при чтении JSON:\n%s', ME.message), 'Ошибка');
        return;
    end

    required = {'nClasses', 'PeakFit', 'SmoothWindow', 'SmoothnessPenalty'};
    missing = {};
    for i = 1:numel(required)
        if ~isfield(config, required{i})
            missing{end+1} = required{i};
        end
    end
    if ~isempty(missing)
        missing_str = strjoin(missing, ', ');
        errordlg2(sprintf('В конфигурации отсутствуют поля: %s', missing_str), 'Ошибка');
        config = [];
    end
end

function [selected_sets, available_sets] = select_datasets(AllEEG)
    % Выбор наборов через GUI
    has_children = arrayfun(@(x) does_it_have_children(AllEEG(x)), 1:numel(AllEEG));
    has_dyn = arrayfun(@(x) is_dynamics_set(AllEEG(x)), 1:numel(AllEEG));
    available_sets = find(~has_children & ~has_dyn & ~cellfun(@isempty, {AllEEG.data}));

    if isempty(available_sets)
        errorDialog('Нет подходящих наборов для обратного наложения.', 'Ошибка');
        selected_sets = [];
        return;
    end

    setnames = {AllEEG(available_sets).setname};
    [res, ~, ~, out] = inputgui(...
        'geometry', [1 1 1], 'geomvert', [1 1 4], ...
        'uilist', {...
            {'Style', 'text', 'string', 'Выберите наборы для наложения карт', 'FontWeight', 'bold'}, ...
            {'Style', 'text', 'string', 'Используйте Ctrl/Shift для множественного выбора'}, ...
            {'Style', 'listbox', 'string', setnames, 'Min', 0, 'Max', 2, 'Value', 1, 'tag', 'SelectedSets'} ...
        }, 'title', 'Распознавание микросостояний');
    if isempty(res)
        selected_sets = [];
        return;
    end
    selected_sets = available_sets(out.SelectedSets);
end

function [template_source, template_EEG] = select_template_source(AllEEG)
    % Выбор источника шаблонов
    global MSTATES_TEMPLATES;
    template_source = [];
    template_EEG = [];

    has_children = arrayfun(@(x) does_it_have_children(AllEEG(x)), 1:numel(AllEEG));
    mean_sets = find(has_children);
    mean_names = {AllEEG(mean_sets).setname};
    
    pub_names = {};
    pub_display = {};
    if ~isempty(MSTATES_TEMPLATES)
        try
            [pub_names, pub_display] = getTemplateNames();
        catch
            disp('Не удалось получить имена опубликованных шаблонов.');
        end
    end
    
    all_sources_cell = [{'Собственные карты каждого набора'}, mean_names, pub_display];
    all_sources_str = strjoin(all_sources_cell, '|');

    [res, ~, ~, out] = inputgui(...
        'geometry', {[1] [1]}, 'geomvert', [1 1], ...
        'uilist', {...
            {'Style', 'text', 'string', 'Выберите источник карт:'}, ...
            {'Style', 'popupmenu', 'string', all_sources_str, 'tag', 'TemplateChoice', 'Value', 1} ...
        }, 'title', 'Источник шаблона');
    if isempty(res)
        return;
    end
    
    if out.TemplateChoice == 1
        template_source = 'own';
    elseif out.TemplateChoice <= 1 + length(mean_names)
        template_idx = out.TemplateChoice - 1;
        template_source = mean_names{template_idx};
        template_EEG = AllEEG(mean_sets(template_idx));
    else
        template_idx = out.TemplateChoice - 1 - length(mean_names);
        template_source = pub_names{template_idx};
        template_EEG = MSTATES_TEMPLATES(find(strcmp(pub_names, template_source), 1));
    end
end

function [AllEEG, success_count] = perform_backfitting(AllEEG, selected_sets, template_source, template_EEG, config)
    % Основной цикл обратного наложения с waitbar
    n_classes = config.nClasses;
    FitPar.PeakFit = config.PeakFit;
    FitPar.b = config.SmoothWindow;
    FitPar.lambda = config.SmoothnessPenalty;
    FitPar.Classes = n_classes;

    h = waitbar(0, 'Подготовка...', 'Name', 'Обратное наложение микросостояний', 'CreateCancelBtn', 'setappdata(gcbf,''canceling'',1)');
    cleanup = onCleanup(@() safe_close(h));

    total_steps = numel(selected_sets);
    success_count = 0;

    for s = 1:total_steps
        if getappdata(h, 'canceling')
            fprintf('Операция прервана пользователем.\n');
            break;
        end

        s_idx = selected_sets(s);
        waitbar(s/total_steps, h, sprintf('Обработка %d из %d: %s', s, total_steps, AllEEG(s_idx).setname));

        EEGtmp = AllEEG(s_idx);

        % Получение карт
        maps_are_valid = false;
        if strcmp(template_source, 'own')
            if isfield(EEGtmp, 'msinfo') && isstruct(EEGtmp.msinfo) && isfield(EEGtmp.msinfo, 'MSMaps') && ...
               numel(EEGtmp.msinfo.MSMaps) >= n_classes && ~isempty(EEGtmp.msinfo.MSMaps(n_classes).Maps)
                maps_are_valid = true;
                maps = EEGtmp.msinfo.MSMaps(n_classes).Maps;
                TemplateInfo.name = '<<собственные>>';
                TemplateInfo.SortedBy = EEGtmp.msinfo.MSMaps(n_classes).SortedBy;
                TemplateInfo.TemplateLabels = EEGtmp.msinfo.MSMaps(n_classes).Labels;
            end
            if ~maps_are_valid
                 warning('Набор %s не содержит карт для %i классов, пропуск.', EEGtmp.setname, n_classes);
                 continue;
            end
        else
            if isfield(template_EEG, 'msinfo') && isstruct(template_EEG.msinfo) && isfield(template_EEG.msinfo, 'MSMaps') && ...
               numel(template_EEG.msinfo.MSMaps) >= n_classes && ~isempty(template_EEG.msinfo.MSMaps(n_classes).Maps)
                maps_are_valid = true;
                maps = template_EEG.msinfo.MSMaps(n_classes).Maps;
                TemplateInfo.name = template_source;
                TemplateInfo.SortedBy = template_EEG.msinfo.MSMaps(n_classes).SortedBy;
                TemplateInfo.TemplateLabels = template_EEG.msinfo.MSMaps(n_classes).Labels;
            end
            if ~maps_are_valid
                warning('Шаблон %s не содержит карт для %i классов, пропуск набора %s.', template_source, n_classes, EEGtmp.setname);
                continue;
            end
        end

        % Ресемплинг каналов
        if ~strcmp(template_source, 'own') && EEGtmp.nbchan ~= template_EEG.nbchan
            [LocalToGlobal, ~] = MakeResampleMatrices(EEGtmp.chanlocs, template_EEG.chanlocs);
            EEGtmp.data = LocalToGlobal * reshape(EEGtmp.data, EEGtmp.nbchan, []);
            EEGtmp.nbchan = template_EEG.nbchan;
            EEGtmp.chanlocs = template_EEG.chanlocs;
        end

        % Присвоение меток и вычисление параметров
        [MSClass, gfp, IndGEVs] = AssignMStates(EEGtmp, maps, FitPar, true);
        if isempty(MSClass)
            warning('Не удалось выполнить наложение для набора %s, пропуск.', EEGtmp.setname);
            continue;
        end
        MSStats = QuantifyMSDynamics(MSClass, gfp, EEGtmp.srate, TemplateInfo, IndGEVs);

        % Сохранение результатов в ALLEEG
        AllEEG(s_idx).msinfo.FitPar = FitPar;
        AllEEG(s_idx).msinfo.MSStats(n_classes) = MSStats;
        AllEEG(s_idx).saved = 'no';
        success_count = success_count + 1;
    end
    
    function safe_close(h_local)
        if ishandle(h_local)
            delete(h_local);
        end
    end
end

function offer_saving(AllEEG, selected_sets)
    % Предлагает сохранить изменения
    if isempty(selected_sets)
        return;
    end
    answer = questdlg('Сохранить изменения в обработанных наборах?', 'Сохранение', ...
        'Сохранить', 'Сохранить как...', 'Отмена', 'Сохранить');
    switch answer
        case 'Сохранить'
            for i = 1:numel(selected_sets)
                pop_saveset(AllEEG(selected_sets(i)), 'savemode', 'resave');
            end
        case 'Сохранить как...'
            for i = 1:numel(selected_sets)
                pop_saveset(AllEEG(selected_sets(i)), 'savemode', 'gui');
            end
    end
end

% === Вспомогательные функции для проверки статуса ===
function has_dyn = is_dynamics_set(in)
    has_dyn = isfield(in, 'msinfo') && isfield(in.msinfo, 'FitPar') && isfield(in.msinfo.FitPar, 'Rectify');
end

function answer = does_it_have_children(in)
    answer = isfield(in, 'msinfo') && isfield(in.msinfo, 'children');
end
