RedLedger = {}
RedLedger.name = "RedLedger"
RedLedger.version = "0.5"

local WM = WINDOW_MANAGER

local defaults =
{
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

    local romans =
    {
        {1000, "M"},
        {900,  "CM"},
        {500,  "D"},
        {400,  "CD"},
        {100,  "C"},
        {90,   "XC"},
        {50,   "L"},
        {40,   "XL"},
        {10,   "X"},
        {9,    "IX"},
        {5,    "V"},
        {4,    "IV"},
        {1,    "I"},
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

    if scale >= 1.8 then
        self.counterLabel:SetFont("ZoFontWinH1")
        self.counterLabel:SetScale(1.6)
    elseif scale >= 1.5 then
        self.counterLabel:SetFont("ZoFontWinH1")
        self.counterLabel:SetScale(1.35)
    elseif scale >= 1.2 then
        self.counterLabel:SetFont("ZoFontWinH1")
        self.counterLabel:SetScale(1.15)
    elseif scale >= 1.0 then
        self.counterLabel:SetFont("ZoFontWinH1")
        self.counterLabel:SetScale(1.0)
    elseif scale >= 0.8 then
        self.counterLabel:SetFont("ZoFontWinH2")
        self.counterLabel:SetScale(1.0)
    else
        self.counterLabel:SetFont("ZoFontWinH3")
        self.counterLabel:SetScale(1.0)
    end
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
    label:SetColor(0.75, 0.05, 0.05, 1)
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

    local panelData =
    {
        type = "panel",
        name = "Red Ledger",
        displayName = "Red Ledger",
        author = "O-Range",
        version = self.version,
        registerForRefresh = true,
        registerForDefaults = true,
    }

    LibAddonMenu2:RegisterAddonPanel("RedLedgerPanel", panelData)

    local options =
    {
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
            tooltip = "Automatically hides the counter when you are not in Cyrodiil, Imperial City, or Battlegrounds.",
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
            tooltip = "Display the kill counter in Roman numerals instead of normal numbers.",
            getFunc = function() return self.saved.useRoman end,
            setFunc = function(value)
                self.saved.useRoman = value
                self:UpdateCounter()
            end,
        },
        {
            type = "slider",
            name = "Counter Size",
            tooltip = "Adjust the size of the kill counter.",
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
            tooltip = "Plays a sound effect when you get a kill.",
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
            text = "Use the keybind 'Simulate Killing Blow' or /redledger test for testing.",
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
    local w = GuiRoot:GetWidth()
    local h = GuiRoot:GetHeight()

    win:SetDimensions(w + 4, h + 4)
    win:ClearAnchors()
    win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, -2, -2)
    win:SetMouseEnabled(false)
    win:SetMovable(false)
    win:SetHidden(false)
    win:SetDrawLayer(DL_OVERLAY)
    win:SetDrawTier(DT_HIGH)
    win:SetDrawLevel(40)

    local bg = WM:CreateControl(nil, win, CT_BACKDROP)
    bg:SetAnchorFill()
    bg:SetCenterColor(0, 0, 0, 0)
    bg:SetEdgeColor(0, 0, 0, 0)
    bg:SetEdgeTexture("", 1, 1, 1)
    bg:SetHidden(true)

    self.effectsWindow = win
end

function RedLedger:GetSplatterControl()
    for i = 1, #self.splatterPool do
        local ctrl = self.splatterPool[i]
        if ctrl:IsHidden() then
            return ctrl
        end
    end

    if #self.splatterPool >= 10 then
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
    local texPath = self.bloodTextures[math.random(1, #self.bloodTextures)]

    -- +20% intensity
    local size = math.random(580, 1050)

    local control = self:GetSplatterControl()

    control:SetHidden(true)
    control:SetAlpha(1)
    control:SetColor(1.15, 1.05, 1.05, 1)   -- brighter
    control:SetTextureCoords(0, 1, 0, 1)
    control:SetDesaturation(0)

    control:ClearAnchors()
    control:SetDimensions(size, size)
    control:SetTexture(texPath)
    control:SetDrawLevel(80 + math.random(1, 40))

    local maxX = math.max(40, screenW - size - 40)
    local maxY = math.max(40, screenH - size - 40)

    local x = math.random(40, maxX)
    local y = math.random(40, maxY)

    control:SetAnchor(TOPLEFT, self.effectsWindow, TOPLEFT, x, y)
    control:SetHidden(false)

    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local fade = timeline:InsertAnimation(ANIMATION_ALPHA, control, 0)
    fade:SetDuration(4600)          -- slightly longer for heavier feel
    fade:SetAlphaValues(1.0, 0.0)

    timeline:SetHandler("OnStop", function()
        if control then
            control:SetHidden(true)
            control:SetAlpha(1)
            control:ClearAnchors()
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
    self:TriggerBloodSplash()

    if self.saved.playSound then
        PlaySound(SOUNDS.DEATH)
    end
end

function RedLedger:SimulateKill()
    self:ProcessKill()
end

--------------------------------------------------
-- Reliable PvP Kill Detection
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

    self.bloodTextures =
    {
        "RedLedger/texture/blood1.dds",
        "RedLedger/texture/blood2.dds",
        "RedLedger/texture/blood3.dds",
    }

    math.randomseed(GetGameTimeMilliseconds())

    self:CreateCounter()
    self:CreateEffectsWindow()
    self:CreateSettings()
    self:InitializeCommands()

    -- Primary reliable sources
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PVP_KILL_FEED_DEATH, function(...)
        self:OnPvPKillFeedDeath(...)
    end)

    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_BATTLEGROUND_KILL, function(...)
        self:OnBattlegroundKill(...)
    end)

    -- Combat event fallback
    EVENT_MANAGER:RegisterForEvent(self.name .. "_Combat", EVENT_COMBAT_EVENT, function(...)
        self:OnCombatEvent(...)
    end)
    EVENT_MANAGER:AddFilterForEvent(self.name .. "_Combat", EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_KILLING_BLOW)

    -- Update visibility when zoning
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