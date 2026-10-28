
-- PvP activites (e.g. Rewards for the Worthy, Cyrodiil town quests, Battlegrounds dailies, etc.)

local addon = Unboxer
local class = addon:Namespace("rules.rewards")
local rules = addon.classes.rules
local knownIds
local debug = false
local submenu = GetString(SI_UNBOXER_QUEST_REWARDS)

class.PvP = addon.classes.Rule:Subclass()
function class.PvP:New()
    return addon.classes.Rule.New(
        self, 
        {
            name           = "pvp",
            exampleItemIds = {
                145577, -- [Rewards for the Worthy]
                140252, -- [Battlemaster Rivyn's Reward Box]
            },
            dependencies    = { "excluded2" },
            submenu        = submenu,
            title          = GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKCATEGORIES1),
            knownIds       = knownIds
        })
end

function class.PvP:Match(data)
  
    -- Old Rewards for the Worthy containers
    -- if addon:StringContainsStringIdOrDefault(data.name, SI_UNBOXER_UNKNOWN_ITEM_PATTERN)
       -- and data.quality == ITEM_FUNCTIONAL_QUALITY_ARTIFACT
       -- and data.flavorText == ""
       -- and data.bindType ~= BIND_TYPE_ON_PICKUP
    -- then
        -- return true
    -- end
    
    -- if data.flavorText == "" or data.bindType ~= BIND_TYPE_ON_PICKUP then
        -- return
    -- end
    
    -- if addon:StringContainsStringIdOrDefault(data.name, SI_UNBOXER_CHAMPION_LOWER) -- Champion in name
       -- or addon:StringContainsStringIdOrDefault(data.name, SI_UNBOXER_GLADIATOR_LOWER) -- Gladiator in name
       -- or addon:StringContainsStringIdOrDefault(data.name, SI_UNBOXER_CYRODIIL_LOWER) -- Cyrodiil in name
       -- or addon:StringContainsStringIdOrDefault(data.flavorText, SI_UNBOXER_CITIZENS_LOWER) -- Cyrodiil town rewards
       -- or addon:StringContainsStringIdOrDefault(data.flavorText, SI_UNBOXER_BATTLEGROUND_LOWER) -- Battlegrounds rewards
       -- or addon:StringContainsStringIdOrDefault(data.flavorText, SI_UNBOXER_YOUR_ALLIANCE_LOWER) -- "your alliance" in flavor text
	   -- or addon:StringContainsStringIdOrDefault(data.flavorText, SI_UNBOXER_CYRODIIL_LOWER) -- Cyrodiil in flavor text
    -- then
        -- return true
    -- end
end

knownIds = {
  [119550]=1, -- Vlastarus Reward Container (green)
  [119551]=1, -- Bruma Reward Container (green)
  [119552]=1, -- Cropsford Reward Container (green)
  [119553]=1, -- Cheydinhal Reward Container (green)
  [119554]=1, -- Chorrol Reward Container (green)
  [134619]=1, -- Rewards for the Worthy (blue)
  [135004]=1, -- Cyrodiil Assault Crate
  [135006]=1, -- Cyrodiil Defense Crate
  [135023]=1, -- Champion's Cache (blue)
  [135136]=1, -- Champion's Cache (purple)
  [138812]=1, -- Gladiator's Rucksack (blue)
  [140252]=1, -- Battlemaster Rivyn's Reward Box (purple)
  [140425]=1, -- Champion's Cache (blue)
  [140426]=1, -- Champion's Cache (purple)
  [145577]=1, -- Rewards for the Worthy (blue)
  [147649]=1, -- Champion's Cache (blue)
  [147650]=1, -- Champion's Cache (purple)
  [151941]=1, -- Siegemaster's Coffer (blue)
  [181436]=1, -- Rewards for the Worthy (blue)
  [190009]=1, -- Rewards for the Worthy (blue)
  [184171]=1, -- Rewards for the Worthy (blue)
  [181452]=1, -- Champion's Cache (blue)
  [181453]=1, -- Champion's Cache (purple)
  [199725]=1, -- Battlemaster's Rucksack
  [199726]=1, -- Warmaster's Rucksack
  [199727]=1, -- Scout's Rucksack
  [199728]=1, -- Bounty Hunter's Rucksack
  [208129]=1, -- Scroll Keeper's Rucksack
  [204404]=1, -- Rewards for the Worthy (blue)
  [204405]=1, -- Champion's Cache (blue) 
  [204406]=1, -- Champion's Cache (purple)
  [210866]=1, -- Rewards for the Worthy
  [214239]=1, -- Rewards for the Worthy
  [194353]=1, -- Rewards for the Worthy
  [219651]=1, -- Rewards for the Worthy
  
  -- item sets
  
  [214308]=1,
  [214307]=1,
  [214306]=1,
  [214305]=1,
  [214304]=1,
  [214303]=1,
  [214302]=1,
  [214301]=1,
  [214300]=1,
  [214299]=1,
  
  --[190343]=1, -- Rewards for the Worthy Item Sets (golden)
  
  [212245]=1,
  [212246]=1,
  
[217653]=1,
[184172]=1,
[184173]=1,
[190010]=1,
[190011]=1,
[194354]=1,
[194355]=1,
[204838]=1,
[210867]=1,
[210868]=1,
[214240]=1,
[214241]=1,
[219652]=1,
[219653]=1,
[217607]=1,
[217612]=1,
[217613]=1,
[217614]=1,
[217615]=1,
[217616]=1,
[217618]=1,
[217609]=1,
[188250]=1,
[188130]=1,
[212234]=1, -- Battlemaster's Spoils
[212236]=1, -- Battlemaster's Spoils
[212237]=1, -- Battlemaster's Spoils
[224368]=1, -- Champion's Cache
[224369]=1, -- Champion's Cache
[224367]=1, -- Rewards for the Worthy

[225247]=1, --Veterancy Rewards for the Worthy
[225248]=1, --Veterancy Rewards for the Worthy
[225250]=1, --Alliance Banner Furnishing Coffer

[226942]=1, --Uncommon Ancestral Antiquities Coffer
[226960]=1, --Superior Ancestral Antiquities Coffer
[226961]=1, --Epic Ancestral Antiquities Coffer
[227312]=1, --Sack of Pirate Gold
[227862]=1, --Veterancy Supplemental Rewards
}