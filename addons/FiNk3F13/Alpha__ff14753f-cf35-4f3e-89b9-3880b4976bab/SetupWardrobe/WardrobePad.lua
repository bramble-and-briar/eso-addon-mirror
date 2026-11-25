local keys = {
    {name="Aus", id="off"},
    {name="Aufgabenwechsel (Steuerkreuz rechts)", id="quest"},
    {name="Karte (Touchpad)", id="map", layer="ControllerWardrobeMap"},
    {name="Waffe ziehen / wegstecken", id="weapon", layer="ControllerWardrobeWeapon"},
}

local dispatch
function ControllerWardrobePadDown(key)
    if dispatch then dispatch(key) end
end

function ControllerWardrobeInstallPad(state, choose, nextSetup, directSetup)
    local layers = {}
    local function bindingsChanged()
        for _,key in ipairs(keys) do
            if key.layer then
                local wanted = IsInGamepadPreferredMode() and (state.padNext==key.id or state.padDirect==key.id)
                if wanted and not layers[key.id] then
                    layers[key.id] = ZO_ActionLayerFragment:New(key.layer)
                    HUD_SCENE:AddFragment(layers[key.id])
                elseif not wanted and layers[key.id] then
                    HUD_SCENE:RemoveFragment(layers[key.id])
                    layers[key.id] = nil
                end
            end
        end
    end
    local function selector(label, field, other)
        local function entries()
            local list={}
            for _,key in ipairs(keys) do
                if key.id=="off" or key.id~=state[other] then
                    list[#list+1]={name=key.name,id=key.id,data=#list+1}
                end
            end
            return list
        end
        choose(label,entries,function()
            for i,key in ipairs(entries()) do if key.id==state[field] then return i end end
            return 1
        end,function(i)
            state[field]=entries()[i].id
            bindingsChanged()
        end)
    end
    selector("WWDPad · Nächstes Setup","padNext","padDirect")
    selector("WWDPad · Direkt zum Zielsetup","padDirect","padNext")

    local lastPress = -1000
    local captured = false
    dispatch = function(key)
        if not IsInGamepadPreferredMode() or HUD_SCENE.state~="shown" then return end
        local action
        if state.padNext==key then action=nextSetup
        elseif state.padDirect==key then action=directSetup
        else return end
        local now=GetGameTimeMilliseconds()
        if now-lastPress>=800 then lastPress=now; action() end
        return true
    end
    local hooked = {}
    local function install()
        local tracker=HUD_TRACKER_MANAGER
        if tracker and tracker.BeginAssistInteract and tracker.EndAssistInteract and not hooked[tracker] then
            hooked[tracker]=true
            ZO_PreHook(tracker,"BeginAssistInteract",function()
                captured=dispatch("quest")==true
                return captured
            end)
            ZO_PreHook(tracker,"EndAssistInteract",function()
                local consumed=captured
                captured=false
                return consumed
            end)
        end
        local quests=FOCUSED_QUEST_TRACKER
        if quests and quests.AssistNext and not hooked[quests] then
            hooked[quests]=true
            ZO_PreHook(quests,"AssistNext",function() return dispatch("quest") end)
        end
        bindingsChanged()
    end
    HUD_SCENE:RegisterCallback("StateChange",function(_,s) if s~="shown" then captured=false end end)
    EVENT_MANAGER:RegisterForEvent("ControllerWardrobePad",EVENT_GAMEPAD_PREFERRED_MODE_CHANGED,bindingsChanged)
    EVENT_MANAGER:RegisterForEvent("ControllerWardrobePad",EVENT_PLAYER_ACTIVATED,install)
    install()
end
