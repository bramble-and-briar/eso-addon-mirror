local colors = kpuiConst.Colors	

------------------------------------------------------------------------------
	-- replace tooltips
function kelaReplaceTooltips (tooltip)	

	-- replace type, style and unique info
	tooltip.AddTypeSlotUniqueLine = function(control, itemLink, itemType, section, text1, text2, ...)	
		
		if(text1) then 
			local unique = IsItemLinkUnique(itemLink) 
			local uniqueEquipped = IsItemLinkUniqueEquipped(itemLink) 
			local formatSuffix 
			if(unique) then 
				formatSuffix = "_UNIQUE"
			elseif(uniqueEquipped) then 
				formatSuffix = "_UNIQUE_EQUIPPED"
			else 
				formatSuffix = "" 
			end 		
			local lineText 
			local itemStyle = GetItemLinkItemStyle(itemLink)
			local equipType = GetItemLinkEquipType(itemLink) 	
			if equipType and itemStyle ~= ITEMSTYLE_NONE and equipType ~= EQUIP_TYPE_INVALID and equipType ~= EQUIP_TYPE_RING and equipType ~= EQUIP_TYPE_POISON and equipType ~= EQUIP_TYPE_NECK and equipType ~= EQUIP_TYPE_COSTUME then
		
				local itemType, specializedItemType = GetItemLinkItemType(itemLink) 
				local specializedItemTypeText = ZO_GetSpecializedItemTypeText(itemType, specializedItemType) 
				local armorType = GetItemLinkArmorType(itemLink)
				local weaponType = GetItemLinkWeaponType(itemLink) 			
				local styleColor, styleText = getStyleHeaderLine(itemStyle)
				if itemType == ITEMTYPE_ARMOR and weaponType == WEAPONTYPE_NONE then 
					lineText = GetString("SI_EQUIPTYPE", equipType).." ("..GetString("SI_ARMORTYPE", armorType).." - "..styleColor:Colorize(styleText)..")"
				elseif weaponType ~= WEAPONTYPE_NONE then 
					lineText = GetString("SI_WEAPONTYPE", weaponType).." ("..GetString("SI_EQUIPTYPE", equipType).." - "..styleColor:Colorize(styleText)..")" 					
				end
			else
				if(text2) then 
					if equipType ~= EQUIP_TYPE_RING and equipType ~= EQUIP_TYPE_NECK and equipType ~= EQUIP_TYPE_COSTUME then
						local format = _G["SI_ITEM_FORMAT_STR_TEXT1_TEXT2"..formatSuffix]
						lineText = zo_strformat(format, text1, text2) 
					else
						local format = _G["SI_ITEM_FORMAT_STR_TEXT1"..formatSuffix] 
						lineText = zo_strformat(format, text1) 
					end					
				else 
					local format = _G["SI_ITEM_FORMAT_STR_TEXT1"..formatSuffix] 
					lineText = text1
					if formatSuffix == "_UNIQUE" then
						lineText = text1.." "..GetString(SI_ITEM_FORMAT_STR_UNIQUE)
					elseif formatSuffix == "_UNIQUE_EQUIPPED" then
						lineText = text1.." "..GetString(SI_ITEM_FORMAT_STR_UNIQUE_EQUIPPED)
					end
				end 				
			end 
			if(lineText) then 
				section:AddLine(lineText, {fontSize = KELA_TOOLTIPS_FONT_SMALL, customSpacing = 0, childSpacing = 0})
			end 
			

		end
	end 
	
	-- replace currency and add trading info
	tooltip.AddItemValue = function(control, itemLink, ...)
	end
	
	local oldAddItemTitle = tooltip.AddItemTitle
	tooltip.AddItemTitle = function(control, itemLink, name, ...)
		local kelaLine = control:AcquireSection(control:GetStyle("kelaTrade")) 

		-- build the price line for the item
		local iconGold = zo_iconFormat("EsoUI/Art/currency/gamepad/gp_gold.dds", "32", "32") 

		local CONSIDER_CONDITION = true 
		local value = GetItemLinkValue(itemLink, not CONSIDER_CONDITION)
		local finalValue
		local effectiveValue
		local valueString = colors.COLOR_WHITE:Colorize(zo_strformat(SI_GAMEPAD_TOOLTIP_ITEM_VALUE_FORMAT, "0", iconGold))
		local averageGuildPrice = 0
		local countGuildPrice = 0

		local valueStringAdditionalTTC = nil
		local valueStringAdditionalATT = nil
		if(value > 0) then 
			effectiveValue = GetItemLinkValue(itemLink, CONSIDER_CONDITION) 
			finalValue = value 
			if(effectiveValue ~= value) then 
				finalValue = zo_strformat(SI_ITEM_FORMAT_STR_EFFECTIVE_VALUE_OF_MAX, effectiveValue, value)
			end 
			valueString = colors.COLOR_WHITE:Colorize(zo_strformat(SI_GAMEPAD_TOOLTIP_ITEM_VALUE_FORMAT, finalValue, iconGold))
		end
		if TamrielTradeCentre and TamrielTradeCentrePrice then
			local priceInfoTTC = TamrielTradeCentrePrice:GetPriceInfo(itemLink)

			if priceInfoTTC then
				local valueTTC = nil
				-- Get one of 2 prices from TTC
				if priceInfoTTC.SuggestedPrice then
					valueTTC = priceInfoTTC.SuggestedPrice
				elseif priceInfoTTC.Avg then
					valueTTC = priceInfoTTC.Avg
				end
				
				-- Update the valueString
				valueString = valueString..colors.COLOR_WHITE:Colorize(", ")
				if valueTTC then
					averageGuildPrice = averageGuildPrice + (valueTTC * 1.125)
					local valueTTCStr = KelaLocalizedFormatNumber(valueTTC * 1.125, 0)
					valueString = valueString..zo_strformat("|c1fcae0TTC: <<1>>|r", valueTTCStr) -- old color: cf23d8e
					countGuildPrice = countGuildPrice + 1
				else
					valueString = valueString..zo_strformat("|c1fcae0TTC: N/A|r")
				end

				-- Create additional TTC Info Lines
				valueStringAdditionalTTC = zo_strformat("|c1fcae0TTC - <<1>> Avg / <<3>> min / <<4>> max [<<2>> Listings]|r", 
					KelaLocalizedFormatNumber(priceInfoTTC.Avg), --TamrielTradeCentre:FormatNumber(priceInfoTTC.Avg), 
					KelaLocalizedFormatNumber(priceInfoTTC.EntryCount), 
					KelaLocalizedFormatNumber(priceInfoTTC.Min), 
					KelaLocalizedFormatNumber(priceInfoTTC.Max))
				
			end
			
		end
		if MasterMerchant and MasterMerchant.itemStats then
			valueString = valueString..colors.COLOR_WHITE:Colorize(", ")
			local tipStats = MasterMerchant:itemStats(itemLink, false)
			if tipStats and tipStats.avgPrice then
				averageGuildPrice = averageGuildPrice + tipStats['avgPrice']
				local valueMM = KelaLocalizedFormatNumber(tonumber(tipStats['avgPrice']), 0)
				valueString = valueString..zo_strformat("|c7171d1MM: <<1>>|r", valueMM)
				countGuildPrice = countGuildPrice + 1
			else
				valueString = valueString..zo_strformat("|c7171d1MM: N/A|r")
			end
		end
		if ArkadiusTradeTools ~= nil then 
			valueString = valueString..colors.COLOR_WHITE:Colorize(", ")
			local statsATT = KelaGetATTPriceStats(itemLink)
			if statsATT then -- and averagePrice ~= nil
				averageGuildPrice = averageGuildPrice + statsATT.Avg
				local resultValueATT = KelaLocalizedFormatNumber(tonumber(statsATT.Avg), 0)
				valueString = valueString..zo_strformat("|c1fe095ATT: <<1>>|r", resultValueATT) -- old color: f58585
				countGuildPrice = countGuildPrice + 1

				-- Create the Additional ATT Info String
				valueStringAdditionalATT = zo_strformat("|c1fe095ATT - <<1>> Avg / <<3>> min / <<4>> max [<<2>> Sales]|r", 
					KelaLocalizedFormatNumber(statsATT.Avg), --TamrielTradeCentre:FormatNumber(priceInfoTTC.Avg), 
					KelaLocalizedFormatNumber(statsATT.Sales), 
					KelaLocalizedFormatNumber(statsATT.Min or 0), 
					KelaLocalizedFormatNumber(statsATT.Max))
			else
				valueString = valueString..zo_strformat("|c1fe095ATT: N/A|r")
			end

		end
		
		if countGuildPrice > 1 then 
			local averageGuildValue = KelaLocalizedFormatNumber(averageGuildPrice / countGuildPrice, 2)
			valueString = valueString..", "..'|t24:24:EsoUI/Art/currency/currency_gold.dds|t'.." "..colors.COLOR_GOLD:Colorize(averageGuildValue)
		end

		kelaLine:AddLine(valueString)
		if valueStringAdditionalTTC then kelaLine:AddLine(valueStringAdditionalTTC) end
		if valueStringAdditionalATT then kelaLine:AddLine(valueStringAdditionalATT) end
		control:AddSection(kelaLine)
		oldAddItemTitle(control, itemLink, name, ...)
	end
	
	-- replace charge, condition and poison bar
	tooltip.AddPoisonInfo = function(control, itemLink, equipSlot, ...)	
		local hasPoison, poisonCount, poisonHeader, poisonItemLink = GetItemPairedPoisonInfo(equipSlot) 
		if(hasPoison) then 
			--Poison Count 
			local poisonSection = control:AcquireSection(control:GetStyle("bodyHeader"), {paddingTop = 2, paddingBottom = -5, uppercase = false})
			local poisonString = colors.COLOR_POISON:Colorize(zo_iconTextFormatNoSpace("EsoUI/Art/Tooltips/icon_poison.dds", 32, 32, poisonCount).." - "..poisonHeader)
			poisonSection:AddLine(poisonString, {fontSize = KELA_TOOLTIPS_FONT_MEDIUM}) 
			control:AddSection(poisonSection) 
			--Poison Ability 
			control:AddOnUseAbility(poisonItemLink, {fontSize = KELA_TOOLTIPS_FONT_SMALL})
		end 
	end
