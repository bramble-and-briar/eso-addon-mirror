-- Tamriel Collections - Furnishing Plans v1.0.0
local TC = TamrielCollections
local sourceData=TC.furnishingSources
local planSourceGroups=sourceData and sourceData.groups or {}
local planSourceIndex=sourceData and sourceData.index or '|'
TC.furnishingSources=nil

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
local function Source(plan)
    if not plan then return end
    local external = TC.furnishingPlanData and TC.furnishingPlanData[plan.resultId]
    if external then return external end
    if not plan._tcfSourceChecked then
        plan._tcfSourceChecked = true
        if plan.resultId then
            local _, finish = planSourceIndex:find('|' .. tostring(plan.resultId) .. '=', 1, true)
            if finish then
                local group = tonumber(planSourceIndex:match('(%d+)', finish + 1))
                plan._tcfSource = planSourceGroups[group]
            end
        end
    end
    return plan._tcfSource
end
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
    screen.detailSource:SetFont('ZoFontGamepad20')
    screen.detailSource:SetHeight(88);screen.detailSource:SetMaxLineCount(4)
    screen.detailAchievement:SetFont('ZoFontGamepad18');screen.detailAchievement:SetHeight(58)
    screen.detailAchievement:SetMaxLineCount(3)
end
local function EffectiveSource(screen,plan)
    local source=Source(plan)
    return source and source.byZone and source.byZone[screen._tcfZone] or source
end
local function PlanInfo(screen,plan)
    local station=plan and GetCraftingSkillName and Text(GetCraftingSkillName(plan.station)) or ''
    screen.detailAcquisition:SetText(plan and ((plan.known and '|c66CC66Learned|r' or '|cE57373Not learned|r')
        ..(station~='' and (' - '..station) or '')) or '')
    screen.detailWhereTitle:SetText(plan and 'Where to obtain:' or '')
    local source=EffectiveSource(screen,plan)
    screen.detailLocation:SetText(source and source.location or (plan and 'Source not yet verified' or ''))
    screen.detailSource:SetText(source and source.description or (plan and
        'Acquisition details have not been verified for this plan yet.' or ''))
    screen.detailAchievement:SetText(source and source.extra or '')
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
        local resume=self.resumeMotifsAfterMap and self.activeModuleId==ID and self._tcfMapReturn
        self._tcfHidden=nil
        local result
        if originalShowing then result=originalShowing(self,...) end
        if resume then
            self._tcfMapReturn=nil
            self.activeModuleId=ID
            self._tcfFamilyKey,self._tcfPlanKey=resume.familyKey,resume.planKey
            self.mode=resume.mode=='details' and 'details' or 'styles'
            Render(self)
            self:SetCurrentList(self.mode=='details' and self.detailList or self.styleList)
            self:RefreshKeybinds()
        end
        return result
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
    local originalShowMap=screen.ShowSelectedMotifOnMap
    screen.ShowSelectedMotifOnMap=function(self,...)
        if self.activeModuleId==ID then
            if self.mode~='styles' and self.mode~='details' then return end
            local map=TC.furnishingPlanMap
            if map then return map.Show(self,EffectiveSource(self,SelectedPlan(self)))end
            return
        end
        if originalShowMap then return originalShowMap(self,...)end
    end
    for _,descriptor in ipairs(screen.keybindStripDescriptor or {}) do
        if descriptor.keybind=='UI_SHORTCUT_SECONDARY' then
            local visible=descriptor.visible
            descriptor.visible=function()
                if screen.activeModuleId==ID then
                    local map=TC.furnishingPlanMap
                    return not screen._tcfHidden and (screen.mode=='styles' or screen.mode=='details')
                        and map and map.CanShow(EffectiveSource(screen,SelectedPlan(screen))) or false
                end
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
    assetRoot='TamrielCollectionsFurnishingPlans',screenControl='TCFQuestJournalTL',version = 10000,supportsSearch=true,
    onCategoryFocus=function(screen,data)
        screen:ShowUnavailableCategory(data,TC:GetArchiveCategory(ID))
        screen.moduleUnavailableTitle:SetText('FURNISHING PLANS')
        screen.moduleUnavailableBody:SetText('v1.0.0 - sources and map\n\nPress X to browse furnishing plans.')
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

