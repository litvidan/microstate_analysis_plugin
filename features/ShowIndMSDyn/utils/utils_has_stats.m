function tf = utils_has_stats(EEG)
% UTILS_HAS_STATS  Проверяет, содержит ли набор EEG микростат-статистики (MSStats)
%
%   tf = utils_has_stats(EEG)
%
% Вход:
%   EEG - структура EEGLAB
% Выход:
%   tf  - true, если есть поле EEG.msinfo.MSStats, иначе false
%
    tf = isfield(EEG, 'msinfo') && ...
         isstruct(EEG.msinfo) && ...
         isfield(EEG.msinfo, 'MSStats') && ...
         ~isempty(EEG.msinfo.MSStats);
end