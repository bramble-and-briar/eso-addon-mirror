local LCCC = LibCodesCommonCode
local Internal = LibCombatAlertsInternal
local Public = LibCombatAlerts


--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

-- Format styles for Public.FormatTime
Public.TIME_FORMAT_LONG      = 1 -- 0:16
Public.TIME_FORMAT_SHORT     = 2 -- 16s (default)
Public.TIME_FORMAT_COUNTDOWN = 3 -- 1.6s
Public.TIME_FORMAT_COMPACT   = 4 -- 2h or 2m or 16s

-- Degree of certainty of interrupt; e.g., there are cases where a stun will not interrupt
Public.INTERRUPT_EVENTS = {
	[ACTION_RESULT_CHARMED] = 1,
	[ACTION_RESULT_FEARED] = 1,
	[ACTION_RESULT_STUNNED] = 2,
	[ACTION_RESULT_DIED] = 3,
	[ACTION_RESULT_DIED_XP] = 3,
	[ACTION_RESULT_INTERRUPT] = 4,
}

Public.DEATH_EVENTS = {
	[ACTION_RESULT_DIED] = true,
	[ACTION_RESULT_DIED_XP] = true,
}

Public.DAMAGE_EVENTS = {
	[ACTION_RESULT_DAMAGE] = true,
	[ACTION_RESULT_CRITICAL_DAMAGE] = true,
	[ACTION_RESULT_BLOCKED_DAMAGE] = true,
	[ACTION_RESULT_DOT_TICK] = true,
	[ACTION_RESULT_DOT_TICK_CRITICAL] = true,
}

Public.IDS = {
	TAUNT = 38254,
	MAJ_VULN = 106754,
}


--------------------------------------------------------------------------------
-- Imports from LibCodesCommonCode
--------------------------------------------------------------------------------

Public.UnpackRGBA = LCCC.Int32ToRGBA
Public.UnpackRGB = LCCC.Int24ToRGB
Public.PackRGBA = LCCC.RGBAToInt32
Public.PackRGB = LCCC.RGBToInt24
Public.AddAlpha = LCCC.Int24ToInt32
Public.RemoveAlpha = LCCC.Int32ToInt24
Public.HSLToRGB = LCCC.HSLToRGB
Public.UnpackHSL = LCCC.Int24ToHSL
Public.UnpackHSLA = LCCC.Int32ToHSLA
Public.GetGradientUnpacked = LCCC.GetGradientRGBA
Public.GetGradientPacked = LCCC.GetGradientInt32

setmetatable(Public, { __index = function( tbl, key )
	local external = LCCC[key]
	if (type(external) == "function") then
		tbl[key] = external
		return external
	end
end })


--------------------------------------------------------------------------------
-- Miscellaneous functions
--------------------------------------------------------------------------------

do
	local cache = { }
	function Public.GetAbilityName( abilityId )
		local name = cache[abilityId]
		if (not name) then
			name = GetAbilityName(abilityId)
			name = (name ~= "") and ZO_CachedStrFormat(SI_ABILITY_TOOLTIP_NAME, name) or string.format("[#%d]", abilityId)
			cache[abilityId] = name
		end
		return name
	end
end

