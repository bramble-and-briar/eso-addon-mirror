local A, S = PBS_HUD_MANAGER, PBS_HUD_MANAGER_STRINGS

-- ---------------------------------------------------------------------------------------
-- Hiding parts of the HUD while the player is in combat
--
-- The elements belong to other add-ons, or to the game, and both keep deciding for themselves
-- whether they are shown: the clock on every scene change, the Cyrodiil windows on every alert,
-- the game's chat and tracker column every time a fragment shows or hides. Hiding one once, on
-- entering combat, would be undone by the next of those. So instead of hiding, the control's
-- SetHidden is wrapped, on that one control, with a veto:
--
--   * the owner's request is always remembered (pbsWanted), whether or not it was carried out;
--   * while the veto is on, the control is hidden whatever was requested;
--   * when the veto goes, the control is put to what the owner last asked for -- which is not
--     necessarily what it was when combat began: an alert that expired in the meantime stays
--     hidden, a window the owner showed stays shown.
--
-- Nothing is wrapped until the option is on and a fight begins, so with it off the add-on does
-- not touch any of them. The minimap is the exception: it is not hidden by one control but by the
-- map fragment, which its own add-on already takes in and out of the HUD scenes, so that is what
-- is used for it (SetMinimapAttached).
--
-- A control that does not take the wrapper (the client ignores a method set on one control, or
-- has no SetHidden) falls back to being hidden when the fight begins and put back when it ends,
-- with nothing to stop its owner showing it in between. /pbhud combat says which ones.
-- ---------------------------------------------------------------------------------------

local TICK_MS = 1000
local SCENE_SETTLE_MS = 150

