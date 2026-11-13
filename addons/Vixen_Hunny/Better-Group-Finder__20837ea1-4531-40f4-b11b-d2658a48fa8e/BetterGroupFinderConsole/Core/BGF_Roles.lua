-- BGF_Roles.lua
-- Automatic role composition, plus the auto-generated title and description.

local BGF = BetterGroupFinderConsole
local U = BGF.util
local A = BGF.Activities

BGF.Roles = {}
local R = BGF.Roles

R.TANK = LFG_ROLE_TANK
R.HEAL = LFG_ROLE_HEAL
R.DPS = LFG_ROLE_DPS
R.ANY = LFG_ROLE_INVALID
R.ORDER = { LFG_ROLE_TANK, LFG_ROLE_HEAL, LFG_ROLE_DPS }
R.ALL = { LFG_ROLE_TANK, LFG_ROLE_HEAL, LFG_ROLE_DPS, LFG_ROLE_INVALID }

R.INFO = {
    [LFG_ROLE_TANK] = { short = "T", name = "Tank", plural = "Tanks", color = "5DADE2",
        icon = "EsoUI/Art/LFG/LFG_icon_tank.dds", gpIcon = "EsoUI/Art/LFG/Gamepad/LFG_roleIcon_tank.dds" },
    [LFG_ROLE_HEAL] = { short = "H", name = "Healer", plural = "Healers", color = "58D68D",
        icon = "EsoUI/Art/LFG/LFG_icon_healer.dds", gpIcon = "EsoUI/Art/LFG/Gamepad/LFG_roleIcon_healer.dds" },
    [LFG_ROLE_DPS] = { short = "D", name = "DPS", plural = "DPS", color = "EC7063",
        icon = "EsoUI/Art/LFG/LFG_icon_dps.dds", gpIcon = "EsoUI/Art/LFG/Gamepad/LFG_roleIcon_dps.dds" },
    [LFG_ROLE_INVALID] = { short = "A", name = "Any role", plural = "Any role", color = "D5D8DC",
        icon = "EsoUI/Art/LFG/LFG_icon_dps.dds", gpIcon = "EsoUI/Art/LFG/Gamepad/LFG_roleIcon_dps.dds" },
}

function R:Info(role)
    return self.INFO[role] or self.INFO[LFG_ROLE_INVALID]
end

function R:Icon(role, size)
    local info = self:Info(role)
    size = size or 20
    if role == LFG_ROLE_INVALID then
        return U.Colorize(info.color, "?")
    end
    local path = BGF:IsGamepad() and info.gpIcon or info.icon
    return zo_iconFormat(path, size, size)
end

function R:Colored(role, text)
    return U.Colorize(self:Info(role).color, text)
end

---------------------------------------------------------------------------
-- Templates
---------------------------------------------------------------------------
-- Returns { [TANK]=n, [HEAL]=n, [DPS]=n, [ANY]=n } summing to numRoles.
function R:Template(numRoles, intent, activity)
    numRoles = math.max(1, tonumber(numRoles) or 4)
    local style = intent and intent.roleStyle or "standard"
    local t, h, d = 0, 0, 0

    local base = activity and activity.roles
    -- The default trial makeup follows the settings; activities with their
    -- own makeup (e.g. Aetherian Archive) keep it.
    local sv = BGF.sv or {}
    local trialT, trialH = sv.trialTanks or 2, sv.trialHealers or 2
    if base == A.TRIAL_DEFAULT then
        base = { trialT, trialH, 12 - trialT - trialH }
    end
    if style == "any" then
        -- everything flexible
    elseif base and (base[1] + base[2] + base[3]) == numRoles then
        t, h, d = base[1], base[2], base[3]
    elseif style == "pvp" then
        h = math.max(1, zo_round(numRoles / 4))
        t = numRoles >= 8 and 1 or 0
        d = numRoles - h - t
    elseif style == "flex" then
        if numRoles >= 4 then
            t, h = 1, 1
            d = numRoles - 2
        end
    else
        if numRoles == 1 then
            d = 1
        elseif numRoles == 2 then
            h, d = 1, 1
        elseif numRoles == 3 then
            t, h, d = 1, 1, 1
        elseif numRoles <= 6 then
            t, h = 1, 1
            d = numRoles - 2
        elseif numRoles == 12 then
            t, h = trialT, trialH
            d = numRoles - t - h
        else
            t = math.max(1, math.floor(numRoles / 6))
            h = math.max(1, math.ceil(numRoles / 6))
            d = numRoles - t - h
        end
    end

    local out = { [self.TANK] = t, [self.HEAL] = h, [self.DPS] = math.max(0, d) }
    out[self.ANY] = math.max(0, numRoles - t - h - out[self.DPS])
    return out
