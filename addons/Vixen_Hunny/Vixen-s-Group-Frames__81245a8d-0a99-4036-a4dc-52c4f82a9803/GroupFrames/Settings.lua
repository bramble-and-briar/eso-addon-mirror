local GF = GroupFrames

-- The options are described once, in LibAddonMenu's format, and then shown
-- through LibAddonMenu on PC or LibHarvensAddonSettings on console.
--
-- Extra fields understood by both paths:
--   source      (dropdown) function returning names, values - the list is
--               rebuilt from it whenever the effect lists change
--   placeholder (dropdown) name of the "nothing selected" entry on console
--   type "status": a line of text from a function; console only (PC shows
--               the same messages in chat)

local NONE = "\1none" -- data of the console placeholder entry

local function Checkbox(name, key, tooltip, disabled)
    return {
        type = "checkbox",
        name = name,
        tooltip = tooltip,
        getFunc = function() return GF.sv[key] end,
        setFunc = function(value)
            GF.sv[key] = value
            GF.ApplyLayout()
        end,
        default = GF.defaults[key],
        disabled = disabled,
    }
end

local function Slider(name, key, min, max, step, tooltip, disabled)
    return {
        type = "slider",
        name = name,
        tooltip = tooltip,
        min = min,
        max = max,
        step = step,
        decimals = step < 1 and 2 or 0,
        getFunc = function() return GF.sv[key] end,
        setFunc = function(value)
            GF.sv[key] = value
            GF.ApplyLayout()
        end,
        default = GF.defaults[key],
        disabled = disabled,
    }
end

local function BuffSubmenu(title, names, masterKey)
    local controls = {
        {
            type = "button",
            name = "Enable all " .. title,
            width = "half",
            func = function()
                for _, name in ipairs(names) do GF.sv.buffs[name] = true end
                GF.ApplyLayout()
            end,
        },
        {
            type = "button",
            name = "Disable all " .. title,
            width = "half",
            func = function()
                for _, name in ipairs(names) do GF.sv.buffs[name] = false end
                GF.ApplyLayout()
            end,
        },
    }
    for _, name in ipairs(names) do
        controls[#controls + 1] = {
            type = "checkbox",
            name = name,
            width = "half",
            getFunc = function() return GF.sv.buffs[name] end,
            setFunc = function(value)
                GF.sv.buffs[name] = value
                GF.ApplyLayout()
            end,
            default = true,
        }
    end
    return {
        type = "submenu",
        name = title,
        controls = controls,
        disabled = function() return not (GF.sv.showBuffs and GF.sv[masterKey]) end,
    }
end

---------------------------------------------------------------------------
-- Console (LibHarvensAddonSettings)
---------------------------------------------------------------------------

