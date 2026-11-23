local S=SurveySidekick
local T=S.Text
local WM=WINDOW_MANAGER
local ipairs, pairs, type = ipairs, pairs, type
local math, table = math, table
local TOPLEFT, TOPRIGHT, CENTER = TOPLEFT, TOPRIGHT, CENTER
local CT_BACKDROP, CT_CONTROL = CT_BACKDROP, CT_CONTROL
local MOUSE_BUTTON_INDEX_LEFT = MOUSE_BUTTON_INDEX_LEFT
local updatingAppearance=false
local utilityLayout,layoutParents,utilitySizes={},{},{}
local function Remember(control,parent,x,y,width,height,kind)
    utilityLayout[#utilityLayout+1]={control=control,parent=parent,x=x,y=y,width=width,height=height,kind=kind}
    layoutParents[control]=parent
end
local buttonOpacityControls={}
function S.ApplyButtonOpacity()
    local value=tonumber(S.character.buttonOpacityPercent) or 100
    if value~=value then value=100 end
    value=math.max(0,math.min(100,value));S.character.buttonOpacityPercent=value
    for _,root in ipairs(buttonOpacityControls)do root:SetAlpha(S.journalUtilityMode and 1 or value/100)end
    if S.buttonOpacitySlider and not updatingAppearance then
        updatingAppearance=true;S.buttonOpacitySlider:SetValue(value);updatingAppearance=false
        S.buttonOpacityValue:SetText(string.format("%d%%",math.floor(value+.5)))
    end
end
function S.SetButtonOpacityPercent(value)
    value=tonumber(value)
    if not value or value~=value then return false end
    S.character.buttonOpacityPercent=math.max(0,math.min(100,value));S.ApplyButtonOpacity();return true
end
local function OpacityButton(root)
    buttonOpacityControls[#buttonOpacityControls+1]=root;S.ApplyButtonOpacity()
end
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
    local opacity=tonumber(S.character.opacityPercent) or 100
    if opacity~=opacity then opacity=100 end
    opacity=math.max(0,math.min(100,opacity));S.character.opacityPercent=opacity
    for _,surface in ipairs(themeSurfaces)do
        local part=surface.kind=="title" and "title" or "background"
        local color=palettes[choice[part]][part]
        local border=palettes[choice.border].border
        local shade=surface.kind=="input" and .75 or 1
        surface.control:SetCenterColor(color[1]*shade,color[2]*shade,color[3]*shade,surface.alpha*(surface.kind=="input" and (.5+.5*opacity/100) or opacity/100))
        surface.control:SetEdgeColor(border[1],border[2],border[3],1)
        if S.journalUtilityMode then
            surface.control:SetCenterColor(0,0,0,surface.kind=="input" and .45 or .08)
            surface.control:SetEdgeColor(.77,.75,.58,surface.kind=="input" and .5 or 0)
        end
    end
    if S.opacitySlider and not updatingAppearance then
        updatingAppearance=true;S.opacitySlider:SetValue(opacity);updatingAppearance=false
        S.opacityValue:SetText(string.format("%d%%",math.floor(opacity+.5)))
    end
    if S.sizeValue then S.sizeValue:SetText(string.format("%d%%",math.floor((S.character.scale or .8)*100+.5)))end
    S.ApplyButtonOpacity()
    if S.appearanceCombos then
        for part,combo in pairs(S.appearanceCombos)do
            if part~="preset" then combo:SetSelectedItem(T(choice[part]))end
        end
        local preset=choice.background==choice.title and choice.title==choice.border and choice.title or "Custom"
        S.appearanceCombos.preset:SetSelectedItem(T(preset))
    end
end
function S.SetOpacityPercent(percent)
    percent=tonumber(percent)
    if not percent or percent~=percent then return false end
    S.character.opacityPercent=math.max(0,math.min(100,percent));S.ApplyAppearance();return true
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
    c:SetColor(.94,.91,.97,1);c:SetText(T(text or ""));Remember(c,parent,x,y,width,nil,"label");return c
end
local tooltipOwner
local function Tooltip(button,text)
    button.tooltip=T(text)
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
    local callbackName=fn==S.ShowDetours and "ShowDetours" or fn==S.ShowAccountant and "ShowAccountant"
    c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);c:SetDimensions(width,30);c:SetText(T(text));c:SetHandler("OnClicked",function()
        ClearTooltip(InformationTooltip);((callbackName and S[callbackName]) or fn)()
    end)
    S.journalActions=S.journalActions or {}
    S.journalActions[#S.journalActions+1]={control=c,parent=parent,text=text,x=x,y=y,width=width}
    Remember(c,parent,x,y,width,30,text=="Close" and "close" or "button")
    if S.language~="en" then c:SetFont("ZoFontGameSmall")end
    OpacityButton(c);Tooltip(c,description or BUTTON_HELP[text] or text);return c
end
local function IconButton(parent,name,texture,x,y,size,tooltip,fn,template)
    local c=WM:CreateControlFromVirtual(name,parent,template or "ZO_ButtonBehaviorClickSound")
    c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);c:SetDimensions(size,size)
    if texture then
        c:SetNormalTexture(texture);c:SetPressedTexture(texture);c:SetMouseOverTexture(texture)
    end
    c:SetMouseEnabled(true);c:SetHandler("OnClicked",function()ClearTooltip(InformationTooltip);fn()end)
    OpacityButton(c);Tooltip(c,tooltip);return c
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
    if not visible then
        for _,window in ipairs({S.appearanceWindow or false,S.detourWindow or false,S.accountantWindow or false,S.catalogWindow or false})do
            if window then window:SetHidden(true)end
        end
    end
    if visible then S.Render()end
end
function S.ApplyWindowMode()
    local minimized=S.character.minimized==true
    local width=minimized and 560 or 920
    local height=minimized and 126 or 700
    local scale=S.character.scale or 0.8
    S.ui:SetDimensions(width*scale,height*scale)
    S.canvas:SetDimensions(width,height);S.canvas:SetScale(scale)
    S.header:SetWidth(width)
    S.title:SetWidth(minimized and 205 or 600)
    S.title:SetFont(minimized and "ZoFontWinH2" or "ZoFontWinH1")
    for _,button in ipairs(S.tabButtons) do button:SetHidden(minimized)end
    S.craftButton:SetHidden(minimized or S.tab~="surveys" or S.catalogKind=="treasure")
    S.colorsButton:SetHidden(minimized)
    S.status:SetHidden(minimized);S.compactStatus:SetHidden(not minimized);S.compactSelected:SetHidden(not minimized)
    local icon=minimized and "plus" or "minus"
    S.minimizeButton:SetNormalTexture("EsoUI/Art/Buttons/"..icon.."_up.dds")
    S.minimizeButton:SetPressedTexture("EsoUI/Art/Buttons/"..icon.."_down.dds")
    S.minimizeButton:SetMouseOverTexture("EsoUI/Art/Buttons/"..icon.."_over.dds")
    S.minimizeButton.tooltip=T(minimized and "Restore full window" or "Minimize to tracker bar (keeps tracking)")
end
function S.SetScalePercent(percent)
    percent=tonumber(percent)
    if not percent or percent<60 or percent>120 then
        S.Say("Use /surveys scale 60 through 120. Default: 80.");return
    end
    S.SaveWindowPosition()
    S.character.scale=percent/100
    if S.journalUtilityMode then S.ApplyAppearance();return end
    S.ApplyWindowMode();S.RestoreWindowPosition();S.Render();S.ApplyAppearance()
    for _,window in ipairs({S.appearanceWindow or false,S.detourWindow or false,S.accountantWindow or false,S.catalogWindow or false})do
        if window then window:SetScale(S.character.scale)end
    end
    S.Say(T("Window size set to %s%%.",percent))
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
    Remember(container,parent,x,y,width,30,"dropdown")
    OpacityButton(container)
    local combo=ZO_ComboBox_ObjectFromContainer(container);combo:SetSortsItems(false)
    return combo,container
end
local function OpacitySlider(name,parent,y)
    local slider=WM:CreateControl(name,parent,CT_SLIDER)
    slider:SetAnchor(TOPLEFT,parent,TOPLEFT,225,y);slider:SetDimensions(210,18)
    Remember(slider,parent,225,y,210,18,"slider")
    slider:SetMouseEnabled(true);slider:SetOrientation(ORIENTATION_HORIZONTAL)
    slider:SetThumbTexture("EsoUI/Art/Miscellaneous/scrollbox_elevator.dds",
        "EsoUI/Art/Miscellaneous/scrollbox_elevator_disabled.dds",nil,8,16)
    local track=WM:CreateControl(nil,slider,CT_BACKDROP)
    track:SetAnchor(CENTER,slider,CENTER,0,0);track:SetDimensions(210,6)
    Remember(track,slider,0,0,210,6,"slidertrack")
    ThemeSurface(track,"input",.95)
    slider:SetMinMax(0,100);slider:SetValueStep(5)
    return slider
end
function S.ShowAppearance()
    if not S.appearanceWindow then
        local root=WM:CreateTopLevelWindow("SurveySidekickAppearance")
        root:SetDimensions(520,535);root:SetAnchor(CENTER,GuiRoot,CENTER,0,0)
        root:SetMouseEnabled(true);root:SetMovable(true);root:SetClampedToScreen(true);root:SetDrawTier(DT_HIGH)
        local bg=WM:CreateControl(nil,root,CT_BACKDROP);bg:SetAnchorFill();ThemeSurface(bg,"background",.99)
        Label(root,nil,"Colors & Size",20,15,350,"ZoFontWinH2")
        Button(root,nil,"Close",400,12,100,function()root:SetHidden(true)end,"Close the color menu. Your color choices are saved automatically.")
        S.appearanceCombos={}
        for i,row in ipairs({{"preset","Color preset"},{"background","Background"},{"title","Title bar"},{"border","Borders"}})do
            local part=row[1]
            Label(root,nil,row[2],20,66+(i-1)*52,170)
            local combo=Dropdown(root,"SurveySidekickColor"..part,200,62+(i-1)*52,295)
            S.appearanceCombos[part]=combo
            for _,name in ipairs(paletteOrder)do
                local colorName=name
                combo:AddItem(combo:CreateItemEntry(T(colorName),function()S.SetAppearance(part,colorName)end))
            end
        end
        Label(root,nil,"Background opacity",20,278,200)
        S.opacitySlider=OpacitySlider("SurveySidekickOpacity",root,280)
        S.opacityValue=Label(root,nil,"",445,276,65)
        S.opacitySlider:SetHandler("OnValueChanged",function(_,value)if not updatingAppearance then S.SetOpacityPercent(value)end end)
        Label(root,nil,"Button opacity",20,321,200)
        S.buttonOpacitySlider=OpacitySlider("SurveySidekickButtonOpacity",root,323)
        S.buttonOpacityValue=Label(root,nil,"",445,319,65)
        S.buttonOpacitySlider:SetHandler("OnValueChanged",function(_,value)if not updatingAppearance then S.SetButtonOpacityPercent(value)end end)
        Label(root,nil,"Window size",20,365,180)
        Button(root,nil,"Smaller",200,360,100,function()S.SetScalePercent(math.max(60,(S.character.scale or .8)*100-5))end)
        S.sizeValue=Label(root,nil,"",315,365,65)
        Button(root,nil,"Larger",390,360,100,function()S.SetScalePercent(math.min(120,(S.character.scale or .8)*100+5))end)
        S.appearanceReset=Button(root,"SurveySidekickResetColors","Reset Colors",20,410,150,function()S.SetAppearance("preset","Plum")end)
        Button(root,nil,"Reset Background",185,410,150,function()S.SetOpacityPercent(100)end)
        Button(root,nil,"Reset Buttons",350,410,150,function()S.SetButtonOpacityPercent(100)end)
        Button(root,nil,"Reset Size",20,453,150,function()S.SetScalePercent(80)end)
        Label(root,nil,"Labels and survey names stay readable.",185,459,315,"ZoFontGameSmall")
        Label(root,nil,"Appearance and size save for this character.",20,495,480,"ZoFontGameSmall")
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
    combo:SetSelectedItem(chosen and chosen.name or T(#items==0 and "No known materials yet" or "Choose material"))
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
        S.goalTypeCombo:AddItem(S.goalTypeCombo:CreateItemEntry(T(choice),function()
            S.goalCraft=choice;S.character.goalCraft=choice;S.character.goalItemId=nil
            S.PopulateGoalMaterials(choice,nil)
        end))
    end
    S.goalTypeCombo:SetSelectedItem(T(S.goalCraft))
    S.PopulateGoalMaterials(S.goalCraft,selected)
    S.goalMaterialCombo:SetPreshowDropdownCallback(function()S.PopulateGoalMaterials(S.goalCraft,S.goalSelectedId)end)
    if current and current.target then S.goalQty:SetText(tostring(current.target))end
end
local function Scroll(parent,name,x,y,w,h)
    local c=WM:CreateControlFromVirtual(name,parent,"ZO_ScrollContainer")
    c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);c:SetDimensions(w,h)
    local child=c:GetNamedChild("ScrollChild");child:SetWidth(w-24)
    Remember(c,parent,x,y,w,h,"scroll")
    Remember(child,parent,0,0,w-24,nil,"scrollChild")
    return c,child
end

function S.CurrentCatalogItem()
    for _,item in ipairs(S.InventoryEntries("all","both"))do
        if item.id==S.catalogSelected then return item end
    end
end
function S.TravelCatalog(preview)
    S.Scan()
    local item=S.CurrentCatalogItem()
    if not item or item.backpack<1 then S.Say("Select a survey or treasure map in your backpack first.");return end
    if item.unidentified then S.Say("Identify this item from your backpack before traveling to its location.");return end
    local location=(item.kind=="survey" and S.locations or S.treasureLocations or {})[item.id]
    if not location then S.Say("Install/update LibTreasure to preview item locations.");return end
    S.Travel(preview,location,item)
end
local function BankStatus()
    if not S.db.bankItems then return T("Open your personal bank once to record surveys and treasure maps. Older survey counts may still be shown.")end
    if IsBankOpen()then return T("Personal bank open: counts refresh automatically.")end
    local seen=S.db.bankSeen or 0
    return T("Bank snapshot: %s (%d min ago). Open your bank to update it.",GetDateStringFromTimestamp(seen),math.max(0,math.floor((GetTimeStamp()-seen)/60)))
end
function S.RenderCatalog()
    if not S.catalogChild then return end
    if type(S.character.expandedZones)~="table"then S.character.expandedZones={}end
    S.character.catalogKind=S.catalogKind;S.character.catalogSource=S.catalogSource
    S.character.craftFilter=S.craftFilter
    S.catalogBankInfo:SetText(BankStatus())
    local entries={}
    for _,item in ipairs(S.InventoryEntries(S.catalogKind or "all",S.catalogSource or "both"))do
        local loc=S.locations[item.id]
        if S.craftFilter=="All" or (item.kind=="survey" and (item.craft or (loc and loc.craft))==S.craftFilter)then entries[#entries+1]=item end
    end
    for i=#entries+1,#S.catalogRows do S.catalogRows[i]:SetHidden(true)end
    local selected
    local groups=S.InventoryZoneGroups(entries,S.catalogSource)
    local y,itemIndex=0,0
    for i=#groups+1,#S.zoneRows do S.zoneRows[i]:SetHidden(true)end
    for i,group in ipairs(groups)do
        local header=S.zoneRows[i]
        if not header then
            header=WM:CreateControlFromVirtual("SurveySidekickZoneRow"..i,S.catalogChild,"ZO_DefaultButton")
            header:SetDimensions(835,34);header:SetFont("ZoFontGame")
            header:SetHandler("OnClicked",function(self)
                local expanded=S.character.expandedZones
                expanded[self.zoneKey]=not expanded[self.zoneKey];S.RenderCatalog()
            end)
            S.zoneRows[i]=header
        end
        local open=S.character.expandedZones[group.key]==true
        header.zoneKey=group.key;header:SetHidden(false);header:ClearAnchors()
        header.zoneName=group.name;header.surveyCount=group.surveys;header.mapCount=group.maps;header.zoneOpen=open
        header:SetAnchor(TOPLEFT,S.catalogChild,TOPLEFT,0,y)
        header.zoneCaption=(open and "- " or "+ ")..T(group.name).." | "..T("Surveys")..": "..group.surveys.." | "..T("Treasure maps")..": "..group.maps
        header:SetText(header.zoneCaption)
        y=y+38
        for _,item in ipairs(group.items)do
            itemIndex=itemIndex+1
            local row=S.catalogRows[itemIndex]
            if not row then
                row=WM:CreateControlFromVirtual("SurveySidekickInventoryRow"..itemIndex,S.catalogChild,"ZO_DefaultButton")
                row:SetDimensions(813,40);row:SetFont("ZoFontGameSmall")
                row:SetHandler("OnClicked",function(self)
                    S.catalogSelected=self.itemId;S.character.catalogSelected=self.itemId;S.Render()
                end)
                S.catalogRows[itemIndex]=row
            end
            row.itemId=item.id;row:SetHidden(not open);row:ClearAnchors()
            row:SetAnchor(TOPLEFT,S.catalogChild,TOPLEFT,22,y)
            row:SetText((S.catalogSelected==item.id and "> " or "")..T("%s | Backpack %d | Bank %d",item.name,item.backpack,item.bank))
            if open then y=y+44 end
            if S.catalogSelected==item.id then selected=item end
        end
    end
    S.catalogChild:SetHeight(math.max(270,y));S.catalogEmpty:SetHidden(#entries>0)
    S.selected=selected and not selected.unidentified and selected.kind=="survey" and selected.backpack>0 and selected.id or nil
    if selected then
        S.catalogInfo:SetText(selected.name.."\n"..T("%s | %s | Backpack %d | Bank %d",T(selected.kind=="survey" and "Surveys" or "Treasure maps"),T(selected.zone),selected.backpack,selected.bank))
    else
        S.catalogSelected=nil;S.character.catalogSelected=nil
        S.catalogInfo:SetText(T("Select a survey or treasure map to view its details."))
    end
    local location=selected and not selected.unidentified and (selected.kind=="survey" and S.locations or S.treasureLocations or {})[selected.id]
    local carried=selected and selected.backpack>0
    S.catalogOpenButton:SetText(T(selected and selected.kind=="treasure" and "Open Map" or "Open Survey"))
    local x=0
    for _,action in ipairs({{S.mapButton,location,40},{S.travelButton,location and carried,40},
        {S.previewButton,location and carried,40},{S.catalogHintButton,selected,115},{S.catalogOpenButton,carried and not selected.unidentified,185}})do
        local control,show,width=action[1],action[2],action[3]
        control:SetHidden(not show)
        if show then control:ClearAnchors();control:SetAnchor(TOPLEFT,S.panels.surveys,TOPLEFT,x,464);x=x+width+12 end
    end
    S.catalogActionNote:SetText(selected and (selected.unidentified and T(carried and "Open this item from your backpack to reveal its zone. The list refreshes automatically." or "Withdraw this unidentified item, then open it from your backpack to reveal its zone.")
        or (not carried and T("Withdraw this item from your bank before opening its picture.")
        or (not location and T("Install/update LibTreasure to preview item locations.") or ""))) or "")
    S.detourButton:SetHidden(not S.selected)
    S.character.catalogSelected=S.catalogSelected
    S.RenderDetours()
end
function S.ShowCatalog()
    S.tab="surveys"
    if S.character.minimized then S.SetMinimized(false)end
    S.SetWindowVisible(true);S.Scan();S.Render()
end
function S.CreateCatalogPanel(p)
    local kinds={all="All items",survey="Surveys",treasure="Treasure maps"}
    local sources={both="Backpack + Bank",backpack="Backpack",bank="Bank"}
    S.catalogKind=kinds[S.character.catalogKind] and S.character.catalogKind or "all"
    S.catalogSource=sources[S.character.catalogSource] and S.character.catalogSource or "both"
    S.catalogSelected=S.character.catalogSelected
    if type(S.character.expandedZones)~="table"then S.character.expandedZones={}end
    S.zoneRows={}
    S.catalogKindCombo=Dropdown(p,"SurveySidekickCatalogKind",0,0,230)
    S.catalogSourceCombo=Dropdown(p,"SurveySidekickCatalogSource",245,0,230)
    for _,key in ipairs({"all","survey","treasure"})do
        local value=key
        S.catalogKindCombo:AddItem(S.catalogKindCombo:CreateItemEntry(T(kinds[key]),function()
            S.catalogKind=value
            if value=="treasure"then S.craftFilter="All"end
            S.Render()
        end))
    end
    for _,key in ipairs({"both","backpack","bank"})do
        local value=key
        S.catalogSourceCombo:AddItem(S.catalogSourceCombo:CreateItemEntry(T(sources[key]),function()S.catalogSource=value;S.Render()end))
    end
    S.catalogKindCombo:SetSelectedItem(T(kinds[S.catalogKind]));S.catalogSourceCombo:SetSelectedItem(T(sources[S.catalogSource]))
    Button(p,"SurveySidekickResetFilters","Reset Filters",495,0,160,function()
        S.catalogKind="all";S.catalogSource="both";S.craftFilter="All"
        S.catalogKindCombo:SetSelectedItem(T("All items"));S.catalogSourceCombo:SetSelectedItem(T("Backpack + Bank"));S.Render()
    end,"Reset item, storage and survey-type filters.")
    S.refreshButton=IconButton(p,"SurveySidekickRefresh","SurveySidekick/textures/refresh.dds",825,0,36,
        "Refresh backpack counts; this also updates automatically. Bank counts update only while your personal bank is open.",S.Scan)
    S.detourButton=Button(p,"SurveySidekickDetour","Treasure Detour",0,43,235,S.ShowDetours,"Show carried treasure maps in the selected survey's zone.")
    S.catalogBankInfo=Label(p,nil,"",250,42,615,"ZoFontGameSmall");S.inventoryInfo=S.catalogBankInfo
    local sc,child=Scroll(p,"SurveySidekickInventoryScroll",0,90,875,280)
    S.catalogScroll=sc
    S.catalogChild=child;S.catalogRows={};S.surveyChild=child;S.surveyRows=S.catalogRows
    S.catalogEmpty=Label(child,nil,"No surveys or treasure maps match these filters.",0,0,835)
    S.catalogInfo=Label(p,nil,"",0,378,870,"ZoFontGameSmall");S.selectionLabel=S.catalogInfo
    S.catalogActionNote=Label(p,nil,"",0,432,870,"ZoFontGameSmall")
    S.mapButton=IconButton(p,"SurveySidekickMap","EsoUI/Art/MainMenu/menuBar_map_up.dds",0,464,40,
        "Map Pin: preview the selected item's location. Replaces your current waypoint.",S.PinCatalogItem)
    S.mapButton:SetPressedTexture("EsoUI/Art/MainMenu/menuBar_map_down.dds");S.mapButton:SetMouseOverTexture("EsoUI/Art/MainMenu/menuBar_map_over.dds")
    S.catalogMapButton=S.mapButton
    S.travelButton=IconButton(p,"SurveySidekickTravel",WayshrineTexture(),52,464,40,
        "Travel: nearest unlocked wayshrine (normal gold cost applies)",function()S.TravelCatalog(false)end)
    S.previewButton=IconButton(p,"SurveySidekickPreview",GetCurrencyKeyboardIcon(CURT_MONEY),104,464,40,
        "Preview destination and cost (does not travel)",function()S.TravelCatalog(true)end)
    S.catalogHintButton=Button(p,"SurveySidekickCatalogHint","Hint",156,464,115,function()S.ShowItemHint(S.catalogSelected)end,
        "Show the item's description, zone, map position and nearest unlocked wayshrine.")
    S.catalogOpenButton=Button(p,"SurveySidekickCatalogOpen","Open Survey",283,464,185,function()S.OpenMapItem(S.catalogSelected)end,
        "Open ESO's original survey or treasure-map picture. Bank-only items must be withdrawn first.")
end


function S.RenderDetours()
    local entries,reason,zone=S.DetourEntries()
    local count=0;for _,item in ipairs(entries)do count=count+item.count end
    if S.detourButton then
        S.detourButton:SetText(reason and T("Treasure Detour") or T("Treasure Detour: %d maps",count))
    end
    if not S.detourWindow or S.detourWindow:IsHidden() then return end
    S.detourInfo:SetText(reason and T(reason) or T("%s: %d carried treasure maps. Click a map to place its waypoint.",zone,count))
    for i=#entries+1,#S.detourRows do S.detourRows[i]:SetHidden(true)end
    for i,item in ipairs(entries)do
        local row=S.detourRows[i]
        if not row then
            row=WM:CreateControlFromVirtual("SurveySidekickDetourRow"..i,S.detourChild,"ZO_DefaultButton")
            row:SetDimensions(510,40);row:SetAnchor(TOPLEFT,S.detourChild,TOPLEFT,0,(i-1)*46)
            row:SetFont("ZoFontGameSmall")
            row:SetHandler("OnClicked",function(self)S.PinTreasure(self.itemId)end)
            Tooltip(row,"Place this carried treasure map's waypoint. Replaces your current waypoint.")
            S.detourRows[i]=row
        end
        row.itemId=item.id;row:SetText(item.name.." x"..item.count);row:SetHidden(false)
    end
    S.detourEmpty:SetHidden(reason~=nil or #entries>0)
    S.detourChild:SetHeight(math.max(220,#entries*46))
end

function S.ShowDetours()
    S.Scan()
    if not S.detourWindow then
        local root=WM:CreateTopLevelWindow("SurveySidekickDetours")
        root:SetDimensions(580,410);root:SetAnchor(CENTER,GuiRoot,CENTER,0,0)
        root:SetMouseEnabled(true);root:SetMovable(true);root:SetClampedToScreen(true);root:SetDrawTier(DT_HIGH)
        local bg=WM:CreateControl(nil,root,CT_BACKDROP);bg:SetAnchorFill();ThemeSurface(bg,"background",.99)
        Label(root,nil,"Treasure Detour",20,15,420,"ZoFontWinH2")
        Button(root,nil,"Close",460,12,100,function()root:SetHidden(true)end)
        S.detourInfo=Label(root,nil,"",20,60,540)
        local scroll,child=Scroll(root,"SurveySidekickDetourScroll",20,125,540,225)
        S.detourChild=child;S.detourRows={}
        S.detourEmpty=Label(child,nil,"No carried treasure maps for this survey's zone.",0,0,510)
        Label(root,nil,"Backpack only. Same zone does not mean a short walking distance.",20,365,540,"ZoFontGameSmall")
        S.detourWindow=root
    end
    S.detourWindow:SetScale(S.character.scale or .8)
    S.detourWindow:SetHidden(false);S.RenderDetours()
end

function S.UpdateAccountant()
    if not S.accountantWindow then return end
    local history=S.db.history
    if S.accountantA and history[S.accountantA] and S.accountantB and history[S.accountantB] then
        S.accountantText:SetText(S.AccountantText(history[S.accountantA],history[S.accountantB]))
    else S.accountantText:SetText(T("Finish two runs before comparing them."))end
    local _,height=S.accountantText:GetTextDimensions()
    S.accountantChild:SetHeight(math.max(280,height+30))
    S.commentaryButton:SetText(T("Commentary: %s",T(S.character.accountantCommentary==true and "On" or "Off")))
end

function S.ShowAccountant()
    if not S.accountantWindow then
        local root=WM:CreateTopLevelWindow("SurveySidekickAccountant")
        root:SetDimensions(620,570);root:SetAnchor(CENTER,GuiRoot,CENTER,0,0)
        root:SetMouseEnabled(true);root:SetMovable(true);root:SetClampedToScreen(true);root:SetDrawTier(DT_HIGH)
        local bg=WM:CreateControl(nil,root,CT_BACKDROP);bg:SetAnchorFill();ThemeSurface(bg,"background",.99)
        Label(root,nil,"PETTY ACCOUNTANT",20,15,450,"ZoFontWinH2")
        Button(root,nil,"Close",500,12,100,function()root:SetHidden(true)end)
        Label(root,nil,"Run A",20,66,85);Label(root,nil,"Run B",20,118,85)
        S.accountantComboA=Dropdown(root,"SurveySidekickAccountantA",110,62,490)
        S.accountantComboB=Dropdown(root,"SurveySidekickAccountantB",110,114,490)
        local scroll,child=Scroll(root,"SurveySidekickAccountantScroll",20,175,580,310)
        S.accountantChild=child
        S.accountantText=Label(child,nil,"",0,0,540)
        S.commentaryButton=Button(root,nil,"Commentary",20,515,330,function()
            S.character.accountantCommentary=S.character.accountantCommentary~=true
            S.UpdateAccountant()
        end,"Toggle optional Petty Accountant comments. Saved per character.")
        S.accountantWindow=root
    end
    local history=S.db.history
    S.accountantA=history[S.reportIndex or 0] and S.reportIndex or (#history>0 and 1 or nil)
    S.accountantB=nil
    for i=1,#history do if i~=S.accountantA then S.accountantB=i;break end end
    S.accountantComboA:ClearItems();S.accountantComboB:ClearItems()
    S.accountantComboA:SetSelectedItem(T("Choose a run"));S.accountantComboB:SetSelectedItem(T("Choose a run"))
    for i,run in ipairs(history)do
        local index=i
        local name=T("Run %d | %s | %d materials",i,GetDateStringFromTimestamp(run.started),run.total or 0)
        S.accountantComboA:AddItem(S.accountantComboA:CreateItemEntry(name,function()
            S.accountantA=index;S.UpdateAccountant()
        end))
        S.accountantComboB:AddItem(S.accountantComboB:CreateItemEntry(name,function()
            S.accountantB=index;S.UpdateAccountant()
        end))
        if i==S.accountantA then S.accountantComboA:SetSelectedItem(name)end
        if i==S.accountantB then S.accountantComboB:SetSelectedItem(name)end
    end
    if not S.accountantA then S.accountantComboA:SetSelectedItem(T("No saved runs"))end
    if not S.accountantB then S.accountantComboB:SetSelectedItem(T("Choose another run"))end
    S.accountantWindow:SetScale(S.character.scale or .8)
    S.accountantWindow:SetHidden(false);S.UpdateAccountant()
end

function S.ShowExport(text,title)
    if not S.export then
        local root=WM:CreateTopLevelWindow("SurveySidekickExport")
        root:SetDimensions(770,550);root:SetAnchor(CENTER,GuiRoot,CENTER,0,0)
        root:SetMouseEnabled(true);root:SetMovable(true);root:SetClampedToScreen(true);root:SetDrawTier(DT_HIGH)
        local bg=WM:CreateControl(nil,root,CT_BACKDROP);bg:SetAnchorFill();ThemeSurface(bg,"background",.99)
        S.exportTitle=Label(root,nil,"COPY YOUR HOARD",20,15,600,"ZoFontWinH2")
        S.exportInstructions=Label(root,nil,"Click the text, then Ctrl+A and Ctrl+C. Nothing is sent automatically.",20,51,720)
        Button(root,nil,"Close",650,12,100,function()root:SetHidden(true)end)
        local scroll,child=Scroll(root,"SurveySidekickExportScroll",20,90,730,435)
        local edit=WM:CreateControl("SurveySidekickExportText",child,CT_EDITBOX)
        edit:SetAnchor(TOPLEFT,child,TOPLEFT,0,0);edit:SetDimensions(695,1200);edit:SetFont("ZoFontGame")
        Remember(edit,child,0,0,695,nil,"content")
        edit:SetMultiLine(true);edit:SetMaxInputChars(100000);edit:SetMouseEnabled(true)
        edit:SetHandler("OnEscape",function(self)self:LoseFocus()end)
        S.export=root;S.exportText=edit;S.exportChild=child
    end
    local isHelp=title=="Survey Sidekick Help"
    S.exportTitle:SetText(T(title or "COPY YOUR HOARD"))
    S.exportInstructions:SetHidden(isHelp)
    S.exportText:SetEditEnabled(not isHelp)
    S.export:SetDrawLevel(30)
    S.export:SetScale(S.character.scale or 0.8)
    S.export:SetHidden(false);S.exportText:SetText(text)
    local lineCount=1;for _ in text:gmatch("\n") do lineCount=lineCount+1 end
    local height=math.max(420,lineCount*26+120)
    S.exportText:SetHeight(height);S.exportChild:SetHeight(height)
    if isHelp then S.exportText:LoseFocus()else S.exportText:TakeFocus();S.exportText:SelectAll()end
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
    local bg=WM:CreateControl(nil,root,CT_BACKDROP);S.background=bg;bg:SetAnchorFill();ThemeSurface(bg,"background",.97)
    local header=WM:CreateControl(nil,root,CT_BACKDROP);S.header=header;header:SetAnchor(TOPLEFT,root,TOPLEFT,0,0);header:SetDimensions(920,54)
    ThemeSurface(header,"title")
    S.title=Label(root,nil,"SURVEY SIDEKICK",20,12,600,"ZoFontWinH1")
    S.colorsButton=Button(root,"SurveySidekickColors","Colors & Size",0,0,125,S.ShowAppearance,"Appearance: choose background, title bar and border colors, or apply a color preset.")
    S.colorsButton:ClearAnchors();S.colorsButton:SetAnchor(TOPRIGHT,root,TOPRIGHT,-245,12)
    local help=IconButton(root,"SurveySidekickHelp","EsoUI/Art/MenuBar/menuBar_help_up.dds",0,0,30,"Open instructions and slash commands.",function()S.ShowExport(S.Help(),"Survey Sidekick Help")end)
    S.helpButton=help
    help:SetPressedTexture("EsoUI/Art/MenuBar/menuBar_help_down.dds");help:SetMouseOverTexture("EsoUI/Art/MenuBar/menuBar_help_over.dds")
    help:ClearAnchors();help:SetAnchor(TOPRIGHT,root,TOPRIGHT,-104,12)
    S.minimizeButton=IconButton(root,"SurveySidekickMinimize",nil,0,0,30,"Minimize",function()S.SetMinimized(not S.character.minimized)end,"ZO_MinusButton")
    S.minimizeButton:ClearAnchors();S.minimizeButton:SetAnchor(TOPRIGHT,root,TOPRIGHT,-62,12)
    local close=IconButton(root,"SurveySidekickClose",nil,0,0,24,"Close window (/surveys to reopen)",function()S.SetWindowVisible(false)end,"ZO_CloseButton")
    S.closeButton=close
    close:ClearAnchors();close:SetAnchor(TOPRIGHT,root,TOPRIGHT,-20,15)
    S.tabButtons={}
    for i,v in ipairs({{"surveys","Surveys & Maps"},{"run","Current Run"},{"report","The Hoard Report"}}) do
        local tab=v[1];S.tabButtons[i]=Button(root,nil,v[2],20+(i-1)*220,66,210,function()S.tab=tab;S.character.lastTab=tab;S.Render()end)
    end
    S.panels={}
    for _,key in ipairs({"surveys","run","report"}) do
        local panel=WM:CreateControl(nil,root,CT_CONTROL);panel:SetAnchor(TOPLEFT,root,TOPLEFT,20,110);panel:SetDimensions(880,535);S.panels[key]=panel
    end
    local p=S.panels.surveys
    local crafts={"All","Blacksmithing","Clothing","Woodworking","Alchemy","Enchanting","Jewelry","Other"};local craftIndex=1
    for i,craft in ipairs(crafts)do if craft==S.craftFilter then craftIndex=i end end
    S.craftButton=Button(root,"SurveySidekickSurveyType",T("Survey Type: %s",T("All")),690,66,210,function()
        for i,craft in ipairs(crafts)do if craft==S.craftFilter then craftIndex=i;break end end
        craftIndex=craftIndex%#crafts+1;S.craftFilter=crafts[craftIndex]
        S.craftButton:SetText(T("Survey Type: %s",T(S.craftFilter)))
        S.tab="surveys";S.Render()
    end,"Survey Type: click to cycle through crafting types. All shows every survey in your backpack.")
    S.craftButton:SetFont("ZoFontGameSmall")
    S.CreateCatalogPanel(p)
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
        S.ShowExport(T("THE HOARD REPORT: %d materials in %s | Regular-sized %d | Survey/Large %d | Other %d. My survey pile has filed a complaint.",r.total,S.Time(r.seconds),b.regular,b.survey,b.other))
    end)
    Button(p,nil,"Export Details",485,0,180,function()S.ShowExport(S.Report(S.db.history[S.reportIndex],true))end)
    Button(p,"SurveySidekickCompare","Compare Runs",680,0,190,S.ShowAccountant,"Compare two saved runs by materials, time and estimated value.")
    S.reportInfo=Label(p,nil,"",0,45,870)
    local scroll3,child3=Scroll(p,"SurveySidekickReportScroll",0,85,875,435)
    S.reportText=Label(child3,nil,"",0,0,835);S.reportChild=child3
    S.status=Label(root,nil,"",20,658,875)
    S.compactSelected=Label(root,"SurveySidekickCompactSelected","",20,56,520,"ZoFontGameSmall")
    S.compactSelected:SetMaxLineCount(1)
    S.compactStatus=Label(root,"SurveySidekickCompactStatus","",20,84,520,"ZoFontGameSmall")
    S.ApplyWindowMode();S.RestoreWindowPosition()
    S.SetWindowVisible(S.character.windowVisible~=false)
end
function S.RenderSurveys()S.RenderCatalog()end
local function FitText(label,child,text)
    label:SetText(T(text));local _,height=label:GetTextDimensions();child:SetHeight(math.max(240,height+30))
end
function S.RenderRun()
    local r=S.character.run
    if not r then
        S.runSummary:SetText(T("Your next hoard is waiting."));S.breakdownInfo:SetText(T("Start/Resume, gather, then Finish Run. The loot split is automatic."))
        S.goalInfo:SetText(T("Goals track materials collected during the current run."))
        FitText(S.runText,S.runChild,"All crafting materials looted while the run is active count.\n\nYour material totals update automatically while the run is active.\n\nChoose a survey type, a material name and a quantity above to set a goal.");return
    end
    S.runSummary:SetText(T("%s | %s | %d materials",T(r.running and "RUNNING" or "PAUSED"),S.Time(r.seconds),r.total))
    local b=r.breakdown or {regular=0,survey=0,other=r.total}
    S.breakdownInfo:SetText(T("Regular-sized: %d | Survey/Large: %d | Other: %d",b.regular,b.survey,b.other)..((r.pending or 0)>0 and T(" | Checking runes: %d",r.pending) or ""))
    local current,target=S.Model.GoalProgress(r)
    S.goalInfo:SetText(target>0 and T("Goal: %s %d / %d",S.MaterialName({id=r.goal.id,name=r.goal.name}),current,target) or T("No material goal set."))
    local rows={};local sorted={};for _,v in pairs(r.materials)do sorted[#sorted+1]=v end
    table.sort(sorted,function(a,b)return a.count>b.count end)
    for _,v in ipairs(sorted)do rows[#rows+1]=T("%s x%d | Regular %d / Survey-Large %d / Other %d",S.MaterialName(v),v.count,v.regular or 0,v.survey or 0,v.other or v.count)end
    local value,missing=S.Value(r.materials);table.insert(rows,1,T("Estimated value: %.0fg | %d unpriced items",value,missing))
    if #sorted==0 then rows[#rows+1]=T("Pick up some materials to start filling your hoard.")end
    FitText(S.runText,S.runChild,table.concat(rows,"\n"))
end
function S.RenderReport()
    local r=S.db.history[S.reportIndex]
    S.reportInfo:SetText(r and T("Run %d of %d | %s | Last 30 runs saved",S.reportIndex,#S.db.history,GetDateStringFromTimestamp(r.started)) or T("Finish a run to create your first report."))
    FitText(S.reportText,S.reportChild,S.Report(r))
end
function S.Render()
    if not S.ui or S.ui:IsHidden() then S.dirty=true;return end
    S.dirty=false
    local minimized=S.character.minimized==true
    for key,panel in pairs(S.panels)do panel:SetHidden(minimized or key~=S.tab)end
    S.character.lastTab=S.tab
    local r=S.character.run
    local selected=S.CurrentCatalogItem()
    S.compactSelected:SetText(selected and selected.name or T("Select a survey or treasure map to view its details."))
    S.craftButton:SetText(T("Survey Type: %s",T(S.craftFilter)))
    S.craftButton:SetHidden(minimized or S.tab~="surveys" or S.catalogKind=="treasure")
    S.compactStatus:SetText(r and T("%s | %s | %d materials",T(r.running and "RUNNING" or "PAUSED"),S.Time(r.seconds),r.total) or T("Ready for your next hoard."))
    if minimized then return end
    if S.tab=="surveys" then S.RenderSurveys()elseif S.tab=="run" then S.RenderRun()else S.RenderReport()end
    S.status:SetText(T("v%s | Maps: %s | Prices: %s | /surveys help",S.version,LibTreasure_GetAllItemsData and "LibTreasure" or T("install LibTreasure"),TamrielTradeCentrePrice and T("TTC/manual") or T("manual/unpriced")))
end

function S.LayoutJournalUtility(window,enabled)
    local size=utilitySizes[window]
    if not size then
        if window==S.appearanceWindow then size={520,535}
        elseif window==S.detourWindow then size={580,410}
        elseif window==S.accountantWindow then size={620,570}
        else size={770,550}end
        utilitySizes[window]=size
    end
    local dw,dh=enabled and 920-size[1] or 0,enabled and 700-size[2] or 0
    window:SetDimensions(size[1]+dw,size[2]+dh)
    for _,entry in ipairs(utilityLayout)do
        local owner=entry.parent
        while owner and owner~=window do owner=layoutParents[owner]end
        if owner==window then
            local c,x,y,w=entry.control,entry.x,entry.y,entry.width
            if entry.kind=="slidertrack" then
                c:SetDimensions(w+dw,6)
            elseif entry.kind=="scrollChild" or entry.kind=="content" then
                c:SetWidth(w+dw)
            else
                if entry.parent==window and x>size[1]*.6 then x=x+dw end
                if entry.parent==window and y>=size[2]-130 then y=y+dh end
                if entry.kind=="scroll" or entry.kind=="dropdown" or entry.kind=="slider"
                    or (entry.kind=="label" and w>=250) then w=w+dw end
                c:ClearAnchors();c:SetAnchor(TOPLEFT,entry.parent,TOPLEFT,x,y)
                if entry.height then c:SetDimensions(w,entry.height+(entry.kind=="scroll" and dh or 0))else c:SetWidth(w)end
                if entry.kind=="close" then c:SetText(T(enabled and "Back" or "Close"))end
            end
        end
    end
    if window==S.accountantWindow then
        local _,height=S.accountantText:GetTextDimensions();S.accountantChild:SetHeight(math.max(280,height+30))
    elseif window==S.export then
        local height=math.max(600,S.exportText:GetHeight());S.exportText:SetHeight(height);S.exportChild:SetHeight(height)
    end
end