-- Shared layout: included in every standalone Archive module; initialized once.
do
local TC = TamrielCollections
if not TC.archiveLayout or TC.archiveLayout.version < 1101 then
-- Shared Archives layout derived from the approved Motifs v1.1.1: a separate scene-owned background plane keeps the
-- native masked menus, search controls, emblem and panel rails unobscured.
-- Geometry is measured
-- against GuiRoot because ESO narrows the native scene owner to quadrant 1.
local Pilot = { version = 1101, modules = {} }
TC.archiveLayout = Pilot
local function Current(screen)
    local id
    if screen.mode == 'categories' then
        local data = screen.categoryList and screen.categoryList:GetTargetData()
        id = data and data.categoryKey
    elseif screen.mode == 'styles' or screen.mode == 'details' or screen.mode == 'starter' then
        id = screen.activeModuleId
    end
    return id and Pilot.modules[id]
end
local function IsArchive(screen) return Current(screen) ~= nil end
local function Capture(control)
    local saved = { anchors = {}, width = control:GetWidth(), height = control:GetHeight(), hidden = control:IsHidden(), parent = control:GetParent() }
    for index = 0, control:GetNumAnchors() - 1 do
        local valid, point, relative, relativePoint, x, y, constrains = control:GetAnchor(index)
        if valid then saved.anchors[#saved.anchors + 1] = { point, relative, relativePoint, x, y, constrains } end
    end
    if control.GetAutoRectClipChildren then saved.clip = control:GetAutoRectClipChildren() end
    if control.GetDrawLayer then saved.layer = control:GetDrawLayer() end
    if control.GetDrawLevel then saved.level = control:GetDrawLevel() end
    if control.GetFont then saved.font = control:GetFont() end
    return saved
end
local function RestoreControl(control, saved)
    if saved.parent and control:GetParent() ~= saved.parent then control:SetParent(saved.parent) end
    control:ClearAnchors()
    control:SetDimensions(saved.width, saved.height)
    for _, anchor in ipairs(saved.anchors) do
        control:SetAnchor(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5], anchor[6])
    end
    control:SetHidden(saved.hidden)
    if saved.clip ~= nil and control.SetAutoRectClipChildren then control:SetAutoRectClipChildren(saved.clip) end
    if saved.layer ~= nil then control:SetDrawLayer(saved.layer) end
    if saved.level ~= nil then control:SetDrawLevel(saved.level) end
    if saved.font then control:SetFont(saved.font) end
end
local moved = { 'collectionsHeaderLine', 'collectionsLogoBottomLine', 'collectionsMenuBottomLine',
    'collectionsHeaderLogo', 'detailTopLine', 'detailBottomLine', 'motifSearchLine', 'motifSearchBackdrop',
    'motifSearchControl', 'styleListContainer', 'detailControl', 'detailHeading', 'detailAcquisition',
    'detailWhereTitle', 'detailLocation', 'detailSource', 'detailAchievement', 'detailIcon',
    'moduleUnavailableTitle', 'moduleUnavailableBody' }
local hiddenLines = { 'collectionsHeaderLine', 'collectionsLogoBottomLine', 'collectionsMenuBottomLine',
    'detailTopLine', 'detailBottomLine', 'motifSearchLine', 'motifSearchBackdrop' }
local function Bounds(screen)
    local owner, root = screen.control, GuiRoot or screen.control
    if not owner or not root or not root.GetLeft or not screen.middle or not screen.right then return end
    local left, top, width, height = root:GetLeft(), root:GetTop(), root:GetWidth(), root:GetHeight()
    if not (left and top and width and height and width > 600 and height > 400) then return end
    local middle, right = screen.middle:GetLeft() - left, screen.right:GetLeft() - left
    if not (middle > 100 and right > middle + 100 and right < width - 100) then return end
    local alley = ZO_GAMEPAD_ALLEY_WIDTH or 10
    local panelLeft = math.max(0, middle - screen.right:GetWidth() - alley)
    local panelRight = math.min(width, screen.right.GetRight and screen.right:GetRight() - left or width)
    local middleEnd = math.min(right - alley, screen.middle.GetRight and screen.middle:GetRight() - left or right - alley)
    local texture = ZO_KeybindStripGamepadBackgroundTexture
    local keybindHeight = texture and texture.GetHeight and texture:GetHeight() or ZO_GAMEPAD_KEYBIND_STRIP_BACKGROUND_HEIGHT or 128
    local footer = texture and texture.GetTop and texture:GetTop() - top or height - keybindHeight
    if not footer or footer <= height / 2 or footer > height then footer = height - keybindHeight end
    footer = footer - 16
    -- All columns share a title baseline and two narrow gold rules. Keep the
    -- left menu and chapter-list divider aligned, leaving the middle list open.
    local titleTop = math.max(24, ZO_GAMEPAD_SAFE_ZONE_INSET_Y or 54) + 8
    local first, second = titleTop + 56, titleTop + 216
    local listTop, lower = second + 18, footer - 234
    if lower - listTop < 314 then return end
    return { root = root, owner = owner, width = width, height = height,
        left = panelLeft, leftEnd = middle - alley, middle = middle, middleEnd = middleEnd,
        right = right, edge = panelRight, titleTop = titleTop, first = first,
        second = second, listTop = listTop, lower = lower, footer = footer }
