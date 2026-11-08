-- LibAddonMenu panel and /bev slash commands.
local BEV = BetterEffectViewer

---------------------------------------------------------------------------
-- Option builders
---------------------------------------------------------------------------

local function lamColor(t)
    return { r = t[1], g = t[2], b = t[3], a = t[4] }
end

local function checkbox(self, name, key, tooltip, onChange, extra)
    local option = {
        type = "checkbox",
        name = name,
        tooltip = tooltip,
        getFunc = function() return self.sv[key] end,
        setFunc = function(value)
            self.sv[key] = value
            if onChange then onChange(value) end
        end,
        default = self.defaults[key],
    }
    if extra then
        for k, v in pairs(extra) do option[k] = v end
    end
    return option
end

local function slider(self, name, key, min, max, step, tooltip, onChange, extra)
    local option = {
        type = "slider",
        name = name,
        tooltip = tooltip,
        min = min,
        max = max,
        step = step,
        decimals = step < 1 and 1 or 0,
        getFunc = function() return self.sv[key] end,
        setFunc = function(value)
            self.sv[key] = value
            if onChange then onChange(value) end
        end,
        default = self.defaults[key],
    }
    if extra then
        for k, v in pairs(extra) do option[k] = v end
    end
    return option
end

local function dropdown(self, name, key, entries, tooltip, onChange, extra)
    local choices, values = {}, {}
    for i, entry in ipairs(entries) do
        values[i] = entry[1]
        choices[i] = entry[2]
    end
    local option = {
        type = "dropdown",
        name = name,
        tooltip = tooltip,
        choices = choices,
        choicesValues = values,
        getFunc = function() return self.sv[key] end,
        setFunc = function(value)
            self.sv[key] = value
            if onChange then onChange(value) end
        end,
        default = self.defaults[key],
    }
    if extra then
        for k, v in pairs(extra) do option[k] = v end
    end
    return option
end

local function color(self, name, key, tooltip)
    return {
        type = "colorpicker",
        name = name,
        tooltip = tooltip,
        getFunc = function() return self:UnpackColor(self.sv[key]) end,
        setFunc = function(r, g, b, a)
            self.sv[key] = { r, g, b, a }
            self:RefreshAppearance()
        end,
        default = lamColor(self.defaults[key]),
    }
end

local function layoutSubmenu(self, title, layoutKey)
    local function layoutSlider(name, field, min, max, tooltip)
        return {
            type = "slider",
            name = name,
            tooltip = tooltip,
            min = min,
            max = max,
            step = 1,
            getFunc = function() return self.sv[layoutKey][field] end,
            setFunc = function(value)
                self.sv[layoutKey][field] = value
                self:ApplyCurrentLayout()
            end,
            default = self.defaults[layoutKey][field],
        }
    end

    return {
        type = "submenu",
        name = title,
        controls = {
            layoutSlider("Icon Size", "iconSize", 16, 72, "Width and height of each effect icon."),
            layoutSlider("Timer Font Size", "fontSize", 8, 32, "Size of the countdown text. Stack counts scale with it."),
            layoutSlider("Icons Per Row", "maxCols", 1, 20, "How many icons fit on one row before wrapping."),
        },
    }
end

local function listEditbox(self, name, listName, add, tooltip)
    return {
        type = "editbox",
        name = name,
        tooltip = tooltip,
        isMultiline = false,
        getFunc = function() return "" end,
        setFunc = function(text)
            local ids = self:ParseAbilityIds(text)
            if #ids == 0 then
                return
            end
            local changed = self:EditList(listName, ids, add)
            self:Print("%s %d ability id(s) %s the %s.", add and "Added" or "Removed", changed,
                add and "to" or "from", listName)
        end,
    }
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------

