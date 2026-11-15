-- Red arrow over enemies you're in combat with.
--
-- The game draws a floating marker over every enemy that's fighting you (the "aggro" map pin type);
-- addons can only change its texture and size with SetFloatingMarkerInfo. That call is shared by the
-- whole UI, and when two addons call it (Untaunted, Fancy Action Bar+, older DebuffTracker...) the
-- game can crash to desktop -- not always, often on /reloadui, which made it very hard to pin down
-- (FancyActionBarPlus issue #42; DebuffTracker 1.x removed its marker for that reason).
--
-- So this is built to never be the second caller:
--   * off by default;
--   * never called while an addon known to set this marker is enabled (Untaunted, Fancy Action Bar+);
--   * a shared flag: _G.FLOATING_MARKER_OWNERS[MAP_PIN_TYPE_AGGRO] names the addon that set it --
--     we set it when we call and never call if someone else's name is in it (other authors can
--     check the same flag);
--   * a pass-through pre-hook notices any other addon calling SetFloatingMarkerInfo for the aggro
--     marker, after which we never call it again this session;
--   * called ONCE per session, a few seconds after the loading screen (after every addon's own
--     start-up), and size changes are debounced -- nothing calls it repeatedly;
--   * turning it off doesn't call anything (the game's own arrow comes back after /reloadui).

local DT = DebuffTracker
local M = DT.Marker
local L = DT.L

local NAME = "DebuffTracker"
local TEXTURE = "DebuffTracker/icons/redarrow.dds"
local START_DELAY_MS = 3000
local DEBOUNCE_MS = 800

-- add-on folder names known to set the aggro marker themselves
M.KNOWN_USERS = { "Untaunted", "FancyActionBar+" }

M.applied = false         -- we've set it this session
M.otherCaller = nil       -- name / "another add-on" once someone else set it
M.reason = nil            -- why it's not active (for the settings page)
local ownCall = false
local hooked = false
local pending = false

function M.Available()
    return type(SetFloatingMarkerInfo) == "function" and MAP_PIN_TYPE_AGGRO ~= nil
end

local function Owners()
    local owners = rawget(_G, "FLOATING_MARKER_OWNERS")
    if type(owners) ~= "table" then
        owners = {}
        _G.FLOATING_MARKER_OWNERS = owners
    end
    return owners
end

-- Notice other add-ons setting the aggro marker (never blocks or changes their call).
function M.InstallHook()
    if hooked or not M.Available() or type(ZO_PreHook) ~= "function" then return end
    hooked = true
    ZO_PreHook("SetFloatingMarkerInfo", function(markerType, _, primaryTexture)
        -- the game's own UI sets its default markers (its art lives under EsoUI/): that's not an add-on
        local zos = type(primaryTexture) == "string" and primaryTexture:lower():sub(1, 6) == "esoui/"
        if markerType == MAP_PIN_TYPE_AGGRO and not ownCall and not zos then
            local first = not M.otherCaller
            M.otherCaller = M.otherCaller or L("another add-on")
            M.reason = L("Another add-on set the enemy marker this session.")
            if first and M.applied then
                -- it set it after us: warn once, the user should keep only one of them
                zo_callLater(function()
                    DT.Util.Print(L("Another add-on also sets the enemy marker (the red arrow). Two add-ons doing that can crash the game: turn it off in one of them (DebuffTracker: Settings > Enemy marker)."))
                end, 500)
            end
        end
        return false
    end)
end

-- enabled add-ons from the known list (by folder name)
function M.KnownUsersEnabled()
    local found = {}
    local mgr = type(GetAddOnManager) == "function" and GetAddOnManager()
    if not mgr or not mgr.GetNumAddOns then return found end
    local want = {}
    for _, n in ipairs(M.KNOWN_USERS) do want[n] = true end
    local ok = pcall(function()
        for i = 1, mgr:GetNumAddOns() do
            local name, _, _, _, enabled, state = mgr:GetAddOnInfo(i)
            local running = enabled and (ADDON_STATE_ENABLED == nil or state == nil or state == ADDON_STATE_ENABLED)
            if want[name] and running then found[#found + 1] = name end
        end
    end)
    if not ok then return {} end
    return found
end

-- Is it safe for us to set the marker right now? Returns ok, reason.
function M.Check()
    if not M.Available() then return false, L("This game version has no enemy marker API.") end
    if M.otherCaller then return false, L("Another add-on set the enemy marker this session.") end
    local owner = Owners()[MAP_PIN_TYPE_AGGRO]
    if owner and owner ~= NAME then return false, L("<<1>> set the enemy marker.", tostring(owner)) end
    local known = M.KnownUsersEnabled()
    if #known > 0 then
        return false, L("<<1>> can set the same marker; two add-ons doing it can crash the game. Use theirs, or disable it there and here it turns on after /reloadui.", table.concat(known, ", "))
    end
    return true
end

local function Size()
    return math.floor(DT.Util.Clamp(tonumber(DT.Profiles.Settings().enemyMarkerSize) or 32, 12, 96) + 0.5)
end

local function Apply()
    local ok, reason = M.Check()
    if not ok then M.reason = reason return false end
    Owners()[MAP_PIN_TYPE_AGGRO] = NAME
    ownCall = true
    local fine = pcall(SetFloatingMarkerInfo, MAP_PIN_TYPE_AGGRO, Size(), TEXTURE, "", true, false)
    ownCall = false
    if fine then
        M.applied = true
        M.reason = nil
    end
    return fine
end

-- After a loading screen, a few seconds later: every add-on (and the game's own UI, which sets its
-- default markers when you arrive) has run its start-up by then. Once per loading screen, like every
-- add-on with this feature -- never repeatedly.
function M.OnActivated()
    if not DT.Profiles.Settings().enemyMarker then
        M.reason = L("Off.")
        return
    end
    zo_callLater(function()
        if DT.Profiles.Settings().enemyMarker then Apply() end
    end, START_DELAY_MS)
end

-- Settings changed (toggle / size). Turning it on mid-session applies once (debounced); turning it
-- off calls nothing and is undone by the next /reloadui.
function M.SettingsChanged()
    if not DT.Profiles.Settings().enemyMarker then
        M.reason = M.applied and L("Off after the next /reloadui.") or L("Off.")
        return
    end
    if pending then return end
    pending = true
    zo_callLater(function()
        pending = false
        if DT.Profiles.Settings().enemyMarker then Apply() end
    end, DEBOUNCE_MS)
end

function M.Status()
    if not M.Available() then return L("Not available in this game version.") end
    local s = DT.Profiles.Settings()
    if M.otherCaller then
        return "|cE0A060" .. L("Another add-on set the enemy marker this session, so DebuffTracker leaves it alone.") .. "|r"
    end
    if M.applied and s.enemyMarker then return L("|c7FD07FActive.|r") end
    if M.applied and not s.enemyMarker then return L("Off after the next /reloadui.") end
    if not s.enemyMarker then return L("Off.") end
    local ok, reason = M.Check()
    if not ok then return "|cE0A060" .. reason .. "|r" end
    return M.reason or L("Turns on a few seconds after the loading screen.")
end

-- at load: notice add-ons that set the marker during their own start-up after us
M.InstallHook()
