DoNotLearn = DoNotLearn or {}
DoNotLearn.version = "1.2.3"
DoNotLearn.name = "Do Not Learn"
DoNotLearn.defaults = {
    blockRecipes = true,
    blockFurnishings = true,
    blockMotifs = true,
    blockScripts = true,
    blockStylePages = false,
    blockRuneboxes = false,
}
DoNotLearn.NOTHING = 0
DoNotLearn.RECIPE = 1
DoNotLearn.FURNISHINGPLAN = 2
DoNotLearn.MOTIF = 3
DoNotLearn.SCRIBING = 4
DoNotLearn.STYLEPAGE = 5
DoNotLearn.RUNEBOX = 6
DoNotLearn.override = false

local function initLearnAnywayTranslations() 
  local lang = GetCVar("Language.2")
  if lang == "en" then ZO_CreateStringId("SI_LEARN_ANYWAY", "Learn Anyway") return end
  if lang == "de" then ZO_CreateStringId("SI_LEARN_ANYWAY", "Trotzdem Lernen") return end
  if lang == "fr" then ZO_CreateStringId("SI_LEARN_ANYWAY", "Apprendre Quand Même") return end
  if lang == "ru" then ZO_CreateStringId("SI_LEARN_ANYWAY", "Всё Равно Изучить") return end
  if lang == "ja" then ZO_CreateStringId("SI_LEARN_ANYWAY", "それでも習得する") return end
  if lang == "zh" then ZO_CreateStringId("SI_LEARN_ANYWAY", "仍然学习") return end
  if lang == "es" then ZO_CreateStringId("SI_LEARN_ANYWAY", "Aprender de todos modos") return end
  if lang == "it" then ZO_CreateStringId("SI_LEARN_ANYWAY", "Impara comunque") return end
  if lang == "pl" then ZO_CreateStringId("SI_LEARN_ANYWAY", "Ucz się mimo to") return end
  ZO_CreateStringId("SI_LEARN_ANYWAY", "Learn Anyway")
end

