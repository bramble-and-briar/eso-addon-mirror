--	===============================================================================================================
--	TOM (Tamriel Online Messenger) - Reborn
--	===============================================================================================================
--	This addon serves as a continuation and upgrade for the Tamriel Online Messenger addon, offering many improvements from any previous versions.
--	A large amount of functionality has been built upon, repaired or added as unique new features for additional convenience.
--	Please review the addon website for further details & function specifics.
--
--	(c) 07/21/22 - Present
--
--	TOM Reborn coded & translated by: P5YCH3 (https://www.esoui.com/forums/member.php?u=47541)
--	===============================================================================================================

tomUI={}
local tom={}
local tomreborn={}
local TOM_REBORN_ADDON_WEBSITE = "https://www.esoui.com/downloads/info3428-TOM-TamrielOnlineMessenger-Reborn.html#info"
local TOM_REBORN_FEEDBACK_WEBSITE = "https://www.esoui.com/forums/member.php?u=47541"

tom.name="tom"
tom.version="6.4.3"
tom.isDebug=false
tom.loaded=false
tom.PlayerReady=false

local function echo(msg) CHAT_SYSTEM.primaryContainer.currentBuffer:AddMessage("|CFFFF00" .. msg) end

function tom.LoadLocalization(locKey)
	tom.LocTxt={}
	--===============================================
	--German, Deutsch, Немецкий (DE)
	--===============================================
	if string.upper(locKey)=="DE" then
		tom.locTxt={
			{"Hauptfenster ein-/ausblenden","Gildenfunktionen ein-/ausblenden","Katakomben ein-/ausblenden","Magische Nachrichten ein-/ausblenden","Spieler Scan ein-/ausblenden","ungesendete Nachrichten anzeigen"},
			"Tamriel Online Messenger (TOM) version #1 - #2 Nachrichten, #3 Empfänger - heute ist der #4. Tag meines Lebens",
			"Willkommen zurück, Du warst #1 offline",
			"Einstellungen",
			"Automatisch öffnen",
			"TOM automatisch öffnen, wenn eine wichtige Nachricht eintrifft.",
			"Verschiebbare Fenster",
			"Das TOM Hauptfenster und der Alerter sind frei verschiebbar",
			"Aufbewahrungszeiten",
			"Flüsternachrichten",	--10
			"Aufbewahrungszeit für Flüsternachrichten in Tagen",
			"Gruppennachrichten",
			"Aufbewahrungszeit für Gruppennachrichten in Tagen",
			"Gilde #1",
			"Aufbewahrungszeit für Gildennachrichten #1 in Tagen",
			"Sprachnachrichten",
			"Aufbewahrungszeit für Sagen, Brüllen und Emotes",
			"Allgemeine Zone",
			"Aufbewahrungszeit für Nachrichten in der allgemeinen Zone",
			"Deutsche Zone",	--20
			"Aufbewahrungszeit für Nachrichten der deutschsprachigen Zone (/zde)",
			"Französische Zone",
			"Aufbewahrungszeit für Nachrichten der französischsprachigen Zone (/zfr)",
			"Englische Zone",
			"Aufbewahrungszeit für Nachrichten der englischsprachigen Zone (/zen)",
			"TOM verbergen",
			"#1 verwaltete Nachrichten, #2 bekannte Empfänger",
			"Fensterhöhe",
			"Höhe des Hauptfensters in Zeilen",
			"Fensterbreite",	--30
			"Breite des Hauptfensters in Einheiten",
			"Gruppe",
			"Sprache",
			"Allgemeine Zone", --locTxt[34], locMsg(34)
			"Deutsche Zone", --locTxt[35], locMsg(35)
			"Französische Zone", --locTxt[36], locMsg(36)
			"Englische Zone", --locTxt[37], locMsg(37)
			"Du hast die Gilde \"#1\" verlassen",
			"Du bist der Gilde \"#1\" beigetreten",
			"Namen in Gilden", --locTxt[40], locMsg(40)
			"in Gilden Charakternamen (Kurzform), Accountnamen (Adresse) oder beides (Langform) anzeigen",
			{"1-Kurzform", "2-Adresse", "3-Langform"},
			"Dieser Gruppe kann nicht geantwortet werden", --locTxt[43], locMsg(43)
			"• Linksklick:\nDer aktuellen Gruppe antworten.\n\n• Rechtsklick:\nLetzte Nachrichten in Zwischenablage.", --44
			"• Linksklick:\nDie aktuelle Gruppe löschen.\n\n• Rechtsklick:\nAlarm-Popup umschalten (Bitte nicht stören).", --45
			"#1 Nachricht(en) aus Gruppe \"#2\" gelöscht",
			"Sonstiges",
			"24-Stunden Anzeige",
			"Die übliche 24-stündige Anzeige anstatt der 12-stündigen Anzeige (am/pm) benutzen",
			"Nachrichtenbehandlung",  --50
			"Aktion bei eingehenden Flüsternachrichten",
			"1-Ignorieren:\nDie eingehenden Nachrichten werden nicht gespeichert oder angezeigt.\n\n2-Speichern:\nEingehende Nachrichten werden gespeichert und angezeigt.\n\n3-Alarmieren:\nEingehende Nachrichten werden gespeichert, angezeigt und der Benutzer alarmiert (ggf. das Hauptfenster geöffnet).",
			{"1-Ignorieren", "2-Speichern/anzeigen", "3-Alarmieren"},
			"Aktion bei eingehenden Gruppennachrichten",
			"Aktion bei Nachrichten #1", --55
			"Aktion für Sagen, Brüllen und Emotes",
			"Aktion bei allgemeinen Zonennachrichten",
			"Aktion bei deutschen Zonennachrichten",
			"Aktion bei französischen Zonennachrichten",
			"Aktion bei englischen Zonennachrichten",  --locTxt[60], locMsg(60)
			"Höhe ungedockter Fenster",
			"Höhe ungedockter Fenster in Zeilen",
			"Breite ungedockter Fenster",
			"Breite ungedockter Fenster in Einheiten",
			"Interface neu laden (/reloadui)",
			"Abmelden (/logout)",
			"ESOTU verlassen (/quit)",
			"Hintergrundtransparenz in %",
			"Die aktuelle Gruppe abdocken.",
			"[Systemnachricht]", --locTxt[70], locMsg(70)
			"Herzlich willkommen, ich bin Tom!\nEs freut mich sehr, dass Du dieses AddON ausprobieren möchtest. Als erstes solltest Du vielleicht in den Einstellungen (Steuerung -> Tastenbelegung) eine Taste festlegen um mich schnell öffnen oder schliessen zu können\nViel Freude mit TOM - dem Tamriel Online Messenger",
			"Du benutzt soeben zum ersten Mal die Sprache TOMish - herzlichen Glückwunsch!\nDiese Sprache kann von Spielern ohne TOM nicht gelesen werden, benutze sie daher mit Bedacht und überwiegend in Gruppen- und/oder Gildenchats um niemanden zu belästigen. Viel Spass mit TOMish",
			{"Handel", "Handelsangebote", true, "wts", "wtb", "", "", "", "", "drogen", ""},
			"Gruppe \"#1\" deaktiviert (Magische Nachrichten verwenden, um sie wieder anzuzeigen)",
			"TOM - Magische Nachrichten",
			"Magische Nachrichten öffnen.",
			"Magische Nachrichten sind Nachrichten, welche über Suchbegriffe aus allen Kanälen herausgefiltert und in eigens hierfür bereitgestellten Gruppen angezeigt werden.\nGeben Sie bis zu 6 Wörter an, nach welchen gesucht wird, und bis zu 2 Worte, welche NICHT enthalten sein dürfen",
			"Suchworte",
			"Ausschlüsse",
			"Titel",  --80
			{"aktiv","inaktiv"},
			"Neue magische Regel hinzufügen",
			"Die aktuelle magische Regel löschen",
			"Magische Nachrichten schliessen und die Regeln auf alle Nachrichten anwenden",
			"Klicken, um den Status der Regel zu ändern",
			{"TOM - Katakomben", "Katakomben schliessen","Ziel (%t), an welches gesendet wird:","%t=Ziel, %c=Charactername, %a=Accountname, %o=Standort","Ziel-Scanner starten/schliessen","Codierung:","Seite","Linksklick=Neue Schriftrolle einfügen, Rechtsklick=Diese Schriftrolle löschen","Linksklicken um an das Ziel zu senden, Rechtsklicken zum Bereitstellen an das Gildenfenster, Mittlere Maustaste zum Senden direkt an den Chat","Klicken, um diese Schriftrolle zu bearbeiten","HIER klicken, um diese Schriftrolle zu benennen"},
			{"Seid herzlich gegrüsst, werter Freund aus Tamriel","Ich bin %c, ein Heiler aus %o - darf ich es wagen, Euch anzusprechen?","Gildennachricht;Wir müssen weiter wachsen - bitte versucht neue Seelen an unsere Feuer zu bringen","Verkauft jemand |H1:item:45192:101:50:5365:81:50:0:0:0:0:0:0:0:0:0:9:0:0:0:0:0|h|h?"},
			"Katakomben öffnen.",
			"Kein Platz zum Einfügen - die letzte Zeile dieser Seite ist nicht frei",
			{"Standard","TOMish"},  --90
			"Klicken, um die Sprache der Schriftrollen zu ändern",
			"TOM - Gildenfunktionen",
			"Gildenfunktionen schliessen",
			"nächste Gilde",
			{"Status ausgeben","zu Spieler reisen","Mail senden","Betreff flüstern","Nachricht flüstern","aus Gilde entfernen","Mail>angezeigte","Betreff>Gildenchat","Nachricht>Gildenchat"},
			"Aktion bei linker Maustaste - klicken, um eine andere Funktion für die linke Maustaste zu definieren",
			"Aktion bei rechter Maustaste - klicken, um eine andere Funktion für die rechte Maustaste zu definieren",
			"Accountnamen umschalten",
			"Anzeige aktualisieren",
			"Du bist in keiner Gilde",  --100
			{"suche",{"*ALLE","*ONLINE","*OFFLINE",},"wobei offline seit",{">","<"},{"Minuten","Stunden","Tagen","Monaten"},{"erforderlich ist","nicht erforderlich ist"}},
			"# Mitglieder angezeigt",
			"Gildenfunktionen öffnen.",
			"Betreff",
			"Spieler #1, #2(#3), #4, Account #5, in Gebiet #6, ",
			{"Aldmeri Dominion","Ebenherz-Pakt","Dolchsturz Bündnis"},
			{"Drachenritter","Magier","Nachtklinge","Templer","Nekromant"}, --locTxt[107], locMsg(107)
			"links- oder rechtsklicken, um die unten eingestellte Aktion für diese Maustaste auszuführen",
			"den Nachrichtentext entfernen",
			"Nachricht unvollständig - Betreff oder Text fehlt",  --110
			"Die Nachricht \"#2\" an \"#1\" wurde fehlerfrei versandt",
			"Die Nachricht \"#2\" an \"#1\" konnte nicht versandt werden: #3",
			{"1-Ungelesene", "2-Gelesen/Gesamt", "3-Nichts"},
			"Anzeige der Nachrichten pro Gruppe",
			"Anzeige der Nachrichtenanzahl",
			"Begrüssung anzeigen",
			"Begrüssung beim Eintritt in die Welt im Chat anzeigen",
			"Ihr könnt keine Mail an Euch selbst senden",
			"Mailbox des Empfängers ist voll",
			"Zu wenig Geld, um die Nachricht zu senden", --120
			"Spielerscan",
			"Spielerscan schliessen",
			"Liste löschen",
			{"Katakomben","Entfernen"},
			"abgedocktes Fenster verwerfen",
			"dieser Gruppe antworten",
			"TOM - nicht gesendete Nachrichten",
			"nicht gesendete Nachrichten schliessen",
			"erneut senden mit Linksklick, löschen mit Rechtsklick",
			"nicht gesendete Nachrichten öffnen", --130
			"TIM wurde nicht gefunden (muss während des Imports aktiv sein)",
			"kein Platz frei, um Daten aus TIM einzufügen",
			"#1 Schriftrollen aus TIM importiert und in den Katakomben abgelegt",
			"Beide Warteschlangen sind leer - alle Mail vesandt",
			"#1 Nachricht(en) warten noch darauf, versandt zu werden, #2 Nachricht(en) konnten nicht versandt werden",
			"Zur Alarmnachricht wechseln",
			"Automatisch zur letzten eingegangenen Nachricht wechseln, wenn diese zu einer Gruppe gehört, welche auf \"alarmieren\" steht.", --locTxt[137], locMsg(137)
			"und einem Gildenrang von",
			"mit einem Level von",
			"TOM - Clipboard", -- 140
			"Clipboard schliessen",
			"(Kapazität ca. 1024 Zeichen)",
			"Onlinesymbol anzeigen",
			"Zeigt Euren Onlinestatus in der Titelleiste, wenn dieser \"abwesend\", \"nicht stören\" oder \"offline\" ist",
			"Alerter anzeigen",
			"Zeigt ein verschiebbares Icon, um bei eingehenden Nachrichten optisch alarmieren zu können falls das Hauptfenster aktuell nicht dargestellt wird (empfohlen)",
			"Allgemeines",
			"Schriftgröße",
			"Größe der Texte in den Nachrichtenfenstern",
			"#1 Nachrichten zur Variablen \"msgdump\" ausgegeben - verlasse das Spiel um dies zu untersuchen. Die Variable wird beim nächsten Eintritt in die Welt zerstört um Speicher zu sparen.", -- 150
			"TOM wird temporär nicht mehr öffnen - auch, wenn Nachrichten auf ALARM gestellt sind (nicht stoeren).", --151
			"TOM wird auf normale Alarmbehandlung zurückgestellt", --152 --TOM is restored to normal alarm handling
			--===============================================================
			--All translation variables below this point added by P5YCH3
			--===============================================================
			"Alerter in Menüs anzeigen", --locTxt[153], locMsg(153) --New settings option for alerter bubble - Translate: Display alerter inside of menus
			"Alerter in Menüs anzeigen, einschließlich Inventar, Bank usw. (Standard: AUS)", --locTxt[154], locMsg(154) --Tooltip for the new settings option
			"Konsolenbefehle", --locTxt[155], locMsg(155) - Console Commands
			"TOM - Funktionen", --locTxt[156], locMsg(156) - TOM - Functions
			"Öffnet die TOM-Oberfläche.", --locTxt[157], locMsg(157) - Opens the TOM interface.
			"Wechseln Sie zwischen Englisch (EN), Deutsch (DE) oder Russisch (RU).", --locTxt[158], locMsg(158) - Switch between English (EN), German (DE) or Russian (RU).
			"Import von Nachrichten aus TIM (TOMs Vorgänger).", --locTxt[159], locMsg(159) - Import of messages from TIM (TOMs predecessor).
			"Überprüft die Mailwarteschlange der Gildenfunktionen.", --locTxt[160], locMsg(160) - Checks the guild functions mail queue.
			"Verlauf in SavedVariables (bei jeder Anmeldung gelöscht).", --locTxt[161], locMsg(161) - History in SavedVariables (cleared each login).
			"Druckt testweise den aktuellen Zeitstempel zum Chatten.", --locTxt[162], locMsg(162) - Prints the current timestamp to chat as a test.
			"Einen Statuscheck auf der Hauptanzeige drucken.", --locTxt[163], locMsg(163) - Print a status check to the main display.
			"Löscht den gesamten Verlauf von TOM und aktualisiert die Anzeige.", --locTxt[164], locMsg(164) - Clears all history from TOM and refreshes the display.
			"TOM - Einstellungen (Dieses Menü)", --locTxt[165], locMsg(165) - TOM - Settings (This Menu)
			"Öffnet das TOM Einstellungsfeld.", --locTxt[166], locMsg(166) - Opens the TOM settings panel.
			"• Klicken Sie hier:\nTOM-Addon-Einstellungen anzeigen.\n\n• Nachrichtendaten:\n", --locTxt[167], locMsg(167) - Bubble Tooltip
			"• Klicken Sie hier:\nTOM-Addon-Einstellungen anzeigen.", --locTxt[168], locMsg(168) - Addon Settings Button Tooltip
			"Cursor automatisch mit TOM anzeigen", --locTxt[169], locMsg(169) - New settings option to show the cursor automatically when opening TOM.
			"Zeigen Sie automatisch den Mauszeiger an, wenn Sie das TOM-Hauptfenster öffnen.", --locTxt[170], locMsg(170) - Tooltip for the cursor settings option.
			"Magic Message-Warnungen", --locTxt[171], locMsg(171) - New settings option for Magic Messages keyword alerts.
			"Zeigen Sie eine blinkende Warnung an, wenn Schlüsselwörter aus Magic Messages übereinstimmen.", --locTxt[172], locMsg(172) - Tooltip for Magic Messages keyword alerts settings option.
			"Japanische Zone", --locTxt[173], locMsg(173) - New translation values for Japanese Zone group.
			"Russische Zone", --locTxt[174], locMsg(174) - New translation values for Russian Zone group.
			"Spanische Zone", --locTxt[175], locMsg(175) - New translation values for Spanish Zone group.
			"Ausgewählte Gruppe automatisch beantworten", --locTxt[176], locMsg(176) - New settings option to toggle the TOMish bar.
			"Starten Sie sofort eine Antwort an die ausgewählte Konversationsgruppe in der Hauptschnittstelle.", --locTxt[177], locMsg(177) - New settings option to toggle the TOMish bar.
			"Klicken Sie hier, um die Chat-Sprache zwischen Common oder TOMish umzuschalten.", --locTxt[178], locMsg(178), MainWindowCoding
			{"/z","/g1","/g2","/g3","/g4","/g5","/p","/s","/y","/e"}, --locTxt[179], locMsg(179), --MainWindowChannel tooltip - /z, /g1, /g2, /g2, /g3, /g4, /g5, /p, /s, /y, /e
			"Klicken Sie hier, um den Kanal für Ihre Nachricht zu ändern.\n\n/z, /g1, /g2, /g2, /g3, /g4, /g5, /p, /s, /y, /e", --locTxt[180], locMsg(180), --MainWindowChannel
			"Während des Kampfes schließen", --locTxt[181], locMsg(181) - New settings option to close the main display during combat.
			"Schließen Sie die Hauptanzeige während des Kampfes.", --locTxt[182], locMsg(182) - New settings option to close the main display during combat - Tooltip.
			"Innerhalb von Menüs schließen", --locTxt[183], locMsg(183) - New settings option to close the main display winthin game menus.
			"Schließen Sie TOM, wenn Sie Spielmenüs anzeigen.", --locTxt[184], locMsg(184) - New settings option to close the main display winthin game menus - Tooltip.
			"Mittelklick", --locTxt[185], locMsg(185) - New settings option to decide the function of the middle mouse button on conversation channels - Text.
			"Wählen Sie aus, was passiert, wenn Sie mit der mittleren Maustaste auf eine Konversation oder einen Kanal klicken.", --locTxt[186], locMsg(186) - New settings option to decide the function of the middle mouse button on conversation channels - Tooltip.
			{"1-wählen","2-löschen"}, --locTxt[187], locMsg(187) - New settings option to decide the function of the middle mouse button on conversation channels - Dropdown. middle_Click
		}
	--===============================================
	--Russian, Russisch, Русский (RU)
	--===============================================
	elseif string.upper(locKey)=="RU" then
		tom.locTxt={
			{"TOM - Показать/Скрыть","Показать/Скрыть Функции гильдии","Показать/Скрыть Катакомбы","Показать/Скрыть Магические Сообщения","Показать/Скрыть Сканирование игрока","Показать Неотправленную Почту"},
			"Tamriel Online Messenger (TOM) версия #1 - #2 сообщений, #3 получателей - дней жизни: #4", --locTxt[2], locMsg(2)
			"С возвращением, вы были не в сети #1", --locTxt[3], locMsg(3)
			"Настройки", --locTxt[4], locMsg(4)
			"Автоматически открывать TOM",
			"Автоматически открывать TOM если получено важное сообщение.",
			"Двигать окна",
			"TOM окно и сигнализатор свободно перемещаются.",
			"Срок хранения",
			"Шепот",
			"Срок  хранения (в днях) для шепота.",
			"Группа",
			"Срок хранения (в днях) сообщений группы.",
			"Гильдия #1",
			"Срок хранения (в днях) сообщений гильдии #1.",
			"Другие сообщения",
			"Время хранения сообщений, кричит и эмоций.",
			"Общая область",
			"Срок хранения для общей области (/z).",
			"Немецкая Область",
			"Срок хранения для немецкая Область (/zde).",
			"Французская Область",
			"Срок хранения для французская Область (/zfr).",
			"Английская Область",
			"Срок хранения для английская Область (/zen).",
			"Скрыть TOM", --locTxt[26], locMsg(26)
			"#1 сообщений получено.\n#2 отправителей.",
			"Высота окна",
			"Высота главного окна в строках.",
			"Ширина окна", --locTxt[30], locMsg(30)
			"Ширина окна сообщения в единицах.",
			"Группа",
			"Сказать",
			"Область", --locTxt[34], locMsg(34)
			"Немецкая Область", --locTxt[35], locMsg(35)
			"Французский Область", --locTxt[356], locMsg(36)
			"Английский Область", --locTxt[37], locMsg(37)
			"Вы вышли из гильдии \"#1\"",
			"Вы вступили в гильдию \"#1\"",
			"Имена в гильдии", --locTxt[40], locMsg(40)
			"Отображение имен персонажей (короткая), имен учетных записей (адрес, @UserID) или оба (длинная) в функциях гильдии.",
			{"1-короткая", "2-адрес", "3-длинная"},
			"Не могу ответить этой группе.",
			"• Левая кнопка мыши:\nОтветить текущей группе.\n\n• Правая кнопка мыши:\nКопировать сообщения в буфер обмена.", --44
			"• Левая кнопка мыши:\nУдалить сообщения из текущей группы.\n\n• Правая кнопка мыши:\nПереключать TOM в режим тишины, и временно отключает оповещения.", --45
			"#1 сообщения удалены из группы #2",
			"другие настройки", --locTxt[47], locMsg(47)
			"24-часовые часы",
			"Использовать 24-часовой формат вместо 12-часового. (am/pm).",
			"Обработка сообщений",
			"Действие на входящий шепот",
			"• 1-игнорировать:\nИгнорировать входящие сообщения.\n\n• 2-хранить/показать:\nВходящие сообщения сохраняются и отображаются.\n\n• 3-уведомлять:\nВходящие сообщения сохраняются, отображаются и пользователь будет уведомлен (главное окно открывается в зависимости от ваших настроек).",
			{"1-игнорировать", "2-хранить/показать", "3-уведомлять"},
			"Действие на входящие сообщения группы",
			"действие на #1",
			"Действие на разговор, кричать или эмоцию",
			"Действие на вход. сообщения общей области", --locTxt[57], locMsg(57)
			"Действие - Немецкая Область",
			"Действие - Французская Область",
			"Действие - Английская Область",
			"Высота незакрепленного окна.",
			"Высота незакрепленного окна в строках.",
			"Ширина незакрепленного окна.",
			"Ширина незакрепленного окна в единицах.",
			"Перезагрузить интерфейс (/reloadui)",
			"Выйти в меню (/logout)",
			"Выйти из ESOTU (/quit)", --locTxt[67], locMsg(67)
			"Прозрачность фона в %",
			"Открепить текущую группу.",
			"[Системные Сообщения]", --locTxt[70], locMsg(70)
			"Привет, я TOM!\nСпасибо за использование этого аддона. Я рекомендую привязать клавишу (Управление > Addon Keybinds) для быстрого переключения TOM одним кликом.\nНадеюсь, вам понравится пользоваться TOM - Tamriel Online Messenger.",
			"Поздравляю с обучением общения в TOMish!\nTOMish это закодированный язык. TOM пользователи могут видеть как происходит декодированные в своем окне чата аддона. Функция TOMish, идеально подходит для ролевых игр или проведения личных бесед.",
			{"Торговля", "Торговые предложения", true, "wts", "wtb", "", "", "", "", "наркотики", ""},
			"Группа \"#1\" inactivated (используйте Магические Сообщения, чтобы вернуть их)",
			"TOM - Магические Сообщения",
			"Открыть Магические Сообщения.",
			"• Магические сообщения фильтруют сообщения со всех каналов, используя настраиваемые ключевые слова.\n• Вы можете выбрать до 6 слов для поиска во всех сообщениях и до 2 слов, которые можно игнорировать.", --locTxt[77], locMsg(77)
			"Ключ. слова", --locTxt[78], locMsg(78)
			"Игнор. слова", --locTxt[79], locMsg(79)
			"Заголовок", --locTxt[80], locMsg(80)
			{"вкл.","выкл."},
			"Добавить новое магическое правило.",
			"Удалить текущее правило.",
			"Закрыть окно «Магические Сообщения» и применить правила ко всем сообщениям.",
			"Нажмите, чтобы изменить состояние правила. (вкл.) - активно, (выкл.) - неактивно",
			{"TOM - Катакомбы","Закрыть Катакомбы.","Сообщения будут отправлены (%t):","%t=получатель\n%c=имя персонажа\n%a=id аккаунта\n%o=локация","Сканер игрока.","coding:","стр.","• Щелкните левой кнопкой мыши, чтобы вставить новый свиток.\n• Щелкните правой кнопкой мыши, чтобы удалить этот свиток.","• Щелкните левой кнопкой мыши, чтобы отправить.\n• Щелкните правой кнопкой мыши, чтобы отправить в функции гильдии.\n• Щелкните средней кнопкой мыши, чтобы отправить сообщение прямо в чат.","• Щелкните, чтобы изменить этот свиток.","• Щелкните здесь, чтобы назвать эту страницу."},
			{"VR16 DD LFG","WTB |H1:item:45192:101:50:5365:81:50:0:0:0:0:0:0:0:0:0:9:0:0:0:0:0|h|h","Эй, я %c. Добро пожаловать.","Члены гильдии всегда могут пригласить в гильдию своих друзей - нажмите G, а затем E чтобы пригласить их."}, --locTxt[87], locMsg(87)
			"Открыть катакомбы.",
			"Нет места для вставки. Последняя строка этой страницы не пуста.",
			{"Общий","TOMish"},
			"Нажмите, чтобы переключить метод отправки.\n\nОбщий - обычная отправка\nTOMish - отправка для клиентов TOM",
			"TOM - Функции Гильдии",
			"Закрыть Функции Гильдии.",
			"Следующая Гильдия.",
			{"статус списка","тп к игроку","отправить письмо","тема","сообщение","искл. из гильдии", "письмо выбранным","тема в чат гильдии","текст в чат гильдии"},
			"Действие левой кнопки мыши.\n\nНажмите, чтобы определить другое действие для левой кнопки мыши.",
			"Действие правой кнопки мыши.\n\nНажмите, чтобы определить другое действие для правой кнопки мыши.", --locTxt[97], locMsg(97)
			"Переключить имена учетных записей",
			"Обновить список.", --locTxt[99], locMsg(99)
			"Вы не состоите в гильдии",
			{"Выбор ",{"*ВСЕ","*ОНЛАЙН","*ОФЛАЙН",},"где офлайн",{">","<"},{"минут","часов","дней","месяцев"},{"обязательно","не обязательно"}},
			"Кол-во участников #",
			"Открыть функции гильдии.",
			"Тема",
			"Член гильдии #1, #2 (ЧП #3), #4, Аккаунт #5, В зоне #6, ",
			{"Альдмерский Доминион","Эбонхартский Пакт","Даггерфольский Ковенант"},
			{"Рыцарь-дракон","Чародей","Клинок ночи","Храмовник","Некромант"}, --locTxt[107], locMsg(107)
			"Щелкните левой или правой кнопкой мыши, чтобы выполнить предопределенное действие для этой кнопки мыши.", --locTxt[108], locMsg(108)
			"Очистить текст.",
			"Сообщение неполное - отсутствует тема или текст.",
			"Ваша почта \"#2\" к \"#1\" была успешно отправлена.",
			"Сообщение \"#2\" к \"#1\" не удалось отправить: #3",
			{"1-непрочитано", "2-непрочитано/количество", "3-ничего такого"},
			"Отображение сообщений на группу.",
			"Количество групповых сообщений",
			"Показать приветствие",
			"Отображать приветственное сообщение при входе в систему.", --locTxt[117], locMsg(117)
			"Вы не можете отправить письмо самому себе.",
			"Почтовый ящик получателя заполнен.",
			"У вас недостаточно золота, чтобы отправить это письмо.",
			"Сканер игрока",
			"Закрыть сканер.",
			"Очистить список.",
			{"катакомбы","удалить"},
			"Удалить незакрепленное окно.",
			"Ответить этой группе.",
			"TOM - Неотправленная почта", --locTxt[127], locMsg(127)
			"Закрыть неотправленную почту.",
			"Щелкните левой кнопкой мыши, чтобы отправить повторно, щелкните правой кнопкой мыши, чтобы удалить.", --locTxt[129], locMsg(129)
			"Открыть неотправленную почту.",
			"TIM не найдено (должно быть активно, чтобы начать импорт)",
			"нет места для вставки данных из TIM",
			"#1 свитки, импортированны из TIM и сохранены в Катакомбах",
			"Очередь пуста - вся почта отправлена",
			"#1 сообщение(ий) ожидают отправки, #2 сообщение(ий) не удалось отправить",
			"Предупреждающее сообщение",
			"Автоматическое переключение на последнее входящее сообщение, если для его группы установлен уровень 3 (3-уведомлять).", --locTxt[137], locMsg(137)
			"и ранг гильдии между",
			"с уровнем между",
			"TOM - Буфер Обмена",
			"Закрыть буфер обмена.",
			"(емкость 1024 символа)",
			"Показать значок онлайн",
			"Показывает ваш онлайн-статус в строке заголовка, если он установлен на \"отсутствует\", \"не беспокоить\" или \"не в сети\".",
			"Показать оповещение", --locTxt[145], locMsg(145)
			"Отображает подвижное всплывающее окно, чтобы дать вам визуальные предупреждения о входящих сообщениях, когда главное окно не отображается (рекомендуется).",
			"Общий",
			"Размер шрифта",
			"Размер символов в окнах сообщений.",
			"#1 сообщения сбрасываются в переменную \"msgdump\" - выйдите из игры, чтобы исследовать. Переменная будет уничтожена при следующем входе для экономии памяти.", --150
			"TOM переходит в режим тишины, и временно отключает оповещения. Оповещения будут заглушены, даже если в настройках обработки сообщений установлено (3-уведомлять).", --151
			"TOM переходит к нормальной обработке сообщений, и включает оповещения согласно настройкам обработки сообщений.", --152
			--===============================================================
			--All translation variables below this point added by P5YCH3
			--===============================================================
			"Отображать оповещение внутри меню", --locTxt[153], locMsg(153) - Новая опция настроек для всплывающей подсказки
			"Переключает отображение всплывающего окна оповещения в меню игры, включая инвентарь, банк, настройки игры и т.д.. (ОТКЛ. по умолчанию).", --locTxt[154], locMsg(154) - Новая опция настроек для всплывающей подсказки
			"Консольные команды", --locTxt[155], locMsg(155)
			"TOM - Функции", --locTxt[156], locMsg(156)
			"Открывает основной интерфейс TOM.", --locTxt[157], locMsg(157)
			"Переключение между английским (EN), немецким (DE) или русским (RU).", --locTxt[158], locMsg(158) - Switch between English (EN), German (DE) or Russian (RU).
			"Позволяет импортировать сообщения из TIM (предшественник TOM).", --locTxt[159], locMsg(159)
			"Проверяет очередь функций гильдии на наличие ожидающих почтовых операций..", --locTxt[160], locMsg(160)
			"Сохраняет все сообщения в сохраненных переменных (очищается при каждом входе в систему).", --locTxt[161], locMsg(161)
			"Печатает текущую метку времени для чата в качестве теста.", --locTxt[162], locMsg(162)
			"Печать проверки состояния на основной дисплей.", --locTxt[163], locMsg(163)
			"Очищает всю историю от TOM и обновляет дисплей.", --locTxt[164], locMsg(164)
			"TOM - Настройки (это меню)", --locTxt[165], locMsg(165)
			"Открывает панель настроек.", --locTxt[166], locMsg(166)
			"• Кликните сюда:\nПоказать настройки аддона TOM.\n\n• Данные сообщения:\n", --locTxt[167], locMsg(167) - Всплывающая подсказка
			"• Кликните сюда:\nПоказать настройки аддона TOM.", --locTxt[168], locMsg(168) - Подсказка кнопки настроек аддона
			"Показывать курсор автоматически с TOM", --locTxt[169], locMsg(169) - Новая опция настроек для автоматического отображения курсора при открытии TOM.
			"Автоматически отображать курсор при открытии главного окна TOM.", --locTxt[170], locMsg(170) - Подсказка для параметра настройки курсора.
			"Оповещения о Магических сообщениях", --locTxt[171], locMsg(171) - New settings option for Magic Messages keyword alerts.
			"Отображение мигающего оповещения при совпадении ключевых слов из Магических сообщений.", --locTxt[172], locMsg(172) - Tooltip for Magic Messages keyword alerts settings option.
			"Японская Область", --locTxt[173], locMsg(173) - New translation values for Japanese Zone group.
			"Русская Область", --locTxt[174], locMsg(174) - New translation values for Russian Zone group.
			"Испанская Область", --locTxt[175], locMsg(175) - New translation values for Spanish Zone group.
			"Автоматически отвечать выбранной группе", --locTxt[176], locMsg(176) - New settings option to toggle the TOMish bar.
			"Автоматически начать отвечать в выбранной группе бесед в основном интерфейсе.", --locTxt[177], locMsg(177) - New settings option to toggle the TOMish bar.
			"Нажмите, чтобы переключить язык сообщений между Common или TOMish.", --locTxt[178], locMsg(178), MainWindowCoding
			{"/z","/g1","/g2","/g3","/g4","/g5","/p","/s","/y","/e"}, --locTxt[179], locMsg(179), --MainWindowChannel tooltip - /z, /g1, /g2, /g2, /g3, /g4, /g5, /p, /s, /y, /e
			"Нажмите, чтобы изменить канал для вашего сообщения.\n\n/z, /g1, /g2, /g2, /g3, /g4, /g5, /p, /s, /y, /e", --locTxt[180], locMsg(180), --MainWindowChannel
			"Закрыть во время боя", --locTxt[181], locMsg(181) - New settings option to close the main display during combat.
			"Закройте главный дисплей во время боя.", --locTxt[182], locMsg(182) - New settings option to close the main display during combat - Tooltip.
			"Закрыть в меню", --locTxt[183], locMsg(183) - New settings option to close the main display winthin game menus.
			"Закрывайте TOM при отображении игровых меню.", --locTxt[184], locMsg(184) - New settings option to close the main display winthin game menus - Tooltip.
			"Щелчок средней кнопкой мыши", --locTxt[185], locMsg(185) - New settings option to decide the function of the middle mouse button on conversation channels - Text.
			"Выберите, что произойдет, когда вы нажмете среднюю кнопку мыши на разговор или канал.", --locTxt[186], locMsg(186) - New settings option to decide the function of the middle mouse button on conversation channels - Tooltip.
			{"1-выбирать","2-удалить"}, --locTxt[187], locMsg(187) - New settings option to decide the function of the middle mouse button on conversation channels - Dropdown. middle_Click
		}
	--===============================================
	--English, Englisch, Английский (EN)
	--===============================================
	else
		tom.locTxt={
			{"TOM - Show/Hide","Show/Hide Guild Functions","Show/Hide Catacombs","Show/Hide Magic Messages","Show/Hide Player Scan","Show Unsent Mail"},
			"Tamriel Online Messenger (TOM) version #1 - #2 messages, #3 recipients - today is the #4th day of my life", --locTxt[2], locMsg(2)
			"Welcome back, you were offline for #1", --locTxt[3], locMsg(3)
			"Settings", --locTxt[4], locMsg(4)
			"Automatically open TOM",
			"Automatically open TOM if an important message is received.",
			"Moveable windows",
			"The TOM window and the alerter are freely moveable.",
			"Retention times",
			"Whispers",
			"Retention time (days) for whispers.",
			"Party",
			"Retention time (days) for party messages.",
			"Guild #1",
			"Retention time (days) for guild messages #1.",
			"Common messages",
			"Retention time for say, yell and emote messages.",
			"Common zone",
			"Retention time for the common zone (/z).",
			"German zone",
			"Retention time for the german spoken zone (/zde).",
			"French zone",
			"Retention time for the french spoken zone (/zfr).",
			"English zone",
			"Retention time for the english spoken zone (/zen).",
			"Hide TOM", --locTxt[26], locMsg(26)
			"#1 managed messages.\n#2 known recipients.",
			"Window height",
			"Height of the main window in lines.",
			"Window width", --locTxt[30], locMsg(30)
			"Width of the message window in units.",
			"Party", --locTxt[32], locMsg(32)
			"Say", --locTxt[33], locMsg(33)
			"Common Zone", --locTxt[34], locMsg(34)
			"German Zone", --locTxt[35], locMsg(35)
			"French Zone", --locTxt[36], locMsg(36)
			"English Zone", --locTxt[37], locMsg(37)
			"You have left guild \"#1\"",
			"You have joined guild \"#1\"",
			"Names in TOM - Appearance", --locTxt[40], locMsg(40)
			"TOM Reborn can display character names (short), account names (address, @UserID) or both (long) in the main window.", --locTxt[41], locMsg(41)
			{"1-short", "2-address", "3-long"}, --locTxt[42], locMsg(42)
			"Unable to answer this group.", --locTxt[43], locMsg(43)
			"• Left Click:\nAnswer the current group.\n\n• Right Click:\nCopy messages into clipboard.", --44
			"• Left Click:\nDelete messages from the current group.\n\n• Right Click:\nToggle TOM alert popups (DND).", --45
			"#1 message(s) deleted from group #2",
			"other settings", --locTxt[47], locMsg(47)
			"24 hour clock",
			"Use the 24-hour clock display rather than the 12-hour (am/pm) display.",
			"Message handling",
			"Action on incoming whispers", --locTxt[51], locMsg(51)
			"• 1-ignore:\nIncoming messages are to be ignored.\n\n• 2-save:\nIncoming messages are saved and displayed.\n\n• 3-alert:\nIncoming messages are saved, displayed and the user will be alerted (the main window is opened dependent on your settings).", --P5YCH3
			{"1-ignore", "2-save/display", "3-alert"},
			"Action on incoming party messages",
			"action on #1",
			"Action on say, yell or emote",
			"Action on incoming common zone messages", --locTxt[57], locMsg(57)
			"Action on incoming german zone messages",
			"Action on incoming french zone messages",
			"Action on incoming english zone messages",
			"Undocked window height.",
			"Undocked window height in lines.",
			"Undocked window width.",
			"Undocked window width in units.",
			"reload the interface (/reloadui)",
			"logout (/logout)",
			"leave ESOTU (/quit)", --locTxt[67], locMsg(67)
			"Background transparency in %",
			"Undock the current group.",
			"[Core System]", --locTxt[70], locMsg(70)
			--"Hello, I'm TOM!\nThankyou for using this addon. I recommend binding a key (controls > keybindings) so you can toggle TOM with one click.\nI hope you enjoy using TOM - Tamriel Online Messenger.",
			"Hello, welcome to TOM Reborn!\nThank you for using this addon. It is highly recommended that you bind a key (controls > keybindings) so that you can access TOM quickly when required during your adventures.\nI hope you enjoy using TOM Reborn.", --P5YCH3
			"Congratulations on learning to speak TOMish!\nTOMish is a coded language that only other TOM users can see as decoded in their addon chatbox. This feature is ideal for roleplay or holding private conversations. Have fun talking TOMish",
			{"Trade", "Trade offers", true, "wts", "wtb", "", "", "", "", "drugs", ""},
			"Group \"#1\" inactivated (use magic messages to get them back)",
			"TOM - Magic Messages", --locTxt[75], locMsg(75)
			"Open Magic Messages.",
			"• Magic messages filter posts from all channels using custom keywords.\n• You can select up to 6 words to search in all messages and up to 2 words which can be omitted.", --locTxt[77], locMsg(77)
			"Keywords", --locTxt[78], locMsg(78)
			"Omit Words", --locTxt[79], locMsg(79)
			"Title", --locTxt[80], locMsg(80)
			{"active","inactive"},
			"Add a new magic rule.",
			"Delete the current rule.",
			"Close the Magic Messages window and apply the rules to all messages.",
			"Click to change the rule state.",
			{"TOM - Catacombs","Close Catacombs.","Messages will be sent to this target (%t):","%t=target\n%c=charactername\n%a=accountname\n%o=position","Player Scanner.","coding:","page","• Left click to insert a new scroll.\n• Right click to delete this scroll.","• Left click to send to target.\n• Right click to send to Guild Functions.\n• Middle click to send directly to chat.","• Click to edit this scroll.","• Click here to name this page."},
			{"VR16 DD LFG","WTB |H1:item:45192:101:50:5365:81:50:0:0:0:0:0:0:0:0:0:9:0:0:0:0:0|h|h","Hey, I'm %c. Welcome.","Members are always welcome to invite their friends to the guild - press G then E to invite them."}, --locTxt[87], locMsg(87)
			"Open Catacombs.",
			"No room to insert. The last row of this page is not empty.",
			{"Common","TOMish"}, --locTxt[90], locMsg(90)
			"Click to toggle the scroll language.", --locTxt[91], locMsg(91), tomCatacombCoding
			"TOM - Guild Functions",
			"Close Guild Functions.",
			"Next guild.",
			{"list status","travel to player","send mail","whisper subject","whisper message","dismiss from guild", "mail>selected","subject>guildchat","message>guildchat"},
			"Action for left mouse button.\n\nClick to define another action for the left mouse button.",
			"Action for right mouse button.\n\nClick to define another action for the right mouse button.", --locTxt[97], locMsg(97)
			"Toggle accountnames",
			"Refresh list.", --locTxt[99], locMsg(99)
			"You don't belong to a guild",
			{"Select ",{"*ALL","*ONLINE","*OFFLINE",},"where offline",{">","<"},{"minutes","hours","days","months"},{"is mandatory","is not mandatory"}},
			"# members displayed",
			"Open Guild Functions.",
			"subject",
			"Guildmember #1, #2(#3), #4, account #5, in zone #6, ",
			{"Aldmeri Dominion","Ebonheart Pact","Daggerfall Covenant"},
			{"Dragonknight","Sorcerer","Nightblade","Templar","Necromancer"}, --locTxt[107], locMsg(107)
			"Left or right click to execute the predefined action for this mouse button.", --locTxt[108], locMsg(108)
			"Clear text.",
			"Message incomplete - missing subject or text.",
			"Your mail \"#2\" to \"#1\" was sent successfully.",
			"The message \"#2\" to \"#1\" could not be sent: #3",
			{"1-unread", "2-unread/count", "3-nothing"}, --locTxt[113], locMsg(113)
			"Display of messages per group.",
			"Group message count", --locTxt[115], locMsg(115)
			"Display greeting",
			"Display welcome message on login.", --locTxt[117], locMsg(117)
			"You're not able to mail to yourself.",
			"Recipient's mailbox is full.",
			"You don't have enough gold to send send this mail.",
			"Player Scanner",
			"Close scanner.",
			"Clear the list.",
			{"catacombs","remove"},
			"Discard undocked window.",
			"Answer this group.",
			"TOM - Unsent Mail", --locTxt[127], locMsg(127)
			"Close unsent mail.",
			"Left click to resend, right click to delete.", --locTxt[129], locMsg(129)
			"Open unsent mail.",
			"TIM was not found (must be active to start the import)",
			"no room to insert data from TIM",
			"#1 scrolls imported from TIM and stored to the catacombs",
			"Both queues are empty - all mail sent",
			"#1 message(s) waiting to be sent, #2 message(s) could not be sent",
			"Switch to alert message", --locTxt[136], locMsg(136)
			"Auto switch to the last incoming message if its group is set to level 3 (3-alert).", --locTxt[137], locMsg(137)
			"and a guild rank between",
			"with a level between",
			"TOM - Clipboard",
			"Close clipboard.",
			"(capacity 1024 chars about)",
			"Display online icon",
			"Shows your online status within the titlebar if it is set to \"away\", \"do not disturb\" or \"offline\".",
			"Display alerter", --locTxt[145], locMsg(145)
			"Displays a moveable popup bubble to give you visual alerts for incoming messages whenever the main window is not shown (recommended).",
			"common",
			"Fontsize",
			"Size of the characters within the message windows.",
			"#1 messages dumped into variable \"msgdump\" - exit the game to investigate. The variable will be destroyed while entering the world next time to save memory", --150
			"TOM will now temporary stay closed even if messages are set to alert level 3 in the settings (3-alert).", --151
			"TOM has returned to normal alert handling.", --152
			--===============================================================
			--All translation variables below this point added by P5YCH3
			--===============================================================
			"Display alerter inside of menus", --locTxt[153], locMsg(153) - New settings option for alerter bubble
			"Toggles the display of the alerter popup within game menus including the inventory, bank, game settings, etc. (off by default).", --locTxt[154], locMsg(154) - New settings option for alerter bubble
			"Console Commands", --locTxt[155], locMsg(155)
			"TOM - Functions", --locTxt[156], locMsg(156)
			"Opens the main TOM interface.", --locTxt[157], locMsg(157)
			"Toggle between English (EN), German (DE), or Russian (RU).", --locTxt[158], locMsg(158)
			"Allows the importing of messages from TIM (TOMs predecessor).", --locTxt[159], locMsg(159)
			"Checks the guild functions queue for any pending mail operations.", --locTxt[160], locMsg(160)
			"Saves all messages in saved variables (cleared each login).", --locTxt[161], locMsg(161)
			"Prints the current timestamp to chat as a test.", --locTxt[162], locMsg(162)
			"Print a status check to the main display.", --locTxt[163], locMsg(163)
			"Clears all history from TOM and refreshes the display.", --locTxt[164], locMsg(164)
			"TOM - Settings (This Menu)", --locTxt[165], locMsg(165)
			"Opens the settings panel.", --locTxt[166], locMsg(166)
			"• Click Here:\nShow TOM addon settings.\n\n• Message Data:\n", --locTxt[167], locMsg(167) - Bubble Tooltip
			"• Click Here:\nShow TOM addon settings.", --locTxt[168], locMsg(168) - Addon Settings Button Tooltip
			"Show cursor automatically with TOM", --locTxt[169], locMsg(169) - New settings option to show the cursor automatically when opening TOM.
			"Automatically display the mouse cursor when opening the main TOM window.", --locTxt[170], locMsg(170) - Tooltip for the cursor settings option.
			"Display alerts for Magic Messages", --locTxt[171], locMsg(171) - New settings option for Magic Messages keyword alerts.
			"Display a flashing alert when keywords from Magic Messages are matched.", --locTxt[172], locMsg(172) - Tooltip for Magic Messages keyword alerts settings option.
			"Japanese Zone", --locTxt[173], locMsg(173) - New translation values for Japanese Zone group.
			"Russian Zone", --locTxt[174], locMsg(174) - New translation values for Russian Zone group.
			"Spanish Zone", --locTxt[175], locMsg(175) - New translation values for Spanish Zone group.
			"Automatically answer selected group", --locTxt[176], locMsg(176) - New settings option to toggle the TOMish bar.
			"Immediately start a reply to the chosen conversation group in the main interface.", --locTxt[177], locMsg(177) - New settings option to toggle the TOMish bar.
			"Click to toggle the message language between Common or TOMish.", --locTxt[178], locMsg(178), MainWindowCoding
			{"/z","/g1","/g2","/g3","/g4","/g5","/p","/s","/y","/e"}, --locTxt[179], locMsg(179), --MainWindowChannel tooltip - /z, /g1, /g2, /g2, /g3, /g4, /g5, /p, /s, /y, /e
			"Click to change the channel for your message.\n\n/z, /g1, /g2, /g2, /g3, /g4, /g5, /p, /s, /y, /e", --locTxt[180], locMsg(180), --MainWindowChannel
			"Close during combat", --locTxt[181], locMsg(181) - New settings option to close the main display during combat.
			"Close TOM during combat.", --locTxt[182], locMsg(182) - New settings option to close the main display during combat - Tooltip.
			"Close within menus", --locTxt[183], locMsg(183) - New settings option to close the main display winthin game menus.
			"Close TOM when viewing game menus.", --locTxt[184], locMsg(184) - New settings option to close the main display winthin game menus - Tooltip.
			"Middle-click", --locTxt[185], locMsg(185) - New settings option to decide the function of the middle mouse button on conversation channels - Text.
			"Choose what happens when you middle-click on a conversation or channel.", --locTxt[186], locMsg(186) - New settings option to decide the function of the middle mouse button on conversation channels - Tooltip.
			{"1-select","2-delete"}, --locTxt[187], locMsg(187) - New settings option to decide the function of the middle mouse button on conversation channels - Dropdown. middle_Click
		}
	end
end

function tom.zeitDisvergenz()
	local timeStamp=GetTimeStamp()
	local days=math.floor(timeStamp/tom.oneDay)
	local seconds=timeStamp-days*tom.oneDay
	local disvergenz=GetSecondsSinceMidnight()-seconds
	return disvergenz
end

function tom.timeFromMidnight(timeStamp)
	local days=math.floor(timeStamp/tom.oneDay)
	local seconds=timeStamp-days*tom.oneDay
	return seconds
end

function tom.to2string(wert)
	local swert=tostring(wert)
	if string.len(swert)<2 then swert="0"..swert end
	return swert
end

function tom.locMsg(msgKey,msgP1,msgP2,msgP3,msgP4,msgP5,msgP6)
	local temp=""
	temp=tom.locTxt[msgKey]
	if msgP1~=nil then temp=tom.msgReplace(temp,"#1",msgP1) end
	if msgP2~=nil then temp=tom.msgReplace(temp,"#2",msgP2) end
	if msgP3~=nil then temp=tom.msgReplace(temp,"#3",msgP3) end
	if msgP4~=nil then temp=tom.msgReplace(temp,"#4",msgP4) end
	if msgP5~=nil then temp=tom.msgReplace(temp,"#5",msgP5) end
	if msgP6~=nil then temp=tom.msgReplace(temp,"#6",msgP6) end
	return temp 
end

function tom.msgReplace(msgTxt,msgLit,Replacement)
	local temp=msgTxt
	local xpos=0
	if Replacement~=nil then
		repeat
			xpos = string.find(temp,msgLit)
			if xpos~=nil then
				if xpos==1 then
					temp=Replacement .. string.sub(temp,3)
				else
					temp=string.sub(temp,1,xpos-1) .. Replacement .. string.sub(temp,xpos+2)
				end
			end
		until xpos==nil
	end
	return temp
end

function tom.encodeTOMish(svar)
	local temp=""
	local looper=0
	local isInLink=0
	while looper<string.len(svar) do
		looper=looper+1
		tempc=string.sub(svar,looper,looper)
		if tempc=="|" then
			-- ist ein Link-Escapezeichen
			if isInLink==0 then
				-- kann der Beginn eines Links sein
				if string.sub(svar,looper,looper+1)=="|H" then
					isInLink=2
					temp=temp..string.sub(svar,looper,looper+1)
					looper=looper+1
				else
					-- war nur eine normale Pipe, die ohnehin nicht übersetzt wird
					temp=temp..tempc
				end
			else
				-- eines der Abschlusszeichen von zweien...
				if string.sub(svar,looper,looper+1)=="|h" then
					isInLink=isInLink-1
					temp=temp..string.sub(svar,looper,looper+1)
					looper=looper+1
				else
					-- war nur eine normale Pipe, die ohnehin nicht übersetzt wird
					temp=temp..tempc
				end
			end
		else
			-- normale encodierung
			if isInLink==0 then
				local pos=string.find(tom.code1,tempc,1,true)
				if pos then tempc=string.sub(tom.code2,pos,pos) end
			end
			temp=temp..tempc
		end
	end
	return temp
end

function tom.decodeTOMish(svar)
	local temp=""
	local looper=0
	local isInLink=0
	while looper<string.len(svar) do
		looper=looper+1
		tempc=string.sub(svar,looper,looper)
		if tempc=="|" then
			-- ist ein Link-Escapezeichen
			if isInLink==0 then
				-- kann der Beginn eines Links sein
				if string.sub(svar,looper,looper+1)=="|H" then
					isInLink=2
					temp=temp..string.sub(svar,looper,looper+1)
					looper=looper+1
				else
					-- war nur eine normale Pipe, die ohnehin nicht übersetzt wird
					temp=temp..tempc
				end
			else
				-- eines der Abschlusszeichen von zweien...
				if string.sub(svar,looper,looper+1)=="|h" then
					isInLink=isInLink-1
					temp=temp..string.sub(svar,looper,looper+1)
					looper=looper+1
				else
					-- war nur eine normale Pipe, die ohnehin nicht übersetzt wird
					temp=temp..tempc
				end
			end
		else
			-- normale encodierung
			if isInLink==0 then
				local pos=string.find(tom.code2,tempc,1,true)
				if pos then tempc=string.sub(tom.code1,pos,pos) end
			end
			temp=temp..tempc
		end
	end
	return temp
end

function tom.sendMessage(message,bPrefixed)
	local msgToSend="|c"..tom.chatcolor..message.."|r"
	if bPrefixed==true then msgToSend="|cFCFCFCTOM> |r" .. msgToSend end
	if (CHAT_SYSTEM) then CHAT_SYSTEM:AddMessage(msgToSend) end
end

function tom.sendDebugMessage(message)
	if tom.isDebug==true then
		tom.sendMessage("DEBUG> "..message,false)
	end
end

function tom.sendSystemMessage(message)
	tom.IncomingMessage(0,tom.systemCoreType,tom.systemAccount,message)
end

function tom.sendSystemStatus()
	local lifeDay=GetDiffBetweenTimeStamps(GetTimeStamp(),tom.dayofBirth)
	lifeDay=math.floor(lifeDay/tom.oneDay)+1
	tom.sendSystemMessage(tom.locMsg(2,tom.version,tom.vars.msgCount,tom.vars.personCount,lifeDay),false)
end

function tom.sendChatMessage(message,encode)
	if (CHAT_SYSTEM) then
		-- an das Chatsystem weitergeben
		local msgToSend=message
		if encode==true then
			msgToSend=tom.codeTrigger1 .. tom.encodeTOMish(message)
			if tom.vars.sentTOMish<1 then tom.sendSystemMessage(tom.locMsg(72)) end
			tom.vars.sentTOMish=tom.vars.sentTOMish+1
		end
		CHAT_SYSTEM:StartTextEntry(msgToSend)
		ZO_ChatWindowTextEntry:SetAlpha(1)
		ZO_ChatWindowTextEntryEditBox:SelectAll()
		ZO_ChatWindowTextEntryEditBox:TakeFocus()
	end
end

function tom.removeDeletedMessages()
	local Target=1
	for Looper=1,tom.vars.msgCount,1 do
		if tom.vars.msgDltd[Looper]==nil then
			if Target<Looper then
				tom.vars.msgType[Target]=tom.vars.msgType[Looper]
				tom.vars.msgFrom[Target]=tom.vars.msgFrom[Looper]
				tom.vars.msgText[Target]=tom.vars.msgText[Looper]
				tom.vars.msgTime[Target]=tom.vars.msgTime[Looper]
				tom.vars.msgRead[Target]=tom.vars.msgRead[Looper]
				tom.vars.msgDltd[Target]=tom.vars.msgDltd[Looper]
			end
			Target=Target+1
		end
	end
	local Deleted=0
	for Looper=Target,tom.vars.msgCount,1 do
		tom.vars.msgType[Looper]=nil
		tom.vars.msgFrom[Looper]=nil
		tom.vars.msgText[Looper]=nil
		tom.vars.msgTime[Looper]=nil
		tom.vars.msgRead[Looper]=nil
		tom.vars.msgDltd[Looper]=nil
		Deleted=Deleted+1
	end
	tom.vars.msgCount=Target-1
	return Deleted
end

function tom.deleteExpiredMessages()
	local temp=0
	local Expire=0
	local isNow=GetTimeStamp()
	for Looper=1,tom.vars.msgCount,1 do
		temp=tom.messageTypTranslate(tom.vars.msgType[Looper],tom.vars.msgFrom[Looper])
		if temp==tom.mmtgrp then Expire=tom.vars.mltgrp
		elseif ((temp==tom.mmtg01) or (temp==tom.mmto01)) then Expire=tom.vars.mltg[1]
		elseif ((temp==tom.mmtg02) or (temp==tom.mmto02)) then Expire=tom.vars.mltg[2]
		elseif ((temp==tom.mmtg03) or (temp==tom.mmto03)) then Expire=tom.vars.mltg[3]
		elseif ((temp==tom.mmtg04) or (temp==tom.mmto04)) then Expire=tom.vars.mltg[4]
		elseif ((temp==tom.mmtg05) or (temp==tom.mmto05)) then Expire=tom.vars.mltg[5]
		elseif temp==tom.mmtsay then Expire=tom.vars.mltsay
		elseif temp==tom.mmtzzz then Expire=tom.vars.mltzzz
		elseif temp==tom.mmtzde then Expire=tom.vars.mltzde
		elseif temp==tom.mmtzfr then Expire=tom.vars.mltzfr
		elseif temp==tom.mmtzen then Expire=tom.vars.mltzen
		--===========================================
		--P5YCH3 - Translation additions.
		--===========================================
		elseif temp==tom.mmtzjp then Expire=tom.vars.mltzjp
		elseif temp==tom.mmtzru then Expire=tom.vars.mltzru
		elseif temp==tom.mmtzes then Expire=tom.vars.mltzes
		--===========================================
		elseif temp==tom.mmtsys then Expire=tom.vars.mltsys
		else
			Expire=tom.vars.mltwsp
		end
		-- Verfallszeit in Sekunden
		Expire=Expire*tom.oneDay
		-- Verfallszeit der Nachricht
		Expire=tom.vars.msgTime[Looper]+Expire
		local willExpire=GetDiffBetweenTimeStamps(Expire,isNow)
		if willExpire<0 then
			tom.messageDelete(Looper)
		end
	end
end

function tom.messageDelete(msgNum)
	if msgNum>0 and msgNum<=tom.vars.msgCount then
		tom.vars.msgRead[msgNum]=nil
		tom.vars.msgDltd[msgNum]=true
	end
end

function tom.isLOMmessage(msgText,msgFrom,lomElement)
	local bfound=false
	if tom.vars.lom[lomElement][3]==true then
		-- Nur aktive Elemente
		-- Active items only
		local chkMsgText=string.lower(msgText)
		local chkFromText=string.lower(msgFrom)
		for looper=4,9,1 do
			if (tom.vars.lom[lomElement][looper]~="") and ((string.find(chkMsgText,tom.vars.lom[lomElement][looper],1,true)~=nil) or (string.find(chkFromText,tom.vars.lom[lomElement][looper],1,true)~=nil)) then
				bfound=true --select
			end
		end
		for looper=10,11,1 do
			if (tom.vars.lom[lomElement][looper]~="") and ((string.find(chkMsgText,tom.vars.lom[lomElement][looper],1,true)~=nil) or (string.find(chkFromText,tom.vars.lom[lomElement][looper],1,true)~=nil)) then
				bfound=false --omit
			end
		end
	end
	return bfound
end

function tom.messageAddMMT(Index)
	local temp=0
	local MMTchanged=false
	if tom.vars.msgDltd[Index]==nil then
		-- die MMT prüfen, ob ein neuer Eintrag erstellt werden muss
		-- check the MMT whether a new entry needs to be created
		temp=tom.messageTypTranslate(tom.vars.msgType[Index],tom.vars.msgFrom[Index])
		if tom.mmt[temp]==nil then
			tom.mmt[temp]={}
			tom.mmtCount=tom.mmtCount+1
			MMTchanged=true
		end
		table.insert(tom.mmt[temp],Index)
		if tom.mmt[temp].Readed==nil then tom.mmt[temp].Readed=0 end
		if tom.mmt[temp].Unreaded==nil then tom.mmt[temp].Unreaded=0 end
		-- in alle Rollen der Fenster einfügen
		-- Include in all roles of windows
		for looper=1,tom.vars.twtCount,1 do
			local twtKey=tom.windowName .. tom.to2string(looper)
			if ((tom.vars.twt[twtKey].act==true) and (temp==tom.vars.twt[twtKey].gom)) then
				-- diese GOM ist connected zur Rolle - direkt durchgeben und auf gelesen setzen
				-- this GOM is connected to the roll - pass it on directly and set it to read
				tom.vars.msgRead[Index]=nil
				local addingMessage=tom.formatRolleMsg(Index,false)
				tom.AddmsgToRolle(addingMessage,twtKey,Index)
			end
		end
		if tom.vars.msgRead[Index]==nil then tom.mmt[temp].Readed=tom.mmt[temp].Readed+1 else tom.mmt[temp].Unreaded=tom.mmt[temp].Unreaded+1 end
		-- die LOMs prüfen, ob es eine magische Nachricht ist
		-- the LOMs check if it is a magic message
		for Element=1,tom.vars.lomCount do
			local lomID=tom.mmtlom+Element-1
			if tom.isLOMmessage(tom.vars.msgText[Index],tom.vars.persons[tom.vars.msgFrom[Index]],Element)==true then
				-- die MMT prüfen, ob ein neuer Eintrag erstellt werden muss
				-- check the MMT whether a new entry needs to be created
				if tom.mmt[lomID]==nil then
					tom.mmt[lomID]={}
					tom.mmtCount=tom.mmtCount+1
					MMTchanged=true
				end
				table.insert(tom.mmt[lomID],Index)
				if tom.mmt[lomID].Readed==nil then tom.mmt[lomID].Readed=0 end
				if tom.mmt[lomID].Unreaded==nil then tom.mmt[lomID].Unreaded=0 end
				-- in alle Rollen der Fenster einfügen
				-- Include in all roles of windows
				for looper=1,tom.vars.twtCount,1 do
					local twtKey=tom.windowName .. tom.to2string(looper)
					if ((tom.vars.twt[twtKey].act==true) and (lomID==tom.vars.twt[twtKey].gom)) then
						-- diese GOM ist connected zur Rolle - direkt durchgeben und auf gelesen setzen
						-- this GOM is connected to the roll - pass it on directly and set it to read
						tom.vars.msgRead[Index]=nil
						local addingMessage=tom.formatRolleMsg(Index,false)
						tom.AddmsgToRolle(addingMessage,twtKey,Index)
					end
				end
				if tom.vars.msgRead[Index]==nil then
					tom.mmt[lomID].Readed=tom.mmt[lomID].Readed+1
					--=======================================================================
					--P5YCH3 - New function to show alerts for unread Magic Messages.
					--=======================================================================
					--Without this, the '/say' channel will not respond to alerts.
					--Prevent the alert from starting when the plugin is loaded using a new variable.
					--AddonJustStarted_Ignore_Regenerated_Messages
					if tom.vars.alerterShownForMagicMessages == true then
						if AddonJustStarted_Ignore_Regenerated_Messages == false then
							tom.alertHandler(1)
						end
					end
					--=======================================================================
				else
					tom.mmt[lomID].Unreaded=tom.mmt[lomID].Unreaded+1
					--=======================================================================
					--P5YCH3 - New function to show alerts for unread Magic Messages.
					--=======================================================================
					--Only triggers when the keywords channel is not selected.
					if tom.vars.alerterShownForMagicMessages == true then
						tom.alertHandler(1)
					end
					--=======================================================================
				end
			end
		end
	end
	return MMTchanged,temp
end

function tom.resetOverides(force)
	if force==true then
		if tom.ovrChatter==true then tom.ovrChatter=false end	
		if tom.ovrCombat==true then tom.ovrCombat=false end
		if tom.ovrStrip==true then tom.ovrStrip=false end
	else
		if ((tom.isChattering==false) and (tom.ovrChatter==true)) then tom.ovrChatter=false end	
		if ((IsUnitInCombat("player")==false) and (tom.ovrCombat==true)) then tom.ovrCombat=false end
		if ((tom.isInStrip()==false) and (tom.ovrStrip==true)) then tom.ovrStrip=false end	
	end
end

function tom.alertHandler(action)
	if action==0 then
		-- alarmierung fahren
		-- drive alarm
		if tom.alrStatus==1 then
			if tom.alrPhase==0 then
				tom.alrPhase=1
				tomAlerterBubble:SetTexture("/esoui/art/chatwindow/chat_notification_up.dds")
			else
				tom.alrPhase=0
				tomAlerterBubble:SetTexture("/esoui/art/chatwindow/chat_notification_down.dds")
			end
		end
		-- Überschreibungen löschen
		-- Delete overrides
		tom.resetOverides(false)
	elseif action==1 then
		-- alarm start
		if tom.alrStatus~=1 then
			tom.alrStatus=1
			tom.alrPhase=0
			tom.alertHandler(0)
		end
	elseif action==2 then
		-- alarm stop
		if tom.alrStatus==1 then
			tom.alrPhase=1
			tom.alertHandler(0)
			tom.alrStatus=0
		end
	elseif action==3 then
		-- alarm check
		if tom.alrStatus==1 then
			-- den Alarm stoppen, wenn das Fenster geöffnet wird
			-- stop the alarm when the window is opened
			if tom.windowState==true then
				tom.alertHandler(2)
			else
				-- Fenster öffnen anfordern, wenn eingestellt
				-- Request open window if set
				if tom.vars.openOnAlarm==true then
					-- NICHT öffnen, wenn überschrieben
					-- DO NOT open if overwritten
					if tom.overrideAlert==false then
						tom.vars.requestedWindowState=true
					end
				end
			end
		end
		tom.alertHandler(0)
	end
end

--Function to return the character name and accound ID of a guild member. - (character@account)
function tom.guildLookup(guildNo,sID)
	local temp=sID
	local guildID=GetGuildId(guildNo)
	local memberIndex=GetGuildMemberIndexFromDisplayName(guildID,sID)
	local xhasCharacter, xCharacterName=GetGuildMemberCharacterInfo(guildID,memberIndex)
	temp=tom.truncatMale(xCharacterName) .. sID
	return temp
end

--P5YCH3 - Function to return just the character name of a guild member.
function tom.guildLookup_Character_Only(guildNo,sID)
	local temp=sID
	local guildID=GetGuildId(guildNo)
	local memberIndex=GetGuildMemberIndexFromDisplayName(guildID,sID)
	local xhasCharacter, xCharacterName=GetGuildMemberCharacterInfo(guildID,memberIndex)
	temp=tom.truncatMale(xCharacterName)
	return temp
end

--P5YCH3, #MESSAGE_FEATURES
function tom.messageAdd(messageType, messageFrom, messageText, sender_account_id) --P5YCH3, Updated
	local messageFromX=tom.truncatMale(messageFrom)
	local fromDisplayNameX=sender_account_id --P5YCH3, New variable for the account ID in public channels.

  	if messageType>=CHAT_CHANNEL_GUILD_1 and messageType<=CHAT_CHANNEL_GUILD_5 then
		messageFromX=tom.guildLookup(messageType-CHAT_CHANNEL_GUILD_1+1,messageFrom)
		fromDisplayNameX = "" --P5YCH3, Prevents player account IDs from being duplicated for guild messages.
	elseif messageType>=CHAT_CHANNEL_OFFICER_1 and messageType<=CHAT_CHANNEL_OFFICER_5 then
		messageFromX=tom.guildLookup(messageType-CHAT_CHANNEL_OFFICER_1+1,messageFrom)
		fromDisplayNameX = "" --P5YCH3, Prevents player account IDs from being duplicated for guild messages.
	elseif (messageType==CHAT_CHANNEL_WHISPER) or (messageType==CHAT_CHANNEL_WHISPER_SENT) then
		fromDisplayNameX = ""
	end

	--=====================================================================================================
	--P5YCH3 - Attempt to intercept and replace any nil returns on values before they cause errors.
	--=====================================================================================================
	if messageFromX == tom.systemAccount then --Prevents the system account ID from returning a nil value.
		fromDisplayNameX = ""
		d("TOM - Reborn, account ID was [System]. Set to: ".. fromDisplayNameX)
	end

	if fromDisplayNameX == nil then --Prevents fromDisplayNameX from returning nil.
		local fromDisplayNameX = "@Unknown"
		d("TOM - Reborn, account ID was detected as nil. Set to: ".. fromDisplayNameX)
	end

	if not fromDisplayNameX then --Prevents fromDisplayNameX from returning nothing.
		local fromDisplayNameX = "@Unknown"
		d("TOM - Reborn, account ID was not found. Set to: ".. fromDisplayNameX)
	end
	--=============================================================================================

	tom.vars.msgCount=tom.vars.msgCount+1
	tom.vars.msgType[tom.vars.msgCount]=messageType
	tom.vars.msgFrom[tom.vars.msgCount]=tom.addPerson(messageFromX .. tostring(fromDisplayNameX)) --P5YCH3, Updated
	tom.vars.msgText[tom.vars.msgCount]=messageText
	tom.vars.msgTime[tom.vars.msgCount]=GetTimeStamp()
	tom.vars.msgRead[tom.vars.msgCount]=false
	tom.vars.msgDltd[tom.vars.msgCount]=nil
end

function tom.getMMTname(key)
	local temp=""
	if key~=nil then
		if ((key>0) and (key<tom.mmtgrp)) then
			if tom.vars.persons[key]~=nil then
				temp=tom.vars.persons[key]
			end
		elseif key==tom.mmtgrp then temp=tom.locMsg(32)
		elseif key==tom.mmtg01 then temp=tom.vars.Guilds[1]
		elseif key==tom.mmtg02 then temp=tom.vars.Guilds[2]
		elseif key==tom.mmtg03 then temp=tom.vars.Guilds[3]
		elseif key==tom.mmtg04 then temp=tom.vars.Guilds[4]
		elseif key==tom.mmtg05 then temp=tom.vars.Guilds[5]
		elseif key==tom.mmto01 then temp="{" .. tom.vars.Guilds[1] .. "}"
		elseif key==tom.mmto02 then temp="{" .. tom.vars.Guilds[2] .. "}"
		elseif key==tom.mmto03 then temp="{" .. tom.vars.Guilds[3] .. "}"
		elseif key==tom.mmto04 then temp="{" .. tom.vars.Guilds[4] .. "}"
		elseif key==tom.mmto05 then temp="{" .. tom.vars.Guilds[5] .. "}"
		elseif key==tom.mmtsay then temp=tom.locMsg(33)
		elseif key==tom.mmtzzz then temp=tom.locMsg(34)
		elseif key==tom.mmtzde then temp=tom.locMsg(35)
		elseif key==tom.mmtzfr then temp=tom.locMsg(36)
		elseif key==tom.mmtzen then temp=tom.locMsg(37)
		--===========================================
		--P5YCH3 - Translation additions.
		--===========================================
		elseif key==tom.mmtzjp then temp=tom.locMsg(173)
		elseif key==tom.mmtzru then temp=tom.locMsg(174)
		elseif key==tom.mmtzes then temp=tom.locMsg(175)
		--===========================================
		elseif key==tom.mmtsys then temp=tom.locMsg(70)
		elseif key>=tom.mmtlom then temp="*" .. tom.vars.lom[key-tom.mmtlom+1][1]
		end
	end
	return temp
end

function tom.messageTypTranslate(nType,msgFrom)
	local temp=0
	if nType==CHAT_CHANNEL_PARTY then temp=tom.mmtgrp
	elseif nType==CHAT_CHANNEL_GUILD_1 then temp=tom.mmtg01
	elseif nType==CHAT_CHANNEL_GUILD_2 then temp=tom.mmtg02
	elseif nType==CHAT_CHANNEL_GUILD_3 then temp=tom.mmtg03
	elseif nType==CHAT_CHANNEL_GUILD_4 then temp=tom.mmtg04
	elseif nType==CHAT_CHANNEL_GUILD_5 then temp=tom.mmtg05
	elseif nType==CHAT_CHANNEL_OFFICER_1 then temp=tom.mmto01
	elseif nType==CHAT_CHANNEL_OFFICER_2 then temp=tom.mmto02
	elseif nType==CHAT_CHANNEL_OFFICER_3 then temp=tom.mmto03
	elseif nType==CHAT_CHANNEL_OFFICER_4 then temp=tom.mmto04
	elseif nType==CHAT_CHANNEL_OFFICER_5 then temp=tom.mmto05
	elseif ((nType==CHAT_CHANNEL_SAY) or (nType==CHAT_CHANNEL_YELL) or (nType==CHAT_CHANNEL_EMOTE)) then temp=tom.mmtsay
	elseif nType==CHAT_CHANNEL_ZONE then temp=tom.mmtzzz
	elseif nType==CHAT_CHANNEL_ZONE_LANGUAGE_1 then temp=tom.mmtzen
	elseif nType==CHAT_CHANNEL_ZONE_LANGUAGE_2 then temp=tom.mmtzfr
	elseif nType==CHAT_CHANNEL_ZONE_LANGUAGE_3 then temp=tom.mmtzde
	--===========================================
	--P5YCH3 - Translation additions.
	--===========================================
	elseif nType==CHAT_CHANNEL_ZONE_LANGUAGE_4 then temp=tom.mmtzjp
	elseif nType==CHAT_CHANNEL_ZONE_LANGUAGE_5 then temp=tom.mmtzru
	elseif nType==CHAT_CHANNEL_ZONE_LANGUAGE_6 then temp=tom.mmtzes
	--===========================================
	elseif nType==tom.systemCoreType then temp=tom.mmtsys
	elseif ((nType==CHAT_CHANNEL_WHISPER) or (nType==CHAT_CHANNEL_WHISPER_SENT)) then temp=msgFrom
	end
	return temp
end

function tom.messageHandling(nType)
	local group=tom.messageTypTranslate(nType,1)
	local temp="1"
	if ((group>0) and (group<tom.mmtgrp)) then temp=tom.vars.alrwsp
	elseif group==tom.mmtgrp then temp=tom.vars.alrgrp
	elseif ((group==tom.mmtg01) or (group==tom.mmto01)) then temp=tom.vars.alrg[1]
	elseif ((group==tom.mmtg02) or (group==tom.mmto02)) then temp=tom.vars.alrg[2]
	elseif ((group==tom.mmtg03) or (group==tom.mmto03)) then temp=tom.vars.alrg[3]
	elseif ((group==tom.mmtg04) or (group==tom.mmto04)) then temp=tom.vars.alrg[4]
	elseif ((group==tom.mmtg05) or (group==tom.mmto05)) then temp=tom.vars.alrg[5]
	elseif group==tom.mmtsay then temp=tom.vars.alrsay
	elseif group==tom.mmtzzz then temp=tom.vars.alrzzz
	elseif group==tom.mmtzde then temp=tom.vars.alrzde
	elseif group==tom.mmtzfr then temp=tom.vars.alrzfr
	elseif group==tom.mmtzen then temp=tom.vars.alrzen
	--===========================================
	--P5YCH3 - Translation additions.
	--===========================================
	elseif group==tom.mmtzjp then temp=tom.vars.alrzjp
	elseif group==tom.mmtzru then temp=tom.vars.alrzru
	elseif group==tom.mmtzes then temp=tom.vars.alrzes
	--===========================================
	elseif group==tom.mmtsys then temp=tom.vars.alrsys
	end
	return string.sub(temp,1,1)
end

--P5YCH3 - New and improved function to retrieve account IDs for any public channels such as /say, /zone, /yell.. #MESSAGE_FEATURES
function tom.IncomingMessage(eventcode, messageType, messageFrom, messageText, isCustomerService, fromDisplayName) --Updated
	AddonJustStarted_Ignore_Regenerated_Messages = false --P5YCH3
--=======================================================================--
--P5YCH3 - Some new local variables.
--=======================================================================--
	local sender_account_id = fromDisplayName --P5YCH3
	local sender_account_character = tom.truncatMale(messageFrom) --P5YCH3

	if messageType>=CHAT_CHANNEL_GUILD_1 and messageType<=CHAT_CHANNEL_GUILD_5 then
		sender_account_character=tom.guildLookup_Character_Only(messageType-CHAT_CHANNEL_GUILD_1+1,messageFrom)
	elseif messageType>=CHAT_CHANNEL_OFFICER_1 and messageType<=CHAT_CHANNEL_OFFICER_5 then
		sender_account_character=tom.guildLookup_Character_Only(messageType-CHAT_CHANNEL_OFFICER_1+1,messageFrom)
	end
--=======================================================================--

	if tom.PlayerReady==true then
		-- npc ignorieren
		if (messageType~=8) and (messageType~=7) then
			-- ignorierte Nachrichten nicht beachten
			-- ignore ignored messages
			local messageHandling=tom.messageHandling(messageType)
			if messageHandling>="2" then
				-- eine verschlüsselte Nachricht entschlüsseln
				-- decrypt an encrypted message
				local msgText=messageText
				local trigger=((string.sub(messageText,1,string.len(tom.codeTrigger1))==tom.codeTrigger1) or (string.sub(messageText,1,string.len(tom.codeTrigger2))==tom.codeTrigger2))
				if trigger==true then
					msgText=tom.decodeTOMish(string.sub(msgText,string.len(tom.codeTrigger1)+1))
				end
				-- diese Nachricht speichern
				-- save this message
				tom.messageAdd(messageType,messageFrom,msgText,sender_account_id) --P5YCH3, Updated
				-- die gespeicherte Nachricht in die MMT einfügen
				-- Paste the saved message into the MMT
				local MMTchanged,MMTkey=tom.messageAddMMT(tom.vars.msgCount)
				tom.refreshUI(MMTchanged)

				if messageHandling=="3" then
					-- alarmieren
					-- alert
					tom.alertHandler(1)
					tom.activateAlertGOM(MMTkey)
				end
				if tom.vars.msgCount==1 then
					-- die erste angelegte Gruppe anklicken
					-- click on the first created group
					tom.GOMclick(1,1)
				end
			end
		end
	end
end

function tom.activateAlertGOM(MMTkey)
	if tom.vars.activateAlertgroup==true then
		if tom.hasToClose()==false then
			if tom.vars.twt[tom.windowNameMain].gom~=MMTkey then
				-- nachsehen, ob es schon ein abgedocktes Fenster gibt
				-- see if there is already an undocked window
				if tom.searchUndockedWindow(MMTkey,true)=="" then
					-- einen Click auf die GOM simulieren, wenn eine Alarmnachricht eintrifft
					-- simulate a click on the GOM when an alarm message arrives
					tom.connectGOMtoRolle(MMTkey,tom.windowNameMain)
				end
			end
		end
	end
end

function tom.rebuildMMT()
	tom.mmt=nil
	tom.mmt={}
	tom.mmtCount=0
	for Looper=1,tom.vars.msgCount,1 do
		tom.messageAddMMT(Looper)
	end
	tom.rebuildMDT()
end

function tom.rebuildMDT()
	tom.mdt=nil
	tom.mdt={}
	for Element in pairs(tom.mmt) do
		table.insert(tom.mdt, Element)
	end
	table.sort(tom.mdt)
	for Element in pairs(tom.mdt) do
		if tom.mdt[Element]==tom.vars.twt[tom.windowNameMain].gom then tom.lastMDTindex=Element end
	end
end

function tom.adjustGOMbutton(buttonNo,Index)
	local bName=tom.windowNameMain.."B"..tom.to2string(buttonNo)
	local gBC=GetControl(bName)
	local gBCBG=GetControl(bName .. "BG")
	local MMTkey=tom.mdt[Index]
	if MMTkey==nil then
		gBC:SetText(tostring(buttonNo))
		gBC:SetHidden(true)
	else
		local grpRead=tom.mmt[MMTkey].Readed
		local grpUnread=tom.mmt[MMTkey].Unreaded
		local temp=tom.getMMTname(MMTkey)
		if string.sub(tom.vars.gomMessageNotifier,1,1)=="1" then
			if grpUnread>0 then temp=temp .. " (" .. grpUnread .. ")" end
		elseif string.sub(tom.vars.gomMessageNotifier,1,1)=="2" then
			if grpUnread>0 then temp=temp .. " (" .. grpUnread .. "/" .. grpRead+grpUnread .. ")" else temp=temp .. " (" .. grpRead+grpUnread .. ")" end
		end
		gBC:SetText(temp)
		gBC:SetHidden(false)
		if grpUnread>0 then gBC:SetColor(1,1,0.7,1) else gBC:SetColor(0.9,0.9,0.6,0.6) end
		if MMTkey~=tom.vars.twt[tom.windowNameMain].gom then gBCBG:SetAlpha(0) else
			gBCBG:SetAlpha(0.2)
			gBC:SetColor(0.9,0.9,0.9,1)
		end
	end
end

function tom.adjustLOMbutton(buttonNo,Index)
	local bName="tomMagicB"..tom.to2string(buttonNo)
	local gBC=GetControl(bName)
	local gBCBG=GetControl(bName .. "BG")
	local MMTkey=tom.vars.lom[Index]
	if MMTkey==nil then
		gBC:SetText(tostring(buttonNo))
		gBC:SetHidden(true)
	else
		local temp=tom.vars.lom[Index][1]
		gBC:SetText(temp)
		gBC:SetHidden(false)
		gBC:SetColor(1,1,0.7,1)
		if Index~=tom.vars.shownLOM then gBCBG:SetAlpha(0) else
			gBCBG:SetAlpha(0.2)
			gBC:SetColor(0.9,0.9,0.9,1)
			tom.magicLomTransport(Index,true)
		end
	end
end

function tom.refreshUI(doRebuild)
	if doRebuild==true then tom.rebuildMDT() end
	local shownGOM=tom.getMMTname(tom.vars.twt[tom.windowNameMain].gom)
	tomWindow01Gom:SetText(shownGOM)
	-- Hauptfensteranzeige
	for looper=1,tom.vars.gomButtons,1 do
		tom.adjustGOMbutton(looper,tom.firstGOMbutton+looper-1)
	end
	tomWindow01SL1:SetMinMax(1,tom.mmtCount-tom.vars.gomButtons+1)
	tomWindow01SL1:SetValue(tom.firstGOMbutton)
	if tom.mmtCount>tom.vars.gomButtons then
		tomWindow01SL1:SetHidden(false)
	else
		tomWindow01SL1:SetHidden(true)
	end
end

function tom.refreshFailedUI()
	-- failMail Fensteranzeige
	for looper=1,tom.fmButtons,1 do
		tom.adjustFMbutton(looper,tom.firstFMbutton+looper-1)
	end
	tomfailMailSL1:SetMinMax(1,tom.vars.failedMailQueueindex-tom.fmButtons+1)
	tomfailMailSL1:SetValue(tom.firstFMbutton)
	if tom.vars.failedMailQueueindex>tom.fmButtons then
		tomfailMailSL1:SetHidden(false)
	else
		tomfailMailSL1:SetHidden(true)
	end
end

function tom.refreshCatacombUI()
	tom.loadCatacombScrollPage()
	tomCatacombCoding:SetText(tom.locTxt[90][tom.vars.CatacombCoding]) --locTxt[90], locMsg(90), {"Common","TOMish"}
	tomCatacombNameText:SetText(tom.vars.CatacombNames[tom.vars.CatacombScrollsPage])
end

function tom.refreshMagicUI()
	for looper=1,tom.lomButtons,1 do
		tom.adjustLOMbutton(looper,tom.firstLOMbutton+looper-1)
	end
	tomMagicSL1:SetMinMax(1,tom.vars.lomCount-tom.lomButtons+1)
	tomMagicSL1:SetValue(tom.firstLOMbutton)
	if tom.vars.lomCount>tom.lomButtons then
		tomMagicSL1:SetHidden(false)
	else
		tomMagicSL1:SetHidden(true)
	end
end

function tom.refreshGuildUI()
	tomGuildBetreff:SetText(tom.vars.GuildSubject)
	tomGuildNachricht:SetText(tom.vars.GuildMessage)
	tom.UpdateGuildList()
	tom.UpdateGuildButtons(1)
	tom.guildSetGuildWindow()
	tom.slider3:SetValue(1)
end

function tom.refreshUIwindow()
	tomWindow01Coding:SetText(tom.locTxt[90][tom.vars.MainWindowCoding]) --P5YCH3 - locTxt[90], locMsg(90), {"Common","TOMish"}

	if tom.vars.MainWindowCoding == 1 then --Common
		tomWindow01Crypt:SetAlpha(0) --Hide the TOMish bar.
		tomWindow01Crypt:SetCopyEnabled(false) --Disable TOMish functionality.
		tomWindow01Crypt:SetPasteEnabled(false)
		tomWindow01Crypt:SetEditEnabled(false)
		tomWindow01Crypt:SetMouseEnabled(false)
		tomWindow01Crypt:SetHidden(true)
		tomWindow01ChangeChannel:SetColor(1, 1, 1, 1) --white, default
		tomWindow01ChangeChannelTargetBG:SetEdgeColor(1, 1, 1, 1) --white, default
		tomWindow01Coding:SetColor(1, 1, 1, 1) --white, default
		tomWindow01CodingTargetBG:SetEdgeColor(1, 1, 1, 1) --white, default

		tomWindow01Common:SetAlpha(1) --Show the Common bar.
		tomWindow01Common:SetCopyEnabled(true) --Enable Common functionality.
		tomWindow01Common:SetPasteEnabled(true)
		tomWindow01Common:SetEditEnabled(true)
		tomWindow01Common:SetMouseEnabled(true)
		tomWindow01Common:SetHidden(false)
	elseif tom.vars.MainWindowCoding == 2 then --TOMish
		tomWindow01Common:SetAlpha(0) --Hide the Common bar.
		tomWindow01Common:SetCopyEnabled(false) --Disable Common functionality.
		tomWindow01Common:SetPasteEnabled(false)
		tomWindow01Common:SetEditEnabled(false)
		tomWindow01Common:SetMouseEnabled(false)
		tomWindow01Common:SetHidden(true)

		tomWindow01Crypt:SetAlpha(1) --Show the TOMish bar.
		tomWindow01Crypt:SetCopyEnabled(true) --Enable TOMish functionality.
		tomWindow01Crypt:SetPasteEnabled(true)
		tomWindow01Crypt:SetEditEnabled(true)
		tomWindow01Crypt:SetMouseEnabled(true)
		tomWindow01Crypt:SetHidden(false)
		tomWindow01ChangeChannel:SetColor(255, 0, 0, 1.0) --red
		tomWindow01ChangeChannelTargetBG:SetEdgeColor(255, 0, 0, 1.0) --red
		tomWindow01Coding:SetColor(255, 0, 0, 1.0) --red
		tomWindow01CodingTargetBG:SetEdgeColor(255, 0, 0, 1.0) --red
	end

	tomWindow01ChangeChannel:SetText(tom.locTxt[179][tom.vars.MainWindowChannel]) --P5YCH3 - locTxt[179], locMsg(179), {"/z","/g1","/g2","/g3","/g4","/g5","/s","/p","/y","/e"}
	tom.showWindow(tom.windowState)
end

function tom.resetUI()
	tom.firstGOMbutton=1
	tom.firstLOMbutton=1
	tom.firstFMbutton=1
	tom.refreshUI(true)
	tom.refreshMagicUI()
	tom.refreshGuildUI()
	tom.refreshFailedUI()
	tom.reconnectToGOM()
end

function tom.isInStrip()
	return not ZO_KeybindStripControl:IsHidden() --interactive menu is not hidden..
end

function tom.hasToClose()
	local forceClose=false
	local isInStrip=tom.isInStrip()
	local isInCombat=IsUnitInCombat("player")
	local isInScene=GAME_MENU_SCENE:IsShowing()
	local isInChatter=tom.isChattering
	--P5YCH3 - Removed isInStrip, isInCombat and isInScene from the main 'hasToClose' check to make these behaviors optional..
	if (	--((isInStrip==true) and (tom.ovrStrip==false)) or
--			((isInCombat==true) and (tom.ovrCombat==false) and (tom.vars.closeInCombat==true)) or
			((isInChatter==true) and (tom.ovrChatter==false))-- or 
--			(isInScene==true)
			) then 
		forceClose=true
	end

	--P5YCH3 - New unique behavior check to determine whether or not to close the main window when in combat.
	--Uses a new option in the addon settings panel (based on 'isInCombat' and 'closeInCombat').
	if ((isInCombat==true) and (tom.ovrCombat==false) and (tom.vars.closeInCombat==true)) then
		forceClose=true
	end

	--P5YCH3 - New unique behavior check to determine whether or not to close the main window when within other game menus.
	--Uses a new option in the addon settings panel (based on 'isInScene', 'isInStrip' and 'closeInMenus').
	if ( (isInScene==true) or (isInStrip==true and tom.ovrStrip==false)) and (tom.vars.closeInMenus==true) then
		forceClose=true
	end

	if false then
		local temp="Strip/Scene/Chatter: "
		if isInStrip==true then temp=temp.."1" else temp=temp.."0" end
		temp=temp.."/"
		if tom.ovrStrip==true then temp=temp.."1" else temp=temp.."0" end
		temp=temp..", "
		if isInScene==true then temp=temp.."1" else temp=temp.."0" end
		temp=temp..", "
		if tom.isChattering==true then temp=temp.."1" else temp=temp.."0" end
		temp=temp.."/"
		if tom.ovrChatter==true then temp=temp.."1" else temp=temp.."0" end
		tom.sendDebugMessage(temp)
	end
	return forceClose
end

function tom.UpdateThrottle()
	local temp=false
	if GetFrameTimeMilliseconds()>tom.throttlelast+tom.throttleCount then
		temp=true
		tom.throttlelast=GetFrameTimeMilliseconds()
	end
	return temp
end

function tom.immediateThrottle()
	tom.throttlelast=1
end

function tom.findPersonIndex(sID)
	local Looper=0
	local returnIndex=0
	while ((Looper<tom.vars.personCount) and (returnIndex==0)) do
		Looper=Looper+1
		if tom.vars.persons[Looper]==sID then returnIndex=Looper end
	end
	return returnIndex
end

function tom.updatePerson(Index,sName)
	local temp=Index
	if temp==0 then
		tom.vars.personCount=tom.vars.personCount+1
		temp=tom.vars.personCount
	end
	tom.vars.persons[temp]=sName
	return temp
end

function tom.truncatMale(sName)
	local temp=sName
	local Index=string.find(sName,"%^")
	if Index~=nil then temp=string.sub(sName,1,Index-1) end
	return temp
end 

function tom.addPerson(sName)
	local Index=0
	Index=tom.findPersonIndex(sName)
	Index=tom.updatePerson(Index,sName)
	return Index
end

function tom.messageAdjustGuild(fromID,toID)
	for Looper=1,tom.vars.msgCount,1 do
		if tom.vars.msgType[Looper]==CHAT_CHANNEL_GUILD_1+fromID-1 then
			-- es ist eine Gildennachricht
			if toID>0 then
				tom.vars.msgType[Looper]=5000+CHAT_CHANNEL_GUILD_1+toID-1
			else
				tom.vars.msgType[Looper]=5000
			end
		elseif tom.vars.msgType[Looper]==CHAT_CHANNEL_OFFICER_1+fromID-1 then
			-- es ist eine Offiziersnachricht
			if toID>0 then
				tom.vars.msgType[Looper]=6000+CHAT_CHANNEL_OFFICER_1+toID-1
			else
				tom.vars.msgType[Looper]=6000
			end
		end
	end
end

function tom.messageNormalizeGuild()
	local Looper=1
	while Looper<=tom.vars.msgCount do
		if ((tom.vars.msgType[Looper]==5000) or (tom.vars.msgType[Looper]==6000)) then
			-- Diese Gilde gibt es nicht mehr, daher muss diese Nachricht gelöscht werden
			tom.messageDelete(Looper)
		elseif tom.vars.msgType[Looper]>6000 then
			-- diese Nachricht wird zu einer Offiziersnachricht zurücknormalisiert
			tom.vars.msgType[Looper]=tom.vars.msgType[Looper]-6000
		elseif tom.vars.msgType[Looper]>5000 then
			-- diese Nachricht wird zu einer Gildennachricht zurücknormalisiert
			tom.vars.msgType[Looper]=tom.vars.msgType[Looper]-5000
		end
		Looper=Looper+1
	end
end

function tom.checkVanishedGuilds()
	local oldGuilds={}
	local oldSettings={}
	local oldAlerts={}
	local guildID=0
	local adjusted=false
	for Looper=1,5,1 do
		oldGuilds[Looper]=tom.vars.Guilds[Looper]
		tom.vars.Guilds[Looper]=""
		oldSettings[Looper]=tom.vars.mltg[Looper]
		tom.vars.mltg[Looper]=14
		oldAlerts[Looper]=tom.vars.alrg[Looper]
		tom.vars.alrg[Looper]=tom.locTxt[53][2]
		guildID=GetGuildId(Looper)
		if guildID>0 then
			tom.vars.Guilds[Looper]=GetGuildName(guildID)
		end
	end
	for Looper=1,5,1 do
		local newGuildID=0
		for Looper2=1,5,1 do
			if oldGuilds[Looper]~="" and oldGuilds[Looper]==tom.vars.Guilds[Looper2] then
				newGuildID=Looper2
			end
		end
		if newGuildID~=Looper then
			if ((newGuildID==0) and (oldGuilds[Looper]=="")) then
				-- nichts, beide unbesetzt
			else
				tom.messageAdjustGuild(Looper,newGuildID)
				tom.vars.mltg[newGuildID]=oldSettings[Looper]
				tom.vars.alrg[newGuildID]=oldAlerts[Looper]
				adjusted=true
			end
		else
			-- ist weiterhin gleich
			tom.vars.mltg[newGuildID]=oldSettings[Looper]
			tom.vars.alrg[newGuildID]=oldAlerts[Looper]
		end
	end
	if adjusted==true then 
		tom.messageNormalizeGuild()
		tom.rebuildMMT()
		tom.resetUI()
		tom.refreshUIwindow()
		tom.closeUndockedWindows()
		tom.refreshLAM()
	end
	for Looper=1,5,1 do
		guildID=GetGuildId(Looper)
	end
end

function tom.guildJoined(eventCode, guildId, guildName)
	if tom.PlayerReady==true then
		tom.sendMessage(tom.locMsg(39,guildName),true)
		tom.checkVanishedGuilds()
	end
end

function tom.guildLeft(eventCode, guildId, guildName)
	if tom.PlayerReady==true then
		tom.sendMessage(tom.locMsg(38,guildName),true)
		tom.checkVanishedGuilds()
	end
end

function tom.getGuildDefaultName(guildNo)
	local temp=tom.vars.Guilds[guildNo]
	if temp=="" then
		temp=guildNo
	end
	return temp
end

function tom.removeWastedTopCut()
	while ((tom.vars.personCount>0) and (tom.Treffer[tom.vars.personCount]==nil)) do
		tom.vars.persons[tom.vars.personCount]=nil
		tom.vars.personCount=tom.vars.personCount-1
	end
end

function tom.removeWastedPersons()
	tom.Treffer={}
	local copyPersons={}
	local copyCount=0
	local looper=0
	for looper=1,tom.vars.msgCount do tom.Treffer[tom.vars.msgFrom[looper]]=true end
	tom.removeWastedTopCut()
	while looper<tom.vars.personCount do
		looper=looper+1
		if tom.Treffer[looper]~=nil then
			-- ist noch vorhanden - kopieren
			copyCount=copyCount+1
			copyPersons[copyCount]=tom.vars.persons[looper]
		else
			-- einen herunterziehen
			copyCount=copyCount+1
			copyPersons[copyCount]=tom.vars.persons[tom.vars.personCount]
			-- die Nachrichten des gezogenen umschlüsseln
			for looper2=1,tom.vars.msgCount,1 do
				if tom.vars.msgFrom[looper2]==tom.vars.personCount then
					tom.vars.msgFrom[looper2]=looper
				end
			end
			tom.vars.persons[tom.vars.personCount]=nil
			tom.vars.personCount=tom.vars.personCount-1
			tom.removeWastedTopCut()
		end
	end
	tom.vars.persons=nil
	tom.vars.persons={}
	for looper=1,copyCount,1 do tom.vars.persons[looper]=copyPersons[looper] end
	tom.vars.personCount=copyCount
	tom.Treffer=nil
end

function tom.GarbageCollection()
	local GCtime=GetTimeStamp()
	tom.deleteExpiredMessages()
	tom.removeDeletedMessages()
	tom.removeWastedPersons()
	tom.rebuildMMT()
	tom.resetUI()
	GCtime=GetTimeStamp()-GCtime
	if GCtime>1 then tom.sendDebugMessage("Garbage Collection beendet - " .. GCtime .. " Sekunde(n)") end
end

function tom.showWindow(bShow)
	-- das Hauptfenster und die ungedockten Fenster in den angeforderten Zustand bringen
	for looper=1,tom.vars.twtCount,1 do
		local windowKey=tom.windowName .. tom.to2string(looper)
		local gBC=GetControl(windowKey)
		if (bShow==true) and (tom.vars.twt[windowKey].act==true) then
			gBC:SetHidden(false)
			-- New settings option to toggle the automatic display of the cursor when opening TOM. Checks the 'automaticallyShowCursor' saved variable.
			if tom.vars.automaticallyShowCursor == true then
				SCENE_MANAGER:Show("hudui") --P5YCH3 - Automatically show the cursor when the main window opens (if enabled).
			end
		else
			gBC:SetHidden(true)
		end
	end
	-- das Magiefenster in den angeforderten Zustand bringen
	-- bring the magic window to the requested state
	if (bShow==true) and (tom.vars.requestedMagicState==true) then
		tomMagic:SetHidden(false)
		tom.magicState=true
	else
		tomMagic:SetHidden(true)
		tom.magicState=false
	end
	-- die Katakomben in den angeforderten Zustand bringen
	if (bShow==true) and (tom.vars.requestedCatacombState==true) then
		tomCatacomb:SetHidden(false)
		tom.catacombState=true
	else
		tomCatacomb:SetHidden(true)
		tom.catacombState=false
	end
	-- das Gildenfenster in den angeforderten Zustand bringen
	if (bShow==true) and (tom.vars.requestedGuildState==true) then
		if tom.guildIsReaded==false then tom.guildReadGuild() end
		tomGuild:SetHidden(false)
		tom.guildState=true
	else
		tomGuild:SetHidden(true)
		tom.guildState=false
	end
	-- das Scanfenster in den angeforderten Zustand bringen
	if (bShow==true) and (tom.vars.requestedScanState==true) then
		tomScan:SetHidden(false)
		tom.scanState=true
		tom.scanTarget=true
	else
		tomScan:SetHidden(true)
		tom.scanState=false
		tom.scanTarget=false
	end
	-- das Clipboardfenster in den angeforderten Zustand bringen
	-- Bring the clipboard window to the requested state
	if (bShow==true) and (tom.vars.requestedClipState==true) then
		tomClipboard:SetHidden(false)
		tom.clipState=true
	else
		tomClipboard:SetHidden(true)
		tom.clipState=false
	end
	-- das failMail Fenster in den angeforderten Zustand bringen
	if (bShow==true) and (tom.vars.requestedFailState==true) then
		tomfailMail:SetHidden(false)
		tom.failState=true
	else
		tomfailMail:SetHidden(true)
		tom.failState=false
	end
	tom.windowState=bShow
end

function tom.time(Seconds)
	local systime=0
	if tom.vars.use24hours==false then
		systime=FormatTimeSeconds(Seconds,TIME_FORMAT_STYLE_CLOCK_TIME,TIME_FORMAT_PRECISION_TWELVE_HOUR, TIME_FORMAT_DIRECTION_NONE)
		local atPos=string.find(systime,"%.")
		if (atPos~=nil) and (atPos>1) then
			systime=string.lower(string.sub(systime,1,atPos-3) .. string.sub(systime,atPos-1,atPos-1) .. string.sub(systime,atPos+1,atPos+1))
		end
	else
		systime=FormatTimeSeconds(Seconds,TIME_FORMAT_STYLE_CLOCK_TIME,TIME_FORMAT_PRECISION_TWENTY_FOUR_HOUR, TIME_FORMAT_DIRECTION_NONE)
	end
	return systime
end

function tom.updateClock()
	tomWindow01Clock:SetText(tom.time(GetSecondsSinceMidnight()))
end

-- Callback für den Alerter
function tomUI.AlerterUpdate()
	-- Nur ausführen, wenn TOM fertig geladen ist
	if (tom.loaded == true) then
		if tom.UpdateThrottle()==true then
			-- Das Fenster in den angeforderten Status bringen
			local newWindowState=tom.vars.requestedWindowState
			if tom.hasToClose()==true then
				--================================================================================--===========================================--
				-- P5YCH3 - SCENE_MANAGER HANDLING FOR UI CONTROLS
				--================================================================================--===========================================--
				-- New settings option to toggle the display of the alerter bubble within menus. Checks the 'alerterShownInsideMenus' saved variable.
				-- Checks for GAME_MENU_SCENE:IsShowing() via the hasToClose() function above.
				if tom.vars.alerterShownInsideMenus == false then
					tomAlerterBubble:SetHidden(true)
				end
				newWindowState=false
			else
				if tom.vars.alerterShown == true and tom.vars.alerterShownInsideMenus == false then
					tomAlerterBubble:SetHidden(false)
				end
				--================================================================================--===========================================--
			end
			if ((newWindowState~=tom.windowState) or 
					(tom.vars.requestedMagicState~=tom.magicState) or 
					(tom.vars.requestedCatacombState~=tom.catacombState) or 
					(tom.vars.requestedScanState~=tom.scanState) or 
					(tom.vars.requestedClipState~=tom.clipState) or 
					(tom.vars.requestedFailState~=tom.failState) or 
					(tom.vars.requestedGuildState~=tom.guildState)) then
				tom.playSound(1)
				tom.showWindow(newWindowState)
			end
			tom.vars.lastActiveTime=GetTimeStamp()
			tom.updateClock()
			tom.alertHandler(3)
			tom.sendQueuedMail()
		end
	end
end

function tomUI.AlerterMoveStop()
	-- Nur ausführen, wenn tom geladen ist
	if (tom.loaded == true) then
		-- der Anwender hat den Alerter verschoben - das merken wir uns
		--echo("|cFF0000Alerter moved by TOM.")
		tom.vars.AofX = tomAlerterBubble:GetLeft()
		tom.vars.AofY = tomAlerterBubble:GetTop()
		tomAlerter:ClearAnchors()
		tomAlerter:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,tom.vars.AofX,tom.vars.AofY)
	end
