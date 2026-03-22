function ui_stats_window(tab)
    ud = get(tab,'UserData');
    % Проверяем, что поле stats_fig существует, является скаляром и валидным handle
    if isfield(ud, 'stats_fig') && isscalar(ud.stats_fig) && ishandle(ud.stats_fig)
        figure(ud.stats_fig);
        return;
    end

    fig = figure('Name', sprintf('Статистика: %s', get(tab,'Title')), ...
        'NumberTitle','off','MenuBar','none','ToolBar','none',...
        'Position',[200 200 500 600], 'CloseRequestFcn',{@close_stats,tab});
    ud.stats_fig = fig;
    set(tab,'UserData',ud);

    % Таблица текущей эпохи
    h_panel_epoch = uipanel(fig, 'Units','normalized','Position',[0.05 0.55 0.9 0.4],...
        'Title','Переходы (текущая эпоха)','FontSize',11);
    uitable(h_panel_epoch, 'Units','normalized','Position',[0.05 0.1 0.9 0.8],...
        'ColumnName',arrayfun(@(x) char(64+x), 1:ud.nClasses,'UniformOutput',false),...
        'RowName',arrayfun(@(x) char(64+x), 1:ud.nClasses,'UniformOutput',false),...
        'Data',zeros(ud.nClasses), 'ColumnFormat',repmat({'numeric'},1,ud.nClasses),...
        'ColumnEditable',false(1,ud.nClasses), 'ColumnWidth',repmat({50},1,ud.nClasses),...
        'FontSize',12, 'Tag','table_epoch');

    % Таблица глобально
    h_panel_global = uipanel(fig, 'Units','normalized','Position',[0.05 0.1 0.9 0.4],...
        'Title','Переходы (глобально)','FontSize',11);
    uitable(h_panel_global, 'Units','normalized','Position',[0.05 0.1 0.9 0.8],...
        'ColumnName',arrayfun(@(x) char(64+x), 1:ud.nClasses,'UniformOutput',false),...
        'RowName',arrayfun(@(x) char(64+x), 1:ud.nClasses,'UniformOutput',false),...
        'Data',ud.global_transitions, 'ColumnFormat',repmat({'numeric'},1,ud.nClasses),...
        'ColumnEditable',false(1,ud.nClasses), 'ColumnWidth',repmat({60},1,ud.nClasses),...
        'FontSize',12, 'Tag','table_global');

    % Текст покрытия
    uicontrol(fig, 'Style','text','Units','normalized','Position',[0.05 0.03 0.9 0.1],...
        'HorizontalAlignment','left','FontSize',10,'String','','Tag','text_cov');

    ui_update_stats_window(fig, ud);
end

function close_stats(src,~,tab)
    if ishandle(tab)
        ud = get(tab,'UserData');
        if isfield(ud,'stats_fig') & ishandle(ud.stats_fig) & ud.stats_fig==src
            ud.stats_fig = [];
            set(tab,'UserData',ud);
        end
    end
    delete(src);
end