end
local function Place(control, b, left, right, top, height)
    if not control then return end
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, b.root, TOPLEFT, left, top)
    control:SetAnchor(TOPRIGHT, b.root, TOPLEFT, right, top)
    control:SetHeight(height)
end
local function Foreground(control)
    if not control then return end
    control:SetDrawLayer(DL_CONTROLS)
    control:SetDrawLevel(90)
end
local function NewControl(state, name, kind, level)
    local isBackground = name == 'Backdrop' or name == 'FooterFill' or name == 'HeaderShade'
    local parent = isBackground and state.backgroundRoot or state.bounds.owner
    local control = WINDOW_MANAGER:CreateControl('TCArchiveLayout' .. name, parent, kind)
    if DT_LOW then control:SetDrawTier(DT_LOW) end
    control:SetDrawLayer(isBackground and DL_BACKGROUND or DL_CONTROLS)
    control:SetDrawLevel(isBackground and 0 or level)
    control:SetHidden(true)
    return control
end
local function MakeControls(state, screen)
    if state.controls then return end
    local c = {}; state.controls = c
    -- Scroll masks and top-level windows compose their descendants as a group.
    -- Raising a label cannot place it above an opaque sibling in another
    -- composed layer. Keep the paint in a distinct, lower background window.
    local background = WINDOW_MANAGER:CreateTopLevelWindow('TCArchiveBackgroundWindow')
    background:SetHidden(true)
    background:SetMouseEnabled(false)
    background:SetDrawTier(DT_LOW)
    background:SetDrawLayer(DL_BACKGROUND)
    background:SetDrawLevel(0)
    state.backgroundRoot = background
    state.backgroundFragment = ZO_SimpleSceneFragment:New(background)
    state.backgroundFragment:SetConditional(function() return state.active == true and IsArchive(screen) end)
    screen.scene:AddFragment(state.backgroundFragment)
    -- A near-solid tint retains a faint glimpse of the world beneath the
    -- native gamepad panels, while keeping collection text readable.
    c.Backdrop = NewControl(state, 'Backdrop', CT_TEXTURE, 10)
    c.Backdrop:SetColor(32 / 255, 37 / 255, 38 / 255, 0.72)
    c.FooterFill = NewControl(state, 'FooterFill', CT_TEXTURE, 11)
    c.FooterFill:SetColor(36 / 255, 40 / 255, 40 / 255, 1)
    c.FooterRule = NewControl(state, 'FooterRule', CT_TEXTURE, 20)
    c.FooterRule:SetColor(145 / 255, 137 / 255, 112 / 255, 1)
    c.HeaderShade = NewControl(state, 'HeaderShade', CT_TEXTURE, 15)
    c.HeaderShade:SetColor(0.015, 0.02, 0.02, 0.24)
    for _, name in ipairs({ 'TitleRule', 'HeaderRule', 'MenuRule', 'SourceRule' }) do
        local line = NewControl(state, name, CT_TEXTURE, 20)
        -- The native divider fades toward its ends. A solid two-unit rule
        -- spans the exact panel bounds without fading or stretching an image.
        line:SetColor(224 / 255, 191 / 255, 124 / 255, 1)
        c[name] = line
    end
    for _, name in ipairs({ 'ArchivesTitle', 'ModuleTitle', 'DetailsTitle', 'StarterHint' }) do
        local label = NewControl(state, name, CT_LABEL, 90)
        label:SetFont(name == 'StarterHint' and 'ZoFontGamepad25' or 'ZoFontGamepadBold34')
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        if name == 'StarterHint' then label:SetColor(0.72, 0.72, 0.68, 1)
        else label:SetColor(244 / 255, 225 / 255, 182 / 255, 1) end
        c[name] = label
    end
    c.ModuleEmblem = NewControl(state, 'ModuleEmblem', CT_TEXTURE, 90)
    c.ModuleEmblem:SetColor(244 / 255, 225 / 255, 182 / 255, 0.45)
    c.ContextHint = NewControl(state, 'ContextHint', CT_LABEL, 90)
    c.ContextHint:SetFont('ZoFontGamepad25')
    c.ContextHint:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    c.ContextHint:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    c.ContextHint:SetColor(0.72, 0.72, 0.68, 1)
    c.ContextHint:SetText('Collection overview')
    c.ArchivesTitle:SetText('TAMRIEL ARCHIVES')
    c.ModuleTitle:SetText('MOTIFS')
    c.DetailsTitle:SetText('DETAILS')
    c.StarterHint:SetText('Choose a motif to view its chapters,\ncollection progress and sources.')
