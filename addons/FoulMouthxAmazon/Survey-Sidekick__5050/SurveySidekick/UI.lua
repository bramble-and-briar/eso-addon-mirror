local S=SurveySidekick
local WM=WINDOW_MANAGER
local ipairs, pairs, type = ipairs, pairs, type
local math, table = math, table
local TOPLEFT, TOPRIGHT, CENTER = TOPLEFT, TOPRIGHT, CENTER
local CT_BACKDROP, CT_CONTROL = CT_BACKDROP, CT_CONTROL
local MOUSE_BUTTON_INDEX_LEFT = MOUSE_BUTTON_INDEX_LEFT
local InformationTooltip = InformationTooltip
local ClearTooltip, InitializeTooltip, SetTooltipText = ClearTooltip, InitializeTooltip, SetTooltipText
local palettes = {
    Plum={background={.09,.055,.13},title={.25,.12,.36},border={.63,.48,.78}},
    Emerald={background={.035,.10,.075},title={.075,.27,.18},border={.36,.67,.49}},
    Ocean={background={.035,.075,.12},title={.07,.21,.34},border={.35,.60,.79}},
    Ember={background={.12,.055,.035},title={.34,.13,.065},border={.79,.49,.30}},
    Midnight={background={.055,.06,.075},title={.14,.16,.21},border={.48,.53,.64}},
    Rose={background={.12,.045,.075},title={.33,.10,.20},border={.78,.43,.61}}
}
local paletteOrder={"Plum","Emerald","Ocean","Ember","Midnight","Rose"}
local themeSurfaces={}
local function Appearance()
    local choice=S.character.appearance
    if type(choice)~="table" then choice={};S.character.appearance=choice end
    for _,part in ipairs({"background","title","border"})do
        if not palettes[choice[part]] then choice[part]="Plum" end
    end
    return choice
end
function S.ApplyAppearance()
    local choice=Appearance()
    for _,surface in ipairs(themeSurfaces)do
        local part=surface.kind=="title" and "title" or "background"
        local color=palettes[choice[part]][part]
        local border=palettes[choice.border].border
        local shade=surface.kind=="input" and .75 or 1
        surface.control:SetCenterColor(color[1]*shade,color[2]*shade,color[3]*shade,surface.alpha)
        surface.control:SetEdgeColor(border[1],border[2],border[3],1)
    end
    if S.appearanceCombos then
        for part,combo in pairs(S.appearanceCombos)do
            if part~="preset" then combo:SetSelectedItem(choice[part])end
        end
        local preset=choice.background==choice.title and choice.title==choice.border and choice.title or "Custom"
        S.appearanceCombos.preset:SetSelectedItem(preset)
    end
end
local function ThemeSurface(control,kind,alpha)
    themeSurfaces[#themeSurfaces+1]={control=control,kind=kind,alpha=alpha or 1}
    S.ApplyAppearance()
end
function S.SetAppearance(part,name)
    if not palettes[name] then return false end
    local choice=Appearance()
    if part=="preset" then
        choice.background=name;choice.title=name;choice.border=name
    elseif part=="background" or part=="title" or part=="border" then choice[part]=name
    else return false end
    S.ApplyAppearance();return true
end
local function Label(parent,name,text,x,y,width,font)
    local c=WM:CreateControl(name,parent,CT_LABEL)
    c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);c:SetWidth(width);c:SetFont(font or "ZoFontGame")
    c:SetColor(.94,.91,.97,1);c:SetText(text or "");return c
end
local tooltipOwner
local function Tooltip(button,text)
    button.tooltip=text
    button:SetHandler("OnMouseEnter",function(self)
        tooltipOwner=self
        InitializeTooltip(InformationTooltip,self,TOP,0,-6,BOTTOM)
        SetTooltipText(InformationTooltip,self.tooltip)
    end)
    button:SetHandler("OnMouseExit",function(self)if tooltipOwner==self then ClearTooltip(InformationTooltip);tooltipOwner=nil end end)
    button:SetHandler("OnEffectivelyHidden",function(self)if tooltipOwner==self then ClearTooltip(InformationTooltip);tooltipOwner=nil end end)
