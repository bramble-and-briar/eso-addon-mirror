-- The gamepad settings list, loadout preview and raid list share one screen.
local function icon(path, size)
    if not path or path == "" then return "· " end
    return string.format("|t%d:%d:%s|t", size, size, path)
end

local function skillRow(setup, bar, size)
    local row = {}
    for slot = 3, 8 do
        local id = setup.skills and setup.skills[bar] and setup.skills[bar][slot]
        row[#row+1] = (slot == 8 and "  " or "") .. icon(id and id > 0 and GetAbilityIcon(id), size)
    end
    return table.concat(row)
end

function ControllerWardrobeMenu(sv, state, slots, bars, title, save, loadSetup, locate, refreshHud, pending, cancel)
    local lib = LibHarvensAddonSettings
    state.pages = state.pages or {{ name = "Seite 1", ids = {1, 2, 3, 4} }}
    state.nextId = state.nextId or 5
    if #state.pages == 0 then state.pages[1] = {name="Seite 1", ids={1,2,3,4}} end
    for id in pairs(state.setups) do
        if type(id)=="number" then state.nextId=math.max(state.nextId,id+1) end
    end
    for _,p in ipairs(state.pages) do
        for _,id in ipairs(p.ids) do state.nextId=math.max(state.nextId,id+1) end
    end
    local pageIndex = math.max(1, math.min(state.pageIndex or 1, #state.pages))
    local function page() return state.pages[pageIndex] end
    local position = 1
    local function current() return page().ids[position] end
    local raidList = {{name="Eigene Seiten", data=1}}
    local raidIndex = {}
    for index, raid in ipairs(ControllerWardrobeRaids) do
        raidIndex[raid.tag] = index
        raidList[index+1] = {name=raid.name, data=index+1}
    end
    local function raid()
        return ControllerWardrobeRaids[raidIndex[page().raid]]
    end
    local board = WINDOW_MANAGER:CreateTopLevelWindow("ControllerWardrobeOverview")
    board:SetDimensions(1040, 662)
    board:SetHidden(true)
    local function fit()
        local left = GAMEPAD_TOOLTIPS:GetTooltipContainer(GAMEPAD_LEFT_TOOLTIP):GetLeft()
        local width, height = GuiRoot:GetWidth(), GuiRoot:GetHeight()
        local available = width - (left or width * 0.32) - 24
        board:SetScale(math.min(1, math.max(1,available)/1040, height*0.83/662))
        board:ClearAnchors()
        board:SetAnchor(RIGHT, GuiRoot, RIGHT, -12, 0)
    end
    local drawPreview = ControllerWardrobeCreatePreview(board, slots, bars, skillRow, icon, locate)
    local panel = WINDOW_MANAGER:CreateControl(nil, board, CT_CONTROL)
    panel:SetDimensions(438,662)
    panel:SetAnchor(RIGHT, board, RIGHT)
    local bg = WINDOW_MANAGER:CreateControl(nil, panel, CT_BACKDROP)
    bg:SetAnchorFill(panel)
    bg:SetCenterColor(0.035, 0.045, 0.05, 0.93)
    bg:SetEdgeColor(0.38, 0.37, 0.32, 0.85)
    local function label(x, y, width, font)
        local c = WINDOW_MANAGER:CreateControl(nil, panel, CT_LABEL)
        c:SetAnchor(TOPLEFT, panel, TOPLEFT, x, y)
        c:SetWidth(width)
        c:SetFont(font)
        c:SetMaxLineCount(1)
        return c
    end
    local badge = WINDOW_MANAGER:CreateControl(nil, panel, CT_TEXTURE)
    badge:SetAnchor(TOPLEFT, panel, TOPLEFT, 12, 12)
    badge:SetDimensions(48,48)
    local zone = label(72, 7, 357, "ZoFontGamepad27")
    local heading = label(72, 38, 357, "ZoFontGamepad18")
    heading:SetColor(0.86, 0.77, 0.55, 1)
    local rows = {}
    for i = 1, 14 do
        local y = 70 + (i-1)*41
        local highlight = WINDOW_MANAGER:CreateControl(nil, panel, CT_TEXTURE)
        highlight:SetAnchor(TOPLEFT, panel, TOPLEFT, 5, y)
        highlight:SetDimensions(428,40)
        highlight:SetColor(0.24,0.55,0.50,0.34)
        rows[i] = {label(16,y,282,"ZoFontGamepad22"),label(305,y,128,"ZoFontGamepad18"),
            label(305,y+18,128,"ZoFontGamepad18"), label(16,y+22,282,"ZoFontGamepad18"), highlight}
    end
    local function redraw()
        local trial = raid()
        drawPreview(title(current()), state.setups[current()])
        zone:SetText(ControllerWardrobeDisplayName(trial and trial.name or page().zone or "Eigene Seiten"))
        badge:SetTexture(trial and trial.icon or "/esoui/art/icons/gear_breton_heavy_chest_d.dds")
        local count = 0
        for _,id in ipairs(page().ids) do if state.setups[id] then count=count+1 end end
        heading:SetText(page().name .. "   ·   " .. count .. "/" .. #page().ids .. " gespeichert")
        local first = math.floor((position-1)/14)*14
        for i, row in ipairs(rows) do
            local n = first+i
            local id = page().ids[n]
            local setup = state.setups[id]
            local boss = page().encounters and page().encounters[id]
            row[1]:SetText(id and ((n == position and "|c83e4cf› " or "") .. (boss or title(id)) .. "|r") or "")
            local detail = id and boss and title(id) ~= boss and title(id) or nil
            row[4]:SetText(id and (detail or (setup and "Gespeichert" or "Freier Platz")) or "")
            row[4]:SetColor(0.72,0.75,0.73,1)
            row[5]:SetHidden(n ~= position)
            for j, bar in ipairs(bars) do row[j+1]:SetText(setup and skillRow(setup, bar, 16) or "") end
        end
    end
    local fragment = ZO_SimpleSceneFragment:New(board)
    CALLBACK_MANAGER:RegisterCallback("LibHarvensAddonSettings_AddonSelected", function(_, newMenu)
        if lib.scene then
            if newMenu == sv then fit(); redraw(); lib.scene:AddFragment(fragment)
            else lib.scene:RemoveFragment(fragment) end
        end
    end)
    local function refresh()
        redraw()
        sv:UpdateControls()

    end
    local function addSlot()
        local id = state.nextId
        state.nextId = id+1
        table.insert(page().ids, id)
        position = #page().ids
        return id
    end
    local function newPage(trial)
        local tag = trial and trial.tag
        local number = 1
        for _,p in ipairs(state.pages) do if p.raid == tag then number=number+1 end end
        pageIndex = #state.pages+1
        state.pages[pageIndex] = {name="Seite "..number, raid=tag, ids={}, encounters={}}
        state.pageIndex = pageIndex
        if trial then
            for _,boss in ipairs(trial.bosses) do
                local id = addSlot()
                state.names[id], page().encounters[id] = boss, boss
            end
        else addSlot() end
        position = 1
    end
    local controls = {}
    local function button(name, action)
        controls[#controls+1] = {type=lib.ST_BUTTON, label=name, buttonText=name, tooltip="", clickHandler=action}
    end
    local function edit(name, get, set)
        controls[#controls+1] = {type=lib.ST_EDIT, label=name, tooltip="", getFunction=get,
            setFunction=function(v) if v and v:find("%S") then set(v); refreshHud(); refresh() end end}
    end
    local function choose(name, list, value, action)
        controls[#controls+1] = {type=lib.ST_DROPDOWN, label=name, items=list, tooltip="",
            getFunction=function() return list()[value()].name end,
            setFunction=function(_, _, entry) if entry.data ~= value() then action(entry.data); refresh() end end}
    end
    choose("Prüfung / Raid", function() return raidList end,
        function() return (raidIndex[page().raid] or 0)+1 end, function(index)
            local trial = ControllerWardrobeRaids[index-1]
            local tag = trial and trial.tag
            for i,p in ipairs(state.pages) do
                if p.raid == tag then pageIndex,state.pageIndex,position=i,i,1; return end
            end
            newPage(trial)
        end)
    local function raidPages()
        local entries = {}
        for i,p in ipairs(state.pages) do
            if p.raid == page().raid then
                entries[#entries+1]={name=p.name,data=#entries+1,index=i}
            end
        end
        return entries
    end
    choose("Seite", raidPages, function()
        for i,p in ipairs(raidPages()) do if p.index==pageIndex then return i end end
    end,function(i) pageIndex=raidPages()[i].index; state.pageIndex=pageIndex; position=1 end)
    choose("Boss / Setup", function()
        local entries = {}
        for i,id in ipairs(page().ids) do entries[i]={name=i .. ". " .. title(id),data=i} end
        return entries
    end, function() return position end, function(i)
        position=i
        if state.quick and state.setups[current()] then loadSetup(current()) end
    end)
    controls[#controls+1] = {type=lib.ST_CHECKBOX,label="Schnell ausrüsten",tooltip="",
        getFunction=function() return state.quick == true end,setFunction=function(v) state.quick=v end}
    button("Ausgewähltes Setup laden",function() loadSetup(current()) end)
    button("Aktuelles Setup speichern",function() save(current()); refresh() end)
    ControllerWardrobeInstallPad(state,choose,function()
        if pending() then return end
        local p = page()
        local start = 0
        local cursor = state.last
        if cursor == p.padReturnFromTarget then cursor = p.padPrevious end
        for i,id in ipairs(p.ids) do if id == cursor then start=i; break end end
        for offset=1,#p.ids do
            local i=(start+offset-1)%#p.ids+1
            local id=p.ids[i]
            if state.setups[id] then
                position=i
                p.padReturnFromTarget=nil
        p.padPrevious=id
                loadSetup(id)
                return
            end
        end
        d("SetupWardrobe – Auf dieser Seite ist noch kein Setup gespeichert.")
    end,function()
        if pending() then return end
        local p=page()
        if not p.padTarget or not state.setups[p.padTarget] then
            d("SetupWardrobe – Wähle zuerst ein WWDPad-Zielsetup für diese Seite.")
            return
        end
        if state.last~=p.padTarget then p.padPrevious=state.last end
        p.padReturnFromTarget=p.padTarget
        loadSetup(p.padTarget)
    end)
    local function targetEntries()
        local entries={{name="Kein Zielsetup",data=1}}
        for _,id in ipairs(page().ids) do
            if state.setups[id] then entries[#entries+1]={name=title(id),id=id,data=#entries+1} end
        end
        return entries
    end
    choose("WWDPad · Zielsetup dieser Seite",targetEntries,function()
        for i,entry in ipairs(targetEntries()) do if entry.id==page().padTarget then return i end end
        return 1
    end,function(i) page().padTarget=targetEntries()[i].id end)
    button("Setup erstellen",function() addSlot(); refresh() end)
    edit("Setup umbenennen",function() return title(current()) end,function(v) state.names[current()]=v end)
    choose("Reihenfolge",function()
        local entries={}
        for i=1,#page().ids do entries[i]={name=tostring(i),data=i} end
        return entries
    end,function() return position end,function(i)
        table.insert(page().ids,i,table.remove(page().ids,position)); position=i
    end)
    button("Seite erstellen",function()
        newPage(raid()); refresh()
    end)
    edit("Seite umbenennen",function() return page().name end,function(v) page().name=v end)
    local confirmKey, untilMS
    local function confirmed(key)
        if pending() then d("SetupWardrobe – Bitte den Wechsel abwarten."); return false end
        local now=GetGameTimeMilliseconds()
        if confirmKey==key and now<untilMS then confirmKey=nil; return true end
        confirmKey,untilMS=key,now+3500
        d("SetupWardrobe – Zum Löschen innerhalb von 3 Sekunden erneut drücken.")
    end
    local function forget(id)
        if page().padTarget==id then page().padTarget=nil end
        if page().padReturnFromTarget==id then page().padReturnFromTarget=nil end
        if page().padPrevious==id then page().padPrevious=nil end
        if page().encounters then page().encounters[id]=nil end
        state.setups[id],state.names[id]=nil,nil
        if state.last==id then state.last=nil end
    end
    button("Setup löschen",function()
        if not confirmed("setup"..current()) then return end
        forget(table.remove(page().ids,position))
        position=math.min(position,#page().ids)
        if position==0 then addSlot() end
        refreshHud(); refresh()
    end)
    button("Seite löschen",function()
        if not confirmed("page"..page().ids[1]) then return end
        for _,id in ipairs(page().ids) do forget(id) end
        table.remove(state.pages,pageIndex)
        pageIndex=math.max(1,math.min(pageIndex,#state.pages))
        if not page() then state.pages[1]={name="Seite 1",ids={}}; addSlot() end
        position,state.pageIndex=1,pageIndex
        refreshHud(); refresh()
    end)
    local quickslotActions={}
    do
        local function register(addon,name,id,texture,run,description)
            quickslotActions[#quickslotActions+1]={name=name,id=id,run=run}
            if LibRadialMenu then LibRadialMenu:RegisterEntry(addon,name,id,texture,run,description) end
        end
        local texture="/esoui/art/icons/gear_breton_heavy_chest_d.dds"
        local function loadPosition(index)
            if pending() then d("SetupWardrobe – Bitte den Wechsel abwarten."); return end
            local id=page().ids[index]
            if not id or not state.setups[id] then
                d("SetupWardrobe – Dieser Platz auf der ausgewählten Raid-Seite ist leer.")
                return
            end
            position=index
            page().padReturnFromTarget=nil
            loadSetup(id)
            redraw()
        end
        for i=1,4 do
            register("ControllerWardrobe","Setup "..i,"setup"..i,texture,
                function() loadSetup(i) end,"Ursprünglicher Schnellplatz "..i)
        end
        for i=1,14 do
            register("ControllerWardrobe","Raid-Seite · Setup "..i,"pageSetup"..i,texture,
                function() loadPosition(i) end,"Platz "..i.." der ausgewählten Raid-Seite laden.")
        end
        for _,delta in ipairs({-1,1}) do
            local text=delta==1 and "Nächstes Setup" or "Vorheriges Setup"
            register("ControllerWardrobe",text,"cycle"..delta,texture,function()
                if pending() then d("SetupWardrobe – Bitte den Wechsel abwarten."); return end
                local ids=page().ids
                local start=position
                for i,id in ipairs(ids) do if id==state.last then start=i; break end end
                for offset=1,#ids do
                    local i=(start-1+offset*delta)%#ids+1
                    if state.setups[ids[i]] then loadPosition(i); return end
                end
                d("SetupWardrobe – Diese Seite enthält kein gespeichertes Setup.")
            end,text.." der ausgewählten Seite laden")
        end
        register("ControllerWardrobe","Aktuelles Setup erneut laden","reloadCurrent",texture,function()
            local index=position
            for i,id in ipairs(page().ids) do if id==state.last then index=i; break end end
            loadPosition(index)
        end,"Das zuletzt geladene Setup der ausgewählten Raid-Seite erneut anlegen.")
        register("ControllerWardrobe","Zum ersten Setup zurück","resetSequence",texture,function()
            if pending() then d("SetupWardrobe – Bitte den Wechsel abwarten."); return end
            for i,id in ipairs(page().ids) do
                if state.setups[id] then
                    page().padPrevious=nil
                    loadPosition(i)
                    return
                end
            end
            d("SetupWardrobe – Diese Seite enthält kein gespeichertes Setup.")
        end,"Reihenfolge neu beginnen und das erste gespeicherte Setup der ausgewählten Seite laden.")
        register("ControllerWardrobe","Wechsel abbrechen","cancelSwap",texture,function()
            if cancel then cancel() end
        end,"Einen laufenden oder im Kampf vorgemerkten Wechsel beenden. Bereits angelegte Teile bleiben angelegt.")
    end
    SetupWardrobeNativeQuickslots(state,choose,controls,quickslotActions)
    sv:AddSettings(controls,nil,false)
end
