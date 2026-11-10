-- Global namespace shared by every TradeQR file.
-- Loaded first (after the vendored QR encoder), so other files can attach classes to it.
TradeQR = {
    name = "TradeQR",
    savedVariablesName = "TradeQR_SavedVariables",
    savedVariablesVersion = 1,

    -- Payload format version, bump it when the JSON shape changes (the phone app reads it).
    payloadVersion = 1,

    defaults = {
        -- Only sales where the current account is the seller.
        onlyMySales = true,
        -- How far back to look the very first time a guild is scanned.
        initialLookbackSeconds = 24 * 60 * 60,
        -- Re-scan overlap, so events that reach the client late are not skipped.
        rescanOverlapSeconds = 10 * 60,
        -- Seen event ids are forgotten after this long (keeps SavedVariables small on console).
        seenRetentionSeconds = 30 * 24 * 60 * 60,
        -- "Later" button: how long the screen stays quiet.
        snoozeSeconds = 15 * 60,

        pendingSales = {},
        seenEventIds = {},
        lastScanTimestampByGuildId = {},
    },

    pollIntervalMs = 5 * 60 * 1000,
    autoShowCheckIntervalMs = 15 * 1000,
}