function Public.PlaySounds( soundId, amplification, delayForNext, ... )
	local sound = soundId and SOUNDS[soundId]
	if (sound) then
		for i = 1, amplification or 1 do
			PlaySound(sound)
		end
	end
	if (type(delayForNext) == "number") then
		local args = { ... }
		if (#args > 0) then
			zo_callLater(function() Public.PlaySounds(unpack(args)) end, delayForNext)
		end
	end
end

function Public.GetTexture( textureId )
	local textures = Internal.Textures
	local texture = type(textureId) == "string" and textures[textureId]
	local l, r, t, b, w, h
	if (type(texture) == "table") then
		texture, l, r, t, b, w, h = unpack(texture)
		if (w and h) then
			l = l / w
			r = r / w
			t = t / h
			b = b / h
		end
	end
	local path = string.format("%sart/%s", Internal.GetRootPath(), texture or textures.clear)
	if (b) then
		return path, l, r, t, b
	else
		return path
	end
end

function Public.SetTexture( control, textureId )
	local path, l, r, t, b = Public.GetTexture(textureId)
	control:SetTexture(path)
	if (b) then
		control:SetTextureCoords(l, r, t, b)
	else
		control:SetTextureCoords(0, 1, 0, 1)
	end
end

do
	local colorDef -- Scratch object, defined here to avoid recreating with each call
	function Public.GetTelegraphColor( isFriendly )
		local colorString = GetSetting(SETTING_TYPE_COMBAT, isFriendly and COMBAT_SETTING_MONSTER_TELLS_FRIENDLY_COLOR or COMBAT_SETTING_MONSTER_TELLS_ENEMY_COLOR)
		if (colorDef) then
			colorDef:Initialize(colorString)
		else
			colorDef = ZO_ColorDef:New(colorString)
		end
		local r, g, b = colorDef:UnpackRGB()
		local brightness = tonumber(GetSetting(SETTING_TYPE_COMBAT, isFriendly and COMBAT_SETTING_MONSTER_TELLS_FRIENDLY_BRIGHTNESS or COMBAT_SETTING_MONSTER_TELLS_ENEMY_BRIGHTNESS))
		return Public.PackRGBA(r, g, b, 0.4 * brightness / 50 + 0.2)
	end
end

function Public.FormatTime( ms, format )
	if (ms < 0) then ms = 0 end

	if (format ~= Public.TIME_FORMAT_COUNTDOWN) then
		ms = ms + 500 -- So that floor() rounds to nearest
	end

	if (format == Public.TIME_FORMAT_COUNTDOWN and ms < 3000) then
		return string.format("%.1fs", ms / 1000)
	elseif (format ~= Public.TIME_FORMAT_LONG) then
		if (ms > 5400000 and format == Public.TIME_FORMAT_COMPACT) then
			return string.format("%dh", zo_round(ms / 3600000))
		elseif (ms > 90000 and format == Public.TIME_FORMAT_COMPACT) then
			return string.format("%dm", zo_round(ms / 60000))
		else
			return string.format("%ds", zo_floor(ms / 1000))
		end
	else
		return string.format(
			"%d:%02d",
			zo_floor(ms / 60000),
			zo_floor(ms / 1000) % 60
		)
	end
end

function Public.CheckUnitForEffect( unitTag, effectAbilityId )
	local count = GetNumBuffs(unitTag)
	for i = 1, count do
		local _, timeStarted, timeEnding, _, stackCount, _, _, _, _, _, abilityId, _, castByPlayer = GetUnitBuffInfo(unitTag, i)
		if (abilityId == effectAbilityId) then
			return timeStarted, timeEnding, stackCount, castByPlayer
		end
	end
	return nil
end

function Public.GetUnitHealthPercent( unitTag, invalidReturnsNil )
	local current, _, effectiveMax = GetUnitPower(unitTag, COMBAT_MECHANIC_FLAGS_HEALTH)
	if (effectiveMax > 0) then
		return 100 * current / effectiveMax
	elseif (invalidReturnsNil) then
		return nil
	else
		return 0
	end
end

function Public.RegisterForFilteredEvent( name, event, callback, ... )
	EVENT_MANAGER:RegisterForEvent(name, event, callback)
	EVENT_MANAGER:AddFilterForEvent(name, event, ...)
end

function Public.ToggleUIFragment( fragment, enable, additionalSceneNames )
	if (enable) then
		HUD_SCENE:AddFragment(fragment)
		HUD_UI_SCENE:AddFragment(fragment)
		SIEGE_BAR_SCENE:AddFragment(fragment)
		SIEGE_BAR_UI_SCENE:AddFragment(fragment)
	else
		HUD_SCENE:RemoveFragment(fragment)
		HUD_UI_SCENE:RemoveFragment(fragment)
		SIEGE_BAR_SCENE:RemoveFragment(fragment)
		SIEGE_BAR_UI_SCENE:RemoveFragment(fragment)
	end

	-- Additional scenes
	if (additionalSceneNames) then
		for _, sceneName in ipairs(additionalSceneNames) do
			local scene = SCENE_MANAGER:GetScene(sceneName)
			if (scene) then
				if (enable) then
					scene:AddFragment(fragment)
				else
					scene:RemoveFragment(fragment)
				end
			end
		end
	end
end

function Public.CoalescedDelayedCall( identifier, delay, func )
	local name = "LCA_Coalesce_" .. identifier
	EVENT_MANAGER:UnregisterForUpdate(name)
	EVENT_MANAGER:RegisterForUpdate(name, delay, func, true)
end


--------------------------------------------------------------------------------
-- Get the distance between two units or a unit and a supplied point
--------------------------------------------------------------------------------

function Public.GetDistanceSquared( x1, y1, z1, x2, y2, z2 )
	local dx = x1 - x2
	local dy = y1 - y2
	local dz = z1 - z2
	return dx * dx + dy * dy + dz * dz
end

function Public.GetDistance( unitTag1, unitTag2, useHeight, validate, useMapPositionInsteadOfRawPosition )
	local GetPosition = useMapPositionInsteadOfRawPosition and GetUnitWorldPosition or GetUnitRawWorldPosition

	local zone1, x1, y1, z1 = GetPosition(unitTag1)
	local zone2, x2, y2, z2

	if (type(unitTag2) == "table") then
		x2, y2, z2 = unpack(unitTag2)
	else
		zone2, x2, y2, z2 = GetPosition(unitTag2)
	end

	if (validate and (zone1 == 0 or zone1 ~= zone2)) then
		return -1
	elseif (useHeight) then
		return zo_sqrt(Public.GetDistanceSquared(x1, y1, z1, x2, y2, z2)) / 100
	else
		return zo_sqrt(Public.GetDistanceSquared(x1, 0, z1, x2, 0, z2)) / 100
	end
end

function Public.IsUnitIdWithinDistance( unitId, distance )
	local unitTag = Public.IdentifyGroupUnitId(unitId or -1)
	if (unitTag and IsUnitInGroupSupportRange(unitTag)) then
		return Public.GetDistance("player", unitTag) <= (distance or 0)
	end
	return false
end


--------------------------------------------------------------------------------
-- Fill in missing options with defaults or update existing options with changes
--------------------------------------------------------------------------------

function Public.PopulateOptions( options, defaults, populateExistingSubtables )
	return Public.MergeTables(options, defaults, populateExistingSubtables and 1 or 0)
end

-- Valid parameter formats:
-- options, changesTable
-- options, "key1", value1, "key2", value2, etc.
function Public.UpdateOptions( options, ... )
	local changes = ...
	if (type(changes) == "table") then
		return Public.MergeTables(options, changes, 2)
	else
		if (type(options) ~= "table") then
			options = { }
		end
		for i = 1, select("#", ...), 2 do
			local key, value = select(i, ...)
			if (key ~= nil) then
				options[key] = value
			end
		end
		return options
	end
end


--------------------------------------------------------------------------------
-- Check for slotted abilities
--------------------------------------------------------------------------------

do
	local HOTBARS = {
		[HOTBAR_CATEGORY_PRIMARY] = EQUIP_SLOT_MAIN_HAND,
		[HOTBAR_CATEGORY_BACKUP] = EQUIP_SLOT_BACKUP_MAIN,
	}

	-- Taunt
	local TAUNT_ABILITIES = {
		[ 28306] = 0, -- Puncture
		[ 38250] = 0, -- Pierce Armor
		[ 38256] = 0, -- Ransack
		[ 38984] = 1, -- Destructive Clench
		[ 38985] = 1, -- Flame Clench
		[ 38989] = 1, -- Frost Clench
		[ 38993] = 1, -- Shock Clench
		[ 39114] = 0, -- Deafening Roar
		[ 39475] = 0, -- Inner Fire
		[ 42056] = 0, -- Inner Rage
		[ 42060] = 0, -- Inner Beast
		[183165] = 0, -- Runic Jolt
		[183430] = 0, -- Runic Sunder
		[186531] = 0, -- Runic Embrace
	}
	local TAUNT_SCRIPT_ID = 12

	-- Pull
	local PULL_ABILITIES = {
		[20492] = true, -- Fiery Grip
		[20496] = true, -- Unrelenting Grip
		[40336] = true, -- Silver Leash
	}
	local PULL_GRIMOIRES = {
		[2] = true, -- Wield Soul
		[3] = true, -- Shield Throw
	}
	local PULL_SCRIPT_ID = 14

	-- Purge
	local AOE_PURGE_ABILITIES = {
		[38571] = true, -- Purge
		[40232] = true, -- Efficient Purge
		[40234] = true, -- Cleanse
	}
	local AOE_PURGE_GRIMOIRES = {
		[ 8] = true, -- Soul Burst
		[10] = true, -- Torchbearer
	}
	local PURGE_SCRIPT_ID = 36

	function Public.DoesPlayerHaveTauntSlotted( )
		for hotbarCategory, equipSlot in pairs(HOTBARS) do
			for i = 3, 7 do
				local actionType = GetSlotType(i, hotbarCategory)
				if (actionType == ACTION_TYPE_ABILITY) then
					local weaponCheck = TAUNT_ABILITIES[GetSlotBoundId(i, hotbarCategory)]
					if (weaponCheck == 0 or (weaponCheck == 1 and GetItemWeaponType(BAG_WORN, equipSlot) == WEAPONTYPE_FROST_STAFF)) then
						return true
					end
				elseif (actionType == ACTION_TYPE_CRAFTED_ABILITY) then
					if (GetCraftedAbilityActiveScriptIds(GetSlotBoundId(i, hotbarCategory)) == TAUNT_SCRIPT_ID) then
						return true
					end
				end
			end
		end
		return false
	end

	function Public.DoesPlayerHaveSingleTargetPullSlotted( )
		for hotbarCategory in pairs(HOTBARS) do
			for i = 3, 7 do
				local actionType = GetSlotType(i, hotbarCategory)
				if (actionType == ACTION_TYPE_ABILITY) then
					if (PULL_ABILITIES[GetSlotBoundId(i, hotbarCategory)]) then
						return true
					end
				elseif (actionType == ACTION_TYPE_CRAFTED_ABILITY) then
					local craftedAbilityId = GetSlotBoundId(i, hotbarCategory)
					if (PULL_GRIMOIRES[craftedAbilityId] and GetCraftedAbilityActiveScriptIds(craftedAbilityId) == PULL_SCRIPT_ID) then
						return true
					end
				end
			end
		end
		return false
	end

	function Public.DoesPlayerHaveTauntOrPullSlotted( )
		return Public.DoesPlayerHaveTauntSlotted() or Public.DoesPlayerHaveSingleTargetPullSlotted()
	end

	function Public.DoesPlayerHaveAoePurgeSlotted( )
		for hotbarCategory in pairs(HOTBARS) do
			for i = 3, 7 do
				local actionType = GetSlotType(i, hotbarCategory)
				if (actionType == ACTION_TYPE_ABILITY) then
					if (AOE_PURGE_ABILITIES[GetSlotBoundId(i, hotbarCategory)]) then
						return true
					end
				elseif (actionType == ACTION_TYPE_CRAFTED_ABILITY) then
					local craftedAbilityId = GetSlotBoundId(i, hotbarCategory)
					if (AOE_PURGE_GRIMOIRES[craftedAbilityId] and select(2, GetCraftedAbilityActiveScriptIds(craftedAbilityId)) == PURGE_SCRIPT_ID) then
						return true
					end
				end
			end
		end
		return false
	end

	function Public.IsNightbladeCutthroatPassiveActive( )
		return (select(6, GetSkillAbilityInfo(GetSpecificSkillAbilityKeysByAbilityId(263606))))
	end
end


--------------------------------------------------------------------------------
-- Cached status: isDamage, isHealer, isTank, isVet
--------------------------------------------------------------------------------

do
	local function updateRole( )
		local role = GetSelectedLFGRole()
		Public.isDamage = role == LFG_ROLE_DPS
		Public.isHealer = role == LFG_ROLE_HEAL
		Public.isTank = role == LFG_ROLE_TANK
	end

	Public.RunAfterInitialLoadscreen(function( )
		local name = "LCA_RoleMonitor"
		EVENT_MANAGER:RegisterForEvent(name, EVENT_GROUP_MEMBER_ROLE_CHANGED, updateRole)
		EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_COMBAT_STATE, updateRole)
		updateRole()
	end)

	Public.MonitorZoneChanges("LCA_DifficultyMonitor", function( )
		Public.isVet = GetCurrentZoneDungeonDifficulty() == DUNGEON_DIFFICULTY_VETERAN
	end)
