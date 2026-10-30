local O=ObsidianHUD
local suppressedBars,suppressedArt,skins={},{},{}
local quickslotSkin,quickslotArt=nil,{}
local invisible=function() return false end

function O.ReleaseResources()
    for bar,old in pairs(suppressedBars) do
        if bar.externalVisibilityRequirement==invisible then
            bar:SetExternalVisibilityRequirement(old.requirement)
            bar:UpdateStatusBar()
        end
    end
    suppressedBars={}
end

function O.SyncNativeResources()
    if not O.vars.enabled or not O.vars.hideOriginals or not O.materialReady then O.ReleaseResources(); return end
    if not O.root or not PLAYER_ATTRIBUTE_BARS or not PLAYER_ATTRIBUTE_BARS.bars then return end
    for _,bar in ipairs(PLAYER_ATTRIBUTE_BARS.bars) do
        local power=bar.powerType
        if bar.unitTag=="player" and (power==COMBAT_MECHANIC_FLAGS_HEALTH or
            power==COMBAT_MECHANIC_FLAGS_MAGICKA or power==COMBAT_MECHANIC_FLAGS_STAMINA) then
            if not suppressedBars[bar] then suppressedBars[bar]={requirement=bar.externalVisibilityRequirement} end
            bar:SetExternalVisibilityRequirement(invisible)
            bar:UpdateContextualFading()
        end
    end
end

local function suppressArt(control)
    if not control then return end
    if suppressedArt[control]==nil then suppressedArt[control]=control:GetAlpha() end
    control:SetAlpha(0)
end

local function restoreArt()
    for control,alpha in pairs(suppressedArt) do control:SetAlpha(alpha) end
    suppressedArt={}
end

function O.SuppressNativeSkillText(button)
    suppressArt(button.timerText)
    suppressArt(button.stackCountText)
end

function O.ReleaseSkills()
    O.ReleaseFixedBindings()
    O.previewActiveBar=nil
    if O.barIndicator then O.barIndicator:SetHidden(true) end
    for _,skin in pairs(skins) do
        O.HideUltimateCharge(skin)
        O.StopPreviewSwap(skin)
        skin.frame:SetHidden(true); skin.back:SetHidden(true); skin.timerBar=nil; skin.timerVisible=false
        O.HideSkillText(skin)
    end
    restoreArt()
end

function O.AnimatePreviewSwap(previous)
    if O.IsFixedSkillView() then return end -- Fixed rows retain weapon identity.
    local active=GetActiveHotbarCategory()
    if previous==nil or previous==active or not O.OtherBar(previous) or not O.OtherBar(active) then return end
    local now=GetFrameTimeSeconds()
    for _,skin in pairs(skins) do O.StartPreviewSwap(skin,now) end
end

function O.FinishNativeSkillAnimations(button)
    if not button then return end
    -- "Ohne Animation" refers only to the weapon-bar transition. A skill's
    -- own pressed/bounce animation and glow remain active in every view.
    for _,key in ipairs({"hotbarSwapAnimation","timerSwapAnimation","stackCountSwapAnimation"}) do
        local timeline=button[key]
        if timeline and timeline:IsPlaying() then timeline:PlayInstantlyToEnd(false) end
    end
end

function O.FinishFixedUltimateSwap()
    if O.NoSkillAnimationsView() and O.vars.enabled and O.OtherBar(GetActiveHotbarCategory()) and ZO_ActionBar_GetButton then
        for slot=3,8 do O.FinishNativeSkillAnimations(ZO_ActionBar_GetButton(slot)) end
        return
    end
    if not O.vars.enabled or not O.IsFixedSkillView() or not O.vars.backBar
        or not O.OtherBar(GetActiveHotbarCategory()) or not ZO_ActionBar_GetButton then return end
    local button=ZO_ActionBar_GetButton(8)
    if not button then return end
    -- Only the ultimate skips the weapon-swap flip. Normal skills keep their
    -- native animation; activation/bounce timelines are left untouched here.
    for _,key in ipairs({"hotbarSwapAnimation","timerSwapAnimation","stackCountSwapAnimation"}) do
        local timeline=button[key]
        if timeline and timeline:IsPlaying() then timeline:PlayInstantlyToEnd(false) end
    end
