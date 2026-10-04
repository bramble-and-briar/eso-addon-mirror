--- ChatInput viewer
--- Version 1.3.1

--- Changelog
--- V. 1.3.1 - Update for ESO Version 12.1.5, API version 101051.
--- V. 1.3.0 - Update for ESO Version 12.0.5, API version 101050.
---          - New view mode 'minimized'
---          - Key binding for tuggling the view state
---          - new chat commands '/civshow', '/civhide', '/civmini'
---          - Message with update information after login.
--- V. 1.2.3 - Update for ESO Version 11.3.4, API version 101049.
--- V. 1.2.2 - Bugfix for an issue during AddOn initialization
--- V. 1.2.1 - Update for ESO Version 11.2.6, API version 101048.
---          - Exception prevented, when slash commands were used more than one time.
---          - Slash commands /civshow and /civhide added.
--- V. 1.2.0 - Update for ESO Version 11.1.5, API version 101047.
---          - Repeating the channel color of the input textbox in the viewer.
--- V. 1.1.0 - Russian translation added.
---          - Bugfix for character counting of multibyte characters.
---          - Spelling errors removed
--- V. 1.0.0 - Initial version.

--- ---------------------------------------------------------------------

--	d( "----------" )


--- The Addon namespace.
--- @class ChatInputViewer
--- @field OnAddOnLoaded function
--- @field name string
ChatInputViewer = {}
ChatInputViewer.name = "ChatInputViewer"

--- @field CivLogger object # Instance of the LibDebugLogger logger for this AddOn.
local CivLogger

--- # ChatInputViewerVars
--- @class savedVariables
local savedVariables

--- Existing OnTextChanged handler of other AddOns registered to the
--- ZO_ChatWindowTextEntryEditBox control.
local ExistingOnTextChangedHandler

--- Status of the input string
---   1     0 - 279 characters
---   2   280 - 314 characters
---   3   315 - 349 characters
---   4   350 characters
local LastInputLengthState
--- Array for the color definitions of the colors showing the inpt string state.
---   1   {1.0, 1.0, 1.0, 1.0}
---   2   {1.0, 1.0, 0.0, 1.0}
---   3   {1.0, 0.5, 0.0, 1.0}
---   4   {1.0, 0.0, 0.0, 1.0}
local InputLengthStateColors
--- Last channel used in the chat.
local LastChannel

--- Table containing the provided window modes.
---   1   "Adjusted to chat window"
---   2   "Fixed width"
local ModeChoices


--- Hilfsfunktion für die verzögerte Nachricht
local function ShowWelcomeMessage()

	--d("== Chat Input Viewer - neue Funktionen in Version 1.3.0 ==")
	d(GetString(CHATIV_UPDATEMESSAGE_01))
	--d(" * Neuer Anzeigemodus 'Minimiert'")
	d(GetString(CHATIV_UPDATEMESSAGE_02))
	--d(" * Chat Kommandos /civshow, /civhide und /civmini")
	d(GetString(CHATIV_UPDATEMESSAGE_03))
	--d(" * Konfigurierbares Tastaturkommando zum Wechseln des Modus.")
	d(GetString(CHATIV_UPDATEMESSAGE_04))
	--d("Details findet ihr in der AddOn-Beschreibung auf USOUI: https://www.esoui.com/downloads/info4158-ChatInputViewer.html")
	d(GetString(CHATIV_UPDATEMESSAGE_05))
	if (savedVariables.updatemessages.messagecounter < 5) then
		--df("(Message will be shown %s more times after login.)", 5 - savedVariables.updatemessages.messagecounter)
		df(GetString(CHATIV_UPDATEMESSAGE_06), 5 - savedVariables.updatemessages.messagecounter)
	end

end