-- Adds the options to a LibHarvensAddonSettings panel. Returns a function
-- that rebuilds the dynamic dropdowns (optionally skipping one option).
local function BuildConsolePanel(LHA, options)
    local settings = LHA:AddAddon("GroupFrames", { allowDefaults = false, allowRefresh = true })
    local dynamic = {} -- option -> setting

    local function Add(o)
        local kind = o.type
        if kind == "header" then
            settings:AddSetting({ type = LHA.ST_SECTION, label = o.name })
        elseif kind == "description" then
            settings:AddSetting({ type = LHA.ST_LABEL, label = o.text })
        elseif kind == "status" then
            settings:AddSetting({ type = LHA.ST_LABEL, label = o.text })
        elseif kind == "checkbox" then
            settings:AddSetting({
                type = LHA.ST_CHECKBOX,
                label = o.name,
                tooltip = o.tooltip,
                getFunction = o.getFunc,
                setFunction = o.setFunc,
                disable = o.disabled,
            })
        elseif kind == "slider" then
            settings:AddSetting({
                type = LHA.ST_SLIDER,
                label = o.name,
                tooltip = o.tooltip,
                min = o.min,
                max = o.max,
                step = o.step,
                format = o.step < 1 and "%.2f" or "%.0f",
                getFunction = o.getFunc,
                setFunction = o.setFunc,
                disable = o.disabled,
            })
        elseif kind == "button" then
            settings:AddSetting({
                type = LHA.ST_BUTTON,
                label = o.name,
                buttonText = o.name,
                tooltip = o.tooltip,
                clickHandler = function() o.func() end,
                disable = o.disabled,
            })
        elseif kind == "editbox" then
            settings:AddSetting({
                type = LHA.ST_EDIT,
                label = o.name,
                tooltip = o.tooltip,
                getFunction = o.getFunc,
                setFunction = o.setFunc,
                disable = o.disabled,
            })
        elseif kind == "dropdown" then
            local items = {}
            local function Build()
                local names, values
                if o.source then
                    names, values = o.source()
                else
                    names, values = o.choices, o.choicesValues
                end
                values = values or names
                ZO_ClearNumericallyIndexedTable(items)
                if o.placeholder then
                    items[1] = { name = o.placeholder, data = NONE }
                end
                for i, name in ipairs(names) do
                    items[#items + 1] = { name = name, data = values[i] }
                end
                return items
            end
            Build()
            local setting = settings:AddSetting({
                type = LHA.ST_DROPDOWN,
                label = o.name,
                tooltip = o.tooltip,
                items = o.source and Build or items,
                -- the library looks the current entry up by its name and
                -- must always get a string
                getFunction = function()
                    local value = o.getFunc()
                    for _, item in ipairs(items) do
                        if item.data == value then return item.name end
                    end
                    return items[1] and items[1].name or ""
                end,
                setFunction = function(_, _, item)
                    local value = item and item.data
                    if value == NONE then value = nil end
                    o.setFunc(value)
                end,
                disable = o.disabled,
            })
            if o.source then dynamic[o] = setting end
        elseif kind == "submenu" then
            settings:AddSetting({ type = LHA.ST_SECTION, label = o.name })
            for _, child in ipairs(o.controls) do Add(child) end
        end
    end

    for _, o in ipairs(options) do Add(o) end

    return function(except)
        for o, setting in pairs(dynamic) do
            if o ~= except and setting.control then
                setting:UpdateControl()
            end
        end
    end
end

---------------------------------------------------------------------------
-- Options
---------------------------------------------------------------------------

function GF.CreateSettings()
    local console = IsConsoleUI() and LibHarvensAddonSettings ~= nil
    local LAM = LibAddonMenu2
    if not console and not LAM then return end

    local buffsOff = function() return not GF.sv.showBuffs end

    -- state of the "Additional effects" controls
    local pendingSeen, pendingText, pendingRemove = nil, "", nil
    local pendingMember = "" -- @account of the chosen groupmate, "" = everyone
    local pendingShared = nil
    local status = "" -- result of the last button press, shown on console

    local RefreshEffectControls -- assigned once the panel exists

    local function Report(display, reason)
        if display then
            status = "Now tracking " .. display
        else
            status = reason or ""
        end
        if status ~= "" then d("GroupFrames: " .. status) end
    end

    local function SortedKeys(source, display)
        local keys = {}
        for key in pairs(source) do keys[#keys + 1] = key end
        table.sort(keys, function(a, b) return display(a):lower() < display(b):lower() end)
        local names = {}
        for i, key in ipairs(keys) do names[i] = display(key) end
        return names, keys
    end

    local memberDropdown = {
        type = "dropdown",
        name = "Groupmate",
        tooltip = "Pick a groupmate to list only the effects seen on them, or Everyone for the whole group.",
        choices = { "Everyone" },
        choicesValues = { "" },
        source = function()
            local names, keys = GF.GetGroupMembers()
            table.insert(names, 1, "Everyone")
            table.insert(keys, 1, "")
            -- fall back to Everyone when the chosen groupmate has left
            local found = false
            for _, key in ipairs(keys) do
                if key == pendingMember then found = true end
            end
            if not found then pendingMember = "" end
            return names, keys
        end,
        getFunc = function() return pendingMember end,
        scrollable = 13,
        reference = "GroupFramesMemberDropdown",
        disabled = buffsOff,
    }
    memberDropdown.setFunc = function(value)
        pendingMember = value or ""
        pendingSeen = nil
        RefreshEffectControls(memberDropdown)
    end

    local seenDropdown = {
        type = "dropdown",
        name = "Effects seen on them",
        tooltip = "Effects that are or were active on the chosen groupmate this session. Press Refresh lists while the effect is active if it is missing.",
        choices = {},
        placeholder = "(choose an effect)",
        source = function()
            local names = GF.GetAddableEffects(pendingMember)
            return names, names
        end,
        getFunc = function() return pendingSeen end,
        setFunc = function(value) pendingSeen = value end,
        scrollable = 12,
        width = "half",
        reference = "GroupFramesSeenDropdown",
        disabled = buffsOff,
    }

    local trackedDropdown = {
        type = "dropdown",
        name = "Tracked effects",
        tooltip = "The additional effects you are tracking. Pick one to remove it.",
        choices = {},
        placeholder = "(choose an effect)",
        source = function()
            if pendingRemove ~= nil and not GF.sv.trackedEffects[pendingRemove] then pendingRemove = nil end
            return SortedKeys(GF.sv.trackedEffects, function(key) return GF.sv.trackedEffects[key] end)
        end,
        getFunc = function() return pendingRemove end,
        setFunc = function(value) pendingRemove = value end,
        scrollable = 12,
        width = "half",
        reference = "GroupFramesTrackedDropdown",
    }

    local sharedDropdown = {
        type = "dropdown",
        name = "Shared with you",
        tooltip = "Effects groupmates have shared this session that you are not tracking yet.",
        choices = {},
        placeholder = "(choose an effect)",
        source = function()
            if pendingShared ~= nil and not GF.sharedEffects[pendingShared] then pendingShared = nil end
            return SortedKeys(GF.sharedEffects, function(key)
                local entry = GF.sharedEffects[key]
                return entry.display .. " - from " .. entry.from
            end)
        end,
        getFunc = function() return pendingShared end,
        setFunc = function(value) pendingShared = value end,
        scrollable = 12,
        width = "half",
        reference = "GroupFramesSharedDropdown",
    }

    local dynamicDropdowns = { memberDropdown, seenDropdown, trackedDropdown, sharedDropdown }

    local screenWidth = zo_floor(GuiRoot:GetWidth())
    local screenHeight = zo_floor(GuiRoot:GetHeight())

    local options = {
        { type = "header", name = "General" },
        Checkbox("Replace default group frames", "replaceDefault",
            "Hides the game's own group and raid frames so only GroupFrames is shown."),
        Checkbox("Show when not grouped", "showSolo", "Shows a frame for yourself while you are not in a group."),
        Checkbox("Show account names", "useDisplayName", "Shows @account names instead of character names."),

        { type = "header", name = "Layout" },
        {
            type = "description",
            text = console
                and "Move the frames with the position sliders. Turn on the preview to see a full group while solo, then close the menu to look at it."
                or "Unlock the frames to drag them, or use the position sliders. While unlocked, the mouse wheel scales them and Shift + wheel changes their width. Use the preview to arrange a full group while solo.",
        },
        {
            type = "button",
            name = "Toggle 12-frame preview",
            tooltip = "Shows 12 copies of your own frame. Also available as /groupframes test [count].",
            width = "half",
            func = function()
                GF.SetPreview(not GF.previewCount and 12 or nil)
                status = GF.previewCount and "Preview on" or "Preview off"
            end,
        },
        {
            type = "slider",
            name = "Position X",
            tooltip = "Distance of the frames from the left edge of the screen.",
            min = 0, max = screenWidth, step = 5,
            getFunc = function() return zo_round(GF.sv.left) end,
            setFunc = function(value)
                GF.sv.left = value
                GF.ApplyLayout()
            end,
        },
        {
            type = "slider",
            name = "Position Y",
            tooltip = "Distance of the frames from the top edge of the screen.",
            min = 0, max = screenHeight, step = 5,
            getFunc = function() return zo_round(GF.sv.top) end,
            setFunc = function(value)
                GF.sv.top = value
                GF.ApplyLayout()
            end,
        },
        Slider("Scale", "scale", 0.5, 2, 0.05),
        Slider("Frame width", "width", 100, 400, 5),
        {
            type = "dropdown",
            name = "Direction",
            tooltip = "Vertical stacks members downwards and wraps into new columns. Horizontal places them side by side and wraps into new rows.",
            choices = { "Vertical", "Horizontal" },
            choicesValues = { "vertical", "horizontal" },
            getFunc = function() return GF.sv.orientation end,
            setFunc = function(value)
                GF.sv.orientation = value
                GF.ApplyLayout()
            end,
            default = "vertical",
        },
        Slider("Wrap after (0 = auto)", "wrapAfter", 0, 12, 1,
            "Number of frames before a new column/row starts. 0 wraps automatically when the frames would run off the screen."),
        Checkbox("Balance wrapped columns/rows", "balanceWrap",
            "Splits members evenly, e.g. 6 + 6 instead of 8 + 4."),
        Checkbox("Adaptive size", "adaptiveSize",
            "Shrinks the frames when the group is larger than the threshold below."),
        Slider("Shrink above this many members", "compactAbove", 1, 11, 1, nil,
            function() return not GF.sv.adaptiveSize end),
        Slider("Shrunk size", "compactFactor", 0.5, 1, 0.05,
            "Size of the frames in large groups relative to their normal size.",
            function() return not GF.sv.adaptiveSize end),

        { type = "header", name = "Appearance" },
        Slider("Background opacity", "bgAlpha", 0, 1, 0.05),
        Checkbox("Show role icons", "showRoleIcons",
            "Shows the selected group role next to the name (class icon when no role is set)."),
        Checkbox("Highlight my own frame", "highlightSelf", "Gives your own frame a gold border and name."),
        Checkbox("Smooth bar animation", "smoothBars", "Bars glide to their new value instead of jumping."),
        Checkbox("Show damage shields", "showShields",
            "Overlays active damage shields on the health bar.", function() return not GF.sv.showHealth end),

        { type = "header", name = "Resources" },
        {
            type = "description",
            text = GF.hasGroupResources
                and "Magicka and stamina of other members come from LibGroupResources. Bars stay dimmed for members who do not run the library or have sharing disabled."
                or "|cff5555LibGroupResources is not installed.|r Magicka and stamina can only be shown for yourself until you install it.",
        },
        Checkbox("Track health", "showHealth"),
        Checkbox("Show health percentage", "showHealthText", nil, function() return not GF.sv.showHealth end),
        Checkbox("Track magicka", "showMagicka"),
        Checkbox("Track stamina", "showStamina"),
        Slider("Health bar height", "healthHeight", 6, 40, 1),
        Slider("Magicka / stamina bar height", "resourceHeight", 2, 20, 1),

        { type = "header", name = "Ultimate, combat stats and weapon bar" },
        {
            type = "description",
            text = (GF.hasCombatStats
                    and "Ultimate, DPS and HPS come from LibGroupCombatStats and show for members who run it."
                    or "|cff5555LibGroupCombatStats is not installed.|r Ultimate shows only for yourself, and DPS/HPS not at all, until you install it.")
                .. " The line under the bars shows DPS in red and HPS in green (in thousands)."
                .. (GF.canShareBar
                    and " Front/back bar is shared by GroupFrames itself, so it only shows for members who also use this addon."
                    or " |cff5555Front/back bar of other members needs LibGroupBroadcast.|r"),
        },
        Checkbox("Show ultimate", "showUlt",
            "Gold bar with the icon of the member's current ultimate. It fills towards the cost of that ultimate, shows current / needed points, and lights up when it can be cast."),
        Slider("Ultimate bar height", "ultHeight", 10, 40, 1, nil, function() return not GF.sv.showUlt end),
        Checkbox("Show DPS", "showDps"),
        Checkbox("Show HPS", "showHps"),
        Checkbox("Show front / back bar", "showBar", "Shows which weapon bar each member is currently on."),
        Checkbox("Share my weapon bar", "shareBar",
            "Tells groupmates who use GroupFrames which bar you are on.",
            function() return not GF.canShareBar end),

        { type = "header", name = "Buffs" },
        Checkbox("Track buffs", "showBuffs"),
        Slider("Icon size", "iconSize", 12, 48, 1, nil, buffsOff),
        Slider("Maximum icons per member", "maxIcons", 1, 20, 1, nil, buffsOff),
        Checkbox("Show remaining time", "showTimers", nil, buffsOff),
        {
            type = "dropdown",
            name = "Sort effects by",
            tooltip = "Order of the effect icons from left to right. Effects without a duration count as the longest.",
            choices = {
                "Type (Major, Minor, added)",
                "Remaining time: shortest first",
                "Remaining time: longest first",
                "Max duration: shortest first",
                "Max duration: longest first",
            },
            choicesValues = { "default", "remainingAsc", "remainingDesc", "durationAsc", "durationDesc" },
            getFunc = function() return GF.sv.sortMode end,
            setFunc = function(value)
                GF.sv.sortMode = value
                GF.ApplyLayout()
            end,
            default = "default",
            disabled = buffsOff,
        },
        Checkbox("Track other Major/Minor buffs", "trackOtherMajorMinor",
            "Also shows Major/Minor buffs that are not in the lists below.", buffsOff),
        Checkbox("Track Major/Minor debuffs", "trackDebuffs",
            "Also shows Major/Minor debuffs on group members (e.g. Major Defile, Minor Vulnerability).", buffsOff),

        -- Other buffs: everything that is not a Major/Minor buff
        { type = "header", name = "Other buffs (additional effects)" },
        {
            type = "description",
            text = "Track any other effect on group members. It is shown with its icon and remaining time after the Major/Minor buffs. Pick it from the effects seen on a groupmate, or type its name or ability id.",
        },
        { type = "status", text = function() return status ~= "" and ("|cffd040" .. status .. "|r") or " " end },
        memberDropdown,
        seenDropdown,
        {
            type = "button",
            name = "Add selected effect",
            width = "half",
            func = function()
                Report(GF.AddTrackedEffect(pendingSeen))
                pendingSeen = nil
                RefreshEffectControls()
            end,
            disabled = function() return buffsOff() or not pendingSeen end,
        },
        {
            type = "editbox",
            name = "Effect name or ability id",
            tooltip = "A name tracks every ability with that name. An ability id tracks only that exact ability.",
            getFunc = function() return pendingText end,
            setFunc = function(value) pendingText = value or "" end,
            width = "half",
            disabled = buffsOff,
        },
        {
            type = "button",
            name = "Add typed effect",
            width = "half",
            func = function()
                Report(GF.AddTrackedEffect(pendingText))
                pendingText = ""
                RefreshEffectControls()
            end,
            disabled = function() return buffsOff() or pendingText == "" end,
        },
        trackedDropdown,
        {
            type = "button",
            name = "Remove selected effect",
            width = "half",
            func = function()
                if pendingRemove ~= nil then
                    status = "Removed " .. tostring(GF.sv.trackedEffects[pendingRemove])
                end
                GF.RemoveTrackedEffect(pendingRemove)
                pendingRemove = nil
                RefreshEffectControls()
            end,
            disabled = function() return pendingRemove == nil end,
        },
        {
            type = "button",
            name = "Refresh lists",
            tooltip = "Rescans you and your group for active effects.",
            width = "half",
            func = function() RefreshEffectControls() end,
        },

        { type = "header", name = "Share with groupmates" },
        {
            type = "description",
            text = GF.canShare
                and "Send your additional effects to groupmates who also use GroupFrames. They choose which ones to add, and anything they share with you appears below."
                or ("|cff5555" .. (GF.shareError or "LibGroupBroadcast is not installed.") .. "|r"),
        },
        {
            type = "button",
            name = "Share my effects",
            tooltip = "Sends your tracked effects list to everyone in your group.",
            width = "half",
            func = function()
                local _, message = GF.ShareTrackedEffects()
                Report(nil, message)
            end,
            disabled = function() return not GF.canShare end,
        },
        Checkbox("Add shared effects automatically", "autoAcceptShared",
            "Start tracking effects as soon as a groupmate shares them, without asking."),
        sharedDropdown,
        {
            type = "button",
            name = "Add selected shared effect",
            width = "half",
            func = function()
                GF.AcceptSharedEffect(pendingShared)
                pendingShared = nil
                RefreshEffectControls()
            end,
            disabled = function() return pendingShared == nil end,
        },
        {
            type = "button",
            name = "Add all shared effects",
            width = "half",
            func = function()
                GF.AcceptSharedEffect()
                pendingShared = nil
                RefreshEffectControls()
            end,
            disabled = function() return next(GF.sharedEffects) == nil end,
        },

        { type = "header", name = "Major and Minor buff lists" },
        Checkbox("Track Major buffs", "trackMajor", nil, buffsOff),
        BuffSubmenu("Major buffs", GF.MAJOR_BUFFS, "trackMajor"),
        Checkbox("Track Minor buffs", "trackMinor", nil, buffsOff),
        BuffSubmenu("Minor buffs", GF.MINOR_BUFFS, "trackMinor"),

        -- console has no error popups, so problems are reported here
        { type = "header", name = "Diagnostics" },
        { type = "status", text = function() return GF.GetDiagnostics() end },
    }

    if console then
        local refreshConsole = BuildConsolePanel(LibHarvensAddonSettings, options)
        RefreshEffectControls = function(except)
            refreshConsole(except)
            GF.ApplyLayout()
        end
    else
        local panel = LAM:RegisterAddonPanel("GroupFramesOptions", {
            type = "panel",
            name = "GroupFrames",
            displayName = "GroupFrames",
            author = "Vixen Hunny",
            version = GF.version,
            slashCommand = "/groupframessettings",
            registerForRefresh = true,
            registerForDefaults = true,
        })

        RefreshEffectControls = function()
            for _, o in ipairs(dynamicDropdowns) do
                local control = _G[o.reference]
                if control then
                    control:UpdateChoices(o.source())
                    control:UpdateValue()
                end
            end
            GF.ApplyLayout()
        end

        local lamOptions = {
            {
                type = "checkbox",
                name = "Lock position",
                tooltip = "Unlock to drag the frames. You can also use /groupframes to toggle this while the HUD is visible.",
                getFunc = function() return GF.sv.locked end,
                setFunc = function(value) GF.SetLocked(value) end,
                default = true,
            },
        }
        for _, o in ipairs(options) do
            if o.type ~= "status" then lamOptions[#lamOptions + 1] = o end
        end

        local function OnPanel(openedPanel)
            if openedPanel == panel then RefreshEffectControls() end
        end
        CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", OnPanel)
        CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", OnPanel)

        LAM:RegisterOptionControls("GroupFramesOptions", lamOptions)
    end

    GF.OnSharedEffectsChanged = function() RefreshEffectControls() end
end
