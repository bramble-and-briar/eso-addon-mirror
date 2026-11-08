local localization_strings = {
  CHATIV_WARNING_CAPTION = "Обратите внимание:",
  CHATIV_WARNING_TEXT = "Поле для отображения ввода в чате отображается под окном чата. Окно чата обычно занимает всю нижнюю часть"
    .. " экрана. Если при отображении аддона окно не сдвигается вверх автоматически, нижний край окна чата необходимо сдвинуть вверх"
    .. " вручную.",
  CHATIV_VISIBLE = "Отображать поле ввода чата",
  CHATIV_VISIBLE_TOOLTIP = "Показывает или скрывает просмотрщик (область ввода чата).",
  CHATIV_MINIMISED = "Уменьшенный размер окна",
  CHATIV_MINIMISED_TOOLTIP = "Отображает окно в свернутом виде по одной строке.",
  CHATIV_FONTSIZE = "Размер шрифта",
  CHATIV_FONTSIZE_TOOLTIP = "Размер текста в поле ввода просмотрщика. Изменение этого значения также влияет на высоту окна.",
  CHATIV_WINDOWMODE = "Режим окна",
  CHATIV_WINDOWMODE_TOOLTIP = "Указывает, как определяется ширина окна.",
  CHATIV_WINDOWMODE_VAL1 = "Автоподстройка под окно чата",
  CHATIV_WINDOWMODE_VAL2 = "Фиксированная ширина",
  CHATIV_WINDOWWIDTH = "Ширина окна",
  CHATIV_WINDOWWIDTH_TOOLTIP = "Ширина окна просмотрщика.",
  CHATIV_NROFLINES = "Количество строк текста",
  CHATIV_NROFLINES_TOOLTIP = "Максимальное количество строк текста, отображаемых в окне просмотрщика. Изменение этого значения"
    .. " влияет на высоту окна.",
  CHATIV_KEYBINDING_TUGGLE = "Показать или скрыть окно",
  CHATIV_UPDATEMESSAGE_01 = "== Chat Input Viewer - Новые функции в версии 1.3.0 ==",
  CHATIV_UPDATEMESSAGE_02 = " * Новый режим «свернутый»",
  CHATIV_UPDATEMESSAGE_03 = " * Команды чата /civshow, /civhide и /civmini",
  CHATIV_UPDATEMESSAGE_04 = " * Настраиваемое сочетание клавиш для переключения режимов.",
  CHATIV_UPDATEMESSAGE_05 = "Подробности можно найти в описании дополнения на сайте USOUI: https://www.esoui.com/downloads/info4158-ChatInputViewer.html",
  CHATIV_UPDATEMESSAGE_06 = "(Это сообщение будет отображаться ещё %s раз после входа в систему.)",
}

for stringId, stringValue in pairs(localization_strings) do
  SafeAddString(_G[stringId], stringValue, 2)
end
