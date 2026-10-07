FlobotsBlameGame = FlobotsBlameGame or {}
local this = FlobotsBlameGame

this.constants = {
	PLAYER_BLAME_CHANCE = 0.85, -- chance to blame a group member	
}

this.variables = {	
}

-- Configuration

this.playerReasons = {
    -- Classic Combat & Rotation Mistakes
    "they missed their bar swap timing",
    "their DPS was visually offensive",
    "they stood in the red AOE to finish a heavy attack",
    "they forgot to slot a shield or burst heal",
    "their weave rhythm was out of sync with the universe",
    "they activated their ultimate in the complete wrong direction",
    "they rolled into a wall instead of away",
    "they held the synergy prompt until it expired",
    "they light-attacked during a stack-and-hold phase",
    "they cancelled their execute with a light attack",
    "they hit their backbar burst heal on their frontbar",
    "they ran out of stamina trying to block an unblockable heavy",
    "they dodge-rolled twice and depleted their entire stamina pool",
    "they were heavy attacking with an ice staff",
    "their potion was on cooldown because they used it at 100% health",
    "they spent three whole GCDs trying to weapon swap during lag",
    "they missed the interrupt on a five-second cast animation",
    "they pressed Ultimate instead of Synergy",
    "they mistimed their bash and interrupted their own cast",
    "they forgot to pre-buff before the pull",

    -- Gear, Sets & Build Choices
    "they refuse to run food buffs",
    "their gear pieces were completely broken and at 0% durability",
    "they were wearing PvP gear in a HM trial",
    "they forgot to slot a spamable",
    "their weapon enchants ran out of soul gems three fights ago",
    "they equipped two monster shoulders instead of a helm and shoulder",
    "they forgot to transmute their traits to Divines",
    "they were running a craftable set from 2017",
    "their Mundus Stone was accidentally set to The Shadow on a healer",
    "they had no glyphs applied to their jewelry",
    "they brought a oakensoul build to a two-bar fight",
    "they forgot to re-equip their monster set after a outfit check",
    "they were wearing heavy armor as a light armor DPS",
    "their companion took their set drop and didn't share",
    "they swapped to a speed-running outfit during boss burn",

    -- Pets, Companions & Aggro Mishaps
    "their pet taunted the boss onto the squishies",
    "their Sorcerer twilight matriarch blocked everyone's screen",
    "their companion aggroed the add pack from across the arena",
    "their Warden bear drew agro during a stealth phase",
    "they forgot to set their pet to passive before the mechanic",
    "their blastbones got confused and chased a butterfly",
    "their maw of the infernal daedroth blinded the entire group",

    -- Group Dynamics & Morale
    "their outfit dyes are lowering team morale",
    "they breathed too loud on Discord",
    "they hogged the healer's Combat Prayer",
    "they ran away from the healer to get a self-heal",
    "they dropped their AOE directly behind the group",
    "they stood on top of the tank during a cleave mechanic",
    "they ran the stack-and-spread mechanic directly into the group",
    "they kite-farmed the boss around the outer edge of the room",
    "they took the synergy intended for the tank",
    "they grabbed the portal mechanic without telling anyone",
    "they picked up the runner role and went the wrong way",
    "they dropped their static field directly on top of the group wipe zone",
    "they stole the orb heal meant for the main tank",
    "they were standing in Narnia while the group was stacked",
    "they dropped a meteor on the rest of the raid",

    -- Distractions & Meta Shenanigans
    "they were checking combat metrics mid-mechanic",
    "they were typing in guild chat during the execution phase",
    "they were Alt-Tabbed looking up a log parse",
    "they were inspecting someone else's fashion outfit during the pull",
    "they were busy linked their golden gold coast experience scroll in chat",
    "they were adjusting their AddOn settings mid-fight",
    "they were busy complaining about class nerfs in zone chat",
    "they were checking house furniture prices on the Guild Trader",
    "they were eating real-life food during the execute phase",
    "they were muting Discord to argue with their family",
    "they were taking a screenshot for Instagram during the burn",

    -- Spatial Awareness & Movement Failures
    "they walked off the ledge entirely on their own",
    "they dodged into an environmental hazards grid",
    "they backed up into an unpulled trash pack",
    "they sprinted into the boss before the tank loaded in",
    "they jumped into the lava thinking it was a shortcut",
    "they got turned around and ran deeper into the red zone",
    "they mistimed their jump over the ground wave",
    "they walked into the laser beam while looking backward",
    "they got stuck behind a tiny pebble on the floor",

    -- Resource Management Failures
    "they ran out of Magicka and started hitting the boss with light attacks",
    "they spent all their resources spamming a movement ability",
    "they forgot to heavy attack for resources for three minutes straight",
    "they drank the wrong potion by accident",
    "they converted all their stamina to magicka at the worst possible time",

    -- Hardmode & Trial Specific Goofs
    "they touched the hardmode banner before the strategy explanation was done",
    "they didn't break free from the CC for six whole seconds",
    "they forgot to cleanse at the pool",
    "they brought the bomb mechanic to the stack point",
    "they turned the boss toward the group during a cleave animation",
    "they missed their bash turn on the interrupt rotation",
    "they swapped roles mid-dungeon and forgot to mention it",
    "they used a knockback ability on the stacked adds",
    "they pulled agro because their DPS was slightly higher than their survivability",
    "they picked up the relic and immediately dropped it",

    -- Pure Absurdity
    "their character looked at the boss funny",
    "they lost a roll-off in their mind mid-fight",
    "their emote macro got stuck on /dance",
    "their Khajiit ran out of lives",
    "they tried to parry a mechanic that isn't parryable",
    "they hesitated for 0.1 seconds and paid the ultimate price",
    "they blinked and missed the entire mechanic",
    "they tried to bribe the boss with gold",
    "their luck stat rolled a critical failure"
}

this.externalFactors = {
    {
        name = "my computer",
        reasons = {
            "it decided to install updates during execute",
            "the GPU ran out of emotional bandwidth",
            "frame rate dropped into single digits",
            "input lag ate the dodge roll registration"
        }
    },
    {
        name = "the weather",
        reasons = {
            "a sudden barometric pressure shift disrupted light weaving",
            "solar flares interfered with the Wi-Fi signal",
            "humidity degraded keybind responsiveness",
            "wind resistance slowed down the cast bar"
        }
    },
    {
        name = "Zos",
        reasons = {
            "the server hamster tripped on the wheel again",
            "desync registered a hit from Cyrodiil",
            "block bug struck at the worst possible microsecond",
            "skills failed to cast despite valid resources"
        }
    },
    {
        name = "my ISP",
        reasons = {
            "packet loss intercepted the heal mid-air",
            "ping spiked into four digits",
            "a local squirrel chewed the fiber line",
            "routing went through Coldharbour first"
        }
    },
    {
        name = "the boss",
        reasons = {
            "the boss hitboxes are completely fraudulent",
            "the heavies came out with zero windup animation",
            "it targeted the squishiest player on purpose",
            "the mechanic was clearly untelegraphed"
        }
    }
}
