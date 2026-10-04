ScoreboardFixXbox = { name = 'ScoreboardFixXbox', rows = {}, teamControls = {}, headers = {}, flat = {} }
local A, C = ScoreboardFixXbox, ScoreboardFixXboxCore
local WM, EM = WINDOW_MANAGER, EVENT_MANAGER
local gold = {0.82,0.80,0.65,1}
local FONT_HEADER = 'ZoFontGamepad27'
local FONT_ROW = 'ZoFontGamepad34'
local FONT_TITLE = 'ZoFontGamepad42'
local FONT_SCORE = 'ZoFontGamepad42'
local HEADER_HEIGHT = 142
local HEADER_DIVIDER_Y = 64
local HEADER_ROW_Y = 82
local HEADER_CONTROL_HEIGHT = 58
local HEADER_LABEL_HEIGHT = 38
local HEADER_ICON_SIZE = 34
local HEADER_ICON_OFFSET_Y = math.floor((HEADER_LABEL_HEIGHT - HEADER_ICON_SIZE) / 2)
local HEADER_GLOW_SIZE = 50
local HEADER_GLOW_ALPHA = 0.45
local HEADER_GLOW_OFFSET_Y = HEADER_ICON_OFFSET_Y - math.floor((HEADER_GLOW_SIZE - HEADER_ICON_SIZE) / 2)
local HEADER_GLOW_TEXTURE = 'ScoreboardFixXbox/Textures/header_glow.dds'

local HEADER_ICON_ARROW_IN_KNEE = 'EsoUI/Art/Armory/BuildIcons/buildicon_71.dds'
local BG_ICON_LAND_GRAB = 'EsoUI/Art/Battlegrounds/Gamepad/gp_battlegrounds_tabIcon_landgrab.dds'
local BG_ICON_RELIC_TEST = 'EsoUI/Art/MapPins/battlegrounds_relic_neutral.dds'
local BG_ICON_CHAOSBALL = 'EsoUI/Art/MapPins/battlegrounds_murderball_neutral.dds'
local BG_ICON_CAPTURE_POINT = 'EsoUI/Art/Compass/compass_bg_capturepoint_neutral.dds'
local HEADER_ICON_DAMAGE = 'EsoUI/Art/LFG/LFG_dps_down_no_glow_64.dds'
local HEADER_ICON_HEALING = 'EsoUI/Art/LFG/LFG_healer_down_no_glow_64.dds'
local cols = {
    {key='displayName',title='USERID',x=172,w=192,gapAfter=10},
    {key='characterName',title='CHARACTER',x=374,w=218},
    {key='medals',title='MEDAL SCORE',x=500,w=150},
    {key='kills',title='K',x=596,w=48},
    {key='deaths',title='D',x=644,w=48},
    {key='assists',title='A',x=692,w=48},
    {key='kd',title='K/D',x=741,w=64},
    {key='damage',title='DAMAGE',x=812,w=90},
    {key='healing',title='HEALING',x=912,w=90},
    {key='objective',title='',x=1012,w=90},
}
local order = {BATTLEGROUND_TEAM_PIT_DAEMONS, BATTLEGROUND_TEAM_STORM_LORDS, BATTLEGROUND_TEAM_FIRE_DRAKES}
local function Label(parent, font, text)
    local c = WM:CreateControl(nil,parent,CT_LABEL)
    c:SetFont(font or 'ZoFontGamepad27'); c:SetColor(unpack(gold)); c:SetText(text or '')
    c:SetVerticalAlignment(TEXT_ALIGN_CENTER); c:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
    return c
end
local function Place(c,x,y,w,h)
    c:ClearAnchors(); c:SetAnchor(TOPLEFT,c:GetParent(),TOPLEFT,x,y); c:SetDimensions(w,h)
end
local function Back(parent, r,g,b,a)
    local c=WM:CreateControl(nil,parent,CT_BACKDROP)
    c:SetAnchorFill(); c:SetCenterColor(r,g,b,a); c:SetEdgeColor(0.62,0.59,0.44,1)
    c:SetEdgeTexture('',1,1,1); return c
