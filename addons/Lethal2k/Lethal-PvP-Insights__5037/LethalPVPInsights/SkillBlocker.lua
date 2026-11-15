-- Lethal PVP Insights - Skill Blocker: stop skills on your bars from being cast by accident, or from being
-- recast while their effect is still running. Pick skills from dropdowns (your bars, or any skill line).
-- Works like LibSkillBlocker: a pre-hook on the action bar's "can use" check, so nothing is cast at all.
local PDI = PVPDataInsight
local B = {}
PDI.SkillBlocker = B

local function cfg()
    local s = PDI.sv.settings
    s.skillBlock = s.skillBlock or {}
    local c = s.skillBlock
    c.blocked = c.blocked or {}
    c.recast = c.recast or {}
    if c.enabled == nil then c.enabled = true end
    if c.pvp == nil then c.pvp = true end
    if c.showError == nil then c.showError = true end
    c.recastSeconds = tonumber(c.recastSeconds) or 0
    return c
end

local function cleanName(id)
    return zo_strformat("<<1>>", GetAbilityName(id) or "")
end

local function key(name) return zo_strlower(name or "") end

-- names of the chosen skills, so every rank / variant of a skill matches
function B:Rebuild()
    local c = cfg()
    self.blockNames, self.recastNames = {}, {}
    for id, name in pairs(c.blocked) do self.blockNames[key(name ~= "" and name or cleanName(id))] = true end
    for id, name in pairs(c.recast) do self.recastNames[key(name ~= "" and name or cleanName(id))] = true end
    self.any = next(c.blocked) ~= nil or next(c.recast) ~= nil
end

local function slotAbility(slot)
    local id = GetSlotBoundId(slot)
    if not id or id == 0 then return nil end
    if GetSlotType(slot) == ACTION_TYPE_CRAFTED_ABILITY and GetAbilityIdForCraftedAbilityId then
        id = GetAbilityIdForCraftedAbilityId(id)
    end
    return id
end

local function inPvP() return IsPlayerInAvAWorld() or IsActiveWorldBattleground() end

function B:IsSlotBlocked(slot)
    local c = cfg()
    if not c.enabled or not self.any then return false end
    if not c.pvp and inPvP() then return false end
    local id = slotAbility(slot)
    if not id then return false end
    local name = key(cleanName(id))
    if c.blocked[id] or self.blockNames[name] then return true end
    if c.recast[id] or self.recastNames[name] then
        local left = GetActionSlotEffectTimeRemaining(slot) or 0
        return left > c.recastSeconds * 1000
    end
    return false
end

-- the key that was pressed is only visible in the call stack (same trick as LibSkillBlocker)
local function canUseHook()
    if not B.any then return false end
    local slot = tonumber(debug.traceback():match('keybind = ".*ACTION_BUTTON_(%d)'))
    if not slot or not B:IsSlotBlocked(slot) then return false end
    if cfg().showError then ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, SI_RESPECRESULT6) end
    ZO_ActionBar_OnActionButtonUp(slot)
    return true
end

function B:Init()
    self:Rebuild()
    if ZO_ActionBar_CanUseActionSlots then ZO_PreHook("ZO_ActionBar_CanUseActionSlots", canUseHook) end
end

-- ---------------------------------------------------------------- picking a skill
local pick = { type = nil, line = nil, id = nil }

local SKILL_TYPES = {
    SKILL_TYPE_CLASS, SKILL_TYPE_WEAPON, SKILL_TYPE_ARMOR, SKILL_TYPE_WORLD,
    SKILL_TYPE_GUILD, SKILL_TYPE_AVA, SKILL_TYPE_RACIAL,
}

