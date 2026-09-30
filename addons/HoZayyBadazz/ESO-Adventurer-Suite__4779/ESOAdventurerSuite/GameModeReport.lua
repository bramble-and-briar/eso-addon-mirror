-- ESO Adventurer Suite
-- Copyright (c) 2026 HoZayyBadazz. All Rights Reserved.
-- Proprietary source. Unauthorized redistribution, republication, rebranding,
-- or public distribution of modified/derivative versions is prohibited.
-- Private personal-use modifications are permitted. See LICENSE.txt.
-- Hotkey-driven combat report for every ESO game mode.

ESOProgressionCoach = ESOProgressionCoach or {}
local EPC = ESOProgressionCoach
EPC.GameModeReport = EPC.GameModeReport or {}
local R = EPC.GameModeReport

local wm = WINDOW_MANAGER
local PREFIX = (EPC.name or "EAS") .. "_GameModeReport"
local GOLD = { 0.96, 0.72, 0.22, 1.00 }
local TEXT = { 0.94, 0.95, 0.97, 1.00 }
local MUTED = { 0.62, 0.67, 0.74, 1.00 }
local GREEN = { 0.34, 0.88, 0.34, 1.00 }
local CYAN = { 0.24, 0.78, 0.96, 1.00 }
local RED = { 0.96, 0.30, 0.24, 1.00 }
local PURPLE = { 0.74, 0.38, 0.94, 1.00 }
local PANEL = { 0.018, 0.023, 0.034, 0.965 }
local PANEL_ALT = { 0.035, 0.043, 0.060, 0.94 }
local EDGE = { 0.20, 0.25, 0.33, 0.90 }
local WHITE_TEXTURE = "EsoUI/Art/Miscellaneous/white.dds"
local DEFAULT_ICON = "EsoUI/Art/MainMenu/menubar_character_up.dds"
local SINGLE_LINE_WRAP = TEXT_WRAP_MODE_ELLIPSIS or TEXT_WRAP_MODE_TRUNCATE

local MODE_ICONS = {
    OVERLAND = "EsoUI/Art/MainMenu/menubar_map_up.dds",
    DUNGEON = "EsoUI/Art/MainMenu/menubar_group_up.dds",
    TRIAL = "EsoUI/Art/MainMenu/menubar_group_up.dds",
    ARENA = "EsoUI/Art/MainMenu/menubar_achievements_up.dds",
    ARCHIVE = "EsoUI/Art/Journal/journal_tabIcon_cadwell_up.dds",
    BATTLEGROUND = "EsoUI/Art/MainMenu/menubar_ava_up.dds",
    PVP = "EsoUI/Art/MainMenu/menubar_ava_up.dds",
}

-- 0.29.118: CMX-inspired Suite-native report navigation.  The buttons are
-- deliberately short so the rail remains readable at the report's minimum
-- width; the selected page title is shown by the active panel(s).
local PAGE_DEFS = {
    { key = "OVERVIEW", short = "OVR", label = "Overview" },
    { key = "DAMAGE", short = "DMG", label = "Damage" },
    { key = "TARGETS", short = "TGT", label = "Targets" },
    { key = "HEALING", short = "HEAL", label = "Healing" },
    { key = "INCOMING", short = "IN", label = "Incoming" },
    { key = "GROUP", short = "GRP", label = "Group" },
    { key = "BUFFS", short = "BUFF", label = "Buffs" },
    { key = "RESOURCES", short = "RES", label = "Resources" },
    { key = "GRAPH", short = "GRPH", label = "Graph" },
    { key = "BUILD", short = "BLD", label = "Build" },
}

local PAGE_LABELS = {}
for _, page in ipairs(PAGE_DEFS) do PAGE_LABELS[page.key] = page.label end

local KNOWN_ARENAS = {
    ["dragonstar arena"] = true, ["maelstrom arena"] = true,
    ["blackrose prison"] = true, ["vateshran hollows"] = true,
}

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local values = { pcall(fn, ...) }
    if not values[1] then return fallback end
    table.remove(values, 1)
    return unpack(values)
end

local function clamp(value, low, high)
    value = tonumber(value) or low
    if value < low then return low end
    if value > high then return high end
    return value
end

local function stripGrammarSuffixes(value)
    value = tostring(value or "")
    -- ESO unit/monster names can contain grammar markers such as ^n, ^m, or ^f.
    -- They are useful to the localization formatter but should never be shown
    -- literally in the combat report (for example "Clannfear^n").
    value = value:gsub("%^%a+", "")
    return value
end

local function clean(value)
    value = tostring(value or "")
    if value ~= "" and type(zo_strformat) == "function" then
        local ok, formatted = pcall(zo_strformat, "<<C:1>>", value)
        if ok and formatted and formatted ~= "" then value = formatted end
    end
    return stripGrammarSuffixes(value)
end

local function cleanName(value)
    local result = clean(value)
    result = result:gsub("^%s+", ""):gsub("%s+$", "")
    return result ~= "" and result or "Unknown"
end

local function lower(value) return string.lower(clean(value)) end

local function epoch()
    return tonumber(safe(GetTimeStamp, 0)) or tonumber(safe(GetTimeStamp32, 0)) or 0
end

local function frameSeconds()
    return tonumber(safe(GetFrameTimeSeconds, 0)) or 0
end

local function number(value) return tonumber(value) or 0 end

local function formatNumber(value)
    local n = math.floor(math.abs(number(value)) + 0.5)
    local sign = number(value) < 0 and "-" or ""
    local digits = tostring(n)
    local parts = {}
    while #digits > 3 do
        table.insert(parts, 1, string.sub(digits, -3))
        digits = string.sub(digits, 1, -4)
    end
    table.insert(parts, 1, digits)
    return sign .. table.concat(parts, ",")
end

local function formatDuration(seconds)
    seconds = math.max(0, math.floor(number(seconds) + 0.5))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local remaining = seconds % 60
    if hours > 0 then return string.format("%d:%02d:%02d", hours, minutes, remaining) end
    return string.format("%d:%02d", minutes, remaining)
end

local function formatPercent(value) return string.format("%.1f%%", number(value)) end

local function createBackdrop(name, parent, centerColor, edgeColor)
    local control = wm:CreateControl(name, parent, CT_BACKDROP)
    control:SetCenterColor(unpack(centerColor or PANEL))
    control:SetEdgeColor(unpack(edgeColor or EDGE))
    control:SetEdgeTexture("EsoUI/Art/Tooltips/UI-SliderBackdrop.dds", 1, 1, 1)
    return control
end

local function createLabel(name, parent, text, font, color, alignment)
    local control = wm:CreateControl(name, parent, CT_LABEL)
    control:SetFont(font or "ZoFontGame")
    control:SetColor(unpack(color or TEXT))
    control:SetText(tostring(text or ""))
    control:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    -- Report cells are intentionally one line. At minimum size/UI scale, ESO
    -- otherwise lets text wrap or draw beyond the cell and collide with the
    -- next row/column. Ellipsis keeps every label inside its assigned box.
    if control.SetWrapMode and SINGLE_LINE_WRAP then control:SetWrapMode(SINGLE_LINE_WRAP) end
    if control.SetMaxLineCount then control:SetMaxLineCount(1) end
    if alignment then control:SetHorizontalAlignment(alignment) end
    return control
end

local function createValueLabel(name, parent, font, color, alignment)
    local control = createLabel(name, parent, "", font or "ZoFontGameSmall", color or TEXT, alignment or TEXT_ALIGN_RIGHT)
    control:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return control
end

local function createSectionLabel(parent, text, color)
    local control = createLabel(nil, parent, text, "ZoFontGameBold", color or GOLD)
    control:SetHeight(18)
    return control
end

local function createButton(name, parent, text, callback)
    -- Report children are intentionally anonymous. They are kept by direct Lua
    -- references and never need global ESO control names. This prevents a stale
    -- report instance from causing Duplicate name errors after reload/update.
    local background = createBackdrop(nil, parent, { 0.10, 0.115, 0.15, 0.98 }, { 0.42, 0.48, 0.58, 0.94 })
    local button = wm:CreateControl(nil, background, CT_BUTTON)
    button:SetAnchorFill(background)
    button:SetFont("ZoFontGameBold")
    button:SetNormalFontColor(unpack(TEXT))
    button:SetMouseOverFontColor(unpack(GOLD))
    button:SetPressedFontColor(1, 1, 1, 1)
    button:SetText(text)
    button:SetHandler("OnClicked", callback)
    return button, background
end

local function zoneName()
    local name = clean(safe(GetUnitZone, "", "player"))
    if name ~= "" then return name end
    local index = tonumber(safe(GetUnitZoneIndex, 0, "player")) or 0
    if index > 0 and type(GetZoneId) == "function" and type(GetZoneNameById) == "function" then
        local zoneId = tonumber(safe(GetZoneId, 0, index)) or 0
        if zoneId > 0 then return clean(safe(GetZoneNameById, "", zoneId)) end
    end
    return "Unknown Location"
end

function R:GetModeInfo()
    local zone = zoneName()
    local name = lower(zone)
    if type(IsUnitInBattleground) == "function" and safe(IsUnitInBattleground, false, "player") == true then
        return "BATTLEGROUND", "BATTLEGROUND", zone
    end
    if name:find("infinite archive", 1, true) or name:find("endless archive", 1, true) then
        return "ARCHIVE", "INFINITE ARCHIVE", zone
    end
    if KNOWN_ARENAS[name] or name:find(" arena", 1, true) or name:find("arena ", 1, true) then
        return "ARENA", "ARENA", zone
    end
    if safe(IsUnitInDungeon, false, "player") == true then
        local size = tonumber(safe(GetGroupSize, 0)) or 0
        if size >= 8 then return "TRIAL", "TRIAL", zone end
        return "DUNGEON", "DUNGEON", zone
    end
    if safe(IsActiveWorldBattleground, false) == true or safe(IsPlayerInAvAWorld, false) == true
        or name:find("cyrodiil", 1, true) or name:find("imperial city", 1, true) then
        return "PVP", "ALLIANCE WAR", zone
    end
    return "OVERLAND", "OVERLAND", zone
end

function R:GetDifficulty()
    local value = safe(GetCurrentZoneDungeonDifficulty, nil)
    if DUNGEON_DIFFICULTY_VETERAN ~= nil and value == DUNGEON_DIFFICULTY_VETERAN then return "VETERAN" end
    if DUNGEON_DIFFICULTY_NORMAL ~= nil and value == DUNGEON_DIFFICULTY_NORMAL then return "NORMAL" end
    return "STANDARD"
end

local function readPower(powerType)
    if powerType == nil then return 0, 0 end
    local current, maximum = safe(GetUnitPower, 0, "player", powerType)
    return number(current), number(maximum)
end

local function readStat(stat)
    if stat == nil or type(GetPlayerStat) ~= "function" then return 0 end
    local bonus = STAT_BONUS_OPTION_APPLY_BONUS or STAT_BONUS_OPTION_DONT_APPLY_BONUS or 0
    return number(safe(GetPlayerStat, 0, stat, bonus))
end

function R:CaptureStats()
    local health, healthMax = readPower(POWERTYPE_HEALTH)
    local magicka, magickaMax = readPower(POWERTYPE_MAGICKA)
    local stamina, staminaMax = readPower(POWERTYPE_STAMINA)
    local ultimate, ultimateMax = readPower(POWERTYPE_ULTIMATE)
    local criticalRating = math.max(readStat(STAT_SPELL_CRITICAL), readStat(STAT_CRITICAL_STRIKE), readStat(STAT_CRITICAL_CHANCE))
    local criticalChance = type(GetCriticalStrikeChance) == "function" and number(safe(GetCriticalStrikeChance, 0, criticalRating)) or criticalRating
    local damage = readStat(STAT_WEAPON_AND_SPELL_DAMAGE)
    if damage <= 0 then damage = math.max(readStat(STAT_ATTACK_POWER), readStat(STAT_SPELL_POWER)) end
    local stats = {
        health = health, healthMax = healthMax,
        magicka = magicka, magickaMax = magickaMax,
        stamina = stamina, staminaMax = staminaMax,
        ultimate = ultimate, ultimateMax = ultimateMax,
        damage = damage,
        criticalChance = criticalChance,
        penetration = math.max(readStat(STAT_PHYSICAL_PENETRATION), readStat(STAT_SPELL_PENETRATION), readStat(STAT_OFFENSIVE_PENETRATION)),
        physicalResistance = readStat(STAT_PHYSICAL_RESIST),
        spellResistance = readStat(STAT_SPELL_RESIST),
        magickaRegen = readStat(STAT_MAGICKA_REGEN_COMBAT),
        staminaRegen = readStat(STAT_STAMINA_REGEN_COMBAT),
    }

    -- Use the exact same stat reader as the visible Live Combat Stats frame.
    -- This prevents Game Combat and the overlay from disagreeing because one
    -- path used derived stats while the other used ESO's Advanced Stats API.
    if EPC.UnitFrames and type(EPC.UnitFrames.GetCombatStatsSnapshot) == "function" then
        local ok, live = pcall(EPC.UnitFrames.GetCombatStatsSnapshot, EPC.UnitFrames, false)
        if ok and type(live) == "table" then
            stats.damage = number(live.power)
            stats.criticalChance = live.criticalChance ~= nil and number(live.criticalChance) or stats.criticalChance
            stats.criticalDamage = live.criticalDamage ~= nil and number(live.criticalDamage) or nil
            stats.penetration = number(live.penetration)
            stats.physicalResistance = number(live.physicalResistance)
            stats.spellResistance = number(live.spellResistance)
        end
    end
    return stats
end

