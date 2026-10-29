-- =============================================================================
-- CasualClean -- UI/QuestTracker.lua
-- =============================================================================
-- "Show <tracker> only in the menu": hides a ZOS HUD tracker during play and
-- shows it on the gamepad Main Menu root and its sub-list instead. Two tracker
-- GROUPS are handled, each with its own setting:
--
--   quest    FOCUSED_QUEST_TRACKER_FRAGMENT + ZONE_STORY_TRACKER_FRAGMENT
--            (the game swaps the second in for the first while a zone story is
--            assisted, so hiding only one would leave the other on the HUD)
--   pursuit  TIMED_ACTIVITY_TRACKER_FRAGMENT + ACHIEVEMENT_TRACKER_FRAGMENT
--            (ZOS's "Aspiration" tracker: ONE control that shows a Golden
--            Pursuit or an Endeavor depending on which is assisted -- so this
--            setting necessarily covers both -- plus the achievement tracker
--            linked beneath it the same way zone story is linked to quests)
--
-- Plus the PEEK (see its own section below): while trackers are hidden, the
-- first press of the assist button shows them for a few seconds instead of
-- silently changing the tracked quest.
--
-- NOTHING IS DRAWN HERE. No controls, no XML, no fonts, no textures. The
-- tracker shown in the menu is ZOS's own, in its own position, with its own
-- styling. All this module does is drive two things ZOS already exposes:
--
--   1. Scene membership. A fragment is drawn only in scenes that contain it
--      (ZO_SceneFragment:ComputeIfFragmentShouldShow). The tracker fragments
--      belong to the HUD scenes; this module also adds them to
--      MAIN_MENU_GAMEPAD_SCENE and PLAYER_SUBMENU_SCENE. ZO_Scene:AddFragment
--      is public and idempotent.
--   2. Hidden reasons. ZO_HUDFadeSceneFragment mixes in
--      ZO_HideableSceneFragmentMixin, so SetHiddenForReason(reason, hidden)
--      keeps the fragment hidden while any reason is set. ZOS uses it for
--      "NoTrackedQuests", "DisabledBySetting", "TrackingZoneStory",
--      "NotAssisted" and so on; this module adds one reason of its own and
--      flips it on scene transitions. HUD_TRACKER_MANAGER:RefreshLayout hides
--      the tracker CONTROL whenever its fragment is hidden for any reason
--      (ZO_HUDTracker_Base:IsActive), and the fragment's OnShowing/OnHidden
--      re-run RefreshLayout, so control and fragment stay in step without any
--      help from here.
--
-- This is the same shape as the companion-frame hiding in CasualClean.lua
-- (SetHiddenForReason) and the default-bar hiding in UI/MagStamArcs.lua: a
-- ZOS-provided hook, applied with a reason that is ours, and cleared to
-- restore stock behaviour exactly.
--
-- WHY NOT SetSetting. The game's own "Show quest tracker" option would hide
-- that tracker everywhere, menu included, via the "DisabledBySetting" reason,
-- and the workspace records SetSetting as console-private, so the add-on could
-- not flip it back for the menu anyway. The native setting must stay ON; if a
-- user has it off the quest group is a harmless no-op, which the settings
-- tooltip says. (The pursuit tracker has no native show/hide setting at all.)
--
-- THE NO-BLINK RULE. Moving from the menu root to its sub-list is a scene
-- change (root HIDING, sub-list SHOWING). Deciding "in the menu?" from the
-- current scene alone would set the reason during HIDING and clear it again a
-- moment later -- a visible blink. So the decision looks at
-- SCENE_MANAGER:GetNextScene() first and falls back to the current scene,
-- which is exactly how ComputeIfFragmentShouldShow itself treats transitions.
--
-- CONSOLE SURFACES NO ERRORS, so every first-party global is looked up by name
-- at Init and recorded as found or missing. A renamed global degrades to
-- "stock tracker, feature inert" for that fragment and shows up in
-- `/casualclean tracker`, rather than killing the add-on.
-- =============================================================================

