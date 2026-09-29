-- =================================================================================================
-- PotionMaker: українська мова інтерфейсу та назв ефектів.
-- Мова завантажується до ініціалізації PotionMaker: він сам побачить мову "ua"
-- (PotMaker.languageSupported) і застосує мовні налаштування.
-- =================================================================================================

local DovahMova = DovahMova

DovahMova.RegisterIntegration({
	name = "PotionMaker",
	IsAvailable = function()
		return PotMaker ~= nil and PotMaker.LoadLanguage ~= nil
	end,
	Prepare = function()
		PotMaker:LoadLanguage(DovahMova.IntegrationStrings.PotionMaker)

		local language = PotMaker.language
		DovahMova.Util.CreateStringIds({
			SI_BINDING_NAME_POTIONMAKER_SEARCH = language.search,
			SI_BINDING_NAME_POTIONMAKER_SEARCH_WRITS = GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES212),
			SI_BINDING_NAME_POTIONMAKER_SEARCH_FAVORITS = language.favorites,
		})
	end,
})
