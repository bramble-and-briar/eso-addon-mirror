-- "My target" keeps your tab target when you look away (Sazane, 5.15.x; rule by Yarden).
--
-- What the game gives addons (checked in game with /dt tabtest, three rounds):
--   * IsGameCameraPreferredTargetValid(): yes / no, "a tab target is set". Nothing says WHO it is: the unit
--     tag "target" never exists, "reticleover" is only what's under the crosshair.
--   * EVENT_TARGET_CHANGED for "player": fires when Tab picks or cycles a target (and now and then without
--     one, so it's treated as "maybe changed").
-- So the tab target can't be read; it's inferred:
--   * when a tab target gets set, it's the enemy you looked at last (under the crosshair now, or within the
--     last few seconds) -- Tab picks the enemy nearest the crosshair;
--   * when your target changes while one is set: the enemy under the crosshair at that moment; looking at
--     nothing, the lock is dropped (Tab moved to someone we can't know -- showing the old one would be wrong);
--   * the locked enemy dies, or the tab target is cleared: dropped.
-- While locked and you look away (or at another enemy), "my target" trackers show the locked enemy from the
-- effect events about it (its effects are copied from its buff list when it's locked, then kept up to date
-- by events). Nothing runs unless a "my target" tracker exists and the setting is on.

local DT = DebuffTracker
local TT = {}
DT.TabTarget = TT
local U = DT.Util

local NS = "DebuffTracker5_TabTarget"
local LAST_SEEN = 5          -- s: "the enemy you looked at last" counts this long after you looked away

TT.lock = nil                -- { id = unitId or nil (not known yet), name = clean name }
local watching = false
local wasValid = false
local last = nil             -- { id, exact, name, at }

local function TabSet()
    return type(IsGameCameraPreferredTargetValid) == "function" and IsGameCameraPreferredTargetValid() == true
end

-- the enemy under the crosshair: its unitId once the game has named it (an event tagged "reticleover")
local function Current()
    if not DoesUnitExist("reticleover") or IsUnitDead("reticleover") or not DT.Units.IsEnemyTag("reticleover") then return nil end
    local Units = DT.Units
    return { id = Units.reticleExact and Units.reticleUnitId or nil, name = U.CleanName(GetUnitName("reticleover")) }
end

local function SetLock(l, seedFromReticle)
    local old = TT.lock
    TT.lock = l
    local id = l and l.id or nil
    if (old and old.id) ~= id or seedFromReticle then
        DT.Effects.SetLock(id, seedFromReticle and id and DT.Effects.Scan("reticleover", U.Now()) or nil)
    end
    if DT.debug then U.Debug("tab target lock: %s", l and string.format("%s(%s)", tostring(l.name), tostring(l.id)) or "none") end
    if DT.Engine and DT.Engine.RequestUpdate then DT.Engine.RequestUpdate() end
end

-- a tab target was set or changed: lock the enemy under the crosshair, else (only when it was just set)
-- the one looked at last
local function Pick(justSet, now)
    local cur = Current()
    if cur then SetLock(cur, cur.id ~= nil); return end
    if justSet and last and now - last.at <= LAST_SEEN then
        SetLock({ id = last.id, name = last.name }, false)
        return
    end
    SetLock(nil)
end

local function OnTargetChanged()
    if not watching or not TabSet() then return end
    wasValid = true
    Pick(false, U.Now())
end

-- every engine update while watched
function TT.Poll(now)
    if not watching then return end
    local cur = Current()
    if cur then
        last = last or {}
        last.id, last.name, last.at = cur.id, cur.name, now
    end
    if not TabSet() then
        wasValid = false
        if TT.lock then SetLock(nil) end
        return
    end
    if not wasValid then
        wasValid = true
        Pick(true, now)
        return
    end
    local l = TT.lock
    if not l then return end
    if l.id and DT.Effects.died[l.id] then SetLock(nil); return end
    -- locked by name before the game named its unitId: filled in once it does, while you look at it
    if not l.id and cur and cur.id and cur.name == l.name then SetLock({ id = cur.id, name = cur.name }, true) end
end

-- Is the crosshair on the locked enemy? (then its own buff list is read, as always)
function TT.ReticleIsLock()
    local l = TT.lock
    if not l or not DoesUnitExist("reticleover") then return false end
    local Units = DT.Units
    if Units.reticleExact and Units.reticleUnitId then return Units.reticleUnitId == l.id end
    return U.CleanName(GetUnitName("reticleover")) == l.name     -- not named yet: same name
end

-- on while a "my target" tracker exists and the setting allows it
function TT.SetWatched(on)
    on = on == true
    if on == watching then return end
    watching = on
    if on then
        if EVENT_TARGET_CHANGED then
            EVENT_MANAGER:RegisterForEvent(NS, EVENT_TARGET_CHANGED, OnTargetChanged)
            EVENT_MANAGER:AddFilterForEvent(NS, EVENT_TARGET_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
        end
    else
        if EVENT_TARGET_CHANGED then EVENT_MANAGER:UnregisterForEvent(NS, EVENT_TARGET_CHANGED) end
        wasValid, last = false, nil
        if TT.lock then SetLock(nil) end
    end
end

function TT.IsWatched() return watching end

-- loading screen: every unitId belongs to the previous area
function TT.Reset()
    wasValid, last = false, nil
    if TT.lock then SetLock(nil) end
end
