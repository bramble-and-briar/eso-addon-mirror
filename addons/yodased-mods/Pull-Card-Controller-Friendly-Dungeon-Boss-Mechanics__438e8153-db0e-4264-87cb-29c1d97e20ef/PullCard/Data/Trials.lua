-- 12-player trials.
-- Trial bosses have too many mechanics for the pop-up card: keep `everyone`
-- to the one or two mechanics that wipe the group. Newer trials have per-boss
-- hard modes; put each on that boss's `extra.hardmode`.

local addDungeon = PullCardData.addDungeon
local addBoss = PullCardData.addBoss
local addShared = PullCardData.addShared

-- Example:
-- addDungeon("Rockgrove", "trial", { group = "Blackwood" })
