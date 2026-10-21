KwibusRandomThings = KwibusRandomThings or {}
local KRT = KwibusRandomThings
local EM = EVENT_MANAGER
local ADDON_NAME = KRT.name

local TRIAL_ZONES = KRT.TRIAL_ZONES
local ARENA_ZONES = KRT.ARENA_ZONES

local DEFAULTS = { eal = {
    enabled = true,
    showIndicator = true,
    chatNotifications = false,
    delaySeconds = 5,
    logNormal = false,
    logTrials = true,
    logDungeons = false,
    logArenas = false,
    logHouses = false,
    logPvP = false,
    indicatorUnlocked = false,
    indicatorLeft = nil,
    indicatorTop = nil,
} }

KRT.EAL = {
    id = "eal",
    defaults = DEFAULTS.eal,
    indicator = nil,
    label = nil,
    bg = nil,
    indicatorFragment = nil,
    lastKnownLogState = nil,
    refreshCounter = 0,
    _updateLoopRegistered = false,
}

function KRT.EAL:SV()
    return KRT.GetModuleSV(self.id, self.defaults)
end

local function SV() 
    return KRT.EAL:SV()
end

local function PrintChatNotification(message)
    if CHAT_ROUTER then
        CHAT_ROUTER:AddSystemMessage("[Kwibus Auto Log] " .. message)
    else
        d("[Kwibus Auto Log] " .. message)
    end
end

local function GetLocationType()
    -- 1. Check Housing
    if GetCurrentHouseOwner() ~= "" or GetCurrentZoneHouseId() ~= 0 then 
        return "HOUSE", false 
    end
    
    -- 2. Check PvP
    if IsActiveWorldBattleground() or IsInImperialCity() or IsInCyrodiil() or IsPlayerInAvAWorld() then 
        return "PVP", false 
    end

    -- 3. Check Instances (Dungeons, Arenas, Trials)
    local difficulty = GetCurrentZoneDungeonDifficulty()
    if difficulty ~= DUNGEON_DIFFICULTY_NONE then
        local isVet = (difficulty == DUNGEON_DIFFICULTY_VETERAN)
        local zoneId = GetZoneId(GetUnitZoneIndex("player"))
        local instanceType = "DUNGEON" -- Assume dungeon first

        -- Determine if it's actually an Arena or Trial dynamically
        if IsPlayerInReviveCounterRaid() then
            local reviveCounter = GetCurrentRaidStartingReviveCounters()
            local raidId = GetCurrentParticipatingRaidId()

            if (reviveCounter > 24 or raidId < 4) and raidId > 0 then
                instanceType = "TRIAL"
            elseif reviveCounter <= 24 and raidId >= 4 then
                instanceType = "ARENA"
            end
        else
            -- Failsafe: if the dynamic check fails, use our hardcoded arrays
            if TRIAL_ZONES[zoneId] then 
                instanceType = "TRIAL"
            elseif ARENA_ZONES[zoneId] or IsInstanceEndlessDungeon() then 
                instanceType = "ARENA"
            end
        end

        return instanceType, isVet
    end

    -- Failsafe for normal zones that flag IsUnitInDungeon but have NONE difficulty
    if IsUnitInDungeon("player") then
        local zoneId = GetZoneId(GetUnitZoneIndex("player"))
        if TRIAL_ZONES[zoneId] then return "TRIAL", false end
        if ARENA_ZONES[zoneId] then return "ARENA", false end
        return "DUNGEON", false
    end

    return "NONE", false
end

local function ShouldLogHere()
    local sv = SV()
    if not sv.enabled then return false end

    local locType, isVet = GetLocationType()

    -- Block normal difficulties universally if disabled (except housing/pvp)
    if (locType == "TRIAL" or locType == "DUNGEON" or locType == "ARENA") then
        if not isVet and not sv.logNormal then 
            return false 
        end
    end

    if locType == "TRIAL" then
        return sv.logTrials
    elseif locType == "DUNGEON" then
        return sv.logDungeons
    elseif locType == "ARENA" then
        return sv.logArenas
    elseif locType == "HOUSE" then
        return sv.logHouses
    elseif locType == "PVP" then
        return sv.logPvP
    end
    
    return false
end

function KRT.EAL:UpdateLoopState()
    local sv = SV()
    local shouldRun = sv and sv.enabled
    if shouldRun then
        if not self._updateLoopRegistered then
            self._updateLoopRegistered = true
            EM:RegisterForUpdate(ADDON_NAME .. "_EALUpdateLoop", 1000, function() self:OnUpdate() end)
        end
    else
        if self._updateLoopRegistered then
            self._updateLoopRegistered = false
            EM:UnregisterForUpdate(ADDON_NAME .. "_EALUpdateLoop")
        end
    end
end

