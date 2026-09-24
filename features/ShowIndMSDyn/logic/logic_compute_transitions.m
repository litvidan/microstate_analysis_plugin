function trans = logic_compute_transitions(assign, n_classes, epoch)
% LOGIC_COMPUTE_TRANSITIONS  Вычисляет матрицу условных вероятностей переходов
%
%   trans = logic_compute_transitions(assign, n_classes)        - глобально по всем эпохам
%   trans = logic_compute_transitions(assign, n_classes, epoch) - только для указанной эпохи
%
% Вход:
%   assign    - матрица назначений классов (время × эпохи)
%   n_classes - количество классов
%   epoch     - (опционально) номер эпохи (скаляр)
% Выход:
%   trans     - матрица n_classes × n_classes, где trans(from,to) – вероятность перехода из from в to
%               (нормировано по строкам, в процентах). Диагональные элементы (задержка в том же классе) равны 0.
%
    if nargin < 3
        % глобально
        trans = zeros(n_classes);
        n_epochs = size(assign, 2);
        for ep = 1:n_epochs
            assign_ep = assign(:, ep);
            changes = find(diff(assign_ep) ~= 0);
            for i = 1:numel(changes)
                from = assign_ep(changes(i));
                to   = assign_ep(changes(i)+1);
                if from > 0 && to > 0 && from ~= to
                    trans(from, to) = trans(from, to) + 1;
                end
            end
        end
    else
        % одна эпоха
        assign_ep = assign(:, epoch);
        changes = find(diff(assign_ep) ~= 0);
        trans = zeros(n_classes);
        for i = 1:numel(changes)
            from = assign_ep(changes(i));
            to   = assign_ep(changes(i)+1);
            if from > 0 && to > 0 && from ~= to
                trans(from, to) = trans(from, to) + 1;
            end
        end
    end

    % нормировка по строкам
    for from = 1:n_classes
        total = sum(trans(from, :));
        if total > 0
            trans(from, :) = trans(from, :) / total * 100;
        end
    end
end