local O=ObsidianHUD
local suppressedBars,suppressedArt,skins={},{},{}
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

function O.ReleaseSkills()
    for _,skin in pairs(skins) do skin.frame:SetHidden(true); skin.back:SetHidden(true) end
    restoreArt()
end

function O.UpdateSkills(visible)
    if not O.vars.skillFrames or not O.vars.enabled or not ZO_ActionBar_GetButton then O.ReleaseSkills(); return end
    local active=GetActiveHotbarCategory()
    local other=O.OtherBar(active)
    if not other then O.ReleaseSkills(); return end -- Preserve temporary/special ESO ability bars.
    -- Category changes can precede the action bar's own category update. Release
    -- the previous targets before resolving the currently active/back controls.
    restoreArt()
    for slot=3,8 do
        local button=ZO_ActionBar_GetButton(slot)
        if button and button.icon and button.slot then
            local skin=skins[slot]
            if not skin or skin.button~=button then
                if skin then skin.frame:SetHidden(true); skin.back:SetHidden(true) end
                skin=O.CreateSkillSkin(button); skins[slot]=skin
            end
            skin.frame:SetHidden(not visible)
            local slotArt=ObsidianHUDAssetsFantasySlot
            local useArt=slotArt and slotArt:IsTextureLoaded()
            skin.art:SetHidden(not useArt)
            skin.backMetal:SetHidden(not useArt)
            skin.art:SetColor(unpack(O.vars.accent))
            skin.backMetal:SetColor(unpack(O.vars.accent))
            for i,edge in ipairs(skin.frame.edges) do
                local c=O.vars.accent
                edge:SetColor(c[1],c[2],c[3],i==1 and 1 or 0.65)
                edge:SetHidden(useArt==true)
            end
            local texture=GetSlotTexture(slot,other)
            local hasSkill=texture and texture~="" and GetSlotBoundId(slot,other)~=0
            skin.back:SetHidden(not visible or not O.vars.backBar or not hasSkill)
            if hasSkill then
                skin.backIcon:SetTexture(texture)
                local remain,duration,global=GetSlotCooldownInfo(slot,other)
                local effect=GetActionSlotEffectTimeRemaining and GetActionSlotEffectTimeRemaining(slot,other) or 0
                local seconds=not global and (remain or 0)>0 and remain/1000 or (effect or 0)/1000
                skin.timer:SetText(seconds>=1 and tostring(math.ceil(seconds)) or "")
            end
            -- Keep native skill controls and keybinds; only replace decorative art.
            suppressArt(button.slot:GetNamedChild("Backdrop"))
            if slot==8 then suppressArt(button.slot:GetNamedChild("Decoration")) end
            if O.vars.backBar then
                local nativeBack=ZO_ActionBar_GetButton(slot,other)
                -- During a swap the category lookup can still resolve to the
                -- active button. Never hide that button (or its child preview).
                if nativeBack and nativeBack~=button and nativeBack.slot and nativeBack.slot~=button.slot then
                    suppressArt(nativeBack.slot)
                end
            end
        end
    end
end
