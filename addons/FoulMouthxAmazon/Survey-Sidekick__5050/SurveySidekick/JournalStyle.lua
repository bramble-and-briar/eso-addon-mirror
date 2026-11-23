-- Journal-only presentation. Uses ESO textures and the existing manager actions.
local S=SurveySidekick
local T=S.Text
local WM=WINDOW_MANAGER
local GetItemLinkIcon=GetItemLinkIcon
local InitializeTooltip,SetTooltipText,ClearTooltip=InitializeTooltip,SetTooltipText,ClearTooltip
local InformationTooltip=InformationTooltip
local ipairs,pairs,math,table=ipairs,pairs,math,table
local TOPLEFT,CT_LABEL,CT_TEXTURE,CT_BACKDROP,CT_CONTROL=TOPLEFT,CT_LABEL,CT_TEXTURE,CT_BACKDROP,CT_CONTROL
local active=false
local toolbar,tables
local function Anchor(control,parent,x,y,w,h)
    control:ClearAnchors();control:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y)
    control:SetDimensions(w,h)
end
local function Label(parent,text,x,y,width,header)
    local c=WM:CreateControl(nil,parent,CT_LABEL)
    Anchor(c,parent,x,y,width,28);c:SetFont(header and "ZoFontGameBold" or "ZoFontGame")
    c:SetColor(header and .77 or .85,header and .75 or .85,header and .58 or .85,1)
    c:SetMaxLineCount(1);c:SetText(T(text or ""));return c
end
local function Stripe(parent,index,width)
    local bg=WM:CreateControl(nil,parent,CT_BACKDROP)
    bg:SetAnchorFill();bg:SetCenterColor(.08,.09,.12,index%2==0 and .44 or .12)
    bg:SetEdgeColor(0,0,0,0);return bg
end
local function Textures(button,prefix)
    button:SetNormalTexture(prefix.."up.dds")
    button:SetPressedTexture(prefix.."down.dds")
    button:SetMouseOverTexture(prefix.."over.dds")
