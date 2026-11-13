-- locales/en.lua
ZoneAchievements = ZoneAchievements or {}
ZoneAchievements.L = ZoneAchievements.L or {}

local enStrings = {
    lockedZone = "Locked Zone",
    unknown = "Unknown",
    recentTag = "  |cFFD700[NEW]|r",
    completed = "|c00FF00Achievement Completed!|r",
    progress = "Progress: |cFFFF00%d / %d|r",
    testTitle = "|c39DB92[ZA-Test] Drag Me!|r",
    dragMe = "Hold Left Mouse Button to drag",
    -- Tabs and History
    tabZone = "Zone",
    tabHistory = "History",
    historyTitle = "Activity History (24h)",
    justNow = "Just now",
    minutesAgo = "%d m ago",
    hoursAgo = "%d h ago",
    -- Special Challenges and Dividers
    specialHeader = "——— Major Challenges ———",
    otherHeader = "——— Other Achievements ———",
    vetHeader = "——— Veteran Mode ———",
    vetKeywords = { "veteran" },
    tagVet = "|c9370DB[VET]|r ",
    tagSpeed = "|c00FFFF[SPEED]|r ",
    tagNoDeath = "|cE6E6FA[NO-DEATH]|r ",
    tagHM = "|cFF4500[HM]|r ",
    tagTrifecta = "|cFFD700[TRIFECTA]|r ",
    tagMisfortune1 = "|cFFD700[1 MISFORTUNE]|r ",
    tagMisfortune2 = "|cFF8C00[2 MISFORTUNES]|r ",
    tagMisfortune3 = "|cFF0000[3 MISFORTUNES]|r ",
    menuSetVet = "Tag as: [Vet]",
    menuSetSpeed = "Tag as: [Speedrun]",
    menuSetNoDeath = "Tag as: [No-Death]",
    menuSetHM = "Tag as: [HM]",
    menuSetTrifecta = "Tag as: [Trifecta]",
    menuSetMisfortune1 = "Tag as: [1 Misfortune]",
    menuSetMisfortune2 = "Tag as: [2 Misfortunes]",
    menuSetMisfortune3 = "Tag as: [3 Misfortunes]",
    menuClearTag = "Remove special tag",
}

for k, v in pairs(enStrings) do
    ZoneAchievements.L[k] = v
end

ZO_CreateStringId("SI_BINDING_NAME_TOGGLE_ZONEACH_WINDOW", "Toggle ZoneAchievements Window")