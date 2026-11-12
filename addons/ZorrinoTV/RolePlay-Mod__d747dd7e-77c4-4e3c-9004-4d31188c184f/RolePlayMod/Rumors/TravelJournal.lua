if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Travel leads are saved only on explicit request; heard history is not a notebook.
local B=IHR_Runtime.Beta
local T={};B.TravelJournal=T
local book,rows,heading,entryTitle,entryText,entryStatus,sourceLabel,regionLabel,strike,pageLabel,previous,nextPage
local selected,region,city,listPage,textPage=nil,nil,nil,1,1
local gamepadFocus,gamepadActive=1,false
local listPageCount,textPageCount=1,1
local inquiryButton,backButton,exitButton
local oldNotebook=B.ShowNotebook
local BOOK_SIZE=1024
local function hideBook()
    B.travelJournalVisible=false
    if T.GamepadClearFocus then T.GamepadClearFocus() end
    if book then book:SetHidden(true) end
end
function T.IsOpen() return book~=nil and not book:IsHidden() end
local function viewport()
    return math.max(1,GuiRoot:GetWidth()),math.max(1,GuiRoot:GetHeight()),
        type(GuiRoot.GetLeft)=='function' and GuiRoot:GetLeft() or 0,
        type(GuiRoot.GetTop)=='function' and GuiRoot:GetTop() or 0
end
local function finite(value) return type(value)=='number' and value==value and math.abs(value)<math.huge end
function T.Layout()
    if not book then return end
    local width,height=viewport()
    local margin=math.min(16,width*.03,height*.03)
    local scale=math.min(1,(width-margin*2)/BOOK_SIZE,(height-margin*2)/BOOK_SIZE)
    book:SetScale(scale)
    local x,y=(width-BOOK_SIZE*scale)/2,(height-BOOK_SIZE*scale)/2
    local pos=B.saved and B.saved.travelJournalPosition
    if type(pos)=='table' and finite(pos.x) and finite(pos.y) then x=pos.x*width;y=pos.y*height end
    x=math.max(margin,math.min(x,width-BOOK_SIZE*scale-margin))
    y=math.max(margin,math.min(y,height-BOOK_SIZE*scale-margin))
    book:ClearAnchors();book:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,x,y)
    if B.saved then B.saved.travelJournalPosition={x=x/width,y=y/height} end
end
function T.SavePosition()
    if not book or not B.saved then return end
    local width,height,left,top=viewport()
    B.saved.travelJournalPosition={x=(book:GetLeft()-left)/width,y=(book:GetTop()-top)/height}
    T.Layout() -- A dragged edge is clamped and saved in the same coordinate space.
end
local function data()
    B.saved.travelJournalV1=B.saved.travelJournalV1 or {entries={}}
    return B.saved.travelJournalV1
end
function T.Has(id) return B.saved and data().entries[tostring(id)]~=nil end
local function active(id,name,names)
    if type(HasQuest)=='function' and HasQuest(id) then return true end
    return names[B.Normalize(name)] or false
end
function T.Refresh()
    if not B.saved then return end
    local names={}
    if next(data().entries) then for _,q in ipairs(B.Quests()) do names[B.Normalize(q.name)]=true end end
    for _,e in pairs(data().entries) do
        if type(HasCompletedQuest)=='function' and HasCompletedQuest(e.quest) then e.completed=true;e.started=true end
        if not e.started and active(e.quest,e.questName,names) then e.started=true;e.startedAt=GetTimeStamp() end
    end
