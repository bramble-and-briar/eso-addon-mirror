-- =================================================================================================
-- CrutchAlerts: українські імена босів.
--
-- CrutchAlerts будує таблиці порогів здоров'я босів (BossHealthBar.thresholds) під час свого
-- завантаження, коли рядки CRUTCH_BHB_* ще англійські (мовного файлу lang/ua.lua немає).
-- В українському клієнті GetUnitName повертає українське ім'я, тож пороги не знаходяться.
-- Рішення: перекладаємо рядки CRUTCH_BHB_* і додаємо в таблиці порогів ключі з українськими іменами.
-- =================================================================================================

local DovahMova = DovahMova

--- Додає до таблиці порогів запис під українським ім'ям боса.
local function AddThresholdAlias(thresholds, englishKey, ukrainianName)
	if not thresholds or not thresholds[englishKey] then
		return
	end
	-- Так само CrutchAlerts формує ключ з імені юніта (BossHealthBarAPI.GetBossThresholds)
	local ukrainianKey = zo_strformat(SI_UNIT_NAME, ukrainianName)
	if not thresholds[ukrainianKey] then
		thresholds[ukrainianKey] = thresholds[englishKey]
	end
end

DovahMova.RegisterIntegration({
	name = "CrutchAlerts",
	IsAvailable = function()
		return CrutchAlerts ~= nil
	end,
	Apply = function()
		local bossHealthBar = CrutchAlerts.BossHealthBar or {}
		for stringIdName, names in pairs(DovahMova.IntegrationStrings.CrutchAlertsBossNames) do
			ZO_CreateStringId(stringIdName, names.ua)

			-- Ключ, під яким CrutchAlerts зберіг пороги (Crutch.GetCapitalizedString)
			local englishKey = zo_strformat("<<C:1>>", names.en)
			local variants = { names.ua }
			for _, alternative in ipairs(names.alt or {}) do
				variants[#variants + 1] = alternative
			end
			for _, ukrainianName in ipairs(variants) do
				AddThresholdAlias(bossHealthBar.thresholds, englishKey, ukrainianName)
				AddThresholdAlias(bossHealthBar.eaThresholds, englishKey, ukrainianName)
			end
		end
	end,
})
