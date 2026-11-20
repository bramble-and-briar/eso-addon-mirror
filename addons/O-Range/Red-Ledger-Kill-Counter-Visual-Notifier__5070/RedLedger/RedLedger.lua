RedLedger = {}
RedLedger.name = "RedLedger"
RedLedger.version = "0.5"

local WM = WINDOW_MANAGER

local defaults = {
    posX = 0,
    posY = 0,
    unlocked = false,
    lifetimeKills = 0,
    useRoman = true,
    counterScale = 1.0,
    hideCounter = false,
    hideInPvE = true,
    playSound = true,
}

--------------------------------------------------
-- Utility
--------------------------------------------------

local function ToRoman(num)
    if num == 0 then return "N" end
    if num < 0 then return tostring(num) end

    local romans = {
        {1000, "M"}, {900, "CM"}, {500, "D"}, {400, "CD"},
        {100, "C"},  {90, "XC"},  {50, "L"},  {40, "XL"},
        {10, "X"},   {9, "IX"},   {5, "V"},   {4, "IV"},
        {1, "I"},
    }

    local result = ""
    for _, pair in ipairs(romans) do
        local value, numeral = pair[1], pair[2]
        while num >= value do
            result = result .. numeral
            num = num - value
        end
    end
    return result
end

function RedLedger:IsInPvPArea()
    return IsPlayerInAvAWorld() or IsActiveWorldBattleground()
end

function RedLedger:UpdateCounterVisibility()
    if not self.counterWindow then return end

    local shouldShow = true
    if self.saved.hideCounter then
        shouldShow = false
    elseif self.saved.hideInPvE and not self:IsInPvPArea() then
        shouldShow = false
    end

    self.counterWindow:SetHidden(not shouldShow)
end

function RedLedger:UpdateCounter()
    if not self.counterLabel then return end

    if self.saved.useRoman then
        self.counterLabel:SetText(ToRoman(self.sessionKills))
    else
        self.counterLabel:SetText(tostring(self.sessionKills))
    end
end

function RedLedger:ApplyCounterScale()
    if not self.counterWindow or not self.counterLabel then return end

    local scale = self.saved.counterScale or 1.0
    local baseW, baseH = 160, 90
    self.counterWindow:SetDimensions(baseW * scale, baseH * scale)

    -- Custom font (slug version)
    local fontSize
    if scale >= 1.8 then
        fontSize = 56
    elseif scale >= 1.5 then
        fontSize = 48
    elseif scale >= 1.2 then
        fontSize = 40
    elseif scale >= 1.0 then
        fontSize = 34
    elseif scale >= 0.8 then
        fontSize = 28
    else
        fontSize = 22
    end

    local fontString = string.format("RedLedger/font/Friday13v12.slug|%d|soft-shadow-thick", fontSize)
    self.counterLabel:SetFont(fontString)
    self.counterLabel:SetScale(1.0)
end

function RedLedger:ResetSessionCounter()
    self.sessionKills = 0
    self:UpdateCounter()
end

--------------------------------------------------
-- Counter Window
--------------------------------------------------

function RedLedger:CreateCounter()
    local control = WM:CreateTopLevelWindow("RedLedgerCounter")

    control:SetMovable(self.saved.unlocked)
    control:SetMouseEnabled(true)
    control:SetClampedToScreen(true)

    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self.saved.posX, self.saved.posY)

    control:SetHandler("OnMoveStop", function(ctrl)
        local _, _, _, _, x, y = ctrl:GetAnchor(0)
        self.saved.posX = x
        self.saved.posY = y
    end)

    local backdrop = WM:CreateControl(nil, control, CT_BACKDROP)
    backdrop:SetAnchorFill()
    backdrop:SetCenterColor(0, 0, 0, 0)
    backdrop:SetEdgeColor(0, 0, 0, 0)

    local label = WM:CreateControl("RedLedgerCounterLabel", control, CT_LABEL)
    label:SetAnchor(CENTER, control, CENTER, 0, 0)
    label:SetColor(0.82, 0.04, 0.04, 1)          -- richer blood red
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetText("N")

    self.counterWindow = control
    self.counterLabel = label

    self:ApplyCounterScale()
    self:UpdateCounter()
    self:UpdateCounterVisibility()
end

--------------------------------------------------
-- Settings
--------------------------------------------------

