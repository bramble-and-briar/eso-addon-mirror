-- CallToArm_CTA.lua (CTA module)
-- Create or reuse the global namespace table (safe if reloaded)
local CallToArm = _G.CallToArm or {}
_G.CallToArm = CallToArm
local CALLTOARM = CallToArm
CALLTOARM.CTA = CALLTOARM.CTA or {}

local CTA = CALLTOARM.CTA
local EM = EVENT_MANAGER

CTA._initDone = CTA._initDone or false
CTA._nextPollAt = CTA._nextPollAt or 0
CTA._updateHandle = "CALLTOARM_CTA_UPDATE"
CTA._leaderboardQueryAt = CTA._leaderboardQueryAt or {}
CTA._forcePopulationOnce = CTA._forcePopulationOnce or false
CTA._campaignDataRefreshAt = CTA._campaignDataRefreshAt or 0
CTA._selectionDataReceivedAt = CTA._selectionDataReceivedAt or 0
CTA._selectionRequestSerial = CTA._selectionRequestSerial or 0
CTA._selectionReadySerial = CTA._selectionReadySerial or 0
CTA._debugNoFireCount = CTA._debugNoFireCount or 0
CTA._campaignWarmupAt = CTA._campaignWarmupAt or 0
CTA._keepChangeCheckScheduled = CTA._keepChangeCheckScheduled or false

CTA.Popup = CTA.Popup or {}

local POPUP_WIDTH = 900
local POPUP_HEIGHT = 180

local function DebugCTA(msg)
    if CALLTOARM.SV and CALLTOARM.SV.debug then
        d("|c88ccff[CALLTOARM]|r: " .. tostring(msg))
    end
end

local function EnsureCampaignDataFeed(force)
    local now = GetTimeStamp()
    if not CTA._assignedFeedRegistered then
        RegisterForAssignedCampaignData()
        CTA._assignedFeedRegistered = true
    end
    -- Campaign selection data is server-queried and completed asynchronously.
    -- Even forced/manual checks share a one-minute floor to avoid hammering it.
    if CTA._campaignDataRefreshAt ~= 0 and now - CTA._campaignDataRefreshAt < 60 then return end
    CTA._campaignDataRefreshAt = now
    CTA._selectionRequestSerial = CTA._selectionRequestSerial + 1
    QueryCampaignSelectionData()
end

local function GetAllianceIcon(alliance)
    if ZO_GetLargeAllianceSymbolIcon then
        return ZO_GetLargeAllianceSymbolIcon(alliance)
    end
    if ZO_GetAllianceSymbolIcon then
        return ZO_GetAllianceSymbolIcon(alliance)
    end
    return nil
end

local ZOS_GetAllianceColor = _G.GetAllianceColor

local function GetAllianceRGB(alliance)
    if type(ZOS_GetAllianceColor) == "function" then
        local c = ZOS_GetAllianceColor(alliance)
        if c and c.UnpackRGB then
            return c:UnpackRGB()
        end
    end
    if alliance == ALLIANCE_ALDMERI_DOMINION or alliance == 1 then
        return 1.0, 0.9, 0.2
    elseif alliance == ALLIANCE_EBONHEART_PACT or alliance == 2 then
        return 0.95, 0.3, 0.3
    elseif alliance == ALLIANCE_DAGGERFALL_COVENANT or alliance == 3 then
        return 0.3, 0.6, 1.0
    end
    return 1, 1, 1
end

local function Clamp01(value)
    local v = tonumber(value) or 0
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function RGBToHex(r, g, b)
    local rr = math.floor(Clamp01(r) * 255 + 0.5)
    local gg = math.floor(Clamp01(g) * 255 + 0.5)
    local bb = math.floor(Clamp01(b) * 255 + 0.5)
    return string.format("%02X%02X%02X", rr, gg, bb)
end

local function GetAllianceNameShort(alliance)
    local name = GetAllianceName and GetAllianceName(alliance) or ""
    if name == "" then return "Alliance" end
    if name == "Aldmeri Dominion" then name = "Dominion"
    elseif name == "Daggerfall Covenant" then name = "Covenant"
    elseif name == "Ebonheart Pact" then name = "Pact" end
    local r, g, b = GetAllianceRGB(alliance)
    return "|c" .. RGBToHex(r, g, b) .. name .. "|r"
end

-- Normalize old saved message punctuation at display time, without rewriting preferences.
local function CleanMessagePunctuation(text)
    text = tostring(text or "")
    text = text:gsub(" %- ", ", ")
    text = text:gsub("\226\128\148", ":")
    text = text:gsub("\195\162\226\130\172\226\128\157", ":")
    text = text:gsub("\226\128\147", ":")
    text = text:gsub("\195\162\226\130\172\226\128\156", ":")
    text = text:gsub("\226\128\166", ".")
    text = text:gsub("\195\162\226\130\172\194\166", ".")
    return text
end

local function BuildTextureTag(path, size)
    if not path or path == "" then return "" end
    local s = tonumber(size) or 28
    return string.format("|t%d:%d:%s|t", s, s, path)
end

local function GetGuildHeraldryData(gid)
    if not GetGuildHeraldryAttribute then return nil end
    local bgCategory, bgStyle, backgroundPrimaryColorIndex, backgroundSecondaryColorIndex, crestCategoryIndex, crestStyleIndex, crestColorIndex = GetGuildHeraldryAttribute(gid)
    if not bgCategory then return nil end

    local data = {}
    data.bgCategoryIconPath = GetHeraldryGuildFinderBackgroundCategoryIcon and GetHeraldryGuildFinderBackgroundCategoryIcon(bgCategory)
    data.bgStyleIconPath = GetHeraldryGuildFinderBackgroundStyleIcon and GetHeraldryGuildFinderBackgroundStyleIcon(bgCategory, bgStyle)
    data.crestIconPath = GetHeraldryGuildFinderCrestStyleIcon and GetHeraldryGuildFinderCrestStyleIcon(crestCategoryIndex, crestStyleIndex)

    local _, _, crestR, crestG, crestB = GetHeraldryColorInfo(crestColorIndex)
    local _, _, backgroundPrimaryR, backgroundPrimaryG, backgroundPrimaryB = GetHeraldryColorInfo(backgroundPrimaryColorIndex)
    local _, _, backgroundSecondaryR, backgroundSecondaryG, backgroundSecondaryB = GetHeraldryColorInfo(backgroundSecondaryColorIndex)

    data.crestColor = { crestR, crestG, crestB }
    data.primaryBackgroundColor = { backgroundPrimaryR, backgroundPrimaryG, backgroundPrimaryB }
    data.secondaryBackgroundColor = { backgroundSecondaryR, backgroundSecondaryG, backgroundSecondaryB }
    data.hasHeraldry = not (backgroundPrimaryColorIndex == 1 and backgroundSecondaryColorIndex == 1 and crestCategoryIndex == 1 and crestStyleIndex == 1 and crestColorIndex == 1)
    return data
end

local function GetGuildCrestIcon(gid)
    if not GetGuildHeraldryAttribute or not GetHeraldryGuildFinderCrestStyleIcon then
        return nil
    end
    local _, _, _, _, crestCategoryIndex, crestStyleIndex = GetGuildHeraldryAttribute(gid)
    if not crestCategoryIndex then return nil end
    return GetHeraldryGuildFinderCrestStyleIcon(crestCategoryIndex, crestStyleIndex)
end

local function BuildCtaCenterMessage(msg)
    return tostring(msg or "")
end

