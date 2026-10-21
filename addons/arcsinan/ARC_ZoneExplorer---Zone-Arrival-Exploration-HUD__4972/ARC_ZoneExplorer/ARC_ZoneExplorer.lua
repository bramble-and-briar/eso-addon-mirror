--[[
    ARC_ZoneExplorer
    Author: @arcsinan
    Description: Displays an elegant zone arrival summary and exploration HUD upon teleporting.
                 Shows Zone Guide completion, item set collection (stickerbook), and character daily statuses.
]]

ARC_ZoneExplorer = ARC_ZoneExplorer or {}
local ADDON_NAME = "ARC_ZoneExplorer"
local ADDON_VERSION = "1.0.0"
local ADDON_AUTHOR = "@arcsinan"

ARC_ZoneExplorer.name = ADDON_NAME
ARC_ZoneExplorer.version = ADDON_VERSION
ARC_ZoneExplorer.author = ADDON_AUTHOR

local defaults = {
    language = "en",
    enabled = true,
    autoShowOnArrival = true,
    displayDuration = 8, -- seconds, 0 = stay until manually closed
    windowOpacity = 0.90,
    uiScale = 1.0,               -- UI Scale multiplier (0.50 to 1.30)
    compactMode = false,         -- Compact single-column mini HUD
    hideCompleted = false,       -- User toggle: hide 100% completed activities
    trackSkyshards = true,
    trackWayshrines = true,
    trackDelves = true,
    trackDungeons = true,
    trackBosses = true,
    trackEvents = true,
    trackLocales = true,
    trackStory = true,
    showSets = true,
    hideCompletedSets = false,   -- User toggle: hide 100% completed sets
    showDailies = true,
    trackRiding = true,
    trackWrits = true,
    windowPosition = { point = TOP, relPoint = TOP, x = 0, y = 75 },
}

-- Activities to track via Zone Guide
local ACTIVITIES = {
    { type = ZONE_COMPLETION_TYPE_SKYSHARDS,        stringId = "SI_ARC_ZE_ACT_SKYSHARDS",  key = "trackSkyshards" },
    { type = ZONE_COMPLETION_TYPE_WAYSHRINES,       stringId = "SI_ARC_ZE_ACT_WAYSHRINES", key = "trackWayshrines" },
    { type = ZONE_COMPLETION_TYPE_DELVES,           stringId = "SI_ARC_ZE_ACT_DELVES",     key = "trackDelves" },
    { type = ZONE_COMPLETION_TYPE_PUBLIC_DUNGEONS,  stringId = "SI_ARC_ZE_ACT_DUNGEONS",   key = "trackDungeons" },
    { type = ZONE_COMPLETION_TYPE_WORLD_BOSSES,     stringId = "SI_ARC_ZE_ACT_BOSSES",     key = "trackBosses" },
    { type = ZONE_COMPLETION_TYPE_WORLD_EVENTS,     stringId = "SI_ARC_ZE_ACT_EVENTS",     key = "trackEvents" },
    { type = ZONE_COMPLETION_TYPE_STRIKING_LOCALES, stringId = "SI_ARC_ZE_ACT_LOCALES",    key = "trackLocales" },
    { type = ZONE_COMPLETION_TYPE_ZONE_STORY,       stringId = "SI_ARC_ZE_ACT_STORY",      key = "trackStory" },
}

local fadeTimerId = nil
local activityLabels = {}
local setLabels = {}

