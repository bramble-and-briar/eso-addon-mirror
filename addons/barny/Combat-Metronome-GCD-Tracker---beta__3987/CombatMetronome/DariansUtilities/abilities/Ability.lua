local Util = DariansUtilities
Util.Ability = Util.Ability or { }
Util.Stacks = Util.Stacks or {}
Util.Text = Util.Text or {}
local Ability = Util.Ability
Ability.cache = { }
Ability.nameCache = { }

local invalidLocation = {
    displayName = "Invalid location",
    icon = "/esoui/art/icons/icon_missing.dds",
    clearSynergy = false,
}

local effectFaded = {
    displayName = "Effect faded",
    icon = "/esoui/art/icons/servicemappins/servicepin_transmute.dds",
    clearSynergy = false,
}

local targetDied = {
    displayName = "Target dead",
    icon = "/esoui/art/targetmarkers/gamepad/target_white_skull.dds",
    clearSynergy = false,
}

local silenced = {
    displayName = "Silenced",
    icon = "/esoui/art/icons/ability_debuff_silence.dds",
    clearSynergy = false,
}

local stagger = {
    displayName = "Stagger",
    icon = "/esoui/art/icons/ability_debuff_stagger.dds",
    clearSynergy = false,
}

local immune = {
    displayName = "Target immune",
    icon = "/esoui/art/icons/death_recap_void_dot_heavy.dds", --/esoui/art/icons/death_recap_necro_dot_heavy2.dds
    clearSynergy = false,
}

local abilityOnCooldown = {
    displayName = "Error",
    icon = "/esoui/art/icons/icon_missing.dds",
    clearSynergy = false,
}

local block = {
    displayName = "Blocked",
    icon = "/esoui/art/icons/u42_weaponskill_onehandshield25.dds",
    clearSynergy = false,
}

local GRACE_PERIOD = 500

local Class = {
[1] = "DK",
[2] = "SORC",
[3] = "NB",
[4] = "DEN",
[5] = "CRO",
[6] = "PLAR",
[117] = "ARC",
}

local targetConstants = {
    ["ground"] = GetString(SI_ABILITY_TOOLTIP_TARGET_TYPE_GROUND),
    ["enemy"] = GetString(SI_TARGETTYPE0),
    ["ally"] = GetString(SI_TARGETTYPE1),
    ["self"] = GetString(SI_TARGETTYPE2)
}

local jesusBeam = {
    [63029] = true,
    [63044] = true,
    [63046] = true,
}

local mendWoundsIds = {
        [107579]=true,[107583]=true,[107629]=true,[107630]=true,[107636]=true,[107637]=true,[107638]=true,[114990]=true,[114991]=true,[114992]=true,[118617]=true,[118638]=true,[118645]=true
    }

local meditateIds = {
    [103665]=true, [103492]=true, [103652]=true
}

local carverIds = {[183122] = "Exhausting Fatecarver mag", [193397] = "Exhausting Fatecarver stam"}

local log = Util.log

function Ability:ForId(id)
    local o = self.cache[id]
    if (o) then
        return o 
    end

	o = { }
	setmetatable(o, self)
	self.__index = self

    o.id = id
    o.name = Util.Text.CropZOSString(GetAbilityName(id), "ability")
    local channeled, duration = GetAbilityCastInfo(id)
    o.channeled = channeled
    if channeled then
        o.channelTime = duration
        o.castTime = 0
    else
        o.castTime = duration
        o.channelTime = 0
    end
    -- end
    o.delay = duration or 0
    o.instant = not (o.castTime > 0 or (o.channeled and o.channelTime > 0))
    o.casted = not (o.instant or o.channeled)
    o.target = GetAbilityTargetDescription(id)
	o.icon = GetAbilityIcon(id)

    o.duration = GetAbilityDuration(id)
    o.buffType = GetAbilityBuffType(id)
    o.isTankAbility, 
    o.isHealerAbility, 
    o.isDamageAbility = GetAbilityRoles(id)

    o.ground = o.target == targetConstants.ground
    o.enemy = o.target == targetConstants.enemy
    o.ally = o.target == targetConstants.ally
    
    o.isMendWounds = mendWoundsIds[id] or false
    o.isMeditate = meditateIds[id] or false
    if o.isMeditate then o.delay = 1000 end
    
    o.checkForDeadTarget = ((o.enemy or o.ally) and duration > 1000) or (o.isMendWounds)
    
    o.heavy = o.id == GetSlotBoundId(2) and not o.isMendWounds
    o.light = o.id == GetSlotBoundId(1) and not o.isMendWounds
    
    o.hasProgression,
    o.progressionIndex = GetAbilityProgressionXPInfoFromAbilityId(id)

    if o.hasProgression then
        o.baseName,
        o.morph,
        o.rank = GetAbilityProgressionInfo(o.progressionIndex)

        o.baseId = GetAbilityProgressionAbilityId(o.progressionIndex, 0, 1)
    end

    if (o.name) then
        self.nameCache[o.name] = o
    end
    
    self.cache[id] = o

    return o
