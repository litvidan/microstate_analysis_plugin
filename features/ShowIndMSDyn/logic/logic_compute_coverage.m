function cov = logic_compute_coverage(assign, n_classes)
% LOGIC_COMPUTE_COVERAGE  Вычисляет процент покрытия каждого класса по всем точкам (глобально)
%
%   cov = logic_compute_coverage(assign, n_classes)
%
% Вход:
%   assign    - матрица назначений классов (время × эпохи) или вектор (все точки подряд)
%   n_classes - количество классов
% Выход:
%   cov       - вектор 1×n_classes с процентами покрытия (сумма = 100, исключая точки с меткой 0)
%
    % Если assign – матрица, преобразуем в вектор
    if size(assign,2) > 1
        assign = assign(:);
    end
    valid = assign > 0;
    total_valid = sum(valid);
    if total_valid == 0
        cov = zeros(1, n_classes);
        return;
    end
    cov = zeros(1, n_classes);
    for c = 1:n_classes
        cov(c) = sum(assign == c) / total_valid * 100;
    end
end