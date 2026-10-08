-- DLC and chapter 4-player dungeons.
-- Group each dungeon under its DLC with opts.group; it is shown in the menu label.
-- Hard modes are usually final-boss only: put them on that boss's `extra.hardmode`.

local addDungeon = PullCardData.addDungeon
local addBoss = PullCardData.addBoss
local addShared = PullCardData.addShared

-- Example:
-- addDungeon("Fang Lair", "dlc", { group = "Wolfhunter" })
-- addBoss("Boss Name", "Fang Lair", "Boss Name", {"Alias"},
--     "summary", "everyone", "tank", "healer", "dps", "[Boss] tldr",
--     {
--         hardmode = "What changes in hard mode.",
--         challenges = { { name = "Achievement", text = "Condition." } },
--     })