--- Updates the viewer display with the current text of the chat input textfield.
local function ShowChatInput()

	local chatInput, viewerOutput
	local chatInputSize, foundPos
	local currentInputLengthState
	local statCol

	chatInput = ZO_ChatWindowTextEntryEditBox:GetText()
	chatInputSize = utf8.len(chatInput)
	viewerOutput = ""

	if (chatInputSize >= 350) then
		currentInputLengthState = 4
	elseif (chatInputSize >= 315) then
		currentInputLengthState = 3
	elseif (chatInputSize >= 280) then
		currentInputLengthState = 2
	else
		currentInputLengthState = 1
	end

	if (savedVariables.minimised == false) then
		ChatInputViewerControl_Label:SetText(chatInput)
	else
		ChatInputViewerControl_Label:SetText(chatInputSize .. " / 350")
	end

	if (currentInputLengthState > 1) then
		if (currentInputLengthState ~= LastInputLengthState) then
			statCol = InputLengthStateColors[currentInputLengthState]
			ChatInputViewerControl_Label:SetColor(statCol[1], statCol[2], statCol[3], statCol[4])
			LastChannel = nil
		end
	elseif (LastChannel ~= CHAT_SYSTEM.currentChannel) then 
		ChatInputViewerControl_Label:SetColor(ZO_ChatSystem_GetCategoryColorFromChannel(CHAT_SYSTEM.currentChannel))
		LastChannel = CHAT_SYSTEM.currentChannel
	end
	LastInputLengthState = currentInputLengthState

end


--- Calculates the height of the viewer window according to the given parameters.
---   @param nrOfLines number # The number of shown lines.
---   @param fontsize  number # The fontsize of the viewer window.
---   @return boolean height  # The calculated window height.
local function CalculateViewerHeight(nrOfLines, fontsize)

	local height, addFontsize

	--CivLogger:Debug( "CalculateViewerHeight()")
	--CivLogger:Debug( ".   Params: " .. nrOfLines .. ", " .. fontsize)

	if (nrOfLines == 0) then
		--CivLogger:Debug( ".   New Viewer Height: 0")
		return 0
	end

	if (fontsize == 16) then
		addFontsize = 5
	elseif (fontsize == 24) then
		addFontsize = 7
	else
		addFontsize = 6
	end

	height = nrOfLines * (fontsize + addFontsize) + 12

	--CivLogger:Debug( ".   New Viewer Height: " .. height)

	return height

end

local function CetCurrentViewerHeight()

	local currentHeight

	--CivLogger:Debug( "CetCurrentViewerHeight()")

	currentHeight = 0
	if (savedVariables.visible == true) then
		if _G["ChatInputViewerControl"] ~= nil then
			currentHeight = _G["ChatInputViewerControl"]:GetHeight()
		end
	end

	--CivLogger:Debug( ".   Current Viewer Height: " .. currentHeight)

	return currentHeight

end

--- Moves the chat window vertically. The function limits the movement so that the
--- chat window always remains within the game window.
---   @param deltaY  number # A positive value moves the window down, a negative up.
local function MoveChatWindowY(deltaY)

	local chatXPos, chatYPos, rootYPos, chatheight1, chatheight2
	--local chatYPos2

	--CivLogger:Debug( "MoveChatWindowY()")

	chatYPos = ZO_ChatWindow:GetBottom()

	if (deltaY > 0) then
		rootYPos = GuiRoot:GetBottom()
		if (chatYPos + deltaY > rootYPos) then
			deltaY = rootYPos - chatYPos
		end
	end

	--chatYPos2 = ZO_ChatWindow:GetBottom()
	chatXPos = ZO_ChatWindow:GetLeft()
	chatYPos = ZO_ChatWindow:GetTop()
	chatheight1 = ZO_ChatWindow:GetHeight()

	ZO_ChatWindow:SetSimpleAnchorParent(chatXPos, chatYPos + deltaY)
	chatheight2 = ZO_ChatWindow:GetHeight()

	if (chatheight2 ~= chatheight1) then
		ZO_ChatWindow:SetSimpleAnchorParent(chatXPos, chatYPos + deltaY + 0.01)
		ZO_ChatWindow:SetHeight(chatheight1)
	end

