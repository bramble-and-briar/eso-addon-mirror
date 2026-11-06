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
    for _,id in ipairs(data.parts[item.id]or {})do Add(id)end
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
end
function Info.Update(screen,item)
    if not item then Info.Hide(screen);return end
    local rows=Info.Achievements(item)
    if #rows==0 then Info.Hide(screen);return end
    local label=screen._tcaAchievementHint
    if not label and WINDOW_MANAGER and CT_LABEL and screen.detailHeading then
        label=WINDOW_MANAGER:CreateControl('TCAAntiquityAchievementHint',screen.detailHeading,CT_LABEL)
        label:SetFont('ZoFontGamepad18');label:SetHeight(18);label:SetMaxLineCount(1)
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetAnchor(TOPLEFT,screen.detailHeading,BOTTOMLEFT,0,45)
        label:SetAnchor(TOPRIGHT,screen.detailHeading,BOTTOMRIGHT,0,45)
        label:SetDrawLayer(DL_CONTROLS);label:SetDrawLevel(91)
        if TEXT_WRAP_MODE_ELLIPSIS then label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)end
        screen._tcaAchievementHint=label
    end
    if label then
        local first=rows[1]
        local icon=first.icon and first.icon~=''and '|t16:16:'..first.icon..'|t 'or ''
        label:SetText((first.requirement and 'Required: 'or 'Achievement: ')..icon..first.name
            ..' ('..first.status..')'..(#rows>1 and ' +'..(#rows-1)or ''))
        label:SetColor(1,.92,.70,1);label:SetHidden(false)
    end
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
            gamepadInfo={dialogType=GAMEPAD_DIALOGS.BASIC},title={text='Antiquity details'},
            mainText={text=function(dialog)return dialog.data.text end},
            buttons={{keybind='DIALOG_NEGATIVE',text='Back'}},
        })
    end
    ZO_Dialogs_ShowGamepadDialog('TCA_ANTIQUITY_INFO',{text=Info.Describe(item,source,leadStatus)})
end