end
local function Heading(parent,text)
    local c=WM:CreateControl(nil,parent,CT_CONTROL)
    c:SetMouseEnabled(false)
    c.label=Label(c,FONT_HEADER,text);c.label:SetAnchorFill()
    c.label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    return c
end
local function CleanName(s) return zo_strformat(SI_UNIT_NAME,s or '') end
local function ObjectiveIcon(gameType)
    -- Deathmatch uses the exact Armory DDS confirmed by the /icons browser.
    if gameType==BATTLEGROUND_GAME_TYPE_DEATHMATCH then return HEADER_ICON_ARROW_IN_KNEE end
    -- Use native Battleground objective art. Capture the Relic deliberately has no
    -- fallback in this test build: if the suspected relic DDS path is wrong, it should
    -- fail visibly so the asset test is unambiguous.
    if gameType==BATTLEGROUND_GAME_TYPE_MURDERBALL then return BG_ICON_CHAOSBALL end
    if gameType==BATTLEGROUND_GAME_TYPE_CAPTURE_THE_FLAG then return BG_ICON_RELIC_TEST end
    if gameType==BATTLEGROUND_GAME_TYPE_DOMINATION or gameType==BATTLEGROUND_GAME_TYPE_CRAZY_KING or gameType==BATTLEGROUND_GAME_TYPE_KING_OF_THE_HILL then
        return BG_ICON_CAPTURE_POINT
    end
    return BG_ICON_LAND_GRAB
end
local function SetupIconHeader(button)
    button.label:SetHidden(true)

    -- Shared neutral halo behind the three main stat icons. This is a soft,
    -- circular beige glow, not a larger duplicate of the icon itself.
    button.glow=WM:CreateControl(nil,button,CT_TEXTURE)
    button.glow:SetTexture(HEADER_GLOW_TEXTURE)
    button.glow:SetDimensions(HEADER_GLOW_SIZE,HEADER_GLOW_SIZE)
    button.glow:SetAnchor(TOP,button,TOP,0,HEADER_GLOW_OFFSET_Y)
    button.glow:SetDrawLayer(DL_CONTROLS)
    button.glow:SetColor(unpack(gold))
    button.glow:SetAlpha(HEADER_GLOW_ALPHA)

    -- Strong black silhouette around the icon. Eight offset copies create a
    -- clean outline without changing the source DDS.
    button.outlines={}
    local outlineOffsets={
        {-0.5,-0.5},{0,-0.5},{0.5,-0.5},
        {-0.5,0},                {0.5,0},
        {-0.5,0.5}, {0,0.5},   {0.5,0.5},
    }
    for i,offset in ipairs(outlineOffsets) do
        local outline=WM:CreateControl(nil,button,CT_TEXTURE)
        outline:SetDimensions(HEADER_ICON_SIZE,HEADER_ICON_SIZE)
        outline:SetAnchor(TOP,button,TOP,offset[1],HEADER_ICON_OFFSET_Y+offset[2])
        outline:SetDrawLayer(DL_CONTROLS)
        outline:SetColor(0,0,0,1)
        outline:SetAlpha(1)
        button.outlines[i]=outline
    end

    button.icon=WM:CreateControl(nil,button,CT_TEXTURE)
    button.icon:SetDimensions(HEADER_ICON_SIZE,HEADER_ICON_SIZE)
    button.icon:SetAnchor(TOP,button,TOP,0,HEADER_ICON_OFFSET_Y)
    button.icon:SetDrawLayer(DL_OVERLAY)
    button.icon:SetColor(1,1,1,1)
    button.icon:SetAlpha(1)
    button.icon:SetBlendMode(TEX_BLEND_MODE_ADD)

