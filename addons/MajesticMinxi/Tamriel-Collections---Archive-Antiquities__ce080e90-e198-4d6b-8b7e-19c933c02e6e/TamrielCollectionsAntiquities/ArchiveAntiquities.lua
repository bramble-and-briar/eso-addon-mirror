-- Tamriel Collections - Archive Antiquities v1.0.2
-- Whole rewards and their parts share native recovery and codex progress.
local TC=TamrielCollections
local ID,TEMPLATE='antiquities','ZO_QuestJournal_Gamepad_MenuEntryTemplate'
local Catalogue=TC.antiquityCatalogue
local Key=Catalogue.Key
local Render,ShowSelection,Install,NavigationLayout,StartLeadRefresh
local function Now()return GetFrameTimeSeconds and GetFrameTimeSeconds()or 0 end
local function ActiveLead(part)
    return part.hasLead and part.requiresLead and(not part.leadExpires or part.leadExpires>Now())or false
end
local function ExpiryText(part)
    local seconds=part.leadExpires and math.max(0,part.leadExpires-Now())
    if not seconds then return 'Active lead'end
    local value,unit
    if seconds>=86400 then value,unit=math.ceil(seconds/86400),'day'
    elseif seconds>=3600 then value,unit=math.ceil(seconds/3600),'hour'
    elseif seconds>=60 then value,unit=math.ceil(seconds/60),'minute'
    else value,unit=math.ceil(seconds),'second'end
    return string.format('Active lead - expires in %d %s%s',value,unit,value==1 and ''or 's')
end
local function Active(screen)
    return screen.activeModuleId==ID and (screen.mode=='styles' or screen.mode=='details')
end
local function Alive(screen)
    return Active(screen) and not screen._tcaHidden and (not SCENE_MANAGER
        or not SCENE_MANAGER.IsShowing or SCENE_MANAGER:IsShowing('tamrielCollectionsGamepad'))
end
local function ZoneName(id)
    local name=id and GetZoneNameById and GetZoneNameById(id)
    return name and name~='' and (zo_strformat and zo_strformat(name) or name) or 'Unknown zone'
end
local function Source(part)
    return part and (part.source or TC.antiquitySources and TC.antiquitySources[part.id]
        or TC.antiquityExtraSources and TC.antiquityExtraSources.Get(part.id)
        or (part.furnishing or part.parent and part.parent.family=='furnishings')
            and TC.antiquityFurnitureSources and TC.antiquityFurnitureSources.Get(part.id))
end
local function InZone(part,zone)
    if not zone or part.zoneId==zone then return true end
    local source=Source(part)
    for _,id in ipairs(source and source.zones or {})do if id==zone then return true end end
    return false
end
local function PartVisible(screen,part)
    return screen._tcaShowAll or not part.complete
end
local function Matches(screen,item)
    local query=screen._tcaQuery or ''
    local parent=item.parts and item or item.parent or item
    local parentMatch=query=='' or parent.nameKey:find(query,1,true)
    if item.parts then
        if not PartVisible(screen,item)then return false end
        for _,part in ipairs(item.parts)do
            if PartVisible(screen,part) and InZone(part,screen._tcaZone)
                and (parentMatch or part.nameKey:find(query,1,true))then return true end
        end
        return false
    end
    return PartVisible(screen,item) and InZone(item,screen._tcaZone)
        and (parentMatch or item.nameKey:find(query,1,true))
end
local function LeadCount(screen,item)
    if item.parts then
        if not PartVisible(screen,item)then return 0 end
        local count=0
        for _,part in ipairs(item.parts)do
            if Matches(screen,part)and ActiveLead(part)then count=count+1 end
        end
        return count
    end
    return Matches(screen,item)and ActiveLead(item)and 1 or 0
end
local function LeadSummary(count)
    return string.format('%d active lead%s',count,count==1 and ''or 's')
end
local function LeadBadge(count,group)
    if count==0 then return ''end
    local text=group and(count..' LEAD'..(count==1 and ''or 'S'))or 'LEAD'
    return '  |cE0BF7C['..text..']|r'
end
local function Selected(screen)
    local row=screen.styleList:GetTargetData();return row and row.antiquityItem
