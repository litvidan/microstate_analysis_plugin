function ui_create_tab(tab_group, AllEEG, set_idx, n_classes, figSize)
    EEG = AllEEG(set_idx);
    tab = uitab(tab_group, 'Title', sprintf('%s (%i кл.)', EEG.setname, n_classes));

    % Получаем данные через логику
    ud = logic_prepare_ms_data(EEG, n_classes, AllEEG);

    % Строим интерфейс и получаем обновлённый ud с графическими handles
    ud = build_tab_ui(tab, ud, figSize);

    % Сохраняем данные окончательно
    set(tab, 'UserData', ud);
    update_display(tab);
end

function ud = build_tab_ui(tab, ud, figSize)
    if ud.showMaps
        minGridWidth = 60;
        if figSize(3)*0.98/ud.nClasses >= minGridWidth
            map_panel_width = 0.88;
            ud.MapPanel = uipanel(tab, 'Units','normalized','Position',[0.01 0.82 map_panel_width 0.15],'BorderType','none');
            ud.ax = axes(tab, 'Position',[0.05 0.25 map_panel_width-0.04 0.55]);
            minusY = 0.35; plusY = 0.52;
            % Временно сохраняем для PlotMSMaps
            set(tab, 'UserData', ud);
            PlotMSMaps(tab, ud.nClasses);
        else
            ud.ax = axes(tab, 'Position',[0.05 0.22 0.88 0.70]);
            uicontrol('Style','pushbutton','String','Карты','Units','normalized',...
                'Position',[0.94 0.64 0.05 0.15],'Callback',{@show_maps_button, ud.ChosenTemplate, ud.nClasses});
            minusY = 0.40; plusY = 0.57;
        end
    else
        ud.ax = axes(tab, 'Position',[0.05 0.22 0.88 0.70]);
        minusY = 0.40; plusY = 0.57;
    end

    % Кнопки управления
    y_pos = 0.05;
    uicontrol(tab, 'Style','pushbutton','String','|<<','Units','normalized',...
        'Position',[0.05 y_pos 0.08 0.05],'Callback',{@goto_epoch,tab,'prev'});
    ud.epochBox = uicontrol(tab, 'Style','edit','String','1','Units','normalized',...
        'Position',[0.14 y_pos 0.08 0.05],'Callback',{@goto_epoch,tab,'edit'});
    uicontrol(tab, 'Style','pushbutton','String','>>|','Units','normalized',...
        'Position',[0.23 y_pos 0.08 0.05],'Callback',{@goto_epoch,tab,'next'});
    uicontrol(tab, 'Style','pushbutton','String','Гор. зум +','Units','normalized',...
        'Position',[0.35 y_pos 0.12 0.05],'Callback',{@zoom_x,tab,-1000});
    uicontrol(tab, 'Style','pushbutton','String','Гор. зум -','Units','normalized',...
        'Position',[0.48 y_pos 0.12 0.05],'Callback',{@zoom_x,tab,1000});
    uicontrol(tab, 'Style','pushbutton','String','Статистика','Units','normalized',...
        'Position',[0.65 y_pos 0.12 0.05],'Callback',{@show_stats,tab});
    uicontrol(tab, 'Style','pushbutton','String','-','Units','normalized',...
        'Position',[0.94 minusY 0.05 0.15],'Callback',{@zoom_y,tab,1/0.75});
    uicontrol(tab, 'Style','pushbutton','String','+','Units','normalized',...
        'Position',[0.94 plusY 0.05 0.15],'Callback',{@zoom_y,tab,0.75});

    % Убедимся, что Start в пределах
    newMin = ud.Time(1);
    newMax = ud.Time(end) - ud.XRange;
    ud.Start = max(newMin, min(ud.Start, newMax));
    ud.slider = uicontrol(tab, 'Style','slider', ...
        'Min', newMin, 'Max', newMax, 'Value', ud.Start, ...
        'Units','normalized','Position',[0.05 y_pos+0.08 0.88 0.03],...
        'BackgroundColor',[0.6 0.6 0.6],'Callback',{@slider_move,tab});
    
    % Создаём объекты area (один раз)
    hold(ud.ax, 'on');
    ud.area_handles = gobjects(1, ud.nClasses+1);
    for k = 1:ud.nClasses+1
        ud.area_handles(k) = area(ud.ax, ud.Time, ud.fit_data{1}(k,:),...
            'LineStyle','none','FaceColor',ud.cmap(k,:),'ShowBaseLine','off');
    end
    line(ud.ax, [ud.Time(1) ud.Time(end)], [0 0], 'Color','k','LineWidth',0.5);
    hold(ud.ax, 'off');

    % Возвращаем обновлённый ud