function KRT.EAL:UpdateIndicatorState()
    local w = self.indicator
    if not w then return end

    self:UpdateLoopState()

    local sv = SV()

    if sv.enabled and sv.indicatorUnlocked then
        if self.indicatorFragment then
            HUD_SCENE:RemoveFragment(self.indicatorFragment)
            HUD_UI_SCENE:RemoveFragment(self.indicatorFragment)
        end
        w:SetHidden(false)
    elseif sv.enabled and sv.showIndicator then
        if self.indicatorFragment then
            HUD_SCENE:AddFragment(self.indicatorFragment)
            HUD_UI_SCENE:AddFragment(self.indicatorFragment)
        end
        if SCENE_MANAGER then
            local isHud = SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")
            w:SetHidden(not isHud)
        end
    else
        if self.indicatorFragment then
            HUD_SCENE:RemoveFragment(self.indicatorFragment)
            HUD_UI_SCENE:RemoveFragment(self.indicatorFragment)
        end
        w:SetHidden(true)
        w:SetMovable(false)
        w:SetMouseEnabled(false)
        return -- Exit early when module is disabled so we don't bother updating text/drawing bg
    end

    local isLogging = IsEncounterLogEnabled()
    local label = self.label
    if label then
        if isLogging then
            label:SetText("Logging")
            label:SetColor(0.1, 0.9, 0.1, 1)
        else
            label:SetText("No logging")
            label:SetColor(0.9, 0.1, 0.1, 1)
        end
    end

    local bg = self.bg
    if bg then
        bg:SetHidden(not sv.indicatorUnlocked)
    end

    w:SetMovable(sv.indicatorUnlocked)
    w:SetMouseEnabled(sv.indicatorUnlocked)
end

function KRT.EAL:SetEncounterLog(state)
    local currentState = IsEncounterLogEnabled()
    if currentState ~= state then
        SetEncounterLogEnabled(state)
        if SV().chatNotifications then
            if state then
                PrintChatNotification("Logging started.")
            else
                PrintChatNotification("Logging stopped.")
            end
        end
    end
    self:UpdateIndicatorState()
end

function KRT.EAL:EvaluateAndApplyLogState()
    if not SV().enabled then return end
    local shouldLog = ShouldLogHere()
    self:SetEncounterLog(shouldLog)
end

function KRT.EAL:Refresh(immediate)
    if not SV().enabled then return end
    if immediate then
        self:EvaluateAndApplyLogState()
        return
    end

    self.refreshCounter = (self.refreshCounter or 0) + 1
    local currentCounter = self.refreshCounter
    local delay = (SV().delaySeconds or 5) * 1000

    if delay > 0 then
        zo_callLater(function()
            if self.refreshCounter == currentCounter then
                self:EvaluateAndApplyLogState()
            end
        end, delay)
    else
        self:EvaluateAndApplyLogState()
    end

    -- Failsafe: Re-check 3 seconds later just in case ESO API was lagging during zone-in
    zo_callLater(function()
        if self.refreshCounter == currentCounter then
            self:EvaluateAndApplyLogState()
        end
    end, (delay > 0 and delay + 3000) or 3000)
end

function KRT.EAL:OnUpdate()
    if not SV().enabled then return end
    local isLogging = IsEncounterLogEnabled()
    if self.lastKnownLogState ~= isLogging then
        self.lastKnownLogState = isLogging
        self:UpdateIndicatorState()
    end
end

function KRT.EAL:SaveIndicatorPos()
    if not self.indicator then return end
    SV().indicatorLeft = self.indicator:GetLeft()
    SV().indicatorTop = self.indicator:GetTop()
end

function KRT.EAL:RestoreIndicatorPos()
    if not self.indicator then return end
    if SV().indicatorLeft and SV().indicatorTop then
        self.indicator:ClearAnchors()
        self.indicator:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, SV().indicatorLeft, SV().indicatorTop)
    end
end

function KRT.EAL:CenterIndicator(axis)
    local w = self.indicator
    if not w then return end

    w:ClearAnchors()
    if axis == "horizontal" then
        local currentTop = w:GetTop()
        w:SetAnchor(TOP, GuiRoot, TOP, 0, currentTop)
    elseif axis == "vertical" then
        local currentLeft = w:GetLeft()
        w:SetAnchor(LEFT, GuiRoot, LEFT, currentLeft, 0)
    end
    self:SaveIndicatorPos()
end

function KRT.EAL:Initialize()
    self.indicator = KwibusEncounterAutoLogIndicator or WINDOW_MANAGER:GetControlByName("KwibusEncounterAutoLogIndicator")
    
    if not self.indicator then 
        d("[Kwibus Auto Log] ERROR: Could not link to XML frame. Settings will not work.")
        return 
    end

    self.label = self.indicator:GetNamedChild("Label")
    self.bg = self.indicator:GetNamedChild("BG")

    self:RestoreIndicatorPos()
    self.indicator:SetHandler("OnMoveStop", function() self:SaveIndicatorPos() end)
    self.indicatorFragment = ZO_HUDFadeSceneFragment:New(self.indicator)

    self.lastKnownLogState = IsEncounterLogEnabled()

    EM:RegisterForEvent(ADDON_NAME .. "_EALPlayerActivated", EVENT_PLAYER_ACTIVATED, function() self:Refresh() end)
    EM:RegisterForEvent(ADDON_NAME .. "_EALZoneChanged", EVENT_ZONE_CHANGED, function() self:Refresh() end)

    -- Difficulty changes
    EM:RegisterForEvent(ADDON_NAME .. "_EALVet1", EVENT_VETERAN_DIFFICULTY_CHANGED, function() self:Refresh() end)
    EM:RegisterForEvent(ADDON_NAME .. "_EALVet2", EVENT_GROUP_VETERAN_DIFFICULTY_CHANGED, function() self:Refresh() end)

    -- Force initial UI state explicitly
    self:UpdateIndicatorState()
    self:Refresh()
