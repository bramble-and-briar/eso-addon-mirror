PredefineChatMessages = {}
PredefineChatMessages.name = "PredefineChatMessages"
PredefineChatMessages.version = "1.4.6"
PredefineChatMessages.changesmade = false
PredefineChatMessages.defaultSettings = { 
    messages = { "", "", "", "", "", "", "", "", "", "" },
    cmds = { "/predef1", "/predef2", "/predef3", "/predef4", "/predef5", "/predef6", "/predef7", "/predef8", "/predef9", "/predef10" },
}

local amountOfPredefinedMessages = 10

-- Localization strings
local strings = {
  TITLE = {
      en = "Predefine Chat Messages",
      de = "Vordefinierte Chat-Nachrichten",
      fr = "Messages de chat prédéfinis",
      ru = "Предустановленные сообщения чата",
      jp = "定型チャットメッセージ",
      zh = "预设聊天信息",
      es = "Mensajes de chat predefinidos",
      it = "Messaggi chat predefiniti",
      pl = "Predefiniowane wiadomości czatu",
  },
  MESSAGE = {
      en = "Message",
      de = "Nachricht",
      fr = "Message",
      ru = "Сообщение",
      jp = "メッセージ",
      zh = "信息",
      es = "Mensaje",
      it = "Messaggio",
      pl = "Wiadomość",
  },
  MESSAGE_HEADER = {
      en = "Predefined Message",
      de = "Vordefinierte Nachricht",
      fr = "Message prédéfini",
      ru = "Предустановленное сообщение",
      ja = "定型メッセージ",
      zh = "预设消息",
      es = "Mensaje predefinido",
      it = "Messaggio predefinito",
      pl = "Wiadomość predefiniowana",
  },
  SLASH_COMMAND = {
      en = "Slash Command",
      de = "Slash-Befehl",
      fr = "Commande slash",
      ru = "Команда с косой чертой",
      jp = "スラッシュコマンド",
      zh = "斜杠命令",
      es = "Comando slash",
      it = "Comando slash",
      pl = "Komenda slash",
  },
  SLASH_COMMAND_TOOLTIP = {
      en = "Choose your own slash command to use for predefined message (max 12 characters)",
      de = "Wähle deinen eigenen Slash-Befehl für die folgende vordefinierte Nachricht (max. 12 Zeichen)",
      fr = "Choisissez votre propre commande slash à utiliser avec le message prédéfini suivant (12 caractères max)",
      ru = "Выберите собственную команду с косой чертой для использования с следующим предустановленным сообщением (макс. 12 символов)",
      jp = "次の定型メッセージで使用するスラッシュコマンドを自分で選んでください （最大12文字）",
      zh = "为以下预设消息选择您自己的斜杠命令 （最多12个字符）",
      es = "Elige tu propio comando slash para usar con el mensaje predefinido (máx. 12 caracteres)",
      it = "Scegli il tuo comando slash da usare per il messaggio predefinito (max 12 caratteri)",
      pl = "Wybierz własną komendę slash do użycia z predefiniowaną wiadomością (maks. 12 znaków)",
  },
  TOOLTIP = {
    en = "Message for slash command %d (max 350 characters)",
    de = "Nachricht für Slash-Befehl %d (max. 350 Zeichen)",
    fr = "Message pour la commande slash %d (350 caractères maximum)",
    ru = "Сообщение для команды с косой чертой %d (макс. 350 символов)",
    ja = "スラッシュコマンド%d用のメッセージ（最大350文字）",
    zh = "斜杠命令 %d 的消息（最多350个字符）",
    es = "Mensaje para el comando slash %d (máx. 350 caracteres)",
    it = "Messaggio per il comando slash %d (max 350 caratteri)",
    pl = "Wiadomość dla komendy slash %d (maks. 350 znaków)",
  },
  NOPREDEF = {
      en = "No Predefine message saved for",
      de = "Keine vordefinierte Nachricht gespeichert für",
      fr = "Aucun message prédéfini enregistré pour",
      ru = "Нет сохранённого предустановленного сообщения для",
      jp = "定義済みメッセージが保存されていません：",
      zh = "未保存预设消息用于：",
      es = "No hay mensaje predefinido guardado para",
      it = "Nessun messaggio predefinito salvato per",
      pl = "Brak zapisanej predefiniowanej wiadomości dla",
  },
  NOTICE_MESSAGE = {
    en = [[You cannot use slash commands that are already being used by eso or other addons. If you enter a slash command already in use, it will revert to its previous value when exiting the addon options.
Make sure to use the apply button below if you have made any changes to the slash commands (not necessary when changing only the messages)]],
    de = [[Du kannst keine Slash-Befehle verwenden, die bereits von ESO oder anderen Addons genutzt werden. Wenn du einen bereits verwendeten Slash-Befehl eingibst, wird beim Verlassen der Addon-Einstellungen der vorherige Wert wiederhergestellt.
Bitte den untenstehenden Übernehmen-Button verwenden, wenn du Änderungen an den Slash-Befehlen vorgenommen hast (nicht nötig bei Änderungen nur an den Nachrichten)]],
    fr = [[Vous ne pouvez pas utiliser de commandes slash déjà utilisées par ESO ou d'autres extensions. Si vous saisissez une commande slash déjà utilisée, sa valeur précédente sera rétablie en quittant les options de l'addon.
Utilisez le bouton Appliquer ci-dessous si vous avez modifié les commandes slash (inutile si seuls les messages ont été changés)]],
    ru = [[Вы не можете использовать команды с косой чертой, которые уже используются ESO или другими дополнениями. Если вы введёте такую команду, при выходе из настроек аддона будет восстановлено предыдущее значение.
Обязательно нажмите кнопку «Применить» ниже, если вы изменили команды с косой чертой (не требуется, если изменены только сообщения)]],
    ja = [[ESOや他のアドオンですでに使用されているスラッシュコマンドは使用できません。すでに使用中のスラッシュコマンドを入力した場合、アドオンオプションを終了すると以前の値に戻されます。
スラッシュコマンドを変更した場合は、下の「適用」ボタンを使用してください（メッセージのみの変更なら不要です）]],
    zh = [[您不能使用 ESO 或其他插件已在使用的斜杠命令。如果输入已被占用的斜杠命令，在退出插件选项时将恢复为之前的值。
如果更改了斜杠命令，请务必点击下方的“应用”按钮（仅更改消息时则不需要）]],
    es = [[No puedes usar comandos slash que ya estén siendo usados por ESO u otros addons. Si introduces un comando slash ya en uso, volverá a su valor anterior al salir de las opciones del addon.
Asegúrate de usar el botón aplicar abajo si has hecho cambios en los comandos slash (no es necesario si solo cambias los mensajes)]],
    it = [[Non puoi usare comandi slash già utilizzati da ESO o altri addon. Se inserisci un comando slash già in uso, tornerà al valore precedente quando esci dalle opzioni dell'addon.
Assicurati di usare il pulsante applica qui sotto se hai modificato i comandi slash (non necessario se cambi solo i messaggi)]],
    pl = [[Nie możesz używać komend slash, które są już używane przez ESO lub inne dodatki. Jeśli wpiszesz komendę slash już używaną, po wyjściu z opcji dodatku zostanie przywrócona poprzednia wartość.
Użyj poniższego przycisku zastosuj, jeśli zmieniłeś komendy slash (nie jest to konieczne przy zmianie tylko wiadomości)]],
  },
  NOTICE_LABEL = {
    en = "Notice",
    de = "Hinweis",
    fr = "Remarque",
    ru = "Уведомление",
    ja = "注意",
    zh = "提示",
    es = "Aviso",
    it = "Avviso",
    pl = "Uwaga",
  },
  BUTTON_LABEL_APPLYCHANGES = {
    en = "Apply Changed Commands",
    de = "Befehle Übernehmen",
    fr = "Appliquer Commandes",
    ru = "Применить команды",
    ja = "コマンド適用",
    zh = "应用命令",
    es = "Aplicar comandos cambiados",
    it = "Applica comandi modificati",
    pl = "Zastosuj zmienione komendy",
  },
  BUTTON_TOOLTIP_APPLYCHANGES = {
    en = "This will perform a reloadui so that the new slash commands will be applied.",
    de = "Dies führt ein reloadui aus, damit die neuen Slash-Befehle übernommen werden.",
    fr = "Cela effectuera un reloadui pour appliquer les nouvelles commandes slash.",
    ru = "Будет выполнен reloadui, чтобы применить новые команды с косой чертой.",
    ja = "新しいスラッシュコマンドを適用するために reloadui が実行されます。",
    zh = "这将执行 reloadui，以应用新的斜杠命令。",
    es = "Esto realizará un reloadui para que se apliquen los nuevos comandos slash.",
    it = "Questo eseguirà un reloadui per applicare i nuovi comandi slash.",
    pl = "To wykona reloadui, aby zastosować nowe komendy slash.",
  }
}

