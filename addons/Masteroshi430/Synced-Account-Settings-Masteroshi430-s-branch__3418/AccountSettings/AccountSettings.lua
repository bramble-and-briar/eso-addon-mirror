-- AccountSettings basics {{{
AccountSettings = {}

AccountSettings.name = "AccountSettings"
AccountSettings.version = 3.0
AccountSettings.savedName = "AccountSettings_SV"
AccountSettings.displayName = "|cff8555Account Settings|r"
AccountSettings.str = ""

AccountSettings.Default = {}
AccountSettings.Default.sync = true
AccountSettings.Default.shareKeybinds = true
AccountSettings.Default.log = false
AccountSettings.Default.debug = false
AccountSettings.Default.settings = {}
AccountSettings.Default.allSettings = {}
AccountSettings.Default.settingsBool = {}
AccountSettings.Default.chatColors = {}
AccountSettings.Default.tracked = false
AccountSettings.Default.showChatIcon = true
AccountSettings.Default.chatSettingsAddon = "Synced Account Settings"

AccountSettings.OKAY_COLOR = "44ff44"
AccountSettings.ERROR_COLOR = "ff4444"
AccountSettings.DEBUG_COLOR = "ffff44"
AccountSettings.NAME_COLOR = "ffffff"

-- End AccountSettings basics }}}

local function IsAccessibilityModeEnabled()
    return GetSetting_Bool(SETTING_TYPE_ACCESSIBILITY, ACCESSIBILITY_SETTING_ACCESSIBILITY_MODE)
end

