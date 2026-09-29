-- =================================================================================================
-- Dustman: українські рядки (Dustman завантажує Language/$(language).lua, файлу ua у нього немає).
-- Застосовуються до ініціалізації Dustman, тож його меню будується українською.
-- =================================================================================================

local DovahMova = DovahMova

DovahMova.RegisterIntegration({
	name = "Dustman",
	IsAvailable = function()
		return Dustman ~= nil
	end,
	Prepare = function()
		DovahMova.Util.CreateStringIds(DovahMova.IntegrationStrings.Dustman, 1)
	end,
})