end

function tomUI.AlerterClick()
	-- Anwender drückt auf den Alerter oder das Keybinding
	if tom.PlayerReady==true then
		-- den angeforderten Status ändern
		if tom.vars.requestedWindowState==true then
			if tom.windowState==false then
				if IsUnitInCombat("player")==true then
					-- Combat überschreiben
					tom.ovrCombat=true
				end
				if tom.isChattering==true then
					-- Chatter überschreiben
					tom.ovrChatter=true
				end
				if tom.isInStrip()==true then
					-- Chatter überschreiben
					tom.ovrStrip=true
				end
			else
				tom.vars.requestedWindowState=false
				tom.resetOverides(true)
			end
		else
			if tom.windowState==false then
				if IsUnitInCombat("player")==true then
					-- Combat überschreiben
					tom.ovrCombat=true
				end
				if tom.isChattering==true then
					-- Chatter überschreiben
					tom.ovrChatter=true
				end
				if tom.isInStrip()==true then
					-- Strip überschreiben
					tom.ovrStrip=true
				end
			end
			tom.vars.requestedWindowState=true
		end
		tom.immediateThrottle()
	end
end

function tomUI.guildClick()
	if tom.PlayerReady==true then
		tom.vars.requestedGuildState=not tom.vars.requestedGuildState
		tom.immediateThrottle()
	end
