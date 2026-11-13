-- ============================================================================
-- Bloom HPS - Core
-- Namespace, constants, saved-setting defaults and small shared helpers.
-- ============================================================================

HPSMeterUI = HPSMeterUI or {}
local M = HPSMeterUI

M.name    = "HPSMeter"
M.title   = "Bloom HPS"
M.version = "4.0"
M.author  = "Vixen Hunny"

M.TICK_MS = 500 -- how often the meter redraws while a fight is running

-- pastel pink / lavender / mint
M.DEFAULT_HEAL_COLOR   = "ffb3d1"
M.DEFAULT_SHIELD_COLOR = "c9b8ff"
M.DEFAULT_MITIGATION_COLOR = "a8ecd0"

-- defaults from before the pastel restyle, swapped for the new ones on load
-- if the player never changed them
M.OLD_DEFAULT_COLORS = {
    labelColor      = { "9ff8ba", M.DEFAULT_HEAL_COLOR },
    shieldColor     = { "b8f7ff", M.DEFAULT_SHIELD_COLOR },
    mitigationColor = { "d6ffd6", M.DEFAULT_MITIGATION_COLOR },
}

M.defaults = {
    showLabel   = true,
    labelX      = 300,
    labelY      = 200,
    scale       = 0.5,
    labelColor  = M.DEFAULT_HEAL_COLOR,
    showShields = true,
    shieldColor = M.DEFAULT_SHIELD_COLOR,
    showSplits  = true,  -- personal / group lines
    showMitigation = true,
    mitigationColor = M.DEFAULT_MITIGATION_COLOR,
    groupMode   = true,  -- LibFights group mode (needed for group shields)
    showTitle   = true,
    showFlowers = true,
    hideInMenus = true,  -- only show on the HUD, not in inventory / map / menus
    flowerAlpha = 0.6,
}

local floor, format = math.floor, string.format

-- 950 -> "950", 1500 -> "1.5k", 12000 -> "12k", 2300000 -> "2.3m"
function M.FormatShortNumber(n)
    n = tonumber(n) or 0
    local absN = math.abs(n)
    local divisor, suffix
    if absN >= 1e9 then
        divisor, suffix = 1e9, "b"
    elseif absN >= 1e6 then
        divisor, suffix = 1e6, "m"
    elseif absN >= 1e3 then
        divisor, suffix = 1e3, "k"
    else
        return tostring(floor(n))
    end
    local v = n / divisor
    if absN >= divisor * 10 then
        return format("%.0f%s", v, suffix)
    end
    return (format("%.1f", v):gsub("%.0$", "")) .. suffix
end

-- Returns a clean lowercase 6-digit hex string, or the fallback if invalid.
function M.SanitizeHex(value, fallback)
    local hex = tostring(value or ""):gsub("^#", ""):lower()
    if hex:match("^%x%x%x%x%x%x$") then return hex end
    return fallback
end

function M.HexToRGBA(hex, alpha)
    local r = tonumber(hex:sub(1, 2), 16) or 255
    local g = tonumber(hex:sub(3, 4), 16) or 255
    local b = tonumber(hex:sub(5, 6), 16) or 255
    return r / 255, g / 255, b / 255, alpha or 1
end

-- Texture paths: the game wants them relative to the AddOns folder, and the
-- folder name may differ from M.name, so a few spellings are checked side by
-- side (see UI.VerifyTextures) and the first one that loads is used.
local textureRoots, textureRootIndex

function M.GetAddOnRootPath()
    local manager = GetAddOnManager and GetAddOnManager()
    if not (manager and manager.GetAddOnRootDirectoryPath) then return nil end
    for i = 1, manager:GetNumAddOns() do
        if manager:GetAddOnInfo(i) == M.name then
            return manager:GetAddOnRootDirectoryPath(i)
        end
    end
end

function M.TextureRoots()
    if textureRoots then return textureRoots end
    textureRoots = {}
    local seen = {}
    local function Add(root)
        if root and not seen[root] then
            seen[root] = true
            textureRoots[#textureRoots + 1] = root
        end
    end
    local rootPath = M.GetAddOnRootPath()
    local folder = rootPath and rootPath:match("[Aa]dd[Oo]ns/(.-)/?$")
    if folder and folder ~= "" then
        Add("/" .. folder .. "/")
        Add(folder .. "/")
    end
    Add("/" .. M.name .. "/")
    Add(M.name .. "/")
    textureRootIndex = 1
    return textureRoots
end

function M.TextureRoot()
    return M.TextureRoots()[textureRootIndex]
end

-- Switches to candidate root `index`; returns true if it changed.
function M.SetTextureRoot(index)
    M.TextureRoots()
    if index == textureRootIndex then return false end
    textureRootIndex = index
    return true
end

function M.Texture(name)
    return M.TextureRoot() .. "textures/" .. name .. ".dds"
end

function M.Print(msg)
    msg = format("[%s] %s", M.title, msg)
    if IsConsoleUI() and CHAT_ROUTER then
        CHAT_ROUTER:AddSystemMessage(msg)
    else
        d(msg)
    end
end
