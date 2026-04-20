function [AllEEG, EEGout, CurrentSet, com] = pop_SortMSMaps(AllEEG, varargin)

    [~,nogui] = eegplugin_simplemicrostate;

    %% Set defaults for outputs
    com = '';
    global EEG;
    global CURRENTSET;
    EEGout = EEG;
    CurrentSet = CURRENTSET;

    guiElements = {};
    guiGeom = {};
    guiGeomV = [];

    %% Parse inputs and perform initial validation
    p = inputParser;
    p.FunctionName = 'pop_SortMSMaps';
    
    addRequired(p, 'AllEEG', @(x) validateattributes(x, {'struct'}, {}));
    addOptional(p, 'SelectedSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector', '<=', numel(AllEEG)}));
    % Остальные параметры парсим, но в GUI не используем
    addParameter(p, 'Classes', 'all');
    addParameter(p, 'SortOrder', []);
    addParameter(p, 'NewLabels', []);

    parse(p, AllEEG, varargin{:});

    SelectedSets = p.Results.SelectedSets;
    Classes = p.Results.Classes;    
    SortOrder = p.Results.SortOrder;
    NewLabels = p.Results.NewLabels;

    %% SelectedSets validation
    HasMS = arrayfun(@(x) hasMicrostates(AllEEG(x)), 1:numel(AllEEG));
    HasDyn = arrayfun(@(x) isDynamicsSet(AllEEG(x)), 1:numel(AllEEG));
    AvailableSets = find(HasMS & ~HasDyn);
    
    if isempty(AvailableSets)
        errorMessage = ['Не найдено подходящих наборов для сортировки. Используйте ' ...
            '"Выделить n микросостояний" для их создания.'];
        if isempty(SelectedSets)
            errorDialog(errorMessage, 'Ошибка сортировки карт микросостояний');
            return;
        else
            error(errorMessage);
        end
    end

    if ~isempty(SelectedSets)
        SelectedSets = unique(SelectedSets, 'stable');
        isValid = ismember(SelectedSets, AvailableSets);
        if any(~isValid)
            invalidTxt = sprintf('%i, ', SelectedSets(~isValid));
            invalidTxt = invalidTxt(1:end-2);
            error(['Следующие наборы невалидны: ' invalidTxt ...
                '. Убедитесь, что вы не выбрали пустые наборы или наборы с уже посчитанной динамикой.']);
        end
    else        
        AvailableSetnames = {AllEEG(AvailableSets).setname};
        defaultSet = find(ismember(AvailableSets, CurrentSet), 1);
        if isempty(defaultSet); defaultSet = 1; end

        guiElements = [guiElements, ....
                    {{ 'Style', 'text', 'string', 'Выберите набор для сортировки', 'FontWeight', 'bold'}} ...
                    {{ 'Style', 'listbox' , 'string', AvailableSetnames, 'Min', 0, 'Max', 1,'Value', defaultSet, 'tag','SelectedSets'}}];
        guiGeom  = [guiGeom  1 1];
        guiGeomV = [guiGeomV  1 4];
    end

    %% Prompt user to fill in remaining parameters if necessary
    if ~isempty(guiElements)
        [res,~,~,outstruct] = inputgui('geometry', guiGeom, 'geomvert', guiGeomV, 'uilist', guiElements,...
             'title','Редактирование и сортировка карт микросостояний');

        if isempty(res); return; end
        
        if isfield(outstruct, 'SelectedSets')
            SelectedSets = AvailableSets(outstruct.SelectedSets);
        end
    end

    if numel(SelectedSets) < 1
        errordlg2('Вы должны выбрать хотя бы один набор данных','Ошибка сортировки карт');
        return;
    end
    
    if numel(SelectedSets) > 1
        error('Для ручной сортировки можно выбрать только один набор данных за раз.');
    end

    %% Handle manual/interactive sort case
    classRange = AllEEG(SelectedSets).msinfo.ClustPar.MinClasses:AllEEG(SelectedSets).msinfo.ClustPar.MaxClasses;
    
    % Если переданы метки (NewLabels), это программный вызов для сортировки
    if ~isempty(NewLabels)
        if ~isnumeric(Classes)
             error('Для программной сортировки необходимо указать числовое значение для ''Classes''.');
        end
        
        SortedMaps = ManualSort(AllEEG(SelectedSets).msinfo.MSMaps, SortOrder, NewLabels, Classes, classRange);
        if isempty(SortedMaps); return; end

        AllEEG(SelectedSets).msinfo.MSMaps = SortedMaps;
        EEGout = AllEEG(SelectedSets);
        CurrentSet = SelectedSets;
    
        NewLabelsTxt = sprintf('''%s'', ', string(NewLabels));
        NewLabelsTxt = ['{' NewLabelsTxt(1:end-2) '}'];
        if isempty(SortOrder)
            com = sprintf('[ALLEEG, EEG, CURRENTSET] = pop_SortMSMaps(ALLEEG, %i, ''Classes'', %i, ''NewLabels'', %s);', SelectedSets, Classes, NewLabelsTxt);
        else
            com = sprintf('[ALLEEG, EEG, CURRENTSET] = pop_SortMSMaps(ALLEEG, %i, ''Classes'', %i, ''SortOrder'', %s, ''NewLabels'', %s);', SelectedSets, Classes, mat2str(SortOrder), NewLabelsTxt);
        end

        return;
    else
        % В противном случае - интерактивный вызов
        
        % Если количество классов не было передано как число, спрашиваем у пользователя
        if ~isnumeric(Classes)
            classChoices = arrayfun(@(x) {sprintf('%i Классов', x)}, classRange);
            [res,~,~,outstruct] = inputgui('geometry', [1 1], 'geomvert', [1 4], 'uilist', ...
                { {'Style', 'text', 'String', 'Выберите решения для отображения в окне'} ...
                  {'Style', 'listbox', 'String', classChoices, 'Min', 0, 'Max', 2, 'Value', 1:numel(classRange), 'Tag', 'Classes'}}, ...
                'title','Редактирование и сортировка карт');

            if isempty(res); return; end
            Classes = classRange(outstruct.Classes);
        end

        [EEGout, CurrentSet, childIdx, childEEG, com] = InteractiveSort(AllEEG, SelectedSets, Classes);
        global ALLEEG;
        AllEEG = ALLEEG; % Обновляем ALLEEG на случай, если пользователь что-то изменил
        AllEEG = eeg_store(AllEEG, EEGout, CurrentSet);
        if ~isempty(childIdx)
            AllEEG = eeg_store(AllEEG, childEEG, childIdx);
        end
        return;
    end
end

% --- Вспомогательные функции ---
function hasDyn = isDynamicsSet(in)
    hasDyn = false;
    if ~isfield(in,'msinfo'), return; end    
    if ~isfield(in.msinfo, 'FitPar'), return; end
    if ~isfield(in.msinfo.FitPar, 'Rectify'), return; else, hasDyn = true; end
end

function hasMS = hasMicrostates(in)
    hasMS = false;
    if ~isfield(in,'msinfo'), return; end
    if isempty(in.msinfo), return; else, hasMS = true; end
end
