-- Lethal PVP Insights - classify what an enemy hit you with
-- Categories (display order): Weapon, Skill, Passive Skill, Ultimate, Synergy, Proc Set,
-- Weapon Glyph, Weapon Poison, CP Damage, Damage Effect.
-- Pure buffs/debuffs (Minor/Major X, Off Balance, Taunt...) are hidden.
-- The game doesn't label set procs, so this combines several signals; a right-click on a row
-- lets you correct the category and the addon remembers it.
local PDI = PVPDataInsight
local Skills = {}
PDI.Skills = Skills

Skills.ORDER = { weapon = 1, skill = 2, passive = 3, ultimate = 4, synergy = 5, set = 6,
                 glyph = 7, poison = 8, cp = 9, mythic = 10, food = 11, xpfood = 12, buff = 13, effect = 14, hidden = 99 }
Skills.LABEL = {
    weapon = "|cC5C29EWeapon|r", skill = "|c66CCFFSkill|r", passive = "|c88AADDPassive Skill|r",
    ultimate = "|cFFAA33Ultimate|r", synergy = "|cFF88CCSynergy|r", set = "|cA0FFA0Proc Set|r",
    glyph = "|cDDDD66Weapon Glyph|r", poison = "|c88DD88Weapon Poison|r", cp = "|cFFCC99CP Damage|r",
    effect = "|cCCCCCCDamage Effect|r", hidden = "|c777777Hidden|r",
    food = "|cE0B070Food Buff|r", xpfood = "|cD0A0FFXP Buff|r", mythic = "|cFFD24AMythic|r", buff = "|cBBBBBBBuff|r",
}
-- right-click cycles through these ("Hidden" last, so a row can be removed)
Skills.CYCLE = { "skill", "passive", "ultimate", "synergy", "set", "glyph", "poison", "cp", "weapon", "effect", "hidden" }
-- labels that read better for buffs
Skills.BUFF_LABEL = { cp = "|cFFCC99Champion Points|r" }
function Skills:BuffLabel(cat) return self.BUFF_LABEL[cat] or self.LABEL[cat] or cat end
-- buffs on a targeted player (right-click cycle on the Buffs list)
Skills.BUFF_CYCLE = { "skill", "passive", "ultimate", "set", "mythic", "glyph", "cp", "food", "xpfood", "buff", "hidden" }

-- Corrections by name (lower case). Extend as players report them.
local NAME_CAT = {
    -- skills
    ["oblivion's foe"] = "set", ["take flight"] = "ultimate", ["thrive in chaos"] = "ultimate",
    ["scourge harvest"] = "skill", ["ashen grip"] = "skill", ["warding soul"] = "skill", ["magical smash"] = "skill",
    ["spell orb"] = "skill", ["power lash"] = "skill", ["rip and tear execute"] = "skill",
    ["blockade of fire"] = "skill", ["blockade of frost"] = "skill", ["blockade of shock"] = "skill",
    ["blockade of storms"] = "skill", ["blockade of elements"] = "skill",
    -- passive skills
    ["static reverberation"] = "passive", ["burning light"] = "passive", ["wild embers"] = "passive",
    ["wildfire embers"] = "passive", ["forceful"] = "passive", ["soul shatter"] = "passive",
    -- ultimates
    ["eye of flame"] = "ultimate", ["eye of the storm"] = "ultimate", ["eye of storm"] = "ultimate",
    -- Destruction Staff ultimates (Elemental Storm / Elemental Rage and their elemental versions)
    ["elemental storm"] = "ultimate", ["fire storm"] = "ultimate", ["ice storm"] = "ultimate",
    ["thunder storm"] = "ultimate", ["elemental rage"] = "ultimate", ["fiery rage"] = "ultimate",
    ["icy rage"] = "ultimate", ["thunderous rage"] = "ultimate", ["eye of lightning"] = "ultimate",
    ["eye of frost"] = "ultimate",
    ["light attack (power overload)"] = "ultimate", ["heavy attack (power overload)"] = "ultimate",
    ["energy overload"] = "ultimate", ["power overload"] = "ultimate",
    ["light attack (energy overload)"] = "ultimate", ["heavy attack (energy overload)"] = "ultimate",
    -- Soul Strike and its morphs are the only "Soul" ultimates (other "... Soul" names are skills)
    ["soul strike"] = "ultimate", ["shatter soul"] = "ultimate", ["soul assault"] = "ultimate",
    -- synergies
    ["spinal surge"] = "synergy", ["combustion"] = "synergy", ["runebreak"] = "synergy", ["shards"] = "synergy",
    ["blessed shards"] = "synergy", ["holy shards"] = "synergy", ["conduit"] = "synergy", ["ignite"] = "synergy",
    ["radiate"] = "synergy", ["supernova"] = "synergy", ["gravity crush"] = "synergy", ["pure agony"] = "synergy",
    ["grave robber"] = "synergy", ["feeding frenzy"] = "synergy", ["blood funnel"] = "synergy", ["blood feast"] = "synergy",
    ["spawn broodlings"] = "synergy", ["black widows"] = "synergy", ["arachnophobia"] = "synergy", ["shackle"] = "synergy",
    ["hidden refresh"] = "synergy", ["harvest"] = "synergy", ["purify"] = "synergy", ["shackle damage"] = "synergy",
    -- proc sets
    ["plague carrier"] = "set", ["deadlands demolisher"] = "set", ["sliver assault"] = "set",
    ["hrothgar's chill"] = "set", ["orpheon the tactician"] = "set", ["aetheric lance"] = "set",
    ["eagle's mark"] = "set", ["werewolf berserker bleed"] = "set", ["shived"] = "set",
    ["hunter's venom"] = "set", ["wrathful nova"] = "set",
    -- champion point damage
    ["cutting defense"] = "cp", ["occult overload"] = "cp",
    -- weapon glyphs (enchantments)
    ["fiery weapon"] = "glyph", ["frozen weapon"] = "glyph", ["charged weapon"] = "glyph", ["poisoned weapon"] = "glyph",
    ["befouled weapon"] = "glyph", ["befoulded weapon"] = "glyph", ["decrease health"] = "glyph",
    ["prismatic onslaught"] = "glyph", ["absorb health"] = "glyph", ["absorb magicka"] = "glyph",
    ["absorb stamina"] = "glyph", ["life drain"] = "glyph", ["prismatic weapon"] = "glyph",
    -- weapon poisons
    ["ravage health"] = "poison", ["creeping ravage health"] = "poison",
    -- not useful: shields/buffs (possibly from other enemies) and siege
    ["barrier"] = "hidden", ["sphere of influence"] = "hidden", ["hydroglass shield"] = "hidden",
    ["hierophant's shield"] = "hidden", ["bone wall"] = "hidden", ["sorcerer's soul"] = "hidden",
    -- damage effects
    ["bash"] = "effect",
}

