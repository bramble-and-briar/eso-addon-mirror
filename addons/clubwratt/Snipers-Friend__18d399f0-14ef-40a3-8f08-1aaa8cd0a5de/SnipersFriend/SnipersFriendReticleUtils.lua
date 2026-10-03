-- SnipersFriendReticleUtils.lua: Pure helpers for the reticle dot (no side effects)

local ReticleUtils = {}

local TEXTURE_ROOT = "SnipersFriend/textures/"

---@type table<string, SnipersFriendReticleStyle>
ReticleUtils.STYLES = {
    dot_small  = { label = "Dot (small)",      texture = TEXTURE_ROOT .. "dot_small.dds" },
    dot_medium = { label = "Dot (medium)",     texture = TEXTURE_ROOT .. "dot_medium.dds" },
    dot_large  = { label = "Dot (large)",      texture = TEXTURE_ROOT .. "dot_large.dds" },
    dot_plain  = { label = "Dot (no outline)", texture = TEXTURE_ROOT .. "dot_plain.dds" },
    ring       = { label = "Ring",             texture = TEXTURE_ROOT .. "ring.dds" },
    ring_dot   = { label = "Ring + dot",       texture = TEXTURE_ROOT .. "ring_dot.dds" },
}

---@type string[]
ReticleUtils.STYLE_ORDER = { "dot_small", "dot_medium", "dot_large", "dot_plain", "ring", "ring_dot" }

---@param key string
---@return SnipersFriendReticleStyle
function ReticleUtils.GetStyle(key)
    return ReticleUtils.STYLES[key] or ReticleUtils.STYLES.dot_medium
end

---Dropdown items for LibHarvensAddonSettings
---@return {name: string, data: string}[]
function ReticleUtils.StyleItems()
    local items = {}
    for _, key in ipairs(ReticleUtils.STYLE_ORDER) do
        items[#items + 1] = { name = ReticleUtils.STYLES[key].label, data = key }
    end
    return items
end

---@param label string
---@return string|nil
function ReticleUtils.StyleKeyFromLabel(label)
    for key, style in pairs(ReticleUtils.STYLES) do
        if style.label == label then
            return key
        end
    end
    return nil
end

---@param v number
---@param lo number
---@param hi number
---@return number
function ReticleUtils.Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

---@param c SnipersFriendRGBA
---@return number, number, number, number
function ReticleUtils.UnpackColor(c)
    return c.r or 1, c.g or 1, c.b or 1, c.a or 1
end

SnipersFriend.ReticleUtils = ReticleUtils
