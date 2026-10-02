BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.UI = BGMeter.UI or {}

local U = BGMeter.UI._win
local K = BGMeter.Constants
local S = BGMeter.Plot.style
local Drawer = BGMeter.UI.Drawer
local set_text = U.set_text
local hexc = BGMeter.Format.hexc

local M = {}

if not K.dev_tools() then
    BGMeter.UI.dev = M
    return
end

local ACTIONS = {
    { label = "Diagnostic report", cmd = "report", tip = "Everything I need to look at a problem, in the copybox.\nSelect All, Ctrl+C, paste it to me." },
    { label = "Veterancy dump", cmd = "vet", tip = "Every raw veterancy value the game reports, in the copybox." },
    { label = "Map art", cmd = "art", tip = "For every recorded match: battleground name, map id, zone and the background it resolves to, in the copybox.\nA guess or FALLBACK line is an arena that needs an entry." },
    { label = "Live scoreboard dump", cmd = "dump", tip = "Reads the scoreboard right now and prints it (chat)." },
    { label = "Perf counters", cmd = "perf", tip = "Frame times, heap and per-probe cost since the last reset." },
    { label = "Perf reset", cmd = "perf reset" },
    { label = "Profiler report", cmd = "prof", tip = "Every instrumented stage since the last reset: calls, p50, p95, worst, allocation, budget misses." },
    { label = "Profiler reset", cmd = "prof reset" },
    { label = "Validation report", cmd = "validate", tip = "Every invariant that tripped since the last reset: clocks, caps, codec round-trips, finite numbers, handler errors." },
    { label = "Validation reset", cmd = "validate reset" },
    { label = "GC probe 10 s", cmd = "gcprobe 10", tip = "Measures allocation per frame for ten seconds, result in chat." },
    { label = "Anchor probe", cmd = "probe anchors 100", tip = "Times ClearAnchors, SetAnchor, SetColor, SetThickness and SetHidden on 100 map line controls, in the copybox." },
    { label = "Debug log on/off", cmd = "debug", tip = "Echo debug lines to chat while it is on." },
    { label = "Layer debug", cmd = "layers", tip = "Paints every layer of the result window in a flat colour." },
    { label = "Mock: deathmatch", cmd = "mock dm" },
    { label = "Mock: domination", cmd = "mock dom" },
    { label = "Mock: crazy king", cmd = "mock ck" },
    { label = "Mock: chaosball", cmd = "mock ball" },
    { label = "Mock: capture the relic", cmd = "mock relic" },
    { label = "Mock 6v6v6: deathmatch", cmd = "mock tri dm", tip = "A three-sided match as the addon would show it today." },
    { label = "Mock 6v6v6: domination", cmd = "mock tri dom" },
    { label = "Mock 6v6v6: crazy king", cmd = "mock tri ck" },
    { label = "Mock 6v6v6: chaosball", cmd = "mock tri ball" },
    { label = "Mock 6v6v6: capture the relic", cmd = "mock tri relic" },
    { label = "Trophy demo (next rank)", cmd = "trophy", tip = "Steps the competitive standing through the demo ranks." },
    { label = "Vet mock: below cap", cmd = "vetmock below" },
    { label = "Vet mock: rank 34 rewards", cmd = "vetmock r34" },
    { label = "Vet mock: at cap", cmd = "vetmock cap" },
    { label = "Vet mock: past max h1", cmd = "vetmock h1" },
    { label = "Vet mock: past max h2", cmd = "vetmock h2" },
    { label = "Vet mock: past max h3", cmd = "vetmock h3" },
    { label = "Vet mock: off", cmd = "vetmock off" },
    { label = "Forget faces", cmd = "forget faces" },
    { label = "Geo: probe now", cmd = "geo", tip = "Map, tiles, your position, the group's and the objective pins, right now.\nRun it once outside a battleground and once inside." },
    { label = "Geo: record ON", cmd = "geo on", tip = "Samples positions every 2 s during battlegrounds until you turn it off.\nStarts by itself when a match begins." },
    { label = "Geo: record OFF", cmd = "geo off" },
    { label = "Geo: mark here", cmd = "geo mark", tip = "Notes your position with a timestamp. Stand on a flag or a base and mark it." },
    { label = "Geo: dump page 1", cmd = "geo dump 1", tip = "The trace in pages the copybox can hold. Select All, Ctrl+C, paste each page to me." },
    { label = "Geo: dump page 2", cmd = "geo dump 2" },
    { label = "Geo: dump page 3", cmd = "geo dump 3" },
    { label = "Geo: dump page 4", cmd = "geo dump 4" },
    { label = "Geo: dump page 5", cmd = "geo dump 5" },
    { label = "Geo: dump page 6", cmd = "geo dump 6" },
    { label = "Geo: clear trace", cmd = "geo clear" },
}

local D = Drawer.new({
    key = "dev",
    index = 4,
    title = "Developer",
    icon = "EsoUI/Art/Help/help_tabIcon_CS_up.dds",
    icon_down = "EsoUI/Art/Help/help_tabIcon_CS_down.dds",
    icon_over = "EsoUI/Art/Help/help_tabIcon_CS_over.dds",
    drag_name = "BGMeterDevDrag",
    list_heading = "DEV BUILD  ·  " .. K.VERSION,
    cache_key = function(self) return "dev" end,
    fetch = function(self) return ACTIONS end,
    row_make = function(self, r)
        r.name:ClearAnchors()
        r.name:SetAnchor(LEFT, r.container, LEFT, 10, 0)
        r.name:SetAnchor(RIGHT, r.container, RIGHT, -70, 0)
        r.count:SetDimensions(64, Drawer.row_h())
        if r.count.SetFont then r.count:SetFont(S.FONT.small) end
        U.clamp_line(r.count)
    end,
    row_fill = function(self, r, e)
        set_text(r.name, e.label)
        set_text(r.count, string.format("|c%s/%s|r", hexc(K.COLOR.text_dim), e.cmd))
    end,
    describe = function(self, e)
        return (e.tip and (e.tip .. "\n") or "") .. "runs  /bgmeter " .. e.cmd
    end,
    on_click = function(self, e)
        if BGMeter._slash then BGMeter._slash(e.cmd) end
        BGMeter.Sound.play("nav")
    end,
    foot = function(self, list)
        return "click a row to run it  ·  never ships: dev keys off in release"
    end,
})

function M.invalidate() D:invalidate() end
function M.refresh() D:refresh() end
function M.is_open() return D:is_open() end
function M.toggle() D:toggle() end
function M.on_host_resized() D:on_host_resized() end
function M.on_menu_shown() D:on_menu_shown() end
function M.init(pw) D:init(pw) end
function M.controls() return D:controls() end
M.actions = ACTIONS
M.drawer = D

BGMeter.UI.dev = M
