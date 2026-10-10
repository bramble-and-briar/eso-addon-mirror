local MOUSEMENU_HEADER_TEXT_COLOR = "#ecdc6e"
local MOUSEMENU_BUTTON_TEXT_COLOR = "#ffffff"
local MOUSEMENU_BUTTON_TEXT_HIGHLIGHT_COLOR = "#f3aa6f"
local MOUSEMENU_BUTTON_HIGHLIGHT_COLOR = "#1d5783"

local MOUSEMENU_HEADER_FONT_SIZE = 18
local MOUSEMENU_NORMAL_FONT_SIZE = 15

local MOUSEMENU_MIN_WIDTH = 200
local MOUSEMENU_MIN_HEIGHT = 100

local mouseButtons = {}
local mouseLines = {}
local nextButtonTop = 0
local width = MOUSEMENU_MIN_WIDTH

local function SetMouseMenuDimensions(_width, height)
	AUI_MouseMenu:SetDimensions(_width, height)	
	AUI_MouseMenu_BG:SetDimensions(_width, height) 
	AUI_MouseMenu_Header:SetDimensions(_width, MOUSEMENU_HEADER_FONT_SIZE)
	AUI_MouseMenu_Header:SetDimensions(_width, MOUSEMENU_HEADER_FONT_SIZE)
	AUI_MouseMenu_HeaderLine:SetDimensions(_width, 2)
	
	width = _width
end

function AUI.AddMouseMenuButton(_name, _text, _func)
	local buttonHeight = 28
		
	local button = mouseButtons[_name]
		
	if not button then	
		button = WINDOW_MANAGER:CreateControl(_name, AUI_MouseMenu, CT_CONTROL)			
		button:SetMouseEnabled(true)	
		
		button:SetHandler("OnMouseEnter", function(self)
			self.ButtonHighlight:SetHidden(false)
			self.Label:SetColor(AUI.Color.ConvertHexToRGBA(MOUSEMENU_BUTTON_TEXT_HIGHLIGHT_COLOR, 1.0):UnpackRGBA())
			self.Label:SetAlpha(1)
		end)	
		
		button:SetHandler("OnMouseExit", function(self)
			self.ButtonHighlight:SetHidden(true)
			self.Label:SetColor(AUI.Color.ConvertHexToRGBA(MOUSEMENU_BUTTON_TEXT_COLOR, 1.0):UnpackRGBA())
			self.Label:SetAlpha(0.8)
		end)			
		
		button.ButtonHighlight = WINDOW_MANAGER:CreateControl(nil, button, CT_TEXTURE)
		button.ButtonHighlight:SetAnchor(TOPLEFT, button, TOPLEFT, 0, 0)
		button.ButtonHighlight:SetColor(AUI.Color.ConvertHexToRGBA(MOUSEMENU_BUTTON_HIGHLIGHT_COLOR, 0.8):UnpackRGBA())
		button.ButtonHighlight:SetHidden(true)
		button.ButtonHighlight:SetMouseEnabled(false)	
		button.ButtonHighlight:SetAlpha(0.7)
		
		button.Label = WINDOW_MANAGER:CreateControl(nil, button, CT_LABEL)
		button.Label:SetColor(AUI.Color.ConvertHexToRGBA(MOUSEMENU_BUTTON_TEXT_COLOR, 1.0):UnpackRGBA())	

		button.Label:SetFont("$(MEDIUM_FONT)|" .. MOUSEMENU_NORMAL_FONT_SIZE .. "|" .. "outline")
		button.Label:SetMouseEnabled(false)
		button.Label:SetHorizontalAlignment(TEXT_ALIGN_CENTER) 	
		button.Label:SetVerticalAlignment(TEXT_ALIGN_CENTER) 
		button.Label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS) 	
		button.Label:SetAlpha(0.8)
	end
	
	button:SetDimensions(width, buttonHeight)
	button:SetAnchor(TOPLEFT, AUI_MouseMenu, TOPLEFT, 0, nextButtonTop)	
	button:SetHidden(false)
	button:SetHandler("OnMouseUp", function() 
												AUI.HideMouseMenu()
												_func(button) 
											 end
							    )
									
	nextButtonTop = (nextButtonTop + buttonHeight) + 4
	
	button.ButtonHighlight:SetDimensions(width, buttonHeight)	
	
	button.Label:SetDimensions(width, 30)
	button.Label:SetAnchor(CENTER, button, CENTER, 0, 0)	
	button.Label:SetText(_text)
	
	AUI_MouseMenu:SetDimensions(width, nextButtonTop)	
	AUI_MouseMenu_BG:SetDimensions(width, nextButtonTop)
	
	mouseButtons[_name] = button
