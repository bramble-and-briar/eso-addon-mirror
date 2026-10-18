CompanionGearHunter = CompanionGearHunter or {}
local CompanionGearHunter = CompanionGearHunter -- local reference, faster than repeated _G lookups

-- LibAddonMenu-2.0 provides the global LibAddonMenu2; the manifest's
-- DependsOn guarantees it is loaded.
local LAM = LibAddonMenu2

local panel = nil

-- Opens this addon's own panel (Settings > Add-Ons). Closes the grid window
-- first - it's drawn above the game menu and would sit on top of the panel.
-- Goes through ToggleWindow so the usual close-time cleanup still runs.
function CompanionGearHunter.OpenSettings()
    if panel == nil then
        return
    end
    if not CompanionGearHunterWindow:IsHidden() then
        CompanionGearHunter.ToggleWindow()
    end
    LAM:OpenToPanel(panel)
end

-- Redraws everything that shows a marker so a changed setting is visible
-- right away: the grid (companion dropdown marker) and the item rows
-- currently on screen. Chat lines already printed keep their old look.
local function RefreshMarkers()
    if CompanionGearHunter.RefreshGrid then
        CompanionGearHunter.RefreshGrid()
    end
    if CompanionGearHunter.RefreshListBadges then
        CompanionGearHunter.RefreshListBadges()
    end
end

local function ColorDefault(kind)
    local color = CompanionGearHunter.Data.DEFAULT_MARKER_COLORS[kind]
    return { r = color[1], g = color[2], b = color[3] }
end

-- The Colors section is one row per color: "Wanted Color   [swatch]  <icon>",
-- the companion icon drawn in the color as it's picked. LAM can't put a label,
-- a swatch and a preview on one row by itself, so each picker is a full-width
-- row and the swatch is moved next to its label and the icon added beside it
-- from the LAM-PanelControlsCreated hook in BuildAddonMenu. Same layout as
-- CompanionRoster's Colors section.
local COLOR_SWATCH_X = 200 -- where the swatch starts, so the rows line up
local SAMPLE_ICON_SIZE = 32
local COLOR_ROWS = {
    {
        kind = "wanted", name = GetString(COMPANIONGEARHUNTER_SETTINGS_COLOR_WANTED),
        tooltip = GetString(COMPANIONGEARHUNTER_SETTINGS_COLOR_WANTED_TIP),
    },
    {
        kind = "upgrade", name = GetString(COMPANIONGEARHUNTER_SETTINGS_COLOR_UPGRADE),
        tooltip = GetString(COMPANIONGEARHUNTER_SETTINGS_COLOR_UPGRADE_TIP),
    },
}

local function ColorRowReference(row)
    return "CompanionGearHunterColor_" .. row.kind
end

-- Redraws a row's icon in the color currently saved for it.
local function UpdateColorSample(row)
    local control = _G[ColorRowReference(row)]
    if control and control.companionGearHunterSample then
        control.companionGearHunterSample:SetText(string.format("|c%s%s|r",
            CompanionGearHunter.Data.GetMarkerColorHex(row.kind),
            zo_iconFormatInheritColor(CompanionGearHunter.Data.MARKER_ICON, SAMPLE_ICON_SIZE, SAMPLE_ICON_SIZE)))
    end
end

local function ColorRowOption(row)
    return {
        type = "colorpicker",
        name = row.name,
        tooltip = row.tooltip,
        getFunc = function() return CompanionGearHunter.Data.GetMarkerColor(row.kind) end,
        setFunc = function(r, g, b)
            CompanionGearHunter.Data.SetMarkerColor(row.kind, r, g, b)
            RefreshMarkers()
            UpdateColorSample(row)
        end,
        default = ColorDefault(row.kind),
        reference = ColorRowReference(row),
        width = "full",
    }
end

-- SLASH_COMMANDS is the real base-game table every slash command (library-
-- registered or not) ends up in. Channel-switch shortcuts like /w or /g live
-- in their own lookup table, so both need checking to catch every real
-- collision. Same checks CompanionRoster uses.
local function IsSlashCommandTaken(command)
    if SLASH_COMMANDS[command] ~= nil then
        return true
    end
    local switchLookup = ZO_ChatSystem_GetChannelSwitchLookupTable()
    return switchLookup[command] ~= nil
end

-- The command is typed WITHOUT its slash: the panel draws a "/" in front of the
-- box (see the LAM-PanelControlsCreated hook in BuildAddonMenu), so it can never
-- end up as only a slash. A slash typed anyway is accepted and dropped.
local COMMAND_EDITBOX_REFERENCE = "CompanionGearHunterCommandEditbox"

