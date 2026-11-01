-- =============================================================================
-- Under Pressure -- UI/TextureGuard.lua (0.5.10)
-- =============================================================================
-- Makes an icon show even when the client refuses to load our own DDS file.
--
-- THE PROBLEM (field, 2026-10-29..31; Docs/UnderPressure.md under 0.5.10).
-- The Plague Carrier and Pull icons drew nothing on console until the game
-- was fully quit and relaunched, while the silence ring, shipped with the
-- same XML construction and the same DDS format, drew every time. Renaming
-- the icon files (0.5.7) did not help. The difference is age, not format:
-- the ring's files have been in the package since 0.2.x, so every client
-- had them on disk when it started; the icon files were ADDED (and then
-- renamed, which is adding again) by updates installed while the game was
-- already running. ESOUI has said so since 2014: "If you add any image to
-- the addons folder, it wont be loaded until you restart game client"
-- (Garkin), and "the game has an internal cache of textures (filepath/name)
-- it failed to load and reload ui doesn't clear that cache" (Mandrakia).
-- So a texture file new to the running process is dead until a restart,
-- and nothing we ship under a new name can fix that for a running client.
--
-- THE ANSWER. Textures the GAME ships are always loadable: the client has
-- had them since it started. So each icon control is watched; once its
-- display has been on screen for a moment, IsTextureLoaded() (the check
-- ZOS's own pre-login overlay and animated background use, with a timeout,
-- in preloginoverlay.lua / basebackground.lua) says whether our file
-- arrived. If it has not after a second check, the control is pointed at a
-- fallback the game owns: the ability icon of Plague Carrier / Rush of
-- Agony via GetAbilityIcon, which must exist on console for the buff bar.
-- A player on a fresh update sees the set's own icon instead of nothing;
-- after their next restart they see our art.
--
-- Checks run only after a display is shown (preview or a real event), via
-- zo_callLater, never per frame. A control that is hidden again before its
-- check (a pull warning lasts about a second) is left for the next show,
-- because a texture that was never drawn may simply not have been asked
-- for yet. Once a control is resolved (ok or fallback) it is never checked
-- again. The debug overlay prints UP.TextureGuard.Summary().
-- =============================================================================

UP = UP or {}
UP.TextureGuard = {}
local G = UP.TextureGuard

-- Delay before the first check once a display is shown, and the gap to the
-- second, decisive check. Textures stream in asynchronously; the login
-- overlay's own timeout is measured in seconds, so two checks over ~2.5 s
-- are patient without leaving a player staring at nothing for long.
local FIRST_CHECK_MS  = 600
local SECOND_CHECK_MS = 1900
-- After a fallback is applied, one more look to report whether IT loaded.
local VERIFY_MS       = 1500

-- Game-owned art for when ours is dead. Ability icons are resolved at
-- fallback time through GetAbilityIcon (never at file-parse time), with a
-- generic warning glyph behind them should an id ever stop resolving.
local GENERIC_WARNING = "EsoUI/Art/Miscellaneous/ESO_Icon_Warning.dds"
G.FALLBACK_ABILITY = {
    plague = 159612,   -- Plague Carrier (Plaguebreak)
    pull   = 159279,   -- Rush of Agony
}

-- watched[i] = { control, label, fallbackKey, status, path }
-- status: "waiting" | "ok" | "fallback" | "fallback-dead" | "missing"
local watched = {}
local pending = false

local function fileName(ctrl)
    if not (ctrl and ctrl.GetTextureFileName) then return "?" end
    local ok, name = pcall(ctrl.GetTextureFileName, ctrl)
    return (ok and type(name) == "string") and name or "?"
end

-- "Is this control actually being drawn?" IsControlHidden is true when any
-- ancestor is hidden. Without the method (a fake in a harness) assume shown.
local function drawn(ctrl)
    if not ctrl then return false end
    if ctrl.IsControlHidden then
        local ok, hidden = pcall(ctrl.IsControlHidden, ctrl)
        if ok then return not hidden end
    end
    if ctrl.IsHidden then
        local ok, hidden = pcall(ctrl.IsHidden, ctrl)
        if ok then return not hidden end
    end
    return true
end

-- "Did the texture arrive?" Loaded per the client, and with real pixel
-- dimensions when the client can say. A control without IsTextureLoaded
-- cannot be judged and is treated as fine.
local function textureLoaded(ctrl)
    if not (ctrl and ctrl.IsTextureLoaded) then return true end
    local ok, loaded = pcall(ctrl.IsTextureLoaded, ctrl)
    if not ok then return true end
    if not loaded then return false end
    if ctrl.GetTextureFileDimensions then
        local okD, w, h = pcall(ctrl.GetTextureFileDimensions, ctrl)
        if okD and type(w) == "number" and type(h) == "number" and (w <= 0 or h <= 0) then
            return false
        end
    end
    return true
end

function G.FallbackPath(key)
    local id = G.FALLBACK_ABILITY[key]
    if id and type(GetAbilityIcon) == "function" then
        local ok, icon = pcall(GetAbilityIcon, id)
        if ok and type(icon) == "string" and icon ~= "" then return icon end
    end
    return GENERIC_WARNING
end

local function applyFallback(entry)
    local path = G.FallbackPath(entry.fallbackKey)
    if not (path and entry.control and entry.control.SetTexture) then
        entry.status = "missing"
        return false
    end
    local ok = pcall(entry.control.SetTexture, entry.control, path)
    if not ok then
        entry.status = "missing"
        return false
    end
    entry.status = "fallback"
    entry.fallbackPath = path
    return true
