--------------------------------------------------------------
-- EyeOnKeep.lua — v1.3.2
-- Author: SugaComa (Rik Sprint)
-- RESOURCES NOW FILTER BY HOME TERRITORY (same as keeps/outposts/towns)
--------------------------------------------------------------
local ADDON_NAME = "EyeOnKeep"
EyeOnKeep = EyeOnKeep or {}
EyeOnKeep.version = "1.3.2"
local EM = EVENT_MANAGER
local EOK_SV_VERSION = 44
local EOK_SV = nil
local _inited = false
local muted = false
local BG_CONTEXT = BGQUERY_LOCAL
local tacticalEnabled = false
local lastTacticalAdvice
local populationRequestedAt, populationReceivedAt
local tacticalPopulation, tacticalPopulationCampaign

-- SavedVars defaults
local DEFAULTS = {
    excludeIC = true,
    messageStyle = "immersive",
    alertMatrix = {
        keep = { true, true, true },
        outpost = { true, true, true },
        town = { true, true, true },
        resource = { true, true, true },
    },
}

--------------------------------------------------------------
-- Factions
--------------------------------------------------------------
local FACTION = {
    [ALLIANCE_ALDMERI_DOMINION] = { tag="AD", name="Dominion", color="|cFFD700", monarch="Queen Ayrenn" },
    [ALLIANCE_EBONHEART_PACT]     = { tag="EP", name="Pact",     color="|cFF2400", monarch="Jorunn the Skald-King" },
    [ALLIANCE_DAGGERFALL_COVENANT]= { tag="DC", name="Covenant",color="|c4169E1", monarch="King Emeric" },
    [ALLIANCE_NONE]               = { tag="--", name="Conflict",        color="|cFFFFFF", monarch="No ruler" },
}
local INFO_COLOR = "|c00FFCC"
local CHAT_TAG = "[EoK] "

-- Central chat output. Every EyeOnKeep line carries the same short tag so
-- narration tools such as VCAP2 can identify it reliably.
local function EmitChat(msg, force)
    if not msg or msg == "" then return end
    if muted and not force then return end

    local line = CHAT_TAG .. "|cFFFFFF" .. msg .. "|r"
    if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage(line)
    else
        d(line)
    end
end

function EyeOnKeep.Chat(msg, force)
    EmitChat(msg, force == true)
end

local chat = EyeOnKeep.Chat

local function TacticalEligible()
    return tacticalEnabled and (not IsUnitGrouped("player") or IsUnitGroupLeader("player"))
end

--------------------------------------------------------------
-- Keep Types
--------------------------------------------------------------
--------------------------------------------------------------
-- Canonicalize helper
--------------------------------------------------------------
local function canon(s)
    if not s or s == "" then return "" end
    s = s:gsub("’","'"):gsub("^%s*(.-)%s*$","%1")
    return s
end


--------------------------------------------------------------
-- Territory & Classification
--------------------------------------------------------------
local HOME_KEEPS = {
    ["Castle Alessia"]=1, ["Castle Black Boot"]=1, ["Castle Bloodmayne"]=1,
    ["Castle Brindle"]=1, ["Castle Faregyl"]=1, ["Castle Roebeck"]=1,
    ["Fort Aleswell"]=3, ["Fort Ash"]=3, ["Fort Dragonclaw"]=3,
    ["Fort Glademist"]=3, ["Fort Rayles"]=3, ["Fort Warden"]=3,
    ["Arrius Keep"]=2, ["Blue Road Keep"]=2, ["Chalman Keep"]=2,
    ["Drakelowe Keep"]=2, ["Kingscrest Keep"]=2, ["Farragut Keep"]=2,
}
local OUTPOSTS = {
    ["Nikel Outpost"]=1, ["Carmala Outpost"]=1,
    ["Bleaker's Outpost"]=3, ["Winter's Peak Outpost"]=3,
    ["Sejanus Outpost"]=2, ["Harlun's Outpost"]=2,
}
local TOWNS = { ["Vlastarus"]=1, ["Bruma"]=3, ["Cropsford"]=2, }

local EMP_KEEPS = {
    ["Castle Alessia"]=true, ["Castle Roebeck"]=true,
    ["Blue Road Keep"]=true, ["Chalman Keep"]=true,
    ["Fort Aleswell"]=true, ["Fort Ash"]=true,
}
local OUTER_KEEPS = {
    ["Castle Brindle"]=true, ["Fort Dragonclaw"]=true, ["Drakelowe Keep"]=true,
}

--------------------------------------------------------------
-- Resource → Parent Keep
--------------------------------------------------------------
local TOKEN_TO_KEEP = {
    ["Alessia"]="Castle Alessia",["Black Boot"]="Castle Black Boot",["Bloodmayne"]="Castle Bloodmayne",
    ["Brindle"]="Castle Brindle",["Faregyl"]="Castle Faregyl",["Roebeck"]="Castle Roebeck",
    ["Aleswell"]="Fort Aleswell",["Ash"]="Fort Ash",["Dragonclaw"]="Fort Dragonclaw",
    ["Glademist"]="Fort Glademist",["Rayles"]="Fort Rayles",["Warden"]="Fort Warden",
    ["Arrius"]="Arrius Keep",["Blue Road"]="Blue Road Keep",["Chalman"]="Chalman Keep",
    ["Drakelowe"]="Drakelowe Keep",["Kingscrest"]="Kingscrest Keep",["Farragut"]="Farragut Keep",
}
local function stripResourceSuffix(name)
    return canon(name):gsub("%s+Farm$",""):gsub("%s+Mine$",""):gsub("%s+Lumbermill$","")