local strings = {
  SI_DONOTLEARN_PANEL_NAME = {
      en = "Do Not Learn",
      de = "Nicht Lernen",
      fr = "Ne Pas Apprendre",
      ru = "Не Изучать",
      ja = "習得しない",
      zh = "不学习",
      es = "No Aprender",
      it = "Non Imparare",
      pl = "Nie Ucz się",
  },
  SI_BLOCK_RECIPES = {
      en = "Block Recipes",
      de = "Rezepte Blockieren",
      fr = "Bloquer Les Recettes",
      ru = "Блокировать Рецепты",
      ja = "レシピをブロック",
      zh = "屏蔽配方",
      es = "Bloquear Recetas",
      it = "Blocca Ricette",
      pl = "Blokuj Przepisy",
  },
  SI_BLOCK_FURNISHING = {
      en = "Block Furnishing Plans",
      de = "Einrichtungspläne Blockieren",
      fr = "Bloquer Les Plans De Mobilier",
      ru = "Блокировать Планы Обстановки",
      ja = "家具設計図をブロック",
      zh = "屏蔽家具图纸",
      es = "Bloquear Planos de Mobiliario",
      it = "Blocca Progetti di Arredamento",
      pl = "Blokuj Plany Mebli",
  },
  SI_BLOCK_MOTIFS = {
      en = "Block Motifs",
      de = "Stile Blockieren",
      fr = "Bloquer Les Motifs",
      ru = "Блокировать Мотивы",
      ja = "モチーフをブロック",
      zh = "屏蔽样式",
      es = "Bloquear Motivos",
      it = "Blocca Motivi",
      pl = "Blokuj Motywy",
  },
  SI_BLOCK_STYLEPAGES = {
      en = "Block Style Pages",
      de = "Stilseiten Blockieren",
      fr = "Bloquer Les Pages de Style",
      ru = "Блокировать Страницы Стиля",
      ja = "スタイルページをブロック",
      zh = "屏蔽样式页面",
      es = "Bloquear Páginas de Estilo",
      it = "Blocca Pagine di Stile",
      pl = "Blokuj Strony Stylu",
  },
  SI_BLOCK_RUNEBOX = {
      en = "Block Runebox",
      de = "Runenbox Blockieren",
      fr = "Bloquer la Boîte de Runes",
      ru = "Блокировать Руническую Коробку",
      ja = "ルーンボックスをブロック",
      zh = "屏蔽符文箱",
      es = "Bloquear Caja de Runas",
      it = "Blocca Scatola di Rune",
      pl = "Blokuj Skrzynkę Run",
  },
  SI_BLOCK_SCRIBING = {
      en = "Block Scribing",
      de = "Skribieren Blockieren",
      fr = "Bloquer la Calligraphie",
      ru = "Блокировать Скрибирование",
      ja = "スクライブをブロック",
      zh = "屏蔽铭文",
      es = "Bloquear Escritura",
      it = "Blocca Scrittura",
      pl = "Blokuj Pisanie",
  },
  SI_PREVENTED_RECIPE = {
      en = "blocked recipe from being learned",
      de = "Rezept wurde am Lernen gehindert",
      fr = "Recette empêchée d'être apprise",
      ru = "Изучение рецепта было заблокировано",
      ja = "レシピの習得がブロックされました",
      zh = "配方的学习已被阻止",
      es = "receta bloqueada para ser aprendida",
      it = "ricetta bloccata dall'apprendimento",
      pl = "blokowano naukę przepisu",
  },
  SI_PREVENTED_FURNISHINGPLAN = {
      en = "blocked furnishing plan from being learned",
      de = "Einrichtungsplan wurde am Lernen gehindert",
      fr = "Plan de mobilier empêché d'être appris",
      ru = "Изучение плана обстановки было заблокировано",
      ja = "家具設計図の習得がブロックされました",
      zh = "家具图纸的学习已被阻止",
      es = "plano de mobiliario bloqueado para ser aprendido",
      it = "progetto di arredamento bloccato dall'apprendimento",
      pl = "blokowano naukę planu mebli",
  },
  SI_PREVENTED_MOTIF = {
      en = "blocked motif from being learned",
      de = "Stil wurde am Lernen gehindert",
      fr = "Motif empêché d'être appris",
      ru = "Изучение мотива было заблокировано",
      ja = "モチーフの習得がブロックされました",
      zh = "样式的学习已被阻止",
      es = "motivo bloqueado para ser aprendido",
      it = "motivo bloccato dall'apprendimento",
      pl = "blokowano naukę motywu",
  },
  SI_PREVENTED_STYLEPAGE = {
      en = "blocked style page from being learned",
      de = "Stilseite wurde am Lernen gehindert",
      fr = "Page de style empêchée d'être apprise",
      ru = "Изучение страницы стиля было заблокировано",
      ja = "スタイルページの習得がブロックされました",
      zh = "样式页面的学习已被阻止",
      es = "página de estilo bloqueada para ser aprendida",
      it = "pagina di stile bloccata dall'apprendimento",
      pl = "blokowano naukę strony stylu",
  },
  SI_PREVENTED_RUNEBOX = {
      en = "blocked runebox from being learned",
      de = "Runenbox wurde am Lernen gehindert",
      fr = "Boîte de runes empêchée d'être apprise",
      ru = "Изучение рунической коробки было заблокировано",
      ja = "ルーンボックスの習得がブロックされました",
      zh = "符文箱的学习已被阻止",
      es = "caja de runas bloqueada para ser aprendida",
      it = "scatola di rune bloccata dall'apprendimento",
      pl = "blokowano naukę skrzynki run",
  },
  SI_PREVENTED_SCRIBING = {
      en = "blocked scribing script or grimoire from being learned",
      de = "skripting-Skript oder Grimoire wurde am Lernen gehindert",
      fr = "script ou grimoire de calligraphie empêché d'être appris",
      ru = "изучение скриптового скрипта или гримуара было заблокировано",
      ja = "スクライブのスクリプトまたはグリモワールの習得がブロックされました",
      zh = "铭文脚本或魔法书的学习已被阻止",
      es = "guion o grimorio de escritura bloqueado para ser aprendido",
      it = "script o grimorio di scrittura bloccato dall'apprendimento",
      pl = "blokowano naukę skryptu lub grymuaru pisania",
  },
  SI_BLOCK_RECIPES_TOOLTIP = {
      en = "Prevents learning new recipes.",
      de = "Verhindert das Erlernen neuer Rezepte.",
      fr = "Empêche d'apprendre de nouvelles recettes.",
      ru = "Запрещает изучение новых рецептов.",
      ja = "新しいレシピの習得を防ぎます。",
      zh = "阻止学习新配方。",
      es = "Impide aprender nuevas recetas.",
      it = "Impedisce di imparare nuove ricette.",
      pl = "Zapobiega nauce nowych przepisów.",
  },
  SI_BLOCK_FURNISHING_TOOLTIP = {
      en = "Prevents learning new furnishing plans.",
      de = "Verhindert das Erlernen neuer Einrichtungspläne.",
      fr = "Empêche d'apprendre de nouveaux plans de mobilier.",
      ru = "Запрещает изучение новых планов обстановки.",
      ja = "新しい家具設計図の習得を防ぎます。",
      zh = "阻止学习新家具图纸。",
      es = "Impide aprender nuevos planos de mobiliario.",
      it = "Impedisce di imparare nuovi progetti di arredamento.",
      pl = "Zapobiega nauce nowych planów mebli.",
  },
  SI_BLOCK_MOTIFS_TOOLTIP = {
      en = "Prevents learning new motifs.",
      de = "Verhindert das Erlernen neuer Stile.",
      fr = "Empêche d'apprendre de nouveaux motifs.",
      ru = "Запрещает изучение новых мотивов.",
      ja = "新しいモチーフの習得を防ぎます。",
      zh = "阻止学习新样式。",
      es = "Impide aprender nuevos motivos.",
      it = "Impedisce di imparare nuovi motivi.",
      pl = "Zapobiega nauce nowych motywów.",
  },
  SI_BLOCK_STYLEPAGES_TOOLTIP = {
      en = "Prevents learning new style pages.",
      de = "Verhindert das Erlernen neuer Stilseiten.",
      fr = "Empêche d'apprendre de nouvelles pages de style.",
      ru = "Запрещает изучение новых страниц стиля.",
      ja = "新しいスタイルページの習得を防ぎます。",
      zh = "阻止学习新样式页面。",
      es = "Impide aprender nuevas páginas de estilo.",
      it = "Impedisce di imparare nuove pagine di stile.",
      pl = "Zapobiega nauce nowych stron stylu.",
  },
  SI_BLOCK_RUNEBOX_TOOLTIP = {
      en = "Prevents learning new runeboxes.",
      de = "Verhindert das Erlernen neuer Runenboxen.",
      fr = "Empêche d'apprendre de nouvelles boîtes de runes.",
      ru = "Запрещает изучение новых рунических коробок.",
      ja = "新しいルーンボックスの習得を防ぎます。",
      zh = "阻止学习新的符文箱。",
      es = "Impide aprender nuevas cajas de runas.",
      it = "Impedisce di imparare nuove scatole di rune.",
      pl = "Zapobiega nauce nowych skrzynek run.",
  },
  SI_BLOCK_SCRIBING_TOOLTIP = {
      en = "Prevents learning new scribing scripts and grimoires.",
      de = "Verhindert das Erlernen neuer Skripting-Skripte und Grimoire.",
      fr = "Empêche d'apprendre de nouveaux scripts et grimoires de calligraphie.",
      ru = "Запрещает изучение новых скриптов и гримуаров скрибирования.",
      ja = "新しいスクライブのスクリプトとグリモワールの習得を防ぎます。",
      zh = "阻止学习新的铭文脚本和魔法书。",
      es = "Impide aprender nuevos guiones y grimorios de escritura.",
      it = "Impedisce di imparare nuovi script e grimori di scrittura.",
      pl = "Zapobiega nauce nowych skryptów i grymuarów pisania.",
  },
}

