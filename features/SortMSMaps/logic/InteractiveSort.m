function [EEGout, CurrentSet, childIdx, childEEG, com] = InteractiveSort(AllEEG, SelectedSet, Classes)
    
    EEGout = AllEEG(SelectedSet);
    CurrentSet = SelectedSet;
    childIdx = [];
    childEEG = [];
    com = '';
    
    % --- Расчет размеров окна ---
    minGridHeight = 80;     
    minGridWidth = 60;    
    expVarWidth = 55;
    nRows = numel(Classes);
    nCols = max(Classes);          
    
    screenSize = get(0, 'ScreenSize');
    
    ud.minPanelWidth = expVarWidth + minGridWidth*nCols;
    ud.minPanelHeight = minGridHeight*nRows;
    
    fig_h = figure('NumberTitle', 'off', 'Name', ['Карты микросостояний для ' AllEEG(SelectedSet).setname], ...
        'Position', screenSize, 'MenuBar', 'figure', 'ToolBar', 'none', 'Tag', 'InteractiveSort');
    
    % --- Сбор данных для отображения ---
    ud.MSMaps = AllEEG(SelectedSet).msinfo.MSMaps;
    ud.chanlocs = AllEEG(SelectedSet).chanlocs;
    ud.setname = AllEEG(SelectedSet).setname;
    ud.ClustPar = AllEEG(SelectedSet).msinfo.ClustPar;
    ud.Classes = Classes;
    ud.wasSorted = false([1 numel(Classes)]);
    ud.SelectedSet = SelectedSet;
    ud.com = '';
    if isfield(AllEEG(SelectedSet).msinfo, 'children')
        ud.Children = AllEEG(SelectedSet).msinfo.children;
    else
        ud.Children = [];
    end
    
    % Заполнение стандартных меток, если их нет
    for j = ud.Classes   
        if isfield(ud.MSMaps(j),'Labels') && ~isempty(ud.MSMaps(j).Labels)
            continue
        end 
        for k = 1:j
            ud.MSMaps(j).Labels{k} = sprintf('MS_%i.%i',j,k);
        end
    end
    
    % --- Построение интерфейса ---
    fig_h.UserData = ud;
    buildSimplifiedFig(fig_h);
    fig_h.CloseRequestFcn = {@figClose, fig_h};                            
    PlotMSMaps2(fig_h, fig_h.UserData.MapPanel, ud.MSMaps(ud.Classes), ud.chanlocs, 'ShowExpVar', 1);
    
    if ~isvalid(fig_h)
        return
    end
    
    uiwait(fig_h);
    
    if ~isvalid(fig_h)
        return
    end
    ud = fig_h.UserData;
    delete(fig_h);
    
    % --- Обработка после закрытия окна ---
    if any(ud.wasSorted)
        hasChildren = ~isempty(ud.Children);
        [yesPressed, selection] = questDlg(hasChildren);
    
        if yesPressed
            AllEEG(SelectedSet).msinfo.MSMaps = ud.MSMaps;
            EEGout = AllEEG(SelectedSet);
            EEGout.saved = 'no';
            CurrentSet = SelectedSet;
            com = ud.com;
    
            sortCom = '';
            if hasChildren            
                childIdx = FindChildSets(AllEEG, SelectedSet);
                if strcmp(selection, 'Очистить сортировку у зависимых наборов')
                    AllEEG = ClearDataSortedByParent(AllEEG, AllEEG(SelectedSet).msinfo.children);
                    childEEG = AllEEG(childIdx);
                elseif strcmp(selection, 'Отсортировать зависимые наборы по этому набору')                    
                    if ~isempty(childIdx)
                        IgnorePolarity = AllEEG(SelectedSet).msinfo.ClustPar.IgnorePolarity;
                        Classes = Classes(ud.wasSorted);
                        [~, childEEG, childIdx, sortCom] = pop_SortMSMaps(AllEEG, childIdx, 'TemplateSet', SelectedSet, ...
                            'IgnorePolarity', IgnorePolarity, 'Classes', Classes);
                    else
                        disp('Не удалось найти зависимые наборы для повторной сортировки');
                    end
                end
                for s=1:numel(childIdx)
                    childEEG(s).saved = 'no';
                end
            end
    
            if ~isempty(sortCom)
                com = [com newline sortCom];
            end
        else
            disp('Изменения отменены');
        end                
    end
