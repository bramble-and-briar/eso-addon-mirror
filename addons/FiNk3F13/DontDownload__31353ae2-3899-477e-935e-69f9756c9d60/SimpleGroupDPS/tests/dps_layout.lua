local function control()
    return setmetatable({}, { __index = function(_, name)
        return function(self, value, ...)
            if name == "SetDimensions" then self.width = value; self.height = ... end
            if name == "SetAnchor" then self.anchor = { value, ... } end
            if name == "SetFont" then self.font = value end
            if name == "SetHidden" then self.hidden = value end
            if name == "SetText" then self.text = value end
            if name == "SetMaxLineCount" then self.maxLines = value end
            if name == "SetWrapMode" then self.wrapMode = value end
        end
    end })
end
WINDOW_MANAGER = { CreateControl = function() return control() end }
dofile("DPSPanel.lua")
local parent = control()
parent.swtGroupDPSLabels = {}
local members = { { name = "@Me", dps = 1000, isPlayer = true }, { name = "@Friend", dps = 2000 } }
local panel = SimpleGroupDPS_DPSPanel
local defaultHeight = panel:Render(parent, members, false, 10000)
assert(panel:GetWidth() == 400 and defaultHeight == 128, "compact default width preserves row height")
assert(parent.swtGroupDPSLabels[1].font:find("|22|", 1, true)
    and parent.swtGroupDPSLabels[1].swtDPSValue.font:find("|18|", 1, true),
    "only DPS numbers are enlarged; names and row dimensions stay unchanged")
panel:Render(parent, members, false, 10000, { dpsWidth = 450, dpsFontSize = 20, dpsRowSpacing = 10 })
assert(parent.swtGroupDPSLabels[1].swtDPSValue.font:find("|18|", 1, true),
    "DPS digits in the user's narrow layout increase from 18 to 20")
local options = { dpsWidth = 420, dpsFontSize = 14, dpsRowSpacing = 0 }
local compactHeight = panel:Render(parent, members, false, 10000, options)
assert(panel:GetWidth(options) == 400 and compactHeight == 72, "compact controls change existing rows immediately")
local row = parent.swtGroupDPSLabels[1]
assert(row.height == 16 and row.font:find("|14|", 1, true))
assert(36 + row.width + 4 + row.swtDPSValue.width <= 420, "name and DPS stay inside compact panel")
options.dpsWidth, options.dpsFontSize, options.dpsRowSpacing = 800, 30, 16
assert(panel:Render(parent, members, true, 10000, options) == 192, "expanded row spacing applies")
assert(parent.swtGroupDPSLabels.backdrop.width == 400 and row.swtBar.width == 384, "Oversized legacy widths must be capped")
assert(row.height >= 30 and row.swtIcon.width <= row.height, "large fonts and icons fit rows")
options.dpsWidth, options.dpsFontSize, options.dpsRowSpacing, options.dpsValueFontSize = 450, 20, 0, 32
panel:Render(parent, members, true, 10000, options)
assert(row.font:find("|20|", 1, true) and row.swtDPSValue.font:find("|32|", 1, true),
    "name and number sizes are independently adjustable")
assert(row.height >= 34 and 36 + row.width + 4 + row.swtDPSValue.width <= 450,
    "large DPS numbers have enough row height and remain within the window")
assert(parent.swtGroupDPSLabels.summary.swtDPSValue.font:find("|32|", 1, true), "sum uses the selected number size")
options.dpsFontSize = 14
panel:Render(parent, members, false, 10000, options)
assert(row.swtDPSValue.font:find("|32|", 1, true), "name size cannot shrink the selected DPS digits")

ZO_FormatTime = function() return "0:06" end -- A formatter rounding up must not change the measured timer.
panel:Render(parent, members, false, 5100, options)
assert(parent.swtGroupDPSLabels[0].swtDPSValue.text == "0:05", "5.1s measurement must never display as 6s")
panel:Render(parent, members, false, 5999, options)
assert(parent.swtGroupDPSLabels[0].swtDPSValue.text == "0:05", "only completed seconds appear in HUD")
panel:Render(parent, members, false, 6000, options)
assert(parent.swtGroupDPSLabels[0].swtDPSValue.text == "0:06", "six seconds appear only at six measured seconds")

