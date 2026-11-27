-- MANA Antiquarian by Beardborn
-- Antiquity leads window:
--   * by default only my leads, grouped by zone, current zone on top;
--   * "All leads" toggle adds missing leads with hints where to find them
--     (hints and some filters come from Display Leads if installed);
--   * one-click scrying and map, search, resizable window, set collection progress;
--   * zones from DLCs you do not own are hidden automatically (adjustable in settings);
--   * chat reminder about leads that expire soon.
-- Bonus: double-clicking a row in the Display Leads window starts scrying.
-- UI texts are English; translations live in lang/<language>.lua (see MANAAntiquarian.T).
-- AI disclosure: written with the help of an AI assistant (Claude by Anthropic) from the author's design;
-- tested in game and maintained by the author.
-- Global MANAAntiquarian is needed for the XML window handlers and the keybinding.

MANAAntiquarian = MANAAntiquarian or {}
local ML = MANAAntiquarian
local T = ML.T
ML.name = "MANAAntiquarian"
ML.displayName = "MANA Antiquarian"
ML.version = "1.0.1"
ML.author = "Beardborn"

ZO_CreateStringId("SI_BINDING_NAME_MANA_ANTIQUARIAN_TOGGLE", T"Open MANA Antiquarian")

local SV_VERSION = 1
local DEFAULTS = {
    showAll = false,
    major = 1,              -- filter for missing leads
    type = 1,
    alertOnLogin = true,
    alertThreshold = 86400, -- seconds
    sortKey = "status",     -- sorting within a zone
    sortAsc = true,
    zoneOverride = {},      -- [zoneId] = true (show) / false (hide); nil = automatic
    window = nil,           -- { x, y, w, h }
}

local sv
local searchText = ""
local currentZoneId = 0
local entriesCache = nil

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local PREFIX = "|c42D6D1[MANA Antiquarian]|r "
local function Say(text) d(PREFIX .. text) end

local COLOR = {
    zone = "E0C080", here = "42D6D1", dig = "EECA2A", scry = "2DC50E",
    blocked = "FF9933", other = "9A9A9A", nolead = "6F6F6F",
    red = "FF4444", orange = "FF9933", yellow = "FFFF66", normal = "C5C29E",
    link = "6FB8FF", linkHover = "FFFFFF",
}
local function C(hex, text) return "|c" .. hex .. text .. "|r" end

local QUALITY_HEX = { [1] = "2DC50E", [2] = "3A92FF", [3] = "A02EF7", [4] = "EECA2A", [5] = "FF8000" }
local function QualityText(quality, text)
    if GetAntiquityQualityColor then
        local ok, color = pcall(GetAntiquityQualityColor, quality)
        if ok and color and color.Colorize then return color:Colorize(text) end
    end
    return C(QUALITY_HEX[quality] or "FFFFFF", text)
end

local function Lower(text)
    if LocaleAwareToLower then return LocaleAwareToLower(text) end
    return zo_strlower(text)
end

local function SafeMethod(obj, method, ...)
    if obj and obj[method] then
        local ok, result = pcall(obj[method], obj, ...)
        if ok then return result end
    end
    return nil
end

local function SafeCall(fn, ...)
    if not fn then return nil end
    local ok, result = pcall(fn, ...)
    if ok then return result end
    return nil
end

local function HasDL() return RDL ~= nil and RDL.Locations ~= nil end

---------------------------------------------------------------------------
-- Zones
---------------------------------------------------------------------------

local ALLZONES = 101010  -- Display Leads uses ids from this number for special zones

local function ZoneName(zoneId)
    if zoneId == nil or zoneId == 0 then return T"Any zone" end
    local special = RDL and RDL.ZONEID_ALLZONES or ALLZONES
    if zoneId >= special then
        return (RDL and RDL.ZONENAME_SPECIAL and RDL.ZONENAME_SPECIAL[zoneId]) or T"Special location"
    end
    local name = GetZoneNameById(zoneId)
    if not name or name == "" then return T"Zone " .. zoneId end
    return zo_strformat("<<C:1>>", name)
end

-- Top-level zone the player is in (same logic as Display Leads).
local function GetCurrentRootZoneId()
    local zoneId = GetZoneId(GetUnitZoneIndex("player"))
    local artaeum = RDL and RDL.ZONEID_ARTAEUM or 1027
    local guard = 0
    while zoneId and zoneId ~= 0 and zoneId ~= artaeum and GetParentZoneId(zoneId) ~= zoneId and guard < 10 do
        zoneId = GetParentZoneId(zoneId)
        guard = guard + 1
    end
    local cavern = RDL and RDL.ZONEID_WSKYRIMCAVERN or 1161
    if zoneId == cavern then zoneId = RDL and RDL.ZONEID_WSKYRIM or 1160 end
    return zoneId or 0
end

-- Collectible (DLC) that unlocks the zone; 0 = base game.
local function GetZoneCollectible(zoneId)
    if not zoneId or zoneId == 0 or zoneId >= ALLZONES then return 0 end
    local zoneIndex = GetZoneIndex(zoneId)
    if not zoneIndex or zoneIndex == 0 then return 0 end
    return SafeCall(GetCollectibleIdForZone, zoneIndex) or 0
