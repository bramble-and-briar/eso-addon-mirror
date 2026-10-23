local env = dofile("tests/addon.lua")
local panels = LiveBuffUptimeGroupPanels
local tracker = {config = {key = 99, id = 61771, unit = "group",
    groupPanel = {enabled = true, target = "group", x = 123, y = 234, scale = 1.2}}}
local function render(count)
    local members = {}
    for index = 1, count do members[index] = {tag = "group" .. index, name = "Spieler " .. index, available = true} end
    panels.Render(tracker, members, {}, 100, true, false, function() return {ends = 110} end, "Buff")
    return tracker.groupPanel
end
for _, count in ipairs({12, 8, 10, 7, 9, 11, 6, 1, 0, 8, 12}) do
    local panel = render(count)
    local left, right = 0, 0
    for index = 1, 12 do
        local row = panel.rows[index]
        if index <= count then
            assert(not row.name.hidden and row.name.text == "Spieler " .. index)
            assert(row.timer.text == "10,0")
            assert(row.name.y >= 30 and row.name.y <= 150)
            assert(row.timer.y == row.name.y and row.tint.y == row.name.y and row.role.y == row.name.y + 3,
                "Name, tint, role and timer must move together")
            if row.name.x == 26 then left = left + 1
            else assert(row.name.x == 242); right = right + 1 end
        else assert(row.name.hidden and row.timer.hidden and row.tint.hidden) end
    end
    if count > 6 then
        assert(left == math.ceil(count / 2) and right == math.floor(count / 2))
    else assert(left == count and right == 0) end
    assert(panel.window.width == 420 and panel.window.height == 172,
        "Changing roster size must not resize the draggable frame")
    assert(tracker.config.groupPanel.x == 123 and tracker.config.groupPanel.y == 234 and tracker.config.groupPanel.scale == 1.2)
end
print("Panel layout: balanced 7-12 player columns, compact 0-6 player list, role/timer alignment, roster changes and preserved frame/position/scale passed")