end
local BUTTON_HELP={
    ["My Surveys"]="View the surveys in your backpack, duplicate counts, map pins and travel options.",
    ["Current Run"]="Start or pause gathering and view your live materials, timer and material goal.",
    ["The Hoard Report"]="View saved runs, loot breakdowns, estimates and your personal record.",
    ["Start / Resume"]="Start counting materials you loot, or continue your paused run. Existing run totals are kept.",
    ["Pause"]="Pause the timer and stop counting loot. Start / Resume continues the same run.",
    ["Finish Run"]="Finish this run and save its material totals, time and estimates in The Hoard Report.",
    ["Set Goal"]="Set a collection target for the material selected in the dropdown. All of its loot in this run counts.",
    ["Newer"]="Show a more recent saved run.",
    ["Older"]="Show an older saved run.",
    ["Copy Summary"]="Open a short run summary you can copy into guild chat or Discord. Nothing is sent automatically.",
    ["Export Details"]="Open detailed material quantities, loot categories and estimates as copyable text.",
    ["Close"]="Close this copy window. Your run and report are kept."
}
local function Button(parent,name,text,x,y,width,fn,description)
    local c=WM:CreateControlFromVirtual(name,parent,"ZO_DefaultButton")
    c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);c:SetDimensions(width,30);c:SetText(text);c:SetHandler("OnClicked",function()ClearTooltip(InformationTooltip);fn()end)
    Tooltip(c,description or BUTTON_HELP[text] or text);return c
end
local function IconButton(parent,name,texture,x,y,size,tooltip,fn,template)
    local c=WM:CreateControlFromVirtual(name,parent,template or "ZO_ButtonBehaviorClickSound")
    c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);c:SetDimensions(size,size)
    if texture then
        c:SetNormalTexture(texture);c:SetPressedTexture(texture);c:SetMouseOverTexture(texture)
    end
    c:SetMouseEnabled(true);c:SetHandler("OnClicked",function()ClearTooltip(InformationTooltip);fn()end)
    Tooltip(c,tooltip);return c
end
local function WayshrineTexture()
    for i=1,GetNumFastTravelNodes() do
        local _,_,_,_,icon,_,kind=GetFastTravelNodeInfo(i)
        if kind==POI_TYPE_WAYSHRINE and icon and icon~="" then return icon end
    end
    return "EsoUI/Art/MainMenu/menuBar_map_up.dds"
end
function S.SaveWindowPosition()
    if not S.ui then return end
    local left,top=S.ui:GetLeft(),S.ui:GetTop()
    if type(left)=="number" and type(top)=="number" and left==left and top==top and math.abs(left)<100000 and math.abs(top)<100000 then
        S.character.windowPosition={left=left,top=top}
    end
end
function S.RestoreWindowPosition()
    local p=S.character.windowPosition
    if p and type(p.left)=="number" and type(p.top)=="number" and p.left==p.left and p.top==p.top
        and math.abs(p.left)<100000 and math.abs(p.top)<100000 then
        S.ui:ClearAnchors();S.ui:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,p.left,p.top)
    end
end
function S.SaveWindowState()
    if not S.ui then return end
    S.SaveWindowPosition();S.character.windowVisible=not S.ui:IsHidden()
end
function S.SetWindowVisible(visible)
    if not S.ui then return end
    if not visible then S.SaveWindowPosition();if S.goalQty then S.goalQty:LoseFocus()end end
    S.character.windowVisible=visible==true
    S.ui:SetHidden(not visible)
    if not visible and S.appearanceWindow then S.appearanceWindow:SetHidden(true)end
    if visible then S.Render()end
