-- Game event wiring.
local BEV = BetterEffectViewer

local RETICLE_TAGS = { "reticleover", "reticleoverplayer" }

local function OnEffectChanged(_, changeType, _, effectName, _, beginTime, endTime, stackCount, iconName,
                               _, effectType, _, _, _, _, abilityId, sourceType)
    if not BEV.hasTarget or BEV.targetLostAt then
        return
    end

    if changeType == EFFECT_RESULT_FADED
        or changeType == EFFECT_RESULT_FULLY_REMOVED
        or changeType == EFFECT_RESULT_TRANSFER then
        if BEV:RemoveEffect(BEV:MakeEffectKey(abilityId, effectType)) then
            BEV.needsRedraw = true
        end
        -- Another source may still have this effect up; let a quick rescan restore it.
        BEV:RequestRescan(0.2)
        return
    end

    if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
        if not effectName or effectName == "" then
            return
        end
        local castByPlayer = sourceType == COMBAT_UNIT_TYPE_PLAYER
        if BEV:UpsertEffect(effectName, abilityId, iconName, effectType, beginTime, endTime, stackCount,
            castByPlayer, GetFrameTimeSeconds()) then
            BEV.needsRedraw = true
        end
    end
end

function BEV:RegisterEvents()
    local name = self.name

    EVENT_MANAGER:RegisterForEvent(name, EVENT_RETICLE_TARGET_CHANGED, function()
        self:OnReticleTargetChanged()
    end)

    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, function()
        self:ApplyCurrentLayout()
        self:OnReticleTargetChanged()
    end)

    -- Filters must be added after the event is registered for that namespace.
    for _, unitTag in ipairs(RETICLE_TAGS) do
        local namespace = name .. "_Effect_" .. unitTag
        EVENT_MANAGER:RegisterForEvent(namespace, EVENT_EFFECT_CHANGED, OnEffectChanged)
        EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, unitTag)
    end

    if EVENT_EFFECTS_FULL_UPDATE then
        EVENT_MANAGER:RegisterForEvent(name, EVENT_EFFECTS_FULL_UPDATE, function()
            self:RequestRescan(0)
        end)
    end

    EVENT_MANAGER:RegisterForUpdate(name .. "_Update", 100, function()
        self:OnUpdate()
    end)
end