function CTA.Popup:Ensure()
    if self.control then return end
    if not WINDOW_MANAGER then return end

    local root = GuiRoot
    local control = WINDOW_MANAGER:CreateControl("CALLTOARM_CTA_Popup", root, CT_CONTROL)
    control:SetDimensions(POPUP_WIDTH, POPUP_HEIGHT)
    control:ClearAnchors()
    control:SetAnchor(CENTER, root, CENTER, 0, -150)
    control:SetHidden(true)
    control:SetMouseEnabled(false)

    local bg = WINDOW_MANAGER:CreateControl("$(parent)BG", control, CT_BACKDROP)
    bg:SetAnchorFill()
    bg:SetCenterColor(0, 0, 0, 0.7)
    bg:SetEdgeColor(0, 0, 0, 0.9)

    local banner = WINDOW_MANAGER:CreateControl("$(parent)Banner", control, CT_TEXTURE)
    banner:SetTexture("EsoUI/Art/AvA/AvA_battlegroundBanner.dds")
    banner:SetAnchorFill()
    banner:SetAlpha(0.25)

    local allianceIcon = WINDOW_MANAGER:CreateControl("$(parent)AllianceIcon", control, CT_TEXTURE)
    allianceIcon:SetDimensions(96, 96)
    allianceIcon:SetAnchor(LEFT, control, LEFT, 24, 0)

    local guildBlock = WINDOW_MANAGER:CreateControl("$(parent)GuildBlock", control, CT_CONTROL)
    guildBlock:SetDimensions(120, 120)
    guildBlock:SetAnchor(RIGHT, control, RIGHT, -24, 0)

    local guildBanner = WINDOW_MANAGER:CreateControl("$(parent)GuildBanner", guildBlock, CT_TEXTURE)
    guildBanner:SetDimensions(120, 120)
    guildBanner:SetAnchor(CENTER, guildBlock, CENTER, 0, 0)
    guildBanner:SetTexture("EsoUI/Art/Guild/guildHeraldry_background_default.dds")
    guildBanner:SetDrawLayer(DL_BACKGROUND)

    local guildPattern = WINDOW_MANAGER:CreateControl("$(parent)GuildPattern", guildBlock, CT_TEXTURE)
    guildPattern:SetDimensions(120, 120)
    guildPattern:SetAnchor(CENTER, guildBlock, CENTER, 0, 0)
    guildPattern:SetHidden(true)
    guildPattern:SetDrawLayer(DL_ARTWORK)

    local guildCrest = WINDOW_MANAGER:CreateControl("$(parent)GuildCrest", guildBlock, CT_TEXTURE)
    guildCrest:SetDimensions(120, 120)
    guildCrest:SetAnchor(CENTER, guildBlock, CENTER, 0, 0)
    guildCrest:SetHidden(true)
    guildCrest:SetDrawLayer(DL_OVERLAY)
    guildCrest:SetBlendMode(TEX_BLEND_MODE_ALPHA)

    local guildText = WINDOW_MANAGER:CreateControl("$(parent)GuildText", guildBlock, CT_LABEL)
    guildText:SetFont("ZoFontGamepad36")
    guildText:SetAnchor(CENTER, guildBlock, CENTER, 0, 0)
    guildText:SetColor(1, 1, 1, 0.9)
    guildText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    guildText:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local message = WINDOW_MANAGER:CreateControl("$(parent)Message", control, CT_LABEL)
    message:SetFont("ZoFontGamepad42")
    message:SetAnchor(CENTER, control, CENTER, 0, 0)
    message:SetDimensions(POPUP_WIDTH - 260, POPUP_HEIGHT - 40)
    message:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    message:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    message:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

    local footer = WINDOW_MANAGER:CreateControl("$(parent)Footer", control, CT_LABEL)
    footer:SetFont("ZoFontGamepad18")
    footer:SetAnchor(BOTTOMLEFT, control, BOTTOMLEFT, 16, -8)
    footer:SetColor(1, 1, 1, 0.6)
    footer:SetText("")
    footer:SetHidden(true)

    self.control = control
    self.bg = bg
    self.banner = banner
    self.allianceIcon = allianceIcon
    self.guildBanner = guildBanner
    self.guildPattern = guildPattern
    self.guildCrest = guildCrest
    self.guildText = guildText
    self.message = message
    self.footer = footer
end

function CTA.Popup:Show(args)
    if not args or not args.message or args.message == "" then
        DebugCTA("CTA Popup: missing message")
        return false
    end
    self:Ensure()
    if not self.control then
        DebugCTA("CTA Popup: control not available")
        return false
    end

    local allianceId = tonumber(args.allianceId) or 0
    local guildName = args.guildName or (args.guildId and GetGuildName(args.guildId)) or "Guild"
    local duration = tonumber(args.durationSeconds) or 6

    local icon = GetAllianceIcon(allianceId)
    if icon then
        self.allianceIcon:SetTexture(icon)
        self.allianceIcon:SetHidden(false)
    else
        self.allianceIcon:SetHidden(true)
    end

    local r, g, b = GetAllianceRGB(allianceId)
    self.bg:SetCenterColor(r, g, b, 0.2)
    self.bg:SetEdgeColor(r, g, b, 0.8)

    local heraldry = GetGuildHeraldryData(args.guildId or 0)
    if heraldry then
        self.guildBanner:SetTexture(heraldry.bgCategoryIconPath or "EsoUI/Art/Guild/guildHeraldry_background_default.dds")
        if heraldry.primaryBackgroundColor then
            self.guildBanner:SetColor(unpack(heraldry.primaryBackgroundColor))
        else
            self.guildBanner:SetColor(1, 1, 1, 1)
        end
        if heraldry.bgStyleIconPath then
            self.guildPattern:SetTexture(heraldry.bgStyleIconPath)
            if heraldry.secondaryBackgroundColor then
                self.guildPattern:SetColor(unpack(heraldry.secondaryBackgroundColor))
            else
                self.guildPattern:SetColor(1, 1, 1, 1)
            end
            self.guildPattern:SetHidden(false)
        else
            self.guildPattern:SetHidden(true)
        end
        if heraldry.crestIconPath then
            self.guildCrest:SetTexture(heraldry.crestIconPath)
            if heraldry.crestColor then
                self.guildCrest:SetColor(unpack(heraldry.crestColor))
            else
                self.guildCrest:SetColor(1, 1, 1, 1)
            end
            self.guildCrest:SetHidden(false)
        else
            self.guildCrest:SetHidden(true)
        end
        self.guildText:SetHidden(true)
    else
        self.guildBanner:SetTexture("EsoUI/Art/Guild/guildHeraldry_background_default.dds")
        self.guildBanner:SetColor(1, 1, 1, 1)
        self.guildPattern:SetHidden(true)
        local crest = GetGuildCrestIcon(args.guildId or 0)
        if crest then
            self.guildCrest:SetTexture(crest)
            self.guildCrest:SetColor(1, 1, 1, 1)
            self.guildCrest:SetHidden(false)
        else
            self.guildCrest:SetHidden(true)
        end
        self.guildText:SetText(guildName)
        self.guildText:SetHidden(false)
    end

    self.message:SetText(args.message)

    self.control:SetAlpha(1)
    self.control:SetHidden(false)

    if self._hideHandle then
        EVENT_MANAGER:UnregisterForUpdate(self._hideHandle)
    end
    self._hideHandle = "CALLTOARM_CTA_POPUP_HIDE"
    zo_callLater(function()
        if self.control then
            self.control:SetHidden(true)
        end
    end, duration * 1000)

    DebugCTA(string.format("CTA Popup: shown (%ds)", duration))
    return true
end

local function DefaultCtaState()
    return {
        lastFiredAt = {
            empPush = 0,
            dethrone = 0,
            warBegins = 0,
            warRages = 0,
            population = 0,
        },
        lastSeen = {
            top1Name = "",
            top2Name = "",
            emperorName = "",
            lastEmpKeepsOwned = -1,
            lastPopulationSummary = "",
            lastPopBars = {
                [ALLIANCE_ALDMERI_DOMINION] = -1,
                [ALLIANCE_EBONHEART_PACT] = -1,
                [ALLIANCE_DAGGERFALL_COVENANT] = -1,
            },
        },
        homeCampaignPresence = {
            wasInHomeCampaign = false,
            firedOnceWhileInHomeCampaign = false,
        },
    }
end