function RedLedger:CreateSettings()
    if not LibAddonMenu2 then return end

    local panelData = {
        type = "panel",
        name = "Red Ledger",
        displayName = "Red Ledger",
        author = "O-Range",
        version = self.version,
        registerForRefresh = true,
        registerForDefaults = true,
    }

    LibAddonMenu2:RegisterAddonPanel("RedLedgerPanel", panelData)

    local options = {
        {
            type = "header",
            name = "Counter Visibility",
        },
        {
            type = "checkbox",
            name = "Hide Counter Completely",
            tooltip = "Completely hides the kill counter.",
            getFunc = function() return self.saved.hideCounter end,
            setFunc = function(value)
                self.saved.hideCounter = value
                self:UpdateCounterVisibility()
            end,
        },
        {
            type = "checkbox",
            name = "Hide Counter in PvE Zones",
            tooltip = "Automatically hides the counter outside Cyrodiil, Imperial City, and Battlegrounds.",
            getFunc = function() return self.saved.hideInPvE end,
            setFunc = function(value)
                self.saved.hideInPvE = value
                self:UpdateCounterVisibility()
            end,
        },
        {
            type = "header",
            name = "Counter Appearance",
        },
        {
            type = "checkbox",
            name = "Unlock Counter Position",
            getFunc = function() return self.saved.unlocked end,
            setFunc = function(value)
                self.saved.unlocked = value
                if self.counterWindow then
                    self.counterWindow:SetMovable(value)
                end
            end,
        },
        {
            type = "checkbox",
            name = "Use Roman Numerals",
            tooltip = "Display the kill counter in Roman numerals.",
            getFunc = function() return self.saved.useRoman end,
            setFunc = function(value)
                self.saved.useRoman = value
                self:UpdateCounter()
            end,
        },
        {
            type = "slider",
            name = "Counter Size",
            tooltip = "Scale of the kill counter.",
            min = 0.6,
            max = 2.2,
            step = 0.1,
            decimals = 1,
            getFunc = function() return self.saved.counterScale end,
            setFunc = function(value)
                self.saved.counterScale = value
                self:ApplyCounterScale()
            end,
        },
        {
            type = "header",
            name = "Effects",
        },
        {
            type = "checkbox",
            name = "Play Sound on Kill",
            tooltip = "Play a death sound when you get a kill.",
            getFunc = function() return self.saved.playSound end,
            setFunc = function(value)
                self.saved.playSound = value
            end,
        },
        {
            type = "header",
            name = "Session",
        },
        {
            type = "button",
            name = "Reset Session Kill Count",
            func = function()
                self:ResetSessionCounter()
            end,
        },
        {
            type = "description",
            text = function()
                return string.format("Lifetime kills: %d", self.saved.lifetimeKills or 0)
            end,
        },
        {
            type = "description",
            text = "Keybind: Simulate Killing Blow  |  /redledger test",
        },
    }

    LibAddonMenu2:RegisterOptionControls("RedLedgerPanel", options)
end

--------------------------------------------------
-- Commands
--------------------------------------------------

function RedLedger:InitializeCommands()
    SLASH_COMMANDS["/redledger"] = function(text)
        text = string.lower(zo_strtrim(text or ""))

        if text == "reset" or text == "rs" then
            self:ResetSessionCounter()
            d("|cAA0000[Red Ledger]|r Session counter reset.")

        elseif text == "test" then
            self:ProcessKill()

        elseif text == "lifetime" or text == "lt" then
            d(string.format("|cAA0000[Red Ledger]|r Lifetime kills: %d", self.saved.lifetimeKills or 0))

        elseif text == "toggle" or text == "hide" then
            self.saved.hideCounter = not self.saved.hideCounter
            self:UpdateCounterVisibility()
            d("|cAA0000[Red Ledger]|r Counter " .. (self.saved.hideCounter and "hidden" or "shown") .. ".")

        else
            d("|cAA0000[Red Ledger]|r Commands:")
            d("  /redledger test     - Simulate a kill + blood splash")
            d("  /redledger reset    - Reset session counter")
            d("  /redledger lifetime - Show lifetime kills")
            d("  /redledger toggle   - Toggle counter visibility")
        end
    end
end

--------------------------------------------------
-- Blood Effects
--------------------------------------------------

function RedLedger:CreateEffectsWindow()
    local win = WM:CreateTopLevelWindow("RedLedgerEffects")
    win:SetAnchorFill(GuiRoot)
    win:SetMouseEnabled(false)
    win:SetMovable(false)
    win:SetHidden(false)
    win:SetDrawLayer(DL_OVERLAY)
    win:SetDrawTier(DT_HIGH)
    win:SetDrawLevel(40)

    self.effectsWindow = win
