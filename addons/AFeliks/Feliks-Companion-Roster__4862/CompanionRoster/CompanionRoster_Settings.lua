CompanionRoster = CompanionRoster or {}
local CompanionRoster = CompanionRoster -- local reference, faster than repeated _G lookups

CompanionRoster.Settings = {}

-- LibAddonMenu-2.0 sets the bare global LibAddonMenu2, used directly.
local LAM = LibAddonMenu2

-- Dropdown labels ("None", "Tank", ..., "Tank + Damage", ...) and the role pair
-- each one stands for, built from the same CompanionRoster.Data.ROLE_CHOICES
-- the right-click menu uses so the two can't drift apart. Filled in by
-- Settings.Initialize, once the client's strings are ready.
local ROLE_CHOICES = {}
local ROLE_CHOICE_TO_ROLES = {}

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

-- The command is typed WITHOUT its slash: the panel draws a "/" in front of the
-- box (see the LAM-PanelControlsCreated hook in Settings.Initialize), so it can never
-- end up as only a slash. A slash typed anyway is accepted and dropped.
local COMMAND_EDITBOX_REFERENCE = "CompanionRosterCommandEditbox"

-- The red line under the box, "" when there's nothing to say. Chat isn't
-- visible while the settings panel is open, so problems show here instead.
local commandMessage = ""

-- The saved command without its leading slash, as shown in the box.
local function GetCommandName()
    return (CompanionRoster.Data.GetSlashCommand():gsub("^/", ""))
end

-- Applied live via LibSlashCommander's Command:RemoveAlias/AddAlias, not
-- just saved for next login - see CompanionRoster.slashCommand, set up in
-- CompanionRoster_UI.lua.
local function SetSlashCommand(input)
    local name = (zo_strlower(input or ""):gsub("%s+", ""))
    name = (name:gsub("^/+", ""))
    if name == "" then
        -- The working command stays in effect; the box is left blank so the
        -- message below it explains what's missing.
        commandMessage = GetString(COMPANIONROSTER_SETTINGS_COMMAND_REQUIRED)
        return
    end

    local newCommand = "/" .. name
    local oldCommand = CompanionRoster.Data.GetSlashCommand()
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
        Reject(zo_strformat(COMPANIONROSTER_SETTINGS_COMMAND_TAKEN, newCommand))
        return
    end

    -- Nothing to rename if the command never got registered at load.
    if CompanionRoster.slashCommand == nil then
        Reject(GetString(COMPANIONROSTER_SETTINGS_COMMAND_NOT_REGISTERED))
        return
    end

    CompanionRoster.slashCommand:RemoveAlias(oldCommand)
    CompanionRoster.slashCommand:AddAlias(newCommand)
    CompanionRoster.Data.SetSlashCommand(newCommand)
    commandMessage = ""
end

-- LAM wants a color default as { r =, g =, b = }.
local function ColorDefault(kind)
    local color = CompanionRoster.Data.DEFAULT_COLORS[kind]
    return { r = color[1], g = color[2], b = color[3] }
end

-- The Colors section is one row per color: "Done Color   [swatch]  5500/5500",
-- the sample text drawn in the color as it's picked. LAM can't put a label, a
-- swatch and a preview on one row by itself, so each picker is a full-width
-- row and the swatch is moved next to its label and the preview added beside
-- it from the LAM-PanelControlsCreated hook in Settings.Initialize.
-- One real Guild skill line ("Fighters 5") from the first companion with any
-- recorded, in the game's own name. Before any companion
-- has been summoned there is nothing recorded, so a made-up sample is used.
local function GetGuildSampleItems()
    for _, companion in ipairs(CompanionRoster.Data.GetAllCompanions()) do
        for _, group in ipairs(CompanionRoster.Data.GetSkillLinesForCompanion(companion.id) or {}) do
            if CompanionRoster.Data.IsGuildSkillGroup(group) and #group.lines > 0 then
                -- " Guild" is dropped from the name, as the Level tooltip does.
                local line = group.lines[1]
                return (line.name:gsub(" Guild$", "")) .. " " .. line.rank
            end
        end
    end
    return GetString(COMPANIONROSTER_SETTINGS_COLOR_LABEL_SAMPLE)
end

local COLOR_SWATCH_X = 200 -- where the swatch starts, so the three rows line up
local COLOR_ROWS = {
    {
        kind = "done", name = COMPANIONROSTER_SETTINGS_COLOR_DONE,
        tooltip = COMPANIONROSTER_SETTINGS_COLOR_DONE_TIP,
        sample = function(hex) return "|c" .. hex .. "5500/5500|r" end,
        redrawsRoster = true,
    },
    {
        kind = "inProgress", name = COMPANIONROSTER_SETTINGS_COLOR_IN_PROGRESS,
        tooltip = COMPANIONROSTER_SETTINGS_COLOR_IN_PROGRESS_TIP,
        sample = function(hex) return "|c" .. hex .. "3075/5500|r" end,
        redrawsRoster = true,
    },
    {
        kind = "tooltipLabel", name = COMPANIONROSTER_SETTINGS_COLOR_LABEL,
        tooltip = COMPANIONROSTER_SETTINGS_COLOR_LABEL_TIP,
        -- The Guild line as the Level tooltip draws it, label in the picked color.
        sample = function(hex)
            -- The rest of the line is in the game's default tooltip text color,
            -- like the Level tooltip, where only the label is colored.
            return "|c" .. hex .. zo_strformat(COMPANIONROSTER_LEVEL_TIP_LABEL, GetString("SI_SKILLTYPE", SKILL_TYPE_GUILD)) .. "|r |c" .. ZO_TOOLTIP_DEFAULT_COLOR:ToHex() .. GetGuildSampleItems() .. "|r"
        end,
    },
}

