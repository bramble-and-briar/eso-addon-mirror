-- =================================================================================================
-- Qcell's Rockgrove Helper: українські імена босів.
-- QRH шукає в імені боса підрядки з QRH.data.*_name (англійською). Підставляємо імена з ua.lang.
-- =================================================================================================

local DovahMova = DovahMova

local UKRAINIAN_NAMES = {
	oaxiltso_name = "Оаксілтсо",
	bahsei_name = "Бахсей",               -- «Вісниця Полум'я Бахсей»
	xalvakka_name = "Ксалвакка",
	xalvakka_volatile_shell_name = "Нестабільна Оболонка",
}

DovahMova.RegisterIntegration({
	name = "QcellRockgroveHelper",
	IsAvailable = function()
		return QRH ~= nil and QRH.data ~= nil
	end,
	Apply = function()
		for field, name in pairs(UKRAINIAN_NAMES) do
			QRH.data[field] = string.lower(name)
		end
	end,
})