end

function RedLedger:GetSplatterControl()
    for i = 1, #self.splatterPool do
        local ctrl = self.splatterPool[i]
        if ctrl:IsHidden() then
            return ctrl
        end
    end

    if #self.splatterPool >= 16 then
        local oldest = table.remove(self.splatterPool, 1)
        table.insert(self.splatterPool, oldest)
        oldest:SetHidden(true)
        return oldest
    end

    local control = WM:CreateControl(nil, self.effectsWindow, CT_TEXTURE)
    control:SetDrawLayer(DL_OVERLAY)
    control:SetDrawTier(DT_HIGH)
    control:SetHidden(true)
    table.insert(self.splatterPool, control)

    return control
end

function RedLedger:TriggerBloodSplash()
    if not self.effectsWindow then
        self:CreateEffectsWindow()
    end

    local screenW = GuiRoot:GetWidth()
    local screenH = GuiRoot:GetHeight()
    local texPath = "RedLedger/texture/blood_master.dds"

    local size = math.random(420, 1250)
    local control = self:GetSplatterControl()

    control:SetHidden(true)
    control:SetAlpha(1)

    -- Color variation
    local r = 1.05 + math.random() * 0.20
    local g = 0.90 + math.random() * 0.15
    local b = 0.90 + math.random() * 0.15
    control:SetColor(r, g, b, 1)
    control:SetDesaturation(math.random() * 0.22)

    control:ClearAnchors()
    control:SetDimensions(size, size)
    control:SetTexture(texPath)
    control:SetDrawLevel(80 + math.random(1, 50))

    -- Random flip / mirror
    local flip = math.random(0, 3)
    if flip == 0 then
        control:SetTextureCoords(0, 1, 0, 1)
    elseif flip == 1 then
        control:SetTextureCoords(1, 0, 0, 1)
    elseif flip == 2 then
        control:SetTextureCoords(0, 1, 1, 0)
    else
        control:SetTextureCoords(1, 0, 1, 0)
    end

    -- Full random rotation
    control:SetTextureRotation(math.random() * 2 * math.pi)

    -- Position
    local maxX = math.max(30, screenW - size - 30)
    local maxY = math.max(30, screenH - size - 30)
    local x = math.random(30, maxX)
    local y = math.random(30, maxY)
    control:SetAnchor(TOPLEFT, self.effectsWindow, TOPLEFT, x, y)
    control:SetHidden(false)

    -- Fade
    local duration = math.random(3600, 5400)
    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local fade = timeline:InsertAnimation(ANIMATION_ALPHA, control, 0)
    fade:SetDuration(duration)
    fade:SetAlphaValues(1.0, 0.0)

    timeline:SetHandler("OnStop", function()
        if control then
            control:SetHidden(true)
            control:SetAlpha(1)
            control:ClearAnchors()
            control:SetTextureRotation(0)
            control:SetTextureCoords(0, 1, 0, 1)
        end
    end)

    timeline:PlayFromStart()
end

--------------------------------------------------
-- Kill Processing
--------------------------------------------------

function RedLedger:ProcessKill()
    local now = GetGameTimeMilliseconds()
    if self.lastKillTime and (now - self.lastKillTime) < 400 then
        return
    end
    self.lastKillTime = now

    self.sessionKills = self.sessionKills + 1
    self.saved.lifetimeKills = (self.saved.lifetimeKills or 0) + 1

    self:UpdateCounter()

    -- Weighted multi-splat (1 most common, occasionally 2 or 3)
    local roll = math.random(1, 100)
    local count = 1
    if roll <= 22 then
        count = 2
    elseif roll <= 30 then
        count = 3
    end

    for i = 1, count do
        self:TriggerBloodSplash()
    end

    if self.saved.playSound then
        PlaySound(SOUNDS.DEATH)
    end
end

function RedLedger:SimulateKill()
    self:ProcessKill()
end

--------------------------------------------------
-- PvP Kill Detection
--------------------------------------------------