-- Name patterns, checked in order
local PATTERNS = {
    { "trebuchet", "hidden" }, { "ballista", "hidden" }, { "catapult", "hidden" }, { "battering ram", "hidden" },
    { "flaming oil", "hidden" }, { "scattershot", "hidden" }, { "siege", "hidden" }, { "cold fire", "hidden" },
    { "shield$", "hidden" }, { "lancer$", "hidden" },   -- Fire / Frost / Lightning Lancer (siege)
    { "^%a+ burst$", "skill" },                 -- Warding/Fiery/Bloody/Magical ... Burst
    { "^blockade of ", "skill" },               -- Blockade of Frost / Fire / Storms (destruction staff)
    { "^%a+ throw$", "skill" },                 -- Chilling / Scorching / Shocking ... Throw
    { "^%a+ smash$", "skill" },                 -- Magical / Dazing / ... Smash
    { "^%a+ knife$", "skill" },
    { "^%a+ pulsar$", "skill" },                -- Frost / Flame / Storm ... Pulsar                 -- Traveling Knife scribing: Shattering / Leeching / ... Knife
    { "^%a+ soul$", "skill" },                  -- Dazing / Shocking / Fiery / Healing ... Soul
    { "^%a+ clench$", "skill" },                -- Frost / Fire / Shock Clench (destruction staff)
    { "^unstable wall of ", "skill" },          -- Unstable Wall of Fire / Frost / Shock
    { "^wall of ", "skill" },                   -- Wall of Fire / Frost / Storms / Elements
    { "^%a+ impulse$", "skill" },               -- Fire / Frost / Shock Impulse
    { "^%a+ reach$", "skill" },                 -- Fire / Frost / Shock Reach
    { "^%a+ ring$", "skill" },                  -- Fire / Frost / Shock Ring
    { "ravage ", "poison" },                    -- Ravage Health, Creeping Ravage Stamina...
}