end

function tomUI.catacombClick()
	if tom.PlayerReady==true then
		tom.vars.requestedCatacombState=not tom.vars.requestedCatacombState
		tom.immediateThrottle()
	end
end

function tomUI.magicClick()
	if tom.PlayerReady==true then
		tom.vars.requestedMagicState=not tom.vars.requestedMagicState
		-- beim Schliessen des Fensters die UI in Ordnung bringen
		if tom.vars.requestedMagicState==false then
			tom.rebuildMMT()
			tom.resetUI()
		end
		tom.immediateThrottle()
	end
end

function tomUI.scanClick()
	if tom.PlayerReady==true then
		tom.vars.requestedScanState=not tom.vars.requestedScanState
		tom.immediateThrottle()
	end
end

function tomUI.clipClick()
	if tom.PlayerReady==true then
		tom.vars.requestedClipState=not tom.vars.requestedClipState
		tom.immediateThrottle()
	end
end

function tomUI.failMailClick()
	if tom.PlayerReady==true then
		tom.vars.requestedFailState=not tom.vars.requestedFailState
		tom.immediateThrottle()
	end
end

function tomUI.executeAction(actionNo)
	-- Keybinding-Aktion ausführen
	if tom.PlayerReady==true then
		if actionNo==1 then tom.sendMessage("Reload",true) ReloadUI()
		elseif actionNo==2 then tom.sendMessage("Logout",true) Logout()
		elseif actionNo==3 then tom.sendMessage("Quit",true) Quit()
		end
	end
