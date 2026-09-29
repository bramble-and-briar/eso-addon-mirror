-- =================================================================================================
-- Назви навичок системи чемпіонства (ЧП).
-- =================================================================================================

local DovahMova = DovahMova
local Util = DovahMova.Util

local Champion = {}
DovahMova.Champion = Champion

local STRING_OVERRIDE_VERSION = 10
local originalTooltipName

local function GetMode()
	return DovahMova.settings.ShowChampionTooltip
end

local function FormatName(abilityId, ukrainianName)
	local englishName = abilityId and DovahMova.db.Abilities[abilityId]
	if not ukrainianName or GetMode() == DovahMova.MODE_UA then
		return ukrainianName
	end
	return Util.FormatBilingual(ukrainianName, englishName, GetMode())
end

local function PrepareTooltip(abilityId, ukrainianName)
	local text = FormatName(abilityId, ukrainianName)
	if text and text ~= ukrainianName then
		SafeAddString(SI_ABILITY_TOOLTIP_NAME, text, STRING_OVERRIDE_VERSION)
	end
end

local function RestoreTooltip()
	SafeAddString(SI_ABILITY_TOOLTIP_NAME, originalTooltipName, STRING_OVERRIDE_VERSION)
end

local installed = false

function Champion.Install()
	if installed then
		return
	end
	installed = true
	originalTooltipName = GetString(SI_ABILITY_TOOLTIP_NAME)

	local originalGetChampionSkillName = GetChampionSkillName
	GetChampionSkillName = function(championSkillId, ...)
		local ukrainianName = originalGetChampionSkillName(championSkillId, ...)
		return FormatName(GetChampionAbilityId(championSkillId), ukrainianName) or ""
	end

	local function HookTooltipMethod(methodName, getAbilityAndName)
		local original = ChampionSkillTooltip[methodName]
		ChampionSkillTooltip[methodName] = function(self, ...)
			PrepareTooltip(getAbilityAndName(...))
			original(self, ...)
			RestoreTooltip()
		end
	end

	HookTooltipMethod("SetChampionSkill", function(championSkillId)
		return GetChampionAbilityId(championSkillId), originalGetChampionSkillName(championSkillId)
	end)
	HookTooltipMethod("SetAbilityId", function(abilityId)
		return abilityId, GetAbilityName(abilityId)
	end)

	ZO_PreHook(CHAMPION_PERKS, "LayoutRightTooltipChampionSkillAbility", function(_, abilityId, ukrainianName)
		PrepareTooltip(abilityId, ukrainianName)
	end)
	ZO_PostHook(CHAMPION_PERKS, "LayoutRightTooltipChampionSkillAbility", RestoreTooltip)
end
