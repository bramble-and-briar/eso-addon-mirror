
FrankGrinder.elms = FrankGrinder.elms or {
    
    elmsData = {
        -- Night Market
        [1559] = "/1559//81938,30833,61270,1//1559//88654,30798,67282,2//1559//89336,30779,72436,3//1559//87496,30798,78100,4//1559//80663,30966,75239,5//1559//70653,30759,71316,27//1559//85400,33970,234597,31//1559//78382,35410,217892,30//1559//88672,33897,219902,28//1559//237896,31251,139818,30//1559//241417,31440,140876,29//1559//234255,31162,131147,30//1559//219179,31422,126225,30//1559//211281,31875,130573,32//1559//214587,31383,140496,28//1559//231071,33602,142992,31//1559//230739,33619,141168,28//1559//228534,31223,149526,32//1559//220626,31557,153107,31//1559//226692,31104,150002,26//1559//191417,31390,145768,28//1559//188223,31121,150464,32//1559//197401,33706,163123,31//1559//197734,31113,156385,29//1559//201912,31129,155578,24//1559//195089,31659,170976,23//1559//211655,31117,168234,29//1559//205788,31053,175878,24//1559//195009,31043,154315,30//1559//222283,31415,125686,29//1559//87592,30912,77039,24//1559//81135,30624,84079,25//1559//79707,30979,77490,32//1559//84688,30952,68975,29//1559//84650,30750,65931,28//1559//76552,30692,55849,32//1559//71388,30623,58898,29//1559//81847,33193,68678,30//1559//82002,33193,67739,31//1559//72396,30609,71292,29//1559//60505,30908,61554,32//1559//62763,30688,59262,25//1559//66057,30574,55470,26//1559//80268,30592,60022,25//1559//84291,32787,84597,31//1559//89325,30612,86909,31//1559//69067,30769,86281,27//1559//84238,34022,234944,23//1559//69802,34000,236962,28//1559//66028,33879,239070,28//1559//66886,33875,237025,32//1559//69683,33986,233364,28//1559//81109,33888,222731,32//1559//78881,34420,212238,28//1559//82412,33954,215383,26//1559//80679,34000,211019,28//1559//77766,33999,223687,31//1559//83949,34229,225437,28//1559//69600,34084,227829,25//1559//67921,34051,230927,31//1559//68352,36081,235233,30//1559//82883,33997,240800,30//1559//189238,31388,166418,26//1559//207333,31255,154427,27//1559//227545,31049,142548,24//1559//87604,33927,232452,27//1559//87736,34132,215803,28//1559//84934,34263,212782,28//1559//219704,31263,170402,26//1559//72870,34280,238945,25//1559//64943,33927,234219,24//1559//77903,34021,229922,26//1559//74158,33960,224342,28//1559//78864,34016,217227,29//1559//73559,34056,220459,27//1559//71354,34328,221821,29//1559//66889,33879,224090,29//1559//70260,34090,226813,29//1559//75800,33951,227322,29//1559//77476,34018,235884,29//1559//215518,31227,174562,27//1559//215065,31239,164546,25//1559//217524,31256,164449,23//1559//188398,31388,168264,30//1559//198339,31093,164975,23//1559//67755,34083,233917,30//1559//80552,34077,219276,29/"
    }

}

--  List quests in the journal
-- /script for i=1,GetNumJournalQuests() do d(string.format("%d - %s", GetJournalQuestId(i), zo_strformat("<<t:1>>", GetJournalQuestName(i)))) end

local NMQuestShareIds = {
    7400, -- Argent Eradication
    7403, -- Brazen Eradication
    7405, -- Fleet and Swift
    7406, -- Keen of Mind
    7404, -- Representing the Faction
    7381, -- Blood on the Sands
}

local NMZoneQuestIds = {
    PARCH = {
        7458, -- Scavenger's Riddles
        7454, -- Free the Caged
        7455, -- Fatal Flask
        7460, -- Ink-Parched
        7456, -- Adding to the Collection
    },
    SKITTER = {
        7433, -- Missing Persons
        7435, -- Sullied Reputations
        7432, -- District Field Journal
        7437, -- Curio Collection
        7461, -- Too Many Spiders
    },
    SORROW = {
        7438, -- Defacement
        7439, -- Blunt Steel
        7451, -- Express Delivery
        7459, -- Dark and Empty Spaces
        7457, -- Restocking the Bizarre
    }
}

--------------------------------------------------------------------------------
-- NM KEY FARM AUTOMATION (Night Market / Adventure Zone Event)
--------------------------------------------------------------------------------

local NM_UPDATE_NAME = "NMKeyFarmTick"
local NM_TICK_MS = 3000
local NM_TARGET_SIZE = 12
local NM_FG_ADDON_ADVERT = "\n\nBy Frank's Gear Grinder"


-- Session-only toggle (no SavedVars)
function FrankGrinder:IsNMKeyFarmEnabled()
    return self.nmKeyFarmActive == true
end

function FrankGrinder:SetNMKeyFarmEnabled(enabled)
    self.nmKeyFarmActive = (enabled == true)
end

function FrankGrinder:RemoveMyGroupFinderListingIfAny()
    local userType = GetCurrentGroupFinderUserType()
    if userType == GROUP_FINDER_GROUP_LISTING_USER_TYPE_CREATED_GROUP_LISTING then
        RequestRemoveGroupListing()
        return true
    end
    return false
end

function FrankGrinder:NM_KickOfflineGroupMembersIfEnabled()
  local c = self:NM_GetKeyFarmConfig()
  if not (c and c.kickOffline == true) then
    return false
  end

  -- Only leader can kick; TaosGroupTools guards this way too
  if not (GetIsUnitGrouped() and IsUnitGroupLeader("player")) then
    return false
  end

  local kickedAny = false
  for i = 1, GetGroupSize() do
    local unitTag = GetGroupUnitTagByIndex(i)
    if unitTag and unitTag ~= "player" then
      if IsUnitOnline(unitTag) == false then
        GroupKick(unitTag)
        kickedAny = true
      end
    end
  end

  return kickedAny
end

function FrankGrinder:NM_DisableAndCleanup(reason)
    -- Turn automation off
    self:SetNMKeyFarmEnabled(false)

    self._nmCreateInFlight = false
    self._nmFallbackTried = false

    -- Stop the tick immediately
    EVENT_MANAGER:UnregisterForUpdate(self.name .. "." .. NM_UPDATE_NAME)

    -- Remove listing if it exists
    self:RemoveMyGroupFinderListingIfAny()

    if self:IsDebugEnabled() then
        self:DebugMsg("NMKeyFarm disabled: " .. tostring(reason))
    end

    self:ChatMsg(GetString(GG_NM_GROUP_AUTO) .. ": " .. GetString(GG_NM_GROUP_AUTO_OFF) .. " (" .. reason .. ")")
end

-- District/boss enums from Adventure Zone boss tree mapping
FrankGrinder.NM_ARGENT = FrankGrinder.NM_ARGENT or {
    DISTRICTS = {
        SKITTER = {
            label = "Skitter",
            locationIndex = 1,
            bosses = {
                ADVENTURE_ZONE_BOSS_SKITTERING_WORLD_BOSS_1,
                ADVENTURE_ZONE_BOSS_SKITTERING_WORLD_BOSS_2,
            },
        },
        SORROW = {
            label = "Sorrow",
            locationIndex = 3,
            bosses = {
                ADVENTURE_ZONE_BOSS_SORROWS_FRIEND_WORLD_BOSS_1,
                ADVENTURE_ZONE_BOSS_SORROWS_FRIEND_WORLD_BOSS_2,
            },
        },
        PARCH = {
            label = "Parch",
            locationIndex = 2,
            bosses = {
                ADVENTURE_ZONE_BOSS_PARCH_WORLD_BOSS_1,
                ADVENTURE_ZONE_BOSS_PARCH_WORLD_BOSS_2,
            },
        },
    },
    DISTRICT_ORDER = { "SKITTER", "SORROW", "PARCH" },
}

