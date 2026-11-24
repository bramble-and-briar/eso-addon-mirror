SimpleDPS.ConfigUI = {
	initialized = false,
	
	openMenu = function (self)
		if SimpleDPSConfigMenu:IsHidden() then
			if not self.initialized then self:initialize() end
			SimpleDPSConfigMenu:SetHidden(false)
		end
	end,
	
	closeMenu = function (self)
		SimpleDPSConfigMenu:SetHidden(true)
	end,
	
	initialize = function (self)
		-- Stats Shown
		statsshown = ZO_ComboBox_ObjectFromContainer(SimpleDPSConfigMenuSectionStatsShownDropdown)
		statsshown.m_sortOrder = false
		formatEntries = {									
			"DPS",
			"Percentage",
			"Total",
			"DPS (Percentage)",
			"Percentage (DPS)",
			"Total (DPS)",
			"DPS (Total)",
			"Total (Percentage)",
			"Percentage (Total)",
			"Total (DPS) Percentage",
			"Total (Percentage) DPS",
			"Percentage (DPS) Total",
			"Percentage (Total) DPS",
			"DPS (Total) Percentage",
			"DPS (Percentage) Total"
		}
		
		for k, v in pairs(formatEntries) do
			item = statsshown:CreateItemEntry(v, function () CALLBACK_MANAGER:FireCallbacks(SimpleDPS.FORMAT_CHANGED) end)
			statsshown:AddItem(item)
		end
		statsshown:SetSelectedItemText(SimpleDPS.config.damageFormat)	
		CALLBACK_MANAGER:RegisterCallback(SimpleDPS.FORMAT_CHANGED, function() self:changeDamageFormat() end, SimpleDPS.name .. "StatsShownClick")
		
		-- Current Fight Behavior
		fightBehavior = ZO_ComboBox_ObjectFromContainer(SimpleDPSConfigMenuSectionCurrentFightBehaviorDropdown)		
		fightBehavior.m_sortOrder = false
		fightEntries = {
			"Reset immediately after combat",
			"Reset shortly after combat",
			"Reset when re-entering combat"
		}
		
		for k, v in pairs(fightEntries) do
			item = fightBehavior:CreateItemEntry(v, function () CALLBACK_MANAGER:FireCallbacks(SimpleDPS.BEHAVIOR_CHANGED) end)
			fightBehavior:AddItem(item)
		end
		fightBehavior:SetSelectedItemText(fightEntries[SimpleDPS.config.resetBehavior])
		CALLBACK_MANAGER:RegisterCallback(SimpleDPS.BEHAVIOR_CHANGED, function() self:changeCurrentFightBehavior() end, SimpleDPS.name .. "CurrentFightBehaviorClick")
		
		-- AutoHide
		SimpleDPSConfigMenuSectionAutoHideName:SetText("Auto Hide meter after combat: ")
		SimpleDPSConfigMenuSectionAutoHideName:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
		SimpleDPSConfigMenuSectionAutoHideName:ClearAnchors()
		SimpleDPSConfigMenuSectionAutoHideName:SetAnchor(CENTER, SimpleDPSConfigMenuSectionAutoHide, CENTER, -74, 0)
		SimpleDPSConfigMenuSectionAutoHideName:SetWidth(275)
		SimpleDPSConfigMenuSectionAutoHideCheckbox.checkedText = "yes"
		SimpleDPSConfigMenuSectionAutoHideCheckbox.uncheckedText = "no"
		ZO_CheckButton_SetCheckState(SimpleDPSConfigMenuSectionAutoHideCheckbox, SimpleDPS.config.autoHideEnabled)
		SimpleDPSConfigMenuSectionAutoHideCheckbox:SetWidth(30)
		SimpleDPSConfigMenuSectionAutoHideCheckbox:ClearAnchors()
		SimpleDPSConfigMenuSectionAutoHideCheckbox:SetAnchor(LEFT, SimpleDPSConfigMenuSectionAutoHideName, RIGHT, 24, 0)				
		SimpleDPSConfigMenuSectionAutoHideCheckbox:SetHandler("OnClicked", function (control) self:toggleAutoHide(control) end, SimpleDPS.name .. "AutoHideClick")
		
		-- Previous Fight
		SimpleDPSConfigMenuSectionPreviousFightName:SetText("Show previous fight stats: ")
		SimpleDPSConfigMenuSectionPreviousFightName:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
		SimpleDPSConfigMenuSectionPreviousFightName:ClearAnchors()
		SimpleDPSConfigMenuSectionPreviousFightName:SetAnchor(CENTER, SimpleDPSConfigMenuSectionPreviousFight, CENTER, -74, 0)
		SimpleDPSConfigMenuSectionPreviousFightName:SetWidth(275)
		SimpleDPSConfigMenuSectionPreviousFightCheckbox.checkedText = "yes"
		SimpleDPSConfigMenuSectionPreviousFightCheckbox.uncheckedText = "no"
		ZO_CheckButton_SetCheckState(SimpleDPSConfigMenuSectionPreviousFightCheckbox, SimpleDPS.config.showPreviousFight)
		SimpleDPSConfigMenuSectionPreviousFightCheckbox:SetWidth(30)
		SimpleDPSConfigMenuSectionPreviousFightCheckbox:ClearAnchors()
		SimpleDPSConfigMenuSectionPreviousFightCheckbox:SetAnchor(LEFT, SimpleDPSConfigMenuSectionPreviousFightName, RIGHT, 24, 0)
		SimpleDPSConfigMenuSectionPreviousFightCheckbox:SetHandler("OnClicked", function (control) self:togglePreviousFight(control) end, SimpleDPS.name .. "PreviousFightClick")
		
		-- Window Scale		
		SimpleDPSConfigMenuSectionWindowScaleSlider:SetValue(SimpleDPS.config.windowScale)
		SimpleDPSConfigMenuSectionWindowScaleValue:SetText(self:formatDecimal(SimpleDPS.config.windowScale * 100, "%"))
		SimpleDPSConfigMenuSectionWindowScaleSlider:SetHandler("OnValueChanged", function(control, value) self:changeWindowScale(value) end)
				
		-- Transparency
		local alpha = 1 - SimpleDPS.config.windowAlpha
		SimpleDPSConfigMenuSectionTransparencyValue:SetText(self:formatDecimal(alpha * 100, "%"))
		SimpleDPSConfigMenuSectionTransparencySlider:SetValue(alpha)		
		SimpleDPSConfigMenuSectionTransparencySlider:SetHandler("OnValueChanged", function(control, value) self:changeTransparencyValue(value) end)
		
		-- Background Color
		SimpleDPSConfigMenuSectionBackgroundColorName:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
		SimpleDPSConfigMenuSectionBackgroundColorName:SetWidth(200)
		SimpleDPSConfigMenuSectionBackgroundColorName:ClearAnchors()
		SimpleDPSConfigMenuSectionBackgroundColorName:SetAnchor(RIGHT, SimpleDPSConfigMenuSectionBackgroundColorColorSection, LEFT, -24, 0)
		SimpleDPSConfigMenuSectionBackgroundColorColorSection:SetWidth(40)
		SimpleDPSConfigMenuSectionBackgroundColorColorSection:ClearAnchors()
		SimpleDPSConfigMenuSectionBackgroundColorColorSection:SetAnchor(RIGHT, SimpleDPSConfigMenuSectionBackgroundColor, RIGHT, 0, 0)
		ZO_SharedOptions:InitializeControl(SimpleDPSConfigMenuSectionBackgroundColor)
		SimpleDPSConfigMenuSectionBackgroundColorColor:SetColor(ZO_ColorDef.FromARGBHexadecimal(SimpleDPS.config.backgroundColor):UnpackRGBA())
		SimpleDPSConfigMenuSectionBackgroundColorColorSection:SetHandler("OnMouseUp", function(self, upInside)
			local colorPicker = SYSTEMS:GetObject("colorPicker")
			ZO_Options_ColorOnMouseUp(self:GetParent(), upInside)
			colorPicker.colorSelectedCallback = function(...) SimpleDPS.ConfigUI:changeBackgroundColor(true, nil, ...) end
			colorPicker.colorSelect:SetHandler("OnColorSelected", function (...) SimpleDPS.ConfigUI:changeBackgroundColor(false, ...) end, SimpleDPS.name .. "BackgroundColorSelect")
		end)
		
		-- Static Color
		SimpleDPSConfigMenuSectionStaticColorName:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
		SimpleDPSConfigMenuSectionStaticColorName:SetWidth(200)
		SimpleDPSConfigMenuSectionStaticColorName:ClearAnchors()
		SimpleDPSConfigMenuSectionStaticColorName:SetAnchor(RIGHT, SimpleDPSConfigMenuSectionStaticColorColorSection, LEFT, -24, 0)
		SimpleDPSConfigMenuSectionStaticColorColorSection:SetWidth(40)
		SimpleDPSConfigMenuSectionStaticColorColorSection:ClearAnchors()
		SimpleDPSConfigMenuSectionStaticColorColorSection:SetAnchor(RIGHT, SimpleDPSConfigMenuSectionStaticColor, RIGHT, 0, 0)
		ZO_SharedOptions:InitializeControl(SimpleDPSConfigMenuSectionStaticColor)
		SimpleDPSConfigMenuSectionStaticColorColor:SetColor(ZO_ColorDef.FromARGBHexadecimal(SimpleDPS.config.staticTextColor):UnpackRGBA())
		SimpleDPSConfigMenuSectionStaticColorColorSection:SetHandler("OnMouseUp", function(self, upInside)
			local colorPicker = SYSTEMS:GetObject("colorPicker")
			ZO_Options_ColorOnMouseUp(self:GetParent(), upInside)
			colorPicker.colorSelectedCallback = function(...) SimpleDPS.ConfigUI:changeStaticColor(true, nil, ...) end
			colorPicker.colorSelect:SetHandler("OnColorSelected", function (...) SimpleDPS.ConfigUI:changeStaticColor(false, ...) end, SimpleDPS.name .. "StaticColorSelect")
		end)
		
		-- Active Color
		SimpleDPSConfigMenuSectionActiveColorName:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
		SimpleDPSConfigMenuSectionActiveColorName:SetWidth(200)
		SimpleDPSConfigMenuSectionActiveColorName:ClearAnchors()
		SimpleDPSConfigMenuSectionActiveColorName:SetAnchor(RIGHT, SimpleDPSConfigMenuSectionActiveColorColorSection, LEFT, -24, 0)
		SimpleDPSConfigMenuSectionActiveColorColorSection:SetWidth(40)
		SimpleDPSConfigMenuSectionActiveColorColorSection:ClearAnchors()
		SimpleDPSConfigMenuSectionActiveColorColorSection:SetAnchor(RIGHT, SimpleDPSConfigMenuSectionActiveColor, RIGHT, 0, 0)
		ZO_SharedOptions:InitializeControl(SimpleDPSConfigMenuSectionActiveColor)
		SimpleDPSConfigMenuSectionActiveColorColor:SetColor(ZO_ColorDef.FromARGBHexadecimal(SimpleDPS.config.activeTextColor):UnpackRGBA())
		SimpleDPSConfigMenuSectionActiveColorColorSection:SetHandler("OnMouseUp", function(self, upInside)
			local colorPicker = SYSTEMS:GetObject("colorPicker")
			ZO_Options_ColorOnMouseUp(self:GetParent(), upInside)
			colorPicker.colorSelectedCallback = function(...) SimpleDPS.ConfigUI:changeActiveColor(true, nil, ...) end
			colorPicker.colorSelect:SetHandler("OnColorSelected", function (...) SimpleDPS.ConfigUI:changeActiveColor(false, ...) end, SimpleDPS.name .. "ActiveColorSelect")
		end)
		
		-- Inactive Color
		SimpleDPSConfigMenuSectionInactiveColorName:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
		SimpleDPSConfigMenuSectionInactiveColorName:SetWidth(200)
		SimpleDPSConfigMenuSectionInactiveColorName:ClearAnchors()
		SimpleDPSConfigMenuSectionInactiveColorName:SetAnchor(RIGHT, SimpleDPSConfigMenuSectionInactiveColorColorSection, LEFT, -24, 0)
		SimpleDPSConfigMenuSectionInactiveColorColorSection:SetWidth(40)
		SimpleDPSConfigMenuSectionInactiveColorColorSection:ClearAnchors()
		SimpleDPSConfigMenuSectionInactiveColorColorSection:SetAnchor(RIGHT, SimpleDPSConfigMenuSectionInactiveColor, RIGHT, 0, 0)
		ZO_SharedOptions:InitializeControl(SimpleDPSConfigMenuSectionInactiveColor)
		SimpleDPSConfigMenuSectionInactiveColorColor:SetColor(ZO_ColorDef.FromARGBHexadecimal(SimpleDPS.config.inactiveTextColor):UnpackRGBA())
		SimpleDPSConfigMenuSectionInactiveColorColorSection:SetHandler("OnMouseUp", function(self, upInside)
			local colorPicker = SYSTEMS:GetObject("colorPicker")
			ZO_Options_ColorOnMouseUp(self:GetParent(), upInside)
			colorPicker.colorSelectedCallback = function(...) SimpleDPS.ConfigUI:changeInactiveColor(true, nil, ...) end
			colorPicker.colorSelect:SetHandler("OnColorSelected", function (...) SimpleDPS.ConfigUI:changeInactiveColor(false, ...) end, SimpleDPS.name .. "InactiveColorSelect")
		end)
		
		self.initialized = true
	end,

	setSetting = function (self, settingId, setting)
		SimpleDPS.config[settingId] = setting
	end,
	
	toggleAutoHide = function (self, control)
		local enabled = control:GetState() == 1 and true or false
		self:setSetting("autoHideEnabled", enabled)
		
		if enabled then
			if not SimpleDPS.inCombat then
				SimpleDPS:hideMeter()
			end
		else
			SimpleDPS:showMeter()
		end
	end,
	
	togglePreviousFight = function (self, control)
		local enabled = control:GetState() == 1 and true or false
		self:setSetting("showPreviousFight", enabled)
		
		if enabled then
			SimpleDPS:showPreviousFight()
		else		
			SimpleDPS:hidePreviousFight()
		end
	end,
	
	changeDamageFormat = function (self)
		self:setSetting("damageFormat", ZO_ComboBox_ObjectFromContainer(SimpleDPSConfigMenuSectionStatsShownDropdown):GetSelectedItem())
		
		SimpleDPS:setWidth()
		SimpleDPS:setFormatFunction()
		
		if SimpleDPS.inCombat then SimpleDPS:recalculate() end
		SimpleDPS:displayPreviousDps()	
	end,
	
	changeCurrentFightBehavior = function (self)
		local combobox = ZO_ComboBox_ObjectFromContainer(SimpleDPSConfigMenuSectionCurrentFightBehaviorDropdown)
		local value = combobox:GetSelectedItem()
		local selectedIndex = 0
		
		for index, item in ipairs(combobox:GetItems()) do
			if value == item.name then
				selectedIndex = index
				break
			end
		end
		
		if selectedIndex > 0 then 
			self:setSetting("resetBehavior", selectedIndex) 
			
			if not SimpleDPS.inCombat and SimpleDPSIndicatorDpsLabelValue:GetText() ~= "--" then
				if selectedIndex ~= SimpleDPS.RESET_LAZY then
					SimpleDPS:resetDpsMeter()
				end
			end
		end
	end,
	
	changeBackgroundColor = function (self, final, control, r, g, b)
		local argbhex = ZO_ColorDef.ToARGBHexadecimal(r, g, b, 1)
		self:setBackgroundColor(argbhex)	
		
		if final then 
			self:setSetting("backgroundColor", argbhex)
			SimpleDPSConfigMenuSectionBackgroundColorColor:SetColor(r, g, b)
			SYSTEMS:GetObject("colorPicker").colorSelect:SetHandler("OnColorSelected", nil, SimpleDPS.name .. "BackgroundColorSelect")
		end
	end,
	
	changeStaticColor = function (self, final, control, r, g, b)
		local argbhex = ZO_ColorDef.ToARGBHexadecimal(r, g, b, 1)
		self:setStaticTextColor(argbhex)		
		
		if final then 
			self:setSetting("staticTextColor", argbhex)
			SimpleDPSConfigMenuSectionStaticColorColor:SetColor(r, g, b)
			SYSTEMS:GetObject("colorPicker").colorSelect:SetHandler("OnColorSelected", nil, SimpleDPS.name .. "StaticColorSelect")
		end
	end,
	
	changeActiveColor = function (self, final, control, r, g, b)
		local argbhex = ZO_ColorDef.ToARGBHexadecimal(r, g, b, 1)
		
		if final then			
			self:setSetting("activeTextColor", argbhex)
			self:setInactiveTextColor(SimpleDPS.config.inactiveTextColor)
			self:setActiveTextColor(argbhex)
			SimpleDPSConfigMenuSectionActiveColorColor:SetColor(r, g, b)
			SYSTEMS:GetObject("colorPicker").colorSelect:SetHandler("OnColorSelected", nil, SimpleDPS.name .. "ActiveColorSelect")
		else
			self:setInactiveTextColor(argbhex)
		end
	end,
	
	changeInactiveColor = function (self, final, control, r, g, b)
		local argbhex = ZO_ColorDef.ToARGBHexadecimal(r, g, b, 1)
		self:setInactiveTextColor(argbhex)

		if final then			
			self:setSetting("inactiveTextColor", argbhex)
			SimpleDPSConfigMenuSectionInactiveColorColor:SetColor(r, g, b)
			SYSTEMS:GetObject("colorPicker").colorSelect:SetHandler("OnColorSelected", nil, SimpleDPS.name .. "InactiveColorSelect")
		end
	end,
	
	setBackgroundColor = function (self, hex)
		local r, g, b = ZO_ColorDef.FromARGBHexadecimal(hex):UnpackRGB()
		SimpleDPSIndicatorBg:SetCenterColor(r, g, b, SimpleDPS.config.windowAlpha)
	end,
	
	setStaticTextColor = function (self, hex)
		local r, g, b = ZO_ColorDef.FromARGBHexadecimal(hex):UnpackRGB()
		
		SimpleDPSIndicatorDpsLabel:SetColor(r, g, b)
		SimpleDPSIndicatorLastDpsLabel:SetColor(r, g, b)
		SimpleDPSIndicatorLastDpsLabelValue:SetColor(r, g, b)
	end,
	
	setActiveTextColor = function (self, hex)
		local r, g, b = ZO_ColorDef.FromARGBHexadecimal(hex):UnpackRGB()
		
		if SimpleDPS.inCombat or SimpleDPSIndicatorDpsLabelValue:GetText() == "--"then
			SimpleDPSIndicatorDpsLabelValue:SetColor(r, g, b)
		end
	end,
	
	setInactiveTextColor = function (self, hex)
		local r, g, b = ZO_ColorDef.FromARGBHexadecimal(hex):UnpackRGB()
		
		if not SimpleDPS.inCombat and SimpleDPSIndicatorDpsLabelValue:GetText() ~= "--" then
			SimpleDPSIndicatorDpsLabelValue:SetColor(r, g, b)
		end
	end,
	
	resetBackgroundColor = function (self)
		local defaultColor = "FF000000"
		SimpleDPSConfigMenuSectionBackgroundColorColor:SetColor(ZO_ColorDef.FromARGBHexadecimal(defaultColor):UnpackRGB())
		self:setBackgroundColor(defaultColor)
		self:setSetting("backgroundColor", defaultColor)
	end,
	
	resetStaticTextColor = function (self)
		local defaultColor = "FFFF0000"
		SimpleDPSConfigMenuSectionStaticColorColor:SetColor(ZO_ColorDef.FromARGBHexadecimal(defaultColor):UnpackRGB())
		self:setStaticTextColor(defaultColor)
		self:setSetting("staticTextColor", defaultColor)
	end,
	
	resetActiveTextColor = function (self)
		local defaultColor = "FFF5F5F5"
		SimpleDPSConfigMenuSectionActiveColorColor:SetColor(ZO_ColorDef.FromARGBHexadecimal(defaultColor):UnpackRGB())
		self:setActiveTextColor(defaultColor)
		self:setSetting("activeTextColor", defaultColor)
	end,
	
	resetInactiveTextColor = function (self)
		local defaultColor = "FF00FF00"
		SimpleDPSConfigMenuSectionInactiveColorColor:SetColor(ZO_ColorDef.FromARGBHexadecimal(defaultColor):UnpackRGB())
		self:setInactiveTextColor(defaultColor)
		self:setSetting("inactiveTextColor", defaultColor)
	end,
	
	changeTransparencyValue = function (self, value)
		SimpleDPSConfigMenuSectionTransparencyValue:SetText(self:formatDecimal(value * 100, "%"))
		self:setSetting("windowAlpha", 1 - value)
		SimpleDPS:SetAlpha()
	end,
	
	changeWindowScale = function (self, value)
		SimpleDPSConfigMenuSectionWindowScaleValue:SetText(self:formatDecimal(value * 100, "%"))
		self:setSetting("windowScale", value)
		self:setWindowScale(value)
	end,
	
	setWindowScale = function (self, scale)
		local label = scale * 71
		local button = scale * 30			
		local buttonAnchor = scale * 10
		
		SimpleDPS:setWidth(scale)		
		SimpleDPSIndicatorConfigButton:SetWidth(button)
		SimpleDPSIndicatorLastDpsLabel:SetWidth(label)
		SimpleDPSIndicatorDpsLabel:SetWidth(label)
		
		window = SimpleDPS.config.showPreviousFight and 60 or 35
		local height = scale * (25)
		
		SimpleDPSIndicator:SetHeight(scale * window)
		SimpleDPSIndicatorConfigButton:SetHeight(button)
		SimpleDPSIndicatorLastDps:SetHeight(height)
		SimpleDPSIndicatorLastDpsLabel:SetHeight(height)
		SimpleDPSIndicatorLastDpsLabelValue:SetHeight(height)
		SimpleDPSIndicatorDps:SetHeight(height)
		SimpleDPSIndicatorDpsLabel:SetHeight(height)
		SimpleDPSIndicatorDpsLabelValue:SetHeight(height)
		
		SimpleDPSIndicatorConfigButton:ClearAnchors()
		SimpleDPSIndicatorConfigButton:SetAnchor(CENTER, SimpleDPSIndicator, TOPLEFT, buttonAnchor, buttonAnchor)
		
		local fontSize = self:calculateFontSize()
		local font = string.format("$(MEDIUM_FONT)|$(%s)|soft-shadow-thin", fontSize)
		local boldFont = string.format("$(BOLD_FONT)|$(%s)|soft-shadow-thin", fontSize)
		
		SimpleDPSIndicatorLastDpsLabel:SetFont(font)
		SimpleDPSIndicatorLastDpsLabelValue:SetFont(font)
		SimpleDPSIndicatorDpsLabel:SetFont(font)
		SimpleDPSIndicatorDpsLabelValue:SetFont(boldFont)
	end,
	
	calculateFontSize = function (self)
		local FONT_SIZE_STR = { "KB_8", "KB_9", "KB_10", "KB_11", "KB_12", "KB_13", "KB_14", "KB_15", "KB_16", "KB_17", "KB_18", "KB_19", "KB_20", "KB_21", "KB_22", "KB_23", "KB_24", "KB_25", "KB_26", "KB_28", "KB_30", "KB_32", "KB_34", "KB_36", "KB_40", "KB_48", "KB_54" }
		local FONT_SIZE_INT = { 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 28, 30, 32, 34, 36, 40, 48, 54 }
		local calc = 9 * 0.435
		
		local width = SimpleDPSIndicatorLastDpsLabel:GetWidth()
		local lastChosen = "KB_8"

		local i = 0
		
		for i = 1, #FONT_SIZE_INT do
			local key = FONT_SIZE_INT[i]
			local value = FONT_SIZE_STR[i]
			local size = key * calc
			
			if size > width then
				return lastChosen
			else
				lastChosen = value
			end
		end
		
		return lastChosen
	end,
	
	formatDecimal = function (self, value, suffix)
		if value % 1 ~= 0 then
			return string.format("%.2f%s", value, suffix or "")
		end
		
		return string.format("%d%s", value, suffix or "")
	end,
}