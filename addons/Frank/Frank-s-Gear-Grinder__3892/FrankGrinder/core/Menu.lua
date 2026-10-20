function FrankGrinder:BuildMenu()
    local LAM = LibAddonMenu2
    if not LAM then
        self:ChatMsg(GetString(GG_LAM_NOT_FOUND))
        return
    end

    local panelData = {
        type = "panel",
        name = "|cFF0000Frank's |cFF5500Gear Grinder|r",
        displayName = "|cFF0000Frank's |cFF5500Gear Grinder|r",
        author = self.author,
        version = self.addonVersion,
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsTable = {
        { type = "header", name = GetString(GG_MENU_LE_HEADER), width = "full" },
        { type = "description", text = GetString(GG_MENU_LE_DESC), width = "full" },

        {
            type = "checkbox",
            name = GetString(GG_MENU_LE_ENABLED),
            tooltip = GetString(GG_MENU_LE_ENABLED_TT),
            getFunc = function() return self:GetSettingLeadWarningEnabled() end,
            setFunc = function(v) self:SetSettingLeadWarningEnabled(v) end,
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(GG_MENU_LE_ANNOUNCE_REMINDERS),
            tooltip = GetString(GG_MENU_LE_ANNOUNCE_REMINDERS_TT),
            getFunc = function() return self:GetSettingLeadWarningAnnounce() end,
            setFunc = function(v) self:SetSettingLeadWarningAnnounce(v) end,
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(GG_MENU_LE_CHAT_REMINDERS),
            tooltip = GetString(GG_MENU_LE_CHAT_REMINDERS_TT),
            getFunc = function() return self:GetSettingLeadWarningChatWindow() end,
            setFunc = function(v) self:SetSettingLeadWarningChatWindow(v) end,
            width = "full",
        },
        {
            type = "editbox",
            name = GetString(GG_MENU_LE_WARNING_PERIOD),
            tooltip = GetString(GG_MENU_LE_WARNING_PERIOD_TT),
            getFunc = function() return self:GetSettingLeadWarningPeriod() end,
            setFunc = function(v) self:SetSettingLeadWarningPeriod(v) end,
        },
        {
            type = "editbox",
            name = GetString(GG_MENU_LE_NO_WARNING_PERIOD),
            tooltip = GetString(GG_MENU_LE_NO_WARNING_PERIOD_TT),
            getFunc = function() return self:GetSettingLeadNoWarningPeriod() end,
            setFunc = function(v) self:SetSettingLeadNoWarningPeriod(v) end,
        },

        { type = "header", name = GetString(GG_MENU_GF_HEADER), width = "full" },
        {
            type = "checkbox",
            name = GetString(GG_MENU_GF_ENABLED),
            tooltip = GetString(GG_MENU_GF_ENABLED_TT),
            getFunc = function() return self:GetSettingGroupFinderEnabled() end,
            setFunc = function(v) self:SetSettingGroupFinderEnabled(v) end,
            width = "full",
        },
        {
            type = "editbox",
            name = GetString(GG_MENU_GF_CHECK_INTERVAL),
            tooltip = GetString(GG_MENU_GF_CHECK_INTERVAL_TT),
            getFunc = function() return self:GetSettingGroupFinderCheckInterval() end,
            setFunc = function(v) self:SetSettingGroupFinderCheckInterval(v) end,
        },
        { type = "header", name = GetString(GG_MENU_GF_TRIAL_HEADER), width = "full" },
        { type = "description", text = GetString(GG_MENU_GF_TRIAL_DESC), width = "full" },
    }

    local orderedKeys = {}
    for key in pairs(self.Trials) do table.insert(orderedKeys, key) end
    table.sort(orderedKeys, function(a, b) return self.Trials[a].zoneId < self.Trials[b].zoneId end)

    for _, key in ipairs(orderedKeys) do
        local data = self.Trials[key]
        table.insert(optionsTable, {
            type = "checkbox",
            name = string.format("%s (%s)", data.zoneName, key),
            tooltip = string.format(GetString(GG_MENU_GF_TRIAL_TT), data.zoneName),
            getFunc = function() return self:GetSettingGroupFinderTrials(key) end,
            setFunc = function(v) self:SetSettingGroupFinderTrials(key, v) end,
            width = "full",
        })
    end

    table.insert(optionsTable, { type = "header", name = GetString(GG_MENU_PA_HEADER), width = "full" })
    table.insert(optionsTable, { type = "description", text = GetString(GG_MENU_PA_DESC), width = "full" })
    table.insert(optionsTable, {
        type = "description",
        text = function()
            local active, reason = FrankGrinder:GetPAHookStatus()

            if active then
                return "|c00FF00Personal Assistant Integration: ACTIVE|r"
            else
                return "|cFF0000Personal Assistant Integration: INACTIVE|r\n|cAAAAAAReason: " .. reason .. "|r"
            end
        end,
        width = "full",
    })
    table.insert(optionsTable, {
        type = "checkbox",
        name = GetString(GG_MENU_PA_ENABLED),
        tooltip = GetString(GG_MENU_PA_ENABLED_TT),
        getFunc = function() return self:GetSettingOverridePAKnown() end,
        setFunc = function(v) self:SetSettingOverridePAKnown(v) end,
        width = "full",
    })
    table.insert(optionsTable, {
        type = "editbox",
        name = GetString(GG_MENU_PA_SALE_VALUE_THRESHOLD),
        tooltip = GetString(GG_MENU_PA_SALE_VALUE_THRESHOLD_TT),
        getFunc = function() return self:GetSettingSaleValueThreshold() end,
        setFunc = function(v) self:SetSettingSaleValueThreshold(v) end,
    })
    table.insert(optionsTable, {
        type = "editbox",
        name = GetString(GG_MENU_PA_CRAFTER_CHARACTER_NAME),
        tooltip = GetString(GG_MENU_PA_CRAFTER_CHARACTER_NAME_TT),
        getFunc = function() return self:GetSettingCrafterCharacterName() end,
        setFunc = function(v) self:SetSettingCrafterCharacterName(v) end,
    })
    table.insert(optionsTable, {
        type = "checkbox",
        name = GetString(GG_MENU_PA_WITHDRAW_TO_TRADER_ENABLED),
        tooltip = GetString(GG_MENU_PA_WITHDRAW_TO_TRADER_ENABLED_TT),
        getFunc = function() return self:GetSettingWithdrawToTraderEnabled() end,
        setFunc = function(v) self:SetSettingWithdrawToTraderEnabled(v) end,
        width = "full",
    })
    table.insert(optionsTable, {
        type = "editbox",
        name = GetString(GG_MENU_PA_TRADER_CHARACTER_NAME),
        tooltip = GetString(GG_MENU_PA_TRADER_CHARACTER_NAME_TT),
        getFunc = function() return self:GetSettingTraderCharacterName() end,
        setFunc = function(v) self:SetSettingTraderCharacterName(v) end,
    })

    table.insert(optionsTable, { 
        type = "header", 
        name = "Mail to Other Accounts", 
        width = "full" 
    })
    table.insert(optionsTable, { 
        type = "checkbox", 
        name = "Enabled?", 
        tooltip = "Displays buttons to send items to other accounts.", 
        getFunc = function() return self:GetSettingMailToOtherAccountEnabled() end, 
        setFunc = function(value) self:SetSettingMailToOtherAccountEnabled(value) end, 
    })
    table.insert(optionsTable, {
        type = "editbox",
        name = "Items Recipient",
        tooltip = "Account name to send items to (@name).",
        getFunc = function() return self:GetSettingMailItemsAccount() end,
        setFunc = function(value) self:SetSettingMailItemsAccount(value) end,
    })
    table.insert(optionsTable, {
        type = "editbox",
        name = "Crafting Materials Recipient",
        tooltip = "Account name to send crafting materials to (@name).",
        getFunc = function() return self:GetSettingMailMatsAccount() end,
        setFunc = function(value) self:SetSettingMailMatsAccount(value) end,
    })
    --table.insert(optionsTable, { type = "header", name = "Mailer Filters", width = "full" })

    table.insert(optionsTable, {
        type = "checkbox",
        name = "Intricate Woodcrafting",
        tooltip = "Send intricate woodworking items to the configured Items recipient.",
        getFunc = function() return self:GetSettingMailIntricateWoodcrafting() end,
        setFunc = function(v) self:SetSettingMailIntricateWoodcrafting(v) end,
    })

    table.insert(optionsTable, {
        type = "checkbox",
        name = "Intricate Clothier",
        tooltip = "Send intricate clothier items.",
        getFunc = function() return self:GetSettingMailIntricateClothier() end,
        setFunc = function(v) self:SetSettingMailIntricateClothier(v) end,
    })

    table.insert(optionsTable, {
        type = "checkbox",
        name = "Intricate Blacksmithing",
        tooltip = "Send intricate blacksmithing items.",
        getFunc = function() return self:GetSettingMailIntricateBlacksmithing() end,
        setFunc = function(v) self:SetSettingMailIntricateBlacksmithing(v) end,
    })

    table.insert(optionsTable, {
        type = "checkbox",
        name = "Intricate Jewelry",
        tooltip = "Send intricate jewelry items.",
        getFunc = function() return self:GetSettingMailIntricateJewelry() end,
        setFunc = function(v) self:SetSettingMailIntricateJewelry(v) end,
    })

    table.insert(optionsTable, {
        type = "checkbox",
        name = "Glyphs",
        tooltip = "Send non-legendary glyphs.",
        getFunc = function() return self:GetSettingMailGlyphs() end,
        setFunc = function(v) self:SetSettingMailGlyphs(v) end,
    })

    table.insert(optionsTable, {
        type = "checkbox",
        name = "Crafting Materials",
        tooltip = "Send crafting materials.",
        getFunc = function() return self:GetSettingMailCraftingMats() end,
        setFunc = function(v) self:SetSettingMailCraftingMats(v) end,
    })

    table.insert(optionsTable, {
        type = "checkbox",
        name = "BoE Set Items",
        tooltip = "Send collected Bind-on-Equip set items.",
        getFunc = function() return self:GetSettingMailBoEItems() end,
        setFunc = function(v) self:SetSettingMailBoEItems(v) end,
    })

    table.insert(optionsTable, {
        type = "checkbox",
        name = "Unknown Writs",
        tooltip = "Send unknown master crafting writs.",
        getFunc = function() return self:GetSettingMailUnknownWrits() end,
        setFunc = function(v) self:SetSettingMailUnknownWrits(v) end,
    })

    table.insert(optionsTable, {
        type = "checkbox",
        name = "Unidentified Surveys",
        tooltip = "Send unidentified survey maps.",
        getFunc = function() return self:GetSettingMailUnknownSurveys() end,
        setFunc = function(v) self:SetSettingMailUnknownSurveys(v) end,
    })
    table.insert(optionsTable, {
        type = "checkbox",
        name = "Unopened Treasure Maps",
        tooltip = "Send unopened treasure maps.",
        getFunc = function() return self:GetSettingMailUnknownTreasures() end,
        setFunc = function(v) self:SetSettingMailUnknownTreasures(v) end,
        width = "full",
    })

    table.insert(optionsTable, { type = "header", name = GetString(GG_MENU_KC_HEADER), width = "full" })
    table.insert(optionsTable, { type = "description", text = GetString(GG_MENU_KC_DESC), width = "full" })
    table.insert(optionsTable, {
        type = "checkbox",
        name = GetString(GG_MENU_KC_ENABLED),
        tooltip = GetString(GG_MENU_KC_ENABLED_TT),
        getFunc = function() return self:GetSettingKeyChordingEnabled() end,
        setFunc = function(v) self:SetSettingKeyChordingEnabled(v) end,
        default = false,
        width = "full",
    })

    table.insert(optionsTable, { type = "header", name = "Debug", width = "full" })
    table.insert(optionsTable, {
        type = "checkbox",
        name = "Enabled?",
        getFunc = function() return self:IsDebugEnabled() end,
        setFunc = function(v) self:SetDebugEnabled(v) end,
        width = "full",
    })

    LAM:RegisterAddonPanel(self.name .. "Options", panelData)
    LAM:RegisterOptionControls(self.name .. "Options", optionsTable)
end