function R:CaptureBuffs()
    local buffs = {}
    local count = tonumber(safe(GetNumBuffs, 0, "player")) or 0
    local now = frameSeconds()
    for index = 1, count do
        local name, started, ending, _, stacks, icon, _, effectType, _, _, abilityId = safe(GetUnitBuffInfo, nil, "player", index)
        if name and name ~= "" then
            local remaining = math.max(0, number(ending) - now)
            local duration = math.max(0, number(ending) - number(started))
            local isDebuff = BUFF_EFFECT_TYPE_DEBUFF ~= nil and effectType == BUFF_EFFECT_TYPE_DEBUFF
            buffs[#buffs + 1] = {
                name = clean(name), icon = tostring(icon or ""), stacks = number(stacks),
                remaining = remaining, duration = duration, abilityId = number(abilityId), debuff = isDebuff,
            }
        end
    end
    table.sort(buffs, function(left, right)
        if left.debuff ~= right.debuff then return left.debuff == true end
        if left.remaining ~= right.remaining then return left.remaining < right.remaining end
        return left.name < right.name
    end)
    while #buffs > 18 do table.remove(buffs) end
    return buffs
end

local function copyRows(rows, limit)
    local copied = {}
    for index = 1, math.min(#(rows or {}), limit or 20) do
        local source = rows[index]
        if type(source) == "table" then
            local row = {}
            for key, value in pairs(source) do
                local kind = type(value)
                if kind == "string" or kind == "number" or kind == "boolean" then row[key] = value end
            end
            copied[#copied + 1] = row
        end
    end
    return copied
end

function R:BuildReport(fight, live)
    if type(fight) ~= "table" then return nil end
    local modeKey, modeLabel, zone = self:GetModeInfo()
    local stats = self:CaptureStats()
    local effective = type(fight.combatStats) == "table" and fight.combatStats or nil
    if effective then
        stats.damage = number(effective.power)
        stats.penetration = number(effective.penetration)
        stats.physicalResistance = number(effective.physicalResistance)
        stats.spellResistance = number(effective.spellResistance)
        if effective.criticalChance ~= nil then stats.criticalChance = number(effective.criticalChance) end
        if effective.criticalDamage ~= nil then stats.criticalDamage = number(effective.criticalDamage) end
        stats.combatStatSamples = number(effective.samples)
        stats.effective = true
    end
    local resources = type(fight.resources) == "table" and fight.resources or {}
    local magickaUse = type(resources.magicka) == "table" and resources.magicka or {}
    local staminaUse = type(resources.stamina) == "table" and resources.stamina or {}
    stats.magickaSpent = number(magickaUse.spent)
    stats.magickaGained = number(magickaUse.gained)
    stats.magickaSpentPerSecond = number(magickaUse.spentPerSecond)
    stats.magickaGainedPerSecond = number(magickaUse.gainedPerSecond)
    stats.staminaSpent = number(staminaUse.spent)
    stats.staminaGained = number(staminaUse.gained)
    stats.staminaSpentPerSecond = number(staminaUse.spentPerSecond)
    stats.staminaGainedPerSecond = number(staminaUse.gainedPerSecond)
    local trackedEffects = copyRows(fight.effects or {}, 30)
    local bossMechanics = nil
    if type(fight.bossMechanics) == "table" then
        bossMechanics = {}
        for key, value in pairs(fight.bossMechanics) do
            local kind = type(value)
            if kind == "string" or kind == "number" or kind == "boolean" then bossMechanics[key] = value end
        end
        bossMechanics.seen = copyRows(fight.bossMechanics.seen or {}, 10)
    elseif live == true and EPC.BossMechanicsAssistant and EPC.BossMechanicsAssistant.GetLiveSummary then
        local liveSummary = EPC.BossMechanicsAssistant:GetLiveSummary()
        if type(liveSummary) == "table" then
            bossMechanics = {}
            for key, value in pairs(liveSummary) do
                local kind = type(value)
                if kind == "string" or kind == "number" or kind == "boolean" then bossMechanics[key] = value end
            end
            bossMechanics.seen = copyRows(liveSummary.seen or {}, 10)
        end
    end
    local report = {
        live = live == true,
        modeKey = modeKey, modeLabel = modeLabel, zone = zone,
        difficulty = self:GetDifficulty(),
        character = clean(safe(GetUnitName, "Player", "player")),
        capturedAt = epoch(),
        duration = number(fight.duration),
        totalDamage = number(fight.totalDamage), dps = number(fight.dps),
        directDamage = number(fight.directDamage), dotDamage = number(fight.dotDamage),
        petDamage = number(fight.petDamage), petDps = number(fight.petDps),
        companionDamage = number(fight.companionDamage), companionDps = number(fight.companionDps),
        combinedDamage = number(fight.combinedDamage), combinedDps = number(fight.combinedDps),
        hits = number(fight.hits), criticalHits = number(fight.criticalHits), criticalEventPercent = number(fight.criticalEventPercent),
        totalHealing = number(fight.totalHealing), hps = number(fight.hps),
        petHealing = number(fight.petHealing), companionHealing = number(fight.companionHealing), combinedHealing = number(fight.combinedHealing),
        healEvents = number(fight.healEvents), criticalHeals = number(fight.criticalHeals), criticalHealPercent = number(fight.criticalHealPercent),
        incomingDamage = number(fight.incomingDamage), dtps = number(fight.dtps),
        incomingHits = number(fight.incomingHits), blockedHits = number(fight.blockedHits), blockPercent = number(fight.blockPercent),
        targetCount = number(fight.targetCount),
        abilities = copyRows(fight.abilities, 30),
        targets = copyRows(fight.targets, 18),
        contributors = copyRows(fight.contributors, 18),
        actors = copyRows(fight.actors, 24),
        incomingSources = copyRows(fight.incomingSources, 18),
        stats = stats, buffs = #trackedEffects > 0 and trackedEffects or self:CaptureBuffs(),
        bossMechanics = bossMechanics,
    }
    for _, ability in ipairs(report.abilities) do
        ability.percent = report.totalDamage > 0 and (number(ability.damage) / report.totalDamage * 100) or 0
        ability.dps = report.duration > 0 and (number(ability.damage) / report.duration) or 0
        ability.critPercent = number(ability.hits) > 0 and (number(ability.criticalHits) / number(ability.hits) * 100) or 0
    end
    return report
end

function R:EnsureSaved()
    if not EPC.saved then return nil end
    if type(EPC.saved.gameModeReports) ~= "table" then EPC.saved.gameModeReports = {} end
    return EPC.saved.gameModeReports
end

function R:OnFightEnded(fight)
    local reports = self:EnsureSaved()
    if not reports or EPC.saved.gameModeReportEnabled == false then return end
    local report = self:BuildReport(fight, false)
    if not report then return end
    reports[#reports + 1] = report
    while #reports > 30 do table.remove(reports, 1) end
    if self.window and not self.window:IsHidden() then self.viewIndex = 1 self:Refresh() end
end

function R:GetAvailableReports()
    local available = {}
    local combat = EPC.Combat
    if combat and combat.current and type(combat.GetDisplayFight) == "function" then
        local live = self:BuildReport(combat:GetDisplayFight(), true)
        if live then available[#available + 1] = live end
    end
    local reports = self:EnsureSaved() or {}
    for index = #reports, 1, -1 do available[#available + 1] = reports[index] end
    if #available == 0 and combat and type(combat.GetLastFight) == "function" then
        local fallback = self:BuildReport(combat:GetLastFight(), false)
        if fallback then available[#available + 1] = fallback end
    end
    return available
end

function R:CreatePanel(name, title)
    local panel = createBackdrop(nil, self.window, PANEL, EDGE)
    -- 0.29.119: compact analyzer panels use a left-aligned section heading
    -- and a small gold marker instead of a large centered card title.
    local accent = wm:CreateControl(nil, panel, CT_TEXTURE)
    accent:SetTexture(WHITE_TEXTURE)
    accent:SetColor(unpack(GOLD))
    accent:SetAnchor(TOPLEFT, panel, TOPLEFT, 8, 6)
    accent:SetDimensions(3, 15)
    panel.accent = accent

    panel.title = createLabel(nil, panel, title, "ZoFontGameBold", GOLD, TEXT_ALIGN_LEFT)
    panel.title:SetAnchor(TOPLEFT, panel, TOPLEFT, 16, 2)
    panel.title:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -8, 2)
    panel.title:SetHeight(23)
    panel.title:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

    local rule = wm:CreateControl(nil, panel, CT_TEXTURE)
    rule:SetTexture(WHITE_TEXTURE)
    rule:SetColor(0.28, 0.33, 0.42, 0.52)
    rule:SetAnchor(TOPLEFT, panel, TOPLEFT, 8, 27)
    rule:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -8, 27)
    rule:SetHeight(1)
    panel.rule = rule
    return panel
end

function R:CreateTableRow(parent, name, index, hasIcon)
    local row = wm:CreateControl(nil, parent, CT_CONTROL)
    local bar = wm:CreateControl(nil, row, CT_TEXTURE)
    bar:SetTexture(WHITE_TEXTURE)
    bar:SetColor(0.12, 0.34, 0.18, 0.70)
    bar:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 1)
    bar:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, 0, -1)
    row.bar = bar
    if hasIcon then
        local icon = wm:CreateControl(nil, row, CT_TEXTURE)
        icon:SetAnchor(LEFT, row, LEFT, 2, 0)
        icon:SetDimensions(20, 20)
        icon:SetTexture(DEFAULT_ICON)
        row.icon = icon
    end
    local label = createLabel(nil, row, "", "ZoFontGameSmall", TEXT)
    label:SetAnchor(LEFT, row, LEFT, hasIcon and 27 or 5, 0)
    label:SetAnchor(RIGHT, row, RIGHT, -5, 0)
    label:SetHeight(22)
    row.label = label
    row:SetHidden(true)
    return row
end

function R:CreateStatRow(parent)
    local row = wm:CreateControl(nil, parent, CT_CONTROL)
    row.name = createLabel(nil, row, "", "ZoFontGameSmall", MUTED)
    row.name:SetAnchor(LEFT, row, LEFT, 0, 0)
    row.name:SetWidth(150)
    row.value = createValueLabel(nil, row, "ZoFontGameSmall", TEXT, TEXT_ALIGN_RIGHT)
    row.value:SetAnchor(RIGHT, row, RIGHT, 0, 0)
    row.value:SetWidth(96)
    row:SetHidden(true)
    return row
end

function R:CreateBuffRow(parent)
    local row = wm:CreateControl(nil, parent, CT_CONTROL)
    local bar = wm:CreateControl(nil, row, CT_TEXTURE)
    bar:SetTexture(WHITE_TEXTURE)
    bar:SetColor(0.06, 0.38, 0.12, 0.76)
    bar:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 1)
    bar:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, 0, -1)
    row.bar = bar
    row.icon = wm:CreateControl(nil, row, CT_TEXTURE)
    row.icon:SetAnchor(LEFT, row, LEFT, 2, 0)
    row.icon:SetDimensions(20, 20)
    row.icon:SetTexture(DEFAULT_ICON)
    row.name = createLabel(nil, row, "", "ZoFontGameSmall", TEXT)
    row.name:SetAnchor(LEFT, row, LEFT, 27, 0)
    row.name:SetWidth(180)
    row.stacks = createValueLabel(nil, row, "ZoFontGameSmall", MUTED, TEXT_ALIGN_CENTER)
    row.stacks:SetAnchor(LEFT, row.name, RIGHT, 4, 0)
    row.stacks:SetWidth(42)
    row.time = createValueLabel(nil, row, "ZoFontGameSmall", TEXT, TEXT_ALIGN_RIGHT)
    row.time:SetAnchor(RIGHT, row, RIGHT, -4, 0)
    row.time:SetWidth(64)
    row:SetHidden(true)
    return row
end

function R:CreateTargetRow(parent)
    local row = wm:CreateControl(nil, parent, CT_CONTROL)
    row.bar = wm:CreateControl(nil, row, CT_TEXTURE)
    row.bar:SetTexture(WHITE_TEXTURE)
    row.bar:SetColor(0.08, 0.22, 0.38, 0.72)
    row.bar:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 1)
    row.bar:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, 0, -1)
    row.kind = createLabel(nil, row, "", "ZoFontGameSmall", GOLD)
    row.kind:SetAnchor(LEFT, row, LEFT, 4, 0)
    row.kind:SetWidth(62)
    row.name = createLabel(nil, row, "", "ZoFontGameSmall", TEXT)
    row.name:SetAnchor(LEFT, row.kind, RIGHT, 6, 0)
    row.name:SetWidth(122)
    row.dps = createValueLabel(nil, row, "ZoFontGameSmall", CYAN, TEXT_ALIGN_RIGHT)
    row.dps:SetAnchor(LEFT, row.name, RIGHT, 6, 0)
    row.dps:SetWidth(66)
    row.hps = createValueLabel(nil, row, "ZoFontGameSmall", GREEN, TEXT_ALIGN_RIGHT)
    row.hps:SetAnchor(LEFT, row.dps, RIGHT, 6, 0)
    row.hps:SetWidth(62)
    row.extra = createValueLabel(nil, row, "ZoFontGameSmall", TEXT, TEXT_ALIGN_RIGHT)
    row.extra:SetAnchor(RIGHT, row, RIGHT, -4, 0)
    row.extra:SetWidth(70)
    row:SetHidden(true)
    return row
end