function BEV:CreateSettingsMenu()
    local LAM = LibAddonMenu2
    if not LAM then
        return
    end

    local function redraw() self:Redraw() end
    local function relayout() self:RefreshAppearance() end
    local function retune()
        self:ApplyRuntimePlatformTuning()
        self:ApplyCurrentLayout()
    end
    local function consoleTuningDisabled() return not self.sv.autoConsoleTuning end

    local panelData = {
        type = "panel",
        name = "BetterEffectViewer",
        displayName = self.title,
        author = self.author,
        version = self.version,
        slashCommand = "/bevsettings",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local options = {
        {
            type = "description",
            text = "Buffs and debuffs on whatever is under your reticle. Unlock the window to see a preview "
                .. "and drag it into place, then lock it again. Chat: |c4FC3F7/bev help|r",
        },
        checkbox(self, "Lock Window", "lockWindow",
            "Unlock to drag the window around. A preview is shown while unlocked.",
            function(value) self:SetLocked(value) end),
        {
            type = "button",
            name = "Reset Position",
            tooltip = "Move the window back to its default spot above the reticle.",
            width = "half",
            func = function() self:ResetPosition() end,
        },

        {
            type = "submenu",
            name = "Display",
            controls = {
                checkbox(self, "Show Buffs", "showBuffs", nil, redraw, { width = "half" }),
                checkbox(self, "Show Debuffs", "showDebuffs", nil, redraw, { width = "half" }),
                checkbox(self, "Show Permanent Effects", "showPermanents",
                    "Show effects with no duration or a very long one.", redraw),
                checkbox(self, "Show Target Name", "showTargetName",
                    "Show the target's name above the icons, coloured by reaction.", relayout),
                slider(self, "Target Name Font Size", "targetNameFontSize", 10, 28, 1, nil, relayout,
                    { disabled = function() return not self.sv.showTargetName end }),
                dropdown(self, "Row Order", "groupOrder", {
                    { "buffsFirst", "Buffs on top" },
                    { "debuffsFirst", "Debuffs on top" },
                }, nil, relayout),
                dropdown(self, "Icon Alignment", "alignment", {
                    { "left", "Left" },
                    { "center", "Centre" },
                    { "right", "Right" },
                }, "How partly filled rows line up.", relayout),
                checkbox(self, "Collapse Empty Rows", "collapseEmptyRows",
                    "Hide a group's row entirely when it has no effects. Off keeps the layout steady.", relayout),
                slider(self, "Max Rows Per Group", "maxRows", 1, 10, 1,
                    "Extra effects beyond this many rows are not shown.", redraw),
                slider(self, "Icon Spacing", "iconSpacing", 0, 12, 1, nil, relayout),
                slider(self, "Border Thickness", "borderSize", 1, 4, 1, nil, relayout),
                checkbox(self, "Duration Sweep", "showDurationSweep",
                    "Draw a radial sweep over icons as their duration runs down.", relayout),
                checkbox(self, "Dim Others' Effects", "dimOtherEffects",
                    "Slightly fade icons for effects you did not apply, so yours stand out.", redraw),
                slider(self, "Target Hold Time (s)", "reticleHoldDuration", 0, 5, 0.1,
                    "Keep showing the last target this long after your reticle leaves it."),
                slider(self, "Fade Out Time (s)", "fadeOutDuration", 0, 2, 0.1,
                    "How long the window takes to fade once the target is gone."),
            },
        },

        layoutSubmenu(self, "PvE Layout", "pveLayout"),
        layoutSubmenu(self, "PvP Layout (Cyrodiil, Imperial City, Battlegrounds)", "pvpLayout"),

        {
            type = "submenu",
            name = "Timers & Flashing",
            controls = {
                slider(self, "Show Tenths Below (s)", "decimalThreshold", 0, 15, 1,
                    "Timers show one decimal place under this many seconds. 0 turns it off.", redraw),
                slider(self, "Flash Below (s)", "flashThreshold", 0, 15, 1,
                    "Icons pulse towards the flash colour when about to expire. 0 turns it off.", redraw),
                color(self, "Flash Colour", "flashColor"),
            },
        },

        {
            type = "submenu",
            name = "Colours",
            controls = {
                { type = "header", name = "Borders" },
                color(self, "Your Effects", "playerEffectBorderColor", "Border for anything you applied."),
                color(self, "Buffs", "buffBorderColor"),
                color(self, "Debuffs", "debuffBorderColor"),
                color(self, "Permanent Effects", "permanentBorderColor"),
                { type = "header", name = "Text" },
                color(self, "Buff Timer", "buffTimerColor"),
                color(self, "Debuff Timer", "debuffTimerColor"),
                color(self, "Permanent Timer", "permanentTimerColor"),
                color(self, "Stack Count", "stackColor"),
            },
        },

        {
            type = "submenu",
            name = "Sorting & Filtering",
            controls = {
                dropdown(self, "Sort Effects By", "sortMode", {
                    { "shortest", "Shortest remaining" },
                    { "longest", "Longest remaining" },
                    { "newest", "Newest first" },
                    { "oldest", "Oldest first" },
                }, nil, redraw),
                checkbox(self, "Your Effects First", "playerEffectsFirst",
                    "Always place effects you applied ahead of everything else.", redraw),
                dropdown(self, "Filter Mode", "filterMode", {
                    { "none", "Show everything" },
                    { "whitelist", "Whitelist only" },
                    { "blacklist", "Hide blacklisted" },
                }, nil, function() self:OnFilterChanged() end),
                checkbox(self, "Auto-Whitelist Long Effects", "autoWhitelist",
                    "In whitelist mode, automatically whitelist effects lasting at least the duration below.", nil,
                    { disabled = function() return self.sv.filterMode ~= "whitelist" end }),
                slider(self, "Auto-Whitelist Min Duration (s)", "autoWhitelistDuration", 1, 60, 1, nil, nil,
                    { disabled = function() return self.sv.filterMode ~= "whitelist" or not self.sv.autoWhitelist end }),
                { type = "header", name = "Whitelist" },
                listEditbox(self, "Add Ability IDs", "whitelist", true,
                    "One or more ability ids, separated by spaces or commas. Press Enter to apply."),
                listEditbox(self, "Remove Ability IDs", "whitelist", false),
                {
                    type = "button",
                    name = "Print Whitelist",
                    width = "half",
                    func = function() self:PrintList("whitelist") end,
                },
                {
                    type = "button",
                    name = "Clear Whitelist",
                    width = "half",
                    isDangerous = true,
                    warning = "Removes every ability from the whitelist.",
                    func = function()
                        self:ClearList("whitelist")
                        self:Print("Whitelist cleared.")
                    end,
                },
                { type = "header", name = "Blacklist" },
                listEditbox(self, "Add Ability IDs", "blacklist", true,
                    "One or more ability ids, separated by spaces or commas. Press Enter to apply."),
                listEditbox(self, "Remove Ability IDs", "blacklist", false),
                {
                    type = "button",
                    name = "Print Blacklist",
                    width = "half",
                    func = function() self:PrintList("blacklist") end,
                },
                {
                    type = "button",
                    name = "Clear Blacklist",
                    width = "half",
                    isDangerous = true,
                    warning = "Removes every ability from the blacklist.",
                    func = function()
                        self:ClearList("blacklist")
                        self:Print("Blacklist cleared.")
                    end,
                },
            },
        },

        {
            type = "submenu",
            name = "Performance",
            controls = {
                dropdown(self, "Update Rate", "performanceMode", {
                    { "balanced", "Balanced" },
                    { "low", "Low CPU" },
                    { "ultra", "Ultra low CPU" },
                }, "Lower settings update timers less often.", function()
                    self.nextMaintenanceAt = 0
                    self.nextVisualUpdateAt = 0
                end),
                slider(self, "Fallback Rescan Interval (s)", "fallbackRescanInterval", 0.5, 5, 0.1,
                    "How often to re-read the target's effects in case an update event was missed.", function()
                        self:ApplyRuntimePlatformTuning()
                        self:RequestRescan(0)
                    end),
                { type = "header", name = "Console" },
                checkbox(self, "Auto Console Tuning", "autoConsoleTuning",
                    "On console, cap rows, columns and tracked effects and use the lowest update rate.", retune),
                slider(self, "Max Rows", "consoleSlotRowsCap", 1, 20, 1, nil, retune,
                    { disabled = consoleTuningDisabled }),
                slider(self, "Max Tracked Effects", "consoleEffectCap", 8, 256, 1, nil, retune,
                    { disabled = consoleTuningDisabled }),
                slider(self, "Max Icons Per Row", "consoleMaxColsCap", 1, 20, 1, nil, retune,
                    { disabled = consoleTuningDisabled }),
            },
        },
    }

    self.settingsPanel = LAM:RegisterAddonPanel("BetterEffectViewerPanel", panelData)
    LAM:RegisterOptionControls("BetterEffectViewerPanel", options)
end

function BEV:OpenSettings()
    if LibAddonMenu2 and self.settingsPanel then
        LibAddonMenu2:OpenToPanel(self.settingsPanel)
        return true
    end
    return false
end

---------------------------------------------------------------------------
-- Chat
---------------------------------------------------------------------------

function BEV:PrintList(listName)
    local ids = {}
    for id in pairs(self.sv[listName]) do
        ids[#ids + 1] = id
    end
    table.sort(ids)

    if #ids == 0 then
        self:Print("The %s is empty.", listName)
        return
    end

    self:Print("%s (%d):", listName, #ids)
    for _, id in ipairs(ids) do
        local name = GetAbilityName(id)
        d(string.format("  %d  %s", id, name ~= "" and zo_strformat(SI_ABILITY_NAME, name) or "|c888888unknown|r"))
    end
end

local HELP = {
    "/bev - open settings",
    "/bev lock | unlock - lock the window, or unlock it to move with a preview",
    "/bev reset - move the window back to its default position",
    "/bev whitelist add|remove <ids> - edit the whitelist (also: wl)",
    "/bev blacklist add|remove <ids> - edit the blacklist (also: bl)",
    "/bev whitelist | blacklist - print a list",
    "/bev filter none|whitelist|blacklist - change filter mode",
}

local LIST_ALIASES = { whitelist = "whitelist", wl = "whitelist", blacklist = "blacklist", bl = "blacklist" }
local FILTER_MODES = { none = true, whitelist = true, blacklist = true }

function BEV:HandleSlashCommand(text)
    local args = {}
    for word in tostring(text or ""):lower():gmatch("%S+") do
        args[#args + 1] = word
    end
    local command = args[1]

    if not command then
        if not self:OpenSettings() then
            self:Print("Settings need LibAddonMenu-2.0. Type /bev help for chat commands.")
        end
    elseif command == "help" then
        self:Print("commands")
        for _, line in ipairs(HELP) do
            d("  " .. line)
        end
    elseif command == "lock" or command == "unlock" then
        self:SetLocked(command == "lock")
        self:Print(command == "lock" and "Window locked." or "Window unlocked - drag it into place.")
    elseif command == "reset" then
        self:ResetPosition()
        self:Print("Position reset.")
    elseif command == "filter" then
        local mode = args[2]
        if FILTER_MODES[mode] then
            self.sv.filterMode = mode
            self:OnFilterChanged()
            self:Print("Filter mode: %s.", mode)
        else
            self:Print("Usage: /bev filter none|whitelist|blacklist")
        end
    elseif LIST_ALIASES[command] then
        local listName = LIST_ALIASES[command]
        local action = args[2]
        local idsText = table.concat(args, " ", 3)

        -- Back-compat: "/bev whitelist 12345" adds.
        if action and tonumber(action) then
            action, idsText = "add", table.concat(args, " ", 2)
        end

        if action == "add" or action == "remove" then
            local ids = self:ParseAbilityIds(idsText)
            if #ids == 0 then
                self:Print("Give one or more ability ids, e.g. /bev %s %s 61747", command, action)
                return
            end
            local changed = self:EditList(listName, ids, action == "add")
            self:Print("%s %d ability id(s) %s the %s.", action == "add" and "Added" or "Removed", changed,
                action == "add" and "to" or "from", listName)
        else
            self:PrintList(listName)
        end
    else
        self:Print("Unknown command '%s'. Type /bev help.", command)
    end
end

function BEV:RegisterSlashCommands()
    SLASH_COMMANDS["/bev"] = function(text)
        self:HandleSlashCommand(text)
    end
end