local function L(key)
  local lang = GetCVar("Language.2")
  return strings[key][lang] or strings[key]["en"]
end

local function GetItemLinkSetCollectionStatus(itemLink)
    -- Returns:
    -- 0: Not a collectible
    -- 1: Collectible and not collected
    -- 2: Collectible and collected
    -- 3: Item Set Collectible and not collected
    -- 4: Item Set Collectible and collected
 
    if (IsItemLinkSetCollectionPiece(itemLink)) then
        if (IsItemSetCollectionPieceUnlocked(GetItemLinkItemId(itemLink))) then
            return 4
        else
            return 3
        end
    else
        local id = GetItemLinkContainerCollectibleId(itemLink)
        if (id > 0) then
            if (IsCollectibleOwnedByDefId(id)) then
                return 2
            elseif (GetCollectibleCategoryType(id) == COLLECTIBLE_CATEGORY_TYPE_COMBINATION_FRAGMENT and not CanCombinationFragmentBeUnlocked(id)) then
                return 2
            else
                return 1
            end
        end
        return 0
    end
end

-- ZO_PreHookProtected is a rewrite of ZO_PreHook. It accepts Protected functions.
-- IsProtectedFunction(existingFunctionName) will still return true even if existingFunctionName is not called
-- Calling existingFunctionName() will work, it will call your function and depending on your code will run the prehooked function
-- Calling CallSecureProtected("existingFunctionName", arg1) will work, it will call the original function only. You won't be able to "fake" other addons if they're correctly written, but mainly ESOUI code.
-- Don't hook a non-protected function with this PreHook or game won't load
local function ZO_PreHookProtected(objectTable, existingFunctionName, hookFunction)
    if(type(objectTable) == "string") then
        hookFunction = existingFunctionName
        existingFunctionName = objectTable
        objectTable = _G
    end
 
    local newFn = function(...)
        if(not hookFunction(...)) then
        
            if IsProtectedFunction(existingFunctionName) then
                return CallSecureProtected(existingFunctionName, ...)
            end
            
        end
    end
 
    objectTable[existingFunctionName] = newFn
 