local function EnsureByGuild(gid)
    if not CALLTOARM.SV then return nil end
    CALLTOARM.SV.byGuild = CALLTOARM.SV.byGuild or {}
    if gid and gid ~= 0 then
        if CALLTOARM.SV.byGuild[gid] == nil then
            CALLTOARM.SV.byGuild[gid] = {}
        end
        local g = CALLTOARM.SV.byGuild[gid]
        g.campaign = g.campaign or { homeCampaignId = 0 }
        g.cta = g.cta or {}

        local cta = g.cta
        cta.enabled = cta.enabled == true
        cta.polling = cta.polling or { intervalSeconds = 1800 }
        cta.polling.intervalSeconds = tonumber(cta.polling.intervalSeconds) or 1800
        cta.doNotDisturb = cta.doNotDisturb or {
            enabled = true,
            suppressInTrials = true,
            suppressInVetDungeons = true,
            suppressInSoloActivities = true,
            suppressInInfiniteArchive = true,
            fireOnceWhileInHomeCampaign = true,
            mode = "none",
        }
        if cta.doNotDisturb.mode == nil then
            cta.doNotDisturb.mode = "none"
            if cta.doNotDisturb.enabled then
                if cta.doNotDisturb.suppressInTrials then
                    cta.doNotDisturb.mode = "mercenary"
                elseif cta.doNotDisturb.suppressInVetDungeons then
                    cta.doNotDisturb.mode = "battle"
                elseif cta.doNotDisturb.suppressInSoloActivities or cta.doNotDisturb.suppressInInfiniteArchive then
                    cta.doNotDisturb.mode = "peace"
                end
            end
        end
        if cta.doNotDisturb.mode == "trial" then cta.doNotDisturb.mode = "mercenary" end
        if cta.doNotDisturb.mode == "vet" then cta.doNotDisturb.mode = "battle" end
        if cta.doNotDisturb.mode == "solo" or cta.doNotDisturb.mode == "archive" then
            cta.doNotDisturb.mode = "peace"
        end
        cta.alerts = cta.alerts or {
            empPush = false,
            dethrone = false,
            warBegins = false,
            warRages = false,
            population = false,
        }
        if cta.alerts.population == nil then
            cta.alerts.population = false
        end
        cta.rules = cta.rules or { dethroneKeepThreshold = 3 }
        cta.display = cta.display or { popupSeconds = 6, useFancyPopup = true }
        if cta.display.useFancyPopup == nil then
            cta.display.useFancyPopup = true
        elseif cta.display.useFancyPopup == false and cta.display._migratedFancy ~= true then
            cta.display.useFancyPopup = true
            cta.display._migratedFancy = true
        end
        cta.templates = cta.templates or {
            empPush = "{Guild} needs you, {ListedPlayer} is pushing for Emperorship!",
            dethrone = "{Guild} Emperor {EmpPlayer} needs you, protect the throne!",
            warBegins = "{Guild}, {GuildAlliance} calls you to Cyrodiil, war begins!",
            warRages = "{GuildAlliance} is at war, {Guild} mount up!",
            population1 = "{Guild} The enemy begins to march",
            population2 = "{Guild} borders may be compromised",
            population3 = "{Guild} War begins, prepare for battle",
            population4 = "{Guild} Mount up! We are at war!",
        }
        if cta.templates.population1 == nil then cta.templates.population1 = "{Guild} The enemy begins to march" end
        if cta.templates.population2 == nil then cta.templates.population2 = "{Guild} borders may be compromised" end
        if cta.templates.population3 == nil then cta.templates.population3 = "{Guild} War begins, prepare for battle" end
        if cta.templates.population4 == nil then cta.templates.population4 = "{Guild} Mount up! We are at war!" end
        cta.cooldown = cta.cooldown or { seconds = 1800 }
        cta.population = cta.population or { intervalSeconds = 1800 }
        cta.population.intervalSeconds = tonumber(cta.population.intervalSeconds) or 1800
        cta.activity = cta.activity or {
            overland = true,
            groupDungeons = false,
            trials = false,
            arenasArchive = false,
            pvpOther = false,
        }
        cta.state = cta.state or DefaultCtaState()
        cta.state.lastFiredAt = cta.state.lastFiredAt or {}
        if cta.state.lastFiredAt.population == nil then
            cta.state.lastFiredAt.population = 0
        end
        cta.state.lastSeen = cta.state.lastSeen or {}
        if cta.state.lastSeen.lastPopulationSummary == nil then
            cta.state.lastSeen.lastPopulationSummary = ""
        end
        if cta.state.lastSeen.lastPopulationLevel == nil then
            cta.state.lastSeen.lastPopulationLevel = 0
        end
        if cta.state.lastSeen.lastPopulationPF == nil then
            cta.state.lastSeen.lastPopulationPF = 0
        end
        if cta.state.lastSeen.lastPopulationEC == nil then
            cta.state.lastSeen.lastPopulationEC = 0
        end
        if cta.state.lastSeen.lastPopulationStateKey == nil then
            cta.state.lastSeen.lastPopulationStateKey = ""
        end

        return g
    end
    return nil
end

local function GetRepresentedGuildId()
    if CALLTOARM.Guild and CALLTOARM.Guild.IsLockActive and CALLTOARM.Guild.IsLockActive() then
        return CALLTOARM.Guild.GetLockedGuildId()
    end
    if not CALLTOARM.SV or not CALLTOARM.SV.cta then return 0 end
    local gid = tonumber(CALLTOARM.SV.cta.representedGuildId) or 0
    if gid == 0 and CALLTOARM.Guild and CALLTOARM.Guild.GetLockedGuildId then
        gid = tonumber(CALLTOARM.Guild.GetLockedGuildId()) or 0
        if gid ~= 0 then
            CALLTOARM.SV.cta.representedGuildId = gid
        end
    end
    if gid == 0 and CALLTOARM.Guild and CALLTOARM.Guild.GetSelectedGuildId then
        gid = tonumber(CALLTOARM.Guild.GetSelectedGuildId()) or 0
    end
    return gid
end

local function GetHomeCampaignId(gid)
    local g = EnsureByGuild(gid)
    if not g then return 0 end
    return tonumber(g.campaign and g.campaign.homeCampaignId) or 0
end

local function GetGuildCtaSettings(gid)
    local g = EnsureByGuild(gid)
    if not g then return nil end
    return g.cta
end

local function EnsureCampaignHistoryScope(settings, campaignId)
    local lastSeen = settings and settings.state and settings.state.lastSeen
    if not lastSeen then return end
    if tonumber(lastSeen.campaignId) == tonumber(campaignId) then return end

    -- Observation history must never cross campaign boundaries. Cooldowns remain
    -- guild-scoped, preserving existing notification-frequency preferences.
    lastSeen.campaignId = campaignId
    lastSeen.top1Name = ""
    lastSeen.top2Name = ""
    lastSeen.emperorName = ""
    lastSeen.lastEmpKeepsOwned = -1
    lastSeen.lastPopulationCampaignId = nil
    lastSeen.lastPopulationStateKey = ""
    lastSeen.lastPopulationOwn = nil
    lastSeen.lastPopulationEnemyMax = nil
    lastSeen.lastPopulationSummary = ""
    lastSeen.lastPopBars = {
        [ALLIANCE_ALDMERI_DOMINION] = -1,
        [ALLIANCE_EBONHEART_PACT] = -1,
        [ALLIANCE_DAGGERFALL_COVENANT] = -1,
    }
end

local function IsEligibleForCTA(gid)
    for index = 1, GetNumGuilds() do
        if GetGuildId(index) == gid then return true end
    end
    return false
end

local function GetZoneDisplayTypeSafe()
    if _G.GetCurrentZoneDisplayType then
        local v = _G.GetCurrentZoneDisplayType()
        if v ~= nil then return v end
    end
    if GetZoneDisplayType and GetUnitZone then
        local zone = GetUnitZone("player")
        if type(zone) == "number" then
            local v = GetZoneDisplayType(zone)
            if v ~= nil then return v end
        end
    end
    return nil
end

local function GetCurrentGroupDifficulty()
    if GetGroupDifficulty then
        return GetGroupDifficulty()
    end
    return nil
end

local function IsTrueSoloOrCompanion()
    if not IsUnitGrouped or not IsUnitGrouped("player") then
        return true
    end
    if not GetGroupSize then return false end
    local groupSize = GetGroupSize()
    if groupSize <= 1 then return true end
    if groupSize == 2 and IsGroupCompanionUnitTag then
        for i = 1, 2 do
            local unitTag = "group" .. i
            if IsGroupCompanionUnitTag(unitTag) then
                return true
            end
        end
    end
    return false
end

local function IsInTrial()
    local inInstance = IsInInstance and IsInInstance() == true
    if not inInstance then return false end
    local displayType = GetZoneDisplayTypeSafe()
    return displayType == ZONE_DISPLAY_TYPE_TRIAL
end

local function IsInVeteranDungeon()
    local inInstance = IsInInstance and IsInInstance() == true
    if not inInstance then return false end
    local displayType = GetZoneDisplayTypeSafe()
    if displayType ~= ZONE_DISPLAY_TYPE_DUNGEON then return false end
    local difficulty = GetCurrentGroupDifficulty()
    return difficulty == GROUP_DIFFICULTY_VETERAN
end

local function IsInGroupArena()
    local inInstance = IsInInstance and IsInInstance() == true
    if not inInstance then return false end
    local displayType = GetZoneDisplayTypeSafe()
    if displayType ~= ZONE_DISPLAY_TYPE_ARENA then return false end
    return not IsTrueSoloOrCompanion()
end

local function IsInSoloActivity()
    if IsInMaelstromArena and IsInMaelstromArena() then return true end
    if IsInVeteranMaelstromArena and IsInVeteranMaelstromArena() then return true end
    local inInstance = IsInInstance and IsInInstance() == true
    if not inInstance then return false end
    local displayType = GetZoneDisplayTypeSafe()
    if displayType ~= ZONE_DISPLAY_TYPE_ARENA then return false end
    return IsTrueSoloOrCompanion()
