-- Statistics report controller navigation.
-- This module is intentionally presentation-only: it reuses the statistics
-- report functions and pooled controls instead of duplicating report logic.

BUI=BUI or {}
BUI.Stats=BUI.Stats or {}
BUI.Stats.Gamepad=BUI.Stats.Gamepad or {}
local Gamepad=BUI.Stats.Gamepad

Gamepad.active=false
Gamepad.level="targets"
Gamepad.index=1
Gamepad.parentIndex=1
Gamepad.currentTab=1

local TAB_CONTROLS={
	"BUI_Report_Dbutton",
	"BUI_Report_Hbutton",
	"BUI_Report_Rbutton",
	"BUI_Report_Ibutton",
	"BUI_Report_Gbutton",
}

local function Global(name)
	return rawget(_G,name)
end

local function KeyIs(key,name)
	local value=Global(name)
	return value~=nil and key==value
end

local function Visible(control)
	return control and control.IsHidden and not control:IsHidden()
end

local function Enabled(control)
	if not control then return false end
	if control.IsEnabled then return control:IsEnabled() end
	if control.GetState then
		local state=control:GetState()
		return state~=Global("BSTATE_DISABLED") and state~=Global("BSTATE_DISABLED_PRESSED")
	end
	return true
end

local function ReportIsShowing()
	return Visible(Global("BUI_Report"))
end

local function InGamepadMode()
	local fn=Global("IsInGamepadPreferredMode")
	return type(fn)=="function" and fn() or false
end

local function SortReportControls(a,b)
	local ai=a.reportIndex or a.index or a.id or 0
	local bi=b.reportIndex or b.index or b.id or 0
	if ai==bi and a.GetTop and b.GetTop then return (a:GetTop() or 0)<(b:GetTop() or 0) end
	return ai<bi
end

