local A=ALTHarvestItems
function A:OpenNativeMail()
    if not SCENE_MANAGER or not SCENE_MANAGER.Show or (IsUnitInCombat and IsUnitInCombat('player'))
        or (IsUnitDead and IsUnitDead('player')) or (ZO_Dialogs_IsShowingDialog and ZO_Dialogs_IsShowingDialog()) then return false end
    local gamepad=IsInGamepadPreferredMode and IsInGamepadPreferredMode()
    local scene=gamepad and 'mailManagerGamepad' or 'mailInbox'
    if SCENE_MANAGER.GetScene and not SCENE_MANAGER:GetScene(scene) then return false end
    if self.StopSurveyBatch then self:StopSurveyBatch() end
    if self.StopSuiteMouse then self:StopSuiteMouse(false) end
    if not gamepad and MAIN_MENU_KEYBOARD and MAIN_MENU_KEYBOARD.ShowScene then MAIN_MENU_KEYBOARD:ShowScene(scene)
    else SCENE_MANAGER:Show(scene) end
    self:GoldInvalidateInbox(); return true
end
function A:MailLink(control)
    if not control then return end
    control:SetMouseEnabled(control:GetText()~='')
    control:SetHandler('OnMouseUp',function(_,button) if button==MOUSE_BUTTON_INDEX_LEFT then self:OpenNativeMail() end end)
    control:SetHandler('OnMouseEnter',function(c) if ZO_Tooltips_ShowTextTooltip then self:ShowSuiteTip(c,TOP,self:T('OPEN_NATIVE_MAIL')) end end)
    control:SetHandler('OnMouseExit',function() if ZO_Tooltips_HideTextTooltip then self:HideSuiteTip() end end)
end
local refresh=A.Refresh
function A:Refresh()
    refresh(self)
    if self.goldHeaderLabels then self:MailLink(self.goldHeaderLabels[4]) end
    if self.suiteCharacterLabels then self:MailLink(self.suiteCharacterLabels.post) end
end