-- ESO Settings {{{
AccountSettings.ChatColors = {
    CHAT_CATEGORY_COMBAT_ALLIANCE_POINTS,
    CHAT_CATEGORY_COMBAT_BLOCK_ABSORBED_DEFEND,
    CHAT_CATEGORY_COMBAT_DEATH,
    CHAT_CATEGORY_COMBAT_DIRECT_DAMAGE,
    CHAT_CATEGORY_COMBAT_DIRECT_HEAL,
    CHAT_CATEGORY_COMBAT_DODGE_PARRY_MISS,
    CHAT_CATEGORY_COMBAT_DOT,
    CHAT_CATEGORY_COMBAT_DRAIN,
    CHAT_CATEGORY_COMBAT_ENERGIZE,
    CHAT_CATEGORY_COMBAT_EXPERIENCE,
    CHAT_CATEGORY_COMBAT_GAINED_EFFECT,
    CHAT_CATEGORY_COMBAT_HOT,
    CHAT_CATEGORY_COMBAT_LOST_EFFECT,
    CHAT_CATEGORY_COMBAT_OTHER,
    CHAT_CATEGORY_COMBAT_RANK_POINTS,
    CHAT_CATEGORY_COMBAT_RESIST,
    CHAT_CATEGORY_COMBAT_TELVAR_STONES,
    CHAT_CATEGORY_EMOTE,
    CHAT_CATEGORY_GUILD_1,
    CHAT_CATEGORY_GUILD_2,
    CHAT_CATEGORY_GUILD_3,
    CHAT_CATEGORY_GUILD_4,
    CHAT_CATEGORY_GUILD_5,
    CHAT_CATEGORY_MONSTER_EMOTE,
    CHAT_CATEGORY_MONSTER_SAY,
    CHAT_CATEGORY_MONSTER_WHISPER,
    CHAT_CATEGORY_MONSTER_YELL,
    CHAT_CATEGORY_OFFICER_1,
    CHAT_CATEGORY_OFFICER_2,
    CHAT_CATEGORY_OFFICER_3,
    CHAT_CATEGORY_OFFICER_4,
    CHAT_CATEGORY_OFFICER_5,
    CHAT_CATEGORY_PARTY,
    CHAT_CATEGORY_SAY,
    CHAT_CATEGORY_SYSTEM,
    CHAT_CATEGORY_WHISPER_INCOMING,
    CHAT_CATEGORY_WHISPER_OUTGOING,
    CHAT_CATEGORY_YELL,
    CHAT_CATEGORY_ZONE,
    CHAT_CATEGORY_ZONE_ENGLISH,
    CHAT_CATEGORY_ZONE_FRENCH,
    CHAT_CATEGORY_ZONE_GERMAN,
    CHAT_CATEGORY_ZONE_JAPANESE,
    CHAT_CATEGORY_ZONE_RUSSIAN,
    CHAT_CATEGORY_ZONE_SPANISH,
	CHAT_CATEGORY_ZONE_CHINESE_S,
}

AccountSettings.SettingSystemType = { -- Acessibility, audio, gamepad, graphics are global and I disabled them 

    
	
    --SETTING_TYPE_ACCESSIBILITY,
	--SETTING_TYPE_ACCOUNT,
	SETTING_TYPE_ACTION_BARS,
    SETTING_TYPE_ACTIVE_COMBAT_TIP,
    --SETTING_TYPE_AUDIO,
    SETTING_TYPE_BUFFS,
    SETTING_TYPE_CAMERA,
    SETTING_TYPE_CHAT_BUBBLE,
	--SETTING_TYPE_CHAT_GLOBALS,
	--SETTING_TYPE_CHAT_TABS,
    SETTING_TYPE_COMBAT,
	  --SETTING_TYPE_CUSTOM,
	--SETTING_TYPE_DEVELOPER_DEBUG,
    --SETTING_TYPE_GAMEPAD,
    --SETTING_TYPE_GRAPHICS,
    SETTING_TYPE_IN_WORLD,
    SETTING_TYPE_LANGUAGE,
    SETTING_TYPE_LOOT,
    SETTING_TYPE_NAMEPLATES,
    SETTING_TYPE_SUBTITLES,
    SETTING_TYPE_TUTORIAL,
    SETTING_TYPE_UI,
	--SETTING_TYPE_VOICE,
}



AccountSettings.AllSettingSystemType = { -- Used to save everything 

    SETTING_TYPE_ACCESSIBILITY,
	SETTING_TYPE_ACCOUNT,
	SETTING_TYPE_ACTION_BARS,
    SETTING_TYPE_ACTIVE_COMBAT_TIP,
    SETTING_TYPE_AUDIO,
    SETTING_TYPE_BUFFS,
    SETTING_TYPE_CAMERA,
    SETTING_TYPE_CHAT_BUBBLE,
	--SETTING_TYPE_CHAT_GLOBALS,
	--SETTING_TYPE_CHAT_TABS,
    SETTING_TYPE_COMBAT,
	--SETTING_TYPE_CUSTOM,
	--SETTING_TYPE_DEVELOPER_DEBUG,
    SETTING_TYPE_GAMEPAD,
    SETTING_TYPE_GRAPHICS,
    SETTING_TYPE_IN_WORLD,
    SETTING_TYPE_LANGUAGE,
    SETTING_TYPE_LOOT,
    SETTING_TYPE_NAMEPLATES,
    SETTING_TYPE_SUBTITLES,
    SETTING_TYPE_TUTORIAL,
    SETTING_TYPE_UI,
	--SETTING_TYPE_VOICE,
}

AccountSettings.SettingPanelTypeString = {
  [SETTING_PANEL_VIDEO    ] = SI_SETTINGSYSTEMPANEL1,
	[SETTING_PANEL_AUDIO    ] = SI_SETTINGSYSTEMPANEL0,
	[SETTING_PANEL_GAMEPLAY    ] = SI_SETTINGSYSTEMPANEL4,
  [SETTING_PANEL_CAMERA    ] = SI_SETTINGSYSTEMPANEL2,
	[SETTING_PANEL_INTERFACE   ] = SI_SETTINGSYSTEMPANEL3,
	[SETTING_PANEL_NAMEPLATES ] = SI_SETTINGSYSTEMPANEL8,
	[SETTING_PANEL_SOCIAL ] = SI_SETTINGSYSTEMPANEL5,
	[SETTING_PANEL_COMBAT ] = SI_SETTINGSYSTEMPANEL9,
	[SETTING_PANEL_ACCESSIBILITY ] = SI_SETTINGSYSTEMPANEL11,
	[SETTING_PANEL_ACCOUNT] = SI_SETTINGSYSTEMPANEL10,
	[SETTING_PANEL_CINEMATIC] = SI_SETTINGSYSTEMPANEL7,
	[SETTING_PANEL_DEBUG] = SI_SETTINGSYSTEMPANEL6,
}


AccountSettings.SettingSystemTypeString = {
  [SETTING_TYPE_ACCESSIBILITY    ] = SI_SETTINGSYSTEMPANEL11,
	[SETTING_TYPE_ACCOUNT          ] = SI_SETTINGSYSTEMPANEL10,
	[SETTING_TYPE_ACTION_BARS      ] = SI_GAMEPAD_SKILLS_ACTIONBAR_HEADER,
	[SETTING_TYPE_ACTIVE_COMBAT_TIP] = SI_INTERFACE_OPTIONS_ACT_SETTING_LABEL,
  [SETTING_TYPE_AUDIO            ] = SI_SETTINGSYSTEMPANEL0,
  [SETTING_TYPE_BUFFS            ] = SI_BUFFS_OPTIONS_SECTION_TITLE,
  [SETTING_TYPE_CAMERA           ] = SI_SETTINGSYSTEMPANEL2,
  [SETTING_TYPE_CHAT_BUBBLE      ] = SI_INTERFACE_OPTIONS_CHAT_BUBBLES,
	[SETTING_TYPE_CHAT_GLOBALS     ] = SI_CHAT_TAB_GENERAL,
	[SETTING_TYPE_CHAT_TABS        ] = "SETTING_TYPE_CHAT_TABS",
  [SETTING_TYPE_COMBAT           ] = SI_SETTINGSYSTEMPANEL9,
	[SETTING_TYPE_DEVELOPER_DEBUG  ] = SI_SETTINGSYSTEMPANEL6,
  [SETTING_TYPE_GAMEPAD          ] = SI_GAMEPAD_SECTION_HEADER,
  [SETTING_TYPE_GRAPHICS         ] = SI_GRAPHICS_OPTIONS_VIDEO_CATEGORY_DISPLAY,
  [SETTING_TYPE_IN_WORLD         ] = SI_GAMEPLAY_OPTIONS_GENERAL,
  [SETTING_TYPE_LANGUAGE         ] = SI_SOCIAL_OPTIONS_CHAT_SETTINGS,
  [SETTING_TYPE_LOOT             ] = SI_GAMEPLAY_OPTIONS_ITEMS,
  [SETTING_TYPE_NAMEPLATES       ] = SI_INTERFACE_OPTIONS_NAMEPLATES,
  [SETTING_TYPE_SUBTITLES        ] = SI_AUDIO_OPTIONS_SUBTITLES,
  [SETTING_TYPE_TUTORIAL         ] = SI_INTERFACE_OPTIONS_TOOLTIPS_TUTORIAL_ENABLED,
  [SETTING_TYPE_UI               ] = SI_SETTINGSYSTEMPANEL3,
	[SETTING_TYPE_VOICE            ] = SI_MAIN_MENU_GAMEPAD_VOICECHAT,
	[SETTING_TYPE_CUSTOM           ] = SI_GRAPHICSPRESETS7,
}

AccountSettings.SettingIds = {

   [SETTING_TYPE_ACTIVE_COMBAT_TIP] =
    {
        --Options_Interface_ActiveCombatTips
        [0] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_ACTIVE_COMBAT_TIP,
            panel = SETTING_PANEL_COMBAT,
            settingId = 0, -- TODO: make an enum for this, or merge it with another setting type
            text = SI_INTERFACE_OPTIONS_ACT_SETTING_LABEL,
            tooltipText = SI_INTERFACE_OPTIONS_ACT_SETTING_LABEL_TOOLTIP,
            valid = {ACT_SETTING_OFF, ACT_SETTING_AUTO, ACT_SETTING_ALWAYS,},
            valueStringPrefix = "SI_ACTIVECOMBATTIPSETTING",
        },
    },

   [SETTING_TYPE_ACTION_BARS] =
    {
      [ACTION_BAR_SETTING_LOCK_ACTION_BARS] =
	  {
	        system = SETTING_TYPE_ACTION_BARS,
            settingId = ACTION_BAR_SETTING_LOCK_ACTION_BARS,
            text = SI_GAMEPAD_SKILLS_ACTIONBAR_HEADER,
            tooltipText = SI_GAMEPAD_SKILLS_MANAGE_ACTIONBAR,
	  },
	  
    },



   [SETTING_TYPE_ACCESSIBILITY] =
    {
        -- Options_Accessibility_AccessibilityMode
        [ACCESSIBILITY_SETTING_ACCESSIBILITY_MODE] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_ACCESSIBILITY,
            settingId = ACCESSIBILITY_SETTING_ACCESSIBILITY_MODE,
            panel = SETTING_PANEL_ACCESSIBILITY,
            text = SI_ACCESSIBILITY_OPTIONS_ACCESSIBILITY_MODE,
            tooltipText = SI_ACCESSIBILITY_OPTIONS_ACCESSIBILITY_MODE_TOOLTIP,
            events =
            {
                [true] = "OnAccessibilityModeEnabled",
                [false] = "OnAccessibilityModeDisabled",
            },
            gamepadHasEnabledDependencies = true,
        },
        -- -- Options_Accessibility_VoiceChatAccessibility
        -- [ACCESSIBILITY_SETTING_VOICE_CHAT_ACCESSIBILITY] =
        -- {
            -- controlType = OPTIONS_CHECKBOX,
            -- system = SETTING_TYPE_ACCESSIBILITY,
            -- settingId = ACCESSIBILITY_SETTING_VOICE_CHAT_ACCESSIBILITY,
            -- panel = SETTING_PANEL_ACCESSIBILITY,
            -- text = SI_ACCESSIBILITY_OPTIONS_VOICE_CHAT_ACCESSIBILITY,
            -- tooltipText = SI_ACCESSIBILITY_OPTIONS_VOICE_CHAT_ACCESSIBILITY_TOOLTIP,
            -- exists = IsConsoleUI,
            -- eventCallbacks =
            -- {
                -- ["OnAccessibilityModeEnabled"] = ZO_Options_SetOptionActive,
                -- ["OnAccessibilityModeDisabled"] = ZO_Options_SetOptionInactive,
            -- },
            -- enabled = IsAccessibilityModeEnabled(),
            -- gamepadIsEnabledCallback = IsAccessibilityModeEnabled(),
            -- gamepadCustomTooltipFunction = function(tooltip)
                -- GAMEPAD_TOOLTIPS:LayoutSettingAccessibilityTooltipWarning(tooltip, GetString(SI_ACCESSIBILITY_OPTIONS_VOICE_CHAT_ACCESSIBILITY_TOOLTIP), GetString(SI_OPTIONS_ACCESSIBILITY_MODE_REQUIRED_WARNING), not IsAccessibilityModeEnabled())
            -- end,
        -- },
        -- Options_Accessibility_TextChatNarration
        [ACCESSIBILITY_SETTING_TEXT_CHAT_NARRATION] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_ACCESSIBILITY,
            settingId = ACCESSIBILITY_SETTING_TEXT_CHAT_NARRATION,
            panel = SETTING_PANEL_ACCESSIBILITY,
            text = SI_ACCESSIBILITY_OPTIONS_TEXT_CHAT_NARRATION,
            tooltipText = SI_ACCESSIBILITY_OPTIONS_TEXT_CHAT_NARRATION_TOOLTIP,
            events =
            {
                [true] = "OnTextChatNarrationEnabled",
                [false] = "OnTextChatNarrationDisabled",
            },
            gamepadHasEnabledDependencies = true,
            exists = IsChatSystemAvailableForCurrentPlatform,
            eventCallbacks =
            {
                ["OnAccessibilityModeEnabled"] = ZO_Options_UpdateOption,
                ["OnAccessibilityModeDisabled"] = ZO_Options_UpdateOption,
            },
            enabled = IsAccessibilityModeEnabled(),
            gamepadIsEnabledCallback = IsAccessibilityModeEnabled(),
            gamepadCustomTooltipFunction = function(tooltip)
                GAMEPAD_TOOLTIPS:LayoutSettingAccessibilityTooltipWarning(tooltip, GetString(SI_ACCESSIBILITY_OPTIONS_TEXT_CHAT_NARRATION_TOOLTIP), GetString(SI_OPTIONS_ACCESSIBILITY_MODE_REQUIRED_WARNING), not IsAccessibilityModeEnabled())
            end,
        },
        -- Options_Accessibility_ZoneChatNarration
        [ACCESSIBILITY_SETTING_ZONE_CHAT_NARRATION] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_ACCESSIBILITY,
            settingId = ACCESSIBILITY_SETTING_ZONE_CHAT_NARRATION,
            panel = SETTING_PANEL_ACCESSIBILITY,
            text = SI_ACCESSIBILITY_OPTIONS_ZONE_CHAT_NARRATION,
            tooltipText = SI_ACCESSIBILITY_OPTIONS_ZONE_CHAT_NARRATION_TOOLTIP,
            exists = IsChatSystemAvailableForCurrentPlatform,
            eventCallbacks =
            {
                ["OnAccessibilityModeEnabled"] = ZO_Options_UpdateOption,
                ["OnAccessibilityModeDisabled"] = ZO_Options_UpdateOption,
                ["OnTextChatNarrationEnabled"] = ZO_Options_UpdateOption,
                ["OnTextChatNarrationDisabled"] = ZO_Options_UpdateOption,
            },
            enabled = IsTextChatNarrationEnabled,
            gamepadIsEnabledCallback = IsTextChatNarrationEnabled,
            gamepadCustomTooltipFunction = function(tooltip)
                local shouldDisplayWarning = not IsAccessibilityModeEnabled() or not IsTextChatNarrationEnabled()
                local warningText = IsAccessibilityModeEnabled() and GetString(SI_OPTIONS_TEXT_CHAT_NARRATION_REQUIRED_WARNING) or GetString(SI_OPTIONS_ACCESSIBILITY_MODE_REQUIRED_WARNING)
                GAMEPAD_TOOLTIPS:LayoutSettingAccessibilityTooltipWarning(tooltip, GetString(SI_ACCESSIBILITY_OPTIONS_ZONE_CHAT_NARRATION_TOOLTIP), warningText, shouldDisplayWarning)
            end,
        },
        -- Options_Accessibility_ScreenNarration
        [ACCESSIBILITY_SETTING_SCREEN_NARRATION] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_ACCESSIBILITY,
            settingId = ACCESSIBILITY_SETTING_SCREEN_NARRATION,
            panel = SETTING_PANEL_ACCESSIBILITY,
            text = SI_ACCESSIBILITY_OPTIONS_SCREEN_NARRATION,
            tooltipText = SI_ACCESSIBILITY_OPTIONS_SCREEN_NARRATION_TOOLTIP,
            eventCallbacks =
            {
                ["OnAccessibilityModeEnabled"] = ZO_Options_UpdateOption,
                ["OnAccessibilityModeDisabled"] = ZO_Options_UpdateOption,
            },
            enabled = IsAccessibilityModeEnabled(),
            gamepadIsEnabledCallback = IsAccessibilityModeEnabled(),
            gamepadCustomTooltipFunction = function(tooltip)
                GAMEPAD_TOOLTIPS:LayoutSettingAccessibilityTooltipWarning(tooltip, GetString(SI_ACCESSIBILITY_OPTIONS_SCREEN_NARRATION_TOOLTIP), GetString(SI_OPTIONS_ACCESSIBILITY_MODE_REQUIRED_WARNING), not IsAccessibilityModeEnabled())
            end,
        },
		
        -- Options_Accessibility_TextInputNarration
        [ACCESSIBILITY_SETTING_TEXT_INPUT_NARRATION] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_ACCESSIBILITY,
            settingId = ACCESSIBILITY_SETTING_TEXT_INPUT_NARRATION,
            panel = SETTING_PANEL_ACCESSIBILITY,
            text = SI_ACCESSIBILITY_OPTIONS_TEXT_INPUT_NARRATION,
            tooltipText = SI_ACCESSIBILITY_OPTIONS_TEXT_INPUT_NARRATION_TOOLTIP,
            eventCallbacks =
            {
                ["OnAccessibilityModeEnabled"] = ZO_Options_UpdateOption,
                ["OnAccessibilityModeDisabled"] = ZO_Options_UpdateOption,
                ["OnScreenNarrationEnabled"] = ZO_Options_UpdateOption,
                ["OnScreenNarrationDisabled"] = ZO_Options_UpdateOption,
            },
            enabled = IsScreenNarrationEnabled,
            gamepadIsEnabledCallback = IsScreenNarrationEnabled,
            gamepadCustomTooltipFunction = function(tooltip)
                local shouldDisplayWarning = not IsAccessibilityModeEnabled() or not IsScreenNarrationEnabled()
                local warningText = IsAccessibilityModeEnabled() and GetString(SI_OPTIONS_SCREEN_NARRATION_REQUIRED_WARNING) or GetString(SI_OPTIONS_ACCESSIBILITY_MODE_REQUIRED_WARNING)
                GAMEPAD_TOOLTIPS:LayoutSettingAccessibilityTooltipWarning(tooltip, GetString(SI_ACCESSIBILITY_OPTIONS_TEXT_INPUT_NARRATION_TOOLTIP), warningText, shouldDisplayWarning)
            end,
        },
        -- Options_Accessibility_NarrationVolume
        [ACCESSIBILITY_SETTING_NARRATION_VOLUME] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_ACCESSIBILITY,
            settingId = ACCESSIBILITY_SETTING_NARRATION_VOLUME,
            panel = SETTING_PANEL_ACCESSIBILITY,
            text = SI_ACCESSIBILITY_OPTIONS_NARRATION_VOLUME,
            tooltipText = SI_ACCESSIBILITY_OPTIONS_NARRATION_VOLUME_TOOLTIP,
            minValue = 0,
            maxValue = 100,
            showValue = true,
            eventCallbacks =
            {
                ["OnAccessibilityModeEnabled"] = ZO_Options_UpdateOption,
                ["OnAccessibilityModeDisabled"] = ZO_Options_UpdateOption,
            },
            enabled = IsAccessibilityModeEnabled(),
            gamepadIsEnabledCallback = IsAccessibilityModeEnabled(),
            gamepadCustomTooltipFunction = function(tooltip)
                GAMEPAD_TOOLTIPS:LayoutSettingAccessibilityTooltipWarning(tooltip, GetString(SI_ACCESSIBILITY_OPTIONS_NARRATION_VOLUME_TOOLTIP), GetString(SI_OPTIONS_ACCESSIBILITY_MODE_REQUIRED_WARNING), not IsAccessibilityModeEnabled())
            end,
        },
        -- Options_Accessibility_NarrationVoiceSpeed
        [ACCESSIBILITY_SETTING_NARRATION_VOICE_SPEED] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_ACCESSIBILITY,
            settingId = ACCESSIBILITY_SETTING_NARRATION_VOICE_SPEED,
            panel = SETTING_PANEL_ACCESSIBILITY,
            text = SI_ACCESSIBILITY_OPTIONS_NARRATION_VOICE_SPEED,
            tooltipText = SI_ACCESSIBILITY_OPTIONS_NARRATION_VOICE_SPEED_TOOLTIP,
            valid = {NARRATION_VOICE_SPEED_NORMAL, NARRATION_VOICE_SPEED_FAST, NARRATION_VOICE_SPEED_EXTRA_FAST, },
            valueStringPrefix = "SI_NARRATIONVOICESPEED",
            eventCallbacks =
            {
                ["OnAccessibilityModeEnabled"] = ZO_Options_UpdateOption,
                ["OnAccessibilityModeDisabled"] = ZO_Options_UpdateOption,
            },
            enabled = IsAccessibilityModeEnabled(),
            gamepadIsEnabledCallback = IsAccessibilityModeEnabled(),
            gamepadCustomTooltipFunction = function(tooltip)
                GAMEPAD_TOOLTIPS:LayoutSettingAccessibilityTooltipWarning(tooltip, GetString(SI_ACCESSIBILITY_OPTIONS_NARRATION_VOICE_SPEED_TOOLTIP), GetString(SI_OPTIONS_ACCESSIBILITY_MODE_REQUIRED_WARNING), not IsAccessibilityModeEnabled())
            end,
        },
        -- Options_Accessibility_NarrationVoiceType
        [ACCESSIBILITY_SETTING_NARRATION_VOICE_TYPE] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_ACCESSIBILITY,
            settingId = ACCESSIBILITY_SETTING_NARRATION_VOICE_TYPE,
            panel = SETTING_PANEL_ACCESSIBILITY,
            text = SI_ACCESSIBILITY_OPTIONS_NARRATION_VOICE_TYPE,
            tooltipText = SI_ACCESSIBILITY_OPTIONS_NARRATION_VOICE_TYPE_TOOLTIP,
            valid = { NARRATION_VOICE_TYPE_FEMALE, NARRATION_VOICE_TYPE_MALE, },
            valueStringPrefix = "SI_NARRATIONVOICETYPE",
            eventCallbacks =
            {
                ["OnAccessibilityModeEnabled"] = ZO_Options_UpdateOption,
                ["OnAccessibilityModeDisabled"] = ZO_Options_UpdateOption,
            },
            enabled = IsAccessibilityModeEnabled(),
            gamepadIsEnabledCallback = IsAccessibilityModeEnabled(),
            gamepadCustomTooltipFunction = function(tooltip)
                GAMEPAD_TOOLTIPS:LayoutSettingAccessibilityTooltipWarning(tooltip, GetString(SI_ACCESSIBILITY_OPTIONS_NARRATION_VOICE_TYPE_TOOLTIP), GetString(SI_OPTIONS_ACCESSIBILITY_MODE_REQUIRED_WARNING), not IsAccessibilityModeEnabled())
            end,
        },
        -- Options_Accessibility_AccessibleQuickwheels
        [ACCESSIBILITY_SETTING_ACCESSIBLE_QUICKWHEELS] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_ACCESSIBILITY,
            settingId = ACCESSIBILITY_SETTING_ACCESSIBLE_QUICKWHEELS,
            panel = SETTING_PANEL_ACCESSIBILITY,
            text = SI_ACCESSIBILITY_OPTIONS_ACCESSIBLE_QUICKWHEELS,
            tooltipText = SI_ACCESSIBILITY_OPTIONS_ACCESSIBLE_QUICKWHEELS_TOOLTIP,
        },
        -- Options_Accessibility_Waypoint_Color
        [ACCESSIBILITY_SETTING_PLAYER_WAYPOINT_ICON_COLOR] =
        {
            controlType = OPTIONS_COLOR,
            system = SETTING_TYPE_ACCESSIBILITY,
            settingId = ACCESSIBILITY_SETTING_PLAYER_WAYPOINT_ICON_COLOR,
            panel = SETTING_PANEL_ACCESSIBILITY,
            text = SI_ACCESSIBILITY_OPTIONS_PLAYER_WAYPOINT_COLOR,
            tooltipText = SI_ACCESSIBILITY_OPTIONS_PLAYER_WAYPOINT_COLOR_TOOLTIP,
            exists = ZO_IsIngameUI,
        },
        --Options_Accessibility_GamepadAimAssistIntensity
        [ACCESSIBILITY_SETTING_GAMEPAD_AIM_ASSIST_INTENSITY] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_ACCESSIBILITY,
            settingId = ACCESSIBILITY_SETTING_GAMEPAD_AIM_ASSIST_INTENSITY,
            panel = SETTING_PANEL_ACCESSIBILITY,
            text = SI_ACCESSIBILITY_OPTIONS_GAMEPAD_AIM_ASSIST_INTENSITY,
            tooltipText = SI_ACCESSIBILITY_OPTIONS_GAMEPAD_AIM_ASSIST_INTENSITY_TOOLTIP,
            minValue = 0,
            maxValue = 100,
            showValue = true,
        },
        --Options_Accessibility_MouseAimAssistIntensity
        [ACCESSIBILITY_SETTING_MOUSE_AIM_ASSIST_INTENSITY] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_ACCESSIBILITY,
            settingId = ACCESSIBILITY_SETTING_MOUSE_AIM_ASSIST_INTENSITY,
            panel = SETTING_PANEL_ACCESSIBILITY,
            text = SI_ACCESSIBILITY_OPTIONS_MOUSE_AIM_ASSIST_INTENSITY,
            tooltipText = SI_ACCESSIBILITY_OPTIONS_MOUSE_AIM_ASSIST_INTENSITY_TOOLTIP,
            minValue = 0,
            maxValue = 100,
            showValue = true,
            exists = function()
                return not IsConsoleUI()
            end,
        },
    },
	
    [SETTING_TYPE_ACCOUNT] =
    {
        [ACCOUNT_SETTING_ACCOUNT_EMAIL] =
        {
            controlType = OPTIONS_INVOKE_CALLBACK,
            system = SETTING_TYPE_ACCOUNT,
            settingId = ACCOUNT_SETTING_ACCOUNT_EMAIL,
            panel = SETTING_PANEL_ACCOUNT,
            text = SI_INTERFACE_OPTIONS_ACCOUNT_CHANGE_EMAIL,
            gamepadCustomTooltipFunction = function(tooltip, text)
                GAMEPAD_TOOLTIPS:LayoutSettingAccountResendActivation(tooltip, HasActivatedEmail(), ZO_OptionsPanel_GetAccountEmail())
            end,
            -- If this setting doesn't exist, we won't attempt to load it, which would mean
            -- OPTIONS_CUSTOM_SETTING_RESEND_EMAIL_ACTIVATION could never be able to show
            exists = ZO_OptionsPanel_IsAccountManagementAvailable,
            visible = false,
            callback = function()
                if IsInGamepadPreferredMode() then
                    local data =
                    {
                        finishedCallback = function()
                            GAMEPAD_OPTIONS:RefreshOptionsList()
                        end,
                    }
                    ZO_Dialogs_ShowGamepadDialog("ZO_OPTIONS_GAMEPAD_EDIT_EMAIL_DIALOG", data)
                else
                    ZO_Dialogs_ShowDialog("ZO_OPTIONS_KEYBOARD_EDIT_EMAIL_DIALOG")
                end
            end,
        },
        [ACCOUNT_SETTING_GET_UPDATES] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_ACCOUNT,
            settingId = ACCOUNT_SETTING_GET_UPDATES,
            panel = SETTING_PANEL_ACCOUNT,
            text = SI_INTERFACE_OPTIONS_ACCOUNT_GET_UPDATES,
            tooltipText = function()
                if not IsConsoleUI() then
                    if HasActivatedEmail() then
                        return GetString(SI_INTERFACE_OPTIONS_ACCOUNT_GET_UPDATES_TOOLTIP_TEXT)
                    else
                        return zo_strformat(SI_KEYBOARD_INTERFACE_OPTIONS_ACCOUNT_GET_UPDATES_TOOLTIP_WARNING_FORMAT, GetString(SI_INTERFACE_OPTIONS_ACCOUNT_GET_UPDATES_TOOLTIP_TEXT), GetString(SI_INTERFACE_OPTIONS_ACCOUNT_NEED_ACTIVE_ACCOUNT_WARNING))
                    end
                end
            end,
            exists = ZO_OptionsPanel_IsAccountManagementAvailable,
            SetSettingOverride = function(control, value)
                SetSecureSetting(control.data.system, control.data.settingId, tostring(value))
            end,
            GetSettingOverride = function(control)
                return GetSecureSetting_Bool(control.data.system, control.data.settingId)
            end,
            gamepadCustomTooltipFunction = function(tooltip, text)
                GAMEPAD_TOOLTIPS:LayoutSettingAccountGetUpdates(tooltip, HasActivatedEmail())
            end,
            enabled = function()
                return HasActivatedEmail()
            end,
            gamepadIsEnabledCallback = function()
                return HasActivatedEmail()
            end,
        },
    },

    [SETTING_TYPE_AUDIO] =
    {
        --Options_Audio_MasterVolume
        [AUDIO_SETTING_AUDIO_VOLUME] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_AUDIO,
            settingId = AUDIO_SETTING_AUDIO_VOLUME,
            panel = SETTING_PANEL_AUDIO,
            text = SI_AUDIO_OPTIONS_MASTER_VOLUME,
            tooltipText = SI_AUDIO_OPTIONS_MASTER_VOLUME_TOOLTIP,
            minValue = 0,
            maxValue = 100,
            showValue = true,
            onReleasedHandler = function() PlaySound(SOUNDS.VOLUME_DING_ALL) end,
        },
        --Options_Audio_MusicEnabled
        [AUDIO_SETTING_MUSIC_ENABLED] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_AUDIO,
            settingId = AUDIO_SETTING_MUSIC_ENABLED,
            panel = SETTING_PANEL_AUDIO,
            text = SI_AUDIO_OPTIONS_MUSIC_ENABLED,
            tooltipText = SI_AUDIO_OPTIONS_MUSIC_ENABLED_TOOLTIP,
            events = {[true] = "MusicEnabled_On", [false] = "MusicEnabled_Off",},
            gamepadHasEnabledDependencies = true,
        },
        --Options_Audio_MusicVolume
        [AUDIO_SETTING_MUSIC_VOLUME] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_AUDIO,
            settingId = AUDIO_SETTING_MUSIC_VOLUME,
            panel = SETTING_PANEL_AUDIO,
            text = SI_AUDIO_OPTIONS_MUSIC_VOLUME,
            tooltipText = SI_AUDIO_OPTIONS_MUSIC_VOLUME_TOOLTIP,
            minValue = 0,
            maxValue = 100,
            showValue = true,
            eventCallbacks =
            {
                ["MusicEnabled_On"] = ZO_Options_SetOptionActive,
                ["MusicEnabled_Off"] = ZO_Options_SetOptionInactive,
            },
            onReleasedHandler = function() PlaySound(SOUNDS.VOLUME_DING_MUSIC) end,
            gamepadIsEnabledCallback = function() 
                                            return tonumber(GetSetting(SETTING_TYPE_AUDIO, AUDIO_SETTING_MUSIC_ENABLED)) ~= 0
                                        end,
        },
        --Options_Audio_SoundEnabled
        [AUDIO_SETTING_SOUND_ENABLED] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_AUDIO,
            settingId = AUDIO_SETTING_SOUND_ENABLED,
            panel = SETTING_PANEL_AUDIO,
            text = SI_AUDIO_OPTIONS_SOUND_ENABLED,
            tooltipText = SI_AUDIO_OPTIONS_SOUND_ENABLED_TOOLTIP,
            events = {[true] = "SoundEnabled_On", [false] = "SoundEnabled_Off",},
            gamepadHasEnabledDependencies = true,
        },
        --Options_Audio_AmbientVolume
        [AUDIO_SETTING_AMBIENT_VOLUME] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_AUDIO,
            settingId = AUDIO_SETTING_AMBIENT_VOLUME,
            panel = SETTING_PANEL_AUDIO,
            text = SI_AUDIO_OPTIONS_AMBIENT_VOLUME,
            tooltipText = SI_AUDIO_OPTIONS_AMBIENT_VOLUME_TOOLTIP,
            minValue = 0,
            maxValue = 100,
            showValue = true,
            eventCallbacks =
            {
                ["SoundEnabled_On"] = ZO_Options_SetOptionActive,
                ["SoundEnabled_Off"]= ZO_Options_SetOptionInactive,
            },
            onReleasedHandler = function() PlaySound(SOUNDS.VOLUME_DING_AMBIENT) end,
            gamepadIsEnabledCallback = IsSoundEnabled,
        },
        --Options_Audio_SFXVolume
        [AUDIO_SETTING_SFX_VOLUME] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_AUDIO,
            settingId = AUDIO_SETTING_SFX_VOLUME,
            panel = SETTING_PANEL_AUDIO,
            text = SI_AUDIO_OPTIONS_SFX_VOLUME,
            tooltipText = SI_AUDIO_OPTIONS_SFX_VOLUME_TOOLTIP,
            minValue = 0,
            maxValue = 100,
            showValue = true,
            eventCallbacks =
            {
                ["SoundEnabled_On"] = ZO_Options_SetOptionActive,
                ["SoundEnabled_Off"]= ZO_Options_SetOptionInactive,
            },
            onReleasedHandler = function() PlaySound(SOUNDS.VOLUME_DING_SFX) end,
            gamepadIsEnabledCallback = IsSoundEnabled,
        },
        --Options_Audio_FootstepsVolume
        [AUDIO_SETTING_FOOTSTEPS_VOLUME] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_AUDIO,
            settingId = AUDIO_SETTING_FOOTSTEPS_VOLUME,
            panel = SETTING_PANEL_AUDIO,
            text = SI_AUDIO_OPTIONS_FOOTSTEPS_VOLUME,
            tooltipText = SI_AUDIO_OPTIONS_FOOTSTEPS_VOLUME_TOOLTIP,
            minValue = 0,
            maxValue = 100,
            showValue = true,
            eventCallbacks =
            {
                ["SoundEnabled_On"] = ZO_Options_SetOptionActive,
                ["SoundEnabled_Off"]= ZO_Options_SetOptionInactive,
            },
            onReleasedHandler = function() PlaySound(SOUNDS.VOLUME_DING_FOOTSTEPS) end,
            gamepadIsEnabledCallback = IsSoundEnabled,
        },
        --Options_Audio_VOVolume
        [AUDIO_SETTING_VO_VOLUME] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_AUDIO,
            settingId = AUDIO_SETTING_VO_VOLUME,
            panel = SETTING_PANEL_AUDIO,
            text = SI_AUDIO_OPTIONS_VO_VOLUME,
            tooltipText = SI_AUDIO_OPTIONS_VO_VOLUME_TOOLTIP,
            minValue = 0,
            maxValue = 100,
            showValue = true,
            eventCallbacks =
            {
                ["SoundEnabled_On"] = ZO_Options_SetOptionActive,
                ["SoundEnabled_Off"]= ZO_Options_SetOptionInactive,
            },
            onReleasedHandler = function() PlaySound(SOUNDS.VOLUME_DING_VO) end,
            gamepadIsEnabledCallback = IsSoundEnabled,
        },
        --Options_Audio_UISoundVolume
        [AUDIO_SETTING_UI_VOLUME] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_AUDIO,
            settingId = AUDIO_SETTING_UI_VOLUME,
            panel = SETTING_PANEL_AUDIO,
            text = SI_AUDIO_OPTIONS_UI_VOLUME,
            tooltipText = SI_AUDIO_OPTIONS_UI_VOLUME_TOOLTIP,
            minValue = 0,
            maxValue = 100,
            showValue = true,
            eventCallbacks =
            {
                ["SoundEnabled_On"] = ZO_Options_SetOptionActive,
                ["SoundEnabled_Off"]= ZO_Options_SetOptionInactive,
            },
            onReleasedHandler = function() PlaySound(SOUNDS.VOLUME_DING_UI) end,
            gamepadIsEnabledCallback = IsSoundEnabled,
        },
        --Options_Audio_VideoSoundVolume
        [AUDIO_SETTING_VIDEO_VOLUME] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_AUDIO,
            settingId = AUDIO_SETTING_VIDEO_VOLUME,
            panel = SETTING_PANEL_AUDIO,
            text = SI_AUDIO_OPTIONS_VIDEO_VOLUME,
            tooltipText = SI_AUDIO_OPTIONS_VIDEO_VOLUME_TOOLTIP,
            minValue = 0,
            maxValue = 100,
            showValue = true,
            eventCallbacks =
            {
                ["SoundEnabled_On"] = ZO_Options_SetOptionActive,
                ["SoundEnabled_Off"]= ZO_Options_SetOptionInactive,
            },
            onReleasedHandler = function() PlaySound(SOUNDS.VOLUME_DING_VIDEO) end,
            gamepadIsEnabledCallback = IsSoundEnabled,
        },
        --Options_Audio_BackgroundAudio
        [AUDIO_SETTING_BACKGROUND_AUDIO] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_AUDIO,
            settingId = AUDIO_SETTING_BACKGROUND_AUDIO,
            panel = SETTING_PANEL_AUDIO,
            text = SI_AUDIO_OPTIONS_BACKGROUND_AUDIO,
            tooltipText = SI_AUDIO_OPTIONS_BACKGROUND_AUDIO_TOOLTIP,
            exists = ZO_IsPCUI,
        },
        --Options_Audio_VoiceChatVolume
        [AUDIO_SETTING_VOICE_CHAT_VOLUME] =
        {
            system = SETTING_TYPE_AUDIO,
            settingId = AUDIO_SETTING_VOICE_CHAT_VOLUME,
            controlType = OPTIONS_SLIDER,
            panel = SETTING_PANEL_DEBUG,
            text = SI_GAMEPAD_AUDIO_OPTIONS_VOICECHAT_VOLUME,
            minValue = 40,
            maxValue = 75,
            exists = IsConsoleUI,
        },
        --Options_Audio_CombatMusicMode
        [AUDIO_SETTING_COMBAT_MUSIC_MODE] =
        {
            system = SETTING_TYPE_AUDIO,
            settingId = AUDIO_SETTING_COMBAT_MUSIC_MODE,
            controlType = OPTIONS_FINITE_LIST,
            panel = SETTING_PANEL_AUDIO,
            text = SI_AUDIO_OPTIONS_COMBAT_MUSIC,
            tooltipText = SI_AUDIO_OPTIONS_COMBAT_MUSIC_TOOLTIP,
            valid = { COMBAT_MUSIC_MODE_SETTING_ALL, COMBAT_MUSIC_MODE_SETTING_NONE, COMBAT_MUSIC_MODE_SETTING_BOSSES_ONLY },
            valueStringPrefix = "SI_COMBATMUSICMODESETTING"
        },
        [AUDIO_SETTING_INTRO_MUSIC] = 
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_AUDIO,
            settingId = AUDIO_SETTING_INTRO_MUSIC,
            panel = SETTING_PANEL_AUDIO,
            text = SI_AUDIO_OPTIONS_INTRO_MUSIC,
            tooltipText = SI_AUDIO_OPTIONS_INTRO_MUSIC_TOOLTIP,
            -- valid = dynamically determined near EOF, introMusicSetting.valid
            -- itemText = dynamically determined near EOF, introMusicSetting.itemText
        },
        [AUDIO_SETTING_SPATIAL_SOUND] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_AUDIO,
            settingId = AUDIO_SETTING_SPATIAL_SOUND,
            panel = SETTING_PANEL_AUDIO,
            text = SI_AUDIO_OPTIONS_SPATIAL_SOUND,
            tooltipText = function()
                if ZO_IsPlaystationPlatform() then
                    return GetString(SI_GAMEPAD_AUDIO_OPTIONS_SPATIAL_SOUND_TOOLTIP_PROSPERO)
                elseif ZO_IsConsolePlatform() then
                    return GetString(SI_GAMEPAD_AUDIO_OPTIONS_SPATIAL_SOUND_TOOLTIP_SCARLETT)
                else
                    return GetString(SI_AUDIO_OPTIONS_SPATIAL_SOUND_TOOLTIP_WINDOWS)
                end
            end,
            events = {[true] = "SpatialSound_On", [false] = "SpatialSound_Off",},
            gamepadHasEnabledDependencies = true,
            exists = DoesPlatformSupportSpatialSound,
        },
        [AUDIO_SETTING_SPATIAL_SOUND_QUALITY] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_AUDIO,
            settingId = AUDIO_SETTING_SPATIAL_SOUND_QUALITY,
            panel = SETTING_PANEL_AUDIO,
            text = SI_AUDIO_OPTIONS_SPATIAL_SOUND,
            tooltipText = SI_AUDIO_OPTIONS_SPATIAL_SOUND_QUALITY_TOOLTIP,
            valid = { SPATIAL_SOUND_QUALITY_SETTING_LOW, SPATIAL_SOUND_QUALITY_SETTING_HIGH },
            valueStringPrefix = "SI_SPATIALSOUNDQUALITYSETTING",
            eventCallbacks =
            {
                ["SpatialSound_On"] = ZO_Options_SetOptionActive,
                ["SpatialSound_Off"] = ZO_Options_SetOptionInactive,
            },
            gamepadIsEnabledCallback = function()
                if DoesPlatformSupportSpatialSound() then
                    return GetSetting(SETTING_TYPE_AUDIO, AUDIO_SETTING_SPATIAL_SOUND)
                end

                return true
            end,
            exists = DoesPlatformSupportSpatialSoundQuality,
        },
    },

    --Buffs & Debuffs
    [SETTING_TYPE_BUFFS] =
    {
        --Options_Combat_Buffs_AllEnabled
        [BUFFS_SETTING_ALL_ENABLED] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_BUFFS,
            panel = SETTING_PANEL_COMBAT,
            settingId = BUFFS_SETTING_ALL_ENABLED,
            text = SI_BUFFS_OPTIONS_ALL_ENABLED,
            tooltipText = SI_BUFFS_OPTIONS_ALL_ENABLED_TOOLTIP,
            -- valid = {BUFF_DEBUFF_ENABLED_CHOICE_DONT_SHOW, BUFF_DEBUFF_ENABLED_CHOICE_AUTOMATIC, BUFF_DEBUFF_ENABLED_CHOICE_ALWAYS_SHOW,},
            -- valueStringPrefix = "SI_BUFFDEBUFFENABLEDCHOICE",
            -- events = {[BUFF_DEBUFF_ENABLED_CHOICE_DONT_SHOW] = "AllBuffsDebuffsEnabled_Changed", [BUFF_DEBUFF_ENABLED_CHOICE_AUTOMATIC] = "AllBuffsDebuffsEnabled_Changed", [BUFF_DEBUFF_ENABLED_CHOICE_ALWAYS_SHOW] = "AllBuffsDebuffsEnabled_Changed"},
            -- gamepadHasEnabledDependencies = true,
        },
        --Options_Combat_Buffs_AllBuffs
        [BUFFS_SETTING_BUFFS_ENABLED] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_BUFFS,
            panel = SETTING_PANEL_COMBAT,
            settingId = BUFFS_SETTING_BUFFS_ENABLED,
            text = SI_BUFFS_OPTIONS_BUFFS_ENABLED,
            tooltipText = SI_BUFFS_OPTIONS_BUFFS_ENABLED_TOOLTIP,
            -- events = {[false] = "BuffsEnabled_Changed", [true] = "BuffsEnabled_Changed",},
            -- gamepadHasEnabledDependencies = true,

            -- eventCallbacks =
            -- {
                -- ["AllBuffsDebuffsEnabled_Changed"]   = OnBuffDebuffEnabledChanged,
            -- },
            -- gamepadIsEnabledCallback = IsBuffDebuffEnabled,
        },
        --Options_Combat_Buffs_SelfBuffs
        [BUFFS_SETTING_BUFFS_ENABLED_FOR_SELF] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_BUFFS,
            panel = SETTING_PANEL_COMBAT,
            settingId = BUFFS_SETTING_BUFFS_ENABLED_FOR_SELF,
            text = SI_BUFFS_OPTIONS_BUFFS_ENABLED_FOR_SELF,
            tooltipText = SI_BUFFS_OPTIONS_BUFFS_ENABLED_FOR_SELF_TOOLTIP,

            -- eventCallbacks =
            -- {
                -- ["AllBuffsDebuffsEnabled_Changed"]   = OnBuffsEnabledChanged,
                -- ["BuffsEnabled_Changed"]    = OnBuffsEnabledChanged,
            -- },
            -- gamepadIsEnabledCallback = AreBuffsEnabled,
        },
        --Options_Combat_Buffs_TargetBuffs
        [BUFFS_SETTING_BUFFS_ENABLED_FOR_TARGET] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_BUFFS,
            panel = SETTING_PANEL_COMBAT,
            settingId = BUFFS_SETTING_BUFFS_ENABLED_FOR_TARGET,
            text = SI_BUFFS_OPTIONS_BUFFS_ENABLED_FOR_TARGET,
            tooltipText = SI_BUFFS_OPTIONS_BUFFS_ENABLED_FOR_TARGET_TOOLTIP,

            -- eventCallbacks =
            -- {
                -- ["AllBuffsDebuffsEnabled_Changed"]   = OnBuffsEnabledChanged,
                -- ["BuffsEnabled_Changed"]    = OnBuffsEnabledChanged,
            -- },
            -- gamepadIsEnabledCallback = AreBuffsEnabled,
        },
        --Options_Combat_Buffs_AllDebuffs
        [BUFFS_SETTING_DEBUFFS_ENABLED] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_BUFFS,
            panel = SETTING_PANEL_COMBAT,
            settingId = BUFFS_SETTING_DEBUFFS_ENABLED,
            text = SI_BUFFS_OPTIONS_DEBUFFS_ENABLED,
            tooltipText = SI_BUFFS_OPTIONS_DEBUFFS_ENABLED_TOOLTIP,
            -- events = {[false] = "DebuffsEnabled_Changed", [true] = "DebuffsEnabled_Changed",},
            -- gamepadHasEnabledDependencies = true,

            -- eventCallbacks =
            -- {
                -- ["AllBuffsDebuffsEnabled_Changed"]   = OnBuffDebuffEnabledChanged,
            -- },
            -- gamepadIsEnabledCallback = IsBuffDebuffEnabled,
        },
        --Options_Combat_Buffs_SelfDebuffs
        [BUFFS_SETTING_DEBUFFS_ENABLED_FOR_SELF] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_BUFFS,
            panel = SETTING_PANEL_COMBAT,
            settingId = BUFFS_SETTING_DEBUFFS_ENABLED_FOR_SELF,
            text = SI_BUFFS_OPTIONS_DEBUFFS_ENABLED_FOR_SELF,
            tooltipText = SI_BUFFS_OPTIONS_DEBUFFS_ENABLED_FOR_SELF_TOOLTIP,

            eventCallbacks =
            {
                ["AllBuffsDebuffsEnabled_Changed"]   = OnDebuffsEnabledChanged,
                ["DebuffsEnabled_Changed"]    = OnDebuffsEnabledChanged,
            },
            gamepadIsEnabledCallback = AreDebuffsEnabled,
        },
        --Options_Combat_Buffs_TargetDebuffs
        [BUFFS_SETTING_DEBUFFS_ENABLED_FOR_TARGET] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_BUFFS,
            panel = SETTING_PANEL_COMBAT,
            settingId = BUFFS_SETTING_DEBUFFS_ENABLED_FOR_TARGET,
            text = SI_BUFFS_OPTIONS_DEBUFFS_ENABLED_FOR_TARGET,
            tooltipText = SI_BUFFS_OPTIONS_DEBUFFS_ENABLED_FOR_TARGET_TOOLTIP,
            events = {[false] = "DebuffsEnabledForTarget_Changed", [true] = "DebuffsEnabledForTarget_Changed",},
            gamepadHasEnabledDependencies = true,

            eventCallbacks =
            {
                ["AllBuffsDebuffsEnabled_Changed"]   = OnDebuffsEnabledChanged,
                ["DebuffsEnabled_Changed"]    = OnDebuffsEnabledChanged,
            },
            gamepadIsEnabledCallback = AreDebuffsEnabled,
        },
        --Options_Combat_Buffs_LongEffects
        [BUFFS_SETTING_LONG_EFFECTS] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_BUFFS,
            panel = SETTING_PANEL_COMBAT,
            settingId = BUFFS_SETTING_LONG_EFFECTS,
            text = SI_BUFFS_OPTIONS_LONG_EFFECTS,
            tooltipText = SI_BUFFS_OPTIONS_LONG_EFFECTS_TOOLTIP,

            eventCallbacks =
            {
                ["AllBuffsDebuffsEnabled_Changed"]   = OnBuffDebuffEnabledChanged,
            },
            gamepadIsEnabledCallback = IsBuffDebuffEnabled,
        },
        --Options_Combat_Buffs_PermanentEffects
        [BUFFS_SETTING_PERMANENT_EFFECTS] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_BUFFS,
            panel = SETTING_PANEL_COMBAT,
            settingId = BUFFS_SETTING_PERMANENT_EFFECTS,
            text = SI_BUFFS_OPTIONS_PERMANENT_EFFECTS,
            tooltipText = SI_BUFFS_OPTIONS_PERMANENT_EFFECTS_TOOLTIP,

            eventCallbacks =
            {
                ["AllBuffsDebuffsEnabled_Changed"]   = OnBuffDebuffEnabledChanged,
            },
            gamepadIsEnabledCallback = IsBuffDebuffEnabled,
        },
        --Option_Combat_Buffs_Debuffs_Enabled_For_Target_From_Others
        [BUFFS_SETTING_DEBUFFS_ENABLED_FOR_TARGET_FROM_OTHERS] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_BUFFS,
            panel = SETTING_PANEL_COMBAT,
            settingId = BUFFS_SETTING_DEBUFFS_ENABLED_FOR_TARGET_FROM_OTHERS,
            text = SI_BUFFS_OPTIONS_DEBUFFS_ENABLED_FOR_TARGET_FROM_OTHERS,
            tooltipText = SI_BUFFS_OPTIONS_DEBUFFS_ENABLED_FOR_TARGET_FROM_OTHERS_TOOLTIP,
            
            eventCallbacks =
            {
                ["AllBuffsDebuffsEnabled_Changed"] = OnDebuffsEnabledForTargetChanged,
                ["DebuffsEnabled_Changed"] = OnDebuffsEnabledForTargetChanged,
                ["DebuffsEnabledForTarget_Changed"] = OnDebuffsEnabledForTargetChanged,
            },
            gamepadIsEnabledCallback = AreDebuffsForTargetEnabled,
        }
    },

    --Camera
    [SETTING_TYPE_CAMERA] =
    {
        --Options_Camera_Smoothing
        [CAMERA_SETTING_SMOOTHING] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_CAMERA,
            settingId = CAMERA_SETTING_SMOOTHING,
            panel = SETTING_PANEL_CAMERA,
            text = SI_INTERFACE_OPTIONS_CAMERA_SMOOTHING,
            tooltipText = SI_INTERFACE_OPTIONS_CAMERA_SMOOTHING_TOOLTIP,
        },
        --Options_Camera_InvertY
        [CAMERA_SETTING_INVERT_Y] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_CAMERA,
            settingId = CAMERA_SETTING_INVERT_Y,
            panel = SETTING_PANEL_CAMERA,
            text = SI_INTERFACE_OPTIONS_CAMERA_INVERT_Y,
            tooltipText = SI_INTERFACE_OPTIONS_CAMERA_INVERT_Y_TOOLTIP,
        },
        --Options_Camera_InvertX
        [CAMERA_SETTING_INVERT_X] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_CAMERA,
            settingId = CAMERA_SETTING_INVERT_X,
            panel = SETTING_PANEL_CAMERA,
            text = SI_INTERFACE_OPTIONS_CAMERA_INVERT_X,
            tooltipText = SI_INTERFACE_OPTIONS_CAMERA_INVERT_X_TOOLTIP,
        },
        --Options_Camera_FOVChangesAllowed
        [CAMERA_SETTING_FOV_CHANGES_ALLOWED] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_CAMERA,
            settingId = CAMERA_SETTING_FOV_CHANGES_ALLOWED,
            panel = SETTING_PANEL_CAMERA,
            text = SI_INTERFACE_OPTIONS_CAMERA_FOV_CHANGES,
            tooltipText = SI_INTERFACE_OPTIONS_CAMERA_FOV_CHANGES_TOOLTIP,
        },
		--Options_Camera_AssassinationCamera
        [CAMERA_SETTING_ASSASSINATION_CAMERA] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_CAMERA,
            settingId = CAMERA_SETTING_ASSASSINATION_CAMERA,
            panel = SETTING_PANEL_CAMERA,
            text = SI_INTERFACE_OPTIONS_CAMERA_ASSASSINATION_CAMERA,
            tooltipText = SI_INTERFACE_OPTIONS_CAMERA_ASSASSINATION_CAMERA_TOOLTIP,
        },
        --Options_Camera_ScreenShake
        [CAMERA_SETTING_SCREEN_SHAKE] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_CAMERA,
            settingId = CAMERA_SETTING_SCREEN_SHAKE,
            panel = SETTING_PANEL_CAMERA,
            text = SI_INTERFACE_OPTIONS_CAMERA_SCREEN_SHAKE,
            tooltipText = SI_INTERFACE_OPTIONS_CAMERA_SCREEN_SHAKE_TOOLTIP,
            minValue = 0.0,
            maxValue = 1.0,
            valueFormat = "%.2f",
            showValue = true,
            defaultMarker = 100,
            showValueMin = 0,
            showValueMax = 100,
        },
        --Options_Camera_CameraSensitivityFirstPerson
        [CAMERA_SETTING_SENSITIVITY_FIRST_PERSON_X] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_CAMERA,
            settingId = CAMERA_SETTING_SENSITIVITY_FIRST_PERSON_X,
            panel = SETTING_PANEL_CAMERA,
            text = SI_INTERFACE_OPTIONS_CAMERA_SENSITIVITY_FIRST_PERSON_X,
            tooltipText = SI_INTERFACE_OPTIONS_CAMERA_SENSITIVITY_FIRST_PERSON_X_TOOLTIP,
            minValue = 0.1,
            maxValue = 1.6,
            valueFormat = "%.2f",
            showValue = true,
            defaultMarker = 50,
            showValueMin = 0,
            showValueMax = 100,
        },
        --Options_Camera_CameraSensitivityFirstPersonY
        [CAMERA_SETTING_SENSITIVITY_FIRST_PERSON_Y] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_CAMERA,
            settingId = CAMERA_SETTING_SENSITIVITY_FIRST_PERSON_Y,
            panel = SETTING_PANEL_CAMERA,
            text = SI_INTERFACE_OPTIONS_CAMERA_SENSITIVITY_FIRST_PERSON_Y,
            tooltipText = SI_INTERFACE_OPTIONS_CAMERA_SENSITIVITY_FIRST_PERSON_Y_TOOLTIP,
            minValue = 0.1,
            maxValue = 1.6,
            valueFormat = "%.2f",
            showValue = true,
            defaultMarker = 50,
            showValueMin = 0,
            showValueMax = 100,
        },
        --Options_Camera_FirstPersonFieldOfView
        [CAMERA_SETTING_FIRST_PERSON_FIELD_OF_VIEW] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_CAMERA,
            settingId = CAMERA_SETTING_FIRST_PERSON_FIELD_OF_VIEW,
            panel = SETTING_PANEL_CAMERA,
            text = SI_INTERFACE_OPTIONS_CAMERA_FIRST_PERSON_FOV,
            gamepadTextOverride = SI_GAMEPAD_OPTIONS_CAMERA_FIRST_PERSON_FOV,
            tooltipText = SI_INTERFACE_OPTIONS_CAMERA_FIRST_PERSON_FOV_TOOLTIP,
            minValue = 35,
            maxValue = 65,
            valueFormat = "%.2f",
            showValue = true,
            defaultMarker = 50,
            showValueMin = 70,
            showValueMax = 130,
        },
        --Options_Camera_FirstPersonHeadBob
        [CAMERA_SETTING_FIRST_PERSON_HEAD_BOB] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_CAMERA,
            settingId = CAMERA_SETTING_FIRST_PERSON_HEAD_BOB,
            panel = SETTING_PANEL_CAMERA,
            text = SI_INTERFACE_OPTIONS_CAMERA_FIRST_PERSON_BOB,
            gamepadTextOverride = SI_GAMEPAD_OPTIONS_CAMERA_FIRST_PERSON_BOB,
            tooltipText = SI_INTERFACE_OPTIONS_CAMERA_FIRST_PERSON_BOB_TOOLTIP,
            minValue = 0.0,
            maxValue = 1.0,
            valueFormat = "%.2f",
            showValue = true,
            defaultMarker = 100,
            showValueMin = 0,
            showValueMax = 100,
        },
        --Options_Camera_CameraSensitivityThirdPersonY
        [CAMERA_SETTING_SENSITIVITY_THIRD_PERSON_Y] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_CAMERA,
            settingId = CAMERA_SETTING_SENSITIVITY_THIRD_PERSON_Y,
            panel = SETTING_PANEL_CAMERA,
            text = SI_INTERFACE_OPTIONS_CAMERA_SENSITIVITY_THIRD_PERSON_Y,
            tooltipText = SI_INTERFACE_OPTIONS_CAMERA_SENSITIVITY_THIRD_PERSON_Y_TOOLTIP,
            minValue = 0.1,
            maxValue = 1.6,
            valueFormat = "%.2f",
            showValue = true,
            showValueMin = 0,
            showValueMax = 100,
        },
        --Options_Camera_CameraSensitivityThirdPerson
        [CAMERA_SETTING_SENSITIVITY_THIRD_PERSON_X] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_CAMERA,
            settingId = CAMERA_SETTING_SENSITIVITY_THIRD_PERSON_X,
            panel = SETTING_PANEL_CAMERA,
            text = SI_INTERFACE_OPTIONS_CAMERA_SENSITIVITY_THIRD_PERSON_X,
            tooltipText = SI_INTERFACE_OPTIONS_CAMERA_SENSITIVITY_THIRD_PERSON_X_TOOLTIP,
            minValue = 0.1,
            maxValue = 1.6,
            valueFormat = "%.2f",
            showValue = true,
            showValueMin = 0,
            showValueMax = 100,
        },
        --Options_Camera_ThirdPersonHorizontalPositionMutliplier
        [CAMERA_SETTING_THIRD_PERSON_HORIZONTAL_POSITION_MULTIPLIER] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_CAMERA,
            settingId = CAMERA_SETTING_THIRD_PERSON_HORIZONTAL_POSITION_MULTIPLIER,
            panel = SETTING_PANEL_CAMERA,
            text = SI_INTERFACE_OPTIONS_CAMERA_THIRD_PERSON_HORIZONTAL_POSITION_MULTIPLIER,
            tooltipText = SI_INTERFACE_OPTIONS_CAMERA_THIRD_PERSON_HORIZONTAL_POSITION_MULTIPLIER_TOOLTIP,
            minValue = -1.0,
            maxValue = 1.0,
            valueFormat = "%.2f",
            showValue = true,
            defaultMarker = 100,
            showValueMin = -100,
            showValueMax = 100,
        },
        --Options_Camera_ThirdPersonHorizontalOffset
        [CAMERA_SETTING_THIRD_PERSON_HORIZONTAL_OFFSET] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_CAMERA,
            settingId = CAMERA_SETTING_THIRD_PERSON_HORIZONTAL_OFFSET,
            panel = SETTING_PANEL_CAMERA,
            text = SI_INTERFACE_OPTIONS_CAMERA_THIRD_PERSON_HORIZONTAL_OFFSET,
            tooltipText = SI_INTERFACE_OPTIONS_CAMERA_THIRD_PERSON_HORIZONTAL_OFFSET_TOOLTIP,
            minValue = -1.0,
            maxValue = 1.0,
            valueFormat = "%.2f",
            showValue = true,
            defaultMarker = 0,
            showValueMin = -100,
            showValueMax = 100,
        },
        --Options_Camera_ThirdPersonVerticalOffset
        [CAMERA_SETTING_THIRD_PERSON_VERTICAL_OFFSET] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_CAMERA,
            settingId = CAMERA_SETTING_THIRD_PERSON_VERTICAL_OFFSET,
            panel = SETTING_PANEL_CAMERA,
            text = SI_INTERFACE_OPTIONS_CAMERA_THIRD_PERSON_VERTICAL_OFFSET,
            tooltipText = SI_INTERFACE_OPTIONS_CAMERA_THIRD_PERSON_VERTICAL_OFFSET_TOOLTIP,
            minValue = -0.3,
            maxValue = 0.5,
            valueFormat = "%.2f",
            showValue = true,
            defaultMarker = 0,
            showValueMin = -60,
            showValueMax = 100,
        },
        --Options_Camera_ThirdPersonFieldOfView
        [CAMERA_SETTING_THIRD_PERSON_FIELD_OF_VIEW] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_CAMERA,
            settingId = CAMERA_SETTING_THIRD_PERSON_FIELD_OF_VIEW,
            panel = SETTING_PANEL_CAMERA,
            text = SI_INTERFACE_OPTIONS_CAMERA_THIRD_PERSON_FOV,
            gamepadTextOverride = SI_GAMEPAD_OPTIONS_CAMERA_THIRD_PERSON_FOV,
            tooltipText = SI_INTERFACE_OPTIONS_CAMERA_THIRD_PERSON_FOV_TOOLTIP,
            minValue = 35,
            maxValue = 65,
            valueFormat = "%.2f",
            showValue = true,
            defaultMarker = 50, -- should match default from InterfaceSettingObject_Camera.cpp
            showValueMin = 70,
            showValueMax = 130,
        },
        --Options_Camera_ThirdPersonSiegeWeaponry
        [CAMERA_SETTING_THIRD_PERSON_SIEGE_WEAPONRY] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_CAMERA,
            panel = SETTING_PANEL_CAMERA,
            settingId = CAMERA_SETTING_THIRD_PERSON_SIEGE_WEAPONRY,
            text = SI_INTERFACE_OPTIONS_CAMERA_THIRD_PERSON_SIEGE_WEAPONRY,
            tooltipText = SI_INTERFACE_OPTIONS_CAMERA_THIRD_PERSON_SIEGE_WEAPONRY_TOOLTIP,
            valid = {SIEGE_CAMERA_CHOICE_FREE, SIEGE_CAMERA_CHOICE_CONSTRAINED,},
            valueStringPrefix = "SI_SIEGECAMERACHOICE",
        },
    },

    --Chat bubbles
    [SETTING_TYPE_CHAT_BUBBLE] =
    {
        --Options_Interface_ChatBubblesEnabled
        [CHAT_BUBBLE_SETTING_ENABLED] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_CHAT_BUBBLE,
            settingId = CHAT_BUBBLE_SETTING_ENABLED,
            panel = SETTING_PANEL_INTERFACE,
            text = SI_INTERFACE_OPTIONS_CHAT_BUBBLES,
            consoleTextOverride = SI_QUICK_CHAT_SETTING_ENABLED,
            tooltipText = SI_INTERFACE_OPTIONS_CHAT_BUBBLES_TOOLTIP,
            events = {[false] = "ChatBubbles_Off", [true] = "ChatBubbles_On",},
            gamepadHasEnabledDependencies = true,
        },
        --Options_Interface_ChatBubblesSpeed
        [CHAT_BUBBLE_SETTING_SPEED_MODIFIER] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_CHAT_BUBBLE,
            settingId = CHAT_BUBBLE_SETTING_SPEED_MODIFIER,
            panel = SETTING_PANEL_INTERFACE,
            text = SI_INTERFACE_OPTIONS_CHAT_BUBBLES_FADE_RATE,
            tooltipText = SI_INTERFACE_OPTIONS_CHAT_BUBBLES_FADE_RATE_TOOLTIP,
            minValue = .25,
            maxValue = 3.0,
            valueFormat = "%.2f",
            showValue = true,
            showValueFunc = ZO_OptionsPanel_Interface_ChatBubbleSpeedSliderValueFunc,

            eventCallbacks =
            {
                ["ChatBubbles_Off"]   = ZO_Options_SetOptionInactive,
                ["ChatBubbles_On"]    = ZO_Options_SetOptionActive,
            },
            gamepadIsEnabledCallback = function() 
                                return tonumber(GetSetting(SETTING_TYPE_CHAT_BUBBLE, CHAT_BUBBLE_SETTING_ENABLED)) ~= 0
                            end,
        },
        --Options_Interface_ChatBubblesEnabledRestrictToContacts
        [CHAT_BUBBLE_SETTING_ENABLED_ONLY_FROM_CONTACTS] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_CHAT_BUBBLE,
            settingId = CHAT_BUBBLE_SETTING_ENABLED_ONLY_FROM_CONTACTS,
            panel = SETTING_PANEL_INTERFACE,
            text = SI_INTERFACE_OPTIONS_CHAT_BUBBLES_ONLY_KNOWN,
            tooltipText = SI_INTERFACE_OPTIONS_CHAT_BUBBLES_ONLY_KNOWN_TOOLTIP,

            eventCallbacks =
            {
                ["ChatBubbles_Off"]   = ZO_Options_SetOptionInactive,
                ["ChatBubbles_On"]    = ZO_Options_SetOptionActive,
            },
        },
        --Options_Interface_ChatBubblesEnabledForLocalPlayer
        [CHAT_BUBBLE_SETTING_ENABLED_FOR_LOCAL_PLAYER] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_CHAT_BUBBLE,
            settingId = CHAT_BUBBLE_SETTING_ENABLED_FOR_LOCAL_PLAYER,
            panel = SETTING_PANEL_INTERFACE,
            text = SI_INTERFACE_OPTIONS_CHAT_BUBBLES_SELF,
            tooltipText = SI_INTERFACE_OPTIONS_CHAT_BUBBLES_SELF_TOOLTIP,

            eventCallbacks =
            {
                ["ChatBubbles_Off"]   = ZO_Options_SetOptionInactive,
                ["ChatBubbles_On"]    = ZO_Options_SetOptionActive,
            },
        },
    },



   --Combat
    [SETTING_TYPE_COMBAT] =
    {
        [COMBAT_SETTING_ENCOUNTER_LOG_APPEAR_ANONYMOUS] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_COMBAT,
            settingId = COMBAT_SETTING_ENCOUNTER_LOG_APPEAR_ANONYMOUS,
            panel = SETTING_PANEL_COMBAT,
            text = SI_INTERFACE_OPTIONS_COMBAT_ENCOUNTER_LOG_APPEAR_ANONYMOUS,
            tooltipText = SI_INTERFACE_OPTIONS_COMBAT_ENCOUNTER_LOG_APPEAR_ANONYMOUS_TOOLTIP,
            exists = ZO_IsPCUI,
        },
        [COMBAT_SETTING_SCROLLING_COMBAT_TEXT_ENABLED] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_COMBAT,
            settingId = COMBAT_SETTING_SCROLLING_COMBAT_TEXT_ENABLED,
            panel = SETTING_PANEL_COMBAT,
            text = SI_INTERFACE_OPTIONS_COMBAT_SCT_ENABLED,
            tooltipText = SI_INTERFACE_OPTIONS_COMBAT_SCT_ENABLED_TOOLTIP,
            events = {[true] = "SCTEnabled_Changed", [false] = "SCTEnabled_Changed",},
            gamepadHasEnabledDependencies = true,
        },
        [COMBAT_SETTING_SCT_OUTGOING_ENABLED] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_COMBAT,
            settingId = COMBAT_SETTING_SCT_OUTGOING_ENABLED,
            panel = SETTING_PANEL_COMBAT,
            text = SI_INTERFACE_OPTIONS_COMBAT_SCT_OUTGOING_ENABLED,
            tooltipText = SI_INTERFACE_OPTIONS_COMBAT_SCT_OUTGOING_ENABLED_TOOLTIP,
            events = {[true] = "SCTOutgoingEnabled_Changed", [false] = "SCTOutgoingEnabled_Changed",},
            eventCallbacks =
            {
                ["SCTEnabled_Changed"]   = OnSCTEnabledChanged,
            },
            gamepadIsEnabledCallback = IsSCTEnabled,
            gamepadHasEnabledDependencies = true,
        },
        [COMBAT_SETTING_SCT_OUTGOING_DAMAGE_ENABLED] = {text = SI_INTERFACE_OPTIONS_COMBAT_SCT_OUTGOING_DAMAGE_ENABLED, tooltipText = SI_INTERFACE_OPTIONS_COMBAT_SCT_OUTGOING_DAMAGE_ENABLED_TOOLTIP, system = SETTING_TYPE_COMBAT, settingId =COMBAT_SETTING_SCT_OUTGOING_DAMAGE_ENABLED},
        [COMBAT_SETTING_SCT_OUTGOING_DOT_ENABLED] = {text = SI_INTERFACE_OPTIONS_COMBAT_SCT_OUTGOING_DOT_ENABLED, tooltipText = SI_INTERFACE_OPTIONS_COMBAT_SCT_OUTGOING_DOT_ENABLED_TOOLTIP, system = SETTING_TYPE_COMBAT, settingId =COMBAT_SETTING_SCT_OUTGOING_DOT_ENABLED},
        [COMBAT_SETTING_SCT_OUTGOING_HEALING_ENABLED] = {text = SI_INTERFACE_OPTIONS_COMBAT_SCT_OUTGOING_HEALING_ENABLED, tooltipText = SI_INTERFACE_OPTIONS_COMBAT_SCT_OUTGOING_HEALING_ENABLED_TOOLTIP, system = SETTING_TYPE_COMBAT, settingId =COMBAT_SETTING_SCT_OUTGOING_HEALING_ENABLED},
        [COMBAT_SETTING_SCT_OUTGOING_HOT_ENABLED] = {text = SI_INTERFACE_OPTIONS_COMBAT_SCT_OUTGOING_HOT_ENABLED, tooltipText = SI_INTERFACE_OPTIONS_COMBAT_SCT_OUTGOING_HOT_ENABLED_TOOLTIP, system = SETTING_TYPE_COMBAT, settingId =COMBAT_SETTING_SCT_OUTGOING_HOT_ENABLED},
        [COMBAT_SETTING_SCT_OUTGOING_STATUS_EFFECTS_ENABLED] = {text = SI_INTERFACE_OPTIONS_COMBAT_SCT_OUTGOING_STATUS_EFFECTS_ENABLED, tooltipText = SI_INTERFACE_OPTIONS_COMBAT_SCT_OUTGOING_STATUS_EFFECTS_ENABLED_TOOLTIP, system = SETTING_TYPE_COMBAT, settingId =COMBAT_SETTING_SCT_OUTGOING_STATUS_EFFECTS_ENABLED},
        [COMBAT_SETTING_SCT_OUTGOING_PET_DAMAGE_ENABLED] = {text = SI_INTERFACE_OPTIONS_COMBAT_SCT_OUTGOING_PET_DAMAGE_ENABLED, tooltipText = SI_INTERFACE_OPTIONS_COMBAT_SCT_OUTGOING_PET_DAMAGE_ENABLED_TOOLTIP, system = SETTING_TYPE_COMBAT, settingId =COMBAT_SETTING_SCT_OUTGOING_PET_DAMAGE_ENABLED},
        [COMBAT_SETTING_SCT_OUTGOING_PET_DOT_ENABLED] = {text = SI_INTERFACE_OPTIONS_COMBAT_SCT_OUTGOING_PET_DOT_ENABLED, tooltipText = SI_INTERFACE_OPTIONS_COMBAT_SCT_OUTGOING_PET_DOT_ENABLED_TOOLTIP, system = SETTING_TYPE_COMBAT, settingId =COMBAT_SETTING_SCT_OUTGOING_PET_DOT_ENABLED},
        [COMBAT_SETTING_SCT_OUTGOING_PET_HEALING_ENABLED] = {text = SI_INTERFACE_OPTIONS_COMBAT_SCT_OUTGOING_PET_HEALING_ENABLED, tooltipText = SI_INTERFACE_OPTIONS_COMBAT_SCT_OUTGOING_PET_HEALING_ENABLED_TOOLTIP, system = SETTING_TYPE_COMBAT, settingId =COMBAT_SETTING_SCT_OUTGOING_PET_HEALING_ENABLED},
        [COMBAT_SETTING_SCT_OUTGOING_PET_HOT_ENABLED] = {text = SI_INTERFACE_OPTIONS_COMBAT_SCT_OUTGOING_PET_HOT_ENABLED, tooltipText = SI_INTERFACE_OPTIONS_COMBAT_SCT_OUTGOING_PET_HOT_ENABLED_TOOLTIP, system = SETTING_TYPE_COMBAT, settingId =COMBAT_SETTING_SCT_OUTGOING_PET_HOT_ENABLED},
        [COMBAT_SETTING_SCT_INCOMING_ENABLED] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_COMBAT,
            settingId = COMBAT_SETTING_SCT_INCOMING_ENABLED,
            panel = SETTING_PANEL_COMBAT,
            text = SI_INTERFACE_OPTIONS_COMBAT_SCT_INCOMING_ENABLED,
            tooltipText = SI_INTERFACE_OPTIONS_COMBAT_SCT_INCOMING_ENABLED_TOOLTIP,
            events = {[true] = "SCTIncomingEnabled_Changed", [false] = "SCTIncomingEnabled_Changed",},
            eventCallbacks =
            {
                ["SCTEnabled_Changed"]   = OnSCTEnabledChanged,
            },
            gamepadIsEnabledCallback = IsSCTEnabled,
            gamepadHasEnabledDependencies = true,
        },
        [COMBAT_SETTING_SCT_INCOMING_DAMAGE_ENABLED] = {text = SI_INTERFACE_OPTIONS_COMBAT_SCT_INCOMING_DAMAGE_ENABLED, tooltipText = SI_INTERFACE_OPTIONS_COMBAT_SCT_INCOMING_DAMAGE_ENABLED_TOOLTIP, system = SETTING_TYPE_COMBAT, settingId =COMBAT_SETTING_SCT_INCOMING_DAMAGE_ENABLED},
        [COMBAT_SETTING_SCT_INCOMING_DOT_ENABLED] = {text = SI_INTERFACE_OPTIONS_COMBAT_SCT_INCOMING_DOT_ENABLED, tooltipText = SI_INTERFACE_OPTIONS_COMBAT_SCT_INCOMING_DOT_ENABLED_TOOLTIP, system = SETTING_TYPE_COMBAT, settingId =COMBAT_SETTING_SCT_INCOMING_DOT_ENABLED},
        [COMBAT_SETTING_SCT_INCOMING_HEALING_ENABLED] = {text = SI_INTERFACE_OPTIONS_COMBAT_SCT_INCOMING_HEALING_ENABLED, tooltipText = SI_INTERFACE_OPTIONS_COMBAT_SCT_INCOMING_HEALING_ENABLED_TOOLTIP, system = SETTING_TYPE_COMBAT, settingId =COMBAT_SETTING_SCT_INCOMING_HEALING_ENABLED},
        [COMBAT_SETTING_SCT_INCOMING_HOT_ENABLED] = {text = SI_INTERFACE_OPTIONS_COMBAT_SCT_INCOMING_HOT_ENABLED, tooltipText = SI_INTERFACE_OPTIONS_COMBAT_SCT_INCOMING_HOT_ENABLED_TOOLTIP, system = SETTING_TYPE_COMBAT, settingId =COMBAT_SETTING_SCT_INCOMING_HOT_ENABLED},
        [COMBAT_SETTING_SCT_INCOMING_PET_DAMAGE_ENABLED] = {text = SI_INTERFACE_OPTIONS_COMBAT_SCT_INCOMING_PET_DAMAGE_ENABLED, tooltipText = SI_INTERFACE_OPTIONS_COMBAT_SCT_INCOMING_PET_DAMAGE_ENABLED_TOOLTIP, system = SETTING_TYPE_COMBAT, settingId =COMBAT_SETTING_SCT_INCOMING_PET_DAMAGE_ENABLED},
        [COMBAT_SETTING_SCT_INCOMING_PET_DOT_ENABLED] = {text = SI_INTERFACE_OPTIONS_COMBAT_SCT_INCOMING_PET_DOT_ENABLED, tooltipText = SI_INTERFACE_OPTIONS_COMBAT_SCT_INCOMING_PET_DOT_ENABLED_TOOLTIP, system = SETTING_TYPE_COMBAT, settingId =COMBAT_SETTING_SCT_INCOMING_PET_DOT_ENABLED},
        [COMBAT_SETTING_SCT_INCOMING_STATUS_EFFECTS_ENABLED] = {text = SI_INTERFACE_OPTIONS_COMBAT_SCT_INCOMING_STATUS_EFFECTS_ENABLED, tooltipText = SI_INTERFACE_OPTIONS_COMBAT_SCT_INCOMING_STATUS_EFFECTS_ENABLED_TOOLTIP, system = SETTING_TYPE_COMBAT, settingId =COMBAT_SETTING_SCT_INCOMING_STATUS_EFFECTS_ENABLED},
        [COMBAT_SETTING_SCT_SHOW_OVER_HEAL] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_COMBAT,
            settingId = COMBAT_SETTING_SCT_SHOW_OVER_HEAL,
            panel = SETTING_PANEL_COMBAT,
            text = SI_INTERFACE_OPTIONS_COMBAT_SCT_SHOW_OVER_HEAL,
            tooltipText = SI_INTERFACE_OPTIONS_COMBAT_SCT_SHOW_OVER_HEAL_TOOLTIP,
            eventCallbacks =
            {
                ["SCTEnabled_Changed"]   = OnSCTEnabledChanged,
            },
            gamepadIsEnabledCallback = IsSCTEnabled,
        },
       --Options_Gameplay_MonsterTells
        [COMBAT_SETTING_MONSTER_TELLS_ENABLED] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_COMBAT,
            panel = SETTING_PANEL_GAMEPLAY,
            settingId = COMBAT_SETTING_MONSTER_TELLS_ENABLED,
            text = SI_INTERFACE_OPTIONS_COMBAT_MONSTER_TELLS_ENABLE,
            tooltipText = SI_INTERFACE_OPTIONS_COMBAT_MONSTER_TELLS_ENABLE_TOOLTIP,
            events = {[true] = "MonsterTellsEnabled_Changed", [false] = "MonsterTellsEnabled_Changed",},
            gamepadHasEnabledDependencies = true,
        },
        --Options_Gameplay_MonsterTellsColorSwapEnabled
        [COMBAT_SETTING_MONSTER_TELLS_COLOR_SWAP_ENABLED] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_COMBAT,
            panel = SETTING_PANEL_GAMEPLAY,
            settingId = COMBAT_SETTING_MONSTER_TELLS_COLOR_SWAP_ENABLED,
            text = SI_INTERFACE_OPTIONS_COMBAT_MONSTER_TELLS_COLOR_SWAP_ENABLED,
            tooltipText = SI_INTERFACE_OPTIONS_COMBAT_MONSTER_TELLS_COLOR_SWAP_ENABLED_TOOLTIP,
            events = {[true] = "MonsterTellsColorSwapEnabled_Changed", [false] = "MonsterTellsColorSwapEnabled_Changed",},
            eventCallbacks =
            {
                ["MonsterTellsEnabled_Changed"] = OnMonsterTellsEnabledChanged,
            },
            gamepadIsEnabledCallback = AreMonsterTellsEnabled,
            gamepadHasEnabledDependencies = true,
        },
        --Options_Gameplay_MonsterTellsFriendlyColor
        [COMBAT_SETTING_MONSTER_TELLS_FRIENDLY_COLOR] =
        {
            controlType = OPTIONS_COLOR,
            system = SETTING_TYPE_COMBAT,
            settingId = COMBAT_SETTING_MONSTER_TELLS_FRIENDLY_COLOR,
            panel = SETTING_PANEL_GAMEPLAY,
            text = SI_INTERFACE_OPTIONS_COMBAT_MONSTER_TELLS_FRIENDLY_COLOR,
            tooltipText = SI_INTERFACE_OPTIONS_COMBAT_MONSTER_TELLS_FRIENDLY_COLOR_TOOLTIP,
            eventCallbacks =
            {
                ["MonsterTellsEnabled_Changed"] = OnMonsterTellsOrColorSwapEnabledChanged,
                ["MonsterTellsColorSwapEnabled_Changed"] = OnMonsterTellsOrColorSwapEnabledChanged,
            },
            gamepadIsEnabledCallback = IsMonsterTellsColorSwapEnabled,
        },
        --Options_Gameplay_MonsterTellsFriendlyBrightness
        [COMBAT_SETTING_MONSTER_TELLS_FRIENDLY_BRIGHTNESS] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_COMBAT,
            settingId = COMBAT_SETTING_MONSTER_TELLS_FRIENDLY_BRIGHTNESS,
            panel = SETTING_PANEL_GAMEPLAY,
            text = SI_INTERFACE_OPTIONS_COMBAT_MONSTER_TELLS_FRIENDLY_BRIGHTNESS,
            tooltipText = SI_INTERFACE_OPTIONS_COMBAT_MONSTER_TELLS_FRIENDLY_BRIGHTNESS_TOOLTIP,
            minValue = 1,
            maxValue = 50,
            showValue = true,
            eventCallbacks =
            {
                ["MonsterTellsEnabled_Changed"] = OnMonsterTellsOrColorSwapEnabledChanged,
                ["MonsterTellsColorSwapEnabled_Changed"] = OnMonsterTellsOrColorSwapEnabledChanged,
            },
            gamepadIsEnabledCallback = IsMonsterTellsColorSwapEnabled,
        },
        --Options_Gameplay_MonsterTellsEnemyColor
        [COMBAT_SETTING_MONSTER_TELLS_ENEMY_COLOR] =
        {
            controlType = OPTIONS_COLOR,
            system = SETTING_TYPE_COMBAT,
            settingId = COMBAT_SETTING_MONSTER_TELLS_ENEMY_COLOR,
            panel = SETTING_PANEL_GAMEPLAY,
            text = SI_INTERFACE_OPTIONS_COMBAT_MONSTER_TELLS_ENEMY_COLOR,
            tooltipText = SI_INTERFACE_OPTIONS_COMBAT_MONSTER_TELLS_ENEMY_COLOR_TOOLTIP,
            eventCallbacks =
            {
                ["MonsterTellsEnabled_Changed"] = OnMonsterTellsOrColorSwapEnabledChanged,
                ["MonsterTellsColorSwapEnabled_Changed"] = OnMonsterTellsOrColorSwapEnabledChanged,
            },
            gamepadIsEnabledCallback = IsMonsterTellsColorSwapEnabled,
        },
        --Options_Gameplay_MonsterTellsEnemyBrightness
        [COMBAT_SETTING_MONSTER_TELLS_ENEMY_BRIGHTNESS] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_COMBAT,
            settingId = COMBAT_SETTING_MONSTER_TELLS_ENEMY_BRIGHTNESS,
            panel = SETTING_PANEL_GAMEPLAY,
            text = SI_INTERFACE_OPTIONS_COMBAT_MONSTER_TELLS_ENEMY_BRIGHTNESS,
            tooltipText = SI_INTERFACE_OPTIONS_COMBAT_MONSTER_TELLS_ENEMY_BRIGHTNESS_TOOLTIP,
            minValue = 1,
            maxValue = 50,
            showValue = true,
            eventCallbacks =
            {
                ["MonsterTellsEnabled_Changed"] = OnMonsterTellsOrColorSwapEnabledChanged,
                ["MonsterTellsColorSwapEnabled_Changed"] = OnMonsterTellsOrColorSwapEnabledChanged,
            },
            gamepadIsEnabledCallback = IsMonsterTellsColorSwapEnabled,
        },
        --Options_Gameplay_DodgeDoubleTap
        [COMBAT_SETTING_ROLL_DODGE_DOUBLE_TAP] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_COMBAT,
            panel = SETTING_PANEL_GAMEPLAY,
            settingId = COMBAT_SETTING_ROLL_DODGE_DOUBLE_TAP,
            text = SI_INTERFACE_OPTIONS_COMBAT_ROLL_DODGE_ENABLED,
            tooltipText = SI_INTERFACE_OPTIONS_COMBAT_ROLL_DODGE_ENABLED_TOOLTIP,
            events = {[true] = "DoubleTapRollDodgeEnabled_On", [false] = "DoubleTapRollDodgeEnabled_Off",},
        },
        --Options_Gameplay_RollDodgeTime
        [COMBAT_SETTING_ROLL_DODGE_WINDOW] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_COMBAT,
            settingId = COMBAT_SETTING_ROLL_DODGE_WINDOW,
            panel = SETTING_PANEL_GAMEPLAY,
            text = SI_INTERFACE_OPTIONS_COMBAT_ROLL_DODGE_WINDOW,
            tooltipText = SI_INTERFACE_OPTIONS_COMBAT_ROLL_DODGE_WINDOW_TOOLTIP,
            minValue = 75,
            maxValue = 275,
            
            showValue = true,
            valueTextFormatter = SI_INTERFACE_OPTIONS_COMBAT_ROLL_DODGE_WINDOW_MS,
            
            eventCallbacks =
            {
                ["DoubleTapRollDodgeEnabled_On"]    = ZO_Options_SetOptionActive,
                ["DoubleTapRollDodgeEnabled_Off"]   = ZO_Options_SetOptionInactive,
            },
        },
        --Options_Gameplay_ClampGroundTarget
        [COMBAT_SETTING_CLAMP_GROUND_TARGET_ENABLED] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_COMBAT,
            settingId = COMBAT_SETTING_CLAMP_GROUND_TARGET_ENABLED,
            panel = SETTING_PANEL_GAMEPLAY,
            text = SI_INTERFACE_OPTIONS_COMBAT_CLAMP_GROUND_TARGET_ENABLED,
            tooltipText = SI_INTERFACE_OPTIONS_COMBAT_CLAMP_GROUND_TARGET_ENABLED_TOOLTIP,
        },
        --Options_Gameplay_PreventAttackingInnocents
        [COMBAT_SETTING_PREVENT_ATTACKING_INNOCENTS] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_COMBAT,
            settingId = COMBAT_SETTING_PREVENT_ATTACKING_INNOCENTS,
            panel = SETTING_PANEL_GAMEPLAY,
            text = SI_INTERFACE_OPTIONS_COMBAT_PREVENT_ATTACKING_INNOCENTS,
            tooltipText = SI_INTERFACE_OPTIONS_COMBAT_PREVENT_ATTACKING_INNOCENTS_TOOLTIP,
        },
        --Options_Gameplay_QuickCastGroundAbilities
        [COMBAT_SETTING_QUICK_CAST_GROUND_ABILITIES] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_COMBAT,
            panel = SETTING_PANEL_GAMEPLAY,
            settingId = COMBAT_SETTING_QUICK_CAST_GROUND_ABILITIES,
            text = SI_INTERFACE_OPTIONS_COMBAT_QUICK_CAST_GROUND_ABILITIES,
            tooltipText = SI_INTERFACE_OPTIONS_COMBAT_QUICK_CAST_GROUND_ABILITIES_TOOLTIP,
            valid = {QUICK_CAST_GROUND_ABILITIES_CHOICE_ON, QUICK_CAST_GROUND_ABILITIES_CHOICE_AUTOMATIC, QUICK_CAST_GROUND_ABILITIES_CHOICE_OFF,},
            valueStringPrefix = "SI_QUICKCASTGROUNDABILITIESCHOICE",
        },
        --Options_Gameplay_AllowCompanionAutoUltimate
        [COMBAT_SETTING_ALLOW_COMPANION_AUTO_ULTIMATE] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_COMBAT,
            settingId = COMBAT_SETTING_ALLOW_COMPANION_AUTO_ULTIMATE,
            panel = SETTING_PANEL_GAMEPLAY,
            text = SI_INTERFACE_OPTIONS_COMBAT_ALLOW_COMPANION_AUTO_ULTIMATE,
            tooltipText = SI_INTERFACE_OPTIONS_COMBAT_ALLOW_COMPANION_AUTO_ULTIMATE_TOOLTIP,
        },
        --Options_Gameplay_DamageShieldVisibility
        [COMBAT_SETTING_DAMAGE_SHIELD_VISIBILITY] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_COMBAT,
            settingId = COMBAT_SETTING_DAMAGE_SHIELD_VISIBILITY,
            panel = SETTING_PANEL_GAMEPLAY,
            text = SI_INTERFACE_OPTIONS_COMBAT_DAMAGE_SHIELD_VISIBILITY,
            tooltipText = SI_INTERFACE_OPTIONS_COMBAT_DAMAGE_SHIELD_VISIBILITY_TOOLTIP,
            valid = {DAMAGE_SHIELD_VISIBILITY_SETTING_OFF, DAMAGE_SHIELD_VISIBILITY_SETTING_CURRENT_HEALTH, DAMAGE_SHIELD_VISIBILITY_SETTING_START_TIME},
            valueStringPrefix = "SI_DAMAGESHIELDVISIBILITYSETTING",
        },
    },

    --Gamepad
    [SETTING_TYPE_GAMEPAD] =
    {
        --Options_Gamepad_CameraSensitivity
        [GAMEPAD_SETTING_CAMERA_SENSITIVITY_X] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_GAMEPAD,
            settingId = GAMEPAD_SETTING_CAMERA_SENSITIVITY_X,
            panel = SETTING_PANEL_CAMERA,
            text = SI_GAMEPAD_OPTIONS_CAMERA_SENSITIVITY_X,
            minValue = 0.65,
            maxValue = 1.05,
            valueFormat = "%.2f",
            showValue = true,
            defaultMarker = 50,
            showValueMin = 0,
            showValueMax = 100,
        },
        --Options_Gamepad_CameraSensitivityY
        [GAMEPAD_SETTING_CAMERA_SENSITIVITY_Y] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_GAMEPAD,
            settingId = GAMEPAD_SETTING_CAMERA_SENSITIVITY_Y,
            panel = SETTING_PANEL_CAMERA,
            text = SI_GAMEPAD_OPTIONS_CAMERA_SENSITIVITY_Y,
            minValue = 0.65,
            maxValue = 1.05,
            valueFormat = "%.2f",
            showValue = true,
            defaultMarker = 50,
            showValueMin = 0,
            showValueMax = 100,
        },
        --Options_Gamepad_InvertY
        [GAMEPAD_SETTING_INVERT_Y] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_GAMEPAD,
            settingId = GAMEPAD_SETTING_INVERT_Y,
            panel = SETTING_PANEL_CAMERA,
            text = SI_GAMEPAD_OPTIONS_INVERT_Y,
        },
        --Options_Gamepad_InvertX
        [GAMEPAD_SETTING_INVERT_X] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_GAMEPAD,
            settingId = GAMEPAD_SETTING_INVERT_X,
            panel = SETTING_PANEL_CAMERA,
            text =  ZO_IsConsolePlatform() and SI_GAMEPAD_OPTIONS_INVERT_X or SI_GAMEPAD_OPTIONS_INVERT_X_PC,
        },
        --Options_Gamepad_Vibration
        [GAMEPAD_SETTING_VIBRATION] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_GAMEPAD,
            settingId = GAMEPAD_SETTING_VIBRATION,
            panel = SETTING_PANEL_GAMEPLAY,
            text = SI_GAMEPAD_OPTIONS_CAMERA_VIBRATION,
        },
        --Options_Gamepad_Deadzone_Inner_Right_Stick
        [GAMEPAD_SETTING_DEADZONE_INNER_RIGHT_STICK] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_GAMEPAD,
            settingId = GAMEPAD_SETTING_DEADZONE_INNER_RIGHT_STICK,
            panel = SETTING_PANEL_GAMEPLAY,
            text = SI_GAMEPAD_OPTIONS_DEADZONE_INNER_RIGHT_STICK,
            tooltipText = SI_GAMEPAD_OPTIONS_DEADZONE_INNER_RIGHT_STICK_TOOLTIP,
            minValue = 0.15,
            maxValue = 0.99,
            valueFormat = "%.2f",
            showValue = true,
            defaultMarker = 15,
            showValueMin = 20,
            showValueMax = 100,
        },
       --Options_Gamepad_Deadzone_Outer_Right_Stick
        [GAMEPAD_SETTING_DEADZONE_OUTER_RIGHT_STICK] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_GAMEPAD,
            settingId = GAMEPAD_SETTING_DEADZONE_OUTER_RIGHT_STICK,
            panel = SETTING_PANEL_GAMEPLAY,
            text = SI_GAMEPAD_OPTIONS_DEADZONE_OUTER_RIGHT_STICK,
            tooltipText = SI_GAMEPAD_OPTIONS_DEADZONE_OUTER_TOOLTIP,
            minValue = 0.15,
            maxValue = 0.99,
            valueFormat = "%.2f",
            showValue = true,
            defaultMarker = 100,
            showValueMin = 20,
            showValueMax = 100,
        },
        --Options_Gamepad_Deadzone_Inner_Left_Stick
        [GAMEPAD_SETTING_DEADZONE_INNER_LEFT_STICK] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_GAMEPAD,
            settingId = GAMEPAD_SETTING_DEADZONE_INNER_LEFT_STICK,
            panel = SETTING_PANEL_GAMEPLAY,
            text = SI_GAMEPAD_OPTIONS_DEADZONE_INNER_LEFT_STICK,
            tooltipText = SI_GAMEPAD_OPTIONS_DEADZONE_INNER_TOOLTIP,
            minValue = 0.15,
            maxValue = 0.99,
            valueFormat = "%.2f",
            showValue = true,
            defaultMarker = 25,
            showValueMin = 15,
            showValueMax = 100,
        },
        --Options_Gamepad_Deadzone_Outer_Left_Stick
        [GAMEPAD_SETTING_DEADZONE_OUTER_LEFT_STICK] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_GAMEPAD,
            settingId = GAMEPAD_SETTING_DEADZONE_OUTER_LEFT_STICK,
            panel = SETTING_PANEL_GAMEPLAY,
            text = SI_GAMEPAD_OPTIONS_DEADZONE_OUTER_LEFT_STICK,
            tooltipText = SI_GAMEPAD_OPTIONS_DEADZONE_OUTER_TOOLTIP,
            minValue = 0.15,
            maxValue = 0.99,
            valueFormat = "%.2f",
            showValue = true,
            defaultMarker = 100,
            showValueMin = 15,
            showValueMax = 100,
        },
        --Options_Gamepad_Deadzone_Trigger
        [GAMEPAD_SETTING_DEADZONE_TRIGGERS] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_GAMEPAD,
            settingId = GAMEPAD_SETTING_DEADZONE_TRIGGERS,
            panel = SETTING_PANEL_GAMEPLAY,
            text = SI_GAMEPAD_OPTIONS_DEADZONE_TRIGGERS,
            tooltipText = SI_GAMEPAD_OPTIONS_DEADZONE_TRIGGERS_TOOLTIP,
            minValue = 0.15,
            maxValue = 0.85,
            valueFormat = "%.2f",
            showValue = true,
            defaultMarker = 50,
            showValueMin = 15,
            showValueMax = 85,
        },
    },

    --Graphics
    [SETTING_TYPE_GRAPHICS] =
    {
        --Options_Video_DisplayMode
        [GRAPHICS_SETTING_FULLSCREEN] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_FULLSCREEN,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_DISPLAY_MODE,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_DISPLAY_MODE_TOOLTIP,
            valid = {FULLSCREEN_MODE_FULLSCREEN_EXCLUSIVE, FULLSCREEN_MODE_WINDOWED, FULLSCREEN_MODE_FULLSCREEN_WINDOWED, },
            valueStringPrefix = "SI_FULLSCREENMODE",
            exists = ZO_IsPCUI,

            events = {[FULLSCREEN_MODE_WINDOWED] = "DisplayModeNonExclusive", [FULLSCREEN_MODE_FULLSCREEN_WINDOWED] = "DisplayModeNonExclusive", [FULLSCREEN_MODE_FULLSCREEN_EXCLUSIVE] = "DisplayModeExclusive",},
        },
        --Options_Video_ActiveDisplay
        [GRAPHICS_SETTING_ACTIVE_DISPLAY] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_ACTIVE_DISPLAY,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_ACTIVE_DISPLAY,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_ACTIVE_DISPLAY_TOOLTIP,
            exists = IsActiveDisplayEnabledOnPlatform,

            gamepadIsEnabledCallback = function()
                return tonumber(GetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_FULLSCREEN)) == FULLSCREEN_MODE_FULLSCREEN_EXCLUSIVE
            end,

            eventCallbacks =
            {
                ["DisplayModeNonExclusive"] = ZO_Options_SetOptionInactive,
                ["DisplayModeExclusive"] = ZO_Options_SetOptionActive,
            },
        },
        --Options_Video_Resolution
        [GRAPHICS_SETTING_RESOLUTION] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_RESOLUTION,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_RESOLUTION,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_RESOLUTION_TOOLTIP,
            exists = ZO_IsPCUI,

            gamepadIsEnabledCallback = function()
                return tonumber(GetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_FULLSCREEN)) == FULLSCREEN_MODE_FULLSCREEN_EXCLUSIVE
            end,

            eventCallbacks =
            {
                ["DisplayModeNonExclusive"] = ZO_Options_SetOptionInactive,
                ["DisplayModeExclusive"] = ZO_Options_SetOptionActive,
                ["ActiveDisplayChanged"] = ZO_OptionsPanel_Video_OnActiveDisplayChanged,
            },
        },
        --Options_Video_VSync
        [GRAPHICS_SETTING_VSYNC] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_VSYNC,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_VSYNC,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_VSYNC_TOOLTIP,
            exists = ZO_IsPCUI,
        },
        --Options_Video_RenderThread
        [GRAPHICS_SETTING_RENDERTHREAD] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_RENDERTHREAD,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_RENDER_THREAD,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_RENDER_THREAD_TOOLTIP,
            mustRestartToApply = true,
            exists = ZO_IsWindowsUI,
        },
        --Options_Video_AntiAliasing_Type
        [GRAPHICS_SETTING_ANTIALIASING_TYPE] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_ANTIALIASING_TYPE,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_ANTI_ALIASING,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_ANTI_ALIASING_TOOLTIP,
            valid = ShouldShowDLSSSetting()
                    and { ANTIALIASING_TYPE_NONE, ANTIALIASING_TYPE_FXAA, ANTIALIASING_TYPE_TAA, ANTIALIASING_TYPE_DLSS, ANTIALIASING_TYPE_NVAA, }
                    or { ANTIALIASING_TYPE_NONE, ANTIALIASING_TYPE_FXAA, ANTIALIASING_TYPE_TAA, },

            valueStringPrefix = "SI_ANTIALIASINGTYPE",
            exists = ZO_IsPCUI,

            events = {
                [ANTIALIASING_TYPE_NONE] = "DLSSDisabled",
                [ANTIALIASING_TYPE_FXAA] = "DLSSDisabled",
                [ANTIALIASING_TYPE_TAA]  = "DLSSDisabled",
                [ANTIALIASING_TYPE_DLSS] = "DLSSEnabled",
                [ANTIALIASING_TYPE_NVAA] = "DLSSDisabled",
            },

            eventCallbacks =
            {
                ["FSREnabled"]  = function(control)
                    if (tonumber(GetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_ANTIALIASING_TYPE)) == ANTIALIASING_TYPE_DLSS) or
                       (tonumber(GetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_ANTIALIASING_TYPE)) == ANTIALIASING_TYPE_NVAA) then
                        SetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_ANTIALIASING_TYPE, ANTIALIASING_TYPE_TAA)
                        ZO_Options_UpdateOption(control)
                    end
                end,
            },
        },
        --Options_Video_Use_Background_FPS_Limit
        [GRAPHICS_SETTING_USE_BACKGROUND_FPS_LIMIT] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_USE_BACKGROUND_FPS_LIMIT,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_USE_BACKGROUND_FPS_LIMIT,
            tooltipText = SI_GRAPHICS_OPTIONS_USE_BACKGROUND_FPS_LIMIT_TOOLTIP,
            exists = ZO_IsPCUI,
            events = {
                [true] = "UseBackgroundFPSLimitToggled",
                [false] = "UseBackgroundFPSLimitToggled",
            },
        },
        --Options_Video_Background_FPS_Limit
        [GRAPHICS_SETTING_BACKGROUND_FPS_LIMIT] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_BACKGROUND_FPS_LIMIT,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_BACKGROUND_FPS_LIMIT,
            tooltipText = SI_GRAPHICS_OPTIONS_BACKGROUND_FPS_LIMIT_TOOLTIP,
            minValue = 10,
            maxValue = 100,
            valueFormat = "%d",
            showValue = true,
            showValueMin = 10,
            showValueMax = 100,
            exists = ZO_IsPCUI,
            eventCallbacks =
            {
                ["UseBackgroundFPSLimitToggled"] = ZO_OptionsPanel_Video_BackgroundFPSLimit_RefreshEnabled,
            }
        },
        --Options_Video_Gamma_Adjustment
        [GRAPHICS_SETTING_GAMMA_ADJUSTMENT] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_GAMMA_ADJUSTMENT,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_GAMMA_ADJUSTMENT,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_GAMMA_ADJUSTMENT_TOOLTIP,
            minValue = 75,
            maxValue = 150,
            valueFormat = "%.2f",
            exists = IsSystemNotUsingHDR,
        },
        --Options_Video_Graphics_Quality
        [GRAPHICS_SETTING_PRESETS] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_PRESETS,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_PRESETS,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_PRESETS_TOOLTIP,

            valid = IsMinSpecMachine() 
                    and {GRAPHICS_PRESETS_MINIMUM, GRAPHICS_PRESETS_LOW, GRAPHICS_PRESETS_MEDIUM, GRAPHICS_PRESETS_CUSTOM}
                    or {GRAPHICS_PRESETS_MINIMUM, GRAPHICS_PRESETS_LOW, GRAPHICS_PRESETS_MEDIUM, GRAPHICS_PRESETS_HIGH, GRAPHICS_PRESETS_ULTRA, GRAPHICS_PRESETS_MAXIMUM, GRAPHICS_PRESETS_CUSTOM},

            valueStringPrefix = "SI_GRAPHICSPRESETS",
            mustReloadSettings = true,
            mustPushApply = true,
            exists = ZO_IsPCUI,
        },
        --Options_Video_Texture_Resolution
        [GRAPHICS_SETTING_MIP_LOAD_SKIP_LEVELS] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_MIP_LOAD_SKIP_LEVELS,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_TEXTURE_RES,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_TEXTURE_RES_TOOLTIP,

            valid = IsMinSpecMachine() 
                    and {TEX_RES_CHOICE_LOW, TEX_RES_CHOICE_MEDIUM}
                    or {TEX_RES_CHOICE_LOW, TEX_RES_CHOICE_MEDIUM, TEX_RES_CHOICE_HIGH},

            valueStringPrefix = "SI_TEXTURERESOLUTIONCHOICE",
            mustPushApply = true,
            exists = ZO_IsPCUI,
        },
        --Options_Video_DLSS_Mode
        [GRAPHICS_SETTING_DLSS_MODE] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_DLSS_MODE,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_DLSS_MODE,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_DLSS_MODE_TOOLTIP,
            valid = {DLSS_MODE_QUALITY, DLSS_MODE_BALANCED, DLSS_MODE_PERFORMANCE},
            valueStringPrefix = "SI_DLSSMODE",
            exists = ZO_IsPCUI and ShouldShowDLSSSetting(),

            eventCallbacks =
            {
                ["DLSSEnabled"] = ZO_Options_SetOptionActive,
                ["DLSSDisabled"] = ZO_Options_SetOptionInactive,
            },
        },
        --Options_Video_FSR_Mode 
        [GRAPHICS_SETTING_FSR_MODE] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_FSR_MODE,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_FSR_MODE,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_FSR_MODE_TOOLTIP,
            valid = {FSR_MODE_OFF, FSR_MODE_ULTRA_QUALITY, FSR_MODE_QUALITY, FSR_MODE_BALANCED, FSR_MODE_PERFORMANCE},
            valueStringPrefix = "SI_FSRMODE",
            exists = ZO_IsPCUI and ShouldShowFSRSetting(),
            
            eventCallbacks =
            {
                ["DLSSEnabled"] = function(control)
                    SetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_FSR_MODE, FSR_MODE_OFF)
                    ZO_Options_UpdateOption(control)
                end,

                ["DLSSDisabled"] = function(control)
                    if tonumber(GetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_ANTIALIASING_TYPE)) == ANTIALIASING_TYPE_NVAA then
                        SetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_FSR_MODE, FSR_MODE_OFF)
                        ZO_Options_UpdateOption(control)
                    end
                end,
            },

            events = {
                [FSR_MODE_OFF]           = "FSRDisabled",
                [FSR_MODE_ULTRA_QUALITY] = "FSREnabled",
                [FSR_MODE_QUALITY]       = "FSREnabled",
                [FSR_MODE_BALANCED]      = "FSREnabled",
                [FSR_MODE_PERFORMANCE]   = "FSREnabled",
            },
        },
        --Options_Video_Sub_Sampling
        [GRAPHICS_SETTING_SUB_SAMPLING] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_SUB_SAMPLING,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_SUB_SAMPLING,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_SUB_SAMPLING_TOOLTIP,
            valid = {SUB_SAMPLING_MODE_LOW, SUB_SAMPLING_MODE_MEDIUM, SUB_SAMPLING_MODE_NORMAL},
            valueStringPrefix = "SI_SUBSAMPLINGMODE",
            exists = ZO_IsPCUI,

            eventCallbacks =
            {
                ["DLSSEnabled"]  = ZO_Options_SetOptionInactive,
                ["DLSSDisabled"] = ZO_Options_SetOptionActive,
                ["FSREnabled"]   = ZO_Options_SetOptionInactive,
                ["FSRDisabled"]  = ZO_Options_SetOptionActive,
            },
        },
        --Options_Video_Shadows
        [GRAPHICS_SETTING_SHADOWS] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_SHADOWS,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_SHADOWS,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_SHADOWS_TOOLTIP,
            valid = {SHADOWS_CHOICE_OFF, SHADOWS_CHOICE_LOW, SHADOWS_CHOICE_MEDIUM, SHADOWS_CHOICE_HIGH, SHADOWS_CHOICE_ULTRA},
            valueStringPrefix = "SI_SHADOWSCHOICE",
            mustPushApply = true,
            exists = ZO_IsPCUI,
        },
        --Options_Video_Screenspace_Water_Reflection_Quality
        [GRAPHICS_SETTING_SCREENSPACE_WATER_REFLECTION_QUALITY] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_SCREENSPACE_WATER_REFLECTION_QUALITY,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_SCREENSPACE_WATER_REFLECTION_QUALITY,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_SCREENSPACE_WATER_REFLECTION_QUALITY_TOOLTIP,
            valid = {SCREENSPACE_WATER_REFLECTION_QUALITY_OFF, SCREENSPACE_WATER_REFLECTION_QUALITY_LOW, SCREENSPACE_WATER_REFLECTION_QUALITY_MEDIUM, SCREENSPACE_WATER_REFLECTION_QUALITY_HIGH, SCREENSPACE_WATER_REFLECTION_QUALITY_ULTRA},
            valueStringPrefix = "SI_SCREENSPACEWATERREFLECTIONQUALITY",
            mustPushApply = true,
            exists = ZO_IsPCUI,
        },
        --Options_Video_Planar_Water_Reflection_Quality
        [GRAPHICS_SETTING_PLANAR_WATER_REFLECTION_QUALITY] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_PLANAR_WATER_REFLECTION_QUALITY,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_PLANAR_WATER_REFLECTION_QUALITY,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_PLANAR_WATER_REFLECTION_QUALITY_TOOLTIP,
            valid = {PLANAR_WATER_REFLECTION_QUALITY_OFF, PLANAR_WATER_REFLECTION_QUALITY_MEDIUM, PLANAR_WATER_REFLECTION_QUALITY_HIGH},
            valueStringPrefix = "SI_PLANARWATERREFLECTIONQUALITY",
            mustPushApply = true,
            exists = ZO_IsPCUI,
        },
        --Options_Video_Maximum_Particle_Systems
        [GRAPHICS_SETTING_PFX_GLOBAL_MAXIMUM] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_PFX_GLOBAL_MAXIMUM,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_MAXIMUM_PARTICLE_SYSTEMS,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_MAXIMUM_PARTICLE_SYSTEMS_TOOLTIP,
            minValue = 768,
            maxValue = 2048,
            valueFormat = "%d",
            showValue = true,
            showValueMin = 768,
            showValueMax = 2048,
            exists = ZO_IsPCUI,
        },
        --Options_Video_Particle_Suppression_Distance
        [GRAPHICS_SETTING_PFX_SUPPRESS_DISTANCE] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_PFX_SUPPRESS_DISTANCE,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_PARTICLE_SUPPRESSION_DISTANCE,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_PARTICLE_SUPPRESSION_DISTANCE_TOOLTIP,
            minValue = 35.0,
            maxValue = 100.0,
            valueFormat = "%d",
            showValue = true,
            showValueMin = 35,
            showValueMax = 100,
            exists = ZO_IsPCUI,
        },
        --Options_Video_View_Distance
        [GRAPHICS_SETTING_VIEW_DISTANCE] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_VIEW_DISTANCE,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_VIEW_DISTANCE,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_VIEW_DISTANCE_TOOLTIP,
            minValue = 0.4,
            maxValue = 2.0,
            valueFormat = "%.2f",
            showValue = true,
            showValueMin = 0,
            showValueMax = 100,
            exists = ZO_IsPCUI,
        },
        --Options_Video_Ambient_Occlusion
        [GRAPHICS_SETTING_AMBIENT_OCCLUSION_TYPE] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_AMBIENT_OCCLUSION_TYPE,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_AMBIENT_OCCLUSION_TYPE,
            tooltipText = IsMacUI()
                    and SI_GRAPHICS_OPTIONS_VIDEO_MAC_AMBIENT_OCCLUSION_TYPE_TOOLTIP
                    or SI_GRAPHICS_OPTIONS_VIDEO_WINDOWS_AMBIENT_OCCLUSION_TYPE_TOOLTIP,
            valid = IsMacUI()
                    and {AMBIENT_OCCLUSION_TYPE_NONE, AMBIENT_OCCLUSION_TYPE_SSAO, AMBIENT_OCCLUSION_TYPE_HBAO}
                    or {AMBIENT_OCCLUSION_TYPE_NONE, AMBIENT_OCCLUSION_TYPE_SSAO, AMBIENT_OCCLUSION_TYPE_HBAO, AMBIENT_OCCLUSION_TYPE_LSAO, AMBIENT_OCCLUSION_TYPE_SSGI},
            valueStringPrefix = "SI_AMBIENTOCCLUSIONTYPE",
            exists = ZO_IsPCUI,
        },
        --Options_Video_Occlusion_Culling_Enabled
        [GRAPHICS_SETTING_OCCLUSION_CULLING_ENABLED] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_OCCLUSION_CULLING_ENABLED,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_OCCLUSION_CULLING_ENABLED,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_OCCLUSION_CULLING_ENABLED_TOOLTIP,
            mustPushApply = true,
            exists = ZO_IsWindowsUI,
        },
        --Options_Video_Clutter_2D_Quality
        [GRAPHICS_SETTING_CLUTTER_2D_QUALITY] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_CLUTTER_2D_QUALITY,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_CLUTTER_2D_QUALITY,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_CLUTTER_2D_QUALITY_TOOLTIP,
            valid = { CLUTTER_QUALITY_OFF, CLUTTER_QUALITY_LOW, CLUTTER_QUALITY_MEDIUM, CLUTTER_QUALITY_HIGH, CLUTTER_QUALITY_ULTRA, },
            valueStringPrefix = "SI_CLUTTERQUALITY",
            exists = ZO_IsPCUI,
        },
        --Options_Video_Depth_Of_Field_Mode
        [GRAPHICS_SETTING_DEPTH_OF_FIELD_MODE] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_DEPTH_OF_FIELD_MODE,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_DEPTH_OF_FIELD_MODE,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_DEPTH_OF_FIELD_MODE_TOOLTIP,
            
            valid = IsMacUI()
                    and {DEPTH_OF_FIELD_MODE_OFF, DEPTH_OF_FIELD_MODE_SIMPLE, DEPTH_OF_FIELD_MODE_SMOOTH}
                    or {DEPTH_OF_FIELD_MODE_OFF, DEPTH_OF_FIELD_MODE_SIMPLE, DEPTH_OF_FIELD_MODE_SMOOTH, DEPTH_OF_FIELD_MODE_CIRCULAR},
            
            valueStringPrefix = "SI_DEPTHOFFIELDMODE",
            exists = ZO_IsPCUI,
        },
        -- Options_Video_Character_Resolution
        [GRAPHICS_SETTING_CHARACTER_RESOLUTION] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_CHARACTER_RESOLUTION,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_CHARACTER_RESOLUTION,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_CHARACTER_RESOLUTION_TOOLTIP,
            valid = { CHARACTER_RESOLUTION_LOW, CHARACTER_RESOLUTION_MEDIUM, CHARACTER_RESOLUTION_HIGH, CHARACTER_RESOLUTION_ULTRA },
            valueStringPrefix = "SI_CHARACTERRESOLUTION",
            exists = ZO_IsPCUI,
        },
        --Options_Video_Bloom
        [GRAPHICS_SETTING_BLOOM] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_BLOOM,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_BLOOM,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_BLOOM_TOOLTIP,
            exists = ZO_IsPCUI,
        },
        --Options_Video_Distortion
        [GRAPHICS_SETTING_DISTORTION] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_DISTORTION,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_DISTORTION,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_DISTORTION_TOOLTIP,
            exists = ZO_IsPCUI,
        },
        --Options_Video_God_Rays
        [GRAPHICS_SETTING_GOD_RAYS] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_GOD_RAYS,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_GOD_RAYS,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_GOD_RAYS_TOOLTIP,
            exists = ZO_IsPCUI,
        },
        [GRAPHICS_SETTING_CONSOLE_ENHANCED_RENDER_QUALITY] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_CONSOLE_ENHANCED_RENDER_QUALITY,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_CONSOLE_ENHANCED_RENDER_QUALITY,
            tooltipText = GetTooltipStringForRenderQualitySetting(),
            --valid = dynamically determined based on the system below,
            valueStringPrefix = "SI_CONSOLEENHANCEDRENDERQUALITY",
            mustPushApply = GetUIPlatform() == UI_PLATFORM_XBOX,
            exists = ZO_OptionsPanel_Video_HasConsoleRenderQualitySetting,
        },
        [GRAPHICS_SETTING_GRAPHICS_MODE_PS5] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_GRAPHICS_MODE_PS5,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_CONSOLE_ENHANCED_RENDER_QUALITY,
            tooltipText = SI_GRAPHICS_OPTIONS_CONSOLE_ENHANCED_RENDER_QUALITY_TOOLTIP_PS5,
            valid = { GRAPHICS_MODE_FIDELITY, GRAPHICS_MODE_PERFORMANCE },
            valueStringPrefix = "SI_GRAPHICSMODE",
            mustPushApply = false,
            exists = GetUIPlatform() == UI_PLATFORM_PS5
        },
        [GRAPHICS_SETTING_GRAPHICS_MODE_XBSS] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_GRAPHICS_MODE_XBSS,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_CONSOLE_ENHANCED_RENDER_QUALITY,
            tooltipText = SI_GRAPHICS_OPTIONS_CONSOLE_ENHANCED_RENDER_QUALITY_TOOLTIP_XBSS,
            valid = { GRAPHICS_MODE_FIDELITY, GRAPHICS_MODE_PERFORMANCE },
            valueStringPrefix = "SI_GRAPHICSMODE",
            mustPushApply = true,
            exists = DoesPlatformSupportGraphicSetting(GRAPHICS_SETTING_GRAPHICS_MODE_XBSS)
        },
        [GRAPHICS_SETTING_GRAPHICS_MODE_XBSX] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_GRAPHICS_MODE_XBSX,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_CONSOLE_ENHANCED_RENDER_QUALITY,
            tooltipText = SI_GRAPHICS_OPTIONS_CONSOLE_ENHANCED_RENDER_QUALITY_TOOLTIP_XBSX,
            valid = { GRAPHICS_MODE_FIDELITY, GRAPHICS_MODE_PERFORMANCE },
            valueStringPrefix = "SI_GRAPHICSMODE",
            mustPushApply = true,
            exists = DoesPlatformSupportGraphicSetting(GRAPHICS_SETTING_GRAPHICS_MODE_XBSX)
        },
        [GRAPHICS_SETTING_CAP_CONSOLE_FRAMERATE_IN_MENUS] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_CAP_CONSOLE_FRAMERATE_IN_MENUS,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_CAP_CONSOLE_FRAMERATE_IN_MENUS,
            tooltipText = SI_GRAPHICS_OPTIONS_CAP_CONSOLE_FRAMERATE_IN_MENUS_TOOLTIP,
            exists = DoesPlatformSupportFramerateCapInMenus,
            eventCallbacks =
            {
                ["OnGraphicsModeFidelitySelected"] = ZO_Options_SetOptionInactive,
                ["OnGraphicsModePerformanceSelected"] = ZO_Options_SetOptionActive,
            },
            gamepadIsEnabledCallback = function()
                if DoesPlatformSupportGraphicSetting(GRAPHICS_SETTING_GRAPHICS_MODE_PS5) then
                    return tonumber(GetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_GRAPHICS_MODE_PS5)) == GRAPHICS_MODE_PERFORMANCE
                elseif DoesPlatformSupportGraphicSetting(GRAPHICS_SETTING_GRAPHICS_MODE_XBSS) then
                    return tonumber(GetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_GRAPHICS_MODE_XBSS)) == GRAPHICS_MODE_PERFORMANCE
                elseif DoesPlatformSupportGraphicSetting(GRAPHICS_SETTING_GRAPHICS_MODE_XBSX) then
                    return tonumber(GetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_GRAPHICS_MODE_XBSX)) == GRAPHICS_MODE_PERFORMANCE
                end

                return true
            end,

        },
        [GRAPHICS_SETTING_ENERGY_SUSTAINABILITY_SCREEN_DIM_AND_RESOLUTION] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_ENERGY_SUSTAINABILITY_SCREEN_DIM_AND_RESOLUTION,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_ENERGY_SUSTAINABILITY_SCREEN_DIM_AND_RESOLUTION,
            tooltipText = function()
                if IsConsoleUI() then
                    return GetString(SI_GRAPHICS_OPTIONS_ENERGY_SUSTAINABILITY_SCREEN_DIM_AND_RESOLUTION_CONSOLE_TOOLTIP)
                else
                    return GetString(SI_GRAPHICS_OPTIONS_ENERGY_SUSTAINABILITY_SCREEN_DIM_AND_RESOLUTION_PC_TOOLTIP)
                end
            end,
            valid = {ENERGY_SUSTAINABILITY_SCREEN_DIM_AND_RESOLUTION_FIVE_MINS, ENERGY_SUSTAINABILITY_SCREEN_DIM_AND_RESOLUTION_TEN_MINS, ENERGY_SUSTAINABILITY_SCREEN_DIM_AND_RESOLUTION_DISABLED},
            valueStringPrefix = "SI_ENERGYSUSTAINABILITYSCREENDIMANDRESOLUTION",
            exists = DoesPlatformSupportScreenDimAndResolutionDrop,
        },
        [GRAPHICS_SETTING_HDR_ENABLED] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_HDR_ENABLED,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_HDR_ENABLED,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_HDR_ENABLED_TOOLTIP,
            valueStringPrefix = "SI_HDREnabled",
            visible = DoesSystemSupportHDR,
            exists = ZO_IsPCUI,
            mustRestartToApply = true,
            events = {
                [true]  = "OnHDRToggled",
                [false] = "OnHDRToggled",
            },
        },
        [GRAPHICS_SETTING_HDR_PEAK_BRIGHTNESS] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_HDR_PEAK_BRIGHTNESS,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_HDR_PEAK_BRIGHTNESS,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_HDR_PEAK_BRIGHTNESS_TOOLTIP,
            minValue = 200,
            maxValue = 1000,
            valueFormat = "%.2f",
            visible = IsSystemUsingHDR,
        },
		
        [GRAPHICS_SETTING_HDR_SCENE_BRIGHTNESS] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_HDR_SCENE_BRIGHTNESS,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_HDR_SCENE_BRIGHTNESS,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_HDR_SCENE_BRIGHTNESS_TOOLTIP,
            minValue = 0.8,
            maxValue = 2.0,
            valueFormat = "%.2f",
            visible = IsSystemUsingHDR,
        },
        [GRAPHICS_SETTING_HDR_SCENE_CONTRAST] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_HDR_SCENE_CONTRAST,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_HDR_SCENE_CONTRAST,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_HDR_SCENE_CONTRAST_TOOLTIP,
            minValue = 0.8,
            maxValue = 2.4,
            valueFormat = "%.2f",
            visible = IsSystemUsingHDR,
        },
        [GRAPHICS_SETTING_HDR_UI_BRIGHTNESS] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_HDR_UI_BRIGHTNESS,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_HDR_UI_BRIGHTNESS,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_HDR_UI_BRIGHTNESS_TOOLTIP,
            minValue = 0.8,
            maxValue = 1.5,
            valueFormat = "%.2f",
            visible = IsSystemUsingHDR,
        },
        [GRAPHICS_SETTING_HDR_UI_CONTRAST] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_HDR_UI_CONTRAST,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_HDR_UI_CONTRAST,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_HDR_UI_CONTRAST_TOOLTIP,
            minValue = 0.8,
            maxValue = 1.4,
            valueFormat = "%.2f",
            visible = IsSystemUsingHDR,
        },
        [GRAPHICS_SETTING_HDR_MODE] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_HDR_MODE,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_HDR_MODE,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_HDR_MODE_TOOLTIP,
            valid = { HDR_MODE_DEFAULT, HDR_MODE_VIBRANT },
            valueStringPrefix = "SI_HDRMODE",
            visible = IsSystemUsingHDR,
            exists = IsConsoleUI,
        },
        [GRAPHICS_SETTING_SHOW_ADDITIONAL_ALLY_EFFECTS] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_SHOW_ADDITIONAL_ALLY_EFFECTS,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_SHOW_ADDITIONAL_ALLY_EFFECTS,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_SHOW_ADDITIONAL_ALLY_EFFECTS_TOOLTIP,
            exists = ZO_IsPCUI,
        },
        [GRAPHICS_SETTING_VFX_SELF_INTENSITY] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_VFX_SELF_INTENSITY,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_VFX_SELF_INTENSITY,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_VFX_SELF_INTENSITY_TOOLTIP,
            valid = { VFX_INTENSITY_VALUE_NORMAL, VFX_INTENSITY_VALUE_LOW, VFX_INTENSITY_VALUE_MINIMAL},
            valueStringPrefix = "SI_VFXINTENSITYVALUE",
        },
        [GRAPHICS_SETTING_VFX_FRIENDLY_INTENSITY] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_VFX_FRIENDLY_INTENSITY,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_VFX_FRIENDLY_INTENSITY,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_VFX_FRIENDLY_INTENSITY_TOOLTIP,
            valid = { VFX_INTENSITY_VALUE_NORMAL, VFX_INTENSITY_VALUE_LOW, VFX_INTENSITY_VALUE_MINIMAL},
            valueStringPrefix = "SI_VFXINTENSITYVALUE",
        },
        [GRAPHICS_SETTING_VFX_ENEMY_INTENSITY] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_GRAPHICS,
            settingId = GRAPHICS_SETTING_VFX_ENEMY_INTENSITY,
            panel = SETTING_PANEL_VIDEO,
            text = SI_GRAPHICS_OPTIONS_VIDEO_VFX_ENEMY_INTENSITY,
            tooltipText = SI_GRAPHICS_OPTIONS_VIDEO_VFX_ENEMY_INTENSITY_TOOLTIP,
            valid = { VFX_INTENSITY_VALUE_NORMAL, VFX_INTENSITY_VALUE_LOW, VFX_INTENSITY_VALUE_MINIMAL},
            valueStringPrefix = "SI_VFXINTENSITYVALUE",
        },
    },

    --In world
    [SETTING_TYPE_IN_WORLD] =
    {
        --Options_Gameplay_HidePolymorphHelm
        [IN_WORLD_UI_SETTING_HIDE_POLYMORPH_HELM] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_IN_WORLD,
            panel = SETTING_PANEL_GAMEPLAY,
            settingId = IN_WORLD_UI_SETTING_HIDE_POLYMORPH_HELM,
            text = SI_INTERFACE_OPTIONS_HIDE_POLYMORPH_HELM,
            tooltipText = SI_INTERFACE_OPTIONS_HIDE_POLYMORPH_HELM_TOOLTIP,
        },

        --Options_Gameplay_HideMountStaminaUpgrade
        [IN_WORLD_UI_SETTING_HIDE_MOUNT_STAMINA_UPGRADE] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_IN_WORLD,
            panel = SETTING_PANEL_GAMEPLAY,
            settingId = IN_WORLD_UI_SETTING_HIDE_MOUNT_STAMINA_UPGRADE,
            text = SI_INTERFACE_OPTIONS_HIDE_MOUNT_STAMINA_UPGRADE,
            tooltipText = SI_INTERFACE_OPTIONS_HIDE_MOUNT_STAMINA_UPGRADE_TOOLTIP,
        },

        --Options_Gameplay_HideMountSpeedUpgrade
        [IN_WORLD_UI_SETTING_HIDE_MOUNT_SPEED_UPGRADE] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_IN_WORLD,
            panel = SETTING_PANEL_GAMEPLAY,
            settingId = IN_WORLD_UI_SETTING_HIDE_MOUNT_SPEED_UPGRADE,
            text = SI_INTERFACE_OPTIONS_HIDE_MOUNT_SPEED_UPGRADE,
            tooltipText = SI_INTERFACE_OPTIONS_HIDE_MOUNT_SPEED_UPGRADE_TOOLTIP,
        },

        --Options_Gameplay_HideMountInventoryUpgrade
        [IN_WORLD_UI_SETTING_HIDE_MOUNT_INVENTORY_UPGRADE] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_IN_WORLD,
            panel = SETTING_PANEL_GAMEPLAY,
            settingId = IN_WORLD_UI_SETTING_HIDE_MOUNT_INVENTORY_UPGRADE,
            text = SI_INTERFACE_OPTIONS_HIDE_MOUNT_INVENTORY_UPGRADE,
            tooltipText = SI_INTERFACE_OPTIONS_HIDE_MOUNT_INVENTORY_UPGRADE_TOOLTIP,
        },		

        --Options_Gameplay_DefaultSoulGem
        [IN_WORLD_UI_SETTING_DEFAULT_SOUL_GEM] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_IN_WORLD,
            panel = SETTING_PANEL_GAMEPLAY,
            settingId = IN_WORLD_UI_SETTING_DEFAULT_SOUL_GEM,
            text = SI_GAMEPLAY_OPTIONS_DEFAULT_SOUL_GEM,
            tooltipText = SI_GAMEPLAY_OPTIONS_DEFAULT_SOUL_GEM_TOOLTIP,
            valid = {DEFAULT_SOUL_GEM_CHOICE_GOLD, DEFAULT_SOUL_GEM_CHOICE_CROWN,},
            gamepadValidStringOverrides = {SI_GAMEPAD_OPTIONS_DEFAULT_SOUL_GEM_CHOICE_GOLD, SI_GAMEPAD_OPTIONS_DEFAULT_SOUL_GEM_CHOICE_CROWNS},
            valueStringPrefix = "SI_DEFAULTSOULGEMCHOICE",
        },

        --Options_Gameplay_FootInverseKinematics
        [IN_WORLD_UI_SETTING_FOOT_INVERSE_KINEMATICS] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_IN_WORLD,
            settingId = IN_WORLD_UI_SETTING_FOOT_INVERSE_KINEMATICS,
            panel = SETTING_PANEL_GAMEPLAY,
            text = SI_INTERFACE_OPTIONS_FOOT_INVERSE_KINEMATICS,
            tooltipText = SI_INTERFACE_OPTIONS_FOOT_INVERSE_KINEMATICS_TOOLTIP,
        },

        --Options_Gameplay_LimitFollowersInTowns
        [IN_WORLD_UI_SETTING_LIMIT_FOLLOWERS_IN_TOWNS] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_IN_WORLD,
            settingId = IN_WORLD_UI_SETTING_LIMIT_FOLLOWERS_IN_TOWNS,
            panel = SETTING_PANEL_GAMEPLAY,
            text = SI_INTERFACE_OPTIONS_LIMIT_FOLLOWERS_IN_TOWNS,
            tooltipText = SI_INTERFACE_OPTIONS_LIMIT_FOLLOWERS_IN_TOWNS_TOOLTIP,
        },
		
        --Options_Gameplay_ToggleSprint
        [IN_WORLD_UI_SETTING_TOGGLE_SPRINT] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_IN_WORLD,
            settingId = IN_WORLD_UI_SETTING_TOGGLE_SPRINT,
            panel = SETTING_PANEL_GAMEPLAY,
            text = SI_INTERFACE_OPTIONS_TOGGLE_SPRINT,
            tooltipText = SI_INTERFACE_OPTIONS_TOGGLE_SPRINT_TOOLTIP,
        },

        --Options_Gameplay_CompanionReactions
        [IN_WORLD_UI_SETTING_COMPANION_REACTION_FREQUENCY] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_IN_WORLD,
            panel = SETTING_PANEL_GAMEPLAY,
            settingId = IN_WORLD_UI_SETTING_COMPANION_REACTION_FREQUENCY,
            text = SI_INTERFACE_OPTIONS_COMPANION_REACTIONS,
            tooltipText = SI_INTERFACE_OPTIONS_COMPANION_REACTIONS_TOOLTIP,
            valid = { COMPANION_REACTION_FREQUENCY_RATE_VERY_LOW, COMPANION_REACTION_FREQUENCY_RATE_LOW, COMPANION_REACTION_FREQUENCY_RATE_NORMAL, COMPANION_REACTION_FREQUENCY_RATE_HIGH },
            valueStringPrefix = "SI_COMPANIONREACTIONFREQUENCYRATE",
        },

        --Options_Gameplay_CompanionPassengerPreference
        [IN_WORLD_UI_SETTING_COMPANION_PASSENGER_PREFERENCE] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_IN_WORLD,
            panel = SETTING_PANEL_GAMEPLAY,
            settingId = IN_WORLD_UI_SETTING_COMPANION_PASSENGER_PREFERENCE,
            text = SI_INTERFACE_OPTIONS_COMPANION_PASSENGER_PREFERENCE,
            tooltipText = SI_INTERFACE_OPTIONS_COMPANION_PASSENGER_PREFERENCE_TOOLTIP,
            valid = { COMPANION_PASSENGER_PREFERENCE_ALWAYS, COMPANION_PASSENGER_PREFERENCE_NEVER, COMPANION_PASSENGER_PREFERENCE_WHEN_PLAYER_NOT_GROUPED, },
            valueStringPrefix = "SI_COMPANIONPASSENGERPREFERENCE",
        },
        --Options_Nameplates_GlowThickness
        [IN_WORLD_UI_SETTING_GLOW_THICKNESS] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_IN_WORLD,
            settingId = IN_WORLD_UI_SETTING_GLOW_THICKNESS,
            panel = SETTING_PANEL_NAMEPLATES,
            text = SI_INTERFACE_OPTIONS_GLOWS_THICKNESS,
            tooltipText = SI_INTERFACE_OPTIONS_GLOWS_THICKNESS_TOOLTIP,
        
            valueFormat = "%f",
            showValue = true,
            showValueMin = 0,
            showValueMax = 100,
        },
        --Options_Nameplates_TargetGlowCheck
        [IN_WORLD_UI_SETTING_TARGET_GLOW_ENABLED] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_IN_WORLD,
            panel = SETTING_PANEL_NAMEPLATES,
            settingId = IN_WORLD_UI_SETTING_TARGET_GLOW_ENABLED,
            text = SI_INTERFACE_OPTIONS_TARGET_GLOWS_ENABLED,
            tooltipText = SI_INTERFACE_OPTIONS_TARGET_GLOWS_ENABLED_TOOLTIP,
            events = {[true] = "TargetGlowEnabled_On", [false] = "TargetGlowEnabled_Off",},
            gamepadHasEnabledDependencies = true,
        },
        --Options_Nameplates_TargetGlowIntensity
        [IN_WORLD_UI_SETTING_TARGET_GLOW_INTENSITY] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_IN_WORLD,
            settingId = IN_WORLD_UI_SETTING_TARGET_GLOW_INTENSITY,
            panel = SETTING_PANEL_NAMEPLATES,
            text = SI_INTERFACE_OPTIONS_TARGET_GLOWS_INTENSITY,
            tooltipText = SI_INTERFACE_OPTIONS_TARGET_GLOWS_INTENSITY_TOOLTIP,

            valueFormat = "%f",
            showValue = true,
            showValueMin = 0,
            showValueMax = 100,

            eventCallbacks =
            {
                ["TargetGlowEnabled_On"]    = ZO_Options_SetOptionActive,
                ["TargetGlowEnabled_Off"]   = ZO_Options_SetOptionInactive,
            },
            gamepadIsEnabledCallback = function() 
                                            return tonumber(GetSetting(SETTING_TYPE_IN_WORLD, IN_WORLD_UI_SETTING_TARGET_GLOW_ENABLED)) ~= 0
                                        end,
        },
        --Options_Nameplates_InteractableGlowCheck
        [IN_WORLD_UI_SETTING_INTERACTABLE_GLOW_ENABLED] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_IN_WORLD,
            panel = SETTING_PANEL_NAMEPLATES,
            settingId = IN_WORLD_UI_SETTING_INTERACTABLE_GLOW_ENABLED,
            text = SI_INTERFACE_OPTIONS_INTERACTABLE_GLOWS_ENABLED,
            tooltipText = SI_INTERFACE_OPTIONS_INTERACTABLE_GLOWS_ENABLED_TOOLTIP,
            events = {[true] = "InteractableGlowEnabled_On", [false] = "InteractableGlowEnabled_Off",},
            gamepadHasEnabledDependencies = true,
        },
        --Options_Nameplates_InteractableGlowIntensity
        [IN_WORLD_UI_SETTING_INTERACTABLE_GLOW_INTENSITY] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_IN_WORLD,
            settingId = IN_WORLD_UI_SETTING_INTERACTABLE_GLOW_INTENSITY,
            panel = SETTING_PANEL_NAMEPLATES,
            text = SI_INTERFACE_OPTIONS_INTERACTABLE_GLOWS_INTENSITY,
            tooltipText = SI_INTERFACE_OPTIONS_INTERACTABLE_GLOWS_INTENSITY_TOOLTIP,

            valueFormat = "%f",
            showValue = true,
            showValueMin = 0,
            showValueMax = 100,

            eventCallbacks =
            {
                ["InteractableGlowEnabled_On"]    = ZO_Options_SetOptionActive,
                ["InteractableGlowEnabled_Off"]   = ZO_Options_SetOptionInactive,
            },
            gamepadIsEnabledCallback = function() 
                                            return tonumber(GetSetting(SETTING_TYPE_IN_WORLD, IN_WORLD_UI_SETTING_INTERACTABLE_GLOW_ENABLED)) ~= 0
                                        end,
        },
        --Options_Nameplates_TargetMarkerSize
        [IN_WORLD_UI_SETTING_TARGET_MARKER_SIZE] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_IN_WORLD,
            settingId = IN_WORLD_UI_SETTING_TARGET_MARKER_SIZE,
            panel = SETTING_PANEL_NAMEPLATES,
            text = SI_INTERFACE_OPTIONS_TARGET_MARKER_SIZE,
            tooltipText = SI_INTERFACE_OPTIONS_TARGET_MARKER_SIZE_TOOLTIP,

            minValue = 1.0,
            maxValue = 3.0,
            valueFormat = "%.2f",
            showValue = true,
            showValueMin = 1,
            showValueMax = 100,

            eventCallbacks =
            {
                ["TargetMarkersEnabled_On"]    = ZO_Options_SetOptionActive,
                ["TargetMarkersEnabled_Off"]   = ZO_Options_SetOptionInactive,
            },
            gamepadIsEnabledCallback = function()
                                            return tonumber(GetSetting(SETTING_TYPE_NAMEPLATES, NAMEPLATE_TYPE_TARGET_MARKERS)) ~= 0
                                        end,
        },
    },

    --Language Settings
    [SETTING_TYPE_LANGUAGE] =
    {
        --Options_Social_UseProfanityFilter
        [LANGUAGE_SETTING_USE_PROFANITY_FILTER] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_LANGUAGE,
            settingId = LANGUAGE_SETTING_USE_PROFANITY_FILTER,
            panel = SETTING_PANEL_SOCIAL,
            text = SI_INTERFACE_OPTIONS_LANGUAGE_USE_PROFANITY_FILTER,
            tooltipText = SI_INTERFACE_OPTIONS_LANGUAGE_USE_PROFANITY_FILTER_TOOLTIP,
            events = {[false] = "ProfanityFilter_Off", [true] = "ProfanityFilter_On",},
        },
    },

    --Loot
    [SETTING_TYPE_LOOT] =
    {
        --Options_Gameplay_UseAoeLoot
        [LOOT_SETTING_AOE_LOOT] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_LOOT,
            settingId = LOOT_SETTING_AOE_LOOT,
            panel = SETTING_PANEL_GAMEPLAY,
            text = SI_INTERFACE_OPTIONS_LOOT_USE_AOELOOT,
            tooltipText = SI_INTERFACE_OPTIONS_LOOT_USE_AOELOOT_TOOLTIP,
        },
        --Options_Gameplay_UseAutoLoot
        [LOOT_SETTING_AUTO_LOOT] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_LOOT,
            settingId = LOOT_SETTING_AUTO_LOOT,
            panel = SETTING_PANEL_GAMEPLAY,
            text = SI_INTERFACE_OPTIONS_LOOT_USE_AUTOLOOT,
            tooltipText = SI_INTERFACE_OPTIONS_LOOT_USE_AUTOLOOT_TOOLTIP,
            events = {[true] = "AutoLoot_On", [false] = "AutoLoot_Off",},
            gamepadHasEnabledDependencies = true,
        },
        --Options_Gameplay_UseAutoLootStolen
        [LOOT_SETTING_AUTO_LOOT_STOLEN] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_LOOT,
            settingId = LOOT_SETTING_AUTO_LOOT_STOLEN,
            panel = SETTING_PANEL_GAMEPLAY,
            text = SI_INTERFACE_OPTIONS_LOOT_USE_AUTOLOOT_STOLEN,
            tooltipText = SI_INTERFACE_OPTIONS_LOOT_USE_AUTOLOOT_STOLEN_TOOLTIP,
            eventCallbacks =
            {
                ["AutoLoot_On"]    = ZO_Options_SetOptionActive,
                ["AutoLoot_Off"]   = ZO_Options_SetOptionInactive,
            },
            gamepadIsEnabledCallback = function()
                                            return tonumber(GetSetting(SETTING_TYPE_LOOT,LOOT_SETTING_AUTO_LOOT)) ~= 0
                                       end
        },
        --Options_Gameplay_PreventStealingPlaced
        [LOOT_SETTING_PREVENT_STEALING_PLACED] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_LOOT,
            settingId = LOOT_SETTING_PREVENT_STEALING_PLACED,
            panel = SETTING_PANEL_GAMEPLAY,
            text = SI_INTERFACE_OPTIONS_LOOT_PREVENT_STEALING_PLACED,
            tooltipText = SI_INTERFACE_OPTIONS_LOOT_PREVENT_STEALING_PLACED_TOOLTIP,
        },
        --Options_Gameplay_AutoAddToCraftBag
        [LOOT_SETTING_AUTO_ADD_TO_CRAFT_BAG] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_LOOT,
            settingId = LOOT_SETTING_AUTO_ADD_TO_CRAFT_BAG,
            panel = SETTING_PANEL_GAMEPLAY,
            text = SI_INTERFACE_OPTIONS_LOOT_AUTO_ADD_TO_CRAFT_BAG,
            tooltipText = SI_INTERFACE_OPTIONS_LOOT_AUTO_ADD_TO_CRAFT_BAG_TOOLTIP,
            gamepadIsEnabledCallback = IsESOPlusSubscriber,
            onInitializeFunction = function(control, isKeyboardControl)
                                        if isKeyboardControl then
                                            --ZO_Options_SetOptionActive/Inactive are keyboard only functions. The gamepad manages active state through
                                            --the gamepadIsEnabledCallback. Using ZO_Options_SetOptionActive/Inactive with gamepad controls will set them
                                            --to the keyboard colors and also doesn't handle the parametric list's selected state's impact.
                                            if IsESOPlusSubscriber() then
                                                ZO_Options_SetOptionActive(control)
                                            else 
                                                ZO_Options_SetOptionInactive(control)
                                            end
                                        end
                                    end
        },
        --Options_Gameplay_UseLootHistory
        [LOOT_SETTING_LOOT_HISTORY] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_LOOT,
            settingId = LOOT_SETTING_LOOT_HISTORY,
            panel = SETTING_PANEL_GAMEPLAY,
            text = SI_INTERFACE_OPTIONS_LOOT_TOGGLE_LOOT_HISTORY,
            tooltipText = SI_INTERFACE_OPTIONS_LOOT_TOGGLE_LOOT_HISTORY_TOOLTIP,
        },
    },

    --Nameplates and Healthbars
    [SETTING_TYPE_NAMEPLATES] =
    {
        --Options_Nameplates_AllNameplates
        [NAMEPLATE_TYPE_ALL_NAMEPLATES] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_NAMEPLATES,
            panel = SETTING_PANEL_NAMEPLATES,
            settingId = NAMEPLATE_TYPE_ALL_NAMEPLATES,
            text = SI_INTERFACE_OPTIONS_NAMEPLATES_ALL,
            tooltipText = SI_INTERFACE_OPTIONS_NAMEPLATES_ALL_TOOLTIP,
            events = {[false] = "AllNameplates_Off", [true] = "AllNameplates_On",},
            gamepadHasEnabledDependencies = true,
        },
        --Options_Nameplates_ShowPlayerTitles
        [NAMEPLATE_TYPE_SHOW_PLAYER_TITLES] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_NAMEPLATES,
            panel = SETTING_PANEL_NAMEPLATES,
            settingId = NAMEPLATE_TYPE_SHOW_PLAYER_TITLES,
            text = SI_INTERFACE_OPTIONS_NAMEPLATES_SHOW_PLAYER_TITLES,
            tooltipText = SI_INTERFACE_OPTIONS_NAMEPLATES_SHOW_PLAYER_TITLES_TOOLTIP,
            gamepadIsEnabledCallback = AreNameplatesEnabled,
            eventCallbacks =
            {
                ["AllNameplates_Off"]   = ZO_Options_SetOptionInactive,
                ["AllNameplates_On"]    = ZO_Options_SetOptionActive,
            },
        },
        --Options_Nameplates_ShowPlayerGuilds
        [NAMEPLATE_TYPE_SHOW_PLAYER_GUILDS] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_NAMEPLATES,
            panel = SETTING_PANEL_NAMEPLATES,
            settingId = NAMEPLATE_TYPE_SHOW_PLAYER_GUILDS,
            text = SI_INTERFACE_OPTIONS_NAMEPLATES_SHOW_PLAYER_GUILDS,
            tooltipText = SI_INTERFACE_OPTIONS_NAMEPLATES_SHOW_PLAYER_GUILDS_TOOLTIP,
            gamepadIsEnabledCallback = AreNameplatesEnabled,
            eventCallbacks =
            {
                ["AllNameplates_Off"]   = ZO_Options_SetOptionInactive,
                ["AllNameplates_On"]    = ZO_Options_SetOptionActive,
            },
        },
        --Options_Nameplates_Player
        [NAMEPLATE_TYPE_PLAYER_NAMEPLATE] = {text = SI_INTERFACE_OPTIONS_NAMEPLATES_PLAYER, tooltipText = SI_INTERFACE_OPTIONS_NAMEPLATES_PLAYER_TOOLTIP, system = SETTING_TYPE_NAMEPLATES, settingId =NAMEPLATE_TYPE_PLAYER_NAMEPLATE},
        --Options_Nameplates_PlayerDimmed
        [NAMEPLATE_TYPE_PLAYER_NAMEPLATE_HIGHLIGHT] = {text = SI_INTERFACE_OPTIONS_NAMEPLATES_HIGHLIGHT_PLAYER, tooltipText = SI_INTERFACE_OPTIONS_NAMEPLATES_HIGHLIGHT_PLAYER_TOOLTIP, system = SETTING_TYPE_NAMEPLATES, settingId =NAMEPLATE_TYPE_PLAYER_NAMEPLATE_HIGHLIGHT},
        --Options_Nameplates_GroupMember
        [NAMEPLATE_TYPE_GROUP_MEMBER_NAMEPLATES] = {text = SI_INTERFACE_OPTIONS_NAMEPLATES_GROUP_MEMBER, tooltipText = SI_INTERFACE_OPTIONS_NAMEPLATES_GROUP_MEMBER_TOOLTIP, system = SETTING_TYPE_NAMEPLATES, settingId =NAMEPLATE_TYPE_GROUP_MEMBER_NAMEPLATES},
        --Options_Nameplates_GroupMemberDimmed
        [NAMEPLATE_TYPE_GROUP_MEMBER_NAMEPLATES_HIGHLIGHT] = {text = SI_INTERFACE_OPTIONS_NAMEPLATES_HIGHLIGHT_GROUP_MEMBER, tooltipText = SI_INTERFACE_OPTIONS_NAMEPLATES_HIGHLIGHT_GROUP_MEMBER_TOOLTIP, system = SETTING_TYPE_NAMEPLATES, settingId =NAMEPLATE_TYPE_GROUP_MEMBER_NAMEPLATES_HIGHLIGHT},
        --Options_Nameplates_FriendlyNPC
        [NAMEPLATE_TYPE_FRIENDLY_NPC_NAMEPLATES] = {text = SI_INTERFACE_OPTIONS_NAMEPLATES_FRIENDLY_NPC, tooltipText = SI_INTERFACE_OPTIONS_NAMEPLATES_FRIENDLY_NPC_TOOLTIP, system = SETTING_TYPE_NAMEPLATES, settingId =NAMEPLATE_TYPE_FRIENDLY_NPC_NAMEPLATES},
        --Options_Nameplates_FriendlyNPCDimmed
        [NAMEPLATE_TYPE_FRIENDLY_NPC_NAMEPLATES_HIGHLIGHT] = {text = SI_INTERFACE_OPTIONS_NAMEPLATES_HIGHLIGHT_FRIENDLY_NPC, tooltipText = SI_INTERFACE_OPTIONS_NAMEPLATES_HIGHLIGHT_FRIENDLY_NPC_TOOLTIP, system = SETTING_TYPE_NAMEPLATES, settingId =NAMEPLATE_TYPE_FRIENDLY_NPC_NAMEPLATES_HIGHLIGHT},
        --Options_Nameplates_FriendlyPlayer
        [NAMEPLATE_TYPE_FRIENDLY_PLAYER_NAMEPLATES] = {text = SI_INTERFACE_OPTIONS_NAMEPLATES_FRIENDLY_PLAYER, tooltipText = SI_INTERFACE_OPTIONS_NAMEPLATES_FRIENDLY_PLAYER_TOOLTIP, system = SETTING_TYPE_NAMEPLATES, settingId =NAMEPLATE_TYPE_FRIENDLY_PLAYER_NAMEPLATES},
        --Options_Nameplates_FriendlyPlayerDimmed
        [NAMEPLATE_TYPE_FRIENDLY_PLAYER_NAMEPLATES_HIGHLIGHT] = {text = SI_INTERFACE_OPTIONS_NAMEPLATES_HIGHLIGHT_FRIENDLY_PLAYER, tooltipText = SI_INTERFACE_OPTIONS_NAMEPLATES_HIGHLIGHT_FRIENDLY_PLAYER_TOOLTIP, system = SETTING_TYPE_NAMEPLATES, settingId =NAMEPLATE_TYPE_FRIENDLY_PLAYER_NAMEPLATES_HIGHLIGHT},
        --Options_Nameplates_NeutralNPC
        [NAMEPLATE_TYPE_NEUTRAL_NPC_NAMEPLATES] = {text = SI_INTERFACE_OPTIONS_NAMEPLATES_NEUTRAL_NPC, tooltipText = SI_INTERFACE_OPTIONS_NAMEPLATES_NEUTRAL_NPC_TOOLTIP, system = SETTING_TYPE_NAMEPLATES, settingId =NAMEPLATE_TYPE_NEUTRAL_NPC_NAMEPLATES},
        --Options_Nameplates_NeutralNPCDimmed
        [NAMEPLATE_TYPE_NEUTRAL_NPC_NAMEPLATES_HIGHLIGHT] = {text = SI_INTERFACE_OPTIONS_NAMEPLATES_HIGHLIGHT_NEUTRAL_NPC, tooltipText = SI_INTERFACE_OPTIONS_NAMEPLATES_HIGHLIGHT_NEUTRAL_NPC_TOOLTIP, system = SETTING_TYPE_NAMEPLATES, settingId =NAMEPLATE_TYPE_NEUTRAL_NPC_NAMEPLATES_HIGHLIGHT},
        --Options_Nameplates_EnemyNPC
        [NAMEPLATE_TYPE_ENEMY_NPC_NAMEPLATES] = {text = SI_INTERFACE_OPTIONS_NAMEPLATES_ENEMY_NPC, tooltipText = SI_INTERFACE_OPTIONS_NAMEPLATES_ENEMY_NPC_TOOLTIP, system = SETTING_TYPE_NAMEPLATES, settingId =NAMEPLATE_TYPE_ENEMY_NPC_NAMEPLATES},
        --Options_Nameplates_EnemyNPCDimmed
        [NAMEPLATE_TYPE_ENEMY_NPC_NAMEPLATES_HIGHLIGHT] = {text = SI_INTERFACE_OPTIONS_NAMEPLATES_HIGHLIGHT_ENEMY_NPC, tooltipText = SI_INTERFACE_OPTIONS_NAMEPLATES_HIGHLIGHT_ENEMY_NPC_TOOLTIP, system = SETTING_TYPE_NAMEPLATES, settingId =NAMEPLATE_TYPE_ENEMY_NPC_NAMEPLATES_HIGHLIGHT},
        --Options_Nameplates_EnemyPlayer
        [NAMEPLATE_TYPE_ENEMY_PLAYER_NAMEPLATES] = {text = SI_INTERFACE_OPTIONS_NAMEPLATES_ENEMY_PLAYER, tooltipText = SI_INTERFACE_OPTIONS_NAMEPLATES_ENEMY_PLAYER_TOOLTIP, system = SETTING_TYPE_NAMEPLATES, settingId =NAMEPLATE_TYPE_ENEMY_PLAYER_NAMEPLATES},
        --Options_Nameplates_EnemyPlayerDimmed
        [NAMEPLATE_TYPE_ENEMY_PLAYER_NAMEPLATES_HIGHLIGHT] = {text = SI_INTERFACE_OPTIONS_NAMEPLATES_HIGHLIGHT_ENEMY_PLAYER, tooltipText = SI_INTERFACE_OPTIONS_NAMEPLATES_HIGHLIGHT_ENEMY_PLAYER_TOOLTIP, system = SETTING_TYPE_NAMEPLATES, settingId =NAMEPLATE_TYPE_ENEMY_PLAYER_NAMEPLATES_HIGHLIGHT},
        --Options_Nameplates_AllHB
        [NAMEPLATE_TYPE_ALL_HEALTHBARS] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_NAMEPLATES,
            settingId = NAMEPLATE_TYPE_ALL_HEALTHBARS,
            panel = SETTING_PANEL_NAMEPLATES,
            text = SI_INTERFACE_OPTIONS_HEALTHBARS_ALL,
            tooltipText = SI_INTERFACE_OPTIONS_HEALTHBARS_ALL_TOOLTIP,
            events = {[false] = "AllHealthBars_Off", [true] = "AllHealthBars_On", },
            gamepadHasEnabledDependencies = true,
        },
        --Options_Nameplates_HealthbarAlignment
        [NAMEPLATE_TYPE_HEALTHBAR_ALIGNMENT] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_NAMEPLATES,
            panel = SETTING_PANEL_NAMEPLATES,
            settingId = NAMEPLATE_TYPE_HEALTHBAR_ALIGNMENT,
            text = SI_INTERFACE_OPTIONS_HEALTHBAR_ALIGNMENT,
            tooltipText = SI_INTERFACE_OPTIONS_HEALTHBAR_ALIGNMENT_TOOLTIP,
            valueStringPrefix = "SI_NAMEPLATEDISPLAYCHOICE",
            valid = { NAMEPLATE_CHOICE_LEFT, NAMEPLATE_CHOICE_CENTER },
            gamepadIsEnabledCallback = AreHealthbarsEnabled,
            eventCallbacks =
            {
                ["AllHealthBars_Off"]   = ZO_Options_SetOptionInactive,
                ["AllHealthBars_On"]    = ZO_Options_SetOptionActive,
            },
        },
        --Options_Nameplates_HealthbarChaseBar
        [NAMEPLATE_TYPE_HEALTHBAR_CHASE_BAR] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_NAMEPLATES,
            panel = SETTING_PANEL_NAMEPLATES,
            settingId = NAMEPLATE_TYPE_HEALTHBAR_CHASE_BAR,
            text = SI_INTERFACE_OPTIONS_HEALTHBAR_CHASE_BAR,
            tooltipText = SI_INTERFACE_OPTIONS_HEALTHBAR_CHASE_BAR_TOOLTIP,
            gamepadIsEnabledCallback = AreHealthbarsEnabled,
            eventCallbacks =
            {
                ["AllHealthBars_Off"]   = ZO_Options_SetOptionInactive,
                ["AllHealthBars_On"]    = ZO_Options_SetOptionActive,
            },
        },
        --Options_Nameplates_HealthbarFrameBorder
        [NAMEPLATE_TYPE_HEALTHBAR_FRAME_BORDER] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_NAMEPLATES,
            panel = SETTING_PANEL_NAMEPLATES,
            settingId = NAMEPLATE_TYPE_HEALTHBAR_FRAME_BORDER,
            text = SI_INTERFACE_OPTIONS_HEALTHBAR_FRAME_BORDER,
            tooltipText = SI_INTERFACE_OPTIONS_HEALTHBAR_FRAME_BORDER_TOOLTIP,
            gamepadIsEnabledCallback = AreHealthbarsEnabled,
            eventCallbacks =
            {
                ["AllHealthBars_Off"]   = ZO_Options_SetOptionInactive,
                ["AllHealthBars_On"]    = ZO_Options_SetOptionActive,
            },
        },
        --Options_Nameplates_PlayerHB
        [NAMEPLATE_TYPE_PLAYER_HEALTHBAR] = {text = SI_INTERFACE_OPTIONS_HEALTHBARS_PLAYER, tooltipText = SI_INTERFACE_OPTIONS_HEALTHBARS_PLAYER_TOOLTIP, system = SETTING_TYPE_NAMEPLATES, settingId = NAMEPLATE_TYPE_PLAYER_HEALTHBAR},
        --Options_Nameplates_PlayerHBDimmed
        [NAMEPLATE_TYPE_PLAYER_HEALTHBAR_HIGHLIGHT] = {text = SI_INTERFACE_OPTIONS_HEALTHBARS_HIGHLIGHT_PLAYER, tooltipText = SI_INTERFACE_OPTIONS_HEALTHBARS_HIGHLIGHT_PLAYER_TOOLTIP, system = SETTING_TYPE_NAMEPLATES, settingId = NAMEPLATE_TYPE_PLAYER_HEALTHBAR_HIGHLIGHT},
        --Options_Nameplates_GroupMemberHB
        [NAMEPLATE_TYPE_GROUP_MEMBER_HEALTHBARS] = {text = SI_INTERFACE_OPTIONS_HEALTHBARS_GROUP_MEMBER, tooltipText = SI_INTERFACE_OPTIONS_HEALTHBARS_GROUP_MEMBER_TOOLTIP, system = SETTING_TYPE_NAMEPLATES, settingId = NAMEPLATE_TYPE_GROUP_MEMBER_HEALTHBARS},
        --Options_Nameplates_GroupMemberHBDimmed
        [NAMEPLATE_TYPE_GROUP_MEMBER_HEALTHBARS_HIGHLIGHT] = {text = SI_INTERFACE_OPTIONS_HEALTHBARS_HIGHLIGHT_GROUP_MEMBER, tooltipText = SI_INTERFACE_OPTIONS_HEALTHBARS_HIGHLIGHT_GROUP_MEMBER_TOOLTIP, system = SETTING_TYPE_NAMEPLATES, settingId = NAMEPLATE_TYPE_GROUP_MEMBER_HEALTHBARS_HIGHLIGHT},
        --Options_Nameplates_FriendlyNPCHB
        [NAMEPLATE_TYPE_FRIENDLY_NPC_HEALTHBARS] = {text = SI_INTERFACE_OPTIONS_HEALTHBARS_FRIENDLY_NPC, tooltipText = SI_INTERFACE_OPTIONS_HEALTHBARS_FRIENDLY_NPC_TOOLTIP, system = SETTING_TYPE_NAMEPLATES, settingId = NAMEPLATE_TYPE_FRIENDLY_NPC_HEALTHBARS},
        --Options_Nameplates_FriendlyNPCHBDimmed
        [NAMEPLATE_TYPE_FRIENDLY_NPC_HEALTHBARS_HIGHLIGHT] = {text = SI_INTERFACE_OPTIONS_HEALTHBARS_HIGHLIGHT_FRIENDLY_NPC, tooltipText = SI_INTERFACE_OPTIONS_HEALTHBARS_HIGHLIGHT_FRIENDLY_NPC_TOOLTIP, system = SETTING_TYPE_NAMEPLATES, settingId = NAMEPLATE_TYPE_FRIENDLY_NPC_HEALTHBARS_HIGHLIGHT},
        --Options_Nameplates_FriendlyPlayerHB
        [NAMEPLATE_TYPE_FRIENDLY_PLAYER_HEALTHBARS] ={text = SI_INTERFACE_OPTIONS_HEALTHBARS_FRIENDLY_PLAYER, tooltipText = SI_INTERFACE_OPTIONS_HEALTHBARS_FRIENDLY_PLAYER_TOOLTIP, system = SETTING_TYPE_NAMEPLATES, settingId = NAMEPLATE_TYPE_FRIENDLY_PLAYER_HEALTHBARS},
        --Options_Nameplates_FriendlyPlayerHBDimmed
        [NAMEPLATE_TYPE_FRIENDLY_PLAYER_HEALTHBARS_HIGHLIGHT] = {text = SI_INTERFACE_OPTIONS_HEALTHBARS_HIGHLIGHT_FRIENDLY_PLAYER, tooltipText = SI_INTERFACE_OPTIONS_HEALTHBARS_HIGHLIGHT_FRIENDLY_PLAYER_TOOLTIP, system = SETTING_TYPE_NAMEPLATES, settingId = NAMEPLATE_TYPE_FRIENDLY_PLAYER_HEALTHBARS_HIGHLIGHT},
        --Options_Nameplates_NeutralNPCHB
        [NAMEPLATE_TYPE_NEUTRAL_NPC_HEALTHBARS] = {text = SI_INTERFACE_OPTIONS_HEALTHBARS_NEUTRAL_NPC, tooltipText = SI_INTERFACE_OPTIONS_HEALTHBARS_NEUTRAL_NPC_TOOLTIP, system = SETTING_TYPE_NAMEPLATES, settingId = NAMEPLATE_TYPE_NEUTRAL_NPC_HEALTHBARS},
        --Options_Nameplates_NeutralNPCHBDimmed
        [NAMEPLATE_TYPE_NEUTRAL_NPC_HEALTHBARS_HIGHLIGHT] = {text = SI_INTERFACE_OPTIONS_HEALTHBARS_HIGHLIGHT_NEUTRAL_NPC, tooltipText = SI_INTERFACE_OPTIONS_HEALTHBARS_HIGHLIGHT_NEUTRAL_NPC_TOOLTIP, system = SETTING_TYPE_NAMEPLATES, settingId = NAMEPLATE_TYPE_NEUTRAL_NPC_HEALTHBARS_HIGHLIGHT},
        --Options_Nameplates_EnemyNPCHB
        [NAMEPLATE_TYPE_ENEMY_NPC_HEALTHBARS] = {text = SI_INTERFACE_OPTIONS_HEALTHBARS_ENEMY_NPC, tooltipText = SI_INTERFACE_OPTIONS_HEALTHBARS_ENEMY_NPC_TOOLTIP, system = SETTING_TYPE_NAMEPLATES, settingId = NAMEPLATE_TYPE_ENEMY_NPC_HEALTHBARS},
        --Options_Nameplates_EnemyNPCHBDimmed
        [NAMEPLATE_TYPE_ENEMY_NPC_HEALTHBARS_HIGHLIGHT] = {text = SI_INTERFACE_OPTIONS_HEALTHBARS_HIGHLIGHT_ENEMY_NPC, tooltipText = SI_INTERFACE_OPTIONS_HEALTHBARS_HIGHLIGHT_ENEMY_NPC_TOOLTIP, system = SETTING_TYPE_NAMEPLATES, settingId = NAMEPLATE_TYPE_ENEMY_NPC_HEALTHBARS_HIGHLIGHT},
        --Options_Nameplates_EnemyPlayerHB
        [NAMEPLATE_TYPE_ENEMY_PLAYER_HEALTHBARS] = {text = SI_INTERFACE_OPTIONS_HEALTHBARS_ENEMY_PLAYER, tooltipText = SI_INTERFACE_OPTIONS_HEALTHBARS_ENEMY_PLAYER_TOOLTIP, system = SETTING_TYPE_NAMEPLATES, settingId = NAMEPLATE_TYPE_ENEMY_PLAYER_HEALTHBARS},
        --Options_Nameplates_EnemyPlayerHBDimmed
        [NAMEPLATE_TYPE_ENEMY_PLAYER_HEALTHBARS_HIGHLIGHT] = {text = SI_INTERFACE_OPTIONS_HEALTHBARS_HIGHLIGHT_ENEMY_PLAYER, tooltipText = SI_INTERFACE_OPTIONS_HEALTHBARS_HIGHLIGHT_ENEMY_PLAYER_TOOLTIP, system = SETTING_TYPE_NAMEPLATES, settingId = NAMEPLATE_TYPE_ENEMY_PLAYER_HEALTHBARS_HIGHLIGHT},
        --Options_Nameplates_AllianceIndicators
        [NAMEPLATE_TYPE_ALLIANCE_INDICATORS] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_NAMEPLATES,
            settingId = NAMEPLATE_TYPE_ALLIANCE_INDICATORS,
            panel = SETTING_PANEL_NAMEPLATES,
            text = SI_INTERFACE_OPTIONS_NAMEPLATES_ALLIANCE_INDICATORS,
            tooltipText = SI_INTERFACE_OPTIONS_NAMEPLATES_ALLIANCE_INDICATORS_TOOLTIP,
            valid = {NAMEPLATE_CHOICE_NEVER, NAMEPLATE_CHOICE_ALLY, NAMEPLATE_CHOICE_ENEMY, NAMEPLATE_CHOICE_ALL},
            valueStringPrefix = "SI_NAMEPLATEDISPLAYCHOICE",
        },
        --Options_Nameplates_GroupIndicators
        [NAMEPLATE_TYPE_GROUP_INDICATORS] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_NAMEPLATES,
            settingId = NAMEPLATE_TYPE_GROUP_INDICATORS,
            panel = SETTING_PANEL_NAMEPLATES,
            text = SI_INTERFACE_OPTIONS_NAMEPLATES_GROUP_INDICATORS,
            tooltipText = SI_INTERFACE_OPTIONS_NAMEPLATES_GROUP_INDICATORS_TOOLTIP,
        },
        --Options_Nameplates_TargetMarkers
        [NAMEPLATE_TYPE_TARGET_MARKERS] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_NAMEPLATES,
            settingId = NAMEPLATE_TYPE_TARGET_MARKERS,
            panel = SETTING_PANEL_NAMEPLATES,
            text = SI_INTERFACE_OPTIONS_NAMEPLATES_TARGET_MARKERS,
            tooltipText = SI_INTERFACE_OPTIONS_NAMEPLATES_TARGET_MARKERS_TOOLTIP,

            events = {[true] = "TargetMarkersEnabled_On", [false] = "TargetMarkersEnabled_Off",},
            gamepadHasEnabledDependencies = true,
        },
        --Options_Nameplates_ResurrectIndicators
        [NAMEPLATE_TYPE_RESURRECT_INDICATORS] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_NAMEPLATES,
            settingId = NAMEPLATE_TYPE_RESURRECT_INDICATORS,
            panel = SETTING_PANEL_NAMEPLATES,
            text = SI_INTERFACE_OPTIONS_NAMEPLATES_RESURRECT_INDICATORS,
            tooltipText = SI_INTERFACE_OPTIONS_NAMEPLATES_RESURRECT_INDICATORS_TOOLTIP,
        },
        --Options_Nameplates_FollowerIndicators
        [NAMEPLATE_TYPE_FOLLOWER_INDICATORS] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_NAMEPLATES,
            settingId = NAMEPLATE_TYPE_FOLLOWER_INDICATORS,
            panel = SETTING_PANEL_NAMEPLATES,
            text = SI_INTERFACE_OPTIONS_NAMEPLATES_FOLLOWER_INDICATORS,
            tooltipText = SI_INTERFACE_OPTIONS_NAMEPLATES_FOLLOWER_INDICATORS_TOOLTIP,
        },
    },
	
    --Subtitles
    [SETTING_TYPE_SUBTITLES] =
    {
        --Options_Audio_SubtitlesEnabledForNPCs
        [SUBTITLE_SETTING_ENABLED_FOR_NPCS] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_SUBTITLES,
            settingId = SUBTITLE_SETTING_ENABLED_FOR_NPCS,
            panel = SETTING_PANEL_AUDIO,
            text = SI_AUDIO_OPTIONS_NPC_SUBTITLES_ENABLED,
            tooltipText = SI_AUDIO_OPTIONS_NPC_SUBTITLES_ENABLED_TOOLTIP,
            exists = ZO_IsIngameUI,
        },
        --Options_Audio_SubtitlesEnabledForVideos
        [SUBTITLE_SETTING_ENABLED_FOR_VIDEOS] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_SUBTITLES,
            settingId = SUBTITLE_SETTING_ENABLED_FOR_VIDEOS,
            panel = SETTING_PANEL_AUDIO,
            text = SI_AUDIO_OPTIONS_VIDEO_SUBTITLES_ENABLED,
            tooltipText = SI_AUDIO_OPTIONS_VIDEO_SUBTITLES_ENABLED_TOOLTIP,
        },
    },

    --Tutorial
    [SETTING_TYPE_TUTORIAL] =
    {
        --Options_Gameplay_TutorialEnabled
        [TUTORIAL_ENABLED_SETTING_ID] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_TUTORIAL,
            settingId = TUTORIAL_ENABLED_SETTING_ID,
            panel = SETTING_PANEL_GAMEPLAY,
            text = SI_INTERFACE_OPTIONS_TOOLTIPS_TUTORIAL_ENABLED,
            tooltipText = SI_INTERFACE_OPTIONS_TOOLTIPS_TUTORIAL_ENABLED_TOOLTIP,
            events = {[true] = "TutorialsEnabled", [false] = "TutorialsDisabled",},
        },

        [OPTIONS_CUSTOM_SETTING_RESET_TUTORIALS] = -- this setting will only be used in the gamepad options, keyboard has a different implementation
        {
            controlType = OPTIONS_INVOKE_CALLBACK,
            system = SETTING_TYPE_TUTORIAL,
            panel = SETTING_PANEL_GAMEPLAY,
            settingId = OPTIONS_CUSTOM_SETTING_RESET_TUTORIALS,
            text = SI_INTERFACE_OPTIONS_RESET_TUTORIALS,
            callback = function()
                ZO_Dialogs_ShowPlatformDialog("CONFIRM_RESET_TUTORIALS")
            end,
        },
    },
    

    --UI Settings
    [SETTING_TYPE_UI] =
    {
        --Options_Interface_ShowActionBar
        [UI_SETTING_SHOW_ACTION_BAR] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_UI,
            panel = SETTING_PANEL_COMBAT,
            settingId = UI_SETTING_SHOW_ACTION_BAR,
            text = SI_INTERFACE_OPTIONS_ACTION_BAR,
            tooltipText = SI_INTERFACE_OPTIONS_ACTION_BAR_TOOLTIP,
            valid = {ACTION_BAR_SETTING_CHOICE_OFF, ACTION_BAR_SETTING_CHOICE_AUTOMATIC, ACTION_BAR_SETTING_CHOICE_ON,},
            valueStringPrefix = "SI_ACTIONBARSETTINGCHOICE",
            events = {[ACTION_BAR_SETTING_CHOICE_OFF] = "OnAbilityBarsEnabledChanged", [ACTION_BAR_SETTING_CHOICE_AUTOMATIC] = "OnAbilityBarsEnabledChanged", [ACTION_BAR_SETTING_CHOICE_ON] = "OnAbilityBarsEnabledChanged"},
            gamepadHasEnabledDependencies = true,
        },
        [UI_SETTING_SHOW_ACTION_BAR_TIMERS] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_UI,
            panel = SETTING_PANEL_COMBAT,
            settingId = UI_SETTING_SHOW_ACTION_BAR_TIMERS,
            text = SI_INTERFACE_OPTIONS_ACTION_BAR_TIMERS,
            tooltipText = SI_INTERFACE_OPTIONS_ACTION_BAR_TIMERS_TOOLTIP,
            eventCallbacks =
            {
                ["OnAbilityBarsEnabledChanged"] = OnAbilityBarsEnabledChanged,
            },
            gamepadIsEnabledCallback = AreAbilityBarsEnabled,
            events = {[false] = "OnAbilityBarTimersEnabledChanged", [true] = "OnAbilityBarTimersEnabledChanged"},
            gamepadHasEnabledDependencies = true,
        },
        [UI_SETTING_SHOW_ACTION_BAR_BACK_ROW] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_UI,
            panel = SETTING_PANEL_COMBAT,
            settingId = UI_SETTING_SHOW_ACTION_BAR_BACK_ROW,
            text = SI_INTERFACE_OPTIONS_ACTION_BAR_BACK_ROW,
            tooltipText = SI_INTERFACE_OPTIONS_ACTION_BAR_BACK_ROW_TOOLTIP,
            eventCallbacks =
            {
                ["OnAbilityBarsEnabledChanged"] = OnAbilityBarBackRowEnabledChanged,
                ["OnAbilityBarTimersEnabledChanged"] = OnAbilityBarBackRowEnabledChanged,
            },
            gamepadIsEnabledCallback = IsAbilityBarBackRowEnabled,
        },
        --Options_Interface_ShowResourceBars
        [UI_SETTING_SHOW_RESOURCE_BARS] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_UI,
            panel = SETTING_PANEL_COMBAT,
            settingId = UI_SETTING_SHOW_RESOURCE_BARS,
            text = SI_INTERFACE_OPTIONS_RESOURCE_BARS,
            tooltipText = SI_INTERFACE_OPTIONS_RESOURCE_BARS_TOOLTIP,
            valid = {RESOURCE_BARS_SETTING_CHOICE_DONT_SHOW, RESOURCE_BARS_SETTING_CHOICE_AUTOMATIC, RESOURCE_BARS_SETTING_CHOICE_ALWAYS_SHOW,},
            valueStringPrefix = "SI_RESOURCEBARSSETTINGCHOICE",
        },
        --Options_Interface_ResourceNumbers
        [UI_SETTING_RESOURCE_NUMBERS] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_UI,
            panel = SETTING_PANEL_COMBAT,
            settingId = UI_SETTING_RESOURCE_NUMBERS,
            text = SI_INTERFACE_OPTIONS_RESOURCE_NUMBERS,
            tooltipText = SI_INTERFACE_OPTIONS_RESOURCE_NUMBERS_TOOLTIP,
            valid = {RESOURCE_NUMBERS_SETTING_OFF, RESOURCE_NUMBERS_SETTING_NUMBER_ONLY, RESOURCE_NUMBERS_SETTING_PERCENT_ONLY, RESOURCE_NUMBERS_SETTING_NUMBER_AND_PERCENT},
            valueStringPrefix = "SI_RESOURCENUMBERSSETTING",
        },
        --Options_Interface_UltimateNumber
        [UI_SETTING_ULTIMATE_NUMBER] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_UI,
            panel = SETTING_PANEL_COMBAT,
            settingId = UI_SETTING_ULTIMATE_NUMBER,
            text = SI_INTERFACE_OPTIONS_ULTIMATE_NUMBER,
            tooltipText = SI_INTERFACE_OPTIONS_ULTIMATE_NUMBER_TOOLTIP,
        },
        [UI_SETTING_PRIMARY_PLAYER_NAME_PC] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_UI,
            panel = SETTING_PANEL_INTERFACE,
            settingId = UI_SETTING_PRIMARY_PLAYER_NAME_PC,
            text = SI_INTERFACE_OPTIONS_PRIMARY_PLAYER_NAME,
            tooltipText = SI_INTERFACE_OPTIONS_PRIMARY_PLAYER_NAME_TOOLTIP,
            exists = ZO_IsPCUI,
            valid =
            {
                PRIMARY_PLAYER_NAME_SETTING_PREFER_CROSSPLAY,
                PRIMARY_PLAYER_NAME_SETTING_PREFER_CHARACTER,
            },
            valueStrings =
            {
                function() return GetString("SI_PRIMARYPLAYERNAMESETTING", PRIMARY_PLAYER_NAME_SETTING_PREFER_CROSSPLAY) end,
                function() return GetString("SI_PRIMARYPLAYERNAMESETTING", PRIMARY_PLAYER_NAME_SETTING_PREFER_CHARACTER) end,
            }
        },
        [UI_SETTING_PRIMARY_PLAYER_NAME_CONSOLE] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_UI,
            panel = SETTING_PANEL_INTERFACE,
            settingId = UI_SETTING_PRIMARY_PLAYER_NAME_CONSOLE,
            text = SI_INTERFACE_OPTIONS_PRIMARY_PLAYER_NAME,
            tooltipText = SI_INTERFACE_OPTIONS_PRIMARY_PLAYER_NAME_TOOLTIP,
            exists = ZO_IsConsoleOrGameCoreUI,
            valid =
            {
                PRIMARY_PLAYER_NAME_SETTING_PREFER_PLATFORM,
                 


                PRIMARY_PLAYER_NAME_SETTING_PREFER_CHARACTER,
            },
            valueStrings =
            {
                function() return zo_strformat(GetString("SI_PRIMARYPLAYERNAMESETTING", PRIMARY_PLAYER_NAME_SETTING_PREFER_PLATFORM), ZO_GetPlatformAccountLabel()) end,
                


                function() return GetString("SI_PRIMARYPLAYERNAMESETTING", PRIMARY_PLAYER_NAME_SETTING_PREFER_CHARACTER) end
            }
        },
        --Options_Interface_ShowRaidLives
        [UI_SETTING_SHOW_RAID_LIVES] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_UI,
            panel = SETTING_PANEL_INTERFACE,
            settingId = UI_SETTING_SHOW_RAID_LIVES,
            text = SI_INTERFACE_OPTIONS_SHOW_RAID_LIVES,
            tooltipText = SI_INTERFACE_OPTIONS_SHOW_RAID_LIVES_TOOLTIP,
            valid = {RAID_LIFE_VISIBILITY_CHOICE_OFF, RAID_LIFE_VISIBILITY_CHOICE_AUTOMATIC, RAID_LIFE_VISIBILITY_CHOICE_ON,},
            valueStringPrefix = "SI_RAIDLIFEVISIBILITYCHOICE",
        },
        --UI_Settings_ShowHouseTracker
        [UI_SETTING_SHOW_HOUSE_TRACKER] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_UI,
            settingId = UI_SETTING_SHOW_HOUSE_TRACKER,
            panel = SETTING_PANEL_INTERFACE,
            text = SI_INTERFACE_OPTIONS_SHOW_HOUSE_TRACKER,
            tooltipText = SI_INTERFACE_OPTIONS_SHOW_HOUSE_TRACKER_TOOLTIP,
        },
        --UI_Settings_ShowQuestTracker
        [UI_SETTING_SHOW_QUEST_TRACKER] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_UI,
            settingId = UI_SETTING_SHOW_QUEST_TRACKER,
            panel = SETTING_PANEL_INTERFACE,
            text = SI_INTERFACE_OPTIONS_SHOW_QUEST_TRACKER,
            tooltipText = SI_INTERFACE_OPTIONS_SHOW_QUEST_TRACKER_TOOLTIP,
            events = {[true] = "QuestTracker_On", [false] = "QuestTracker_Off",},
            gamepadHasEnabledDependencies = true,
        },
        --UI_Settings_AutomaticQuestTracking
        [UI_SETTING_AUTOMATIC_QUEST_TRACKING] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_UI,
            settingId = UI_SETTING_AUTOMATIC_QUEST_TRACKING,
            panel = SETTING_PANEL_INTERFACE,
            text = SI_INTERFACE_OPTIONS_AUTOMATIC_QUEST_TRACKING,
            tooltipText = SI_INTERFACE_OPTIONS_AUTOMATIC_QUEST_TRACKING_TOOLTIP,
            eventCallbacks =
            {
                ["QuestTracker_Off"]   = ZO_Options_SetOptionInactive,
                ["QuestTracker_On"]    = ZO_Options_SetOptionActive,
            },
            -- gamepadIsEnabledCallback = function() 
                -- return tonumber(GetSetting(SETTING_TYPE_UI, UI_SETTING_SHOW_QUEST_TRACKER)) ~= 0
            -- end,
        },
        --Options_Interface_FramerateCheck
        [UI_SETTING_SHOW_FRAMERATE] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_UI,
            settingId = UI_SETTING_SHOW_FRAMERATE,
            panel = SETTING_PANEL_INTERFACE,
            text = SI_INTERFACE_OPTIONS_SHOW_FRAMERATE,
            tooltipText = SI_INTERFACE_OPTIONS_SHOW_FRAMERATE_TOOLTIP,
        },
         --Options_Interface_LatencyCheck
        [UI_SETTING_SHOW_LATENCY] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_UI,
            settingId = UI_SETTING_SHOW_LATENCY,
            panel = SETTING_PANEL_INTERFACE,
            text = SI_INTERFACE_OPTIONS_SHOW_LATENCY,
            tooltipText = SI_INTERFACE_OPTIONS_SHOW_LATENCY_TOOLTIP,
        },
        --Options_Interface_FramerateLatencyLockCheck
        [UI_SETTING_FRAMERATE_LATENCY_LOCK] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_UI,
            settingId = UI_SETTING_FRAMERATE_LATENCY_LOCK,
            panel = SETTING_PANEL_INTERFACE,
            text = SI_INTERFACE_OPTIONS_FRAMERATE_LATENCY_LOCK,
            tooltipText = SI_INTERFACE_OPTIONS_FRAMERATE_LATENCY_LOCK_TOOLTIP,
        },
        --Options_Interface_QuestBestowerIndicators
        [UI_SETTING_SHOW_QUEST_BESTOWER_INDICATORS] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_UI,
            settingId = UI_SETTING_SHOW_QUEST_BESTOWER_INDICATORS,
            panel = SETTING_PANEL_INTERFACE,
            text = SI_INTERFACE_OPTIONS_SHOW_QUEST_BESTOWERS,
            tooltipText = SI_INTERFACE_OPTIONS_SHOW_QUEST_BESTOWERS_TOOLTIP,
            events = {[true] = "Bestowers_On", [false] = "Bestowers_Off",},
            gamepadHasEnabledDependencies = true,
        },
        --UI_Settings_ShowQuestTracker
        [UI_SETTING_COMPASS_QUEST_GIVERS] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_UI,
            settingId = UI_SETTING_COMPASS_QUEST_GIVERS,
            panel = SETTING_PANEL_INTERFACE,
            text = SI_INTERFACE_OPTIONS_COMPASS_QUEST_GIVERS,
            tooltipText = SI_INTERFACE_OPTIONS_COMPASS_QUEST_GIVERS_TOOLTIP,
            eventCallbacks =
            {
                ["Bestowers_Off"]   = ZO_Options_SetOptionInactive,
                ["Bestowers_On"]    = ZO_Options_SetOptionActive,
            },
            gamepadIsEnabledCallback = function() 
                                            return tonumber(GetSetting(SETTING_TYPE_UI, UI_SETTING_SHOW_QUEST_BESTOWER_INDICATORS)) ~= 0
                                        end
        },
        --UI_Settings_ShowQuestTracker
        [UI_SETTING_COMPASS_ACTIVE_QUESTS] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_UI,
            panel = SETTING_PANEL_INTERFACE,
            settingId = UI_SETTING_COMPASS_ACTIVE_QUESTS,
            text = SI_INTERFACE_OPTIONS_COMPASS_ACTIVE_QUESTS,
            tooltipText = SI_INTERFACE_OPTIONS_COMPASS_ACTIVE_QUESTS_TOOLTIP,
            valid = {COMPASS_ACTIVE_QUESTS_CHOICE_OFF, COMPASS_ACTIVE_QUESTS_CHOICE_ON, COMPASS_ACTIVE_QUESTS_CHOICE_FOCUSED,},
            valueStringPrefix = "SI_COMPASSACTIVEQUESTSCHOICE",
            events =
            {
                [COMPASS_ACTIVE_QUESTS_CHOICE_OFF] = "CompassActiveQuests_Off",
                [COMPASS_ACTIVE_QUESTS_CHOICE_FOCUSED] = "CompassActiveQuests_Focused",
                [COMPASS_ACTIVE_QUESTS_CHOICE_ON] = "CompassActiveQuests_On"
            },
            eventCallbacks =
            {
                ["CompassActiveQuests_Off"]   = function(control) ZO_Options_SetWarningText(control, SI_INTERFACE_OPTIONS_COMPASS_ACTIVE_QUESTS_OFF_RESTRICTION) end,
                ["CompassActiveQuests_Focused"]    = function(control) ZO_Options_SetWarningText(control, SI_INTERFACE_OPTIONS_COMPASS_ACTIVE_QUESTS_FOCUSED_RESTRICTION) end,
                ["CompassActiveQuests_On"]    = ZO_Options_HideAssociatedWarning,
            },
        },
        --UI_Settings_ShowWeaponIndicator
        [UI_SETTING_SHOW_WEAPON_INDICATOR] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_UI,
            settingId = UI_SETTING_SHOW_WEAPON_INDICATOR,
            panel = SETTING_PANEL_INTERFACE,
            text = SI_WEAPON_INDICATOR,
            tooltipText = SI_WEAPON_INDICATOR_SETTINGS_TOOLTIP,
        },
        --UI_Settings_ShowArmorIndicator
        [UI_SETTING_SHOW_ARMOR_INDICATOR] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_UI,
            settingId = UI_SETTING_SHOW_ARMOR_INDICATOR,
            panel = SETTING_PANEL_INTERFACE,
            text = SI_ARMOR_INDICATOR,
            tooltipText = SI_ARMOR_INDICATOR_SETTINGS_TOOLTIP,
        },
        --Options_Interface_CompassCompanion
        [UI_SETTING_COMPASS_COMPANION] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_UI,
            settingId = UI_SETTING_COMPASS_COMPANION,
            panel = SETTING_PANEL_INTERFACE,
            text = SI_INTERFACE_OPTIONS_COMPASS_COMPANION,
            tooltipText = SI_INTERFACE_OPTIONS_COMPASS_COMPANION_TOOLTIP,
        },
        --Options_Interface_CompassTargetMarkers
        [UI_SETTING_COMPASS_TARGET_MARKERS] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_UI,
            settingId = UI_SETTING_COMPASS_TARGET_MARKERS,
            panel = SETTING_PANEL_INTERFACE,
            text = SI_INTERFACE_OPTIONS_COMPASS_TARGET_MARKERS,
            tooltipText = SI_INTERFACE_OPTIONS_COMPASS_TARGET_MARKERS_TOOLTIP,
        },
        -- --UI_Settings_ShowCompassDistanceTracking 
        [UI_SETTING_COMPASS_DISTANCE_TRACKING] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_UI,
            settingId = UI_SETTING_COMPASS_DISTANCE_TRACKING,
            panel = SETTING_PANEL_INTERFACE,
            text = SI_INTERFACE_OPTIONS_COMPASS_DISTANCE_TRACKING,
            tooltipText = SI_INTERFACE_OPTIONS_COMPASS_DISTANCE_TRACKING_TOOLTIP,
        },
        --Options_Social_RestrictedCommunication
        [UI_SETTING_RESTRICTED_COMMUNICATION] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_UI,
            settingId = UI_SETTING_RESTRICTED_COMMUNICATION,
            panel = SETTING_PANEL_SOCIAL,
            text = SI_INTERFACE_OPTIONS_RESTRICTED_COMMUNICATION,
            tooltipText = SI_INTERFACE_OPTIONS_RESTRICTED_COMMUNICATION_TOOLTIP,
            visible = function()
                return IsCommunicationRestrictedAccount()
            end,
        },
        --Options_Social_ReturnCursorOnChatFocus
        [UI_SETTING_RETURN_CURSOR_ON_CHAT_FOCUS] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_UI,
            settingId = UI_SETTING_RETURN_CURSOR_ON_CHAT_FOCUS,
            panel = SETTING_PANEL_SOCIAL,
            text = SI_INTERFACE_OPTIONS_RETURN_CURSOR_ON_CHAT_FOCUS,
            tooltipText = SI_INTERFACE_OPTIONS_RETURN_CURSOR_ON_CHAT_FOCUS_TOOLTIP,
        },
        --Options_Social_ShowLeaderboardNotifications
        [UI_SETTING_SHOW_LEADERBOARD_NOTIFICATIONS] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_UI,
            settingId = UI_SETTING_SHOW_LEADERBOARD_NOTIFICATIONS,
            panel = SETTING_PANEL_SOCIAL,
            text = SI_SOCIAL_OPTIONS_SHOW_LEADERBOARD_NOTIFICATIONS,
            tooltipText = SI_SOCIAL_OPTIONS_SHOW_LEADERBOARD_NOTIFICATIONS_TOOLTIP,
            events = {[false] = "LeaderboardNotifications_Off", [true] = "LeaderboardNotifications_On",},
        },
        --Options_Social_AutoDeclineDuelInvites
        [UI_SETTING_AUTO_DECLINE_DUEL_INVITES] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_UI,
            settingId = UI_SETTING_AUTO_DECLINE_DUEL_INVITES,
            panel = SETTING_PANEL_SOCIAL,
            text = SI_SOCIAL_OPTIONS_AUTO_DECLINE_DUEL_INVITES,
            tooltipText = SI_SOCIAL_OPTIONS_AUTO_DECLINE_DUEL_INVITES_TOOLTIP,
        },
        --Options_Social_AutoDeclineTributeInvites
        [UI_SETTING_AUTO_DECLINE_TRIBUTE_INVITES] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_UI,
            settingId = UI_SETTING_AUTO_DECLINE_TRIBUTE_INVITES,
            panel = SETTING_PANEL_SOCIAL,
            text = SI_SOCIAL_OPTIONS_AUTO_DECLINE_TRIBUTE_INVITES,
            tooltipText = SI_SOCIAL_OPTIONS_AUTO_DECLINE_TRIBUTE_INVITES_TOOLTIP,
        },
        --Options_Social_AvANotifications
        [UI_SETTING_SHOW_AVA_NOTIFICATIONS] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_UI,
            panel = SETTING_PANEL_SOCIAL,
            settingId = UI_SETTING_SHOW_AVA_NOTIFICATIONS,
            text = SI_SOCIAL_OPTIONS_SHOW_AVA_NOTIFICATIONS,
            tooltipText = SI_SOCIAL_OPTIONS_SHOW_AVA_NOTIFICATIONS_TOOLTIP,
            valid = {AVA_NOTIFICATIONS_SETTING_CHOICE_DONT_SHOW, AVA_NOTIFICATIONS_SETTING_CHOICE_AUTOMATIC, AVA_NOTIFICATIONS_SETTING_CHOICE_ALWAYS_SHOW,},
            valueStringPrefix = "SI_AVANOTIFICATIONSSETTINGCHOICE",
            events = {[AVA_NOTIFICATIONS_SETTING_CHOICE_DONT_SHOW] = "AvANotifications_Off", [AVA_NOTIFICATIONS_SETTING_CHOICE_AUTOMATIC] = "AvANotifications_On", [AVA_NOTIFICATIONS_SETTING_CHOICE_ALWAYS_SHOW] = "AvANotifications_On",},
            gamepadHasEnabledDependencies = true,
        },
        --Options_Social_GuildKeepNotices
        [UI_SETTING_SHOW_GUILD_KEEP_NOTICES] =
        {
            controlType = OPTIONS_FINITE_LIST,
            system = SETTING_TYPE_UI,
            panel = SETTING_PANEL_SOCIAL,
            settingId = UI_SETTING_SHOW_GUILD_KEEP_NOTICES,
            text = SI_SOCIAL_OPTIONS_SHOW_GUILD_KEEP_NOTICES,
            tooltipText = SI_SOCIAL_OPTIONS_SHOW_GUILD_KEEP_NOTICES_TOOLTIP,
            valid = {GUILD_KEEP_NOTICES_SETTING_CHOICE_DONT_SHOW, GUILD_KEEP_NOTICES_SETTING_CHOICE_CHAT, GUILD_KEEP_NOTICES_SETTING_CHOICE_ALERT,},
            valueStringPrefix = "SI_GUILDKEEPNOTICESSETTINGCHOICE",
            gamepadIsEnabledCallback = AreAvANotificationsEnabled,
            eventCallbacks =
            {
                ["AvANotifications_Off"]   = ZO_Options_SetOptionInactive,
                ["AvANotifications_On"]    = ZO_Options_SetOptionActive,
            },
        },
        --Options_Social_PvPKillFeedNotifications
        [UI_SETTING_SHOW_PVP_KILL_FEED_NOTIFICATIONS] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_UI,
            panel = SETTING_PANEL_SOCIAL,
            settingId = UI_SETTING_SHOW_PVP_KILL_FEED_NOTIFICATIONS,
            text = SI_SOCIAL_OPTIONS_SHOW_PVP_KILL_FEED_NOTIFICATIONS,
            tooltipText = SI_SOCIAL_OPTIONS_SHOW_PVP_KILL_FEED_NOTIFICATIONS_TOOLTIP,
        },
        [UI_SETTING_GAMEPAD_CHAT_HUD_ENABLED] =
        {
            controlType = OPTIONS_CHECKBOX,
            panel = SETTING_PANEL_SOCIAL,
            system = SETTING_TYPE_UI,
            settingId = UI_SETTING_GAMEPAD_CHAT_HUD_ENABLED,
            text = SI_SOCIAL_OPTIONS_GAMEPAD_CHAT_HUD_ENABLED,
            tooltipText = SI_SOCIAL_OPTIONS_GAMEPAD_CHAT_HUD_ENABLED_TOOLTIP,
            existsOnGamepad = ZO_ChatSystem_DoesPlatformUseGamepadChatSystem,
        },
        --Options_Video_UseCustomScale
        [UI_SETTING_USE_CUSTOM_SCALE] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_UI,
            settingId = UI_SETTING_USE_CUSTOM_SCALE,
            panel = SETTING_PANEL_VIDEO,
            text = SI_VIDEO_OPTIONS_UI_USE_CUSTOM_SCALE,
            tooltipText = SI_VIDEO_OPTIONS_UI_USE_CUSTOM_SCALE_TOOLTIP,
            exists = ZO_IsIngameUI,
            events = {
                [true] = "UseCustomScaleToggled",
                [false] = "UseCustomScaleToggled",
            },
        },
        --Options_Video_CustomScale
        [UI_SETTING_CUSTOM_SCALE] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_UI,
            settingId = UI_SETTING_CUSTOM_SCALE,
            panel = SETTING_PANEL_VIDEO,
            text = SI_VIDEO_OPTIONS_UI_CUSTOM_SCALE,
            tooltipText = SI_VIDEO_OPTIONS_UI_CUSTOM_SCALE_TOOLTIP,
            exists = ZO_IsIngameUI,
            valueFormat = "%.6f",
            minValue = KEYBOARD_CUSTOM_UI_SCALE_LOWER_BOUND,
            maxValue = KEYBOARD_CUSTOM_UI_SCALE_UPPER_BOUND,
            onReleasedHandler = ZO_OptionsPanel_Video_SetCustomScale,
            eventCallbacks =
            {
                ["UseCustomScaleToggled"] = ZO_OptionsPanel_Video_CustomScale_RefreshEnabled,
            }
        },
        [UI_SETTING_USE_GAMEPAD_CUSTOM_SCALE] =
        {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_UI,
            settingId = UI_SETTING_USE_GAMEPAD_CUSTOM_SCALE,
            panel = SETTING_PANEL_VIDEO,
            text = SI_VIDEO_OPTIONS_UI_USE_CUSTOM_SCALE,
            tooltipText = SI_GAMEPAD_VIDEO_OPTIONS_UI_USE_CUSTOM_SCALE_TOOLTIP,
            exists = ZO_IsIngameUI,
        },
        [UI_SETTING_GAMEPAD_CUSTOM_SCALE] =
        {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_UI,
            settingId = UI_SETTING_GAMEPAD_CUSTOM_SCALE,
            panel = SETTING_PANEL_VIDEO,
            text = SI_VIDEO_OPTIONS_UI_CUSTOM_SCALE,
            tooltipText = SI_GAMEPAD_VIDEO_OPTIONS_UI_CUSTOM_SCALE_TOOLTIP,
            exists = ZO_IsIngameUI,
            valueFormat = "%.6f",
            minValue = GAMEPAD_CUSTOM_UI_SCALE_LOWER_BOUND,
            maxValue = GAMEPAD_CUSTOM_UI_SCALE_UPPER_BOUND,
            showValueMin = 64,
            showValueMax = 100,
            valueTextFormatter = SI_VIDEO_OPTIONS_UI_CUSTOM_SCALE_PERCENT,
            gamepadIsEnabledCallback = function() 
                return GetSetting(SETTING_TYPE_UI, UI_SETTING_USE_GAMEPAD_CUSTOM_SCALE) ~= "0"
            end,
        },
    },
	
    --Custom
    [SETTING_TYPE_CUSTOM] =
    {
        --Options_Interface_ChatBubblesSayChannel
        [OPTIONS_CUSTOM_SETTING_CHAT_BUBBLE_SAY_ENABLED] = 
        {
            controlType = OPTIONS_CHECKBOX,
            panel = SETTING_PANEL_INTERFACE,
            text = SI_INTERFACE_OPTIONS_CHAT_SAY,
            tooltipText = SI_INTERFACE_OPTIONS_SAY_TOOLTIP,
            exists = ZO_IsPCUI,
            
            channelCategories = { CHAT_CATEGORY_SAY },
        },
        --Options_Interface_ChatBubblesYellChannel
        [OPTIONS_CUSTOM_SETTING_CHAT_BUBBLE_YELL_ENABLED] = 
        {
            controlType = OPTIONS_CHECKBOX,
            panel = SETTING_PANEL_INTERFACE,
            text = SI_INTERFACE_OPTIONS_CHAT_YELL,
            tooltipText = SI_INTERFACE_OPTIONS_YELL_TOOLTIP,
            exists = ZO_IsPCUI,
            
            channelCategories = { CHAT_CATEGORY_YELL },
        },
        --Options_Interface_ChatBubblesWhisperChannel
        [OPTIONS_CUSTOM_SETTING_CHAT_BUBBLE_WHISPER_ENABLED] =
        {
            controlType = OPTIONS_CHECKBOX,
            panel = SETTING_PANEL_INTERFACE,
            text = SI_INTERFACE_OPTIONS_CHAT_TELL,
            tooltipText = SI_INTERFACE_OPTIONS_TELL_TOOLTIP,
            exists = ZO_IsPCUI,
            
            channelCategories = { CHAT_CATEGORY_WHISPER_INCOMING, CHAT_CATEGORY_WHISPER_OUTGOING },
        },
        --Options_Interface_ChatBubblesGroupChannel
        [OPTIONS_CUSTOM_SETTING_CHAT_BUBBLE_GROUP_ENABLED] =
        {
            controlType = OPTIONS_CHECKBOX,
            panel = SETTING_PANEL_INTERFACE,
            text = SI_INTERFACE_OPTIONS_CHAT_GROUP,
            tooltipText = SI_INTERFACE_OPTIONS_GROUP_TOOLTIP,
            exists = ZO_IsPCUI,
            
            channelCategories = { CHAT_CATEGORY_PARTY },
        },
        --Options_Interface_ChatBubblesEmoteChannel
        [OPTIONS_CUSTOM_SETTING_CHAT_BUBBLE_EMOTE_ENABLED] =
        {
            controlType = OPTIONS_CHECKBOX,
            panel = SETTING_PANEL_INTERFACE,
            text = SI_INTERFACE_OPTIONS_CHAT_EMOTE,
            tooltipText = SI_INTERFACE_OPTIONS_EMOTE_TOOLTIP,
            exists = ZO_IsPCUI,
            
            channelCategories = { CHAT_CATEGORY_EMOTE },
        },
        --Options_Interface_FramerateLatencyResetPosition
        [OPTIONS_CUSTOM_SETTING_FRAMERATE_LATENCY_RESET_POSITION] =
        {
            controlType = OPTIONS_INVOKE_CALLBACK,
            panel = SETTING_PANEL_INTERFACE,
            system = SETTING_TYPE_CUSTOM,
            settingId = OPTIONS_CUSTOM_SETTING_FRAMERATE_LATENCY_RESET_POSITION,
            text = SI_INTERFACE_OPTIONS_FRAMERATE_LATENCY_POSITION_RESET,
            callback = function()
                PERFORMANCE_METERS:ResetPosition()
            end,
        },
        --Options_Gameplay_MonsterTellsFriendlyTest
        [OPTIONS_CUSTOM_SETTING_MONSTER_TELLS_FRIENDLY_TEST] =
        {
            controlType = OPTIONS_INVOKE_CALLBACK,
            system = SETTING_TYPE_CUSTOM,
            panel = SETTING_PANEL_GAMEPLAY,
            settingId = OPTIONS_CUSTOM_SETTING_MONSTER_TELLS_FRIENDLY_TEST,
            text = SI_INTERFACE_OPTIONS_COMBAT_MONSTER_TELLS_FRIENDLY_TEST,
            tooltipText = SI_INTERFACE_OPTIONS_COMBAT_MONSTER_TELLS_FRIENDLY_TEST_TOOLTIP,
            eventCallbacks =
            {
                ["MonsterTellsEnabled_Changed"] = OnMonsterTellsOrColorSwapEnabledChanged,
                ["MonsterTellsColorSwapEnabled_Changed"] = OnMonsterTellsOrColorSwapEnabledChanged,
            },
            gamepadIsEnabledCallback = IsMonsterTellsColorSwapEnabled,
            callback = function()
                            StartWorldEffectOnPlayer(UI_WORLD_EFFECT_FRIENDLY_TELEGRAPH)
                        end,
        },
        --Options_Gameplay_MonsterTellsEnemyTest
        [OPTIONS_CUSTOM_SETTING_MONSTER_TELLS_ENEMY_TEST] =
        {
            controlType = OPTIONS_INVOKE_CALLBACK,
            system = SETTING_TYPE_CUSTOM,
            panel = SETTING_PANEL_GAMEPLAY,
            settingId = OPTIONS_CUSTOM_SETTING_MONSTER_TELLS_ENEMY_TEST,
            text = SI_INTERFACE_OPTIONS_COMBAT_MONSTER_TELLS_ENEMY_TEST,
            tooltipText = SI_INTERFACE_OPTIONS_COMBAT_MONSTER_TELLS_ENEMY_TEST_TOOLTIP,
            eventCallbacks =
            {
                ["MonsterTellsEnabled_Changed"] = OnMonsterTellsOrColorSwapEnabledChanged,
                ["MonsterTellsColorSwapEnabled_Changed"] = OnMonsterTellsOrColorSwapEnabledChanged,
            },
            gamepadIsEnabledCallback = IsMonsterTellsColorSwapEnabled,
            callback = function()
                            StartWorldEffectOnPlayer(UI_WORLD_EFFECT_ENEMY_TELEGRAPH)
                        end,
        },
        --Options_Gamepad_Reset_Deadzones
        [OPTIONS_CUSTOM_SETTING_RESET_GAMEPAD_DEADZONES] =
        {
            controlType = OPTIONS_INVOKE_CALLBACK,
            system = SETTING_TYPE_CUSTOM,
            settingId = OPTIONS_CUSTOM_SETTING_RESET_GAMEPAD_DEADZONES,
            panel = SETTING_PANEL_GAMEPLAY,
            text = SI_GAMEPAD_OPTIONS_RESET_DEADZONES,
            customResetToDefaultsFunction = function() ResetGamepadDeadzonesToDefault() end,
            exists = function()
                return IsInGamepadPreferredMode()
            end,
            callback = function()
                ZO_Dialogs_ShowPlatformDialog("KEYBINDINGS_RESET_GAMEPAD_DEADZONES_TO_DEFAULTS")
            end,
        },
        --Options_Gamepad_Reset_Controls
        [OPTIONS_CUSTOM_SETTING_RESET_GAMEPAD_CONTROLS] =
        {
            controlType = OPTIONS_INVOKE_CALLBACK,
            system = SETTING_TYPE_CUSTOM,
            settingId = OPTIONS_CUSTOM_SETTING_RESET_GAMEPAD_CONTROLS,
            panel = SETTING_PANEL_GAMEPLAY,
            text = SI_GAMEPAD_OPTIONS_RESET_CONTROLS,
            customResetToDefaultsFunction = function() ResetGamepadBindsToDefault() end,
            exists = function()
                return not IsConsoleUI()
            end,
            callback = function()
                ZO_Dialogs_ShowPlatformDialog("KEYBINDINGS_RESET_GAMEPAD_TO_DEFAULTS")
            end,
        },
        --Options_Social_TextSize
        [OPTIONS_CUSTOM_SETTING_SOCIAL_TEXT_SIZE] = 
        {
            controlType = OPTIONS_CUSTOM,
            customControlType = OPTIONS_SLIDER,
            customSetupFunction = ZO_OptionsPanel_Social_InitializeTextSizeControl,
            customResetToDefaultsFunction = ZO_OptionsPanel_Social_ResetTextSizeToDefault,
            onShow = ZO_OptionsPanel_Social_TextSizeOnShow,
            panel = SETTING_PANEL_SOCIAL,
            text = SI_SOCIAL_OPTIONS_TEXT_SIZE,
            tooltipText = SI_SOCIAL_OPTIONS_TEXT_SIZE_TOOLTIP,
            existsOnGamepad = DoesPlatformNotUseGamepadChatSystem,
            minValue = 8,
            maxValue = 24,
        },
        --Options_Social_GamepadTextSize
        [OPTIONS_CUSTOM_SETTING_SOCIAL_GAMEPAD_TEXT_SIZE] =
        {
            controlType = OPTIONS_FINITE_LIST,
            panel = SETTING_PANEL_SOCIAL,
            text = SI_SOCIAL_OPTIONS_TEXT_SIZE,
            tooltipText = SI_SOCIAL_OPTIONS_TEXT_SIZE_TOOLTIP,
            valid = { GAMEPAD_CHAT_TEXT_SIZE_SETTING_SMALL, GAMEPAD_CHAT_TEXT_SIZE_SETTING_MEDIUM, GAMEPAD_CHAT_TEXT_SIZE_SETTING_LARGE, },
            valueStringPrefix = "SI_GAMEPADCHATTEXTSIZESETTING",
            GetSettingOverride = GetGamepadChatFontSize,
            scrollListChangedCallback = ZO_OptionsPanel_Social_OnGamepadChatTextSizeScrollListChanged,
            existsOnGamepad = ZO_ChatSystem_DoesPlatformUseGamepadChatSystem,
        },
        --Options_Social_MinAlpha
        [OPTIONS_CUSTOM_SETTING_SOCIAL_MIN_ALPHA] = 
        {
            controlType = OPTIONS_CUSTOM,
            customControlType = OPTIONS_SLIDER,
            customSetupFunction = ZO_OptionsPanel_Social_InitializeMinAlphaControl,
            customResetToDefaultsFunction = ZO_OptionsPanel_Social_ResetMinAlphaToDefault,
            onShow = ZO_OptionsPanel_Social_MinAlphaOnShow,
            panel = SETTING_PANEL_SOCIAL,
            text = SI_SOCIAL_OPTIONS_MIN_ALPHA,
            tooltipText = SI_SOCIAL_OPTIONS_MIN_ALPHA_TOOLTIP,
            existsOnGamepad = DoesPlatformNotUseGamepadChatSystem,
            minValue = 0,
            maxValue = 100,
        },
        --Options_Social_ChatColor_Say
        [OPTIONS_CUSTOM_SETTING_SOCIAL_CHAT_COLOR_SAY] = 
        {
            controlType = OPTIONS_CHAT_COLOR,
            text = GetString("SI_CHATCHANNELCATEGORIES", CHAT_CATEGORY_SAY),
            panel = SETTING_PANEL_SOCIAL,
            chatChannelCategory = CHAT_CATEGORY_SAY,
            tooltipText = SI_SOCIAL_OPTIONS_SAY_COLOR_TOOLTIP,
        },
        --Options_Social_ChatColor_Yell
        [OPTIONS_CUSTOM_SETTING_SOCIAL_CHAT_COLOR_YELL] = 
        {
            controlType = OPTIONS_CHAT_COLOR,
            text = GetString("SI_CHATCHANNELCATEGORIES", CHAT_CATEGORY_YELL),
            panel = SETTING_PANEL_SOCIAL,
            chatChannelCategory = CHAT_CATEGORY_YELL,
            tooltipText = SI_SOCIAL_OPTIONS_YELL_COLOR_TOOLTIP,
        },
        --Options_Social_ChatColor_WhisperIncoming
        [OPTIONS_CUSTOM_SETTING_SOCIAL_CHAT_COLOR_WHISPER_INC] = 
        {
            controlType = OPTIONS_CHAT_COLOR,
            text = GetString("SI_CHATCHANNELCATEGORIES", CHAT_CATEGORY_WHISPER_INCOMING),
            panel = SETTING_PANEL_SOCIAL,
            chatChannelCategory = CHAT_CATEGORY_WHISPER_INCOMING,
            nameFormatter = SI_SOCIAL_OPTIONS_TELL_INCOMING_FORMATTER,
            tooltipText = SI_SOCIAL_OPTIONS_WHISPER_INCOMING_COLOR_TOOLTIP,
        },
        --Options_Social_ChatColor_WhisperOutoing
        [OPTIONS_CUSTOM_SETTING_SOCIAL_CHAT_COLOR_WHISPER_OUT] = 
        {
            controlType = OPTIONS_CHAT_COLOR,
            text = GetString("SI_CHATCHANNELCATEGORIES", CHAT_CATEGORY_WHISPER_OUTGOING),
            panel = SETTING_PANEL_SOCIAL,
            chatChannelCategory = CHAT_CATEGORY_WHISPER_OUTGOING,
            nameFormatter = SI_SOCIAL_OPTIONS_TELL_OUTGOING_FORMATTER,
            tooltipText = SI_SOCIAL_OPTIONS_WHISPER_OUTGOING_COLOR_TOOLTIP,
        },
        --Options_Social_ChatColor_Group
        [OPTIONS_CUSTOM_SETTING_SOCIAL_CHAT_COLOR_GROUP] = 
        {
            controlType = OPTIONS_CHAT_COLOR,
            text = GetString("SI_CHATCHANNELCATEGORIES", CHAT_CATEGORY_PARTY),
            panel = SETTING_PANEL_SOCIAL,
            chatChannelCategory = CHAT_CATEGORY_PARTY,
            tooltipText = SI_SOCIAL_OPTIONS_GROUP_COLOR_TOOLTIP,
        },
        --Options_Social_ChatColor_Zone
        [OPTIONS_CUSTOM_SETTING_SOCIAL_CHAT_COLOR_ZONE] = 
        {
            controlType = OPTIONS_CHAT_COLOR,
            text = GetString("SI_CHATCHANNELCATEGORIES", CHAT_CATEGORY_ZONE),
            panel = SETTING_PANEL_SOCIAL,
            chatChannelCategory = CHAT_CATEGORY_ZONE,
            tooltipText = SI_SOCIAL_OPTIONS_ZONE_COLOR_TOOLTIP,
        },
        --Options_Social_ChatColor_NPC
        [OPTIONS_CUSTOM_SETTING_SOCIAL_CHAT_COLOR_NPC] = 
        {
            controlType = OPTIONS_CHAT_COLOR,
            text = GetString("SI_CHATCHANNELCATEGORIES", CHAT_CATEGORY_MONSTER_SAY),
            panel = SETTING_PANEL_SOCIAL,
            chatChannelCategory = CHAT_CATEGORY_MONSTER_SAY,
            overrideName = SI_CHAT_CHANNEL_NAME_NPC,
            tooltipText = SI_SOCIAL_OPTIONS_NPC_COLOR_TOOLTIP,
        },
        --Options_Social_ChatColor_Emote
        [OPTIONS_CUSTOM_SETTING_SOCIAL_CHAT_COLOR_EMOTE] = 
        {
            controlType = OPTIONS_CHAT_COLOR,
            text = GetString("SI_CHATCHANNELCATEGORIES", CHAT_CATEGORY_EMOTE),
            panel = SETTING_PANEL_SOCIAL,
            chatChannelCategory = CHAT_CATEGORY_EMOTE,
            tooltipText = SI_SOCIAL_OPTIONS_EMOTE_COLOR_TOOLTIP,
        },
        --Options_Social_ChatColor_System
        [OPTIONS_CUSTOM_SETTING_SOCIAL_CHAT_COLOR_SYSTEM] = 
        {
            controlType = OPTIONS_CHAT_COLOR,
            text = GetString("SI_CHATCHANNELCATEGORIES", CHAT_CATEGORY_SYSTEM),
            panel = SETTING_PANEL_SOCIAL,
            chatChannelCategory = CHAT_CATEGORY_SYSTEM,
            tooltipText = SI_SOCIAL_OPTIONS_SYSTEM_COLOR_TOOLTIP,
        },
        --Options_Social_ChatColor_Guild1
        [OPTIONS_CUSTOM_SETTING_SOCIAL_CHAT_COLOR_GUILD1] = 
        {
            controlType = OPTIONS_CHAT_COLOR,
            text = GetString("SI_CHATCHANNELCATEGORIES", CHAT_CATEGORY_GUILD_1),
            panel = SETTING_PANEL_SOCIAL,
            chatChannelCategory = CHAT_CATEGORY_GUILD_1,
            tooltipText = SI_SOCIAL_OPTIONS_GUILD1_COLOR_TOOLTIP,
        },
        --Options_Social_ChatColor_Officer1
        [OPTIONS_CUSTOM_SETTING_SOCIAL_CHAT_COLOR_OFFICER1] = 
        {
            controlType = OPTIONS_CHAT_COLOR,
            text = GetString("SI_CHATCHANNELCATEGORIES", CHAT_CATEGORY_OFFICER_1),
            panel = SETTING_PANEL_SOCIAL,
            chatChannelCategory = CHAT_CATEGORY_OFFICER_1,
            tooltipText = SI_SOCIAL_OPTIONS_OFFICER1_COLOR_TOOLTIP,
        },
        --Options_Social_ChatColor_Guild2
        [OPTIONS_CUSTOM_SETTING_SOCIAL_CHAT_COLOR_GUILD2] = 
        {
            controlType = OPTIONS_CHAT_COLOR,
            text = GetString("SI_CHATCHANNELCATEGORIES", CHAT_CATEGORY_GUILD_2),
            panel = SETTING_PANEL_SOCIAL,
            chatChannelCategory = CHAT_CATEGORY_GUILD_2,
            tooltipText = SI_SOCIAL_OPTIONS_GUILD2_COLOR_TOOLTIP,
        },
        --Options_Social_ChatColor_Officer2
        [OPTIONS_CUSTOM_SETTING_SOCIAL_CHAT_COLOR_OFFICER2] = 
        {
            controlType = OPTIONS_CHAT_COLOR,
            text = GetString("SI_CHATCHANNELCATEGORIES", CHAT_CATEGORY_OFFICER_2),
            panel = SETTING_PANEL_SOCIAL,
            chatChannelCategory = CHAT_CATEGORY_OFFICER_2,
            tooltipText = SI_SOCIAL_OPTIONS_OFFICER2_COLOR_TOOLTIP,
        },
        --Options_Social_ChatColor_Guild3
        [OPTIONS_CUSTOM_SETTING_SOCIAL_CHAT_COLOR_GUILD3] = 
        {
            controlType = OPTIONS_CHAT_COLOR,
            text = GetString("SI_CHATCHANNELCATEGORIES", CHAT_CATEGORY_GUILD_3),
            panel = SETTING_PANEL_SOCIAL,
            chatChannelCategory = CHAT_CATEGORY_GUILD_3,
            tooltipText = SI_SOCIAL_OPTIONS_GUILD3_COLOR_TOOLTIP,
        },
        --Options_Social_ChatColor_Officer3
        [OPTIONS_CUSTOM_SETTING_SOCIAL_CHAT_COLOR_OFFICER3] = 
        {
            controlType = OPTIONS_CHAT_COLOR,
            text = GetString("SI_CHATCHANNELCATEGORIES", CHAT_CATEGORY_OFFICER_3),
            panel = SETTING_PANEL_SOCIAL,
            chatChannelCategory = CHAT_CATEGORY_OFFICER_3,
            tooltipText = SI_SOCIAL_OPTIONS_OFFICER3_COLOR_TOOLTIP,
        },
        --Options_Social_ChatColor_Guild4
        [OPTIONS_CUSTOM_SETTING_SOCIAL_CHAT_COLOR_GUILD4] = 
        {
            controlType = OPTIONS_CHAT_COLOR,
            text = GetString("SI_CHATCHANNELCATEGORIES", CHAT_CATEGORY_GUILD_4),
            panel = SETTING_PANEL_SOCIAL,
            chatChannelCategory = CHAT_CATEGORY_GUILD_4,
            tooltipText = SI_SOCIAL_OPTIONS_GUILD4_COLOR_TOOLTIP,
        },
        --Options_Social_ChatColor_Officer4
        [OPTIONS_CUSTOM_SETTING_SOCIAL_CHAT_COLOR_OFFICER4] = 
        {
            controlType = OPTIONS_CHAT_COLOR,
            text = GetString("SI_CHATCHANNELCATEGORIES", CHAT_CATEGORY_OFFICER_4),
            panel = SETTING_PANEL_SOCIAL,
            chatChannelCategory = CHAT_CATEGORY_OFFICER_4,
            tooltipText = SI_SOCIAL_OPTIONS_OFFICER4_COLOR_TOOLTIP,
        },
        --Options_Social_ChatColor_Guild5
        [OPTIONS_CUSTOM_SETTING_SOCIAL_CHAT_COLOR_GUILD5] = 
        {
            controlType = OPTIONS_CHAT_COLOR,
            text = GetString("SI_CHATCHANNELCATEGORIES",  CHAT_CATEGORY_GUILD_5),
            panel = SETTING_PANEL_SOCIAL,
            chatChannelCategory = CHAT_CATEGORY_GUILD_5,
            tooltipText = SI_SOCIAL_OPTIONS_GUILD5_COLOR_TOOLTIP,
        },
        --Options_Social_ChatColor_Officer5
        [OPTIONS_CUSTOM_SETTING_SOCIAL_CHAT_COLOR_OFFICER5] = 
        {
            controlType = OPTIONS_CHAT_COLOR,
            text = GetString("SI_CHATCHANNELCATEGORIES", CHAT_CATEGORY_OFFICER_5),
            panel = SETTING_PANEL_SOCIAL,
            chatChannelCategory = CHAT_CATEGORY_OFFICER_5,
            tooltipText = SI_SOCIAL_OPTIONS_OFFICER5_COLOR_TOOLTIP,
        },
       --View Credits
        [OPTIONS_CUSTOM_SETTING_GAMEPAD_PREGAME_VIEW_CREDITS] =
        {
            controlType = OPTIONS_INVOKE_CALLBACK,
            system = SETTING_TYPE_CUSTOM,
            panel = SETTING_PANEL_CINEMATIC,
            settingId = OPTIONS_CUSTOM_SETTING_GAMEPAD_PREGAME_VIEW_CREDITS,
            text = SI_GAME_MENU_CREDITS,
            callback = function()
                            SCENE_MANAGER:Push("gamepad_credits")
                        end
        },
        --Play Cinematic
        [OPTIONS_CUSTOM_SETTING_GAMEPAD_PREGAME_PLAY_CINEMATIC] =
        {
            controlType = OPTIONS_INVOKE_CALLBACK,
            system = SETTING_TYPE_CUSTOM,
            panel = SETTING_PANEL_CINEMATIC,
            settingId = OPTIONS_CUSTOM_SETTING_GAMEPAD_PREGAME_PLAY_CINEMATIC,
            text = SI_GAME_MENU_PLAY_CINEMATIC,
            callback = ZO_PlayIntroCinematicAndReturn,
        },
        [OPTIONS_CUSTOM_SETTING_RESEND_EMAIL_ACTIVATION] =
        {
            controlType = OPTIONS_INVOKE_CALLBACK,
            panel = SETTING_PANEL_ACCOUNT,
            text = SI_INTERFACE_OPTIONS_ACCOUNT_RESEND_ACTIVATION,
            gamepadCustomTooltipFunction = function(tooltip, text)
                GAMEPAD_TOOLTIPS:LayoutSettingAccountResendActivation(tooltip, HasActivatedEmail(), ZO_OptionsPanel_GetAccountEmail())
            end,
            callback = function()
                RequestResendAccountEmailVerification()
            end,
            exists = ZO_OptionsPanel_IsAccountManagementAvailable,
            visible = ZO_OptionsPanel_Account_CanResendActivation,
        },
        [OPTIONS_CUSTOM_SETTING_SCREEN_ADJUST] =
        {
            controlType = OPTIONS_INVOKE_CALLBACK,
            system = SETTING_TYPE_CUSTOM,
            panel = SETTING_PANEL_VIDEO,
            settingId = OPTIONS_CUSTOM_SETTING_SCREEN_ADJUST,
            text = SI_SETTING_SHOW_SCREEN_ADJUST,
            exists = IsConsoleUI,
            gamepadIsEnabledCallback = function() 
                -- only allow resizing once the previous one has been completed.
                return not IsGUIResizing()
            end,
            disabledText = SI_SETTING_SHOW_SCREEN_ADJUST_DISABLED,
            callback = function()
                SCENE_MANAGER:Push("screenAdjust")
            end,
            customResetToDefaultsFunction = function()
                SetOverscanOffsets(0, 0, 0, 0)
            end
        },

        [OPTIONS_CUSTOM_SETTING_GAMMA_ADJUST] =
        {
            controlType = OPTIONS_INVOKE_CALLBACK,
            system = SETTING_TYPE_CUSTOM,
            panel = SETTING_PANEL_VIDEO,
            settingId = OPTIONS_CUSTOM_SETTING_GAMMA_ADJUST,
            text = SI_VIDEO_OPTIONS_CALIBRATE_GAMMA,
            gamepadTextOverride = SI_GAMMA_MAIN_TEXT,
            exists = IsSystemNotUsingHDR,
            callback = function()
                SCENE_MANAGER:Push("gammaAdjust")
            end,
            customResetToDefaultsFunction = function()
                ResetSettingToDefault(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_GAMMA_ADJUSTMENT)
            end,
        },

        [OPTIONS_CUSTOM_SETTING_SCREENSHOT_MODE] =
        {
            controlType = OPTIONS_INVOKE_CALLBACK,
            system = SETTING_TYPE_CUSTOM,
            panel = SETTING_PANEL_VIDEO,
            settingId = OPTIONS_CUSTOM_SETTING_SCREENSHOT_MODE,
            text = SI_SETTING_ENTER_SCREENSHOT_MODE,
            tooltipText = SI_SETTING_ENTER_SCREENSHOT_MODE_TOOLTIP,
            callback = function()
                            SCREENSHOT_MODE_GAMEPAD:Show()
                        end,
        },

    },
}






