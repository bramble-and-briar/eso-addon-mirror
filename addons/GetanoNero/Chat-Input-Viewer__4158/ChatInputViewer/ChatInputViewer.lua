--- ChatInput viewer
--- Version 1.4.0

--- Changelog
--- V. 1.4.0  Code review to eliminate flaws and implement best practices.
---           All changes implemented or recommended by Baertram (https://www.esoui.com/forums/member.php?u=2028)
---           - Language files improved.
---           - Event and slash command regestration moved to OnAddOnLoaded()
---           - Leaking of global function ToggleViewer() removed.
---           - Registration of the AddOn to the ZO_ChatWindowTextEntryEditBox.OnTextChanged event corrected.
---           - Local references to global variables ZO_ChatWindow and ZO_ChatWindowTextEntryEditBox
---             added.
---           - Local references to global AddOn controls added.
---           - In the SavedVariables structure a layer for the ESO server added.
--- V. 1.3.1  - Update for ESO Version 12.1.5, API version 101051.
--- V. 1.3.0  - Update for ESO Version 12.0.5, API version 101050.
---           - New view mode 'minimized'
---           - Key binding for tuggling the view state
---           - new chat commands '/civshow', '/civhide', '/civmini'
---           - Message with update information after login.
--- V. 1.2.3  - Update for ESO Version 11.3.4, API version 101049.
--- V. 1.2.2  - Bugfix for an issue during AddOn initialization
--- V. 1.2.1  - Update for ESO Version 11.2.6, API version 101048.
---           - Exception prevented, when slash commands were used more than one time.
---           - Slash commands /civshow and /civhide added.
--- V. 1.2.0  - Update for ESO Version 11.1.5, API version 101047.
---           - Repeating the channel color of the input textbox in the viewer.
--- V. 1.1.0  - Russian translation added.
---           - Bugfix for character counting of multibyte characters.
---           - Spelling errors removed
--- V. 1.0.0  - Initial version.

--- ---------------------------------------------------------------------


--- The Addon namespace.
--- @class ChatInputViewer
--- @field OnAddOnLoaded function
--- @field name string
ChatInputViewer = {}

--- Best practice: Create local reference to global variable, to speed up _G table search.
--- Without the local variable each time ChatInputViewer is called, the global _G table is
--- searched for the entry _G["ChatInputViewer"].
--- (Baertram)
local ChatInputViewer = ChatInputViewer

ChatInputViewer.name = "ChatInputViewer"

--- Best practice: Create local references for often used controls of the AddOn.
--- The variables will be filled at EVENT_ADD_ON_LOADED after the XML file was processed too.
--- (Baertram)
ChatInputViewer.RootControl = nil
ChatInputViewer.BGControl = nil
ChatInputViewer.LabelControl = nil

---  Best practice: Create local reference variables to often used global variables,
---  that are available before AddOns load.
---  This improves performance as looking up the global variables needs more ressources.
---  (Baertram)

--- Variable for the the chat window.
local zoChatWindow = ZO_ChatWindow
--- Variable for the the input text field of the chat window.
local zoChatWindowTextEntryEditBox = ZO_ChatWindowTextEntryEditBox


--- @field CivLogger object # Instance of the LibDebugLogger logger for this AddOn.
local CivLogger

--- # ChatInputViewerVars
--- @class savedVariables
local savedVariables

--- Indicates whether the AddOn is already registered to the events of the chat input textbox.
local RegisteredToChatHandlerAndHooks = false


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
	if (savedVariables.updatemessages.viewcounter < 5) then
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

	chatInput = zoChatWindowTextEntryEditBox:GetText()
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
		ChatInputViewer.LabelControl:SetText(chatInput)
	else
		ChatInputViewer.LabelControl:SetText(chatInputSize .. " / 350")
	end

	if (currentInputLengthState > 1) then
		if (currentInputLengthState ~= LastInputLengthState) then
			statCol = InputLengthStateColors[currentInputLengthState]
			ChatInputViewer.LabelControl:SetColor(statCol[1], statCol[2], statCol[3], statCol[4])
			LastChannel = nil
		end
	elseif (LastChannel ~= CHAT_SYSTEM.currentChannel) then 
		ChatInputViewer.LabelControl:SetColor(ZO_ChatSystem_GetCategoryColorFromChannel(CHAT_SYSTEM.currentChannel))
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
		if ChatInputViewer.RootControl ~= nil then
			currentHeight = ChatInputViewer.RootControl:GetHeight()
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

	--CivLogger:Debug( "MoveChatWindowY()")

	chatYPos = zoChatWindow:GetBottom()

	if (deltaY > 0) then
		rootYPos = GuiRoot:GetBottom()
		if (chatYPos + deltaY > rootYPos) then
			deltaY = rootYPos - chatYPos
		end
	end

	--chatYPos2 = zoChatWindow:GetBottom()
	chatXPos = zoChatWindow:GetLeft()
	chatYPos = zoChatWindow:GetTop()
	chatheight1 = zoChatWindow:GetHeight()

	zoChatWindow:SetSimpleAnchorParent(chatXPos, chatYPos + deltaY)
	chatheight2 = zoChatWindow:GetHeight()

	if (chatheight2 ~= chatheight1) then
		zoChatWindow:SetSimpleAnchorParent(chatXPos, chatYPos + deltaY + 0.01)
		zoChatWindow:SetHeight(chatheight1)
	end

end


local function SetChatHandlers()

	--- Existing OnTextChanged handler of an other AddOn already registered to the
	--- ZO_ChatWindowTextEntryEditBox control.
	local existingOnTextChangedHandler

	-- Check if handler was added already; if so: Done (Baertram)
	if RegisteredToChatHandlerAndHooks then

		return
	end

	-- Store an already existing event handler of another AddOn in existingOnTextChangedHandler
	existingOnTextChangedHandler = zoChatWindowTextEntryEditBox:GetHandler("OnTextChanged")

	-- Register ChatInputViewer to the event
	zoChatWindowTextEntryEditBox:SetHandler("OnTextChanged",
		function(self)
			-- Only execute our addons' code if needed, and first always run the already existing code
			if (existingOnTextChangedHandler ~= nil) then
				existingOnTextChangedHandler(self)
			end

			-- Check if the handler must react on our chat input now (Baertram).
			if not savedVariables.visible then return end

			ShowChatInput()
		end
	)

	RegisteredToChatHandlerAndHooks = true

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

	ChatInputViewer.RootControl:SetHeight(newHeight)
	ChatInputViewer.LabelControl:SetHeight(newHeight - 10)
	if (savedVariables.visible == false) then
		ChatInputViewer.LabelControl:SetHidden(false)
		ChatInputViewer.BGControl:SetHidden(false)
		--SetChatHandlers(true)
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
		ChatInputViewer.LabelControl:SetHidden(true)
		ChatInputViewer.BGControl:SetHidden(true)
		--SetChatHandlers(false)
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
	ChatInputViewer.RootControl:SetHeight(newHeight)
	ChatInputViewer.LabelControl:SetHeight(newHeight - 10)
	if (savedVariables.visible == false) then
		ChatInputViewer.LabelControl:SetHidden(false)
		ChatInputViewer.BGControl:SetHidden(false)
		--SetChatHandlers(true)
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
		ChatInputViewer.RootControl:SetWidth(width)
	end

	nrOfShownLines = CalculateNrOfLines( savedVariables.visible, savedVariables.minimised, nrOfLines)
	height = CalculateViewerHeight(nrOfShownLines, fontsize)
	ChatInputViewer.RootControl:SetHeight(height)
	ChatInputViewer.LabelControl:SetHeight(height - 10)

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
	ChatInputViewer.LabelControl:SetFont("$(CHAT_FONT)|$(KB_" .. val .. ")|soft-shadow-thick")
	ChatInputViewer.RootControl:ClearAnchors()
	if (savedVariables.mode == 1) then
		ChatInputViewer.RootControl:SetAnchor(TOPLEFT, zoChatWindow, BOTTOMLEFT, 0, 0)
		ChatInputViewer.RootControl:SetAnchor(TOPRIGHT, zoChatWindow, BOTTOMRIGHT, 0, 0)
		ResizeViewerControl(0, nrOfShownLines, val)
	else
		ChatInputViewer.RootControl:SetAnchor(TOPLEFT, zoChatWindow, BOTTOMLEFT, 0, 0)
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

	ChatInputViewer.RootControl:ClearAnchors()
	if (savedVariables.mode == 1) then
		ChatInputViewer.RootControl:SetAnchor(TOPLEFT, zoChatWindow, BOTTOMLEFT, 0, 0)
		ChatInputViewer.RootControl:SetAnchor(TOPRIGHT, zoChatWindow, BOTTOMRIGHT, 0, 0)
		ResizeViewerControl(0, savedVariables.nroflines, savedVariables.fontsize)
	else
		ChatInputViewer.RootControl:SetAnchor(TOPLEFT, zoChatWindow, BOTTOMLEFT, 0, 0)
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
function ChatInputViewer.ToggleViewer()

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

	-- Update the created global XML controls to the local table so that they can be accessed
	-- via the local ChatInputViewer variable mroe easily.
	-- (Baertram)
	local civControl = ChatInputViewerControl
	local civControlLabel = GetControl(civControl, "_Label")
	local civControlBG = GetControl(civControl, "_BG")
	ChatInputViewer.RootControl = civControl
	ChatInputViewer.LabelControl = civControlLabel
	ChatInputViewer.BGControl = civControlBG


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

	ChatInputViewer.LabelControl:SetFont("$(CHAT_FONT)|$(KB_" .. savedVariables.fontsize .. ")|soft-shadow-thick")
	ChatInputViewer.LabelControl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	ChatInputViewer.RootControl:ClearAnchors()
	nrOfShownLines = CalculateNrOfLines( savedVariables.visible, savedVariables.minimised)
	if (savedVariables.mode == 1) then
		ChatInputViewer.RootControl:SetAnchor(TOPLEFT, zoChatWindow, BOTTOMLEFT, 0, 0)
		ChatInputViewer.RootControl:SetAnchor(TOPRIGHT, zoChatWindow, BOTTOMRIGHT, 0, 0)
		--ResizeViewerControl(0, nrOfShownLines, savedVariables.fontsize)
	else
		ChatInputViewer.RootControl:SetAnchor(TOPLEFT, zoChatWindow, BOTTOMLEFT, 0, 0)
		--ResizeViewerControl(savedVariables.windowwidth, nrOfShownLines, savedVariables.fontsize)
	end
	ChatInputViewer.LabelControl:SetHidden(not savedVariables.visible)
	ChatInputViewer.BGControl:SetHidden(not savedVariables.visible)

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

--- Register the slash commands
local function registerSlashCommands()

	SLASH_COMMANDS["/civshow"] = ShowViewer
	SLASH_COMMANDS["/civhide"] = HideViewer
	SLASH_COMMANDS["/civmini"] = MinimiseViewer

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
			messageversion = 0, -- was startversion = 10300,
			shownversion = 0,  -- was messageversion = 0
			viewcounter = 0   -- was messagecounter = 0
		},
		convertedTo10400 = false,
		visible = true,
		minimised = false,
		fontsize = 22,
		mode = 1,  -- adjusted to chat window
		windowwidth = 1000,
		nroflines = 4
	}

	--CivLogger:Debug( ".   Vor savedVariables lesen: "..tostring(defaults.visible)..", "..tostring(defaults.minimised))

	--savedVariables = ZO_SavedVars:NewAccountWide("ChatInputViewerVars", 1, nil, defaults, nil, nil)
	savedVariables = ZO_SavedVars:NewAccountWide("ChatInputViewerVars", 1, nil, defaults, GetWorldName(), nil)
	if savedVariables.convertedTo10400 == false then
		local oldSavedVariables = ZO_SavedVars:NewAccountWide("ChatInputViewerVars", 1, nil, defaults, nil, nil)
		-- Update messages are reset. There are no messages for this version. 
		savedVariables.updatemessages = {
			messageversion = 0,
			shownversion = 0,
			viewcounter = 0
		}
		savedVariables.visible = oldSavedVariables.visible
		savedVariables.minimised = oldSavedVariables.minimised
		savedVariables.fontsize = oldSavedVariables.fontsize
		savedVariables.mode = oldSavedVariables.mode
		savedVariables.windowwidth = oldSavedVariables.windowwidth
		savedVariables.nroflines = oldSavedVariables.nroflines
		ChatInputViewerVars["Default"] = nil
		savedVariables.convertedTo10400 = true
	end

	--CivLogger:Debug( ".   Vor initializeChatInputViewer: "..tostring(savedVariables.visible)..", "..tostring(savedVariables.minimised))

	initializeChatInputViewer()

	--CivLogger:Debug( ".   Vor setVisibility: "..tostring(savedVariables.visible)..", "..tostring(savedVariables.minimised))

	setVisibility(savedVariables.visible, savedVariables.minimised)
	SetChatWindowAtStartUp()

	--CivLogger:Debug( ".   Vor SetChatHandlers: "..tostring(savedVariables.visible)..", "..tostring(savedVariables.minimised))

	SetChatHandlers()

	--- Register the EVENT_PLAYER_ACTIVATED event
	EVENT_MANAGER:RegisterForEvent(ChatInputViewer.name, EVENT_PLAYER_ACTIVATED, ChatInputViewer.OnPlayerActivated)

	registerSlashCommands()

end

function ChatInputViewer.OnPlayerActivated(_, initial) 

	EVENT_MANAGER:UnregisterForEvent("ChatInputViewer", EVENT_PLAYER_ACTIVATED)

	if (savedVariables.updatemessages.shownversion < savedVariables.updatemessages.messageversion) then

		if (savedVariables.updatemessages.messagecounter >= 5) then

			savedVariables.updatemessages.shownversion = savedVariables.updatemessages.messageversion
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

--- Register the EVENT_ADD_ON_LOADED event
EVENT_MANAGER:RegisterForEvent(ChatInputViewer.name, EVENT_ADD_ON_LOADED, ChatInputViewer.OnAddOnLoaded)
