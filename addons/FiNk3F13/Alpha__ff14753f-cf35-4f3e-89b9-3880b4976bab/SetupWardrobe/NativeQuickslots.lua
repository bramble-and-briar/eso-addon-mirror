-- Native ESO quickslots use SE, E, NE, N, NW, W, SW, S as indices 1..8.
function SetupWardrobeNativeQuickslots(state, choose, controls, actions)
    local lib=LibHarvensAddonSettings
    state.quickslotBindings=state.quickslotBindings or {}
    local bindings=state.quickslotBindings
    local selectedSlot=8
    local lastPlain,handling
    local function actionFor(slot)
        local key=bindings[slot]
        for _,action in ipairs(actions) do if action.id==key then return action end end
    end
    local function rememberCurrent()
        local slot=GetCurrentQuickslot()
        if not actionFor(slot) then lastPlain=slot end
    end
    local function changed(_,slot)
        if handling then return end
        local action=actionFor(slot)
        if not action then lastPlain=slot; return end
        if not state.quickslotsEnabled or not IsInGamepadPreferredMode() or HUD_SCENE.state~="shown" then return end
        handling=true
        action.run()
        if state.quickslotReturn and lastPlain and not actionFor(lastPlain) then
            SetCurrentQuickslot(lastPlain)
        end
        handling=false
    end
    local function enable(value)
        state.quickslotsEnabled=value==true
        EVENT_MANAGER:UnregisterForEvent("SetupWardrobeQuickslots",EVENT_ACTIVE_QUICKSLOT_CHANGED)
        if state.quickslotsEnabled then
            rememberCurrent()
            EVENT_MANAGER:RegisterForEvent("SetupWardrobeQuickslots",EVENT_ACTIVE_QUICKSLOT_CHANGED,changed)
        end
    end
    controls[#controls+1]={type=lib.ST_CHECKBOX,label="Schnellzugriff · Belegung aktiv",
        tooltip="Eine Richtung im normalen ESO-Schnellzugriff auswählen, um die zugewiesene Setup-Aktion auszuführen.",
        getFunction=function()return state.quickslotsEnabled==true end,setFunction=enable}
    controls[#controls+1]={type=lib.ST_CHECKBOX,label="Schnellzugriff · Zum Trankplatz zurück",
        tooltip="Nach der Setup-Aktion wieder den zuletzt gewählten unbelegten Schnellplatz auswählen. So lässt sich dieselbe Setup-Richtung erneut wählen.",
        getFunction=function()return state.quickslotReturn==true end,
        setFunction=function(value)state.quickslotReturn=value==true;rememberCurrent()end}
    local directions={"SO · Südost","O · Ost","NO · Nordost","N · Nord","NW · Nordwest","W · West","SW · Südwest","S · Süd"}
    choose("Schnellzugriff · Richtung",function()
        local entries={}
        for i,name in ipairs(directions)do entries[i]={name=name,data=i}end
        return entries
    end,function()return selectedSlot end,function(i)selectedSlot=i end)
    local function entries()
        local result={{name="Normale ESO-Funktion",data=1}}
        for _,action in ipairs(actions)do
            result[#result+1]={name=action.name,id=action.id,data=#result+1}
        end
        return result
    end
    choose("Schnellzugriff · Aktion",entries,function()
        for i,entry in ipairs(entries())do if entry.id==bindings[selectedSlot] then return i end end
        return 1
    end,function(i)
        bindings[selectedSlot]=entries()[i].id
        if lastPlain and actionFor(lastPlain)then lastPlain=nil end
        rememberCurrent()
    end)
    enable(state.quickslotsEnabled)
end
