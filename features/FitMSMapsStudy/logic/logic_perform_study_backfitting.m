function [success_count, failed_files] = logic_perform_study_backfitting(STUDY, template_source, template_EEG, config)
    % Apply microstate backfitting to all datasets in a STUDY and save results to .mat files.
    %
    % Inputs:
    %   STUDY           - EEGLAB STUDY structure
    %   template_source - 'own' or name of template dataset
    %   template_EEG    - EEG structure with maps (if template_source ~= 'own')
    %   config          - structure with fields: nClasses, PeakFit, SmoothWindow, SmoothnessPenalty
    %
    % Outputs:
    %   success_count   - number of successfully processed datasets
    %   failed_files    - cell array of filenames that failed

    n_classes = config.nClasses;
    FitPar.PeakFit = config.PeakFit;
    FitPar.b = config.SmoothWindow;
    FitPar.lambda = config.SmoothnessPenalty;
    FitPar.Classes = n_classes;

    % Validate template maps if not 'own'
    if ~strcmp(template_source, 'own')
        if ~isfield(template_EEG, 'msinfo') || ~isfield(template_EEG.msinfo, 'MSMaps') || ...
           numel(template_EEG.msinfo.MSMaps) < n_classes || isempty(template_EEG.msinfo.MSMaps(n_classes).Maps)
            error('Шаблонные карты "%s" не содержат валидных карт для %d классов.', template_source, n_classes);
        end
    end

    total_datasets = length(STUDY.datasetinfo);
    success_count = 0;
    failed_files = {};

    % Waitbar
    h = waitbar(0, 'Начинается процесс присвоения...', 'Name', 'Присвоение карт...', ...
                'CreateCancelBtn', 'setappdata(gcbf,''canceling'',1)');
    cleanup = onCleanup(@() delete(h(ishandle(h))));

    for i = 1:total_datasets
        if getappdata(h, 'canceling')
            fprintf('Операция отменена пользователем.\n');
            break;
        end

        dinfo = STUDY.datasetinfo(i);
        waitbar(i / total_datasets, h, sprintf('Обработка %s...', dinfo.filename));

        % Load dataset
        EEG = pop_loadset('filename', dinfo.filename, 'filepath', dinfo.filepath);
        if isempty(EEG)
            warning('Не получилось загрузить датасет %s, пропускаю.', dinfo.filename);
            failed_files{end+1} = dinfo.filename;
            continue;
        end

        % Call backfitting
        [EEG_updated, success] = backfit_single_dataset(EEG, template_source, template_EEG, n_classes, FitPar);

        % Prepare results structure
        results = struct();
        results.success = success;
        results.n_epochs = EEG.trials;
        results.n_points = EEG.pnts;
        results.times = EEG.times;
        results.srate = EEG.srate;

        if success
            results.MSClass = EEG_updated.msinfo.MSStats(n_classes).MSClass;
            results.MSStats = EEG_updated.msinfo.MSStats(n_classes);
            success_count = success_count + 1;
        else
            warning('Присвоение не удалось для %s, пропускаю.', EEG.setname);
            failed_files{end+1} = dinfo.filename;
        end

        % Save to .mat file
        [~, name, ~] = fileparts(dinfo.filename);
        output_filename = fullfile(dinfo.filepath, [name, '_ms_dynamics.mat']);
        try
            save(output_filename, 'results');
            if success
                fprintf('Сохранена динамика для %s\n', EEG.setname);
            else
                fprintf('Сохранен маркер ошибки для %s\n', EEG.setname);
            end
        catch ME
            warning('Не получилось сохранить результат для %s: %s', EEG.setname, ME.message);
        end

        clear EEG EEG_updated;
    end
end