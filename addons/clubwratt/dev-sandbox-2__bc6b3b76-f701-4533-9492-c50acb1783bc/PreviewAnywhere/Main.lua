-- Main.lua: slash commands and load sequence.
local PA = PreviewAnywhere

-- Registered at file scope so "/pva status" answers even if Initialize never runs.
local function HandleCommand(args)
    local command, rest = string.match(args or "", "^%s*(%S*)%s*(.-)%s*$")
    command = string.lower(command or "")
    local Probe = PA.Probe
    if not Probe then
        PA.Chat(PA.Fmt("probe module missing (file load failed); initErrors=%d", #PA.diagnostics.initErrors))
        return
    end

    if command == "" or command == "help" then
        Probe.Help()
    elseif command == "probe" then
        PA.SafeCall("probe", Probe.Report)
    elseif command == "linktest" then
        local force = string.find(string.lower(rest), "force", 1, true) ~= nil
        PA.SafeCall("linktest", Probe.LinkTest, tonumber(string.match(rest, "%d+")), force)
    elseif command == "styletest" then
        PA.SafeCall("styletest", Probe.StyleTest, string.match(rest, "%d+"))
    elseif command == "status" then
        Probe.Status()
    elseif command == "export" then
        PA.Export()
    elseif command == "clear" then
        local lib = rawget(_G, "LibConsoleLogger")
        if lib and lib.Clear then lib:Clear() end
        PA.Chat("log cleared")
    elseif command == "debug" then
        PA.state.savedVars.debug = not PA.state.savedVars.debug
        PA.Chat(PA.Fmt("debug mode %s (%s)", PA.state.savedVars.debug and "ON" or "OFF", PA.LoggerStateLine()))
    elseif command == "chat" then
        PA.state.savedVars.debugChat = not PA.state.savedVars.debugChat
        PA.Chat(PA.Fmt("debug lines to chat: %s", PA.state.savedVars.debugChat and "ON" or "OFF"))
    elseif command == "on" or command == "off" then
        PA.state.savedVars.enabled = command == "on"
        PA.Chat(PA.Fmt("preview actions %s", command == "on" and "enabled" or "disabled"))
        PA.SafeCall("InventoryFraming.Apply", PA.InventoryFraming.Apply)
    elseif command == "vault" then
        PA.VaultCategories.Command(rest)
    elseif command == "invframe" then
        PA.state.savedVars.inventoryFraming = PA.state.savedVars.inventoryFraming == false
        PA.Chat(PA.Fmt("inventory preview framing: %s", PA.state.savedVars.inventoryFraming and "vendor style (beside the tooltip)" or "game default"))
        PA.SafeCall("InventoryFraming.Apply", PA.InventoryFraming.Apply)
    else
        PA.Chat(PA.Fmt("unknown command '%s'", command))
        Probe.Help()
    end
end

SLASH_COMMANDS["/pva"] = HandleCommand
SLASH_COMMANDS["/previewanywhere"] = HandleCommand
-- Kept from the standalone Vault Categories addon: /vcat <args> = /pva vault <args>.
SLASH_COMMANDS["/vcat"] = function(args) PA.VaultCategories.Command(args) end

local function Initialize()
    local d = PA.diagnostics
    if d.initialized then
        return
    end
    d.initialized = true

    local okSV, savedVars = pcall(ZO_SavedVars.NewAccountWide, ZO_SavedVars, PA.savedVarsName, PA.savedVarsVersion, nil, PA.state.savedVars)
    if okSV then
        PA.state.savedVars = savedVars
    else
        table.insert(d.initErrors, "savedVars: " .. tostring(savedVars))
    end

    if not (rawget(_G, "ITEM_PREVIEW_GAMEPAD") and rawget(_G, "ITEM_PREVIEW_LIST_HELPER_GAMEPAD")) then
        table.insert(d.initErrors, "gamepad item preview system not available")
        PA.Log("ERROR: gamepad item preview system not available; addon inactive")
        return
    end

    local function Init(label, fn)
        local ok, err = pcall(fn)
        if not ok then
            table.insert(d.initErrors, label .. ": " .. tostring(err))
        end
        return ok
    end
    local linkOk = Init("LinkPreview", PA.LinkPreview.Initialize)
    local slotOk = Init("SlotPreview", PA.SlotPreview.Initialize)
    local hoverOk = Init("Hover", PA.Hover.Initialize)
    local framingOk = Init("InventoryFraming", PA.InventoryFraming.Initialize)
    local vaultOk = Init("VaultCategories", PA.VaultCategories.Initialize)

    PA.Log("loaded v%s (links=%s, hosts=%s, hover=%s, framing=%s, vault=%s, %d init errors)", PA.version, tostring(linkOk), tostring(slotOk), tostring(hoverOk), tostring(framingOk),
        tostring(vaultOk), #d.initErrors)
    for _, err in ipairs(d.initErrors) do
        PA.Log("  initError: %s", err)
    end
    -- A broken install should be visible even without debug mode.
    if #d.initErrors > 0 then
        PA.Chat(PA.Fmt("v%s loaded with %d init error(s); /pva status for details", PA.version, #d.initErrors))
    end
end

EVENT_MANAGER:RegisterForEvent(PA.name .. "_Loaded", EVENT_ADD_ON_LOADED, function(_event, addonName)
    table.insert(PA.diagnostics.addonNames, addonName)
    if addonName == PA.name then
        EVENT_MANAGER:UnregisterForEvent(PA.name .. "_Loaded", EVENT_ADD_ON_LOADED)
        Initialize()
    end
end)

-- Debug mode: every Lua error from any addon or the base UI (consoles show none of them) goes to
-- the log, so a broken screen comes with its stack trace in the export.
local luaErrors = 0
EVENT_MANAGER:RegisterForEvent(PA.name .. "_LuaError", EVENT_LUA_ERROR, function(_event, errorText, errorCode)
    if not PA.IsDebug() then
        return
    end
    luaErrors = luaErrors + 1
    PA.Count("luaErrors")
    if luaErrors <= 20 then
        local text = tostring(errorText)
        if #text > 900 then
            text = string.sub(text, 1, 900) .. " ..."
        end
        PA.Log("LUA ERROR #%d (code %s): %s", luaErrors, tostring(errorCode), text)
    end
end)

-- Fallback in case EVENT_ADD_ON_LOADED never carries our manifest name on this platform.
EVENT_MANAGER:RegisterForEvent(PA.name .. "_Activated", EVENT_PLAYER_ACTIVATED, function()
    EVENT_MANAGER:UnregisterForEvent(PA.name .. "_Activated", EVENT_PLAYER_ACTIVATED)
    if not PA.diagnostics.initialized then
        PA.diagnostics.lateInit = true
        Initialize()
    end
    if PA.IsDebug() then
        PA.Chat(PA.Fmt("v%s active, debug mode on (%s). /pva for commands.", PA.version, PA.LoggerStateLine()))
    end
end)
