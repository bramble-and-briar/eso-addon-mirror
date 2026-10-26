local SAVED_VARS_VERSION = 1

local function ValidateSavedVars()
    if type(BF.savedVars.builds) ~= "table" then BF.savedVars.builds = {} end
    if type(BF.savedVars.marketplaceBuilds) ~= "table" then BF.savedVars.marketplaceBuilds = {} end
    if type(BF.savedVars.settings) ~= "table" then BF.savedVars.settings = ZO_DeepTableCopy(BF.defaults.settings) end
    if type(BF.savedVars.settings.exportEndpoint) ~= "string" then BF.savedVars.settings.exportEndpoint = BF.defaults.settings.exportEndpoint end
    if type(BF.savedVars.settings.applyDelayMs) ~= "number" then BF.savedVars.settings.applyDelayMs = BF.defaults.settings.applyDelayMs end
    BF.savedVars.savedVarsVersion = SAVED_VARS_VERSION
end

local function CreateSettingsMenu()
    if not LibAddonMenu2 then return end
    local panelData = {
        type = "panel",
        name = "BuildForge",
        displayName = "|c88CCFFBuildForge|r",
        author = "Tek",
        version = BF.version,
        slashCommand = "/bfsettings",
        registerForRefresh = true,
        registerForDefaults = true,
    }
    local options = {
        { type = "description", text = "Build marketplace foundation: record, export, compare, and apply owned gear builds." },
        {
            type = "editbox",
            name = "Export Endpoint",
            tooltip = "Open ingestion endpoint. Include /ingest at the end.",
            getFunc = function() return BF.savedVars.settings.exportEndpoint or "" end,
            setFunc = function(value) BF.savedVars.settings.exportEndpoint = value end,
            default = BF.defaults.settings.exportEndpoint,
        },
        {
            type = "slider",
            name = "Gear Apply Delay",
            tooltip = "Delay between equip requests.",
            min = 100,
            max = 1500,
            step = 50,
            getFunc = function() return BF.savedVars.settings.applyDelayMs or BF.defaults.settings.applyDelayMs end,
            setFunc = function(value) BF.savedVars.settings.applyDelayMs = value end,
            default = BF.defaults.settings.applyDelayMs,
        },
    }
    LibAddonMenu2:RegisterAddonPanel("BuildForge_Settings", panelData)
    LibAddonMenu2:RegisterOptionControls("BuildForge_Settings", options)
end

local function RegisterSlashCommands()
    SLASH_COMMANDS["/bf"] = function(args)
        local cmd = args and args:lower():match("^%s*(%S*)") or ""
        local rest = args and args:match("^%s*%S+%s*(.-)%s*$") or ""
        if cmd == "help" then
            BF.Chat("/bf - open UI")
            BF.Chat("/bf record - record current character build")
            BF.Chat("/bf compare - compare selected build to owned gear")
            BF.Chat("/bf apply - apply all possible build pieces")
            BF.Chat("/bf gear - apply matching owned gear only")
            BF.Chat("/bf export - export selected build")
            BF.Chat("/bf endpoint <url> - set open export endpoint")
        elseif cmd == "record" then
            BF.RecordCurrentBuild()
        elseif cmd == "compare" or cmd == "preview" then
            BF.CompareSelectedBuild()
        elseif cmd == "apply" then
            BF.ApplySelectedBuildAll()
        elseif cmd == "gear" then
            BF.ApplySelectedBuildGear()
        elseif cmd == "export" then
            BF.ExportSelectedBuild()
        elseif cmd == "endpoint" then
            BF.BuildExport.SetEndpoint(rest)
        else
            BF.ToggleUI()
        end
    end
    SLASH_COMMANDS["/buildforge"] = SLASH_COMMANDS["/bf"]
    SLASH_COMMANDS["/bfrecord"] = function() BF.RecordCurrentBuild() end
    SLASH_COMMANDS["/bfcompare"] = function() BF.CompareSelectedBuild() end
    SLASH_COMMANDS["/bfapply"] = function() BF.ApplySelectedBuildAll() end
    SLASH_COMMANDS["/bfgear"] = function() BF.ApplySelectedBuildGear() end
    SLASH_COMMANDS["/bfexport"] = function() BF.ExportSelectedBuild() end
end

local function OnAddonLoaded(eventCode, addonName)
    if addonName ~= BF.name then return end
    EVENT_MANAGER:UnregisterForEvent(BF.name, EVENT_ADD_ON_LOADED)
    local ok = pcall(function()
        BF.savedVars = ZO_SavedVars:NewAccountWide("BuildForge_Data", 1, nil, BF.defaults)
    end)
    if not ok or not BF.savedVars then BF.savedVars = ZO_DeepTableCopy(BF.defaults) end
    ValidateSavedVars()
    RegisterSlashCommands()
    CreateSettingsMenu()
    if BF.AddCustomMenuEntry then BF.AddCustomMenuEntry() end
    EVENT_MANAGER:RegisterForEvent(BF.name .. "_PlayerActivated", EVENT_PLAYER_ACTIVATED, function() BF.initialized = true end)
    BF.Chat("Loaded. Use /bf to open.")
end

EVENT_MANAGER:RegisterForEvent(BF.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
