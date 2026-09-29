-- =================================================================================================
-- Назви вмінь: вікно навичок (українська або англійська) та спливаючі вікна (UA або UA (EN)).
-- =================================================================================================

local DovahMova = DovahMova
local Util = DovahMova.Util

local Abilities = {}
DovahMova.Abilities = Abilities

local STRING_OVERRIDE_VERSION = 10
local originalStrings = {}

local function GetEnglishName(abilityId)
	return abilityId and DovahMova.db.Abilities[abilityId]
end

local function IsMenuEnglish()
	return DovahMova.settings.ShowAbilitiesMenu == DovahMova.MODE_EN
end

--- Замінює українську назву вміння в текстовому елементі на англійську.
local function ReplaceNameInLabel(label, abilityId)
	local englishName = GetEnglishName(abilityId)
	if label and englishName then
		label:SetText(Util.PlainReplace(label:GetText(), GetAbilityName(abilityId), englishName))
	end
end

local function GetEntryAbilityId(skillData)
	return skillData:GetPointAllocator():GetProgressionData():GetAbilityId()
end

-- -------------------------------------------------------------------------------------------------
-- Вікно навичок
-- -------------------------------------------------------------------------------------------------

local function InstallSkillsWindowHooks()
	local originalAbilityEntrySetup = ZO_Skills_AbilityEntry_Setup
	ZO_Skills_AbilityEntry_Setup = function(control, skillData)
		originalAbilityEntrySetup(control, skillData)
		if IsMenuEnglish() then
			ReplaceNameInLabel(control:GetNamedChild("Name"), GetEntryAbilityId(skillData))
		end
	end

	local originalCompanionEntrySetup = ZO_Skills_CompanionSkillEntry_Setup
	ZO_Skills_CompanionSkillEntry_Setup = function(control, skillData)
		originalCompanionEntrySetup(control, skillData)
		if IsMenuEnglish() then
			ReplaceNameInLabel(control:GetNamedChild("Name"), GetEntryAbilityId(skillData))
		end
	end

	ZO_PostHookHandler(ZO_SkillsConfirmDialog, "OnShow", function()
		if IsMenuEnglish() and ZO_SkillsConfirmDialog.data then
			ReplaceNameInLabel(ZO_SkillsConfirmDialog:GetNamedChild("AbilityName"), ZO_SkillsConfirmDialog.data:GetAbilityId())
		end
	end)

	ZO_PostHookHandler(ZO_SkillsMorphDialog, "OnShow", function()
		local baseAbility = ZO_SkillsMorphDialog:GetNamedChild("BaseAbility")
		local progressionData = baseAbility and baseAbility.skillProgressionData
		local englishName = progressionData and GetEnglishName(progressionData:GetAbilityId())
		if IsMenuEnglish() and englishName then
			ZO_SkillsMorphDialog.desc:SetText(zo_strformat(SI_SKILLS_SELECT_MORPH, englishName))
		end
	end)

	-- Порадник навичок
	local advisor = ZO_SKILLS_ADVISOR_SUGGESTION_WINDOW
	local originalAdvisorSetup = advisor.SetupAbilityEntry
	advisor.SetupAbilityEntry = function(manager, control, skillProgressionData)
		originalAdvisorSetup(manager, control, skillProgressionData)
		if IsMenuEnglish() then
			ReplaceNameInLabel(control:GetNamedChild("Name"), skillProgressionData:GetAbilityId())
		end
	end

	-- Геймпадний інтерфейс бере назви напряму з даних навичок
	local originalGetName = ZO_SkillProgressionData_Base.GetName
	function ZO_SkillProgressionData_Base:GetName()
		local englishName = IsMenuEnglish() and IsInGamepadPreferredMode() and GetEnglishName(self:GetAbilityId())
		return englishName or originalGetName(self)
	end

	local originalGetFormattedName = ZO_SkillProgressionData_Base.GetFormattedName
	function ZO_SkillProgressionData_Base:GetFormattedName(formatter)
		local englishName = IsMenuEnglish() and IsInGamepadPreferredMode() and GetEnglishName(self:GetAbilityId())
		if englishName then
			return ZO_CachedStrFormat(formatter or SI_ABILITY_NAME, englishName)
		end
		return originalGetFormattedName(self, formatter)
	end