end

function tomUI.WindowMoveStop(self)
	-- Nur ausführen, wenn tom geladen ist
	if (tom.loaded == true) then
		-- der Anwender hat das Fenster verschoben - das merken wir uns
		local windowName=self:GetName()
		tom.vars.twt[windowName].X=self:GetLeft()
		tom.vars.twt[windowName].Y=self:GetTop()
		self:ClearAnchors()
		self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, tom.vars.twt[windowName].X, tom.vars.twt[windowName].Y)
	end
end

function tomUI.MagicMoveStop(self)
	-- Nur ausführen, wenn tom geladen ist
	if (tom.loaded == true) then
		-- der Anwender hat das Fenster verschoben - das merken wir uns
		tom.vars.MofX=self:GetLeft()
		tom.vars.MofY=self:GetTop()
		self:ClearAnchors()
		self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, tom.vars.MofX, tom.vars.MofY)
	end
end

function tomUI.GuildMoveStop(self)
	-- Nur ausführen, wenn tom geladen ist
	if (tom.loaded == true) then
		-- der Anwender hat das Fenster verschoben - das merken wir uns
		tom.vars.GofX=self:GetLeft()
		tom.vars.GofY=self:GetTop()
		self:ClearAnchors()
		self:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,tom.vars.GofX,tom.vars.GofY)
	end
end

function tomUI.CatacombMoveStop(self)
	-- Nur ausführen, wenn tom geladen ist
	if (tom.loaded == true) then
		-- der Anwender hat das Fenster verschoben - das merken wir uns
		tom.vars.CofX=self:GetLeft()
		tom.vars.CofY=self:GetTop()
		self:ClearAnchors()
		self:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,tom.vars.CofX,tom.vars.CofY)
	end
end

function tomUI.ScanMoveStop(self)
	-- Nur ausführen, wenn Das AddON schon geladen ist
	if (tom.loaded == true) then
		-- der Anwender hat das Fenster verschoben - das merken wir uns
		tom.vars.SofX = self:GetLeft()
		tom.vars.SofY = self:GetTop()
		tomScan:ClearAnchors()
		tomScan:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,tom.vars.SofX,tom.vars.SofY) 
	end
end

function tomUI.ClipMoveStop(self)
	-- Nur ausführen, wenn Das AddON schon geladen ist
	-- Run only if the AddON is already loaded
	if (tom.loaded == true) then
		-- der Anwender hat das Fenster verschoben - das merken wir uns
		-- the user moved the window - we remember that
		tom.vars.DofX = self:GetLeft()
		tom.vars.DofY = self:GetTop()
		tomClipboard:ClearAnchors()
		tomClipboard:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,tom.vars.DofX,tom.vars.DofY) 
	end
end

function tomUI.failMailMoveStop(self)
	-- Nur ausführen, wenn Das AddON schon geladen ist
	if (tom.loaded == true) then
		-- der Anwender hat das Fenster verschoben - das merken wir uns
		tom.vars.FofX = self:GetLeft()
		tom.vars.FofY = self:GetTop()
		tomScan:ClearAnchors()
		tomScan:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,tom.vars.FofX,tom.vars.FofY) 
	end
end

function tom.setChatter()
	tom.isChattering=true
end

function tom.endChatter()
	tom.isChattering=false
end

function tom.WelcomeBackMessage()
	if ((tom.GameResumedAfter>30) and (tom.vars.displayGreeting==true)) then
		tom.sendMessage(tom.locMsg(3, FormatTimeSeconds(tom.GameResumedAfter, TIME_FORMAT_STYLE_DESCRIPTIVE, TIME_FORMAT_PRECISION_SECONDS, TIME_FORMAT_DIRECTION_NONE)),true)
	end
end

function tom.reconnectToGOM()
	if tom.connectGOMtoRolle(tom.vars.twt[tom.windowNameMain].gom,tom.windowNameMain)==false then
		-- auf den ersten vorhandenen GOM positionieren
		local temp=""
		for looper in pairs(tom.mmt) do if temp=="" then temp=looper end end
		tom.connectGOMtoRolle(temp,tom.windowNameMain)
	end
end

function tom.activateUIchanges()
	tom.InitializeUI()
	tom.resetUI()
end

function tom.firstRun()
	if tom.vars.firstRun==true then
		tom.sendSystemMessage(tom.locMsg(71))
		tom.vars.firstRun=false
	end
end

function tom.EnterWorld()
	if tom.PlayerReady==false then
		tom.WelcomeBackMessage()
		tom.GarbageCollection()
		tom.PlayerReady=true
		tom.magicLomTransport(tom.vars.shownLOM,true)
		tom.refreshCatacombUI()
		tom.firstRun()
		if tom.mailStatus(true)~=0 then tom.mailStatus(false) end
	end
end

function tom.ShowTooltip(self,tooltipText)
	if self:GetAlpha()~=0 then
		InitializeTooltip(InformationTooltip,self,TOPRIGHT,0,5,BOTTOMRIGHT)
		SetTooltipText(InformationTooltip,tooltipText)
	end
end

function tom.bubbleStatistics()
	local temp=tom.locMsg(27,tom.vars.msgCount,tom.vars.personCount)
	return temp
end

function tom.getMessageColorCode(mType)
	local temp=7
	if mType==CHAT_CHANNEL_PARTY then temp=7
	elseif mType==CHAT_CHANNEL_GUILD_1 then temp=13
	elseif mType==CHAT_CHANNEL_GUILD_2 then temp=13
	elseif mType==CHAT_CHANNEL_GUILD_3 then temp=13
	elseif mType==CHAT_CHANNEL_GUILD_4 then temp=13
	elseif mType==CHAT_CHANNEL_GUILD_5 then temp=13
	elseif mType==CHAT_CHANNEL_OFFICER_1 then temp=18
	elseif mType==CHAT_CHANNEL_OFFICER_2 then temp=18
	elseif mType==CHAT_CHANNEL_OFFICER_3 then temp=18
	elseif mType==CHAT_CHANNEL_OFFICER_4 then temp=18
	elseif mType==CHAT_CHANNEL_OFFICER_5 then temp=18
	elseif mType==CHAT_CHANNEL_SAY then temp=1
	elseif mType==CHAT_CHANNEL_YELL then temp=2
	elseif mType==CHAT_CHANNEL_EMOTE then temp=8
	elseif mType==CHAT_CHANNEL_ZONE then temp=6
	elseif mType==CHAT_CHANNEL_ZONE_LANGUAGE_1 then temp=6
	elseif mType==CHAT_CHANNEL_ZONE_LANGUAGE_2 then temp=6
	elseif mType==CHAT_CHANNEL_ZONE_LANGUAGE_3 then temp=6
	--===========================================
	--P5YCH3 - Translation additions.
	--===========================================
	--elseif mType==CHAT_CHANNEL_ZONE_LANGUAGE_4 then temp=6
	elseif mType==CHAT_CHANNEL_ZONE_LANGUAGE_5 then temp=6
	--elseif mType==CHAT_CHANNEL_ZONE_LANGUAGE_6 then temp=6
	--===========================================
	elseif mType==CHAT_CHANNEL_WHISPER then temp=3
	elseif mType==CHAT_CHANNEL_WHISPER_SENT then temp=4
	end
	return temp
end

function getGuildDisplayname(fullName)
	local temp=fullName --the entire string, character name and account ID
	local atPos=string.find(temp,"@")
	if (atPos~=nil) and (atPos>1) then
		if string.sub(tom.vars.displayPlayerChars,1,1)=="1" then --short, character name, P5YCH3 - Updated
			temp=string.sub(temp,1,atPos-1)
		elseif string.sub(tom.vars.displayPlayerChars,1,1)=="2" then --address, account ID, P5YCH3 - Updated
			temp=string.sub(temp,atPos)
		end
	end
	return temp
end

function tom.createPlayerLink(sender)
	local temp=sender
	local atPos=string.find(sender,"@")

	if atPos==nil then
		temp=ZO_LinkHandler_CreateLink(sender,nil,CHARACTER_LINK_TYPE, sender)
	else
		if atPos>1 then
			temp=ZO_LinkHandler_CreateLink(getGuildDisplayname(sender),nil,CHARACTER_LINK_TYPE, string.sub(sender,atPos))
		else
			temp=ZO_LinkHandler_CreateLink(sender,nil,CHARACTER_LINK_TYPE, sender)
		end
	end
	return temp
end

function tom.formatRolleMsg(Key,plainFormat)
	local now=GetTimeStamp()+tom.zeitDisvergenz()
	local msgTime=tom.vars.msgTime[Key]+tom.zeitDisvergenz()
	local prefix=tom.time(tom.timeFromMidnight(msgTime)) .. "  "
	if msgTime<(now-GetSecondsSinceMidnight()) then
		prefix=GetDateStringFromTimestamp(msgTime) .. "  " .. prefix
	end
	if plainFormat==false then
		prefix="|c" .. tom.timestampColor .. prefix .. "|r"
	end

	local sender=tom.vars.msgFrom[Key]

	--TOM sets the global sender variable to the 'Key' returned above.
	sender=tom.vars.persons[sender]

	-- Korrektur für eigene Whispers
	--Override - Whispers that you send. Controls how your name appears within the channel history. Does not effect the appearance of other players.
	if tom.vars.msgType[Key]==CHAT_CATEGORY_WHISPER_OUTGOING then
		sender=GetUnitName("player") .. GetUnitDisplayName("player")
	end

	if plainFormat==false then
		sender=tom.createPlayerLink(sender)
		sender="|c" .. tom.senderColor .. sender .. "  |r"
	else
		sender="["..sender.."]  "
	end
	tom.vars.msgRead[Key]=nil
	local temp=prefix .. sender .. tom.vars.msgText[Key]
	return temp
end

function tom.isAuthor(msgNum) 
	local temp=false
	if tom.vars.msgType[msgNum]==2 then
		local isFrom=tom.vars.persons[tom.vars.msgFrom[msgNum]]
		if string.find(isFrom,tomreborn.authorAccount_InGameName)~=nil then
			temp=true
		end
	end
	return temp
end

function tom.AddmsgToRolle(messageToAdd,winKey,msgNum)
	if tom.vars.twt[winKey].act==true then
		local gBC=GetControl(winKey .. "Rolle")
		local gBC2=GetControl(winKey .. "SL2")
		if tom.isAuthor(msgNum)==true then
			gBC:AddMessage(messageToAdd,GetInterfaceColor(INTERFACE_COLOR_TYPE_ABILITY_TOOLTIP,ABILITY_TOOLTIP_TEXT_COLOR_GOLD_ABILITY))
		else
			gBC:AddMessage(messageToAdd,GetInterfaceColor(INTERFACE_COLOR_TYPE_CHAT_CHANNEL_CATEGORY_DEFAULTS,tom.getMessageColorCode(tom.vars.msgType[msgNum])))
		end
		-- Den Slider anpassen, dabei verhindern, dass die Rolle verrutscht, wenn die Scrollpos nicht am Ende ist (der Benutzer weiter vorne liest)
		-- Adjust the slider, preventing the scroll from slipping when the scrollpos is not at the end (the user reads ahead)
		gBC2:SetMinMax(0,gBC:GetNumHistoryLines())
		if gBC:GetScrollPosition()==0 then
			gBC2:SetValue(gBC:GetNumHistoryLines())
		end
	end
end

function tom.clearRolle(windowKey)
	local gBC=GetControl(windowKey .. "Rolle")
	gBC:Clear()
end

function tom.connectCatacombToGOM(gomKey)
	tomCatacombGom:SetText(tostring(gomKey))
	tomCatacombTarget:SetText(tom.getMMTname(gomKey))
end

function tom.connectGOMtoRolle(Key,windowKey)
	local positioned=false
	if tom.mmt[Key]~=nil then
		local numMessages=tom.mmt[Key].Readed+tom.mmt[Key].Unreaded
		tom.vars.twt[windowKey].gom=Key
		positioned=true
		tom.clearRolle(windowKey)
		for looper=1,numMessages,1 do
			local connectMessage=tom.formatRolleMsg(tom.mmt[Key][looper],false)
			tom.AddmsgToRolle(connectMessage,windowKey,tom.mmt[Key][looper])
		end
		tom.mmt[Key].Readed=numMessages
		tom.mmt[Key].Unreaded=0
		if windowKey==tom.windowNameMain then
			tom.connectCatacombToGOM(tom.vars.twt[windowKey].gom)
		end
	end
	tom.refreshUI()
	return positioned
end

function tom.sendRolleToClipboard(Key)
	local maxEdit=1028
	if tom.mmt[Key]~=nil then
		local numMessages=tom.mmt[Key].Readed+tom.mmt[Key].Unreaded
		local xText=""
		for looper=numMessages,1,-1 do
			local connectMessage=tom.formatRolleMsg(tom.mmt[Key][looper],true)
			if string.len(xText) + string.len(connectMessage) < maxEdit then
				if xText~="" then xText="\n"..xText end
				xText=connectMessage..xText
			end
		end
		tomClipboardEdit:SetText(xText)
		tom.vars.ClipboardText=xText
		tom.vars.requestedClipState=true
	end
end

function tomUI.clipClearClick()
	tomClipboardEdit:Clear()
end

function tomUI.clipEditStart(self)
	self:SetKeyboardEnabled(true)
	self:TakeFocus()
end

function tomUI.copyToClipboard(winName)
	local Key=tom.vars.twt[winName].gom
	tom.sendRolleToClipboard(Key)
end

function tomUI.toggleAlertOverride(winName)
	if tom.overrideAlert==false then
		tom.overrideAlert=true
		tom.sendMessage(tom.locMsg(151)) --locTxt[151]
	else
		tom.overrideAlert=false
		tom.sendMessage(tom.locMsg(152)) --locTxt[152]
	end
end

function tom.closeUndockedMagicans()
	for looper=2,tom.vars.twtCount,1 do
		local Key=tom.windowName..tom.to2string(looper)
		if tom.vars.twt[Key].act==true then
			local gom=tom.vars.twt[Key].gom
			if gom>=tom.mmtlom then
				tom.undockGOMclose(Key)
			end
		end
	end
end

function tom.closeUndockedWindows()
	for looper=2,tom.vars.twtCount,1 do
		local Key=tom.windowName..tom.to2string(looper)
		if tom.vars.twt[Key].act==true then
			local gom=tom.vars.twt[Key].gom
			tom.undockGOMclose(Key)
		end
	end
end

function tom.reconnectToPreviousMDT()
	if tom.lastMDTindex~=0 then
		if tom.mdt[tom.lastMDTindex]~=nil then
			-- positionieren auf die Pos, welche der Anwender zuletzt angeklickt hatte
			tom.connectGOMtoRolle(tom.mdt[tom.lastMDTindex],tom.windowNameMain)
		else
			-- scheinbar wurde der letzte Eintrag der MDT gelöscht
			tom.lastMDTindex=tom.lastMDTindex-1
			if tom.mdt[tom.lastMDTindex]~=nil then
				-- auf den ersten Eintrag gehen
				tom.connectGOMtoRolle(tom.mdt[tom.lastMDTindex],tom.windowNameMain)
			else
				tom.resetAll()
			end
		end
	end
end

function tom.deleteGOM(Key)
	if tom.mmt[Key]==nil then
		if Key~=nil then tom.sendDebugMessage("Gruppe " .. Key .. " nicht gefunden") end
	else
		local Gruppe=tom.getMMTname(Key)
		if ((Key<tom.mmtlom) or (Key==tom.mmtsys)) then
			local toDelete=tom.mmt[Key].Readed+tom.mmt[Key].Unreaded
			for looper=1,toDelete,1 do
				local msgNum=tom.mmt[Key][looper]
				tom.messageDelete(msgNum)
			end
			-- im Chat anzeigen, dass Nachrichten gelöscht wurden (momentan deaktiviert)
			-- show in chat that messages have been deleted (currently disabled)
			-- tom.sendMessage(tom.locMsg(46,toDelete,Gruppe),true)

			-- die Rolle leeren, damit alle nachrichten verschwinden, auch, wenn es die letzte GOM war
			-- empty the scroll so that all messages disappear, even if it was the last GOM
			tom.clearRolle(tom.windowNameMain)
		else
			-- LOMs nicht löschen, sondern nur deaktivieren
			-- Do not delete LOMs, only deactivate them
			tom.vars.lom[Key-tom.mmtlom+1][3]=false
			tom.sendMessage(tom.locMsg(74,Gruppe),true)
		end
		-- Ein etwaiges ungedocktes Fenster schliessen
		local twtKey=tom.searchUndockedWindow(Key,false)
		if twtKey~="" then tom.undockGOMclose(twtKey) end
		-- die MMT neu aufbauen
		-- rebuild the MMT
		tom.rebuildMMT()
		tom.resetUI()
		tom.refreshUIwindow()
		tom.closeUndockedMagicans()
		tom.reconnectToPreviousMDT()
	end
end

--P5YCH3 - Used when determining what to prefix a message with when clicking a channel. Can be used to adjust how replies occur.
function tom.getGOMprefix(Key)
	local temp=nil
	if Key==nil then temp="/s"
	elseif Key==tom.mmtgrp then temp="/p"
	elseif Key==tom.mmtg01 then temp="/g1"
	elseif Key==tom.mmtg02 then temp="/g2"
	elseif Key==tom.mmtg03 then temp="/g3"
	elseif Key==tom.mmtg04 then temp="/g4"
	elseif Key==tom.mmtg05 then temp="/g5"
	elseif Key==tom.mmto01 then temp="/o1"
	elseif Key==tom.mmto02 then temp="/o2"
	elseif Key==tom.mmto03 then temp="/o3"
	elseif Key==tom.mmto04 then temp="/o4"
	elseif Key==tom.mmto05 then temp="/o5"
	elseif Key==tom.mmtsay then temp="/s"
	elseif Key==tom.mmtzzz then temp="/z"
	--elseif Key==tom.mmtzde then temp="/zde" --Originals, broken
	--elseif Key==tom.mmtzfr then temp="/zfr"
	--elseif Key==tom.mmtzen then temp="/zen"
	elseif Key==tom.mmtzde then temp="/dezone" --P5YCH3 - Fixed all broken zone prefixes
	elseif Key==tom.mmtzfr then temp="/frzone"
	elseif Key==tom.mmtzen then temp="/enzone"
	--===========================================
	--P5YCH3 - Translation additions.
	--===========================================
	elseif Key==tom.mmtzjp then temp="/jpzone"
	elseif Key==tom.mmtzru then temp="/ruzone"
	elseif Key==tom.mmtzes then temp="/eszone"
	--===========================================
	elseif ((Key>0) and (Key<tom.mmtg01)) then
	
		if tom.vars.persons[Key]~=nil then temp="/w " .. tom.vars.persons[Key] else temp="/w" end
	end
	if temp~=nil then temp=temp .. " " end
	return temp
end

function tom.answerGOM(Key)
	local temp=tom.getGOMprefix(Key)
	if temp==nil then
		tom.sendMessage(tom.locMsg(43),true) --locTxt[43], locMsg(43)
	else
		tom.sendChatMessage(temp,false)
	end
end

--P5YCH3 - New executeGOMclick functions for the first three main interface buttons.
function tomUI.executeGOMclick(action,button)
	-- left click=answer the current group, right click=last messages into clipboard.
	if action==1 then
		if button==1 then -- if left click.. answer the current group
			tom.answerGOM(tom.vars.twt[tom.windowNameMain].gom)
		elseif button==3 then -- if middle click.. answer the current group
			tomUI.copyToClipboard(tom.windowNameMain)
		else -- if right click.. last messages into clipboard.
			tomUI.copyToClipboard(tom.windowNameMain)
		end

	-- undock the current group..
	elseif action==2 then
		tom.undockGOM(tom.vars.twt[tom.windowNameMain].gom)

	-- left click=delete messages from the current group, right click=toggle alert popup override
	elseif action==3 then
		if button==1 then -- if left click.. delete messages from the current group
			tom.deleteGOM(tom.vars.twt[tom.windowNameMain].gom)
		elseif button==3 then -- if middle click.. answer the current group
			tomUI.toggleAlertOverride(tom.windowNameMain)
		else --if right click.. toggle alert popup override
			tomUI.toggleAlertOverride(tom.windowNameMain)
		end
	end
end

--P5YCH3, #REPLY_FEATURES
function tom.GOMclick(GOMno,button) --P5YCH3 - Change channels, clicked on a channel, channel was selected.
	local Index=GOMno+tom.firstGOMbutton-1
	local Key=tom.mdt[Index]
	if button==1 then --If left click..
		tom.connectGOMtoRolle(Key,tom.windowNameMain)

		--P5YCH3 - New function to optionally start a reply to the selected group if this behavior is enabled in the addon settings.
		--First determine if the group we are looking at is valid for a reply or not.
		local temp=tom.getGOMprefix(Key)
		if temp==nil then
			--tom.sendMessage(tom.locMsg(43),true) --locTxt[43], locMsg(43)
		else
			--Optionally starts a reply to the selected group if this behavior is enabled in the addon settings.
			if tom.vars.Automatically_Reply_To_Selected_Groups == true then
				if tom.exemptionForSettingsChanges == false then --Prevents chat being triggered when changing name display settings.
					tom.answerGOM(Key)
				end
			end
		end

	elseif button==3 then --P5YCH3 - If middle-click..
		if string.sub(tom.vars.middle_Click,1,1)=="1" then
			tom.connectGOMtoRolle(Key,tom.windowNameMain)
			if tom.vars.Automatically_Reply_To_Selected_Groups == true then
				if tom.exemptionForSettingsChanges == false then --Prevents chat being triggered when changing name display settings.
					tom.answerGOM(Key)
				end
			end
		elseif string.sub(tom.vars.middle_Click,1,1)=="2" then
			tom.deleteGOM(tom.vars.twt[tom.windowNameMain].gom) --Deletes the conversation.
			d("TOM - The conversation was deleted from your history.")
		end
		
	else --if right click..
		tom.answerGOM(Key)
	end
	tom.lastMDTindex=Index
end

function tom.OnSlider1Move(value)
	if tom.PlayerReady==true then
		tom.firstGOMbutton=value
		tom.refreshUI()
	end
end

function tom.OnMagicSlider1Move(value)
	tom.firstLOMbutton=value
	tom.refreshMagicUI()
end

function tom.OnRolleWheel(self,value)
	local parent=self:GetParent()
	local parentName=parent:GetName()
	local gBC=GetControl(parentName .. "SL2")
	local SLmin,SLmax=gBC:GetMinMax()
	local SLval=gBC:GetValue()
	if value<0 then
		if SLval<SLmax then gBC:SetValue(SLval+1) end
	else
		if SLval>SLmin then gBC:SetValue(SLval-1) end
	end
end

function tom.OnSlider2Move(self,value)
	local parent=self:GetParent()
	local parentName=parent:GetName()
	local gBC=GetControl(parentName .. "Rolle")
	gBC:SetScrollPosition(gBC:GetNumHistoryLines()-value)
end

function tomUI.OnGOMScroll(value)
	local SLmin,SLmax=tomWindow01SL1:GetMinMax()
	local SLval=tomWindow01SL1:GetValue()
	if tom.mmtCount>tom.vars.gomButtons then
		if value<0 then
			if SLval<SLmax then tomWindow01SL1:SetValue(SLval+1) end
		else
			if SLval>SLmin then tomWindow01SL1:SetValue(SLval-1) end
		end
	end
end

function tom.newLOM()
	tom.vars.lomCount=tom.vars.lomCount+1
	tom.vars.lom[tom.vars.lomCount]={tom.to2string(tom.vars.lomCount), "", false, "", "", "", "", "", "", "", ""}
	tom.vars.shownLOM=tom.vars.lomCount
end

function tom.deleteLOM(Index)
	if Index>0 then
		if tom.vars.lomCount>0 then
			if Index<tom.vars.lomCount then
				for looper=Index,tom.vars.lomCount-1,1 do
					tom.vars.lom[looper]=tom.vars.lom[looper+1]
				end
			end
			tom.vars.lom[tom.vars.lomCount]=nil
			tom.vars.lomCount=tom.vars.lomCount-1
		end
	end
	if tom.vars.shownLOM>tom.vars.lomCount then tom.vars.shownLOM=tom.vars.lomCount end
end

function tomUI.executeLOMclick(action)
	if action==1 then
		tom.newLOM()
	elseif action==2 then
		tom.deleteLOM(tom.vars.shownLOM)
	end
	tom.refreshMagicUI()
	tom.magicLomTransport(tom.vars.shownLOM,true)
end

function tom.magicLomTransport(Index,direction)
	if tom.PlayerReady==true then
		if Index>0 then
			if direction==true then
				tomMagicName:SetText(tom.vars.lom[Index][1])
				tomMagicTitel:SetText(tom.vars.lom[Index][2])
				if tom.vars.lom[Index][3]==true then tomMagicStatus:SetText(tom.locTxt[81][1]) else tomMagicStatus:SetText(tom.locTxt[81][2]) end
				for looper=4,11,1 do
					gBC=GetControl("tomMagicEdit"..tom.to2string(looper))
					gBC:SetText(tom.vars.lom[Index][looper])
				end
			else
				tom.vars.lom[Index][1]=tomMagicName:GetText()
				tom.vars.lom[Index][2]=tomMagicTitel:GetText()
				if tomMagicStatus:GetText()==tom.locTxt[81][1] then tom.vars.lom[Index][3]=true else tom.vars.lom[Index][3]=false end
				for looper=4,11,1 do
					gBC=GetControl("tomMagicEdit"..tom.to2string(looper))
					tom.vars.lom[Index][looper]=string.lower(gBC:GetText())
				end
			end
		end
	end
end

function tomUI.lomStatusClick(self)
	local value=self:GetText()
	if value==tom.locTxt[81][1] then self:SetText(tom.locTxt[81][2]) else self:SetText(tom.locTxt[81][1]) end
	tomUI.magicStoreBack(self)
end

function tom.LOMclick(LOMno,button)
	local Index=LOMno+tom.firstLOMbutton-1
	tom.vars.shownLOM=Index
	tom.refreshMagicUI()
	tom.magicLomTransport(Index,true)
end

function tomUI.OnLOMScroll(value)
	local SLmin,SLmax=tomMagicSL1:GetMinMax()
	local SLval=tomMagicSL1:GetValue()
	if tom.vars.lomCount>tom.lomButtons then
		if value<0 then
			if SLval<SLmax then tomMagicSL1:SetValue(SLval+1) end
		else
			if SLval>SLmin then tomMagicSL1:SetValue(SLval-1) end
		end
	end
end

function tom.createGOMbutton(nButton,gombuttonwidth,gombuttonheight,gomX,gomY)
	local bName="tomWindow01B"..tom.to2string(nButton)
	local gBC=GetControl(bName)
	if nButton<=tom.vars.gomButtons then
		if gBC==nil then gBC=CreateControlFromVirtual(bName, tomWindow01, "gomButton") end
		gBC:SetDimensions(gombuttonwidth,gombuttonheight-2)
		gBC:ClearAnchors()
		gBC:SetAnchor(TOPLEFT, tomWindow01, TOPLEFT, gomX, gomY+(nButton-1)*gombuttonheight)
		gBC:SetText(tostring(nButton))
		gBC:SetHandler("OnMouseUp", function(self,button) tom.GOMclick(tonumber(string.sub(self:GetName(),13,14)),button) end)
		gBC:SetHandler("OnMouseWheel", function(self, delta, ctrl, alt, shift) tomUI.OnGOMScroll(delta) end)
		gBC:SetHidden(false)
	else
		if gBC~=nil then 
			gBC:ClearAnchors()
			gBC:SetHidden(true)
		end
	end
end

function tom.createLOMbutton(nButton,lombuttonwidth,lombuttonheight,lomX,lomY)
	local bName="tomMagicB"..tom.to2string(nButton)
	local gBC=GetControl(bName)
	if nButton<=tom.lomButtons then
		if gBC==nil then gBC=CreateControlFromVirtual(bName,tomMagic,"lomButton") end
		gBC:SetDimensions(lombuttonwidth,lombuttonheight-2)
		gBC:ClearAnchors()
		gBC:SetAnchor(TOPLEFT,tomMagic,TOPLEFT,lomX,lomY+(nButton-1)*lombuttonheight)
		gBC:SetText(tostring(nButton))
		gBC:SetHandler("OnMouseUp", function(self,button) tom.LOMclick(tonumber(string.sub(self:GetName(),10,11)),button) end)
		gBC:SetHandler("OnMouseWheel", function(self, delta, ctrl, alt, shift) tomUI.OnLOMScroll(delta) end)
		gBC:SetHidden(false)
	else
		if gBC~=nil then 
			gBC:ClearAnchors()
			gBC:SetHidden(true)
		end
	end
end

function tom.reorgUndockedWindows()
	local looper=2
	while looper<tom.vars.twtCount do
		if tom.vars.twt[tom.windowName..tom.to2string(looper)].act==false then
			if looper<tom.vars.twtCount then
				-- einen herunterziehen, wenn noch einer da ist
				tom.vars.twt[tom.windowName..tom.to2string(looper)]=tom.vars.twt[tom.windowName..tom.to2string(tom.vars.twtCount)]
				-- und weg damit
				tom.vars.twt[tom.windowName..tom.to2string(tom.vars.twtCount)]=nil
			end
			tom.vars.twtCount=tom.vars.twtCount-1
		end
		looper=looper+1
	end
end

function tom.searchUndockedWindow(Key,activeOnly)
	local looper=2
	local temp=""
	while (looper<=tom.vars.twtCount) and (temp=="") do
		if tom.vars.twt[tom.windowName..tom.to2string(looper)].gom==Key then
			if ((activeOnly==false) or (activeOnly==tom.vars.twt[tom.windowName..tom.to2string(looper)].act)) then
				temp=tom.windowName..tom.to2string(looper)
			end
		end
		looper=looper+1
	end
	return temp
end

function tom.createRolleSlider(parentKeyName,offsetX,offsetY,sliderHeight)
	local sliderName=parentKeyName .. "SL2"
	local parent=GetControl(parentKeyName)
	local gBC=GetControl(sliderName)
	if gBC==nil then gBC=CreateControl(sliderName,parent,CT_SLIDER) end
	gBC:ClearAnchors()
	gBC:SetAnchor(TOPLEFT,parent,TOPLEFT,offsetX,offsetY)
	gBC:SetDimensions(15,sliderHeight)
	gBC:SetMouseEnabled(true)
	gBC:SetThumbTexture("ESOUI/art/lorelibrary/lorelibrary_scroll.dds","ESOUI/art/lorelibrary/lorelibrary_scroll.dds","ESOUI/art/lorelibrary/lorelibrary_scroll.dds",15,25,0,0,1,1)
	gBC:SetHandler("OnValueChanged",function(self,value,eventReason) tom.OnSlider2Move(self,value) end)
	gBC:SetHidden(false)
	gBC:SetValueStep(1)
	gBC:SetMinMax(1,1)
	gBC:SetValue(1)
	return gBC
end

function tom.createUndockedWindow(newKey,newGOM)
	local WindowGOMblock=40
	local WindowRow1=10
	local newGOMtext=tom.getMMTname(newGOM)
	local winWidth=tom.vars.undockedWidth+20
	local winHeight=tom.vars.undockedHeigth*tom.gombuttonheight+WindowGOMblock+10
	local gBC2=nil
	local gBC=GetControl(newKey)
	if gBC==nil then gBC=CreateControlFromVirtual(newKey, GuiRoot, "tomWindowVM") end
	gBC:ClearAnchors()
	gBC:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, tom.vars.twt[newKey].X, tom.vars.twt[newKey].Y)
	gBC:SetDimensions(winWidth,winHeight)
	gBC2=GetControl(newKey .. "Background")
	gBC2:SetAlpha(tom.vars.BGalpha/100)
	gBC2=GetControl(newKey .. "Bubble")
	gBC2:SetTexture("/esoui/art/chatwindow/chat_notification_echo.dds")
	gBC2=GetControl(newKey .. "Gom")
	gBC2:SetText(newGOMtext)
	gBC2=GetControl(newKey .. "Closer")
	gBC2:SetTexture("/esoui/art/buttons/cancel_up.dds")
	gBC2:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[125]) end)
	gBC2:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	gBC2=GetControl(newKey .. "Answer")
	gBC2:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[126]) end)
	gBC2:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	gBC2=GetControl(newKey .. "Line1")
	gBC2:ClearAnchors()
	gBC2:SetAnchor(TOPLEFT,gBC, TOPLEFT, 0, WindowGOMblock-6)
	gBC2:SetDimensions(winWidth,2)
	gBC2=GetControl(newKey .. "Line3")
	gBC2:ClearAnchors()
	gBC2:SetAnchor(TOPLEFT,gBC, TOPLEFT, 0, winHeight-10)
	gBC2:SetDimensions(winWidth,2)
	gBC2=GetControl(newKey .. "Rolle")
	gBC2:ClearAnchors()
	gBC2:SetAnchor(TOPLEFT,gBC, TOPLEFT, WindowRow1, WindowGOMblock)
	gBC2:SetDimensions(winWidth-20,winHeight-(WindowGOMblock+10))
	gBC2:SetLinkEnabled(true)
	gBC2:SetMouseEnabled(true)
	gBC2:SetHidden(false)
	gBC2:SetClearBufferAfterFadeout(false)
	gBC2:SetMaxHistoryLines(tom.MaxHistoryLines)
	gBC2:SetFont(tom.tomFont(57,tom.vars.fontSize))
	gBC2:SetHandler("OnLinkMouseUp", function(self, _, link, button) return ZO_LinkHandler_OnLinkMouseUp(link, button, self) end)
	gBC2:SetHandler("OnMouseWheel", function(self, delta, ctrl, alt, shift) tom.OnRolleWheel(self,delta) end)
	gBC:SetDimensions(winWidth,winHeight)
	gBC2=GetControl(newKey .. "Background")
	gBC2:SetAlpha(tom.vars.BGalpha/100)
	gBC2=GetControl(newKey .. "Rolle")
	gBC2:SetDimensions(winWidth-20,winHeight-(WindowGOMblock+10))
	-- Den Rollen-Slider erzeugen/platzieren
	gBC=tom.createRolleSlider(newKey,winWidth-17,WindowGOMblock,winHeight-(WindowGOMblock+10))
	gBC2=GetControl(newKey .. "Rolle")
	gBC:SetMinMax(0,gBC2:GetNumHistoryLines())
	gBC:SetValue(gBC2:GetNumHistoryLines())