-- ===== Buffs on a targeted player only (never used for enemy attacks or the Group tab) =====
local BUFF_NAME_CAT = {
    -- skills
    ["fleetstep wings"] = "skill", ["igneous weapons"] = "skill", ["ingneous weapons"] = "skill",
    ["medium armor evasion"] = "skill", ["hurricane"] = "skill", ["crystal fragments"] = "skill",
    ["bound armaments"] = "skill", ["spell orb"] = "skill", ["molten whip"] = "skill", ["critical surge"] = "skill",
    ["resolving vigor"] = "skill", ["scourge harvest"] = "skill",
    ["take flight"] = "ultimate", ["thrive in chaos"] = "ultimate", ["oblivion's foe"] = "set",
    -- passive skills
    ["landslide"] = "passive", ["hawk eye"] = "passive", ["font of power"] = "passive", ["exploitation"] = "passive",
    ["blood magic"] = "passive", ["calculated defense"] = "passive", ["sunsphere"] = "passive",
    ["draconic scales"] = "passive",
    -- sets
    ["rallying cry"] = "set", ["twice-fanged serpent"] = "set",
    ["aetheric light"] = "set", ["aetheric lancer"] = "set",
    ["black gemsplitter"] = "set", ["black gem monstrosity"] = "set",
    ["death dealer's fete"] = "mythic", ["escalating fete"] = "mythic",
    -- glyphs
    ["weapon damage"] = "glyph",
    -- not worth listing (mounts, sprinting, immunities, buffs other players may have given them)
    ["gallop"] = "hidden", ["continuous attack"] = "hidden", ["dodge fatigue"] = "hidden",
    ["increase detection"] = "hidden", ["winded"] = "hidden", ["void shackles"] = "hidden",
    -- often cast on them by someone else (shown with a *)
    ["radiating regeneration"] = "skill", ["echoing vigor"] = "skill", ["healing burst"] = "buff",
    ["crux"] = "hidden", ["empower"] = "hidden", ["sunderer"] = "hidden", ["ozezan's plating"] = "hidden",
    -- food and drink
    ["bewitched sugar skulls"] = "food", ["jewels of misrule"] = "food", ["orzorga's smoked bear haunch"] = "food",
    ["orzorga's tripe trifle pocket"] = "food", ["orzorga's blood price pie"] = "food", ["orzorga's red frothgar"] = "food",
    ["witchmother's potent brew"] = "food", ["witchmother's party punch"] = "food", ["artaeum takeaway broth"] = "food",
    ["artaeum pickled fish bowl"] = "food", ["dubious camoran throne"] = "food", ["clockwork citrus filet"] = "food",
    ["pack leader's bone broth"] = "food", ["lava foot soup-and-saltrice"] = "food", ["candied jester's coins"] = "food",
    ["ghastly eye bowl"] = "food", ["crown fortifying meal"] = "food", ["crown refreshing drink"] = "food",
    ["crown vigorous ragout"] = "food", ["crown combat mystic's stew"] = "food", ["crown stout magic liqueur"] = "food",
    ["smoked bear haunch"] = "food", ["sweet sanguine apples"] = "food", ["bowl of \"peeled eyeballs\""] = "food",
    ["purple monkey"] = "food", ["mythic aetherial ambrosia"] = "food", ["aetherial ambrosia"] = "food",
    ["deregulated mushroom stew"] = "food", ["hearty garlic corn chowder"] = "food", ["dragon's blood"] = "food",
    ["spring-loaded infusion"] = "food", ["old aldmeri orphan gruel"] = "food", ["rumbling sweet roll"] = "food",
}
-- Every skill and buff name recorded so far, checked once (game data + your corrections + ESO skill/set/CP
-- lists). Used before any guessing; the hand-written lists above still win.
local AUDIT_SKILL_CAT = {
    ["absorb magicka"] = "glyph", ["absorb stamina"] = "glyph", ["absorption field"] = "hidden",
    ["acid spray"] = "skill", ["aetheric lance"] = "set", ["agony totem"] = "hidden",
    ["apocryphal inspiration"] = "hidden", ["arctic blast"] = "skill", ["arterial burst"] = "skill",
    ["aurora javelin"] = "skill", ["avid boneyard"] = "skill", ["bash"] = "effect", ["bash stun"] = "hidden",
    ["beckoning armor"] = "hidden", ["befouled weapon"] = "glyph", ["behemoth's vulnerability"] = "hidden",
    ["binding burst"] = "skill", ["binding javelin"] = "skill", ["bite of winter"] = "hidden",
    ["biting jabs"] = "skill", ["black gem monstrosity"] = "set", ["blessing of restoration"] = "hidden",
    ["blockade of frost"] = "skill", ["blockade of storms"] = "skill", ["blood of the elder dragon"] = "hidden",
    ["bloodclaws"] = "skill", ["bloody contingency"] = "skill", ["bloody soul"] = "skill", ["bombard"] = "skill",
    ["bone"] = "hidden", ["bone surge"] = "hidden", ["bone wall"] = "hidden", ["bound armaments"] = "skill",
    ["boundless storm"] = "skill", ["brands of imperium"] = "hidden", ["brawler"] = "skill",
    ["breath of life"] = "hidden", ["bright harbinger"] = "hidden", ["budding seeds"] = "hidden",
    ["burning"] = "effect", ["burning embers"] = "skill", ["burning light"] = "passive", ["burning talons"] = "skill",
    ["calculated defense"] = "hidden", ["caltrops"] = "skill", ["charged weapon"] = "glyph", ["chill"] = "effect",
    ["chilled"] = "effect", ["chilling burst"] = "skill", ["chilling contingency"] = "skill",
    ["chilling explosion"] = "skill", ["chilling knife"] = "skill", ["chilling soul"] = "skill",
    ["cold harbor ballista bolt"] = "hidden", ["combat physician"] = "hidden", ["combat prayer"] = "hidden",
    ["concealed weapon"] = "skill", ["concentrated barrier"] = "hidden", ["concussion"] = "effect",
    ["corpseburster"] = "set", ["corrosive armor"] = "ultimate", ["creeping ravage health"] = "poison",
    ["crescent sweep"] = "ultimate", ["crippling grasp"] = "skill", ["critical rush"] = "skill",
    ["crusher"] = "hidden", ["crushing shock"] = "skill", ["crystal fragments"] = "skill",
    ["crystal weapon"] = "skill", ["crystallized slab"] = "skill", ["cutthroat's mockery"] = "hidden",
    ["cutting defense"] = "cp", ["daedric prey"] = "skill", ["dark convergence"] = "set",
    ["dawnbreaker of smiting"] = "ultimate", ["dazing knife"] = "skill", ["dazing smash"] = "skill",
    ["dazing soul"] = "skill", ["decrease health"] = "glyph", ["deep fissure"] = "skill", ["deep slash"] = "skill",
    ["defensive rune"] = "hidden", ["detonating siphon"] = "skill", ["diseased"] = "effect",
    ["disintegrating dragonfire"] = "skill", ["drain health"] = "effect", ["drain magicka"] = "hidden",
    ["drain stamina"] = "hidden", ["eagle's mark"] = "set", ["echoing vigor"] = "hidden",
    ["elemental susceptibility"] = "hidden", ["endless fury"] = "skill", ["energy orb"] = "hidden",
    ["engulfing dragonfire"] = "skill", ["erudite's rigor"] = "hidden", ["essence drain"] = "hidden",
    ["essence thief"] = "hidden", ["executioner"] = "skill", ["exploitation"] = "hidden",
    ["extended ritual"] = "hidden", ["fasalla's guile"] = "hidden", ["feral pounce"] = "skill",
    ["ferocious leap"] = "ultimate", ["fiery burst"] = "skill", ["fiery explosion"] = "skill",
    ["fiery soul"] = "skill", ["fiery weapon"] = "glyph", ["fire ballista bolt"] = "hidden",
    ["flame clench"] = "skill", ["flame lash"] = "skill", ["flaming oil"] = "hidden", ["fleetstep wings"] = "hidden",
    ["focused aim"] = "skill", ["force pulse"] = "skill", ["forceful"] = "passive", ["fortifying banner"] = "hidden",
    ["fossilize"] = "hidden", ["fragmented shield"] = "hidden", ["from the brink"] = "cp",
    ["frost lancer"] = "hidden", ["frost pulsar"] = "skill", ["frost reach"] = "skill",
    ["frost safeguard"] = "hidden", ["frozen weapon"] = "glyph", ["gibbering shelter"] = "hidden",
    ["gorethief"] = "set", ["green lotus"] = "hidden", ["harvest"] = "synergy", ["haunting curse"] = "skill",
    ["healing burst"] = "skill", ["healing combustion"] = "hidden", ["healing contingency"] = "hidden",
    ["healing soul"] = "skill", ["healing springs"] = "hidden", ["healing thicket"] = "hidden",
    ["healing ward"] = "hidden", ["heart of flame"] = "skill", ["hearth and home"] = "hidden",
    ["heavy attack (bow)"] = "weapon", ["heavy attack (dual wield)"] = "weapon", ["heavy attack (ice)"] = "weapon",
    ["heavy attack (lightning)"] = "weapon", ["heavy attack (one handed)"] = "weapon",
    ["heavy attack (restoration)"] = "weapon", ["heavy attack (two handed)"] = "weapon", ["hemorrhaging"] = "effect",
    ["hit dummy"] = "hidden", ["honor the dead"] = "hidden", ["hrothgar's chill"] = "set", ["hunter's venom"] = "set",
    ["hurricane"] = "skill", ["hydroglass shield"] = "hidden", ["ice comet"] = "ultimate",
    ["igneous shield"] = "hidden", ["igneous weapons"] = "skill", ["ignite"] = "synergy",
    ["ignite synergy ticker"] = "hidden", ["illuminate"] = "hidden", ["illustrious healing"] = "hidden",
    ["immobilize"] = "hidden", ["immobilize immunity"] = "hidden", ["impale"] = "skill",
    ["impervious runeward"] = "skill", ["incapacitating strike"] = "ultimate", ["incinerate"] = "skill",
    ["killer's blade"] = "skill", ["leashing burst"] = "skill", ["leashing knife"] = "skill",
    ["leeching plate"] = "set", ["leeching vines"] = "hidden", ["life drain"] = "glyph", ["life giver"] = "hidden",
    ["light attack (bow)"] = "weapon", ["light attack (dual wield)"] = "weapon",
    ["light attack (energy overload)"] = "ultimate", ["light attack (ice)"] = "weapon",
    ["light attack (inferno)"] = "weapon", ["light attack (lightning)"] = "weapon",
    ["light attack (one handed)"] = "weapon", ["light attack (power overload)"] = "ultimate",
    ["light attack (restoration)"] = "weapon", ["light attack (two handed)"] = "weapon",
    ["lightning ballista bolt"] = "hidden", ["living dark"] = "hidden", ["lucent echoes"] = "hidden",
    ["maarselok"] = "set", ["mages' wrath"] = "skill", ["magical explosion"] = "skill", ["magical smash"] = "skill",
    ["magical soul"] = "skill", ["magma incarnate"] = "hidden", ["magma shell"] = "ultimate",
    ["magnum shot"] = "skill", ["malady"] = "hidden", ["mark of hircine"] = "hidden", ["meatbag catapult"] = "hidden",
    ["merciless resolve"] = "skill", ["molten whip"] = "skill", ["mortal coil"] = "hidden",
    ["mountain giant"] = "hidden", ["mystic siphon"] = "skill", ["northern storm"] = "ultimate",
    ["oblivion's foe"] = "set", ["off balance"] = "hidden", ["off balance exploit"] = "hidden",
    ["oil catapult"] = "hidden", ["onslaught"] = "ultimate", ["orpheon the tactician"] = "set",
    ["overcharged"] = "effect", ["ozezan's plating"] = "hidden", ["permafrost"] = "ultimate",
    ["pestilent burst"] = "skill", ["pestilent colossus"] = "ultimate", ["pestilent soul"] = "skill",
    ["petrify"] = "hidden", ["piercing mark"] = "hidden", ["plague carrier"] = "set", ["plague infected"] = "effect",
    ["plague slinger"] = "set", ["plaguebreak"] = "hidden", ["poison injection"] = "skill", ["poisoned"] = "effect",
    ["poisoned weapon"] = "glyph", ["polar wind"] = "hidden", ["power extraction"] = "skill",
    ["power lash"] = "skill", ["power of the light"] = "skill", ["power surge"] = "hidden",
    ["powerful assault"] = "hidden", ["practiced incantation"] = "hidden", ["prayer shawl"] = "hidden",
    ["propelling shield"] = "hidden", ["proximity detonation"] = "skill", ["pummeling goliath bash"] = "ultimate",
    ["puncturing sweep"] = "skill", ["purify"] = "synergy", ["purifying light"] = "skill", ["pyrebrand"] = "set",
    ["pyreburst"] = "effect", ["quick cloak"] = "skill", ["radiant oppression"] = "skill",
    ["radiating regeneration"] = "hidden", ["rallying cry"] = "hidden", ["rapid regeneration"] = "hidden",
    ["ravage health"] = "poison", ["refreshing path"] = "hidden", ["relentless focus"] = "skill",
    ["rending slashes"] = "skill", ["repentance"] = "hidden", ["resurrect trigger"] = "hidden",
    ["reviving barrier"] = "hidden", ["reviving barrier heal"] = "hidden", ["ricochet skull"] = "skill",
    ["ritual of rebirth"] = "hidden", ["robes of transmutation"] = "hidden", ["rune power"] = "hidden",
    ["runeguard of still waters"] = "hidden", ["rush of agony"] = "set", ["salve of renewal"] = "hidden",
    ["searing claw"] = "skill", ["sellistrix"] = "set", ["shattering knife"] = "skill",
    ["shattering rocks"] = "hidden", ["shattering spines"] = "skill", ["shattering throw"] = "skill",
    ["shatterspike mantle"] = "skill", ["shifting standard"] = "ultimate", ["shived"] = "set",
    ["shocking explosion"] = "skill", ["shocking soul"] = "skill", ["shooting star"] = "ultimate",
    ["siege shield"] = "hidden", ["siege weapon shield"] = "hidden", ["silver shards"] = "skill",
    ["sliver assault"] = "set", ["sload's semblance"] = "set", ["solar barrage"] = "skill",
    ["sorcerer's soul"] = "hidden", ["soul of flame"] = "skill", ["soul shatter"] = "passive",
    ["soul splitting trap"] = "skill", ["soul tether"] = "ultimate", ["sphere of influence"] = "hidden",
    ["spinal surge"] = "synergy", ["spiteward of the lucid mind"] = "skill", ["static reverberation"] = "passive",
    ["streak"] = "skill", ["stun"] = "hidden", ["sturdy"] = "hidden", ["sturdy horn"] = "hidden",
    ["subterranean assault"] = "skill", ["sundered"] = "effect", ["sundering burst"] = "skill",
    ["sundering soul"] = "skill", ["super nova"] = "hidden", ["suppression field"] = "ultimate",
    ["surprise attack"] = "skill", ["swallow soul"] = "skill", ["swarming scion"] = "ultimate",
    ["take flight"] = "ultimate", ["tarnished nightmare"] = "set", ["taunt"] = "hidden", ["the blind"] = "hidden",
    ["thrive in chaos"] = "ultimate", ["tidal chakram"] = "hidden", ["toppling charge"] = "skill",
    ["toxic barrage"] = "ultimate", ["traumatic burns"] = "hidden", ["turn evil"] = "hidden",
    ["unleashed terror"] = "set", ["unnerving boneyard"] = "skill", ["vampire's bane"] = "skill",
    ["venom arrow"] = "skill", ["venom skull"] = "skill", ["vicious death"] = "set", ["ward ally"] = "hidden",
    ["warding burst"] = "skill", ["warding contingency"] = "hidden", ["whirling blades"] = "skill",
    ["wildfire embers"] = "passive", ["winterborn"] = "set", ["wrath of elements"] = "set",
    ["wrecking blow"] = "skill", ["zaan"] = "hidden",
}
local AUDIT_BUFF_CAT = {
    ["absorb missile"] = "skill", ["aerie's call"] = "buff", ["aetherial ambrosia"] = "food",
    ["aetheric lancer"] = "set", ["aetheric light"] = "set", ["aggressive horn"] = "ultimate",
    ["alcaire festival sword-pie"] = "food", ["alliance war skill line scroll"] = "xpfood",
    ["alliance war skill line scroll, grand"] = "xpfood", ["alliance war skill line scroll, major"] = "xpfood",
    ["almalexia's mercy"] = "set", ["arcane engine guardian"] = "set", ["arctic blast"] = "skill",
    ["armor master"] = "set", ["artaeum pickled fish bowl"] = "food", ["artaeum takeaway broth"] = "food",
    ["ball of lightning"] = "skill", ["balorgh"] = "set", ["basalt barrier"] = "buff", ["beautiful corpse"] = "buff",
    ["beckoning armor"] = "skill", ["berserker rage"] = "ultimate", ["berserking warrior"] = "set",
    ["betnikh twice-spiked ale"] = "food", ["bewitched sugar skulls"] = "food", ["binding banner"] = "skill",
    ["bird of prey"] = "skill", ["blazing shield"] = "hidden", ["blessing of war"] = "xpfood",
    ["blighted blastbones"] = "skill", ["blood hunger"] = "buff", ["blood magic"] = "passive",
    ["blood mist"] = "skill", ["blood of the green dragon"] = "skill", ["bloodspawn"] = "set",
    ["blue betty"] = "skill", ["booming voice"] = "passive", ["born from shadow"] = "buff", ["bound aegis"] = "skill",
    ["bound armaments"] = "skill", ["boundless storm"] = "skill", ["brawler"] = "skill", ["briarheart"] = "set",
    ["bright harbinger"] = "passive", ["bull netch"] = "skill", ["butcher's bleed"] = "buff",
    ["calculated defense"] = "passive", ["camouflaged hunter"] = "skill", ["carve"] = "skill",
    ["cauterize"] = "skill", ["chain pull range suppression"] = "hidden", ["channeled focus"] = "skill",
    ["charging banner"] = "skill", ["claw fury"] = "skill", ["clever alchemist"] = "set",
    ["clockwork citrus filet"] = "food", ["colovian war torte"] = "xpfood", ["combat physician"] = "set",
    ["concealed weapon"] = "skill", ["concentrated barrier"] = "passive", ["concentrated force"] = "set",
    ["constitution"] = "passive", ["continuous attack"] = "hidden", ["corrosive armor"] = "ultimate",
    ["corrupting bloody mara"] = "food", ["crescent sweep"] = "ultimate", ["critical surge"] = "skill",
    ["crowd control immunity"] = "hidden", ["crown combat mystic's stew"] = "food",
    ["crown experience scroll"] = "xpfood", ["crown fortifying meal"] = "food", ["crown refreshing drink"] = "food",
    ["crown stout magic liqueur"] = "food", ["crunchy spider skewer"] = "food", ["crushing weapon"] = "skill",
    ["crux"] = "hidden", ["cruxweaver armor"] = "skill", ["crystal fragments"] = "skill",
    ["crystal weapon"] = "skill", ["crystal weaver"] = "hidden", ["crystallized slab"] = "skill",
    ["curse of deadly doom"] = "buff", ["cycle unending"] = "passive", ["damage shield"] = "hidden",
    ["dampen magic"] = "skill", ["dark conversion"] = "skill", ["dark deal"] = "skill", ["darklight"] = "passive",
    ["deaden pain"] = "skill", ["deadly cloak"] = "skill", ["death's favor"] = "buff",
    ["deceptive predator"] = "skill", ["deep fissure"] = "skill", ["defensive banner"] = "skill",
    ["defensive bond"] = "skill", ["defensive rune"] = "skill", ["defensive stance"] = "skill",
    ["defiant smash"] = "skill", ["defiled blast"] = "buff", ["delay"] = "buff", ["destructive impact"] = "set",
    ["detonating siphon"] = "skill", ["dodge fatigue"] = "hidden", ["dragonguard tactics"] = "set",
    ["dragonknight's contingency"] = "skill", ["dragonknight's knife"] = "skill", ["dragonknight's smash"] = "skill",
    ["dubious camoran throne"] = "food", ["earthshield mantle"] = "skill", ["ebon armory"] = "set",
    ["echoing vigor"] = "skill", ["elder scroll of altadoon"] = "hidden", ["elder scroll of chim"] = "hidden",
    ["elder scroll of mnem"] = "hidden", ["elder scroll of ni-mohk"] = "hidden", ["empower"] = "hidden",
    ["enduring rampage"] = "ultimate", ["energy"] = "buff", ["energy overload"] = "ultimate",
    ["engulfing dragonfire"] = "skill", ["enlivening overflow"] = "cp", ["escalating fete"] = "mythic",
    ["esoteric environment greaves"] = "set", ["essence thief"] = "set", ["eternal guardian"] = "ultimate",
    ["everlasting sweep"] = "ultimate", ["evil hunter"] = "skill", ["evolving runemend"] = "skill",
    ["expert evasion cooldown"] = "buff", ["exploitation"] = "passive", ["farstrider's blessing"] = "set",
    ["fate realigned"] = "passive", ["fated fortune"] = "passive", ["feeding frenzy"] = "synergy",
    ["feral guardian"] = "ultimate", ["ferocious leap"] = "ultimate", ["finvir's trinket"] = "buff",
    ["flawless dawnbreaker"] = "ultimate", ["fleetstep wings"] = "skill", ["flesh fortress"] = "passive",
    ["follow up"] = "passive", ["font of power"] = "passive", ["fortified ayleid well"] = "xpfood",
    ["fortifying banner"] = "skill", ["forward momentum"] = "skill", ["fragmented shield"] = "hidden",
    ["from the brink"] = "cp", ["frost safeguard"] = "buff", ["funnel health"] = "skill", ["gallop"] = "hidden",
    ["ghastly eye bowl"] = "food", ["gibbering shelter"] = "ultimate", ["glacial obstinance"] = "passive",
    ["glyphic of the tides"] = "ultimate", ["gold coast experience scroll"] = "xpfood", ["gorethief"] = "set",
    ["grace"] = "passive", ["grand gold coast experience scroll"] = "xpfood", ["grand rejuvenation"] = "set",
    ["grave guardian"] = "set", ["grave lord's sacrifice"] = "skill", ["greater storm atronach"] = "ultimate",
    ["green lotus"] = "skill", ["hardened ward"] = "skill", ["hardening"] = "buff", ["harness magicka"] = "skill",
    ["harnessed quintessence"] = "passive", ["harvest"] = "synergy", ["hawk eye"] = "passive",
    ["healing springs"] = "skill", ["healing thicket"] = "ultimate", ["healing ward"] = "skill",
    ["healthy engine guardian"] = "set", ["heart of flame"] = "skill", ["hircine's rage"] = "skill",
    ["hold the line"] = "buff", ["honor the dead"] = "skill", ["hungry scythe"] = "skill",
    ["hunter's focus"] = "buff", ["huntsman's warmask"] = "set", ["hurricane"] = "skill",
    ["hydroglass shield"] = "hidden", ["igneous shield"] = "hidden", ["igneous weapons"] = "skill",
    ["illuminate"] = "passive", ["immobilize immunity"] = "hidden", ["incinerate"] = "skill",
    ["increase all primary stat recovery"] = "food", ["increase all primary stats"] = "food",
    ["increase detection"] = "hidden", ["increase health recovery"] = "food",
    ["increase magicka & stamina recovery"] = "food", ["increase magicka recovery"] = "food",
    ["increase max health"] = "food", ["increase max health & magicka"] = "food",
    ["increase max health & stamina"] = "food", ["increase max magicka"] = "food", ["increase max stamina"] = "food",
    ["inferno"] = "skill", ["ink-scribe's verve"] = "passive", ["insatiable hunger"] = "passive",
    ["inspired scholarship"] = "skill", ["intensity"] = "buff", ["intensive mender"] = "skill",
    ["invisibility"] = "buff", ["iron flask"] = "set", ["jewels of misrule"] = "food", ["landslide"] = "passive",
    ["lava foot soup-and-saltrice"] = "food", ["leeching strikes"] = "skill", ["leeching vines"] = "skill",
    ["life giver"] = "ultimate", ["light weaver"] = "passive", ["living corpse"] = "buff", ["living dark"] = "skill",
    ["living trellis"] = "skill", ["lotus blossom"] = "skill", ["lycanthropy"] = "passive",
    ["magicka controller"] = "passive", ["magma shell"] = "ultimate", ["maim"] = "buff",
    ["medium armor evasion"] = "skill", ["mending incantation"] = "buff", ["merciless charge"] = "set",
    ["merciless resolve"] = "skill", ["meridia's blessed armor"] = "set", ["meritorious service"] = "set",
    ["mirage"] = "skill", ["molten armaments"] = "skill", ["molten stance"] = "buff", ["molten war torte"] = "xpfood",
    ["mortal coil"] = "skill", ["mystic guard"] = "skill", ["mystic siphon"] = "skill",
    ["mythic aetherial ambrosia"] = "food", ["nature's embrace"] = "skill", ["necromancer's soul"] = "skill",
    ["necrotic potency"] = "skill", ["noble duelist's silks"] = "set", ["northern storm"] = "ultimate",
    ["nothing wasted"] = "passive", ["noxiphilic sanguivoria"] = "passive", ["onslaught"] = "ultimate",
    ["opportunistic contingency"] = "skill", ["oppressive bolts"] = "buff", ["orzorga's blood price pie"] = "food",
    ["orzorga's red frothgar"] = "food", ["orzorga's smoked bear haunch"] = "food",
    ["orzorga's tripe trifle pocket"] = "food", ["overkill"] = "buff", ["ozezan's plating"] = "hidden",
    ["pack leader's bone broth"] = "food", ["pearlescent ward"] = "set", ["permafrost"] = "ultimate",
    ["persistence"] = "passive", ["phantasmal escape"] = "skill", ["physical resistance potion"] = "buff",
    ["pillager's profit"] = "set", ["polar wind"] = "skill", ["power lash"] = "skill",
    ["power overload"] = "ultimate", ["powerful assault"] = "set", ["prayer shawl"] = "set", ["precision"] = "cp",
    ["propelling shield"] = "hidden", ["protect the brood"] = "skill", ["prowl"] = "ultimate",
    ["prowler's recovery"] = "buff", ["prowler's resources"] = "buff", ["prowler's talisman"] = "set",
    ["proximity detonation"] = "skill", ["psijic ambrosia"] = "food", ["purifying bloody mara"] = "food",
    ["quick cloak"] = "skill", ["radial sweep"] = "ultimate", ["radiating regeneration"] = "skill",
    ["rally"] = "skill", ["rallying cry"] = "set", ["rapid regeneration"] = "skill",
    ["recuperative treatise"] = "skill", ["regenerating bastion"] = "passive", ["regenerative ward"] = "skill",
    ["reinforced"] = "cp", ["rejuvenation"] = "cp", ["relentless focus"] = "skill", ["remedying banner"] = "skill",
    ["remedying burst"] = "hidden", ["remedying contingency"] = "skill", ["remedying soul"] = "skill",
    ["replenishing barrier"] = "ultimate", ["resistant flesh"] = "skill", ["resolute defense"] = "passive",
    ["resolving vigor"] = "skill", ["restorative banner"] = "skill", ["restore health"] = "buff",
    ["restore stamina"] = "buff", ["restoring focus"] = "skill", ["reusable parts"] = "passive",
    ["reviving barrier"] = "ultimate", ["ricochet skull"] = "skill", ["ring of the pale order"] = "set",
    ["robes of transmutation"] = "set", ["robust engine guardian"] = "set", ["rune of displacement"] = "skill",
    ["rune power"] = "buff", ["runeguard of still waters"] = "skill", ["runic sunder"] = "skill",
    ["sacred ground"] = "passive", ["sanies lupinus"] = "passive", ["sated frenzy"] = "passive",
    ["scourge harvest"] = "skill", ["seething fury"] = "skill", ["sergeant's focus"] = "set",
    ["serpent's rebuke"] = "mythic", ["seventh legion brute"] = "set", ["shadow of the bloodmoon cooldown"] = "buff",
    ["shadowy disguise"] = "skill", ["shared wards"] = "buff", ["shatterspike mantle"] = "skill",
    ["shielded assault"] = "skill", ["shields of erudition"] = "buff", ["shifting standard"] = "ultimate",
    ["shocking banner"] = "skill", ["shuffle"] = "skill", ["siege shield"] = "hidden",
    ["siege weapon shield"] = "hidden", ["siphoning attacks"] = "skill", ["siphoning strikes"] = "skill",
    ["skeletal arcanist"] = "skill", ["skeletal archer"] = "skill", ["slivers of the null arca"] = "set",
    ["sneak"] = "passive", ["solar barrage"] = "skill", ["soul of flame"] = "skill", ["soul siphon"] = "ultimate",
    ["soul tether"] = "ultimate", ["soulcleaver"] = "set", ["spell orb"] = "skill",
    ["sphere of influence"] = "hidden", ["spinal surge"] = "synergy", ["spirit guardian"] = "skill",
    ["spiteward of the lucid mind"] = "skill", ["spring-loaded infusion"] = "food", ["storm master"] = "set",
    ["storm the heavens"] = "buff", ["strike from the shadows"] = "passive", ["subterranean assault"] = "skill",
    ["sul-xan soulbound"] = "set", ["summon charged atronach"] = "ultimate", ["summon twilight matriarch"] = "skill",
    ["summon twilight tormentor"] = "skill", ["summon unstable clannfear"] = "skill",
    ["summon unstable familiar"] = "skill", ["summon volatile familiar"] = "skill",
    ["summon winged twilight"] = "skill", ["summoner's armor"] = "skill", ["sunderer"] = "hidden",
    ["sunlight"] = "buff", ["sunsphere"] = "passive", ["swallow soul"] = "skill", ["symbiosis"] = "skill",
    ["take flight"] = "ultimate", ["templar's banner"] = "skill", ["templar's smash"] = "skill",
    ["templar's soul"] = "skill", ["tenacious contingency"] = "skill", ["tenacious torch"] = "skill",
    ["the juggernaut"] = "set", ["the saint and the seducer"] = "set", ["thrive in chaos"] = "ultimate",
    ["tidal chakram"] = "skill", ["translocated rubble"] = "passive", ["tri focus"] = "passive",
    ["twice-fanged serpent"] = "set", ["ulfsild's contingency"] = "skill", ["unbreakable fate"] = "skill",
    ["unchained"] = "cp", ["undaunted mettle"] = "passive", ["unnatural movement"] = "passive",
    ["unstable frost shield"] = "hidden", ["unstoppable"] = "skill", ["vampire stage 1"] = "passive",
    ["vampire stage 2"] = "buff", ["vampire stage 3"] = "buff", ["vampire stage 4"] = "buff",
    ["venom skull"] = "skill", ["vitalizing glyphic"] = "ultimate", ["void shackles"] = "hidden",
    ["ward ally"] = "skill", ["warding bond"] = "skill", ["warding burst"] = "hidden",
    ["warding contingency"] = "skill", ["weapon damage"] = "glyph", ["well fed"] = "food",
    ["well fed: magicka regen"] = "food", ["well grounded"] = "buff", ["wild guardian"] = "ultimate",
    ["wind walker"] = "passive", ["winded"] = "hidden", ["witchmother's brew"] = "food",
    ["witchmother's party punch"] = "food", ["witchmother's potent brew"] = "food", ["wretched vitality"] = "set",
    ["xoryn's masterpiece"] = "set", ["zaudrus's ambition"] = "set",
}
for k, v in pairs(AUDIT_SKILL_CAT) do if NAME_CAT[k] == nil then NAME_CAT[k] = v end end
for k, v in pairs(AUDIT_BUFF_CAT) do if BUFF_NAME_CAT[k] == nil then BUFF_NAME_CAT[k] = v end end
-- corrections made by hand after checking in game (win over everything above)
local FIXED_CAT = {
    ["exploitation"] = "passive",
    ["ball of lightning"] = "skill", ["blessing of war"] = "xpfood", ["blue betty"] = "skill",
    ["boundless storm"] = "skill", ["concealed weapon"] = "skill", ["crystal weapon"] = "skill",
    ["crystal weaver"] = "hidden", ["dampen magic"] = "skill", ["dark conversion"] = "skill", ["dark deal"] = "skill",
    ["deceptive predator"] = "skill", ["deep fissure"] = "skill", ["dragon's appetite"] = "set",
    ["enlivening overflow"] = "cp",
    ["ferocious leap"] = "ultimate", ["fortified ayleid well"] = "xpfood", ["grave lord's sacrifice"] = "skill",
    ["magma shell"] = "ultimate", ["onslaught"] = "ultimate", ["persistence"] = "passive",
    ["proximity detonation"] = "skill", ["serpent's rebuke"] = "mythic", ["slivers of the null arca"] = "set",
    ["death dealer's fete"] = "mythic", ["ring of the pale order"] = "mythic", ["sea-serpent's coil"] = "mythic",
    ["feral carnage"] = "skill", ["prowl"] = "buff", ["pack leader"] = "ultimate", ["werewolf berserker"] = "ultimate",
    ["conservation of energy"] = "passive", ["volcanic whip"] = "skill",
    ["unstoppable"] = "skill",
    ["medium armor evasion"] = "hidden",        -- always on while wearing medium armor (not a skill or a choice)
    ["elemental susceptibility"] = "skill",     -- Destruction Staff (seen as Burning + Chilled + Concussion at once)
    ["way of fire"] = "set",
}
for k, v in pairs(FIXED_CAT) do NAME_CAT[k] = v; BUFF_NAME_CAT[k] = v end

