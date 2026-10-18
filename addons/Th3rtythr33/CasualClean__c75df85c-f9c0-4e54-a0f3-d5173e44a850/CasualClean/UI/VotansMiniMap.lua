-- =============================================================================
-- CasualClean -- UI/VotansMiniMap.lua
-- =============================================================================
-- Fixes the Grid X / Grid Y position sliders in Votan's Minimap's settings on
-- console. Inert when that add-on is not installed. Full investigation in
-- Docs/VotansMiniMap-SliderBug.md; the short version:
--
--   * Votan's Minimap 2.2.2 sets the slider bounds to +/- (GuiRoot size / 16).
--     A 1080-tall screen gives Grid Y a range of -67.5..67.5 with step 1, so
--     every reachable value sits on a half-step, while Grid X gets a whole
--     120. That is the only difference between the two rows and why only the
--     vertical slider misbehaves.
--   * Its getters return math.floor(account.y / 8), and after every move the
--     add-on reads the map's actual centre back into account.y, so a centre
--     that lands off a whole eighth (clamping, or a fractional centre) pushes
--     the slider a step away from where the player left it.
--
-- THE FIX, applied to the LHAS setting objects the minimap itself mutates
-- (locationSettings = settings:AddSettings({...}) in its Settings.lua, the
-- same objects as VOTANS_MINIMAP.settingsControls.settings[i], whose min /
-- max / default / getFunction fields LHAS re-reads on every redraw):
--
--   1. min rounded up and max rounded down to whole numbers, so the slider's
--      steps are whole numbers (cause 1);
--   2. getFunction replaced by zo_round(account[axis] / 8), so a read-back a
--      fraction off a whole eighth no longer moves the slider (cause 2);
--   3. the defaults index slip corrected: the add-on computes Grid X's
--      default from Grid Y's row and Grid Y's from Grid W's; the intent is
--      "flush to the right / bottom edge", i.e. X from W and Y from H.
--
-- The setters are left alone. Everything is restored exactly on disable.
--
-- RE-APPLYING. The minimap's local getScreenDimensions() rewrites min, max
-- and default on EVENT_ALL_GUI_SCREENS_RESIZED (it never touches getFunction).
-- This module registers its own handler for that event and re-applies one
-- frame later through zo_callLater, since the order in which the two
-- handlers run is not something to rely on. Refresh is also re-run from
-- RefreshState, with the same short retry as the other third-party tweak.
--
-- VERSION. The structure, not the version string, is the gate: rows found by
-- their localised labels, numeric bounds, function getters. The minimap's
-- settingsControls.version is reported so a future change is visible.
--
-- The add-on's global is VOTANS_MINIMAP (end of its Main.lua); account is its
-- ZO_SavedVars account-wide table, positions in pixels, sliders in eighths.
-- =============================================================================

CasualClean = CasualClean or {}
local CC = CasualClean
CC.VotansMiniMap = {}
local V = CC.VotansMiniMap

-- On by default: it only ever acts when the minimap is installed, and the
-- sliders are broken without it.
V.DEFAULT_ENABLED = true

local ADDON_GLOBAL = "VOTANS_MINIMAP"
local EVENT_NS = "CasualCleanVotansMiniMap"
local RETRY_MS, RETRY_ATTEMPTS = 250, 8

-- Rows by their string ids. labelText is the localised string the minimap
-- passed in, so matching GetString(id) works in every language.
local ROW_IDS = {
    x = "SI_VOTANSMINIMAP_GRID_X",
    y = "SI_VOTANSMINIMAP_GRID_Y",
    w = "SI_VOTANSMINIMAP_GRID_W",
    h = "SI_VOTANSMINIMAP_GRID_H",
}

local mm = nil             -- VOTANS_MINIMAP, once resolved
local rows = nil           -- { x=, y=, w=, h= } LHAS setting objects
local originals = {}       -- row -> { min=, max=, default=, getFunction= }
local applied = false
local resizeHooked = false
local retryPending = false
local missing = nil

local function sv()
    return CC.sv
end

function V.GetEnabled()
    local s = sv()
    if s and s.fixVotansSliders ~= nil then
        return s.fixVotansSliders
    end
    return V.DEFAULT_ENABLED
end

-- -----------------------------------------------------------------------------
-- Resolution
-- -----------------------------------------------------------------------------
local function FindRows(panel)
    local found = {}
    for key, idName in pairs(ROW_IDS) do
        local id = _G[idName]
        local wanted = id and GetString(id) or nil
        if wanted then
            for _, setting in ipairs(panel.settings) do
                if setting.labelText == wanted then
                    found[key] = setting
                    break
                end
            end
        end
    end
    return found
end

