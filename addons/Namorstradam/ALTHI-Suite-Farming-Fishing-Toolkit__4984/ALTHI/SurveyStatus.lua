local A=ALTHarvestItems
function A:SaveSurveyPosition()
    local w=self.surveyWindow; if not w then return end
    self.db.ui.surveyX=w:GetLeft(); self.db.ui.surveyY=w:GetTop()
end
function A:RestoreSurveyPosition()
    local w=self.surveyWindow; local ui=self.db.ui
    if type(ui.surveyX)=='number' and type(ui.surveyY)=='number' then
        local x=math.max(0,math.min(ui.surveyX,math.max(0,(GuiRoot:GetWidth() or 1920)-w:GetWidth())))
        local y=math.max(0,math.min(ui.surveyY,math.max(0,(GuiRoot:GetHeight() or 1080)-w:GetHeight())))
        w:ClearAnchors(); w:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,x,y)
    end
end
function A:SurveyCurrentArea()
    local name=GetUnitZone and GetUnitZone('player') or ''
    local index=GetUnitZoneIndex and GetUnitZoneIndex('player')
    if index and GetZoneId and GetZoneNameById then
        local native=GetZoneNameById(GetZoneId(index)); if native and native~='' then name=native end
    end
    return self:SurveyZoneBase(name)
end
function A:RefreshSurveyArea()
    local w=self.surveyWindow; if not w or not w.areaTitle or w:IsHidden() then return end
    local area=self:SurveyCurrentArea(); local key=zo_strlower(area); local total,active=0,0
    for i=1,6 do
        local spec=self.professionSpecs[i]; local s=self:SurveySummary(spec[1]); local count=0
        for name,row in pairs(s.areas) do if zo_strlower(self:SurveyZoneBase(name))==key then count=count+row.inventory end end
        total=total+count
        local _,selected=self:ProfessionSelection(spec[1]); if selected>0 then active=active+count end
    end
    local title=area~='' and area..' · '..self:T(total==0 and 'SURVEY_AREA_CLEAR' or active==0 and 'SURVEY_AREA_PASSIVE_ONLY' or 'SURVEY_AREA_REMAINING') or self:T('SURVEY_AREA_UNKNOWN')
    local counts=string.format(self:T('SURVEY_AREA_EYE_COUNTS'),total,'|t18:18:ALTHI/art/visibility_on.dds|t',active,'|t18:18:ALTHI/art/visibility_off.dds|t',total-active)
    if w.areaTitle:GetText()~=title then w.areaTitle:SetText(title) end
    if w.areaCounts:GetText()~=counts then w.areaCounts:SetText(counts) end
end
local layout=A.LayoutSurveyWindow
function A:LayoutSurveyWindow()
    layout(self)
    local w=self.surveyWindow; if w.key~='selected' then return end
    if not w.areaTitle then
        w.areaTitle=self:Label(w,'ZoFontGameBold'); w.areaCounts=self:Label(w,'ZoFontGameSmall')
        w:SetHandler('OnMoveStop',function() self:SaveSurveyPosition() end)
        local resize=w:GetHandler('OnResizeStop')
        w:SetHandler('OnResizeStop',function(c) if resize then resize(c) end; self:SaveSurveyPosition() end)
    end
    w.areaTitle:ClearAnchors(); w.areaTitle:SetAnchor(TOPLEFT,w,TOPLEFT,18,208); w.areaTitle:SetDimensions(w:GetWidth()-36,24)
    w.areaCounts:ClearAnchors(); w.areaCounts:SetAnchor(TOPLEFT,w,TOPLEFT,18,236); w.areaCounts:SetDimensions(w:GetWidth()-36,24)
    w.empty:ClearAnchors(); w.empty:SetAnchor(TOPLEFT,w,TOPLEFT,18,278)
end
local draw=A.DrawSurveyList
function A:DrawSurveyList()
    if self.surveyDrawing then return end -- Native dimension resolution may re-enter OnRect callbacks.
    self.surveyDrawing=true
    local ok,err=pcall(draw,self); self.surveyDrawing=nil
    if not ok then error(err,0) end
    if self.surveyWindow.key=='selected' then self.surveyWindow.title:SetText(self:GoldText(self:T('SURVEY_OVERVIEW'))) end
    self:RefreshSurveyArea()
end
local open=A.OpenSurveyOverview
function A:OpenSurveyOverview()
    local x,y=self.db.ui.surveyX,self.db.ui.surveyY
    open(self)
    if type(x)=='number' and type(y)=='number' then self.db.ui.surveyX=x; self.db.ui.surveyY=y end
    self:RestoreSurveyPosition(); self:SaveSurveyPosition(); self:RefreshSurveyArea()
end
local refresh=A.Refresh
function A:Refresh()
    refresh(self)
    if not self.window then return end
    if not self.professionDivider then
        self.professionDivider=WINDOW_MANAGER:CreateControl(nil,self.window,CT_TEXTURE)
        self.professionDivider:SetColor(0.65,0.65,0.6,0.5); self.professionDivider:SetMouseEnabled(false)
    end
    local line=self.professionDivider; line:SetHidden(self.db.ui.activity~='resources' or self.db.ui.minimized)
    line:ClearAnchors(); line:SetAnchor(TOPLEFT,self.window,TOPLEFT,18,266); line:SetDimensions(self.window:GetWidth()-36,1)
end
