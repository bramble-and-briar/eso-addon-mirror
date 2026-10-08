CompanionRoster = CompanionRoster or {}
local CompanionRoster = CompanionRoster -- local reference, faster than repeated _G lookups

-- LibAddonMenu-2.0 exposes a bare global (LibAddonMenu2) in addition to the
-- usual LibStub("LibAddonMenu-2.0") lookup - used directly here since this
-- setup doesn't have LibStub installed, and there's no other reason to
-- require it.
local LAM = LibAddonMenu2

-- Dropdown labels ("None", "Tank", ..., "Tank + DPS", ...) and the role pair
-- each one stands for, built from the same CompanionRoster.Data.ROLE_CHOICES
-- the right-click menu uses so the two can't drift apart.
local ROLE_CHOICES = { "None" }
local ROLE_CHOICE_TO_ROLES = {}
for _, choice in ipairs(CompanionRoster.Data.ROLE_CHOICES) do
    local label = CompanionRoster.Data.GetRoleLabel(choice.primary, choice.secondary)
    table.insert(ROLE_CHOICES, label)
    ROLE_CHOICE_TO_ROLES[label] = choice
end

-- SLASH_COMMANDS is the real base-game table every slash command (library-
-- registered or not) ends up in - LibSlashCommander's own alias lookup reads
-- from it too (see its __index in LibSlashCommander.lua). Channel-switch
-- shortcuts like /w or /g aren't in there though, they live in their own
-- lookup table, so both need checking to catch every real collision.
local function IsSlashCommandTaken(command)
    if SLASH_COMMANDS[command] ~= nil then
        return true
    end
    local switchLookup = ZO_ChatSystem_GetChannelSwitchLookupTable()
    return switchLookup[command] ~= nil
end

-- Applied live via LibSlashCommander's Command:RemoveAlias/AddAlias, not
-- just saved for next login - see CompanionRoster.slashCommand, set up in
-- CompanionRoster_UI.lua.
local function SetSlashCommand(input)
    local newCommand = zo_strlower(input or ""):gsub("%s+", "")
    if newCommand == "" then
        return
    end
    if newCommand:sub(1, 1) ~= "/" then
        newCommand = "/" .. newCommand
    end

    local oldCommand = CompanionRoster.Data.GetSlashCommand()
    if newCommand == oldCommand then
        return
    end

    if IsSlashCommandTaken(newCommand) then
        d(zo_strformat("Feliks' Companion Roster: <<1>> is already used by another command - pick something else.", newCommand))
        return
    end

    CompanionRoster.slashCommand:RemoveAlias(oldCommand)
    CompanionRoster.slashCommand:AddAlias(newCommand)
    CompanionRoster.Data.SetSlashCommand(newCommand)
end

-- LAM wants a color default as { r =, g =, b = }.
local function ColorDefault(kind)
    local color = CompanionRoster.Data.DEFAULT_COLORS[kind]
    return { r = color[1], g = color[2], b = color[3] }
end

-- Companion Info frame helpers. Every setting writes through to saved vars and
-- redraws the frame immediately; all but the master checkbox grey out while
-- the master is off.
local function SetHudOption(key, value)
    CompanionRoster.Data.SetHudOption(key, value)
    CompanionRoster.HUD.Refresh()
end

local function HudIsOff()
    return not CompanionRoster.Data.GetHudOption("enabled")
end

local function HudColorDefault()
    local color = CompanionRoster.Data.DEFAULT_HUD_COLOR
    return { r = color[1], g = color[2], b = color[3] }
end

local function HudCheckbox(key, name, tooltip)
    return {
        type = "checkbox",
        name = name,
        tooltip = tooltip,
        getFunc = function() return CompanionRoster.Data.GetHudOption(key) end,
        setFunc = function(value) SetHudOption(key, value) end,
        disabled = HudIsOff,
        default = CompanionRoster.Data.HUD_DEFAULTS[key],
        width = "full",
    }
end