end

local function IsInInfiniteArchive()
    if IsInstanceEndlessDungeon and IsInstanceEndlessDungeon() then return true end
    if ENDLESS_DUNGEON_MANAGER and ENDLESS_DUNGEON_MANAGER.IsPlayerInEndlessDungeon then
        return ENDLESS_DUNGEON_MANAGER:IsPlayerInEndlessDungeon()
    end
    local inInstance = IsInInstance and IsInInstance() == true
    if not inInstance then return false end
    local displayType = GetZoneDisplayTypeSafe()
    return displayType == ZONE_DISPLAY_TYPE_ENDLESS_DUNGEON
end

local function ShouldSuppressForActivity(settings)
    if not settings or not settings.doNotDisturb or settings.doNotDisturb.enabled == false then
        return false
    end
    local mode = settings.doNotDisturb.mode or "none"
    if mode == "none" then return false end
    if mode == "peace" then
        return IsInTrial() or IsInVeteranDungeon() or IsInGroupArena() or IsInSoloActivity() or IsInInfiniteArchive()
    end
    if mode == "deserter" then
        return IsInTrial() or IsInVeteranDungeon() or IsInGroupArena()
    end
    if mode == "battle" then
        return IsInTrial() or IsInVeteranDungeon()
    end
    if mode == "mercenary" then
        return IsInTrial()
    end
    if mode == "trial" then return IsInTrial() end
    if mode == "vet" then return IsInVeteranDungeon() end
    if mode == "solo" then return IsInSoloActivity() end
    if mode == "archive" then return IsInInfiniteArchive() end
    return false
end

local function GetCampaignQueryType(campaignId)
    if not campaignId or campaignId == 0 then return nil end
    local contextKey = CALLTOARM.Status.GetCampaignContextKey(
        campaignId,
        GetAssignedCampaignId and GetAssignedCampaignId() or 0,
        GetCurrentCampaignId and GetCurrentCampaignId() or 0,
        IsPlayerInAvAWorld and IsPlayerInAvAWorld() == true
    )
    if contextKey == "assigned" then return BGQUERY_ASSIGNED_CAMPAIGN end
    if contextKey == "local" then return BGQUERY_LOCAL end
    return nil
end

local function HasKeepData(campaignId)
    local context = GetCampaignQueryType(campaignId)
    if not context then return false end
    -- The initialization event can precede addon registration. Matching keep
    -- keys are the durable API availability signal once the feed is loaded.
    for i = 1, GetNumKeeps() do
        local _, availableContext = GetKeepKeysByIndex(i)
        if (context == BGQUERY_ASSIGNED_CAMPAIGN and IsAssignedBattlegroundContext(availableContext))
            or (context == BGQUERY_LOCAL and IsLocalBattlegroundContext(availableContext)) then return true end
    end
    return false
end

local function GetPopulationForCampaign(campaignId)
    if not campaignId or campaignId == 0 then return nil end
    local now = GetTimeStamp and GetTimeStamp() or 0
    if not CALLTOARM.Status or not CALLTOARM.Status.IsSelectionDataFresh(
        now,
        CTA._selectionDataReceivedAt,
        CTA._selectionRequestSerial,
        CTA._selectionReadySerial
    ) then return nil end

    if GetNumSelectionCampaigns and GetSelectionCampaignId and GetSelectionCampaignPopulationData then
        for selectionIndex = 1, GetNumSelectionCampaigns() do
            local id = GetSelectionCampaignId(selectionIndex)
            if id == campaignId then
                local population = {
                    [ALLIANCE_ALDMERI_DOMINION] = GetSelectionCampaignPopulationData(selectionIndex, ALLIANCE_ALDMERI_DOMINION),
                    [ALLIANCE_EBONHEART_PACT] = GetSelectionCampaignPopulationData(selectionIndex, ALLIANCE_EBONHEART_PACT),
                    [ALLIANCE_DAGGERFALL_COVENANT] = GetSelectionCampaignPopulationData(selectionIndex, ALLIANCE_DAGGERFALL_COVENANT),
                }
                if CALLTOARM.Status.ValidatePopulation(population) then return population end
                return nil
            end
        end
    end

    return nil
end

local function GetImperialKeepSnapshot(campaignId, referenceAlliance)
    if not HasKeepData(campaignId) then return nil, nil end
    if not GetCampaignRulesetId then return nil, nil end
    local rulesetId = GetCampaignRulesetId(campaignId)
    if not rulesetId then return nil, nil end
    local numKeeps = GetCampaignRulesetNumImperialKeeps(rulesetId, referenceAlliance)
    if not numKeeps or numKeeps <= 0 then return nil end
    local counts = {
        [ALLIANCE_ALDMERI_DOMINION] = 0,
        [ALLIANCE_EBONHEART_PACT] = 0,
        [ALLIANCE_DAGGERFALL_COVENANT] = 0,
    }
    local queryType = GetCampaignQueryType(campaignId)
    for i = 1, numKeeps do
        local keepId = GetCampaignRulesetImperialKeepId(rulesetId, referenceAlliance, i)
        if not keepId or keepId == 0 then return nil end
        local found = false
        for index = 1, GetNumKeeps() do
            local availableId, context = GetKeepKeysByIndex(index)
            if availableId == keepId and ((queryType == BGQUERY_ASSIGNED_CAMPAIGN and IsAssignedBattlegroundContext(context))
                or (queryType == BGQUERY_LOCAL and IsLocalBattlegroundContext(context))) then found = true; break end
        end
        if not found then return nil end
        local keepAlliance = GetKeepAlliance(keepId, queryType)
        if counts[keepAlliance] == nil then return nil end
        counts[keepAlliance] = counts[keepAlliance] + 1
    end
    return { counts = counts, total = numKeeps }
end

local function GetEmperorKeepsOwned(campaignId, alliance)
    -- ESO's own Emperor screen builds one six-keep set using the displayed
    -- alliance, then counts the actual owners of those same keep IDs.
    local snapshot = GetImperialKeepSnapshot(campaignId, alliance)
    if not snapshot then return nil, nil end
    return snapshot.counts[alliance], snapshot.total
end

local function IsImperialKeepForCampaign(campaignId, referenceAlliance, keepId)
    if not campaignId or campaignId == 0 or not keepId or keepId == 0 then return false end
    local rulesetId = GetCampaignRulesetId and GetCampaignRulesetId(campaignId) or nil
    if not rulesetId then return false end
    local numKeeps = GetCampaignRulesetNumImperialKeeps(rulesetId, referenceAlliance) or 0
    for index = 1, numKeeps do
        if GetCampaignRulesetImperialKeepId(rulesetId, referenceAlliance, index) == keepId then return true end
    end
    return false
end

local function ExpandTemplate(template, replacements)
    local text = CleanMessagePunctuation(template)
    for key, value in pairs(replacements or {}) do
        text = text:gsub("{" .. key .. "}", tostring(value or ""))
    end
    return text
end

