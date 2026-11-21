-- PlayerMascotHealth2 v2.0.7 - GUEST characters (one definition per guest, files in guests/<id>/)
-- The settings show guests in their own "Guest" dropdown (a guest can be renamed there). Rules (see GUEST_ID_LEDGER.md, not shipped):
--   * id = guest_NNN (digits), lower case. It is the key of the guest's saved settings: NEVER change it and NEVER reuse it for another person.
--   * "guest = true" is what puts a character into the Guest dropdown; the id must start with guest_ or the definition is refused.
--   * sortKey "50-NNN"; the file names below are the same as in packs/ (sheet = 1024x512 DDS, 4x2 cells of 256x256, 8 FPS).
-- No events, no timers, no API calls: it only appends definitions to PMH2_PackQueue, which PlayerMascotHealth2.lua reads once after login.
-- A build for one friend contains only that friend's definition here and only that friend's folder under guests/.

PMH2_PackQueue = PMH2_PackQueue or {}

-- guest_001: "カフカ" (name = the original display name; the user can rename it in the settings)
table.insert(PMH2_PackQueue, {
    format = 1,
    guest = true,
    id = "guest_001",
    name = "カフカ",
    sortKey = "50-001",
    dir = "PlayerMascotHealth2/guests/guest_001/",
    states = {
        NORMAL   = { sheet = "NORMAL_SHEET.dds",   still = "NORMAL.png",   contentBottom = 255 / 256 },
        CAUTION  = { sheet = "CAUTION_SHEET.dds",  still = "CAUTION.png",  contentBottom = 255 / 256 },
        DANGER   = { sheet = "DANGER_SHEET.dds",   still = "DANGER.png",   contentBottom = 255 / 256 },
        CRITICAL = { sheet = "CRITICAL_SHEET.dds", still = "CRITICAL.png", contentBottom = 255 / 256 },
        ZERO     = { sheet = "ZERO_SHEET.dds",     still = "ZERO.png",     contentBottom = 253 / 256 },
    },
})
