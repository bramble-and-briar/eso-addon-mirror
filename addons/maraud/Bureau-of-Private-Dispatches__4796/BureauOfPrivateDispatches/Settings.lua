local addon = BureauOfPrivateDispatches
local CONFIG = addon.config
local PANEL_ID = addon.name .. "_Settings"

local GetString = GetString
local stringformat = string.format

function addon:OpenSettingsPanel()
	if self.settingsPanel ~= nil and LibAddonMenu2 ~= nil and type(LibAddonMenu2.OpenToPanel) == "function" then
		LibAddonMenu2:OpenToPanel(self.settingsPanel)
	end
end

function addon:RegisterSettingsPanel()
	local LAM = LibAddonMenu2
	if LAM == nil or type(LAM.RegisterAddonPanel) ~= "function" then
		return false
	end

	local function IsMuted()
		return self:IsMuted()
	end

	local function IsIncomingSoundOn()
		return self.savedVariables == nil or self.savedVariables.incomingSound ~= false
	end

	local function IsOverdueSoundOn()
		return self.savedVariables == nil or self.savedVariables.overdueSound ~= false
	end

	local function IsAutoDndOn()
		return self.savedVariables == nil or self.savedVariables.autoDndInCombat ~= false
	end

	local function IsAutoCollapseOn()
		return self.savedVariables ~= nil and self.savedVariables.autoCollapseInCombat == true
	end

	local function SoundControlsDisabled()
		return IsMuted()
	end

	-- Live at-a-glance dashboard. LAM re-reads function-valued text on panel
	-- open and after any setting change (registerForRefresh). On = the shipped
	-- green, off = the muted label grey, matching the other Bureau panels.
	local STATUS_COLOR_ON = "6FCB9F"
	local STATUS_COLOR_OFF = "8C8A82"

	local function Colorize(colorHex, text)
		return stringformat("|c%s%s|r", colorHex, text)
	end

	local function StatusOnOff(enabled)
		return Colorize(
			enabled and STATUS_COLOR_ON or STATUS_COLOR_OFF,
			GetString(enabled and SI_BPD_STATUS_ON or SI_BPD_STATUS_OFF)
		)
	end

	local function StatusRow(labelKey, valueText)
		return stringformat("%s  %s", GetString(labelKey), valueText)
	end

	local function BuildStatusText()
		local rows =
		{
			StatusRow(SI_BPD_STATUS_LABEL_SOUNDS, StatusOnOff(not IsMuted())),
			StatusRow(SI_BPD_STATUS_LABEL_DND, StatusOnOff(self:IsDndActive())),
			StatusRow(SI_BPD_STATUS_LABEL_AUTO_DND, StatusOnOff(IsAutoDndOn())),
			StatusRow(SI_BPD_STATUS_LABEL_LOCK, StatusOnOff(self:IsPanelLocked())),
			StatusRow(SI_BPD_STATUS_LABEL_AUTOCOLLAPSE, StatusOnOff(IsAutoCollapseOn())),
			StatusRow(SI_BPD_STATUS_LABEL_PCHAT, StatusOnOff(self:UsesPChatPreview())),
		}
		return table.concat(rows, "\n")
	end

	local panelData =
	{
		type = "panel",
		name = GetString(SI_BPD_PANEL_NAME),
		displayName = GetString(SI_BPD_PANEL_DISPLAY_NAME),
		author = "|c6FCB9Fmeshlg|r @ArtieFox",
		version = addon.version,
		slashCommand = "/bpdsettings",
		registerForRefresh = true,
		registerForDefaults = true,
	}

	self.settingsPanel = LAM:RegisterAddonPanel(PANEL_ID, panelData)

	local options =
	{
		{
			type = "description",
			text = GetString(SI_BPD_PANEL_INTRO),
			width = "full",
		},
		{
			type = "description",
			text = GetString(SI_BPD_PANEL_OVERVIEW),
			width = "full",
		},
		{
			type = "description",
			text = GetString(SI_BPD_SLASH_HINT),
			width = "full",
		},
		{
			type = "description",
			title = GetString(SI_BPD_STATUS_TITLE),
			text = BuildStatusText,
			width = "full",
			reference = "BPDSettingsStatusBlock",
		},
		{
			type = "header",
			name = GetString(SI_BPD_HEADER_SOUND),
			width = "full",
		},
		{
			type = "description",
			text = GetString(SI_BPD_SECTION_SOUND_DESCRIPTION),
			width = "full",
		},
		{
			type = "checkbox",
			name = GetString(SI_BPD_SETTINGS_MUTE),
			tooltip = GetString(SI_BPD_SETTINGS_MUTE_TT),
			getFunc = function()
				return IsMuted()
			end,
			setFunc = function(value)
				self:SetMuted(value)
			end,
			default = false,
			width = "full",
			reference = "BPDSettingsMute",
		},
		{
			type = "checkbox",
			name = GetString(SI_BPD_SETTINGS_INCOMING_SOUND),
			tooltip = GetString(SI_BPD_SETTINGS_INCOMING_SOUND_TT),
			getFunc = function()
				return IsIncomingSoundOn()
			end,
			setFunc = function(value)
				self:SetIncomingSound(value)
			end,
			disabled = SoundControlsDisabled,
			default = true,
			width = "full",
			reference = "BPDSettingsIncomingSound",
		},
		{
			type = "checkbox",
			name = GetString(SI_BPD_SETTINGS_OVERDUE_SOUND),
			tooltip = GetString(SI_BPD_SETTINGS_OVERDUE_SOUND_TT),
			getFunc = function()
				return IsOverdueSoundOn()
			end,
			setFunc = function(value)
				self:SetOverdueSound(value)
			end,
			disabled = SoundControlsDisabled,
			default = true,
			width = "full",
			reference = "BPDSettingsOverdueSound",
		},
		{
			type = "header",
			name = GetString(SI_BPD_HEADER_DND),
			width = "full",
		},
		{
			type = "description",
			text = GetString(SI_BPD_SECTION_DND_DESCRIPTION),
			width = "full",
		},
		{
			type = "checkbox",
			name = GetString(SI_BPD_SETTINGS_AUTO_DND),
			tooltip = GetString(SI_BPD_SETTINGS_AUTO_DND_TT),
			getFunc = function()
				return IsAutoDndOn()
			end,
			setFunc = function(value)
				self:SetAutoDndInCombat(value)
			end,
			default = true,
			width = "full",
			reference = "BPDSettingsAutoDnd",
		},
		{
			type = "header",
			name = GetString(SI_BPD_HEADER_PANEL),
			width = "full",
		},
		{
			type = "description",
			text = GetString(SI_BPD_SECTION_PANEL_DESCRIPTION),
			width = "full",
		},
		{
			type = "checkbox",
			name = GetString(SI_BPD_SETTINGS_LOCK),
			tooltip = GetString(SI_BPD_SETTINGS_LOCK_TT),
			getFunc = function()
				return self:IsPanelLocked()
			end,
			setFunc = function(value)
				self:SetPanelLocked(value)
			end,
			default = false,
			width = "full",
			reference = "BPDSettingsLock",
		},
		{
			type = "slider",
			name = GetString(SI_BPD_SETTINGS_SCALE),
			tooltip = GetString(SI_BPD_SETTINGS_SCALE_TT),
			min = CONFIG.PANEL_SCALE_MIN,
			max = CONFIG.PANEL_SCALE_MAX,
			step = 0.05,
			decimals = 2,
			getFunc = function()
				return self:GetPanelScale()
			end,
			setFunc = function(value)
				self:SetPanelScale(value)
			end,
			default = CONFIG.PANEL_SCALE_DEFAULT,
			width = "full",
			reference = "BPDSettingsScale",
		},
		{
			type = "slider",
			name = GetString(SI_BPD_SETTINGS_OPACITY),
			tooltip = GetString(SI_BPD_SETTINGS_OPACITY_TT),
			min = CONFIG.PANEL_OPACITY_MIN,
			max = CONFIG.PANEL_OPACITY_MAX,
			step = 0.05,
			decimals = 2,
			getFunc = function()
				return self:GetPanelOpacity()
			end,
			setFunc = function(value)
				self:SetPanelOpacity(value)
			end,
			default = CONFIG.PANEL_OPACITY_DEFAULT,
			width = "full",
			reference = "BPDSettingsOpacity",
		},
		{
			type = "dropdown",
			name = GetString(SI_BPD_SETTINGS_VISIBLE_SENDERS),
			tooltip = GetString(SI_BPD_SETTINGS_VISIBLE_SENDERS_TT),
			choices = { "6", "8", "12" },
			getFunc = function()
				return tostring(self:GetVisibleSenderLimit())
			end,
			setFunc = function(value)
				self:SetVisibleSenderLimit(tonumber(value))
			end,
			default = tostring(CONFIG.DEFAULT_VISIBLE_SENDERS),
			width = "full",
			reference = "BPDSettingsVisibleSenders",
		},
		{
			type = "checkbox",
			name = GetString(SI_BPD_SETTINGS_AUTOCOLLAPSE),
			tooltip = GetString(SI_BPD_SETTINGS_AUTOCOLLAPSE_TT),
			getFunc = function()
				return IsAutoCollapseOn()
			end,
			setFunc = function(value)
				self:SetAutoCollapseInCombat(value)
			end,
			default = false,
			width = "full",
			reference = "BPDSettingsAutoCollapse",
		},
		{
			type = "button",
			name = GetString(SI_BPD_SETTINGS_RESET_POSITION),
			tooltip = GetString(SI_BPD_SETTINGS_RESET_POSITION_TT),
			func = function()
				self:ResetPosition()
			end,
			width = "half",
			reference = "BPDSettingsResetPosition",
		},
		{
			type = "header",
			name = GetString(SI_BPD_HEADER_FOLLOWUP),
			width = "full",
		},
		{
			type = "description",
			text = GetString(SI_BPD_SECTION_FOLLOWUP_DESCRIPTION),
			width = "full",
		},
		{
			type = "slider",
			name = GetString(SI_BPD_SETTINGS_FOLLOWUP_WAITING),
			tooltip = GetString(SI_BPD_SETTINGS_FOLLOWUP_WAITING_TT),
			min = CONFIG.FOLLOW_UP_WAITING_SECONDS_MIN,
			max = CONFIG.FOLLOW_UP_WAITING_SECONDS_MAX,
			step = 5,
			getFunc = function()
				return self:GetFollowUpWaitingMs() / 1000
			end,
			setFunc = function(value)
				self:SetFollowUpWaitingSeconds(value)
			end,
			default = CONFIG.FOLLOW_UP_WAITING_MS / 1000,
			width = "full",
			reference = "BPDSettingsFollowUpWaiting",
		},
		{
			type = "slider",
			name = GetString(SI_BPD_SETTINGS_FOLLOWUP_OVERDUE),
			tooltip = GetString(SI_BPD_SETTINGS_FOLLOWUP_OVERDUE_TT),
			min = CONFIG.FOLLOW_UP_OVERDUE_SECONDS_MIN,
			max = CONFIG.FOLLOW_UP_OVERDUE_SECONDS_MAX,
			step = 5,
			getFunc = function()
				return self:GetFollowUpOverdueMs() / 1000
			end,
			setFunc = function(value)
				self:SetFollowUpOverdueSeconds(value)
			end,
			default = CONFIG.FOLLOW_UP_OVERDUE_MS / 1000,
			width = "full",
			reference = "BPDSettingsFollowUpOverdue",
		},
		{
			type = "slider",
			name = GetString(SI_BPD_SETTINGS_FOLLOWUP_GRACE),
			tooltip = GetString(SI_BPD_SETTINGS_FOLLOWUP_GRACE_TT),
			min = CONFIG.FOLLOW_UP_REPLY_GRACE_SECONDS_MIN,
			max = CONFIG.FOLLOW_UP_REPLY_GRACE_SECONDS_MAX,
			step = 5,
			getFunc = function()
				return self:GetFollowUpReplyGraceMs() / 1000
			end,
			setFunc = function(value)
				self:SetFollowUpReplyGraceSeconds(value)
			end,
			default = CONFIG.FOLLOW_UP_REPLY_GRACE_MS / 1000,
			width = "full",
			reference = "BPDSettingsFollowUpGrace",
		},
		{
			type = "slider",
			name = GetString(SI_BPD_SETTINGS_FOLLOWUP_ANSWERED),
			tooltip = GetString(SI_BPD_SETTINGS_FOLLOWUP_ANSWERED_TT),
			min = CONFIG.FOLLOW_UP_ANSWERED_VISIBLE_SECONDS_MIN,
			max = CONFIG.FOLLOW_UP_ANSWERED_VISIBLE_SECONDS_MAX,
			step = 1,
			getFunc = function()
				return self:GetFollowUpAnsweredVisibleMs() / 1000
			end,
			setFunc = function(value)
				self:SetFollowUpAnsweredVisibleSeconds(value)
			end,
			default = CONFIG.FOLLOW_UP_ANSWERED_VISIBLE_MS / 1000,
			width = "full",
			reference = "BPDSettingsFollowUpAnswered",
		},
		{
			type = "header",
			name = GetString(SI_BPD_HEADER_RESTORE),
			width = "full",
		},
		{
			type = "description",
			text = GetString(SI_BPD_SECTION_RESTORE_DESCRIPTION),
			width = "full",
		},
		{
			type = "checkbox",
			name = GetString(SI_BPD_SETTINGS_PCHAT_PREVIEW),
			tooltip = GetString(SI_BPD_SETTINGS_PCHAT_PREVIEW_TT),
			getFunc = function()
				return self:UsesPChatPreview()
			end,
			setFunc = function(value)
				self:SetUsePChatPreview(value)
			end,
			default = true,
			width = "full",
			reference = "BPDSettingsPChatPreview",
		},
		{
			type = "header",
			name = GetString(SI_BPD_HEADER_NOTES),
			width = "full",
		},
		{
			type = "description",
			text = GetString(SI_BPD_SECTION_GESTURES_DESCRIPTION),
			width = "full",
		},
		{
			type = "description",
			text = GetString(SI_BPD_SECTION_BADGES_DESCRIPTION),
			width = "full",
		},
		{
			type = "description",
			text = GetString(SI_BPD_SECTION_KEYBINDS_DESCRIPTION),
			width = "full",
		},
	}

	LAM:RegisterOptionControls(PANEL_ID, options)
	return true
end
