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
% Подфункции (UI)
% =========================================================================

function config = load_fit_config()
    config = [];
    plugin_path = fileparts(mfilename('fullpath'));
    config_file = fullfile(plugin_path, '..\\fit_config.json');

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

    % Проверка наличия обязательных полей
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
    [geometry, geomvert, uilist, title] = get_dataset_selection_ui(setnames);
    [res, ~, ~, out] = inputgui( 'geometry', geometry, 'geomvert', geomvert, 'uilist', uilist, 'title', title);
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

    [geometry, geomvert, uilist, title] = get_template_source_ui(all_sources_str);
    [res, ~, ~, out] = inputgui('geometry', geometry, 'geomvert', geomvert, 'uilist', uilist, 'title', title);
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

function offer_saving(AllEEG, selected_sets)
    % Предлагает сохранить изменения
    if isempty(selected_sets)
        return;
    end
    [question, title, btn1, btn2, btn3, default_btn] = get_saving_options_ui();
    answer = questdlg(question, title, btn1, btn2, btn3, default_btn);
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
