-- ESO Adventurer Suite
-- Merchant / Fence Category Strip
-- Keeps ESO's native secure rows intact. The Suite filters the real native
-- scroll-list entries; it never inserts addon header rows into the player backpack.

local EPC = ESOProgressionCoach
if not EPC then return end

EPC.MerchantFenceCategoryBar = EPC.MerchantFenceCategoryBar or {}
local V = EPC.MerchantFenceCategoryBar
local wm = WINDOW_MANAGER
local NAME = (EPC.name or "ESOAdventurerSuite") .. "_MerchantFenceCategories029765"

local FILTERS = {
    { key="ALL", label="ALL" },
    { key="GEAR", label="GEAR" },
    { key="CONSUMABLES", label="CONSUMABLES" },
    { key="MATERIALS", label="MATERIALS" },
    { key="MISC", label="MISC" },
}

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a,b,c,d,e = pcall(fn, ...)
    if not ok or a == nil then return fallback end
    return a,b,c,d,e
end

local function linkForEntry(entry)
    local grid = rawget(_G, "EASInventoryGrid")
    if grid and type(grid.GetNativeEntryLink029364) == "function" then
        return tostring(grid:GetNativeEntryLink029364(entry) or "")
    end
    local data = type(entry)=="table" and (entry.data or entry) or nil
    if type(data)~="table" then return "" end
    local link = data.itemLink or data.link or data.itemLinkString
    if tostring(link or "") ~= "" then return tostring(link) end
    local bag = tonumber(data.bagId or data.bag)
    local slot = tonumber(data.slotIndex or data.slot)
    if bag ~= nil and slot ~= nil and type(GetItemLink)=="function" then
        return tostring(safe(GetItemLink, "", bag, slot, LINK_STYLE_DEFAULT or 0) or "")
    end
    local storeIndex = tonumber(data.storeIndex or data.storeEntryIndex)
    if storeIndex and type(GetStoreItemLink)=="function" then
        return tostring(safe(GetStoreItemLink, "", storeIndex, LINK_STYLE_DEFAULT or 0) or "")
    end
    return ""
end

local function classify(link)
    if link == "" then return "MISC" end
    local equipType = tonumber(safe(GetItemLinkEquipType, 0, link)) or 0
    local weaponType = tonumber(safe(GetItemLinkWeaponType, 0, link)) or 0
    local armorType = tonumber(safe(GetItemLinkArmorType, 0, link)) or 0
    if equipType ~= 0 or weaponType ~= 0 or armorType ~= 0 then return "GEAR" end

    local itemType = tonumber(safe(GetItemLinkItemType, 0, link)) or 0
    local consumables = {}
    local materials = {}
    local function addType(set, globalName)
        local value = rawget(_G, globalName)
        if value ~= nil then set[value] = true end
    end
    for _,name in ipairs({
        "ITEMTYPE_FOOD","ITEMTYPE_DRINK","ITEMTYPE_POTION","ITEMTYPE_POISON","ITEMTYPE_RECIPE",
    }) do addType(consumables,name) end
    if consumables[itemType] then return "CONSUMABLES" end

    for _,name in ipairs({
        "ITEMTYPE_REAGENT","ITEMTYPE_INGREDIENT","ITEMTYPE_SPICE","ITEMTYPE_FLAVORING",
        "ITEMTYPE_ENCHANTING_RUNE_ASPECT","ITEMTYPE_ENCHANTING_RUNE_ESSENCE","ITEMTYPE_ENCHANTING_RUNE_POTENCY",
        "ITEMTYPE_BLACKSMITHING_RAW_MATERIAL","ITEMTYPE_BLACKSMITHING_MATERIAL",
        "ITEMTYPE_WOODWORKING_RAW_MATERIAL","ITEMTYPE_WOODWORKING_MATERIAL",
        "ITEMTYPE_CLOTHIER_RAW_MATERIAL","ITEMTYPE_CLOTHIER_MATERIAL",
        "ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL","ITEMTYPE_JEWELRYCRAFTING_MATERIAL",
        "ITEMTYPE_STYLE_MATERIAL","ITEMTYPE_TRAIT_MATERIAL",
    }) do addType(materials,name) end
    if materials[itemType] then return "MATERIALS" end
    return "MISC"
