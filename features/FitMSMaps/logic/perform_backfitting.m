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

