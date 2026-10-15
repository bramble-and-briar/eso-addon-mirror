-- My UI: independent startup and LibAddonMenu diagnostic.
-- Loaded first so failures in later modules can still be reported.
MyUIDebug = MyUIDebug or {}
local D = MyUIDebug
D.expectedName = "MyUI"
D.messages = D.messages or {}
D.errors = D.errors or {}
D.loaded = false
D.panelName = "BUI_BanditUI"

local function AddMessage(line)
    local entries = D.messages
    entries[#entries + 1] = tostring(line)
    if #entries > 45 then table.remove(entries, 1) end
end

function D.Note(phase, result)
    AddMessage(tostring(phase) .. ": " .. tostring(result))
end

local function Print(line)
    local message = "|cAACCFF[My UI Debug]|r " .. tostring(line)
    if type(d) == "function" then
        d(message)
    elseif rawget(_G, "CHAT_SYSTEM") and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage(message)
    end
end

local function FindLAM()
    local lam = rawget(_G, "LibAddonMenu2")
    if lam then return lam end
    local stub = rawget(_G, "LibStub")
    if stub ~= nil then
        local ok, lib = pcall(stub, "LibAddonMenu-2.0")
        if ok then return lib end
    end
    return nil
end

local function State()
    local bui = rawget(_G, "BUI")
    local bridge = bui and bui.SettingsBridge
    local init = bui and bui.Initialization
    local lam = FindLAM()
    if not D.loaded then
        return false, "EVENT_ADD_ON_LOADED fehlt (oder Add-on-Ladefehler)"
    end
    if not bui then return false, "BUI_Vars.lua wurde nicht ausgefuehrt" end
    if bui.name ~= D.expectedName then
        return false, "Namensfehler: BUI.name=" .. tostring(bui.name)
    end
    if not lam then return false, "LibAddonMenu-2.0 fehlt / wurde nicht geladen" end
    if not init or not init.addOnLoadedHandled then
        return false, "BUI_Initialize.lua: Ladeereignis nicht verarbeitet"
    end
    local steps = init.stages
    if steps then
        for name, result in pairs(steps) do
            if type(result) == "string" and string.sub(result, 1, 6) == "error:" then
                return false, "Startfehler in " .. name .. ": " .. result
            end
        end
    end
    if init.steps then
        for name, result in pairs(init.steps) do
            if type(result) == "string" and string.sub(result, 1, 6) == "error:" then
                return false, "Startfehler in " .. name .. ": " .. result
            end
        end
    end
    if not bridge then return false, "SXUI_LAMBridge.lua fehlt" end
    if not (bridge.groupedPanelData and bridge.groupedPanelData[D.panelName]) then
        return false, "BUI.Menu.Initialize: LAM-Einstellungen nicht gesammelt"
    end
    if not (bridge.groupedFinalized and bridge.groupedFinalized[D.panelName]) then
        return false, "LAM-Panel nicht fertig registriert (FinalizeGrouped)"
    end
    if not (bridge.panels and bridge.panels[D.panelName]) then
        return false, "LAM-Panel fehlt trotz FinalizeGrouped"
    end
    local count = bridge.groupedOptionCount and bridge.groupedOptionCount[D.panelName] or 0
    if count < 1 then
        return false, "LAM-Panel ohne registrierte Einstellungen (0 Eintraege)"
    end
    return true, "'My UI': " .. tostring(count) .. " Menueeintraege registriert (" .. tostring(bridge.mode) .. ")"
end

function D.Report()
    local ok, summary = State()
    Print((ok and "OK: " or "PROBLEM: ") .. summary)
    Print("Technischer Add-on-Name: MyUI | Anzeigename: My UI")
    local bui = rawget(_G, "BUI")
    Print("BUI.name=" .. tostring(bui and bui.name) .. ", LibAddonMenu=" .. (FindLAM() and "geladen" or "FEHLT"))
    local console = type(IsKeyboardUISupported) == "function" and not IsKeyboardUISupported()
    Print("Plattform=" .. (console and "Konsole" or "PC/unklar") .. ", LibHarvensAddonSettings (LibVotans)=" .. (rawget(_G, "LibHarvensAddonSettings") and "geladen" or "FEHLT"))
    local init = bui and bui.Initialization
    if init then
        local order = {"saved variables", "root UI", "player UI", "combat UI", "action bars and frames", "menus and integrations"}
        for _, key in ipairs(order) do
            Print(key .. " = " .. tostring(init.stages and init.stages[key] or "nicht gestartet"))
        end
        if init.steps then
            local names = {"Menu.Init", "Menu.Initialize", "MiniMap", "Automation", "Panel", "CustomBar", "LAM.FinalizeGrouped", "RegisterEvents", "SlashCommands", "BUI_Ready"}
            for _, key in ipairs(names) do
                Print("  " .. key .. " = " .. tostring(init.steps[key] or "nicht gestartet"))
            end
        end
    end
    local bridge = bui and bui.SettingsBridge
    if bridge then
        local sectionCount = 0
        for _ in pairs((bridge.pendingSections and bridge.pendingSections[D.panelName]) or {}) do
            sectionCount = sectionCount + 1
        end
        Print("Bridge: mode=" .. tostring(bridge.mode) .. ", sections=" .. sectionCount
            .. ", finalized=" .. tostring(bridge.groupedFinalized and bridge.groupedFinalized[D.panelName])
            .. ", panel=" .. tostring(bridge.panels and bridge.panels[D.panelName] ~= nil)
            .. ", eintraege=" .. tostring(bridge.groupedOptionCount and bridge.groupedOptionCount[D.panelName] or 0))
    end
    for i = math.max(1, #D.messages - 10), #D.messages do
        Print(D.messages[i])
    end
    for i = 1, #D.errors do Print("LUA-FEHLER: " .. D.errors[i]) end
    return ok, summary
end

local function Overlay()
    if not rawget(_G, "WINDOW_MANAGER") or not rawget(_G, "GuiRoot") then return end
    if not rawget(_G, "CT_LABEL") then return end
    if not D.window then
        local window = WINDOW_MANAGER:CreateTopLevelWindow("MyUI_DebugWindow")
        window:SetDimensions(1040, 190)
        window:SetAnchor(TOP, GuiRoot, TOP, 0, 80)
        window:SetMouseEnabled(false)
        local label = WINDOW_MANAGER:CreateControl("MyUI_DebugText", window, CT_LABEL)
        label:SetAnchorFill(window)
        label:SetFont("$(MEDIUM_FONT)|23|soft-shadow-thick")
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        D.window = window
        D.label = label
    end
    local success, status = State()
    local bui = rawget(_G, "BUI")
    D.label:SetColor(success and 0.3 or 1, success and 1 or 0.65, 0.4, 1)
    D.label:SetText("MY UI DEBUG: " .. (success and "OK" or "FEHLER")
        .. "\n" .. status
        .. "\nAdd-on: " .. tostring(bui and bui.name or "BUI fehlt")
        .. " | LAM: " .. (FindLAM() and "geladen" or "FEHLT")
        .. "\n/chat: /myuidebug fuer Details")
    D.window:SetHidden(false)
    if type(zo_callLater) == "function" then
        D.overlaySequence = (D.overlaySequence or 0) + 1
        local seq = D.overlaySequence
        zo_callLater(function()
            if D.overlaySequence == seq and D.window then D.window:SetHidden(true) end
        end, 20000)
    end
end

function D.Show()
    D.Report()
    local success, err = pcall(Overlay)
    if not success then Print("Overlay-Fehler: " .. tostring(err)) end
end

D.Note("Start", "MyUI_Debug.lua geladen")
if rawget(_G, "SLASH_COMMANDS") then
    SLASH_COMMANDS["/myuidebug"] = function() D.Show() end
end

if rawget(_G, "EVENT_MANAGER") and rawget(_G, "EVENT_LUA_ERROR") then
    EVENT_MANAGER:RegisterForEvent("MyUI_DebugErrors", EVENT_LUA_ERROR, function(_, errorText)
        local msg = tostring(errorText or "")
        if string.find(msg, "MyUI", 1, true) or string.find(msg, "BUI_", 1, true) or string.find(msg, "LAM", 1, true) then
            if #D.errors < 6 then D.errors[#D.errors + 1] = string.sub(msg, 1, 320) end
        end
    end)
end

if rawget(_G, "EVENT_MANAGER") and rawget(_G, "EVENT_ADD_ON_LOADED") then
    EVENT_MANAGER:RegisterForEvent("MyUI_DebugLoaded", EVENT_ADD_ON_LOADED, function(_, addOnName)
        if addOnName ~= D.expectedName then return end
        D.loaded = true
        D.Note("EVENT_ADD_ON_LOADED", "MyUI empfangen")
        EVENT_MANAGER:UnregisterForEvent("MyUI_DebugLoaded", EVENT_ADD_ON_LOADED)
    end)
end

if rawget(_G, "EVENT_MANAGER") and rawget(_G, "EVENT_PLAYER_ACTIVATED") then
    EVENT_MANAGER:RegisterForEvent("MyUI_DebugActivated", EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent("MyUI_DebugActivated", EVENT_PLAYER_ACTIVATED)
        if type(zo_callLater) == "function" then
            zo_callLater(function() D.Show() end, 4500)
        else
            D.Show()
        end
    end)
end
