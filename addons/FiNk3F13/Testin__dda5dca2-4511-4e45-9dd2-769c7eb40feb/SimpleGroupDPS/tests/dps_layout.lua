local function control()
    return setmetatable({}, { __index = function(_, name)
        return function(self, value, ...)
            if name == "SetDimensions" then self.width = value; self.height = ... end
            if name == "SetAnchor" then self.anchor = { value, ... } end
            if name == "SetFont" then self.font = value end
            if name == "SetHidden" then self.hidden = value end
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
assert(panel:GetWidth() == 520 and defaultHeight == 128, "existing default layout preserved")
local options = { dpsWidth = 420, dpsFontSize = 14, dpsRowSpacing = 0 }
local compactHeight = panel:Render(parent, members, false, 10000, options)
assert(panel:GetWidth(options) == 420 and compactHeight == 72, "compact controls change existing rows immediately")
local row = parent.swtGroupDPSLabels[1]
assert(row.height == 16 and row.font:find("|14|", 1, true))
assert(36 + row.width + 4 + row.swtDPSValue.width <= 420, "name and DPS stay inside compact panel")
options.dpsWidth, options.dpsFontSize, options.dpsRowSpacing = 800, 30, 16
assert(panel:Render(parent, members, true, 10000, options) == 192, "expanded row spacing applies")
assert(parent.swtGroupDPSLabels.backdrop.width == 800 and row.swtBar.width == 784)
assert(row.height >= 30 and row.swtIcon.width <= row.height, "large fonts and icons fit rows")

print("PASS: standalone compact and expanded DPS layout")
