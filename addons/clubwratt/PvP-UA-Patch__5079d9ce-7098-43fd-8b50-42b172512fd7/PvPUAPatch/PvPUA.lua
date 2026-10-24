PvPUAPatch = PvPUAPatch or {} -- build.sh: private global, coexists with the unpatched PvPUA
local PvPUA = PvPUAPatch
PvPUA.name = "PvPUAPatch" -- build.sh: must match the addon folder (EVENT_ADD_ON_LOADED)
PvPUA.version = "5.6.1" -- Patch: build.sh writes VERSION here; only used in the debug log

--------------------------------------------------
-- Config
--------------------------------------------------
PvPUA.config = {}
PvPUA.config.isClampedToScreen = true
PvPUA.config.imageWidth = 30
PvPUA.config.nameWidth = 165
PvPUA.config.flagWidth = 40
PvPUA.config.flagHeight = 8
PvPUA.config.flagFlipWidth = 40
PvPUA.config.underAttackForWidth = 50
PvPUA.config.killsWidth = 75
PvPUA.config.width = 430
PvPUA.config.siegeWidth = 30
PvPUA.config.entryHeight = 32

--------------------------------------------------
-- ICON SIZES
--------------------------------------------------
PvPUA.config.iconScale = {
    scrollCarrier = 1.65,
    scrollOnKeep  = 1.25,
    volendrung    = 1.0,
    rank          = 1.25,
    emperor       = 0.90,
    allianceScore = 1.0,
}

PvPUA.config.barHeight = 18

PvPUA.config.barFontSize = 0

PvPUA.config.barTextNudge = 2

--------------------------------------------------
-- K: / D: readout
--------------------------------------------------
PvPUA.config.kdGap       = "  "
PvPUA.config.kdRightPad  = 4
PvPUA.config.kdTextNudge = 2
PvPUA.config.kdFontSize  = 20


PvPUA.config.volendrungTintToHud = true
PvPUA.config.height = PvPUA.config.entryHeight * 10
PvPUA.config.backdropAlphaOdd = 0.25
PvPUA.config.backdropAlphaEven = 0.15
PvPUA.config.flagBackdropColor = { r = 0.1, g = 0.1, b = 0.1 }
PvPUA.config.iconOutline = false

