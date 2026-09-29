--- @class Srendarr
local Srendarr = _G['Srendarr'] -- grab addon table from global
local LMP = LibMediaProvider

-- UPVALUES --
local PlaySound = PlaySound

local procAbilityNames = Srendarr.procAbilityNames
local crystalFragments = Srendarr.crystalFragments -- special case for tracking fragments proc

local slotData = Srendarr.slotData
local procAnims = {}
local animsEnabled, procSound


-- ------------------------
-- PROC HANDLING
-- ------------------------
function Srendarr:ProcAnimationStart(slot, silent, reset)
    if reset then Srendarr:ProcAnimationStop(slot) end

    if (animsEnabled and procAnims[slot] ~= nil and not procAnims[slot].isPlaying) then -- no need to start if already playing
        procAnims[slot].loopTexture:SetHidden(false)
        procAnims[slot].loop:PlayFromStart()
        procAnims[slot].isPlaying = true

        if Srendarr.slotData[slot] then
            local abilityName = Srendarr.slotData[slot].abilityName
            if (abilityName == crystalFragments) and (Srendarr.crystalFragmentsProc) then return end
        end

        if not silent then
            if (self.db.procModifier) then                                                -- temporarily overrides Audio Effects volume when playing the Srendarr proc sound (Phinix)
                local soundBase = GetSetting(SETTING_TYPE_AUDIO, AUDIO_SETTING_UI_VOLUME) -- store Audio Effects volume to revert after change (Phinix)
                SetSetting(SETTING_TYPE_AUDIO, AUDIO_SETTING_UI_VOLUME, Srendarr.db.procVolume)
                PlaySound(procSound)
                -- restore Audio Effects volume to the last value set by the user after playing the proc sound (Phinix)
                zo_callLater(function () SetSetting(SETTING_TYPE_AUDIO, AUDIO_SETTING_UI_VOLUME, soundBase) end, 1000)
            else
                PlaySound(procSound)
            end
        end
    end
end

function Srendarr:ProcAnimationStop(slot)
    if (procAnims[slot] and procAnims[slot].isPlaying) then
        procAnims[slot].isPlaying = false
        procAnims[slot].loopTexture:SetHidden(true)
        procAnims[slot].loop:Stop()
    end
end

function Srendarr:OnCrystalFragmentsProc(onGain)
    if (onGain) then
        procAbilityNames[crystalFragments] = true
        for slot = 3, 7 do
            if (slotData[slot].abilityName == crystalFragments) then
                self:ProcAnimationStart(slot)
                break
            end
        end
        Srendarr.crystalFragmentsProc = true
    else
        procAbilityNames[crystalFragments] = false
        for slot = 3, 7 do
            if (slotData[slot].abilityName == crystalFragments) then
                self:ProcAnimationStop(slot)
                break
            end
        end
        zo_callLater(function () Srendarr.crystalFragmentsProc = false end, 400) -- need to wait briefly before resetting crystal fragments proc state due to wrong state spam from EVENT_EFFECT_CHANGED (Phinix)
    end
end

-- ------------------------
-- PROC INIT & CONFIG
-- ------------------------
function Srendarr:HideGrimActivationHighlight(button)
    if self.db.grimProcAnims then return end
    if not button or not button.activationHighlight then return end

    local slot = button:GetSlot()
    local hotbarCategory = button:GetHotbarCategory()
    local abilityID = self.GetSlotBoundAbilityId(slot, hotbarCategory)
    if not self.grimBar[abilityID] then return end

    local highlight = button.activationHighlight
    highlight:SetHidden(true)
    local anim = highlight.animation
    if anim then
        anim:GetTimeline():Stop()
    end
end

function Srendarr:ConfigureProcs()
    animsEnabled = self.db.procEnableAnims
    procSound = LMP:Fetch('sound', self.db.procPlaySound)

    if (not animsEnabled) then -- hide animations if not using
        for slot = 3, 7 do
            procAnims[slot].isPlaying = false
            procAnims[slot].loopTexture:SetHidden(true)
            procAnims[slot].loop:Stop()
        end
    end
end

function Srendarr:InitializeProcs()
    local button, ctrl

    for slot = 3, 7 do
        button = ZO_ActionBar_GetButton(slot)
        local button_slot = button and button.slot
        procAnims[slot] = {}

        ctrl = WINDOW_MANAGER:CreateControl(nil, button_slot, CT_TEXTURE)
        ctrl:SetAnchor(TOPLEFT, button_slot:GetNamedChild('FlipCard'))
        ctrl:SetAnchor(BOTTOMRIGHT, button_slot:GetNamedChild('FlipCard'))
        ctrl:SetTexture([[esoui/art/actionbar/abilityhighlight_mage_med.dds]])
        ctrl:SetBlendMode(TEX_BLEND_MODE_ADD)
        ctrl:SetDrawLevel(2)
        ctrl:SetHidden(true)

        procAnims[slot].isPlaying = false
        procAnims[slot].loopTexture = ctrl

        procAnims[slot].loop = ANIMATION_MANAGER:CreateTimelineFromVirtual('UltimateReadyLoop', ctrl)
        procAnims[slot].loop:SetHandler('OnStop', function ()
            procAnims[slot].loopTexture:SetHidden(true)
        end)

        SecurePostHook(button, 'UpdateActivationHighlight', function (actionButton)
            Srendarr:HideGrimActivationHighlight(actionButton)
        end)
    end

    self:ConfigureProcs()
end