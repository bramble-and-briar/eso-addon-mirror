function ATT_LoadSettings()
  local panelData = {
    type = "panel",
    name = "Alchemy Tooltips",
    displayName = "Alchemy Tooltips",
    author = "Hyperioxes, |cff9b15Sharlikran|r",
    version = "1.32",
    website = "https://www.esoui.com/downloads/info2531-AlchemyTooltips.html",
    feedback = "https://www.esoui.com/downloads/info2531-AlchemyTooltips.html#comments",
    slashCommand = "/alchemytooltips",
    registerForRefresh = true,
    registerForDefaults = true,
  }
  LibAddonMenu2:RegisterAddonPanel("AlchemyTooltips", panelData)

  local AT_ADVANCED_NAME_SETTINGS = 7
  local AT_CUSTOM_QUALITY_SETTINGS = 8
  local optionsData = {}
  optionsData[#optionsData + 1] = {
    type = "header",
    name = GetString(AT_GeneralSettings),
    width = "full",
  }
  optionsData[#optionsData + 1] = {
    type = "checkbox",
    name = GetString(AT_CustomTooltips_name),
    tooltip = GetString(AT_CustomTooltips_tip),
    getFunc = function() return ATT_savedVars.useTooltips end,
    setFunc = function(value) ATT_savedVars.useTooltips = value end,
    width = "full",
    --warning = "Will need to reinitialize prices",
  }
  optionsData[#optionsData + 1] = {
    type = "checkbox",
    name = GetString(AT_CustomIcons_name),
    tooltip = GetString(AT_CustomIcons_tip),
    getFunc = function() return ATT_savedVars.useCustomIcons end,
    setFunc = function(value) ATT_savedVars.useCustomIcons = value end,
    width = "full",
    warning = GetString(AT_ReloadUI_warn),
  }
  optionsData[#optionsData + 1] = {
    type = "checkbox",
    name = GetString(AT_CustomNames_name),
    tooltip = GetString(AT_CustomNames_tip),
    getFunc = function() return ATT_savedVars.useCustomNames end,
    setFunc = function(value) ATT_savedVars.useCustomNames = value end,
    width = "full",
    warning = GetString(AT_ReloadUI_warn),
  }
  optionsData[#optionsData + 1] = {
    type = "checkbox",
    name = GetString(AT_CustomQualityColors_name),
    tooltip = GetString(AT_CustomQualityColors_tip),
    getFunc = function() return ATT_savedVars.useCustomQualities end,
    setFunc = function(value) ATT_savedVars.useCustomQualities = value end,
    width = "full",
    warning = GetString(AT_ReloadUI_warn),
  }
  optionsData[#optionsData + 1] = {
    type = "checkbox",
    name = GetString(AT_ShowCraftCost_name),
    tooltip = GetString(AT_ShowCraftCost_tip),
    getFunc = function() return ATT_savedVars.showCraftCost end,
    setFunc = function(value) ATT_savedVars.showCraftCost = value end,
    width = "full",
  }
  optionsData[AT_ADVANCED_NAME_SETTINGS] = {
    type = "submenu",
    name = GetString(AT_AdvancedNameSettings_name),
    tooltip = GetString(AT_AdvancedNameSettings_tip),
    controls = {},
  }
  optionsData[AT_CUSTOM_QUALITY_SETTINGS] = {
    type = "submenu",
    name = GetString(AT_CustomQuality_name),
    tooltip = GetString(AT_CustomQuality_tip),
    controls = {},
  }
  optionsData[#optionsData + 1] = {
    type = "header",
    name = GetString(AT_PricingSettings),
    width = "full",
  }
  optionsData[#optionsData + 1] = {
    type = "checkbox",
    name = GetString(AT_UseTTCPrices_name),
    tooltip = GetString(AT_UseTTCPrices_tip),
    getFunc = function() return ATT_savedVars.TTCuse end,
    setFunc = function(value) ATT_savedVars.TTCuse = value end,
    width = "full",
    warning = GetString(AT_ReinitializePrices_warn),
  }
  optionsData[#optionsData + 1] = {
    type = "checkbox",
    name = GetString(AT_UseMMPrices_name),
    tooltip = GetString(AT_UseMMPrices_tip),
    getFunc = function() return ATT_savedVars.MMuse end,
    setFunc = function(value) ATT_savedVars.MMuse = value end,
    width = "full",
    warning = GetString(AT_ReinitializePrices_warn),
  }
  optionsData[#optionsData + 1] = {
    type = "checkbox",
    name = GetString(AT_UseATTPrices_name),
    tooltip = GetString(AT_UseATTPrices_tip),
    getFunc = function() return ATT_savedVars.ATTuse end,
    setFunc = function(value) ATT_savedVars.ATTuse = value end,
    width = "full",
    warning = GetString(AT_ReinitializePrices_warn),
  }
  optionsData[#optionsData + 1] = {
    type = "submenu",
    name = GetString(AT_AlterPricingFormula_name),
    tooltip = GetString(AT_AlterPricingFormula_tip),
    controls = {
      [1] = {
        type = "editbox",
        name = GetString(AT_TTCMultiplier_name),
        tooltip = GetString(AT_TTCMultiplier_tip),
        getFunc = function() return ATT_savedVars.TTCMultiplier end,
        setFunc = function(value) ATT_savedVars.TTCMultiplier = value end,
        isMultiline = false,
        width = "full",
        warning = GetString(AT_ReinitializePrices_warn),
        default = "1",
      },
      [2] = {
        type = "editbox",
        name = GetString(AT_MMMultiplier_name),
        tooltip = GetString(AT_MMMultiplier_tip),
        getFunc = function() return ATT_savedVars.MMMultiplier end,
        setFunc = function(value) ATT_savedVars.MMMultiplier = value end,
        isMultiline = false,
        width = "full",
        warning = GetString(AT_ReinitializePrices_warn),
        default = "1",
      },
      [3] = {
        type = "editbox",
        name = GetString(AT_ATTMultiplier_name),
        tooltip = GetString(AT_ATTMultiplier_tip),
        getFunc = function() return ATT_savedVars.ATTMultiplier end,
        setFunc = function(value) ATT_savedVars.ATTMultiplier = value end,
        isMultiline = false,
        width = "full",
        warning = GetString(AT_ReinitializePrices_warn),
        default = "1",
      },
    },
  }
  optionsData[#optionsData + 1] = {
    type = "button",
    name = GetString(AT_ReinitializePrices_name),
    tooltip = GetString(AT_ReinitializePrices_tip),
    func = function() ATT_Functions:InitializePrices() end,
    width = "full",
  }
  optionsData[#optionsData + 1] = {
    type = "header",
    name = GetString(AT_ExampleBlueEntoloma_header),
    width = "full",
  }
  optionsData[#optionsData + 1] = {
    type = "texture",
    image = "/esoui/art/icons/crafting_mushroom_blue_entoloma_cap_r1.dds",
    imageWidth = 100,
    imageHeight = 100,
    width = "half",
  }
  optionsData[#optionsData + 1] = {
    type = "description",
    text = function()
      local formula = "("
      local multiplier
      if ATT_savedVars.TTCuse and LibPrice.ItemLinkToPriceGold("|H0:item:30148:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", "ttc") ~= nil then
        multiplier = ATT_savedVars.TTCMultiplier .. " * TTC + "
      end
      if ATT_savedVars.MMuse and LibPrice.ItemLinkToPriceGold("|H1:item:30148:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", "mm") ~= nil then
        multiplier = ATT_savedVars.MMMultiplier .. " * MM + "
      end
      if ATT_savedVars.ATTuse and LibPrice.ItemLinkToPriceGold("|H0:item:30148:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", "att") ~= nil then
        multiplier = ATT_savedVars.ATTMultiplier .. " * ATT + "
      end
      if multiplier ~= nil then formula = formula .. multiplier else formula = formula .. GetString(AT_NoneAvailable_warn) end
      formula = formula:sub(1, -3)
      formula = formula .. ") / " .. ATT_Functions:countPricingAddons()
      return formula
    end,
    width = "full",
  }
  optionsData[#optionsData + 1] = {
    type = "description",
    text = function()
      local formula = GetString(AT_PriceFormula_text)
      local multiplier
      if ATT_savedVars.TTCuse and LibPrice.ItemLinkToPriceGold("|H0:item:30148:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", "ttc") ~= nil then
        multiplier = ATT_savedVars.TTCMultiplier .. " * " .. string.format("%.3f", LibPrice.ItemLinkToPriceGold("|H0:item:30148:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", "ttc")) .. " + "
      end
      if ATT_savedVars.MMuse and LibPrice.ItemLinkToPriceGold("|H0:item:30148:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", "mm") ~= nil then
        multiplier = formula .. ATT_savedVars.MMMultiplier .. " * " .. string.format("%.3f", LibPrice.ItemLinkToPriceGold("|H0:item:30148:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", "mm")) .. " + "
      end
      if ATT_savedVars.ATTuse and LibPrice.ItemLinkToPriceGold("|H0:item:30148:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", "att") ~= nil then
        multiplier = formula .. ATT_savedVars.ATTMultiplier .. " * " .. string.format("%.3f", LibPrice.ItemLinkToPriceGold("|H0:item:30148:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", "att")) .. " + "
      end
      if multiplier ~= nil then formula = formula .. multiplier else formula = formula .. GetString(AT_NoneAvailable_warn) end
      formula = formula:sub(1, -3)
      formula = formula .. ") / " .. ATT_Functions:countPricingAddons() .. " = " .. string.format("%.3f", ATT_Functions:GeneratePrice("|H0:item:30148:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"))
      return formula
    end,
    width = "full",
  }
  optionsData[#optionsData + 1] = {
    type = "header",
    name = GetString(AT_OtherSettings),
    width = "full",
  }
  optionsData[#optionsData + 1] = {
    type = "checkbox",
    name = GetString(AT_OldTooltipLayout_name),
    tooltip = GetString(AT_OldTooltipLayout_tip),
    getFunc = function() return ATT_savedVars.useOld end,
    setFunc = function(value) ATT_savedVars.useOld = value end,
    width = "full",
  }
  table.insert(optionsData[AT_ADVANCED_NAME_SETTINGS].controls, {
    type = "description",
    text = GetString(AT_ChangesRequireReload_desc),
    width = "full",
  })
  table.insert(optionsData[AT_ADVANCED_NAME_SETTINGS].controls, {
    type = "description",
    text = GetString(AT_DisplayedInventoryName_desc),
    width = "full",
  })
  local effectIds = {}
  for effectId in pairs(ATT_Variables.properEffectNames) do
    effectIds[#effectIds + 1] = effectId
  end
  table.sort(effectIds)
  for _, effectId in ipairs(effectIds) do
    local savedEffectId = effectId
    local effectName = ATT_Variables.properEffectNames[savedEffectId]
    table.insert(optionsData[AT_ADVANCED_NAME_SETTINGS].controls, {
      type = "description",
      text = effectName .. "  --->  " .. ATT_savedVars.effectsByWritIDShort[savedEffectId],
      width = "half",
      reference = "description" .. savedEffectId
    })
    table.insert(optionsData[AT_ADVANCED_NAME_SETTINGS].controls, {
      type = "editbox",
      name = GetString(AT_ChangeDisplayedName_name),
      getFunc = function() return ATT_savedVars.effectsByWritIDShort[savedEffectId] end,
      setFunc = function(text)
        ATT_savedVars.effectsByWritIDShort[savedEffectId] = text
        _G["description" .. savedEffectId].data.text = effectName .. "  --->  " .. ATT_savedVars.effectsByWritIDShort[savedEffectId]
        _G["description" .. savedEffectId]:UpdateValue()
      end,
      isMultiline = false, --boolean
      width = "half", --or "half" (optional)
      default = "", --(optional)
    })
  end
  table.insert(optionsData[AT_CUSTOM_QUALITY_SETTINGS].controls, {
    type = "description",
    text = GetString(AT_ChangesRequireReload_desc),
    width = "full",
  })
  for i = 1, 5 do
    table.insert(optionsData[AT_CUSTOM_QUALITY_SETTINGS].controls, {
      type = "description",
      text = ATT_Variables.qualityColors[i] .. " quality:  " .. ATT_savedVars.craftingCostQualityBrackets[i - 1] .. "|t16:16:EsoUI/Art/currency/currency_gold.dds|t - " .. ATT_savedVars.craftingCostQualityBrackets[i] .. "|t16:16:EsoUI/Art/currency/currency_gold.dds|t",
      width = "half",
      reference = "qualityDescription" .. i,
    })
    table.insert(optionsData[AT_CUSTOM_QUALITY_SETTINGS].controls, {
      type = "editbox",
      name = GetString(AT_ChangeBracket_name),
      getFunc = function() return ATT_savedVars.craftingCostQualityBrackets[i] end,
      setFunc = function(text)
        ATT_savedVars.craftingCostQualityBrackets[i] = tonumber(text)
        _G["qualityDescription" .. i].data.text = ATT_Variables.qualityColors[i] .. " quality:  " .. ATT_savedVars.craftingCostQualityBrackets[i - 1] .. "|t16:16:EsoUI/Art/currency/currency_gold.dds|t - " .. ATT_savedVars.craftingCostQualityBrackets[i] .. "|t16:16:EsoUI/Art/currency/currency_gold.dds|t"
        if i == 5 then
          _G["qualityDescription" .. 6].data.text = ATT_Variables.qualityColors[6] .. " quality:  " .. ATT_savedVars.craftingCostQualityBrackets[5] .. "|t16:16:EsoUI/Art/currency/currency_gold.dds|t and more"
        else
          _G["qualityDescription" .. i + 1].data.text = ATT_Variables.qualityColors[i + 1] .. " quality:  " .. ATT_savedVars.craftingCostQualityBrackets[i] .. "|t16:16:EsoUI/Art/currency/currency_gold.dds|t - " .. ATT_savedVars.craftingCostQualityBrackets[i + 1] .. "|t16:16:EsoUI/Art/currency/currency_gold.dds|t"
        end
        _G["qualityDescription" .. i]:UpdateValue()
        _G["qualityDescription" .. i + 1]:UpdateValue()
      end,
      isMultiline = false, --boolean
      width = "half", --or "half" (optional)
      default = "", --(optional)
    })
  end
  table.insert(optionsData[AT_CUSTOM_QUALITY_SETTINGS].controls, {
    type = "description",
    text = ATT_Variables.qualityColors[6] .. " quality:  " .. ATT_savedVars.craftingCostQualityBrackets[5] .. "|t16:16:EsoUI/Art/currency/currency_gold.dds|t and more",
    width = "full",
    reference = "qualityDescription6"
  })
  LibAddonMenu2:RegisterOptionControls("AlchemyTooltips", optionsData)
end