end
local function parentKeepForResource(name)
    return TOKEN_TO_KEEP[stripResourceSuffix(name)]
end

--------------------------------------------------------------
-- Helpers
--------------------------------------------------------------
local function nowMs() 
return GetFrameTimeMilliseconds() 
end
local function SafeColor(a) 
return (FACTION[a] and FACTION[a].color) or "|cFFFFFF" 
end
local function SafeName(a) 
return (FACTION[a] and FACTION[a].name) or "Unknown" 
end
-- Display only: canonical names stay intact for territory, resource and abbreviation lookup.
local function DisplayPlace(name)
    return (name:gsub("^Castle ", ""):gsub("^Fort ", ""):gsub(" Keep$", ""):gsub(" Keep ", " "):gsub(" Outpost$", ""))
end
local function FactionText(alliance)
    return SafeColor(alliance) .. SafeName(alliance) .. "|r|cFFFFFF"
end

local function SafeMonarch(a) 
return (FACTION[a] and FACTION[a].monarch) or "Unknown Ruler" 
end


local function getKeepType(keepId)
    if not keepId or keepId <= 0 or type(GetKeepType) ~= "function" then return 0 end
    return GetKeepType(keepId)
end

--------------------------------------------------------------
-- Objective classification uses API constants; display names do not determine type.
--------------------------------------------------------------
local function getObjectiveType(name, keepId)
    if not keepId or keepId <= 0 or not name or name == "?" then
        return "other"
    end

    local key = canon(name)
    local kt = getKeepType(keepId)

    if kt == KEEPTYPE_RESOURCE then return "resource" end
    if kt == KEEPTYPE_KEEP then return "keep" end
    if kt == KEEPTYPE_OUTPOST then return "outpost" end
    if kt == KEEPTYPE_TOWN then return "town" end

    return "other"
end


--------------------------------------------------------------
-- Resolve territory (home alliance)
--------------------------------------------------------------
local function resolveTerritory(name, keepId)
    local key = canon(name)
    local native = HOME_KEEPS[key] or OUTPOSTS[key] or TOWNS[key]
    if native then return native end
    local parent = parentKeepForResource(name)
    if parent then
        local pk = canon(parent)
        return HOME_KEEPS[pk] or OUTPOSTS[pk] or TOWNS[pk] or ALLIANCE_NONE
    end
    return ALLIANCE_NONE
end

--------------------------------------------------------------
-- Message Formatter
--------------------------------------------------------------
local function FormatKeepMessage(template, keepName, owner, territory, myAlliance)
    if not template then return "" end

    local parent = parentKeepForResource(keepName)
    local n = INFO_COLOR .. DisplayPlace(keepName) .. "|r|cFFFFFF"
    local p = INFO_COLOR .. (parent or keepName) .. "|r|cFFFFFF"
    local o = SafeColor(owner) .. SafeName(owner) .. "|r|cFFFFFF"
    local t = SafeColor(territory) .. SafeName(territory) .. "|r|cFFFFFF"
    local m = SafeColor(myAlliance) .. SafeName(myAlliance) .. "|r|cFFFFFF"
    local r = SafeColor(owner) .. SafeMonarch(owner) .. "|r|cFFFFFF"



    local msg = template
        :gsub("%%Kn", n)
        :gsub("%%Kp", p)
        :gsub("%%Ko", o)
        :gsub("%%Kt", t)
        :gsub("%%Km", m)
        :gsub("%%Kr", r)

    return msg .. "|r"
end

--------------------------------------------------------------
-- FILTER: ALL OBJECTS USE HOME TERRITORY (including resources!)
--------------------------------------------------------------
local function matrixAllows(otype, filterAlliance)
    if not EOK_SV or not EOK_SV.alertMatrix then return true end
    local t = EOK_SV.alertMatrix[otype]
    if not t then return true end
    local v = t[filterAlliance]
    if v == nil then return true end
    return v
end

