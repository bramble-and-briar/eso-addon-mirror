local Addon = LarvalTearMod
local Log = Addon.Common.Log
local LTM_EQUIPMENT_APPLY = Addon.Modules.EquipmentApply
local LTM_EQUIPMENT_CHANGE = Addon.Modules.EquipmentChange
local LTM_PIPELINE_CONTEXT = Addon.Modules.PipelineContext

local EQUIPMENT_APPLY_E_CONFIG_INVALID = "EQUIPMENT_APPLY_E_CONFIG_INVALID"
local EQUIPMENT_APPLY_E_CHANGE_FAILED = "EQUIPMENT_APPLY_E_CHANGE_FAILED"
local EQUIPMENT_APPLY_E_RUNTIME = "EQUIPMENT_APPLY_E_RUNTIME"
local EQUIPMENT_APPLY_E_OUTFIT_FAILED = "EQUIPMENT_APPLY_E_OUTFIT_FAILED"

local function SplitEquipmentConfig(config)
    if type(config) ~= "table" then
        return nil, nil
    end

    if config.equipment ~= nil or config.outfit ~= nil then
        return config.equipment, config.outfit
    end

    return config, nil
end

local function ApplyOutfitSelection(outfitConfig)
    if outfitConfig == nil then
        return true, nil, { status = "noop", reason = "outfit_not_saved" }
    end
    if type(outfitConfig) ~= "table" then
        return false, "outfit_config_invalid", nil
    end

    local isDefault = outfitConfig.mode == "default" and outfitConfig.equippedOutfitIndex == nil
    local targetIndex = outfitConfig.equippedOutfitIndex
    if not isDefault and (outfitConfig.mode ~= nil or type(targetIndex) ~= "number"
        or targetIndex < 1 or targetIndex % 1 ~= 0) then
        return false, "outfit_config_invalid", nil
    end
    if type(GetEquippedOutfitIndex) ~= "function" then
        return false, "outfit_api_unavailable", nil
    end
    if not isDefault then
        if type(GetNumUnlockedOutfits) ~= "function" then
            return false, "outfit_api_unavailable", nil
        end
        local countOk, maxOutfits = pcall(GetNumUnlockedOutfits, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
        if not countOk or type(maxOutfits) ~= "number" or maxOutfits < 0 or maxOutfits % 1 ~= 0 then
            return false, "outfit_count_unavailable", nil
        end
        if targetIndex > maxOutfits then
            return false, "outfit_index_unavailable", {
                equippedOutfitIndex = targetIndex,
                maxOutfits = maxOutfits,
            }
        end
    end

    local currentOk, currentIndex = pcall(GetEquippedOutfitIndex, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
    if not currentOk then
        return false, "outfit_capture_failed", nil
    end
    if currentIndex == targetIndex then
        return true, nil, { status = "matched", equippedOutfitIndex = currentIndex }
    end

    local request = EquipOutfit
    if isDefault then
        request = UnequipOutfit
    end
    if type(request) ~= "function" then
        return false, isDefault and "outfit_unequip_unavailable" or "outfit_equip_unavailable", nil
    end
    local ok, err
    if isDefault then
        ok, err = pcall(request, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
    else
        ok, err = pcall(request, GAMEPLAY_ACTOR_CATEGORY_PLAYER, targetIndex)
    end
    if not ok then
        return false, isDefault and "outfit_unequip_failed" or "outfit_equip_failed", {
            apiError = tostring(err),
        }
    end

    -- Preserve the existing immediate verification and Equipment failure contract.
    local verifyOk, appliedIndex = pcall(GetEquippedOutfitIndex, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
    if not verifyOk or appliedIndex ~= targetIndex then
        return false, "outfit_verify_failed", {
            mode = outfitConfig.mode,
            equippedOutfitIndex = targetIndex,
            currentOutfitIndex = verifyOk and appliedIndex or nil,
        }
    end
    return true, nil, {
        status = isDefault and "unequipped" or "equipped",
        equippedOutfitIndex = appliedIndex,
    }
end

function LTM_EQUIPMENT_APPLY:Log(...)
    Log.LogDebugSummary(...)
end

function LTM_EQUIPMENT_APPLY:BuildLastResult(ok, reason, details, status)
    self.lastResult = {
        ok = ok == true,
        details = {
            phase = "equipment_apply",
            reason = reason,
            summary = details,
            status = status or (ok == true and "success" or "failure"),
        },
    }
end

function LTM_EQUIPMENT_APPLY:NotifyPipelineContinuation(context, success, err)
    local continuation = context and context.pipelineContinuation or nil
    if type(continuation) == "function" and not context.pipelineContinuationNotified then
        context.pipelineContinuationNotified = true
        continuation(success == true, err)
    end
end

function LTM_EQUIPMENT_APPLY:IsMissingItemPartial(reason, verifyMetadata)
    return reason == "equipment_final_verify_timeout"
        and type(verifyMetadata) == "table"
        and verifyMetadata.isMissingItemPartial == true
end

function LTM_EQUIPMENT_APPLY:RecordPartialSuccess(context, summary)
    local pipelineContext = context and context.config and context.config._pipelineContext or nil
    if type(pipelineContext) ~= "table" then
        return
    end

    return LTM_PIPELINE_CONTEXT:RecordDomainResult(pipelineContext, {
        domain = "Equipment",
        sourcePhase = "Equipment",
        severity = "partial",
        resultCode = "equipment_partial_missing_items",
        reasons = {
            "equipment_item_not_found",
        },
        residualSummary = summary,
    })
end

function LTM_EQUIPMENT_APPLY:FinishPartial(context, reason, summary)
    self:BuildLastResult(true, reason, summary, "partial")
    self:RecordPartialSuccess(context, summary)
    self:Log(
        "Equipment apply partial",
        "reason=" .. tostring(reason),
        "targetSlots=" .. tostring(type(summary) == "table" and summary.targetSlots or 0),
        "matchedSlots=" .. tostring(type(summary) == "table" and summary.finalMatchedSlots or 0),
        "mismatchedSlots=" .. tostring(type(summary) == "table" and summary.finalMismatchedSlots or 0)
    )
    self:NotifyPipelineContinuation(context, true, nil)
end

function LTM_EQUIPMENT_APPLY:BeginEquipmentChangeWait(config, context)
    local equipmentConfig = SplitEquipmentConfig(config)
    local verifyMetadata = type(context) == "table" and context.equipmentVerifyMetadata or nil
    local runOk, beginOk, beginErr, beginSummary = pcall(
        LTM_EQUIPMENT_CHANGE.BeginApplyEquipment,
        LTM_EQUIPMENT_CHANGE,
        equipmentConfig,
        function(success, err, summary)
            LTM_EQUIPMENT_APPLY:FinishDeferredApply(context, success == true, err, summary)
        end,
        verifyMetadata
    )

    if not runOk then
        return false, EQUIPMENT_APPLY_E_RUNTIME, nil
    end

    if beginOk == true and beginErr == "deferred" then
        return true, "deferred", beginSummary
    end

    return false, beginErr or EQUIPMENT_APPLY_E_CHANGE_FAILED, beginSummary
end

function LTM_EQUIPMENT_APPLY:ApplyOutfitNow(config, summary)
    local _, outfitConfig = SplitEquipmentConfig(config)
    if type(summary) ~= "table" then
        summary = {}
    end

    if Addon:IsIgnoreCostumesEnabled() then
        summary.outfit = {
            status = "skipped",
            reason = "ignore_costumes_enabled",
            saved = type(outfitConfig) == "table",
        }
        self:Log("Equipment outfit apply skipped", "reason=ignore_costumes_enabled")
        return true, nil, summary
    end

    local outfitOk, outfitErr, outfitSummary = ApplyOutfitSelection(outfitConfig)
    summary.outfit = outfitSummary

    if outfitOk ~= true then
        return false, outfitErr or EQUIPMENT_APPLY_E_OUTFIT_FAILED, summary
    end

    return true, nil, summary
end

function LTM_EQUIPMENT_APPLY:FinishDeferredApply(context, success, err, summary)
    local verifyMetadata = type(context) == "table" and context.equipmentVerifyMetadata or nil
    local isMissingItemPartial = success ~= true and self:IsMissingItemPartial(err, verifyMetadata)
    if success == true or isMissingItemPartial then
        local outfitOk, outfitErr, outfitSummary = self:ApplyOutfitNow(context and context.config, summary)
        if outfitOk ~= true then
            success = false
            err = outfitErr
            summary = outfitSummary
            isMissingItemPartial = false
        else
            summary = outfitSummary
        end
    end

    if isMissingItemPartial then
        self:FinishPartial(context, err, summary)
        return
    end

    self:BuildLastResult(success == true, err, summary)
    if success == true then
        self:Log(
            "Equipment apply finished",
            "slotCount=" .. tostring(type(summary) == "table" and summary.slotCount or 0),
            "targetSlots=" .. tostring(type(summary) == "table" and summary.targetSlots or 0),
            "requestedSlots=" .. tostring(type(summary) == "table" and summary.requestedSlots or 0),
            "unresolvedSlots=" .. tostring(type(summary) == "table" and summary.unresolvedSlots or 0)
        )
        self:NotifyPipelineContinuation(context, true, nil)
        return
    end

    local outfitSummary = type(summary) == "table" and summary.outfit or nil
    self:Log("Equipment apply failed", "error=" .. tostring(err),
        type(outfitSummary) == "table" and outfitSummary.apiError
            and ("apiError=" .. outfitSummary.apiError) or nil)
    self:NotifyPipelineContinuation(context, false, err or EQUIPMENT_APPLY_E_CHANGE_FAILED)
end

function LTM_EQUIPMENT_APPLY:Run(config)
    self:Log("Equipment apply called")

    if type(config) ~= "table" then
        self:BuildLastResult(false, "equipment_config_invalid", nil)
        self:Log("Equipment apply failed", "error=" .. EQUIPMENT_APPLY_E_CONFIG_INVALID)
        return false, EQUIPMENT_APPLY_E_CONFIG_INVALID
    end

    local continuation = config._pipelineContinuation
    local context = {
        config = config,
        pipelineContinuation = continuation,
        pipelineContinuationNotified = false,
        equipmentVerifyMetadata = {
            mythicPreclearPerformed = false,
            allFinalMismatchesMissingItems = false,
            isMissingItemPartial = false,
        },
    }
    local equipmentConfig = SplitEquipmentConfig(config)
    local preclearOk, preclearErr, preclearSummary = LTM_EQUIPMENT_CHANGE:BeginMythicPreclearIfNeeded(equipmentConfig, function(success, err)
        if success ~= true then
            LTM_EQUIPMENT_APPLY:BuildLastResult(false, err or "mythic_preclear_failed", preclearSummary)
            LTM_EQUIPMENT_APPLY:Log("Equipment apply failed", "error=" .. tostring(err or "mythic_preclear_failed"))
            LTM_EQUIPMENT_APPLY:NotifyPipelineContinuation(context, false, err or "mythic_preclear_failed")
            return
        end

        context.equipmentVerifyMetadata.mythicPreclearPerformed = true
        local beginOk, beginErr, beginSummary = LTM_EQUIPMENT_APPLY:BeginEquipmentChangeWait(config, context)
        if not (beginOk == true and beginErr == "deferred") then
            LTM_EQUIPMENT_APPLY:FinishDeferredApply(context, beginOk == true, beginErr, beginSummary)
        end
    end)

    if preclearOk == true and preclearErr == "deferred" then
        self:BuildLastResult(true, "deferred", preclearSummary)
        self:Log("Equipment apply deferred", "reason=mythic_preclear")
        return true, "deferred"
    elseif preclearOk == false then
        self:BuildLastResult(false, preclearErr, preclearSummary)
        self:Log("Equipment apply failed", "error=" .. tostring(preclearErr))
        return false, preclearErr or EQUIPMENT_APPLY_E_CHANGE_FAILED
    end

    local beginOk, beginErr, beginSummary = self:BeginEquipmentChangeWait(config, context)
    if beginOk == true and beginErr == "deferred" then
        self:BuildLastResult(true, "deferred", beginSummary)
        return true, "deferred"
    end

    self:BuildLastResult(false, beginErr, beginSummary)
    if type(beginSummary) == "table" then
        self:Log(
            "Equipment apply summary",
            "targetSlots=" .. tostring(beginSummary.targetSlots or 0),
            "matchedSlots=" .. tostring(beginSummary.matchedSlots or 0),
            "equippedSlots=" .. tostring(beginSummary.equippedSlots or 0),
            "requestedSlots=" .. tostring(beginSummary.requestedSlots or 0),
            "unresolvedSlots=" .. tostring(beginSummary.unresolvedSlots or 0),
            "failedSlots=" .. tostring(beginSummary.failedSlots or 0)
        )
    end
    self:Log("Equipment apply failed", "error=" .. tostring(beginErr))
    return false, beginErr or EQUIPMENT_APPLY_E_CHANGE_FAILED
end

function LTM_EQUIPMENT_APPLY:GetLastResult()
    return self.lastResult
end
