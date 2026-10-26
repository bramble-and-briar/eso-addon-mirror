local ADDON = "DelugeBlame"

local DELUGE_IDS = {
	[174959] = "Normal",
	[174960] = "Veteran",
	[174961] = "Hard Mode",
}
local DEDUPE_MS = 1000
local lastNotice = {}
local DEBUG = true

local function OnEffectChanged(_, changeType, effectSlot, effectName, unitTag, beginTime, endTime,
                               stackCount, iconName, buffType, effectType, abilityType,
                               statusEffectType, unitName, unitId, abilityId)
	if changeType ~= EFFECT_RESULT_FADED then return end
	if unitTag ~= "player" and unitTag:sub(1, 5) ~= "group" then return end
	if IsUnitDead(unitTag) then if DEBUG then d("[KDB] debug: " .. GetUnitDisplayName(unitTag) .. " was dead!") end return end
	if IsUnitSwimming(unitTag) then if DEBUG then d("[KDB] debug: " .. GetUnitDisplayName(unitTag) .. " was swimming, ok") end return end

	local account = GetUnitDisplayName(unitTag)
	local now = GetGameTimeMilliseconds()

	if lastNotice[account] and now - lastNotice[account] < DEDUPE_MS then return end
	lastNotice[account] = now
	d(("[KDB] %s was not swimming when deluge ends."):format(account))
end

local function OnLoaded(_, addonName)
	if addonName ~= ADDON then return end
	EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)
	for id in pairs(DELUGE_IDS) do
		local name = ADDON .. "_" .. id
		EVENT_MANAGER:RegisterForEvent(name, EVENT_EFFECT_CHANGED, OnEffectChanged)
		EVENT_MANAGER:AddFilterForEvent(name, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, id)
	end
end

EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, OnLoaded)