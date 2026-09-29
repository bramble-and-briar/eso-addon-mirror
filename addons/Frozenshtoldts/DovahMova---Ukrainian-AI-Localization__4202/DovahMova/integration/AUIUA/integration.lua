-- =================================================================================================
-- AUI (Advanced UI): українські рядки.
-- AUI завантажує лише L10n/$(language).lua, тож в українському клієнті AUI.L10n порожня і
-- замість текстів показуються ключі. Заповнюємо AUI.L10n до ініціалізації AUI (Prepare),
-- тож меню і назви клавіш будуються вже українською.
-- =================================================================================================

local DovahMova = DovahMova

DovahMova.RegisterIntegration({
	name = "AUI",
	IsAvailable = function()
		return AUI ~= nil and AUI.L10n ~= nil
	end,
	Prepare = function()
		for key, text in pairs(DovahMova.IntegrationStrings.AUI) do
			AUI.L10n[key] = text
		end
	end,
})