local function OnAddOnLoaded(eventCode, addOnName)
    if addOnName ~= CompanionRoster.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent("CompanionRoster_Settings", EVENT_ADD_ON_LOADED)

    local panelData = {
        type = "panel",
        name = "Feliks' Companion Roster",
        displayName = "Feliks' Companion Roster",
        author = "Feliks Blackwood",
        version = CompanionRoster.version,
        registerForRefresh = true,
        registerForDefaults = true,
    }
    -- Kept so the Companion Info frame can tell when this panel is the page
    -- being viewed (LAM-PanelOpened / LAM-PanelClosed hand back this object).
    CompanionRoster.settingsPanel = LAM:RegisterAddonPanel("CompanionRoster_Options", panelData)

    local optionsTable = {
        {
            type = "header",
            name = "General",
            width = "full",
        },
        {
            type = "editbox",
            name = "Chat Command",
            tooltip = "The chat command that toggles the roster window. Takes effect immediately, no reload needed.",
            getFunc = function() return CompanionRoster.Data.GetSlashCommand() end,
            setFunc = SetSlashCommand,
            default = "/fcr",
            width = "half",
        },
        {
            type = "checkbox",
            name = "Close Window When Entering Combat",
            tooltip = "Close when entering combat.",
            getFunc = function() return CompanionRoster.Data.GetCloseOnCombat() end,
            setFunc = function(value) CompanionRoster.Data.SetCloseOnCombat(value) end,
            default = false,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Show Roles in Collections",
            tooltip = "Shows each companion's Role icon on their tile in the Collections screen. Keyboard and mouse UI only.",
            getFunc = function() return CompanionRoster.Data.GetShowRoleOnCollections() end,
            setFunc = function(value) CompanionRoster.Data.SetShowRoleOnCollections(value) end,
            default = true,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Show Rapport in Collections",
            tooltip = "Shows each companion's current rapport number under their portrait in the Collections screen. Keyboard and mouse UI only.",
            getFunc = function() return CompanionRoster.Data.GetShowRapportOnCollections() end,
            setFunc = function(value) CompanionRoster.Data.SetShowRapportOnCollections(value) end,
            default = true,
            width = "full",
        },
        {
            type = "header",
            name = "Companion Info Frame",
            width = "full",
        },
        {
            type = "description",
            text = "A small always-visible line showing your active companion. Move it with Game Menu > Edit HUD.",
            width = "full",
        },
        {
            type = "checkbox",
            name = "Show Companion Info Frame",
            tooltip = "Turns the whole frame on or off. When off, it also disappears from Edit HUD.",
            getFunc = function() return CompanionRoster.Data.GetHudOption("enabled") end,
            setFunc = function(value) SetHudOption("enabled", value) end,
            default = CompanionRoster.Data.HUD_DEFAULTS.enabled,
            width = "full",
        },
        HudCheckbox("bold", "Bold Text", "Use the bold game font instead of the regular one."),
        {
            type = "colorpicker",
            name = "Text Color",
            tooltip = "The color of the whole line.",
            getFunc = function() return CompanionRoster.Data.GetHudColor() end,
            setFunc = function(r, g, b)
                CompanionRoster.Data.SetHudColor(r, g, b)
                CompanionRoster.HUD.Refresh()
            end,
            disabled = HudIsOff,
            default = HudColorDefault(),
            width = "full",
        },
        {
            type = "description",
            text = "Parts to show (the companion's name is always shown):",
            width = "full",
        },
        HudCheckbox("level", "Level", "For example Lv:16."),
        HudCheckbox("xpRaw", "XP (current/needed)", "For example (94938/116000). Hidden at max level."),
        HudCheckbox("xpPercent", "XP Percent", "For example 81%. Hidden at max level."),
        HudCheckbox("xpGain", "XP Gain", "The most recent XP gain, for example [+120]. Hidden at max level."),
        HudCheckbox("rapportLevel", "Rapport Level", "For example Rap:6."),
        HudCheckbox("rapportChange", "Rapport Change", "The most recent rapport gain or loss, for example [+25]."),
        HudCheckbox("rapportNumber", "Rapport Number", "Your current rapport points, for example (3247)."),
        {
            type = "header",
            name = "Colors",
            width = "full",
        },
        {
            type = "description",
            text = "The colors used for rapport and Guild ranks in the roster window, the Collections screen and chat search results.",
            width = "full",
        },
        {
            type = "colorpicker",
            name = "Done Color",
            tooltip = "Maxed rapport and maxed Guild ranks.",
            getFunc = function() return CompanionRoster.Data.GetColor("done") end,
            setFunc = function(r, g, b)
                CompanionRoster.Data.SetColor("done", r, g, b)
                CompanionRoster.RefreshGrid()
            end,
            default = ColorDefault("done"),
            width = "half",
        },
        {
            type = "colorpicker",
            name = "In Progress Color",
            tooltip = "Rapport and Guild ranks that can still go up.",
            getFunc = function() return CompanionRoster.Data.GetColor("inProgress") end,
            setFunc = function(r, g, b)
                CompanionRoster.Data.SetColor("inProgress", r, g, b)
                CompanionRoster.RefreshGrid()
            end,
            default = ColorDefault("inProgress"),
            width = "half",
        },
        {
            -- Re-evaluated whenever the panel refreshes (registerForRefresh),
            -- so this follows the pickers as they change.
            type = "description",
            text = function()
                return string.format("Preview:   |c%s5500/5500|r Done      |c%s3075/5500|r In Progress",
                    CompanionRoster.Data.GetColorHex("done"), CompanionRoster.Data.GetColorHex("inProgress"))
            end,
            width = "full",
        },
        {
            type = "header",
            name = "Companion Roles",
            width = "full",
        },
        {
            type = "description",
            text = "Purely a label you set yourself - there's no way to detect a companion's build from their gear or slotted skills. Account-wide, same as the companion itself. Right-clicking a companion's Role icon in the roster window does the same thing.",
            width = "full",
        },
    }

    for _, companion in ipairs(CompanionRoster.Data.GetAllCompanions()) do
        local companionId = companion.id
        table.insert(optionsTable, {
            type = "dropdown",
            name = companion.name,
            choices = ROLE_CHOICES,
            getFunc = function()
                local primary, secondary = CompanionRoster.Data.GetCompanionRoles(companionId)
                return CompanionRoster.Data.GetRoleLabel(primary, secondary) or "None"
            end,
            setFunc = function(choice)
                local roles = ROLE_CHOICE_TO_ROLES[choice]
                CompanionRoster.Data.SetCompanionRoles(companionId, roles and roles.primary, roles and roles.secondary)
                CompanionRoster.RefreshGrid()
            end,
            default = "None",
            width = "half",
        })
    end

    LAM:RegisterOptionControls("CompanionRoster_Options", optionsTable)
end

EVENT_MANAGER:RegisterForEvent("CompanionRoster_Settings", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
