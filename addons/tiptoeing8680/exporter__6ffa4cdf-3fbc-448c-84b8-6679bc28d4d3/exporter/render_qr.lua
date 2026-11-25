-- render_qr.lua: draws a QR matrix as black horizontal strips on a white background.
--
-- Each horizontal run of dark modules becomes one solid-colour CT_TEXTURE, so the control
-- count stays far below one-per-module. Controls are pooled and reused across frames.
-- Possible later optimisation: one TextureComposite with surfaces, which is LibQRCode's
-- approach.
-- TODO(verify) on console: a CT_TEXTURE with no texture file renders as a solid rectangle
-- when SetColor is used (FishyQR relies on this on PC).
--
-- Matrix convention (speedata luaqrcode): matrix[x][y], 1-based, value > 0 means dark.

CompanionExport = CompanionExport or {}

local Render = {}
CompanionExport.Render = Render

--- Pure: convert a matrix into runs { y, x, length } of dark modules (1-based).
function Render.runs(matrix)
    local size = #matrix
    local runs = {}
    for y = 1, size do
        local x = 1
        while x <= size do
            if matrix[x][y] > 0 then
                local start = x
                while x <= size and matrix[x][y] > 0 do
                    x = x + 1
                end
                runs[#runs + 1] = { y, start, x - start }
            else
                x = x + 1
            end
        end
    end
    return runs
end

--- Module pixel size for a target total height, including the quiet zone on both sides.
function Render.modulePx(matrixSize, targetHeightPx, quietModules)
    local px = math.floor(targetHeightPx / (matrixSize + 2 * quietModules))
    if px < 2 then
        px = 2
    end
    return px
end

local function acquireStrip(canvas, i)
    canvas.qrPool = canvas.qrPool or {}
    local strip = canvas.qrPool[i]
    if not strip then
        strip = WINDOW_MANAGER:CreateControl(canvas:GetName() .. "Strip" .. i, canvas, CT_TEXTURE)
        strip:SetColor(0, 0, 0, 1)
        strip:SetDrawLevel(2)
        canvas.qrPool[i] = strip
    end
    return strip
end

--- Draw `matrix` onto `canvas` (a CT_TEXTURE used as the white background).
--- Returns the total pixel size of the drawn code.
function Render.draw(canvas, matrix, targetHeightPx, quietModules)
    local size = #matrix
    local px = Render.modulePx(size, targetHeightPx, quietModules)
    local total = (size + 2 * quietModules) * px

    canvas:SetDimensions(total, total)
    canvas:SetColor(1, 1, 1, 1)
    canvas:SetDrawLevel(1)

    local runs = Render.runs(matrix)
    for i, run in ipairs(runs) do
        local y, x, len = run[1], run[2], run[3]
        local strip = acquireStrip(canvas, i)
        strip:ClearAnchors()
        strip:SetAnchor(TOPLEFT, canvas, TOPLEFT, (quietModules + x - 1) * px, (quietModules + y - 1) * px)
        strip:SetDimensions(len * px, px)
        strip:SetHidden(false)
    end
    local pool = canvas.qrPool or {}
    for i = #runs + 1, #pool do
        pool[i]:SetHidden(true)
    end
    return total, #runs
end