local BUFF_PATTERNS = {
    { "immunity$", "hidden" },                  -- Crowd Control Immunity, Immobilize Immunity...
    { "^major ", "hidden" }, { "^minor ", "hidden" },   -- Major/Minor buffs (older records still have them)
    { "^elder scroll of ", "hidden" },          -- Elder Scroll of Altadoon...
    { "%f[%a]ward", "hidden" },                 -- Ward, Warding ... (may come from another player)
    { "burst", "hidden" },                      -- ... Burst shields from other players
    { "torte$", "xpfood" },                     -- Colovian / Molten / White-Gold War Torte
    { "experience scroll", "xpfood" },
    { "^increase max ", "food" },               -- generic food/drink buff names
    { "^increase all primary stats", "food" },
}

-- buffs that may well come from another player (heals over time...): listed with a * after the name
-- Monomyth Reforged (mythic ring): it has no buff of its own; a player with all 3 effects of either
-- set wears it (Minor Timidity + Minor Vitality + Major Protection, or Major Force + Minor Berserk +
-- Minor Vulnerability)
Skills.MONOMYTH_SETS = {
    { "Minor Timidity", "Minor Vitality", "Major Protection" },
    { "Major Force", "Minor Berserk", "Minor Vulnerability" },
}
Skills.MONOMYTH_EFFECTS = {}
for _, set in ipairs(Skills.MONOMYTH_SETS) do for _, n in ipairs(set) do Skills.MONOMYTH_EFFECTS[n] = true end end

