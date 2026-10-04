local O = OneCrosshair
local assets = O.ArcAssets
O.ArcRenderer = {}
local R = O.ArcRenderer
local specs = {
    health = { angle = -math.pi / 2, centered = true, direction = 1 },
    shield = { angle = -math.pi / 2, centered = true, direction = 1 },
    bottom = { angle = math.pi / 2, centered = true, direction = -1 },
    magicka = { angle = math.pi, direction = 1 },
    stamina = { angle = 0, direction = -1 },
}
function R.Range(name, fill, length)
    local spec = specs[name]
    local span = math.pi / 2 * length / 100
    local half = span * O.Clamp(fill) / 2
    local center = spec.angle
    if not spec.centered then center = center + spec.direction * (half - span / 2) end
    return center - half, center + half, center
end
local function Texture(parent, file, level)
    local c = O.Control(parent, CT_TEXTURE)
    c:SetTexture("OneCrosshair/Assets/" .. file .. ".dds")
    c:SetDimensions(assets.extent * 2, assets.extent * 2)
    c:SetAnchor(CENTER, parent, CENTER, 0, 0)
    c:SetPixelRoundingEnabled(false)
    c:SetBlendMode(TEX_BLEND_MODE_ALPHA)
    c:SetDrawLevel(level)
    c:SetColor(1, 1, 1, 0)
    return c
end
function R.New(parent, name)
    local file = name == "shield" and "ArcShield" or "ArcFill"
    local level = name == "shield" and 4 or 2
    local arc = { first = Texture(parent, file, level), second = Texture(parent, file, level) }
    if name == "health" or name == "magicka" or name == "stamina" then
        arc.glow = Texture(parent, "ArcWarning", 0)
        local _, _, center = R.Range(name, 1, assets.length)
        -- ESO texture rotation runs opposite to our screen-space polar angles.
        arc.glow:SetTextureRotation(-(center + math.pi / 2), .5, .5)
    end
    return arc
end
function R.Hidden(arc, hidden)
    arc.first:SetHidden(hidden); arc.second:SetHidden(hidden)
    if arc.glow then arc.glow:SetHidden(hidden) end
end
local function Frame(control, name, frame)
    local column, row = frame % assets.columns, math.floor(frame / assets.columns)
    control:SetTextureCoords(column / assets.columns, (column + 1) / assets.columns,
        row / assets.rows, (row + 1) / assets.rows)
    local _, _, center = R.Range(name, frame / assets.steps, assets.length)
    control:SetTextureRotation(-(center + math.pi / 2), .5, .5)
end
function R.Draw(arc, name, fill, color, alpha, glowing)
    fill, alpha = O.Clamp(fill), O.Clamp(alpha)
    if arc.fill == fill and arc.color == color and arc.alpha == alpha and arc.glowing == glowing then return end
    local glowChanged = arc.color ~= color or arc.alpha ~= alpha or arc.glowing ~= glowing
    arc.fill, arc.color, arc.alpha, arc.glowing = fill, color, alpha, glowing
    local position = fill * assets.steps
    local frame = math.floor(position)
    local weight = position - frame
    Frame(arc.first, name, frame)
    Frame(arc.second, name, math.min(frame + 1, assets.steps))
    -- Correct source-over opacity, avoiding dimming in the shared solid region.
    local upper = alpha * weight
    local lower = upper < 1 and alpha * (1 - weight) / (1 - upper) or 0
    if fill == 0 then lower, upper = 0, 0 end
    arc.first:SetColor(color[1], color[2], color[3], lower)
    arc.second:SetColor(color[1], color[2], color[3], upper)
    if arc.glow and glowChanged then
        arc.glow:SetColor(color[1], color[2], color[3], alpha * .6 * glowing)
    end
end
