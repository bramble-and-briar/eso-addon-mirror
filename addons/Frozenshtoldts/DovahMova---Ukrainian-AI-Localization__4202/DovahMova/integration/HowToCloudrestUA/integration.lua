-- =================================================================================================
-- HowToCloudrest: українські імена босів Хмарної Відпочинку (Cloudrest).
-- HowToCloudrest шукає в іменах юнітів англійські слова ("Siroria", "Relequen"...), щоб стежити
-- за смертю міні-босів і визначати бій із сайд-босами. Перекладаємо імена назад на англійські.
-- Імена взято з ua.lang.
-- =================================================================================================

local DovahMova = DovahMova

local ENGLISH_BOSS_NAMES = {
	["Сірорія"] = "Siroria",
	["Релеквен"] = "Relequen",
	["Ґаленве"] = "Galenwe",
	["Сілаеда"] = "Silaeda",
	["Беланаріл"] = "Belanaril",
	["Беланарл"] = "Belanaril",
	["Фаларіель"] = "Falarielle",
}

local MINI_BOSSES = { Siroria = true, Relequen = true, Galenwe = true }
local SIDE_BOSSES = { Silaeda = true, Belanaril = true, Falarielle = true }

local function ToEnglishName(unitName)
	for ukrainianName, englishName in pairs(ENGLISH_BOSS_NAMES) do
		if zo_plainstrfind(unitName, ukrainianName) then
			return englishName
		end
	end
	return unitName
end

--- Аналог HowToCloudrest.RegisterForAllMiniDeaths з підтримкою українських імен.
local function RegisterForAllMiniDeaths()
	local addonName = HowToCloudrest.name
	for i = 1, MAX_BOSSES do
		local unitTag = "boss" .. i
		if DoesUnitExist(unitTag) then
			local bossName = ToEnglishName(GetUnitName(unitTag))
			if MINI_BOSSES[bossName] then
				local eventName = addonName .. "BossDeath" .. i
				EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_UNIT_DEATH_STATE_CHANGED)
				EVENT_MANAGER:RegisterForEvent(eventName, EVENT_UNIT_DEATH_STATE_CHANGED, HowToCloudrest.OnBossDeath)
				EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, "boss")
			end
			if SIDE_BOSSES[bossName] then
				HTC.isSideBoss = true
			end
		end
	end
end

DovahMova.RegisterIntegration({
	name = "HowToCloudrest",
	IsAvailable = function()
		return HowToCloudrest ~= nil and HowToCloudrest.RegisterForAllMiniDeaths ~= nil
	end,
	Apply = function()
		HowToCloudrest.RegisterForAllMiniDeaths = RegisterForAllMiniDeaths

		local originalHideMiniUI = HowToCloudrest.HideMiniUI
		HowToCloudrest.HideMiniUI = function(miniName, ...)
			return originalHideMiniUI(ToEnglishName(miniName), ...)
		end
	end,
})
