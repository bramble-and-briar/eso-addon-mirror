-- Uses ESO's quest-cycle action, normally D-pad quest-cycle button in gamepad mode.
-- Does not change the player's saved key bindings.
local NAME = "WWDpad"
local VERSION = "0.6.1"
local RADIAL_ID = "wwdpad"
local settings
local hooked = false
local capturedPress = false
local lastSwap = -100000
local SWAP_COOLDOWN_MS = 800
local SWAP_TIMEOUT_MS = 45000
local swapPending = false
local swapUncertain = false
local swapGeneration = 0
local completionSignalReady = false
local pendingPlan
local queuedPlan
local drainScheduled = false
local DrainDeferred
local actionFragments = {}
local activeFragments = {}
local customPress = {}
local RefreshSettings
local HOTKEYS = {
    { id = "quest", name = "Aufgabenwechsel (Steuerkreuz rechts)" },
    { id = "map", name = "Karte (PlayStation: Touchpad)", layer = "WWDpadMap" },
    { id = "sheathe", name = "Waffe ziehen / wegstecken", layer = "WWDpadSheathe" },
}

local function HotkeyName()
    for _, option in ipairs(HOTKEYS) do
        if option.id == settings.hotkey then return option.name end
    end
    return HOTKEYS[1].name
end

local function Say(message)
    d("[WW D-Pad " .. VERSION .. "] " .. message)
end

local function ShouldHandle()
    return settings and settings.enabled
        and IsInGamepadPreferredMode()
        and HUD_SCENE and HUD_SCENE.state == "shown"
end

local function NextSetup(directMode, suppliedPlan, automatic)
    local now = GetFrameTimeMilliseconds()
    -- Ignore extra presses. Never queue them, and never unlock only because
    -- enough time passed while WW is still changing gear/skills/CP.
    if not settings.enabled or swapUncertain or swapPending then return false end
    local inCombat = IsUnitInCombat("player")
    if not inCombat and now - lastSwap < SWAP_COOLDOWN_MS then return false end
    if automatic and (inCombat or queuedPlan) then return false end
    if inCombat and queuedPlan then return false end
    if not inCombat and queuedPlan and not suppliedPlan then DrainDeferred(); return false end
    if IsUnitDeadOrReincarnating("player") then return end

    local ww = WizardsWardrobe
    if not ww or type(ww.LoadSetup) ~= "function" then
        Say("Wizard's Wardrobe ist nicht bereit.")
        return
    end
    if not completionSignalReady then
        Say("WW-Abschlussmeldung nicht verfuegbar; Hotkey-Wechsel bleibt gesperrt.")
        return
    end
    -- Adjacent loading requires a selected WW page and its current index.
    if not ww.selection or not ww.selection.zone or not ww.selection.pageId
        or type(ww.currentIndex) ~= "number" then
        Say("Zuerst in Wizard's Wardrobe eine Seite und ein Setup auswaehlen.")
        return
    end
    local submitted = false
    local ok, message = pcall(function()
        local plan = suppliedPlan or WWDpadRouting.Plan(directMode)
        if not plan then return end
        if inCombat then
            if not queuedPlan then
                plan.adjacent = false -- freeze the exact next index at button press
                queuedPlan = plan
                WWDpadAuto.ManualOverride()
                Say("Ein Setupwechsel ist fuer nach dem Kampf vorgemerkt.")
            end
            return
        end
        pendingPlan = plan
        if not automatic then WWDpadAuto.ManualOverride() end
        swapPending = true
        swapGeneration = swapGeneration + 1
        local generation = swapGeneration
        lastSwap = now
        zo_callLater(function()
            if not swapPending or swapGeneration ~= generation then return end
            -- Fail closed: an elapsed timer is not proof that WW finished.
            swapUncertain = true
            settings.enabled = false
            RefreshSettings()
            Say("Kein bestaetigter WW-Abschluss nach 45 Sekunden. Hotkey deaktiviert. WW pruefen und /reloadui ausfuehren.")
        end, SWAP_TIMEOUT_MS)
        submitted = true
        local accepted
        if plan.adjacent then
            accepted = ww.LoadSetupAdjacent(1)
        else
            accepted = ww.LoadSetup(plan.zone, plan.pageId, plan.index, false)
        end
        if accepted == false and swapPending then
            swapPending = false
            pendingPlan = nil
            swapGeneration = swapGeneration + 1
            Say("WW hat den Wechsel nicht angenommen.")
        end
    end)
    if not ok then
        if not submitted then
            swapPending = false
            swapGeneration = swapGeneration + 1
            pendingPlan = nil
            Say("Setup-Erkennung fehlgeschlagen (kein Wechsel gestartet): " .. tostring(message))
            return
        end
        swapUncertain = true
        settings.enabled = false
        RefreshSettings()
        Say("WW-Wechsel fehlgeschlagen; Hotkey deaktiviert: " .. tostring(message))
    end
    return ok and submitted
