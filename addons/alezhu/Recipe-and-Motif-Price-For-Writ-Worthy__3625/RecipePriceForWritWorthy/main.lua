local logger

local function GetUnknownMotifLink(parser)
    local LCK = LibCharacterKnowledge
    if not LCK then
        return nil
    end
    local motif = parser.motif_num
    local recipe = parser.recipe
    if not motif and recipe then
        if recipe.is_known then
            return nil
        end
        return recipe.recipe_link
    end
    if not parser.motif_num then
        return nil
    end
    local request_item = parser.request_item or {}
    local chapter = request_item.motif_page or ITEM_STYLE_CHAPTER_ALL
    local is_unknown = LCK.GetMotifKnowledgeForCharacter(motif, chapter) == LCK.KNOWLEDGE_UNKNOWN
    if not is_unknown then
        return nil
    end

    -- LibCharacterKnowledge no longer exposes LibCharacterKnowledgeInternal;
    -- use its public API instead.
    local items = LCK.GetMotifItemsFromStyle(motif)
    if type(items) ~= "table" then
        logger:Debug("No motif items for style " .. tostring(motif))
        return nil
    end
    -- Same styleId/chapterId -> itemId logic as LCK's internal TranslateItem
    local id
    if chapter ~= ITEM_STYLE_CHAPTER_ALL then
        id = items.chapters[chapter]
    else
        id = items.books and items.books[1] or nil
    end
    if not id or id == 0 then
        logger:Debug("No chapter item id for style " .. tostring(motif) .. " chapter " .. tostring(chapter))
        return nil
    end
    local link = LCK.GetItemLinkFromItemId(id, LINK_STYLE_BRACKETS)
    return link
end

local function GetMotifInfo(motif_link)
    local string_list = {}
    local curr_fmt = function(value)
        return ZO_Currency_FormatPlatform(CURT_MONEY, value, ZO_CURRENCY_FORMAT_AMOUNT_ICON, nil)
    end

    table.insert(string_list, motif_link)
    if LibPrice then
        local priceData = LibPrice.ItemLinkToPriceData(motif_link)
        local TTC = TamrielTradeCentre
        local ttc = priceData.ttc
        if ttc and TTC then
            if ttc.SuggestedPrice ~= nil then
                table.insert(string_list,
                        string.format("TTC %s: %s",
                                GetString(TTC_SETTING_INCLUDESUGGESTEDPRICE),
                                curr_fmt(ttc.SuggestedPrice)
                        )
                )
            end
            if ttc.Avg ~= nil and ttc.Min ~= nil and ttc.Max ~= nil then
                table.insert(string_list,
                        string.format("TTC " .. GetString(TTC_PRICE_AGGREGATEPRICESXYZ) .. " %s",
                                TTC:FormatNumber(ttc.Avg),
                                TTC:FormatNumber(ttc.Min),
                                TTC:FormatNumber(ttc.Max),
                                ZO_Currency_GetPlatformFormattedCurrencyIcon(CURT_MONEY, false, true)
                        )
                )
            end
        end

        local mm = priceData.mm
        if mm and mm.avgPrice > 0 then
            table.insert(string_list, string.format("MM Avg: %s", curr_fmt(mm.avgPrice)))
        end

        local att = priceData.att
        if att and att.avgPrice > 0 then
            table.insert(string_list, string.format("ATT Avg: %s", curr_fmt(att.avgPrice)))
        end

    end
    local result = table.concat(string_list, "\n")
    return result
end