end

local function CreateSettings()
    if IsConsoleUI() and not LibAddonMenu2 then return end
    
    local LAM = LibAddonMenu2
    local panelName = DoNotLearn.name .. "OptionsPanel"

    local panelData = {
        type = "panel",
        name = L("SI_DONOTLEARN_PANEL_NAME"),
        displayName = "|c00FF00" .. L("SI_DONOTLEARN_PANEL_NAME") .. "|r",
        author = "msetten",
        version = DoNotLearn.version,
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsData = {
        {
            type = "checkbox",
            name = L("SI_BLOCK_RECIPES"),
            tooltip = L("SI_BLOCK_RECIPES_TOOLTIP"),
            getFunc = function() return DoNotLearn.savedVars.blockRecipes end,
            setFunc = function(value) DoNotLearn.savedVars.blockRecipes = value end,
            default = true,
        },
        {
            type = "checkbox",
            name = L("SI_BLOCK_FURNISHING"),
            tooltip = L("SI_BLOCK_FURNISHING_TOOLTIP"),
            getFunc = function() return DoNotLearn.savedVars.blockFurnishings end,
            setFunc = function(value) DoNotLearn.savedVars.blockFurnishings = value end,
            default = true,
        },
        {
            type = "checkbox",
            name = L("SI_BLOCK_MOTIFS"),
            tooltip = L("SI_BLOCK_MOTIFS_TOOLTIP"),
            getFunc = function() return DoNotLearn.savedVars.blockMotifs end,
            setFunc = function(value) DoNotLearn.savedVars.blockMotifs = value end,
            default = true,
        },
  
        {
            type = "checkbox",
            name = L("SI_BLOCK_SCRIBING"),
            tooltip = L("SI_BLOCK_SCRIBING_TOOLTIP"),
            getFunc = function() return DoNotLearn.savedVars.blockScripts end,
            setFunc = function(value) DoNotLearn.savedVars.blockScripts = value end,
            default = true,
        },
         {
            type = "checkbox",
            name = L("SI_BLOCK_STYLEPAGES"),
            tooltip = L("SI_BLOCK_STYLEPAGES_TOOLTIP"),
            getFunc = function() return DoNotLearn.savedVars.blockStylePages end,
            setFunc = function(value) DoNotLearn.savedVars.blockStylePages = value end,
            default = true,
        },
         {
            type = "checkbox",
            name = L("SI_BLOCK_RUNEBOX"),
            tooltip = L("SI_BLOCK_RUNEBOX_TOOLTIP"),
            getFunc = function() return DoNotLearn.savedVars.blockRuneboxes end,
            setFunc = function(value) DoNotLearn.savedVars.blockRuneboxes = value end,
            default = true,
        },
    }

    LAM:RegisterAddonPanel(panelName, panelData)
    LAM:RegisterOptionControls(panelName, optionsData)
end

local function ShouldBlockItem(bagId, slotIndex)
    local itemType, specializedType = GetItemType(bagId, slotIndex)
    -- d("Checking itemType: " .. tostring(itemType) .. " specializedType: " .. tostring(specializedType))
    local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_BRACKETS)
    local itemId = GetItemLinkItemId(itemLink)
    if itemType == ITEMTYPE_RECIPE then
      if specializedType == SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_FOOD or specializedType == SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_DRINK then
        if IsItemLinkRecipeKnown(itemLink) then return false, DoNotLearn.NOTHING end
        if DoNotLearn.override then return false, DoNotLearn.RECIPE end
        return DoNotLearn.savedVars.blockRecipes, DoNotLearn.RECIPE
      elseif specializedType == SPECIALIZED_ITEMTYPE_RECIPE_ALCHEMY_FORMULA_FURNISHING 
          or specializedType == SPECIALIZED_ITEMTYPE_RECIPE_BLACKSMITHING_DIAGRAM_FURNISHING 
          or specializedType == SPECIALIZED_ITEMTYPE_RECIPE_CLOTHIER_PATTERN_FURNISHING 
          or specializedType == SPECIALIZED_ITEMTYPE_RECIPE_ENCHANTING_SCHEMATIC_FURNISHING
          or specializedType == SPECIALIZED_ITEMTYPE_RECIPE_JEWELRYCRAFTING_SKETCH_FURNISHING
          or specializedType == SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_DESIGN_FURNISHING 
          or specializedType == SPECIALIZED_ITEMTYPE_RECIPE_WOODWORKING_BLUEPRINT_FURNISHING then
        if IsItemLinkRecipeKnown(itemLink) then return false, DoNotLearn.NOTHING end
        if DoNotLearn.override then return false, DoNotLearn.FURNISHINGPLAN end
        return DoNotLearn.savedVars.blockFurnishings, DoNotLearn.FURNISHINGPLAN
      end
    elseif itemType == ITEMTYPE_RACIAL_STYLE_MOTIF then
      if IsItemLinkBookKnown(itemLink) then return false, DoNotLearn.NOTHING end
      if DoNotLearn.override then return false, DoNotLearn.MOTIF end
      return DoNotLearn.savedVars.blockMotifs, DoNotLearn.MOTIF
    elseif itemType == ITEMTYPE_COLLECTIBLE then
      local isKnown = GetItemLinkSetCollectionStatus(itemLink)
        if isKnown == 2 or isKnown == 4 then return false, DoNotLearn.NOTHING end
        if DoNotLearn.override then return false, DoNotLearn.STYLEPAGE end
        return DoNotLearn.savedVars.blockStylePages, DoNotLearn.STYLEPAGE
    elseif itemType == ITEMTYPE_CONTAINER then
        local textureName = GetItemInfo(bagId, slotIndex)
        -- d("Texture name: " .. tostring(textureName))
        if textureName == "/esoui/art/icons/container_sealed_polymorph_001.dds" or textureName == "/esoui/art/icons/item_collectible_runebound_tome.dds" then
          local isKnown = GetItemLinkSetCollectionStatus(itemLink)
          --d("isKnown: " .. tostring(isKnown))
          if isKnown == 2 or isKnown == 4 then return false, DoNotLearn.NOTHING end
          if DoNotLearn.override then return false, DoNotLearn.RUNEBOX end
          return DoNotLearn.savedVars.blockRuneboxes, DoNotLearn.RUNEBOX
        end
    elseif itemType == 72 or itemType == 73 then
      -- 72 = scribing scripts, 73 = scribing grimoires
      if IsItemLinkBookKnown(itemLink) then return false, DoNotLearn.NOTHING end
      if DoNotLearn.override then return false, DoNotLearn.SCRIBING end
      return DoNotLearn.savedVars.blockScripts, DoNotLearn.SCRIBING
    -- else 
    --   d("Unhandled item type: " .. tostring(itemType) .. " specializedType: " .. tostring(specializedType))
    end

    --return true, DoNotLearn.NOTHING
    return false, DoNotLearn.NOTHING
