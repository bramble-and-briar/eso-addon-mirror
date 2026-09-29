-- =================================================================================================
-- MapPins: риболовні місця на карті.
-- MapPins визначає, яку рибу ще не спіймано, шукаючи в назвах критеріїв досягнень слово типу води
-- (MapPins_Localization[мова].Lake тощо). У його lang/ua.lua ці слова («Озеро», «Річка»...)
-- не збігаються з текстом ua.lang, де критерії мають вигляд «Болотяна мінога (Озерна)».
-- Замінюємо їх на слова з ua.lang.
-- =================================================================================================

local DovahMova = DovahMova

-- Тип води -> слово в дужках у назвах критеріїв рибальських досягнень (ua.lang)
local WATER_TYPE_WORDS = {
	Lake = "Озерна",
	Foul = "Стічна",
	River = "Річкова",
	Salt = "Морська",
	Oily = "Масляниста",
	Mystic = "Містична",
	Running = "Проточна",
}

DovahMova.RegisterIntegration({
	name = "MapPins",
	IsAvailable = function()
		return MapPins_Localization ~= nil
	end,
	Apply = function()
		local localization = MapPins_Localization.ua
		if not localization then
			localization = {}
			MapPins_Localization.ua = localization
		end
		for waterType, word in pairs(WATER_TYPE_WORDS) do
			localization[waterType] = word
		end
	end,
})
