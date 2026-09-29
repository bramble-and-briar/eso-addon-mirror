-- =================================================================================================
-- AsylumTracker: запуск в українському клієнті.
--
-- AsylumTracker.Initialize() (у його EVENT_ADD_ON_LOADED) викликає
-- AST.lang[GetCVar("language.2")].LoadStrings(). Модуля "ua" у нього немає, тож без виправлення
-- ініціалізація падає з помилкою «attempt to index a nil value».
-- Додаємо порожній модуль "ua" ще під час завантаження файлів, до ініціалізації AsylumTracker;
-- англійські рядки AsylumTracker завантажує завжди, тож вони й використовуються.
-- =================================================================================================

local DovahMova = DovahMova

DovahMova.RegisterIntegration({
	name = "AsylumTracker",
	IsAvailable = function()
		return AsylumTracker ~= nil and AsylumTracker.lang ~= nil
	end,
	Prepare = function()
		AsylumTracker.lang.ua = AsylumTracker.lang.ua or { LoadStrings = function() end }
	end,
})