local bossMembers = {{name = "@Known", dps = 2000, bossDPS = 1000}, {name = "@Unknown", dps = 1000}}
panel:Render(parent, bossMembers, true, 6000, options)
assert(parent.swtGroupDPSLabels[1].swtDPSValue.text == "1,0 Tsd. (2,0 Tsd.)", "Known boss values stay unchanged")
assert(parent.swtGroupDPSLabels[2].swtDPSValue.text == "(1,0 Tsd.)", "Unknown boss value must not show minus placeholders")
assert(parent.swtGroupDPSLabels.summary.swtDPSValue.text == "(3,0 Tsd.)", "Unknown boss sum must not show minus placeholders")
assert(bossMembers[2].bossDPS == nil, "Hiding placeholders must not invent a zero DPS value")
bossMembers[2].bossDPS = 0
panel:Render(parent, bossMembers, true, 6000, options)
assert(parent.swtGroupDPSLabels[2].swtDPSValue.text == "0 (1,0 Tsd.)", "Confirmed zero boss DPS must remain visible")
panel:Render(parent, bossMembers, true, 6000, options)
assert(parent.swtGroupDPSLabels.summary.swtDPSValue.text == "1,0 Tsd. (3,0 Tsd.)", "Restored group summary adds displayed player values")
panel:Render(parent, bossMembers, false, 0, options)
assert(parent.swtGroupDPSLabels.summary.swtDPSValue.text == "3,0 Tsd.", "Restored non-boss sum adds player DPS")
panel:Render(parent, bossMembers, true, 6000, options, {groupDPS = 600, groupBossDPS = 400})
assert(parent.swtGroupDPSLabels.summary.swtDPSValue.text == "400 (600)", "Local measurement overrides reported DPS sum")
panel:Render(parent, bossMembers, false, 6000, options, {groupDPS = 0})
assert(parent.swtGroupDPSLabels.summary.swtDPSValue.text == "0", "Measured local zero remains authoritative")
TEXT_WRAP_MODE_ELLIPSIS = 9
local narrowParent = control()
narrowParent.swtGroupDPSLabels = {}
local narrowOptions = {dpsWidth = 280, dpsFontSize = 22, dpsValueFontSize = 32}
panel:Render(narrowParent, bossMembers, true, 6000, narrowOptions)
local narrowRows = narrowParent.swtGroupDPSLabels
for _, index in ipairs({0, 1, 2, "summary"}) do
    local label = narrowRows[index].swtDPSValue
    function label:GetTextWidth()
        return #(self.text or "") * tonumber(self.font:match("|(%d+)|")) * 0.6
    end
end
local longMembers = {{name = "@AnExtremelyLongAccountName", dps = 2000000, bossDPS = 1000000}}
for width = 280, 400, 10 do
    narrowOptions.dpsWidth = width
    panel:Render(narrowParent, longMembers, true, 6000, narrowOptions)
    local narrowRow = narrowRows[1]
    assert(narrowRows.backdrop.width == width and panel:GetWidth(narrowOptions) == width, "Each narrow-width slider step must change the panel")
    assert(36 + narrowRow.width + 4 + narrowRow.swtDPSValue.width <= width, "Name and DPS columns must stay inside the narrow panel")
    assert(narrowRow.swtDPSValue:GetTextWidth() <= narrowRow.swtDPSValue.width, "Long boss/overall values must fit their column")
    assert(narrowRows.summary.swtDPSValue:GetTextWidth() <= narrowRows.summary.swtDPSValue.width)
    assert(narrowRow.maxLines == 1 and narrowRow.wrapMode == TEXT_WRAP_MODE_ELLIPSIS, "Long names must not wrap into another row")
end
assert(narrowOptions.dpsValueFontSize == 32, "Compact fitting must not overwrite the saved number size")
narrowOptions.dpsWidth = 800
panel:Render(narrowParent, {{name = "@Known", dps = 200, bossDPS = 100}}, true, 6000, narrowOptions)
assert(narrowRows[1].swtDPSValue.font:find("|32|", 1, true), "Widening must restore the requested number size")
assert(narrowRows.backdrop.width == 400 and panel:GetWidth(narrowOptions) == 400, "Maximum width must stay compact")
assert(panel:GetWidth({dpsWidth = 10}) == 280, "Width must clamp to the new compact minimum")
local nativeCalls = 0
ZO_AbbreviateAndLocalizeNumber = function(value)
    assert(value >= 1000, "Small fractional values must not reach ESO's abbreviation formatter")
    nativeCalls = nativeCalls + 1
    return "NativeAbbreviation"
end
local function integer(value) return tostring(math.floor(value + 0.5)) end
for _, value in ipairs({0, 0.123456789, 1.23456789, 42.857142857, 999.49, 999.99}) do
    local sample = {{name = "@Player", dps = value, bossDPS = value / 2},
        {name = "@Healer", messageType = "healing", rawHPS = value, effectiveHPS = value / 3}}
    panel:Render(parent, sample, true, 6000, options, {groupDPS = value, groupBossDPS = value / 2})
    assert(parent.swtGroupDPSLabels[1].swtDPSValue.text == integer(value / 2) .. " (" .. integer(value) .. ")")
    assert(parent.swtGroupDPSLabels[2].swtDPSValue.text == integer(value / 3) .. " (" .. integer(value) .. ")")
    assert(parent.swtGroupDPSLabels.summary.swtDPSValue.text == integer(value / 2) .. " (" .. integer(value) .. ")")
    assert(sample[1].dps == value, "Display rounding must not alter the actual measured DPS")
end
assert(nativeCalls == 0)
panel:Render(parent, {{name = "@Player", dps = 1000}}, false, 6000, options)
assert(parent.swtGroupDPSLabels[1].swtDPSValue.text == "1,0 Tsd." and nativeCalls == 0,
    "Thousands always use the requested Tsd. unit independently of the game formatter")
ZO_AbbreviateAndLocalizeNumber = function() return "13,2 T." end
panel:Render(parent, {{name = "@Player", dps = 13200, bossDPS = 1000},
    {name = "@Healer", messageType = "healing", rawHPS = 20000, effectiveHPS = 5000}}, true, 6000, options)
assert(parent.swtGroupDPSLabels[1].swtDPSValue.text == "1,0 Tsd. (13,2 Tsd.)")
assert(parent.swtGroupDPSLabels[2].swtDPSValue.text == "5,0 Tsd. (20,0 Tsd.)")
assert(parent.swtGroupDPSLabels.summary.swtDPSValue.text == "1,0 Tsd. (13,2 Tsd.)",
    "DPS, HPS and sum cannot change to ESO's T. abbreviation")
print("PASS: DPS layout, compact width, adaptive fitting and integer DPS/HPS/boss/group values below 1k")
