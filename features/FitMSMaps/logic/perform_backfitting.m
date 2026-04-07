function [AllEEG, success_count] = perform_backfitting(AllEEG, selected_sets, template_source, template_EEG, config)
    % perform_backfitting - Обратное наложение для нескольких наборов (вызов backfit_single_dataset)
    %
    % Вход:
    %   AllEEG          - массив структур EEG
    %   selected_sets   - индексы наборов для обработки
    %   template_source - 'own' или имя шаблона
    %   template_EEG    - EEG с шаблонами (если template_source не 'own')
    %   config          - структура с параметрами (nClasses, PeakFit, SmoothWindow, SmoothnessPenalty)
    %
    % Выход:
    %   AllEEG          - обновлённый массив
    %   success_count   - количество успешно обработанных наборов

    n_classes = config.nClasses;
    FitPar.PeakFit = config.PeakFit;
    FitPar.b = config.SmoothWindow;
    FitPar.lambda = config.SmoothnessPenalty;
    FitPar.Classes = n_classes;

    % ---- Обеспечить однородность массива AllEEG (поле msinfo должно быть у всех) ----
    for i = 1:length(AllEEG)
        if ~isfield(AllEEG(i), 'msinfo')
            AllEEG(i).msinfo = [];
        end
    end

    h = waitbar(0, 'Подготовка...', 'Name', 'Обратное наложение микросостояний', ...
                'CreateCancelBtn', 'setappdata(gcbf,''canceling'',1)');
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

        % Вызов функции обработки одного набора
        [EEG_updated, success] = backfit_single_dataset(AllEEG(s_idx), template_source, ...
                                                         template_EEG, n_classes, FitPar);

        if success
            AllEEG(s_idx) = EEG_updated;
            success_count = success_count + 1;
        else
            warning('Набор %s не обработан', AllEEG(s_idx).setname);
        end
    end

    function safe_close(h_local)
        if ishandle(h_local)
            delete(h_local);
        end
    end
end


function [EEGout, success] = backfit_single_dataset(EEGin, template_source, template_EEG, n_classes, FitPar)
    % backfit_single_dataset - Обратное наложение для одного набора EEG
    %
    % Вход:
    %   EEGin           - структура EEG
    %   template_source - 'own' или имя другого набора
    %   template_EEG    - EEG структура с шаблонами (если template_source не 'own')
    %   n_classes       - количество классов микросостояний
    %   FitPar          - параметры для AssignMStates
    %
    % Выход:
    %   EEGout          - обновленная структура EEG
    %   success         - true, если обработка успешна

    EEGout = EEGin;
    success = false;

    % 1. Получение карт и информации о шаблоне
    maps_are_valid = false;
    if strcmp(template_source, 'own')
        if isfield(EEGin, 'msinfo') && isstruct(EEGin.msinfo) && ...
           isfield(EEGin.msinfo, 'MSMaps') && ...
           numel(EEGin.msinfo.MSMaps) >= n_classes && ...
           ~isempty(EEGin.msinfo.MSMaps(n_classes).Maps)

            maps_are_valid = true;
            maps = EEGin.msinfo.MSMaps(n_classes).Maps;
            TemplateInfo.name = '<<собственные>>';
            TemplateInfo.SortedBy = EEGin.msinfo.MSMaps(n_classes).SortedBy;
            TemplateInfo.TemplateLabels = EEGin.msinfo.MSMaps(n_classes).Labels;
        end
    else
        if isfield(template_EEG, 'msinfo') && isstruct(template_EEG.msinfo) && ...
           isfield(template_EEG.msinfo, 'MSMaps') && ...
           numel(template_EEG.msinfo.MSMaps) >= n_classes && ...
           ~isempty(template_EEG.msinfo.MSMaps(n_classes).Maps)

            maps_are_valid = true;
            maps = template_EEG.msinfo.MSMaps(n_classes).Maps;
            TemplateInfo.name = template_source;
            TemplateInfo.SortedBy = template_EEG.msinfo.MSMaps(n_classes).SortedBy;
            TemplateInfo.TemplateLabels = template_EEG.msinfo.MSMaps(n_classes).Labels;
        end
    end

    if ~maps_are_valid
        warning('Не удалось получить карты для %d классов из источника %s', n_classes, template_source);
        return;
    end

    % 2. Ресемплинг каналов (если используем внешний шаблон и число каналов разное)
    if ~strcmp(template_source, 'own') && EEGin.nbchan ~= template_EEG.nbchan
        [LocalToGlobal, ~] = MakeResampleMatrices(EEGin.chanlocs, template_EEG.chanlocs);
        EEGout.data = LocalToGlobal * reshape(EEGout.data, EEGout.nbchan, []);
        EEGout.nbchan = template_EEG.nbchan;
        EEGout.chanlocs = template_EEG.chanlocs;
    end

    % 3. Присвоение меток и вычисление параметров
    [MSClass, gfp, IndGEVs] = AssignMStates(EEGout, maps, FitPar, true);
    if isempty(MSClass)
        warning('AssignMStates не вернул метки для набора %s', EEGin.setname);
        return;
    end

    MSStats = QuantifyMSDynamics(MSClass, gfp, EEGout.srate, TemplateInfo, IndGEVs);

    % 4. Сохранение результатов
    if ~isfield(EEGout, 'msinfo') || ~isstruct(EEGout.msinfo)
        EEGout.msinfo = struct();
    end
    EEGout.msinfo.FitPar = FitPar;
    EEGout.msinfo.MSStats(n_classes) = MSStats;
    EEGout.saved = 'no';

    success = true;
end