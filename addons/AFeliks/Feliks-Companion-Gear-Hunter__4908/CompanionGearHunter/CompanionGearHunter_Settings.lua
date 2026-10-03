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

-- Applied live via LibSlashCommander's Command:RemoveAlias/AddAlias, not just
-- saved for next login - see CompanionGearHunter.slashCommand in
-- CompanionGearHunter_UI.lua.
local function SetSlashCommand(input)
    local newCommand = zo_strlower(input or ""):gsub("%s+", "")
    if newCommand == "" then
        return
    end
    if newCommand:sub(1, 1) ~= "/" then
        newCommand = "/" .. newCommand
    end

    local oldCommand = CompanionGearHunter.Data.GetSlashCommand()
    if newCommand == oldCommand then
        return
    end

    if IsSlashCommandTaken(newCommand) then
        d(zo_strformat("Feliks' Companion Gear Hunter: <<1>> is already used by another command - pick something else.", newCommand))
        return
    end

    CompanionGearHunter.slashCommand:RemoveAlias(oldCommand)
    CompanionGearHunter.slashCommand:AddAlias(newCommand)
    CompanionGearHunter.Data.SetSlashCommand(newCommand)
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
            tooltip = "The chat command that toggles the window. Takes effect immediately, no reload needed.",
            getFunc = function() return CompanionGearHunter.Data.GetSlashCommand() end,
            setFunc = SetSlashCommand,
            default = "/fcgh",
            width = "half",
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
            name = "Marker Colors",
            width = "full",
        },
        {
            type = "description",
            text = "The color of the icons shown on items in your bags, banks, stores, trades and mail, in chat, and next to companions in the window. Dark colors are not suggested.",
            width = "full",
        },
        {
            type = "colorpicker",
            name = "Wanted Color",
            tooltip = "Items matching something on your wishlist.",
            getFunc = function() return CompanionGearHunter.Data.GetMarkerColor("wanted") end,
            setFunc = function(r, g, b)
                CompanionGearHunter.Data.SetMarkerColor("wanted", r, g, b)
                RefreshMarkers()
            end,
            default = ColorDefault("wanted"),
            width = "half",
        },
        {
            type = "colorpicker",
            name = "Upgrade Color",
            tooltip = "Items that are a quality upgrade over what a companion has equipped.",
            getFunc = function() return CompanionGearHunter.Data.GetMarkerColor("upgrade") end,
            setFunc = function(r, g, b)
                CompanionGearHunter.Data.SetMarkerColor("upgrade", r, g, b)
                RefreshMarkers()
            end,
            default = ColorDefault("upgrade"),
            width = "half",
        },
        {
            -- Re-evaluated whenever the panel refreshes (registerForRefresh),
            -- so the icons here follow the pickers as they change.
            type = "description",
            text = function()
                return string.format("Preview:   |c%s%s|r Wanted      |c%s%s|r Upgrade",
                    CompanionGearHunter.Data.GetMarkerColorHex("wanted"), zo_iconFormatInheritColor(CompanionGearHunter.Data.MARKER_ICON, 32, 32),
                    CompanionGearHunter.Data.GetMarkerColorHex("upgrade"), zo_iconFormatInheritColor(CompanionGearHunter.Data.MARKER_ICON, 32, 32))
            end,
            width = "full",
        },
    }
    LAM:RegisterOptionControls("CompanionGearHunter_Options", optionsTable)
end

EVENT_MANAGER:RegisterForEvent("CompanionGearHunter_Settings", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
