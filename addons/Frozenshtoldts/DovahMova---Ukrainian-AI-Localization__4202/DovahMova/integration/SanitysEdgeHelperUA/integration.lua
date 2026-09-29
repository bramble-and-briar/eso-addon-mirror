-- =================================================================================================
-- Sanity's Edge Helper: українські імена босів.
-- SEH порівнює ім'я боса з SEH.data.*Name, які заповнюються з рядків SEH_* під час завантаження
-- SEH (ще англійською), тому після перекладу рядків оновлюємо й SEH.data.
-- =================================================================================================

local DovahMova = DovahMova

DovahMova.RegisterIntegration({
	name = "SanitysEdgeHelper",
	IsAvailable = function()
		return SEH ~= nil
	end,
	Apply = function()
		DovahMova.Util.CreateStringIds(DovahMova.IntegrationStrings.SanitysEdgeHelper, 1)
		if SEH.data then
			SEH.data.yaseylaName = string.lower(GetString(SEH_Yaseyla))
			SEH.data.chimeraName = string.lower(GetString(SEH_Chimera))
			SEH.data.ansuulName = string.lower(GetString(SEH_Ansuul))
		end
	end,
})
