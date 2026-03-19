function [EEGout, com] = pop_FindMSMaps_simple(AllEEG)
    % pop_FindMSMaps_simple - Упрощённое выделение микросостояний с загрузкой параметров из cluster_config.mat
    %
    % Вход: ALLEEG - массив структур EEGLAB
    % Выход: EEGout - обновлённые наборы, com - строка истории

    com = '';
    global EEG CURRENTSET;
    EEGout = EEG;

    % === Шаг 1: Загрузка конфигурации из предопределённого файла ===
    config = load_config();
    if isempty(config)
        return; % ошибка уже показана
    end

    % === Шаг 2: Выбор наборов ===
    [selected_sets, available_sets] = select_datasets(AllEEG);
    if isempty(selected_sets)
        return;
    end

    % === Шаг 3: Кластеризация ===
    [AllEEG, failed_sets] = perform_clustering(AllEEG, selected_sets, config);

    % Удаляем неудачные наборы
    selected_sets(ismember(selected_sets, failed_sets)) = [];
    if isempty(selected_sets)
        errordlg2('Ни один набор не был успешно обработан.', 'Ошибка');
        return;
    end
    EEGout = AllEEG(selected_sets);

    % === Шаг 4: Отображение карт ===
    show_maps(AllEEG, selected_sets, config.nClasses);

    % === Шаг 5: Сортировка карт (всегда) ===
    AllEEG = sort_maps(AllEEG, selected_sets);
    EEGout = AllEEG(selected_sets); % обновляем после сортировки

    % === Шаг 6: Сохранение ===
    offer_saving(AllEEG, selected_sets);

    com = 'pop_FindMSMaps_simple(ALLEEG);';
end

% =========================================================================
% Подфункции
% =========================================================================

function config = load_config()
    config = [];
    plugin_path = fileparts(mfilename('fullpath'));
    config_file = fullfile(plugin_path, '..\\cluster_config.json');

    if ~exist(config_file, 'file')
        errordlg2(sprintf('Файл конфигурации не найден:\n%s', config_file), 'Ошибка');
        return;
    end

    try        
        json_text = fileread(config_file); 
        config = jsondecode(json_text);
    catch ME
        errordlg2(sprintf('Ошибка при чтении JSON-файла:\n%s', ME.message), 'Ошибка');
        return;
    end

    % Проверка наличия обязательных полей
    required = {'nClasses', 'GFPPeaks', 'Normalize', 'Restarts'};
    missing = {};
    for i = 1:numel(required)
        if ~isfield(config, required{i})
            missing{end+1} = required{i};
        end
    end
    if ~isempty(missing)
        missing_str = strjoin(missing, ', ');
        errordlg2(sprintf('В конфигурации отсутствуют обязательные поля:\n%s', missing_str), 'Ошибка');
        config = [];
        return;
    end

    fprintf('Конфигурация загружена из %s\n', config_file);
end

function [selected_sets, available_sets] = select_datasets(AllEEG)
    % Выбор наборов через GUI
    has_children = arrayfun(@(x) does_it_have_children(AllEEG(x)), 1:numel(AllEEG));
    has_dyn = arrayfun(@(x) is_dynamics_set(AllEEG(x)), 1:numel(AllEEG));
    available_sets = find(~has_children & ~has_dyn & ~cellfun(@isempty, {AllEEG.data}));

    if isempty(available_sets)
        errorDialog('Нет подходящих наборов для кластеризации.', 'Ошибка');
        selected_sets = [];
        return;
    end

    setnames = {AllEEG(available_sets).setname};
    [res, ~, ~, out] = inputgui(...
        'geometry', [1 1 1], 'geomvert', [1 1 4], ...
        'uilist', {...
            {'Style', 'text', 'string', 'Выберите наборы для кластеризации', 'FontWeight', 'bold'}, ...
            {'Style', 'text', 'string', 'Используйте Ctrl/Shift для множественного выбора'}, ...
            {'Style', 'listbox', 'string', setnames, 'Min', 0, 'Max', 2, 'Value', 1, 'tag', 'SelectedSets'} ...
        }, 'title', 'Выделение микросостояний');
    if isempty(res)
        selected_sets = [];
        return;
    end
    selected_sets = available_sets(out.SelectedSets);
end