end

% --- Обработчики ---
function goto_epoch(~,~,tab,mode)
    ud = get(tab,'UserData');
    if strcmp(mode,'edit')
        val = str2double(get(ud.epochBox,'String'));
        if isnan(val) || val<1 || val>ud.nSegments
            set(ud.epochBox,'String',num2str(ud.Segment));
            return;
        end
        new_ep = round(val);
    elseif strcmp(mode,'prev')
        new_ep = ud.Segment - 1;
    else % next
        new_ep = ud.Segment + 1;
    end

    if new_ep>=1 && new_ep<=ud.nSegments
        ud.Segment = new_ep;
        set(tab,'UserData',ud);
        update_display(tab);
    else
        set(ud.epochBox,'String',num2str(ud.Segment));
    end
end

function zoom_x(~,~,tab,delta)
    ud = get(tab,'UserData');
    
    total_time_range = ud.Time(end) - ud.Time(1);
    if total_time_range <= 0 % Защита от пустого диапазона
        return;
    end
    
    newXRange = ud.XRange + delta;
    
    % Минимальный зум 100мс, но не больше, чем общая длина
    min_zoom = min(100, total_time_range);
    
    % Ограничиваем XRange
    ud.XRange = max(min_zoom, min(newXRange, total_time_range));
    
    set(tab,'UserData',ud);
    update_display(tab);
end

function zoom_y(~,~,tab,factor)
    ud = get(tab,'UserData');
    ud.MaxY = ud.MaxY * factor;
    set(tab,'UserData',ud);
    update_display(tab);
end

function slider_move(~,~,tab)
    ud = get(tab,'UserData');
    % Просто сохраняем значение слайдера. update_display сделает остальное.
    ud.Start = get(ud.slider, 'Value');
    set(tab,'UserData',ud);
    update_display(tab);
end

function show_stats(~,~,tab)
    ui_stats_window(tab);   % вызов отдельного файла
end

function show_maps_button(~,~,template,nC)
    pop_ShowIndMSMaps(template,1,'Classes',nC);
end

