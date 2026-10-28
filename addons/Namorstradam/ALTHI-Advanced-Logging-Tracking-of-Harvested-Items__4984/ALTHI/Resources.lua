local A = ALTHarvestItems
A.categories = {
    { key = "alchemy", name = "ALCHEMY_PLANTS_FUNGI_AND_WATER" },
    { key = "metal", name = "BLACKSMITHING_ORE_AND_MATERIALS" },
    { key = "wood", name = "WOODWORKING_WOOD_AND_MATERIALS" },
    { key = "cloth", name = "CLOTHING_FIBRES_LEATHER_AND_HIDES" },
    { key = "jewelry", name = "JEWELLERY_DUST_AND_MATERIALS" },
    { key = "runes", name = "ENCHANTING_RUNES" },
    { key = "housing", name = "HOUSING_FURNISHING_MATERIALS" },
    { key = "style", name = "STYLE_MATERIALS" },
    { key = "traits", name = "TRAIT_MATERIALS" },
    { key = "powder", name = "PULVERISED_MATERIALS" },
    { key = "rare", name = "RARE_HARVESTS" },
    { key = "provisioning", name = "PROVISIONING" },
}
local groups = {
    provisioning = { "INGREDIENT" },
    alchemy = { "REAGENT", "POTION_BASE", "POISON_BASE" },
    metal = { "BLACKSMITHING_RAW_MATERIAL", "BLACKSMITHING_MATERIAL", "BLACKSMITHING_BOOSTER" },
    wood = { "WOODWORKING_RAW_MATERIAL", "WOODWORKING_MATERIAL", "WOODWORKING_BOOSTER" },
    cloth = { "CLOTHIER_RAW_MATERIAL", "CLOTHIER_MATERIAL", "CLOTHIER_BOOSTER" },
    jewelry = { "JEWELRYCRAFTING_RAW_MATERIAL", "JEWELRYCRAFTING_MATERIAL", "JEWELRYCRAFTING_BOOSTER" },
    runes = { "ENCHANTING_RUNE_ASPECT", "ENCHANTING_RUNE_ESSENCE", "ENCHANTING_RUNE_POTENCY" },
    housing = { "FURNISHING_MATERIAL" }, style = { "STYLE_MATERIAL" },
    traits = { "ARMOR_TRAIT", "WEAPON_TRAIT", "JEWELRY_TRAIT" },
    powder = { "JEWELRY_RAW_TRAIT", "JEWELRYCRAFTING_RAW_BOOSTER", "RAW_MATERIAL" },
}
function A:BuildMaterialTypes()
    self.materialTypes = {}
    self.normalNodeIds = {}
    for _, id in ipairs(A.Seed and A.Seed.nodeIds or {}) do self.normalNodeIds[id] = true end
    for category, types in pairs(groups) do
        for _, suffix in ipairs(types) do
            local value = _G["ITEMTYPE_" .. suffix]
            if value then self.materialTypes[value] = category end
        end
    end
end
function A:CategoryFor(id, itemType)
    if id == 115026 or id == 204881 then return "rare" end -- Dust and Luminous Ink: explicit identities, not generic consumables.
    return self.materialTypes[itemType]
end
function A:IsEnabled(id)
    local item = self.db.catalog[id]
    return item and item.category and self.db.whitelist[id] ~= false
        and self.db.categoryEnabled[item.category] ~= false
        and self.db.sectionEnabled[self:SectionFor(item)] ~= false
        and self.db.subgroupEnabled[self:SectionFor(item) .. ":" .. item.category] ~= false
end
function A:Observe(link)
    if not link or link == "" then return end
    local id = self.ValidId(GetItemLinkItemId(link))
    if not id then return end
    local itemType = GetItemLinkItemType(link)
    local category = self:CategoryFor(id, itemType)
    if not category then return end
    local name = zo_strformat("<<C:1>>", GetItemLinkName(link))
    if name == "" then return end
    local old = self.db.catalog[id]
    self.db.catalog[id] = { name = name, itemType = itemType, category = category,
        icon = GetItemLinkIcon(link), quality = GetItemLinkDisplayQuality(link), sources = old and old.sources or {}, observed = old and old.observed or {} }
    if old and old.sources and old.sources.world and not self.db.catalog[id].observed.world then
        self.db.catalog[id].observed.world = { target = "" }
    end
    if self.normalNodeIds[id] then self.db.catalog[id].sources.normal = true end
    if self.db.whitelist[id] == nil then self.db.whitelist[id] = true end
    if not old or old.category ~= category then self.catalogRevision = (self.catalogRevision or 0) + 1 end
    return id, name
end
function A:HydrateCatalog()
    for id, entry in pairs(self.db.catalog) do
        entry.category = self:CategoryFor(id, entry.itemType)
        if entry.category then self:Observe(self.Link(id)) end
    end