-- Curated Overland Sets fallback mapping (zoneId -> array of itemSetId)
ARC_ZoneExplorer.ZONE_OVERLAND_SETS = {
    [101] = { 18, 82, 85 },     -- Eastmarch: Akaviri Dragonguard, Red Mountain, Stygian
    [57]  = { 174, 175, 176 },  -- Deshaan: Mother's Sorrow, Night Mother's Embrace, Plague Doctor
    [41]  = { 82, 83, 84 },     -- Stonefalls: Red Mountain, Silks of the Sun, Shalk Exoskeleton
    [103] = { 85, 87, 88 },     -- The Rift: Stygian, Ysgramor's Birthright, Draugr's Heritage
    [117] = { 177, 178, 179 },  -- Shadowfen: Hatchling's Shell, Swamp Raider, Robes of the Hist
    [381] = { 15, 45, 46 },     -- Auridon: Queen's Elegance, Twin Sisters, Armor of the Trainee
    [3]   = { 14, 19, 22 },     -- Glenumbra: Bloodthorn's Touch, Hide of the Werewolf, Wyrd Tree's Blessing
    [19]  = { 20, 21, 23 },     -- Stormhaven: Night Terror, Dreamer's Mantle, Vaermina's Gambit
    [20]  = { 24, 25, 26 },     -- Rivenspire: Necropotence, Vampire's Cloak, Darkstride
    [104] = { 49, 50, 51 },     -- Alik'r Desert: Order of Diagna, Sword-Singer, Robes of the Withered Hand
    [92]  = { 52, 53, 54 },     -- Bangkorai: Spriggan's Thorns, Seventh Legion Brute, Vampire Lord
    [383] = { 27, 28, 29 },     -- Grahtwood: Green Pact, Ranger's Gait, Barkskin
    [108] = { 30, 31, 32 },     -- Greenshade: Wilderqueen's Arch, Beekeeper's Gear, Shadow of the Red Mountain
    [58]  = { 33, 34, 35 },     -- Malabal Tor: Spinner's Garments, Defiler, Salvation
    [382] = { 36, 37, 38 },     -- Reaper's March: Overwhelming Surge, Skooma Smuggler, Shadow Dancer
    [844] = { 338, 339, 340 },  -- Vvardenfell: War Maiden, Defiler, Warrior-Poet
    [1011]= { 391, 392, 393 },  -- Summerset: Gryphon's Ferocity, Grace of Gloom, Wispmother's Malice
    [1086]= { 437, 438, 439 },  -- Northern Elsweyr: Crafty Alfiq, Darloc Brae, Senchal Defender
    [1160]= { 483, 484, 485 },  -- Western Skyrim: Winter's Respite, Venomous Smite, Eternal Vigor
    [1261]= { 542, 543, 544 },  -- Blackwood: Frostbite, Bog Raider, Deadlands Assassin
    [1318]= { 587, 588, 589 },  -- High Isle: Systres' Scowl, Blessing of High Isle, Steadfast's Mettle
    [1383]= { 644, 645, 646 },  -- Telvanni Peninsula: Camonna Tong, Adamant Selene, Runecarver's Blaze
    [1443]= { 692, 693, 694 },  -- West Weald: Macabre Vintage, Ayleid Refugee, Tharriker's Strike
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function FormatTimeMS(ms)
    local totalSeconds = math.floor(ms / 1000)
    local hours = math.floor(totalSeconds / 3600)
    local minutes = math.floor((totalSeconds % 3600) / 60)
    if hours > 0 then
        return string.format("%dh %02dm", hours, minutes)
    else
        return string.format("%dm", minutes)
    end
end

-- Safely queries Zone Guide completion for a given activity type
local function GetZoneActivityCount(zoneId, completionType)
    if not GetNumZoneActivitiesForZoneCompletionType or not IsZoneStoryActivityComplete then
        return 0, 0
    end
    local total = GetNumZoneActivitiesForZoneCompletionType(zoneId, completionType) or 0
    local completed = 0
    for i = 1, total do
        if IsZoneStoryActivityComplete(zoneId, completionType, i) then
            completed = completed + 1
        end
    end
    return completed, total
end

--------------------------------------------------------------------------------
-- Dynamic Layout & Scaling
--------------------------------------------------------------------------------

function ARC_ZoneExplorer:ApplyLayout()
    if not self.hud then return end
    local scale = self.savedVars.uiScale or 1.0
    self.hud:SetScale(scale)
end

--------------------------------------------------------------------------------
-- Data Query & Refresh
--------------------------------------------------------------------------------

function ARC_ZoneExplorer:RefreshData()
    if not self.hud then return end

    self:ApplyLayout()

    local isCompact = self.savedVars.compactMode
    local zoneIndex = GetUnitZoneIndex("player")
    local zoneId = GetZoneId(zoneIndex)
    local zoneName = zo_strformat("<<C:1>>", GetZoneNameByIndex(zoneIndex))
    local subzoneName = zo_strformat("<<C:1>>", GetPlayerLocationName())

    -- Update Title Texts
    ARC_ZoneExplorer_HUD_Welcome:SetText(GetString(SI_ARC_ZE_HUD_WELCOME))
    ARC_ZoneExplorer_HUD_ZoneName:SetText(zoneName)
    if subzoneName ~= "" and subzoneName ~= zoneName then
        ARC_ZoneExplorer_HUD_SubZoneName:SetText("— " .. subzoneName)
        ARC_ZoneExplorer_HUD_SubZoneName:SetHidden(false)
    else
        ARC_ZoneExplorer_HUD_SubZoneName:SetHidden(true)
    end

    -- Headers
    ARC_ZoneExplorer_HUD_ExplorationHeader:SetText(GetString(SI_ARC_ZE_HUD_EXPLORATION))
    ARC_ZoneExplorer_HUD_SetsHeader:SetText(GetString(SI_ARC_ZE_HUD_SETS))
    ARC_ZoneExplorer_HUD_DailiesHeader:SetText(GetString(SI_ARC_ZE_HUD_DAILIES))

    local actContainer = ARC_ZoneExplorer_HUD_ActivitiesList
    local setsContainer = ARC_ZoneExplorer_HUD_SetsList
    local rowY = 0
    local visibleCount = 0

    local lineHeight = isCompact and 19 or 22
    local labelFont = "ZoFontGame"

    -- 1. Populate Zone Activities
    for i, act in ipairs(ACTIVITIES) do
        local isTracked = (self.savedVars[act.key] ~= false)
        local completed, total = GetZoneActivityCount(zoneId, act.type)
        local is100Percent = (total > 0 and completed >= total)
        local shouldShow = isTracked and (total > 0) and not (self.savedVars.hideCompleted and is100Percent)

        if shouldShow then
            visibleCount = visibleCount + 1
            local label = activityLabels[visibleCount]
            if not label then
                label = WINDOW_MANAGER:CreateControl("$(parent)_ActLabel" .. visibleCount, actContainer, CT_LABEL)
                activityLabels[visibleCount] = label
            end
            label:SetFont(labelFont)
            label:ClearAnchors()
            label:SetAnchor(TOPLEFT, actContainer, TOPLEFT, 0, rowY)
            label:SetAnchor(TOPRIGHT, actContainer, TOPRIGHT, 0, rowY)

            local actName = GetString(_G[act.stringId])
            local statusColor = is100Percent and "|c00FF00" or "|c00D4FF"
            label:SetText(string.format("%s %s[%d / %d]|r", actName, statusColor, completed, total))
            label:SetHidden(false)

            rowY = rowY + lineHeight
        end
    end

    for j = visibleCount + 1, #activityLabels do
        activityLabels[j]:SetHidden(true)
    end

    -- 2. Populate Zone Item Sets
    local setRowY = 0
    local setsFound = 0
    local setLineHeight = isCompact and 19 or 20

    if self.savedVars.showSets then
        pcall(function()
            local setIds = nil
            if LibSets and LibSets.GetZoneSetIds then
                local ok, ids = pcall(LibSets.GetZoneSetIds, zoneId)
                if ok and type(ids) == "table" and #ids > 0 then
                    setIds = ids
                end
            end

            if not setIds and self.ZONE_OVERLAND_SETS then
                setIds = self.ZONE_OVERLAND_SETS[zoneId]
            end

            if setIds and #setIds > 0 then
                for _, setId in ipairs(setIds) do
                    local hasSet, setName = false, nil
                    if GetItemSetInfo then
                        hasSet, setName = GetItemSetInfo(setId)
                    end

                    if (hasSet or (setName and setName ~= "")) then
                        local unlocked = 0
                        local totalPieces = 0
                        if GetNumItemSetCollectionSlotsUnlocked then
                            unlocked = GetNumItemSetCollectionSlotsUnlocked(setId) or 0
                        end
                        if GetNumItemSetCollectionPieces then
                            totalPieces = GetNumItemSetCollectionPieces(setId) or 0
                        end

                        local isSetComplete = (totalPieces > 0 and unlocked >= totalPieces)

                        if not (self.savedVars.hideCompletedSets and isSetComplete) then
                            setsFound = setsFound + 1
                            local sLabel = setLabels[setsFound]
                            if not sLabel then
                                sLabel = WINDOW_MANAGER:CreateControl("$(parent)_SetLabel" .. setsFound, setsContainer, CT_LABEL)
                                setLabels[setsFound] = sLabel
                            end
                            sLabel:SetFont(labelFont)
                            sLabel:ClearAnchors()
                            sLabel:SetAnchor(TOPLEFT, setsContainer, TOPLEFT, 0, setRowY)
                            sLabel:SetAnchor(TOPRIGHT, setsContainer, TOPRIGHT, 0, setRowY)

                            local color = isSetComplete and "|c00FF00" or "|c00D4FF"
                            local progressText = totalPieces > 0 and string.format("%s%d/%d|r", color, unlocked, totalPieces) or ""
                            sLabel:SetText(string.format("%s: %s", tostring(setName or ("Set " .. setId)), progressText))
                            sLabel:SetHidden(false)
                            setRowY = setRowY + setLineHeight
                            if setsFound >= (isCompact and 4 or 5) then break end
                        end
                    end
                end
            end
        end)
    end

    for s = setsFound + 1, #setLabels do
        setLabels[s]:SetHidden(true)
    end

    -- 3. Populate Daily Statuses
    local hasDailies = self.savedVars.showDailies and (self.savedVars.trackRiding or self.savedVars.trackWrits)
    if hasDailies then
        if self.savedVars.trackRiding then
            local speed, maxSpeed = GetRidingStats(RIDING_TRAIN_SPEED)
            local stamina, maxStamina = GetRidingStats(RIDING_TRAIN_STAMINA)
            local carry, maxCarry = GetRidingStats(RIDING_TRAIN_CARRYING_CAPACITY)

            if speed == maxSpeed and stamina == maxStamina and carry == maxCarry then
                ARC_ZoneExplorer_HUD_RidingLabel:SetText("|c00FF00" .. GetString(SI_ARC_ZE_RIDING_MAX) .. "|r")
            else
                local timeUntilMS = GetTimeUntilCanBeTrained()
                if timeUntilMS == 0 then
                    ARC_ZoneExplorer_HUD_RidingLabel:SetText("|c00FF00" .. GetString(SI_ARC_ZE_RIDING_READY) .. "|r")
                else
                    local timeStr = FormatTimeMS(timeUntilMS)
                    ARC_ZoneExplorer_HUD_RidingLabel:SetText(string.format(GetString(SI_ARC_ZE_RIDING_COOLDOWN), timeStr))
                end
            end
            ARC_ZoneExplorer_HUD_RidingLabel:SetHidden(false)
        else
            ARC_ZoneExplorer_HUD_RidingLabel:SetHidden(true)
        end

        if self.savedVars.trackWrits then
            local activeWrits = 0
            local numQuests = GetNumJournalQuests()
            for q = 1, numQuests do
                if GetJournalQuestType(q) == QUEST_TYPE_CRAFTING then
                    activeWrits = activeWrits + 1
                end
            end

            if activeWrits > 0 then
                ARC_ZoneExplorer_HUD_WritsLabel:SetText("|cFFD700" .. string.format(GetString(SI_ARC_ZE_WRITS_PENDING), activeWrits) .. "|r")
            else
                ARC_ZoneExplorer_HUD_WritsLabel:SetText("|cAAAAAA" .. GetString(SI_ARC_ZE_WRITS_DONE) .. "|r")
            end
            ARC_ZoneExplorer_HUD_WritsLabel:SetHidden(false)
        else
            ARC_ZoneExplorer_HUD_WritsLabel:SetHidden(true)
        end

        ARC_ZoneExplorer_HUD_DailiesHeader:SetHidden(false)
    else
        ARC_ZoneExplorer_HUD_DailiesHeader:SetHidden(true)
        ARC_ZoneExplorer_HUD_RidingLabel:SetHidden(true)
        ARC_ZoneExplorer_HUD_WritsLabel:SetHidden(true)
    end

    -- 4. Apply Anchors and Window Sizing
    if isCompact then
        -- COMPACT SINGLE COLUMN MODE (400px wide, exact dynamic height)
        ARC_ZoneExplorer_HUD_Welcome:SetHidden(true)

        ARC_ZoneExplorer_HUD_ZoneName:ClearAnchors()
        ARC_ZoneExplorer_HUD_ZoneName:SetAnchor(TOPLEFT, self.hud, TOPLEFT, 16, 12)
        ARC_ZoneExplorer_HUD_ZoneName:SetFont("ZoFontHeader2")

        ARC_ZoneExplorer_HUD_SubZoneName:ClearAnchors()
        ARC_ZoneExplorer_HUD_SubZoneName:SetAnchor(LEFT, ARC_ZoneExplorer_HUD_ZoneName, RIGHT, 8, 0)
        ARC_ZoneExplorer_HUD_SubZoneName:SetFont("ZoFontGame")

        local currentY = 38

        -- Exploration section
        if visibleCount > 0 then
            ARC_ZoneExplorer_HUD_ExplorationHeader:SetHidden(false)
            ARC_ZoneExplorer_HUD_ExplorationHeader:ClearAnchors()
            ARC_ZoneExplorer_HUD_ExplorationHeader:SetAnchor(TOPLEFT, self.hud, TOPLEFT, 16, currentY)
            ARC_ZoneExplorer_HUD_ExplorationHeader:SetFont("ZoFontGameBold")
            currentY = currentY + 20

            actContainer:SetHidden(false)
            actContainer:ClearAnchors()
            actContainer:SetAnchor(TOPLEFT, self.hud, TOPLEFT, 16, currentY)
            local actH = visibleCount * lineHeight
            actContainer:SetDimensions(368, actH)
            currentY = currentY + actH + 8
        else
            ARC_ZoneExplorer_HUD_ExplorationHeader:SetHidden(true)
            actContainer:SetHidden(true)
        end

        -- Sets section
        if self.savedVars.showSets and setsFound > 0 then
            ARC_ZoneExplorer_HUD_SetsHeader:SetHidden(false)
            ARC_ZoneExplorer_HUD_SetsHeader:ClearAnchors()
            ARC_ZoneExplorer_HUD_SetsHeader:SetAnchor(TOPLEFT, self.hud, TOPLEFT, 16, currentY)
            ARC_ZoneExplorer_HUD_SetsHeader:SetFont("ZoFontGameBold")
            currentY = currentY + 20

            setsContainer:SetHidden(false)
            setsContainer:ClearAnchors()
            setsContainer:SetAnchor(TOPLEFT, self.hud, TOPLEFT, 16, currentY)
            local setH = setsFound * setLineHeight
            setsContainer:SetDimensions(368, setH)
            currentY = currentY + setH + 8
        else
            ARC_ZoneExplorer_HUD_SetsHeader:SetHidden(true)
            setsContainer:SetHidden(true)
        end

        -- Dailies section
        if hasDailies then
            ARC_ZoneExplorer_HUD_DailiesHeader:ClearAnchors()
            ARC_ZoneExplorer_HUD_DailiesHeader:SetAnchor(TOPLEFT, self.hud, TOPLEFT, 16, currentY)
            ARC_ZoneExplorer_HUD_DailiesHeader:SetFont("ZoFontGameBold")
            currentY = currentY + 20

            if self.savedVars.trackRiding then
                ARC_ZoneExplorer_HUD_RidingLabel:ClearAnchors()
                ARC_ZoneExplorer_HUD_RidingLabel:SetAnchor(TOPLEFT, self.hud, TOPLEFT, 16, currentY)
                ARC_ZoneExplorer_HUD_RidingLabel:SetFont("ZoFontGame")
                currentY = currentY + 18
            end

            if self.savedVars.trackWrits then
                ARC_ZoneExplorer_HUD_WritsLabel:ClearAnchors()
                ARC_ZoneExplorer_HUD_WritsLabel:SetAnchor(TOPLEFT, self.hud, TOPLEFT, 16, currentY)
                ARC_ZoneExplorer_HUD_WritsLabel:SetFont("ZoFontGame")
                currentY = currentY + 18
            end
            currentY = currentY + 4
        end

        local totalHeight = math.max(100, currentY + 12)
        self.hud:SetDimensions(400, totalHeight)
    else
        -- STANDARD TWO-COLUMN MODE (640 x 320)
        self.hud:SetDimensions(640, 320)

        ARC_ZoneExplorer_HUD_Welcome:SetHidden(false)
        ARC_ZoneExplorer_HUD_Welcome:ClearAnchors()
        ARC_ZoneExplorer_HUD_Welcome:SetAnchor(TOPLEFT, self.hud, TOPLEFT, 20, 14)

        ARC_ZoneExplorer_HUD_ZoneName:ClearAnchors()
        ARC_ZoneExplorer_HUD_ZoneName:SetAnchor(TOPLEFT, ARC_ZoneExplorer_HUD_Welcome, BOTTOMLEFT, 0, 0)
        ARC_ZoneExplorer_HUD_ZoneName:SetFont("ZoFontWindowTitle")

        ARC_ZoneExplorer_HUD_SubZoneName:ClearAnchors()
        ARC_ZoneExplorer_HUD_SubZoneName:SetAnchor(LEFT, ARC_ZoneExplorer_HUD_ZoneName, RIGHT, 15, 0)
        ARC_ZoneExplorer_HUD_SubZoneName:SetFont("ZoFontGameMedium")

        ARC_ZoneExplorer_HUD_ExplorationHeader:SetHidden(false)
        ARC_ZoneExplorer_HUD_ExplorationHeader:ClearAnchors()
        ARC_ZoneExplorer_HUD_ExplorationHeader:SetAnchor(TOPLEFT, self.hud, TOPLEFT, 20, 82)
        ARC_ZoneExplorer_HUD_ExplorationHeader:SetFont("ZoFontHeader")

        actContainer:SetHidden(false)
        actContainer:ClearAnchors()
        actContainer:SetAnchor(TOPLEFT, ARC_ZoneExplorer_HUD_ExplorationHeader, BOTTOMLEFT, 0, 8)
        actContainer:SetDimensions(280, 200)

        if setsFound > 0 then
            ARC_ZoneExplorer_HUD_SetsHeader:SetHidden(false)
            ARC_ZoneExplorer_HUD_SetsHeader:ClearAnchors()
            ARC_ZoneExplorer_HUD_SetsHeader:SetAnchor(TOPLEFT, self.hud, TOPLEFT, 330, 82)
            ARC_ZoneExplorer_HUD_SetsHeader:SetFont("ZoFontHeader")

            setsContainer:SetHidden(false)
            setsContainer:ClearAnchors()
            setsContainer:SetAnchor(TOPLEFT, ARC_ZoneExplorer_HUD_SetsHeader, BOTTOMLEFT, 0, 8)
            setsContainer:SetDimensions(290, 110)
        else
            ARC_ZoneExplorer_HUD_SetsHeader:SetHidden(true)
            setsContainer:SetHidden(true)
        end

        if hasDailies then
            ARC_ZoneExplorer_HUD_DailiesHeader:ClearAnchors()
            ARC_ZoneExplorer_HUD_DailiesHeader:SetAnchor(TOPLEFT, self.hud, TOPLEFT, 330, setsFound > 0 and 205 or 82)
            ARC_ZoneExplorer_HUD_DailiesHeader:SetFont("ZoFontGameBold")

            local dY = setsFound > 0 and 225 or 105
            if self.savedVars.trackRiding then
                ARC_ZoneExplorer_HUD_RidingLabel:ClearAnchors()
                ARC_ZoneExplorer_HUD_RidingLabel:SetAnchor(TOPLEFT, self.hud, TOPLEFT, 330, dY)
                dY = dY + 20
            end
            if self.savedVars.trackWrits then
                ARC_ZoneExplorer_HUD_WritsLabel:ClearAnchors()
                ARC_ZoneExplorer_HUD_WritsLabel:SetAnchor(TOPLEFT, self.hud, TOPLEFT, 330, dY)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- UI Show / Hide
--------------------------------------------------------------------------------

function ARC_ZoneExplorer:ShowHUD()
    if not self.savedVars.enabled or not self.hud then return end

    if fadeTimerId then
        EVENT_MANAGER:UnregisterForUpdate("ARC_ZoneExplorer_FadeTimer")
        fadeTimerId = nil
    end

    self:RefreshData()
    self.hud:SetAlpha(self.savedVars.windowOpacity or 0.90)
    self.hud:SetHidden(false)

    -- Auto-dismiss timer if configured
    if self.savedVars.displayDuration and self.savedVars.displayDuration > 0 then
        local hideTime = GetGameTimeMilliseconds() + (self.savedVars.displayDuration * 1000)
        EVENT_MANAGER:RegisterForUpdate("ARC_ZoneExplorer_FadeTimer", 500, function()
            if GetGameTimeMilliseconds() >= hideTime then
                EVENT_MANAGER:UnregisterForUpdate("ARC_ZoneExplorer_FadeTimer")
                ARC_ZoneExplorer:HideHUD()
            end
        end)
    end
end

function ARC_ZoneExplorer:HideHUD()
    if self.hud then
        self.hud:SetHidden(true)
    end
    if fadeTimerId then
        EVENT_MANAGER:UnregisterForUpdate("ARC_ZoneExplorer_FadeTimer")
        fadeTimerId = nil
    end
end

function ARC_ZoneExplorer:ToggleHUD()
    if self.hud and not self.hud:IsHidden() then
        self:HideHUD()
    else
        self:ShowHUD()
    end
end

--------------------------------------------------------------------------------
-- Donation / In-Game Mail to @arcsinan
--------------------------------------------------------------------------------

function ARC_ZoneExplorer.DonateGold(amount)
    local world = GetWorldName()
    if world ~= "" and not string.find(string.lower(world), "eu") then
        local warnFmt = GetString(SI_ARC_ZE_CHAT_SERVER_WARN)
        d(string.format(warnFmt, tostring(world)))
    end

    local goldAmount = tonumber(amount) or 0

    SCENE_MANAGER:Show("mailSend")
    zo_callLater(function()
        if ZO_MailSendToField then
            ZO_MailSendToField:SetText("@arcsinan")
        end
        if ZO_MailSendSubjectField then
            ZO_MailSendSubjectField:SetText("ARC Zone Explorer Donation")
        end
        if ZO_MailSendBodyField then
            local mailBody = GetString(SI_ARC_ZE_MAIL_BODY)
            ZO_MailSendBodyField:SetText(mailBody)
            ZO_MailSendBodyField:TakeFocus()
        end
        if goldAmount > 0 and QueueMoneyAttachment then
            QueueMoneyAttachment(goldAmount)
            if ZO_MailSendSendCurrency and ZO_MailSendSendCurrency.OnBeginInput then
                ZO_MailSendSendCurrency:OnBeginInput()
            end
        end
    end, 250)
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

local function OnPlayerActivated(eventCode, initial)
    if ARC_ZoneExplorer.savedVars and ARC_ZoneExplorer.savedVars.enabled and ARC_ZoneExplorer.savedVars.autoShowOnArrival then
        -- Delay slightly to allow engine to populate zone completion caches
        zo_callLater(function()
            ARC_ZoneExplorer:ShowHUD()
        end, 1200)
    end
end

local function OnAddOnLoaded(event, addonName)
    if addonName ~= ADDON_NAME then return end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    -- SavedVariables initialization (Account-wide with Megaserver isolation)
    ARC_ZoneExplorer.savedVars = ZO_SavedVars:NewAccountWide(
        "ARC_ZoneExplorer_SavedVariables",
        1,
        GetWorldName(),
        defaults,
        nil,
        nil
    )

    -- Apply Turkish if configured in SavedVariables (English remains default otherwise)
    if ARC_ZoneExplorer.savedVars.language == "tr" and ARC_ZoneExplorer.ApplyTurkishStrings then
        ARC_ZoneExplorer.ApplyTurkishStrings()
    end

    -- Hook TopLevelControl
    ARC_ZoneExplorer.hud = ARC_ZoneExplorer_HUD
    if ARC_ZoneExplorer.hud then
        -- Restore position if saved
        local pos = ARC_ZoneExplorer.savedVars.windowPosition
        if pos and pos.x and pos.y then
            ARC_ZoneExplorer.hud:ClearAnchors()
            ARC_ZoneExplorer.hud:SetAnchor(pos.point or TOP, GuiRoot, pos.relPoint or TOP, pos.x, pos.y)
        end

        ARC_ZoneExplorer.hud:SetHandler("OnMoveStop", function()
            local isValid, point, relTo, relPoint, x, y = ARC_ZoneExplorer.hud:GetAnchor(0)
            if isValid then
                ARC_ZoneExplorer.savedVars.windowPosition = { point = point, relPoint = relPoint, x = x, y = y }
            end
        end)

        local closeBtn = ARC_ZoneExplorer_HUD_CloseBtn or ARC_ZoneExplorer.hud:GetNamedChild("CloseBtn")
        if closeBtn then
            closeBtn:SetHandler("OnClicked", function()
                ARC_ZoneExplorer:HideHUD()
            end)
        end

        ARC_ZoneExplorer:ApplyLayout()
    end

    -- Register Slash Commands inside OnAddOnLoaded
    local function ToggleCmd()
        ARC_ZoneExplorer:ToggleHUD()
    end

    local function OpenSettingsCmd()
        if LibAddonMenu2 and ARC_ZoneExplorer.settingsPanel then
            LibAddonMenu2:OpenToPanel(ARC_ZoneExplorer.settingsPanel)
        else
            d("|c00D4FF[ARC Zone Explorer]|r " .. GetString(SI_ARC_ZE_TITLE))
            d("Type /zoneexplorer or /aze to toggle the HUD.")
        end
    end

    SLASH_COMMANDS["/zoneexplorer"] = ToggleCmd
    SLASH_COMMANDS["/aze"] = ToggleCmd
    SLASH_COMMANDS["/azesettings"] = OpenSettingsCmd
    SLASH_COMMANDS["/arcdonate"] = function() ARC_ZoneExplorer.DonateGold(0) end

    -- Register Player Activated for zone transitions
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_PlayerActivated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    -- Initialize Settings Panel
    if ARC_ZoneExplorer.InitializeSettings then
        ARC_ZoneExplorer:InitializeSettings()
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