------------------------------------------------------------------------------
	-- replace enchant section	ESOUI/art/enchanting/enchanting_highlight.dds
	-- Signature and return values follow core ZO_Tooltip:AddEnchant: the caller
	-- uses the returned suppression info to add the "disabled by" line.
	tooltip.AddEnchant = function(control, itemLink, enchantDiffMode, equipSlot, extraData)
		local hasEnchant, enchantHeader, enchantDescription = GetItemLinkEnchantInfo(itemLink)
		if not hasEnchant then
			return ITEM_BONUS_SUPPRESSION_TYPE_NONE, 0
		end
		local stringEnchant = ""
		enchantDiffMode = enchantDiffMode or (extraData and extraData.enchantDiffMode) or ZO_ENCHANT_DIFF_NONE
		local itemBonusSuppressionType, itemBonusSuppressionRefId = ITEM_BONUS_SUPPRESSION_TYPE_NONE, 0
		if enchantDiffMode == ZO_ENCHANT_DIFF_NONE and extraData and extraData.showSuppression then
			itemBonusSuppressionType, itemBonusSuppressionRefId = GetItemEnchantSuppressionInfo()
		end
		local enchantSection = control:AcquireSection(control:GetStyle("bodySection"))
		local itemType = GetItemLinkItemType(itemLink)
		local equipType = GetItemLinkEquipType(itemLink) 	
		local strIcon = "ESOUI/art/enchanting/enchanting_highlight.dds"
		if(hasEnchant) then 
			stringEnchant = enchantHeader
				local stringEnchantShort
			if string.find(stringEnchant,":") then 
				stringEnchantShort = string.upper(string.sub(stringEnchant, string.find(stringEnchant,":") + 2, string.len(stringEnchant)))
			else 
				stringEnchantShort = string.upper(stringEnchant)
			end
			if enchantDiffMode == ZO_ENCHANT_DIFF_NONE then 
				if (IsItemAffectedByPairedPoison(equipSlot)) then 
					stringEnchant = zo_iconFormat(strIcon, 44, 44).." "..colors.COLOR_WHITE:Colorize(stringEnchantShort).." - "..colors.COLOR_POISON:Colorize(GetString(SI_TOOLTIP_ENCHANT_SUPPRESSED_BY_POISON))
					local suppressedStyle = control:GetStyle("suppressedAbility") 
				else 
					stringEnchant = zo_iconFormat(strIcon, 44, 44).." "..colors.COLOR_WHITE:Colorize(stringEnchantShort).." - "..enchantDescription
				end 
			end 
		end 
		enchantSection:AddLine(stringEnchant, control:GetStyle("bodyDescription"))  
		control:AddSection(enchantSection) 
		if hasEnchant and enchantDiffMode ~= ZO_ENCHANT_DIFF_NONE then 
			local diffColorStyle, icon 
			if enchantDiffMode == ZO_ENCHANT_DIFF_ADD then 
				diffColorStyle = control:GetStyle("enchantDiffAdd") 
				icon = "EsoUI/Art/Buttons/pointsPlus_up.dds" 
			elseif enchantDiffMode == ZO_ENCHANT_DIFF_REMOVE then 
				diffColorStyle = control:GetStyle("enchantDiffRemove") 
				icon = "EsoUI/Art/Buttons/pointsMinus_up.dds" 
			else 
				-- If this assert is hit, support needs to be added for the additional 
				-- enchant diff modes, which do not exist at the time of writing. 
				assert(false) 
			end 
			local enchantmentDescriptionSection = control:AcquireSection(diffColorStyle, control:GetStyle("enchantDiff")) 
			local diffSection = control:AcquireSection(control:GetStyle("enchantDiffTextureContainer")) 
			diffSection:AddTexture(icon, control:GetStyle("enchantDiffTexture")) 
			enchantmentDescriptionSection:AddSection(diffSection) 
			enchantmentDescriptionSection:AddLine(enchantDescription, control:GetStyle("bodyDescription"))
			control:AddSection(enchantmentDescriptionSection)
		end
		return itemBonusSuppressionType, itemBonusSuppressionRefId
	end
end
