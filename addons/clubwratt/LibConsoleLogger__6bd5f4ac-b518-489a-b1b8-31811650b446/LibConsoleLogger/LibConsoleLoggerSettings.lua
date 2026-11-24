-- LibConsoleLoggerSettings.lua: LibHarvensAddonSettings integration

LibConsoleLogger = LibConsoleLogger or {}
LibConsoleLogger.Settings = LibConsoleLogger.Settings or {}

local Settings = LibConsoleLogger.Settings

Settings.initialized = Settings.initialized or false
Settings.panel = Settings.panel or nil

local URL_DIALOG_NAME = "LIB_CONSOLE_LOGGER_SET_URL"
-- Generous for LAN receivers and tunnel URLs while staying well under engine limits.
local MAX_URL_INPUT_CHARS = 256

local function ShowLogDialog()
    local dialog = LibConsoleLogger and LibConsoleLogger.LogDialog
    if dialog and dialog.Show then
        dialog:Show()
    end
end

local function GetWebExport()
    return LibConsoleLogger and LibConsoleLogger.WebExport
end

---@return string
local function GetCurrentUrl()
    local webExport = GetWebExport()
    local current = webExport and webExport.GetUrl and webExport.GetUrl(nil) or ""
    return tostring(current or "")
end

-- ============================================================================
-- Export URL input dialog
--
-- LibHarvensAddonSettings' ST_EDIT row does not reliably summon the console
-- virtual keyboard, so the URL is edited through a standard gamepad parametric
-- dialog with a text field entry (the same flow the base game uses for e.g.
-- guild rank names), which opens the keyboard dependably.
-- ============================================================================

local urlDialogRegistered = false
local pendingUrl = ""

local function ReleaseUrlDialog()
    if ZO_Dialogs_ReleaseDialogOnButtonPress then
        ZO_Dialogs_ReleaseDialogOnButtonPress(URL_DIALOG_NAME)
    end
end

local function SavePendingUrl()
    local webExport = GetWebExport()
    if webExport and webExport.SetUrl then
        webExport.SetUrl(pendingUrl, nil)
    end

    -- Re-run visible row setups so the URL button label reflects the new value.
    local LAS = _G["LibHarvensAddonSettings"]
    local list = LAS and LAS.list
    if list and list.RefreshVisible then
        list:RefreshVisible()
    end
end

---@return boolean registered
local function EnsureUrlDialogRegistered()
    if urlDialogRegistered then
        return true
    end
    if not (ZO_Dialogs_RegisterCustomDialog and GAMEPAD_DIALOGS) then
        return false
    end

    ZO_Dialogs_RegisterCustomDialog(URL_DIALOG_NAME, {
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
        },
        blockDialogReleaseOnPress = true,
        canQueue = true,
        title = {
            text = "Export URL",
        },
        mainText = {
            text = "Address of your log receiver, e.g. 192.168.1.50:7878.\n\n\"http://\" is added automatically if you don't include a scheme.",
        },
        setup = function(dialog)
            pendingUrl = GetCurrentUrl()
            dialog:setupFunc()
        end,
        parametricList = {
            {
                template = "ZO_Gamepad_GenericDialog_Parametric_TextFieldItem",
                templateData = {
                    urlField = true,
                    textChangedCallback = function(control)
                        pendingUrl = control:GetText()
                    end,
                    setup = function(control, data, selected)
                        control.highlight:SetHidden(not selected)
                        control.editBoxControl.textChangedCallback = data.textChangedCallback
                        control.editBoxControl:SetDefaultText("host:port or full URL")
                        control.editBoxControl:SetTextType(TEXT_TYPE_ALL)
                        control.editBoxControl:SetMaxInputChars(MAX_URL_INPUT_CHARS)
                        control.editBoxControl:SetText(pendingUrl)
                    end,
                },
            },
            {
                template = "ZO_GamepadTextFieldSubmitItem",
                templateData = {
                    finishedSelector = true,
                    text = GetString(SI_DIALOG_ACCEPT),
                    setup = ZO_SharedGamepadEntry_OnSetup,
                },
                icon = ZO_GAMEPAD_SUBMIT_ENTRY_ICON,
            },
        },
        buttons = {
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
                callback = function()
                    ReleaseUrlDialog()
                end,
            },
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = function(dialog)
                    local targetData = dialog.entryList and dialog.entryList:GetTargetData()
                    local targetControl = dialog.entryList and dialog.entryList:GetTargetControl()
                    if targetData and targetData.urlField and targetControl and targetControl.editBoxControl then
                        targetControl.editBoxControl:TakeFocus()
                    elseif targetData and targetData.finishedSelector then
                        SavePendingUrl()
                        ReleaseUrlDialog()
                    end
                end,
            },
        },
    })

    urlDialogRegistered = true
    return true
