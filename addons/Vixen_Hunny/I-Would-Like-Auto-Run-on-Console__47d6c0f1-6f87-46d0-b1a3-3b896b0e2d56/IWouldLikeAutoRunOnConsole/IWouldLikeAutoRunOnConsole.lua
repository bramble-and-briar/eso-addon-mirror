-- I Would Like Auto Run On Console
-- Gives the game's built-in Auto Run action a controller binding.
--
-- Why a binding and not a button handled by this addon: ToggleAutoRun() is
-- private, so addon code can never call it. The built-in AUTORUN keybind
-- action can call it though, and addons are allowed to bind keys to actions
-- while out of combat. So this addon binds a controller combo to that action
-- and the game does the rest. It is the same action PC uses, so it behaves
-- the same: it is a toggle, and moving forward or backward cancels it.

local ADDON = "IWouldLikeAutoRunOnConsole"
local ACTION = "AUTORUN"
local AUTO, OFF = "AUTO", "OFF"
local em = EVENT_MANAGER

-- In order of preference for the automatic pick. Combos come first because
-- binding the "hold" version of a button changes how its tap behaves.
local BUTTONS = {
    { id = "LB_L3",     key = KEY_GAMEPAD_BOTH_LEFT_SHOULDER_LEFT_STICK,  label = "LB / L1 + click left stick" },
    { id = "L3_R3",     key = KEY_GAMEPAD_BOTH_STICKS,                    label = "Click both sticks" },
    { id = "LB_R3",     key = KEY_GAMEPAD_BOTH_LEFT_SHOULDER_RIGHT_STICK, label = "LB / L1 + click right stick" },
    { id = "LB_DLEFT",  key = KEY_GAMEPAD_BOTH_LEFT_SHOULDER_DPAD_LEFT,   label = "LB / L1 + d-pad left" },
    { id = "DDOWN_HOLD",  key = KEY_GAMEPAD_DPAD_DOWN_HOLD,  label = "Hold d-pad down" },
    { id = "DLEFT_HOLD",  key = KEY_GAMEPAD_DPAD_LEFT_HOLD,  label = "Hold d-pad left" },
    { id = "DRIGHT_HOLD", key = KEY_GAMEPAD_DPAD_RIGHT_HOLD, label = "Hold d-pad right" },
    { id = "DUP_HOLD",    key = KEY_GAMEPAD_DPAD_UP_HOLD,    label = "Hold d-pad up" },
    { id = "BACK_HOLD",   key = KEY_GAMEPAD_BACK_HOLD,       label = "Hold View / Touchpad button" },
}

local defaults = {
    choice = AUTO, -- AUTO, OFF, or a BUTTONS id
    boundKey = nil, -- key code this addon bound, so it only ever removes its own binding
}

local sv
local layerIndex, categoryIndex, actionIndex
local pendingApply = false -- a change is waiting for combat to end

local function Print(text, ...)
    CHAT_ROUTER:AddSystemMessage("|c66ccff[AutoRun]|r " .. string.format(text, ...))
end

local function ButtonById(id)
    for _, button in ipairs(BUTTONS) do
        if button.id == id and button.key then return button end
    end
end

local function KeyLabel(key)
    for _, button in ipairs(BUTTONS) do
        if button.key == key then return button.label end
    end
    return GetKeyName(key)
end

---------------------------------------------------------------------------
-- Reading the current bindings
---------------------------------------------------------------------------
local function SlotKey(slot)
    return (GetActionBindingInfo(layerIndex, categoryIndex, actionIndex, slot))
end

-- Slot on the Auto Run action holding this key, if any.
local function SlotOfKey(key)
    for slot = 1, GetMaxBindingsPerAction() do
        if SlotKey(slot) == key then return slot end
    end
end

local function EmptySlot()
    for slot = 1, GetMaxBindingsPerAction() do
        if SlotKey(slot) == KEY_INVALID then return slot end
    end
end

-- Any controller binding on Auto Run, whoever made it.
local function CurrentGamepadKey()
    for slot = 1, GetMaxBindingsPerAction() do
        local key = SlotKey(slot)
        if key ~= KEY_INVALID and IsKeyCodeGamepadKey(key) then return key end
    end
end

-- Name of the other action using this key in the same layer, or nil if free.
local function KeyOwner(key)
    local cat, act = GetBindingIndicesFromKeys(layerIndex, key, KEY_INVALID, KEY_INVALID, KEY_INVALID, KEY_INVALID)
    if not cat or not act then return nil end
    if cat == categoryIndex and act == actionIndex then return nil end
    local name = GetActionInfo(layerIndex, cat, act)
    local localized = name and GetString(_G["SI_BINDING_NAME_" .. name]) or ""
    return localized ~= "" and localized or name or "another action"
end

---------------------------------------------------------------------------
-- Changing bindings (protected calls: only work out of combat)
---------------------------------------------------------------------------
local function Unbind(slot)
    return CallSecureProtected("UnbindKeyFromAction", layerIndex, categoryIndex, actionIndex, slot)
end

local function Bind(slot, key)
    return CallSecureProtected("BindKeyToAction", layerIndex, categoryIndex, actionIndex, slot,
        key, KEY_INVALID, KEY_INVALID, KEY_INVALID, KEY_INVALID)
end

local function RemoveOwnBinding()
    if not sv.boundKey then return end
    local slot = SlotOfKey(sv.boundKey)
    if slot then Unbind(slot) end
    sv.boundKey = nil
end