local function WrapCenterMessage(text, maxChars)
    local limit = tonumber(maxChars) or 64
    local s = tostring(text or "")
    if s == "" or #s <= limit then return s end
    local out = {}
    local line = ""
    for word in s:gmatch("%S+") do
        if #line == 0 then
            line = word
        elseif (#line + 1 + #word) <= limit then
            line = line .. " " .. word
        else
            out[#out + 1] = line
            line = word
        end
    end
    if line ~= "" then out[#out + 1] = line end
    return table.concat(out, "\n")
end

local function Lower(text)
    text = tostring(text or "")
    if zo_strlower then
        return zo_strlower(text)
    end
    return string.lower(text)
end

local function GetGuildNameSafe(gid)
    if gid and gid ~= 0 then
        return GetGuildName(gid) or "Guild"
    end
    return "Guild"
end

local function IsBattlegroundWorld()
    if IsActiveWorldBattleground and IsActiveWorldBattleground() then
        return true
    end
    return false
end

local function IsInAnyDungeon()
    local inInstance = IsInInstance and IsInInstance() == true
    if not inInstance then return false end
    local displayType = GetZoneDisplayTypeSafe()
    return displayType == ZONE_DISPLAY_TYPE_DUNGEON
end

local function IsInOverlandOrPublicContent()
    local inInstance = IsInInstance and IsInInstance() == true
    if not inInstance then
        return true
    end
    local displayType = GetZoneDisplayTypeSafe()
    if displayType == nil then
        -- Treat unknown as overland to avoid suppressing alerts at login
        return true
    end
    if displayType == ZONE_DISPLAY_TYPE_PUBLIC_DUNGEON then
        return true
    end
    if displayType == ZONE_DISPLAY_TYPE_ZONE then
        return true
    end
    return false
end

local function IsInPvpOutsideHomeCampaign(homeCampaignId)
    if IsBattlegroundWorld() then
        return true
    end
    local inAvA = IsPlayerInAvAWorld and IsPlayerInAvAWorld() == true
    if not inAvA then return false end
    if GetCurrentCampaignId then
        local current = tonumber(GetCurrentCampaignId()) or 0
        if current ~= 0 and current ~= tonumber(homeCampaignId or 0) then
            return true
        end
    end
    -- Covers Imperial City / AvA maps without a matching home campaign id.
    return true
end

local function IsActivityAllowed(settings, homeCampaignId)
    local activity = settings and settings.activity
    if not activity then
        return true
    end

    -- Fast-path: open world (non-instance, non-AvA)
    local inInstance = IsInInstance and IsInInstance() == true
    local inAvA = IsPlayerInAvAWorld and IsPlayerInAvAWorld() == true
    if not inInstance then
        if not inAvA then
            return activity.overland ~= false
        end
    end

    if IsInTrial() then
        local allowed = activity.trials ~= false
        if not allowed then DebugCTA("CTA Activity: suppressed by trials filter.") end
        return allowed
    end
    if IsInAnyDungeon() then
        local allowed = activity.groupDungeons ~= false
        if not allowed then DebugCTA("CTA Activity: suppressed by group dungeon filter.") end
        return allowed
    end
    if IsInGroupArena() or IsInSoloActivity() or IsInInfiniteArchive() then
        local allowed = activity.arenasArchive ~= false
        if not allowed then DebugCTA("CTA Activity: suppressed by arena/archive filter.") end
        return allowed
    end
    if IsInPvpOutsideHomeCampaign(homeCampaignId) then
        local allowed = activity.pvpOther ~= false
        if not allowed then DebugCTA("CTA Activity: suppressed by PvP filter.") end
        return allowed
    end
    if IsInOverlandOrPublicContent() then
        local allowed = activity.overland ~= false
        if not allowed then DebugCTA("CTA Activity: suppressed by overland filter.") end
        return allowed
    end

    return true
end

local function BuildGuildMemberLookup(gid)
    local map = {}
    if not GetNumGuildMembers or not GetGuildMemberInfo then
        return map
    end
    local num = GetNumGuildMembers(gid) or 0
    for i = 1, num do
        -- API 101050: GetGuildMemberInfo returns account/display name first;
        -- the second return is the guild note, not a character name.
        local displayName = GetGuildMemberInfo(gid, i)
        if displayName and displayName ~= "" then
            map[Lower(displayName)] = true
        end

        -- Character identity is supplied separately by GetGuildMemberCharacterInfo.
        if GetGuildMemberCharacterInfo then
            local hasCharacter, characterName = GetGuildMemberCharacterInfo(gid, i)
            if hasCharacter and characterName and characterName ~= "" then
                map[Lower(characterName)] = true
            end
        end
    end
    return map
end

local function QueryLeaderboardIfNeeded(campaignId, alliance)
    if not QueryCampaignLeaderboardData then return end
    if not campaignId or campaignId == 0 or not alliance then return end
    CTA._leaderboardQueryAt = CTA._leaderboardQueryAt or {}
    local key = tostring(campaignId) .. ":" .. tostring(alliance)
    local last = CTA._leaderboardQueryAt[key] or 0
    local now = GetTimeStamp and GetTimeStamp() or 0
    if (now - last) < 120 then
        return
    end
    CTA._leaderboardQueryAt[key] = now
    -- This API requests an alliance, not an arbitrary campaign ID.
    if campaignId ~= GetAssignedCampaignId() then return end
    local ready = QueryCampaignLeaderboardData(alliance)
    if ready == LEADERBOARD_DATA_READY and GetLeaderboardCampaignSequenceId(campaignId) == GetCampaignSequenceId(campaignId) then
        CTA._leaderboardReady = CTA._leaderboardReady or {}
        CTA._leaderboardReady[key] = now
    end
end

local function CanFire(settings, alertKey)
    if CTA._debugBypassCooldownActive == true then
        return true
    end
    local cooldown = tonumber(settings.cooldown and settings.cooldown.seconds) or 600
    local last = tonumber(settings.state.lastFiredAt[alertKey]) or 0
    return (GetTimeStamp() - last) >= cooldown
end

local function MarkFired(settings, alertKey)
    settings.state.lastFiredAt[alertKey] = GetTimeStamp()
end

local function FireAlert(settings, templateKey, replacements)
    local template = settings.templates and settings.templates[templateKey] or ""
    local msg = ExpandTemplate(template, replacements)
    local duration = tonumber(settings.display and settings.display.popupSeconds) or 6
    local guildId = replacements and replacements.guildId or 0
    local allianceId = replacements and replacements.allianceId or 0

    local iconPrefix = BuildCtaCenterMessage("")
    local r, g, b = GetAllianceRGB(allianceId)
    local allianceHex = RGBToHex(r, g, b)
    local wrapped = WrapCenterMessage(msg, 64)
    local coloredMsg = string.format("|c%s%s|r", allianceHex, wrapped)
    local centerMsg = string.format("%s%s", iconPrefix, coloredMsg)

    local sound = (SOUNDS and SOUNDS.ACHIEVEMENT_AWARDED) or nil

    if CALLTOARM.UI and CALLTOARM.UI.ShowCenter then
        CALLTOARM.UI.ShowCenter(centerMsg, duration)
    elseif CENTER_SCREEN_ANNOUNCE and CENTER_SCREEN_ANNOUNCE.CreateMessageParams and CENTER_SCREEN_ANNOUNCE.DisplayMessage and sound then
        local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, sound)
        if params.SetLifespanMS and duration then
            params:SetLifespanMS(duration * 1000)
        end
        params:SetText(centerMsg)
        CENTER_SCREEN_ANNOUNCE:DisplayMessage(params)
    elseif ZO_Alert and UI_ALERT_CATEGORY_ALERT and sound then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, sound, centerMsg)
    else
        d(centerMsg)
    end
    DebugCTA("CTA Triggered: " .. tostring(templateKey))
    DebugCTA("CTA Fired: " .. tostring(msg))
end

function CTA.FormatCenterMessage(msg, guildId, allianceId)
    return BuildCtaCenterMessage(msg, guildId, allianceId)
end

local function CheckEmperorPush(gid, settings, campaignId, guildAlliance)
    if settings.alerts.empPush ~= true then return false end
    if not CanFire(settings, "empPush") then return false end
    if not HasKeepData(campaignId) then return false end
    if DoesCampaignHaveEmperor(campaignId) then
        local emperorAlliance = GetCampaignEmperorInfo(campaignId)
        if emperorAlliance == guildAlliance then return false end
    end
    local key = tostring(campaignId) .. ":" .. tostring(guildAlliance)
    local received = CTA._leaderboardReady and CTA._leaderboardReady[key]
    if not received or GetTimeStamp() - received > 120
        or GetLeaderboardCampaignSequenceId(campaignId) ~= GetCampaignSequenceId(campaignId) then return false end

    if GetNumCampaignAllianceLeaderboardEntries then
        local num = GetNumCampaignAllianceLeaderboardEntries(campaignId, guildAlliance)
        if not num or num == 0 then
            QueryLeaderboardIfNeeded(campaignId, guildAlliance)
            return false
        end
    end

    local owned, total = GetEmperorKeepsOwned(campaignId, guildAlliance)
    if not total or not owned or total == 0 or owned < 4 then
        return false
    end

    local _, rank, name, _, _, displayName = GetCampaignAllianceLeaderboardEntryInfo(campaignId, guildAlliance, 1)
    if not rank or tonumber(rank) ~= 1 then
        return false
    end

    local candidateDisplay = displayName or ""
    local candidateName = name or ""
    if candidateDisplay == "" and candidateName == "" then
        return false
    end

    local memberLookup = BuildGuildMemberLookup(gid)
    local isGuildMember = false
    if candidateDisplay ~= "" and memberLookup[Lower(candidateDisplay)] then
        isGuildMember = true
    end
    if candidateName ~= "" and memberLookup[Lower(candidateName)] then
        isGuildMember = true
    end
    DebugCTA(string.format(
        "CTA Emp Push: keeps=%d/%d rank=%s display=%s character=%s guildMember=%s",
        tonumber(owned) or 0,
        tonumber(total) or 0,
        tostring(rank),
        tostring(candidateDisplay),
        tostring(candidateName),
        tostring(isGuildMember)
    ))

    if not isGuildMember then
        return false
    end

    local topName = (candidateDisplay ~= "" and candidateDisplay) or candidateName
    settings.state.lastSeen.top1Name = topName
    FireAlert(settings, "empPush", {
        guildId = gid,
        allianceId = guildAlliance,
        Guild = GetGuildNameSafe(gid),
        ListedPlayer = topName,
        GuildAlliance = GetAllianceNameShort(guildAlliance),
    })
    MarkFired(settings, "empPush")
    return true
end

local function CheckDethrone(gid, settings, campaignId, guildAlliance)
    if settings.alerts.dethrone ~= true then return false end
    if not CanFire(settings, "dethrone") then return false end
    if not HasKeepData(campaignId) then return false end
    if not DoesCampaignHaveEmperor(campaignId) then return false end

    local emperorAlliance, emperorCharacter, emperorDisplay = GetCampaignEmperorInfo(campaignId)
    if emperorAlliance ~= guildAlliance then return false end

    local owned, total = GetEmperorKeepsOwned(campaignId, guildAlliance)
    if not total or not owned or total == 0 then return false end

    local threshold = tonumber(settings.rules.dethroneKeepThreshold) or 3
    if owned > threshold then
        settings.state.lastSeen.lastEmpKeepsOwned = owned
        return false
    end

    if not CALLTOARM.Status.ShouldRaiseThroneDefense(
        owned,
        total,
        threshold,
        settings.state.lastSeen.lastEmpKeepsOwned
    ) then
        return false
    end

    settings.state.lastSeen.lastEmpKeepsOwned = owned
    FireAlert(settings, "dethrone", {
        guildId = gid,
        allianceId = guildAlliance,
        Guild = GetGuildNameSafe(gid),
        EmpPlayer = emperorDisplay or emperorCharacter or "",
        GuildAlliance = GetAllianceNameShort(guildAlliance),
    })
    MarkFired(settings, "dethrone")
    return true
end

local function CheckWarBegins(gid, settings, campaignId, guildAlliance)
    if settings.alerts.warBegins ~= true then return false end
    if not CanFire(settings, "warBegins") then return false end
    local pop = GetPopulationForCampaign(campaignId)
    if not pop then return false end

    local lastSeen = settings.state and settings.state.lastSeen and settings.state.lastSeen.lastPopBars or {}
    local anyTransition = false
    for alliance, alliancePop in pairs(pop) do
        local last = lastSeen[alliance]
        if last == nil then last = -1 end
        if alliancePop == CAMPAIGN_POP_LOW and (last == CAMPAIGN_POP_NONE or last < CAMPAIGN_POP_LOW) then
            anyTransition = true
        end
        lastSeen[alliance] = alliancePop or -1
    end

    if not anyTransition then return false end

    FireAlert(settings, "warBegins", {
        guildId = gid,
        allianceId = guildAlliance,
        Guild = GetGuildNameSafe(gid),
        GuildAlliance = GetAllianceNameShort(guildAlliance),
    })
    MarkFired(settings, "warBegins")
    return true
end

local function CheckWarRages(gid, settings, campaignId, guildAlliance)
    if settings.alerts.warRages ~= true then return false end
    if not CanFire(settings, "warRages") then return false end
    local pop = GetPopulationForCampaign(campaignId)
    if not pop then return false end

    local hotCount = 0
    for _, alliancePop in pairs(pop) do
        if alliancePop and alliancePop >= CAMPAIGN_POP_MEDIUM then
            hotCount = hotCount + 1
        end
    end

    if hotCount < 2 then return false end

    FireAlert(settings, "warRages", {
        guildId = gid,
        allianceId = guildAlliance,
        Guild = GetGuildNameSafe(gid),
        GuildAlliance = GetAllianceNameShort(guildAlliance),
    })
    MarkFired(settings, "warRages")
    return true
end

local function BuildPopulationSummary(pop, guildAlliance)
    local state = CALLTOARM.Status.CalculatePopulationState(pop, guildAlliance)
    if not state then return "unavailable" end
    return string.format(
        "%s | own:%d enemyMax:%d enemies:%d/%d",
        string.upper(state.key),
        state.own,
        state.enemyMax,
        state.enemyOne,
        state.enemyTwo
    )
end

local function FireAlertText(settings, messageText, replacements)
    local template = tostring(messageText or "")
    local msg = ExpandTemplate(template, replacements)
    local duration = tonumber(settings.display and settings.display.popupSeconds) or 6
    local guildId = replacements and replacements.guildId or 0
    local allianceId = replacements and replacements.allianceId or 0

    local iconPrefix = BuildCtaCenterMessage("")
    local r, g, b = GetAllianceRGB(allianceId)
    local allianceHex = RGBToHex(r, g, b)
    local wrapped = WrapCenterMessage(msg, 64)
    local coloredMsg = string.format("|c%s%s|r", allianceHex, wrapped)
    local centerMsg = string.format("%s%s", iconPrefix, coloredMsg)

    local sound = (SOUNDS and SOUNDS.ACHIEVEMENT_AWARDED) or nil

    if CALLTOARM.UI and CALLTOARM.UI.ShowCenter then
        CALLTOARM.UI.ShowCenter(centerMsg, duration)
    elseif CENTER_SCREEN_ANNOUNCE and CENTER_SCREEN_ANNOUNCE.CreateMessageParams and CENTER_SCREEN_ANNOUNCE.DisplayMessage and sound then
        local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, sound)
        if params.SetLifespanMS and duration then
            params:SetLifespanMS(duration * 1000)
        end
        params:SetText(centerMsg)
        CENTER_SCREEN_ANNOUNCE:DisplayMessage(params)
    elseif ZO_Alert and UI_ALERT_CATEGORY_ALERT and sound then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, sound, centerMsg)
    else
        d(centerMsg)
    end
    DebugCTA("CTA Triggered: population tier message")
    DebugCTA("CTA Fired: " .. tostring(msg))
