local addon = BureauOfPrivateDispatches
local private = addon.private
local CONFIG = addon.config
local ADDON_NAME = addon.name

local FormatLocalizedText = private.FormatLocalizedText
local BuildFont = private.BuildFont
local Utf8Prefix = private.Utf8Prefix
local ResolveSenderHue = private.ResolveSenderHue
local FormatElapsed = private.FormatElapsed
local SetControlColor = private.SetControlColor
local FOLLOW_UP_STATES = addon.followUpStates

local UPDATE_NAMESPACE_CLOCK = ADDON_NAME .. "Clock"
local UPDATE_NAMESPACE_INTERACTION = ADDON_NAME .. "Interaction"
local EVENT_NAMESPACE_SIGNAL = ADDON_NAME .. "Signal"
local PANEL_SCENE_NAMES = { "hud", "hudui" }

local GetString = GetString
local type = type
local unpack = unpack
local stringformat = string.format
local mathmin = math.min
local mathmax = math.max

addon.cards = {}
addon.clockRunning = false
addon.displayOrder = {}
addon.isInteractionLocked = false
addon.combatAutoCollapsed = false
addon.combatCollapseSuppressed = false

-- Tooltip ownership ---------------------------------------------------------
local activeTooltipOwner = nil

local function ShowControlTooltip(control, text)
	if type(text) ~= "string" or text == "" then
		return
	end

	activeTooltipOwner = control
	InitializeTooltip(InformationTooltip, control, LEFT, -6, 0, RIGHT)
	InformationTooltip:AddLine(text)
end

local function ShowControlTooltipLines(control, lines)
	if type(lines) ~= "table" or #lines == 0 then
		return
	end

	activeTooltipOwner = control
	InitializeTooltip(InformationTooltip, control, LEFT, -6, 0, RIGHT)
	for index = 1, #lines do
		local line = lines[index]
		if line == "" then
			if type(InformationTooltip.AddVerticalPadding) == "function" then
				InformationTooltip:AddVerticalPadding(6)
			end
		else
			InformationTooltip:AddLine(line)
		end
	end
end

local function HideControlTooltip(control)
	if control ~= nil and activeTooltipOwner ~= control then
		return
	end

	activeTooltipOwner = nil
	ClearTooltip(InformationTooltip)
end

private.HideControlTooltip = HideControlTooltip

-- Interaction locking ------------------------------------------------------
-- Mouse transitions between parent and child controls can briefly emit an exit
-- event. A short deferred unlock keeps the presentation order stable across
-- those transitions and while the panel is being dragged.
function addon:BeginPanelInteraction()
	EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAMESPACE_INTERACTION)
	self.isInteractionLocked = true
end

function addon:CancelPanelInteraction()
	EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAMESPACE_INTERACTION)
	self.isInteractionLocked = false
end

function addon:SchedulePanelInteractionEnd()
	EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAMESPACE_INTERACTION)
	EVENT_MANAGER:RegisterForUpdate(
		UPDATE_NAMESPACE_INTERACTION,
		CONFIG.INTERACTION_UNLOCK_DELAY_MS,
		function()
			EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAMESPACE_INTERACTION)
			if self.isMoving or not self.isInteractionLocked then
				return
			end
			if self.root ~= nil
				and type(MouseIsOver) == "function"
				and MouseIsOver(self.root) then
				return
			end

			self:CancelPanelInteraction()
			self:RefreshNotifications()
		end
	)
end

function addon:SynchronizeDisplayOrder()
	local displayOrder = self.displayOrder
	local seen = {}
	local writeIndex = 1

	if self.isInteractionLocked then
		for readIndex = 1, #displayOrder do
			local senderId = displayOrder[readIndex]
			if self.notificationsBySender[senderId] ~= nil and not seen[senderId] then
				seen[senderId] = true
				displayOrder[writeIndex] = senderId
				writeIndex = writeIndex + 1
			end
		end
	end

	for _, senderId in ipairs(self.senderOrder) do
		if not seen[senderId] then
			seen[senderId] = true
			displayOrder[writeIndex] = senderId
			writeIndex = writeIndex + 1
		end
	end

	for index = #displayOrder, writeIndex, -1 do
		displayOrder[index] = nil
	end
end

-- Control construction -----------------------------------------------------
function addon:CreateSurface(name, parent, centerColor, drawLevel)
	local surface = WINDOW_MANAGER:CreateControl(name, parent, CT_BACKDROP)
	surface:SetCenterColor(unpack(centerColor))
	surface:SetEdgeColor(unpack(CONFIG.TRANSPARENT_COLOR))

	if type(surface.SetInsets) == "function" then
		surface:SetInsets(0, 0, 0, 0)
	end
	if type(surface.SetEdgeTexture) == "function" then
		surface:SetEdgeTexture("", 1, 1, 0)
	end

	surface:SetDrawLevel(drawLevel or CONFIG.DRAW_LEVEL_BACKGROUND)
	return surface
end

function addon:CreateSurfaceFill(name, parent, centerColor, drawLevel)
	local surface = self:CreateSurface(name, parent, centerColor, drawLevel)
	surface:SetAnchorFill(parent)
	return surface
end

function addon:CreateGlyphButton(name, parent, glyph, tooltipText, hoverColor, onClicked, iconTexture)
	local button = WINDOW_MANAGER:CreateControl(name, parent, CT_BUTTON)
	button:SetDimensions(CONFIG.CLOSE_BUTTON_SIZE, CONFIG.CLOSE_BUTTON_SIZE)
	button:SetDrawLevel(CONFIG.DRAW_LEVEL_CONTENT)

	local visual
	if iconTexture ~= nil then
		visual = WINDOW_MANAGER:CreateControl(name .. "Icon", button, CT_TEXTURE)
		visual:SetAnchor(CENTER, button, CENTER, 0, 0)
		visual:SetDimensions(CONFIG.HEADER_ICON_SIZE, CONFIG.HEADER_ICON_SIZE)
		visual:SetTexture(iconTexture)
		button.icon = visual
	else
		visual = WINDOW_MANAGER:CreateControl(name .. "Label", button, CT_LABEL)
		visual:SetAnchorFill(button)
		visual:SetFont(BuildFont(CONFIG.FONT_FACE_BOLD, CONFIG.GLYPH_FONT_SIZE))
		visual:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
		visual:SetVerticalAlignment(TEXT_ALIGN_CENTER)
		visual:SetText(glyph)
		button.label = visual
	end
	visual:SetDrawLevel(CONFIG.DRAW_LEVEL_CONTENT)
	SetControlColor(visual, CONFIG.GLYPH_COLOR)
	button.tooltipText = tooltipText

	button:SetHandler("OnClicked", onClicked)
	button:SetHandler("OnMouseEnter", function(control)
		self:BeginPanelInteraction()
		button:SetAlpha(1)
		SetControlColor(visual, hoverColor)
		ShowControlTooltip(control, button.tooltipText or tooltipText)
	end)
	button:SetHandler("OnMouseExit", function(control)
		SetControlColor(visual, CONFIG.GLYPH_COLOR)
		HideControlTooltip(control)
		if button.hideWhenIdle then
			button:SetAlpha(0)
		end
		self:SchedulePanelInteractionEnd()
	end)
	button:SetHandler("OnEffectivelyHidden", function(control)
		SetControlColor(visual, CONFIG.GLYPH_COLOR)
		HideControlTooltip(control)
		if button.hideWhenIdle then
			button:SetAlpha(0)
		end
	end)

	return button
end

local function OpenWhisperTo(senderId)
	if type(senderId) ~= "string" or senderId == "" then
		return false
	end

	if type(StartChatInput) == "function" then
		StartChatInput("", CHAT_CHANNEL_WHISPER, senderId)
		return true
	end

	return false
end

local ignoreDialogRegistered = false

