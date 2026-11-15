-- Import of HyperTools export strings.
--
-- HyperTools (Transmission.lua) exports a tracker table as nested "$<type><value>&" tokens: a table
-- is "$" followed by key/value pairs and a closing "&"; scalars are "$N<number>&", "$B<true|false>&",
-- "$S<string>&" (strings are not escaped). The tracker fields are the ones of HT_trackers (Default.lua):
-- type, name, text, icon, target, targetNumber, sizeX, sizeY, xOffset, yOffset, colours, font,
-- fontSize, fontWeight, decimals, timer1 (timer), timer2 (stacks), inverse, vertical, hideIcon,
-- drawLevel, conditions, events, load, children, parent.
--
-- Every HyperTools tracker becomes a DebuffTracker tracker; Groups are flattened (children keep their
-- screen position, the group's load conditions are merged into them); "Group Member" children become
-- "above heads" trackers. What can't be carried over is listed in the returned notes.

local DT = DebuffTracker
local HT = {}
DT.HyperTools = HT
local U = DT.Util
local S = DT.Schema
local L = DT.L

------------------------------------------------------------------------------
-- Parser
------------------------------------------------------------------------------

local MAX_DEPTH = 40

local function ParseValue(s, i, depth)
    if depth > MAX_DEPTH then error("too deep", 0) end
    if s:sub(i, i) ~= "$" then error("expected $ at " .. i, 0) end
    local c = s:sub(i + 1, i + 1)
    if c == "N" or c == "B" or c == "S" then
        local j = s:find("&", i + 2, true)
        if not j then error("unterminated value", 0) end
        local raw = s:sub(i + 2, j - 1)
        if c == "N" then return tonumber(raw) or 0, j + 1 end
        if c == "B" then return raw == "true", j + 1 end
        return raw, j + 1
    elseif c == "&" then
        return {}, i + 2
    elseif c == "$" then
        local t = {}
        local k = i + 1
        while s:sub(k, k) == "$" do
            local key, val
            key, k = ParseValue(s, k, depth + 1)
            val, k = ParseValue(s, k, depth + 1)
            if type(key) ~= "table" then t[key] = val end
        end
        if s:sub(k, k) ~= "&" then error("expected & at " .. k, 0) end
        return t, k + 1
    end
    error("unknown token at " .. i, 0)
end

function HT.LooksLike(text)
    text = U.Trim(text or "")
    return text:sub(1, 2) == "$$"
end

-- Returns the HyperTools tracker table, or nil + error.
function HT.Parse(text)
    text = U.Trim(text or ""):gsub("[\r\n]", "")
    if not HT.LooksLike(text) then return nil, L("Not a HyperTools string") end
    local ok, value, nextIndex = pcall(ParseValue, text, 1, 0)
    if not ok then return nil, L("Damaged HyperTools string (<<1>>)", tostring(value)) end
    if type(value) ~= "table" or not value.type then return nil, L("Not a HyperTools tracker") end
    return value
end

------------------------------------------------------------------------------
-- Conversion
------------------------------------------------------------------------------

local CLASS_IDS = { Dragonknight = 1, Sorcerer = 2, Nightblade = 3, Warden = 4, Necromancer = 5, Templar = 6, Arcanist = 117 }
local ROLE_NAMES = { [1] = "dps", [2] = "tank", [4] = "healer" }
local FONT_EFFECTS = { ["soft-shadow-thick"] = true, ["soft-shadow-thin"] = true, ["thick-outline"] = true, ["shadow"] = true }

local ARG_MAP = { ["Remaining Time"] = "remaining", ["Stacks"] = "stacks", ["Group Role"] = "role", ["Distance to target"] = "distance" }
local RESULT_MAP = {
    ["Set Bar Color"] = "color", ["Set Text Color"] = "textColor", ["Set Timer Color"] = "timerColor",
    ["Set Stacks Color"] = "stackColor", ["Set Background Color"] = "background", ["Set Border Color"] = "glow",
    ["Hide Tracker"] = "hide", ["Show Proc"] = "proc",
}

local function Color(c, fallback)
    if type(c) == "table" and tonumber(c[1]) then
        return { tonumber(c[1]) or 1, tonumber(c[2]) or 1, tonumber(c[3]) or 1, tonumber(c[4]) or 1 }
    end
    return fallback
end

local function List(t)
    local out = {}
    if type(t) ~= "table" then return out end
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do out[#out + 1] = t[k] end
    return out
end

local function Note(notes, text)
    for _, n in ipairs(notes) do if n == text then return end end
    notes[#notes + 1] = text
end

-- HT target -> scope (+ unit index)
local function Scope(ht, inGroupMember)
    if inGroupMember then return "group", 0 end
    local target, n = ht.target, math.floor(tonumber(ht.targetNumber) or 0)
    if target == "Yourself" then return "player", 0 end
    if target == "Current Target" then return "target", 0 end
    if target == "Boss" then return "boss", (n >= 1 and n <= 6) and n or 0 end
    if target == "Group" then return "group", (n >= 1 and n <= 12) and n or 0 end
    return "player", 0
end

-- HT events -> DT triggers (main + extras)
local function Triggers(ht, scope, unitIndex, notes, hiddenWhenZero)
    local triggers = {}
    for _, ev in ipairs(List(ht.events)) do
        local a = type(ev.arguments) == "table" and ev.arguments or {}
        local ids = {}
        for _, id in ipairs(List(a.Ids)) do
            local n = tonumber(id)
            if n and n > 0 then ids[#ids + 1] = n end
        end
        if type(a.luaCodeToExecute) == "string" and U.Trim(a.luaCodeToExecute) ~= "" then
            Note(notes, L("Custom Lua code in HyperTools events isn't imported (it could run anything)."))
        end
        if ev.type == "Get Effect Duration" then
            triggers[#triggers + 1] = {
                type = "effect", abilityIds = ids, scope = scope, unitIndex = unitIndex,
                source = a.onlyYourCast and "me" or "any", effectType = "any",
                mode = hiddenWhenZero and "present" or "always", perAbility = false,
            }
        elseif ev.type == "Get Effect Cooldown" then
            triggers[#triggers + 1] = {
                type = "combat", abilityIds = ids, combatSource = a.onlyYourCast and "me" or "any",
                duration = math.max(0.1, tonumber(a.cooldown) or 10), restartOnRefresh = true,
                showReady = not hiddenWhenZero,
            }
        elseif ev.type == "Entering/Exiting Combat" then
            Note(notes, L("\"Entering/Exiting Combat\" events only ran custom Lua; use the Load tab's combat setting instead."))
        end
    end
    if #triggers == 0 then
        triggers[1] = { type = "effect", abilityIds = {}, scope = scope, unitIndex = unitIndex, mode = "present" }
        Note(notes, L("\"<<1>>\" had no ability IDs; add them on the Trigger tab.", tostring(ht.name)))
    end
    return triggers
end

-- HT conditions -> DT rules. "Hide when remaining time is 0 / below 0.1" is how HyperTools users
-- hide inactive trackers: that becomes "Show while active" instead of a rule.
local function Conditions(ht, notes)
    local rules, hiddenWhenZero = {}, false
    for _, c in ipairs(List(ht.conditions)) do
        local prop, action = ARG_MAP[c.arg1], RESULT_MAP[c.result]
        local value = c.arg2
        if prop == "remaining" and action == "hide" and tonumber(value)
            and ((c.operator == "==" and tonumber(value) == 0) or (c.operator == "<=" and tonumber(value) <= 0.1)
                 or (c.operator == "<" and tonumber(value) <= 0.1)) then
            hiddenWhenZero = true
        elseif prop and action then
            if prop == "role" then value = ROLE_NAMES[tonumber(value) or -1] or tostring(value) end
            local rule = { prop = prop, op = c.operator or "<=", value = value, action = action }
            if action == "color" or action == "textColor" or action == "timerColor" or action == "stackColor"
                or action == "background" or action == "glow" then
                rule.arg = Color(c.resultArguments, { 1, 0, 0, 1 })
            end
            rules[#rules + 1] = rule
        else
            Note(notes, L("A condition (<<1>> -> <<2>>) has no equivalent and was skipped.", tostring(c.arg1), tostring(c.result)))
        end
    end
    return rules, hiddenWhenZero
end

local function Load(ht, notes, parentLoad)
    local l = type(ht.load) == "table" and ht.load or {}
    local out = { roles = {}, classes = {}, skills = {}, bossNames = {}, zoneNames = {} }
    if l.inCombat then out.combat = "in" end
    local role = ROLE_NAMES[tonumber(l.role) or 0]
    if role then out.roles[role] = true end
    if type(l.class) == "string" and CLASS_IDS[l.class] then out.classes[CLASS_IDS[l.class]] = true end
    -- HyperTools' "!" in front of an entry = "never when it matches" (Tony). DebuffTracker switches a whole list to
    -- "Never when"; a list that mixes both keeps the plain entries (a note says which were left out).
    out.never = {}
    local function Split(list, what)
        local pos, neg = {}, {}
        for _, v in ipairs(List(list)) do
            if type(v) == "string" and v:sub(1, 1) == "!" then
                local rest = U.Trim(v:sub(2))
                if rest ~= "" then neg[#neg + 1] = tonumber(rest) or rest end
            elseif v ~= nil and v ~= "" then
                pos[#pos + 1] = v
            end
        end
        if #neg > 0 and #pos == 0 then return neg, true end
        if #neg > 0 then Note(notes, L("A <<1>> load list mixed \"only\" and \"!\" (never) entries: only the plain ones were imported.", what)) end
        return pos, false
    end
    local skills, skillsNever = Split(l.skills, "skill")
    for _, v in ipairs(skills) do
        local n = tonumber(v)
        if n then out.skills[#out.skills + 1] = n
        elseif type(v) == "string" then
            out.skillNames = out.skillNames or {}
            out.skillNames[#out.skillNames + 1] = U.Lower(v)
        end
    end
    if skillsNever then out.never.skills = true end
    local bosses, bossesNever = Split(l.bosses, "boss")
    for _, b in ipairs(bosses) do
        if type(b) == "string" and b ~= "" then out.bossNames[#out.bossNames + 1] = U.Lower(b) end
    end
    if bossesNever then out.never.bosses = true end
    local zones, zonesNever = Split(l.zones, "zone")
    for _, z in ipairs(zones) do
        if type(z) == "string" and z ~= "" then out.zoneNames[#out.zoneNames + 1] = U.Lower(z) end
    end
    if zonesNever then out.never.zones = true end
    local sets = List(l.itemSets)
    if #sets > 0 then
        local link = sets[1]
        if type(link) == "string" and type(GetItemLinkSetInfo) == "function" then
            local hasSet, _, _, _, maxEquipped, setId = GetItemLinkSetInfo(link)
            if hasSet and setId then out.setId, out.setPieces = setId, tonumber(maxEquipped) or 5 end
        end
        if #sets > 1 then Note(notes, L("Only the first item set of a load condition is imported (DebuffTracker checks one set).")) end
    end
    -- a group's own load conditions apply to everything inside it
    if parentLoad then
        if parentLoad.combat == "in" then out.combat = "in" end
        for k in pairs(parentLoad.roles or {}) do out.roles[k] = true end
        for k in pairs(parentLoad.classes or {}) do out.classes[k] = true end
        for _, v in ipairs(parentLoad.skills or {}) do out.skills[#out.skills + 1] = v end
        for k in pairs(parentLoad.never or {}) do out.never[k] = true end
        for _, v in ipairs(parentLoad.bossNames or {}) do out.bossNames[#out.bossNames + 1] = v end
        for _, v in ipairs(parentLoad.zoneNames or {}) do out.zoneNames[#out.zoneNames + 1] = v end
        if (parentLoad.setId or 0) > 0 and not out.setId then out.setId, out.setPieces = parentLoad.setId, parentLoad.setPieces end
    end
    return out, l.never == true
end

local function Font(ht, ds)
    if type(ht.font) == "string" then
        for _, f in ipairs(DT.Const.FONT_FACES) do if f[1] == ht.font then ds.fontFace = ht.font end end
    end
    if tonumber(ht.fontSize) then ds.fontSize = tonumber(ht.fontSize) end
    if FONT_EFFECTS[ht.fontWeight] then ds.fontEffect = ht.fontWeight end
end

local function Convert(ht, ctx, out)
    local kind = ht.type
    if kind == "Group" or kind == "Group Member" then
        local load, never = Load(ht, ctx.notes, ctx.parentLoad)
        local childCtx = {
            notes = ctx.notes,
            x = ctx.x + (tonumber(ht.xOffset) or 0), y = ctx.y + (tonumber(ht.yOffset) or 0),
            parentLoad = load, parentNever = ctx.parentNever or never,
            inGroupMember = ctx.inGroupMember or kind == "Group Member",
        }
        for _, child in ipairs(List(ht.children)) do
            if type(child) == "table" and child.type then Convert(child, childCtx, out) end
        end
        if kind == "Group Member" and #List(ht.children) == 0 then
            Note(ctx.notes, L("The Group Member \"<<1>>\" was empty.", tostring(ht.name)))
        end
        return
    end

    local scope, unitIndex = Scope(ht, ctx.inGroupMember)
    local rules, hiddenWhenZero = Conditions(ht, ctx.notes)
    local triggers = Triggers(ht, scope, unitIndex, ctx.notes, hiddenWhenZero)
    local load, never = Load(ht, ctx.notes, ctx.parentLoad)
    local sizeX, sizeY = tonumber(ht.sizeX) or 40, tonumber(ht.sizeY) or 40
    local timeColor, stackColor, textColor = Color(ht.timeColor), Color(ht.stacksColor), Color(ht.textColor)
    local ds = {
        showTimer = ht.timer1 ~= false, showStacks = ht.timer2 ~= false,
        timeFormat = (tonumber(ht.decimals) or 1) > 0 and "tenths" or "seconds",
        drawLevel = math.max(0, math.min(10, math.floor(tonumber(ht.drawLevel) or 0))),
        showHeader = false, title = "",
        textColor = textColor, timerColor = timeColor, stackColor = stackColor,
        separateTextColors = timeColor ~= nil or stackColor ~= nil,
        background = Color(ht.backgroundColor, { 0, 0, 0, 0.4 }),
        colorMode = "solid", colorSolid = Color(ht.barColor, { 1, 1, 1, 1 }),
    }
    Font(ht, ds)

    if ctx.inGroupMember then
        ds.type, ds.iconSize, ds.maxShown = "heads", math.max(16, math.min(128, sizeX)), 3
        if kind ~= "Icon Tracker" then
            Note(ctx.notes, L("\"<<1>>\" was a <<2>> on group members; it's shown as icons above their heads.", tostring(ht.name), kind))
        end
    elseif kind == "Icon Tracker" then
        ds.type, ds.iconSize = "icons", math.max(16, math.min(200, sizeX))
    elseif kind == "Progress Bar" then
        ds.type = "bars"
        ds.width, ds.height = sizeX, sizeY
        ds.vertical = ht.vertical == true
        if ds.vertical then ds.width, ds.height = sizeY, sizeX end
        ds.fillReverse = ht.inverse == true
        ds.showRowIcon = ht.hideIcon ~= true
        ds.labelFormat = (type(ht.text) == "string" and ht.text ~= "") and ht.text or "{name}"
        ds.style = "classic"
    elseif kind == "Progress Texture" then
        ds.type, ds.iconSize = "icons", math.max(16, math.min(200, math.max(sizeX, sizeY)))
        ds.iconTimer = ht.vertical and "shrinkV" or "shrinkH"
        ds.forceIcon = type(ht.icon) == "string" and ht.icon ~= ""
    else
        Note(ctx.notes, L("Unknown HyperTools tracker type \"<<1>>\" imported as icons.", tostring(kind)))
        ds.type = "icons"
    end

    local t = {
        name = (type(ht.name) == "string" and ht.name ~= "") and ht.name or L("Imported"),
        enabled = not (never or ctx.parentNever),
        iconOverride = type(ht.icon) == "string" and ht.icon or "",
        trigger = triggers[1],
        extraTriggers = { unpack(triggers, 2) },
        display = ds,
        conditions = rules,
        load = load,
    }
    if not ctx.inGroupMember then
        -- HyperTools positions are top-left pixels from the screen's top-left corner
        local x = ctx.x + (tonumber(ht.xOffset) or 0)
        local y = ctx.y + (tonumber(ht.yOffset) or 0)
        t.position = { x = math.floor(x - GuiRoot:GetWidth() / 2 + 0.5), y = math.floor(y - GuiRoot:GetHeight() / 2 + 0.5) }
    end
    out[#out + 1] = S.Normalize(t)
end

-- Returns a list of DebuffTracker trackers + a list of notes, or nil + error.
function HT.Import(text)
    local ht, err = HT.Parse(text)
    if not ht then return nil, err end
    local out, notes = {}, {}
    local ok, e = pcall(Convert, ht, { notes = notes, x = 0, y = 0 }, out)
    if not ok then return nil, L("Couldn't convert the HyperTools tracker (<<1>>)", tostring(e)) end
    if #out == 0 then return nil, L("The HyperTools string had no trackers in it.") end
    return out, notes
end
