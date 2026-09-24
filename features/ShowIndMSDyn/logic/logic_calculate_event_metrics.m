function metrics = logic_calculate_event_metrics(ud, event_type, time_from, time_to)
    % Рассчитывает метрики микросостояний (частота, длительность, покрытие)
    % для заданного типа события в указанном временном окне.

    n_classes = ud.nClasses;
    metrics = zeros(3, n_classes); % 3 метрики: частота, длительность, покрытие

    if ~isfield(ud, 'event') || isempty(ud.event) || ~isfield(ud, 'Assignment')
        return; % Нет событий или данных для анализа
    end

    % --- 1. Находим индексы событий нужного типа ---
    is_numeric_type = ~isnan(str2double(event_type));
    if is_numeric_type
        numeric_event_type = str2double(event_type);
        event_indices = find(cellfun(@(c) isnumeric(c) && c == numeric_event_type, {ud.event.type}));
    else
        event_indices = find(strcmp({ud.event.type}, event_type));
    end
    
    if isempty(event_indices)
        return; % Нет событий выбранного типа
    end
    n_events = numel(event_indices);

    % --- 2. Подготовка данных для анализа на основе сэмплов ---
    % Объединяем все эпохи в одну непрерывную последовательность
    full_assignment_sequence = ud.Assignment(:);
    total_points = numel(full_assignment_sequence);
    
    % Времена событий в сэмплах (1-based)
    event_latencies_samples = [ud.event(event_indices).latency];
    
    % Интервал между сэмплами в мс
    dt = ud.Time(2) - ud.Time(1);
    srate = 1000 / dt;
    
    % Конвертируем временное окно из мс в сэмплы
    from_samples = round(time_from / 1000 * srate);
    to_samples = round(time_to / 1000 * srate);

    % --- 3. Расчет метрик ---
    total_duration_samples_per_class = zeros(1, n_classes);
    total_occurrences_per_class = zeros(1, n_classes);
    total_analyzed_samples = 0;
    
    for i = 1:n_events
        % Определяем окно анализа в сэмплах для текущего события
        window_start_sample = event_latencies_samples(i) + from_samples;
        window_end_sample = event_latencies_samples(i) + to_samples;
        
        % Ограничиваем окно границами данных
        window_start_sample = max(1, window_start_sample);
        window_end_sample = min(total_points, window_end_sample);
        
        if window_start_sample > window_end_sample
            continue;
        end
        
        sample_indices = window_start_sample:window_end_sample;
        total_analyzed_samples = total_analyzed_samples + numel(sample_indices);
        
        % Получаем последовательность микросостояний в этом окне
        window_sequence = full_assignment_sequence(sample_indices);
        
        % Рассчитываем метрики для этого окна
        for k = 1:n_classes
            class_active = (window_sequence == k);
            
            % Суммарная длительность в сэмплах
            total_duration_samples_per_class(k) = total_duration_samples_per_class(k) + sum(class_active);
            
            % Количество активаций (переходов в состояние)
            if any(class_active)
                occurrences = sum(diff([0; class_active(:)]) == 1);
                total_occurrences_per_class(k) = total_occurrences_per_class(k) + occurrences;
            end
        end
    end
    
    % --- 4. Финализация расчетов ---
    if n_events > 0
        % 1. Частота (среднее количество активаций на одно событие)
        metrics(1, :) = total_occurrences_per_class / n_events;
        
        % 2. Средняя длительность (общая длительность / общее число активаций) в мс
        total_duration_ms_per_class = total_duration_samples_per_class * dt;
        non_zero_occurrences = total_occurrences_per_class > 0;
        metrics(2, non_zero_occurrences) = total_duration_ms_per_class(non_zero_occurrences) ./ total_occurrences_per_class(non_zero_occurrences);
        
        % 3. Покрытие (процент времени в анализируемых окнах)
        if total_analyzed_samples > 0
            metrics(3, :) = (total_duration_samples_per_class / total_analyzed_samples) * 100;
        end
    end
end