-- any of the tables (name -> anything) together hold all 3 effects of one set
function Skills:HasMonomyth(...)
    local have = {}
    for _, t in ipairs({ ... }) do
        if type(t) == "table" then for n in pairs(t) do have[n] = true end end
    end
    for _, set in ipairs(self.MONOMYTH_SETS) do
        if have[set[1]] and have[set[2]] and have[set[3]] then return true end
    end
    return false
end

local BUFF_UNCERTAIN = {
    ["radiating regeneration"] = true, ["echoing vigor"] = true, ["healing burst"] = true,
    -- class mastery passives that also buff group members (seen on players of any class)
    ["calculated defense"] = true, ["sphere of influence"] = true, ["lead from the front"] = true,
    ["share the spoils"] = true, ["bountiful harvest"] = true, ["bright harbinger"] = true,
    ["erudite's rigor"] = true, ["ink-scribe's verve"] = true,
    -- cast by another player too (a group member's buff, or the synergy of another player's ultimate)
    ["chakram of destiny"] = true, ["summon charged atronach"] = true,
}
function Skills:BuffUncertain(name)
    return BUFF_UNCERTAIN[string.lower(zo_strtrim(zo_strformat("<<1>>", name or "")))] == true
end

-- shown under a different (better known) name
local BUFF_RENAME = {
    ["escalating fete"] = "Death Dealer's Fete", ["sliver assault"] = "Slivers of the Null Arca",
    ["seething fury"] = "Molten Whip",
    ["aetheric light"] = "Aetheric Lancer",
    ["black gemsplitter"] = "Black Gem Monstrosity",
    ["eagle's mark"] = "Aerie's Cry",
}

