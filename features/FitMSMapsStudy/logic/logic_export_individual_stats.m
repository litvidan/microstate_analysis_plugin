function logic_export_individual_stats(fig, template_name)
    % Экспорт индивидуальных данных каждого датасета в Excel/CSV
    study_data = getappdata(fig, 'study_data');
    indices = getappdata(fig, 'current_indices');
    if isempty(indices)
        warndlg('Нет данных для экспорта. Сначала примените фильтры.', 'Экспорт');
        return;
    end

    % Временное окно из GUI
    edit_from = findobj(fig, 'Tag', 'edit_time_from');
    edit_to   = findobj(fig, 'Tag', 'edit_time_to');
    if isempty(edit_from) || isempty(edit_to)
        time_from = -200; time_to = 800;
    else
        time_from = str2double(get(edit_from, 'String'));
        time_to   = str2double(get(edit_to, 'String'));
    end

    n_classes = study_data.n_classes;
    class_names = arrayfun(@(x) char(64+x), 1:n_classes, 'UniformOutput', false);

    % Фиксированный порядок потенциальных фильтров
    all_filter_fields = {'subject', 'session', 'run', 'condition', 'group'};
    available_filters = fieldnames(study_data.filters);
    % Выбираем только те, которые есть в данных, и в указанном порядке
    ordered_filters = {};
    for f = 1:length(all_filter_fields)
        if any(strcmp(available_filters, all_filter_fields{f}))
            ordered_filters{end+1} = all_filter_fields{f};
        end
    end
    n_filters = length(ordered_filters);

    % Типы событий
    if isfield(study_data, 'event') && ~isempty(study_data.event)
        raw_types = {study_data.event.type};
        event_types = unique(cellfun(@(x) num2str(x), raw_types, 'UniformOutput', false));
    else
        event_types = {};
    end
    n_events = length(event_types);

    % Заголовки столбцов
    col_names = {'Dataset'};
    for f = 1:n_filters
        col_names{end+1} = sprintf('filter_%s', ordered_filters{f});
    end
    for c = 1:n_classes
        col_names{end+1} = sprintf('Coverage_%s', class_names{c});
    end
    % Переходы: все пары from→to, where from≠to
    for from = 1:n_classes
        for to = 1:n_classes
            if from ~= to
                col_names{end+1} = sprintf('Trans_%s→%s', class_names{from}, class_names{to});
            end
        end
    end
    % События: для каждого типа события – три метрики (Freq, Dur, Cov) по каждому классу
    for ev = 1:n_events
        ev_name = event_types{ev};
        for metric = {'Freq','Dur','Cov'}
            mname = metric{1};
            for c = 1:n_classes
                col_names{end+1} = sprintf('%s_%s_%s', ev_name, mname, class_names{c});
            end
        end
    end

    n_datasets = length(indices);
    data_table = cell(n_datasets, length(col_names));

    ud_base.Time = study_data.times;
    ud_base.nClasses = n_classes;
    ud_base.event = study_data.event;

    for row = 1:n_datasets
        idx = indices(row);
        % Название датасета
        data_table{row, 1} = study_data.setnames{idx};

        % Значения фильтров в строгом порядке
        for f = 1:n_filters
            fname = ordered_filters{f};
            vals = study_data.filters.(fname);
            if iscell(vals)
                data_table{row, 1+f} = vals{idx};
            else
                data_table{row, 1+f} = num2str(vals(idx));
            end
        end

        % Покрытие классов
        assign = study_data.MSClass_all{idx};
        cov = logic_compute_coverage(assign, n_classes);
        offset = 1 + n_filters;
        for c = 1:n_classes
            data_table{row, offset + c} = cov(c);
        end

        % Матрица переходов (развёрнутая)
        trans = logic_compute_transitions(assign, n_classes);
        trans_start = offset + n_classes;
        trans_idx = 1;
        for from = 1:n_classes
            for to = 1:n_classes
                if from ~= to
                    data_table{row, trans_start + trans_idx} = trans(from, to);
                    trans_idx = trans_idx + 1;
                end
            end
        end

        % Метрики по событиям
        ud = ud_base;
        ud.Assignment = assign(:);
        event_start = trans_start + (n_classes * (n_classes - 1)); % общее число переходов
        for ev = 1:n_events
            ev_type = event_types{ev};
            m = logic_calculate_event_metrics(ud, ev_type, time_from, time_to);
            for met = 1:3
                for c = 1:n_classes
                    col = event_start + (ev-1)*3*n_classes + (met-1)*n_classes + c;
                    data_table{row, col} = m(met, c);
                end
            end
        end
    end

    % Диалог сохранения
    default_name = sprintf('individual_stats_%s.xlsx', datestr(now, 'yyyymmdd_HHMMSS'));
    [file, path] = uiputfile({'*.xlsx','Excel files (*.xlsx)';'*.csv','CSV files (*.csv)'}, ...
        'Сохранить индивидуальные данные', default_name);
    if isequal(file,0), return; end
    fullpath = fullfile(path, file);

    out_table = cell2table(data_table, 'VariableNames', col_names);
    [~,~,ext] = fileparts(fullpath);
    if strcmpi(ext, '.xlsx')
        writetable(out_table, fullpath, 'Sheet', 'IndividualData', 'WriteRowNames', false);
    else
        writetable(out_table, fullpath);
    end
    fprintf('Индивидуальные данные сохранены в %s\n', fullpath);
end