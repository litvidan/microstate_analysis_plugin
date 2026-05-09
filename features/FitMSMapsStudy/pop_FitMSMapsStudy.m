function [STUDY, ALLEEG, com] = pop_FitMSMapsStudy(STUDY, ALLEEG, varargin)
    % pop_FitMSMapsStudy - GUI wrapper for applying microstate backfitting to a STUDY.
    % After backfitting, optionally displays grand average dynamics.
    %
    % Usage:
    %   [STUDY, ALLEEG, com] = pop_FitMSMapsStudy_simple(STUDY, ALLEEG);
    %
    % Inputs:
    %   STUDY   - EEGLAB STUDY structure
    %   ALLEEG  - array of EEG structures (may contain mean datasets)
    %
    % Outputs:
    %   STUDY   - updated STUDY (saved flag may be changed)
    %   ALLEEG  - unchanged
    %   com     - command history string

    com = '';
    global MSTATES_TEMPLATES;

    % Загрузка конфигурации
    plugin_path = fileparts(mfilename('fullpath'));
    config_file = fullfile(plugin_path, '..', 'FitMSMaps', 'fit_config.json');
    try
        config = jsondecode(fileread(config_file));
    catch ME
        errordlg(sprintf('Ошибка загрузки конфигурационного файла: %s', ME.message), 'Configuration Error');
        return;
    end

    % UI: выбор шаблона
    [template_source, template_EEG, canceled] = ui_select_template_for_study(STUDY, ALLEEG, MSTATES_TEMPLATES);
    if canceled
        return;
    end

    % Perform backfitting using logic function
    [success_count, failed_files] = logic_perform_study_backfitting(STUDY, template_source, template_EEG, config);

    if success_count > 0
        STUDY.saved = 'no';
    end

    % Report summary
    total = length(STUDY.datasetinfo);
    fprintf('\n=== Обобщение присвоения ===\n');
    fprintf('Успешно обработаны: %d / %d\n', success_count, total);
    if ~isempty(failed_files)
        fprintf('Провальные датасеты:\n');
        for f = 1:length(failed_files)
            fprintf('  - %s\n', failed_files{f});
        end
    end

    % После успешного backfitting, в конце функции pop_FitMSMapsStudy_simple.m:
    if success_count > 0
        answer = questdlg('Присвоение завершено. Показать усреднённую статистику для STUDY?', ...
                          'Study статистика', 'Да', 'Нет', 'Да');
        if strcmp(answer, 'Да')
            try
                % Загружаем все результаты
                study_data = logic_load_study_data(STUDY);
                
                % Вычисляем n_classes, если отсутствует
                if ~isfield(study_data, 'n_classes') && study_data.n_sets > 0
                    study_data.n_classes = length(study_data.MSStats_all{1}.Coverage);
                end
                % Отображаем окно
                ui_study_stats_window(study_data, template_source);
            catch ME
                errordlg(sprintf('Ошибка отображения статистикиs:\n%s', ME.message), 'Ошибка');
            end
        end
    end
    
    com = sprintf('pop_FitMSMapsStudy_simple(STUDY, ALLEEG);');
end