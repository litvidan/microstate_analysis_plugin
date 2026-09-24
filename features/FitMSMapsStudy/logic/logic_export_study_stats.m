function logic_export_study_stats(fig, template_name)
    study_data = getappdata(fig, 'study_data');
    indices = getappdata(fig, 'current_indices');
    if isempty(indices) || isempty(study_data)
        warndlg('Нет данных для экспорта. Сначала примените фильтры.', 'Экспорт');
        return;
    end
    
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
    
    % Покрытие и переходы (средние по выбранным)
    cov_sum = zeros(1, n_classes);
    trans_sum = zeros(n_classes);
    for i = indices
        assign = study_data.MSClass_all{i};
        cov_sum = cov_sum + logic_compute_coverage(assign, n_classes);
        trans_sum = trans_sum + logic_compute_transitions(assign, n_classes);
    end
    n_sel = length(indices);
    avg_cov = cov_sum / n_sel;
    avg_trans = trans_sum / n_sel;
    
    % Метрики по всем событиям
    [event_types, freq_mat, dur_mat, cov_mat] = logic_compute_all_event_metrics(study_data, indices, time_from, time_to);
    
    % Фильтры
    filter_names = fieldnames(study_data.filters);
    filter_vals = cell(1, length(filter_names));
    for f = 1:length(filter_names)
        ctrl = findobj(fig, 'Tag', ['filter_' filter_names{f}]);
        if ~isempty(ctrl)
            items = get(ctrl, 'String');
            val = get(ctrl, 'Value');
            filter_vals{f} = items{val};
        else
            filter_vals{f} = 'Все';
        end
    end
    
    % Диалог сохранения
    default_name = sprintf('статистика_STUDY_%s.xlsx', datestr(now, 'yyyymmdd_HHMMSS'));
    [file, path] = uiputfile({'*.xlsx','Файлы Excel (*.xlsx)';'*.csv','CSV файлы (*.csv)'}, ...
        'Сохранить статистику', default_name);
    if isequal(file,0), return; end
    fullpath = fullfile(path, file);
    
    % Таблицы
    cov_table = array2table(avg_cov, 'VariableNames', class_names, 'RowNames', {'Покрытие (%)'});
    trans_table = array2table(avg_trans, 'VariableNames', class_names, 'RowNames', class_names);
    freq_table = array2table(freq_mat, 'VariableNames', class_names, 'RowNames', event_types);
    dur_table  = array2table(dur_mat,  'VariableNames', class_names, 'RowNames', event_types);
    cov_event_table = array2table(cov_mat, 'VariableNames', class_names, 'RowNames', event_types);
    
    info = { 'Параметр','Значение';
             'Количество наборов',num2str(n_sel);
             'Шаблон',template_name;
             'Окно (мс)',sprintf('[%d,%d]',time_from,time_to) };
    for i = 1:length(filter_names)
        info{end+1,1} = filter_names{i};
        info{end,2} = filter_vals{i};
    end
    
    [~,~,ext] = fileparts(fullpath);
    if strcmpi(ext, '.xlsx')
        writetable(cov_table, fullpath, 'Sheet','Покрытие_классов','WriteRowNames',true);
        writetable(trans_table, fullpath, 'Sheet','Переходы','WriteRowNames',true);
        writetable(freq_table, fullpath, 'Sheet','Частота_событий','WriteRowNames',true);
        writetable(dur_table, fullpath, 'Sheet','Длительность_событий','WriteRowNames',true);
        writetable(cov_event_table, fullpath, 'Sheet','Покрытие_событиями','WriteRowNames',true);
        writecell(info, fullpath, 'Sheet','Информация');
    else
        fid = fopen(fullpath,'w','n','utf-8');
        fprintf(fid,'=== ИНФОРМАЦИЯ ===\n');
        for i=1:size(info,1), fprintf(fid,'%s,%s\n',info{i,1},info{i,2}); end
        fprintf(fid,'\n=== ПОКРЫТИЕ КЛАССОВ (%%), среднее ===\n'); fclose(fid);
        writetable(cov_table, fullpath,'WriteMode','append','WriteRowNames',true);
        fid=fopen(fullpath,'a'); fprintf(fid,'\n=== ПЕРЕХОДЫ (%%), средняя матрица ===\n'); fclose(fid);
        writetable(trans_table, fullpath,'WriteMode','append','WriteRowNames',true);
        fid=fopen(fullpath,'a'); fprintf(fid,'\n=== ЧАСТОТА АКТИВАЦИЙ (на событие) ===\n'); fclose(fid);
        writetable(freq_table, fullpath,'WriteMode','append','WriteRowNames',true);
        fid=fopen(fullpath,'a'); fprintf(fid,'\n=== ДЛИТЕЛЬНОСТЬ АКТИВАЦИЙ (мс) ===\n'); fclose(fid);
        writetable(dur_table, fullpath,'WriteMode','append','WriteRowNames',true);
        fid=fopen(fullpath,'a'); fprintf(fid,'\n=== ПОКРЫТИЕ В ОКНЕ СОБЫТИЯ (%% времени) ===\n'); fclose(fid);
        writetable(cov_event_table, fullpath,'WriteMode','append','WriteRowNames',true);
    end
    fprintf('Сохранено: %s\n', fullpath);
end