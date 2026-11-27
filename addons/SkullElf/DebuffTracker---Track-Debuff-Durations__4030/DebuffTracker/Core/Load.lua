-- Load conditions: whether a tracker exists right now (combat, zone, role, class, group, boss
-- fight, equipped set, character). An unloaded tracker costs nothing but this check.

local DT = DebuffTracker
local Load = DT.Load
local C = DT.Const
local U = DT.Util

Load.zone = { type = "overland", id = 0 }

function Load.ClassifyZone()
    local zoneId = GetZoneId(GetUnitZoneIndex("player")) or 0
    local zoneType = "overland"
    if type(GetCurrentZoneHouseId) == "function" and (GetCurrentZoneHouseId() or 0) ~= 0 then
        zoneType = "house"
    elseif (type(IsPlayerInAvAWorld) == "function" and IsPlayerInAvAWorld())
        or (type(IsActiveWorldBattleground) == "function" and IsActiveWorldBattleground()) then
        zoneType = "pvp"
    elseif C.TRIAL_ZONES[zoneId]
        or (type(GetCurrentParticipatingRaidId) == "function" and (GetCurrentParticipatingRaidId() or 0) > 0) then
        zoneType = "trial"
    elseif C.GROUP_ZONES[zoneId] or (type(GetCurrentZoneDungeonDifficulty) == "function" and DUNGEON_DIFFICULTY_NONE ~= nil
        and GetCurrentZoneDungeonDifficulty() ~= DUNGEON_DIFFICULTY_NONE) then
        zoneType = "dungeon"
    elseif type(IsUnitInDungeon) == "function" and IsUnitInDungeon("player") then
        zoneType = "delve"
    end
    Load.zone = { type = zoneType, id = zoneId }
    return Load.zone
end

local function Role()
    if type(GetSelectedLFGRole) ~= "function" then return "dps" end
    local r = GetSelectedLFGRole()
    if r == LFG_ROLE_TANK then return "tank" end
    if r == LFG_ROLE_HEAL then return "healer" end
    return "dps"
end

-- Slotted skills on both bars (for "only with this skill slotted"); rebuilt when the bars change.
Load.slotted = { ids = {}, names = {} }
local slotsDirty = true
function Load.MarkSlotsDirty() slotsDirty = true end