end


--------------------------------------------------------------------------------
-- Unit ID identification functions
--------------------------------------------------------------------------------

do
	local registrants = { }
	local registered = false
	local groupTags = { }
	local groupIds = { }
	local bossIds = { }
	local playerId = nil

	local unitPrefixes = {
		group = { "LCA_UnitId_G", 1 },
		boss = { "LCA_UnitId_B", 2 },
		player = { "LCA_UnitId_P", 3 },
	}

	local function identify( unitType, unitTag, unitName, unitId )
		if (unitType == 1) then
			local oldUnitId = groupTags[unitTag]
			local oldUnitInfo = groupIds[unitId]
			if (oldUnitId ~= unitId or not oldUnitInfo) then
				if (oldUnitId) then
					groupIds[oldUnitId] = nil
				end
				local name = GetUnitDisplayName(unitTag)
				local unitInfo = oldUnitInfo or { }
				unitInfo.tag = unitTag
				unitInfo.name = name ~= "" and name or unitName
				groupTags[unitTag] = unitId
				groupIds[unitId] = unitInfo
			end
		elseif (unitType == 2 and not bossIds[unitId]) then
			bossIds[unitId] = {
				tag = unitTag,
				name = unitName,
			}
		elseif (unitType == 3) then
			playerId = unitId
		end
	end

	local function toggle( unitPrefix, enable, fullTag )
		local data = unitPrefixes[unitPrefix]
		if (enable) then
			Public.RegisterForFilteredEvent(data[1], EVENT_EFFECT_CHANGED, function( _, _, _, _, unitTag, _, _, _, _, _, _, _, _, unitName, unitId )
				identify(data[2], unitTag, unitName, unitId)
			end, fullTag and REGISTER_FILTER_UNIT_TAG or REGISTER_FILTER_UNIT_TAG_PREFIX, unitPrefix)
		else
			EVENT_MANAGER:UnregisterForEvent(data[1], EVENT_EFFECT_CHANGED)
		end
	end

	function Public.ToggleUnitIdTracking( name, enable )
		if (enable) then
			registrants[name] = true
		else
			registrants[name] = nil
		end

		if (not registered and next(registrants)) then
			registered = true
			Public.ResetUnitIdTracking()
			toggle("group", true)
			toggle("boss", true)
			toggle("player", true, true)
		elseif (registered and not next(registrants)) then
			registered = false
			toggle("group", false)
			toggle("boss", false)
			toggle("player", false)
		end
	end

	function Public.ResetUnitIdTracking( )
		ZO_ClearTable(groupTags)
		ZO_ClearTable(groupIds)
		ZO_ClearTable(bossIds)
		playerId = nil
	end

	function Public.GetPlayerUnitId( )
		return playerId or 0
	end

	function Public.IsUnitIdValid( unitId )
		return unitId and unitId ~= 0
	end

	function Public.IdentifyGroupUnitTag( unitTag )
		return groupTags[unitTag]
	end

	function Public.IdentifyGroupUnitId( unitId, useFallback )
		if (groupIds[unitId]) then
			return groupIds[unitId].tag, groupIds[unitId].name
		elseif (useFallback) then
			if (playerId == unitId) then
				return "player", GetDisplayName()
			else
				return "", string.format("unit%d", unitId)
			end
		else
			return nil
		end
	end

	function Public.IdentifyBossUnitId( unitId, useFallback )
		if (bossIds[unitId]) then
			return bossIds[unitId].tag, bossIds[unitId].name
		elseif (useFallback) then
			return "", string.format("unit%d", unitId)
		else
			return nil
		end
	end

	local ROLE_ICONS = {
		[LFG_ROLE_DPS] = "/esoui/art/lfg/gamepad/lfg_roleicon_dps.dds",
		[LFG_ROLE_TANK] = "/esoui/art/lfg/gamepad/lfg_roleicon_tank.dds",
		[LFG_ROLE_HEAL] = "/esoui/art/lfg/gamepad/lfg_roleicon_healer.dds",
	}

	function Public.IdentifyGroupUnitIdWithRole( ... )
		local unitTag, name = Public.IdentifyGroupUnitId(...)
		local icon = ROLE_ICONS[GetGroupMemberSelectedRole(unitTag)] -- GetGroupMemberSelectedRole returns LFG_ROLE_INVALID if unitTag is invalid
		if (icon) then
			name = zo_iconTextFormat(icon, "85%", "85%", name, true, true)
		end
		return unitTag, name
	end