local function GetOrCreateTooltipControlForMotifInfo(control)
    local parent_name = control:GetName()
    local motif_label_name = parent_name .. "WritWorthyMotifTooltip"
    local motif_label = WINDOW_MANAGER:GetControlByName(motif_label_name)
    if motif_label == nil then
        logger:Debug("Create " .. motif_label_name)
        motif_label = CreateControl(motif_label_name, control, CT_LABEL)
        motif_label:SetFont("ZoFontGame")
        motif_label:SetMouseEnabled(true)
        motif_label:SetHandler('OnMouseEnter', function(self)
            self.tooltip = ItemTooltip
            InitializeTooltip(self.tooltip)
            self.tooltip:SetLink(self.data.link)
            if self.data.link then
                if TamrielTradeCentre and TamrielTradeCentrePrice then
                    TamrielTradeCentrePrice:AppendPriceInfo(self.tooltip, self.data.link)
                end
                --Integrate MM graphs
                if MasterMerchant and MasterMerchant.isInitialized then
                    MasterMerchant:addStatsAndGraph(self.tooltip, self.data.link)
                end
            end
            self.tooltip:SetHidden(false)
        end)
        motif_label:SetHandler('OnMouseExit', function(self)
            if self.tooltip then
                ClearTooltip(self.tooltip)
                self.tooltip:SetHidden(true)
                self.tooltip = nil
            end
        end)
        motif_label:SetHandler('OnMouseDown', function(self, button)
            if button == MOUSE_BUTTON_INDEX_RIGHT then
                zo_callLater(function()
                    ClearMenu()
                    if TamrielTradeCentre then
                        local itemInfo = TamrielTradeCentre_ItemInfo:New(self.data.link)
                        AddCustomMenuItem(
                                TamrielTradeCentre:GetString("TTC_PRICE_PRICETOCHAT", TamrielTradeCentreLangEnum.Default),
                                function()
                                    TamrielTradeCentrePrice:PriceInfoToChat(itemInfo, langEnum)
                                end
                        )
                        if itemInfo.ID ~= nil then
                            AddCustomMenuItem(GetString(TTC_SEARCHONLINE),
                                    function()
                                        TamrielTradeCentrePrice:SearchOnline(itemInfo)
                                    end
                            )
                            AddCustomMenuItem(GetString(TTC_PRICEHISTORYONLINE),
                                    function()
                                        TamrielTradeCentrePrice:PriceDetailOnline(itemInfo)
                                    end
                            )
                        end
                    end

                    if MasterMerchant then
                        AddCustomMenuItem(GetString(MM_STATS_TO_CHAT), function()
                            MasterMerchant:OnItemLinkAction(self.data.link)
                        end)
                    end

                    if ArkadiusTradeTools then
                        local ArkadiusTradeToolsSales = ArkadiusTradeTools.Modules.Sales
                        local L = ArkadiusTradeToolsSales.Localization
                        AddCustomMenuItem(L["ATT_STR_STATS_TO_CHAT"], function()
                            ArkadiusTradeToolsSales:StatsToChat(self.data.link)
                        end)
                    end

                    AddCustomMenuItem(GetString(SI_ITEM_ACTION_LINK_TO_CHAT), function()
                        ZO_LinkHandler_InsertLink(zo_strformat(SI_TOOLTIP_ITEM_NAME, self.data.link))
                    end)
                    ShowMenu(self)
                end, 0)
            end
        end)
    end
    -- NOTE: ZO_Tooltip:AddControl() is a layout operation, not just a
    -- parent change: it (re)inserts the label into the tooltip's row
    -- flow after the tooltip has been rebuilt for the current item.
    -- Tooltips are reused for many items, so this must run every time.
    control:AddControl(motif_label)
    motif_label:SetAnchor(CENTER)
    return motif_label
end

local function HookWritWorthy()
    logger:Debug("HookWritWorthy")

    -- Capture the parser created by ToMatKnowList, keyed by item_link:
    -- a tooltip then consumes the parser of its *own* item_link, even if
    -- other code (WritWorthy window etc.) calls ToMatKnowList in between.
    -- Entry is consumed on read, so nothing accumulates.
    local parser_cache = {}
    local orig_ToMatKnowList = WritWorthy.ToMatKnowList
    WritWorthy.ToMatKnowList = function(item_link, ...)
        local mat_list, know_list, parser = orig_ToMatKnowList(item_link, ...)
        parser_cache[item_link] = parser
        return mat_list, know_list, parser
    end

    SecurePostHook(WritWorthy, "TooltipInsertOurText", function(control, item_link, purchase_gold, unique_id, style)
        -- Only master writs were parsed by the original function
        if GetItemLinkItemType(item_link) ~= ITEMTYPE_MASTER_WRIT then
            return
        end
        logger:Debug("TooltipInsertOurText")
        local motif_label = GetOrCreateTooltipControlForMotifInfo(control)
        motif_label:SetHidden(true)

        -- Parser from the just-finished ToMatKnowList call for this link;
        -- re-parse only as a fallback if WritWorthy stops calling it there
        local parser = parser_cache[item_link]
        parser_cache[item_link] = nil
        if not parser then
            local _, _, fallback = WritWorthy.ToMatKnowList(item_link)
            parser = fallback
        end
        if not parser then
            return
        end
        local motif_link = GetUnknownMotifLink(parser)
        if motif_link then
            motif_label.data = { link = motif_link }
            motif_label:SetText(GetMotifInfo(motif_link))
            motif_label:SetHidden(false)
        end
    end)
end

local function Start(addonName)
    if LibDebugLogger then
        logger = LibDebugLogger(addonName)
    else
        logger = { Debug = function() end }
    end
    -- On load
    logger:Debug("Start")
    local function OnLoaded(_, loadedAddonName)
        if (addonName == loadedAddonName) then
            logger:Debug("OnLoaded")
            HookWritWorthy()
            EVENT_MANAGER:UnregisterForEvent(addonName, EVENT_ADD_ON_LOADED)
        end
    end
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_ADD_ON_LOADED, OnLoaded)
end

Start("RecipePriceForWritWorthy")