end

local function HookedUseItem(bagId, slotIndex)
  -- local itemLink = GetItemLink(bagId, slotIndex)
  -- local itemid = GetItemLinkItemId(itemLink)
  -- d("itemLink: " .. tostring(itemLink) .. " itemid: " .. tostring(itemid))
  local usable, onlyFromActionSlot = IsItemUsable(bagId, slotIndex)
  if usable and not onlyFromActionSlot then
    local block, blockType = DoNotLearn.ShouldBlockItem(bagId, slotIndex)
    if block then
        local name = GetItemName(bagId, slotIndex)
        if blockType == DoNotLearn.RECIPE then
          ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, L("SI_DONOTLEARN_PANEL_NAME") .. " " .. L("SI_PREVENTED_RECIPE"))
        elseif blockType == DoNotLearn.FURNISHINGPLAN then
          ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, L("SI_DONOTLEARN_PANEL_NAME") .. " " .. L("SI_PREVENTED_FURNISHINGPLAN"))
        elseif blockType == DoNotLearn.MOTIF then
          ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, L("SI_DONOTLEARN_PANEL_NAME") .. " " .. L("SI_PREVENTED_MOTIF"))
        elseif blockType == DoNotLearn.SCRIBING then
          ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, L("SI_DONOTLEARN_PANEL_NAME") .. " " .. L("SI_PREVENTED_SCRIBING"))
        elseif blockType == DoNotLearn.STYLEPAGE then
          ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, L("SI_DONOTLEARN_PANEL_NAME") .. " " .. L("SI_PREVENTED_STYLEPAGE"))
        elseif blockType == DoNotLearn.RUNEBOX then
          ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, L("SI_DONOTLEARN_PANEL_NAME") .. " " .. L("SI_PREVENTED_RUNEBOX"))
        end
        return true
    end
    -- Allow normal behavior
    return false
  end