for _,x in pairs(AccountSettings.SettingSystemType) do
    AccountSettings.Default.settings[x] = {}
end

for _,x in pairs(AccountSettings.AllSettingSystemType) do
    AccountSettings.Default.allSettings[x] = {}
end



for kx,x in pairs(AccountSettings.SettingSystemType) do
    AccountSettings.Default.settingsBool[x] = {}
    for ky, y in pairs(AccountSettings.SettingIds[x]) do
       y.system = y.system or x -- system fallback
       y.settingId = y.settingId or ky -- settingId fallback
       if y.system == SETTING_TYPE_UI and y.settingId == UI_SETTING_TEXT_LANGUAGE then
          AccountSettings.Default.settingsBool[y.system][y.settingId] = false 
       elseif y.settingId then
           AccountSettings.Default.settingsBool[y.system][y.settingId] = true
       end	
    end
end

for _,x in pairs(AccountSettings.ChatColors) do
    AccountSettings.Default.chatColors[x] = {}
end

function AccountSettings:SaveChatSettings()
    if ZO_ChatWindow and ZO_ChatWindow.container then
        local settings = ZO_ChatWindow.container.settings

        settings.width, settings.height = ZO_ChatWindow:GetDimensions()
        local _ _, settings.point, _, settings.relPoint, settings.x, settings.y = ZO_ChatWindow:GetAnchor(0)

        AccountSettings.sv.chatWindowSettings = ZO_ChatWindow.container.settings
        AccountSettings:Log ( AccountSettings.DEBUG_COLOR, "ChatWindowSettings " .. tostring( AccountSettings.sv.chatWindowSettings ) )
    end