end

function tomUI.answerDockedWindow(self)
	local parent=self:GetParent()
	local Key=tom.vars.twt[parent:GetName()].gom
	tom.answerGOM(Key)
end

function tomUI.undockCloseClick(self)
	local parent=self:GetParent()
	tom.undockGOMclose(parent:GetName())
end

function tom.undockGOMclose(windowKey)
	tom.vars.twt[windowKey].act=false
	tom.refreshUIwindow()
end

function tom.undockGOM(Key)
	local twt=tom.searchUndockedWindow(Key,false)
	if twt=="" then
		tom.vars.twtCount=tom.vars.twtCount+1
		twt=tom.windowName .. tom.to2string(tom.to2string(tom.vars.twtCount))
		tom.vars.twt[twt]={}
		tom.vars.twt[twt].X=250+10*tom.vars.twtCount
		tom.vars.twt[twt].Y=250-10*tom.vars.twtCount
		tom.vars.twt[twt].gom=Key
	end
	tom.vars.twt[twt].act=true
	tom.createUndockedWindow(twt,Key)
	tom.connectGOMtoRolle(Key,twt)
	tom.refreshUIwindow()
end

--P5YCH3 - New function for the new Common edit field on the main display.
function tomUI.commonEditEnde(self,process)
	self:SetKeyboardEnabled(false)
	self:LoseFocus()
	if process==true then
		local textEntered=self:GetText()
		--Send an unencrypted message to the chat system.
		tom.sendChatMessage(textEntered,false)
		self:Clear()
	end
end

function tomUI.cryptEditEnde(self,process)
	self:SetKeyboardEnabled(false)
	self:LoseFocus()
	if process==true then
		local textEntered=self:GetText()
		-- verschleiert an das Chatsystem senden
		-- send obfuscated to the chat system (enrypted)
		tom.sendChatMessage(textEntered,true)
		self:Clear()
	end
end

function tomUI.ClipboardEditEnde(self)
	self:SetKeyboardEnabled(false)
	self:LoseFocus()
end

function tomUI.catacombNameClick()
	tomCatacombNameText:SetHidden(true)
	-- das EditFeld stattdessen anzeigen
	tomCatacombNameEdit:SetHidden(false)
	tomCatacombNameEdit:SetKeyboardEnabled(false)
	tomCatacombNameEdit:TakeFocus()
	tomCatacombNameEdit:SetText(tomCatacombNameText:GetText())
end

function tomUI.catacombNameEnde(self)
	tomCatacombNameEdit:SetKeyboardEnabled(false)
	tomCatacombNameEdit:LoseFocus()
	-- den Namen eintragen
	local textEntered=self:GetText()
	if textEntered>" "==false then textEntered=nil end
	tom.vars.CatacombNames[tom.vars.CatacombScrollsPage]=textEntered
	-- das Textfeld stattdessen wieder anzeigen
	tomCatacombNameText:SetText(textEntered)
	tomCatacombNameText:SetHidden(false)
	tomCatacombNameEdit:SetHidden(true)
end

function tomUI.magicStoreBack(self)
	self:SetKeyboardEnabled(false)
	self:LoseFocus()
	tom.magicLomTransport(tom.vars.shownLOM,false)
end

function tom.expandTokens(message)
	local temp=message
	local xTarget=tomCatacombTarget:GetText()
	local xStandort=GetUnitZone("player")
	local xStandort=tom.truncatMale(GetMapName())
	local xCharName=GetUnitName("player")
	local xAccount=GetUnitDisplayName("player")
	temp=string.gsub(temp,"%%t",xTarget)
	temp=string.gsub(temp,"%%o",xStandort)
	temp=string.gsub(temp,"%%c",xCharName)
	temp=string.gsub(temp,"%%a",xAccount)
	return temp
end

function tomUI.CatacombEditEnde()
	tomCatacombEdit:SetKeyboardEnabled(false)
	tomCatacombEdit:LoseFocus()
	local textEntered=tomCatacombEdit:GetText()
	if tom.vars.CatacombMessageIndex~=0 then
		-- geänderten Text zurückspeichern
		tom.vars.CatacombMessage=textEntered
		tom.vars.CatacombScrollsText[tom.vars.CatacombMessageIndex]=textEntered
		tom.loadCatacombScrollPage()
	end
end

function tomUI.CatacombScrollPageClick(direction)
	if direction==true then
		tom.vars.CatacombScrollsPage=tom.vars.CatacombScrollsPage+1
		if tom.vars.CatacombScrollsPage>tom.CatacombScrollsMaxPages then tom.vars.CatacombScrollsPage=1 end
	else
		tom.vars.CatacombScrollsPage=tom.vars.CatacombScrollsPage-1
		if tom.vars.CatacombScrollsPage<1 then tom.vars.CatacombScrollsPage=tom.CatacombScrollsMaxPages end
	end
	tom.loadCatacombScrollPage()
end

--P5YCH3 - TOM Reborn - New function to toggle the main display bar language between Common and TOMish.
function tomUI.MainWindowToggleCoding(self)
	if tom.vars.MainWindowCoding==1 then tom.vars.MainWindowCoding=2 else tom.vars.MainWindowCoding=1 end
	tom.refreshUIwindow()
end

--P5YCH3 - TOM Reborn - New function to change the channel for the main display bar.
	--{"/z","/g1","/g2","/g3","/g4","/g5","/p","/s","/y","/e"}
function tomUI.MainWindowChangeChannel(self)
	if tom.vars.MainWindowChannel==1 then --/z
		tom.vars.MainWindowChannel=2
		tom.sendChatMessage("/g1 ", false)
	elseif tom.vars.MainWindowChannel==2 then--/g1
		tom.vars.MainWindowChannel=3
		tom.sendChatMessage("/g2 ", false)
	elseif tom.vars.MainWindowChannel==3 then--/g2
		tom.vars.MainWindowChannel=4
		tom.sendChatMessage("/g3 ", false)
	elseif tom.vars.MainWindowChannel==4 then--/g3
		tom.vars.MainWindowChannel=5
		tom.sendChatMessage("/g4 ", false)
	elseif tom.vars.MainWindowChannel==5 then--/g4
		tom.vars.MainWindowChannel=6
		tom.sendChatMessage("/g5 ", false)
	elseif tom.vars.MainWindowChannel==6 then--/g5
		tom.vars.MainWindowChannel=7
		tom.sendChatMessage("/p ", false)
	elseif tom.vars.MainWindowChannel==7 then--/p
		tom.vars.MainWindowChannel=8
		tom.sendChatMessage("/s ", false)
	elseif tom.vars.MainWindowChannel==8 then--/s
		tom.vars.MainWindowChannel=9
		tom.sendChatMessage("/y ", false)
	elseif tom.vars.MainWindowChannel==9 then--/y
		tom.vars.MainWindowChannel=10
		tom.sendChatMessage("/e ", false)
	elseif tom.vars.MainWindowChannel==10 then--/e
		tom.vars.MainWindowChannel=1
		tom.sendChatMessage("/z ", false)
	end
	tom.refreshUIwindow()

	if tom.vars.MainWindowCoding == 2 then
		tomWindow01Crypt:SetKeyboardEnabled(true)
		tomWindow01Crypt:TakeFocus()
	end
end

function tomUI.CatacombToggleCoding(self)
	if tom.vars.CatacombCoding==1 then tom.vars.CatacombCoding=2 else tom.vars.CatacombCoding=1 end
	tom.refreshCatacombUI()
end

function tomUI.CatacombButtonHandler(event, button)
	local buttonName=event:GetName()
	local CatacombIndex=0
	--================================================================================
	--Button name="tomInsKill"
	--================================================================================
	if string.sub(buttonName,1,18)=="tomCatacombInsKill" then
		CatacombIndex=string.sub(buttonName,19,20)
		local pageIndex=CatacombIndex+0
		CatacombIndex=CatacombIndex+tom.CatacombRows*(tom.vars.CatacombScrollsPage-1)
		--=====================================================================
		if button==1 then --if left click..
			-- Zeile Einfügen wenn möglich
			-- Insert line if possible
			if tom.vars.CatacombScrollsText[CatacombIndex+tom.CatacombRows-pageIndex]==nil then
				-- eine Zeile durch hinaufschieben einfügen
				-- insert a line by dragging it up
				if pageIndex<tom.CatacombRows then
					for looper=tom.CatacombRows-pageIndex,1,-1 do
						tom.vars.CatacombScrollsText[CatacombIndex+looper]=tom.vars.CatacombScrollsText[CatacombIndex+looper-1]
					end
				end
				tom.vars.CatacombScrollsText[CatacombIndex]=nil
				tom.loadCatacombScrollPage()
			else
				-- Kein Platz zum Einfügen
				-- No space to paste
				tom.sendMessage(tom.locMsg(89),true)
			end
		--=====================================================================
		elseif button==2 then --if right click..
			-- diese Zeile durch herunterziehen löschen
			-- delete this line by dragging it down
			if pageIndex<tom.CatacombRows then
				for looper=1,tom.CatacombRows-pageIndex,1 do
					tom.vars.CatacombScrollsText[CatacombIndex+looper-1]=tom.vars.CatacombScrollsText[CatacombIndex+looper]
				end
			end
			tom.vars.CatacombScrollsText[CatacombIndex+tom.CatacombRows-pageIndex]=nil
			tom.loadCatacombScrollPage()
		--=====================================================================
		else --if middle click..
			-- nichts zu tun für button 3 oder Andere
			-- nothing to do for button 3 or others
		end
	end
	--==========================================================================================================
	--Label name="tomCataText"
	--==========================================================================================================
	if string.sub(buttonName,1,15)=="tomCatacombText" then
		-- Catacomb editieren
		CatacombIndex=string.sub(buttonName,16,17)
		CatacombIndex=CatacombIndex+tom.CatacombRows*(tom.vars.CatacombScrollsPage-1)
		tom.vars.CatacombMessageIndex=CatacombIndex
		tomCatacombEdit:SetText(tom.vars.CatacombScrollsText[tom.vars.CatacombMessageIndex])
		tomCatacombEdit:SetKeyboardEnabled(true)
		tomCatacombEdit:TakeFocus()
	end
	--==========================================================================================================
	--Button name="tomSndEdt"
	--==========================================================================================================
	if string.sub(buttonName,1,17)=="tomCatacombSndEdt" then
		CatacombIndex=string.sub(buttonName,18,19)
		CatacombIndex=CatacombIndex+tom.CatacombRows*(tom.vars.CatacombScrollsPage-1)
		tom.vars.CatacombMessageIndex=CatacombIndex
		tomCatacombEdit:SetText(tom.vars.CatacombScrollsText[tom.vars.CatacombMessageIndex])
		--=====================================================================
		if button==1 then --if left click..
			-- Catacomb an Target senden
			-- Send catacomb to target
			if tom.vars.CatacombScrollsText[tom.vars.CatacombMessageIndex]~=nil then
				local gomPrefix=tom.getGOMprefix(tonumber(tomCatacombGom:GetText()))
				if gomPrefix~=nil then
					tom.sendChatMessage(gomPrefix,false)
					tom.sendChatMessage(tom.expandTokens(tom.vars.CatacombScrollsText[tom.vars.CatacombMessageIndex]),tom.vars.CatacombCoding==2)
				else
					tom.sendMessage(tom.locMsg(43),true) --locTxt[43], locMsg(43)
				end
			end
		--=====================================================================
		elseif button==2 then --if right click..
			-- Catacomb an Gildenfenster senden
			-- Send catacomb to guild window
			if tom.vars.CatacombScrollsText[tom.vars.CatacombMessageIndex]~=nil then
				tom.sendCatacombToGuild(tom.expandTokens(tom.vars.CatacombScrollsText[tom.vars.CatacombMessageIndex]))
			end
		--=====================================================================
		else --if middle click..
			-- bei Button 3 (oder Anderen) an den Chat senden
			-- send to chat at button 3 (or others).
			--tom.answerGOM(tom.vars.twt[tom.windowNameMain].gom)
			if tom.vars.CatacombScrollsText[tom.vars.CatacombMessageIndex]~=nil then
				tom.sendChatMessage(tom.expandTokens(tom.vars.CatacombScrollsText[tom.vars.CatacombMessageIndex]),tom.vars.CatacombCoding==2)
			end
		end
	end
end

function tom.sendCatacombToGuild(TextToSend)
	local pos=string.find(TextToSend,";",1,true)
	if pos then
		tom.vars.GuildSubject=string.sub(TextToSend,1,pos-1)
		tom.vars.GuildMessage=string.sub(TextToSend,pos+1)
		tom.refreshGuildUI()
	else
		tom.vars.GuildSubject="TOMmail"
		tom.vars.GuildMessage=TextToSend
		tom.refreshGuildUI()
	end
	if tom.vars.requestedGuildState~=true then tom.vars.requestedGuildState=true end
end

function tom.loadCatacombScrollPage()
	tomCatacombScrollsPage:SetText(tom.vars.CatacombScrollsPage)
	tomCatacombSlider:SetValue(tom.vars.CatacombScrollsPage)
	for looper=1,tom.CatacombRows,1 do
		local CatacombText=GetControl("tomCatacombText"..tostring(looper))
		CatacombText:SetText(tom.vars.CatacombScrollsText[looper+tom.CatacombRows*(tom.vars.CatacombScrollsPage-1)])
	end
	tomCatacombNameText:SetText(tom.vars.CatacombNames[tom.vars.CatacombScrollsPage])
end

function tom.OnCatacombSliderMove(value)
	if tom.PlayerReady==true then
		tom.vars.CatacombScrollsPage=value
		tom.loadCatacombScrollPage()
	end
end

function tom.UpdateGuildList()
	if tom.guildindex<=tom.guildButtons then
		tom.slider3:SetHidden(true)
	else
		tom.slider3:SetMinMax(0,tom.guildindex-tom.guildButtons+1)
		tom.slider3:SetHidden(false)
	end
end

function tom.createGUILDbutton(nButton)
	local guildButtonControl=GetControl("tomGuildButton"..tom.to2string(nButton))
	if guildButtonControl==nil then guildButtonControl=CreateControlFromVirtual("tomGuildButton"..tom.to2string(nButton), tomGuild, "tomGuildButton") end
	guildButtonControl:SetDimensions(tom.guildbuttonwidth,tom.guildbuttonheight-2)
	guildButtonControl:SetAnchor(TOPLEFT,tomGuild,TOPLEFT,40,tom.GuildBlock3+(nButton-1)*tom.guildbuttonheight)
	guildButtonControl:SetFont(tom.tomFont(67,16))
	guildButtonControl:SetText(tostring(nButton))
	guildButtonControl:SetHandler("OnMouseUp", function(self,button) tomUI.OnGuildClick(button,self:GetName()) end)
	if nButton==1 then
		-- den Tooltiptext nur an den ersten Button binden
		-- Bind the tooltip text only to the first button
		guildButtonControl:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[108]) end)
		guildButtonControl:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	end
	guildButtonControl=GetControl("tomGuildStatusButton"..tom.to2string(nButton))
	if guildButtonControl==nil then guildButtonControl=CreateControlFromVirtual("tomGuildStatusButton"..tom.to2string(nButton),tomGuild,"tomGuildStatusButton") end
	guildButtonControl:SetDimensions(tom.guildstatusbuttonwidth,tom.guildbuttonheight-2)
	guildButtonControl:SetAnchor(TOPLEFT,tomGuild,TOPLEFT,10,tom.GuildBlock3+(nButton-1)*tom.guildbuttonheight)
end

function tom.createSCANbutton(nButton)
	local scanButtonControl=GetControl("tomScanButton"..tom.to2string(nButton))
	if scanButtonControl==nil then scanButtonControl=CreateControlFromVirtual("tomScanButton"..tom.to2string(nButton),tomScan,"tomScanButton") end
	scanButtonControl:SetDimensions(tom.scanbuttonwidth,tom.scanbuttonheight-2)
	scanButtonControl:SetAnchor(TOPLEFT,tomScan,TOPLEFT,20,50+(nButton-1)*tom.scanbuttonheight)
	scanButtonControl:SetFont(tom.tomFont(67,16))
	scanButtonControl:SetHandler("OnMouseUp", function(self,button) tom.OnScanClick(button,self:GetName()) end)
end

function tom.UpdateGuildButtons(nFirst)
	if nFirst>0 then
		tom.guildFirstButton=nFirst
		local Looper=1
		while Looper<=tom.guildButtons do
			local index=nFirst+Looper-1
			local button=GetControl("tomGuildButton"..tom.to2string(Looper))
			if index<=tom.guildindex then
				button:SetHidden(false)
				if tom.vars.queryAccount==true then
					button:SetText(tom.guild.maccount[index])
				else
					button:SetText(tom.guild.mchar[index])
				end
				if index==tom.guildactive then
					button:SetColor(0.9,0.9,0.9,1)
				else
					button:SetColor(0.9,0.9,0.6,0.6)
				end
				button=GetControl("tomGuildButton"..tom.to2string(Looper).."BG")
				button:SetHidden(false)
				if index==tom.guildactive then
					button:SetAlpha(0.2)
				else
					button:SetAlpha(0)
				end
				button=GetControl("tomGuildStatusButton"..tom.to2string(Looper))
				button:SetHidden(false)
				if tom.guild.mstatus[index]==1 then
					button:SetTexture("/esoui/art/contacts/social_status_online.dds")
				else
					if tom.guild.mstatus[index]==2 then
						button:SetTexture("/esoui/art/contacts/social_status_afk.dds")
					else
						if tom.guild.mstatus[index]==3 then
							button:SetTexture("/esoui/art/contacts/social_status_dnd.dds")
						else
							if tom.guild.mstatus[index]==4 then
								button:SetTexture("/esoui/art/contacts/social_status_offline.dds")
							end
						end
					end
				end
			else
				button:SetHidden(true)
				button:SetText("darfniegesehenwerden")
				button=GetControl("tomGuildStatusButton"..tom.to2string(Looper))
				button:SetHidden(true)
				button=GetControl("tomGuildButton"..tom.to2string(Looper).."BG")
				button:SetHidden(true)
			end
			Looper=Looper+1
		end
	end
end

function tom.guildSetGuildWindow()
	if tom.vars.actualGuild~=0 then
		tomGuildGilde:SetText(tom.vars.Guilds[tom.vars.actualGuild])
	else
		tomGuildGilde:SetText(tom.locTxt[100])
	end
	tomGuildqrySuche:SetText(tom.locTxt[101][1])
	tomGuildqryAuswahl:SetText(tom.locTxt[101][2][tom.vars.queryStatus])
	tomGuildqryZusatz:SetText(tom.locTxt[101][3])
	tomGuildqryGtlt:SetText(tom.locTxt[101][4][tom.vars.queryGtlt])
	tomGuildqryAnzahl:SetText(tom.vars.queryCounts)
	tomGuildqryEinheit:SetText(tom.locTxt[101][5][tom.vars.queryUnits])
	tomGuildqryMode:SetText(tom.locTxt[101][6][tom.vars.queryIgnore])
	tomGuildqryVonGRank:SetText(tom.vars.queryVonGRank)
	tomGuildqryBisGRank:SetText(tom.vars.queryBisGRank)
	if tom.vars.queryVonRank<=50 then
		tomGuildqryVonRank:SetText(tom.vars.queryVonRank)
	else
		tomGuildqryVonRank:SetText("V"..tom.vars.queryVonRank-50)
	end
	if tom.vars.queryBisRank<=50 then
		tomGuildqryBisRank:SetText(tom.vars.queryBisRank)
	else
		tomGuildqryBisRank:SetText("V"..tom.vars.queryBisRank-50)
	end
	tomGuildFooterLMTAction:SetText(tom.locTxt[95][tom.vars.queryLMT])
	tomGuildFooterRMTAction:SetText(tom.locTxt[95][tom.vars.queryRMT])
	local temp=tom.locTxt[102]
	temp=string.gsub(temp,"#",tom.guildindex,1)
	tomGuildFooterDisplayed:SetText(temp)
end

function tom.removeFromMailQueue(mailQindex,transportToFailedMailQ)
	if mailQindex<=tom.vars.mailQueueindex then
		if transportToFailedMailQ==true then
			tom.vars.failedMailQueueindex=tom.vars.failedMailQueueindex+1
			tom.vars.failedMailQueue.mTO[tom.vars.failedMailQueueindex]=tom.vars.mailQueue.mTO[mailQindex]
			tom.vars.failedMailQueue.mSUB[tom.vars.failedMailQueueindex]=tom.vars.mailQueue.mSUB[mailQindex]
			tom.vars.failedMailQueue.mTEXT[tom.vars.failedMailQueueindex]=tom.vars.mailQueue.mTEXT[mailQindex]
		end
		if tom.vars.mailQueueindex>mailQindex then
			-- herunterziehen eines Eintrages
			for looper=mailQindex,tom.vars.mailQueueindex-1,1 do
				tom.vars.mailQueue.mTO[looper]=tom.vars.mailQueue.mTO[looper+1]
				tom.vars.mailQueue.mSUB[looper]=tom.vars.mailQueue.mSUB[looper+1]
				tom.vars.mailQueue.mTEXT[looper]=tom.vars.mailQueue.mTEXT[looper+1]
			end
		end
		-- löschen des höchsten Eintrages
		tom.vars.mailQueue.mTO[tom.vars.mailQueueindex]=nil
		tom.vars.mailQueue.mSUB[tom.vars.mailQueueindex]=nil
		tom.vars.mailQueue.mTEXT[tom.vars.mailQueueindex]=nil
		tom.vars.mailQueueindex=tom.vars.mailQueueindex-1
	end
end

function tom.translateMailerror(reason)
	local temp=""
	if reason==MAIL_SEND_RESULT_CANT_SEND_TO_SELF then temp=tom.locMsg(118)
	elseif reason==MAIL_SEND_RESULT_FAIL_MAILBOX_FULL then temp=tom.locMsg(119)
	elseif reason==MAIL_SEND_RESULT_NOT_ENOUGH_MONEY then temp=tom.locMsg(120)
	else temp=tostring(reason) end
	return temp
end

function tom.sendMailFailure(event,reason)
	if tom.wait4mail==true then
		local temp=tom.locMsg(112,tom.vars.mailQueue.mTO[tom.MailInQueue],tom.vars.mailQueue.mSUB[tom.MailInQueue],tom.translateMailerror(reason))
		-- die fehlgeschlagene Mail dokumentieren
		tom.sendMessage(temp,true)
		tom.removeFromMailQueue(tom.MailInQueue,true)
		-- die nicht gesendeten Nachrichten anzeigen
		tom.refreshFailedUI(doRebuild)
		tom.vars.requestedFailState=true
		tom.wait4mail=false
	end
end

function tom.sendMailSuccess()
	if tom.wait4mail==true then
		local temp=tom.locMsg(111,tom.vars.mailQueue.mTO[tom.MailInQueue],tom.vars.mailQueue.mSUB[tom.MailInQueue])
		-- die Mail dokumentieren
		tom.sendSystemMessage(temp)
		tom.removeFromMailQueue(tom.MailInQueue,false)
		tom.wait4mail=false
	end
end

function tom.sendMailopenMailBox()
	tom.MailBoxOpen=true
end

function tom.sendMailcloseMailBox()
	tom.MailBoxOpen=false
end

function tom.sendQueuedMail()
	if ((tom.wait4mail==false) and (tom.vars.mailQueueindex>0)) then
		tom.wait4mail=true
		-- EINEN MailQueue-Eintrag senden (pro Aufruf dieser Funktion)
		local mailboxwasopen=tom.MailBoxOpen
		if tom.MailBoxOpen==false then RequestOpenMailbox() end
		-- die erste geqeuete Mail senden (FIFO)
		tom.MailInQueue=1
		SendMail(tom.vars.mailQueue.mTO[tom.MailInQueue], tom.vars.mailQueue.mSUB[tom.MailInQueue], tom.vars.mailQueue.mTEXT[tom.MailInQueue])
		if mailboxwasopen==false then CloseMailbox() end
	end
end

function tom.addtoMailQueue(mailTO,mailSUB,mailTEXT)
	tom.vars.mailQueueindex=tom.vars.mailQueueindex+1
	tom.vars.mailQueue.mTO[tom.vars.mailQueueindex]=mailTO
	tom.vars.mailQueue.mSUB[tom.vars.mailQueueindex]=mailSUB
	tom.vars.mailQueue.mTEXT[tom.vars.mailQueueindex]=mailTEXT
end

function tom.addToGuild(xname,xplayerStatus,xsecsSinceLogoff,xhasCharacter,xcharacterName,xzoneName,xclassType,xalliance,xlevel,xveteranRank,xRankIndex)
	tom.guildindex=tom.guildindex+1
	tom.guild.maccount[tom.guildindex]=xname
	tom.guild.mstatus[tom.guildindex]=xplayerStatus
	tom.guild.msecsoff[tom.guildindex]=xsecsSinceLogoff
	if xhasCharacter==true then
		tom.guild.mchar[tom.guildindex]=tom.truncatMale(xcharacterName)
	else
		tom.guild.mchar[tom.guildindex]=""
	end
	tom.guild.mzone[tom.guildindex]=tom.truncatMale(xzoneName)
	tom.guild.mclasstype[tom.guildindex]=xclassType
	tom.guild.malliance[tom.guildindex]=xalliance
	tom.guild.mlevel[tom.guildindex]=xlevel
	tom.guild.mveteranRank[tom.guildindex]=xveteranRank
	tom.guild.mRank[tom.guildindex]=xRankIndex
end

function tom.GuildMemberInfo(index) --list status
	local link=tom.createPlayerLink(tom.guild.mchar[index] .. tom.guild.maccount[index]).."|c"..tom.chatcolor
	local klasse=tom.locTxt[107][tom.guild.mclasstype[index]]
	if klasse==nil then klasse="" end
	local vrank=tom.guild.mlevel[index]
	if tom.guild.mveteranRank[index]~=0 then
		vrank="V"..tom.guild.mveteranRank[index]
	end
	local allianz=tom.locTxt[106][tom.guild.malliance[index]]
	if allianz==nil then allianz="" end
	local link2=tom.createPlayerLink(tom.guild.maccount[index]).."|c"..tom.chatcolor
	local pzone=tom.guild.mzone[index]
	local temp=tom.locMsg(105,link,klasse,vrank,allianz,link2,pzone)
	if tom.guild.mstatus[index]<4 then
		temp=temp.."online "
	else
		temp=temp.."offline " .. FormatTimeSeconds(tom.guild.msecsoff[index], TIME_FORMAT_STYLE_DESCRIPTIVE, TIME_FORMAT_PRECISION_SECONDS, TIME_FORMAT_DIRECTION_NONE)
	end
	temp=temp.."|r"
	return temp
end

function tom.guildReadGuild()
	tom.guild={maccount={},mstatus={},msecsoff={},mchar={},mzone={},mclasstype={},malliance={},mlevel={},mveteranRank={},mRank={}}
	tom.guildindex=0
	if tom.vars.actualGuild~=0 then
		local multi=1
		if tom.vars.queryUnits==1 then
			multi=60
		else
			if tom.vars.queryUnits==2 then
				multi=3600
			else
				if tom.vars.queryUnits==3 then
					multi=86400
				else
					if tom.vars.queryUnits==4 then
						multi=2678400
					end
				end
			end
		end
		local offseconds=tom.vars.queryCounts*multi
		local guildID=GetGuildId(tom.vars.actualGuild)
		local guildMembers=GetNumGuildMembers(guildID) 
		local looper=0
		while looper<guildMembers do
			looper=looper+1
			local xname, xnote, xrankIndex, xplayerStatus, xsecsSinceLogoff=GetGuildMemberInfo(guildID, looper)
			local xhasCharacter, xcharacterName, xzoneName, xclassType, xalliance, xlevel, xveteranRank=GetGuildMemberCharacterInfo(guildID, looper)
			-- grundsaetzlich anzeigen
			-- basically show
			local bAddMember=true
			if (tom.vars.queryStatus==2) and (xplayerStatus==4) then
				-- online sollte gesucht werden, member ist aber offline
				-- should be searched online, but member is offline
				bAddMember=false
			end
			if (tom.vars.queryStatus==3) and (xplayerStatus<4) then
				-- onffline sollte gesucht werden, member ist aber online
				-- onffline should be searched, but member is online
				bAddMember=false
			end
			if tom.vars.queryIgnore==1 then
				if tom.vars.queryGtlt==1 then
					if xsecsSinceLogoff<offseconds then
						-- nicht lange offline genug
						-- not offline long enough
						bAddMember=false
					end
				else
					if xsecsSinceLogoff>offseconds then
						-- zu lange offline
						-- offline for too long
						bAddMember=false
					end
				end
			end
			if ((xrankIndex<tom.vars.queryVonGRank) or (xrankIndex>tom.vars.queryBisGRank)) then
				-- nicht im richtigen Gildenrang
				-- not in the right guild rank
				bAddMember=false
			end
			local xRealRank=xlevel+xveteranRank
			if ((xRealRank<tom.vars.queryVonRank) or (xRealRank>tom.vars.queryBisRank)) then
				-- nicht im richtigen Levelbereich
				-- not in the right level range
				bAddMember=false
			end
			if bAddMember==true then
				tom.addToGuild(xname,xplayerStatus,xsecsSinceLogoff,xhasCharacter,xcharacterName,xzoneName,xclassType,xalliance,xlevel,xveteranRank,xrankIndex)
			end
		end
		-- Die Gildenauflistung sortieren
		-- Sort the guild listing
		local bswitched=true
		local firstElem=1
		local lastElem=tom.guildindex
		while bswitched==true do
			bswitched=false
			looper=firstElem
			while looper<lastElem do
				if ((tom.vars.queryAccount==true) and (tom.guild.maccount[looper]>tom.guild.maccount[looper+1])) or ((tom.vars.queryAccount==false) and (tom.guild.mchar[looper]>tom.guild.mchar[looper+1])) then
					local xaccount=tom.guild.maccount[looper]
					local xstatus=tom.guild.mstatus[looper]
					local xsecsoff=tom.guild.msecsoff[looper]
					local xchar=tom.guild.mchar[looper]
					local xzone=tom.guild.mzone[looper]
					local xclasstype=tom.guild.mclasstype[looper]
					local xalliance=tom.guild.malliance[looper]
					local xlevel=tom.guild.mlevel[looper]
					local xveteranRank=tom.guild.mveteranRank[looper]
					local xRank=tom.guild.mRank[looper]
					tom.guild.maccount[looper]=tom.guild.maccount[looper+1]
					tom.guild.mstatus[looper]=tom.guild.mstatus[looper+1]
					tom.guild.msecsoff[looper]=tom.guild.msecsoff[looper+1]
					tom.guild.mchar[looper]=tom.guild.mchar[looper+1]
					tom.guild.mzone[looper]=tom.guild.mzone[looper+1]
					tom.guild.mclasstype[looper]=tom.guild.mclasstype[looper+1]
					tom.guild.malliance[looper]=tom.guild.malliance[looper+1]
					tom.guild.mlevel[looper]=tom.guild.mlevel[looper+1]
					tom.guild.mveteranRank[looper]=tom.guild.mveteranRank[looper+1]
					tom.guild.mRank[looper]=tom.guild.mRank[looper+1]
					tom.guild.maccount[looper+1]=xaccount
					tom.guild.mstatus[looper+1]=xstatus
					tom.guild.msecsoff[looper+1]=xsecsoff
					tom.guild.mchar[looper+1]=xchar
					tom.guild.mzone[looper+1]=xzone
					tom.guild.mclasstype[looper+1]=xclasstype
					tom.guild.malliance[looper+1]=xalliance
					tom.guild.mlevel[looper+1]=xlevel
					tom.guild.mveteranRank[looper+1]=xveteranRank
					tom.guild.mRank[looper+1]=xRank
					bswitched=true
				end
				looper=looper+1
			end
			lastElem=lastElem-1
		end
	end
	tom.refreshGuildUI()
	tom.guildIsReaded=true
end

function tom.processGuildRequest(button,index)
	-- Gildenfunktion ausführen
	-- Perform guild function
	local actionToProcess=tom.vars.queryLMT
	if button==2 then actionToProcess=tom.vars.queryRMT end
	if actionToProcess==1 then
		-- Gildenfunktion "Status ausgeben"
		-- Guild Function "Output Status"
		tom.sendMessage(tom.GuildMemberInfo(index),false)
	elseif actionToProcess==2 then
		-- Gildenfunktion "zu Spieler reisen"
		--Guild function "travel to player"
		JumpToGuildMember(tom.guild.maccount[index])
	elseif actionToProcess==3 then
		-- Gildenfunktion "Mail senden"
		-- Guild Function "Send Mail"
		if ((string.len(tomGuildBetreff:GetText())>0) and (string.len(tomGuildNachricht:GetText())>0)) then
			tom.addtoMailQueue(tom.guild.maccount[index],tomGuildBetreff:GetText(),tomGuildNachricht:GetText())
		else
			tom.sendMessage(tom.locTxt[110],true)
		end
	elseif actionToProcess==4 then
		-- Gildenfunktion "Betreff fluestern"
		-- Guild function "whisper subject"
		tom.sendChatMessage("/w "..tom.guild.maccount[index].." "..tomGuildBetreff:GetText())
	elseif actionToProcess==5 then
		-- Gildenfunktion "Nachricht fluestern"
		-- Guild Feature "Whisper Message"
		tom.sendChatMessage("/w "..tom.guild.maccount[index].." "..tomGuildNachricht:GetText())
	elseif actionToProcess==6 then
		-- Gildenfunktion "aus Gilde entfernen"
		-- Guild function "remove from guild"
		GuildRemove(GetGuildId(tom.vars.actualGuild),tom.guild.maccount[index])
	elseif actionToProcess==7 then
		-- Gildenfunktion "Mail an ALLE angezeigten"
		-- Guild function "Mail to ALL displayed"
		local mBetreff=tomGuildBetreff:GetText()
		local mText=tomGuildNachricht:GetText()
		if ((string.len(mBetreff)>0) and (string.len(mText)>0)) then
			local looper=0
			while looper<tom.guildindex do
				looper=looper+1
				tom.addtoMailQueue(tom.guild.maccount[looper],mBetreff,mText)
			end
		else
			tom.sendMessage(tom.locTxt[110],true)
		end
	elseif actionToProcess==8 then
		-- Gildenfunktion "Betreff>Gildenchat"
		-- Guild Function "Subject>Guild Chat"
		tom.sendChatMessage("/g"..tostring(tom.vars.actualGuild).." "..tomGuildBetreff:GetText())
	elseif actionToProcess==9 then
		-- Gildenfunktion "Nachricht>Gildenchat"
		-- Guild Function "Message>Guild Chat"
		tom.sendChatMessage("/g"..tostring(tom.vars.actualGuild).." "..tomGuildNachricht:GetText())
	end
