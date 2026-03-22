function tf = utils_does_have_children(EEG)
% UTILS_DOES_HAVE_CHILDREN  Проверяет, имеет ли набор дочерние наборы (поле children)
%
%   tf = utils_does_have_children(EEG)
%
% Вход:
%   EEG - структура EEGLAB
% Выход:
%   tf  - true, если есть поле EEG.msinfo.children (даже если оно пустое)
%
    tf = isfield(EEG, 'msinfo') && ...
         isstruct(EEG.msinfo) && ...
         isfield(EEG.msinfo, 'children');
end