local function add(list, control)
    if control == nil then return end
    for _, known in ipairs(list) do
        if known == control then return end
    end
    list[#list + 1] = control
end

-- Each target is one option, and the controls it hides, looked up when they are needed: some of
-- them do not exist until their owner has first shown them.
A.combatTargets = {
    { key = "quest", controls = function()
        -- The whole tracker column, not the quest panel inside it: the game re-parents and
        -- re-anchors every tracker in it on each layout, which a single panel would not survive.
        local list = {}
        add(list, rawget(_G, "ZO_HUDTrackers"))
        if #list == 0 and type(FOCUSED_QUEST_TRACKER) == "table" then
            add(list, FOCUSED_QUEST_TRACKER.control or FOCUSED_QUEST_TRACKER.primaryControl)
        end
        return list
    end },
    { key = "chat", controls = function()
        local list = {}
        if type(GAMEPAD_CHAT_SYSTEM) == "table" then add(list, GAMEPAD_CHAT_SYSTEM.control) end
        if type(CHAT_SYSTEM) == "table" then add(list, CHAT_SYSTEM.control) end
        return list
    end },
    { key = "minimap", minimap = true },
    { key = "alert", controls = function()
        -- The alert text, the log window, the campaign summary and the overview map.
        local list, root = {}, rawget(_G, "PBS_CYRODIIL_ALERT")
        if type(root) == "table" then
            for _, name in ipairs({ "hud", "log", "board", "map" }) do
                local part = root[name]
                if type(part) == "table" then add(list, part.window) end
            end
        end
        return list
    end },
    { key = "clock", controls = function()
        local list, root = {}, rawget(_G, "PBS_CLOCK")
        if type(root) == "table" and type(root.cards) == "table" then
            for _, kind in ipairs({ "real", "game" }) do
                local card = root.cards[kind]
                if type(card) == "table" then add(list, card.root) end
            end
        end
        return list
    end },
    { key = "compass", controls = function()
        -- The frame and the compass inside it: hiding the frame alone would leave the bearing
        -- marks and the pins if the client keeps them in a control of their own. Whichever of
        -- the three names is the same control as another is only taken once.
        local list = {}
        add(list, rawget(_G, "ZO_CompassFrame"))
        add(list, rawget(_G, "ZO_Compass"))
        local frame = rawget(_G, "COMPASS_FRAME")
        if type(frame) == "table" then add(list, frame.control) end
        return list
    end },
}

A.fallback = setmetatable({}, { __mode = "k" })

-- Puts the veto on one control, if it is not on already. True if the control now answers to it.
function A:Guard(control)
    if control.pbsGuard then return true end
    if type(control.SetHidden) ~= "function" or type(control.IsHidden) ~= "function" then return false end
    local original = control.SetHidden
    local ok = pcall(function()
        control.pbsWanted = control:IsHidden()
        control.pbsVeto = false
        control.pbsCalls = 0
        control.SetHidden = function(self, hidden)
            self.pbsCalls = (self.pbsCalls or 0) + 1
            self.pbsWanted = hidden
            return original(self, hidden or self.pbsVeto)
        end
        -- A probe, with the value it has: if the wrapper is what runs, the count moves.
        control:SetHidden(control.pbsWanted)
    end)
    if ok and control.pbsCalls == 1 then
        control.pbsGuard = true
        return true
    end
    pcall(function() control.SetHidden = nil end)
    return false
end

function A:VetoControl(control, on)
    -- Something that is not a control, or not one this client lets us hide: nothing to do.
    if type(control.SetHidden) ~= "function" or type(control.IsHidden) ~= "function" then return end
    if on and not control.pbsGuard and not self.fallback[control] then
        if not self:Guard(control) then self.fallback[control] = { vetoed = false } end
    end
    if control.pbsGuard then
        control.pbsVeto = on
        -- Only when what is on screen is not what it should be: this runs once a second in combat.
        local shouldBeHidden = control.pbsWanted == true or on
        if control:IsHidden() ~= shouldBeHidden then control:SetHidden(control.pbsWanted) end
        return
    end
    local state = self.fallback[control]
    if not state then return end
    if on and not state.vetoed then
        state.previous, state.vetoed = control:IsHidden(), true
        control:SetHidden(true)
    elseif not on and state.vetoed then
        state.vetoed = false
        control:SetHidden(state.previous == true)
    end
end

-- The minimap is taken out of the HUD scenes and put back by its own add-on's call. It is put
-- back only if it was this that took it out, not when the add-on had already taken it out (the
-- full map was open) and not while the full map is in front, where the add-on does it itself
-- when the HUD comes back.
function A:VetoMinimap(on)
    local minimap = rawget(_G, "PBS_MINIMAP")
    if type(minimap) ~= "table" or type(minimap.SetMinimapAttached) ~= "function" then return end
    if on then
        if minimap.minimapAttached and pcall(minimap.SetMinimapAttached, minimap, false) then
            self.minimapParked = true
        end
    elseif self.minimapParked then
        self.minimapParked = false
        local inFront = type(minimap.IsWorldMapInFront) == "function" and minimap.IsWorldMapInFront()
        local wanted = type(minimap.account) == "table" and minimap.account.enableMap
        if wanted and not inFront and not minimap.dormant then
            pcall(minimap.SetMinimapAttached, minimap, true)
        end
    end
end

function A:CombatActive()
    return self.sv.combat.enabled == true and self.inCombat == true
end

-- Brings every target to what the option and the combat state say. Safe to call at any time and
-- as often as wanted: it is also the tick that finds windows created since, and the answer to the
-- minimap's add-on putting its map back when the full map is closed.
function A:ApplyCombat()
    local active = self:CombatActive()
    for _, target in ipairs(self.combatTargets) do
        local on = active and self.sv.combat[target.key] == true
        if target.minimap then
            self:VetoMinimap(on)
        else
            for _, control in ipairs(target.controls()) do
                -- Only guarded or fallback controls need telling when it goes off.
                if on or control.pbsGuard or self.fallback[control] then self:VetoControl(control, on) end
            end
        end
    end
    if active and not self.combatTicking then
        self.combatTicking = true
        EVENT_MANAGER:RegisterForUpdate(self.name .. "Combat", TICK_MS, function() self:ApplyCombat() end)
    elseif not active and self.combatTicking then
        self.combatTicking = false
        EVENT_MANAGER:UnregisterForUpdate(self.name .. "Combat")
    end
end

function A:SetCombatOption(key, value)
    if type(self.sv.combat[key]) ~= "boolean" then return false end
    self.sv.combat[key] = value == true
    self:ApplyCombat()
    return true
end

function A:ReadCombatState()
    self.inCombat = type(IsUnitInCombat) == "function" and IsUnitInCombat("player") == true or false
end

function A:InitCombat()
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        self.inCombat = inCombat == true
        self:ApplyCombat()
    end)
    -- Back on the HUD from a menu: the owners show their things again, in the middle of a fight if
    -- that is where we are. They do it in their own handlers, so this waits for them.
    for _, scene in ipairs({ HUD_SCENE, HUD_UI_SCENE }) do
        if scene then
            scene:RegisterCallback("StateChange", function(_, newState)
                if newState == SCENE_SHOWN and self:CombatActive() then
                    if zo_callLater then
                        zo_callLater(function() self:ApplyCombat() end, SCENE_SETTLE_MS)
                    else
                        self:ApplyCombat()
                    end
                end
            end)
        end
    end
end

-- What the option is doing, for the command.
function A:CombatLines()
    local function word(flag) return flag and S.stateOn or S.stateOff end
    local combat = self.sv.combat
    local lines = {
        self:Format(S.combatStatus, { state = word(combat.enabled), now = word(self.inCombat == true) }),
    }
    for _, target in ipairs(self.combatTargets) do
        local line = self:Format(S.combatLine, { name = S["combat_" .. target.key], state = word(combat[target.key]) })
        local unhooked = false
        if target.controls then
            for _, control in ipairs(target.controls()) do
                if self.fallback[control] then unhooked = true end
            end
        end
        if unhooked then line = line .. "  " .. S.combatNoHook end
        lines[#lines + 1] = line
    end
    return lines
end

-- /pbhud combat [on | off | <target> on | off]
function A:CombatCommand(rest)
    local first, second = rest:match("^(%S*)%s*(%S*)")
    local function flag(word)
        if word == "on" then return true end
        if word == "off" then return false end
        return nil
    end
    if first == "" then
        -- just the status
    elseif flag(first) ~= nil then
        self:SetCombatOption("enabled", flag(first))
    else
        local known = false
        for _, target in ipairs(self.combatTargets) do
            if target.key == first then known = true end
        end
        if not known or flag(second) == nil then return false end
        self:SetCombatOption(first, flag(second))
    end
    return true
end