-- The red line under the box, "" when there's nothing to say. Chat isn't
-- visible while the settings panel is open, so problems show here instead.
local commandMessage = ""

-- The saved command without its leading slash, as shown in the box.
local function GetCommandName()
    return (CompanionGearHunter.Data.GetSlashCommand():gsub("^/", ""))
end

-- Applied live via LibSlashCommander's Command:RemoveAlias/AddAlias, not just
-- saved for next login - see CompanionGearHunter.slashCommand in
-- CompanionGearHunter_UI.lua.
local function SetSlashCommand(input)
    local name = (zo_strlower(input or ""):gsub("%s+", ""))
    name = (name:gsub("^/+", ""))
    if name == "" then
        -- The working command stays in effect; the box is left blank so the
        -- message below it explains what's missing.
        commandMessage = GetString(COMPANIONGEARHUNTER_SETTINGS_COMMAND_REQUIRED)
        return
    end

    local newCommand = "/" .. name
    local oldCommand = CompanionGearHunter.Data.GetSlashCommand()
    if newCommand == oldCommand then
        commandMessage = ""
        return
    end

    -- Put the box back on the command that's still in effect, with the reason.
    local function Reject(message)
        commandMessage = message
        local control = _G[COMMAND_EDITBOX_REFERENCE]
        if control and control.editbox then
            control.editbox:SetText(GetCommandName())
        end
    end

    if IsSlashCommandTaken(newCommand) then
        Reject(zo_strformat(COMPANIONGEARHUNTER_SETTINGS_COMMAND_TAKEN, newCommand))
        return
    end

    -- Nothing to rename if the command never got registered at load.
    if CompanionGearHunter.slashCommand == nil then
        Reject(GetString(COMPANIONGEARHUNTER_SETTINGS_COMMAND_NOT_REGISTERED))
        return
    end

    CompanionGearHunter.slashCommand:RemoveAlias(oldCommand)
    CompanionGearHunter.slashCommand:AddAlias(newCommand)
    CompanionGearHunter.Data.SetSlashCommand(newCommand)
    commandMessage = ""
end