end

local function CheckPopulationAlert(gid, settings, campaignId, guildAlliance, force)
    if settings.alerts.population ~= true then
        DebugCTA("CTA Pop: disabled.")
        return false
    end

    local pop = GetPopulationForCampaign(campaignId)
    if not pop then
        DebugCTA("CTA Poll: population data unavailable.")
        EnsureCampaignDataFeed(true)
        return false
    end

    local lastSeen = settings.state.lastSeen
    local previous
    if tonumber(lastSeen.lastPopulationCampaignId) == campaignId
        and lastSeen.lastPopulationOwn ~= nil
        and lastSeen.lastPopulationEnemyMax ~= nil then
        previous = {
            own = tonumber(lastSeen.lastPopulationOwn),
            enemyMax = tonumber(lastSeen.lastPopulationEnemyMax),
        }
    end
    local state = CALLTOARM.Status.CalculatePopulationState(pop, guildAlliance, previous)
    if not state then
        DebugCTA("CTA Poll: population values incomplete; status unknown.")
        return false
    end

    local now = GetTimeStamp and GetTimeStamp() or 0
    local interval = tonumber(settings.population and settings.population.intervalSeconds) or 1800
    if interval < 60 then interval = 60 end

    local lastFired = tonumber(settings.state.lastFiredAt.population) or 0
    local lastStateKey = tostring(lastSeen.lastPopulationStateKey or "")
    local changed = (state.key ~= lastStateKey)

    if not force then
        if not changed and (now - lastFired) < interval then
            return false
        end
    end

    lastSeen.lastPopulationCampaignId = campaignId
    lastSeen.lastPopulationStateKey = state.key
    lastSeen.lastPopulationOwn = state.own
    lastSeen.lastPopulationEnemyMax = state.enemyMax
    lastSeen.lastPopulationPF = state.own
    lastSeen.lastPopulationEC = state.enemyOne + state.enemyTwo
    lastSeen.lastPopulationSummary = BuildPopulationSummary(pop, guildAlliance)

    local message = CALLTOARM.Status.SelectPopulationMessage(state)
    if not message then return false end

    FireAlertText(settings, message, {
        guildId = gid,
        allianceId = guildAlliance,
        Guild = GetGuildNameSafe(gid),
        GuildAlliance = GetAllianceNameShort(guildAlliance),
    })
    settings.state.lastFiredAt.population = now

    DebugCTA(string.format(
        "CTA Pop: campaign=%d state=%s direction=%s own=%d enemies=%d/%d enemyMax=%d margin=%d",
        campaignId,
        state.key,
        state.direction,
        state.own,
        state.enemyOne,
        state.enemyTwo,
        state.enemyMax,
        state.margin
    ))
    return true
