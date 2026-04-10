function [study_data, failed_sets] = logic_load_study_data(STUDY, suffix)
    % logic_load_study_data - Load backfitting results for all datasets in a STUDY.
    % (исправленная версия)

    if nargin < 2
        suffix = '_ms_dynamics';
    end

    n_datasets = length(STUDY.datasetinfo);
    study_data = struct();
    study_data.n_sets = 0;
    study_data.MSClass_all = {};
    study_data.MSStats_all = {};
    study_data.GFP_all = {};
    study_data.setnames = {};
    failed_sets = {};

    n_epochs_ref = [];
    n_points_ref = [];
    times_ref = [];
    srate_ref = [];

    for i = 1:n_datasets
        dinfo = STUDY.datasetinfo(i);
        result_file = fullfile(dinfo.filepath, [dinfo.filename(1:end-4) suffix '.mat']);
        
        if ~exist(result_file, 'file')
            warning('Result file not found: %s', result_file);
            failed_sets{end+1} = dinfo.filename;
            continue;
        end
        
        try
            data = load(result_file);
            if ~isfield(data, 'results') || ~isfield(data.results, 'success') || ~data.results.success
                warning('Invalid or failed results for %s', dinfo.filename);
                failed_sets{end+1} = dinfo.filename;
                continue;
            end
            
            res = data.results;
            
            % ---- Установка эталонных параметров от первого УСПЕШНОГО набора ----
            if isempty(n_epochs_ref)
                % первый успешно загруженный набор задаёт эталон
                n_epochs_ref = res.n_epochs;
                n_points_ref = res.n_points;
                times_ref = res.times;
                srate_ref = res.srate;
            else
                % проверка совместимости с эталоном
                incompatible = false;
                msg = {};
                if res.n_epochs ~= n_epochs_ref
                    incompatible = true;
                    msg{end+1} = sprintf('n_epochs: %d (ref) vs %d (current)', n_epochs_ref, res.n_epochs);
                end
                if res.n_points ~= n_points_ref
                    incompatible = true;
                    msg{end+1} = sprintf('n_points: %d (ref) vs %d (current)', n_points_ref, res.n_points);
                end
                if length(res.times) ~= length(times_ref) || any(abs(res.times - times_ref) > 1e-6)
                    incompatible = true;
                    if length(res.times) ~= length(times_ref)
                        msg{end+1} = sprintf('times length: %d (ref) vs %d (current)', length(times_ref), length(res.times));
                    else
                        diff_max = max(abs(res.times - times_ref));
                        msg{end+1} = sprintf('times values differ (max diff = %g ms)', diff_max);
                    end
                end
                if res.srate ~= srate_ref
                    incompatible = true;
                    msg{end+1} = sprintf('srate: %g (ref) vs %g (current)', srate_ref, res.srate);
                end
                
                if incompatible
                    warning('Dataset %s has incompatible structure:\n  %s', dinfo.filename, strjoin(msg, '\n  '));
                    failed_sets{end+1} = dinfo.filename;
                    continue;
                end
            end
            
            % ---- Хранение MSClass в правильном формате [n_points x n_epochs] ----
            msclass = res.MSClass;
            if isvector(msclass)
                % вектор -> матрица [n_points x n_epochs]
                msclass = reshape(msclass, n_points_ref, n_epochs_ref);
            else
                % уже матрица, проверяем ориентацию
                if size(msclass, 1) ~= n_points_ref
                    % если строки не равны n_points, пробуем транспонировать
                    if size(msclass, 2) == n_points_ref
                        msclass = msclass';
                    else
                        warning('Dataset %s: unexpected MSClass size [%d,%d]', dinfo.filename, size(msclass,1), size(msclass,2));
                        failed_sets{end+1} = dinfo.filename;
                        continue;
                    end
                end
            end
            study_data.MSClass_all{end+1} = msclass;
            study_data.MSStats_all{end+1} = res.MSStats;
            study_data.setnames{end+1} = dinfo.filename;
            study_data.n_sets = study_data.n_sets + 1;
            
            % GFP (если есть)
            if isfield(res.MSStats, 'GFP')
                study_data.GFP_all{end+1} = res.MSStats.GFP;
            else
                study_data.GFP_all{end+1} = [];
            end
            
        catch ME
            warning('Error loading %s: %s', result_file, ME.message);
            failed_sets{end+1} = dinfo.filename;
        end
    end
    
    if study_data.n_sets == 0
        error('No valid datasets found.');
    end
    
    % Добавляем события из первого набора (если нужно)
    dinfo = STUDY.datasetinfo(1);
    EEG_first = pop_loadset('filename', dinfo.filename, 'filepath', dinfo.filepath);
    if ~isempty(EEG_first) && isfield(EEG_first, 'event')
        study_data.event = EEG_first.event;
    else
        study_data.event = [];
    end
    
    study_data.n_points = n_points_ref;
    study_data.times = times_ref;
    study_data.srate = srate_ref;
    study_data.n_classes = length(study_data.MSStats_all{1}.Coverage);
end