local function EnsureIgnoreDialog()
	if ignoreDialogRegistered or type(ESO_Dialogs) ~= "table" then
		return ignoreDialogRegistered
	end

	ESO_Dialogs["BPD_IGNORE_SENDER"] =
	{
		canQueue = true,
		title = { text = SI_BPD_IGNORE_TITLE },
		mainText =
		{
			text = function(dialog)
				local senderId = dialog.data and dialog.data.senderId or ""
				return zo_strformat(GetString(SI_BPD_IGNORE_BODY), senderId)
			end,
		},
		buttons =
		{
			{
				text = SI_DIALOG_CONFIRM,
				callback = function(dialog)
					local senderId = dialog.data and dialog.data.senderId
					if type(AddIgnore) == "function" and senderId ~= nil then
						AddIgnore(senderId)
					end
					addon:DismissSender(senderId)
				end,
			},
			{
				text = SI_DIALOG_CANCEL,
			},
		},
	}
	ignoreDialogRegistered = true
	return true
end

function addon:OpenMailTo(senderId)
	if type(senderId) ~= "string" or senderId == "" or MAIL_SEND == nil then
		return false
	end

	if SCENE_MANAGER ~= nil and type(SCENE_MANAGER.Show) == "function" then
		SCENE_MANAGER:Show("mailSend")
	end
	if type(MAIL_SEND.ComposeMailTo) == "function" then
		MAIL_SEND:ComposeMailTo(senderId)
		return true
	end
	if type(MAIL_SEND.SetReply) == "function" then
		MAIL_SEND:SetReply(senderId)
		return true
	end

	return false
end

function addon:TeleportToSender(entry)
	if entry == nil then
		return false
	end

	local relation = self:GetSenderRelation(entry)
	if not relation.canTeleport then
		return false
	end

	if relation.isGroup
		and type(relation.groupCharacterName) == "string"
		and type(JumpToGroupMember) == "function" then
		JumpToGroupMember(relation.groupCharacterName)
		return true
	end
	if relation.isFriend and type(JumpToFriend) == "function" then
		JumpToFriend(entry.senderId)
		return true
	end
	if relation.isGuild and type(JumpToGuildMember) == "function" then
		JumpToGuildMember(entry.senderId)
		return true
	end

	return false
end

function addon:ConfirmIgnoreSender(senderId)
	local entry = self.notificationsBySender[senderId]
	local relation = self:GetSenderRelation(entry)
	if not relation.canIgnore then
		return false
	end
	if relation.isIgnored then
		self:DismissSender(senderId)
		return true
	end
	if not EnsureIgnoreDialog() or type(ZO_Dialogs_ShowDialog) ~= "function" then
		return false
	end

	ZO_Dialogs_ShowDialog("BPD_IGNORE_SENDER", { senderId = senderId })
	return true
end

