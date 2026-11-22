-- Settings panel (account-wide).

local TFL = TargetFrameLine
local LAM = LibAddonMenu2

function TFL.InitializeSettings()
    local sv = TFL.sv
    local defaults = TFL.defaults

    LAM:RegisterAddonPanel("TargetFrameLine_Panel", {
        type = "panel",
        name = "Target Frame Line",
        author = "Schrodi",
        version = TFL.version,
        registerForDefaults = true,
    })

    LAM:RegisterOptionControls("TargetFrameLine_Panel", {
        {
            type = "description",
            text = "The line above the target's health bar, for players:\n"
                .. "name [Alliance War rank] [class] [champion icon]level\n"
                .. "Champion points are shown in veterancy zones too, instead of the veterancy rank.",
        },
        {
            type = "checkbox",
            name = "Hide target marker in the target frame",
            tooltip = "Removes the target marker icon (the symbol a group member can put over someone's head) from the name in this frame, for players and NPCs alike. "
                .. "Where the markers show in the world is set in the game: Settings -> Nameplates -> Target Markers (over heads) and Settings -> Interface -> Compass Target Markers.",
            getFunc = function() return sv.hideTargetMarker end,
            setFunc = function(value) sv.hideTargetMarker = value; TFL.Refresh() end,
            default = defaults.hideTargetMarker,
        },
        {
            type = "checkbox",
            name = "Champion icon before champion points",
            getFunc = function() return sv.showChampionIcon end,
            setFunc = function(value) sv.showChampionIcon = value; TFL.Refresh() end,
            default = defaults.showChampionIcon,
        },
        {
            type = "checkbox",
            name = "Overland difficulty icon after the name",
            tooltip = "The icon the game shows when the player has picked a harder overland difficulty.",
            getFunc = function() return sv.showDifficultyIcon end,
            setFunc = function(value) sv.showDifficultyIcon = value; TFL.Refresh() end,
            default = defaults.showDifficultyIcon,
        },
        {
            type = "slider",
            name = "Class and rank icon size (% of text height)",
            min = 80,
            max = 200,
            step = 5,
            getFunc = function() return sv.iconSize end,
            setFunc = function(value) sv.iconSize = value; TFL.Refresh() end,
            default = defaults.iconSize,
        },
    })
end
