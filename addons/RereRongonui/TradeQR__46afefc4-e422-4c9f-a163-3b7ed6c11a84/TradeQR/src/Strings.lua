-- User-facing strings (Italian for now; the game client has no Italian locale,
-- so these are not localized through the client language).
local strings = {
    TRADEQR_SCREEN_TITLE = "Vendita completata",
    TRADEQR_COUNTER = "<<1>> di <<2>>",
    TRADEQR_LABEL_GUILD = "Gilda",
    TRADEQR_LABEL_ITEM = "Oggetto",
    TRADEQR_LABEL_QUANTITY = "Quantità",
    TRADEQR_LABEL_PRICE = "Prezzo",
    TRADEQR_LABEL_BUYER = "Acquirente",
    TRADEQR_LABEL_DATE = "Data",
    TRADEQR_HINT = "Inquadra il QR code con il telefono, poi premi \"Registrata\".",
    TRADEQR_KEYBIND_DONE = "Registrata",
    TRADEQR_KEYBIND_SKIP = "Salta",
    TRADEQR_KEYBIND_LATER = "Più tardi",
    TRADEQR_CHAT_NEW_SALES = "TradeQR: <<1>> nuove vendite da registrare.",
    TRADEQR_CHAT_NOTHING_PENDING = "TradeQR: nessuna vendita da registrare.",
    TRADEQR_CHAT_QR_ERROR = "TradeQR: impossibile generare il QR code (<<1>>).",
}

for stringId, text in pairs(strings) do
    ZO_CreateStringId(stringId, text)
end
