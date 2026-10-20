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

    -- ---- Rank ----------------------------------------------------------------------------
    -- The rows' text is a function: it is worked out when the row is drawn, so it is current
    -- whenever the section is opened.
    AddSection("SECTION_RANK")
    settings:AddSetting({
        type = Library.ST_LABEL,
        label = function() return ADDON.records:RankLine() end,
        tooltip = L("RANK_ROW_TIP"),
        canSelect = true,
    })
    settings:AddSetting({
        type = Library.ST_LABEL,
        label = function() return ADDON.records:StatsLine() end,
        tooltip = L("RANK_ROW_TIP"),
        canSelect = true,
    })
    -- ---- Ranking window, daily records and attacks -------------------------------------------------------
    -- The number of days is not fixed, so these rows are built again every time the panel is
    -- opened and after the records are cleared. They sit in one run of the list, so the run can be
    -- taken out and a new one put in its place. Every row can be selected, which is what lets the
    -- d-pad scroll a long list.
    local MAX_DAY_ROWS = 30
    local scope = "all"
    local dynamicStart = #settings.settings + 1
    local dynamicCount = 0

    local function BuildRecordRows()
        local records = ADDON.records
        scope = "all"

        local rows = {}
        local function Row(text)
            rows[#rows + 1] = { type = Library.ST_LABEL, label = text, canSelect = true }
        end

        -- The ranking window: on or off, and which period it counts. The periods are the days and months
        -- that have records, so they are listed afresh each time.
        rows[#rows + 1] = { type = Library.ST_SECTION, label = L("SECTION_RANKING") }
        rows[#rows + 1] = {
            type = Library.ST_BUTTON,
            label = L("RANKING_BUTTON"),
            tooltip = L("RANKING_BUTTON_TIP"),
            buttonText = L("RANKING_BUTTON_TEXT"),
            clickHandler = function() ADDON.ranking:Toggle() end,
        }
        local periodItems = {}
        for _, token in ipairs(records:RankingScopes()) do
            periodItems[#periodItems + 1] = { name = records:ScopeText(token), data = token }
        end
        rows[#rows + 1] = {
            type = Library.ST_DROPDOWN,
            label = L("RANKING_PERIOD"),
            tooltip = L("RANKING_PERIOD_TIP"),
            items = periodItems,
            default = periodItems[1].name,
            -- "Reset to defaults" must not pop the ranking window up.
            ignoreDefault = true,
            getFunction = function()
                for _, item in ipairs(periodItems) do
                    if item.data == ADDON.ranking.scope then
                        return item.name
                    end
                end
                return periodItems[1].name
            end,
            setFunction = function(combobox, name, item)
                ADDON.ranking:SetScope(item.data)
                -- Choosing a period is asking to see it.
                if not ADDON.ranking.wanted then
                    ADDON.ranking:SetWanted(true)
                end
            end,
        }

        rows[#rows + 1] = { type = Library.ST_SECTION, label = L("SECTION_DAYS") }
        Row(function() return records:TodayLine() end)
        local days = records:DayKeys()
        if #days == 0 then
            Row(L("NO_RECORDS"))
        end
        for index = 1, math.min(#days, MAX_DAY_ROWS) do
            Row(records:DayLine(days[index]))
        end
        if #days > MAX_DAY_ROWS then
            Row(string.format(L("MORE_DAYS"), #days - MAX_DAY_ROWS))
        end

        rows[#rows + 1] = { type = Library.ST_SECTION, label = L("SECTION_ABILITIES") }
        local items = { { name = L("SCOPE_ALL"), data = "all" } }
        for index = 1, math.min(#days, MAX_DAY_ROWS) do
            items[#items + 1] = { name = records:DayLine(days[index]), data = days[index] }
        end
        rows[#rows + 1] = {
            type = Library.ST_DROPDOWN,
            label = L("SCOPE"),
            tooltip = L("SCOPE_TIP"),
            items = items,
            default = items[1].name,
            getFunction = function()
                for _, item in ipairs(items) do
                    if item.data == scope then
                        return item.name
                    end
                end
                return items[1].name
            end,
            setFunction = function(combobox, name, item)
                scope = item.data
                -- The lists below read the scope when they are drawn.
                settings:UpdateControls()
            end,
        }
        local function AddList(headingKey, kind)
            Row(L(headingKey))
            for rank = 1, 5 do
                Row(function() return records:EntryLine(kind, rank, records:Top(kind, scope, 5)[rank]) end)
            end
        end
        AddList("KILLED_WITH", "killedWith")
        AddList("DIED_TO", "diedTo")
        return rows
    end

    function ADDON.RebuildRecordRows()
        settings:RemoveSettings(dynamicStart, dynamicCount)
        local rows = BuildRecordRows()
        settings:AddSettings(rows, dynamicStart)
        dynamicCount = #rows
    end

    do
        local rows = BuildRecordRows()
        settings:AddSettings(rows)
        dynamicCount = #rows
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

    -- Deleting records is asked about first, and does nothing if it cannot be asked.
    for _, button in ipairs({ { key = "CLEAR_DAYS", kind = "days" }, { key = "RESET_ALL", kind = "all" } }) do
        settings:AddSetting({
            type = Library.ST_BUTTON,
            label = L(button.key),
            tooltip = L(button.key .. "_TIP"),
            buttonText = L("BUTTON_RUN"),
            clickHandler = function()
                if not ADDON.records:ConfirmClear(button.kind, ADDON.RebuildRecordRows) then
                    ADDON.Print(L("ERR_NO_DIALOG"))
                end
            end,
        })
    end

    -- Registered on the client's callback manager, beside everyone else's. It runs before the
    -- library draws the panel, so the day rows are current when it appears. The preview follows the
    -- panel as well -- see "Following the settings panel" in Preview.lua for why this callback alone
    -- is not enough on console.
    CALLBACK_MANAGER:RegisterCallback(
        "LibHarvensAddonSettings_AddonSelected",
        function(_, addonSettings)
            if addonSettings == settings then
                ADDON.RebuildRecordRows()
            end
            ADDON.preview:OnAddonSelected(addonSettings)
        end
    )
end