function RedLedger:OnPvPKillFeedDeath(
    eventCode, killLocation,
    killerDisplayName, killerCharacterName, killerAlliance, killerRank,
    victimDisplayName, victimCharacterName, victimAlliance, victimRank,
    isKillLocation
)
    local myDisplayName = GetDisplayName()
    local myCharacterName = zo_strformat("<<1>>", GetUnitName("player"))

    local killerDisp = zo_strformat("<<1>>", killerDisplayName or "")
    local killerChar = zo_strformat("<<1>>", killerCharacterName or "")
    local victimDisp = zo_strformat("<<1>>", victimDisplayName or "")
    local victimChar = zo_strformat("<<1>>", victimCharacterName or "")

    local isMeKiller = (killerDisp == myDisplayName) or (killerChar == myCharacterName)
    local isMeVictim = (victimDisp == myDisplayName) or (victimChar == myCharacterName)

    if isMeKiller and not isMeVictim then
        self:ProcessKill()
    end
end

function RedLedger:OnBattlegroundKill(
    eventCode,
    killedPlayerCharacterName, killedPlayerDisplayName, killedPlayerBattlegroundAlliance,
    killingPlayerCharacterName, killingPlayerDisplayName, killingPlayerBattlegroundAlliance,
    battlegroundKillType, killingAbilityId
)
    local myDisplayName = GetDisplayName()
    local myCharacterName = zo_strformat("<<1>>", GetUnitName("player"))

    local killerDisp = zo_strformat("<<1>>", killingPlayerDisplayName or "")
    local killerChar = zo_strformat("<<1>>", killingPlayerCharacterName or "")
    local victimDisp = zo_strformat("<<1>>", killedPlayerDisplayName or "")
    local victimChar = zo_strformat("<<1>>", killedPlayerCharacterName or "")

    local isMeKiller = (killerDisp == myDisplayName) or (killerChar == myCharacterName)
    local isMeVictim = (victimDisp == myDisplayName) or (victimChar == myCharacterName)

    if isMeKiller and not isMeVictim then
        self:ProcessKill()
    end
end

function RedLedger:OnCombatEvent(
    eventCode, result, isError, abilityName, abilityId,
    sourceName, sourceType, targetName, targetType,
    hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, ...
)
    if isError then return end
    if result ~= ACTION_RESULT_KILLING_BLOW then return end
    if sourceType ~= COMBAT_UNIT_TYPE_PLAYER and sourceType ~= COMBAT_UNIT_TYPE_PLAYER_PET then return end

    local playerName = zo_strformat("<<1>>", GetUnitName("player"))
    local source = zo_strformat("<<1>>", sourceName or "")

    if source == playerName then
        self:ProcessKill()
    end
end

--------------------------------------------------
-- Keybind
--------------------------------------------------

function RedLedger_Keybind_Test()
    if RedLedger then
        RedLedger:SimulateKill()
    end
end

ZO_CreateStringId("SI_BINDING_NAME_REDLEDGER_TEST", "Simulate Killing Blow")

--------------------------------------------------
-- Initialization
--------------------------------------------------

function RedLedger:Initialize()
    self.saved = ZO_SavedVars:NewAccountWide("RedLedgerSaved", 1, nil, defaults)

    self.sessionKills = 0
    self.splatterPool = {}
    self.lastKillTime = 0

    math.randomseed(GetGameTimeMilliseconds())

    self:CreateCounter()
    self:CreateEffectsWindow()
    self:CreateSettings()
    self:InitializeCommands()

    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PVP_KILL_FEED_DEATH, function(...)
        self:OnPvPKillFeedDeath(...)
    end)

    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_BATTLEGROUND_KILL, function(...)
        self:OnBattlegroundKill(...)
    end)

    EVENT_MANAGER:RegisterForEvent(self.name .. "_Combat", EVENT_COMBAT_EVENT, function(...)
        self:OnCombatEvent(...)
    end)
    EVENT_MANAGER:AddFilterForEvent(self.name .. "_Combat", EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_KILLING_BLOW)

    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PLAYER_ACTIVATED, function()
        self:UpdateCounterVisibility()
    end)

    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_ZONE_CHANGED, function()
        self:UpdateCounterVisibility()
    end)

    d("|cAA0000Red Ledger|r v" .. self.version .. " loaded.")
end

local function OnLoaded(_, addonName)
    if addonName ~= RedLedger.name then return end
    EVENT_MANAGER:UnregisterForEvent(RedLedger.name, EVENT_ADD_ON_LOADED)
    RedLedger:Initialize()
end

EVENT_MANAGER:RegisterForEvent(RedLedger.name, EVENT_ADD_ON_LOADED, OnLoaded)