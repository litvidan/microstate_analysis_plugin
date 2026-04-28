function logic_export_study_stats(fig, template_name)
    % Экспорт данных статистики STUDY в Excel/CSV
    export_data = getappdata(fig, 'export_stats');
    if isempty(export_data)
        warndlg('Нет данных для экспорта. Сначала примените фильтры.', 'Экспорт');
        return;
    end
    
    default_name = sprintf('study_statistics_%s.xlsx', datestr(now, 'yyyymmdd_HHMMSS'));
    [file, path] = uiputfile({'*.xlsx','Excel files (*.xlsx)';'*.csv','CSV files (*.csv)'},...
        'Сохранить статистику', default_name);
    if isequal(file,0), return; end
    fullpath = fullfile(path, file);
    
    n_classes = length(export_data.coverage);
    class_names = arrayfun(@(x) char(64+x), 1:n_classes, 'UniformOutput', false);
    
    cov_tab = array2table(export_data.coverage, 'VariableNames', class_names, 'RowNames', {'Coverage (%)'});
    trans_tab = array2table(export_data.transitions, 'VariableNames', class_names, 'RowNames', class_names);
    event_tab = array2table(export_data.event_metrics, 'VariableNames', class_names, ...
        'RowNames', {'Frequency (per event)','Duration (ms)','Coverage (%)'});
    
    info = {'Parameter','Value'; 'Number of datasets',num2str(export_data.n_selected); ...
        'Template',template_name; 'Event type',export_data.event_type; ...
        'Time window (ms)',sprintf('[%d,%d]',export_data.time_window(1),export_data.time_window(2))};
    for i = 1:length(export_data.filter_info.names)
        info{end+1,1} = export_data.filter_info.names{i};
        info{end,2} = export_data.filter_info.values{i};
    end
    
    [~,~,ext] = fileparts(fullpath);
    if strcmpi(ext,'.xlsx')
        writetable(cov_tab, fullpath, 'Sheet','Coverage', 'WriteRowNames',true);
        writetable(trans_tab, fullpath, 'Sheet','Transitions', 'WriteRowNames',true);
        writetable(event_tab, fullpath, 'Sheet','EventMetrics', 'WriteRowNames',true);
        writecell(info, fullpath, 'Sheet','Info');
    else
        fid = fopen(fullpath,'w');
        fprintf(fid,'=== Information ===\n');
        for i=1:size(info,1), fprintf(fid,'%s,%s\n',info{i,1},info{i,2}); end
        fprintf(fid,'\n=== Coverage (%%)\n'); fclose(fid);
        writetable(cov_tab, fullpath, 'WriteMode','append', 'WriteRowNames',true);
        fid = fopen(fullpath,'a'); fprintf(fid,'\n=== Transitions (%%)\n'); fclose(fid);
        writetable(trans_tab, fullpath, 'WriteMode','append', 'WriteRowNames',true);
        fid = fopen(fullpath,'a'); fprintf(fid,'\n=== Event Metrics ===\n'); fclose(fid);
        writetable(event_tab, fullpath, 'WriteMode','append', 'WriteRowNames',true);
    end
    fprintf('Сохранено: %s\n', fullpath);
end