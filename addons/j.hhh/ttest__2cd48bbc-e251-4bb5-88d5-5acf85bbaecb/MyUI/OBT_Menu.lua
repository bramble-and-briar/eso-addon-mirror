local OBT = OffBalanceTracker

---------------------------------------------------------------------------
-- CREATE SETTINGS (MENU)
---------------------------------------------------------------------------
function OBT.CreateSettings()
    local iconTank = "|t20:20:/esoui/art/lfg/lfg_icon_tank.dds|t"
    local iconHealer = "|t20:20:/esoui/art/lfg/lfg_icon_healer.dds|t"
    local iconDPS = "|t20:20:/esoui/art/lfg/lfg_icon_dps.dds|t"
    local iconScroll = "|t20:20:/esoui/art/journal/journal_tabicon_cadwell_up.dds|t"

    local panelName = "Off Balance Tracker"
    if GetUnitDisplayName("player") == OBT.AUTHOR then panelName = "[Dev] " .. panelName end

    local panelData = {
        type = "panel",
        name = panelName,
        displayName = "|cFF7F00Off Balance|r |cFFFFFFTracker|r",
        author = "|cFF7F00" .. OBT.AUTHOR .. "|r |cFFFFFF[EU]|r",
        version = string.format("%s-%04d", OBT.VERSION, OBT.ADDONVERSION),
        registerForRefresh = true,
        registerForDefaults = true,
    }

    ---------------------------------------------------------------------------
    -- GET COLOR DEFAULT
    ---------------------------------------------------------------------------
    local function GetColorDefault(ColorArray)
        return { r = ColorArray[1], g = ColorArray[2], b = ColorArray[3], a = ColorArray[4] }
    end

    ---------------------------------------------------------------------------
    -- REFRESH PREVIEW
    ---------------------------------------------------------------------------
    local function RefreshPreview()
        if OBT.isForceShow or OBT.isMenuPreview then
            OBT.uptimePercentage = 100
            OBT.UpdateVisuals(1, 4900, true)
        end
    end

    local optionsData = {
        {
            type = "checkbox",
            name = "|cFF7F00MASTERSWITCH|r (Turns the entire addon ON/OFF)",
            tooltip = "Enables or disables all tracker functionalities.",
            getFunc = function() return OBT.SV.enableAddon end,
            setFunc = function(value)
                OBT.SV.enableAddon = value
                if value then OBT.Enable() else OBT.Disable() end
            end,
            default = OBT.Default.enableAddon,
        },
        {
			type = "description",
			text = "Type |cFF7F00/offbalancetracker|r to |cFF0000LOCK|r or |c00FF00UNLOCK|r the tracker and reposition it.",
			width = "full"
		},
        {
            type = "button",
            name = "Toggle Preview",
            tooltip = "Forces the display to show for positioning.",
            func = function()
                local isCurrentlyShown = OBT.isForceShow or OBT.isMenuPreview
                if isCurrentlyShown then
                    OBT.isForceShow = false
                    OBT.isMenuPreview = false
                    OBT.uptimePercentage = 0
                    OBT.UpdateVisibility()
                    OBT.UpdateVisuals(0, 0, false)
                else
                    OBT.isForceShow = true
                    OBT.isMenuPreview = true
                    OBT.uptimePercentage = 100
                    OBT.UpdateVisibility()
                    OBT.UpdateVisuals(1, 4900, true)
                end
            end,
            disabled = function() return not OBT.SV.enableAddon end,
            width = "half",
        },
        {
            type = "button",
            name = "Reset Position",
            tooltip = "Resets the UI position to default.",
            func = function() OBT.SetDefaultPosition() end,
            disabled = function() return not OBT.SV.enableAddon end,
            width = "half",
        },

        -- SUBMENU: TRACKING, VISIBILITY & ROLES
        {
            type = "submenu",
            name = "|cFF7F00VISIBILITY & ROLES|r",
            controls = {
                {
                    type = "checkbox",
                    name = "Only Show In Combat",
                    tooltip = "If enabled, the tracker will be hidden when out of combat.",
                    getFunc = function() return OBT.SV.isOnlyCombat end,
                    setFunc = function(value)
                        OBT.SV.isOnlyCombat = value
                        OBT.UpdateVisibility()
                    end,
                    default = OBT.Default.isOnlyCombat,
                    disabled = function() return not OBT.SV.enableAddon end,
                },
                {
                    type = "slider",
                    name = "Combat Hide Delay [sec]",
                    tooltip = "Delays hiding the UI after combat ends.",
                    min = 0, max = 5, step = 0.5,
                    getFunc = function() return OBT.SV.combatHideDelay or OBT.Default.combatHideDelay end,
                    setFunc = function(value) OBT.SV.combatHideDelay = value end,
                    default = OBT.Default.combatHideDelay,
                    disabled = function() return not OBT.SV.enableAddon or not OBT.SV.isOnlyCombat end,
                },
                {
                    type = "checkbox",
                    name = "Only Show on Bosses",
                    tooltip = "If enabled, the tracker will remain hidden unless a boss is tracked.",
                    getFunc = function() return OBT.SV.isOnlyBosses end,
                    setFunc = function(value)
                        OBT.SV.isOnlyBosses = value
                        OBT.UpdateVisibility()
                    end,
                    default = OBT.Default.isOnlyBosses,
                    disabled = function() return not OBT.SV.enableAddon end,
                },
                {
                    type = "checkbox",
                    name = "Boss Focus (Target Lock)",
                    tooltip = "Locks onto a Boss if present. Reticle target overrides this if multiple bosses exist. Warning! Will not track adds besides the boss!",
                    getFunc = function() return OBT.SV.isBossFocus end,
                    setFunc = function(value) OBT.SV.isBossFocus = value end,
                    default = OBT.Default.isBossFocus,
                    disabled = function() return not OBT.SV.enableAddon end,
                },
                { type = "header", name = "|cFFBF7FRole Filters|r" },
                {
                    type = "description",
                    text = "Select the roles you want this tracker to be visible on.",
                    width = "full",
                },
                {
                    type = "checkbox", name = "Enable as Tank " .. iconTank,
                    getFunc = function() return OBT.SV.isEnabledTank end,
                    setFunc = function(value)
                        OBT.SV.isEnabledTank = value
                        OBT.UpdateVisibility()
                    end,
                    default = OBT.Default.isEnabledTank,
                    disabled = function() return not OBT.SV.enableAddon end,
                },
                {
                    type = "checkbox", name = "Enable as Healer " .. iconHealer,
                    getFunc = function() return OBT.SV.isEnabledHeal end,
                    setFunc = function(value)
                        OBT.SV.isEnabledHeal = value
                        OBT.UpdateVisibility()
                    end,
                    default = OBT.Default.isEnabledHeal,
                    disabled = function() return not OBT.SV.enableAddon end,
                },
                {
                    type = "checkbox", name = "Enable as DPS " .. iconDPS,
                    getFunc = function() return OBT.SV.isEnabledDPS end,
                    setFunc = function(value)
                        OBT.SV.isEnabledDPS = value
                        OBT.UpdateVisibility()
                    end,
                    default = OBT.Default.isEnabledDPS,
                    disabled = function() return not OBT.SV.enableAddon end,
                },
                {
                    type = "checkbox", name = "Enable as Solo " .. iconScroll,
                    getFunc = function() return OBT.SV.isEnabledSolo end,
                    setFunc = function(value)
                        OBT.SV.isEnabledSolo = value
                        OBT.UpdateVisibility()
                    end,
                    default = OBT.Default.isEnabledSolo,
                    disabled = function() return not OBT.SV.enableAddon end,
                },
            },
        },

        -- SUBMENU: DESIGN, SCALING & COLORS
        {
            type = "submenu",
            name = "|cFF7F00DESIGN & COLORS|r",
            controls = {
                {
                    type = "checkbox",
                    name = "|cFF0000Lock UI|r",
                    tooltip = "Locks the tracker icon so it cannot be accidentally moved.",
                    getFunc = function() return OBT.SV.isLocked end,
                    setFunc = function(value)
                        OBT.SV.isLocked = value
                        OBT.PARENT:SetMovable(not value)
                        OBT.PARENT:SetMouseEnabled(not value)
                    end,
                    disabled = function() return not OBT.SV.enableAddon end,
                    default = OBT.Default.isLocked,
                },

                { type = "header", name = "|cFFBF7FCHOOSE UI Elements|r" },
                {
                    type = "checkbox",
                    name = "|c00BFFFShow Background & Border|r",
                    tooltip = "Disable to hide the background and display only the remaining time.",
                    getFunc = function() return OBT.SV.isShowBackground end,
                    setFunc = function(value)
                        OBT.SV.isShowBackground = value
                        RefreshPreview()
                    end,
                    disabled = function() return not OBT.SV.enableAddon end,
                    default = OBT.Default.isShowBackground,
                },
                {
                    type = "checkbox", name = "|c00BFFFShow BOSS Label|r",
                    getFunc = function() return not OBT.SV.isHideBossLabel end,
                    setFunc = function(value)
                        OBT.SV.isHideBossLabel = not value
                        OBT.UpdateTimerPosition()
                        RefreshPreview()
                    end,
                    default = not OBT.Default.isHideBossLabel,
                    disabled = function() return not OBT.SV.enableAddon end,
                },
                {
                    type = "checkbox", name = "|c00BFFFShow Uptime [%]|r",
                    getFunc = function() return not OBT.SV.isHideUptime end,
                    setFunc = function(value)
                        OBT.SV.isHideUptime = not value
                        OBT.UpdateTimerPosition()
                        RefreshPreview()
                    end,
                    default = not OBT.Default.isHideUptime,
                    disabled = function() return not OBT.SV.enableAddon end,
                },
                {
                    type = "divider",
                },
                {
                    type = "checkbox", name = "Thick Outline Font",
                    getFunc = function() return OBT.SV.isThickOutline end,
                    setFunc = function(value)
                        OBT.SV.isThickOutline = value
                        OBT.UpdateFonts()
                        RefreshPreview()
                    end,
                    default = OBT.Default.isThickOutline,
                    disabled = function() return not OBT.SV.enableAddon end,
                },
                {
                    type = "divider",
                },
                {
                    type = "slider", name = "Icon Size",
                    min = 40, max = 100, step = 1,
                    getFunc = function() return OBT.SV.iconSize end,
                    setFunc = function(value)
                        OBT.SV.iconSize = value
                        OBT.PARENT:SetDimensions(value, value)
                        OBT.BG:SetDimensions(value, value)
                        local innerSize = math.max(1, value - (OBT.SV.borderThickness * 2))
                        OBT.ICON:SetDimensions(innerSize, innerSize)
                    end,
                    default = OBT.Default.iconSize,
                    disabled = function() return not OBT.SV.isShowBackground end
                },
                {
                    type = "slider", name = "Border Thickness",
                    min = 0, max = 10, step = 1,
                    getFunc = function() return OBT.SV.borderThickness end,
                    setFunc = function(value)
                        OBT.SV.borderThickness = value
                        local innerSize = math.max(1, OBT.SV.iconSize - (value * 2))
                        OBT.ICON:SetDimensions(innerSize, innerSize)
                    end,
                    default = OBT.Default.borderThickness,
                    disabled = function() return not OBT.SV.isShowBackground end
                },
                {
                    type = "slider", name = "Edge Thickness",
                    min = 0, max = 2, step = 1,
                    getFunc = function() return OBT.SV.edgeThickness end,
                    setFunc = function(value)
                        OBT.SV.edgeThickness = value
                        OBT.BG:SetEdgeTexture("", 1, 1, OBT.SV.edgeThickness, 0)
                        if OBT.SV.edgeThickness == 0 then
                            OBT.BG:SetEdgeColor(0, 0, 0, 0)
                        else
                            OBT.BG:SetEdgeColor(0, 0, 0, 1)
                        end
                    end,
                    default = OBT.Default.edgeThickness,
                    disabled = function() return not OBT.SV.isShowBackground end
                },

                { type = "header", name = "|cFFBF7FBorder Colors (States)|r" },
                {
                    type = "colorpicker", name = "0 - Idle / No Target / No OB",
                    getFunc = function() return unpack(OBT.SV.ColorIdle) end,
                    setFunc = function(r, g, b, a)
                        OBT.SV.ColorIdle = { r, g, b, a }
                        if OBT.isForceShow or OBT.isMenuPreview then
                            RefreshPreview()
                        else
                            OBT.UpdateVisuals(0, 0, false)
                        end
                    end,
                    default = GetColorDefault(OBT.Default.ColorIdle),
                    disabled = function() return not OBT.SV.enableAddon end,
                },
                {
                    type = "colorpicker", name = "1 - Off Balance (Active)",
                    getFunc = function() return unpack(OBT.SV.ColorActive) end,
                    setFunc = function(r, g, b, a)
                        OBT.SV.ColorActive = { r, g, b, a }
                        RefreshPreview()
                    end,
                    default = GetColorDefault(OBT.Default.ColorActive),
                    disabled = function() return not OBT.SV.enableAddon end,
                },
                {
                    type = "colorpicker", name = "2 - Immunity (Cooldown)",
                    getFunc = function() return unpack(OBT.SV.ColorImmune) end,
                    setFunc = function(r, g, b, a)
                        OBT.SV.ColorImmune = { r, g, b, a }
                        if OBT.isForceShow or OBT.isMenuPreview then OBT.UpdateVisuals(2, 14000, true) end
                    end,
                    default = GetColorDefault(OBT.Default.ColorImmune),
                    disabled = function() return not OBT.SV.enableAddon end,
                },

                -- TIMER
                { type = "header", name = "|cFFBF7FCenter Timer|r" },
                {
                    type = "checkbox", name = "Colored Timer (Matches Border)",
                    getFunc = function() return OBT.SV.isColoredTimer end,
                    setFunc = function(value)
                        OBT.SV.isColoredTimer = value
                        RefreshPreview()
                    end,
                    default = OBT.Default.isColoredTimer,
                    disabled = function() return not OBT.SV.enableAddon end,
                },
                {
                    type = "colorpicker", name = "Timer Color",
                    getFunc = function() return unpack(OBT.SV.ColorTextTimer) end,
                    setFunc = function(r, g, b, a)
                        OBT.SV.ColorTextTimer = { r, g, b, a }
                        RefreshPreview()
                    end,
                    default = GetColorDefault(OBT.Default.ColorTextTimer),
                    disabled = function() return not OBT.SV.enableAddon or OBT.SV.isColoredTimer end,
                },
                {
                    type = "slider", name = "Timer Font Size",
                    min = 12, max = 124, step = 1,
                    getFunc = function() return OBT.SV.fontSizeTimer end,
                    setFunc = function(value)
                        OBT.SV.fontSizeTimer = value
                        OBT.UpdateFonts()
                        RefreshPreview()
                    end,
                    default = OBT.Default.fontSizeTimer,
                    disabled = function() return not OBT.SV.enableAddon end,
                },
                {
                    type = "slider", name = "Timer Vertical Offset",
                    min = -24, max = 24, step = 1,
                    getFunc = function() return OBT.SV.offsetYTimer end,
                    setFunc = function(value)
                        OBT.SV.offsetYTimer = value
                        OBT.UpdateTimerPosition()
                    end,
                    default = OBT.Default.offsetYTimer,
                    disabled = function() return not OBT.SV.enableAddon end,
                },
                {
                    type = "slider", name = "Decimal Threshold (s)",
                    tooltip = "Shows decimal places when the timer falls below this value.",
                    min = 0, max = 15, step = 0.5,
                    getFunc = function() return OBT.SV.decimalThreshold end,
                    setFunc = function(value)
                        OBT.SV.decimalThreshold = value
                        RefreshPreview()
                    end,
                    default = OBT.Default.decimalThreshold,
                    disabled = function() return not OBT.SV.enableAddon end,
                },

                -- BOSS LABEL
                { type = "header", name = "|cFFBF7FBoss Label|r" },
                {
                    type = "checkbox", name = "Colored Boss Label (Matches Border)",
                    getFunc = function() return OBT.SV.isColoredBossLabel end,
                    setFunc = function(value)
                        OBT.SV.isColoredBossLabel = value
                        RefreshPreview()
                    end,
                    default = OBT.Default.isColoredBossLabel,
                    disabled = function() return not OBT.SV.enableAddon end,
                },
                {
                    type = "colorpicker", name = "Boss Label Color",
                    getFunc = function() return unpack(OBT.SV.ColorTextBoss) end,
                    setFunc = function(r, g, b, a)
                        OBT.SV.ColorTextBoss = { r, g, b, a }
                        RefreshPreview()
                    end,
                    default = GetColorDefault(OBT.Default.ColorTextBoss),
                    disabled = function() return not OBT.SV.enableAddon or OBT.SV.isColoredBossLabel end, 
                },
                {
                    type = "slider", name = "Boss Font Size",
                    min = 12, max = 32, step = 1,
                    getFunc = function() return OBT.SV.fontSizeBoss end,
                    setFunc = function(value)
                        OBT.SV.fontSizeBoss = value
                        OBT.UpdateFonts()
                        RefreshPreview()
                    end,
                    default = OBT.Default.fontSizeBoss,
                    disabled = function() return not OBT.SV.enableAddon end,
                },
                {
                    type = "slider", name = "Boss Vertical Offset",
                    min = -24, max = 24, step = 1,
                    getFunc = function() return OBT.SV.offsetYBoss end,
                    setFunc = function(value)
                        OBT.SV.offsetYBoss = value
                        OBT.UpdateBossPosition()
                    end,
                    default = OBT.Default.offsetYBoss,
                    disabled = function() return not OBT.SV.enableAddon end,
                },
                {
                    type = "checkbox", name = "Disable Experimental",
                    tooltip = "In some rare and uncertain cases, boss label might show weird text.",
                    getFunc = function() return OBT.SV.isHideExperimental end,
                    setFunc = function(value)
                        OBT.SV.isHideExperimental = value
                    end,
                    default = OBT.Default.isHideExperimental,
                    disabled = function() return not OBT.SV.enableAddon end,
                },

                -- UPTIME
                { type = "header", name = "|cFFBF7FUptime|r" },
                {
                    type = "colorpicker", name = "Uptime Color",
                    getFunc = function() return unpack(OBT.SV.ColorTextUptime) end,
                    setFunc = function(r, g, b, a)
                        OBT.SV.ColorTextUptime = { r, g, b, a }
                        RefreshPreview()
                    end,
                    default = GetColorDefault(OBT.Default.ColorTextUptime),
                    disabled = function() return not OBT.SV.enableAddon or OBT.SV.isHideUptime end,
                },
                {
                    type = "slider", name = "Uptime Font Size",
                    min = 12, max = 32, step = 1,
                    getFunc = function() return OBT.SV.fontSizeUptime end,
                    setFunc = function(value)
                        OBT.SV.fontSizeUptime = value
                        OBT.UpdateFonts()
                        RefreshPreview()
                    end,
                    default = OBT.Default.fontSizeUptime,
                    disabled = function() return not OBT.SV.enableAddon or OBT.SV.isHideUptime end,
                },
            },
        },

        -- SUBMENU: AUDIO
        {
            type = "submenu",
            name = "|cFF7F00AUDIO SETTINGS|r",
            controls = {
                {
                    type = "dropdown",
                    name = "Sound Trigger Mode",
                    tooltip = "Select when the sound should be played.",
                    choices = {"On Off Balance Proc", "On Immunity Fade"},
                    choicesValues = {1, 2},
                    getFunc = function() return OBT.SV.soundTriggerMode end,
                    setFunc = function(value)
                        OBT.SV.soundTriggerMode = value
                        OBT.PlaySound(OBT.SV.volumeSound)
                    end,
                    default = OBT.Default.soundTriggerMode,
                    disabled = function() return not OBT.SV.enableAddon end,
                },
                {
                    type = "slider",
                    name = "Sound Volume",
                    min = 0, max = 5, step = 1,
                    getFunc = function() return OBT.SV.volumeSound end,
                    setFunc = function(value)
                        OBT.SV.volumeSound = value
                        OBT.PlaySound(OBT.SV.volumeSound)
                    end,
                    default = OBT.Default.volumeSound,
                    disabled = function() return not OBT.SV.enableAddon end,
                },
                { type = "header", name = "|cFFBF7FAudio Roles|r" },
                {
                    type = "description",
                    text = "Select roles for sound alert.",
                    width = "full",
                },
                {
                    type = "checkbox", name = "Play Sound as Tank " .. iconTank,
                    getFunc = function() return OBT.SV.isSoundEnabledTank end,
                    setFunc = function(value)
                        OBT.SV.isSoundEnabledTank = value
                    end,
                    default = OBT.Default.isSoundEnabledTank,
                    disabled = function() return not OBT.SV.enableAddon end,
                },
                {
                    type = "checkbox", name = "Play Sound as Healer " .. iconHealer,
                    getFunc = function() return OBT.SV.isSoundEnabledHeal end,
                    setFunc = function(value)
                        OBT.SV.isSoundEnabledHeal = value
                    end,
                    default = OBT.Default.isSoundEnabledHeal,
                    disabled = function() return not OBT.SV.enableAddon end,
                },
                {
                    type = "checkbox", name = "Play Sound as DPS " .. iconDPS,
                    getFunc = function() return OBT.SV.isSoundEnabledDPS end,
                    setFunc = function(value)
                        OBT.SV.isSoundEnabledDPS = value
                    end,
                    default = OBT.Default.isSoundEnabledDPS,
                    disabled = function() return not OBT.SV.enableAddon end,
                },
                {
                    type = "checkbox", name = "Play Sound as Solo " .. iconScroll,
                    getFunc = function() return OBT.SV.isSoundEnabledSolo end,
                    setFunc = function(value)
                        OBT.SV.isSoundEnabledSolo = value
                    end,
                    default = OBT.Default.isSoundEnabledSolo,
                    disabled = function() return not OBT.SV.enableAddon end,
                },
            },
        },

        -- SUBMENU: CHAT SUMMARY
        {
            type = "submenu",
            name = "|cFF7F00CHAT SUMMARY|r",
            controls = {
                {
                    type = "checkbox",
                    name = "Enable Chat Summary",
                    tooltip = "Outputs uptime to chat after combat.",
                    getFunc = function() return OBT.SV.isEnabledChat end,
                    setFunc = function(value) OBT.SV.isEnabledChat = value end,
                    default = OBT.Default.isEnabledChat,
                    disabled = function() return not OBT.SV.enableAddon end,
                },
                {
                    type = "slider",
                    name = "Min. Fight Time (s)",
                    tooltip = "Only outputs a summary if the fight lasted longer than X seconds.",
                    min = 0, max = 120, step = 5,
                    getFunc = function() return OBT.SV.minFightTime end,
                    setFunc = function(value) OBT.SV.minFightTime = value end,
                    default = OBT.Default.minFightTime,
                    disabled = function() return not OBT.SV.enableAddon end,
                },
            },
        },

        -- FEEDBACK
        {
            type = "description",
            text = "If you enjoy |cFF7F00Off Balance Tracker|r, consider sharing your feedback or supporting its development. Your input and contributions are greatly appreciated!",
            width = "full"
        },
        {
            type = "button",
            name = "Feedback / Donate",
            tooltip = "Opens a mail to send feedback or donate to the author. <3",
            func = function()
                if OBT.isConsole then
                    d(string.format("%s |cFFFFFFFeedback via Mail is currently only supported on PC.|r", OBT.CHAT))
                    return
                end
                SCENE_MANAGER:Show('mailSend')
                zo_callLater(function()
                    ZO_MailSendToField:SetText(OBT.AUTHOR)
                    ZO_MailSendSubjectField:SetText("Off Balance Tracker")
                    ZO_MailSendBodyField:TakeFocus()
                end, 250)
            end,
            width = "half"
        }
    }

    -- My UI owns the LAM panel. Give its Off Balance Tracker root exactly
    -- four submenu entries, matching the original LAM group organization.
    -- Move the original standalone master switch, preview and reset controls
    -- into Visibility & Roles; keep the feedback controls in Chat Summary.
    -- Do not change their callbacks or any of the tracking/display logic.
    local fourSubmenus = {}
    local generalControls = {}
    local trailingControls = {}
    local seenFirstSubmenu = false

    for _, option in ipairs(optionsData) do
        if option.type == "submenu" then
            seenFirstSubmenu = true
            table.insert(fourSubmenus, option)
        elseif not seenFirstSubmenu then
            table.insert(generalControls, option)
        else
            table.insert(trailingControls, option)
        end
    end

    if #fourSubmenus == 4 then
        local visibilityControls = fourSubmenus[1].controls
        for i = #generalControls, 1, -1 do
            table.insert(visibilityControls, 1, generalControls[i])
        end
        local chatControls = fourSubmenus[4].controls
        for _, option in ipairs(trailingControls) do
            table.insert(chatControls, option)
        end
        return fourSubmenus
    end

    -- Safety fallback if the upstream OBT layout changes in a future update.
    return optionsData
end