end

function O.BackBarTimerText(slot,bar)
    local effect=O.GetSkillTimerRemaining(slot,bar)
    local remaining=effect or 0
    -- Recast cooldown and effect duration are different clocks. Never start
    -- a second countdown when an effect ends. Pots retain native cooldowns.
    if remaining<=0 then return "" end
    -- Match ActionButton:UpdateTimer instead of rounding up by a whole second.
    return ZO_FormatTimeShowUnitOverThresholdShowDecimalUnderThreshold(remaining/1000,
        ZO_ONE_MINUTE_IN_SECONDS,ZO_EFFECT_EXPIRATION_IMMINENCE_THRESHOLD_S,TIME_FORMAT_STYLE_SHOW_LARGEST_UNIT)
end

function O.IsSkillProcReady(slot,bar)
    local id=GetSlotBoundId(slot,bar)
    if not id or id<=0 then return false end
    if ActionSlotHasActivationHighlight and ActionSlotHasActivationHighlight(slot,bar)==true then return true end
    if O.procReadyAbilities and O.procReadyAbilities[id] then return true end
    local source=O.stackSources and O.stackSources[id]
    local threshold=O.procStackThresholds and O.procStackThresholds[source or id]
    return threshold~=nil and O.GetSkillStackCount(slot,bar)>=threshold or false
end
function O.IsStackProcSkill(slot,bar)
    local id=GetSlotBoundId(slot,bar)
    local source=O.stackSources and O.stackSources[id]
    return (O.procReadyAbilities and O.procReadyAbilities[id]) or
        (O.procStackThresholds and O.procStackThresholds[source or id]~=nil) or false
end
function O.StopSkillProcHighlight(control)
    if not control then return end
    control:SetHidden(true)
    if control.procGlow then control.procGlow:SetHidden(true) end
    if control.procAnimation then control.procAnimation:GetTimeline():Stop() end
    control.procReady=false
end
function O.UpdateSkillProcHighlight(skin,back,slot,bar,visible)
    local control=back and skin.procBack or skin.procFront
    if not control then return false end
    local usable=(not IsSlotUsable or IsSlotUsable(slot,bar)~=false)
        and (not ActionSlotHasNonCostStateFailure or ActionSlotHasNonCostStateFailure(slot,bar)~=true)
    local ready=visible and not back and bar==GetActiveHotbarCategory()
        and usable and O.IsSkillProcReady(slot,bar) or false
    if not ready then
        if control.procReady then O.StopSkillProcHighlight(control) else control:SetHidden(true) end
        return false
    end
    local _,_,texture=GetSlotTexture(slot,bar)
    if type(texture)~="string" or texture=="" then texture="esoui/art/actionbar/abilityhighlightanimation.dds" end
    if not control.procReady or control.procTexture~=texture then
        control.procTexture=texture
        control:SetTexture(texture)
        if CreateSimpleAnimation then
            if not control.procAnimation then control.procAnimation=CreateSimpleAnimation(ANIMATION_TEXTURE,control) end
            -- Same 64-frame layout and playback as ESO's ActivationHighlight.
            control.procAnimation:SetImageData(64,1)
            control.procAnimation:SetFramerate(30)
            local timeline=control.procAnimation:GetTimeline()
            timeline:SetPlaybackType(ANIMATION_PLAYBACK_LOOP,LOOP_INDEFINITELY)
            timeline:PlayFromStart()
        else
            -- A static native glow is still valid if animation is unavailable;
            -- never show the whole animation atlas as one distorted image.
            control:SetTexture("esoui/art/hud/gamepad/gp_skillglow.dds")
            control:SetTextureCoords(0.1875,0.8125,0.1875,0.8125)
        end
        control.procReady=true
    end
    if control.procGlow then control.procGlow:SetHidden(false) end
    control:SetHidden(false)
    return ready
end