end

function AUI.AddMouseMenuLine(_name)
	local line =  mouseLines[_name]
	
	if not line then
		line = WINDOW_MANAGER:CreateControl(_name, AUI_MouseMenu, CT_TEXTURE)
		line:SetTexture("esoui/art/tradinghouse/tradinghouse_divider_short.dds")			
	end
	
	line:SetAnchor(TOPCENTER, AUI_MouseMenu, TOPCENTER, 0, nextButtonTop)
	line:SetDimensions(MOUSEMENU_MIN_WIDTH, 2)	
	line:SetHidden(false)
	
	nextButtonTop = (nextButtonTop + 2) + 4
	mouseLines[_name] = line
end

function AUI.ShowMouseMenu(_displayName, _closeFunc, _width)
	if _displayName then
		nextButtonTop = 36
	else
		nextButtonTop = 0
	end
	
	for _, _button in pairs(mouseButtons) do
		_button:SetHidden(true)
	end
	
	for _, _line in pairs(mouseLines) do
		_line:SetHidden(true)
	end	
	
	AUI_MouseMenu:SetHandler("OnMouseEnter", function(_eventCode, _button, _ctrl, _alt, shift) AUI_MouseMenu_Container:SetMouseEnabled(false) end)
	AUI_MouseMenu:SetHandler("OnMouseExit", function(_eventCode, _button, _ctrl, _alt, shift) AUI_MouseMenu_Container:SetMouseEnabled(true) end)

	AUI_MouseMenu_Container:ClearAnchors()	
	AUI_MouseMenu_Container:SetAnchorFill(GuiRoot)  
	AUI_MouseMenu_Container:SetHidden(false)	
	AUI_MouseMenu_Container:SetHandler("OnMouseDown", function(_eventCode, _button, _ctrl, _alt, shift) AUI.HideMouseMenu() end)
			
	local mouseMenuWidth = 	MOUSEMENU_MIN_WIDTH	
			
	if _width then
		mouseMenuWidth = _width
	end	
			
	SetMouseMenuDimensions(mouseMenuWidth, MOUSEMENU_MIN_HEIGHT)
	
	nextButtonTop = nextButtonTop + 4
	
	local x, y = GetUIMousePosition()
	AUI_MouseMenu:SetAnchor(TOPLEFT, GUIROOT, TOPLEFT, x, y)
	
	AUI_MouseMenu:SetHidden(false)

	if _displayName then
		AUI_MouseMenu_Header:SetColor(AUI.Color.ConvertHexToRGBA(MOUSEMENU_HEADER_TEXT_COLOR, 1.0):UnpackRGBA())	
		AUI_MouseMenu_Header:SetFont("$(MEDIUM_FONT)|" .. MOUSEMENU_HEADER_FONT_SIZE .. "|" .. "outline")	
		AUI_MouseMenu_Header:SetAnchor(TOPCENTER, AUI_MouseMenu, TOPCENTER, 0, 4)		
		AUI_MouseMenu_Header:SetHorizontalAlignment(TEXT_ALIGN_CENTER ) 	
		AUI_MouseMenu_Header:SetVerticalAlignment(TEXT_ALIGN_CENTER ) 		
	
		AUI_MouseMenu_HeaderLine:SetTexture("esoui/art/tradinghouse/tradinghouse_divider_short.dds")		
		AUI_MouseMenu_HeaderLine:SetAnchor(TOPCENTER, AUI_MouseMenu, TOPCENTER, 0, nextButtonTop)	
		AUI_MouseMenu_HeaderLine:SetHidden(false)	
	
		nextButtonTop = nextButtonTop + 6
	
		AUI_MouseMenu_Header:SetText(_displayName)
		AUI_MouseMenu_Header:SetHidden(false)
		AUI_MouseMenu_HeaderLine:SetHidden(false)
	else
		AUI_MouseMenu_Header:SetHidden(true)
		AUI_MouseMenu_HeaderLine:SetHidden(true)
	end
end

function AUI.HideMouseMenu()
	AUI_MouseMenu:SetHidden(true)
	AUI_MouseMenu_Container:SetHidden(true)
end