end

DrainDeferred = function()
    if not settings.enabled or swapUncertain then queuedPlan = nil; return end
    if IsUnitInCombat("player") or swapPending then return end
    if IsUnitDeadOrReincarnating("player") then queuedPlan = nil; return end
    -- Do not switch over menus; resume when the HUD is shown again.
    if not ShouldHandle() then return end
    local remaining = SWAP_COOLDOWN_MS - (GetFrameTimeMilliseconds() - lastSwap)
    if remaining > 0 then
        if not drainScheduled then
            drainScheduled = true
            zo_callLater(function() drainScheduled = false; DrainDeferred() end, remaining + 1)
        end
        return
    end
    if queuedPlan then
        local plan = queuedPlan
        queuedPlan = nil
        if not WWDpadRouting.IsCurrent(plan) then
            Say("Vorgemerkter Wechsel verworfen: WW-Seite oder Setup wurde geaendert.")
            return
        end
        NextSetup(false, plan, false)
    else
        WWDpadAuto.Schedule()
    end
end

local function UpdateInputLayer()
    local desired = {}
    if settings.enabled and IsInGamepadPreferredMode() then
        for _, option in ipairs(HOTKEYS) do
            if (option.id == settings.hotkey or option.id == settings.secondHotkey) and option.layer then
                if not actionFragments[option.id] then
                    actionFragments[option.id] = ZO_ActionLayerFragment:New(option.layer)
                end
                desired[option.id] = actionFragments[option.id]
            end
        end
    end
    for id, fragment in pairs(activeFragments) do
        if not desired[id] then HUD_SCENE:RemoveFragment(fragment); customPress[id] = nil end
    end
    for id, fragment in pairs(desired) do
        if not activeFragments[id] then HUD_SCENE:AddFragment(fragment) end
    end
    activeFragments = desired
end

-- Each alternative layer contains only its selected inherited ESO action.
-- ESO activates/removes that layer together with the HUD scene.
WWDpadInput = {}
function WWDpadInput.Down(hotkey)
    if customPress[hotkey] or not ShouldHandle()
        or (settings.hotkey ~= hotkey and settings.secondHotkey ~= hotkey) then return end
    customPress[hotkey] = true
    NextSetup(settings.secondHotkey == hotkey)
end
function WWDpadInput.Up(hotkey)
    if hotkey then customPress[hotkey] = nil else customPress = {} end
end

local function SetEnabled(value)
    settings.enabled = value == true
    if not settings.enabled then queuedPlan = nil end
    RefreshSettings()
end

local function SetAutoBoss(value)
    settings.autoBossEnabled = value == true
    RefreshSettings()
end

local function SetAutoMode(value)
    if value ~= "matched" and value ~= "target" then return end
    settings.autoBossMode = value
    WWDpadAuto.Schedule()
end

local function SetHotkey(value)
    for _, option in ipairs(HOTKEYS) do
        if option.id == value then
            if value == settings.secondHotkey then
                settings.secondHotkey = settings.hotkey
            end
            settings.hotkey = value
            RefreshSettings()
            return
        end
    end
end

