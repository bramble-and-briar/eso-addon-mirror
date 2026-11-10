-- Draws a QR matrix inside a parent control using solid backdrops.
-- Horizontal runs of dark modules are merged into a single control, which keeps the
-- control count low (a ~65x65 code needs a few hundred runs instead of thousands of cells).
local QRRenderer = ZO_InitializingObject:Subclass()

local QUIET_ZONE_MODULES = 4

function QRRenderer:Initialize(parent, canvasSize)
    self.parent = parent
    self.canvasSize = canvasSize
    self.runControls = {}
    self.background = self:CreateSolidControl(parent:GetName() .. "Background", 1, 1, 1)
end

function QRRenderer:CreateSolidControl(name, r, g, b)
    local control = WINDOW_MANAGER:CreateControl(name, self.parent, CT_BACKDROP)
    control:SetCenterColor(r, g, b, 1)
    control:SetEdgeColor(0, 0, 0, 0)
    return control
end

function QRRenderer:AcquireRunControl(runIndex)
    local control = self.runControls[runIndex]
    if not control then
        control = self:CreateSolidControl(self.parent:GetName() .. "Run" .. runIndex, 0, 0, 0)
        control:SetDrawLevel(1)
        self.runControls[runIndex] = control
    end
    control:SetHidden(false)
    return control
end

function QRRenderer:HideRunsFrom(firstUnusedIndex)
    for runIndex = firstUnusedIndex, #self.runControls do
        self.runControls[runIndex]:SetHidden(true)
    end
end

-- matrix[x][y], 1-based, positive values are dark modules (luaqrcode convention).
function QRRenderer:Render(matrix)
    local moduleCount = #matrix
    local moduleSize = zo_floor(self.canvasSize / (moduleCount + 2 * QUIET_ZONE_MODULES))
    local totalSize = moduleSize * (moduleCount + 2 * QUIET_ZONE_MODULES)
    local origin = moduleSize * QUIET_ZONE_MODULES

    self.background:ClearAnchors()
    self.background:SetAnchor(CENTER, self.parent, CENTER)
    self.background:SetDimensions(totalSize, totalSize)

    local runIndex = 0
    for y = 1, moduleCount do
        local x = 1
        while x <= moduleCount do
            if matrix[x][y] > 0 then
                local runStart = x
                while x <= moduleCount and matrix[x][y] > 0 do
                    x = x + 1
                end
                runIndex = runIndex + 1
                local run = self:AcquireRunControl(runIndex)
                run:ClearAnchors()
                run:SetAnchor(TOPLEFT, self.background, TOPLEFT, origin + (runStart - 1) * moduleSize, origin + (y - 1) * moduleSize)
                run:SetDimensions((x - runStart) * moduleSize, moduleSize)
            else
                x = x + 1
            end
        end
    end
    self:HideRunsFrom(runIndex + 1)
end

TradeQR.QRRenderer = QRRenderer
