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
-- How long after the HUD is back the other add-ons' windows are looked at, and how often at most.
local SCAN_SETTLE_MS = 500
local SCAN_INTERVAL_MS = 30000
local SCAN_AFTER_LOGIN_MS = 4000
A.maxParts = 20
local MAX_LISTED = 60

local function add(list, control)
    if control == nil then return end
    for _, known in ipairs(list) do
        if known == control then return end
    end
    list[#list + 1] = control
end

-- The chat systems there are: the gamepad one, and whichever CHAT_SYSTEM is (the same object on
-- console).
function A:ChatSystems()
    local list = {}
    if type(GAMEPAD_CHAT_SYSTEM) == "table" then add(list, GAMEPAD_CHAT_SYSTEM) end
    if type(CHAT_SYSTEM) == "table" then add(list, CHAT_SYSTEM) end
    return list
end

-- A text entry that says it is open and does not have the focus is the stuck state the game's
-- own source describes. The game closes it with CloseTextEntry, as it does when the chat mode
-- changes, and so does this, once, when the chat is let go of. Left alone when the on-screen
-- keyboard is up, where the edit box need not report a focus of its own.
function A:ResyncChat()
    if type(IsVirtualKeyboardOnScreen) == "function" and IsVirtualKeyboardOnScreen() then return end
    for _, system in ipairs(self:ChatSystems()) do
        local entry = system.textEntry
        if type(entry) == "table" and entry.open == true and type(system.CloseTextEntry) == "function"
            and type(entry.GetEditControl) == "function" then
            local ok, edit = pcall(entry.GetEditControl, entry)
            if ok and edit and type(edit.HasFocus) == "function" and not edit:HasFocus() then
                pcall(system.CloseTextEntry, system, true)
            end
        end
    end
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
        -- The parts of the chat that can be seen -- the messages, the background, the new-message
        -- mark -- and NOT the chat's own top-level control, nor its text entry.
        --
        -- The game's chat says in its own source that a text entry started while the chat window
        -- is hidden cannot take focus and is left stuck open, after which it will not open again
        -- until something closes it. Hiding the whole chat for a fight does exactly that to a
        -- player who presses the chat button in it, and the fight's end does not undo it. It also
        -- stops the chat's own timer, which runs on that control's OnUpdate. With the top-level
        -- control left alone both go on working, and the text entry, which fades in only when it
        -- is used, is left to the game.
        local list = {}
        for _, system in ipairs(A:ChatSystems()) do
            local before = #list
            if type(system.containers) == "table" then
                for _, container in ipairs(system.containers) do
                    if type(container) == "table" then add(list, container.windowContainer) end
                end
            end
            if #list == before and type(system.primaryContainer) == "table" then
                add(list, system.primaryContainer.windowContainer)
            end
            local control = system.control
            if control and type(control.GetNamedChild) == "function" then
                local ok, background = pcall(control.GetNamedChild, control, "Bg")
                if ok then add(list, background) end
            end
            add(list, system.chatBubble)
            -- A chat that shows none of those: better the whole control than nothing.
            if #list == before then add(list, control) end
        end
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
    { key = "extra", controls = function()
        -- The parts of other add-ons that the player chose from the list, by name.
        local list = {}
        for _, name in ipairs(A.sv.hudParts) do add(list, A:ControlByName(name)) end
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
    -- A control can belong to more than one target (a part the player chose that is also the clock's):
    -- it is hidden if any of them says so, decided once, so two targets never take it back and forth.
    local order, wanted, known = {}, {}, {}
    for _, target in ipairs(self.combatTargets) do
        local on = active and self.sv.combat[target.key] == true
        if target.key == "chat" then
            local wasOn = self.chatHidden == true
            self.chatHidden = on
            if wasOn and not on then self.resyncChatAfter = true end
        end
        if target.minimap then
            self:VetoMinimap(on)
        else
            for _, control in ipairs(target.controls()) do
                if not known[control] then
                    known[control] = true
                    order[#order + 1] = control
                end
                if on then wanted[control] = true end
            end
        end
    end
    for _, control in ipairs(order) do
        local on = wanted[control] == true
        -- Only guarded or fallback controls need telling when it goes off.
        if on or control.pbsGuard or self.fallback[control] then self:VetoControl(control, on) end
    end
    -- After the controls are back, so the text entry is looked at in the state the player sees.
    if self.resyncChatAfter then
        self.resyncChatAfter = false
        self:ResyncChat()
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
                if newState ~= SCENE_SHOWN then return end
                if self:CombatActive() then
                    if zo_callLater then
                        zo_callLater(function() self:ApplyCombat() end, SCENE_SETTLE_MS)
                    else
                        self:ApplyCombat()
                    end
                end
                -- The HUD itself, not the HUD with the cursor up.
                if scene == HUD_SCENE and self:ScanWanted() then
                    if zo_callLater then
                        zo_callLater(function() self:OnHudShown() end, SCAN_SETTLE_MS)
                    else
                        self:OnHudShown()
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

-- /pbhud combat [on | off | <target> on | off | add <name> | remove <name> | parts | scan]
-- `typed` is what was typed after the command's first word, in its own case: control names are
-- case-sensitive. Returns whether it understood, and the lines to print if not the status.
function A:CombatCommand(rest, typed)
    local first, second = rest:match("^(%S*)%s*(%S*)")
    local function flag(word)
        if word == "on" then return true end
        if word == "off" then return false end
        return nil
    end
    if first == "add" or first == "remove" then
        local name = (typed or ""):match("^%S+%s+(.-)%s*$") or ""
        if name == "" then return false end
        if first == "add" then self:AddPart(name) else self:RemovePart(name) end
        return true, { self.message }
    elseif first == "parts" then
        return true, self:PartsLines()
    elseif first == "scan" then
        -- From the chat, the HUD is what is on screen, so this sees what a scan should see.
        local found = self:ScanNow()
        return true, { self:Format(S.partsScanned, { found = found, count = #self:CandidateNames() }) }
    elseif first == "" then
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

-- ---------------------------------------------------------------------------------------
-- The parts of other add-ons, chosen from a list
--
-- Other add-ons cannot be told what to hide, so their parts are found on the screen and the
-- player picks the ones to hide. Three limits shape it, and none can be got round from here:
--
--   * A part is found by its name, among the windows that sit directly on the screen (GuiRoot's
--     children). One that another part holds -- FancyActionBar+ draws on the game's action bar --
--     is not found, and hiding what holds it would hide the game's own bar with it.
--   * Nothing says which add-on a part belongs to; the name is all there is. Parts without a
--     name, or with one made up each time, cannot be chosen: there is nothing to keep.
--   * The settings panel is a menu, and a menu hides the HUD. So the screen is looked at while
--     the HUD is up -- once after the login, and again when it comes back, at most every half
--     minute -- and the panel offers what was seen. What a scan sees is only what was showing.
--
-- The game's own parts (ZO_...) are never offered and never accepted: the ones worth hiding are
-- the targets above, and the rest are not for an add-on to take away.
-- ---------------------------------------------------------------------------------------

A.partDraft = {}

function A:IsGamePart(name)
    return name:sub(1, 3) == "ZO_" or name == self.name
end

-- A name that can be kept: text, trimmed, and not absurdly long. nil otherwise.
function A:ValidPartName(name)
    if type(name) ~= "string" then return nil end
    name = (name:gsub("^%s+", ""):gsub("%s+$", ""))
    if name == "" or #name > 120 then return nil end
    return name
end

-- Called when the saved settings are loaded: what came back from the file may be in any shape.
function A:NormalizeParts()
    local clean, known = {}, {}
    if type(self.sv.hudParts) == "table" then
        for _, name in ipairs(self.sv.hudParts) do
            local valid = self:ValidPartName(name)
            if valid and not self:IsGamePart(valid) and not known[valid] and #clean < self.maxParts then
                known[valid] = true
                clean[#clean + 1] = valid
            end
        end
    end
    self.sv.hudParts = clean
end

-- The control a name stands for, or nil. Anything that has a name is a global too, so the name
-- alone finds it; GetControl is asked first because it is what the client means by it.
function A:ControlByName(name)
    local control
    if type(GetControl) == "function" then
        local ok, found = pcall(GetControl, name)
        if ok then control = found end
    end
    if control == nil then control = rawget(_G, name) end
    return control
end

-- Looks at what sits on the screen and remembers the names of the parts that are showing, other
-- than the game's own. Remembered, not replaced: a part that was up a minute ago and is not now
-- is still the same part. Returns how many were not known before.
function A:ScanNow()
    self.lastScan = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
    self.scanRequested = false
    self.hudSeen = self.hudSeen or {}
    local found = 0
    local ok = pcall(function()
        for index = 1, GuiRoot:GetNumChildren() do
            local child = GuiRoot:GetChild(index)
            if child and type(child.GetName) == "function" and type(child.IsHidden) == "function" then
                local name = child:GetName()
                if type(name) == "string" and name ~= "" and not self:IsGamePart(name)
                    and not self.hudSeen[name] and not child:IsHidden() then
                    self.hudSeen[name] = true
                    found = found + 1
                end
            end
        end
    end)
    self.scanned = ok
    return found
end

-- Whether now is a time to look: not in a fight (what the option hides would not be seen), and
-- not more often than every half minute unless the player asked.
function A:ScanWanted()
    if self:CombatActive() then return false end
    if self.scanRequested or not self.lastScan then return true end
    local now = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
    return now - self.lastScan >= SCAN_INTERVAL_MS
end

function A:OnHudShown()
    if self:ScanWanted() then self:ScanNow() end
end

-- Once everything has loaded and the HUD is up.
function A:ScheduleLoginScan()
    if not zo_callLater then return end
    zo_callLater(function()
        self.scanRequested = true
        self:OnHudShown()
    end, SCAN_AFTER_LOGIN_MS)
end

-- What has been seen and not chosen, in order.
function A:CandidateNames()
    local chosen, names = {}, {}
    for _, name in ipairs(self.sv.hudParts) do chosen[name] = true end
    for name in pairs(self.hudSeen or {}) do
        if not chosen[name] then names[#names + 1] = name end
    end
    table.sort(names)
    return names
end

-- The rows of the two lists in the panel. Never empty: the library picks a row by its name, so an
-- empty list gets a placeholder that stands for nothing.
function A:CandidateItems()
    local items = {}
    for index, name in ipairs(self:CandidateNames()) do
        if index > MAX_LISTED then break end
        items[#items + 1] = { name = name, data = name }
    end
    if #items == 0 then items[1] = { name = S.partsNone, data = nil } end
    return items
end

function A:ChosenItems()
    local items = {}
    for _, name in ipairs(self.sv.hudParts) do items[#items + 1] = { name = name, data = name } end
    if #items == 0 then items[1] = { name = S.partsNoneChosen, data = nil } end
    return items
end

-- The row a dropdown shows: the one picked, or the first, which is what it shows until a pick.
function A:SelectedItem(items, picked)
    for _, item in ipairs(items) do
        if item.data ~= nil and item.data == picked then return item end
    end
    return items[1]
end

function A:AddPart(name)
    local clean = self:ValidPartName(name)
    if not clean then
        self:Say(S.partsNothingSelected)
        return false
    end
    if self:IsGamePart(clean) then
        self:Say(self:Format(S.partsRefused, { name = clean }))
        return false
    end
    for _, known in ipairs(self.sv.hudParts) do
        if known == clean then
            self:Say(self:Format(S.partsAlready, { name = clean }))
            return false
        end
    end
    if #self.sv.hudParts >= self.maxParts then
        self:Say(self:Format(S.partsFull, { max = self.maxParts }))
        return false
    end
    self.sv.hudParts[#self.sv.hudParts + 1] = clean
    self.partDraft.candidate = nil
    self:ApplyCombat()
    local there = self:ControlByName(clean) ~= nil
    self:Say(self:Format(there and S.partsAdded or S.partsAddedMissing, { name = clean }))
    return true
end

function A:RemovePart(name)
    local clean = self:ValidPartName(name)
    local list = self.sv.hudParts
    local at
    for index, known in ipairs(list) do
        if known == clean then at = index end
    end
    if not at then
        self:Say(clean and self:Format(S.partsNotChosen, { name = clean }) or S.partsNothingSelected)
        return false
    end
    table.remove(list, at)
    self.partDraft.chosen = nil
    -- No longer in any list, so the tick would not find it: let it go here, in the middle of a fight
    -- too, and then let the targets that still want it have it again.
    local control = self:ControlByName(clean)
    if control and type(control.IsHidden) == "function" and (control.pbsGuard or self.fallback[control]) then
        self:VetoControl(control, false)
    end
    self:ApplyCombat()
    self:Say(self:Format(S.partsRemoved, { name = clean }))
    return true
end

-- The buttons of the panel.
function A:PressAddPart()
    local item = self:SelectedItem(self:CandidateItems(), self.partDraft.candidate)
    return self:AddPart(item and item.data)
end

function A:PressRemovePart()
    local item = self:SelectedItem(self:ChosenItems(), self.partDraft.chosen)
    return self:RemovePart(item and item.data)
end

function A:PressRescan()
    self.scanRequested = true
    self:Say(S.partsRescanQueued)
end

function A:PartsStatus()
    if not self.scanned then return S.partsNotScanned end
    return self:Format(S.partsStatus, { found = #self:CandidateNames(), chosen = #self.sv.hudParts })
end

function A:PartsLines()
    local function join(list) return #list > 0 and table.concat(list, ", ") or "-" end
    local chosen, found = {}, {}
    for _, name in ipairs(self.sv.hudParts) do chosen[#chosen + 1] = name end
    for index, name in ipairs(self:CandidateNames()) do
        if index > MAX_LISTED then break end
        found[#found + 1] = name
    end
    return {
        self:Format(S.partsListChosen, { list = join(chosen) }),
        self:Format(S.partsListFound, { list = join(found) }),
    }
end
