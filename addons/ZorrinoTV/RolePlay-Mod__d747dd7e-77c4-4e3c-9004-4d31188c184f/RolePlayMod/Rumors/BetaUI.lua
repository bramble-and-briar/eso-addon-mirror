if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Shared conversation presentation. Quest/social decisions remain in their own modules.
local B = IHR_Runtime.Beta
local A = IHR_Runtime.Base
local U = {}; B.ConversationUI = U
local rows, frame, titleLabel, subtitle, bodyLabel, pageLabel, textPageLabel
local prevPage, nextPage, prevText, nextText, measureLabel, background
local scrim, shadeTexture, separator
local current, page, textPage = nil, 1, 1
local session = 0
local WIDTH, PADDING = 640, 18
local footer = {}
local wheelDrag
local choiceViewport,gamepadList
local LIST_UPDATE='RPMGamepadChoiceList'

local function control(kind,parent) return WINDOW_MANAGER:CreateControl(nil,parent,kind) end
local function at(c,x,y,parent)
    parent=parent or frame;c:ClearAnchors();c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y)
end
local function label(parent,font,x,y,width,height)
    local c=control(CT_LABEL,parent);c:SetFont(font);c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);c:SetDimensions(width,height)
    c:SetMouseEnabled(false);return c
end
local function button(parent,text,x,y,width,height,callback)
    local c=control(CT_BUTTON,parent)
    c:SetFont('ZoFontGamepad22');c:SetText(text);c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);c:SetDimensions(width,height)
    c:SetNormalFontColor(.88,.81,.63,1);c:SetMouseOverFontColor(1,.96,.82,1)
    c:SetMouseEnabled(true);c:SetClickSound('Click');c:SetHandler('OnClicked',callback)
    return c
end
function U.CreateIconButton(parent,icon,tooltip,callback,size)
    local c=control(CT_BUTTON,parent);c:SetDimensions(size or 36,size or 36);c:SetMouseEnabled(true);c:SetClickSound('Click')
    local tex=control(CT_TEXTURE,c);tex:SetAnchorFill();tex:SetTexture('RolePlayMod/ui/conversation/'..icon..'.dds');tex:SetMouseEnabled(false)
    tex:SetColor(.82,.77,.65,1);c.rpmIcon=tex;c.rpmIconName=icon;c.rpmTooltip=tooltip
    c:SetHandler('OnMouseEnter',function()
        tex:SetColor(1,1,.94,1)
        if type(InitializeTooltip)=='function' and type(SetTooltipText)=='function' and InformationTooltip then
            InitializeTooltip(InformationTooltip,c,TOPLEFT,0,-8,BOTTOMLEFT);SetTooltipText(InformationTooltip,c.rpmTooltip or tooltip)
        end
    end)
    c:SetHandler('OnMouseExit',function()
        tex:SetColor(.82,.77,.65,1)
        if type(ClearTooltip)=='function' and InformationTooltip then ClearTooltip(InformationTooltip) end
    end)
    c:SetHandler('OnClicked',function()
        if type(ClearTooltip)=='function' and InformationTooltip then ClearTooltip(InformationTooltip) end
        if callback then callback() end
    end)
    return c
end
local function TextHeight(text)
    measureLabel:SetText(text or '');return measureLabel:GetTextHeight()