local function ColorRowReference(row)
    return "CompanionRosterColor_" .. row.kind
end

-- Redraws a row's sample text in the color currently saved for it.
local function UpdateColorSample(row)
    local control = _G[ColorRowReference(row)]
    if control and control.companionRosterSample then
        control.companionRosterSample:SetText(row.sample(CompanionRoster.Data.GetColorHex(row.kind)))
    end
end

local function ColorRowOption(row)
    return {
        type = "colorpicker",
        name = GetString(row.name),
        tooltip = GetString(row.tooltip),
        getFunc = function() return CompanionRoster.Data.GetColor(row.kind) end,
        setFunc = function(r, g, b)
            CompanionRoster.Data.SetColor(row.kind, r, g, b)
            if row.redrawsRoster then
                CompanionRoster.RefreshGrid()
            end
            UpdateColorSample(row)
        end,
        default = ColorDefault(row.kind),
        reference = ColorRowReference(row),
        width = "full",
    }
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

local function HudCheckbox(key, nameId, tooltipId)
    return {
        type = "checkbox",
        name = GetString(nameId),
        tooltip = GetString(tooltipId),
        getFunc = function() return CompanionRoster.Data.GetHudOption(key) end,
        setFunc = function(value) SetHudOption(key, value) end,
        disabled = HudIsOff,
        default = CompanionRoster.Data.HUD_DEFAULTS[key],
        width = "full",
    }
end

