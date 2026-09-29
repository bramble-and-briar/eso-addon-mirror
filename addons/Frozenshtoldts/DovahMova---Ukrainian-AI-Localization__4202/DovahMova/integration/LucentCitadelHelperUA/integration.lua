-- =================================================================================================
-- Lucent Citadel Helper: українські імена босів.
-- LCH порівнює ім'я боса з LCH.data.*Name, які заповнюються з рядків LCH_* під час завантаження
-- LCH (ще англійською), тому після перекладу рядків оновлюємо й LCH.data.
-- =================================================================================================

local DovahMova = DovahMova

DovahMova.RegisterIntegration({
	name = "LucentCitadelHelper",
	IsAvailable = function()
		return LCH ~= nil
	end,
	Apply = function()
		DovahMova.Util.CreateStringIds(DovahMova.IntegrationStrings.LucentCitadelHelper, 1)
		if LCH.data then
			LCH.data.zilyessetName = string.lower(GetString(LCH_Zilyesset))
			LCH.data.orphicName = string.lower(GetString(LCH_Orphic))
			LCH.data.xorynName = string.lower(GetString(LCH_Xoryn))
		end
	end,
})