function Load.Slotted()
    if not slotsDirty then return Load.slotted end
    slotsDirty = false
    local ids, names = {}, {}
    local function AddName(n)
        n = U.Lower(U.CleanName(n or ""))
        if n ~= "" then names[#names + 1] = n end
    end
    if type(GetSlotBoundId) == "function" then
        local bars = { HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }
        -- in werewolf form your bar IS the werewolf bar (Tony: "never with <werewolf skill>" -- HyperTools' "!")
        if HOTBAR_CATEGORY_WEREWOLF and type(IsWerewolf) == "function" and IsWerewolf() then bars[#bars + 1] = HOTBAR_CATEGORY_WEREWOLF end
        for _, cat in ipairs(bars) do
            for slot = 3, 8 do      -- 3-7 skills, 8 ultimate
                local id = GetSlotBoundId(slot, cat)
                if id and id > 0 then
                    -- A scribed skill's slot holds a CRAFTED ability ID (a small number of its own), not
                    -- an ability ID: the real one -- with your scripts -- comes from
                    -- GetAbilityIdForCraftedAbilityId. Its grimoire's base ability counts too, and every
                    -- name it goes by ("Soul Burst", the scripted name).
                    if ACTION_TYPE_CRAFTED_ABILITY and type(GetSlotType) == "function"
                        and GetSlotType(slot, cat) == ACTION_TYPE_CRAFTED_ABILITY then
                        local crafted = id
                        ids[crafted] = true
                        if type(GetCraftedAbilityDisplayName) == "function" then AddName(GetCraftedAbilityDisplayName(crafted)) end
                        if type(GetCraftedAbilityRepresentativeAbilityId) == "function" then
                            local base = GetCraftedAbilityRepresentativeAbilityId(crafted)
                            if base and base > 0 then ids[base] = true; AddName(GetAbilityName(base)) end
                        end
                        id = type(GetAbilityIdForCraftedAbilityId) == "function" and GetAbilityIdForCraftedAbilityId(crafted) or 0
                    end
                    if id and id > 0 then
                        ids[id] = true
                        AddName(GetAbilityName(id))
                        -- a "chaining" skill turns into another ability in its slot after the cast (Stone Giant ->
                        -- its projectile 133027): the slot still holds the first ability; what it is NOW is the
                        -- effective one (esoui playerskillsdata.lua ZO_ActiveSkillProgressionData:GetEffectiveAbilityId;
                        -- OmniAura and Fancy Action Bar+ read it the same way). HangryGinger: the Stagger icon stayed
                        -- grey after casting Stone Giant -- only the slot's own ability was looked at.
                        if type(GetEffectiveAbilityIdForAbilityOnHotbar) == "function" then
                            local eff = GetEffectiveAbilityIdForAbilityOnHotbar(id, cat)
                            if eff and eff > 0 and eff ~= id then
                                ids[eff] = true
                                AddName(GetAbilityName(eff))
                            end
                        end
                    end
                    if type(GetSlotName) == "function" then AddName(GetSlotName(slot, cat)) end
                end
            end
        end
    end
    Load.slotted = { ids = ids, names = names }
    return Load.slotted
end

-- Is this ability (ID or name, either bar) on my action bars right now? (rule "Ability on my bars")
function Load.IsOnBar(what)
    local sl = Load.Slotted()
    local id = tonumber(what)
    if id then return sl.ids[math.floor(id)] == true end
    local want = U.Lower(U.Trim(tostring(what or "")))
    if want == "" then return false end
    for _, have in ipairs(sl.names) do
        if have:find(want, 1, true) then return true end
    end
    return false
end

-- Champion skills slotted on the champion bar ([championSkillId] = true)
local cpSlotted, cpDirty = {}, true
function Load.ChampionSlotted()
    if not cpDirty then return cpSlotted end
    cpDirty = false
    local out = {}
    if type(GetSlotBoundId) == "function" and HOTBAR_CATEGORY_CHAMPION then
        for slot = 1, 12 do
            local id = GetSlotBoundId(slot, HOTBAR_CATEGORY_CHAMPION)
            if id and id > 0 then out[id] = true end
        end
    end
    cpSlotted = out
    return out
end

-- A chaining skill ending (projectiles used, timed out) changes the slot's effective ability without a slot update:
-- its state update says so. It fires often, so it's listened to only while a tracker looks at what's on the bars
-- (rule "Ability on my bars", Load "skills slotted").
local chainWatch = false
function Load.SetChainWatch(on)
    on = on == true
    if on == chainWatch or not EVENT_ACTION_SLOT_STATE_UPDATED then return end
    chainWatch = on
    if on then
        EVENT_MANAGER:RegisterForEvent("DebuffTracker5_SlotState", EVENT_ACTION_SLOT_STATE_UPDATED, function()
            slotsDirty = true
            DT.Engine.RequestUpdate()
        end)
    else
        EVENT_MANAGER:UnregisterForEvent("DebuffTracker5_SlotState", EVENT_ACTION_SLOT_STATE_UPDATED)
    end
end

function Load.InitializeSlots()
    local function Dirty()
        slotsDirty = true
        if DT.Engine.StandingChanged then DT.Engine.StandingChanged() end
        DT.Engine.RequestUpdate()
    end
    -- by name: a list of constants stops at the first one this client doesn't have (ipairs ends at nil)
    for i, name in ipairs({ "EVENT_ACTION_SLOT_UPDATED", "EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED",
            "EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED", "EVENT_ACTIVE_WEAPON_PAIR_CHANGED", "EVENT_SKILL_RESPEC_RESULT",
            "EVENT_WEREWOLF_STATE_CHANGED" }) do
        local ev = _G[name]
        if ev then EVENT_MANAGER:RegisterForEvent("DebuffTracker5_Slots" .. i, ev, Dirty) end
    end
    local function ChampionChanged()
        cpDirty = true
        if DT.Engine.StandingChanged then DT.Engine.StandingChanged() end
        if DT.Procs.OnLoadoutChanged then DT.Procs.OnLoadoutChanged() end
        DT.Engine.RequestUpdate()
    end
    for i, name in ipairs({ "EVENT_CHAMPION_PURCHASE_RESULT", "EVENT_PLAYER_ACTIVATED", "EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED" }) do
        local ev = _G[name]
        if ev then EVENT_MANAGER:RegisterForEvent("DebuffTracker5_Champion" .. i, ev, ChampionChanged) end
    end
end

-- lowercase names of the bosses present (computed once per tick, only when a tracker asks)
local function BossNames(ctx)
    if ctx.bossNames then return ctx.bossNames end
    local names = {}
    for _, tag in ipairs(DT.Units.BossTags()) do names[#names + 1] = U.Lower(U.CleanName(GetUnitName(tag))) end
    ctx.bossNames = names
    return names
end

-- The game's combat state flickers: it drops to "out of combat" for a moment in the middle of fights
-- (enemies resetting, leashing, out of range for a second -- very common in overland). "Only in combat"
-- trackers would vanish and come back. So combat counts as over only after COMBAT_GRACE seconds.
Load.COMBAT_GRACE = 3
local lastInCombat = -1000
function Load.InCombat()
    local now = DT.Util.Now()
    if IsUnitInCombat("player") then lastInCombat = now return true end
    return now - lastInCombat < Load.COMBAT_GRACE
end
function Load.ResetCombatGrace() lastInCombat = -1000 end
-- seconds since you were last in combat (0 while in combat)
function Load.SinceCombat()
    if IsUnitInCombat("player") then return 0 end
    return DT.Util.Now() - lastInCombat
end

-- Boss frames drop for a moment mid-fight (a boss going untargetable, a phase change, adds spawning): a boss seen
-- in the last BOSS_GRACE seconds still counts, so "boss fights only" / "trash only" trackers don't flicker.
Load.BOSS_GRACE = 2
local lastBoss = -1000
local function BossPresent()
    local now = DT.Util.Now()
    if DoesUnitExist("boss1") then lastBoss = now return true end
    return now - lastBoss < Load.BOSS_GRACE
end
function Load.ResetBossGrace() lastBoss = -1000 end

local characterName
function Load.Context()
    if not characterName then characterName = U.CleanName(GetUnitName("player")) end
    local groupSize = GetGroupSize() or 0
    return {
        inCombat = Load.InCombat(),
        zoneType = Load.zone.type,
        zoneId = Load.zone.id,
        role = Role(),
        classId = GetUnitClassId("player"),
        groupSize = groupSize,
        bossPresent = BossPresent(),
        dead = IsUnitDead("player") == true,
        character = characterName,
    }
end

-- Returns loaded (bool), reason (string, for the editor's "why isn't it showing" hint)
-- "Above heads" needs a world position; the game only gives that for allies.
function Load.HeadsProblem(tracker)
    if tracker.display.type == "onframes" then
        -- entries about allies: buffs / debuffs on group members, you or your companion, group members themselves
        -- (Group members), or a group's resources
        local tr = tracker.trigger
        if (tr.type == "effect" and C.HEAD_SCOPES[tr.scope]) or tr.type == "group"
            or (tr.type == "resource" and (tr.unit == "group" or tr.unit == "player")) then
            return nil
        end
        return DT.L("On group frames only works on allies (group members, you, your companion)")
    end
    if tracker.display.type ~= "heads" then return nil end
    local tr = tracker.trigger
    if tr.type ~= "effect" or not C.HEAD_SCOPES[tr.scope] then
        return DT.L("Above heads only works on allies (group members, you, your companion)")
    end
    return nil
end

local function Standing(tracker, ctx)
    if not tracker.enabled then return false, DT.L("Disabled") end
    local headsProblem = Load.HeadsProblem(tracker)
    if headsProblem then return false, headsProblem end
    -- a proc's own tracker ("Own tracker" in My procs) with nothing to show -- its set taken off, its
    -- synergy unticked: no empty window left behind (Tony: "when removing the set this box stays")
    local tr = tracker.trigger
    if tr.type == "procs" and #tr.procOnly > 0 and #DT.Procs.Candidates(tr) == 0 then
        return false, DT.L("Not worn")
    end
    local ld = tracker.load
    if ld.group == "solo" and ctx.groupSize > 0 then return false, DT.L("Solo only") end
    if ld.group == "group" and (ctx.groupSize < 2 or ctx.groupSize > 4) then return false, DT.L("Small group only") end
    if ld.group == "raid" and ctx.groupSize < 5 then return false, DT.L("Raid only") end
    if ld.group == "grouped" and ctx.groupSize < 2 then return false, DT.L("Group only") end
    -- Every list below is "only when" (one of them matches) or, switched to "never when", the opposite: hidden
    -- when one of them matches (Tony: HyperTools' "!" prefix, here as a plain switch next to each list).
    local never = ld.never
    local function Apply(group, matched, onlyReason, neverReason)
        if never[group] then
            if matched then return neverReason end
        elseif not matched then
            return onlyReason
        end
        return nil
    end
    local why

    -- zones: zone types, zone IDs, zone names
    if next(ld.zoneTypes) or #ld.zoneIds > 0 or #ld.zoneNames > 0 then
        local function NameMatch()
            if #ld.zoneNames == 0 then return nil end
            ctx.zoneName = ctx.zoneName or U.Lower(U.CleanName(GetUnitZone and GetUnitZone("player") or ""))
            for _, want in ipairs(ld.zoneNames) do
                if ctx.zoneName:find(want, 1, true) then return true end
            end
            return false
        end
        -- each kind that's filled in: true / false; nil when not used
        local typeOk, idOk
        if next(ld.zoneTypes) then typeOk = ld.zoneTypes[ctx.zoneType] == true end
        if #ld.zoneIds > 0 then idOk = U.Contains(ld.zoneIds, ctx.zoneId) == true end
        local nameOk = NameMatch()
        if never.zones then
            -- never: any listed zone (type, ID or name) is enough to hide it
            if typeOk or idOk or nameOk then return false, DT.L("Not in this zone") end
        else
            -- only: every kind that's filled in must match (as before)
            if typeOk == false then return false, DT.L("Zone type") end
            if idOk == false or nameOk == false then return false, DT.L("Zone") end
        end
    end
    if next(ld.roles) then
        why = Apply("roles", ld.roles[ctx.role] == true, DT.L("Role"), DT.L("Not for this role"))
        if why then return false, why end
    end
    if next(ld.classes) then
        why = Apply("classes", ld.classes[ctx.classId] == true, DT.L("Class"), DT.L("Not for this class"))
        if why then return false, why end
    end
    -- gear: a set by ID (pieces / full) and full sets by name
    if ld.setId > 0 or #ld.setNames > 0 then
        local idWorn, nameWorn
        if ld.setId > 0 then
            if ld.setFull then idWorn = DT.Gear.IsFull(ld.setId)
            else idWorn = DT.Gear.Pieces(ld.setId, ld.setBackbar) >= ld.setPieces end
        end
        if #ld.setNames > 0 then nameWorn = DT.Procs.FullSetWornByName(ld.setNames) end
        if never.sets then
            if idWorn or nameWorn == true then return false, DT.L("Not with this set worn") end
        else
            if ld.setId > 0 and not idWorn then
                return false, ld.setFull and DT.L("Full set not equipped") or DT.L("Set not equipped")
            end
            if nameWorn == false then return false, DT.L("Set not worn: <<1>>", table.concat(ld.setNames, ", ")) end
        end
    end
    if #ld.cpSkills > 0 then
        local slotted, ok = Load.ChampionSlotted(), false
        for _, id in ipairs(ld.cpSkills) do
            if slotted[id] then ok = true; break end
        end
        why = Apply("cp", ok, DT.L("Champion skill not slotted"), DT.L("Not with this champion skill"))
        if why then return false, why end
    end
    if #ld.skills > 0 or #ld.skillNames > 0 then
        local sl, ok = Load.Slotted(), false
        for _, id in ipairs(ld.skills) do
            if sl.ids[id] then ok = true; break end
        end
        if not ok then
            for _, want in ipairs(ld.skillNames) do
                for _, have in ipairs(sl.names) do
                    if have:find(want, 1, true) then ok = true; break end
                end
                if ok then break end
            end
        end
        why = Apply("skills", ok, DT.L("Skill not slotted"), DT.L("Not with this skill slotted"))
        if why then return false, why end
    end
    if #ld.characters > 0 then
        local ok = false
        for _, n in ipairs(ld.characters) do
            if U.Lower(n) == U.Lower(ctx.character) then ok = true; break end
        end
        why = Apply("characters", ok, DT.L("Other characters only"), DT.L("Not on this character"))
        if why then return false, why end
    end
    return true
end

-- What changes from moment to moment (combat, a boss, being dead, werewolf form, which boss): only hides the tracker.
local function Moment(tracker, ctx)
    local ld = tracker.load
    local never = ld.never
    local function Apply(group, matched, onlyReason, neverReason)
        if never[group] then
            if matched then return neverReason end
        elseif not matched then
            return onlyReason
        end
        return nil
    end
    local why
    -- "Stay shown after combat" (Meterskull keeps its meters 5 s): longer than the usual grace
    if ld.combat == "in" and not ctx.inCombat and not ((ld.combatLinger or 0) > Load.COMBAT_GRACE
        and Load.SinceCombat() < ld.combatLinger) then
        return false, DT.L("Only in combat")
    end
    if ld.combat == "out" and ctx.inCombat then return false, DT.L("Only out of combat") end
    if ld.bossOnly and not ctx.bossPresent then return false, DT.L("Boss fights only") end
    if ld.trashOnly and ctx.bossPresent then return false, DT.L("Not during boss fights") end
    if ld.hideDead and ctx.dead then return false, DT.L("You're dead") end
    -- werewolf form (Tony, 5.14.6: "show only when I'm human" -- the werewolf bar isn't one of your two bars, so
    -- "skill slotted" could never see it). Read only for trackers that use it.
    if ld.werewolf ~= "any" then
        if ctx.werewolf == nil then ctx.werewolf = type(IsWerewolf) == "function" and IsWerewolf() == true end
        if ld.werewolf == "only" and not ctx.werewolf then return false, DT.L("Only in werewolf form") end
        if ld.werewolf == "never" and ctx.werewolf then return false, DT.L("Not in werewolf form") end
    end

    if #ld.bossNames > 0 then
        local ok = false
        for _, have in ipairs(BossNames(ctx)) do
            for _, want in ipairs(ld.bossNames) do
                if have:find(want, 1, true) then ok = true; break end
            end
            if ok then break end
        end
        why = Apply("bosses", ok, DT.L("Other boss"), DT.L("Not against this boss"))
        if why then return false, why end
    end
    return true
end

-- Returns loaded (bool), reason (string, for the editor's "why isn't it showing" hint), standing (bool).
-- "Standing" conditions change rarely -- enabled, role, class, character, zone, group, sets, champion and slotted
-- skills: a tracker that fails one of them doesn't listen to anything at all (Engine.Rebuild; Yarden, 5.21.26: "I'm on
-- healer. Why am I listening to non healer things??" -- a Taunt tracker for tanks still followed every taunt). The
-- moment-to-moment ones only hide it, so nothing re-registers each time combat starts or ends.
function Load.Check(tracker, ctx)
    local ok, why = Standing(tracker, ctx)
    if not ok then return false, why, false end
    ok, why = Moment(tracker, ctx)
    if not ok then return false, why, true end
    return true, nil, true
end

-- only the standing conditions (does this tracker need to listen to anything right now?): ok, reason
function Load.Standing(tracker, ctx)
    return Standing(tracker, ctx)
end

-- only the moment-to-moment ones: ok, reason
function Load.Moment(tracker, ctx)
    return Moment(tracker, ctx)
end

function Load.IsLoaded(tracker, ctx)
    return (Load.Check(tracker, ctx))
end
