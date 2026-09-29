-- =================================================================================================
-- HarvestMap: українські рядки і назви об'єктів.
-- HarvestMap завантажує Localization/$(language).lua; для "ua" файлу немає, тому підміняємо
-- Harvest.GetLocalization, перестворюємо назви клавіш і додаємо українські назви об'єктів,
-- за якими HarvestMap розпізнає важкі мішки, схованки тощо. Виконується до ініціалізації HarvestMap.
-- =================================================================================================

local DovahMova = DovahMova

local UI_STRING_IDS = {
	"SI_BINDING_NAME_HARVEST_SHOW_FILTER",
	"SI_BINDING_NAME_SKIP_TARGET",
	"SI_BINDING_NAME_TOGGLE_WORLDPINS",
	"SI_BINDING_NAME_TOGGLE_MAPPINS",
	"SI_BINDING_NAME_TOGGLE_MINIMAPPINS",
	"SI_BINDING_NAME_HARVEST_SHOW_PANEL",
	"HARVESTFARM_GENERATOR",
	"HARVESTFARM_EDITOR",
	"HARVESTFARM_SAVE",
}

DovahMova.RegisterIntegration({
	name = "HarvestMap",
	IsAvailable = function()
		return Harvest ~= nil and Harvest.GetLocalization ~= nil
	end,
	Prepare = function()
		local strings = DovahMova.IntegrationStrings.HarvestMap

		local originalGetLocalization = Harvest.GetLocalization
		Harvest.GetLocalization = function(tag)
			return strings[tag] or originalGetLocalization(tag)
		end

		for _, stringIdName in ipairs(UI_STRING_IDS) do
			if strings[stringIdName] then
				ZO_CreateStringId(stringIdName, strings[stringIdName])
			end
		end

		local pinTypes = Harvest.interactableName2PinTypeId
		if pinTypes then
			for name, pinTypeField in pairs(DovahMova.IntegrationStrings.HarvestMapInteractables) do
				pinTypes[zo_strlower(name)] = Harvest[pinTypeField]
			end
		end
	end,
})