end
local function chunks(text,limit)
    local result={};text=text or '';limit=limit or 190
    while #text>720 or TextHeight(text)>limit do
        local cut
        for pos in text:sub(1,720):gmatch('()[ \t\r\n]') do cut=pos end
        cut=cut or math.min(720,#text)
        while TextHeight(text:sub(1,cut))>limit and cut>1 do
            local previous
            for pos in text:sub(1,cut-1):gmatch('()[ \t\r\n]') do previous=pos end
            cut=previous or math.max(1,cut-8)
        end
        while cut>1 and text:byte(cut+1) and text:byte(cut+1)>=128 and text:byte(cut+1)<192 do cut=cut-1 end
        result[#result+1]=text:sub(1,cut);text=text:sub(cut+1)
    end
    result[#result+1]=text;return result
end
function B.NpcRaceText(npc)
    local race=npc and npc.race
    if type(race)~='string' then return 'Race : non renseignée' end
    race=B.Name(race):gsub('^[ \t\r\n]+',''):gsub('[ \t\r\n]+$','')
    if race=='' then return 'Race : non renseignée' end
    return 'Race : '..race..(npc.raceSource=='catalogue' and ' (répertoire)' or '')
end
function B.IsOpen() return frame and not frame:IsHidden() end
function B.Close()
    if B.SocialWheel then B.SocialWheel.Hide() end
    if not frame then return end
    EVENT_MANAGER:UnregisterForUpdate(LIST_UPDATE);gamepadList=nil
    frame:SetHidden(true);B.nativeSession=false
    if scrim then scrim:SetHidden(true) end
    if B.Native then B.Native.Restore() end
    if B.ownsCursor then SetGameCameraUIMode(false) end
    B.ownsCursor=false;B.npc=nil;current=nil;session=session+1
    if type(ClearTooltip)=='function' and InformationTooltip then ClearTooltip(InformationTooltip) end
end

-- All coordinates are GUI units, so the native UI scale is respected too.
function U.LayoutMetrics(screenWidth,screenHeight,width,height)
    local w,h=math.max(1,screenWidth),math.max(1,screenHeight)
    local safe=math.min(w,h*16/9);local left=(w-safe)/2
    local fraction=w/h<1.5 and .48 or .40
    local availableWidth=safe*fraction;local availableHeight=h*.80
    -- GUI units already account for the player's interface scale. Never
    -- magnify a conversation just because the display has more pixels.
    local scale=math.min(1,availableWidth/width,availableHeight/height)
    local right=left+safe*.96
    return {x=math.max(0,right-width*scale),y=math.max(h*.06,(h-height*scale)/2),scale=scale,width=width*scale,height=height*scale,safeLeft=left,safeWidth=safe}
end
local function isWheel()
    return current and current.custom and current.kind=='speechcraft'
end
local function wheelMode() return current and current.nativeLayout and 'interactive' or 'free' end
local function controlDown() return type(IsControlKeyDown)=='function' and IsControlKeyDown() end
local function wheelMoveEnabled() return not RolePlayMod or RolePlayMod.Options().wheelMoveWithCtrl~=false end
function U.IsWheelDragging() return wheelDrag~=nil end
function U.EndWheelDrag()
    if not wheelDrag then return end
    local context=wheelDrag;wheelDrag=nil -- StopMoving can synchronously fire OnMoveStop.
    frame:StopMovingOrResizing();frame:SetMovable(false)
    if B.saved then
        local w,h=GuiRoot:GetWidth(),GuiRoot:GetHeight()
        local scale=GuiRoot:GetScale();if not scale or scale<=0 then scale=1 end
        if w>0 and h>0 then
            B.saved.wheelPositions=B.saved.wheelPositions or {}
            B.saved.wheelPositions[context.mode]={x=(frame:GetLeft()-GuiRoot:GetLeft())/(w*scale),y=(frame:GetTop()-GuiRoot:GetTop())/(h*scale)}
        end
    end
    if U.Relayout then U.Relayout() end
    local wheel=RolePlayMod and RolePlayMod.Speechcraft and RolePlayMod.Speechcraft.Wheel
    if wheel and wheel.ResumeAfterDrag then wheel.ResumeAfterDrag() end
end
function U.BeginWheelDrag(owner,button,ctrl)
    if button~=(MOUSE_BUTTON_INDEX_LEFT or 1) or not isWheel() or not wheelMoveEnabled() or not B.IsOpen() then return false end
    if ctrl==nil then ctrl=controlDown() end
    if not ctrl then return false end
    owner.rpmWheelDragConsumed=true
    if wheelDrag then return true end
    frame:SetMovable(true)
    if frame:StartMoving()==false then frame:SetMovable(false);return true end
    wheelDrag={mode=wheelMode()}
    if RolePlayMod and RolePlayMod.Speechcraft then RolePlayMod.Speechcraft.Ready(false) end
    return true
end
function U.BindWheelDrag(c,callback)
    c:SetHandler('OnMouseDown',function(_,button,ctrl)
        c.rpmWheelDragConsumed=false
        U.BeginWheelDrag(c,button,ctrl)
    end)
    c:SetHandler('OnMouseUp',function(_,button)
        if button==(MOUSE_BUTTON_INDEX_LEFT or 1) then U.EndWheelDrag() end
    end)
    if callback then
        c:SetHandler('OnClicked',function(...)
            -- Keep the latch after mouse-up, including when Ctrl was released
            -- first: moving a sector must never also play that approach.
            if c.rpmWheelDragConsumed or (isWheel() and wheelMoveEnabled() and controlDown()) then return end
            if type(ClearTooltip)=='function' and InformationTooltip then ClearTooltip(InformationTooltip) end
            return callback(...)
        end)
    end
end
function B.ResetWheelPosition()
    U.EndWheelDrag()
    if B.saved then B.saved.wheelPositions=nil end
    if U.Relayout then U.Relayout() end
end
function B.SaveDialoguePosition()
    if not frame or not B.saved then return end
    if isWheel() then return end -- Wheel placement has separate saved positions.
    if B.nativeSession then return end -- The game's dialogue owns this position.
    local w,h=GuiRoot:GetWidth(),GuiRoot:GetHeight()
    if w<=0 or h<=0 then return end
    local rx=type(GuiRoot.GetLeft)=='function' and GuiRoot:GetLeft() or 0
    local ry=type(GuiRoot.GetTop)=='function' and GuiRoot:GetTop() or 0
    B.saved.dialoguePosition={x=(frame:GetLeft()-rx)/w,y=(frame:GetTop()-ry)/h}
    if U.Relayout then U.Relayout() end
end
function B.ResetPosition()
    if B.saved then B.saved.dialoguePosition=nil end
    if U.Relayout then U.Relayout() end
end
local function position(height,width)
    local w,h=GuiRoot:GetWidth(),GuiRoot:GetHeight();local layout=U.LayoutMetrics(w,h,width,height)
    local native=current and current.nativeLayout
    if native then
        local nativeScale=native.scale or 1
        local availableHeight=current.custom and math.max(1,h-24) or math.max(1,h-native.y-20)
        local scale=math.min(nativeScale,native.width*nativeScale/width,availableHeight/height)
        layout={x=native.x,y=native.y,scale=scale,width=width*scale,height=height*scale,native=true}
        if not current.custom and native.gamepadLayout then
            -- The two native dialogue areas share one scale, but not one flow.
            layout.x=native.x;layout.y=native.gamepadLayout.bodyTop
            layout.scale=nativeScale;layout.width=width*nativeScale;layout.height=height*nativeScale
        end
        if current.custom then
            local area=native.dialogueArea
            if area and area.width>0 and area.height>0 then
                -- A short native greeting shrinks its resize-to-fit areas. Use
                -- those bounds for the centre, never as a wheel size limit.
                -- Only the column width and viewport constrain a custom panel.
                scale=math.min(1,nativeScale,area.width/width,(w-24)/width,(h-24)/height)
                layout.scale=scale;layout.width=width*scale;layout.height=height*scale
                layout.x=area.centerX-layout.width/2;layout.y=area.centerY-layout.height/2
            else
                layout.x=native.x+math.max(0,(native.width*nativeScale-layout.width)/2)
                layout.y=(h-layout.height)/2
            end
            if current.kind=='speechcraft' and native.wheelAnchor then
                layout.x=native.wheelAnchor.x
                layout.y=native.wheelAnchor.centerY-layout.height/2
            end
            layout.x=math.max(12,math.min(layout.x,w-layout.width-12))
            layout.y=math.max(12,math.min(layout.y,h-layout.height-12))
        end
        frame:SetMovable(false)
    else frame:SetMovable(true) end
    local wheel=isWheel()
    if wheel then frame:SetMovable(false) end
    local pos=wheel and B.saved and B.saved.wheelPositions and B.saved.wheelPositions[wheelMode()] or not native and B.saved and B.saved.dialoguePosition
    if type(pos)=='table' and type(pos.x)=='number' and pos.x==pos.x and math.abs(pos.x)<math.huge and type(pos.y)=='number' and pos.y==pos.y and math.abs(pos.y)<math.huge then
        layout.x=math.max(0,math.min(pos.x*w,math.max(0,w-layout.width)))
        layout.y=math.max(0,math.min(pos.y*h,math.max(0,h-layout.height)))
    end
    frame:SetDimensions(width,height);frame:SetScale(layout.scale);at(frame,layout.x,layout.y,GuiRoot)
    if scrim then
        -- Interactive NPCs keep the game's own background. Other inhabitants
        -- receive the same kind of local, softly faded dialogue backdrop.
        local bgx,bgy=math.max(0,layout.x-70),math.max(0,layout.y-55)
        local bgw=math.min(w-bgx,layout.width+140)
        local bgh=math.min(h-bgy,math.max(320,layout.height+110))
        scrim:ClearAnchors();scrim:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,bgx,bgy);scrim:SetDimensions(bgw,bgh)
        separator:ClearAnchors();separator:SetAnchor(TOPLEFT,scrim,TOPLEFT,math.max(0,layout.x-bgx-12),0);separator:SetDimensions(1,bgh)
        scrim:SetHidden(not not native)
    end
    U.layout=layout
end
local Render
local function openRoute(route)
    if route.kind=='home' then return B.ShowHome() end
    if route.kind=='quests' then return B.ShowQuests() end
    if route.kind=='travelQuestions' then return B.TravelJournal.ShowInquiries() end
    if route.kind=='services' then return B.ShowServices() end
    if route.kind=='quest' then
        local quest=B.ReadQuest(route.index)
        if quest and quest.key==route.key then return B.ShowQuest(quest) end
        return B.ShowQuests()
    end
    return B.ShowHome()
end
local function returnToParent()
    if not current then return end
    -- This is a menu hierarchy, not browser history. Answers and follow-ups
    -- share their owner's menu; going up must never push the answer back down.
    if current.parentRoute then return openRoute(current.parentRoute) end
    if current.back then return current.back() end
    return B.ShowHome()
end
U.Back=returnToParent
function U.SetRoute(route)
    if not current then return end
    current.route=route
    if route.kind=='home' then current.parentRoute=nil
    elseif route.kind=='quest' then current.parentRoute={kind='quests'}
    else current.parentRoute={kind='home'} end
end
local function createWindow()
    if frame then return end
    frame=WINDOW_MANAGER:CreateTopLevelWindow('IHRBetaConversation')
    frame:SetDimensions(WIDTH,400);frame:SetHidden(true);frame:SetMouseEnabled(true);frame:SetMovable(true);frame:SetClampedToScreen(true)
    if frame.SetDrawTier and DT_HIGH then frame:SetDrawTier(DT_HIGH) end
    frame:SetHandler('OnMoveStop',function() if wheelDrag then U.EndWheelDrag() else B.SaveDialoguePosition() end end)
    U.BindWheelDrag(frame)
    scrim=WINDOW_MANAGER:CreateTopLevelWindow('RPMConversationShade');scrim:SetHidden(true);scrim:SetMouseEnabled(false)
    if scrim.SetDrawTier and DT_MEDIUM then scrim:SetDrawTier(DT_MEDIUM) end
    shadeTexture=control(CT_TEXTURE,scrim);shadeTexture:SetAnchorFill();shadeTexture:SetTexture('RolePlayMod/ui/conversation/dialogue-background.dds');shadeTexture:SetMouseEnabled(false)
    separator=control(CT_TEXTURE,scrim);separator:SetTexture('RolePlayMod/ui/conversation/dialogue-separator.dds');separator:SetColor(.86,.81,.64,.8);separator:SetMouseEnabled(false)
    frame:SetHandler('OnHide',function() U.EndWheelDrag();scrim:SetHidden(true) end)
    background=control(CT_BACKDROP,frame);background:SetAnchorFill();background:SetCenterColor(.012,.01,.008,.48);background:SetEdgeColor(0,0,0,0)
    titleLabel=label(frame,'ZoFontGamepadBold27',PADDING,0,WIDTH-2*PADDING,32);titleLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    subtitle=label(frame,'ZoFontGamepad18',PADDING,36,WIDTH-2*PADDING,24);subtitle:SetColor(.8,.75,.63,1)
    bodyLabel=label(frame,'ZoFontGamepad22',PADDING,42,WIDTH-2*PADDING,0);bodyLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)
    measureLabel=control(CT_LABEL,frame);measureLabel:SetWidth(WIDTH-2*PADDING);measureLabel:SetHeight(0);measureLabel:SetHidden(true)
    choiceViewport=control(CT_SCROLL,frame);choiceViewport:SetHidden(true);choiceViewport:SetMouseEnabled(false)
    rows={}
    for i=1,5 do
        local row=button(frame,'',PADDING,0,WIDTH-2*PADDING,40,function() end)
        row.choiceLabel=label(row,'ZoFontGamepad22',0,0,WIDTH-2*PADDING,0)
        row.choiceLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER);row.choiceLabel:SetColor(.88,.81,.63,1)
        row.hoverLines={}
        for lineIndex=1,2 do
            local line=control(CT_TEXTURE,row)
            line:SetTexture('RolePlayMod/ui/conversation/question-rule.dds')
            line:SetDimensions(WIDTH-2*PADDING,1);line:SetColor(.9,.88,.8,.75)
            line:SetMouseEnabled(false);line:SetHidden(true);row.hoverLines[lineIndex]=line
        end
        row:SetHandler('OnMouseEnter',function()
            if B.Native and B.Native.IsGamepadMode() then return end
            for _,line in ipairs(row.hoverLines) do line:SetHidden(false) end
        end)
        row:SetHandler('OnMouseExit',function() for _,line in ipairs(row.hoverLines) do line:SetHidden(true) end end)
        rows[i]=row
    end
    prevPage=button(frame,'Questions précédentes',66,0,205,34,function() page=math.max(1,page-1);Render() end)
    nextPage=button(frame,'Autres questions',WIDTH-225,0,207,34,function() page=page+1;Render() end)
    pageLabel=label(frame,'ZoFontGamepad18',270,0,100,28);pageLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    prevText=button(frame,'Texte précédent',PADDING,0,200,32,function() textPage=math.max(1,textPage-1);Render() end)
    nextText=button(frame,'Lire la suite',WIDTH-218,0,200,32,function() textPage=textPage+1;Render() end)
    textPageLabel=label(frame,'ZoFontGamepad18',270,0,100,26);textPageLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    footer.back=U.CreateIconButton(frame,'back','Retour',returnToParent,36)
    footer.exit=U.CreateIconButton(frame,'exit','Quitter RolePlay Mod',B.Close,36)
    footer.journal=U.CreateIconButton(frame,'journal','Carnet de voyage',function() if current and current.journal then current.journal() end end,36)
    footer.persuasion=U.CreateIconButton(frame,'persuasion','Persuasion',function() if current and current.persuasion then current.persuasion() end end,36)
    if frame.SetKeyboardEnabled then
        frame:SetKeyboardEnabled(not (B.Native and B.Native.IsGamepadMode()))
        frame:SetHandler('OnKeyDown',function(_,key) if key==KEY_ESCAPE then B.Close() end end)
    end
    U.Controls={frame=frame,title=titleLabel,body=bodyLabel,rows=rows,footer=footer,page=pageLabel,nextPage=nextPage,prevPage=prevPage,nextText=nextText,prevText=prevText,subtitle=subtitle,background=background,scrim=scrim,separator=separator,choiceViewport=choiceViewport}