end


--------------------------------------------------------------------------------
-- Interaction blocking
--------------------------------------------------------------------------------

do
	local isHooked = false
	local rules = { }

	local function shouldBlock( )
		local action, name = GetGameCameraInteractableActionInfo()
		if (action and action ~= "" and name and name ~= "") then
			for _, rule in pairs(rules) do
				if ((not rule.action or Public.MatchStrings(rule.action, action)) and Public.MatchStrings(rule.name, name)) then
					if (rule.callback()) then
						return true
					end
				end
			end
		end
		return false
	end

	local function enableHook( )
		-- Hooking RETICLE:TryHandlingInteraction produces a cosmetic result: the prompt is hidden, but player input is still accepted
		ZO_PreHook(RETICLE, "TryHandlingInteraction", function( _, interactionPossible )
			if (interactionPossible and shouldBlock()) then
				return true
			else
				return false
			end
		end)

		-- Hooking INTERACTIVE_WHEEL_MANAGER:StartInteraction produces a behavioral result: player input is discarded, but the prompt is still shown
		local obj = INTERACTIVE_WHEEL_MANAGER
		local fnName = "StartInteraction"
		local origFn = obj[fnName]
		obj[fnName] = function( ... )
			if (shouldBlock()) then
				return true
			else
				return origFn(...)
			end
		end
	end

	function Public.RegisterInteractionBlock( id, action, name, callback )
		-- id is required
		-- action is optional and may be nil
		-- name and callback are required for registration; omit them to unregister instead

		if (name and callback) then
			rules[id] = { action = action, name = name, callback = callback }
			if (not isHooked) then
				isHooked = true
				enableHook()
			end
		else
			rules[id] = nil
		end
	end

	function Public.UnregisterAllInteractionBlocks( )
		ZO_ClearTable(rules)
	end
