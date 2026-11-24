-- Last Rites 1.0.14
local NAME, TITLE, VERSION = "LastRites", "Last Rites", "1.0.14"
local CAPACITY, HISTORY_LIMIT = 30, 10
local CAPTURE_WINDOWS = {["5 seconds"] = 5000, ["10 seconds"] = 10000,
    ["15 seconds"] = 15000, ["20 seconds"] = 20000, ["30 seconds"] = 30000}
local PAGE_SIZE, SCENE_NAME = 7, "LastRitesHistory"
local JOURNAL_ICON = "EsoUI/Art/TreeIcons/Gamepad/gp_tutorial_idexIcon_combat.dds"
local saved, scene, recap, rowPool, liveKeys, journalKeys, livePrompt
local latestDeath, latestSaved, refreshLive
local view, restoreNative, reviewLatest
local journalSortIndex = 1
local JOURNAL_SORTS = {
    {sources = "One timeline", order = "Chronological", label = "Timeline / Time"},
    {sources = "One timeline", order = "By skill", label = "Timeline / Skill"},
    {sources = "By attacker", order = "Chronological", label = "Attacker / Time"},
    {sources = "By attacker", order = "By skill", label = "Attacker / Skill"},
}
local journalEntryInstalled = false
local deathIndex, pageIndex = 1, 1
local ring, first, count = {}, 1, 0
local lastDroppedTime
local observedPlayers, siegeAbilities = {}, {}
local pending
local filters = {
    {"Direct", "Direct damage"}, {"DoT", "Damage over time"},
    {"Blocked", "Blocked damage"}, {"Shielded", "Shielded damage"},
    {"Heal", "Healing received"}, {"Absorbed", "Absorbed damage"}, {"Environment", "Environmental damage"},
    {"Physical", "Physical"}, {"Magic", "Magic"}, {"Fire", "Fire"},
    {"Cold", "Frost"}, {"Shock", "Shock"}, {"Poison", "Poison"},
    {"Disease", "Disease"}, {"Bleed", "Bleed"}, {"Oblivion", "Oblivion"},
    {"Earth", "Earth"}, {"Drown", "Drowning"}, {"Generic", "Generic"},
    {"Unknown", "Unknown element"},
}
local defaults = {mode = "Both", captureWindow = "30 seconds", reopenRecap = true, sources = "One timeline", order = "Chronological", filters = {}, deaths = {}}
for _, filter in ipairs(filters) do defaults.filters[filter[1]] = true end

local results, elements = {}, {}
local function Map(target, value, ...)
    for index = 1, select("#", ...) do
        local key = select(index, ...)
        if key ~= nil then target[key] = value end
    end
end

Map(results, "Direct", ACTION_RESULT_DAMAGE, ACTION_RESULT_CRITICAL_DAMAGE,
    ACTION_RESULT_PRECISE_DAMAGE, ACTION_RESULT_WRECKING_DAMAGE)
Map(results, "DoT", ACTION_RESULT_DOT_TICK, ACTION_RESULT_DOT_TICK_CRITICAL)
Map(results, "Heal", ACTION_RESULT_HEAL, ACTION_RESULT_CRITICAL_HEAL,
    ACTION_RESULT_HOT_TICK, ACTION_RESULT_HOT_TICK_CRITICAL)
Map(results, "Blocked", ACTION_RESULT_BLOCKED_DAMAGE)
Map(results, "Shielded", ACTION_RESULT_DAMAGE_SHIELDED)
Map(results, "Absorbed", ACTION_RESULT_ABSORBED)
Map(results, "Environment", ACTION_RESULT_FALL_DAMAGE, ACTION_RESULT_KILLED_BY_SUBZONE)
Map(elements, "Physical", DAMAGE_TYPE_PHYSICAL)
Map(elements, "Magic", DAMAGE_TYPE_MAGIC)
Map(elements, "Fire", DAMAGE_TYPE_FIRE)
Map(elements, "Cold", DAMAGE_TYPE_COLD)
Map(elements, "Shock", DAMAGE_TYPE_SHOCK)
Map(elements, "Poison", DAMAGE_TYPE_POISON)
Map(elements, "Disease", DAMAGE_TYPE_DISEASE)
Map(elements, "Bleed", DAMAGE_TYPE_BLEED)
Map(elements, "Oblivion", DAMAGE_TYPE_OBLIVION)
Map(elements, "Earth", DAMAGE_TYPE_EARTH)
Map(elements, "Drown", DAMAGE_TYPE_DROWN)
Map(elements, "Generic", DAMAGE_TYPE_GENERIC)

local function CleanName(name)
    return (name or ""):gsub("%^.*$", "")
end