--------------------------------------------------------------
-- LEXICON (Token Reference) for building messages below
-- ------------------------------------------------------------
-- These tokens are replaced dynamically in alert message templates.
-- Use them inside any string passed to FormatKeepMessage().
--
--  %Kn = Keep or Resource name               (e.g. "Alessia Farm")
--  %Ko = Current owner alliance              (e.g. "Ebonheart Pact")
--  %Kt = Territory or home alliance          (e.g. "Aldmeri Dominion")
--  %Km = My alliance                         (e.g. "Daggerfall Covenant")
--  %Ka = Attacker or extra info (flex token)
--  %Ks = Keep Attacker (who has siege up)
--  %Kr = Monarch name of owner (e.g. "Queen Ayrenn")
--
--  Color Codes:
--    Applied automatically per faction:
--      AD = |cFFD700  (gold)
--      EP = |cFF2400  (red)
--      DC = |c4169E1  (blue)
--      Neutral/Conflict = |cFFFFFF
--
--  Example Templates:
--    "%Kn is under attack: defend %Km lands!"
--    "%Ko have captured %Kn in the name of %Kr."
--    "Disruption reported at %Kn: %Ko are defending."
--
--  ⚙️ Expansion Ideas:
--    %Kp = Parent keep (for resources)
--    %Kc = Campaign name
--    %Ki = Keep ID
--    %Kb = Battle state (Under Attack / Captured / Defended)
-- ------------------------------------------------------------
--------------------------------------------------------------
-- styles NOW WITH ABBREVIATIONS
--------------------------------------------------------------
local ABBR = {
    keep = {
        ["Castle Alessia"]      = "LESSY", ["Castle Black Boot"] = "BB", ["Castle Bloodmayne"] = "BM",
        ["Castle Brindle"]      = "BRIN", ["Castle Faregyl"]    = "FARE", ["Castle Roebeck"]    = "ROE",
        ["Fort Aleswell"]       = "ALES", ["Fort Ash"]         = "ASH", ["Fort Dragonclaw"]   = "DRAGON",
        ["Fort Glademist"]      = "GLADE", ["Fort Rayles"]      = "RAYLES", ["Fort Warden"]       = "WARDEN",
        ["Arrius Keep"]         = "ARRY", ["Blue Road Keep"]   = "BRK", ["Chalman Keep"]      = "CHAL",
        ["Drakelowe Keep"]      = "DRAKE", ["Kingscrest Keep"]  = "KINGS", ["Farragut Keep"]     = "FARRA",
    },
    resource = {
		["Castle Alessia Farm"] = "LESSY FARM", ["Castle Alessia Mine"] = "LESSY MINE", ["Castle Alessia Lumbermill"] = "LESSY LUMB",
		["Castle Black Boot Farm"] = "BB FARM", ["Castle Black Boot Mine"] = "BB MINE", ["Castle Black Boot Lumbermill"] = "BB LUMB",
		["Castle Bloodmayne Farm"] = "BM FARM", ["Castle Bloodmayne Mine"] = "BM MINE", ["Castle Bloodmayne Lumbermill"] = "BM LUMB",
		["Castle Brindle Farm"] = "BRIN FARM", ["Castle Brindle Mine"] = "BRIN MINE", ["Castle Brindle Lumbermill"] = "BRIN LUMB",
		["Castle Faregyl Farm"] = "FARE FARM", ["Castle Faregyl Mine"] = "FARE MINE", ["Castle Faregyl Lumbermill"] = "FARE LUMB",
		["Castle Roebeck Farm"] = "ROE FARM", ["Castle Roebeck Mine"] = "ROE MINE", ["Castle Roebeck Lumbermill"] = "ROE LUMB",
		["Fort Aleswell Farm"] = "ALES FARM", ["Fort Aleswell Mine"] = "ALES MINE", ["Fort Aleswell Lumbermill"] = "ALES LUMB",
		["Fort Ash Farm"] = "ASH FARM", ["Fort Ash Mine"] = "ASH MINE", ["Fort Ash Lumbermill"] = "ASH LUMB",
		["Fort Dragonclaw Farm"] = "DRAGON FARM", ["Fort Dragonclaw Mine"] = "DRAGON MINE", ["Fort Dragonclaw Lumbermill"] = "DRAGON LUMB",
		["Fort Glademist Farm"] = "GLADE FARM", ["Fort Glademist Mine"] = "GLADE MINE", ["Fort Glademist Lumbermill"] = "GLADE LUMB",
		["Fort Rayles Farm"] = "RAYLES FARM", ["Fort Rayles Mine"] = "RAYLES MINE", ["Fort Rayles Lumbermill"] = "RAYLES LUMB",
		["Fort Warden Farm"] = "WARDEN FARM", ["Fort Warden Mine"] = "WARDEN MINE", ["Fort Warden Lumbermill"] = "WARDEN LUMB",
		["Arrius Keep Farm"] = "ARRY FARM", ["Arrius Keep Mine"] = "ARRY MINE", ["Arrius Keep Lumbermill"] = "ARRY LUMB",
		["Blue Road Keep Farm"] = "BRK FARM", ["Blue Road Keep Mine"] = "BRK MINE", ["Blue Road Keep Lumbermill"] = "BRK LUMB",
		["Chalman Keep Farm"] = "CHAL FARM", ["Chalman Keep Mine"] = "CHAL MINE", ["Chalman Keep Lumbermill"] = "CHAL LUMB",
		["Drakelowe Keep Farm"] = "DRAKE FARM", ["Drakelowe Keep Mine"] = "DRAKE MINE", ["Drakelowe Keep Lumbermill"] = "DRAKE LUMB",
		["Kingscrest Keep Farm"] = "KINGS FARM", ["Kingscrest Keep Mine"] = "KINGS MINE", ["Kingscrest Keep Lumbermill"] = "KINGS LUMB",
		["Farragut Keep Farm"] = "FARRA FARM", ["Farragut Keep Mine"] = "FARRA MINE", ["Farragut Keep Lumbermill"] = "FARRA LUMB",

    },
    outpost = {
        ["Nikel Outpost"]       = "NIK", ["Carmala Outpost"]  = "CARM",
        ["Bleaker's Outpost"]   = "BLEAKERS", ["Winter's Peak Outpost"] = "WINTERS",
        ["Sejanus Outpost"]     = "SEJ", ["Harlun's Outpost"] = "HARLUN",
    },
    town = {
        ["Vlastarus"]           = "VLAST", ["Bruma"]            = "BRUMA", ["Cropsford"]        = "CROPS",
    },
    alliance = {
        [ALLIANCE_ALDMERI_DOMINION] = "AD",
        [ALLIANCE_EBONHEART_PACT]   = "EP",
        [ALLIANCE_DAGGERFALL_COVENANT] = "DC",
        [ALLIANCE_NONE]             = "--",
    }
}