end


local function SetChatHandlers(addOnEnabled)

	if (addOnEnabled) then

		--CivLogger:Debug( "In SetChatHandlers: register to event")

		-- Store an already existing event handler of another AddOn in ExistingOnTextChangedHandler
		ExistingOnTextChangedHandler = ZO_ChatWindowTextEntryEditBox:GetHandler("OnTextChanged")
		-- Register ChatInputViewer to the event
		ZO_ChatWindowTextEntryEditBox:SetHandler("OnTextChanged", function(self)
			ShowChatInput()
			if (ExistingOnTextChangedHandler ~= nil) then
				ExistingOnTextChangedHandler(self)
			end
		end)
	else

		--CivLogger:Debug( "In SetChatHandlers: unregister from event")

		-- If the Viewer is not visible, unregister the AddOn
		if (ExistingOnTextChangedHandler ~= nil) then
			-- Register the original event handler, that was stored in ExistingOnTextChangedHandler
			ZO_ChatWindowTextEntryEditBox:SetHandler("OnTextChanged", ExistingOnTextChangedHandler)
			ExistingOnTextChangedHandler = nil
		end
	end

end

--- Shows the viewer window.
local function ShowViewer()
	local currentHeight, newHeight, deltaY

	--CivLogger:Debug( "ShowViewer()")

	-- Calculate the movement for the chat window
	currentHeight = CetCurrentViewerHeight()
	newHeight = CalculateViewerHeight(savedVariables.nroflines, savedVariables.fontsize)
	deltaY = currentHeight - newHeight

	if (deltaY ~= 0) then
		MoveChatWindowY(deltaY)
	end

	ChatInputViewerControl:SetHeight(newHeight)
	ChatInputViewerControl_Label:SetHeight(newHeight - 10)
	if (savedVariables.visible == false) then
		ChatInputViewerControl_Label:SetHidden(false)
		ChatInputViewerControl_BG:SetHidden(false)
		SetChatHandlers(true)
	end
	savedVariables.visible = true
	savedVariables.minimised = false
	ShowChatInput()
end

--- Hides the viewer window.
local function HideViewer()
	local currentHeight, deltaY

	--CivLogger:Debug( "HideViewer()")

	-- Calculate the movement for the chat window
	currentHeight = CetCurrentViewerHeight()
	deltaY = currentHeight

	if (deltaY ~= 0) then
		MoveChatWindowY(deltaY)
	end

	if (savedVariables.visible == true) then
		ChatInputViewerControl_Label:SetHidden(true)
		ChatInputViewerControl_BG:SetHidden(true)
		SetChatHandlers(false)
	end
	savedVariables.visible = false
	savedVariables.minimised = false
end

--- Shows the viewer window in a minimised state that only shows a single line
--- with the number of characters in the input field.
local function MinimiseViewer()
	local currentHeight, newHeight, deltaY

	--CivLogger:Debug( "MinimiseViewer()")

	-- Calculate the movement for the chat window
	currentHeight = CetCurrentViewerHeight()
	newHeight = CalculateViewerHeight(1, savedVariables.fontsize)
	deltaY = currentHeight - newHeight

	--CivLogger:Debug( "----- Alt: " .. currentHeight .. ", Neu: " .. newHeight .. ", Delta: " .. deltaY)

	if (deltaY ~= 0) then
		MoveChatWindowY(deltaY)
	end

	-- Resize the viewer window
	-- Set the new viewer state (visible, minimised)
	ChatInputViewerControl:SetHeight(newHeight)
	ChatInputViewerControl_Label:SetHeight(newHeight - 10)
	if (savedVariables.visible == false) then
		ChatInputViewerControl_Label:SetHidden(false)
		ChatInputViewerControl_BG:SetHidden(false)
		SetChatHandlers(true)
	end
	savedVariables.visible = true
	savedVariables.minimised = true
	ShowChatInput()

end