end
local function HideNative(screen)
    for _, name in ipairs(hiddenLines) do if screen[name] then screen[name]:SetHidden(true) end end
end
function Pilot.Restore(screen)
    local state = screen._tcArchiveLayout
    if not state then return end
    state.generation = (state.generation or 0) + 1
    state.pending, state.attempts = nil, 0
    local wasActive = state.active
    state.active = false
    if state.backgroundFragment then state.backgroundFragment:Refresh() end
    if not wasActive then return end
    for list, offset in pairs(state.listOffsets or {}) do
        list:SetFixedCenterOffset(offset)
    end
    state.listOffsets = nil
    for control, saved in pairs(state.saved) do RestoreControl(control, saved) end
    for _, control in pairs(state.controls or {}) do control:SetHidden(true) end
    if state.ownerLayer ~= nil then screen.control:SetDrawLayer(state.ownerLayer) end
    if ZO_GamepadGenericHeader_Refresh and screen.header then
        ZO_GamepadGenericHeader_Refresh(screen.header, screen.headerData or { titleText = 'TAMRIEL ARCHIVES' })
    end
    state.saved = nil
end
function Pilot.Apply(screen)
    local config = Current(screen)
    if not config or screen._tcArchiveLayoutHidden then return false end
    -- Motifs v1.1.1 owns its approved layout independently. Restore it before
    -- capturing native controls for another module, regardless of load order.
    local motifsState = screen._tcmLayoutPilot
    if motifsState and not motifsState.active and motifsState.saved then
        -- Its list-offset restoration fires keybind callbacks before it has
        -- restored the original parents. The enclosing category change will
        -- apply this layout once that restoration has fully completed.
        return false
    end
    if TC.motifLayoutPreview then TC.motifLayoutPreview.Restore(screen) end
    if screen._tcArchiveLayout and screen._tcArchiveLayout.active
        and screen._tcArchiveLayout.moduleId ~= config.id then Pilot.Restore(screen) end
    local state = screen._tcArchiveLayout
    if not state then state = {}; screen._tcArchiveLayout = state end
    local b = state.active and state.bounds or Bounds(screen)
    if not b then
        if zo_callLater and not state.pending and (state.attempts or 0) < 3 then
            state.pending, state.attempts = true, (state.attempts or 0) + 1
            local generation = state.generation or 0
            zo_callLater(function()
                if (state.generation or 0) ~= generation then return end
                state.pending = nil
                if IsArchive(screen) then Pilot.Apply(screen) end
            end, 33)
        end
        return false
    end
    if not state.active then
        state.bounds, state.saved, state.attempts = b, {}, 0
        state.ownerLayer = screen.control:GetDrawLayer()
        for _, name in ipairs(moved) do
            local control = screen[name]
            if control and control.GetNumAnchors then state.saved[control] = Capture(control) end
        end
        for _, row in ipairs(screen.fixedCategoryRows or {}) do state.saved[row] = Capture(row) end
        MakeControls(state, screen)
        state.active, state.moduleId = true, config.id
    end
    -- Explicitly separate the scene's content plane from its background plane.
    screen.control:SetDrawLayer(DL_CONTROLS)
    local c, starter = state.controls, screen.mode == 'categories' or screen.mode == 'starter'
    c.ModuleTitle:SetText(string.upper(config.name))
    c.StarterHint:SetText(config.hint)
    if not starter then screen:SetMotifContentVisible(true) end
    Place(state.backgroundRoot, b, 0, b.width, 0, b.height)
    Place(c.Backdrop, b, 0, b.width, 0, b.height)
    local keybindTop = b.footer + 16
    Place(c.FooterFill, b, 0, b.width, keybindTop, b.height - keybindTop)
    Place(c.FooterRule, b, 0, b.width, keybindTop, 2)
    Place(c.HeaderShade, b, b.left, b.edge, b.titleTop - 20, b.second - b.titleTop + 20)
    Place(c.TitleRule, b, b.left, b.edge, b.first, 2)
    Place(c.HeaderRule, b, b.left, b.edge, b.second, 2)
    Place(c.MenuRule, b, b.left, b.leftEnd, b.lower, 2)
    Place(c.SourceRule, b, b.right, b.edge, b.lower, 2)
    Place(c.ArchivesTitle, b, b.left + 12, b.leftEnd - 12, b.titleTop, 48)
    Place(c.ModuleTitle, b, b.middle + 12, b.middleEnd - 12, b.titleTop, 48)
    Place(c.DetailsTitle, b, b.right + 12, b.edge - 12, b.titleTop, 48)
    local category = TC.GetArchiveCategory and TC:GetArchiveCategory(config.id)
    local emblem = category and screen:GetCategoryIcon(category)
    if emblem then c.ModuleEmblem:SetTexture(emblem) end
    local emblemSize = math.min(128, b.footer - b.lower - 40)
    Place(c.ModuleEmblem, b, (b.left + b.leftEnd - emblemSize) / 2,
        (b.left + b.leftEnd + emblemSize) / 2, (b.lower + b.footer - emblemSize) / 2, emblemSize)
    Place(c.StarterHint, b, b.right + 28, b.edge - 28, (b.listTop + b.lower) / 2 - 48, 96)
    for _, control in pairs(c) do control:SetHidden(false) end
    c.StarterHint:SetHidden(not starter)
    c.ModuleEmblem:SetHidden(not emblem)
    c.ContextHint:SetHidden(config.search)
    if ZO_GamepadGenericHeader_Refresh and screen.header then
        ZO_GamepadGenericHeader_Refresh(screen.header, { titleText = '' })
    end
    local center = (b.first + b.second) / 2
    Place(c.ContextHint, b, b.middle + 32, b.middleEnd - 32, center - 24, 48)
    if screen.collectionsHeaderLogo then
        -- The native header is a separately animated fragment. Its hidden
        -- state and scroll mask must not hide the fixed Archives artwork.
        screen.collectionsHeaderLogo:SetParent(b.owner)
        screen.collectionsHeaderLogo:SetHidden(false)
        screen.collectionsHeaderLogo:ClearAnchors()
        screen.collectionsHeaderLogo:SetDimensions(100, 100)
        screen.collectionsHeaderLogo:SetAnchor(CENTER, b.root, TOPLEFT, (b.left + b.leftEnd) / 2, center)
        Foreground(screen.collectionsHeaderLogo)
    end
    if screen.detailIcon then
        screen.detailIcon:ClearAnchors()
        screen.detailIcon:SetDimensions(100, 100)
        screen.detailIcon:SetAnchor(CENTER, b.root, TOPLEFT, (b.right + b.edge) / 2, center)
        Foreground(screen.detailIcon)
    end
    if screen.motifSearchControl then
        screen.motifSearchControl:ClearAnchors()
        screen.motifSearchControl:SetAnchor(CENTER, b.root, TOPLEFT, (b.middle + b.middleEnd) / 2, center)
        -- The same native search affordance is visible on the starter. Its
        -- existing Search shortcut opens the selected module and then focuses the edit box.
        screen.motifSearchControl:SetHidden(not config.search)
        Foreground(screen.motifSearchControl)
    end
    Place(screen.styleListContainer, b, b.middle + 8, b.middleEnd - 8, b.listTop, b.footer - b.listTop)
    Place(screen.detailControl, b, b.right + 8, b.edge - 8, b.listTop, b.lower - b.listTop - 12)
    for _, name in ipairs({ 'styleListContainer', 'detailControl' }) do
        if screen[name] and screen[name].SetAutoRectClipChildren then screen[name]:SetAutoRectClipChildren(true) end
    end
    -- Native vertical lists anchor the selected row at their center. Bring
    -- that anchor to the top of the viewport without moving the panel itself.
    state.listOffsets = state.listOffsets or {}
    for _, list in ipairs({ screen.styleList, screen.detailList }) do
        if list.SetFixedCenterOffset and list.GetControl then
            if state.listOffsets[list] == nil then
                state.listOffsets[list] = list.fixedCenterOffset or 0
            end
            list:SetFixedCenterOffset(8 - list:GetControl():GetHeight() / 2)
        end
    end
    Place(screen.detailHeading, b, b.right + 24, b.edge - 24, b.first + 20, 76)
    if screen.detailHeading then screen.detailHeading:SetFont('ZoFontGamepadBold27') end
    Place(screen.detailAcquisition, b, b.right + 24, b.edge - 24, b.first + 110, 30)
    Foreground(screen.detailHeading)
    Foreground(screen.detailAcquisition)
    Place(screen.detailWhereTitle, b, b.right + 24, b.edge - 24, b.lower + 10, 28)
    Place(screen.detailLocation, b, b.right + 24, b.edge - 24, b.lower + 42, 30)
    Place(screen.detailSource, b, b.right + 24, b.edge - 24, b.lower + 76, 88)
    Place(screen.detailAchievement, b, b.right + 24, b.edge - 24, b.lower + 170, 58)
    -- Retain foreground placement without changing native data, row templates,
    -- scrolling, search controls or controller bindings.
    for _, name in ipairs({ 'styleListContainer', 'detailControl', 'detailWhereTitle',
        'detailLocation', 'detailSource', 'detailAchievement',
        'moduleUnavailableTitle', 'moduleUnavailableBody' }) do Foreground(screen[name]) end
    local rows = screen.fixedCategoryRows or {}
    local spacing = #rows > 1 and math.min(80, (b.lower - b.listTop - 90) / (#rows - 1)) or 0
    for index, row in ipairs(rows) do
        -- Keep only the visuals outside the animated header. The invisible
        -- native category list retains all controller input and selection.
        row:SetParent(b.owner)
        row:SetHidden(false)
        row:ClearAnchors()
        row:SetAnchor(TOPLEFT, b.root, TOPLEFT, b.left + 44, b.listTop + 14 + (index - 1) * spacing)
        Foreground(row)
    end
    if starter then
        -- A single module heading above the search field identifies this page;
        -- preserve the native press-X prompt without repeating the heading.
        if screen.moduleUnavailableTitle then screen.moduleUnavailableTitle:SetHidden(true) end
        Place(screen.moduleUnavailableBody, b, b.middle + 32, b.middleEnd - 32,
            (b.listTop + b.lower) / 2 - 76, 152)
    end
    HideNative(screen)
    state.backgroundFragment:Refresh()
    return true