--------------------------------------------------
-- Constants
--------------------------------------------------
PvPUA.constants = {}
PvPUA.constants.updateInterval = 1000
-- How long an item stays on the list after the last activity (UA! flag dropped, last siege weapon
-- gone, last kill-marker change). Upstream value; briefly 60000 in 5.3.0, reverted in 5.3.1.
PvPUA.constants.siegeTimeout = 5000
-- Kill tally (see "Kill Tally" section). Normalized map units on the Cyrodiil/IC zone map.
PvPUA.constants.killAttachRadius = 0.04   -- a kill marker belongs to the nearest tracked location within this
PvPUA.constants.killMatchRadius  = 0.008  -- two snapshots this close apart are the same marker
-- Kill feed (see "Kill Feed" under Kill Tally). A chat-reported kill waits this long for the kill
-- marker that will eventually carry it; a marker delta this recent is assumed to already hold a
-- chat kill that arrives just after it; the same killer/victim pair from both sources within the
-- dedupe window is one kill (the game's own chat handler uses the same 10 s rule).
PvPUA.constants.chatKillReconcileMs  = 60000
PvPUA.constants.chatKillMarkerLeadMs = 3000
PvPUA.constants.chatKillDedupeMs     = 10000
PvPUA.constants.resourceType = { FARM = 1, MINE = 2, LUMBER = 3 }
PvPUA.constants.flipTimes = { KEEP = 20000, OUTPOST = 20000, RESOURCE = 20000 }

PvPUA.constants.textures = {}
PvPUA.constants.textures.KEEP = "/esoui/art/mappins/ava_largekeep_neutral.dds"
PvPUA.constants.textures.OUTPOST = "/esoui/art/mappins/ava_outpost_neutral.dds"
PvPUA.constants.textures.VILLAGE = "/esoui/art/mappins/ava_town_neutral.dds"
PvPUA.constants.textures.RESOURCE_MINE = "/esoui/art/compass/ava_mine_neutral.dds"
PvPUA.constants.textures.RESOURCE_FARM = "/esoui/art/compass/ava_farm_neutral.dds"
PvPUA.constants.textures.RESOURCE_LUMBER = "/esoui/art/compass/ava_lumbermill_neutral.dds"
PvPUA.constants.textures.BRIDGE_PASSABLE = "/esoui/art/mappins/ava_bridge_passable.dds"
PvPUA.constants.textures.BRIDGE_NOT_PASSABLE = "/esoui/art/mappins/ava_bridge_not_passable.dds"
PvPUA.constants.textures.MILEGATE_PASSABLE = "/esoui/art/mappins/ava_milegate_passable.dds"
PvPUA.constants.textures.MILEGATE_NOT_PASSABLE = "/esoui/art/mappins/ava_milegate_not_passable.dds"
PvPUA.constants.textures.DISTRICT = "/esoui/art/mappins/ava_imperialdistrict_neutral.dds"

PvPUA.constants.emperorKeeps = {
    { name = "Aleswell",  col = 0, row = 0 },
    { name = "Chalman",   col = 1, row = 0 },
    { name = "Ash",       col = 0, row = 1 },
    { name = "Blue Road", col = 1, row = 1 },
    { name = "Roebeck",   col = 0, row = 2 },
    { name = "Alessia",   col = 1, row = 2 },
}

PvPUA.constants.userIcons = {
    ["@user562"]         = { texture = "PvPUAPatch/Textures/icon_panda.dds" },
    ["@sir gilson7"]     = { texture = "PvPUAPatch/Textures/icon_werewolf.dds", heightOffset = 1.0 },
    ["@get em nala"]     = { texture = "PvPUAPatch/Textures/icon_hedgehog.dds" },
    ["@suzyqboston3383"] = { texture = "PvPUAPatch/Textures/icon_trinity.dds", heightOffset = 1.0 },
    ["@suzibrew"]        = { texture = "PvPUAPatch/Textures/icon_elephant.dds" },
    ["@maddogmcree6157"] = { texture = "PvPUAPatch/Textures/icon_devildog.dds" },
    ["@sgt bear78fh"]    = { texture = "PvPUAPatch/Textures/icon_bear.dds", heightOffset = 1.0 },
    ["@rolo tsg"]        = { texture = "PvPUAPatch/Textures/icon_wizard.dds" },
    ["@bella nekro"]     = { texture = "PvPUAPatch/Textures/icon_bellamask.dds" },
}

PvPUA.constants.ICON_NONE    = 1
PvPUA.constants.ICON_DEFAULT = 2

PvPUA.constants.iconCategories = {
    { id = "other",     name = "Other" },
    { id = "alliances", name = "Alliances" },
    { id = "symbols",   name = "Symbols" },
    { id = "memes",     name = "Memes" },
}

PvPUA.constants.iconChoices = {
    { name = "None",       category = "other",     texture = "EsoUI/Art/Buttons/decline_up.dds", none = true },
    { name = "Default",    category = "other",     isDefault = true },
    { name = "Kiss",       category = "memes",     texture = "PvPUAPatch/Textures/icon_kiss.dds" },
    { name = "Troll Blob", category = "memes",     texture = "PvPUAPatch/Textures/icon_trollblob.dds" },
    { name = "Trollface",  category = "memes",     texture = "PvPUAPatch/Textures/icon_trollface.dds" },
    { name = "Butterfly",  category = "other",     texture = "PvPUAPatch/Textures/icon_butterfly.dds" },
    { name = "Hi",         category = "other",     texture = "PvPUAPatch/Textures/icon_hi.dds" },
    { name = "Crown",      category = "symbols",   texture = "PvPUAPatch/Textures/icon_crown.dds" },
    { name = "Arrow",      category = "symbols",   texture = "PvPUAPatch/Textures/icon_arrow.dds" },
    { name = "DC Banner",  category = "alliances", texture = "PvPUAPatch/Textures/icon_dc_banner.dds" },
    { name = "DC Shield",  category = "alliances", texture = "PvPUAPatch/Textures/icon_dc_shield.dds" },
    { name = "AD Banner",  category = "alliances", texture = "PvPUAPatch/Textures/icon_ad_banner.dds" },
    { name = "AD Shield",  category = "alliances", texture = "PvPUAPatch/Textures/icon_ad_shield.dds" },
    { name = "EP Banner",  category = "alliances", texture = "PvPUAPatch/Textures/icon_ep_banner.dds" },
    { name = "EP Shield",  category = "alliances", texture = "PvPUAPatch/Textures/icon_ep_shield.dds" },
}

PvPUA.defaults = { posX = 100, posY = 450, timerColor = { r = 1, g = 1, b = 1, a = 1 }, enableAPChat = true, consolidateAPChat = false, consolidateRepairDelay = 5, consolidateCombatDelay = 10, alertsEnabled = false, alertLifespan = 10, font = "EsoUI/Common/Fonts/FTN57.otf", backdropStyle = "Alliance", backdropColor = { r = 0, g = 0, b = 0, a = 1 }, backdropOpacity = 25, settingsFontSize = 30, settingsOpacity = 100, settingsHighlight = "Alliance", settingsHighlightColor = { r = 1, g = 1, b = 1, a = 1 }, settingsRemember = true, listSize = "Default", uiScale = 1.0, barMode = "AP", showMilegates = true, showBridges = true, showTowns = true, showResources = true, showScrollCarriers = true, showVolendrungRow = true, showCredit = false --[[ patch: upstream default is true ]], showListInMenus = false, showListWhileSieging = false, showListWhileDead = true, showListDeadRepair = false, listCap = 0, showKillTally = true, debugLog = false --[[ patch: LibConsoleLogger diagnostics ]] }

PvPUA.capChoices = {
    { name = "All", value = 0  },
    { name = "5",   value = 5  },
    { name = "10",  value = 10 },
    { name = "15",  value = 15 },
    { name = "30",  value = 30 },
}

PvPUA.charDefaults = { aiKeyword = "", aiEnabled = false, aiWhisper = true, aiSay = false, aiZone = false, aiGuild = false, aiGuildName = "", aiGuildToggles = {}, aiGuildMigrated = false, aiGuildMigrationRepair = false, aiKickOffline = false, aiKickMinutes = 5, aiPvP = true, aiPvE = true, iconShowSelf = true, iconShowOthers = true, iconShowSmallGroupFrames = false, iconShowLargeGroupFrames = false }

local ICON_CHARACTER_KEYS = { "iconChoice", "iconShowSelf", "iconShowOthers", "iconShowSmallGroupFrames", "iconShowLargeGroupFrames" }

PvPUA.state = {}
PvPUA.state.visibleControls = {}
PvPUA.state.resources = {}
PvPUA.state.keeps = {}
PvPUA.state.outposts = {}
PvPUA.state.villages = {}
PvPUA.state.destructibles = {}
PvPUA.state.districts = {}

PvPUA.controls = {}
PvPUA.savedVariables = nil
PvPUA.cachedFont = nil
PvPUA.volendrung = nil
PvPUA.initializedItems = false
PvPUA.registeredCyroEvents = false
PvPUA.creditCycle = 0

PvPUA.session = { killingBlows = 0, deaths = 0 }

-- Kill tally working state: last kill-marker snapshot + cached location positions (per map id).
PvPUA.killTally = { snapshot = {}, positions = nil, positionsMapId = nil }

--------------------------------------------------
-- Alliance Hex
--------------------------------------------------
local DC_HEX = GetAllianceColor(ALLIANCE_DAGGERFALL_COVENANT):ToHex()
local AD_HEX = GetAllianceColor(ALLIANCE_ALDMERI_DOMINION):ToHex()
local EP_HEX = GetAllianceColor(ALLIANCE_EBONHEART_PACT):ToHex()

local CREDIT_STATES = {}
local ALLIANCE_STR  = "Alliance!"
local CYCLE_COLORS  = { DC_HEX, AD_HEX, EP_HEX }
local totalSteps    = #ALLIANCE_STR * #CYCLE_COLORS
for step = 0, totalSteps - 1 do
    local colorIndex  = math.floor(step / #ALLIANCE_STR) + 1
    local letterIndex = (step % #ALLIANCE_STR) + 1
    local animated    = ""
    for i = 1, #ALLIANCE_STR do
        local ch = ALLIANCE_STR:sub(i, i)
        if i <= letterIndex then
            animated = animated .. "|c" .. CYCLE_COLORS[colorIndex] .. ch .. "|r"
        else
            local prevColor = colorIndex > 1 and CYCLE_COLORS[colorIndex - 1] or CYCLE_COLORS[#CYCLE_COLORS]
            animated = animated .. "|c" .. prevColor .. ch .. "|r"
        end
    end
    CREDIT_STATES[step] = "|c" .. DC_HEX .. "DC|r, |c00FF00the BEST|r " .. animated .. " - |c00FF00user562|r"
end

--------------------------------------------------
-- Combat Tracking Locals
--------------------------------------------------
local pvpIsCombatRegistered = false

local VOLENDRUNG_DESPAWN_GRACE = 10000

local wm = WINDOW_MANAGER

--------------------------------------------------
-- Player Icon System
--------------------------------------------------
PvPUA.playerIcon = {}
local PI = PvPUA.playerIcon

--------------------------------------------------
-- Timer Colors
--------------------------------------------------
local function GetTimerColor()
    local c = PvPUA.savedVariables and PvPUA.savedVariables.timerColor
    if type(c) == "table" then
        return c.r or 1, c.g or 1, c.b or 1
    end
    return 1, 1, 1
end

function PvPUA:GetFont()
    if not self.cachedFont then
        local path = self.savedVariables and self.savedVariables.font or "EsoUI/Common/Fonts/FTN47.otf"
        local size = "25"
        self.cachedFont = path .. "|" .. size .. "|outline"
    end
    return self.cachedFont
end

function PvPUA:InvalidateFontCache()
    self.cachedFont = nil
end

--------------------------------------------------
-- Alliance Colors
--------------------------------------------------
local function GetColorForAlliance(alliance)
    return GetAllianceColor(alliance)
end

local function ToHex(r, g, b)
    return string.format("%02X%02X%02X", math.floor(r*255), math.floor(g*255), math.floor(b*255))
end

local function ColorText(text, r, g, b)
    return "|c" .. ToHex(r, g, b) .. text .. "|r"
end

local rainbowPalette = { "FF2222", "FF9900", "FFEE00", "33DD33", "00CCCC", "3399FF", "BB44EE" }
local function RainbowText(text)
    local out = {}
    local idx = 1
    for i = 1, #text do
        local ch = text:sub(i, i)
        if ch == " " then
            out[#out + 1] = ch
        else
            local color = rainbowPalette[((idx - 1) % #rainbowPalette) + 1]
            out[#out + 1] = "|c" .. color .. ch .. "|r"
            idx = idx + 1
        end
    end
    return table.concat(out)
end

local function GetGuildAllianceColor(guildId)
    if not guildId or guildId <= 0 then return GetAllianceColor(ALLIANCE_NONE) end
    local alliance = GetGuildAlliance(guildId)
    return GetColorForAlliance(alliance)
end

--------------------------------------------------
-- Volendrung Helpers
--------------------------------------------------
local function GetVolendrungTexture(pinType)
    if pinType and ZO_MapPin and ZO_MapPin.PIN_DATA and ZO_MapPin.PIN_DATA[pinType] then
        local tex = ZO_MapPin.PIN_DATA[pinType].texture
        if tex and type(tex) == "string" then return tex end
    end
    if pinType == MAP_PIN_TYPE_AVA_DAEDRIC_ARTIFACT_VOLENDRUNG_ALDMERI    then return "/esoui/art/mappins/ava_daedricartifact_volendrung_aldmeri.dds"    end
    if pinType == MAP_PIN_TYPE_AVA_DAEDRIC_ARTIFACT_VOLENDRUNG_DAGGERFALL  then return "/esoui/art/mappins/ava_daedricartifact_volendrung_daggerfall.dds"  end
    if pinType == MAP_PIN_TYPE_AVA_DAEDRIC_ARTIFACT_VOLENDRUNG_EBONHEART   then return "/esoui/art/mappins/ava_daedricartifact_volendrung_ebonheart.dds"   end
    return "/esoui/art/mappins/ava_daedricartifact_volendrung_neutral.dds"
end

local function GetVolendrungAlliance(pinType)
    if pinType == MAP_PIN_TYPE_AVA_DAEDRIC_ARTIFACT_VOLENDRUNG_ALDMERI    then return ALLIANCE_ALDMERI_DOMINION    end
    if pinType == MAP_PIN_TYPE_AVA_DAEDRIC_ARTIFACT_VOLENDRUNG_DAGGERFALL  then return ALLIANCE_DAGGERFALL_COVENANT  end
    if pinType == MAP_PIN_TYPE_AVA_DAEDRIC_ARTIFACT_VOLENDRUNG_EBONHEART   then return ALLIANCE_EBONHEART_PACT       end
    return 0
end

--------------------------------------------------
-- Zone Detection
--------------------------------------------------
local function IsInICCampaign()
    if not (GetCurrentCampaignId and IsImperialCityCampaign) then return false end
    local ok, result = pcall(function()
        local id = GetCurrentCampaignId()
        return id ~= 0 and IsImperialCityCampaign(id) == true
    end)
    return ok and result == true
end

local function IsInCyrodiilOrIC()
    if IsInICCampaign() == true then
        return true
    elseif IsInCyrodiil() == true then
        return true
    elseif IsInCyrodiil() == false and IsPlayerInAvAWorld() == true and IsInAvAZone() == true and IsInImperialCity() == false and IsActiveWorldBattleground() == false then
        return true
    else
        return false
    end
end

--------------------------------------------------
-- Name Helpers
--------------------------------------------------
local function AdjustDistrictName(name)
    if name == nil then return "" end
    name = name:gsub(" District", "")
    return name
end

local function AdjustResourceName(name)
    name = name:gsub("Castle ", ""):gsub("[fF]ort ", ""):gsub("Keep ", ""):gsub("[Ll]umbermill", "Lumber")
    return name
end

local function AdjustKeepName(name)
    name = name:gsub(",..$", ""):gsub("Castle ", ""):gsub("[fF]ort ", ""):gsub("Keep ", ""):gsub("Keep", "")
    return name
end

local function AdjustOutpostName(name)
    name = name:gsub("Outpost", "")
    return name
end

--------------------------------------------------
-- Init Functions
--------------------------------------------------
function PvPUA:InitResources(gameTime)
    local resources = { 22, 23, 24, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57,
                        61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87 }
    self.state.resources = {}
    for i = 1, #resources do
        local id = resources[i]
        self.state.resources[id] = {}
        self.state.resources[id].id = id
        self.state.resources[id].keepType = GetKeepType(id)
        self.state.resources[id].name = AdjustResourceName(zo_strformat("<<1>>", GetKeepName(id)))
        self.state.resources[id].isUnderAttack = GetKeepUnderAttack(id, BGQUERY_LOCAL)
        if self.state.resources[id].isUnderAttack == true then
            self.state.resources[id].interestingSince = gameTime
        else
            self.state.resources[id].interestingSince = nil
        end
        self.state.resources[id].attackStatusLostAt = 0
        self.state.resources[id].underAttackFor = 0
        self.state.resources[id].siegeWeapons = {}
        self.state.resources[id].siegeWeapons.AD = GetNumSieges(id, BGQUERY_LOCAL, ALLIANCE_ALDMERI_DOMINION)
        self.state.resources[id].siegeWeapons.DC = GetNumSieges(id, BGQUERY_LOCAL, ALLIANCE_DAGGERFALL_COVENANT)
        self.state.resources[id].siegeWeapons.EP = GetNumSieges(id, BGQUERY_LOCAL, ALLIANCE_EBONHEART_PACT)
        self.state.resources[id].owningAlliance = GetKeepAlliance(id, BGQUERY_LOCAL)
    end
end

function PvPUA:InitKeeps(gameTime)
    self.state.keeps = {}
    for i = 3, 20 do
        self.state.keeps[i] = {}
        self.state.keeps[i].id = i
        self.state.keeps[i].keepType = GetKeepType(i)
        self.state.keeps[i].name = AdjustKeepName(zo_strformat("<<1>>", GetKeepName(i)))
        self.state.keeps[i].isUnderAttack = GetKeepUnderAttack(i, BGQUERY_LOCAL)
        if self.state.keeps[i].isUnderAttack == true then
            self.state.keeps[i].interestingSince = gameTime
        else
            self.state.keeps[i].interestingSince = nil
        end
        self.state.keeps[i].attackStatusLostAt = 0
        self.state.keeps[i].underAttackFor = 0
        self.state.keeps[i].siegeWeapons = {}
        self.state.keeps[i].siegeWeapons.AD = GetNumSieges(i, BGQUERY_LOCAL, ALLIANCE_ALDMERI_DOMINION)
        self.state.keeps[i].siegeWeapons.DC = GetNumSieges(i, BGQUERY_LOCAL, ALLIANCE_DAGGERFALL_COVENANT)
        self.state.keeps[i].siegeWeapons.EP = GetNumSieges(i, BGQUERY_LOCAL, ALLIANCE_EBONHEART_PACT)
        self.state.keeps[i].owningAlliance = GetKeepAlliance(i, BGQUERY_LOCAL)
        self.state.keeps[i].resources = {}
        local farmId = GetResourceKeepForKeep(i, RESOURCETYPE_FOOD)
        local lumberId = GetResourceKeepForKeep(i, RESOURCETYPE_WOOD)
        local mineId = GetResourceKeepForKeep(i, RESOURCETYPE_ORE)
        if self.state.resources[farmId] then
            self.state.resources[farmId].rType = PvPUA.constants.resourceType.FARM
        end
        if self.state.resources[lumberId] then
            self.state.resources[lumberId].rType = PvPUA.constants.resourceType.LUMBER
        end
        if self.state.resources[mineId] then
            self.state.resources[mineId].rType = PvPUA.constants.resourceType.MINE
        end
    end
    local allianceHomeKeepNames = {
        [ALLIANCE_ALDMERI_DOMINION]    = { "Alessia", "Black Boot", "Bloodmayne", "Brindle", "Faregyl", "Roebeck" },
        [ALLIANCE_DAGGERFALL_COVENANT] = { "Aleswell", "Ash", "Dragonclaw", "Glademist", "Rayles", "Warden" },
        [ALLIANCE_EBONHEART_PACT]      = { "Arrius", "Blue Road", "Chalman", "Drakelowe", "Farragut", "Kingscrest" },
    }
    self.homeKeepIds = {}
    self.emperorKeepIds = {}
    for i = 3, 20 do
        local rawName = zo_strformat("<<1>>", GetKeepName(i))
        for alliance, names in pairs(allianceHomeKeepNames) do
            for _, hkName in ipairs(names) do
                if rawName:find(hkName) then
                    self.homeKeepIds[i] = alliance
                    break
                end
            end
        end
        for slot = 1, #PvPUA.constants.emperorKeeps do
            if self.emperorKeepIds[slot] == nil
               and rawName:find(PvPUA.constants.emperorKeeps[slot].name) then
                self.emperorKeepIds[slot] = i
                break
            end
        end
    end
end

function PvPUA:InitOutposts(gameTime)
    local outposts = { 132, 133, 134, 163, 164, 165 }
    self.state.outposts = {}
    for i = 1, #outposts do
        local id = outposts[i]
        self.state.outposts[id] = {}
        self.state.outposts[id].id = id
        self.state.outposts[id].keepType = GetKeepType(id)
        self.state.outposts[id].name = AdjustOutpostName(zo_strformat("<<1>>", GetKeepName(id)))
        self.state.outposts[id].isUnderAttack = GetKeepUnderAttack(id, BGQUERY_LOCAL)
        if self.state.outposts[id].isUnderAttack == true then
            self.state.outposts[id].interestingSince = gameTime
        else
            self.state.outposts[id].interestingSince = nil
        end
        self.state.outposts[id].attackStatusLostAt = 0
        self.state.outposts[id].underAttackFor = 0
        self.state.outposts[id].siegeWeapons = {}
        self.state.outposts[id].siegeWeapons.AD = GetNumSieges(id, BGQUERY_LOCAL, ALLIANCE_ALDMERI_DOMINION)
        self.state.outposts[id].siegeWeapons.DC = GetNumSieges(id, BGQUERY_LOCAL, ALLIANCE_DAGGERFALL_COVENANT)
        self.state.outposts[id].siegeWeapons.EP = GetNumSieges(id, BGQUERY_LOCAL, ALLIANCE_EBONHEART_PACT)
        self.state.outposts[id].owningAlliance = GetKeepAlliance(id, BGQUERY_LOCAL)
    end
end

function PvPUA:InitVillages(gameTime)
    local villages = { 149, 151, 152 }
    self.state.villages = {}
    for i = 1, #villages do
        local id = villages[i]
        self.state.villages[id] = {}
        self.state.villages[id].id = id
        self.state.villages[id].keepType = GetKeepType(id)
        self.state.villages[id].name = zo_strformat("<<1>>", GetKeepName(id))
        self.state.villages[id].isUnderAttack = GetKeepUnderAttack(id, BGQUERY_LOCAL)
        if self.state.villages[id].isUnderAttack == true then
            self.state.villages[id].interestingSince = gameTime
        else
            self.state.villages[id].interestingSince = nil
        end
        self.state.villages[id].attackStatusLostAt = 0
        self.state.villages[id].underAttackFor = 0
        self.state.villages[id].siegeWeapons = {}
        self.state.villages[id].siegeWeapons.AD = GetNumSieges(id, BGQUERY_LOCAL, ALLIANCE_ALDMERI_DOMINION)
        self.state.villages[id].siegeWeapons.DC = GetNumSieges(id, BGQUERY_LOCAL, ALLIANCE_DAGGERFALL_COVENANT)
        self.state.villages[id].siegeWeapons.EP = GetNumSieges(id, BGQUERY_LOCAL, ALLIANCE_EBONHEART_PACT)
        self.state.villages[id].owningAlliance = GetKeepAlliance(id, BGQUERY_LOCAL)
    end
end

function PvPUA:InitDestructibles(gameTime)
    self.state.destructibles = {}
    for i = 154, 162 do
        self.state.destructibles[i] = {}
        self.state.destructibles[i].id = i
        self.state.destructibles[i].keepType = GetKeepType(i)
        self.state.destructibles[i].name = AdjustResourceName(zo_strformat("<<1>>", GetKeepName(i)))
        self.state.destructibles[i].isUnderAttack = GetKeepUnderAttack(i, BGQUERY_LOCAL)
        if self.state.destructibles[i].isUnderAttack == true then
            self.state.destructibles[i].interestingSince = gameTime
        else
            self.state.destructibles[i].interestingSince = nil
        end
        self.state.destructibles[i].attackStatusLostAt = 0
        self.state.destructibles[i].underAttackFor = 0
        self.state.destructibles[i].isPassable = IsKeepPassable(i, BGQUERY_LOCAL)
        self.state.destructibles[i].directionalAccess = GetKeepDirectionalAccess(i, BGQUERY_LOCAL)
    end
end

function PvPUA:InitDistricts(gameTime)
    self.state.districts = {}
    if not (GetNumKeeps and GetKeepKeysByIndex) then return end
    pcall(function()
        local n = GetNumKeeps() or 0
        for i = 1, n do
            local id = GetKeepKeysByIndex(i)
            if id and id ~= 0 and GetKeepType(id) == KEEPTYPE_IMPERIAL_CITY_DISTRICT then
                local d = {}
                d.id = id
                d.keepType = KEEPTYPE_IMPERIAL_CITY_DISTRICT
                d.name = AdjustDistrictName(zo_strformat("<<1>>", GetKeepName(id)))
                d.isUnderAttack = GetKeepUnderAttack(id, BGQUERY_LOCAL)
                if d.isUnderAttack == true then d.interestingSince = gameTime end
                d.attackStatusLostAt = 0
                d.underAttackFor = 0
                d.owningAlliance = GetKeepAlliance(id, BGQUERY_LOCAL)
                d.objectives = { { id = nil, state = 100, holdingAlliance = d.owningAlliance } }
                self.state.districts[id] = d
            end
        end
    end)
end

function PvPUA:InitState(hadVolendrung)
    local gameTime = GetGameTimeMilliseconds()
    self:KillTallyResetState()

    if IsInICCampaign() then
        self.state.resources = {}
        self.state.keeps = {}
        self.state.outposts = {}
        self.state.villages = {}
        self.state.destructibles = {}
        self.homeKeepIds = {}
        self:InitDistricts(gameTime)
        self:AddObjectives()
        self:KillTallyRestore()
        return
    end

    self.state.districts = {}
    self:InitResources(gameTime)
    self:InitKeeps(gameTime)
    self:InitOutposts(gameTime)
    self:InitVillages(gameTime)
    self:InitDestructibles(gameTime)
    self:AddObjectives()
    self:KillTallyRestore()
    self:ScanForVolendrung()
    self:ScanForScrolls()
    if self.volendrung == nil and hadVolendrung then
        self.volendrung = hadVolendrung
        self.volendrung.despawnAt = GetGameTimeMilliseconds() + VOLENDRUNG_DESPAWN_GRACE
    end
end

--------------------------------------------------
-- ScanForVolendrung
--------------------------------------------------
function PvPUA:ScanForVolendrung()
    if not GetNumObjectives then return end
    local n = GetNumObjectives()
    if not n then return end
    for i = 1, n do
        local keepId, objectiveId = GetObjectiveIdsForIndex(i)
        if keepId and objectiveId then
            local _, objectiveType, objectiveState = GetObjectiveInfo(keepId, objectiveId, BGQUERY_LOCAL)
            if objectiveType == OBJECTIVE_DAEDRIC_WEAPON then
                local objectiveControlEvent = GetLastObjectiveControlEvent(keepId, objectiveId, BGQUERY_LOCAL)
                if objectiveState == OBJECTIVE_CONTROL_STATE_FLAG_DROPPED
                or objectiveState == OBJECTIVE_CONTROL_STATE_FLAG_HELD
                or objectiveControlEvent == OBJECTIVE_CONTROL_EVENT_FLAG_SPAWNED
                or (objectiveState ~= nil and objectiveState ~= OBJECTIVE_CONTROL_STATE_UNKNOWN) then
                    local pinType = GetObjectivePinInfo(keepId, objectiveId, BGQUERY_LOCAL)
                    self.volendrung = {
                        texture        = GetVolendrungTexture(pinType),
                        holderAlliance = GetVolendrungAlliance(pinType),
                        objectiveId    = objectiveId,
                        keepId         = keepId,
                        despawnAt      = nil,
                        spawnedAt      = GetGameTimeMilliseconds(),
                    }
                    return
                end
            end
        end
    end
end

local SCROLL_TEXTURE_FALLBACK = {
    [MAP_PIN_TYPE_ARTIFACT_ALDMERI_OFFENSIVE]     = "/esoui/art/mappins/ava_artifact_altadoon.dds",
    [MAP_PIN_TYPE_ARTIFACT_ALDMERI_DEFENSIVE]     = "/esoui/art/mappins/ava_artifact_mnem.dds",
    [MAP_PIN_TYPE_ARTIFACT_EBONHEART_OFFENSIVE]   = "/esoui/art/mappins/ava_artifact_ghartok.dds",
    [MAP_PIN_TYPE_ARTIFACT_EBONHEART_DEFENSIVE]   = "/esoui/art/mappins/ava_artifact_chim.dds",
    [MAP_PIN_TYPE_ARTIFACT_DAGGERFALL_OFFENSIVE]  = "/esoui/art/mappins/ava_artifact_nimohk.dds",
    [MAP_PIN_TYPE_ARTIFACT_DAGGERFALL_DEFENSIVE]  = "/esoui/art/mappins/ava_artifact_almaruma.dds",
}

local SCROLL_PINTYPE_ALLIANCE = {
    [MAP_PIN_TYPE_ARTIFACT_ALDMERI_OFFENSIVE]     = ALLIANCE_ALDMERI_DOMINION,
    [MAP_PIN_TYPE_ARTIFACT_ALDMERI_DEFENSIVE]     = ALLIANCE_ALDMERI_DOMINION,
    [MAP_PIN_TYPE_ARTIFACT_EBONHEART_OFFENSIVE]   = ALLIANCE_EBONHEART_PACT,
    [MAP_PIN_TYPE_ARTIFACT_EBONHEART_DEFENSIVE]   = ALLIANCE_EBONHEART_PACT,
    [MAP_PIN_TYPE_ARTIFACT_DAGGERFALL_OFFENSIVE]  = ALLIANCE_DAGGERFALL_COVENANT,
    [MAP_PIN_TYPE_ARTIFACT_DAGGERFALL_DEFENSIVE]  = ALLIANCE_DAGGERFALL_COVENANT,
}

local function GetScrollTexture(pinType)
    if pinType and ZO_MapPin and ZO_MapPin.PIN_DATA and ZO_MapPin.PIN_DATA[pinType] then
        local tex = ZO_MapPin.PIN_DATA[pinType].texture
        if tex and type(tex) == "string" then return tex end
    end
    return SCROLL_TEXTURE_FALLBACK[pinType]
end

--------------------------------------------------
-- Scroll Display
--------------------------------------------------
function PvPUA:RefreshScrolls()
    local ok = pcall(function()
        for _, keep in pairs(self.state.keeps) do keep.scroll = nil end
        for _, town in pairs(self.state.villages) do town.scroll = nil end

        if not GetNumObjectives then return end
        local keysFn = GetAvAObjectiveKeysByIndex or GetObjectiveIdsForIndex
        local n = GetNumObjectives() or 0
        for i = 1, n do
            local keepId, objectiveId, ctx = keysFn(i)
            if keepId and objectiveId then
                local ctxUse = ctx or BGQUERY_LOCAL
                local _, oType, oState = GetObjectiveInfo(keepId, objectiveId, ctxUse)
                if (oType == OBJECTIVE_ARTIFACT_OFFENSIVE or oType == OBJECTIVE_ARTIFACT_DEFENSIVE)
                and oState == OBJECTIVE_CONTROL_STATE_FLAG_AT_ENEMY_BASE then
                    local atKeep
                    if GetKeepThatHasCapturedThisArtifactScrollObjective then
                        atKeep = GetKeepThatHasCapturedThisArtifactScrollObjective(keepId, objectiveId, ctxUse)
                    end
                    local target
                    if atKeep and atKeep ~= 0 then
                        target = self.state.keeps[atKeep] or self.state.villages[atKeep]
                    end
                    if target then
                        local pinType = GetObjectivePinInfo(keepId, objectiveId, ctxUse)
                        local home
                        if GetArtifactScrollObjectiveOriginalOwningAlliance then
                            home = GetArtifactScrollObjectiveOriginalOwningAlliance(keepId, objectiveId, ctxUse)
                        end
                        if not home or home == 0 then home = SCROLL_PINTYPE_ALLIANCE[pinType] or 0 end
                        if pinType then
                            target.scroll = {
                                pinType         = pinType,
                                holdingAlliance = home,
                                objectiveId     = objectiveId,
                            }
                        end
                    end
                end
            end
        end
    end)
    if not ok then
        for _, keep in pairs(self.state.keeps) do keep.scroll = nil end
        for _, town in pairs(self.state.villages) do town.scroll = nil end
    end
end

function PvPUA:ScanForScrolls()
    self:RefreshScrolls()
end

local SCROLL_CARRIER_GRACE = 30000

local SCROLL_KEEP_ICON_SCALE        = PvPUA.config.iconScale.scrollOnKeep
local SCROLL_CARRIER_ICON_SCALE     = PvPUA.config.iconScale.scrollCarrier
local VOLENDRUNG_CARRIER_ICON_SCALE = PvPUA.config.iconScale.volendrung

PvPUA.scrollCarriers = {}

PvPUA.artifactHolders = {}
PvPUA.artifactHolderAlliance = {}

local function ScrollKey(name)
    if not name then return "" end
    name = zo_strformat("<<1>>", name)
    name = name:gsub("^Elder Scroll of ", ""):gsub("^Scroll of ", "")
    return string.lower(name)
end

function PvPUA:OnArtifactControlState(_, artifactName, keepId, characterName, playerAlliance, objectiveControlEvent, objectiveControlState, campaignId, displayName)
    if campaignId == 0 then return end
    local key = artifactName and ScrollKey(artifactName) or nil
    if not key or key == "" then return end
    if objectiveControlEvent == OBJECTIVE_CONTROL_EVENT_FLAG_TAKEN then
        local nm = displayName or characterName or ""
        if type(nm) == "string" then
            local stripped = (nm:gsub("^@", ""))
            if stripped ~= "" then nm = stripped end
        end
        self.artifactHolders[key] = nm
        self.artifactHolderAlliance[key] = playerAlliance or 0
    elseif objectiveControlEvent == OBJECTIVE_CONTROL_EVENT_FLAG_SPAWNED then
        self.artifactHolders[key] = ""
        self.artifactHolderAlliance[key] = 0
    end
end

local function ShortenScrollName(name)
    if not name then return "" end
    name = zo_strformat("<<1>>", name)
    name = name:gsub("^Elder Scroll of ", ""):gsub("^Scroll of ", "")
    return name
end

local function ShortenPOIName(name)
    if not name then return "" end
    name = zo_strformat("<<1>>", name)
    name = name:gsub(",..$", "")
                :gsub("%^.d$", "")
                :gsub(" Wayshrine", "")
                :gsub("District", "")
                :gsub("Castle ", "")
                :gsub("[fF]ort ", "")
                :gsub("[Ll]umber ?[Mm]ill", "Lumber")
                :gsub("^Scroll Temple of ", "Temple of ")
                :gsub("Keep ", "")
                :gsub("Keep$", "")
                :gsub("Outpost", "")
    name = name:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return name
end

PvPUA.locationCache = PvPUA.locationCache or {}

function PvPUA:BuildLocationCache()
    local mapId = GetCurrentMapId and GetCurrentMapId() or 0
    if self.locationCache[mapId] then return self.locationCache[mapId] end

    local list = {}

    for keepId = 1, 200 do
        local _, nx, ny = GetKeepPinInfo(keepId, BGQUERY_LOCAL)
        local keepName = GetKeepName and GetKeepName(keepId) or nil
        if nx and ny and not (nx == 0 and ny == 0)
           and keepName and keepName ~= "" then
            list[#list + 1] = { x = nx, y = ny, name = ShortenPOIName(keepName) }
        end
    end

    if #list == 0 then return {} end

    if GetNumPOIs and GetPOIMapInfo and GetPOIInfo then
        local zoneIndex = GetCurrentMapZoneIndex and GetCurrentMapZoneIndex() or nil
        if zoneIndex then
            local count = GetNumPOIs(zoneIndex) or 0
            for poiIndex = 1, count do
                local nx, ny = GetPOIMapInfo(zoneIndex, poiIndex)
                local poiName = GetPOIInfo(zoneIndex, poiIndex)
                if nx and ny and not (nx == 0 and ny == 0)
                   and poiName and poiName ~= "" then
                    list[#list + 1] = { x = nx, y = ny, name = ShortenPOIName(poiName) }
                end
            end
        end
    end

    self.locationCache[mapId] = list
    return list
end

function PvPUA:GetClosestLocationName(x, y)
    if not x or not y then return "" end
    if x == 0 and y == 0 then return "" end

    local list = self:BuildLocationCache()
    local bestName, bestDistSq = "", math.huge
    for i = 1, #list do
        local v = list[i]
        local dx = v.x - x
        local dy = v.y - y
        local dsq = dx * dx + dy * dy
        if dsq < bestDistSq then
            bestDistSq = dsq
            bestName = v.name
        end
    end
    return bestName
end

function PvPUA:RefreshScrollCarriers()
    local ok = pcall(function()
        local now = GetGameTimeMilliseconds()
        local seen = {}

        if GetNumObjectives then
            local keysFn = GetAvAObjectiveKeysByIndex or GetObjectiveIdsForIndex
            local n = GetNumObjectives() or 0
            for i = 1, n do
                local keepId, objectiveId, ctx = keysFn(i)
                if keepId and objectiveId then
                    local ctxUse = ctx or BGQUERY_LOCAL
                    local oName, oType, oState = GetObjectiveInfo(keepId, objectiveId, ctxUse)
                    if (oType == OBJECTIVE_ARTIFACT_OFFENSIVE or oType == OBJECTIVE_ARTIFACT_DEFENSIVE)
                    and (oState == OBJECTIVE_CONTROL_STATE_FLAG_HELD
                      or oState == OBJECTIVE_CONTROL_STATE_FLAG_DROPPED) then

                        local key = tostring(keepId) .. ":" .. tostring(objectiveId)
                        seen[key] = true

                        local c = self.scrollCarriers[key]
                        if not c then
                            c = { startedAt = now }
                            self.scrollCarriers[key] = c
                        end

                        local pinType, px, py = GetObjectivePinInfo(keepId, objectiveId, ctxUse)
                        c.texture = GetScrollTexture(pinType)
                        c.scrollName = ShortenScrollName(oName)

                        c.scrollAlliance = SCROLL_PINTYPE_ALLIANCE[pinType] or 0

                        local nameKey = ScrollKey(oName)
                        local holderName, holderAlliance

                        if self.artifactHolders[nameKey] and self.artifactHolders[nameKey] ~= "" then
                            holderName = self.artifactHolders[nameKey]
                            holderAlliance = self.artifactHolderAlliance[nameKey]
                        end

                        local function pickHolder(raw, display)
                            if type(display) == "string" and display ~= "" then
                                local stripped = (display:gsub("^@", ""))
                                if stripped ~= "" then return stripped end
                            end
                            if type(raw) == "string" and raw ~= "" then return raw end
                            return nil
                        end

                        if (holderName == nil or holderName == "") and GetCarryableObjectiveHoldingCharacterInfo then
                            local raw, disp = GetCarryableObjectiveHoldingCharacterInfo(keepId, objectiveId, ctxUse)
                            holderName = pickHolder(raw, disp)
                        end
                        if (holderName == nil or holderName == "") and GetCarryableObjectiveLastHoldingCharacterInfo then
                            local raw, disp = GetCarryableObjectiveLastHoldingCharacterInfo(keepId, objectiveId, ctxUse)
                            holderName = pickHolder(raw, disp)
                        end
                        if (holderAlliance == nil or holderAlliance == 0) and GetCarryableObjectiveHoldingAllianceInfo then
                            local hA, lastA = GetCarryableObjectiveHoldingAllianceInfo(keepId, objectiveId, ctxUse)
                            holderAlliance = (hA and hA ~= 0) and hA or lastA
                        end

                        if oState == OBJECTIVE_CONTROL_STATE_FLAG_DROPPED then
                            holderName = "Dropped"
                        elseif holderName == nil or holderName == "" then
                            holderName = "Held"
                        end
                        c.holder = holderName
                        c.holderAlliance = holderAlliance or 0
                        c.location = self:GetClosestLocationName(px, py)

                        if oState == OBJECTIVE_CONTROL_STATE_FLAG_DROPPED then
                            c.droppedAt = c.droppedAt or now
                        else
                            c.droppedAt = nil
                        end
                    end
                end
            end
        end

        for key, c in pairs(self.scrollCarriers) do
            if not seen[key] then
                self.scrollCarriers[key] = nil
            elseif c.droppedAt and (now - c.droppedAt) > SCROLL_CARRIER_GRACE then
                self.scrollCarriers[key] = nil
            end
        end
    end)
    if not ok then self.scrollCarriers = {} end
end

function PvPUA:GetScrollCarrierItems()
    local out = {}
    local now = GetGameTimeMilliseconds()
    for key, c in pairs(self.scrollCarriers) do
        local scrollName = c.scrollName or ""
        local loc         = c.location or ""
        local who         = c.holder or ""
        local isDropped   = (c.droppedAt ~= nil)
        local sc = GetColorForAlliance(c.scrollAlliance or 0)
        local label = "|c" .. ToHex(sc.r, sc.g, sc.b) .. scrollName .. "|r"
        local hasPrefix = (scrollName ~= "")
        if loc ~= "" then
            label = label .. " @ " .. loc
            hasPrefix = true
        end
        if who ~= "" then
            local hc = GetColorForAlliance(c.holderAlliance or 0)
            local holderHex = isDropped and "FFFFFF" or ToHex(hc.r, hc.g, hc.b)
            local bracket = "|c" .. holderHex .. "[" .. who .. "]|r"
            label = hasPrefix and (label .. " " .. bracket) or bracket
        end
        out[#out + 1] = {
            isScrollCarrier = true,
            isScrollDropped = isDropped,
            id              = 0,
            name            = label,
            carrierTexture  = c.texture,
            scrollAlliance  = c.scrollAlliance or 0,
            owningAlliance  = c.holderAlliance or 0,
            isUnderAttack   = false,
            underAttackFor  = now - (c.startedAt or now),
            interestingSince = c.startedAt,
            siegeWeapons    = {},
        }
    end
    return out
end

local VOLENDRUNG_NEUTRAL_TEXTURE = "/esoui/art/mappins/ava_daedricartifact_volendrung_neutral.dds"

PvPUA.volendrungName    = nil

function PvPUA:RefreshVolendrungCarrier()
    local ok = pcall(function()
        local fKeep, fObj, fCtx, oName, oState, pinType, px, py

        if GetNumObjectives then
            local keysFn = GetAvAObjectiveKeysByIndex or GetObjectiveIdsForIndex
            local n = GetNumObjectives() or 0
            for i = 1, n do
                local keepId, objectiveId, ctx = keysFn(i)
                if keepId and objectiveId then
                    local ctxUse = ctx or BGQUERY_LOCAL
                    local nm, ty, st = GetObjectiveInfo(keepId, objectiveId, ctxUse)
                    if ty == OBJECTIVE_DAEDRIC_WEAPON
                    and st ~= nil and st ~= OBJECTIVE_CONTROL_STATE_UNKNOWN then
                        fKeep, fObj, fCtx = keepId, objectiveId, ctxUse
                        oName, oState = nm, st
                        pinType, px, py = GetObjectivePinInfo(keepId, objectiveId, ctxUse)
                        break
                    end
                end
            end
        end

        local activeId = GetActiveDaedricArtifactId and GetActiveDaedricArtifactId() or 0

        if fKeep or (activeId and activeId ~= 0) then
            local v = self.volendrung
            if not v then
                v = { spawnedAt = GetGameTimeMilliseconds() }
                self.volendrung = v
            end
            if fKeep then
                v.keepId, v.objectiveId, v.ctx = fKeep, fObj, fCtx
                v.texture = GetVolendrungTexture(pinType)
                v.holderAlliance = GetVolendrungAlliance(pinType) or 0
            end
            v.despawnAt = nil
            if activeId and activeId ~= 0 and GetDaedricArtifactDisplayName then
                local nm = GetDaedricArtifactDisplayName(activeId)
                if nm and nm ~= "" then self.volendrungName = zo_strformat("<<1>>", nm) end
            end
        end

        local v = self.volendrung
        if not v then return end

        local isDropped = (oState == OBJECTIVE_CONTROL_STATE_FLAG_DROPPED)
        local isHeld    = (oState == OBJECTIVE_CONTROL_STATE_FLAG_HELD)

        local alliance
        if fKeep and GetCarryableObjectiveHoldingAllianceInfo then
            alliance = GetCarryableObjectiveHoldingAllianceInfo(fKeep, fObj, fCtx)
        end
        if not alliance or alliance == 0 then
            alliance = GetVolendrungAlliance(pinType) or 0
        end

        local holder
        local objKey = oName and oName ~= "" and ScrollKey(oName) or nil
        if objKey and self.artifactHolders[objKey]
           and self.artifactHolders[objKey] ~= "" and self.artifactHolders[objKey] ~= "?" then
            holder = self.artifactHolders[objKey]
        end

        if (holder == nil or holder == "") and fKeep then
            local function pick(raw, display)
                if type(display) == "string" and display ~= "" then
                    local stripped = (display:gsub("^@", ""))
                    if stripped ~= "" then return stripped end
                end
                if type(raw) == "string" and raw ~= "" then return raw end
                return nil
            end
            if GetCarryableObjectiveHoldingCharacterInfo then
                holder = pick(GetCarryableObjectiveHoldingCharacterInfo(fKeep, fObj, fCtx))
            end
            if (holder == nil or holder == "") and GetCarryableObjectiveLastHoldingCharacterInfo then
                holder = pick(GetCarryableObjectiveLastHoldingCharacterInfo(fKeep, fObj, fCtx))
            end
        end

        if holder and holder ~= "" then
            v.knownHolder         = holder
            v.knownHolderAlliance = alliance or 0
        elseif isHeld and v.knownHolder
           and v.knownHolderAlliance == (alliance or 0) and (alliance or 0) ~= 0 then
            holder = v.knownHolder .. "?"
        end
        if isDropped or (alliance or 0) == 0
           or (v.knownHolderAlliance and v.knownHolderAlliance ~= (alliance or 0)) then
            if not (holder and holder ~= "") then
                v.knownHolder, v.knownHolderAlliance = nil, nil
            end
        end

        if isDropped then
            v.holder      = "Dropped"
            v.rowAlliance = 0
        elseif isHeld then
            v.holder      = (holder and holder ~= "") and holder or "Held"
            v.rowAlliance = alliance or 0
        else
            v.holder      = nil
            v.rowAlliance = 0
        end

        if self.config.volendrungTintToHud then
            v.rowTexture = VOLENDRUNG_NEUTRAL_TEXTURE
        elseif v.rowAlliance == 0 then
            v.rowTexture = VOLENDRUNG_NEUTRAL_TEXTURE
        else
            v.rowTexture = GetVolendrungTexture(pinType) or VOLENDRUNG_NEUTRAL_TEXTURE
        end

        v.isDropped = isDropped
        v.location  = self:GetClosestLocationName(px, py)
        v.rowName   = (oName and oName ~= "" and zo_strformat("<<1>>", oName))
                      or self.volendrungName or "Volendrung"
    end)

    if not ok and self.volendrung then
        local v = self.volendrung
        v.holder, v.location, v.isDropped = nil, "", false
        v.rowAlliance = 0
        v.rowTexture  = VOLENDRUNG_NEUTRAL_TEXTURE
        v.rowName     = self.volendrungName or "Volendrung"
    end
end

function PvPUA:GetVolendrungCarrierItem()
    local v = self.volendrung
    if not v then return nil end

    local rowName   = v.rowName or self.volendrungName or "Volendrung"
    local loc       = v.location or ""
    local who       = v.holder or ""
    local isDropped = (v.isDropped == true)

    local carrierAlliance = (not isDropped) and (v.rowAlliance or 0) or 0
    local cc  = GetColorForAlliance(carrierAlliance)
    local hex = ToHex(cc.r, cc.g, cc.b)

    local label = "|c" .. hex .. rowName .. "|r"
    local hasPrefix = (rowName ~= "")
    if loc ~= "" then
        label = label .. " @ " .. loc
        hasPrefix = true
    end
    if who ~= "" then
        local bracket = "|c" .. hex .. "[" .. who .. "]|r"
        label = hasPrefix and (label .. " " .. bracket) or bracket
    end

    local now = GetGameTimeMilliseconds()
    return {
        isScrollCarrier  = true,
        isVolendrung     = true,
        isScrollDropped  = isDropped,
        id               = 0,
        name             = label,
        carrierTexture   = v.rowTexture or VOLENDRUNG_NEUTRAL_TEXTURE,
        carrierIconScale = VOLENDRUNG_CARRIER_ICON_SCALE,
        carrierTint      = (self.config.volendrungTintToHud == true),
        scrollAlliance   = v.rowAlliance or 0,
        owningAlliance   = v.rowAlliance or 0,
        isUnderAttack    = false,
        underAttackFor   = now - (v.spawnedAt or now),
        interestingSince = v.spawnedAt,
        siegeWeapons     = {},
    }
end

PvPUA.constants.textures.SCROLL_TALLY = {
    [ALLIANCE_ALDMERI_DOMINION]    = "/esoui/art/campaign/overview_scrollicon_aldmeri.dds",
    [ALLIANCE_EBONHEART_PACT]      = "/esoui/art/campaign/overview_scrollicon_ebonheart.dds",
    [ALLIANCE_DAGGERFALL_COVENANT] = "/esoui/art/campaign/overview_scrollicon_daggefall.dds",
}

PvPUA.scrollCounts = { [ALLIANCE_ALDMERI_DOMINION] = 0, [ALLIANCE_DAGGERFALL_COVENANT] = 0, [ALLIANCE_EBONHEART_PACT] = 0 }

function PvPUA:UpdateScrollCounts()
    local ok = pcall(function()
        local ad, dc, ep = 0, 0, 0
        if GetNumObjectives and GetKeepThatHasCapturedThisArtifactScrollObjective then
            local keysFn = GetAvAObjectiveKeysByIndex or GetObjectiveIdsForIndex
            local n = GetNumObjectives() or 0
            for i = 1, n do
                local keepId, objectiveId, ctx = keysFn(i)
                if keepId and objectiveId then
                    local ctxUse = ctx or BGQUERY_LOCAL
                    local holdingKeep = GetKeepThatHasCapturedThisArtifactScrollObjective(keepId, objectiveId, ctxUse)
                    if holdingKeep and holdingKeep ~= 0 then
                        local state = GetObjectiveControlState and GetObjectiveControlState(keepId, objectiveId, ctxUse)
                        if state == nil
                        or state == OBJECTIVE_CONTROL_STATE_FLAG_AT_BASE
                        or state == OBJECTIVE_CONTROL_STATE_FLAG_AT_ENEMY_BASE then
                            local alliance = GetKeepAlliance(holdingKeep, ctxUse)
                            if alliance == ALLIANCE_ALDMERI_DOMINION then ad = ad + 1
                            elseif alliance == ALLIANCE_DAGGERFALL_COVENANT then dc = dc + 1
                            elseif alliance == ALLIANCE_EBONHEART_PACT then ep = ep + 1 end
                        end
                    end
                end
            end
        end
        self.scrollCounts[ALLIANCE_ALDMERI_DOMINION]    = ad
        self.scrollCounts[ALLIANCE_DAGGERFALL_COVENANT] = dc
        self.scrollCounts[ALLIANCE_EBONHEART_PACT]      = ep
    end)
    if not ok then
        self.scrollCounts[ALLIANCE_ALDMERI_DOMINION]    = 0
        self.scrollCounts[ALLIANCE_DAGGERFALL_COVENANT] = 0
        self.scrollCounts[ALLIANCE_EBONHEART_PACT]      = 0
    end
end

function PvPUA:RefreshScrollTally()
    local map = {
        { icon = self.controls.scoreDCScroll, txt = self.controls.scoreDCScrollTxt, alliance = ALLIANCE_DAGGERFALL_COVENANT },
        { icon = self.controls.scoreADScroll, txt = self.controls.scoreADScrollTxt, alliance = ALLIANCE_ALDMERI_DOMINION },
        { icon = self.controls.scoreEPScroll, txt = self.controls.scoreEPScrollTxt, alliance = ALLIANCE_EBONHEART_PACT },
    }
    for i = 1, #map do
        local e = map[i]
        if e.icon and e.txt then
            local count = self.scrollCounts[e.alliance] or 0
            e.icon:SetHidden(false)
            e.txt:SetHidden(false)
            e.txt:SetText(tostring(count))
        end
    end
end

--------------------------------------------------
-- AddObjectives
--------------------------------------------------
function PvPUA:AddObjectives()
    local numObjectives = GetNumObjectives()
    for i = 1, numObjectives do
        local keepId, objectiveId, bgqueryType = GetObjectiveIdsForIndex(i)
        if bgqueryType == BGQUERY_ASSIGNED_AND_LOCAL or bgqueryType == BGQUERY_LOCAL then
            if self.state.keeps[keepId] ~= nil then
                self.state.keeps[keepId].objectives = self.state.keeps[keepId].objectives or {}
                if self.state.keeps[keepId].objectives[1] == nil then
                    self.state.keeps[keepId].objectives[1] = {}
                    self.state.keeps[keepId].objectives[1].id = objectiveId
                    self.state.keeps[keepId].objectives[1].state = 100
                    self.state.keeps[keepId].objectives[1].holdingAlliance = self.state.keeps[keepId].owningAlliance
                elseif self.state.keeps[keepId].objectives[2] == nil then
                    self.state.keeps[keepId].objectives[2] = {}
                    self.state.keeps[keepId].objectives[2].id = objectiveId
                    self.state.keeps[keepId].objectives[2].state = 100
                    self.state.keeps[keepId].objectives[2].holdingAlliance = self.state.keeps[keepId].owningAlliance
                end
            elseif self.state.resources[keepId] ~= nil then
                self.state.resources[keepId].objectives = self.state.resources[keepId].objectives or {}
                self.state.resources[keepId].objectives[1] = {}
                self.state.resources[keepId].objectives[1].id = objectiveId
                self.state.resources[keepId].objectives[1].state = 100
                self.state.resources[keepId].objectives[1].holdingAlliance = self.state.resources[keepId].owningAlliance
            elseif self.state.outposts[keepId] ~= nil then
                self.state.outposts[keepId].objectives = self.state.outposts[keepId].objectives or {}
                if self.state.outposts[keepId].objectives[1] == nil then
                    self.state.outposts[keepId].objectives[1] = {}
                    self.state.outposts[keepId].objectives[1].id = objectiveId
                    self.state.outposts[keepId].objectives[1].state = 100
                    self.state.outposts[keepId].objectives[1].holdingAlliance = self.state.outposts[keepId].owningAlliance
                else
                    self.state.outposts[keepId].objectives[2] = {}
                    self.state.outposts[keepId].objectives[2].id = objectiveId
                    self.state.outposts[keepId].objectives[2].state = 100
                    self.state.outposts[keepId].objectives[2].holdingAlliance = self.state.outposts[keepId].owningAlliance
                end
            elseif self.state.districts[keepId] ~= nil then
                self.state.districts[keepId].objectives = self.state.districts[keepId].objectives or {}
                self.state.districts[keepId].objectives[1] = {}
                self.state.districts[keepId].objectives[1].id = objectiveId
                self.state.districts[keepId].objectives[1].state = 100
                self.state.districts[keepId].objectives[1].holdingAlliance = self.state.districts[keepId].owningAlliance
            elseif self.state.villages[keepId] ~= nil then
                self.state.villages[keepId].objectives = self.state.villages[keepId].objectives or {}
                if self.state.villages[keepId].objectives[1] == nil then
                    self.state.villages[keepId].objectives[1] = {}
                    self.state.villages[keepId].objectives[1].id = objectiveId
                    self.state.villages[keepId].objectives[1].state = 100
                    self.state.villages[keepId].objectives[1].holdingAlliance = self.state.villages[keepId].owningAlliance
                elseif self.state.villages[keepId].objectives[2] == nil then
                    self.state.villages[keepId].objectives[2] = {}
                    self.state.villages[keepId].objectives[2].id = objectiveId
                    self.state.villages[keepId].objectives[2].state = 100
                    self.state.villages[keepId].objectives[2].holdingAlliance = self.state.villages[keepId].owningAlliance
                else
                    self.state.villages[keepId].objectives[3] = {}
                    self.state.villages[keepId].objectives[3].id = objectiveId
                    self.state.villages[keepId].objectives[3].state = 100
                    self.state.villages[keepId].objectives[3].holdingAlliance = self.state.villages[keepId].owningAlliance
                end
            end
        end
    end
end

--------------------------------------------------
-- ResetObjectives
--------------------------------------------------
function PvPUA:ResetObjective(keeps)
    for key, keep in pairs(keeps) do
        if keep.objectives ~= nil then
            for i = 1, #keep.objectives do
                keep.objectives[i].state = 100
                keep.objectives[i].holdingAlliance = keep.owningAlliance
            end
        end
    end
end

function PvPUA:ResetObjectives()
    self:ResetObjective(self.state.keeps)
    self:ResetObjective(self.state.outposts)
    self:ResetObjective(self.state.resources)
    self:ResetObjective(self.state.villages)
    self:ResetObjective(self.state.districts)
end

--------------------------------------------------
-- GetItemByKeepId
--------------------------------------------------
function PvPUA:GetItemByKeepId(keepId)
    if keepId ~= nil then
        if self.state.resources[keepId] ~= nil then return self.state.resources[keepId]
        elseif self.state.keeps[keepId] ~= nil then return self.state.keeps[keepId]
        elseif self.state.outposts[keepId] ~= nil then return self.state.outposts[keepId]
        elseif self.state.villages[keepId] ~= nil then return self.state.villages[keepId]
        elseif self.state.districts[keepId] ~= nil then return self.state.districts[keepId]
        end
    end
    return nil
end

--------------------------------------------------
-- Flag State / Flip Logic
--------------------------------------------------
local function GetFlagStatePercent(state, owningAlliance, holdingAlliance)
    local percent = 99
    if state == OBJECTIVE_CONTROL_STATE_AREA_ABOVE_CONTROL_THRESHOLD then
        if holdingAlliance == owningAlliance then percent = 90 else percent = 51 end
    elseif state == OBJECTIVE_CONTROL_STATE_AREA_NO_CONTROL then
        if holdingAlliance == 0 then percent = 0 else percent = 10 end
    elseif state == OBJECTIVE_CONTROL_STATE_AREA_MAX_CONTROL then
        percent = 100
    elseif state == OBJECTIVE_CONTROL_STATE_AREA_BELOW_CONTROL_THRESHOLD then
        if holdingAlliance == owningAlliance then percent = 40 else percent = 10 end
    end
    return percent
end

local function GetFlipConstant(keepType)
    if keepType == KEEPTYPE_KEEP then return PvPUA.constants.flipTimes.KEEP
    elseif keepType == KEEPTYPE_OUTPOST then return PvPUA.constants.flipTimes.OUTPOST
    elseif keepType == KEEPTYPE_RESOURCE then return PvPUA.constants.flipTimes.RESOURCE
    else return 0 end
end

local function FlagsAtFlipState(objectives, owningAlliance)
    local flips = false
    if objectives ~= nil then
        local flipedFlags = 0
        for i = 1, #objectives do
            if objectives[i].holdingAlliance ~= owningAlliance and objectives[i].state > 50 then
                flipedFlags = flipedFlags + 1
            else
                break
            end
        end
        if flipedFlags == #objectives then
            if #objectives == 1 then
                flips = true
            elseif #objectives == 2 and objectives[1].holdingAlliance == objectives[2].holdingAlliance then
                flips = true
            elseif #objectives == 3 and objectives[1].holdingAlliance == objectives[2].holdingAlliance and objectives[1].holdingAlliance == objectives[3].holdingAlliance then
                flips = true
            end
        end
    end
    return flips
end

local function AdjustKeepFlipping(keep)
    local flipTime = GetFlipConstant(keep.keepType)
    if flipTime > 0 then
        if FlagsAtFlipState(keep.objectives, keep.owningAlliance) == true then
            if keep.flipsAt == nil then
                keep.flipsAt = GetGameTimeMilliseconds() + flipTime
            end
        else
            keep.flipsAt = nil
        end
    end
end

--------------------------------------------------
-- UpdateItem
--------------------------------------------------
local notifCooldowns = {}

local function FireKeepUA(keepId, name, owningAlliance)
    if not PvPUA.savedVariables or not PvPUA.savedVariables.alertsEnabled then return end

    local now = GetGameTimeMilliseconds()
    if notifCooldowns[keepId] and now - notifCooldowns[keepId] < 30000 then return end
    notifCooldowns[keepId] = now

    local ac = GetColorForAlliance(owningAlliance)
    local nameHex = ToHex(ac.r, ac.g, ac.b)
    PvPUA:HKPush(keepId, string.format("|c%s%s|r |cFF8C00UA!|r", nameHex, name))
end

--------------------------------------------------
-- Debug log (Patch) - optional LibConsoleLogger
--------------------------------------------------
-- Field diagnostics for the kill-marker / kill-feed listing. Everything goes to LibConsoleLogger's
-- export buffer only (never chat) and only while Settings > "Debug Log" is on AND the library is
-- installed and enabled in its own settings; without the library every call is a nil check.
-- Lines are event-driven and change-only (no per-tick output), so a fight is a few hundred lines.
-- Export: Settings > "Export Debug Log" (or the library's own Export). Cap the buffer in the
-- library's "Buffer size" setting to keep an export to a few browser round trips.
local DL = { last = {}, logger = nil }

local function DLLib()
    local lib = rawget(_G, "LibConsoleLogger")
    if type(lib) ~= "table" or type(lib.For) ~= "function" then return nil end
    return lib
end

function PvPUA:DebugLogAvailable()
    return DLLib() ~= nil
end

function PvPUA:DebugLogEnabled()
    local sv = self.savedVariables
    return sv ~= nil and sv.debugLog == true and DLLib() ~= nil
end

local function DLAlliance(alliance)
    if alliance == ALLIANCE_DAGGERFALL_COVENANT then return "DC" end
    if alliance == ALLIANCE_ALDMERI_DOMINION then return "AD" end
    if alliance == ALLIANCE_EBONHEART_PACT then return "EP" end
    return tostring(alliance)
end

local function DLItemName(item)
    if item == nil then return "none" end
    return tostring(item.name or ("#" .. tostring(item.id)))
end

-- Buffer one formatted line, stamped with the game clock in seconds.
local function DLog(fmt, ...)
    if not PvPUA:DebugLogEnabled() then return end
    local logger = DL.logger
    if logger == nil then
        local lib = DLLib()
        local ok, scoped = pcall(lib.For, lib, PvPUA.name)
        if not ok or scoped == nil then return end
        logger = scoped
        DL.logger = logger
    end
    local ok, msg = pcall(string.format, fmt, ...)
    if not ok then msg = tostring(fmt) end
    pcall(logger.Buffer, logger, string.format("%8.1f %s", GetGameTimeMilliseconds() / 1000, msg))
end

-- Same, but only when `value` differs from the last value logged under `key` (state lines).
local function DLogChange(key, value, fmt, ...)
    if DL.last[key] == value then return end
    if not PvPUA:DebugLogEnabled() then return end -- not remembered either, so it is logged once enabled
    DL.last[key] = value
    DLog(fmt, ...)
end

function PvPUA:DebugLogClear()
    local lib = DLLib()
    if lib and lib.Clear then pcall(lib.Clear, lib) end
    DL.last = {}
end

-- Returns ok, reason (reason is one of the library's: "disabled", "no-url", "empty", "busy", ...).
function PvPUA:DebugLogExport()
    local lib = DLLib()
    if lib == nil then return false, "LibConsoleLogger not installed" end
    DLog("export requested (v%s)", tostring(self.version or "?"))
    local ok, result, reason = pcall(lib.Export, lib)
    if not ok then return false, tostring(result) end
    return result == true, reason
end

--------------------------------------------------
-- Kill Tally
--------------------------------------------------
-- Accumulates the game's "Battle Victories" kill markers into the list items they sit on, for as
-- long as each item has been on the list (same lifetime as the UA! timer). Kill markers carry no
-- id and every replacement marker restarts at 0, so we keep a positional snapshot and add deltas.
--
--   CyroUpdateLoop / EVENT_KILL_LOCATIONS_UPDATED
--     └─ KillTallyUpdate: read markers ─ match to last snapshot by position ─ credit deltas
--   UpdateItem (per item, every tick)
--     └─ KillTallySync: joined the list? ─ seed from markers already on the item
--                       left the list?   ─ drop the tally (a UA! timer reset alone does not)
--
-- Patch: kill-marker activity also puts a location ON the list. A marker that appears at, or whose
-- count rises at, a keep / outpost / town / resource / district stamps item.lastKillSeen; UpdateItem
-- treats the item as interesting for siegeTimeout after that stamp, exactly like a dropped UA! flag.
-- The first scan after a fresh init is a baseline (markers already on the map don't count as
-- activity); after /reloadui the saved snapshot + lastKillSeen are restored instead.
local KT_ALLIANCES = { ALLIANCE_DAGGERFALL_COVENANT, ALLIANCE_ALDMERI_DOMINION, ALLIANCE_EBONHEART_PACT }

-- Kill markers on bridges / milegates don't make them interesting (they're mid-field, not objectives).
local function KTKillsMakeInteresting(self, item)
    return item ~= nil and item.id ~= nil and self.state.destructibles[item.id] == nil
end

local function KTZeroCounts()
    local counts = {}
    for i = 1, #KT_ALLIANCES do counts[KT_ALLIANCES[i]] = 0 end
    return counts
end

-- Marker and keep coordinates are relative to the *current* map. Only sample on the AvA zone map so
-- the attach radius means the same thing every time (sub-maps / other zones are simply skipped).
local function KTOnAvAZoneMap()
    if not (GetMapContentType and GetMapType) then return true end
    local ok, result = pcall(function()
        return GetMapContentType() == MAP_CONTENT_AVA and GetMapType() == MAPTYPE_ZONE
    end)
    return ok and result == true
end

function PvPUA:KillTallyEnabled()
    return self.savedVariables == nil or self.savedVariables.showKillTally ~= false
end

function PvPUA:KillTallyResetState()
    self.killTally = { snapshot = {}, positions = nil, positionsMapId = nil, pending = nil, baselined = false,
                       -- Kill feed (chat) working state, see "Kill Feed" below.
                       chat = { seen = {}, pending = {}, recent = {}, byName = nil, unresolved = {} } }
end

--------------------------------------------------
-- Kill Tally persistence (survive /reloadui mid-siege)
--------------------------------------------------
-- Every update writes a compact copy of the marker snapshot and the live tallies to SavedVars
-- (keyed by campaign). InitState restores it if it's the same campaign and fresh enough; the UA!
-- timer (interestingSince) is restored alongside so the timer and the tally stay in step.
local KT_RESTORE_MAX_AGE_S = 15 * 60

local function KTItemById(self, keepId)
    local groups = { self.state.resources, self.state.keeps, self.state.outposts,
                     self.state.villages, self.state.destructibles, self.state.districts }
    for g = 1, #groups do
        local item = groups[g] and groups[g][keepId]
        if item then return item end
    end
    return nil
end

function PvPUA:KillTallySave()
    local sv = self.savedVariables
    if not sv then return end
    local snapshot = self.killTally.snapshot
    local markers = {}
    for i = 1, #snapshot do
        local m = snapshot[i]
        markers[i] = { x = m.x, y = m.y, c = m.counts, k = m.item and m.item.id or nil }
    end
    local tallies = {}
    local kills = {}
    local gameTime = GetGameTimeMilliseconds()
    local wallNow = GetTimeStamp()
    local groups = { self.state.resources, self.state.keeps, self.state.outposts,
                     self.state.villages, self.state.destructibles, self.state.districts }
    for g = 1, #groups do
        for keepId, item in pairs(groups[g] or {}) do
            local t = item.killTally
            if t and item.interestingSince then
                tallies[keepId] = { c = t.counts, wallSince = wallNow - (gameTime - item.interestingSince) / 1000 }
            end
            -- Patch: last kill-marker activity, as a wall-clock stamp so it survives a reload.
            if item.lastKillSeen and item.lastKillSeen + PvPUA.constants.siegeTimeout > gameTime then
                kills[keepId] = wallNow - (gameTime - item.lastKillSeen) / 1000
            end
        end
    end
    sv.killTallyState = {
        campaignId = GetCurrentCampaignId and GetCurrentCampaignId() or 0,
        savedAt    = wallNow,
        markers    = markers,
        tallies    = tallies,
        kills      = kills,
    }
end

-- Called from InitState after the item tables exist. Restores the snapshot (so the first update
-- only credits deltas) and stages the saved tallies in `pending`; KillTallySync consumes them on
-- the first tick for items that are back on the list, then KillTallyUpdate discards the rest.
function PvPUA:KillTallyRestore()
    local sv = self.savedVariables
    local saved = sv and sv.killTallyState
    if not saved then return end
    local wallNow = GetTimeStamp()
    local campaignId = GetCurrentCampaignId and GetCurrentCampaignId() or 0
    if saved.campaignId ~= campaignId or wallNow - (saved.savedAt or 0) > KT_RESTORE_MAX_AGE_S then
        sv.killTallyState = nil
        return
    end
    local snapshot = {}
    for i = 1, #(saved.markers or {}) do
        local m = saved.markers[i]
        local counts = KTZeroCounts()
        for a = 1, #KT_ALLIANCES do counts[KT_ALLIANCES[a]] = (m.c and m.c[KT_ALLIANCES[a]]) or 0 end
        snapshot[#snapshot + 1] = { x = m.x, y = m.y, counts = counts, item = m.k and KTItemById(self, m.k) or nil }
    end
    self.killTally.snapshot = snapshot
    self.killTally.baselined = true -- the restored snapshot is the baseline; new markers are real activity
    local gameTime = GetGameTimeMilliseconds()
    local pending = {}
    for keepId, t in pairs(saved.tallies or {}) do
        local counts = KTZeroCounts()
        for a = 1, #KT_ALLIANCES do counts[KT_ALLIANCES[a]] = (t.c and t.c[KT_ALLIANCES[a]]) or 0 end
        local sinceGame = gameTime - math.max(0, wallNow - (t.wallSince or wallNow)) * 1000
        pending[keepId] = { counts = counts, since = sinceGame }
    end
    self.killTally.pending = pending
    -- Patch: put the kill-activity stamps straight back on the items so a kill-only entry comes
    -- back after a reload (UpdateItem reads lastKillSeen on the first tick).
    for keepId, wallLast in pairs(saved.kills or {}) do
        local item = KTItemById(self, keepId)
        if item then
            item.lastKillSeen = gameTime - math.max(0, wallNow - wallLast) * 1000
        end
    end
end

-- Normalized map positions of every tracked keep-type item, cached per map id.
function PvPUA:KillTallyPositions()
    local kt = self.killTally
    local mapId = GetCurrentMapId and GetCurrentMapId() or 0
    if kt.positions and kt.positionsMapId == mapId then return kt.positions end
    local positions = {}
    local groups = { self.state.resources, self.state.keeps, self.state.outposts,
                     self.state.villages, self.state.destructibles, self.state.districts }
    for g = 1, #groups do
        for keepId, item in pairs(groups[g] or {}) do
            local _, nx, ny = GetKeepPinInfo(keepId, BGQUERY_LOCAL)
            if nx and ny and not (nx == 0 and ny == 0) then
                positions[#positions + 1] = { x = nx, y = ny, item = item }
            end
        end
    end
    kt.positions = positions
    kt.positionsMapId = mapId
    return positions
end

function PvPUA:KillTallyNearestItem(x, y)
    local best, bestDist
    local positions = self:KillTallyPositions()
    local maxDist = PvPUA.constants.killAttachRadius
    for i = 1, #positions do
        local p = positions[i]
        local dist = zo_distance(x, y, p.x, p.y)
        if dist <= maxDist and (bestDist == nil or dist < bestDist) then
            best, bestDist = p.item, dist
        end
    end
    return best
end

local function KTReadMarkers()
    local markers = {}
    local n = (GetNumKillLocations and GetKillLocationPinInfo and GetNumKillLocationAllianceKills)
              and GetNumKillLocations() or 0
    for i = 1, n do
        local pinType, nx, ny = GetKillLocationPinInfo(i)
        if pinType ~= MAP_PIN_TYPE_INVALID and nx and ny and not (nx == 0 and ny == 0) then
            local counts = KTZeroCounts()
            for a = 1, #KT_ALLIANCES do
                local alliance = KT_ALLIANCES[a]
                counts[alliance] = GetNumKillLocationAllianceKills(i, alliance) or 0
            end
            markers[#markers + 1] = { x = nx, y = ny, counts = counts }
        end
    end
    return markers
end

-- Closest unconsumed marker from the previous snapshot within the match radius, or nil.
local function KTFindPrevious(previous, marker)
    local best, bestDist
    local maxDist = PvPUA.constants.killMatchRadius
    for i = 1, #previous do
        local p = previous[i]
        if not p.consumed then
            local dist = zo_distance(marker.x, marker.y, p.x, p.y)
            if dist <= maxDist and (bestDist == nil or dist < bestDist) then
                best, bestDist = p, dist
            end
        end
    end
    if best then best.consumed = true end
    return best
end

--------------------------------------------------
-- Kill Feed (chat)
--------------------------------------------------
-- EVENT_PVP_KILL_FEED_DEATH is the "X defeated Y near Z" chat line. It fires for every kill near
-- the player (and for kills at battle markers), so it sees fights the markers never show: a single
-- kill puts Z on the list (same siegeTimeout linger as a marker) and counts toward Z's tally right
-- away. Locations are matched by name, so "Chalman Keep" / "Chalman Farm" / "Chalman Mine" are the
-- distinct items they already are; a line with no recognisable name falls back to the item nearest
-- the player, if one is within killAttachRadius.
--
-- The same kill usually reaches us twice - here, and a moment later as a marker count going up -
-- so the tally must not count it both times:
--   chat first:   the kill is held as "pending" on its item (per alliance) for chatKillReconcileMs;
--                 the next marker delta for that alliance at that item consumes pending kills
--                 before anything is credited (KTChatAbsorb).
--   marker first: a marker delta younger than chatKillMarkerLeadMs is remembered per item/alliance
--                 and a chat kill that lands inside that window is assumed to be in it already.
--   both sources: the game raises the event once per source (local / kill-location) for the same
--                 killer+victim; the pair is deduped for chatKillDedupeMs like its own chat handler.
-- The "interesting" stamp itself (lastKillSeen) is just a time, so it can't double count.
--
--   EVENT_PVP_KILL_FEED_DEATH
--     └─ KillFeedOnDeath: dedupe pair ─ resolve item ─ lastKillSeen ─ tally +1 (unless marker led) ─ pending +1
--   KillTallyUpdate (marker delta at an item)
--     └─ KTChatAbsorb: delta -= pending chat kills ─ remember the rest as a recent marker delta
local function KTNormalizeName(name)
    if type(name) ~= "string" or name == "" then return "" end
    local s = zo_strformat("<<1>>", name)
    s = s:lower()
    s = s:gsub("^%s+", "")
    s = s:gsub("[%s%.]+$", "")
    return s
end

-- raw GetKeepName(id) and the adjusted item.name of every keep-type item -> item. Built once per
-- InitState (KillTallyResetState clears it). Bridges / milegates are left out on purpose.
local function KTChatNameIndex(self)
    local chat = self.killTally.chat
    if chat.byName then return chat.byName end
    local exact, raw = {}, {}
    local groups = { self.state.resources, self.state.keeps, self.state.outposts,
                     self.state.villages, self.state.districts }
    for g = 1, #groups do
        for keepId, item in pairs(groups[g] or {}) do
            local rawName = KTNormalizeName(GetKeepName and GetKeepName(keepId) or nil)
            if rawName ~= "" then
                exact[rawName] = item
                raw[#raw + 1] = { name = rawName, item = item }
            end
            local shortName = KTNormalizeName(item.name)
            if shortName ~= "" and exact[shortName] == nil then exact[shortName] = item end
        end
    end
    chat.byName = { exact = exact, raw = raw }
    return chat.byName
end

-- "Chalman Keep" -> the Chalman keep item; "Chalman Farm" -> its farm. Exact match on the raw or
-- shortened name first, then the longest raw name contained in the string ("near Chalman Farm").
local function KTChatResolveByName(self, killLocation)
    local wanted = KTNormalizeName(killLocation)
    if wanted == "" then return nil end
    local index = KTChatNameIndex(self)
    local item = index.exact[wanted]
    if item then return item end
    local best, bestLen = nil, 0
    for i = 1, #index.raw do
        local entry = index.raw[i]
        if #entry.name > bestLen and wanted:find(entry.name, 1, true) then
            best, bestLen = entry.item, #entry.name
        end
    end
    return best
end

-- Nearest keep-type item to the player, if close. Only meaningful on the AvA zone map (the
-- player position is relative to the current map, same caveat as the markers).
local function KTChatResolveByPlayer(self)
    if not GetMapPlayerPosition or not KTOnAvAZoneMap() then return nil end
    local ok, x, y = pcall(GetMapPlayerPosition, "player")
    if not ok or type(x) ~= "number" or type(y) ~= "number" or (x == 0 and y == 0) then return nil end
    return self:KillTallyNearestItem(x, y)
end

-- Chat kills waiting for the marker that will carry them: pending[itemId][alliance] = { t, t, ... }
local function KTChatPendingList(chat, itemId, alliance, create)
    local byItem = chat.pending[itemId]
    if byItem == nil then
        if not create then return nil end
        byItem = {}
        chat.pending[itemId] = byItem
    end
    local list = byItem[alliance]
    if list == nil and create then
        list = {}
        byItem[alliance] = list
    end
    return list
end

-- Called from KillTallyUpdate for every marker delta: returns the part of the delta that is NOT
-- already in the tally as a chat kill, and remembers what was credited for the marker-first case.
local function KTChatAbsorb(self, item, alliance, delta, gameTime)
    local chat = self.killTally.chat
    if delta <= 0 or item == nil or item.id == nil then return delta end
    local list = KTChatPendingList(chat, item.id, alliance, false)
    if list then
        local maxAge = PvPUA.constants.chatKillReconcileMs
        -- drop expired (oldest first; the list is in arrival order)
        while #list > 0 and gameTime - list[1] > maxAge do table.remove(list, 1) end
        while delta > 0 and #list > 0 do
            table.remove(list, 1)
            delta = delta - 1
        end
    end
    if delta > 0 then
        local recent = chat.recent[item.id]
        if recent == nil then
            recent = {}
            chat.recent[item.id] = recent
        end
        recent[alliance] = { t = gameTime, n = delta }
    end
    return delta
end

-- Make sure an item has a tally to add to, the same way KillTallySync would on the next tick
-- (resume a saved one after /reloadui, else seed from the markers already sitting on it).
local function KTEnsureTally(self, item)
    if item.killTally ~= nil then return end
    local pending = self.killTally.pending
    local saved = pending and item.id and pending[item.id]
    if saved then
        pending[item.id] = nil
        item.interestingSince = saved.since
        item.killTally = { counts = saved.counts, dirty = true }
        return
    end
    self:KillTallySeed(item)
end

function PvPUA:KillFeedOnDeath(killLocation, killerDisplayName, killerCharacterName, killerAlliance,
                               victimDisplayName, victimCharacterName)
    -- Debug log: one line per event, "KF <where> <killer>(<alliance>) > <victim>: <outcome>".
    -- Built only while logging, so a big fight's kill feed costs no string garbage with the log off.
    local kfHead = ""
    if self:DebugLogEnabled() then
        kfHead = string.format('KF "%s" %s(%s) > %s:', tostring(killLocation), tostring(killerDisplayName or killerCharacterName),
                               DLAlliance(killerAlliance), tostring(victimDisplayName or victimCharacterName))
    end
    if not self.initializedItems or self.killTally == nil then
        DLog("%s ignored, items not initialized", kfHead)
        return
    end
    local chat = self.killTally.chat
    local gameTime = GetGameTimeMilliseconds()

    -- One kill, two sources (local + kill location): keep the first.
    local killerKey = (killerDisplayName ~= nil and killerDisplayName ~= "") and killerDisplayName or (killerCharacterName or "?")
    local victimKey = (victimDisplayName ~= nil and victimDisplayName ~= "") and victimDisplayName or (victimCharacterName or "?")
    local pairKey = killerKey .. "___" .. victimKey
    local dedupeMs = PvPUA.constants.chatKillDedupeMs
    for key, t in pairs(chat.seen) do
        if gameTime - t > dedupeMs then chat.seen[key] = nil end
    end
    if chat.seen[pairKey] ~= nil then
        DLog("%s dup (%.1fs after first)", kfHead, (gameTime - chat.seen[pairKey]) / 1000)
        return
    end
    chat.seen[pairKey] = gameTime

    local how = "name"
    local item = KTChatResolveByName(self, killLocation)
    if item == nil then
        how = "player"
        item = KTChatResolveByPlayer(self)
        if item == nil then
            local u = chat.unresolved
            u[#u + 1] = killLocation or ""
            if #u > 20 then table.remove(u, 1) end
            local okPos, px, py = pcall(GetMapPlayerPosition, "player")
            DLog("%s unresolved (no name match; player %s,%s avaMap=%s)", kfHead,
                 okPos and tostring(px) or "?", okPos and tostring(py) or "?", tostring(KTOnAvAZoneMap()))
            return
        end
    end
    if not KTKillsMakeInteresting(self, item) then
        DLog("%s -> %s by %s, not an objective (bridge/milegate), ignored", kfHead, DLItemName(item), how)
        return
    end

    -- The place is interesting now; UpdateItem lists it for siegeTimeout.
    item.lastKillSeen = gameTime

    -- Tally the kill for the killer's alliance unless a marker delta just carried it.
    local known = false
    for a = 1, #KT_ALLIANCES do if KT_ALLIANCES[a] == killerAlliance then known = true end end
    if not known then
        DLog("%s -> %s by %s, listed, alliance %s unknown so not tallied", kfHead, DLItemName(item), how, tostring(killerAlliance))
        return
    end
    local recent = chat.recent[item.id] and chat.recent[item.id][killerAlliance]
    if recent and recent.n > 0 and gameTime - recent.t <= PvPUA.constants.chatKillMarkerLeadMs then
        recent.n = recent.n - 1
        DLog("%s -> %s by %s, listed, already in a marker delta %.1fs ago (not tallied)", kfHead, DLItemName(item), how,
             (gameTime - recent.t) / 1000)
        return
    end
    KTEnsureTally(self, item)
    local tally = item.killTally
    if tally then
        tally.counts[killerAlliance] = (tally.counts[killerAlliance] or 0) + 1
        tally.dirty = true
    end
    local list = KTChatPendingList(chat, item.id, killerAlliance, true)
    -- Drop expired entries here too: KTChatAbsorb only runs when a marker delta lands on this item,
    -- so without this a long fight with no marker would grow the list for the whole session.
    local maxAge = PvPUA.constants.chatKillReconcileMs
    while #list > 0 and gameTime - list[1] > maxAge do table.remove(list, 1) end
    list[#list + 1] = gameTime
    DLog("%s -> %s by %s, listed, tally %s=%s (already on list: %s%s)", kfHead, DLItemName(item), how, DLAlliance(killerAlliance),
         tally and tostring(tally.counts[killerAlliance]) or "?", item.interestingSince ~= nil and "yes" or "no",
         tally and "" or "; NO TALLY TABLE")
end

-- Diff the live kill markers against the last snapshot and credit the deltas to flagged items.
-- A count that went *down* means the game replaced the marker, so the new marker's whole count
-- is fresh kills. Markers that vanished were already counted. Markers on items that aren't on the
-- list are ignored here; they get picked up by KillTallySeed when the item flags.
function PvPUA:KillTallyUpdate()
    -- Patch: always scan (the kill-activity list entries don't depend on the tally column);
    -- the Kill Tally toggle only hides the column (KillTallyText).
    if not self.initializedItems then
        DLogChange("ktSkip", "init", "KT skip: items not initialized")
        return
    end
    if not KTOnAvAZoneMap() then
        local okC, content = pcall(function() return GetMapContentType() end)
        local okT, mapType = pcall(function() return GetMapType() end)
        DLogChange("ktSkip", "map", "KT skip: current map is not the AvA zone map (content=%s type=%s); markers not read until it is",
                   okC and tostring(content) or "?", okT and tostring(mapType) or "?")
        return
    end
    DLogChange("ktSkip", false, "KT scanning (AvA zone map)")
    local kt = self.killTally
    local previous = kt.snapshot
    local markers = KTReadMarkers()
    local gameTime = GetGameTimeMilliseconds()
    -- Patch: markers already on the map at a fresh init are history, not activity.
    local countAsActivity = kt.baselined
    local logging = self:DebugLogEnabled()
    if DL.last.ktMarkers ~= #markers then -- (pre-check keeps the per-tick cost at one comparison when unchanged)
        DLogChange("ktMarkers", #markers, "KT markers: %d (api n=%s, events so far %d)%s", #markers,
                   tostring(GetNumKillLocations and GetNumKillLocations() or "n/a"), kt.eventCount or 0,
                   countAsActivity and "" or " - BASELINE, not activity")
    end
    for i = 1, #markers do
        local m = markers[i]
        local prev = KTFindPrevious(previous, m)
        m.item = (prev and prev.item) or self:KillTallyNearestItem(m.x, m.y)
        local item = m.item
        local tally = item and item.killTally
        local activity = prev == nil -- a brand-new marker is activity even at 0 kills
        local deltaText = nil
        for a = 1, #KT_ALLIANCES do
            local alliance = KT_ALLIANCES[a]
            local now = m.counts[alliance]
            local delta = prev and (now - (prev.counts[alliance] or 0)) or now
            if delta < 0 then delta = now end
            if delta > 0 then
                activity = true
                local rawDelta = delta
                -- Patch: chat kills already in the tally are not counted a second time.
                if countAsActivity then delta = KTChatAbsorb(self, item, alliance, delta, gameTime) end
                if delta > 0 and tally and item.interestingSince ~= nil then
                    tally.counts[alliance] = tally.counts[alliance] + delta
                    tally.dirty = true
                end
                if logging then
                    deltaText = (deltaText and (deltaText .. " ") or "") .. string.format("%s+%d%s", DLAlliance(alliance), rawDelta,
                                rawDelta ~= delta and string.format("(%d chat-absorbed)", rawDelta - delta) or "")
                end
            end
        end
        if activity and logging then
            DLog("KT marker %d at %.3f,%.3f -> %s: %s%s%s", i, m.x, m.y, DLItemName(item),
                 prev == nil and "NEW " or "", deltaText or "no count change",
                 (not countAsActivity) and " [baseline]" or (item == nil and " [no objective within attach radius]"
                 or (not KTKillsMakeInteresting(self, item)) and " [bridge/milegate, not listed]"
                 or string.format(" [listed; tally %s]", tally and (item.interestingSince ~= nil) and "credited" or "none yet")))
        end
        if activity and countAsActivity and KTKillsMakeInteresting(self, item) then
            item.lastKillSeen = gameTime
        end
    end
    for i = 1, logging and #previous or 0 do
        local p = previous[i]
        if not p.consumed then DLog("KT marker gone at %.3f,%.3f (%s)", p.x, p.y, DLItemName(p.item)) end
    end
    kt.snapshot = markers
    kt.baselined = true
    kt.lastUpdateMs = gameTime
    kt.pending = nil -- anything not reclaimed on the first tick is stale
    self:KillTallySave()
end

-- Event handler: coalesce bursts; the 1s tick is the backstop anyway.
local KT_EVENT_MIN_INTERVAL_MS = 250
function PvPUA:KillTallyOnEvent()
    if self.killTally then self.killTally.eventCount = (self.killTally.eventCount or 0) + 1 end
    local last = self.killTally and self.killTally.lastUpdateMs or 0
    if GetGameTimeMilliseconds() - last < KT_EVENT_MIN_INTERVAL_MS then return end
    self:KillTallyUpdate()
end

-- Start an item's tally when it joins the list: zero it, then count in every marker already
-- attached to the item so a fight that was running before the flag went up is included.
function PvPUA:KillTallySeed(item)
    local tally = { counts = KTZeroCounts(), dirty = true }
    local snapshot = self.killTally.snapshot
    for i = 1, #snapshot do
        local m = snapshot[i]
        if m.item == nil then m.item = self:KillTallyNearestItem(m.x, m.y) end
        if m.item == item then
            for a = 1, #KT_ALLIANCES do
                local alliance = KT_ALLIANCES[a]
                tally.counts[alliance] = tally.counts[alliance] + (m.counts[alliance] or 0)
            end
        end
    end
    item.killTally = tally
end

-- Called for every item each tick. The tally lives exactly as long as the item is on the list
-- (interestingSince ~= nil); it does NOT restart when upstream resets the UA! timer on a reflag.
function PvPUA:KillTallySync(item)
    if item.interestingSince == nil then
        item.killTally = nil
        return
    end
    if item.killTally ~= nil then return end
    -- Back on the list right after a reload: resume the saved tally and timer instead of
    -- reseeding (the restored snapshot already accounts for the markers on this item).
    local pending = self.killTally.pending
    local saved = pending and item.id and pending[item.id]
    if saved then
        pending[item.id] = nil
        item.interestingSince = saved.since
        item.killTally = { counts = saved.counts, dirty = true }
        return
    end
    self:KillTallySeed(item)
end

function PvPUA:KillTallyText(item)
    if not self:KillTallyEnabled() then return "" end
    local tally = item and item.killTally
    if not tally or item.isScrollCarrier then return "" end
    if tally.text and not tally.dirty then return tally.text end
    -- Only alliances with kills; a 0 is noise.
    local parts = {}
    for a = 1, #KT_ALLIANCES do
        local alliance = KT_ALLIANCES[a]
        local n = tally.counts[alliance] or 0
        if n > 0 then
            local c = GetColorForAlliance(alliance)
            parts[#parts + 1] = ColorText(tostring(n), c.r, c.g, c.b)
        end
    end
    tally.text = table.concat(parts, " ")
    tally.dirty = false
    return tally.text
end

function PvPUA:UpdateItem(items, gameTime)
    local itemsOfInterest = {}
    for key, item in pairs(items) do
        local itemOfInterest = false
        local wasListed = item.interestingSince ~= nil -- Patch: for the debug log's join/leave lines
        local previousOwningAlliance = item.owningAlliance
        item.owningAlliance = GetKeepAlliance(key, BGQUERY_LOCAL)
        local previousAttackState = item.isUnderAttack
        item.isUnderAttack = GetKeepUnderAttack(key, BGQUERY_LOCAL)
        item.underAttackFor = 0

        if item.owningAlliance ~= previousOwningAlliance and self.state.destructibles[key] == nil then
            itemOfInterest = true
            if item.interestingSince == nil then item.interestingSince = gameTime end
            item.underAttackFor = gameTime - item.interestingSince
            if item.objectives ~= nil then
                for i = 1, #item.objectives do
                    item.objectives[i].state = 100
                    item.objectives[i].holdingAlliance = item.owningAlliance
                end
            end
            item.flipsAt = nil
        end
        if previousAttackState == false and item.isUnderAttack == true then
            if item.attackStatusLostAt ~= 0 and item.attackStatusLostAt + PvPUA.constants.siegeTimeout < gameTime then
                item.interestingSince = gameTime
            end
            local playerAlliance = GetUnitAlliance("player")
            if item.name ~= nil and self.state.keeps[key] ~= nil
               and PvPUA.homeKeepIds[key] == playerAlliance then
                FireKeepUA(key, item.name, item.owningAlliance)
            end
        elseif previousAttackState == true and item.isUnderAttack == false then
            item.attackStatusLostAt = gameTime
        end
        if item.isUnderAttack == true then
            itemOfInterest = true
            if item.interestingSince == nil then item.interestingSince = gameTime end
            item.underAttackFor = gameTime - item.interestingSince
        else
            if item.attackStatusLostAt ~= 0 and item.attackStatusLostAt + PvPUA.constants.siegeTimeout > gameTime then
                itemOfInterest = true
                if item.interestingSince == nil then item.interestingSince = gameTime end
                item.underAttackFor = gameTime - item.interestingSince
            end
        end
        if self.state.destructibles[key] == nil and item.siegeWeapons ~= nil then
            item.siegeWeapons.AD = GetNumSieges(key, BGQUERY_LOCAL, ALLIANCE_ALDMERI_DOMINION)
            item.siegeWeapons.DC = GetNumSieges(key, BGQUERY_LOCAL, ALLIANCE_DAGGERFALL_COVENANT)
            item.siegeWeapons.EP = GetNumSieges(key, BGQUERY_LOCAL, ALLIANCE_EBONHEART_PACT)
            if item.siegeWeapons.AD > 0 or item.siegeWeapons.DC > 0 or item.siegeWeapons.EP > 0 then
                itemOfInterest = true
                if item.interestingSince == nil then item.interestingSince = gameTime end
                item.underAttackFor = gameTime - item.interestingSince
                item.lastSiegeWeaponSeen = gameTime
            elseif item.lastSiegeWeaponSeen ~= nil and item.lastSiegeWeaponSeen + PvPUA.constants.siegeTimeout > gameTime then
                itemOfInterest = true
                if item.interestingSince == nil then item.interestingSince = gameTime end
                item.underAttackFor = gameTime - item.interestingSince
            else
                item.lastSiegeWeaponSeen = nil
            end
        end
        -- Patch: recent kill-marker activity (see "Kill Tally") keeps a keep / outpost / town /
        -- resource / district on the list for siegeTimeout, same as a dropped UA! flag.
        if item.lastKillSeen ~= nil then
            if item.lastKillSeen + PvPUA.constants.siegeTimeout > gameTime then
                itemOfInterest = true
                if item.interestingSince == nil then item.interestingSince = gameTime end
                item.underAttackFor = gameTime - item.interestingSince
            else
                item.lastKillSeen = nil
            end
        end
        if item.keepType == KEEPTYPE_BRIDGE or item.keepType == KEEPTYPE_MILEGATE then
            item.isPassable = IsKeepPassable(key, BGQUERY_LOCAL)
            item.directionalAccess = GetKeepDirectionalAccess(key, BGQUERY_LOCAL)
        end
        if itemOfInterest == true then
            local sv = PvPUA.savedVariables
            local hidden = false
            if sv then
                if item.keepType == KEEPTYPE_MILEGATE and sv.showMilegates == false then hidden = true
                elseif item.keepType == KEEPTYPE_BRIDGE and sv.showBridges == false then hidden = true
                elseif item.keepType == KEEPTYPE_TOWN and sv.showTowns == false then hidden = true
                elseif item.keepType == KEEPTYPE_RESOURCE and sv.showResources == false then hidden = true
                end
            end
            if hidden then
                item.interestingSince = nil
            else
                table.insert(itemsOfInterest, item)
            end
        else
            item.interestingSince = nil
        end
        self:KillTallySync(item)
        -- Debug log: list membership changes only (never per tick), with why it is / was on the list.
        local isListed = item.interestingSince ~= nil
        if isListed ~= wasListed then
            if isListed then
                local why = {}
                if item.isUnderAttack then why[#why + 1] = "UA" end
                if item.owningAlliance ~= previousOwningAlliance then why[#why + 1] = "flipped" end
                if item.siegeWeapons and ((item.siegeWeapons.AD or 0) + (item.siegeWeapons.DC or 0) + (item.siegeWeapons.EP or 0)) > 0 then
                    why[#why + 1] = "siege"
                end
                if item.lastKillSeen ~= nil then why[#why + 1] = "kills" end
                local t = item.killTally
                DLog("list + %s (%s) tally DC=%d AD=%d EP=%d", DLItemName(item), #why > 0 and table.concat(why, ",") or "?",
                     t and t.counts[ALLIANCE_DAGGERFALL_COVENANT] or 0, t and t.counts[ALLIANCE_ALDMERI_DOMINION] or 0,
                     t and t.counts[ALLIANCE_EBONHEART_PACT] or 0)
            else
                DLog("list - %s%s", DLItemName(item), itemOfInterest == true and " (hidden by Show List setting)" or "")
            end
        end
    end
    return itemsOfInterest
end

--------------------------------------------------
-- Sort
--------------------------------------------------
local function SortItemsOfInterest(itemA, itemB)
    if itemA == nil or itemB == nil then return true end
    if itemA.isScrollCarrier and not itemB.isScrollCarrier then return true end
    if itemB.isScrollCarrier and not itemA.isScrollCarrier then return false end
    if itemA.isScrollCarrier and itemB.isScrollCarrier then
        if itemA.isVolendrung and not itemB.isVolendrung then return true end
        if itemB.isVolendrung and not itemA.isVolendrung then return false end
        return (itemA.interestingSince or 0) < (itemB.interestingSince or 0)
    end
    local playerAlliance = GetUnitAlliance("player")
    local aFriendly = GetKeepAlliance(itemA.id, BGQUERY_LOCAL) == playerAlliance
    local bFriendly = GetKeepAlliance(itemB.id, BGQUERY_LOCAL) == playerAlliance
    if aFriendly and not bFriendly then return true end
    if not aFriendly and bFriendly then return false end
    if not aFriendly and not bFriendly then
        local aSiege = itemA.siegeWeapons and (
            (playerAlliance == ALLIANCE_ALDMERI_DOMINION    and (itemA.siegeWeapons.AD or 0) > 0) or
            (playerAlliance == ALLIANCE_DAGGERFALL_COVENANT and (itemA.siegeWeapons.DC or 0) > 0) or
            (playerAlliance == ALLIANCE_EBONHEART_PACT      and (itemA.siegeWeapons.EP or 0) > 0)
        )
        local bSiege = itemB.siegeWeapons and (
            (playerAlliance == ALLIANCE_ALDMERI_DOMINION    and (itemB.siegeWeapons.AD or 0) > 0) or
            (playerAlliance == ALLIANCE_DAGGERFALL_COVENANT and (itemB.siegeWeapons.DC or 0) > 0) or
            (playerAlliance == ALLIANCE_EBONHEART_PACT      and (itemB.siegeWeapons.EP or 0) > 0)
        )
        if aSiege and not bSiege then return true end
        if not aSiege and bSiege then return false end
    end
    if itemA.interestingSince == nil or itemB.interestingSince == nil then return true end
    return itemA.interestingSince < itemB.interestingSince
end

--------------------------------------------------
-- Texture Helper
--------------------------------------------------
local function GetTextureAndOffsetForItem(keepType, rType, isPassable)
    if keepType == KEEPTYPE_KEEP then
        return PvPUA.constants.textures.KEEP, 3
    elseif keepType == KEEPTYPE_OUTPOST then
        return PvPUA.constants.textures.OUTPOST, 3
    elseif keepType == KEEPTYPE_RESOURCE then
        if rType == PvPUA.constants.resourceType.FARM then return PvPUA.constants.textures.RESOURCE_FARM, -1
        elseif rType == PvPUA.constants.resourceType.MINE then return PvPUA.constants.textures.RESOURCE_MINE, -1
        elseif rType == PvPUA.constants.resourceType.LUMBER then return PvPUA.constants.textures.RESOURCE_LUMBER, -1
        end
    elseif keepType == KEEPTYPE_TOWN then
        return PvPUA.constants.textures.VILLAGE, 2
    elseif keepType == KEEPTYPE_IMPERIAL_CITY_DISTRICT then
        return PvPUA.constants.textures.DISTRICT, 2
    elseif keepType == KEEPTYPE_BRIDGE then
        if isPassable == true then return PvPUA.constants.textures.BRIDGE_PASSABLE, -2
        else return PvPUA.constants.textures.BRIDGE_NOT_PASSABLE, -2 end
    elseif keepType == KEEPTYPE_MILEGATE then
        if isPassable == true then return PvPUA.constants.textures.MILEGATE_PASSABLE, -2
        else return PvPUA.constants.textures.MILEGATE_NOT_PASSABLE, -2 end
    end
    return "", 0
end

--------------------------------------------------
-- Format Time
--------------------------------------------------
local function FormatUnderAttackTime(underAttackFor)
    if underAttackFor ~= nil or underAttackFor == 0 then
        local minutes = string.format("%d", underAttackFor / 60)
        local seconds = underAttackFor - minutes * 60
        if seconds > 0 and seconds < 10 then
            return string.format("%d:0%d", minutes, seconds)
        elseif seconds == 0 then
            return string.format("%d:00", minutes)
        else
            return string.format("%d:%d", minutes, seconds)
        end
    else
        return ""
    end
end

local function SetSiegeWeapons(control, weapons)
    if weapons ~= nil and weapons > 0 then
        control:SetText(weapons)
    else
        control:SetText("")
    end
end

--------------------------------------------------
-- Create Progress Bar
--------------------------------------------------
local function CreateProgressBar(parent)
    local control = wm:CreateControl(nil, parent, CT_CONTROL)
    control:SetDimensions(PvPUA.config.flagWidth, PvPUA.config.flagHeight)
    control:SetHidden(true)

    control.backdrop = wm:CreateControl(nil, control, CT_BACKDROP)
    control.backdrop:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
    control.backdrop:SetDimensions(PvPUA.config.flagWidth, PvPUA.config.flagHeight)
    control.backdrop:SetEdgeColor(0, 0, 0, 1)
    control.backdrop:SetCenterColor(PvPUA.config.flagBackdropColor.r, PvPUA.config.flagBackdropColor.g, PvPUA.config.flagBackdropColor.b, 1)

    control.progress = wm:CreateControl(nil, control, CT_STATUSBAR)
    control.progress:SetAnchor(TOPLEFT, control, TOPLEFT, 1, 1)
    control.progress:SetDimensions(PvPUA.config.flagWidth - 2, PvPUA.config.flagHeight - 2)
    control.progress:SetMinMax(0, 100)
    control.progress:SetValue(0)
    return control
end

--------------------------------------------------
-- Create Entry Control
--------------------------------------------------
local function CreateEntryControl(parent)
    local controlFont = PvPUA:GetFont()

    local control = wm:CreateControl(nil, parent, CT_CONTROL)
    control:SetDimensions(PvPUA.config.width, PvPUA.config.entryHeight)
    control:SetHidden(true)

    control.backdrop = wm:CreateControl(nil, control, CT_BACKDROP)
    control.backdrop:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
    control.backdrop:SetDimensions(PvPUA.config.width, PvPUA.config.entryHeight)
    control.backdrop:SetDrawLayer(0)

    control.uaOutline = wm:CreateControl(nil, control, CT_TEXTURE)
    control.uaOutline:SetAnchor(TOPLEFT, control, TOPLEFT, -5 - 2, -5 - 2)
    control.uaOutline:SetDimensions(PvPUA.config.imageWidth + 10 + 4, PvPUA.config.entryHeight + 10 + 4)
    control.uaOutline:SetTexture("/esoui/art/mappins/ava_attackburst_64.dds")
    control.uaOutline:SetColor(0, 0, 0, 1)
    control.uaOutline:SetHidden(true)
    control.uaOutline:SetDrawLayer(0)

    control.uaImage = wm:CreateControl(nil, control, CT_TEXTURE)
    control.uaImage:SetAnchor(TOPLEFT, control, TOPLEFT, -5, -5)
    control.uaImage:SetDimensions(PvPUA.config.imageWidth + 10, PvPUA.config.entryHeight + 10)
    control.uaImage:SetTexture("/esoui/art/mappins/ava_attackburst_64.dds")
    control.uaImage:SetHidden(true)
    control.uaImage:SetDrawLayer(1)

    control.imageOutline = wm:CreateControl(nil, control, CT_TEXTURE)
    control.imageOutline:SetAnchor(TOPLEFT, control, TOPLEFT, -2 - 2, -2 - 2)
    control.imageOutline:SetDimensions(PvPUA.config.imageWidth + 4 + 4, PvPUA.config.entryHeight + 4 + 4)
    control.imageOutline:SetColor(0, 0, 0, 1)
    control.imageOutline:SetDrawLayer(1)
    control.imageOutline:SetHidden(not PvPUA.config.iconOutline)

    control.image = wm:CreateControl(nil, control, CT_TEXTURE)
    control.image:SetAnchor(TOPLEFT, control, TOPLEFT, -2, -2)
    control.image:SetDimensions(PvPUA.config.imageWidth + 4, PvPUA.config.entryHeight + 4)
    control.image:SetDrawLayer(2)

    control.scrollImage = wm:CreateControl(nil, control, CT_TEXTURE)
    control.scrollImage:SetDrawLayer(3)
    control.scrollImage:SetHidden(true)

    control.name = wm:CreateControl(nil, control, CT_LABEL)
    control.name:SetAnchor(TOPLEFT, control, TOPLEFT, PvPUA.config.imageWidth + 4, 0)
    control.name:SetDimensions(PvPUA.config.nameWidth, PvPUA.config.entryHeight)
    control.name:SetFont(controlFont)
    control.name:SetWrapMode(ELLIPSIS)
    control.name:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    control.name:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

    control.progress = wm:CreateControl(nil, control, CT_CONTROL)
    control.progress:SetAnchor(TOPLEFT, control, TOPLEFT, PvPUA.config.imageWidth + 4 + PvPUA.config.nameWidth, 0)
    control.progress:SetDimensions(PvPUA.config.flagWidth, PvPUA.config.entryHeight)
    control.progress.bar1 = CreateProgressBar(control.progress)
    control.progress.bar2 = CreateProgressBar(control.progress)
    control.progress.bar3 = CreateProgressBar(control.progress)

    local siegeOffset = PvPUA.config.imageWidth + 4 + PvPUA.config.nameWidth + PvPUA.config.flagWidth
    control.dcSiege = wm:CreateControl(nil, control, CT_LABEL)
    control.dcSiege:SetAnchor(TOPLEFT, control, TOPLEFT, siegeOffset, 0)
    control.dcSiege:SetDimensions(PvPUA.config.siegeWidth, PvPUA.config.entryHeight)
    control.dcSiege:SetFont(controlFont)
    control.dcSiege:SetWrapMode(ELLIPSIS)
    control.dcSiege:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    control.dcSiege:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    control.adSiege = wm:CreateControl(nil, control, CT_LABEL)
    control.adSiege:SetAnchor(TOPLEFT, control, TOPLEFT, siegeOffset + PvPUA.config.siegeWidth, 0)
    control.adSiege:SetDimensions(PvPUA.config.siegeWidth, PvPUA.config.entryHeight)
    control.adSiege:SetFont(controlFont)
    control.adSiege:SetWrapMode(ELLIPSIS)
    control.adSiege:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    control.adSiege:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    control.epSiege = wm:CreateControl(nil, control, CT_LABEL)
    control.epSiege:SetAnchor(TOPLEFT, control, TOPLEFT, siegeOffset + PvPUA.config.siegeWidth * 2, 0)
    control.epSiege:SetDimensions(PvPUA.config.siegeWidth, PvPUA.config.entryHeight)
    control.epSiege:SetFont(controlFont)
    control.epSiege:SetWrapMode(ELLIPSIS)
    control.epSiege:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    control.epSiege:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    control.flipStatus = wm:CreateControl(nil, control, CT_LABEL)
    control.flipStatus:SetAnchor(TOPLEFT, control, TOPLEFT, siegeOffset + PvPUA.config.siegeWidth * 3 + 10, 0)
    control.flipStatus:SetDimensions(PvPUA.config.flagFlipWidth, PvPUA.config.entryHeight)
    control.flipStatus:SetFont(controlFont)
    control.flipStatus:SetWrapMode(ELLIPSIS)
    control.flipStatus:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    control.flipStatus:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    control.underAttackFor = wm:CreateControl(nil, control, CT_LABEL)
    control.underAttackFor:SetAnchor(TOPRIGHT, control, TOPRIGHT, 0, 0)
    control.underAttackFor:SetDimensions(PvPUA.config.underAttackForWidth, PvPUA.config.entryHeight)
    control.underAttackFor:SetFont(controlFont)
    control.underAttackFor:SetWrapMode(ELLIPSIS)
    control.underAttackFor:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    control.underAttackFor:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    -- Kill tally column: "DC AD EP" battle-victory counts, left of the UA! timer.
    control.kills = wm:CreateControl(nil, control, CT_LABEL)
    control.kills:SetAnchor(TOPRIGHT, control, TOPRIGHT, -PvPUA.config.underAttackForWidth - 4, 0)
    control.kills:SetDimensions(PvPUA.config.killsWidth, PvPUA.config.entryHeight)
    control.kills:SetFont(controlFont)
    control.kills:SetWrapMode(ELLIPSIS)
    control.kills:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    control.kills:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    return control
end

--------------------------------------------------
-- Create UI
--------------------------------------------------
function PvPUA:CreateUI()
    self.controls.TLW = wm:CreateTopLevelWindow("PvPUA_TLW")
    self.controls.TLW:SetClampedToScreen(self.config.isClampedToScreen)
    self.controls.TLW:SetDimensions(self.config.width, self.config.height + self.config.entryHeight * 2 + 20)
    self.controls.TLW:SetDrawLayer(DL_BACKGROUND)
    self.controls.TLW:SetDrawTier(DT_LOW)
    self.controls.TLW:SetHidden(true)

    self:ApplyPosition()
    self:ApplyScale()

    self.controls.TLW.rootControl = wm:CreateControl(nil, self.controls.TLW, CT_CONTROL)
    local rootControl = self.controls.TLW.rootControl
    rootControl:SetDimensions(self.config.width, self.config.height)
    rootControl:SetAnchor(TOPLEFT, self.controls.TLW, TOPLEFT, 0, self:HeaderTop() + self.config.entryHeight * 2)

    self.state.visibleControls = {}
    for i = 1, 15 do
        local entry = CreateEntryControl(rootControl)
        entry:SetAnchor(TOPLEFT, rootControl, TOPLEFT, 0, self.config.entryHeight * (i - 1))
        entry:SetHidden(true)
        table.insert(self.state.visibleControls, entry)
    end
    zo_callLater(function()
        for i = 16, 30 do
            local entry = CreateEntryControl(rootControl)
            entry:SetAnchor(TOPLEFT, rootControl, TOPLEFT, 0, self.config.entryHeight * (i - 1))
            entry:SetHidden(true)
            table.insert(self.state.visibleControls, entry)
        end
    end, 100)

    self.controls.creditLabel = wm:CreateControl(nil, self.controls.TLW, CT_LABEL)
    self.controls.creditLabel:SetFont("EsoUI/Common/Fonts/univers67.otf|15|outline")
    self.controls.creditLabel:SetAnchor(TOPLEFT, self.controls.TLW, TOPLEFT, 0, 0)
    self.controls.creditLabel:SetDimensions(self.config.width, 20)
    self.controls.creditLabel.baseY = 0
    self.controls.creditLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.controls.creditLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.controls.creditLabel:SetText(CREDIT_STATES[0])
    self.controls.creditLabel:SetDrawLayer(2)
    self.controls.creditLabel:SetHidden(true)

    self.controls.infoBg = wm:CreateControl(nil, self.controls.TLW, CT_BACKDROP)
    self.controls.infoBg:SetAnchor(TOPLEFT, self.controls.TLW, TOPLEFT, 0, 20)
    self.controls.infoBg:SetDimensions(self.config.width, self.config.entryHeight)
    self.controls.infoBg.baseX, self.controls.infoBg.baseY = 0, 20
    self.controls.infoBg:SetCenterColor(0, 0, 0, self.config.backdropAlphaOdd)
    self.controls.infoBg:SetEdgeColor(0, 0, 0, 0)
    self.controls.infoBg:SetDrawLayer(0)
    self.controls.infoBg:SetHidden(true)

    local infoH      = self.config.entryHeight
    local rankBase   = math.max(28, infoH - 2)
    local rankIconSz = math.floor(rankBase * self.config.iconScale.rank)
    local barPad     = 4
    local kbStart    = self.config.width - 130
    local gapEnd     = kbStart - barPad
    local rankX      = 0
    local barLeft    = rankX + rankBase + barPad
    local barW       = gapEnd - barLeft

    local barFontPx = self.config.barFontSize
    if not barFontPx or barFontPx <= 0 then
        barFontPx = math.max(10, math.floor(self.config.barHeight))
    end
    local barLabelFont = "EsoUI/Common/Fonts/FTN57.otf|" .. barFontPx .. "|outline"
    local barNudge = self.config.barTextNudge or 0

    local killFont = "EsoUI/Common/Fonts/FTN57.otf|" .. (self.config.kdFontSize or 20) .. "|outline"


    local rankGrow = math.floor((rankIconSz - rankBase) / 2)
    self.controls.infoRankIcon = wm:CreateControl(nil, self.controls.TLW, CT_TEXTURE)
    self.controls.infoRankIcon:SetAnchor(TOPLEFT, self.controls.TLW, TOPLEFT,
        rankX - rankGrow,
        20 + math.floor((infoH - rankBase) / 2) - rankGrow)
    self.controls.infoRankIcon.baseX = rankX - rankGrow
    self.controls.infoRankIcon.baseY = 20 + math.floor((infoH - rankBase) / 2) - rankGrow
    self.controls.infoRankIcon:SetDimensions(rankIconSz, rankIconSz)
    self.controls.infoRankIcon:SetDrawLayer(2)
    self.controls.infoRankIcon:SetHidden(true)

    local barH = self.config.barHeight
    self.controls.infoBarBg = wm:CreateControl(nil, self.controls.TLW, CT_BACKDROP)
    self.controls.infoBarBg:SetAnchor(TOPLEFT, self.controls.TLW, TOPLEFT, barLeft, 20 + math.floor((infoH - barH) / 2))
    self.controls.infoBarBg:SetDimensions(barW, barH)
    self.controls.infoBarBg.baseX = barLeft
    self.controls.infoBarBg.baseY = 20 + math.floor((infoH - barH) / 2)
    self.controls.infoBarBg:SetCenterColor(0.1, 0.1, 0.1, 0.9)
    self.controls.infoBarBg:SetEdgeColor(0, 0, 0, 1)
    self.controls.infoBarBg:SetDrawLayer(1)
    self.controls.infoBarBg:SetHidden(true)

    self.controls.infoBar = wm:CreateControl(nil, self.controls.TLW, CT_STATUSBAR)
    self.controls.infoBar:SetAnchor(TOPLEFT, self.controls.TLW, TOPLEFT, barLeft + 1, 20 + math.floor((infoH - barH) / 2) + 1)
    self.controls.infoBar:SetDimensions(barW - 2, barH - 2)
    self.controls.infoBar.baseX = barLeft + 1
    self.controls.infoBar.baseY = 20 + math.floor((infoH - barH) / 2) + 1
    self.controls.infoBar:SetMinMax(0, 100)
    self.controls.infoBar:SetValue(0)
    self.controls.infoBar:SetDrawLayer(2)
    self.controls.infoBar:SetHidden(true)

    self.controls.infoRankNum = wm:CreateControl(nil, self.controls.TLW, CT_LABEL)
    self.controls.infoRankNum:SetFont(barLabelFont)
    self.controls.infoRankNum:SetAnchor(LEFT, self.controls.infoBarBg, LEFT, 3, barNudge)
    self.controls.infoRankNum:SetDimensions(math.floor(barW / 2), barH + 6)
    self.controls.infoRankNum:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.controls.infoRankNum:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    self.controls.infoRankNum:SetColor(1, 1, 1, 1)
    self.controls.infoRankNum:SetDrawLayer(3)
    self.controls.infoRankNum:SetHidden(true)

    self.controls.infoAPText = wm:CreateControl(nil, self.controls.TLW, CT_LABEL)
    self.controls.infoAPText:SetFont(barLabelFont)
    self.controls.infoAPText:SetAnchor(RIGHT, self.controls.infoBarBg, RIGHT, -3, barNudge)
    self.controls.infoAPText:SetDimensions(barW - 3, barH + 6)
    self.controls.infoAPText:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.controls.infoAPText:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.controls.infoAPText:SetColor(1, 1, 1, 1)
    self.controls.infoAPText:SetDrawLayer(3)
    self.controls.infoAPText:SetHidden(true)

    self.controls.infoKD = wm:CreateControl(nil, self.controls.TLW, CT_LABEL)
    self.controls.infoKD:SetFont(killFont)
    self.controls.infoKD:SetAnchor(TOPRIGHT, self.controls.TLW, TOPRIGHT,
        -(self.config.kdRightPad or 0), 20 + (self.config.kdTextNudge or 0))
    self.controls.infoKD.baseX = -(self.config.kdRightPad or 0)
    self.controls.infoKD.baseY = 20 + (self.config.kdTextNudge or 0)
    self.controls.infoKD:SetDimensions(220, infoH)
    self.controls.infoKD:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.controls.infoKD:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.controls.infoKD:SetDrawLayer(2)
    self.controls.infoKD:SetHidden(true)

    local scoreFont = "EsoUI/Common/Fonts/FTN57.otf|20|outline"
    self.controls.scoreRow = wm:CreateControl(nil, self.controls.TLW, CT_CONTROL)
    self.controls.scoreRow:SetDimensions(self.config.width, self.config.entryHeight)
    self.controls.scoreRow:SetAnchor(TOPLEFT, self.controls.TLW, TOPLEFT, 0, 20 + self.config.entryHeight)
    self.controls.scoreRow.baseX, self.controls.scoreRow.baseY = 0, 20 + self.config.entryHeight
    self.controls.scoreRow:SetHidden(true)

    self.controls.scoreRowBg = wm:CreateControl(nil, self.controls.scoreRow, CT_BACKDROP)
    self.controls.scoreRowBg:SetAnchor(TOPLEFT, self.controls.scoreRow, TOPLEFT, 0, 0)
    self.controls.scoreRowBg:SetDimensions(self.config.width, self.config.entryHeight)
    self.controls.scoreRowBg:SetCenterColor(0, 0, 0, self.config.backdropAlphaEven)
    self.controls.scoreRowBg:SetEdgeColor(0, 0, 0, 0)
    self.controls.scoreRowBg:SetDrawLayer(0)

    local iBase = math.max(16, self.config.entryHeight - 4)
    local iSize = math.floor(iBase * self.config.iconScale.allianceScore)
    local iGrow = math.floor((iSize - iBase) / 2)
    local dcColor = GetColorForAlliance(ALLIANCE_DAGGERFALL_COVENANT)
    local adColor = GetColorForAlliance(ALLIANCE_ALDMERI_DOMINION)
    local epColor = GetColorForAlliance(ALLIANCE_EBONHEART_PACT)

    local empBaseW = PvPUA.config.imageWidth + 4
    local empBaseH = self.config.entryHeight + 4
    local empW     = math.floor(empBaseW * self.config.iconScale.emperor)
    local empH     = math.floor(empBaseH * self.config.iconScale.emperor)
    self.controls.infoEmpIcon = wm:CreateControl(nil, self.controls.scoreRow, CT_TEXTURE)
    self.controls.infoEmpIcon:SetTexture("esoui/art/campaign/gamepad/gp_overview_menuicon_emperor.dds")
    self.controls.infoEmpIcon:SetDimensions(empW, empH)
    self.controls.infoEmpIcon:SetAnchor(TOPLEFT, self.controls.scoreRow, TOPLEFT,
        -2 - math.floor((empW - empBaseW) / 2),
        -2 - math.floor((empH - empBaseH) / 2))
    self.controls.infoEmpIcon:SetColor(0.35, 0.35, 0.35, 1)
    self.controls.infoEmpIcon:SetDrawLayer(1)
    self.controls.infoEmpIcon:SetHidden(true)

    self.controls.empSlices = {}
    local sliceW = empW / 2
    local empBands = { { 0, 0.4082 }, { 0.4082, 0.5918 }, { 0.5918, 1 } }
    for slot = 1, #PvPUA.constants.emperorKeeps do
        local def = PvPUA.constants.emperorKeeps[slot]
        local band = empBands[def.row + 1]
        local slice = wm:CreateControl(nil, self.controls.infoEmpIcon, CT_TEXTURE)
        slice:SetTexture("esoui/art/campaign/gamepad/gp_overview_menuicon_emperor.dds")
        slice:SetDimensions(sliceW, empH * (band[2] - band[1]))
        slice:SetAnchor(TOPLEFT, self.controls.infoEmpIcon, TOPLEFT,
            def.col * sliceW, empH * band[1])
        slice:SetTextureCoords(def.col * 0.5, def.col * 0.5 + 0.5,
            band[1], band[2])
        slice:SetColor(0.35, 0.35, 0.35, 1)
        slice:SetDrawLayer(2)
        self.controls.empSlices[slot] = slice
    end

    local volW = PvPUA.config.imageWidth + 4 + 8
    local timerW = self.config.underAttackForWidth
    local remaining = self.config.width - volW - timerW - 4
    local groupW = math.floor(remaining / 3)
    local ptsW = groupW - iBase
    local col1 = volW
    local col2 = col1 + groupW
    local col3 = col1 + groupW * 2

    self.controls.scoreDCIcon = wm:CreateControl(nil, self.controls.scoreRow, CT_TEXTURE)
    self.controls.scoreDCIcon:SetTexture("/esoui/art/ava/ava_hud_emblem_daggerfall.dds")
    self.controls.scoreDCIcon:SetDimensions(iSize, iSize)
    self.controls.scoreDCIcon:SetAnchor(TOPLEFT, self.controls.scoreRow, TOPLEFT, col1 - iGrow, -iGrow)
    self.controls.scoreDCIcon:SetDrawLayer(1)

    self.controls.scoreDCScroll = wm:CreateControl(nil, self.controls.scoreRow, CT_TEXTURE)
    self.controls.scoreDCScroll:SetTexture(PvPUA.constants.textures.SCROLL_TALLY[ALLIANCE_DAGGERFALL_COVENANT])
    self.controls.scoreDCScroll:SetDimensions(iBase, iBase)
    self.controls.scoreDCScroll:SetAnchor(CENTER, self.controls.scoreDCIcon, CENTER, 0, 0)
    self.controls.scoreDCScroll:SetDrawLayer(3)
    self.controls.scoreDCScroll:SetDrawTier(DT_MEDIUM)
    self.controls.scoreDCScroll:SetHidden(false)

    self.controls.scoreDCScrollTxt = wm:CreateControl(nil, self.controls.scoreRow, CT_LABEL)
    self.controls.scoreDCScrollTxt:SetFont(scoreFont)
    self.controls.scoreDCScrollTxt:SetAnchor(CENTER, self.controls.scoreDCIcon, CENTER, 0, 0)
    self.controls.scoreDCScrollTxt:SetDimensions(iBase, iBase)
    self.controls.scoreDCScrollTxt:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.controls.scoreDCScrollTxt:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.controls.scoreDCScrollTxt:SetColor(1, 1, 1, 1)
    self.controls.scoreDCScrollTxt:SetDrawLayer(4)
    self.controls.scoreDCScrollTxt:SetDrawTier(DT_HIGH)
    self.controls.scoreDCScrollTxt:SetHidden(false)

    self.controls.scoreDCPts = wm:CreateControl(nil, self.controls.scoreRow, CT_LABEL)
    self.controls.scoreDCPts:SetFont(scoreFont)
    self.controls.scoreDCPts:SetAnchor(TOPLEFT, self.controls.scoreRow, TOPLEFT, col1 + iBase + 4, 0)
    self.controls.scoreDCPts:SetDimensions(ptsW, self.config.entryHeight)
    self.controls.scoreDCPts:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.controls.scoreDCPts:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    self.controls.scoreDCPts:SetColor(dcColor.r, dcColor.g, dcColor.b, 1)

    self.controls.scoreADIcon = wm:CreateControl(nil, self.controls.scoreRow, CT_TEXTURE)
    self.controls.scoreADIcon:SetTexture("/esoui/art/ava/ava_hud_emblem_aldmeri.dds")
    self.controls.scoreADIcon:SetDimensions(iSize, iSize)
    self.controls.scoreADIcon:SetAnchor(TOPLEFT, self.controls.scoreRow, TOPLEFT, col2 - iGrow, -iGrow)
    self.controls.scoreADIcon:SetDrawLayer(1)

    self.controls.scoreADScroll = wm:CreateControl(nil, self.controls.scoreRow, CT_TEXTURE)
    self.controls.scoreADScroll:SetTexture(PvPUA.constants.textures.SCROLL_TALLY[ALLIANCE_ALDMERI_DOMINION])
    self.controls.scoreADScroll:SetDimensions(iBase, iBase)
    self.controls.scoreADScroll:SetAnchor(CENTER, self.controls.scoreADIcon, CENTER, 0, 0)
    self.controls.scoreADScroll:SetDrawLayer(3)
    self.controls.scoreADScroll:SetDrawTier(DT_MEDIUM)
    self.controls.scoreADScroll:SetHidden(false)

    self.controls.scoreADScrollTxt = wm:CreateControl(nil, self.controls.scoreRow, CT_LABEL)
    self.controls.scoreADScrollTxt:SetFont(scoreFont)
    self.controls.scoreADScrollTxt:SetAnchor(CENTER, self.controls.scoreADIcon, CENTER, 0, 0)
    self.controls.scoreADScrollTxt:SetDimensions(iBase, iBase)
    self.controls.scoreADScrollTxt:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.controls.scoreADScrollTxt:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.controls.scoreADScrollTxt:SetColor(1, 1, 1, 1)
    self.controls.scoreADScrollTxt:SetDrawLayer(4)
    self.controls.scoreADScrollTxt:SetDrawTier(DT_HIGH)
    self.controls.scoreADScrollTxt:SetHidden(false)

    self.controls.scoreADPts = wm:CreateControl(nil, self.controls.scoreRow, CT_LABEL)
    self.controls.scoreADPts:SetFont(scoreFont)
    self.controls.scoreADPts:SetAnchor(TOPLEFT, self.controls.scoreRow, TOPLEFT, col2 + iBase + 4, 0)
    self.controls.scoreADPts:SetDimensions(ptsW, self.config.entryHeight)
    self.controls.scoreADPts:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.controls.scoreADPts:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    self.controls.scoreADPts:SetColor(adColor.r, adColor.g, adColor.b, 1)

    self.controls.scoreEPIcon = wm:CreateControl(nil, self.controls.scoreRow, CT_TEXTURE)
    self.controls.scoreEPIcon:SetTexture("/esoui/art/ava/ava_hud_emblem_ebonheart.dds")
    self.controls.scoreEPIcon:SetDimensions(iSize, iSize)
    self.controls.scoreEPIcon:SetAnchor(TOPLEFT, self.controls.scoreRow, TOPLEFT, col3 - iGrow, -iGrow)
    self.controls.scoreEPIcon:SetDrawLayer(1)

    self.controls.scoreEPScroll = wm:CreateControl(nil, self.controls.scoreRow, CT_TEXTURE)
    self.controls.scoreEPScroll:SetTexture(PvPUA.constants.textures.SCROLL_TALLY[ALLIANCE_EBONHEART_PACT])
    self.controls.scoreEPScroll:SetDimensions(iBase, iBase)
    self.controls.scoreEPScroll:SetAnchor(CENTER, self.controls.scoreEPIcon, CENTER, 0, 0)
    self.controls.scoreEPScroll:SetDrawLayer(3)
    self.controls.scoreEPScroll:SetDrawTier(DT_MEDIUM)
    self.controls.scoreEPScroll:SetHidden(false)

    self.controls.scoreEPScrollTxt = wm:CreateControl(nil, self.controls.scoreRow, CT_LABEL)
    self.controls.scoreEPScrollTxt:SetFont(scoreFont)
    self.controls.scoreEPScrollTxt:SetAnchor(CENTER, self.controls.scoreEPIcon, CENTER, 0, 0)
    self.controls.scoreEPScrollTxt:SetDimensions(iBase, iBase)
    self.controls.scoreEPScrollTxt:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.controls.scoreEPScrollTxt:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.controls.scoreEPScrollTxt:SetColor(1, 1, 1, 1)
    self.controls.scoreEPScrollTxt:SetDrawLayer(4)
    self.controls.scoreEPScrollTxt:SetDrawTier(DT_HIGH)
    self.controls.scoreEPScrollTxt:SetHidden(false)

    self.controls.scoreEPPts = wm:CreateControl(nil, self.controls.scoreRow, CT_LABEL)
    self.controls.scoreEPPts:SetFont(scoreFont)
    self.controls.scoreEPPts:SetAnchor(TOPLEFT, self.controls.scoreRow, TOPLEFT, col3 + iBase + 4, 0)
    self.controls.scoreEPPts:SetDimensions(ptsW, self.config.entryHeight)
    self.controls.scoreEPPts:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.controls.scoreEPPts:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    self.controls.scoreEPPts:SetColor(epColor.r, epColor.g, epColor.b, 1)

    self.controls.scoreTimer = wm:CreateControl(nil, self.controls.scoreRow, CT_LABEL)
    self.controls.scoreTimer:SetFont(scoreFont)
    self.controls.scoreTimer:SetAnchor(TOPRIGHT, self.controls.scoreRow, TOPRIGHT, -2, 0)
    self.controls.scoreTimer:SetDimensions(timerW, self.config.entryHeight)
    self.controls.scoreTimer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.controls.scoreTimer:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.controls.scoreTimer:SetColor(1, 1, 1, 1)

    self.controls.hudFragment = ZO_HUDFadeSceneFragment:New(self.controls.TLW)

    if SCENE_MANAGER and not self.listSceneHooked then
        self.listSceneHooked = true
        SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, _, newState)
            if newState == SCENE_HIDDEN and PvPUA:IsSettingsSceneObject(scene) then
                PvPUA.listPreview = false
            end
            if newState == SCENE_SHOWN or newState == SCENE_HIDDEN then
                PvPUA:ApplyListVisibility()
            end
        end)
    end
end

--------------------------------------------------
-- Campaign Queue
--------------------------------------------------
PvPUA.queue = { active = false }

local QUEUE_SIDE_PAD   = 10
local QUEUE_EDGE_PAD   = 6
local QUEUE_MAX_ROWS   = 3
local QUEUE_FONT       = "ZoFontGamepad27"
local QUEUE_HEADER_H   = 33
local QUEUE_ROW_H      = 35
local QUEUE_SAFETY_TICK = 5000
local QUEUE_RETRY_MS   = 3000

function PvPUA:AnchorQueueWindow(height)
    local tlw = self.controls.queueTLW
    if not tlw then return end
    local baseHeight = QUEUE_EDGE_PAD * 2 + QUEUE_HEADER_H + QUEUE_ROW_H
    local grow = (height or baseHeight) - baseHeight
    tlw:ClearAnchors()
    if ZO_CompassFrame then
        tlw:SetAnchor(LEFT, ZO_CompassFrame, RIGHT, 40, grow / 2)
    else
        tlw:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 100, 100)
    end
end

function PvPUA:CreateQueueUI()
    if self.controls.queueTLW then return end

    local tlw = wm:CreateTopLevelWindow("PvPUA_QueueTLW")
    tlw:SetClampedToScreen(true)
    tlw:SetDimensions(160, QUEUE_EDGE_PAD * 2 + QUEUE_HEADER_H + QUEUE_ROW_H)
    tlw:SetDrawTier(DT_HIGH)
    tlw:SetDrawLayer(DL_OVERLAY)
    tlw:SetDrawLevel(9000)
    tlw:SetHidden(true)
    self.controls.queueTLW = tlw

    self:AnchorQueueWindow(QUEUE_EDGE_PAD * 2 + QUEUE_HEADER_H + QUEUE_ROW_H)

    local bg = wm:CreateControl(nil, tlw, CT_BACKDROP)
    bg:SetAnchor(TOPLEFT, tlw, TOPLEFT, 0, 0)
    bg:SetAnchor(BOTTOMRIGHT, tlw, BOTTOMRIGHT, 0, 0)
    bg:SetCenterColor(0, 0, 0, 0.6)
    bg:SetEdgeColor(0.6, 0.6, 0.6, 0.8)
    bg:SetEdgeTexture(nil, 1, 1, 1, 0)
    self.controls.queueBg = bg

    local header = wm:CreateControl(nil, tlw, CT_LABEL)
    header:SetFont(QUEUE_FONT)
    header:SetAnchor(TOP, tlw, TOP, 0, QUEUE_EDGE_PAD)
    header:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    header:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    header:SetColor(0, 1, 0, 1)
    self.controls.queueHeader = header

    self.controls.queueRows = {}
    for i = 1, QUEUE_MAX_ROWS do
        local row = wm:CreateControl(nil, tlw, CT_LABEL)
        row:SetFont(QUEUE_FONT)
        row:SetAnchor(TOP, tlw, TOP, 0,
            QUEUE_EDGE_PAD + QUEUE_HEADER_H + QUEUE_ROW_H * (i - 1))
        row:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        row:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        row:SetColor(1, 1, 1, 1)
        row:SetHidden(true)
        self.controls.queueRows[i] = row
    end
end

local function QueueCampaignName(campaignId)
    local name = ""
    if GetCampaignName then
        local ok, value = pcall(GetCampaignName, campaignId)
        if ok and value then name = zo_strformat("<<1>>", value) end
    end
    if name == "" then name = "Campaign " .. tostring(campaignId) end
    if #name > 14 then name = name:sub(1, 13) .. "." end
    return name
end

local function QueueEntryIsDisplayable(entry)
    if type(entry.position) ~= "number" or entry.position <= 0 then return false end
    if entry.state ~= nil and CAMPAIGN_QUEUE_REQUEST_STATE_WAITING ~= nil then
        if entry.state ~= CAMPAIGN_QUEUE_REQUEST_STATE_WAITING then return false end
    end
    return true
end

function PvPUA:GetQueueEntries()
    local out = {}
    if not (GetNumCampaignQueueEntries and GetCampaignQueueEntry) then return out end
    local ok = pcall(function()
        local n = GetNumCampaignQueueEntries() or 0
        for i = 1, n do
            local campaignId, queueAsGroup = GetCampaignQueueEntry(i)
            if campaignId and campaignId ~= 0 then
                local entry = { campaignId = campaignId, asGroup = queueAsGroup == true }
                if GetCampaignQueuePosition then
                    entry.position = GetCampaignQueuePosition(campaignId, entry.asGroup)
                end
                if GetCampaignQueueState then
                    entry.state = GetCampaignQueueState(campaignId, entry.asGroup)
                end
                if QueueEntryIsDisplayable(entry) then
                    out[#out + 1] = entry
                end
            end
        end
    end)
    if not ok then return {} end
    return out
end

function PvPUA:RefreshQueueWindow()
    if not self.controls.queueTLW then return end

    local entries = self:GetQueueEntries()
    if #entries == 0 then
        self.controls.queueTLW:SetHidden(true)
        self.queue.active = false
        return
    end

    local shown = #entries
    if shown > QUEUE_MAX_ROWS then shown = QUEUE_MAX_ROWS end

    self.controls.queueHeader:SetText(shown > 1 and "Queues" or "Queue")

    local ac = GetColorForAlliance(GetUnitAlliance("player"))

    for i = 1, QUEUE_MAX_ROWS do
        local row = self.controls.queueRows[i]
        local entry = entries[i]
        if entry and i <= shown then
            local positionText = "--"
            if type(entry.position) == "number" and entry.position > 0 then
                positionText = tostring(entry.position)
            end
            local groupTag = entry.asGroup and " |c9090A0(G)|r" or ""
            row:SetText(ColorText(QueueCampaignName(entry.campaignId), ac.r, ac.g, ac.b) ..
                " |c00FF00#|r" ..
                ColorText(positionText, ac.r, ac.g, ac.b) .. groupTag)
            row:SetHidden(false)
        else
            row:SetText("")
            row:SetHidden(true)
        end
    end

    local widest = self.controls.queueHeader:GetTextWidth() or 0
    for i = 1, shown do
        local w = self.controls.queueRows[i]:GetTextWidth() or 0
        if w > widest then widest = w end
    end

    local width = math.ceil(widest) + QUEUE_SIDE_PAD * 2
    local height = QUEUE_EDGE_PAD * 2 + QUEUE_HEADER_H + QUEUE_ROW_H * shown

    self.controls.queueTLW:SetDimensions(width, height)
    self:AnchorQueueWindow(height)

    self.controls.queueTLW:SetHidden(false)
    self.queue.active = true
end

function PvPUA:RefreshQueueSoon()
    self:RefreshQueueWindow()
    zo_callLater(function() PvPUA:RefreshQueueWindow() end, QUEUE_RETRY_MS)
end

function PvPUA:StartQueueSafetyPoll()
    EVENT_MANAGER:UnregisterForUpdate(PvPUA.name .. "_QueueSafety")
    EVENT_MANAGER:RegisterForUpdate(PvPUA.name .. "_QueueSafety", QUEUE_SAFETY_TICK,
        function() PvPUA:RefreshQueueWindow() end)
end

function PvPUA:RegisterQueueEvents()
    local pairsToBind = {
        { EVENT_CAMPAIGN_QUEUE_JOINED,           "_QueueJoined" },
        { EVENT_CAMPAIGN_QUEUE_LEFT,             "_QueueLeft" },
        { EVENT_CAMPAIGN_QUEUE_POSITION_CHANGED, "_QueuePosition" },
        { EVENT_CAMPAIGN_QUEUE_STATE_CHANGED,    "_QueueState" },
    }
    for i = 1, #pairsToBind do
        local eventId, suffix = pairsToBind[i][1], pairsToBind[i][2]
        if eventId ~= nil then
            EVENT_MANAGER:RegisterForEvent(PvPUA.name .. suffix, eventId,
                function() PvPUA:RefreshQueueWindow() end)
        end
    end
end

--------------------------------------------------
-- Header Layout
--------------------------------------------------
function PvPUA:ApplyHeaderLayout()
    local c = self.controls
    if not (c.TLW and c.creditLabel and c.infoBg) then return end

    local shift = ((self.initializedZone == "IC") and self.config.entryHeight or 0) + self:HeaderTop() - 20
    if self.headerShift == shift then return end
    self.headerShift = shift

    local function place(control, point, relPoint)
        if not control or control.baseY == nil then return end
        control:ClearAnchors()
        control:SetAnchor(point, c.TLW, relPoint, control.baseX or 0, control.baseY + shift)
    end

    place(c.creditLabel, TOPLEFT, TOPLEFT)
    place(c.scoreRow, TOPLEFT, TOPLEFT)
    place(c.infoBg, TOPLEFT, TOPLEFT)
    place(c.infoRankIcon, TOPLEFT, TOPLEFT)
    place(c.infoBarBg, TOPLEFT, TOPLEFT)
    place(c.infoBar, TOPLEFT, TOPLEFT)
    place(c.infoKD, TOPRIGHT, TOPRIGHT)
end

--------------------------------------------------
-- UpdateEntries
--------------------------------------------------
function PvPUA:UpdateEntries(itemsOfInterest)
    local listCap = (self.savedVariables and self.savedVariables.listCap) or 0
    if listCap > 0 then
        for i = #itemsOfInterest, listCap + 1, -1 do
            itemsOfInterest[i] = nil
        end
    end

    self.state.lastItems = itemsOfInterest
    local adColor = GetColorForAlliance(ALLIANCE_ALDMERI_DOMINION)
    local epColor = GetColorForAlliance(ALLIANCE_EBONHEART_PACT)
    local dcColor = GetColorForAlliance(ALLIANCE_DAGGERFALL_COVENANT)
    for i = 1, #itemsOfInterest do
        local item = itemsOfInterest[i]
        local control = self.state.visibleControls[i]
        if not control then break end
        control:ClearAnchors()
        control:SetAnchor(TOPLEFT, self.controls.TLW.rootControl, TOPLEFT, 0, self.config.entryHeight * (i - 1))
        control:SetHidden(false)
        local ac = GetColorForAlliance(item.owningAlliance)
        local useAlliance = self.savedVariables and self.savedVariables.backdropStyle == "Alliance"
        local bc = self.savedVariables and self.savedVariables.backdropColor
        local br = bc and bc.r or 0
        local bg_c = bc and bc.g or 0
        local bb = bc and bc.b or 0
        if useAlliance then
            local rr, rg, rb = ac.r, ac.g, ac.b
            if item.isScrollDropped then rr, rg, rb = 1, 1, 1 end
            if i % 2 == 0 then
                control.backdrop:SetCenterColor(rr, rg, rb, self.config.backdropAlphaEven)
            else
                control.backdrop:SetCenterColor(rr, rg, rb, self.config.backdropAlphaOdd)
            end
        else
            if i % 2 == 0 then
                control.backdrop:SetCenterColor(br, bg_c, bb, self.config.backdropAlphaEven)
            else
                control.backdrop:SetCenterColor(br, bg_c, bb, self.config.backdropAlphaOdd)
            end
        end
        control.backdrop:SetEdgeColor(0, 0, 0, 0)
        if item.isUnderAttack == true then
            control.backdrop:SetHidden(false)
            control.uaImage:SetHidden(false)
            if control.uaOutline then control.uaOutline:SetHidden(item.isScrollCarrier == true) end
            control.image:SetHidden(false)
        else
            control.backdrop:SetHidden(false)
            control.uaImage:SetHidden(true)
            if control.uaOutline then control.uaOutline:SetHidden(true) end
            control.image:SetHidden(false)
        end
        local texture, offset = GetTextureAndOffsetForItem(item.keepType, item.rType, item.isPassable)
        if item.isScrollCarrier then
            texture = item.carrierTexture or texture
            offset = 2
            local baseW = self.config.imageWidth + offset * 2
            local baseH = self.config.entryHeight + offset * 2
            local iconScale = item.carrierIconScale or SCROLL_CARRIER_ICON_SCALE
            local cw = baseW * iconScale
            local ch = baseH * iconScale
            local dx = (cw - baseW) / 2
            local dy = (ch - baseH) / 2
            control.image:SetTexture(texture)
            control.image:ClearAnchors()
            control.image:SetAnchor(TOPLEFT, control, TOPLEFT, -offset - dx, -offset - dy)
            control.image:SetDimensions(cw, ch)
            if item.carrierTint then
                control.image:SetColor(ac.r, ac.g, ac.b, 1)
            else
                control.image:SetColor(1, 1, 1, 1)
            end
            if control.imageOutline then control.imageOutline:SetHidden(true) end
        else
            control.image:SetTexture(texture)
            control.image:ClearAnchors()
            control.image:SetAnchor(TOPLEFT, control, TOPLEFT, -offset, -offset)
            control.image:SetDimensions(self.config.imageWidth + offset * 2, self.config.entryHeight + offset * 2)
            control.image:SetColor(ac.r, ac.g, ac.b, 1)
            if control.imageOutline then
                local OL = 2
                control.imageOutline:SetTexture(texture)
                control.imageOutline:ClearAnchors()
                control.imageOutline:SetAnchor(TOPLEFT, control, TOPLEFT, -offset - OL, -offset - OL)
                control.imageOutline:SetDimensions(self.config.imageWidth + offset * 2 + OL * 2,
                                                   self.config.entryHeight + offset * 2 + OL * 2)
                control.imageOutline:SetColor(0, 0, 0, 1)
                control.imageOutline:SetHidden(not self.config.iconOutline or texture == nil or texture == "")
            end
        end

        if control.scrollImage then
            local okScroll = pcall(function()
                if item.isScrollCarrier then
                    control.scrollImage:SetHidden(true)
                elseif item.scroll and item.scroll.pinType then
                    local sTex = GetScrollTexture(item.scroll.pinType)
                    if sTex then
                        local sw = (self.config.imageWidth + offset * 2) * SCROLL_KEEP_ICON_SCALE
                        local sh = (self.config.entryHeight + offset * 2) * SCROLL_KEEP_ICON_SCALE
                        control.scrollImage:ClearAnchors()
                        control.scrollImage:SetAnchor(CENTER, control.image, CENTER, 0, 0)
                        control.scrollImage:SetDimensions(sw, sh)
                        control.scrollImage:SetTexture(sTex)
                        control.scrollImage:SetColor(1, 1, 1, 1)
                        control.scrollImage:SetHidden(false)
                    else
                        control.scrollImage:SetHidden(true)
                    end
                else
                    control.scrollImage:SetHidden(true)
                end
            end)
            if not okScroll then control.scrollImage:SetHidden(true) end
        end

        if item.isScrollCarrier then
            local wideName = self.config.nameWidth + self.config.flagWidth
                           + self.config.siegeWidth * 3 + self.config.flagFlipWidth
            control.name:SetDimensions(wideName, self.config.entryHeight)
            control.name:SetColor(1, 1, 1, 1)
            control.name:SetText(item.name)
        else
            control.name:SetDimensions(self.config.nameWidth, self.config.entryHeight)
            control.name:SetColor(ac.r, ac.g, ac.b, 1)
            control.name:SetText(item.name)
        end

        local font = PvPUA:GetFont()
        control.name:SetFont(font)
        control.adSiege:SetFont(font)
        control.epSiege:SetFont(font)
        control.dcSiege:SetFont(font)
        control.flipStatus:SetFont(font)
        control.underAttackFor:SetFont(font)

        if item.siegeWeapons ~= nil then
            SetSiegeWeapons(control.dcSiege, item.siegeWeapons.DC)
            SetSiegeWeapons(control.adSiege, item.siegeWeapons.AD)
            SetSiegeWeapons(control.epSiege, item.siegeWeapons.EP)
            control.dcSiege:SetColor(dcColor.r, dcColor.g, dcColor.b, 1)
            control.adSiege:SetColor(adColor.r, adColor.g, adColor.b, 1)
            control.epSiege:SetColor(epColor.r, epColor.g, epColor.b, 1)
        else
            control.adSiege:SetText("")
            control.epSiege:SetText("")
            control.dcSiege:SetText("")
        end

        local underAttackFor = item.underAttackFor
        control.underAttackFor:SetText(FormatUnderAttackTime(underAttackFor / 1000))
        local tr, tg, tb = GetTimerColor()
        control.underAttackFor:SetColor(tr, tg, tb, 1)
        if control.kills then
            control.kills:SetFont(font)
            control.kills:SetText(self:KillTallyText(item))
        end

        local objectives = item.objectives
        control.progress.bar1:ClearAnchors()
        control.progress.bar2:ClearAnchors()
        control.progress.bar3:ClearAnchors()
        if item.isScrollCarrier then
            control.progress.bar1:SetHidden(true)
            control.progress.bar2:SetHidden(true)
            control.progress.bar3:SetHidden(true)
            control.flipStatus:SetText("")
        elseif item.keepType == KEEPTYPE_KEEP or item.keepType == KEEPTYPE_OUTPOST then
            control.progress.bar1:SetAnchor(TOPLEFT, control.progress, TOPLEFT, 0, self.config.entryHeight / 2 - self.config.flagHeight - 1)
            control.progress.bar2:SetAnchor(TOPLEFT, control.progress, TOPLEFT, 0, self.config.entryHeight / 2 + 1)
            control.progress.bar1:SetHidden(false)
            control.progress.bar2:SetHidden(false)
            control.progress.bar3:SetHidden(true)
            if objectives ~= nil and objectives[1] ~= nil and objectives[2] ~= nil then
                control.progress.bar1.progress:SetValue(objectives[1].state)
                control.progress.bar2.progress:SetValue(objectives[2].state)
                control.progress.bar1.progress:SetColor(GetColorForAlliance(objectives[1].holdingAlliance).r, GetColorForAlliance(objectives[1].holdingAlliance).g, GetColorForAlliance(objectives[1].holdingAlliance).b)
                control.progress.bar2.progress:SetColor(GetColorForAlliance(objectives[2].holdingAlliance).r, GetColorForAlliance(objectives[2].holdingAlliance).g, GetColorForAlliance(objectives[2].holdingAlliance).b)
            else
                control.progress.bar1.progress:SetValue(100)
                control.progress.bar2.progress:SetValue(100)
            end
        elseif item.keepType == KEEPTYPE_TOWN then
            control.progress.bar1:SetAnchor(TOPLEFT, control.progress, TOPLEFT, 0, self.config.entryHeight / 6 - self.config.flagHeight / 2)
            control.progress.bar2:SetAnchor(TOPLEFT, control.progress, TOPLEFT, 0, self.config.entryHeight / 6 * 3 - self.config.flagHeight / 2)
            control.progress.bar3:SetAnchor(TOPLEFT, control.progress, TOPLEFT, 0, self.config.entryHeight / 6 * 5 - self.config.flagHeight / 2)
            control.progress.bar1:SetHidden(false)
            control.progress.bar2:SetHidden(false)
            control.progress.bar3:SetHidden(false)
            if objectives ~= nil then
                control.progress.bar1.progress:SetValue(objectives[1].state)
                control.progress.bar2.progress:SetValue(objectives[2].state)
                control.progress.bar3.progress:SetValue(objectives[3].state)
                control.progress.bar1.progress:SetColor(GetColorForAlliance(objectives[1].holdingAlliance).r, GetColorForAlliance(objectives[1].holdingAlliance).g, GetColorForAlliance(objectives[1].holdingAlliance).b)
                control.progress.bar2.progress:SetColor(GetColorForAlliance(objectives[2].holdingAlliance).r, GetColorForAlliance(objectives[2].holdingAlliance).g, GetColorForAlliance(objectives[2].holdingAlliance).b)
                control.progress.bar3.progress:SetColor(GetColorForAlliance(objectives[3].holdingAlliance).r, GetColorForAlliance(objectives[3].holdingAlliance).g, GetColorForAlliance(objectives[3].holdingAlliance).b)
            end
        elseif item.keepType == KEEPTYPE_RESOURCE or item.keepType == KEEPTYPE_IMPERIAL_CITY_DISTRICT then
            control.progress.bar1:SetAnchor(TOPLEFT, control.progress, TOPLEFT, 0, self.config.entryHeight / 2 - self.config.flagHeight / 2)
            control.progress.bar1:SetHidden(false)
            control.progress.bar2:SetHidden(true)
            control.progress.bar3:SetHidden(true)
            if objectives ~= nil then
                control.progress.bar1.progress:SetValue(objectives[1].state)
                control.progress.bar1.progress:SetColor(GetColorForAlliance(objectives[1].holdingAlliance).r, GetColorForAlliance(objectives[1].holdingAlliance).g, GetColorForAlliance(objectives[1].holdingAlliance).b)
            end
        else
            control.progress.bar1:SetHidden(true)
            control.progress.bar2:SetHidden(true)
            control.progress.bar3:SetHidden(true)
        end

        if item.flipsAt ~= nil then
            local flipsIn = math.floor((item.flipsAt - GetGameTimeMilliseconds()) / 1000)
            if flipsIn >= 0 then
                control.flipStatus:SetText(flipsIn)
                if objectives ~= nil and objectives[1].holdingAlliance == GetUnitAlliance("player") then
                    control.flipStatus:SetColor(0, 1, 0, 1)
                else
                    control.flipStatus:SetColor(1, 0, 0, 1)
                end
            else
                control.flipStatus:SetText("")
            end
        else
            control.flipStatus:SetText("")
        end
    end
    for i = #itemsOfInterest + 1, #self.state.visibleControls do
        local c = self.state.visibleControls[i]
        c:SetHidden(true)
        if c.scrollImage then c.scrollImage:SetHidden(true) end
    end
end

function PvPUA:GetVeterancyInfo()
    local info = { ok = false, rank = 0, progress = 0, total = 0, icon = nil, raw1 = nil, why = nil }
    local okCall = pcall(function()
        if REWARD_TRACK_TYPE_AVA_VETERANCY == nil then info.why = "no REWARD_TRACK_TYPE_AVA_VETERANCY" return end
        if not (GetActiveReferenceTrackIdsForRewardTrackType and GetReferenceTrackIndex
                and GetInfoForRewardTrack) then info.why = "reward track API missing" return end

        local trackType = REWARD_TRACK_TYPE_AVA_VETERANCY

        local ids = { GetActiveReferenceTrackIdsForRewardTrackType(trackType) }
        if #ids == 0 then info.why = "no active track ids" return end

        local trackId, trackIndex
        for i = 1, #ids do
            local candidate = ids[i]
            if type(candidate) == "number" then
                local idx = GetReferenceTrackIndex(trackType, candidate)
                if idx then
                    trackId, trackIndex = candidate, idx
                    break
                end
            end
        end
        if not trackIndex then info.why = "no resolvable track index" return end

        local first, currentRank, progressToNextRank = GetInfoForRewardTrack(trackType, trackIndex)
        info.raw1 = first

        if type(currentRank) ~= "number" then
            local rets = { GetInfoForRewardTrack(trackType, trackIndex) }
            for i = 1, #rets do
                if type(rets[i]) == "number" then
                    currentRank = rets[i]
                    progressToNextRank = (type(rets[i + 1]) == "number") and rets[i + 1] or 0
                    break
                end
            end
        end

        info.rank = currentRank or 0
        info.progress = progressToNextRank or 0

        local iconRank = info.rank
        if iconRank > 100 then iconRank = 100 end

        if info.rank >= 101 then
            info.total = 0
        elseif GetRewardTrackIdFromReferenceTrackId and GetTotalProgressAtRewardTrackTier then
            local rewardTrackId = GetRewardTrackIdFromReferenceTrackId(trackType, trackId)
            if rewardTrackId then
                info.total = GetTotalProgressAtRewardTrackTier(rewardTrackId, info.rank) or 0
            end
        end

        if type(first) == "string" and first:lower():find("%.dds") then
            info.icon = first
        end

        if not info.icon then
            local iconFns = {
                { fn = "GetVeterancyRankIcon",          args = { "rank" } },
                { fn = "GetAvAVeterancyRankIcon",       args = { "rank" } },
                { fn = "GetRewardTrackTierIcon",        args = { "rewardTrackId", "rank" } },
                { fn = "GetRewardTrackRankIcon",        args = { "trackType", "rank" } },
                { fn = "GetLargeAvAVeterancyRankIcon",  args = { "rank" } },
            }
            local rewardTrackIdForIcon
            if GetRewardTrackIdFromReferenceTrackId then
                rewardTrackIdForIcon = GetRewardTrackIdFromReferenceTrackId(trackType, trackId)
            end
            local argValues = {
                rank          = iconRank,
                trackType     = trackType,
                rewardTrackId = rewardTrackIdForIcon,
                tier          = (type(first) == "number") and first or nil,
            }
            for i = 1, #iconFns do
                local entry = iconFns[i]
                local f = _G[entry.fn]
                if type(f) == "function" then
                    local callArgs, missing = {}, false
                    for a = 1, #entry.args do
                        local val = argValues[entry.args[a]]
                        if val == nil then
                            missing = true
                            break
                        end
                        callArgs[a] = val
                    end
                    if not missing then
                        local okIcon, res
                        if #callArgs == 1 then
                            okIcon, res = pcall(f, callArgs[1])
                        else
                            okIcon, res = pcall(f, callArgs[1], callArgs[2])
                        end
                        if okIcon and type(res) == "string" and res ~= ""
                           and res:lower():find("%.dds") then
                            info.icon = res
                            info.iconSource = entry.fn .. "(" .. table.concat(entry.args, ",") .. ")"
                            break
                        end
                    end
                end
            end
        end

        info.ok = true
    end)
    if not okCall then info.ok = false; info.why = info.why or "api call errored" end
    return info
end

--------------------------------------------------
-- RefreshRankLabel
--------------------------------------------------
function PvPUA:RefreshRankLabel()
    if not self.controls.infoRankNum then return end
    if self.savedVariables and self.savedVariables.barMode == "Veterancy" then
        local v = self:GetVeterancyInfo()
        if v.ok then
            self.controls.infoRankNum:SetText(tostring(v.rank))
        else
            self.controls.infoRankNum:SetText("--")
        end
        return
    end
    local rankNum  = ZO_CampaignAvARankRank and ZO_CampaignAvARankRank:GetText() or ""
    local rankName = ZO_CampaignAvARankName and ZO_CampaignAvARankName:GetText() or ""
    local grade    = rankName:match("GRADE %d+") or ""
    if rankNum ~= "" then
        self.controls.infoRankNum:SetText(rankNum .. (grade ~= "" and (" " .. grade) or ""))
    end
end

--------------------------------------------------
-- OnUiUpdate
--------------------------------------------------
function PvPUA:OnUiUpdate(itemsOfInterest)
    local rootControl = self.controls.TLW.rootControl

    rootControl:ClearAnchors()
    rootControl:SetAnchor(TOPLEFT, self.controls.TLW, TOPLEFT, 0, self:HeaderTop() + self.config.entryHeight * 2)

    if itemsOfInterest ~= nil then
        self:UpdateEntries(itemsOfInterest)
    else
        for i = 1, #self.state.visibleControls do
            self.state.visibleControls[i]:SetHidden(true)
        end
    end

    if self:ShowCredit() then
        self.controls.creditLabel:SetHidden(false)
        self.creditCycle = (self.creditCycle + 1) % totalSteps
        self.controls.creditLabel:SetText(CREDIT_STATES[self.creditCycle])
    else
        self.controls.creditLabel:SetHidden(true)
    end
    self.controls.infoBg:SetHidden(false)
    self.controls.infoRankIcon:SetHidden(false)
    self.controls.infoEmpIcon:SetHidden(false)
    self.controls.infoBarBg:SetHidden(false)
    self.controls.infoBar:SetHidden(false)
    self.controls.infoRankNum:SetHidden(false)
    self.controls.infoAPText:SetHidden(false)
    self.controls.infoKD:SetHidden(false)

    local inIC = self.initializedZone == "IC"
    self:ApplyHeaderLayout()
    self.controls.scoreRow:SetHidden(inIC)

    local vetMode = self.savedVariables and self.savedVariables.barMode == "Veterancy"
    local vetIconShown = false
    PvPUA:RefreshRankLabel()

    if vetMode then
        local v = self:GetVeterancyInfo()
        if v.icon then
            self.controls.infoRankIcon:SetTexture(v.icon)
            self.controls.infoRankIcon:SetHidden(false)
            vetIconShown = true
        else
            local rankIconTex = ZO_CampaignAvARankIcon and ZO_CampaignAvARankIcon:GetTextureFileName() or ""
            if rankIconTex ~= "" then self.controls.infoRankIcon:SetTexture(rankIconTex) end
        end

        if v.ok and v.total and v.total > 0 then
            local pct = (v.progress / v.total) * 100
            if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end
            self.controls.infoBar:SetValue(pct)
            self.controls.infoAPText:SetText(
                ZO_CommaDelimitNumber(v.progress) .. " / " .. ZO_CommaDelimitNumber(v.total))
        else
            self.controls.infoBar:SetValue(v.ok and 100 or 0)
            self.controls.infoAPText:SetText("")
        end
    else
        local currentXP = GetUnitAvARankPoints("player")
        local lastRankXP, nextRankXP = GetAvARankProgress(currentXP)
        local rankIconTex = ZO_CampaignAvARankIcon and ZO_CampaignAvARankIcon:GetTextureFileName() or ""
        if rankIconTex ~= "" then
            self.controls.infoRankIcon:SetTexture(rankIconTex)
        end
        local apEarned   = currentXP - lastRankXP
        local apRequired = nextRankXP and (nextRankXP - lastRankXP) or 0
        if nextRankXP and apRequired > 0 then
            local barPct = (apEarned / apRequired * 100)
            self.controls.infoBar:SetValue(barPct)
            self.controls.infoAPText:SetText(
                ZO_CommaDelimitNumber(apEarned) .. " / " .. ZO_CommaDelimitNumber(apRequired))
        else
            self.controls.infoBar:SetValue(100)
            self.controls.infoAPText:SetText("")
        end
    end
    local pAlliance = GetUnitAlliance("player")
    local ac = GetColorForAlliance(pAlliance)
    self.controls.infoBar:SetColor(ac.r, ac.g, ac.b, 1)
    if vetIconShown then
        self.controls.infoRankIcon:SetColor(1, 1, 1, 1)
    else
        self.controls.infoRankIcon:SetColor(ac.r, ac.g, ac.b, 1)
    end

    self:RefreshKDText()

    if inIC then return end

    local campaignId = GetCurrentCampaignId()

    if self.controls.empSlices then
        local empAlliance = GetCampaignEmperorInfo and GetCampaignEmperorInfo(campaignId) or 0
        local hasEmperor = empAlliance ~= nil and empAlliance ~= 0
        local ec = hasEmperor and GetColorForAlliance(empAlliance) or nil

        for slot = 1, #self.controls.empSlices do
            local slice = self.controls.empSlices[slot]
            if hasEmperor then
                slice:SetColor(ec.r, ec.g, ec.b, 1)
            else
                local keepId = self.emperorKeepIds and self.emperorKeepIds[slot]
                local owner = keepId and GetKeepAlliance(keepId, BGQUERY_LOCAL) or 0
                if owner ~= nil and owner ~= 0 then
                    local kc = GetColorForAlliance(owner)
                    slice:SetColor(kc.r, kc.g, kc.b, 1)
                else
                    slice:SetColor(0.35, 0.35, 0.35, 1)
                end
            end
        end
    end

    local secs = GetSecondsUntilCampaignScoreReevaluation(campaignId)
    local mins = math.floor(secs / 60)
    local s = secs - mins * 60
    self.controls.scoreTimer:SetText(string.format("%d:%02d", mins, s))
    local dcTotal = GetCampaignAllianceScore(campaignId, ALLIANCE_DAGGERFALL_COVENANT) or 0
    local adTotal = GetCampaignAllianceScore(campaignId, ALLIANCE_ALDMERI_DOMINION) or 0
    local epTotal = GetCampaignAllianceScore(campaignId, ALLIANCE_EBONHEART_PACT) or 0
    local dcPot = GetCampaignAlliancePotentialScore(campaignId, ALLIANCE_DAGGERFALL_COVENANT) or 0
    local adPot = GetCampaignAlliancePotentialScore(campaignId, ALLIANCE_ALDMERI_DOMINION) or 0
    local epPot = GetCampaignAlliancePotentialScore(campaignId, ALLIANCE_EBONHEART_PACT) or 0
    self.controls.scoreDCPts:SetText("[" .. dcTotal .. "] +" .. dcPot .. "p")
    self.controls.scoreADPts:SetText("[" .. adTotal .. "] +" .. adPot .. "p")
    self.controls.scoreEPPts:SetText("[" .. epTotal .. "] +" .. epPot .. "p")
    local dcColor = GetColorForAlliance(ALLIANCE_DAGGERFALL_COVENANT)
    local adColor = GetColorForAlliance(ALLIANCE_ALDMERI_DOMINION)
    local epColor = GetColorForAlliance(ALLIANCE_EBONHEART_PACT)
    self.controls.scoreDCIcon:SetColor(dcColor.r, dcColor.g, dcColor.b, 1)
    self.controls.scoreADIcon:SetColor(adColor.r, adColor.g, adColor.b, 1)
    self.controls.scoreEPIcon:SetColor(epColor.r, epColor.g, epColor.b, 1)


end

--------------------------------------------------
-- OnObjectiveControlState
--------------------------------------------------
function PvPUA:OnObjectiveControlState(eventCode, keepId, objectiveId, battlegroundContext, objectiveName, objectiveType, objectiveControlEvent, objectiveControlState, holdingAlliance, attackingAlliance, pinType)
    local keep = self:GetItemByKeepId(keepId)
    if keep ~= nil then
        local objectives = keep.objectives
        if objectives == nil then
            self:AddObjectives()
            objectives = keep.objectives
        end
        if objectives ~= nil then
            local objective = nil
            for i = 1, #objectives do
                if objectives[i].id == objectiveId then
                    objective = objectives[i]
                    break
                end
            end
            if objective == nil then
                for i = 1, #objectives do
                    if objectives[i].id == nil then
                        objectives[i].id = objectiveId
                        objective = objectives[i]
                        break
                    end
                end
            end
            if objective ~= nil then
                objective.holdingAlliance = holdingAlliance
                if objective.holdingAlliance == 0 then
                    objective.holdingAlliance = attackingAlliance
                end
                objective.state = GetFlagStatePercent(objectiveControlState, keep.owningAlliance, holdingAlliance)
                AdjustKeepFlipping(keep)
            end
        end
    end
end

--------------------------------------------------
-- K:/D: text
--------------------------------------------------
function PvPUA:RefreshKDText()
    local c = self.controls
    if not c or not c.infoKD then return end
    local gap = self.config.kdGap or " "
    c.infoKD:SetText("|c00FF00K:|r " .. self.session.killingBlows
                     .. gap .. "|cFF0000D:|r " .. self.session.deaths)
end

--------------------------------------------------
-- CyroUpdateLoop
--------------------------------------------------
function PvPUA:CyroUpdateLoop()
    if IsInCyrodiilOrIC() == true then
        local itemsOfInterest = {}
        local gameTime = GetGameTimeMilliseconds()
        local function addItems(newItems)
            if newItems ~= nil then
                for i = 1, #newItems do
                    table.insert(itemsOfInterest, newItems[i])
                end
            end
        end
        addItems(self:UpdateItem(self.state.resources, gameTime))
        addItems(self:UpdateItem(self.state.keeps, gameTime))
        addItems(self:UpdateItem(self.state.outposts, gameTime))
        addItems(self:UpdateItem(self.state.villages, gameTime))
        addItems(self:UpdateItem(self.state.destructibles, gameTime))
        addItems(self:UpdateItem(self.state.districts, gameTime))
        -- Runs after UpdateItem: an item that flagged this tick seeds from the previous snapshot,
        -- then this tick's delta brings it up to date. Deltas already credited by the event
        -- handler are zero here.
        self:KillTallyUpdate()
        if self.initializedZone ~= "IC" then
            self:RefreshScrolls()
            self:UpdateScrollCounts()
            self:RefreshScrollTally()
            self:RefreshScrollCarriers()
            if not (self.savedVariables and self.savedVariables.showScrollCarriers == false) then
                addItems(self:GetScrollCarrierItems())
            end
            self:RefreshVolendrungCarrier()
            if not (self.savedVariables and self.savedVariables.showVolendrungRow == false) then
                local volItem = self:GetVolendrungCarrierItem()
                if volItem then addItems({ volItem }) end
            end
        end
        if #itemsOfInterest > 1 then
            table.sort(itemsOfInterest, SortItemsOfInterest)
        end
        self:OnUiUpdate(itemsOfInterest)
        self:ApplyListVisibility()
    end
end

--------------------------------------------------
-- Volendrung Events
--------------------------------------------------
function PvPUA:CacheVolendrungName(daedricArtifactId)
    if not daedricArtifactId or not GetDaedricArtifactDisplayName then return end
    local nm = GetDaedricArtifactDisplayName(daedricArtifactId)
    if nm and nm ~= "" then
        self.volendrungName    = zo_strformat("<<1>>", nm)
    end
end

function PvPUA:OnVolendrungSpawned(eventCode, daedricArtifactId)
    self:CacheVolendrungName(daedricArtifactId)
    self.volendrung = {
        texture        = "/esoui/art/mappins/ava_daedricartifact_volendrung_neutral.dds",
        holderAlliance = 0,
        objectiveId    = nil,
        keepId         = nil,
        despawnAt      = nil,
        spawnedAt      = GetGameTimeMilliseconds(),
    }
    self:CyroUpdateLoop()
end

function PvPUA:OnVolendrungStateChanged(eventCode, objectiveKeepId, objectiveObjectiveId, battlegroundContext,
    objectiveControlEvent, objectiveControlState, holderAlliance, lastHolderAlliance, pinType,
    daedricArtifactId, lastObjectiveControlState)

    self:CacheVolendrungName(daedricArtifactId)

    if lastObjectiveControlState == OBJECTIVE_CONTROL_STATE_UNKNOWN
    and objectiveControlState ~= OBJECTIVE_CONTROL_STATE_UNKNOWN then
        self.volendrung = {
            texture        = GetVolendrungTexture(pinType),
            holderAlliance = GetVolendrungAlliance(pinType),
            objectiveId    = objectiveObjectiveId,
            keepId         = objectiveKeepId,
            despawnAt      = nil,
            spawnedAt      = (self.volendrung and self.volendrung.spawnedAt) or GetGameTimeMilliseconds(),
        }
        self:CyroUpdateLoop()
        return
    end

    if self.volendrung and objectiveControlState ~= OBJECTIVE_CONTROL_STATE_UNKNOWN then
        self.volendrung.texture        = GetVolendrungTexture(pinType)
        self.volendrung.holderAlliance = GetVolendrungAlliance(pinType)
        self.volendrung.objectiveId    = objectiveObjectiveId
        self.volendrung.keepId         = objectiveKeepId
        self.volendrung.despawnAt      = nil
        self:CyroUpdateLoop()
    end
end

function PvPUA:OnArtifactScrollStateChanged(...)
    self:RefreshScrolls()
end

--------------------------------------------------
-- Volendrung Despawn Poll
--------------------------------------------------
function PvPUA:PollVolendrungDespawn()
    if not self.volendrung then return end

    if self.volendrung.despawnAt then
        if GetGameTimeMilliseconds() >= self.volendrung.despawnAt then
            self.volendrung = nil
            self:CyroUpdateLoop()
        end
        return
    end

    if self.volendrung.objectiveId and self.volendrung.keepId then
        local objectiveState = select(3, GetObjectiveInfo(
            self.volendrung.keepId,
            self.volendrung.objectiveId,
            BGQUERY_LOCAL
        ))
        if objectiveState == OBJECTIVE_CONTROL_STATE_UNKNOWN or objectiveState == nil then
            self.volendrung.despawnAt = GetGameTimeMilliseconds() + VOLENDRUNG_DESPAWN_GRACE
        end
    end
end

function PvPUA:RefreshStatLabels()
    local c = self.controls
    if not c.infoKD then return end
    self:RefreshKDText()
    c.infoKD:SetHidden(false)
end

--------------------------------------------------
-- UpdateKAD
--------------------------------------------------
local function UpdateKAD()
    if PvPUA.controls and PvPUA.controls.infoKD then
        PvPUA:RefreshKDText()
    end
end

--------------------------------------------------
-- OnPlayerActivated
--------------------------------------------------
function PvPUA:ZoneCheck()
    if IsInCyrodiilOrIC() == true then
        local zoneKind = IsInICCampaign() and "IC" or "CYRO"
        if self.initializedItems == false or self.initializedZone ~= zoneKind then
            local hadVolendrung = self.volendrung
            self:InitState(hadVolendrung)
            self:ResetObjectives()
            self.initializedItems = true
            self.initializedZone = zoneKind
        end
        if self.registeredCyroEvents == false then
            EVENT_MANAGER:RegisterForEvent(PvPUA.name, EVENT_OBJECTIVE_CONTROL_STATE,
                function(...) PvPUA:OnObjectiveControlState(...) end)
            EVENT_MANAGER:RegisterForEvent(PvPUA.name, EVENT_DAEDRIC_ARTIFACT_OBJECTIVE_SPAWNED_BUT_NOT_REVEALED,
                function(...) PvPUA:OnVolendrungSpawned(...) end)
            EVENT_MANAGER:RegisterForEvent(PvPUA.name, EVENT_DAEDRIC_ARTIFACT_OBJECTIVE_STATE_CHANGED,
                function(...) PvPUA:OnVolendrungStateChanged(...) end)
            EVENT_MANAGER:RegisterForEvent(PvPUA.name, EVENT_ARTIFACT_SCROLL_STATE_CHANGED,
                function(...) PvPUA:OnArtifactScrollStateChanged(...) end)
            EVENT_MANAGER:RegisterForEvent(PvPUA.name .. "_ArtifactCtrl", EVENT_ARTIFACT_CONTROL_STATE,
                function(...) PvPUA:OnArtifactControlState(...) end)
            local regKT, regKF = "no event", "no event"
            if EVENT_KILL_LOCATIONS_UPDATED then
                regKT = tostring(EVENT_MANAGER:RegisterForEvent(PvPUA.name .. "_KillTally", EVENT_KILL_LOCATIONS_UPDATED,
                    function() pcall(function() PvPUA:KillTallyOnEvent() end) end))
            end
            -- Own namespace: upstream's KAD counter already holds PvPUA.name .. "_KillFeed" for this event
            -- (registered at load), and a second RegisterForEvent with the same name+event is rejected.
            if EVENT_PVP_KILL_FEED_DEATH then
                regKF = tostring(EVENT_MANAGER:RegisterForEvent(PvPUA.name .. "_KillTallyFeed", EVENT_PVP_KILL_FEED_DEATH,
                    function(_, killLocation, killerDisplayName, killerCharacterName, killerAlliance, _killerRank,
                             victimDisplayName, victimCharacterName)
                        local ok, err = pcall(function()
                            PvPUA:KillFeedOnDeath(killLocation, killerDisplayName, killerCharacterName, killerAlliance,
                                                  victimDisplayName, victimCharacterName)
                        end)
                        if not ok then DLog("KF handler error: %s", tostring(err)) end
                    end))
            end
            DL.last = {} -- fresh zone: state lines log again
            DLog("v%s %s: registered EVENT_KILL_LOCATIONS_UPDATED=%s EVENT_PVP_KILL_FEED_DEATH=%s; api GetNumKillLocations=%s GetKillLocationPinInfo=%s GetNumKillLocationAllianceKills=%s",
                 tostring(PvPUA.version), zoneKind, regKT, regKF, type(GetNumKillLocations), type(GetKillLocationPinInfo),
                 type(GetNumKillLocationAllianceKills))
            if EVENT_REWARD_TRACK_PROGRESS_GAINED then
                EVENT_MANAGER:RegisterForEvent(PvPUA.name .. "_VetTrack", EVENT_REWARD_TRACK_PROGRESS_GAINED,
                    function(_, trackType)
                        if trackType == REWARD_TRACK_TYPE_AVA_VETERANCY then
                            PvPUA:RefreshRankLabel()
                        end
                    end)
            end
            EVENT_MANAGER:RegisterForUpdate(PvPUA.name, PvPUA.constants.updateInterval,
                function()
                    pcall(function()
                        PvPUA:CyroUpdateLoop()
                        PvPUA:PollVolendrungDespawn()
                    end)
                end)
            self.registeredCyroEvents = true
        end
    else
        if self.registeredCyroEvents == true then
            EVENT_MANAGER:UnregisterForEvent(PvPUA.name, EVENT_OBJECTIVE_CONTROL_STATE)
            EVENT_MANAGER:UnregisterForEvent(PvPUA.name, EVENT_DAEDRIC_ARTIFACT_OBJECTIVE_SPAWNED_BUT_NOT_REVEALED)
            EVENT_MANAGER:UnregisterForEvent(PvPUA.name, EVENT_DAEDRIC_ARTIFACT_OBJECTIVE_STATE_CHANGED)
            EVENT_MANAGER:UnregisterForEvent(PvPUA.name, EVENT_ARTIFACT_SCROLL_STATE_CHANGED)
            EVENT_MANAGER:UnregisterForEvent(PvPUA.name .. "_ArtifactCtrl", EVENT_ARTIFACT_CONTROL_STATE)
            if EVENT_KILL_LOCATIONS_UPDATED then
                EVENT_MANAGER:UnregisterForEvent(PvPUA.name .. "_KillTally", EVENT_KILL_LOCATIONS_UPDATED)
            end
            if EVENT_PVP_KILL_FEED_DEATH then
                EVENT_MANAGER:UnregisterForEvent(PvPUA.name .. "_KillTallyFeed", EVENT_PVP_KILL_FEED_DEATH)
            end
            if EVENT_REWARD_TRACK_PROGRESS_GAINED then
                EVENT_MANAGER:UnregisterForEvent(PvPUA.name .. "_VetTrack", EVENT_REWARD_TRACK_PROGRESS_GAINED)
            end
            EVENT_MANAGER:UnregisterForUpdate(PvPUA.name)
            self.registeredCyroEvents = false
            DLog("left Cyrodiil/IC: kill events unregistered")
        end
        self.initializedItems = false
        self.volendrung = nil
        self.volendrungName    = nil
        self.controls.TLW:SetHidden(true)
        self.controls.creditLabel:SetHidden(true)
        self.controls.scoreRow:SetHidden(true)
        self.controls.infoBg:SetHidden(true)
        self.controls.infoRankIcon:SetHidden(true)
        self.controls.infoEmpIcon:SetHidden(true)
        self.controls.infoBarBg:SetHidden(true)
        self.controls.infoBar:SetHidden(true)
        self.controls.infoRankNum:SetHidden(true)
        self.controls.infoAPText:SetHidden(true)
        self.controls.infoKD:SetHidden(true)
    end
    PvPUA:UpdateHUDScenes()
end

function PvPUA:OnPlayerActivated()
    PI.StartPolling()
    PI.ScheduleGroupRefresh()
    self:RefreshQueueSoon()

    self:ZoneCheck()

    zo_callLater(function() PvPUA:UpdateHUDScenes() end, 500)
    zo_callLater(function() PvPUA:RefreshRankLabel() end, 2000)
    if PvPUA_RefreshRespawnButtons then PvPUA_RefreshRespawnButtons() end
end

--------------------------------------------------
-- Respawn Buttons
--------------------------------------------------
local function RSFindNearestKeep()
    local selfX, selfY = GetMapPlayerPosition("player")
    local bestId, bestDist
    for i = 1, GetNumKeeps() do
        local keepId = GetKeepKeysByIndex(i)
        if CanRespawnAtKeep(keepId) then
            local _, kx, ky = GetKeepPinInfo(keepId, BGQUERY_LOCAL)
            if kx ~= 0 and ky ~= 0 then
                local dist = zo_distance3D(selfX, selfY, 0, kx, ky, 0)
                if not bestDist or dist < bestDist then
                    bestId, bestDist = keepId, dist
                end
            end
        end
    end
    return bestId
end

local function RSFindNearestCamp()
    if GetNumForwardCamps(BGQUERY_LOCAL) == 0 then return nil end
    local selfX, selfY = GetMapPlayerPosition("player")
    local bestIndex, bestDist
    for i = 1, GetNumForwardCamps(BGQUERY_LOCAL) do
        local _, cx, cy, radius = GetForwardCampPinInfo(BGQUERY_LOCAL, i)
        if cx ~= 0 and cy ~= 0 and radius and radius > 0 then
            local dist = zo_distance3D(selfX, selfY, 0, cx, cy, 0)
            if dist < radius and (not bestDist or dist < bestDist) then
                bestIndex, bestDist = i, dist
            end
        end
    end
    return bestIndex
end

local function RSCampCooldownText()
    local ok, result = pcall(function()
        if not GetNextForwardCampRespawnTime then return "" end
        local nextRespawnMS = GetNextForwardCampRespawnTime()
        if not nextRespawnMS or nextRespawnMS == 0 then return "" end
        local remainingMS = nextRespawnMS - GetGameTimeMilliseconds()
        if remainingMS <= 0 then return "" end
        local totalSeconds = math.ceil(remainingMS / 1000)
        local minutes = math.floor(totalSeconds / 60)
        local seconds = totalSeconds % 60
        return string.format(" |cB4B2A9%d:%02d|r", minutes, seconds)
    end)
    if ok then return result end
    return ""
end

local function RSRespawnAtNearestKeep()
    local keepId = RSFindNearestKeep()
    if keepId then RespawnAtKeep(keepId) end
end

local function RSRespawnAtNearestCamp()
    local campIndex = RSFindNearestCamp()
    if campIndex then RespawnAtForwardCamp(campIndex) end
end

local function RSStyleButton(button)
    if button.rsStyled then return end
    button.rsStyled = true
    local template = ZO_GetPlatformTemplate("ZO_DeathKeybindButton")
    if template then
        ApplyTemplateToControl(button, template)
    end
    button:SetNormalTextColor(IsInGamepadPreferredMode() and ZO_SELECTED_TEXT or ZO_NORMAL_TEXT)
end

local function RSSetupDeathButtons()
    if not IsInCyrodiil() then return end

    local btnCamp = PvPUA_Death_ButtonsButton1
    local btnKeep = PvPUA_Death_ButtonsButton2
    if not btnCamp or not btnKeep then return end

    RSStyleButton(btnCamp)
    RSStyleButton(btnKeep)

    local aColor = GetAllianceColor(GetUnitAlliance("player")):ToHex()

    local suffix = " |cFFFFFF[|r|c" .. DC_HEX .. "P|r|c" .. AD_HEX .. "v|r|c" .. EP_HEX .. "P|r|cFF8800 UA!|r|cFFFFFF]|r"

    local campIndex = RSFindNearestCamp()
    if campIndex then
        local cooldownText = RSCampCooldownText()
        btnCamp:SetKeybind("PVPUA_RESPAWN_AT_CAMP")
        btnCamp:SetText("Respawn at |c" .. aColor .. "Forward Camp|r" .. cooldownText .. suffix)
        btnCamp:SetCallback(RSRespawnAtNearestCamp)
        btnCamp:SetEnabled(true)
        btnCamp:SetKeybindEnabled(true)
        btnCamp:SetHidden(false)
    else
        btnCamp:SetKeybind(nil)
        btnCamp:SetText("")
        btnCamp:SetCallback(nil)
        btnCamp:SetHidden(true)
    end

    local keepId = RSFindNearestKeep()
    if keepId then
        local keepName = GetKeepName(keepId) or "Keep"
        btnKeep:SetKeybind("PVPUA_RESPAWN_AT_KEEP")
        btnKeep:SetText("Respawn at |c" .. aColor .. keepName .. "|r" .. suffix)
        btnKeep:SetCallback(RSRespawnAtNearestKeep)
        btnKeep:SetEnabled(true)
        btnKeep:SetKeybindEnabled(true)
        btnKeep:SetHidden(false)
    else
        btnKeep:SetKeybind(nil)
        btnKeep:SetText("")
        btnKeep:SetCallback(nil)
        btnKeep:SetHidden(true)
    end
end

local rsButtonsShown = false

local function RSShouldShow()
    if not IsInCyrodiil() then return false end
    if not IsUnitDead("player") then return false end
    local name = SCENE_MANAGER and SCENE_MANAGER:GetCurrentSceneName()
    return name == "hud" or name == "hudui"
end

local function RSApplyVisibility()
    local control = PvPUA_Death_Buttons
    if not control then return end

    if RSShouldShow() then
        control:SetHidden(false)
        RSSetupDeathButtons()
        if not rsButtonsShown then
            rsButtonsShown = true
            control:SetHandler("OnUpdate", function() RSSetupDeathButtons() end)
        end
    else
        control:SetHidden(true)
        if rsButtonsShown then
            rsButtonsShown = false
            control:SetHandler("OnUpdate", nil)
        end
    end
end

local rsSceneHooked = false
local function RSHookScenes()
    if rsSceneHooked or not SCENE_MANAGER then return end
    rsSceneHooked = true
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function()
        RSApplyVisibility()
    end)
end

local function RSOnDeathStateChanged()
    RSHookScenes()
    RSApplyVisibility()
end

function PvPUA_RefreshRespawnButtons()
    RSOnDeathStateChanged()
end

--------------------------------------------------
-- Screen Bounds
--------------------------------------------------
local function ScreenBounds()
    local w, h
    if GuiRoot and GuiRoot.GetDimensions then w, h = GuiRoot:GetDimensions() end
    if type(w) ~= "number" or w < 640 then w = 1920 end
    if type(h) ~= "number" or h < 480 then h = 1080 end
    return math.ceil(w / 5) * 5, math.ceil(h / 5) * 5
end

--------------------------------------------------
-- Fonts
--------------------------------------------------
local EA_FONT_CHOICES = {
    { name = "Gamepad Medium",  value = "EsoUI/Common/Fonts/FTN57.otf" },
    { name = "Gamepad Bold",    value = "EsoUI/Common/Fonts/FTN87.otf" },
    { name = "Gamepad Light",   value = "EsoUI/Common/Fonts/FTN47.otf" },
    { name = "Univers Regular", value = "EsoUI/Common/Fonts/Univers57.otf" },
    { name = "Univers Light",   value = "EsoUI/Common/Fonts/univers55.otf" },
    { name = "Univers Bold",    value = "EsoUI/Common/Fonts/univers67.otf" },
    { name = "Prose Antique",   value = "EsoUI/Common/Fonts/ProseAntiquePSMT.otf" },
    { name = "Trajan Pro",      value = "EsoUI/Common/Fonts/TrajanPro-Regular.otf" },
    { name = "Handwritten",     value = "EsoUI/Common/Fonts/Handwritten_Bold.otf" },
    { name = "Arial Narrow",    value = "EsoUI/Common/Fonts/arialn.ttf" },
    { name = "Consolas",        value = "EsoUI/Common/Fonts/consola.ttf" },
}

--------------------------------------------------
-- Settings Details
--------------------------------------------------
local SAVED_ACCOUNT_TIP   = "Account wide: the same on all your characters."
local SAVED_CHARACTER_TIP = "Per character: set separately on each of your characters."
local function DetailsFont(path, size)
    return (path or "EsoUI/Common/Fonts/univers67.otf") .. "|" .. tostring(size or 45) .. "|outline"
end

--------------------------------------------------
-- Settings
--------------------------------------------------
PVPUA_ADDON_ICON = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_multiplayer.dds"

PVPUA_MENU_TITLE_COLORED = "|c" .. DC_HEX .. "P|r|c" .. AD_HEX .. "v|r|c" .. EP_HEX .. "P|r |cFF8800UA!|r"
PVPUA_TOOLTIP_AUTHOR_COLORED = "user|c" .. DC_HEX .. "5|r|c" .. AD_HEX .. "6|r|c" .. EP_HEX .. "2|r"

function PvPUA:SettingsPreviewControls()
    local controls = {}
    if self.controls and self.controls.TLW then controls[#controls + 1] = self.controls.TLW end
    if PvPUA.Potion and PvPUA.Potion.panel then controls[#controls + 1] = PvPUA.Potion.panel end
    for _, alert in pairs(self.effectAlerts or {}) do
        if type(alert) == "table" and alert.panel then controls[#controls + 1] = alert.panel end
    end
    return controls
end

function PvPUA:CreateSettings()
    local lib = rawget(_G, "PvPUAPatchLib")
    if not (lib and lib.RegisterSettings) then
        PvPUA.settingsUnavailable = true
        return
    end

    PvPUA.settingsPanel = lib:RegisterSettings({
        name            = "PvPUAPatch",
        placement       = "main",
        menuAfter       = "CAMPAIGN",
        menuTitle       = PVPUA_MENU_TITLE_COLORED,
        menuIcon        = PVPUA_ADDON_ICON,
        title           = PVPUA_MENU_TITLE_COLORED,
        author          = PVPUA_TOOLTIP_AUTHOR_COLORED,
        version         = "5.6.1",
        previewControls = function() return PvPUA:SettingsPreviewControls() end,
        textSize        = function() return PvPUA.savedVariables.settingsFontSize end,
        windowOpacity   = function() return PvPUA.savedVariables.settingsOpacity end,
        rememberPage    = function() return PvPUA.savedVariables.settingsRemember == true end,
        lastPage        = function()
            local sv = PvPUA.savedVariables
            if type(sv.settingsLastPage) ~= "table" then sv.settingsLastPage = {} end
            return sv.settingsLastPage
        end,
        accentColor     = function()
            local sv = PvPUA.savedVariables
            if sv.settingsHighlight ~= "Custom" then return nil end
            local c = sv.settingsHighlightColor
            if type(c) ~= "table" then return nil end
            return c.r or 1, c.g or 1, c.b or 1
        end,
        options         = {
            self:AppearanceMenu(),
            self:AlertsMenu(),
            self:APChatMenu(),
            self:AutoInviteMenu(),
            self:RanksMenu(),
            self:IconMenu(),
            self:SettingsMenu(),
        },
    })
    if not PvPUA.settingsPanel then PvPUA.settingsUnavailable = true end
end

--------------------------------------------------
-- Kill Feed
--------------------------------------------------
local KILL_FEED_EXPIRATION_MS = 10000
local killFeedSeen = {}

local function KFNormalize(name)
    name = zo_strformat("<<1>>", name or "")
    name = name:gsub("^@", "")
    return name:lower()
end

local function KFPlayerIdentity()
    local charName = KFNormalize(GetUnitName("player") or "")
    local displayName = ""
    local ok, dn = pcall(GetDisplayName)
    if ok and dn then displayName = KFNormalize(dn) end
    return charName, displayName
end

local function KFIsPlayer(displayName, characterName)
    local playerChar, playerDisplay = KFPlayerIdentity()
    local c = KFNormalize(characterName)
    local d = KFNormalize(displayName)
    if c ~= "" and playerChar ~= "" and c == playerChar then return true end
    if d ~= "" and playerDisplay ~= "" and d == playerDisplay then return true end
    if d ~= "" and playerChar ~= "" and d == playerChar then return true end
    if c ~= "" and playerDisplay ~= "" and c == playerDisplay then return true end
    return false
end

local function KFPreferredName(displayName, characterName)
    local d = KFNormalize(displayName)
    if d ~= "" then return d end
    return KFNormalize(characterName)
end

local function KFShouldSuppress(killerName, victimName, isKillLocation)
    local now = GetGameTimeMilliseconds()
    for key, stamp in pairs(killFeedSeen) do
        if now - stamp > KILL_FEED_EXPIRATION_MS then
            killFeedSeen[key] = nil
        end
    end
    local suffix = killerName .. "___" .. victimName
    local ownKey = (isKillLocation and "B" or "L") .. suffix
    local otherKey = (isKillLocation and "L" or "B") .. suffix
    if killFeedSeen[otherKey] ~= nil then
        killFeedSeen[otherKey] = nil
        return true
    end
    killFeedSeen[ownKey] = now
    return false
end

local function PvPUA_OnKillFeedDeath(eventCode, killLocation,
        killerDisplayName, killerCharacterName, killerAlliance, killerRank,
        victimDisplayName, victimCharacterName, victimAlliance, victimRank,
        isKillLocation)
    if not KFIsPlayer(killerDisplayName, killerCharacterName) then return end
    if KFIsPlayer(victimDisplayName, victimCharacterName) then return end
    local killerName = KFPreferredName(killerDisplayName, killerCharacterName)
    local victimName = KFPreferredName(victimDisplayName, victimCharacterName)
    if victimName == "" then return end
    if KFShouldSuppress(killerName, victimName, isKillLocation == true) then return end
    PvPUA.session.killingBlows = PvPUA.session.killingBlows + 1
    UpdateKAD()
end

--------------------------------------------------
-- Whats New
--------------------------------------------------
local WHATS_NEW_DIALOG = "PVPUA_WHATS_NEW"
local whatsNewRegistered = false

local function WhatsNewPublicIconCount()
    local count = 0
    for _, icon in ipairs(PvPUA.constants.iconChoices) do
        if not icon.none and not icon.isDefault then count = count + 1 end
    end
    return count
end

PvPUA.whatsNew = {
    version = "1.8",
    title = PVPUA_MENU_TITLE_COLORED,
    message = table.concat({
        "Updated to version 5.",
        "",
        "- Icons are now available to everyone. There are just " .. WhatsNewPublicIconCount() .. " for now.",
        "- You can change your icon's size and height.",
        "- LibGroupBroadcast is only needed for you and your group to see each other's icons.",
        "- Show now includes Small Group Frames and Large Group Frames.",
        "- If you can't see your group members' icons, first make sure you have LibGroupBroadcast. If you do, try quitting and restarting your game.",
        "- If your own icon isn't showing, try quitting and restarting your game as well.",
        "",
        "Any bugs, message me:",
        "Xbox: user562",
        "Discord: user562. (period included)",
    }, "\n"),
}

local function WhatsNewTitle()
    return PvPUA.whatsNew.title or ""
end

local function WhatsNewMessage()
    return PvPUA.whatsNew.message or ""
end

local function WhatsNewMarkSeen()
    if PvPUA.savedVariables then
        PvPUA.savedVariables.lastSeenVersion = PvPUA.whatsNew.version
    end
end

local function WhatsNewRegisterDialog()
    if whatsNewRegistered or not ZO_Dialogs_RegisterCustomDialog then return end
    ZO_Dialogs_RegisterCustomDialog(WHATS_NEW_DIALOG, {
        canQueue = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS and GAMEPAD_DIALOGS.BASIC },
        title = { text = WhatsNewTitle },
        mainText = { text = WhatsNewMessage },
        buttons = {
            { keybind = "DIALOG_PRIMARY", text = SI_OK, callback = WhatsNewMarkSeen },
        },
    })
    whatsNewRegistered = true
end

function PvPUA:ShowWhatsNew()
    WhatsNewRegisterDialog()
    if ZO_Dialogs_ShowGamepadDialog then
        ZO_Dialogs_ShowGamepadDialog(WHATS_NEW_DIALOG)
    elseif ZO_Dialogs_ShowPlatformDialog then
        ZO_Dialogs_ShowPlatformDialog(WHATS_NEW_DIALOG)
    elseif ZO_Dialogs_ShowDialog then
        ZO_Dialogs_ShowDialog(WHATS_NEW_DIALOG)
    end
end

function PvPUA:WhatsNewCheck(freshInstall)
    local wn = PvPUA.whatsNew
    if type(wn.version) ~= "string" or wn.version == "" then return end
    if not self.savedVariables then return end
    if freshInstall then
        WhatsNewMarkSeen()
        return
    end
    if self.savedVariables.lastSeenVersion == wn.version then return end
    self:ShowWhatsNew()
end

--------------------------------------------------
-- Load
--------------------------------------------------
local function OnAddonLoaded(event, addonName)
    if addonName ~= PvPUA.name then return end

    local freshInstall = (PvPUA_SavedVars == nil)

    PvPUA.savedVariables = ZO_SavedVars:NewAccountWide(
        "PvPUA_SavedVars", 27, nil,
        PvPUA.defaults
    )

    PvPUA.charVariables = ZO_SavedVars:NewCharacterIdSettings(
        "PvPUA_CharVars", 1, nil,
        PvPUA.charDefaults
    )

    PvPUA:ApplyBackdropOpacity()

    if type(PvPUA.charVariables.aiGuildToggles) ~= "table" then
        PvPUA.charVariables.aiGuildToggles = {}
    end

    if type(PvPUA.savedVariables.lastSeenVersion) ~= "string" then
        PvPUA.savedVariables.lastSeenVersion = ""
    end

    if PvPUA.charVariables.aiPvP == nil then
        PvPUA.charVariables.aiPvP = true
    end
    if PvPUA.charVariables.aiPvE == nil then
        PvPUA.charVariables.aiPvE = true
    end

    if not PvPUA.charVariables.aiGuildMigrationRepair then
        PvPUA.charVariables.aiGuildMigrated = false
        PvPUA.charVariables.aiGuildMigrationRepair = true
    end

    if not PvPUA.savedVariables.showListDeadRepair then
        PvPUA.savedVariables.showListWhileDead = true
        PvPUA.savedVariables.showListDeadRepair = true
    end

    PvPUA.savedVariables.listSize = "Default"

    if PvPUA.savedVariables.iconShowGroupFrames ~= nil then
        PvPUA.savedVariables.iconShowSmallGroupFrames = PvPUA.savedVariables.iconShowGroupFrames
        PvPUA.savedVariables.iconShowLargeGroupFrames = PvPUA.savedVariables.iconShowGroupFrames
        PvPUA.savedVariables.iconShowGroupFrames = nil
    end

    if not PvPUA.charVariables.iconMigrated then
        local sv, cv = PvPUA.savedVariables, PvPUA.charVariables
        for i = 1, #ICON_CHARACTER_KEYS do
            local key = ICON_CHARACTER_KEYS[i]
            if sv[key] ~= nil then cv[key] = sv[key] end
        end
        cv.iconMigrated = true
    end

    if not PvPUA.charVariables.groupFramesCleared then
        local cv = PvPUA.charVariables
        cv.iconShowSmallGroupFrames = false
        cv.iconShowLargeGroupFrames = false
        cv.groupFramesCleared = true
    end

    if PvPUA.Potion then
        pcall(function() PvPUA.Potion:Initialize() end)
    end

    local style = PvPUA.savedVariables.backdropStyle
    if style == "Alliance Colored" then
        PvPUA.savedVariables.backdropStyle = "Alliance"
    elseif style == "Black" then
        PvPUA.savedVariables.backdropStyle = "Custom"
        PvPUA.savedVariables.backdropColor = { r = 0, g = 0, b = 0, a = 1 }
    end

    PvPUA:ApplyListSize()
    PvPUA:CreateUI()
    PvPUA:CreateQueueUI()
    PvPUA:RegisterQueueEvents()
    PvPUA:StartQueueSafetyPoll()
    PvPUA:RefreshQueueSoon()
    PvPUA:RefreshBackdropColors()
    PvPUA:EAInit()
    local settingsOk, settingsErr = pcall(function() PvPUA:CreateSettings() end)
    if not settingsOk then
        PvPUA.settingsUnavailable = true
        PvPUA.settingsError = tostring(settingsErr)
    end

    pcall(PI.Init)
    pcall(PI.InitNetwork)
    pcall(PI.InitGroupFrameIcons)

    EVENT_MANAGER:RegisterForEvent(PvPUA.name, EVENT_PLAYER_ACTIVATED,
        function() PvPUA:OnPlayerActivated() end)

    EVENT_MANAGER:RegisterForEvent(PvPUA.name .. "_WhatsNew", EVENT_PLAYER_ACTIVATED,
        function()
            EVENT_MANAGER:UnregisterForEvent(PvPUA.name .. "_WhatsNew", EVENT_PLAYER_ACTIVATED)
            PvPUA:WhatsNewCheck(freshInstall)
        end)

    EVENT_MANAGER:RegisterForEvent(PvPUA.name .. "_ZoneChanged", EVENT_ZONE_CHANGED,
        function() PvPUA:ZoneCheck() end)

    local siegeEvents = {
        { EVENT_BEGIN_SIEGE_CONTROL, "_SiegeBegin" },
        { EVENT_END_SIEGE_CONTROL,   "_SiegeEnd" },
    }
    for i = 1, #siegeEvents do
        local eventId, suffix = siegeEvents[i][1], siegeEvents[i][2]
        if eventId ~= nil then
            EVENT_MANAGER:RegisterForEvent(PvPUA.name .. suffix, eventId,
                function() PvPUA:ApplyListVisibility() end)
        end
    end

    if not pvpIsCombatRegistered then

        if EVENT_PVP_KILL_FEED_DEATH ~= nil then
            EVENT_MANAGER:RegisterForEvent(PvPUA.name .. "_KillFeed", EVENT_PVP_KILL_FEED_DEATH,
                PvPUA_OnKillFeedDeath)
        end

        EVENT_MANAGER:RegisterForEvent(PvPUA.name .. "_Death", EVENT_PLAYER_DEAD,
            function()
                RSOnDeathStateChanged()
                PvPUA:EAClearAll()
                PvPUA:ApplyListVisibility()
                if not (IsPlayerInAvAWorld() or IsActiveWorldBattleground()) then return end
                PvPUA.session.deaths = PvPUA.session.deaths + 1
                UpdateKAD()
            end)

        EVENT_MANAGER:RegisterForEvent(PvPUA.name .. "_Alive", EVENT_PLAYER_ALIVE,
            function()
                RSOnDeathStateChanged()
                PvPUA:EAClearAll()
                PvPUA:ApplyListVisibility()
            end)

        pvpIsCombatRegistered = true
    end

    if PvPUA.charVariables.aiEnabled then
        PvPUA:AIEnableOnLoad()
    end

    if PvPUA.charVariables.aiKickOffline then
        PvPUA:AIKickStart()
    end

    EVENT_MANAGER:UnregisterForEvent(PvPUA.name, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(PvPUA.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)

--------------------------------------------------
-- Shared
--------------------------------------------------
PvPUA.util = {
    wm                    = wm,
    DC_HEX                = DC_HEX,
    AD_HEX                = AD_HEX,
    EP_HEX                = EP_HEX,
    ColorText             = ColorText,
    RainbowText           = RainbowText,
    GetColorForAlliance   = GetColorForAlliance,
    GetGuildAllianceColor = GetGuildAllianceColor,
    IsInCyrodiilOrIC      = IsInCyrodiilOrIC,
    ScreenBounds          = ScreenBounds,
    DetailsFont           = DetailsFont,
    EA_FONT_CHOICES       = EA_FONT_CHOICES,
    SAVED_ACCOUNT_TIP     = SAVED_ACCOUNT_TIP,
    SAVED_CHARACTER_TIP   = SAVED_CHARACTER_TIP,
}
