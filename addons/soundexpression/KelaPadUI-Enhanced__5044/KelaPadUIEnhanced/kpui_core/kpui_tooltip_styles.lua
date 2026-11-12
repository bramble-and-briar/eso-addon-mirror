-- Apply only the properties that differ from the current core style so future
-- ESO defaults are inherited. `removedKeys` preserves deliberate omissions.
local function KelaOverrideTooltipStyle(styleName, overrides, removedKeys)
    local style = ZO_TOOLTIP_STYLES[styleName]
    if not style then
        return
    end

    for key, value in pairs(overrides) do
        style[key] = value
    end

    if removedKeys then
        for _, key in ipairs(removedKeys) do
            style[key] = nil
        end
    end
end

-- redefine styles
function kelaTotalRedefineStyles ()
    --General 

    KelaOverrideTooltipStyle("title", {
        fontSize = KELA_TOOLTIPS_FONT_BIG,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
        fontFace = "$(GAMEPAD_MEDIUM_FONT)",
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
    KelaOverrideTooltipStyle("statValuePairStat", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
    })
    KelaOverrideTooltipStyle("statValuePairValue", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
    })
    KelaOverrideTooltipStyle("championRequirements", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("fullWidth", {
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
    KelaOverrideTooltipStyle("statValueSlider", {
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("statValueSliderStat", {
        fontSize = KELA_TOOLTIPS_FONT_SMALL,
    })
    KelaOverrideTooltipStyle("statValueSliderValue", {
        fontSize = KELA_TOOLTIPS_FONT_SMALL,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("succeeded", {
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("failed", {
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("bodySection", {
        customSpacing = 15,
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    ZO_TOOLTIP_STYLES.bodySection1 = { 
        widthPercent = KELA_TOOLTIPS_CONTENT_WIDTH_PERCENT, 
		width = KELA_TOOLTIPS_CONTENT_WIDTH, 
        fontColorField = kpuiConst.Colors.GENERAL_COLOR_OFF_WHITE, 
		fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,	
        fontFace = "$(GAMEPAD_LIGHT_FONT)", 
    }
    KelaOverrideTooltipStyle("bodyHeader", {
        fontSize = KELA_TOOLTIPS_FONT_SMALL,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
        widthPercent = KELA_TOOLTIPS_CONTENT_WIDTH_PERCENT,
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
    KelaOverrideTooltipStyle("itemTagsSection", {
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
    KelaOverrideTooltipStyle("itemTradeBoPSection", {
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
    KelaOverrideTooltipStyle("itemTradeBoPHeader", {
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
    })
    KelaOverrideTooltipStyle("bodyDescription", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
    })
    KelaOverrideTooltipStyle("enchantIrreplaceable", {
        fontSize = KELA_TOOLTIPS_FONT_SMALL,
    })
    --Character Attribute Tooltip 
    KelaOverrideTooltipStyle("attributeBody", {
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
    })
    KelaOverrideTooltipStyle("equipmentBonusValue", {
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("equipmentBonusLowestPieceHeader", {
        fontSize = KELA_TOOLTIPS_FONT_SMALL,
    })
    --Item Tooltip 
    KelaOverrideTooltipStyle("baseStatsSection", {
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
    KelaOverrideTooltipStyle("valueStatsSection", {
        paddingTop = 15,
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
    KelaOverrideTooltipStyle("conditionOrChargeBarSection", {
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
    KelaOverrideTooltipStyle("conditionOrChargeBar", {
        widthPercent = KELA_TOOLTIPS_CONTENT_WIDTH_PERCENT,
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
    KelaOverrideTooltipStyle("itemImprovementConditionOrChargeBar", {
        widthPercent = KELA_TOOLTIPS_CONTENT_WIDTH_PERCENT,
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
    KelaOverrideTooltipStyle("ridingTrainingChargeBar", {
        widthPercent = KELA_TOOLTIPS_CONTENT_WIDTH_PERCENT,
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
    KelaOverrideTooltipStyle("enchantDiff", {
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
    KelaOverrideTooltipStyle("enchantDiffAdd", {
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("enchantDiffRemove", {
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    ZO_TOOLTIP_STYLES.enchantDiffTextureContainer = { 
        layoutPrimaryDirection = "right", 
        layoutSecondaryDirection = "down", 
        paddingLeft = -35, 
        paddingTop = 3, 
        paddingRight = 3, 
        paddingBottom = -49, 
    }
    ZO_TOOLTIP_STYLES.enchantDiffTexture = { 
        width = 32, 
        height = 32 
    } 
    KelaOverrideTooltipStyle("topSection", {
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
        fontFace = "$(GAMEPAD_MEDIUM_FONT)",
        fontSize = KELA_TOOLTIPS_FONT_SMALL,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("topSubsection", {
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
        fontSize = KELA_TOOLTIPS_FONT_SMALL,
    }, { "height" })
    KelaOverrideTooltipStyle("collectionsTopSection", {
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
        fontSize = KELA_TOOLTIPS_FONT_SMALL,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    }, { "dimensionConstraints" })
    KelaOverrideTooltipStyle("topSubsectionItemDetails", {
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
        customSpacing = -4,
        fontSize = KELA_TOOLTIPS_FONT_SMALL,
        height = 32,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("flavorText", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
    })
    KelaOverrideTooltipStyle("prioritySellText", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
    })
    KelaOverrideTooltipStyle("inactiveBonus", {
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("activeBonus", {
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("degradedStat", {
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("qualityTrash", {
        fontColorField = ITEM_QUALITY_TRASH,
    })
    KelaOverrideTooltipStyle("qualityNormal", {
        fontColorField = ITEM_QUALITY_NORMAL,
    })
    KelaOverrideTooltipStyle("qualityMagic", {
        fontColorField = ITEM_QUALITY_MAGIC,
    })
    KelaOverrideTooltipStyle("qualityArcane", {
        fontColorField = ITEM_QUALITY_ARCANE,
    })
    KelaOverrideTooltipStyle("qualityArtifact", {
        fontColorField = ITEM_QUALITY_ARTIFACT,
    })
    KelaOverrideTooltipStyle("qualityLegendary", {
        fontColorField = ITEM_QUALITY_LEGENDARY,
    })
    KelaOverrideTooltipStyle("bind", {
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("stolen", {
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("bagCountSection", {
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
    })
    KelaOverrideTooltipStyle("itemTagTitle", {
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
    })
    KelaOverrideTooltipStyle("itemTagDescription", {
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
    })

    --Gamepad Stable Tooltip 
    KelaOverrideTooltipStyle("stableGamepadTooltip", {
        widthPercent = KELA_TOOLTIPS_CONTENT_WIDTH_PERCENT,
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
    KelaOverrideTooltipStyle("stableGamepadFlavor", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
    })
    KelaOverrideTooltipStyle("stableGamepadTitle", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("poisonCount", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("equippedPoisonSection", {
        customSpacing = 15,
    })

    --Ability Tooltip 
    KelaOverrideTooltipStyle("abilityStatsSection", {
        childSpacing = 3,
        widthPercent = KELA_TOOLTIPS_CONTENT_WIDTH_PERCENT,
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
    KelaOverrideTooltipStyle("abilityUpgrade", {
        fontSize = KELA_TOOLTIPS_FONT_SMALL,
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
    KelaOverrideTooltipStyle("newEffectTitle", {
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
        fontSize = KELA_TOOLTIPS_FONT_SMALL,
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
    KelaOverrideTooltipStyle("newEffectBody", {
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
    KelaOverrideTooltipStyle("abilityProgressBar", {
        widthPercent = KELA_TOOLTIPS_CONTENT_WIDTH_PERCENT,
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
	-- Traits, Ingredient
    KelaOverrideTooltipStyle("hasIngredient", {
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("doesntHaveIngredient", {
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("traitKnown", {
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("traitUnknown", {
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })


    KelaOverrideTooltipStyle("keepBaseTooltipContent", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
        width = KELA_TOOLTIPS_CONTENT_WIDTH - 120,
    })
    KelaOverrideTooltipStyle("keepUpgradeTooltipContent", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
    KelaOverrideTooltipStyle("gamepadElderScrollTooltipContent", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
	
	
    -- Achievement Tooltip 
    KelaOverrideTooltipStyle("achievementRewardsSection", {
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
        paddingTop = 10,
        childSpacing = 10,
    })
    KelaOverrideTooltipStyle("achievementSummaryCategorySection", {
        paddingBottom = 10,
    })
    KelaOverrideTooltipStyle("achievementCriteriaSection", {
        paddingTop = 10,
        paddingBottom = 7,
        childSpacing = 7,
    })
    KelaOverrideTooltipStyle("achievementCriteriaBar", {
        widthPercent = KELA_TOOLTIPS_CONTENT_WIDTH_PERCENT,
        width = KELA_TOOLTIPS_CONTENT_WIDTH - 20,
    }, { "statusBarTemplateOverrideName" })
    KelaOverrideTooltipStyle("achievementDescriptionComplete", {
        widthPercent = KELA_TOOLTIPS_CONTENT_WIDTH_PERCENT,
        width = KELA_TOOLTIPS_CONTENT_WIDTH - 40,
        fontSize = KELA_TOOLTIPS_FONT_SMALL,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("achievementDescriptionIncomplete", {
        widthPercent = KELA_TOOLTIPS_CONTENT_WIDTH_PERCENT,
        width = KELA_TOOLTIPS_CONTENT_WIDTH - 40,
        fontSize = KELA_TOOLTIPS_FONT_SMALL,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("achievementName", {
        widthPercent = KELA_TOOLTIPS_CONTENT_WIDTH_PERCENT,
        width = KELA_TOOLTIPS_CONTENT_WIDTH - 60,
        fontSize = KELA_TOOLTIPS_FONT_SMALL,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    }, { "fontColorField" })
    KelaOverrideTooltipStyle("achievementComplete", {
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("achievementIncomplete", {
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })


    -- Loot tooltip 
    KelaOverrideTooltipStyle("lootTooltip", {
        width = 100,
    })
    -- Gamepad Social Tooltip 
    KelaOverrideTooltipStyle("socialTitle", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
    })
    KelaOverrideTooltipStyle("socialStatsSection", {
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
    KelaOverrideTooltipStyle("socialStatsValue", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("socialOffline", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    -- Gamepad Collections  
    KelaOverrideTooltipStyle("collectionsInfoSection", {
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })

    KelaOverrideTooltipStyle("collectionsStatsSection", {
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })

    KelaOverrideTooltipStyle("collectionsRestrictionsSection", {
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })

    KelaOverrideTooltipStyle("collectionsStatsValue", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })

    KelaOverrideTooltipStyle("collectionsPersonality", {
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })

    -- Extra companion details in the Collections tooltip. Match the body text
    -- used by the base Collections info section (27px light font, off-white).
    ZO_TOOLTIP_STYLES.companionCollectionsSection = {
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
        childSpacing = 10,
        customSpacing = 25,
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
        fontFace = "$(GAMEPAD_LIGHT_FONT)",
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
        fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_3,
    }

    KelaOverrideTooltipStyle("collectionsEmoteGranted", {
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    -- Gamepad Crown Store Market 
    KelaOverrideTooltipStyle("instantUnlockIneligibilitySection", {
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("instantUnlockIneligibilityLine", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
    })
    -- Gamepad Keep Information 
    KelaOverrideTooltipStyle("keepInfoSection", {
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
    --Gamepad Voice Chat 
    KelaOverrideTooltipStyle("voiceChatBodyHeader", {
        fontSize = KELA_TOOLTIPS_FONT_SMALL,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
    KelaOverrideTooltipStyle("voiceChatPairLabel", {
        fontSize = KELA_TOOLTIPS_FONT_SMALL,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("voiceChatPairText", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("voiceChatGamepadReputation", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("voiceChatGamepadSpeaker", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
    KelaOverrideTooltipStyle("voiceChatGamepadSpeakerTitle", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("voiceChatGamepadSpeakerText", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
    })
    KelaOverrideTooltipStyle("voiceChatGamepadStatValuePair", {
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })

    KelaOverrideTooltipStyle("groupTitleSection", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("groupDescription", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
    })
    KelaOverrideTooltipStyle("groupDescriptionError", {
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("groupRolesTitleSection", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("groupRolesStatValuePairValue", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
	-- Gamepad Champion Screen 
    KelaOverrideTooltipStyle("championTitleSection", {
        width = 390,
        uppercase = true,
    })
    KelaOverrideTooltipStyle("championTitle", {
        width = 390,
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
        fontColorField = kpuiConst.Colors.GENERAL_COLOR_WHITE,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
        fontFace = "$(GAMEPAD_MEDIUM_FONT)",
    })
    KelaOverrideTooltipStyle("dividerLine", {
        width = 390,
    })
	-- Comparison
    KelaOverrideTooltipStyle("itemComparisonStatSection", {
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
    KelaOverrideTooltipStyle("itemComparisonStatValuePair", {
        widthPercent = KELA_TOOLTIPS_CONTENT_WIDTH_PERCENT,
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
    KelaOverrideTooltipStyle("itemComparisonStatValuePairValue", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
    })
    KelaOverrideTooltipStyle("itemComparisonStatValuePairDefaultColor", {
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    -- Dyes 
    KelaOverrideTooltipStyle("dyesSection", {
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
    KelaOverrideTooltipStyle("dyeSwatchStyle", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("dyeSwatchEntrySection", {
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
    KelaOverrideTooltipStyle("dyeStampError", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    -- Housing Tooltips 
    KelaOverrideTooltipStyle("defaultAccessTopSection", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
    })
    KelaOverrideTooltipStyle("defaultAccessTitle", {
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("defaultAccessBody", {
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
    })
    --Gamepad Currency Tooltip 
    KelaOverrideTooltipStyle("currencyStatValuePair", {
        width = KELA_TOOLTIPS_CONTENT_WIDTH,
    })
    KelaOverrideTooltipStyle("currencyStatValuePairStat", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("currencyStatValuePairValue", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("requirementPass", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })
    KelaOverrideTooltipStyle("requirementFail", {
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM,
        fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    })

	-- Kela Styles
	ZO_TOOLTIP_STYLES.kelaTrade = {
		paddingTop = 3,
		paddingBottom = 3,
		customSpacing = 5, 
		childSpacing = 5, 
        widthPercent = KELA_TOOLTIPS_CONTENT_WIDTH_PERCENT, 
		width = KELA_TOOLTIPS_CONTENT_WIDTH,
		fontSize = KELA_TOOLTIPS_FONT_SMALL, 
		fontFace = "$(GAMEPAD_LIGHT_FONT)", 
		fontColorType = INTERFACE_COLOR_TYPE_TEXT_COLORS, 
		fontColorField = INTERFACE_TEXT_COLOR_NORMAL, 
		fontStyle = "soft-shadow-thick",
		uppercase = true, 
	}
	-- kela Quad1 (left collection) styles
 	ZO_TOOLTIP_STYLES.QUAD1title = { 
		fontSize = KELA_TOOLTIPS_FONT_MEDIUM, 
        customSpacing = 5,		
        uppercase = true, 
        fontColorField = kpuiConst.Colors.GENERAL_COLOR_WHITE, 
        widthPercent = 100, 
	}
	ZO_TOOLTIP_STYLES.QUAD1collectionsInfoSection = { 
		customSpacing = 25, 
		childSpacing = 25, 
		widthPercent = 100, 
		fontColorType = INTERFACE_COLOR_TYPE_TEXT_COLORS, 
		fontColorField = INTERFACE_TEXT_COLOR_NORMAL,         
		fontFace = "$(GAMEPAD_LIGHT_FONT)", 
	}
	ZO_TOOLTIP_STYLES.QUAD1collectionsStatsSection = { 
		statValuePairSpacing = 10, 
		childSpacing = 20, 
		customSpacing = 20, 
		widthPercent = 100, 
		fontColorType = INTERFACE_COLOR_TYPE_TEXT_COLORS, 
		fontColorField = INTERFACE_TEXT_COLOR_NORMAL,  
	}
	ZO_TOOLTIP_STYLES.QUAD1collectionsRestrictionsSection = { 
		statValuePairSpacing = 10, 
		childSpacing = 10, 
		customSpacing = 20, 
		widthPercent = 100, 
		fontColorType = INTERFACE_COLOR_TYPE_TEXT_COLORS, 
		fontColorField = INTERFACE_TEXT_COLOR_NORMAL,  
	}
	
	-- Kela Styles InfoTooltip-------------------////////////////////////////////////////////////////////////
	
	ZO_TOOLTIP_STYLES.InfoTooltipDesc = {
		statValuePairSpacing = 20, 
        widthPercent = KELA_TOOLTIPS_CONTENT_WIDTH_PERCENT, 
		width = KELA_TOOLTIPS_CONTENT_WIDTH,
		fontSize = KELA_TOOLTIPS_FONT_MEDIUM, 
		fontFace = "$(GAMEPAD_LIGHT_FONT)", 
		fontColorType = INTERFACE_COLOR_TYPE_TEXT_COLORS, 
		fontColorField = INTERFACE_TEXT_COLOR_NORMAL, 
		fontStyle = "soft-shadow-thick",
		uppercase = false, 
	}
    ZO_TOOLTIP_STYLES.InfoTooltipStatValuePair = { 
        height = 30, 
        widthPercent = KELA_TOOLTIPS_CONTENT_WIDTH_PERCENT, 
		width = KELA_TOOLTIPS_CONTENT_WIDTH,
    } 
    ZO_TOOLTIP_STYLES.InfoTooltipStatValuePairValueLeftAlign = { 
        fontSize = KELA_TOOLTIPS_FONT_MEDIUM, 
		widthPercent = KELA_TOOLTIPS_CONTENT_WIDTH_PERCENT, 
		width = KELA_TOOLTIPS_CONTENT_WIDTH,
        fontFace = "$(GAMEPAD_LIGHT_FONT)", 
        horizontalAlignment = TEXT_ALIGN_LEFT, 
    }
    ZO_TOOLTIP_STYLES.InfoTooltipStatValuePairStat = { 
        fontSize = KELA_TOOLTIPS_FONT_SMALL, 
		fontFace = "$(GAMEPAD_LIGHT_FONT)",
        uppercase = false, 
        fontColorField = kpuiConst.Colors.GENERAL_COLOR_OFF_WHITE, 
		fontColorType = INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP,
    }

end