end

function tomUI.OnGuildClick(button,guildButtonName)
	-- Anwender drückt auf einen Gilden-Knopf
	-- User presses a guild button
	local ButtonNum=string.sub(guildButtonName,15,16)+0
	tom.guildactive=ButtonNum+tom.guildFirstButton-1
	tom.UpdateGuildButtons(tom.slider3:GetValue())
	tom.processGuildRequest(button,ButtonNum+tom.guildFirstButton-1)
end

function tomUI.RefreshGuildClick()
	-- Anwender drückt auf Gildenrefresh
	-- User presses guild refresh
	tom.guildNextGuild(false)
end

function tomUI.GuildMessageTextChanged(edb)
	local lenDisplay=string.len(edb).."/"..tom.maxGuildMessageLength
	tomGuildNachrichtLen:SetText(lenDisplay)
end

function tom.queryRMTDo(value)
	tom.vars.queryRMT=tom.vars.queryRMT+value
	if tom.vars.queryRMT>tom.guildMouseActions then
		tom.vars.queryRMT=1
	end
	if tom.vars.queryRMT<1 then
		tom.vars.queryRMT=tom.guildMouseActions
	end
	tom.guildSetGuildWindow()
end

function tom.queryLMTDo(value)
	tom.vars.queryLMT=tom.vars.queryLMT+value
	if tom.vars.queryLMT>tom.guildMouseActions then
		tom.vars.queryLMT=1
	end
	if tom.vars.queryLMT<1 then
		tom.vars.queryLMT=tom.guildMouseActions
	end
	tom.guildSetGuildWindow()
end

function tomUI.queryLMTClick(button)
	-- Anwender ändert Query-Auswahl
	if button==1 then tom.queryLMTDo(1) else tom.queryLMTDo(-1) end
end

function tomUI.queryRMTClick(button)
	-- Anwender ändert Query-Auswahl
	if button==1 then tom.queryRMTDo(1) else tom.queryRMTDo(-1) end
end

function tomUI.NachrichtStart()
	tomGuildNachricht:SetKeyboardEnabled(true)
	tomGuildNachricht:TakeFocus()
end

function tomUI.BetreffStart()
	tomGuildBetreff:SetKeyboardEnabled(true)
	tomGuildBetreff:TakeFocus()
end

function tomUI.NachrichtEnde(bZuBetreff)
	tomGuildNachricht:SetKeyboardEnabled(false)
	tomGuildNachricht:LoseFocus()
	tom.vars.GuildMessage=tomGuildNachricht:GetText()
	if bZuBetreff==true then tomUI.BetreffStart() end
end

function tomUI.BetreffEnde(bZuNachricht)
	tomGuildBetreff:SetKeyboardEnabled(false)
	tomGuildBetreff:LoseFocus()
	tom.vars.GuildSubject=tomGuildBetreff:GetText()
	if bZuNachricht==true then tomUI.NachrichtStart() end
end

function tom.queryModeDo(value)
	tom.vars.queryIgnore=tom.vars.queryIgnore+value
	if tom.vars.queryIgnore>2 then tom.vars.queryIgnore=1 end
	if tom.vars.queryIgnore<1 then tom.vars.queryIgnore=2 end
	tom.guildReadGuild()
end

function tomUI.queryModeClick(button)
	-- Anwender ändert Query-Auswahl
	if button==1 then tom.queryModeDo(1) else tom.queryModeDo(-1) end
end

function tom.queryEinheitDo(value)
	tom.vars.queryUnits=tom.vars.queryUnits+value
	if tom.vars.queryUnits>4 then tom.vars.queryUnits=1 end
	if tom.vars.queryUnits<1 then tom.vars.queryUnits=4 end
	tom.guildReadGuild()
end

function tomUI.queryEinheitClick(button)
	-- Anwender ändert Query-Auswahl
	if button==1 then tom.queryEinheitDo(1) else tom.queryEinheitDo(-1) end
end

function tom.queryBisGRankDo(value)
	tom.vars.queryBisGRank=tom.vars.queryBisGRank+value
	if tom.vars.queryBisGRank>10 then tom.vars.queryBisGRank=tom.vars.queryVonGRank end
	if tom.vars.queryBisGRank<tom.vars.queryVonGRank then tom.vars.queryBisGRank=10 end
	tom.guildReadGuild()
end

function tomUI.queryBisGRankClick(button)
	-- Anwender ändert Query-Auswahl VON Gildenrang
	if button==1 then tom.queryBisGRankDo(1) else tom.queryBisGRankDo(-1) end
end

function tom.queryVonGRankDo(value)
	tom.vars.queryVonGRank=tom.vars.queryVonGRank+value
	if tom.vars.queryVonGRank>tom.vars.queryBisGRank then tom.vars.queryVonGRank=1 end
	if tom.vars.queryVonGRank<1 then tom.vars.queryVonGRank=tom.vars.queryBisGRank end
	tom.guildReadGuild()
end

function tomUI.queryVonGRankClick(button)
	-- Anwender ändert Query-Auswahl VON Gildenrang
	if button==1 then tom.queryVonGRankDo(1) else tom.queryVonGRankDo(-1) end
end

function tom.queryBisRankDo(value)
	tom.vars.queryBisRank=tom.vars.queryBisRank+value
	if tom.vars.queryBisRank>3600 then tom.vars.queryBisRank=tom.vars.queryVonRank end
	if tom.vars.queryBisRank<tom.vars.queryVonRank then tom.vars.queryBisRank=3600 end
	tom.guildReadGuild()
end

function tomUI.queryBisRankClick(button)
	-- Anwender ändert Query-Auswahl VON Rang
	if button==1 then tom.queryBisRankDo(1) else tom.queryBisRankDo(-1) end
end

function tom.queryVonRankDo(value)
	tom.vars.queryVonRank=tom.vars.queryVonRank+value
	if tom.vars.queryVonRank>tom.vars.queryBisRank then tom.vars.queryVonRank=1 end
	if tom.vars.queryVonRank<1 then tom.vars.queryVonRank=tom.vars.queryBisRank end
	tom.guildReadGuild()
end

function tomUI.queryVonRankClick(button)
	-- Anwender ändert Query-Auswahl VON Rang
	if button==1 then tom.queryVonRankDo(1) else tom.queryVonRankDo(-1) end
end

function tom.queryAnzahlDo(value)
	tom.vars.queryCounts=tom.vars.queryCounts+value
	if tom.vars.queryCounts>31 then tom.vars.queryCounts=1 end
	if tom.vars.queryCounts<1 then tom.vars.queryCounts=31 end
	tom.guildReadGuild()
end

function tomUI.queryAnzahlClick(button)
	-- Anwender ändert Query-Auswahl
	if button==1 then tom.queryAnzahlDo(1) else tom.queryAnzahlDo(-1) end
end

function tomUI.queryGtltClick(button)
	-- Anwender ändert Query-groesser/kleiner
	if tom.vars.queryGtlt==1 then tom.vars.queryGtlt=2 else tom.vars.queryGtlt=1 end
	tom.guildReadGuild()
end

function tom.queryAuswahlDo(value)
	tom.vars.queryStatus=tom.vars.queryStatus+value
	if tom.vars.queryStatus>3 then tom.vars.queryStatus=1 end
	if tom.vars.queryStatus<1 then tom.vars.queryStatus=3 end
	tom.guildReadGuild()
end

function tomUI.queryAuswahlClick(button)
	-- Anwender ändert Query-Auswahl
	if button==1 then tom.queryAuswahlDo(1) else tom.queryAuswahlDo(-1) end
end

function tomUI.toggleAcountClick()
	if tom.vars.queryAccount==true then
		tom.vars.queryAccount=false
	else
		tom.vars.queryAccount=true
	end
	tom.guildReadGuild()
end

function tom.rotateGuild()
	local index=tom.vars.actualGuild
	local nextGuild=0
	local loopmax=0
	while ((nextGuild==0) and (loopmax<6)) do
		loopmax=loopmax+1
		index=index+1
		if index>5 then index=index-5 end
		if tom.vars.Guilds[index]~="" then nextGuild=index end
	end
	return nextGuild
end

function tom.guildNextGuild(bRotate)
	--P5YCH3 - Fix for the 'Guild Functions' window index returning a nil value after a reload of the UI.
	--A local variable was incorrectly defined. Changed 'nextguild' to 'nextGuild'..
	local nextGuild=tom.vars.actualGuild --Updated
	if bRotate==true then nextGuild=tom.rotateGuild() end
	if nextGuild~=0 then
		tom.vars.actualGuild=nextGuild
		tom.guildReadGuild()
	else
		tom.sendMessage(tom.locTxt[100])
	end
end

function tom.OnSlider3Move(nvalue)
	tom.UpdateGuildButtons(nvalue)
end

function tomUI.slider3MouseWheel(event,value)
	-- Nur ausfuehren, wenn Das AddON schon geladen ist
	if (tom.loaded == true) then
		tom.slider3:SetValue(tom.slider3:GetValue()-value)
	end
end

function tomUI.NextGuildClick()
	-- Anwender drueckt auf naechste Gilde
	tom.guildNextGuild(true)
end

function tom.updateScanTargets()
	for looper=1,tom.scanTargetMax,1 do
		local button=GetControl("tomScanButton"..tom.to2string(looper))
		if ((tom.vars.scanTargets[looper]~=nil) and (tom.vars.scanTargets[looper][1]~=nil)) then
			button:SetText(tom.vars.scanTargets[looper][2].." ("..tom.vars.scanTargets[looper][3]..")")
		else
			button:SetText(nil)
		end
	end
end

function tom.removeScanTarget(ButtonNum)
	for looper=ButtonNum,tom.scanTargetMax-1,1 do
		if tom.vars.scanTargets[looper]~=nil then
			if tom.vars.scanTargets[looper+1]~=nil then
				if tom.vars.scanTargets[looper+1][1]~=nil then
					tom.vars.scanTargets[looper][1]=tom.vars.scanTargets[looper+1][1]
					tom.vars.scanTargets[looper][2]=tom.vars.scanTargets[looper+1][2]
					tom.vars.scanTargets[looper][3]=tom.vars.scanTargets[looper+1][3]
				else
					tom.vars.scanTargets[looper][1]=nil
					tom.vars.scanTargets[looper][2]=nil
					tom.vars.scanTargets[looper][3]=nil
				end
			end
		end
	end
	tom.vars.scanTargets[tom.scanTargetMax]={}
	tom.updateScanTargets()
end

function tom.OnScanClick(button,scanButtonName)
	-- Anwender drückt auf einen Scan-Knopf
	-- User presses a scan button
	local ButtonNum=string.sub(scanButtonName,14,15)+0
	if tom.vars.scanTargets[ButtonNum]~=nil then
		if button==1 then
			-- über Katakomben ansprechen
			-- talk about catacombs
			local gomKey=tom.addPerson(tom.vars.scanTargets[ButtonNum][1])
			tom.connectCatacombToGOM(gomKey)
			tom.vars.requestedCatacombState=true
		else
			-- Eintrag entfernen
			-- Remove entry
			tom.removeScanTarget(ButtonNum)
		end
	end
end

function tomUI.scanClearClick()
	for looper=1,tom.scanTargetMax,1 do
		tom.vars.scanTargets[looper]={}
	end
	tom.updateScanTargets()
end

function tom.addScanTarget(xName,xDisplayName,xStufe)
	local isFound=false
	for looper=1,tom.scanTargetMax,1 do
		if tom.vars.scanTargets[looper]~=nil then
			if tom.vars.scanTargets[looper][1]==xDisplayName then
				isFound=true
			end
		end
	end
	if isFound==false then
		for looper=tom.scanTargetMax,2,-1 do
			if tom.vars.scanTargets[looper]==nil then tom.vars.scanTargets[looper]={} end
			if tom.vars.scanTargets[looper-1]~=nil then
				if tom.vars.scanTargets[looper-1][1]~=nil then
					tom.vars.scanTargets[looper][1]=tom.vars.scanTargets[looper-1][1]
					tom.vars.scanTargets[looper][2]=tom.vars.scanTargets[looper-1][2]
					tom.vars.scanTargets[looper][3]=tom.vars.scanTargets[looper-1][3]
				end
			end
		end
		if tom.vars.scanTargets[1]==nil then tom.vars.scanTargets[1]={} end
		tom.vars.scanTargets[1][1]=xDisplayName
		tom.vars.scanTargets[1][2]=xName
		tom.vars.scanTargets[1][3]=xStufe
		tom.updateScanTargets()
	end
end

function tom.targetChanged()
	if tom.scanTarget==true then
		if IsUnitPlayer("reticleover")==true then
			local xname=GetUnitName("reticleover")
			local xonline=IsUnitOnline("reticleover")
			local xdisplayName=GetUnitDisplayName("reticleover")
			local xstufe=0
			if xonline==true then
				if IsUnitVeteran("reticleover")==true then xstufe="V"..GetUnitVeteranRank("reticleover") else xstufe=GetUnitEffectiveLevel("reticleover") end
				tom.addScanTarget(xname,xdisplayName,xstufe)
			end
		end
	end
end

function tom.snipFailedQueueEntry(Index)
	for looper=Index,tom.vars.failedMailQueueindex-1,1 do
		tom.vars.failedMailQueue.mTO[looper]=tom.vars.failedMailQueue.mTO[looper+1]
		tom.vars.failedMailQueue.mSUB[looper]=tom.vars.failedMailQueue.mSUB[looper+1]
		tom.vars.failedMailQueue.mTEXT[looper]=tom.vars.failedMailQueue.mTEXT[looper+1]
	end
	tom.vars.failedMailQueue.mTO[tom.vars.failedMailQueueindex]=nil
	tom.vars.failedMailQueue.mSUB[tom.vars.failedMailQueueindex]=nil
	tom.vars.failedMailQueue.mTEXT[tom.vars.failedMailQueueindex]=nil
	tom.vars.failedMailQueueindex=tom.vars.failedMailQueueindex-1
end

function tom.resendFailedMail(Index)
	local mTO=tom.vars.failedMailQueue.mTO[Index]
	local mSUB=tom.vars.failedMailQueue.mSUB[Index]
	local mText=tom.vars.failedMailQueue.mTEXT[Index]
	tom.snipFailedQueueEntry(Index)
	tom.refreshFailedUI()
	tom.addtoMailQueue(mTO,mSUB,mText)
end

function tom.deleteFailedMail(Index)
	tom.snipFailedQueueEntry(Index)
	tom.refreshFailedUI()
end

function tom.FMclick(FMno,button)
	local Index=FMno+tom.firstFMbutton-1
	if button==1 then
		tom.resendFailedMail(Index)
	else
		tom.deleteFailedMail(Index)
	end
end

function tomUI.OnFMSliderMove(value)
	tom.firstFMbutton=value
	tom.refreshFailedUI()
end

function tomUI.OnFMScroll(value)
	local SLmin,SLmax=tomfailMailSL1:GetMinMax()
	local SLval=tomfailMailSL1:GetValue()
	if tom.vars.failedMailQueueindex>tom.fmButtons then
		if value<0 then
			if SLval<SLmax then tomfailMailSL1:SetValue(SLval+1) end
		else
			if SLval>SLmin then tomfailMailSL1:SetValue(SLval-1) end
		end
	end
end

function tom.adjustFMbutton(buttonNo,Index)
	local bName="tomfailMailI"..tom.to2string(buttonNo)
	local gBCI=GetControl(bName)
	bName="tomfailMailR"..tom.to2string(buttonNo)
	local gBCR=GetControl(bName)
	bName="tomfailMailS"..tom.to2string(buttonNo)
	local gBCS=GetControl(bName)
	bName="tomfailMailT"..tom.to2string(buttonNo)
	local gBCT=GetControl(bName)
	if Index>tom.vars.failedMailQueueindex then
		gBCI:SetHidden(true)
		gBCR:SetHidden(true)
		gBCS:SetHidden(true)
		gBCT:SetHidden(true)
	else
		gBCR:SetText(tom.vars.failedMailQueue.mTO[Index])
		gBCS:SetText(tom.vars.failedMailQueue.mSUB[Index])
		gBCT:SetText(tom.vars.failedMailQueue.mTEXT[Index])
		gBCI:SetHidden(false)
		gBCR:SetHidden(false)
		gBCS:SetHidden(false)
		gBCT:SetHidden(false)
	end
end

function tom.createFMbutton(nButton,fmbuttonwidth,fmbuttonheight,fmtextwidth,fmrecipientwidth,fmX,fmY)
	local bName="tomfailMailI"..tom.to2string(nButton)
	local gBC=GetControl(bName)
	if nButton<=tom.fmButtons then
		if gBC==nil then gBC=CreateControlFromVirtual(bName,tomfailMail,"tomfailMailButton") end
		gBC:SetDimensions(fmbuttonwidth,fmbuttonheight-2)
		gBC:ClearAnchors()
		gBC:SetAnchor(TOPLEFT,tomfailMail,TOPLEFT,fmX,fmY+(nButton-1)*fmbuttonheight)
		gBC:SetHandler("OnMouseUp", function(self,button) tom.FMclick(tonumber(string.sub(self:GetName(),13,14)),button) end)
		gBC:SetHandler("OnMouseWheel", function(self, delta, ctrl, alt, shift) tomUI.OnFMScroll(delta) end)
		if nButton==1 then
			-- den Tooltiptext nur an den ersten Button binden
			-- Bind the tooltip text only to the first button
			gBC:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[129]) end)
			gBC:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
		end
		gBC:SetHidden(false)
	else
		if gBC~=nil then 
			gBC:ClearAnchors()
			gBC:SetHidden(true)
		end
	end
	bName="tomfailMailR"..tom.to2string(nButton)
	gBC=GetControl(bName)
	if nButton<=tom.fmButtons then
		if gBC==nil then gBC=CreateControlFromVirtual(bName,tomfailMail,"tomfailMailText") end
		gBC:SetDimensions(fmtextwidth,fmbuttonheight-2)
		gBC:SetFont(tom.tomFont(57,16))
		gBC:SetColor(1,1,0.7,1)
		gBC:ClearAnchors()
		gBC:SetAnchor(TOPLEFT,tomfailMail,TOPLEFT,fmX+fmbuttonwidth+10,fmY+(nButton-1)*fmbuttonheight)
		gBC:SetText(tostring(nButton))
		gBC:SetHidden(false)
	else
		if gBC~=nil then 
			gBC:ClearAnchors()
			gBC:SetHidden(true)
		end
	end
	bName="tomfailMailS"..tom.to2string(nButton)
	gBC=GetControl(bName)
	if nButton<=tom.fmButtons then
		if gBC==nil then gBC=CreateControlFromVirtual(bName,tomfailMail,"tomfailMailText") end
		gBC:SetDimensions(fmtextwidth,fmbuttonheight-2)
		gBC:SetFont(tom.tomFont(57,16))
		gBC:SetColor(0.9,0.9,0.9,1)
		gBC:ClearAnchors()
		gBC:SetAnchor(TOPLEFT,tomfailMail,TOPLEFT,fmX+fmbuttonwidth+10+fmrecipientwidth+10,fmY+(nButton-1)*fmbuttonheight)
		gBC:SetText(tostring(nButton))
		gBC:SetHidden(false)
	else
		if gBC~=nil then 
			gBC:ClearAnchors()
			gBC:SetHidden(true)
		end
	end
	bName="tomfailMailT"..tom.to2string(nButton)
	gBC=GetControl(bName)
	if nButton<=tom.fmButtons then
		if gBC==nil then gBC=CreateControlFromVirtual(bName,tomfailMail,"tomfailMailText") end
		gBC:SetDimensions(fmtextwidth,fmbuttonheight-2)
		gBC:SetFont(tom.tomFont(57,16))
		gBC:SetColor(0.9,0.9,0.6,0.6)
		gBC:ClearAnchors()
		gBC:SetAnchor(TOPLEFT,tomfailMail,TOPLEFT,fmX+fmbuttonwidth+10+fmrecipientwidth+10+fmtextwidth+10,fmY+(nButton-1)*fmbuttonheight)
		gBC:SetText(tostring(nButton))
		gBC:SetHidden(false)
	else
		if gBC~=nil then 
			gBC:ClearAnchors()
			gBC:SetHidden(true)
		end
	end
end

function tom.importFromTIM()
	local imported=0
	if tim~=nil then
		local TOMpointer=tom.CatacombScrollsMaxPages*tom.CatacombRows+1
		-- den ersten freien Platz in TOM suchen
		while ((tom.vars.CatacombScrollsText[TOMpointer-1]==nil) and (TOMpointer>1)) do TOMpointer=TOMpointer-1 end
		if TOMpointer<=tom.CatacombScrollsMaxPages*tom.CatacombRows then
			for looper=1,tim.CatacombScrollsMaxPages*tim.CatacombRows,1 do
				if tim.vars.CatacombScrollsText[looper]~=nil then
					if tim.vars.CatacombScrollsText[looper]>" " then
						-- einen freien Platz suchen
						while ((tom.vars.CatacombScrollsText[TOMpointer]~=nil) and (TOMpointer<=tom.CatacombScrollsMaxPages*tom.CatacombRows)) do TOMpointer=TOMpointer+1 end
						if TOMpointer<=tom.CatacombScrollsMaxPages*tom.CatacombRows then
							-- die Daten einfügen
							tom.vars.CatacombScrollsText[TOMpointer]=tim.vars.CatacombScrollsText[looper]
							imported=imported+1
						else
							-- kein Platz mehr in TOM
							tom.sendMessage(tom.locMsg(132),true)
						end
					end
				end
			end
		else
			-- kein Platz mehr in TOM
			tom.sendMessage(tom.locMsg(132),true)
		end
		tom.vars.requestedCatacombState=true
		tom.refreshCatacombUI()
		tom.sendMessage(tom.locMsg(133,imported),true)
	else
		-- TIM ist nicht aktiv
		tom.sendMessage(tom.locMsg(131),true)
	end
end

function tom.setMovability(value)
	tomWindow01:SetMovable(value)
	tomAlerter:SetMovable(value)
	tomAlerterBubble:SetMovable(value)
	tom.vars.moveableWindows=value
end

function tom.playSound(soundNo)
	if tom.PlayerReady==true then
		-- Soundfunktionen sind noch deaktiviert
		if false then
			if soundNo==1 then PlayItemSound(ITEM_SOUND_CATEGORY_DEFAULT,4)
			elseif soundNo==2 then PlayItemSound(ITEM_SOUND_CATEGORY_RING,1)
			end
		end
	end
end

function tom.mailStatus(checkonly)
	if checkonly==false then
		if tom.vars.failedMailQueueindex+tom.vars.mailQueueindex==0 then
			tom.sendMessage(tom.locMsg(134),true)
		else
			tom.sendMessage(tom.locMsg(135,tom.vars.mailQueueindex,tom.vars.failedMailQueueindex),true)
			tom.vars.requestedFailState=true
		end
	end
	return tom.vars.failedMailQueueindex+tom.vars.mailQueueindex
end

function tom.onlineStatusChange(event,oldStatus,newStatus)
	if tom.vars.displayOnlineStatus==true then
		if newStatus~=1 then
			tomWindow01OnlineStatus:SetTexture(GetPlayerStatusIcon(newStatus))
			tomWindow01OnlineStatus:SetHidden(false)
		else
			tomWindow01OnlineStatus:SetHidden(true)
		end
	else
		tomWindow01OnlineStatus:SetHidden(true)
	end
end

function tom.setAlerterHideStatus(shown)
	tomAlerterBubble:SetHidden(not shown)
end

function tom.updateCore()
	tom.vars.core=tom.version
end

function tom.setFontSize()
	for looper=1,tom.vars.twtCount,1 do
		local twtKey=tom.windowName .. tom.to2string(looper) .. "Rolle"
		local gBC=GetControl(twtKey)
		if gBC~=nil then
			gBC:SetFont(tom.tomFont(57,tom.vars.fontSize))
		end
	end

end

function tom.tomFont(style,size)
	return "EsoUI/Common/Fonts/univers"..tom.to2string(style)..".otf|"..tom.to2string(size).."|soft-shadow-thin"
end

function tom.translateFirstDigit(fIndex,fTable)
	return fTable[tonumber(fIndex)]
end

--P5YCH3 - New function for middle-click settings.
function tom.toggleMiddleClickSettings()
	if string.sub(tom.vars.middle_Click,1,1)=="1" then
		--tom.vars.middle_Click="1-select"
		d("TOM - Middle-click behavior set to: " .. tom.vars.middle_Click)
	elseif string.sub(tom.vars.middle_Click,1,1)=="2" then
		--tom.vars.middle_Click="2-delete"
		d("TOM - Middle-click behavior set to: " .. tom.vars.middle_Click)
	end
end

function tom.translateSettings()
	tom.vars.displayPlayerChars=tom.translateFirstDigit(string.sub(tom.vars.displayPlayerChars,1,1),tom.locTxt[42]) --P5YCH3, Updated
	tom.vars.alrwsp=tom.translateFirstDigit(string.sub(tom.vars.alrwsp,1,1),tom.locTxt[53])
	tom.vars.alrgrp=tom.translateFirstDigit(string.sub(tom.vars.alrgrp,1,1),tom.locTxt[53])
	tom.vars.alrg[1]=tom.translateFirstDigit(string.sub(tom.vars.alrg[1],1,1),tom.locTxt[53])
	tom.vars.alrg[2]=tom.translateFirstDigit(string.sub(tom.vars.alrg[2],1,1),tom.locTxt[53])
	tom.vars.alrg[3]=tom.translateFirstDigit(string.sub(tom.vars.alrg[3],1,1),tom.locTxt[53])
	tom.vars.alrg[4]=tom.translateFirstDigit(string.sub(tom.vars.alrg[4],1,1),tom.locTxt[53])
	tom.vars.alrg[5]=tom.translateFirstDigit(string.sub(tom.vars.alrg[5],1,1),tom.locTxt[53])
	tom.vars.alrsay=tom.translateFirstDigit(string.sub(tom.vars.alrsay,1,1),tom.locTxt[53])
	tom.vars.alrzzz=tom.translateFirstDigit(string.sub(tom.vars.alrzzz,1,1),tom.locTxt[53])
	tom.vars.alrzde=tom.translateFirstDigit(string.sub(tom.vars.alrzde,1,1),tom.locTxt[53])
	tom.vars.alrzfr=tom.translateFirstDigit(string.sub(tom.vars.alrzfr,1,1),tom.locTxt[53])
	tom.vars.alrzen=tom.translateFirstDigit(string.sub(tom.vars.alrzen,1,1),tom.locTxt[53])
	tom.vars.gomMessageNotifier=tom.translateFirstDigit(string.sub(tom.vars.gomMessageNotifier,1,1),tom.locTxt[113])
end

function tom.refreshLAM()
	-- die Optionen anpassen, wenn die Einstellungen schon mal aufgerufen wurden
	-- funktioniert nicht, wird daher momentan nicht gemacht
	-- adjust the options if the settings have been called up before
	-- doesn't work, so it's not being done at the moment
	if false then
		for looper=1,5,1 do
			local gBC=GetControl("tomConfigGuildName1"..tom.to2string(looper))
			if gBC~=nil then
				gBC.label:SetText(tom.locMsg(14,tom.getGuildDefaultName(looper)))
				gBC:UpdateValue(tom.vars.alrg[looper])
				tom.sendDebugMessage("alrg: "..tom.vars.alrg[looper])
			end
			gBC=GetControl("tomConfigGuildName2"..tom.to2string(looper))
			if gBC~=nil then
				gBC.label:SetText(tom.locMsg(14,tom.getGuildDefaultName(looper)))
				gBC:UpdateValue(tom.vars.mltg[looper])
				tom.sendDebugMessage("mltg: "..tom.vars.mltg[looper])
			end
		end
	end
end