-- Boss abbreviations (enum-only mapping)
FrankGrinder.NM_BOSS_ABBREV = {
    -- Skitter
    [ADVENTURE_ZONE_BOSS_SKITTERING_WORLD_BOSS_1]      = "Abom",
    [ADVENTURE_ZONE_BOSS_SKITTERING_WORLD_BOSS_2]      = "LdyNas",

    -- Sorrow (Sorrows Friend)
    [ADVENTURE_ZONE_BOSS_SORROWS_FRIEND_WORLD_BOSS_1]  = "Kovan",
    [ADVENTURE_ZONE_BOSS_SORROWS_FRIEND_WORLD_BOSS_2]  = "Exarch",

    -- Parch
    [ADVENTURE_ZONE_BOSS_PARCH_WORLD_BOSS_1]           = "Titan",
    [ADVENTURE_ZONE_BOSS_PARCH_WORLD_BOSS_2]           = "Ozezan",
}

-- ------------------------------------------------------------
-- Dungeon Keyfarm boss enums (instance bosses) + placeholders
-- You said you'll fill the names later.
-- ------------------------------------------------------------
FrankGrinder.NM_DUNGEON_BOSSES = {
  ADVENTURE_ZONE_BOSS_PARCH_INSTANCE_BOSS,
  ADVENTURE_ZONE_BOSS_SKITTERING_INSTANCE_BOSS,
  ADVENTURE_ZONE_BOSS_SORROWS_FRIEND_INSTANCE_BOSS,
}

FrankGrinder.NM_DUNGEON_BOSS_ABBREV = {
  [ADVENTURE_ZONE_BOSS_PARCH_INSTANCE_BOSS] = "B'Kyfxi",  
  [ADVENTURE_ZONE_BOSS_SKITTERING_INSTANCE_BOSS] = "Alziriix",  
  [ADVENTURE_ZONE_BOSS_SORROWS_FRIEND_INSTANCE_BOSS] = "Knell", 
}

function FrankGrinder:NM_DungeonAllKeysObtained()
  for _, bossEnum in ipairs(self.NM_DUNGEON_BOSSES) do
    if not self:NM_IsKeyObtainedForBoss(bossEnum) then
      return false
    end
  end
  return true
end


-- Your rule: "key obtained" iff boss state is DEFEATED
function FrankGrinder:NM_IsKeyObtainedForBoss(bossEnum)
    return GetAdventureZoneBossState(bossEnum) == ADVENTURE_ZONE_BOSS_STATE_DEFEATED
end

-- District has a key if ANY of its bosses is defeated
function FrankGrinder:NM_HasKeyForDistrict(districtKey)
    local district = self.NM_ARGENT.DISTRICTS[districtKey]
    if not district then return false end
    for _, bossEnum in ipairs(district.bosses) do
        if self:NM_IsKeyObtainedForBoss(bossEnum) then
            return true
        end
    end
    return false
end

-- "All keys obtained" if ALL 6 bosses are defeated
function FrankGrinder:NM_AllKeysObtained()
    for _, dk in ipairs(self.NM_ARGENT.DISTRICT_ORDER) do
        local district = self.NM_ARGENT.DISTRICTS[dk]
        if district then
            for _, bossEnum in ipairs(district.bosses) do
                if not self:NM_IsKeyObtainedForBoss(bossEnum) then
                    return false
                end
            end
        end
    end
    return true
end

-- ------------------------------------------------------------
-- NM Keyfarm modes + config
-- ------------------------------------------------------------
local GF_TITLE_MAX = 50
local GF_DESC_MAX  = 100
local NM_MODE_DUNGEON  = "dungeon"
local NM_MODE_ARGENT   = "argent"
local NM_MODE_ADVENTURE = "adventure"

local function NM_GetTargetSizeForMode(mode)
  return (mode == NM_MODE_DUNGEON) and 4 or 12
end

local function NM_DefaultsForMode(mode)
  if mode == NM_MODE_DUNGEON then
    return { tank = 1, heal = 1, dps = 2, cp = 1000 }
  elseif mode == NM_MODE_ADVENTURE then
    return { tank = 2, heal = 2, dps = 8, cp = 160 }
  end
  -- Argent
  return { tank = 2, heal = 2, dps = 8, cp = 500 }
end

function FrankGrinder:NM_GetKeyFarmConfig()
  -- persisted config (SavedVars) with safe defaults
  local c = self.SV and self.SV.options and self.SV.options.nmAutomationConfig
  if type(c) ~= "table" then
    self.SV.options.nmAutomationConfig = ZO_DeepTableCopy(self.defaults.options.nmAutomationConfig or {})
    c = self.SV.options.nmAutomationConfig
  end
  c.mode = c.mode or (self.defaults.options.nmAutomationConfig and self.defaults.options.nmAutomationConfig.mode) or NM_MODE_ARGENT
  c.titlePrefix = tostring(c.titlePrefix or "")

    c.tank = tonumber(c.tank) or 2
    c.heal = tonumber(c.heal) or 2
    c.dps = tonumber(c.dps) or 8
    c.cp = tonumber(c.cp) or 500
    c.kickOffline = (c.kickOffline == true) -- default false unless explicitly set
    return c

end

function FrankGrinder:NM_ClampRolesToSize(c)
  local total = NM_GetTargetSizeForMode(c.mode)
  local function clamp(n, lo, hi)
    n = tonumber(n) or 0
    if n < lo then return lo end
    if n > hi then return hi end
    return n
  end
  c.tank = clamp(c.tank, 0, total)
  c.heal = clamp(c.heal, 0, total - c.tank)
  -- DPS becomes "remainder" to keep total consistent
  c.dps = total - (c.tank + c.heal)
  if c.dps < 0 then c.dps = 0 end
  -- CP basic clamp
  c.cp = clamp(c.cp, 0, 3600)
end

function FrankGrinder:NM_ApplyModeDefaults(mode)
  local c = self:NM_GetKeyFarmConfig()
  c.mode = mode
  local d = NM_DefaultsForMode(mode)
  c.tank, c.heal, c.dps, c.cp = d.tank, d.heal, d.dps, d.cp
  self:NM_ClampRolesToSize(c)
end


function FrankGrinder:GF_SanitiseText(s)
    s = tostring(s or "")
    s = s:gsub("\r", " "):gsub("\n", " ")
    s = s:gsub("%^N", " "):gsub("%^M", " "):gsub("%^n", " "):gsub("%^m", " ")
    s = s:gsub("[%c]", " ")
    s = s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

function FrankGrinder:GF_SmartTruncate(s, maxLen)
    s = tostring(s or "")
    if not maxLen or maxLen <= 0 or #s <= maxLen then return s end

    local cut = s:sub(1, maxLen)
    local lastComma = cut:match("^.*(),%s")
    if lastComma and lastComma > 1 then
        return cut:sub(1, lastComma - 1)
    end
    local lastSemi = cut:match("^.*();%s")
    if lastSemi and lastSemi > 1 then
        return cut:sub(1, lastSemi - 1)
    end
    local lastSpace = cut:match("^.*()%s")
    if lastSpace and lastSpace > 1 then
        return cut:sub(1, lastSpace - 1)
    end
    return cut
end