function R:CreateAbilityRow(parent)
    local row = wm:CreateControl(nil, parent, CT_CONTROL)
    row.bar = wm:CreateControl(nil, row, CT_TEXTURE)
    row.bar:SetTexture(WHITE_TEXTURE)
    row.bar:SetColor(0.12, 0.34, 0.18, 0.70)
    row.bar:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 1)
    row.bar:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, 0, -1)
    row.icon = wm:CreateControl(nil, row, CT_TEXTURE)
    row.icon:SetAnchor(LEFT, row, LEFT, 2, 0)
    row.icon:SetDimensions(20, 20)
    row.icon:SetTexture(DEFAULT_ICON)
    row.name = createLabel(nil, row, "", "ZoFontGameSmall", TEXT)
    row.name:SetAnchor(LEFT, row, LEFT, 27, 0)
    row.name:SetWidth(188)
    row.percent = createValueLabel(nil, row, "ZoFontGameSmall", MUTED, TEXT_ALIGN_RIGHT)
    row.percent:SetAnchor(LEFT, row.name, RIGHT, 4, 0)
    row.percent:SetWidth(44)
    row.dps = createValueLabel(nil, row, "ZoFontGameSmall", CYAN, TEXT_ALIGN_RIGHT)
    row.dps:SetAnchor(LEFT, row.percent, RIGHT, 8, 0)
    row.dps:SetWidth(58)
    row.damage = createValueLabel(nil, row, "ZoFontGameSmall", TEXT, TEXT_ALIGN_RIGHT)
    row.damage:SetAnchor(LEFT, row.dps, RIGHT, 8, 0)
    row.damage:SetWidth(72)
    row.crit = createValueLabel(nil, row, "ZoFontGameSmall", MUTED, TEXT_ALIGN_RIGHT)
    row.crit:SetAnchor(LEFT, row.damage, RIGHT, 8, 0)
    row.crit:SetWidth(74)
    row.max = createValueLabel(nil, row, "ZoFontGameSmall", TEXT, TEXT_ALIGN_RIGHT)
    row.max:SetAnchor(RIGHT, row, RIGHT, -4, 0)
    row.max:SetWidth(70)
    row:SetHidden(true)
    return row
end

function R:CreateGraphRow(parent)
    local row = wm:CreateControl(nil, parent, CT_CONTROL)
    row.bar = wm:CreateControl(nil, row, CT_TEXTURE)
    row.bar:SetTexture(WHITE_TEXTURE)
    row.bar:SetColor(0.16, 0.42, 0.62, 0.74)
    row.bar:SetAnchor(TOPLEFT, row, TOPLEFT, 2, 3)
    row.bar:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, 2, -3)
    row.name = createLabel(nil, row, "", "ZoFontGameSmall", TEXT)
    row.name:SetAnchor(LEFT, row, LEFT, 10, 0)
    row.value = createValueLabel(nil, row, "ZoFontGameSmall", TEXT, TEXT_ALIGN_RIGHT)
    row.value:SetAnchor(RIGHT, row, RIGHT, -8, 0)
    row.value:SetWidth(170)
    row:SetHidden(true)
    return row
end


function R:CreateTargetHeader(parent)
    local row = wm:CreateControl(nil, parent, CT_CONTROL)
    row.kind = createLabel(nil, row, "Type", "ZoFontGameSmall", MUTED)
    row.kind:SetAnchor(LEFT, row, LEFT, 4, 0)
    row.kind:SetWidth(62)
    row.name = createLabel(nil, row, "Name", "ZoFontGameSmall", MUTED)
    row.name:SetAnchor(LEFT, row.kind, RIGHT, 6, 0)
    row.name:SetWidth(122)
    row.dps = createValueLabel(nil, row, "ZoFontGameSmall", MUTED, TEXT_ALIGN_RIGHT)
    row.dps:SetText("DPS")
    row.dps:SetAnchor(LEFT, row.name, RIGHT, 6, 0)
    row.dps:SetWidth(66)
    row.hps = createValueLabel(nil, row, "ZoFontGameSmall", MUTED, TEXT_ALIGN_RIGHT)
    row.hps:SetText("HPS/DMG")
    row.hps:SetAnchor(LEFT, row.dps, RIGHT, 6, 0)
    row.hps:SetWidth(62)
    row.extra = createValueLabel(nil, row, "ZoFontGameSmall", MUTED, TEXT_ALIGN_RIGHT)
    row.extra:SetText("Score")
    row.extra:SetAnchor(RIGHT, row, RIGHT, -4, 0)
    row.extra:SetWidth(70)
    return row
end

function R:CreateAbilityHeader(parent)
    local row = wm:CreateControl(nil, parent, CT_CONTROL)
    row.name = createLabel(nil, row, "Ability", "ZoFontGameSmall", MUTED)
    row.name:SetAnchor(LEFT, row, LEFT, 27, 0)
    row.name:SetWidth(188)
    row.percent = createValueLabel(nil, row, "ZoFontGameSmall", MUTED, TEXT_ALIGN_RIGHT)
    row.percent:SetText("Share")
    row.percent:SetAnchor(LEFT, row.name, RIGHT, 4, 0)
    row.percent:SetWidth(44)
    row.dps = createValueLabel(nil, row, "ZoFontGameSmall", MUTED, TEXT_ALIGN_RIGHT)
    row.dps:SetText("DPS")
    row.dps:SetAnchor(LEFT, row.percent, RIGHT, 8, 0)
    row.dps:SetWidth(58)
    row.damage = createValueLabel(nil, row, "ZoFontGameSmall", MUTED, TEXT_ALIGN_RIGHT)
    row.damage:SetText("Damage")
    row.damage:SetAnchor(LEFT, row.dps, RIGHT, 8, 0)
    row.damage:SetWidth(72)
    row.crit = createValueLabel(nil, row, "ZoFontGameSmall", MUTED, TEXT_ALIGN_RIGHT)
    row.crit:SetText("Crit/Hits")
    row.crit:SetAnchor(LEFT, row.damage, RIGHT, 8, 0)
    row.crit:SetWidth(74)
    row.max = createValueLabel(nil, row, "ZoFontGameSmall", MUTED, TEXT_ALIGN_RIGHT)
    row.max:SetText("Max")
    row.max:SetAnchor(RIGHT, row, RIGHT, -4, 0)
    row.max:SetWidth(70)
    return row
end

function R:LayoutTargetColumns(row, header)
    if not row then return end
    local width = math.max(260, number(row:GetWidth()))
    local height = math.max(18, number(row:GetHeight()))
    local margin, gap = 4, 4
    local kindW, dpsW, hpsW, extraW = 56, 58, 66, 62
    local fixed = margin * 2 + kindW + dpsW + hpsW + extraW + (gap * 4)
    local nameW = math.max(82, width - fixed)
    -- If the row is exceptionally narrow, shave the flexible columns first.
    if fixed + nameW > width then
        nameW = math.max(70, width - fixed)
    end

    local x = margin
    local function place(control, w, alignment)
        if not control then return end
        control:ClearAnchors()
        control:SetAnchor(TOPLEFT, row, TOPLEFT, x, 0)
        control:SetDimensions(w, height)
        if alignment then control:SetHorizontalAlignment(alignment) end
        x = x + w + gap
    end

    place(row.kind, kindW, header and TEXT_ALIGN_CENTER or TEXT_ALIGN_LEFT)
    place(row.name, nameW, header and TEXT_ALIGN_CENTER or TEXT_ALIGN_LEFT)
    place(row.dps, dpsW, header and TEXT_ALIGN_CENTER or TEXT_ALIGN_RIGHT)
    place(row.hps, hpsW, header and TEXT_ALIGN_CENTER or TEXT_ALIGN_RIGHT)
    -- Score/Share is the final column. Anchor its box by the same calculated X
    -- as the header instead of independently pinning it to the right edge.
    if row.extra then
        row.extra:ClearAnchors()
        row.extra:SetAnchor(TOPLEFT, row, TOPLEFT, x, 0)
        row.extra:SetDimensions(math.max(48, width - x - margin), height)
        row.extra:SetHorizontalAlignment(header and TEXT_ALIGN_CENTER or TEXT_ALIGN_RIGHT)
    end
end

function R:LayoutAbilityColumns(row, header)
    if not row then return end
    local width = math.max(360, number(row:GetWidth()))
    local height = math.max(18, number(row:GetHeight()))
    local margin, gap, iconSpace = 4, 4, 27
    local shareW, dpsW, damageW, critW, maxW = 54, 54, 72, 76, 70
    local minimumName = 118
    -- Compact Overview can give TOP DAMAGE a narrower column than the full DMG
    -- page. Shrink numeric columns before the ability name so headers and values
    -- never draw past the panel edge.
    if width < 500 then
        gap, iconSpace = 3, 24
        shareW, dpsW, damageW, critW, maxW = 44, 48, 64, 64, 58
        minimumName = 90
    end
    if width < 430 then
        shareW, dpsW, damageW, critW, maxW = 42, 44, 58, 58, 52
        minimumName = 82
    end
    local fixed = margin * 2 + iconSpace + shareW + dpsW + damageW + critW + maxW + (gap * 5)
    local nameW = math.max(minimumName, width - fixed)
    if fixed + nameW > width then
        nameW = math.max(70, width - fixed)
    end

    local x = margin + iconSpace
    local function place(control, w, alignment)
        if not control then return end
        control:ClearAnchors()
        control:SetAnchor(TOPLEFT, row, TOPLEFT, x, 0)
        control:SetDimensions(w, height)
        if alignment then control:SetHorizontalAlignment(alignment) end
        x = x + w + gap
    end

    place(row.name, nameW, header and TEXT_ALIGN_CENTER or TEXT_ALIGN_LEFT)
    place(row.percent, shareW, header and TEXT_ALIGN_CENTER or TEXT_ALIGN_RIGHT)
    place(row.dps, dpsW, header and TEXT_ALIGN_CENTER or TEXT_ALIGN_RIGHT)
    place(row.damage, damageW, header and TEXT_ALIGN_CENTER or TEXT_ALIGN_RIGHT)
    place(row.crit, critW, header and TEXT_ALIGN_CENTER or TEXT_ALIGN_RIGHT)
    if row.max then
        row.max:ClearAnchors()
        row.max:SetAnchor(TOPLEFT, row, TOPLEFT, x, 0)
        row.max:SetDimensions(math.max(54, width - x - margin), height)
        row.max:SetHorizontalAlignment(header and TEXT_ALIGN_CENTER or TEXT_ALIGN_RIGHT)
    end
end


local UI_REFERENCE_FIELDS = {
    "window", "background", "header", "modeIcon", "modeLabel", "zoneLabel", "titleLabel",
    "previousButton", "previousBackground", "nextButton", "nextBackground", "closeButton", "closeBackground",
    "pageRail", "metricStrip", "summaryPanel", "summaryText", "statsPanel", "statsText", "buffsPanel", "targetsPanel",
    "abilitiesPanel", "graphPanel", "abilityHeader", "buffHeader", "targetHeader", "targetHeaderRow", "abilityHeaderRow", "footer",
}

function R:IsUIReady()
    if not self.window or not self.modeIcon or not self.modeLabel or not self.zoneLabel or not self.titleLabel then return false end
    if not self.summaryPanel or not self.summaryText or not self.statsPanel then return false end
    if not self.pageRail or not self.metricStrip or not self.buffsPanel or not self.targetsPanel or not self.abilitiesPanel or not self.graphPanel or not self.abilityHeader or not self.targetHeaderRow or not self.abilityHeaderRow or not self.footer then return false end
    if not self.previousButton or not self.nextButton or not self.closeButton then return false end
    if type(self.pageButtons) ~= "table" or type(self.metricCells) ~= "table" or type(self.summaryRows) ~= "table" or type(self.statsRows) ~= "table" or type(self.buffRows) ~= "table" or type(self.targetRows) ~= "table" or type(self.abilityRows) ~= "table" or type(self.graphRows) ~= "table" then return false end
    return #self.pageButtons == #PAGE_DEFS and #self.metricCells == 5 and #self.summaryRows == 18 and #self.statsRows == 13 and #self.buffRows > 0 and #self.targetRows > 0 and #self.abilityRows > 0 and #self.graphRows > 0
end

function R:DiscardIncompleteUI()
    if self.window and type(self.window.SetHidden) == "function" then pcall(self.window.SetHidden, self.window, true) end
    for _, field in ipairs(UI_REFERENCE_FIELDS) do self[field] = nil end
    self.pageButtons, self.metricCells, self.summaryRows, self.statsRows, self.buffRows, self.targetRows, self.abilityRows, self.graphRows = nil, nil, nil, nil, nil, nil, nil, nil
    self.currentReport = nil
end

function R:EnsureWindow()
    if self:IsUIReady() then return true end
    if self.window then self:DiscardIncompleteUI() end

    -- A partial UI can exist if initialization was interrupted. Build into a new
    -- collision-safe root and never let a failed rebuild reach Refresh().
    local lastError = nil
    for attempt = 1, 2 do
        local ok, result = pcall(self.CreateWindow, self)
        if ok and result ~= false and self:IsUIReady() then
            self.lastUIError = nil
            return true
        end
        if not ok then lastError = tostring(result or "unknown Lua error")
        elseif result == false then lastError = "CreateWindow returned false"
        else lastError = "one or more report controls were not created"
        end
        self:DiscardIncompleteUI()
    end

    self.lastUIError = lastError
    if EPC.Print then
        EPC:Print("Game Mode Combat Report UI could not be initialized" .. (lastError and (": " .. lastError) or "."))
    end
    return false
end