local function IsPvP()
    return IsInAvAZone() or IsInImperialCity() or IsActiveWorldBattleground()
        or GetCurrentBattlegroundId() > 0 or GetDuelInfo() == DUEL_STATE_DUELING
end

local function CaptureEnabled(pvp)
    return saved.mode == "Both" or saved.mode == (pvp and "PvP" or "PvE")
end

local function ReopenDeathRecap(pvp)
    if saved.reopenRecap and CaptureEnabled(pvp) and DEATH_RECAP and not DEATH_RECAP:IsWindowOpen() then
        DEATH_RECAP:SetWindowOpen(true)
    end
end

local function SyncDeathRecap()
    ReopenDeathRecap(IsPvP())
end

local function MarkSettingsDirty()
    if ZO_IsConsoleOrGameCoreUI() and AUTO_SAVING then AUTO_SAVING:MarkDirty() end
end

local function ResetCapture()
    ring, first, count = {}, 1, 0
    lastDroppedTime = nil
end

local function TrimCapture(now)
    local cutoff = now - (CAPTURE_WINDOWS[saved.captureWindow] or 30000)
    while count > 0 and ring[first].time < cutoff do
        ring[first] = nil
        first = first % CAPACITY + 1
        count = count - 1
    end
    return cutoff
end

local function RememberPlayer(unitTag)
    if not IsUnitPlayer(unitTag) then return end
    local name = CleanName(GetUnitName(unitTag))
    local display = CleanName(GetUnitDisplayName(unitTag))
    local now = GetGameTimeMilliseconds()
    local identity = {time = now, display = display}
    if name ~= "" then observedPlayers[name] = identity end
    if display ~= "" then observedPlayers[display] = identity end
end

local function IsSiege(abilityId, ability)
    if not abilityId or abilityId == 0 then return false end
    if siegeAbilities[abilityId] == nil then
        local art = string.lower(GetAbilityIcon(abilityId) or "")
        local name = string.lower(ability)
        siegeAbilities[abilityId] = art:find("siege", 1, true) ~= nil
            or name:find("ballista", 1, true) ~= nil
            or name:find("trebuchet", 1, true) ~= nil
            or name:find("catapult", 1, true) ~= nil
            or name:find("oil pot", 1, true) ~= nil
            or name:find("boiling oil", 1, true) ~= nil
            or name:find("burning oil", 1, true) ~= nil
    end
    return siegeAbilities[abilityId]
end

local function OnCombat(_, result, isError, ability, _, slot, source, sourceType,
    _, targetType, damage, _, damageType, _, sourceId, targetId, abilityId)
    local kind = results[result]
    if isError or not kind or targetType ~= COMBAT_UNIT_TYPE_PLAYER
        or saved.mode == "Off" or pending or (damage <= 0 and kind ~= "Environment") then return end
    -- Fall and lethal terrain can be reported as damage from the player to itself.
    local ownSource = sourceType == COMBAT_UNIT_TYPE_PLAYER
        or sourceType == COMBAT_UNIT_TYPE_PLAYER_PET
        or sourceType == COMBAT_UNIT_TYPE_PLAYER_COMPANION
        or (sourceId and sourceId > 0 and sourceId == targetId)
    if ownSource and kind ~= "Environment" and kind ~= "Heal" then return end
    local now = GetGameTimeMilliseconds()
    local pvp = IsPvP()
    if not CaptureEnabled(pvp) then return end
    source = CleanName(source)
    ability = ability or ""
    if ability == "" and abilityId and abilityId > 0 then ability = GetAbilityName(abilityId) end
    if not ability or ability == "" then ability = kind == "Environment" and "Environment" or "Unknown ability" end
    local duel, opponent, opponentDisplay
    if pvp then duel, opponent, opponentDisplay = GetDuelInfo() end
    local selfCast = sourceType == COMBAT_UNIT_TYPE_PLAYER or (sourceId and sourceId > 0 and sourceId == targetId)
    local player = selfCast or sourceType == COMBAT_UNIT_TYPE_GROUP
        or (sourceType == COMBAT_UNIT_TYPE_OTHER and IsDecoratedDisplayName(source))
        or (duel == DUEL_STATE_DUELING and source ~= ""
            and (source == CleanName(opponent) or source == CleanName(opponentDisplay)))
    local health, maxHealth = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_HEALTH)
    local physicalResist = GetPlayerStat(STAT_PHYSICAL_RESIST, STAT_BONUS_OPTION_APPLY_BONUS)
    local spellResist = GetPlayerStat(STAT_SPELL_RESIST, STAT_BONUS_OPTION_APPLY_BONUS)
    TrimCapture(now)
    local position = (first + count - 1) % CAPACITY + 1
    if count == CAPACITY then lastDroppedTime = ring[position].time end
    ring[position] = {
        time = now, pvp = pvp, name = source, sourceId = sourceId, ability = ability,
        kind = kind, element = elements[damageType] or "Unknown", amount = damage,
        player = player, displayName = selfCast and CleanName(GetUnitDisplayName("player")) or nil,
        siege = pvp and (IsInAvAZone() or IsInImperialCity()) and IsSiege(abilityId, ability),
        critical = result == ACTION_RESULT_CRITICAL_DAMAGE or result == ACTION_RESULT_DOT_TICK_CRITICAL
            or result == ACTION_RESULT_CRITICAL_HEAL or result == ACTION_RESULT_HOT_TICK_CRITICAL,
        slot = slot, abilityId = abilityId,
        health = health, maxHealth = maxHealth, physicalResist = physicalResist, spellResist = spellResist,
        eligible = not ownSource,
    }
    if count == CAPACITY then
        first = first % CAPACITY + 1
    else
        count = count + 1
    end