end

local function ShowUrlDialog()
    if not EnsureUrlDialogRegistered() then
        return
    end
    ZO_Dialogs_ShowGamepadDialog(URL_DIALOG_NAME, nil, nil)
end

-- ============================================================================
-- Scope dropdown
--
-- The scopes are known only once the other addons have loaded and logged, well after this panel is built, so
-- the dropdown's items are a function: LibHarvensAddonSettings calls it each time it sets the row up.
-- ============================================================================

local ALL_SCOPES_LABEL = "All scopes"

-- One item table per scope, reused across row setups.
---@type table<string, { name: string, data: string }>
local scopeItemsByName = {}

---@param name string the dropdown label
---@param scope string the scope it selects, "" for all
---@return { name: string, data: string }
local function ScopeItem(name, scope)
    local item = scopeItemsByName[name]
    if not item then
        item = { name = name, data = scope }
        scopeItemsByName[name] = item
    end
    return item
end

---@return { name: string, data: string }[]
local function ScopeItems()
    local items = { ScopeItem(ALL_SCOPES_LABEL, "") }
    local scopes = LibConsoleLogger:GetScopes()
    for i = 1, #scopes do
        items[#items + 1] = ScopeItem(scopes[i], scopes[i])
    end
    return items
end

-- ============================================================================
-- Settings panel
-- ============================================================================

---@return boolean created
function Settings.Initialize()
    if Settings.initialized then
        return false
    end

    local LAS = _G["LibHarvensAddonSettings"]
    if not (LAS and LAS.AddAddon) then
        return false
    end

    local panel = LAS:AddAddon("LibConsoleLogger", { allowRefresh = true })
    if not panel then
        return false
    end

    panel.author = "clubwratt"
    panel.version = LibConsoleLogger.version

    Settings.initialized = true
    Settings.panel = panel

    local webExport = GetWebExport()

    panel:AddSetting({
        type = LAS.ST_SECTION,
        label = "Export",
    })

    panel:AddSetting({
        type = LAS.ST_CHECKBOX,
        label = "Enable logging",
        tooltip = "Master switch: buffer logs for export (and mirror to chat when enabled below).",
        getFunction = function()
            return LibConsoleLogger:IsEnabled()
        end,
        setFunction = function(value)
            LibConsoleLogger:SetEnabled(value)
        end,
    })

    panel:AddSetting({
        type = LAS.ST_CHECKBOX,
        label = "Log to chat",
        tooltip = "Mirror logged lines to the chat log as system messages.",
        getFunction = function()
            return LibConsoleLogger:IsChatEnabled()
        end,
        setFunction = function(value)
            LibConsoleLogger:SetChatEnabled(value)
        end,
    })

    panel:AddSetting({
        type = LAS.ST_SLIDER,
        label = "Buffer size",
        tooltip = "How many lines the log buffer keeps; the oldest are dropped first. Each export round trip (one browser open/close) carries roughly 80 short lines, so a smaller buffer means fewer round trips. Lowering it trims the buffer immediately. The buffer is saved with these settings, so it survives /reloadui, zone changes and relogs; exporting or disabling logging empties it. Default 4000.",
        min = (webExport and webExport.GetMinLines and webExport.GetMinLines()) or 50,
        max = (webExport and webExport.GetMaxLinesCeiling and webExport.GetMaxLinesCeiling()) or 4000,
        step = 50,
        format = "%d",
        unit = " lines",
        getFunction = function()
            return LibConsoleLogger:GetMaxLines()
        end,
        setFunction = function(value)
            LibConsoleLogger:SetMaxLines(value)
        end,
    })

    panel:AddSetting({
        type = LAS.ST_BUTTON,
        label = function()
            local current = GetCurrentUrl()
            if current == "" then
                return "Export URL: (not set)"
            end
            return "Export URL: " .. current
        end,
        tooltip = "Receiver URL for log export. \"http://\" is added automatically if you don't include a scheme.",
        buttonText = "Set",
        clickHandler = function()
            ShowUrlDialog()
        end,
    })

    panel:AddSetting({
        type = LAS.ST_LABEL,
        label = "How it works: Export opens \"<your URL>?d=<base64 data>\" in the game browser. Select this row for receiver instructions.",
        tooltip = "To receive logs, run a small web server (or ask an AI to write one):\n\n"
            .. "1. Listen for HTTP GET requests on any path.\n"
            .. "2. Read the \"d\" query parameter.\n"
            .. "3. Decode it as URL-safe base64 (\"-\" and \"_\" instead of \"+\" and \"/\").\n"
            .. "4. Append the decoded UTF-8 text to a file. One log line per newline.\n\n"
            .. "Large logs arrive as several requests; the next chunk is sent after you close the in-game browser, so appending each request in order reproduces the log.\n\n"
            .. "Set the Export URL to your computer's LAN address, e.g. 192.168.1.50:8080. Console and computer must be on the same network.",
    })

    panel:AddSetting({
        type = LAS.ST_DROPDOWN,
        label = "Scope",
        tooltip = "Whose lines you see and send: \"View logs\", the chat log and \"Export buffered logs\" (an addon's own export command too) show only the scope chosen here, plus this library's \"UI loaded\" markers and (see below) the game's errors. Every scope keeps being recorded whatever is chosen, so you can switch after the fact. An addon is listed once it has asked for its logger (LibConsoleLogger:For) or has lines in the buffer. Exporting one scope removes only that scope's lines from the buffer.",
        items = ScopeItems,
        ignoreDefault = true,
        getFunction = function()
            local scope = LibConsoleLogger:GetScope()
            return scope == "" and ALL_SCOPES_LABEL or scope
        end,
        setFunction = function(_, name, item)
            local scope = item and item.data
            if scope == nil then
                scope = (name == ALL_SCOPES_LABEL) and "" or name
            end
            LibConsoleLogger:SetScope(scope)
        end,
    })

    panel:AddSetting({
        type = LAS.ST_CHECKBOX,
        label = "Include errors",
        tooltip = "Show the game's Lua errors alongside the scope chosen above, in \"View logs\" and in an export. While logging is enabled every error is recorded, whichever addon or part of the game raised it: each distinct one once in full, then a count when it repeats. They are always there under \"All scopes\" and under the \"Errors\" scope; this switch only decides whether they come along with another scope.",
        getFunction = function()
            return LibConsoleLogger:IsIncludingErrors()
        end,
        setFunction = function(value)
            LibConsoleLogger:SetIncludeErrors(value)
        end,
    })

    panel:AddSetting({
        type = LAS.ST_BUTTON,
        label = "View logs",
        buttonText = "View",
        clickHandler = function()
            ShowLogDialog()
        end,
    })

    panel:AddSetting({
        type = LAS.ST_BUTTON,
        label = "Export buffered logs",
        buttonText = "Export",
        clickHandler = function()
            if LibConsoleLogger and LibConsoleLogger.Export then
                LibConsoleLogger:Export()
                return
            end
            if webExport and webExport.SubmitBuffered then
                webExport.SubmitBuffered(nil)
            end
        end,
    })

    panel:AddSetting({
        type = LAS.ST_BUTTON,
        label = "Clear buffered logs",
        tooltip = "Empties the whole buffer, every scope.",
        buttonText = "Clear",
        clickHandler = function()
            if LibConsoleLogger and LibConsoleLogger.Clear then
                LibConsoleLogger:Clear()
                return
            end
            if webExport and webExport.BufferClear then
                webExport.BufferClear()
            end
        end,
    })

    panel:AddSetting({
        type = LAS.ST_SECTION,
        label = "For addon developers",
    })

    panel:AddSetting({
        type = LAS.ST_LABEL,
        label = "Call this library from your addon's Lua code. Select this row for usage instructions.",
        tooltip = "Add to your manifest:\n"
            .. "  ## ConsoleDependsOn: LibConsoleLogger\n\n"
            .. "Then in your Lua code:\n"
            .. "  local logger = LibConsoleLogger:For(\"MyAddon\")\n"
            .. "  logger:Log(\"hello\", someTable)  -- buffer + chat; tables expand\n"
            .. "  logger:Buffer(\"quiet line\")     -- buffer only, no chat\n"
            .. "  logger:Debug(\"urgent\", info)    -- export immediately (needs URL)\n"
            .. "  logger:Export()                 -- export the whole buffer\n\n"
            .. "All calls are safe no-ops until the user enables logging above, so you can leave them in shipping code. Logged lines are prefixed with [MyAddon], and MyAddon becomes a choice in the Scope dropdown above.",
    })

    if LAS.RefreshAddonSettings then
        LAS:RefreshAddonSettings()
    end

    return true
end