end

-- List refreshes can call selection/keybind callbacks synchronously. Keep a
-- single layout pass active and restore the guard even if native code errors.
local rawApply, rawRestore = Pilot.Apply, Pilot.Restore
function Pilot.Apply(screen)
    if screen._tcArchiveLayoutBusy or screen._tcArchiveLayoutPaused then return false end
    screen._tcArchiveLayoutBusy = true
    local ok, result = pcall(rawApply, screen)
    screen._tcArchiveLayoutBusy = nil
    if not ok then error(result) end
    return result
end
function Pilot.Restore(screen)
    local busy = screen._tcArchiveLayoutBusy
    screen._tcArchiveLayoutBusy = true
    local ok, result = pcall(rawRestore, screen)
    screen._tcArchiveLayoutBusy = busy
    if not ok then error(result) end
    return result
end
local function Sync(screen)
    if screen._tcArchiveLayoutBusy or screen._tcArchiveLayoutPaused or screen._tcArchiveLayoutHidden then return end
    if Current(screen) then Pilot.Apply(screen) else Pilot.Restore(screen) end
end
function Pilot.WatchLifecycle(screen)
    -- Modules install their reader/loading hooks on first open. Keep this
    -- observer outside the latest hooks: a reader's resume branch can return
    -- without calling an earlier OnShowing implementation.
    if screen.OnShowing ~= screen._tcArchiveLayoutOnShowing then
        local showing = screen.OnShowing
        local wrapper = function(self, ...)
            self._tcArchiveLayoutHidden = nil
            local result
            if showing then result = showing(self, ...) end
            Sync(self)
            return result
        end
        screen.OnShowing, screen._tcArchiveLayoutOnShowing = wrapper, wrapper
    end
    if screen.OnHiding ~= screen._tcArchiveLayoutOnHiding then
        local hiding = screen.OnHiding
        local wrapper = function(self, ...)
            self._tcArchiveLayoutHidden = true
            Pilot.Restore(self)
            if hiding then return hiding(self, ...) end
        end
        screen.OnHiding, screen._tcArchiveLayoutOnHiding = wrapper, wrapper
    end