end
function S.ApplyWindowMode()
    local minimized=S.character.minimized==true
    local width=minimized and 460 or 920
    local height=minimized and 90 or 700
    local scale=S.character.scale or 0.8
    S.ui:SetDimensions(width*scale,height*scale)
    S.canvas:SetDimensions(width,height);S.canvas:SetScale(scale)
    S.header:SetWidth(width)
    S.title:SetWidth(minimized and 205 or 600)
    S.title:SetFont(minimized and "ZoFontWinH2" or "ZoFontWinH1")
    for _,button in ipairs(S.tabButtons) do button:SetHidden(minimized)end
    S.craftButton:SetHidden(minimized)
    S.status:SetHidden(minimized);S.compactStatus:SetHidden(not minimized)
    local icon=minimized and "plus" or "minus"
    S.minimizeButton:SetNormalTexture("EsoUI/Art/Buttons/"..icon.."_up.dds")
    S.minimizeButton:SetPressedTexture("EsoUI/Art/Buttons/"..icon.."_down.dds")
    S.minimizeButton:SetMouseOverTexture("EsoUI/Art/Buttons/"..icon.."_over.dds")
    S.minimizeButton.tooltip=minimized and "Restore full window" or "Minimize to tracker bar (keeps tracking)"
end
function S.SetScalePercent(percent)
    percent=tonumber(percent)
    if not percent or percent<60 or percent>120 then
        S.Say("Use /surveys scale 60 through 120. Default: 80.");return
    end
    S.SaveWindowPosition()
    S.character.scale=percent/100
    S.ApplyWindowMode();S.RestoreWindowPosition();S.Render()
    if S.appearanceWindow then S.appearanceWindow:SetScale(S.character.scale)end
    S.Say("Window size set to "..percent.."%.")
end
function S.SetMinimized(value)
    local left,top=S.ui:GetLeft(),S.ui:GetTop()
    S.character.minimized=value==true
    S.ui:ClearAnchors();S.ui:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,left,top)
    S.ApplyWindowMode();S.SaveWindowPosition();S.Render()
end
local function Edit(parent,name,x,y,width,hint)
    local bg=WM:CreateControl(name.."BG",parent,CT_BACKDROP)
    bg:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);bg:SetDimensions(width,30)
    ThemeSurface(bg,"input",.95)
    local edit=WM:CreateControlFromVirtual(name,bg,"ZO_DefaultEdit")
    edit:SetAnchor(TOPLEFT,bg,TOPLEFT,6,3);edit:SetDimensions(width-12,24)
    edit:SetFont("ZoFontGame");edit:SetMaxInputChars(120);edit:SetMouseEnabled(true);edit:SetEditEnabled(true)
    edit:SetHandler("OnMouseDown",function(self,button)
        if button==MOUSE_BUTTON_INDEX_LEFT then self:TakeFocus()end
    end)
    -- The border/padding is also clickable, instead of starting a window drag.
    bg:SetMouseEnabled(true);bg:SetHandler("OnMouseDown",function(_,button)
        if button==MOUSE_BUTTON_INDEX_LEFT then edit:TakeFocus()end
    end)
    edit:SetHandler("OnEnter",function(self)self:LoseFocus()end)
    edit:SetHandler("OnEscape",function(self)self:LoseFocus()end)
    return edit
end
local function Dropdown(parent,name,x,y,width,description)
    local container=WM:CreateControlFromVirtual(name,parent,"ZO_ComboBox")
    container:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);container:SetDimensions(width,30)
    local combo=ZO_ComboBox_ObjectFromContainer(container);combo:SetSortsItems(false)
    return combo,container