end
local icons={
    ["Start / Resume"]="SurveySidekick/textures/play_",
    ["Pause"]="SurveySidekick/textures/pause_",
    ["Finish Run"]="SurveySidekick/textures/stop_",
    ["Newer"]="EsoUI/Art/Buttons/large_leftarrow_",
    ["Older"]="EsoUI/Art/Buttons/large_rightarrow_",
    ["Copy Summary"]="EsoUI/Art/Buttons/edit_",
    ["Export Details"]="EsoUI/Art/MainMenu/menuBar_inventory_",
    ["Compare Runs"]="EsoUI/Art/MainMenu/menuBar_character_",
    ["Set Goal"]="EsoUI/Art/MainMenu/menuBar_journal_",
    ["Hint"]="EsoUI/Art/MenuBar/menuBar_help_",
    ["Open Survey"]="EsoUI/Art/MainMenu/menuBar_map_",
    ["Treasure Detour"]="EsoUI/Art/MainMenu/menuBar_map_",
}
local function MakeToolbar()
    toolbar={}
    local tabs={{"surveys","Surveys & Maps","map"},{"run","Current Run","inventory"},{"report","The Hoard Report","journal"}}
    for i,entry in ipairs(tabs)do
        local key,title,prefix=entry[1],entry[2],"EsoUI/Art/MainMenu/menuBar_"..entry[3].."_"
        local b=WM:CreateControlFromVirtual(nil,S.canvas,"ZO_ButtonBehaviorClickSound")
        Anchor(b,S.canvas,20+(i-1)*60,6,40,40);Textures(b,prefix)
        b:SetMouseEnabled(true)
        b:SetHandler("OnClicked",function()S.tab=key;S.character.lastTab=key;S.Render()end)
        b:SetHandler("OnMouseEnter",function(self)
            InitializeTooltip(InformationTooltip,self,TOP,0,-6,BOTTOM);SetTooltipText(InformationTooltip,T(title))
        end)
        b:SetHandler("OnMouseExit",function()ClearTooltip(InformationTooltip)end)
        b:SetHandler("OnEffectivelyHidden",function()ClearTooltip(InformationTooltip)end)
        toolbar[#toolbar+1]={button=b,key=key,prefix=prefix}
    end
    toolbar.caption=Label(S.canvas,"",220,12,360,true)
    for i,entry in ipairs({{"Open instructions and slash commands.","EsoUI/Art/MenuBar/menuBar_help_",function()S.ShowExport(S.Help(),"Survey Sidekick Help")end}})do
        local title,prefix,callback=entry[1],entry[2],entry[3]
        local b=WM:CreateControlFromVirtual(nil,S.canvas,"ZO_ButtonBehaviorClickSound")
        Anchor(b,S.canvas,590+(i-1)*44,6,34,34);Textures(b,prefix);b:SetMouseEnabled(true)
        b:SetHandler("OnClicked",callback)
        b:SetHandler("OnMouseEnter",function(self)InitializeTooltip(InformationTooltip,self,TOP,0,-6,BOTTOM);SetTooltipText(InformationTooltip,T(title))end)
        b:SetHandler("OnMouseExit",function()ClearTooltip(InformationTooltip)end)
        b:SetHandler("OnEffectivelyHidden",function()ClearTooltip(InformationTooltip)end)
        toolbar[#toolbar+1]={button=b,prefix=prefix}
    end
    toolbar.footer=Label(S.canvas,"",20,658,875)
    toolbar.footer:SetFont("ZoFontGameSmall")
end
local function Row(parent,index)
    local row=WM:CreateControl(nil,parent,CT_CONTROL)
    Anchor(row,parent,0,0,835,30);row.bg=Stripe(row,index,835)
    row.icon=WM:CreateControl(nil,row,CT_TEXTURE);Anchor(row.icon,row,4,2,26,26)
    row.name=Label(row,"",38,0,405)
    row.qty=Label(row,"",450,0,82)
    row.regular=Label(row,"",540,0,90)
    row.survey=Label(row,"",640,0,90)
    row.other=Label(row,"",740,0,90)
    return row
end
local function MaterialTable(key,parent,run)
    tables=tables or {}
    local view=tables[key]
    if not view then
        view={rows={},root=WM:CreateControl(nil,parent,CT_CONTROL)};tables[key]=view
        Anchor(view.root,parent,0,0,835,100)
        view.summary=Label(view.root,"",0,0,835,true)
        view.value=Label(view.root,"",0,28,835)
        for _,v in ipairs({{"Material",38,405},{"Quantity",450,82},{"Regular",540,90},{"Survey/Large",640,95},{"Other",740,90}})do
            Label(view.root,v[1],v[2],66,v[3],true)
        end
    end
    view.root:SetHidden(not active)
    local sorted={}
    if run then for _,item in pairs(run.materials)do sorted[#sorted+1]=item end end
    table.sort(sorted,function(a,b)
        if a.count==b.count then return S.MaterialName(a)<S.MaterialName(b)end
        return a.count>b.count
    end)
    local value,unpriced=0,0
    if run then value,unpriced=S.Value(run.materials)end
    view.summary:SetText(run and T("Materials looted: %d | Active time: %s",run.total,S.Time(run.seconds)) or T("Your next hoard is waiting."))
    view.value:SetText(run and T("Estimated value: %.0fg | Unpriced items: %d (not included)",value,unpriced) or T("Start/Resume, gather, then Finish Run. The loot split is automatic."))
    for i,item in ipairs(sorted)do
        local row=view.rows[i] or Row(view.root,i);view.rows[i]=row
        Anchor(row,view.root,0,98+(i-1)*32,835,30);row:SetHidden(false)
        row.icon:SetTexture(GetItemLinkIcon(item.link or S.Link(item.id)))
        row.name:SetText(S.MaterialName(item));row.qty:SetText(tostring(item.count))
        row.regular:SetText(tostring(item.regular or 0));row.survey:SetText(tostring(item.survey or 0))
        row.other:SetText(tostring(item.other or item.count))
    end
    for i=#sorted+1,#view.rows do view.rows[i]:SetHidden(true)end
    local loot=S.SortedLoot(run)
    view.lootRows=view.lootRows or {}
    if #loot>0 then
        if not view.lootHeading then view.lootHeading=Label(view.root,"OTHER LOOT",0,0,835,true)end
        Anchor(view.lootHeading,view.root,0,110+#sorted*32,835,28);view.lootHeading:SetHidden(false)
        local value,missing=S.Value(run.loot)
        view.lootHeading:SetText(T("OTHER LOOT").."    "..T("Estimated value: %.0fg | Unpriced items: %d (not included)",value,missing))
    elseif view.lootHeading then view.lootHeading:SetHidden(true)end
    for i,item in ipairs(loot)do
        local row=view.lootRows[i] or Row(view.root,i);view.lootRows[i]=row
        Anchor(row,view.root,0,148+#sorted*32+(i-1)*32,835,30);row:SetHidden(false)
        row.icon:SetTexture(GetItemLinkIcon(item.link or S.Link(item.id)))
        row.name:SetText(S.MaterialName(item));row.qty:SetText(tostring(item.count))
        row.regular:SetText("");row.survey:SetText("");row.other:SetText("")
    end
    for i=#loot+1,#view.lootRows do view.lootRows[i]:SetHidden(true)end
    local height=math.max(200,100+#sorted*32+(#loot>0 and 50+#loot*32 or 0))
    view.root:SetHeight(height);parent:SetHeight(height)
end
local function InventoryRows()
    local items={};for _,item in ipairs(S.InventoryEntries("all","both"))do items[item.id]=item end
    for i,row in ipairs(S.catalogRows)do
        local item=items[row.itemId]
        if active and item then
            if not row.journal then
                local style={};row.journal=style
                style.bg=Stripe(row,i,813)
                style.icon=WM:CreateControl(nil,row,CT_TEXTURE);Anchor(style.icon,row,4,5,28,28)
                style.name=Label(row,"",40,5,530)
                style.backpack=Label(row,"",590,5,100)
                style.bank=Label(row,"",708,5,100)
            end
            local style=row.journal;row:SetText("")
            row:SetNormalTexture("");row:SetPressedTexture("");row:SetMouseOverTexture("")
            style.bg:SetCenterColor(S.catalogSelected==item.id and .28 or .08,.24,.20,S.catalogSelected==item.id and .5 or (i%2==0 and .3 or .08))
            style.icon:SetTexture(GetItemLinkIcon(item.link or S.Link(item.id)))
            style.name:SetText(item.name);style.backpack:SetText(tostring(item.backpack));style.bank:SetText(tostring(item.bank))
        end
        if row.journal then for _,c in pairs(row.journal)do c:SetHidden(not active)end end
    end
    for _,row in ipairs(S.zoneRows)do
        if active then
            if not row.journalLabel then row.journalLabel=Label(row,"",8,3,820,true)end
            row.journalLabel:SetText(row.zoneCaption or "")
            row:SetText("")
            row:SetNormalTexture("");row:SetPressedTexture("");row:SetMouseOverTexture("")
        end
        if row.journalLabel then row.journalLabel:SetHidden(not active)end
    end
end

function S.ApplyJournalStyle(value)
    active=value==true
    if active and not toolbar then MakeToolbar()end
    for _,control in ipairs({S.background,S.header,S.title,S.colorsButton,S.helpButton,S.closeButton,S.status})do control:SetHidden(active)end
    for _,button in ipairs(S.tabButtons)do button:SetHidden(active or S.character.minimized==true)end
    for _,panel in pairs(S.panels)do Anchor(panel,S.canvas,20,active and 58 or 110,880,535)end
    S.craftButton:ClearAnchors();S.craftButton:SetAnchor(TOPLEFT,S.canvas,TOPLEFT,690,active and 8 or 66)
    Anchor(S.catalogScroll,S.panels.surveys,0,active and 110 or 90,875,active and 260 or 280)
    if active and not S.journalInventoryColumns then
        S.journalInventoryColumns={Label(S.panels.surveys,"Material",62,72,530,true),
            Label(S.panels.surveys,"Backpack",612,72,100,true),Label(S.panels.surveys,"Bank",730,72,100,true)}
    end
    for _,column in ipairs(S.journalInventoryColumns or {})do column:SetHidden(not active)end
    if toolbar then
        for _,entry in ipairs(toolbar)do
            entry.button:SetHidden(not active)
            entry.button:SetNormalTexture(entry.prefix..(S.tab==entry.key and "down.dds" or "up.dds"))
            entry.button:SetAlpha(1)
        end
        toolbar.caption:SetHidden(not active)
        toolbar.caption:SetText(T(({surveys="Surveys & Maps",run="Current Run",report="The Hoard Report"})[S.tab] or "Surveys & Maps"))
        toolbar.footer:SetHidden(not active)
        toolbar.footer:SetText(T(S.tab=="surveys" and "Click a zone to expand its surveys and treasure maps." or "Survey/Large and gold values are estimates. Unpriced items are excluded."))
    end
    local reportIndex=0
    for _,entry in ipairs(S.journalActions or {})do
        local button=entry.control
        local panel=entry.parent==S.panels.run or entry.parent==S.panels.report or entry.parent==S.panels.surveys
        if panel then
            if active and icons[entry.text] then
                local x,y=entry.x,entry.y
                local transport=({["Start / Resume"]=0,["Pause"]=64,["Finish Run"]=128})[entry.text]
                if transport then x=transport end
                if entry.parent==S.panels.report then x=reportIndex*64;reportIndex=reportIndex+1 end
                Anchor(button,entry.parent,x,y,44,44);button:SetText("");Textures(button,icons[entry.text]);entry.skinned=true
            elseif entry.skinned then
                Anchor(button,entry.parent,entry.x,entry.y,entry.width,30);button:SetText(T(entry.text))
                button:SetNormalTexture("");button:SetPressedTexture("");button:SetMouseOverTexture("");entry.skinned=false
            end
        end
    end
    if active then
        -- Give the five item actions equal cells; allow for each texture's padding.
        local index=0
        for _,entry in ipairs({{S.mapButton,48},{S.travelButton,56},{S.previewButton,40},
            {S.catalogHintButton,48},{S.catalogOpenButton,48}})do
            local button,size=entry[1],entry[2]
            if not button:IsHidden() then
                Anchor(button,S.panels.surveys,index*68+(56-size)/2,464+(56-size)/2,size,size)
                index=index+1
            end
        end
    else
        S.mapButton:SetDimensions(40,40);S.travelButton:SetDimensions(40,40);S.previewButton:SetDimensions(40,40)
    end
    S.runText:SetHidden(active);S.reportText:SetHidden(active)
    if not active and tables then for _,v in pairs(tables)do v.root:SetHidden(true)end end
    InventoryRows()
    if active and S.tab=="run" then MaterialTable("run",S.runChild,S.character.run)
    elseif active and S.tab=="report" then MaterialTable("report",S.reportChild,S.db.history[S.reportIndex])end
end

-- These actions can refresh a panel directly (zone toggle and report arrows).
local renderCatalog,renderRun,renderReport=S.RenderCatalog,S.RenderRun,S.RenderReport
S.RenderCatalog=function()renderCatalog();if active then S.ApplyJournalStyle(true)end end
S.RenderRun=function()renderRun();if active then S.ApplyJournalStyle(true)end end
S.RenderReport=function()renderReport();if active then S.ApplyJournalStyle(true)end end
