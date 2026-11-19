local C=CompanionSidekick
local WM=WINDOW_MANAGER
local format,concat,sort=string.format,table.concat,table.sort
local palettes={
    Teal={background={.025,.065,.068},title={.055,.19,.19},border={.24,.53,.48}},
    Plum={background={.09,.055,.13},title={.25,.12,.36},border={.63,.48,.78}},
    Emerald={background={.035,.10,.075},title={.075,.27,.18},border={.36,.67,.49}},
    Ocean={background={.035,.075,.12},title={.07,.21,.34},border={.35,.60,.79}},
    Ember={background={.12,.055,.035},title={.34,.13,.065},border={.79,.49,.30}},
    Midnight={background={.055,.06,.075},title={.14,.16,.21},border={.48,.53,.64}},
    Rose={background={.12,.045,.075},title={.33,.10,.20},border={.78,.43,.61}},
}
local paletteOrder={"Teal","Plum","Emerald","Ocean","Ember","Midnight","Rose"}
local surfaces={}
local function appearance()
    local settings=C.db.settings
    if type(settings.appearanceByCharacter)~="table" then settings.appearanceByCharacter={}end
    local choice=settings.appearanceByCharacter[C.characterId]
    if type(choice)~="table" then choice={};settings.appearanceByCharacter[C.characterId]=choice end
    for _,part in ipairs({"background","title","border"})do
        if not palettes[choice[part]]then choice[part]="Teal"end
    end
    return choice
end
function C.ApplyAppearance()
    local choice=appearance()
    for _,surface in ipairs(surfaces)do
        local part=surface.part=="title" and "title" or "background"
        local color=palettes[choice[part]][part]
        local shade=surface.part=="row" and 1.25 or 1
        surface.control:SetCenterColor(color[1]*shade,color[2]*shade,color[3]*shade,.97)
        local border=palettes[choice.border].border
        surface.control:SetEdgeColor(border[1],border[2],border[3],1)
    end
    if C.appearanceCombos then
        for _,part in ipairs({"background","title","border"})do C.appearanceCombos[part]:SetSelectedItem(choice[part])end
        local preset=choice.background==choice.title and choice.title==choice.border and choice.title or "Custom"
        C.appearanceCombos.preset:SetSelectedItem(preset)
    end
end
function C.SetAppearance(part,name)
    if not palettes[name]then return false end
    local choice=appearance()
    if part=="preset" then choice.background=name;choice.title=name;choice.border=name
    elseif part=="background" or part=="title" or part=="border" then choice[part]=name
    else return false end
    C.ApplyAppearance();return true
end
local function label(parent,text,x,y,w,font)
    local c=WM:CreateControl(nil,parent,CT_LABEL)
    c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);c:SetWidth(w);c:SetFont(font or "ZoFontGameSmall")
    c:SetColor(.90,.95,.94,1);c:SetText(text or "");return c
end
local function button(parent,text,x,y,w,fn)
    local c=WM:CreateControlFromVirtual(nil,parent,"ZO_DefaultButton")
    c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);c:SetDimensions(w,28);c:SetFont("ZoFontGameSmall")
    c:SetText(text);c:SetHandler("OnClicked",fn);return c
end
local function backdrop(parent,part)
    local bg=WM:CreateControl(nil,parent,CT_BACKDROP);bg:SetAnchorFill()
    bg:SetEdgeTexture("",1,1,1)
    surfaces[#surfaces+1]={control=bg,part=part}
    C.ApplyAppearance();return bg
end
local function scroll(parent,name,x,y,w,h)
    local sc=WM:CreateControlFromVirtual(name,parent,"ZO_ScrollContainer")
    sc:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);sc:SetDimensions(w,h)
    local child=sc:GetNamedChild("ScrollChild");child:SetWidth(w-22)
    return child