end
local function Objective(gameType)
    if gameType==BATTLEGROUND_GAME_TYPE_DEATHMATCH then return SCORE_TRACKER_TYPE_DAMAGE_TAKEN,'Damage Taken' end
    if gameType==BATTLEGROUND_GAME_TYPE_MURDERBALL then return SCORE_TRACKER_TYPE_FLAG_CARRIED_TIME,'Flag Carried Time' end
    if gameType==BATTLEGROUND_GAME_TYPE_CAPTURE_THE_FLAG then return SCORE_TRACKER_TYPE_FLAG_CAPTURED,'Relics Captured' end
    return SCORE_TRACKER_TYPE_FLAG_CAPTURED,'Flags Captured'
end
function A:Capture()
    if not IsActiveWorldBattleground() then return end
    local id=GetCurrentBattlegroundId()
    if not id or id==0 then return end
    local state=GetCurrentBattlegroundState()
    if not self.inMatch or not self.match or self.match.id~=id or
        (self.match.finished and state~=BATTLEGROUND_STATE_FINISHED) then
        self.match={id=id,rounds={},finished=false}; self.viewRound=nil; self.selected=nil
    end
    self.inMatch=true
    local m=self.match
    m.currentRound=math.max(1,GetCurrentBattlegroundRoundIndex())
    m.numRounds=GetBattlegroundNumRounds(id)
    if not m.teamIds then
        m.teamIds={}
        local n=GetBattlegroundNumTeams(id)
        for _,team in ipairs(order) do
            if DoesBattlegroundHaveTeam(id,team) then table.insert(m.teamIds,team) end
        end
        local teamSize=GetBattlegroundTeamSize(id) or 0
        if teamSize>0 then
            m.capacity=teamSize
        else
            m.capacity=(n==3) and 6 or 4
        end
    end
    local wasFinished=m.finished
    local hadTotal=m.total~=nil
    m.finished=state==BATTLEGROUND_STATE_FINISHED
    for round=1,m.currentRound do
        local count=GetNumScoreboardEntries(round)
        if count>0 then
            local gameType=GetBattlegroundGameType(id,round)
            local stat,title=Objective(gameType)
            local snapshot={teams={},gameType=gameType,title=string.upper(GetString('SI_BATTLEGROUNDGAMETYPE',gameType) or 'BATTLEGROUND'),objectiveTitle=title,showLives=DoesBattlegroundHaveLimitedPlayerLives(id)}
            for _,team in ipairs(order) do
                local roundComplete=(round<m.currentRound) or state>=BATTLEGROUND_STATE_POSTROUND
                local activeTeam=DoesBattlegroundHaveTeam(id,team)
                snapshot.teams[team]={players={},score=GetCurrentBattlegroundScore(round,team),won=roundComplete and activeTeam and DidCurrentBattlegroundTeamWinOrTieRound(team,round) or false}
            end
            for i=1,count do
                local characterName,displayName,team,isLocal=GetScoreboardEntryInfo(i,round)
                if displayName and snapshot.teams[team] then
                    local function Score(t) return GetScoreboardEntryScoreByType(i,t,round) or 0 end
                    local p={characterName=CleanName(characterName),displayName=displayName,team=team,
                        isLocalPlayer=isLocal,classId=GetScoreboardEntryClassId(i,round),entryIndex=i,roundIndex=round,
                        kills=Score(SCORE_TRACKER_TYPE_KILL),deaths=Score(SCORE_TRACKER_TYPE_DEATH),
                        assists=Score(SCORE_TRACKER_TYPE_ASSISTS),damage=Score(SCORE_TRACKER_TYPE_DAMAGE_DONE),
                        healing=Score(SCORE_TRACKER_TYPE_HEALING_DONE),medals=Score(SCORE_TRACKER_TYPE_SCORE),
                        objective=Score(stat),medalDetails={}}
                    if DoesBattlegroundHaveLimitedPlayerLives(id) then
                        p.lives=GetScoreboardEntryNumLivesRemaining(i,round)
                    end
                    local medalId=GetNextScoreboardEntryMedalId(i,round,nil)
                    local seen={}
                    while medalId and medalId~=0 and not seen[medalId] do
                        seen[medalId]=true
                        local name,icon,_,reward=GetMedalInfo(medalId)
                        local quantity=GetScoreboardEntryNumEarnedMedalsById(i,medalId,round)
                        table.insert(p.medalDetails,{id=medalId,name=name,icon=icon,count=quantity,points=quantity*reward})
                        medalId=GetNextScoreboardEntryMedalId(i,round,medalId)
                    end
                    table.sort(p.medalDetails,function(a,b) return a.points>b.points end)
                    table.insert(snapshot.teams[team].players,p)
                end
            end
            m.rounds[round]=snapshot
        end
    end
    if m.finished and m.numRounds>1 then
        m.total=C.Total(m)
        if m.total then
            local stat=Objective(m.total.gameType)
            local fields={kills=SCORE_TRACKER_TYPE_KILL,deaths=SCORE_TRACKER_TYPE_DEATH,
                assists=SCORE_TRACKER_TYPE_ASSISTS,damage=SCORE_TRACKER_TYPE_DAMAGE_DONE,
                healing=SCORE_TRACKER_TYPE_HEALING_DONE,medals=SCORE_TRACKER_TYPE_SCORE,objective=stat}
            for _,team in ipairs(m.teamIds) do
                local data=m.total.teams[team]
                data.score=GetCurrentBattlegroundRoundsWonByTeam(team)
                local result=GetBattlegroundResultForTeam(team)
                data.won=result==BATTLEGROUND_RESULT_WIN or result==BATTLEGROUND_RESULT_TIE
                for _,p in ipairs(data.players) do
                    -- Use the native cumulative values for the final roster. Earlier
                    -- departed players retain the totals of their captured rounds.
                    if p.roundIndex==m.currentRound then
                        for field,scoreType in pairs(fields) do
                            p[field]=GetBattlegroundCumulativeScoreForScoreboardEntryByType(p.entryIndex,scoreType,p.roundIndex) or p[field]
                        end
                    end
                end
            end
            if not wasFinished or not hadTotal then self.viewRound='total' end
        end
    end