end


--------------------------------------------------------------------------------
-- Skill blocking
-- callback params: actionId, slotIndex, hotbarCategory
-- hotbarCategory is non-nil for relevance check, nil for should-block check
--------------------------------------------------------------------------------

do
	local NAME = "LCA_SkillBlocker"
	local HOTBARS = { HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }

	local registrants = { }
	local registered = false
	local isHooked = false
	local eligible = false

	local function hasRelevantAbilitySlotted( )
		for _, hotbarCategory in ipairs(HOTBARS) do
			for slotIndex = 3, 8 do
				for _, callback in pairs(registrants) do
					if (callback(GetSlotBoundId(slotIndex, hotbarCategory), slotIndex, hotbarCategory)) then
						return true
					end
				end
			end
		end
		return false
	end

	local function enableHook( )
		ZO_PreHook("ZO_ActionBar_CanUseActionSlots", function( )
			if (eligible) then
				local slotIndex = tonumber(debug.traceback():match("ACTION_BUTTON_(%d)"))
				for _, callback in pairs(registrants) do
					if (callback(GetSlotBoundId(slotIndex), slotIndex)) then
						ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, SI_RESPECRESULT6)
						ZO_ActionBar_OnActionButtonUp(slotIndex)
						return true
					end
				end
			end
		end)
	end

	local function combatStateChange( _, inCombat )
		eligible = inCombat and hasRelevantAbilitySlotted()
		if (eligible and not isHooked) then
			isHooked = true
			enableHook()
		end
	end

	-- Omit callback to unregister
	function Public.RegisterInCombatSkillBlock( name, callback )
		if (type(callback) ~= "function") then
			callback = nil
		end
		if (registrants[name] ~= callback) then
			registrants[name] = callback
			if (next(registrants)) then
				if (not registered) then
					registered = true
					EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_COMBAT_STATE, combatStateChange)
				end
				-- Always re-run the eligibility check
				combatStateChange(nil, IsUnitInCombat("player"))
			elseif (not next(registrants) and registered) then
				registered = false
				EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_PLAYER_COMBAT_STATE)
				eligible = false
			end
		end
	end
end
