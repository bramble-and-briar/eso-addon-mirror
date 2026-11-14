-- KelaPadUI trading-house and crafting-station hooks.

local KPUI_TRADINGHOUSE = KPUI_TRADINGHOUSE
local colors = KPUI_TRADINGHOUSE.colors
local KelaGetATTSalesSecondsPerDay = KPUI_TRADINGHOUSE.KelaGetATTSalesSecondsPerDay
local KelaCreateColorizedResumePrice = KPUI_TRADINGHOUSE.KelaCreateColorizedResumePrice
local GetItemLinks = KPUI_TRADINGHOUSE.GetItemLinks
local GetBuyInfo = KPUI_TRADINGHOUSE.GetBuyInfo
local HideTradingTooltipControls = KPUI_TRADINGHOUSE.HideTradingTooltipControls
local HideImprovementTooltipControls = KPUI_TRADINGHOUSE.HideImprovementTooltipControls
local HideProvisionerTooltipControls = KPUI_TRADINGHOUSE.HideProvisionerTooltipControls
local HideCreationTooltipControls = KPUI_TRADINGHOUSE.HideCreationTooltipControls
local HideAlchemyTooltipControls = KPUI_TRADINGHOUSE.HideAlchemyTooltipControls
local HideEnchantingTooltipControls = KPUI_TRADINGHOUSE.HideEnchantingTooltipControls
local ResetProvisionerTradingTooltip = KPUI_TRADINGHOUSE.ResetProvisionerTradingTooltip
local ResetCreationTradingTooltip = KPUI_TRADINGHOUSE.ResetCreationTradingTooltip
local AddClearLine = KPUI_TRADINGHOUSE.AddClearLine
local SetSmithTradingInfo = KPUI_TRADINGHOUSE.SetSmithTradingInfo
local SetSmithGraph = KPUI_TRADINGHOUSE.SetSmithGraph
local SetSmithNotes = KPUI_TRADINGHOUSE.SetSmithNotes
local SetSmithListings = KPUI_TRADINGHOUSE.SetSmithListings
local SetSmithQualityPrices = KPUI_TRADINGHOUSE.SetSmithQualityPrices
local SetProductionPrices = KPUI_TRADINGHOUSE.SetProductionPrices
local SetCraftingComponents = KPUI_TRADINGHOUSE.SetCraftingComponents
local IsKPUITradingHouseSettingEnabled = KPUI_TRADINGHOUSE.IsKPUITradingHouseSettingEnabled

local hookCraftingStationAlready = false
local hookCraftingStationKeybindAlready = false
local hookProvisionerTooltipAlready = false
local hookCreationTooltipAlready = false
local hookDeconstructTooltipAlready = false
local hookRefineTooltipAlready = false
local hookAlchemyTooltipAlready = false
local hookEnchantingTooltipAlready = false

				
local hookTradingHouseAlready = false
local hookBankingAlready = false
local hookStoregAlready = false
local hookATTAlready = false

