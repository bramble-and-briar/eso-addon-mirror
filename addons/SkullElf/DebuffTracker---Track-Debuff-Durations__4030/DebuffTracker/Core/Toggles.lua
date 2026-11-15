-- Toggled abilities (tutsuraki, 5.13.7): is Power Overload / a toggle skill switched on? The game says so per
-- action bar slot -- IsSlotToggled(slot, hotbarCategory), the same call its own action bar uses to light up
-- a toggled button (esoui actionbutton.lua), refreshed on EVENT_HOTBAR_SLOT_STATE_UPDATED (actionbar.lua).
-- Werewolf form isn't a toggle on a slot (the bar changes): IsWerewolf() / EVENT_WEREWOLF_STATE_CHANGED.
--
-- A listed ability matches a slotted skill by ID, or by name -- also part of the name, so "overload" finds
-- Power Overload and Energy Overload.

local DT = DebuffTracker
local Tg = DT.Toggles
local U = DT.Util

local NS = "DebuffTracker5_Toggles"
local BARS = { HOTBAR_CATEGORY_PRIMARY or 0, HOTBAR_CATEGORY_BACKUP or 1 }
local FIRST_SLOT, LAST_SLOT = 3, 8          -- skills 3-7, ultimate 8 (as Load.Slotted)

local function SlotAbility(slot, cat)
    local id = type(GetSlotBoundId) == "function" and GetSlotBoundId(slot, cat) or 0
    if not id or id <= 0 then return nil end
    local name = type(GetSlotName) == "function" and GetSlotName(slot, cat) or ""
    -- a scribed skill's slot holds a crafted ability ID: the real one comes from the game (as Load.Slotted)
    if ACTION_TYPE_CRAFTED_ABILITY and type(GetSlotType) == "function" and GetSlotType(slot, cat) == ACTION_TYPE_CRAFTED_ABILITY
        and type(GetAbilityIdForCraftedAbilityId) == "function" then
        id = GetAbilityIdForCraftedAbilityId(id) or id
    end
    if name == "" then name = GetAbilityName(id) end
    return id, U.Lower(U.CleanName(name or "")), name
end

-- Is this one of the werewolf transformation's names? ("werewolf" typed in the list, or the ultimate itself)
local function IsWerewolfEntry(g)
    if g.werewolf ~= nil then return g.werewolf end
    local l = U.Lower(g.label or "")
    local yes = l:find("werewolf", 1, true) ~= nil or l:find("pack leader", 1, true) ~= nil
    for n in pairs(g.names or {}) do
        if n:find("werewolf", 1, true) or n:find("pack leader", 1, true) then yes = true end
    end
    g.werewolf = yes
    return yes
end

local function Matches(g, id, lname)
    if g.ids[id] then return true end
    for n in pairs(g.names) do
        if lname == n or (n ~= "" and lname:find(n, 1, true)) then return true end
    end
    -- listed by ID, slotted as another rank with the same name (names worked out once per list)
    local idNames = g.toggleIdNames
    if not idNames then
        idNames = {}
        for gid in pairs(g.ids) do
            local gl = U.Lower(U.CleanName(GetAbilityName(gid)))
            if gl ~= "" then idNames[gl] = true end
        end
        g.toggleIdNames = idNames
    end
    return idNames[lname] == true
end

-- State of one listed ability: on (bool), slotted (bool), icon of the slotted skill, its name
function Tg.State(g)
    if IsWerewolfEntry(g) then
        local on = type(IsWerewolf) == "function" and IsWerewolf() == true
        return on, true, nil, nil
    end
    local slottedAny, icon, name = false, nil, nil
    for _, cat in ipairs(BARS) do
        for slot = FIRST_SLOT, LAST_SLOT do
            local id, lname, raw = SlotAbility(slot, cat)
            if id and Matches(g, id, lname) then
                slottedAny = true
                icon = icon or (type(GetSlotTexture) == "function" and GetSlotTexture(slot, cat)) or GetAbilityIcon(id)
                name = name or U.CleanName(raw or "")
                if type(IsSlotToggled) == "function" and IsSlotToggled(slot, cat) == true then
                    return true, true, icon, name
                end
            end
        end
    end
    return false, slottedAny, icon, name
end

------------------------------------------------------------------------------
-- Events: only while a tracker watches toggles. The slot-state event fires for any slot change (usable,
-- cost...) -- an update is asked for only when a watched toggle actually flipped.
------------------------------------------------------------------------------

local watched = {}          -- list of compiled groups
local last = {}             -- [group] = on
local registered = false

local function Check()
    local changed = false
    for _, g in ipairs(watched) do
        local on = Tg.State(g)
        if last[g] ~= on then
            last[g] = on
            changed = true
        end
    end
    if changed and DT.Engine.RequestUpdate then DT.Engine.RequestUpdate() end
end
Tg.Check = Check

local EVENTS = { "EVENT_HOTBAR_SLOT_STATE_UPDATED", "EVENT_HOTBAR_SLOT_UPDATED", "EVENT_ACTION_SLOT_UPDATED",
    "EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED", "EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED", "EVENT_WEREWOLF_STATE_CHANGED" }

-- groups: compiled ability groups of every enabled toggle tracker
function Tg.SetWatched(groups)
    watched = groups or {}
    last = {}
    local want = #watched > 0
    if want == registered then if want then Check() end return end
    registered = want
    for i, name in ipairs(EVENTS) do
        local ev = _G[name]
        if ev then
            if want then EVENT_MANAGER:RegisterForEvent(NS .. i, ev, Check)
            else EVENT_MANAGER:UnregisterForEvent(NS .. i, ev) end
        end
    end
    if want then Check() end
end

function Tg.IsWatching() return registered end
