-- Complete item information and native achievement progress, read on selection.
local TC=TamrielCollections
local Info={}
TC.antiquityInfo=Info
local function Text(value)return zo_strformat and zo_strformat(value or '')or tostring(value or '')end
local function Zone(id)
    return id and id>0 and GetZoneNameById and Text(GetZoneNameById(id))or 'Not applicable'
end
local function Ids(item)
    local data=TC.antiquityAchievementLinks or {sets={},parts={}}
    local ids,seen={},{}
    local function Add(id)
        if id and id>0 and not seen[id]then seen[id]=true;ids[#ids+1]=id end
    end
    local parent=item.parts and item or item.parent
    if parent and parent.key:match('^set:')then
        for _,id in ipairs(data.sets[parent.id]or {})do Add(id)end
    end
    -- Native reward-set IDs and individual lead IDs are different namespaces.
    -- A whole Mythic numbered 53 must not inherit motif chapter 53's links.
    if not item.parts then for _,id in ipairs(data.parts[item.id]or {})do Add(id)end end
    if item.motifGroup then
        for _,part in ipairs(item.parts)do for _,id in ipairs(data.parts[part.id]or {})do Add(id)end end
    end
    local collectibleId=item.collectibleId or parent and parent.collectibleId
    if collectibleId and GetCollectibleLinkedAchievement then Add(GetCollectibleLinkedAchievement(collectibleId))end
    return ids
end
function Info.Achievements(item)
    local rows={}
    if not item or not GetAchievementInfo then return rows end
    for _,id in ipairs(Ids(item))do
        local name,description,_,icon,complete=GetAchievementInfo(id)
        if name and name~=''then
            local known,total=0,0
            if GetAchievementNumCriteria and GetAchievementCriterion then
                local count=GetAchievementNumCriteria(id)or 0
                if count<=256 then
                    for index=1,count do
                        local _,earned,required=GetAchievementCriterion(id,index)
                        known=known+math.max(0,earned or 0);total=total+math.max(0,required or 0)
                    end
                end
            end
            local status=complete and 'Complete'or total>0 and string.format('%d/%d',known,total)or 'Incomplete'
            rows[#rows+1]={id=id,name=Text(name),description=Text(description),icon=icon,
                complete=complete==true,status=status,
                requirement=TC.antiquityAchievementLinks and TC.antiquityAchievementLinks.requirements
                    and TC.antiquityAchievementLinks.requirements[id]==true or false}
        end
    end
    return rows
end
function Info.Hide(screen)
    if screen._tcaAchievementHint then screen._tcaAchievementHint:SetHidden(true)end
    if screen._tcaAchievementVisible then
        screen.detailAchievement:SetText('');screen._tcaAchievementVisible=nil
    end
end
function Info.Layout(screen,b)
    if not screen._tcaAchievementVisible then return end
    local label=screen.detailAchievement
    local height=math.max(58,label:GetTextHeight()or (screen._tcaAchievementCount or 1)*26)
    local top=b.footer-height-6
    local function Place(control,y,h)
        control:ClearAnchors();control:SetAnchor(TOPLEFT,b.root,TOPLEFT,b.right+24,y)
        control:SetAnchor(TOPRIGHT,b.root,TOPLEFT,b.edge-24,y);control:SetHeight(h)
    end
    -- Most rewards use the original two-row footer. If names wrap or a
    -- native collectible adds another achievement, use the source block's
    -- actual text heights to keep the complete stack below the source.
    local sourceHeight=screen.detailSource:GetTextHeight()or 88
    if height>58 and b.lower+76+sourceHeight+4>top then
        local y=b.lower+4
        for _,row in ipairs({{screen.detailWhereTitle,22},{screen.detailLocation,26},{screen.detailSource,88}})do
            local h=row[1]:GetTextHeight()or row[2]
            Place(row[1],y,h);y=y+h+3
        end
        top=y
    end
    Place(label,top,height)
end
function Info.Update(screen,item)
    -- Use the same bottom-right achievement field as Motifs. The header is
    -- reserved for the reward name and codex progress.
    if screen._tcaAchievementHint then screen._tcaAchievementHint:SetHidden(true)end
    if not item then Info.Hide(screen);return end
    local rows=Info.Achievements(item)
    local label=screen.detailAchievement
    if #rows==0 then label:SetText('');screen._tcaAchievementVisible=nil;return end
    local lines={}
    for index,row in ipairs(rows)do
        local icon=row.icon and row.icon~=''and '|t26:26:'..row.icon..'|t  'or ''
        local prefix=row.requirement and '|cFFEBB3Required:|r '
            or index==1 and '|cFFEBB3'..(#rows>1 and 'Achievements:'or 'Achievement:')..'|r 'or ''
        lines[#lines+1]=prefix..icon..row.name
    end
    label:SetMaxLineCount(math.max(2,#rows*2))
    label:SetText(table.concat(lines,'\n'))
    screen._tcaAchievementVisible=true
    screen._tcaAchievementCount=#rows
    local state=screen._tcArchiveLayout
    if state and state.active and state.moduleId=='antiquities'then Info.Layout(screen,state.bounds)end
end
function Info.Describe(item,source,leadStatus)
    local lines={item.name,string.format('Codex: %d/%d',item.known,item.total)}
    if item.description and item.description~=''then lines[#lines+1]='\n'..Text(item.description)end
    if item.collectibleId then
        lines[#lines+1]=item.unlocked==true and 'Collectible unlocked'or item.unlocked==false and 'Collectible locked'or 'Unlock status unavailable'
    end
    if not item.parts then
        lines[#lines+1]='Recovered: '..item.recovered
        lines[#lines+1]='Excavation: '..Zone(item.zoneId)
        lines[#lines+1]=leadStatus
        lines[#lines+1]='\nLead source: '..(source and source.location or 'Not yet verified')
        lines[#lines+1]=source and source.description or 'The map button shows the excavation zone until a source is verified.'
    end
    local rows=Info.Achievements(item)
    if #rows>0 then
        lines[#lines+1]='\nRelated achievements'
        for _,row in ipairs(rows)do
            lines[#lines+1]=(row.requirement and 'Required: 'or '')..row.name..' - '..row.status
            if row.description~=''then lines[#lines+1]=row.description end
        end
    end
    return table.concat(lines,'\n')
end
function Info.Show(screen,item,source,leadStatus)
    if not item or not ZO_Dialogs_RegisterCustomDialog or not ZO_Dialogs_ShowGamepadDialog
        or not GAMEPAD_DIALOGS or not GAMEPAD_DIALOGS.BASIC then return end
    if not Info.dialog then
        Info.dialog=true
        ZO_Dialogs_RegisterCustomDialog('TCA_ANTIQUITY_INFO',{
            gamepadInfo={dialogType=GAMEPAD_DIALOGS.BASIC,allowRightStickPassThrough=true},title={text='Antiquity details'},
            mainText={text=function(dialog)return dialog.data.text end},
            buttons={{keybind='DIALOG_NEGATIVE',text='Back'}},
        })
    end
    ZO_Dialogs_ShowGamepadDialog('TCA_ANTIQUITY_INFO',{text=Info.Describe(item,source,leadStatus)})
end
