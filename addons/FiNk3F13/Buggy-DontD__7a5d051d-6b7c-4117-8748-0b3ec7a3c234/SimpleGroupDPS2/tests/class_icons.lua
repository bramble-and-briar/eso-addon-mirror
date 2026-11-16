local env = dofile("tests/standalone.lua")
local rows = env.window.swtGroupDPSLabels
local classes = {11, 24, 37, 52, 68, 91, 117}
local unitClasses = {player = 117, group1 = 24}
function GetUnitClassId(tag) return unitClasses[tag] or 0 end
function GetNumClasses() return #classes end
function GetClassIndexById(id)
    for i, value in ipairs(classes) do if value == id then return i end end
end
function GetClassInfo(index)
    local id = assert(classes[index], "GetClassInfo takes the index, not the class ID")
    return id, "Lore", "Normal", "Pressed", "Hover", true, "ClassIcon_" .. id .. ".dds"
end
env.receive("group1", {messageType = "damage", allTargetsDPS = 20000})
assert(rows[1].swtClassIcon.texture == "ClassIcon_24.dds" and not rows[1].swtClassIcon.hidden)
assert(rows[2].swtClassIcon.texture == "ClassIcon_117.dds" and not rows[2].swtClassIcon.hidden,
    "Own player and received member both get their actual base class")
for _, row in ipairs({rows[1], rows[2]}) do
    assert(row.left + row.swtClassIcon.left == 8, "Class symbol begins at the left padding")
    assert(row.swtClassIcon.left + row.swtClassIcon.width <= row.swtIcon.left,
        "Class symbol is left of the role symbol without overlap")
    assert(row.swtIcon.left + row.swtIcon.width <= 0, "Role symbol cannot overlap name")
    assert(row.left + row.width + 4 + row.swtDPSValue.width <= env.window.width,
        "The values still fit inside the unchanged window width")
    assert(row.left + row.swtBar.left == 8, "Bars still start at the left padding")
end
assert(rows.summary.swtClassIcon.hidden, "Sum has no arbitrary class symbol")
function GetUnitDisplayName(tag) return tag == "group1" and "@NewPeer" or "@Me" end
unitClasses.group1 = 0
env.receive("group1", {messageType = "damage", allTargetsDPS = 21000})
assert(rows[1].swtClassIcon.hidden, "A reused row cannot display the previous player's class for an unknown new member")

print("PASS: class-ID lookup, own/group icons, compact placement and unknown classes")
