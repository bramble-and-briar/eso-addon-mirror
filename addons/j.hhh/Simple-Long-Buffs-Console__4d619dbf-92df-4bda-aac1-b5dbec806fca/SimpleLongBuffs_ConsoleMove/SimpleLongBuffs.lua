
local NAME = 'SimpleLongBuffs'

local SLB_SV
local SLB_TOP_LEVEL
local isGamepadMoveModeActive = false
local moveLastUpdateMs = 0
local UpdateHudVisibility

local DEFAULTS = {
    positionX = 128,
    positionY = 128,
    gamepadMoveSpeed = 420,
    buffScale = 100,
}

local function ApplyBuffScale()
    if not SLB_TOP_LEVEL or not SLB_SV then return end
    local scale = zo_clamp((tonumber(SLB_SV.buffScale) or 100) / 100, 0.5, 2.0)
    SLB_TOP_LEVEL:SetScale(scale)
end

local function ApplySavedPosition()
    if not SLB_TOP_LEVEL or not SLB_SV then return end
    SLB_TOP_LEVEL:ClearAnchors()
    SLB_TOP_LEVEL:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, SLB_SV.positionX or 128, SLB_SV.positionY or 128)
end

local function UpdateGamepadMove()
    if not isGamepadMoveModeActive or not SLB_TOP_LEVEL or not SLB_SV then return end

    local stickX = GetGamepadLeftStickX and GetGamepadLeftStickX(true) or 0
    local stickY = GetGamepadLeftStickY and GetGamepadLeftStickY(true) or 0
    if math.abs(stickX) < 0.18 then stickX = 0 end
    if math.abs(stickY) < 0.18 then stickY = 0 end
    if stickX == 0 and stickY == 0 then return end

    local now = GetGameTimeMilliseconds()
    local dt = 0.016
    if moveLastUpdateMs > 0 then
        dt = math.min((now - moveLastUpdateMs) / 1000, 0.05)
    end
    moveLastUpdateMs = now

    local speed = tonumber(SLB_SV.gamepadMoveSpeed) or 420
    SLB_SV.positionX = (SLB_SV.positionX or 128) + (stickX * speed * dt)
    SLB_SV.positionY = (SLB_SV.positionY or 128) - (stickY * speed * dt)
    ApplySavedPosition()
end

local function RequestSavedVariablesSave()
    local addonManager = GetAddOnManager and GetAddOnManager()
    if addonManager and addonManager.RequestAddOnSavedVariablesPrioritySave then
        addonManager:RequestAddOnSavedVariablesPrioritySave(NAME)
    end
end

local function StartGamepadMoveMode()
    if isGamepadMoveModeActive or not SLB_TOP_LEVEL then return end
    isGamepadMoveModeActive = true
    moveLastUpdateMs = 0
    SLB_TOP_LEVEL:SetHidden(false)
    EVENT_MANAGER:RegisterForUpdate(NAME .. 'GamepadMove', 16, UpdateGamepadMove)
    d('|cFFFFFFSimple Long Buffs|r Move mode: |c00FF00ON|r - move with left stick')
end

local function SaveCurrentPosition()
    if not SLB_TOP_LEVEL or not SLB_SV then return end
    local left = SLB_TOP_LEVEL:GetLeft()
    local top = SLB_TOP_LEVEL:GetTop()
    if left ~= nil and top ~= nil then
        SLB_SV.positionX = zo_round(left)
        SLB_SV.positionY = zo_round(top)
    end
end

local function StopGamepadMoveMode()
    if not isGamepadMoveModeActive then return end
    EVENT_MANAGER:UnregisterForUpdate(NAME .. 'GamepadMove')
    isGamepadMoveModeActive = false
    moveLastUpdateMs = 0
    SaveCurrentPosition()
    ApplySavedPosition()
    RequestSavedVariablesSave()
    UpdateHudVisibility()
    d('|cFFFFFFSimple Long Buffs|r Move mode: |cFFAA00OFF|r - position saved')
end