end
function T.Note(r,text,npc)
    if not r or not r.quest or type(text)~='string' or text=='' or not npc then return false end
    local entries=data().entries;local key=tostring(r.quest)
    if entries[key] then return false end
    local zoneId=npc.zoneId
    if type(GetParentZoneId)=='function' and zoneId then local parent=GetParentZoneId(zoneId);if parent and parent>0 then zoneId=parent end end
    local area=type(GetZoneNameById)=='function' and zoneId and GetZoneNameById(zoneId) or ''
    if r.regionName and r.regionName~='' then area=r.regionName end
    if area=='' and type(GetZoneNameByIndex)=='function' then area=GetZoneNameByIndex(npc.zoneIndex or GetUnitZoneIndex('player')) end
    local town=r.town or select(2,B.TavernTown(npc)) or npc.locality
    local name=type(GetQuestName)=='function' and GetQuestName(r.quest) or ''
    entries[key]={quest=r.quest,questName=B.Name(name~='' and name or r.title or r.giver),giver=r.giver,
        text=text,speaker=npc.name,region=B.Name(area~='' and area or 'Région inconnue'),city=B.Name(town and town~='' and town or 'Lieu inconnu'),
        time=GetTimeStamp(),mapKey=r.mapKey,anchor=r.anchor and {x=r.anchor.x,y=r.anchor.y} or nil,
        route=r.route,reference=r.reference,source=r.source}
    T.Refresh();return true
end
function T.Groups()
    T.Refresh();local groups={}
    for _,e in pairs(data().entries) do groups[e.region]=groups[e.region] or {};groups[e.region][e.city]=true end
    return groups
