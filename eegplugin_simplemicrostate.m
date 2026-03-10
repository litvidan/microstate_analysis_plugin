function [vers, nogui] = eegplugin_simplemicrostate(fig, try_strings, catch_strings)

    vers = 'SimpleMicrostatePlugin 1.0';
    nogui = isempty(findobj('Tag','EEGLAB'));

    pluginpath = fileparts(mfilename('fullpath'));
    addpath(genpath(pluginpath));

    if ~ismember('MSTATES_TEMPLATES', who('global'))
        global MSTATES_TEMPLATES;
        templatepath = fullfile(pluginpath, 'Templates');
        if exist(templatepath, 'dir')
            Templates = dir(fullfile(templatepath, '*.set'));
            MSTemplate = [];
            for t = 1:numel(Templates)
                MSTemplate = eeg_store(MSTemplate, ...
                    pop_loadset('filename', Templates(t).name, 'filepath', templatepath));
            end
            MSTATES_TEMPLATES = MSTemplate;
            fprintf('  - Загружено %d шаблонов из Templates\n', numel(Templates));
        else
            MSTATES_TEMPLATES = [];
            fprintf('  - Папка Templates не найдена\n');
        end
    end

    if nargin > 0
        % Команда для выделения микросостояний
        comFind = [try_strings.no_check ...
            '[EEG, LASTCOM] = pop_FindMSMaps_simple(ALLEEG);' ...
            'if ~isempty(LASTCOM),' ...
            '   assignin(''base'', ''EEG'', EEG);' ...
            'end;' ...
            catch_strings.store_and_hist];

        % Команда для распознавания микросостояний
        comFit = [try_strings.no_check ...
            '[EEG, LASTCOM] = pop_FitMSMaps_simple(ALLEEG);' ...
            'if ~isempty(LASTCOM),' ...
            '   assignin(''base'', ''EEG'', EEG);' ...
            'end;' ...
            catch_strings.store_and_hist];

        % Добавление пунктов меню в Tools
        toolsmenu = findobj(fig, 'tag', 'tools');
        submenu = uimenu(toolsmenu, 'label', 'Микросостояния (упрощённый плагин)', ...
            'userdata', 'study:on', 'Separator', 'on');
        uimenu(submenu, 'Label', 'Выделить n микросостояний', ...
            'Callback', comFind, 'userdata', 'study:on');
        uimenu(submenu, 'Label', 'Распознать микросостояния на ЭЭГ', ...
            'Callback', comFit, 'userdata', 'study:on');
    end
end