--- Calculates the number of lines for rezising the viewer depending on the given
--- values for visibility and minimise state.
---   @param visible   boolean # Flag if the viewer window is visibile.
---   @param minimised boolean # Flag if the viewer window is minimised.
local function CalculateNrOfLines( visible, minimised, newNrOfLines)

	local nrOfShownLines

	if (savedVariables.visible == false) then
		nrOfShownLines = 0
	elseif (savedVariables.visible == true and savedVariables.minimised == true) then
		nrOfShownLines = 1
	else
		if (newNrOfLines ~= nil) then
			nrOfShownLines = newNrOfLines
		else
			nrOfShownLines = savedVariables.nroflines
		end
	end

	return nrOfShownLines
	
end

--- Sets the width and the height of the viewer window.
---   @param width     number # The width of the viewer window. When the window is adjusted to the
---                             chat window, 0 has to be provided.
---   @param nrOfLines number # The number of text rows that are shown in the viewer.
---   @param fontsize  number # The font size of the viewer text.
local function ResizeViewerControl(width, nrOfLines, fontsize)

	local height
	local nrOfShownLines

	-- If a fixed width is given, set the width
	if (width > 0) then
		ChatInputViewerControl:SetWidth(width)
	end

	nrOfShownLines = CalculateNrOfLines( savedVariables.visible, savedVariables.minimised, nrOfLines)
	height = CalculateViewerHeight(nrOfShownLines, fontsize)
	ChatInputViewerControl:SetHeight(height)
	ChatInputViewerControl_Label:SetHeight(height - 10)

end


--- Retrieves the visibility status of the viewer window.
--- This function is used for the communication with the settings menu.
---   @return boolean visible # The visibility status.
local function getVisibility()
	return savedVariables.visible
end

--- Retrieves the visibility status of the viewer window.
--- This function is used for the communication with the settings menu.
---   @return boolean visible # The visibility status.
local function getMinimised()
	return savedVariables.minimised
end

--- Sets the visibility status of the viewer window and changes the visibility.
--- This function is used for the communication with the settings menu.
---   @param visible   boolean # Flag if the viewer window is visibile.
---   @param minimised boolean # Flag if the viewer window is minimised.
local function setVisibility( visible, minimised)
	if (visible == true) then
		if (minimised == true) then
			MinimiseViewer()
		else
			ShowViewer()
		end
	else
		HideViewer()
	end
end

--- Retrieves the font size for the viewer window.
--- This function is used for the communication with the settings menu.
---   @return number fontsize # The font size of the viewer text.
local function getFontSize()
	return savedVariables.fontsize
end

--- Sets the font size of the text in the viewer window.
--- This function is used for the communication with the settings menu.
---   @param val number # The font size of the viewer text.
local function setFontSize(val)

	local nrOfShownLines

	nrOfShownLines = CalculateNrOfLines( savedVariables.visible, savedVariables.minimised)
	ChatInputViewerControl_Label:SetFont("$(CHAT_FONT)|$(KB_" .. val .. ")|soft-shadow-thick")
	ChatInputViewerControl:ClearAnchors()
	if (savedVariables.mode == 1) then
		ChatInputViewerControl:SetAnchor(TOPLEFT, ZO_ChatWindow, BOTTOMLEFT, 0, 0)
		ChatInputViewerControl:SetAnchor(TOPRIGHT, ZO_ChatWindow, BOTTOMRIGHT, 0, 0)
		ResizeViewerControl(0, nrOfShownLines, val)
	else
		ChatInputViewerControl:SetAnchor(TOPLEFT, ZO_ChatWindow, BOTTOMLEFT, 0, 0)
		ResizeViewerControl(savedVariables.windowwidth, nrOfShownLines, val)
	end
	savedVariables.fontsize = val
end

--- Retrieves the mode of the viewer window.
--- This function is used for the communication with the settings menu.
---   @return number mode # The ID of the window mode (1 = adjusted, 2 = fixed).
local function getWindowMode()
	return ModeChoices[savedVariables.mode]