-- Status effects applied by weapon enchants / element damage (ids and names)
local STATUS_EFFECTS = {
    ["chilled"] = true, ["burning"] = true, ["poisoned"] = true, ["sundered"] = true, ["concussion"] = true,
    ["overcharged"] = true, ["diseased"] = true, ["hemorrhaging"] = true, ["bleeding"] = true,
}
local STATUS_IDS = { [21481] = true, [18084] = true, [21929] = true, [148800] = true, [21487] = true,
                     [148797] = true, [21925] = true, [148801] = true }

-- Known set procs whose names don't match the set name (extend as needed)
local KNOWN_SETS = {
    ["sliver assault"] = true, ["hrothgar's chill"] = true, ["orpheon the tactician"] = true,
    ["aetheric lance"] = true,
}
local KNOWN_SKILLS = { ["magical smash"] = true }

local function norm(s)
    s = string.lower(zo_strformat("<<1>>", s or ""))
    s = s:gsub("'s%f[%W]", ""):gsub("[%z\1-\31\33-\47\58-\64\91-\96\123-\127]", ""):gsub("%s+", " ")
    return zo_strtrim(s)
end

-- Lazy table of all item set names (normalised)
local setNames
local function buildSetNames()
    setNames = {}
    if not GetNextItemSetCollectionId or not GetItemSetName then return end
    local id = GetNextItemSetCollectionId(nil)
    local guard = 0
    while id and guard < 5000 do
        local n = GetItemSetName(id)
        if n and n ~= "" then setNames[norm(n)] = true end
        id = GetNextItemSetCollectionId(id)
        guard = guard + 1
    end
    -- plus every set seen on gear (some sets are missing from the collections list)
    for _, n in pairs(PDI.sv and PDI.sv.setNames or {}) do
        if type(n) == "string" and n ~= "" then setNames[norm(n)] = true end
    end
