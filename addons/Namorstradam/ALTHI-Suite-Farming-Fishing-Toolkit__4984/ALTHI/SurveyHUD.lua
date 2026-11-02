local A=ALTHarvestItems
local titles={alchemy='ALCHEMY',metal='BLACKSMITHING',wood='WOODWORKING_47A0D9',cloth='CLOTHING',jewelry='JEWELRY',runes='ENCHANTING'}
function A:CloseSurveyList()
    if not self.surveyWindow then return false end
    self.db.ui.surveyVisible=false; self.surveyRequestedVisible=false; self:StopSurveyBatch(); self.surveyWindow:SetHidden(true)
    return true
end
function A:UpdateSurveyVisibility()
    local w=self.surveyWindow; if not w then return end
    local menu=self.db.options.hideInMenus~=false and not self:SuiteBaseScene()
    self.surveyMenuSuppressed=menu
    local hidden=not self.surveyRequestedVisible or menu
    local wasHidden=w:IsHidden()
    if hidden~=wasHidden then
        if hidden then w:SetHidden(true); self:StopSurveyBatch()
        else self:Front(w); self:DrawSurveyList(); self:EnsureSurveyTicker() end
    end
end
function A:OpenSurveyShortcut()
    if self.surveyWindow and self.surveyRequestedVisible then
        self:UpdateSurveyStock(); self:UpdateSurveyVisibility()
        if not self.surveyWindow:IsHidden() then self.surveyWindow:BringWindowToTop(); self:ReleaseSuiteMouse() end
        return -- Open-only key. Never toggle off or reset the current scroll position.
    end
    local key=self.db.ui.surveyProfession or 'alchemy'; if not titles[key] then key='alchemy' end
    self:OpenSurveyList(key,titles[key])
end
local visible=A.UpdateWindowVisibility
function A:UpdateWindowVisibility()
    visible(self)
    if self.window and self.window:IsHidden() then self.surveyHovered=nil; self:HideSurveyTip() end
    self:UpdateSurveyVisibility()
end
local language=A.InitializeLanguage
function A:InitializeLanguage()
    language(self); ZO_CreateStringId('SI_BINDING_NAME_ALTHI_SURVEY_MINIMIZE',self:T('BIND_SURVEY_MINIMIZE'))
    ZO_CreateStringId('SI_BINDING_NAME_ALTHI_SURVEYS',self:T('BIND_SURVEYS_OPEN'))
end

-- Folding is independent from the visibility shortcut; never opens a closed HUD.
function A:ToggleSurveyFoldShortcut()
    if self.surveyRequestedVisible and self.surveyWindow and not self.surveyWindow:IsHidden() then
        self:ToggleSurveyMinimized()
    end
end