function O.UpdateBackBarTimer(skin)
    if skin.timerBar==nil or not skin.timerVisible then return end
    local displayed=O.SkillDisplayBar and O.SkillDisplayBar(skin.button) or GetActiveHotbarCategory()
    local other=O.OtherBar(displayed)
    if other~=skin.timerBar then return end
    local text=O.BackBarTimerText(skin.timerSlot,other)
    skin.timer:SetText(text)
    O.UpdateStackText(skin.backStacks,skin.timerSlot,other)
    O.UpdateSkillProcHighlight(skin,true,skin.timerSlot,other,true)
    -- Bar identity, not a running effect, determines the inactive icon's tint.
    -- Keep the parent and text untouched so timers and stacks remain legible.
    if not skin.previewMuted or skin.previewTintRevision~=O.textRevision then
        skin.previewMuted=true; skin.previewTintRevision=O.textRevision
        local c={0.55,0.55,0.55}
        skin.backIcon:SetDesaturation(1)
        skin.backIcon:SetColor(0.7,0.7,0.7,1)
        skin.backMetal:SetDesaturation(1)
        skin.backMetal:SetColor(c[1],c[2],c[3],1)
        for i,edge in ipairs(skin.back.edges) do edge:SetColor(c[1],c[2],c[3],i==1 and 1 or 0.65) end
    end
end

local function hasRunningSkill(slot,bar)
    return O.IsSkillProcReady(slot,bar) or O.BackBarTimerText(slot,bar)~="" or O.GetSkillStackCount(slot,bar)>0
        or (IsSlotToggled and IsSlotToggled(slot,bar)) or false
end

local function styleSlot(skin,visible)
    skin.frame:SetHidden(not visible)
    local asset=ObsidianHUDAssetsFantasySlot
    local useArt=asset and asset:IsTextureLoaded()
    local c=O.vars.skillFrameColor or O.vars.accent
    skin.art:SetHidden(not useArt)
    skin.art:SetColor(unpack(c))
    if skin.backMetal then
        skin.backMetal:SetHidden(not useArt)
    end
    for _,frame in ipairs({skin.frame,skin.back}) do
        for i,edge in ipairs(frame.edges) do
            if frame==skin.frame then edge:SetColor(c[1],c[2],c[3],i==1 and 1 or 0.65) end
            edge:SetHidden(useArt==true)
        end
    end
end

local function restoreQuickslotArt()
    for control,alpha in pairs(quickslotArt) do
        if control:GetAlpha()==0 then control:SetAlpha(alpha) end
    end
    quickslotArt={}
end

function O.SkillPreviewTexture(slot,bar)
    local id=O.GetSkillAbilityId and O.GetSkillAbilityId(slot,bar) or GetSlotBoundId(slot,bar)
    id=tonumber(id) or 0
    if id<=0 then return nil end
    local texture=GetSlotTexture(slot,bar)
    -- Inactive slots can temporarily have no native slot texture during a
    -- weapon swap. The slotted ability still supplies its own icon.
    if type(texture)~="string" or texture=="" then
        texture=GetAbilityIcon and GetAbilityIcon(id)
    end
    return type(texture)=="string" and texture~="" and texture or nil
end

function O.UpdateSkillPreview(skin,slot,active,visible)
    if O.SkillDisplayBar then active=O.SkillDisplayBar(skin.button) end
    local other=O.OtherBar(active)
    local texture=other and O.SkillPreviewTexture(slot,other)
    local show=(slot~=8 or O.DualUltimateView()) and visible and O.vars.backBar and texture~=nil
        and (O.vars.skillHudView~="running" or hasRunningSkill(slot,other))
    if O.IsFixedSkillView() then
        O.StopPreviewSwap(skin)
        skin.back:SetAlpha(1)
    end
    O.LayoutSkillPreview(skin)
    skin.back:SetHidden(not show)
    skin.timerVisible=show
    if not show then
        O.StopPreviewSwap(skin)
        O.StopSkillProcHighlight(skin.procBack)
    end
    if texture then
        O.SetPreviewTexture(skin,texture)
        skin.timerSlot,skin.timerBar=slot,other
        O.UpdateBackBarTimer(skin)
    else
        skin.timerBar=nil; skin.timer:SetText(""); skin.backStacks:SetText("")
    end