function R:CreateWindow()
    if self:IsUIReady() then return true end
    if not wm then return false end
    if self.window then self:DiscardIncompleteUI() end

    -- A named top-level ESO control can outlive the Lua reference that created
    -- it (for example after an addon update/re-init). Never assume self.window
    -- being nil means the global control name is free. Hide stale report roots
    -- and allocate a collision-safe root name for this instance.
    local baseName = "EAS_GameModeCombatReport"
    for index = 1, 32 do
        local staleName = index == 1 and baseName or (baseName .. "_" .. tostring(index))
        local stale = _G[staleName]
        if stale and type(stale.SetHidden) == "function" then pcall(stale.SetHidden, stale, true) end
    end

    local rootName = baseName
    local serial = 1
    while _G[rootName] ~= nil and serial < 100 do
        serial = serial + 1
        rootName = baseName .. "_" .. tostring(serial)
    end

    local ok, window = pcall(function() return wm:CreateTopLevelWindow(rootName) end)
    if not ok or not window then
        if EPC.Print then EPC:Print("Game Mode Combat Report could not create its UI window.") end
        return
    end
    self.controlRootName = rootName
    self.window = window

    window:SetDrawTier(DT_HIGH)
    window:SetDrawLayer(DL_CONTROLS)
    window:SetDrawLevel(220)
    window:SetClampedToScreen(true)
    window:SetMouseEnabled(true)
    if type(window.SetMovable) == "function" then window:SetMovable(true) end
    if type(window.SetResizable) == "function" then window:SetResizable(true) end
    -- 0.29.119: page-based content no longer needs the old oversized 1040x720
    -- minimum. The compact analyzer remains readable down to 760x500 because
    -- only the selected report view is laid out at one time.
    if window.SetDimensionConstraints then window:SetDimensionConstraints(760, 500, 1280, 900) end
    if window.SetResizeHandleSize then window:SetResizeHandleSize(24) end
    window:SetHidden(true)

    self.background = createBackdrop(nil, window, { 0.012, 0.014, 0.022, 0.98 }, { 0.78, 0.58, 0.18, 1.00 })
    self.background:SetAnchorFill(window)

    self.header = createBackdrop(nil, window, { 0.025, 0.027, 0.038, 0.99 }, { 0.36, 0.40, 0.48, 1.00 })
    self.header:SetAnchor(TOPLEFT, window, TOPLEFT, 4, 4)
    self.header:SetAnchor(TOPRIGHT, window, TOPRIGHT, -4, 4)
    self.header:SetHeight(42)
    self.header:SetMouseEnabled(true)
    self.header:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and type(window.StartMoving) == "function" then window:StartMoving() end
    end)
    self.header:SetHandler("OnMouseUp", function()
        if type(window.StopMovingOrResizing) == "function" then window:StopMovingOrResizing() end
        R:SavePlacement()
    end)

    self.modeIcon = wm:CreateControl(nil, self.header, CT_TEXTURE)
    self.modeIcon:SetAnchor(LEFT, self.header, LEFT, 9, 0)
    self.modeIcon:SetDimensions(28, 28)
    self.modeIcon:SetTexture(DEFAULT_ICON)
    self.modeIcon:SetColor(unpack(GOLD))
    self.modeLabel = createLabel(nil, self.header, "GAME MODE", "ZoFontGameBold", GOLD)
    self.modeLabel:SetAnchor(LEFT, self.modeIcon, RIGHT, 6, -8)
    self.modeLabel:SetDimensions(170, 18)
    self.zoneLabel = createLabel(nil, self.header, "", "ZoFontGameSmall", MUTED)
    self.zoneLabel:SetAnchor(LEFT, self.modeIcon, RIGHT, 6, 9)
    self.zoneLabel:SetDimensions(205, 16)

    self.titleLabel = createLabel(nil, self.header, "COMBAT • OVERVIEW", "ZoFontGameBold", TEXT, TEXT_ALIGN_CENTER)
    self.titleLabel:SetAnchor(CENTER, self.header, CENTER, 0, 0)
    self.titleLabel:SetDimensions(250, 24)

    self.previousButton, self.previousBackground = createButton("EAS_GameModeReportPrevious", self.header, "<", function() R:ShowOlder() end)
    self.previousBackground:SetAnchor(RIGHT, self.header, RIGHT, -104, 0)
    self.previousBackground:SetDimensions(28, 26)
    self.nextButton, self.nextBackground = createButton("EAS_GameModeReportNext", self.header, ">", function() R:ShowNewer() end)
    self.nextBackground:SetAnchor(RIGHT, self.header, RIGHT, -72, 0)
    self.nextBackground:SetDimensions(28, 26)
    self.closeButton, self.closeBackground = createButton("EAS_GameModeReportClose", self.header, "X", function() R:Hide() end)
    self.closeBackground:SetAnchor(RIGHT, self.header, RIGHT, -8, 0)
    self.closeBackground:SetDimensions(30, 26)

    self.currentPage = self.currentPage or "OVERVIEW"
    self.pageRail = createBackdrop(nil, window, { 0.018, 0.022, 0.032, 0.96 }, { 0.24, 0.29, 0.37, 0.96 })
    self.pageButtons = {}
    for index, page in ipairs(PAGE_DEFS) do
        local pageKey = page.key
        local pageLabel = page.label
        local button, background = createButton(nil, self.pageRail, page.short, function() R:SetPage(pageKey) end)
        button:SetFont("ZoFontGameSmall")
        button.easPageKey = page.key
        background.easPageKey = page.key
        button:SetHandler("OnMouseEnter", function(control)
            if type(ZO_Tooltips_ShowTextTooltip) == "function" then
                pcall(ZO_Tooltips_ShowTextTooltip, control, RIGHT, pageLabel)
            end
        end)
        button:SetHandler("OnMouseExit", function(control)
            if type(ZO_Tooltips_HideTextTooltip) == "function" then pcall(ZO_Tooltips_HideTextTooltip) end
        end)
        self.pageButtons[index] = { button = button, background = background, page = page }
    end

    -- Compact KPI strip: the fight's most useful numbers remain visible while
    -- the detailed page below changes. This replaces a lot of duplicated card
    -- chrome and is the main reason the report can now be much smaller.
    self.metricStrip = createBackdrop(nil, window, { 0.020, 0.026, 0.038, 0.97 }, { 0.18, 0.23, 0.31, 0.92 })
    self.metricCells = {}
    local metricDefs = {
        { key = "DPS", label = "PLAYER DPS", color = CYAN },
        { key = "ALL", label = "ALL DPS", color = GOLD },
        { key = "HPS", label = "HPS", color = GREEN },
        { key = "IN", label = "IN DPS", color = RED },
        { key = "TIME", label = "TIME", color = TEXT },
    }
    for index, def in ipairs(metricDefs) do
        local cell = wm:CreateControl(nil, self.metricStrip, CT_CONTROL)
        cell.caption = createLabel(nil, cell, def.label, "ZoFontGameSmall", MUTED, TEXT_ALIGN_CENTER)
        cell.caption:SetAnchor(TOPLEFT, cell, TOPLEFT, 3, 2)
        cell.caption:SetAnchor(TOPRIGHT, cell, TOPRIGHT, -3, 2)
        cell.caption:SetHeight(15)
        cell.value = createLabel(nil, cell, "--", "ZoFontGameBold", def.color, TEXT_ALIGN_CENTER)
        cell.value:SetAnchor(TOPLEFT, cell, TOPLEFT, 3, 16)
        cell.value:SetAnchor(BOTTOMRIGHT, cell, BOTTOMRIGHT, -3, -2)
        cell.key = def.key
        if index > 1 then
            cell.separator = wm:CreateControl(nil, cell, CT_TEXTURE)
            cell.separator:SetTexture(WHITE_TEXTURE)
            cell.separator:SetColor(0.24, 0.29, 0.37, 0.50)
            cell.separator:SetAnchor(TOPLEFT, cell, TOPLEFT, 0, 6)
            cell.separator:SetAnchor(BOTTOMLEFT, cell, BOTTOMLEFT, 0, -6)
            cell.separator:SetWidth(1)
        end
        self.metricCells[index] = cell
    end

    self.summaryPanel = self:CreatePanel("EAS_GameModeReportSummary", "PLAYER COMBAT")
    -- Render PLAYER COMBAT as individual fixed rows instead of one multiline
    -- label. A single constrained label could squeeze its final lines together
    -- at smaller report sizes/UI scales, making Healing / Incoming DPS /
    -- Blocked hits appear concatenated. Fixed rows guarantee one stat per line.
    self.summaryText = createLabel(nil, self.summaryPanel, "", "ZoFontGameSmall", TEXT)
    self.summaryText:SetHidden(true)
    self.summaryRows = {}
    for index = 1, 18 do
        local row = wm:CreateControl(nil, self.summaryPanel, CT_CONTROL)
        row.name = createLabel(nil, row, "", "ZoFontGameSmall", MUTED, TEXT_ALIGN_LEFT)
        row.value = createValueLabel(nil, row, "ZoFontGameSmall", TEXT, TEXT_ALIGN_RIGHT)
        row:SetHidden(true)
        self.summaryRows[index] = row
    end

    self.statsPanel = self:CreatePanel("EAS_GameModeReportStats", "RESOURCES & BUILD STATS")
    self.statsText = createLabel(nil, self.statsPanel, "", "ZoFontGameSmall", TEXT)
    self.statsText:SetHidden(true)
    self.statsRows = {}
    for index = 1, 13 do self.statsRows[index] = self:CreateStatRow(self.statsPanel) end

    self.buffsPanel = self:CreatePanel("EAS_GameModeReportBuffs", "BUFF / DEBUFF UPTIME")
    self.buffHeader = createLabel(nil, self.buffsPanel, "Effect                                  Stacks  Uptime", "ZoFontGameSmall", MUTED)
    self.buffHeader:SetAnchor(TOPLEFT, self.buffsPanel, TOPLEFT, 12, 32)
    self.buffHeader:SetHeight(18)
    self.buffRows = {}
    for index = 1, 14 do self.buffRows[index] = self:CreateBuffRow(self.buffsPanel) end

    self.targetsPanel = self:CreatePanel("EAS_GameModeReportTargets", "GROUP / COMPANIONS / PETS / TARGETS")
    self.targetHeader = createLabel(nil, self.targetsPanel, "", "ZoFontGameSmall", MUTED)
    self.targetHeader:SetHidden(true)
    self.targetHeaderRow = self:CreateTargetHeader(self.targetsPanel)
    self.targetHeaderRow:SetAnchor(TOPLEFT, self.targetsPanel, TOPLEFT, 10, 32)
    self.targetHeaderRow:SetHeight(18)
    self.targetRows = {}
    for index = 1, 12 do self.targetRows[index] = self:CreateTargetRow(self.targetsPanel) end

    self.abilitiesPanel = self:CreatePanel("EAS_GameModeReportAbilities", "ABILITY BREAKDOWN")
    self.abilityHeader = createLabel(nil, self.abilitiesPanel, "", "ZoFontGameSmall", MUTED)
    self.abilityHeader:SetHidden(true)
    self.abilityHeaderRow = self:CreateAbilityHeader(self.abilitiesPanel)
    self.abilityHeaderRow:SetAnchor(TOPLEFT, self.abilitiesPanel, TOPLEFT, 10, 32)
    self.abilityHeaderRow:SetHeight(18)
    self.abilityRows = {}
    for index = 1, 16 do self.abilityRows[index] = self:CreateAbilityRow(self.abilitiesPanel) end

    self.graphPanel = self:CreatePanel("EAS_GameModeReportGraph", "DAMAGE DISTRIBUTION")
    self.graphRows = {}
    for index = 1, 12 do self.graphRows[index] = self:CreateGraphRow(self.graphPanel) end

    self.footer = createLabel(nil, window, "", "ZoFontGameSmall", MUTED, TEXT_ALIGN_CENTER)
    self.footer:SetAnchor(BOTTOMLEFT, window, BOTTOMLEFT, 10, -5)
    self.footer:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -10, -5)
    self.footer:SetHeight(20)

    window:SetHandler("OnResizeStop", function() R:SavePlacement() R:ApplyLayout() end)
    self:RestorePlacement()
    self:ApplyLayout()
    return self:IsUIReady()
end

function R:SavePlacement()
    if not self.window or not EPC.saved then return end
    EPC.saved.gameModeReportLeft = self.window:GetLeft()
    EPC.saved.gameModeReportTop = self.window:GetTop()
    EPC.saved.gameModeReportWidth = self.window:GetWidth()
    EPC.saved.gameModeReportHeight = self.window:GetHeight()
end

function R:RestorePlacement(forceCenter)
    if not self.window or not EPC.saved then return end
    local rootWidth = number(GuiRoot:GetWidth())
    local rootHeight = number(GuiRoot:GetHeight())

    -- One-time migration from the oversized pre-0.29.119 report. Existing
    -- users immediately get the new compact footprint instead of preserving
    -- a saved 1040x720+ window that defeats the redesign.
    if EPC.saved.gameModeReportCompact119 ~= true then
        EPC.saved.gameModeReportWidth = 860
        EPC.saved.gameModeReportHeight = 560
        EPC.saved.gameModeReportCompact119 = true
    end
    -- 0.29.120 keeps the same compact footprint but fixes the content rather
    -- than forcing the user to enlarge the report. Mark the layout migration
    -- so future versions can preserve whatever size the player chooses.
    if EPC.saved.gameModeReportReadable120 ~= true then
        EPC.saved.gameModeReportReadable120 = true
    end

    local maxWidth = math.max(760, rootWidth - 30)
    local maxHeight = math.max(500, rootHeight - 30)
    local width = clamp(EPC.saved.gameModeReportWidth or 860, 760, maxWidth)
    local height = clamp(EPC.saved.gameModeReportHeight or 560, 500, maxHeight)
    self.window:SetDimensions(width, height)
    self.window:ClearAnchors()
    local left = number(EPC.saved.gameModeReportLeft or -1)
    local top = number(EPC.saved.gameModeReportTop or -1)
    if forceCenter == true or left < 0 or top < 0 then
        self.window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    else
        self.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    end
end

function R:ResetPosition()
    if not EPC.saved then return end
    EPC.saved.gameModeReportLeft, EPC.saved.gameModeReportTop = -1, -1
    EPC.saved.gameModeReportWidth, EPC.saved.gameModeReportHeight = 860, 560
    EPC.saved.gameModeReportCompact119 = true
    self:RestorePlacement(true)
    self:ApplyLayout()
end

