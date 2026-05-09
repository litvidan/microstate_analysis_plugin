function [fig_h, com] = pop_ShowIndMSMaps(AllEEG, varargin)

    [~,nogui] = eegplugin_mcstates;    

    %% Установка значений по умолчанию для выходных данных
    com = '';
    fig_h = [];

    %% Парсинг входных данных и начальная валидация
    p = inputParser;
    p.FunctionName = 'pop_ShowIndMSMaps';
    p.StructExpand = false;

    addRequired(p, 'AllEEG',  @(x) validateattributes(x, {'struct'}, {}));
    addOptional(p, 'SelectedSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector', '<=', numel(AllEEG)}));    
    addParameter(p, 'Classes', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector'}));
    addParameter(p, 'Visible', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary', 'scalar'}));
    parse(p, AllEEG, varargin{:});

    AllEEG = p.Results.AllEEG;
    SelectedSets = p.Results.SelectedSets;
    Classes = p.Results.Classes;
    Visible = p.Results.Visible;

    if nogui && (isempty(SelectedSets) || isempty(Classes) || Visible)
        error("Эта функция требует графического интерфейса");
    end

    %% Валидация SelectedSets
    HasMS = arrayfun(@(x) hasMicrostates(AllEEG(x)), 1:numel(AllEEG));
    HasDyn = arrayfun(@(x) isDynamicsSet(AllEEG(x)), 1:numel(AllEEG));
    AvailableSets = find(HasMS & ~HasDyn);    
    if isempty(AvailableSets)
        errorMessage = ['Не найдено подходящих наборов для отрисовки. Используйте ' ...
            '"Инструменты->Выделить n микросостояний" для их создания.'];
        if matches('SelectedSets', p.UsingDefaults)
            errorDialog(errorMessage, 'Ошибка отрисовки карт микросостояний');
            return;
        else
            error(errorMessage);
        end
    end

    if ~isempty(SelectedSets)
        SelectedSets = unique(SelectedSets, 'stable');
        isValid = ismember(SelectedSets, AvailableSets);
        if any(~isValid)
            invalidSetsTxt = sprintf('%i, ', SelectedSets(~isValid));
            invalidSetsTxt = invalidSetsTxt(1:end-2);
            error(['Следующие наборы невалидны: ' invalidSetsTxt ...
                '. Убедитесь, что вы не выбрали пустые наборы, наборы с динамикой или ' ...
                'наборы без карт микросостояний.']);
        end
    else
        global CURRENTSET;
        defaultSets = find(ismember(AvailableSets, CURRENTSET));
        if isempty(defaultSets);    defaultSets = 1;    end        
        AvailableSetnames = {AllEEG(AvailableSets).setname};
        
        [res,~,~,outstruct] = inputgui('geometry', [1 1 1 1], 'geomvert', [1 1 1 4], 'uilist', ...
            {{ 'Style', 'text'    , 'string', 'Выберите наборы для отрисовки', 'FontWeight', 'bold'} ...
            { 'Style', 'text'    , 'string', 'Используйте ctrl или shift для множественного выбора'} ...
            { 'Style', 'text'    , 'string', 'Если выбрано несколько, для каждого будет создана вкладка'} ...
            { 'Style', 'listbox' , 'string', AvailableSetnames, 'Min', 0, 'Max', 2,'Value', defaultSets, 'tag','SelectedSets'}}, ...
            'title', 'Отрисовка карт микросостояний');

        if isempty(res);    return; end
        SelectedSets = AvailableSets(outstruct.SelectedSets);

        if numel(SelectedSets) < 1
            errordlg2('Вы должны выбрать хотя бы один набор данных','Ошибка отрисовки карт');
            return;
        end
    end

    SelectedEEG = AllEEG(SelectedSets);

    % Запрос у пользователя диапазона классов для отображения, если необходимо
    AllMinClasses = arrayfun(@(x) SelectedEEG(x).msinfo.ClustPar.MinClasses, 1:numel(SelectedEEG));
    AllMaxClasses = arrayfun(@(x) SelectedEEG(x).msinfo.ClustPar.MaxClasses, 1:numel(SelectedEEG));
    MinClasses = min(AllMinClasses);
    MaxClasses = max(AllMaxClasses);
    if matches('Classes', p.UsingDefaults)
        classRange = MinClasses:MaxClasses;
        classChoices = arrayfun(@(x) sprintf('%i Классов', x), classRange, 'UniformOutput', false);
        classChoices = strjoin(classChoices, '|');

        [res,~,~,outstruct] = inputgui('geometry', [1 1 1], 'geomvert', [1 1 4], 'uilist', ...
            { {'Style', 'text', 'string', 'Выберите классы для отображения'} ...
              {'Style', 'text', 'string' 'Используйте ctrl или shift для множественного выбора'} ...
              {'Style', 'listbox', 'string', classChoices, 'Min', 0, 'Max', 2, 'Value', 1:numel(classRange), 'Tag', 'Classes'}}, ...
              'title', 'Отрисовка карт микросостояний');
        
        if isempty(res); return; end

        Classes = classRange(outstruct.Classes);
    else
        if any(Classes < MinClasses) || any(Classes > MaxClasses)
            invalidClasses = Classes(or((Classes < MinClasses), (Classes > MaxClasses)));
            invalidClassesTxt = sprintf('%i, ', invalidClasses);
            invalidClassesTxt = invalidClassesTxt(1:end-2);
            error(['Следующие указанные решения для отрисовки невалидны: %s' ...
                '. Допустимые номера классов находятся в диапазоне %i-%i.'], invalidClassesTxt, MinClasses, MaxClasses);
        end
    end        

    % Расчет начального размера фигуры и необходимости прокрутки
    expVarWidth = 0;
    minGridHeight = 80;
    minGridWidth = 60;    
    tabHeight = 30;
    nRows = numel(Classes);
    nCols = max(Classes);

    % Получение доступного размера экрана
    toolkit = java.awt.Toolkit.getDefaultToolkit();
    jframe = javax.swing.JFrame;
    insets = toolkit.getScreenInsets(jframe.getGraphicsConfiguration());
    tempFig = figure('ToolBar', 'none', 'MenuBar', 'figure', 'Position', [-1000 -1000 0 0]);    
    pause(0.2);
    titleBarHeight1 = tempFig.OuterPosition(4) - tempFig.InnerPosition(4) + tempFig.OuterPosition(2) - tempFig.InnerPosition(2);
    tempFig.MenuBar = 'none';
    pause(0.2);
    titleBarHeight2 = tempFig.OuterPosition(4) - tempFig.InnerPosition(4) + tempFig.OuterPosition(2) - tempFig.InnerPosition(2);
    delete(tempFig);
    monitorPositions = get(0, 'MonitorPositions');
    if size(monitorPositions, 1) > 1
        screenSizes = arrayfun(@(x) monitorPositions(x, 3)*monitorPositions(x,4), 1:size(monitorPositions, 1));
        [~, i] = max(screenSizes);
        screenSize = monitorPositions(i, :);
    else
        screenSize = get(0, 'ScreenSize');
    end
    figSize1 = screenSize + [insets.left, insets.bottom, -insets.left-insets.right, -titleBarHeight1-insets.bottom-insets.top];
    figSize2 = screenSize + [insets.left, insets.bottom, -insets.left-insets.right, -titleBarHeight2-insets.bottom-insets.top];

    minPanelWidth = expVarWidth + minGridWidth*nCols;
    minPanelHeight = minGridHeight*nRows;

    if Visible
        figVisible = 'on';
    else
        figVisible = 'off';
    end

    Scroll = false;
    if minPanelWidth > figSize1(3) || minPanelHeight > (figSize1(4) - tabHeight)
        Scroll = true; 
        fig_h = uifigure('Name', 'Карты микросостояний', 'Units', 'pixels', ...
            'Position', figSize2, 'Visible', figVisible);
        if minPanelWidth < fig_h.Position(3)
            minPanelWidth = fig_h.Position(3) - 50;
        end
        if minPanelHeight < fig_h.Position(4) - tabHeight
            minPanelHeight = fig_h.Position(4) - tabHeight;
        end
    else
        fig_h = figure('ToolBar', 'none', 'MenuBar', 'figure', 'NumberTitle', 'off', ...
            'Name', 'Карты микросостояний', 'Position', figSize1, 'Visible', figVisible);            
    end
    gridWidth = fig_h.Position(3)/nCols;
    gridHeight = (fig_h.Position(4) - tabHeight)/nRows;            
    if gridHeight - gridWidth > 100
        heightDiff = fig_h.Position(4) - gridWidth*nRows - 200;
        fig_h.Position(2) = fig_h.Position(2) + .5*heightDiff;
        fig_h.Position(4) = gridWidth*nRows + 200;
        minPanelHeight = fig_h.Position(4) - tabHeight - 30;
    end
    tabGroup = uitabgroup(fig_h, 'Units', 'normalized', 'Position', [0 0 1 1]);

    for i=1:numel(SelectedEEG) 
        ClassRange = SelectedEEG(i).msinfo.ClustPar.MinClasses:SelectedEEG(i).msinfo.ClustPar.MaxClasses;
        plotClasses = ClassRange(ismember(ClassRange, Classes));
        if isempty(plotClasses)
            warning('%s не содержит ни одного из выбранных решений кластеризации для отрисовки, пропуск...', SelectedEEG(i).setname);
            continue;
        end
        for j = ClassRange
            if isfield(SelectedEEG(i).msinfo.MSMaps(j),'Labels')
                if ~isempty(SelectedEEG(i).msinfo.MSMaps(j).Labels)
                    continue
                end
            end 
            for k = 1:j
                SelectedEEG(i).msinfo.MSMaps(j).Labels{k} = sprintf('MS_%i.%i',j,k);
            end
        end
              
        setTab = uitab(tabGroup, 'Title', ['Карты микросостояний для ' SelectedEEG(i).setname]);
        tabGroup.SelectedTab = setTab;          
        if Scroll
            OuterPanel = uipanel(setTab, 'Units', 'normalized', 'Position', [0 0 1 1], 'BorderType', 'none');
            OuterPanel.Scrollable = 'on';
            MapPanel = uipanel(OuterPanel, 'Units', 'pixels', 'Position', [0 0 minPanelWidth minPanelHeight], 'BorderType', 'none');
        else
            MapPanel = uipanel(setTab, 'Units', 'normalized', 'Position', [0 0 1 1], 'BorderType', 'none');
        end        
        PlotMSMaps2(fig_h, MapPanel, SelectedEEG(i).msinfo.MSMaps(plotClasses), SelectedEEG(i).chanlocs, ...
            'ShowProgress', ~Visible | Scroll, 'Setname', SelectedEEG(i).setname);
    end    
    
    com = sprintf('fig_h = pop_ShowIndMSMaps(%s, %s, ''Classes'', %s, ''Visible'', %i);', inputname(1), mat2str(SelectedSets), mat2str(Classes), Visible);
end

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