end

function AccountSettings:CreateSettingsBool()
    local rtn = {
        [1] = {
            type = "checkbox",
            name = "Sync",
            tooltip = "Sync your settings once you choose whom to save settings on",
            default = AccountSettings.Default.sync,
            getFunc = function() return AccountSettings.sv.sync end,
            setFunc = function(newValue)
                AccountSettings.sv.sync = newValue
                if newValue then AccountSettings:Sync() end
            end,
            warning = "If you manually change your settings make sure to save it again with the button below."
        },
		
        [2] = {
            type = "checkbox",
            name = "Share keybinds",
            tooltip = "Share keybinds between characters automatically & when using [Restore ALL settings]",
            default = AccountSettings.Default.shareKeybinds,
            getFunc = function() return AccountSettings.sv.shareKeybinds end,
            setFunc = function(newValue) AccountSettings.sv.shareKeybinds = newValue end,
        },

        [3] = {
            type = "checkbox",
            name = "Show Chat Save Button",
            tooltip = "A button to save chat settings",
            default = AccountSettings.Default.showChatIcon,
            getFunc = function() return AccountSettings.sv.showChatIcon end,
            setFunc = function(newValue)
                AccountSettings.sv.showChatIcon = newValue
				if AccountSettings.sv.showChatIcon then
					AccountSettings_SaveChat_Button:show()
				else
					AccountSettings_SaveChat_Button:hide()
				end
            end,
        },
		
		[4] = {
		    type = "dropdown",
			name = "Chat Settings Addon",
			tooltip = "Choose the addon you want in charge of restoring the chat settings",
			choices = {"Synced Account Settings", "pChat", "Perfect Pixel"},
            default = AccountSettings.Default.chatSettingsAddon,
            getFunc = function() return AccountSettings.sv.chatSettingsAddon end,
            setFunc = function(newValue)
			            AccountSettings.sv.chatSettingsAddon = newValue 
                      end						
		},
		
        [5] = {
            type = "button",
            name = "Save character settings",
            func = function() AccountSettings:SaveSettings() end,
            tooltip = "Once you click this, it will save all the character settings associated with this toon, then each time you switch toon, all these character settings will be auto loaded, making them account wide.",
            width = "full",
            isDangerous = true,
            warning = "This will fully update what you had previously saved. If this is your first time, no worries. If this is your second time be weary that the previous data will be lost."
        },
		
		[6] = {
            type = "button",
            name = "Save ALL settings",
            func = function() AccountSettings:SaveAllSettings() end,
            tooltip = "Once you click this, it will save all the settings associated with this toon, even the account wide ones, use [Restore All settings] to restore all settings.",
            width = "full",
            isDangerous = true,
            warning = "This will fully update what you had previously saved. If this is your first time, no worries. If this is your second time be weary that the previous data will be lost."
        },
		[7] = {
            type = "button",
            name = "Restore ALL settings",
            func = function() AccountSettings:RestoreAll() end,
            tooltip = "Once you click this, it will restore all the settings you saved with the [Save ALL settings] button, even the accountwide ones including sound and graphics, USE AT YOUR OWN RISK.",
            width = "full",
            isDangerous = true,
            warning = "This will will replace ALL your settings with the [Save ALL settings] button ones (most recent save, cross account), USE AT YOUR OWN RISK."
        },

        [8] = {
            type = "checkbox",
            name = "Log",
            tooltip = "Log messages for syncing/if you need to save/saved.",
            default = AccountSettings.Default.log,
            getFunc = function() return AccountSettings.sv.log end,
            setFunc = function(newValue)
                AccountSettings.sv.log = newValue
            end,
        },

        [9] = {
            type = "checkbox",
            name = "Debug",
            tooltip = "Show debug messages",
            default = AccountSettings.Default.debug,
            getFunc = function() return AccountSettings.sv.debug end,
            setFunc = function(newValue)
                AccountSettings.sv.debug = newValue
            end,
        },
        [10] = {
            type = "divider",
        },
        [11] = {
            type = "description",
            text = "|c33ccccYou will find many on/off switches to enable auto loading after changing toon each character setting type saved with the [Save character settings] button. If you would like for a setting to sync across your account, leave it on, otherwise, turn it off. \n\n|r|ccccc33By default everything is on except text language because it causes a reloadUI loop.|r",
        },
        [12] = {
            type = "divider",
        },
    }

    local index = 13

    for kx,x in pairs(AccountSettings.SettingSystemType) do 
        local sub = {
            type = "submenu",
            name = AccountSettings.SettingSystemTypeString[x],
            controls = {}
        }
        local subIndex = 1

        for ky, y in pairs(AccountSettings.SettingIds[x]) do
           y.system = y.system or x -- system fallback
           y.settingId = y.settingId or ky -- settingId fallback
           if y.text then 
              local cb = {
                  type = "checkbox",
                  name = y.text,
                  tooltip = y.tooltipText,
                  default = AccountSettings.Default.settingsBool[y.system][y.settingId],
                  getFunc = function() return AccountSettings.sv.settingsBool[y.system][y.settingId] end,
                  setFunc = function(newValue)
                      AccountSettings.sv.settingsBool[y.system][y.settingId] = newValue
                  end,
              }

              sub.controls[subIndex] = cb
              subIndex = subIndex + 1
             end 
          end

          rtn[index] = sub
          index = index + 1

    end

    return rtn