local function ToggleGamepadMoveMode()
    if isGamepadMoveModeActive then StopGamepadMoveMode() else StartGamepadMoveMode() end
end

local function BuildOptionalLAMMenu()
    local LAM = LibAddonMenu2
    if not LAM or not SLB_SV then return end

    local panelName = NAME .. "Menu"
    LAM:RegisterAddonPanel(panelName, {
        type = "panel",
        name = "Simple Long Buffs",
        displayName = "Simple Long Buffs",
        author = "JH Console Port",
        version = "console.3",
        registerForRefresh = true,
    })

    LAM:RegisterOptionControls(panelName, {
        {
            type = "button",
            name = "Toggle move mode",
            tooltip = "Turns movement mode on/off. While enabled, move the buff display with the left stick. Turning it off saves the position.",
            func = function() ToggleGamepadMoveMode() end,
            width = "full",
        },
        {
            type = "slider",
            name = "Buff size",
            tooltip = "Changes the size of the buff display.",
            min = 50,
            max = 200,
            step = 5,
            getFunc = function() return SLB_SV.buffScale or 100 end,
            setFunc = function(value)
                SLB_SV.buffScale = value
                ApplyBuffScale()
                RequestSavedVariablesSave()
            end,
            width = "full",
            default = 100,
        },
        {
            type = "slider",
            name = "Gamepad move speed",
            min = 100,
            max = 1000,
            step = 25,
            getFunc = function() return SLB_SV.gamepadMoveSpeed or 420 end,
            setFunc = function(value)
                SLB_SV.gamepadMoveSpeed = value
                RequestSavedVariablesSave()
            end,
            width = "full",
        },
    })
end


-------------------------------------
--Custom Container Object--
-------------------------------------
local UnitBuffTrackerContrainer

UnitBuffTrackerContrainer = ZO_BuffDebuff_ContainerObject:Subclass()

function UnitBuffTrackerContrainer:New(...)
    return ZO_BuffDebuff_ContainerObject.New(self, ...)
end

function UnitBuffTrackerContrainer:ShouldContextuallyShow()
    return true
end

function UnitBuffTrackerContrainer:CreateMetaPool(container, buffControlPool)
    local metaPool = ZO_MetaPool:New(buffControlPool)
    metaPool.container = container

    local function OnAcquired(control)
        control:ClearAnchors()

        if control.platformStyle ~= self.currentPlatformStyle then
            control.platformStyle = self.currentPlatformStyle
            ApplyTemplateToControl(control, ZO_GetPlatformTemplate("SimpleLongBuffs_BuffDebuffIcon"))
        end

        if not metaPool.firstControl then
            metaPool.firstControl = control
            control:SetAnchor(BOTTOM, container, BOTTOM)
        else
            control:SetAnchor(BOTTOM, metaPool.lastControl, TOP, 0, -5)
        end

        metaPool.lastControl = control

        control:SetParent(container)
    end

    local function OnReset(control)
        control.blinkAnimation:Stop()

        control.cooldown:ResetCooldown()
        control.cooldown:SetHidden(true)
    end

    metaPool:SetCustomAcquireBehavior(OnAcquired)
    metaPool:SetCustomResetBehavior(OnReset)

    return metaPool
end

-------------------------------------
--Custom Style--
-------------------------------------
local UnitBuffTrackerStyle

UnitBuffTrackerStyle = ZO_BuffDebuffStyleObject:Subclass()
function UnitBuffTrackerStyle:New(...)
    return ZO_BuffDebuffStyleObject.New(self, ...)
end