local function L(key)
    local lang = GetCVar("Language.2")
    return strings[key][lang] or strings[key]["en"]
end

local function IsSlashCommandInUse(command)
    return SLASH_COMMANDS[string.lower(command)] ~= nil
end

local function SafeStartChatInput(text, channel, target)
    local isRestrictedCommunicationPermitted = true
    if target ~= nil and IsCommunicationRestricted() then
        isRestrictedCommunicationPermitted = CanCommunicateWith(target)
    end
    if IsChatSystemAvailableForCurrentPlatform() and isRestrictedCommunicationPermitted then
        ZO_GetChatSystem():StartTextEntry(text, channel, target, true)
    end
end

local function SendPredefineMessage(index)
    local msg = PredefineChatMessages.savedVars.messages[index]
    local chat = LibChatMessage("Predefine Chat Messages", "PDM")
    if msg and msg ~= "" then
        SafeStartChatInput(msg) 
    else
      chat:SetTagColor("ff0000"):Print(L("NOPREDEF") .. " /predef" .. index)
    end
end

local function RegisterSlashCommands()
    for i = 1, amountOfPredefinedMessages do
      if PredefineChatMessages.savedVars.cmds[i] ~= nil and PredefineChatMessages.savedVars.cmds[i] ~= "" then
        SLASH_COMMANDS[PredefineChatMessages.savedVars.cmds[i]] = function()
            SendPredefineMessage(i)
        end
      end
    end
