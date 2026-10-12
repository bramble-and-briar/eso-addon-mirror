local function SettingsInit()
    local accountDefaults = {}

    local defaults = {
        formPos = nil,
        formShown = false,
        showPercent = true,
        showBackBar = true,
        showSkillLines = true,
        trackSkillLineXP = true,
        hideNonLevelable = false,
        pinnedSkillLines = {}, -- skillLineId -> true
    }

    SkillExp.accountData = ZO_SavedVars:NewAccountWide("SkillExp_Data", 1, nil, accountDefaults)
    SkillExp.config = ZO_SavedVars:NewCharacterIdSettings("SkillExp_Data", 1, nil, defaults)

    -- Escape key hook: close SkillExp windows before opening game menu
    ZO_PreHook("ZO_SceneManager_ToggleGameMenuBinding", function()
        if not SkillExp_Settings:IsHidden() then
            SkillExp_ToggleSettings()
            return true
        end
    end)
end

function SkillExp_ToggleSettings()
    local willOpen = SkillExp_Settings:IsHidden()
    SkillExp_Settings:SetHidden(not willOpen)
    SetGameCameraUIMode(willOpen)
end

local function CreateSettingsUI()
    local panel = SkillExp_Settings
    local components = SkillExpComponents

    local showPctToggle = components.CreateToggle(
        "SkillExpSettingsShowPct", panel, SkillExp.config, "showPercent",
        "Show Skill Percent", "Show skill progress percentage next to bars")
    showPctToggle:SetAnchor(TOPLEFT, panel, TOPLEFT, 20, 20)

    -- Wire toggle: update existing rows when toggled
    showPctToggle:SetHandler("OnMouseDown", function(self)
        self:SetChecked(not SkillExp.config.showPercent)
        CALLBACK_MANAGER:FireCallbacks("OnSkillExpSettingChanged")
    end)

    local showBackToggle = components.CreateToggle(
        "SkillExpSettingsShowBack", panel, SkillExp.config, "showBackBar",
        "Show Back Bar", "Show back bar skills section")
    showBackToggle:SetAnchor(TOPLEFT, showPctToggle, BOTTOMLEFT, 0, 8)

    showBackToggle:SetHandler("OnMouseDown", function(self)
        self:SetChecked(not SkillExp.config.showBackBar)
        CALLBACK_MANAGER:FireCallbacks("OnSkillExpSettingChanged")
    end)

    local showSkillLinesToggle = components.CreateToggle(
        "SkillExpSettingsShowLines", panel, SkillExp.config, "showSkillLines",
        "Show Skill Lines", "Show skill line progress for slotted abilities")
    showSkillLinesToggle:SetAnchor(TOPLEFT, showBackToggle, BOTTOMLEFT, 0, 8)

    showSkillLinesToggle:SetHandler("OnMouseDown", function(self)
        self:SetChecked(not SkillExp.config.showSkillLines)
        CALLBACK_MANAGER:FireCallbacks("OnSkillExpSettingChanged")
    end)

    local trackXPToggle = components.CreateToggle(
        "SkillExpSettingsTrackXP", panel, SkillExp.config, "trackSkillLineXP",
        "Track Skill Line XP", "Auto-add skill lines to the list when they receive XP")
    trackXPToggle:SetAnchor(TOPLEFT, showSkillLinesToggle, BOTTOMLEFT, 0, 8)

    trackXPToggle:SetHandler("OnMouseDown", function(self)
        self:SetChecked(not SkillExp.config.trackSkillLineXP)
        CALLBACK_MANAGER:FireCallbacks("OnSkillExpSettingChanged")
    end)

    local hideMaxedToggle = components.CreateToggle(
        "SkillExpSettingsHideMaxed", panel, SkillExp.config, "hideNonLevelable",
        "Hide Non-Levelable Bars", "Hide skill and skill line bars that are at max rank or cannot gain XP")
    hideMaxedToggle:SetAnchor(TOPLEFT, trackXPToggle, BOTTOMLEFT, 0, 8)

    hideMaxedToggle:SetHandler("OnMouseDown", function(self)
        self:SetChecked(not SkillExp.config.hideNonLevelable)
        CALLBACK_MANAGER:FireCallbacks("OnSkillExpSettingChanged")
    end)

    -- Close button (Esc)
    local closeButton = CreateControlFromVirtual("SkillExpSettingsClose", panel, "ZO_DialogButton")
    closeButton:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, -20, -20)
    ZO_KeybindButtonTemplate_Setup(closeButton, "TOGGLE_SYSTEM", function()
        SkillExp_ToggleSettings()
    end, "Close")
end

CALLBACK_MANAGER:RegisterCallback("OnSkillExpInitializing", SettingsInit)
CALLBACK_MANAGER:RegisterCallback("OnSkillExpInitialized", CreateSettingsUI)
