function tf = utils_is_dynamics_set(EEG)
% UTILS_IS_DYNAMICS_SET  Проверяет, является ли набор данных "динамическим" (уже содержит FitPar)
%
%   tf = utils_is_dynamics_set(EEG)
%
% Вход:
%   EEG - структура EEGLAB
% Выход:
%   tf  - true, если есть поле EEG.msinfo.FitPar и в нём поле Rectify
%
    tf = isfield(EEG, 'msinfo') && ...
         isstruct(EEG.msinfo) && ...
         isfield(EEG.msinfo, 'FitPar') && ...
         isfield(EEG.msinfo.FitPar, 'Rectify');
end