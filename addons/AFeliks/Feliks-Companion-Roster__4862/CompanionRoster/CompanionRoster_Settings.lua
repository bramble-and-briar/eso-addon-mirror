CompanionRoster = CompanionRoster or {}
local CompanionRoster = CompanionRoster -- local reference, faster than repeated _G lookups

-- LibAddonMenu-2.0 exposes a bare global (LibAddonMenu2) in addition to the
-- usual LibStub("LibAddonMenu-2.0") lookup - used directly here since this
-- setup doesn't have LibStub installed, and there's no other reason to
-- require it.
local LAM = LibAddonMenu2

local ROLE_CHOICES = { "None", "Tank", "Healer", "DPS" }
local ROLE_CHOICE_TO_VALUE = {
    ["Tank"] = LFG_ROLE_TANK,
    ["Healer"] = LFG_ROLE_HEAL,
    ["DPS"] = LFG_ROLE_DPS,
}
local ROLE_VALUE_TO_CHOICE = {
    [LFG_ROLE_TANK] = "Tank",
    [LFG_ROLE_HEAL] = "Healer",
    [LFG_ROLE_DPS] = "DPS",
}

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
    LAM:RegisterAddonPanel("CompanionRoster_Options", panelData)

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
            tooltip = "Automatically hides the roster window the moment you enter combat. Doesn't apply to movement - the base game closes menus like your inventory when you move, but that's handled natively by the client, not through anything an addon can hook into.",
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
                return ROLE_VALUE_TO_CHOICE[CompanionRoster.Data.GetCompanionRole(companionId)] or "None"
            end,
            setFunc = function(choice)
                CompanionRoster.Data.SetCompanionRole(companionId, ROLE_CHOICE_TO_VALUE[choice])
                CompanionRoster.RefreshGrid()
            end,
            default = "None",
            width = "half",
        })
    end

    LAM:RegisterOptionControls("CompanionRoster_Options", optionsTable)
end

EVENT_MANAGER:RegisterForEvent("CompanionRoster_Settings", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
