-- =================================================================================================
-- Votan's Fisherman: українські рядки і розпізнавання типу води риболовних місць.
-- Тип води Votan's Fisherman визначає за підрядками в назві місця для лову (InteractToLootType).
-- Назви з ua.lang: «Місце для лову в озері», «Стічне місце для лову», «Місце для лову в морі» тощо.
-- =================================================================================================

local DovahMova = DovahMova

local LOOT_TYPE_FOUL, LOOT_TYPE_RIVER, LOOT_TYPE_LAKE, LOOT_TYPE_OCEAN = 1, 2, 3, 4

-- Підрядок назви місця для лову (у нижньому регістрі) -> тип води
local INTERACT_STEMS = {
	["стічн"] = LOOT_TYPE_FOUL,    -- стічне
	["масл"] = LOOT_TYPE_FOUL,     -- замаслене
	["річк"] = LOOT_TYPE_RIVER,
	["річц"] = LOOT_TYPE_RIVER,    -- в річці
	["озер"] = LOOT_TYPE_LAKE,     -- в озері
	["мор"] = LOOT_TYPE_OCEAN,     -- в морі
	["містичн"] = LOOT_TYPE_OCEAN, -- містичне
}

DovahMova.RegisterIntegration({
	name = "VotansFisherman",
	IsAvailable = function()
		return VOTANS_FISHERMAN ~= nil and VOTANS_FISHERMAN.InteractToLootType ~= nil
	end,
	Prepare = function()
		-- До ініціалізації Votan's Fisherman: з цих рядків він сам будує таблиці типів води
		DovahMova.Util.OverrideStrings(DovahMova.IntegrationStrings.VotansFisherman, 1)
	end,
	Apply = function()
		local fisherman = VOTANS_FISHERMAN
		for stem, lootType in pairs(INTERACT_STEMS) do
			fisherman.InteractToLootType[stem] = lootType
		end
		for lootType = LOOT_TYPE_FOUL, LOOT_TYPE_OCEAN do
			fisherman.ActionToLootType[GetString("SI_FISHERMAN_ACTIONNAME", lootType)] = lootType
		end
		if fisherman.RefreshPins then
			fisherman:RefreshPins()
		end
	end,
})
