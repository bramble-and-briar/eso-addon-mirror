PBsKillLog = PBsKillLog or {}
local ADDON = PBsKillLog
local L = ADDON.L

-- Position and size move in fives: a d-pad press that moves the window one unit at a time would
-- take a minute to cross the screen, and nobody can see the difference between 212 and 215.
local LAYOUT_STEP = 5

-- Re-reads every row from the saved values, for when they were changed from outside the panel
-- (the window dragged with the mouse, or reset). Only while the panel is the one on screen.
function ADDON.RefreshSettingsPanel()
    local panel = ADDON.settingsPanel
    if panel and panel.selected and panel.UpdateControls then
        panel:UpdateControls()
    end
end

function ADDON.InitializeSettings()
    local Library = LibHarvensAddonSettings
    if not Library then
        return
    end

    local settings = Library:AddAddon(ADDON.title)
    if not settings then
        return
    end
    ADDON.settingsPanel = settings
    settings.allowDefaults = true
    settings.author = ADDON.author
    settings.version = ADDON.version

    -- The preview follows the panel -- see "Following the settings panel" in Preview.lua for why
    -- this callback alone is not enough on console. Registered on the client's callback manager,
    -- beside everyone else's.
    CALLBACK_MANAGER:RegisterCallback(
        "LibHarvensAddonSettings_AddonSelected",
        function(_, addonSettings)
            ADDON.preview:OnAddonSelected(addonSettings)
        end
    )

    local sv = ADDON.sv
    local defaults = ADDON.defaults

    -- The sliders' ranges are the screen. GuiRoot is the space the anchor offsets are measured in,
    -- so its size is the furthest any distance or size can usefully go.
    local rootWidth = zo_floor(GuiRoot:GetWidth())
    local rootHeight = zo_floor(GuiRoot:GetHeight())

    local function AddSection(key)
        settings:AddSetting({
            type = Library.ST_SECTION or Library.ST_LABEL,
            label = L(key),
        })
    end

    local function AddCheckbox(labelKey, tipKey, default, getFunction, setFunction)
        settings:AddSetting({
            type = Library.ST_CHECKBOX,
            label = L(labelKey),
            tooltip = L(tipKey),
            default = default,
            getFunction = getFunction,
            setFunction = setFunction,
        })
    end

    -- A slider over one saved value; moving it applies the value to the window.
    local function AddSlider(labelKey, tipKey, key, min, max, step, apply)
        settings:AddSetting({
            type = Library.ST_SLIDER,
            label = L(labelKey),
            tooltip = L(tipKey),
            min = min,
            max = max,
            step = step,
            default = defaults[key],
            format = "%d",
            unit = "",
            getFunction = function()
                return sv[key]
            end,
            setFunction = function(value)
                sv[key] = value
                apply()
            end,
        })
    end

    settings:AddSetting({
        type = Library.ST_LABEL,
        label = L("EXPLANATION"),
    })

    AddCheckbox("PREVIEW", "PREVIEW_TIP", defaults.preview,
        function() return sv.preview end,
        function(value)
            sv.preview = value
            -- Shows the frame if the panel is open, hides it if the option was just switched off.
            ADDON.preview:SetPanelOpen(true)
        end)

    -- Moving the window with the mouse needs a mouse; there is nothing to unlock on a console.
    if ADDON.CAN_EDIT_WITH_MOUSE then
        AddCheckbox("UNLOCK", "UNLOCK_TIP", false, ADDON.IsUnlocked, ADDON.SetUnlocked)
    end

    -- ---- Window --------------------------------------------------------------------------
    AddSection("SECTION_WINDOW")
    AddSlider("POS_X", "POS_X_TIP", "left", 0, rootWidth, LAYOUT_STEP, ADDON.ApplyLayout)
    AddSlider("POS_Y", "POS_Y_TIP", "top", 0, rootHeight, LAYOUT_STEP, ADDON.ApplyLayout)
    AddSlider("WIDTH", "WIDTH_TIP", "width", ADDON.MIN_WIDTH, rootWidth, LAYOUT_STEP, ADDON.ApplyLayout)
    AddSlider("HEIGHT", "HEIGHT_TIP", "height", ADDON.MIN_HEIGHT, rootHeight, LAYOUT_STEP, ADDON.ApplyLayout)

    -- ---- Text ----------------------------------------------------------------------------
    AddSection("SECTION_TEXT")
    AddSlider("FONT_SIZE", "FONT_SIZE_TIP", "fontSize", ADDON.MIN_FONT_SIZE, ADDON.MAX_FONT_SIZE, 1, ADDON.ApplyFont)

    -- ---- Layer ---------------------------------------------------------------------------
    AddSection("SECTION_LAYER")

    local tierItems = {}
    local tierItemByKey = {}
    for _, tier in ipairs({
        { key = "low", labelKey = "TIER_LOW" },
        { key = "medium", labelKey = "TIER_MEDIUM" },
        { key = "high", labelKey = "TIER_HIGH" },
    }) do
        local item = { name = L(tier.labelKey), data = tier.key }
        tierItems[#tierItems + 1] = item
        tierItemByKey[tier.key] = item
    end

    settings:AddSetting({
        type = Library.ST_DROPDOWN,
        label = L("DRAW_TIER"),
        tooltip = L("DRAW_TIER_TIP"),
        items = tierItems,
        default = tierItemByKey[defaults.drawTier].name,
        getFunction = function()
            -- Never nil: a dropdown handed nil falls back to showing its first item, which reads
            -- as the setting having reset itself.
            return (tierItemByKey[sv.drawTier] or tierItemByKey[defaults.drawTier]).name
        end,
        setFunction = function(combobox, name, item)
            sv.drawTier = item.data
            ADDON.ApplyLayer()
        end,
    })

    AddSlider("DRAW_LEVEL", "DRAW_LEVEL_TIP", "drawLevel", 0, ADDON.MAX_DRAW_LEVEL, LAYOUT_STEP, ADDON.ApplyLayer)

    -- ---- Sound ---------------------------------------------------------------------------
    AddSection("SECTION_SOUND")
    AddCheckbox("KILL_SOUND", "KILL_SOUND_TIP", defaults.killSound,
        function() return sv.killSound end,
        ADDON.SetKillSound)

    -- ---- Log -----------------------------------------------------------------------------
    AddSection("SECTION_LOG")
    settings:AddSetting({
        type = Library.ST_BUTTON,
        label = L("TEST"),
        tooltip = L("TEST_TIP"),
        buttonText = L("BUTTON_RUN"),
        clickHandler = ADDON.AddTestEntry,
    })
    settings:AddSetting({
        type = Library.ST_BUTTON,
        label = L("CLEAR"),
        tooltip = L("CLEAR_TIP"),
        buttonText = L("BUTTON_RUN"),
        clickHandler = ADDON.ClearLog,
    })
end