local function Resolve()
    if mm and rows then
        return true
    end
    local addon = _G[ADDON_GLOBAL]
    if type(addon) ~= "table" then
        missing = ADDON_GLOBAL .. " (Votan's Minimap not installed or not loaded yet)"
        return false
    end
    local panel = addon.settingsControls
    if type(panel) ~= "table" or type(panel.settings) ~= "table" then
        missing = ADDON_GLOBAL .. ".settingsControls.settings not built yet"
        return false
    end
    if type(addon.account) ~= "table" then
        missing = ADDON_GLOBAL .. ".account missing"
        return false
    end
    local found = FindRows(panel)
    for _, key in ipairs({ "x", "y" }) do
        local row = found[key]
        if not row then
            missing = "Grid " .. key:upper() .. " row not found by label"
            return false
        end
        if type(row.min) ~= "number" or type(row.max) ~= "number" or type(row.getFunction) ~= "function" then
            missing = "Grid " .. key:upper() .. " row has an unexpected shape"
            return false
        end
    end
    mm, rows, missing = addon, found, nil
    return true
end

-- -----------------------------------------------------------------------------
-- Apply / restore
-- -----------------------------------------------------------------------------
local function Remember(row)
    if not originals[row] then
        originals[row] = { min = row.min, max = row.max, default = row.default, getFunction = row.getFunction }
    end
end

local function RoundedGetter(axis)
    return function()
        local v = tonumber(mm.account[axis]) or 0
        return zo_round(v / 8)
    end
end

-- Idempotent: rounding already-whole bounds changes nothing, the getter is
-- replaced with an equivalent one, and defaults recompute to the same value.
local function Apply()
    for _, key in ipairs({ "x", "y" }) do
        local row = rows[key]
        Remember(row)
        -- Whole-number bounds, rounded inward (cause 1).
        row.min = zo_ceil(row.min)
        row.max = zo_floor(row.max)
        -- Read-back-proof getter (cause 2).
        row.getFunction = RoundedGetter(key)
    end
    -- Defaults: flush to the right / bottom edge, from the WIDTH / HEIGHT rows
    -- (the add-on indexes the wrong rows for these).
    if rows.w and type(rows.w.default) == "number" then
        rows.x.default = zo_floor(rows.x.max - rows.w.default / 2)
    end
    if rows.h and type(rows.h.default) == "number" then
        rows.y.default = zo_floor(rows.y.max - rows.h.default / 2)
    end
    applied = true
end

local function Restore()
    if not applied then
        return
    end
    for row, saved in pairs(originals) do
        row.min, row.max, row.default, row.getFunction = saved.min, saved.max, saved.default, saved.getFunction
    end
    originals = {}
    applied = false
end

-- The minimap rewrites the bounds on this event; re-apply one frame later so
-- it cannot matter which handler the client runs first.
local function SetResizeHook(on)
    if on == resizeHooked or type(EVENT_MANAGER) ~= "table" and type(EVENT_MANAGER) ~= "userdata" then
        return
    end
    if on then
        EVENT_MANAGER:RegisterForEvent(EVENT_NS, EVENT_ALL_GUI_SCREENS_RESIZED, function()
            zo_callLater(function()
                if V.GetEnabled() and Resolve() then
                    Apply()
                end
            end, 0)
        end)
    else
        EVENT_MANAGER:UnregisterForEvent(EVENT_NS, EVENT_ALL_GUI_SCREENS_RESIZED)
    end
    resizeHooked = on
end

local function RefreshWithRetry(attemptsLeft)
    retryPending = false
    if not V.GetEnabled() then
        Restore()
        SetResizeHook(false)
        return
    end
    if Resolve() then
        Apply()
        SetResizeHook(true)
        return
    end
    if attemptsLeft > 0 and type(zo_callLater) == "function" then
        retryPending = true
        zo_callLater(function() RefreshWithRetry(attemptsLeft - 1) end, RETRY_MS)
    end
end

-- -----------------------------------------------------------------------------
-- Public surface
-- -----------------------------------------------------------------------------
function V.Refresh()
    if retryPending then
        return
    end
    RefreshWithRetry(RETRY_ATTEMPTS)
end

function V.SetEnabled(value)
    local s = sv()
    if s then
        s.fixVotansSliders = value and true or false
    end
    if not value then
        Restore()
        SetResizeHook(false)
    end
    V.Refresh()
end

function V.Init()
    V.Refresh()
end

-- For `/casualclean votan`.
function V.GetReport()
    local out = {}
    out[#out + 1] = string.format("enabled=%s resolved=%s applied=%s resizeHook=%s retryPending=%s",
        tostring(V.GetEnabled()), tostring(mm ~= nil and rows ~= nil), tostring(applied),
        tostring(resizeHooked), tostring(retryPending))
    if missing then
        out[#out + 1] = "missing: " .. missing
    end
    if mm and rows then
        out[#out + 1] = string.format("minimap version=%s account x=%s y=%s",
            tostring(mm.settingsControls and mm.settingsControls.version),
            tostring(mm.account.x), tostring(mm.account.y))
        for _, key in ipairs({ "x", "y" }) do
            local row = rows[key]
            local ok, value = pcall(row.getFunction)
            out[#out + 1] = string.format("Grid %s: min=%s max=%s default=%s step=%s getter=%s",
                key:upper(), tostring(row.min), tostring(row.max), tostring(row.default),
                tostring(row.step), ok and tostring(value) or ("error " .. tostring(value)))
        end
    end
    return out
end
