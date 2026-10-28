local addon = Unboxer
local LSV  = LibSavedVars
local LAM2 = LibAddonMenu2

-- Local variables
local debug = false
local libLootSummaryWarning, renamedSettings, removedSettings, refreshPrefix, tableMultiInsertSorted, version5, version7, version8, version9

----------------- Settings -----------------------
function addon:SetupSavedVars()
    
    self.defaults = 
    {
        autoloot = true,
        autolootDelay = 2,
        reservedSlots = 0,
        chatColor = { 1, 1, 1, 1 },
        shortPrefix = true,
        chatUseSystemColor = true,
        chatContainerOpen = true,
        chatContainerIcons = true,
        coloredPrefix = false,
		    noAutoLootStolen = false,
        chatContentsSummary = {
            enabled = true,
            minQuality = ITEM_FUNCTIONAL_QUALITY_MIN_VALUE,
            showIcon = true,
            showTrait = true,
            showNotCollected = true,
            hideSingularQuantities = true,
            iconSize = 90,
            delimiter = " ",
            combineDuplicates = true,
            sortedByQuality = true,
            linkStyle = LINK_STYLE_DEFAULT,
            showCounter = true,
        },
    }
    self.trackingDefaults = {
        cooldownProtected = {},
        cooldownEnd = {},
    }
    
    for _, rule in ipairs(self.rules) do
        self.defaults[rule.name] = false
        self.defaults[rule.autolootSettingName] = self.defaults.autoloot
        self.defaults[rule.summarySettingName] = true
    end

    self.tracking = LSV:NewAccountWide(self.name .. "_Tracking", self.trackingDefaults)
    self.settings =
      LSV:NewAccountWide(self.name .. "_Account", self.defaults)
         :AddCharacterSettingsToggle(self.name .. "_Character")
         :RenameSettings(4, renamedSettings)
         :RemoveSettings(4, removedSettings)
         :Version(5, version5)
         :RemoveSettings(6, "containerUniqueItemIds")
         :Version(7, version7)
         :Version(8, version8)
         :Version(9, version9)
    
    if LSV_Data.EnableDefaultsTrimming then
        self.settings:EnableDefaultsTrimming()
    end
    
    self.chat = self.classes.ChatProxy:New()
    self.summary = LibLootSummary({ chat = self.chat })
    
    local counterText = GetString(SI_ITEMTYPE18)
    if GetCVar("Language.2") ~= "de" then
        counterText = zo_strlower(counterText)
    end
    self.summary:SetCounterText(counterText)
    
    self.chatColor = ZO_ColorDef:New(unpack(self.settings.chatColor))
    refreshPrefix()
    self.Debug("SetupSavedVars()", debug)
end