end

local function later(fn, ms)
    if type(zo_callLater) == "function" then
        zo_callLater(fn, ms)
    else
        fn()
    end
end

-- Register a texture control. `fallbackKey` names the game-owned art to use
-- if ours never loads ("plague" / "pull"). Nil controls are ignored so
-- callers can pass GetNamedChild results straight through.
function G.Watch(control, label, fallbackKey)
    if not control then return end
    for _, e in ipairs(watched) do
        if e.control == control then return end
    end
    watched[#watched + 1] = {
        control = control, label = label or "?", fallbackKey = fallbackKey,
        status = "waiting", path = fileName(control),
    }
end

local function unresolvedShown()
    local list = {}
    for _, e in ipairs(watched) do
        if e.status == "waiting" and drawn(e.control) then list[#list + 1] = e end
    end
    return list
end

local function anyWaiting()
    for _, e in ipairs(watched) do
        if e.status == "waiting" then return true end
    end
    return false
end

-- One pass: mark what has loaded. `decide` = apply fallbacks to the rest.
local function pass(decide)
    local stillWaiting = false
    for _, e in ipairs(unresolvedShown()) do
        if textureLoaded(e.control) then
            e.status = "ok"
        elseif decide then
            if applyFallback(e) then
                local entry = e
                later(function()
                    if entry.status == "fallback" and drawn(entry.control)
                       and not textureLoaded(entry.control) then
                        entry.status = "fallback-dead"
                    end
                end, VERIFY_MS)
            end
        else
            stillWaiting = true
        end
    end
    return stillWaiting
end

-- Called by a display when it becomes visible. Idempotent and cheap: nothing
-- happens once every watched control is resolved, and only one check chain
-- runs at a time.
function G.Check()
    if pending or not anyWaiting() then return end
    pending = true
    later(function()
        local more = pass(false)
        if not more then
            pending = false
            return
        end
        later(function()
            pass(true)
            pending = false
        end, SECOND_CHECK_MS)
    end, FIRST_CHECK_MS)
end

-- "plague=ok(6)  pull=FALLBACK 6/6  callout=waiting"
function G.Summary()
    if #watched == 0 then return "textures: none watched" end
    local order, byLabel = {}, {}
    for _, e in ipairs(watched) do
        local b = byLabel[e.label]
        if not b then
            b = { total = 0, ok = 0, fallback = 0, dead = 0, missing = 0, waiting = 0 }
            byLabel[e.label] = b
            order[#order + 1] = e.label
        end
        b.total = b.total + 1
        if e.status == "ok" then b.ok = b.ok + 1
        elseif e.status == "fallback" then b.fallback = b.fallback + 1
        elseif e.status == "fallback-dead" then b.dead = b.dead + 1
        elseif e.status == "missing" then b.missing = b.missing + 1
        else b.waiting = b.waiting + 1 end
    end
    local parts = {}
    for _, label in ipairs(order) do
        local b = byLabel[label]
        local s
        if b.ok == b.total then s = ("ok(%d)"):format(b.total)
        elseif b.waiting == b.total then s = "waiting"
        else
            s = ("ok %d/%d"):format(b.ok, b.total)
            if b.fallback > 0 then s = s .. (" FALLBACK %d"):format(b.fallback) end
            if b.dead > 0 then s = s .. (" FALLBACK-DEAD %d"):format(b.dead) end
            if b.missing > 0 then s = s .. (" MISSING %d"):format(b.missing) end
            if b.waiting > 0 then s = s .. (" waiting %d"):format(b.waiting) end
        end
        parts[#parts + 1] = label .. "=" .. s
    end
    return "textures: " .. table.concat(parts, "  ")
end

-- Start over after a load screen (EVENT_PLAYER_ACTIVATED): every control goes
-- back to "waiting" and is judged afresh the next time its display is shown.
-- Matt's second observation (2026-10-31): icons that worked after a full
-- relaunch were gone again on a LATER load of the same game, so a verdict
-- of "ok" cannot be trusted across logins, suspend/resume or a mid-session
-- add-on update. A control on the fallback gets its own file back first, so
-- a file that has since become loadable (after a restart) is used again.
function G.Rearm()
    for _, e in ipairs(watched) do
        if e.status ~= "waiting" then
            if e.fallbackPath and e.path and e.path ~= "?" and e.control and e.control.SetTexture then
                pcall(e.control.SetTexture, e.control, e.path)
            end
            e.fallbackPath = nil
            e.status = "waiting"
        end
    end
    pending = false
end

local NAMESPACE = "UnderPressure_TextureGuard"
function G.Init()
    if EVENT_MANAGER and type(EVENT_PLAYER_ACTIVATED) == "number" then
        EVENT_MANAGER:RegisterForEvent(NAMESPACE, EVENT_PLAYER_ACTIVATED, function() G.Rearm() end)
    end
end

-- For the harness and the API audit.
function G.Status(label)
    local out = {}
    for _, e in ipairs(watched) do
        if label == nil or e.label == label then
            out[#out + 1] = { label = e.label, status = e.status, path = e.path, fallbackPath = e.fallbackPath }
        end
    end
    return out
end

function G._Reset()
    watched = {}
    pending = false
end