end


function AccountSettings:SaveSettings() -- save selected non accountwide
    for kx,x in pairs(AccountSettings.SettingSystemType) do
        for ky, y in pairs(AccountSettings.SettingIds[x]) do
            y.system = y.system or x -- system fallback
            y.settingId = y.settingId or ky -- settingId fallback
            local value = GetSetting(y.system, y.settingId) 
            AccountSettings.sv.settings[y.system][y.settingId] = value
			      if AccountSettings.sv.debug and value then
			         AccountSettings:Log ( AccountSettings.DEBUG_COLOR, "Saving ".. GetString(y.text).." to "..value)
			      end
        end
    end
    
	-- save chat colors
    for _,x in ipairs(AccountSettings.ChatColors) do
        local r,g,b = GetChatCategoryColor(x)
        local value = { r, g, b }
        AccountSettings.sv.chatColors = AccountSettings.sv.chatColors or {}
        AccountSettings.sv.chatColors[x] = value
    end
    -- save chat min alpha
    AccountSettings.sv.chatAlphaKeyboard = KEYBOARD_CHAT_SYSTEM:GetMinAlpha()
    
    -- save chat text size
    AccountSettings.sv.chatFontSizeKeyboard = KEYBOARD_CHAT_SYSTEM:GetFontSizeFromSetting()
	
	-- save bindings
	AccountSettings.sv.bindings = {}
	for layerIndex = 1, GetNumActionLayers() do
		local layerName, numCategories = GetActionLayerInfo(layerIndex)
		for categoryIndex = 1, numCategories do
			local categoryName, numActions = GetActionLayerCategoryInfo(layerIndex, categoryIndex)
			for actionIndex = 1, numActions do
				local actionName, isRebindable, isHidden = GetActionInfo(layerIndex, categoryIndex, actionIndex)
				if (not isHidden) and isRebindable then
					for bindingIndex = 1, GetMaxBindingsPerAction() do
						local key, modifier1, modifier2, modifier3, modifier4 = GetActionBindingInfo(layerIndex, categoryIndex, actionIndex, bindingIndex)
						local entry = {
							actionName,        -- [1]
							key,               -- [2]
							bindingIndex,      -- [3]
							modifier1,         -- [4]
							modifier2,         -- [5]
							modifier3,         -- [6]
							modifier4,         -- [7]
						}
						table.insert(AccountSettings.sv.bindings, entry)
						if AccountSettings.sv.debug then
							AccountSettings:Log(AccountSettings.DEBUG_COLOR, "Saving " .. actionName .. " keybind to " .. GetKeyName(key))
						end
					end
				end
			end
		end
	end

    AccountSettings.sv.tracked = true
    AccountSettings:Log ( AccountSettings.OKAY_COLOR, "Saved." )