-- Called once from the addon's single EVENT_ADD_ON_LOADED handler
-- (CompanionRoster.lua), after the saved data is ready.
function CompanionRoster.Settings.Initialize()
    local noneLabel = GetString(COMPANIONROSTER_ROLE_NONE)
    ROLE_CHOICES = { noneLabel }
    for _, choice in ipairs(CompanionRoster.Data.ROLE_CHOICES) do
        local label = CompanionRoster.Data.GetRoleLabel(choice.primary, choice.secondary)
        table.insert(ROLE_CHOICES, label)
        ROLE_CHOICE_TO_ROLES[label] = choice
    end

    local panelData = {
        type = "panel",
        name = CompanionRoster.title,
        displayName = CompanionRoster.title,
        author = "Feliks Blackwood",
        version = CompanionRoster.version,
        registerForRefresh = true,
        registerForDefaults = true,
    }
    -- Kept so the Companion Info frame can tell when this panel is the page
    -- being viewed (LAM-PanelOpened / LAM-PanelClosed hand back this object).
    CompanionRoster.settingsPanel = LAM:RegisterAddonPanel("CompanionRoster_Options", panelData)

    -- LAM builds the panel's controls the first time it's opened. The "/" in
    -- front of the Chat Command box is added then, as a plain label next to the
    -- box's own backdrop; a leftover message is cleared when the panel closes.
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", function(panel)
        if panel ~= CompanionRoster.settingsPanel then
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
        -- anchored to the swatch's holder, so it shrinks to fit) and a sample of
        -- the color drawn to the right of the swatch.
        for _, row in ipairs(COLOR_ROWS) do
            local control = _G[ColorRowReference(row)]
            if control and control.container and control.color and control.color.border then
                control.container:ClearAnchors()
                control.container:SetAnchor(TOPLEFT, control, TOPLEFT, COLOR_SWATCH_X, 0)

                local sample = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
                sample:SetFont("ZoFontGame")
                sample:SetAnchor(LEFT, control.color.border, RIGHT, 12, 0)
                control.companionRosterSample = sample
                UpdateColorSample(row)
            end
        end
    end)
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(panel)
        if panel == CompanionRoster.settingsPanel then
            commandMessage = ""
        end
    end)

    local optionsTable = {
        {
            type = "header",
            name = GetString(COMPANIONROSTER_SETTINGS_GENERAL),
            width = "full",
        },
        {
            type = "editbox",
            name = GetString(COMPANIONROSTER_SETTINGS_COMMAND),
            tooltip = GetString(COMPANIONROSTER_SETTINGS_COMMAND_TIP),
            getFunc = GetCommandName,
            setFunc = SetSlashCommand,
            default = "fcr",
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
            type = "checkbox",
            name = GetString(COMPANIONROSTER_SETTINGS_CLOSE_COMBAT),
            tooltip = GetString(COMPANIONROSTER_SETTINGS_CLOSE_COMBAT_TIP),
            getFunc = function() return CompanionRoster.Data.GetCloseOnCombat() end,
            setFunc = function(value)
                CompanionRoster.Data.SetCloseOnCombat(value)
                CompanionRoster.UpdateCombatEvent()
            end,
            default = false,
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(COMPANIONROSTER_SETTINGS_SHOW_ROLES),
            tooltip = GetString(COMPANIONROSTER_SETTINGS_SHOW_ROLES_TIP),
            getFunc = function() return CompanionRoster.Data.GetShowRoleOnCollections() end,
            setFunc = function(value) CompanionRoster.Data.SetShowRoleOnCollections(value) end,
            default = true,
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(COMPANIONROSTER_SETTINGS_SHOW_RAPPORT),
            tooltip = GetString(COMPANIONROSTER_SETTINGS_SHOW_RAPPORT_TIP),
            getFunc = function() return CompanionRoster.Data.GetShowRapportOnCollections() end,
            setFunc = function(value) CompanionRoster.Data.SetShowRapportOnCollections(value) end,
            default = true,
            width = "full",
        },
        {
            type = "header",
            name = GetString(COMPANIONROSTER_SETTINGS_HUD_HEADER),
            width = "full",
        },
        {
            type = "description",
            text = GetString(COMPANIONROSTER_SETTINGS_HUD_DESCRIPTION),
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(COMPANIONROSTER_SETTINGS_HUD_ENABLED),
            tooltip = GetString(COMPANIONROSTER_SETTINGS_HUD_ENABLED_TIP),
            getFunc = function() return CompanionRoster.Data.GetHudOption("enabled") end,
            setFunc = function(value) SetHudOption("enabled", value) end,
            default = CompanionRoster.Data.HUD_DEFAULTS.enabled,
            width = "full",
        },
        HudCheckbox("bold", COMPANIONROSTER_SETTINGS_HUD_BOLD, COMPANIONROSTER_SETTINGS_HUD_BOLD_TIP),
        {
            type = "colorpicker",
            name = GetString(COMPANIONROSTER_SETTINGS_HUD_COLOR),
            tooltip = GetString(COMPANIONROSTER_SETTINGS_HUD_COLOR_TIP),
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
            text = GetString(COMPANIONROSTER_SETTINGS_HUD_PARTS),
            width = "full",
        },
        HudCheckbox("level", COMPANIONROSTER_SETTINGS_HUD_LEVEL, COMPANIONROSTER_SETTINGS_HUD_LEVEL_TIP),
        HudCheckbox("xpRaw", COMPANIONROSTER_SETTINGS_HUD_XP_RAW, COMPANIONROSTER_SETTINGS_HUD_XP_RAW_TIP),
        HudCheckbox("xpPercent", COMPANIONROSTER_SETTINGS_HUD_XP_PERCENT, COMPANIONROSTER_SETTINGS_HUD_XP_PERCENT_TIP),
        HudCheckbox("xpGain", COMPANIONROSTER_SETTINGS_HUD_XP_GAIN, COMPANIONROSTER_SETTINGS_HUD_XP_GAIN_TIP),
        HudCheckbox("rapportLevel", COMPANIONROSTER_SETTINGS_HUD_RAPPORT_LEVEL, COMPANIONROSTER_SETTINGS_HUD_RAPPORT_LEVEL_TIP),
        HudCheckbox("rapportChange", COMPANIONROSTER_SETTINGS_HUD_RAPPORT_CHANGE, COMPANIONROSTER_SETTINGS_HUD_RAPPORT_CHANGE_TIP),
        HudCheckbox("rapportNumber", COMPANIONROSTER_SETTINGS_HUD_RAPPORT_NUMBER, COMPANIONROSTER_SETTINGS_HUD_RAPPORT_NUMBER_TIP),
        {
            type = "header",
            name = GetString(COMPANIONROSTER_SETTINGS_COLORS_HEADER),
            width = "full",
        },
        {
            type = "description",
            text = GetString(COMPANIONROSTER_SETTINGS_COLORS_DESCRIPTION),
            width = "full",
        },
        ColorRowOption(COLOR_ROWS[1]),
        ColorRowOption(COLOR_ROWS[2]),
        ColorRowOption(COLOR_ROWS[3]),
        {
            type = "header",
            name = GetString(COMPANIONROSTER_SETTINGS_ROLES_HEADER),
            width = "full",
        },
        {
            type = "description",
            text = GetString(COMPANIONROSTER_SETTINGS_ROLES_DESCRIPTION),
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
                return CompanionRoster.Data.GetRoleLabel(primary, secondary) or noneLabel
            end,
            setFunc = function(choice)
                local roles = ROLE_CHOICE_TO_ROLES[choice]
                CompanionRoster.Data.SetCompanionRoles(companionId, roles and roles.primary, roles and roles.secondary)
                CompanionRoster.RefreshGrid()
            end,
            default = noneLabel,
            width = "half",
        })
    end

    LAM:RegisterOptionControls("CompanionRoster_Options", optionsTable)
end
