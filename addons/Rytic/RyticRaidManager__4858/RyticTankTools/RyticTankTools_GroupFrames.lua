------------------------------------------------------------
-- RYTIC COMBAT & RAID TOOLS GROUP FRAMES v3.0.0
-- Assigned mechanic teams, manual overrides, prog groups, and range state.
------------------------------------------------------------

local RyticTank = RyticTank
RyticTank.GroupFrames = RyticTank.GroupFrames or {}
local Group = RyticTank.GroupFrames

local EM, WM = EVENT_MANAGER, WINDOW_MANAGER
local GetGroupSize = GetGroupSize
local GetGroupUnitTagByIndex = GetGroupUnitTagByIndex
local IsUnitGrouped = IsUnitGrouped
local IsUnitDead = IsUnitDead
local IsUnitBeingResurrected = IsUnitBeingResurrected
local DoesUnitHaveResurrectPending = DoesUnitHaveResurrectPending
local GetUnitName = GetUnitName
local GetUnitPower = GetUnitPower
local GetFrameTimeSeconds = GetFrameTimeSeconds
local GetUnitAttributeVisualizerEffectInfo = GetUnitAttributeVisualizerEffectInfo
local GetGroupMemberReadyState = GetGroupMemberReadyState
local GetGroupMemberSelectedRole = GetGroupMemberSelectedRole
local IsUnitOnline = IsUnitOnline
local GetTimeStamp = GetTimeStamp
local IsUnitInGroupSupportRange = IsUnitInGroupSupportRange
local math_max, math_min = math.max, math.min
local math_floor, math_ceil = math.floor, math.ceil
local tonumber, tostring = tonumber, tostring

local UPDATE_NAME = "RyticTankToolsGroupFramesUpdate"
local SHIELD_EVENT_PREFIX = "RyticTankToolsGroupShield"
local MAX_GROUP_SIZE = 24
local TEAM_COUNT = 2
local GROUP_B_AUTO_SHOW_SIZE = 7 -- show Team B automatically once a second 6-player team is needed
local FRAME_WIDTH, FRAME_HEIGHT, FRAME_GAP = 220, 40, 4
local rezPendingSince = {} -- session-only, keyed by account rather than visual frame
local TEAM_NAMES = {"TEAM A", "TEAM B"} -- fallback display names
local TEAM_COLORS = {{0.20,0.55,1.00}, {1.00,0.45,0.20}}
local TRUSTED_LEADERSHIP = {
    ["@rytic"] = true,
    ["@rytic's-wifey"] = true,
    ["@kimmi2510"] = true,
    ["@vonziklar"] = true,
}
local DEFAULT_ASSISTANTS = {}
local DEFAULT_ROLE_COLORS = {
    tank={0.20,0.85,0.30,1},
    healer={1.00,0.35,0.70,1},
    dps={0.20,0.55,1.00,1},
    unknown={0.45,0.45,0.48,1},
}

local function defaults()
    RyticTank.saved = RyticTank.saved or {}
    RyticTank.saved.groupFrames = RyticTank.saved.groupFrames or {
        enabled=true, locked=true, scale=1.0, x=40, y=220,
        columns=2, showBarrier=true,
        showReadyCheck=true, showRange=true, rangeMeters=15,
        assignmentPreset="Default", assignments={}, progGroups={}, teamNames={"TEAM A","TEAM B"}, dps={}, dpsSource="LibGroupCombatStats",
        roleColors={tank={0.20,0.85,0.30,1},healer={1.00,0.35,0.70,1},dps={0.20,0.55,1.00,1}}, nameDisplay="GAMER TAG", offlineSince={}, deathCounts={}, deathDebounce={}, savedGroupList={}, assistants={}
    }
    local s = RyticTank.saved.groupFrames
    s.assignments = s.assignments or {}
    s.progGroups = s.progGroups or {}
    s.teamNames = s.teamNames or {"TEAM A","TEAM B"}
    s.teamNames[1] = (s.teamNames[1] and s.teamNames[1] ~= "") and s.teamNames[1] or "TEAM A"
    s.teamNames[2] = (s.teamNames[2] and s.teamNames[2] ~= "") and s.teamNames[2] or "TEAM B"
    s.dps = s.dps or {}
    s.roleColors = s.roleColors or {}
    s.offlineSince = s.offlineSince or {}
    s.deathCounts = s.deathCounts or {}
    s.deathDebounce = s.deathDebounce or {}
    s.savedGroupList = s.savedGroupList or {}
    s.assistants = s.assistants or {}
    if s.assistantDefaultsSeeded ~= true then
        for account in pairs(DEFAULT_ASSISTANTS) do s.assistants[account]=true end
        s.assistantDefaultsSeeded=true
    end
    for role,color in pairs(DEFAULT_ROLE_COLORS) do
        if role ~= "unknown" and not s.roleColors[role] then
            s.roleColors[role]={color[1],color[2],color[3],color[4]}
        end
    end
    if s.showReadyCheck == nil then s.showReadyCheck=true end
    if s.showRange == nil then s.showRange=true end
    if s.rangeMeters == nil then s.rangeMeters=15 end
    if s.nameDisplay == nil then s.nameDisplay="GAMER TAG" end
    return s
end

local function clamp(v, lo, hi)
    return math_max(lo, math_min(hi, tonumber(v) or lo))
end

local function normalize(name)
    return zo_strformat("<<z:1>>", tostring(name or "")):lower():gsub("%s+", "")
end

local function makeLabel(parent, font, width, height)
    local label=WM:CreateControl(nil,parent,CT_LABEL)
    label:SetFont(font); label:SetDimensions(width,height)
    label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetMouseEnabled(false)
    return label
end

local shieldCache = {}

local function getAccountName(tag)
    return (GetUnitDisplayName and GetUnitDisplayName(tag)) or (GetUnitName and GetUnitName(tag)) or tag or ""
end

local function getLeaderTag()
    local size=GetGroupSize and GetGroupSize() or 0
    for i=1,size do
        local tag=GetGroupUnitTagByIndex(i)
        if tag and IsUnitGroupLeader and IsUnitGroupLeader(tag) then return tag end
    end
    if IsUnitGroupLeader and IsUnitGroupLeader("player") then return "player" end
end

function Group.SetSessionAssistants(list)
    Group.sessionAssistants={}
    Group.sessionAssistantsInitialized=true
    for _,account in ipairs(list or {}) do
        local key=normalize(account)
        if key~="" then Group.sessionAssistants[key]=true end
    end
end

local function trustedLeaderActive()
    local tag=getLeaderTag()
    local leader=tag and normalize(getAccountName(tag)) or ""
    return TRUSTED_LEADERSHIP[leader] == true
end

function Group.IsAccountAssistant(account)
    local key=normalize(account)
    if key=="" then return false end

    if not Group.IsLocalLeader() and Group.sessionAssistantsInitialized then
        return Group.sessionAssistants and Group.sessionAssistants[key] == true
    end

    Group.sessionAssistantOverrides=Group.sessionAssistantOverrides or {}
    if Group.sessionAssistantOverrides[key] ~= nil then
        return Group.sessionAssistantOverrides[key] == true
    end

    if trustedLeaderActive() and TRUSTED_LEADERSHIP[key] then
        local tag=getLeaderTag()
        local leader=tag and normalize(getAccountName(tag)) or ""
        return key ~= leader
    end

    -- Without a published crown list, every grouped Rytic user starts as an
    -- assistant.  Only this group's explicit override can revoke that access;
    -- old account-wide assistant flags must not carry into a new pug.
    return true
end

function Group.IsLocalLeader()
    return IsUnitGroupLeader and IsUnitGroupLeader("player") or false
end

function Group.IsLocalAssistant()
    return Group.IsAccountAssistant(getAccountName("player"))
end

function Group.CanManageAssignments()
    return Group.IsLocalLeader() or Group.IsLocalAssistant()
end

function Group.SetAssistant(account,enabled)
    if not Group.IsLocalLeader() then return false,"Only the current ESO group leader can designate Rytic assistants" end
    local key=normalize(account)
    if key=="" then return false,"Invalid account" end
    if key==normalize(getAccountName("player")) then return false,"The group leader is already the authority" end
    -- ASSIST/REMOVE applies only to this group session.
    Group.sessionAssistantOverrides=Group.sessionAssistantOverrides or {}
    Group.sessionAssistantOverrides[key]=enabled and true or false
    return true
end

function Group.ToggleAssistant(account)
    local enabled=not Group.IsAccountAssistant(account)
    local ok,err=Group.SetAssistant(account,enabled)
    return ok,err,enabled
end