function tom.InitializeOptions()
	-- Das Einstellungsfenster aufbauen - LibAddonMenu Version 2.0
	local panelData = {
				type = "panel",
				name = "TOM - Reborn",
				displayName = "|c4779ce" .. "Tamriel Online Messenger" .. "|r" .. "|cFF0000" .. " Reborn" .. "|r",
				author = tomreborn.authorAccount .. ", " .. tom.authorAccount,
				website = TOM_REBORN_ADDON_WEBSITE,
				feedback = TOM_REBORN_FEEDBACK_WEBSITE,
				version = tom.version,
				registerForRefresh = true,
				registerForDefaults = true}
	local optionsData={
			[1]={
				type="header",
				--name=tom.locTxt[4],
				name = ZO_HIGHLIGHT_TEXT:Colorize(tom.locTxt[4]), --P5YCH3
				},
			[2]={
				type="checkbox",
				name=tom.locTxt[5],
				tooltip=tom.locTxt[6],
				getFunc=function() return tom.vars.openOnAlarm end,
				setFunc=function(newValue) tom.vars.openOnAlarm=newValue end,
				default=tom.tom_defaults.openOnAlarm,
				},
			[3]={
				type="checkbox",
				name=tom.locTxt[136],
				tooltip=tom.locTxt[137],
				getFunc=function() return tom.vars.activateAlertgroup end,
				setFunc=function(newValue) tom.vars.activateAlertgroup=newValue end,
				default=tom.tom_defaults.activateAlertgroup,
				},
			[4] = {
				type="header",
				--name=tom.locTxt[50],	-- Nachrichtenbehandlung
				name = ZO_HIGHLIGHT_TEXT:Colorize(tom.locTxt[50]), --P5YCH3
				},
			[5] = {
				type="dropdown",
				name=tom.locTxt[51], --locTxt[51], locMsg(51)
				tooltip=tom.locTxt[52],
				choices=tom.locTxt[53],
				getFunc=function() return tom.vars.alrwsp end,
				setFunc=function(value) tom.vars.alrwsp=value tom.translateSettings() end,
				default=tom.tom_defaults.alrwsp
				},
			[6] = {
				type="dropdown",
				name=tom.locTxt[54],
				tooltip=tom.locTxt[52],
				choices=tom.locTxt[53],
				getFunc=function() return tom.vars.alrgrp end,
				setFunc=function(value) tom.vars.alrgrp=value tom.translateSettings() end,
				default=tom.tom_defaults.alrgrp
				},
			[7] = {
				type="dropdown",
				name=tom.locMsg(14,tom.getGuildDefaultName(1)),
				tooltip=tom.locMsg(52,tom.getGuildDefaultName(1)),
				choices=tom.locTxt[53],
				getFunc=function() return tom.vars.alrg[1] end,
				setFunc=function(value) tom.vars.alrg[1]=value tom.translateSettings() end,
				default=tom.tom_defaults.alrg[1],
				reference="tomConfigGuildName101",
				},
			[8] = {
				type="dropdown",
				name=tom.locMsg(14,tom.getGuildDefaultName(2)),
				tooltip=tom.locMsg(52,tom.getGuildDefaultName(2)),
				choices=tom.locTxt[53],
				getFunc=function() return tom.vars.alrg[2] end,
				setFunc=function(value) tom.vars.alrg[2]=value tom.translateSettings() end,
				default=tom.tom_defaults.alrg[2],
				reference="tomConfigGuildName102",
				},
			[9] = {
				type="dropdown",
				name=tom.locMsg(14,tom.getGuildDefaultName(3)),
				tooltip=tom.locMsg(52,tom.getGuildDefaultName(3)),
				choices=tom.locTxt[53],
				getFunc=function() return tom.vars.alrg[3] end,
				setFunc=function(value) tom.vars.alrg[3]=value tom.translateSettings() end,
				default=tom.tom_defaults.alrg[3],
				reference="tomConfigGuildName103",
				},
			[10] = {
				type="dropdown",
				name=tom.locMsg(14,tom.getGuildDefaultName(4)),
				tooltip=tom.locMsg(52,tom.getGuildDefaultName(4)),
				choices=tom.locTxt[53],
				getFunc=function() return tom.vars.alrg[4] end,
				setFunc=function(value) tom.vars.alrg[4]=value tom.translateSettings() end,
				default=tom.tom_defaults.alrg[4],
				reference="tomConfigGuildName104",
				},
			[11] = {
				type="dropdown",
				name=tom.locMsg(14,tom.getGuildDefaultName(5)),
				tooltip=tom.locMsg(52,tom.getGuildDefaultName(5)),
				choices=tom.locTxt[53],
				getFunc=function() return tom.vars.alrg[5] end,
				setFunc=function(value) tom.vars.alrg[5]=value tom.translateSettings() end,
				default=tom.tom_defaults.alrg[5],
				reference="tomConfigGuildName105",
				},
			[12] = {
				type="dropdown",
				name=tom.locTxt[56],
				tooltip=tom.locTxt[52],
				choices=tom.locTxt[53],
				getFunc=function() return tom.vars.alrsay end,
				setFunc=function(value) tom.vars.alrsay=value tom.translateSettings() end,
				default=tom.tom_defaults.alrsay,
				},
			[13] = {
				type="dropdown",
				name=tom.locTxt[57],
				tooltip=tom.locTxt[52],
				choices=tom.locTxt[53],
				getFunc=function() return tom.vars.alrzzz end,
				setFunc=function(value) tom.vars.alrzzz=value tom.translateSettings() end,
				default=tom.tom_defaults.alrzzz,
				},
			[14] = {
				type="dropdown",
				name=tom.locTxt[58],
				tooltip=tom.locTxt[52],
				choices=tom.locTxt[53],
				getFunc=function() return tom.vars.alrzde end,
				setFunc=function(value) tom.vars.alrzde=value tom.translateSettings() end,
				default=tom.tom_defaults.alrzde,
				},
			[15] = {
				type="dropdown",
				name=tom.locTxt[59],
				tooltip=tom.locTxt[52],
				choices=tom.locTxt[53],
				getFunc=function() return tom.vars.alrzfr end,
				setFunc=function(value) tom.vars.alrzfr=value tom.translateSettings() end,
				default=tom.tom_defaults.alrzfr,
				},
			[16] = {
				type="dropdown",
				name=tom.locTxt[60],
				tooltip=tom.locTxt[52],
				choices=tom.locTxt[53],
				getFunc=function() return tom.vars.alrzen end,
				setFunc=function(value) tom.vars.alrzen=value tom.translateSettings() end,
				default=tom.tom_defaults.alrzen,
				},
			[17] = {
				type="header",
				--name=tom.locTxt[9],	-- Aufbewahrungszeiten
				name = ZO_HIGHLIGHT_TEXT:Colorize(tom.locTxt[9]), --P5YCH3
				},
			[18] = {
				type="dropdown",
				name=tom.locTxt[10],
				tooltip=tom.locTxt[11],
				choices=tom.msgRetentionsWhisper,
				getFunc=function() return tom.vars.mltwsp end,
				setFunc=function(value) tom.vars.mltwsp=value end,
				default=tom.tom_defaults.mltwsp,
				},
			[19] = {
				type="dropdown",
				name=tom.locTxt[12],
				tooltip=tom.locTxt[13],
				choices=tom.msgRetentions,
				getFunc=function() return tom.vars.mltgrp end,
				setFunc=function(value) tom.vars.mltgrp=value end,
				default=tom.tom_defaults.mltgrp,
				},
			[20] = {
				type="dropdown",
				name=tom.locMsg(14,tom.getGuildDefaultName(1)),
				tooltip=tom.locMsg(15,tom.getGuildDefaultName(1)),
				choices=tom.msgRetentions,
				getFunc=function() return tom.vars.mltg[1] end,
				setFunc=function(value) tom.vars.mltg[1]=value end,
				default=tom.tom_defaults.mltg[1],
				reference="tomConfigGuildName201",
				},
			[21] = {
				type="dropdown",
				name=tom.locMsg(14,tom.getGuildDefaultName(2)),
				tooltip=tom.locMsg(15,tom.getGuildDefaultName(2)),
				choices=tom.msgRetentions,
				getFunc=function() return tom.vars.mltg[2] end,
				setFunc=function(value) tom.vars.mltg[2]=value end,
				default=tom.tom_defaults.mltg[2],
				reference="tomConfigGuildName202",
				},
			[22] = {
				type="dropdown",
				name=tom.locMsg(14,tom.getGuildDefaultName(3)),
				tooltip=tom.locMsg(15,tom.getGuildDefaultName(3)),
				choices=tom.msgRetentions,
				getFunc=function() return tom.vars.mltg[3] end,
				setFunc=function(value) tom.vars.mltg[3]=value end,
				default=tom.tom_defaults.mltg[3],
				reference="tomConfigGuildName203",
				},
			[23] = {
				type="dropdown",
				name=tom.locMsg(14,tom.getGuildDefaultName(4)),
				tooltip=tom.locMsg(15,tom.getGuildDefaultName(4)),
				choices=tom.msgRetentions,
				getFunc=function() return tom.vars.mltg[4] end,
				setFunc=function(value) tom.vars.mltg[4]=value end,
				default=tom.tom_defaults.mltg[4],
				reference="tomConfigGuildName204",
				},
			[24] = {
				type="dropdown",
				name=tom.locMsg(14,tom.getGuildDefaultName(5)),
				tooltip=tom.locMsg(15,tom.getGuildDefaultName(5)),
				choices=tom.msgRetentions,
				getFunc=function() return tom.vars.mltg[5] end,
				setFunc=function(value) tom.vars.mltg[5]=value end,
				default=tom.tom_defaults.mltg[5],
				reference="tomConfigGuildName205",
				},
			[25] = {
				type="dropdown",
				name=tom.locTxt[16],
				tooltip=tom.locTxt[17],
				choices=tom.msgRetentions,
				getFunc=function() return tom.vars.mltsay end,
				setFunc=function(value) tom.vars.mltsay=value end,
				default=tom.tom_defaults.mltsay,
				},
			[26] = {
				type="dropdown",
				name=tom.locTxt[18],
				tooltip=tom.locTxt[19],
				choices=tom.msgRetentions,
				getFunc=function() return tom.vars.mltzzz end,
				setFunc=function(value) tom.vars.mltzzz=value end,
				default=tom.tom_defaults.mltzzz,
				},
			[27] = {
				type="dropdown",
				name=tom.locTxt[20],
				tooltip=tom.locTxt[21],
				choices=tom.msgRetentions,
				getFunc=function() return tom.vars.mltzde end,
				setFunc=function(value) tom.vars.mltzde=value end,
				default=tom.tom_defaults.mltzde,
				},
			[28] = {
				type="dropdown",
				name=tom.locTxt[22],
				tooltip=tom.locTxt[23],
				choices=tom.msgRetentions,
				getFunc=function() return tom.vars.mltzfr end,
				setFunc=function(value) tom.vars.mltzfr=value end,
				default=tom.tom_defaults.mltzfr,
				},
			[29] = {
				type="dropdown",
				name=tom.locTxt[24],
				tooltip=tom.locTxt[25],
				choices=tom.msgRetentions,
				getFunc=function() return tom.vars.mltzen end,
				setFunc=function(value) tom.vars.mltzen=value end,
				default=tom.tom_defaults.mltzen,
				},
			[30]={
				type="header",
				--name=tom.locTxt[47],
				name = ZO_HIGHLIGHT_TEXT:Colorize(tom.locTxt[47]), --P5YCH3
				},
			[31] = {
				type="dropdown",
				name=tom.locTxt[40], --Names in TOM - Appearance
				tooltip=tom.locTxt[41],
				choices=tom.locTxt[42],
				getFunc=function() return tom.vars.displayPlayerChars end, --P5YCH3, Updated
				setFunc=function(value) tom.vars.displayPlayerChars=value tom.exemptionForSettingsChanges = true tom.GOMclick(1,1) tom.translateSettings() tom. --Updated
				exemptionForSettingsChanges = false end, --P5YCH3, reset settings exemption.
				default=tom.tom_defaults.displayPlayerChars --P5YCH3 - Updated
				},
			[32] = {
				type="dropdown",
				name=tom.locTxt[115],
				tooltip=tom.locTxt[114],
				choices=tom.locTxt[113],
				getFunc=function() return tom.vars.gomMessageNotifier end,
				setFunc=function(value) tom.vars.gomMessageNotifier=value tom.translateSettings() end,
				default=tom.tom_defaults.gomMessageNotifier
				},
			[33] = { --P5YCH3 - New settings option to allow users to choose what middle-click does to a conversation group.
				type="dropdown",
				name=tom.locTxt[185],
				tooltip=tom.locTxt[186],
				choices=tom.locTxt[187],
				getFunc=function() return tom.vars.middle_Click end,
				setFunc=function(value) tom.vars.middle_Click=value tom.toggleMiddleClickSettings() end,
				default=tom.tom_defaults.middle_Click
				},
			[34]={
				type="checkbox",
				name=tom.locTxt[48],
				tooltip=tom.locTxt[49],
				getFunc=function() return tom.vars.use24hours end,
				setFunc=function(newValue) tom.vars.use24hours=newValue tom.activateUIchanges() end,
				default=tom.tom_defaults.use24hours,
				},
			[35] = {
				type="slider",
				name=tom.locTxt[28],
				tooltip=tom.locTxt[29],
				min=tom.tom_defaults.gomButtons-2,
				max=tom.gomMaxButtons,
				step=1,
				getFunc=function() return tom.vars.gomButtons end,
				setFunc=function(value) tom.vars.gomButtons=value tom.activateUIchanges() end,
				default=tom.tom_defaults.gomButtons,
				},
			[36] = {
				type="slider",
				name=tom.locTxt[30],
				tooltip=tom.locTxt[31],
				min=tom.tom_defaults.chatWidth-200,
				max=tom.chatMaxWidth,
				step=50,
				getFunc=function() return tom.vars.chatWidth end,
				setFunc=function(value) tom.vars.chatWidth=value tom.activateUIchanges() end,
				default=tom.tom_defaults.chatWidth,
				},
			[37] = {
				type="slider",
				name=tom.locTxt[61],
				tooltip=tom.locTxt[62],
				min=tom.tom_defaults.undockedHeigth-2,
				max=tom.gomMaxButtons,
				step=1,
				getFunc=function() return tom.vars.undockedHeigth end,
				setFunc=function(value) tom.vars.undockedHeigth=value tom.activateUIchanges() end,
				default=tom.tom_defaults.undockedHeigth,
				},
			[38] = {
				type="slider",
				name=tom.locTxt[63],
				tooltip=tom.locTxt[64],
				min=tom.tom_defaults.undockedWidth-200,
				max=tom.chatMaxWidth,
				step=50,
				getFunc=function() return tom.vars.undockedWidth end,
				setFunc=function(value) tom.vars.undockedWidth=value tom.activateUIchanges() end,
				default=tom.tom_defaults.undockedWidth,
				},
			[39] = {
				type="slider",
				name=tom.locTxt[148],
				tooltip=tom.locTxt[149],
				min=12,
				max=28,
				step=1,
				getFunc=function() return tom.vars.fontSize end,
				setFunc=function(value) tom.vars.fontSize=value tom.setFontSize() end,
				default=tom.tom_defaults.fontSize,
				},
			[40] = {
				type="slider",
				name=tom.locTxt[68],
				tooltip=nil,
				min=0,
				max=100,
				step=5,
				getFunc=function() return tom.vars.BGalpha end,
				setFunc=function(value) tom.vars.BGalpha=value tom.activateUIchanges() end,
				default=tom.tom_defaults.BGalpha,
				},
			[41]={
				type="checkbox",
				name=tom.locTxt[116],
				tooltip=tom.locTxt[117],
				getFunc=function() return tom.vars.displayGreeting end,
				setFunc=function(newValue) tom.vars.displayGreeting=newValue end,
				default=tom.tom_defaults.displayGreeting,
				},
			[42]={
				type="checkbox",
				name=tom.locTxt[7],
				tooltip=tom.locTxt[8],
				getFunc=function() return tom.vars.moveableWindows end,
				setFunc=function(newValue) tom.vars.moveableWindows=newValue tom.setMovability(newValue) end,
				default=tom.tom_defaults.moveableWindows,
				},
			[43]={
				type="checkbox",
				name=tom.locTxt[143],
				tooltip=tom.locTxt[144],
				getFunc=function() return tom.vars.displayOnlineStatus end,
				setFunc=function(newValue) tom.vars.displayOnlineStatus=newValue tom.onlineStatusChange(0,0,GetPlayerStatus()) end,
				default=tom.tom_defaults.displayOnlineStatus,
				},
			[44]={
				type="checkbox",
				name=tom.locTxt[145],
				tooltip=tom.locTxt[146],
				getFunc=function() return tom.vars.alerterShown end,
				setFunc=function(newValue) tom.vars.alerterShown=newValue tom.setAlerterHideStatus(tom.vars.alerterShown) end,
				default=tom.tom_defaults.alerterShown,
				},
			[45]={ --P5YCH3 - New settings option to show / hide alerter bubble within game menus.
				type="checkbox",
				name=tom.locTxt[153],
				tooltip=tom.locTxt[154],
				getFunc=function() return tom.vars.alerterShownInsideMenus end,
				setFunc=function(newValue) tom.vars.alerterShownInsideMenus=newValue end,
				default=tom.tom_defaults.alerterShownInsideMenus,
				},
			[46]={ --P5YCH3 - New settings option to show visible alerts for Magic Messages with the alerter bubble.
				type="checkbox",
				name=tom.locTxt[171],
				tooltip=tom.locTxt[172],
				getFunc=function() return tom.vars.alerterShownForMagicMessages end,
				setFunc=function(newValue) tom.vars.alerterShownForMagicMessages=newValue end,
				default=tom.tom_defaults.alerterShownForMagicMessages,
				},
			[47]={ --P5YCH3 - New settings option to toggle the automatic display of the cursor when opening the main TOM window.
				type="checkbox",
				name=tom.locTxt[169],
				tooltip=tom.locTxt[170],
				getFunc=function() return tom.vars.automaticallyShowCursor end,
				setFunc=function(newValue) tom.vars.automaticallyShowCursor=newValue end,
				default=tom.tom_defaults.automaticallyShowCursor,
				},
			[48]={ --P5YCH3 - New settings option to toggle the automatic switching of selected groups within the main window.
				type="checkbox",
				name=tom.locTxt[176],
				tooltip=tom.locTxt[177],
				getFunc=function() return tom.vars.Automatically_Reply_To_Selected_Groups end,
				setFunc=function(newValue) tom.vars.Automatically_Reply_To_Selected_Groups=newValue end,
				default=tom.tom_defaults.Automatically_Reply_To_Selected_Groups,
				},
			[49]={ --P5YCH3 - New settings option to toggle the display of the main window during combat.
				type="checkbox",
				name=tom.locTxt[181],
				tooltip=tom.locTxt[182],
				getFunc=function() return tom.vars.closeInCombat end,
				setFunc=function(newValue) tom.vars.closeInCombat=newValue end,
				default=tom.tom_defaults.closeInCombat,
				},
			[50]={ --P5YCH3 - New settings option to toggle the display of the main window within game menus.
				type="checkbox",
				name=tom.locTxt[183],
				tooltip=tom.locTxt[184],
				getFunc=function() return tom.vars.closeInMenus end,
				setFunc=function(newValue) tom.vars.closeInMenus=newValue end,
				default=tom.tom_defaults.closeInMenus,
				},
			[51]={ --P5YCH3 - New submenu for all addon console commands (includes German (DE) tranlations!).
				type = "submenu",
				name = ZO_HIGHLIGHT_TEXT:Colorize(tom.locTxt[155]), --Console Commands
				controls =
					{
						{
						type = "header",
						name = ZO_HIGHLIGHT_TEXT:Colorize(tom.locTxt[156]), --TOM - Functions
						},
						{
						type = "description",
						text = ZO_HIGHLIGHT_TEXT:Colorize("/tom") .. " - " .. tom.locTxt[157] .. "\n"
						..ZO_HIGHLIGHT_TEXT:Colorize("/tom lang") .. " - " .. tom.locTxt[158] .. "\n"
						..ZO_HIGHLIGHT_TEXT:Colorize("/tom import") .. " - " .. tom.locTxt[159] .. "\n"
						..ZO_HIGHLIGHT_TEXT:Colorize("/tom mail") .. " - " .. tom.locTxt[160] .. "\n"
						..ZO_HIGHLIGHT_TEXT:Colorize("/tom msgdump") .. " - " .. tom.locTxt[161] .. "\n"
						..ZO_HIGHLIGHT_TEXT:Colorize("/tom test") .. " - " .. tom.locTxt[162] .. "\n"
						..ZO_HIGHLIGHT_TEXT:Colorize("/tom status") .. " - " .. tom.locTxt[163] .. "\n"
						..ZO_HIGHLIGHT_TEXT:Colorize("/tom reset") .. " - " .. tom.locTxt[164] .. "\n"
						},
						{
						type = "header",
						name = ZO_HIGHLIGHT_TEXT:Colorize(tom.locTxt[165]),
						},
						{
						type = "description",
						text = ZO_HIGHLIGHT_TEXT:Colorize("/tom settings") .. " - " .. tom.locTxt[166] .. "\n"
						},
					}
				},
			}

	-- Removed by P5YCH3
	-- What the fu*k is this crap? LAM3 does not exist. LOL xD..
	-- local LAM3=LibAddonMenu2
	-- LAM3:RegisterAddonPanel("TOMConfig", panelData)
	-- LAM3:RegisterOptionControls("TOMConfig", optionsData)

	-- P5YCH3 -- Proper LAM2 Variables
	TOMAddonPanel = LibAddonMenu2:RegisterAddonPanel("TOMConfig", panelData) 
	LibAddonMenu2:RegisterOptionControls("TOMConfig", optionsData)
end

function tom.InitializeUI()
	-- Alerter einstellen und anzeigen
	-- Movable Button / Speakbubble
	tomAlerter:ClearAnchors() --TopLevelControl
	tomAlerter:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,tom.vars.AofX,tom.vars.AofY) --TopLevelControl

	tomAlerterBubble:SetTexture("/esoui/art/chatwindow/chat_notification_echo.dds") --Texture
	tomAlerterBubble:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[1][1]) end) --Texture
	tomAlerterBubble:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end) --Texture

	-- Das Hauptfenster einstellen und anzeigen
	local WindowGOMblock=50
	local WindowGOMblock2=WindowGOMblock+tom.vars.gomButtons*tom.gombuttonheight
	local WindowRow1=10
	local WindowRow2=WindowRow1+tom.gombuttonwidth+6
	local winWidth=WindowRow2+tom.vars.chatWidth+20
	local winHeight=WindowGOMblock2+50
	tomWindow01:ClearAnchors()
	tomWindow01:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, tom.vars.twt[tom.windowNameMain].X, tom.vars.twt[tom.windowNameMain].Y)
	tomWindow01:SetDimensions(winWidth,winHeight)
	tomWindow01Background:SetAlpha(tom.vars.BGalpha/100)
	tomWindow01Bubble:SetTexture("/esoui/art/chatwindow/chat_notification_echo.dds")
	--tomWindow01Bubble:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.bubbleStatistics()) end)
	tomWindow01Bubble:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[167] .. tom.bubbleStatistics()) end) --P5YCH3 - Updated the main window bubble icon tooltip.
	tomWindow01Bubble:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)

	--P5YCH3 - New settings panel button tooltip (tomWindow01Settings).
	tomWindow01Settings:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[168]) end)
	tomWindow01Settings:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)

	tomWindow01OnlineStatus:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,GetString("SI_PLAYERSTATUS",GetPlayerStatus())) end)
	tomWindow01OnlineStatus:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	tomWindow01Closer:SetHandler("/esoui/art/buttons/cancel_up.dds")
	tomWindow01Closer:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locMsg(26)) end)
	tomWindow01Closer:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	tomWindow01Answer:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locMsg(44)) end)
	tomWindow01Answer:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	tomWindow01Undock:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locMsg(69)) end)
	tomWindow01Undock:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	tomWindow01Kill:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locMsg(45)) end)
	tomWindow01Kill:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	tomWindow01Magic:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locMsg(76)) end)
	tomWindow01Magic:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	tomWindow01Catacomb:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locMsg(88)) end)
	tomWindow01Catacomb:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	tomWindow01Guild:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locMsg(103)) end)
	tomWindow01Guild:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	tomWindow01Line1:ClearAnchors()
	tomWindow01Line1:SetAnchor(TOPLEFT, tomWindow01, TOPLEFT, 0, WindowGOMblock-6)
	tomWindow01Line1:SetDimensions(winWidth,2)
	tomWindow01Line2:ClearAnchors()
	tomWindow01Line2:SetAnchor(TOPLEFT, tomWindow01, TOPLEFT, WindowRow2, WindowGOMblock)
	tomWindow01Line2:SetDimensions(2,winHeight-WindowGOMblock)
	tomWindow01Line3:ClearAnchors()
	tomWindow01Line3:SetAnchor(TOPLEFT, tomWindow01, TOPLEFT, tom.gombuttonwidth+WindowRow1, WindowGOMblock2+10)
	tomWindow01Line3:SetDimensions(winWidth-WindowRow2,2)
	for Looper=1,tom.gomMaxButtons,1 do
		tom.createGOMbutton(Looper,tom.gombuttonwidth,tom.gombuttonheight,WindowRow1,WindowGOMblock)
	end
	-- Den GOM-Slider erzeugen/platzieren
	if tomWindow01SL1==nil then CreateControl("tomWindow01SL1",tomWindow01,CT_SLIDER) end
	tomWindow01SL1:ClearAnchors()
	tomWindow01SL1:SetAnchor(TOPLEFT, tomWindow01, TOPLEFT, WindowRow2-2, WindowGOMblock)
	tomWindow01SL1:SetDimensions(5,WindowGOMblock2-WindowGOMblock)
	tomWindow01SL1:SetMouseEnabled(true)
	tomWindow01SL1:SetThumbTexture("ESOUI/art/lorelibrary/lorelibrary_scroll.dds","ESOUI/art/lorelibrary/lorelibrary_scroll.dds","ESOUI/art/lorelibrary/lorelibrary_scroll.dds",15,25,0,0,1,1)
	tomWindow01SL1:SetHandler("OnValueChanged",function(self,value,eventReason) tom.OnSlider1Move(value) end)
	tomWindow01SL1:SetMinMax(1,1)
	tomWindow01SL1:SetHidden(false)
	tomWindow01SL1:SetValueStep(1)
	tomWindow01SL1:SetValue(1)
	-- Die Rolle einrichten
	tomWindow01Rolle:ClearAnchors()
	tomWindow01Rolle:SetAnchor(TOPRIGHT, tomWindow01, TOPRIGHT, -10, WindowGOMblock+5)
	tomWindow01Rolle:SetDimensions(tom.vars.chatWidth,WindowGOMblock2-WindowGOMblock)
	tomWindow01Rolle:SetLinkEnabled(true)
	tomWindow01Rolle:SetMouseEnabled(true)
	tomWindow01Rolle:SetHidden(false)
	tomWindow01Rolle:SetClearBufferAfterFadeout(false)
	tomWindow01Rolle:SetMaxHistoryLines(tom.MaxHistoryLines)
	tom.setFontSize()
	--//tomWindow01Rolle:SetFont(tom.tomFont(57,tom.vars.fontSize))
	tomWindow01Rolle:SetHandler("OnLinkMouseUp", function(self, _, link, button) return ZO_LinkHandler_OnLinkMouseUp(link, button, self) end)
	tomWindow01Rolle:SetHandler("OnMouseWheel", function(self, delta, ctrl, alt, shift) tom.OnRolleWheel(self,delta) end)
	-- Den Rollen-Slider erzeugen/platzieren
	-- Create/place the reel slider
	tom.createRolleSlider(tom.windowNameMain,winWidth-17,WindowGOMblock,WindowGOMblock2-WindowGOMblock)
	-- Die CryptBox anpassen

	--P5YCH3 - New button to toggle the language from TOMish or Common for quickly responding in the selected channel.
	tomWindow01Coding:SetText(tom.locTxt[90][tom.vars.MainWindowCoding])
	tomWindow01Coding:SetFont(tom.tomFont(57,16))
	tomWindow01Coding:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[178]) end)
	tomWindow01Coding:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)

	--P5YCH3 - New button to change the channel of the main window bar.
	tomWindow01ChangeChannel:SetText(tom.locTxt[179][tom.vars.MainWindowChannel])
	tomWindow01ChangeChannel:SetFont(tom.tomFont(57,16))
	tomWindow01ChangeChannel:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[180]) end)
	tomWindow01ChangeChannel:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)

	-- Customize the CryptBox
	tomWindow01Crypt:Clear()
	tomWindow01Crypt:SetAlpha(1)
	--tomWindow01Crypt:SetColor(1,1,1,1) --white, normal
	--tomWindow01Crypt:SetColor(255, 255, 0, 1.0) --yellow
	tomWindow01Crypt:SetColor(255, 0, 0, 1.0) --red
	tomWindow01Crypt:SetFont(tom.tomFont(57,16))
	tomWindow01Crypt:SetCopyEnabled(true)
	tomWindow01Crypt:SetPasteEnabled(true)
	tomWindow01Crypt:SetEditEnabled(true)
	tomWindow01Crypt:SetMaxInputChars(300)
	tomWindow01Crypt:SetDimensions(tom.vars.chatWidth-140,20) --P5YCH3 - Resized to make room for new channel selector.

	--P5YCH3 - Customize the new TOM Reborn Common chat box
	tomWindow01Common:Clear()
	tomWindow01Common:SetAlpha(1)
	tomWindow01Common:SetColor(1,1,1,1) --white, normal
	tomWindow01Common:SetFont(tom.tomFont(57,16))
	tomWindow01Common:SetCopyEnabled(true)
	tomWindow01Common:SetPasteEnabled(true)
	tomWindow01Common:SetEditEnabled(true)
	tomWindow01Common:SetMaxInputChars(300)
	tomWindow01Common:SetDimensions(tom.vars.chatWidth-140,20)