end

function CTA.SetRepresentedGuild(gid)
    if not CALLTOARM.SV then return end
    CALLTOARM.SV.cta = CALLTOARM.SV.cta or {}
    CALLTOARM.SV.cta.representedGuildId = tonumber(gid) or 0
    CTA._nextPollAt = 0
end

function CTA.GetRepresentedGuildId()
    return GetRepresentedGuildId()
end

function CTA.GetGuildSettings(gid)
    return GetGuildCtaSettings(gid)
end

function CTA.SetRepresentationLock(seconds)
    CALLTOARM.SV.cta.representLockedUntil = GetTimeStamp() + (tonumber(seconds) or 600)
end

function CTA.ClearRepresentationLock()
    CALLTOARM.SV.cta.representLockedUntil = 0
end

function CTA.DebugDump(gid, campaignId)
    local settings = GetGuildCtaSettings(gid)
    if not settings then
        DebugCTA("CTA Debug: no settings for guild " .. tostring(gid))
        return
    end

    local displayType = GetZoneDisplayTypeSafe()
    local inInstance = IsInInstance and IsInInstance() == true
    local inAvA = IsPlayerInAvAWorld and IsPlayerInAvAWorld() == true

    DebugCTA("CTA Debug: ----")
    DebugCTA(string.format("CTA Debug: guildId=%s campaignId=%s alliance=%s", tostring(gid), tostring(campaignId), tostring(GetGuildAlliance(gid))))
    DebugCTA(string.format("CTA Debug: zoneDisplayType=%s inInstance=%s inAvA=%s", tostring(displayType), tostring(inInstance), tostring(inAvA)))
    DebugCTA(string.format("CTA Debug: enabled=%s cooldown=%s popInterval=%s", tostring(settings.enabled), tostring(settings.cooldown and settings.cooldown.seconds), tostring(settings.population and settings.population.intervalSeconds)))
    DebugCTA(string.format("CTA Debug: alerts empPush=%s dethrone=%s warBegins=%s warRages=%s population=%s", tostring(settings.alerts and settings.alerts.empPush), tostring(settings.alerts and settings.alerts.dethrone), tostring(settings.alerts and settings.alerts.warBegins), tostring(settings.alerts and settings.alerts.warRages), tostring(settings.alerts and settings.alerts.population)))
    DebugCTA(string.format("CTA Debug: activity overland=%s groupDungeons=%s trials=%s arenasArchive=%s pvpOther=%s", tostring(settings.activity and settings.activity.overland), tostring(settings.activity and settings.activity.groupDungeons), tostring(settings.activity and settings.activity.trials), tostring(settings.activity and settings.activity.arenasArchive), tostring(settings.activity and settings.activity.pvpOther)))
    DebugCTA(string.format("CTA Debug: DND mode=%s fireOnceHome=%s", tostring(settings.doNotDisturb and settings.doNotDisturb.mode), tostring(settings.doNotDisturb and settings.doNotDisturb.fireOnceWhileInHomeCampaign)))
    DebugCTA("CTA Debug: ----")
end

function CTA.UpdateHomeCampaignPresence(settings, inHomeCampaign)
    local presence = settings.state.homeCampaignPresence
    if inHomeCampaign then
        if not presence.wasInHomeCampaign then
            presence.wasInHomeCampaign = true
            presence.firedOnceWhileInHomeCampaign = false
        end
    else
        presence.wasInHomeCampaign = false
        presence.firedOnceWhileInHomeCampaign = false
    end
end

function CTA.RunPoll()
    local gid = GetRepresentedGuildId()
    if gid == 0 then
        DebugCTA("CTA Poll: no represented/locked guild.")
        return
    end
    local bypassCooldown = CTA._debugBypassCooldownOnce == true
    CTA._debugBypassCooldownOnce = false
    CTA._debugBypassCooldownActive = bypassCooldown
    if not IsEligibleForCTA(gid) then CTA._debugBypassCooldownActive = false; return end

    local settings = GetGuildCtaSettings(gid)
    if not settings or settings.enabled ~= true then
        DebugCTA("CTA Poll: settings disabled.")
        CTA._debugBypassCooldownActive = false
        return
    end

    DebugCTA("CTA Poll: checking alerts.")

    local guildAlliance = GetGuildAlliance(gid)
    if guildAlliance == 0 then
        DebugCTA("CTA Poll: no guild alliance.")
        CTA._debugBypassCooldownActive = false
        return
    end

    local campaignId = CTA.ResolveCampaign(gid)
    if not campaignId or campaignId == 0 then
        DebugCTA("CTA Poll: no campaign id.")
        CTA._debugBypassCooldownActive = false
        return
    end
    EnsureCampaignHistoryScope(settings, campaignId)

    if ShouldSuppressForActivity(settings) or not IsActivityAllowed(settings, campaignId) then
        local displayType = GetZoneDisplayTypeSafe() or -1
        local inInstance = IsInInstance and IsInInstance() == true
        local inAvA = IsPlayerInAvAWorld and IsPlayerInAvAWorld() == true
        DebugCTA(string.format("CTA Poll: activity suppressed (displayType=%s, inInstance=%s, inAvA=%s).", tostring(displayType), tostring(inInstance), tostring(inAvA)))
        CTA._debugBypassCooldownActive = false
        return
    end

    QueryLeaderboardIfNeeded(campaignId, guildAlliance)

    local inAvA = IsPlayerInAvAWorld and IsPlayerInAvAWorld()
    local inHomeCampaign = false
    if inAvA and GetCurrentCampaignId then
        inHomeCampaign = (GetCurrentCampaignId() == campaignId)
    end

    CTA.UpdateHomeCampaignPresence(settings, inHomeCampaign)

    if inHomeCampaign and settings.doNotDisturb and settings.doNotDisturb.fireOnceWhileInHomeCampaign then
        if settings.state.homeCampaignPresence.firedOnceWhileInHomeCampaign then
            return
        end
    end

    local forcePopulation = CTA._forcePopulationOnce == true
    CTA._forcePopulationOnce = false

    local fired = false
    fired = CheckEmperorPush(gid, settings, campaignId, guildAlliance) or fired
    fired = CheckDethrone(gid, settings, campaignId, guildAlliance) or fired
    -- These alert modes were already implemented and configurable but were not
    -- included in the polling chain, so they could never fire during normal use.
    fired = CheckWarBegins(gid, settings, campaignId, guildAlliance) or fired
    fired = CheckWarRages(gid, settings, campaignId, guildAlliance) or fired
    fired = CheckPopulationAlert(gid, settings, campaignId, guildAlliance, forcePopulation) or fired

    if not fired then
        CTA._debugNoFireCount = (CTA._debugNoFireCount or 0) + 1
        if CTA._debugNoFireCount % 10 == 0 then
            DebugCTA("CTA Poll: no alerts fired.")
        end
    end

    if fired and inHomeCampaign and settings.doNotDisturb and settings.doNotDisturb.fireOnceWhileInHomeCampaign then
        settings.state.homeCampaignPresence.firedOnceWhileInHomeCampaign = true
    end
    CTA._debugBypassCooldownActive = false
end

-- Automatic checks and requested briefings share acquisition, not notification state.
function CTA.ResolveCampaign(gid)
    local guild = CALLTOARM.Guild
    local lockActive = guild and guild.IsLockActive and guild.IsLockActive() or false
    local assigned = GetAssignedCampaignId and GetAssignedCampaignId() or 0
    return CALLTOARM.Status.ResolveCampaign({
        guildId = gid,
        lockActive = lockActive,
        lockedGuildId = lockActive and guild.GetLockedGuildId() or 0,
        lockedCampaignId = lockActive and guild.GetLockedCampaignId() or 0,
        configuredCampaignId = GetHomeCampaignId(gid),
        assignedCampaignId = assigned,
    })
end

local function BriefingLine(text)
    local line = "|c88ccff[CallToArm]|r " .. text
    if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then CHAT_SYSTEM:AddMessage(line) else d(line) end
end