end
local function window(name,title,w,h)
    local root=WM:CreateTopLevelWindow(name)
    root:SetDimensions(w,h);root:SetAnchor(CENTER,GuiRoot,CENTER,0,0)
    root:SetMouseEnabled(true);root:SetMovable(true);root:SetClampedToScreen(true);root:SetDrawTier(DT_HIGH)
    backdrop(root,"background")
    local header=WM:CreateControl(nil,root,CT_CONTROL)
    header:SetAnchor(TOPLEFT,root,TOPLEFT,0,0);header:SetDimensions(w,44)
    backdrop(header,"title")
    label(header,title,14,8,w-130,"ZoFontWinH3")
    root:SetHidden(true)
    return root
end
function C.ApplyScale()
    for _,root in ipairs({C.window,C.detail,C.appearanceWindow})do if root then root:SetScale(C.db.settings.scale or .85)end end
    if C.sizeValue then C.sizeValue:SetText(format("%d%%",math.floor((C.db.settings.scale or .85)*100+.5)))end
end
function C.SetScalePercent(percent)
    percent=tonumber(percent)
    if not percent or percent~=percent then return false end
    C.db.settings.scale=math.max(.55,math.min(1.2,percent/100));C.ApplyScale();return true
end
function C.ShowAppearance()
    if not C.appearanceWindow then
        local root=window("CompanionSidekickAppearance","COLORS & SIZE",500,410)
        root:SetDrawLevel(30)
        button(root,"X",442,8,40,function()root:SetHidden(true)end)
        C.appearanceCombos={}
        for i,row in ipairs({{"preset","Color preset"},{"background","Background"},{"title","Title bar"},{"border","Borders"}})do
            local part=row[1]
            label(root,row[2],20,63+(i-1)*47,150,"ZoFontGame")
            local container=WM:CreateControlFromVirtual("CompanionSidekickColor"..part,root,"ZO_ComboBox")
            container:SetAnchor(TOPLEFT,root,TOPLEFT,190,58+(i-1)*47);container:SetDimensions(285,30)
            local combo=ZO_ComboBox_ObjectFromContainer(container);combo:SetSortsItems(false)
            C.appearanceCombos[part]=combo
            for _,name in ipairs(paletteOrder)do
                local colorName=name
                combo:AddItem(combo:CreateItemEntry(colorName,function()C.SetAppearance(part,colorName)end))
            end
        end
        label(root,"Window size",20,260,150,"ZoFontGame")
        button(root,"Smaller",190,253,100,function()C.SetScalePercent((C.db.settings.scale or .85)*100-5)end)
        C.sizeValue=label(root,"",305,259,65,"ZoFontGame")
        button(root,"Larger",375,253,100,function()C.SetScalePercent((C.db.settings.scale or .85)*100+5)end)
        button(root,"Reset Colors",20,310,175,function()C.SetAppearance("preset","Teal")end)
        button(root,"Reset Size",215,310,175,function()C.SetScalePercent(85)end)
        label(root,"Colors save per character. Size applies across this account.",20,357,460)
        label(root,"Changes apply instantly. Size range: 55-120%.",20,380,460)
        C.appearanceWindow=root
    end
    C.ApplyAppearance();C.ApplyScale();C.appearanceWindow:SetHidden(false)
end
function C.SelectedRecord(id)
    local char=C.selectedCharacter and C.db.characters[C.selectedCharacter]
    return char and char.companions and char.companions[id],char
end
local function level(id)
    local shared=C.db.shared[id]
    return shared and shared.level and tostring(shared.level) or "?"