end

local function learnAnyway(bag, slot) 
  DoNotLearn.override = true
  CallSecureProtected("UseItem", bag, slot)
  DoNotLearn.override = false
end

local function gamepadInventoryHook(inventoryInfo, slotActions)
	if not IsInGamepadPreferredMode() and not IsConsoleUI() then
		return
	end
	if not inventoryInfo or not inventoryInfo.dataSource then
		return
	end
  if IsBankOpen() or IsGuildBankOpen() then
    return
  end
	local bag = inventoryInfo.dataSource.bagId
	local slot = inventoryInfo.dataSource.slotIndex
	local itemLink = GetItemLink(bag, slot)

  local itemType, specializedType = GetItemType(bag, slot)
  if itemType == ITEMTYPE_RECIPE then
    if not IsItemLinkRecipeKnown(itemLink) then
      slotActions:AddSlotAction(SI_LEARN_ANYWAY, function() learnAnyway(bag, slot) end , "keybind3")
      -- addButton(bag, slot)
    end    
  elseif itemType == ITEMTYPE_RACIAL_STYLE_MOTIF then
    if not IsItemLinkBookKnown(itemLink) then
      slotActions:AddSlotAction(SI_LEARN_ANYWAY, function() learnAnyway(bag, slot) end , "keybind3")
      -- addButton(bag, slot)
    end 
  elseif itemType == ITEMTYPE_COLLECTIBLE then
    local isKnown = GetItemLinkSetCollectionStatus(itemLink)
    if isKnown == 1 or isKnown == 3 then
      slotActions:AddSlotAction(SI_LEARN_ANYWAY, function() learnAnyway(bag, slot) end , "keybind3")
      -- addButton(bag, slot)
    end
  elseif itemType == ITEMTYPE_CONTAINER then
    local isKnown = GetItemLinkSetCollectionStatus(itemLink)
    if isKnown == 1 or isKnown == 3 then
      slotActions:AddSlotAction(SI_LEARN_ANYWAY, function() learnAnyway(bag, slot) end , "keybind3")
      -- addButton(bag, slot)
    end
  elseif itemType == 72 or itemType == 73 then
    -- 72 = scribing scripts, 73 = scribing grimoires
    if not IsItemLinkBookKnown(itemLink) then
      slotActions:AddSlotAction(SI_LEARN_ANYWAY, function() learnAnyway(bag, slot) end , "keybind3")
      -- addButton(bag, slot)
    end
  end
end

function DoNotLearn.OnAddOnLoaded(event, addonName)
    if addonName ~= "DoNotLearn" then return end
    EVENT_MANAGER:UnregisterForEvent("DoNotLearn_Loaded", EVENT_ADD_ON_LOADED)

    DoNotLearn.savedVars = ZO_SavedVars:NewCharacterIdSettings("DoNotLearnSaved", 1, nil, DoNotLearn.defaults)
    if DoNotLearn.savedVars.blockStylePages == nil then DoNotLearn.savedVars.blockStylePages = DoNotLearn.defaults.blockStylePages end
    if DoNotLearn.savedVars.blockRuneboxes == nil then DoNotLearn.savedVars.blockRuneboxes = DoNotLearn.defaults.blockRuneboxes end
    initLearnAnywayTranslations()
    CreateSettings()
    ZO_PreHookProtected('UseItem', DoNotLearn.HookedUseItem)
    SecurePostHook(_G, "ZO_InventorySlot_DiscoverSlotActionsFromActionList", gamepadInventoryHook)
end


EVENT_MANAGER:RegisterForEvent("DoNotLearn_Loaded", EVENT_ADD_ON_LOADED, DoNotLearn.OnAddOnLoaded)

DoNotLearn.HookedUseItem = HookedUseItem
DoNotLearn.ShouldBlockItem = ShouldBlockItem
DoNotLearn.learnAnyway = learnAnyway