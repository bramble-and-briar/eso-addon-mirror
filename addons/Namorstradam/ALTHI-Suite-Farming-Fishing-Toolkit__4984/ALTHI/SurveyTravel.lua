-- Native roster travel; paid shrine recall requires ESO's own confirmation.
local A=ALTHarvestItems
local shrine='|t24:24:EsoUI/Art/Icons/poi/poi_wayshrine_complete.dds|t'
local function zoneName(s)
    return zo_strlower(A:SurveyZoneBase(s))
end
function A:BuildSurveyTravelTargets()
    local targets={}; local me=zo_strlower(GetDisplayName())
    local function add(name,status,hasCharacter,reportedName,zoneId,kind)
        if type(name)~='string' or name=='' or zo_strlower(name)==me or not hasCharacter
            or status==nil or status==PLAYER_STATUS_OFFLINE or type(zoneId)~='number' or zoneId<=0
            or not CanJumpToPlayerInZone or not CanJumpToPlayerInZone(zoneId) then return end
        local native=GetZoneNameById and GetZoneNameById(zoneId) or reportedName
        if native=='' then native=reportedName end
        local key=zoneName(native); if key=='' then return end
        local candidate={name=name,zoneId=zoneId,kind=kind}
        local old=targets[key]
        if not old or (old.kind=='guild' and kind=='friend') or (old.kind==kind and zo_strlower(name)<zo_strlower(old.name)) then targets[key]=candidate end
    end
    if GetNumFriends and GetFriendInfo and GetFriendCharacterInfo and JumpToFriend then
        for i=1,GetNumFriends() do
            local name,_,status=GetFriendInfo(i)
            if status~=PLAYER_STATUS_OFFLINE and zo_strlower(name or '')~=me then
                local has,_,zone,_,_,_,_,id=GetFriendCharacterInfo(i)
                add(name,status,has,zone,id,'friend')
            end
        end
    end
    if GetNumGuilds and GetGuildId and GetNumGuildMembers and GetGuildMemberInfo and GetGuildMemberCharacterInfo and JumpToGuildMember then
        for i=1,GetNumGuilds() do
            local guild=GetGuildId(i)
            for index=1,GetNumGuildMembers(guild) do
                local name,_,_,status=GetGuildMemberInfo(guild,index)
                if status~=PLAYER_STATUS_OFFLINE and zo_strlower(name or '')~=me then
                    local has,_,zone,_,_,_,_,id=GetGuildMemberCharacterInfo(guild,index)
                    add(name,status,has,zone,id,'guild')
                end
            end
        end
    end
    self.surveyTravelTargets=targets; self.surveyTravelAt=self.Now(); self.surveyTravelDirty=nil
end
function A:SurveyTravelTarget(area)
    local key=zoneName(area); local map=self.surveyTravelTargets or {}
    -- Roman-numbered sites may keep their full display name. Match the base
    -- only against an actual eligible roster zone; never a dungeon's parent.
    return map[key] or map[key:gsub('%s+[ivx]+$','')]
end
function A:SurveyTravelTip(area)
    local target=self:SurveyTravelTarget(area)
    if not target then
        local node=self:SurveyRecallNode(area)
        if node then return string.format(self:T('SURVEY_RECALL_TIP'),node.name,self.Integer(node.cost),self.coin) end
        return self:T('SURVEY_RECALL_UNAVAILABLE')
    end
    local source=self:T(target.kind=='friend' and 'SURVEY_TRAVEL_FRIEND' or 'SURVEY_TRAVEL_GUILD')
    return string.format(self:T('SURVEY_TRAVEL_TARGET'),area,target.name,source)
end
function A:SurveyRecallNode(area)
    if not GetNumFastTravelNodes or not GetFastTravelNodeInfo or not GetFastTravelNodePOIIndicies
        or not GetZoneId or not GetZoneNameById or not GetRecallCost or not GetRecallCurrency
        or not GetFastTravelNodeOutboundOnlyInfo or not GetFastTravelNodeHouseId or not POI_TYPE_WAYSHRINE then return end
    local key=zoneName(area):gsub('%s+[ivx]+$',''); local best
    for index=1,GetNumFastTravelNodes() do
        local known,name,_,_,_,_,poiType,_,locked=GetFastTravelNodeInfo(index)
        if known and not locked and poiType==POI_TYPE_WAYSHRINE and GetFastTravelNodeHouseId(index)==0
            and not GetFastTravelNodeOutboundOnlyInfo(index) then
            local zone=GetFastTravelNodePOIIndicies(index)
            if zone and zone>0 and zoneName(GetZoneNameById(GetZoneId(zone)))==key then
                local cost=GetRecallCost(index)
                if type(cost)=='number' and cost>=0 and GetRecallCurrency(index)==CURT_MONEY
                    and (not best or cost<best.cost or (cost==best.cost and zo_strlower(name)<zo_strlower(best.name))) then
                    best={index=index,name=name,cost=cost}
                end
            end
        end
    end
    return best