end

-- -------------------------------------------------------------------------------------------------
-- Спливаючі вікна
-- -------------------------------------------------------------------------------------------------

local function RestoreStrings()
	SafeAddString(SI_ABILITY_NAME_AND_RANK, originalStrings.SI_ABILITY_NAME_AND_RANK, STRING_OVERRIDE_VERSION)
	SafeAddString(SI_ABILITY_TOOLTIP_NAME, originalStrings.SI_ABILITY_TOOLTIP_NAME, STRING_OVERRIDE_VERSION)
end

local function PrepareStrings(abilityId)
	local mode = DovahMova.settings.ShowAbilitiesTooltip
	local englishName = GetEnglishName(abilityId)
	if mode == DovahMova.MODE_UA or not englishName then
		return
	end
	local text = Util.FormatBilingual(GetAbilityName(abilityId), englishName, mode)
	SafeAddString(SI_ABILITY_NAME_AND_RANK, Util.PlainReplace(originalStrings.SI_ABILITY_NAME_AND_RANK, "<<1>>", text), STRING_OVERRIDE_VERSION)
	SafeAddString(SI_ABILITY_TOOLTIP_NAME, text, STRING_OVERRIDE_VERSION)
end

-- Визначення abilityId за аргументами відповідних методів SkillTooltip
local function ActiveSkillAbilityId(skillType, skillLineIndex, skillIndex, morphChoice, ...)
	local overrideAbilityId = select(10, ...)
	if overrideAbilityId then
		return overrideAbilityId
	end
	return GetSpecificSkillAbilityInfo(skillType, skillLineIndex, skillIndex, morphChoice, 1)
end

local function PassiveSkillAbilityId(skillType, skillLineIndex, skillIndex, rank)
	return GetSpecificSkillAbilityInfo(skillType, skillLineIndex, skillIndex, 0, rank)
end

local function NewSkillAbilityId(skillType, skillLineIndex, skillIndex)
	return GetSpecificSkillAbilityInfo(skillType, skillLineIndex, skillIndex, 0, 1)
end

local function DirectAbilityId(abilityId)
	return abilityId
end

local function HookTooltipMethod(methodName, getAbilityId)
	local original = SkillTooltip[methodName]
	SkillTooltip[methodName] = function(self, ...)
		PrepareStrings(getAbilityId(...))
		original(self, ...)
		RestoreStrings()
	end
end

local function InstallTooltipHooks()
	originalStrings.SI_ABILITY_NAME_AND_RANK = GetString(SI_ABILITY_NAME_AND_RANK)
	originalStrings.SI_ABILITY_TOOLTIP_NAME = GetString(SI_ABILITY_TOOLTIP_NAME)

	HookTooltipMethod("SetActiveSkill", ActiveSkillAbilityId)
	HookTooltipMethod("SetPassiveSkill", PassiveSkillAbilityId)
	HookTooltipMethod("SetSkillAbility", NewSkillAbilityId)
	HookTooltipMethod("SetCompanionSkill", DirectAbilityId)
	HookTooltipMethod("SetAbilityId", DirectAbilityId)
end

local installed = false

function Abilities.Install()
	if installed then
		return
	end
	installed = true
	InstallSkillsWindowHooks()
	InstallTooltipHooks()
end

--- Оновлює вікна навичок після зміни налаштування.
function Abilities.Refresh()
	SKILLS_WINDOW:RebuildSkillLineList()
	COMPANION_SKILLS_DATA_MANAGER:RebuildSkillsData()
end
