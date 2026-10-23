local env = dofile("tests/addon.lua")
local saved = env.saved()
dofile("lang/en.lua")
local function language(value)
    GetCVar = function(name) assert(name == "language.2"); return value end
    dofile("Localization.lua")
    return LiveBuffUptimeLocalization
end
local de = language("de")
assert(de.Text("Kampfstatistiken") == "Kampfstatistiken" and de.Decimal(78.23, "%.1f") == "78,2")
local en = language("en")
assert(en.Text("Kampfstatistiken") == "Combat Statistics" and en.Decimal(78.23, "%.1f") == "78.2")
assert(en.Text("custom text") == "custom text")
assert(language("fr").Text("Kampfstatistiken") == "Combat Statistics", "Untranslated languages must fall back to English")
language("en")
local function formats(text)
    local result = {}
    text = text:gsub("%%%%", "")
    for kind in text:gmatch("%%[-+ #0]*%d*%.?%d*([cdeEfgGiouqsxX])") do result[#result + 1] = kind end
    return table.concat(result)
end
for original, translated in pairs(LiveBuffUptimeEnglish) do
    assert(type(translated) == "string" and #translated > 0)
    assert(formats(original) == formats(translated), "Changed format arguments: " .. original)
end
ZO_SavedVars.NewAccountWide = function() return saved end
saved.trackers = {{key = 1, id = 123, unit = "reticleover", enabled = true, x = 100, y = 100, scale = 1}}
GetAbilityName = function(id) return "English Effect " .. id end
local manifest = assert(io.open("LiveBuffUptime.addon", "r"))
local source = manifest:read("*a"); manifest:close()
assert(source:find("Localization.lua", 1, true) < source:find("Cooldowns.lua", 1, true))
for line in source:gmatch("[^\r\n]+") do
    if line:match("%.lua$") then dofile(line) end
end
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
assert(env.setting("Combat Statistics").buttonText == "Open Combat Report")
assert(env.setting("Panel Scale").max == 1.5)
assert(env.setting("Panel Width").min == 120)
assert(not pcall(env.setting, "Panel Target"), "English settings must not offer enemy group panels")
local unit = env.setting("Unit")
assert(unit.items[1].name == "On Me" and unit.items[2].name == "On Group")
assert(unit.items[3].name == "Damage Dealers Only" and unit.items[4].name == "On Enemy")
for _, setting in ipairs(env.panel.descriptors) do
    if setting.tooltip then
        local text = type(setting.tooltip) == "function" and setting.tooltip() or setting.tooltip
        assert(#text <= 160, "English tooltip too long: " .. setting.label)
    end
end
env.setting("Show Group Panel").setFunction(true)
local key = saved.trackers[1].key
assert(not pcall(env.setting, "Placement Preview"))
assert(env.controls["LiveBuffUptimeGroupPanel" .. key .. "Title"].text ~= "")
env.setting("Panel Width").setFunction(180)
assert(saved.trackers[1].groupPanel.width == 180 and saved.trackers[1].unit == "reticleover")
local list = dofile("tests/helpers/report-console-ui.lua")(env)
LFG_ROLE_HEAL = 4
local record = {zone = "English Zone", date = "20261018", clock = "12:00:00", started = 0, ended = 10,
    buffs = {{id = 123, name = "English Effect 123", unit = "player", covered = 7.79, duration = 10, percent = 77.9,
        members = {{name = "@Test_Name", role = 4, covered = 7.79, duration = 10, deaths = 1, deadTime = 2.2}}}},
    debuffs = {{id = 34384, name = "Morag Tong", unit = "reticleover", covered = 3, duration = 4, percent = 75,
        members = {{id = 1, name = "Skeleton", covered = 1, duration = 2}, {id = 2, name = "Skeleton", covered = 2, duration = 2}}}}}
LiveBuffUptimeReports.Init({uptimeHistory = {record}})
local bindings, definition, shown
KEYBIND_STRIP = {AddKeybindButtonGroup = function(_, group) bindings = group end, RemoveKeybindButtonGroup = function() end}
GAMEPAD_DIALOGS, SI_DIALOG_CANCEL = {BASIC = 1}, "Cancel"
ZO_Dialogs_RegisterCustomDialog = function(_, dialog) definition = dialog end
ZO_Dialogs_ShowGamepadDialog = function(_, data) shown = {data = data} end
LiveBuffUptimeReports.Open()
assert(list.entries[1].subtitle == "2026-10-18 | 1 Fight")
assert(bindings[1].name == "Back" and bindings[6].name == "Delete")
assert(env.controls.LiveBuffUptimeReportTotal.text == "Personal Uptime  77.9 %")
assert(env.controls.LiveBuffUptimeReportRole1.text == "Healer")
assert(env.controls.LiveBuffUptimeReportDeaths1.text == "Deaths: 1 / 2.2 s dead")
assert(env.controls.LiveBuffUptimeReportReceiptHeading.text == "Received /\nRefreshed")
bindings[6].callback()
assert(definition.title.text(shown) == "Delete Area?")
assert(definition.mainText.text(shown):find("Really delete 1 saved fights?", 1, true))
definition.finishedCallback(shown)
bindings[5].callback()
assert(bindings[7].name() == "Lock" and bindings[7].visible())
bindings[7].callback()
assert(bindings[7].name() == "Unlock" and list.entries[1].subtitle:find("Locked", 1, true))
assert(not bindings[6].enabled())
bindings[7].callback()
bindings[5].callback()
assert(list.entries[1].subtitle == "On Me")
assert(bindings[2].name() == "Debuff Uptime")
bindings[2].callback()
assert(bindings[2].name() == "Buff Uptime")
assert(bindings[5].name() == "Show Enemy Types" and bindings[5].visible())
assert(env.controls.LiveBuffUptimeReportName1.text == "Skeleton x2")
assert(env.controls.LiveBuffUptimeReportSubtitle.text:find("2 enemies | 1 types", 1, true))
bindings[5].callback()
assert(list.entries[1].text == "Skeleton x2" and env.controls.LiveBuffUptimeReportName1.text == "Skeleton #1")
assert(env.controls.LiveBuffUptimeReportTotal.text == "Debuff Uptime  75.0 %")
LiveBuffUptimeReports.Close()
SLASH_COMMANDS["/lbu"]("status")
assert(env.messages[#env.messages]:find("Debuff", 1, true))
print("Localization: English manifest load, German retention, fallback, format parity, settings, panel, console reports, dates, decimals and deletion passed")