function FrankGrinder:BuildNMKeyFarmTitleAndDescription()
  local c = self:NM_GetKeyFarmConfig()
  self:NM_ClampRolesToSize(c)

  local prefix = self:GF_SanitiseText(c.titlePrefix or "")
  if prefix ~= "" then
    prefix = prefix .. " "
  end

  local mode = c.mode or NM_MODE_ARGENT
  local title, desc

  if mode == NM_MODE_DUNGEON then
    local missing = {}
    for _, bossEnum in ipairs(self.NM_DUNGEON_BOSSES) do
      if not self:NM_IsKeyObtainedForBoss(bossEnum) then
        table.insert(missing, self.NM_DUNGEON_BOSS_ABBREV[bossEnum] or "?")
      end
    end

    if #missing > 0 then
      title = prefix .. "Dungeon Keys"
      desc = "Bosses: " .. table.concat(missing, ", ")
    else
      title = prefix .. "Dungeon Keys: complete"
      desc = "All dungeon keys obtained"
    end

  elseif mode == NM_MODE_ADVENTURE then
    title = prefix .. "Adventuring"
    desc = "General Adventure Zone group. Please follow CROWN."

  else
    -- Argent Keyfarm (existing logic)
    local districtsToRun = {}
    local descParts = {}

    for _, dk in ipairs(self.NM_ARGENT.DISTRICT_ORDER) do
      local district = self.NM_ARGENT.DISTRICTS[dk]
      if district then
        local miss = {}
        for _, bossEnum in ipairs(district.bosses) do
          if not self:NM_IsKeyObtainedForBoss(bossEnum) then
            table.insert(miss, self.NM_BOSS_ABBREV[bossEnum] or "?")
          end
        end
        if #miss > 0 then
          table.insert(districtsToRun, district.label)
          table.insert(descParts, string.format("%s %s", district.label, table.concat(miss, ",")))
        end
      end
    end

    if #districtsToRun > 0 then
      title = prefix .. "Argent Keys: " .. table.concat(districtsToRun, "/")
      desc  = "Bosses: " .. table.concat(descParts, "; ")
    else
      title = prefix .. "Argent Keys: complete"
      desc  = "Bosses: none"
    end
  end

  title = self:GF_SanitiseText(title)
  title = self:GF_SmartTruncate(title, GF_TITLE_MAX)

  -- Sanitise the advert too, then budget for it, so the final description is
  -- control-character free and within the Group Finder limit.
  local advert = self:GF_SanitiseText(NM_FG_ADDON_ADVERT)
  if advert ~= "" then advert = " " .. advert end

  desc = self:GF_SanitiseText(desc)
  desc = self:GF_SmartTruncate(desc, GF_DESC_MAX - #advert)
  desc = desc .. advert

  return title, desc
end

-- Configure the DRAFT listing for Event Zone 12-person 2/2/8 CP500
function FrankGrinder:ConfigureDraftForNMKeyFarm()
  local c = self:NM_GetKeyFarmConfig()
  self:NM_ClampRolesToSize(c)

  local IS_EDITABLE = true
  local draft = ZO_GroupListingUserTypeData:New(
    GROUP_FINDER_GROUP_LISTING_USER_TYPE_GROUP_LISTING_DRAFT,
    IS_EDITABLE
  )
  draft:UpdateOptions()

  SetGroupFinderUserTypeGroupListingSecondaryOptionDefault(
    GROUP_FINDER_GROUP_LISTING_USER_TYPE_GROUP_LISTING_DRAFT
  )

  -- Category: Adventure Zone (stable enum)
  draft:SetCategory(GROUP_FINDER_CATEGORY_ADVENTURE_ZONE)
  draft:UpdateOptions()

  -- Size: choose target size from available flags (match label contains "4" or "12")
  local targetSize = NM_GetTargetSizeForMode(c.mode)
  local sizeFlagFound = nil
  local startFlag = draft:GetSizeMin()
  local endFlag = draft:GetSizeMax()

  for flag in ZO_FlagHelpers.FlagIterator(startFlag, endFlag) do
    local sizeLabel = GetString("SI_GROUPFINDERGROUPSIZE", flag)
    if sizeLabel and string.find(sizeLabel, tostring(targetSize)) then
      sizeFlagFound = flag
      break
    end
  end

  if not sizeFlagFound then
    return nil, "Could not resolve group size for Event Zone"
  end
  draft:SetSize(sizeFlagFound)

  -- Dynamic title/description per mode + key state
  local title, desc = self:BuildNMKeyFarmTitleAndDescription()
  draft:SetTitle(title)
  draft:SetDescription(desc)

  -- Enforce roles + composition (from config)
  draft:SetGroupEnforceRoles(true)
  draft:SetDesiredRoleCount(LFG_ROLE_TANK, c.tank)
  draft:SetDesiredRoleCount(LFG_ROLE_HEAL, c.heal)
  draft:SetDesiredRoleCount(LFG_ROLE_DPS,  c.dps)
  draft:SetDesiredRoleCount(LFG_ROLE_INVALID, 0)

  -- CP requirement (from config)
  draft:SetGroupRequiresChampion(true)
  draft:SetChampionPoints(tonumber(c.cp) or 0)

  return draft, nil
end

function FrankGrinder:IsTitleValidForGroupFinder(title)
    local violations = { IsValidGroupFinderListingTitle(title) }
    return (#violations == 0)
end

function FrankGrinder:NMKeyFarmTick()
  if not self:IsNMKeyFarmEnabled() then return end
  if self._nmCreateInFlight then return end

  local c = self:NM_GetKeyFarmConfig()
  self:NM_ClampRolesToSize(c)
  local mode = c.mode or NM_MODE_ARGENT
  local targetSize = NM_GetTargetSizeForMode(mode)

  -- Gate 0: Must be in the Adventure Zone (boss state API reliability)
  if not IsInAdventureZone() then
    self:NM_DisableAndCleanup(GetString(GG_NM_GROUP_AUTO_ERROR_NOTINZONE))
    return
  end

  -- Gate 1: Night Market must be active (time-limited)
  if not IsAdventureZoneActive() then
    self:NM_DisableAndCleanup(GetString(GG_NM_GROUP_AUTO_ERROR_ZONENOTACTIVE))
    return
  end

  -- Gate 2: auto-stop only for keyfarm modes
  if mode == NM_MODE_ARGENT and self:NM_AllKeysObtained() then
    self:NM_DisableAndCleanup(GetString(GG_NM_GROUP_AUTO_ALLDONE))
    return
  end
  if mode == NM_MODE_DUNGEON and self:NM_DungeonAllKeysObtained() then
    self:NM_DisableAndCleanup(GetString(GG_NM_GROUP_AUTO_ALLDONE))
    return
  end

  -- Group Finder must be available
  local status = GetGroupFinderStatusReason()
  if status ~= GROUP_FINDER_ACTION_RESULT_SUCCESS then
    return
  end

  local groupSize = GetGroupSize()
  local userType = GetCurrentGroupFinderUserType()
  local hasCreatedListing = (userType == GROUP_FINDER_GROUP_LISTING_USER_TYPE_CREATED_GROUP_LISTING)

    -- If group is full, optionally kick offline players and remove listing (but keep automation on)
    if groupSize >= targetSize then
      local kicked = self:NM_KickOfflineGroupMembersIfEnabled()

      -- If we kicked someone, we want to ensure the listing is removed (if present)
      -- so the next tick can recreate once group size drops on the server side.
      if kicked then
        if hasCreatedListing then
          RequestRemoveGroupListing()
        end
        return
      end

      -- Only share quests for Argent keyfarm mode
      if mode == NM_MODE_ARGENT or mode == NM_MODE_ADVENTURE then
        if self._nmSharedQuestsAtFull ~= true then
          if hasCreatedListing then
            RequestRemoveGroupListing()
            self._nmShareAfterDelist = true
            return
          end
          if self._nmShareAfterDelist or not hasCreatedListing then
            self:NM_ShareKeyFarmQuestsIfPresent()
            self._nmSharedQuestsAtFull = true
            self._nmShareAfterDelist = false
          end
        end
      end

      return
    end

  -- Group not full anymore: reset one-shot flags
  self._nmSharedQuestsAtFull = false
  self._nmShareAfterDelist = false

  -- Group not full: ensure listing exists
  if not hasCreatedListing then
    local draft, err = self:ConfigureDraftForNMKeyFarm()
    if not draft then
      if self:IsDebugEnabled() then
        self:DebugMsg("NMKeyFarm: " .. tostring(err))
      end
      return
    end

    local title = draft:GetTitle()
    if not self:IsTitleValidForGroupFinder(title) then
      if self:IsDebugEnabled() then
        self:DebugMsg("NMKeyFarm: title failed Group Finder title rules")
      end
      return
    end

    local canCreate, disabledString = ZO_GroupFinder_CanDoCreateEdit(draft, nil, false)
    if not canCreate then
      if self:IsDebugEnabled() then
        self:DebugMsg("NMKeyFarm: cannot create listing: " .. tostring(disabledString))
      end
      return
    end

    self._nmCreateInFlight = true
    RequestCreateGroupListing()
  end
end

function FrankGrinder:NM_OnCreateListingResult(result)
    -- Only care when NM automation is actively trying to manage listings
    if not self:IsNMKeyFarmEnabled() then return end

    if result == GROUP_FINDER_ACTION_RESULT_SUCCESS then
        -- reset fallback state
        self._nmFallbackTried = false
        self._nmCreateInFlight = false
        return
    end

    -- Mark request finished
    self._nmCreateInFlight = false

    -- If it failed and we haven't tried the fallback yet, apply fallback composition and retry once
    if not self._nmFallbackTried then
        self._nmFallbackTried = true

        local mode = self:NM_GetKeyFarmConfig().mode

        -- "All keys done" means different bosses per mode; Adventuring has no
        -- key goal at all, so it never auto-completes.
        local allKeysDone = false
        if mode == NM_MODE_DUNGEON then
            allKeysDone = self:NM_DungeonAllKeysObtained()
        elseif mode == NM_MODE_ARGENT then
            allKeysDone = self:NM_AllKeysObtained()
        end

        -- Only retry if we still need a listing (group not full, no listing exists, Night Market active, not all keys done)
        if IsAdventureZoneActive()
           and not allKeysDone
           and GetGroupSize() < NM_GetTargetSizeForMode(mode)
           and GetCurrentGroupFinderUserType() ~= GROUP_FINDER_GROUP_LISTING_USER_TYPE_CREATED_GROUP_LISTING
        then
            if self:IsDebugEnabled() then
                self:DebugMsg("NMKeyFarm: create failed (" .. tostring(result) .. "), retrying with fallback composition")
            end

            self:NM_ApplyFallbackCompositionFromAttained()
            self._nmCreateInFlight = true
            RequestCreateGroupListing()
        end
        return
    end
    
    -- Already tried fallback; auto end automation
    self:NM_DisableAndCleanup(GetString(GG_NM_GROUP_AUTO_ERROR_FAILEDTWICE))

end

function FrankGrinder:NM_RegisterCreateResultHandler()
    if self._nmCreateResultRegistered then return end
    self._nmCreateResultRegistered = true

    EVENT_MANAGER:RegisterForEvent(self.name .. ".NMCreateResult",
        EVENT_GROUP_FINDER_CREATE_GROUP_LISTING_RESULT,
        function(_, result)
            self:NM_OnCreateListingResult(result)
        end
    )
end

local function Clamp(n, lo, hi)
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

function FrankGrinder:NM_ApplyFallbackCompositionFromAttained()
    local userType = GROUP_FINDER_GROUP_LISTING_USER_TYPE_GROUP_LISTING_DRAFT

    -- Read attained counts from the draft user type (API-provided)
    local tank = GetGroupFinderUserTypeGroupListingAttainedRoleCount(userType, LFG_ROLE_TANK) or 0
    local heal = GetGroupFinderUserTypeGroupListingAttainedRoleCount(userType, LFG_ROLE_HEAL) or 0
    local dps  = GetGroupFinderUserTypeGroupListingAttainedRoleCount(userType, LFG_ROLE_DPS)  or 0
    
    -- LFG_ROLE_INVALID is "Any" but we'll keep strict (0) unless needed
    --local total = 12
    local c = self:NM_GetKeyFarmConfig()
    self:NM_ClampRolesToSize(c)
    local total = NM_GetTargetSizeForMode(c.mode)

    -- Sanity clamp
    tank = Clamp(tank, 0, total)
    heal = Clamp(heal, 0, total - tank)
    dps  = Clamp(dps,  0, total - tank - heal)

    -- Fill remaining slots into DPS (keeps listing usable)
    local remaining = total - (tank + heal + dps)
    dps = dps + remaining

    -- Apply desired counts directly to the draft listing
    -- First clear desired roles to avoid stale state
    GroupFinderUserTypeGroupListingClearDesiredRoles(userType)
    SetGroupFinderUserTypeGroupListingEnforceRoles(userType, true)
    SetGroupFinderUserTypeGroupListingRoleCount(userType, LFG_ROLE_TANK, tank)
    SetGroupFinderUserTypeGroupListingRoleCount(userType, LFG_ROLE_HEAL, heal)
    SetGroupFinderUserTypeGroupListingRoleCount(userType, LFG_ROLE_DPS,  dps)
    SetGroupFinderUserTypeGroupListingRoleCount(userType, LFG_ROLE_INVALID, 0)
end

-- Build a fast lookup table once (upvalue in this file)
local NMQuestShareIdSet = {}
for _, qid in ipairs(NMQuestShareIds) do
    NMQuestShareIdSet[qid] = true
end

function FrankGrinder:NM_ShareQuestsInJournalByIdSet(idSet)
    if GetGroupSize() < 2 then return 0 end -- nothing to share to
    local shared = 0

    for ji = 1, GetNumJournalQuests() do
        local qid = GetJournalQuestId(ji)
        if idSet[qid] then
            -- Only share if the API says it is sharable
            if GetIsQuestSharable and GetIsQuestSharable(ji) then
                ShareQuest(ji)
                shared = shared + 1
                if self.IsDebugEnabled and self:IsDebugEnabled() then
                    self:DebugMsg(string.format("NM: Shared quest %d (%s)", qid, tostring(GetJournalQuestName(ji))))
                end
            else
                if self.IsDebugEnabled and self:IsDebugEnabled() then
                    self:DebugMsg(string.format("NM: Quest %d in journal but not sharable right now", qid))
                end
            end
        end
    end

    return shared
end

function FrankGrinder:NM_ShareKeyFarmQuestsIfPresent()
    local count = self:NM_ShareQuestsInJournalByIdSet(NMQuestShareIdSet)
    if count > 0 then
        self:ChatMsg(GetString(GG_NM_GROUP_AUTO) .. ": " .. GetString(GG_NM_GROUP_AUTO_QUESTSHARE1) .. " " .. tostring(count) .. " ".. GetString(GG_NM_GROUP_AUTO_QUESTSHARE2))
    else
        if self.IsDebugEnabled and self:IsDebugEnabled() then
            self:DebugMsg("NM: no shareable NM quests found in journal.")
        end
    end
end

function FrankGrinder:ToggleNMKeyFarm()
  -- Requirement:
  -- - If automation is running: keybind turns it OFF
  -- - If automation is not running: only show config if in Night Market (Adventure Zone)
  if FrankGrinder.A() then
      if self:IsNMKeyFarmEnabled() then
        self:ToggleNMKeyFarmAutomation(false)
        return
      end

      -- Gate: Must be in the Adventure Zone before showing the pre-config UI
      if not IsInAdventureZone() then
        -- Keep messaging consistent with ToggleNMKeyFarmAutomation(true)
        self:ChatMsg(GetString(GG_NM_GROUP_AUTO) .. ": " ..
                     GetString(GG_NM_GROUP_AUTO_OFF) .. " (" ..
                     GetString(GG_NM_GROUP_AUTO_ERROR_NOTINZONE) .. ")")
        return
      end

      self:NM_ShowKeyFarmConfigWindow()
    end
end

-- enable: true/false/nil (nil => toggle)
function FrankGrinder:ToggleNMKeyFarmAutomation(enable)
    if enable == nil then
        enable = not self:IsNMKeyFarmEnabled()
    end

    -- If turning ON, enforce "must be in Adventure Zone" (see section 2)
    if enable then
        if not IsInAdventureZone() then
            -- Don't allow enable outside the Adventure Zone
            self:SetNMKeyFarmEnabled(false)
            self:InitializeNightMarketAutomation()
            self:RemoveMyGroupFinderListingIfAny()
            self:ChatMsg(GetString(GG_NM_GROUP_AUTO) .. ": " .. GetString(GG_NM_GROUP_AUTO_OFF) .. " (" .. GetString(GG_NM_GROUP_AUTO_ERROR_NOTINZONE) .. ")")
            return
        end
    end

    self:SetNMKeyFarmEnabled(enable)

    if not enable then
        -- IMPORTANT: stop tick first so it can't recreate
        self:InitializeNightMarketAutomation()
        local removed = self:RemoveMyGroupFinderListingIfAny()
        self:ChatMsg(GetString(GG_NM_GROUP_AUTO) .. ": " .. GetString(GG_NM_GROUP_AUTO_OFF) .. (removed and " (" .. GetString(GG_NM_GROUP_AUTO_LISTINGREMOVED) .. ")" or ""))
        return
    end

    -- enable case: clear transient retry state so first attempt is clean
    self._nmCreateInFlight = false
    self._nmFallbackTried = false

    self:ChatMsg(GetString(GG_NM_GROUP_AUTO) .. ": " .. GetString(GG_NM_GROUP_AUTO_ON))
    self:InitializeNightMarketAutomation()
end

--------------------------------------------------------------------------------
-- Initialiser: registers NM automation tick (session-only)
--------------------------------------------------------------------------------

function FrankGrinder:InitializeNightMarketAutomation()
    local EM = EVENT_MANAGER

    -- Ensure session toggle defaults OFF unless user turned it on via slash command
    self.nmKeyFarmActive = (self.nmKeyFarmActive == true) and true or false

    -- NM automation tick
    EM:UnregisterForUpdate(self.name .. "." .. NM_UPDATE_NAME)

    self:NM_RegisterCreateResultHandler()

    if self:IsNMKeyFarmEnabled() then
        EM:RegisterForUpdate(self.name .. "." .. NM_UPDATE_NAME, NM_TICK_MS, function()
            self:NMKeyFarmTick()
        end)
        self:NMKeyFarmTick()
    end
end


--------------------------
-- Night Market Elms injection
----

------------------------------------------------------------
-- Utility: Parse elms string into marker tables
------------------------------------------------------------
local function ParseElmsString(str)
    local markers = {}

    -- Matches: /92//133505,6189,298259,23/
    for zoneId, x, y, z, icon in string.gmatch(str, "/(%d+)//(%d+),(%d+),(%d+),(%d+)/") do
        zoneId = tonumber(zoneId)
        x = tonumber(x)
        y = tonumber(y)
        z = tonumber(z)
        icon = tonumber(icon)

        markers[zoneId] = markers[zoneId] or {}
        table.insert(markers[zoneId], {
            [1] = x,
            [2] = y,
            [3] = z,
            [4] = icon,
        })
    end

    return markers
end

------------------------------------------------------------
-- Add/remove markers from ElmsMarkers
------------------------------------------------------------

local function MarkersEqual(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end
    return a[1] == b[1]
       and a[2] == b[2]
       and a[3] == b[3]
       and a[4] == b[4]
end

function FrankGrinder:ElmsApplyMarkersForZone(zoneId)
    self:DebugMsg("ElmsApplyMarkersForZone : zoneId " .. tostring(zoneId))

    if not ElmsMarkers or not ElmsMarkers.savedVars or not ElmsMarkers.savedVars.positions then
        self:DebugMsg("ElmsApplyMarkersForZone: ElmsMarkers not found, cannot apply markers.")
        return
    end

    local zoneStr = self.elms.elmsData[zoneId]
    if not zoneStr then
        self:DebugMsg("ElmsApplyMarkersForZone: No elms data for zone " .. tostring(zoneId))
        return
    end

    self:DebugMsg("ElmsApplyMarkersForZone: Injecting markers for zone " .. tostring(zoneId))

    local markersByZone = ParseElmsString(zoneStr)
    local list = markersByZone[zoneId]
    if not list or #list == 0 then return end

    ElmsMarkers.savedVars.positions[zoneId] = ElmsMarkers.savedVars.positions[zoneId] or {}

    self:DebugMsg("ElmsApplyMarkersForZone: ElmsMarkers savedVars currently has " .. tostring(#ElmsMarkers.savedVars.positions[zoneId] or 0) .. " markers")

    local zoneList = ElmsMarkers.savedVars.positions[zoneId]
    for _, marker in ipairs(list) do
        table.insert(zoneList, marker)
        self:DebugMsg("Injected Elms marker zone " .. tostring(zoneId) ..
            ": " .. marker[1] .. ", " .. marker[2] .. ", " .. marker[3] .. ", icon " .. marker[4])
    end
    self:DebugMsg("ElmsApplyMarkersForZone: ElmsMarkers savedVars now has " .. tostring(#ElmsMarkers.savedVars.positions[zoneId] or 0) .. " markers")

    ElmsMarkers.CheckActivation()
end


function FrankGrinder:RemoveMarkerListFromZone(zoneId, zoneList, list)
    for _, marker in ipairs(list) do
        for i = #zoneList, 1, -1 do
            if MarkersEqual(zoneList[i], marker) then
                self:DebugMsg(string.format(
                    "RemoveMarkerListFromZone: Removed Elms marker zone %d: %d, %d, %d, icon %d",
                    zoneId, zoneList[i][1], zoneList[i][2], zoneList[i][3], zoneList[i][4]
                ))
                table.remove(zoneList, i)
            end
        end
    end

    -- Cleanup empty zone
    if next(zoneList) == nil then
        ElmsMarkers.savedVars.positions[zoneId] = nil
        self:DebugMsg("RemoveMarkerListFromZone: Zone " .. tostring(zoneId) .. " removed (no markers left).")
    end

    -- CheckActivation only clears icons for zones still present in
    -- positions, so an emptied zone would keep its icons drawn.
    if ElmsMarkers.RemovePositionIcons then
        ElmsMarkers.RemovePositionIcons(zoneId)
    end
end


function FrankGrinder:ElmsRemoveMarkers()
    if not (ElmsMarkers and ElmsMarkers.savedVars and ElmsMarkers.savedVars.positions) then
        self:DebugMsg("ElmsRemoveMarkers: ElmsMarkers not found, cannot remove markers.")
        return
    end

    for zoneId, zoneStr in pairs(self.elms.elmsData) do
        local markersByZone = ParseElmsString(zoneStr)
        local list = markersByZone[zoneId]
        local zoneList = ElmsMarkers.savedVars.positions[zoneId]

        if type(zoneList) == "table" and type(list) == "table" then
            self:RemoveMarkerListFromZone(zoneId, zoneList, list)
        end
    end

    ElmsMarkers.CheckActivation()
end


function FrankGrinder:ElmsRemoveMarkersForZone(zoneId)
    if not (ElmsMarkers and ElmsMarkers.savedVars and ElmsMarkers.savedVars.positions) then
        self:DebugMsg("ElmsRemoveMarkersForZone: ElmsMarkers not found, cannot remove markers.")
        return
    end

    local zoneStr = self.elms.elmsData[zoneId]
    if not zoneStr then return end

    local markersByZone = ParseElmsString(zoneStr)
    local list = markersByZone[zoneId]
    local zoneList = ElmsMarkers.savedVars.positions[zoneId]

    if type(zoneList) ~= "table" or type(list) ~= "table" then return end

    self:DebugMsg("ElmsRemoveMarkersForZone: Removing markers for zone " .. tostring(zoneId))
    self:RemoveMarkerListFromZone(zoneId, zoneList, list)
    ElmsMarkers.CheckActivation()
end

------------------------------------------------------------
-- Zone Change Watcher
------------------------------------------------------------
function FrankGrinder:OnElmsZoneChanged()
    --*string* _zoneName_, *string* _subZoneName_, *bool* _newSubzone_, *integer* _zoneId_, *integer* _subZoneId_
    self:DebugMsg("OnElmsZoneChanged called.")
    if not self:GetSettingEnableElmsInjection() then return end
    if not ElmsMarkers or not ElmsMarkers.savedVars then return end

    local zoneId = GetZoneId(GetUnitZoneIndex("player")) 
    self:DebugMsg("OnElmsZoneChanged: ZoneId = " .. tostring(zoneId))

    -- Remove from previous zone
    if self.lastElmsZoneId and self.lastElmsZoneId ~= zoneId then
        self:DebugMsg("OnElmsZoneChanged: Removing markers for all zones : previous zone " .. tostring(self.lastElmsZoneId))
        self:ElmsRemoveMarkers()

    end

    if self.lastElmsZoneId == nil or (self.lastElmsZoneId and self.lastElmsZoneId ~= zoneId) then
        self:DebugMsg("OnElmsZoneChanged: Injecting markers for current zone " .. tostring(zoneId))
        -- Inject for current zone (if we have data)
        self:ElmsRemoveMarkers()
        self:ElmsApplyMarkersForZone(zoneId)
    end

    self:DebugMsg("OnElmsZoneChanged: Updating lastElmsZoneId to " .. tostring(zoneId))
    self.lastElmsZoneId = zoneId
end

local AZ_HIDE_REASON = "FrankGrinderUserSetting"

function FrankGrinder:ApplyAdventureZoneHudTrackerSetting()
    local hide = self.SV and self.SV.options and self.SV.options.hideAdventureZoneHudTracker

    -- The base UI creates this fragment when the tracker initialises. 
    if ADVENTURE_ZONE_HUD_TRACKER_FRAGMENT then
        ADVENTURE_ZONE_HUD_TRACKER_FRAGMENT:SetHiddenForReason(AZ_HIDE_REASON, hide == true)
        return true
    end

    return false
end

function FrankGrinder:ApplyAdventureZoneHudTrackerSettingWithRetry()
    if self:ApplyAdventureZoneHudTrackerSetting() then return end

    -- Retry a few times until the fragment exists
    local tries = 0
    EVENT_MANAGER:RegisterForUpdate(self.name .. ".AZHudRetry", 1000, function()
        tries = tries + 1
        if self:ApplyAdventureZoneHudTrackerSetting() or tries >= 10 then
            EVENT_MANAGER:UnregisterForUpdate(self.name .. ".AZHudRetry")
        end
    end)
end

local function NM_GetLocalisedDistrictName(district)
    -- district is your NM_ARGENT.DISTRICTS entry
    if district and district.locationIndex then
        local name = GetAdventureZoneEventLocationName(district.locationIndex)
        if name and name ~= "" then
            return zo_strformat("<<t:1>>", name)
        end
    end
    -- fallback to your internal label if the API isn't available right now
    return district and district.label or "?"
end

local function NM_GetLocalisedQuestName(questId)
    local qn = GetQuestName(questId)
    if qn and qn ~= "" then
        return zo_strformat("<<t:1>>", qn)
    end
    return nil
end

local function BuildNightMarketQuestListDescription(self)
    local lines = {}

    -- Optional header
    lines[#lines + 1] = ""
    lines[#lines + 1] = "|t24:24:OdySupportIcons/icons/squares/squaretwo_blue.dds|t " .. GetString(GG_NM_MENU_BLUE_MARKERS)
    lines[#lines + 1] = ""
    lines[#lines + 1] = "|t24:24:OdySupportIcons/icons/squares/squaretwo_green.dds|t " .. GetString(GG_NM_MENU_GREEN_MARKERS)
    lines[#lines + 1] = ""
    lines[#lines + 1] = GetString(GG_NM_MENU_NOTE_ON_ELMS)
    lines[#lines + 1] = ""
    lines[#lines + 1] = GetString(GG_NM_MENU_QUEST_LIST_HDR)

    -- Use your canonical district order
    for _, dk in ipairs(self.NM_ARGENT.DISTRICT_ORDER) do
        local district = self.NM_ARGENT.DISTRICTS[dk]
        local districtName = NM_GetLocalisedDistrictName(district)

        lines[#lines + 1] = ""
        lines[#lines + 1] = districtName .. ":"

        local qids = NMZoneQuestIds[dk] or {}
        if #qids == 0 then
            lines[#lines + 1] = "  (no quest IDs configured)"
        else
            local id = ""
            for _, qid in ipairs(qids) do
                
                if id == "" then
                    id = "-"
                elseif id == "-" then
                    id = "1"
                else
                    local n = tonumber(id)
                    if n and n >= 1 and n <= 3 then
                        id = tostring(n + 1)
                    end
                end

                local questName = NM_GetLocalisedQuestName(qid)
                if questName then
                    lines[#lines + 1] = string.format("  %s   %s", id, questName)
                else
                    lines[#lines + 1] = string.format("  %s   <unknown quest %d>", id, qid)
                end
            end
        end
    end

    return table.concat(lines, "\n")
end
------------------------------------------------------------
-- 2. SETTINGS MENU OPTION
------------------------------------------------------------
function FrankGrinder:ElmsCreateSettingsMenu()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panel = {
        type = "panel",
        name = "|cFF0000Frank's |cFF5500Night Market Grinder|r",
        displayName = "|cFF0000Frank's |cFF5500Night Market Grinder|r",
        author = self.author,
        version = self.addonVersion,
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local elmsDescription = BuildNightMarketQuestListDescription(self)

    local options = {
        {
            type = "checkbox",
            name = GetString(GG_NM_MENU_HIDE_TRACKER),
            tooltip = GetString(GG_NM_MENU_HIDE_TRACKER_TT),
            getFunc = function() return self:GetSettingHideAdventureZoneHudTracker() end,
            setFunc = function(v) self:SetSettingHideAdventureZoneHudTracker(v) end,
            default = false,
        },
        {
            type = "checkbox",
            name = GetString(GG_NM_MENU_ELMS_ENABLE),
            tooltip = GetString(GG_NM_MENU_ELMS_ENABLE_TT),
            getFunc = function() return self:GetSettingEnableElmsInjection() end,
            setFunc = function(value)
                self:SetSettingEnableElmsInjection(value)

                if self:GetSettingEnableElmsInjection() then
                    self:ElmsInstall()
                else
                    self:ElmsUninstall()
                end
            end,
            width = "full",
        },
        {
            type = "description",
            title = GetString(GG_NM_MENU_ELMS_GUIDANCE_HEADER),
            text = elmsDescription,
            width = "full",
        },
    }

    LAM:RegisterAddonPanel("FrankGrinder_ElmsInjectionPanel", panel)
    LAM:RegisterOptionControls("FrankGrinder_ElmsInjectionPanel", options)
end

------------------------------------------------------------
-- INSTALL: Remove all old markers, then add new markers
------------------------------------------------------------
function FrankGrinder:ElmsInstall()
    if not self:GetSettingEnableElmsInjection() then return end

    self:DebugMsg("ElmsInstall: Elms injection enabled.")

    -- These are torn down by ElmsUninstall, so they have to be registered
    -- here rather than once at load, or toggling the setting off and back on
    -- would leave the watcher dead until a reload.
    EVENT_MANAGER:RegisterForEvent("FrankGrinder_ElmsZoneChanged", EVENT_ZONE_CHANGED,
        function()
            self:DebugMsg("EVENT_ZONE_CHANGED fired")
            self:OnElmsZoneChanged()
        end
    )

    EVENT_MANAGER:RegisterForEvent("FrankGrinder_ElmsPlayerActivated", EVENT_PLAYER_ACTIVATED,
        function()
            self:DebugMsg("EVENT_PLAYER_ACTIVATED fired")
            self:OnElmsZoneChanged()
        end
    )

    EVENT_MANAGER:RegisterForEvent("FrankGrinder_LogoutCleanup", EVENT_LOGOUT_DEFERRED,
        function()
            self:DebugMsg("EVENT_LOGOUT_DEFERRED fired")
            self:ElmsUninstall()
        end
    )

    self:OnElmsZoneChanged()
end

------------------------------------------------------------
-- UNINSTALL: Remove all new markers only
------------------------------------------------------------
function FrankGrinder:ElmsUninstall()
    self:DebugMsg("ElmsUninstall: Removing markers from all zones")
    self:ElmsRemoveMarkers()
    self.lastElmsZoneId = nil

    EVENT_MANAGER:UnregisterForEvent("FrankGrinder_LogoutCleanup", EVENT_LOGOUT_DEFERRED)
    EVENT_MANAGER:UnregisterForEvent("FrankGrinder_ElmsZoneChanged", EVENT_ZONE_CHANGED)
    EVENT_MANAGER:UnregisterForEvent("FrankGrinder_ElmsPlayerActivated", EVENT_PLAYER_ACTIVATED)
end

-- ------------------------------------------------------------
-- UI Mouse Mode helpers for NM config window
-- ------------------------------------------------------------
function FrankGrinder:NM_PushUIMouseMode()
  -- Store prior state so we only restore if we changed it
  local was = false
  if IsGameCameraUIModeActive then
    was = (IsGameCameraUIModeActive() == true)
  end
  self._nmCfgPrevUIMode = was

  -- Turn on cursor mode for mouse interaction
  if SetGameCameraUIMode then
    SetGameCameraUIMode(true)
  end
end

function FrankGrinder:NM_PopUIMouseMode()
  -- Only restore if we previously captured a state
  if self._nmCfgPrevUIMode == nil then return end

  -- If the game was NOT in UI mode before we opened, turn it back off
  if self._nmCfgPrevUIMode == false then
    if SetGameCameraUIMode then
      SetGameCameraUIMode(false)
    end
  end

  self._nmCfgPrevUIMode = nil
end

-- ------------------------------------------------------------
-- NM Keyfarm Config Window (keybind pre-start UI)
-- ------------------------------------------------------------
function FrankGrinder:NM_CreateKeyFarmConfigWindowIfNeeded()
  if self._nmCfgUI and self._nmCfgUI.win then return end

-- Filled role icons used by Group Finder shared code (keyboard UI uses these filled/no-glow variants)
  local ROLE_ICON_FILLED = {
    [LFG_ROLE_TANK] = "EsoUI/Art/LFG/LFG_tank_down_no_glow_64.dds",
    [LFG_ROLE_HEAL] = "EsoUI/Art/LFG/LFG_healer_down_no_glow_64.dds",
    [LFG_ROLE_DPS]  = "EsoUI/Art/LFG/LFG_dps_down_no_glow_64.dds",
  } 

  -- Keyboard Group Finder spinner textures (exact assets used by the RoleSpinner template)
  local TEX_MINUS_UP       = "EsoUI/Art/Buttons/pointsMinus_up.dds"
  local TEX_MINUS_DOWN     = "EsoUI/Art/Buttons/pointsMinus_down.dds"
  local TEX_MINUS_OVER     = "EsoUI/Art/Buttons/pointsMinus_over.dds"
  local TEX_MINUS_DISABLED = "EsoUI/Art/Buttons/pointsMinus_disabled.dds"

  local TEX_PLUS_UP        = "EsoUI/Art/Buttons/pointsPlus_up.dds"
  local TEX_PLUS_DOWN      = "EsoUI/Art/Buttons/pointsPlus_down.dds"
  local TEX_PLUS_OVER      = "EsoUI/Art/Buttons/pointsPlus_over.dds"
  local TEX_PLUS_DISABLED  = "EsoUI/Art/Buttons/pointsPlus_disabled.dds" 


  local wm = WINDOW_MANAGER
  local win = wm:CreateTopLevelWindow("FrankGrinder_nmAutomationConfig")
  win:SetDimensions(420, 385)
  win:SetMovable(true)
  win:SetMouseEnabled(true)
  win:SetHidden(true)
    win:SetHandler("OnHide", function()
      if FrankGrinder and FrankGrinder.NM_PopUIMouseMode then
        FrankGrinder:NM_PopUIMouseMode()
      end
    end)
  win:SetClampedToScreen(true)
  win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)

  local bg = wm:CreateControl(nil, win, CT_BACKDROP)
  bg:SetAnchorFill()
  bg:SetCenterColor(0, 0, 0, 0.75)
  bg:SetEdgeColor(1, 1, 1, 0.8)

  local title = wm:CreateControl(nil, win, CT_LABEL)
  title:SetAnchor(TOP, win, TOP, 0, 12)
  title:SetFont("ZoFontWinH2")
  title:SetText("|cFF0000Frank's |cFF5500Night Market Grinder|r")

  -- Sub-heading
  local subTitle = wm:CreateControl(nil, win, CT_LABEL)
  subTitle:SetAnchor(TOP, title, BOTTOM, 0, 6)
  subTitle:SetFont("ZoFontWinH3")
  subTitle:SetColor(0.85, 0.85, 0.85, 1) -- slightly softer than the main title
  subTitle:SetText("Group Finder Automation")

  -- Helper: editbox
  local function makeEdit(name, parent, width, anchorPoint, rel, relPoint, x, y)
    local bd = wm:CreateControlFromVirtual(name .. "_BD", parent, "ZO_EditBackdrop")
    bd:SetDimensions(width, 26)
    bd:SetAnchor(anchorPoint, rel, relPoint, x, y)
    local eb = wm:CreateControlFromVirtual(name .. "_Edit", bd, "ZO_DefaultEditForBackdrop")
    eb:SetFont("ZoFontWinH4")
    eb:SetAllowMarkupType(ALLOW_MARKUP_TYPE_NONE)
    eb:SetMaxInputChars(50)
    return eb, bd
  end

  -- Mode dropdown label
  local modeLbl = wm:CreateControl(nil, win, CT_LABEL)
  modeLbl:SetAnchor(TOPLEFT, win, TOPLEFT, 20, 85)
  modeLbl:SetFont("ZoFontWinH4")
  modeLbl:SetText("Activity")

  -- Mode dropdown
  local dd = wm:CreateControlFromVirtual("FrankGrinder_nmAutomationConfig_Mode", win, "ZO_ComboBox")
  dd:SetAnchor(TOPLEFT, win, TOPLEFT, 160, 80)
  dd:SetDimensions(220, 26)
  local combo = ZO_ComboBox_ObjectFromContainer(dd)
  combo:ClearItems()

  local prefixLbl = wm:CreateControl(nil, win, CT_LABEL)
  prefixLbl:SetAnchor(TOPLEFT, win, TOPLEFT, 20, 122)
  prefixLbl:SetFont("ZoFontWinH4")
  prefixLbl:SetText("Title Prefix")

  local prefixEdit = makeEdit("FrankGrinder_nmAutomationConfig_Prefix", win, 220, TOPLEFT, win, TOPLEFT, 160, 118)
  prefixEdit:SetMaxInputChars(20)

  local cpLbl = wm:CreateControl(nil, win, CT_LABEL)
  cpLbl:SetAnchor(TOPLEFT, win, TOPLEFT, 20, 159)
  cpLbl:SetFont("ZoFontWinH4")
  cpLbl:SetText("CP Requirement")

  local cpEdit = makeEdit("FrankGrinder_nmAutomationConfig_CP", win, 220, TOPLEFT, win, TOPLEFT, 160, 155)
  cpEdit:SetMaxInputChars(4)

    -- Kick offline players checkbox
      local kickOfflineCb = wm:CreateControlFromVirtual("FrankGrinder_nmAutomationConfig_KickOffline", win, "ZO_CheckButton")
      kickOfflineCb:SetAnchor(TOPLEFT, win, TOPLEFT, 20, 196)
      ZO_CheckButton_SetLabelText(kickOfflineCb, "Kick offline players") 
      ZO_CheckButton_SetCheckState(kickOfflineCb, (self:NM_GetKeyFarmConfig().kickOffline == true))

      -- Persist immediately when toggled
    ZO_CheckButton_SetToggleFunction(kickOfflineCb, function(checked)
      
        local enabled = (checked == true)
        local c = self:NM_GetKeyFarmConfig()
        c.kickOffline = enabled -- persist to SavedVars

    end)

      kickOfflineCb:SetHandler("OnClicked", function(btn)
        ZO_CheckButton_OnClicked(btn)
      end)

  -- Role row helper
local function makeRoleRow(y, roleType)
    local row = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    row:SetDimensions(380, 34)
    row:SetAnchor(TOPLEFT, win, TOPLEFT, 20, y)

    -- Icon (filled/no-glow)
    local icon = WINDOW_MANAGER:CreateControl(nil, row, CT_TEXTURE)
    icon:SetDimensions(28, 28)
    icon:SetAnchor(LEFT, row, LEFT, 0, 0)
    icon:SetTexture(ROLE_ICON_FILLED[roleType]) 

    -- Text label (Tank/Healer/Damage)
    local text = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
    text:SetAnchor(LEFT, icon, RIGHT, 10, 0)
    text:SetDimensions(130, 28)
    text:SetFont("ZoFontGameBold")
    text:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    -- Base UI uses the LFG role strings (same source as gamepad roles bar uses)
    text:SetText(GetString("SI_LFGROLE", roleType))

    -- Minus button (pointsMinus_* set)
    local minus = WINDOW_MANAGER:CreateControl(nil, row, CT_BUTTON)
    minus:SetDimensions(32, 32)
    minus:SetAnchor(LEFT, text, RIGHT, 10, 0)
    minus:SetNormalTexture(TEX_MINUS_UP)
    minus:SetPressedTexture(TEX_MINUS_DOWN)
    minus:SetMouseOverTexture(TEX_MINUS_OVER)
    minus:SetDisabledTexture(TEX_MINUS_DISABLED) 

    -- Value label
    local val = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
    val:SetAnchor(LEFT, minus, RIGHT, 2, 0)
    val:SetDimensions(44, 32)
    val:SetFont("ZoFontWinH2")
    val:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    val:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    val:SetText("0")

    -- Plus button (pointsPlus_* set)
    local plus = WINDOW_MANAGER:CreateControl(nil, row, CT_BUTTON)
    plus:SetDimensions(32, 32)
    plus:SetAnchor(LEFT, val, RIGHT, 2, 0)
    plus:SetNormalTexture(TEX_PLUS_UP)
    plus:SetPressedTexture(TEX_PLUS_DOWN)
    plus:SetMouseOverTexture(TEX_PLUS_OVER)
    plus:SetDisabledTexture(TEX_PLUS_DISABLED) 

    return minus, plus, val, icon, text, row
  end


  local tankMinus, tankPlus, tankVal = makeRoleRow(220, LFG_ROLE_TANK)
  local healMinus, healPlus, healVal = makeRoleRow(255, LFG_ROLE_HEAL)
  local dpsMinus,  dpsPlus,  dpsVal  = makeRoleRow(290, LFG_ROLE_DPS)


  -- Buttons
  local startBtn = wm:CreateControlFromVirtual(nil, win, "ZO_DefaultButton")
  startBtn:SetDimensions(120, 30)
  startBtn:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 20, -15)
  startBtn:SetText("Start")

  local closeBtn = wm:CreateControlFromVirtual(nil, win, "ZO_DefaultButton")
  closeBtn:SetDimensions(120, 30)
  closeBtn:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -20, -15)
  closeBtn:SetText("Close")

  -- State + helpers
    self._nmCfgUI = {
      win = win,
      combo = combo,
      dd = dd,
      prefixEdit = prefixEdit,
      cpEdit = cpEdit,
      kickOfflineCb = kickOfflineCb,
      tankVal = tankVal,
      healVal = healVal,
      dpsVal = dpsVal,
    }


  local function refreshFromConfig()
    local c = self:NM_GetKeyFarmConfig()
    self:NM_ClampRolesToSize(c)

    -- Dropdown selection text
    local modeName =
      (c.mode == NM_MODE_DUNGEON and "Dungeon Keyfarm")
      or (c.mode == NM_MODE_ADVENTURE and "Adventuring")
      or "Argent Keyfarm"

    -- ignoreCallback = true: without it SetSelectedItem fires the item's
    -- callback (setMode), which calls back into refreshFromConfig forever.
    combo:SetSelectedItem(modeName, true)

    prefixEdit:SetText(tostring(c.titlePrefix or ""))
    cpEdit:SetText(tostring(c.cp or ""))
    
    tankVal:SetText(tostring(c.tank))
    healVal:SetText(tostring(c.heal))
    dpsVal:SetText(tostring(c.dps))
  end

    local function setMode(mode)
      local c = self:NM_GetKeyFarmConfig()


        local keepPrefix = tostring(c.titlePrefix or "")
        self:NM_ApplyModeDefaults(mode)
        local c2 = self:NM_GetKeyFarmConfig()
        c2.titlePrefix = keepPrefix
        refreshFromConfig()

    end

  -- Dropdown items
  local function addModeItem(label, modeToken)
    local entry = combo:CreateItemEntry(label, function()
      setMode(modeToken)
    end)
    combo:AddItem(entry)
  end
  addModeItem("Dungeon Keyfarm", NM_MODE_DUNGEON)
  addModeItem("Argent Keyfarm",  NM_MODE_ARGENT)
  addModeItem("Adventuring",     NM_MODE_ADVENTURE)

  -- Role buttons behaviour
  local function adjustRole(which, delta)
    local c = self:NM_GetKeyFarmConfig()
    if which == "tank" then c.tank = (tonumber(c.tank) or 0) + delta end
    if which == "heal" then c.heal = (tonumber(c.heal) or 0) + delta end
    if which == "dps"  then
      -- For DPS we adjust and then clamp by converting to remainder:
      -- interpret requested DPS and clamp others if needed.
      c.dps = (tonumber(c.dps) or 0) + delta
      -- Convert to remainder model: keep tank/heal, clamp dps to remainder
      local total = NM_GetTargetSizeForMode(c.mode)
      if c.dps < 0 then c.dps = 0 end
      if c.dps > total then c.dps = total end
      -- If DPS is set explicitly, keep it and clamp heal down then tank down if needed
      local maxOthers = total - c.dps
      if c.heal > maxOthers then c.heal = maxOthers end
      if c.tank > (maxOthers - c.heal) then c.tank = maxOthers - c.heal end
    end
    self:NM_ClampRolesToSize(c)
    refreshFromConfig()
  end

  tankMinus:SetHandler("OnClicked", function() adjustRole("tank", -1) end)
  tankPlus:SetHandler("OnClicked",  function() adjustRole("tank",  1) end)
  healMinus:SetHandler("OnClicked", function() adjustRole("heal", -1) end)
  healPlus:SetHandler("OnClicked",  function() adjustRole("heal",  1) end)
  dpsMinus:SetHandler("OnClicked",  function() adjustRole("dps",  -1) end)
  dpsPlus:SetHandler("OnClicked",   function() adjustRole("dps",   1) end)

  -- Edit handlers (prefix + CP)
  prefixEdit:SetHandler("OnFocusLost", function()
    local c = self:NM_GetKeyFarmConfig()
    c.titlePrefix = tostring(prefixEdit:GetText() or "")
  end)

  cpEdit:SetHandler("OnFocusLost", function()
    local c = self:NM_GetKeyFarmConfig()
    local n = tonumber(cpEdit:GetText() or "")
    if not n then
      -- revert to current
      refreshFromConfig()
      return
    end
    c.cp = n
    self:NM_ClampRolesToSize(c)
    refreshFromConfig()
  end)

  -- Buttons
  closeBtn:SetHandler("OnClicked", function()
    win:SetHidden(true)
  end)

  startBtn:SetHandler("OnClicked", function()
    -- Persist current text fields before starting
    local c = self:NM_GetKeyFarmConfig()
    c.titlePrefix = tostring(prefixEdit:GetText() or "")
    local n = tonumber(cpEdit:GetText() or "")
    if n then c.cp = n end
    self:NM_ClampRolesToSize(c)

    win:SetHidden(true)
    self:ToggleNMKeyFarmAutomation(true)
  end)

  refreshFromConfig()
end

function FrankGrinder:NM_ShowKeyFarmConfigWindow()
  self:NM_CreateKeyFarmConfigWindowIfNeeded()
  if self._nmCfgUI and self._nmCfgUI.win then
    self:NM_GetKeyFarmConfig() -- ensure defaults exist
    self:NM_PushUIMouseMode()
    self._nmCfgUI.win:SetHidden(false)
  end
end

------------------------------------------------------------
-- INITIALIZE (called from main addon)
------------------------------------------------------------
function FrankGrinder:InitializeNightMarket()
    self:ElmsCreateSettingsMenu()

    self:ApplyAdventureZoneHudTrackerSettingWithRetry()

    -- Sweep any markers left behind by a crash or a hard exit while injection
    -- was on. Runs even when the setting is off, because that is exactly the
    -- case where nothing else would ever clean them up.
    self:ElmsRemoveMarkers()

    self:ElmsInstall()
end