-- verbose: also report when nothing needed to change (used for user-driven calls).
local function Apply(verbose)
    if not layerIndex then
        layerIndex, categoryIndex, actionIndex = GetActionIndicesFromName(ACTION)
        if not layerIndex then
            if verbose then Print("the game's Auto Run action was not found, nothing to bind.") end
            return
        end
    end

    if IsUnitInCombat("player") then
        pendingApply = true
        if verbose then Print("bindings cannot change in combat, will apply when combat ends.") end
        return
    end
    pendingApply = false

    if sv.choice == OFF then
        local had = sv.boundKey ~= nil
        RemoveOwnBinding()
        if verbose or had then Print("off - the addon is not binding Auto Run.") end
        return
    end

    local wanted
    if sv.choice == AUTO then
        local existing = CurrentGamepadKey()
        if existing then
            if verbose then Print("Auto Run is on: %s", KeyLabel(existing)) end
            return
        end
        for _, button in ipairs(BUTTONS) do
            if button.key and not KeyOwner(button.key) then
                wanted = button
                break
            end
        end
        if not wanted then
            Print("every button combo this addon knows is already in use. Pick one with /autorun.")
            return
        end
    else
        wanted = ButtonById(sv.choice)
        if not wanted then
            sv.choice = AUTO
            return Apply(verbose)
        end
        if SlotOfKey(wanted.key) then
            sv.boundKey = wanted.key
            if verbose then Print("Auto Run is on: %s", wanted.label) end
            return
        end
        local owner = KeyOwner(wanted.key)
        if owner then
            Print("%s is already used by \"%s\". Pick another, or free it in Settings > Controls first.", wanted.label, owner)
            return
        end
    end

    RemoveOwnBinding()

    local slot = EmptySlot()
    if not slot then
        Print("Auto Run has no free binding slot. Clear one in Settings > Controls > Movement.")
        return
    end
    if GetNumSavedKeybindings() >= GetMaxNumSavedKeybindings() then
        Print("the game's limit of custom bindings is reached, cannot add Auto Run.")
        return
    end

    Bind(slot, wanted.key)
    if SlotKey(slot) == wanted.key then
        sv.boundKey = wanted.key
        Print("Auto Run is now on: %s. Press it again or move to stop.", wanted.label)
    else
        Print("the game refused to bind %s. Try another with /autorun.", wanted.label)
    end
end

local function SetChoice(choice)
    sv.choice = choice
    Apply(true)
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
local settingsPanel

local function StatusText()
    if not layerIndex then return "Not loaded yet." end
    local key = CurrentGamepadKey()
    if key then return "Auto Run is on: " .. KeyLabel(key) end
    if pendingApply then return "Waiting for combat to end." end
    return "Auto Run has no controller button."
end

local function CreateSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelName = ADDON .. "_Settings"
    settingsPanel = LAM:RegisterAddonPanel(panelName, {
        slashCommand = "/autorunsettings",
        type = "panel",
        name = "Auto Run On Console",
        displayName = "I Would Like Auto Run On Console",
        author = "Vixen Hunny",
        version = "1.0.0",
        registerForRefresh = true,
        registerForDefaults = true,
    })

    local choices, choicesValues = { "Automatic (first free combo)", "Off" }, { AUTO, OFF }
    for _, button in ipairs(BUTTONS) do
        if button.key then
            choices[#choices + 1] = button.label
            choicesValues[#choicesValues + 1] = button.id
        end
    end

    LAM:RegisterOptionControls(panelName, {
        {
            type = "description",
            text = "Binds the game's own Auto Run to a controller combo. Press it once to start running, "
                .. "press it again or move the stick forward or back to stop. "
                .. "Changes made in combat apply when combat ends.",
        },
        {
            type = "dropdown",
            name = "Auto Run button",
            tooltip = "Automatic keeps any Auto Run controller binding you already have, otherwise takes the first unused combo.",
            choices = choices,
            choicesValues = choicesValues,
            getFunc = function() return sv.choice end,
            setFunc = SetChoice,
            default = defaults.choice,
        },
        {
            type = "description",
            title = "Current binding",
            text = StatusText,
        },
        {
            type = "button",
            name = "Apply again",
            tooltip = "Re-check the binding, for example after changing controls in the game's own settings.",
            func = function() Apply(true) end,
            width = "half",
        },
    })
end

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------
local function OnSlash(args)
    local cmd = zo_strlower(args or ""):match("^%s*(%S*)")
    local index = tonumber(cmd)
    if cmd == "auto" then
        SetChoice(AUTO)
    elseif cmd == "off" then
        SetChoice(OFF)
    elseif index and BUTTONS[index] and BUTTONS[index].key then
        SetChoice(BUTTONS[index].id)
    elseif cmd == "settings" then
        if settingsPanel then
            LibAddonMenu2:OpenToPanel(settingsPanel)
        else
            Print("the settings panel needs LibAddonMenu-2.0")
        end
    else
        Apply(true)
        Print("/autorun auto | off | settings | <number>")
        for i, button in ipairs(BUTTONS) do
            if button.key then Print("  %d - %s", i, button.label) end
        end
    end
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
local function Initialize()
    sv = ZO_SavedVars:NewAccountWide("IWouldLikeAutoRunOnConsoleSV", 1, nil, defaults)

    local function ApplyQuietly() Apply(false) end
    em:RegisterForEvent(ADDON, EVENT_PLAYER_ACTIVATED, ApplyQuietly)
    em:RegisterForEvent(ADDON, EVENT_KEYBINDINGS_LOADED, ApplyQuietly)
    em:RegisterForEvent(ADDON, EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        if pendingApply and not inCombat then Apply(true) end
    end)

    CreateSettings()
    SLASH_COMMANDS["/autorun"] = OnSlash
end

em:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= ADDON then return end
    em:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)
    Initialize()
end)
