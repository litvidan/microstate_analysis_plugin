function [template_source, template_EEG, canceled] = ui_select_template_for_study(STUDY, ALLEEG, MSTATES_TEMPLATES)
    % UI dialog for selecting microstate template source for STUDY analysis.
    %
    % Inputs:
    %   STUDY              - EEGLAB STUDY structure
    %   ALLEEG             - array of EEG structures (may contain mean datasets)
    %   MSTATES_TEMPLATES  - global variable with public templates
    %
    % Outputs:
    %   template_source    - 'own' or name of selected template dataset
    %   template_EEG       - EEG structure with maps (empty if template_source='own')
    %   canceled           - true if user cancelled

    template_source = [];
    template_EEG = [];
    canceled = false;

    % Collect available templates
    mean_sets = find(arrayfun(@(x) isfield(x, 'msinfo') && isfield(x.msinfo, 'children'), ALLEEG));
    mean_names = {ALLEEG(mean_sets).setname};
    
    pub_names = {};
    if ~isempty(MSTATES_TEMPLATES)
        pub_names = {MSTATES_TEMPLATES.setname};
    end
    
    % Add 'own' as first option
    all_sources_cell = [{'Собственные карты каждого набора'}, mean_names, pub_names];
    if length(all_sources_cell) == 1
        errordlg('Доступные шаблоны не обнаружены', 'Template Error');
        canceled = true;
        return;
    end
    
    % Отрисовка UI
    geometry = {[1 1]};
    geomvert = [1];
    uilist = {{'Style', 'text', 'string', 'Выберите набор карт:'}, ...
              {'Style', 'popupmenu', 'string', strjoin(all_sources_cell, '|'), 'tag', 'TemplateChoice'}};
    title = 'Выберите шаблонные карты';
    
    [res, ~, ~, out] = inputgui('geometry', geometry, 'geomvert', geomvert, 'uilist', uilist, 'title', title);
    if isempty(res)
        canceled = true;
        return;
    end
    
    choice_idx = out.TemplateChoice;
    if choice_idx == 1
        template_source = 'own';
        template_EEG = [];
    elseif choice_idx <= 1 + numel(mean_names)
        mean_idx = choice_idx - 1;
        template_source = mean_names{mean_idx};
        template_EEG = ALLEEG(mean_sets(mean_idx));
    else
        pub_idx = choice_idx - 1 - numel(mean_names);
        template_source = pub_names{pub_idx};
        template_EEG = MSTATES_TEMPLATES(pub_idx);
    end
end