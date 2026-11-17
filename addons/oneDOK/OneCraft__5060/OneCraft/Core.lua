OneCraft = {}
local O = OneCraft
O.name, O.apiVersion = "OneCraft", 101051
O.Alchemy = {effects = {}, selectedEffects = {}, reagents = {}, inventory = {}, recipes = {}, selected = {}, kind = 1, level = 1}
O.Enchanting = {selection = {equipment = "weapon", level = 1, effect = false, quality = 1}, inventory = {}}
O.Alchemy.emptyTexture = "EsoUI/Art/Crafting/crafting_alchemy_trait_slot.dds"
O.noneTexture = "EsoUI/Art/Crafting/crafting_smithing_noTrait.dds"
O.isRussian = GetCVar("language.2") == "ru"
O.text = O.isRussian and {
    noEffect = "Без эффекта", effect = "Эффект %d", choose = "Выберите эффект.",
    compatible = "Доступны только эффекты, совместимые с выбранными выше.",
    unsupported = "OneCraft: эта версия API не поддерживается.",
    recipes = "Рецепты", recipeHint = "Все рецепты с выбранными эффектами", close = "Закрыть",
    crafts = "Крафтов: %d",
} or {
    noEffect = "No effect", effect = "Effect %d", choose = "Select an effect.",
    compatible = "Only effects compatible with the selections above are available.",
    unsupported = "OneCraft: unsupported API version.",
    recipes = "Recipes", recipeHint = "All recipes with the selected effects", close = "Close",
    crafts = "Crafts: %d",
}
for _, A in ipairs({O.Alchemy, O.Enchanting}) do
    A.name = O.name
    A.apiVersion = O.apiVersion
    function A.ItemLink(id)
        return string.format("|H0:item:%d:20:5:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", id)
    end
    function A.IsBusy() return ZO_CraftingUtils_IsPerformingCraftProcess() end
    function A.Contains(list, value)
        for _, entry in ipairs(list) do if entry == value then return true end end
        return false
    end
end
function O.Enchanting.CopySelection(source)
    source = source or O.Enchanting.selection
    return {level = source.level, equipment = source.equipment, effect = source.effect, quality = source.quality}
end