end

local function IsZoneAutoAvailable(zoneId)
    local collectibleId = GetZoneCollectible(zoneId)
    if collectibleId == 0 then return true end
    return SafeCall(IsCollectibleUnlocked, collectibleId) ~= false
end

local function IsZoneVisible(zoneId)
    local override = sv.zoneOverride[zoneId]
    if override ~= nil then return override end
    return IsZoneAutoAvailable(zoneId)
end

---------------------------------------------------------------------------
-- Lead data
---------------------------------------------------------------------------

local STATUS = { DIG = 1, SCRY = 2, BLOCKED = 3, OTHER = 4, NOLEAD = 5 }
local STATUS_TEXT = {
    [STATUS.DIG] = C(COLOR.dig, T"Dig"),
    [STATUS.SCRY] = C(COLOR.scry, T"Scry"),
    [STATUS.BLOCKED] = C(COLOR.blocked, T"Unavailable"),
    [STATUS.OTHER] = C(COLOR.other, T"Other zone"),
    [STATUS.NOLEAD] = C(COLOR.nolead, T"No lead"),
}

local MAJOR_CHOICES = {
    { name = T"Obtainable", tip = T"Missing leads, except completed non-repeatable ones" },
    { name = T"Codex incomplete", tip = T"Has undiscovered codex entries" },
    { name = T"Never excavated", tip = T"The antiquity has never been excavated" },
    { name = T"Group dungeons", tip = T"Leads from 4-player dungeons (requires Display Leads)" },
    { name = T"Latest DLC", tip = T"Leads from the latest DLC (requires Display Leads)" },
    { name = T"All", tip = T"All, including completed non-repeatable ones" },
}
local TYPE_CHOICES = {
    { name = T"All types" },
    { name = T"Hide common", tip = T"Hide motif chapters, simple treasures and simple furnishings" },
    { name = T"Sets only", tip = T"Only parts of sets (mythics, mounts etc.)" },
}

local MOTIF_CHAPTER = GetString("SI_SPECIALIZEDITEMTYPE", SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_CHAPTER)
local TREASURE = GetString("SI_SPECIALIZEDITEMTYPE", SPECIALIZED_ITEMTYPE_TREASURE)
local FURNISHING = GetString("SI_ITEMTYPE", ITEMTYPE_FURNISHING)

local function GetSetOrRewardName(id, setId)
    local name = ""
    if setId and setId > 0 then name = zo_strformat("<<C:1>>", GetAntiquitySetName(setId)) end
    if name == "" then
        local rewardId = SafeCall(GetAntiquityRewardId, id) or 0
        if rewardId > 0 and REWARDS_MANAGER then
            name = SafeMethod(REWARDS_MANAGER, "GetRewardContextualTypeString", rewardId) or ""
        end
    end
    return name
end

local function GetDiggingState(id)
    local data = ANTIQUITY_DATA_MANAGER and ANTIQUITY_DATA_MANAGER:GetAntiquityData(id)
    local hasDigSites = SafeMethod(data, "HasDiscoveredDigSites")
    if hasDigSites == nil then
        local n = SafeCall(GetNumAntiquityDigSites, id)
        hasDigSites = n ~= nil and n > 0
    end
    local canScry = SafeMethod(data, "CanScry") == true
    return hasDigSites == true, canScry
end

