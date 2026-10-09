CompanionGearHunter = CompanionGearHunter or {}
local CompanionGearHunter = CompanionGearHunter -- local reference, faster than repeated _G lookups

-- LibAddonMenu-2.0 exposes a bare global (LibAddonMenu2) in addition to the
-- usual LibStub lookup - used directly, same as CompanionRoster does, since
-- LibStub isn't guaranteed to be installed.
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
-- from the LAM-PanelControlsCreated hook in OnAddOnLoaded. Same layout as
-- CompanionRoster's Colors section.
local COLOR_SWATCH_X = 200 -- where the swatch starts, so the rows line up
local SAMPLE_ICON_SIZE = 32
local COLOR_ROWS = {
    {
        kind = "wanted", name = "Wanted Color",
        tooltip = "Items matching something on your wishlist.",
    },
    {
        kind = "upgrade", name = "Upgrade Color",
        tooltip = "Items that are a quality upgrade over what a companion has equipped.",
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
-- box (see the LAM-PanelControlsCreated hook in OnAddOnLoaded), so it can never
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
        commandMessage = "A chat command is required."
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
        Reject(newCommand .. " is already used by another command - pick something else.")
        return
    end

    -- Nothing to rename if the command never got registered at load.
    if CompanionGearHunter.slashCommand == nil then
        Reject("The chat command isn't registered, so it can't be changed right now.")
        return
    end

    CompanionGearHunter.slashCommand:RemoveAlias(oldCommand)
    CompanionGearHunter.slashCommand:AddAlias(newCommand)
    CompanionGearHunter.Data.SetSlashCommand(newCommand)
    commandMessage = ""
end

local function OnAddOnLoaded(eventCode, addOnName)
    if addOnName ~= CompanionGearHunter.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent("CompanionGearHunter_Settings", EVENT_ADD_ON_LOADED)

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
            name = "General",
            width = "full",
        },
        {
            type = "checkbox",
            name = "Find Gear Quality Upgrades",
            tooltip = "When checked, browsing a companion item that's a higher quality than what a companion currently has equipped in a slot you aren't actively hunting for (\"Find\" unchecked) marks that item and adds a note to its tooltip. Weight/type and trait must match what's equipped - only the quality is an upgrade.",
            getFunc = function() return CompanionGearHunter.Data.GetUpgradeSuggestionsEnabled() end,
            setFunc = function(value)
                CompanionGearHunter.Data.SetUpgradeSuggestionsEnabled(value)
                RefreshMarkers()
            end,
            default = true,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Tag Gear in Chat",
            tooltip = "When checked, companion gear item links in chat (any channel, including your own messages) get a companion icon in front of them, in the wanted or upgrade color below. Hover the link for details. Edits the line in place - no extra chat lines.",
            getFunc = function() return CompanionGearHunter.Data.GetChatTaggingEnabled() end,
            setFunc = function(value) CompanionGearHunter.Data.SetChatTaggingEnabled(value) end,
            default = true,
            width = "full",
        },
        {
            type = "editbox",
            name = "Chat Command",
            tooltip = "The chat command that toggles the window, typed without the slash. Takes effect immediately, no reload needed.",
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
            name = "Tooltip Prefix",
            tooltip = "Text shown at the start of the lines this addon adds to item tooltips. Leave it empty for no prefix.",
            getFunc = function() return CompanionGearHunter.Data.GetTooltipPrefix() end,
            setFunc = function(value) CompanionGearHunter.Data.SetTooltipPrefix(value) end,
            default = CompanionGearHunter.Data.DEFAULT_TOOLTIP_PREFIX,
            isMultiline = false,
            maxChars = 20,
            width = "half",
        },
        {
            type = "header",
            name = "Colors",
            width = "full",
        },
        {
            type = "description",
            text = "The color of the icons shown on items in your bags, banks, guild stores, trades and mail, in chat, and next to companions in the window. Dark colors are not suggested.",
            width = "full",
        },
        ColorRowOption(COLOR_ROWS[1]),
        ColorRowOption(COLOR_ROWS[2]),
    }
    LAM:RegisterOptionControls("CompanionGearHunter_Options", optionsTable)
end

EVENT_MANAGER:RegisterForEvent("CompanionGearHunter_Settings", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