end

-- Exact UI actions become icons; actual questions and answers are never rewritten here.
local journalActions={['(Consulter mon carnet.)']=true,['(Consulter mon carnet de voyage.)']=true,['Ouvrir mon carnet de voyage.']=true}
local persuasionActions={['Prenons un moment pour parler.']=true,['Prenons le temps de discuter.']=true,['Terminons notre conversation.']=true}
local returnActions={
    ['Je cherche aussi autre chose.']=true,['Parler d’une autre quête.']=true,['Revenir à la conversation.']=true,
    ['Revenir au carnet.']=true,['Revenir à mon carnet.']=true,['Revenir à ma question.']=true,
    ['Revenir aux questions de cette quête.']=true,['Revenir aux questions sur cette quête.']=true,
    ['Revenir aux questions.']=true,
    ['Je vais demander ailleurs.']=true,['Une autre fois.']=true,['Très bien. Je vous laisse.']=true,
}
local function prepare(title,choices)
    local result={choices={},isHome=title=='Conversation',isQuestList=title=='Mes quêtes',gamepadMode=B.Native and B.Native.IsGamepadMode() or false}
    for _,item in ipairs(choices or {}) do
        if item.uiRole=='journal' or journalActions[item.text] then result.journal=item.callback
        elseif item.uiRole=='persuasion' or persuasionActions[item.text] then
            -- At home, persuasion is offered when an actual question is refused.
            if not result.isHome then result.persuasion=item.callback end
        elseif item.uiRole=='back' or returnActions[item.text] then result.back=item.callback
        else result.choices[#result.choices+1]=item end
    end
    if result.gamepadMode and result.persuasion then
        table.insert(result.choices,1,{text='Persuasion',callback=result.persuasion})
    end
    if result.gamepadMode and result.journal then
        result.choices[#result.choices+1]={text='Consulter mon carnet de voyage.',callback=result.journal};result.journal=nil
    end
    result.choiceLimit=result.isQuestList and 3 or 5
    return result
end
local function presentation(view)
    -- A keyboard-enabled top level takes key events before action bindings.
    -- The controller uses ESO's binding layers; never capture its face/Dpad
    -- keys in the Escape-only keyboard handler.
    if frame and frame.SetKeyboardEnabled then frame:SetKeyboardEnabled(not (B.Native and B.Native.IsGamepadMode())) end
    local metrics=B.Native and B.Native.LayoutMetrics and B.Native.LayoutMetrics(true) or nil
    local native=B.nativeSession and metrics or nil
    view.nativeLayout=native
    local width=view.custom and (view.width or WIDTH) or native and native.width or WIDTH
    local pad=native and 0 or PADDING
    local bodyFont=view.notes and 'ZoFontGamepadBookPaper' or metrics and metrics.bodyFont or 'ZoFontGamepad22'
    local optionFont=metrics and metrics.optionFont or 'ZoFontGamepad22'
    titleLabel:SetFont(metrics and metrics.nameFont or 'ZoFontGamepadBold27')
    titleLabel:SetHidden(native~=nil and native.title~=nil and (native.gamepad or not view.custom))
    if B.Native and B.Native.UseCustomTitle then B.Native.UseCustomTitle(native~=nil and not native.gamepad and not not view.custom) end
    if B.Native and B.Native.UseWheelPresentation then
        B.Native.UseWheelPresentation(native~=nil and native.gamepad and view.custom and view.kind=='speechcraft')
    end
    bodyLabel:SetFont(bodyFont);measureLabel:SetFont(bodyFont);measureLabel:SetWidth(width-2*pad)
    for _,row in ipairs(rows) do row.choiceLabel:SetFont(optionFont) end
    for _,c in ipairs({prevPage,nextPage,prevText,nextText}) do c:SetFont(optionFont) end
    return width,pad,bodyFont
end
local function placeGamepadChoices(offset)
    if not gamepadList then return end
    gamepadList.offset=offset
    for _,row in ipairs(rows) do
        if row.rpmChoice then at(row,0,(row.rpmListY or 0)+offset,choiceViewport) end
    end
end
function U.GamepadSelect(selected)
    if not (B.Native and B.Native.IsGamepadMode()) then return end
    for _,row in ipairs(rows or {}) do
        row.choiceLabel:SetColor(row==selected and 1 or .58,row==selected and 1 or .58,row==selected and 1 or .58,1)
        for _,line in ipairs(row.hoverLines) do line:SetHidden(true) end
    end
    if not gamepadList or not selected or not selected.rpmChoice then return end
    local target=gamepadList.center-(selected.rpmListY or 0)-selected:GetHeight()/2
    if gamepadList.selected==selected and gamepadList.target==target then return end
    local first=gamepadList.selected==nil
    gamepadList.selected=selected;gamepadList.target=target
    EVENT_MANAGER:UnregisterForUpdate(LIST_UPDATE)
    if first then placeGamepadChoices(target);return end
    local from=gamepadList.offset or target;local start=GetFrameTimeMilliseconds();local owner=gamepadList
    EVENT_MANAGER:RegisterForUpdate(LIST_UPDATE,16,function()
        if gamepadList~=owner or not B.IsOpen() then EVENT_MANAGER:UnregisterForUpdate(LIST_UPDATE);return end
        local t=math.min(1,math.max(0,(GetFrameTimeMilliseconds()-start)/160))
        local eased=1-(1-t)*(1-t)*(1-t)
        placeGamepadChoices(from+(target-from)*eased)
        if t>=1 then EVENT_MANAGER:UnregisterForUpdate(LIST_UPDATE) end
    end)
end
Render=function()
    if not current or not B.npc then return end
    local gamepad=B.Native and B.Native.IsGamepadMode() or false
    if current.gamepadMode~=gamepad then
        local prepared=prepare(current.title,current.rawChoices)
        current.choices=prepared.choices;current.journal=prepared.journal;current.persuasion=prepared.persuasion;current.back=prepared.back
        current.choiceLimit=prepared.choiceLimit;current.gamepadMode=gamepad
    end
    local width,pad,font=presentation(current);local native=current.nativeLayout;local inner=width-2*pad
    local gpLayout=not current.custom and gamepad and native and native.gamepadLayout
    local textLimit=gpLayout and (gpLayout.bodyBottom-gpLayout.bodyTop)/(native.scale or 1)-40 or (current.notes and 240 or 190)
    textLimit=math.max(60,textLimit)
    if current.textWidth~=inner or current.bodyFont~=font or current.textLimit~=textLimit then
        current.texts=chunks(current.sourceText,textLimit)
        current.textWidth=inner;current.bodyFont=font;current.textLimit=textLimit
    end
    textPage=math.max(1,math.min(textPage,#current.texts))
    titleLabel:SetWidth(inner);at(titleLabel,pad,0)
    titleLabel:SetText(current.notes and 'Mes notes' or B.npc.clientName or B.npc.name)
    subtitle:SetWidth(inner);subtitle:SetText(current.title or '');subtitle:SetHidden(not current.notes);at(subtitle,pad,native and 0 or 36)
    local y=native and (current.notes and 32 or (not native.title and 44 or 0)) or (current.notes and 72 or 44)
    bodyLabel:SetWidth(inner);measureLabel:SetWidth(inner);bodyLabel:SetHeight(0);bodyLabel:SetText(current.texts[textPage] or '');bodyLabel:SetHidden(current.custom)
    if gpLayout then y=math.max(current.notes and 32 or 0,(gpLayout.bodyBottom-gpLayout.bodyTop)/(native.scale or 1)-TextHeight(current.texts[textPage])) end
    at(bodyLabel,pad,y)
    if not current.custom then y=y+math.max(28,TextHeight(current.texts[textPage]))+14 end
    local limit=current.choiceLimit;local pages=math.max(1,math.ceil(#current.choices/limit))
    page=math.max(1,math.min(page,pages));textPage=math.max(1,math.min(textPage,#current.texts))
    for _,c in ipairs({prevText,nextText,textPageLabel}) do c:SetHidden(current.custom or #current.texts<=1) end
    if not current.custom and #current.texts>1 then
        prevText:SetHidden(textPage<=1);nextText:SetHidden(textPage>=#current.texts)
        local textNavigationY=gpLayout and 0 or y
        at(prevText,pad,textNavigationY);at(nextText,width-218,textNavigationY);at(textPageLabel,(width-100)/2,textNavigationY+4)
        textPageLabel:SetText(textPage..' / '..#current.texts);y=y+40
    end
    local previousList=gamepadList
    EVENT_MANAGER:UnregisterForUpdate(LIST_UPDATE);gamepadList=nil
    choiceViewport:SetHidden(not gpLayout)
    if gpLayout then
        local scale=native.scale or 1
        local top=(gpLayout.dividerBottom-gpLayout.bodyTop)/scale+12
        local height=math.max(80,(gpLayout.bottom-gpLayout.bodyTop)/scale-top)
        at(choiceViewport,pad,top);choiceViewport:SetDimensions(inner,height)
        gamepadList={view=current,page=page,center=(gpLayout.choiceCenterY-gpLayout.bodyTop)/scale-top}
        if previousList and previousList.view==current and previousList.page==page then gamepadList.offset=previousList.offset;gamepadList.selected=previousList.selected end
        y=0
    end
    for i,row in ipairs(rows) do
        local item=not current.custom and i<=limit and current.choices[(page-1)*limit+i] or nil
        row:SetHidden(not item);for _,line in ipairs(row.hoverLines) do line:SetHidden(true) end
        row:SetParent(gpLayout and choiceViewport or frame)
        if item then
            row.choiceLabel:SetWidth(inner);row.choiceLabel:SetHeight(0);row.choiceLabel:SetText(item.text)
            local th=row.choiceLabel:GetTextHeight();local height=math.max(native and 26 or 32,th+(gamepad and 16 or native and 4 or 8))
            row:SetDimensions(inner,height);at(row,pad,y);at(row.choiceLabel,0,(height-th)/2,row)
            for lineIndex,line in ipairs(row.hoverLines) do line:SetDimensions(inner,1);at(line,0,lineIndex==1 and 0 or height-1,row) end
            row.rpmChoice=item;row.rpmListY=y
            if gamepad then row.choiceLabel:SetColor(.58,.58,.58,1) else row.choiceLabel:SetColor(.88,.81,.63,1) end
            y=y+height+(gamepad and 10 or 4)
            local capturedSession=session
            row:SetHandler('OnClicked',function() if capturedSession==session and B.npc and B.IsOpen() then item.callback() end end)
        else row.rpmChoice=nil;row:SetHandler('OnClicked',function() end) end
    end
    if gpLayout then
        U.GamepadSelect(gamepadList.selected and gamepadList.selected.rpmChoice and gamepadList.selected or rows[1])
        placeGamepadChoices(gamepadList.offset or 0)
        y=(gpLayout.bottom-gpLayout.bodyTop)/(native.scale or 1)
    end
    for _,c in pairs(footer) do c:SetHidden(true) end
    prevPage:SetHidden(true);nextPage:SetHidden(true);pageLabel:SetHidden(true)
    if current.custom then
        local nativeWheel=native and native.gamepad and current.kind=='speechcraft'
        background:SetCenterColor(.015,.012,.008,nativeWheel and 0 or .65)
        if not current.hideNavigation then
            local fy=(current.height or 520)-46;at(footer.back,pad,fy);at(footer.exit,pad+46,fy)
            footer.back:SetHidden(false);footer.exit:SetHidden(false)
        end
        position(current.height or 520,width)
    else
        background:SetCenterColor(.012,.01,.008,current.notes and .7 or 0)
        y=y+18
        if current.isHome then
            local x=pad
            if current.journal then at(footer.journal,x,y);footer.journal:SetHidden(false);x=x+46 end
            at(footer.exit,x,y);footer.exit:SetHidden(false)
        elseif current.persuasion then
            at(footer.persuasion,pad,y);footer.persuasion:SetHidden(false)
            at(footer.back,pad+46,y);footer.back:SetHidden(false)
        else
            at(footer.back,pad,y);footer.back:SetHidden(false)
            if current.journal then at(footer.journal,pad+46,y);footer.journal:SetHidden(false) end
            if not current.isQuestList and pages==1 then at(footer.exit,pad+(current.journal and 92 or 46),y);footer.exit:SetHidden(false) end
        end
        if pages>1 then
            prevPage:SetHidden(page<=1);nextPage:SetHidden(page>=pages);pageLabel:SetHidden(false)
            at(prevPage,66,y);at(nextPage,width-225,y);at(pageLabel,(width-100)/2,y+4);pageLabel:SetText(page..' / '..pages)
        end
        if gpLayout then
            -- LB/RB own paging in the native bottom strip. Keep the click
            -- targets available to that controller without duplicate labels.
            prevPage:SetAlpha(0);nextPage:SetAlpha(0);prevText:SetAlpha(0);nextText:SetAlpha(0)
            if pages>1 then at(pageLabel,(width-100)/2,y-46) end
        end
        position(y+54,width)
    end
    if not gpLayout then for _,c in ipairs({prevPage,nextPage,prevText,nextText}) do c:SetAlpha(1) end end
    U.current=current;U.page=page;U.textPage=textPage;U.pageCount=pages;U.textPageCount=#current.texts
    if B.Native and B.Native.IsGamepadMode() then for _,c in pairs(footer) do c:SetHidden(true) end end
end
function U.Relayout() if not wheelDrag and frame and not frame:IsHidden() then Render() end end
function B.Show(title,text,choices,notes,statusText)
    U.EndWheelDrag()
    if B.SocialWheel then B.SocialWheel.Hide() end
    if not B.npc then return end
    createWindow()
    local next=prepare(title,choices);next.title=title;next.sourceText=text;next.rawChoices=choices;next.notes=notes;next.statusText=statusText
    presentation(next)
    next.texts=chunks(text,notes and 240 or 190)
    -- A new answer inherits the menu that owns the inquiry, even after an
    -- animation, a refusal, or another answer. No visited text is a parent.
    if current then next.parentRoute=current.route or current.parentRoute end
    if next.isHome then next.route={kind='home'};next.parentRoute=nil
    elseif next.isQuestList then next.route={kind='quests'};next.parentRoute={kind='home'} end
    current=next;page=1;textPage=1;frame:SetHidden(false);Render()
end
function B.ShowCustomContent(title,height,options)
    B.Show(title,'',{});options=options or {}
    current.custom=true;current.height=height;current.width=options.width or WIDTH;current.kind=options.kind
    current.contentTop=options.contentTop or 44;current.hideNavigation=options.hideNavigation
    subtitle:SetHidden(true);Render();return frame
end
function B.RefreshCustomStatus() end -- Trust belongs in the wheel, never above it.
local function resizeConversation()
    U.Relayout()
    -- GuiRoot may apply the new global UI scale after the setting event.
    if type(zo_callLater)=='function' then zo_callLater(U.Relayout,0) end
end
if EVENT_SCREEN_RESIZED then EVENT_MANAGER:RegisterForEvent('RPMConversationResolution',EVENT_SCREEN_RESIZED,resizeConversation) end
if EVENT_INTERFACE_SETTING_CHANGED then EVENT_MANAGER:RegisterForEvent('RPMConversationScale',EVENT_INTERFACE_SETTING_CHANGED,resizeConversation) end

local function choice(text,callback) return {text=text,callback=callback} end

function B.ShowHome()
    if not B.npc then return end
    local npc=B.npc
    B.Show("Conversation",B.Greeting(npc),{
        choice("J’aurais besoin d’un renseignement.",function() B.ShowQuests() end),
        choice("Je cherche un marchand ou un service.",function() B.ShowServices() end),
        choice("Que pouvez-vous me dire sur les environs ?",function() B.ShowRumor() end),
        choice("Vous avez un moment pour parler ?",function() B.ShowSocial() end),
        choice("(Consulter mon carnet.)",function() B.ShowNotebook() end),
    })
end

function B.ShowQuests()
    local choices={}
    for _,q in ipairs(B.Quests()) do
        local quest=q
        choices[#choices+1]=choice(quest.name,function() B.ShowQuest(quest) end)
    end
    B.Show("Mes quêtes",#choices>0 and "Je vous écoute. De quoi s’agit-il ?" or "Je n’ai rien de précis à demander pour le moment.",choices)
    U.SetRoute({kind='quests'})
end

local function freshQuest(q)
    local fresh=B.CurrentQuest(q)
    if not fresh then B.ShowQuests();return nil end
    return fresh
end
function B.ShowQuest(q)
    q=freshQuest(q);if not q then return end
    local choices={}
    for _,p in ipairs(B.MatchPlaces(q)) do
        local place=p
        local question=B.PlaceQuestion(place.name,place)
        choices[#choices+1]=choice(question,function()
            local fresh=freshQuest(q);if not fresh then return end
            -- Revalidate the journal evidence after every step change.
            for _,newPlace in ipairs(B.MatchPlaces(fresh)) do
                if newPlace.normal==place.normal then B.ShowPlace(newPlace);return end
            end
            B.ShowQuest(fresh)
        end)
    end
    choices[#choices+1]=choice("(Relire mes notes sur cette affaire.)",function() B.ShowEvidence(q) end)
    choices[#choices+1]=choice("Parler d’une autre quête.",function() B.ShowQuests() end)
    local text="Je vous écoute."
    if #choices==2 then text="Qu’est-ce que vous cherchez, au juste ?" end
    B.Show(q.name,text,choices)
end
function B.ShowPlace(place)
    local answer=B.PlaceAnswer(place)
    local informant=B.npc.name
    B.Show("À propos de « "..place.name.." »",answer,{
        choice("(Relire le passage qui parle de cet endroit.)",function()
            B.Show(place.kind,place.source,{
                choice("Revenir à ma question.",function() B.ShowPlace(place) end),
            },true)
        end),
        choice("(Noter cet endroit dans mon carnet.)",function()
            B.Remember(place,answer,informant)
            B.Show("Piste notée","Vous avez noté « "..place.name.." » et le renseignement qui vous y conduit.",{
                choice("Continuer à parler de cette quête.",function() B.ShowQuest(place.quest) end),
            },true)
        end),
        choice("Poser une autre question sur cette quête.",function() B.ShowQuest(place.quest) end),
    })
end
function B.ShowEvidence(q,selected)
    q=freshQuest(q);if not q then return end
    local source=q.sources[selected or 1]
    local choices={}
    for i,entry in ipairs(q.sources) do
        local index=i
        if i~=(selected or 1) then
            choices[#choices+1]=choice("Relire : "..entry.kind..".",function() B.ShowEvidence(q,index) end)
        end
    end
    choices[#choices+1]=choice("Revenir à la conversation.",function() B.ShowQuest(q) end)
    B.Show(q.name..(source and (" · "..source.kind) or ""),source and source.text or "Je n’ai rien noté à ce sujet.",choices,true)
end

function B.ShowServices()
    SetMapToPlayerLocation()
    local locality=A.SubZone()
    local services=A.GetServices(locality)
    table.sort(services,function(a,b) return A.ServiceLabel(a)<A.ServiceLabel(b) end)
    local choices={}
    for _,name in ipairs(services) do
        local service=name
        choices[#choices+1]=choice("Où trouver : "..A.ServiceLabel(service).." ?",function()
            SetMapToPlayerLocation()
            local entry=A.GetService(service,A.SubZone())
            local text="Je ne sais pas où vous pourriez trouver ça."
            if entry then
                local dir,dist,raw=A.ServiceDirections(entry.mapX,entry.mapY)
                if raw<.045 then text="C’est tout près d’ici. Regardez autour de vous."
                else text=string.format("%s ? Vers le %s. %s",A.ServiceLabel(service),dir,dist) end
            end
            B.Show(A.ServiceLabel(service),text,{
                choice("Demander un autre service.",function() B.ShowServices() end),
            })
        end)
    end
    B.Show("Services des environs",#choices>0 and "Que cherchez-vous ?" or "Je ne connais personne à vous recommander dans le coin.",choices)
end
function B.ShowRumor()
    local zone=GetUnitZoneIndex("player")
    local index=A.ChoosePOI(zone,true)
    if not index then
        B.Show("Les environs","Je ne connais pas assez les environs pour vous guider.",{})
        return
    end
    local place={name=B.Name(GetPOIInfo(zone,index))}
    local choices={
        choice("Vous connaissez un autre endroit ?",function() B.ShowRumor() end),
        choice("Merci, je retiens cet endroit.",function()
            IHeardARumor.lastPOI=index;IHeardARumor.lastPOIZone=zone
            B.ShowHome()
        end),
    }
    local description=B.PlaceDescription(place)
    if description then
        choices[#choices+1]=choice("(Relire ce que je sais de cet endroit.)",function()
            B.Show(place.name,description,{
                choice("Revenir à la conversation.",function() B.ShowRumor() end),
            },true)
        end)
    end
    B.Show("Les environs",B.PlaceAnswer(place),choices)
end

function B.ShowSocial()
    local npc=B.npc
    if not B.Relation(npc) then
        B.Show("Conversation","Bien sûr. Je vous écoute.",{})
        return
    end
    local gained=B.ChangeTrust(npc,"conversation",1)
    B.Show("Faire connaissance",gained and "Oui, j’ai un peu de temps. Qu’est-ce qui vous amène par ici ?" or "Vous vouliez me demander autre chose ?",{
        choice("Merci d’avoir pris le temps de m’écouter.",function()
            B.ChangeTrust(npc,"courtesy",1)
            B.Show("Prendre le temps","Il n’y a pas de quoi. Bonne route à vous.",{})
        end),
        choice("Allons, vous pouvez bien m’en dire davantage.",function()
            B.ChangeTrust(npc,"pressure",-1)
            B.Show("Ne pas brusquer les choses","Je vous ai dit ce que je savais. N’insistez pas.",{})
        end),
    })
end
function B.ShowNotebook()
    local choices={}
    local active={};for _,q in ipairs(B.Quests()) do active[q.key]=true end
    for _,entry in ipairs(B.saved.notebook) do
        local note=entry
        choices[#choices+1]=choice(note.name..(active[note.questKey] and "" or " — ancienne piste"),function()
            B.Show("Piste : "..note.name,note.questName.."\n\n"..note.kind.." :\n« "..note.source.." »",{},true)
        end)
    end
    B.Show("Mes pistes",#choices>0 and "Les renseignements que vous avez choisi de conserver." or "Je n’ai encore noté aucune piste.",choices,true)
end

-- Being friendly is not evidence that a creature can converse.
-- ESO exposes livestock but no general animal/humanoid predicate. Require
-- a recognised speaking race/catalogue identity or an actual native dialogue.
local animalNames={chien=true,chienne=true,chat=true,chatte=true,chaton=true,chiot=true,
    cheval=true,jument=true,poulain=true,vache=true,taureau=true,boeuf=true,veau=true,
    mouton=true,brebis=true,agneau=true,chevre=true,bouc=true,cochon=true,porc=true,
    poule=true,poulet=true,coq=true,lapin=true,renard=true,loup=true,louve=true,
    ours=true,cerf=true,biche=true,daim=true,rat=true,souris=true,ecureuil=true,
    serpent=true,lezard=true,grenouille=true,crapaud=true,singe=true,guar=true,
    senche=true,chatigre=true,chameau=true,chevreuil=true,crabe=true,
    dog=true,cat=true,horse=true,cow=true,chicken=true,fox=true,wolf=true,deer=true,
    goat=true,sheep=true,pig=true,rabbit=true,monkey=true,squirrel=true,bear=true}
local speakingRaces={maormer=true,dremora=true,goblin=true,nereid=true,reachman=true}
local khajiitForms={alfiq=true,['senche-raht']=true,['pahmar-raht']=true,['cathay-raht']=true}
function B.CanConverseWithUnit(unitTag,useNative)
    if type(IsUnitLivestock)=='function' and IsUnitLivestock(unitTag) then return false end
    local race=type(GetUnitRace)=='function' and B.Normalize(GetUnitRace(unitTag)) or ''
    if B.SocialRace(race) or speakingRaces[race] then return true end
    if useNative then return true end -- A game-authored conversation is authoritative.
    local name=B.Name(GetUnitName(unitTag))
    local record=B.NpcRaces and B.NpcRaces.Find(name)
    if record and khajiitForms[record.raceKey] then return true end
    local plain=B.Normalize(name):gsub('^le ',''):gsub('^la ',''):gsub('^les ',''):gsub('^un ',''):gsub('^une ','')
    if animalNames[plain:match('^([^ ]+)') or ''] then return false end
    return record~=nil
end

function B.Open(useNative)
    if B.IsOpen() then B.Close();return end
    useNative=not not (B.Native and B.saved.nativeConversation and B.Native.IsConversing() and (useNative or IsInteracting()))
    local unitTag=useNative and "interact" or "reticleover"
    if IsUnitInCombat("player") then d("[RolePlayMod] Attendez la fin du combat pour discuter.");return end
    if not DoesUnitExist(unitTag) or IsUnitPlayer(unitTag) or IsUnitDead(unitTag) then
        d("[RolePlayMod] Visez un PNJ vivant disposé à discuter.");return
    end
    local reaction=GetUnitReaction(unitTag)
    if not useNative and reaction~=UNIT_REACTION_FRIENDLY and reaction~=UNIT_REACTION_NEUTRAL and reaction~=UNIT_REACTION_PLAYER_ALLY and reaction~=UNIT_REACTION_NPC_ALLY then
        d("[RolePlayMod] Cette personne n’est pas disposée à discuter.");return
    end
    if not B.CanConverseWithUnit(unitTag,useNative) then
        d("[RolePlayMod] Cette cible n’est pas un interlocuteur identifié.");return
    end
    SetMapToPlayerLocation()
    local zoneId,x,y,z=GetUnitWorldPosition("player")
    B.npc={name=B.Name(GetUnitName(unitTag)),caption=B.Name(GetUnitCaption(unitTag)),zoneIndex=GetUnitZoneIndex("player"),
        zoneId=zoneId,locality=A.SubZone(),x=x,y=y,z=z}
    if RPM_LOCALE.english then B.npc.clientName=zo_strformat('<<C:1>>',_G.GetUnitName(unitTag) or '') end
    B.npc.race=type(GetUnitRace)=="function" and GetUnitRace(unitTag) or ""
    if B.NpcRaces then B.NpcRaces.Resolve(B.npc,unitTag) end
    B.npc.alliance=type(GetUnitAlliance)=="function" and GetUnitAlliance(unitTag) or 0
    B.nativeSession=useNative
    session=session+1
    B.ChangeTrust(B.npc,"visit",1)
    B.ownsCursor=not IsGameCameraUIModeActive()
    SetGameCameraUIMode(true)
    B.ShowHome()
    if useNative then B.Native.Begin() end
end

EVENT_MANAGER:RegisterForUpdate("IHRBetaDistance",300,function()
    if not B.IsOpen() or not B.npc then return end
    local zone,x,y,z=GetUnitWorldPosition("player")
    local dx,dy,dz=x-B.npc.x,y-(B.npc.y or y),z-B.npc.z
    if zone~=B.npc.zoneId or dx*dx+dy*dy+dz*dz>62500 or IsUnitInCombat("player") then B.Close() end
end)
local function closeOn(event,name)
    if event then EVENT_MANAGER:RegisterForEvent(name,event,function() B.Close() end) end
end
closeOn(EVENT_PLAYER_DEACTIVATED,"IHRBetaLeave")
closeOn(EVENT_CHATTER_BEGIN,"IHRBetaChatter")
closeOn(EVENT_OPEN_STORE,"IHRBetaStore")
if EVENT_QUEST_ADVANCED then
    EVENT_MANAGER:RegisterForEvent("IHRBetaAdvance",EVENT_QUEST_ADVANCED,function()
        if B.IsOpen() then B.ShowQuests() end
    end)
end