end

--- Sets the mode of the viewer window.
--- This function is used for the communication with the settings menu.
---   @param val number # The ID of the window mode (1 = adjusted, 2 = fixed).
local function setWindowMode(val)

	local text

	for k, v in pairs(ModeChoices) do
		if (v == val) then
			savedVariables.mode = k
		end
	end

	ChatInputViewerControl:ClearAnchors()
	if (savedVariables.mode == 1) then
		ChatInputViewerControl:SetAnchor(TOPLEFT, ZO_ChatWindow, BOTTOMLEFT, 0, 0)
		ChatInputViewerControl:SetAnchor(TOPRIGHT, ZO_ChatWindow, BOTTOMRIGHT, 0, 0)
		ResizeViewerControl(0, savedVariables.nroflines, savedVariables.fontsize)
	else
		ChatInputViewerControl:SetAnchor(TOPLEFT, ZO_ChatWindow, BOTTOMLEFT, 0, 0)
		ResizeViewerControl(savedVariables.windowwidth, savedVariables.nroflines, savedVariables.fontsize)
	end
end

--- Retrieves the width for the viewer window.
--- This function is used for the communication with the settings menu.
---   @return number width # The width for the viewer window.
local function getWindowWidth()
	return savedVariables.windowwidth
end

--- Sets the width of the viewer window.
--- This function is used for the communication with the settings menu.
---   @param val number # The width of the viewer window.
local function setWindowWidth(val)
	if (savedVariables.mode == 2) then
		ResizeViewerControl(val, savedVariables.nroflines, savedVariables.fontsize)
	end
	savedVariables.windowwidth = val
end

--- Retrieves the number of text lines for the viewer window.
--- This function is used for the communication with the settings menu.
---   @return number width # The  number of text lines for the viewer window.
local function getNrOfLines()
	return savedVariables.nroflines
end

--- Sets the number of text lines for the viewer window.
--- This function is used for the communication with the settings menu.
---   @param val number # The  number of text lines for the viewer window.
local function setNrOfLines(val)
	ResizeViewerControl(0, val, savedVariables.fontsize)
	savedVariables.nroflines = val
end


--- Function used for key binding. It is called by the game engine when the defined
--- key is pressed.
function ToggleViewer()

	if (savedVariables.visible == true) then
		if (savedVariables.minimised == true) then
			HideViewer()
		else
			MinimiseViewer()
		end
	else
		ShowViewer()
	end

end

--- Sets the Position of the Chat window depending on the size of the viewer window.
local function SetChatWindowAtStartUp()

	local nrOfLines, height

	--CivLogger:Debug( "SetChatWindowAtStartUp()")

	-- Calculate the height of the viewer window.
	nrOfLines = CalculateNrOfLines( savedVariables.visible, savedVariables.minimised)
	height = CalculateViewerHeight(nrOfLines, savedVariables.fontsize)

	-- Move the chat window if necessary
	if (height ~= 0) then
		MoveChatWindowY(height)
	end

end

