ERUI_CustomBuffs = {}
local CB = ERUI_CustomBuffs

CB.recentBuffs = {}
CB.recentDebuffs = {}
CB.recentTargetDebuffs = {}

local alwaysIgnore = {
    [28807] = true, [28854] = true, [39073] = true, [177578] = true,
    [64160] = true,
    [41503] = true,
    [84732] = true, [84733] = true,
}

local defaults = {
    showAllBuffs = true,
    showAllDebuffs = true,
    showAllTargetDebuffs = false,
    buffWhitelist = {},
    debuffWhitelist = {},
    targetDebuffWhitelist = {},
}

function CB.FormatName(name)
    return zo_strformat("<<t:1>>", name)
end

local function IsWhitelisted(list, abilityId, cleanName)
    return list[abilityId] ~= nil or list[cleanName] ~= nil
end

local function IsTargetTrackingActive()
    if not DoesUnitExist("reticleover") then return false end
    if EldenRingUI and EldenRingUI.dummyMode then return true end

    for i = 1, 6 do
        if AreUnitsEqual("reticleover", "boss" .. i) then return true end
    end
    return false
end

local function RememberTargetDebuff(auraName, abilityId, effectType)
    if effectType == BUFF_EFFECT_TYPE_DEBUFF and not alwaysIgnore[abilityId] then
        CB.recentTargetDebuffs[abilityId] = CB.FormatName(auraName)
    end
end

function CB:ShouldDisplayAura(auraName, abilityId, effectType, unitTag)
    if alwaysIgnore[abilityId] then return false end

    local cleanName = CB.FormatName(auraName)

    if unitTag == "reticleover" then
        if effectType ~= BUFF_EFFECT_TYPE_DEBUFF then return false end
        return self.db.showAllTargetDebuffs or IsWhitelisted(self.db.targetDebuffWhitelist, abilityId, cleanName)
    end

    if effectType == BUFF_EFFECT_TYPE_BUFF then
        CB.recentBuffs[abilityId] = cleanName
        return self.db.showAllBuffs or IsWhitelisted(self.db.buffWhitelist, abilityId, cleanName)
    elseif effectType == BUFF_EFFECT_TYPE_DEBUFF then
        CB.recentDebuffs[abilityId] = cleanName
        return self.db.showAllDebuffs or IsWhitelisted(self.db.debuffWhitelist, abilityId, cleanName)
    end

    return false
end

function CB:RefreshFrame(frame, unitTag)
    if not frame then return end

    frame:ReleaseAllAuras()

    if DoesUnitExist(unitTag) then
        local isTarget = (unitTag == "reticleover")
        local track = not isTarget or IsTargetTrackingActive()

        for i = 1, GetNumBuffs(unitTag) do
            local auraName, start, finish, buffSlot, stacks, icon, _, effectType, _, _, abilityId = GetUnitBuffInfo(unitTag, i)
            if isTarget then
                RememberTargetDebuff(auraName, abilityId, effectType)
            end
            if track and self:ShouldDisplayAura(auraName, abilityId, effectType, unitTag) then
                frame:AddOrUpdateAura(true, auraName, start, finish, stacks, icon, effectType, abilityId, buffSlot)
            end
        end
    end

    frame:UpdateDisplay()
end

function CB:RefreshAllAuras()
    self:RefreshFrame(self.frame, "player")
    self:RefreshFrame(self.targetFrame, "reticleover")
end

local function RefreshTarget()
    CB:RefreshFrame(CB.targetFrame, "reticleover")
end

local function OnEffectChanged(_, change, slot, auraName, unitTag, start, finish, stacks, icon, _, effectType, _, _, _, _, abilityId)
    if not abilityId then return end

    if unitTag == "reticleover" then
        if change ~= EFFECT_RESULT_FADED then
            RememberTargetDebuff(auraName, abilityId, effectType)
        end
        if not IsTargetTrackingActive() then return end
    end

    local frame = (unitTag == "player") and CB.frame or CB.targetFrame

    if change == EFFECT_RESULT_FADED then
        frame:RemoveAura(abilityId)
    elseif change == EFFECT_RESULT_GAINED or change == EFFECT_RESULT_UPDATED then
        if CB:ShouldDisplayAura(auraName, abilityId, effectType, unitTag) then
            frame:AddOrUpdateAura(false, auraName, start, finish, stacks, icon, effectType, abilityId, slot)
        else
            frame:RemoveAura(abilityId)
        end
    end
end

local function AddToHUD(frame)
    local fragment = ZO_HUDFadeSceneFragment:New(frame, 0, 0)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    SIEGE_BAR_SCENE:AddFragment(fragment)
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= "EldenRingUI" then return end
    EVENT_MANAGER:UnregisterForEvent("ERUI_CustomBuffs", EVENT_ADD_ON_LOADED)

    CB.db = ZO_SavedVars:NewAccountWide("ERUiVars", 1, "CustomBuffs", defaults)

    CB.frame = CB:CreateDisplayFrame("ERUI_CustomBuffsFrame", "player", false)
    CB.frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 140, 110)
    AddToHUD(CB.frame)

    CB.targetFrame = CB:CreateDisplayFrame("ERUI_TargetDebuffsFrame", "reticleover", true)
    CB.targetFrame:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 485, -160)
    AddToHUD(CB.targetFrame)

    CB:InitializeSettings()

    EVENT_MANAGER:RegisterForEvent("ERUI_CustomBuffs", EVENT_EFFECT_CHANGED, OnEffectChanged)
    EVENT_MANAGER:AddFilterForEvent("ERUI_CustomBuffs", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
    EVENT_MANAGER:RegisterForEvent("ERUI_CustomBuffs", EVENT_PLAYER_ACTIVATED, function() CB:RefreshAllAuras() end)
    EVENT_MANAGER:RegisterForEvent("ERUI_CustomBuffs", EVENT_PLAYER_ALIVE, function() CB:RefreshFrame(CB.frame, "player") end)
    EVENT_MANAGER:RegisterForEvent("ERUI_CustomBuffs", EVENT_PLAYER_DEAD, function() CB.frame:ReleaseAllAuras() end)

    EVENT_MANAGER:RegisterForEvent("ERUI_TargetDebuffs", EVENT_EFFECT_CHANGED, OnEffectChanged)
    EVENT_MANAGER:AddFilterForEvent("ERUI_TargetDebuffs", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "reticleover")
    EVENT_MANAGER:RegisterForEvent("ERUI_TargetDebuffs", EVENT_RETICLE_TARGET_CHANGED, RefreshTarget)
    EVENT_MANAGER:RegisterForEvent("ERUI_TargetDebuffs", EVENT_BOSSES_CHANGED, RefreshTarget)
    CALLBACK_MANAGER:RegisterCallback("ERUI_DummyModeChanged", RefreshTarget)
end

EVENT_MANAGER:RegisterForEvent("ERUI_CustomBuffs", EVENT_ADD_ON_LOADED, OnAddOnLoaded)