-- Arclight Taunt 1.0.3 | Settings module
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
local MEDIA_BG_NONE = A.MEDIA_BG_NONE
local MEDIA_BG_OBSIDIAN = A.MEDIA_BG_OBSIDIAN
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
local function ActionRow(actions)
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
                for i, button in ipairs(buttons) do
                    button:SetDimensions(buttonWidth, 28)
                    button:ClearAnchors()
                    button:SetAnchor(TOPLEFT, row, TOPLEFT, (i - 1) * (buttonWidth + gap), 6)
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
        version = "1.0.3",
        website = "https://www.esoui.com/downloads/info5008-ArclightTauntModernTankHUD.html",
        feedback = "https://www.esoui.com/downloads/info5008-ArclightTauntModernTankHUD.html",
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
    local function UpdateDiagnostics(key, value)
        A.saved[key] = value
        -- Never resurrect an old badge when either diagnostic is enabled.
        for _, target in pairs(A.targets) do
            target.tauntStacks, target.counterEnd, target.immuneUntil = nil, nil, nil
        end
        A.TargetChanged()
        A.Tick()
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
            if spec.kind == "background" and value ~= MEDIA_BG_NONE
                and not A.RegisteredMediaPath(spec.kind, value) then return end
            A.saved[key] = value
            A.ApplyMedia()
            A.Tick()
        end
        data.default = defaults[key]
        spec.keys, spec.savedKey, spec.option = keys, key, data
        mediaSpecs[data.reference] = spec
        return data
    end
    local options = {
        {
            type = "description", width = "full",
            text = T("Arclight Taunt shows taunt timers for multiple enemies. Adjust the HUD, boss warnings and tracking here."),
        },
        { type = "header", name = T("Quick settings"), width = "full" },
        {
                type = "checkbox", name = T("Show preview"), width = "half",
                tooltip = T("Display test enemies with varied remaining durations instead of the real target list."),
                getFunc = function() return A.demo end,
                setFunc = function(value)
                    A.demo = value
                    if value then A.demoEntries = A.CreateDemo(A.demoCount or 14) end
                    A.Tick()
                end,
                default = false,
            },
        {
                type = "checkbox", name = T("Move HUD with mouse"), width = "half",
                tooltip = T("Enable to show the preview and unlock dragging. Hold left mouse button to move the HUD; position saves on release. Disable afterwards. If the menu covers the HUD, adjust X/Y or close the menu and free the cursor with the period key."),
                getFunc = function() return A.moving end,
                setFunc = function(value)
                    if value and not A.moving then
                        A.moveStartedDemo = not A.demo
                        if A.moveStartedDemo then
                            A.demo = true
                            A.demoEntries = A.CreateDemo(A.demoCount or 14)
                        end
                    end
                    A.SetMoving(value)
                    if not value and A.moveStartedDemo then
                        A.demo = false
                        A.moveStartedDemo = false
                    end
                    A.Tick()
                end,
                default = false,
            },
        {
                type = "slider", name = T("HUD size (%)"), width = "half",
                min = 70, max = 160, step = 5,
                getFunc = function() return math.floor(A.saved.scale * 100 + 0.5) end,
                setFunc = function(value) UpdateLayout("scale", value / 100) end,
                default = 125,
            },
        ValueDropdown("barDisplay", {
                name = T("Progress display"), width = "half",
                tooltip = T("Narrow bar (default): Signal strip below the name. Full row: a tinted row drains with the timer. Names and urgency colors remain visible."),
                choices = {T("Narrow bar"), T("Fill entire row")}, choicesValues = {"compact", "full"},
            }),
        {
            type = "submenu", name = T("Position & list"), width = "full",
            controls = {
            {
                    type = "slider", name = T("Preview enemies"), width = "half",
                    tooltip = T("Number of simulated enemies (1–24)."),
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
                    type = "button", name = T("Reset position"), width = "half",
                    tooltip = T("Reset only the HUD position to its default."),
                    func = function()
                        A.saved.x, A.saved.y = defaults.x, defaults.y
                        A.screenX, A.screenY = nil, nil
                        A.Layout()
                        A.Tick()
                    end,
                },
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
                    name = T("Hide HUD in menus"), width = "full",
                    tooltip = T("Hide the enemy HUD in map, inventory and settings. Keep it visible during preview or dragging."),
                }),
            Checkbox("fitToScreen", {
                    name = T("Keep HUD on screen"), width = "full",
                    tooltip = T("Keep the HUD visible at different resolutions and UI scales. Shrinks only if required; saved preferred position is preserved."),
                }),
            {
                    type = "checkbox", name = T("Grow HUD upward"), width = "full",
                    tooltip = T("Keep the lower HUD edge fixed when new enemies appear. Switching attempts to preserve the visible position."),
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
            ValueDropdown("columns", {
                    name = T("Columns"), width = "half",
                    tooltip = T("One column saves width; two columns save height."),
                    choices = {T("One column"), T("Two columns")}, choicesValues = {1, 2},
                }),
            {
                    type = "slider", name = T("Rows per column"), width = "half",
                    tooltip = T("Show hidden taunts as +N. Sorting determines which active taunts are shown first."),
                    min = 4, max = MAX_PER_COLUMN, step = 1,
                    getFunc = function() return A.saved.limit end,
                    setFunc = function(value) UpdateSaved("limit", math.floor(value)) end,
                    default = defaults.limit,
                },
            ValueDropdown("sortMode", {
                    name = T("Sorting"), width = "half",
                    tooltip = T("By remaining time: soonest expiring first. Stable by warning level: red, yellow, turquoise, keeping initial order within each level."),
                    choices = {T("By remaining time"), T("Stable by warning level")}, choicesValues = {"remaining", "stable"},
                }),
            {
                    type = "slider", name = T("Column width (pixels)"), width = "half",
                    tooltip = T("Wider rows leave more space for long names. With two columns, each has this width."),
                    min = 240, max = 360, step = 10,
                    getFunc = function() return A.saved.width end,
                    setFunc = function(value) UpdateSaved("width", math.floor(value)) end,
                    default = defaults.width,
                },
            {
                    type = "slider", name = T("Enemy row spacing (pixels)"), width = "half",
                    tooltip = T("Space between enemy rows. Smaller values save room with many taunts. Default: 2 pixels."),
                    min = 0, max = 8, step = 1,
                    getFunc = function() return A.saved.rowGap end,
                    setFunc = function(value) UpdateSaved("rowGap", math.floor(value)) end,
                    default = defaults.rowGap,
                },
            Checkbox("header", {
                    name = T("Show status header"), width = "half",
                    tooltip = T("Hidden by default. Enemy names, timers and urgency colors are sufficient. Optionally show ARCLIGHT and counters above; hidden enemies remain listed as +N below."),
                }),
            Checkbox("smartTime", {
                    name = T("Smart countdown display"), width = "full",
                    tooltip = T("Above five seconds show whole numbers; at five seconds and below show tenths. Warning colors still switch at 7 and 4 seconds."),
                }),
            },
        },
        {
            type = "submenu", name = T("Appearance & readability"), width = "full",
            controls = {
            Checkbox("highlightTarget", {
                    name = Colored(T("Highlight current target"), C.selected), width = "full",
                    tooltip = T("Highlight the clearly identified target; choose the style below. Taunt urgency colors stay intact."),
                }),
            ValueDropdown("focusStyle", {
                    name = T("Target highlight style"), width = "half",
                    disabled = function() return not A.saved.highlightTarget end,
                    tooltip = T("Subtle: right-side marker only. Strong: adds a light blue outline and glow. Taunt urgency colors remain unchanged."),
                    choices = {T("Strong"), T("Subtle")}, choicesValues = {"strong", "subtle"},
                }),
            {
                    type = "slider", name = T("Background opacity (%)"), width = "half",
                    min = 25, max = 100, step = 5,
                    getFunc = function() return math.floor(A.saved.opacity * 100 + 0.5) end,
                    setFunc = function(value) UpdateSaved("opacity", value / 100) end,
                    default = 72,
                },
            MediaDropdown("fontKey", {reference="FontChoice", kind="font", first=MEDIA_FONT_DEFAULT}, {
                    name = T("Font"), width = "half",
                    tooltip = T("Fonts provided by LibMediaProvider. The Arclight default uses the original ESO font; other fonts may vary by language."),
                }),
            MediaDropdown("timerFontKey", {reference="TimerFontChoice", kind="font",
                first=MEDIA_TIMER_INHERIT, alternative=MEDIA_FONT_DEFAULT}, {
                    name = T("Countdown font"), width = "half",
                    tooltip = T("Use a separate font for the countdown from LibMediaProvider. Default: same as enemy name. Narrow or monospaced digits may look calmer."),
                }),
            {
                    type = "slider", name = T("Font size (%)"), width = "half",
                    tooltip = T("Change text size independently of row height. Long names may be truncated."),
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
                    disabled = function() return A.saved.barDisplay == "full" end,
                    tooltip = T("Only for narrow bar. Signal (default): fine segmentation; Signature: subtle sheen; Flat: solid color. Other textures via LibMediaProvider."),
                }),
            {
                    type = "slider", name = T("Bar thickness (pixels)"), width = "half",
                    disabled = function() return A.saved.barDisplay == "full" end,
                    tooltip = T("Only for narrow bar: height from 2 to 6 pixels. Full-row display always fills the row height."),
                    min = 2, max = 6, step = 1,
                    getFunc = function() return A.saved.barHeight end,
                    setFunc = function(value)
                        A.saved.barHeight = math.floor(value)
                        A.ApplyMedia()
                        A.Tick()
                    end,
                    default = defaults.barHeight,
                },
            MediaDropdown("backgroundKey", {reference="BackgroundChoice", kind="background",
                first=MEDIA_BG_OBSIDIAN, alternative=MEDIA_BG_NONE}, {
                    name = T("Row background"), width = "half",
                    tooltip = T("Choose from Arclight backgrounds. Obsidian has a subtle gradient; Carbon features fine lines. Other backgrounds may be available through LibMediaProvider. None keeps the original urgency-tinted surface."),
                }),
            {
                    type = "checkbox", name = T("Textured bar track"), width = "half",
                    tooltip = T("Show a textured dark track behind the Signal progress bar. Disable for the plain bar track."),
                    getFunc = function() return A.saved.texturedTrack end,
                    setFunc = function(value)
                        A.saved.texturedTrack = value
                        A.ApplyMedia()
                        A.Tick()
                    end,
                    default = defaults.texturedTrack,
                },
            Checkbox("subtleWarningBg", {
                    name = T("Tint warning rows subtly"), width = "full",
                    tooltip = T("Tint rows subtly yellow or red near expiration. Timers and status markers keep their urgency colors."),
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
                    type = "checkbox", name = Colored(T("Boss warning banner"), C.alertEdge), width = "full",
                    tooltip = T("Show a brief red banner with the boss name. Enabled by default; no warning for a refreshed taunt or after combat."),
                    getFunc = function() return A.saved.bossAlertText end,
                    setFunc = function(value)
                        UpdateSaved("bossAlertText", value)
                        if not value then A.HideBossWarning("expired") end
                    end,
                    default = defaults.bossAlertText,
                },
            Checkbox("bossAlertSound", {
                    name = T("Play sound on expired boss taunt"), width = "full",
                    tooltip = T("Enabled by default. Only native ESO sounds. A four-second cooldown prevents sound spam."),
                }),
            {
                    type = "dropdown", name = T("Alert sound"), width = "full",
                    tooltip = T("ESO sounds associated with warnings or failures. Enable warning audio and use Test warning to hear the selected sound together with the banner."),
                    choices = soundChoices, choicesValues = ALERT_SOUND_CHOICES,
                    getFunc = function() return A.saved.bossAlertSoundKey end,
                    setFunc = function(value)
                        if ALERT_SOUNDS[value] then UpdateSaved("bossAlertSoundKey", value) end
                    end,
                    default = defaults.bossAlertSoundKey,
                },
            {
                    type = "checkbox", name = Colored(T("Boss taunt early warning"), C.safe), width = "full",
                    tooltip = T("Show a small turquoise warning below the red banner for your boss taunts near expiry. Both can appear together. Silent; clears on expiry, re-taunt or death. Enabled by default."),
                    getFunc = function() return A.saved.bossEarlyWarning end,
                    setFunc = function(value)
                        UpdateSaved("bossEarlyWarning", value)
                        if not value then A.HideBossWarning("early") end
                    end,
                    default = defaults.bossEarlyWarning,
                },
            {
                    type = "slider", name = T("Boss early warning at (seconds)"), width = "full",
                    min = 1, max = 4, step = 0.5, decimals = 1,
                    getFunc = function() return A.saved.bossEarlySeconds end,
                    setFunc = function(value)
                        UpdateSaved("bossEarlySeconds", math.floor(value * 2 + 0.5) / 2)
                    end,
                    default = defaults.bossEarlySeconds,
                },
            ActionRow({
                {
                    name = T("Test warning"),
                    tooltip = T("Preview red first, then turquoise 1.5 seconds later if early warnings are enabled. Red stays at least 2 seconds for this test. Sound follows the audio toggle."),
                    func = function() A.PreviewBossWarnings() end,
                },
                {
                    name = T("Test early warning"),
                    tooltip = T("Preview the small turquoise early-warning banner below the expiry banner without combat."),
                    func = function() A.ShowBossWarning(1, T("Bone Colossus"), true, "early") end,
                },
            }),
            { type = "header", name = Colored(T("Warning appearance"), "2FE6C4"), width = "full" },
            {
                    type = "slider", name = T("Warning display duration (seconds)"), width = "half",
                    tooltip = T("Duration of real red warnings and standalone previews. The combined test keeps red for at least 2 seconds. Live early warnings follow the affected taunts."),
                    min = 1, max = 4, step = 0.5, decimals = 1,
                    getFunc = function() return A.saved.bossAlertDuration end,
                    setFunc = function(value)
                        local safe = FiniteBoundedNumber(value, defaults.bossAlertDuration, 1, 4)
                        UpdateSaved("bossAlertDuration", math.floor(safe * 2 + 0.5) / 2)
                    end,
                    default = defaults.bossAlertDuration,
                },
            {
                    type = "slider", name = T("Boss warning opacity (%)"), width = "half",
                    tooltip = T("100% is fully opaque. The warning design stays the same; only background opacity changes."),
                    min = 60, max = 100, step = 5,
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
                    type = "slider", name = T("Boss warning: distance from screen top"), width = "half",
                    tooltip = T("Only moves the boss warning; independent of the enemy list."),
                    min = 50, max = 600, step = 5,
                    getFunc = function() return A.saved.bossAlertOffsetY end,
                    setFunc = function(value)
                        A.saved.bossAlertOffsetY = value
                        A.PositionBossAlerts()
                    end,
                    default = defaults.bossAlertOffsetY,
                },
            { type = "header", name = Colored(T("Boss detection"), C.bossName), width = "full" },
            ValueDropdown("bossMode", {
                    name = T("Boss detection mode"), width = "full",
                    tooltip = T("Strict: official boss unit tags only. Extended: also deadly enemies. Comprehensive (default): also hard enemies, including some Craglorn/world bosses. Difficulty does not conclusively identify bosses; powerful non-bosses can be flagged. The unit must be observed through a valid ESO unit tag."),
                    choices = {T("Strict (official boss bars only)"), T("Extended (including deadly enemies)"), T("Comprehensive (including hard enemies)")},
                    choicesValues = {"strict", "dangerous", "comprehensive"},
                }),
            Checkbox("bossAlertElites", {
                    name = T("Warn for powerful enemies too (experimental)"), width = "full",
                    tooltip = T("Off by default. Normally warn only for bosses identified through official boss unit tags; enables warnings for difficulty-based candidates, including possible elite non-bosses."),
                }),
            Checkbox("pinBosses", {
                    name = T("Pin bosses to top"), width = "full",
                    tooltip = T("Off by default. Pin detected bosses above other enemies, with expired boss taunts first. Active bosses keep the selected sorting; expired entries follow the normal removal rules."),
                }),
            Checkbox("showBossIcon", {
                    name = T("Show skull icon for bosses"), width = "full",
                    tooltip = T("Show a skull for enemies identified via boss tags or difficulty. Comprehensive mode also includes strong non-bosses. Matching names alone are never used."),
                }),
            Checkbox("highlightBossNames", {
                    name = T("Highlight boss names"), width = "full",
                    tooltip = T("Colors recognized boss names champagne gold. The skull stays ivory; urgency colors and target highlighting are unchanged."),
                }),

            },
        },
        {
            type = "submenu", name = T("Tracking & experiments"), width = "full",
            controls = {
            {
                    type = "checkbox", name = T("Show only my taunts"), width = "full",
                    tooltip = T("Off: Also track group taunts when ESO provides their effect events."),
                    getFunc = function() return A.saved.onlyMine end,
                    setFunc = function(value)
                        A.saved.onlyMine = value
                        A.targets, A.activeTarget, A.reticleUnitId = {}, nil, nil
                        A.pendingBossWarnings, A.pendingFirstAt = nil, nil
                        A.HideBossWarning()
                        A.Tick()
                    end,
                    default = defaults.onlyMine,
                },
            Checkbox("removeDead", {
                    name = T("Remove dead enemies immediately"), width = "full",
                    tooltip = T("Remove enemies by unique unit ID when death is reported. ESO does not report every death; remaining entries clear at combat end."),
                }),
            Checkbox("showExpired", {
                    name = T("Show expired taunts until combat ends"), width = "full",
                    tooltip = T("Off by default: expired taunts show 0.0 for two seconds before disappearing. Enabled: keep 0.0 until re-taunted, death is recognized or combat ends. Lost entries have limited space."),
                }),
            { type = "header", name = Colored(T("Experimental indicators"), C.warning), width = "full" },
            {
                    type = "checkbox",
                    name = T("Show taunt immunity (experimental)"), width = "full",
                    tooltip = T("Experimental diagnostic: Shows IMMUNE only for a uniquely matched, active target with a recognized immunity effect or five taunt-counter stacks. A resisted taunt may not appear in the list at all; disabled by default."),
                    getFunc = function() return A.saved.showImmunity end,
                    setFunc = function(value) UpdateDiagnostics("showImmunity", value) end,
                    default = defaults.showImmunity,
                },
            {
                    type = "checkbox",
                    name = T("Show taunt stacks (experimental)"), width = "full",
                    tooltip = T("Experimental diagnostic: Only shows an actually observed 2/5–5/5 stack count for a uniquely matched active target. Never estimated; disabled by default."),
                    getFunc = function() return A.saved.showTauntStacks end,
                    setFunc = function(value) UpdateDiagnostics("showTauntStacks", value) end,
                    default = defaults.showTauntStacks,
                },
            { type = "header", name = Colored(T("Tests"), C.muted), width = "full" },
            ActionRow({
              {
                name = T("Test welcome notice"),
                tooltip = T("Display the one-time setup tip again without resetting saved settings."),
                func = function() A.Chat(T("Welcome! Tip: Open ESC > Settings > Add-ons > Arclight Taunt to customize the HUD.")) end,
              },
              {
                name = T("Test language & fonts"),
                tooltip = T("Show a multi-boss warning and a font sample. Russian text uses ESO fonts; your saved font selection is preserved."),
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
        CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(opened)
            if panel and opened == panel then
                A.RefreshMediaChoices()
                A.ApplyMedia()
                A.Tick()
            end
        end)
    end
end

-- Public entry points used across modules.
A.MakeSettings = MakeSettings
