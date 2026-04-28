function [study_data, failed_sets] = logic_load_study_data(STUDY, suffix)
    if nargin < 2, suffix = '_ms_dynamics'; end

    n_datasets = length(STUDY.datasetinfo);
    study_data = struct();
    study_data.n_sets = 0;
    study_data.MSClass_all = {};
    study_data.MSStats_all = {};
    study_data.GFP_all = {};
    study_data.setnames = {};
    study_data.filters = struct();
    study_data.successful_indices = [];
    study_data.MSMaps = []; % Initialize MSMaps field
    failed_sets = {};

    n_points_ref = [];
    times_ref = [];
    srate_ref = [];
    maps_loaded = false; % Flag to check if maps are loaded

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
            
            if isempty(n_points_ref)
                n_points_ref = res.n_points;
                times_ref = res.times;
                srate_ref = res.srate;
            else
                if res.n_points ~= n_points_ref || res.srate ~= srate_ref
                    warning('Dataset %s has incompatible epoch structure. Skipping.', dinfo.filename);
                    failed_sets{end+1} = dinfo.filename;
                    continue;
                end
            end
            
            if ~maps_loaded
                if isfield(res, 'MSMaps')
                    study_data.MSMaps = res.MSMaps;
                end
                if isfield(res, 'chanlocs')
                    study_data.chanlocs = res.chanlocs;
                end
                maps_loaded = true;
            end
            
            msclass = res.MSClass;
            if isvector(msclass)
                if numel(msclass) ~= (res.n_points * res.n_epochs)
                    warning('Dataset %s: Mismatch in MSClass size.', dinfo.filename);
                    failed_sets{end+1} = dinfo.filename;
                    continue;
                end
                msclass = reshape(msclass, res.n_points, res.n_epochs);
            end
            
            study_data.MSClass_all{end+1} = msclass;
            study_data.MSStats_all{end+1} = res.MSStats;
            study_data.setnames{end+1} = dinfo.filename;
            study_data.n_sets = study_data.n_sets + 1;
            study_data.successful_indices(end+1) = i;
            
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
    
    % --- Сохраняем значения переменных фильтрации (всегда как строки) ---
    possible_vars = {'subject', 'session', 'run', 'condition', 'group'};
    for v = 1:length(possible_vars)
        var_name = possible_vars{v};
        if isfield(STUDY.datasetinfo, var_name)
            raw_vals = {STUDY.datasetinfo.(var_name)};
            if ~isempty(raw_vals) && any(~cellfun(@isempty, raw_vals))
                % Преобразуем всё в строки
                str_vals = cellfun(@(x) num2str(x), raw_vals, 'UniformOutput', false);
                study_data.filters.(var_name) = str_vals(study_data.successful_indices);
            end
        end
    end
    
    % События и chanlocs из первого успешного набора
    first_idx = study_data.successful_indices(1);
    dinfo = STUDY.datasetinfo(first_idx);
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