end

local function ReplaceSlashCommand(i, oldcmd, newcmd)
   SLASH_COMMANDS[newcmd] = function()
      SendPredefineMessage(i)
   end
   SLASH_COMMANDS[oldcmd] = nil
end

function CreateSettingsPanel()   
    if IsConsoleUI() and not LibAddonMenu2 then return end

    local LAM = LibAddonMenu2
    local panelName = PredefineChatMessages.name .. "OptionsPanel"

    local panelData = {
        type = "panel",
        name = L("TITLE"),
        displayName = "|c00FF00" .. L("TITLE") .. "|r",
        author = "msetten",
        version = PredefineChatMessages.version,
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsTable = {}

    table.insert(optionsTable, {
        type = "description",
        title = L("NOTICE_LABEL"),
        text = L("NOTICE_MESSAGE"),
        reference = "noticeRefName",
      }
    )

    table.insert(optionsTable, {
      type = "button",
      name = L("BUTTON_LABEL_APPLYCHANGES"),
      tooltip = L("BUTTON_TOOLTIP_APPLYCHANGES"),
      func = function() ReloadUI("ingame") end,
      width = "full",
      disabled = function() return not PredefineChatMessages.changesmade end
    })

    for i = 1, amountOfPredefinedMessages do
        local editboxRefName = "PredefineChatMessageEditbox" .. i
        local editboxRefNameSlash = "PredefineChatMessageEditboxSlash" .. i
        local headerRefName = "PredefinedChatMessageHeader" .. i

        table.insert(optionsTable, {
            type = "header",
            name = string.format("%s %d", L("MESSAGE_HEADER"), i),
            reference = headerRefName
          }
        )

        table.insert(optionsTable, {
            type = "editbox",
            name = L("MESSAGE"),
            tooltip = string.format(L("TOOLTIP"), i),
            getFunc = function() return PredefineChatMessages.savedVars.messages[i] end,
            setFunc = function(val) 
              PredefineChatMessages.savedVars.messages[i] = string.sub(val, 1, 350) 
            end,
            isMultiline = true,
            width = "full",
            maxChars = 350,
            reference = editboxRefName,
            default = "",
        })

        table.insert(optionsTable, {
            type = "editbox",
            name = L("SLASH_COMMAND"),
            tooltip = L("SLASH_COMMAND_TOOLTIP"),
            getFunc = function() return PredefineChatMessages.savedVars.cmds[i] end,
            setFunc = function(val) 
              if string.sub(val, 1, 1) ~= "/" then
                val = "/" .. val
              end
              if (IsSlashCommandInUse(val) and val ~= PredefineChatMessages.savedVars.cmds[i]) or val == "/" then 
                val = PredefineChatMessages.savedVars.cmds[i]
              else 
                oldcmd = PredefineChatMessages.savedVars.cmds[i]
                PredefineChatMessages.savedVars.cmds[i] = string.sub(val, 1, 13)
                PredefineChatMessages.changesmade = true
                ReplaceSlashCommand(i, oldcmd, PredefineChatMessages.savedVars.cmds[i])
              end
              
            end,
            isMultiline = false,
            width = "full",
            maxChars = 13,
            reference = editboxRefNameSlash,
            default = "",
          }
        )
    end

    table.insert(optionsTable, {
      type = "button",
      name = L("BUTTON_LABEL_APPLYCHANGES"),
      tooltip = L("BUTTON_TOOLTIP_APPLYCHANGES"),
      func = function() ReloadUI("ingame") end,
      width = "full",
      disabled = function() return not PredefineChatMessages.changesmade end
    })

    LAM:RegisterAddonPanel(panelName, panelData)
    LAM:RegisterOptionControls(panelName, optionsTable)
end

local function addAdditionalCommands()
  if #PredefineChatMessages.savedVars.messages >= amountOfPredefinedMessages then return end
  for i = #PredefineChatMessages.savedVars.cmds + 1, amountOfPredefinedMessages do
    table.insert(PredefineChatMessages.savedVars.cmds, "/predef" .. i)
    table.insert(PredefineChatMessages.savedVars.messages, "")
  end
end

-- OnAddOnLoaded
function PredefineChatMessages.OnAddOnLoaded(event, addonName)
    if addonName ~= PredefineChatMessages.name then return end
    
    PredefineChatMessages.savedVars = ZO_SavedVars:NewAccountWide("PredefineChatMessagesSaved", 1, nil, PredefineChatMessages.defaultSettings)

    addAdditionalCommands() -- in case of an update from an older version
    
    CreateSettingsPanel()
    RegisterSlashCommands()

    EVENT_MANAGER:UnregisterForEvent(PredefineChatMessages.name .. "_Loaded", EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(PredefineChatMessages.name .. "_Loaded", EVENT_ADD_ON_LOADED, PredefineChatMessages.OnAddOnLoaded)