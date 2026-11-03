-- Arclight Taunt 1.1.0 | Settings module
-- Loaded in manifest order; requires Core.lua and uses its shared namespace.
local A = ArclightTaunt
local T = A.T
local ALERT_SOUNDS = A.ALERT_SOUNDS
local ALERT_SOUND_CHOICES = A.ALERT_SOUND_CHOICES
local C = A.C
local FiniteBoundedNumber = A.FiniteBoundedNumber
local MAX_PER_COLUMN = A.MAX_PER_COLUMN
local MEDIA_BAR_DEFAULT = A.MEDIA_BAR_DEFAULT
local MEDIA_BAR_FLAT = A.MEDIA_BAR_FLAT
local MEDIA_FONT_DEFAULT = A.MEDIA_FONT_DEFAULT
local MEDIA_TIMER_INHERIT = A.MEDIA_TIMER_INHERIT
local SetColor = A.SetColor
local defaults = A.defaults

local function Colored(text, color)
    local hex = color
    if type(color) == "table" then
        hex = string.format("%02X%02X%02X", math.floor(color[1] * 255 + 0.5),
            math.floor(color[2] * 255 + 0.5), math.floor(color[3] * 255 + 0.5))
    end
    return "|c" .. hex .. text .. "|r"
end

-- All settings live in Settings > Add-ons > Arclight Taunt (LibAddonMenu-2.0).
-- The integration does not package or modify the third-party library.
-- Native ESO buttons in one supported LAM custom row. Equal widths and a
-- bounded font fit keep translated actions aligned without patching LAM.
local function ActionRow(actions, maxButtonWidth)
    return {
        type = "custom", width = "full", minHeight = 40, maxHeight = 40,
        actions = actions,
        createFunc = function(row)
            local buttons = {}
            local measure = A.WM:CreateControl(nil, row, CT_LABEL)
            measure:SetDimensions(10000, 1000)
            A.SetHidden(measure, true)
            for i = 1, #actions do
                local action = actions[i]
                local button = A.WM:CreateControlFromVirtual(nil, row, "ZO_DefaultButton")
                button:SetText(action.name)
                button:SetClickSound("Click")
                button.data = {tooltipText = action.tooltip}
                button:SetHandler("OnMouseEnter", ZO_Options_OnMouseEnter)
                button:SetHandler("OnMouseExit", ZO_Options_OnMouseExit)
                button:SetHandler("OnClicked", function() action.func() end)
                button:GetLabelControl():SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
                buttons[i] = button
            end
            local lastWidth
            local function layout()
                local width = row:GetWidth()
                if width == lastWidth then return end
                lastWidth = width
                local gap = 12
                local buttonWidth = math.max(1, (width - gap * (#buttons - 1)) / #buttons)
                buttonWidth = math.min(buttonWidth, maxButtonWidth or buttonWidth)
                local start = (width - buttonWidth * #buttons - gap * (#buttons - 1)) / 2
                for i, button in ipairs(buttons) do
                    button:SetDimensions(buttonWidth, 28)
                    button:ClearAnchors()
                    button:SetAnchor(TOPLEFT, row, TOPLEFT, start + (i - 1) * (buttonWidth + gap), 6)
                    local font
                    for size = 18, 14, -1 do
                        font = "$(BOLD_FONT)|" .. size .. "|soft-shadow-thin"
                        measure:SetFont(font)
                        measure:SetText(actions[i].name)
                        if measure:GetTextDimensions() <= buttonWidth - 16 then break end
                    end
                    button:SetFont(font)
                end
            end
            row:SetHandler("OnSizeChanged", layout)
            layout()
        end,
    }
end
local function MakeSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end -- manifest dependency should normally guarantee it

    local panelName = "ArclightTauntSettings"
    local panelData = {
        type = "panel",
        -- LAM deliberately strips markup from the LEFT addon list; only the
        -- panel title and author are reliably colourable without patching LAM.
        name = "Arclight Taunt",
        displayName = "|c2FE6C4Arclight Taunt|r",
        author = "|cF7B95BtareN|r",
        version = "1.1.0",
        website = "https://www.esoui.com/downloads/info5008-ArclightTauntMulti-TargetTankHUD.html",
        feedback = "https://www.esoui.com/downloads/info5008-ArclightTauntMulti-TargetTankHUD.html#comments",
        registerForRefresh = true,
        registerForDefaults = true,
    }
    local panel = LAM:RegisterAddonPanel(panelName, panelData)

    local function DisplayMediaChoices(keys)
        local labels = {}
        for i, key in ipairs(keys) do labels[i] = A.TStored(key) end
        return labels
    end
    local soundChoices = {}
    for i, key in ipairs(ALERT_SOUND_CHOICES) do soundChoices[i] = A.TStored(key) end
    local function UpdateSaved(key, value)
        A.saved[key] = value
        A.Tick()
    end
    local function UpdateLayout(key, value)
        A.saved[key] = value
        A.screenX, A.screenY = nil, nil
        if key == "scale" then A.renderScale = nil end
        A.Layout()
        if key == "scale" then A.ApplyMedia() end -- recalculate physical bar pixels
        A.Tick()
    end
    -- Only plain saved controls use these helpers. Tracking resets, warning
    -- dismissal and other special actions remain explicit in their own setters.
    local function Checkbox(key, data)
        data.type = "checkbox"
        data.getFunc = function() return A.saved[key] end
        data.setFunc = function(value) UpdateSaved(key, value) end
        data.default = defaults[key]
        return data
    end
    local function ValueDropdown(key, data)
        data.type = "dropdown"
        data.getFunc = function() return A.saved[key] end
        data.setFunc = function(value)
            if A.ChoicePresent(data.choicesValues, value) then UpdateSaved(key, value) end
        end
        data.default = defaults[key]
        return data
    end
    local mediaSpecs = {}
    local function MediaDropdown(key, spec, data)
        local keys = A.BuildMediaChoices(spec.kind, spec.first, spec.alternative, A.saved[key])
        data.type, data.reference = "dropdown", A.ADDON .. spec.reference
        data.choices, data.choicesValues = DisplayMediaChoices(keys), keys
        data.getFunc = function()
            return A.ChoicePresent(keys, A.saved[key]) and A.saved[key] or defaults[key]
        end
        data.setFunc = function(value)
            if not A.ChoicePresent(keys, value) then return end
            A.saved[key] = value
            A.ApplyMedia()
            A.Tick()
        end
        data.default = defaults[key]
        spec.keys, spec.savedKey, spec.option = keys, key, data
        mediaSpecs[data.reference] = spec
        return data
    end
    local positionControls = {
            {
                    type = "slider", name = T("Position X (pixels)"), width = "half",
                    tooltip = T("Horizontal distance from screen left; alternatively drag the HUD."),
                    min = 0, max = 3840, step = 1,
                    getFunc = function() return A.saved.x end,
                    setFunc = function(value) UpdateLayout("x", math.floor(value)) end,
                    default = defaults.x,
                },
            {
                    type = "slider", name = T("Position Y (pixels)"), width = "half",
                    tooltip = T("Vertical distance from top edge."),
                    min = 0, max = 2160, step = 1,
                    getFunc = function() return A.saved.y end,
                    setFunc = function(value) UpdateLayout("y", math.floor(value)) end,
                    default = defaults.y,
                },
            Checkbox("hideInMenus", {
                    name = T("Hide HUD in menus"), width = "half",
                    tooltip = T("Hides the list in menus, except during preview or dragging."),
                }),
            Checkbox("fitToScreen", {
                    name = T("Keep HUD on screen"), width = "half",
                    tooltip = T("Keeps the HUD on screen, shrinking only when needed. Saved position is preserved."),
                }),
            {
                    type = "checkbox", name = T("Grow HUD upward"), width = "half",
                    tooltip = T("New rows grow upward from a fixed bottom edge. Switching tries to preserve the visible position."),
                    getFunc = function() return A.saved.growUp end,
                    setFunc = function(value)
                        if value == A.saved.growUp then return end
                        local top = A.root:GetTop()
                        local bottom = A.root.GetBottom and A.root:GetBottom() or
                            (top + (A.root.GetHeight and A.root:GetHeight() or 0) * (A.renderScale or A.saved.scale))
                        A.saved.y = math.floor((value and bottom or top) + 0.5)
                        A.saved.growUp = value
                        A.screenX, A.screenY = nil, nil
                        A.Layout()
                        A.Tick()
                    end,
                    default = defaults.growUp,
                },
            {
                    type="button",name=T("Reset position"),width="half",
                    tooltip=T("Reset only the HUD position to its default."),
                    func=function()
                        A.saved.x,A.saved.y=defaults.x,defaults.y;A.screenX,A.screenY=nil,nil
                        A.Layout();A.Tick()
                    end,
                },
    }
    local function WithPosition(controls)
        controls[#controls+1]={type="header",name=T("Position"),width="full"}
        for _,item in ipairs(positionControls) do controls[#controls+1]=item end
        return controls
    end
    local options = {
        {
            type = "description", width = "full",
            text = T("Your taunts at a glance. Boss warnings also work with the list hidden. Use preview/pause to adjust."),
        },
        { type = "header", name = T("Quick settings"), width = "full" },
        {
                type = "checkbox", name = T("Show preview"), width = "half",
                    tooltip = T("Starts with staggered taunts, then irregular arrivals and re-taunts for about a minute. Visible focus changes regularly. Pause to adjust."),
                getFunc = function() return A.demo end,
                setFunc = function(value)
                    A.moveStartedDemo = false
                    A.SetDemoEnabled(value)
                    A.Tick()
                end,
                default = false,
            },
        {
                type = "checkbox", name = T("Pause preview"), width = "half",
                tooltip = T("Freezes preview timers, rows and arrivals. Resume without restarting; ending preview clears pause."),
                disabled = function() return not A.demo end,
                getFunc = function() return A.demoPausedAt ~= nil end,
                setFunc = function(value) A.SetDemoPaused(value); A.Tick() end,
                default = false,
            },
        {
                type = "checkbox", name = T("Move HUD with mouse"), width = "half",
                tooltip = T("Shows the preview for dragging. Hold left mouse, move, release to save; disable afterwards. If covered by the menu, use X/Y or close it and press period to free the cursor."),
                getFunc = function() return A.moving end,
                setFunc = function(value)
                    if value and not A.moving then
                        A.moveStartedDemo = not A.demo
                        if A.moveStartedDemo then
                            A.SetDemoEnabled(true)
                        end
                    end
                    A.SetMoving(value)
                    if not value and A.moveStartedDemo then
                        A.SetDemoEnabled(false)
                        A.moveStartedDemo = false
                    end
                    A.Tick()
                end,
                default = false,
            },
        {
                type = "slider", name = T("Preview enemies"), width = "half",
                tooltip = T("Sample pool per cycle: 1–24. The visible count varies as taunts start and expire."),
                min = 1, max = 24, step = 1,
                getFunc = function() return A.demoCount or 14 end,
                setFunc = function(value)
                    A.demoCount = math.floor(value)
                    A.demoEntries = A.CreateDemo(A.demoCount)
                    A.Tick()
                end,
                default = 14,
            },
        {
                type = "slider", name = T("HUD size (%)"), width = "half",
                min = 70, max = 160, step = 5,
                getFunc = function() return math.floor(A.saved.scale * 100 + 0.5) end,
                setFunc = function(value) UpdateLayout("scale", value / 100) end,
                default = 115,
            },
        ValueDropdown("barDisplay", {
                name = T("Progress display"), width = "half",
                tooltip = T("Narrow: countdown below the name. Full row: a colored fill drains with the timer. Names and urgency stay visible."),
                choices = {T("Narrow bar"), T("Fill entire row")}, choicesValues = {"compact", "full"},
            }),
        {
            type = "submenu", name = T("List & layout"), width = "full",
            controls = WithPosition({
            Checkbox("showTauntList", {
                    name = T("Show taunt list"), width = "full",
                    tooltip = T("Hides the list; configured tracking, boss banners and sounds continue. Preview and drag mode can still show it."),
                }),
            Checkbox("mirrorTauntList", {
                    name = T("Mirror taunt list"), width = "full",
                    tooltip = T("Timers left, names right, skulls fixed beside the right stripe. Bars empty left to right; columns mirror too. Text and sorting stay unchanged."),
                }),
            ValueDropdown("columns", {
                    name = T("Columns"), width = "half",
                    tooltip = T("One column saves width; two columns save height."),
                    choices = {T("One column"), T("Two columns")}, choicesValues = {1, 2},
                }),
            {
                    type = "slider", name = T("Rows per column"), width = "half",
                    tooltip = T("Hidden entries: +N. Active taunts sort by expiry; pinned bosses keep priority."),
                    min = 4, max = MAX_PER_COLUMN, step = 1,
                    getFunc = function() return A.saved.limit end,
                    setFunc = function(value) UpdateSaved("limit", math.floor(value)) end,
                    default = defaults.limit,
                },
            {
                    type = "slider", name = T("Column width (pixels)"), width = "full",
                    tooltip = T("Wider rows leave more space for long names. With two columns, each has this width."),
                    min = 240, max = 360, step = 10,
                    getFunc = function() return A.saved.width end,
                    setFunc = function(value) UpdateSaved("width", math.floor(value)) end,
                    default = defaults.width,
                },
            {
                    type = "slider", name = T("Extra row height (px)"), width = "half",
                    tooltip = T("Extra height above the font/bar minimum, 1 UI pixel per step. Zero is the compact readable minimum; fonts and bar thickness stay unchanged."),
                    min = 0, max = 40, step = 1,
                    getFunc = function() return A.saved.rowHeightExtra or 0 end,
                    setFunc = function(value)
                        UpdateSaved("rowHeightExtra", math.floor(FiniteBoundedNumber(value, 0, 0, 40) + 0.5))
                    end,
                    default = function()
                        local full = A.saved.barDisplay == "full"
                        return math.max(0, (full and A.ROW_HEIGHT or A.COMPACT_ROW_HEIGHT) - A.MinimumRowHeight(full))
                    end,
                },
            {
                    type = "slider", name = T("Enemy row spacing (pixels)"), width = "half",
                    tooltip = T("Row spacing; target focus reserves at least 2 px without changing this setting. Default: 2 px."),
                    min = 0, max = 8, step = 1,
                    getFunc = function() return A.saved.rowGap end,
                    setFunc = function(value) UpdateSaved("rowGap", math.floor(value)) end,
                    default = defaults.rowGap,
                },
            Checkbox("smartTime", {
                    name = T("Smart countdown display"), width = "full",
                    tooltip = T("Whole seconds above 5 s; tenths at 5 s or less. Color thresholds are independent."),
                }),
            }),
        },
        {
            type = "submenu", name = T("Appearance & readability"), width = "full",
            controls = {
            {
                    type = "checkbox", name = Colored(T("High contrast"), "FFFFFF"), width = "full",
                    tooltip = T("Vivid colors and shaded surfaces in both styles. Fonts stay unchanged; focus remains outside the row. Disabling restores your saved appearance."),
                    getFunc = function() return A.saved.highContrast end,
                    setFunc = function(value)
                        A.saved.highContrast = value
                        A.ApplyMedia()
                        A.Tick()
                    end,
                    default = defaults.highContrast,
                },
            Checkbox("highlightTarget", {
                    name = Colored(T("Highlight current target"), "D4F0FF"), width = "full",
                    tooltip = T("Pale outline around the current target, with a brief light sweep on target changes. Names and urgency colors stay unchanged."),
                }),
            {
                    type = "slider", name = T("Background opacity (%)"), width = "half",
                    disabled = function() return A.saved.highContrast end,
                    min = 25, max = 100, step = 5,
                    getFunc = function() return math.floor(A.saved.opacity * 100 + 0.5) end,
                    setFunc = function(value) UpdateSaved("opacity", value / 100) end,
                    default = 72,
                },
            MediaDropdown("fontKey", {reference="FontChoice", kind="font", first=MEDIA_FONT_DEFAULT}, {
                    name = T("Font"), width = "half",
                    tooltip = T("Fonts from LibMediaProvider. Arclight uses the ESO font by default; other fonts may differ by language."),
                }),
            MediaDropdown("timerFontKey", {reference="TimerFontChoice", kind="font",
                first=MEDIA_TIMER_INHERIT, alternative=MEDIA_FONT_DEFAULT}, {
                    name = T("Countdown font"), width = "half",
                    tooltip = T("Separate LibMediaProvider font for timers. Default: enemy-name font. Narrow or monospaced digits can improve readability."),
                }),
            {
                    type = "slider", name = T("Font size (%)"), width = "half",
                    tooltip = T("Adjust text size. Long names may be shortened; the readable row minimum follows the font."),
                    min = 85, max = 115, step = 5,
                    getFunc = function() return A.saved.fontSize end,
                    setFunc = function(value)
                        A.saved.fontSize = math.floor(value)
                        A.ApplyMedia()
                        A.Tick()
                    end,
                    default = defaults.fontSize,
                },
            MediaDropdown("barKey", {reference="BarChoice", kind="statusbar",
                first=MEDIA_BAR_DEFAULT, alternative=MEDIA_BAR_FLAT}, {
                    name = T("Bar texture"), width = "half",
                    disabled = function() return A.saved.barDisplay == "full" or A.saved.highContrast end,
                    tooltip = T("Narrow bars only. Signature (default): soft sheen; Signal: fine segments; Flat: solid color. More textures via LibMediaProvider."),
                }),
            {
                    type = "slider", name = T("Bar thickness (pixels)"), width = "half",
                    disabled = function() return A.saved.barDisplay == "full" end,
                    tooltip = T("Narrow bars: 2–6 px; high contrast uses at least 5 px without changing your setting. Full-row fills use the entire row height."),
                    min = 2, max = 6, step = 1,
                    getFunc = function() return A.saved.barHeight end,
                    setFunc = function(value)
                        A.saved.barHeight = math.floor(value)
                        A.ApplyMedia()
                        A.Tick()
                    end,
                    default = defaults.barHeight,
                },
            {
                    type = "checkbox", name = T("Emphasize bar track"), width = "full",
                    disabled = function() return A.saved.highContrast end,
                    tooltip = T("Brightens the empty narrow-bar track. Off: plain dark track."),
                    getFunc = function() return A.saved.texturedTrack end,
                    setFunc = function(value)
                        A.saved.texturedTrack = value
                        A.ApplyMedia()
                        A.Tick()
                    end,
                    default = defaults.texturedTrack,
                },
            Checkbox("subtleWarningBg", {
                    disabled = function() return A.saved.highContrast end,
                    name = Colored(T("Tint warning rows subtly"), "D8C78E"), width = "full",
                    tooltip = T("Subtle yellow/red row backgrounds near expiry. Timer and stripe keep their urgency colors."),
                }),
            {
                    type = "slider", name = Colored(T("Yellow warning at (seconds)"), C.warning), width = "half",
                    tooltip = T("Countdown and status indicator turn yellow at this remaining time. Default: 7 seconds."),
                    min = 5, max = 12, step = 1,
                    getFunc = function() return A.saved.warningAt end,
                    setFunc = function(value)
                        A.saved.warningAt = math.floor(value)
                        A.saved.dangerAt = math.min(A.saved.dangerAt, A.saved.warningAt - 1)
                        A.Tick()
                    end,
                    default = defaults.warningAt,
                },
            {
                    type = "slider", name = Colored(T("Red warning at (seconds)"), C.danger), width = "half",
                    tooltip = T("The taunt turns red at this remaining time. Default: 4 seconds."),
                    min = 1, max = 8, step = 1,
                    getFunc = function() return A.saved.dangerAt end,
                    setFunc = function(value)
                        A.saved.dangerAt = math.floor(value)
                        A.saved.warningAt = math.max(A.saved.warningAt, A.saved.dangerAt + 1)
                        A.Tick()
                    end,
                    default = defaults.dangerAt,
                },
            },
        },
        {
            type = "submenu", name = T("Bosses"), width = "full",
            controls = {
            {
                type="checkbox",name=Colored(T("Boss warning banner"),C.alertEdge),width="full",
                tooltip=T("Red banner on boss taunt expiry. Default: on. No alert after a re-taunt or combat end."),
                getFunc=function() return A.saved.bossAlertText end,
                setFunc=function(value) UpdateSaved("bossAlertText",value);if not value then A.HideBossWarning("expired") end end,
                default=defaults.bossAlertText,
            },
            {
                type="checkbox",name=Colored(T("Boss taunt early warning"),C.safe),width="full",
                tooltip=T("Turquoise warning before boss taunt expiry, below red when needed. Clears on expiry, re-taunt or recognized death. Default: on; audio optional."),
                getFunc=function() return A.saved.bossEarlyWarning end,
                setFunc=function(value) UpdateSaved("bossEarlyWarning",value);if not value then A.HideBossWarning("early") end end,
                default=defaults.bossEarlyWarning,
            },
            {
                type="dropdown",name=T("Play warning sound"),width="full",
                tooltip=T("Sound on expiry, early warning, both or off. Early audio requires early warnings. Red has priority; cooldowns are separate."),
                choices={T("Off"),T("Only on expiry"),T("Only for early warning"),T("Both warnings")},
                choicesValues={"off","expired","early","both"},
                getFunc=function()
                    if A.saved.bossAlertSound then return A.saved.bossEarlySound and "both" or "expired" end
                    return A.saved.bossEarlySound and "early" or "off"
                end,
                setFunc=function(value)
                    if value~="off" and value~="expired" and value~="early" and value~="both" then return end
                    A.saved.bossAlertSound=value=="expired" or value=="both"
                    A.saved.bossEarlySound=value=="early" or value=="both"
                    A.Tick()
                end,
                default="expired",
            },
            {
                type="dropdown",name=Colored(T("Expiry warning sound"),C.alertEdge),width="half",
                reference=A.ADDON.."ExpirySoundChoice",
                tooltip=T("Native ESO sounds. Test playback with Test warning; a listed sound may be silent on your client."),
                scrollable=true,
                disabled=function() return not A.saved.bossAlertSound end,
                choices=soundChoices,choicesValues=ALERT_SOUND_CHOICES,
                getFunc=function() return A.saved.bossAlertSoundKey end,
                setFunc=function(value) if ALERT_SOUNDS[value] then UpdateSaved("bossAlertSoundKey",value) end end,
                default=defaults.bossAlertSoundKey,
            },
            {
                type="dropdown",name=Colored(T("Early warning sound"),C.safe),width="half",
                reference=A.ADDON.."EarlySoundChoice",
                scrollable=true,
                tooltip=T("Default: Duel boundary warning. The test plays it if early audio is enabled and no real red warning has priority."),
                disabled=function() return not A.saved.bossEarlyWarning or not A.saved.bossEarlySound end,
                choices=soundChoices,choicesValues=ALERT_SOUND_CHOICES,
                getFunc=function() return A.saved.bossEarlySoundKey end,
                setFunc=function(value) if ALERT_SOUNDS[value] then UpdateSaved("bossEarlySoundKey",value) end end,
                default=defaults.bossEarlySoundKey,
            },
            ActionRow({
                {
                    name = T("Test warning"),
                    tooltip = T("Early → expiry → both, with enabled sounds. Without early warning: red only. Red has audio priority. Short red previews last at least 2 s. Click to restart; real warnings take priority."),
                    func = function() A.PreviewBossWarnings() end,
                },
            }, 280),
            { type = "header", name = Colored(T("Warning appearance"), "2FE6C4"), width = "full" },
            {
                    type = "slider", name = T("Warning opacity (%)"), width = "half",
                    tooltip = T("100% is opaque. Only the background changes; the warning design stays the same."),
                    min = 60, max = 100, step = 1,
                    getFunc = function() return A.saved.bossAlertOpacity end,
                    setFunc = function(value)
                        A.saved.bossAlertOpacity = value
                        for _, alert in pairs(A.bossAlerts) do
                            if alert.backgroundControl then
                                SetColor(alert.backgroundControl, C.alertBackground, value / 100)
                            end
                        end
                    end,
                    default = defaults.bossAlertOpacity,
                },
            {
                    type = "slider", name = T("Warning offset from top"), width = "half",
                    tooltip = T("Only moves the boss warning; independent of the enemy list."),
                    min = 50, max = 600, step = 5,
                    getFunc = function() return A.saved.bossAlertOffsetY end,
                    setFunc = function(value)
                        A.saved.bossAlertOffsetY = value
                        A.PositionBossAlerts()
                    end,
                    default = defaults.bossAlertOffsetY,
                },
            {
                type="slider",name=T("Early warning lead time (s)"),width="half",min=1,max=4,step=0.5,decimals=1,
                getFunc=function() return A.saved.bossEarlySeconds end,
                setFunc=function(value) UpdateSaved("bossEarlySeconds",math.floor(value*2+0.5)/2) end,
                default=defaults.bossEarlySeconds,
            },
            {
                type="slider",name=T("Expiry warning duration (s)"),width="half",min=1,max=4,step=0.5,decimals=1,
                tooltip=T("Red warning duration. The test uses the early lead time and keeps red for at least 2 s."),
                getFunc=function() return A.saved.bossAlertDuration end,
                setFunc=function(value) UpdateSaved("bossAlertDuration",math.floor(FiniteBoundedNumber(value,defaults.bossAlertDuration,1,4)*2+0.5)/2) end,
                default=defaults.bossAlertDuration,
            },
            { type = "header", name = Colored(T("Boss detection"), C.bossName), width = "full" },
            ValueDropdown("bossMode", {
                    name = T("Boss detection mode"), width = "full",
                    tooltip = T("Strict: official bosses. Extended: also deadly enemies. Comprehensive: also hard enemies, including some world/Craglorn bosses. Difficulty may include non-bosses; a valid unit observation is required."),
                    choices = {T("Strict (official boss bars only)"), T("Extended (including deadly enemies)"), T("Comprehensive (including hard enemies)")},
                    choicesValues = {"strict", "dangerous", "comprehensive"},
                }),
            Checkbox("bossAlertElites", {
                    name = T("Elite alerts (experimental)"), width = "full",
                    tooltip = T("Off by default: warnings require official boss tags. Enable to include difficulty-based candidates, possibly strong non-bosses."),
                }),
            Checkbox("pinBosses", {
                    name = T("Pin bosses to top"), width = "full",
                    tooltip = T("Pins bosses above other enemies, expired bosses first. Active bosses sort by time; normal removal rules apply. Default: off."),
                }),
            Checkbox("showBossIcon", {
                    name = T("Boss skull icons") .. " |t24:21:" .. A.BOSS_ICON_TEXTURE .. "|t", width = "full",
                    tooltip = T("Skulls mark bosses identified by tags or difficulty. Comprehensive may include strong non-bosses; matching names alone never qualify."),
                }),
            Checkbox("highlightBossNames", {
                    name = Colored(T("Highlight boss names"), C.bossName), width = "full",
                    tooltip = T("Champagne boss names and ivory skulls. Urgency colors and target focus stay unchanged."),
                }),

            },
        },
        {
            type = "submenu", name = T("Tracking & tests"), width = "full",
            controls = {
            {
                    type="checkbox",name=T("Track taunts on players"),width="full",
                    tooltip=T("Off: exclude confirmed player targets. On: also show your taunts on players. Unknown types stay until identified; only your own taunts are tracked."),
                    getFunc=function() return A.saved.trackPlayerTargets end,
                    setFunc=function(value)
                        A.saved.trackPlayerTargets=value==true;A.PrunePlayerTargets();A.Tick()
                    end,
                    default=false,
                },
            Checkbox("removeDead", {
                    name = T("Remove dead enemies"), width = "full",
                    tooltip = T("Removes each enemy by its ID when ESO reports death. Some deaths are not reported; combat end clears remaining entries."),
                }),
            Checkbox("showExpired", {
                    name = T("Keep expired taunts"), width = "full",
                    tooltip = T("Off: show zero for 2 s. On: keep zero until re-taunt, recognized death or combat end. Expired entries have limited slots."),
                }),
            { type = "header", name = Colored(T("Tests"), C.muted), width = "full" },
            ActionRow({
              {
                name = T("Test welcome notice"),
                tooltip = T("Show the welcome tip again. Saved settings stay unchanged."),
                func = function() A.Chat(T("Welcome! Set up your HUD: ESC > Settings > Add-ons > Arclight Taunt.")) end,
              },
              {
                name = T("Test language & fonts"),
                tooltip = T("Multi-boss banner and font sample. Russian uses ESO fonts; saved choices are preserved."),
                func = function()
                    A.ShowBossWarning(21, nil, true, "early")
                    local sample = A.language == "ru"
                        and "Аа Бб Жж Йй Щщ Ыы Ьь Ээ Юю Яя Ёё 0123456789"
                        or "Aa Zz ÄÖÜ äöü ß éèê ñ ç 0123456789"
                    A.SetAlertText("early", A.bossAlerts.early.titleText, sample)
                end,
              },
            }),
            },
        },
    }
    function A.RefreshMediaChoices(mediaType)
        for reference, spec in pairs(mediaSpecs) do
            if not mediaType or mediaType == spec.kind then
                local fresh = A.BuildMediaChoices(spec.kind, spec.first, spec.alternative, A.saved[spec.savedKey])
                local keys = spec.keys
                for i = #keys, 1, -1 do keys[i] = nil end
                for i, key in ipairs(fresh) do keys[i] = key end
                local labels = DisplayMediaChoices(keys)
                spec.option.choices, spec.option.choicesValues = labels, keys
                local control = _G[reference]
                if control and type(control.UpdateChoices) == "function" then
                    control:UpdateChoices(labels, keys)
                    control:UpdateValue()
                end
            end
        end
    end
    LAM:RegisterOptionControls(panelName, options)
    if CALLBACK_MANAGER and type(CALLBACK_MANAGER.RegisterCallback) == "function" then
        local function AlignSoundControls(opened)
            if opened ~= panel then return end
            for _, suffix in ipairs({"ExpirySoundChoice", "EarlySoundChoice"}) do
                local control = _G[A.ADDON .. suffix]
                if control and control.label then
                    control.label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
                    if control.container then
                        control.container:ClearAnchors()
                        control.container:SetAnchor(TOP, control.label, BOTTOM, 0, 2)
                    end
                end
            end
        end
        CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", AlignSoundControls)
        CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(opened)
            if panel and opened == panel then
                AlignSoundControls(opened)
                A.RefreshMediaChoices()
                A.ApplyMedia()
                A.Tick()
            end
        end)
    end
end

-- Public entry points used across modules.
A.MakeSettings = MakeSettings