end
function Pilot.BeforeShowing(screen)
    screen._tcArchiveLayoutHidden = nil
    Pilot.Install(screen)
    -- A standalone module must open on an installed category, rather than
    -- the disabled Motifs row inherited from the native shared menu.
    local selected = screen.categoryList and screen.categoryList:GetTargetData()
    if selected and TC:IsArchiveModuleInstalled(selected.categoryKey) then return end
    for index, category in ipairs(TC.archiveCategories or {}) do
        if TC:IsArchiveModuleInstalled(category.key) then
            screen.categoryList:SetSelectedIndex(index)
            break
        end
    end
end
function Pilot.Install(screen)
    if screen._tcArchiveLayoutInstalled then Pilot.WatchLifecycle(screen); return end
    screen._tcArchiveLayoutInstalled = true
    local category = screen.ShowCategory
    screen.ShowCategory = function(self, data)
        local state = self._tcArchiveLayout
        if state and state.active and (not data or data.categoryKey ~= state.moduleId) then Pilot.Restore(self) end
        local result = category(self, data)
        Sync(self)
        return result
    end
    local show = screen.ShowStyle
    screen.ShowStyle = function(self, data)
        if not Current(self) then Pilot.Restore(self) end
        local result = show(self, data)
        Sync(self)
        return result
    end
    local refresh = screen.RefreshKeybinds
    screen.RefreshKeybinds = function(self, ...)
        local result = refresh(self, ...)
        Sync(self)
        return result
    end
    Pilot.WatchLifecycle(screen)
