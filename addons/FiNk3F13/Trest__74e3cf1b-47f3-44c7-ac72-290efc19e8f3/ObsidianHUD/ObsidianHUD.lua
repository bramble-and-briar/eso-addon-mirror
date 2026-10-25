local O=ObsidianHUD
local playerActive=false
local swapUpdate=O.name.."SwapSync"

local function hotbarUpdated()
    EVENT_MANAGER:UnregisterForUpdate(swapUpdate)
    O.Tick()
    if not O.vars.enabled or not playerActive then return end
    -- Refresh now, then once next frame after ESO's own action bar handlers.
    -- This avoids depending on event-handler order during a hotbar change.
    EVENT_MANAGER:RegisterForUpdate(swapUpdate,0,function()
        EVENT_MANAGER:UnregisterForUpdate(swapUpdate)
        O.Tick()
    end)
end

function O.Tick()
    if not O.root then return end
    if O.nativeMoving and not O.vars.enabled then O.StopNativeMove(); return end
    if O.moving and not O.vars.enabled then O.StopMove(); return end
    O.UpdateMaterials()
    O.UpdateClassIcon()
    local hud=playerActive and (HUD_SCENE:IsShowing() or HUD_UI_SCENE:IsShowing())
    local visible=O.vars.enabled and hud
    O.root:SetHidden(not (visible or O.moving) or not O.materialReady)
    O.SyncNativeResources()
    if visible then O.UpdateResources() end
    O.UpdateSkills(visible)
    O.UpdateNativePositions()
end

function O.Refresh()
    O.Layout()
    O.Tick()
end

local function initialize(_,name)
    if name~=O.name then return end
    EVENT_MANAGER:UnregisterForEvent(O.name,EVENT_ADD_ON_LOADED)
    O.vars=ZO_SavedVars:NewAccountWide("ObsidianHUDSavedVariables",1,nil,O.defaults)
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
    EVENT_MANAGER:RegisterForEvent(O.name,EVENT_PLAYER_ACTIVATED,function() playerActive=true; O.Refresh() end)
    EVENT_MANAGER:RegisterForEvent(O.name,EVENT_PLAYER_DEACTIVATED,function()
        EVENT_MANAGER:UnregisterForUpdate(swapUpdate)
        playerActive=false; O.StopMove(); O.StopNativeMove(); O.root:SetHidden(true); O.ReleaseSkills()
    end)
    EVENT_MANAGER:RegisterForEvent(O.name,EVENT_POWER_UPDATE,function(_,unit)
        if unit=="player" and O.vars.enabled then O.UpdateResources() end
    end)
    EVENT_MANAGER:AddFilterForEvent(O.name,EVENT_POWER_UPDATE,REGISTER_FILTER_UNIT_TAG,"player")
    EVENT_MANAGER:RegisterForEvent(O.name,EVENT_GAMEPAD_PREFERRED_MODE_CHANGED,function() O.StopNativeMove(); O.Refresh() end)
    EVENT_MANAGER:RegisterForEvent(O.name,EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED,hotbarUpdated)
    EVENT_MANAGER:RegisterForUpdate(O.name.."Refresh",250,O.Tick)
    SLASH_COMMANDS["/obsidian"]=function(input)
        input=string.lower(zo_strtrim(input or ""))
        if input=="status" then O.PrintMaterialStatus(); return
        elseif input=="move" then O.StartMove(); return
        elseif input=="move skills" then O.StartNativeMove("skills"); return
        elseif input=="move ult" then O.StartNativeMove("ultimate"); return
        elseif input=="move pots" then O.StartNativeMove("quickslot"); return
        elseif input=="move buffs" then O.StartNativeMove("buffs"); return
        elseif input=="off" then O.vars.enabled=false
        elseif input=="on" then O.vars.enabled=true
        else O.vars.enabled=not O.vars.enabled end
        O.Refresh()
        d("Obsidian HUD: "..(O.vars.enabled and "an" or "aus - Originalanzeigen wiederhergestellt"))
    end
end
EVENT_MANAGER:RegisterForEvent(O.name,EVENT_ADD_ON_LOADED,initialize)
