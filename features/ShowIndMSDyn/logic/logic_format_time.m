function str = logic_format_time(t_sec)
% FORMAT_TIME  Форматирует время в секундах в строку ЧЧ:ММ:СС.ммм с учётом знака.
%   Для векторов возвращает cellstr.
%
%   str = logic_format_time(t_sec)
%
% Вход:
%   t_sec - время в секундах (скаляр или вектор)
% Выход:
%   str   - строка или cellstr с отформатированным временем
%
% Примеры:
%   logic_format_time(3661.5)  -> '01:01:01.500'
%   logic_format_time(-125.3)   -> '-02:05.300'

    if nargin < 1
        str = '';
        return;
    end

    if numel(t_sec) > 1
        str = cell(size(t_sec));
        for i = 1:numel(t_sec)
            str{i} = format_time_single(t_sec(i));
        end
    else
        str = format_time_single(t_sec);
    end
end

function s = format_time_single(t)
    sign_char = '';
    if t < 0
        sign_char = '-';
        t = abs(t);
    end
    hours = floor(t / 3600);
    minutes = floor(mod(t, 3600) / 60);
    seconds = mod(t, 60);
    if hours > 0
        s = sprintf('%s%02d:%02d:%06.3f', sign_char, hours, minutes, seconds);
    elseif minutes > 0
        s = sprintf('%s%02d:%06.3f', sign_char, minutes, seconds);
    else
        s = sprintf('%s%.3f', sign_char, seconds);
    end
end