--- Initializes the AddOn
local function initializeChatInputViewer()

	local panelName = "ChatInputViewerOptions"
	local nrOfShownLines
	local kbText

	LastChannel = nil
	LastInputLengthState = 0

	InputLengthStateColors = {
		[1] = {1.0, 1.0, 1.0, 1.0},
		[2] = {1.0, 1.0, 0.0, 1.0},
		[3] = {1.0, 0.5, 0.0, 1.0},
		[4] = {1.0, 0.0, 0.0, 1.0},
	}

	ModeChoices = {
		[1] = GetString(CHATIV_WINDOWMODE_VAL1),
		[2] = GetString(CHATIV_WINDOWMODE_VAL2),
	}

	ChatInputViewerControl_Label:SetFont("$(CHAT_FONT)|$(KB_" .. savedVariables.fontsize .. ")|soft-shadow-thick")
	ChatInputViewerControl_Label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	ChatInputViewerControl:ClearAnchors()
	nrOfShownLines = CalculateNrOfLines( savedVariables.visible, savedVariables.minimised)
	if (savedVariables.mode == 1) then
		ChatInputViewerControl:SetAnchor(TOPLEFT, ZO_ChatWindow, BOTTOMLEFT, 0, 0)
		ChatInputViewerControl:SetAnchor(TOPRIGHT, ZO_ChatWindow, BOTTOMRIGHT, 0, 0)
		--ResizeViewerControl(0, nrOfShownLines, savedVariables.fontsize)
	else
		ChatInputViewerControl:SetAnchor(TOPLEFT, ZO_ChatWindow, BOTTOMLEFT, 0, 0)
		--ResizeViewerControl(savedVariables.windowwidth, nrOfShownLines, savedVariables.fontsize)
	end
	ChatInputViewerControl_Label:SetHidden(not savedVariables.visible)
	ChatInputViewerControl_BG:SetHidden(not savedVariables.visible)

	--- The panel data for the ChatInputViewer addon, that are shown in the Addon settings GUI.
	---   @class panelData
	---   @field type string @The type of the panel.
	---   @field name string @The name of the panel.
	---   @field author string @The author of the addon.
	local panelData = {
		type = "panel",
		name = "Chatinput viewer",
		author = "@GetanoNero",
		registerForRefresh = true,
	}
	--- The data for the configuration options of the ChatInputViewer addon.
	local optionsData = {
		[1] = {
			type = "description",
			title = GetString(CHATIV_WARNING_CAPTION),
			text = GetString(CHATIV_WARNING_TEXT),
		},
		[2] = {
			type = "checkbox",
			name = GetString(CHATIV_VISIBLE),
			tooltip = GetString(CHATIV_VISIBLE_TOOLTIP),
			getFunc = function() return getVisibility() end,
			setFunc = function(value) setVisibility(value, savedVariables.minimised) end,
		},
		[3] = {
			type = "checkbox",
			name = GetString(CHATIV_MINIMISED),
			tooltip = GetString(CHATIV_MINIMISED_TOOLTIP),
			getFunc = function() return getMinimised() end,
			setFunc = function(value) setVisibility(savedVariables.visible, value) end,
			disabled = function() return (savedVariables.visible == false) end,
		},
		[4] = {
			type = "dropdown",
			name = GetString(CHATIV_FONTSIZE),
			tooltip = GetString(CHATIV_FONTSIZE_TOOLTIP),
			choices = {
				16,
				18,
				20,
				22,
				24,
			},
			getFunc = function() return getFontSize() end,
			setFunc = function(value) setFontSize(value) end,
		},
		[5] = {
			type = "dropdown",
			name = GetString(CHATIV_WINDOWMODE),
			tooltip = GetString(CHATIV_WINDOWMODE_TOOLTIP),
			choices = ModeChoices,
			getFunc = function() return getWindowMode() end,
			setFunc = function(value) setWindowMode(value) end,
		},
		[6] = {
			type = "dropdown",
			name = GetString(CHATIV_WINDOWWIDTH),
			tooltip = GetString(CHATIV_WINDOWWIDTH_TOOLTIP),
			choices = {
				600,
				800,
				1000,
				1200,
			},
			getFunc = function() return getWindowWidth() end,
			setFunc = function(value) setWindowWidth(value) end,
			disabled = function() return (savedVariables.mode == 1) end,
		},
		[7] = {
			type = "dropdown",
			name = GetString(CHATIV_NROFLINES),
			tooltip = GetString(CHATIV_NROFLINES_TOOLTIP),
			choices = {
				2,
				3,
				4,
				5,
				6,
			},
			getFunc = function() return getNrOfLines() end,
			setFunc = function(value) setNrOfLines(value) end,
		},
	}

	local LAM = LibAddonMenu2
	LAM:RegisterAddonPanel(panelName, panelData)
	LAM:RegisterOptionControls(panelName, optionsData)

	--- Keybinding
	kbText = GetString(CHATIV_KEYBINDING_TUGGLE)
	ZO_CreateStringId("SI_BINDING_NAME_CIV_TOGGLE_WINDOW", kbText)
