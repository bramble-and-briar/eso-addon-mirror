local env = dofile("tests/addon.lua")
local main, section = {}, {}
local current = main
local listSwitches = 0
LibHarvensAddonSettings.scrollList = {
    GetCurrentList = function() return current end,
    GetMainList = function() return main end,
    GetList = function(_, name) assert(name == "Section"); return section end,
    SetCurrentList = function(_, list) current = list; listSwitches = listSwitches + 1 end,
}
env.panel.selected = true
function env.panel:CreateControls()
    local parent
    current.rows = {}
    for _, descriptor in ipairs(self.descriptors) do
        if descriptor.type == LibHarvensAddonSettings.ST_SECTION then parent = nil end
        if parent == current.currentSection then table.insert(current.rows, descriptor) end
        if descriptor.type == LibHarvensAddonSettings.ST_SECTION then parent = descriptor end
    end
end
function env.panel:RefreshSelection() self.selectionRefreshed = true end
local function row(label)
    for _, descriptor in ipairs(current.rows) do
        if descriptor.label == label then return descriptor end
    end
    error("Visible setting missing: " .. label)
end
env.setting("Effekt-ID").setFunction("456")
env.setting("Einheit").setFunction(nil, nil, { data = "reticleover" })
env.setting("Tracker hinzufuegen").clickHandler()
assert(current == section and section.currentSection.label == "Effect 456 (456) - Auf dem Gegner")
assert(row("Einheit").getFunction() == "Auf dem Gegner")
assert(row("Move UI").buttonText == "Icon verschieben")
local previousSection = section.currentSection
local deferred
function zo_callLater(callback) deferred = callback end
local switchesBefore = listSwitches
row("Einheit").setFunction(nil, nil, { data = "player" })
-- The real menu may clear its section reference before the deferred refresh.
section.currentSection = nil
assert(deferred)
deferred()
assert(section.currentSection ~= previousSection, "Rebuild must replace the section identity")
assert(section.currentSection.label == "Effect 456 (456) - Auf mir")
assert(row("Einheit").getFunction() == "Auf mir")
assert(listSwitches == switchesBefore, "Unit changes must not reopen the menu list")
assert(env.panel.lastSelectedRow == row("Einheit"), "Keep focus on the unit selector")
for _, unit in ipairs({ "group", "reticleover", "player", "group", "reticleover" }) do
    row("Einheit").setFunction(nil, nil, { data = unit })
    section.currentSection = nil
    deferred()
    assert(current == section and row("Move UI"))
    assert(env.panel.lastSelectedRow == row("Einheit"))
end
assert(row("Einheit").getFunction() == "Auf dem Gegner")
row("Move UI").clickHandler()
assert(env.controls.LiveBuffUptimeTracker3.mouse)
SLASH_COMMANDS["/lbu"]("move")
row("Tracker entfernen").clickHandler()
deferred()
assert(current == main and not main.currentSection)
row("Nur im Kampf anzeigen")
print("Settings: new tracker opens directly, draft unit preserved, unit changes retain page, removal returns to main passed")