end
local function LeadStatus(part)
    if ActiveLead(part)then return ExpiryText(part)end
    if part.ready then
        if part.treasure then return 'Treasure recovered'end
        if part.motif then return 'Chapter recovered'end
        if part.furnishing then return 'Furnishing recovered'end
        if part.single then return 'Reward recovered'end
        return part.parent.family=='mounts'and 'Part recovered'or 'Part ready for assembly'
    end
    if part.hasLead and part.leadExpires and part.leadExpires<=Now()then return 'Lead expired'end
    return part.requiresLead and 'Lead not held' or 'No lead required'
end
local function StopLeadRefresh(screen)
    if screen._tcaLeadRefresh then
        if EVENT_MANAGER and EVENT_MANAGER.UnregisterForUpdate then EVENT_MANAGER:UnregisterForUpdate('TCAActiveLeads')end
        screen._tcaLeadRefresh=nil
    end
end
local function HideInformation(screen)
    StopLeadRefresh(screen)
    for _,name in ipairs({'_tcaBody','_tcaPath'})do
        if screen[name]then screen[name]:SetHidden(true)end
    end
    if TC.antiquityInfo then TC.antiquityInfo.Hide(screen)end
end
local function Body(screen,text)
    screen._tcaBodyText=text or ''
    if screen._tcaBody then screen._tcaBody:SetText(screen._tcaBodyText)end
