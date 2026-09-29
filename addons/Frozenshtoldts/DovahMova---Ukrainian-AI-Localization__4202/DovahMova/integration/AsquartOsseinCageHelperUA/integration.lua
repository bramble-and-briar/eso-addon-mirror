-- =================================================================================================
-- Asquart's Ossein Cage Helper: українські імена босів і NPC.
-- AOCH порівнює імена юнітів з AOCH.data.*_name, які заповнюються з рядків AOCH_* під час
-- завантаження AOCH (ще англійською), тому після перекладу рядків оновлюємо й AOCH.data.
-- =================================================================================================

local DovahMova = DovahMova

-- Поле AOCH.data -> рядок AOCH_*
local DATA_NAME_FIELDS = {
	carrion_shield_synergy_name = "AOCH_CarrionShield",
	spectral_revenant_name = "AOCH_SpectralRevenant",
	dreadful_abductor_name = "AOCH_Abductor",
	gedna_relvel_name = "AOCH_GednaRelvel",
	tortured_ranyu_name = "AOCH_TorturedRanyu",
	blood_drinker_thisa_name = "AOCH_BloodDrkinerThisa",
	hall_of_fleshcraft_name = "AOCH_ShaperOfFlesh",
	fleshspawn_name = "AOCH_Fleshspawn",
	channeler_name = "AOCH_Channeler",
	harvester_name = "AOCH_Harvester",
	daedroth_name = "AOCH_Daedroth",
	jynorah_name = "AOCH_Jynorah",
	skorknif_name = "AOCH_Skorknif",
	valneer_name = "AOCH_Valneer",
	myrinax_name = "AOCH_Myrinax",
	overfiend_kazpian_name = "AOCH_Kazpian",
	agonizer_bomb_name = "AOCH_AgonizerBomb",
}

DovahMova.RegisterIntegration({
	name = "AsquartOsseinCageHelper",
	IsAvailable = function()
		return AOCH ~= nil
	end,
	Apply = function()
		DovahMova.Util.CreateStringIds(DovahMova.IntegrationStrings.AsquartOsseinCageHelper, 1)
		if AOCH.data then
			for field, stringIdName in pairs(DATA_NAME_FIELDS) do
				AOCH.data[field] = GetString(_G[stringIdName])
			end
		end
	end,
})
