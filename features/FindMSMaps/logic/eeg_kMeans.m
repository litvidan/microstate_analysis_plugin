function [bestClusterCenters, bestClusterIndices, bestClusterLoadings, explainedVariance] = eeg_kMeans(inputEEGData, numberOfClusters, numberOfRestarts, maxSamplesForClustering, clusteringFlags, channelLocations)
% EEG_KMEANS выполняет кластеризацию k-средних для топографических карт ЭЭГ.
%
% function [bestClusterCenters, bestClusterIndices, bestClusterLoadings, explainedVariance] = eeg_kMeans(inputEEGData, numberOfClusters, numberOfRestarts, maxSamplesForClustering, clusteringFlags, channelLocations)
%
% Входные аргументы:
%   inputEEGData            - входные данные ЭЭГ (количество временных точек * количество каналов)
%   numberOfClusters        - количество кластеров микросостояний для извлечения
%   numberOfRestarts        - количество перезапусков алгоритма (рекомендуется около 20)
%   maxSamplesForClustering - максимальное количество временных точек ЭЭГ для кластеризации
%   clusteringFlags         - флаги для управления поведением (например, 'p' - полярность, 'n' - нормализация)
%   channelLocations        - структура с расположением каналов (используется для EMD)
%
% Выходные аргументы:
%   bestClusterCenters      - центры кластеров (топографии микросостояний)
%   bestClusterIndices      - индекс кластера для каждой временной точки
%   bestClusterLoadings     - амплитуда/корреляция назначенной карты для каждой временной точки
%   explainedVariance       - объясненная дисперсия (GEV) для модели

% --- Валидация входных данных ---
if (size(numberOfClusters,1) ~= 1) || (size(numberOfClusters,2) ~= 1)
	error('Второй аргумент (numberOfClusters) должен быть скаляром');
end

[numberOfFrames, numberOfChannels] = size(inputEEGData);

if nargin < 3 || isempty(numberOfRestarts)
    numberOfRestarts = 1;
end
if nargin < 4 || isempty(maxSamplesForClustering)
    maxSamplesForClustering = numberOfFrames;
end
if nargin < 5
    clusteringFlags = '';
end
if nargin < 6
    channelLocations = [];
end

if (maxSamplesForClustering > numberOfFrames)
    maxSamplesForClustering = numberOfFrames;
end

% --- Настройка параметров на основе флагов ---
% Флаг 'p' (polarity) указывает, что полярность должна учитываться.
considerPolarity = contains(clusteringFlags, 'p');
% Флаг '+' включает инициализацию k-means++ для более умного выбора начальных точек.
useKmeansPlusPlusInit = contains(clusteringFlags, '+');
% Флаг 'e' (emd) включает использование Earth Mover's Distance для сравнения карт.
useEarthMoversDistance = contains(clusteringFlags, 'e');
% Флаг 'n' (normalize) включает нормализацию каждой карты.
normalizeData = contains(clusteringFlags, 'n');

% --- Подготовка данных ---
% Применение среднего референта (Average Reference)
averageReferenceMatrix = eye(numberOfChannels) - (1 / numberOfChannels);
eegDataForClustering = inputEEGData * averageReferenceMatrix;
originalEEGData = eegDataForClustering; % Сохраняем копию для финальных расчетов

% Нормализация данных, если указан флаг 'n'
% Каждая карта (временная точка) будет иметь Global Field Power = 1.
if normalizeData
    eegDataForClustering = L2NormDim(eegDataForClustering, 2);
end

% --- Инициализация переменных для цикла перезапусков ---
bestFitScore = 0;
bestClusterCenters = [];
bestClusterIndices = [];
bestClusterLoadings = [];

if maxSamplesForClustering < numberOfClusters
    warning('Количество выборок (%i) меньше количества кластеров (%i). Возвращается пустой результат.', maxSamplesForClustering, numberOfClusters);
    return;
end

% --- Инициализация индикатора прогресса ---
waitbarHandle = [];
if contains(clusteringFlags, 'b') % 'b' для графического индикатора
    waitbarHandle = waitbar(0, sprintf('Вычисление %i кластеров, пожалуйста, подождите...', numberOfClusters));
else % Индикатор в консоли
    progressBarSteps = 20;
    currentProgressStep = 0;
    fprintf(1, 'Кластеризация k-means (k=%i): |', numberOfClusters);
    progressBarStringLength = fprintf(1, [repmat(' ', 1, progressBarSteps - currentProgressStep) '|   0%%']);
    tic