local function getAbbr(name, otype)
    name = canon(name)
    if ABBR[otype] and ABBR[otype][name] then
        return ABBR[otype][name]
    end
    local parent = parentKeepForResource(name)
    if parent and ABBR.keep[parent] then
        return ABBR.keep[parent] ..
            (name:find("Farm") and "F" or name:find("Mine") and "M" or "L")
    end
    return name:sub(1, 3):upper()
end


--------------------------------------------------------------
-- MESSAGE STYLE SYSTEM (Immersive / Compact / Quick)
--------------------------------------------------------------
local STYLE = "immersive"

--------------------------------------------------------------
-- UNDER ATTACK (Colour-aware for all styles)
--------------------------------------------------------------
local function ChatPlace(name, kind)
    return INFO_COLOR .. (STYLE == "quick" and getAbbr(name, kind) or DisplayPlace(name)) .. "|r|cFFFFFF"
end

local function sayUnderAttack(name, owner, territory, kind, myAlliance)
    if not matrixAllows(kind, territory) then return end
    local place, faction = ChatPlace(name, kind), FactionText(owner)
    local message
    if STYLE ~= "immersive" then
        message = faction .. " under attack at " .. place .. "."
    elseif kind == "resource" then
        message = owner == myAlliance and ("Defend " .. place .. ", protect the supply line.")
            or (faction .. " under attack at " .. place .. ".")
    elseif kind == "town" then
        message = owner == myAlliance and ("Defend " .. place .. ", hold the town.")
            or (faction .. " under attack at " .. place .. ".")
    elseif owner == myAlliance and territory == myAlliance then
        message = "Defend " .. place .. ", our lands are under attack."
    elseif owner == myAlliance then
        message = "Hold " .. place .. ", our territory is under attack."
    elseif territory == myAlliance then
        message = "Reclaim " .. place .. ", the " .. faction .. " are under attack."
    else
        message = faction .. " under attack at " .. place .. "."
    end
    chat(message)
end

local function sayResolution(name, oldOwner, owner, territory, kind, myAlliance)
    if not matrixAllows(kind, territory) then return end
    local place, faction = ChatPlace(name, kind), FactionText(owner)
    local message
    if STYLE ~= "immersive" then
        message = faction .. " take " .. place .. "."
    elseif kind == "resource" then
        message = faction .. " now control " .. place .. (owner == myAlliance
            and ", securing the supply line." or ", changing the supply line.")
    elseif owner == territory then
        message = faction .. " reclaim " .. place .. "."
    elseif owner == myAlliance then
        message = faction .. " take " .. place .. ", our territory expands."
    elseif territory == myAlliance then
        message = place .. " lost, the " .. faction .. " now hold our lands."
    elseif oldOwner == myAlliance then
        message = place .. " lost, the " .. faction .. " take control."
    else
        message = faction .. " take " .. place .. "."
    end
    chat(message)
end

--------------------------------------------------------------
--------------------------------------------------------------
-- State Machine
--------------------------------------------------------------
-- Siege intelligence uses current ownership; homeland is only a wording/filter input.
local STATE, OBJECTIVES, RESOURCE_PARENTS = {}, {}, {}
local activeCampaign, scanNumber = nil, 0
local trackingSuspended = false
local function InCyrodiil()
    return IsInCyrodiil() and not IsInImperialCity() and not IsActiveWorldBattleground()
end

-- Announce actual coronations, never infer them from six-keep ownership.
local lastCoronationKey, lastCoronationAt = nil, 0
local function OnCoronation(_, campaignId, characterName, alliance, displayName)
    if trackingSuspended or not InCyrodiil() or campaignId ~= GetCurrentCampaignId()
        or alliance ~= GetUnitAlliance("player") then return end
    local name = characterName
    if type(name) ~= "string" or name == "" then name = displayName end
    if type(name) ~= "string" or name == "" then return end
    local key = tostring(campaignId) .. ":" .. tostring(alliance) .. ":" .. name
    local now = nowMs()
    if key == lastCoronationKey and now - lastCoronationAt < 10000 then return end
    lastCoronationKey, lastCoronationAt = key, now
    if zo_strformat then name = zo_strformat("<<1>>", name) end
    chat(SafeColor(alliance) .. name .. "|r|cFFFFFF crowned Emperor in the name of "
        .. SafeColor(alliance) .. SafeMonarch(alliance) .. "|r|cFFFFFF!")
end

