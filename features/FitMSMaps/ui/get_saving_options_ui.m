function [question, title, btn1, btn2, btn3, default_btn] = get_saving_options_ui()
    % get_saving_options_ui - Определяет UI для диалога сохранения
    question = 'Сохранить изменения в обработанных наборах?';
    title = 'Сохранение';
    btn1 = 'Сохранить';
    btn2 = 'Сохранить как...';
    btn3 = 'Отмена';
    default_btn = 'Сохранить';
end