end

function O.UpdateQuickslot(visible)
    restoreQuickslotArt()
    if not O.vars.enabled or not O.vars.quickslotFrame or not ZO_ActionBar_GetButton then
        if quickslotSkin then quickslotSkin.frame:SetHidden(true) end
        return
    end
    local button=ZO_ActionBar_GetButton(1,HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    if not button or not button.slot or not button.icon then
        if quickslotSkin then quickslotSkin.frame:SetHidden(true) end
        return
    end
    if not quickslotSkin or quickslotSkin.button~=button then
        if quickslotSkin then quickslotSkin.frame:SetHidden(true) end
        quickslotSkin=O.CreateSlotSkin(button,true)
    end
    styleSlot(quickslotSkin,visible)
    -- Hide only the decorative backing; native item count, cooldown, keybinds
    -- and input controls remain owned by ESO.
    if visible then
        local backing=button.slot:GetNamedChild("Backdrop")
        if backing then quickslotArt[backing]=backing:GetAlpha(); backing:SetAlpha(0) end
    end
end

function O.UpdateSkills(visible)
    if not O.vars.skillFrames or not O.vars.enabled or not ZO_ActionBar_GetButton then O.ReleaseSkills(); return end
    local active=GetActiveHotbarCategory()
    local other=O.OtherBar(active)
    if not other then O.ReleaseSkills(); return end -- Preserve temporary/special ESO ability bars.
    O.previewActiveBar=active
    -- Category changes can precede the action bar's own category update. Release
    -- the previous targets before resolving the currently active/back controls.
    restoreArt()
    for slot=3,8 do
        local button=ZO_ActionBar_GetButton(slot)
        if button and button.icon and button.slot then
            local skin=skins[slot]
            if not skin or skin.button~=button then
                if skin then O.HideUltimateCharge(skin); O.StopPreviewSwap(skin); skin.frame:SetHidden(true); skin.back:SetHidden(true); skin.timerVisible=false; O.HideSkillText(skin) end
                skin=O.CreateSkillSkin(button); skins[slot]=skin
            end
            if O.NoSkillAnimationsView() then O.FinishNativeSkillAnimations(button)
            elseif slot==8 then O.FinishFixedUltimateSwap() end
            styleSlot(skin,visible)
            skin.activeTextSlot=slot
            O.UpdateSkillPreview(skin,slot,active,visible)
            O.StyleSkillText(skin)
            skin.activeTextSlot,skin.activeTextBar,skin.activeTextVisible=slot,active,visible
            skin.textRoot:SetHidden(not visible)
            skin.activeTimer:ClearAnchors()
            skin.activeTimer:SetAnchor(CENTER,button.slot,CENTER,0,slot==8 and -9 or 0)
            O.UpdateActiveSkillText(skin)
            if slot==8 then skin.timer:SetText(""); skin.backStacks:SetText("") end
            if slot==8 then O.UpdateUltimateCharge(skin) end
            -- Keep native skill controls and keybinds; only replace decorative art.
            suppressArt(button.slot:GetNamedChild("Backdrop"))
            if slot==8 then suppressArt(button.slot:GetNamedChild("Decoration")) end
            if slot==8 then
                for _,name in ipairs({"Frame","FillAnimationLeft","FillAnimationRight","ReadyBurst","ReadyLoop"}) do suppressArt(button.slot:GetNamedChild(name)) end
            end
            if O.vars.backBar or slot==8 then
                local nativeBack=ZO_ActionBar_GetButton(slot,other)
                -- During a swap the category lookup can still resolve to the
                -- active button. Never hide that button (or its child preview).
                if nativeBack and nativeBack~=button and nativeBack.slot and nativeBack.slot~=button.slot then
                    suppressArt(nativeBack.slot)
                end
            end
        end
    end
    O.UpdateBarIndicator(ZO_ActionBar_GetButton(3),active,visible and O.vars.backBar)
end