local function typeChoices()
    local names, values = {}, {}
    for _, t in ipairs(SKILL_TYPES) do
        if t then names[#names + 1] = GetString("SI_SKILLTYPE", t); values[#values + 1] = t end
    end
    return names, values
end

local function lineChoices()
    local names, values = {}, {}
    if not pick.type then return names, values end
    for i = 1, GetNumSkillLines(pick.type) do
        local name = GetSkillLineInfo(pick.type, i)
        if name and name ~= "" then
            names[#names + 1] = zo_strformat("<<1>>", name); values[#values + 1] = i
        end
    end
    return names, values
end

local function abilityId(t, line, idx, morph)
    for _, rank in ipairs({ 4, 1, 0 }) do
        local ok, id = pcall(GetSpecificSkillAbilityInfo, t, line, idx, morph, rank)
        if ok and id and id ~= 0 then return id end
    end
end

local function skillChoices()
    local names, values = {}, {}
    if not (pick.type and pick.line) then return names, values end
    for idx = 1, GetNumSkillAbilities(pick.type, pick.line) do
        if not IsSkillAbilityPassive(pick.type, pick.line, idx) then
            for morph = 0, 2 do
                local id = abilityId(pick.type, pick.line, idx, morph)
                if id then
                    names[#names + 1] = zo_iconFormat(GetAbilityIcon(id), 20, 20) .. " " .. cleanName(id) ..
                        (morph == 0 and "" or ("  |c999999(morph " .. morph .. ")|r"))
                    values[#values + 1] = id
                end
            end
        end
    end
    return names, values
end

local function barChoices()
    local names, values, seen = {}, {}, {}
    local cats = { HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }
    for _, cat in ipairs(cats) do
        for slot = 3, 8 do
            local ok, id = pcall(GetSlotBoundId, slot, cat)
            local okT, st = pcall(GetSlotType, slot, cat)
            if ok and id and id ~= 0 then
                if okT and st == ACTION_TYPE_CRAFTED_ABILITY and GetAbilityIdForCraftedAbilityId then
                    id = GetAbilityIdForCraftedAbilityId(id)
                end
                if not seen[id] then
                    seen[id] = true
                    names[#names + 1] = zo_iconFormat(GetAbilityIcon(id), 20, 20) .. " " .. cleanName(id) ..
                        (cat == HOTBAR_CATEGORY_BACKUP and "  |c999999(back bar)|r" or "  |c999999(front bar)|r")
                    values[#values + 1] = id
                end
            end
        end
    end
    return names, values
end

local function listText(t)
    local rows = {}
    for id, name in pairs(t) do
        rows[#rows + 1] = zo_iconFormat(GetAbilityIcon(id), 22, 22) .. " " .. (name ~= "" and name or cleanName(id))
    end
    table.sort(rows)
    return #rows > 0 and table.concat(rows, "\n") or "|c999999None yet.|r"
end

local removePick
local function removeChoices()
    local names, values = {}, {}
    local c = cfg()
    for id, name in pairs(c.blocked) do names[#names + 1] = "Blocked: " .. name; values[#values + 1] = "b" .. id end
    for id, name in pairs(c.recast) do names[#names + 1] = "Recast: " .. name; values[#values + 1] = "r" .. id end
    return names, values
end

local function add(list, what)
    if not pick.id then PDI.Msg("Choose a skill first."); return end
    local c = cfg()
    local name = cleanName(pick.id)
    c[list][pick.id] = name
    B:Rebuild()
    PDI.Msg(string.format("%s: %s", what, name))
end

function B:GetOptions()
    local c = function() return cfg() end
    local opts = {
        { type = "header", name = "Skill Blocker" },
        {
            type = "description",
            text = "Choose skills from your bars or from any skill line below. A |cFFFFFFblocked|r skill can't be cast " ..
                "from your bar at all. With |cFFFFFFrecast prevention|r a skill can't be cast again while its effect is still running.",
        },
        {
            type = "checkbox", name = "Enable Skill Blocker",
            getFunc = function() return c().enabled end,
            setFunc = function(v) c().enabled = v end,
        },
        {
            type = "checkbox", name = "Also block in PvP areas",
            tooltip = "When off, nothing is blocked in Cyrodiil, Imperial City and Battlegrounds.",
            getFunc = function() return c().pvp end,
            setFunc = function(v) c().pvp = v end,
            disabled = function() return not c().enabled end,
        },
        {
            type = "checkbox", name = "Show an error when a skill is blocked",
            getFunc = function() return c().showError end,
            setFunc = function(v) c().showError = v end,
            disabled = function() return not c().enabled end,
        },
        {
            type = "slider", name = "Prevent recast until less than (seconds) remain",
            tooltip = "0 = only when the effect has ended. For example 2 lets you recast during the last 2 seconds.",
            min = 0, max = 10, step = 0.5,
            getFunc = function() return c().recastSeconds end,
            setFunc = function(v) c().recastSeconds = v end,
            disabled = function() return not c().enabled end,
        },

        { type = "header", name = "Choose a skill" },
        {
            type = "dropdown", name = "From your action bars",
            choices = function() return (barChoices()) end,
            choicesValues = function() return select(2, barChoices()) end,
            placeholder = "-",
            getFunc = function() return pick.id end,
            setFunc = function(v) pick.id = v end,
        },
        {
            type = "dropdown", name = "Or: skill type",
            choices = function() return (typeChoices()) end,
            choicesValues = function() return select(2, typeChoices()) end,
            placeholder = "-",
            getFunc = function() return pick.type end,
            setFunc = function(v) if pick.type ~= v then pick.type, pick.line = v, nil end end,
        },
        {
            type = "dropdown", name = "Skill line",
            choices = function() return (lineChoices()) end,
            choicesValues = function() return select(2, lineChoices()) end,
            placeholder = "-",
            getFunc = function() return pick.line end,
            setFunc = function(v) pick.line = v end,
            disabled = function() return pick.type == nil end,
        },
        {
            type = "dropdown", name = "Skill",
            choices = function() return (skillChoices()) end,
            choicesValues = function() return select(2, skillChoices()) end,
            placeholder = "-",
            getFunc = function() return pick.id end,
            setFunc = function(v) pick.id = v end,
            disabled = function() return pick.line == nil end,
        },
        {
            type = "description",
            text = function()
                if not pick.id then return "|c999999No skill chosen.|r" end
                return "Chosen: " .. zo_iconFormat(GetAbilityIcon(pick.id), 26, 26) .. " |cFFFFFF" .. cleanName(pick.id) .. "|r"
            end,
        },
        {
            type = "button", name = "Block this skill", width = "half",
            func = function() add("blocked", "Blocked") end,
            disabled = function() return pick.id == nil end,
        },
        {
            type = "button", name = "Prevent recast", width = "half",
            func = function() add("recast", "Recast prevented") end,
            disabled = function() return pick.id == nil end,
        },

        { type = "header", name = "Blocked skills" },
        { type = "description", text = function() return listText(c().blocked) end },
        { type = "header", name = "Recast prevention" },
        { type = "description", text = function() return listText(c().recast) end },
        {
            type = "dropdown", name = "Remove a skill",
            choices = function() return (removeChoices()) end,
            choicesValues = function() return select(2, removeChoices()) end,
            placeholder = "-",
            getFunc = function() return removePick end,
            setFunc = function(v) removePick = v end,
        },
        {
            type = "button", name = "Remove", width = "half",
            disabled = function() return removePick == nil end,
            func = function()
                local list = removePick:sub(1, 1) == "b" and "blocked" or "recast"
                local id = tonumber(removePick:sub(2))
                cfg()[list][id] = nil
                removePick = nil
                B:Rebuild()
            end,
        },
    }
    return opts
end