function UnitBuffTrackerStyle:UpdateContainer(containerObject)
    ZO_ClearNumericallyIndexedTable(self.sortedBuffs)
    ZO_ClearNumericallyIndexedTable(self.sortedDebuffs)

    local unitTag = containerObject:GetUnitTag()
    local uid = 1

    for i = 1, GetNumBuffs(unitTag) do
        local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, statusEffectType, abilityId, _, castByPlayer = GetUnitBuffInfo(unitTag, i)
        local permanent = IsAbilityPermanent(abilityId)
        local abilityDuration = GetAbilityDuration(abilityId) or 0

        -- Show only the buffs this console HUD is meant to track:
        --   1) food / drink buffs
        --   2) Experience gain consumable buffs
        --   3) Alliance Rank / Alliance Skill gain consumable buffs
        --   4) Vampire Stage
        --
        -- Food/drink detection is intentionally local. There is no global ESO API
        -- function named GetActiveFoodBuff; several addons implement that helper
        -- themselves. Long, removable self buffs with no cost/range/cast time and
        -- a real ability description match ESO food/drink effects reliably.
        local _, _, _, _, _, _, _, _, _, _, _, canClickOff = GetUnitBuffInfo(unitTag, i)

        local function IsFoodOrDrinkAbility(id)
            if not id or not DoesAbilityExist(id) then return false end
            if not canClickOff then return false end
            if (GetAbilityDuration(id) or 0) < 600000 then return false end
            if GetAbilityTargetDescription(id) ~= GetString(SI_TARGETTYPE2) then return false end
            if GetAbilityEffectDescription(id) ~= "" then return false end
            if (GetAbilityRadius(id) or 0) > 0 or (GetAbilityAngleDistance(id) or 0) > 0 then return false end
            if (GetAbilityCost(id) or 0) > 0 then return false end
            local channeled, castTime = GetAbilityCastInfo(id)
            if channeled or (castTime or 0) > 0 then return false end
            local minRangeCM, maxRangeCM = GetAbilityRange(id)
            if (minRangeCM or 0) > 0 or (maxRangeCM or 0) > 0 then return false end
            if (GetAbilityDescription(id) or "") == "" then return false end
            return true
        end

        local abilityDescription = GetAbilityDescription and (GetAbilityDescription(abilityId) or "") or ""
        local searchable = string.lower((buffName or "") .. " " .. abilityDescription)

        -- Known XP consumable buff IDs seen across Ambrosia, Crown/Gold Coast
        -- scrolls and event XP effects. Name/description matching remains as a
        -- fallback so new variants can work without another update.
        local xpBuffIds = {
            [85501]=true, [85503]=true, [86755]=true, [88445]=true,
            [89683]=true, [91369]=true,
        }
        local isExperienceBuff = xpBuffIds[abilityId] == true or
            string.find(searchable, "increased experience", 1, true) ~= nil or
            string.find(searchable, "experience point", 1, true) ~= nil or
            string.find(searchable, "experience gain", 1, true) ~= nil or
            string.find(searchable, "erfahrungs", 1, true) ~= nil

        -- War Tortes / Alliance War scrolls use an Alliance Skill Gain-style
        -- buff name. German fallbacks cover the corresponding localized wording.
        local isAlliancePointBuff =
            string.find(searchable, "alliance skill gain", 1, true) ~= nil or
            string.find(searchable, "alliance rank", 1, true) ~= nil or
            string.find(searchable, "alliance war skill", 1, true) ~= nil or
            string.find(searchable, "allianzrang", 1, true) ~= nil or
            string.find(searchable, "allianzkrieg", 1, true) ~= nil or
            string.find(searchable, "allianzfertigkeit", 1, true) ~= nil

        local isVampireStage =
            string.find(searchable, "vampirism stage", 1, true) ~= nil or
            string.find(searchable, "vampire stage", 1, true) ~= nil or
            string.find(searchable, "vampirstufe", 1, true) ~= nil or
            string.find(searchable, "vampirismus stufe", 1, true) ~= nil

        -- The generic long-consumable signature catches food/drink. XP/AP are
        -- separately whitelisted by ID/name, and Vampire Stage is permanent.
        local isFoodBuff = IsFoodOrDrinkAbility(abilityId) and not isExperienceBuff and not isAlliancePointBuff
        local shouldShow = (effectType == BUFF_EFFECT_TYPE_BUFF) and
            (isFoodBuff or isExperienceBuff or isAlliancePointBuff or isVampireStage)

        if shouldShow then
            local data = {
                buffName = buffName,
                timeStarted = timeStarted,
                timeEnding = timeEnding,
                buffSlot = buffSlot,
                stackCount = stackCount,
                iconFilename = iconFilename,
                buffType = buffType,
                effectType = effectType,
                abilityType = abilityType,
                statusEffectType = statusEffectType,
                abilityId = abilityId,
                uid = uid,
                duration = timeEnding - timeStarted,
                castByPlayer = castByPlayer,
                permanent = permanent,
                isArtificial = false,
            }
            local appropriateTable = (effectType == BUFF_EFFECT_TYPE_BUFF) and self.sortedBuffs or self.sortedDebuffs
            table.insert(appropriateTable, data)
            uid = uid + 1
        end
    end

    if #self.sortedBuffs then
        table.sort(self.sortedBuffs, self.SortCallbackFunction)
    end
    if #self.sortedDebuffs then
        table.sort(self.sortedDebuffs, self.SortCallbackFunction)
    end

    local buffPool, debuffPool = containerObject:GetPools()

    for _, data in ipairs(self.sortedBuffs) do
        local buffControl = buffPool:AcquireObject()
        buffControl.data = data
        self:SetupIcon(buffControl)
    end

    for _, data in ipairs(self.sortedDebuffs) do
        local debuffControl = debuffPool:AcquireObject()
        debuffControl.data = data
        self:SetupIcon(debuffControl)
    end