function KelaSetupCraftingStation()

	if not hookCraftingStationAlready then

		-- alchemy crafting
		ZO_PreHook(ZO_GamepadAlchemy, "UpdateTooltip", function(control, ...)
				local ingredientsBar = control.control:GetNamedChild("SlotContainer")
				-- setting
				if not hookAlchemyTooltipAlready then
					control.tooltip.tip.styleNamespace = ZO_TOOLTIP_STYLES
					control.tooltip.tip:SetStyles(control.tooltip.tip:GetStyle("tooltip"))
					ingredientsBar:ClearAnchors()
					ingredientsBar:SetAnchor(BOTTOM, GuiRoot, BOTTOMLEFT, ZO_GAMEPAD_PROVISIONER_INGREDIENTS_BAR_OFFSET_X, ZO_GAMEPAD_CRAFTING_UTILS_FLOATING_BOTTOM_OFFSET + 30)
					control.tooltip:ClearAnchors()
					control.tooltip:SetAnchor(BOTTOM, ingredientsBar, TOP, 0, -25)	
					if not ctlAlchemyTooltip then ctlAlchemyTooltip = CreateControlFromVirtual("$(parent)TradingTip", control.tooltip, "KPUI_CraftingTooltip") end
					ctlAlchemyTooltip:ClearAnchors()
					ctlAlchemyTooltip:SetAnchor(BOTTOMLEFT, control.tooltip, BOTTOMRIGHT, 38)
					ctlAlchemyTooltip:SetHidden(true)
					GAMEPAD_ALCHEMY_CREATION_SCENE:RegisterCallback("StateChange", function(oldState, newState)
						if newState == SCENE_HIDDEN then
							if ctlAlchemyTooltip then 
								ctlAlchemyTooltip.tip:ClearLines()
								ctlAlchemyTooltip:SetHidden(true) 
							end
							HideAlchemyTooltipControls() -- release custom tooltip controls during teardown
							
						end
					end)
					hookAlchemyTooltipAlready = true
				end	
				if control:IsCraftable() then
					control.tooltip:SetHidden(false)
					control.tooltip.tip:ClearLines()
					local solventBagId, solventSlotIndex, reagent1BagId, reagent1SlotIndex, reagent2BagId, reagent2SlotIndex, reagent3BagId, reagent3SlotIndex = control:GetAllCraftingBagAndSlots()
					local itemLink, prospectiveAlchemyResult = GetAlchemyResultingItemLink(solventBagId, solventSlotIndex, reagent1BagId, reagent1SlotIndex, reagent2BagId, reagent2SlotIndex, reagent3BagId, reagent3SlotIndex)
					local solventType = GetItemType(solventBagId, solventSlotIndex)
					local itemTypeString = GetString(solventType == ITEMTYPE_POTION_BASE and SI_ITEM_FORMAT_STR_POTION or SI_ITEM_FORMAT_STR_POISON)
					control.tooltip.tip:LayoutAlchemyPreview(itemLink, itemTypeString, prospectiveAlchemyResult)
					if ctlAlchemyTooltip and IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_CRAFTING) then 
						if itemLink and prospectiveAlchemyResult > 1 then
							control.tooltip:ClearAnchors()
							control.tooltip:SetAnchor(BOTTOM, ingredientsBar, TOP, -254, -25)
							local maxIterations = GetMaxIterationsPossibleForAlchemyItem(control:GetAllCraftingBagAndSlots())
							ZO_Tooltip:LayoutAlchemyTradingTooltip(ctlAlchemyTooltip, itemLink, maxIterations)
							ctlAlchemyTooltip:SetHidden(false) 
						else
							control.tooltip:ClearAnchors()
							control.tooltip:SetAnchor(BOTTOM, ingredientsBar, TOP, 0, -25)						
							ctlAlchemyTooltip.tip:ClearLines()
							ctlAlchemyTooltip:SetHidden(true) 
						end
					else
						control.tooltip:ClearAnchors()
						control.tooltip:SetAnchor(BOTTOM, ingredientsBar, TOP, 0, -25)						
						if ctlAlchemyTooltip then					
							ctlAlchemyTooltip.tip:ClearLines()
							ctlAlchemyTooltip:SetHidden(true) 					
						end
					end
				else
					control.tooltip:SetHidden(true)
					if ctlAlchemyTooltip then
						ctlAlchemyTooltip.tip:ClearLines()
						ctlAlchemyTooltip:SetHidden(true)
					end
				end
				return true
		end)

		-- enchanting
		ZO_PreHook(ZO_GamepadEnchanting, "UpdateTooltip", function(control, ...)
			local ingredientsBar = control.control:GetNamedChild("RuneSlotContainer")
			local function KelaOnSelectedDataChangedCallback (list, selectedData)
				if selectedData and selectedData.bagId and selectedData.slotIndex then
					local SHOW_COMBINED_COUNT = true
					GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, selectedData.bagId, selectedData.slotIndex, SHOW_COMBINED_COUNT)
					if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_CRAFTING) then
						local itemLink = GetItemLink(selectedData.bagId, selectedData.slotIndex)
						local itemUniqueId = GetItemUniqueId(selectedData.bagId, selectedData.slotIndex)
						local parentControl = GAMEPAD_TOOLTIPS:GetTooltipInfo(GAMEPAD_LEFT_TOOLTIP).bgControl
						KPUI_GAMEPAD_TOOLTIPS:ClearTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP)
						KPUI_GAMEPAD_TOOLTIPS:LayoutTradingTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP, "GAMEPAD_ENCHANTING_EXTRACTION", itemLink, selectedData, KPUI_GAMEPAD_TRADING_TOOLTIP, parentControl, false, 7, nil, itemUniqueId)		
					else
						KPUI_GAMEPAD_TOOLTIPS:HideTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP)
					end
				else
					GAMEPAD_TOOLTIPS:ClearLines(GAMEPAD_LEFT_TOOLTIP)
					KPUI_GAMEPAD_TOOLTIPS:HideTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP)
				end					
			end
			-- setting
			if not hookEnchantingTooltipAlready then
				control.resultTooltip.tip.styleNamespace = ZO_TOOLTIP_STYLES
				control.resultTooltip.tip:SetStyles(control.resultTooltip.tip:GetStyle("tooltip"))
				ingredientsBar:ClearAnchors()
				ingredientsBar:SetAnchor(BOTTOM, GuiRoot, BOTTOMLEFT, ZO_GAMEPAD_PROVISIONER_INGREDIENTS_BAR_OFFSET_X, ZO_GAMEPAD_CRAFTING_UTILS_FLOATING_BOTTOM_OFFSET + 30)
				if not ctlEnchantingTooltip then ctlEnchantingTooltip = CreateControlFromVirtual("$(parent)TradingTip", control.resultTooltip, "KPUI_CraftingTooltip") end
				ctlEnchantingTooltip:SetHidden(true)
				GAMEPAD_ENCHANTING_CREATION_SCENE:RegisterCallback("StateChange", function(oldState, newState)
					if newState == SCENE_HIDDEN then
						if ctlEnchantingTooltip then
							ctlEnchantingTooltip.tip:ClearLines()
							ctlEnchantingTooltip:SetHidden(true)
						end
						HideEnchantingTooltipControls() -- release custom tooltip controls during teardown
					end
				end)
				GAMEPAD_ENCHANTING_EXTRACTION_SCENE:RegisterCallback("StateChange", function(oldState, newState)
					if newState == SCENE_SHOWING then
						control.inventory.list:SetOnSelectedDataChangedCallback(KelaOnSelectedDataChangedCallback)
						KelaOnSelectedDataChangedCallback (control.inventory.list, control.inventory.list:GetSelectedData())
					elseif newState == SCENE_HIDDEN then
						control.inventory.list:RemoveOnSelectedDataChangedCallback(KelaOnSelectedDataChangedCallback)
						KPUI_GAMEPAD_TOOLTIPS:HideTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP)
					end
				end)	
				hookEnchantingTooltipAlready = true
			end	
			if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_CRAFTING) then
				control.resultTooltip:ClearAnchors()
				control.resultTooltip:SetAnchor(BOTTOM, ingredientsBar, TOP, -254, -25)
				if ctlEnchantingTooltip then
					ctlEnchantingTooltip:ClearAnchors()
					ctlEnchantingTooltip:SetAnchor(BOTTOMLEFT, control.resultTooltip, BOTTOMRIGHT, 38)
				end
			else
				control.resultTooltip:ClearAnchors()
				control.resultTooltip:SetAnchor(BOTTOM, ingredientsBar, TOP, 0, -25)
				if ctlEnchantingTooltip then ctlEnchantingTooltip:SetHidden(true) end
			end
			if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_CRAFTING) then
				control.extractionSlotContainer:ClearAnchors()
				control.extractionSlotContainer:SetAnchor(CENTER, GuiRoot, CENTER, 740, 300)
			else
				control.extractionSlotContainer:ClearAnchors()
				control.extractionSlotContainer:SetAnchor(CENTER, GuiRoot, CENTER, 370, 300)			
			end
			if control:IsCraftable() then
				control.resultTooltip:SetHidden(false)
				control.resultTooltip.tip:ClearLines()
				control.resultTooltip.tip:LayoutEnchantingPreview(control:GetAllCraftingBagAndSlots())
				if ctlEnchantingTooltip and IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_CRAFTING) then 
					local itemLink = GetEnchantingResultingItemLink(control:GetAllCraftingBagAndSlots())				
					local maxIterations = GetMaxIterationsPossibleForEnchantingItem(control:GetAllCraftingBagAndSlots())				
					ZO_Tooltip:LayoutEnchantingTradingTooltip(ctlEnchantingTooltip, itemLink, maxIterations)
					ctlEnchantingTooltip:SetHidden(false) 
				end
			elseif control:IsExtractable() and control.extractionSlot:HasOneItem() then
			else
				control.resultTooltip:SetHidden(true)
				if ctlEnchantingTooltip and IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_CRAFTING) then 
					ctlEnchantingTooltip.tip:ClearLines()
					ctlEnchantingTooltip:SetHidden(true) 
				end
			end
			return true
		end)

		-- recipe crafting
		ZO_PreHook(ZO_GamepadProvisioner, "RefreshRecipeDetails", function(control, selectedData, ...)
			-- setting
			if not hookProvisionerTooltipAlready then
				control.resultTooltip.tip.styleNamespace = ZO_TOOLTIP_STYLES
				control.resultTooltip.tip:SetStyles(control.resultTooltip.tip:GetStyle("tooltip"))
				if not ctlProvisionerTooltip then ctlProvisionerTooltip = CreateControlFromVirtual("$(parent)TradingTip", control.resultTooltip, "KPUI_CraftingTooltip") end
				ctlProvisionerTooltip:ClearAnchors()
				ctlProvisionerTooltip:SetAnchor(BOTTOMLEFT, control.resultTooltip, BOTTOMRIGHT, 26)
				ctlProvisionerTooltip:SetHidden(true)

				-- Recipe mode is also embedded in the alchemy station through the creation scene.
				-- The root scene is not shown there, so clean up on the creation scene instead.
				GAMEPAD_PROVISIONER_CREATION_SCENE:RegisterCallback("StateChange", function(oldState, newState)
					if newState == SCENE_HIDDEN then
						ResetProvisionerTradingTooltip()
					end
				end)
				hookProvisionerTooltipAlready = true
			end
			-- RefreshRecipeDetails(nil) is the close/clear path. Do not re-anchor the
			-- tooltip or ingredients bar while the scene is tearing down.
			if not selectedData then
				ResetProvisionerTradingTooltip()
				return
			end
			local ingredientsBar = control.control:GetNamedChild("IngredientsBar")
			ingredientsBar:ClearAnchors()
			control.resultTooltip:ClearAnchors()
			ingredientsBar:SetAnchor(BOTTOM, GuiRoot, BOTTOMLEFT, ZO_GAMEPAD_PROVISIONER_INGREDIENTS_BAR_OFFSET_X, ZO_GAMEPAD_CRAFTING_UTILS_FLOATING_BOTTOM_OFFSET + 80)
			if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_CRAFTING) then
				control.resultTooltip:SetAnchor(BOTTOM, ingredientsBar, TOP, -248, -75)
			else
				control.resultTooltip:SetAnchor(BOTTOM, ingredientsBar, TOP, 0, -75)
			end
		end)
		SecurePostHook(ZO_GamepadProvisioner, "RefreshRecipeDetails", function(control, selectedData, ...)
			if not selectedData then
				ResetProvisionerTradingTooltip()
				return
			end
			if not IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_CRAFTING) then
				ResetProvisionerTradingTooltip()
				return
			end
			local recipeListIndex, recipeIndex = selectedData.recipeListIndex, selectedData.recipeIndex
			-- trading tooltip
			if ctlProvisionerTooltip then
				ZO_Tooltip:LayoutProvisionerTradingTooltip(ctlProvisionerTooltip, recipeListIndex, recipeIndex, selectedData)
				ctlProvisionerTooltip:SetHidden(false)
			end
		end)

		-- ammunition crafting
		ZO_PreHook(ZO_GamepadSmithingCreation, "SetupResultTooltip", function(control, selectedPatternIndex, selectedMaterialIndex, selectedMaterialQuantity, selectedStyleId, selectedTraitIndex, ...)
			-- setting
			if not hookCreationTooltipAlready then
				control.resultTooltip.tip.styleNamespace = ZO_TOOLTIP_STYLES
				control.resultTooltip.tip:SetStyles(control.resultTooltip.tip:GetStyle("tooltip"))
				if not ctlCreationTooltip then ctlCreationTooltip = CreateControlFromVirtual("$(parent)TradingTip", control.resultTooltip, "KPUI_CraftingTooltip") end
				ctlCreationTooltip:ClearAnchors()
				ctlCreationTooltip:SetAnchor(LEFT, control.resultTooltip, RIGHT, 26)				
				ctlCreationTooltip:SetHidden(true)
				GAMEPAD_SMITHING_CREATION_SCENE:RegisterCallback("StateChange", function(oldState, newState)
					if newState == SCENE_HIDDEN then
						ResetCreationTradingTooltip()
					end
				end)
				hookCreationTooltipAlready = true
			end	
			if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_CRAFTING) then
				control.resultTooltip:ClearAnchors()
				control.resultTooltip:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)				
				ctlCreationTooltip:SetHidden(false)
			else
				control.resultTooltip:ClearAnchors()
				control.resultTooltip:SetAnchor(CENTER, GuiRoot, LEFT, ZO_GAMEPAD_PANEL_FLOATING_CENTER_QUADRANT_1_SHOWN, ZO_GAMEPAD_PANEL_FLOATING_CENTER_OFFSET_Y)	
				ResetCreationTradingTooltip()
			end
			control.resultTooltip.tip:LayoutPendingSmithingItem(selectedPatternIndex, selectedMaterialIndex, selectedMaterialQuantity, selectedStyleId, selectedTraitIndex)
			if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_CRAFTING) then
				local itemLink = GetSmithingPatternResultLink(selectedPatternIndex, selectedMaterialIndex, selectedMaterialQuantity, selectedStyleId, selectedTraitIndex)
				if itemLink and itemLink ~= "" then 
					ZO_Tooltip:LayoutSmithingCreationTooltip(ctlCreationTooltip, itemLink) 
				else
					ResetCreationTradingTooltip()
				end
			end
			return true
		end)

		-- Smithing Deconstruction
		SecurePostHook(ZO_GamepadSmithingExtraction, "UpdateSelection", function(control, ...)
			control.slotContainer:ClearAnchors()
				if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_CRAFTING) then
					control.slotContainer:SetAnchor(CENTER, GuiRoot, CENTER, 740, 300)
				else
					control.slotContainer:SetAnchor(BOTTOM, GuiRoot, BOTTOMLEFT, ZO_GAMEPAD_PANEL_FLOATING_CENTER_QUADRANT_1_2_SHOWN, ZO_GAMEPAD_CRAFTING_UTILS_FLOATING_BOTTOM_OFFSET)				
				end
			if (SCENE_MANAGER:IsShowing("gamepad_smithing_deconstruct") and not hookDeconstructTooltipAlready) or (SCENE_MANAGER:IsShowing("gamepad_smithing_refine") and not hookRefineTooltipAlready) then
				control.slotContainer:GetNamedChild("ExtractionSlot"):GetNamedChild("Name"):SetFont("ZoFontGamepadCondensed34")
				control.tooltip.tip.styleNamespace = ZO_TOOLTIP_STYLES
				control.tooltip.tip:SetStyles(control.tooltip.tip:GetStyle("tooltip"))

				control.inventory.list:RemoveAllOnSelectedDataChangedCallbacks()
				control.inventory.list:SetOnSelectedDataChangedCallback(function(list, selectedData)
					KEYBIND_STRIP:UpdateKeybindButtonGroup(control.keybindStripDescriptor)
					control.itemActions:SetInventorySlot(selectedData)
					if selectedData and selectedData.bagId and selectedData.slotIndex then
						local SHOW_COMBINED_COUNT = true
						GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, selectedData.bagId, selectedData.slotIndex, SHOW_COMBINED_COUNT)
						if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_CRAFTING) then
							local itemLink = GetItemLink(selectedData.bagId, selectedData.slotIndex)
							local itemUniqueId = GetItemUniqueId(selectedData.bagId, selectedData.slotIndex)
							local parentControl = GAMEPAD_TOOLTIPS:GetTooltipInfo(GAMEPAD_LEFT_TOOLTIP).bgControl
							KPUI_GAMEPAD_TOOLTIPS:ClearTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP)
							KPUI_GAMEPAD_TOOLTIPS:LayoutTradingTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP, "GAMEPAD_SMITHING_EXTRACTION", itemLink, selectedData, KPUI_GAMEPAD_TRADING_TOOLTIP, parentControl, false, 7, nil, itemUniqueId)		
						else
							KPUI_GAMEPAD_TOOLTIPS:HideTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP)
						end
					else
						GAMEPAD_TOOLTIPS:ClearLines(GAMEPAD_LEFT_TOOLTIP)
						KPUI_GAMEPAD_TOOLTIPS:HideTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP)
					end
				end)
				if SCENE_MANAGER:IsShowing("gamepad_smithing_deconstruct") then
					hookDeconstructTooltipAlready = true
				elseif SCENE_MANAGER:IsShowing("gamepad_smithing_refine") then 
					hookRefineTooltipAlready = true
				end
			end
		end)
		ZO_PreHook(ZO_GamepadSmithingExtraction, "RefreshTooltip", function(control, ...)
			if control.extractionSlot:HasOneItem() then
			else
				control.tooltip:SetHidden(true)
			end
			return true
		end)

		--	improvement scene
		ZO_PreHook(ZO_GamepadSmithingImprovement, "UpdateSelection", function(control, ...)
			-- Setting
			if not hookCraftingStationKeybindAlready then
				control.sourceTooltip.tip.styleNamespace = ZO_TOOLTIP_STYLES				
				control.resultTooltip.tip.styleNamespace = ZO_TOOLTIP_STYLES
				control.sourceTooltip.tip:SetStyles(control.sourceTooltip.tip:GetStyle("tooltip"))
				control.resultTooltip.tip:SetStyles(control.resultTooltip.tip:GetStyle("tooltip"))	
				-- set up inventory keybinds and tooltips
				control.inventory.list:RemoveAllOnSelectedDataChangedCallbacks()
				control.inventory.list:SetOnSelectedDataChangedCallback(function(list, selectedData)
					KEYBIND_STRIP:UpdateKeybindButtonGroup(control.keybindStripDescriptor)
					control.itemActions:SetInventorySlot(selectedData)
					if selectedData and selectedData.bagId and selectedData.slotIndex then
						local itemUniqueId = GetItemUniqueId(selectedData.bagId, selectedData.slotIndex)
						ZO_Tooltip:LayoutSmithingTradingTooltip(control.sourceTooltip, selectedData.bagId, selectedData.slotIndex, nil, itemUniqueId, selectedData)
						control:Refresh()
						-- selectedData.quality is deprecated, included here for addon backwards compatibility
						local functionalQuality = selectedData.functionalQuality or selectedData.quality
						control:ColorizeText(control:GetBoosterRowForQuality(functionalQuality))
						control.selectedItem = selectedData
						if not control:HasSelections() then
							control.resultTooltip:SetHidden(true)
							control.slotContainer:SetHidden(true)
							control:EnableQualityBridge(false)
						end
						control:SetInventoryActive(true)
						if control.shouldActivateTabBar then
							ZO_GamepadGenericHeader_Activate(control.owner.header)
						end
						control.spinner:Deactivate()
						GAMEPAD_CRAFTING_RESULTS:SetCraftingTooltip(control.resultTooltip)
						GAMEPAD_CRAFTING_RESULTS:SetTooltipAnimationSounds(ZO_SharedSmithingImprovement_GetImprovementTooltipSounds())
						GAMEPAD_CRAFTING_RESULTS:ClearSecondaryTooltipAnimationControls()
						GAMEPAD_CRAFTING_RESULTS:AddSecondaryTooltipAnimationControl(control.sourceTooltip)
						GAMEPAD_CRAFTING_RESULTS:AddSecondaryTooltipAnimationControl(control.qualityBridge)
					else
						control.sourceTooltip.tip:ClearLines()
						control.sourceTooltip:SetHidden(true)
						GAMEPAD_CRAFTING_RESULTS:SetCraftingTooltip(nil)
						control:ClearBoosterRowHighlight()
						control.selectedItem = nil
						control:Refresh()
					end
				end)
				KelaPadUI.kelaCraftingKeybindStripDescriptor =
					{
						-- toggle tooltip
						{
							alignment = KEYBIND_STRIP_ALIGN_CENTER,	
							name = function()
								return GetString(KELA_TRADING_VIEW_MODE)
							end,
							keybind = "UI_SHORTCUT_RIGHT_STICK",
							visible = function() return true end,
							callback = function() 
								local bagId, slotIndex
								if control.improvementSlot:HasItem() then
									bagId, slotIndex = control.improvementSlot:GetBagAndSlot()
								end
								if KELA_SMITHING_IMPROVED_TOOLTIP_TYPE == 0 then
									KELA_SMITHING_IMPROVED_TOOLTIP_TYPE = 1
								else
									KELA_SMITHING_IMPROVED_TOOLTIP_TYPE = 0
								end
								control:SetupResultTooltip(bagId, slotIndex, GetCraftingInteractionType())
							end,
						},		
					}			
				GAMEPAD_SMITHING_IMPROVEMENT_SCENE:RegisterCallback("StateChange", function(oldState, newState) 
					-- states: hiding, showing, shown, hidden
					if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_CRAFTING) then
						if(newState == "showing") then
							KEYBIND_STRIP:AddKeybindButtonGroup(KelaPadUI.kelaCraftingKeybindStripDescriptor)
						elseif(newState == "hiding") then
							KEYBIND_STRIP:RemoveKeybindButtonGroup(KelaPadUI.kelaCraftingKeybindStripDescriptor)
						end
					end
				end) 
				hookCraftingStationKeybindAlready = true
			end	
			if control.selectedItem then
				-- control.selectedItem.quality is deprecated, included here for addon backwards compatibility
				local functionalQuality = control.selectedItem.functionalQuality or control.selectedItem.quality
				control:ColorizeText(control:GetBoosterRowForQuality(functionalQuality))
			else
				control:ClearBoosterRowHighlight()
			end
			control.inventory:PerformFullRefresh()
			return true
		end)
		ZO_PreHook(ZO_GamepadSmithingImprovement, "SetupResultTooltip", function(control, itemToImproveBagId, itemToImproveSlotIndex, craftingSkillType, ...)
			-- source item
			local bagId, slotIndex
			if control.improvementSlot:HasItem() then
				bagId, slotIndex = control.improvementSlot:GetBagAndSlot()
			else
				local selectedData = control.selectedItem
				if selectedData and selectedData.bagId and selectedData.slotIndex then
					bagId = selectedData.bagId
					slotIndex = selectedData.slotIndex
				end
			end
			local itemUniqueId = GetItemUniqueId(bagId, slotIndex)
			ZO_Tooltip:LayoutSmithingTradingTooltip(control.sourceTooltip, bagId, slotIndex, nil, itemUniqueId, selectedData)
			-- result item
			local itemUniqueId = GetItemUniqueId(itemToImproveBagId, itemToImproveSlotIndex)
			ZO_Tooltip:LayoutSmithingTradingTooltip(control.resultTooltip, itemToImproveBagId, itemToImproveSlotIndex, craftingSkillType, itemUniqueId, selectedData)
			return true
		end)
		hookCraftingStationAlready = true
	end