end
function Pilot.Prompt(screen, data, config)
    screen:ShowUnavailableCategory(data, TC:GetArchiveCategory(config.id))
    if screen.moduleUnavailableTitle then screen.moduleUnavailableTitle:SetHidden(true) end
    if screen.moduleUnavailableBody then screen.moduleUnavailableBody:SetText(config.intro) end
    if screen.motifSearchFocus and screen.motifSearchFocus.GetEditBox then
        screen.motifSearchFocus:GetEditBox():SetDefaultText('Search ' .. config.name)
    end
    Pilot.Apply(screen)
end
function Pilot.Register(id, config)
    config.id = id
    local module = TC:GetArchiveModule(id)
    if not module then return end
    config.search = module.supportsSearch == true
    Pilot.modules[id] = config
    if module._tcArchiveLayoutWrapped then return end
    module._tcArchiveLayoutWrapped = true
    local focus, open = module.onCategoryFocus, module.open
    module.onCategoryFocus = function(screen, data)
        Pilot.Install(screen)
        Pilot.Prompt(screen, data, config)
    end
    module.open = function(screen)
        Pilot.Install(screen)
        -- Style Pages previously populated on focus. Defer that exact native
        -- catalogue routine to X; the other modules prepare themselves on open.
        local paused = screen._tcArchiveLayoutPaused
        screen._tcArchiveLayoutPaused = true
        local ok, result = pcall(function()
            if config.prepareOnOpen and focus then focus(screen) end
            if open then return open(screen) end
        end)
        screen._tcArchiveLayoutPaused = paused
        if not ok then error(result) end
        Pilot.WatchLifecycle(screen)
        Pilot.Apply(screen)
        return result
    end
end

end
TC.archiveLayout.Register("furnishingPlans", { name = "Furnishing Plans", intro = "Browse furnishing families and track your plans.\nFind learned and unlearned furnishing designs.\n\nPress X to browse Furnishing Plans.", hint = "Choose a furnishing family to view its plans,\nlearned status and source details." })
end
