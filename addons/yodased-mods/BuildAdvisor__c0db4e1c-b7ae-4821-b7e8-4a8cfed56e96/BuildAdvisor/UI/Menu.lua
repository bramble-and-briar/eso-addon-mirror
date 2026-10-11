local BA = BuildAdvisor
-- Menu lives in the game's Settings page via LibConsoleMenu (same pattern as PullCard).
-- Everything is read by highlighting a row: the tooltip shows it. Pressing a row does nothing,
-- since the tooltip is already on screen. Tooltips are functions, so every highlight rescans
-- the character and follows gear swaps without a reload.

local function FormatNumber(value)
    return ZO_CommaDelimitNumber and ZO_CommaDelimitNumber(value) or tostring(value)
end

-- A read-only row: its text is the tooltip.
local function InfoRow(name, getText)
    return {
        type = "button",
        name = name,
        tooltip = function() return getText() end,
        func = function() end,
    }
end

-------------------------------------------------------------------------------
-- Role / activity pickers (saved per character). "auto" means guess from the scan; selector
-- values must be strings, so it stands in for nil.
-------------------------------------------------------------------------------
local function CharacterSelector(name, tooltip, list, key)
    local choices = { { name = "Auto (guess)", value = "auto" } }
    for _, entry in ipairs(list) do
        choices[#choices + 1] = { name = entry.name, value = entry.id }
    end
    return {
        type = "selector",
        name = name,
        tooltip = tooltip,
        choices = choices,
        default = "auto",
        getFunc = function() return BA.char[key] or "auto" end,
        setFunc = function(value) BA.char[key] = (value ~= "auto") and value or nil end,
    }
end

local function DescribeActivities()
    local lines = { "What you want this character to do. Auto guesses from where you are. Saved for this character only.", "" }
    for _, activity in ipairs(BA.activities) do
        lines[#lines + 1] = activity.note and string.format("- %s: %s", activity.name, activity.note) or ("- " .. activity.name)
    end
    return table.concat(lines, "\n")
end

-------------------------------------------------------------------------------
-- Analysis rows
-------------------------------------------------------------------------------
local function AnalysisRow(name, section)
    return InfoRow(name, function()
        local report = BA.Advisor:Analyze()
        if section == "summary" then return BA.Advisor:FormatSummary(report) end
        return BA.Advisor:FormatSection(report, section)
    end)
end

-------------------------------------------------------------------------------
-- Raw scan (what the analysis is based on)
-------------------------------------------------------------------------------
-- Appends "could not read" lines for scan sections that errored (e.g. a private API on console).
local function AppendErrors(lines, snapshot, sections)
    for _, section in ipairs(sections) do
        local err = snapshot.errors[section]
        if err then
            lines[#lines + 1] = ""
            lines[#lines + 1] = string.format("Could not read %s: %s", section, err)
        end
    end
    return table.concat(lines, "\n")
end

local function DescribeCharacter(snapshot)
    local a = snapshot.attributes
    local lines = {
        string.format("%s %s, level %d, CP %d", snapshot.raceName, snapshot.className, snapshot.level, snapshot.cp),
        string.format("Attributes: Health %s / Magicka %s / Stamina %s", tostring(a.health or "?"), tostring(a.magicka or "?"), tostring(a.stamina or "?")),
        "",
    }
    for _, stat in ipairs(BA.Scanner.STATS) do
        local value = snapshot.stats[stat.key]
        if value then lines[#lines + 1] = string.format("%s: %s", stat.label, FormatNumber(value)) end
    end
    return AppendErrors(lines, snapshot, { "character", "stats" })
end

local function DescribeGear(snapshot)
    local w = snapshot.armorWeights
    local lines = { string.format("Armor: %d light, %d medium, %d heavy", w.light, w.medium, w.heavy), "" }
    local sets = {}
    for _, set in pairs(snapshot.sets) do sets[#sets + 1] = set end
    table.sort(sets, function(x, y) return x.name < y.name end)
    for _, set in ipairs(sets) do
        lines[#lines + 1] = string.format("%s (%d/%d)", set.name, set.equipped, set.max or 0)
    end
    if #sets == 0 then lines[#lines + 1] = "No set items equipped." end
    lines[#lines + 1] = ""
    for _, piece in ipairs(snapshot.slots) do
        local details = {}
        if piece.weaponType then details[#details + 1] = piece.weaponType end
        if piece.armorWeight then details[#details + 1] = piece.armorWeight end
        if piece.trait then details[#details + 1] = piece.trait end
        if piece.enchant ~= "" then details[#details + 1] = piece.enchant end
        lines[#lines + 1] = string.format("- %s (%s)", piece.name, table.concat(details, ", "))
    end
    return AppendErrors(lines, snapshot, { "gear" })
end

local function DescribeSkillBars(snapshot)
    local lines = {}
    for _, bar in ipairs({ { key = "front", label = "Front bar" }, { key = "back", label = "Back bar" } }) do
        local names = {}
        for _, skill in ipairs(snapshot.bars[bar.key]) do
            names[#names + 1] = skill.ultimate and (skill.name .. " (ult)") or skill.name
        end
        lines[#lines + 1] = bar.label .. ": " .. (#names > 0 and table.concat(names, ", ") or "empty")
        lines[#lines + 1] = ""
    end
    return AppendErrors(lines, snapshot, { "skills" })
end

local function DescribeChampionAndMundus(snapshot)
    local lines = {
        "Mundus: " .. (#snapshot.mundus > 0 and table.concat(snapshot.mundus, ", ") or "none detected"),
        "",
        string.format("Champion points earned: %s", tostring(snapshot.cpEarned)),
        "Slotted stars:",
    }
    for _, star in ipairs(snapshot.champion) do
        lines[#lines + 1] = string.format("- %s (%d pts)", star.name, star.points or 0)
    end
    if #snapshot.champion == 0 then lines[#lines + 1] = "- none" end
    return AppendErrors(lines, snapshot, { "mundus", "champion" })
end

function BA:BuildScanOptions()
    local function scanRow(name, describe)
        return InfoRow(name, function() return describe(BA.Scanner:Snapshot()) end)
    end
    return {
        scanRow("Character & Stats", DescribeCharacter),
        scanRow("Gear", DescribeGear),
        scanRow("Skill Bars", DescribeSkillBars),
        scanRow("Champion & Mundus", DescribeChampionAndMundus),
    }
end

-------------------------------------------------------------------------------
-- Reference builds and gear sources
-------------------------------------------------------------------------------
local function DescribeBuild(build)
    local snapshot = BA.Scanner:Snapshot()
    local lines = { build.description or "", "" }
    lines[#lines + 1] = string.format("Class: %s    Role: %s", build.class or "?", build.role or "?")
    if build.activity then lines[#lines + 1] = "Activities: " .. table.concat(build.activity, ", ") end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Sets (you have / needed):"
    for _, req in ipairs(BA.GearTracker:GetRequirements(build, snapshot)) do
        lines[#lines + 1] = string.format("- %s %d/%d (%s)", req.name, req.equipped, req.pieces, req.source)
    end
    if build.skills then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Skills: " .. table.concat(build.skills, ", ")
    end
    if build.ultimate then lines[#lines + 1] = "Ultimate: " .. build.ultimate end
    return table.concat(lines, "\n")
end

function BA:BuildReferenceOptions()
    local builds = {}
    for _, build in pairs(self.builds) do builds[#builds + 1] = build end
    table.sort(builds, function(a, b) return a.name < b.name end)
    local options = {}
    for _, build in ipairs(builds) do
        options[#options + 1] = InfoRow(build.name, function() return DescribeBuild(build) end)
    end
    return options
end

function BA:BuildGearSourceOptions()
    local ids = {}
    for id in pairs(self.gearSources) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b) return self.gearSources[a].name < self.gearSources[b].name end)
    local options = {}
    for _, id in ipairs(ids) do
        local data = self.gearSources[id]
        options[#options + 1] = InfoRow(data.name, function()
            local wearing = BA.Scanner:GetEquippedCount(BA.Scanner:Snapshot(), data)
            return table.concat({
                "Source: " .. data.source,
                "Zone: " .. data.zone,
                string.format("You're wearing: %d", wearing),
                "",
                data.method,
            }, "\n")
        end)
    end
    return options
end

function BA:BuildSettingsOptions()
    return {
        {
            type = "slider",
            name = "Popup display time (seconds)",
            tooltip = "Minimum time the /badv summary stays on screen if it can't open as a dialog (up to 60 seconds).",
            min = 3,
            max = 60,
            step = 1,
            default = BA.defaults.popupSeconds,
            getFunc = function() return BA.saved.popupSeconds end,
            setFunc = function(value) BA.saved.popupSeconds = value end,
        },
    }
end

-------------------------------------------------------------------------------
-- Registration
-------------------------------------------------------------------------------
function BA:InitializeMenu()
    if not LibConsoleMenu or type(LibConsoleMenu.CreateAddonMenu) ~= "function" then
        return
    end

    local menu = LibConsoleMenu:CreateAddonMenu(self.name, {
        title = "Build Advisor",
        author = "yodased",
        version = self.version,
        category = "utility",
    })
    if not menu then return end

    menu:AddOptions({
        CharacterSelector("Role", "Your role on this character. Auto guesses from your gear. Saved for this character only.", BA.roles, "role"),
        CharacterSelector("Activity", DescribeActivities(), BA.activities, "activity"),
        AnalysisRow("Summary", "summary"),
        AnalysisRow("Group Support", "support"),
        AnalysisRow("Damage", "damage"),
        AnalysisRow("Survivability", "survival"),
        AnalysisRow("Gear & Traits", "gear"),
        AnalysisRow("Mundus & Champion", "mundus"),
        { type = "submenu", name = "Character Scan", options = self:BuildScanOptions() },
        { type = "submenu", name = "Reference Builds", options = self:BuildReferenceOptions() },
        { type = "submenu", name = "Gear Sources", options = self:BuildGearSourceOptions() },
        { type = "submenu", name = "Settings", options = self:BuildSettingsOptions() },
    })
end

-- /buildadvisor and /badv: the analysis summary as a dialog.
function BA:ShowSummary()
    self.Popup:Show("Build Advisor", BA.Advisor:FormatSummary(BA.Advisor:Analyze()))
end
