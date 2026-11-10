-- Turns a stored sale record into the text encoded in the QR code.
-- The phone app parses this JSON; keep it in sync with the payloadVersion in Namespace.lua.
local SalePayload = ZO_InitializingObject:Subclass()

function SalePayload:Initialize(jsonEncoder)
    self.jsonEncoder = jsonEncoder
end

function SalePayload:Build(sale)
    return self.jsonEncoder:EncodeObject({
        { "src", "TradeQR" },
        { "v", TradeQR.payloadVersion },
        { "id", sale.eventId },
        { "ts", sale.timestamp },
        { "guild", sale.guildName },
        { "item", sale.itemName },
        { "link", sale.itemLink },
        { "qty", sale.quantity },
        { "price", sale.price },
        { "tax", sale.tax },
        { "buyer", sale.buyer },
        { "seller", sale.seller },
    })
end

TradeQR.SalePayload = SalePayload