end

local function isSuiteHeader(entry)
    local d=type(entry)=="table" and (entry.data or entry) or nil
    return type(d)=="table" and (d.easSuiteCategoryHeader029364==true or d.easSuiteCategoryHeader029376==true)
end

function V:GetCandidateLists029765()
    local out, seen = {}, {}
    local function add(list)
        if not list or seen[list] or type(ZO_ScrollList_GetDataList)~="function" then return end
        local ok,data=pcall(ZO_ScrollList_GetDataList,list)
        if ok and type(data)=="table" then seen[list]=true; out[#out+1]=list end
    end
    add(rawget(_G,"ZO_PlayerInventoryList"))
    add(rawget(_G,"ZO_StoreWindowList"))
    add(rawget(_G,"ZO_StoreWindowBuyBackList"))
    add(rawget(_G,"ZO_StoreWindowBuybackList"))
    return out
end

function V:RestoreList029765(list)
    local base=self.base029765 and self.base029765[list]
    if type(base)~="table" or type(ZO_ScrollList_GetDataList)~="function" then return end
    local ok,data=pcall(ZO_ScrollList_GetDataList,list)
    if not ok or type(data)~="table" then return end
    for i=#data,1,-1 do data[i]=nil end
    for i,e in ipairs(base) do data[i]=e end
    if type(ZO_ScrollList_Commit)=="function" then pcall(ZO_ScrollList_Commit,list) end
end

function V:CaptureBase029765(list)
    if not list or type(ZO_ScrollList_GetDataList)~="function" then return nil end
    self.base029765=self.base029765 or setmetatable({}, {__mode="k"})
    local ok,data=pcall(ZO_ScrollList_GetDataList,list)
    if not ok or type(data)~="table" then return nil end

    -- Native UI may have rebuilt the list since our last pass. Capture only real
    -- item rows and native non-item rows; never cache old Suite category headers.
    local clean={}
    for _,e in ipairs(data) do if not isSuiteHeader(e) then clean[#clean+1]=e end end
    self.base029765[list]=clean
    return clean
end

function V:ApplyFilterToList029765(list)
    local filter=self.filter029765 or "ALL"
    local base=self:CaptureBase029765(list)
    if type(base)~="table" then return end
    local ok,data=pcall(ZO_ScrollList_GetDataList,list)
    if not ok or type(data)~="table" then return end

    local rebuilt={}
    for _,entry in ipairs(base) do
        local link=linkForEntry(entry)
        if link=="" or filter=="ALL" or classify(link)==filter then rebuilt[#rebuilt+1]=entry end
    end
    for i=#data,1,-1 do data[i]=nil end
    for i,e in ipairs(rebuilt) do data[i]=e end
    if type(ZO_ScrollList_Commit)=="function" then pcall(ZO_ScrollList_Commit,list) end
end

function V:Apply029765()
    if not self.active029765 then return end
    for _,list in ipairs(self:GetCandidateLists029765()) do self:ApplyFilterToList029765(list) end
    self:RefreshButtons029765()
end

function V:RefreshButtons029765()
    for key,button in pairs(self.buttons029765 or {}) do
        local active=(self.filter029765 or "ALL")==key
        if button.easBg029765 then
            if active then button.easBg029765:SetCenterColor(0.16,0.29,0.36,0.98)
            else button.easBg029765:SetCenterColor(0.035,0.050,0.070,0.96) end
        end
    end
end

function V:Create029765()
    if self.root029765 or not wm or not GuiRoot then return self.root029765 end
    local root=wm:CreateTopLevelWindow("EAS_MerchantFenceCategoryBar029765")
    root:SetDimensions(585,38)
    root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 92, 170)
    root:SetDrawTier(rawget(_G,"DT_HIGH") or 2)
    root:SetHidden(true)
    root:SetMouseEnabled(true)
    local bg=wm:CreateControl(nil,root,CT_BACKDROP); bg:SetAnchorFill(root)
    bg:SetCenterColor(0.012,0.018,0.028,0.97); bg:SetEdgeColor(0.52,0.42,0.18,0.95); bg:SetEdgeTexture(nil,1,1,1)

    self.buttons029765={}
    local previous=nil
    for _,info in ipairs(FILTERS) do
        local b=wm:CreateControl(nil,root,CT_BUTTON)
        b:SetDimensions(info.key=="CONSUMABLES" and 132 or 102,30)
        if previous then b:SetAnchor(LEFT,previous,RIGHT,6,0) else b:SetAnchor(LEFT,root,LEFT,8,0) end
        b:SetFont("ZoFontGameBold"); b:SetText(info.label)
        b:SetHorizontalAlignment(TEXT_ALIGN_CENTER); b:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        local bb=wm:CreateControl(nil,b,CT_BACKDROP); bb:SetAnchorFill(b); bb:SetEdgeColor(0.20,0.32,0.40,0.95); bb:SetEdgeTexture(nil,1,1,1)
        b.easBg029765=bb
        local key=info.key
        b:SetHandler("OnClicked",function()
            V.filter029765=key
            V:Apply029765()
        end)
        self.buttons029765[key]=b
        previous=b
    end
    self.root029765=root
    self:RefreshButtons029765()
    return root
end

function V:Open029765(context)
    self.context029765=context or "STORE"
    self.active029765=true
    self.filter029765="ALL"
    self.base029765=setmetatable({}, {__mode="k"})
    local root=self:Create029765()
    if root then root:SetHidden(false) end

    local function refresh()
        if not V.active029765 then return end
        -- Strip any stale Suite header rows first. Merchant Sell and Fence use
        -- the player backpack list, which must stay header-free.
        local grid=rawget(_G,"EASInventoryGrid")
        if grid and type(grid.PurgeUnsafePlayerInventoryHeaders029475)=="function" then
            grid:PurgeUnsafePlayerInventoryHeaders029475()
        end
        V:Apply029765()
    end
    if type(zo_callLater)=="function" then
        for _,delay in ipairs({0,80,220,500}) do zo_callLater(refresh,delay) end
    else refresh() end
end

function V:Close029765()
    for list in pairs(self.base029765 or {}) do self:RestoreList029765(list) end
    self.active029765=false
    self.context029765=nil
    self.base029765=setmetatable({}, {__mode="k"})
    if self.root029765 then self.root029765:SetHidden(true) end
end

function V:Initialize029765()
    if self.initialized029765 or not EVENT_MANAGER then return end
    self.initialized029765=true
    if rawget(_G,"EVENT_OPEN_STORE") then
        EVENT_MANAGER:RegisterForEvent(NAME.."_Store",EVENT_OPEN_STORE,function()
            V:Open029765("MERCHANT")
        end)
    end
    if rawget(_G,"EVENT_OPEN_FENCE") then
        EVENT_MANAGER:RegisterForEvent(NAME.."_Fence",EVENT_OPEN_FENCE,function()
            V:Open029765("FENCE")
        end)
    end
    if rawget(_G,"EVENT_CLOSE_STORE") then
        EVENT_MANAGER:RegisterForEvent(NAME.."_Close",EVENT_CLOSE_STORE,function()
            V:Close029765()
        end)
    end

    if rawget(_G,"EVENT_INVENTORY_FULL_UPDATE") then
        EVENT_MANAGER:RegisterForEvent(NAME.."_Full",EVENT_INVENTORY_FULL_UPDATE,function()
            if V.active029765 and type(zo_callLater)=="function" then zo_callLater(function() V:Apply029765() end,60) end
        end)
    end
    if rawget(_G,"EVENT_INVENTORY_SINGLE_SLOT_UPDATE") then
        EVENT_MANAGER:RegisterForEvent(NAME.."_Slot",EVENT_INVENTORY_SINGLE_SLOT_UPDATE,function()
            if V.active029765 and type(zo_callLater)=="function" then zo_callLater(function() V:Apply029765() end,60) end
        end)
    end
end

V:Initialize029765()