end
function A:RequestSurveyTravel(area)
    if not self:SurveyWindowActive() or (IsUnitInCombat and IsUnitInCombat('player'))
        or (IsUnitDead and IsUnitDead('player')) or (IsInCampaign and IsInCampaign())
        or not CanLeaveCurrentLocationViaTeleport or not CanLeaveCurrentLocationViaTeleport()
        or (ZO_Dialogs_IsShowingDialog and ZO_Dialogs_IsShowingDialog()) then return false end
    self:BuildSurveyTravelTargets()
    if self:SurveyTravelTarget(area) then return self:TravelToSurveyZone(area) end
    local node=self:SurveyRecallNode(area)
    if not node or not ZO_Dialogs_ShowPlatformDialog or not GetRecallCooldown then return false end
    local _,premiumRemaining=GetRecallCooldown()
    if premiumRemaining~=0 then return false end -- Same restriction as the native map pin.
    self:StopSurveyBatch(); self:HideSuiteTip()
    -- Native dialog owns live cost, affordability, E/Alt and the eventual request.
    -- Nothing is deducted or travelled by ALTHI when this dialog opens/cancels.
    ZO_Dialogs_ShowPlatformDialog('RECALL_CONFIRM',{nodeIndex=node.index},{mainTextParams={node.name}})
    return true
end
function A:TravelToSurveyZone(area)
    if not self:SurveyWindowActive() or (IsUnitInCombat and IsUnitInCombat('player'))
        or (IsUnitDead and IsUnitDead('player'))
        or not CanLeaveCurrentLocationViaTeleport or not CanLeaveCurrentLocationViaTeleport() then return false end
    self:BuildSurveyTravelTargets() -- Revalidate before the explicit user action.
    local target=self:SurveyTravelTarget(area)
    if not target then self:DrawSurveyList(); return false end
    self:StopSurveyBatch()
    if target.kind=='friend' then JumpToFriend(target.name) else JumpToGuildMember(target.name) end
    return true -- A request, not a claim that the server completed the journey.
end
function A:RefreshSurveyTravelRows()
    local w=self.surveyWindow; if not w or not w.key then return end
    w.travelButtons=w.travelButtons or {}
    local width=w:GetWidth()
    for i,label in ipairs(w.rows) do
        local button=w.travelButtons[i]
        if not button then
            button=self:Button(w,'',30,function(control)
                self:RequestSurveyTravel(control.area)
            end)
            button:SetHandler('OnMouseEnter',function(c) self:ShowSuiteTip(c,TOP,self:SurveyTravelTip(c.area)) end)
            button:SetHandler('OnMouseExit',function() self:HideSuiteTip() end)
            w.travelButtons[i]=button
        end
        button:SetHidden(label:IsHidden()); button.area=label:GetText()
        if not label:IsHidden() then
            label:SetWidth(width-214)
            w.amounts[i]:ClearAnchors(); w.amounts[i]:SetAnchor(TOPLEFT,w,TOPLEFT,width-190,208+(i-1)*32); w.amounts[i]:SetWidth(104)
            button:ClearAnchors(); button:SetAnchor(TOPLEFT,w,TOPLEFT,width-78,208+(i-1)*32)
            button:SetText(self:SurveyTravelTarget(button.area) and shrine or self.coin)
        end
    end
end
local draw=A.DrawSurveyList
function A:DrawSurveyList()
    draw(self)
    if self.surveyWindow and self.surveyWindow.key and not self.db.ui.surveyMinimized then
        if not self.surveyTravelAt or self.Now()-self.surveyTravelAt>30 or (self.surveyTravelDirty and self.Now()-self.surveyTravelAt>=5) then self:BuildSurveyTravelTargets() end
        self:RefreshSurveyTravelRows()
    end
end
-- Roster refresh happens on an actual redraw/click, never on the idle ticker.
local initialize=A.Initialize
function A:Initialize()
    initialize(self)
    for _,event in pairs({EVENT_FRIEND_ADDED,EVENT_FRIEND_REMOVED,EVENT_FRIEND_PLAYER_STATUS_CHANGED,
        EVENT_FRIEND_CHARACTER_UPDATED,EVENT_GUILD_MEMBER_ADDED,EVENT_GUILD_MEMBER_REMOVED,
        EVENT_GUILD_MEMBER_PLAYER_STATUS_CHANGED,EVENT_GUILD_MEMBER_CHARACTER_UPDATED,EVENT_PLAYER_ACTIVATED}) do
        EVENT_MANAGER:RegisterForEvent('ALTHarvestItemsSurveyTravel',event,function() self.surveyTravelDirty=true end)
    end
end
