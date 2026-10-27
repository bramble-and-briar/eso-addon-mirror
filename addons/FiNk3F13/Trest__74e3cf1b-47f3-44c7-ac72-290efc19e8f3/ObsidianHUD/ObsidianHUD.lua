local O=ObsidianHUD
local playerActive=false
local swapUpdate=O.name.."SwapSync"

local function hotbarUpdated()
    EVENT_MANAGER:UnregisterForUpdate(swapUpdate)
    local previous=O.previewActiveBar
    O.FinishFixedUltimateSwap()
    O.Tick()
    if not O.vars.enabled or not playerActive then return end
    O.AnimatePreviewSwap(previous)
    -- Refresh now, then once next frame after ESO's own action bar handlers.
    -- This avoids depending on event-handler order during a hotbar change.
    EVENT_MANAGER:RegisterForUpdate(swapUpdate,0,function()
        EVENT_MANAGER:UnregisterForUpdate(swapUpdate)
        O.FinishFixedUltimateSwap()
        O.Tick()
    end)
end

function O.Tick()
    if not O.root then return end
    if O.nativeMoving and not O.vars.enabled then O.StopNativeMove(); return end
    if O.moving and not O.vars.enabled then O.StopMove(); return end
    O.UpdateSkillScale()
    O.UpdateMaterials()
    O.UpdateClassIcon()
    local hud=playerActive and (HUD_SCENE:IsShowing() or HUD_UI_SCENE:IsShowing())
    local visible=O.vars.enabled and hud
    if O.resourcesVisible~=visible then O.ResetResourceAnimations() end
    O.resourcesVisible=visible
    O.root:SetHidden(not (visible or O.moving) or not O.materialReady)
    O.SyncNativeResources()
    if visible then O.UpdateResources() end
    O.UpdateSkills(visible)
    O.UpdateQuickslot(visible)
    O.UpdateNativePositions()
end

function O.Refresh()
    O.textRevision=O.textRevision+1
    O.ApplyFixedFeatures()
    O.Layout()
    O.Tick()
end

local function initialize(_,name)
    if name~=O.name then return end
    EVENT_MANAGER:UnregisterForEvent(O.name,EVENT_ADD_ON_LOADED)
    O.vars=ZO_SavedVars:NewAccountWide("ObsidianHUDSavedVariables",1,nil,O.defaults)
    O.ApplyFixedFeatures()
    O.vars.blastbonesHelp=nil
    if not O.vars.fantasyLayout then
        local accent=O.vars.accent
        if accent[1]==0.66 and accent[2]==0.52 and accent[3]==0.30 then O.vars.accent={1,1,1} end
        if O.vars.width==550 then O.vars.width=480 end
        O.vars.fantasyLayout=true
    end
    O.CreateUI()
    O.CreateMoveUI()
    O.CreateNativeMoveUI()
    O.CreateSettings()
    EVENT_MANAGER:RegisterForEvent(O.name,EVENT_PLAYER_ACTIVATED,function() O.ResetStackEffects(); O.ResetSkillTimers(); playerActive=true; O.Refresh() end)
    EVENT_MANAGER:RegisterForEvent(O.name,EVENT_PLAYER_DEACTIVATED,function()
        EVENT_MANAGER:UnregisterForUpdate(swapUpdate)
        O.ResetStackEffects()
        O.ResetSkillTimers()
        playerActive=false; O.StopMove(); O.StopNativeMove(); O.root:SetHidden(true); O.ReleaseSkills()
        O.resourcesVisible=false; O.ResetResourceAnimations()
        O.UpdateQuickslot(false)
    end)
    EVENT_MANAGER:RegisterForEvent(O.name,EVENT_POWER_UPDATE,function(_,unit)
        if unit=="player" and O.vars.enabled then O.UpdateResources() end
    end)
    EVENT_MANAGER:AddFilterForEvent(O.name,EVENT_POWER_UPDATE,REGISTER_FILTER_UNIT_TAG,"player")
    EVENT_MANAGER:RegisterForEvent(O.name,EVENT_GAMEPAD_PREFERRED_MODE_CHANGED,function() O.ReleaseFixedBindings(); O.StopNativeMove(); O.Refresh() end)
    EVENT_MANAGER:RegisterForEvent(O.name,EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED,hotbarUpdated)
    EVENT_MANAGER:RegisterForEvent(O.name.."Stacks",EVENT_EFFECT_CHANGED,O.OnSkillStackEffectChanged)
    EVENT_MANAGER:AddFilterForEvent(O.name.."Stacks",EVENT_EFFECT_CHANGED,REGISTER_FILTER_UNIT_TAG,"player")
    if EVENT_ACTION_SLOT_ABILITY_USED then
        EVENT_MANAGER:RegisterForEvent(O.name.."TimerCasts",EVENT_ACTION_SLOT_ABILITY_USED,O.OnTimerAbilityUsed)
    end
    if EVENT_ACTION_SLOT_EFFECT_UPDATE then
        EVENT_MANAGER:RegisterForEvent(O.name.."TimerSlots",EVENT_ACTION_SLOT_EFFECT_UPDATE,O.OnTimerSlotEffectUpdated)
    end
    EVENT_MANAGER:RegisterForEvent(O.name.."TimerEffects",EVENT_EFFECT_CHANGED,O.OnTimerEffectChanged)
    EVENT_MANAGER:AddFilterForEvent(O.name.."TimerEffects",EVENT_EFFECT_CHANGED,REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,COMBAT_UNIT_TYPE_PLAYER)
    if EVENT_COMBAT_EVENT then
        for abilityId in pairs(O.timerExplosions) do
            local key=O.name.."TimerImpact"..abilityId
            EVENT_MANAGER:RegisterForEvent(key,EVENT_COMBAT_EVENT,O.OnTimerCombatEvent)
            EVENT_MANAGER:AddFilterForEvent(key,EVENT_COMBAT_EVENT,REGISTER_FILTER_ABILITY_ID,abilityId)
        end
    end
    EVENT_MANAGER:RegisterForUpdate(O.name.."Refresh",250,O.Tick)
    SLASH_COMMANDS["/obsidian"]=function(input)
        input=string.lower(zo_strtrim(input or ""))
        if input=="status" then O.PrintMaterialStatus(); return
        elseif input=="move" then O.StartMove(); return
        elseif input=="move skills" then O.StartNativeMove("skills"); return
        elseif input=="move ult" then O.StartNativeMove("ultimate"); return
        elseif input=="move pots" then O.StartNativeMove("quickslot"); return
        elseif input=="move buffs" then O.StartNativeMove("buffs"); return
        end
        d("Obsidian HUD: /obsidian status | /obsidian move | /obsidian move skills / ult / pots / buffs")
    end
end
EVENT_MANAGER:RegisterForEvent(O.name,EVENT_ADD_ON_LOADED,initialize)