end
local function sorted(t) local keys={};for key in pairs(t) do keys[#keys+1]=key end;table.sort(keys);return keys end
-- Split only at ASCII whitespace; Lua's locale classes can split UTF-8 accents.
function T.Pages(text)
    local pages={};text=RPM_LOCALE.Text(text or '')
    while #text>450 do
        local cut
        for pos in text:sub(1,450):gmatch('()[ \t\r\n]') do cut=pos end
        cut=cut or 450
        while cut>1 and text:byte(cut+1) and text:byte(cut+1)>=128 and text:byte(cut+1)<192 do cut=cut-1 end
        pages[#pages+1]=text:sub(1,cut);text=text:sub(cut+1)
    end
    pages[#pages+1]=text;return pages
end
local function label(font,x,y,w,h)
    local c=WINDOW_MANAGER:CreateControl(nil,book,CT_LABEL)
    c:SetFont(font);c:SetColor(.18,.105,.045,1);c:SetAnchor(TOPLEFT,book,TOPLEFT,x,y);c:SetDimensions(w,h);return c
end
local function button(text,x,y,w,callback)
    local c=WINDOW_MANAGER:CreateControl(nil,book,CT_BUTTON)
    c:SetFont('ZoFontGamepadBookPaper');c:SetText(text);c:SetAnchor(TOPLEFT,book,TOPLEFT,x,y);c:SetDimensions(w,42)
    c:SetNormalFontColor(.22,.12,.04,1);c:SetMouseOverFontColor(.55,.28,.08,1)
    c:SetMouseEnabled(true);c:SetHandler('OnClicked',callback);return c
end
local function iconButton(icon,tooltip,x,y,callback)
    local ui=B.ConversationUI
    local c
    if ui and type(ui.CreateIconButton)=='function' then
        c=ui.CreateIconButton(book,icon,tooltip,callback,44)
    else
        c=WINDOW_MANAGER:CreateControl(nil,book,CT_BUTTON)
        c:SetDimensions(44,44);c:SetMouseEnabled(true)
        c:SetNormalTexture('RolePlayMod/ui/conversation/'..icon..'.dds')
        c:SetHandler('OnClicked',callback)
    end
    c:ClearAnchors();c:SetAnchor(TOPLEFT,book,TOPLEFT,x,y)
    return c
end
local render
local function gamepadTargets()
    local targets={}
    for _,row in ipairs(rows or {}) do
        if row.item and not row:IsHidden() then
            local targetRow=row
            targets[#targets+1]={control=row,label=row.item.text,callback=function()
                local fn=type(targetRow.GetHandler)=='function' and targetRow:GetHandler('OnClicked') or targetRow.OnClicked
                if fn then return fn(targetRow) end
            end}
        end
    end
    if inquiryButton then targets[#targets+1]={control=inquiryButton,label='Journal d’enquête',callback=function() hideBook();oldNotebook() end} end
    if backButton then targets[#targets+1]={control=backButton,label='Retour',callback=function() T.GamepadBack() end} end
    if exitButton then targets[#targets+1]={control=exitButton,label='Quitter RolePlay Mod',callback=B.Close} end
    return targets
end
local function paintGamepadFocus()
    local targets=gamepadTargets()
    gamepadFocus=math.max(1,math.min(gamepadFocus,#targets))
    for i,target in ipairs(targets) do
        local c=target.control
        if not c.rpmBookFocusLines then
            c.rpmBookFocusLines={}
            for lineIndex=1,2 do
                local line=WINDOW_MANAGER:CreateControl(nil,c,CT_TEXTURE)
                line:SetTexture('RolePlayMod/ui/conversation/question-rule.dds');line:SetColor(.34,.18,.07,.9)
                line:SetMouseEnabled(false);line:SetDimensions(c:GetWidth(),1)
                line:SetAnchor(lineIndex==1 and TOPLEFT or BOTTOMLEFT,c,lineIndex==1 and TOPLEFT or BOTTOMLEFT,0,0)
                c.rpmBookFocusLines[lineIndex]=line
            end
        end
        for _,line in ipairs(c.rpmBookFocusLines) do line:SetHidden(not gamepadActive or i~=gamepadFocus) end
    end
    -- Rows disappearing after a page change must not retain a focus mark.
    for _,row in ipairs(rows or {}) do
        if not row.item and row.rpmBookFocusLines then for _,line in ipairs(row.rpmBookFocusLines) do line:SetHidden(true) end end
    end
end
function T.GamepadClearFocus()
    gamepadActive=false
    for _,target in ipairs(gamepadTargets()) do
        for _,line in ipairs(target.control.rpmBookFocusLines or {}) do line:SetHidden(true) end
    end
end
function T.GamepadMove(direction)
    if not T.IsOpen() then return false end
    gamepadActive=true
    if direction=='left' or direction=='right' then
        local old=listPage;listPage=math.max(1,math.min(listPageCount,listPage+(direction=='right' and 1 or -1)))
        if old~=listPage then gamepadFocus=1;render() else paintGamepadFocus() end
        return old~=listPage
    end
    local targets=gamepadTargets();if #targets==0 then return false end
    if direction=='up' or direction=='down' then
        gamepadFocus=(gamepadFocus-1+(direction=='down' and 1 or -1))%#targets+1
        paintGamepadFocus();return true
    end
    paintGamepadFocus();return false
end
function T.GamepadConfirm()
    if not T.IsOpen() then return false end
    gamepadActive=true;paintGamepadFocus()
    local target=gamepadTargets()[gamepadFocus]
    if not target then return false end
    target.callback();return true
end
function T.GamepadBack()
    if not T.IsOpen() then return false end
    if selected then selected=nil;textPage=1
    elseif city then city=nil;selected=nil;listPage=1
    elseif region then region=nil;selected=nil;listPage=1
    else
        hideBook()
        if B.npc and B.npc.travelOnly then B.Close() else B.ShowHome() end
        return true
    end
    gamepadFocus=1;render();return true
end
function T.GamepadPage(delta)
    if not T.IsOpen() then return false end
    delta=delta and delta<0 and -1 or 1
    gamepadActive=true
    if selected and textPageCount>1 then
        local old=textPage;textPage=math.max(1,math.min(textPageCount,textPage+delta));render();return old~=textPage
    end
    return T.GamepadMove(delta>0 and 'right' or 'left')
end
function T.GamepadLabel()
    local target=T.IsOpen() and gamepadTargets()[gamepadFocus]
    return target and target.label or 'Carnet de voyage'
end
function T.GetGamepadContext()
    if not T.IsOpen() then return end
    return {kind='book',root=book,items=gamepadTargets,back=T.GamepadBack,page=T.GamepadPage,
        move=T.GamepadMove,confirm=T.GamepadConfirm,clear=T.GamepadClearFocus,label=T.GamepadLabel}
end
local function create()
    if book then return end
    book=WINDOW_MANAGER:CreateTopLevelWindow('IHRTravelJournal');book:SetDimensions(BOOK_SIZE,BOOK_SIZE)
    book:SetAnchor(CENTER,GuiRoot,CENTER,0,0);book:SetMovable(true);book:SetMouseEnabled(true);book:SetClampedToScreen(true);book:SetHidden(true)
    book:SetKeyboardEnabled(not (B.Native and B.Native.IsGamepadMode()))
    book:SetHandler('OnKeyDown',function(_,key) if key==KEY_ESCAPE then B.Close() end end)
    book:SetHandler('OnMoveStop',T.SavePosition)
    book:SetHandler('OnHide',function() B.travelJournalVisible=false end)
    local bg=WINDOW_MANAGER:CreateControl(nil,book,CT_TEXTURE);bg:SetAnchorFill();bg:SetTexture('EsoUI/Art/LoreLibrary/loreLibrary_paperBook.dds')
    heading=label('ZoFontGamepadBookPaperTitle',100,175,365,65);heading:SetText('Carnet de voyage')
    regionLabel=label('ZoFontGamepadBookPaper',100,242,365,55)
    rows={}
    for i=1,7 do local index=i;rows[i]=button('',100,300+(i-1)*57,365,function()
        local item=rows[index].item;if not item then return end
        if item.region then region=item.region;city=nil;selected=nil
        elseif item.city then city=item.city;selected=nil
        else selected=item.entry;textPage=1 end
        listPage=1;render()
    end)
        local mark=WINDOW_MANAGER:CreateControl(nil,rows[i],CT_BACKDROP);mark:SetAnchor(TOPLEFT,rows[i],TOPLEFT,0,22);mark:SetDimensions(340,2);mark:SetCenterColor(.32,.18,.08,.85);mark:SetEdgeColor(0,0,0,0);mark:SetHidden(true);rows[i].crossed=mark
    end
    button('← Classement',100,735,175,function()
        if city then city=nil;selected=nil elseif region then region=nil;selected=nil end
        listPage=1;render()
    end)
    button('←',280,735,70,function() listPage=math.max(1,listPage-1);render() end)
    button('→',360,735,70,function() listPage=listPage+1;render() end)
    entryTitle=label('ZoFontGamepadBookPaperTitle',550,175,370,80)
    strike=WINDOW_MANAGER:CreateControl(nil,book,CT_BACKDROP);strike:SetAnchor(TOPLEFT,entryTitle,TOPLEFT,0,22);strike:SetDimensions(360,2)
    strike:SetCenterColor(.32,.18,.08,.85);strike:SetEdgeColor(0,0,0,0)
    entryStatus=label('ZoFontGamepadBookPaper',550,260,370,50)
    entryText=label('ZoFontGamepadBookPaper',550,318,370,365)
    sourceLabel=label('ZoFontGamepadBookPaper',550,687,370,62)
    previous=button('←',550,756,70,function() textPage=math.max(1,textPage-1);render() end)
    pageLabel=label('ZoFontGamepadBookPaper',630,766,200,35)
    nextPage=button('→',845,756,70,function() textPage=textPage+1;render() end)
    inquiryButton=button('Journal d’enquête',165,805,300,function() hideBook();oldNotebook() end)
    backButton=iconButton('back','Revenir à la conversation',100,805,function()
        hideBook()
        if B.npc and B.npc.travelOnly then B.Close() else B.ShowHome() end
    end)
    exitButton=iconButton('exit','Quitter RolePlay Mod',876,805,function() B.Close() end)
end
render=function()
    T.Refresh();local groups=T.Groups();local items={}
    if not region then for _,r in ipairs(sorted(groups)) do items[#items+1]={region=r,text=r} end
    elseif not city then for _,c in ipairs(sorted(groups[region] or {})) do items[#items+1]={city=c,text=c} end
    else
        for _,e in pairs(data().entries) do if e.region==region and e.city==city then items[#items+1]={entry=e,text=(e.started and '✓ ' or '• ')..e.giver} end end
        table.sort(items,function(a,b) return a.entry.time<b.entry.time or a.entry.time==b.entry.time and a.entry.quest<b.entry.quest end)
    end
    listPageCount=math.max(1,math.ceil(#items/7));listPage=math.min(math.max(1,listPage),listPageCount)
    regionLabel:SetText((region or 'Choisissez une région')..(city and ('\n'..city) or ''))
    for i,row in ipairs(rows) do
        local item=items[(listPage-1)*7+i];row.item=item;row:SetText(item and item.text or '');row:SetHidden(not item);row.crossed:SetHidden(not (item and item.entry and item.entry.started))
    end
    local e=selected
    entryTitle:SetText(e and e.giver or 'Les nouvelles de la route')
    entryStatus:SetText(e and (e.completed and 'Quête terminée — piste suivie' or e.started and 'Quête commencée — piste suivie' or 'Une piste à explorer') or '')
    strike:SetHidden(not (e and e.started))
    local pages=T.Pages(e and e.text or (#items==0 and 'Aucune rumeur notée ici.\n\nÉcoutez les aubergistes, les brasseurs et les voyageurs : les pistes obtenues sont notées automatiquement. Vous pourrez ensuite demander aux habitants où trouver les personnes mentionnées.' or 'Les pistes sont classées par région, puis par ville.\n\nChoisissez une entrée sur la page de gauche. Les pistes barrées correspondent à des quêtes déjà commencées.'))
    textPageCount=#pages;textPage=math.min(math.max(1,textPage),textPageCount);entryText:SetText(pages[textPage])
    sourceLabel:SetText(e and ('Entendu auprès de '..e.speaker..'\n'..e.city..' · '..e.region) or '')
    pageLabel:SetText(textPage..' / '..#pages);previous:SetHidden(textPage<=1);nextPage:SetHidden(textPage>=#pages)
    paintGamepadFocus()
    backButton:SetHidden(gamepadActive);exitButton:SetHidden(gamepadActive)
end
function T.Open()
    if not B.saved then return end
    if not B.npc then
        local zone,x,y,z=GetUnitWorldPosition('player')
        B.npc={name='Mon carnet',zoneIndex=GetUnitZoneIndex('player'),zoneId=zone,x=x,y=y,z=z,locality='',travelOnly=true}
        B.ownsCursor=not IsGameCameraUIModeActive();SetGameCameraUIMode(true)
    end
    local frame=B.ShowCustomContent('Carnet de voyage',650);frame:SetHidden(true)
    create();T.Layout()
    gamepadActive=B.Native.IsGamepadMode();gamepadFocus=1
    B.travelJournalVisible=true;book:SetHidden(false);render()
end
function T.ShowNoted(r,text,npc)
    T.Note(r,text,npc)
    B.Show('Carnet de voyage','C’est noté dans votre carnet.\n\n'..text,{
        {text='Autre chose ?',callback=function() B.ShowQuestRumors(true) end},
        {text='Ouvrir mon carnet de voyage.',callback=T.Open},
        {text='Merci pour ces renseignements.',callback=function() B.ShowHome() end},
    },true)
end
B.ShowNotebook=T.Open
local show,close,isOpen=B.Show,B.Close,B.IsOpen
function B.Show(...) hideBook();return show(...) end
function B.Close(...) hideBook();return close(...) end
function B.IsOpen() return T.IsOpen() or isOpen() end
if SLASH_COMMANDS then SLASH_COMMANDS['/carnet']=T.Open;SLASH_COMMANDS['/ihrvoyage']=T.Open end
if EVENT_MANAGER then
    for _,event in ipairs({EVENT_QUEST_ADDED,EVENT_QUEST_REMOVED,EVENT_PLAYER_ACTIVATED}) do
        if event then EVENT_MANAGER:RegisterForEvent('IHRTravelJournal'..event,event,function() T.Refresh();if book and not book:IsHidden() then render() end end) end
    end
    local function resize()
        if not T.IsOpen() then return end
        T.Layout()
        -- The native UI can apply its new scale at the end of this frame.
        if type(zo_callLater)=='function' then zo_callLater(function() if T.IsOpen() then T.Layout() end end,0) end
    end
    if EVENT_SCREEN_RESIZED then EVENT_MANAGER:RegisterForEvent('IHRTravelJournalResize',EVENT_SCREEN_RESIZED,resize) end
    if EVENT_INTERFACE_SETTING_CHANGED then
        EVENT_MANAGER:RegisterForEvent('IHRTravelJournalScale',EVENT_INTERFACE_SETTING_CHANGED,function(_,settingType)
            if not SETTING_TYPE_UI or settingType==SETTING_TYPE_UI then resize() end
        end)
    end
end