end

function UnitBuffTrackerStyle:SortFunction(buffData1, buffData2)
    if buffData1.permanent and buffData2.permanent then
        return buffData1.buffName > buffData2.buffName
    else
        if buffData1.permanent then
            return true
        elseif buffData2.permanent then
            return false
        end

        if buffData1.timeEnding == buffData2.timeEnding then
            return buffData1.buffName > buffData2.buffName
        else
            return buffData1.timeEnding > buffData2.timeEnding
        end
    end
end

UpdateHudVisibility = function()
    if not SLB_TOP_LEVEL then return end
    if isGamepadMoveModeActive then
        SLB_TOP_LEVEL:SetHidden(false)
        return
    end

    -- Only show the tracker on the normal HUD. Hide it in inventory, map,
    -- settings, dialogs and other full-screen menus.
    local hudVisible = (SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui"))
    SLB_TOP_LEVEL:SetHidden(not hudVisible)
end

function SimpleLongBuffs_Initialize(topLevelCtrl)

    local function OnAddOnLoaded(_, addonName)
        if addonName == NAME then

            EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)

            SLB_TOP_LEVEL = topLevelCtrl
            SLB_SV = ZO_SavedVars:NewAccountWide('SimpleLongBuffsData', 1, nil, DEFAULTS, GetWorldName())
            ApplySavedPosition()
            ApplyBuffScale()

            local UnitBuffTrackerStyleObject = UnitBuffTrackerStyle:New("SimpleLongBuffs_BuffDebuffCenterOutStyle_Template")
            local controlPool = ZO_ControlPool:New("ZO_BuffDebuffIcon", nil, "SLBBuff")

            local containerControl = CreateControlFromVirtual(NAME..'BuffDebuffContainer', topLevelCtrl, 'ZO_BuffDebuffContainerTemplate')
            containerControl:ClearAnchors()
            containerControl:SetAnchor(BOTTOMRIGHT, topLevelCtrl, BOTTOMRIGHT, 0, 0)

            local containerObject = UnitBuffTrackerContrainer:New(containerControl, controlPool, 'player', EVENT_PLAYER_ACTIVATED)
            containerObject:SetStyleObject(UnitBuffTrackerStyleObject, true)

            BUFF_DEBUFF:AddContainerObject('player_longbuffs', containerObject)

            BuildOptionalLAMMenu()
            EVENT_MANAGER:RegisterForUpdate(NAME .. "HudVisibility", 100, UpdateHudVisibility)
            EVENT_MANAGER:RegisterForEvent(NAME .. "SavePosition", EVENT_PLAYER_DEACTIVATED, function()
                SaveCurrentPosition()
                RequestSavedVariablesSave()
            end)
            UpdateHudVisibility()

        end
    end

    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
end