function update_display(tab)
    ud = get(tab, 'UserData');

    % === Синхронизация слайдера с текущими параметрами ===
    total_time_range = ud.Time(end) - ud.Time(1);

    if total_time_range <= 0
        set(ud.slider, 'Enable', 'off');
        cla(ud.ax);
        title(ud.ax, sprintf('Эпоха %d: нет данных для отображения', ud.Segment));
        return;
    end

    % Проверяем, помещается ли весь график
    is_full_range = (ud.XRange >= total_time_range - eps);

    if is_full_range
        set(ud.slider, 'Enable', 'off');
        ud.XRange = total_time_range;
        ud.Start = ud.Time(1);
    else
        set(ud.slider, 'Enable', 'on');
    end

    max_start = ud.Time(end) - ud.XRange;
    if max_start < ud.Time(1)
        max_start = ud.Time(1);
    end
    
    ud.Start = max(ud.Time(1), min(ud.Start, max_start));
    
    set(ud.slider, 'Min', ud.Time(1), 'Max', max_start, 'Value', ud.Start);

    % --- Остальной код обновления графика ---
    window_start = ud.Start;
    window_end = ud.Start + ud.XRange;
    idx = ud.Time >= window_start & ud.Time <= window_end;
    t_show = ud.Time(idx);
    fit_ep = ud.fit_data{ud.Segment};
    fit_show = fit_ep(:, idx);

    if ~isfield(ud, 'area_handles') || isempty(ud.area_handles)
        error('Объекты area не инициализированы.');
    end
    for k = 1:ud.nClasses+1
        set(ud.area_handles(k), 'XData', t_show, 'YData', fit_show(k,:));
    end

    axis(ud.ax, [window_start-0.5, window_end+0.5, 0, ud.MaxY]);

    % Метки времени
    xticks = get(ud.ax, 'XTick');
    xtick_labels = arrayfun(@(x) logic_format_time(x/1000), xticks, 'UniformOutput', false);
    set(ud.ax, 'XTickLabel', xtick_labels, 'FontSize', 9);
    xlabel(ud.ax, 'Время', 'FontSize', 10);
    ylabel(ud.ax, 'GFP', 'FontSize', 10);
    title(ud.ax, sprintf('Эпоха %d из %d (%d классов)', ud.Segment, ud.nSegments, ud.nClasses));

    set(ud.epochBox, 'String', num2str(ud.Segment));

    % --- Маркеры событий ---
    if isfield(ud, 'event_lines') && ~isempty(ud.event_lines)
        delete(ud.event_lines);
        ud.event_lines = [];
    end
    if isfield(ud, 'event_texts') && ~isempty(ud.event_texts)
        delete(ud.event_texts);
        ud.event_texts = [];
    end

    nPoints = numel(ud.Time);
    dt = ud.Time(2) - ud.Time(1);
    hold(ud.ax, 'on');
    ev_lines = [];
    ev_texts = [];
    event_times = [];
    event_types = {};

    for e = 1:numel(ud.event)
        if ~isfield(ud.event(e), 'epoch')
            epoch = 1;
        else
            epoch = ud.event(e).epoch;
        end
        if epoch ~= ud.Segment
            continue;
        end
        t = (ud.event(e).latency - (ud.Segment-1) * nPoints) * dt;
        if t < window_start || t > window_end
            continue;
        end
        event_times = [event_times, t];
        if isnumeric(ud.event(e).type)
            event_types{end+1} = sprintf('%1.0i', ud.event(e).type);
        else
            event_types{end+1} = ud.event(e).type;
        end
    end

    if ~isempty(event_times)
        [sorted_times, sort_idx] = sort(event_times);
        sorted_types = event_types(sort_idx);
        grouping_threshold = 50; % мс
        groups = {};
        current_group_times = [];
        current_group_types = {};
        for i = 1:numel(sorted_times)
            if isempty(current_group_times)
                current_group_times = sorted_times(i);
                current_group_types = {sorted_types{i}};
            elseif sorted_times(i) - current_group_times(end) <= grouping_threshold
                current_group_times = [current_group_times, sorted_times(i)];
                current_group_types{end+1} = sorted_types{i};
            else
                groups{end+1} = struct('times', current_group_times, 'types', {current_group_types});
                current_group_times = sorted_times(i);
                current_group_types = {sorted_types{i}};
            end
        end
        if ~isempty(current_group_times)
            groups{end+1} = struct('times', current_group_times, 'types', {current_group_types});
        end

        y_offset = 0.05 * ud.MaxY;
        for g = 1:numel(groups)
            group_times = groups{g}.times;
            group_types = groups{g}.types;
            for i = 1:numel(group_times)
                t = group_times(i);
                line_h = plot(ud.ax, [t t], [0 ud.MaxY], '-k');
                ev_lines = [ev_lines, line_h];
                text_y = ud.MaxY + (i-1) * y_offset;
                text_h = text(ud.ax, t, text_y, group_types{i}, ...
                    'Interpreter','none','FontSize',8,...
                    'VerticalAlignment','bottom','HorizontalAlignment','center','Rotation',90);
                ev_texts = [ev_texts, text_h];
            end
        end
    end
    hold(ud.ax, 'off');
    ud.event_lines = ev_lines;
    ud.event_texts = ev_texts;

    % --- Обновление статистики, если окно открыто ---
    if isfield(ud, 'stats_fig') & ishandle(ud.stats_fig)
        ui_update_stats_window(ud.stats_fig, ud);
    end

    set(tab, 'UserData', ud);
    drawnow limitrate;
end