end	

function KelaSetupTradingHouse()
	if not kpuiSVBuyingData or not kpuiSVListingData then
		return
	end
	if KelaPadUI.KelaTradingHouseSetupStarted then
		return
	end
	KelaPadUI.KelaTradingHouseSetupStarted = true

	-- set up the guild store
	SecurePostHook(ZO_GamepadTradingHouse, "OpenTradingHouse", function()
		if not hookTradingHouseAlready then
			-- hide when switching pages
			SecurePostHook(ZO_GamepadTradingHouse, "SetCurrentListObject", function(control, listObject, ...)
				if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_TRADINGHOUSE) then
					KPUI_GAMEPAD_TOOLTIPS:HideTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP)
				end
			end)
			-- sell window
			SecurePostHook(GAMEPAD_TRADING_HOUSE_SELL, "UpdateItemSelectedTooltip", function(control, selectedData, ...)
				if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_TRADINGHOUSE) then
					if selectedData then
						local bag, index = ZO_Inventory_GetBagAndIndex(selectedData)
						
						local itemUniqueId = GetItemUniqueId(bag, index)
						local itemLink = GetItemLink(bag, index)
						local parentControl = GAMEPAD_TOOLTIPS:GetTooltipInfo(GAMEPAD_LEFT_TOOLTIP).bgControl
						KPUI_GAMEPAD_TOOLTIPS:ClearTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP)
						KPUI_GAMEPAD_TOOLTIPS:LayoutTradingTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP, "GAMEPAD_TRADING_HOUSE_SELL", itemLink, selectedData, KPUI_GAMEPAD_TRADING_TOOLTIP, parentControl, false, 5, nil, itemUniqueId)		
					else
						KPUI_GAMEPAD_TOOLTIPS:HideTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP)
					end		
				end
			end)
			-- hide when leaving the page
			SecurePostHook(GAMEPAD_TRADING_HOUSE_SELL, "OnHiding", function(control, ...)
				if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_TRADINGHOUSE) then
					KPUI_GAMEPAD_TOOLTIPS:HideTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP)
				end
			end)
			-- active listing window
			SecurePostHook(GAMEPAD_TRADING_HOUSE_LISTINGS, "UpdateItemSelectedTooltip", function(control, selectedData, ...)
				if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_TRADINGHOUSE) then
					if selectedData then
						local itemLink = selectedData.itemLink
						local parentControl = GAMEPAD_TOOLTIPS:GetTooltipInfo(GAMEPAD_LEFT_TOOLTIP).bgControl	
						KPUI_GAMEPAD_TOOLTIPS:ClearTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP)
						KPUI_GAMEPAD_TOOLTIPS:LayoutTradingTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP, "GAMEPAD_TRADING_HOUSE_LISTINGS", itemLink, selectedData, KPUI_GAMEPAD_TRADING_TOOLTIP, parentControl, false, 5)		
					else
						KPUI_GAMEPAD_TOOLTIPS:HideTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP)
					end
				end
			end)
			-- SEARCH WINDOW
			-- add deal-value filter buttons
			SecurePostHook(GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS, "OnShowing", function(control, ...)
				local keybind  = 
				{
					alignment = KEYBIND_STRIP_ALIGN_LEFT,	
					name = "Name",
					keybind = "UI_SHORTCUT_RIGHT_STICK",
					callback = function()
							KELA_CURRENT_EFFECTDEAL_SELECTION_INDEX = (KELA_CURRENT_EFFECTDEAL_SELECTION_INDEX == 5) and 1 or (KELA_CURRENT_EFFECTDEAL_SELECTION_INDEX + 1)
							control:Deactivate()
							control:FilterScrollList()
							ZO_SortFilterList.CommitScrollList(control)
							control:RefreshPagingControls()
							control:UpdateKeybinds()
							control:Activate()
						end,
					ethereal = true,
				}
				control:AddUniversalKeybind(keybind)

				local keybind  = 
				{
					alignment = KEYBIND_STRIP_ALIGN_LEFT,	
					name = "Known Item Filter",
					keybind = "UI_SHORTCUT_LEFT_STICK",
					callback = function()
							if KELA_KNOWN_ITEM_FILTER == "ALL" then 
								KELA_KNOWN_ITEM_FILTER = "UNKNOWN"
							elseif KELA_KNOWN_ITEM_FILTER == "UNKNOWN" then
								KELA_KNOWN_ITEM_FILTER = "KNOWN"
							else
								KELA_KNOWN_ITEM_FILTER = "ALL"
							end
							control:Deactivate()
							control:FilterScrollList()
							ZO_SortFilterList.CommitScrollList(control)
							control:RefreshPagingControls()
							control:UpdateKeybinds()
							control:Activate()
						end,
					ethereal = true,
				}
				control:AddUniversalKeybind(keybind)

				local keybind  =
				{
					name = "Gamepad Interactive Sort Filter List Left Trigger",
					keybind = "UI_SHORTCUT_LEFT_TRIGGER",
					ethereal = true,
					callback = function()
						control:OnLeftTrigger()
					end,
				}
				control:AddUniversalKeybind(keybind)

				local keybind  =
				{
					name = "Gamepad Interactive Sort Filter List Right Trigger",
					keybind = "UI_SHORTCUT_RIGHT_TRIGGER",
					ethereal = true,
					callback = function()
						control:OnRightTrigger()
					end,
				}
				control:AddUniversalKeybind(keybind)
			end)
			-- add the trade message
			SecurePostHook(GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS, "UpdateItemSelectedTooltip", function(control, selectedData, ...)
				if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_TRADINGHOUSE) then
					if selectedData then
						local itemLink
						if selectedData.isGuildSpecificItem then
							itemLink = GetGuildSpecificItemLink(selectedData.slotIndex)
						else
							itemLink = selectedData.itemLink
						end
						local parentControl = GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS.control
						KPUI_GAMEPAD_TOOLTIPS:ClearTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP)
						local customScale = GetUICustomScale()
						if customScale > 0.8 then
							KPUI_GAMEPAD_TOOLTIPS:LayoutTradingTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP, "GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS", itemLink, selectedData, KPUI_GAMEPAD_TRADING_TOOLTIP, parentControl, true, 50)		
						else
							KPUI_GAMEPAD_TOOLTIPS:LayoutTradingTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP, "GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS", itemLink, selectedData, KPUI_GAMEPAD_TRADING_TOOLTIP, parentControl, false, 45)	
						end
					else
						KPUI_GAMEPAD_TOOLTIPS:HideTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP)
					end
				end
			end)
			-- keep page-turn buttons visible on headers
			ZO_PreHook(GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS, "RefreshPagingControls", function(control, ...)
				if IsKPUITradingHouseSettingEnabled() then
					local enablePrevious = TRADING_HOUSE_SEARCH:HasPreviousPage()
					local enableNext = TRADING_HOUSE_SEARCH:HasNextPage()
					local hideButtons = not (enablePrevious or enableNext)
					local prevButton = control.footer.previousButton
					local nextButton = control.footer.nextButton
					prevButton:SetEnabled(enablePrevious)
					nextButton:SetEnabled(enableNext)
					prevButton:SetHidden(hideButtons)
					nextButton:SetHidden(hideButtons)
					local scrollData = ZO_ScrollList_GetDataList(control.list)
					if next(scrollData) == nil then
						if TRADING_HOUSE_SEARCH.numItemsOnPage ~= 0 then
							control:SetEmptyText(colors.COLOR_WHITE:Colorize("0")..GetString(KELA_TRADING_TRADING_NOTEFFECTLOTS)..colors.COLOR_WHITE:Colorize(tostring(TRADING_HOUSE_SEARCH.numItemsOnPage)))
						end
					else
						control:SetEmptyText(GetString("SI_TRADINGHOUSESEARCHSTATE", 1))
					end
					if not hideButtons then
						control.footer.pageNumberLabel:SetHidden(false)
						control.footer.pageNumberLabel:SetText(tostring(#scrollData).." / "..tostring(TRADING_HOUSE_SEARCH.numItemsOnPage)..GetString(KELA_TRADING_TRADING_PAGES)..zo_strformat(SI_GAMEPAD_PAGED_LIST_PAGE_NUMBER, TRADING_HOUSE_SEARCH:GetPage() + 1))
					else
						control.footer.pageNumberLabel:SetHidden(true)
					end
					return true
				end
			end)
			-- empty-list text
			ZO_PreHook(GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS, "OnSearchStateChanged", function(control, searchState, searchOutcome, ...)
				if IsKPUITradingHouseSettingEnabled() then
					local shouldActivateBrowseResults = false
					local shouldDeactivateBrowseResults = false
					if searchState == TRADING_HOUSE_SEARCH_STATE_NONE then
						control:SetEmptyText("")
						control:RefreshPagingControls()
					elseif searchState == TRADING_HOUSE_SEARCH_STATE_WAITING then
						control:SetEmptyText(GetString("SI_TRADINGHOUSESEARCHSTATE", searchState))
					elseif searchState == TRADING_HOUSE_SEARCH_STATE_COMPLETE then
						if searchOutcome == TRADING_HOUSE_SEARCH_OUTCOME_HAS_RESULTS then
							control:DeselectListData()
							shouldActivateBrowseResults = true
							control:RefreshPagingControls()
						else
							control:SetEmptyText(GetString("SI_TRADINGHOUSESEARCHOUTCOME", searchOutcome))
							shouldDeactivateBrowseResults = (searchOutcome == TRADING_HOUSE_SEARCH_OUTCOME_ALL_RESULTS_PURCHASED)
						end
					end
					control:RefreshData()
					if TRADING_HOUSE_GAMEPAD_SCENE:IsShowing() then
						if shouldActivateBrowseResults then
							if control:IsActive() then
								-- We are already activated, focus on the panel so we start on the first item entry
								control:ActivatePanelFocus()
							else
								TRADING_HOUSE_GAMEPAD:ActivateBrowseResults()
							end
						end
						if shouldDeactivateBrowseResults then
							if control:IsActive() then
								TRADING_HOUSE_GAMEPAD:DeactivateBrowseResults()
							end
						end
					end
					return true
				end
			end)
			ZO_PreHook(GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS, "FilterScrollList", function(control, ...)		
				if IsKPUITradingHouseSettingEnabled() then
					local scrollData = ZO_ScrollList_GetDataList(control.list)
					-- Search results can be non-contiguous: bought items keep their index but get removed from the scroll list
					ZO_ClearTable(control.searchResultItemDataList)
					ZO_ClearNumericallyIndexedTable(scrollData)
					ZO_ClearNumericallyIndexedTable(control.previewListEntries)
					if TRADING_HOUSE_SEARCH:ShouldShowGuildSpecificItems() then
						for i = 1, GetNumGuildSpecificItems() do
							local itemData = TRADING_HOUSE_GAMEPAD:CreateGuildSpecificItemData(i, GetGuildSpecificItemInfo)
							if itemData then
								itemData.isGuildSpecificItem = true
								local dataEntry = ZO_ScrollList_CreateDataEntry(ZO_GAMEPAD_INTERACTIVE_FILTER_LIST_PRIMARY_DATA_TYPE, itemData)
								table.insert(scrollData, dataEntry)
							end
						end
					else
						for tradingHouseItemIndex = 1, TRADING_HOUSE_SEARCH:GetNumItemsOnPage() do
							local itemData = ZO_TradingHouse_CreateSearchResultItemData(tradingHouseItemIndex)
							if itemData then
								local _, _, priceInfoTTC, priceInfoATT = KelaGetPriceInfoTTCATT(itemData.itemLink)
								local valueEffectDeal = KelaGetEffectOfDeal (priceInfoTTC, priceInfoATT, itemData, "GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS")

								local itemType, specializedItemType = GetItemLinkItemType(itemData.itemLink)
								local grantedCollectibleId = GetItemLinkContainerCollectibleId(itemData.itemLink)
								local isItemKnown = "ALL"
								if IsItemLinkBook(itemData.itemLink) or IsItemLinkBookPartOfCollection(itemData.itemLink) then
									-- Motifs and books
									if IsItemLinkBookKnown(itemData.itemLink) then
										isItemKnown = "KNOWN"
									else
										isItemKnown = "UNKNOWN"
									end
								elseif itemType == ITEMTYPE_RECIPE then
									-- Recipe's
									if IsItemLinkRecipeKnown(itemData.itemLink) then
										isItemKnown = "KNOWN"
									else
										isItemKnown = "UNKNOWN"
									end
								elseif IsItemLinkSetCollectionPiece(itemData.itemLink) then
									-- Sets: Armor, weapon, and jewelry
									local itemId = GetItemLinkItemId(itemData.itemLink)
									if IsItemSetCollectionPieceUnlocked(itemId) then
										isItemKnown = "KNOWN"
									else
										isItemKnown = "UNKNOWN"
									end
								elseif grantedCollectibleId > 0 then
									-- Other Collectibles: runeboxes, style pages, etc
									local collectibleCategory = GetCollectibleCategoryType(grantedCollectibleId)
									if IsCollectibleOwnedByDefId(grantedCollectibleId) then
										isItemKnown = "KNOWN"
									elseif collectibleCategory == COLLECTIBLE_CATEGORY_TYPE_COMBINATION_FRAGMENT and not CanCombinationFragmentBeUnlocked(grantedCollectibleId) then
										isItemKnown = "KNOWN"
									else
										isItemKnown = "UNKNOWN"
									end
								end

								if valueEffectDeal == "-" then 
									valueEffectDeal = KelaGetEffectIfUndefined(itemData)
								end
								if KELA_CURRENT_EFFECTDEAL_SELECTION_INDEX == 1 or (KELA_CURRENT_EFFECTDEAL_SELECTION_INDEX == 2 and valueEffectDeal == 0) or (KELA_CURRENT_EFFECTDEAL_SELECTION_INDEX > 2 and valueEffectDeal >= KELA_CURRENT_EFFECTDEAL_SELECTION_INDEX) then	
									if KELA_KNOWN_ITEM_FILTER=="ALL" or (KELA_KNOWN_ITEM_FILTER==isItemKnown) then
										local dataEntry = ZO_ScrollList_CreateDataEntry(ZO_GAMEPAD_INTERACTIVE_FILTER_LIST_PRIMARY_DATA_TYPE, itemData)
										control.searchResultItemDataList[tradingHouseItemIndex] = itemData
										table.insert(scrollData, dataEntry)
										if control:CanPreviewTradingHouseItem(itemData) then
											table.insert(control.previewListEntries, tradingHouseItemIndex)
										end
									end
								end
							end
						end
						control:RefreshPagingControls()
					end
					if TRADING_HOUSE_PREVIEW_GAMEPAD_SCENE:IsShowing() then
						control:UpdatePreviewForChangedData()
					end
					return true
				end
			end)
			SecurePostHook(GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS, "FilterScrollList", function(control, ...)		
				if IsKPUITradingHouseSettingEnabled() then
					control.contentHeaderData.data1HeaderText = colors.COLOR_WHITE:Colorize(zo_iconFormat(kpuiConst.stringDDS.leftStickXBOne, 44, 44)).." "..GetString(KELA_TRADING_FILTER_KNOWN)..KELA_KNOWN_ITEM_FILTER
					control.contentHeaderData.data2HeaderText = ""
					control.contentHeaderData.data3HeaderText = colors.COLOR_WHITE:Colorize(zo_iconFormat(kpuiConst.stringDDS.rightStickXBOne, 44, 44)).." "..KelaCreateColorizedResumePrice(KELA_CURRENT_EFFECTDEAL_SELECTION_INDEX)
					ZO_GamepadGenericHeader_RefreshData(control.contentHeader, control.contentHeaderData)
				end
			end)
			local PRICE_THRESHOLD_DIGITS = 6
			local PRICE_THRESHOLD = zo_pow(10, PRICE_THRESHOLD_DIGITS)
			ZO_PostHook(GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS, "SetupResultItemRow", function(selfControl, control, itemData, ...)		
				if IsKPUITradingHouseSettingEnabled() then
					local colorPrice = colors.COLOR_WHITE
					local trueTTC, trueATT, priceInfoTTC, priceInfoATT = KelaGetPriceInfoTTCATT(itemData.itemLink)
					local priceInfo = (trueTTC and priceInfoTTC) or (trueATT and priceInfoATT)
					if priceInfo then
						local valueEffectDeal, _, colorEffectDeal = KelaGetEffectOfDeal (priceInfoTTC, priceInfoATT, itemData, "GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS")
						local avgPrice = priceInfo.Avg
						local minPrice = priceInfo.Min
						local maxPrice = priceInfo.Max
						if valueEffectDeal ~= "-" then
							colorPrice = colorEffectDeal
						elseif avgPrice ~= 0 and itemData.purchasePricePerUnit ~= avgPrice then
							if itemData.purchasePricePerUnit <= minPrice + (avgPrice-minPrice)*0.1 then
								colorPrice = colors.COLOR_DEALGREAT
							elseif itemData.purchasePricePerUnit <= minPrice + (avgPrice-minPrice)*0.7 then
								colorPrice = colors.COLOR_DEALGOOD
							elseif itemData.purchasePricePerUnit <= avgPrice + (maxPrice-avgPrice)*0.3 then
								colorPrice = colors.COLOR_DEALNORMAL
							elseif itemData.purchasePricePerUnit <= avgPrice + (maxPrice-avgPrice)*0.7 then
								colorPrice = colors.COLOR_DEALBAD
							elseif itemData.purchasePricePerUnit >= avgPrice + (maxPrice-avgPrice)*0.7 then
								colorPrice = colors.COLOR_DEALTERRIBLE
							end
						end
					end
					control.unitPriceLabel:SetColor(colorPrice:UnpackRGB())
				end
			end)
			-- TRADING_HOUSE_CREATE_LISTING_GAMEPAD
			-- create-listing window
			SecurePostHook(TRADING_HOUSE_CREATE_LISTING_GAMEPAD, "Showing", function(control, ...)
				if IsKPUITradingHouseSettingEnabled() then
					local itemLink = GetItemLink(control.itemBag, control.itemIndex)
					if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_TRADINGHOUSE) then
						selectedData = control.selectedData
						local itemUniqueId = GetItemUniqueId(control.itemBag, control.itemIndex)
						if itemLink then
							local parentControl = GAMEPAD_TOOLTIPS:GetTooltipInfo(GAMEPAD_LEFT_TOOLTIP).bgControl	
							KPUI_GAMEPAD_TOOLTIPS:ClearTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP)
							KPUI_GAMEPAD_TOOLTIPS:LayoutTradingTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP, "TRADING_HOUSE_CREATE_LISTING_GAMEPAD", itemLink, selectedData, KPUI_GAMEPAD_TRADING_TOOLTIP, parentControl, false, 5, nil, itemUniqueId)		
						end
					end
					local trueTTC, trueATT, priceInfoTTC, priceInfoATT = KelaGetPriceInfoTTCATT(itemLink)
					_, _, _, _, _, _, _, _, _, _, _, _, compareValuePrice = KelaGetEffectOfDeal (priceInfoTTC, priceInfoATT, selectedData)				
					-- set a custom price
					if compareValuePrice and compareValuePrice ~= 0 then 
						control:SetListingPrice(math.ceil(compareValuePrice))
					end
				end
			end)
			SecurePostHook(TRADING_HOUSE_CREATE_LISTING_GAMEPAD, "Hiding", function(control, ...)
				if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_TRADINGHOUSE) then
					KPUI_GAMEPAD_TOOLTIPS:HideTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP)
				end
			end)
			SecurePostHook(TRADING_HOUSE_CREATE_LISTING_GAMEPAD, "SetListingPrice", function(selfControl, price, isPreview, ...)
				if IsKPUITradingHouseSettingEnabled() then
					local listingFee, _, profit = GetTradingHousePostPriceInfo(price)
					selfControl.validPrice = (GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER) >= listingFee) and (price > 0) and (price <= MAX_PLAYER_CURRENCY)
					local HAS_ERROR = not selfControl.validPrice
					local colorValue = colors.COLOR_WHITE
					if HAS_ERROR then 
						colorValue = colors.COLOR_DEALTERRIBLE
					end
					selectedData = selfControl.selectedData
					local itemLink = GetItemLink(selfControl.itemBag, selfControl.itemIndex)
					if itemLink then
						local controlContainer = selfControl.control:GetNamedChild("Mask"):GetNamedChild("Container")
						local controlRail = controlContainer:GetNamedChild("Rail")
						local itemUniqueId = GetItemUniqueId(selfControl.itemBag, selfControl.itemIndex)
						local stackCount, buyPrice, buyPricePerUnit
						local itemType = GetItemLinkItemType(itemLink)
						if itemType == ITEMTYPE_MASTER_WRIT and ArkadiusTradeTools and ArkadiusTradeTools.Modules and ArkadiusTradeTools.Modules.Sales then
							stackCount = ArkadiusTradeTools.Modules.Sales:GetVoucherCount(itemLink)
						elseif selectedData and selectedData.stackCount then
							stackCount = selectedData.stackCount
						else
							stackCount = 1
						end
						if itemUniqueId then
							tblBuyingItems = kpuiSVBuyingData["buyingTable"]			
							itemUID = Id64ToString(itemUniqueId)
							if tblBuyingItems[itemUID] ~= nil then
								buyPricePerUnit = tonumber(tblBuyingItems[itemUID]["buyPricePerUnit"])
								buyPrice = buyPricePerUnit*stackCount
							end
						end				
						if stackCount > 1 then
							local numPrice = KelaRoundNumber(price / stackCount, 2)	 -- Round to 2 decimal places
							local strPrice = ZO_CurrencyControl_FormatCurrencyAndAppendIcon(numPrice, true, CURT_MONEY, true)
							if not ctlListingPriceLabel then ctlListingPriceLabel = CreateControlFromVirtual("$(parent)KPUI_ListingPrice", controlContainer, "KPUI_LabelValue") end				
							ctlListingPriceLabel:ClearAnchors()
							ctlListingPriceLabel:SetAnchor(TOPLEFT, controlRail, BOTTOMLEFT, 0, -265)
							ctlListingPriceLabel:SetAnchor(TOPRIGHT, controlRail, BOTTOMRIGHT, 0, -265)
							ctlListingPriceLabel:SetHidden(false)	
							ctlListingPriceLabel:GetNamedChild("Label"):SetText(GetString(KELA_TRADING_SALE_PRICE))
							ctlListingPriceLabel:GetNamedChild("Value"):SetText(colorValue:Colorize(strPrice))
						else
							if ctlListingPriceLabel then ctlListingPriceLabel:SetHidden(true) end
						end
						if buyPrice then
							local strClearProfit = profit-buyPrice

							if not HAS_ERROR then 
								if strClearProfit >= buyPrice then
									colorValue = colors.COLOR_DEALGREAT
								elseif strClearProfit >= buyPrice*0.3 then
									colorValue = colors.COLOR_DEALGOOD
								elseif strClearProfit >= 0 then

								elseif strClearProfit >= 0-(buyPrice*0.2) then
									colorValue = colors.COLOR_DEALBAD
								elseif strClearProfit <= 0-(buyPrice*0.2) then
									colorValue = colors.COLOR_DEALTERRIBLE
								end
							end
							strClearProfit = ZO_CurrencyControl_FormatCurrencyAndAppendIcon(strClearProfit, true, CURT_MONEY, true)
							if not ctlListingClearProfitAmountLabel then ctlListingClearProfitAmountLabel = CreateControlFromVirtual("$(parent)KPUI_ListingProfit", controlContainer, "KPUI_LabelValue") end				
							ctlListingClearProfitAmountLabel:ClearAnchors()
							ctlListingClearProfitAmountLabel:SetAnchor(TOPLEFT, controlRail, BOTTOMLEFT, 0, 95)
							ctlListingClearProfitAmountLabel:SetAnchor(TOPRIGHT, controlRail, BOTTOMRIGHT, 0, 95)
							ctlListingClearProfitAmountLabel:SetHidden(false)	
							ctlListingClearProfitAmountLabel:GetNamedChild("Label"):SetText(GetString(KELA_TRADING_SALE_CLEARPROFIT))
							ctlListingClearProfitAmountLabel:GetNamedChild("Value"):SetText(colorValue:Colorize(strClearProfit))
						else
							if ctlListingClearProfitAmountLabel then ctlListingClearProfitAmountLabel:SetHidden(true) end
						end
					end
				end

			end)
			-- Sell/purchase confirmation dialogs.  These tables mirror current core
			-- because the confirmation actions are C API calls that cannot be hooked
			-- for history updates.  The display function remains core-owned and still
			-- supplies the narration/main-text parameters.  Guild-specific-item and
			-- display-error dialogs remain core-owned because they have no Kela
			-- history side effects. Keep these copies in sync with
			-- ZO_GamepadTradingHouse_Dialogs_DisplayConfirmationDialog.
			--
			-- No dialog hooks are installed here.  An earlier version pre-hooked
			-- ZO_GamepadTradingHouse_Dialogs_DisplayConfirmationDialog and
			-- post-hooked ZO_Dialogs_ShowDialog to decorate the confirmation data,
			-- but nothing captured that data any more, so the decoration was dead
			-- code that only risked tainting the dialog callstack.
			ESO_Dialogs["TRADING_HOUSE_CONFIRM_BUY_ITEM"] =
			{
				gamepadInfo =
				{
					dialogType = GAMEPAD_DIALOGS.BASIC,
				},
				title =
				{
					text = SI_GAMEPAD_TRADING_HOUSE_CONFIRM_BUY_DIALOG_TITLE,
				},
				mainText = 
				{
					text = function(dialog)
					if dialog.data.stackCount > 1 then
							return SI_GAMEPAD_TRADING_HOUSE_CONFIRM_BUY_MULTIPLE_DIALOG_TEXT
						else
							return SI_GAMEPAD_TRADING_HOUSE_CONFIRM_BUY_DIALOG_TEXT
						end
					end,
				},
				buttons =
				{
					[1] =
					{
						text =      SI_TRADING_HOUSE_PURCHASE_ITEM_DIALOG_CONFIRM,
						callback =  function(dialog)
										if IsKPUITradingHouseSettingEnabled() then
											KelaAddToBuyingUniqueTable(dialog.data.uniqueId, dialog.data.itemName, dialog.data.price, dialog.data.pricePerUnit, dialog.data.listingIndex, dialog.data.displayQuality)
										end
										ConfirmPendingItemPurchase()
									 end
					},
					[2] =
					{
						text =      SI_TRADING_HOUSE_PURCHASE_ITEM_DIALOG_CANCEL,
						callback =  function(dialog)
										ClearPendingItemPurchase()
									end
					}
				}
			}
			local exitOnFinished = true
			ESO_Dialogs["TRADING_HOUSE_CONFIRM_SELL_ITEM"] =
			{
				gamepadInfo =
				{
					dialogType = GAMEPAD_DIALOGS.BASIC,
				},
				title =
				{
					text = SI_GAMEPAD_TRADING_HOUSE_CONFIRM_SELL_DIALOG_TITLE,
				},
				mainText = 
				{
					text =  function(dialog)
								if dialog.data.stackCount > 1 then
									return SI_GAMEPAD_TRADING_HOUSE_CONFIRM_SELL_MULTIPLE_DIALOG_TEXT
								else
									return SI_GAMEPAD_TRADING_HOUSE_CONFIRM_SELL_DIALOG_TEXT
								end
							end,
				},
				setup = function()
					exitOnFinished = false
				end,
				finishedCallback = function(dialog)
					if exitOnFinished then
						SCENE_MANAGER:HideCurrentScene()
					end
				end,
				buttons =
				{
					[1] =
					{
						text = SI_DIALOG_YES,
						callback = function(dialog)
							local stackCount = dialog.data.stackCount
							local desiredPrice = dialog.data.price
							local listingIndex = dialog.data.listingIndex
							RequestPostItemOnTradingHouse(BAG_BACKPACK, listingIndex, stackCount, desiredPrice)
							
							if IsKPUITradingHouseSettingEnabled() then
								KelaAddToListingTable(BAG_BACKPACK, listingIndex, stackCount, desiredPrice)
							end
							
							exitOnFinished = true
						end
					},
					[2] =
					{
						text = SI_DIALOG_NO,
					}  
				}
			}
			ESO_Dialogs["TRADING_HOUSE_CONFIRM_REMOVE_LISTING"] =
			{
				gamepadInfo =
				{
					dialogType = GAMEPAD_DIALOGS.BASIC,
				},
				title =
				{
					text = SI_GAMEPAD_TRADING_HOUSE_LISTING_REMOVE_DIALOG_TITLE,
				},
				mainText = 
				{
					text =  function(dialog)
								if dialog.data.stackCount > 1 then
									return SI_GAMEPAD_TRADING_HOUSE_LISTING_REMOVE_MULTIPLE_DIALOG_TEXT
								else
									return SI_GAMEPAD_TRADING_HOUSE_LISTING_REMOVE_DIALOG_TEXT
								end
							end,
				},
				buttons =
				{
					[1] =
					{
						text =      SI_DIALOG_REMOVE,
						callback =  function(dialog)
										CancelTradingHouseListing(dialog.data.listingIndex)
										if IsKPUITradingHouseSettingEnabled() then
											KelaRemoveFromListingTable(dialog.data.listingIndex, dialog.data.stackCount, dialog.data.price, dialog.data.timeRemaining)
										end
									end
					},
					[2] =
					{
						text =       SI_DIALOG_CANCEL,
					}  
				}
			}
			hookTradingHouseAlready = true
		end
	end)
	
	-- set up banking when the regular bank opens
	SecurePostHook(ZO_GamepadBanking, "OnOpenBank", function(control, bankBag, ...)
		if not hookBankingAlready then
			SecurePostHook(ZO_BankingCommon_Gamepad, "LayoutBankingEntryTooltip", function(control, inventoryData, ...)
				if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_BANK) then
					if inventoryData and inventoryData.bagId then
						local itemLink = GetItemLink(inventoryData.bagId, inventoryData.slotIndex)
						local itemUniqueId = GetItemUniqueId(inventoryData.bagId, inventoryData.slotIndex)
						if itemLink then
							local parentControl = GAMEPAD_TOOLTIPS:GetTooltipInfo(GAMEPAD_LEFT_TOOLTIP).bgControl	
							KPUI_GAMEPAD_TOOLTIPS:ClearLines(KPUI_GAMEPAD_TRADING_TOOLTIP)
							KPUI_GAMEPAD_TOOLTIPS:LayoutTradingTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP, "ZO_BankingCommon_Gamepad", itemLink, inventoryData, KPUI_GAMEPAD_TRADING_TOOLTIP, parentControl, false, 5, nil, itemUniqueId)			
						end
					else
						KPUI_GAMEPAD_TOOLTIPS:HideTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP)
					end
				end
			end)		
			SecurePostHook(ZO_BankingCommon_Gamepad, "OnCategoryChanged", function(control, selectedData, ...)
				if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_BANK) then
					control:LayoutBankingEntryTooltip(selectedData)
				end
			end)
			hookBankingAlready = true
		end
	end)
	
	-- set up banking when the guild bank opens
	SecurePostHook(ZO_BankingCommon_Gamepad, "OnStateChanged", function(control, oldState, newState, ...)
		if not hookBankingAlready then
			if newState == SCENE_SHOWING then
				SecurePostHook(ZO_BankingCommon_Gamepad, "LayoutBankingEntryTooltip", function(control, inventoryData, ...)
					if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_BANK) then
						if inventoryData and inventoryData.bagId then
							local itemLink = GetItemLink(inventoryData.bagId, inventoryData.slotIndex)
							local itemUniqueId = GetItemUniqueId(inventoryData.bagId, inventoryData.slotIndex)
							if itemLink then
								local parentControl = GAMEPAD_TOOLTIPS:GetTooltipInfo(GAMEPAD_LEFT_TOOLTIP).bgControl	
								KPUI_GAMEPAD_TOOLTIPS:ClearLines(KPUI_GAMEPAD_TRADING_TOOLTIP)
								KPUI_GAMEPAD_TOOLTIPS:LayoutTradingTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP, "ZO_BankingCommon_Gamepad", itemLink, inventoryData, KPUI_GAMEPAD_TRADING_TOOLTIP, parentControl, false, 5, nil, itemUniqueId)		
							end
						else
							KPUI_GAMEPAD_TOOLTIPS:HideTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP)
						end
					end
				end)		
				SecurePostHook(ZO_BankingCommon_Gamepad, "OnCategoryChanged", function(control, selectedData, ...)
					if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_BANK) then
						KPUI_GAMEPAD_TOOLTIPS:HideTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP)
					end	
				end)
				SecurePostHook(ZO_GuildBank_Gamepad, "ChangeGuildBank", function(control, guildBankId, ...)
					if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_BANK) then
						KPUI_GAMEPAD_TOOLTIPS:HideTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP)
					end
				end)
				hookBankingAlready = true
			end
		end		
	end)

	-- set up stores
	SecurePostHook(ZO_GamepadStoreManager, "OnStateChanged", function(control, oldState, newState, ...)
		if not hookStoregAlready then
			if newState == SCENE_SHOWING then
				SecurePostHook(ZO_GamepadStoreBuy, "OnSelectedItemChanged", function(control, buyData, ...)
					if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_STORE) then
						if buyData then
							local itemLink = buyData.itemLink
							if itemLink then
								local parentControl = GAMEPAD_TOOLTIPS:GetTooltipInfo(GAMEPAD_LEFT_TOOLTIP).bgControl	
								KPUI_GAMEPAD_TOOLTIPS:ClearLines(KPUI_GAMEPAD_TRADING_TOOLTIP)
								KPUI_GAMEPAD_TOOLTIPS:LayoutTradingTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP, "ZO_GamepadStoreBuy", itemLink, buyData, KPUI_GAMEPAD_TRADING_TOOLTIP, parentControl, false, 5)		
							end
						end					
					end
				end)
				SecurePostHook(ZO_GamepadStoreSell, "OnSelectedItemChanged", function(control, inventoryData, ...)
					if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_STORE) then
						if inventoryData and inventoryData.bagId then
							local itemLink = GetItemLink(inventoryData.bagId, inventoryData.slotIndex)
							local itemUniqueId = GetItemUniqueId(inventoryData.bagId, inventoryData.slotIndex)
							if itemLink then
								local parentControl = GAMEPAD_TOOLTIPS:GetTooltipInfo(GAMEPAD_LEFT_TOOLTIP).bgControl	
								KPUI_GAMEPAD_TOOLTIPS:ClearLines(KPUI_GAMEPAD_TRADING_TOOLTIP)
								KPUI_GAMEPAD_TOOLTIPS:LayoutTradingTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP, "ZO_GamepadStoreSell", itemLink, inventoryData, KPUI_GAMEPAD_TRADING_TOOLTIP, parentControl, false, 5, nil, itemUniqueId)		
							end
						else
							KPUI_GAMEPAD_TOOLTIPS:HideTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP)
						end	
					end
				end)
				SecurePostHook(ZO_GamepadStoreBuyback, "OnSelectedItemChanged", function(control, buyBackData, ...)
					if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_STORE) then
						if buyBackData then
							local itemLink = GetBuybackItemLink(buyBackData.slotIndex)						
							if itemLink then
								local parentControl = GAMEPAD_TOOLTIPS:GetTooltipInfo(GAMEPAD_LEFT_TOOLTIP).bgControl	
								KPUI_GAMEPAD_TOOLTIPS:ClearLines(KPUI_GAMEPAD_TRADING_TOOLTIP)
								KPUI_GAMEPAD_TOOLTIPS:LayoutTradingTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP, "ZO_GamepadStoreBuyback", itemLink, buyBackData, KPUI_GAMEPAD_TRADING_TOOLTIP, parentControl, false, 5)		
							end
						else
							KPUI_GAMEPAD_TOOLTIPS:HideTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP)	
						end
					end
				end)
				SecurePostHook(ZO_GamepadStoreManager, "HideActiveComponent", function(control, ...)
					if IsKPUITradingHouseSettingEnabled(KELA_SETTING_PANEL_TRADE_TOOLTIP_STORE) then
						KPUI_GAMEPAD_TOOLTIPS:HideTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP)	
					end
				end)
				hookStoregAlready = true
			end
		end		
	end)

	-- set up the ATT graph
	if ArkadiusTradeTools ~= nil and ArkadiusTradeToolsSalesGraph and not hookATTAlready then
		ZO_PreHook(ArkadiusTradeToolsSalesGraph, "AddDot", function(control, x, y, color)

				local drawAreaWidth, drawAreaHeight = control.drawArea:GetDimensions()
				local rangeX = control.maxX - control.minX

				local posX = x - control.minX
				local rangeY = control.maxY - control.minY
				local posY = control.maxY - y

				local left = drawAreaWidth / rangeX * posX
				local right = -(drawAreaWidth - left - 2)
				local top = drawAreaHeight / rangeY * posY
				local bottom = -(drawAreaHeight - top - 2)

				-- Serves as the index for our current surface
				control.numDots = control.numDots + 1

				if (control.numDots > control.numSurfaces) then
					control.drawArea:AddSurface(0.25, 0.75, 0.25, 0.75)
					control.numSurfaces = control.numSurfaces + 1
				else
					control.drawArea:SetSurfaceHidden(control.numDots, false)
				end

				control.drawArea:SetColor(control.numDots, color:UnpackRGBA())
				
				control.drawArea:SetPixelRoundingEnabled(false)
				if x == GetTimeStamp() then
					if color == colors.COLOR_TTC then -- then
						left = left - 8
						right = right + 2
						top = top - 1
						bottom = bottom	+ 2
						control.drawArea:SetPixelRoundingEnabled(true)
					elseif color == colors.COLOR_ATT then -- tradeSuggested == "ATT" then
						left = left - 2
						right = right + 8
						top = top - 1
						bottom = bottom	+ 2
						control.drawArea:SetPixelRoundingEnabled(true)
					end
				end
				control.drawArea:SetInsets(control.numDots, left - 2, right + 2, top - 2, bottom + 2)
				
				return true
		
		end)
		
	end

	if ArkadiusTradeTools then
		-- The ATT analysis-period selector extends the core guild dialog.
		-- Without ATT, leave the core TRADING_HOUSE_CHANGE_ACTIVE_GUILD untouched.
		local function SetupTradingHouseGuildItem(control, data, ...)
		ZO_SharedGamepadEntry_OnSetup(control, data, ...)
		if data.isCurrentGuild then
			control.statusIndicator:AddIcon("EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_equipped.dds")
			control.statusIndicator:Show()
		end
	end
	local function GetGuildSelectionNarrationText(entryData, entryControl)
		return ZO_FormatRadioButtonNarrationText(entryData.text, entryData.isCurrentGuild)
	end
	local function SetupGuildSelectionDialog(dialog)
		local currentGuildId = GetSelectedTradingHouseGuildId()
		dialog.info.parametricList = {}
		local indexToSelect = nil
		for i = 1, GetNumGuilds() do
			local guildId = GetGuildId(i)
			local guildName = GetGuildName(guildId)
			local allianceId = GetGuildAlliance(guildId)
			local icon = ZO_GetLargeAllianceSymbolIcon(allianceId)
			local listItem = 
			{
				template = "ZO_GamepadSubMenuEntryWithStatusTemplate",
				templateData = 
				{
					 guildId = guildId,
					 guildName = guildName,
					 allianceId = allianceId,
					 fontScaleOnSelection = false,
					 setup = SetupTradingHouseGuildItem,
					 isCurrentGuild = guildId == currentGuildId,
					 narrationText = GetGuildSelectionNarrationText,
				},
				icon = icon,
				text = guildName,
			}
			table.insert(dialog.info.parametricList, listItem)
			if guildId == currentGuildId then
				indexToSelect = i
			end
		end
		if IsKPUITradingHouseSettingEnabled() then
			dialog.info.blockDialogReleaseOnPress = true
			-- ATT analysis period
			local function setupRow (control, data, selected, reselectingDuringRebuild, enabled, active)
				ZO_SharedGamepadEntry_OnSetup(control, data, selected, reselectingDuringRebuild, enabled, active)
				local label = control.label
				label:SetFont("ZoFontGamepad34")

				if not KPUI_SelectorContainer then KPUI_SelectorContainer = CreateControlFromVirtual("$(parent)KPUI_SelectorContainer", dialog, "KPUI_SelectorContainer") end
				KelaPadUI.selectorContainer = KPUI_SelectorContainer
				KelaPadUI.selectorContainer:ClearAnchors()
				KelaPadUI.selectorContainer:SetAnchor(TOPLEFT, control, TOPRIGHT, 0, 0)
				KelaPadUI.selectorContainer:SetAnchor(BOTTOMLEFT, control, BOTTOMRIGHT, 0, 0)			
				KelaPadUI.selectorContainer:SetHidden(false)			
				KelaPadUI.selector = ZO_CurrencySelector_Gamepad:New(KPUI_SelectorContainer:GetNamedChild("Selector"))
				KelaPadUI.selector:SetClampValues(true)
				KelaPadUI.selector:SetMaxValue(30)
				KelaPadUI.selector.control:SetHidden(false)
				KelaPadUI.selector:SetValue(KelaGetATTAnalysisPeriod())
			end
			local function callbackRow(dialog)
				KelaPadUI.selector:SetValue(KelaGetATTAnalysisPeriod())
				KelaPadUI.selectorContainer:SetHidden(false)
				KelaPadUI.selector.control:SetHidden(false)
				local targetControl = dialog.entryList:GetTargetControl()
				KelaPadUI.selector:Activate()
				KelaPadUI.selectorActive = true
			end
			local KelaOptionsPeriod = 
			{
				template = "Kela_GamepadFullWidthLabelEntryTemplate",
				header = GetString(KELA_MAINMENU_TITLE),
				headerTemplate = "Kela_GamepadMenuEntryFullWidthHeaderTemplate",
				templateData =
				{
					text = GetString(KELA_SETTINGS_TRADE_ATTGRAPH_PERIOD),
					setup = setupRow,
					callback = callbackRow,
					visible = function()
							return SCENE_MANAGER:GetCurrentScene():GetName() == "gamepad_trading_house"
						end,
				},
			}
			table.insert(dialog.info.parametricList, KelaOptionsPeriod)
		end
		dialog:setupFunc()
		if indexToSelect then
			dialog.entryList:SetSelectedIndexWithoutAnimation(indexToSelect)
		end
	end
	function KelaDeactivateSelector()
		KelaPadUI.selector:SetValue(KelaGetATTAnalysisPeriod())
		KelaPadUI.selector:Deactivate()
		KelaPadUI.selectorActive = false
	end
	function KelaUpdateTradingHouseTooltip()
		if TRADING_HOUSE_GAMEPAD.currentListObject:GetTradingHouseMode() == ZO_TRADING_HOUSE_MODE_LISTINGS then 
			GAMEPAD_TRADING_HOUSE_LISTINGS:UpdateItemSelectedTooltip(KELA_TRADINGHOUSE_CURRENT_SELECTEDDATA)
		elseif TRADING_HOUSE_GAMEPAD.currentListObject:GetTradingHouseMode() == ZO_TRADING_HOUSE_MODE_SELL  then					
			GAMEPAD_TRADING_HOUSE_SELL:UpdateItemSelectedTooltip(KELA_TRADINGHOUSE_CURRENT_SELECTEDDATA)
		end	
	end
    local noChoiceCallback = function(dialog)
		KelaDeactivateSelector()
		KelaPadUI.selector.control:SetHidden(true)
	end	
	ESO_Dialogs["TRADING_HOUSE_CHANGE_ACTIVE_GUILD"] =
	{
		gamepadInfo =
		{
			dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
		},
		setup = SetupGuildSelectionDialog,
		blockDialogReleaseOnPress = IsKPUITradingHouseSettingEnabled() and true,
		title =
		{
			text = SI_GAMEPAD_TRADING_HOUSE_GUILD_SELECTION,
		},
		buttons =
		{
			[1] =
			{
				text = SI_GAMEPAD_SELECT_OPTION,
				callback = function(dialog)
					local data = dialog.entryList:GetTargetData()
					if IsKPUITradingHouseSettingEnabled() then
						if data.guildId then
							dialog.info.blockDialogReleaseOnPress = false
							-- Route through the selector manager so the choice is persisted.
							-- Calling SelectTradingHouseGuildId directly changes the active guild
							-- only until the trading-house scene is shown again, which resets it
							-- from the saved guild id.
							ZO_GUILD_SELECTOR_MANAGER:SetSelectedGuildStoreId(data.guildId)
							KelaPadUI.selector.control:SetHidden(true)
							zo_callLater(KelaUpdateTradingHouseTooltip, 150)
						else
							if KelaPadUI.selectorActive then
								local amount = KelaPadUI.selector:GetValue()
								if amount == 0 then amount = 1 end
								KelaSetSetting(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_ATT_PERIOD, amount, true)
								KelaDeactivateSelector()						
							elseif data and data.callback then
								data.callback(dialog)
							end					
						end
					else
						if data.guildId then
							ZO_GUILD_SELECTOR_MANAGER:SetSelectedGuildStoreId(data.guildId)
						end
					end
				end
			},

			[2] =
			{
				text = SI_DIALOG_EXIT,
				callback = function(dialog)
					if IsKPUITradingHouseSettingEnabled() then
						if KelaPadUI.selectorActive then
							KelaDeactivateSelector()
						else
							KelaPadUI.selector.control:SetHidden(true)
							dialog.info.blockDialogReleaseOnPress = false
						end	
						zo_callLater(KelaUpdateTradingHouseTooltip, 150)
					end
				end
			}
		},
        noChoiceCallback = noChoiceCallback,
	}
	end
end