end

function KRT.EAL:GetLAMSubmenu()
    return {
        type = "submenu",
        name = "Kwibus Auto Log",
        controls = {
            {
                type = "checkbox",
                name = "Enable Module",
                getFunc = function() return SV().enabled end,
                setFunc = function(v) 
                    SV().enabled = v
                    self:UpdateLoopState()
                    if not v then
                        self:UpdateIndicatorState() 
                    else
                        self:Refresh() 
                    end
                end,
                default = DEFAULTS.eal.enabled,
                width = "full",
            },
            {
                type = "checkbox",
                name = "Enable On-Screen Indicator",
                getFunc = function() return SV().showIndicator end,
                setFunc = function(v) SV().showIndicator = v; self:UpdateIndicatorState() end,
                default = DEFAULTS.eal.showIndicator,
                width = "full",
                disabled = function() return not SV().enabled end,
            },
            {
                type = "checkbox",
                name = "Enable Chat Notifications",
                getFunc = function() return SV().chatNotifications end,
                setFunc = function(v) SV().chatNotifications = v end,
                default = DEFAULTS.eal.chatNotifications,
                width = "full",
                disabled = function() return not SV().enabled end,
            },
            {
                type = "checkbox",
                name = "Enable Repositioning (Drag)",
                getFunc = function() return SV().indicatorUnlocked end,
                setFunc = function(v) SV().indicatorUnlocked = v; self:UpdateIndicatorState() end,
                default = DEFAULTS.eal.indicatorUnlocked,
                width = "full",
                disabled = function() return not SV().enabled or not SV().showIndicator end,
            },
            {
                type = "button",
                name = "Reset Horizontal Position",
                func = function() self:CenterIndicator("horizontal") end,
                width = "half",
                disabled = function() return not SV().enabled or not SV().showIndicator or not SV().indicatorUnlocked end,
            },
            {
                type = "button",
                name = "Reset Vertical Position",
                func = function() self:CenterIndicator("vertical") end,
                width = "half",
                disabled = function() return not SV().enabled or not SV().showIndicator or not SV().indicatorUnlocked end,
            },
            {
                type = "slider",
                name = "Start Delay (Seconds)",
                tooltip = "Seconds to wait after entering a zone before evaluating and starting/stopping logging.",
                min = 0,
                max = 10,
                step = 1,
                getFunc = function() return SV().delaySeconds end,
                setFunc = function(v) SV().delaySeconds = v end,
                default = DEFAULTS.eal.delaySeconds,
                width = "full",
                disabled = function() return not SV().enabled end,
            },
            { type = "divider" },
            {
                type = "checkbox",
                name = "Log Normal Instances",
                tooltip = "If enabled, logs Normal difficulty instances. If disabled, Normal Trials, Dungeons, and Arenas will never be logged.",
                getFunc = function() return SV().logNormal end,
                setFunc = function(v) SV().logNormal = v; self:Refresh(true) end,
                default = DEFAULTS.eal.logNormal,
                width = "full",
                disabled = function() return not SV().enabled end,
            },
            { type = "divider" },
            {
                type = "checkbox",
                name = "Trials",
                getFunc = function() return SV().logTrials end,
                setFunc = function(v) SV().logTrials = v; self:Refresh(true) end,
                default = DEFAULTS.eal.logTrials,
                width = "full",
                disabled = function() return not SV().enabled end,
            },
            {
                type = "checkbox",
                name = "Dungeons",
                getFunc = function() return SV().logDungeons end,
                setFunc = function(v) SV().logDungeons = v; self:Refresh(true) end,
                default = DEFAULTS.eal.logDungeons,
                width = "full",
                disabled = function() return not SV().enabled end,
            },
            {
                type = "checkbox",
                name = "Arenas",
                getFunc = function() return SV().logArenas end,
                setFunc = function(v) SV().logArenas = v; self:Refresh(true) end,
                default = DEFAULTS.eal.logArenas,
                width = "full",
                disabled = function() return not SV().enabled end,
            },
            {
                type = "checkbox",
                name = "Houses",
                getFunc = function() return SV().logHouses end,
                setFunc = function(v) SV().logHouses = v; self:Refresh(true) end,
                default = DEFAULTS.eal.logHouses,
                width = "full",
                disabled = function() return not SV().enabled end,
            },
            {
                type = "checkbox",
                name = "PvP (Cyrodiil/IC/BGs)",
                getFunc = function() return SV().logPvP end,
                setFunc = function(v) SV().logPvP = v; self:Refresh(true) end,
                default = DEFAULTS.eal.logPvP,
                width = "full",
                disabled = function() return not SV().enabled end,
            },
        }
    }
end

KRT:RegisterModule(KRT.EAL)