end
function A:Snapshot()
    if self.match and self.viewRound=='total' then return self.match.total end
    return self.match and self.match.rounds[self.viewRound or self.match.currentRound]
end
function A:Build()
    local win=WM:CreateControl('ScoreboardFixXboxWindow',BATTLEGROUND_SCOREBOARD_FRAGMENT.control,CT_CONTROL); self.window=win
    win:SetHidden(true); win:SetMouseEnabled(false)
    self.board=WM:CreateControl(nil,win,CT_CONTROL)
    Back(self.board,0.015,0.018,0.017,0.75)
    self.title=Label(win,FONT_TITLE); Place(self.title,26,12,710,50)
    self.timer=Label(win,FONT_ROW); Place(self.timer,785,12,260,50); self.timer:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.roundButton=Heading(win,''); Place(self.roundButton,410,54,270,30)
    self.roundButton.label:SetFont(FONT_ROW)
    self.headerDivider=WM:CreateControl('ScoreboardFixXboxHeaderDivider',win,CT_TEXTURE)
    self.headerDivider:SetTexture('EsoUI/Art/Miscellaneous/horizontalDivider.dds')
    self.headerDivider:SetTextureCoords(0.181640625,0.818359375,0,1)
    self.headerDivider:SetDrawLayer(DL_OVERLAY)
    self.headerDivider:SetDrawTier(DT_HIGH)
    self.headerDivider:SetColor(1.0,0.95,0.72,1.0)
    self.headerDivider:SetBlendMode(TEX_BLEND_MODE_ADD)
    self.teamScoreHeader=Label(win,FONT_HEADER,'TEAM SCORE'); self.teamScoreHeader:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.livesHeader=WM:CreateControl(nil,win,CT_TEXTURE); self.livesHeader:SetTexture('EsoUI/Art/Trials/VitalityDepletion.dds')
    self.livesHeader:SetColor(1,1,1,1); self.livesHeader:SetAlpha(1); self.livesHeader:SetBlendMode(TEX_BLEND_MODE_ADD)
    for i,col in ipairs(cols) do
        local b=Heading(win,col.title)
        b.label:ClearAnchors(); b.label:SetAnchor(TOPLEFT,b,TOPLEFT,0,0); b.label:SetDimensions(col.w,38)
        -- Every player-data header is centred over its dedicated column.
        b.label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        if col.key=='damage' then
            SetupIconHeader(b)
            self.damageHeader=b
        elseif col.key=='healing' then
            SetupIconHeader(b)
            self.healingHeader=b
        elseif col.key=='objective' then
            SetupIconHeader(b)
            self.objectiveHeader=b
        end
        Place(b,col.x,83,col.w,HEADER_CONTROL_HEIGHT); self.headers[i]=b
    end
    self.empty=Label(win,FONT_ROW,'No battleground data yet.'); Place(self.empty,180,200,750,60)
    for _,team in ipairs(order) do
        local t={}; self.teamControls[team]=t
        t.line=WM:CreateControl(nil,win,CT_TEXTURE); t.line:SetColor(GetBattlegroundTeamColor(team):UnpackRGBA())
        t.icon=WM:CreateControl(nil,win,CT_TEXTURE); t.icon:SetTexture(ZO_GetLargeBattlegroundTeamSymbolIcon(team))
        t.score=Label(win,FONT_SCORE); t.score:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    end
    self.detail=WM:CreateControl(nil,win,CT_CONTROL)
    self.detail:SetMouseEnabled(false)
    self.detail:SetHidden(true)
    Back(self.detail,0.015,0.018,0.017,0.96)
    self.detailUserID=Label(self.detail,FONT_ROW); Place(self.detailUserID,15,12,280,42)
    self.detailCharacter=Label(self.detail,FONT_ROW); Place(self.detailCharacter,15,50,280,42)
    self.detailCharacter:SetColor(0.66,0.65,0.56,1)
    self.detailStats=Label(self.detail,FONT_HEADER); Place(self.detailStats,15,98,280,66)
    self.detailTitle=Label(self.detail,FONT_HEADER,'TOP MEDALS'); Place(self.detailTitle,15,175,200,36)
    self.detailPoints=Label(self.detail,FONT_HEADER,'POINTS'); Place(self.detailPoints,224,175,71,36)
    self.detailPoints:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.medalLabels={}
    for i=1,12 do
        local icon=WM:CreateControl(nil,self.detail,CT_TEXTURE); Place(icon,15,222+(i-1)*48,30,30)
        local name=Label(self.detail,FONT_HEADER); Place(name,52,216+(i-1)*48,175,43)
        local points=Label(self.detail,FONT_HEADER); Place(points,235,216+(i-1)*48,60,43); points:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        self.medalLabels[i]={icon=icon,name=name,points=points}
    end
    self.detailFooter=Label(self.detail,FONT_HEADER)
    self.detailEmpty=Label(self.detail,FONT_HEADER,'No medals earned')
    Place(self.detailEmpty,15,216,280,44)
    win:SetDrawTier(DT_HIGH)
    win:SetHandler('OnUpdate',function(_,now) if self.visible then self:UpdateTimer() end end)