function addon:BuildCardTooltipLines(entry)
	if entry == nil then
		return nil
	end

	local relation = self:GetSenderRelation(entry)
	local lines = { entry.senderId }
	if type(entry.characterName) == "string"
		and entry.characterName ~= ""
		and entry.characterName ~= entry.senderId then
		lines[#lines + 1] = entry.characterName
	end

	local relationLabels = {}
	if relation.isGroup then
		relationLabels[#relationLabels + 1] = GetString(SI_BPD_TOOLTIP_RELATION_GROUP)
	end
	if relation.isFriend then
		relationLabels[#relationLabels + 1] = GetString(SI_BPD_TOOLTIP_RELATION_FRIEND)
	end
	if relation.isGuild then
		relationLabels[#relationLabels + 1] = GetString(SI_BPD_TOOLTIP_RELATION_GUILD)
	end
	if #relationLabels > 0 then
		lines[#lines + 1] = table.concat(relationLabels, " · ")
	end

	local unreadCount = entry.unreadCount or 0
	local readText = unreadCount > 0
		and FormatLocalizedText(SI_BPD_TOOLTIP_STATUS_UNREAD, unreadCount)
		or GetString(SI_BPD_TOOLTIP_STATUS_READ)
	local followUpText = GetString(SI_BPD_TOOLTIP_STATUS_PENDING)
	if entry.followUpState == FOLLOW_UP_STATES.ANSWERED then
		followUpText = GetString(SI_BPD_TOOLTIP_STATUS_ANSWERED)
	elseif entry.followUpState == FOLLOW_UP_STATES.OVERDUE then
		followUpText = GetString(SI_BPD_TOOLTIP_STATUS_OVERDUE)
	elseif entry.followUpState == FOLLOW_UP_STATES.WAITING then
		followUpText = GetString(SI_BPD_TOOLTIP_STATUS_WAITING)
	elseif entry.replyOpenedMs ~= nil then
		followUpText = GetString(SI_BPD_TOOLTIP_STATUS_COMPOSING)
	end
	lines[#lines + 1] = table.concat(
		{
			FormatElapsed(GetGameTimeMilliseconds() - (entry.lastMessageMs or GetGameTimeMilliseconds())),
			readText,
			followUpText,
		},
		" · "
	)

	if entry.previewIsPlaceholder then
		lines[#lines + 1] = GetString(SI_BPD_TOOLTIP_PLACEHOLDER)
	elseif type(entry.preview) == "string" and entry.preview ~= "" then
		lines[#lines + 1] = ""
		lines[#lines + 1] = entry.preview
	end

	lines[#lines + 1] = ""
	lines[#lines + 1] = GetString(SI_BPD_TOOLTIP_GESTURES)
	lines[#lines + 1] = GetString(SI_BPD_TOOLTIP_GESTURE_REPLY)
	lines[#lines + 1] = GetString(SI_BPD_TOOLTIP_GESTURE_OPEN)
	lines[#lines + 1] = GetString(SI_BPD_TOOLTIP_GESTURE_READ)
	lines[#lines + 1] = GetString(SI_BPD_TOOLTIP_GESTURE_HIDE)
	if relation.canMail then
		lines[#lines + 1] = GetString(SI_BPD_TOOLTIP_GESTURE_MAIL)
	end
	if relation.canTeleport then
		lines[#lines + 1] = GetString(SI_BPD_TOOLTIP_GESTURE_JUMP)
	end
	if relation.canIgnore then
		lines[#lines + 1] = GetString(SI_BPD_TOOLTIP_GESTURE_IGNORE)
	end

	return lines
end

function addon:HandleCardGesture(senderId, button)
	local entry = self.notificationsBySender[senderId]
	if entry == nil then
		return
	end

	local shift = type(IsShiftKeyDown) == "function" and IsShiftKeyDown() == true
	local ctrl = type(IsControlKeyDown) == "function" and IsControlKeyDown() == true
	local alt = type(IsAltKeyDown) == "function" and IsAltKeyDown() == true
	-- Alt alone is unused. Ignore is Ctrl+Alt+Right so it cannot be confused
	-- with teleport (Ctrl+Shift+Left) by swapping only the mouse button.
	if alt and not ctrl then
		return
	end

	local relation = self:GetSenderRelation(entry)
	if button == MOUSE_BUTTON_INDEX_LEFT then
		if alt then
			return
		end
		if ctrl and shift then
			if relation.canTeleport then
				self:TeleportToSender(entry)
			end
		elseif ctrl then
			if relation.canMail then
				self:OpenMailTo(senderId)
			end
		elseif shift then
			OpenWhisperTo(senderId)
		elseif OpenWhisperTo(senderId) then
			self:MarkReplyOpened(senderId)
		end
	elseif button == MOUSE_BUTTON_INDEX_MIDDLE then
		self:MarkSenderRead(senderId)
	elseif button == MOUSE_BUTTON_INDEX_RIGHT then
		if ctrl and alt then
			if relation.canIgnore then
				self:ConfirmIgnoreSender(senderId)
			end
		else
			self:DismissSender(senderId)
		end
	end
end

function addon:CreateNotificationCard(index)
	local name = stringformat("%sNotification%d", ADDON_NAME, index)
	local card = WINDOW_MANAGER:CreateControl(name, self.root, CT_CONTROL)
	card:SetDimensions(CONFIG.PANEL_WIDTH, CONFIG.EXPANDED_CARD_HEIGHT)
	card:SetHidden(true)
	card:SetMouseEnabled(true)

	card.background = self:CreateSurfaceFill(
		name .. "Background",
		card,
		CONFIG.CARD_BACKGROUND_COLOR,
		CONFIG.DRAW_LEVEL_BACKGROUND
	)
	card.pulseBackdrop = self:CreateSurfaceFill(
		name .. "Pulse",
		card,
		CONFIG.TRANSPARENT_COLOR,
		CONFIG.DRAW_LEVEL_WASH
	)
	card.pulseBackdrop:SetAlpha(CONFIG.PULSE_MIN_ALPHA)
	card.pulseAnimation = ZO_AlphaAnimation:New(card.pulseBackdrop)

	card.rail = self:CreateSurface(name .. "Rail", card, CONFIG.ACCENT_COLOR, CONFIG.DRAW_LEVEL_ACCENT)
	card.rail:SetAnchor(TOPLEFT, card, TOPLEFT, 0, 0)
	card.rail:SetAnchor(BOTTOMLEFT, card, BOTTOMLEFT, 0, 0)
	card.rail:SetWidth(CONFIG.RAIL_WIDTH)

	card.closeButton = self:CreateGlyphButton(
		name .. "Close",
		card,
		"×",
		GetString(SI_BPD_TOOLTIP_DISMISS),
		CONFIG.DISMISS_HOVER_COLOR,
		function()
			local senderId = card.armedSenderId or card.senderId
			card.armedSenderId = nil
			card.skipGesture = true
			self:DismissSender(senderId)
			self:SchedulePanelInteractionEnd()
		end
	)
	card.closeButton:SetHandler("OnMouseDown", function()
		self:BeginPanelInteraction()
		card.armedSenderId = card.senderId
		card.skipGesture = true
	end)
	card.closeButton:SetHandler("OnMouseExit", function(control)
		SetControlColor(card.closeButton.label, CONFIG.GLYPH_COLOR)
		HideControlTooltip(control)
		local cardHovered = type(MouseIsOver) == "function" and MouseIsOver(card)
		if card.closeButton.hideWhenIdle and not cardHovered then
			card.closeButton:SetAlpha(0)
		end
		if cardHovered then
			ShowControlTooltipLines(card, self:BuildCardTooltipLines(self.notificationsBySender[card.senderId]))
		end
		self:SchedulePanelInteractionEnd()
	end)
	card.closeButton.hideWhenIdle = true
	card.closeButton:SetAlpha(0)
	card:SetHandler("OnMouseDown", function(_, button)
		self:BeginPanelInteraction()
		card.armedSenderId = card.senderId
		if button == MOUSE_BUTTON_INDEX_MIDDLE then
			card.consumeMiddleUp = true
			self:HandleCardGesture(card.senderId, button)
			self:SchedulePanelInteractionEnd()
		end
	end)

	card.senderLabel = WINDOW_MANAGER:CreateControl(name .. "Sender", card, CT_LABEL)
	card.senderLabel:SetDrawLevel(CONFIG.DRAW_LEVEL_CONTENT)
	card.senderLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
	card.senderLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	card.senderLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	card.senderLabel:SetMaxLineCount(1)
	SetControlColor(card.senderLabel, CONFIG.SENDER_TEXT_COLOR)

	card.messageLabel = WINDOW_MANAGER:CreateControl(name .. "Message", card, CT_LABEL)
	card.messageLabel:SetDrawLevel(CONFIG.DRAW_LEVEL_CONTENT)
	card.messageLabel:SetFont(BuildFont(CONFIG.FONT_FACE, CONFIG.MESSAGE_FONT_SIZE))
	card.messageLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
	card.messageLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	card.messageLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	card.messageLabel:SetMaxLineCount(1)
	SetControlColor(card.messageLabel, CONFIG.MESSAGE_TEXT_COLOR)

	card.countLabel = WINDOW_MANAGER:CreateControl(name .. "Count", card, CT_LABEL)
	card.countLabel:SetDrawLevel(CONFIG.DRAW_LEVEL_CONTENT)
	card.countLabel:SetFont(BuildFont(CONFIG.FONT_FACE_BOLD, CONFIG.META_FONT_SIZE))
	card.countLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
	card.countLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	card.countLabel:SetMaxLineCount(1)
	SetControlColor(card.countLabel, CONFIG.COUNT_TEXT_COLOR)

	card.statusLabel = WINDOW_MANAGER:CreateControl(name .. "Status", card, CT_LABEL)
	card.statusLabel:SetDrawLevel(CONFIG.DRAW_LEVEL_CONTENT)
	card.statusLabel:SetFont(BuildFont(CONFIG.FONT_FACE_BOLD, CONFIG.META_FONT_SIZE))
	card.statusLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	card.statusLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	card.statusLabel:SetMaxLineCount(1)
	SetControlColor(card.statusLabel, CONFIG.MUTED_TEXT_COLOR)

	card.timeLabel = WINDOW_MANAGER:CreateControl(name .. "Time", card, CT_LABEL)
	card.timeLabel:SetDrawLevel(CONFIG.DRAW_LEVEL_CONTENT)
	card.timeLabel:SetFont(BuildFont(CONFIG.FONT_FACE, CONFIG.META_FONT_SIZE))
	card.timeLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
	card.timeLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	card.timeLabel:SetMaxLineCount(1)
	SetControlColor(card.timeLabel, CONFIG.MUTED_TEXT_COLOR)

	card:SetHandler("OnMouseEnter", function(control)
		self:BeginPanelInteraction()
		self:TintSurface(card.background, CONFIG.CARD_HOVER_COLOR)
		card.closeButton:SetAlpha(1)
		local entry = self.notificationsBySender[card.senderId]
		ShowControlTooltipLines(control, self:BuildCardTooltipLines(entry))
	end)
	card:SetHandler("OnMouseExit", function(control)
		self:TintSurface(card.background, CONFIG.CARD_BACKGROUND_COLOR)
		card.closeButton:SetAlpha(0)
		HideControlTooltip(control)
		self:SchedulePanelInteractionEnd()
	end)
	card:SetHandler("OnEffectivelyHidden", function(control)
		self:TintSurface(card.background, CONFIG.CARD_BACKGROUND_COLOR)
		card.closeButton:SetAlpha(0)
		HideControlTooltip(control)
	end)
	card:SetHandler("OnMouseUp", function(_, button, upInside)
		local senderId = card.armedSenderId or card.senderId
		card.armedSenderId = nil
		if card.skipGesture then
			card.skipGesture = nil
			return
		end
		if card.consumeMiddleUp and button == MOUSE_BUTTON_INDEX_MIDDLE then
			card.consumeMiddleUp = nil
			return
		end
		if not upInside then
			return
		end

		self:HandleCardGesture(senderId, button)
		self:SchedulePanelInteractionEnd()
	end)

	return card
end

function addon:CreateInterface()
	self.root = WINDOW_MANAGER:CreateTopLevelWindow(ADDON_NAME .. "Window")
	self.root:SetDimensions(CONFIG.PANEL_WIDTH, CONFIG.HEADER_HEIGHT)
	self.root:SetDrawTier(DT_HIGH)
	self.root:SetClampedToScreen(true)
	self.root:SetMouseEnabled(true)
	self.root:SetMovable(true)
	self.root:SetHidden(true)
	self:ApplySavedPosition()
	self.root:SetHandler("OnMouseEnter", function()
		self:BeginPanelInteraction()
	end)
	self.root:SetHandler("OnMouseExit", function()
		self:SchedulePanelInteractionEnd()
	end)

	self.root:SetHandler("OnMoveStop", function()
		self.isMoving = false
		self:SavePosition()
		self:SchedulePanelInteractionEnd()
	end)

	self.header = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "Header", self.root, CT_CONTROL)
	self.header:SetAnchor(TOPLEFT, self.root, TOPLEFT, 0, 0)
	self.header:SetAnchor(TOPRIGHT, self.root, TOPRIGHT, 0, 0)
	self.header:SetHeight(CONFIG.HEADER_HEIGHT)
	self.header:SetMouseEnabled(true)
	self.header:SetHandler("OnMouseEnter", function()
		self:BeginPanelInteraction()
	end)
	self.header:SetHandler("OnMouseExit", function()
		self:SchedulePanelInteractionEnd()
	end)

	self.headerBackdrop = self:CreateSurfaceFill(
		ADDON_NAME .. "HeaderBackground",
		self.header,
		CONFIG.HEADER_BACKGROUND_COLOR,
		CONFIG.DRAW_LEVEL_BACKGROUND
	)
	self.headerPulseBackdrop = self:CreateSurfaceFill(
		ADDON_NAME .. "HeaderPulse",
		self.header,
		CONFIG.TRANSPARENT_COLOR,
		CONFIG.DRAW_LEVEL_WASH
	)
	self.headerPulseBackdrop:SetAlpha(CONFIG.PULSE_MIN_ALPHA)
	self.headerPulseAnimation = ZO_AlphaAnimation:New(self.headerPulseBackdrop)
	self.headerRail = self:CreateSurface(
		ADDON_NAME .. "HeaderRail",
		self.header,
		CONFIG.ACCENT_COLOR,
		CONFIG.DRAW_LEVEL_ACCENT
	)
	self.headerRail:SetAnchor(TOPLEFT, self.header, TOPLEFT, 0, 0)
	self.headerRail:SetAnchor(BOTTOMLEFT, self.header, BOTTOMLEFT, 0, 0)
	self.headerRail:SetWidth(CONFIG.RAIL_WIDTH)

	self.headerHairline = self:CreateSurface(
		ADDON_NAME .. "HeaderHairline",
		self.header,
		CONFIG.HAIRLINE_COLOR,
		CONFIG.DRAW_LEVEL_ACCENT
	)
	self.headerHairline:SetAnchor(BOTTOMLEFT, self.header, BOTTOMLEFT, 0, 0)
	self.headerHairline:SetAnchor(BOTTOMRIGHT, self.header, BOTTOMRIGHT, 0, 0)
	self.headerHairline:SetHeight(1)

	self.headerTitle = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "HeaderTitle", self.header, CT_LABEL)
	self.headerTitle:SetDrawLevel(CONFIG.DRAW_LEVEL_CONTENT)
	self.headerTitle:SetAnchor(
		LEFT,
		self.header,
		LEFT,
		CONFIG.RAIL_WIDTH + CONFIG.HEADER_HORIZONTAL_PADDING,
		0
	)
	self.headerTitle:SetFont(BuildFont(CONFIG.FONT_FACE_BOLD, CONFIG.HEADER_FONT_SIZE))
	self.headerTitle:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	self.headerTitle:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	self.headerTitle:SetMaxLineCount(1)
	self.headerTitle:SetText(GetString(SI_BPD_HEADER_TITLE))
	SetControlColor(self.headerTitle, CONFIG.HEADER_TEXT_COLOR)

	self.clearButton = self:CreateGlyphButton(
		ADDON_NAME .. "ClearAll",
		self.header,
		nil,
		GetString(SI_BPD_TOOLTIP_CLEAR_ALL),
		CONFIG.DISMISS_HOVER_COLOR,
		function()
			self:ClearAllNotifications()
		end,
		CONFIG.HEADER_CLEAR_TEXTURE
	)
	self.clearButton.icon:SetTextureCoords(0.15625, 0.84375, 0.15625, 0.84375)
	self.clearButton:SetAnchor(RIGHT, self.header, RIGHT, -CONFIG.CLOSE_BUTTON_INSET, 0)

	self.collapseButton = self:CreateGlyphButton(
		ADDON_NAME .. "Collapse",
		self.header,
		nil,
		GetString(SI_BPD_TOOLTIP_COLLAPSE),
		CONFIG.GLYPH_HOVER_COLOR,
		function()
			self:ToggleCollapsed()
		end,
		CONFIG.HEADER_COLLAPSE_TEXTURE
	)
	self.collapseButton:SetAnchor(RIGHT, self.clearButton, LEFT, -2, 0)

	self.lockButton = self:CreateGlyphButton(
		ADDON_NAME .. "Lock",
		self.header,
		nil,
		GetString(SI_BPD_TOOLTIP_LOCK),
		CONFIG.GLYPH_HOVER_COLOR,
		function()
			self:TogglePanelLock()
		end,
		CONFIG.HEADER_UNLOCK_TEXTURE
	)
	self.lockButton:SetAnchor(RIGHT, self.collapseButton, LEFT, -2, 0)

	self.headerCount = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "HeaderCount", self.header, CT_LABEL)
	self.headerCount:SetAnchor(RIGHT, self.lockButton, LEFT, -CONFIG.META_GAP, 0)
	self.headerCount:SetFont(BuildFont(CONFIG.FONT_FACE_BOLD, CONFIG.HEADER_COUNT_FONT_SIZE))
	self.headerCount:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
	self.headerCount:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	self.headerCount:SetDimensions(CONFIG.HEADER_COUNT_WIDTH, CONFIG.HEADER_HEIGHT)
	self.headerCount:SetMaxLineCount(1)
	SetControlColor(self.headerCount, CONFIG.COUNT_TEXT_COLOR)
	self.headerTitle:SetAnchor(RIGHT, self.headerCount, LEFT, -CONFIG.HEADER_HORIZONTAL_PADDING, 0)

	self.header:SetHandler("OnMouseDown", function(_, button)
		if button == MOUSE_BUTTON_INDEX_LEFT then
			if self:IsPanelLocked() then
				return
			end
			self:BeginPanelInteraction()
			self.isMoving = true
			self.root:StartMoving()
		end
	end)
	self.header:SetHandler("OnMouseUp", function(_, button)
		if button == MOUSE_BUTTON_INDEX_LEFT and self.isMoving then
			self.isMoving = false
			self.root:StopMovingOrResizing()
			self:SavePosition()
			self:SchedulePanelInteractionEnd()
		end
	end)

	for index = 1, CONFIG.MAX_VISIBLE_SENDERS do
		self.cards[index] = self:CreateNotificationCard(index)
	end

	self.overflow = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "Overflow", self.root, CT_CONTROL)
	self.overflow:SetDimensions(CONFIG.PANEL_WIDTH, CONFIG.OVERFLOW_HEIGHT)
	self.overflow:SetHidden(true)
	self.overflow:SetMouseEnabled(true)
	self.overflow:SetHandler("OnMouseEnter", function(control)
		self:BeginPanelInteraction()
		ShowControlTooltip(control, GetString(SI_BPD_TOOLTIP_OVERFLOW))
	end)
	self.overflow:SetHandler("OnMouseExit", function(control)
		HideControlTooltip(control)
		self:SchedulePanelInteractionEnd()
	end)
	self.overflow:SetHandler("OnMouseUp", function(_, button, upInside)
		if not upInside then
			return
		end
		if button == MOUSE_BUTTON_INDEX_LEFT then
			self:CycleOverflowPage()
		elseif button == MOUSE_BUTTON_INDEX_RIGHT then
			self:RestoreLastDismissed()
		end
		self:SchedulePanelInteractionEnd()
	end)
	self.overflowBackdrop = self:CreateSurfaceFill(
		ADDON_NAME .. "OverflowBackground",
		self.overflow,
		CONFIG.OVERFLOW_BACKGROUND_COLOR,
		CONFIG.DRAW_LEVEL_BACKGROUND
	)
	self.overflowLabel = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "OverflowLabel", self.overflow, CT_LABEL)
	self.overflowLabel:SetAnchorFill(self.overflow)
	self.overflowLabel:SetDrawLevel(CONFIG.DRAW_LEVEL_CONTENT)
	self.overflowLabel:SetFont(BuildFont(CONFIG.FONT_FACE, CONFIG.OVERFLOW_FONT_SIZE))
	self.overflowLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.overflowLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	self.overflowLabel:SetMaxLineCount(1)
	SetControlColor(self.overflowLabel, CONFIG.MUTED_TEXT_COLOR)
end

-- Visibility and clock -----------------------------------------------------
function addon:IsPanelCollapsed()
	if self.combatAutoCollapsed then
		return true
	end
	return self.savedVariables ~= nil and self.savedVariables.collapsed == true
end

function addon:ToggleCollapsed()
	if self.savedVariables == nil then
		return
	end

	if self.combatAutoCollapsed then
		self.combatAutoCollapsed = false
		self.combatCollapseSuppressed = true
		self.savedVariables.collapsed = false
		self:RefreshNotifications()
		return
	end

	self.savedVariables.collapsed = not self.savedVariables.collapsed
	self:RefreshNotifications()
end

function addon:IsPanelLocked()
	return self.savedVariables ~= nil and self.savedVariables.locked == true
end

function addon:ApplyPanelLock()
	local locked = self:IsPanelLocked()
	if self.root ~= nil and type(self.root.SetMovable) == "function" then
		self.root:SetMovable(not locked)
	end
	if self.lockButton ~= nil and self.lockButton.icon ~= nil then
		self.lockButton.icon:SetTexture(locked and CONFIG.HEADER_LOCK_TEXTURE or CONFIG.HEADER_UNLOCK_TEXTURE)
		self.lockButton.tooltipText = GetString(locked and SI_BPD_TOOLTIP_UNLOCK or SI_BPD_TOOLTIP_LOCK)
	end
end

function addon:SetPanelLocked(locked)
	if self.savedVariables == nil then
		return false
	end
	self.savedVariables.locked = locked == true
	self:ApplyPanelLock()
	return self.savedVariables.locked
end

function addon:TogglePanelLock()
	return self:SetPanelLocked(not self:IsPanelLocked())
end

local function ClampSetting(value, minimum, maximum, fallback)
	if type(value) ~= "number" or value ~= value then
		return fallback
	end
	if value < minimum then
		return minimum
	end
	if value > maximum then
		return maximum
	end
	return value
end

function addon:GetPanelScale()
	local scale = self.savedVariables ~= nil and self.savedVariables.scale or CONFIG.PANEL_SCALE_DEFAULT
	return ClampSetting(scale, CONFIG.PANEL_SCALE_MIN, CONFIG.PANEL_SCALE_MAX, CONFIG.PANEL_SCALE_DEFAULT)
end

function addon:GetPanelOpacity()
	local opacity = self.savedVariables ~= nil and self.savedVariables.opacity or CONFIG.PANEL_OPACITY_DEFAULT
	return ClampSetting(opacity, CONFIG.PANEL_OPACITY_MIN, CONFIG.PANEL_OPACITY_MAX, CONFIG.PANEL_OPACITY_DEFAULT)
end

function addon:TintSurface(control, color)
	if control == nil or type(color) ~= "table" then
		return
	end

	local opacity = self:GetPanelOpacity()
	control:SetCenterColor(color[1], color[2], color[3], (color[4] or 1) * opacity)
end

function addon:ApplyPanelAppearance()
	if self.root == nil then
		return
	end

	if type(self.root.SetScale) == "function" then
		self.root:SetScale(self:GetPanelScale())
	end

	self:TintSurface(self.headerBackdrop, CONFIG.HEADER_BACKGROUND_COLOR)
	self:TintSurface(self.overflowBackdrop, CONFIG.OVERFLOW_BACKGROUND_COLOR)
	for _, card in ipairs(self.cards) do
		if card.background ~= nil then
			self:TintSurface(card.background, CONFIG.CARD_BACKGROUND_COLOR)
		end
	end
end

function addon:SetPanelScale(scale)
	if self.savedVariables == nil or type(scale) ~= "number" or scale ~= scale then
		return false
	end

	self.savedVariables.scale = ClampSetting(
		scale,
		CONFIG.PANEL_SCALE_MIN,
		CONFIG.PANEL_SCALE_MAX,
		CONFIG.PANEL_SCALE_DEFAULT
	)
	self:ApplyPanelAppearance()
	return true
end

function addon:SetPanelOpacity(opacity)
	if self.savedVariables == nil or type(opacity) ~= "number" or opacity ~= opacity then
		return false
	end

	self.savedVariables.opacity = ClampSetting(
		opacity,
		CONFIG.PANEL_OPACITY_MIN,
		CONFIG.PANEL_OPACITY_MAX,
		CONFIG.PANEL_OPACITY_DEFAULT
	)
	self:ApplyPanelAppearance()
	return true
end

function addon:SetAutoCollapseInCombat(enabled)
	if self.savedVariables == nil then
		return false
	end

	self.savedVariables.autoCollapseInCombat = enabled == true
	if not self.savedVariables.autoCollapseInCombat then
		self.combatAutoCollapsed = false
		self.combatCollapseSuppressed = false
	end
	self:UpdateCombatCollapse()
	return self.savedVariables.autoCollapseInCombat == true
end

function addon:ToggleAutoCollapseInCombat()
	return self:SetAutoCollapseInCombat(not (self.savedVariables ~= nil and self.savedVariables.autoCollapseInCombat))
end

function addon:UpdateCombatCollapse()
	local wasAutoCollapsed = self.combatAutoCollapsed == true

	if self.savedVariables == nil or not self.savedVariables.autoCollapseInCombat then
		self.combatAutoCollapsed = false
		self.combatCollapseSuppressed = false
		if wasAutoCollapsed then
			self:RefreshNotifications()
		end
		return
	end

	if self:IsPlayerInCombat() then
		if self.combatCollapseSuppressed or self.savedVariables.collapsed then
			return
		end
		if not self.combatAutoCollapsed then
			self.combatAutoCollapsed = true
			self:RefreshNotifications()
		end
		return
	end

	self.combatCollapseSuppressed = false
	self.combatAutoCollapsed = false
	if wasAutoCollapsed then
		self:RefreshNotifications()
	end
end

function addon:RegisterSceneVisibility()
	self.panelScenes = {}

	if SCENE_MANAGER == nil or type(SCENE_MANAGER.GetScene) ~= "function" then
		return
	end

	local onSceneStateChange = function()
		if not self:IsPanelSceneActive() then
			self:CancelPanelInteraction()
		end
		self:RefreshNotifications()
	end

	for _, sceneName in ipairs(PANEL_SCENE_NAMES) do
		local scene = SCENE_MANAGER:GetScene(sceneName)
		if scene ~= nil and type(scene.IsShowing) == "function" then
			self.panelScenes[#self.panelScenes + 1] = scene
			scene:RegisterCallback("StateChange", onSceneStateChange)
		end
	end
end

function addon:IsPanelSceneActive()
	if self.panelScenes == nil or #self.panelScenes == 0 then
		return true
	end

	for _, scene in ipairs(self.panelScenes) do
		if scene:IsShowing() then
			return true
		end
	end

	return false
end

function addon:UpdateVisibility()
	if not self.root then
		return
	end

	local hasNotifications = #self.senderOrder > 0
	local shouldHide = not hasNotifications or not self:IsPanelSceneActive()
	if shouldHide and not self.isMoving then
		self:CancelPanelInteraction()
	end
	if not hasNotifications then
		self:StopHeaderPulse()
	end
	self.root:SetHidden(shouldHide)

	if not shouldHide then
		self:StartPendingCardPulses()
	end

	self:UpdateClockRegistration()
end

function addon:UpdateClockRegistration()
	local shouldRun = #self.senderOrder > 0
	if shouldRun == self.clockRunning then
		return
	end

	self.clockRunning = shouldRun
	if shouldRun then
		EVENT_MANAGER:RegisterForUpdate(UPDATE_NAMESPACE_CLOCK, CONFIG.CLOCK_INTERVAL_MS, self.clockCallback)
	else
		EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAMESPACE_CLOCK)
	end
end

function addon:IsPlayerInCombat()
	return type(IsUnitInCombat) == "function" and IsUnitInCombat("player") == true
end

function addon:IsManualDndActive(nowStamp)
	nowStamp = nowStamp or (type(GetTimeStamp) == "function" and GetTimeStamp() or nil)
	if type(self.dndUntilStamp) ~= "number" or type(nowStamp) ~= "number" then
		return false
	end
	if nowStamp >= self.dndUntilStamp then
		self.dndUntilStamp = nil
		return false
	end
	return true
end

function addon:IsDndActive()
	if self:IsManualDndActive() then
		return true
	end
	local autoDnd = self.savedVariables ~= nil and self.savedVariables.autoDndInCombat
	if autoDnd == false then
		return false
	end
	return self:IsPlayerInCombat()
end

function addon:IsMuted()
	return self.savedVariables ~= nil and self.savedVariables.muted == true
end

function addon:CanPlayIncomingSound(entry)
	if self.suppressArrivalCues then
		return false
	end
	if self:IsDndActive() then
		return false
	end
	if self:IsMuted() then
		return false
	end
	return self.savedVariables == nil or self.savedVariables.incomingSound ~= false
end

function addon:CanPlayOverdueSound()
	if self:IsDndActive() or self:IsMuted() then
		return false
	end
	return self.savedVariables == nil or self.savedVariables.overdueSound ~= false
end

function addon:CanShowArrivalPulse()
	if self.suppressArrivalCues or self:IsDndActive() then
		return false
	end
	return true
end

function addon:CanSignalFollowUpReminder()
	if not self:IsPanelSceneActive() or self.isInteractionLocked or self.isMoving then
		return false
	end
	if self:IsDndActive() or self:IsPlayerInCombat() then
		return false
	end
	return true
end

function addon:PlayNamedSound(soundName)
	if type(PlaySound) ~= "function" or type(SOUNDS) ~= "table" or type(soundName) ~= "string" then
		return false
	end

	local sound = SOUNDS[soundName]
	if sound == nil then
		return false
	end

	PlaySound(sound)
	return true
end

function addon:NotifyIncomingWhisper(entry)
	if entry == nil or self.suppressArrivalCues then
		return
	end
	if not self:CanPlayIncomingSound(entry) then
		return
	end

	local now = GetGameTimeMilliseconds()
	if type(self.lastIncomingSoundMs) == "number"
		and now - self.lastIncomingSoundMs < CONFIG.INCOMING_SOUND_THROTTLE_MS then
		return
	end

	if self:PlayNamedSound(CONFIG.INCOMING_SOUND) then
		self.lastIncomingSoundMs = now
	end
end

function addon:SetMuted(muted)
	if self.savedVariables == nil then
		return false
	end
	self.savedVariables.muted = muted == true
	return true
end

function addon:SetIncomingSound(enabled)
	if self.savedVariables == nil then
		return false
	end
	self.savedVariables.incomingSound = enabled == true
	return self.savedVariables.incomingSound
end

function addon:SetOverdueSound(enabled)
	if self.savedVariables == nil then
		return false
	end
	self.savedVariables.overdueSound = enabled == true
	return self.savedVariables.overdueSound
end

function addon:SetAutoDndInCombat(enabled)
	if self.savedVariables == nil then
		return false
	end
	self.savedVariables.autoDndInCombat = enabled == true
	self:OnDndStateChanged()
	return self.savedVariables.autoDndInCombat
end

function addon:ToggleMuted()
	local nextMuted = not self:IsMuted()
	self:SetMuted(nextMuted)
	return nextMuted
end

function addon:SetManualDnd(enabled)
	if enabled then
		local nowStamp = type(GetTimeStamp) == "function" and GetTimeStamp() or nil
		if type(nowStamp) ~= "number" then
			return false
		end
		self.dndUntilStamp = nowStamp + CONFIG.DND_DURATION_SECONDS
		self:OnDndStateChanged()
		return true
	end

	if self.dndUntilStamp == nil then
		return false
	end
	self.dndUntilStamp = nil
	self:OnDndStateChanged()
	return true
end

function addon:ToggleManualDnd()
	local enabled = not self:IsManualDndActive()
	self:SetManualDnd(enabled)
	return enabled
end

function addon:FlushDeferredCues()
	if self:IsDndActive() then
		return
	end

	if self:CanShowArrivalPulse() then
		self:StartPendingCardPulses()
	end
	if self:CanSignalFollowUpReminder() then
		self:StartPendingFollowUpReminder()
	end
end

function addon:OnDndStateChanged()
	local active = self:IsDndActive()
	if active == self.wasDndActive then
		return
	end
	self.wasDndActive = active
	if not active then
		self:FlushDeferredCues()
	end
end

function addon:RegisterSignalEvents()
	EVENT_MANAGER:RegisterForEvent(
		EVENT_NAMESPACE_SIGNAL,
		EVENT_PLAYER_COMBAT_STATE,
		function()
			self:OnDndStateChanged()
			self:UpdateCombatCollapse()
		end
	)
end

function addon:OnClockTick()
	local now = GetGameTimeMilliseconds()
	self:OnDndStateChanged()
	local canSignalReminder = self:CanSignalFollowUpReminder()
	local modelChanged = self:UpdateFollowUps(now, canSignalReminder)
	if not modelChanged then
		self:RefreshTimestamps(now)
	end

	if canSignalReminder then
		self:StartPendingFollowUpReminder()
	end
end

function addon:RefreshTimestamps(now)
	now = now or GetGameTimeMilliseconds()

	for _, card in ipairs(self.cards) do
		local senderId = card.senderId
		if senderId ~= nil and not card:IsHidden() then
			local entry = self.notificationsBySender[senderId]
			if entry ~= nil then
				card.timeLabel:SetText(FormatElapsed(now - entry.lastMessageMs))
			end
		end
	end
end

-- Animation and card binding ----------------------------------------------
function addon:StartCardPulse(card)
	card.pulseAnimation:Stop()
	card.pulseBackdrop:SetAlpha(CONFIG.PULSE_MIN_ALPHA)
	card.pulseAnimation:PingPong(
		CONFIG.PULSE_MIN_ALPHA,
		CONFIG.PULSE_MAX_ALPHA,
		CONFIG.PULSE_DURATION_MS,
		CONFIG.PULSE_LOOP_COUNT
	)
end

function addon:StopCardPulse(card)
	card.pulseAnimation:Stop()
	card.pulseBackdrop:SetAlpha(CONFIG.PULSE_MIN_ALPHA)
end

function addon:StartHeaderPulse(hue, senderId, revision, pulseKind)
	self.headerPulseAnimation:Stop()
	self.headerPulseBackdrop:SetCenterColor(hue[1], hue[2], hue[3], CONFIG.PULSE_TINT_ALPHA)
	self.headerPulseBackdrop:SetAlpha(CONFIG.PULSE_MIN_ALPHA)
	self.headerPulseSenderId = senderId
	self.headerPulseRevision = revision
	self.headerPulseKind = pulseKind
	self.headerPulseAnimation:PingPong(
		CONFIG.PULSE_MIN_ALPHA,
		CONFIG.PULSE_MAX_ALPHA,
		CONFIG.PULSE_DURATION_MS,
		CONFIG.PULSE_LOOP_COUNT
	)
end

function addon:StopHeaderPulse()
	if self.headerPulseAnimation == nil then
		return
	end

	self.headerPulseAnimation:Stop()
	self.headerPulseBackdrop:SetAlpha(CONFIG.PULSE_MIN_ALPHA)
	self.headerPulseSenderId = nil
	self.headerPulseRevision = nil
	self.headerPulseKind = nil
end

function addon:ReleaseCard(card)
	self:StopCardPulse(card)
	card.senderId = nil
	card.armedSenderId = nil
	card.skipGesture = nil
	card.revision = nil
	card.closeButton:SetAlpha(0)
	card.statusLabel:SetText("")
	card.consumeMiddleUp = nil
	HideControlTooltip(card.closeButton)
	HideControlTooltip(card)
	card:SetHidden(true)
end

function addon:PopulateCard(card, entry, expanded)
	local hue = ResolveSenderHue(entry.senderId)
	local previousSenderId = card.senderId
	local isLatestRevision = self.latestNotificationSenderId == entry.senderId
		and self.latestNotificationRevision == entry.revision
	local needsPulseRestart = isLatestRevision and entry.pulsedRevision ~= entry.revision
	local canShowPulse = self:IsPanelSceneActive() and self:CanShowArrivalPulse()

	card.senderId = entry.senderId
	card.revision = entry.revision
	if self.focusedSenderId == entry.senderId then
		card.rail:SetCenterColor(unpack(CONFIG.FOCUS_RAIL_COLOR))
	else
		card.rail:SetCenterColor(unpack(hue))
	end
	card.pulseBackdrop:SetCenterColor(hue[1], hue[2], hue[3], CONFIG.PULSE_TINT_ALPHA)

	card.senderLabel:ClearAnchors()
	card.messageLabel:ClearAnchors()
	card.countLabel:ClearAnchors()
	card.statusLabel:ClearAnchors()
	card.timeLabel:ClearAnchors()
	card.closeButton:ClearAnchors()

	local closeZone = CONFIG.CLOSE_BUTTON_INSET + CONFIG.CLOSE_BUTTON_SIZE + CONFIG.META_GAP
	local unreadCount = entry.unreadCount or 1
	local countText = ""
	if unreadCount > 1 then
		local displayedCount = mathmin(unreadCount, CONFIG.MAX_DISPLAYED_UNREAD)
		if unreadCount > CONFIG.MAX_DISPLAYED_UNREAD then
			countText = FormatLocalizedText(SI_BPD_UNREAD_COUNT_OVERFLOW, displayedCount)
		else
			countText = FormatLocalizedText(SI_BPD_UNREAD_COUNT, displayedCount)
		end
	end
	card.countLabel:SetText(countText)
	card.closeButton:SetAnchor(RIGHT, card, RIGHT, -CONFIG.CLOSE_BUTTON_INSET, 0)

	local statusText = ""
	local statusColor = CONFIG.MUTED_TEXT_COLOR
	if entry.followUpState == FOLLOW_UP_STATES.ANSWERED then
		statusText = "R"
		statusColor = CONFIG.FOLLOW_UP_ANSWERED_COLOR
	elseif entry.followUpState == FOLLOW_UP_STATES.OVERDUE then
		statusText = "!"
		statusColor = CONFIG.FOLLOW_UP_OVERDUE_COLOR
	elseif entry.followUpState == FOLLOW_UP_STATES.WAITING then
		statusText = "*"
		statusColor = CONFIG.FOLLOW_UP_WAITING_COLOR
	elseif entry.replyOpenedMs ~= nil then
		statusText = "..."
	end
	card.statusLabel:SetText(statusText)
	SetControlColor(card.statusLabel, statusColor)
	local senderTextColor = entry.followUpState == FOLLOW_UP_STATES.ANSWERED
		and CONFIG.MUTED_TEXT_COLOR or CONFIG.SENDER_TEXT_COLOR
	SetControlColor(card.senderLabel, senderTextColor)
	SetControlColor(
		card.messageLabel,
		entry.followUpState == FOLLOW_UP_STATES.ANSWERED
			and CONFIG.MUTED_TEXT_COLOR or CONFIG.MESSAGE_TEXT_COLOR
	)

	if not expanded then
		local textLeft = CONFIG.RAIL_WIDTH + CONFIG.CARD_HORIZONTAL_PADDING
		local timeRight = closeZone
		local countRight = timeRight + CONFIG.COMPACT_TIME_WIDTH + CONFIG.META_GAP
		local statusRight = countRight + CONFIG.COMPACT_COUNT_WIDTH + CONFIG.META_GAP
		local textRight = statusRight + CONFIG.STATUS_WIDTH + CONFIG.META_GAP

		card.senderLabel:SetFont(BuildFont(CONFIG.FONT_FACE, CONFIG.COMPACT_FONT_SIZE))
		card.senderLabel:SetWidth(CONFIG.COMPACT_SENDER_WIDTH)
		card.senderLabel:SetHeight(CONFIG.COMPACT_CARD_HEIGHT)
		card.senderLabel:SetText(Utf8Prefix(entry.senderId, CONFIG.COMPACT_SENDER_CHARACTERS))
		card.senderLabel:SetAnchor(LEFT, card, LEFT, textLeft, 0)
		card.messageLabel:SetFont(BuildFont(CONFIG.FONT_FACE, CONFIG.COMPACT_FONT_SIZE))
		card.messageLabel:SetHeight(CONFIG.COMPACT_CARD_HEIGHT)
		card.messageLabel:SetText(Utf8Prefix(entry.preview, CONFIG.COMPACT_PREVIEW_CHARACTERS))
		card.messageLabel:SetAnchor(LEFT, card.senderLabel, RIGHT, CONFIG.COMPACT_MESSAGE_GAP, 0)
		card.messageLabel:SetAnchor(RIGHT, card, RIGHT, -textRight, 0)

		card.countLabel:SetWidth(CONFIG.COMPACT_COUNT_WIDTH)
		card.countLabel:SetHeight(CONFIG.META_ROW_HEIGHT)
		card.countLabel:SetAnchor(RIGHT, card, RIGHT, -countRight, 0)
		card.statusLabel:SetWidth(CONFIG.STATUS_WIDTH)
		card.statusLabel:SetHeight(CONFIG.META_ROW_HEIGHT)
		card.statusLabel:SetAnchor(RIGHT, card, RIGHT, -statusRight, 0)
		card.timeLabel:SetWidth(CONFIG.COMPACT_TIME_WIDTH)
		card.timeLabel:SetHeight(CONFIG.META_ROW_HEIGHT)
		card.timeLabel:SetAnchor(RIGHT, card, RIGHT, -timeRight, 0)
	else
		local textLeft = CONFIG.RAIL_WIDTH + CONFIG.CARD_HORIZONTAL_PADDING
		local timeRight = closeZone
		local countRight = timeRight + CONFIG.TIME_WIDTH + CONFIG.META_GAP
		local statusRight = countRight + CONFIG.COUNT_WIDTH + CONFIG.META_GAP
		local senderRight = statusRight + CONFIG.STATUS_WIDTH + CONFIG.META_GAP
		local messageRight = CONFIG.CLOSE_BUTTON_INSET + CONFIG.CLOSE_BUTTON_SIZE + CONFIG.META_GAP

		card.senderLabel:SetFont(BuildFont(CONFIG.FONT_FACE_BOLD, CONFIG.SENDER_FONT_SIZE))
		card.senderLabel:SetHeight(CONFIG.SENDER_ROW_HEIGHT)
		card.senderLabel:SetText(Utf8Prefix(entry.senderId, CONFIG.SENDER_DISPLAY_CHARACTERS))
		card.senderLabel:SetAnchor(TOPLEFT, card, TOPLEFT, textLeft, CONFIG.SENDER_ROW_OFFSET_Y)
		card.senderLabel:SetAnchor(TOPRIGHT, card, TOPRIGHT, -senderRight, CONFIG.SENDER_ROW_OFFSET_Y)

		card.countLabel:SetWidth(CONFIG.COUNT_WIDTH)
		card.countLabel:SetHeight(CONFIG.META_ROW_HEIGHT)
		card.countLabel:SetAnchor(TOPRIGHT, card, TOPRIGHT, -countRight, CONFIG.SENDER_ROW_OFFSET_Y + 2)
		card.statusLabel:SetWidth(CONFIG.STATUS_WIDTH)
		card.statusLabel:SetHeight(CONFIG.META_ROW_HEIGHT)
		card.statusLabel:SetAnchor(TOPRIGHT, card, TOPRIGHT, -statusRight, CONFIG.SENDER_ROW_OFFSET_Y + 2)
		card.timeLabel:SetWidth(CONFIG.TIME_WIDTH)
		card.timeLabel:SetHeight(CONFIG.META_ROW_HEIGHT)
		card.timeLabel:SetAnchor(TOPRIGHT, card, TOPRIGHT, -timeRight, CONFIG.SENDER_ROW_OFFSET_Y + 2)
		card.messageLabel:SetFont(BuildFont(CONFIG.FONT_FACE, CONFIG.MESSAGE_FONT_SIZE))
		card.messageLabel:SetText(Utf8Prefix(entry.preview, CONFIG.MESSAGE_PREVIEW_CHARACTERS))
		card.messageLabel:SetHeight(CONFIG.MESSAGE_ROW_HEIGHT)
		card.messageLabel:SetAnchor(TOPLEFT, card, TOPLEFT, textLeft, CONFIG.MESSAGE_ROW_OFFSET_Y)
		card.messageLabel:SetAnchor(TOPRIGHT, card, TOPRIGHT, -messageRight, CONFIG.MESSAGE_ROW_OFFSET_Y)
	end
	card.messageLabel:SetHidden(false)

	card.timeLabel:SetText(FormatElapsed(GetGameTimeMilliseconds() - entry.lastMessageMs))

	if not isLatestRevision then
		self:StopCardPulse(card)
	elseif needsPulseRestart and canShowPulse then
		entry.pulsedRevision = entry.revision
		self:StartCardPulse(card)
	elseif previousSenderId ~= entry.senderId then
		self:StopCardPulse(card)
	end
end

function addon:StartPendingCardPulses()
	if self.headerPulseKind == "reminder"
		and (self.latestReminderSenderId ~= self.headerPulseSenderId
			or self.latestReminderRevision ~= self.headerPulseRevision) then
		self:StopHeaderPulse()
	end

	if self.latestNotificationSenderId == nil and self.latestReminderSenderId == nil then
		self:StopHeaderPulse()
	end

	if not self:IsPanelCollapsed() then
		self:StopHeaderPulse()
	end

	if not self:CanShowArrivalPulse() then
		return
	end

	local senderId = self.latestNotificationSenderId
	local entry = senderId ~= nil and self.notificationsBySender[senderId] or nil
	if entry == nil
		or self.latestNotificationRevision ~= entry.revision
		or entry.pulsedRevision == entry.revision then
		return
	end

	if self:IsPanelCollapsed() then
		entry.pulsedRevision = entry.revision
		self:StartHeaderPulse(ResolveSenderHue(senderId), senderId, entry.revision, "message")
		return
	end

	for _, card in ipairs(self.cards) do
		if card.senderId == senderId and not card:IsHidden() then
			entry.pulsedRevision = entry.revision
			self:StartCardPulse(card)
			return
		end
	end
end

function addon:RefreshNotifications()
	if not self.root then
		return
	end

	self:PruneSenderOrder()
	self:SynchronizeDisplayOrder()
	self:NormalizeOverflowPage()

	local totalSenders = #self.senderOrder
	local presentationOrder = self.displayOrder
	local collapsed = self:IsPanelCollapsed() and totalSenders > 0
	local pageSize = self:GetVisibleSenderLimit()
	local startIndex = ((self.overflowPage or 0) * pageSize) + 1
	local visibleSenders = 0
	if not collapsed then
		visibleSenders = mathmin(mathmax(totalSenders - startIndex + 1, 0), pageSize)
	end

	local offsetY = CONFIG.HEADER_HEIGHT
	if visibleSenders > 0 then
		offsetY = offsetY + CONFIG.HEADER_TO_CARDS_SPACING
	end

	for index, card in ipairs(self.cards) do
		local entry = nil
		if index <= visibleSenders then
			entry = self.notificationsBySender[presentationOrder[startIndex + index - 1]]
		end

		if entry ~= nil then
			local expanded = index == 1
			local cardHeight = expanded and CONFIG.EXPANDED_CARD_HEIGHT or CONFIG.COMPACT_CARD_HEIGHT
			card:ClearAnchors()
			card:SetAnchor(TOPLEFT, self.root, TOPLEFT, 0, offsetY)
			card:SetWidth(CONFIG.PANEL_WIDTH)
			card:SetHeight(cardHeight)
			self:PopulateCard(card, entry, expanded)
			card:SetHidden(false)

			offsetY = offsetY + cardHeight
			if index < visibleSenders then
				offsetY = offsetY + CONFIG.CARD_SPACING
			end
		else
			self:ReleaseCard(card)
		end
	end

	local hiddenSenders = totalSenders - visibleSenders
	if hiddenSenders > 0 and not collapsed then
		offsetY = offsetY + CONFIG.CARD_SPACING
		self.overflow:ClearAnchors()
		self.overflow:SetAnchor(TOPLEFT, self.root, TOPLEFT, 0, offsetY)
		self.overflowLabel:SetText(FormatLocalizedText(SI_BPD_OVERFLOW_SENDERS, hiddenSenders))
		self.overflow:SetHidden(false)
		offsetY = offsetY + CONFIG.OVERFLOW_HEIGHT
	else
		self.overflow:SetHidden(true)
	end

	local totalUnread = 0
	local overdueSenders = 0
	for _, senderId in ipairs(self.senderOrder) do
		local entry = self.notificationsBySender[senderId]
		if entry ~= nil then
			totalUnread = totalUnread + (entry.unreadCount or 0)
			if entry.followUpState == FOLLOW_UP_STATES.OVERDUE then
				overdueSenders = overdueSenders + 1
			end
		end
	end
	local displayedTotalUnread = mathmin(totalUnread, CONFIG.MAX_DISPLAYED_TOTAL_UNREAD)
	if totalUnread > CONFIG.MAX_DISPLAYED_TOTAL_UNREAD and overdueSenders > 0 then
		self.headerCount:SetText(FormatLocalizedText(
			SI_BPD_HEADER_COUNT_OVERFLOW_WITH_OVERDUE,
			totalSenders,
			displayedTotalUnread,
			overdueSenders
		))
	elseif totalUnread > CONFIG.MAX_DISPLAYED_TOTAL_UNREAD then
		self.headerCount:SetText(FormatLocalizedText(
			SI_BPD_HEADER_COUNT_OVERFLOW,
			totalSenders,
			displayedTotalUnread
		))
	elseif overdueSenders > 0 then
		self.headerCount:SetText(FormatLocalizedText(
			SI_BPD_HEADER_COUNT_WITH_OVERDUE,
			totalSenders,
			displayedTotalUnread,
			overdueSenders
		))
	else
		self.headerCount:SetText(FormatLocalizedText(SI_BPD_HEADER_COUNT, totalSenders, displayedTotalUnread))
	end

	self.collapseButton.icon:SetTexture(collapsed and CONFIG.HEADER_EXPAND_TEXTURE or CONFIG.HEADER_COLLAPSE_TEXTURE)
	self.root:SetHeight(offsetY)
	self:UpdateVisibility()
end

function addon:StartFollowUpReminderPulse(control, animation)
	animation:Stop()
	control:SetCenterColor(
		CONFIG.FOLLOW_UP_OVERDUE_COLOR[1],
		CONFIG.FOLLOW_UP_OVERDUE_COLOR[2],
		CONFIG.FOLLOW_UP_OVERDUE_COLOR[3],
		CONFIG.FOLLOW_UP_REMINDER_TINT_ALPHA
	)
	control:SetAlpha(CONFIG.PULSE_MIN_ALPHA)
	animation:PingPong(
		CONFIG.PULSE_MIN_ALPHA,
		CONFIG.FOLLOW_UP_REMINDER_MAX_ALPHA,
		CONFIG.FOLLOW_UP_REMINDER_DURATION_MS,
		CONFIG.FOLLOW_UP_REMINDER_LOOP_COUNT
	)
end

function addon:PlayFollowUpReminderSound()
	if not self:CanPlayOverdueSound() then
		return
	end

	self:PlayNamedSound(CONFIG.FOLLOW_UP_REMINDER_SOUND)
end

function addon:StartPendingFollowUpReminder()
	local senderId = self.latestReminderSenderId
	local entry = senderId ~= nil and self.notificationsBySender[senderId] or nil
	if entry == nil
		or self.latestReminderRevision ~= entry.incomingRevision
		or entry.reminderCueRevision == entry.incomingRevision
		or (entry.unreadCount or 0) == 0 then
		return
	end

	entry.reminderCueRevision = entry.incomingRevision
	if self:IsPanelCollapsed() then
		self.headerPulseSenderId = senderId
		self.headerPulseRevision = entry.incomingRevision
		self.headerPulseKind = "reminder"
		self:StartFollowUpReminderPulse(self.headerPulseBackdrop, self.headerPulseAnimation)
	else
		for _, card in ipairs(self.cards) do
			if card.senderId == senderId and not card:IsHidden() then
				self:StartFollowUpReminderPulse(card.pulseBackdrop, card.pulseAnimation)
				break
			end
		end
	end

	self:PlayFollowUpReminderSound()
end