local function postDeathCount()
    local s=defaults(); local rows={}
    local size=GetGroupSize and GetGroupSize() or 0
    for i=1,size do
        local tag=GetGroupUnitTagByIndex(i)
        if tag then
            local account=getAccountName(tag)
            rows[#rows+1]={name=account,count=tonumber(s.deathCounts[normalize(account)]) or 0}
        end
    end
    table.sort(rows,function(a,b) return a.count>b.count or (a.count==b.count and a.name<b.name) end)
    local parts={}
    for _,row in ipairs(rows) do parts[#parts+1]=row.name..": "..row.count end
    if #parts==0 then d("|cFFAA00Rytic: no group death data.|r"); return end
    CHAT_SYSTEM:Maximize(); CHAT_SYSTEM.primaryContainer:FadeIn()
    StartChatInput("/p Group deaths: "..table.concat(parts,", "))
end

local function saveCurrentGroupList()
    local s=defaults(); s.savedGroupList={}
    local size=GetGroupSize and GetGroupSize() or 0
    for i=1,size do
        local tag=GetGroupUnitTagByIndex(i)
        if tag then
            local account=getAccountName(tag)
            if account~="" then s.savedGroupList[#s.savedGroupList+1]=account end
        end
    end
    d("|c55FF55Rytic: saved "..tostring(#s.savedGroupList).." group members.|r")
end

local function inviteGuildOne(account)
    if not account or account=="" then return end
    if not GetNumGuilds or GetNumGuilds()<1 then d("|cFF4444Rytic: you are not in a guild.|r"); return end
    local guildId=GetGuildId(1)
    if not guildId or guildId==0 then d("|cFF4444Rytic: guild slot 1 is unavailable.|r"); return end
    if DoesPlayerHaveGuildPermission and not DoesPlayerHaveGuildPermission(guildId,GUILD_PERMISSION_INVITE) then
        d("|cFF4444Rytic: no invite permission for guild slot 1.|r"); return
    end
    GuildInvite(guildId,account)
end

local function showMemberMenu(frame)
    local tag=frame and frame.unitTag
    if not tag or not DoesUnitExist(tag) then return end
    local account=getAccountName(tag)
    local isPlayer=(GetUnitName(tag)==GetUnitName("player"))
    local isLeader=IsUnitGroupLeader and IsUnitGroupLeader("player")
    local online=not IsUnitOnline or IsUnitOnline(tag)
    ClearMenu()

    -- PTE = the raid shorthand for P -> T -> E: use ESO's native instant
    -- instance-exit API instead of simulating keyboard input or opening scenes.
    if ExitInstanceImmediately then
        AddMenuItem("PTE - Port Out",function() ExitInstanceImmediately() end)
    end

    if isPlayer then
        AddMenuItem(GetString(SI_GROUP_LIST_MENU_LEAVE_GROUP),function() GroupLeave() end)
    elseif online then
        AddMenuItem("Whisper",function()
            if account and account~="" and ZO_GetChatSystem then
                local chatSystem=ZO_GetChatSystem()
                if chatSystem and chatSystem.StartTextEntry then
                    chatSystem:StartTextEntry("",CHAT_CHANNEL_WHISPER,account,true)
                end
            end
        end)
        AddMenuItem(GetString(SI_SOCIAL_MENU_JUMP_TO_PLAYER),function() JumpToGroupMember(account) end)
        AddMenuItem("Invite to Guild 1",function() inviteGuildOne(account) end)
    end
    local memberName=GetUnitName(tag) or account
    AddMenuItem("Assign Team A (lock)",function() if Group.Assign(memberName,1,true) then Group.PushOut() end end)
    AddMenuItem("Assign Team B (lock)",function() if Group.Assign(memberName,2,true) then Group.PushOut() end end)
    AddMenuItem("Unlock team assignment",function()
        local s=defaults(); local key=normalize(memberName); local a=s.assignments[key] or s.assignments[normalize(account)]
        if a then a.locked=false end
        Group.Refresh()
    end)
    AddMenuItem("Post death count",postDeathCount)
    AddMenuItem("Save group list",saveCurrentGroupList)
    if isLeader and not isPlayer then
        local assistant=Group.IsAccountAssistant(account)
        AddMenuItem(assistant and "Remove Rytic Assistant" or "Make Rytic Assistant",function()
            local ok,err,enabled=Group.ToggleAssistant(account)
            if ok then d((enabled and "|c55FF55Rytic: Assistant enabled for " or "|cFFAA00Rytic: Assistant removed for ")..account..".|r")
            elseif err then d("|cFF4444Rytic: "..tostring(err)..".|r") end
        end)
    end
    if isLeader then
        AddMenuItem(GetString(SI_GROUP_LIST_READY_CHECK_BIND),function()
            BeginGroupElection(GROUP_ELECTION_TYPE_GENERIC_UNANIMOUS,ZO_GROUP_ELECTION_DESCRIPTORS.READY_CHECK)
        end)
        if not isPlayer then
            if GroupPromote then
                AddMenuItem(GetString(SI_GROUP_LIST_MENU_PROMOTE_TO_LEADER),function() GroupPromote(tag) end)
            end
            AddMenuItem(GetString(SI_GROUP_LIST_MENU_KICK_FROM_GROUP),function() GroupKick(tag) end)
        end
    end
    ShowMenu(frame)
end

local function createFrame(parent,index)
    local frame=WM:CreateControl(nil,parent,CT_BACKDROP)
    frame:SetDimensions(FRAME_WIDTH,FRAME_HEIGHT)
    frame:SetMouseEnabled(true)
    frame:SetCenterColor(.025,.03,.04,.92)
    frame:SetEdgeColor(.20,.22,.27,1)
    frame:SetEdgeTexture("",1,1,2,0)
    frame.healthBack=WM:CreateControl(nil,frame,CT_BACKDROP)
    frame.healthBack:SetMouseEnabled(false)
    frame.healthBack:SetAnchor(TOPLEFT,frame,TOPLEFT,2,2)
    frame.healthBack:SetAnchor(BOTTOMRIGHT,frame,BOTTOMRIGHT,-2,-2)
    frame.healthBack:SetCenterColor(.12,.035,.045,.95)
    frame.healthBack:SetEdgeColor(0,0,0,0)
    frame.health=WM:CreateControl(nil,frame.healthBack,CT_BACKDROP)
    frame.health:SetMouseEnabled(false)
    frame.health:SetAnchor(TOPLEFT,frame.healthBack,TOPLEFT,0,0)
    frame.health:SetAnchor(BOTTOMLEFT,frame.healthBack,BOTTOMLEFT,0,0)
    frame.health:SetWidth(1)
    frame.health:SetCenterColor(.15,.78,.24,.78)
    frame.health:SetEdgeColor(0,0,0,0)
    -- Damage-shield overlay. Same max-health-scaled approach used by Bandits:
    -- shield width = min(shield / maxHealth, 1) * frame width.
    frame.shield=WM:CreateControl(nil,frame.healthBack,CT_BACKDROP)
    frame.shield:SetMouseEnabled(false)
    frame.shield:SetAnchor(TOPLEFT,frame.healthBack,TOPLEFT,0,0)
    frame.shield:SetAnchor(BOTTOMLEFT,frame.healthBack,BOTTOMLEFT,0,0)
    frame.shield:SetWidth(1)
    frame.shield:SetCenterColor(1.00,.70,.70,.88)
    frame.shield:SetEdgeColor(0,0,0,0)
    frame.shield:SetDrawLayer(DL_OVERLAY)
    frame.shield:SetHidden(true)
    frame.name=makeLabel(frame,"ZoFontGameBold",145,20)
    frame.name:SetAnchor(TOPLEFT,frame,TOPLEFT,8,2)
    frame.status=makeLabel(frame,"ZoFontGameSmall",145,16)
    frame.status:SetAnchor(BOTTOMLEFT,frame,BOTTOMLEFT,8,-1)
    frame.status:SetColor(.80,.82,.86,1)
    -- Explicit death indicator. ESO can report zero health before/while the
    -- group-unit death flag settles, so updateFrame drives this from both.
    frame.dead=makeLabel(frame,"ZoFontWinH2",FRAME_WIDTH-8,FRAME_HEIGHT)
    frame.dead:SetAnchor(CENTER,frame,CENTER,0,0)
    frame.dead:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    frame.dead:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    frame.dead:SetColor(1,.08,.08,1)
    frame.dead:SetText("DEAD")
    frame.dead:SetHidden(true)
    frame.barrier=makeLabel(frame,"ZoFontGameBold",62,18)
    frame.barrier:SetAnchor(TOPRIGHT,frame,TOPRIGHT,-5,2)
    frame.barrier:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    frame.barrier:SetColor(1,.72,.72,1)
    frame.ready=makeLabel(frame,"ZoFontGameBold",22,22)
    frame.ready:SetAnchor(TOPRIGHT,frame,TOPRIGHT,-68,0)
    frame.ready:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    frame.ready:SetHidden(true)
    frame.range=makeLabel(frame,"ZoFontGameBold",18,18)
    frame.range:SetAnchor(BOTTOMRIGHT,frame,BOTTOMRIGHT,-30,-1)
    frame.range:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    frame.range:SetText("•")
    frame.range:SetHidden(true)
    frame.teamBadge=makeLabel(frame,"ZoFontGameSmall",38,16)
    frame.teamBadge:SetAnchor(BOTTOMRIGHT,frame,BOTTOMRIGHT,-48,-1)
    frame.teamBadge:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    frame.teamBadge:SetHidden(true)
    frame.index=index

    -- Bandits-style quick location check: hovering a member shows the zone/location
    -- ESO currently reports for that group unit (trial, house, overland zone, etc.).
    frame:SetHandler("OnMouseEnter",function(self)
        local tag=self.unitTag
        if not tag or not DoesUnitExist(tag) then return end

        local zoneName=(GetUnitZone and GetUnitZone(tag)) or ""
        if zoneName==nil or zoneName=="" then zoneName="Location unavailable" end

        InitializeTooltip(InformationTooltip,self,TOPLEFT,0,0,TOPRIGHT)
        SetTooltipText(InformationTooltip,zoneName)
    end)
    frame:SetHandler("OnMouseExit",function(self)
        ClearTooltip(InformationTooltip)
    end)
    frame:SetHandler("OnMouseUp",function(self,button,upInside)
        if button==MOUSE_BUTTON_INDEX_RIGHT and upInside then showMemberMenu(self) end
    end)
    return frame
end

local function formatNumber(value)
    value=math_max(0,math_floor(tonumber(value) or 0))
    if value>=1000000 then return string.format("%.1fm",value/1000000) end
    if value>=1000 then return string.format("%.1fk",value/1000) end
    return tostring(value)
end

local function getBarrier(tag)
    local cached=shieldCache[tag]
    if cached~=nil then return cached end
    if not GetUnitAttributeVisualizerEffectInfo then return 0 end
    local value=GetUnitAttributeVisualizerEffectInfo(
        tag,ATTRIBUTE_VISUAL_POWER_SHIELDING,STAT_MITIGATION,
        ATTRIBUTE_HEALTH,POWERTYPE_HEALTH)
    value=math_max(0,tonumber(value) or 0)
    shieldCache[tag]=value
    return value
end

local function setShield(frame,tag,shieldValue,maxHealth)
    shieldValue=math_max(0,tonumber(shieldValue) or 0)
    maxHealth=math_max(0,tonumber(maxHealth) or 0)
    if not frame.shield or shieldValue<=0 or maxHealth<=0 then
        if frame.shield then frame.shield:SetHidden(true) end
        return
    end
    local pct=clamp(shieldValue/maxHealth,0,1)
    frame.shield:SetWidth(math_max(1,(FRAME_WIDTH-4)*pct))
    frame.shield:SetHidden(false)
end

local function setHealth(frame,current,maximum,r,g,b,a)
    local pct=maximum and maximum>0 and clamp(current/maximum,0,1) or 0
    frame.health:SetWidth(math_max(1,(FRAME_WIDTH-4)*pct))
    frame.health:SetHidden(pct<=0)
    -- Keep the entire unit tile keyed to the selected group role color.
    -- The unfilled health area is a darker shade of the same role color.
    frame.healthBack:SetCenterColor(r * 0.30, g * 0.30, b * 0.30, 0.98)
    frame.health:SetCenterColor(r, g, b, 0.78)
end

local function updateReady(frame,tag,settings)
    if not settings.showReadyCheck or not GetGroupMemberReadyState then frame.ready:SetHidden(true); return end
    local state=GetGroupMemberReadyState(tag)
    if state==nil then frame.ready:SetHidden(true); return end
    if READY_CHECK_READY and state==READY_CHECK_READY then frame.ready:SetText("|c55FF55✓|r")
    elseif READY_CHECK_NOT_READY and state==READY_CHECK_NOT_READY then frame.ready:SetText("|cFF4444✕|r")
    else frame.ready:SetText("|cBBBBBB?|r") end
    frame.ready:SetHidden(false)
end

local function updateRange(frame,tag,settings,r,g,b,a)
    -- Configurable true-distance range check for grouped players. ESO world-position
    -- coordinates are compared directly, avoiding a square root on every refresh.
    frame.range:SetHidden(true)
    if not settings.showRange then return end
    local inRange=nil
    if GetUnitWorldPosition then
        local pZone,px,py,pz=GetUnitWorldPosition("player")
        local uZone,ux,uy,uz=GetUnitWorldPosition(tag)
        if pZone and uZone and pZone==uZone and px and ux then
            local dx,dy,dz=px-ux,py-uy,pz-uz
            local limit=clamp(settings.rangeMeters or 15,5,50)*100
            inRange=(dx*dx+dy*dy+dz*dz) <= (limit*limit)
        end
    end
    -- Safe fallback when world positions are unavailable. This fallback uses ESO's
    -- built-in group support range and therefore is not user-adjustable.
    if inRange==nil and IsUnitInGroupSupportRange then inRange=IsUnitInGroupSupportRange(tag) end
    if inRange == false then
        local shade=0.42
        frame:SetCenterColor(r*shade,g*shade,b*shade,0.98)
        frame:SetEdgeColor(r*shade,g*shade,b*shade,a or 1)
        frame.healthBack:SetCenterColor(r*0.16,g*0.16,b*0.16,0.98)
        frame.health:SetCenterColor(r*shade,g*shade,b*shade,0.82)
    end
end

local function teamOf(name)
    local a=defaults().assignments[normalize(name)]
    return a and tonumber(a.team) or nil
end

local function resolveMemberIdentity(name)
    local wanted=normalize(name)
    local size=GetGroupSize and GetGroupSize() or 0
    for i=1,size do
        local tag=GetGroupUnitTagByIndex and GetGroupUnitTagByIndex(i) or nil
        if tag then
            local account=getAccountName(tag)
            local charName=GetUnitName and GetUnitName(tag) or ""
            if wanted==normalize(account) or wanted==normalize(charName) then
                return account,charName
            end
        end
    end
    return nil,nil
end

local function getDps(name)
    return tonumber(defaults().dps[normalize(name)]) or 0
end

local function setTeam(name,team,locked)
    local s=defaults(); local key=normalize(name)
    if key=="" then return false end
    s.assignments[key]={name=tostring(name),team=clamp(team,1,TEAM_COUNT),locked=locked~=false}
    return true
end

local function canonicalizeCurrentAssignments()
    local s=defaults()
    local size=GetGroupSize and GetGroupSize() or 0
    for i=1,size do
        local tag=GetGroupUnitTagByIndex and GetGroupUnitTagByIndex(i) or nil
        if tag then
            local account=getAccountName(tag)
            local charName=GetUnitName and GetUnitName(tag) or ""
            local accountKey=normalize(account)
            local charKey=normalize(charName)
            local a=(accountKey~="" and s.assignments[accountKey]) or (charKey~="" and s.assignments[charKey]) or nil
            if a and a.team then
                local v={name=(account~="" and account or charName),team=clamp(a.team,1,TEAM_COUNT),locked=a.locked~=false}
                if accountKey~="" then s.assignments[accountKey]={name=v.name,team=v.team,locked=v.locked} end
                if charKey~="" then s.assignments[charKey]={name=v.name,team=v.team,locked=v.locked} end
            end
        end
    end
end

local function refreshPositionsBoard()
    local P=RyticTank.Positions
    if P and P.Refresh then P.Refresh() end
end

function Group.Assign(name,team,locked)
    if IsUnitGrouped and IsUnitGrouped("player") and not Group.CanManageAssignments() then
        d("|cFFAA00Rytic: Team assignments require group lead or Rytic assistant authority.|r")
        return false
    end
    local account,charName=resolveMemberIdentity(name)
    if account and account~="" then
        setTeam(account,team,locked)
        if charName and charName~="" then setTeam(charName,team,locked) end
        canonicalizeCurrentAssignments()
        if Group.Refresh then Group.Refresh() end
        refreshPositionsBoard()
        return true
    end
    local ok=setTeam(name,team,locked)
    canonicalizeCurrentAssignments()
    if ok and Group.Refresh then Group.Refresh() end
    if ok then refreshPositionsBoard() end
    return ok
end

function Group.ClearAssignments()
    defaults().assignments={}
    Group.Refresh()
    refreshPositionsBoard()
end

function Group.SetDps(name,value)
    defaults().dps[normalize(name)]=tonumber(value) or 0
end

function Group.GetSharedDps(name)
    return getDps(name)
end

function Group.GetTeam(name)
    return teamOf(name)
end

function Group.GetTeamName(team)
    team=clamp(team,1,2)
    return tostring(defaults().teamNames[team] or TEAM_NAMES[team])
end

function Group.SetTeamName(team,name)
    if IsUnitGrouped and IsUnitGrouped("player") and not Group.CanManageAssignments() then
        return false,"Team names require group lead or Rytic assistant authority"
    end
    team=clamp(team,1,2)
    name=zo_strtrim(tostring(name or ""))
    if name=="" then name=TEAM_NAMES[team] end
    if #name>18 then name=string.sub(name,1,18) end
    defaults().teamNames[team]=name
    Group.Refresh()
    refreshPositionsBoard()
    if Group.PushOut then Group.PushOut() end
    return true
end

function Group.GetRangeMeters()
    return clamp(defaults().rangeMeters or 15,5,50)
end

function Group.SetRangeMeters(meters)
    defaults().rangeMeters=clamp(meters,5,50)
    Group.Refresh()
    return defaults().rangeMeters
end

-- LibGroupCombatStats reports DPS in thousands. Cache by both character and
-- account name so assignments remain stable even if the visual name mode changes.
local function cacheSharedDps(unitTag,data)
    if not unitTag or not data then return end
    local value=math_max(0,tonumber(data.dps) or 0) * 1000
    local s=defaults()
    local charName=GetUnitName and GetUnitName(unitTag) or ""
    local account=GetUnitDisplayName and GetUnitDisplayName(unitTag) or ""
    if charName~="" then s.dps[normalize(charName)]=value end
    if account~="" then s.dps[normalize(account)]=value end
end

local function seedSharedDps()
    if not Group.combatStats or not Group.combatStats.GetUnitDPS then return end
    local size=GetGroupSize and GetGroupSize() or 0
    for i=1,size do
        local tag=GetGroupUnitTagByIndex(i)
        if tag then cacheSharedDps(tag,Group.combatStats:GetUnitDPS(tag)) end
    end
end

local function initCombatStats()
    if Group.combatStats or Group.combatStatsTried then return Group.combatStats~=nil end
    Group.combatStatsTried=true
    local lib=LibGroupCombatStats
    if not lib or not lib.RegisterAddon then return false end
    local obj=lib.RegisterAddon("RyticTankTools",{"DPS"})
    if not obj then return false end
    Group.combatStats=obj
    local groupEvent=lib.EVENT_GROUP_DPS_UPDATE or "EVENT_GROUP_DPS_UPDATE"
    local playerEvent=lib.EVENT_PLAYER_DPS_UPDATE or "EVENT_PLAYER_DPS_UPDATE"
    obj:RegisterForEvent(groupEvent,cacheSharedDps)
    obj:RegisterForEvent(playerEvent,cacheSharedDps)
    seedSharedDps()
    return true
end

local function getRoleKey(tag)
    if not GetGroupMemberSelectedRole then return "unknown" end
    local role=GetGroupMemberSelectedRole(tag)
    if LFG_ROLE_TANK and role==LFG_ROLE_TANK then return "tank" end
    if LFG_ROLE_HEAL and role==LFG_ROLE_HEAL then return "healer" end
    if LFG_ROLE_DPS and role==LFG_ROLE_DPS then return "dps" end
    return "unknown"
end

local function collectMembers()
    local out={}
    local size=GetGroupSize and GetGroupSize() or 0
    for i=1,size do
        local tag=GetGroupUnitTagByIndex(i)
        if tag then
            local name=GetUnitName(tag) or tag
            local account=getAccountName(tag)
            local role=getRoleKey(tag)
            local saved=defaults().assignments[normalize(name)] or defaults().assignments[normalize(account)]
            out[#out+1]={tag=tag,name=name,account=account,role=role,dps=getDps(name)>0 and getDps(name) or getDps(account),saved=saved}
        end
    end
    return out
end

function Group.GetMembers()
    initCombatStats()
    seedSharedDps()
    return collectMembers()
end

-- Exact subset search for the unlocked DDs. A raid has few enough DDs that
-- checking every legal subset is tiny, and gives a genuinely closest DPS split.
local function bestDpsSubset(dds,countA,baseA,baseB)
    local n=#dds
    local bestMask,bestDiff=nil,nil
    local limit=2^n
    for mask=0,limit-1 do
        local count,sum=0,0
        for i=1,n do
            if math_floor(mask/2^(i-1))%2==1 then count=count+1; sum=sum+dds[i].dps end
        end
        if count==countA then
            local total=0
            for i=1,n do total=total+dds[i].dps end
            local diff=math.abs((baseA+sum)-(baseB+(total-sum)))
            if not bestDiff or diff<bestDiff then bestDiff,bestMask=diff,mask end
        end
    end
    return bestMask or 0
end

function Group.AutoBalance()
    if IsUnitGrouped and IsUnitGrouped("player") and not Group.CanManageAssignments() then
        d("|cFFAA00Rytic: Auto Arrange requires group lead or Rytic assistant authority.|r")
        return false
    end
    initCombatStats(); seedSharedDps()
    local members=collectMembers()
    local totals={0,0}; local counts={0,0}; local dpsCounts={0,0}; local unlockedDps={}; local unlockedSupport={}

    -- Manual locks are hard constraints and are never moved by Auto Arrange.
    for _,m in ipairs(members) do
        if m.saved and m.saved.locked and m.saved.team then
            local t=clamp(m.saved.team,1,2)
            totals[t]=totals[t]+m.dps; counts[t]=counts[t]+1
            if m.role=="dps" then dpsCounts[t]=dpsCounts[t]+1 end
        elseif m.role=="dps" then
            unlockedDps[#unlockedDps+1]=m
        else
            unlockedSupport[#unlockedSupport+1]=m
        end
    end

    -- Put tanks/healers/unknown support on the side with fewer members of that role.
    table.sort(unlockedSupport,function(a,b) return a.role<b.role or (a.role==b.role and normalize(a.name)<normalize(b.name)) end)
    local roleCounts={tank={0,0},healer={0,0},unknown={0,0}}
    for _,m in ipairs(members) do
        if m.saved and m.saved.locked and m.saved.team and roleCounts[m.role] then roleCounts[m.role][m.saved.team]=roleCounts[m.role][m.saved.team]+1 end
    end
    for _,m in ipairs(unlockedSupport) do
        local rc=roleCounts[m.role] or roleCounts.unknown
        local t=(rc[1]<rc[2]) and 1 or ((rc[2]<rc[1]) and 2 or (counts[1]<=counts[2] and 1 or 2))
        setTeam(m.name,t,false); rc[t]=rc[t]+1; counts[t]=counts[t]+1
    end

    -- Split DD slots as evenly as possible, then choose the exact subset whose
    -- combined shared DPS makes Team A and Team B closest after locked DDs.
    table.sort(unlockedDps,function(a,b) return a.dps>b.dps or (a.dps==b.dps and normalize(a.name)<normalize(b.name)) end)
    local totalDpsCount=dpsCounts[1]+dpsCounts[2]+#unlockedDps
    local targetA=math_ceil(totalDpsCount/2)
    local needA=clamp(targetA-dpsCounts[1],0,#unlockedDps)
    local mask=bestDpsSubset(unlockedDps,needA,totals[1],totals[2])
    for i,m in ipairs(unlockedDps) do
        local t=(math_floor(mask/2^(i-1))%2==1) and 1 or 2
        setTeam(m.name,t,false); totals[t]=totals[t]+m.dps; counts[t]=counts[t]+1; dpsCounts[t]=dpsCounts[t]+1
    end
    Group.Refresh()
    Group.PushOut()
    d(string.format("|c55FF55Rytic: Auto Arrange complete. A %.1fk / B %.1fk shared DPS.|r",totals[1]/1000,totals[2]/1000))
    return totals[1],totals[2]
end

function Group.AutoBalanceDpsOnly()
    if IsUnitGrouped and IsUnitGrouped("player") and not Group.CanManageAssignments() then
        d("|cFFAA00Rytic: Auto DPS Teams requires group lead or Rytic assistant authority.|r")
        return false
    end
    initCombatStats(); seedSharedDps()
    local members=collectMembers(); local dds={}; local totals={0,0}; local counts={0,0}
    -- Supports keep their existing team. Only DPS are redistributed.
    for _,m in ipairs(members) do
        if m.role=="dps" then
            if m.saved and m.saved.locked and m.saved.team then
                local t=clamp(m.saved.team,1,2); totals[t]=totals[t]+m.dps; counts[t]=counts[t]+1
            else dds[#dds+1]=m end
        end
    end
    table.sort(dds,function(a,b) return a.dps>b.dps or (a.dps==b.dps and normalize(a.name)<normalize(b.name)) end)
    local targetA=math_ceil((counts[1]+counts[2]+#dds)/2)
    local needA=clamp(targetA-counts[1],0,#dds)
    local mask=bestDpsSubset(dds,needA,totals[1],totals[2])
    for i,m in ipairs(dds) do
        local t=(math_floor(mask/2^(i-1))%2==1) and 1 or 2
        setTeam(m.account~="" and m.account or m.name,t,false)
        setTeam(m.name,t,false)
        totals[t]=totals[t]+m.dps; counts[t]=counts[t]+1
    end
    canonicalizeCurrentAssignments(); Group.Refresh(); Group.PushOut()
    d(string.format("|c55FF55Rytic: DPS teams arranged. %s %.1fk / %s %.1fk.|r",Group.GetTeamName(1),totals[1]/1000,Group.GetTeamName(2),totals[2]/1000))
    return totals[1],totals[2]
end

local function copyPlain(value)
    if type(value)~="table" then return value end
    local out={}; for k,v in pairs(value) do out[copyPlain(k)]=copyPlain(v) end; return out
end

function Group.SaveProgGroupSnapshot(name,rows,teamNames,positions)
    local s=defaults(); name=zo_strtrim(tostring(name or s.assignmentPreset or "Default")); if name=="" then name="Default" end
    local assignments={}
    for _,row in ipairs(rows or {}) do
        if type(row)=="table" and row.name and row.team then
            local key=normalize(row.name); assignments[key]={name=tostring(row.name),team=clamp(row.team,1,2),locked=row.locked~=false}
        end
    end
    s.progGroups[name]={assignments=assignments,positions=copyPlain(positions),teamNames=copyPlain(teamNames or {"TEAM A","TEAM B"})}
    s.assignmentPreset=name
    return true
end

function Group.GetProgGroupSnapshot(name)
    local s=defaults(); local saved=s.progGroups[tostring(name or s.assignmentPreset or "Default")]
    if not saved then return nil end
    local assignmentSource=saved.assignments or saved
    return {assignments=copyPlain(assignmentSource),positions=copyPlain(saved.positions),teamNames=copyPlain(saved.teamNames or {"TEAM A","TEAM B"})}
end

function Group.SetCurrentProgGroupName(name)
    local s=defaults(); name=zo_strtrim(tostring(name or "Default")); if name=="" then name="Default" end; s.assignmentPreset=name; return true
end

function Group.SaveProgGroup(name)
    local s=defaults()
    name=zo_strtrim(tostring(name or s.assignmentPreset or "Default"))
    if name=="" then name="Default" end
    local assignments={}
    for key,value in pairs(s.assignments) do assignments[key]={name=value.name,team=value.team,locked=value.locked} end
    local positions=nil
    if RyticTank.Positions and RyticTank.Positions.ExportProgPositions then
        positions=RyticTank.Positions.ExportProgPositions()
    end
    s.progGroups[name]={assignments=assignments,positions=positions,teamNames={Group.GetTeamName(1),Group.GetTeamName(2)}}
    s.assignmentPreset=name
    return true
end

function Group.LoadProgGroup(name)
    local s=defaults(); name=tostring(name or s.assignmentPreset or "Default")
    local saved=s.progGroups[name]
    if not saved then return false end
    -- Migrate original prog entries, which stored the assignment map directly.
    local assignmentSource=saved.assignments or saved
    s.assignments={}
    for key,value in pairs(assignmentSource) do
        if type(value)=="table" and value.team then
            s.assignments[key]={name=value.name,team=value.team,locked=value.locked}
        end
    end
    if saved.teamNames then
        s.teamNames[1]=tostring(saved.teamNames[1] or "TEAM A")
        s.teamNames[2]=tostring(saved.teamNames[2] or "TEAM B")
    end
    if saved.positions and RyticTank.Positions and RyticTank.Positions.ImportProgPositions then
        RyticTank.Positions.ImportProgPositions(saved.positions)
    end
    s.assignmentPreset=name; Group.Refresh(); return true
end

function Group.GetCurrentProgGroup()
    return tostring(defaults().assignmentPreset or "Default")
end

function Group.ListProgGroups()
    local names={}
    for name in pairs(defaults().progGroups or {}) do names[#names+1]=name end
    table.sort(names,function(a,b) return zo_strlower(a)<zo_strlower(b) end)
    return names
end

function Group.DeleteProgGroup(name)
    local s=defaults(); name=tostring(name or "")
    if name=="" or not s.progGroups[name] then return false end
    s.progGroups[name]=nil
    if s.assignmentPreset==name then s.assignmentPreset="Default" end
    return true
end

function Group.ExportSyncState()
    local s=defaults()
    local assignments={}
    local size=GetGroupSize and GetGroupSize() or 0
    for i=1,size do
        local tag=GetGroupUnitTagByIndex(i)
        if tag then
            local account=getAccountName(tag)
            local charName=GetUnitName(tag) or account
            local a=s.assignments[normalize(account)] or s.assignments[normalize(charName)]
            if a and a.team then
                assignments[#assignments+1]={account=account,team=clamp(a.team,1,2),locked=a.locked==true}
            end
        end
    end
    local assistants={}
    for i=1,size do
        local tag=GetGroupUnitTagByIndex(i)
        if tag then
            local account=getAccountName(tag)
            if account~="" and Group.IsAccountAssistant(account) then assistants[#assistants+1]=account end
        end
    end
    return assignments,assistants,{Group.GetTeamName(1),Group.GetTeamName(2)}
end

function Group.ApplySyncState(assignments,teamNames)
    local s=defaults(); s.assignments={}
    if type(teamNames)=="table" then
        local a=zo_strtrim(tostring(teamNames[1] or ""))
        local b=zo_strtrim(tostring(teamNames[2] or ""))
        if a~="" then s.teamNames[1]=string.sub(a,1,18) end
        if b~="" then s.teamNames[2]=string.sub(b,1,18) end
    end
    -- The pushed account name is canonical. Mirror it to the current character
    -- name too so every client renders the same team regardless of name-display mode.
    local accountToChar={}
    local size=GetGroupSize and GetGroupSize() or 0
    for i=1,size do
        local tag=GetGroupUnitTagByIndex and GetGroupUnitTagByIndex(i) or nil
        if tag then
            local acct=getAccountName(tag)
            local charName=GetUnitName and GetUnitName(tag) or ""
            if acct and acct~="" then accountToChar[normalize(acct)]=charName end
        end
    end
    for _,row in ipairs(assignments or {}) do
        if row.account and row.account~="" and row.team then
            local team=clamp(row.team,1,2)
            local locked=row.locked==true
            local acctKey=normalize(row.account)
            s.assignments[acctKey]={name=row.account,team=team,locked=locked}
            local charName=accountToChar[acctKey]
            if charName and charName~="" then
                s.assignments[normalize(charName)]={name=charName,team=team,locked=locked}
            end
        end
    end
    Group.Refresh()
    refreshPositionsBoard()
end

-- Atomic local commit used by the Raid Controls thought board.  This updates
-- the complete staged layout without broadcasting intermediate drag edits.
function Group.ApplyBoardState(rows,teamNames)
    if IsUnitGrouped and IsUnitGrouped("player") and not Group.CanManageAssignments() then
        return false,"Board commit requires group lead or Rytic assistant authority"
    end
    if type(rows)~="table" then return false,"Invalid staged assignment data" end
    for _,row in ipairs(rows) do
        if type(row)=="table" and row.name and row.team then
            local account,charName=resolveMemberIdentity(row.name)
            if account and account~="" then
                setTeam(account,row.team,row.locked~=false)
                if charName and charName~="" then setTeam(charName,row.team,row.locked~=false) end
            else
                setTeam(row.name,row.team,row.locked~=false)
            end
        end
    end
    local s=defaults()
    if type(teamNames)=="table" then
        local a=zo_strtrim(tostring(teamNames[1] or "")); local b=zo_strtrim(tostring(teamNames[2] or ""))
        s.teamNames[1]=(a~="" and string.sub(a,1,18)) or "TEAM A"
        s.teamNames[2]=(b~="" and string.sub(b,1,18)) or "TEAM B"
    end
    canonicalizeCurrentAssignments()
    Group.Refresh()
    return true
end

function Group.PushOut()
    if not Group.CanManageAssignments() then return false,"PUSH requires group lead or Rytic assistant authority" end
    Group.lastPush=GetFrameTimeSeconds and GetFrameTimeSeconds() or 0
    if RyticTank.GroupSync and RyticTank.GroupSync.Push then return RyticTank.GroupSync.Push() end
    return false,"LibGroupBroadcast sync module is not loaded"
end

local function getRoleColor(settings,roleKey)
    local c=settings.roleColors and settings.roleColors[roleKey] or DEFAULT_ROLE_COLORS[roleKey]
    c=c or DEFAULT_ROLE_COLORS.unknown
    return tonumber(c[1]) or .45,tonumber(c[2]) or .45,tonumber(c[3]) or .48,tonumber(c[4]) or 1
end

local function setNativeGroupFramesHidden(hidden)
    if ZO_UnitFramesGroups then ZO_UnitFramesGroups:SetHidden(hidden and true or false) end
end

local function setupHudFragment()
    if Group.fragment or not Group.root or not SCENE_MANAGER or not HUD_SCENE or not HUD_UI_SCENE then return false end
    local fragment
    if ZO_HUDFadeSceneFragment then fragment=ZO_HUDFadeSceneFragment:New(Group.root,nil,0)
    elseif ZO_SimpleSceneFragment then fragment=ZO_SimpleSceneFragment:New(Group.root) end
    if not fragment then return false end
    Group.fragment=fragment
    fragment:RegisterCallback("StateChange",function(_,newState)
        if newState==SCENE_FRAGMENT_SHOWN then
            Group.Refresh()
        elseif newState==SCENE_FRAGMENT_HIDDEN and Group.root then
            Group.root:SetHidden(true)
        end
    end)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    return true
end

local function getDisplayedName(tag, settings)
    local accountName=(GetUnitDisplayName and GetUnitDisplayName(tag)) or ""
    local characterName=(GetUnitName and GetUnitName(tag)) or tag or ""
    local mode=settings.nameDisplay or "GAMER TAG"
    if mode=="CHARACTER NAME" then return characterName end
    if mode=="BOTH" and accountName~="" then return accountName.." ("..characterName..")" end
    return accountName~="" and accountName or characterName
end

local function getClassAndCP(tag)
    local cp=(GetUnitChampionPoints and tonumber(GetUnitChampionPoints(tag))) or 0
    local className=(GetUnitClass and GetUnitClass(tag)) or ""
    if className==nil then className="" end
    return tostring(className), cp
end

local function formatOfflineDuration(seconds)
    seconds=math_max(0,math_floor(tonumber(seconds) or 0))
    local hours=math_floor(seconds/3600)
    local minutes=math_floor((seconds%3600)/60)
    local secs=seconds%60
    if hours>0 then return string.format("%d:%02d:%02d",hours,minutes,secs) end
    return string.format("%02d:%02d",minutes,secs)
end

local function getOfflineState(tag,settings,identity)
    if not IsUnitOnline then return false,0 end
    local online=IsUnitOnline(tag)
    local key=normalize(identity)
    local now=(GetTimeStamp and GetTimeStamp()) or 0
    if online then
        if key~="" then settings.offlineSince[key]=nil end
        return false,0
    end
    if key~="" and not settings.offlineSince[key] then settings.offlineSince[key]=now end
    local since=(key~="" and settings.offlineSince[key]) or now
    return true,math_max(0,now-since)
end

local function updateFrame(frame,tag)
    frame.unitTag=tag
    if not tag or not DoesUnitExist or not DoesUnitExist(tag) then frame:SetHidden(true); return end
    local s=defaults(); local name=GetUnitName(tag) or tag
    local displayName=getDisplayedName(tag,s)
    -- Use ESO's built-in group-leader crown so we do not depend on another addon's assets.
    if IsUnitGroupLeader and IsUnitGroupLeader(tag) then
        displayName="|t18:18:/esoui/art/unitframes/gamepad/gp_group_leader.dds|t "..displayName
    end
    local identity=(GetUnitDisplayName and GetUnitDisplayName(tag)) or name
    local offline,offlineSeconds=getOfflineState(tag,s,identity)
    local className,cp=getClassAndCP(tag)
    local current,maximum=GetUnitPower(tag,POWERTYPE_HEALTH)
    current=tonumber(current) or 0; maximum=tonumber(maximum) or 0
    local dead=(IsUnitDead and IsUnitDead(tag)) or current<=0
    local team=teamOf(getAccountName(tag)) or teamOf(name)
    local rezKey=normalize(identity)
    if rezKey=="" then rezKey=tag end
    local pending=dead and not offline and DoesUnitHaveResurrectPending and DoesUnitHaveResurrectPending(tag)
    local pendingSeconds
    if pending then
        -- ESO exposes the pending state for group members, but not its start time.
        -- Begin counting on the first frame where Rytic observes that state.
        local now=(GetFrameTimeSeconds and GetFrameTimeSeconds()) or 0
        local started=rezPendingSince[rezKey]
        if not started or now<started then started=now; rezPendingSince[rezKey]=started end
        pendingSeconds=math_floor(math_max(0,now-started))
    else
        rezPendingSince[rezKey]=nil
        frame.ryticRezSeconds=nil
    end
    frame:SetHidden(false)
    if frame.dead then
        frame.dead:SetHidden(offline or not dead)
        if dead and not offline then
            local state
            if pending then
                state=3
            elseif IsUnitBeingResurrected and IsUnitBeingResurrected(tag) then
                state=2
            else
                state=1
            end
            if frame.ryticDeathState~=state then
                if state==3 then
                    frame.dead:SetFont("ZoFontGameBold")
                    frame.dead:SetColor(1,.78,.16,1)
                elseif state==2 then
                    frame.dead:SetFont("ZoFontWinH2")
                    frame.dead:SetText("REZZING")
                    frame.dead:SetColor(.28,.85,1,1)
                else
                    frame.dead:SetFont("ZoFontWinH2")
                    frame.dead:SetText("DEAD")
                    frame.dead:SetColor(1,.08,.08,1)
                end
                frame.ryticDeathState=state
            end
            if state==3 and frame.ryticRezSeconds~=pendingSeconds then
                frame.dead:SetText("REZ PENDING "..formatOfflineDuration(pendingSeconds))
                frame.ryticRezSeconds=pendingSeconds
            end
        end
    end
    if offline then
        frame.name:SetText(displayName.." |cFF3030OFFLINE|r")
        frame.name:SetColor(1,1,1,1)
    else
        frame.name:SetText(displayName)
        frame.name:SetColor(dead and .55 or 1,dead and .55 or 1,dead and .55 or 1,1)
    end
    local info={}
    if offline then info[#info+1]="|cFF3030"..formatOfflineDuration(offlineSeconds).."|r" end
    if cp>0 then info[#info+1]="CP "..tostring(cp) end
    if className~="" then info[#info+1]=className end
    if not offline then info[#info+1]=formatNumber(current).." / "..formatNumber(maximum) end
    frame.status:SetText(table.concat(info," • "))
    frame.team=team
    if offline then
        frame:SetCenterColor(0,0,0,.98)
        frame:SetEdgeColor(.10,.10,.10,1)
        frame.health:SetHidden(true)
        if frame.shield then frame.shield:SetHidden(true) end
        frame.healthBack:SetCenterColor(0,0,0,.98)
        frame.ready:SetHidden(true)
        frame.range:SetHidden(true)
        frame.barrier:SetHidden(true)
    else
        local roleKey=getRoleKey(tag)
        local rr,rg,rb,ra=getRoleColor(s,roleKey)
        if dead then
            frame:SetCenterColor(.16,.01,.01,.98)
            frame:SetEdgeColor(1,.05,.05,1)
            frame.healthBack:SetCenterColor(.08,.01,.01,.98)
            frame.health:SetHidden(true)
            frame.ready:SetHidden(true)
            frame.range:SetHidden(true)
        else
            -- Full square uses the role color, not only the outline.
            frame:SetCenterColor(rr,rg,rb,0.96)
            frame:SetEdgeColor(rr,rg,rb,ra)
            setHealth(frame,current,maximum,rr,rg,rb,ra)
            updateReady(frame,tag,s)
            updateRange(frame,tag,s,rr,rg,rb,ra)
        end
        local barrier=getBarrier(tag)
        setShield(frame,tag,barrier,maximum)
        if s.showBarrier then
            frame.barrier:SetText(barrier>0 and ("+"..formatNumber(barrier)) or "")
            frame.barrier:SetHidden(barrier<=0)
        else frame.barrier:SetHidden(true) end
    end
    if team then
        local c=TEAM_COLORS[team]
        frame.teamBadge:SetText(team==1 and "A" or "B")
        frame.teamBadge:SetColor(c[1],c[2],c[3],1)
        frame.teamBadge:SetHidden(false)
    else
        frame.teamBadge:SetHidden(true)
    end
end

local function arrangeFrames()
    local s=defaults()
    s.columns=2
    local columns=2
    local rows=math_ceil(MAX_GROUP_SIZE/columns)
    for index,frame in ipairs(Group.frames) do
        local zero=index-1; local col=zero%columns; local row=math_floor(zero/columns)
        frame:ClearAnchors(); frame:SetAnchor(TOPLEFT,Group.root,TOPLEFT,col*(FRAME_WIDTH+FRAME_GAP),row*(FRAME_HEIGHT+FRAME_GAP)+24)
    end
    -- Keep the root compact; Refresh() sizes height to the roster actually visible.
    Group.root:SetDimensions(columns*FRAME_WIDTH+(columns-1)*FRAME_GAP,FRAME_HEIGHT+24)
    for team=1,2 do
        local h=Group.headers[team]; h:ClearAnchors(); h:SetAnchor(TOPLEFT,Group.root,TOPLEFT,(team-1)*(FRAME_WIDTH+FRAME_GAP),0)
        h:SetColor(TEAM_COLORS[team][1],TEAM_COLORS[team][2],TEAM_COLORS[team][3],1)
    end
end

function Group.Create()
    if Group.root then return end
    local s=defaults(); local root=WM:CreateTopLevelWindow("RyticTankToolsGroupFramesRoot")
    Group.root=root; Group.frames={}; Group.headers={}
    root:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,s.x or 40,s.y or 220); root:SetScale(s.scale or 1)
    root:SetMovable(true); root:SetMouseEnabled(false); root:SetClampedToScreen(true)
    root:SetHandler("OnMouseDown",function(self,button)
        if button==MOUSE_BUTTON_INDEX_LEFT and not defaults().locked then self:StartMoving() end
    end)
    root:SetHandler("OnMouseUp",function(self,button)
        if button==MOUSE_BUTTON_INDEX_LEFT and not defaults().locked then self:StopMovingOrResizing() end
    end)
    root:SetHandler("OnMoveStop",function(self)
        local current=defaults()
        current.x=self:GetLeft() or current.x
        current.y=self:GetTop() or current.y
    end)
    local drag=WM:CreateControl(nil,root,CT_BACKDROP)
    Group.dragHandle=drag
    drag:SetDimensions(440,24)
    -- Keep the drag strip inside the root so screen clamping cannot strand it.
    drag:SetAnchor(TOPLEFT,root,TOPLEFT,0,0)
    drag:SetCenterColor(.08,.08,.08,.90)
    drag:SetEdgeColor(.85,.65,.15,1)
    drag:SetEdgeTexture("",1,1,2,0)
    drag:SetDrawTier(DT_HIGH)
    drag:SetDrawLayer(DL_OVERLAY)
    drag:SetMouseEnabled(false)
    drag:SetHidden(true)
    drag.label=makeLabel(drag,"ZoFontGameBold",436,22)
    drag.label:SetAnchor(CENTER,drag,CENTER,0,0)
    drag.label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    drag.label:SetText("DRAG GROUP FRAMES")
    drag:SetHandler("OnMouseDown",function(_,button)
        if button==MOUSE_BUTTON_INDEX_LEFT and not defaults().locked then root:StartMoving() end
    end)
    drag:SetHandler("OnMouseUp",function(_,button)
        if button==MOUSE_BUTTON_INDEX_LEFT and not defaults().locked then
            root:StopMovingOrResizing()
            local current=defaults()
            current.x=root:GetLeft() or current.x
            current.y=root:GetTop() or current.y
        end
    end)
    for team=1,2 do
        local h=makeLabel(root,"ZoFontGameBold",FRAME_WIDTH,22); h:SetText(Group.GetTeamName(team)); Group.headers[team]=h
    end
    for i=1,MAX_GROUP_SIZE do Group.frames[i]=createFrame(root,i) end
    arrangeFrames(); root:SetHidden(true)
end

function Group.ApplyLock()
    local s=defaults(); if not Group.root then return end
    Group.root:SetMovable(not s.locked)
    Group.root:SetMouseEnabled(not s.locked)
    if Group.dragHandle then
        Group.dragHandle:SetMouseEnabled(not s.locked)
        Group.dragHandle:SetHidden(s.locked)
    end
end

function Group.SetLocked(locked)
    defaults().locked=locked and true or false
    Group.ApplyLock()
end

function Group.ResetPosition()
    local s=defaults()
    s.x,s.y=40,220
    if Group.root then
        Group.root:ClearAnchors()
        Group.root:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,s.x,s.y)
    end
end

function Group.Refresh()
    canonicalizeCurrentAssignments()
    if not Group.root then return end
    local s=defaults()
    setupHudFragment()
    local active=s.enabled and IsUnitGrouped("player")
    setNativeGroupFramesHidden(active)
    if not active then rezPendingSince={}; Group.root:SetHidden(true); return end
    if Group.fragment and Group.fragment.GetState and Group.fragment:GetState()~=SCENE_FRAGMENT_SHOWN then
        Group.root:SetHidden(true)
        return
    end
    Group.root:SetHidden(false)
    if Group.headers then
        if Group.headers[1] then Group.headers[1]:SetText(Group.GetTeamName(1)) end
        if Group.headers[2] then Group.headers[2]:SetText(Group.GetTeamName(2)) end
    end
    local size=GetGroupSize and GetGroupSize() or 0
    local ordered={{},{}}; local unassigned={}
    local seenPending=next(rezPendingSince) and {} or nil
    for i=1,size do
        local tag=GetGroupUnitTagByIndex and GetGroupUnitTagByIndex(i) or nil
        if tag then
            local name=GetUnitName(tag) or tag
            if seenPending then
                local key=normalize(getAccountName(tag))
                seenPending[key~="" and key or tag]=true
            end
            local team=teamOf(getAccountName(tag)) or teamOf(name)
            if team==1 or team==2 then ordered[team][#ordered[team]+1]=tag else unassigned[#unassigned+1]=tag end
        end
    end
    if seenPending then
        for key in pairs(rezPendingSince) do
            if not seenPending[key] then rezPendingSince[key]=nil end
        end
    end
    -- Team B always exists in saved/sync state, but stays visually collapsed
    -- until someone is actually assigned to B or the roster exceeds six players.
    local showTeamB = (#ordered[2] > 0) or (size >= GROUP_B_AUTO_SHOW_SIZE)
    if Group.headers and Group.headers[2] then
        Group.headers[2]:SetHidden(not showTeamB)
    end

    local function roleOrder(tag)
        local r=getRoleKey(tag); return r=="tank" and 1 or (r=="healer" and 2 or (r=="dps" and 3 or 4))
    end
    for team=1,2 do table.sort(ordered[team],function(a,b)
        local ra,rb=roleOrder(a),roleOrder(b)
        if ra~=rb then return ra<rb end
        local da,db=getDps(GetUnitName(a)),getDps(GetUnitName(b))
        if da~=db then return da>db end
        return normalize(GetUnitName(a))<normalize(GetUnitName(b))
    end) end
    local visual={}
    local rows=math_ceil(MAX_GROUP_SIZE/2)

    if showTeamB then
        -- Normal two-column raid layout.
        for row=1,rows do
            visual[(row-1)*2+1]=ordered[1][row]
            visual[(row-1)*2+2]=ordered[2][row]
        end
    else
        -- Compact one-column layout: Team A occupies the left-side slots only.
        for row=1,rows do
            visual[(row-1)*2+1]=ordered[1][row]
        end
    end

    -- Even before Auto Arrange, always present the roster in raid hierarchy:
    -- Tank -> Healer -> DPS (highest shared DPS first) -> unknown.
    table.sort(unassigned,function(a,b)
        local ra,rb=roleOrder(a),roleOrder(b)
        if ra~=rb then return ra<rb end
        local da,db=getDps(GetUnitName(a)),getDps(GetUnitName(b))
        if da~=db then return da>db end
        return normalize(GetUnitName(a))<normalize(GetUnitName(b))
    end)

    -- Until Auto Arrange/assignment is used, keep unassigned players visible.
    if showTeamB then
        for _,tag in ipairs(unassigned) do
            local placed=false
            for i=1,MAX_GROUP_SIZE do
                if not visual[i] then visual[i]=tag; placed=true; break end
            end
            if not placed then break end
        end
    else
        local row=1
        for _,tag in ipairs(unassigned) do
            while row<=rows and visual[(row-1)*2+1] do row=row+1 end
            if row>rows then break end
            visual[(row-1)*2+1]=tag
            row=row+1
        end
    end

    for i=1,MAX_GROUP_SIZE do updateFrame(Group.frames[i],visual[i]) end

    -- Collapse the root to one column until Team B is actually needed.
    local maxRows
    if showTeamB then
        maxRows=math.max(1,#ordered[1],#ordered[2],math.ceil(size/2))
        Group.root:SetDimensions(2*FRAME_WIDTH+FRAME_GAP,maxRows*(FRAME_HEIGHT+FRAME_GAP)+24)
    else
        maxRows=math.max(1,size)
        Group.root:SetDimensions(FRAME_WIDTH,maxRows*(FRAME_HEIGHT+FRAME_GAP)+24)
    end
end

function Group.SetEnabled(enabled)
    local s=defaults()
    s.enabled=enabled and true or false
    if s.enabled then
        if Group.RegisterRuntime then Group.RegisterRuntime() end
        Group.ApplyLock()
        Group.Refresh()
    else
        if Group.UnregisterRuntime then Group.UnregisterRuntime() end
        setNativeGroupFramesHidden(false)
        if Group.root then Group.root:SetHidden(true) end
        if Group.dragHandle then Group.dragHandle:SetHidden(true) end
    end
end

function Group.SetRoleColor(role,r,g,b,a)
    local s=defaults()
    if role~="tank" and role~="healer" and role~="dps" then return false end
    s.roleColors[role]={clamp(r,0,1),clamp(g,0,1),clamp(b,0,1),clamp(a or 1,0,1)}
    Group.Refresh()
    return true
end

function Group.SetNameDisplay(mode)
    if mode~="GAMER TAG" and mode~="CHARACTER NAME" and mode~="BOTH" then return false end
    defaults().nameDisplay=mode
    Group.Refresh()
    return true
end

function Group.SetScale(scale)
    local s=defaults()
    s.scale=clamp(scale,.5,2)
    if Group.root then
        Group.root:SetScale(s.scale)
        Group.root:ClearAnchors()
        Group.root:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,s.x or 40,s.y or 220)
        Group.Refresh()
    end
end

local function isGroupTag(tag)
    return type(tag)=="string" and string.sub(tag,1,5)=="group"
end

local function refreshShieldFrame(tag,value)
    if not isGroupTag(tag) then return end
    shieldCache[tag]=math_max(0,tonumber(value) or 0)
    local size=GetGroupSize and GetGroupSize() or 0
    for i=1,size do
        local unitTag=GetGroupUnitTagByIndex and GetGroupUnitTagByIndex(i)
        if unitTag==tag and Group.frames and Group.frames[i] then
            local _,maxHealth=GetUnitPower(tag,POWERTYPE_HEALTH)
            setShield(Group.frames[i],tag,shieldCache[tag],maxHealth)
            if defaults().showBarrier then
                Group.frames[i].barrier:SetText(shieldCache[tag]>0 and ("+"..formatNumber(shieldCache[tag])) or "")
                Group.frames[i].barrier:SetHidden(shieldCache[tag]<=0)
            end
            return
        end
    end
end

local function onShieldVisualAdded(_,tag,visual,statType,attributeType,powerType,value,maxValue,sequenceId)
    if visual~=ATTRIBUTE_VISUAL_POWER_SHIELDING or attributeType~=ATTRIBUTE_HEALTH or powerType~=POWERTYPE_HEALTH then return end
    refreshShieldFrame(tag,(sequenceId==0 and value or 0))
end

local function onShieldVisualUpdated(_,tag,visual,statType,attributeType,powerType,oldValue,newValue,oldMaxValue,newMaxValue)
    if visual~=ATTRIBUTE_VISUAL_POWER_SHIELDING or attributeType~=ATTRIBUTE_HEALTH or powerType~=POWERTYPE_HEALTH then return end
    refreshShieldFrame(tag,newValue)
end

local function onShieldVisualRemoved(_,tag,visual,statType,attributeType,powerType,value,maxValue,sequenceId)
    if visual~=ATTRIBUTE_VISUAL_POWER_SHIELDING or attributeType~=ATTRIBUTE_HEALTH or powerType~=POWERTYPE_HEALTH then return end
    refreshShieldFrame(tag,0)
end

local function onDeathStateChanged(_,tag,isDead)
    if not isDead or not isGroupTag(tag) then return end
    local s=defaults(); local account=getAccountName(tag); local key=normalize(account)
    if key=="" then return end
    local now=(GetGameTimeMilliseconds and GetGameTimeMilliseconds()) or 0
    local last=tonumber(s.deathDebounce[key]) or 0
    if last>0 and now-last<2000 then return end
    s.deathDebounce[key]=now
    s.deathCounts[key]=(tonumber(s.deathCounts[key]) or 0)+1
end

function Group.UnregisterRuntime()
    if not Group.runtimeRegistered then return end
    Group.runtimeRegistered=false
    rezPendingSince={}
    EM:UnregisterForUpdate(UPDATE_NAME)
    local names={"RyticGroupFramesJoined","RyticGroupFramesLeft","RyticGroupFramesUpdated","RyticGroupFramesReadyState","RyticGroupFramesActivated","RyticGroupFramesRoleChanged","RyticGroupFramesDeathCount"}
    for _,name in ipairs(names) do EM:UnregisterForEvent(name) end
    EM:UnregisterForEvent(SHIELD_EVENT_PREFIX.."Added")
    EM:UnregisterForEvent(SHIELD_EVENT_PREFIX.."Updated")
    EM:UnregisterForEvent(SHIELD_EVENT_PREFIX.."Removed")
end

local function resetAssistantSessionIfUngrouped()
    if IsUnitGrouped and not IsUnitGrouped("player") then
        Group.sessionAssistants={}
        Group.sessionAssistantsInitialized=false
        Group.sessionAssistantOverrides={}
    end
end

function Group.RegisterRuntime()
    if Group.runtimeRegistered then return end
    Group.runtimeRegistered=true
    EM:RegisterForUpdate(UPDATE_NAME,250,Group.Refresh)
    local events={{"RyticGroupFramesJoined",EVENT_GROUP_MEMBER_JOINED},{"RyticGroupFramesLeft",EVENT_GROUP_MEMBER_LEFT},{"RyticGroupFramesUpdated",EVENT_GROUP_UPDATE},{"RyticGroupFramesReadyState",EVENT_GROUP_MEMBER_READY_STATE_CHANGED},{"RyticGroupFramesActivated",EVENT_PLAYER_ACTIVATED},{"RyticGroupFramesRoleChanged",EVENT_GROUP_MEMBER_ROLE_CHANGED}}
    for _,e in ipairs(events) do
        if e[2] then
            EM:RegisterForEvent(e[1],e[2],function(...)
                resetAssistantSessionIfUngrouped()
                Group.Refresh(...)
            end)
        end
    end
    if EVENT_UNIT_DEATH_STATE_CHANGED then EM:RegisterForEvent("RyticGroupFramesDeathCount",EVENT_UNIT_DEATH_STATE_CHANGED,onDeathStateChanged) end
    if EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED then
        EM:RegisterForEvent(SHIELD_EVENT_PREFIX.."Added",EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED,onShieldVisualAdded)
        EM:RegisterForEvent(SHIELD_EVENT_PREFIX.."Updated",EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED,onShieldVisualUpdated)
        EM:RegisterForEvent(SHIELD_EVENT_PREFIX.."Removed",EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED,onShieldVisualRemoved)
    end
end

function Group.Initialize()
    local s=defaults(); Group.Create(); Group.ApplyLock()
    setupHudFragment() -- SCENE_MANAGER may not exist yet; EVENT_PLAYER_ACTIVATED retries safely.
    SLASH_COMMANDS["/rtassign"]=function(arg)
        local name,team=string.match(arg or "","^(.-)%s+(%d+)%s*$")
        if name and Group.Assign(name,tonumber(team),true) then Group.Refresh(); Group.PushOut(); d("|c55FF55Rytic: assigned "..name.." to Team "..team..".|r") end
    end
    SLASH_COMMANDS["/rtgroups"]=function(arg)
        local command,rest=string.match(arg or "","^(%S+)%s*(.-)$")
        if command=="auto" or command=="arrange" then Group.AutoBalance()
        elseif command=="save" then Group.SaveProgGroup(rest)
        elseif command=="load" then Group.LoadProgGroup(rest)
        elseif command=="clear" then Group.ClearAssignments()
        elseif command=="push" then Group.PushOut()
        end
    end
    Group.runtimeRegistered=false
    if s.enabled then
        initCombatStats()
        Group.RegisterRuntime()
        Group.Refresh()
    else
        setNativeGroupFramesHidden(false)
        if Group.root then Group.root:SetHidden(true) end
    end
end

EM:RegisterForEvent("RyticGroupFramesBootstrap",EVENT_ADD_ON_LOADED,function(_,addonName)
    if addonName~="RyticTankTools" then return end
    EM:UnregisterForEvent("RyticGroupFramesBootstrap",EVENT_ADD_ON_LOADED)
    if RyticTank.GroupFrames and RyticTank.GroupFrames.Initialize then RyticTank.GroupFrames.Initialize() end
end)