end
function A:Row(index)
    if self.rows[index] then return self.rows[index] end
    local r={}; self.rows[index]=r
    r.control=WM:CreateControl(nil,self.window,CT_CONTROL); r.control:SetMouseEnabled(false)
    r.highlight=Back(r.control,0.6,0.6,0.3,0.06); r.highlight:SetHidden(true); r.highlight:SetMouseEnabled(false)
    r.lives=Label(r.control,FONT_ROW); r.lives:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    r.icon=WM:CreateControl(nil,r.control,CT_TEXTURE)
    r.name=Label(r.control,FONT_ROW); r.character=Label(r.control,FONT_ROW)
    r.name:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    r.character:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    r.character:SetColor(0.66,0.65,0.56,1)
    r.values={}
    for i=3,#cols do r.values[i]=Label(r.control,FONT_ROW); r.values[i]:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
    return r
end
function A:Render()
    local snapshot=self:Snapshot()
    local teamIds=self.match and self.match.teamIds or order
    local capacity=self.match and self.match.capacity or 6
    local rowHeight=capacity==4 and 52 or 48
    local headerHeight=HEADER_HEIGHT
    local height=C.Layout(#teamIds,capacity,rowHeight,headerHeight,18,14)
    local left=22
    local teamWidth=142
    local livesWidth=snapshot and snapshot.showLives and 40 or 0
    local rowX=left+teamWidth
    local x=rowX+livesWidth+36
    for _,col in ipairs(cols) do col.x=x;x=x+col.w+(col.gapAfter or 6) end
    local boardWidth=x+left-6
    -- The main board owns the centred parent; the panel extends to its right.
    -- All board-local coordinates remain identical to 0.1.2.
    local panel=C.PanelLayout(boardWidth,height,GuiRoot:GetWidth(),GuiRoot:GetHeight())
    self.panelLayout=panel
    self.window:SetDimensions(boardWidth,height);self.window:SetScale(panel.scale)
    self.window:ClearAnchors();self.window:SetAnchor(CENTER,GuiRoot,CENTER,0,-30)
    self.detail:ClearAnchors()
    self.detail:SetAnchor(TOPLEFT,self.board,TOPRIGHT,panel.gap,0)
    self.detail:SetDimensions(panel.width,height)
    local inner=panel.width-30
    Place(self.detailUserID,15,12,inner,42)
    Place(self.detailCharacter,15,50,inner,42)
    Place(self.detailStats,15,98,inner,66)
    Place(self.detailTitle,15,175,panel.compact and inner or inner-80,36)
    Place(self.detailPoints,panel.width-86,175,71,36)
    self.detailPoints:SetHidden(panel.compact)
    Place(self.detailEmpty,15,216,inner,44)
    for i,v in ipairs(self.medalLabels) do
        local y=216+(i-1)*panel.rowHeight
        Place(v.icon,15,y+7,30,30)
        Place(v.name,52,y,panel.compact and panel.width-67 or panel.width-135,panel.compact and 30 or 44)
        Place(v.points,panel.compact and 52 or panel.width-75,panel.compact and y+28 or y,
            panel.compact and panel.width-67 or 60,panel.compact and 28 or 44)
    end
    Place(self.detailFooter,15,height-42,inner,32)
    Place(self.board,0,0,boardWidth,height)
    local hasRounds=self.match and (self.match.numRounds or 1)>1
    Place(self.title,left,8,hasRounds and (boardWidth/2-180-left) or (boardWidth-390),52)
    Place(self.timer,boardWidth-350,8,280,52)
    Place(self.roundButton,boardWidth/2-105,8,210,52)
    Place(self.headerDivider,16,HEADER_DIVIDER_Y,boardWidth-32,8)
    Place(self.teamScoreHeader,left,HEADER_ROW_Y,teamWidth,38)
    Place(self.livesHeader,rowX+3,HEADER_ROW_Y+HEADER_ICON_OFFSET_Y,HEADER_ICON_SIZE,HEADER_ICON_SIZE)
    self.livesHeader:SetHidden(livesWidth==0)
    for i,col in ipairs(cols) do Place(self.headers[i],col.x,HEADER_ROW_Y,col.w,HEADER_CONTROL_HEIGHT) end
    self.flat={}
    for _,r in ipairs(self.rows) do r.control:SetHidden(true) end
    for _,t in pairs(self.teamControls) do t.line:SetHidden(true);t.score:SetHidden(true);t.icon:SetHidden(true) end
    self.empty:SetHidden(snapshot~=nil)
    self.title:SetText(string.upper(snapshot and (snapshot.title or 'BATTLEGROUND') or 'BATTLEGROUNDS'))
    local hideRounds=not self.match or (self.match.numRounds or 1)<=1
    self.roundButton:SetHidden(hideRounds)
    if self.match then
        self.roundButton.label:SetText(self.viewRound=='total' and 'RESULT' or ('ROUND '..(self.viewRound or self.match.currentRound)))
    end
    if not snapshot then self.detail:SetHidden(true);return end
    if self.damageHeader then
        self.damageHeader.icon:SetTexture(HEADER_ICON_DAMAGE)
        for _,outline in ipairs(self.damageHeader.outlines or {}) do
            outline:SetTexture(HEADER_ICON_DAMAGE)
        end
        self.damageHeader.icon:SetHidden(false)
        for _,outline in ipairs(self.damageHeader.outlines or {}) do outline:SetHidden(false) end
        self.damageHeader.glow:SetHidden(false)
        self.damageHeader.label:SetHidden(true)
    end
    if self.healingHeader then
        self.healingHeader.icon:SetTexture(HEADER_ICON_HEALING)
        for _,outline in ipairs(self.healingHeader.outlines or {}) do
            outline:SetTexture(HEADER_ICON_HEALING)
        end
        self.healingHeader.icon:SetHidden(false)
        for _,outline in ipairs(self.healingHeader.outlines or {}) do outline:SetHidden(false) end
        self.healingHeader.glow:SetHidden(false)
        self.healingHeader.label:SetHidden(true)
    end
    if self.objectiveHeader then
        local objectiveTexture=ObjectiveIcon(snapshot.gameType)
        self.objectiveHeader.icon:SetTexture(objectiveTexture)
        for _,outline in ipairs(self.objectiveHeader.outlines or {}) do
            outline:SetTexture(objectiveTexture)
        end
        self.objectiveHeader.icon:SetHidden(false)
        for _,outline in ipairs(self.objectiveHeader.outlines or {}) do outline:SetHidden(false) end
        self.objectiveHeader.glow:SetHidden(false)
        self.objectiveHeader.label:SetHidden(true)
    end
    local y=headerHeight
    for _,team in ipairs(teamIds) do
        local data=snapshot.teams[team] or {players={},score=0}
        -- Native roster order makes LB/RB selection follow the displayed rows.
        local players=self:NativeOrderedPlayers(data.players,team)
        local t=self.teamControls[team]
        if t then
            t.line:SetHidden(false);t.score:SetHidden(false);t.icon:SetHidden(false)
            local teamBlockHeight=capacity*rowHeight
            local teamCenter=y+10+teamBlockHeight/2
            Place(t.line,16,y,boardWidth-32,2)
            Place(t.icon,left+(teamWidth-64)/2,teamCenter-103,64,64)
            Place(t.score,left,teamCenter-31,teamWidth,62)
            t.score:SetText(data.score or 0)
            if data.won and ZO_BATTLEGROUND_WINNER_TEXT then
                t.score:SetColor(ZO_BATTLEGROUND_WINNER_TEXT:UnpackRGB())
            elseif ZO_WHITE then
                t.score:SetColor(ZO_WHITE:UnpackRGB())
            else
                t.score:SetColor(1,1,1,1)
            end
        end
        local startY=y+10
        for slot,p in ipairs(players) do
            table.insert(self.flat,p);local r=self:Row(#self.flat);r.data=p;r.control:SetHidden(false)
            Place(r.control,rowX,startY+(slot-1)*rowHeight,boardWidth-left-rowX,rowHeight)
            Place(r.lives,0,0,livesWidth,rowHeight);r.lives:SetHidden(not snapshot.showLives)
            r.lives:SetText(p.lives or 0)
            Place(r.icon,livesWidth,(rowHeight-30)/2,30,30)
            local ci=GetClassIndexById(p.classId)
            if ci then local _,_,_,_,_,_,keyboard,gamepad=GetClassInfo(ci);r.icon:SetTexture(gamepad or keyboard) end
            Place(r.name,cols[1].x-rowX,0,cols[1].w,rowHeight)
            Place(r.character,cols[2].x-rowX,0,cols[2].w,rowHeight)
            r.name:SetText(p.displayName);r.character:SetText(CleanName(p.characterName))
            for i=3,#cols do
                local col=cols[i];local value=p[col.key]
                if col.key=='kd' then value=C.RatioText(p.kills,p.deaths)
                elseif col.key=='damage' or col.key=='healing' then value=C.Number(value)
                elseif col.key=='objective' then value=snapshot.gameType==BATTLEGROUND_GAME_TYPE_MURDERBALL and tostring(value)..'s' or C.Number(value) end
                r.values[i]:SetText(value);Place(r.values[i],col.x-rowX,0,col.w,rowHeight)
            end
        end
        y=y+capacity*rowHeight+18
    end
    local found=false
    for _,p in ipairs(self.flat) do if C.Key(p)==self.selected then found=true end end
    if not found then
        self.selected=nil
        for _,p in ipairs(self.flat) do if p.isLocalPlayer then self.selected=C.Key(p);break end end
        if not self.selected and self.flat[1] then self.selected=C.Key(self.flat[1]) end
    end
    self:UpdateSelection();self:UpdateTimer()
end
function A:UpdateSelection()
    for _,r in ipairs(self.rows) do
        if r.data then
            local active=C.Key(r.data)==self.selected
            r.highlight:SetHidden(not active)
            r.name:SetColor(active and 1 or 0.82,active and 1 or 0.80,active and 0.94 or 0.65,1)
        end
    end
    self:UpdateDetailPanel()
end
function A:UpdateDetailPanel()
    -- Native selection is authoritative, including during a round transition.
    local selected=BATTLEGROUND_SCOREBOARD_FRAGMENT.selectedPlayerData
    local snapshot=self:Snapshot()
    local player
    if selected and snapshot then
        local key=C.Key({displayName=selected.displayName,characterName=CleanName(selected.characterName)})
        for _,team in ipairs(self.match.teamIds) do
            for _,p in ipairs(snapshot.teams[team].players) do
                if C.Key(p)==key then player=p;break end
            end
            if player then break end
        end
    end
    self.detail:SetHidden(not player)
    if not player then return end
    self.detailUserID:SetText(player.displayName)
    self.detailCharacter:SetText(CleanName(player.characterName))
    self.detailStats:SetText('DAMAGE   '..C.Number(player.damage)..'\nHEALING   '..C.Number(player.healing))
    local medals=player.medalDetails
    local maximum=self.panelLayout and self.panelLayout.rows or 0
    for i,labels in ipairs(self.medalLabels) do
        local medal=i<=maximum and medals[i]
        labels.icon:SetHidden(not medal);labels.name:SetHidden(not medal);labels.points:SetHidden(not medal)
        if medal then
            labels.icon:SetTexture(medal.icon)
            labels.name:SetText(medal.count..'  '..medal.name)
            labels.points:SetText(C.Number(medal.points)..(self.panelLayout.compact and ' pts' or ''))
        end
    end
    self.detailEmpty:SetHidden(#medals>0)
    local remaining=math.max(0,#medals-maximum)
    self.detailFooter:SetText(remaining>0 and ('+'..remaining..' more') or '')
end
function A:UpdateTimer()
    if not self.inMatch or not IsActiveWorldBattleground() then self.timer:SetText(self.match and 'Match ended' or '');return end
    local state=GetCurrentBattlegroundState();local prefix=''
    if state==BATTLEGROUND_STATE_FINISHED then prefix='Closing '
    elseif state==BATTLEGROUND_STATE_STARTING then prefix='Starting '
    elseif state==BATTLEGROUND_STATE_PREROUND then prefix='Waiting '
    elseif state==BATTLEGROUND_STATE_POSTROUND then prefix='Round ends ' end
    self.timer:SetText(IsCurrentBattlegroundStateTimed() and prefix..C.Time(GetCurrentBattlegroundStateTimeRemaining()) or '')
end
local function Loaded(_,name)
    if name~=A.name then return end
    EM:UnregisterForEvent(A.name,EVENT_ADD_ON_LOADED)
    if not A:NativeAvailable() then
        d('Scoreboard Fix Xbox: native scoreboard unavailable; vanilla remains active.')
        return
    end
    A:Build()
    A:InstallNativeIntegration()
    EM:RegisterForEvent(A.name,EVENT_SCREEN_RESIZED,function() if A.visible then A:Render() end end)
end
EM:RegisterForEvent(A.name,EVENT_ADD_ON_LOADED,Loaded)