end
local function ItemBody(screen,item)
    local lines={}
    local count=LeadCount(screen,item)
    if count>0 then
        lines[#lines+1]='|cE0BF7C'..(item.parts and LeadSummary(count)or ExpiryText(item))..'|r\n'
    end
    if item.description and item.description~=''then lines[#lines+1]=item.description..'\n'end
    if item.motifGroup then
        lines[#lines+1]=string.format('Chapters learned: %d/%d',item.chaptersLearned,#item.parts)
        lines[#lines+1]=string.format('Codex-complete chapters: %d/%d',item.chaptersComplete,#item.parts)
        lines[#lines+1]='\nPress X to browse chapter leads.'
    elseif item.treasureGroup then
        lines[#lines+1]=string.format('Treasures recovered: %d/%d',item.partsRecovered,#item.parts)
        lines[#lines+1]='Green > Blue > Purple'
        lines[#lines+1]='\nPress X to browse this zone\'s treasures.'
    elseif item.parts then
        lines[#lines+1]=string.format('Parts %s: %d/%d',item.family=='mounts'and 'recovered'or 'ready',
            item.family=='mounts'and item.partsRecovered or item.ready,#item.parts)
        local complete=0;for _,part in ipairs(item.parts)do if part.complete then complete=complete+1 end end
        lines[#lines+1]=string.format('Codex-complete parts: %d/%d',complete,#item.parts)
        lines[#lines+1]='\nPress X to browse fragments and their sources.'
    else
        if item.parent then lines[#lines+1]=(item.parent.kind or 'Reward')..': '..(item.parent.shortName or item.parent.name)..'\n'end
        lines[#lines+1]='Recovered: '..item.recovered
        lines[#lines+1]='Excavation: '..ZoneName(item.zoneId)
        if count==0 then lines[#lines+1]=LeadStatus(item)end
    end
    return table.concat(lines,'\n')
end
local function ItemInfo(screen,item)
    local heading=item and item.name or 'Antiquities'
    screen.detailHeading:SetText('|cFFEBB3'..heading..'|r')
    screen.detailAcquisition:SetText(item and string.format('Codex %d/%d',item.known,item.total) or '')
    if item and item.motif then
        local learned=item.learned==true and 'Learned'or item.learned==false and 'Not learned'or 'Learning status unavailable'
        screen.detailAcquisition:SetText(string.format('Codex %d/%d - %s',item.known,item.total,learned))
    end
    if item and item.single and item.collectibleId then
        screen.detailAcquisition:SetText(string.format('Codex %d/%d - %s',item.known,item.total,
            item.unlocked==true and 'Unlocked'or item.unlocked==false and 'Locked'or 'Unlock status unavailable'))
    end
    screen.detailWhereTitle:SetText('')
    screen.detailLocation:SetText('');screen.detailSource:SetText('');screen.detailAchievement:SetText('')
    if not item then
        if TC.antiquityInfo then TC.antiquityInfo.Update(screen)end
        local model=Catalogue.Get()
        Body(screen,not model and 'Preparing antiquities...' or model.error
            or (#model.parts==0 and 'No supported antiquities were supplied by the game.'
                or 'No matching entries.\n\nShow all, change the zone or clear the search.\n\nPress Circle to go back.'))
        return
    end
    Body(screen,ItemBody(screen,item))
    if item.motifGroup then
        screen.detailWhereTitle:SetText('Style progress')
        screen.detailLocation:SetText(item.chaptersChecked==#item.parts
            and string.format('Chapters learned: %d/%d',item.chaptersLearned,#item.parts)or 'Chapter learning status unavailable')
        screen.detailSource:SetText(string.format('Codex-complete chapters: %d/%d.\nPress X to view chapter leads and sources.',item.chaptersComplete,#item.parts))
        screen.detailAchievement:SetText('This style remains listed until every chapter\'s codex is complete.')
    elseif item.treasureGroup then
        screen.detailWhereTitle:SetText('Zone treasure progress')
        screen.detailLocation:SetText(string.format('Treasures recovered: %d/%d',item.partsRecovered,#item.parts))
        screen.detailSource:SetText('Green > Blue > Purple.\nPress X to view the treasures and their lead requirements.')
        screen.detailAchievement:SetText('This zone remains listed until every treasure\'s codex is complete.')
    elseif item.parts then
        screen.detailWhereTitle:SetText('Collection progress')
        if item.collectibleId then
            local kind=item.kind or 'Collectible'
            screen.detailLocation:SetText(item.unlocked==true and kind..' unlocked'
                or item.unlocked==false and kind..' locked' or 'Unlock status unavailable')
        else screen.detailLocation:SetText(string.format('Assembled: %d',item.recovered or 0))end
        local kind=item.kind or 'Reward'
        screen.detailSource:SetText(string.format('Parts %s: %d/%d\nPress X to view this %s\'s parts and lead sources.',
            item.family=='mounts'and 'recovered'or 'ready',
            item.family=='mounts'and item.partsRecovered or item.ready,#item.parts,kind))
        screen.detailAchievement:SetText('The '..kind..' remains listed until every part\'s codex is complete.')
    else
        local source=Source(item)
        screen.detailWhereTitle:SetText(item.treasure and item.tier==1 and 'Availability'or 'Lead source')
        screen.detailLocation:SetText(source and source.location or 'Source not yet verified')
        screen.detailSource:SetText(source and source.description or 'Lead acquisition details are not yet verified. The map button shows the excavation zone.')
        if item.treasure then
            screen.detailAchievement:SetText('Zone: '..ZoneName(item.zoneId)..'\nRecovered: '..item.recovered..'\n'..LeadStatus(item))
        elseif item.furnishing or item.single then
            screen.detailAchievement:SetText('Recovered: '..item.recovered..'\nExcavation: '..ZoneName(item.zoneId)..'\n'..LeadStatus(item))
        else
            screen.detailAchievement:SetText((item.parent.kind or 'Reward')..': '..(item.parent.shortName or item.parent.name)
                ..'\nExcavation: '..ZoneName(item.zoneId)..'\n'..LeadStatus(item))
        end
    end
    if item.parts then
        screen.detailWhereTitle:SetText('Lead sources')
        screen.detailLocation:SetText(item.motifGroup and 'Chapter leads'or item.treasureGroup and 'Zone treasures'or 'Individual fragments')
        screen.detailSource:SetText('Press X to browse the entries in the middle panel. Select an entry to see where to obtain it.')
    end
    screen.detailAchievement:SetText('')
    if TC.antiquityInfo then TC.antiquityInfo.Update(screen,item)end
end
local function Layout(screen)
    screen:SetMotifContentVisible(true);screen.middle:SetHidden(false);screen.right:SetHidden(false)
    screen.detailIcon:SetHidden(true)
    if screen.rightText then screen.rightText:SetHidden(true)end
    screen.detailControl:SetHidden(true)
    for _,name in ipairs({'detailHeading','detailAcquisition','detailWhereTitle',
        'detailLocation','detailSource','detailAchievement'})do screen[name]:SetHidden(false)end
    screen.detailSource:SetFont('ZoFontGamepad20');screen.detailSource:SetHeight(88);screen.detailSource:SetMaxLineCount(4)
    screen.detailAchievement:SetFont('ZoFontGamepad20');screen.detailAchievement:SetHeight(58);screen.detailAchievement:SetMaxLineCount(2)
end
local familyIntros={
    mythics='Browse Mythic items and the fragments needed to assemble them.',
    musicBoxes='Browse music boxes and their component leads.',mounts='Browse mounts and their component leads.',
    pets='Browse pets and their component leads.',appearance='Browse appearance collectibles, emotes and their leads.',
    furnishings='Browse furnishings and crafting stations. Assembled rewards open into their fragments.',
    motifs='Browse styles, chapter leads and learning progress.',
    zoneTreasures='Browse each zone\'s green, blue and purple treasure sequence.',
    treasures='Browse additional Antiquity treasures.',otherRewards='Browse other native Antiquity rewards.',
}
local function FamilyInfo(screen,row)
    if not row then ItemInfo(screen);return end
    screen._tcaFamily=row.key
    screen.detailHeading:SetText('|cFFEBB3'..row.name..'|r')
    screen.detailAcquisition:SetText(string.format('%d/%d entries complete',row.known,row.total))
    screen.detailWhereTitle:SetText('Collection filters');screen.detailLocation:SetText('')
    screen.detailSource:SetText('Search by name or choose a zone to narrow the list. Toggle Show all to include completed codices.')
    screen.detailAchievement:SetText('')
    Body(screen,((row.activeLeads or 0)>0 and '|cE0BF7C'..LeadSummary(row.activeLeads)..'|r\n\n'or '')
        ..(familyIntros[row.key]or 'Browse individual fragment leads and their acquisition sources.')
        ..string.format('\n\n%d entries shown.\n\nPress X to browse %s.',#row.items,row.name))
    if TC.antiquityInfo then TC.antiquityInfo.Hide(screen)end
end
NavigationLayout=function(screen)
    local state=screen._tcArchiveLayout
    if not Active(screen)or not state or not state.active or state.moduleId~=ID then return end
    local b=state.bounds
    if not screen._tcaBody and WINDOW_MANAGER and CT_LABEL and screen.control then
        for _,name in ipairs({'Body','Path'})do
            local control=WINDOW_MANAGER:CreateControl('TCAAntiquity'..name,screen.control,CT_LABEL)
            control:SetDrawLayer(DL_CONTROLS);control:SetDrawLevel(92)
            control:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            control:SetFont(name=='Body'and 'ZoFontGamepad25'or 'ZoFontGamepad20')
            if name=='Path'then
                control:SetColor(1,.92,.70,1);control:SetMaxLineCount(1)
                if TEXT_WRAP_MODE_ELLIPSIS then control:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)end
            end
            screen['_tca'..name]=control
        end
    end
    local function Place(control,left,right,top,height)
        if not control then return end
        control:ClearAnchors();control:SetAnchor(TOPLEFT,b.root,TOPLEFT,left,top)
        control:SetAnchor(TOPRIGHT,b.root,TOPLEFT,right,top);control:SetHeight(height);control:SetHidden(false)
    end
    Place(screen._tcaBody,b.right+28,b.edge-28,b.listTop+10,b.lower-b.listTop-24)
    if screen._tcaBody then
        screen._tcaBody:SetMaxLineCount(math.max(1,math.floor((b.lower-b.listTop-24)/28)))
        screen._tcaBody:SetText(screen._tcaBodyText or '')
    end
    Place(screen._tcaPath,b.middle+28,b.middleEnd-28,b.second-34,26)
    local model=Catalogue.Get()
    local family=model and model.byFamily[screen._tcaFamily]
    local path,title='Families','ANTIQUITIES'
    if screen._tcaLevel~='families'and family then
        title=string.upper(family.name);path='Families > '..family.name
        local parent=model.byKey[screen._tcaParent]
        if screen._tcaLevel=='parts'and parent then path=family.name..' > '..(parent.shortName or parent.name)end
    end
    if screen._tcaPath then screen._tcaPath:SetText(path)end
    state.controls.ModuleTitle:SetText(title)
    screen.detailControl:SetHidden(true)
    if TC.antiquityInfo then TC.antiquityInfo.Layout(screen,b)end
end
ShowSelection=function(screen,data)
    if screen._tcaRendering then return end
    if screen._tcaLevel=='families'then FamilyInfo(screen,data and data.antiquityFamily)
    else
        local item=data and data.antiquityItem
        if item then
            screen._tcaItem=item.key
            screen._tcaSelections=screen._tcaSelections or {}
            screen._tcaSelections[screen._tcaParent or screen._tcaFamily]=item.key
        end
        ItemInfo(screen,item)
    end
    NavigationLayout(screen)
end
Render=function(screen)
    if not Alive(screen)then return end
    Layout(screen)
    local model=Catalogue.Get()
    local rows={}
    if model then
        for _,family in ipairs(model.families)do
            local row={key=family.key,name=family.name,partsView=family.partsView,items={},total=0,known=0,activeLeads=0}
            for _,item in ipairs(family.items)do
                if Matches(screen,item)then
                    row.items[#row.items+1]=item;row.activeLeads=row.activeLeads+LeadCount(screen,item)
                end
                local inZone=false
                if item.parts then
                    for _,part in ipairs(item.parts)do if InZone(part,screen._tcaZone)then inZone=true;break end end
                else inZone=InZone(item,screen._tcaZone)end
                if inZone then row.total=row.total+1;if item.complete then row.known=row.known+1 end end
            end
            if #row.items>0 then rows[#rows+1]=row end
        end
    end
    local level=screen._tcaLevel or 'families'
    local items,selection={},screen._tcaItem
    if level=='families'then items=rows;selection=screen._tcaFamily
    else
        local family=model and model.byFamily[screen._tcaFamily]
        local parent=model and model.byKey[screen._tcaParent]
        if level=='parts'and parent and parent.parts then
            for _,item in ipairs(parent.parts)do if Matches(screen,item)then items[#items+1]=item end end
        elseif family then
            for _,item in ipairs(family.items)do if Matches(screen,item)then items[#items+1]=item end end
        end
    end
    screen._tcaRendering=true;screen.styleList:Clear()
    screen.detailList:Clear();screen.detailList:Commit()
    local selected=1
    for index,item in ipairs(items)do
        local title=item.name
        if item.treasure then
            local tiers={'|c66CC66Green|r','|c6699FFBlue|r','|cCC88FFPurple|r'}
            title=tiers[item.tier]..' - '..title
        end
        local leads=level=='families'and item.activeLeads or LeadCount(screen,item)
        local entry=ZO_GamepadEntryData:New(string.format('%s  (%d/%d)',title,item.known,item.total)
            ..LeadBadge(leads,level=='families'or item.parts~=nil))
        entry.antiquityLeadCount=leads
        if level=='families'then entry.antiquityFamily=item else entry.antiquityItem=item end
        screen.styleList:AddEntry(TEMPLATE,entry)
        if item.key==selection then selected=index end
    end
    screen.styleList:Commit()
    if #items>0 then screen.styleList:SetSelectedIndex(selected)end
    screen._tcaRendering=false
    ShowSelection(screen,screen.styleList:GetTargetData())
    screen._tcaNextLeadExpiry=nil
    for _,part in ipairs(model and model.parts or {})do
        if ActiveLead(part)and part.leadExpires and(not screen._tcaNextLeadExpiry or part.leadExpires<screen._tcaNextLeadExpiry)then
            screen._tcaNextLeadExpiry=part.leadExpires
        end
    end
    if not model then Catalogue.Request(function()return Alive(screen)end,function()Render(screen)end)end
    screen:RefreshKeybinds()
    StartLeadRefresh(screen)
end
StartLeadRefresh=function(screen)
    if screen._tcaLeadRefresh or not(EVENT_MANAGER and EVENT_MANAGER.RegisterForUpdate)then return end
    screen._tcaLeadRefresh=true
    EVENT_MANAGER:RegisterForUpdate('TCAActiveLeads',30000,function()
        if not Alive(screen)then StopLeadRefresh(screen);return end
        if ZO_GenericGamepadDialog_IsShowing and ZO_GenericGamepadDialog_IsShowing()then return end
        if screen._tcaNextLeadExpiry and screen._tcaNextLeadExpiry<=Now()then Render(screen)
        else
            local item=Selected(screen)
            if item then Body(screen,ItemBody(screen,item))end
        end
    end)
end
local function ResetSearch(screen)
    screen._tcaQuery=''
    if screen.motifSearchFocus and screen.motifSearchFocus.GetEditBox then
        screen._tcaChangingSearch=true;screen.motifSearchFocus:GetEditBox():SetText('');screen._tcaChangingSearch=nil
    end
end
local function ChooseZone(screen)
    if not (ZO_Dialogs_RegisterCustomDialog and ZO_Dialogs_ShowGamepadDialog and GAMEPAD_DIALOGS)then return end
    local name='TCA_ANTIQUITY_ZONE'
    if not TC._tcaZoneDialog then
        TC._tcaZoneDialog=true
        ZO_Dialogs_RegisterCustomDialog(name,{
            gamepadInfo={dialogType=GAMEPAD_DIALOGS.PARAMETRIC},title={text='Antiquity zone'},parametricList={},
            mainText={text='Matches the lead source or excavation zone.'},
            setup=function(dialog,data)
                local seen,zones={},{{name='All zones'}}
                local function Add(id)
                    if id and id>0 and not seen[id]then
                        seen[id]=true;zones[#zones+1]={id=id,name=ZoneName(id)}
                    end
                end
                for _,part in ipairs(Catalogue.Get() and Catalogue.Get().parts or {})do
                    Add(part.zoneId)
                    for _,id in ipairs(Source(part) and Source(part).zones or {})do Add(id)end
                end
                table.sort(zones,function(a,b)
                    if not a.id then return b.id~=nil end
                    if not b.id then return false end
                    if a.name~=b.name then return a.name<b.name end
                    return a.id<b.id
                end)
                local rows,selected={},1
                for index,zone in ipairs(zones)do
                    local entry=ZO_GamepadEntryData:New(zone.name)
                    entry.zoneId=zone.id;entry.setup=ZO_SharedGamepadEntry_OnSetup
                    rows[#rows+1]={template='ZO_GamepadMenuEntryTemplate',entryData=entry}
                    if zone.id==data.screen._tcaZone then selected=index end
                end
                dialog.info.parametricList=rows;dialog:setupFunc();dialog.entryList:SetSelectedIndex(selected)
            end,
            buttons={{keybind='DIALOG_PRIMARY',text='Select',callback=function(dialog)
                local owner=dialog.data.screen;local entry=dialog.entryList:GetTargetData()
                if Active(owner)and entry then
                    owner._tcaZone=entry.zoneId
                    Render(owner)
                end
            end},{keybind='DIALOG_NEGATIVE',text='Cancel'}},
        })
    end
    ZO_Dialogs_ShowGamepadDialog(name,{screen=screen})
end
Install=function(screen)
    if screen._tcaInstalled then return end
    screen._tcaInstalled=true
    for _,method in ipairs({'ShowCategory','ShowCategories'})do
        local original=screen[method]
        if original then screen[method]=function(self,...)
            HideInformation(self)
            return original(self,...)
        end end
    end
    local show=screen.ShowStyle
    screen.ShowStyle=function(self,data)
        if Active(self)then ShowSelection(self,data)elseif show then
            HideInformation(self)
            return show(self,data)
        end
    end
    local search=screen.OnMotifSearchTextChanged
    screen.OnMotifSearchTextChanged=function(self,value)
        if not Active(self)then if search then return search(self,value)end;return end
        if self._tcaChangingSearch then return end
        self._tcaQuery=Key(value);Render(self)
    end
    local showing,hiding=screen.OnShowing,screen.OnHiding
    screen.OnShowing=function(self,...)
        local resume=self.resumeMotifsAfterMap and self.activeModuleId==ID and self._tcaMapReturn
        self._tcaHidden=nil
        local result;if showing then result=showing(self,...)end
        if resume then
            self._tcaMapReturn=nil;self.activeModuleId=ID
            self._tcaFamily,self._tcaParent,self._tcaItem=resume.family,resume.parent,resume.item
            self._tcaLevel=resume.level or(resume.parent and 'parts'or 'items')
            self.mode='styles';Render(self)
            self:SetCurrentList(self.styleList);self:RefreshKeybinds()
        end
        return result
    end
    screen.OnHiding=function(self,...)
        self._tcaHidden=true
        HideInformation(self)
        if hiding then return hiding(self,...)end
    end
    local showMap=screen.ShowSelectedMotifOnMap
    screen.ShowSelectedMotifOnMap=function(self,...)
        if Active(self)then
            local item=Selected(self)
            if item and not item.parts and TC.antiquityMap then return TC.antiquityMap.Show(self,item,Source(item),self._tcaZone)end
        elseif showMap then return showMap(self,...)end
    end
    for _,descriptor in ipairs(screen.keybindStripDescriptor or {})do
        local callback,visible,name=descriptor.callback,descriptor.visible,descriptor.name
        if descriptor.keybind=='UI_SHORTCUT_PRIMARY' then
            descriptor.visible=function()
                if not Active(screen)then return visible and visible()or false end
                local item=Selected(screen)
                local row=screen.styleList:GetTargetData()
                return row and(row.antiquityFamily~=nil or item and item.parts~=nil)or false
            end
            descriptor.callback=function()
                if not Active(screen)then if callback then return callback()end;return end
                local item=Selected(screen)
                local row=screen.styleList:GetTargetData()
                if row and row.antiquityFamily then
                    screen._tcaFamily,screen._tcaLevel=row.antiquityFamily.key,'items'
                    screen._tcaParent=nil
                    screen._tcaItem=screen._tcaSelections and screen._tcaSelections[screen._tcaFamily]
                    Render(screen)
                elseif item and item.parts then
                    screen._tcaParent,screen._tcaLevel=item.key,'parts'
                    screen._tcaItem=screen._tcaSelections and screen._tcaSelections[item.key]
                    Render(screen)
                end
                screen:RefreshKeybinds()
            end
        elseif descriptor.keybind=='UI_SHORTCUT_SECONDARY' then
            descriptor.name=function()
                if not Active(screen)then return type(name)=='function' and name()or name end
                return TC.antiquityMap.Label(Selected(screen),Source(Selected(screen)))
            end
            descriptor.visible=function()
                if not Active(screen)then return visible and visible()or false end
                return Alive(screen)and TC.antiquityMap.CanShow(Selected(screen),Source(Selected(screen)))
            end
        elseif descriptor.keybind=='UI_SHORTCUT_NEGATIVE' then
            descriptor.callback=function()
                if not Active(screen)then if callback then return callback()end;return end
                if screen._tcaLevel=='parts'then
                    screen._tcaItem=screen._tcaParent;screen._tcaParent=nil
                    screen._tcaLevel='items';Render(screen)
                elseif screen._tcaLevel=='items'then
                    screen._tcaLevel='families';screen._tcaItem=nil;Render(screen)
                else screen:ShowCategories()end
                screen:RefreshKeybinds()
            end
        end
    end
    local group=screen.keybindStripDescriptor
    if group then
        local strip=KEYBIND_STRIP
        local registered=strip and strip.HasKeybindButtonGroup and strip:HasKeybindButtonGroup(group)
        if registered then strip:RemoveKeybindButtonGroup(group)end
        group[#group+1]={keybind='UI_SHORTCUT_LEFT_STICK',alignment=KEYBIND_STRIP_ALIGN_RIGHT,
            name=function()return screen._tcaShowAll and 'Hide completed codices' or 'Show all'end,
            visible=function()return Active(screen)end,
            callback=function()if Active(screen)then screen._tcaShowAll=not screen._tcaShowAll;Render(screen)end end}
        group[#group+1]={keybind='UI_SHORTCUT_RIGHT_STICK',
            name=function()return 'Zone: '..(screen._tcaZone and ZoneName(screen._tcaZone)or 'All')end,
            visible=function()return Active(screen)and Catalogue.Get()~=nil end,
            callback=function()if Active(screen)then ChooseZone(screen)end end}
        group[#group+1]={keybind='UI_SHORTCUT_RIGHT_SHOULDER',name='Details',
            visible=function()return Active(screen)and Selected(screen)~=nil end,
            callback=function()
                local item=Selected(screen)
                if Active(screen)and item and TC.antiquityInfo then
                    TC.antiquityInfo.Show(screen,item,Source(item),not item.parts and LeadStatus(item)or '')
                end
            end}
        if registered then strip:AddKeybindButtonGroup(group)end
    end
end
TC:RegisterArchiveModule(ID,{
    displayName='Antiquities',addonName='Tamriel Collections - Archive Antiquities',
    assetRoot='TamrielCollectionsAntiquities',screenControl='TCAQuestJournalTL',version=10002,supportsSearch=true,
    open=function(screen)
        Install(screen);screen._tcaHidden=nil
        screen.activeModuleId,screen.mode=ID,'styles'
        screen._tcaLevel,screen._tcaParent,screen._tcaItem='families',nil,nil
        ResetSearch(screen)
        if Catalogue.Get()and Catalogue.Get().error then Catalogue.Invalidate()end
        screen:SetCurrentList(screen.styleList);Render(screen)
    end,
    activateSearch=function(screen)
        screen:ActivateMotifSearch()
    end,
})
local function Invalidate()
    Catalogue.Invalidate()
    local screen=TC.questScreen
    if not screen or not Alive(screen)or screen._tcaRefreshQueued then return end
    screen._tcaRefreshQueued=true
    zo_callLater(function()
        screen._tcaRefreshQueued=nil
        if Alive(screen)then Render(screen)end
    end,0)
end
if EVENT_MANAGER then
    for _,event in ipairs({'EVENT_ACHIEVEMENT_UPDATED','EVENT_ACHIEVEMENT_AWARDED'})do
        if _G[event]then EVENT_MANAGER:RegisterForEvent('TCAAntiquityAchievements',_G[event],function()
            local screen=TC.questScreen
            if screen and Alive(screen)and Selected(screen)then ItemInfo(screen,Selected(screen))end
        end)end
    end
    for _,event in ipairs({'EVENT_ANTIQUITIES_UPDATED','EVENT_ANTIQUITY_UPDATED','EVENT_ANTIQUITY_LEAD_ACQUIRED'})do
        if _G[event]then EVENT_MANAGER:RegisterForEvent('TCAAntiquityProgress',_G[event],Invalidate)end
    end
    if EVENT_STYLE_LEARNED then
        EVENT_MANAGER:RegisterForEvent('TCAAntiquityMotifLearned',EVENT_STYLE_LEARNED,function()
            local model=Catalogue.Get()
            if model and #model.byFamily.motifs.items==0 then return end
            if model or Catalogue.IsBuilding()then Invalidate()end
        end)
    end
    local function CollectibleChanged(_,collectibleId)
        local model=Catalogue.Get()
        if model then
            if not next(model.collectibleIds)or collectibleId and not model.collectibleIds[collectibleId]then return end
        elseif not Catalogue.IsBuilding()then return end
        Invalidate()
    end
    for _,event in ipairs({'EVENT_COLLECTION_UPDATED','EVENT_COLLECTIBLES_UNLOCK_STATE_CHANGED','EVENT_COLLECTIBLE_UPDATED'})do
        if _G[event]then EVENT_MANAGER:RegisterForEvent('TCAAntiquityMountUnlock',_G[event],CollectibleChanged)end
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
TC.archiveLayout.Register("antiquities", { name = "Antiquities", intro = "Explore furnishings, rewards, motifs and zone treasures.\nTrack recovered items and unfinished codices.\n\nPress X to browse Antiquities.", hint = "Choose a reward or zone to view its items,\ncodex progress and lead sources." })
end

-- Keep the approved shared layout intact. Only this module replaces the
-- right-hand list with information and adds its current middle-panel path.
do
    local apply=TC.archiveLayout.Apply
    TC.archiveLayout.Apply=function(screen,...)
        local result=apply(screen,...)
        if result then NavigationLayout(screen)end
        return result
    end
end
