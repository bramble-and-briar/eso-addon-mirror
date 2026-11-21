-- PlayerMascotHealth2 v2.0.5 - bundled character: "Christmas 2026" (id xmas2026)
-- Same definition the separate pack addon PMH2_Pack_Xmas2026 used, but the files now live inside this addon (packs/xmas2026/).
-- No events, no timers, no API calls: it only appends one definition to PMH2_PackQueue, which PlayerMascotHealth2.lua reads once after login.
-- id "xmas2026" is the key of this character's saved settings. NEVER change it and never reuse it.
-- If the old separate addon PMH2_Pack_Xmas2026 is still installed, its copy is refused as a duplicate id (turn it OFF).

PMH2_PackQueue = PMH2_PackQueue or {}
table.insert(PMH2_PackQueue, {
    format = 1,
    id = "xmas2026",
    name = "Christmas 2026",
    sortKey = "10",
    dir = "PlayerMascotHealth2/packs/xmas2026/",
    states = {
        NORMAL   = { sheet = "NORMAL_SHEET.dds",   still = "NORMAL.png",   contentBottom = 255 / 256 },
        CAUTION  = { sheet = "CAUTION_SHEET.dds",  still = "CAUTION.png",  contentBottom = 255 / 256 },
        DANGER   = { sheet = "DANGER_SHEET.dds",   still = "DANGER.png",   contentBottom = 255 / 256 },
        CRITICAL = { sheet = "CRITICAL_SHEET.dds", still = "CRITICAL.png", contentBottom = 255 / 256 },
        ZERO     = { sheet = "ZERO_SHEET.dds",     still = "ZERO.png",     contentBottom = 255 / 256 },
    },
})