-- Antiquity that needs no lead (each zone's free lead).
local function IsFreeLead(id)
    local requires = SafeCall(DoesAntiquityRequireLead, id)
    if requires == nil then
        local antiquity = ANTIQUITY_DATA_MANAGER and ANTIQUITY_DATA_MANAGER:GetAntiquityData(id)
        requires = SafeMethod(antiquity, "RequiresLead")
    end
    return requires == false
end

-- Progress of a multi-part set (mythic, mount, music box…).
-- A part counts as collected in the current round if it was dug more times
-- than the least-dug part of the set. completed = how many times the full set was assembled.
local function GetSetProgress(setId)
    if not setId or setId == 0 then return nil end
    local total = SafeCall(GetNumAntiquitySetAntiquities, setId)
    if not total or total <= 1 then return nil end
    local parts, minDug = {}, math.huge
    for i = 1, total do
        local partId = SafeCall(GetAntiquitySetAntiquityId, setId, i)
        if partId then
            local dug = GetNumAntiquitiesRecovered(partId)
            if dug < minDug then minDug = dug end
            parts[#parts + 1] = {
                id = partId,
                name = zo_strformat("<<C:1>>", GetAntiquityName(partId)),
                quality = GetAntiquityQuality(partId),
                dug = dug,
                hasLead = DoesAntiquityHaveLead(partId),
            }
        end
    end
    if #parts == 0 then return nil end
    local done = 0
    for _, part in ipairs(parts) do
        part.done = part.dug > minDug
        if part.done then done = done + 1 end
    end
    return { total = #parts, done = done, completed = minDug, parts = parts }
end

local function SetProgressText(progress)
    if not progress then return "" end
    local hex = progress.done == 0 and COLOR.other or COLOR.yellow
    local text = C(hex, progress.done .. "/" .. progress.total)
    if progress.completed > 0 then
        text = text .. C(COLOR.scry, T" · completed ×" .. progress.completed)
    end
    return text
end

-- All leads that may appear in the window (before search and filters).
local function CollectEntries()
    local list = {}
    local setCache = {}
    currentZoneId = GetCurrentRootZoneId()
    local id = GetNextAntiquityId()
    while id do
        local hasLead = DoesAntiquityHaveLead(id)
        local dug = GetNumAntiquitiesRecovered(id)
        local repeatable = IsAntiquityRepeatable(id)
        local scryZone = GetAntiquityZoneId(id)

        -- A zone's free lead (e.g. "Augur's Bones"): always scryable, no lead needed.
        -- Shown as owned if it is in the current zone or already started (scried/site found).
        local free = false
        local freeAny = not hasLead and IsFreeLead(id)
        if freeAny then
            local hasDigSites = GetDiggingState(id)
            local antiquity = ANTIQUITY_DATA_MANAGER and ANTIQUITY_DATA_MANAGER:GetAntiquityData(id)
            local inProgress = SafeMethod(antiquity, "IsInProgress") == true
            if hasDigSites or inProgress or scryZone == GetCurrentRootZoneId() then
                hasLead = true
                free = true
            end
        end
        -- For missing leads the zone where the lead drops matters (may differ from the dig zone).
        local zoneId = scryZone
        if not hasLead and RDL and RDL.FindScryDifferentZones and RDL.FindScryDifferentZones[id] then
            zoneId = RDL.FindScryDifferentZones[id]
        end

        local quality = GetAntiquityQuality(id)
        local diff = GetAntiquityDifficulty(id)
        if diff < 5 then diff = quality end  -- as in Display Leads: skill does not affect "difficulty"
        local setId = GetAntiquitySetId(id)

        local e = {
            id = id,
            free = free,
            freeAny = freeAny,
            name = zo_strformat("<<C:1>>", GetAntiquityName(id)),
            zoneId = zoneId,
            scryZone = scryZone,
            hasLead = hasLead,
            dug = dug,
            repeatable = repeatable,
            finished = (not repeatable) and dug >= 1 and not hasLead,
            quality = quality,
            diff = diff,
            setId = setId,
            setName = GetSetOrRewardName(id, setId),
            setProgress = nil,
            loreTotal = GetNumAntiquityLoreEntries(id),
            loreGot = GetNumAntiquityLoreEntriesAcquired(id),
        }

        if hasLead then
            local left = not free and GetAntiquityLeadTimeRemainingSeconds(id) or 0
            e.timeLeft = (left and left > 0) and left or nil  -- some leads report 0 during the first days
            local hasDigSites, canScry = GetDiggingState(id)
            if hasDigSites then
                e.status = STATUS.DIG
            elseif canScry then
                e.status = STATUS.SCRY
            elseif scryZone == currentZoneId then
                e.status = STATUS.BLOCKED
            else
                e.status = STATUS.OTHER
            end
            e.canScry = canScry
        else
            e.status = STATUS.NOLEAD
        end

        if setId and setId > 0 then
            if setCache[setId] == nil then setCache[setId] = GetSetProgress(setId) or false end
            e.setProgress = setCache[setId] or nil
        end

        if HasDL() and RDL.Locations[id] then e.location = RDL.Locations[id][1] end
        e.searchKey = Lower(e.name .. " " .. ZoneName(zoneId) .. " " .. (e.setName or ""))
        list[#list + 1] = e
        id = GetNextAntiquityId(id)
    end
    return list
end

local function PassesMissingFilters(e)
    local major = sv.major
    if major ~= 6 and e.finished then return false end
    if major == 2 and e.loreGot >= e.loreTotal then return false end
    if major == 3 and e.dug > 0 then return false end
    if major == 4 and not (RDL and RDL.isGroupDungeon and RDL.isGroupDungeon[e.id]) then return false end
    if major == 5 and not (RDL and RDL.LATESTDLC_FIRSTANTIQUITY and e.id >= RDL.LATESTDLC_FIRSTANTIQUITY) then return false end

    if sv.type == 2 then
        if e.setName == MOTIF_CHAPTER then return false end
        if e.diff < 4 and e.setName == TREASURE then return false end
        if e.diff < 2 and e.setName == FURNISHING then return false end
    elseif sv.type == 3 then
        if not (e.setId and e.setId > 0) then return false end
    end
    return true
end

local function IsShown(e)
    if not IsZoneVisible(e.zoneId) then return false end
    if searchText ~= "" and not zo_plainstrfind(e.searchKey, searchText) then return false end
    if e.hasLead then return true end
    if e.freeAny then return false end  -- other zones' free leads do not clutter the list
    return sv.showAll and PassesMissingFilters(e)
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

local TYPE_ZONE, TYPE_LEAD = 1, 2
local window, list, majorCombo, typeCombo

-- Columns: status and name on the left, actions/expiry/codex on the right, the hint stretches in between.
function ML.LayoutColumns(parent)
    local function child(name) return parent:GetNamedChild(name) end
    local h = parent:GetHeight()
    local status, name, hint = child("Status"), child("Name"), child("Hint")
    local lore, expire, scry, map = child("Lore"), child("Expire"), child("Scry"), child("Map")
    for _, c in ipairs({ status, name, hint, lore, expire, scry, map }) do
        c:ClearAnchors()
        c:SetHeight(h)
    end
    status:SetAnchor(LEFT, parent, LEFT, 22, 0);           status:SetWidth(110)
    name:SetAnchor(LEFT, status, RIGHT, 6, 0);             name:SetWidth(300)
    map:SetAnchor(RIGHT, parent, RIGHT, -4, 0);            map:SetWidth(60)
    scry:SetAnchor(RIGHT, map, LEFT, -6, 0);               scry:SetWidth(100)
    expire:SetAnchor(RIGHT, scry, LEFT, -6, 0);            expire:SetWidth(90)
    lore:SetAnchor(RIGHT, expire, LEFT, -6, 0);            lore:SetWidth(60)
    hint:SetAnchor(LEFT, name, RIGHT, 8, 0)
    hint:SetAnchor(RIGHT, lore, LEFT, -8, 0)
end

local function ExpireText(seconds)
    if not seconds then return "" end
    if seconds >= 86400 then
        local days = math.floor(seconds / 86400)
        return C(seconds < 604800 and COLOR.yellow or COLOR.normal, days .. T" d")
    end
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local text = hours > 0 and string.format(T"%d h %d min", hours, minutes) or string.format(T"%d min", minutes)
    return C(seconds < 3600 and COLOR.red or COLOR.orange, text)
end

local function SetupZoneRow(control, data)
    control:SetWidth(list:GetWidth() - 20)
    local label = control:GetNamedChild("Name")
    if data.isHere then
        label:SetText(C(COLOR.here, "◆ ") .. C(COLOR.here, data.name) .. C(COLOR.here, T" — you are here") .. "  " .. C(COLOR.normal, "(" .. data.count .. ")"))
    else
        label:SetText(C(COLOR.zone, data.name) .. "  " .. C(COLOR.normal, "(" .. data.count .. ")"))
    end
end

local function SetupLeadRow(control, data)
    control:SetWidth(list:GetWidth() - 20)
    if not control.mlLayout then
        ML.LayoutColumns(control)
        control.mlLayout = true
    end
    control.data = data
    local function child(name) return control:GetNamedChild(name) end

    child("Status"):SetText(STATUS_TEXT[data.status])
    child("Name"):SetText(QualityText(data.quality, data.name))

    if data.hasLead then
        local hint = data.setName ~= "" and C(COLOR.normal, data.setName) or ""
        if data.setProgress then hint = hint .. C(COLOR.normal, " · ") .. SetProgressText(data.setProgress) end
        if data.free then hint = hint .. C(COLOR.other, (hint ~= "" and " · " or "") .. T"zone's free lead, always available") end
        child("Hint"):SetText(hint)
        child("Lore"):SetText(data.loreTotal > 0 and C(COLOR.normal, data.loreGot .. "/" .. data.loreTotal) or "")
        child("Expire"):SetText(ExpireText(data.timeLeft))
    else
        local prefix = data.setProgress and ("[" .. SetProgressText(data.setProgress) .. "] ") or ""
        child("Hint"):SetText(prefix .. (data.location and C(COLOR.normal, data.location) or C(COLOR.nolead, "—")))
        child("Lore"):SetText(data.loreTotal > 0 and C(COLOR.nolead, data.loreGot .. "/" .. data.loreTotal) or "")
        child("Expire"):SetText("")
    end

    local scry = child("Scry")
    scry.enabled = data.hasLead and data.canScry
    scry:SetText(scry.enabled and C(COLOR.link, T"Scry") or "")
    scry:SetMouseEnabled(scry.enabled)

    local map = child("Map")
    map.enabled = data.scryZone ~= nil and data.scryZone ~= 0 and data.scryZone < ALLZONES
    map:SetText(map.enabled and C(COLOR.link, T"Map") or "")
    map:SetMouseEnabled(map.enabled)
end

-- Column sorting (within each zone).
local HEADER_KEYS = { Status = "status", Name = "name", Hint = "set", Lore = "lore", Expire = "expire" }
local SORT_UP = "|t16:16:EsoUI/Art/Miscellaneous/list_sortUp.dds|t"
local SORT_DOWN = "|t16:16:EsoUI/Art/Miscellaneous/list_sortDown.dds|t"

local SORT_VALUE = {
    status = function(e) return e.status end,
    name = function(e) return e.name end,
    -- By set: most complete first (share of parts), no set last.
    set = function(e)
        local p = e.setProgress
        if not p then return 1 end
        return -(p.done / p.total)
    end,
    lore = function(e) return e.loreGot end,
    expire = function(e) return e.timeLeft or math.huge end,
}

local function DefaultLess(a, b)
    if a.status ~= b.status then return a.status < b.status end
    local ta, tb = a.timeLeft or math.huge, b.timeLeft or math.huge
    if ta ~= tb then return ta < tb end
    if a.quality ~= b.quality then return a.quality > b.quality end
    return a.name < b.name
end

local function SortLess(a, b)
    local getter = SORT_VALUE[sv.sortKey] or SORT_VALUE.status
    local va, vb = getter(a), getter(b)
    if va ~= vb then
        if sv.sortAsc then return va < vb else return va > vb end
    end
    return DefaultLess(a, b)
end

local function SetHeaders()
    local headers = window:GetNamedChild("Headers")
    if not headers.mlLayout then
        ML.LayoutColumns(headers)
        headers.mlLayout = true
    end
    local titles = {
        Status = T"Status",
        Name = T"Antiquity",
        Hint = sv.showAll and T"Set / where to find the lead" or T"Set / reward",
        Lore = T"Codex",
        Expire = T"Expires",
    }
    for childName, title in pairs(titles) do
        local label = headers:GetNamedChild(childName)
        label.sortKey = HEADER_KEYS[childName]
        if label.sortKey == sv.sortKey then
            title = title .. " " .. (sv.sortAsc and SORT_UP or SORT_DOWN)
        end
        label:SetText(title)
    end
    headers:GetNamedChild("Scry"):SetText("")
    headers:GetNamedChild("Map"):SetText("")
end

function ML.OnHeaderClick(label)
    if not label.sortKey then return end
    if sv.sortKey == label.sortKey then
        sv.sortAsc = not sv.sortAsc
    else
        sv.sortKey = label.sortKey
        sv.sortAsc = true
    end
    ML.Refresh()
end

function ML.HeaderEnter(label) label:SetColor(1, 1, 1, 1) end
function ML.HeaderExit(label) label:SetColor(0.77, 0.76, 0.62, 1) end

local function ZoneSortKey(group)
    if group.isHere then return 0 end
    if group.hasDig then return 1 end
    if group.hasMine then return 2 end
    return 3
end

function ML.Refresh()
    if not window or window:IsHidden() then return end
    entriesCache = CollectEntries()

    local groups, byZone = {}, {}
    local total, scryHere, dig, missingShown = 0, 0, 0, 0
    for _, e in ipairs(entriesCache) do
        if e.hasLead then
            total = total + 1
            if e.status == STATUS.SCRY then scryHere = scryHere + 1 end
            if e.status == STATUS.DIG then dig = dig + 1 end
        end
        if IsShown(e) then
            local g = byZone[e.zoneId]
            if not g then
                g = { zoneId = e.zoneId, name = ZoneName(e.zoneId), isHere = (e.zoneId == currentZoneId), items = {} }
                byZone[e.zoneId] = g
                groups[#groups + 1] = g
            end
            g.items[#g.items + 1] = e
            if e.hasLead then g.hasMine = true end
            if e.status == STATUS.DIG then g.hasDig = true end
            if not e.hasLead then missingShown = missingShown + 1 end
        end
    end

    table.sort(groups, function(a, b)
        local ka, kb = ZoneSortKey(a), ZoneSortKey(b)
        if ka ~= kb then return ka < kb end
        return a.name < b.name
    end)

    ZO_ScrollList_Clear(list)
    local scrollData = ZO_ScrollList_GetDataList(list)
    for _, g in ipairs(groups) do
        table.sort(g.items, SortLess)
        scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(TYPE_ZONE,
            { name = g.name, isHere = g.isHere, count = #g.items })
        for _, e in ipairs(g.items) do
            scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(TYPE_LEAD, e)
        end
    end
    ZO_ScrollList_Commit(list)

    local summary = string.format(T"My leads: %d · scry here: %d · dig: %d", total, scryHere, dig)
    if sv.showAll then summary = summary .. T" · missing shown: " .. missingShown end
    window:GetNamedChild("Summary"):SetText(summary)

    local empty = window:GetNamedChild("Empty")
    empty:SetHidden(#groups > 0)
    empty:SetText(searchText ~= "" and T"Nothing found" or T"No leads")

    SetHeaders()
    window:GetNamedChild("Major"):SetHidden(not sv.showAll)
    window:GetNamedChild("Type"):SetHidden(not sv.showAll)
end

function ML.Toggle()
    if not window then return end
    local wasHidden = window:IsHidden()
    SCENE_MANAGER:ToggleTopLevel(window)
    if wasHidden then zo_callLater(ML.Refresh, 50) end
end

function ML.Hide()
    if window then SCENE_MANAGER:HideTopLevel(window) end
end

function ML.SaveWindow()
    if not window then return end
    sv.window = { x = window:GetLeft(), y = window:GetTop(), w = window:GetWidth(), h = window:GetHeight() }
end

function ML.OnResized()
    if not window then return end
    ZO_ScrollList_Commit(list)
end

function ML.OnSearchChanged(editBox)
    searchText = Lower(zo_strtrim(editBox:GetText() or ""))
    ML.Refresh()
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

local function ExplainCannotScry(antiquityId)
    if not DoesAntiquityHaveLead(antiquityId) and not IsFreeLead(antiquityId) then
        Say(T"You have no lead for this antiquity.")
        return
    end
    local hasDigSites = GetDiggingState(antiquityId)
    if hasDigSites then
        Say(T"The dig site is already located — open the map (\"Map\") to see it.")
        return
    end
    local zoneId = GetAntiquityZoneId(antiquityId)
    if zoneId and zoneId ~= 0 and zoneId ~= GetCurrentRootZoneId() then
        Say(T"This antiquity is scried in “" .. ZoneName(zoneId) .. T"”. Travel there (and leave any dungeon).")
    else
        Say(T"You cannot scry right now: you are in a dungeon or building, in combat, or your Scrying skill is too low.")
    end
end

function ML.Scry(antiquityId)
    if not antiquityId then return end
    local data = ANTIQUITY_DATA_MANAGER and ANTIQUITY_DATA_MANAGER:GetAntiquityData(antiquityId)
    if not data then
        Say(T"Could not find the antiquity data.")
        return
    end
    if not SafeMethod(data, "CanScry") then
        ExplainCannotScry(antiquityId)
        return
    end
    ML.Hide()
    if RDLMainWindow then RDLMainWindow:SetHidden(true) end
    SCENE_MANAGER:ShowBaseScene()
    ScryForAntiquity(antiquityId)
end

function ML.ShowOnMap(antiquityId, zoneId)
    if DoesAntiquityHaveLead(antiquityId) or IsFreeLead(antiquityId) then SafeCall(SetTrackedAntiquityId, antiquityId) end
    ML.Hide()
    if ZO_WorldMap_ShowWorldMap then ZO_WorldMap_ShowWorldMap() end
    local mapIndex = SafeCall(GetMapIndexByZoneId, zoneId)
    if mapIndex and ZO_WorldMap_SetMapByIndex then
        zo_callLater(function() ZO_WorldMap_SetMapByIndex(mapIndex) end, 200)
    end
end

function ML.OnAction(label, action)
    local row = label:GetParent()
    local data = row and row.data
    if not data or not label.enabled then return end
    if action == "scry" then
        ML.Scry(data.id)
    else
        ML.ShowOnMap(data.id, data.scryZone)
    end
end

function ML.ActionEnter(label)
    if label.enabled then
        label:SetText(C(COLOR.linkHover, label:GetText():gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")))
    end
    ML.RowEnter(label:GetParent())
end

function ML.ActionExit(label)
    if label.enabled then
        label:SetText(C(COLOR.link, label:GetText():gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")))
    end
    ML.RowExit(label:GetParent())
end

function ML.RowEnter(control)
    if list then ZO_ScrollList_MouseEnter(list, control) end
    local data = control.data
    if not data then return end
    InitializeTooltip(InformationTooltip, control, RIGHT, -10, 0, LEFT)
    SafeMethod(InformationTooltip, "SetAntiquityLead", data.id)
    if data.setProgress then
        local p = data.setProgress
        InformationTooltip:AddVerticalPadding(8)
        local title = C(COLOR.here, T"Set “" .. data.setName .. T"”: ") .. SetProgressText(p)
        InformationTooltip:AddLine(title, "ZoFontGameBold")
        for _, part in ipairs(p.parts) do
            local mark = part.done and "|t18:18:EsoUI/Art/Cadwell/check.dds|t " or C(COLOR.nolead, "— ")
            local leadInfo
            if part.done then
                leadInfo = ""
            elseif part.hasLead then
                leadInfo = C(COLOR.scry, T" — lead owned")
            else
                leadInfo = C(COLOR.other, T" — no lead")
            end
            InformationTooltip:AddLine(mark .. QualityText(part.quality, part.name) .. leadInfo, "ZoFontGame")
        end
    end
    if data.location then
        InformationTooltip:AddVerticalPadding(8)
        SetTooltipText(InformationTooltip, C(COLOR.here, T"Where to find the lead: ") .. data.location)
    end
    InformationTooltip:AddVerticalPadding(6)
    if data.hasLead and data.canScry then
        InformationTooltip:AddLine(C(COLOR.here, T"Double-click to start scrying"), "ZoFontGameSmall")
    end
end

function ML.RowExit(control)
    if list then ZO_ScrollList_MouseExit(list, control) end
    ClearTooltip(InformationTooltip)
end

function ML.RowDoubleClick(control, button)
    if button ~= nil and button ~= MOUSE_BUTTON_INDEX_LEFT then return end
    if control.data and control.data.hasLead then ML.Scry(control.data.id) end
end

---------------------------------------------------------------------------
-- Expiring lead reminder
---------------------------------------------------------------------------

local THRESHOLDS = {
    { value = 3600, name = T"less than 1 hour" },
    { value = 86400, name = T"less than 1 day" },
    { value = 604800, name = T"less than 7 days" },
}

local function ThresholdName(value)
    for _, t in ipairs(THRESHOLDS) do
        if t.value == value then return t.name end
    end
    return tostring(value)
end

function ML.CheckExpiring(always)
    local expiring = {}
    local id = GetNextAntiquityId()
    while id do
        if DoesAntiquityHaveLead(id) then
            local left = GetAntiquityLeadTimeRemainingSeconds(id)
            if left and left > 0 and left < sv.alertThreshold then
                expiring[#expiring + 1] = { name = zo_strformat("<<C:1>>", GetAntiquityName(id)),
                                            quality = GetAntiquityQuality(id), left = left,
                                            zone = ZoneName(GetAntiquityZoneId(id)) }
            end
        end
        id = GetNextAntiquityId(id)
    end
    if #expiring == 0 then
        if always then Say(T"No leads expiring in " .. ThresholdName(sv.alertThreshold) .. T".") end
        return
    end
    table.sort(expiring, function(a, b) return a.left < b.left end)
    Say(C(COLOR.orange, T"Expiring in " .. ThresholdName(sv.alertThreshold) .. ": " .. #expiring))
    for i, e in ipairs(expiring) do
        if i > 8 then
            d(T"  …and " .. (#expiring - 8))
            break
        end
        d("  " .. QualityText(e.quality, e.name) .. " — " .. e.zone .. ", " .. ExpireText(e.left))
    end
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

local function CollectDlcZones()
    local zones, seen = {}, {}
    local id = GetNextAntiquityId()
    while id do
        for _, zoneId in ipairs({ GetAntiquityZoneId(id),
                                  RDL and RDL.FindScryDifferentZones and RDL.FindScryDifferentZones[id] or 0 }) do
            if zoneId and zoneId ~= 0 and not seen[zoneId] then
                seen[zoneId] = true
                local collectibleId = GetZoneCollectible(zoneId)
                if collectibleId ~= 0 then
                    local dlc = zo_strformat("<<C:1>>", GetCollectibleName(collectibleId))
                    zones[#zones + 1] = { zoneId = zoneId, name = ZoneName(zoneId), dlc = dlc }
                end
            end
        end
        id = GetNextAntiquityId(id)
    end
    table.sort(zones, function(a, b) return a.name < b.name end)
    return zones
end

local function CreateSettings()
    local LAM = LibAddonMenu2

    local tNames, tValues = {}, {}
    for _, t in ipairs(THRESHOLDS) do
        tNames[#tNames + 1] = t.name
        tValues[#tValues + 1] = t.value
    end

    local options = {
        { type = "description",
          text = T"Open the window with /manadig or your own key (Controls → MANA Antiquarian)." },
        { type = "header", name = T"Expiring lead reminder" },
        { type = "checkbox", name = T"Remind in chat on login",
          getFunc = function() return sv.alertOnLogin end,
          setFunc = function(v) sv.alertOnLogin = v end },
        { type = "dropdown", name = T"Remind when",
          tooltip = T"Leads with less time left than this. Check now: /manadig alert",
          choices = tNames, choicesValues = tValues,
          getFunc = function() return sv.alertThreshold end,
          setFunc = function(v) sv.alertThreshold = v end },
        { type = "header", name = T"DLC zones" },
        { type = "description",
          text = T"Leads in zones from DLCs you do not own are hidden automatically. You can adjust this here: uncheck a zone to hide it, check it to show it." },
        { type = "button", name = T"Reset to auto-detection", width = "half",
          func = function()
              sv.zoneOverride = {}
              ML.Refresh()
          end },
    }

    for _, z in ipairs(CollectDlcZones()) do
        options[#options + 1] = {
            type = "checkbox",
            name = z.name,
            tooltip = T"DLC: " .. z.dlc .. T"\nAuto-detected: " ..
                      (IsZoneAutoAvailable(z.zoneId) and T"available" or T"not owned"),
            getFunc = function() return IsZoneVisible(z.zoneId) end,
            setFunc = function(v)
                if v == IsZoneAutoAvailable(z.zoneId) then
                    sv.zoneOverride[z.zoneId] = nil
                else
                    sv.zoneOverride[z.zoneId] = v
                end
                ML.Refresh()
            end,
        }
    end

    LAM:RegisterAddonPanel("MANAAntiquarian_Panel", {
        type = "panel", name = ML.displayName, displayName = ML.displayName,
        author = ML.author, version = ML.version,
        slashCommand = "/manadigsettings", registerForRefresh = true,
    })
    LAM:RegisterOptionControls("MANAAntiquarian_Panel", options)
end

---------------------------------------------------------------------------
-- Window init
---------------------------------------------------------------------------

local function InitCombo(control, choices, key)
    local combo = ZO_ComboBox_ObjectFromContainer(control)
    combo:SetSortsItems(false)
    local selected
    for index, choice in ipairs(choices) do
        local entry = combo:CreateItemEntry(choice.name, function()
            sv[key] = index
            ML.Refresh()
        end)
        combo:AddItem(entry, ZO_COMBOBOX_SUPPRESS_UPDATE)
        if index == sv[key] then selected = entry end
    end
    combo:SelectItem(selected or combo.m_sortedItems[1], true)
    return combo
end

local function InitWindow()
    window = MANAAntiquarianWindow
    list = window:GetNamedChild("List")

    ZO_ScrollList_AddDataType(list, TYPE_ZONE, "MANAAntiquarian_ZoneRow", 32, SetupZoneRow)
    ZO_ScrollList_AddDataType(list, TYPE_LEAD, "MANAAntiquarian_LeadRow", 28, SetupLeadRow)
    ZO_ScrollList_EnableHighlight(list, "ZO_ThinListHighlight")

    local showAll = window:GetNamedChild("ShowAll")
    ZO_CheckButton_SetLabelText(showAll, T"All leads")
    ZO_CheckButton_SetCheckState(showAll, sv.showAll)
    ZO_CheckButton_SetToggleFunction(showAll, function(_, checked)
        sv.showAll = checked
        ML.Refresh()
    end)

    local box = window:GetNamedChild("Search"):GetNamedChild("Box")
    if box.SetDefaultText then box:SetDefaultText(T"Search by name, zone, set…") end

    majorCombo = InitCombo(window:GetNamedChild("Major"), MAJOR_CHOICES, "major")
    typeCombo = InitCombo(window:GetNamedChild("Type"), TYPE_CHOICES, "type")

    if sv.window then
        window:ClearAnchors()
        window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.window.x, sv.window.y)
        window:SetDimensions(sv.window.w, sv.window.h)
    end

    SCENE_MANAGER:RegisterTopLevel(window, false)
end

---------------------------------------------------------------------------
-- Double-click in the Display Leads window
---------------------------------------------------------------------------

local function HookDisplayLeads()
    if not (RDL and RDLUnitList) then return end
    ZO_PostHook(RDLUnitList, "SetupUnitRow", function(_, control)
        control:SetHandler("OnMouseDoubleClick", function(ctrl, button)
            if button ~= nil and button ~= MOUSE_BUTTON_INDEX_LEFT then return end
            if ctrl.data and ctrl.data.Aid then ML.Scry(ctrl.data.Aid) end
        end)
    end)
    ZO_PostHook(RDL, "RowMouseEnter", function(control)
        if control and control.data and control.data.Aid and DoesAntiquityHaveLead(control.data.Aid) then
            InformationTooltip:AddVerticalPadding(6)
            InformationTooltip:AddLine(C(COLOR.here, T"Double-click to start scrying"), "ZoFontGameSmall")
        end
    end)
end

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------

-- Server-dependent account-wide settings (EU and NA have different banks and items).
-- Settings saved by earlier versions (not server dependent) are copied to each server once.
local function LoadSavedVars(svName, version, defaults)
    local displayName = GetDisplayName()
    local raw = _G[svName]
    local old = raw and raw["Default"] and raw["Default"][displayName] and raw["Default"][displayName]["$AccountWide"]
    local saved = ZO_SavedVars:NewAccountWide(svName, version, nil, defaults, GetWorldName())
    -- Copy (not move), so every server you play on gets the old settings once.
    if old and not saved.copiedFromDefault then
        for key, value in pairs(old) do
            if key ~= "version" then
                saved[key] = (type(value) == "table") and ZO_DeepTableCopy(value) or value
            end
        end
        saved.copiedFromDefault = true
    end
    return saved
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ML.name then return end
    EVENT_MANAGER:UnregisterForEvent(ML.name, EVENT_ADD_ON_LOADED)

    sv = LoadSavedVars("MANAAntiquarian_SV", SV_VERSION, DEFAULTS)
    sv.zoneOverride = sv.zoneOverride or {}

    InitWindow()
    HookDisplayLeads()
    CreateSettings()

    local function RefreshIfOpen() ML.Refresh() end
    for i, event in ipairs({ EVENT_ANTIQUITY_LEAD_ACQUIRED, EVENT_ANTIQUITY_UPDATED, EVENT_ANTIQUITIES_UPDATED,
                             EVENT_ANTIQUITY_DIG_SITES_UPDATED, EVENT_ZONE_CHANGED }) do
        if event then EVENT_MANAGER:RegisterForEvent(ML.name .. "_Refresh" .. i, event, RefreshIfOpen) end
    end

    local alerted = false
    EVENT_MANAGER:RegisterForEvent(ML.name .. "_Activated", EVENT_PLAYER_ACTIVATED, function()
        ML.Refresh()
        if not alerted and sv.alertOnLogin then
            alerted = true
            zo_callLater(function() ML.CheckExpiring(false) end, 3000)
        end
    end)

    local function SlashHandler(arg)
        arg = zo_strlower(zo_strtrim(arg or ""))
        if arg == "alert" then
            ML.CheckExpiring(true)
        elseif arg == "help" then
            Say(T"/manadig — open/close the window")
            Say(T"/manadig alert — check expiring leads")
            Say(T"/manadigsettings — settings")
        else
            ML.Toggle()
        end
    end
    SLASH_COMMANDS["/manadig"] = SlashHandler
    SLASH_COMMANDS["/manaantiquarian"] = SlashHandler
    SLASH_COMMANDS["/manaleads"] = SlashHandler  -- former add-on name
end

EVENT_MANAGER:RegisterForEvent(ML.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