local function SetSecondHotkey(value)
    if value == settings.hotkey then
        if settings.secondHotkey == "none" then
            Say("Bitte zuerst einen anderen ersten Hotkey waehlen."); return
        end
        settings.hotkey = settings.secondHotkey
    end
    if value ~= "none" then
        local valid = false
        for _, option in ipairs(HOTKEYS) do if option.id == value then valid = true end end
        if not valid then return end
    end
    settings.secondHotkey = value
    RefreshSettings()
end

local function RegisterRadialEntries()
    LibRadialMenu:RegisterEntry(RADIAL_ID,
        settings.enabled and "WW-Hotkey: AN (umschalten)" or "WW-Hotkey: AUS (umschalten)",
        "toggle", "/esoui/art/addons/gamepad/gp_addons_manage.dds", function()
            SetEnabled(not settings.enabled)
            Say(settings.enabled and ("AN: " .. HotkeyName()) or "AUS: normale Tastenfunktion wieder aktiv.")
        end,
        "Schaltet den in den Einstellungen gewaehlten WW-Hotkey ein oder aus. Menues bleiben unveraendert.")
    LibRadialMenu:RegisterEntry(RADIAL_ID,
        settings.autoBossEnabled and "Bossautomatik: AN (umschalten)" or "Bossautomatik: AUS (umschalten)",
        "autoToggle", "/esoui/art/addons/gamepad/gp_addons_manage.dds", function()
            SetAutoBoss(not settings.autoBossEnabled)
            Say(settings.autoBossEnabled and "Bossautomatik AN." or "Bossautomatik AUS.")
        end, "Schaltet nur die automatische Boss-/Raumerkennung ein oder aus. Die manuellen Hotkeys bleiben verfuegbar.")
end

RefreshSettings = function()
    if not settings.enabled then queuedPlan = nil end
    UpdateInputLayer()
    RegisterRadialEntries()
    WWDpadAuto.Schedule()
end