function addon:SetupSettings()
    
    self.Debug("SetupSettings()", debug)
    
    local panelData = {
        type = "panel",
        name = addon.title,
        displayName = addon.title,
        author = addon.author,
        version = addon.version,
        slashCommand = "/unboxer",
        registerForRefresh = true,
        registerForDefaults = true,
    }
  
    self.optionsTable = {
        
        -- Account-wide settings
        self.settings:GetLibAddonMenuAccountCheckbox(),
        
        {
            type     = "submenu",
            name     = GetString(SI_UNBOXER_CHAT_MESSAGES),
            controls = {
          
                -- Use default system color
                {
                    type = "checkbox",
                    name = GetString(SI_UNBOXER_CHAT_USE_SYSTEM_COLOR),
                    getFunc = function() return self.settings.chatUseSystemColor end,
                    setFunc = function(value)
                                  self.settings.chatUseSystemColor = value
                                  refreshPrefix()
                              end,
                    default = self.defaults.chatUseSystemColor,
                },
                -- Message color
                {
                    type = "colorpicker",
                    name = GetString(SI_UNBOXER_CHAT_COLOR),
                    getFunc = function() return unpack(self.settings.chatColor) end,
                    setFunc = function(r, g, b, a)
                                  self.settings.chatColor = { r, g, b, a }
                                  self.chatColor = ZO_ColorDef:New(r, g, b, a)
                                  refreshPrefix()
                              end,
                    default = function()
                                  local r, g, b, a = unpack(self.defaults.chatColor)
                                  return { r=r, g=g, b=b, a=a }
                              end,
                    disabled = function() return self.settings.chatUseSystemColor end,
                },
                -- Prefix header
                {
                    type = "header",
                    name = GetString(SI_UNBOXER_PREFIX_HEADER),
                },
                -- Short prefix
                {
                    type = "checkbox",
                    name = GetString(SI_UNBOXER_SHORT_PREFIX),
                    tooltip = GetString(SI_UNBOXER_SHORT_PREFIX_TOOLTIP),
                    getFunc = function() return self.settings.shortPrefix end,
                    setFunc = function(value)
                                  self.settings.shortPrefix = value
                                  refreshPrefix()
                              end,
                    default = self.defaults.shortPrefix,
                },
                -- Old Prefix Colors
                {
                    type = "checkbox",
                    name = GetString(SI_UNBOXER_COLORED_PREFIX),
                    tooltip = GetString(SI_UNBOXER_COLORED_PREFIX_TOOLTIP),
                    getFunc = function() return self.settings.coloredPrefix end,
                    setFunc = function(value)
                                  self.settings.coloredPrefix = value
                                  refreshPrefix()
                              end,
                    default = self.defaults.coloredPrefix,
                },
                -- Display Messages For:
                {
                    type = "header",
                    name = GetString(SI_UNBOXER_CHAT_MESSAGES_HEADER),
                },
                -- Log container open to chat
                {
                    type = "checkbox",
                    name = GetString(SI_UNBOXER_CHAT_CONTAINERS),
                    tooltip = zo_strformat(SI_UNBOXER_CHAT_CONTAINERS_TOOLTIP, self.name),
                    getFunc = function() return self.settings.chatContainerOpen end,
                    setFunc = function(value) self.settings.chatContainerOpen = value end,
                    default = self.defaults.chatContainerOpen,
                },
                -- Show container icons
                {
                    type = "checkbox",
                    name = GetString(SI_UNBOXER_CHAT_CONTAINERS_ICONS),
                    tooltip = GetString(SI_UNBOXER_CHAT_CONTAINERS_ICONS_TOOLTIP),
                    getFunc = function() return self.settings.chatContainerIcons end,
                    setFunc = function(value) self.settings.chatContainerIcons = value end,
                    width = "full",
                    default = self.defaults.chatContainerIcons,
                    disabled = function() return not self.settings.chatContainerOpen end
                },
                -- divider
                { type = "divider", width = "full" },
                -- Log container contents to chat
                self.summary:GenerateLam2LootOptions(self.title, self.settings, self.defaults, 'chatContentsSummary'),
            },
        },
        
        -- Autoloot
        {
            type    = "checkbox",
            name    = GetString(SI_UNBOXER_AUTOLOOT_GLOBAL),
            tooltip = GetString(SI_UNBOXER_AUTOLOOT_GLOBAL_TOOLTIP),
            getFunc = function() return self.settings.autoloot end,
            setFunc = function(value) self.settings.autoloot = value end,
            default = self.defaults.autoloot,
        },
        -- Autoloot delay
        {
            type    = "slider",
            name    = GetString(SI_UNBOXER_AUTOLOOT_DELAY),
            tooltip = GetString(SI_UNBOXER_AUTOLOOT_DELAY_TOOLTIP),
            min     = 0,
            max     = 20,
            getFunc = function() return self.settings.autolootDelay end,
            setFunc = function(value) self.settings.autolootDelay = value end,
            default = self.defaults.autolootDelay,
            disabled = function() return not addon.settings.autoloot end,
        },
        -- Don't Autoloot stolen
        {
            type    = "checkbox",
            name    = GetString(SI_UNBOXER_NO_AUTOLOOT_STOLEN),
            tooltip = GetString(SI_UNBOXER_NO_AUTOLOOT_STOLEN_TOOLTIP),
            getFunc = function() return self.settings.noAutoLootStolen end,
            setFunc = function(value) self.settings.noAutoLootStolen = value end,
            default = self.defaults.noAutoLootStolen,
			disabled = function() return not addon.settings.autoloot end,
        },
        -- Reserved slots
        {
            type = "slider",
            name = zo_strformat(GetString(SI_UNBOXER_RESERVED_SLOTS), GetString(SI_BINDING_NAME_UNBOX_ALL)),
            tooltip = zo_strformat(GetString(SI_UNBOXER_RESERVED_SLOTS_TOOLTIP), GetString(SI_BINDING_NAME_UNBOX_ALL)),
            getFunc = function() return self.settings.reservedSlots end,
            setFunc = function(value) self.settings.reservedSlots = value end,
            min = 0,
            max = 200,
            step = 1,
            clampInput = true,
            width = "full",
            default = self.defaults.reservedSlots,
        },
		
    }
    
    self.firstSubmenuOptionIndex = #self.optionsTable + 1
    
    LAM2:RegisterAddonPanel(self.name.."Options", panelData)
    
    LAM2:RegisterOptionControls(self.name.."Options", self.optionsTable)
    
    for _, rule in ipairs(self.rules) do
    
        -- The remaining logic pertains to creating LAM options.
        -- Skip if the rule is marked hidden.
        if not rule.hidden then
            
            -- If this is the first rule in its sub-menu, initialize it
            if not self.submenuOptions[rule.submenu] then
                self.submenuOptions[rule.submenu] = {}
                local submenu = { type = "submenu", name = rule.submenu, controls = self.submenuOptions[rule.submenu] }
                tableMultiInsertSorted(self.optionsTable, { submenu }, "name", self.firstSubmenuOptionIndex, #self.optionsTable)
            end
            
            -- Create the new sub-menu option control config
            local ruleSubmenuOption = rule:CreateLAM2Options()
            local compareIndexOffset
            for i, option in ipairs(ruleSubmenuOption) do
                if option.name == rule.title then
                    compareIndexOffset = i
                    break
                end
            end
            
            -- Insert the new sub-menu option config into its sub-menu's "controls" table.
            tableMultiInsertSorted(self.submenuOptions[rule.submenu], ruleSubmenuOption, "name", 1, #self.submenuOptions[rule.submenu], compareIndexOffset)
        end
    end
end

----------------------------------------------------------------------------
--
--       Local methods
-- 
----------------------------------------------------------------------------

function refreshPrefix()
    local self = addon
    local shortTag = self.settings.coloredPrefix and GetString(SI_UNBOXER_COLORED_SHORT) or GetString(SI_UNBOXER_SHORT)
    self.chat:SetShortTag(shortTag)
    local longTag = self.settings.coloredPrefix and GetString(SI_UNBOXER_COLORED) or GetString(SI_UNBOXER_PREFIX)
    self.chat:SetLongTag(longTag)
    self.chat:SetShortTagPrefixEnabled(self.settings.shortPrefix)
    
    if self.settings.chatUseSystemColor or self.settings.coloredPrefix then
        self.chat:SetTagColor(nil)
    else
        self.chat:SetTagColor(self.chatColor)
    end
    
    self.prefix = self.settings.chatUseSystemColor and "" or "|c" .. self.chatColor:ToHex()
    self.suffix = self.settings.chatUseSystemColor and "" or "|r"
    self.summary:SetPrefix(self.prefix)
    self.summary:SetSuffix(self.suffix)
end

function tableMultiInsertSorted(targetTable, newEntry, key, startIndex, endIndex, compareIndexOffset)
    local self = addon
    if not compareIndexOffset then
        compareIndexOffset = 1
    end
    local insertAtIndex
    for optionIndex = startIndex + compareIndexOffset - 1, endIndex do
        local entry = targetTable[optionIndex]
        if ((entry.type == "checkbox" and entry.disabled == nil) 
               or entry.type == "submenu")
           and entry[key] > newEntry[compareIndexOffset][key]
        then
            insertAtIndex = optionIndex - compareIndexOffset + 1
            break
        end
    end
    if not insertAtIndex then
        insertAtIndex = endIndex + 1
    end
    for i = 1, #newEntry do
        local option = newEntry[i]
        self.Debug("Adding "..tostring(option.type)..(option.name and " with name "..tostring(option.name) or "").." at index "..tostring(insertAtIndex + i - 1))
        table.insert(targetTable, insertAtIndex + i - 1, newEntry[i])
    end
end

function version5(sv)
    sv.dragons = sv.solorepeatable
    sv.pvp = sv.solorepeatable
    sv.dragonsAutoloot = sv.solorepeatableAutoloot
    sv.pvpAutoloot = sv.solorepeatableAutoloot
    sv.dragonsSummary = sv.solorepeatableSummary
    sv.pvpSummary = sv.solorepeatableSummary
end

function version7(sv)
    sv.chatContentsSummary = {
        enabled = sv.chatContentsSummary
    }
end

function version8(sv)
    if type(sv.chatContentsSummary) == "table" then
        sv.chatContentsSummary.icons = nil
        sv.chatContentsSummary.traits = nil
    end
    addon.tracking.cooldownProtected = sv.cooldownProtected or {}
    addon.tracking.cooldownEnd = sv.cooldownEnd or {}
    sv.cooldownProtected = nil
    sv.cooldownEnd = nil
    sv.slotUniqueContentItemIds = nil
    sv.chatContentsQuality = nil
    sv.chatContentsHideSingularQuantities = nil
    sv.chatContentsIcons = nil
    sv.chatContentsTraits = nil
end

function version9(sv)
    local oldAutoLootDefault = tonumber(GetSetting(SETTING_TYPE_LOOT,LOOT_SETTING_AUTO_LOOT)) ~= 0
    if sv.autoloot == nil then
        sv.autoloot = oldAutoLootDefault
    end
    for _, rule in ipairs(addon.rules) do
        if sv[rule.autolootSettingName] == nil then
            sv[rule.autolootSettingName] = oldAutoLootDefault
        end
    end
end

renamedSettings = {
    ["giftBoxes"]                  = "festival",
    ["gunnySacks"]                 = "fishing",
    ["runeBoxes"]                  = "runeboxes",
    ["mageGuildReprints"]          = "reprints",
    ["thief"]                      = "legerdemain",
    ["treasureMaps"]               = "treasuremaps",
    ["giftBoxesSummary"]           = "festivalSummary",
    ["gunnySacksSummary"]          = "fishingSummary",
    ["runeBoxesSummary"]           = "runeboxesSummary",
    ["mageGuildReprintsSummary"]   = "reprintsSummary",
    ["thiefSummary"]               = "legerdemainSummary",
    ["treasuremapsSummary"]        = "treasuremapsSummary",
    ["mageGuildReprintsAutoloot"]  = "reprintsAutoloot",
    ["thiefAutoloot"]              = "legerdemainAutoloot",
    ["treasuremapsAutoloot"]       = "treasuremapsAutoloot",
    ["verbose"]                    = "chatContainerOpen",
}

removedSettings = {
    "accessories",
    "accessoriesSummary",
    "alchemist",
    "alchemistSummary",
    "alchemy",
    "alchemy",
    "alchemyAutoloot",
    "alchemySummary",
    "armor",
    "armorAutoloot",
    "armorSummary",
    "autoloot",
    "battlegrounds",
    "battlegroundsAutoloot",
    "battlegroundsSummary",
    "blacksmith",
    "blacksmithSummary",
    "blacksmithing",
    "blacksmithingAutoloot",
    "blacksmithingSummary",
    "clothier",
    "clothierAutoloot",
    "clothierSummary",
    "consumables",
    "consumablesAutoloot",
    "consumablesSummary",
    "cyrodiil",
    "cyrodiilAutoloot",
    "cyrodiilSummary",
    "darkBrotherhood",
    "darkBrotherhoodAutoloot",
    "darkBrotherhoodSummary",
    "dataVersion",
    "enchanter",
    "enchanterSummary",
    "enchanting",
    "enchantingAutoloot",
    "enchantingSummary",
    "enchantments",
    "enchantmentsAutoloot",
    "enchantmentsSummary",
    "imperialCity",
    "imperialCityAutoloot",
    "imperialCitySummary",
    "jewelry",
    "jewelryAutoloot",
    "jewelrySummary",
    "jewelrycrafting",
    "jewelrycraftingAutoloot",
    "jewelrycraftingSummary",
    "monster",
    "nonSet",
    "nonSetAutoloot",
    "nonSetSummary",
    "other",
    "otherAutoloot",
    "otherSummary",
    "overworld",
    "overworldAutoloot",
    "overworldSummary",
    "potions",
    "potionsSummary",
    "provisioner",
    "provisionerSummary",
    "provisioning",
    "provisioningAutoloot",
    "provisioningSummary",
    "ptsCollectibles",
    "ptsCollectiblesAutoloot",
    "ptsCollectiblesSummary",
    "ptsConsumables",
    "ptsConsumablesAutoloot",
    "ptsConsumablesSummary",
    "ptsCrafting",
    "ptsCraftingAutoloot",
    "ptsCraftingSummary",
    "ptsCurrency",
    "ptsCurrencyAutoloot",
    "ptsCurrencySummary",
    "ptsGear",
    "ptsGearAutoloot",
    "ptsGearSummary",
    "ptsHousing",
    "ptsHousingAutoloot",
    "ptsHousingSummary",
    "ptsOther",
    "ptsOtherAutoloot",
    "ptsOtherSummary",
    "ptsSkills",
    "ptsSkillsAutoloot",
    "ptsSkillsSummary",
    "rewards",
    "rewardsAutoloot",
    "rewardsSummary",
    "weapons",
    "weaponsAutoloot",
    "weaponsSummary",
    "woodworker",
    "woodworkerSummary",
    "woodworking",
    "woodworkingAutoloot",
    "woodworkingSummary",
}