local function PoolControls(pool)
	local result={}
	if not pool or not pool.m_Active then return result end
	for _,control in pairs(pool.m_Active) do
		if Visible(control) then result[#result+1]=control end
	end
	table.sort(result,SortReportControls)
	return result
end

function Gamepad:GetTargets()
	return PoolControls(BUI.Stats.TargetPool)
end

function Gamepad:GetAbilities()
	return PoolControls(BUI.Stats.AbilityPool)
end

function Gamepad:GetEntries()
	if self.level=="targets" then return self:GetTargets() end
	if self.level=="abilities" or self.level=="group" then return self:GetAbilities() end
	return {}
end

function Gamepad:CanUseUptimes()
	return self.currentTab==1 and Visible(Global("BUI_Report_Ubutton_Base"))
		and BUI.Stats.HasUptimes and BUI.Stats.HasUptimes()
end

function Gamepad:CanScroll()
	if (self.level=="abilities" or self.level=="group") and #self:GetAbilities()>11 then return true end
	local buffs=Global("BUI_Report_BuffsUp_Names")
	local buffsViewport=Global("BUI_Report_BuffsUp_Content")
	if Visible(buffs) and buffsViewport and buffs:GetHeight()>buffsViewport:GetHeight() then return true end
	local expanded=Global("BUI_Report") and BUI_Report.expanded
	if expanded and expanded.d and Visible(expanded.d.names) and expanded.d.content
		and expanded.d.names:GetHeight()>expanded.d.content:GetHeight() then return true end
	return false
end

function Gamepad:WantsFocus()
	if not ReportIsShowing() or not BUI.Vars or not BUI.Vars.StatsGamepadNavigation then return false end
	return not BUI.Vars.StatsAutoGamepadNavigation or InGamepadMode()
end

function Gamepad:CreateHighlights()
	if self.highlight then return end
	local function Create(name,edgeAlpha)
		local window=WINDOW_MANAGER:CreateTopLevelWindow(name)
		window:SetDrawTier(DT_HIGH)
		window:SetDrawLayer(DL_OVERLAY)
		window:SetDrawLevel(30)
		window:SetMouseEnabled(false)
		window:SetHidden(true)
		local backdrop=WINDOW_MANAGER:CreateControl(name.."Backdrop",window,CT_BACKDROP)
		backdrop:SetAnchorFill(window)
		backdrop:SetCenterColor(1,.82,.2,.10)
		backdrop:SetEdgeColor(1,.82,.2,edgeAlpha)
		backdrop:SetEdgeTexture("",8,2,2)
		return window,backdrop
	end
	self.highlight,self.highlightBackdrop=Create("BUI_Statistics_GamepadFocus",1)
	self.tabHighlight,self.tabHighlightBackdrop=Create("BUI_Statistics_GamepadTabFocus",.9)
end

function Gamepad:GetSelectedControl()
	if self.level=="aux" then
		if self.auxKind=="equipment" then return Global("BUI_Report_Einfo") end
		if self.auxKind=="uptimes" then return Global("BUI_Report_Uptimes") end
	end
	local entries=self:GetEntries()
	if #entries==0 then return nil end
	self.index=math.max(1,math.min(self.index or 1,#entries))
	return entries[self.index]
end

function Gamepad:RefreshKeybinds()
	local strip=Global("KEYBIND_STRIP")
	if self.keybindsAdded and strip and strip.UpdateKeybindButtonGroup then
		strip:UpdateKeybindButtonGroup(self.keybindDescriptor)
	end
end

function Gamepad:RefreshHighlight()
	self:CreateHighlights()
	if not self.active then
		self.highlight:SetHidden(true)
		self.tabHighlight:SetHidden(true)
		return
	end
	local selected=self:GetSelectedControl()
	if selected and Visible(selected) then
		local large=BUI.Vars and BUI.Vars.StatsLargeGamepadUI
		local padding=large and 8 or 4
		self.highlight:ClearAnchors()
		self.highlight:SetAnchor(TOPLEFT,selected,TOPLEFT,-padding,-padding)
		self.highlight:SetAnchor(BOTTOMRIGHT,selected,BOTTOMRIGHT,padding,padding)
		self.highlightBackdrop:SetCenterColor(1,.82,.2,large and .14 or .08)
		self.highlightBackdrop:SetEdgeTexture("",8,2,2)
		self.highlight:SetHidden(false)
	else
		self.highlight:SetHidden(true)
	end
	local tab=Global(TAB_CONTROLS[self.currentTab])
	if tab and Visible(tab) then
		self.tabHighlight:ClearAnchors()
		self.tabHighlight:SetAnchor(TOPLEFT,tab,TOPLEFT,-2,-2)
		self.tabHighlight:SetAnchor(BOTTOMRIGHT,tab,BOTTOMRIGHT,2,2)
		self.tabHighlight:SetHidden(false)
	else
		self.tabHighlight:SetHidden(true)
	end
	self:RefreshKeybinds()
end

function Gamepad:ScrollRelative(direction,amount)
	local scrollFn=Global("ZO_Scroll_ScrollRelative")
	if type(scrollFn)~="function" then return false end
	local controls={}
	if self.level=="abilities" or self.level=="group" then
		controls[#controls+1]=Global("BUI_Report_Content_ScrollContainer")
	end
	controls[#controls+1]=Global("BUI_Report_BuffsUp_Content_ScrollContainer")
	local expanded=Global("BUI_Report") and BUI_Report.expanded
	if expanded and expanded.d and expanded.d.content and expanded.d.content.GetName then
		controls[#controls+1]=Global(expanded.d.content:GetName().."_ScrollContainer")
	end
	local moved=false
	for _,control in ipairs(controls) do
		if Visible(control) then
			scrollFn(control,(amount or 120)*direction)
			moved=true
		end
	end
	return moved
end

function Gamepad:KeepSelectionVisible(control,direction)
	if not control or (self.level~="abilities" and self.level~="group") then return end
	local viewport=Global("BUI_Report_Content")
	if not viewport or not viewport.GetTop then return end
	local top,bottom=control:GetTop(),control:GetBottom()
	local viewTop,viewBottom=viewport:GetTop(),viewport:GetBottom()
	if not top or not viewTop then return end
	if bottom>viewBottom then self:ScrollRelative(1,bottom-viewBottom+8)
	elseif top<viewTop then self:ScrollRelative(-1,viewTop-top+8) end
end

function Gamepad:MoveSelection(direction)
	if self.level=="aux" then return end
	local entries=self:GetEntries()
	if #entries==0 then self.index=1 self:RefreshHighlight() return end
	self.index=math.max(1,math.min((self.index or 1)+direction,#entries))
	self:KeepSelectionVisible(entries[self.index],direction)
	self:RefreshHighlight()
	PlaySound("Click")
end

function Gamepad:ResetForTab()
	if not self.active then return end
	if self.currentTab==5 then
		self.level="group"
		self.index=1
	else
		if BUI.Stats.CollapseExpandedTarget then BUI.Stats.CollapseExpandedTarget() end
		self.level="targets"
		self.index=1
	end
	self.auxKind=nil
	self:RefreshHighlight()
end

function Gamepad:SwitchTab(direction)
	local nextTab=math.max(1,math.min((self.currentTab or 1)+direction,#TAB_CONTROLS))
	if nextTab==self.currentTab then return end
	self.currentTab=nextTab
	if nextTab==1 then BUI.Stats.SetupReport("Damage")
	elseif nextTab==2 then BUI.Stats.SetupReport("Healing")
	elseif nextTab==3 then BUI.Stats.SetupReport("Power")
	elseif nextTab==4 then BUI.Stats.SetupReport("Incoming")
	else BUI.Stats.SetupGroupReport() end
	PlaySound("Click")
end

function Gamepad:ChangeReport(previous)
	if not ReportIsShowing() then return end
	local button=Global(previous and "BUI_Report_Prev" or "BUI_Report_Next")
	if not Enabled(button) then return end
	BUI.Stats.NextReport(previous)
	self:ResetForTab()
	PlaySound("Click")
end

function Gamepad:ActivateSelection()
	if self.level~="targets" then return end
	local control=self:GetSelectedControl()
	if not control or not Enabled(control.expand) then return end
	self.parentIndex=self.index
	BUI.Stats.ExpandTarget(control.expand)
	if Visible(Global("BUI_Report_Ability")) and #self:GetAbilities()>0 then
		self.level="abilities"
		self.index=1
	end
	self:RefreshHighlight()
	PlaySound("Click")
end

function Gamepad:SyncExpandedTarget(expandButton)
	if not self.active then return end
	local expanded=Global("BUI_Report") and BUI_Report.expanded
	if expanded and Visible(Global("BUI_Report_Ability")) and #self:GetAbilities()>0 then
		self.level="abilities"
		self.parentIndex=expanded.reportIndex or (expandButton and expandButton:GetParent().reportIndex) or self.parentIndex or 1
		self.index=1
	else
		self.level=self.currentTab==5 and "group" or "targets"
		self.index=(expandButton and expandButton:GetParent().reportIndex) or self.parentIndex or 1
	end
	self.auxKind=nil
	self:RefreshHighlight()
end

function Gamepad:ToggleAux(kind)
	if kind=="uptimes" and not self:CanUseUptimes() then return end
	if self.level~="aux" then
		self.returnLevel=self.level
		self.returnIndex=self.index
	end
	if kind=="equipment" then BUI.Stats.ToggleEquipmentInfo()
	else BUI.Stats.SetupUptimes() end
	local panel=kind=="equipment" and Global("BUI_Report_Einfo") or Global("BUI_Report_Uptimes")
	if Visible(panel) then
		self.level="aux"
		self.auxKind=kind
	else
		self.level=self.returnLevel or (self.currentTab==5 and "group" or "targets")
		self.index=self.returnIndex or 1
		self.auxKind=nil
	end
	self:RefreshHighlight()
	PlaySound("Click")
end

function BUI.Stats.ToggleReportAuxFromMouse(kind)
	if Gamepad.active then
		Gamepad:ToggleAux(kind)
		return
	end
	PlaySound("Click")
	if kind=="equipment" then BUI.Stats.ToggleEquipmentInfo()
	elseif kind=="uptimes" then BUI.Stats.SetupUptimes() end
end

function BUI.Stats.ExpandTargetFromMouse(expandButton)
	PlaySound("Click")
	BUI.Stats.ExpandTarget(expandButton)
	Gamepad:SyncExpandedTarget(expandButton)
end

function Gamepad:Back()
	if self.level=="aux" then
		local kind=self.auxKind
		if kind=="equipment" and Visible(Global("BUI_Report_Einfo")) then BUI.Stats.ToggleEquipmentInfo()
		elseif kind=="uptimes" and Visible(Global("BUI_Report_Uptimes")) then BUI.Stats.SetupUptimes() end
		self.level=self.returnLevel or (self.currentTab==5 and "group" or "targets")
		self.index=self.returnIndex or 1
		self.auxKind=nil
		self:RefreshHighlight()
	elseif self.level=="abilities" then
		if BUI.Stats.CollapseExpandedTarget then BUI.Stats.CollapseExpandedTarget() end
		self.level="targets"
		self.index=self.parentIndex or 1
		self:RefreshHighlight()
	else
		BUI.Stats.Toggle()
	end
	PlaySound("Click")
end

function Gamepad:CloseCompletely()
	if not ReportIsShowing() then return end
	if Visible(Global("BUI_Report_Einfo")) then BUI.Stats.ToggleEquipmentInfo() end
	if Visible(Global("BUI_Report_Uptimes")) then BUI.Stats.SetupUptimes() end
	if BUI.Stats.CollapseExpandedTarget then BUI.Stats.CollapseExpandedTarget() end
	self.level="targets"
	self.index=1
	self.parentIndex=1
	self.returnLevel=nil
	self.returnIndex=nil
	self.auxKind=nil
	self:Deactivate()
	BUI.Stats.Toggle()
end

function BUI.Stats.CloseCombatReportCompletely()
	Gamepad:CloseCompletely()
end

function Gamepad:HandleKeyDown(key)
	if not self.active then return false end
	if KeyIs(key,"KEY_GAMEPAD_LEFT_SHOULDER") then self:SwitchTab(-1) return true end
	if KeyIs(key,"KEY_GAMEPAD_RIGHT_SHOULDER") then self:SwitchTab(1) return true end
	if KeyIs(key,"KEY_GAMEPAD_DPAD_LEFT") then self:ChangeReport(true) return true end
	if KeyIs(key,"KEY_GAMEPAD_DPAD_RIGHT") then self:ChangeReport(false) return true end
	if KeyIs(key,"KEY_GAMEPAD_DPAD_UP") or KeyIs(key,"KEY_GAMEPAD_LSTICK_UP") then self:MoveSelection(-1) return true end
	if KeyIs(key,"KEY_GAMEPAD_DPAD_DOWN") or KeyIs(key,"KEY_GAMEPAD_LSTICK_DOWN") then self:MoveSelection(1) return true end
	if KeyIs(key,"KEY_GAMEPAD_BUTTON_1") then self:ActivateSelection() return true end
	if KeyIs(key,"KEY_GAMEPAD_BUTTON_2") or KeyIs(key,"KEY_GAMEPAD_BACK") or KeyIs(key,"KEY_GAMEPAD_BACK_HOLD") or KeyIs(key,"KEY_ESCAPE") then self:Back() return true end
	if KeyIs(key,"KEY_GAMEPAD_BUTTON_3") then self:ToggleAux("equipment") return true end
	if KeyIs(key,"KEY_GAMEPAD_BUTTON_4") then self:ToggleAux("uptimes") return true end
	if KeyIs(key,"KEY_GAMEPAD_LEFT_TRIGGER") then self:ScrollRelative(-1,160) return true end
	if KeyIs(key,"KEY_GAMEPAD_RIGHT_TRIGGER") then self:ScrollRelative(1,160) return true end
	return false
end

Gamepad.keybindDescriptor={
	alignment=Global("KEYBIND_STRIP_ALIGN_LEFT"),
	{name="Select / Expand",keybind="UI_SHORTCUT_PRIMARY",visible=function() return Gamepad.active and Gamepad.level=="targets" end,callback=function() Gamepad:ActivateSelection() end},
	{name=function() return (Gamepad.level=="targets" or Gamepad.level=="group") and "Close" or "Back" end,keybind="UI_SHORTCUT_NEGATIVE",visible=function() return Gamepad.active end,callback=function() Gamepad:Back() end},
	{name=function() return Gamepad.level=="aux" and Gamepad.auxKind=="equipment" and "Close Equipment" or "Equipment" end,keybind="UI_SHORTCUT_SECONDARY",visible=function() return Gamepad.active and (Gamepad.level~="aux" or Gamepad.auxKind=="equipment") end,callback=function() Gamepad:ToggleAux("equipment") end},
	{name=function() return Gamepad.level=="aux" and Gamepad.auxKind=="uptimes" and "Close Uptimes" or "Uptimes" end,keybind="UI_SHORTCUT_TERTIARY",visible=function() return Gamepad.active and Gamepad:CanUseUptimes() and (Gamepad.level~="aux" or Gamepad.auxKind=="uptimes") end,callback=function() Gamepad:ToggleAux("uptimes") end},
	{name="Previous Tab",keybind="UI_SHORTCUT_LEFT_SHOULDER",visible=function() return Gamepad.active and Gamepad.level~="aux" and Gamepad.currentTab>1 end,callback=function() Gamepad:SwitchTab(-1) end},
	{name="Next Tab",keybind="UI_SHORTCUT_RIGHT_SHOULDER",visible=function() return Gamepad.active and Gamepad.level~="aux" and Gamepad.currentTab<#TAB_CONTROLS end,callback=function() Gamepad:SwitchTab(1) end},
	{name="Scroll Up",keybind="UI_SHORTCUT_LEFT_TRIGGER",visible=function() return Gamepad.active and Gamepad:CanScroll() end,callback=function() Gamepad:ScrollRelative(-1,160) end},
	{name="Scroll Down",keybind="UI_SHORTCUT_RIGHT_TRIGGER",visible=function() return Gamepad.active and Gamepad:CanScroll() end,callback=function() Gamepad:ScrollRelative(1,160) end},
}

function Gamepad:Activate()
	if self.active or not self:WantsFocus() then return end
	local report=Global("BUI_Report")
	if not report then return end
	self.active=true
	report:SetHandler("OnKeyDown",function(_,key) return Gamepad:HandleKeyDown(key) end)
	if report.TakeFocus then report:TakeFocus() end
	local strip=Global("KEYBIND_STRIP")
	if strip and strip.AddKeybindButtonGroup then
		strip:AddKeybindButtonGroup(self.keybindDescriptor)
		self.keybindsAdded=true
	end
	self:ResetForTab()
end

function Gamepad:Deactivate()
	local report=Global("BUI_Report")
	if report then
		if report.LoseFocus then report:LoseFocus() end
		report:SetHandler("OnKeyDown",nil)
	end
	local strip=Global("KEYBIND_STRIP")
	if self.keybindsAdded and strip and strip.RemoveKeybindButtonGroup then
		strip:RemoveKeybindButtonGroup(self.keybindDescriptor)
	end
	self.keybindsAdded=false
	self.active=false
	if self.highlight then self.highlight:SetHidden(true) end
	if self.tabHighlight then self.tabHighlight:SetHidden(true) end
end

function Gamepad:RefreshActivation()
	if self:WantsFocus() then self:Activate() else self:Deactivate() end
end

local OriginalToggle=BUI.Stats.Toggle
BUI.Stats.Toggle=function(...)
	local wasShowing=ReportIsShowing()
	local result=OriginalToggle(...)
	if ReportIsShowing() then
		Gamepad:RefreshActivation()
	else
		Gamepad:Deactivate()
		if wasShowing and BUI.Stats.ReleaseReportCameraUIMode then BUI.Stats.ReleaseReportCameraUIMode() end
	end
	return result
end

function BUI.Stats.ToggleReportFromMouse()
	if ReportIsShowing() then BUI.Stats.CloseCombatReportCompletely()
	else BUI.Stats.Toggle() end
end

local OriginalSetupReport=BUI.Stats.SetupReport
BUI.Stats.SetupReport=function(context,...)
	local result=OriginalSetupReport(context,...)
	local tabs={Damage=1,Healing=2,Power=3,Incoming=4}
	Gamepad.currentTab=tabs[context] or Gamepad.currentTab
	if Gamepad.active then Gamepad:ResetForTab() end
	return result
end

local OriginalSetupGroupReport=BUI.Stats.SetupGroupReport
BUI.Stats.SetupGroupReport=function(...)
	local result=OriginalSetupGroupReport(...)
	Gamepad.currentTab=5
	if Gamepad.active then Gamepad:ResetForTab() end
	return result
end

if EVENT_MANAGER and Global("EVENT_GAMEPAD_PREFERRED_MODE_CHANGED") then
	EVENT_MANAGER:RegisterForEvent("BUI_Statistics_Gamepad",EVENT_GAMEPAD_PREFERRED_MODE_CHANGED,function()
		Gamepad:RefreshActivation()
	end)
end