function [AllEEG, failed_sets] = perform_clustering(AllEEG, selected_sets, config)
    % Кластеризация выбранных наборов
    n_classes = config.nClasses;
    use_peaks = config.GFPPeaks;
    do_norm = config.Normalize;
    restarts = config.Restarts;

    clust_par.MinClasses = n_classes;
    clust_par.MaxClasses = n_classes;
    clust_par.GFPPeaks = use_peaks;
    clust_par.Normalize = do_norm;
    clust_par.IgnorePolarity = true;
    clust_par.Restarts = restarts;
    clust_par.MaxMaps = inf;

    failed_sets = [];
    for i = 1:length(selected_sets)
        fprintf('Кластеризация набора %i из %i\n', i, length(selected_sets));
        s_idx = selected_sets(i);

        % Сбор данных
        maps_to_use = collect_data(AllEEG(s_idx), use_peaks);

        if size(maps_to_use, 2) < n_classes
            warning('Недостаточно данных для кластеризации в наборе %s', AllEEG(s_idx).setname);
            failed_sets = [failed_sets, s_idx];
            continue;
        end

        flags = '';
        if ~clust_par.IgnorePolarity
            flags = [flags 'p'];
        end
        if clust_par.Normalize
            flags = [flags 'n'];
        end

        [centers, ~, ~, exp_var] = eeg_kMeans(maps_to_use', n_classes, clust_par.Restarts, [], flags, AllEEG(s_idx).chanlocs);

        % Сохраняем результаты
        msinfo.MSMaps(n_classes).Maps = double(centers);
        msinfo.MSMaps(n_classes).ExpVar = double(exp_var);
        msinfo.MSMaps(n_classes).ColorMap = repmat([0.75 0.75 0.75], n_classes, 1);
        for j = 1:n_classes
            msinfo.MSMaps(n_classes).Labels{j} = sprintf('MS_%i.%i', n_classes, j);
        end
        msinfo.MSMaps(n_classes).SortMode = 'none';
        msinfo.MSMaps(n_classes).SortedBy = '';
        msinfo.MSMaps(n_classes).SpatialCorrelation = [];
        msinfo.ClustPar = clust_par;

        AllEEG(s_idx).msinfo = msinfo;
        AllEEG(s_idx).saved = 'no';
    end
end

function maps_to_use = collect_data(EEGset, use_peaks)
    % Собирает данные для кластеризации из одной эпохи/набора
    maps_to_use = [];
    for s = 1:EEGset.trials
        if use_peaks
            gfp = std(EEGset.data(:,:,s), 1, 1);
            is_gfp_peak = find([false, (gfp(1,1:end-2) < gfp(1,2:end-1) & gfp(1,2:end-1) > gfp(1,3:end)), false]);
            maps_to_use = [maps_to_use, EEGset.data(:, is_gfp_peak, s)];
        else
            maps_to_use = [maps_to_use, EEGset.data(:,:,s)];
        end
    end
end

function show_maps(AllEEG, selected_sets, n_classes)
    % Отображает карты
    pop_ShowIndMSMaps(AllEEG, selected_sets, 'Classes', n_classes);
end

function AllEEG = sort_maps(AllEEG, selected_sets)
    % Вызывает интерактивную сортировку для каждого набора
    for i = 1:numel(selected_sets)
        s_idx = selected_sets(i);
        [AllEEG, ~, ~] = pop_SortMSMaps(AllEEG, s_idx);
    end
end

function offer_saving(AllEEG, selected_sets)
    % Предлагает сохранить изменения
    answer = questdlg('Сохранить изменения в наборах данных?', 'Сохранение', ...
                      'Сохранить', 'Сохранить как...', 'Отмена', 'Сохранить');
    switch answer
        case 'Сохранить'
            for i = 1:numel(selected_sets)
                [~] = pop_saveset(AllEEG(selected_sets(i)), ...
                    'filename', AllEEG(selected_sets(i)).filename, ...
                    'filepath', AllEEG(selected_sets(i)).filepath);
            end
        case 'Сохранить как...'
            for i = 1:numel(selected_sets)
                [filename, filepath] = uiputfile('*.set', 'Сохранить набор как', ...
                    AllEEG(selected_sets(i)).filename);
                if filename ~= 0
                    [~] = pop_saveset(AllEEG(selected_sets(i)), ...
                        'filename', filename, 'filepath', filepath);
                end
            end
        otherwise
            % ничего
    end
end

% === Вспомогательные функции (проверка статуса набора) ===
function has_dyn = is_dynamics_set(in)
    has_dyn = false;
    if ~isfield(in,'msinfo'), return; end
    if ~isfield(in.msinfo, 'FitPar'), return; end
    if ~isfield(in.msinfo.FitPar, 'Rectify'), return; else, has_dyn = true; end
end

function answer = does_it_have_children(in)
    answer = false;
    if ~isfield(in,'msinfo'), return; end
    if ~isfield(in.msinfo,'children'), return; else, answer = true; end
end