end
function C.BuildProgress(e,r,char)
    local b=C.db.shared[e.id]
    local rows={e.name,"",char and (char.name.." | "..C.UnlockText(r)) or "Account overview",
        "Companion level: "..level(e.id).." / 20 (shared)",
        "Permanent perk: "..C.KeepsakeText(e),""}
    if char then
        rows[#rows+1]="RAPPORT: "..C.RapportText(r)
        rows[#rows+1]="Rapport last seen: "..C.Age(r and r.rapportSeen)
        rows[#rows+1]="Completion: "..C.Progress(e,r)
        rows[#rows+1]="Quest / unlock snapshot: "..C.Age(r and r.seen)
        rows[#rows+1]=""
        rows[#rows+1]="QUESTS ON THIS CHARACTER"
        for _,q in ipairs(r and r.quests or {})do
            local state=q.active and "[Active]" or (q.complete==true and "[Done]" or (q.complete==false and "[Not done]" or "[Unknown]"))
            rows[#rows+1]=state.." "..q.name
            if q.active and q.objective and q.objective~="" then rows[#rows+1]="  "..q.objective end
        end
        if not r then rows[#rows+1]="Log into this character to record their quests and unlocks."end
    else rows[#rows+1]="Choose a character for their quest chain, current objective and rapport."end
    rows[#rows+1]="";rows[#rows+1]="PERK & KEEPSAKE"
    rows[#rows+1]=C.Clean(GetAbilityName(e.perkId))
    rows[#rows+1]=C.Clean(GetAbilityDescription(e.perkId))
    rows[#rows+1]="Summoned perk and permanent keepsake are different unlocks."
    for _,text in ipairs(C.Requirements(e))do rows[#rows+1]=text end
    rows[#rows+1]="";rows[#rows+1]="Build last seen: "..C.Age(b and b.seen)
    rows[#rows+1]="Unseen information is Unknown. Other characters are last-seen records."
    return concat(rows,"\n")
end
function C.BuildEquipment(e)
    local b=C.db.shared[e.id]
    local rows={e.name.." | SHARED BUILD","Level: "..level(e.id).." / 20","",
        "EQUIPPED ABILITY PRIORITY (left to right)","Skills last seen: "..C.Age(b and b.skillsSeen)}
    if not b or not b.bar then rows[#rows+1]="Summon this companion to scan their equipped skills."
    else
        for i,a in ipairs(b.bar)do rows[#rows+1]=(i==6 and "Ultimate: " or i..". ")..a.name end
    end
    rows[#rows+1]="";rows[#rows+1]="EQUIPMENT"
    rows[#rows+1]="Gear last seen: "..C.Age(b and b.gearSeen)
    if not b or not b.gear then rows[#rows+1]="Summon this companion to scan their gear."
    else
        for _,item in ipairs(b.gear)do
            local slot=GetString("SI_EQUIPSLOT",item.slot)
            if item.name then
                local quality=GetString("SI_ITEMDISPLAYQUALITY",item.quality)
                local trait=GetString("SI_ITEMTRAITTYPE",item.trait)
                rows[#rows+1]=slot..": "..item.name.." | "..quality.." | "..trait
            else rows[#rows+1]=slot..": Empty / unused"end
        end
    end
    rows[#rows+1]="";rows[#rows+1]="SKILL LINES & ABILITIES"
    for _,line in ipairs(b and b.lines or {})do
        rows[#rows+1]=format("%s | Rank %d%s",line.name,line.rank,line.discovered and "" or " | Undiscovered")
        for _,a in ipairs(line.abilities)do
            rows[#rows+1]=format("  %s%s %s (rank %d)",a.unlocked and "[Unlocked] " or "[Locked] ",
                a.passive and "Passive: " or "",a.name,a.required)
        end
    end
    rows[#rows+1]="";rows[#rows+1]="This build is shared by your characters. This tracker does not equip items or change skills."
    return concat(rows,"\n")
end
function C.BuildCharacters(e)
    local list={};for id,char in pairs(C.db.characters)do list[#list+1]={id=id,char=char}end
    sort(list,function(a,b)return a.char.name<b.char.name end)
    local rows={e.name.." | CHARACTER ACCESS",""}
    for _,item in ipairs(list)do
        local r=item.char.companions and item.char.companions[e.id]
        rows[#rows+1]=item.char.name.." | "..C.UnlockText(r)
        rows[#rows+1]="  Rapport: "..C.RapportText(r)
        rows[#rows+1]="  "..C.QuestSummary(e,r).." | Seen: "..C.Age(r and r.seen)
        rows[#rows+1]=""
    end
    rows[#rows+1]="Log into each character once. Summon each companion to capture rapport."
    return concat(rows,"\n")
end
function C.RenderDetail()
    if not C.detail or C.detail:IsHidden()then return end
    local e=C.byId[C.selectedCompanion]
    if not e then return end
    local r,char=C.SelectedRecord(e.id)
    local text
    if C.detailTab=="build" then text=C.BuildEquipment(e)
    elseif C.detailTab=="characters" then text=C.BuildCharacters(e)
    else text=C.BuildProgress(e,r,char)end
    C.detailText:SetText(text)
    local _,height=C.detailText:GetTextDimensions()
    C.detailChild:SetHeight(math.max(390,height+20))
end
function C.ShowDetail(id)
    C.selectedCompanion=id;C.detail:SetHidden(false);C.detailTab="progress";C.RenderDetail()
end
function C.Render()
    if not C.window or C.window:IsHidden()then C.RenderDetail();return end
    local char=C.selectedCharacter and C.db.characters[C.selectedCharacter]
    for i,e in ipairs(C.catalog)do
        local row=C.rows[i]
        if not row then
            row=WM:CreateControl(nil,C.rowChild,CT_BUTTON)
            row:SetDimensions(802,34);row:SetAnchor(TOPLEFT,C.rowChild,TOPLEFT,0,(i-1)*36)
            row:SetMouseEnabled(true);row.bg=backdrop(row,"row")
            row.text={}
            for n,col in ipairs({{8,159},{172,103},{280,116},{400,34},{440,90},{537,257}})do
                row.text[n]=label(row,"",col[1],7,col[2]);row.text[n]:SetMaxLineCount(1)
            end
            row:SetHandler("OnClicked",function(self)C.ShowDetail(self.companionId)end)
            C.rows[i]=row
        end
        row.companionId=e.id;row:SetHidden(false)
        local r=char and char.companions and char.companions[e.id]
        local access,rapport,quest
        if char then
            access=C.UnlockText(r);rapport=r and r.rapport~=nil and tostring(r.rapport).." "..(r.rapportName or "") or "Not scanned"
            quest=C.QuestSummary(e,r)
        else
            local unlocked,scanned,total=C.AccountCounts(e.id)
            access=format("%d/%d chars",unlocked,total);rapport=scanned.." scanned"
            quest="Click for details / character access"
        end
        local values={e.name,access,rapport,level(e.id),C.KeepsakeText(e),quest}
        for n,text in ipairs(values)do row.text[n]:SetText(text)end
    end
    C.rowChild:SetHeight(math.max(230,#C.catalog*36))
    C.footer:SetText(C.indexing and "Indexing quest names and permanent perks..." or
        (char and (char.name.." | Snapshot: "..C.Age(char.seen).." | Click a row for quests, gear, skills and character access.")
        or "Log into alts; summon companions to record rapport, gear and skills. Click a row for details."))
    C.RenderDetail()
end
function C.ShowHelp()
    C.detail:SetHidden(false);C.selectedCompanion=nil
    C.detailText:SetText("COMPANION SIDEKICK\n\n/csidekick - open or close\n/csidekick refresh - rescan\n/csidekick scale 70 - set size (55-120%)\n\nColors & Size in the title bar opens color presets, independent colors and window sizing. Use Smaller/Larger or Reset Size there.\n\nChoose a character or Account overview. Click a companion row.\n\nProgress: recruitment, personal quests and active objective, rapport and permanent keepsake requirements.\nBuild: shared level, equipped gear, skill bar, skill lines and ability unlocks.\nCharacters: who has recruited this companion.\n\nLog into every character once. Summon each companion to record their rapport and build. Offline character data is last-seen, never live. Unseen data says Unknown. NA and EU are separate.\n\nThe first scan indexes story names and keepsakes. This build has English story-name mappings; other client languages may show personal quests as Unknown. Recruitment, rapport and builds use game APIs. Unsupported keepsakes stay Unknown.\n\nComplete means recruitment, recorded personal quests, level 20 and permanent keepsake are all complete. It does not mean every skill line is maxed.\n\nNo messages are sent to other players. No companion is auto-summoned and no gear or skills are changed.\n\nTest build: live ESO UI and companion scans still need in-game verification.")
    local _,h=C.detailText:GetTextDimensions();C.detailChild:SetHeight(h+30)
end
function C.CreateUI()
    C.window=window("CompanionSidekickWindow","COMPANION SIDEKICK",850,440)
    local root=C.window
    local body=WM:CreateControl(nil,root,CT_CONTROL);body:SetAnchor(TOPLEFT,root,TOPLEFT,0,46);body:SetDimensions(850,394)
    C.body=body
    local x,y=C.db.settings.x,C.db.settings.y
    if x and y then root:ClearAnchors();root:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,x,y)end
    root:SetHandler("OnMoveStop",function(self)C.db.settings.x=self:GetLeft();C.db.settings.y=self:GetTop()end)
    button(root,"?",686,8,34,C.ShowHelp)
    button(root,"Colors & Size",553,8,125,C.ShowAppearance)
    button(root,"_",728,8,34,function()
        C.minimized=not C.minimized;body:SetHidden(C.minimized);root:SetHeight(C.minimized and 44 or 440)
    end)
    button(root,"X",772,8,48,function()
        root:SetHidden(true);C.detail:SetHidden(true)
        if C.appearanceWindow then C.appearanceWindow:SetHidden(true)end
    end)
    label(body,"Character",16,5,95)
    local dropdown=WM:CreateControlFromVirtual("CompanionSidekickCharacters",body,"ZO_ComboBox")
    dropdown:SetAnchor(TOPLEFT,body,TOPLEFT,96,0);dropdown:SetDimensions(325,30)
    C.combo=ZO_ComboBox_ObjectFromContainer(dropdown);C.combo:SetSortsItems(false)
    C.combo:AddItem(C.combo:CreateItemEntry("Account overview",function()C.selectedCharacter=nil;C.Render()end))
    local chars={};for id,char in pairs(C.db.characters)do chars[#chars+1]={id=id,char=char}end
    sort(chars,function(a,b)return a.char.name<b.char.name end)
    for _,item in ipairs(chars)do
        local id=item.id
        C.combo:AddItem(C.combo:CreateItemEntry(item.char.name,function()C.selectedCharacter=id;C.Render()end))
    end
    C.selectedCharacter=C.characterId;C.combo:SetSelectedItem(C.characterName)
    button(body,"Refresh",444,0,100,C.Refresh)
    for _,col in ipairs({{"Companion",24,150},{"Access",188,98},{"Rapport",296,106},{"Lv",416,30},{"Keepsake",456,86},{"Quest / overview",553,245}})do
        label(body,col[1],col[2],43,col[3])
    end
    C.rowChild=scroll(body,"CompanionSidekickRosterScroll",16,69,820,271);C.rows={}
    C.footer=label(body,"",16,348,810)
    C.detail=window("CompanionSidekickDetail","COMPANION DETAILS",620,565)
    C.detail:SetDrawLevel(20)
    button(C.detail,"X",558,8,40,function()C.detail:SetHidden(true)end)
    button(C.detail,"Progress",18,54,170,function()C.detailTab="progress";C.RenderDetail()end)
    button(C.detail,"Gear & Skills",218,54,170,function()C.detailTab="build";C.RenderDetail()end)
    button(C.detail,"Characters",418,54,170,function()C.detailTab="characters";C.RenderDetail()end)
    C.detailChild=scroll(C.detail,"CompanionSidekickDetailScroll",18,96,586,451)
    C.detailText=label(C.detailChild,"",0,0,550,"ZoFontGame")
    C.ApplyScale()
end
