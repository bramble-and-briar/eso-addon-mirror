local A = ALTHarvestItems
local function L(key) return A:T(key) end
local function Number(value, zeroAllowed)
    value = tonumber(value)
    if value and value == value and value < math.huge and (value > 0 or zeroAllowed and value == 0) then
        return value
    end
end
local function Safe(method, ...)
    if type(method) ~= "function" then return nil end
    local ok, value = pcall(method, ...)
    if ok then return value end
end
function A:AGSPrice(id)
    if type(AwesomeGuildStore_Data) ~= "table" then return end
    local account = AwesomeGuildStore_Data[GetWorldName() .. GetDisplayName()]
    if type(account) ~= "table" or type(account.lastSoldPricePerUnit) ~= "table" then return end
    -- Verified in AGS SellTabWrapper: material identifiers are plain item-ID strings.
    return Number(account.lastSoldPricePerUnit[tostring(id)])
end
function A:GrossPrice(id)
    local own = Number(self.db.manualPrices[id], true)
    if own then return own, L("CUSTOM_UNIT_PRICE") end
    local cached = self.priceCache[id]
    if cached and self.Now() - cached.at < 60 then return cached.value, cached.source end
    local price, source
    if self.db.options.useAGS then
        price = self:AGSPrice(id)
        if price then source = L("AGS_LAST_OWN_LISTING_PRICE") end
    end
    local link = self.Link(id)
    if not price and self.db.options.useTTC and TamrielTradeCentrePrice then
        local data = Safe(TamrielTradeCentrePrice.GetPriceInfo, TamrielTradeCentrePrice, link)
        if type(data) == "table" then
            price = Number(data.SuggestedPrice)
            if price then source = L("TTC_SUGGESTED_PRICE")
            else
                price = Number(data.Avg)
                if price then source = L("TTC_AVERAGE_LISTING_PRICE") end
            end
        end
    end
    if not price and self.db.options.useATT then
        local sales = ArkadiusTradeTools and ArkadiusTradeTools.Modules and ArkadiusTradeTools.Modules.Sales
        if sales then
            price = Number(Safe(sales.GetAveragePricePerItem, sales, link, GetTimeStamp() - 30 * 86400))
            if price then source = L("ATT_AVERAGE_SALES_30_DAYS") end
        end
    end
    if not price and self.db.options.useMM and MasterMerchant then
        local data = Safe(MasterMerchant.itemStats, MasterMerchant, link, false)
        if type(data) == "table" then
            price = Number(data.avgPrice)
            if price then source = L("MM_AVERAGE_SALES_PER_MM_SETTINGS") end
        end
    end
    if price == nil then
        price = Number(Safe(GetItemLinkValue, link, false), true)
        if price ~= nil then source = L("NPC_VENDOR_PRICE_FALLBACK") end
    end
    source = source or L("NO_PRICE_AVAILABLE")
    self.priceCache[id] = { value = price, source = source, at = self.Now() }
    return price, source
end
function A:RefreshPrices()
    self.settingsDirty = true
    self.priceCache = {}
    self:QueueRefresh()
end
function A:SetManualPrice(id, text)
    text = text:match("^%s*(.-)%s*$")
    if text == "" then self.db.manualPrices[id] = nil
    else
        local value = Number((text:gsub(",", ".")), true)
        if not value then return false end
        self.db.manualPrices[id] = value
    end
    self:RefreshPrices()
    return true
end

function A:Price(id)
    local gross,source=self:GrossPrice(id)
    if gross~=nil and self.db.options.guildTrader then return gross*0.93,source end
    return gross,source
end
function A:SetGuildTrader(enabled)
    self.db.options.guildTrader=enabled==true
    self:RefreshPrices()
    if self.mainSettings then self:RefreshMainSettings() end
end