--[[ 	--P5YCH3 - New settings option to toggle the TOMish bar. Replaced with the TOM Reborn bar.
	if tom.vars.showTOMishBar == false then
		tomWindow01Crypt:SetAlpha(0) --Hide the bar.
		--tomWindow01CryptLbl:SetAlpha(0) -Hide the TOMish text lable. Disabled because the lable was completely replaced with a new button control.
		tomWindow01Crypt:SetCopyEnabled(false) --Disable functionality.
		tomWindow01Crypt:SetPasteEnabled(false)
		tomWindow01Crypt:SetEditEnabled(false)
	else
		tomWindow01Crypt:SetAlpha(1) --Show the bar.
		--tomWindow01CryptLbl:SetAlpha(1) -Show the TOMish text lable. Disabled because the lable was completely replaced with a new button control.
		tomWindow01Crypt:SetCopyEnabled(true) --Enable functionality.
		tomWindow01Crypt:SetPasteEnabled(true)
		tomWindow01Crypt:SetEditEnabled(true)
	end ]]

	--P5YCH3 - Also hide the TOMish bar if Common chat is selected (the text bar is not required because text is redirected to the default chat window).
	if tom.vars.MainWindowCoding == 1 then --Common
		tomWindow01Crypt:SetAlpha(0) --Hide the TOMish bar.
		tomWindow01Crypt:SetCopyEnabled(false) --Disable TOMish functionality.
		tomWindow01Crypt:SetPasteEnabled(false)
		tomWindow01Crypt:SetEditEnabled(false)
		tomWindow01Crypt:SetMouseEnabled(false)
		tomWindow01Crypt:SetHidden(true)
		tomWindow01ChangeChannel:SetColor(1, 1, 1, 1) --white, default
		tomWindow01ChangeChannelTargetBG:SetEdgeColor(1, 1, 1, 1) --white, default
		tomWindow01Coding:SetColor(1, 1, 1, 1) --white, default
		tomWindow01CodingTargetBG:SetEdgeColor(1, 1, 1, 1) --white, default

		tomWindow01Common:SetAlpha(1) --Show the Common bar.
		tomWindow01Common:SetCopyEnabled(true) --Enable Common functionality.
		tomWindow01Common:SetPasteEnabled(true)
		tomWindow01Common:SetEditEnabled(true)
		tomWindow01Common:SetMouseEnabled(true)
		tomWindow01Common:SetHidden(false)
	elseif tom.vars.MainWindowCoding == 2 then --TOMish
		tomWindow01Common:SetAlpha(0) --Hide the Common bar.
		tomWindow01Common:SetCopyEnabled(false) --Disable Common functionality.
		tomWindow01Common:SetPasteEnabled(false)
		tomWindow01Common:SetEditEnabled(false)
		tomWindow01Common:SetMouseEnabled(false)
		tomWindow01Common:SetHidden(true)

		tomWindow01Crypt:SetAlpha(1) --Show the TOMish bar.
		tomWindow01Crypt:SetCopyEnabled(true) --Enable TOMish functionality.
		tomWindow01Crypt:SetPasteEnabled(true)
		tomWindow01Crypt:SetEditEnabled(true)
		tomWindow01Crypt:SetMouseEnabled(true)
		tomWindow01Crypt:SetHidden(false)
		tomWindow01ChangeChannel:SetColor(255, 0, 0, 1.0) --red
		tomWindow01ChangeChannelTargetBG:SetEdgeColor(255, 0, 0, 1.0) --red
		tomWindow01Coding:SetColor(255, 0, 0, 1.0) --red
		tomWindow01CodingTargetBG:SetEdgeColor(255, 0, 0, 1.0) --red
	end

	-- alle ungedockten Fenster wieder erstellen
	-- recreate all undocked windows
	for looper=2,tom.vars.twtCount,1 do
		local twtKey=tom.windowName .. tom.to2string(looper)
		local twtGom=tom.vars.twt[twtKey].gom
		tom.createUndockedWindow(twtKey,twtGom)
	end
	-- Fenster und Alerter verschiebbar machen
	-- Make windows and alerters floating
	tom.setMovability(tom.vars.moveableWindows)
	-- aktuellen Online Status anzeigen
	-- Show current online status
	tom.onlineStatusChange(0,0,GetPlayerStatus())
	-- den Alerter ausblenden, wenn angefordert
	-- hide the alerter when requested
	tom.setAlerterHideStatus(tom.vars.alerterShown)
	-- Das Magiefenster einstellen und anzeigen
	-- Set and display the Magic Messages window
	local magicLOMblock=50
	local magicLOMblock2=magicLOMblock+tom.lomButtons*tom.lombuttonheight
	local magicLOMblock3=80
	local magicLOMblock4=magicLOMblock3+90
	local magicRow1=10
	local magicRow2=magicRow1+tom.lombuttonwidth+6
	local magicRow3=magicRow2+100
	local magicWidth=magicRow2+400
	local magicHeight=magicLOMblock2+50
	tomMagic:ClearAnchors()
	tomMagic:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,tom.vars.MofX,tom.vars.MofY)
	tomMagic:SetDimensions(magicWidth,magicHeight)
	tomMagicBackground:SetAlpha(tom.vars.BGalpha/100)
	tomMagicHeader:SetText(tom.locMsg(75)) --locTxt[75], locMsg(75)
	tomMagicBubble:SetTexture("/esoui/art/chatwindow/chat_notification_echo.dds")
	tomMagicCloser:SetTexture("/esoui/art/buttons/cancel_up.dds")
	tomMagicCloser:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locMsg(84)) end)
	tomMagicCloser:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	tomMagicDesc:ClearAnchors()
	tomMagicDesc:SetAnchor(TOPLEFT,tomMagic,TOPLEFT,magicRow2+10,10)
	tomMagicDesc:SetText(tom.locMsg(77))
	tomMagicLine1:ClearAnchors()
	tomMagicLine1:SetAnchor(TOPLEFT,tomMagic,TOPLEFT,0,magicLOMblock-6)
	tomMagicLine1:SetDimensions(magicWidth,2)
	tomMagicLine2:ClearAnchors()
	tomMagicLine2:SetAnchor(TOPLEFT,tomMagic,TOPLEFT,magicRow2,magicLOMblock)
	tomMagicLine2:SetDimensions(2,magicHeight-magicLOMblock)
	tomMagicLine3:ClearAnchors()
	tomMagicLine3:SetAnchor(TOPLEFT,tomMagic,TOPLEFT,tom.lombuttonwidth+magicRow1,magicHeight-20)
	tomMagicLine3:SetDimensions(magicWidth-magicRow2,2)
	for Looper=1,tom.lomMaxButtons,1 do
		tom.createLOMbutton(Looper,tom.lombuttonwidth,tom.lombuttonheight,magicRow1,magicLOMblock)
	end
	-- Den LOM-Slider erzeugen/platzieren
	-- Create/place the LOM slider
	if tomMagicSL1==nil then CreateControl("tomMagicSL1",tomMagic,CT_SLIDER) end
	tomMagicSL1:ClearAnchors()
	tomMagicSL1:SetAnchor(TOPLEFT,tomMagic,TOPLEFT,magicRow2-2,magicLOMblock)
	tomMagicSL1:SetDimensions(5,magicLOMblock2-magicLOMblock)
	tomMagicSL1:SetMouseEnabled(true)
	tomMagicSL1:SetThumbTexture("ESOUI/art/lorelibrary/lorelibrary_scroll.dds","ESOUI/art/lorelibrary/lorelibrary_scroll.dds","ESOUI/art/lorelibrary/lorelibrary_scroll.dds",15,25,0,0,1,1)
	tomMagicSL1:SetHandler("OnValueChanged",function(self,value,eventReason) tom.OnMagicSlider1Move(value) end)
	tomMagicSL1:SetMinMax(1,1)
	tomMagicSL1:SetHidden(false)
	tomMagicSL1:SetValueStep(1)
	tomMagicSL1:SetValue(1)
	-- Magiefenster Eingabebereich aufbauen
	-- Build magic window input area
	for looper1=0,3,3 do
		for looper2=1,3,1 do
			local gBC=GetControl("tomMagicBack"..tom.to2string(looper2+looper1+3))
			if gBC==nil then gBC=CreateControlFromVirtual("tomMagicBack"..tom.to2string(looper2+looper1+3),tomMagic,"tomMagicBack") end
			gBC:SetDimensions(78,35)
			gBC:ClearAnchors()
			gBC:SetAnchor(TOPLEFT,tomMagicName,TOPLEFT,(looper2-1)*83,(looper1-1)*10+magicLOMblock3)
			gBC:SetTexture("/esoui/art/campaign/overview_scoringbg_daggerfall_left.dds")
			gBC=GetControl("tomMagicEdit"..tom.to2string(looper2+looper1+3))
			if gBC==nil then gBC=CreateControlFromVirtual("tomMagicEdit"..tom.to2string(looper2+looper1+3),tomMagic,"ZO_DefaultEditForBackdrop") end
			gBC:SetHandler("OnMouseDown", function(self) self:SetKeyboardEnabled(true) self:TakeFocus() end)
			gBC:SetHandler("OnEnter", function(self) tomUI.magicStoreBack(self) end)
			gBC:SetHandler("OnEscape", function(self) tomUI.magicStoreBack(self) end)
			gBC:SetHandler("OnFocusLost", function(self) tomUI.magicStoreBack(self) end)
			gBC:SetDimensions(68,24)
			gBC:ClearAnchors()
			gBC:SetAnchor(TOPLEFT,tomMagicName,TOPLEFT,(looper2-1)*83+5,(looper1-1)*10+magicLOMblock3)
			gBC:SetMaxInputChars(16)
			gBC:SetMultiLine(false)
			gBC:SetColor(1,1,0.8,1)
			gBC:SetFont(tom.tomFont(57,14))
		end
	end
	for looper2=1,2,1 do
		local gBC=GetControl("tomMagicBack"..tom.to2string(looper2+9))
		if gBC==nil then gBC=CreateControlFromVirtual("tomMagicBack"..tom.to2string(looper2+9),tomMagic,"tomMagicBack") end
		gBC:SetDimensions(78,35)
		gBC:ClearAnchors()
		gBC:SetAnchor(TOPLEFT,tomMagicName,TOPLEFT,(looper2-1)*83,magicLOMblock3+50)
		gBC:SetTexture("/esoui/art/campaign/overview_scoringbg_ebonheart_left.dds")
		gBC=GetControl("tomMagicEdit"..tom.to2string(looper2+9))
		if gBC==nil then gBC=CreateControlFromVirtual("tomMagicEdit"..tom.to2string(looper2+9),tomMagic,"ZO_DefaultEditForBackdrop") end
		gBC:SetHandler("OnMouseDown", function(self) self:SetKeyboardEnabled(true) self:TakeFocus() end)
		gBC:SetHandler("OnEnter", function(self) tomUI.magicStoreBack(self) end)
		gBC:SetHandler("OnEscape", function(self) tomUI.magicStoreBack(self) end)
		gBC:SetHandler("OnFocusLost", function(self) tomUI.magicStoreBack(self) end)
		gBC:SetDimensions(68,24)
		gBC:ClearAnchors()
		gBC:SetAnchor(TOPLEFT,tomMagicName,TOPLEFT,(looper2-1)*83+5,magicLOMblock3+50)
		gBC:SetMaxInputChars(16)
		gBC:SetMultiLine(false)
		gBC:SetColor(1,1,0.8,1)
		gBC:SetFont(tom.tomFont(57,14))
	end
	tomMagicName:SetMaxInputChars(16)
	tomMagicName:SetMultiLine(false)
	tomMagicTitel:SetMaxInputChars(50)
	tomMagicTitel:SetMultiLine(false)
	tomMagicNameLbl:ClearAnchors()
	tomMagicNameLbl:SetAnchor(TOPLEFT,tomMagicLine2,TOPLEFT,20,magicLOMblock3+20)
	tomMagicTitelLbl:ClearAnchors()
	tomMagicTitelLbl:SetAnchor(TOPLEFT,tomMagicNameLbl,TOPLEFT,0,30)
	tomMagicTitelLbl:SetText(tom.locMsg(80))
	tomMagicSelectLbl:ClearAnchors()
	tomMagicSelectLbl:SetAnchor(TOPLEFT,tomMagicTitelLbl,TOPLEFT,0,40)
	tomMagicSelectLbl:SetText(tom.locMsg(78)) --locTxt[78], locMsg(78)
	tomMagicOmitLbl:ClearAnchors()
	tomMagicOmitLbl:SetAnchor(TOPLEFT,tomMagicSelectLbl,TOPLEFT,0,60)
	tomMagicOmitLbl:SetText(tom.locMsg(79))
	tomMagicNew:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locMsg(82)) end)
	tomMagicNew:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	tomMagicKill:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locMsg(83)) end)
	tomMagicKill:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	tomMagicStatus:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locMsg(85)) end)
	tomMagicStatus:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	-- Das Katakombenfenster einstellen und anzeigen
	-- Set and display the catacomb window
	tomCatacomb:ClearAnchors()
	tomCatacomb:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, tom.vars.CofX, tom.vars.CofY)
	tomCatacombBackground:SetAlpha(tom.vars.BGalpha/100)
	tomCatacombHead1:SetText(tom.locTxt[86][1])
	tomCatacombBubble:SetTexture("/esoui/art/chatwindow/chat_notification_up.dds")
	tomCatacombCloser:SetTexture("/esoui/art/buttons/cancel_up.dds")
	tomCatacombCloser:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[86][2]) end)
	tomCatacombCloser:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	tomCatacombScan:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[86][5]) end)
	tomCatacombScan:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	tomCatacombHelp:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[86][4]) end)
	tomCatacombHelp:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	tomCatacombNameText:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[86][11]) end)
	tomCatacombNameText:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	tomCatacombNameEdit:SetHidden(true)
	tomCatacombNameEdit:SetMaxInputChars(80)
	tomCatacombTargetTxt:SetText(tom.locTxt[86][3])
	tomCatacombTargetTxt:SetFont(tom.tomFont(57,16))
	tomCatacombGom:SetText("-keinGOM-")
	tomCatacombGom:SetHidden(not tom.isDebug)
	tomCatacombGom:SetFont(tom.tomFont(57,16))
	tomCatacombCoding:SetFont(tom.tomFont(57,16))
	tomCatacombCoding:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[91]) end)
	tomCatacombCoding:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	tomCatacombScrollsTxt2:SetText(tom.locTxt[86][7])
	tomCatacombScrollsTxt2:SetFont(tom.tomFont(57,16))
	local gBC=GetControl("tomCatacombSlider")
	if gBC==nil then gBC=CreateControl("tomCatacombSlider",tomCatacomb,CT_SLIDER) end
	gBC:SetOrientation(ORIENTATION_HORIZONTAL)
	gBC:SetDimensions(200,24)
	gBC:SetMouseEnabled(true)
	gBC:SetThumbTexture("EsoUI\\Art\\Miscellaneous\\scrollbox_elevator.dds", "EsoUI\\Art\\Miscellaneous\\scrollbox_elevator_disabled.dds", nil, 8, 16) 
	gBC:SetHandler("OnValueChanged",function(self,value,eventReason) tom.OnCatacombSliderMove(value) end)
	gBC:SetHidden(false)
	gBC:SetMinMax(1,tom.CatacombScrollsMaxPages)
	gBC:SetValueStep(1)
	gBC:SetValue(tom.vars.CatacombScrollsPage)
	gBC:ClearAnchors()
	gBC:SetAnchor(TOPLEFT, tomCatacombScrollsMor, TOPRIGHT, 10, 0)
	local gBC2=CreateControl(nil,gBC,CT_BACKDROP)
	gBC2:SetCenterColor(0, 0, 0)
	gBC2:SetAnchor(TOPLEFT,slider,TOPLEFT, 0, 4)
	gBC2:SetAnchor(BOTTOMRIGHT,slider,BOTTOMRIGHT,0,-4)
	gBC2:SetEdgeTexture("EsoUI\\Art\\Tooltips\\UI-SliderBackdrop.dds", 32, 4)
	-- Katakombenfenster Auswahlbereich aufbauen
	Looper=0
	while Looper<tom.CatacombRows do
		Looper=Looper+1
		-- Einfügen/Löschen Knopf
		local gBC=GetControl("tomCatacombInsKill"..tostring(Looper))
		if gBC==nil then gBC=CreateControlFromVirtual("tomCatacombInsKill"..tostring(Looper),tomCatacomb, "tomInsKill") end
		gBC:ClearAnchors()
		gBC:SetAnchor(TOPLEFT,tomCatacomb,TOPLEFT,10,250+(Looper-1)*26)
		gBC:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[86][8]) end)
		gBC:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
		-- Textkonserve
		gBC=GetControl("tomCatacombText"..tostring(Looper))
		if gBC==nil then gBC=CreateControlFromVirtual("tomCatacombText"..tostring(Looper),tomCatacomb,"tomCataText") end
		gBC:ClearAnchors()
		gBC:SetAnchor(TOPLEFT,tomCatacomb,TOPLEFT,40,250+(Looper-1)*26)
		gBC:SetFont(tom.tomFont(57,16))
		gBC:SetText("Hey"..tostring(Looper))
		gBC:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[86][10]) end)
		gBC:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
		-- Senden/Bearbeiten Knopf
		gBC=GetControl("tomCatacombSndEdt"..tostring(Looper))
		if gBC==nil then gBC=CreateControlFromVirtual("tomCatacombSndEdt"..tostring(Looper),tomCatacomb,"tomSndEdt") end
		gBC:ClearAnchors()
		gBC:SetAnchor(TOPLEFT,tomCatacomb,TOPLEFT,415,245+(Looper-1)*26)
		gBC:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[86][9]) end)
		gBC:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	end
	tomCatacombTarget:SetAlpha(1)
	tomCatacombTarget:SetColor(1,1,1,1)
	tomCatacombTarget:SetFont(tom.tomFont(57,16))
	tomCatacombEdit:SetAlpha(1)
	tomCatacombEdit:SetColor(1,1,1,1)
	tomCatacombEdit:SetCopyEnabled(true)
	tomCatacombEdit:SetPasteEnabled(true)
	tomCatacombEdit:SetEditEnabled(true)
	tomCatacombEdit:SetFont(tom.tomFont(57,16))
	tomCatacombEdit:SetMaxInputChars(tom.maxCatacombMessageLength)
	tomCatacombEdit:SetMultiLine(true)
	tomCatacombEdit:SetNewLineEnabled(true)
	tom.loadCatacombScrollPage()
	-- Das Gildenfenster einstellen und anzeigen
	tomGuild:ClearAnchors()
	tomGuild:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,tom.vars.GofX,tom.vars.GofY)
	tomGuildBackground:SetAlpha(tom.vars.BGalpha/100)
	tomGuildHead1:SetText(tom.locMsg(92))
	tomGuildBubble:SetTexture("/esoui/art/chatwindow/chat_notification_up.dds")
	tomGuildCloser:SetTexture("/esoui/art/buttons/cancel_up.dds")
	tomGuildCloser:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[93]) end)
	tomGuildCloser:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	tomGuildFailed:SetTexture("/esoui/art/buttons/edit_up.dds")
	tomGuildFailed:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[130]) end)
	tomGuildFailed:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	tomGuildNext:SetTexture("/esoui/art/ava/ava_resourcestatus_tabicon_production.dds")
	tomGuildNext:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[94]) end)
	tomGuildNext:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	tomGuildFooterLMTAction:SetFont(tom.tomFont(57,16))
	tomGuildFooterLMTAction:SetText(tom.locTxt[95][tom.vars.queryLMT])
	tomGuildFooterRMTAction:SetFont(tom.tomFont(57,16))
	tomGuildFooterRMTAction:SetText(tom.locTxt[95][tom.vars.queryRMT])
	tomGuildFooterLMTAction:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[96]) end)
	tomGuildFooterLMTAction:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	tomGuildFooterRMTAction:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[97]) end)
	tomGuildFooterRMTAction:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	tomGuildSwitch:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[98]) end)
	tomGuildSwitch:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	tomGuildFooterDisplayed:SetFont(tom.tomFont(57,14))
	tomGuildRefresh:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[99]) end)
	tomGuildRefresh:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	-- Den Gilden-Slider platzieren
	tom.slider3=GetControl("tomGuildSlider")
	if tom.slider3==nil then tom.slider3=CreateControl("tomGuildSlider",tomGuild,CT_SLIDER) end
	tom.slider3:SetMouseEnabled(true)
	tom.slider3:SetThumbTexture("ESOUI/art/lorelibrary/lorelibrary_scroll.dds","ESOUI/art/lorelibrary/lorelibrary_scroll.dds","ESOUI/art/lorelibrary/lorelibrary_scroll.dds",15,25,0,0,1,1)
	tom.slider3:SetHandler("OnValueChanged",function(self,value,eventReason) tom.OnSlider3Move(value) end)
	tom.slider3:SetHidden(true)
	tom.slider3:SetValueStep(1)
	-- Den Gilden-Nachrichtenbereich konfigurieren
	tomGuildBetreffLBL:ClearAnchors()
	tomGuildBetreffLBL:SetAnchor(TOPLEFT,tomGuildBackground,TOPLEFT,220,125)
	tomGuildBetreffLBL:SetFont(tom.tomFont(57,16))
	tomGuildBetreffLBL:SetText(tom.locTxt[104])
	tomGuildBetreff:SetAlpha(1)
	tomGuildBetreff:SetColor(1,1,1,1)
	tomGuildBetreff:SetCopyEnabled(true)
	tomGuildBetreff:SetPasteEnabled(true)
	tomGuildBetreff:SetEditEnabled(true)
	tomGuildBetreff:SetFont(tom.tomFont(57,16))
	tomGuildBetreff:SetMaxInputChars(80)
	tomGuildBetreff:SetDimensions(290,25)
	tomGuildBetreff:ClearAnchors()
	tomGuildBetreff:SetAnchor(TOPLEFT,tomGuild,TOPLEFT,290,125)
	tomGuildNachrichtLen:SetFont(tom.tomFont(57,16))
	-- Die Nachrichtbox anpassen
	tomGuildNachricht:SetDimensions(360,480)
	tomGuildNachricht:SetAlpha(1)
	tomGuildNachricht:SetColor(1,1,1,1)
	tomGuildNachricht:SetCopyEnabled(true)
	tomGuildNachricht:SetPasteEnabled(true)
	tomGuildNachricht:SetEditEnabled(true)
	tomGuildNachricht:SetFont(tom.tomFont(57,16))
	tomGuildNachricht:SetMaxInputChars(tom.maxGuildMessageLength)
	tomGuildNachricht:SetMultiLine(true)
	tomGuildNachricht:SetNewLineEnabled(true)
	-- den Löschknopf beschriften
	tomGuildNachrichtCancel:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[109]) end)
	tomGuildNachrichtCancel:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	-- Schrift in der Suchzeile einstellen
	tomGuildqrySuche:SetFont(tom.tomFont(57,16))
	tomGuildqryAuswahl:SetFont(tom.tomFont(57,16))
	tomGuildqryZusatz:SetFont(tom.tomFont(57,16))
	tomGuildqryGtlt:SetFont(tom.tomFont(57,16))
	tomGuildqryAnzahl:SetFont(tom.tomFont(57,16))
	tomGuildqryEinheit:SetFont(tom.tomFont(57,16))
	tomGuildqryMode:SetFont(tom.tomFont(57,16))
	tomGuildqryZusatz2:SetFont(tom.tomFont(57,16))
	tomGuildqryVonGRank:SetFont(tom.tomFont(57,16))
	tomGuildqryBisGRank:SetFont(tom.tomFont(57,16))
	tomGuildqryZusatz2:SetText(tom.locTxt[138])
	tomGuildqryZusatz3:SetFont(tom.tomFont(57,16))
	tomGuildqryVonRank:SetFont(tom.tomFont(57,16))
	tomGuildqryBisRank:SetFont(tom.tomFont(57,16))
	tomGuildqryZusatz3:SetText(tom.locTxt[139])
	-- den Gilden-Slider anpassen
	tom.slider3:SetDimensions(10,tom.guildButtons*tom.guildbuttonheight)
	tom.slider3:ClearAnchors()
	tom.slider3:SetAnchor(TOPLEFT,tomGuild,TOPLEFT,tom.GuildBlockWidth-15,tom.GuildBlock3)
	-- Die Werte aus den Savedvariables eintragen
	tomGuildBetreff:SetText(tom.vars.GuildSubject)
	tomGuildNachricht:SetText(tom.vars.GuildMessage)
	-- Die Gilden-Buttons aufbauen
	for looper=1,tom.guildButtons,1 do tom.createGUILDbutton(looper) end
	tom.guildSetGuildWindow()
	-- Das Scanfenster einstellen und anzeigen
	-- Set and display the scan window
	tomScan:ClearAnchors()
	tomScan:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,tom.vars.SofX,tom.vars.SofY)
	tomScanBackground:SetAlpha(tom.vars.BGalpha/100)
	tomScanBubble:SetTexture("/esoui/art/chatwindow/chat_notification_up.dds")
	tomScanCloser:SetTexture("/esoui/art/buttons/cancel_up.dds")
	tomScanHead1:SetText(tom.locTxt[121])
	tomScanCloser:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[122]) end)
	tomScanCloser:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	tomScanClear:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[123]) end)
	tomScanClear:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	tomScanFooterLMTAction:SetFont(tom.tomFont(57,16))
	tomScanFooterLMTAction:SetText(tom.locTxt[124][1])
	tomScanFooterRMTAction:SetFont(tom.tomFont(57,16))
	tomScanFooterRMTAction:SetText(tom.locTxt[124][2])
	-- Die Scan-Buttons aufbauen
	-- Build the scan buttons
	for looper=1,tom.scanTargetMax,1 do tom.createSCANbutton(looper) end
	tom.updateScanTargets()
	-- Das Clipboardfenster einstellen und anzeigen
	-- Set and display the clipboard window
	tomClipboard:ClearAnchors()
	tomClipboard:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,tom.vars.DofX,tom.vars.DofY)
	tomClipboardBackground:SetAlpha(tom.vars.BGalpha/100)
	tomClipboardBubble:SetTexture("/esoui/art/chatwindow/chat_notification_up.dds")
	tomClipboardCloser:SetTexture("/esoui/art/buttons/cancel_up.dds")
	tomClipboardHead1:SetText(tom.locTxt[140])
	tomClipboardHead2:SetFont(tom.tomFont(57,14))
	tomClipboardHead2:SetText(tom.locTxt[142])
	tomClipboardCloser:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[141]) end)
	tomClipboardCloser:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	tomClipboardClear:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[123]) end)
	tomClipboardClear:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	tomClipboardEdit:SetAlpha(1)
	tomClipboardEdit:SetColor(1,1,1,1)
	tomClipboardEdit:SetCopyEnabled(true)
	tomClipboardEdit:SetPasteEnabled(true)
	tomClipboardEdit:SetEditEnabled(true)
	tomClipboardEdit:SetFont(tom.tomFont(57,16))
	tomClipboardEdit:SetMaxInputChars(8000)
	tomClipboardEdit:SetMultiLine(true)
	tomClipboardEdit:SetNewLineEnabled(true)
	tomClipboardEdit:SetText(tom.vars.ClipboardText)
	-- Das failMail Fenster einstellen und anzeigen
	tomfailMail:ClearAnchors()
	tomfailMail:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,tom.vars.FofX,tom.vars.FofY)
	tomfailMailBackground:SetAlpha(tom.vars.BGalpha/100)
	tomfailMailBubble:SetTexture("/esoui/art/chatwindow/chat_notification_up.dds")
	tomfailMailCloser:SetTexture("/esoui/art/buttons/cancel_up.dds")
	tomfailMailHeader:SetText(tom.locTxt[127])
	tomfailMailCloser:SetHandler("OnMouseEnter", function(self) tom.ShowTooltip(self,tom.locTxt[128]) end)
	tomfailMailCloser:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
	-- Die failMail-Buttons aufbauen
	for Looper=1,tom.fmButtons,1 do tom.createFMbutton(Looper,tom.fmbuttonwidth,tom.fmbuttonheight,tom.fmtextwidth,tom.fmrecipientwidth,10,45) end
	-- Den FM-Slider erzeugen/platzieren
	if tomfailMailSL1==nil then CreateControl("tomfailMailSL1",tomfailMail,CT_SLIDER) end
	tomfailMailSL1:ClearAnchors()
	tomfailMailSL1:SetAnchor(TOPRIGHT,tomfailMail,TOPRIGHT,-3,50)
	tomfailMailSL1:SetDimensions(5,tom.fmbuttonheight*tom.fmButtons)
	tomfailMailSL1:SetMouseEnabled(true)
	tomfailMailSL1:SetThumbTexture("ESOUI/art/lorelibrary/lorelibrary_scroll.dds","ESOUI/art/lorelibrary/lorelibrary_scroll.dds","ESOUI/art/lorelibrary/lorelibrary_scroll.dds",15,25,0,0,1,1)
	tomfailMailSL1:SetHandler("OnValueChanged",function(self,value,eventReason) tomUI.OnFMSliderMove(value) end)
	tomfailMailSL1:SetMinMax(1,1)
	tomfailMailSL1:SetHidden(false)
	tomfailMailSL1:SetValueStep(1)
	tomfailMailSL1:SetValue(1)
end

function tom.Initialize(eventCode, addOnName)
	if (addOnName == tom.name) then
		--	Defaults anlegen
		tom.tom_defaults = {
			lastActiveTime=0,
			firstRun=true,
			BGalpha=80,
			persons={},
			personCount=0,
			displayGreeting=true,
			sentTOMish=0,
			msgType={},
			msgFrom={},
			msgText={},
			msgTime={},
			msgRead={},
			msgDltd={},
			msgCount=0,
			gomMessageNotifier="1",
			lom={},
			lomCount=0,
			shownLOM=0,
			twt={},
			twtCount=1,
			displayPlayerChars="1", --P5YCH3, Updated, new features for /say, /zone, /y, etc.
			mltwsp=14,
			mltgrp=1,
			mltg={3,3,3,3,3},
			alrg={"2","2","2","2","2",},
			mltsay=1,
			mltzzz=1,
			mltzde=1,
			mltzfr=1,
			mltzen=1,
			--===========================================
			--P5YCH3 - Translation additions.
			--===========================================
			mltzjp="1",
			mltzru="1",
			mltzes="1",
			--===========================================
			mltsys=7,
			alrwsp="3",
			alrgrp="3",
			alrsay="2",
			alrzzz="2",
			alrzde="2",
			alrzfr="2",
			alrzen="2",
			--===========================================
			--P5YCH3 - Translation additions.
			--===========================================
			alrzjp="2",
			alrzru="2",
			alrzes="2",
			--===========================================
			alrsys="2",
			gomButtons=10,
			chatWidth=450,
			undockedHeigth=8,
			undockedWidth=500,
			openOnAlarm=true,
			closeInCombat=true,
			closeInMenus=true, --P5YCH3 - New settings option to toggle the main window display within other game menus.
			use24hours=true,
			requestedWindowState=true,
			requestedMagicState=false,
			requestedCatacombState=false,
			requestedGuildState=false,
			requestedScanState=false,
			requestedClipState=false,
			requestedFailState=false,
			activateAlertgroup=true,
			Guilds={"","","","",""},
			MofX=1062.8570556641, MofY=133.7142639160,
			CofX=608.5714721680, CofY=133.7142639160,
			GofX=5.7143096924, GofY=133.7142639160,
			SofX=94.2857055664, SofY=127.4285583496,
			FofX=1062.8570556641, FofY=477.7144775391,
			DofX=1062.8570556641, DofY=477.7144775391,
			CatacombNames={},
			CatacombScrollsText={},
			CatacombScrollsPage=1,
			MainWindowCoding=1, --P5YCH3 - Toggles the main window bar between Common & TOMish.
			MainWindowChannel=1, --P5YCH3 - Changes the channel of the main window bar.
			CatacombCoding=1,
			queryLMT=1,
			queryRMT=3,
			actualGuild=0,
			queryAccount=true,
			queryUnits=3,
			queryIgnore=2,
			queryCounts=30,
			queryStatus=1,
			queryGtlt=1,
			queryVonRank=1,
			queryBisRank=3550,
			queryVonGRank=1,
			queryBisGRank=10,
			GuildSubject="",
			GuildMessage="",
			failedMailQueueindex=0,
			failedMailQueue={mTO={}, mSUB={}, mTEXT={},},
			mailQueue={mTO={}, mSUB={}, mTEXT={},},
			mailQueueindex=0,
			scanTargets={},
			moveableWindows=true,
			ClipboardText="",
			displayOnlineStatus=true,
			alerterShown=true,
			alerterShownInsideMenus=false, --P5YCH3 - New settings option to toggle the display of the alerter bubble within menus.
			automaticallyShowCursor=false, --P5YCH3 - New settings option to toggle the display of the cursor when opening TOM.
			alerterShownForMagicMessages=false, --P5YCH3 - New settings option to toggle the display of the flashing keyword alerts for Magic Messages.
			fontSize=16,
			AddonJustStarted_Ignore_Regenerated_Messages=false, --P5YCH3 - Helps the new flashing alerts feature for Magic Messages.
			Automatically_Reply_To_Selected_Groups=true, --P5YCH3 - New settings option to automatically change channels when selecting a conversation in the main window.
			middle_Click="1-select", --P5YCH3 - New settings option to determine what happens when you middle-click on a conversation or channel.
		}
		--	Variablen anlegen
		tom.throttle={}
		tom.mdt={}
		tom.mmt={}
		tom.mmtCount=0
		tom.CatacombRows=15
		tom.CatacombScrollsMaxPages=50
		tom.isChattering=false
		tom.guildMembersReaded=false
		tom.dayofBirth=1446764400
		tom.throttleCount=200
		tom.throttlelast=0
		tom.chatcolor="E6E6AA"
		tom.timestampColor="808080"
		tom.exemptionForSettingsChanges=false --P5YCH3 - New variable. Prevents chat being triggered when changing name display settings.
		tom.senderColor="C0C0C0"
		tom.authorColor="DBBA21"
		tom.windowName="tomWindow"
		tom.windowNameMain="tomWindow01"
		tom.systemAccount="TOM@Tom"
		tom.authorAccount="Sternentau"
		tomreborn.authorAccount="|c4779ce" .. "P5YCH3" .. "|r"
		tomreborn.authorAccount_InGameName="P5YCH3"
		tom.systemCoreType=1701
		tom.gomMaxButtons=30
		tom.chatMaxWidth=1200
		tom.maxGuildMessageLength=699
		tom.maxCatacombMessageLength=699
		tom.gombuttonheight=24
		tom.gombuttonwidth=170
		tom.fmbuttonheight=24
		tom.fmbuttonwidth=24
		tom.fmtextwidth=170
		tom.fmrecipientwidth=100
		tom.fmButtons=10
		tom.MaxHistoryLines=1000
		tom.windowState=true
		tom.overrideAlert=false
		tom.magicState=true
		tom.catacombState=true
		tom.guildState=true
		tom.scanState=true
		tom.failState=true
		tom.lombuttonheight=24
		tom.lombuttonwidth=170
		tom.lomButtons=10
		tom.lomMaxButtons=10
		tom.alrStatus=0
		tom.alrPhase=0
		tom.ovrChatter=false
		tom.ovrCombat=false
		tom.ovrStrip=false
		tom.guildindex=0
		tom.guild={maccount={}, mstatus={}, msecsoff={}, mchar={}, mzone={}, mclasstype={}, malliance={}, mlevel={},mveteranRank={},}
		tom.guildButtons=24
		tom.guildbuttonheight=24
		tom.guildbuttonwidth=128
		tom.guildstatusbuttonwidth=24
		tom.guildFirstButton=1
		tom.GuildBlockWidth=195
		tom.GuildBlock3=120
		tom.guildIsReaded=false
		tom.guildMouseActions=9
		tom.scanbuttonheight=24
		tom.scanbuttonwidth=220
		tom.MailBoxOpen=false
		tom.wait4mail=false
		tom.lastMDTindex=0
		tom.oneDay=86400
		tom.mmtgrp=90001
		tom.mmtg01=90002
		tom.mmto01=90003
		tom.mmtg02=90004
		tom.mmto02=90005
		tom.mmtg03=90006
		tom.mmto03=90007
		tom.mmtg04=90008
		tom.mmto04=90009
		tom.mmtg05=90010
		tom.mmto05=90011
		tom.mmtsay=90012
		tom.mmtzzz=90013
		tom.mmtzde=90014
		tom.mmtzfr=90015
		tom.mmtzen=90016
		--===========================================
		--P5YCH3 - Translation additions.
		--===========================================
		tom.mmtzjp=90017
		tom.mmtzru=90018
		tom.mmtzes=90019
		--===========================================
		tom.mmtlom=90100
		-- tom.mmtsys=0 //
		tom.mmtsys=91234
		tom.lomSelectElements=6
		tom.scanTargetMax=20
		tom.scanTarget=false
		tom.msgRetentions={0,1,2,3,4,5,6,7,10,12,14,21,30,60}
		tom.msgRetentionsWhisper={0,1,2,3,4,5,6,7,14,30,60,90,180,365}
		tom.code1="äöüaeiouAEIOUbcdfghjklmnpqrstvwxyzBCDFGHJKLMNPQRSTVWXYZ5678901234"
		tom.code2="üäöeiouaEIOUAzbcdfghjklmnpqrstvwxyZBCDFGHJKLMNPQRSTVWXY0123456789"
		tom.codeTrigger1="(TOMish): " tom.codeTrigger2="(TIMish): "
		tom.ClientLanguage=GetCVar("language.2")
		-- Variablen hinzuladen
		tom.vars = ZO_SavedVars:NewAccountWide("tomvars", 2, nil, tom.tom_defaults)
		-- Spracheinstellung laden (sonst die Standardsprache EN)
		tom.LoadLocalization(tom.ClientLanguage)
		-- Einstellungen an Spracheinstellung anpassen
		-- Adapt settings to language setting
		tom.translateSettings()
		--Das Hauptfenster und den Alerter beim ersten Start platzieren
		--Place the main window and alerter on first launch
		if tom.vars.twt[tom.windowNameMain]==nil then
			tom.vars.twt[tom.windowNameMain]={act=true,X=GuiRoot:GetWidth()-100-tom.vars.chatWidth-tom.gombuttonwidth,Y=GuiRoot:GetHeight()-200-tom.vars.gomButtons*tom.gombuttonheight,gom=0}
			tom.vars.AofX=tom.vars.twt[tom.windowNameMain].X-80
			tom.vars.AofY=tom.vars.twt[tom.windowNameMain].Y
		end
		-- Beim ersten Start die Beispiel- magischen Nachrichten erzeugen
		-- Generate sample magic messages on first launch
		if ((tom.vars.firstRun==true) and (tom.vars.lomCount==0)) then
			tom.vars.lom[1]=tom.locTxt[73]
			tom.vars.lomCount=1
			tom.vars.shownLOM=1
			tom.vars.CatacombScrollsText=tom.locTxt[87]
		end
		-- Die erste Katakombenseite benennen, wenn sie noch keinen Namen hat
		-- Name the first catacomb page if it doesn't already have a name
		if tom.vars.CatacombNames[1]==nil then
			tom.vars.CatacombNames[1]=tom.locTxt[147]
		end
		-- Keybinding ermöglichen
		ZO_CreateStringId("SI_BINDING_NAME_TOM_TOGGLE",tom.locTxt[1][1])
		ZO_CreateStringId("SI_BINDING_NAME_TOM_GUILD",tom.locTxt[1][2])
		ZO_CreateStringId("SI_BINDING_NAME_TOM_CATAC",tom.locTxt[1][3])
		ZO_CreateStringId("SI_BINDING_NAME_TOM_MAGIC",tom.locTxt[1][4])
		ZO_CreateStringId("SI_BINDING_NAME_TOM_SCAN",tom.locTxt[1][5])
		ZO_CreateStringId("SI_BINDING_NAME_TOM_FAIL",tom.locTxt[1][6])
		ZO_CreateStringId("SI_BINDING_NAME_TOM_RELOAD",tom.locTxt[65])
		ZO_CreateStringId("SI_BINDING_NAME_TOM_LOGOUT",tom.locTxt[66])
		ZO_CreateStringId("SI_BINDING_NAME_TOM_QUIT",tom.locTxt[67])
		tom.updateCore()


		tom.reorgUndockedWindows()
		-- Die UI aufbauen und einstellen
		tom.InitializeUI()
		-- Die Gilden überprüfen
		tom.checkVanishedGuilds()
		-- Einstellungen eintragen
		tom.InitializeOptions()
		-- Wenn noch nie eine aktuelle Gilde gesetzt war, dann auf die erste Gilde setzen, wenn es denn eine gibt
		if ((tom.vars.actualGuild==0) and (tom.vars.Guilds[1]~="")) then tom.guildNextGuild(true) end
		-- Startvorbereitungen
		tom.GameStartTime=GetTimeStamp()
		if tom.vars.lastActiveTime==0 then tom.vars.lastActiveTime=tom.GameStartTime end
		tom.GameResumedAfter=GetDiffBetweenTimeStamps(tom.GameStartTime, tom.vars.lastActiveTime)
		-- Die Fenster in den angeforderten Zustand bringen
		tom.showWindow(tom.vars.requestedWindowState)
		-- den letzten Nachrichtendump vernichten
		tom.dumpMessages(false)
		-- und los
		tom.loaded=true
	end
end

function tom.resetAll()
	tom.closeUndockedWindows()
	tom.vars.msgType=nil tom.vars.msgFrom=nil tom.vars.msgText=nil tom.vars.msgTime=nil tom.vars.msgRead=nil tom.vars.msgDltd=nil
	tom.vars.msgType={}  tom.vars.msgFrom={}  tom.vars.msgText={}  tom.vars.msgTime={}  tom.vars.msgRead={}  tom.vars.msgDltd={}
	tom.vars.msgCount=0
	tom.vars.persons=nil tom.vars.persons={}
	tom.vars.personCount=0
	tom.clearRolle(tom.windowNameMain)
	tom.vars.twt[tom.windowNameMain].gom=nil
	tomCatacombTarget:SetText(nil)
	tom.rebuildMMT()
	tom.resetUI()
	tom.refreshUIwindow()
end

function tom.noSpin()
	for name, scene in pairs(SCENE_MANAGER.scenes) do
		if not (name):find("market") and scene:HasFragment(FRAME_PLAYER_FRAGMENT) then
			scene:RemoveFragment(FRAME_PLAYER_FRAGMENT)
		end
	end
end

function tom.dumpMessages(opmode)
	if opmode==false then tom.vars.memorydump=nil else
		tom.vars.msgdump={}
		for Looper=1,tom.vars.msgCount,1 do
			tom.vars.msgdump[Looper]=tom.formatRolleMsg(Looper,true)
		end
		tom.sendMessage(tom.locMsg(150,tom.vars.msgCount))
	end
end

--===========================================
-- TOM ADDON PANEL FUNCTIONS -- P5YCH3
--===========================================
function tom.ShowAddonSettingsMenu()
	LibAddonMenu2:OpenToPanel(TOMAddonPanel)
end

function tomUI.ShowAddonSettingsMenu()
	LibAddonMenu2:OpenToPanel(TOMAddonPanel)
end
--===========================================

function tom.SlashCMD(svar)
	if string.sub(svar,1,5)=="reset" then tom.resetAll()
	elseif string.sub(svar,1,1)=="" then tomUI.AlerterClick() -- P5YCH3 - Command without variable now activates the main TOM window.
	elseif string.sub(svar,1,8)=="settings" then tom.ShowAddonSettingsMenu() -- P5YCH3 - New function '/tom settings' to open the settings panel.
	--elseif string.sub(svar,1,4)=="lang" then if GetCVar("language.2")=="de" then SetCVar("language.2","en") else SetCVar("language.2","de") end
	elseif string.sub(svar,1,4)=="lang" then if GetCVar("language.2")=="de" then SetCVar("language.2","ru") elseif GetCVar("language.2")=="ru" then SetCVar("language.2","en") else SetCVar("language.2","de") end
	elseif string.sub(svar,1,6)=="import" then tom.importFromTIM()
	elseif string.sub(svar,1,4)=="mail" then tom.mailStatus(false)
	elseif string.sub(svar,1,7)=="msgdump" then tom.dumpMessages()
	elseif string.sub(svar,1,4)=="test" then tom.sendMessage(tom.time(500));
	elseif string.sub(svar,1,8)=="printloc" then tom.sendMessage(tom.locTxt[129]); --P5YCH3 - Just an easy way to test return value of locTxt messages. Work smart not hard.
	--else tom.sendSystemStatus() end
	elseif string.sub(svar,1,6)=="status" then tom.sendSystemStatus() end -- P5YCH3 - New variable '/tom status' to replace the status function command.
end



SLASH_COMMANDS["/tombug"] = function()
    echo("|cFF0000Beginning debug mode for TOM.")
    tom.debug = true
end
--	Die Events setzen, und dann kann es schon losgehen ;-)
EVENT_MANAGER:RegisterForEvent(tom.name,EVENT_ADD_ON_LOADED,tom.Initialize)
EVENT_MANAGER:RegisterForEvent(tom.name,EVENT_PLAYER_ACTIVATED,tom.EnterWorld)
EVENT_MANAGER:RegisterForEvent(tom.name,EVENT_CHAT_MESSAGE_CHANNEL,tom.IncomingMessage)
EVENT_MANAGER:RegisterForEvent(tom.name,EVENT_MAIL_OPEN_MAILBOX,tom.sendMailopenMailBox)
EVENT_MANAGER:RegisterForEvent(tom.name,EVENT_MAIL_CLOSE_MAILBOX,tom.sendMailcloseMailBox)
EVENT_MANAGER:RegisterForEvent(tom.name,EVENT_MAIL_SEND_FAILED,tom.sendMailFailure)
EVENT_MANAGER:RegisterForEvent(tom.name,EVENT_MAIL_SEND_SUCCESS,tom.sendMailSuccess)
EVENT_MANAGER:RegisterForEvent(tom.name,EVENT_CHATTER_BEGIN,tom.setChatter)
EVENT_MANAGER:RegisterForEvent(tom.name,EVENT_CHATTER_END,tom.endChatter)
EVENT_MANAGER:RegisterForEvent(tom.name,EVENT_RETICLE_TARGET_CHANGED,tom.targetChanged)
EVENT_MANAGER:RegisterForEvent(tom.name,EVENT_GUILD_SELF_JOINED_GUILD,tom.guildJoined)
EVENT_MANAGER:RegisterForEvent(tom.name,EVENT_GUILD_SELF_LEFT_GUILD,tom.guildLeft)
EVENT_MANAGER:RegisterForEvent(tom.name,EVENT_PLAYER_STATUS_CHANGED,tom.onlineStatusChange)
SLASH_COMMANDS["/tom"] = tom.SlashCMD