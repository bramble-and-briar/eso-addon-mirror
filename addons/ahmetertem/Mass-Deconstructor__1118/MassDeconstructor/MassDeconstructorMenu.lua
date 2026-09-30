-- sentry to make sure HWS is declared before use
if MD == nil then
	MD = {}
end

local colours = {
	["normal"] = "FFFFFF",
	["fine"] = "2DC50E",
	["superior"] = "3A92FF",
	["epic"] = "A02EF7",
	["legendary"] = "EECA2A",
}

local function GetColourisedString(strid,colour)
	return "|c" .. colours[colour] .. GetString(strid) .. "|r"
end
--
-- Register with LibMenu and ESO
--
function MD.MakeMenu()
	-- load the settings->addons menu library
	local menu = LibAddonMenu2
	local set = MD.settings

	-- the panel for the addons menu
	local panel = {
		type = "panel",
		name = "Mass Deconstructor",
		displayName = "Mass Deconstructor",
		author = "Ahmet `Amad` Ertem, @sinnereso",
		version = MD.version,
		registerForRefresh = true
	}

	-- this addons entries in the addon menu
	local options = {
		{
			type = "header",
			name = GetString(SI_MASSDECON_ACCOUNT_SETTINGS),
		},	
        {
            type = "checkbox",
            name = GetString(SI_MASSDECON_ACCOUNT_WIDE),
            tooltip = GetString(SI_MASSDECON_ACCOUNT_WIDE_DESC),
            getFunc = function()
				return MD.settings.useAccountWide
			end,
            setFunc = function(value)
				MD.SetUseAccountWide(value)
			end
        },
	
		{
			type = "header",
			name = GetString(SI_MASSDECON_REFINEMENT_SETTINGS),
		},
		{
			type = "checkbox",
			name = GetString(SI_MASSDECON_REFINE_ENTIRE_STACK),
            tooltip = GetString(SI_MASSDECON_REFINE_STACK_DESC),
			getFunc = function()
				return MD.settings.RefineFullStack
			end,
			setFunc = function(value)
				MD.settings.RefineFullStack = value
			end
		},
		{
			type = "header",
			name = GetString(SI_MASSDECON_DECON_SETTINGS),
		},	
		
		{
			type = "slider",--<<@sinnereso
			name = GetString(SI_MASSDECON_DECON_PROTECTION),
			min = 0,
			max = 20000,
			step = 1000,
			getFunc = function()
				return MD.settings.DeconstructPrice
			end,
			setFunc = function(value)
				MD.settings.DeconstructPrice = value
			end,
			disabled = function()
				return not TamrielTradeCentre
			end
		},
		
		{
			type = "checkbox",--<<@sinnereso
			name = GetString(SI_MASSDECON_DECON_BANKED),
			getFunc = function()
				return MD.settings.DeconstructBanked
			end,
			setFunc = function(value)
				MD.settings.DeconstructBanked = value
			end
		},
		
		{
			type = "checkbox",--<<@sinnereso
			name = GetString(SI_MASSDECON_DECON_BOP_TRADEABLE),
			getFunc = function()
				return MD.settings.DeconstructBopTradeable
			end,
			setFunc = function(value)
				MD.settings.DeconstructBopTradeable = value
			end
		},
		
		{
			type = "checkbox",
			name = GetString(SI_MASSDECON_DECON_TRAITLESS),
			getFunc = function()
				return MD.settings.DeconstructTraitless
			end,
			setFunc = function(value)
				MD.settings.DeconstructTraitless = value
			end
		},
		
		{
			type = "checkbox",
			name = GetString(SI_MASSDECON_DECON_BOUND),
			getFunc = function()
				return MD.settings.DeconstructBound
			end,
			setFunc = function(value)
				MD.settings.DeconstructBound = value
			end
		},
		{
			type = "checkbox",
			name = GetString(SI_MASSDECON_DECON_SET_PIECES),
			getFunc = function()
				return MD.settings.DeconstructSetPiece
			end,
			setFunc = function(value)
				MD.settings.DeconstructSetPiece = value
			end
		},
		{
			type = "checkbox",
			name = GetString(SI_MASSDECON_DECON_RETRAITED),
			getFunc = function()
				return MD.settings.DeconstructRetraited
			end,
			setFunc = function(value)
				MD.settings.DeconstructRetraited = value
			end
		},
		{
			type = "checkbox",
			name = GetString(SI_MASSDECON_DECON_RECONSTRUCTED),
			getFunc = function()
				return MD.settings.DeconstructReconstructed
			end,
			setFunc = function(value)
				MD.settings.DeconstructReconstructed = value
			end
		},
		{
			type = "checkbox",
			name = GetString(SI_MASSDECON_DECON_RESEARCHABLE),
			tooltip = GetString(SI_MASSDECON_DECON_RESEARCH_TIP),
			getFunc = function()
				return MD.settings.DeconstructResearchable
			end,
			setFunc = function(value)
				MD.settings.DeconstructResearchable = value
			end
		},
		{
			type = "checkbox",
			name = GetString(SI_MASSDECON_DECON_CRAFTED),
			getFunc = function()
				return MD.settings.DeconstructCrafted
			end,
			setFunc = function(value)
				MD.settings.DeconstructCrafted = value
			end
		},
		{

			type = "checkbox",
			name = GetString(SI_MASSDECON_CP_SLOTTED_WARN),
			getFunc = function()
				return MD.settings.MeticulousDisassemblyWarning
			end,
			setFunc = function(value)
				MD.settings.MeticulousDisassemblyWarning = value
			end
		},
		{
			type = "checkbox",
			name = GetString(SI_MASSDECON_LIST_ITEMS),
			getFunc = function()
				return MD.settings.Verbose
			end,
			setFunc = function(value)
				MD.settings.Verbose = value
			end
		},
		{
			type = "checkbox",
			name = GetString(SI_MASSDECON_DEBUG),
			getFunc = function()
				return MD.settings.Debug
			end,
			setFunc = function(value)
				MD.settings.Debug = value
			end
		},

		{
			type = "header",
			name = GetString(SI_MASSDECON_LEGACY_HEADER)
		},
		{
			type = "description",
			text = GetString(SI_MASSDECON_LEGACY_DESC)
		},
		{
			type = "checkbox",
			name = GetString(SI_MASSDECON_USE_LEGACY),
			getFunc = function()
				return MD.settings.LegacyDeconstructAll
			end,
			setFunc = function(value)
				MD.settings.LegacyDeconstructAll = value
			end
		},
		{
			type = "checkbox",
			name = GetString(SI_MASSDECON_USE_LEGACY_INTRICATE),
			disabled = function() return not MD.settings.LegacyDeconstructAll end,
			getFunc = function()
				return MD.settings.LegacyDeconstructIntricate
			end,
			setFunc = function(value)
				MD.settings.LegacyDeconstructIntricate = value
			end
		},
		
		{
			type = "checkbox",
			name = GetString(SI_MASSDECON_USE_LEGACY_ORNATE),
			disabled = function() return not MD.settings.LegacyDeconstructAll end,
			getFunc = function()
				return MD.settings.LegacyDeconstructOrnate
			end,
			setFunc = function(value)
				MD.settings.LegacyDeconstructOrnate = value
			end
		},
		
		{
			type = "checkbox",
			name = GetString(SI_MASSDECON_USE_LEGACY_NIRN),
			disabled = function() return not MD.settings.LegacyDeconstructAll end,
			getFunc = function()
				return MD.settings.LegacyDeconstructNirn
			end,
			setFunc = function(value)
				MD.settings.LegacyDeconstructNirn = value
			end
		},


		{
			type = "header",
			name = GetString(SI_MASSDECON_DECON_HEADER)
		},
		{
			type = "submenu",
			name = GetString(SI_MASSDECON_ENCHANTMENT_OPTIONS),
			controls = {
				{
					type = "checkbox",
					name = GetString(SI_MASSDECON_ALLOW_DECON),
					getFunc = function()
						return MD.settings.deconTraits[CRAFTING_TYPE_ENCHANTING].Deconstruct
					end,
					setFunc = function(value)
						MD.settings.deconTraits[CRAFTING_TYPE_ENCHANTING].Deconstruct = value
					end
				},
				{
					type = "dropdown",
					name = GetString(SI_MASSDECON_MAX_QUALITY),
					tooltip = GetString(SI_MASSDECON_QUALITY_DESC),
					choices = {
						GetColourisedString(SI_ITEMQUALITY1,"normal"),
						GetColourisedString(SI_ITEMQUALITY2,"fine"),
						GetColourisedString(SI_ITEMQUALITY3,"superior"),
						GetColourisedString(SI_ITEMQUALITY4,"epic"),
						GetColourisedString(SI_ITEMQUALITY5,"legendary")
					},
					choicesValues = {1, 2, 3, 4, 5},
					getFunc = function()
						return MD.settings.quality[CRAFTING_TYPE_ENCHANTING]
					end,
					setFunc = function(maxQuality)
						MD.settings.quality[CRAFTING_TYPE_ENCHANTING] = maxQuality
					end
				}
			}
		},
		{
			type = "submenu",
			name = GetString(SI_MASSDECON_CLOTHING_OPTIONS),
			controls = {
				{
					type = "checkbox",
					name = GetString(SI_MASSDECON_ALLOW_DECON),
					getFunc = function()
						return MD.settings.deconTraits[CRAFTING_TYPE_CLOTHIER].Deconstruct
					end,
					setFunc = function(value)
						MD.settings.deconTraits[CRAFTING_TYPE_CLOTHIER].Deconstruct = value
					end
				},
				{
					type = "dropdown",
					name = GetString(SI_MASSDECON_MAX_QUALITY),
					tooltip = GetString(SI_MASSDECON_QUALITY_DESC),
					choices = {
						GetColourisedString(SI_ITEMQUALITY1,"normal"),
						GetColourisedString(SI_ITEMQUALITY2,"fine"),
						GetColourisedString(SI_ITEMQUALITY3,"superior"),
						GetColourisedString(SI_ITEMQUALITY4,"epic"),
						GetColourisedString(SI_ITEMQUALITY5,"legendary")
					},
					choicesValues = {1, 2, 3, 4, 5},
					getFunc = function()
						return MD.settings.quality[CRAFTING_TYPE_CLOTHIER]
					end,
					setFunc = function(maxQuality)
						MD.settings.quality[CRAFTING_TYPE_CLOTHIER] = maxQuality
					end
				},
				-- Mixed traits / global / don't care
				{
					type = "checkbox",
					name = GetString(SI_ITEMTRAITTYPE20),
					disabled = function() return MD.settings.LegacyDeconstructAll end,
					getFunc = function()
						return MD.settings.deconTraits[CRAFTING_TYPE_CLOTHIER][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_INTRICATE]
					end,
					setFunc = function(value)
						MD.settings.deconTraits[CRAFTING_TYPE_CLOTHIER][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_INTRICATE] = value
					end
				},
				{
					type = "checkbox",
					name = GetString(SI_ITEMTRAITTYPE19),
					disabled = function() return MD.settings.LegacyDeconstructAll end,
					getFunc = function()
						return MD.settings.deconTraits[CRAFTING_TYPE_CLOTHIER][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_ORNATE]
					end,
					setFunc = function(value)
						MD.settings.deconTraits[CRAFTING_TYPE_CLOTHIER][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_ORNATE] = value
					end
				},
				{
					type = "button",
					name = GetString(SI_MASSDECON_TOGGLE_ALL_TRAITS),
					disabled = function() return MD.settings.LegacyDeconstructAll end,
					width = "full",
					tooltip = GetString(SI_MASSDECON_TOGGLE_ALL_TRAITS_TIP),
					func = function() MD.toggleTraits(CRAFTING_TYPE_CLOTHIER) end,
				},				

				-- all this just for the shield, should find a better way to do this
				-- Armour traits
				{
					type = "submenu",
					name = GetString(SI_MASSDECON_ARMOUR_TRAITS),
					disabled = function() return MD.settings.LegacyDeconstructAll end,
					controls = {
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE11),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_CLOTHIER][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_STURDY]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_CLOTHIER][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_STURDY] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE12),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_CLOTHIER][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_IMPENETRABLE]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_CLOTHIER][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_IMPENETRABLE] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE13),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_CLOTHIER][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_REINFORCED]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_CLOTHIER][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_REINFORCED] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE14),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_CLOTHIER][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_WELL_FITTED]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_CLOTHIER][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_WELL_FITTED] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE15),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_CLOTHIER][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_TRAINING]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_CLOTHIER][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_TRAINING] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE16),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_CLOTHIER][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_INFUSED]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_CLOTHIER][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_INFUSED] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE17),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_CLOTHIER][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_PROSPEROUS]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_CLOTHIER][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_PROSPEROUS] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE18),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_CLOTHIER][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_DIVINES]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_CLOTHIER][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_DIVINES] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE25),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_CLOTHIER][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_NIRNHONED]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_CLOTHIER][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_NIRNHONED] = value
							end
						}
					}
				}
			}
		},
		{
			type = "submenu",
			name = GetString(SI_MASSDECON_BLACKSMITH_OPTIONS),
			controls = {
				{
					type = "checkbox",
					name = GetString(SI_MASSDECON_ALLOW_DECON),
					getFunc = function()
						return MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING].Deconstruct
					end,
					setFunc = function(value)
						MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING].Deconstruct = value
					end
				},
				{
					type = "dropdown",
					name = GetString(SI_MASSDECON_MAX_QUALITY),
					tooltip = GetString(SI_MASSDECON_QUALITY_DESC),
					choices = {
						GetColourisedString(SI_ITEMQUALITY1,"normal"),
						GetColourisedString(SI_ITEMQUALITY2,"fine"),
						GetColourisedString(SI_ITEMQUALITY3,"superior"),
						GetColourisedString(SI_ITEMQUALITY4,"epic"),
						GetColourisedString(SI_ITEMQUALITY5,"legendary")
					},
					choicesValues = {1, 2, 3, 4, 5},
					getFunc = function()
						return MD.settings.quality[CRAFTING_TYPE_BLACKSMITHING]
					end,
					setFunc = function(maxQuality)
						MD.settings.quality[CRAFTING_TYPE_BLACKSMITHING] = maxQuality
					end
				},
				-- Mixed traits / global / don't care
				{
					type = "checkbox",
					name = GetString(SI_ITEMTRAITTYPE20),
					disabled = function() return MD.settings.LegacyDeconstructAll end,
					getFunc = function()
						return MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_INTRICATE]
					end,
					setFunc = function(value)
						MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_INTRICATE] = value
						MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_INTRICATE] = value
					end
				},
				{
					type = "checkbox",
					name = GetString(SI_ITEMTRAITTYPE19),
					disabled = function() return MD.settings.LegacyDeconstructAll end,
					getFunc = function()
						return MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_ORNATE]
					end,
					setFunc = function(value)
						MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_ORNATE] = value
						MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_ORNATE] = value
					end
				},
				{
					type = "button",
					name = GetString(SI_MASSDECON_TOGGLE_ALL_TRAITS),
					disabled = function() return MD.settings.LegacyDeconstructAll end,					
					width = "full",
					tooltip = GetString(SI_MASSDECON_TOGGLE_ALL_TRAITS_TIP),
					func = function() MD.toggleTraits(CRAFTING_TYPE_BLACKSMITHING) end,
				},				

				-- all this just for the shield, should find a better way to do this
				-- Armour traits
				{
					type = "submenu",
					name = GetString(SI_MASSDECON_ARMOUR_TRAITS),
					disabled = function() return MD.settings.LegacyDeconstructAll end,
					controls = {
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE11),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_STURDY]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_STURDY] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE12),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_IMPENETRABLE]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_IMPENETRABLE] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE13),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_REINFORCED]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_REINFORCED] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE14),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_WELL_FITTED]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_WELL_FITTED] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE15),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_TRAINING]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_TRAINING] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE16),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_INFUSED]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_INFUSED] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE17),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_PROSPEROUS]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_PROSPEROUS] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE18),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_DIVINES]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_DIVINES] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE25),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_NIRNHONED]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_NIRNHONED] = value
							end
						}
					}
				},
				-- Weapon traits
				{
					type = "submenu",
					name = GetString(SI_MASSDECON_WEAPON_TRAITS),
					disabled = function() return MD.settings.LegacyDeconstructAll end,
					controls = {
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE1),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_POWERED]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_POWERED] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE2),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_CHARGED]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_CHARGED] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE3),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_PRECISE]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_PRECISE] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE4),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_INFUSED]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_INFUSED] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE5),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_DEFENDING]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_DEFENDING] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE6),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_TRAINING]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_TRAINING] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE7),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_SHARPENED]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_SHARPENED] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE8),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_DECISIVE]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_DECISIVE] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE26),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_NIRNHONED]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_BLACKSMITHING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_NIRNHONED] = value
							end
						}
					}
				}
			}
		},
		{
			type = "submenu",
			name = GetString(SI_MASSDECON_WOODWORK_OPTIONS),
			controls = {
				{
					type = "checkbox",
					name = GetString(SI_MASSDECON_ALLOW_DECON),
					getFunc = function()
						return MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING].Deconstruct
					end,
					setFunc = function(value)
						MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING].Deconstruct = value
					end
				},
				{
					type = "dropdown",
					name = GetString(SI_MASSDECON_MAX_QUALITY),
					tooltip = GetString(SI_MASSDECON_QUALITY_DESC),
					choices = {
						GetColourisedString(SI_ITEMQUALITY1,"normal"),
						GetColourisedString(SI_ITEMQUALITY2,"fine"),
						GetColourisedString(SI_ITEMQUALITY3,"superior"),
						GetColourisedString(SI_ITEMQUALITY4,"epic"),
						GetColourisedString(SI_ITEMQUALITY5,"legendary")
					},
					choicesValues = {1, 2, 3, 4, 5},
					getFunc = function()
						return MD.settings.quality[CRAFTING_TYPE_WOODWORKING]
					end,
					setFunc = function(maxQuality)
						MD.settings.quality[CRAFTING_TYPE_WOODWORKING] = maxQuality
					end
				},
				-- Mixed traits / global / don't care
				{
					type = "checkbox",
					name = GetString(SI_ITEMTRAITTYPE20),
					disabled = function() return MD.settings.LegacyDeconstructAll end,
					getFunc = function()
						return MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_INTRICATE]
					end,
					setFunc = function(value)
						MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_INTRICATE] = value
						MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_INTRICATE] = value
					end
				},
				{
					type = "checkbox",
					name = GetString(SI_ITEMTRAITTYPE19),
					disabled = function() return MD.settings.LegacyDeconstructAll end,
					getFunc = function()
						return MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_ORNATE]
					end,
					setFunc = function(value)
						MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_ORNATE] = value
						MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_ORNATE] = value
					end
				},
				{
					type = "button",
					name = GetString(SI_MASSDECON_TOGGLE_ALL_TRAITS),
					disabled = function() return MD.settings.LegacyDeconstructAll end,
					width = "full",
					tooltip = GetString(SI_MASSDECON_TOGGLE_ALL_TRAITS_TIP),
					func = function() MD.toggleTraits(CRAFTING_TYPE_WOODWORKING) end,
				},

				-- all this just for the shield, should find a better way to do this
				-- Armour traits
				{
					type = "submenu",
					name = GetString(SI_MASSDECON_ARMOUR_TRAITS),
					disabled = function() return MD.settings.LegacyDeconstructAll end,
					controls = {
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE11),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_STURDY]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_STURDY] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE12),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_IMPENETRABLE]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_IMPENETRABLE] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE13),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_REINFORCED]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_REINFORCED] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE14),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_WELL_FITTED]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_WELL_FITTED] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE15),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_TRAINING]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_TRAINING] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE16),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_INFUSED]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_INFUSED] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE17),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_PROSPEROUS]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_PROSPEROUS] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE18),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_DIVINES]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_DIVINES] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE25),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_NIRNHONED]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_ARMOR][ITEM_TRAIT_TYPE_ARMOR_NIRNHONED] = value
							end
						}
					}
				},
				-- Weapon traits
				{
					type = "submenu",
					name = GetString(SI_MASSDECON_WEAPON_TRAITS),
					disabled = function() return MD.settings.LegacyDeconstructAll end,
					controls = {
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE1),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_POWERED]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_POWERED] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE2),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_CHARGED]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_CHARGED] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE3),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_PRECISE]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_PRECISE] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE4),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_INFUSED]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_INFUSED] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE5),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_DEFENDING]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_DEFENDING] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE6),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_TRAINING]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_TRAINING] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE7),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_SHARPENED]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_SHARPENED] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE8),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_DECISIVE]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_DECISIVE] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE26),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_NIRNHONED]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_WOODWORKING][ITEM_TRAIT_TYPE_CATEGORY_WEAPON][ITEM_TRAIT_TYPE_WEAPON_NIRNHONED] = value
							end
						}
					}
				}
			}
		},
		{
			type = "submenu",
			name = GetString(SI_MASSDECON_JEWELLERY_OPTIONS),
			disabledLabel = function() return not MD.GetCanDeconJewellery() end,
			disabled = function() return not MD.GetCanDeconJewellery() end,		
			controls = {
				{
					type = "checkbox",
					name = GetString(SI_MASSDECON_ALLOW_DECON),
					getFunc = function()
						return MD.settings.deconTraits[CRAFTING_TYPE_JEWELRYCRAFTING].Deconstruct
					end,
					setFunc = function(value)
						MD.settings.deconTraits[CRAFTING_TYPE_JEWELRYCRAFTING].Deconstruct = value
					end
				},
				{
					type = "dropdown",
					name = GetString(SI_MASSDECON_MAX_QUALITY),
					tooltip = GetString(SI_MASSDECON_QUALITY_DESC),
					choices = {
						GetColourisedString(SI_ITEMQUALITY1,"normal"),
						GetColourisedString(SI_ITEMQUALITY2,"fine"),
						GetColourisedString(SI_ITEMQUALITY3,"superior"),
						GetColourisedString(SI_ITEMQUALITY4,"epic"),
						GetColourisedString(SI_ITEMQUALITY5,"legendary")
					},
					choicesValues = {1, 2, 3, 4, 5},
					getFunc = function()
						return MD.settings.quality[CRAFTING_TYPE_JEWELRYCRAFTING]
					end,
					setFunc = function(maxQuality)
						MD.settings.quality[CRAFTING_TYPE_JEWELRYCRAFTING] = maxQuality
					end
				},
				{
					type = "checkbox",
					name = GetString(SI_ITEMTRAITTYPE27),
					disabled = function() return MD.settings.LegacyDeconstructAll end,
					getFunc = function()
						return MD.settings.deconTraits[CRAFTING_TYPE_JEWELRYCRAFTING][ITEM_TRAIT_TYPE_CATEGORY_JEWELRY][ITEM_TRAIT_TYPE_JEWELRY_INTRICATE]
					end,
					setFunc = function(value)
						MD.settings.deconTraits[CRAFTING_TYPE_JEWELRYCRAFTING][ITEM_TRAIT_TYPE_CATEGORY_JEWELRY][ITEM_TRAIT_TYPE_JEWELRY_INTRICATE] = value
					end
				},
				{
					type = "checkbox",
					name = GetString(SI_ITEMTRAITTYPE24),
					disabled = function() return MD.settings.LegacyDeconstructAll end,
					getFunc = function()
						return MD.settings.deconTraits[CRAFTING_TYPE_JEWELRYCRAFTING][ITEM_TRAIT_TYPE_CATEGORY_JEWELRY][ITEM_TRAIT_TYPE_JEWELRY_ORNATE]
					end,
					setFunc = function(value)
						MD.settings.deconTraits[CRAFTING_TYPE_JEWELRYCRAFTING][ITEM_TRAIT_TYPE_CATEGORY_JEWELRY][ITEM_TRAIT_TYPE_JEWELRY_ORNATE] = value
					end
				},
				{
					type = "button",
					name = GetString(SI_MASSDECON_TOGGLE_ALL_TRAITS),
					disabled = function() return MD.settings.LegacyDeconstructAll end,
					width = "full",
					tooltip = GetString(SI_MASSDECON_TOGGLE_ALL_TRAITS_TIP),
					func = function() MD.toggleTraits(CRAFTING_TYPE_JEWELRYCRAFTING) end,
				},				
				{
					type = "submenu",
					name = GetString(SI_MASSDECON_JEWELLERY_TRAITS),
					disabled = function() return MD.settings.LegacyDeconstructAll end,
					controls = {
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE21),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_JEWELRYCRAFTING][ITEM_TRAIT_TYPE_CATEGORY_JEWELRY][ITEM_TRAIT_TYPE_JEWELRY_HEALTHY]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_JEWELRYCRAFTING][ITEM_TRAIT_TYPE_CATEGORY_JEWELRY][ITEM_TRAIT_TYPE_JEWELRY_HEALTHY] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE22),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_JEWELRYCRAFTING][ITEM_TRAIT_TYPE_CATEGORY_JEWELRY][ITEM_TRAIT_TYPE_JEWELRY_ARCANE]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_JEWELRYCRAFTING][ITEM_TRAIT_TYPE_CATEGORY_JEWELRY][ITEM_TRAIT_TYPE_JEWELRY_ARCANE] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE23),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_JEWELRYCRAFTING][ITEM_TRAIT_TYPE_CATEGORY_JEWELRY][ITEM_TRAIT_TYPE_JEWELRY_ROBUST]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_JEWELRYCRAFTING][ITEM_TRAIT_TYPE_CATEGORY_JEWELRY][ITEM_TRAIT_TYPE_JEWELRY_ROBUST] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE28),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_JEWELRYCRAFTING][ITEM_TRAIT_TYPE_CATEGORY_JEWELRY][ITEM_TRAIT_TYPE_JEWELRY_SWIFT]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_JEWELRYCRAFTING][ITEM_TRAIT_TYPE_CATEGORY_JEWELRY][ITEM_TRAIT_TYPE_JEWELRY_SWIFT] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE29),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_JEWELRYCRAFTING][ITEM_TRAIT_TYPE_CATEGORY_JEWELRY][ITEM_TRAIT_TYPE_JEWELRY_HARMONY]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_JEWELRYCRAFTING][ITEM_TRAIT_TYPE_CATEGORY_JEWELRY][ITEM_TRAIT_TYPE_JEWELRY_HARMONY] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE30),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_JEWELRYCRAFTING][ITEM_TRAIT_TYPE_CATEGORY_JEWELRY][ITEM_TRAIT_TYPE_JEWELRY_TRIUNE]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_JEWELRYCRAFTING][ITEM_TRAIT_TYPE_CATEGORY_JEWELRY][ITEM_TRAIT_TYPE_JEWELRY_TRIUNE] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE31),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_JEWELRYCRAFTING][ITEM_TRAIT_TYPE_CATEGORY_JEWELRY][ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_JEWELRYCRAFTING][ITEM_TRAIT_TYPE_CATEGORY_JEWELRY][ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE32),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_JEWELRYCRAFTING][ITEM_TRAIT_TYPE_CATEGORY_JEWELRY][ITEM_TRAIT_TYPE_JEWELRY_PROTECTIVE]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_JEWELRYCRAFTING][ITEM_TRAIT_TYPE_CATEGORY_JEWELRY][ITEM_TRAIT_TYPE_JEWELRY_PROTECTIVE] = value
							end
						},
						{
							type = "checkbox",
							name = GetString(SI_ITEMTRAITTYPE33),
							getFunc = function()
								return MD.settings.deconTraits[CRAFTING_TYPE_JEWELRYCRAFTING][ITEM_TRAIT_TYPE_CATEGORY_JEWELRY][ITEM_TRAIT_TYPE_JEWELRY_INFUSED]
							end,
							setFunc = function(value)
								MD.settings.deconTraits[CRAFTING_TYPE_JEWELRYCRAFTING][ITEM_TRAIT_TYPE_CATEGORY_JEWELRY][ITEM_TRAIT_TYPE_JEWELRY_INFUSED] = value
							end
						}
					}
				}
			}
		}
	}
	menu:RegisterAddonPanel("MassDeconstructor", panel)
	menu:RegisterOptionControls("MassDeconstructor", options)
end