end

local function looksLikeSet(name)
    if not setNames then buildSetNames() end
    local n = norm(name)
    if n == "" then return false end
    if setNames[n] then return true end
    -- proc names are often the set name minus/plus a word ("Aetheric Lance" vs "Aetheric Lancer")
    for sn in pairs(setNames) do
        if #n >= 6 and #sn >= 6 and (sn:find(n, 1, true) == 1 or n:find(sn, 1, true) == 1) then return true end
    end
    return false
end

-- Lazy table of player skill names from every skill line the client knows (weapon, guild, world,
-- Alliance War, class lines...), including morphs: [normalised name] = "skill" | "ultimate"
local skillNames
local passiveNames = {}
local function buildSkillNames()
    skillNames = {}
    passiveNames = {}
    if not GetNumSkillTypes then return end
    for st = 1, GetNumSkillTypes() do
        for line = 1, (GetNumSkillLines(st) or 0) do
            for idx = 1, (GetNumSkillAbilities(st, line) or 0) do
                local name, _, _, passive, ultimate = GetSkillAbilityInfo(st, line, idx)
                if passive then
                    if name and name ~= "" then passiveNames[norm(name)] = true end
                else
                    local cat = ultimate and "ultimate" or "skill"
                    if name and name ~= "" then skillNames[norm(name)] = cat end
                    if GetSpecificSkillAbilityInfo then
                        for morph = 0, 2 do
                            local ok, aid = pcall(GetSpecificSkillAbilityInfo, st, line, idx, morph, 1)
                            if ok and aid and aid ~= 0 then
                                local n = GetAbilityName(aid)
                                if n and n ~= "" then skillNames[norm(n)] = cat end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function costOf(id, flag)
    if not GetAbilityCost or not id or id == 0 or not flag then return 0 end
    local ok, c = pcall(GetAbilityCost, id, flag, nil, "player")
    return (ok and c) or 0
end

-- the skill line's own flags for a skill: "ultimate" / "passive" / nil
local function skillFlags(st, line, idx)
    if not (GetSkillAbilityInfo and st and line and idx) then return nil end
    local ok, _, _, _, passive, ultimate = pcall(GetSkillAbilityInfo, st, line, idx)
    if not ok then return nil end
    if ultimate then return "ultimate" end
    if passive then return "passive" end
    return nil
end

local function skillKeys(id)
    if not GetSpecificSkillAbilityKeysByAbilityId or not id or id == 0 then return nil end
    local ok, skillType, lineIndex, skillIndex = pcall(GetSpecificSkillAbilityKeysByAbilityId, id)
    if ok and skillType and skillType ~= 0 and lineIndex and lineIndex > 0 then return skillType, lineIndex, skillIndex end
    return nil
end

local ULT = COMBAT_MECHANIC_FLAGS_ULTIMATE or POWERTYPE_ULTIMATE
local MAG = COMBAT_MECHANIC_FLAGS_MAGICKA or POWERTYPE_MAGICKA
local STA = COMBAT_MECHANIC_FLAGS_STAMINA or POWERTYPE_STAMINA

