-- Tamriel Collections - Furnishing Plans v0.1.5
local TC = TamrielCollections
local ID, TEMPLATE = 'furnishingPlans', 'ZO_QuestJournal_Gamepad_MenuEntryTemplate'
local ICON = 'EsoUI/Art/Crafting/provisioner_indexIcon_furnishings_up.dds'
local function Text(v) return zo_strformat and zo_strformat(v or '') or tostring(v or '') end
local function Key(v)
    return (zo_strlower or string.lower)(Text(v)):gsub('’', "'"):gsub('|c%x%x%x%x%x%x',''):gsub('|r','')
        :gsub('%^.*$',''):gsub('[%p%c]+',' '):gsub('%s+',' '):gsub('^%s+',''):gsub('%s+$','')
end
local styles = {
    'Worm Cult', 'Stone-Nest', 'Tide-Born', 'Sunport', 'Fabricant', 'Mirrormoor', 'Common',
    'Ancient Orc', 'Ancestral Nord', 'Dark Brotherhood', 'Dark Elf', 'High Elf', 'High Isle',
    'Wood Elf', 'Old Orsinium', 'Order of the Hour', 'Psijic', 'Alinor', 'Ayleid', 'Argonian',
    'Ashlander', 'Akaviri', 'Apocrypha', 'Breton', 'Clockwork', 'Colovian', 'Daedric',
    'Darklight', 'Dawnwood', 'Deadlands', 'Dres', 'Druidic', 'Dwarven', 'Dwemer', 'Elsweyr',
    'Fargrave', 'Falmer', 'Galen', 'Hakoshae', 'Hlaalu', 'Imperial', 'Indoril', 'Khajiit',
    'Leyawiin', 'Necrom', 'Nord', 'Orcish', 'Reach', 'Redguard', 'Redoran', 'Solitude',
    'Solstice', 'Telvanni', 'Vampiric', 'Vvardenfell', 'Witch', 'Winterhold', 'Yokudan',
}
local styleKeys = {}
for _, name in ipairs(styles) do styleKeys[#styleKeys+1] = { name = name, key = Key(name) } end
local function Family(name, theme, category)
    local key = Key(name)
    for _, style in ipairs(styleKeys) do
        if key == style.key or key:sub(1,#style.key+1) == style.key..' ' then return style.name end
    end
    if key:find('^target ') then return 'Training Dummies' end
    for _, pair in ipairs({{'ARGONIAN','Argonian'},{'AYLEID','Ayleid'},{'BRETON','Breton'},
        {'CLOCKWORK','Clockwork'},{'DAEDRIC','Daedric'},{'DARK_ELF','Dark Elf'},
        {'DWARVEN','Dwarven'},{'HIGH_ELF','High Elf'},{'IMPERIAL','Imperial'},
        {'KHAJIIT','Khajiit'},{'NORD','Nord'},{'ORC','Orcish'},{'REDGUARD','Redguard'},
        {'VAMPIRIC','Vampiric'},{'WOOD_ELF','Wood Elf'}}) do
        local value = _G['FURNITURE_THEME_TYPE_'..pair[1]]
        if value and theme == value then return pair[2] end
    end
    return 'General - '..(category and category ~= '' and category or 'Decorations')
end
local model, building, generation, waiting = nil, false, 0, {}
local Render, Install
local function Visible(screen)
    return not screen._tcfHidden and (not SCENE_MANAGER or not SCENE_MANAGER.IsShowing
        or SCENE_MANAGER:IsShowing('tamrielCollectionsGamepad'))
end
local function Wants(screen)
    if screen.activeModuleId == ID then return true end
    local selected = screen.mode == 'categories' and screen.categoryList and screen.categoryList:GetTargetData()
    return selected and selected.categoryKey == ID
end
local function Source(plan) return TC.furnishingPlanData and TC.furnishingPlanData[plan.resultId] end
local function InZone(plan, zone)
    if not zone then return true end
    local data = Source(plan)
    return data and data.zones and data.zones[zone] == true or false
end
local function NewPlan(li, ri, listName)
    local known, name, _, _, quality, special, station, resultId = GetRecipeInfo(li,ri)
    if not name or name == '' then return end
    if resultId and resultId <= 0 then resultId = nil end
    if not PROVISIONER_SPECIAL_INGREDIENT_TYPE_FURNISHING
        or special ~= PROVISIONER_SPECIAL_INGREDIENT_TYPE_FURNISHING then return end
    local data, theme, categoryName = nil, nil, nil
    local family = data and data.family or Family(name, theme, categoryName or listName)
    local displayName = data and data.planName or Text(name)
    return { name=displayName, nameKey=Key(displayName), known=known==true, resultId=resultId,
        listIndex=li, recipeIndex=ri, key=tostring(li)..':'..tostring(ri),
        station=station, quality=quality, familyName=family }
end
local function Request(screen)
    waiting[screen] = true
    if building then return end
    building = true
    local token = generation
    local result = { families={}, byKey={}, known=0, total=0, seen={} }
    local li, ri, count, listName = 1,1,0,''
    local lists
    if not zo_callLater then building=false;waiting={};return end
    local function Finish()
        table.sort(result.families,function(a,b)
            local am,bm=a.total-a.known,b.total-b.known
            if (am==0)~=(bm==0) then return am>0 end
            if am~=bm then return am<bm end
            return a.key<b.key
        end)
        for _, family in ipairs(result.families) do
            table.sort(family.plans,function(a,b)
                if a.known~=b.known then return not a.known end
                if a.nameKey~=b.nameKey then return a.nameKey<b.nameKey end
                return a.key<b.key
            end)
        end
        result.seen=nil
        model,building=result,false
        local callbacks=waiting;waiting={}
        for owner in pairs(callbacks) do if Visible(owner) and Wants(owner) then Render(owner) end end
    end
    local function Step()
        if token~=generation then return end
        if not Visible(screen) or screen.activeModuleId~=ID then building=false;waiting={};return end
        if not lists then lists=GetNumRecipeLists and GetNumRecipeLists() or 0 end
        local started=GetGameTimeMilliseconds and GetGameTimeMilliseconds()
        -- Use more of the existing one-millisecond budget before yielding.
        -- Retain the conservative cap when no clock is available.
        local maximum = started and 32 or 8
        for unit=1,maximum do
            if li>lists then Finish();return end
            if ri==1 then listName,count=GetRecipeListInfo(li);count=count or 0 end
            if ri<=count then
                local plan=NewPlan(li,ri,listName)
                if plan and not result.seen[plan.key] then
                    result.seen[plan.key]=true
                    local key=Key(plan.familyName)
                    local family=result.byKey[key]
                    if not family then
                        family={name=plan.familyName,key=key,plans={},known=0,total=0}
                        result.byKey[key]=family;result.families[#result.families+1]=family
                    end
                    family.plans[#family.plans+1]=plan
                    family.total=family.total+1;result.total=result.total+1
                    if plan.known then family.known=family.known+1;result.known=result.known+1 end
                end
                ri=ri+1
            else li,ri=li+1,1 end
            if started and GetGameTimeMilliseconds()-started>=1 then break end
        end
        if zo_callLater then zo_callLater(Step,0) else Step() end
    end
    if zo_callLater then zo_callLater(Step,0) else Step() end
end
local function Layout(screen)
    screen:SetMotifContentVisible(true)
    screen.middle:SetHidden(false);screen.right:SetHidden(false)
    screen.detailIcon:SetHidden(true)
    if screen.rightText then screen.rightText:SetHidden(true) end
    for _,name in ipairs({'detailControl','detailHeading','detailAcquisition','detailWhereTitle',
        'detailLocation','detailSource','detailAchievement'}) do screen[name]:SetHidden(false) end
    local parent=screen.rightContent or screen.detailBottomLine:GetParent()
    screen.detailBottomLine:ClearAnchors()
    screen.detailBottomLine:SetAnchor(BOTTOMLEFT,parent,BOTTOMLEFT,0,-285)
    screen.detailBottomLine:SetAnchor(BOTTOMRIGHT,parent,BOTTOMRIGHT,0,-285)
    screen.detailSource:SetFont('ZoFontGamepad22')
    screen.detailSource:SetHeight(88);screen.detailSource:SetMaxLineCount(5)
    screen.detailAchievement:SetFont('ZoFontGamepad20');screen.detailAchievement:SetHeight(58)
    screen.detailAchievement:SetMaxLineCount(3)
end
local function PlanInfo(screen,plan)
    local station=plan and GetCraftingSkillName and Text(GetCraftingSkillName(plan.station)) or ''
    screen.detailAcquisition:SetText(plan and ((plan.known and '|c66CC66Learned|r' or '|cE57373Not learned|r')
        ..(station~='' and (' - '..station) or '')) or '')
    screen.detailWhereTitle:SetText(plan and 'Where to obtain:' or '')
    local source=plan and Source(plan)
    source=source and source.byZone and source.byZone[screen._tcfZone] or source
    screen.detailLocation:SetText(source and source.location or (plan and 'Source not yet verified' or ''))
    screen.detailSource:SetText(source and source.description or (plan and
        'Acquisition details have not been verified for this plan yet.' or ''))
    screen.detailAchievement:SetText('')
end
local function SelectedPlan(screen)
    local data=screen.detailList:GetTargetData();return data and data.furnishingPlan
end
local function ShowFamily(screen,data)
    if screen._tcfRendering then return end
    local row=data and data.furnishingFamily
    screen._tcfRendering=true
    screen.detailList:Clear()
    if row then
        screen._tcfFamilyKey=row.family.key
        screen.detailHeading:SetText(string.format('|cFFEBB3%s (%d/%d)|r',row.family.name,row.known,row.total))
        for _,plan in ipairs(row.plans) do
            local label=plan.name..'  -  '..(plan.known and '|c66CC66Learned|r' or '|cE57373Not learned|r')
            local entry=ZO_GamepadEntryData:New(label)
            entry.furnishingPlan,entry.isKnown=plan,plan.known
            screen.detailList:AddEntry(TEMPLATE,entry)
        end
    else
        screen.detailHeading:SetText('|cFFEBB3Furnishing Plans|r')
    end
    screen.detailList:Commit()
    if row and #row.plans>0 then
        local wanted=1
        for i,plan in ipairs(row.plans) do if plan.key==screen._tcfPlanKey then wanted=i;break end end
        screen.detailList:SetSelectedIndex(wanted)
    end
    screen._tcfRendering=false
    PlanInfo(screen,SelectedPlan(screen))
    if not row then
        screen.detailSource:SetText(model and (screen._tcfZone and
            'No matching plans with a recorded source in this location. All locations also includes unverified sources.' or
            'No missing plans match this view. Press L3 to show all.') or 'Preparing furnishing plans...')
    end
end
Render=function(screen)
    Layout(screen)
    if not model then
        screen._tcfRendering=true
        screen.styleList:Clear();screen.styleList:Commit()
        screen._tcfRendering=false
        ShowFamily(screen)
        Request(screen)
        screen:RefreshKeybinds();return
    end
    local rows={}
    local query=screen._tcfQuery or ''
    for _,family in ipairs(model.families) do
        local row={family=family,plans={},known=0,total=0}
        local familyMatch=query=='' or Key(family.name):find(query,1,true)
        for _,plan in ipairs(family.plans) do
            if InZone(plan,screen._tcfZone) then
                row.total=row.total+1
                if plan.known then row.known=row.known+1 end
                if (screen._tcfShowAll or not plan.known) and (familyMatch or plan.nameKey:find(query,1,true)) then
                    row.plans[#row.plans+1]=plan
                end
            end
        end
        if #row.plans>0 then rows[#rows+1]=row end
    end
    table.sort(rows,function(a,b)
        local am,bm=a.total-a.known,b.total-b.known
        if (am==0)~=(bm==0) then return am>0 end
        if am~=bm then return am<bm end
        return a.family.key<b.family.key
    end)
    screen._tcfRendering=true
    screen.styleList:Clear()
    local selected=1
    for i,row in ipairs(rows) do
        local entry=ZO_GamepadEntryData:New(string.format('%s (%d/%d)',row.family.name,row.known,row.total))
        entry.furnishingFamily=row
        screen.styleList:AddEntry(TEMPLATE,entry)
        if row.family.key==screen._tcfFamilyKey then selected=i end
    end
    screen.styleList:Commit()
    if #rows>0 then screen.styleList:SetSelectedIndex(selected) end
    screen._tcfRendering=false
    ShowFamily(screen,screen.styleList:GetTargetData())
    if screen.mode=='categories' then
        for _,name in ipairs({'detailControl','detailHeading','detailAcquisition','detailWhereTitle',
            'detailLocation','detailSource','detailAchievement'}) do screen[name]:SetHidden(true) end
        screen.detailIcon:SetTexture(ICON);screen.detailIcon:SetHidden(false)
    end
    screen:RefreshKeybinds()
end
local function ApplyZone(screen,zone)
    if screen.activeModuleId~=ID then return end
    screen._tcfZone=zone
    screen.mode='styles';screen:SetCurrentList(screen.styleList)
    Render(screen)
end
local function ChooseZone(screen)
    if not (ZO_Dialogs_RegisterCustomDialog and ZO_Dialogs_ShowGamepadDialog and GAMEPAD_DIALOGS) then return end
    local name='TCF_FURNISHING_LOCATION'
    if not TC._tcfZoneDialog then
        TC._tcfZoneDialog=true
        ZO_Dialogs_RegisterCustomDialog(name,{
            gamepadInfo={dialogType=GAMEPAD_DIALOGS.PARAMETRIC},title={text='Location'},parametricList={},
            setup=function(dialog,data)
                local rows,selected={},1
                local zones={{name='All locations'}}
                for key,label in pairs(TC.furnishingPlanZones or {}) do zones[#zones+1]={key=key,name=label} end
                table.sort(zones,function(a,b)
                    if not a.key then return b.key~=nil end
                    if not b.key then return false end
                    return a.name<b.name
                end)
                for i,zone in ipairs(zones) do
                    local entry=ZO_GamepadEntryData:New(zone.name)
                    entry.zoneKey=zone.key;entry.setup=ZO_SharedGamepadEntry_OnSetup
                    rows[#rows+1]={template='ZO_GamepadMenuEntryTemplate',entryData=entry}
                    if zone.key==data.screen._tcfZone then selected=i end
                end
                dialog.info.parametricList=rows;dialog:setupFunc();dialog.entryList:SetSelectedIndex(selected)
            end,
            buttons={{keybind='DIALOG_PRIMARY',text='Select',callback=function(dialog)
                local data=dialog.entryList:GetTargetData()
                if data then ApplyZone(dialog.data.screen,data.zoneKey) end
            end},{keybind='DIALOG_NEGATIVE',text='Cancel'}},
        })
    end
    ZO_Dialogs_ShowGamepadDialog(name,{screen=screen})
end
Install=function(screen)
    if screen._tcfInstalled then return end
    screen._tcfInstalled=true
    local originalShow=screen.ShowStyle
    screen.ShowStyle=function(self,data)
        if self.activeModuleId==ID then ShowFamily(self,data) else return originalShow(self,data) end
    end
    local originalSearch=screen.OnMotifSearchTextChanged
    screen.OnMotifSearchTextChanged=function(self,value)
        if self.activeModuleId~=ID then if originalSearch then return originalSearch(self,value) end;return end
        if self._tcfChangingSearch then return end
        self._tcfQuery=Key(value);Render(self)
    end
    local originalShowing,originalHiding=screen.OnShowing,screen.OnHiding
    screen.OnShowing=function(self,...)
        self._tcfHidden=nil
        if originalShowing then return originalShowing(self,...) end
    end
    screen.OnHiding=function(self,...)
        self._tcfHidden=true
        if originalHiding then return originalHiding(self,...) end
    end
    screen.detailList:SetOnTargetDataChangedCallback(function(_,data)
        if screen.activeModuleId==ID and not screen._tcfRendering then
            local plan=data and data.furnishingPlan
            screen._tcfPlanKey=plan and plan.key
            PlanInfo(screen,plan);screen:RefreshKeybinds()
        end
    end)
    for _,descriptor in ipairs(screen.keybindStripDescriptor or {}) do
        if descriptor.keybind=='UI_SHORTCUT_SECONDARY' then
            local visible=descriptor.visible
            descriptor.visible=function()
                if screen.activeModuleId==ID then return false end
                return visible and visible() or false
            end
        elseif descriptor.keybind=='UI_SHORTCUT_NEGATIVE' then
            local callback=descriptor.callback
            descriptor.callback=function()
                if screen.activeModuleId~=ID then if callback then return callback() end;return end
                if screen.mode=='details' then screen.mode='styles';screen:SetCurrentList(screen.styleList)
                elseif screen._tcfQuery and screen._tcfQuery~='' then
                    screen._tcfQuery=nil
                    if screen.motifSearchFocus and screen.motifSearchFocus.GetEditBox then
                        screen._tcfChangingSearch=true
                        screen.motifSearchFocus:GetEditBox():SetText('')
                        screen._tcfChangingSearch=nil
                    end
                    Render(screen)
                else screen:ShowCategories() end
                screen:RefreshKeybinds()
            end
        end
    end
    local group=screen.keybindStripDescriptor
    if group then
        local strip=KEYBIND_STRIP
        local registered=strip and strip.HasKeybindButtonGroup and strip:HasKeybindButtonGroup(group)
        if registered then strip:RemoveKeybindButtonGroup(group) end
        group[#group+1]={keybind='UI_SHORTCUT_LEFT_STICK',alignment=KEYBIND_STRIP_ALIGN_RIGHT,
            name=function()
                return string.format('%s (%d/%d learned)',screen._tcfShowAll and 'Hide learned' or 'Show all',
                    model and model.known or 0,model and model.total or 0)
            end,
            visible=function()return screen.activeModuleId==ID and screen.mode=='styles' end,
            callback=function()
                if screen.activeModuleId~=ID then return end
                screen._tcfShowAll=not screen._tcfShowAll;Render(screen)
            end}
        group[#group+1]={keybind='UI_SHORTCUT_RIGHT_STICK',
            name=function()return 'Location: '..(TC.furnishingPlanZones and TC.furnishingPlanZones[screen._tcfZone] or 'All') end,
            visible=function()return false end,
            callback=function()if screen.activeModuleId==ID then ChooseZone(screen) end end}
        if registered then strip:AddKeybindButtonGroup(group) end
    end
end
local function Prompt(screen)
    if screen.motifSearchFocus and screen.motifSearchFocus.GetEditBox then
        screen.motifSearchFocus:GetEditBox():SetDefaultText('Search Furnishing Plans')
    end
end
TC:RegisterArchiveModule(ID,{
    displayName='Furnishing Plans',addonName='Tamriel Collections - Archive Furnishing Plans',
    assetRoot='TamrielCollectionsFurnishingPlans',screenControl='TCFQuestJournalTL',version=105,supportsSearch=true,
    onCategoryFocus=function(screen,data)
        screen:ShowUnavailableCategory(data,TC:GetArchiveCategory(ID))
        screen.moduleUnavailableTitle:SetText('FURNISHING PLANS')
        screen.moduleUnavailableBody:SetText('v0.1.5 - native families\n\nPress X to browse furnishing plans.')
    end,
    open=function(screen)
        Install(screen)
        screen.activeModuleId,screen.mode=ID,'styles'
        screen._tcfQuery=nil
        if screen.motifSearchFocus and screen.motifSearchFocus.GetEditBox then
            screen._tcfChangingSearch=true;screen.motifSearchFocus:GetEditBox():SetText('');screen._tcfChangingSearch=nil
        end
        screen:SetCurrentList(screen.styleList);Prompt(screen);Render(screen)
    end,
    activateSearch=function(screen)screen:ActivateMotifSearch()end,
})
local function Invalidate()
    generation=generation+1;model,building,waiting=nil,false,{}
    local screen=TC.questScreen
    if screen and Visible(screen) and Wants(screen) then
        if screen._tcfRefreshQueued then return end
        screen._tcfRefreshQueued=true
        local function Refresh()
            screen._tcfRefreshQueued=nil
            if Visible(screen) and Wants(screen) then Render(screen) end
        end
        if zo_callLater then zo_callLater(Refresh,0) else Refresh() end
    end
end
if EVENT_MANAGER then
    for _,name in ipairs({'EVENT_RECIPE_LEARNED'}) do
        if _G[name] then EVENT_MANAGER:RegisterForEvent('TCFFurnishingPlans',_G[name],Invalidate) end
    end
end