CasualClean = CasualClean or {}
local CC = CasualClean
CC.QuestTracker = {}
local Q = CC.QuestTracker

-- Unique to this add-on; the reason string is the key in the fragment's
-- ZO_HiddenReasons set, so it must not collide with ZOS's own.
local REASON = "CasualCleanMenuOnly"
-- Hide instantly (0 ms) so the HUD is clean the moment the menu closes; show
-- with the fragment's own default fade (nil = DEFAULT_HUD_DURATION), which is
-- what the trackers do on the HUD.
local SHOW_MS, HIDE_MS = nil, 0

-- Root menu and its sub-list only, by decision: deeper screens (Inventory,
-- Journal, ...) put their own panels in quadrant 4 where the trackers sit.
local SCENE_NAMES = { "MAIN_MENU_GAMEPAD_SCENE", "PLAYER_SUBMENU_SCENE" }

-- Ordered so the settings panel and the report list them the same way. `key`
-- is what the public API takes; `svKey` is the SavedVariables field.
Q.GROUPS = {
    {
        key = "quest", svKey = "questTrackerInMenu", label = "quest tracker",
        names = { "FOCUSED_QUEST_TRACKER_FRAGMENT", "ZONE_STORY_TRACKER_FRAGMENT" },
    },
    {
        key = "pursuit", svKey = "pursuitTrackerInMenu", label = "Golden Pursuit tracker",
        names = { "TIMED_ACTIVITY_TRACKER_FRAGMENT", "ACHIEVEMENT_TRACKER_FRAGMENT" },
    },
}

-- Peek bounds. Short enough to read the tracker and look away; long enough
-- that a second press to advance the quest lands while it is still visible.
Q.PEEK_SECONDS_MIN = 2
Q.PEEK_SECONDS_MAX = 15

-- Groups off by default: 1.5.0 is published, and nobody's HUD should change
-- until they opt in. The peek defaults ON because it only ever acts while a
-- group is hidden, and without it the assist button would change the tracked
-- quest with nothing on screen to show it happened. Spread into the
-- ZO_SavedVars defaults by CasualClean.lua.
Q.DEFAULTS = { trackerPeek = true, trackerPeekSeconds = 5 }
for _, group in ipairs(Q.GROUPS) do
    Q.DEFAULTS[group.svKey] = false
end

local groupsByKey = {}  -- key -> group (same tables as Q.GROUPS)
local scenes = {}       -- { { name=, scene= }, ... } resolved at Init
local missing = {}      -- names that did not resolve, for the report
local usable = false    -- both scenes and SCENE_MANAGER resolved
local callbacksOn = false
local callbacks = {}    -- scene -> the function registered on it, for unregistering

local function sv()
    return CC.sv
end

local function Setting(key)
    local s = sv()
    if s and s[key] ~= nil then
        return s[key]
    end
    return Q.DEFAULTS[key]
end