end

%% УПРОЩЕННЫЙ GUI LAYOUT %%
function buildSimplifiedFig(fig_h)
    ud = fig_h.UserData;
        
    warning('off', 'MATLAB:hg:uicontrol:StringMustBeNonEmpty');
    
    % Верхняя информационная панель
    uicontrol(fig_h, 'Style', 'Text', 'String', 'Слева: GEV(Global explained variance)глобальная объясненяющая дисперсия. Подписи: индивидуальная объясненная дисперсия.', ...
        'Units', 'normalized', 'Position', [.01 .96 .98 .03], 'HorizontalAlignment', 'left');
    
    % Панель для карт
    ud.MapPanel = uipanel(fig_h, 'Position', [.01 .21 .98 .75]);
    
    % Панель управления
    panel_controls = uipanel(fig_h, 'Units', 'normalized', 'Position', [.01 .005 .88 .195]);
    
    % Выбор решения для сортировки
    uicontrol(panel_controls, 'Style', 'Text', 'String', 'Решение для сортировки', 'Units', 'normalized', 'Position', [.01 .6 .2 .33], 'HorizontalAlignment', 'left');
    AvailableClassesText = arrayfun(@(x) {sprintf('%i Классов', x)}, ud.Classes);
    ud.ClassList = uicontrol(panel_controls, 'Style', 'listbox','String', AvailableClassesText, 'Units','Normalized','Position', [.2 .05 .2 .9], 'Callback',{@solutionChanged, fig_h}, 'Min', 0, 'Max', 1);
    
    % Поля для ручной сортировки
    uicontrol(panel_controls, 'Style', 'Text', 'String', 'Порядок сортировки (минус для смены полярности)', 'Units', 'normalized', 'Position', [.45 .6 .34 .32], 'HorizontalAlignment', 'left');
    ud.OrderEdit = uicontrol(panel_controls, 'Style', 'edit', 'String', "", 'Units', 'normalized', 'Position', [.45 .45 .5 .18]);    
    
    uicontrol(panel_controls, 'Style', 'Text', 'String', 'Новые метки (через пробел)', 'Units', 'normalized', 'Position', [.45 .2 .3 .23], 'HorizontalAlignment', 'left');
    ud.LabelsEdit = uicontrol(panel_controls, 'Style', 'Edit', 'String', "", 'Units', 'normalized', 'Position', [.45 .05 .5 .18]);

    % Кнопка "Сортировать"
    uicontrol(panel_controls, 'Style', 'pushbutton', 'String', 'Сортировать', 'Units', 'normalized', 'Position', [.8 .7 .18 .25], 'Callback', {@Sort, fig_h});
    
    % Кнопка "Сохранить"
    ud.Done = uicontrol(fig_h, 'Style', 'pushbutton', 'String', 'Сохранить'  , 'Units','Normalized','Position', [.9 .005 .09 .06], 'Callback', {@figClose,fig_h});
    
    fig_h.UserData = ud;

    solutionChanged([], [], fig_h); % Вызываем для инициализации полей
end