end

local function FinishDeath()
    local death = pending
    if not death then return end
    pending = nil
    local players = {}
    for index = 1, GetNumKillingAttacks() do
        local raw, _, _, _, player, _, _, minion, display, platform = GetKillingAttackerInfo(index)
        if player and (not minion or minion == "") then
            raw, display, platform = CleanName(raw), CleanName(display), CleanName(platform)
            local identity = {display = platform ~= "" and platform or display}
            if raw ~= "" then players[raw] = identity end
            if display ~= "" then players[display] = identity end
            if platform ~= "" then players[platform] = identity end
        end
    end
    local accepted = {}
    for _, hit in ipairs(death.hits) do
        local observed = observedPlayers[hit.name]
        if observed and math.abs(observed.time - hit.time) > 30000 then observed = nil end
        local known = players[hit.name] or observed
        if hit.kind == "Heal" or not death.pvp or (hit.eligible and (hit.siege or hit.player or known)) then
            local native = players[hit.name]
            local display = hit.displayName
            if (not display or display == "") and native then display = native.display end
            if (not display or display == "") and observed then display = observed.display end
            if display and display ~= "" then
                hit.displayName = display
            elseif IsDecoratedDisplayName(hit.name) then
                hit.displayName = hit.name
            elseif hit.player or known then
                hit.displayName = nil
                hit.name = ""
                hit.unknownPlayer = true
            end
            hit.age = death.time - hit.time
            hit.time, hit.pvp, hit.eligible, hit.player = nil, nil, nil, nil
            accepted[#accepted + 1] = hit
        else
            death.excluded = death.excluded + 1
        end
    end
    death.hits, death.time = accepted, nil
    latestDeath, latestSaved = death, false
    if refreshLive then refreshLive() end
end

local function OnDeath()
    if pending then return end
    latestDeath, latestSaved = nil, false
    if saved.mode == "Off" then return end
    local now = GetGameTimeMilliseconds()
    local pvp = IsPvP() or IsDuelingDeath()
    if not CaptureEnabled(pvp) then
        ResetCapture()
        return
    end
    ReopenDeathRecap(pvp)
    local cutoff = TrimCapture(now)
    pending = {
        time = now, date = GetDateStringFromTimestamp(GetTimeStamp()), clock = GetTimeString(),
        zone = GetUnitZone("player"), character = CleanName(GetUnitName("player")), pvp = pvp, hits = {}, excluded = 0, full = lastDroppedTime ~= nil and lastDroppedTime >= cutoff,
    }
    for offset = 0, count - 1 do
        local hit = ring[(first + offset - 1) % CAPACITY + 1]
        if hit.pvp == pvp then
            pending.hits[#pending.hits + 1] = hit
        end
    end
    ResetCapture()
    local thisDeath = pending
    zo_callLater(function()
        if pending == thisDeath then FinishDeath() end
    end, 2000)
end

local function Bucket(list, index, key, name)
    if not index[key] then
        local group = {heading = name}
        index[key] = group
        list[#list + 1] = group
    end
    return index[key]
end

local function SourceLabel(hit)
    local name = hit.displayName or hit.name
    if name ~= "" then return hit.siege and name .. " [Siege]" or name end
    if hit.siege then return "Siege" end
    return hit.unknownPlayer and "Unknown player" or "Unknown source"
end

local function BuildRows(death, sourceMode, order)
    local rows, sources, sourceKeys = {}, {}, {}
    if sourceMode ~= "By attacker" then sources[1] = {} end
    for _, hit in ipairs(death.hits) do
        if saved.filters[hit.kind] and (hit.kind == "Heal" or saved.filters[hit.element]) then
            local key = hit.displayName or hit.name
            if key == "" then key = hit.sourceId and hit.sourceId > 0 and hit.sourceId or SourceLabel(hit) end
            local group = sources[1]
            if sourceMode == "By attacker" then
                local heading = SourceLabel(hit)
                group = Bucket(sources, sourceKeys, key, heading)
            end
            group[#group + 1] = hit
        end
    end
    for _, group in ipairs(sources) do
        if group.heading then rows[#rows + 1] = {heading = group.heading} end
        if order == "By skill" then
            local skills, skillKeys = {}, {}
            for _, hit in ipairs(group) do
                local key, name = hit.ability, hit.ability
                if hit.slot == ACTION_SLOT_TYPE_LIGHT_ATTACK then key, name = "light", "Light attacks"
                elseif hit.slot == ACTION_SLOT_TYPE_HEAVY_ATTACK then key, name = "heavy", "Heavy attacks" end
                local skill = Bucket(skills, skillKeys, key, name)
                skill[#skill + 1] = hit
            end
            for _, skill in ipairs(skills) do
                rows[#rows + 1] = {heading = "  " .. skill.heading}
                for _, hit in ipairs(skill) do rows[#rows + 1] = hit end
            end
        else
            for _, hit in ipairs(group) do rows[#rows + 1] = hit end
        end
    end
    return rows
end

local pageCount = 1
local liveLayer = GetString(SI_KEYBINDINGS_LAYER_USER_INTERFACE_SHORTCUTS)
local liveLayerOwned = false
local liveStripScene
local FALLBACK_ICON = "EsoUI/Art/Icons/icon_missing.dds"

local function RestoreRecap()
    if not restoreNative then return end
    rowPool:ReleaseAllObjects()
    restoreNative()
    restoreNative = nil
    view = nil
end

local function StartRecap(mode)
    RestoreRecap()
    local scroll = recap.scrollControl
    local title = scroll:GetNamedChild("Title")
    local status = scroll:GetNamedChild("AttacksHeader")
    local titleText, statusText = title:GetText(), status:GetText()
    local hiddenStates = {}
    local function Hide(control)
        hiddenStates[control] = control:IsHidden()
        control:SetHidden(true)
    end
    Hide(recap.difficultyLabel)
    Hide(recap.killingBlowIcon)
    if mode ~= "live" then
        Hide(scroll:GetNamedChild("HintsContainer"))
        Hide(recap.telvarStoneLossControl)
    end
    for _, row in pairs(recap.attackPool:GetActiveObjects()) do Hide(row) end
    restoreNative = function()
        title:SetText(titleText)
        status:SetText(statusText)
        for control, hidden in pairs(hiddenStates) do control:SetHidden(hidden) end
    end
    view = mode
end

local function RecapAmountColor(kind)
    if kind == "Heal" then return 0.55, 1, 0.56 end
    if kind == "Shielded" or kind == "Absorbed" then return 0.65, 0.87, 1 end
    return 1, 0.44, 0.44
end

local function RecapAmountLabel(kind)
    if kind == "Heal" then return "HEAL" end
    if kind == "Shielded" then return "SHLD" end
    if kind == "Absorbed" then return "ABS" end
    return GetString(SI_DEATH_RECAP_DAMAGE_LABEL)
end

local function FormatHitSnapshot(hit)
    if hit.maxHealth == nil or hit.health == nil
        or hit.physicalResist == nil or hit.spellResist == nil then return "" end
    local healthColor = "FFD700"
    if hit.health < hit.maxHealth then
        if hit.kind == "Heal" then
            healthColor = "8CFF8F"
        elseif hit.kind == "Shielded" or hit.kind == "Absorbed" then
            healthColor = "A6DEFF"
        else
            healthColor = "FF7070"
        end
    end
    local function Number(value)
        return zo_strformat(SI_NUMBER_FORMAT, value)
    end
    return string.format("HP: |c%s%s|r / |cFFD700%s|r  |  Resistances: Physical %s  Spell %s",
        healthColor, Number(hit.health), Number(hit.maxHealth), Number(hit.physicalResist), Number(hit.spellResist))
end

local function FormatHitAmount(hit)
    local prefix = "-"
    if hit.kind == "Heal" then
        prefix = "+"
    elseif hit.kind == "Shielded" or hit.kind == "Absorbed" then
        prefix = ""
    end
    return prefix .. zo_strformat(SI_NUMBER_FORMAT, hit.amount)
end

local renderGeneration = 0
local function Refresh()
    if not view then return end
    local death
    if view == "journal" then death = saved.deaths[deathIndex]
    else death = latestDeath end
    local sorting = view == "journal" and JOURNAL_SORTS[journalSortIndex] or saved
    local rows = death and BuildRows(death, sorting.sources, sorting.order) or {}
    local pageSize = view == "latest" and PAGE_SIZE or math.max(1, #rows)
    pageCount = math.max(1, math.ceil(#rows / pageSize))
    pageIndex = math.min(pageIndex, pageCount)

    local scroll = recap.scrollControl
    scroll:GetNamedChild("Title"):SetText(view == "live" and GetString(SI_DEATH_RECAP_TITLE) or TITLE)
    local status = view == "journal" and "No deaths saved yet" or "No captured death"
    if death then
        local context
        if view == "journal" then
            context = string.format("%d/%d  |  %s %s", deathIndex, #saved.deaths, death.date, death.clock)
        elseif view == "live" then
            context = latestSaved and "Saved to Journal" or "Current death"
        else
            context = latestSaved and "Saved to Journal" or "Last death  |  " .. death.clock
        end
        status = string.format("%s  |  %s", context, death.pvp and "PvP" or "PvE")
        if view == "latest" then status = status .. string.format("  |  Page %d/%d", pageIndex, pageCount) end
        if death.full then status = status .. "  |  Buffer full" end
        if #rows == 0 then status = status .. "  |  No matching hits" end
    end
    scroll:GetNamedChild("AttacksHeader"):SetText(status)

    rowPool:ReleaseAllObjects()
    local parent = scroll:GetNamedChild("Attacks")
    local previous
    local function RenderRow(index)
        local hit = rows[(pageIndex - 1) * pageSize + index]
        if not hit then return end
        local row = rowPool:AcquireObject()
        row:SetHidden(false)
        local card = row.lastRitesCard
        local heading = hit.heading ~= nil
        local snapshot = heading and "" or FormatHitSnapshot(hit)
        row:SetHeight(heading and 42 or (snapshot == "" and 96 or 124))
        card.source:SetText(heading and hit.heading or SourceLabel(hit))
        card.time:SetHidden(heading)
        card.amount:SetHidden(heading)
        card.skill:SetHidden(heading)
        card.icon:SetHidden(heading)
        card.snapshot:SetHidden(snapshot == "")
        card.snapshot:SetText(snapshot)
        if not heading then
            local texture = hit.abilityId and hit.abilityId > 0 and GetAbilityIcon(hit.abilityId)
            card.icon:SetTexture(texture and texture ~= "" and texture or FALLBACK_ICON)
            card.time:SetText(string.format("-%.3fs", hit.age / 1000))
            local category = hit.kind == "Heal" and "Heal" or (hit.kind .. " / " .. hit.element)
            card.skill:SetText(string.format("%s |cCACDD0(%s%s)|r",
                string.upper(hit.ability), hit.critical and "Critical " or "", category))
            card.amount:SetText(FormatHitAmount(hit) .. " " .. RecapAmountLabel(hit.kind))
            local red, green, blue = RecapAmountColor(hit.kind)
            card.amount:SetColor(red, green, blue, 1)
        end
        row:ClearAnchors()
        row:SetAnchor(TOPLEFT, previous or parent, previous and BOTTOMLEFT or TOPLEFT, 0, previous and 10 or 0)
        previous = row
    end
    renderGeneration = renderGeneration + 1
    local generation = renderGeneration
    local function RenderBatch(firstRow)
        if generation ~= renderGeneration or not view then return end
        local lastRow = math.min(pageSize, firstRow + 15)
        for index = firstRow, lastRow do RenderRow(index) end
        if lastRow < pageSize then
            zo_callLater(function() RenderBatch(lastRow + 1) end, 0)
        end
    end
    RenderBatch(1)
    ZO_Scroll_ResetToTop(recap.scrollContainer)
end

local function NavigateDeath(offset)
    if view ~= "journal" then return end
    deathIndex = math.max(1, math.min(#saved.deaths, deathIndex + offset))
    pageIndex = 1
    Refresh()
end

local function NavigatePage(offset)
    pageIndex = math.max(1, math.min(pageCount, pageIndex + offset))
    Refresh()
end

local function CycleJournalSort()
    if view ~= "journal" or #saved.deaths == 0 then return end
    journalSortIndex = journalSortIndex % #JOURNAL_SORTS + 1
    pageIndex = 1
    Refresh()
    KEYBIND_STRIP:UpdateKeybindButtonGroup(journalKeys)
end

local function CanSaveDeath()
    return latestDeath ~= nil and not latestSaved
        and (view == "latest" or (view == "live" and IsUnitDead("player")))
end

local function SaveDeath()
    if not CanSaveDeath() then return end
    latestSaved = true
    table.insert(saved.deaths, 1, latestDeath)
    if #saved.deaths > HISTORY_LIMIT then table.remove(saved.deaths) end
    MarkSettingsDirty()
    Refresh()
    livePrompt:SetHidden(true)
    KEYBIND_STRIP:UpdateKeybindButtonGroup(view == "live" and liveKeys or journalKeys)
end

local function StopLive()
    if view ~= "live" then return end
    KEYBIND_STRIP:RemoveKeybindButtonGroup(liveKeys)
    livePrompt:SetHidden(true)
    if liveStripScene then
        liveStripScene:RemoveTemporaryFragment(KEYBIND_STRIP_GAMEPAD_FRAGMENT)
        liveStripScene = nil
    end
    if liveLayerOwned then
        RemoveActionLayerByName(liveLayer)
        liveLayerOwned = false
    end
    RestoreRecap()
end

local function CreateViewer()
    recap = DEATH_RECAP
    local parent = recap.scrollControl:GetNamedChild("Attacks")
    local cardId = 0
    rowPool = ZO_ObjectPool:New(function()
        cardId = cardId + 1
        local prefix = NAME .. "Card" .. cardId
        local row = WINDOW_MANAGER:CreateControl(prefix, parent, CT_BACKDROP)
        row:SetWidth(704)
        row:SetCenterColor(0.045, 0.055, 0.065, 0.94)
        row:SetEdgeTexture("EsoUI/Art/Miscellaneous/Gamepad/gp_toolTip_edge_semiTrans_16.dds", 128, 16, 8, 0)
        row:SetEdgeColor(0.58, 0.62, 0.66, 0.85)

        local function Label(suffix, x, y, width, font, alignment, lines)
            local label = WINDOW_MANAGER:CreateControl(prefix .. suffix, row, CT_LABEL)
            label:SetAnchor(TOPLEFT, row, TOPLEFT, x, y)
            label:SetWidth(width)
            label:SetFont(font)
            label:SetHorizontalAlignment(alignment)
            label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
            label:SetMaxLineCount(lines or 1)
            return label
        end

        local icon = WINDOW_MANAGER:CreateControl(prefix .. "Icon", row, CT_TEXTURE)
        icon:SetDimensions(46, 46)
        icon:SetAnchor(TOPLEFT, row, TOPLEFT, 16, 39)
        row.lastRitesCard = {
            icon = icon,
            source = Label("Source", 72, 7, 242, "ZoFontGamepad27", TEXT_ALIGN_LEFT),
            time = Label("Time", 319, 6, 144, "ZoFontGamepad27", TEXT_ALIGN_CENTER),
            amount = Label("Amount", 470, 3, 217, "ZoFontGamepad34", TEXT_ALIGN_RIGHT),
            skill = Label("Skill", 72, 38, 615, "ZoFontGamepad27", TEXT_ALIGN_LEFT, 2),
            snapshot = Label("Snapshot", 72, 95, 615, "ZoFontGamepad22", TEXT_ALIGN_LEFT),
        }
        return row
    end, function(row)
        row:SetHidden(true)
        row:ClearAnchors()
    end)

    local saveBinding = "UI_SHORTCUT_QUATERNARY"
    livePrompt = WINDOW_MANAGER:CreateControlFromVirtual(NAME .. "SavePrompt", recap.control, "ZO_KeybindButton")
    ApplyTemplateToControl(livePrompt, ZO_GetPlatformTemplate("ZO_KeybindButton"))
    livePrompt:SetAnchor(TOPRIGHT, recap.control, TOPRIGHT, -20, -46)
    livePrompt:SetKeybind(saveBinding)
    livePrompt:SetText("Save to Journal")
    livePrompt:SetCallback(SaveDeath)
    livePrompt:SetHidden(true)

    local previousPage = {name = "Previous page", keybind = "UI_SHORTCUT_LEFT_TRIGGER", visible = function() return view == "latest" end, callback = function() NavigatePage(-1) end}
    local nextPage = {name = "Next page", keybind = "UI_SHORTCUT_RIGHT_TRIGGER", visible = function() return view == "latest" end, callback = function() NavigatePage(1) end}
    liveKeys = {
        {name = "Save to Journal", keybind = saveBinding, ethereal = true,
            visible = CanSaveDeath, callback = SaveDeath},
    }

    refreshLive = function()
        if not latestDeath or not IsUnitDead("player") or not DEATH_RECAP_FRAGMENT:IsShowing()
            or view == "journal" or view == "latest" then return end
        if view ~= "live" then
            pageIndex = 1
            StartRecap("live")
            if not IsActionLayerActiveByName(liveLayer) then
                PushActionLayerByName(liveLayer)
                liveLayerOwned = true
            end
            -- Even ethereal bindings require the native strip control to be visible.
            local hud = SCENE_MANAGER:GetCurrentScene()
            if hud and not hud:HasFragment(KEYBIND_STRIP_GAMEPAD_FRAGMENT) then
                liveStripScene = hud
                hud:AddTemporaryFragment(KEYBIND_STRIP_GAMEPAD_FRAGMENT)
            end
            KEYBIND_STRIP:AddKeybindButtonGroup(liveKeys)
        end
        Refresh()
        livePrompt:SetHidden(latestSaved)
    end

    ZO_PreHook(recap, "SetupAttacks", function()
        StopLive()
    end)
    SecurePostHook(recap, "SetupDeathRecap", function()
        refreshLive()
    end)

    DEATH_RECAP_FRAGMENT:RegisterCallback("StateChange", function(_, state)
        if state == SCENE_FRAGMENT_SHOWING then
            refreshLive()
        elseif state == SCENE_FRAGMENT_HIDING then
            StopLive()
        end
    end)

    journalKeys = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {name = "Newer death", keybind = "UI_SHORTCUT_LEFT_SHOULDER", visible = function() return view == "journal" end, callback = function() NavigateDeath(-1) end},
        {name = "Older death", keybind = "UI_SHORTCUT_RIGHT_SHOULDER", visible = function() return view == "journal" end, callback = function() NavigateDeath(1) end},
        previousPage, nextPage,
        {name = function() return "Sort: " .. JOURNAL_SORTS[journalSortIndex].label end,
            keybind = "UI_SHORTCUT_TERTIARY",
            visible = function() return view == "journal" and #saved.deaths > 0 end,
            callback = CycleJournalSort},
        {name = "Save to Journal", keybind = saveBinding, visible = CanSaveDeath, callback = SaveDeath},
    }
    ZO_Gamepad_AddBackNavigationKeybindDescriptors(journalKeys, GAME_NAVIGATION_TYPE_BUTTON)
    scene = ZO_Scene:New(SCENE_NAME, SCENE_MANAGER)
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    scene:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
    scene:AddFragment(ZO_SimpleSceneFragment:New(recap.control))
    scene:RegisterCallback("StateChange", function(_, state)
        if state == SCENE_SHOWING then
            StopLive()
            deathIndex, pageIndex = 1, 1
            for index, sorting in ipairs(JOURNAL_SORTS) do
                if sorting.sources == saved.sources and sorting.order == saved.order then
                    journalSortIndex = index
                    break
                end
            end
            StartRecap(reviewLatest and "latest" or "journal")
            reviewLatest = false
            Refresh()
            KEYBIND_STRIP:AddKeybindButtonGroup(journalKeys)
        elseif state == SCENE_HIDING then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(journalKeys)
        elseif state == SCENE_HIDDEN then
            RestoreRecap()
            refreshLive()
        end
    end)
end

local function OpenHistory()
    if not scene or SCENE_MANAGER:GetCurrentSceneName() == SCENE_NAME then return end
    SCENE_MANAGER:Push(SCENE_NAME)
end

local function ReviewLatest()
    if not scene or SCENE_MANAGER:GetCurrentSceneName() == SCENE_NAME then return end
    if not latestDeath then
        d("[Last Rites] No death has been captured in this session.")
        return
    end
    reviewLatest = true
    OpenHistory()
end

local function InstallJournalEntry()
    if not scene and DEATH_RECAP and DEATH_RECAP_FRAGMENT then CreateViewer() end
    if journalEntryInstalled or not scene or not ZO_MENU_ENTRIES or not ZO_MENU_MAIN_ENTRIES
        or not MAIN_MENU_GAMEPAD then return end

    for _, journal in ipairs(ZO_MENU_ENTRIES) do
        if journal.id == ZO_MENU_MAIN_ENTRIES.JOURNAL and journal.subMenu then
            local entry = ZO_GamepadEntryData:New(TITLE, JOURNAL_ICON)
            entry:SetIconTintOnSelection(true)
            entry.data = {name = TITLE, icon = JOURNAL_ICON, scene = SCENE_NAME}
            entry.id = NAME
            table.insert(journal.subMenu, entry)
            journalEntryInstalled = true
            MAIN_MENU_GAMEPAD:UpdateEntryEnabledStates()
            return
        end
    end
end

local function ApplyMode(mode)
    if saved.mode == mode then return end
    ResetCapture()
    if mode == "Off" then
        pending, latestDeath, latestSaved = nil, nil, false
        StopLive()
    end
    saved.mode = mode
    MarkSettingsDirty()
    SyncDeathRecap()
end

local function RegisterSettings()
    local library = LibHarvensAddonSettings
    if not library then return end
    local panel = library:AddAddon(TITLE, {allowDefaults = true, allowRefresh = true})
    if not panel then return end
    local function Dropdown(label, key, choices, onChange)
        local items = {}
        for index, choice in ipairs(choices) do items[index] = {name = choice, data = choice} end
        panel:AddSetting({
            type = library.ST_DROPDOWN, label = label, items = items, default = defaults[key],
            getFunction = function()
                for _, item in ipairs(items) do
                    if item.data == saved[key] then
                        if ZO_IsConsoleOrGameCoreUI() then return item end
                        return item.name
                    end
                end
                if ZO_IsConsoleOrGameCoreUI() then return items[1] end
                return items[1].name
            end,
            setFunction = function(controlOrValue, itemName, itemData)
                local function Choice(value)
                    if type(value) == "table" then value = value.data or value.name end
                    for _, item in ipairs(items) do
                        if value == item.data then return value end
                    end
                end
                local value = Choice(itemData) or Choice(itemName) or Choice(controlOrValue)
                if value then onChange(value) end
            end,
        })
    end
    panel:AddSetting({type = library.ST_LABEL, label = "Version " .. VERSION .. " | Account-wide"})
    panel:AddSetting({type = library.ST_BUTTON, label = "Open death history", buttonText = "Open", clickHandler = OpenHistory})
    Dropdown("Capture mode", "mode", {"Off", "PvP", "PvE", "Both"}, ApplyMode)
    panel:AddSetting({
        type = library.ST_CHECKBOX,
        label = "Reopen Death Recap automatically",
        tooltip = "Reopen ESO's Death Recap in content allowed by your capture mode. Turn off to use ESO's own visibility setting.",
        default = defaults.reopenRecap,
        getFunction = function() return saved.reopenRecap end,
        setFunction = function(value)
            saved.reopenRecap = value
            MarkSettingsDirty()
            SyncDeathRecap()
        end,
    })
    Dropdown("Recap time window", "captureWindow",
        {"5 seconds", "10 seconds", "15 seconds", "20 seconds", "30 seconds"}, function(value)
            saved.captureWindow = value
            TrimCapture(GetGameTimeMilliseconds())
            MarkSettingsDirty()
        end)
    Dropdown("Group incoming damage", "sources", {"One timeline", "By attacker"}, function(value) saved.sources = value end)
    Dropdown("Order within each list", "order", {"Chronological", "By skill"}, function(value) saved.order = value end)
    panel:AddSetting({type = library.ST_SECTION, subMenu = false, label = "Damage filters"})
    for _, filter in ipairs(filters) do
        local key = filter[1]
        panel:AddSetting({
            type = library.ST_CHECKBOX, label = filter[2], default = true,
            getFunction = function() return saved.filters[key] end,
            setFunction = function(value) saved.filters[key] = value end,
        })
    end
    panel:AddSetting({type = library.ST_LABEL, label = "Inspired by AlternateDeathRecap by Shienar"})
    panel:AddSetting({
        type = library.ST_SECTION, subMenu = false,
        label = "|cFFD700Built on tea, toast and ADHD - tested live on PS5.|r\n|cB427D3Su|c546D6Aga|c889764Co|cDA34CDma|r",
    })
    panel:AddSetting({
        type = library.ST_LABEL, label = "Contact",
        tooltip = "Found an error or need to contact me about Last Rites?\n\nPlayStation User / PSN: SugaComa\nEmail: eso.addons@rik-sprint.co.uk or use the contact form at www.rik-sprint.co.uk/contact",
    })
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= NAME then return end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    saved = ZO_SavedVars:NewAccountWide("LastRites_SV", 1, nil, defaults)
    RegisterSettings()
    SLASH_COMMANDS["/lastrites"] = ReviewLatest
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_COMBAT_EVENT, OnCombat)
    EVENT_MANAGER:AddFilterForEvent(NAME, EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_DEAD, OnDeath)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ALIVE, function()
        FinishDeath()
        StopLive()
        ResetCapture()
        observedPlayers = {}
    end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_DEACTIVATED, function()
        FinishDeath()
        StopLive()
        ResetCapture()
        observedPlayers = {}
    end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, function()
        InstallJournalEntry()
        SyncDeathRecap()
    end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ZONE_CHANGED, function(_, _, _, newSubzone)
        if not newSubzone then SyncDeathRecap() end
    end)
    InstallJournalEntry()
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_RETICLE_TARGET_CHANGED, function()
        if CaptureEnabled(IsPvP()) then RememberPlayer("reticleover") end
    end)
end)
