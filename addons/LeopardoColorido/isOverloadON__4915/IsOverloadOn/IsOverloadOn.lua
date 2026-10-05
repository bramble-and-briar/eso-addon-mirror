-- IsOverloadOn
-- Shows big, near the center of the screen, whether the sorcerer's Overload (or its morphs Power and Energy Overload)
-- is on. The game only marks the ultimate slot with a thin frame, and FancyActionBar+'s highlight is a background
-- behind the icon, so only its border shows. While on, it shows how many light attacks the ultimate can still pay
-- for. When the skill turns off without you pressing it (ultimate ran out), the alert flashes and plays a sound.
-- Swapping bars does not turn it off.
--
-- The state comes from three sources, and any one saying "on" is enough: the skill's effect on the character (what
-- FancyActionBar+ tracks), IsSlotToggled on the ultimate slot of the active bar (what the game's action bar uses), and
-- the active bar being HOTBAR_CATEGORY_OVERLOAD. /overload test shows all three; /overload events prints every change.
--
-- The game does not say how much each attack costs (the skill's cost is the minimum to turn it on), and vampirism
-- makes it more expensive. The addon starts from values measured in game (KNOWN_ATTACK_COST) and keeps measuring:
-- with Overload on, every drop of the ultimate is the cost of one attack. It uses the most frequent of the recent
-- drops and saves it per skill and vampirism stage in the SavedVariables.

local NAME = "IsOverloadOn"
local VERSION = "1.7.0" -- same as IsOverloadOn.txt

-- Ids checked against data collected in game (API 101051).
local OVERLOAD_IDS = {
    [24785] = true, -- Overload
    [24806] = true, -- Power Overload
    [24804] = true, -- Energy Overload
}
local FALLBACK_ICON_ID = 24806

-- Vampirism stage from the buff on the character (ids from Bandits User Interface, API 101051). No buff = 0.
local VAMPIRE_STAGES = {
    [135397] = 1,
    [135399] = 2,
    [135400] = 3,
    [135402] = 4,
}

-- Light attack cost measured in game on 2026-10-03, per vampirism stage. For the other skills the addon measures on
-- the first attack.
local KNOWN_ATTACK_COST = {
    [24806] = { [0] = 21, [1] = 22, [2] = 23, [3] = 23, [4] = 24 }, -- Power Overload
}

local ULT_SLOT = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1
local BARS = { HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP, HOTBAR_CATEGORY_OVERLOAD }

-- Turned off up to 1.5 s after you pressed the ultimate: on purpose, no alarm. The margin covers ping, because the
-- effect ending comes from the server.
local MANUAL_WINDOW_MS = 1500
-- Waits for the button event to arrive before deciding whether to sound the alarm.
local ALARM_DELAY_MS = 200
local FLASH_MS = 3000
local BLINK_MS = 330

-- Ultimate drops kept to find the cost of one attack, and from how many light attacks left the number turns to the
-- warning color. The history starts with the known cost repeated SEED_DROPS times: a single odd drop (a heavy attack,
-- or a gain and a cost in the same instant) does not change the cost, but two equal ones in a row do.
local DROP_HISTORY = 8
local SEED_DROPS = 2
local LOW_ATTACKS = 3

local COLOR_ON = { 0.35, 0.78, 1, 1 }
local COLOR_OFF = { 1, 0.22, 0.18, 1 }
local COLOR_MOVE = { 1, 0.85, 0.2, 1 }
local COLOR_LOW = { 1, 0.6, 0.15, 1 }
local COLOR_TEXT = { 0.9, 0.9, 0.9, 1 }
local COLOR_SIGNET = { 1, 0.55, 0.1, 1 }

-- "Signet" option: while on, as the ultimate goes down from 500, the whole alert turns orange at this much or less.
-- Off it keeps the red: there the ultimate is usually low, and orange would hide the main warning.
local SIGNET_ULTIMATE = 170

local SOUND_CHOICES = {
    { name = "Countdown warning", id = SOUNDS.COUNTDOWN_WARNING },
    { name = "Duel boundary", id = SOUNDS.DUEL_BOUNDARY_WARNING },
    { name = "Error alert", id = SOUNDS.GENERAL_ALERT_ERROR },
    { name = "Not enough ultimate", id = SOUNDS.ABILITY_NOT_ENOUGH_ULTIMATE },
}

-- When to show the red alert with Overload off (while on, it always shows).
local OFF_MODES = {
    combat = "only in combat",
    always = "always, in or out of combat",
    never = "only the 3 s alert when it turns off by itself",
}

-- The position is the box's left edge (sv.left, not in DEFAULTS; see OnAddOnLoaded) and vertical center, relative to
-- the center of the screen: the box grows and shrinks to the right with the text while the icon stays put.
local DEFAULT_LEFT = -110

local DEFAULTS = {
    y = 160,
    size = 1,
    bgAlpha = 0.6, -- background opacity
    sound = 1, -- index in SOUND_CHOICES; 0 = no sound
    showOff = "combat",
    showTitle = true, -- skill name above ON/OFF
    showAttacks = true, -- big number of light attacks left next to ON/OFF
    showAttacksOff = true, -- the number also while off: how many the ultimate would pay for if turned on now
    showUltimate = true, -- current ultimate on the bottom line
    signet = false, -- whole alert orange while on with SIGNET_ULTIMATE or less
    locked = false, -- starts unlocked, so it can be dragged without a command
    attackCost = {}, -- measured cost of one attack: [skill id][vampirism stage]
}

local sv
local ui = {}
local state = {
    effect = false, -- skill effect on the character, according to the events
    active = false,
    lastUltPressMS = 0,
    ultimate = nil, -- last value seen, to measure the drops
    vampireStage = 0,
    drops = {},
    dropsKey = nil, -- skill and stage the drop history refers to
    reason = "",
    flashUntilMS = 0,
    verbose = false,
}

local function Say(message)
    CHAT_ROUTER:AddSystemMessage("|c59c7ffIsOverloadOn:|r " .. message)
end

local function Now()
    return GetFrameTimeMilliseconds()
end

local function Trace(message)
    if state.verbose then
        Say(string.format("[%.1f s] %s", Now() / 1000, message))
    end
end

-- Reading the state -------------------------------------------------------------------------------------------------

local function OverloadIdOn(hotbar)
    local id = GetSlotBoundId(ULT_SLOT, hotbar)
    if OVERLOAD_IDS[id] then
        return id
    end
end

local function AnySlottedId()
    for _, hotbar in ipairs(BARS) do
        local id = OverloadIdOn(hotbar)
        if id then
            return id
        end
    end
end

local function HasOverloadBuff()
    for i = 1, GetNumBuffs("player") do
        local abilityId = select(11, GetUnitBuffInfo("player", i))
        if OVERLOAD_IDS[abilityId] then
            return true
        end
    end
    return false
end

local function IsUltToggled()
    local hotbar = GetActiveHotbarCategory()
    return OverloadIdOn(hotbar) ~= nil and IsSlotToggled(ULT_SLOT, hotbar) == true
end

local function IsOnOverloadBar()
    return GetActiveHotbarCategory() == HOTBAR_CATEGORY_OVERLOAD
end

local function ReadActive()
    return state.effect or IsUltToggled() or IsOnOverloadBar()
end

local function CurrentUltimate()
    return GetUnitPower("player", COMBAT_MECHANIC_FLAGS_ULTIMATE)
end

-- The most frequent of the recent drops; on a tie, the most recent one wins.
local function MostFrequentDrop()
    local counts, best, bestCount = {}, nil, 0
    for i = #state.drops, 1, -1 do
        local drop = state.drops[i]
        counts[drop] = (counts[drop] or 0) + 1
        if counts[drop] > bestCount then
            best, bestCount = drop, counts[drop]
        end
    end
    return best
end

local function ReadVampireStage()
    for i = 1, GetNumBuffs("player") do
        local stage = VAMPIRE_STAGES[select(11, GetUnitBuffInfo("player", i))]
        if stage then
            return stage
        end
    end
    return 0
end

-- What the addon measured beats the known value.
local function AttackCost(abilityId)
    if not abilityId then
        return nil
    end
    local measured = sv.attackCost[abilityId]
    local known = KNOWN_ATTACK_COST[abilityId]
    return (measured and measured[state.vampireStage]) or (known and known[state.vampireStage])
end

local function RecordDrop(drop, abilityId)
    if not abilityId then
        return
    end
    local key = abilityId .. ":" .. state.vampireStage
    if state.dropsKey ~= key then
        state.drops, state.dropsKey = {}, key
        local current = AttackCost(abilityId)
        for _ = 1, current and SEED_DROPS or 0 do
            table.insert(state.drops, current)
        end
    end
    table.insert(state.drops, drop)
    if #state.drops > DROP_HISTORY then
        table.remove(state.drops, 1)
    end
    sv.attackCost[abilityId] = sv.attackCost[abilityId] or {}
    sv.attackCost[abilityId][state.vampireStage] = MostFrequentDrop()
end

-- Display -----------------------------------------------------------------------------------------------------------

local function Font(face, size, effect)
    return string.format("$(%s)|%d|%s", face, zo_round(size * sv.size), effect)
end

-- Sizes that depend on sv.size; Render uses them to fit the width to the text.
local metrics = {}

local function Layout()
    local s = sv.size
    local pad = zo_round(10 * s)
    local box = zo_round(76 * s)
    local edge = zo_max(2, zo_round(4 * s))
    metrics.pad, metrics.box, metrics.gap = pad, box, zo_round(pad * 1.5)

    -- The width is set by Render, from the text.
    ui.window:SetHeight(box + pad * 2)
    ui.window:ClearAnchors()
    ui.window:SetAnchor(LEFT, GuiRoot, CENTER, sv.left, sv.y)
    ui.bg:SetColor(0, 0, 0, sv.bgAlpha)

    ui.edge:SetDimensions(box, box)
    ui.edge:ClearAnchors()
    ui.edge:SetAnchor(LEFT, ui.frame, LEFT, pad, 0)
    ui.icon:SetDimensions(box - edge * 2, box - edge * 2)
    ui.icon:ClearAnchors()
    ui.icon:SetAnchor(CENTER, ui.edge, CENTER, 0, 0)

    ui.title:SetFont(Font("BOLD_FONT", 14, "soft-shadow-thick"))
    ui.title:ClearAnchors()
    ui.title:SetAnchor(TOPLEFT, ui.edge, TOPRIGHT, pad, 0)
    ui.status:SetFont(Font("BOLD_FONT", 30, "thick-outline"))
    ui.status:ClearAnchors()
    ui.status:SetAnchor(LEFT, ui.edge, RIGHT, pad, 0)
    ui.count:SetFont(Font("BOLD_FONT", 30, "thick-outline"))
    ui.count:ClearAnchors()
    ui.count:SetAnchor(LEFT, ui.status, RIGHT, metrics.gap, 0)
    ui.reason:SetFont(Font("BOLD_FONT", 15, "soft-shadow-thick"))
    ui.reason:ClearAnchors()
    ui.reason:SetAnchor(BOTTOMLEFT, ui.edge, BOTTOMRIGHT, pad, 0)
end

local function IsFlashing()
    return Now() < state.flashUntilMS
end

-- Unlocked and with the mouse cursor free (hudui scene), the alert shows even with no reason, so it can be dragged.
local function IsPositioning()
    return not sv.locked and HUD_UI_SCENE:IsShowing()
end

local function ShouldShow(slottedId)
    if not slottedId then
        return false
    end
    if state.active or IsFlashing() or IsPositioning() then
        return true
    end
    -- Off shows on both bars: Overload only needs to be on one of them (slottedId).
    if IsUnitDead("player") then
        return false
    end
    if sv.showOff == "always" then
        return true
    end
    return sv.showOff == "combat" and IsUnitInCombat("player")
end

local function Render()
    if not ui.window then
        return
    end
    local slottedId = AnySlottedId()
    local show = ShouldShow(slottedId)
    ui.frame:SetHidden(not show)
    -- Only takes the mouse while shown; hidden and unlocked, it would block clicks on an invisible area.
    ui.window:SetMouseEnabled(show and not sv.locked)
    if not show then
        return
    end

    local iconId = slottedId or FALLBACK_ICON_ID
    ui.icon:SetTexture(GetAbilityIcon(iconId))
    ui.icon:SetDesaturation(state.active and 0 or 1)
    -- Uppercased here, not with SetModifyTextType, so GetTextWidth measures the text as shown.
    ui.title:SetText(sv.showTitle and zo_strupper(zo_strformat("<<1>>", GetAbilityName(iconId))) or "")

    local ultimate = CurrentUltimate()
    local color = state.active and COLOR_ON or COLOR_OFF
    if sv.signet and state.active and ultimate <= SIGNET_ULTIMATE then
        color = COLOR_SIGNET
    end
    ui.status:SetText(state.active and "ON" or "OFF")
    ui.status:SetColor(unpack(color))

    -- Big number next to ON/OFF: light attacks the ultimate can still pay for (while off, how many it would pay for if
    -- turned on now). "?" while the cost of this skill has not been measured.
    local count, countColor = "", color
    if sv.showAttacks and (state.active or sv.showAttacksOff) then
        local cost = AttackCost(slottedId)
        if cost then
            local attacks = math.floor(ultimate / cost)
            count = tostring(attacks)
            if state.active and attacks <= LOW_ATTACKS then
                countColor = COLOR_LOW
            end
        else
            count = "?"
        end
    end
    ui.count:SetText(count)
    ui.count:SetColor(unpack(countColor))

    -- Bottom line: current ultimate and why it turned off. Positioning while off, the hint takes its place.
    local positioning = IsPositioning()
    local parts = {}
    if positioning and not state.active then
        table.insert(parts, "drag to move")
    else
        if sv.showUltimate then
            table.insert(parts, string.format("ult %d", ultimate))
        end
        if not state.active and state.reason ~= "" then
            table.insert(parts, state.reason)
        end
    end
    ui.reason:SetText(table.concat(parts, " · "))

    ui.edge:SetColor(unpack(positioning and COLOR_MOVE or color))

    -- Width just enough for the widest line (the outline of the big text sticks out a little: + gap / 2).
    local middle = ui.status:GetTextWidth()
    if count ~= "" then
        middle = middle + metrics.gap + ui.count:GetTextWidth()
    end
    local textWidth = zo_max(ui.title:GetTextWidth(), middle + metrics.gap / 2, ui.reason:GetTextWidth())
    ui.window:SetWidth(metrics.pad * 3 + metrics.box + zo_ceil(textWidth))
end

local function StopFlash()
    EVENT_MANAGER:UnregisterForUpdate(NAME .. "Flash")
    ui.frame:SetAlpha(1)
    Render()
end

local function StartFlash()
    state.flashUntilMS = Now() + FLASH_MS
    EVENT_MANAGER:UnregisterForUpdate(NAME .. "Flash")
    EVENT_MANAGER:RegisterForUpdate(NAME .. "Flash", 40, function()
        if state.active or not IsFlashing() then
            StopFlash()
            return
        end
        local lit = (Now() % BLINK_MS) < (BLINK_MS / 2)
        ui.frame:SetAlpha(lit and 1 or 0.2)
    end)
    Render()
end

local function SavePosition()
    local _, y = ui.window:GetCenter()
    local rootX, rootY = GuiRoot:GetCenter()
    sv.left = zo_round(ui.window:GetLeft() - rootX)
    sv.y = zo_round(y - rootY)
end

local function ApplyLock()
    ui.window:SetMovable(not sv.locked)
    Render()
end

local function CreateUI()
    local wm = WINDOW_MANAGER
    local window = wm:CreateTopLevelWindow(NAME .. "Window")
    window:SetClampedToScreen(true)
    window:SetMouseEnabled(false)
    window:SetMovable(false)
    window:SetHandler("OnMoveStop", SavePosition)

    local frame = wm:CreateControl("$(parent)Frame", window, CT_CONTROL)
    frame:SetAnchorFill(window)

    -- Textures without a file draw a rectangle of the given color.
    local bg = wm:CreateControl("$(parent)Bg", frame, CT_TEXTURE)
    bg:SetAnchorFill(frame)
    bg:SetDrawLevel(0)

    local edge = wm:CreateControl("$(parent)Edge", frame, CT_TEXTURE)
    edge:SetDrawLevel(1)
    local icon = wm:CreateControl("$(parent)Icon", frame, CT_TEXTURE)
    icon:SetDrawLevel(2)

    local function Label(suffix)
        local label = wm:CreateControl("$(parent)" .. suffix, frame, CT_LABEL)
        label:SetDrawLevel(2)
        label:SetColor(1, 1, 1, 1)
        return label
    end
    local title = Label("Title")
    title:SetColor(0.85, 0.85, 0.85, 1)
    local status = Label("Status")
    local count = Label("Count")
    local reason = Label("Reason")
    reason:SetColor(unpack(COLOR_TEXT))

    ui.window, ui.frame, ui.bg, ui.edge, ui.icon = window, frame, bg, edge, icon
    ui.title, ui.status, ui.count, ui.reason = title, status, count, reason

    -- Hides along with the rest of the HUD in menus, like the action bar.
    local fragment = ZO_HUDFadeSceneFragment:New(window)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
end

-- Events ------------------------------------------------------------------------------------------------------------

local function Alarm()
    if state.active or IsUnitDead("player") then
        return
    end
    local now = Now()
    if now - state.lastUltPressMS <= MANUAL_WINDOW_MS + ALARM_DELAY_MS then
        Trace("turned off by you (pressed the ultimate), no alarm")
        return
    end
    state.reason = "turned off by itself"
    Trace(string.format("alarm: %s, ult %d", state.reason, CurrentUltimate()))
    local sound = SOUND_CHOICES[sv.sound]
    if sound then
        PlaySound(sound.id)
    end
    StartFlash()
end

local function Refresh()
    local active = ReadActive()
    if active ~= state.active then
        state.active = active
        Trace(string.format("%s (effect %s, slot %s, overload bar %s)", active and "ON" or "OFF",
            tostring(state.effect), tostring(IsUltToggled()), tostring(IsOnOverloadBar())))
        if active then
            state.reason = ""
            state.flashUntilMS = 0
        else
            zo_callLater(Alarm, ALARM_DELAY_MS)
        end
    end
    Render()
end

local function OnEffectChanged(_, changeType, _, effectName, _, _, _, _, _, _, _, _, _, _, _, abilityId)
    if not OVERLOAD_IDS[abilityId] then
        return
    end
    state.effect = changeType ~= EFFECT_RESULT_FADED
    Trace(string.format("effect %s (%d): %s", effectName, abilityId, state.effect and "gained" or "lost"))
    Refresh()
end

-- With Overload on, every drop of the ultimate is the cost of one attack. Always redraws: the bottom line shows the
-- ultimate even while off.
local function OnUltimateChanged(_, _, _, _, value)
    local previous = state.ultimate
    state.ultimate = value
    if state.active and previous and value < previous then
        local id = AnySlottedId()
        RecordDrop(previous - value, id)
        Trace(string.format("ultimate %d -> %d (-%d), vampirism %d, attack cost %s", previous, value,
            previous - value, state.vampireStage, tostring(AttackCost(id))))
    end
    Render()
end

-- On a stage change the old buff fades and the new one is gained; reread the list so the event order does not matter.
local function OnVampireStageChanged()
    local stage = ReadVampireStage()
    if stage ~= state.vampireStage then
        state.vampireStage = stage
        Trace("vampirism stage " .. stage)
        Render()
    end
end

local function OnPlayerActivated()
    -- No alarm on load: just read how things are.
    state.effect = HasOverloadBuff()
    state.active = ReadActive()
    state.ultimate = CurrentUltimate()
    state.vampireStage = ReadVampireStage()
    state.reason = ""
    Render()
end

local function RegisterEvents()
    local em = EVENT_MANAGER
    for id in pairs(OVERLOAD_IDS) do
        local namespace = NAME .. "Effect" .. id
        em:RegisterForEvent(namespace, EVENT_EFFECT_CHANGED, OnEffectChanged)
        em:AddFilterForEvent(namespace, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, id,
            REGISTER_FILTER_UNIT_TAG, "player")
    end
    for id in pairs(VAMPIRE_STAGES) do
        local namespace = NAME .. "Vampire" .. id
        em:RegisterForEvent(namespace, EVENT_EFFECT_CHANGED, OnVampireStageChanged)
        em:AddFilterForEvent(namespace, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, id,
            REGISTER_FILTER_UNIT_TAG, "player")
    end
    em:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    em:RegisterForEvent(NAME, EVENT_HOTBAR_SLOT_STATE_UPDATED, function(_, slot)
        if slot == ULT_SLOT then
            Refresh()
        end
    end)
    em:RegisterForEvent(NAME, EVENT_HOTBAR_SLOT_UPDATED, Refresh)
    em:RegisterForEvent(NAME, EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, Refresh)
    em:RegisterForEvent(NAME, EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, Refresh)
    em:RegisterForEvent(NAME, EVENT_ACTIVE_WEAPON_PAIR_CHANGED, Refresh)
    em:RegisterForEvent(NAME, EVENT_POWER_UPDATE, OnUltimateChanged)
    em:AddFilterForEvent(NAME, EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "player",
        REGISTER_FILTER_POWER_TYPE, COMBAT_MECHANIC_FLAGS_ULTIMATE)
    em:RegisterForEvent(NAME, EVENT_ACTION_SLOT_ABILITY_USED, function(_, slot)
        if slot == ULT_SLOT then
            state.lastUltPressMS = Now()
            Trace("pressed the ultimate")
        end
    end)
    em:RegisterForEvent(NAME, EVENT_PLAYER_COMBAT_STATE, Refresh)
    em:RegisterForEvent(NAME, EVENT_PLAYER_DEAD, Refresh)
    em:RegisterForEvent(NAME, EVENT_PLAYER_ALIVE, Refresh)
end

-- Diagnostics -------------------------------------------------------------------------------------------------------

local function Diagnose()
    local active = GetActiveHotbarCategory()
    Say(string.format("active bar %d (primary %d, backup %d, overload %d)", active, HOTBAR_CATEGORY_PRIMARY,
        HOTBAR_CATEGORY_BACKUP, HOTBAR_CATEGORY_OVERLOAD))
    for _, hotbar in ipairs(BARS) do
        local id = GetSlotBoundId(ULT_SLOT, hotbar)
        local name = id ~= 0 and zo_strformat("<<1>>", GetAbilityName(id)) or "empty"
        Say(string.format("  bar %d ultimate: %s (%d), toggled %s, skill cost %d", hotbar, name, id,
            tostring(IsSlotToggled(ULT_SLOT, hotbar)),
            GetSlotAbilityCost(ULT_SLOT, COMBAT_MECHANIC_FLAGS_ULTIMATE, hotbar)))
    end
    Say(string.format("effect from events %s, effect in buff list %s, on %s", tostring(state.effect),
        tostring(HasOverloadBuff()), tostring(state.active)))
    local id = AnySlottedId()
    Say(string.format("ultimate %d; vampirism %d; attack cost %s; recent drops: %s", CurrentUltimate(),
        state.vampireStage, tostring(AttackCost(id)), #state.drops > 0 and table.concat(state.drops, ", ") or "none"))
    for i = 1, GetNumBuffs("player") do
        local buffName, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
        if OVERLOAD_IDS[abilityId] or buffName:lower():find("overload", 1, true) then
            Say(string.format("  buff on character: %s (%d)", buffName, abilityId))
        end
    end
end

-- Actions shared by the chat commands and the menu ------------------------------------------------------------------

local function SetLocked(locked)
    sv.locked = locked
    ApplyLock()
end

local function PlayAlarmSound()
    local sound = SOUND_CHOICES[sv.sound]
    if sound then
        PlaySound(sound.id)
    end
end

local function TestAlarm()
    state.reason = "alarm test"
    PlayAlarmSound()
    StartFlash()
    if not AnySlottedId() then
        Say("the alarm only shows with Overload, Power Overload or Energy Overload on a bar.")
    end
end

local function ResetPosition()
    sv.left, sv.y = DEFAULT_LEFT, DEFAULTS.y
    Layout()
end

local function SetBackgroundAlpha(alpha)
    sv.bgAlpha = alpha
    ui.bg:SetColor(0, 0, 0, alpha)
end

local function SetSize(size)
    sv.size = size
    Layout()
    Render()
end

-- Clears the measurements of one skill (or all of them): back to the known values, measuring again.
local function ClearMeasuredCosts(abilityId)
    if abilityId then
        sv.attackCost[abilityId] = nil
    else
        sv.attackCost = {}
    end
    state.dropsKey = nil
    Render()
end

local function CostSummary()
    local id = AnySlottedId() or FALLBACK_ICON_ID
    local costs = {}
    for stage = 0, 4 do
        local measured = sv.attackCost[id] and sv.attackCost[id][stage]
        local known = KNOWN_ATTACK_COST[id] and KNOWN_ATTACK_COST[id][stage]
        table.insert(costs, tostring(measured or known or "?"))
    end
    return string.format("Ultimate spent per %s light attack, without vampirism and at stages 1 to 4: %s. Your "
        .. "current stage: %d. The addon measures every attack and corrects itself; \"?\" means not measured yet.",
        zo_strformat("<<1>>", GetAbilityName(id)), table.concat(costs, " / "), state.vampireStage)
end

-- Chat commands -----------------------------------------------------------------------------------------------------

local settingsPanel

local function DescribeSettings()
    local sound = SOUND_CHOICES[sv.sound]
    Say(string.format("position %s; sound: %s; when off: %s (%s); size %d%%", sv.locked and "locked" or "unlocked",
        sound and sound.name or "none", sv.showOff, OFF_MODES[sv.showOff], zo_round(sv.size * 100)))
end

local function Help()
    Say("/overload menu · lock · unlock · sound · off combat|always|never · size 0.5 to 3 · center"
        .. " · cost [n|clear] · alarm · test · events")
    DescribeSettings()
end

local commands = {
    menu = function()
        if settingsPanel then
            LibAddonMenu2:OpenToPanel(settingsPanel)
        else
            Say("the menu needs LibAddonMenu-2.0 enabled.")
        end
    end,
    lock = function()
        SetLocked(true)
        Say("position locked.")
    end,
    unlock = function()
        SetLocked(false)
        Say("unlocked: free the mouse cursor and drag the alert.")
    end,
    sound = function()
        sv.sound = (sv.sound + 1) % (#SOUND_CHOICES + 1)
        local sound = SOUND_CHOICES[sv.sound]
        PlayAlarmSound()
        Say(sound and ("sound: " .. sound.name .. ". Repeat /overload sound for the next one.")
            or "no sound. Repeat /overload sound to go back to the first one.")
    end,
    off = function(arg)
        if not OFF_MODES[arg] then
            Say("use /overload off combat, always or never.")
            return
        end
        sv.showOff = arg
        Say("when off: " .. OFF_MODES[arg] .. ".")
        Render()
    end,
    size = function(arg)
        local size = tonumber((arg:gsub(",", ".")))
        if not size or size < 0.5 or size > 3 then
            Say("use /overload size with a number from 0.5 to 3 (1 is normal).")
            return
        end
        SetSize(size)
    end,
    center = function()
        ResetPosition()
        Say("back to the starting position.")
    end,
    -- The measured cost can be set by hand (for the current vampirism stage) or cleared.
    cost = function(arg)
        local id = AnySlottedId()
        if not id then
            Say("slot Overload on a bar first.")
            return
        end
        local skill = string.format("%s, vampirism %d", zo_strformat("<<1>>", GetAbilityName(id)), state.vampireStage)
        if arg == "clear" then
            ClearMeasuredCosts(id)
            Say(skill .. ": measurements cleared; back to the known value, measuring again.")
        elseif tonumber(arg) and tonumber(arg) >= 1 then
            sv.attackCost[id] = sv.attackCost[id] or {}
            sv.attackCost[id][state.vampireStage] = math.floor(tonumber(arg))
            state.dropsKey = nil
            Say(string.format("%s: each attack costs %d ultimate.", skill, AttackCost(id)))
            Render()
        elseif arg == "" then
            Say(CostSummary())
        else
            Say("use /overload cost, /overload cost 25 or /overload cost clear.")
        end
    end,
    alarm = TestAlarm,
    test = Diagnose,
    events = function()
        state.verbose = not state.verbose
        Say(state.verbose and "showing every change in chat. /overload events to stop." or "stopped showing.")
    end,
}

local function OnSlashCommand(text)
    local command, arg = (text or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    local handler = commands[command]
    if handler then
        handler(arg)
    else
        Help()
    end
end

-- Menu (LibAddonMenu-2.0, optional) ---------------------------------------------------------------------------------

local function CreateSettingsMenu()
    local LAM = LibAddonMenu2
    if not LAM then
        return
    end

    local soundNames, soundValues = { "None" }, { 0 }
    for i, sound in ipairs(SOUND_CHOICES) do
        table.insert(soundNames, sound.name)
        table.insert(soundValues, i)
    end

    local panelName = NAME .. "Settings"
    settingsPanel = LAM:RegisterAddonPanel(panelName, {
        type = "panel",
        name = "IsOverloadOn",
        author = "LeopardoColorido",
        version = VERSION,
        registerForRefresh = true,
        registerForDefaults = true,
    })

    LAM:RegisterOptionControls(panelName, {
        {
            type = "description",
            text = "Shows near the center of the screen whether Overload (Power or Energy Overload) is on and how many "
                .. "light attacks your ultimate can still pay for. When it turns off without you pressing it, the "
                .. "alert flashes and plays a sound.",
        },
        { type = "header", name = "Position and size" },
        {
            type = "checkbox",
            name = "Lock position",
            tooltip = "Unlocked, the alert shows with a yellow border whenever you free the mouse cursor, and can be "
                .. "dragged. Lock it once it is in place.",
            getFunc = function() return sv.locked end,
            setFunc = SetLocked,
            default = DEFAULTS.locked,
        },
        {
            type = "slider",
            name = "Size (%)",
            min = 50,
            max = 300,
            step = 10,
            getFunc = function() return zo_round(sv.size * 100) end,
            setFunc = function(value) SetSize(value / 100) end,
            default = DEFAULTS.size * 100,
        },
        {
            type = "slider",
            name = "Background opacity (%)",
            tooltip = "Only the dark background behind the alert; the icon and the text stay solid.",
            min = 0,
            max = 100,
            step = 5,
            getFunc = function() return zo_round(sv.bgAlpha * 100) end,
            setFunc = function(value) SetBackgroundAlpha(value / 100) end,
            default = DEFAULTS.bgAlpha * 100,
        },
        {
            type = "button",
            name = "Reset position",
            tooltip = "Moves the alert back to just below the center of the screen.",
            func = ResetPosition,
            width = "half",
        },
        { type = "header", name = "What to show" },
        {
            type = "checkbox",
            name = "Skill name",
            tooltip = "Overload, Power Overload or Energy Overload, above ON/OFF.",
            getFunc = function() return sv.showTitle end,
            setFunc = function(value)
                sv.showTitle = value
                Render()
            end,
            default = DEFAULTS.showTitle,
        },
        {
            type = "checkbox",
            name = "Light attacks left",
            tooltip = "Big number next to ON: how many light attacks your ultimate can still pay for. Turns orange at "
                .. LOW_ATTACKS .. " or less.",
            getFunc = function() return sv.showAttacks end,
            setFunc = function(value)
                sv.showAttacks = value
                Render()
            end,
            default = DEFAULTS.showAttacks,
        },
        {
            type = "checkbox",
            name = "Light attacks while off",
            tooltip = "Keeps the number next to OFF: how many light attacks your ultimate would pay for if you turned "
                .. "Overload on now.",
            getFunc = function() return sv.showAttacksOff end,
            setFunc = function(value)
                sv.showAttacksOff = value
                Render()
            end,
            disabled = function() return not sv.showAttacks end,
            default = DEFAULTS.showAttacksOff,
        },
        {
            type = "checkbox",
            name = "Current ultimate",
            tooltip = "Bottom line: your ultimate right now.",
            getFunc = function() return sv.showUltimate end,
            setFunc = function(value)
                sv.showUltimate = value
                Render()
            end,
            default = DEFAULTS.showUltimate,
        },
        {
            type = "checkbox",
            name = "Signet",
            tooltip = "While Overload is on, turns the whole alert orange once your ultimate drops to "
                .. SIGNET_ULTIMATE .. " or less. While off, the alert stays red.",
            getFunc = function() return sv.signet end,
            setFunc = function(value)
                sv.signet = value
                Render()
            end,
            default = DEFAULTS.signet,
        },
        { type = "header", name = "When to show" },
        {
            type = "dropdown",
            name = "Overload off",
            tooltip = "While on, the alert always shows. While off, it shows on both bars as long as Overload is "
                .. "slotted on either one.",
            choices = { "Only in combat", "Always", "Never (only the 3 s alert)" },
            choicesValues = { "combat", "always", "never" },
            getFunc = function() return sv.showOff end,
            setFunc = function(value)
                sv.showOff = value
                Render()
            end,
            default = DEFAULTS.showOff,
        },
        { type = "header", name = "Alarm when it turns off by itself" },
        {
            type = "dropdown",
            name = "Sound",
            tooltip = "Plays the chosen sound so you can hear it.",
            choices = soundNames,
            choicesValues = soundValues,
            getFunc = function() return sv.sound end,
            setFunc = function(value)
                sv.sound = value
                PlayAlarmSound()
            end,
            default = DEFAULTS.sound,
        },
        {
            type = "button",
            name = "Test alarm",
            tooltip = "Flashes the alert and plays the sound. Needs Overload on a bar.",
            func = TestAlarm,
            width = "half",
        },
        { type = "header", name = "Light attacks left" },
        { type = "description", text = CostSummary },
        {
            type = "button",
            name = "Clear measurements",
            tooltip = "Goes back to the known costs and measures again from the next attack.",
            func = function() ClearMeasuredCosts(nil) end,
            width = "half",
        },
        { type = "header", name = "Diagnostics" },
        {
            type = "checkbox",
            name = "Show events in chat",
            tooltip = "Writes to chat every time Overload turns on or off and every bit of ultimate spent.",
            getFunc = function() return state.verbose end,
            setFunc = function(value) state.verbose = value end,
            default = false,
        },
        {
            type = "button",
            name = "Diagnostics in chat",
            tooltip = "Same as /overload test.",
            func = Diagnose,
            width = "half",
        },
    })
end

-- Startup -----------------------------------------------------------------------------------------------------------

local function OnAddOnLoaded(_, addonName)
    if addonName ~= NAME then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    sv = ZO_SavedVars:NewAccountWide("IsOverloadOn_Saved", 1, nil, DEFAULTS)
    if not OFF_MODES[sv.showOff] then
        sv.showOff = DEFAULTS.showOff
    end
    sv.attackCost = sv.attackCost or {}
    -- Up to 1.5.0 the position was the center of a fixed-width box (346 wide at size 1); now it is the left edge.
    if sv.left == nil then
        sv.left = sv.x and (sv.x - zo_round(346 * sv.size / 2)) or DEFAULT_LEFT
        sv.x = nil
    end
    CreateUI()
    Layout()
    ui.frame:SetHidden(true)
    ApplyLock()
    -- Freeing or capturing the mouse cursor shows or hides the alert for positioning.
    HUD_UI_SCENE:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING or newState == SCENE_HIDING then
            Render()
        end
    end)
    RegisterEvents()
    CreateSettingsMenu()
    SLASH_COMMANDS["/overload"] = OnSlashCommand
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