%% УПРОЩЕННЫЙ ДИАЛОГ ВЫХОДА %%
function [yesPressed, selection] = questDlg(showOptions)
    
    yesPressed = false;
    selection = [];

    questDlg = figure('Name', 'Редактирование и сортировка', 'NumberTitle', 'off', ...
        'Color', [.9 .9 .9], 'WindowStyle', 'modal', 'MenuBar', 'none', 'ToolBar', 'none');
    questDlg.Position(3:4) = [450 150];
    movegui(questDlg, 'center');
    questDlg.UserData.yesPressed = yesPressed;
    questDlg.UserData.selection = selection;
    questDlg.CloseRequestFcn = 'uiresume()';

    uicontrol(questDlg, 'Style', 'text', 'String', 'Сохранить отсортированные карты в наборе данных?', ...
        'Units', 'normalized', 'Position', [.05 .7 .9 .15], 'FontSize', 12, 'BackgroundColor', [.9 .9 .9]);
        
    if showOptions
        questDlg.Position(4) = 190;
        questDlg.UserData.bg = uibuttongroup(questDlg, 'Units', 'normalized', 'Position', [.05 .3 .9 .4], 'BackgroundColor', [.9 .9 .9], 'BorderType', 'none', 'Title', 'Зависимые наборы данных:');
        uicontrol(questDlg.UserData.bg, 'Style', 'radiobutton', 'String', 'Отсортировать зависимые наборы по этому набору', 'Units', 'normalized', ...
            'Position', [.05 .5 .9 .4], 'BackgroundColor', [.9 .9 .9], 'FontSize', 10);
        uicontrol(questDlg.UserData.bg, 'Style', 'radiobutton', 'String', 'Очистить сортировку у зависимых наборов', 'Units', 'normalized', ...
            'Position', [.05 .1 .9 .4], 'BackgroundColor', [.9 .9 .9], 'FontSize', 10);
    end
    
    uicontrol(questDlg, 'Style', 'pushbutton', 'String', 'Да', 'Units', 'normalized', ...
        'Position', [.25 .1 .2 .17], 'Callback', {@btnPressed, questDlg});
    uicontrol(questDlg, 'Style', 'pushbutton', 'String', 'Нет', 'Units', 'normalized', ...
        'Position', [.55 .1 .2 .17], 'Callback', {@btnPressed, questDlg});

    uiwait(questDlg);

    yesPressed = questDlg.UserData.yesPressed;
    selection = questDlg.UserData.selection;

    delete(questDlg);
    
    function btnPressed(src, ~, fig)
        if strcmp(src.String, 'Да')
            fig.UserData.yesPressed = true;
        end
        if isfield(fig.UserData, 'bg') && ~isempty(fig.UserData.bg.SelectedObject)
            fig.UserData.selection = fig.UserData.bg.SelectedObject.String;
        else
            fig.UserData.selection = '';
        end
        uiresume(fig);
    end
end

%% ИСПРАВЛЕННЫЕ КОЛБЭКИ %%
function figClose(~,~,fh)
    uiresume(fh);
end

function solutionChanged(~, ~, fig)
    ud = fig.UserData;        
    nClasses = ud.Classes(ud.ClassList.Value);

    ud.OrderEdit.String = sprintf('%i ', 1:nClasses);

    letters = 'A':'Z';
    if nClasses <= numel(letters)
        ud.LabelsEdit.String = sprintf('%s ', string(arrayfun(@(x) {letters(x)}, 1:nClasses)));
    else
        ud.LabelsEdit.String = '';
    end
end

function Sort(~,~,fh)
    ud = fh.UserData;
    
    % Получаем текущие значения из полей
    nClasses = ud.Classes(ud.ClassList.Value);
    SortOrder = sscanf(ud.OrderEdit.String, '%i')';
    NewLabels = split(ud.LabelsEdit.String)';
    NewLabels = NewLabels(~cellfun(@isempty, NewLabels));

    % Выполняем сортировку напрямую через ManualSort
    SortedMaps = ManualSort(ud.MSMaps, SortOrder, NewLabels, nClasses, ud.Classes);
    
    % Обновляем данные в окне, если сортировка прошла успешно
    if ~isempty(SortedMaps)
        % Генерируем команду для истории
        NewLabelsTxt = sprintf('''%s'', ', string(NewLabels));
        NewLabelsTxt = ['{' NewLabelsTxt(1:end-2) '}'];
        if isempty(SortOrder)
            com = sprintf('[ALLEEG, EEG, CURRENTSET] = pop_SortMSMaps(ALLEEG, %i, ''Classes'', %i, ''NewLabels'', %s);', ud.SelectedSet, nClasses, NewLabelsTxt);
        else
            com = sprintf('[ALLEEG, EEG, CURRENTSET] = pop_SortMSMaps(ALLEEG, %i, ''Classes'', %i, ''SortOrder'', %s, ''NewLabels'', %s);', ud.SelectedSet, nClasses, mat2str(SortOrder), NewLabelsTxt);
        end

        % Обновляем данные в UserData окна
        fh.UserData.MSMaps = SortedMaps;
        fh.UserData.wasSorted(ismember(fh.UserData.Classes, nClasses)) = true;
        
        % Перерисовываем карты
        PlotMSMaps2(fh, ud.MapPanel, fh.UserData.MSMaps(ud.Classes), ud.chanlocs, 'ShowExpVar', 1);

        % Обновляем историю команд
        if isempty(fh.UserData.com)
            fh.UserData.com = com;
        else
            fh.UserData.com = [fh.UserData.com newline com];
        end
    end

    solutionChanged([], [], fh);    
end
