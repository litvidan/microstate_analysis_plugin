function [event_types, freq_matrix, dur_matrix, cov_matrix] = logic_compute_all_event_metrics(study_data, indices, time_from, time_to)
    % Вычисляет метрики для всех типов событий
    n_classes = study_data.n_classes;
    ud_base.Time = study_data.times;
    ud_base.nClasses = n_classes;
    ud_base.event = study_data.event;
    
    % Уникальные типы событий
    if isfield(study_data, 'event') && ~isempty(study_data.event)
        raw_types = {study_data.event.type};
        event_types = unique(cellfun(@(x) num2str(x), raw_types, 'UniformOutput', false));
    else
        event_types = {};
    end
    n_events = length(event_types);
    freq_matrix = zeros(n_events, n_classes);
    dur_matrix  = zeros(n_events, n_classes);
    cov_matrix  = zeros(n_events, n_classes);
    if n_events == 0, return; end
    
    for ev_idx = 1:n_events
        ev_type = event_types{ev_idx};
        s_freq = zeros(1, n_classes);
        s_dur  = zeros(1, n_classes);
        s_cov  = zeros(1, n_classes);
        for i = indices
            ud = ud_base;
            ud.Assignment = study_data.MSClass_all{i}(:);
            m = logic_calculate_event_metrics(ud, ev_type, time_from, time_to);
            if ~isempty(m)
                s_freq = s_freq + m(1,:);
                s_dur  = s_dur  + m(2,:);
                s_cov  = s_cov  + m(3,:);
            end
        end
        n_valid = length(indices);
        freq_matrix(ev_idx,:) = s_freq / n_valid;
        dur_matrix(ev_idx,:)  = s_dur  / n_valid;
        cov_matrix(ev_idx,:)  = s_cov  / n_valid;
    end
end