function R:UpdatePageButtons()
    local selected = self.currentPage or "OVERVIEW"
    for _, item in ipairs(self.pageButtons or {}) do
        local active = item.page and item.page.key == selected
        if item.background then
            if active then
                item.background:SetCenterColor(0.16, 0.12, 0.035, 0.99)
                item.background:SetEdgeColor(unpack(GOLD))
            else
                item.background:SetCenterColor(0.035, 0.045, 0.064, 0.96)
                item.background:SetEdgeColor(0.13, 0.17, 0.23, 0.82)
            end
        end
        if item.button then
            item.button:SetNormalFontColor(unpack(active and GOLD or MUTED))
            item.button:SetMouseOverFontColor(unpack(TEXT))
        end
    end
end

function R:SetPage(pageKey)
    pageKey = tostring(pageKey or "OVERVIEW")
    if not PAGE_LABELS[pageKey] then pageKey = "OVERVIEW" end
    if self.currentPage == pageKey then return end
    self.currentPage = pageKey
    self:UpdatePageButtons()
    self:ApplyLayout()
    self:Refresh()
end

function R:ApplyLayout()
    if not self.window then return end
    local width, height = self.window:GetDimensions()
    local compact = width <= 900 or height <= 600
    self.compactLayout = compact

    local pad = 6
    local gap = 5
    local railWidth = compact and 46 or 50
    local railTop = 48
    local metricHeight = compact and 44 or 48
    local contentX = pad + railWidth + gap
    local contentWidth = math.max(500, width - contentX - pad)
    local contentTop = railTop + metricHeight + gap
    local footerHeight = 22
    local usableHeight = math.max(300, height - contentTop - footerHeight - gap)
    local page = self.currentPage or "OVERVIEW"

    -- Header stays deliberately small. Long location/mode names ellipsize rather
    -- than forcing the report to grow.
    if self.modeLabel then
        self.modeLabel:SetWidth(compact and 145 or 180)
        self.modeLabel:SetFont("ZoFontGameSmall")
    end
    if self.zoneLabel then self.zoneLabel:SetWidth(compact and 180 or 225) end
    if self.titleLabel then
        self.titleLabel:SetWidth(compact and 210 or 270)
        self.titleLabel:SetFont("ZoFontGameBold")
    end

    -- Left navigation rail.
    self.pageRail:ClearAnchors()
    self.pageRail:SetAnchor(TOPLEFT, self.window, TOPLEFT, pad, railTop)
    self.pageRail:SetDimensions(railWidth, math.max(330, height - railTop - footerHeight - pad))
    local buttonHeight = compact and 32 or 35
    local buttonGap = 3
    for index, item in ipairs(self.pageButtons or {}) do
        local bg = item.background
        if bg then
            bg:ClearAnchors()
            bg:SetAnchor(TOPLEFT, self.pageRail, TOPLEFT, 5, 6 + ((index - 1) * (buttonHeight + buttonGap)))
            bg:SetDimensions(railWidth - 10, buttonHeight)
        end
    end
    self:UpdatePageButtons()

    -- Always-visible compact fight metrics.
    if self.metricStrip then
        self.metricStrip:ClearAnchors()
        self.metricStrip:SetAnchor(TOPLEFT, self.window, TOPLEFT, contentX, railTop)
        self.metricStrip:SetDimensions(contentWidth, metricHeight)
        local cellWidth = math.floor(contentWidth / math.max(1, #self.metricCells))
        local x = 0
        for index, cell in ipairs(self.metricCells or {}) do
            local w = (index == #self.metricCells) and (contentWidth - x) or cellWidth
            cell:ClearAnchors()
            cell:SetAnchor(TOPLEFT, self.metricStrip, TOPLEFT, x, 0)
            cell:SetDimensions(math.max(70, w), metricHeight)
            if cell.caption then cell.caption:SetFont("ZoFontGameSmall") end
            if cell.value then cell.value:SetFont(compact and "ZoFontGameSmall" or "ZoFontGameBold") end
            x = x + w
        end
    end

    local panels = { self.summaryPanel, self.statsPanel, self.buffsPanel, self.targetsPanel, self.abilitiesPanel, self.graphPanel }
    for _, panel in ipairs(panels) do if panel then panel:SetHidden(true) end end

    local function place(panel, x, y, w, h)
        panel:SetHidden(false)
        panel:ClearAnchors()
        panel:SetAnchor(TOPLEFT, self.window, TOPLEFT, x, y)
        panel:SetDimensions(math.max(150, w), math.max(90, h))
        if panel.title then panel.title:SetFont("ZoFontGameBold") end
    end

    -- Overview is intentionally information-dense without being dashboard-like:
    -- one narrow fight snapshot, then abilities + distribution on the right.
    if page == "OVERVIEW" then
        local leftW = math.max(220, math.floor(contentWidth * 0.34))
        local rightW = contentWidth - leftW - gap
        local rightTopH = math.floor((usableHeight - gap) * 0.60)
        place(self.summaryPanel, contentX, contentTop, leftW, usableHeight)
        place(self.abilitiesPanel, contentX + leftW + gap, contentTop, rightW, rightTopH)
        place(self.graphPanel, contentX + leftW + gap, contentTop + rightTopH + gap, rightW, usableHeight - rightTopH - gap)
        self.summaryPanel.title:SetText("FIGHT SNAPSHOT")
        self.abilitiesPanel.title:SetText("TOP DAMAGE")
        self.graphPanel.title:SetText("DAMAGE SHARE")
    elseif page == "DAMAGE" then
        -- At minimum size the old split view hid several ability and target
        -- rows. Give the full page to the ability table and expose targets on
        -- their own TGT page so every recorded row remains readable.
        place(self.abilitiesPanel, contentX, contentTop, contentWidth, usableHeight)
        self.abilitiesPanel.title:SetText("DAMAGE ABILITIES")
    elseif page == "TARGETS" then
        place(self.targetsPanel, contentX, contentTop, contentWidth, usableHeight)
        self.targetsPanel.title:SetText("DAMAGE BY TARGET")
    elseif page == "HEALING" then
        local leftW = math.max(240, math.floor(contentWidth * 0.34))
        place(self.summaryPanel, contentX, contentTop, leftW, usableHeight)
        place(self.targetsPanel, contentX + leftW + gap, contentTop, contentWidth - leftW - gap, usableHeight)
        self.summaryPanel.title:SetText("HEALING SNAPSHOT")
        self.targetsPanel.title:SetText("HEALING CONTRIBUTORS")
    elseif page == "INCOMING" then
        local leftW = math.max(240, math.floor(contentWidth * 0.34))
        place(self.summaryPanel, contentX, contentTop, leftW, usableHeight)
        place(self.targetsPanel, contentX + leftW + gap, contentTop, contentWidth - leftW - gap, usableHeight)
        self.summaryPanel.title:SetText("DEFENSE SNAPSHOT")
        self.targetsPanel.title:SetText("INCOMING SOURCES")
    elseif page == "GROUP" then
        place(self.targetsPanel, contentX, contentTop, contentWidth, usableHeight)
        self.targetsPanel.title:SetText("GROUP / COMPANIONS / PETS")
    elseif page == "BUFFS" then
        place(self.buffsPanel, contentX, contentTop, contentWidth, usableHeight)
        self.buffsPanel.title:SetText("BUFF / DEBUFF UPTIME")
    elseif page == "RESOURCES" then
        place(self.statsPanel, contentX, contentTop, contentWidth, usableHeight)
        self.statsPanel.title:SetText("RESOURCE USAGE")
    elseif page == "GRAPH" then
        place(self.graphPanel, contentX, contentTop, contentWidth, usableHeight)
        self.graphPanel.title:SetText("DAMAGE DISTRIBUTION")
    elseif page == "BUILD" then
        place(self.statsPanel, contentX, contentTop, contentWidth, usableHeight)
        self.statsPanel.title:SetText("EFFECTIVE BUILD STATS")
    end

    -- Content rows use the exact panel height. Small fonts + ellipsis preserve
    -- clean columns at minimum size without overlapping or wrapping.
    if self.summaryPanel then
        local contentH = math.max(18, self.summaryPanel:GetHeight() - 34)
        local rowH = math.max(17, math.min(20, math.floor(contentH / 18)))
        for index, row in ipairs(self.summaryRows or {}) do
            row:ClearAnchors()
            row:SetAnchor(TOPLEFT, self.summaryPanel, TOPLEFT, 10, 30 + ((index - 1) * rowH))
            row:SetDimensions(math.max(10, self.summaryPanel:GetWidth() - 20), rowH)
            local rowW = math.max(10, row:GetWidth())
            if row.name then
                row.name:ClearAnchors()
                row.name:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
                row.name:SetDimensions(math.max(80, math.floor(rowW * 0.58)), rowH)
                row.name:SetFont("ZoFontGameSmall")
            end
            if row.value then
                row.value:ClearAnchors()
                row.value:SetAnchor(TOPRIGHT, row, TOPRIGHT, 0, 0)
                row.value:SetDimensions(math.max(60, rowW - math.max(80, math.floor(rowW * 0.58)) - 4), rowH)
                row.value:SetFont("ZoFontGameSmall")
            end
        end
    end

    if self.statsPanel then
        local contentH = math.max(18, self.statsPanel:GetHeight() - 36)
        local rowH = math.max(15, math.min(24, math.floor(contentH / 13)))
        for index, row in ipairs(self.statsRows or {}) do
            row:ClearAnchors()
            row:SetAnchor(TOPLEFT, self.statsPanel, TOPLEFT, 10, 30 + ((index - 1) * rowH))
            row:SetDimensions(math.max(10, self.statsPanel:GetWidth() - 20), rowH)
            if row.name then row.name:SetWidth(math.floor(row:GetWidth() * 0.60)) end
            if row.value then row.value:SetWidth(math.max(66, row:GetWidth() - (row.name and row.name:GetWidth() or 140) - 4)) end
        end
    end

    if self.buffHeader then
        self.buffHeader:ClearAnchors()
        self.buffHeader:SetAnchor(TOPLEFT, self.buffsPanel, TOPLEFT, 10, 29)
        self.buffHeader:SetWidth(math.max(20, self.buffsPanel:GetWidth() - 20))
    end
    local buffAvailable = self.buffsPanel and math.max(1, self.buffsPanel:GetHeight() - 50) or 1
    local buffRowH = math.max(18, math.min(compact and 22 or 24, math.floor(buffAvailable / math.max(1, #(self.buffRows or {})))))
    for index, row in ipairs(self.buffRows or {}) do
        row:ClearAnchors()
        row:SetAnchor(TOPLEFT, self.buffsPanel, TOPLEFT, 8, 47 + ((index - 1) * buffRowH))
        row:SetDimensions(math.max(120, self.buffsPanel:GetWidth() - 16), buffRowH)
        if row.name then row.name:SetWidth(math.max(80, row:GetWidth() - 148)) end
    end

    local targetAvailable = self.targetsPanel and math.max(1, self.targetsPanel:GetHeight() - 50) or 1
    local targetRowH = math.max(18, math.min(compact and 22 or 24, math.floor(targetAvailable / math.max(1, #(self.targetRows or {})))))
    if self.targetHeaderRow then
        self.targetHeaderRow:ClearAnchors()
        self.targetHeaderRow:SetAnchor(TOPLEFT, self.targetsPanel, TOPLEFT, 8, 29)
        self.targetHeaderRow:SetDimensions(math.max(260, self.targetsPanel:GetWidth() - 16), 17)
        self:LayoutTargetColumns(self.targetHeaderRow, true)
    end
    for index, row in ipairs(self.targetRows or {}) do
        row:ClearAnchors()
        row:SetAnchor(TOPLEFT, self.targetsPanel, TOPLEFT, 8, 47 + ((index - 1) * targetRowH))
        row:SetDimensions(math.max(260, self.targetsPanel:GetWidth() - 16), targetRowH)
        self:LayoutTargetColumns(row, false)
    end

    local abilityAvailable = self.abilitiesPanel and math.max(1, self.abilitiesPanel:GetHeight() - 50) or 1
    local abilityRowH = math.max(18, math.min(compact and 22 or 24, math.floor(abilityAvailable / math.max(1, #(self.abilityRows or {})))))
    if self.abilityHeaderRow then
        self.abilityHeaderRow:ClearAnchors()
        self.abilityHeaderRow:SetAnchor(TOPLEFT, self.abilitiesPanel, TOPLEFT, 8, 29)
        self.abilityHeaderRow:SetDimensions(math.max(360, self.abilitiesPanel:GetWidth() - 16), 17)
        self:LayoutAbilityColumns(self.abilityHeaderRow, true)
    end
    for index, row in ipairs(self.abilityRows or {}) do
        row:ClearAnchors()
        row:SetAnchor(TOPLEFT, self.abilitiesPanel, TOPLEFT, 8, 47 + ((index - 1) * abilityRowH))
        row:SetDimensions(math.max(360, self.abilitiesPanel:GetWidth() - 16), abilityRowH)
        self:LayoutAbilityColumns(row, false)
        if row.icon then row.icon:SetDimensions(compact and 18 or 20, compact and 18 or 20) end
    end

    local graphAvailable = self.graphPanel and math.max(1, self.graphPanel:GetHeight() - 36) or 1
    local graphRowH = math.max(20, math.min(compact and 25 or 29, math.floor(graphAvailable / math.max(1, #(self.graphRows or {})))))
    for index, row in ipairs(self.graphRows or {}) do
        row:ClearAnchors()
        row:SetAnchor(TOPLEFT, self.graphPanel, TOPLEFT, 8, 32 + ((index - 1) * graphRowH))
        row:SetDimensions(math.max(260, self.graphPanel:GetWidth() - 16), graphRowH)
        if row.name then row.name:SetWidth(math.max(90, row:GetWidth() - 180)) end
        if row.value then row.value:SetWidth(compact and 145 or 170) end
    end
end

function R:RefreshSummaryRows(report)
    if type(self.summaryRows) ~= "table" then return end
    local page = self.currentPage or "OVERVIEW"
    local normalHits = math.max(0, number(report.hits) - number(report.criticalHits))
    local combinedDamage = number(report.combinedDamage)
    if combinedDamage <= 0 then combinedDamage = number(report.totalDamage) + number(report.petDamage) + number(report.companionDamage) end
    local combinedDps = number(report.combinedDps)
    if combinedDps <= 0 and number(report.duration) > 0 then combinedDps = combinedDamage / number(report.duration) end

    local rows
    if page == "HEALING" then
        local combinedHealing = number(report.combinedHealing)
        if combinedHealing <= 0 then combinedHealing = number(report.totalHealing) + number(report.petHealing) + number(report.companionHealing) end
        rows = {
            { name = "ACTIVE TIME", value = formatDuration(report.duration), nameColor = GOLD },
            { name = "STATUS", value = report.live and "LIVE COMBAT" or "COMPLETED", nameColor = MUTED, valueColor = report.live and GREEN or TEXT },
            { section = true, name = "HEALING", color = GREEN },
            { name = "Player HPS", value = formatNumber(report.hps) },
            { name = "Player healing", value = formatNumber(report.totalHealing) },
            { name = "Companion healing", value = formatNumber(report.companionHealing) },
            { name = "Pet / summon heal", value = formatNumber(report.petHealing) },
            { name = "Combined healing", value = formatNumber(combinedHealing), valueColor = GREEN },
            { section = true, name = "HEAL EVENTS", color = GOLD },
            { name = "Total", value = formatNumber(report.healEvents) },
            { name = "Critical", value = formatNumber(report.criticalHeals) },
            { name = "Critical rate", value = formatPercent(report.criticalHealPercent) },
        }
    elseif page == "INCOMING" then
        local stats = report.stats or {}
        rows = {
            { name = "ACTIVE TIME", value = formatDuration(report.duration), nameColor = GOLD },
            { name = "STATUS", value = report.live and "LIVE COMBAT" or "COMPLETED", nameColor = MUTED, valueColor = report.live and GREEN or TEXT },
            { section = true, name = "DEFENSE", color = RED },
            { name = "Incoming DPS", value = formatNumber(report.dtps), valueColor = RED },
            { name = "Incoming damage", value = formatNumber(report.incomingDamage) },
            { name = "Incoming hits", value = formatNumber(report.incomingHits) },
            { name = "Blocked hits", value = formatNumber(report.blockedHits) },
            { name = "Block rate", value = formatPercent(report.blockPercent) },
            { section = true, name = "RESISTANCE", color = GOLD },
            { name = "Spell resistance", value = formatNumber(stats.spellResistance) },
            { name = "Physical resist.", value = formatNumber(stats.physicalResistance) },
        }
    else
        local mechanics = type(report.bossMechanics) == "table" and report.bossMechanics or nil
        if mechanics and number(mechanics.alerts) > 0 then
            local bossName = tostring(mechanics.bossName or "Boss")
            if mechanics.hmDetected == true then bossName = bossName .. "  •  HM" end
            local grade = tostring(mechanics.grade or "N/A") .. "  •  " .. tostring(math.floor(number(mechanics.score))) .. "/100"
            local interruptText = tostring(math.floor(number(mechanics.interruptSuccess))) .. "/" .. tostring(math.floor(number(mechanics.interruptRequired)))
            local blockText = tostring(math.floor(number(mechanics.blockSuccess))) .. "/" .. tostring(math.floor(number(mechanics.blockRequired)))
            local dodgeText = tostring(math.floor(number(mechanics.dodgeSuccess))) .. "/" .. tostring(math.floor(number(mechanics.dodgeRequired)))
            rows = {
                { name = "ACTIVE TIME", value = formatDuration(report.duration), nameColor = GOLD },
                { name = "STATUS", value = report.live and "LIVE COMBAT" or "COMPLETED", nameColor = MUTED, valueColor = report.live and GREEN or TEXT },
                { section = true, name = "BOSS EXECUTION", color = GOLD },
                { name = "Boss", value = bossName, valueColor = GOLD },
                { name = "Mechanic grade", value = grade, valueColor = number(mechanics.score) >= 90 and GREEN or (number(mechanics.score) >= 70 and GOLD or RED) },
                { name = "Avoidable hits", value = formatNumber(mechanics.avoidableHits), valueColor = number(mechanics.avoidableHits) > 0 and RED or GREEN },
                { name = "Clean avoids", value = formatNumber(mechanics.cleanAvoids), valueColor = GREEN },
                { name = "Interrupts", value = interruptText },
                { name = "Blocks", value = blockText },
                { name = "Dodges", value = dodgeText },
                { section = true, name = "DAMAGE / DEFENSE", color = GOLD },
                { name = "Player DPS", value = formatNumber(report.dps), valueColor = CYAN },
                { name = "Combined DPS", value = formatNumber(combinedDps), valueColor = GOLD },
                { name = "Player damage", value = formatNumber(report.totalDamage) },
                { name = "Critical rate", value = formatPercent(report.criticalEventPercent) },
                { name = "Incoming DPS", value = formatNumber(report.dtps), valueColor = RED },
                { name = "Block rate", value = formatPercent(report.blockPercent) },
            }
        else
            rows = {
                { name = "ACTIVE TIME", value = formatDuration(report.duration), nameColor = GOLD },
                { name = "STATUS", value = report.live and "LIVE COMBAT" or "COMPLETED", nameColor = MUTED, valueColor = report.live and GREEN or TEXT },
                { section = true, name = "DAMAGE", color = GOLD },
                { name = "Player DPS", value = formatNumber(report.dps), valueColor = CYAN },
                { name = "Player damage", value = formatNumber(report.totalDamage) },
                { name = "Pets / summons", value = formatNumber(report.petDamage) },
                { name = "Companion", value = formatNumber(report.companionDamage) },
                { name = "Combined DPS", value = formatNumber(combinedDps), valueColor = GOLD },
                { section = true, name = "HITS", color = GOLD },
                { name = "Total", value = formatNumber(report.hits) },
                { name = "Normal", value = formatNumber(normalHits) },
                { name = "Critical", value = formatNumber(report.criticalHits) },
                { name = "Critical rate", value = formatPercent(report.criticalEventPercent) },
                { section = true, name = "HEALING / DEFENSE", color = GOLD },
                { name = "Player HPS", value = formatNumber(report.hps), valueColor = GREEN },
                { name = "Player healing", value = formatNumber(report.totalHealing) },
                { name = "Incoming DPS", value = formatNumber(report.dtps), valueColor = RED },
                { name = "Blocked hits", value = formatPercent(report.blockPercent) },
            }
        end
    end

    for index, row in ipairs(self.summaryRows or {}) do
        local entry = rows[index]
        if entry then
            row:SetHidden(false)
            if row.name then
                row.name:SetText(entry.name or "")
                row.name:SetColor(unpack(entry.section and (entry.color or GOLD) or (entry.nameColor or MUTED)))
                row.name:SetFont(entry.section and "ZoFontGameBold" or "ZoFontGameSmall")
                if entry.section then
                    row.name:SetWidth(math.max(10, row:GetWidth()))
                else
                    row.name:SetWidth(math.max(80, math.floor(row:GetWidth() * 0.58)))
                end
            end
            if row.value then
                row.value:SetText(entry.section and "" or tostring(entry.value or ""))
                row.value:SetColor(unpack(entry.valueColor or TEXT))
                row.value:SetFont("ZoFontGameSmall")
                row.value:SetHidden(entry.section == true)
                if entry.section then
                    row.value:SetWidth(1)
                else
                    row.value:SetHidden(false)
                    row.value:SetWidth(math.max(60, row:GetWidth() - math.max(80, math.floor(row:GetWidth() * 0.58)) - 4))
                end
            end
        else
            row:SetHidden(true)
        end
    end
end

function R:BuildSummaryText(report)
    local normalHits = math.max(0, number(report.hits) - number(report.criticalHits))
    local combinedDamage = number(report.combinedDamage)
    if combinedDamage <= 0 then combinedDamage = number(report.totalDamage) + number(report.petDamage) + number(report.companionDamage) end
    local combinedDps = number(report.combinedDps)
    if combinedDps <= 0 and number(report.duration) > 0 then combinedDps = combinedDamage / number(report.duration) end
    return table.concat({
        "|cFFD36AACTIVE TIME|r        " .. formatDuration(report.duration),
        "|cA9B2C0STATUS|r             " .. (report.live and "|c55E86ELIVE COMBAT|r" or "COMPLETED FIGHT"),
        "",
        "|cFFD36ADAMAGE|r",
        "Player DPS          " .. formatNumber(report.dps),
        "Player damage       " .. formatNumber(report.totalDamage),
        "Pets / summons      " .. formatNumber(report.petDamage),
        "Companion           " .. formatNumber(report.companionDamage),
        "Combined DPS        " .. formatNumber(combinedDps),
        "",
        "|cFFD36AHITS|r",
        "Total               " .. formatNumber(report.hits),
        "Normal              " .. formatNumber(normalHits),
        "Critical            " .. formatNumber(report.criticalHits),
        "Critical rate       " .. formatPercent(report.criticalEventPercent),
        "",
        "|cFFD36AHEALING / DEFENSE|r",
        "Player HPS          " .. formatNumber(report.hps),
        "Player healing      " .. formatNumber(report.totalHealing),
        "Incoming DPS        " .. formatNumber(report.dtps),
        "Blocked hits        " .. formatPercent(report.blockPercent),
    }, "\n")
end

function R:BuildStatsText(report)
    local stats = report.stats or {}
    return table.concat({
        "|c49C9F6MAGICKA / SECOND|r",
        string.format("Used                %s", formatNumber(stats.magickaSpentPerSecond)),
        string.format("Regained            %s", formatNumber(stats.magickaGainedPerSecond)),
        "",
        "|c7EE33DSTAMINA / SECOND|r",
        string.format("Used                %s", formatNumber(stats.staminaSpentPerSecond)),
        string.format("Regained            %s", formatNumber(stats.staminaGainedPerSecond)),
        "",
        "|cFFD36AEFFECTIVE COMBAT STATS|r",
        string.format("PEN                 %s", formatNumber(stats.penetration)),
        string.format("PWR                 %s", formatNumber(stats.damage)),
        string.format("SR                  %s", formatNumber(stats.spellResistance)),
        string.format("PR                  %s", formatNumber(stats.physicalResistance)),
        string.format("CC                  %s", formatPercent(stats.criticalChance)),
        string.format("CD                  %s", stats.criticalDamage ~= nil and formatPercent(stats.criticalDamage) or "--"),
    }, "\n")
end

function R:RefreshStatsRows(report)
    if type(self.statsRows) ~= "table" then return end
    local stats = report.stats or {}
    local page = self.currentPage or "OVERVIEW"
    local rows
    if page == "RESOURCES" then
        rows = {
            { section = true, name = "MAGICKA", color = CYAN },
            { name = "Current / Max", value = formatNumber(stats.magicka) .. " / " .. formatNumber(stats.magickaMax) },
            { name = "Used / sec", value = formatNumber(stats.magickaSpentPerSecond) },
            { name = "Regained / sec", value = formatNumber(stats.magickaGainedPerSecond) },
            { name = "Total spent", value = formatNumber(stats.magickaSpent) },
            { name = "Total regained", value = formatNumber(stats.magickaGained) },
            { section = true, name = "STAMINA", color = GREEN },
            { name = "Current / Max", value = formatNumber(stats.stamina) .. " / " .. formatNumber(stats.staminaMax) },
            { name = "Used / sec", value = formatNumber(stats.staminaSpentPerSecond) },
            { name = "Regained / sec", value = formatNumber(stats.staminaGainedPerSecond) },
            { name = "Total spent", value = formatNumber(stats.staminaSpent) },
            { name = "Total regained", value = formatNumber(stats.staminaGained) },
            { name = "Ultimate", value = formatNumber(stats.ultimate) .. " / " .. formatNumber(stats.ultimateMax) },
        }
    elseif page == "BUILD" then
        rows = {
            { section = true, name = stats.effective and "FIGHT-WEIGHTED STATS" or "LIVE COMBAT STATS", color = GOLD },
            { name = "PEN", value = formatNumber(stats.penetration) },
            { name = "PWR", value = formatNumber(stats.damage) },
            { name = "SR", value = formatNumber(stats.spellResistance) },
            { name = "PR", value = formatNumber(stats.physicalResistance) },
            { name = "CC", value = formatPercent(stats.criticalChance) },
            { name = "CD", value = stats.criticalDamage ~= nil and formatPercent(stats.criticalDamage) or "--" },
            { section = true, name = "RESOURCE POOLS", color = CYAN },
            { name = "Health", value = formatNumber(stats.health) .. " / " .. formatNumber(stats.healthMax) },
            { name = "Magicka", value = formatNumber(stats.magicka) .. " / " .. formatNumber(stats.magickaMax) },
            { name = "Stamina", value = formatNumber(stats.stamina) .. " / " .. formatNumber(stats.staminaMax) },
            { name = "Magicka regen", value = formatNumber(stats.magickaRegen) },
            { name = "Stamina regen", value = formatNumber(stats.staminaRegen) },
        }
    else
        rows = {
            { section = true, name = "MAGICKA / SECOND", color = CYAN },
            { name = "Used", value = formatNumber(stats.magickaSpentPerSecond) },
            { name = "Regained", value = formatNumber(stats.magickaGainedPerSecond) },
            { section = true, name = "STAMINA / SECOND", color = GREEN },
            { name = "Used", value = formatNumber(stats.staminaSpentPerSecond) },
            { name = "Regained", value = formatNumber(stats.staminaGainedPerSecond) },
            { section = true, name = stats.effective and "EFFECTIVE COMBAT STATS" or "LIVE COMBAT STATS", color = GOLD },
            { name = "PEN", value = formatNumber(stats.penetration) },
            { name = "PWR", value = formatNumber(stats.damage) },
            { name = "SR", value = formatNumber(stats.spellResistance) },
            { name = "PR", value = formatNumber(stats.physicalResistance) },
            { name = "CC", value = formatPercent(stats.criticalChance) },
            { name = "CD", value = stats.criticalDamage ~= nil and formatPercent(stats.criticalDamage) or "--" },
        }
    end
    for index, row in ipairs(self.statsRows or {}) do
        local entry = rows[index]
        if entry then
            row.name:SetText(entry.name or "")
            row.value:SetText(entry.value or "")
            if entry.section then
                row.name:SetColor(unpack(entry.color or GOLD))
                row.name:SetFont(self.compactLayout and "ZoFontGameSmall" or "ZoFontGameBold")
                row.name:SetWidth(math.max(10, row:GetWidth()))
                row.value:SetText("")
                row.value:SetWidth(1)
            else
                row.name:SetColor(unpack(MUTED))
                row.name:SetFont("ZoFontGameSmall")
                row.name:SetWidth(math.floor(row:GetWidth() * 0.58))
                row.value:SetColor(unpack(TEXT))
                row.value:SetFont("ZoFontGameSmall")
                row.value:SetWidth(math.max(70, row:GetWidth() - row.name:GetWidth() - 4))
            end
            row:SetHidden(false)
        else
            row:SetHidden(true)
        end
    end
end


function R:RefreshBuffRows(report)
    local buffs = report.buffs or {}
    local firstRowH = self.buffRows and self.buffRows[1] and math.max(1, number(self.buffRows[1]:GetHeight())) or 23
    local capacity = math.max(0, math.floor((self.buffsPanel:GetHeight() - 49) / firstRowH))
    for index, row in ipairs(self.buffRows) do
        local buff = buffs[index]
        if buff and index <= capacity then
            row.icon:SetTexture(buff.icon ~= "" and buff.icon or DEFAULT_ICON)
            row.name:SetText(tostring(buff.name or "Effect"))
            row.stacks:SetText(number(buff.stacks) > 0 and tostring(number(buff.stacks)) or "-")
            if buff.uptimePercent ~= nil then
                row.time:SetText(formatPercent(buff.uptimePercent))
            else
                row.time:SetText(number(buff.remaining) > 0 and formatDuration(buff.remaining) or "active")
            end
            if buff.debuff then
                row.name:SetColor(unpack(RED)); row.time:SetColor(unpack(RED)); row.bar:SetColor(0.42, 0.07, 0.06, 0.76)
            else
                row.name:SetColor(unpack(TEXT)); row.time:SetColor(unpack(TEXT)); row.bar:SetColor(0.06, 0.38, 0.12, 0.76)
            end
            row.stacks:SetColor(unpack(MUTED))
            local ratio
            if buff.uptimePercent ~= nil then
                ratio = clamp(number(buff.uptimePercent) / 100, 0.05, 1)
            else
                ratio = number(buff.duration) > 0 and clamp(number(buff.remaining) / number(buff.duration), 0.05, 1) or 1
            end
            row.bar:SetWidth(math.max(3, (row:GetWidth() - 2) * ratio))
            row:SetHidden(false)
        else
            row:SetHidden(true)
        end
    end
end

function R:BuildObservedMVP(contributors)
    local rows = {}
    local totalDamage, totalHealing = 0, 0
    local damageLeader, healingLeader = nil, nil
    for _, source in ipairs(contributors or {}) do
        local entry = {
            name = cleanName(source.name),
            damage = number(source.damage), healing = number(source.healing),
            dps = number(source.dps), hps = number(source.hps),
            isSelf = source.isSelf == true,
        }
        if entry.damage > 0 or entry.healing > 0 then
            totalDamage = totalDamage + entry.damage
            totalHealing = totalHealing + entry.healing
            if not damageLeader or entry.damage > damageLeader.damage then damageLeader = entry end
            if not healingLeader or entry.healing > healingLeader.healing then healingLeader = entry end
            rows[#rows + 1] = entry
        end
    end

    local useDamage = totalDamage > 0
    local useHealing = totalHealing > 0
    local weightCount = (useDamage and 1 or 0) + (useHealing and 1 or 0)
    local overall = nil
    for _, entry in ipairs(rows) do
        entry.damageShare = useDamage and (entry.damage / totalDamage) or 0
        entry.healingShare = useHealing and (entry.healing / totalHealing) or 0
        entry.mvpScore = weightCount > 0 and ((entry.damageShare + entry.healingShare) / weightCount * 100) or 0
        if not overall or entry.mvpScore > overall.mvpScore or (entry.mvpScore == overall.mvpScore and entry.damage > overall.damage) then
            overall = entry
        end
    end
    table.sort(rows, function(left, right)
        if left.mvpScore == right.mvpScore then
            if left.damage == right.damage then return left.healing > right.healing end
            return left.damage > right.damage
        end
        return left.mvpScore > right.mvpScore
    end)
    return rows, overall, damageLeader, healingLeader, totalDamage, totalHealing
end

function R:RefreshTargetRows(report)
    local entries = {}
    local page = self.currentPage or "OVERVIEW"
    local contributors, overall, damageLeader, healingLeader, totalGroupDamage, totalGroupHealing = self:BuildObservedMVP(report.contributors or {})

    if page == "TARGETS" then
        if self.targetHeaderRow then
            self.targetHeaderRow.kind:SetText("Type"); self.targetHeaderRow.name:SetText("Target")
            self.targetHeaderRow.dps:SetText("DPS"); self.targetHeaderRow.hps:SetText("Damage"); self.targetHeaderRow.extra:SetText("Share")
        end
        for _, target in ipairs(report.targets or {}) do
            entries[#entries + 1] = {
                kind = "TARGET", name = cleanName(target.name), dps = number(target.dps), hps = 0,
                damage = number(target.damage), healing = 0,
                percent = report.totalDamage > 0 and (number(target.damage) / report.totalDamage * 100) or 0,
            }
            if #entries >= #self.targetRows then break end
        end
    elseif page == "INCOMING" then
        if self.targetHeaderRow then
            self.targetHeaderRow.kind:SetText("Type"); self.targetHeaderRow.name:SetText("Source / Ability")
            self.targetHeaderRow.dps:SetText("DPS"); self.targetHeaderRow.hps:SetText("Damage"); self.targetHeaderRow.extra:SetText("Share")
        end
        for _, incoming in ipairs(report.incomingSources or {}) do
            entries[#entries + 1] = {
                kind = "INCOMING", name = cleanName(incoming.source) .. " - " .. cleanName(incoming.name),
                dps = number(incoming.dps), hps = 0, damage = number(incoming.damage), healing = 0,
                percent = report.incomingDamage > 0 and (number(incoming.damage) / report.incomingDamage * 100) or 0,
            }
            if #entries >= #self.targetRows then break end
        end
    elseif page == "HEALING" then
        if self.targetHeaderRow then
            self.targetHeaderRow.kind:SetText("Type"); self.targetHeaderRow.name:SetText("Player / Actor")
            self.targetHeaderRow.dps:SetText("DPS"); self.targetHeaderRow.hps:SetText("HPS"); self.targetHeaderRow.extra:SetText("Heal %")
        end
        local healingEntries = {}
        for _, contributor in ipairs(contributors) do
            if number(contributor.healing) > 0 then
                healingEntries[#healingEntries + 1] = {
                    kind = contributor.isSelf and "YOU" or "GROUP", name = contributor.name,
                    dps = contributor.dps, hps = contributor.hps, damage = contributor.damage, healing = contributor.healing,
                    score = totalGroupHealing > 0 and contributor.healing / totalGroupHealing * 100 or 0,
                }
            end
        end
        for _, actor in ipairs(report.actors or {}) do
            if tostring(actor.kind or "") ~= "PLAYER" and number(actor.healing) > 0 then
                local owner = cleanName(actor.owner or "")
                local actorName = cleanName(actor.name)
                if owner ~= "Unknown" and owner ~= "" then actorName = actorName .. " (" .. owner .. ")" end
                local kind = tostring(actor.kind or "OTHER")
                healingEntries[#healingEntries + 1] = {
                    kind = kind == "COMPANION" and "COMP" or (kind == "PET" and "PET" or "SUMMON"),
                    name = actorName, dps = number(actor.dps), hps = number(actor.hps), damage = number(actor.damage), healing = number(actor.healing),
                    score = totalGroupHealing > 0 and number(actor.healing) / totalGroupHealing * 100 or 0,
                }
            end
        end
        table.sort(healingEntries, function(a,b) return number(a.healing) > number(b.healing) end)
        for index = 1, math.min(#healingEntries, #self.targetRows) do entries[#entries + 1] = healingEntries[index] end
    else
        if self.targetHeaderRow then
            self.targetHeaderRow.kind:SetText("Type"); self.targetHeaderRow.name:SetText("Player / Actor")
            self.targetHeaderRow.dps:SetText("DPS"); self.targetHeaderRow.hps:SetText("HPS"); self.targetHeaderRow.extra:SetText("Score")
        end
        if overall then
            entries[#entries + 1] = { kind = "MVP", name = overall.name, dps = overall.dps, hps = overall.hps, damage = overall.damage, healing = overall.healing, score = overall.mvpScore }
        end
        if damageLeader and damageLeader.damage > 0 then
            entries[#entries + 1] = { kind = "DMG MVP", name = damageLeader.name, dps = damageLeader.dps, hps = damageLeader.hps, damage = damageLeader.damage, healing = damageLeader.healing }
        end
        if healingLeader and healingLeader.healing > 0 and (not damageLeader or healingLeader.name ~= damageLeader.name) then
            entries[#entries + 1] = { kind = "HEAL MVP", name = healingLeader.name, dps = healingLeader.dps, hps = healingLeader.hps, damage = healingLeader.damage, healing = healingLeader.healing }
        end
        for _, actor in ipairs(report.actors or {}) do
            if #entries >= #self.targetRows then break end
            local kind = tostring(actor.kind or "OTHER")
            if kind ~= "PLAYER" and (number(actor.damage) > 0 or number(actor.healing) > 0) then
                local owner = cleanName(actor.owner or "")
                local actorName = cleanName(actor.name)
                if owner ~= "Unknown" and owner ~= "" then actorName = actorName .. " (" .. owner .. ")" end
                local label = kind == "COMPANION" and "COMP" or (kind == "PET" and "PET" or "SUMMON")
                entries[#entries + 1] = { kind = label, name = actorName, dps = number(actor.dps), hps = number(actor.hps), damage = number(actor.damage), healing = number(actor.healing), score = number(actor.critPercent) }
            end
        end
        for _, contributor in ipairs(contributors) do
            if #entries >= #self.targetRows then break end
            local isLeader = (overall and contributor.name == overall.name) or (damageLeader and contributor.name == damageLeader.name) or (healingLeader and contributor.name == healingLeader.name)
            if not isLeader then
                entries[#entries + 1] = { kind = contributor.isSelf and "YOU" or "GROUP", name = contributor.name, dps = contributor.dps, hps = contributor.hps, damage = contributor.damage, healing = contributor.healing, score = contributor.mvpScore }
            end
        end
    end

    local maximum = 1
    for _, entry in ipairs(entries) do maximum = math.max(maximum, number(entry.damage) + number(entry.healing)) end
    local firstRowH = self.targetRows and self.targetRows[1] and math.max(1, number(self.targetRows[1]:GetHeight())) or 24
    local capacity = math.max(0, math.floor((self.targetsPanel:GetHeight() - 47) / firstRowH))
    for index, row in ipairs(self.targetRows) do
        local entry = entries[index]
        if entry and index <= capacity then
            row.kind:SetText(entry.kind)
            row.name:SetText(cleanName(entry.name))
            row.dps:SetText(formatNumber(entry.dps))
            if entry.kind == "INCOMING" then
                row.hps:SetText(formatNumber(entry.damage)); row.extra:SetText(string.format("%4.1f%%", number(entry.percent)))
                row.kind:SetColor(unpack(RED)); row.name:SetColor(unpack(TEXT)); row.dps:SetColor(unpack(RED)); row.hps:SetColor(unpack(RED)); row.extra:SetColor(unpack(MUTED)); row.bar:SetColor(0.42, 0.07, 0.06, 0.80)
            elseif entry.kind == "TARGET" then
                row.hps:SetText(formatNumber(entry.damage)); row.extra:SetText(string.format("%4.1f%%", number(entry.percent)))
                row.kind:SetColor(unpack(TEXT)); row.name:SetColor(unpack(TEXT)); row.dps:SetColor(unpack(CYAN)); row.hps:SetColor(unpack(TEXT)); row.extra:SetColor(unpack(MUTED)); row.bar:SetColor(0.34, 0.10, 0.09, 0.72)
            elseif entry.kind == "MVP" then
                row.hps:SetText(formatNumber(entry.hps)); row.extra:SetText(string.format("%4.1f", number(entry.score)))
                row.kind:SetColor(unpack(GOLD)); row.name:SetColor(unpack(GOLD)); row.dps:SetColor(unpack(GOLD)); row.hps:SetColor(unpack(GOLD)); row.extra:SetColor(unpack(GOLD)); row.bar:SetColor(0.38, 0.27, 0.06, 0.82)
            elseif entry.kind == "DMG MVP" then
                row.hps:SetText(formatNumber(entry.hps)); row.extra:SetText("DMG")
                row.kind:SetColor(unpack(PURPLE)); row.name:SetColor(unpack(TEXT)); row.dps:SetColor(unpack(PURPLE)); row.hps:SetColor(unpack(GREEN)); row.extra:SetColor(unpack(PURPLE)); row.bar:SetColor(0.27, 0.10, 0.38, 0.78)
            elseif entry.kind == "HEAL MVP" then
                row.hps:SetText(formatNumber(entry.hps)); row.extra:SetText("HEAL")
                row.kind:SetColor(unpack(GREEN)); row.name:SetColor(unpack(TEXT)); row.dps:SetColor(unpack(CYAN)); row.hps:SetColor(unpack(GREEN)); row.extra:SetColor(unpack(GREEN)); row.bar:SetColor(0.06, 0.34, 0.12, 0.78)
            elseif entry.kind == "COMP" or entry.kind == "PET" or entry.kind == "SUMMON" then
                row.hps:SetText(formatNumber(entry.hps)); row.extra:SetText(string.format("%4.1f%%", number(entry.score)))
                local actorColor = entry.kind == "COMP" and PURPLE or (entry.kind == "PET" and GREEN or MUTED)
                row.kind:SetColor(unpack(actorColor)); row.name:SetColor(unpack(TEXT)); row.dps:SetColor(unpack(CYAN)); row.hps:SetColor(unpack(GREEN)); row.extra:SetColor(unpack(actorColor)); row.bar:SetColor(actorColor[1] * 0.30, actorColor[2] * 0.30, actorColor[3] * 0.30, 0.78)
            else
                row.hps:SetText(formatNumber(entry.hps)); row.extra:SetText(page == "HEALING" and string.format("%4.1f%%", number(entry.score)) or string.format("%4.1f", number(entry.score)))
                row.kind:SetColor(unpack(CYAN)); row.name:SetColor(unpack(TEXT)); row.dps:SetColor(unpack(CYAN)); row.hps:SetColor(unpack(GREEN)); row.extra:SetColor(unpack(TEXT)); row.bar:SetColor(0.08, 0.22, 0.38, 0.72)
            end
            row.bar:SetWidth(math.max(3, (row:GetWidth() - 2) * clamp((number(entry.damage) + number(entry.healing)) / maximum, 0.02, 1)))
            row:SetHidden(false)
        else
            row:SetHidden(true)
        end
    end
end


function R:RefreshAbilityRows(report)
    local abilities = report.abilities or {}
    local maximum = math.max(1, number(abilities[1] and abilities[1].damage))
    local firstRowH = self.abilityRows and self.abilityRows[1] and math.max(1, number(self.abilityRows[1]:GetHeight())) or 24
    local capacity = math.max(0, math.floor((self.abilitiesPanel:GetHeight() - 47) / firstRowH))
    for index, row in ipairs(self.abilityRows) do
        local ability = abilities[index]
        if ability and index <= capacity then
            local icon = ""
            if number(ability.abilityId) > 0 and type(GetAbilityIcon) == "function" then icon = tostring(safe(GetAbilityIcon, "", ability.abilityId) or "") end
            row.icon:SetTexture(icon ~= "" and icon or DEFAULT_ICON)
            row.name:SetText(tostring(ability.name or "Unknown"))
            row.percent:SetText(string.format("%.1f%%", number(ability.percent)))
            row.dps:SetText(formatNumber(ability.dps))
            row.damage:SetText(formatNumber(ability.damage))
            row.crit:SetText(string.format("%d/%d", number(ability.criticalHits), number(ability.hits)))
            row.max:SetText(formatNumber(ability.maxHit))
            row.name:SetColor(unpack(TEXT))
            row.percent:SetColor(unpack(MUTED))
            row.dps:SetColor(unpack(CYAN))
            row.damage:SetColor(unpack(TEXT))
            row.crit:SetColor(unpack(MUTED))
            row.max:SetColor(unpack(TEXT))
            local hue = index == 1 and GOLD or (index <= 3 and PURPLE or GREEN)
            row.bar:SetColor(hue[1] * 0.38, hue[2] * 0.38, hue[3] * 0.38, 0.76)
            row.bar:SetWidth(math.max(3, (row:GetWidth() - 2) * clamp(number(ability.damage) / maximum, 0.02, 1)))
            row:SetHidden(false)
        else
            row:SetHidden(true)
        end
    end
end

function R:RefreshGraphRows(report)
    if type(self.graphRows) ~= "table" then return end
    local entries = {}
    for _, ability in ipairs(report.abilities or {}) do
        if number(ability.damage) > 0 then entries[#entries + 1] = { name = cleanName(ability.name), damage = number(ability.damage) } end
    end
    if number(report.companionDamage) > 0 then entries[#entries + 1] = { name = "Companion", damage = number(report.companionDamage) } end
    if number(report.petDamage) > 0 then entries[#entries + 1] = { name = "Pets / Summons", damage = number(report.petDamage) } end
    table.sort(entries, function(a,b) return number(a.damage) > number(b.damage) end)

    local combined = number(report.combinedDamage)
    if combined <= 0 then combined = number(report.totalDamage) + number(report.companionDamage) + number(report.petDamage) end
    local maxDamage = 1
    for index = 1, math.min(#entries, #self.graphRows) do maxDamage = math.max(maxDamage, number(entries[index].damage)) end
    local firstRowH = self.graphRows and self.graphRows[1] and math.max(1, number(self.graphRows[1]:GetHeight())) or 28
    local capacity = math.max(0, math.floor((self.graphPanel:GetHeight() - 32) / firstRowH))
    for index, row in ipairs(self.graphRows) do
        local entry = entries[index]
        if entry and index <= capacity then
            local damage = number(entry.damage)
            local pct = combined > 0 and (damage / combined * 100) or 0
            row.name:SetText(string.format("%d. %s", index, entry.name))
            row.value:SetText(string.format("%s  •  %.1f%%", formatNumber(damage), pct))
            row.bar:SetWidth(math.max(3, (row:GetWidth() - 4) * clamp(damage / maxDamage, 0.02, 1)))
            row:SetHidden(false)
        else
            row:SetHidden(true)
        end
    end
end


function R:RefreshMetricStrip(report)
    if type(self.metricCells) ~= "table" then return end
    local combinedDamage = number(report and report.combinedDamage)
    if report and combinedDamage <= 0 then
        combinedDamage = number(report.totalDamage) + number(report.petDamage) + number(report.companionDamage)
    end
    local combinedDps = number(report and report.combinedDps)
    if report and combinedDps <= 0 and number(report.duration) > 0 then combinedDps = combinedDamage / number(report.duration) end
    local values = report and {
        formatNumber(report.dps),
        formatNumber(combinedDps),
        formatNumber(report.hps),
        formatNumber(report.dtps),
        formatDuration(report.duration),
    } or { "--", "--", "--", "--", "--" }
    for index, cell in ipairs(self.metricCells) do
        if cell and cell.value then cell.value:SetText(values[index] or "--") end
    end
end


function R:Refresh()
    if not self:IsUIReady() then
        local shouldBeVisible = self.window and type(self.window.IsHidden) == "function" and not self.window:IsHidden()
        if not self:EnsureWindow() then return end
        if shouldBeVisible and self.window then self.window:SetHidden(false) end
    end
    if not self.window or self.window:IsHidden() then return end
    local reports = self:GetAvailableReports()
    self.viewIndex = math.floor(clamp(self.viewIndex or 1, 1, math.max(1, #reports)))
    local report = reports[self.viewIndex]
    if not report then
        self.modeLabel:SetText("NO COMBAT DATA")
        self.zoneLabel:SetText("Enter combat, then reopen this report.")
        if self.titleLabel then self.titleLabel:SetText("COMBAT • " .. string.upper(PAGE_LABELS[self.currentPage or "OVERVIEW"] or "OVERVIEW")) end
        self:RefreshMetricStrip(nil)
        if self.summaryText then self.summaryText:SetText("") end
        if type(self.summaryRows) == "table" then
            for index, row in ipairs(self.summaryRows) do
                row:SetHidden(index ~= 1)
                if row.name then row.name:SetText(index == 1 and "No recorded fight" or "") end
                if row.value then row.value:SetText(index == 1 and "available yet" or "") row.value:SetHidden(index ~= 1) end
            end
        end
        self.statsText:SetText("")
        if type(self.statsRows) == "table" then for _, row in ipairs(self.statsRows) do row:SetHidden(true) end end
        self.footer:SetText("Assign a key under Controls > Keybindings > ESO Adventurer Suite.")
        for _, rows in ipairs({ self.buffRows, self.targetRows, self.abilityRows, self.graphRows }) do for _, row in ipairs(rows or {}) do row:SetHidden(true) end end
        return
    end

    self.currentReport = report
    if self.modeIcon then self.modeIcon:SetTexture(MODE_ICONS[report.modeKey] or DEFAULT_ICON) end
    if self.modeLabel then self.modeLabel:SetText(string.format("%s • %s", tostring(report.modeLabel or "GAME MODE"), tostring(report.difficulty or "STANDARD"))) end
    if self.zoneLabel then self.zoneLabel:SetText(tostring(report.zone or "Unknown Location")) end
    if self.titleLabel then
        local pageName = string.upper(PAGE_LABELS[self.currentPage or "OVERVIEW"] or "OVERVIEW")
        self.titleLabel:SetText((report.live and "LIVE • " or "COMBAT • ") .. pageName)
    end
    self:RefreshMetricStrip(report)
    self:RefreshSummaryRows(report)
    if self.statsText then self.statsText:SetText(self:BuildStatsText(report)) end
    self:RefreshStatsRows(report)
    self:RefreshBuffRows(report)
    self:RefreshTargetRows(report)
    self:RefreshAbilityRows(report)
    self:RefreshGraphRows(report)
    if self.previousButton then
        self.previousButton:SetEnabled(self.viewIndex < #reports)
        self.previousButton:SetAlpha(self.viewIndex < #reports and 1 or 0.35)
    end
    if self.nextButton then
        self.nextButton:SetEnabled(self.viewIndex > 1)
        self.nextButton:SetAlpha(self.viewIndex > 1 and 1 or 0.35)
    end
    if self.footer then
        self.footer:SetText(string.format("%s • %s • %s • %d / %d",
            cleanName(report.character or "Player"), tostring(report.modeLabel or "Mode"), string.upper(PAGE_LABELS[self.currentPage or "OVERVIEW"] or "OVERVIEW"), self.viewIndex, math.max(1, #reports)))
    end
end

function R:ShowOlder()
    local reports = self:GetAvailableReports()
    self.viewIndex = math.min(#reports, (self.viewIndex or 1) + 1)
    self:Refresh()
end

function R:ShowNewer()
    self.viewIndex = math.max(1, (self.viewIndex or 1) - 1)
    self:Refresh()
end

function R:SetUIMode(active)
    active = active == true
    local changed = false
    if type(SetGameCameraUIMode) == "function" then changed = safe(SetGameCameraUIMode, false, active) ~= false or changed end
    if SCENE_MANAGER and type(SCENE_MANAGER.SetInUIMode) == "function" then
        local ok = pcall(SCENE_MANAGER.SetInUIMode, SCENE_MANAGER, active)
        changed = ok or changed
    end
    return changed
end

function R:Show()
    if not EPC.saved or EPC.saved.gameModeReportEnabled == false then
        if EPC.Print then EPC:Print("Game Mode Combat Report is disabled. Enable it under Suite Settings > Combat, Role & Builds.") end
        return
    end
    if not self:EnsureWindow() then
        if EPC.Print then EPC:Print("Game Mode Combat Report could not open because its UI failed to initialize. See the previous EAS error for the exact cause.") end
        return
    end
    local already = safe(IsGameCameraUIModeActive, false) == true
    self.ownsUIMode = not already
    if not already then self:SetUIMode(true) end
    self.window:SetAlpha(clamp(EPC.saved.gameModeReportAlpha or 0.96, 0.45, 1.0))
    self.window:SetHidden(false)
    self.viewIndex = 1
    if not self.actionLayerPushed and type(PushActionLayerByName) == "function" then
        local ok = pcall(PushActionLayerByName, "ESOAdventurerSuiteGameModeReportLayer")
        if ok then self.actionLayerPushed = true end
    end
    self:Refresh()
end

function R:Hide()
    if self.window then self.window:SetHidden(true) end
    if self.actionLayerPushed and type(RemoveActionLayerByName) == "function" then
        pcall(RemoveActionLayerByName, "ESOAdventurerSuiteGameModeReportLayer")
        self.actionLayerPushed = false
    end
    if self.ownsUIMode then self:SetUIMode(false) end
    self.ownsUIMode = false
end

function R:Toggle()
    if not self:IsUIReady() or not self.window or self.window:IsHidden() then self:Show() else self:Hide() end
end

function R:ClearHistory()
    if EPC.saved then EPC.saved.gameModeReports = {} end
    self.viewIndex = 1
    if self.window and not self.window:IsHidden() then self:Refresh() end
end

function R:RefreshSettings()
    if self.window then
        self.window:SetAlpha(clamp(EPC.saved and EPC.saved.gameModeReportAlpha or 0.96, 0.45, 1.0))
        if EPC.saved and EPC.saved.gameModeReportEnabled == false then self:Hide() end
    end
end

function R:Initialize()
    self:EnsureSaved()
    self:EnsureWindow()
    self.viewIndex = 1
    self.currentPage = self.currentPage or "OVERVIEW"
    EPC.Runtime:RegisterUpdate("GameModeReport", "Refresh", 500, function()
        if not self.window or self.window:IsHidden() then return end
        -- HUD Layout is a frozen preview. Do not repaint live numbers while the
        -- user is positioning the report; this prevents visible value flashing.
        if EPC and EPC.unitFramesMoveMode then return end
        -- v0.29.763: completed Combat Reports are immutable snapshots.
        -- Repainting them twice per second caused right-edge values to visibly
        -- flicker even though the report itself was not changing.
        if self.currentReport and self.currentReport.live == true then
            self:Refresh()
        end
    end)
end

function ESOAdventurerSuite_ToggleGameModeReport()
    if EPC.GameModeReport then EPC.GameModeReport:Toggle() end
end