end


% =========================================================================
% --- Основной цикл: многократные перезапуски для поиска лучшего решения ---
% =========================================================================
for restartIndex = 1:numberOfRestarts
    % Обновление индикатора прогресса
    if isempty(waitbarHandle)
        [currentProgressStep, progressBarStringLength] = mywaitbar(restartIndex, numberOfRestarts, currentProgressStep, progressBarSteps, progressBarStringLength);
    else
        progressText = sprintf('Перезапуск: %i / %i', restartIndex, numberOfRestarts);
        set(waitbarHandle, 'Name', progressText);
        waitbar(restartIndex / numberOfRestarts, waitbarHandle);
    end

    % Создание подвыборки данных для текущего запуска, если это указано
    if maxSamplesForClustering < numberOfFrames
        randomIndices = randperm(numberOfFrames);
        currentEEGData = originalEEGData(randomIndices(1:maxSamplesForClustering), :);
        if normalizeData
             currentEEGData = L2NormDim(currentEEGData, 2);
        end
    else
        currentEEGData = eegDataForClustering;
    end
    
    currentMaxSamples = size(currentEEGData, 1);

    % --- Инициализация центроидов ---
    if useKmeansPlusPlusInit
        % Инициализация k-means++
        initialCenterIndices = nan(numberOfClusters, 1);
        % 1. Выбираем первый центр случайным образом.
        initialCenterIndices(1) = randi(currentMaxSamples, 1);
        
        for clusterCount = 2:numberOfClusters
            % 2. Для каждой точки данных вычисляем расстояние D(x) до ближайшего уже выбранного центра.
            chosenCenters = currentEEGData(initialCenterIndices(1:clusterCount-1), :);
            correlationMatrix = corr(currentEEGData', chosenCenters');
            
            if considerPolarity
                % Расстояние основано на (1 - корреляция)
                distanceSquared = 2 - 2 * correlationMatrix;
            else
                % Расстояние основано на (1 - абсолютная корреляция)
                distanceSquared = 2 - 2 * abs(correlationMatrix);
            end
            
            % Находим минимальное расстояние для каждой точки до любого из выбранных центров
            minDistanceSquared = min(distanceSquared, [], 2);
            
            % 3. Выбираем новую точку данных в качестве нового центра, используя взвешенное распределение
            % вероятностей, где точка x выбирается с вероятностью, пропорциональной D(x)^2.
            samplingProbabilities = minDistanceSquared / max(minDistanceSquared);
            initialCenterIndices(clusterCount) = randsample(currentMaxSamples, 1, true, samplingProbabilities);
        end
    else
        % Стандартная случайная инициализация
        initialCenterIndices = randi(currentMaxSamples, numberOfClusters, 1);
    end

    currentClusterCenters = currentEEGData(initialCenterIndices, :);
    currentClusterCenters = L2NormDim(currentClusterCenters, 2) * averageReferenceMatrix; % Нормализуем начальные центры

    % --- Инициализация для итеративного процесса ---
    previousClusterIndices = zeros(currentMaxSamples, 1);
    currentClusterIndices = ones(currentMaxSamples, 1); % Начинаем с единиц, чтобы цикл выполнился хотя бы раз
    iterationCount = 0;
    convergenceLimit = 10000;

    % ---------------------------------------------------------------------
    % --- Итеративный процесс присвоения и обновления (цикл конвергенции) ---
    % ---------------------------------------------------------------------
    while iterationCount < convergenceLimit && any(previousClusterIndices ~= currentClusterIndices)
        iterationCount = iterationCount + 1;
        if iterationCount == convergenceLimit
            warning("k-Means не сошелся за %i итераций", convergenceLimit);
        end
        
        previousClusterIndices = currentClusterIndices;

        % --- Шаг 1: Присвоение (Assignment) ---
        % Присваиваем каждую точку данных ближайшему центру кластера.
        correlationMatrix = currentEEGData * currentClusterCenters';
        if useEarthMoversDistance
            if considerPolarity
                [~, currentClusterIndices] = min(EMMapDifference(double(currentEEGData), double(currentClusterCenters), channelLocations, channelLocations, false), [], 2);
            else
                [~, currentClusterIndices] = min(EMMapDifference(double(currentEEGData), double(currentClusterCenters), channelLocations, channelLocations, true), [], 2);
            end
        else
            if considerPolarity
                [~, currentClusterIndices] = max(correlationMatrix, [], 2);
            else
                [~, currentClusterIndices] = max(abs(correlationMatrix), [], 2);
            end
        end

        % --- Шаг 2: Обновление (Update) ---
        % Пересчитываем центры кластеров на основе новых присвоений.
        for clusterIndex = 1:numberOfClusters
            memberIndices = find(currentClusterIndices == clusterIndex);
            if isempty(memberIndices)
                % Если кластер опустел, повторно инициализируем его случайной выборкой, чтобы избежать ошибок.
                randomSampleIndex = randi(currentMaxSamples, 1);
                currentClusterCenters(clusterIndex, :) = currentEEGData(randomSampleIndex, :);
                continue;
            end

            clusterMemberData = currentEEGData(memberIndices, :);
            
            if considerPolarity
                % Если полярность важна, новый центр - это простое среднее его членов.
                currentClusterCenters(clusterIndex, :) = mean(clusterMemberData, 1);
            else
                % Если полярность игнорируется, новый центр - это первая главная компонента
                % его членов. Это позволяет найти доминирующую топографию независимо от знака.
                clusterDataCovariance = clusterMemberData' * clusterMemberData;
                [eigenvectors, ~] = eigs(double(clusterDataCovariance), 1);
                currentClusterCenters(clusterIndex, :) = eigenvectors(:, 1)';
            end
        end
        % Нормализуем новые центры кластеров
        currentClusterCenters = L2NormDim(currentClusterCenters, 2) * averageReferenceMatrix;
    end % --- Конец итеративного цикла ---

    % --- После конвергенции, вычисляем качество подгонки для этого запуска на *всех исходных* данных ---
    finalCorrelationMatrix = originalEEGData * currentClusterCenters';
    
    if useEarthMoversDistance
        if considerPolarity
            [~, finalClusterIndices] = min(EMMapDifference(double(originalEEGData), double(currentClusterCenters), channelLocations, channelLocations, false), [], 2);
            finalLoadings = zeros(size(finalClusterIndices));
            for t = 1:numel(finalClusterIndices)
                finalLoadings(t) = finalCorrelationMatrix(t, finalClusterIndices(t));
            end
        else
            [~, finalClusterIndices] = min(EMMapDifference(double(originalEEGData), double(currentClusterCenters), channelLocations, channelLocations, true), [], 2);
            finalLoadings = zeros(size(finalClusterIndices));
            for t = 1:numel(finalClusterIndices)
                finalLoadings(t) = abs(finalCorrelationMatrix(t, finalClusterIndices(t)));
            end
        end
    else
        if considerPolarity
            [finalLoadings, finalClusterIndices] = max(finalCorrelationMatrix, [], 2);
        else
            [finalLoadings, finalClusterIndices] = max(abs(finalCorrelationMatrix), [], 2);
        end
    end
 
    currentRunFitScore = sum(finalLoadings);

    % --- Сравниваем с лучшим результатом на данный момент ---
    if (currentRunFitScore > bestFitScore)
        bestFitScore = currentRunFitScore;
        bestClusterCenters = currentClusterCenters;
        bestClusterIndices = finalClusterIndices;
        bestClusterLoadings = finalLoadings;
    end    
end % --- Конец цикла перезапусков ---

% --- Финальные расчеты после всех перезапусков ---
if ~isempty(bestClusterIndices)
    % Вычисляем Глобальную Объясненную Дисперсию (GEV) для каждого кластера
    individualGEVNumerator = zeros(1, numberOfClusters);
    for clusterIndex = 1:numberOfClusters
        clusterMemberFlags = (bestClusterIndices == clusterIndex);
        if any(clusterMemberFlags)
            individualGEVNumerator(clusterIndex) = sum(bestClusterLoadings(clusterMemberFlags).^2);
        end
    end
    totalEEGVariance = sum(vecnorm(originalEEGData').^2);
    explainedVariance = individualGEVNumerator / totalEEGVariance;
else
    explainedVariance = [];
end

% --- Очистка индикатора прогресса ---
if isempty(waitbarHandle)
    mywaitbar(numberOfRestarts, numberOfRestarts, currentProgressStep, progressBarSteps, progressBarStringLength);
    fprintf('\n');
else
    close(waitbarHandle);
end

end