end
function S.ShowAppearance()
    if not S.appearanceWindow then
        local root=WM:CreateTopLevelWindow("SurveySidekickAppearance")
        root:SetDimensions(520,350);root:SetAnchor(CENTER,GuiRoot,CENTER,0,0)
        root:SetMouseEnabled(true);root:SetMovable(true);root:SetClampedToScreen(true);root:SetDrawTier(DT_HIGH)
        local bg=WM:CreateControl(nil,root,CT_BACKDROP);bg:SetAnchorFill();ThemeSurface(bg,"background",.99)
        Label(root,nil,"APPEARANCE",20,15,350,"ZoFontWinH2")
        Button(root,nil,"Close",400,12,100,function()root:SetHidden(true)end,"Close the color menu. Your color choices are saved automatically.")
        S.appearanceCombos={}
        for i,row in ipairs({{"preset","Color preset"},{"background","Background"},{"title","Title bar"},{"border","Borders"}})do
            local part=row[1]
            Label(root,nil,row[2],20,66+(i-1)*52,170)
            local combo=Dropdown(root,"SurveySidekickColor"..part,200,62+(i-1)*52,295)
            S.appearanceCombos[part]=combo
            for _,name in ipairs(paletteOrder)do
                local colorName=name
                combo:AddItem(combo:CreateItemEntry(colorName,function()S.SetAppearance(part,colorName)end))
            end
        end
        S.appearanceReset=Button(root,"SurveySidekickResetColors","Reset Colors",20,282,160,function()S.SetAppearance("preset","Plum")end,"Restore the default plum background, violet title bar and lavender borders.")
        Label(root,nil,"Changes apply instantly and save for this character.",20,320,480)
        S.appearanceWindow=root
    end
    S.ApplyAppearance()
    S.appearanceWindow:SetScale(S.character.scale or .8)
    S.appearanceWindow:SetHidden(false)
