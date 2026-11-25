-- ESO appends grammar tags such as ^m and ^p to localized game names.
function ControllerWardrobeDisplayName(raw)
    local text = zo_strformat("<<1>>", raw or "")
    return (text:gsub("%^[mMfFnNpP][%a]*", ""))
end

function ControllerWardrobeCreatePreview(board, slots, bars, skillRow, icon, locate)
    local wm = WINDOW_MANAGER
    local pane = wm:CreateControl(nil, board, CT_BACKDROP)
    pane:SetAnchor(TOPLEFT, board, TOPLEFT)
    pane:SetDimensions(594,662)
    pane:SetCenterColor(0.035,0.045,0.05,0.95)
    pane:SetEdgeColor(0.38,0.37,0.32,0.85)

    local function label(parent,x,y,width,font,text)
        local c = wm:CreateControl(nil,parent,CT_LABEL)
        c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y)
        c:SetWidth(width)
        c:SetFont(font or "ZoFontGamepad18")
        c:SetMaxLineCount(1)
        if text then
            c:SetText(text)
            c:SetColor(0.86,0.77,0.55,1)
        end
        return c
    end
    local title = label(pane,16,8,562,"ZoFontGamepad27")
    local empty = label(pane,16,55,562,nil,"Freier Platz · Mit „Aktuelles Setup speichern“ belegen.")
    local body = wm:CreateControl(nil,pane,CT_CONTROL)
    body:SetAnchorFill(pane)
    local skillBars = {}
    for i=1,2 do
        local x = 16+(i-1)*289
        label(body,x,44,270,nil,i==1 and "Frontbar" or "Backbar")
        skillBars[i] = label(body,x,67,270,"ZoFontGamepad27")
    end
    label(body,16,111,424,nil,"Ausrüstung")
    label(body,457,111,124,nil,"Eigenschaft")
    local gear = {}
    for i=1,#slots do
        local y = 138+(i-1)*23
        gear[i] = { label(body,16,y,435), label(body,457,y,130) }
    end
    label(body,16,464,560,nil,"Championpunkte · aktive Sterne")
    local stars, colors = {}, {{0.59,0.85,0.51},{0.45,0.80,1},{1,0.59,0.52}}
    for i=1,12 do
        stars[i] = label(body,16+((i-1)%2)*289,490+math.floor((i-1)/2)*20,278)
        stars[i]:SetColor(unpack(colors[math.ceil(i/4)]))
    end
    label(body,16,614,562,nil,"Bufffood")
    local food = label(body,16,636,562)
    return function(name, setup)
        title:SetText(name)
        empty:SetHidden(setup ~= nil)
        body:SetHidden(setup == nil)
        if not setup then return end
        for i,bar in ipairs(bars) do skillBars[i]:SetText(skillRow(setup,bar,30)) end
        for i,slot in ipairs(slots) do
            local link = setup.links and setup.links[slot]
            local uid = setup.gear and setup.gear[slot]
            if (not link or link=="") and uid and uid~="" then
                local bag, index = locate(uid)
                if bag then link = GetItemLink(bag,index,LINK_STYLE_DEFAULT) end
            end
            local item, trait = nil, "–"
            if link and link~="" then
                local text = ControllerWardrobeDisplayName(zo_strformat("<<t:1>>",GetItemLinkName(link)))
                local quality = GetItemQualityColor(GetItemLinkDisplayQuality(link))
                item = icon(GetItemLinkIcon(link),20).." "..quality:Colorize(text)
                local id = GetItemLinkTraitInfo(link)
                if id and id>0 then trait=ControllerWardrobeDisplayName(GetString("SI_ITEMTRAITTYPE",id)) end
            else
                item = ControllerWardrobeDisplayName(setup.gearNames and setup.gearNames[slot])
                if item=="" then item=ControllerWardrobeDisplayName(GetString("SI_EQUIPSLOT",slot)).."  –" end
            end
            gear[i][1]:SetText(item)
            gear[i][2]:SetText(trait)
        end
        for i,star in ipairs(stars) do
            local id = setup.cp and setup.cp[i]
            star:SetText(id and id>0 and ControllerWardrobeDisplayName(GetChampionSkillName(id)) or "–")
        end
        food:SetText(ControllerWardrobeDisplayName(setup.food or "Noch nicht gespeichert"))
    end
end
