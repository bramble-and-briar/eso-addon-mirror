local QTI = QuestTrackerImproved

local TIMER_ICON = "|t24:24:esoui/art/miscellaneous/timer_32.dds|t"
local DYNAMIC_EVENT_ICON = "/esoui/art/icons/mapkey/mapkey_dynamic_world_event.dds"

function QTI.GetDynamicEventsTrackerControls()
	local tracker = DYNAMIC_EVENTS_TRACKER
	return tracker.container:GetNamedChild("Header"),
		   tracker.container:GetNamedChild("SubLabel")
end

function QTI.GetOrCreateDynamicEventsHeaderIcon(tracker)
	if tracker.QTI_icon then return tracker.QTI_icon end

	local icon = WINDOW_MANAGER:CreateControl(nil, tracker.container, CT_TEXTURE)
	icon:SetTexture(DYNAMIC_EVENT_ICON)
	icon:SetDimensions(QTI.SV.dynamicEventsIconSize, QTI.SV.dynamicEventsIconSize)
	icon:SetHidden(true)
	tracker.QTI_icon = icon
	return icon
end

function QTI.ApplyDynamicEventsStyle()
	local header, subLabel = QTI.GetDynamicEventsTrackerControls()

	header:SetFont(QTI.GetFont(
		QTI.SV.dynamicEventsHeaderFont,
		QTI.SV.dynamicEventsHeaderSize,
		QTI.SV.dynamicEventsHeaderStyle))
	QTI.ApplyControlColor(header, QTI.SV.dynamicEventsHeaderColor)
	QTI.ApplyTextAlignment(header)

	subLabel:SetFont(QTI.GetFont(
		QTI.SV.dynamicEventsSubLabelFont,
		QTI.SV.dynamicEventsSubLabelSize,
		QTI.SV.dynamicEventsSubLabelStyle))
	QTI.ApplyControlColor(subLabel, QTI.SV.dynamicEventsSubLabelColor)
	QTI.ApplyTextAlignment(subLabel)
end

function QTI.ApplyDynamicEventsAlignment()
	local tracker = DYNAMIC_EVENTS_TRACKER
	local width = QTI.SV.dynamicEventsWidth
	local iconSize = QTI.SV.dynamicEventsIconSize
	local icon = QTI.GetOrCreateDynamicEventsHeaderIcon(tracker)

	tracker.container:SetWidth(width)

	local header, subLabel = QTI.GetDynamicEventsTrackerControls()

	local headerOffset = iconSize + 6
	local textWidth = width - headerOffset

	local headerHeight = header:GetTextHeight()
	if headerHeight == 0 then headerHeight = iconSize end

	local styleOffset = (QTI.SV.dynamicEventsHeaderStyle == "thick-outline") and 4 or 0

	local iconOffsetY	= math.max(0, (headerHeight - iconSize) / 2)
	local headerOffsetY = math.max(0, (iconSize - headerHeight) / 2) + styleOffset

	icon:SetDimensions(iconSize, iconSize)
	icon:ClearAnchors()
	icon:SetAnchor(TOPLEFT, tracker.container, TOPLEFT, 0, iconOffsetY)

	header:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
	header:SetWidth(textWidth)
	header:ClearAnchors()
	header:SetAnchor(TOPLEFT, tracker.container, TOPLEFT, headerOffset, headerOffsetY)

	subLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
	subLabel:SetWidth(textWidth)
	subLabel:ClearAnchors()
	subLabel:SetAnchor(TOPLEFT, header, BOTTOMLEFT, 0, 2)

	local progressBar = tracker.progressBar
	if progressBar then
		progressBar:SetWidth(textWidth)
		progressBar:ClearAnchors()
		progressBar:SetAnchor(TOPLEFT, subLabel, BOTTOMLEFT, 0, 2)
	end

	if tracker.timerText and tracker.timerLabel then
		local anchorTarget = (progressBar and not progressBar:IsHidden()) and progressBar or subLabel

		tracker.timerText:ClearAnchors()
		tracker.timerText:SetAnchor(TOPLEFT, anchorTarget, BOTTOMLEFT, 0, 2)

		tracker.timerLabel:ClearAnchors()
		tracker.timerLabel:SetAnchor(LEFT, tracker.timerText, RIGHT, 4, 0)

		tracker.timerText:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
		tracker.timerLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
	end
end

function QTI.HookDynamicEventsTracker()
	ZO_PreHook(ZO_DynamicEventsTracker, "RefreshAnchors", function(self)
		local style = self.currentStyle
		self:RefreshAnchorSetOnControl(self.container, style.CONTAINER_PRIMARY_ANCHOR, style.CONTAINER_SECONDARY_ANCHOR)
		QTI.ApplyDynamicEventsAlignment()
		return true
	end)

	ZO_PostHook(ZO_DynamicEventsTracker, "RefreshProgress", function(self)
		QTI.ApplyDynamicEventsAlignment()
	end)

	ZO_PostHook(ZO_DynamicEventsTracker, "Update", function(self)
		if self.expireTimeS ~= 0 then
			self.timerText:SetText(TIMER_ICON)
			self.timerText:SetWidth(24)
		end

		local icon = QTI.GetOrCreateDynamicEventsHeaderIcon(self)
		icon:SetHidden(not (self.worldEventInstanceId and self.worldEventInstanceId ~= 0))

		QTI.ApplyDynamicEventsStyle()
		QTI.ApplyDynamicEventsAlignment()
	end)

	ZO_PostHook(ZO_DynamicEventsTracker, "RefreshTimer", function(self)
		if self.expireTimeS ~= 0 then
			local secondsRemaining = zo_max(self.expireTimeS - GetTimeStamp(), 0)
			self.timerLabel:SetText(ZO_FormatTime(
				secondsRemaining,
				TIME_FORMAT_STYLE_COLONS,
				TIME_FORMAT_PRECISION_SECONDS,
				TIME_FORMAT_DIRECTION_DESCENDING))
		end
	end)

	ZO_PostHook(ZO_DynamicEventsTracker, "ApplyPlatformStyle", function(self)
		QTI.ApplyDynamicEventsStyle()
		QTI.ApplyDynamicEventsAlignment()
	end)

	QTI.ApplyDynamicEventsStyle()
	QTI.ApplyDynamicEventsAlignment()
end

function QTI.ResizeDynamicEventsPanel()
	DYNAMIC_EVENTS_TRACKER.container:SetWidth(QTI.SV.dynamicEventsWidth)
end