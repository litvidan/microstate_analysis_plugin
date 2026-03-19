function [geometry, geomvert, uilist, title] = get_template_source_ui(all_sources_str)
    % get_template_source_ui - Определяет UI для выбора источника шаблонов
    geometry = {[1] [1]};
    geomvert = [1 1];
    uilist = {...
        {'Style', 'text', 'string', 'Выберите источник карт:'}, ...
        {'Style', 'popupmenu', 'string', all_sources_str, 'tag', 'TemplateChoice', 'Value', 1} ...
    };
    title = 'Источник шаблона';
end
