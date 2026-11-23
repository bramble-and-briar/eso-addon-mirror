-- Трекинг дебаффов
local AH = _G.MarkTrialHelper
local EM = EVENT_MANAGER

AH.WeakeningEnd = 0
AH.WeakeningTimer = nil

-- WEAKENING_ID из IAHelper
local WEAKENING_ID = 17945

function AH.OnWeakeningEffect(change, _, _, _, unitTag, beginTime, endTime, stackCount, _, _, _, _, _, unitName, unitId, abilityId)
    if not AH.Vars.TrackWeakening then return end
    
    if change == EFFECT_RESULT_GAINED or change == EFFECT_RESULT_UPDATED then
        AH.WeakeningEnd = endTime
        AH.ShowWeakening()
    elseif change == EFFECT_RESULT_FADED then
        AH.WeakeningEnd = 0
        if AH.WeakeningTimer then
            EM:UnregisterForUpdate(AH.WeakeningTimer)
            AH.WeakeningTimer = nil
        end
        if AH.WeakeningFrame then
            AH.WeakeningFrame:SetHidden(true)
            AH.FrameObjectPool:ReleaseObject(AH.WeakeningFrame)
            AH.WeakeningFrame = nil
        end
    end
end

function AH.ShowWeakening()
    if not AH.Vars.TrackWeakening then return end
    if AH.WeakeningEnd <= 0 then return end
    
    local t = AH.WeakeningEnd - GetFrameTimeSeconds()
    if t <= 0 then
        AH.WeakeningEnd = 0
        return
    end
    
    local color = t > 2 and "00FF00" or "FFFF00"
    local text = string.format("Ослабление: |c%s%.1f|r", color, t)
    
    if not AH.WeakeningFrame then
        AH.WeakeningFrame = AH.FrameObjectPool:AcquireObject()
        AH.WeakeningFrame:SetName("Weakening")
        AH.WeakeningFrame:SetDimensions(250, 50)
        AH.WeakeningFrame:SetPosition()
        AH.WeakeningFrame:SetBackgroundColour(0, 0, 0, 0.8)
        AH.WeakeningFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, AH.Vars.WeakeningPosition and AH.Vars.WeakeningPosition.left or 50, AH.Vars.WeakeningPosition.top or 100)
        AH.WeakeningFrame:SetColour(1, 1, 1, 1)
        AH.WeakeningFrame.control:SetDrawTier(DT_HIGH)
        AH.WeakeningFrame.control:SetMouseEnabled(false)
    end
    
    AH.WeakeningFrame:SetText(text)
    AH.WeakeningFrame:SetHidden(false)
    
    if AH.WeakeningTimer then
        EM:UnregisterForUpdate(AH.WeakeningTimer)
    end
    AH.WeakeningTimer = EM:RegisterForUpdate("MarkTrialHelperWeakening", 100, AH.ShowWeakening)
end