end
function S.PopulateGoalMaterials(craft,selected)
    local combo=S.goalMaterialCombo;combo:ClearItems()
    local items=S.GoalChoices(craft);local chosen
    for _,entry in ipairs(items)do
        local id,name=entry.id,entry.name
        local option=combo:CreateItemEntry(name,function()
            S.goalSelectedId=id;S.character.goalItemId=id;S.character.goalCraft=craft
        end)
        option.materialId=id;combo:AddItem(option)
        if id==selected then chosen=entry end
    end
    S.goalSelectedId=chosen and chosen.id or nil
    combo:SetSelectedItem(chosen and chosen.name or (#items==0 and "No known materials yet" or "Choose material"))
end
function S.SetupGoalDropdowns()
    local current=S.character.run and S.character.run.goal
    local selected=current and current.id or S.character.goalItemId
    local entry=selected and S.goalCatalog[selected]
    S.goalCraft=entry and entry.craft or S.character.goalCraft or "Alchemy"
    local valid=false;for _,craft in ipairs(S.GoalCrafts)do if craft==S.goalCraft then valid=true end end
    if not valid then S.goalCraft="Alchemy" end
    for _,craft in ipairs(S.GoalCrafts)do
        local choice=craft
        S.goalTypeCombo:AddItem(S.goalTypeCombo:CreateItemEntry(choice,function()
            S.goalCraft=choice;S.character.goalCraft=choice;S.character.goalItemId=nil
            S.PopulateGoalMaterials(choice,nil)
        end))
    end
    S.goalTypeCombo:SetSelectedItem(S.goalCraft)
    S.PopulateGoalMaterials(S.goalCraft,selected)
    S.goalMaterialCombo:SetPreshowDropdownCallback(function()S.PopulateGoalMaterials(S.goalCraft,S.goalSelectedId)end)
    if current and current.target then S.goalQty:SetText(tostring(current.target))end
end
local function Scroll(parent,name,x,y,w,h)
    local c=WM:CreateControlFromVirtual(name,parent,"ZO_ScrollContainer")
    c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);c:SetDimensions(w,h)
    local child=c:GetNamedChild("ScrollChild");child:SetWidth(w-24)
    return c,child
end
function S.ShowExport(text)
    if not S.export then
        local root=WM:CreateTopLevelWindow("SurveySidekickExport")
        root:SetDimensions(770,550);root:SetAnchor(CENTER,GuiRoot,CENTER,0,0)
        root:SetMouseEnabled(true);root:SetMovable(true);root:SetClampedToScreen(true);root:SetDrawTier(DT_HIGH)
        local bg=WM:CreateControl(nil,root,CT_BACKDROP);bg:SetAnchorFill();ThemeSurface(bg,"background",.99)
        Label(root,nil,"COPY YOUR HOARD",20,15,600,"ZoFontWinH2")
        Label(root,nil,"Click the text, then Ctrl+A and Ctrl+C. Nothing is sent automatically.",20,51,720)
        Button(root,nil,"Close",650,12,100,function()root:SetHidden(true)end)
        local scroll,child=Scroll(root,"SurveySidekickExportScroll",20,90,730,435)
        local edit=WM:CreateControl("SurveySidekickExportText",child,CT_EDITBOX)
        edit:SetAnchor(TOPLEFT,child,TOPLEFT,0,0);edit:SetDimensions(695,1200);edit:SetFont("ZoFontGame")
        edit:SetMultiLine(true);edit:SetMaxInputChars(100000);edit:SetMouseEnabled(true)
        edit:SetHandler("OnEscape",function(self)self:LoseFocus()end)
        S.export=root;S.exportText=edit;S.exportChild=child
    end
    S.export:SetScale(S.character.scale or 0.8)
    S.export:SetHidden(false);S.exportText:SetText(text)
    local lineCount=1;for _ in text:gmatch("\n") do lineCount=lineCount+1 end
    local height=math.max(420,lineCount*26+120)
    S.exportText:SetHeight(height);S.exportChild:SetHeight(height)
    S.exportText:TakeFocus();S.exportText:SelectAll()
end
function S.CreateUI()
    local window=WM:CreateTopLevelWindow("SurveySidekickWindow");S.ui=window
    window:SetHidden(true)
    window:SetDimensions(736,560);window:SetAnchor(CENTER,GuiRoot,CENTER,0,0)
    window:SetMouseEnabled(true);window:SetMovable(true);window:SetClampedToScreen(true)
    window:SetHandler("OnMoveStop",function()S.SaveWindowPosition()end)
    -- Scale the child canvas so the draggable top-level keeps screen-space coordinates.
    local root=WM:CreateControl("SurveySidekickCanvas",window,CT_CONTROL);S.canvas=root
    root:SetAnchor(TOPLEFT,window,TOPLEFT,0,0);root:SetDimensions(920,700)
    local bg=WM:CreateControl(nil,root,CT_BACKDROP);bg:SetAnchorFill();ThemeSurface(bg,"background",.97)
    local header=WM:CreateControl(nil,root,CT_BACKDROP);S.header=header;header:SetAnchor(TOPLEFT,root,TOPLEFT,0,0);header:SetDimensions(920,54)
    ThemeSurface(header,"title")
    S.title=Label(root,nil,"SURVEY SIDEKICK",20,12,600,"ZoFontWinH1")
    S.colorsButton=Button(root,"SurveySidekickColors","Colors",0,0,75,S.ShowAppearance,"Appearance: choose background, title bar and border colors, or apply a color preset.")
    S.colorsButton:ClearAnchors();S.colorsButton:SetAnchor(TOPRIGHT,root,TOPRIGHT,-225,12)
    local help=IconButton(root,"SurveySidekickHelp","EsoUI/Art/MenuBar/menuBar_help_up.dds",0,0,30,"Open instructions and slash commands.",function()S.ShowExport(S.Help())end)
    help:SetPressedTexture("EsoUI/Art/MenuBar/menuBar_help_down.dds");help:SetMouseOverTexture("EsoUI/Art/MenuBar/menuBar_help_over.dds")
    help:ClearAnchors();help:SetAnchor(TOPRIGHT,root,TOPRIGHT,-104,12)
    S.minimizeButton=IconButton(root,"SurveySidekickMinimize",nil,0,0,30,"Minimize",function()S.SetMinimized(not S.character.minimized)end,"ZO_MinusButton")
    S.minimizeButton:ClearAnchors();S.minimizeButton:SetAnchor(TOPRIGHT,root,TOPRIGHT,-62,12)
    local close=IconButton(root,"SurveySidekickClose",nil,0,0,24,"Close window (/surveys to reopen)",function()S.SetWindowVisible(false)end,"ZO_CloseButton")
    close:ClearAnchors();close:SetAnchor(TOPRIGHT,root,TOPRIGHT,-20,15)
    S.tabButtons={}
    for i,v in ipairs({{"surveys","My Surveys"},{"run","Current Run"},{"report","The Hoard Report"}}) do
        local tab=v[1];S.tabButtons[i]=Button(root,nil,v[2],20+(i-1)*220,66,210,function()S.tab=tab;S.Render()end)
    end
    S.panels={}
    for _,key in ipairs({"surveys","run","report"}) do
        local panel=WM:CreateControl(nil,root,CT_CONTROL);panel:SetAnchor(TOPLEFT,root,TOPLEFT,20,110);panel:SetDimensions(880,535);S.panels[key]=panel
    end
    local p=S.panels.surveys
    local crafts={"All","Blacksmithing","Clothing","Woodworking","Alchemy","Enchanting","Jewelry","Other"};local craftIndex=1
    S.craftButton=Button(root,"SurveySidekickSurveyType","Survey Type: All",690,66,210,function()
        craftIndex=craftIndex%#crafts+1;S.craftFilter=crafts[craftIndex]
        S.craftButton:SetText("Survey Type: "..S.craftFilter)
        S.tab="surveys";S.Render()
    end,"Survey Type: click to cycle through crafting types. All shows every survey in your backpack.")
    S.craftButton:SetFont("ZoFontGameSmall")
    S.inventoryInfo=Label(p,nil,"",0,40,865)
    local scroll,child=Scroll(p,"SurveySidekickSurveyScroll",0,75,875,340);S.surveyChild=child;S.surveyRows={}
    S.selectionLabel=Label(p,nil,"Select a survey to begin.",0,425,870)
    S.mapButton=IconButton(p,"SurveySidekickMap","EsoUI/Art/MainMenu/menuBar_map_up.dds",0,466,40,"Map Pin: open the selected survey map and place a waypoint. Replaces your current waypoint.",S.ShowMap)
    S.mapButton:SetPressedTexture("EsoUI/Art/MainMenu/menuBar_map_down.dds");S.mapButton:SetMouseOverTexture("EsoUI/Art/MainMenu/menuBar_map_over.dds")
    S.travelButton=IconButton(p,"SurveySidekickTravel",WayshrineTexture(),60,466,40,"Travel: nearest unlocked wayshrine (normal gold cost applies)",function()S.Travel(false)end)
    S.previewButton=IconButton(p,"SurveySidekickPreview",GetCurrencyKeyboardIcon(CURT_MONEY),120,466,40,"Preview destination and cost (does not travel)",function()S.Travel(true)end)
    S.refreshButton=IconButton(p,"SurveySidekickRefresh","SurveySidekick/textures/refresh.dds",180,466,40,"Refresh: rescan your backpack and update the survey list and duplicate counts. This also updates automatically.",S.Scan)
    p=S.panels.run
    S.runSummary=Label(p,nil,"",0,0,870,"ZoFontWinH2")
    S.breakdownInfo=Label(p,nil,"",0,39,870)
    Button(p,nil,"Start / Resume",0,94,165,S.StartRun)
    Button(p,nil,"Pause",177,94,125,S.PauseRun)
    Button(p,nil,"Finish Run",314,94,150,S.EndRun)
    Label(p,nil,"Survey Type",0,145,210)
    S.goalTypeCombo,S.goalTypeControl=Dropdown(p,"SurveySidekickGoalType",0,174,210,"Choose the survey's crafting type to filter the material list.")
    Label(p,nil,"Material",225,145,350)
    S.goalMaterialCombo,S.goalMaterialControl=Dropdown(p,"SurveySidekickGoalMaterial",225,174,350,"Choose a material by name. Newly collected materials are added automatically.")
    Label(p,nil,"Quantity",590,145,120);S.goalQty=Edit(p,"SurveySidekickGoalQty",590,174,120)
    Tooltip(S.goalQty,"Enter how many of this material you want to collect during the run.")
    S.setGoalButton=Button(p,"SurveySidekickSetGoal","Set Goal",725,174,145,function()S.SetGoal(S.goalSelectedId,S.goalQty:GetText())end)
    S.SetupGoalDropdowns()
    S.goalInfo=Label(p,nil,"",0,218,870)
    local scroll2,child2=Scroll(p,"SurveySidekickRunScroll",0,282,875,240)
    S.runText=Label(child2,nil,"",0,0,835);S.runChild=child2
    p=S.panels.report
    Button(p,nil,"Newer",0,0,130,function()S.reportIndex=math.max(1,S.reportIndex-1);S.RenderReport()end)
    Button(p,nil,"Older",145,0,130,function()S.reportIndex=math.min(math.max(1,#S.db.history),S.reportIndex+1);S.RenderReport()end)
    Button(p,nil,"Copy Summary",290,0,180,function()
        local r=S.db.history[S.reportIndex];if not r then S.Say("Finish a run first.");return end
        local b=r.breakdown or {regular=0,survey=0,other=r.total}
        S.ShowExport("THE HOARD REPORT: "..r.total.." materials in "..S.Time(r.seconds).." | Regular-sized "..b.regular.." | Survey/Large "..b.survey.." | Other "..b.other..". My survey pile has filed a complaint.")
    end)
    Button(p,nil,"Export Details",485,0,180,function()S.ShowExport(S.Report(S.db.history[S.reportIndex],true))end)
    S.reportInfo=Label(p,nil,"",0,45,870)
    local scroll3,child3=Scroll(p,"SurveySidekickReportScroll",0,85,875,435)
    S.reportText=Label(child3,nil,"",0,0,835);S.reportChild=child3
    S.status=Label(root,nil,"",20,658,875)
    S.compactStatus=Label(root,"SurveySidekickCompactStatus","",20,58,420)
    S.ApplyWindowMode();S.RestoreWindowPosition()
    S.SetWindowVisible(S.character.windowVisible~=false)
end
function S.RenderSurveys()
    if not S.surveyChild then return end
    local list={}
    for _,v in pairs(S.inventory or {}) do
        if (S.craftFilter=="All" or v.craft==S.craftFilter) then list[#list+1]=v end
    end
    table.sort(list,function(a,b)if a.zone==b.zone then return a.name<b.name end;return a.zone<b.zone end)
    for i=#list+1,#S.surveyRows do S.surveyRows[i]:SetHidden(true)end
    for i,v in ipairs(list) do
        local row=S.surveyRows[i]
        if not row then
            row=WM:CreateControlFromVirtual("SurveySidekickRow"..i,S.surveyChild,"ZO_DefaultButton")
            row:SetDimensions(835,48);row:SetAnchor(TOPLEFT,S.surveyChild,TOPLEFT,0,(i-1)*52)
            row:SetHandler("OnClicked",function(self)S.selected=self.itemId;S.RenderSurveys()end)
            S.surveyRows[i]=row
        end
        row.itemId=v.id;row:SetHidden(false)
        local count=" x"..v.count.." | bank "..(S.db.bank[v.id] or 0)
        row:SetText((S.selected==v.id and "> " or "")..v.name..count)
    end
    S.surveyChild:SetHeight(math.max(335,#list*52))
    local bankTotal=0;for _,n in pairs(S.db.bank) do bankTotal=bankTotal+n end
    S.inventoryInfo:SetText("Backpack: "..S.CountBackpack().." | Locations: "..#list.." | Bank: "..bankTotal..(S.db.bankSeen and " (last seen)" or " (not scanned yet)"))
    local v=S.selected and S.inventory[S.selected]
    S.selectionLabel:SetText(v and (v.craft.." | "..v.zone.." | "..v.count.." copies left"..(S.locations[v.id] and "" or " | Install/update LibTreasure for location")) or (#list==0 and "No surveys for this craft. Choose All or put surveys in your backpack." or "Select a survey to begin."))
end
local function FitText(label,child,text)
    label:SetText(text);local _,height=label:GetTextDimensions();child:SetHeight(math.max(240,height+30))
end
function S.RenderRun()
    local r=S.character.run
    if not r then
        S.runSummary:SetText("Your next hoard is waiting.");S.breakdownInfo:SetText("Start/Resume, gather, then Finish Run. The loot split is automatic.")
        S.goalInfo:SetText("Goals track materials collected during the current run.")
        FitText(S.runText,S.runChild,"All crafting materials looted while the run is active count.\n\nYour material totals update automatically while the run is active.\n\nChoose a survey type, a material name and a quantity above to set a goal.");return
    end
    S.runSummary:SetText((r.running and "RUNNING" or "PAUSED").." | "..S.Time(r.seconds).." | "..r.total.." materials")
    local b=r.breakdown or {regular=0,survey=0,other=r.total}
    S.breakdownInfo:SetText("Regular-sized: "..b.regular.." | Survey/Large: "..b.survey.." | Other: "..b.other..((r.pending or 0)>0 and (" | Checking runes: "..r.pending) or ""))
    local current,target=S.Model.GoalProgress(r)
    S.goalInfo:SetText(target>0 and ("Goal: "..(r.goal.name or r.goal.id).." "..current.." / "..target) or "No material goal set.")
    local rows={};local sorted={};for _,v in pairs(r.materials)do sorted[#sorted+1]=v end
    table.sort(sorted,function(a,b)return a.count>b.count end)
    for _,v in ipairs(sorted)do rows[#rows+1]=v.name.."  x"..v.count.." | Regular "..(v.regular or 0).." / Survey-Large "..(v.survey or 0).." / Other "..(v.other or v.count)end
    local value,missing=S.Value(r.materials);table.insert(rows,1,string.format("Estimated value: %.0fg | %d unpriced items",value,missing))
    if #sorted==0 then rows[#rows+1]="Pick up some materials to start filling your hoard."end
    FitText(S.runText,S.runChild,table.concat(rows,"\n"))
end
function S.RenderReport()
    local r=S.db.history[S.reportIndex]
    S.reportInfo:SetText(r and ("Run "..S.reportIndex.." of "..#S.db.history.." | "..GetDateStringFromTimestamp(r.started).." | Last 30 runs saved") or "Finish a run to create your first report.")
    FitText(S.reportText,S.reportChild,S.Report(r))
end
function S.Render()
    if not S.ui or S.ui:IsHidden() then S.dirty=true;return end
    S.dirty=false
    local minimized=S.character.minimized==true
    for key,panel in pairs(S.panels)do panel:SetHidden(minimized or key~=S.tab)end
    local r=S.character.run
    S.compactStatus:SetText(r and ((r.running and "RUNNING" or "PAUSED").." | "..S.Time(r.seconds).." | "..r.total.." materials") or "Ready for your next hoard.")
    if minimized then return end
    if S.tab=="surveys" then S.RenderSurveys()elseif S.tab=="run" then S.RenderRun()else S.RenderReport()end
    S.status:SetText("v"..S.version.." | Maps: "..(LibTreasure_GetAllItemsData and "LibTreasure" or "install LibTreasure").." | Prices: "..(TamrielTradeCentrePrice and "TTC/manual" or "manual/unpriced").." | /surveys help")
end