end



function AccountSettings:SaveAllSettings() -- save All settings
    for kx,x in pairs(AccountSettings.AllSettingSystemType) do
        for ky, y in pairs(AccountSettings.SettingIds[x]) do
            y.system = y.system or x -- system fallback
            y.settingId = y.settingId or ky -- settingId fallback
            local value = GetSetting(y.system, y.settingId) 
            if value and y.system and y.settingId then
                AccountSettings.sv.allSettings[y.system][y.settingId] = value
                if AccountSettings.sv.debug then
                    AccountSettings:Log ( AccountSettings.DEBUG_COLOR, "Saving ".. GetString(y.text).." to "..value)
                end
            end
        end
    end

    -- save chat colors
    for _,x in ipairs(AccountSettings.ChatColors) do
        local r,g,b = GetChatCategoryColor (x)
        local value = { r, g, b }
        AccountSettings.sv.allSettings.chatColors = AccountSettings.sv.allSettings.chatColors or {} 
        AccountSettings.sv.allSettings.chatColors[x] = value
    end
    
    -- save chat min alpha
    AccountSettings.sv.allSettings.chatAlphaKeyboard = KEYBOARD_CHAT_SYSTEM:GetMinAlpha()
    
    -- save chat text size
    AccountSettings.sv.allSettings.chatFontSizeKeyboard = KEYBOARD_CHAT_SYSTEM:GetFontSizeFromSetting()
	
	-- save bindings
	AccountSettings.sv.allSettings.bindings = {}
	for layerIndex = 1, GetNumActionLayers() do
		local layerName, numCategories = GetActionLayerInfo(layerIndex)
		for categoryIndex = 1, numCategories do
			local categoryName, numActions = GetActionLayerCategoryInfo(layerIndex, categoryIndex)
			for actionIndex = 1, numActions do
				local actionName, isRebindable, isHidden = GetActionInfo(layerIndex, categoryIndex, actionIndex)
				if (not isHidden) and isRebindable then
					for bindingIndex = 1, GetMaxBindingsPerAction() do
						local key, modifier1, modifier2, modifier3, modifier4 = GetActionBindingInfo(layerIndex, categoryIndex, actionIndex, bindingIndex)
						local entry = {
							actionName,        -- [1]
							key,               -- [2]
							bindingIndex,      -- [3]
							modifier1,         -- [4]
							modifier2,         -- [5]
							modifier3,         -- [6]
							modifier4,         -- [7]
						}
						table.insert(AccountSettings.sv.allSettings.bindings, entry)
						if AccountSettings.sv.debug then
							AccountSettings:Log(AccountSettings.DEBUG_COLOR, "Saving " .. actionName .. " keybind to " .. GetKeyName(key))
						end
					end
				end
			end
		end
	end

	AccountSettings.sv.allSettings.saveAllSettingsDate = GetTimeStamp()
	AccountSettings.sv.allSettings.saveAllSettingsAccount = GetDisplayName()
    AccountSettings:Log ( AccountSettings.OKAY_COLOR, "All Saved." )
