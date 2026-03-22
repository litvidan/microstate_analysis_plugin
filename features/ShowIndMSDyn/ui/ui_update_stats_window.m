function ui_update_stats_window(fig, ud)
    % Обновляет содержимое окна статистики
    table_epoch = findobj(fig, 'Tag', 'table_epoch');
    table_global = findobj(fig, 'Tag', 'table_global');
    text_cov = findobj(fig, 'Tag', 'text_cov');
    if isempty(table_epoch) || isempty(table_global) || isempty(text_cov)
        return;
    end

    % Переходы для текущей эпохи
    assign_epoch = ud.Assignment(:, ud.Segment);
    epoch_trans = logic_compute_transitions(ud.Assignment, ud.nClasses, ud.Segment);
    set(table_epoch, 'Data', arrayfun(@(x) sprintf('%.1f', x), epoch_trans, 'UniformOutput', false));
    set(table_global, 'Data', arrayfun(@(x) sprintf('%.1f', x), ud.global_transitions, 'UniformOutput', false));

    % Покрытие
    fit_epoch = ud.fit_data{ud.Segment};
    epoch_cov = zeros(1, ud.nClasses);
    total_valid = 0;
    for c = 1:ud.nClasses
        active = ~isnan(fit_epoch(c+1, :));
        epoch_cov(c) = sum(active);
        total_valid = total_valid + sum(active);
    end
    if total_valid > 0
        epoch_cov = epoch_cov / total_valid * 100;
    end

    cov_str = 'Покрытие (текущая эпоха): ';
    for c = 1:ud.nClasses
        cov_str = [cov_str, sprintf('%s: %.1f%%  ', char(64+c), epoch_cov(c))];
    end
    cov_str = [cov_str, sprintf('\nПокрытие (глобально): ')];
    for c = 1:ud.nClasses
        cov_str = [cov_str, sprintf('%s: %.1f%%  ', char(64+c), ud.global_cov(c))];
    end
    set(text_cov, 'String', cov_str);
end