-- Global namespace shared by every TradeQR file.
-- Loaded first (after the vendored QR encoder), so other files can attach classes to it.
TradeQR = {
    name = "TradeQR",
    savedVariablesName = "TradeQR_SavedVariables",
    savedVariablesVersion = 1,

    -- Payload format version, bump it when the JSON shape changes (the phone app reads it).
    -- v2: "type" field ("sale" | "listing") and listing payloads.
    -- v3: "gid" (numeric guild id) on sales and listings; "uid", "char", "loc" on listings; "trader" payloads.
    payloadVersion = 3,

    -- Queue record kinds. Records saved by 0.2.x have no kind: they are sales.
    RECORD_KIND_SALE = "sale",
    RECORD_KIND_LISTING = "listing",
    RECORD_KIND_TRADER = "trader",

    defaults = {
        -- Only sales where the current account is the seller.
        onlyMySales = true,
        -- Every scan re-reads this much recent history from the local cache (seen ids prevent duplicates),
        -- so sales that reach the client late are still found. Must stay well below seenRetentionSeconds.
        scanWindowSeconds = 48 * 60 * 60,
        -- Seen event ids are forgotten after this long (keeps SavedVariables small on console).
        seenRetentionSeconds = 30 * 24 * 60 * 60,
        -- "Later" button: how long the screen stays quiet.
        snoozeSeconds = 15 * 60,

        pendingSales = {},
        seenEventIds = {},
        -- Last sequence number used to build listing ids.
        listingSequence = 0,
    },

    pollIntervalMs = 5 * 60 * 1000,
    -- An unfinished (queued) history request is recreated only after this long.
    maxRequestAgeSeconds = 30 * 60,
    autoShowCheckIntervalMs = 15 * 1000,
}