end


function AccountSettings:RestoreAll() -- restore ALL settings
    -- first we look for the most recent save cross account
	local allAccounts = AccountSettings_SV["Default"]
	local saveAllSettingsAccountName = "none"
	local saveAllSettingsAccountDate = 1
    for _, y in pairs(allAccounts) do
	    if y["$AccountWide"] and y["$AccountWide"]["allSettings"] and y["$AccountWide"]["allSettings"]["saveAllSettingsDate"] and y["$AccountWide"]["allSettings"]["saveAllSettingsDate"] > saveAllSettingsAccountDate then
		        saveAllSettingsAccountDate = y["$AccountWide"]["allSettings"]["saveAllSettingsDate"]
            saveAllSettingsAccountName = y["$AccountWide"]["allSettings"]["saveAllSettingsAccount"]
	    end
	end
	
    -- now we restore all settings from the most recent account save
    if saveAllSettingsAccountName ~= "none" then

	    local crossAccountSave = AccountSettings_SV["Default"][saveAllSettingsAccountName]["$AccountWide"]
        for kx,x in pairs(AccountSettings.AllSettingSystemType) do
            for ky, y in pairs(AccountSettings.SettingIds[x]) do
                if y.system and y.settingId and GetSetting(y.system ,y.settingId) ~= nil and crossAccountSave.allSettings[y.system][y.settingId] then -- avoid loading removed settings
            		SetSetting(y.system, y.settingId, crossAccountSave.allSettings[y.system][y.settingId])
					if AccountSettings.sv.debug and y.text and y.system and y.settingId and crossAccountSave.allSettings[y.system][y.settingId] then AccountSettings:Log ( AccountSettings.DEBUG_COLOR, "Setting " .. GetString(y.text).." to "..crossAccountSave.allSettings[y.system][y.settingId]) end
                else
                   if AccountSettings.sv.debug and y.text and type(y.text) ~= "function" then AccountSettings:Log ( AccountSettings.DEBUG_COLOR, "Ignoring " .. GetString(y.text) ) end
                end
            end
        end
 
        -- restore chat settings
        if ZO_ChatWindow and ZO_ChatWindow.container and not (AccountSettings.sv.chatSettingsAddon == "Perfect Pixel" and PP) and not (AccountSettings.sv.chatSettingsAddon == "pChat" and pChat) then -- Avoid chat window mess with Perfect Pixel & pChat 
            local settings = crossAccountSave.chatWindowSettings
            if settings ~= nil and ZO_ChatWindow and ZO_ChatWindow.container then
                ZO_ChatWindow:ClearAnchors()
                ZO_ChatWindow:SetAnchor(settings.point, nil, settings.relPoint, settings.x, settings.y)
                ZO_ChatWindow:SetDimensions(settings.width, settings.height)
                SharedChatContainer.LoadSettings(ZO_ChatWindow.container, settings)
            end
			
			-- restore chat colors
			for _,x in ipairs(AccountSettings.ChatColors) do
				if crossAccountSave.allSettings.chatColors[x] then
					SetChatCategoryColor ( x,
						crossAccountSave.allSettings.chatColors[x][1],
						crossAccountSave.allSettings.chatColors[x][2],
						crossAccountSave.allSettings.chatColors[x][3]
					)
				end
			  end
      end
      
      -- restore chat alpha
      if crossAccountSave.allSettings.chatAlphaKeyboard and not (AccountSettings.sv.chatSettingsAddon == "Perfect Pixel" and PP) and not (AccountSettings.sv.chatSettingsAddon == "pChat" and pChat) then
         KEYBOARD_CHAT_SYSTEM:SetMinAlpha(crossAccountSave.allSettings.chatAlphaKeyboard)
      end 
      
      -- restore chat font size
      if crossAccountSave.allSettings.chatFontSizeKeyboard and not (AccountSettings.sv.chatSettingsAddon == "Perfect Pixel" and PP) and not (AccountSettings.sv.chatSettingsAddon == "pChat" and pChat) then
         KEYBOARD_CHAT_SYSTEM:SetFontSize(crossAccountSave.allSettings.chatFontSizeKeyboard)
      end 
		
		-- restore keybinds
		if AccountSettings.sv.shareKeybinds and crossAccountSave.allSettings.bindings then
			for _, keybindData in ipairs(crossAccountSave.allSettings.bindings) do
				local actionName = keybindData[1]
				local key = keybindData[2]
				local bindingIndex = keybindData[3]
				local modifier1 = keybindData[4] or 0
				local modifier2 = keybindData[5] or 0
				local modifier3 = keybindData[6] or 0
				local modifier4 = keybindData[7] or 0

				local layerIndex, categoryIndex, actionIndex = GetActionIndicesFromName(actionName)
				if layerIndex and categoryIndex and actionIndex then
					if key ~= 0 then
						CallSecureProtected("BindKeyToAction",
							layerIndex, categoryIndex, actionIndex,
							bindingIndex, key, modifier1, modifier2, modifier3, modifier4)
					else
						CallSecureProtected("UnbindKeyFromAction",
							layerIndex, categoryIndex, actionIndex, bindingIndex)
					end
				end

				if AccountSettings.sv.debug then
					AccountSettings:Log(AccountSettings.DEBUG_COLOR, "Setting " .. actionName .. " keybind to " .. GetKeyName(key))
				end
			end
		end
        AccountSettings:Log ( AccountSettings.OKAY_COLOR, "All Restored" )
    else
        AccountSettings:Log ( AccountSettings.ERROR_COLOR, "You must save all settings first before you can restore all" )
    end
	EVENT_MANAGER:UnregisterForEvent(AccountSettings.name, EVENT_PLAYER_ACTIVATED)