local function BuildObjectiveIndex()
    OBJECTIVES, RESOURCE_PARENTS = {}, {}
    local seen = {}
    for index = 1, GetNumKeeps() do
        local id, context = GetKeepKeysByIndex(index)
        if IsLocalBattlegroundContext(context) and not seen[id] then
            seen[id] = true
            local name = GetKeepName(id)
            local kind = getObjectiveType(name, id)
            if kind ~= "other" then OBJECTIVES[#OBJECTIVES + 1] = id end
            if kind == "keep" then
                for _, resourceType in ipairs({ RESOURCETYPE_FOOD, RESOURCETYPE_ORE, RESOURCETYPE_WOOD }) do
                    local resourceId = GetResourceKeepForKeep(id, resourceType)
                    if resourceId and resourceId > 0 then RESOURCE_PARENTS[resourceId] = id end
                end
            end
        end
    end
end

local function ReadState(id)
    local name = GetKeepName(id)
    if not name or name == "" then return end
    local kind = getObjectiveType(name, id)
    if kind == "other" then return end
    local parent = RESOURCE_PARENTS[id]
    local territory = resolveTerritory(parent and GetKeepName(parent) or name, parent or id)
    return name, GetKeepAlliance(id, BG_CONTEXT), GetKeepUnderAttack(id, BG_CONTEXT), territory, kind
end

local function NewState(owner, under)
    return { owner = owner, under = under, siege = {}, announcedSiege = {},
        lastSiegeAt = -math.huge, flagThreats = {} }
end

local function SaySiege(name, owner, territory, kind, counts)
    if not matrixAllows(kind, territory) then return end
    local words = { "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
        "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen", "twenty" }
    local forces = {}
    for alliance = 1, NUM_ALLIANCES do
        if counts[alliance] and counts[alliance] > 0 then
            local count = STYLE == "immersive" and words[counts[alliance]] or nil
            local faction = STYLE == "immersive" and SafeName(alliance) or FACTION[alliance].tag
            forces[#forces + 1] = (count or tostring(counts[alliance])) .. " " .. SafeColor(alliance) .. faction .. "|r|cFFFFFF"
        end
    end
    local report = table.concat(forces, " and ") .. " siege attacking."
    local place = INFO_COLOR .. DisplayPlace(name) .. "|r|cFFFFFF"
    if STYLE == "quick" then
        chat(INFO_COLOR .. getAbbr(name, kind) .. "|r: " .. report)
    elseif STYLE == "compact" then
        chat(place .. ": " .. report)
    elseif owner == GetUnitAlliance("player") then
        local order = territory == GetUnitAlliance("player") and "Defend " or "Hold "
        chat(order .. place .. ", " .. report)
    elseif territory == GetUnitAlliance("player") then
        chat("Reclaim " .. place .. ", " .. report)
    else
        chat(FactionText(owner) .. " hold " .. place .. ", " .. report)
    end
end

local function CheckSiege(id, st, name, owner, territory, kind)
    if kind ~= "keep" then return end
    local counts, freshFaction, growth = {}, false, false
    if not FACTION[owner] or owner == ALLIANCE_NONE then
        st.siege, st.announcedSiege = {}, {}
        return
    end
    for alliance = 1, NUM_ALLIANCES do
        if alliance ~= owner then
            local count = GetNumSieges(id, BG_CONTEXT, alliance) or 0
            if count > 0 then
                counts[alliance] = count
                if not st.siege[alliance] then freshFaction = true end
                if count >= (st.announcedSiege[alliance] or count) + 2 then growth = true end
            else
                st.announcedSiege[alliance] = nil
            end
        end
    end
    local now = nowMs()
    if freshFaction or (growth and now - st.lastSiegeAt >= 10000) then
        SaySiege(name, owner, territory, kind, counts)
        st.announcedSiege = {}
        for alliance, count in pairs(counts) do st.announcedSiege[alliance] = count end
        st.lastSiegeAt = now
    end
    st.siege = counts
end

local function HandleUpdate(id, ownerOverride, oldOwner, attackOverride)
    if not InCyrodiil() then return end
    local name, owner, under, territory, kind = ReadState(id)
    if not name then return end
    if ownerOverride ~= nil then owner = ownerOverride end
    if attackOverride ~= nil then under = attackOverride end
    local st = STATE[id]
    if not st then
        st = NewState(oldOwner or owner, false)
        STATE[id] = st
    end
    local playerAlliance = GetUnitAlliance("player")
    local changedOwner = owner ~= st.owner
    if changedOwner then
        if owner == ALLIANCE_NONE then
            if matrixAllows(kind, territory) then chat("Control of " .. ChatPlace(name, kind) .. " is disputed.") end
        else
            sayResolution(name, st.owner, owner, territory, kind, playerAlliance)
        end
        st.siege, st.announcedSiege, st.flagThreats = {}, {}, {}
    end
    if under and not st.under and not changedOwner then
        sayUnderAttack(name, owner, territory, kind, playerAlliance)
    elseif not under and st.under and not changedOwner then
        if matrixAllows(kind, territory) then
            local message = FactionText(owner) .. " hold " .. INFO_COLOR .. DisplayPlace(name) .. "|r"
            if kind == "resource" then message = message .. ", securing the supply line." else message = message .. "." end
            chat(message)
        end
    end
    st.owner, st.under = owner, under
    CheckSiege(id, st, name, owner, territory, kind)
end

local function ResetTracking()
    STATE, activeCampaign, scanNumber = {}, GetCurrentCampaignId(), 0
    BuildObjectiveIndex()
    -- Snapshot existing owners without inventing captures. Siege is checked on the next scan.
    for _, id in ipairs(OBJECTIVES) do
        local name, owner, under = ReadState(id)
        if name then STATE[id] = NewState(owner, under) end
    end
end

local function EnsureContext()
    if trackingSuspended or not InCyrodiil() then return false end
    if activeCampaign ~= GetCurrentCampaignId() then ResetTracking() end
    return true
end

local function OnKeepUnderAttackChanged(_, id, context, under)
    if IsLocalBattlegroundContext(context) and EnsureContext() then HandleUpdate(id, nil, nil, under) end
end
local function OnKeepOwnerChanged(_, id, context, owner, oldOwner)
    if IsLocalBattlegroundContext(context) and EnsureContext() then HandleUpdate(id, owner, oldOwner) end
end
local function OnKeepResourceUpdate(_, id)
    if EnsureContext() then HandleUpdate(id) end
end
local function OnObjectiveControlState(_, id, objectiveId, context, objectiveName, objectiveType, controlEvent, controlState)
    if not IsLocalBattlegroundContext(context) or not EnsureContext() then return end
    local name, owner, under, territory, kind = ReadState(id)
    if not name or (kind ~= "resource" and kind ~= "town") then return end
    local st = STATE[id] or NewState(owner, under)
    STATE[id] = st
    if controlEvent == OBJECTIVE_CONTROL_EVENT_ASSAULTED or controlEvent == OBJECTIVE_CONTROL_EVENT_UNDER_ATTACK then
        local alreadyThreatened = next(st.flagThreats) ~= nil
        st.flagThreats[objectiveId] = true
        if not alreadyThreatened and not st.under then
            sayUnderAttack(name, owner, territory, kind, GetUnitAlliance("player"))
        end
    elseif controlEvent == OBJECTIVE_CONTROL_EVENT_CAPTURED or controlEvent == OBJECTIVE_CONTROL_EVENT_RECAPTURED
        or controlEvent == OBJECTIVE_CONTROL_EVENT_FULLY_HELD or controlEvent == OBJECTIVE_CONTROL_EVENT_DEACTIVATED then
        st.flagThreats[objectiveId] = nil
    end
    -- Objective capture is not necessarily whole-town ownership. The owner event handles that.
end

local function OnTacticalPopulationReady()
    if not populationRequestedAt or not TacticalEligible() or not InCyrodiil()
        or tacticalPopulationCampaign ~= GetCurrentCampaignId() then return end
    tacticalPopulation = nil
    for index = 1, GetNumSelectionCampaigns() do
        if GetSelectionCampaignId(index) == tacticalPopulationCampaign then
            local population = {}
            for alliance = 1, NUM_ALLIANCES do
                local tier = GetSelectionCampaignPopulationData(index, alliance)
                if type(tier) ~= "number" or tier < CAMPAIGN_POP_LOW or tier > CAMPAIGN_POP_FULL then return end
                population[alliance] = tier
            end
            tacticalPopulation = population
            populationReceivedAt = nowMs()
            return
        end
    end
end

local function TacticalPopulationPressure(alliance)
    local now = nowMs()
    local campaignId = GetCurrentCampaignId()
    if not campaignId or campaignId <= 0 then return false end
    if tacticalPopulationCampaign ~= campaignId then
        tacticalPopulation, lastTacticalAdvice = nil, nil
        tacticalPopulationCampaign = campaignId
    end
    if not populationRequestedAt or now - populationRequestedAt >= 60000 then
        populationRequestedAt = now
        QueryCampaignSelectionData()
    end
    if not tacticalPopulation or now - populationReceivedAt > 120000 then return false end
    for enemy, tier in pairs(tacticalPopulation) do
        if enemy ~= alliance and tier - tacticalPopulation[alliance] >= 2 then return true end
    end
    return false
end

local function CountFriendlyLinks(keeps, alliance)
    local links = {}
    for index = 1, GetNumKeepTravelNetworkLinks(BG_CONTEXT) do
        local first, second = GetKeepTravelNetworkLinkEndpoints(index, BG_CONTEXT)
        if first and first > 0 and second and second > 0 then
            local a = GetKeepTravelNetworkNodeKeepId(first, BG_CONTEXT)
            local b = GetKeepTravelNetworkNodeKeepId(second, BG_CONTEXT)
            if keeps[a] and keeps[b] then
                if keeps[a].owner == alliance then links[b] = (links[b] or 0) + 1 end
                if keeps[b].owner == alliance then links[a] = (links[a] or 0) + 1 end
            end
        end
    end
    return links
end

local function UpdateTacticalAdvice()
    if not TacticalEligible() then
        lastTacticalAdvice = nil
        return
    end

    local alliance = GetUnitAlliance("player")
    if not FACTION[alliance] or alliance == ALLIANCE_NONE then return end
    local solo = not IsUnitGrouped("player")
    local pressured = TacticalPopulationPressure(alliance)
    local keeps, expectedHomes, knownHomes = {}, 0, 0
    for _, homeAlliance in pairs(HOME_KEEPS) do
        if homeAlliance == alliance then expectedHomes = expectedHomes + 1 end
    end
    for _, id in ipairs(OBJECTIVES) do
        local name = GetKeepName(id)
        local homeAlliance = HOME_KEEPS[canon(name)]
        local state = STATE[id]
        if homeAlliance and state and FACTION[state.owner] then
            keeps[id] = { name = name, home = homeAlliance, owner = state.owner, under = state.under,
                siege = state.siege }
            if homeAlliance == alliance then knownHomes = knownHomes + 1 end
        end
    end
    if knownHomes < expectedHomes then return end

    local links = CountFriendlyLinks(keeps, alliance)
    local best
    for id, keep in pairs(keeps) do
        local friendly = keep.owner == alliance
        local home = keep.home == alliance
        local friendlySiege = keep.siege[alliance] ~= nil
        local friendlyLinks = links[id] or 0
        local priority, action, reason
        if home and friendly and (keep.under or next(keep.siege)) then
            priority, action, reason = 4, "Defend", "a home keep is under pressure."
        elseif home and not friendly then
            priority, action, reason = 3, "Retake", "your alliance has lost a home keep."
            if friendlySiege then
                action, reason = "Join the retake at", "your alliance has siege deployed."
            end
        elseif not friendly and keep.owner ~= ALLIANCE_NONE and friendlyLinks > 0
            and (friendlySiege or (not solo and not pressured)) then
            priority, action, reason = 2, "Push", friendlySiege and "your alliance has siege on the front line."
                or "it has a Transitus link to a friendly keep."
        elseif friendly and (home or keep.under) then
            priority, action, reason = 1, "Hold", pressured and "an enemy alliance has a higher campaign population tier."
                or "there is no supported push on the map."
        end

        local support = (friendlySiege and 1 or 0)
        if priority and (not best or priority > best.priority
            or (priority == best.priority and (friendlyLinks > best.links
                or (friendlyLinks == best.links and (support > best.support
                    or (support == best.support and id < best.id)))))) then
            best = { id = id, name = keep.name, priority = priority, links = friendlyLinks,
                support = support, action = action, reason = reason }
        end
    end

    if best and best.action == "Retake" and (solo or pressured) then
        local target, targetName
        for id, parent in pairs(RESOURCE_PARENTS) do
            if parent == best.id and (not target or id < target) then
                local owner, name = GetKeepAlliance(id, BG_CONTEXT), GetKeepName(id)
                if owner ~= alliance and owner ~= ALLIANCE_NONE and FACTION[owner] and name and name ~= "" then
                    target, targetName = id, name
                end
            end
        end
        if target then
            best.reason = "secure a resource for the retake of " .. best.name .. "."
            best.id, best.name, best.action = target, targetName, "Take"
        else
            best.action, best.reason = "Rally for", "it is a lost home keep with no friendly siege reported."
        end
    end

    local key = best and (best.action .. ":" .. best.id)
    if key and key ~= lastTacticalAdvice and not muted then
        chat("Tactical: " .. best.action .. " " .. best.name .. ". " .. best.reason)
        lastTacticalAdvice = key
    elseif not key then
        lastTacticalAdvice = nil
    end
end

local function Scan()
    if not EnsureContext() then return end
    scanNumber = scanNumber + 1
    for _, id in ipairs(OBJECTIVES) do
        if GetKeepType(id) == KEEPTYPE_KEEP or scanNumber % 5 == 0 then HandleUpdate(id) end
    end
    UpdateTacticalAdvice()
end
local function ActivateTracking()
    trackingSuspended = false
    EM:UnregisterForUpdate(ADDON_NAME .. "_Scan")
    STATE, activeCampaign = {}, nil
    if not InCyrodiil() then
        lastTacticalAdvice, tacticalPopulation = nil, nil
        return
    end
    ResetTracking()
    EM:RegisterForUpdate(ADDON_NAME .. "_Scan", 2000, Scan)
end
local function DeactivateTracking()
    trackingSuspended = true
    lastTacticalAdvice, tacticalPopulation = nil, nil
    EM:UnregisterForUpdate(ADDON_NAME .. "_Scan")
    STATE, activeCampaign = {}, nil
end


--------------------------------------------------------------
-- Settings Menu
--------------------------------------------------------------
local function BuildSettingsMenu()
    local LHA = LibHarvensAddonSettings
    if not LHA then
        chat("Settings unavailable, LibHarvensAddonSettings is missing.", true)
        return
    end
    if not EOK_SV.alertMatrix then
        EOK_SV.alertMatrix = {
            keep = { true, true, true },
            outpost = { true, true, true },
            town = { true, true, true },
            resource = { true, true, true },
        }
    end
    local panel = LHA:AddAddon(ADDON_NAME, { allowDefaults = true, allowRefresh = true })
    if not panel then return end

    local factions = { "Aldmeri Dominion", "Ebonheart Pact", "Daggerfall Covenant" }
    local types = { "keep", "outpost", "town", "resource" }

    for _, typ in ipairs(types) do
        local typeKey = typ
        panel:AddSetting({ type = LHA.ST_SECTION, label = string.upper(typeKey) .. " Alerts (by home territory)" })
        for i = 1, 3 do
            local allianceIndex = i
            panel:AddSetting({
                type = LHA.ST_CHECKBOX,
                label = factions[allianceIndex],
                tooltip = "Alert when " .. typeKey .. " in " .. factions[allianceIndex] .. " home territory is attacked",
                getFunction = function() return EOK_SV.alertMatrix[typeKey][allianceIndex] ~= false end,
                setFunction = function(v)
                    if not EOK_SV.alertMatrix[typeKey] then EOK_SV.alertMatrix[typeKey] = {} end
                    EOK_SV.alertMatrix[typeKey][allianceIndex] = v
                end,
            })
        end
    end

    EyeOnKeep_Framework:AddProfileControls(panel)
    EyeOnKeep_Framework:AddFooter(panel)
end


--------------------------------------------------------------
-- Slash Commands
--------------------------------------------------------------

SLASH_COMMANDS["/eyemute"] = function()
    muted = not muted
    chat("Alerts " .. (muted and "|cFF4444muted|r" or "|c00FF00resumed|r") .. ".", true)
    if not muted then lastTacticalAdvice = nil end
end

SLASH_COMMANDS["/eoktactical"] = function()
    tacticalEnabled = not tacticalEnabled
    lastTacticalAdvice = nil
    local status = tacticalEnabled and "on" or "off"
    local paused = tacticalEnabled and (not InCyrodiil() or not TacticalEligible())
    chat("Tactical mode " .. status .. (paused and ". Advice requires Cyrodiil and solo play or crown." or "."), true)
    if TacticalEligible() and EnsureContext() then Scan() end
end

--------------------------------------------------------------
-- Init
--------------------------------------------------------------

--------------------------------------------------------------
-- Init function
--------------------------------------------------------------
local function EyeOnKeep_Init()
    if _inited then return end
    _inited = true

    -- 🔧 Create SavedVars FIRST
    EOK_SV = EyeOnKeep_Framework:NewAccountWide("EyeOnKeep_SV", EOK_SV_VERSION, nil, DEFAULTS)

    -- 🔧 Restore saved message style (fallback = immersive)
    STYLE = EOK_SV.messageStyle or "immersive"

    -- 🔧 Style command (persistent)
    SLASH_COMMANDS["/eokstyle"] = function(arg)
        arg = (arg or ""):lower()
        if arg == "compact" or arg == "quick" or arg == "immersive" then
            STYLE = arg
            EOK_SV.messageStyle = STYLE
            chat("Message style: |cFFFF00" .. arg:upper() .. "|r", true)
        else
            chat("Current: |cFFFF00" .. STYLE:upper() ..
                 "|r  |cFFFFFF/eokstyle immersive | compact | quick|r", true)
        end
    end


    --------------------------------------------------------------
    -- Register Core Events
    --------------------------------------------------------------
    EM:RegisterForEvent(ADDON_NAME.."_Coronation", EVENT_CORONATE_EMPEROR_NOTIFICATION, OnCoronation)
    EM:RegisterForEvent(ADDON_NAME.."_Attack", EVENT_KEEP_UNDER_ATTACK_CHANGED, OnKeepUnderAttackChanged)
    EM:RegisterForEvent(ADDON_NAME.."_Owner", EVENT_KEEP_ALLIANCE_OWNER_CHANGED, OnKeepOwnerChanged)
    EM:RegisterForEvent(ADDON_NAME.."_Objective", EVENT_OBJECTIVE_CONTROL_STATE, OnObjectiveControlState)
    EM:RegisterForEvent(ADDON_NAME.."_Resource", EVENT_KEEP_RESOURCE_UPDATE, OnKeepResourceUpdate)
    EM:RegisterForEvent(ADDON_NAME.."_TacticalPopulation", EVENT_CAMPAIGN_SELECTION_DATA_CHANGED, OnTacticalPopulationReady)

    
    --------------------------------------------------------------
    -- Zone-scoped event tracking and two-second siege scan
    --------------------------------------------------------------
    EM:RegisterForEvent(ADDON_NAME.."_Activated", EVENT_PLAYER_ACTIVATED, ActivateTracking)
    EM:RegisterForEvent(ADDON_NAME.."_Deactivated", EVENT_PLAYER_DEACTIVATED, DeactivateTracking)
    EM:RegisterForEvent(ADDON_NAME.."_Campaign", EVENT_CURRENT_CAMPAIGN_CHANGED, ActivateTracking)
    EM:RegisterForEvent(ADDON_NAME.."_KeepsReady", EVENT_KEEPS_INITIALIZED, ActivateTracking)
    EM:RegisterForEvent(ADDON_NAME.."_KeepReady", EVENT_KEEP_INITIALIZED, function()
        if InCyrodiil() then BuildObjectiveIndex() end
    end)
    ActivateTracking()

    --------------------------------------------------------------
    -- Settings Menu
    --------------------------------------------------------------
    BuildSettingsMenu()

    --------------------------------------------------------------
    -- Startup Message
    --------------------------------------------------------------
    local myAlliance = GetUnitAlliance("player") or ALLIANCE_NONE
    local f = FACTION[myAlliance] or FACTION[ALLIANCE_NONE]
    local campaign = "Unknown Campaign"
    if GetCurrentCampaignId and GetCampaignName then
        local id = GetCurrentCampaignId()
        if id and id > 0 then campaign = GetCampaignName(id) or campaign end
    end
    chat(string.format("%sEyeOnKeep|r %s ready, watching %s%s|r for the %s%s|r.",
        FACTION[1].color, EyeOnKeep.version, INFO_COLOR, campaign, f.color, f.name))
end

--------------------------------------------------------------
-- On Load
--------------------------------------------------------------
local function OnAddonLoaded(_, addon)
    if addon ~= ADDON_NAME then return end
    EM:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    EyeOnKeep_Init()
end
EM:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)

