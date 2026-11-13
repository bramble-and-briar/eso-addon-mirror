-- Turns a stored queue record (sale, listing or guild trader) into the text encoded in the QR code.
-- The phone app parses this JSON; keep it in sync with the payloadVersion in Namespace.lua.
local SalePayload = ZO_InitializingObject:Subclass()

function SalePayload:Initialize(jsonEncoder)
    self.jsonEncoder = jsonEncoder
end

function SalePayload:Build(record)
    if record.kind == TradeQR.RECORD_KIND_LISTING then
        return self:BuildListing(record)
    elseif record.kind == TradeQR.RECORD_KIND_TRADER then
        return self:BuildTrader(record)
    end
    return self:BuildSale(record)
end

function SalePayload:BuildSale(sale)
    return self.jsonEncoder:EncodeObject({
        { "src", "TradeQR" },
        { "v", TradeQR.payloadVersion },
        { "type", TradeQR.RECORD_KIND_SALE },
        { "id", sale.eventId },
        { "ts", sale.timestamp },
        { "guild", sale.guildName },
        { "gid", sale.guildId or 0 },
        { "item", sale.itemName },
        { "link", sale.itemLink },
        { "qty", sale.quantity },
        { "price", sale.price },
        { "tax", sale.tax },
        { "buyer", sale.buyer },
        { "seller", sale.seller },
    })
end

function SalePayload:BuildListing(listing)
    return self.jsonEncoder:EncodeObject({
        { "src", "TradeQR" },
        { "v", TradeQR.payloadVersion },
        { "type", TradeQR.RECORD_KIND_LISTING },
        { "id", listing.eventId },
        { "ts", listing.timestamp },
        { "guild", listing.guildName },
        { "gid", listing.guildId or 0 },
        { "item", listing.itemName },
        { "link", listing.itemLink },
        { "uid", listing.itemUniqueId or "" },
        { "qty", listing.quantity },
        { "price", listing.price },
        { "fee", listing.fee },
        { "seller", listing.seller },
        { "char", listing.character or "" },
        { "loc", listing.location or "" },
    })
end

function SalePayload:BuildTrader(trader)
    return self.jsonEncoder:EncodeObject({
        { "src", "TradeQR" },
        { "v", TradeQR.payloadVersion },
        { "type", TradeQR.RECORD_KIND_TRADER },
        { "id", trader.eventId },
        { "ts", trader.timestamp },
        { "guild", trader.guildName },
        { "gid", trader.guildId },
        { "trader", trader.traderName },
        { "from", trader.weekStartS },
        { "to", trader.weekEndS },
    })
end

TradeQR.SalePayload = SalePayload