local function RegisterSettings()
    local explanation = "Hotkey 1 schaltet weiter; Hotkey 2 lädt den eingetragenen Setupnamen. Ein Tastendruck im Kampf merkt genau einen Wechsel bis Kampfende vor. Die separat zuschaltbare Automatik erkennt Bossbereiche wie WW auch vor dem Boss. Nach dem WW-Abschluss gilt 800 ms Pause."
    local lam = LibAddonMenu2
    if not ZO_IsConsoleOrGameCoreUI() and lam then
        lam:RegisterAddonPanel(NAME .. "Settings", {
            type = "panel", name = "WW D-Pad", displayName = "WW D-Pad",
            author = "FiNk3--F13--", version = VERSION, registerForRefresh = true,
            registerForDefaults = true,
        })
        local labels, values = {}, {}
        for i, option in ipairs(HOTKEYS) do labels[i], values[i] = option.name, option.id end
        local secondLabels, secondValues = {"Nicht belegt"}, {"none"}
        for _, option in ipairs(HOTKEYS) do
            secondLabels[#secondLabels + 1], secondValues[#secondValues + 1] = option.name, option.id
        end
        lam:RegisterOptionControls(NAME .. "Settings", {
            { type = "description", text = explanation },
            { type = "checkbox", name = "Hotkeys aktivieren", default = true,
              getFunc = function() return settings.enabled end, setFunc = SetEnabled },
            { type = "dropdown", name = "Hotkey 1: normale Reihenfolge", choices = labels, choicesValues = values,
              default = "quest", getFunc = function() return settings.hotkey end, setFunc = SetHotkey },
            { type = "dropdown", name = "Hotkey 2: direktes Setup", choices = secondLabels, choicesValues = secondValues,
              default = "none", getFunc = function() return settings.secondHotkey end, setFunc = SetSecondHotkey },
            { type = "description", text = "Beispiel: Setup 3 → Hotkey 2: Miniboss → Hotkey 1: Setup 4. Den Namen wie in WW eingeben. Bei leerem, fehlendem oder mehrdeutigem Namen erfolgt kein Wechsel. WWs eigene Automatik weiterhin ausgeschaltet lassen." },
            { type = "editbox", name = "Setupname für Hotkey 2", getFunc = WWDpadRouting.GetTargetName,
              setFunc = WWDpadRouting.SetTargetName, isMultiline = false, width = "full" },
            { type = "button", name = "Namen des aktuell geladenen WW-Setups übernehmen", func = WWDpadRouting.UseLoadedName, width = "full" },
            { type = "checkbox", name = "Automatische Bosserkennung", default = false,
              getFunc = function() return settings.autoBossEnabled end, setFunc = SetAutoBoss },
            { type = "dropdown", name = "Bei erkanntem Boss laden",
              choices = {"Passendes WW-Setup nach Name/Bossbedingung", "Immer Setup von Hotkey 2"},
              choicesValues = {"matched", "target"}, default = "matched",
              getFunc = function() return settings.autoBossMode end, setFunc = SetAutoMode },
            { type = "description", text = "Automatik AUS lässt Prebuff-Setups unverändert. AN nutzt WWs Raumabfrage und Bossmeldungen, außerhalb des Kampfes. Im Modus nach Name zählt auch ein exakt zugeordnetes anvisiertes Ziel. Unbekannte Bereiche führen zu keinem Wechsel. WWs eigene Automatik ausgeschaltet lassen." },
        })
    elseif LibHarvensAddonSettings then
        local lib = LibHarvensAddonSettings
        local panel = lib:AddAddon("WW D-Pad", {allowDefaults = true})
        local items = {}
        for i, option in ipairs(HOTKEYS) do items[i] = { name = option.name, data = option.id } end
        local secondItems = {{name = "Nicht belegt", data = "none"}}
        for _, option in ipairs(HOTKEYS) do secondItems[#secondItems + 1] = {name = option.name, data = option.id} end
        panel:AddSettings({
            { type = lib.ST_LABEL, label = explanation },
            { type = lib.ST_CHECKBOX, label = "Hotkeys aktivieren", default = true,
              getFunction = function() return settings.enabled end, setFunction = SetEnabled },
            { type = lib.ST_DROPDOWN, label = "Hotkey 1: normale Reihenfolge", items = items, default = HOTKEYS[1].name,
              getFunction = HotkeyName,
              setFunction = function(_, itemName, itemData)
                  if itemData then SetHotkey(itemData.data) end
              end },
            { type = lib.ST_DROPDOWN, label = "Hotkey 2: direktes Setup", items = secondItems, default = "Nicht belegt",
              getFunction = function()
                  for _, item in ipairs(secondItems) do if item.data == settings.secondHotkey then return item.name end end
                  return "Nicht belegt"
              end,
              setFunction = function(_, _, itemData) if itemData then SetSecondHotkey(itemData.data) end end },
            { type = lib.ST_LABEL, label = "Hotkey 2 lädt den eingetragenen Setupnamen. Hotkey 1 setzt danach an der gemerkten Position fort. WWs Automatik ausgeschaltet lassen." },
            { type = lib.ST_EDIT, label = "Setupname für Hotkey 2", getFunction = WWDpadRouting.GetTargetName,
              setFunction = WWDpadRouting.SetTargetName, maxChars = 120, ignoreDefault = true },
            { type = lib.ST_BUTTON, label = "Geladenen WW-Setupnamen übernehmen", clickHandler = WWDpadRouting.UseLoadedName },
            { type = lib.ST_CHECKBOX, label = "Automatische Bosserkennung", default = false,
              getFunction = function() return settings.autoBossEnabled end, setFunction = SetAutoBoss },
            { type = lib.ST_DROPDOWN, label = "Bei erkanntem Boss laden",
              items = {{name = "Passendes WW-Setup", data = "matched"}, {name = "Setup von Hotkey 2", data = "target"}},
              default = "Passendes WW-Setup",
              getFunction = function() return settings.autoBossMode == "target" and "Setup von Hotkey 2" or "Passendes WW-Setup" end,
              setFunction = function(_, _, item) if item then SetAutoMode(item.data) end end },
        })
    end
end

local function InstallHooks()
    if hooked then return end
    local ww = WizardsWardrobe
    if not completionSignalReady and ww and ww.callbackManager
        and type(ww.callbackManager.RegisterCallback) == "function" then
        ww.callbackManager:RegisterCallback("WW_OnSetupSwapSuccess", function()
            if not swapPending or swapUncertain then return end
            WWDpadRouting.Commit(pendingPlan)
            pendingPlan = nil
            swapPending = false
            swapGeneration = swapGeneration + 1
            lastSwap = GetFrameTimeMilliseconds()
            DrainDeferred()
        end)
        completionSignalReady = true
    end
    local installed = false
    -- Older ESO versions and the short quest-cycle path in newer versions.
    if FOCUSED_QUEST_TRACKER and type(FOCUSED_QUEST_TRACKER.AssistNext) == "function" then
        ZO_PreHook(FOCUSED_QUEST_TRACKER, "AssistNext", function()
            if not ShouldHandle() or (settings.hotkey ~= "quest" and settings.secondHotkey ~= "quest") then return end
            NextSetup(settings.secondHotkey == "quest")
            return true
        end)
        installed = true
    end
    -- New HUD tracker: intercept the input methods, not CycleAssistedAspiration,
    -- which ESO also calls internally without a player's button press.
    local tracker = HUD_TRACKER_MANAGER
    if tracker and type(tracker.BeginAssistInteract) == "function"
        and type(tracker.EndAssistInteract) == "function" then
        ZO_PreHook(tracker, "BeginAssistInteract", function()
            if capturedPress then return true end
            if not ShouldHandle() or (settings.hotkey ~= "quest" and settings.secondHotkey ~= "quest") then return end
            capturedPress = true
            NextSetup(settings.secondHotkey == "quest")
            return true
        end)
        ZO_PreHook(tracker, "EndAssistInteract", function()
            if not capturedPress then return end
            capturedPress = false
            return true
        end)
        installed = true
    end
    hooked = installed
    if not installed then
        Say("Kein unterstuetzter Aufgaben-Tracker gefunden; Abkuerzung nicht aktiv.")
    end
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= NAME then return end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    settings = ZO_SavedVars:NewAccountWide("WWDpadSV", 1, nil, { enabled = true, hotkey = "quest", targetSetupName = "", autoBossEnabled = false, autoBossMode = "matched" })
    settings.autoBossEnabled = settings.autoBossEnabled == true
    if settings.autoBossMode ~= "target" then settings.autoBossMode = "matched" end
    -- Preserve the chosen second button from the earlier recognition version.
    if settings.secondHotkey == nil then settings.secondHotkey = settings.bossHotkey or "none" end
    local validHotkey = false
    for _, option in ipairs(HOTKEYS) do
        if option.id == settings.hotkey then validHotkey = true end
    end
    if not validHotkey then settings.hotkey = "quest" end
    local validSecondHotkey = settings.secondHotkey == "none"
    for _, option in ipairs(HOTKEYS) do if settings.secondHotkey == option.id then validSecondHotkey = true end end
    if not validSecondHotkey or settings.secondHotkey == settings.hotkey then settings.secondHotkey = "none" end
    WWDpadRouting.Initialize(settings, Say)
    WWDpadAuto.Initialize(settings, function(plan) return NextSetup(false, plan, true) end)
    LibRadialMenu:RegisterAddon(RADIAL_ID, "WW D-Pad")
    RegisterRadialEntries()
    RegisterSettings()
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, UpdateInputLayer)
    HUD_SCENE:RegisterCallback("StateChange", function(_, newState)
        if newState ~= "shown" then customPress = {} end
        if newState == "shown" then DrainDeferred() end
    end)
    -- Optional PC/PTS testing shortcut; the console uses the radial toggle.
    SLASH_COMMANDS["/wwdpad"] = function()
        SetEnabled(not settings.enabled)
        Say(settings.enabled and ("AN: " .. HotkeyName()) or "AUS: normale Tastenfunktion wieder aktiv.")
    end
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, function()
        queuedPlan = nil -- never replay a combat request after a loading screen
        InstallHooks()
        UpdateInputLayer()
        WWDpadAuto.Schedule()
    end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        if not inCombat then DrainDeferred() end
    end)
    if EVENT_PLAYER_DEAD then EVENT_MANAGER:RegisterForEvent(NAME .. "Death", EVENT_PLAYER_DEAD, function() queuedPlan = nil end) end
end)
