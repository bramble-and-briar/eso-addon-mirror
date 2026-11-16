-- PatchBanditsUI4SelectDangeons Localization: English (Default)

local strings = {
    SI_PATCHBUI_UNCOMPLETED_BUTTON      = "Uncompleted",
    SI_PATCHBUI_PLEDGES_BUTTON          = "Active Pledges",
    SI_PATCHBUI_DIFF_NORMAL             = "Normal",
    SI_PATCHBUI_DIFF_VETERAN            = "Veteran",
    SI_PATCHBUI_UNCOMPLETED_TOOLTIP     = "Select only accessible dungeons with uncompleted quests.\nDifficulty: <<1>> (matches Group settings).\nAvailable: <<2>>.",
    SI_PATCHBUI_PLEDGES_TOOLTIP         = "Select dungeons with active Undaunted pledges.\nDifficulty: <<1>> (matches Group settings).\nAvailable: <<2>>.",
    SI_PATCHBUI_UNCOMPLETED_SELECTED    = "Selected uncompleted dungeon quests: <<1>> (<<2>>)",
    SI_PATCHBUI_UNCOMPLETED_NONE        = "All accessible dungeon quests are already completed! (<<1>>)",
    SI_PATCHBUI_PLEDGES_SELECTED        = "Selected active Undaunted pledges: <<1>> (<<2>>)",
    SI_PATCHBUI_PLEDGES_NONE            = "No active Undaunted pledges found for <<1>> difficulty.",
}

for stringId, stringValue in pairs(strings) do
    ZO_CreateStringId(stringId, stringValue)
    SafeAddString(_G[stringId], stringValue, 1)
end