end

--- Event handler for the EVENT_ADD_ON_LOADED event.
---   @param event string # The event name.
---   @param name string # The name of the loaded addon.
function ChatInputViewer.OnAddOnLoaded(event, name)

	if name ~= "ChatInputViewer" then return end

	EVENT_MANAGER:UnregisterForEvent("ChatInputViewer", EVENT_ADD_ON_LOADED)

	--- The default values for the ChatInputViewer addon.
	---   @class defaults
	---   @field visible boolean # The visibility status of the viewer.
	---   @field updatemessages object # Data structure for showing update informations after login.
	---   @field startversion   number # The AddOn version that was initially installed on this machine.
	---   @field messageversion number # The version of the last update information shown completly.
	---   @field messagecounter number # Counter how often the current update information was shown.
	local defaults = {
		updatemessages = {
			startversion = 10300,
			messageversion = 0,
			messagecounter = 0
		},
		visible = true,
		minimised = false,
		fontsize = 22,
		mode = 1,  -- adjusted to chat window
		windowwidth = 1000,
		nroflines = 4
	}

	--CivLogger:Debug( ".   Vor savedVariables lesen: "..tostring(defaults.visible)..", "..tostring(defaults.minimised))

	savedVariables = ZO_SavedVars:NewAccountWide("ChatInputViewerVars", 1, nil, defaults)

	--CivLogger:Debug( ".   Vor initializeChatInputViewer: "..tostring(savedVariables.visible)..", "..tostring(savedVariables.minimised))

	initializeChatInputViewer()

	--CivLogger:Debug( ".   Vor setVisibility: "..tostring(savedVariables.visible)..", "..tostring(savedVariables.minimised))

	setVisibility(savedVariables.visible, savedVariables.minimised)
	SetChatWindowAtStartUp()

	--CivLogger:Debug( ".   Vor SetChatHandlers: "..tostring(savedVariables.visible)..", "..tostring(savedVariables.minimised))

	SetChatHandlers(savedVariables.visible)

end

function ChatInputViewer.OnPlayerActivated(_, initial) 

	EVENT_MANAGER:UnregisterForEvent("ChatInputViewer", EVENT_PLAYER_ACTIVATED)

	if (savedVariables.updatemessages.messageversion < 10300) then

		if (savedVariables.updatemessages.messagecounter >= 5) then

			savedVariables.updatemessages.messageversion = 10300
			savedVariables.updatemessages.messagecounter = 0

		else

			savedVariables.updatemessages.messagecounter = savedVariables.updatemessages.messagecounter + 1
			-- 500 Millisekunden Verzögerung geben pChat Zeit, fertig zu werden
			zo_callLater(function() ShowWelcomeMessage() end, 500)

		end

	end

end

--- Create AddOn logger instance
--CivLogger = LibDebugLogger:Create(ChatInputViewer.name)
--CivLogger:Info( "CivLogger created.")
--CivLogger:SetMinLevelOverride(LibDebugLogger.LOG_LEVEL_DEBUG)
--CivLogger:Debug( "CivLogger log level set to DEBUG.")

--- Register the slash commands
SLASH_COMMANDS["/civshow"] = ShowViewer
SLASH_COMMANDS["/civhide"] = HideViewer
SLASH_COMMANDS["/civmini"] = MinimiseViewer

--- Register the EVENT_ADD_ON_LOADED event
EVENT_MANAGER:RegisterForEvent(ChatInputViewer.name, EVENT_ADD_ON_LOADED, ChatInputViewer.OnAddOnLoaded)

--- Register the EVENT_PLAYER_ACTIVATED  event
EVENT_MANAGER:RegisterForEvent(ChatInputViewer.name, EVENT_PLAYER_ACTIVATED, ChatInputViewer.OnPlayerActivated)