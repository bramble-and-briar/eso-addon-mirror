local CT = CorpseTracker
local LAM = LibAddonMenu2

-- Query actual slotted morphs on both bars; base skill is a fallback only.
function CT.ReadSkillRange(family)
    if not GetAbilityRange then return nil end
    local best, bestId
    local function Read(id)
        if not id or id <= 0 then return end
        local _, maximum = GetAbilityRange(id, nil, "player")
        if type(maximum) ~= "number" or maximum ~= maximum or maximum <= 0 or maximum == math.huge then return end
        local range = maximum / 100
        if family == "yard" then
            local radius = GetAbilityRadius and GetAbilityRadius(id, nil, "player")
            if type(radius) ~= "number" or radius ~= radius or radius <= 0 or radius == math.huge then return end
            range = range + radius / 100
        end
        if not best or range > best then best, bestId = range, id end
    end
    if GetSlotBoundId then
        for _, category in ipairs({ HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }) do
            for slot = 3, 7 do
                local id = GetSlotBoundId(slot, category)
                if id and CT.AbilityFamily(id) == family then Read(id) end
            end
        end
    end
    if not best then Read(family == "yard" and 117850 or 118763) end
    return best, bestId
end

function CT.RegisterSettings()
    if not LAM then return false end
    local function Set(key)
        return function(value)
            if key == "debugMode" then CT.SetDebugMode(value); return end
            if key == "displayMode" then CT.SetDisplayMode(value); return end
            if key == "countMode" then CT.SetCountMode(value); return end
            if key == "capture" then CT.SetCapture(value); CT.ApplySettings(); return end
            CT.saved[key] = value
            CT.ApplySettings()
        end
    end
    local function Get(key) return function() return CT.saved[key] end end
    local function Check(name, key, tooltip, default)
        return { type = "checkbox", name = name, tooltip = tooltip,
            getFunc = Get(key), setFunc = Set(key), default = default }
    end
    CT.settingsPanel = LAM:RegisterAddonPanel("CorpseTrackerSettings", {
        type = "panel", name = "Corpse Tracker", displayName = "Corpse Tracker",
        author = "@mettaleggroll and Codex", version = CT.version,
        registerForRefresh = true, registerForDefaults = true,
    })
    local function Label(key) return function() return CT.T(key) end end
    local function Choice(key) return CT.T(key) end
    local function Checkbox(key, setting, tip, default)
        local option = Check(Label(key), setting, Label(tip), default)
        option.reference = "CorpseTrackerOption_" .. setting
        if setting == "includeUnknown" then
            option.disabled = function() return CT.saved.countMode == "light" end
        end
        return option
    end
    local languageChoices, languageValues = { CT.T("AUTOMATIC") }, { "auto" }
    for i, code in ipairs(CT.languageCodes) do
        languageChoices[#languageChoices + 1] = CT.languageNames[i]
        languageValues[#languageValues + 1] = code
    end
    local options = {
        { type = "dropdown", name = Label("LANGUAGE"), tooltip = Label("LANG_TIP"),
            choices = languageChoices, choicesValues = languageValues,
            getFunc = Get("language"), setFunc = function(value) CT.saved.language = value end,
            default = "auto", requiresReload = true, reference = "CorpseTrackerOption_language" },
        { type = "dropdown", name = Label("SOURCES"), tooltip = Label("SOURCES_TIP"),
            choices = { Choice("PRIMARY"), Choice("ALL") }, choicesValues = { "primary", "all" },
            getFunc = Get("sourceMode"), setFunc = Set("sourceMode"), default = "primary",
            reference = "CorpseTrackerOption_sourceMode" },
        Checkbox("LOCK", "locked", "LOCK_TIP", false),
        { type = "slider", name = Label("SIZE"), min = 40, max = 140, step = 4,
            getFunc = Get("squareSize"), setFunc = Set("squareSize"), default = 64,
            reference = "CorpseTrackerOption_squareSize" },
    }
    local diagnostics = {
        { type = "description", text = function() return CT.T("RELOAD_REMINDER", CT.version) end },
        { type = "dropdown", name = Label("VIEW"), tooltip = Label("VIEW_TIP"),
            choices = { Choice("COMPACT"), Choice("DETAILED") }, choicesValues = { "compact", "detailed" },
            getFunc = Get("displayMode"), setFunc = Set("displayMode"), default = "compact",
            disabled = function() return CT.saved.countMode == "light" end,
            reference = "CorpseTrackerOption_displayMode" },
        Checkbox("DEBUG", "debugMode", "DEBUG_TIP", false),
        { type = "button", name = Label("NEWTEST"), tooltip = Label("NEWTEST_TIP"),
            func = function() CT.StartDiagnostics("new_test"); CT.ApplySettings() end,
            reference = "CorpseTrackerOption_newTest" },
        { type = "button", name = Label("CLEARLOG"), tooltip = Label("CLEARLOG_TIP"),
            func = function() CT.saved.log = {} end, reference = "CorpseTrackerOption_clearLog" },
        Checkbox("CAPTURE", "capture", "CAPTURE_TIP", false),
        { type = "dropdown", name = Label("COUNT_MODE"), tooltip = Label("COUNT_TIP"),
            choices = { Choice("LIGHT"), Choice("EXTENDED") }, choicesValues = { "light", "extended" },
            getFunc = Get("countMode"), setFunc = Set("countMode"), default = "light",
            reference = "CorpseTrackerOption_countMode" },
        { type = "dropdown", name = Label("RANGE"), tooltip = Label("RANGE_TIP"),
            choices = { Choice("RANGE_SIPHON"), Choice("RANGE_YARD"), Choice("RANGE_MANUAL"), Choice("RANGE_NONE") },
            choicesValues = { "siphon", "yard", "manual", "none" },
            getFunc = Get("rangeMode"), setFunc = Set("rangeMode"), default = "siphon",
            disabled = function() return CT.saved.countMode == "light" end,
            reference = "CorpseTrackerOption_rangeMode" },
        { type = "slider", name = Label("MANUAL_RANGE"), min = 1, max = 60, step = 1,
            getFunc = Get("manualRange"), setFunc = Set("manualRange"), default = 28,
            disabled = function() return CT.saved.countMode == "light" or CT.saved.rangeMode ~= "manual" end,
            reference = "CorpseTrackerOption_manualRange" },
        Checkbox("UNKNOWN", "includeUnknown", "UNKNOWN_TIP", true),
        { type = "slider", name = Label("RADIUS"), tooltip = Label("RADIUS_TIP"), min = 1, max = 60, step = 1,
            getFunc = Get("radius"), setFunc = Set("radius"), default = 12 },
        { type = "description", title = Label("BANNER_UNAVAILABLE"), text = Label("BANNER_TIP") },
        Checkbox("PHYSICAL", "physicalOnly", "PHYSICAL_TIP", false),
    }
    for _, source in ipairs({ { "SOURCE_BB", "bbTTL", 5 }, { "SOURCE_SKULL", "skullTTL", 5 },
            { "SOURCE_ARCHER", "archerTTL", 10 }, { "SOURCE_BANNER", "bannerTTL", 5 } }) do
        local sourceKey = source[1]
        diagnostics[#diagnostics + 1] = { type = "slider", name = function() return CT.T("TTL", CT.T(sourceKey)) end,
            min = 1, max = 60, step = 1, getFunc = Get(source[2]), setFunc = Set(source[2]), default = source[3],
            tooltip = Label("TTL_TIP"), reference = "CorpseTrackerOption_" .. source[2] }
    end
    -- LAM submenus start collapsed; opening one does not start diagnostics.
    options[#options + 1] = { type = "submenu", name = Label("DIAGNOSTICS"),
        controls = diagnostics, reference = "CorpseTrackerOption_diagnostics" }
    LAM:RegisterOptionControls("CorpseTrackerSettings", options)
    return true
end