-- -----------------------------------------------------------------------------
-- Resolution
-- -----------------------------------------------------------------------------
local function Resolve()
    scenes, missing, groupsByKey = {}, {}, {}
    for _, group in ipairs(Q.GROUPS) do
        groupsByKey[group.key] = group
        group.fragments = {}   -- { { name=, fragment= }, ... }
        group.member = false   -- fragments currently added to the menu scenes
        for _, name in ipairs(group.names) do
            local f = _G[name]
            if type(f) == "table" and type(f.SetHiddenForReason) == "function" then
                group.fragments[#group.fragments + 1] = { name = name, fragment = f }
            else
                missing[#missing + 1] = name
            end
        end
    end
    for _, name in ipairs(SCENE_NAMES) do
        local s = _G[name]
        if type(s) == "table" and type(s.AddFragment) == "function" and type(s.RegisterCallback) == "function" then
            scenes[#scenes + 1] = { name = name, scene = s }
        else
            missing[#missing + 1] = name
        end
    end
    local manager = _G["SCENE_MANAGER"]
    local haveManager = type(manager) == "table" and type(manager.GetCurrentScene) == "function"
        and type(manager.GetNextScene) == "function"
    if not haveManager then
        missing[#missing + 1] = "SCENE_MANAGER"
    end
    usable = haveManager and #scenes == #SCENE_NAMES
    return usable
end

-- -----------------------------------------------------------------------------
-- The decision
-- -----------------------------------------------------------------------------
local peeking = false   -- a peek is in progress (see the PEEK section)

local function IsMenuScene(scene)
    for _, entry in ipairs(scenes) do
        if entry.scene == scene then
            return true
        end
    end
    return false
end

-- Next scene first, current scene second: see THE NO-BLINK RULE above.
local function InMenu()
    local target = SCENE_MANAGER:GetNextScene() or SCENE_MANAGER:GetCurrentScene()
    return target ~= nil and IsMenuScene(target)
end

local function ShouldShow()
    return peeking or InMenu()
end

local function GroupEnabled(group)
    return Setting(group.svKey) and true or false
end

local function AnyGroupMember()
    for _, group in ipairs(Q.GROUPS) do
        if group.member then
            return true
        end
    end
    return false
end

local function ApplyReason()
    local hidden = not ShouldShow()
    for _, group in ipairs(Q.GROUPS) do
        if group.member then
            for _, entry in ipairs(group.fragments) do
                entry.fragment:SetHiddenForReason(REASON, hidden, SHOW_MS, HIDE_MS)
            end
        end
    end
end

-- -----------------------------------------------------------------------------
-- Hook / unhook
-- -----------------------------------------------------------------------------
-- One callback per menu scene, shared by every enabled group. Registered when
-- the first group turns on and removed when the last turns off.
local function SetCallbacks(on)
    if on == callbacksOn then
        return
    end
    for _, sceneEntry in ipairs(scenes) do
        local scene = sceneEntry.scene
        if on then
            -- The closure is kept so the same reference can be unregistered.
            -- Its (oldState, newState) arguments are not needed: the decision
            -- re-reads the scene manager every time.
            local fn = function() ApplyReason() end
            scene:RegisterCallback("StateChange", fn)
            callbacks[scene] = fn
        elseif callbacks[scene] then
            scene:UnregisterCallback("StateChange", callbacks[scene])
            callbacks[scene] = nil
        end
    end
    callbacksOn = on
end

local function JoinMenuScenes(group)
    if group.member then
        return
    end
    for _, sceneEntry in ipairs(scenes) do
        for _, entry in ipairs(group.fragments) do
            sceneEntry.scene:AddFragment(entry.fragment)
        end
    end
    group.member = true
end

-- Exact restore of stock behaviour for one group. Order matters slightly:
-- the fragments leave the menu scenes BEFORE the reason is cleared, so
-- clearing it cannot flash a tracker up in a menu that is open at the time.
local function LeaveMenuScenes(group)
    if not group.member then
        return
    end
    for _, sceneEntry in ipairs(scenes) do
        for _, entry in ipairs(group.fragments) do
            sceneEntry.scene:RemoveFragment(entry.fragment)
        end
    end
    for _, entry in ipairs(group.fragments) do
        entry.fragment:SetHiddenForReason(REASON, false, SHOW_MS, HIDE_MS)
    end
    group.member = false
end

-- -----------------------------------------------------------------------------
-- PEEK: the assist button shows hidden trackers before it changes anything
-- -----------------------------------------------------------------------------
-- The assist button (d-pad right by default on gamepad) is the only caller of
-- HUD_TRACKER_MANAGER:BeginAssistInteract / EndAssistInteract
-- (esoui/ingame/globals/bindings.xml, action ASSIST_NEXT_TRACKED_QUEST):
--
--     press   -> BeginAssistInteract: starts a 200-500 ms repeating timer that
--                cycles the Golden Pursuit / Endeavor / achievement tracker
--                while the button is HELD
--     release -> EndAssistInteract: cancels that timer, and if it never fired
--                (a short press) calls FOCUSED_QUEST_TRACKER:AssistNext()
--
-- With a tracker hidden, a short press would change the tracked quest with
-- nothing on screen to show it. So, while a menu-only group is hidden:
--
--     first press   is SWALLOWED (ZO_PreHook returning true skips ZOS's
--                   handler entirely) and starts a peek: the hidden trackers
--                   appear for `trackerPeekSeconds`, and nothing is changed
--     later presses while the peek is visible pass through untouched, so the
--                   quest advances (or a hold cycles) exactly as stock, and
--                   the peek timer restarts so the new quest is seen too
--
-- THE PAIRING RULE. Press and release must be swallowed as a pair. Swallowing
-- the press means ZOS never starts its hold timer, so there is nothing for the
-- release to cancel -- but a release that reaches ZOS without its press would
-- call AssistNext anyway, because the "already cycled" flag it checks is
-- unset. So a swallowed press records that the matching release is to be
-- swallowed too. The cost: on that one press, holding cannot cycle the
-- aspiration tracker. The second press does everything as before, and gamepad
-- mode also has the separate GAMEPAD_CYCLE_PINNED_HUD_ACTION binding.
--
-- The hooks go on the CLASS (ZO_HUDTracker_Manager), not the instance, per
-- ESOUI's hooking guidance, and are installed once: ZO_PreHook has no undo,
-- so the setting is honoured inside the hook rather than by removing it.
local hooksInstalled = false
local swallowRelease = false
local peekTimer = nil        -- zo_callLater id while a peek is running

local function PeekSeconds()
    local seconds = tonumber(Setting("trackerPeekSeconds")) or Q.DEFAULTS.trackerPeekSeconds
    if seconds < Q.PEEK_SECONDS_MIN then seconds = Q.PEEK_SECONDS_MIN end
    if seconds > Q.PEEK_SECONDS_MAX then seconds = Q.PEEK_SECONDS_MAX end
    return seconds
end

local function EndPeek()
    if peekTimer then
        zo_removeCallLater(peekTimer)
        peekTimer = nil
    end
    if peeking then
        peeking = false
        ApplyReason()
    end
end

-- Starting an already-running peek just restarts the clock.
local function StartPeek()
    if peekTimer then
        zo_removeCallLater(peekTimer)
    end
    peekTimer = zo_callLater(function()
        peekTimer = nil
        EndPeek()
    end, PeekSeconds() * 1000)
    if not peeking then
        peeking = true
        ApplyReason()
    end
end

-- True exactly when a press should be turned into a peek: the feature is on,
-- some group is actually hidden by us right now, and nothing is already
-- showing it (menu or a running peek).
local function PressShouldPeek()
    return Setting("trackerPeek") and usable and AnyGroupMember() and not ShouldShow()
end

local function OnAssistPress()
    if not PressShouldPeek() then
        return false            -- pass through to ZOS
    end
    swallowRelease = true
    StartPeek()
    return true                 -- handled: ZOS's BeginAssistInteract is skipped
end

local function OnAssistRelease()
    if swallowRelease then
        swallowRelease = false
        return true             -- the matching release of a swallowed press
    end
    if peeking then
        -- A real press during the peek: let ZOS act on it, and keep the
        -- trackers up long enough to see what it did.
        StartPeek()
    end
    return false
end

local function InstallHooks()
    if hooksInstalled then
        return
    end
    local class = _G["ZO_HUDTracker_Manager"]
    local ok = type(ZO_PreHook) == "function" and type(zo_callLater) == "function"
        and type(zo_removeCallLater) == "function"
        and type(class) == "table" and type(class.BeginAssistInteract) == "function"
        and type(class.EndAssistInteract) == "function"
    if not ok then
        missing[#missing + 1] = "ZO_HUDTracker_Manager.BeginAssistInteract/EndAssistInteract"
        return
    end
    ZO_PreHook(class, "BeginAssistInteract", OnAssistPress)
    ZO_PreHook(class, "EndAssistInteract", OnAssistRelease)
    hooksInstalled = true
end

-- -----------------------------------------------------------------------------
-- Public surface
-- -----------------------------------------------------------------------------
function Q.GetEnabled(key)
    local group = groupsByKey[key]
    if not group then
        return false
    end
    return GroupEnabled(group)
end

function Q.GetPeekEnabled()
    return Setting("trackerPeek") and true or false
end

function Q.GetPeekSeconds()
    return PeekSeconds()
end

-- Idempotent, and cheap enough to re-run from every RefreshState: joins and
-- leaves early-out when already in the requested state, and re-applying the
-- reason is one table write per fragment.
function Q.Refresh()
    if not usable then
        return
    end
    local anyOn = false
    for _, group in ipairs(Q.GROUPS) do
        if GroupEnabled(group) and #group.fragments > 0 then
            JoinMenuScenes(group)
            anyOn = true
        else
            LeaveMenuScenes(group)
        end
    end
    SetCallbacks(anyOn)
    if anyOn then
        ApplyReason()
    else
        -- Nothing hidden by us, so nothing to peek at; drop any running timer
        -- rather than let it fire into a state it no longer describes.
        EndPeek()
    end
end

function Q.SetEnabled(key, value)
    local group = groupsByKey[key]
    local s = sv()
    if group and s then
        s[group.svKey] = value and true or false
    end
    Q.Refresh()
end

function Q.SetPeekEnabled(value)
    local s = sv()
    if s then
        s.trackerPeek = value and true or false
    end
    if not value then
        EndPeek()
    end
end

function Q.SetPeekSeconds(value)
    local s = sv()
    if s then
        s.trackerPeekSeconds = tonumber(value) or Q.DEFAULTS.trackerPeekSeconds
    end
end

function Q.Init()
    Resolve()
    InstallHooks()
    Q.Refresh()
end

-- For `/casualclean tracker`. Every line is a fact the player cannot otherwise
-- see on console: whether the globals resolved, which reasons are set, and
-- where the fragments currently live.
function Q.GetReport()
    local out = {}
    out[#out + 1] = string.format("usable=%s callbacks=%s peek=%s/%ds hooks=%s peeking=%s",
        tostring(usable), tostring(callbacksOn), tostring(Q.GetPeekEnabled()), PeekSeconds(),
        tostring(hooksInstalled), tostring(peeking))
    if #missing > 0 then
        out[#out + 1] = "missing globals: " .. table.concat(missing, ", ")
    end
    if usable then
        local current = SCENE_MANAGER:GetCurrentScene()
        local nextScene = SCENE_MANAGER:GetNextScene()
        out[#out + 1] = string.format("scene current=%s next=%s inMenu=%s",
            current and current.GetName and current:GetName() or "nil",
            nextScene and nextScene.GetName and nextScene:GetName() or "nil",
            tostring(InMenu()))
    end
    for _, group in ipairs(Q.GROUPS) do
        out[#out + 1] = string.format("%s: enabled=%s member=%s",
            group.key, tostring(GroupEnabled(group)), tostring(group.member))
        for _, entry in ipairs(group.fragments or {}) do
            local f = entry.fragment
            local membership = {}
            for _, sceneEntry in ipairs(scenes) do
                local has = sceneEntry.scene.HasFragment and sceneEntry.scene:HasFragment(f)
                membership[#membership + 1] = string.format("%s=%s", sceneEntry.name, tostring(has))
            end
            out[#out + 1] = string.format("  %s: ourReason=%s anyReason=%s %s",
                entry.name,
                tostring(f.IsHiddenForReason and f:IsHiddenForReason(REASON)),
                tostring(f.IsHiddenForAnyReason and f:IsHiddenForAnyReason()),
                table.concat(membership, " "))
        end
    end
    return out
end
