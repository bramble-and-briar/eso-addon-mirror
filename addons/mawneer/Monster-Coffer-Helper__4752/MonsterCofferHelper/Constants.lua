local ADDON_NAME = "MonsterCofferHelper"

local MCH = {}
MCH.name = ADDON_NAME
MCH.version = "1.1.0"
_G[ADDON_NAME] = MCH

-- The three Undaunted quartermasters. The ids are LibSets' `undauntedChestId`,
-- which is what its set data keys the vendor stock on.
MCH.VENDOR_GLIRION  = 1
MCH.VENDOR_MAJ      = 2
MCH.VENDOR_URGARLAG = 3
MCH.VENDOR_IDS = { MCH.VENDOR_GLIRION, MCH.VENDOR_MAJ, MCH.VENDOR_URGARLAG }

MCH.VERDICT_MYSTERY = "mystery"
MCH.VERDICT_CURATED = "curated"
MCH.VERDICT_EITHER  = "either"
MCH.VERDICT_DONE    = "done"

MCH.COLOR = {
    head    = "|c9FD3FF",
    good    = "|c66DD66",
    bad     = "|cDD6666",
    warn    = "|cE8C15A",
    dim     = "|c9A9A9A",
    value   = "|cFFFFFF",
    r       = "|r",
}

MCH.defaults = {
    showPanel       = true,
    chatMessage     = true,
    tooltips        = true,
    confirmPurchases = true,
    lockPanel       = false,
    maxSetsListed   = 6,

    useLearnedPrices = true,
    useLearnedPools  = true,
    mysteryCost      = 1,
    curatedCost      = 8,

    -- What store scans read, kept per server (GetWorldName()), because the PTS
    -- can stock sets and prices that live does not have yet:
    -- [server][vendorId] = { setIds = {...}, mysteryCost = n, curatedCost = n, seenAt = timestamp }
    -- MCH.learned points at the current server's table once loaded.
    learnedByServer = {},

    panel = { point = CENTER, relPoint = CENTER, x = 0, y = 0 },
}