end




function AccountSettings:Sync()
    if AccountSettings.sv.tracked and AccountSettings.sv.sync then
        for _,x in pairs(AccountSettings.SettingSystemType) do
            for _, y in pairs(AccountSettings.SettingIds[x]) do
                if AccountSettings.sv.settingsBool[y.system][y.settingId] ~= nil and AccountSettings.sv.settingsBool[y.system][y.settingId] == true and GetSetting(y.system, y.settingId) ~= nil then -- avoid loading removed settings
                  SetSetting(y.system, y.settingId, AccountSettings.sv.settings[y.system][y.settingId])
                  if AccountSettings.sv.debug and y.text and y.system and y.settingId and AccountSettings.sv.settings[y.system][y.settingId] then
                     AccountSettings:Log ( AccountSettings.DEBUG_COLOR, "Setting " .. GetString(y.text).." to "..AccountSettings.sv.settings[y.system][y.settingId])
                  end
                elseif AccountSettings.sv.debug and y.text and type(y.text) ~= "function" then
                    AccountSettings:Log ( AccountSettings.DEBUG_COLOR, "Ignoring " .. GetString(y.text))
                end
            end
        end
 		
        -- restore chat settings 
        if ZO_ChatWindow and ZO_ChatWindow.container and not (AccountSettings.sv.chatSettingsAddon == "Perfect Pixel" and PP) and not (AccountSettings.sv.chatSettingsAddon == "pChat" and pChat) then -- Avoid chat window mess with Perfect Pixel & pChat
            local settings = AccountSettings.sv.chatWindowSettings
            if settings and ZO_ChatWindow and ZO_ChatWindow.container then
                ZO_ChatWindow:ClearAnchors()
                ZO_ChatWindow:SetAnchor(settings.point, nil, settings.relPoint, settings.x, settings.y)
                ZO_ChatWindow:SetDimensions(settings.width, settings.height)
                SharedChatContainer.LoadSettings(ZO_ChatWindow.container, settings)
            end
			
        -- restore chat colors
        for _,x in ipairs(AccountSettings.ChatColors) do
          if AccountSettings.sv.chatColors[x] then
            SetChatCategoryColor ( x,
              AccountSettings.sv.chatColors[x][1],
              AccountSettings.sv.chatColors[x][2],
              AccountSettings.sv.chatColors[x][3]
            )
          end
          end
		    end
        
      -- restore chat alpha
      if AccountSettings.sv.chatAlphaKeyboard and not (AccountSettings.sv.chatSettingsAddon == "Perfect Pixel" and PP) and not (AccountSettings.sv.chatSettingsAddon == "pChat" and pChat) then
         KEYBOARD_CHAT_SYSTEM:SetMinAlpha(AccountSettings.sv.chatAlphaKeyboard)
      end

      -- restore chat font size
      if AccountSettings.sv.chatFontSizeKeyboard and not (AccountSettings.sv.chatSettingsAddon == "Perfect Pixel" and PP) and not (AccountSettings.sv.chatSettingsAddon == "pChat" and pChat) then
         KEYBOARD_CHAT_SYSTEM:SetFontSize(AccountSettings.sv.chatFontSizeKeyboard)
      end 
		
		-- restore keybinds
		if AccountSettings.sv.shareKeybinds and AccountSettings.sv.bindings then
			for _, keybindData in ipairs(AccountSettings.sv.bindings) do
				local actionName = keybindData[1]
				local key = keybindData[2]
				local bindingIndex = keybindData[3]
				local modifier1 = keybindData[4] or 0
				local modifier2 = keybindData[5] or 0
				local modifier3 = keybindData[6] or 0
				local modifier4 = keybindData[7] or 0

				local layerIndex, categoryIndex, actionIndex = GetActionIndicesFromName(actionName)
				if layerIndex and categoryIndex and actionIndex then
					if key ~= 0 then
						CallSecureProtected("BindKeyToAction",
							layerIndex, categoryIndex, actionIndex,
							bindingIndex, key, modifier1, modifier2, modifier3, modifier4)
					else
						CallSecureProtected("UnbindKeyFromAction",
							layerIndex, categoryIndex, actionIndex, bindingIndex)
					end
				end

				if AccountSettings.sv.debug then
					AccountSettings:Log(AccountSettings.DEBUG_COLOR, "Setting " .. actionName .. " keybind to " .. GetKeyName(key))
				end
			end
		end


        AccountSettings:Log ( AccountSettings.OKAY_COLOR, "Synced" )
    else
        AccountSettings:Log ( AccountSettings.ERROR_COLOR, "You must set a character to track first before you can sync" )
    end
	EVENT_MANAGER:UnregisterForEvent(AccountSettings.name, EVENT_PLAYER_ACTIVATED)
end



function AccountSettings:Log(color, message)
    if color == AccountSettings.DEBUG_COLOR then
        if AccountSettings.sv.debug then
            d ( "|c"..tostring(AccountSettings.NAME_COLOR).."[Account Settings] ".."|r".."|c"..tostring(color)..tostring(message).."|r" )
        end
    elseif AccountSettings.sv.log then
        d ( "|c"..tostring(AccountSettings.NAME_COLOR).."[Account Settings] ".."|r".."|c"..tostring(color)..tostring(message).."|r" )
    end
end

-- Settings {{{
function AccountSettings:CreateSettingsWindow()
    local LAM = LibAddonMenu2

    local settingsWindowData = {
        type = "panel",
        name = AccountSettings.displayName,
        author = "|cff00ffJodynn|r, |c3CB371@Masteroshi430|r",
        version = "2026.09.28",
        registerForRefresh = true,
        registerForDefaults = true,
        slashCommand = "/accountsettings"
    }

    local settingsOptionsData = AccountSettings:CreateSettingsBool()

    local settingsOptionPanel = LAM:RegisterAddonPanel(AccountSettings.name.."_LAM", settingsWindowData)
    LAM:RegisterOptionControls(AccountSettings.name.."_LAM", settingsOptionsData)
end
-- Settings }}}

EVENT_MANAGER:RegisterForEvent(AccountSettings.name, EVENT_ADD_ON_LOADED, function(eventCode, addonName) -- {{{
    if addonName ~= AccountSettings.name then return end

    AccountSettings.sv = ZO_SavedVars:NewAccountWide(AccountSettings.savedName, AccountSettings.version, nil, AccountSettings.Default)
    EVENT_MANAGER:UnregisterForEvent(AccountSettings.name, EVENT_ADD_ON_LOADED)

    AccountSettings:CreateSettingsWindow()

    SLASH_COMMANDS["/accountsync"] = AccountSettings.Sync
	
	AccountSettings_SaveChat_Button = LibChatMenuButton.addChatButton("AccountSettings_SaveChat_Button", {"esoui/art/buttons/edit_save_up.dds", "esoui/art/buttons/edit_save_over.dds", "esoui/art/buttons/edit_save_disabled.dds"}, "Save current chat window settings ( size/position )", function() AccountSettings:SaveChatSettings() end)
	
	if AccountSettings.sv.showChatIcon then
	    AccountSettings_SaveChat_Button:show()
	else
	    AccountSettings_SaveChat_Button:hide()
	end

end) -- }}}

EVENT_MANAGER:RegisterForEvent(AccountSettings.name, EVENT_PLAYER_ACTIVATED , function() -- {{{
	zo_callLater (AccountSettings.Sync, 5000)
end) -- }}}