end
function A:LoadCatalog()
    local seed = A.Seed or { ids = {}, recipes = {} }
    self:HydrateCatalog()
    for _, id in ipairs(seed.ids) do self:Observe(self.Link(id)) end
    if GetNumValidItemStyles and GetValidItemStyleId and GetItemStyleMaterialLink then
        for index = 1, GetNumValidItemStyles() do
            self:Observe(GetItemStyleMaterialLink(GetValidItemStyleId(index), LINK_STYLE_DEFAULT))
        end
    end
    if GetNumSmithingTraitItems and GetSmithingTraitItemLink then
        for index = 1, GetNumSmithingTraitItems() do
            self:Observe(GetSmithingTraitItemLink(index, LINK_STYLE_DEFAULT))
        end
    end
    self:ActivateMaterialExpansion()
    if self.db.catalogVersion == self.version and self.db.catalogApi == GetAPIVersion() then
        self.catalogLoading = false; self:QueueRefresh(); return
    end
    self.catalogLoading = true
    local cursor = 1
    local bookList, bookRecipe = 1, 1
    local bookLists = GetNumRecipeLists and GetRecipeListInfo and GetRecipeInfo and GetRecipeIngredientItemLink
        and GetNumRecipeLists() or 0
    EVENT_MANAGER:UnregisterForUpdate("ALTHICatalog")
    EVENT_MANAGER:RegisterForUpdate("ALTHICatalog", 50, function()
        for index = cursor, math.min(cursor + 19, #seed.recipes) do
            local link = self.Link(seed.recipes[index])
            for ingredient = 1, GetItemLinkRecipeNumIngredients(link) or 0 do
                self:Observe(GetItemLinkRecipeIngredientItemLink(link, ingredient, LINK_STYLE_DEFAULT))
            end
        end
        cursor = cursor + 20
        -- Supplement the historical recipe seed with the current client's recipe book.
        -- Do not require ownership/knowledge; unavailable ingredient links are ignored.
        for _ = 1, 20 do
            if bookList > bookLists then break end
            local _, recipes = GetRecipeListInfo(bookList)
            if bookRecipe > (recipes or 0) then
                bookList, bookRecipe = bookList + 1, 1
            else
                local _, _, ingredients = GetRecipeInfo(bookList, bookRecipe)
                for ingredient = 1, ingredients or 0 do
                    self:Observe(GetRecipeIngredientItemLink(bookList, bookRecipe, ingredient, LINK_STYLE_DEFAULT))
                end
                bookRecipe = bookRecipe + 1
            end
        end
        if cursor > #seed.recipes and bookList > bookLists then
            self.catalogLoading = false
            self.db.catalogVersion = self.version
            self.db.catalogApi = GetAPIVersion()
            EVENT_MANAGER:UnregisterForUpdate("ALTHICatalog")
            if self.settingsWindow then self:RefreshSettings() end
        end
        self:QueueRefresh()
    end)
end
function A:ActivateMaterialExpansion()
    if self.db.materialExpansion0107 then return end
    local ids = {}
    for id, item in pairs(self.db.catalog) do
        if item.category == "provisioning" or id == 204881 then ids[#ids + 1] = id end
    end
    -- Preserve effective choices outside the newly requested materials when lifting masks.
    self:SetItemsEnabled(ids, true)
    self.db.materialExpansion0107 = true
end
function A:SetCategory(key, enabled)
    self.db.categoryEnabled[key] = enabled
    for id, item in pairs(self.db.catalog) do
        if item.category == key then self.db.whitelist[id] = enabled end
    end
    self:SelectionChanged()
end
function A:SelectionChanged()
    self.offset = 0
    self:QueueRefresh()
    if self.settingsWindow then self:RefreshSettings() end
end

-- Handwerksbeutel is a stock snapshot, never a source of session harvests.
function A:ScanStock()
    self.stock, self.stockSlots = {}, {}
    local slot = GetNextVirtualBagSlotId(nil)
    while slot do
        local id = self:Observe(GetItemLink(BAG_VIRTUAL, slot))
        if id then
            self.stockSlots[slot] = id
            self.stock[id] = GetSlotStackSize(BAG_VIRTUAL, slot) or 0
        end
        slot = GetNextVirtualBagSlotId(slot)
    end
    self.stockReady = true
    self:QueueRefresh()
end
function A:StockSlotChanged(_, bag, slot)
    local oldId = self.stockSlots[slot]
    local id = self:Observe(GetItemLink(bag, slot))
    if oldId and oldId ~= id then self.stock[oldId] = 0 end
    self.stockSlots[slot] = id
    if id then self.stock[id] = GetSlotStackSize(bag, slot) or 0 end
    self:QueueRefresh()
end