local function ShowBriefing(job)
    BriefingLine(GetGuildNameSafe(job.guildId) .. ": " .. (GetCampaignName(job.campaignId) or tostring(job.campaignId)))
    local secondsUntilEnd = GetSecondsUntilCampaignEnd and GetSecondsUntilCampaignEnd(job.campaignId) or nil
    local campaignRemaining = CALLTOARM.Status.FormatCampaignRemaining(secondsUntilEnd)
    if campaignRemaining then
        BriefingLine("Campaign ends in " .. campaignRemaining .. ".")
    else
        BriefingLine("Campaign end time unavailable.")
    end
    local keepSnapshot = GetImperialKeepSnapshot(job.campaignId, job.alliance)
    if keepSnapshot then
        if DoesCampaignHaveEmperor(job.campaignId) then
            local alliance, character, display = GetCampaignEmperorInfo(job.campaignId)
            BriefingLine("Emperor: " .. ((display and display ~= "") and display or character or "Unknown") .. ": " .. GetAllianceNameShort(alliance))
        else
            BriefingLine("No current emperor reported.")
        end
        local counts = {}
        for alliance = 1, NUM_ALLIANCES do
            counts[#counts + 1] = GetAllianceNameShort(alliance) .. ": "
                .. tostring(keepSnapshot.counts[alliance]) .. "/" .. tostring(keepSnapshot.total)
        end
        BriefingLine("Imperial keeps: " .. table.concat(counts, "; "))
    else
        BriefingLine("Emperor/keep details unavailable for this campaign. No other campaign's keeps have been substituted.")
    end
    local population = GetPopulationForCampaign(job.campaignId)
    if population then
        local labels = { [CAMPAIGN_POP_LOW]="low", [CAMPAIGN_POP_MEDIUM]="medium", [CAMPAIGN_POP_HIGH]="high", [CAMPAIGN_POP_FULL]="full" }
        local parts = {}
        for alliance = 1, NUM_ALLIANCES do
            parts[#parts + 1] = GetAllianceNameShort(alliance) .. ": " .. (labels[population[alliance]] or "unavailable")
        end
        BriefingLine("Population: " .. table.concat(parts, "; "))
    else
        BriefingLine("Population information unavailable.")
    end
    local key = tostring(job.campaignId) .. ":" .. tostring(job.alliance)
    local received = CTA._leaderboardReady and CTA._leaderboardReady[key]
    if received and GetTimeStamp() - received <= 120 and GetLeaderboardCampaignSequenceId(job.campaignId) == GetCampaignSequenceId(job.campaignId)
        and GetNumCampaignAllianceLeaderboardEntries(job.campaignId, job.alliance) > 0 then
        local _, rank, name, _, _, display = GetCampaignAllianceLeaderboardEntryInfo(job.campaignId, job.alliance, 1)
        local members = BuildGuildMemberLookup(job.guildId)
        local candidate = (display and display ~= "") and display or name or "Unknown"
        local member = members[Lower(display)] or members[Lower(name)]
        BriefingLine("Alliance leader: " .. candidate .. " (rank " .. tostring(rank) .. (member and ", guild member)." or ")."))
    else
        BriefingLine("Alliance leaderboard not ready for this campaign.")
    end
end

local function FinishRequest()
    local job = CTA._pendingRequest
    CTA._pendingRequest = nil
    if not job then return end
    if not IsEligibleForCTA(job.guildId) or GetRepresentedGuildId() ~= job.guildId
        or CTA.ResolveCampaign(job.guildId) ~= job.campaignId then
        if job.manual then BriefingLine("Briefing cancelled: guild or campaign selection changed. Run again for the new selection.") end
        return
    end
    if job.manual then ShowBriefing(job) end
    if job.automatic then CTA.RunPoll() end
end

local function StartRequest(manual)
    local gid = GetRepresentedGuildId()
    if not IsEligibleForCTA(gid) then
        if manual then BriefingLine("Select a guild you belong to before requesting a briefing.") end
        return
    end
    local campaignId = CTA.ResolveCampaign(gid)
    local alliance = GetGuildAlliance(gid) or 0
    if not campaignId or campaignId == 0 or alliance == 0 then
        if manual then BriefingLine("Choose a campaign and a guild with an alliance before requesting a briefing.") end
        return
    end
    if CTA._pendingRequest then
        if manual then
            CTA._pendingRequest.manual = true
            BriefingLine("A campaign check is already pending; the briefing will follow shortly.")
        elseif CTA._pendingRequest.guildId == gid and CTA._pendingRequest.campaignId == campaignId then
            CTA._pendingRequest.automatic = true
        end
        return
    end
    CTA._pendingRequest = { guildId=gid, campaignId=campaignId, alliance=alliance, manual=manual, automatic=not manual }
    if manual then BriefingLine("Requesting campaign information.") end
    EnsureCampaignDataFeed(false)
    QueryLeaderboardIfNeeded(campaignId, alliance)
    zo_callLater(FinishRequest, 5000)
end

function CTA.RunNow()
    -- Explicit request bypasses automatic interruption filters and never marks alerts fired.
    StartRequest(true)
end

local function OnUpdate()
    local gid = GetRepresentedGuildId()
    if not IsEligibleForCTA(gid) then return end
    local settings = GetGuildCtaSettings(gid)
    if not settings or not settings.enabled then return end
    local now = GetTimeStamp()
    if CTA._pendingRequest then return end
    if now < CTA._nextPollAt then return end
    CTA._nextPollAt = now + math.max(60, tonumber(settings.polling.intervalSeconds) or 1800)
    local campaignId = CTA.ResolveCampaign(gid)
    if ShouldSuppressForActivity(settings) or not IsActivityAllowed(settings, campaignId) then return end
    StartRequest(false)
end

function CTA.Init()
    if CTA._initDone then return end
    CTA._initDone = true
    CTA._leaderboardReady = {}
    EM:RegisterForUpdate(CTA._updateHandle, 1000, OnUpdate)
    EM:RegisterForEvent("CALLTOARM_CTA_SELECTION", EVENT_CAMPAIGN_SELECTION_DATA_CHANGED, function()
        CTA._selectionDataReceivedAt = GetTimeStamp()
        CTA._selectionReadySerial = CTA._selectionRequestSerial
        if CTA._pendingRequest then zo_callLater(FinishRequest, 100) end
    end)
    EM:RegisterForEvent("CALLTOARM_CTA_LB", EVENT_CAMPAIGN_LEADERBOARD_DATA_RECEIVED, function(_, campaignId, alliance)
        CTA._leaderboardReady[tostring(campaignId) .. ":" .. tostring(alliance)] = GetTimeStamp()
    end)
    EM:RegisterForEvent("CALLTOARM_CTA_KEEP_OWNER", EVENT_KEEP_ALLIANCE_OWNER_CHANGED, function(_, keepId, battlegroundContext, owningAlliance, oldOwningAlliance)
        if owningAlliance == oldOwningAlliance or CTA._keepChangeCheckScheduled then return end
        local gid = GetRepresentedGuildId()
        if not IsEligibleForCTA(gid) then return end
        local campaignId = CTA.ResolveCampaign(gid)
        local queryType = GetCampaignQueryType(campaignId)
        local contextMatches = (queryType == BGQUERY_ASSIGNED_CAMPAIGN and IsAssignedBattlegroundContext(battlegroundContext))
            or (queryType == BGQUERY_LOCAL and IsLocalBattlegroundContext(battlegroundContext))
        if not contextMatches then return end
        if not IsImperialKeepForCampaign(campaignId, GetGuildAlliance(gid), keepId) then return end

        -- One ownership action can emit several related updates. Coalesce them,
        -- then re-read the complete six-keep snapshot before deciding.
        CTA._keepChangeCheckScheduled = true
        zo_callLater(function()
            CTA._keepChangeCheckScheduled = false
            CTA.RunPoll()
        end, 1000)
    end)
    -- Data callbacks populate caches but never bypass the user's check schedule.
    EM:RegisterForEvent("CALLTOARM_CTA_ACTIVATED", EVENT_PLAYER_ACTIVATED, function()
        local gid = GetRepresentedGuildId()
        if IsEligibleForCTA(gid) then
            local settings = GetGuildCtaSettings(gid)
            local campaignId = CTA.ResolveCampaign(gid)
            CTA.UpdateHomeCampaignPresence(settings, IsPlayerInAvAWorld() and GetCurrentCampaignId() == campaignId)
            -- Zone entry is an extra check, not a reset of the periodic schedule.
            -- RunPoll rechecks filters at delivery and retains each alert's cooldown.
            if settings.enabled and not ShouldSuppressForActivity(settings)
                and IsActivityAllowed(settings, campaignId) then
                StartRequest(false)
            end
        end
    end)
    EM:RegisterForEvent("CALLTOARM_CTA_DEACTIVATED", EVENT_PLAYER_DEACTIVATED, function()
        if CTA._assignedFeedRegistered and UnregisterForAssignedCampaignData then
            UnregisterForAssignedCampaignData()
            CTA._assignedFeedRegistered = false
        end
    end)
    SLASH_COMMANDS["/ctanow"] = CTA.RunNow
end