end

-- Makes a composition fit the size and the roles already in your group:
-- every role keeps at least the members you already have, overflow is
-- taken from DPS first, then healers, then tanks; leftovers become "Any".
function R:Fit(roles, numRoles, attained)
    attained = attained or {}
    local out = {}
    local total = 0
    for _, role in ipairs(self.ORDER) do
        out[role] = math.max(roles[role] or 0, attained[role] or 0)
        total = total + out[role]
    end
    local trimOrder = { self.DPS, self.HEAL, self.TANK }
    local guard = 0
    while total > numRoles and guard < 100 do
        guard = guard + 1
        local trimmed = false
        for _, role in ipairs(trimOrder) do
            if out[role] > (attained[role] or 0) then
                out[role] = out[role] - 1
                total = total - 1
                trimmed = true
                break
            end
        end
        if not trimmed then break end
    end
    out[self.ANY] = math.max(0, numRoles - total)
    return out
end

-- Roles still open (desired - attained), as a table and a total.
function R:Open(desired, attained)
    local open, total = {}, 0
    for _, role in ipairs(self.ALL) do
        local n = math.max(0, (desired[role] or 0) - (attained[role] or 0))
        open[role] = n
        total = total + n
    end
    return open, total
end

-- "2T 2H 8D" / "1T 1H 2D 1A"
function R:Compact(roles, colored)
    local parts = {}
    for _, role in ipairs(self.ALL) do
        local n = roles[role] or 0
        if n > 0 then
            local text = n .. self:Info(role).short
            parts[#parts + 1] = colored and self:Colored(role, text) or text
        end
    end
    return table.concat(parts, " ")
end

-- "1 Tank, 2 DPS"
function R:Long(roles)
    local parts = {}
    for _, role in ipairs(self.ALL) do
        local n = roles[role] or 0
        if n > 0 then
            local info = self:Info(role)
            parts[#parts + 1] = string.format("%d %s", n, n == 1 and info.name or info.plural)
        end
    end
    if #parts == 0 then return "nobody (full)" end
    return table.concat(parts, ", ")
end

-- Icons for open slots, e.g. [T][D][D]
function R:OpenIcons(open, size, maxIcons)
    local parts = {}
    maxIcons = maxIcons or 12
    for _, role in ipairs(self.ALL) do
        for _ = 1, (open[role] or 0) do
            if #parts >= maxIcons then break end
            parts[#parts + 1] = self:Icon(role, size)
        end
    end
    return table.concat(parts, "")
end

---------------------------------------------------------------------------
-- Auto title / description
---------------------------------------------------------------------------
local TITLE_MAX = GROUP_FINDER_GROUP_LISTING_TITLE_MAX_LENGTH or 40
local DESC_MAX = GROUP_FINDER_GROUP_LISTING_DESCRIPTION_MAX_LENGTH or 300

local function Fits(text, max)
    return ZoUTF8StringLength and ZoUTF8StringLength(text) <= max or #text <= max
end

R.AD_TEXT = "Created using Better Group Finder"

local function Len(text)
    return ZoUTF8StringLength and ZoUTF8StringLength(text) or #text
end

-- Cuts text to max characters (UTF-8 safe when the game helper exists).
local function Cut(text, max)
    if Len(text) <= max then return text end
    if ZoUTF8StringSub then return ZoUTF8StringSub(text, 1, max) end
    return string.sub(text, 1, max)
end

-- Appends the "Created using Better Group Finder" line (once), shortening
-- the text before it so the whole description stays within the limit.
function R:WithAd(text)
    text = U.Trim(text)
    if BGF.sv and BGF.sv.descIncludeAd == false then return text end
    if zo_plainstrfind(text, self.AD_TEXT) then return text end
    local room = DESC_MAX - Len(self.AD_TEXT) - 1
    if room <= 0 then return Cut(self.AD_TEXT, DESC_MAX) end
    text = U.Trim(Cut(text, room))
    if text == "" then return self.AD_TEXT end
    return text .. " " .. self.AD_TEXT
end

-- Removes the ad line (used when the setting is turned off).
function R:WithoutAd(text)
    text = tostring(text or "")
    local s, e = zo_plainstrfind(text, self.AD_TEXT)
    if not s then return text end
    return U.Trim(text:sub(1, s - 1) .. text:sub(e + 1))
end

local function IsValidTitle(text)
    if not IsValidGroupFinderListingTitle then return true end
    local ok, firstViolation = pcall(IsValidGroupFinderListingTitle, text)
    return ok and firstViolation == nil
end

-- ctx = { intent, activityName, isVeteran, open = roles table, cp, hm }
function R:BuildTitle(ctx)
    local intent = ctx.intent or {}
    local label = ctx.activityName and ctx.activityName ~= "" and A:ShortLabel(ctx.activityName, ctx.isVeteran) or intent.name or "Group"
    local tag = intent.tag
    if tag == "Vet" or tag == "Normal" then tag = nil end -- already in vX / nX

    local need = self:Compact(ctx.open or {})
    local candidates = {}
    local function Push(...)
        local parts = {}
        for i = 1, select("#", ...) do
            local p = select(i, ...)
            if p and p ~= "" then parts[#parts + 1] = p end
        end
        candidates[#candidates + 1] = table.concat(parts, " ")
    end

    local sv = BGF.sv or {}
    local cpText = (sv.titleIncludeCP ~= false and ctx.cp and ctx.cp > 0) and ("CP" .. ctx.cp .. "+") or nil
    local needText = (sv.titleIncludeRoles ~= false and need ~= "") and ("LF " .. need) or nil
    Push(label, tag, needText, cpText)
    Push(label, tag, needText)
    Push(label, needText)
    Push(label, tag)
    Push(intent.name)
    Push("Group")

    for _, text in ipairs(candidates) do
        text = text:gsub("%s+", " ")
        if text ~= "" and Fits(text, TITLE_MAX) and IsValidTitle(text) then
            return text
        end
    end
    -- Last resort: hard cut.
    return string.sub(candidates[1] or "Group", 1, TITLE_MAX)
end

function R:BuildDescription(ctx)
    local intent = ctx.intent or {}
    local lines = {}
    local function Line(text)
        if text and text ~= "" then lines[#lines + 1] = text end
    end

    if (BGF.sv == nil or BGF.sv.descIncludeActivity ~= false) and ctx.activityName and ctx.activityName ~= "" then
        Line(string.format("%s%s", ctx.activityName, ctx.difficultyText and ctx.difficultyText ~= "" and (" (" .. ctx.difficultyText .. ")") or ""))
    end
    for _, l in ipairs(intent.lines or {}) do Line(l) end
    Line("Need: " .. self:Long(ctx.open or {}) .. ".")
    if ctx.cp and ctx.cp > 0 then
        Line(string.format("CP %d+.", ctx.cp))
    end
    if ctx.voip then Line("Voice chat required.") end
    Line(U.Trim(ctx.extraNotes))

    return self:WithAd(table.concat(lines, " "))
end