-- sk = stored skill record { n=name, id=abilityId, ty={dmg=,dot=,kb=,eff=,cc=,heal=} }
function Skills:Classify(sk)
    local name = sk.n or ""
    local key = string.lower(name)
    -- the checked corrections (FIXED_CAT) win even over an older right-click choice
    local fixed = FIXED_CAT[string.lower(zo_strtrim(zo_strformat("<<1>>", name)))]
    if fixed then return fixed end
    local override = PDI.sv and PDI.sv.skillCat and PDI.sv.skillCat[key]
    if override then return override end
    -- match on the clean name (no grammar suffix, no stray spaces)
    key = string.lower(zo_strtrim(zo_strformat("<<1>>", name)))

    if NAME_CAT[key] then return NAME_CAT[key] end
    for _, p in ipairs(PATTERNS) do
        if key:find(p[1]) then return p[2] end
    end

    local ty = sk.ty or {}
    if not (ty.dmg or ty.dot or ty.kb) then return "hidden" end          -- buffs, debuffs, taunt, off balance, snares
    if key:find("^light attack") or key:find("^heavy attack") or key:find("^medium attack") then
        return "weapon"
    end
    if STATUS_EFFECTS[key] or STATUS_IDS[sk.id or 0] then return "effect" end
    if KNOWN_SETS[key] then return "set" end
    if KNOWN_SKILLS[key] then return "skill" end

    if not skillNames then buildSkillNames() end
    local known = skillNames[norm(name)]
    if known then return known end

    local id = sk.id
    if costOf(id, ULT) > 0 then return "ultimate" end
    local st, line, idx = skillKeys(id)
    local isSkill = st ~= nil or costOf(id, MAG) > 0 or costOf(id, STA) > 0
    if not isSkill and GetAbilityProgressionXPInfoFromAbilityId then
        local ok, hasProg = pcall(GetAbilityProgressionXPInfoFromAbilityId, id)
        isSkill = ok and hasProg or false
    end
    if looksLikeSet(name) then return "set" end
    if isSkill then
        local flag = st and skillFlags(st, line, idx)
        if flag then return flag end
        return "skill"
    end
    return "effect"
end

-- Buffs seen on a targeted player (friend or foe): buff-only lists first, then the same lookups as
-- an enemy's skills. perm = the buff has no duration. Returns category, display name.
-- Right-click choices are kept apart from the enemy ones (sv.buffCat).
-- Every skill, ultimate, passive and set name the game knows (normalised), for esopvp.com so the
-- website can classify names this addon never classified itself: [name] = "skill"|"ultimate"|"passive"|"set"
function Skills:GameNames()
    if not skillNames then buildSkillNames() end
    if not setNames then buildSetNames() end
    local out = {}
    for n in pairs(setNames or {}) do out[n] = "set" end
    for n in pairs(passiveNames or {}) do out[n] = "passive" end
    for n, cat in pairs(skillNames or {}) do out[n] = cat end
    return out
end

function Skills:BuffName(name)
    local key = string.lower(zo_strtrim(zo_strformat("<<1>>", name or "")))
    return BUFF_RENAME[key] or name
end

-- Class Mastery passives: only a character of that class has them (all 3 of its own lines, no
-- subclassing). Some also buff nearby group members under the same name, so on a player of another
-- class they are that group buff, not his passive.
local MASTERY = {}
for cls, names in pairs({
    [1] = { "inexorable descent", "booming voice", "wildfire embers", "resolute defense", "lead from the front" },
    [2] = { "conservation of energy", "font of power", "static reverberation", "calculated defense", "sphere of influence" },
    [3] = { "nocturnal inspiration", "an eye for exploitation", "above and beyond", "cutthroat's focus", "share the spoils" },
    [4] = { "tundra's maw", "wild adaptation", "glacial obstinance", "green-keeper's hide", "bountiful harvest" },
    [5] = { "nothing wasted", "malevolent promise", "cycle unending", "pound of flesh", "veil's forfeit" },
    [6] = { "bastion of light", "devout guardian", "bright harbinger", "judgment's brand", "steadfast candescence" },
    [117] = { "abyssal emergence", "fate realigned", "unbound potential", "erudite's rigor", "ink-scribe's verve" },
}) do for _, n in ipairs(names) do MASTERY[n] = cls end end
Skills.MASTERY = MASTERY

-- cls (optional) = the class of the player the buff was seen on
function Skills:ClassifyBuff(name, id, perm, cls)
    local cat, shown = self:ClassifyBuffRaw(name, id, perm)
    if cls and cls ~= 0 and cat == "passive" then
        local owner = MASTERY[string.lower(zo_strtrim(zo_strformat("<<1>>", shown or "")))]
        if owner and owner ~= cls then cat = "buff" end      -- a group member's mastery buff
    end
    return cat, shown
end

function Skills:ClassifyBuffRaw(name, id, perm)
    local shown = self:BuffName(name)
    local fixed = FIXED_CAT[string.lower(zo_strtrim(zo_strformat("<<1>>", shown or "")))]
        or FIXED_CAT[string.lower(zo_strtrim(zo_strformat("<<1>>", name or "")))]
    if fixed then return fixed, shown end
    local override = PDI.sv and PDI.sv.buffCat and PDI.sv.buffCat[string.lower(shown or "")]
    if override then return override, shown end
    local key = string.lower(zo_strtrim(zo_strformat("<<1>>", name or "")))
    local skey = string.lower(shown or "")
    if BUFF_NAME_CAT[skey] then return BUFF_NAME_CAT[skey], shown end
    if BUFF_NAME_CAT[key] then return BUFF_NAME_CAT[key], shown end
    for _, p in ipairs(BUFF_PATTERNS) do
        if key:find(p[1]) then return p[2], shown end
    end
    if NAME_CAT[key] then return NAME_CAT[key], shown end
    for _, p in ipairs(PATTERNS) do
        if key:find(p[1]) then return p[2], shown end
    end
    if KNOWN_SETS[key] then return "set", shown end
    if not skillNames then buildSkillNames() end
    local known = skillNames[norm(name)]
    if known then return known, shown end
    if passiveNames[norm(name)] then return "passive", shown end
    local st, line, idx = skillKeys(id)
    if st then return skillFlags(st, line, idx) or "skill", shown end
    if looksLikeSet(name) then return "set", shown end
    if costOf(id, ULT) > 0 then return "ultimate", shown end
    if costOf(id, MAG) > 0 or costOf(id, STA) > 0 then return "skill", shown end
    return perm and "passive" or "buff", shown
end

function Skills:CycleOverride(name, current, cycle, store)
    cycle = cycle or self.CYCLE
    store = store or "skillCat"
    PDI.sv[store] = PDI.sv[store] or {}
    local key = string.lower(name or "")
    local idx = 0
    for i, c in ipairs(cycle) do if c == current then idx = i end end
    local nextCat = cycle[idx % #cycle + 1]
    PDI.sv[store][key] = nextCat
    return nextCat
end

function Skills:ResetOverride(name, store)
    store = store or "skillCat"
    if PDI.sv[store] then PDI.sv[store][string.lower(name or "")] = nil end
end

function Skills:SetOverride(name, cat, store)
    store = store or "skillCat"
    PDI.sv[store] = PDI.sv[store] or {}
    PDI.sv[store][string.lower(name or "")] = cat
end

function Skills:HasOverride(name, store)
    local t = PDI.sv[store or "skillCat"]
    return t ~= nil and t[string.lower(name or "")] ~= nil
end
