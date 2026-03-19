function [AllEEG, success_count] = perform_backfitting(AllEEG, selected_sets, template_source, template_EEG, config)
    % perform_backfitting - Основная логика для обратного наложения микросостояний
    %
    % Входные параметры:
    %   AllEEG          - Структура ALLEEG
    %   selected_sets   - Индексы выбранных для обработки наборов
    %   template_source - Имя источника шаблонов ('own' или имя набора)
    %   template_EEG    - EEG структура с шаблонами (если не 'own')
    %   config          - Структура с параметрами из fit_config.json
    %
    % Возвращаемые значения:
    %   AllEEG          - Обновленная структура ALLEEG
    %   success_count   - Количество успешно обработанных наборов
    %

    n_classes = config.nClasses;
    FitPar.PeakFit = config.PeakFit;
    FitPar.b = config.SmoothWindow;
    FitPar.lambda = config.SmoothnessPenalty;
    FitPar.Classes = n_classes;

    h = waitbar(0, 'Подготовка...', 'Name', 'Обратное наложение микросостояний', 'CreateCancelBtn', 'setappdata(gcbf,''canceling'',1)');
    cleanup = onCleanup(@() safe_close(h));

    total_steps = numel(selected_sets);
    success_count = 0;

    for s = 1:total_steps
        if getappdata(h, 'canceling')
            fprintf('Операция прервана пользователем.\n');
            break;
        end

        s_idx = selected_sets(s);
        waitbar(s/total_steps, h, sprintf('Обработка %d из %d: %s', s, total_steps, AllEEG(s_idx).setname));

        EEGtmp = AllEEG(s_idx);

        % Получение карт
        maps_are_valid = false;
        if strcmp(template_source, 'own')
            if isfield(EEGtmp, 'msinfo') && isstruct(EEGtmp.msinfo) && isfield(EEGtmp.msinfo, 'MSMaps') && ...
               numel(EEGtmp.msinfo.MSMaps) >= n_classes && ~isempty(EEGtmp.msinfo.MSMaps(n_classes).Maps)
                maps_are_valid = true;
                maps = EEGtmp.msinfo.MSMaps(n_classes).Maps;
                TemplateInfo.name = '<<собственные>>';
                TemplateInfo.SortedBy = EEGtmp.msinfo.MSMaps(n_classes).SortedBy;
                TemplateInfo.TemplateLabels = EEGtmp.msinfo.MSMaps(n_classes).Labels;
            end
            if ~maps_are_valid
                 warning('Набор %s не содержит карт для %i классов, пропуск.', EEGtmp.setname, n_classes);
                 continue;
            end
        else
            if isfield(template_EEG, 'msinfo') && isstruct(template_EEG.msinfo) && isfield(template_EEG.msinfo, 'MSMaps') && ...
               numel(template_EEG.msinfo.MSMaps) >= n_classes && ~isempty(template_EEG.msinfo.MSMaps(n_classes).Maps)
                maps_are_valid = true;
                maps = template_EEG.msinfo.MSMaps(n_classes).Maps;
                TemplateInfo.name = template_source;
                TemplateInfo.SortedBy = template_EEG.msinfo.MSMaps(n_classes).SortedBy;
                TemplateInfo.TemplateLabels = template_EEG.msinfo.MSMaps(n_classes).Labels;
            end
            if ~maps_are_valid
                warning('Шаблон %s не содержит карт для %i классов, пропуск набора %s.', template_source, n_classes, EEGtmp.setname);
                continue;
            end
        end

        % Ресемплинг каналов
        if ~strcmp(template_source, 'own') && EEGtmp.nbchan ~= template_EEG.nbchan
            [LocalToGlobal, ~] = MakeResampleMatrices(EEGtmp.chanlocs, template_EEG.chanlocs);
            EEGtmp.data = LocalToGlobal * reshape(EEGtmp.data, EEGtmp.nbchan, []);
            EEGtmp.nbchan = template_EEG.nbchan;
            EEGtmp.chanlocs = template_EEG.chanlocs;
        end

        % Присвоение меток и вычисление параметров
        [MSClass, gfp, IndGEVs] = AssignMStates(EEGtmp, maps, FitPar, true);
        if isempty(MSClass)
            warning('Не удалось выполнить наложение для набора %s, пропуск.', EEGtmp.setname);
            continue;
        end
        MSStats = QuantifyMSDynamics(MSClass, gfp, EEGtmp.srate, TemplateInfo, IndGEVs);

        % Сохранение результатов в ALLEEG
        AllEEG(s_idx).msinfo.FitPar = FitPar;
        AllEEG(s_idx).msinfo.MSStats(n_classes) = MSStats;
        AllEEG(s_idx).saved = 'no';
        success_count = success_count + 1;
    end
    
    function safe_close(h_local)
        if ishandle(h_local)
            delete(h_local);
        end
    end
end