end

function Ability:UpdateScribedSkills()
    for i = 1, 12 do
        local abilityId = GetAbilityIdForCraftedAbilityId(i)
        self.cache[abilityId] = nil
        Ability:ForId(abilityId)
    end
end

-- -------- --
-- Tracking --
-- -------- --

Ability.Tracker = Ability.Tracker or { }
Ability.Tracker.name = "Util.Ability.Tracker"

local EVENT_RECORD_DELAY = 10
local EVENT_FORCE_WAIT = 100
local DISMOUNT_PERIOD = 300
local SHEATHING_PERIOD = 800
-- local SWAP_PERIOD = 250

function Ability.Tracker:Start()
    if self.started then return end

    self.started = true
    self.lastAbilityFinished = 0

    self.log = false
    self.class = Class[GetUnitClassId("player")]
    self.cdTriggerTime = 0
    self.lastMounted = 0
    self.weaponLastSheathed = 0
    self.eventStart = 0
    self.lastLightAttack = 0
    self.rollDodgeFinished = 0
    self.lastBlockStatus = false
    
    self.abilityTriggerCounters = {direct = 0, normal = 0, late = 0, combatEvent = 0}
    
    EVENT_MANAGER:RegisterForUpdate(self.name.."Update", 1000 / 30, function(...)
        self:Update()
    end)
    
    -- EVENT_MANAGER:RegisterForEvent(self.name.."SlotUpdated", EVENT_ACTION_SLOT_STATE_UPDATED, function(_, slot) 
        -- if slot > 2 and slot < 9 then self:HandleSlotUpdated(_, slot) end
    -- end)
    EVENT_MANAGER:RegisterForEvent(self.name.."SlotUsed", EVENT_ACTION_SLOT_ABILITY_USED, function(_, slot)
        if slot >2 and slot < 9 then self:HandleSlotUsed(_, slot) end
    end)
    EVENT_MANAGER:RegisterForEvent(self.name.."PlayerDead", EVENT_PLAYER_DEAD, function()
        self:CancelCurrentEvent("Player dead")
        self:CancelEvent("Player dead")
    end)
    -- EVENT_MANAGER:RegisterForEvent(self.name.."PlayerActivated", EVENT_PLAYER_DEACTIVATED, function()
        -- if self.queuedEvent then self:CancelEvent("Player deactivated") end
    -- end)
    
    EVENT_MANAGER:RegisterForEvent(self.name.."IncomingCombatEvent", EVENT_COMBAT_EVENT, function(...)
        self:HandleIncomingCombatEvent(...) 
    end)
    EVENT_MANAGER:AddFilterForEvent(self.name.."IncomingCombatEvent", EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    
    EVENT_MANAGER:RegisterForEvent(self.name.."OutgoingCombatEvent", EVENT_COMBAT_EVENT, function(...)
        self:HandleOutgoingCombatEvent(...) 
    end)
    EVENT_MANAGER:AddFilterForEvent(self.name.."OutgoingCombatEvent", EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    
    EVENT_MANAGER:RegisterForEvent(self.name.."MountedState", EVENT_MOUNTED_STATE_CHANGED, function(_, mounted)
        self.mountedState = mounted
        if not mounted then self.lastMounted = GetFrameTimeMilliseconds() end
    end)
    EVENT_MANAGER:RegisterForEvent(self.name.."CooldownsUpdated", EVENT_ACTION_UPDATE_COOLDOWNS, function()
        self:HandleCooldownsUpdated()
    end)
	EVENT_MANAGER:RegisterForEvent(self.name.."BarSwap", EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, function(...)
        self:HandleBarSwap(...)
    end)
    EVENT_MANAGER:RegisterForEvent(self.name.."CombatStateChange", EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
		Ability.Tracker:ResetDebugCount(inCombat)
    end)
    EVENT_MANAGER:RegisterForEvent(self.name.."WeaponLockChange", EVENT_WEAPON_PAIR_LOCK_CHANGED, function(_, locked)
		Ability.Tracker:HandleWeaponLockChange(locked)
    end)
    EVENT_MANAGER:RegisterForEvent(self.name.."UpdateScribedSkills", EVENT_END_CRAFTING_STATION_INTERACT, function(_, craftType, _)
        if craftType == CRAFTING_TYPE_SCRIBING then Ability:UpdateScribedSkills() end
    end)
end

function Ability.Tracker:GCDCheck()
    
    for i = 3, 8 do
        local slotRemaining, slotDuration, global = GetSlotCooldownInfo(i)
        
        if global then
            local gcdProgress = slotDuration > 0 and slotRemaining/slotDuration or 0
            return gcdProgress, slotRemaining, slotDuration
        end
    end
    return 0, 0, 0
end

function Ability.Tracker:HandleBarSwap(_, barswap, _, _)
    if self.barswap == barswap then return end
    self.barswap = barswap == true
    if self.barswap and self.currentEvent and self.currentEvent.ability and (self.currentEvent.ability.delay > 1000 or self.currentEvent.ability.heavy) then
        self:CancelCurrentEvent("Barswap")
        self.barswap = false
    end
    self:CancelEvent("Barswap")
end

local function CanAbilityFire(time)
    if (Ability.Tracker.currentEvent and Ability.Tracker.currentEvent.ability.heavy) or (CombatMetronome.currentEvent and CombatMetronome.currentEvent.ability.heavy) then
        Ability.Tracker:CancelCurrentEvent("Heavy cancel - new event coming")
        return true
    elseif CombatMetronome.currentEvent and CombatMetronome.currentEvent.ending <= time then
        Ability.Tracker:CancelCurrentEvent("Old event just finished.")
        return true
    elseif CombatMetronome.gcdEvent.clearSynergy then
        CombatMetronome.gcdEvent = { finished = 0 }
    end
    
    return Ability.Tracker.lastAbilityFinished <= time and CombatMetronome.gcdEvent.finished <= time
end

local function RegisterJesusBeam(id)
    local t = DariansUtilities.Ability.Tracker
    if not t.jesusBeamRegistered then
        EVENT_MANAGER:RegisterForEvent(t.name.."HandleJesusBeam", EVENT_EFFECT_CHANGED, function(_,changeType)
            if changeType == EFFECT_RESULT_FADED and t.currentEvent and t.currentEvent.ability.id == id then
                if not t.skipNextEffectFaded then
                    t:CancelCurrentEvent("Jesus beam finished")
                else
                    t:PrintDebugNotes("abilityUsed", id, "Skip next effect faded is now being reset")
                    t.skipNextEffectFaded = false
                end
            end
        end)
        EVENT_MANAGER:AddFilterForEvent(t.name.."HandleJesusBeam", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, id)
        EVENT_MANAGER:AddFilterForEvent(t.name.."HandleJesusBeam", EVENT_EFFECT_CHANGED, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
        t.jesusBeamRegistered = true
        t:PrintDebugNotes("abilityUsed", id, "Jesus beam tracker has been registered")
    else
        t.skipNextEffectFaded = true
        t:PrintDebugNotes("abilityUsed", id, "Seems like like you casted a new beam. Will skip next effect faded")
    end
end

local function UnregisterJesusBeam(id)
    local t = DariansUtilities.Ability.Tracker
    if t.jesusBeamRegistered then
        EVENT_MANAGER:UnregisterForEvent(t.name.."HandleJesusBeam")
        t.jesusBeamRegistered = false
        t.skipNextEffectFaded = false
        t:PrintDebugNotes("abilityUsed", id, "Jesus beam ended. Tracker has been unregistered")
    end
end

function Ability.Tracker:Update()
    local time = GetFrameTimeMilliseconds()
    local gcdProgress, sR, sD = self:GCDCheck()
    
    if (self.lastBlockStatus == false) and IsBlockActive() and (CombatMetronome.currentEvent or self.queuedEvent) then
        -- adding a bunch of checks here, so events aren't canceled if they actually went through
        if CombatMetronome.currentEvent and not CombatMetronome.currentEvent.allowForce and CombatMetronome.currentEvent.start + CombatMetronome.currentEvent.ability.delay > time then self:CancelCurrentEvent("Blocked") end
        self:CancelEvent("Blocked")
    end
    
    -- Fire off late events if no UPDATE_COOLDOWNS events
    if ((self.queuedEvent and self.queuedEvent.castDuringRollDodge and self.rollDodgeFinished <= time) or self.queuedEvent) and gcdProgress > 0.9 and CanAbilityFire(time) then
        self.eventStart = time + sR - sD
        self:AbilityUsed("late", sR, sD)
        self.abilityTriggerCounters.late = self.abilityTriggerCounters.late + 1
    end
    
    -- delete queued Events, if they weren't fired and also shouldn't be
    if not self.currentEvent and self.queuedEvent and math.max(self.lastAbilityFinished, self.queuedEvent.recorded, self.weaponLastSheathed + SHEATHING_PERIOD, self.lastMounted + DISMOUNT_PERIOD) + math.max(self.queuedEvent.ability.delay,1000) < time then
        self:CancelEvent("Event over")
    end
    
    if ArePlayerWeaponsSheathed() then
        self.weaponLastSheathed = time
    end
    self.lastBlockStatus = IsBlockActive()
end

function Ability.Tracker:NewEvent(ability, slot, start)
    local time = GetFrameTimeMilliseconds()
    
    local gcdProgress, sR, sD = self:GCDCheck()

    local event = { }

    event.ability = ZO_ShallowTableCopy(ability)
        
    event.recorded = start
    if self.rollDodgeFinished > time then event.castDuringRollDodge = true end

    local isMounted = time < self.lastMounted + DISMOUNT_PERIOD
    local weaponSheathed = time < self.weaponLastSheathed + SHEATHING_PERIOD
    event.allowForce = ability.instant and not (isMounted or weaponSheathed or ability.ground)
    
    event.slot = slot
    event.hotbar = GetActiveHotbarCategory()

    self.queuedEvent = event
        
    if self.queuedEvent.ability.heavy then
        self.eventStart = start
        self:AbilityUsed("direct", sR, sD)
    elseif self.cdTriggerTime == start and gcdProgress == 1 and self.rollDodgeFinished <= time and not event.castDuringRollDodge then
        if CombatMetronome.currentEvent then self:CancelCurrentEvent("Direct trigger detected") end
        self.eventStart = start
        self:AbilityUsed("direct", sR, sD)
        self.abilityTriggerCounters.direct = self.abilityTriggerCounters.direct + 1
    end
end

function Ability.Tracker:CancelEvent(reason)    
    if self.queuedEvent then
        if self.queuedEvent and self.queuedEvent.ability and not self.queuedEvent.ability.heavy then
            self:PrintDebugNotes("eventCancel", self.queuedEvent.ability.id, string.format("Canceled queued ability '%s'. Reason: %s", self.queuedEvent.ability.name, reason))
        end
        self.queuedEvent = nil
    end
end

function Ability.Tracker:AbilityUsed(trigger, sR, sD)
                
    local event = self.queuedEvent
    
    if carverIds[event.ability.id] then
        local stacks = Util.Stacks:GetCurrentNumStacksOnPlayer("Crux")
        local duration = event.ability.delay + 338*stacks
        event.ability.delay = duration
        event.ability.channelTime = duration
    end
    
    event.start = self.eventStart
    event.ending = self.eventStart + (event.ability.heavy and event.ability.delay or math.max(event.ability.delay, 1000, sR))
    
    self:PrintDebugNotes("eventCancel", self.queuedEvent.ability.id, string.format("Queued ability '%s' is about to be fired. Setting queuedEvent 'nil'", self.queuedEvent.ability.name))
    self.queuedEvent = nil
    
    self.gcd = sD
    self:PrintDebugNotes("abilityUsed", event.ability.id, string.format("New ability used '%s' - Trigger: %s - Remaining: %d", event.ability.name, trigger, sR))
    if jesusBeam[event.ability.id] then RegisterJesusBeam(event.ability.id) end
            
    self:CallbackAbilityUsed(event)
    
    if (event.ability.instant or event.ability.channeled) then
        self:CallbackAbilityActivated(event)
    end

    if (not event.ability.instant or event.ability.heavy) then
        self.currentEvent = event
    end
    
    self.lastAbilityFinished = event.ending
    
    if trigger == "Slot updated" or trigger == "CD updated" then
        self.abilityTriggerCounters.normal = self.abilityTriggerCounters.normal + 1
    end
end

function Ability.Tracker:CallbackAbilityUsed(event)
    if self.CombatMetronome then self.CombatMetronome:HandleAbilityUsed(event) end 
end

function Ability.Tracker:CallbackAbilityActivated(event)
    if self.CombatAuras then self.CombatAuras:HandleAbilityActivated(event) end
end

function Ability.Tracker:CallbackLightAttackUsed(time)
    if self.CombatMetronome.LATracker then self.CombatMetronome.LATracker:HandleLightAttacks(time) end
end

-- function Ability.Tracker:HandleSlotUpdated(e, slot)
    -- local time = GetFrameTimeMilliseconds()
    
    -- if self.lastLightAttack == time then return end
    
    -- if self.queuedEvent and self.queuedEvent.recorded == time and self.queuedEvent.slot == slot then
        -- self:CancelEvent("Same slot updated")
    -- elseif CombatMetronome.currentEvent and CombatMetronome.currentEvent.slot == slot and CombatMetronome.currentEvent.recorded == time then
        -- self:CancelCurrentEvent("Same slot updated")
    -- end
    
    -- if not self.queuedEvent then return
    
    -- elseif self.currentEvent and self.currentEvent.slot == slot and self.eventStart == time then
        -- self:CancelCurrentEvent("Same slot updated")
    -- end
    
    -- local gcdProgress, sR, sD = self:GCDCheck()

    -- local oldStart = self.eventStart or 0
    -- if sR > 0 and sD > 0 then
        -- self.eventStart = time + sR - sD
    -- else
        -- self.eventStart = time
    -- end
    
    -- if self.eventStart >= oldStart then
        -- self:PrintDebugNotes("abilityUsed", self.queuedEvent.ability.id, string.format("Ability '%s' triggered. Firing ability", self.queuedEvent.ability.name))
        -- self:AbilityUsed("slotUpdated")
    -- end
-- end

function Ability.Tracker:HandleCooldownsUpdated()
    
    self.cdTriggerTime = GetFrameTimeMilliseconds()
    
    local gcdProgress, sR, sD = self:GCDCheck()
        
    if self.currentEvent and self.currentEvent.ability.heavy then
        if sR > 0 then
            self:CancelCurrentEvent("Heavy cancel - new GCD")
        else
            local hSR, hSD, global = GetSlotCooldownInfo(2)
            if not global and hSR == hSD then self:CancelCurrentEvent("Heavy cancel") end
        end
    end
    
    if sR == 0 then return end
    
    if not CanAbilityFire(self.cdTriggerTime) then return end
    
    self.gcd = sD
    
    if self.queuedEvent and self.rollDodgeFinished <= self.cdTriggerTime and not self.queuedEvent.castDuringRollDodge then
        self.eventStart = self.cdTriggerTime + sR - sD
        if self.eventStart + GetLatency() >= self.cdTriggerTime then
            self:AbilityUsed("CD updated", sR, sD)
        end
    end
end

function Ability.Tracker:HandleSlotUsed(_, slot)
    -- don't create a new event, if using the slot is just a toggle off
    if IsSlotToggled(slot) then return end
        
    local ability = {}
    local actionType = GetSlotType(slot)
    if actionType == ACTION_TYPE_CRAFTED_ABILITY then
        local isScribedAbility = true
        ability = Util.Ability:ForId(GetAbilityIdForCraftedAbilityId(GetSlotBoundId(slot)), isScribedAbility)
    else
        local isScribedAbility = false
        ability = Util.Ability:ForId(GetSlotBoundId(slot), isScribedAbility)
    end
    
    local time = GetFrameTimeMilliseconds()
        
    self:CancelEvent("Overwrite")
    
    self:NewEvent(ability, slot, time)
end

--                                                 (a)bility | (d)amage | (p)ower | (t)arget | (s)ource | (h)it
--                                                 ------------------------------------------------------------
--                                                 1      2     3      4     5  	6      7      8      9
--                                                 10     11    12     13    14 	15     16     17     18
function Ability.Tracker:HandleIncomingCombatEvent(_,     res,  err,   aName, _, aSlotType, sName, sType, tName, 
                                                   tType, hVal, pType, dType, _, sUId, tUId,  aId, overflow)
    if CombatMetronome and CombatMetronome.currentEvent then
        local time = GetFrameTimeMilliseconds()
        if (   res == ACTION_RESULT_KNOCKBACK
            or res == ACTION_RESULT_PACIFIED
            or res == ACTION_RESULT_STAGGERED
            or res == ACTION_RESULT_STUNNED
            or res == ACTION_RESULT_INTERRUPT
            or res == ACTION_RESULT_FEARED
            or res == ACTION_RESULT_LEVITATED)
            and not sType == COMBAT_UNIT_TYPE_PLAYER and not CombatMetronome.currentEvent.allowForce then
            self:CancelCurrentEvent("CC")
            self:CancelEvent("CC")
            return
        elseif res == ACTION_RESULT_EFFECT_FADED and self.currentEvent and self.currentEvent.ability.id == aId and self.currentEvent.ability.delay > 1000 then
            self:CancelCurrentEvent("Effect faded, player is target")
            return
        elseif sType == COMBAT_UNIT_TYPE_PLAYER and res == ACTION_RESULT_SILENCED and CombatMetronome.currentEvent.ability.id == aId then
            self:CancelCurrentEvent("Silenced")
            return
        end
    end
end


--                                                 (a)bility | (d)amage | (p)ower | (t)arget | (s)ource | (h)it
--                                                 ------------------------------------------------------------
--                                                 1      2     3      4     5  	6      7      8      9
--                                                 10     11    12     13    14 	15     16     17     18
function Ability.Tracker:HandleOutgoingCombatEvent(_,     res,  err,   aName, _, aSlotType, sName, sType, tName, 
                                                   tType, hVal, pType, dType, _, sUId, tUId,  aId, overflow)
    
    aName = Util.Text.CropZOSString(aName, "ability")
    local time = GetFrameTimeMilliseconds()
    
    if res ~= ACTION_RESULT_EFFECT_FADED and CombatMetronome and CombatMetronome.currentEvent and CombatMetronome.currentEvent.ability.id == aId and CombatMetronome.currentEvent.ability.checkForDeadTarget and not CombatMetronome.currentEvent.target then
        CombatMetronome.currentEvent.target = tUId
        self:PrintDebugNotes("currentEvent", aId, string.format("Ability needs to check for dead target. Adding target unit id '%d' to currentEvent", tUId))
    end
    
    if self.queuedEvent and self.queuedEvent.ability.id == aId then
        if res == ACTION_RESULT_BEGIN or res == ACTION_RESULT_EFFECT_GAINED then
            local gcdProgress, sR, sD = self:GCDCheck()
            self.eventStart = time + sR - sD
            self:AbilityUsed("CombatEvent", sR, sD)
            self.abilityTriggerCounters.combatEvent = self.abilityTriggerCounters.combatEvent + 1
        elseif self.queuedEvent.ability.enemy and res == ACTION_RESULT_TARGET_DEAD then
            self:CancelEvent("Leave him alone, he is already dead")
        -- elseif res == ACTION_RESULT_QUEUED then
            -- self.queuedEvent.isQueued = true
        end
    end
            
    if CombatMetronome.currentEvent and CombatMetronome.currentEvent.ability.id == aId and err and CombatMetronome.currentEvent.recorded + 100 > time and res == ACTION_RESULT_ABILITY_ON_COOLDOWN then
        self:CancelCurrentEvent("Error")
        return
    elseif res == ACTION_RESULT_EFFECT_FADED and self.currentEvent and self.currentEvent.ability.id == aId then
        self:CancelCurrentEvent("Effect faded, player is source")
        return
    elseif CombatMetronome.currentEvent and CombatMetronome.currentEvent.ability.id == aId and CombatMetronome.currentEvent.ability.enemy then
        if res == ACTION_RESULT_IMMUNE then
            self:CancelCurrentEvent("Target immune")
            return
        elseif res == ACTION_RESULT_STAGGERED then
            self:CancelCurrentEvent("Stagger")
            return
        elseif res == ACTION_RESULT_TARGET_DEAD then
            self:CancelCurrentEvent("Target dead")
            return
        end
    elseif (res == ACTION_RESULT_DIED or res == ACTION_RESULT_DIED_XP) and CombatMetronome and CombatMetronome.currentEvent and CombatMetronome.currentEvent.ability.checkForDeadTarget and CombatMetronome.currentEvent.target == tUId and aId == CombatMetronome.currentEvent.ability.id then -- ACTION_RESULT_TARGET_DEAD
        self:PrintDebugNotes("currentEvent", aId, string.format("Target dead. Cancelling '%s' - Id: %d", aName, aId))
        self:CancelCurrentEvent("Target died")
        return
    elseif res == ACTION_RESULT_NO_LOCATION_FOUND and CombatMetronome and CombatMetronome.currentEvent and CombatMetronome.currentEvent.ability.id == aId then
        self:CancelCurrentEvent("Invalid location")        
        return
                -- rolldodge
    elseif aId == 28549 and res == ACTION_RESULT_EFFECT_GAINED then
        local _, remaining = self:GCDCheck()
        self.rollDodgeFinished = time + remaining
        self:CancelEvent("Rolldodge")
        if self.currentEvent or CombatMetronome.currentEvent then
            self:CancelCurrentEvent("Rolldodge")
        end
        
    elseif err then return
    
        -- Light and heavy attacks
    elseif aSlotType == ACTION_SLOT_TYPE_HEAVY_ATTACK and (res == ACTION_RESULT_BEGIN or res == ACTION_RESULT_BEGIN_CHANNEL) and sType == COMBAT_UNIT_TYPE_PLAYER then
        if (self.currentEvent and self.currentEvent.ability.id == aId) then
            return
        elseif aId ~= GetSlotBoundId(2) then
            return
        end
        local heavy = Util.Ability:ForId(aId, false)
        self:NewEvent(heavy, 2, time)
        return
    elseif (aSlotType == ACTION_SLOT_TYPE_LIGHT_ATTACK or aSlotType == ACTION_SLOT_TYPE_WEAPON_ATTACK) and tType ~= COMBAT_UNIT_TYPE_PLAYER and (res == ACTION_RESULT_EFFECT_GAINED or res == ACTION_RESULT_CRITICAL_DAMAGE or res == ACTION_RESULT_DAMAGE) and time ~= self.lastLightAttack then
        Ability.Tracker:CallbackLightAttackUsed(time)
        self.lastLightAttack = time
    end
end

function Ability.Tracker:HandleWeaponLockChange(locked)
    local time = GetFrameTimeMilliseconds()
    if not locked and self.currentEvent and self.currentEvent.ability.casted and not self.currentEvent.ability.heavy and ((time-self.currentEvent.start) < self.currentEvent.ability.delay and self.currentEvent.start ~= time) then
        self:CancelCurrentEvent("Weapon lock change")
    end
end

------------------------
---- Debug Triggers ----
------------------------

function Ability.Tracker:ResetDebugCount(inCombat)
    if not inCombat and not self.debugCountReset then
        for t, c in pairs(self.abilityTriggerCounters) do
            self:PrintDebugNotes("triggers", nil, string.format("%s triggers: %d", t, c))
            c = 0
        end
        self.debugCountReset = true
    elseif inCombat and self.debugCountReset then
        self.debugCountReset = false
    end
end

-----------------------------------
---- Debug/Cancel currentEvent ----
-----------------------------------

local reasonToGCDMapping = {
    ["Blocked"] = block,
    ["Error"] = abilityOnCooldown,
    ["Effect faded, player is source"] = effectFaded,
    ["Effect faded, player is target"] = effectFaded,
    ["Jesus beam finished"] = effectFaded,
    ["Invalid location"] = invalidLocation,
    ["Silenced"] = silenced,
    ["Stagger"] = stagger,
    ["Target died"] = targetDied,
    ["Target dead"] = targetDied,
    ["Target immune"] = immune,
}

-- local skipTickTockReasons = {
    -- ["Heavy cancel - new GCD"] = true,
    -- ["Heavy cancel"] = true,
    -- ["Rolldodge"] = true,
-- }

function Ability.Tracker:CancelCurrentEvent(reason)
    local printDebug = false
    local ability
    
    -- local time = GetFrameTimeMilliseconds()
    -- local endedEarly = false
    
    if self.currentEvent then
        if self.currentEvent.ability then ability = self.currentEvent.ability end
        if jesusBeam[ability.id] then UnregisterJesusBeam(ability.id) end
        
        -- if self.currentEvent.ending > time then endedEarly = true end
        
        self.currentEvent = nil
        self.gcd = 1000
        printDebug = true
    end
        
    if CombatMetronome.currentEvent then
        ability = ability or CombatMetronome.currentEvent.ability
        
        -- if CombatMetronome.currentEvent.ending > time then endedEarly = true end
        
        CombatMetronome.currentEvent = nil
        CombatMetronome:OnCDStop("")
        printDebug = true
    end
    
    if printDebug then
        -- event has been canceled - displaying GCD event instead - if necessary and allowed
        local _, remaining = self:GCDCheck()
        if remaining > 0 then
            if reasonToGCDMapping[reason] then
                CombatMetronome.gcdEvent = ZO_ShallowTableCopy(reasonToGCDMapping[reason])
                CombatMetronome.gcdEvent.finished = GetFrameTimeMilliseconds() + remaining
            end
        end
        -- this implementation causes too many problems. leave here for future me to not commit too deep
        -- sound queues if event was ended early
        -- if endedEarly and (CombatMetronome.SV.Progressbar.soundTickEnabled or CombatMetronome.SV.Progressbar.soundTockEnabled) then
            -- local sv = CombatMetronome.SV.Progressbar
            -- if ability.delay > 1000 or skipTickTockReasons[reason] or (ability.heavy and not sv.noTickOnHeavy) then
                -- CombatMetronome.identifiersToSkip[CombatMetronome.currentEventIdentifier] = true
            -- end
            -- if sv.hardForceTickTock and not (ability.heavy and sv.noTickOnHeavy) then
                -- if sv.soundTickEnabled then
                    -- local timerTick =  ((sv.forceTickMSBeforeEnd and sv.forceTickTime) or (sv.soundTickMidAbility and 500) or 0) - sv.soundTickOffset
                    -- if not (ability.channeled and reason == "Blocked") and remaining > timerTick then
                        -- CombatMetronome:QueueTick(sv.soundTickEffect, remaining - timerTick, CombatMetronome.currentEventIdentifier, true)
                    -- end
                -- end
                
                -- if sv.soundTockEnabled then
                    -- local timerTock = (not (ability.channeled and reason == "Blocked") and remaining or 0) + sv.soundTockOffset
                    -- CombatMetronome:QueueTock(sv.soundTockEffect, timerTock, CombatMetronome.currentEventIdentifier, true)
                -- end
            -- end
        -- end
        
        self:PrintDebugNotes("currentEvent", ability.id, string.format("Current event '%s' canceled by: %s", ability.name, reason))
    end
    
    self.lastAbilityFinished = 0
end

function Ability.Tracker:PrintDebugNotes(debugType, abilityID, message)
    local debugs = CombatMetronome.SV.debug
    
    if not debugs[debugType] then return end
        
    local printDebug = false
    if not abilityID or abilityID == nil then printDebug = true
    elseif not next(debugs.abilityWhitelist.ids) then printDebug = true
    elseif debugs.abilityWhitelist.ids[abilityID] then printDebug = true
    end
    
    if printDebug then
        if debugs.printTimestamps then
            local time = GetFrameTimeMilliseconds()
            message = string.format("%d --> %s", time, message)
        end
        CombatMetronome.debug:Print(message)
    end
end