-- Builds the LibAddonMenu settings panel. Called once from the single
-- EVENT_ADD_ON_LOADED handler in CompanionGearHunter.lua, after the saved data
-- is ready (the options read it).
function CompanionGearHunter.BuildAddonMenu()
    local panelData = {
        type = "panel",
        name = "Feliks' Companion Gear Hunter",
        displayName = "Feliks' Companion Gear Hunter",
        author = "Feliks Blackwood",
        version = CompanionGearHunter.version,
        registerForRefresh = true,
        registerForDefaults = true,
    }
    panel = LAM:RegisterAddonPanel("CompanionGearHunter_Options", panelData)

    -- LAM builds the panel's controls the first time it's opened. The "/" in
    -- front of the Chat Command box is added then, as a plain label next to the
    -- box's own backdrop; a leftover message is cleared when the panel closes.
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", function(createdPanel)
        if createdPanel ~= panel then
            return
        end
        local box = _G[COMMAND_EDITBOX_REFERENCE]
        if box and box.bg then
            local slash = WINDOW_MANAGER:CreateControl(nil, box, CT_LABEL)
            slash:SetFont("ZoFontWinH3")
            slash:SetText("/")
            slash:SetAnchor(RIGHT, box.bg, LEFT, -4, 0)
        end

        -- Each color row: swatch moved up next to its label (the label is
        -- anchored to the swatch's holder, so it shrinks to fit) and the
        -- icon drawn to the right of the swatch.
        for _, row in ipairs(COLOR_ROWS) do
            local control = _G[ColorRowReference(row)]
            if control and control.container and control.color and control.color.border then
                control.container:ClearAnchors()
                control.container:SetAnchor(TOPLEFT, control, TOPLEFT, COLOR_SWATCH_X, 0)

                local sample = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
                sample:SetFont("ZoFontGame")
                sample:SetAnchor(LEFT, control.color.border, RIGHT, 12, 0)
                control.companionGearHunterSample = sample
                UpdateColorSample(row)
            end
        end
    end)
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(closedPanel)
        if closedPanel == panel then
            commandMessage = ""
        end
    end)

    local optionsTable = {
        {
            type = "header",
            name = GetString(COMPANIONGEARHUNTER_SETTINGS_GENERAL),
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(COMPANIONGEARHUNTER_SETTINGS_TAG_CHAT),
            tooltip = GetString(COMPANIONGEARHUNTER_SETTINGS_TAG_CHAT_TIP),
            getFunc = function() return CompanionGearHunter.Data.GetChatTaggingEnabled() end,
            setFunc = function(value) CompanionGearHunter.Data.SetChatTaggingEnabled(value) end,
            default = true,
            width = "full",
        },
        {
            type = "editbox",
            name = GetString(COMPANIONGEARHUNTER_SETTINGS_COMMAND),
            tooltip = GetString(COMPANIONGEARHUNTER_SETTINGS_COMMAND_TIP),
            getFunc = GetCommandName,
            setFunc = SetSlashCommand,
            default = "fcgh",
            maxChars = 32,
            reference = COMMAND_EDITBOX_REFERENCE,
            width = "half",
        },
        {
            -- Empty unless the command was rejected or left blank; follows
            -- commandMessage whenever the panel refreshes (registerForRefresh).
            type = "description",
            text = function()
                if commandMessage == "" then
                    return ""
                end
                return "|cFF6666" .. commandMessage .. "|r"
            end,
            width = "full",
        },
        {
            type = "editbox",
            name = GetString(COMPANIONGEARHUNTER_SETTINGS_PREFIX),
            tooltip = GetString(COMPANIONGEARHUNTER_SETTINGS_PREFIX_TIP),
            getFunc = function() return CompanionGearHunter.Data.GetTooltipPrefix() end,
            setFunc = function(value) CompanionGearHunter.Data.SetTooltipPrefix(value) end,
            default = CompanionGearHunter.Data.DEFAULT_TOOLTIP_PREFIX,
            isMultiline = false,
            maxChars = 20,
            width = "half",
        },
    }

    -- Gear Quality Upgrades: the master switch, then one checkbox per companion.
    -- The master wins - while it is off, upgrades are ignored for everyone and
    -- the companion boxes are greyed out (their choices are kept). Built here,
    -- at load, from the full companion list, same as CompanionRoster's per-
    -- companion Role dropdowns.
    table.insert(optionsTable, {
        type = "header",
        name = GetString(COMPANIONGEARHUNTER_SETTINGS_UPGRADES_HEADER),
        width = "full",
    })
    table.insert(optionsTable, {
        type = "checkbox",
        name = GetString(COMPANIONGEARHUNTER_SETTINGS_UPGRADES),
        tooltip = GetString(COMPANIONGEARHUNTER_SETTINGS_UPGRADES_TIP),
        getFunc = function() return CompanionGearHunter.Data.GetUpgradeSuggestionsEnabled() end,
        setFunc = function(value)
            CompanionGearHunter.Data.SetUpgradeSuggestionsEnabled(value)
            RefreshMarkers()
        end,
        default = true,
        width = "full",
    })
    table.insert(optionsTable, {
        type = "description",
        text = GetString(COMPANIONGEARHUNTER_SETTINGS_UPGRADES_DESC),
        width = "full",
    })
    for _, companion in ipairs(CompanionGearHunter.Data.GetAllCompanions()) do
        local companionId = companion.id
        table.insert(optionsTable, {
            type = "checkbox",
            name = companion.name,
            tooltip = zo_strformat(COMPANIONGEARHUNTER_SETTINGS_UPGRADES_COMPANION_TIP, companion.name),
            getFunc = function() return CompanionGearHunter.Data.GetUpgradeEnabledForCompanion(companionId) end,
            setFunc = function(value)
                CompanionGearHunter.Data.SetUpgradeEnabledForCompanion(companionId, value)
                RefreshMarkers()
            end,
            disabled = function() return not CompanionGearHunter.Data.GetUpgradeSuggestionsEnabled() end,
            default = true,
            width = "half",
        })
    end

    table.insert(optionsTable, {
        type = "header",
        name = GetString(COMPANIONGEARHUNTER_SETTINGS_COLORS_HEADER),
        width = "full",
    })
    table.insert(optionsTable, {
        type = "description",
        text = GetString(COMPANIONGEARHUNTER_SETTINGS_COLORS_DESC),
        width = "full",
    })
    table.insert(optionsTable, ColorRowOption(COLOR_ROWS[1]))
    table.insert(optionsTable, ColorRowOption(COLOR_ROWS[2]))

    LAM:RegisterOptionControls("CompanionGearHunter_Options", optionsTable)
end
