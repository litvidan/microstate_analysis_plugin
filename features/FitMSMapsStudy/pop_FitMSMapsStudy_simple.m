function [STUDY, ALLEEG, com] = pop_FitMSMapsStudy_simple(STUDY, ALLEEG, varargin)
    % pop_FitMSMapsStudy_simple - GUI wrapper for applying microstate backfitting to a STUDY.
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

    % Load configuration
    plugin_path = fileparts(mfilename('fullpath'));
    config_file = fullfile(plugin_path, '..', 'FitMSMaps', 'fit_config.json');
    try
        config = jsondecode(fileread(config_file));
    catch ME
        errordlg(sprintf('Error reading configuration file: %s', ME.message), 'Configuration Error');
        return;
    end

    % UI: select template
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
    fprintf('\n=== Study Backfitting Summary ===\n');
    fprintf('Successfully processed: %d / %d\n', success_count, total);
    if ~isempty(failed_files)
        fprintf('Failed datasets:\n');
        for f = 1:length(failed_files)
            fprintf('  - %s\n', failed_files{f});
        end
    end

    com = sprintf('pop_FitMSMapsStudy_simple(STUDY, ALLEEG);');
end