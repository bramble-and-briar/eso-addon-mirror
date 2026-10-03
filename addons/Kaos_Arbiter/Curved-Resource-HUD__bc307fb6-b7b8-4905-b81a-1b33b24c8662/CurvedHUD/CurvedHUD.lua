CurvedHUD = CurvedHUD or {}
local CH = CurvedHUD
CH.name, CH.version, CH.updateName, CH.dataVersion = "CurvedHUD", "1.1.3", "CurvedHUD_Update", 2
CH.defaults = {enabled=true,preview=false,showDefaultResources=true,buffVerticalOffset=0,useOutOfCombatOpacity=false,outOfCombatOpacity=.45,scale=1.0,spacing=235,verticalOffset=35,resourceGap=7,barWidth=48,leftTimerOffset=-6,leftTimerSpacing=15,rightTimerOffset=3,rightTimerSpacing=3,fillAlpha=.85,frameAlpha=.48,backgroundAlpha=.24,shieldAlpha=.68,textAlpha=.95,timerFontSize=24,expirationAlerts=false,resourceValueFontSize=27,resourcePercentFontSize=20,majorBuffTracked="None",insideTimerStyle="Thin",outsideTimerStyle="Thick",majorBuffColor="Purple",balanceEnabled=false,balanceSlot="bottomLeftInside",balanceColor="Orange",aegisEnabled=false,aegisSlot="topLeftOutside",aegisColor="Pale Blue",armamentsEnabled=false,armamentsSlot="topRightInside",armamentsColor="Pale Blue",fragmentsEnabled=false,fragmentsPosition="Top",fragmentsScale=.75,surgeEnabled=false,surgeSlot="topRightOutside",surgeColor="Gold",shroudEnabled=false,shroudSlot="bottomRightOutside",shroudColor="Cyan",soulBurstEnabled=false,soulBurstSlot="topRightInside",soulBurstColor="Purple",soulBurstDuration=20,contingencyEnabled=false,contingencySlot="bottomRightInside",contingencyColor="Cyan",contingencyDuration=20,showRaw=true,showPercent=true,showMaximum=false,debug=false,layout="Parallel",staminaInside=true,iconCache={},abilityIdCache={}}
CH.characterKeys = {majorBuffTracked=true,majorBuffColor=true,balanceEnabled=true,balanceSlot=true,balanceColor=true,aegisEnabled=true,aegisSlot=true,aegisColor=true,armamentsEnabled=true,armamentsSlot=true,armamentsColor=true,fragmentsEnabled=true,fragmentsPosition=true,surgeEnabled=true,surgeSlot=true,surgeColor=true,shroudEnabled=true,shroudSlot=true,shroudColor=true,soulBurstEnabled=true,soulBurstSlot=true,soulBurstColor=true,soulBurstDuration=true,contingencyEnabled=true,contingencySlot=true,contingencyColor=true,contingencyDuration=true}
CH.characterDefaults = {majorBuffTracked="None",majorBuffColor="Purple",balanceEnabled=false,balanceSlot="bottomLeftInside",balanceColor="Orange",aegisEnabled=false,aegisSlot="topLeftOutside",aegisColor="Pale Blue",armamentsEnabled=false,armamentsSlot="topRightInside",armamentsColor="Pale Blue",fragmentsEnabled=false,fragmentsPosition="Top",surgeEnabled=false,surgeSlot="topRightOutside",surgeColor="Gold",shroudEnabled=false,shroudSlot="bottomRightOutside",shroudColor="Cyan",soulBurstEnabled=false,soulBurstSlot="topRightInside",soulBurstColor="Purple",soulBurstDuration=20,contingencyEnabled=false,contingencySlot="bottomRightInside",contingencyColor="Cyan",contingencyDuration=20,initialized=false}
CH.defaults.martialKnowledgeStaminaCue=false
CH.defaults.setEffectIconCache={}
CH.defaults.reduceQuestTrackersInCombat=false
CH.defaults.reduceQuestTrackersInInstances=false
CH.defaults.reducedQuestTrackerOpacity=0
CH.characterKeys.martialKnowledgeStaminaCue=true
CH.characterDefaults.martialKnowledgeStaminaCue=false
CH.majorBuffChoices = {"None","Major Resolve","Major Brutality","Major Savagery","Major Expedition","Major Protection","Major Evasion","Major Berserk","Major Force","Major Courage","Major Heroism","Major Vitality","Major Endurance","Major Intellect","Major Fortitude","Major Gallop"}
CH.minorBuffChoices = {"None","Minor Resolve","Minor Brutality","Minor Savagery","Minor Expedition","Minor Protection","Minor Evasion","Minor Berserk","Minor Force","Minor Courage","Minor Heroism","Minor Vitality","Minor Endurance","Minor Intellect","Minor Fortitude","Minor Mending","Minor Toughness","Minor Lifesteal","Minor Magickasteal","Empower"}
CH.colorChoices = {"Purple","Orange","Pale Blue","Blue","Green","Red","Gold","White","Cyan","Pink"}
CH.colors = {Purple={.58,.24,.92},Orange={.88,.35,.18},["Pale Blue"]={.48,.82,1},Blue={.18,.48,1},Green={.18,.82,.30},Red={.92,.18,.18},Gold={1,.72,.15},White={1,1,1},Cyan={.15,.9,.9},Pink={1,.35,.68}}
CH.trackerSlots = {
    topLeftOutside={side="left",vertical="upper",inside=false}, topLeftInside={side="left",vertical="upper",inside=true},
    bottomLeftOutside={side="left",vertical="lower",inside=false}, bottomLeftInside={side="left",vertical="lower",inside=true},
    topRightInside={side="right",vertical="upper",inside=true}, topRightOutside={side="right",vertical="upper",inside=false},
    bottomRightInside={side="right",vertical="lower",inside=true}, bottomRightOutside={side="right",vertical="lower",inside=false},
}
CH.trackerSlotNames = {"Top Left - Outside","Top Left - Inside","Bottom Left - Outside","Bottom Left - Inside","Top Right - Inside","Top Right - Outside","Bottom Right - Inside","Bottom Right - Outside"}
CH.trackerSlotValues = {"topLeftOutside","topLeftInside","bottomLeftOutside","bottomLeftInside","topRightInside","topRightOutside","bottomRightInside","bottomRightOutside"}
CH.cruxQuadrantNames = {"Top Left","Bottom Left","Top Right","Bottom Right"}
CH.cruxQuadrantValues = {"topLeft","bottomLeft","topRight","bottomRight"}
CH.procPositionChoices = {"Top","Right","Bottom","Left","Center"}
CH.standardBuffTrackerDefinitions = {
    {key="resolve",label="Major Buff 1",selectionSetting="majorBuffTracked",slotSetting="majorBuffSlot",colorSetting="majorBuffColor",slot="bottomLeftOutside",color="Purple",choices=CH.majorBuffChoices},
    {key="majorBuff2",label="Major Buff 2",selectionSetting="majorBuff2Tracked",slotSetting="majorBuff2Slot",colorSetting="majorBuff2Color",slot="topLeftOutside",color="Gold",choices=CH.majorBuffChoices},
    {key="minorBuff1",label="Minor Buff 1",selectionSetting="minorBuff1Tracked",slotSetting="minorBuff1Slot",colorSetting="minorBuff1Color",slot="bottomRightInside",color="Pale Blue",choices=CH.minorBuffChoices},
    {key="minorBuff2",label="Minor Buff 2",selectionSetting="minorBuff2Tracked",slotSetting="minorBuff2Slot",colorSetting="minorBuff2Color",slot="topRightInside",color="Green",choices=CH.minorBuffChoices},
}
CH.setTrackerDefinitions = {
    -- DPS
    {category="DPS Sets",key="setRelequen",label="Arms of Relequen",setNames={"arms of relequen","perfected arms of relequen"},slot="topRightOutside",color="Gold",duration=5,displayStacks=true,stackLimit=10,needles={"harmful winds","relequen"}},
    {category="DPS Sets",key="setKinras",label="Kinras's Wrath",setNames={"kinras's wrath"},slot="bottomRightOutside",color="Red",duration=5,displayStacks=true,stackLimit=5,needles={"burning heart","kinras"}},
    {category="DPS Sets",key="setSiroria",label="Mantle of Siroria",setNames={"mantle of siroria","perfected mantle of siroria"},slot="topRightInside",color="Orange",duration=5,displayStacks=true,stackLimit=10,needles={"siren's call","siroria"}},
    {category="DPS Sets",key="setWhorl",label="Whorl of the Depths",setNames={"whorl of the depths","perfected whorl of the depths"},slot="bottomRightInside",color="Cyan",duration=18,cooldown=18,readyMode="cooldown",needles={"whorl of the depths"}},
    {category="DPS Sets",key="setPillar",label="Pillar of Nirn",setNames={"pillar of nirn"},slot="topRightOutside",color="Red",duration=10,cooldown=10,readyMode="cooldown",needles={"pillar of nirn","bleeding pillar"}},
    {category="DPS Sets",key="setMechanicalAcuity",label="Mechanical Acuity",setNames={"mechanical acuity"},slot="bottomRightOutside",color="White",duration=5,cooldown=21,readyMode="cooldown",needles={"mechanical acuity"}},
    {category="DPS Sets",key="setZens",label="Z'en's Redress",setNames={"z'en's redress"},slot="topRightInside",color="Red",duration=20,needles={"touch of z'en","touch of zen","z'en's redress"}},
    {category="DPS Sets",key="setElementalCatalyst",label="Elemental Catalyst",setNames={"elemental catalyst"},slot="bottomRightInside",color="Purple",duration=3,displayStacks=true,stackLimit=3,needles={"flame weakness","frost weakness","shock weakness","elemental catalyst"}},
    {category="DPS Sets",key="setAlkosh",label="Roar of Alkosh",setNames={"roar of alkosh"},slot="topRightOutside",color="Gold",duration=10,needles={"roar of alkosh","alkosh"}},
    {category="DPS Sets",key="setAegisCaller",label="Aegis Caller",setNames={"aegis caller"},slot="bottomRightOutside",color="Gold",duration=11,cooldown=12,readyMode="cooldown",needles={"aegis caller","lesser aegis"}},
    {category="DPS Sets",key="setBurningSpellweave",label="Burning Spellweave",setNames={"burning spellweave"},slot="topRightInside",color="Orange",duration=8,cooldown=12,readyMode="cooldown",needles={"burning spellweave"}},
    {category="DPS Sets",key="setBriarheart",label="Briarheart",setNames={"briarheart"},slot="bottomRightInside",color="Red",duration=10,cooldown=15,readyMode="cooldown",needles={"briarheart"}},
    -- Healer/support
    {category="Healer & Support Sets",key="setPowerfulAssault",label="Powerful Assault",setNames={"powerful assault"},slot="topLeftOutside",color="Gold",duration=15,needles={"powerful assault"}},
    {category="Healer & Support Sets",key="setRoaringOpportunist",label="Roaring Opportunist",setNames={"roaring opportunist","perfected roaring opportunist"},slot="bottomLeftOutside",color="Gold",duration=12,cooldown=22,readyMode="cooldown",needles={"roaring opportunist","major slayer"}},
    {category="Healer & Support Sets",key="setPillagersProfit",label="Pillager's Profit",setNames={"pillager's profit","perfected pillager's profit"},slot="topLeftInside",color="Purple",duration=10,cooldown=45,readyMode="cooldown",needles={"pillager's profit","pillagers profit"}},
    {category="Healer & Support Sets",key="setSpellPowerCure",label="Spell Power Cure",setNames={"spell power cure"},slot="bottomLeftInside",color="Gold",duration=5,needles={"spell power cure","major courage"}},
    {category="Healer & Support Sets",key="setSymphony",label="Symphony of Blades",setNames={"symphony of blades"},slot="topLeftOutside",color="Cyan",duration=6,cooldown=18,readyMode="cooldown",needles={"symphony of blades","meridia's favor","meridias favor"}},
    {category="Healer & Support Sets",key="setJorvulds",label="Jorvuld's Guidance (5-piece)",setNames={"jorvuld's guidance"},slot="bottomLeftOutside",color="Green",passive=true,readyMode="equipped",needles={"jorvuld's guidance"}},
    {category="Healer & Support Sets",key="setOlorime",label="Vestment of Olorime",setNames={"vestment of olorime","perfected vestment of olorime"},slot="topLeftOutside",color="Gold",duration=20,cooldown=10,readyMode="cooldown",needles={"vestment of olorime","major courage","circle of might"}},
    {category="Healer & Support Sets",key="setSaxhleel",label="Saxhleel Champion",setNames={"saxhleel champion","perfected saxhleel champion"},slot="bottomLeftOutside",color="Gold",duration=21,needles={"saxhleel champion","major force"}},
    {category="Healer & Support Sets",key="setMasterArchitect",label="Master Architect",setNames={"master architect"},slot="topLeftInside",color="Gold",duration=12,needles={"master architect","major slayer"}},
    {category="Healer & Support Sets",key="setWarMachine",label="War Machine",setNames={"war machine"},slot="bottomLeftInside",color="Gold",duration=12,needles={"war machine","major slayer"}},
    -- Tank
    {category="Tank Sets",key="setTurningTide",label="Turning Tide",setNames={"turning tide"},requiredPieces=3,slot="topLeftOutside",color="Cyan",duration=15,cooldown=15,readyMode="condition",conditionNeedles={"flowing water"},needles={"turning tide"}},
    {category="Tank Sets",key="setArchdruid",label="Archdruid Devyric",setNames={"archdruid devyric"},slot="bottomLeftOutside",color="Purple",duration=15,cooldown=15,readyMode="cooldown",needles={"archdruid devyric"}},
    {category="Tank Sets",key="setNazaray",label="Nazaray",setNames={"nazaray"},slot="topLeftInside",color="Purple",duration=30,cooldown=30,readyMode="cooldown",needles={"nazaray"}},
    {category="Tank Sets",key="setCrimsonOath",label="Crimson Oath's Rive",setNames={"crimson oath's rive"},slot="bottomLeftInside",color="Red",duration=15,needles={"crimson oath","crimson oath's rive"}},
    {category="Tank Sets",key="setTremorscale",label="Tremorscale",setNames={"tremorscale"},slot="topLeftOutside",color="Orange",duration=15,cooldown=10,readyMode="cooldown",needles={"tremorscale"}},
    {category="Tank Sets",key="setDrakesRush",label="Drake's Rush",setNames={"drake's rush"},slot="bottomLeftOutside",color="Gold",duration=12,cooldown=18,readyMode="cooldown",needles={"drake's rush","major heroism"}},
    {category="Tank Sets",key="setArkasis",label="Arkasis's Genius",setNames={"arkasis's genius"},slot="topLeftInside",color="Purple",duration=30,cooldown=30,readyMode="cooldown",needles={"arkasis's genius","arkasis"}},
    {category="Tank Sets",key="setYolnahkriin",label="Claw of Yolnahkriin",setNames={"claw of yolnahkriin","perfected claw of yolnahkriin"},slot="bottomLeftInside",color="Gold",duration=15,cooldown=8,readyMode="cooldown",needles={"claw of yolnahkriin","minor courage","yolnahkriin"}},
    {category="Tank Sets",key="setEncratis",label="Encratis's Behemoth",setNames={"encratis's behemoth"},slot="topLeftOutside",color="Orange",duration=12,cooldown=15,readyMode="cooldown",needles={"encratis's behemoth","behemoth's aura","behemoths aura"}},
    {category="Tank Sets",key="setRushOfAgony",label="Rush of Agony",setNames={"rush of agony"},slot="bottomLeftOutside",color="Purple",duration=2,cooldown=8,readyMode="cooldown",needles={"rush of agony","call of the pack"}},
    {category="Tank Sets",key="setDarkConvergence",label="Dark Convergence",setNames={"dark convergence"},slot="topLeftInside",color="Purple",duration=4,cooldown=25,readyMode="cooldown",needles={"dark convergence"}},
    -- Arena weapons
    {category="Arena Weapons",key="setVoidBash",label="Void Bash",setNames={"void bash","perfected void bash"},slot="topRightOutside",color="Purple",duration=13,cooldown=13,readyMode="cooldown",needles={"call of the void","void bash"}},
    {category="Arena Weapons",key="setWrathElements",label="Wrath of Elements",setNames={"wrath of elements","perfected wrath of elements"},slot="bottomRightOutside",color="Cyan",duration=10,cooldown=10,readyMode="cooldown",needles={"wrath of elements","elemental tether"}},
    {category="Arena Weapons",key="setSpectralCloak",label="Spectral Cloak",setNames={"spectral cloak","perfected spectral cloak"},slot="topRightInside",color="Purple",duration=2,needles={"spectral cloak"}},
    {category="Arena Weapons",key="setMercilessCharge",label="Merciless Charge",setNames={"merciless charge","perfected merciless charge"},slot="bottomRightInside",color="Red",duration=7,needles={"merciless charge"}},
    -- Infinite Archive class sets
    {category="Infinite Archive Class Sets",key="setBasalt",label="Basalt-Blooded Warrior",setNames={"basalt-blooded warrior"},slot="topLeftOutside",color="Orange",duration=10,needles={"rock stance","molten stance","obsidian stance"}},
    {category="Infinite Archive Class Sets",key="setWrathsun",label="Wrathsun",setNames={"wrathsun"},slot="bottomLeftOutside",color="Gold",duration=10,needles={"wrathsun","sunlight"}},
    {category="Infinite Archive Class Sets",key="setMonolith",label="Monolith of Storms",setNames={"monolith of storms"},slot="topRightOutside",color="Cyan",duration=10,needles={"monolith of storms","monolith"}},
    {category="Infinite Archive Class Sets",key="setSoulcleaver",label="Soulcleaver",setNames={"soulcleaver"},slot="bottomRightOutside",color="Purple",duration=20,needles={"soulcleaver"}},
    {category="Infinite Archive Class Sets",key="setNobility",label="Nobility in Decay",setNames={"nobility in decay"},slot="topLeftInside",color="Green",duration=16,needles={"beautiful corpse","death's favor","deaths favor"}},
    {category="Infinite Archive Class Sets",key="setGardener",label="Gardener of Seasons",setNames={"gardener of seasons"},slot="bottomLeftInside",color="Green",duration=10,needles={"gardener of seasons","herald of spring","harbinger of fall"}},
    {category="Infinite Archive Class Sets",key="setHierophant",label="Reawakened Hierophant",setNames={"reawakened hierophant"},slot="topRightInside",color="Green",duration=10,needles={"reawakened hierophant","hierophant"}},
}
CH.setTrackerCategories={"DPS Sets","Healer & Support Sets","Tank Sets","Arena Weapons","Infinite Archive Class Sets"}
for _,definition in ipairs(CH.standardBuffTrackerDefinitions) do
    if CH.defaults[definition.selectionSetting]==nil then CH.defaults[definition.selectionSetting]="None" end
    CH.defaults[definition.slotSetting]=CH.defaults[definition.slotSetting] or definition.slot
    CH.defaults[definition.colorSetting]=CH.defaults[definition.colorSetting] or definition.color
    CH.characterKeys[definition.selectionSetting]=true; CH.characterKeys[definition.slotSetting]=true; CH.characterKeys[definition.colorSetting]=true
    CH.characterDefaults[definition.selectionSetting]=CH.characterDefaults[definition.selectionSetting] or CH.defaults[definition.selectionSetting]
    CH.characterDefaults[definition.slotSetting]=CH.characterDefaults[definition.slotSetting] or definition.slot
    CH.characterDefaults[definition.colorSetting]=CH.characterDefaults[definition.colorSetting] or definition.color
end
for _,definition in ipairs(CH.setTrackerDefinitions) do
    local key=definition.key
    CH.defaults[key.."Enabled"]=false; CH.defaults[key.."Slot"]=definition.slot; CH.defaults[key.."Color"]=definition.color
    CH.characterKeys[key.."Enabled"]=true; CH.characterKeys[key.."Slot"]=true; CH.characterKeys[key.."Color"]=true
    CH.characterDefaults[key.."Enabled"]=false; CH.characterDefaults[key.."Slot"]=definition.slot; CH.characterDefaults[key.."Color"]=definition.color
end
CH.scribingTrackerDefinitions = {
    {key="soulBurst",label="Soul Burst",icon="CurvedHUD/textures/soul_burst.dds",slot="topRightInside",color="Purple",duration=20,anchoriteCooldown=5,needles={"soul burst","binding burst","bloody burst","chilling burst","fiery burst","healing burst","leashing burst","magical burst","pestilent burst","shocking burst","sundering burst","warding burst"}},
    {key="contingency",label="Ulfsild's Contingency",icon="CurvedHUD/textures/ulfsilds_contingency.dds",slot="bottomRightInside",color="Cyan",duration=20,needles={"contingency"}},
    {key="elementalExplosion",label="Elemental Explosion",icon="CurvedHUD/textures/elemental_explosion.dds",slot="topRightOutside",color="Orange",duration=20,needles={"elemental explosion","explosion"}},
    {key="mendersBond",label="Mender's Bond",icon="CurvedHUD/textures/menders_bond.dds",slot="bottomRightOutside",color="Cyan",duration=12,needles={"mender's bond","menders bond"," bond"}},
    {key="shieldThrow",label="Shield Throw",icon="CurvedHUD/textures/shield_throw.dds",slot="topLeftOutside",color="Pale Blue",duration=20,needles={"shield throw"," throw"}},
    {key="smash",label="Smash",icon="CurvedHUD/textures/smash.dds",slot="bottomLeftOutside",color="Red",duration=20,needles={"smash"}},
    {key="torchbearer",label="Torchbearer",icon="CurvedHUD/textures/torchbearer.dds",slot="topLeftInside",color="Orange",duration=20,needles={"torchbearer","torch"}},
    {key="trample",label="Trample",icon="CurvedHUD/textures/trample.dds",slot="bottomLeftInside",color="Gold",duration=2,needles={"trample"}},
    {key="travelingKnife",label="Traveling Knife",icon="CurvedHUD/textures/traveling_knife.dds",slot="topRightInside",color="White",duration=20,needles={"traveling knife","knife"}},
    {key="vault",label="Vault",icon="CurvedHUD/textures/vault.dds",slot="bottomRightInside",color="Green",duration=4,needles={"vault"}},
    {key="wieldSoul",label="Wield Soul",icon="CurvedHUD/textures/wield_soul.dds",slot="topRightOutside",color="Purple",duration=20,needles={"wield soul"," soul"}},
}
CH.sorcererTrackerDefinitions = {
    {key="daedricCurse",label="Daedric Curse / Prey",slot="topLeftInside",color="Purple",duration=6,needles={"daedric curse","daedric prey","haunting curse"},durations={ ["daedric curse"]=6,["daedric prey"]=6,["haunting curse"]=12}},
    {key="lightningSplash",label="Lightning Splash",slot="bottomRightOutside",color="Cyan",duration=10,needles={"lightning splash","lightning flood","liquid lightning"},durations={ ["lightning splash"]=10,["lightning flood"]=10,["liquid lightning"]=15}},
    {key="volatileFamiliar",label="Volatile Familiar Activation",slot="bottomLeftOutside",color="Purple",duration=20,needles={"summon volatile familiar","volatile familiar"}},
    {key="twilightTormentor",label="Twilight Tormentor Activation",slot="topRightOutside",color="Pink",duration=20,needles={"summon twilight tormentor","twilight tormentor"}},
    {key="conjuredWard",label="Conjured Ward",slot="bottomLeftInside",color="Pale Blue",duration=6,needles={"conjured ward","hardened ward","regenerative ward"},durations={ ["conjured ward"]=6,["hardened ward"]=6,["regenerative ward"]=10}},
    {key="lightningForm",label="Lightning Form / Hurricane",slot="topRightInside",color="Pale Blue",duration=20,needles={"lightning form","boundless storm","hurricane"},durations={ ["lightning form"]=20,["boundless storm"]=30,["hurricane"]=20}},
    {key="darkExchange",label="Dark Exchange",slot="bottomRightInside",color="Gold",duration=20,needles={"dark exchange","dark conversion","dark deal"}},
    {key="daedricMines",label="Daedric Mines",slot="topLeftOutside",color="Red",duration=15,needles={"daedric mines","daedric minefield","daedric tomb"}},
}
CH.wardenTrackerDefinitions = {
    {key="netch",label="Betty/Bull Netch",slot="topLeftOutside",color="Pale Blue",duration=25,needles={"betty netch","blue betty","bull netch"},icons={ ["betty netch"]="CurvedHUD/textures/betty_netch.dds",["blue betty"]="CurvedHUD/textures/blue_betty.dds",["bull netch"]="CurvedHUD/textures/bull_netch.dds"}},
    {key="swarm",label="Fetcherfly Swarm",slot="bottomLeftOutside",color="Green",duration=20,needles={"swarm","fetcher infection","growing swarm"},icons={ ["swarm"]="CurvedHUD/textures/swarm.dds",["fetcher infection"]="CurvedHUD/textures/fetcher_infection.dds",["growing swarm"]="CurvedHUD/textures/growing_swarm.dds"}},
    {key="shalk",label="Scorch / Shalks",slot="topLeftInside",color="Orange",duration=9,needles={"scorch","deep fissure","subterranean assault"},icons={ ["scorch"]="CurvedHUD/textures/scorch.dds",["deep fissure"]="CurvedHUD/textures/deep_fissure.dds",["subterranean assault"]="CurvedHUD/textures/subterranean_assault.dds"},durations={ ["scorch"]=9,["deep fissure"]=9,["subterranean assault"]=6}},
    {key="shards",label="Impaling Shards / Winter's Revenge",slot="topRightOutside",color="Pale Blue",duration=12,needles={"impaling shards","gripping shards","winter's revenge","winters revenge"}},
    {key="lotus",label="Lotus Flower",slot="bottomRightOutside",color="Pink",duration=20,needles={"lotus flower","green lotus","lotus blossom"},durations={ ["lotus flower"]=20,["green lotus"]=20,["lotus blossom"]=60}},
    {key="seeds",label="Healing Seed / Budding Seeds",slot="bottomLeftInside",color="Green",duration=6,needles={"healing seed","budding seeds","corrupting pollen"}},
    {key="crystallizedShield",label="Crystallized Shield",slot="topRightInside",color="Cyan",duration=6,needles={"crystallized shield","shimmering shield","crystallized slab"}},
}
CH.arcanistTrackerDefinitions = {
    {key="crux",label="Crux",icon="/esoui/art/icons/class_buff_arcanist_crux.dds",slot="topLeftInside",color="Green",duration=30,stackOnly=true,stackMaximum=3,needles={"crux","runeblades","cephaliarch's flail","cephaliarchs flail"}},
    {key="abyssalImpact",label="Abyssal Impact / Flail",slot="bottomLeftInside",color="Green",duration=20,needles={"abyssal impact","cephaliarch's flail","cephaliarchs flail","tentacular dread"}},
    {key="tomeBearer",label="Tome-Bearer's Inspiration",slot="topLeftOutside",color="Gold",duration=30,needles={"tome-bearer's inspiration","tome bearer's inspiration","inspired scholarship","recuperative treatise"}},
    {key="imperfectRing",label="The Imperfect Ring",slot="bottomLeftOutside",color="Purple",duration=20,needles={"the imperfect ring","fulminating rune","rune of displacement"}},
    {key="runicJolt",label="Runic Jolt / Sunder",slot="topRightInside",color="Red",duration=15,needles={"runic jolt","runic embrace","runic sunder"}},
    {key="runespiteWard",label="Runespite Ward",slot="bottomRightInside",color="Pale Blue",duration=6,needles={"runespite ward","spiteward of the lucid mind","impervious runeward"}},
    {key="fatewovenArmor",label="Fatewoven Armor",slot="topRightOutside",color="Purple",duration=20,needles={"fatewoven armor","cruxweaver armor","unbreakable fate"},durations={["fatewoven armor"]=20,["cruxweaver armor"]=30,["unbreakable fate"]=20}},
    {key="runicDefense",label="Runic Defense",slot="bottomRightOutside",color="Pale Blue",duration=20,needles={"runic defense","runeguard of freedom","runeguard of still waters"}},
    {key="eldritchHorror",label="Rune of Eldritch Horror",slot="topLeftInside",color="Pink",duration=20,needles={"rune of eldritch horror","rune of uncanny adoration","rune of the colorless pool"}},
    {key="chakramShields",label="Chakram Shields",slot="bottomLeftInside",color="Cyan",duration=6,needles={"chakram shields","chakram of destiny","tidal chakram"}},
    {key="arcanistDomain",label="Arcanist's Domain",slot="topRightOutside",color="Green",duration=20,needles={"arcanist's domain","arcanists domain","reconstructive domain","zenas' empowering disc","zenas empowering disc"}},
}
CH.dragonknightTrackerDefinitions = {
    {key="dkSearingStrike",label="Searing Strike",slot="topLeftInside",color="Orange",duration=20,needles={"searing strike","venomous claw","burning embers"}},
    {key="dkFieryBreath",label="Fiery Breath",slot="bottomLeftInside",color="Orange",duration=20,needles={"fiery breath","noxious breath","engulfing flames"}},
    {key="dkInferno",label="Inferno",slot="topLeftOutside",color="Red",duration=15,needles={"inferno","flames of oblivion","cauterize"}},
    {key="dkSpikedArmor",label="Spiked Armor",slot="bottomLeftOutside",color="Orange",duration=20,needles={"spiked armor","hardened armor","volatile armor"}},
    {key="dkProtectiveScale",label="Protective Scale",slot="topRightInside",color="Gold",duration=6,needles={"protective scale","dragon fire scale","protective plate"}},
    {key="dkDarkTalons",label="Dark Talons",slot="bottomRightInside",color="Red",duration=4,needles={"dark talons","burning talons","choking talons"}},
    {key="dkMoltenWeapons",label="Molten Weapons",slot="topRightOutside",color="Gold",duration=45,needles={"molten weapons","igneous weapons","molten armaments"},durations={["molten weapons"]=45,["igneous weapons"]=60,["molten armaments"]=45}},
    {key="dkAshCloud",label="Ash Cloud",slot="bottomRightOutside",color="Orange",duration=15,needles={"ash cloud","cinder storm","eruption"}},
    {key="dkObsidianShield",label="Obsidian Shield / Major Mending",slot="topLeftOutside",color="Gold",duration=4,needles={"obsidian shield","igneous shield","fragmented shield","major mending"},durations={["fragmented shield"]=6}},
    {key="dkStoneGiant",label="Stone Giant Stagger",slot="bottomRightInside",color="Orange",duration=5,stackMaximum=3,needles={"stone giant","stagger"}},
    {key="dkSeethingFury",label="Seething Fury",slot="topRightInside",color="Red",duration=15,stackMaximum=3,needles={"seething fury","molten whip"}},
}
CH.nightbladeTrackerDefinitions = {
    {key="nbGrimFocus",label="Grim Focus",slot="topLeftOutside",color="Red",duration=40,stackMaximum=5,needles={"grim focus","relentless focus","merciless resolve"}},
    {key="nbBlur",label="Blur",slot="topLeftInside",color="Purple",duration=20,needles={"blur","mirage","phantasmal escape"}},
    {key="nbPath",label="Path of Darkness",slot="bottomLeftInside",color="Purple",duration=10,needles={"path of darkness","twisting path","refreshing path"}},
    {key="nbCloak",label="Shadow Cloak",slot="bottomLeftOutside",color="Purple",duration=3,needles={"shadow cloak","shadowy disguise","dark cloak"},durations={["dark cloak"]=6}},
    {key="nbShade",label="Summon Shade",slot="topRightOutside",color="Purple",duration=20,needles={"summon shade","dark shade","shadow image"}},
    {key="nbMark",label="Mark Target",slot="topRightInside",color="Red",duration=20,needles={"mark target","piercing mark","reaper's mark","reapers mark"}},
    {key="nbCripple",label="Cripple",slot="bottomRightInside",color="Purple",duration=20,needles={"cripple","debilitate","crippling grasp"}},
    {key="nbSiphoning",label="Siphoning Strikes",slot="bottomRightOutside",color="Red",duration=20,needles={"siphoning strikes","leeching strikes","siphoning attacks"}},
    {key="nbDrainPower",label="Drain Power",slot="topRightOutside",color="Red",duration=20,needles={"drain power","power extraction","sap essence"}},
    {key="nbLotusFan",label="Lotus Fan",slot="bottomRightInside",color="Pink",duration=20,needles={"lotus fan"}},
    {key="nbOfferingPenalty",label="Offering Health Drain",slot="bottomLeftInside",color="Red",duration=3,negative=true,needles={"malevolent offering","healthy offering","shrewd offering"},durations={["malevolent offering"]=3,["healthy offering"]=3,["shrewd offering"]=2}},
}
CH.templarTrackerDefinitions = {
    {key="tpSunFire",label="Sun Fire",slot="topLeftInside",color="Gold",duration=20,needles={"sun fire","reflective light","vampire's bane","vampires bane"}},
    {key="tpSolarFlare",label="Solar Flare",slot="bottomLeftInside",color="Gold",duration=10,needles={"solar flare","dark flare","solar barrage"},durations={["solar barrage"]=20}},
    {key="tpBacklash",label="Backlash",slot="topLeftOutside",color="Gold",duration=6,needles={"backlash","power of the light","purifying light"}},
    {key="tpEclipse",label="Eclipse",slot="bottomLeftOutside",color="Purple",duration=4,needles={"eclipse","living dark","unstable core"},durations={["living dark"]=10}},
    {key="tpSpearShards",label="Spear Shards",slot="topRightInside",color="Gold",duration=10,needles={"spear shards","luminous shards","blazing spear"}},
    {key="tpSunShield",label="Sun Shield",slot="bottomRightInside",color="Gold",duration=6,needles={"sun shield","radiant ward","blazing shield"}},
    {key="tpRuneFocus",label="Rune Focus",slot="topRightOutside",color="Pale Blue",duration=20,needles={"rune focus","channeled focus","restoring focus"},durations={["channeled focus"]=25}},
    {key="tpCleansingRitual",label="Cleansing Ritual",slot="bottomRightOutside",color="White",duration=20,needles={"cleansing ritual","extended ritual","ritual of retribution"},durations={["extended ritual"]=24}},
    {key="tpRestoringAura",label="Restoring Aura",slot="topLeftOutside",color="Green",duration=20,needles={"restoring aura","radiant aura","repentance"}},
    {key="tpIlluminate",label="Illuminate / Armor",slot="topRightOutside",color="Gold",duration=20,needles={"illuminate"}},
}
CH.necromancerTrackerDefinitions = {
    {key="necroSacrificialBones",label="Sacrificial Bones",slot="topLeftInside",color="Purple",duration=10,needles={"sacrificial bones","grave lord's sacrifice","grave lords sacrifice"},durations={["grave lord's sacrifice"]=20,["grave lords sacrifice"]=20}},
    {key="necroBoneyard",label="Boneyard",slot="bottomLeftInside",color="Purple",duration=10,needles={"boneyard","avid boneyard","unnerving boneyard"}},
    {key="necroSkeletalMage",label="Skeletal Mage",slot="topLeftOutside",color="Pale Blue",duration=20,needles={"skeletal mage","skeletal archer","skeletal arcanist"}},
    {key="necroSiphon",label="Shocking Siphon",slot="bottomLeftOutside",color="Purple",duration=12,needles={"shocking siphon","detonating siphon","mystic siphon"}},
    {key="necroBoneArmor",label="Bone Armor",slot="topRightInside",color="White",duration=20,needles={"bone armor","beckoning armor","summoner's armor","summoners armor"},durations={["summoner's armor"]=30,["summoners armor"]=30}},
    {key="necroBoneTotem",label="Bone Totem",slot="bottomRightInside",color="Purple",duration=11,needles={"bone totem","agony totem","remote totem"},durations={["agony totem"]=13}},
    {key="necroSpiritMender",label="Spirit Mender",slot="topRightOutside",color="Green",duration=16,needles={"spirit mender","intensive mender","spirit guardian"},durations={["intensive mender"]=8}},
    {key="necroRestoringTether",label="Restoring Tether",slot="bottomRightOutside",color="Green",duration=12,needles={"restoring tether","braided tether","mortal coil"}},
    {key="necroLifeAmidDeath",label="Life amid Death",slot="topLeftInside",color="Green",duration=5,needles={"life amid death","renewing undeath","enduring undeath"}},
    {key="necroNothingWasted",label="Nothing Wasted",slot="bottomRightOutside",color="Gold",duration=12,stackMaximum=10,needles={"nothing wasted"}},
}
CH.remainingClassDefinitionGroups = {
    {name="Dragonknight",definitions=CH.dragonknightTrackerDefinitions,cache="dragonknightAbilityIds"},
    {name="Nightblade",definitions=CH.nightbladeTrackerDefinitions,cache="nightbladeAbilityIds"},
    {name="Templar",definitions=CH.templarTrackerDefinitions,cache="templarAbilityIds"},
    {name="Necromancer",definitions=CH.necromancerTrackerDefinitions,cache="necromancerAbilityIds"},
}
CH.nonClassTrackerDefinitions = {
    -- Two Handed
    {line="Two Handed",key="twoHandCleave",label="Cleave / Carve / Brawler",slot="topLeftInside",color="Red",duration=10,needles={"cleave","carve","brawler"},durations={ ["cleave"]=10,["carve"]=12,["brawler"]=6}},
    {line="Two Handed",key="stampede",label="Stampede",slot="bottomLeftInside",color="Orange",duration=15,needles={"stampede"}},
    {line="Two Handed",key="momentum",label="Momentum / Rally",slot="topLeftOutside",color="Gold",duration=20,needles={"momentum","forward momentum","rally"},durations={ ["momentum"]=20,["forward momentum"]=20,["rally"]=30}},
    {line="Two Handed",key="followUp",label="Follow Up Passive",slot="bottomLeftOutside",color="Gold",duration=4,needles={"follow up"}},
    {line="Two Handed",key="battleRush",label="Battle Rush Passive",slot="topRightOutside",color="Green",duration=10,needles={"battle rush"}},
    -- One Hand and Shield
    {line="One Hand and Shield",key="puncture",label="Puncture / Pierce Armor",slot="topRightInside",color="Red",duration=15,needles={"puncture","pierce armor","ransack"}},
    {line="One Hand and Shield",key="lowSlash",label="Low Slash",slot="bottomRightInside",color="Orange",duration=15,needles={"low slash","heroic slash","deep slash"}},
    {line="One Hand and Shield",key="defensivePosture",label="Defensive Posture",slot="topRightOutside",color="Pale Blue",duration=6,needles={"defensive posture","defensive stance","absorb missile"}},
    {line="One Hand and Shield",key="powerSlam",label="Power Slam",slot="bottomRightOutside",color="Gold",duration=10,needles={"power slam"}},
    -- Dual Wield
    {line="Dual Wield",key="twinSlashes",label="Twin Slashes",slot="topRightInside",color="Red",duration=20,needles={"twin slashes","blood craze","rending slashes"}},
    {line="Dual Wield",key="bladeCloak",label="Blade Cloak",slot="bottomRightInside",color="Pale Blue",duration=20,needles={"blade cloak","quick cloak","deadly cloak"}},
    {line="Dual Wield",key="flyingBlade",label="Flying Blade",slot="topRightOutside",color="Gold",duration=10,needles={"flying blade"}},
    -- Bow
    {line="Bow",key="volley",label="Volley",slot="topRightInside",color="Green",duration=10,needles={"volley","arrow barrage","endless hail"},durations={ ["volley"]=10,["arrow barrage"]=10,["endless hail"]=13}},
    {line="Bow",key="poisonArrow",label="Poison Arrow",slot="bottomRightInside",color="Green",duration=20,needles={"poison arrow","poison injection","venom arrow"}},
    {line="Bow",key="acidSpray",label="Acid Spray",slot="topRightOutside",color="Green",duration=5,needles={"acid spray"}},
    {line="Bow",key="hawkEye",label="Hawk Eye Stacks",slot="bottomRightOutside",color="Gold",duration=5,needles={"hawk eye"}},
    -- Destruction Staff
    {line="Destruction Staff",key="wallElements",label="Wall of Elements",slot="topRightInside",color="Cyan",duration=10,needles={"wall of elements","wall of fire","wall of frost","wall of storms","unstable wall","elemental blockade"},durations={ ["wall of elements"]=10,["unstable wall of elements"]=10,["elemental blockade"]=15,["elemental blockade of fire"]=15,["elemental blockade of frost"]=15,["elemental blockade of storms"]=15}},
    {line="Destruction Staff",key="destructiveTouch",label="Destructive Touch",slot="bottomRightInside",color="Orange",duration=20,needles={"destructive touch","destructive clench","destructive reach"}},
    {line="Destruction Staff",key="weaknessElements",label="Weakness to Elements",slot="topRightOutside",color="Purple",duration=30,needles={"weakness to elements","elemental drain","elemental susceptibility"}},
    {line="Destruction Staff",key="pulsar",label="Pulsar",slot="bottomRightOutside",color="Pale Blue",duration=10,needles={"pulsar"}},
    -- Restoration Staff
    {line="Restoration Staff",key="grandHealing",label="Grand Healing",slot="topLeftInside",color="Green",duration=5,needles={"grand healing","healing springs","illustrious healing"}},
    {line="Restoration Staff",key="regeneration",label="Regeneration",slot="bottomLeftInside",color="Green",duration=10,needles={"regeneration","rapid regeneration","radiating regeneration"}},
    {line="Restoration Staff",key="blessingProtection",label="Blessing of Protection",slot="topLeftOutside",color="Gold",duration=10,needles={"blessing of protection","combat prayer","blessing of restoration"}},
    {line="Restoration Staff",key="steadfastWard",label="Steadfast Ward",slot="bottomLeftOutside",color="Pale Blue",duration=6,needles={"steadfast ward","healing ward","ward ally"}},
    {line="Restoration Staff",key="forceSiphon",label="Force Siphon",slot="topRightOutside",color="Cyan",duration=24,needles={"force siphon","quick siphon","siphon spirit"},durations={ ["force siphon"]=24,["quick siphon"]=30,["siphon spirit"]=30}},
    {line="Restoration Staff",key="essenceDrain",label="Essence Drain Passive",slot="bottomRightOutside",color="Gold",duration=4,needles={"essence drain"}},
    -- Fighters Guild
    {line="Fighters Guild",key="trapBeast",label="Trap Beast",slot="topLeftInside",color="Red",duration=20,needles={"trap beast","barbed trap","lightweight beast trap"}},
    {line="Fighters Guild",key="circleProtection",label="Circle of Protection",slot="bottomLeftInside",color="Gold",duration=20,needles={"circle of protection","ring of preservation","turn evil"}},
    -- Mages Guild
    {line="Mages Guild",key="fireRune",label="Fire Rune",slot="topLeftInside",color="Orange",duration=20,needles={"fire rune","scalding rune","volcanic rune"}},
    {line="Mages Guild",key="entropy",label="Entropy",slot="bottomLeftInside",color="Purple",duration=20,needles={"entropy","structured entropy","degeneration"}},
    -- Undaunted
    {line="Undaunted",key="bloodAltar",label="Blood Altar",slot="topLeftOutside",color="Red",duration=30,needles={"blood altar","overflowing altar","sanguine altar"}},
    {line="Undaunted",key="trappingWebs",label="Trapping Webs",slot="bottomLeftOutside",color="Green",duration=10,needles={"trapping webs","shadow silk","tangling webs"}},
    {line="Undaunted",key="innerFire",label="Inner Fire",slot="topRightInside",color="Red",duration=15,needles={"inner fire","inner rage","inner beast"}},
    {line="Undaunted",key="boneShield",label="Bone Shield",slot="bottomRightInside",color="White",duration=6,needles={"bone shield","spiked bone shield","bone surge"}},
    {line="Undaunted",key="necroticOrb",label="Necrotic Orb",slot="topRightOutside",color="Cyan",duration=10,needles={"necrotic orb","mystic orb","energy orb"}},
    -- Psijic Order
    {line="Psijic Order",key="timeStop",label="Time Stop",slot="topLeftInside",color="Purple",duration=4,needles={"time stop","borrowed time","time freeze"}},
    {line="Psijic Order",key="imbueWeapon",label="Imbue Weapon",slot="bottomLeftInside",color="Gold",duration=6,needles={"imbue weapon","crushing weapon","elemental weapon"}},
    {line="Psijic Order",key="accelerate",label="Accelerate",slot="topLeftOutside",color="Pale Blue",duration=20,needles={"accelerate","channeled acceleration","race against time"},durations={ ["accelerate"]=20,["channeled acceleration"]=36,["race against time"]=20}},
    {line="Psijic Order",key="spellOrb",label="Spell Orb Charges",slot="bottomLeftOutside",color="Purple",duration=10,needles={"spell orb","spell charge"}},
    -- Alliance War
    {line="Assault",key="vigor",label="Vigor",slot="topRightInside",color="Green",duration=5,needles={"vigor","resolving vigor","echoing vigor"}},
    {line="Assault",key="caltrops",label="Caltrops",slot="bottomRightInside",color="Red",duration=15,needles={"caltrops","anti-cavalry caltrops","razor caltrops"}},
    {line="Assault",key="rapidManeuver",label="Rapid Maneuver",slot="topRightOutside",color="Gold",duration=8,needles={"rapid maneuver","charging maneuver","retreating maneuver"}},
    {line="Assault",key="magickaDetonation",label="Magicka Detonation",slot="bottomRightOutside",color="Purple",duration=4,needles={"magicka detonation","inevitable detonation","proximity detonation"}},
    {line="Support",key="siegeShield",label="Siege Shield",slot="topLeftOutside",color="Pale Blue",duration=20,needles={"siege shield","propelling shield","siege weapon shield"}},
    {line="Support",key="revealingFlare",label="Revealing Flare",slot="bottomLeftOutside",color="Red",duration=5,needles={"revealing flare","lingering flare","scorching flare"}},
    -- Armor and World
    {line="Light Armor",key="annulment",label="Annulment",slot="topLeftInside",color="Pale Blue",duration=6,needles={"annulment","dampen magic","harness magicka"}},
    {line="Medium Armor",key="evasion",label="Evasion",slot="topRightInside",color="Green",duration=20,needles={"evasion","shuffle","elude"}},
    {line="Heavy Armor",key="unstoppable",label="Unstoppable",slot="bottomLeftInside",color="Gold",duration=20,needles={"unstoppable","immovable","unstoppable brute"}},
    {line="Heavy Armor",key="unstoppableSnare",label="Unstoppable Self-Snare",slot="bottomLeftOutside",color="Red",duration=6,negative=true,needles={"unstoppable","immovable","unstoppable brute"}},
    {line="Soul Magic",key="soulTrap",label="Soul Trap",slot="topLeftOutside",color="Purple",duration=20,needles={"soul trap","consuming trap","soul splitting trap"}},
    {line="Vampire",key="mistForm",label="Mist Form",slot="bottomLeftOutside",color="Purple",duration=4,needles={"mist form","blood mist","elusive mist"}},
    {line="Vampire",key="bloodForBloodPenalty",label="Blood for Blood Ally-Heal Lockout",slot="topLeftInside",color="Red",duration=3,negative=true,needles={"blood for blood"}},
    {line="Vampire",key="bloodFrenzyPenalty",label="Blood Frenzy Risk",slot="topLeftOutside",color="Red",duration=2,negative=true,stackMaximum=5,needles={"blood frenzy","sated fury","simmering frenzy"}},
    {line="Werewolf",key="werewolfRoar",label="Roar",slot="topRightOutside",color="Red",duration=10,needles={"roar","ferocious roar","deafening roar"}},
    {line="Werewolf",key="werewolfClaws",label="Infectious Claws",slot="bottomRightOutside",color="Green",duration=20,needles={"infectious claws","claws of anguish","claws of life"}},
}
CH.weaponSkillLines = {"Two Handed","One Hand and Shield","Dual Wield","Bow","Destruction Staff","Restoration Staff"}
CH.otherSkillLines = {"Fighters Guild","Mages Guild","Undaunted","Psijic Order","Assault","Support","Soul Magic","Vampire","Werewolf"}
CH.armorSkillLines = {"Light Armor","Medium Armor","Heavy Armor"}
CH.scribingSkillLineByKey = {
    smash="Two Handed",shieldThrow="One Hand and Shield",travelingKnife="Dual Wield",vault="Bow",
    elementalExplosion="Destruction Staff",mendersBond="Restoration Staff",torchbearer="Fighters Guild",
    contingency="Mages Guild",wieldSoul="Soul Magic",trample="Assault",soulBurst="Soul Magic",
}
for _,definition in ipairs(CH.scribingTrackerDefinitions) do
    local key=definition.key
    if CH.defaults[key.."Enabled"]==nil then CH.defaults[key.."Enabled"]=false end
    CH.defaults[key.."Slot"]=CH.defaults[key.."Slot"] or definition.slot; CH.defaults[key.."Color"]=CH.defaults[key.."Color"] or definition.color; CH.defaults[key.."Duration"]=CH.defaults[key.."Duration"] or definition.duration
    CH.characterKeys[key.."Enabled"]=true; CH.characterKeys[key.."Slot"]=true; CH.characterKeys[key.."Color"]=true; CH.characterKeys[key.."Duration"]=true
    CH.characterDefaults[key.."Enabled"]=CH.characterDefaults[key.."Enabled"] or false; CH.characterDefaults[key.."Slot"]=CH.characterDefaults[key.."Slot"] or definition.slot; CH.characterDefaults[key.."Color"]=CH.characterDefaults[key.."Color"] or definition.color; CH.characterDefaults[key.."Duration"]=CH.characterDefaults[key.."Duration"] or definition.duration
end
for _,definition in ipairs(CH.wardenTrackerDefinitions) do
    local key=definition.key
    CH.defaults[key.."Enabled"]=false; CH.defaults[key.."Slot"]=definition.slot; CH.defaults[key.."Color"]=definition.color
    CH.characterKeys[key.."Enabled"]=true; CH.characterKeys[key.."Slot"]=true; CH.characterKeys[key.."Color"]=true
    CH.characterDefaults[key.."Enabled"]=false; CH.characterDefaults[key.."Slot"]=definition.slot; CH.characterDefaults[key.."Color"]=definition.color
end
for _,definition in ipairs(CH.arcanistTrackerDefinitions) do
    local key=definition.key
    CH.defaults[key.."Enabled"]=false; CH.defaults[key.."Slot"]=definition.slot; CH.defaults[key.."Color"]=definition.color
    CH.characterKeys[key.."Enabled"]=true; CH.characterKeys[key.."Slot"]=true; CH.characterKeys[key.."Color"]=true
    CH.characterDefaults[key.."Enabled"]=false; CH.characterDefaults[key.."Slot"]=definition.slot; CH.characterDefaults[key.."Color"]=definition.color
end
for _,group in ipairs(CH.remainingClassDefinitionGroups) do
    for _,definition in ipairs(group.definitions) do
        local key=definition.key
        CH.defaults[key.."Enabled"]=false; CH.defaults[key.."Slot"]=definition.slot; CH.defaults[key.."Color"]=definition.color
        CH.characterKeys[key.."Enabled"]=true; CH.characterKeys[key.."Slot"]=true; CH.characterKeys[key.."Color"]=true
        CH.characterDefaults[key.."Enabled"]=false; CH.characterDefaults[key.."Slot"]=definition.slot; CH.characterDefaults[key.."Color"]=definition.color
    end
end
CH.defaults.cruxQuadrant="topLeft"; CH.characterKeys.cruxQuadrant=true; CH.characterDefaults.cruxQuadrant="topLeft"
for _,definition in ipairs(CH.sorcererTrackerDefinitions) do
    local key=definition.key
    CH.defaults[key.."Enabled"]=false; CH.defaults[key.."Slot"]=definition.slot; CH.defaults[key.."Color"]=definition.color
    CH.characterKeys[key.."Enabled"]=true; CH.characterKeys[key.."Slot"]=true; CH.characterKeys[key.."Color"]=true
    CH.characterDefaults[key.."Enabled"]=false; CH.characterDefaults[key.."Slot"]=definition.slot; CH.characterDefaults[key.."Color"]=definition.color
end
for _,definition in ipairs(CH.nonClassTrackerDefinitions) do
    local key=definition.key
    CH.defaults[key.."Enabled"]=false; CH.defaults[key.."Slot"]=definition.slot; CH.defaults[key.."Color"]=definition.color
    CH.characterKeys[key.."Enabled"]=true; CH.characterKeys[key.."Slot"]=true; CH.characterKeys[key.."Color"]=true
    CH.characterDefaults[key.."Enabled"]=false; CH.characterDefaults[key.."Slot"]=definition.slot; CH.characterDefaults[key.."Color"]=definition.color
end
-- Enemy-bound durations are removed by ESO when combat ends. Keep self buffs,
-- heals, shields, proc cooldowns, and utility windows intact; only hostile DoTs,
-- ground effects, target debuffs, and their combat-only stacks are purged.
CH.combatBoundTrackerKeys = {
    daedricCurse=true,lightningSplash=true,daedricMines=true,
    swarm=true,shalk=true,shards=true,
    abyssalImpact=true,imperfectRing=true,runicJolt=true,
    dkSearingStrike=true,dkFieryBreath=true,dkDarkTalons=true,dkAshCloud=true,dkStoneGiant=true,
    nbPath=true,nbMark=true,nbCripple=true,nbLotusFan=true,
    tpSunFire=true,tpBacklash=true,tpEclipse=true,tpSpearShards=true,
    necroBoneyard=true,necroSiphon=true,necroBoneTotem=true,
    twoHandCleave=true,stampede=true,puncture=true,lowSlash=true,twinSlashes=true,
    volley=true,poisonArrow=true,acidSpray=true,wallElements=true,destructiveTouch=true,
    weaknessElements=true,pulsar=true,trapBeast=true,fireRune=true,entropy=true,
    trappingWebs=true,innerFire=true,timeStop=true,caltrops=true,magickaDetonation=true,
    soulTrap=true,werewolfClaws=true,
    setRelequen=true,setZens=true,setElementalCatalyst=true,setAlkosh=true,
}
function CH:NormalizeTrackerSlot(value,fallback)
    if self.trackerSlots[value] then return value end
    for index,name in ipairs(self.trackerSlotNames) do
        if value==name then return self.trackerSlotValues[index] end
    end
    return fallback
end
function CH:NormalizeCruxQuadrant(value)
    if value=="topLeft" or value=="bottomLeft" or value=="topRight" or value=="bottomRight" then return value end
    local slot=value or self.sv.cruxSlot
    if slot and string.find(slot,"bottom",1,true) then return string.find(slot,"Right",1,true) and "bottomRight" or "bottomLeft" end
    if slot and string.find(slot,"Right",1,true) then return "topRight" end
    return "topLeft"
end
-- These IDs cover ESO's standardized base effects where confirmed. Name matching
-- remains the fallback because some sources expose their own ability ID while
-- retaining the localized standardized buff name.
local MAJOR_BUFF_IDS = {["Major Resolve"]=61694,["Major Brutality"]=61665,["Major Savagery"]=64568}
local BOUND_ARMAMENTS_SKILL_ID,BOUND_ARMAMENTS_STACK_ID=24165,203447
local CRYSTAL_FRAGMENTS_PROC_EFFECT_ID,CRYSTAL_FRAGMENTS_PROC_SLOT_ID=46327,114716
local CRITICAL_SURGE_EFFECT_ID=23678
local SHROUD_ICON_PATHS={
    ["vibrant shroud"]="CurvedHUD/textures/vibrant_shroud.dds",
    ["encase"]="CurvedHUD/textures/encase.dds",
    ["shattering spines"]="CurvedHUD/textures/shattering_spines.dds",
}
local DEFAULT_SHROUD_ICON_PATH=SHROUD_ICON_PATHS["vibrant shroud"]
local ULFSILD_EFFECT_ID=222285
-- Contingency uses three persistent priming effects and a large family of
-- generated signature/affix effects. The triggered effect frequently does not
-- contain "Ulfsild" in its localized name, so IDs are the authoritative link.
-- Keep this family aligned with the live mappings used by action-bar trackers.
local CONTINGENCY_PRIME_IDS={[217528]=true,[222285]=true,[222678]=true}
local CONTINGENCY_EFFECT_IDS={
    [221185]=true,[217611]=true,[221354]=true,[221392]=true,
    [221155]=true,[221156]=true,[221157]=true,[221158]=true,
    [217655]=true,[217613]=true,[217621]=true,[217605]=true,
    [221179]=true,[221180]=true,[221181]=true,[221182]=true,[221183]=true,[221184]=true,
    [221169]=true,[221170]=true,[221171]=true,[221172]=true,
    [217656]=true,[217652]=true,[217609]=true,[217610]=true,[221356]=true,[218340]=true,
    [221166]=true,[221167]=true,[221168]=true,
    [221159]=true,[221160]=true,[221161]=true,[217654]=true,
    [217528]=true,[217604]=true,[217616]=true,[217618]=true,[217653]=true,[217657]=true,
    [217659]=true,[218341]=true,[219662]=true,[221189]=true,[221352]=true,[221353]=true,
    [221355]=true,[221734]=true,[222285]=true,[222364]=true,[222678]=true,
    [221173]=true,[221174]=true,[221175]=true,[221176]=true,[221177]=true,[217608]=true,
    [240148]=true,[240149]=true,[240150]=true,
}
local WM = WINDOW_MANAGER
local HEALTH_POWER=_G["COMBAT_MECHANIC_FLAGS_HEALTH"] or POWERTYPE_HEALTH
local STAMINA_POWER=_G["COMBAT_MECHANIC_FLAGS_STAMINA"] or POWERTYPE_STAMINA
local MAGICKA_POWER=_G["COMBAT_MECHANIC_FLAGS_MAGICKA"] or POWERTYPE_MAGICKA
local MOUNT_POWER=_G["COMBAT_MECHANIC_FLAGS_MOUNT_STAMINA"] or POWERTYPE_MOUNT_STAMINA
local PERIODIC_COMBAT_RESULTS={}
for _,name in ipairs({
    "ACTION_RESULT_DAMAGE","ACTION_RESULT_CRITICAL_DAMAGE","ACTION_RESULT_DOT_TICK","ACTION_RESULT_DOT_TICK_CRITICAL",
    "ACTION_RESULT_HEAL","ACTION_RESULT_CRITICAL_HEAL","ACTION_RESULT_HOT_TICK","ACTION_RESULT_HOT_TICK_CRITICAL",
    "ACTION_RESULT_BLOCKED_DAMAGE","ACTION_RESULT_DAMAGE_SHIELDED","ACTION_RESULT_EFFECT_FADED",
}) do local value=_G[name]; if value then PERIODIC_COMBAT_RESULTS[value]=true end end
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v or 0)) end

function CH:Log(message, always)
    local line=string.format("|c66CCFF[CurvedHUD]|r %s",tostring(message))
    if always or (self.sv and self.sv.debug) then if d then d(line) end end
end
function CH:Guard(label,fn)
    local ok,err=pcall(fn)
    if not ok then
        self.errorCount=(self.errorCount or 0)+1
        self.errorLog=self.errorLog or {}
        self.errorLog[#self.errorLog+1]=tostring(label)..": "..tostring(err)
        if #self.errorLog>5 then table.remove(self.errorLog,1) end
        self:Log("ERROR in "..label..": "..tostring(err),true)
    end
    return ok
end
local function texture(parent,suffix,level,path,r,g,b,a)
    local c=WM:CreateControl(parent:GetName()..suffix,parent,CT_TEXTURE)
    c:SetDrawLayer(DL_BACKGROUND); c:SetDrawLevel(level); c:SetTexture(path); c:SetColor(r,g,b,a)
    return c
end
local function label(parent,suffix,font)
    local c=WM:CreateControl(parent:GetName()..suffix,parent,CT_LABEL)
    c:SetFont(font or "ZoFontGamepad27"); c:SetHorizontalAlignment(TEXT_ALIGN_CENTER); c:SetVerticalAlignment(TEXT_ALIGN_CENTER); c:SetColor(1,1,1,1)
    return c
end

function CH:CreateBar(key,side,color)
    local b=WM:CreateControl("CurvedHUD_"..key,self.root,CT_CONTROL)
    b.key,b.side,b.color=key,side,color; b:SetDimensions(96,512)
    b.bg=texture(b,"_Background",0,"CurvedHUD/textures/arc_full.dds",.04,.04,.04,self.sv.backgroundAlpha); b.bg:SetAnchorFill(b)
    -- Resource-specific textures provide an ESO-style dark-to-bright gradient.
    -- White tint preserves the authored gradient while SetAlpha remains customizable.
    b.fill=texture(b,"_Fill",2,"CurvedHUD/textures/arc_"..key.."_gradient.dds",1,1,1,self.sv.fillAlpha); b.fill:SetAnchor(BOTTOMLEFT,b,BOTTOMLEFT)
    -- The holder uses the identical geometry as the fill so scaling cannot separate them.
    b.frame=texture(b,"_Frame",1,"CurvedHUD/textures/arc_full.dds",.38,.38,.38,self.sv.frameAlpha); b.frame:SetAnchorFill(b)
    -- Reversed after the first console render showed the arcs facing the wrong way.
    b.u1,b.u2=side=="left" and 1 or 0,side=="left" and 0 or 1
    b.bg:SetTextureCoords(b.u1,b.u2,0,1); b.frame:SetTextureCoords(b.u1,b.u2,0,1)
    b.rawLabel=label(b,"_RawLabel"); b.rawLabel:SetDimensions(190,34)
    b.percentLabel=label(b,"_PercentLabel","ZoFontGamepad20"); b.percentLabel:SetDimensions(110,28)
    self.bars[key]=b
end
function CH:SetTexturePercent(t,owner,pct)
    pct=clamp(pct,0,1)
    local w,h=owner:GetDimensions(); local shown=math.max(1,math.floor(h*pct))
    t:ClearAnchors(); t:SetDimensions(w,shown)
    if owner.segment=="trackerLower" then
        t:SetAnchor(BOTTOMLEFT,owner,BOTTOMLEFT); t:SetTextureCoords(owner.u1,owner.u2,1-(.42*pct),1)
    elseif owner.segment=="upper" then
        -- Keep the outside/top end filled; depletion advances toward it from the midpoint.
        t:SetAnchor(TOPLEFT,owner,TOPLEFT); t:SetTextureCoords(owner.u1,owner.u2,.5,.5+(.5*pct))
    elseif owner.segment=="lower" then
        -- Keep the outside/bottom end filled; depletion advances toward it from the midpoint.
        t:SetAnchor(BOTTOMLEFT,owner,BOTTOMLEFT); t:SetTextureCoords(owner.u1,owner.u2,.5-(.5*pct),.5)
    else
        t:SetAnchor(BOTTOMLEFT,owner,BOTTOMLEFT); t:SetTextureCoords(owner.u1,owner.u2,1-pct,1)
    end
    t:SetHidden(pct<=0)
end

function CH:SetBarSegment(b,segment)
    b.segment=segment
    if segment=="upper" then
        b.bg:SetTextureCoords(b.u1,b.u2,.5,1); b.frame:SetTextureCoords(b.u1,b.u2,.5,1)
    elseif segment=="lower" then
        b.bg:SetTextureCoords(b.u1,b.u2,0,.5); b.frame:SetTextureCoords(b.u1,b.u2,0,.5)
    else
        b.bg:SetTextureCoords(b.u1,b.u2,0,1); b.frame:SetTextureCoords(b.u1,b.u2,0,1)
    end
end
function CH:SetBarValue(b,current,maximum)
    maximum=math.max(1,maximum or 1); current=clamp(current or 0,0,maximum)
    local pct=current/maximum; self:SetTexturePercent(b.fill,b,pct)
    local raw=self.sv.showRaw and ZO_CommaDelimitNumber(current) or ""
    if self.sv.showMaximum then raw=raw..(raw~="" and " / " or "")..ZO_CommaDelimitNumber(maximum) end
    b.rawLabel:SetText(raw); b.rawLabel:SetHidden(raw=="")
    b.percentLabel:SetText(self.sv.showPercent and string.format("%d%%",math.floor(pct*100+.5)) or ""); b.percentLabel:SetHidden(not self.sv.showPercent)
end
function CH:CreateShield()
    local h=self.bars.health
    h.shield=texture(h,"_Shield",3,"CurvedHUD/textures/arc_full.dds",.72,.76,.82,self.sv.shieldAlpha); h.shield:SetAnchor(BOTTOMLEFT,h,BOTTOMLEFT)
    h.overcap=texture(h,"_Overcap",5,"CurvedHUD/textures/arc_frame.dds",1,1,1,.9); h.overcap:SetAnchorFill(h); h.overcap:SetTextureCoords(h.u1,h.u2,0,1); h.overcap:SetHidden(true)
end
function CH:CreateMountBar()
    local b=WM:CreateControl("CurvedHUD_mount",self.root,CT_CONTROL); b:SetDimensions(24,512)
    b.key,b.side,b.segment="mount","right","full"; b.u1,b.u2=0,1
    b.bg=texture(b,"_Background",0,"CurvedHUD/textures/mount_stacked_outer.dds",.04,.04,.04,self.sv.backgroundAlpha); b.bg:SetAnchorFill(b)
    b.frame=texture(b,"_Frame",1,"CurvedHUD/textures/mount_stacked_outer_frame.dds",.38,.38,.38,self.sv.frameAlpha); b.frame:SetAnchorFill(b)
    b.fill=texture(b,"_Fill",2,"CurvedHUD/textures/mount_stacked_outer.dds",.42,.82,.34,self.sv.fillAlpha); b.fill:SetAnchor(BOTTOMLEFT,b,BOTTOMLEFT)
    b.bg:SetTextureCoords(b.u1,b.u2,0,1); b.frame:SetTextureCoords(b.u1,b.u2,0,1)
    b:SetHidden(true); self.mountBar=b
end
function CH:GetTrackerAppearanceBase(slot,specialTexture)
    local info=self.trackerSlots[slot]
    local style=info.inside and self.sv.insideTimerStyle or self.sv.outsideTimerStyle
    if specialTexture=="balance" and slot=="bottomLeftInside" and style=="Thin" then return "balance_lower" end
    if info.side=="right" then return "tracker_"..info.vertical.."_right_"..string.lower(self.sv.layout).."_"..(info.inside and "inside" or "outside").."_"..string.lower(style) end
    return "tracker_"..info.vertical.."_"..(info.inside and "inside" or "outside").."_"..string.lower(style)
end

function CH:CreateTracker(key,slot,colorSetting,specialTexture)
    local t=WM:CreateControl("CurvedHUD_"..key,self.root,CT_CONTROL); t:SetDimensions(38,180); t.segment="full"
    t.key,t.slot,t.colorSetting,t.specialTexture=key,slot,colorSetting,specialTexture; t.isNegative=key=="balance"
    local info=self.trackerSlots[slot]; t.u1,t.u2=info.side=="left" and 1 or 0,info.side=="left" and 0 or 1
    local textureName=self:GetTrackerAppearanceBase(slot,specialTexture)
    t.frame=texture(t,"_Frame",1,"CurvedHUD/textures/"..textureName.."_frame.dds",.35,.35,.35,.7); t.frame:SetAnchorFill(t); t.frame:SetTextureCoords(t.u1,t.u2,0,1)
    t.fill=texture(t,"_Fill",2,"CurvedHUD/textures/"..textureName..".dds",1,1,1,.9); t.fill:SetAnchor(BOTTOMLEFT,t,BOTTOMLEFT)
    if key=="balance" then
        -- Balance intentionally nests over Health, so its curve must render above
        -- the Health fill rather than disappearing behind the sibling control.
        t.frame:SetDrawLayer(DL_CONTROLS); t.fill:SetDrawLayer(DL_CONTROLS)
    end
    t.icon=texture(t,"_Icon",3,"/esoui/art/icons/icon_missing.dds",1,1,1,1); t.icon:SetDimensions(38,38); t.icon:SetAnchor(TOP,t,BOTTOM,0,4)
    t.expiryBorder=WM:CreateControl(t:GetName().."_ExpiryBorder",t,CT_BACKDROP); t.expiryBorder:SetDimensions(44,44); t.expiryBorder:SetAnchor(CENTER,t.icon,CENTER); t.expiryBorder:SetDrawLayer(DL_OVERLAY); t.expiryBorder:SetDrawLevel(48); t.expiryBorder:SetCenterColor(.8,0,0,.08); t.expiryBorder:SetEdgeColor(1,.05,.05,.9); t.expiryBorder:SetHidden(true)
    t.icon:SetDrawLayer(DL_OVERLAY); t.icon:SetDrawLevel(49)
    t.stackLabel=label(t.icon,"_StackLabel","ZoFontGamepadBold27"); t.stackLabel:SetAnchor(CENTER,t.icon,CENTER); t.stackLabel:SetDimensions(38,38); t.stackLabel:SetDrawLayer(DL_OVERLAY); t.stackLabel:SetDrawLevel(50); t.stackLabel:SetHidden(true)
    t.timer=label(t,"_Timer","ZoFontGamepad20"); t.timer:SetDimensions(70,30); t.timer:SetAnchor(BOTTOM,t,TOP,0,-5)
    t.appearanceBase=textureName
    t.active,t.beginTime,t.endTime,t.duration=false,0,0,0; t:SetHidden(true); self.trackers[key]=t
end

function CH:CreateProcAlert()
    local p=WM:CreateControl("CurvedHUD_FragmentsProc",self.root,CT_CONTROL); p:SetDimensions(72,72)
    p.bg=WM:CreateControl("CurvedHUD_FragmentsProc_Background",p,CT_BACKDROP); p.bg:SetAnchorFill(p); p.bg:SetCenterColor(.45,.02,.24,.72); p.bg:SetEdgeColor(1,.25,.72,1)
    p.icon=texture(p,"_Icon",4,"/esoui/art/icons/icon_missing.dds",1,1,1,1); p.icon:SetDimensions(64,64); p.icon:SetAnchor(CENTER,p,CENTER)
    local fallback=GetAbilityIcon and GetAbilityIcon(CRYSTAL_FRAGMENTS_PROC_SLOT_ID)
    if (not fallback or fallback=="") and GetAbilityIcon then fallback=GetAbilityIcon(CRYSTAL_FRAGMENTS_PROC_EFFECT_ID) end
    if fallback and fallback~="" then p.icon:SetTexture(fallback) end
    p:SetHidden(true); self.procAlert=p; self.fragmentsEventActive=false; self.fragmentsEndTime=0
end

function CH:ApplyProcLayout(scale)
    local p=self.procAlert; if not p then return end
    local procScale=clamp(tonumber(self.sv.fragmentsScale) or .75,.35,1.5)
    local size=72*scale*procScale; p:SetDimensions(size,size); p.icon:SetDimensions(64*scale*procScale,64*scale*procScale)
    p:ClearAnchors(); local position=self.sv.fragmentsPosition or "Top"; local spacing=self.sv.spacing*scale
    if position~="Top" and position~="Right" and position~="Bottom" and position~="Left" and position~="Center" then
        position="Top"; self.sv.fragmentsPosition=position
    end
    local x,y=0,0
    if position=="Center" then p:SetAnchor(CENTER,GuiRoot,CENTER,0,0); return
    elseif position=="Top" then y=-225*scale
    elseif position=="Bottom" then y=225*scale
    elseif position=="Left" then x=-spacing+92*scale
    elseif position=="Right" then x=spacing-92*scale end
    p:SetAnchor(CENTER,self.root,CENTER,x,y)
end

function CH:IsCrystalFragmentsProcActive()
    local active=self.fragmentsEventActive and (self.fragmentsEndTime<=0 or self.fragmentsEndTime>GetGameTimeSeconds())
    local iconName=nil
    if GetNumBuffs and GetUnitBuffInfo then
        for index=1,GetNumBuffs("player") do
            local name,_,endTime,_,_,icon,_,_,_,_,abilityId=GetUnitBuffInfo("player",index)
            if abilityId==CRYSTAL_FRAGMENTS_PROC_EFFECT_ID or string.find(string.lower(name or ""),"crystal fragments proc",1,true) then
                active=true; self.fragmentsEndTime=endTime or 0; iconName=icon; break
            end
        end
    end
    if GetSlotBoundId then
        local first=_G["ACTION_BAR_FIRST_NORMAL_SLOT_INDEX"] or 3; local last=_G["ACTION_BAR_ULTIMATE_SLOT_INDEX"] or 8
        for slot=first,last do
            local ok,boundId=pcall(GetSlotBoundId,slot)
            if ok and boundId==CRYSTAL_FRAGMENTS_PROC_SLOT_ID then
                active=true
                if GetSlotTexture then local okIcon,slotIcon=pcall(GetSlotTexture,slot); if okIcon then iconName=slotIcon end end
                break
            end
        end
    end
    return active,iconName
end

function CH:UpdateProcAlert()
    local p=self.procAlert; if not p then return end
    local enabled=self.sv.fragmentsEnabled~=false; local active,iconName=false,nil
    if self.sv.preview and enabled then active=true
    elseif enabled then active,iconName=self:IsCrystalFragmentsProcActive() end
    p:SetHidden(not active)
    if active then
        if iconName and iconName~="" then p.icon:SetTexture(iconName) end
        -- The alert inherits both normal HUD opacity and the optional
        -- out-of-combat opacity through its parent. Keep only a subtle local pulse.
        p.bg:SetAlpha(.72+.28*math.abs(math.sin(GetGameTimeMilliseconds()/300)))
    end
end

function CH:UpdateArmamentsReadyEffect()
    local t=self.trackers and self.trackers.armaments; if not t or not t.readyBorder then return end
    local stacks=self.sv.preview and 4 or (tonumber(t.stackCount) or 0)
    local ready=self.sv.armamentsEnabled~=false and stacks>=4 and not t.expiryAlertActive
    t.readyBorder:SetHidden(not ready)
    local selected=self.colors[self.sv.armamentsColor] or self.colors.Gold
    t.stackLabel:SetColor(ready and math.min(1,selected[1]+.25) or 1,ready and math.min(1,selected[2]+.25) or 1,ready and math.min(1,selected[3]+.25) or 1,1)
    if ready then
        local pulse=.55+.45*math.abs(math.sin(GetGameTimeMilliseconds()/260))
        -- Same larger-backdrop construction used by the Crystal Fragments alert:
        -- the icon remains above it while the white-gold perimeter stays visible.
        local blend=.30+.25*pulse
        t.readyBorder:SetCenterColor(selected[1]+(1-selected[1])*blend,selected[2]+(1-selected[2])*blend,selected[3]+(1-selected[3])*blend,.65+.3*pulse)
        t.readyBorder:SetEdgeColor(1,1,1,.8+.2*pulse)
    end
end

function CH:PhraseMatches(text,phrase)
    text,phrase=string.lower(text or ""),string.lower(phrase or "")
    if phrase=="" then return false end
    local start=1
    while true do
        local first,last=string.find(text,phrase,start,true)
        if not first then return false end
        local before=first>1 and string.sub(text,first-1,first-1) or ""
        local after=last<#text and string.sub(text,last+1,last+1) or ""
        local phraseFirst,phraseLast=string.sub(phrase,1,1),string.sub(phrase,-1)
        local leftOk=not string.find(phraseFirst,"[%w]") or before=="" or not string.find(before,"[%w]")
        local rightOk=not string.find(phraseLast,"[%w]") or after=="" or not string.find(after,"[%w]")
        if leftOk and rightOk then return true end
        start=first+1
    end
end

function CH:FindSlottedSkillIcon(...)
    if not GetSlotBoundId or not GetAbilityName then return nil end
    local wanted={...}; local first=_G["ACTION_BAR_FIRST_NORMAL_SLOT_INDEX"] or 3; local last=_G["ACTION_BAR_ULTIMATE_SLOT_INDEX"] or 8
    local categories={false,_G["HOTBAR_CATEGORY_PRIMARY"] or false,_G["HOTBAR_CATEGORY_BACKUP"] or false}
    for _,category in ipairs(categories) do
        for slot=first,last do
            local ok,id
            if category then ok,id=pcall(GetSlotBoundId,slot,category) else ok,id=pcall(GetSlotBoundId,slot) end
            if ok and id and id>0 then
                local name=string.lower(GetAbilityName(id) or "")
                for _,needle in ipairs(wanted) do
                    if self:PhraseMatches(name,needle) then
                        local okIcon,iconName
                        if GetSlotTexture and category then okIcon,iconName=pcall(GetSlotTexture,slot,category)
                        elseif GetSlotTexture then okIcon,iconName=pcall(GetSlotTexture,slot) end
                        if okIcon and iconName and iconName~="" then return iconName,id end
                        if GetAbilityIcon then local fallback=GetAbilityIcon(id); if fallback and fallback~="" then return fallback,id end end
                        -- The console API can identify a slotted skill while its
                        -- texture path is unavailable to an add-on. Keep the ID;
                        -- bundled-icon callers do not need the runtime texture.
                        return nil,id
                    end
                end
            end
        end
    end
    return nil
end

function CH:FindLearnedSkillIcon(...)
    if not GetNumSkillTypes or not GetNumSkillLines or not GetNumSkillAbilities or not GetSkillAbilityInfo then return nil end
    local wanted={...}
    for skillType=1,GetNumSkillTypes() do
        for lineIndex=1,GetNumSkillLines(skillType) do
            for abilityIndex=1,GetNumSkillAbilities(skillType,lineIndex) do
                local ok,name,textureName=pcall(GetSkillAbilityInfo,skillType,lineIndex,abilityIndex)
                local lowerName=ok and string.lower(name or "") or ""
                for _,needle in ipairs(wanted) do
                    if self:PhraseMatches(lowerName,needle) and textureName and textureName~="" then return textureName end
                end
            end
        end
    end
    return nil
end

function CH:GetShroudIcon(abilityName)
    local lowerName=string.lower(abilityName or "")
    for name,path in pairs(SHROUD_ICON_PATHS) do
        if lowerName==name or string.find(lowerName,name,1,true) then return path end
    end
    return DEFAULT_SHROUD_ICON_PATH
end

function CH:RefreshShroudBinding()
    local t=self.trackers and self.trackers.shroud; if not t then return end
    local _,abilityId=self:FindSlottedSkillIcon("vibrant shroud","shattering spines","encase")
    local abilityName=abilityId and GetAbilityName and GetAbilityName(abilityId) or ""
    local iconPath=self:GetShroudIcon(abilityName)
    t.preferredIcon=iconPath; t.icon:SetTexture(iconPath)
end

function CH:GetConfiguredAbilityDuration(abilityId,fallback)
    local duration=tonumber(fallback) or 20
    if abilityId and abilityId>0 and GetAbilityDuration then
        local ok,durationMs=pcall(GetAbilityDuration,abilityId)
        durationMs=ok and tonumber(durationMs) or 0
        -- Crafted ability IDs reflect the currently selected scripts. Some
        -- combinations still return zero, so preserve the character setting as fallback.
        -- Some abilities expose the interval to their next pulse instead of
        -- the complete parent effect. API data may extend a known duration,
        -- but must never partition it into a shorter tick window.
        if durationMs>=1000 and durationMs<=120000 then duration=math.max(duration,durationMs/1000) end
    end
    return clamp(duration,1,120)
end

function CH:RefreshScribingBindings()
    if not self.trackers then return end
    self.scribingAbilityIds=self.scribingAbilityIds or {}
    for _,definition in ipairs(self.scribingTrackerDefinitions) do
        local tracker=self.trackers[definition.key]
        if tracker then
            local slottedIcon,abilityId=self:FindSlottedDefinitionIcon(definition)
            if abilityId then self.scribingAbilityIds[definition.key]=abilityId end
            local abilityName=abilityId and GetAbilityName and GetAbilityName(abilityId) or definition.needles[1]
            self:ResolveTrackerIcon(definition,abilityName,abilityId,slottedIcon,nil,tracker)
        end
    end
    self:RefreshShroudBinding()
end

function CH:GetFamilyIcon(definition,abilityName)
    local lowerName=string.lower(abilityName or "")
    for name,path in pairs(definition.icons or {}) do
        if lowerName==name or string.find(lowerName,name,1,true) then return path end
    end
    return definition.icons and definition.icons[definition.needles[1]] or nil
end

function CH:RememberDefinitionAbilityId(definition,abilityId)
    abilityId=tonumber(abilityId)
    if not definition or definition.category or not abilityId or abilityId<=0 then return end
    local cache=self.globalSV and self.globalSV.abilityIdCache
    if not cache then return end
    if type(cache[definition.key])~="table" then cache[definition.key]={} end
    cache[definition.key][tostring(abilityId)]=true
end

function CH:IsDefinitionAbilityId(definition,abilityId,idCache)
    abilityId=tonumber(abilityId)
    if not abilityId or abilityId<=0 then return false end
    if idCache and idCache[definition.key] then
        local value=idCache[definition.key]
        if value==abilityId or type(value)=="table" and (value[abilityId] or value[tostring(abilityId)]) then return true end
    end
    for _,knownId in ipairs(definition.abilityIds or {}) do if tonumber(knownId)==abilityId then return true end end
    local learned=self.globalSV and self.globalSV.abilityIdCache and self.globalSV.abilityIdCache[definition.key]
    return type(learned)=="table" and (learned[abilityId] or learned[tostring(abilityId)]) or false
end

function CH:DefinitionMatches(definition,lowerName,abilityId,idCache)
    if self:IsDefinitionAbilityId(definition,abilityId,idCache) then return true end
    for _,needle in ipairs(definition.needles or {}) do
        if self:PhraseMatches(lowerName,needle) then
            self:RememberDefinitionAbilityId(definition,abilityId)
            return true
        end
    end
    return false
end

function CH:FindSlottedDefinitionIcon(definition)
    if not GetSlotBoundId then return nil end
    local expected={}
    if definition.icon then expected[string.lower(definition.icon)]=true end
    for _,path in pairs(definition.icons or {}) do expected[string.lower(path)]=true end
    local cached=self.globalSV and self.globalSV.iconCache and self.globalSV.iconCache[definition.key]
    if cached and cached~="" then expected[string.lower(cached)]=true end
    local first=_G["ACTION_BAR_FIRST_NORMAL_SLOT_INDEX"] or 3; local last=_G["ACTION_BAR_ULTIMATE_SLOT_INDEX"] or 8
    local categories={false,_G["HOTBAR_CATEGORY_PRIMARY"] or false,_G["HOTBAR_CATEGORY_BACKUP"] or false}
    for _,category in ipairs(categories) do
        for slot=first,last do
            local ok,id
            if category then ok,id=pcall(GetSlotBoundId,slot,category) else ok,id=pcall(GetSlotBoundId,slot) end
            if ok and id and id>0 then
                local iconName
                if GetSlotTexture then
                    local okIcon
                    if category then okIcon,iconName=pcall(GetSlotTexture,slot,category) else okIcon,iconName=pcall(GetSlotTexture,slot) end
                    if not okIcon then iconName=nil end
                end
                if (not iconName or iconName=="") and GetAbilityIcon then
                    local okIcon,value=pcall(GetAbilityIcon,id); if okIcon then iconName=value end
                end
                local idMatch=self:IsDefinitionAbilityId(definition,id)
                local iconMatch=iconName and expected[string.lower(iconName)]
                local nameMatch=false
                if not idMatch and not iconMatch and GetAbilityName then
                    local name=string.lower(GetAbilityName(id) or "")
                    for _,needle in ipairs(definition.needles or {}) do if self:PhraseMatches(name,needle) then nameMatch=true; break end end
                end
                if idMatch or iconMatch or nameMatch then
                    self:RememberDefinitionAbilityId(definition,id)
                    return iconName,id
                end
            end
        end
    end
    return nil
end

-- Shared, defensive icon chain for every definition-driven tracker. Bundled
-- artwork wins when supplied; ESO's slot, ability, learned-skill, and live
-- event paths provide independent fallbacks. A previously valid texture is
-- retained if a later API call temporarily returns no artwork.
function CH:ResolveTrackerIcon(definition,abilityName,abilityId,slottedIcon,eventIcon,tracker)
    local isSetTracker=definition.category~=nil and self.setTrackerCategories~=nil
    local iconPath=self:GetFamilyIcon(definition,abilityName) or definition.icon
    if not iconPath or iconPath=="" then iconPath=slottedIcon end
    -- For item sets, ESO's live effect artwork is authoritative. It must win
    -- over the icon of the staff, shield, or armor piece that grants the set.
    if isSetTracker and eventIcon and eventIcon~="" then iconPath=eventIcon end
    if (not iconPath or iconPath=="") and abilityId and abilityId>0 and GetAbilityIcon then
        local ok,value=pcall(GetAbilityIcon,abilityId); if ok then iconPath=value end
    end
    if (not iconPath or iconPath=="") and not isSetTracker then iconPath=self:FindLearnedSkillIcon(unpack(definition.needles or {})) end
    if not iconPath or iconPath=="" then iconPath=eventIcon end
    local savedCache=self.globalSV and (isSetTracker and self.globalSV.setEffectIconCache or self.globalSV.iconCache)
    if (not iconPath or iconPath=="") and savedCache then iconPath=savedCache[definition.key] end
    if (not iconPath or iconPath=="") and tracker then iconPath=isSetTracker and (tracker.effectIcon or tracker.equipmentFallbackIcon) or tracker.preferredIcon end
    if iconPath and iconPath~="" then
        if savedCache then savedCache[definition.key]=iconPath end
        if tracker then
            if isSetTracker then tracker.effectIcon=iconPath else tracker.preferredIcon=iconPath end
            tracker.icon:SetTexture(iconPath)
        end
    end
    return iconPath
end

function CH:RefreshDefinitionBindings(definitions,idCache)
    if not self.trackers then return end
    for _,definition in ipairs(definitions) do
        local tracker=self.trackers[definition.key]
        if tracker then
            local slottedIcon,abilityId=self:FindSlottedDefinitionIcon(definition)
            if abilityId then idCache[definition.key]=abilityId end
            local abilityName=abilityId and GetAbilityName and GetAbilityName(abilityId) or definition.needles[1]
            self:ResolveTrackerIcon(definition,abilityName,abilityId,slottedIcon,nil,tracker)
        end
    end
end

function CH:RefreshWardenBindings()
    if not self.trackers then return end
    self.wardenAbilityIds=self.wardenAbilityIds or {}
    self:RefreshDefinitionBindings(self.wardenTrackerDefinitions,self.wardenAbilityIds)
end

function CH:RefreshArcanistBindings()
    if not self.trackers then return end
    self.arcanistAbilityIds=self.arcanistAbilityIds or {}
    self:RefreshDefinitionBindings(self.arcanistTrackerDefinitions,self.arcanistAbilityIds)
end

function CH:RefreshSorcererBindings()
    if not self.trackers then return end
    self.sorcererAbilityIds=self.sorcererAbilityIds or {}
    self:RefreshDefinitionBindings(self.sorcererTrackerDefinitions,self.sorcererAbilityIds)
end

function CH:RefreshNonClassBindings()
    if not self.trackers then return end
    self.nonClassAbilityIds=self.nonClassAbilityIds or {}
    self:RefreshDefinitionBindings(self.nonClassTrackerDefinitions,self.nonClassAbilityIds)
end

function CH:RefreshRemainingClassBindings()
    if not self.trackers then return end
    for _,group in ipairs(self.remainingClassDefinitionGroups) do
        self[group.cache]=self[group.cache] or {}
        self:RefreshDefinitionBindings(group.definitions,self[group.cache])
    end
end

function CH:SetNameMatches(definition,setName)
    local lower=string.lower(setName or "")
    for _,needle in ipairs(definition.setNames or {}) do if string.find(lower,needle,1,true) then return true end end
    return false
end
function CH:RefreshEquippedSets()
    if not self.trackers then return end
    local counts,ownedCounts,icons={},{},{}
    if GetBagSize and GetItemLink and GetItemLinkSetInfo then
        local size=GetBagSize(BAG_WORN) or 0
        for slot=0,size do
            local link=GetItemLink(BAG_WORN,slot)
            if link and link~="" then
                local result={pcall(GetItemLinkSetInfo,link,false)}
                if result[1] and result[2] then
                    local setName=result[3] or ""; local lower=string.lower(setName)
                    local apiEquipped=(tonumber(result[5]) or 0)+(tonumber(result[8]) or 0)
                    counts[lower]=math.max(counts[lower] or 0,apiEquipped>0 and apiEquipped or ((counts[lower] or 0)+1))
                    -- GetItemLinkSetInfo reports only the currently active
                    -- weapon bar. Count every physically worn set item as a
                    -- second availability signal so back-bar sets survive a
                    -- weapon swap. Two-handed weapons supply two set pieces.
                    local pieceWeight=1
                    if GetItemLinkEquipType then
                        local equipType=GetItemLinkEquipType(link)
                        if EQUIP_TYPE_TWO_HAND and equipType==EQUIP_TYPE_TWO_HAND then pieceWeight=2 end
                    end
                    ownedCounts[lower]=(ownedCounts[lower] or 0)+pieceWeight
                    if GetItemLinkIcon then icons[lower]=GetItemLinkIcon(link) end
                end
            end
        end
    end
    self.jorvuldActive=false
    self.martialKnowledgeEquipped=false
    for setName,count in pairs(counts) do
        if string.find(setName,"martial knowledge",1,true) and math.max(count,ownedCounts[setName] or 0)>=5 then self.martialKnowledgeEquipped=true; break end
    end
    for _,definition in ipairs(self.setTrackerDefinitions) do
        local required=definition.requiredPieces or ((definition.category=="Arena Weapons" or definition.label=="Archdruid Devyric" or definition.label=="Nazaray" or definition.label=="Tremorscale" or definition.label=="Symphony of Blades") and 2 or 5)
        local equipped,icon=false,nil
        for setName,count in pairs(counts) do
            local availableCount=math.max(count,ownedCounts[setName] or 0)
            if self:SetNameMatches(definition,setName) and availableCount>=required then equipped,icon=true,icons[setName]; break end
        end
        local t=self.trackers[definition.key]
        if t then
            t.equipped=equipped
            local effectCache=self.globalSV and self.globalSV.setEffectIconCache
            if icon and icon~="" then t.equipmentFallbackIcon=icon end
            if t.effectIcon and t.effectIcon~="" then t.icon:SetTexture(t.effectIcon)
            elseif effectCache and effectCache[definition.key] then
                t.effectIcon=effectCache[definition.key]; t.icon:SetTexture(t.effectIcon)
            elseif t.equipmentFallbackIcon then t.icon:SetTexture(t.equipmentFallbackIcon) end
            if definition.passive then t.active=equipped end
            local now=GetGameTimeSeconds()
            local liveEffect=t.active and ((t.endTime or t.cooldownEnd or 0)>now)
            if not equipped and not liveEffect then
                t.active=false; t.stackCount=0; t.cooldownEnd=0; t.conditionActive=false; t.conditionEndTime=0; t.setEffectInstances={}
            end
        end
        if definition.key=="setJorvulds" then self.jorvuldActive=equipped end
    end
end

function CH:UpdateMartialKnowledgeStaminaCue(current,maximum)
    local bar=self.bars and self.bars.stamina
    if not bar or not bar.fill then return end
    if self.sv.martialKnowledgeStaminaCue and (self.sv.preview or self.martialKnowledgeEquipped) and (maximum or 0)>0 then
        if current/maximum<.5 then bar.fill:SetColor(.52,1,.58,self.sv.fillAlpha)
        else bar.fill:SetColor(1,.48,.48,self.sv.fillAlpha) end
    else
        -- The resource textures already contain their authored gradient; white
        -- restores the normal Stamina artwork without flattening that gradient.
        bar.fill:SetColor(1,1,1,self.sv.fillAlpha)
    end
end

function CH:CacheExternalTrackerControls()
    local controls={}
    local function add(control)
        if not control or not control.SetAlpha then return end
        for _,existing in ipairs(controls) do if existing==control then return end end
        controls[#controls+1]=control
    end
    local function addQuestControl(control)
        add(control)
        -- The assisted quest title is a sibling of the objective/details area
        -- in some gamepad builds. Include quest-tracker parents, but stop before
        -- reaching shared HUD roots that would hide unrelated interface pieces.
        local parent=control and control.GetParent and control:GetParent()
        for _=1,2 do
            if not parent then break end
            local name=parent.GetName and parent:GetName() or ""
            if not string.find(name,"QuestTracker",1,true) and not string.find(name,"FocusedQuest",1,true) then break end
            add(parent)
            parent=parent.GetParent and parent:GetParent() or nil
        end
    end
    local function addQuestTree(control,depth)
        if not control or (depth or 0)>7 then return end
        add(control)
        if control.GetNumChildren and control.GetChild then
            local count=control:GetNumChildren() or 0
            for index=1,count do addQuestTree(control:GetChild(index),(depth or 0)+1) end
        end
    end
    if FOCUSED_QUEST_TRACKER and FOCUSED_QUEST_TRACKER.GetContainerControl then addQuestControl(FOCUSED_QUEST_TRACKER:GetContainerControl()) end
    addQuestControl(ZO_FocusedQuestTrackerPanel)
    addQuestControl(ZO_FocusedQuestTrackerPanelContainer)
    addQuestControl(ZO_FocusedQuestTrackerPanelContainerQuestContainer)
    addQuestControl(ZO_FocusedQuestTrackerPanelContainerQuestContainerAssisted)
    addQuestControl(ZO_FocusedQuestTrackerPanelContainerQuestContainerAssistedHeader)
    addQuestControl(ZO_FocusedQuestTrackerPanelContainerQuestContainerAssistedHeaderQuestName)
    addQuestControl(ZO_FocusedQuestTrackerPanelContainerQuestContainerAssistedQuest)
    addQuestControl(ZO_FocusedQuestTrackerPanelContainerQuestContainerAssistedQuestHeader)
    addQuestControl(ZO_FocusedQuestTrackerPanelContainerQuestContainerAssistedQuestName)
    addQuestControl(ZO_FocusedQuestTrackerPanelContainerQuestContainerTrackedHeader1)
    addQuestControl(ZO_FocusedQuestTrackerPanelContainerQuestContainerTrackedHeader2)
    -- Platform layouts create some title controls late and under different
    -- names. Traverse only the focused-quest containers so the remaining yellow
    -- title is included without affecting unrelated HUD controls.
    addQuestTree(ZO_FocusedQuestTrackerPanelContainer,0)
    addQuestTree(ZO_FocusedQuestTrackerPanelContainerQuestContainer,0)
    if WM and WM.GetControlByName then
        for _,name in ipairs({
            "ZO_FocusedQuestTrackerPanelContainerQuestContainerAssistedHeaderQuestName",
            "ZO_FocusedQuestTrackerPanelContainerQuestContainerAssistedQuestName",
            "ZO_FocusedQuestTrackerPanelContainerQuestContainerQuestName",
            "ZO_FocusedQuestTrackerPanelContainerQuestContainerHeaderQuestName",
        }) do addQuestControl(WM:GetControlByName(name)) end
    end
    add(PROMOTIONAL_EVENT_TRACKER)
    add(ZO_PromotionalEventTracker_TL)
    self.externalTrackerControls=controls
    self.lastExternalTrackerCacheAt=GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
end

function CH:UpdateExternalTrackerOpacity()
    if not self.sv.reduceQuestTrackersInCombat and not self.sv.reduceQuestTrackersInInstances and not self.externalTrackersReduced then return end
    local inCombat=IsUnitInCombat and IsUnitInCombat("player") or false
    local inInstance=IsUnitInDungeon and IsUnitInDungeon("player") or false
    if not inInstance and GetUnitZoneIndex and GetZoneDisplayType then
        local displayType=GetZoneDisplayType(GetUnitZoneIndex("player"))
        inInstance=(ZONE_DISPLAY_TYPE_DUNGEON and displayType==ZONE_DISPLAY_TYPE_DUNGEON)
            or (ZONE_DISPLAY_TYPE_RAID and displayType==ZONE_DISPLAY_TYPE_RAID)
            or (ZONE_DISPLAY_TYPE_ENDLESS_DUNGEON and displayType==ZONE_DISPLAY_TYPE_ENDLESS_DUNGEON)
    end
    local restricted=(self.sv.reduceQuestTrackersInCombat and inCombat) or (self.sv.reduceQuestTrackersInInstances and inInstance)
    local targetAlpha=restricted and clamp(tonumber(self.sv.reducedQuestTrackerOpacity) or 0,0,1) or 1
    self.externalTrackerBaseAlpha=self.externalTrackerBaseAlpha or {}
    -- Refresh on entry and periodically while restricted because ESO can build
    -- or replace the focused quest title after the rest of its tracker exists.
    local cacheNow=GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
    if not self.externalTrackerControls or (restricted and not self.externalTrackersReduced) or (restricted and cacheNow-(self.lastExternalTrackerCacheAt or 0)>5000) then self:CacheExternalTrackerControls() end
    for _,control in ipairs(self.externalTrackerControls) do
        if self.externalTrackerBaseAlpha[control]==nil then
            self.externalTrackerBaseAlpha[control]=control.GetAlpha and control:GetAlpha() or 1
        end
        control:SetAlpha(restricted and targetAlpha or self.externalTrackerBaseAlpha[control])
    end
    self.externalTrackersReduced=restricted
end
function CH:SetEffectMatches(needles,effectName)
    local lower=string.lower(effectName or "")
    for _,needle in ipairs(needles or {}) do if string.find(lower,needle,1,true) then return true end end
    return false
end
function CH:RefreshSetDurationFromInstances(t,definition,now)
    local latestEnd,latestBegin,totalStacks=0,now,0
    for key,instance in pairs(t.setEffectInstances or {}) do
        if (instance.endTime or 0)<=now then
            t.setEffectInstances[key]=nil
        else
            if instance.endTime>latestEnd then latestEnd,latestBegin=instance.endTime,instance.beginTime or now end
            if definition.displayStacks then totalStacks=totalStacks+math.max(1,tonumber(instance.stackCount) or 0) end
        end
    end
    if latestEnd>now then
        t.active=true; t.beginTime=latestBegin; t.endTime=latestEnd
        t.duration=math.max(.01,latestEnd-latestBegin)
        if definition.displayStacks then t.stackCount=math.min(definition.stackLimit or totalStacks,totalStacks) end
    else
        t.active=false; t.stackCount=0
    end
end

function CH:OnSetEffectChanged(changeType,effectName,unitTag,beginTime,endTime,stackCount,iconName,abilityId)
    if not self.trackers then return end
    local now=GetGameTimeSeconds()
    for _,definition in ipairs(self.setTrackerDefinitions) do
        if self.sv[definition.key.."Enabled"] and (self.sv.preview or (self.trackers[definition.key] and self.trackers[definition.key].equipped)) then
            local t=self.trackers[definition.key]
            local conditionMatch=self:SetEffectMatches(definition.conditionNeedles,effectName)
            local effectMatch=self:SetEffectMatches(definition.needles,effectName)
            if conditionMatch then
                if changeType==EFFECT_RESULT_FADED then
                    local wasArmed=t.conditionActive
                    local expectedEnd=t.conditionEndTime or 0
                    t.conditionActive=false
                    -- Turning Tide's Flowing Water is consumed by the Bash that
                    -- activates the set. An early fade is therefore the most
                    -- reliable player-side activation signal; begin the full
                    -- set cooldown instead of falling straight back to WAIT.
                    if definition.key=="setTurningTide" and wasArmed and expectedEnd>now+.25 then
                        t.cooldownEnd=now+(definition.cooldown or 15)
                        t.active=true; t.beginTime=now; t.endTime=t.cooldownEnd; t.duration=definition.cooldown or 15
                    end
                else
                    t.conditionActive=true
                    t.conditionEndTime=endTime or 0
                end
            end
            if effectMatch then
                self:ResolveTrackerIcon(definition,effectName,abilityId,nil,iconName,t)
                if changeType==EFFECT_RESULT_FADED and not definition.cooldown then
                    local instanceKey=tostring(unitTag or "").."|"..tostring(abilityId or 0).."|"..string.lower(effectName or "")
                    t.setEffectInstances=t.setEffectInstances or {}
                    local instance=t.setEffectInstances[instanceKey]
                    -- ESO can deliver the FADED event for an older application
                    -- after UPDATED/Gained has already supplied a later end time.
                    -- Never let that stale fade erase the refreshed instance.
                    if not instance or (endTime or 0)<=0 or (instance.endTime or 0)<=(endTime or 0)+.1 then t.setEffectInstances[instanceKey]=nil end
                    self:RefreshSetDurationFromInstances(t,definition,now)
                elseif changeType~=EFFECT_RESULT_FADED then
                    if definition.cooldown then
                        t.cooldownEnd=now+definition.cooldown; t.active=true; t.beginTime=now; t.endTime=t.cooldownEnd; t.duration=definition.cooldown
                    else
                        local duration=(endTime or 0)-(beginTime or 0); if duration<=0 then duration=definition.duration or 1 end
                        local instanceKey=tostring(unitTag or "").."|"..tostring(abilityId or 0).."|"..string.lower(effectName or "")
                        t.setEffectInstances=t.setEffectInstances or {}
                        t.setEffectInstances[instanceKey]={beginTime=(beginTime or 0)>0 and beginTime or now,endTime=(endTime or 0)>now and endTime or now+duration,stackCount=stackCount or 0}
                        self:RefreshSetDurationFromInstances(t,definition,now)
                    end
                end
            end
        end
    end
    self:UpdateTrackers()
end

function CH:RefreshLegacyIconFallbacks()
    if not self.trackers then return end
    local definitions={
        {key="balance",needles={"equilibrium","balance","spell symmetry"},abilityId=48136},
        {key="aegis",needles={"bound aegis","bound armor"},abilityId=24163},
        {key="armaments",needles={"bound armaments"},abilityId=BOUND_ARMAMENTS_SKILL_ID},
        {key="surge",needles={"critical surge","surge"},abilityId=CRITICAL_SURGE_EFFECT_ID},
    }
    for _,buffDefinition in ipairs(self.standardBuffTrackerDefinitions) do
        local selected=self.sv[buffDefinition.selectionSetting]
        if selected and selected~="None" then definitions[#definitions+1]={key=buffDefinition.key,needles={string.lower(selected)},abilityId=MAJOR_BUFF_IDS[selected]} end
    end
    for _,definition in ipairs(definitions) do
        local tracker=self.trackers[definition.key]
        if tracker then
            local slottedIcon,slottedId=self:FindSlottedSkillIcon(unpack(definition.needles))
            self:ResolveTrackerIcon(definition,definition.needles[1],slottedId or definition.abilityId,slottedIcon,nil,tracker)
        end
    end
    self:RefreshShroudBinding()
    local proc=self.procAlert
    if proc then
        local iconPath,abilityId=self:FindSlottedSkillIcon("crystal fragments","crystal frags")
        if (not iconPath or iconPath=="") and GetAbilityIcon then iconPath=GetAbilityIcon(abilityId or CRYSTAL_FRAGMENTS_PROC_SLOT_ID) end
        if not iconPath or iconPath=="" then iconPath=self:FindLearnedSkillIcon("crystal fragments","crystal frags") end
        local savedCache=self.globalSV and self.globalSV.iconCache
        if (not iconPath or iconPath=="") and savedCache then iconPath=savedCache.crystalFragments end
        if iconPath and iconPath~="" then
            proc.preferredIcon=iconPath; proc.icon:SetTexture(iconPath)
            if savedCache then savedCache.crystalFragments=iconPath end
        elseif proc.preferredIcon then proc.icon:SetTexture(proc.preferredIcon) end
    end
end

function CH:RefreshAllTrackerIcons()
    self:RefreshScribingBindings()
    self:RefreshSorcererBindings()
    self:RefreshWardenBindings()
    self:RefreshArcanistBindings()
    self:RefreshRemainingClassBindings()
    self:RefreshNonClassBindings()
    self:RefreshLegacyIconFallbacks()
end

function CH:QueueTrackerIconRefresh(delayMs)
    if not zo_callLater then self:RefreshAllTrackerIcons(); return end
    self.iconRefreshGeneration=(self.iconRefreshGeneration or 0)+1
    local generation=self.iconRefreshGeneration
    zo_callLater(function()
        if generation~=self.iconRefreshGeneration or not self.trackers then return end
        self.scribingAbilityIds=self.scribingAbilityIds or {}
        self.sorcererAbilityIds=self.sorcererAbilityIds or {}
        self.wardenAbilityIds=self.wardenAbilityIds or {}
        self.arcanistAbilityIds=self.arcanistAbilityIds or {}
        self.nonClassAbilityIds=self.nonClassAbilityIds or {}
        local queue={}
        local function add(definitions,cache)
            for _,definition in ipairs(definitions) do
                if self.trackers[definition.key] then queue[#queue+1]={definition,cache} end
            end
        end
        add(self.scribingTrackerDefinitions,self.scribingAbilityIds)
        add(self.sorcererTrackerDefinitions,self.sorcererAbilityIds)
        add(self.wardenTrackerDefinitions,self.wardenAbilityIds)
        add(self.arcanistTrackerDefinitions,self.arcanistAbilityIds)
        for _,group in ipairs(self.remainingClassDefinitionGroups) do
            self[group.cache]=self[group.cache] or {}; add(group.definitions,self[group.cache])
        end
        add(self.nonClassTrackerDefinitions,self.nonClassAbilityIds)
        local index=1
        local function processNext()
            if generation~=self.iconRefreshGeneration then return end
            local item=queue[index]
            if not item then
                self:Guard("legacy icon refresh",function() self:RefreshLegacyIconFallbacks() end)
                self.iconRefreshComplete=true
                return
            end
            index=index+1
            self:Guard("queued icon refresh",function() self:RefreshDefinitionBindings({item[1]},item[2]) end)
            zo_callLater(processNext,25)
        end
        processNext()
    end,delayMs or 350)
end

function CH:QueueWornSetRefresh(delayMs)
    if not zo_callLater then self:RefreshEquippedSets(); return end
    self.wornSetRefreshGeneration=(self.wornSetRefreshGeneration or 0)+1
    local generation=self.wornSetRefreshGeneration
    zo_callLater(function()
        if generation~=self.wornSetRefreshGeneration or not self.trackers then return end
        self:Guard("queued worn set refresh",function()
            self:RefreshEquippedSets(); self:UpdateResources(); self:UpdateTrackers()
        end)
    end,delayMs or 250)
end

function CH:ApplyTrackerAppearance(t)
    local info=self.trackerSlots[t.slot]
    local base=self:GetTrackerAppearanceBase(t.slot,t.specialTexture)
    if t.appearanceBase~=base then
        t.frame:SetTexture("CurvedHUD/textures/"..base.."_frame.dds")
        t.fill:SetTexture("CurvedHUD/textures/"..base..".dds")
        t.appearanceBase=base
    end
    t.u1,t.u2=info.side=="left" and 1 or 0,info.side=="left" and 0 or 1
    local color=self.colors[self.sv[t.colorSetting]] or self.colors.White
    t.fill:SetColor(color[1],color[2],color[3],self.sv.fillAlpha)
end

function CH:SyncBarLayers(b)
    local w,h=b:GetDimensions()
    for _,layer in ipairs({b.bg,b.frame,b.overcap}) do
        if layer then layer:ClearAnchors(); layer:SetAnchor(TOPLEFT,b,TOPLEFT); layer:SetDimensions(w,h) end
    end
end
function CH:SyncTrackerLayers(t)
    local w,h=t:GetDimensions()
    t.frame:ClearAnchors(); t.frame:SetAnchor(TOPLEFT,t,TOPLEFT); t.frame:SetDimensions(w,h); t.frame:SetTextureCoords(t.u1,t.u2,0,1)
end
function CH:SetMountTexture(kind)
    local b=self.mountBar; if not b then return end
    if b.textureKind==kind then return end
    b.textureKind=kind
    b.bg:SetTexture("CurvedHUD/textures/mount_"..kind..".dds")
    b.fill:SetTexture("CurvedHUD/textures/mount_"..kind..".dds")
    b.frame:SetTexture("CurvedHUD/textures/mount_"..kind.."_frame.dds")
end
function CH:SetResourceTexture(b,kind)
    if not b or b.key=="health" or b.textureKind==kind then return end
    b.textureKind=kind
    if kind=="standard" then
        b.bg:SetTexture("CurvedHUD/textures/arc_full.dds")
        b.frame:SetTexture("CurvedHUD/textures/arc_full.dds")
        b.fill:SetTexture("CurvedHUD/textures/arc_"..b.key.."_gradient.dds")
    else
        b.bg:SetTexture("CurvedHUD/textures/arc_resource_"..kind..".dds")
        b.frame:SetTexture("CurvedHUD/textures/arc_resource_"..kind..".dds")
        b.fill:SetTexture("CurvedHUD/textures/arc_"..b.key.."_"..kind.."_gradient.dds")
    end
end

function CH:ApplyTrackerSlot(t,h,inner,outer,width,scale)
    local info=self.trackerSlots[t.slot]; if not info then return end
    local style=info.inside and self.sv.insideTimerStyle or self.sv.outsideTimerStyle
    local legacyBalance=t.key=="balance" and t.slot=="bottomLeftInside"
    local legacyAegis=t.key=="aegis" and t.slot=="topLeftOutside"
    local trackerWidth
    if style=="Thick" then trackerWidth=42
    elseif info.inside then trackerWidth=38
    else trackerWidth=52 end
    if style=="Thin" and info.side=="right" and not info.inside then trackerWidth=38 end
    local trackerHeight=info.inside and 145 or 180
    local radiusScale=info.side=="right" and not info.inside and self.sv.layout=="Parallel" and (style=="Thin" and .8 or .5) or 1
    -- Every timer curve was calibrated at Bar Width 72. Scale only its
    -- horizontal texture dimension with Bar Width so its radius continues to
    -- match the resource curve; HUD Scale is applied independently afterward.
    local barRadiusScale=clamp(tonumber(self.sv.barWidth) or 72,24,80)/72
    t:SetDimensions(trackerWidth*radiusScale*barRadiusScale*scale,trackerHeight*scale); t:ClearAnchors()

    local innerNudge=style=="Thick" and 5 or 0
    -- Counter-shift the wider outer-Thin control so its midpoint remains
    -- stable while the far endpoint gains the missing horizontal sweep.
    local outerNudge=style=="Thick" and 5 or 22
    local function widthCorrection(ideal,current)
        local delta=(ideal-current)*.5
        return delta>=0 and delta*.90 or delta*.35
    end
    local leftCorrection=widthCorrection(72,h:GetWidth()/scale)
    local leftOffset=tonumber(self.sv.leftTimerOffset) or 0
    local leftSpacing=(tonumber(self.sv.leftTimerSpacing) or 0)*.5
    if t.key=="resolve" then t:SetAnchor(BOTTOMRIGHT,h,BOTTOMLEFT,(40+outerNudge-leftCorrection-leftSpacing+leftOffset)*scale,-42*scale)
    elseif legacyBalance then t:SetAnchor(BOTTOMLEFT,h,BOTTOMRIGHT,(-46+innerNudge+leftCorrection+leftSpacing+leftOffset)*scale,-62*scale)
    elseif legacyAegis then t:SetAnchor(TOPRIGHT,h,TOPLEFT,(40+outerNudge-leftCorrection-leftSpacing+leftOffset)*scale,42*scale)
    elseif info.side=="left" then
        local x=info.inside and (-46+innerNudge+leftCorrection+leftSpacing) or (40+outerNudge-leftCorrection-leftSpacing)
        x=x+leftOffset
        local y=info.inside and 62 or 42
        if info.vertical=="upper" then t:SetAnchor(info.inside and TOPLEFT or TOPRIGHT,h,info.inside and TOPRIGHT or TOPLEFT,x*scale,y*scale)
        else t:SetAnchor(info.inside and BOTTOMLEFT or BOTTOMRIGHT,h,info.inside and BOTTOMRIGHT or BOTTOMLEFT,x*scale,-y*scale) end
    else
        -- Parallel uses radial inner/outer resource references. In Stacked,
        -- ESO's anchored controls render `outer` on the visual upper half and
        -- `inner` on the visual lower half, so map by the rendered quadrant;
        -- otherwise the named upper/lower slots appear exchanged.
        local ref
        if self.sv.layout=="Stacked" then ref=info.vertical=="upper" and outer or inner
        else ref=info.inside and inner or outer end
        local idealRightWidth=self.sv.layout=="Stacked" and 72 or math.floor(72*.62)
        local rightCorrection=widthCorrection(idealRightWidth,ref:GetWidth()/scale)
        local rightOffset=tonumber(self.sv.rightTimerOffset) or 0
        -- The shared spacing slider is calibrated to Thin. Thick retains its
        -- tested five-point inward correction without adding another setting.
        local rightSpacing=((tonumber(self.sv.rightTimerSpacing) or 0)+(style=="Thick" and -5 or 0))*.5
        local rightOuterNudge=style=="Thick" and 10 or 22
        -- Upper/lower inside slots share one horizontal alignment. Outside slots
        -- retain identical curve geometry but use independent quadrant offsets.
        local outsideBase=-18
        local x=info.inside and (24-innerNudge-rightCorrection-rightSpacing) or (outsideBase-rightOuterNudge+rightCorrection+rightSpacing)
        x=x+rightOffset
        if info.vertical=="upper" then t:SetAnchor(info.inside and TOPRIGHT or TOPLEFT,ref,info.inside and TOPLEFT or TOPRIGHT,x*scale,42*scale)
        else t:SetAnchor(info.inside and BOTTOMRIGHT or BOTTOMLEFT,ref,info.inside and BOTTOMLEFT or BOTTOMRIGHT,x*scale,-42*scale) end
    end

    self:ApplyTrackerAppearance(t); self:SyncTrackerLayers(t)
    t.timer:SetScale(scale); t.icon:SetScale(scale)
    if t.readyBorder then t.readyBorder:SetScale(scale) end
    if t.expiryBorder then t.expiryBorder:SetScale(scale) end
    -- Icons move radially away from their timer endpoint: toward screen center
    -- for inside slots and away from center for outside slots.
    local iconX
    if info.vertical=="upper" then
        if info.side=="left" then iconX=info.inside and 40 or -64
        else iconX=info.inside and -40 or 64 end
    elseif info.side=="left" then iconX=info.inside and 48 or -42
    else iconX=info.inside and -48 or 42 end
    -- Use two shared icon rows. Timer controls retain their independently tuned
    -- curves and horizontal offsets, while every upper icon and every lower icon
    -- receives an identical absolute vertical position.
    local trackerCenterX=t:GetCenter()
    local rootCenterX=self.root and self.root:GetCenter()
    t.icon:ClearAnchors()
    if trackerCenterX and rootCenterX and self.root then
        local rowY=info.vertical=="upper" and -55 or 193
        t.icon:SetAnchor(CENTER,self.root,CENTER,(trackerCenterX-rootCenterX)+iconX*scale,rowY*scale)
    else
        t.icon:SetAnchor(TOP,t,BOTTOM,iconX*scale,(legacyAegis and -58 or -40)*scale)
    end
    t.timer:SetFont(string.format("$(GAMEPAD_MEDIUM_FONT)|%d|soft-shadow-thick",math.floor(self.sv.timerFontSize or 24)))
    t.timer:ClearAnchors(); t.timer:SetAnchor(BOTTOM,t.icon,TOP,0,-2*scale)
end

function CH:ConfigureDefinitionTracker(definition)
    local t=self.trackers[definition.key]
    if not t then
        self:CreateTracker(definition.key,definition.slot,definition.key.."Color")
        t=self.trackers[definition.key]
    end
    t.trackerDefinition=definition
    t.stackMaximum=definition.stackMaximum
    t.isNegative=definition.negative==true
    if definition.category and self.setTrackerCategories then
        t.setDefinition=definition; t.cooldownMode=definition.cooldown~=nil; t.cooldownDuration=definition.cooldown
        t.readyMode=definition.readyMode; t.passiveMode=definition.passive==true
        t.displayStacks=definition.displayStacks; t.stackLimit=definition.stackLimit
    end
    return t
end

function CH:EnsureEnabledDefinitionTrackers()
    local groups={self.scribingTrackerDefinitions,self.sorcererTrackerDefinitions,self.wardenTrackerDefinitions,self.arcanistTrackerDefinitions,self.nonClassTrackerDefinitions,self.setTrackerDefinitions}
    for _,group in ipairs(self.remainingClassDefinitionGroups) do groups[#groups+1]=group.definitions end
    for _,definitions in ipairs(groups) do
        for _,definition in ipairs(definitions) do
            if self.sv[definition.key.."Enabled"] and not self.trackers[definition.key] then self:ConfigureDefinitionTracker(definition) end
        end
    end
end

function CH:EnsureOptionalCoreTrackers()
    local function ensureLegacy(key,slot,color,special)
        if self.sv[key.."Enabled"] and not self.trackers[key] then self:CreateTracker(key,slot,color,special) end
    end
    ensureLegacy("balance","bottomLeftInside","balanceColor","balance")
    ensureLegacy("aegis","topLeftOutside","aegisColor")
    ensureLegacy("armaments","topRightInside","armamentsColor")
    ensureLegacy("surge","topRightOutside","surgeColor")
    ensureLegacy("shroud","bottomRightOutside","shroudColor")
    if self.trackers.armaments and not self.trackers.armaments.readyBorder then
        local armaments=self.trackers.armaments
        local armamentsIcon=GetAbilityIcon and GetAbilityIcon(BOUND_ARMAMENTS_SKILL_ID)
        if armamentsIcon and armamentsIcon~="" then armaments.icon:SetTexture(armamentsIcon) end
        local readyBorder=WM:CreateControl("CurvedHUD_armaments_ReadyBorder",armaments,CT_BACKDROP)
        readyBorder:SetDimensions(44,44); readyBorder:SetAnchor(CENTER,armaments.icon,CENTER); readyBorder:SetDrawLayer(DL_OVERLAY); readyBorder:SetDrawLevel(50); readyBorder:SetCenterColor(1,.78,.2,.9); readyBorder:SetEdgeColor(1,1,1,1); readyBorder:SetHidden(true)
        armaments.icon:SetDrawLayer(DL_OVERLAY); armaments.icon:SetDrawLevel(51); armaments.stackLabel:SetDrawLayer(DL_OVERLAY); armaments.stackLabel:SetDrawLevel(52); armaments.readyBorder=readyBorder
    end
    if self.sv.fragmentsEnabled and not self.procAlert then self:CreateProcAlert() end
    for _,definition in ipairs(self.standardBuffTrackerDefinitions) do
        if self.sv[definition.selectionSetting]~="None" and not self.trackers[definition.key] then
            self:CreateTracker(definition.key,definition.slot,definition.colorSetting)
            self.trackers[definition.key].selectionSetting=definition.selectionSetting
        end
    end
    if self.sv.cruxEnabled and not self.trackers.crux then
        self:CreateTracker("crux","topLeftOutside","cruxColor")
        for _,definition in ipairs(self.arcanistTrackerDefinitions) do if definition.key=="crux" then self:ConfigureDefinitionTracker(definition); break end end
        self:CreateTracker("cruxDuration","topLeftInside","cruxColor")
        self.trackers.cruxDuration.enableSetting="cruxEnabled"; self.trackers.cruxDuration.suppressIcon=true; self.trackers.cruxDuration.icon:SetHidden(true)
    end
end

function CH:ApplyLayout()
    if not self.root then return end
    self:EnsureOptionalCoreTrackers()
    self:EnsureEnabledDefinitionTrackers()
    local sv=self.sv; local scale=clamp(sv.scale,.5,1.5)
    -- Scale dimensions and offsets explicitly. Root transforms caused texture layers to
    -- round independently on console and visibly separate above scale 1.
    self.root:SetScale(1); self.root:ClearAnchors(); self.root:SetAnchor(CENTER,GuiRoot,CENTER,0,sv.verticalOffset)
    local h,s,m=self.bars.health,self.bars.stamina,self.bars.magicka; local width=clamp(sv.barWidth,24,80)*scale
    local balanceSlot=self:NormalizeTrackerSlot(sv.balanceSlot,"bottomLeftInside")
    local aegisSlot=self:NormalizeTrackerSlot(sv.aegisSlot,"topLeftOutside")
    local armamentsSlot=self:NormalizeTrackerSlot(sv.armamentsSlot,"topRightInside")
    local surgeSlot=self:NormalizeTrackerSlot(sv.surgeSlot,"topRightOutside")
    local shroudSlot=self:NormalizeTrackerSlot(sv.shroudSlot,"bottomRightOutside")
    if balanceSlot~=sv.balanceSlot then sv.balanceSlot=balanceSlot end
    if aegisSlot~=sv.aegisSlot then sv.aegisSlot=aegisSlot end
    if armamentsSlot~=sv.armamentsSlot then sv.armamentsSlot=armamentsSlot end
    if surgeSlot~=sv.surgeSlot then sv.surgeSlot=surgeSlot end
    if shroudSlot~=sv.shroudSlot then sv.shroudSlot=shroudSlot end
    if self.trackers.balance then self.trackers.balance.slot=balanceSlot end
    if self.trackers.aegis then self.trackers.aegis.slot=aegisSlot end
    if self.trackers.armaments then self.trackers.armaments.slot=armamentsSlot end
    if self.trackers.surge then self.trackers.surge.slot=surgeSlot end
    if self.trackers.shroud then self.trackers.shroud.slot=shroudSlot end
    for _,definition in ipairs(self.standardBuffTrackerDefinitions) do
        local slot=self:NormalizeTrackerSlot(sv[definition.slotSetting],definition.slot)
        if slot~=sv[definition.slotSetting] then sv[definition.slotSetting]=slot end
        if self.trackers[definition.key] then self.trackers[definition.key].slot=slot end
    end
    local layoutGroups={self.scribingTrackerDefinitions,self.sorcererTrackerDefinitions,self.wardenTrackerDefinitions,self.arcanistTrackerDefinitions,self.nonClassTrackerDefinitions,self.setTrackerDefinitions}
    for _,group in ipairs(self.remainingClassDefinitionGroups) do layoutGroups[#layoutGroups+1]=group.definitions end
    for _,definitions in ipairs(layoutGroups) do
        for _,definition in ipairs(definitions) do
            if not definition.stackOnly then
                local setting=definition.key.."Slot"; local slot=self:NormalizeTrackerSlot(sv[setting],definition.slot)
                if slot~=sv[setting] then sv[setting]=slot end
                local tracker=self.trackers[definition.key]
                if tracker then tracker.slot=slot end
            end
        end
    end
    local cruxQuadrant=self:NormalizeCruxQuadrant(sv.cruxQuadrant)
    if cruxQuadrant~=sv.cruxQuadrant then sv.cruxQuadrant=cruxQuadrant end
    if self.trackers.crux then self.trackers.crux.slot=cruxQuadrant.."Outside" end
    if self.trackers.cruxDuration then self.trackers.cruxDuration.slot=cruxQuadrant.."Inside" end
    h:SetDimensions(width,512*scale); h:ClearAnchors(); h:SetAnchor(CENTER,self.root,CENTER,-sv.spacing*scale,0)
    local inner,outer=sv.staminaInside and s or m,sv.staminaInside and m or s
    if sv.layout=="Stacked" then
        inner:SetDimensions(width,252*scale); outer:SetDimensions(width,252*scale)
        inner:ClearAnchors(); inner:SetAnchor(TOP,self.root,CENTER,sv.spacing*scale,-4*scale); outer:ClearAnchors(); outer:SetAnchor(BOTTOM,self.root,CENTER,sv.spacing*scale,4*scale)
        self:SetBarSegment(inner,"upper"); self:SetBarSegment(outer,"lower")
        self:SetResourceTexture(inner,"standard"); self:SetResourceTexture(outer,"standard")
        local mount=self.mountBar; mount:SetDimensions(width,252*scale)
        mount:ClearAnchors(); mount:SetAnchor(CENTER,s,CENTER,width*.22,0)
        self:SetMountTexture("stacked_outer"); self:SetBarSegment(mount,s.segment)
    else
        local narrow=math.max(20*scale,math.floor(width*.62))
        local outerRadiusScale=.8
        inner:SetDimensions(narrow,512*scale); outer:SetDimensions(narrow*outerRadiusScale,512*scale)
        inner:ClearAnchors(); inner:SetAnchor(CENTER,self.root,CENTER,sv.spacing*scale,0); outer:ClearAnchors(); outer:SetAnchor(CENTER,inner,CENTER,math.max(4*scale,math.floor(narrow*.28))+sv.resourceGap*scale,0)
        self:SetBarSegment(inner,"full"); self:SetBarSegment(outer,"full")
        self:SetResourceTexture(inner,"inner"); self:SetResourceTexture(outer,"outer")
        local mount=self.mountBar; mount:SetDimensions(narrow*(sv.staminaInside and 1 or outerRadiusScale),512*scale)
        mount:ClearAnchors()
        if sv.staminaInside then
            mount:SetAnchor(CENTER,s,CENTER,-11*scale,0); self:SetMountTexture("parallel_inner")
        else
            mount:SetAnchor(CENTER,s,CENTER,11*scale,0); self:SetMountTexture("parallel_outer")
        end
        self:SetBarSegment(mount,"full")
    end
    self:SyncBarLayers(h); self:SyncBarLayers(s); self:SyncBarLayers(m); self:SyncBarLayers(self.mountBar)
    -- Independent controls keep raw values aligned above percentages on every bar.
    for _,b in pairs(self.bars) do
        b.rawLabel:SetFont(string.format("$(GAMEPAD_MEDIUM_FONT)|%d|soft-shadow-thick",math.floor(sv.resourceValueFontSize or 27)))
        b.percentLabel:SetFont(string.format("$(GAMEPAD_MEDIUM_FONT)|%d|soft-shadow-thick",math.floor(sv.resourcePercentFontSize or 20)))
        b.rawLabel:SetScale(scale); b.percentLabel:SetScale(scale)
    end
    h.rawLabel:ClearAnchors(); h.rawLabel:SetAnchor(CENTER,h,CENTER,0,-20*scale)
    h.percentLabel:ClearAnchors(); h.percentLabel:SetAnchor(CENTER,h,CENTER,0,16*scale)
    s.rawLabel:ClearAnchors(); s.rawLabel:SetAnchor(CENTER,s,CENTER,8*scale,-54*scale); s.percentLabel:ClearAnchors(); s.percentLabel:SetAnchor(CENTER,s,CENTER,8*scale,-24*scale)
    m.rawLabel:ClearAnchors(); m.rawLabel:SetAnchor(CENTER,m,CENTER,8*scale,24*scale); m.percentLabel:ClearAnchors(); m.percentLabel:SetAnchor(CENTER,m,CENTER,8*scale,54*scale)
    for _,t in pairs(self.trackers) do self:ApplyTrackerSlot(t,h,inner,outer,width,scale) end
    self:ApplyProcLayout(scale)
    for _,b in pairs(self.bars) do b.bg:SetAlpha(sv.backgroundAlpha); b.fill:SetAlpha(sv.fillAlpha); b.frame:SetAlpha(sv.frameAlpha); b.rawLabel:SetAlpha(sv.textAlpha); b.percentLabel:SetAlpha(sv.textAlpha) end
    self.mountBar.bg:SetAlpha(sv.backgroundAlpha); self.mountBar.fill:SetAlpha(sv.fillAlpha); self.mountBar.frame:SetAlpha(sv.frameAlpha)
    for _,t in pairs(self.trackers) do t.fill:SetAlpha(sv.fillAlpha); t.frame:SetAlpha(sv.frameAlpha); t.timer:SetAlpha(sv.textAlpha); t.icon:SetAlpha(sv.textAlpha) end
    h.shield:SetAlpha(sv.shieldAlpha); self:UpdateDefaultUI(true); self:UpdateCombatOpacity(); self:UpdateExternalTrackerOpacity(); self:UpdateVisibility()
    -- Character activation can produce a burst of inventory and skill-book events.
    -- Coalesce the expensive scans instead of performing them repeatedly here.
    self:QueueWornSetRefresh(100)
    self:UpdateResources(); self:RefreshStandardBuffs(); self:RefreshSorcererTrackers(); self:RefreshWardenTrackers(); self:RefreshArcanistTrackers(); self:UpdateProcAlert()
    self:QueueTrackerIconRefresh(350)
end
function CH:UpdateCombatOpacity(inCombat)
    if not self.root or not self.sv then return end
    if inCombat~=nil then self.inCombat=inCombat
    elseif IsUnitInCombat then self.inCombat=IsUnitInCombat("player") end
    local alpha=1
    if self.sv.useOutOfCombatOpacity and not self.sv.preview and not self.inCombat then alpha=clamp(self.sv.outOfCombatOpacity,.05,1) end
    self.root:SetAlpha(alpha)
end

function CH:UpdateDefaultUI(force)
    if not self.sv then return end
    local show=self.sv.showDefaultResources~=false
    local playerFrame=_G["ZO_PlayerAttribute"]
    if playerFrame then
        -- Reassert only the user's hidden choice; otherwise let ESO retain its own
        -- contextual visibility rules for combat, menus, death, and interaction modes.
        if not show then playerFrame:SetHidden(true)
        elseif force or self.defaultResourcesShown==false then playerFrame:SetHidden(false) end
    end

    -- ZOS anchors the self-buff row 40 px above the stock player resource frame.
    -- When that frame is hidden, move the row into its vacated space.
    local buffTop=_G["ZO_BuffDebuffTopLevel"]
    local buffContainer=_G["ZO_BuffDebuffTopLevelSelfContainer"] or (buffTop and buffTop:GetNamedChild("SelfContainer"))
    if buffContainer and (force or self.defaultResourcesShown~=show) then
        buffContainer:ClearAnchors()
        buffContainer:SetAnchor(CENTER,playerFrame or GuiRoot,playerFrame and TOP or BOTTOM,0,show and -40 or (tonumber(self.sv.buffVerticalOffset) or 0))
    end
    self.defaultResourcesShown=show
end
function CH:UpdateVisibility(state)
    if state~=nil then self.hudVisible=state~=SCENE_HIDDEN end
    if self.root then self.root:SetHidden(not(self.sv and self.sv.enabled and (self.sv.preview or self.hudVisible~=false))) end
end
function CH:GetPowerValues(powerType)
    local current,maximum,effective=GetUnitPower("player",powerType)
    if (maximum or 0)>1 then return current,maximum end
    -- Console builds can expose a pool before the type lookup is initialized.
    for i=0,10 do
        local ok,pType,pCurrent,pMax,pEffective=pcall(GetUnitPowerInfo,"player",i)
        if ok and pType==powerType and (pMax or 0)>1 then return pCurrent,pMax end
    end
    return current or 0,maximum or 0
end
function CH:UpdateResources()
    if not self.root or not self.sv.enabled then return end
    local v=self.power
    if self.sv.preview then v={health={32400,40000},stamina={18700,32000},magicka={21100,32500}}
    else
        local hc,hm=self:GetPowerValues(HEALTH_POWER); local sc,sm=self:GetPowerValues(STAMINA_POWER); local mc,mm=self:GetPowerValues(MAGICKA_POWER)
        if hm<=1 then
            local ok,statMax=pcall(GetPlayerStat,STAT_HEALTH_MAX,STAT_BONUS_OPTION_APPLY_BONUS)
            if ok then hm=statMax or 0 end
        end
        if hm and hm>0 then v.health={hc,hm} end; if sm and sm>0 then v.stamina={sc,sm} end; if mm and mm>0 then v.magicka={mc,mm} end
    end
    self:SetBarValue(self.bars.health,v.health[1],v.health[2]); self:SetBarValue(self.bars.stamina,v.stamina[1],v.stamina[2]); self:SetBarValue(self.bars.magicka,v.magicka[1],v.magicka[2])
    self:UpdateMartialKnowledgeStaminaCue(v.stamina[1],v.stamina[2])
    local shield=self.sv.preview and 14000 or self:GetShieldValue()
    self:SetTexturePercent(self.bars.health.shield,self.bars.health,shield/math.max(1,v.health[2]))
    local healthValid=(v.health[2] or 0)>1
    local over=healthValid and shield>v.health[2]
    self.bars.health.overcap:SetHidden(not over)
    if over then self.bars.health.overcap:SetAlpha(.45+.55*math.abs(math.sin(GetGameTimeMilliseconds()/350))) end

    local mounted=self.sv.preview or (IsMounted and IsMounted())
    local mountCurrent,mountMax=0,0
    if mounted and MOUNT_POWER then mountCurrent,mountMax=self:GetPowerValues(MOUNT_POWER) end
    if self.sv.preview then mountCurrent,mountMax=72,100 end
    self.mountBar:SetHidden(not mounted or (mountMax or 0)<=1)
    if mounted and (mountMax or 0)>1 then self:SetTexturePercent(self.mountBar.fill,self.mountBar,mountCurrent/mountMax) end
end
function CH:GetShieldValue()
    if GetUnitAttributeVisualizerEffectInfo then
        local ok,value=pcall(GetUnitAttributeVisualizerEffectInfo,"player",ATTRIBUTE_VISUAL_POWER_SHIELDING,STAT_MITIGATION,ATTRIBUTE_HEALTH,HEALTH_POWER)
        if ok then
            self.shieldValue=math.max(0,tonumber(value) or 0)
            return self.shieldValue
        end
    end
    return math.max(0,self.shieldValue or 0)
end
function CH:OnShieldVisual(eventCode,unitTag,visualType,statType,attributeType,powerType,oldOrValue,newOrMax)
    if unitTag~="player" or visualType~=ATTRIBUTE_VISUAL_POWER_SHIELDING then return end
    if attributeType and attributeType~=ATTRIBUTE_HEALTH then return end
    if eventCode==EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED then self.shieldValue=0
    elseif eventCode==EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED then self.shieldValue=math.max(0,tonumber(newOrMax) or 0)
    else self.shieldValue=math.max(0,tonumber(oldOrValue) or 0) end
    self:UpdateResources()
end
function CH:UpdateTrackers()
    local now=GetGameTimeSeconds()
    for _,t in pairs(self.trackers) do
        local enabled=t.selectionSetting and self.sv[t.selectionSetting]~="None" or (not t.selectionSetting and (t.key=="resolve" or self.sv[t.enableSetting or (t.key.."Enabled")]~=false))
        local active,pct,remaining,ready=t.active and enabled,0,0,false
        -- A one-bar set remains displayable while its already-applied effect
        -- runs, even if an equipment refresh temporarily reports fewer active
        -- pieces during the swap.
        if t.setDefinition and not self.sv.preview and not t.equipped and not t.active then active=false end
        if t.setDefinition and enabled and (self.sv.preview or t.equipped) and (t.cooldownMode or t.passiveMode) then
            if self.sv.preview then active,ready,pct=true,true,1
            elseif t.passiveMode then active,ready,pct=t.equipped,t.equipped,1
            else
                remaining=math.max(0,(t.cooldownEnd or 0)-now)
                if remaining>0 then active=true; pct=remaining/math.max(.01,t.cooldownDuration or 1)
                elseif t.readyMode=="condition" and t.conditionActive and ((t.conditionEndTime or now)>=now) then active,ready,pct=true,true,1
                else
                    ready=t.readyMode=="cooldown" or (t.readyMode=="condition" and t.conditionActive and ((t.conditionEndTime or now)>=now))
                    -- Conditional sets remain visible while equipped even when
                    -- their proc condition is not armed. Only the green READY
                    -- state is conditional; visibility is not.
                    active,pct=t.readyMode=="condition" or ready,ready and 1 or 0
                end
            end
        elseif self.sv.preview and enabled then
            active=true
            if t.stackMaximum then t.stackCount=t.stackMaximum; pct=1 else pct,remaining=.62,12.4; if t.displayStacks then t.stackCount=t.stackLimit or 5 end end
        elseif active then
            if t.stackMaximum then
                pct=clamp((tonumber(t.stackCount) or 0)/t.stackMaximum,0,1)
                if pct<=0 then t.active,active=false,false end
            else
                remaining=math.max(0,t.endTime-now); pct=remaining/math.max(.01,t.duration or 0)
                if remaining>0 then pct=math.max(.035,pct) else t.active,active=false,false end
            end
        end
        t:SetHidden(not active)
        if active then
            self:SetTexturePercent(t.fill,t,pct)
            local waiting=t.readyMode=="condition" and not ready and remaining<=0
            t.timer:SetText(ready and (t.passiveMode and "ACTIVE" or "READY") or (waiting and "WAIT" or (t.stackMaximum and "" or string.format("%.1f",remaining))))
            t.readyIndicatorActive=ready
            if ready then
                local pulse=.72+.28*math.abs(math.sin(GetGameTimeMilliseconds()/360))
                t.expiryBorder:SetHidden(t.suppressIcon); t.expiryBorder:SetCenterColor(.05,.55,.12,.10); t.expiryBorder:SetEdgeColor(.25,1,.35,pulse)
                t.timer:SetColor(.35,1,.42,1)
            end
            local expiring=not t.stackMaximum and not t.cooldownMode and self.sv.expirationAlerts==true and not t.isNegative and remaining>0 and remaining<=3
            t.expiryAlertActive=expiring; if not ready then t.expiryBorder:SetHidden(not expiring or t.suppressIcon) end
            if expiring then
                local pulse=.5+.5*math.abs(math.sin(GetGameTimeMilliseconds()/240))
                t.timer:SetColor(1,.08,.08,1)
                t.expiryBorder:SetCenterColor(.8,0,0,.05+.10*pulse)
                t.expiryBorder:SetEdgeColor(1,.03,.03,.62+.38*pulse)
            elseif not ready then t.timer:SetColor(1,1,1,1) end
            local stacks=self.sv.preview and t.key=="armaments" and 4 or (tonumber(t.stackCount) or 0)
            t.stackLabel:SetText(tostring(stacks)); t.stackLabel:SetHidden(stacks<=0)
        else
            t.expiryAlertActive=false; t.readyIndicatorActive=false; t.expiryBorder:SetHidden(true); t.timer:SetColor(1,1,1,1); t.stackLabel:SetHidden(true)
        end
    end
    self:UpdateArmamentsReadyEffect()
end
function CH:StandardBuffMatches(selected,effectName,abilityId)
    if not selected or selected=="None" then return false end
    local knownId=MAJOR_BUFF_IDS[selected]
    if knownId and abilityId==knownId then return true end
    local localized=knownId and GetAbilityName and GetAbilityName(knownId) or nil
    return string.lower(effectName or "")==string.lower(selected) or (localized and localized~="" and effectName==localized)
end
function CH:FindStandardBuffTracker(effectName,abilityId)
    for _,definition in ipairs(self.standardBuffTrackerDefinitions) do
        if self:StandardBuffMatches(self.sv[definition.selectionSetting],effectName,abilityId) then return self.trackers and self.trackers[definition.key] end
    end
end
function CH:RefreshStandardBuffs()
    if not self.trackers then return end
    for _,definition in ipairs(self.standardBuffTrackerDefinitions) do
        local t=self.trackers[definition.key]; if t then t.active,t.stackCount=false,0 end
    end
    if self.sv.preview or not GetNumBuffs or not GetUnitBuffInfo then return end
    for index=1,GetNumBuffs("player") do
        local name,beginTime,endTime,_,stackCount,iconName,_,_,_,_,abilityId=GetUnitBuffInfo("player",index)
        local t=self:FindStandardBuffTracker(name,abilityId)
        if t then
            t.active,t.beginTime,t.endTime,t.duration,t.stackCount=true,beginTime or 0,endTime or 0,math.max(.01,(endTime or 0)-(beginTime or 0)),stackCount or 0
            if iconName and iconName~="" then t.icon:SetTexture(iconName) end
        end
    end
end
function CH:RefreshBoundArmaments()
    local t=self.trackers and self.trackers.armaments; if not t then return end
    t.active,t.stackCount=false,0
    if self.sv.preview or self.sv.armamentsEnabled==false or not GetNumBuffs or not GetUnitBuffInfo then return end
    for index=1,GetNumBuffs("player") do
        local name,beginTime,endTime,_,stackCount,iconName,_,_,_,_,abilityId=GetUnitBuffInfo("player",index)
        if abilityId==BOUND_ARMAMENTS_STACK_ID or ((stackCount or 0)>0 and string.find(string.lower(name or ""),"bound armament",1,true)) then
            t.active,t.beginTime,t.endTime,t.duration,t.stackCount=true,beginTime or 0,endTime or 0,math.max(.01,(endTime or 0)-(beginTime or 0)),stackCount or 0
            if iconName and iconName~="" then t.icon:SetTexture(iconName) end
            break
        end
    end
end
function CH:RefreshSorcererTrackers()
    self:RefreshBoundArmaments()
    local surge=self.trackers and self.trackers.surge
    local shroud=self.trackers and self.trackers.shroud
    if surge then surge.active,surge.stackCount=false,0 end
    if shroud then shroud.active,shroud.stackCount=false,0 end
    if self.sv.preview or not GetNumBuffs or not GetUnitBuffInfo then return end
    for index=1,GetNumBuffs("player") do
        local name,beginTime,endTime,_,stackCount,iconName,_,_,_,_,abilityId=GetUnitBuffInfo("player",index)
        local lowerName=string.lower(name or "")
        local t
        if surge and self.sv.surgeEnabled~=false and (abilityId==CRITICAL_SURGE_EFFECT_ID or string.find(lowerName,"critical surge",1,true)) then t=surge
        elseif shroud and self.sv.shroudEnabled~=false and (string.find(lowerName,"vibrant shroud",1,true) or string.find(lowerName,"shattering spines",1,true) or lowerName=="encase") then t=shroud end
        if t then
            t.active,t.beginTime,t.endTime,t.duration,t.stackCount=true,beginTime or 0,endTime or 0,math.max(.01,(endTime or 0)-(beginTime or 0)),stackCount or 0
            if t~=shroud and iconName and iconName~="" then t.icon:SetTexture(iconName)
            elseif t==shroud and not t.preferredIcon and iconName and iconName~="" then t.icon:SetTexture(iconName) end
        end
    end
end
function CH:RefreshWardenTrackers()
    local tracker=self.trackers and self.trackers.netch; if not tracker then return end
    tracker.active,tracker.stackCount=false,0
    if self.sv.preview or self.sv.netchEnabled==false or not GetNumBuffs or not GetUnitBuffInfo then return end
    local definition=self.wardenTrackerDefinitions[1]
    for index=1,GetNumBuffs("player") do
        local name,beginTime,endTime,_,stackCount,_,_,_,_,_,abilityId=GetUnitBuffInfo("player",index)
        local lowerName=string.lower(name or "")
        if string.find(lowerName,"betty netch",1,true) or string.find(lowerName,"blue betty",1,true) or string.find(lowerName,"bull netch",1,true) then
            local iconPath=self:GetFamilyIcon(definition,name); tracker.preferredIcon=iconPath; tracker.icon:SetTexture(iconPath)
            tracker.active,tracker.beginTime,tracker.endTime,tracker.duration,tracker.stackCount=true,beginTime or 0,endTime or 0,math.max(.01,(endTime or 0)-(beginTime or 0)),stackCount or 0
            self.wardenAbilityIds=self.wardenAbilityIds or {}; self.wardenAbilityIds.netch=abilityId or self.wardenAbilityIds.netch
            break
        end
    end
end
function CH:RefreshCrux()
    local t=self.trackers and self.trackers.crux; if not t then return end
    local durationTracker=self.trackers.cruxDuration
    t.active,t.stackCount=false,0
    if durationTracker then durationTracker.active,durationTracker.stackCount=false,0 end
    if self.sv.preview or self.sv.cruxEnabled==false or not GetNumBuffs or not GetUnitBuffInfo then return end
    local definition=self.arcanistTrackerDefinitions[1]
    for index=1,GetNumBuffs("player") do
        local name,beginTime,endTime,_,stackCount,iconName,_,_,_,_,abilityId=GetUnitBuffInfo("player",index)
        local lowerName=string.lower(name or "")
        if (stackCount or 0)>0 and string.find(lowerName,"crux",1,true) then
            t.active,t.beginTime,t.endTime,t.duration,t.stackCount=true,beginTime or 0,endTime or 0,math.max(.01,(endTime or 0)-(beginTime or 0)),math.min(3,stackCount or 0)
            self:ResolveTrackerIcon(definition,name,abilityId,nil,iconName,t)
            if durationTracker then
                durationTracker.active,durationTracker.beginTime,durationTracker.endTime,durationTracker.duration,durationTracker.stackCount=true,beginTime or 0,endTime or 0,math.max(.01,(endTime or 0)-(beginTime or 0)),0
            end
            break
        end
    end
end

function CH:RefreshArcanistTrackers()
    self:RefreshCrux()
end
function CH:IsSoulBurstName(lowerName)
    if lowerName=="soul burst" then return true end
    for _,prefix in ipairs({"binding ","bloody ","chilling ","fiery ","healing ","leashing ","magical ","pestilent ","shocking ","sundering ","warding "}) do
        if lowerName==prefix.."burst" then return true end
    end
    return false
end
function CH:StartCastTracker(t,duration,abilityGraphic,abilityId)
    if not t then return end
    local beginTime=GetGameTimeSeconds(); duration=self:GetConfiguredAbilityDuration(abilityId,duration)
    t.active,t.beginTime,t.endTime,t.duration,t.stackCount=true,beginTime,beginTime+duration,duration,0
    t.castDriven,t.lastCastAt=true,beginTime
    local iconName=t.preferredIcon or abilityGraphic
    if (not iconName or iconName=="") and GetAbilityIcon then iconName=GetAbilityIcon(abilityId) end
    if iconName and iconName~="" then t.icon:SetTexture(iconName); t.preferredIcon=iconName end
    self:UpdateTrackers()
end
function CH:StartFixedCastCooldown(t,duration,abilityGraphic,abilityId)
    if not t then return end
    local now=GetGameTimeSeconds()
    -- Soul Burst may be cast repeatedly, but Anchorite's Potency can consume a
    -- Soul Gem and grant Ultimate only once per cooldown. Do not let an
    -- ineligible cast restart or extend the existing lockout.
    if t.active and (t.endTime or 0)>now then return end
    duration=math.max(.1,tonumber(duration) or 5)
    t.active,t.beginTime,t.endTime,t.duration,t.stackCount=true,now,now+duration,duration,0
    t.castDriven,t.lastCastAt=true,now
    local iconName=t.preferredIcon or abilityGraphic
    if (not iconName or iconName=="") and GetAbilityIcon then
        local ok,value=pcall(GetAbilityIcon,abilityId); if ok then iconName=value end
    end
    if iconName and iconName~="" then t.icon:SetTexture(iconName); t.preferredIcon=iconName end
    self:UpdateTrackers()
end
function CH:SoulBurstUsesAnchoritesPotency(abilityId)
    if not GetNumCraftedAbilities or not GetCraftedAbilityIdAtIndex or not GetCraftedAbilityActiveScriptIds then return false end
    local requestedAbilityId=tonumber(abilityId) or 0
    local ok,count=pcall(GetNumCraftedAbilities); if not ok then return false end
    for index=1,(tonumber(count) or 0) do
        local idOk,craftedAbilityId=pcall(GetCraftedAbilityIdAtIndex,index)
        if idOk and craftedAbilityId and craftedAbilityId~=0 then
            local nameOk,craftedName=pcall(GetCraftedAbilityDisplayName,craftedAbilityId)
            local lowerCraftedName=nameOk and string.lower(craftedName or "") or ""
            local currentId,representativeId=0,0
            if GetAbilityIdForCraftedAbilityId then local valueOk,value=pcall(GetAbilityIdForCraftedAbilityId,craftedAbilityId); if valueOk then currentId=tonumber(value) or 0 end end
            if GetCraftedAbilityRepresentativeAbilityId then local valueOk,value=pcall(GetCraftedAbilityRepresentativeAbilityId,craftedAbilityId); if valueOk then representativeId=tonumber(value) or 0 end end
            if lowerCraftedName=="soul burst" or (requestedAbilityId>0 and (requestedAbilityId==currentId or requestedAbilityId==representativeId)) then
                local scripts={pcall(GetCraftedAbilityActiveScriptIds,craftedAbilityId)}
                if not scripts[1] then return false end
                for scriptIndex=2,4 do
                    local scriptId=tonumber(scripts[scriptIndex]) or 0
                    if scriptId>0 and GetCraftedAbilityScriptDisplayName then
                        local scriptOk,scriptName=pcall(GetCraftedAbilityScriptDisplayName,scriptId)
                        local lowerScriptName=scriptOk and string.lower(scriptName or "") or ""
                        if string.find(lowerScriptName,"anchorite",1,true) and string.find(lowerScriptName,"potency",1,true) then return true end
                    end
                end
                return false
            end
        end
    end
    return false
end
function CH:IsCarveCast(lowerName,abilityId)
    if self:PhraseMatches(lowerName,"carve") then
        if abilityId and abilityId>0 then
            self.globalSV.carveAbilityIds=self.globalSV.carveAbilityIds or {}
            self.globalSV.carveAbilityIds[tostring(abilityId)]=true
        end
        return true
    end
    if abilityId and self.globalSV.carveAbilityIds and self.globalSV.carveAbilityIds[tostring(abilityId)] then return true end
    if abilityId and abilityId>0 and GetAbilityDuration then
        local ok,durationMs=pcall(GetAbilityDuration,abilityId)
        if ok and tonumber(durationMs) and durationMs>=11500 and durationMs<=13000 then
            self.globalSV.carveAbilityIds=self.globalSV.carveAbilityIds or {}
            self.globalSV.carveAbilityIds[tostring(abilityId)]=true
            return true
        end
    end
    return false
end
function CH:IsBrawlerCast(lowerName,abilityId)
    if self:PhraseMatches(lowerName,"brawler") then return true end
    if abilityId and abilityId>0 and GetAbilityDuration then
        local ok,durationMs=pcall(GetAbilityDuration,abilityId)
        return ok and tonumber(durationMs) and durationMs>0 and durationMs<=6500
    end
    return false
end
function CH:StartCarveTracker(t,abilityGraphic,abilityId)
    if not t then return end
    local now=GetGameTimeSeconds()
    -- Combat and action-slot events may both report the same cast. Count it
    -- once so one button press cannot jump directly from 12 to 22 seconds.
    if t.lastCarveCastAt and now-t.lastCarveCastAt<.75 then return end
    t.lastCarveCastAt=now
    local stillApplied=t.active and (t.endTime or 0)>now
    local duration=stillApplied and math.min(32,math.max(12,tonumber(t.carveDuration) or 12)+10) or 12
    t.carveDuration=duration
    t.active,t.beginTime,t.endTime,t.duration,t.stackCount=true,now,now+duration,duration,math.floor((duration-2)/10)
    t.castDriven,t.lastCastAt=true,now
    local iconName=t.preferredIcon or abilityGraphic
    if (not iconName or iconName=="") and GetAbilityIcon then
        local ok,value=pcall(GetAbilityIcon,abilityId); if ok then iconName=value end
    end
    if iconName and iconName~="" then t.icon:SetTexture(iconName); t.preferredIcon=iconName end
    self:UpdateTrackers()
end
function CH:HandleScribingCast(abilityName,abilityGraphic,abilityId,allowActive)
    local lowerName=string.lower(abilityName or "")
    for _,definition in ipairs(self.scribingTrackerDefinitions) do
        local matched=self:IsDefinitionAbilityId(definition,abilityId,self.scribingAbilityIds)
        if not matched then
            if definition.key=="soulBurst" then matched=self:IsSoulBurstName(lowerName)
            else for _,needle in ipairs(definition.needles) do if self:PhraseMatches(lowerName,needle) then matched=true; break end end end
        end
        if matched and self.sv[definition.key.."Enabled"] then
            self:RememberDefinitionAbilityId(definition,abilityId)
            local tracker=self.trackers[definition.key]
            if definition.anchoriteCooldown and self:SoulBurstUsesAnchoritesPotency(abilityId) then
                if not IsUnitInCombat or IsUnitInCombat("player") then
                    self:StartFixedCastCooldown(tracker,definition.anchoriteCooldown,abilityGraphic,abilityId)
                end
            elseif allowActive or not tracker.active then
                self:StartCastTracker(tracker,self.sv[definition.key.."Duration"],abilityGraphic,abilityId)
            end
            if definition.key=="contingency" then
                local now=GetGameTimeSeconds()
                self.contingencyPrimed=true
                self.contingencyPrimedAt=now
                self.contingencyPrimeAbilityId=abilityId
                self.contingencyPrimeEnd=now+self:GetConfiguredAbilityDuration(abilityId,self.sv.contingencyDuration)
                tracker.contingencyProcActive=false
                tracker.contingencyProcEnd=0
            end
            return true
        end
    end
    return false
end

function CH:TriggerPrimedContingency(requirePowerDelay)
    if not self.contingencyPrimed or not self.sv.contingencyEnabled or not self.trackers.contingency then return false end
    local now=GetGameTimeSeconds()
    if now>(self.contingencyPrimeEnd or 0) then self.contingencyPrimed=false; return false end
    -- A power event from the priming cast itself can arrive just after its slot
    -- event. Delay only that fallback path; direct subsequent skill casts remain
    -- authoritative and may animation-cancel the prime immediately.
    if requirePowerDelay and now-(self.contingencyPrimedAt or now)<.6 then return false end
    self:StartCastTracker(self.trackers.contingency,self.sv.contingencyDuration,nil,self.contingencyPrimeAbilityId)
    self.contingencyPrimed=false
    self.contingencyTriggeredAt=now
    self:Log("Ulfsild's Contingency triggered; timer restarted from proc",false)
    return true
end

function CH:HandleWardenCast(abilityName,abilityGraphic,abilityId,allowActive)
    local lowerName=string.lower(abilityName or "")
    for _,definition in ipairs(self.wardenTrackerDefinitions) do
        local matched=self:DefinitionMatches(definition,lowerName,abilityId,self.wardenAbilityIds)
        if matched and self.sv[definition.key.."Enabled"] then
            local tracker=self.trackers[definition.key]
            self:ResolveTrackerIcon(definition,abilityName,abilityId,nil,abilityGraphic,tracker)
            local fallback=definition.durations and definition.durations[lowerName] or definition.duration
            if allowActive or not tracker.active then self:StartCastTracker(tracker,fallback,abilityGraphic,abilityId) end
            return true
        end
    end
    return false
end

function CH:HandleSorcererCast(abilityName,abilityGraphic,abilityId,allowActive)
    local lowerName=string.lower(abilityName or "")
    for _,definition in ipairs(self.sorcererTrackerDefinitions) do
        if self:DefinitionMatches(definition,lowerName,abilityId,self.sorcererAbilityIds) and self.sv[definition.key.."Enabled"] then
            local tracker=self.trackers[definition.key]
            self:ResolveTrackerIcon(definition,abilityName,abilityId,nil,abilityGraphic,tracker)
            local fallback=definition.durations and definition.durations[lowerName] or definition.duration
            if allowActive or not tracker.active then self:StartCastTracker(tracker,fallback,abilityGraphic,abilityId) end
            return true
        end
    end
    return false
end

function CH:HandleArcanistCast(abilityName,abilityGraphic,abilityId,allowActive)
    local lowerName=string.lower(abilityName or "")
    for _,definition in ipairs(self.arcanistTrackerDefinitions) do
        if not definition.stackOnly and self:DefinitionMatches(definition,lowerName,abilityId,self.arcanistAbilityIds) and self.sv[definition.key.."Enabled"] then
            local tracker=self.trackers[definition.key]
            self:ResolveTrackerIcon(definition,abilityName,abilityId,nil,abilityGraphic,tracker)
            local fallback=definition.durations and definition.durations[lowerName] or definition.duration
            if allowActive or not tracker.active then self:StartCastTracker(tracker,fallback,abilityGraphic,abilityId) end
            return true
        end
    end
    return false
end

function CH:HandleRemainingClassCast(abilityName,abilityGraphic,abilityId,allowActive)
    local lowerName=string.lower(abilityName or "")
    for _,group in ipairs(self.remainingClassDefinitionGroups) do
        local idCache=self[group.cache]
        for _,definition in ipairs(group.definitions) do
            if self:DefinitionMatches(definition,lowerName,abilityId,idCache) and self.sv[definition.key.."Enabled"] then
                local tracker=self.trackers[definition.key]
                self:ResolveTrackerIcon(definition,abilityName,abilityId,nil,abilityGraphic,tracker)
                local fallback=definition.durations and definition.durations[lowerName] or definition.duration
                if definition.key=="dkStoneGiant" then
                    local now=GetGameTimeSeconds(); local stacks=(tracker.active and tracker.endTime>now) and (tracker.stackCount or 0)+1 or 1
                    self:StartCastTracker(tracker,fallback,abilityGraphic,abilityId); tracker.stackCount=math.min(definition.stackMaximum,stacks)
                elseif allowActive or not tracker.active then self:StartCastTracker(tracker,fallback,abilityGraphic,abilityId) end
                return true
            end
        end
    end
    return false
end


function CH:HandleNonClassCast(abilityName,abilityGraphic,abilityId,allowActive)
    local lowerName=string.lower(abilityName or "")
    local handled=false
    for _,definition in ipairs(self.nonClassTrackerDefinitions) do
        if self:DefinitionMatches(definition,lowerName,abilityId,self.nonClassAbilityIds) and self.sv[definition.key.."Enabled"] then
            local tracker=self.trackers[definition.key]
            self:ResolveTrackerIcon(definition,abilityName,abilityId,nil,abilityGraphic,tracker)
            local fallback=definition.durations and definition.durations[lowerName] or definition.duration
            if definition.key=="twoHandCleave" and self:IsCarveCast(lowerName,abilityId) then
                self:StartCarveTracker(tracker,abilityGraphic,abilityId)
            elseif definition.key=="twoHandCleave" and self:IsBrawlerCast(lowerName,abilityId) then
                -- Brawler's short effect is its damage shield, not the bleed
                -- duration this tracker represents.
            elseif allowActive or not tracker.active then self:StartCastTracker(tracker,fallback,abilityGraphic,abilityId) end
            handled=true
        end
    end
    return handled
end

function CH:HandleTrackedAbilityCast(abilityName,abilityGraphic,abilityId,authoritative)
    local lowerName=string.lower(abilityName or "")
    -- Do not use the learned/transformed ability-ID cache to decide whether
    -- this is another Contingency cast. On console the next action may expose
    -- a reused crafted ID, causing the real trigger to be mistaken for the
    -- priming skill. Only the explicit skill name suppresses the trigger.
    local isExplicitContingency=self:PhraseMatches(lowerName,"ulfsild's contingency")
        or self:PhraseMatches(lowerName,"ulfsilds contingency")
        or lowerName=="contingency"
    if self.contingencyPrimed and not isExplicitContingency then
        -- Direct action-slot use is itself the reliable signal; GetAbilityCost
        -- frequently reports zero for crafted or transformed ability IDs.
        if authoritative or string.find(lowerName,"dodge",1,true) or string.find(lowerName,"roll",1,true) then self:TriggerPrimedContingency(false) end
    end
    -- Encase/Vibrant Shroud predates the table-driven Sorcerer definitions and
    -- was handled only by EVENT_COMBAT_EVENT. Once action-slot events became
    -- authoritative, that combat path was intentionally filtered and this
    -- family was accidentally bypassed. Route both sources through one handler.
    if self.sv.shroudEnabled and self.trackers.shroud and
       (self:PhraseMatches(lowerName,"vibrant shroud") or self:PhraseMatches(lowerName,"shattering spines") or self:PhraseMatches(lowerName,"encase")) then
        local t=self.trackers.shroud
        if authoritative or not t.active then
            local duration=self:GetConfiguredAbilityDuration(abilityId,10)
            local now=GetGameTimeSeconds()
            t.active,t.beginTime,t.endTime,t.duration=true,now,now+duration,duration
            t.castDriven,t.lastCastAt=true,now
            local iconPath=self:GetShroudIcon(abilityName)
            t.preferredIcon=iconPath; t.icon:SetTexture(iconPath)
            self:UpdateTrackers()
        end
        return true
    end
    return self:HandleScribingCast(abilityName,abilityGraphic,abilityId,authoritative)
        or self:HandleSorcererCast(abilityName,abilityGraphic,abilityId,authoritative)
        or self:HandleWardenCast(abilityName,abilityGraphic,abilityId,authoritative)
        or self:HandleArcanistCast(abilityName,abilityGraphic,abilityId,authoritative)
        or self:HandleRemainingClassCast(abilityName,abilityGraphic,abilityId,authoritative)
        or self:HandleNonClassCast(abilityName,abilityGraphic,abilityId,authoritative)
end
function CH:OnEffectChanged(changeType,effectName,unitTag,beginTime,endTime,stackCount,iconName,abilityId)
    if unitTag~="player" then return end
    local lowerName=string.lower(effectName or "")
    if abilityId==CRYSTAL_FRAGMENTS_PROC_EFFECT_ID or string.find(lowerName,"crystal fragments proc",1,true) then
        self.fragmentsEventActive=changeType~=EFFECT_RESULT_FADED
        self.fragmentsEndTime=endTime or 0
        if iconName and iconName~="" and self.procAlert then self.procAlert.icon:SetTexture(iconName) end
        self:UpdateProcAlert()
        return
    end
    local numericAbilityId=tonumber(abilityId)
    local isKnownContingencyEffect=numericAbilityId and CONTINGENCY_EFFECT_IDS[numericAbilityId]
    local isContingencyPrime=numericAbilityId and CONTINGENCY_PRIME_IDS[numericAbilityId]
    if isContingencyPrime and self.trackers.contingency then
        -- Establish the prepared-runes state from ESO's persistent priming
        -- buff, not only from the active action-bar slot. This survives weapon
        -- swaps and crafted-ID changes when Contingency is slotted on one bar.
        local t=self.trackers.contingency
        local now=GetGameTimeSeconds()
        local reportedBegin=(tonumber(beginTime) or 0)>0 and tonumber(beginTime) or now
        local reportedEnd=tonumber(endTime) or 0
        if changeType~=EFFECT_RESULT_FADED then
            if reportedEnd<=now then reportedEnd=now+self:GetConfiguredAbilityDuration(numericAbilityId,self.sv.contingencyDuration) end
            self.contingencyPrimed=true
            self.contingencyPrimedAt=reportedBegin
            self.contingencyPrimeAbilityId=numericAbilityId
            self.contingencyPrimeEnd=reportedEnd
            t.active,t.beginTime,t.endTime,t.duration,t.stackCount=true,reportedBegin,reportedEnd,math.max(.01,reportedEnd-reportedBegin),stackCount or 0
            t.castDriven=false
            t.contingencyProcActive=false
            t.contingencyProcEnd=0
            if t.preferredIcon then t.icon:SetTexture(t.preferredIcon)
            elseif iconName and iconName~="" then t.icon:SetTexture(iconName) end
            self:Log("Ulfsild's Contingency priming effect "..tostring(abilityId).." detected",false)
        elseif (self.contingencyPrimeEnd or 0)<=now+.15 then
            self.contingencyPrimed=false
            if not t.contingencyProcActive then t.active=false end
        end
        self:UpdateTrackers()
        return
    end
    if isKnownContingencyEffect and not isContingencyPrime and self.trackers.contingency then
        -- This is the generated effect after the prepared runes are consumed,
        -- not the priming buff. Replace the inferred priming endpoint with the
        -- API's real effect window. Several scripts may arrive together; retain
        -- the latest endpoint so the complete overlapping effect is represented.
        local t=self.trackers.contingency
        local now=GetGameTimeSeconds()
        local reportedBegin=(tonumber(beginTime) or 0)>0 and tonumber(beginTime) or now
        local reportedEnd=tonumber(endTime) or 0
        self.contingencyPrimed=false
        if changeType~=EFFECT_RESULT_FADED and reportedEnd>now then
            local firstProc=not t.contingencyProcActive
            local mergedBegin=firstProc and reportedBegin or math.min(t.beginTime or reportedBegin,reportedBegin)
            local mergedEnd=firstProc and reportedEnd or math.max(t.endTime or 0,reportedEnd)
            t.active,t.beginTime,t.endTime,t.duration,t.stackCount=true,mergedBegin,mergedEnd,math.max(.01,mergedEnd-mergedBegin),stackCount or 0
            t.castDriven=false
            t.contingencyProcActive=true
            t.contingencyProcEnd=mergedEnd
            if t.preferredIcon then t.icon:SetTexture(t.preferredIcon)
            elseif iconName and iconName~="" then t.icon:SetTexture(iconName) end
            self:Log("Ulfsild's Contingency proc effect "..tostring(abilityId).." tracked for "..string.format("%.1f",mergedEnd-now).."s",false)
        elseif t.contingencyProcActive and (t.contingencyProcEnd or 0)<=now+.15 then
            t.active=false
            t.contingencyProcActive=false
            t.contingencyProcEnd=0
        end
        self:UpdateTrackers()
        return
    end
    local isContingencyEffect=isKnownContingencyEffect
        or string.find(lowerName,"ulfsild",1,true) and string.find(lowerName,"contingency",1,true)
    if isContingencyEffect and self.contingencyPrimed and changeType~=EFFECT_RESULT_FADED then
        -- The proc's applied/updated effect is the authoritative fallback when
        -- EVENT_ACTION_SLOT_ABILITY_USED does not identify the overlapping
        -- ability or hard action correctly. Ignore only the initial priming
        -- effect, whose begin time is effectively the priming cast time.
        local effectBegin=tonumber(beginTime) or 0
        if effectBegin>(self.contingencyPrimedAt or effectBegin)+.15 then
            self:TriggerPrimedContingency(false)
            return
        end
    end
    local t
    t=self:FindStandardBuffTracker(effectName,abilityId)
    if t then
    elseif abilityId==48136 or abilityId==48131 or abilityId==48141 then t=self.trackers.balance
    elseif abilityId==24163 then t=self.trackers.aegis
    elseif abilityId==BOUND_ARMAMENTS_STACK_ID then t=self.trackers.armaments
    elseif abilityId==CRITICAL_SURGE_EFFECT_ID or string.find(lowerName,"critical surge",1,true) then t=self.trackers.surge
    elseif (string.find(lowerName,"vibrant shroud",1,true) or string.find(lowerName,"shattering spines",1,true) or lowerName=="encase") and self.trackers.shroud then
        t=self.trackers.shroud
        local iconPath=self:GetShroudIcon(effectName); t.preferredIcon=iconPath; t.icon:SetTexture(iconPath)
    elseif isContingencyEffect and self.trackers.contingency then t=self.trackers.contingency
    elseif (string.find(lowerName,"betty netch",1,true) or string.find(lowerName,"blue betty",1,true) or string.find(lowerName,"bull netch",1,true)) and self.trackers.netch then
        t=self.trackers.netch
        local iconPath=self:GetFamilyIcon(self.wardenTrackerDefinitions[1],effectName); t.preferredIcon=iconPath; t.icon:SetTexture(iconPath)
    else
        if self.sv.cruxEnabled and stackCount and stackCount>0 and string.find(lowerName,"crux",1,true) then t=self.trackers.crux end
        local effectGroups={{self.wardenTrackerDefinitions,self.wardenAbilityIds},{self.sorcererTrackerDefinitions,self.sorcererAbilityIds},{self.arcanistTrackerDefinitions,self.arcanistAbilityIds},{self.nonClassTrackerDefinitions,self.nonClassAbilityIds}}
        for _,classGroup in ipairs(self.remainingClassDefinitionGroups) do effectGroups[#effectGroups+1]={classGroup.definitions,self[classGroup.cache]} end
        for _,group in ipairs(effectGroups) do
            if t then break end
            for _,definition in ipairs(group[1]) do
                if not definition.stackOnly and self.sv[definition.key.."Enabled"] and self:DefinitionMatches(definition,lowerName,abilityId,group[2]) then
                    t=self.trackers[definition.key]
                    self:ResolveTrackerIcon(definition,effectName,abilityId,nil,iconName,t)
                    break
                end
            end
            if t then break end
        end
        local duration=(endTime or 0)-(beginTime or 0)
        if not t and duration>0 and duration<30 and (string.find(lowerName,"bound aegis",1,true) or string.find(lowerName,"bound armor",1,true)) then t=self.trackers.aegis end
        if not t and stackCount and stackCount>0 and string.find(lowerName,"bound armament",1,true) then t=self.trackers.armaments end
    end
    if not t then return end
    local now=GetGameTimeSeconds()
    local wasActive=t.active and (t.endTime or 0)>now
    local definition=t.trackerDefinition
    local eventDuration=(endTime or 0)-(beginTime or 0)
    if definition and definition.key=="twoHandCleave" and (self:PhraseMatches(lowerName,"brawler") or eventDuration>0 and eventDuration<=6.5) then
        -- Ignore Brawler's shield application/fade entirely. It must never
        -- start, shorten, clear, or otherwise replace the Carve bleed timer.
        return
    end
    local fallback=definition and ((definition.durations and definition.durations[lowerName]) or definition.duration) or nil
    local reportedBegin=(beginTime or 0)>0 and beginTime or now
    local reportedEnd=endTime or 0
    if definition and t.castDriven then
        -- Cast handlers own the complete parent window. EVENT_EFFECT_CHANGED
        -- may also emit short child pulses and a final tick after that parent
        -- expires. Those events must not manufacture another full duration.
        if changeType==EFFECT_RESULT_FADED then return end
        local parentDuration=math.max(1,tonumber(fallback) or tonumber(t.duration) or 1)
        if eventDuration<=0 or eventDuration<parentDuration*.65 then return end
        if not wasActive and now-(tonumber(t.lastCastAt) or 0)>1 then return end
        -- A same/earlier endpoint adds no information. A genuinely later full
        -- endpoint is retained for API-reported duration extensions.
        if wasActive and reportedEnd<=(t.endTime or 0)+.15 then return end
    end
    -- Periodic skills often emit a short event for every heal, pulse, or damage
    -- tick. Keep the parent skill's full cast/effect window and only extend it
    -- when ESO reports a later endpoint (for example additional Carve stacks).
    if changeType==EFFECT_RESULT_FADED and wasActive and (t.endTime or 0)>now+.15 then return end
    if changeType~=EFFECT_RESULT_FADED then
        local fallbackEnd=not t.castDriven and fallback and (reportedBegin+fallback) or 0
        local mergedEnd=math.max(reportedEnd,fallbackEnd,wasActive and (t.endTime or 0) or 0)
        local mergedBegin=wasActive and (t.beginTime or reportedBegin) or reportedBegin
        t.active=mergedEnd>now or (t.stackMaximum and (stackCount or 0)>0)
        t.beginTime,t.endTime=mergedBegin,mergedEnd
        if t.active then t.duration=math.max(.01,mergedEnd-mergedBegin) end
    else
        t.active=false; t.beginTime,t.endTime=reportedBegin,reportedEnd
    end
    t.stackCount=stackCount or 0
    if t.preferredIcon then t.icon:SetTexture(t.preferredIcon)
    elseif iconName and iconName~="" then t.icon:SetTexture(iconName) end
    self:UpdateTrackers()
end

function CH:CreateHUD()
    if self.root and self.bars and self.bars.health and self.bars.stamina and self.bars.magicka and self.mountBar then
        -- Console character changes can reload addon Lua while preserving the
        -- UI control tree. Recreating named controls here leaked another full
        -- HUD (and every enabled tracker) per character until later add-ons
        -- exhausted the shared frame budget. Reuse the session-owned controls.
        for _,tracker in pairs(self.trackers or {}) do
            tracker.active=false
            tracker.beginTime,tracker.endTime,tracker.duration=0,0,0
            tracker.stackCount=0
            tracker.cooldownEnd=0
            tracker.conditionActive=false
            tracker.conditionEndTime=0
            tracker.equipped=false
            tracker.setEffectInstances=nil
            tracker:SetHidden(true)
            if tracker.stackLabel then tracker.stackLabel:SetHidden(true); tracker.stackLabel:SetText("") end
            if tracker.readyLabel then tracker.readyLabel:SetHidden(true); tracker.readyLabel:SetText("") end
            if tracker.readyBorder then tracker.readyBorder:SetHidden(true) end
            if tracker.expiryBorder then tracker.expiryBorder:SetHidden(true) end
        end
        if self.procAlert then self.procAlert:SetHidden(true) end
        self.fragmentsEventActive=false
        self.fragmentsEndTime=0
        self.mountBar:SetHidden(true)
        self:EnsureOptionalCoreTrackers()
        self:EnsureEnabledDefinitionTrackers()
        self:ApplyLayout()
        return
    end
    self.root=WM:CreateTopLevelWindow("CurvedHUD_Root"); self.root:SetDimensions(900,600); self.root:SetMouseEnabled(false); self.root:SetClampedToScreen(false); self.root:SetDrawTier(DT_HIGH)
    self.bars,self.trackers={},{}; self:CreateBar("health","left",{.85,.1,.1}); self:CreateBar("stamina","right",{.15,.78,.22}); self:CreateBar("magicka","right",{.12,.42,.95})
    self:CreateShield(); self:CreateMountBar()
    -- Every tracker/proc control is allocated on demand from this character's
    -- saved configuration, including the original legacy trackers.
    self:EnsureOptionalCoreTrackers()
    -- Fixed ESO asset path for Vibrant Shroud; cast/slotted detection may replace
    -- it with Encase or Shattering Spines artwork when those variants are used.
    self:EnsureEnabledDefinitionTrackers(); self:ApplyLayout()
end

function CH:QueuePlayerActivationRefresh(delayMs)
    self.activationRefreshGeneration=(self.activationRefreshGeneration or 0)+1
    local generation=self.activationRefreshGeneration
    local function refresh()
        if generation~=self.activationRefreshGeneration then return end
        self:Guard("player activation",function() self:ApplyLayout() end)
    end
    if zo_callLater then zo_callLater(refresh,delayMs or 350) else refresh() end
end

function CH:StartPeriodicUpdates()
    EVENT_MANAGER:UnregisterForUpdate(self.updateName)
    EVENT_MANAGER:UnregisterForUpdate(self.updateName.."Slow")
    EVENT_MANAGER:UnregisterForUpdate(self.updateName.."Memory")
    -- Keep animation/timer presentation responsive without repeating the more
    -- expensive resource, buff and external-control queries ten times a second.
    EVENT_MANAGER:RegisterForUpdate(self.updateName,100,function()
        self:Guard("timer update",function()
            if not self.sv.enabled then return end
            self:UpdateTrackers(); self:UpdateProcAlert()
        end)
    end)
    EVENT_MANAGER:RegisterForUpdate(self.updateName.."Slow",500,function()
        self:Guard("state update",function()
            if self.sv.enabled then self:UpdateResources(); self:RefreshCrux() end
            self:UpdateDefaultUI(false); self:UpdateExternalTrackerOpacity()
        end)
    end)
    -- Small, infrequent incremental GC steps avoid the hitch and CPU-budget
    -- risk of forcing a full global collection. This cannot clear ESO's CPU
    -- script budget; it only helps release unreachable Lua allocations.
    EVENT_MANAGER:RegisterForUpdate(self.updateName.."Memory",60000,function()
        self:Guard("memory maintenance",function()
            if IsUnitInCombat and IsUnitInCombat("player") then return end
            local now=GetGameTimeSeconds()
            for _,tracker in pairs(self.trackers or {}) do
                if tracker.setEffectInstances then
                    for key,instance in pairs(tracker.setEffectInstances) do
                        if (instance.endTime or 0)<=now then tracker.setEffectInstances[key]=nil end
                    end
                end
            end
            if collectgarbage then pcall(collectgarbage,"step",16) end
        end)
    end)
end
function CH:ClearCombatBoundTrackers()
    if not self.trackers then return end
    for key in pairs(self.combatBoundTrackerKeys or {}) do
        local tracker=self.trackers[key]
        if tracker then
            tracker.active=false
            tracker.beginTime,tracker.endTime,tracker.duration=0,0,0
            tracker.stackCount=0
            tracker.carveDuration=nil
            tracker.lastCarveCastAt=nil
            tracker.lastCastAt=nil
            tracker.expiryAlertActive=false
            if tracker.stackLabel then tracker.stackLabel:SetText("") end
            if tracker.readyLabel then tracker.readyLabel:SetText("") end
            if tracker.readyBorder then tracker.readyBorder:SetHidden(true) end
            if tracker.expiryBorder then tracker.expiryBorder:SetHidden(true) end
            tracker:SetHidden(true)
        end
    end
    self:UpdateTrackers()
end
function CH:RegisterEvents()
    EVENT_MANAGER:RegisterForEvent(self.name,EVENT_POWER_UPDATE,function(_,unitTag,_,powerType,current,maximum,effectiveMaximum)
        if unitTag~="player" then return end
        local key=powerType==HEALTH_POWER and "health" or powerType==STAMINA_POWER and "stamina" or powerType==MAGICKA_POWER and "magicka"
        local usableMax=(maximum or 0)>1 and maximum or (effectiveMaximum or 0)
        if key and usableMax>1 then
            local previous=self.power[key] and tonumber(self.power[key][1]) or tonumber(current) or 0
            self.power[key]={current,usableMax}
            if (key=="stamina" or key=="magicka") and (tonumber(current) or 0)<previous then self:TriggerPrimedContingency(true) end
            self:Guard("power event",function() self:UpdateResources() end)
        end
    end); EVENT_MANAGER:AddFilterForEvent(self.name,EVENT_POWER_UPDATE,REGISTER_FILTER_UNIT_TAG,"player")
    EVENT_MANAGER:RegisterForEvent(self.name.."Effects",EVENT_EFFECT_CHANGED,function(_,changeType,_,effectName,unitTag,beginTime,endTime,stackCount,iconName,_,_,_,_,_,_,abilityId)
        self:Guard("effect event",function() self:OnEffectChanged(changeType,effectName,unitTag,beginTime,endTime,stackCount,iconName,abilityId) end)
    end); EVENT_MANAGER:AddFilterForEvent(self.name.."Effects",EVENT_EFFECT_CHANGED,REGISTER_FILTER_UNIT_TAG,"player")
    EVENT_MANAGER:RegisterForEvent(self.name.."SetEffects",EVENT_EFFECT_CHANGED,function(_,changeType,_,effectName,unitTag,beginTime,endTime,stackCount,iconName,_,_,_,_,_,_,abilityId)
        self:Guard("set effect event",function() self:OnSetEffectChanged(changeType,effectName,unitTag,beginTime,endTime,stackCount,iconName,abilityId) end)
    end)
    if EVENT_INVENTORY_SINGLE_SLOT_UPDATE then
        EVENT_MANAGER:RegisterForEvent(self.name.."WornSets",EVENT_INVENTORY_SINGLE_SLOT_UPDATE,function(_,bagId)
            if bagId==BAG_WORN then self:QueueWornSetRefresh(250) end
        end)
    end
    EVENT_MANAGER:RegisterForEvent(self.name.."TrackedCasts",EVENT_COMBAT_EVENT,function(_,result,_,abilityName,abilityGraphic,_,sourceName,sourceType,_,_,_,_,_,_,_,_,abilityId)
        if sourceType~=COMBAT_UNIT_TYPE_PLAYER then return end
        -- Direct action-slot events are authoritative when available. Combat
        -- events also report every DoT/HoT pulse; accepting those as casts made
        -- the final tick restart an expired parent timer.
        if EVENT_ACTION_SLOT_ABILITY_USED and ACTION_RESULT_BEGIN and result~=ACTION_RESULT_BEGIN then return end
        if PERIODIC_COMBAT_RESULTS[result] then return end
        self:HandleTrackedAbilityCast(abilityName,abilityGraphic,abilityId,false)
    end)
    if EVENT_ACTION_SLOT_ABILITY_USED then
        EVENT_MANAGER:RegisterForEvent(self.name.."SlotUsed",EVENT_ACTION_SLOT_ABILITY_USED,function(_,slotNum)
            local ok,id=pcall(GetSlotBoundId,slotNum); if not ok or not id or id<=0 then return end
            local abilityName=GetAbilityName and GetAbilityName(id) or ""; local abilityGraphic=nil
            if GetSlotTexture then local okIcon,icon=pcall(GetSlotTexture,slotNum); if okIcon then abilityGraphic=icon end end
            self:HandleTrackedAbilityCast(abilityName,abilityGraphic,id,true)
        end)
    end
    EVENT_MANAGER:RegisterForEvent(self.name.."Activated",EVENT_PLAYER_ACTIVATED,function()
        self:QueuePlayerActivationRefresh(350)
    end)
    EVENT_MANAGER:RegisterForEvent(self.name.."Combat",EVENT_PLAYER_COMBAT_STATE,function(_,inCombat)
        self:Guard("combat state",function()
            self:UpdateCombatOpacity(inCombat); self:UpdateExternalTrackerOpacity()
            if not inCombat then self:ClearCombatBoundTrackers() end
        end)
    end)
    local shieldCallback=function(eventCode,unitTag,visualType,statType,attributeType,powerType,value1,value2)
        self:Guard("shield event",function() self:OnShieldVisual(eventCode,unitTag,visualType,statType,attributeType,powerType,value1,value2) end)
    end
    EVENT_MANAGER:RegisterForEvent(self.name.."ShieldAdded",EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED,shieldCallback)
    EVENT_MANAGER:RegisterForEvent(self.name.."ShieldUpdated",EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED,shieldCallback)
    EVENT_MANAGER:RegisterForEvent(self.name.."ShieldRemoved",EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED,shieldCallback)
    if not self.sceneCallbacksRegistered then
        local callback=function(_,state) self:UpdateVisibility(state) end
        SCENE_MANAGER:GetScene("hud"):RegisterCallback("StateChange",callback); SCENE_MANAGER:GetScene("hudui"):RegisterCallback("StateChange",callback)
        self.sceneCallbacksRegistered=true
    end
    -- Let the login scene and other add-ons settle before starting recurring work.
    if zo_callLater then zo_callLater(function() self:StartPeriodicUpdates() end,1000) else self:StartPeriodicUpdates() end
end

function CH:MigrateSavedVariables()
    local global,character=self.globalSV,self.characterSV
    local globalVersion=tonumber(global.schemaVersion) or 0
    local characterVersion=tonumber(character.schemaVersion) or 0
    if globalVersion<1 then
        -- Pre-1.0 calibration builds exposed several temporary geometry keys.
        -- Current shared controls and baked/fixed radii supersede them.
        for _,key in ipairs({
            "thinLeftTimerOffset","thinLeftTimerSpacing","thickLeftTimerOffset","thickLeftTimerSpacing",
            "thinRightParallelTimerOffset","thinRightParallelTimerSpacing","thickRightParallelTimerOffset","thickRightParallelTimerSpacing",
            "thinRightStackedTimerOffset","thinRightStackedTimerSpacing","thickRightStackedTimerOffset","thickRightStackedTimerSpacing",
            "parallelOuterResourceRadiusScale","thinRightParallelOutsideRadiusScale","thickRightParallelOutsideRadiusScale",
            "thinLeftInsideRadiusScale","thinLeftOutsideRadiusScale","thinRightParallelInsideRadiusScale",
            "thinRightStackedInsideRadiusScale","thinRightStackedOutsideRadiusScale","thickLeftOutsideRadiusScale",
            "thickRightParallelInsideRadiusScale","thickRightStackedInsideRadiusScale","thickRightStackedOutsideRadiusScale",
        }) do global[key]=nil end
        -- Earlier builds enabled diagnostic chat by default. Release profiles
        -- start quiet; users can still opt in with /curvedhud debug.
        global.debug=false
    end
    if characterVersion<2 then
        -- Update 51 consolidated the power and critical buffs. Preserve each
        -- character's existing tracker intent by moving retired selections to
        -- their live replacements instead of silently disabling the tracker.
        local replacements={
            ["Major Sorcery"]="Major Brutality", ["Minor Sorcery"]="Minor Brutality",
            ["Major Prophecy"]="Major Savagery", ["Minor Prophecy"]="Minor Savagery",
        }
        for _,key in ipairs({"majorBuffTracked","majorBuff2Tracked","minorBuff1Tracked","minorBuff2Tracked"}) do
            character[key]=replacements[character[key]] or character[key]
        end
    end
    if type(global.iconCache)~="table" then global.iconCache={} end
    if type(global.setEffectIconCache)~="table" then global.setEffectIconCache={} end
    if type(global.abilityIdCache)~="table" then global.abilityIdCache={} end
    if type(global.carveAbilityIds)~="table" then global.carveAbilityIds={} end
    global.schemaVersion=self.dataVersion
    character.schemaVersion=self.dataVersion
end

function CH:PrintDiagnosticReport()
    local enabled,instantiated,active,learned=0,0,0,0
    for key in pairs(self.characterKeys or {}) do
        if string.sub(key,-7)=="Enabled" and self.sv[key] then enabled=enabled+1 end
    end
    for _,definition in ipairs(self.standardBuffTrackerDefinitions or {}) do
        if self.sv[definition.selectionSetting] and self.sv[definition.selectionSetting]~="None" then enabled=enabled+1 end
    end
    for _,tracker in pairs(self.trackers or {}) do instantiated=instantiated+1; if tracker.active then active=active+1 end end
    for _,ids in pairs(self.globalSV.abilityIdCache or {}) do if type(ids)=="table" then for _ in pairs(ids) do learned=learned+1 end end end
    local libraries={}
    if LibAddonMenu2 then libraries[#libraries+1]="LibAddonMenu" end
    if LibHarvensAddonSettings then libraries[#libraries+1]="LibVotans" end
    local libraryText=#libraries>0 and table.concat(libraries," + ") or "none"
    local api=GetAPIVersion and GetAPIVersion() or "unknown"
    local memoryKb=collectgarbage and collectgarbage("count") or 0
    self:Log(string.format("REPORT v%s schema=%s API=%s libraries=%s",self.version,tostring(self.globalSV.schemaVersion),tostring(api),libraryText),true)
    self:Log(string.format("layout=%s width=%s scale=%.2f styles=%s/%s enabled=%d instantiated=%d active=%d",tostring(self.sv.layout),tostring(self.sv.barWidth),tonumber(self.sv.scale) or 1,tostring(self.sv.insideTimerStyle),tostring(self.sv.outsideTimerStyle),enabled,instantiated,active),true)
    self:Log(string.format("learned ability IDs=%d total UI Lua memory=%.0f KB guarded errors=%d",learned,memoryKb,self.errorCount or 0),true)
    if self.errorLog and #self.errorLog>0 then self:Log("latest error: "..self.errorLog[#self.errorLog],true) end
end

function CH:Initialize()
    -- CurvedHUD's global table and UI controls can survive console character
    -- transitions. Session-owned registrations must therefore be preserved;
    -- only saved-variable bindings and transient character state are renewed.
    self.settingsRegistrationQueued=false
    self.globalSV=ZO_SavedVars:NewAccountWide("CurvedHUD_SavedVariables",1,nil,self.defaults)
    self.characterSV=ZO_SavedVars:New("CurvedHUD_CharacterSavedVariables",1,nil,self.characterDefaults)
    self:MigrateSavedVariables()
    -- A genuinely new character starts with every optional tracker disabled.
    -- Existing initialized character profiles retain all of their choices.
    if not self.characterSV.initialized then
        self.characterSV.initialized=true
    end
    -- Existing code and both settings providers can continue using CH.sv. The
    -- proxy routes only tracker choices to this character; geometry, sizing,
    -- opacity, fonts, and layout remain account-wide.
    self.sv=setmetatable({}, {
        __index=function(_,key) if self.characterKeys[key] then return self.characterSV[key] end return self.globalSV[key] end,
        __newindex=function(_,key,value) if self.characterKeys[key] then self.characterSV[key]=value else self.globalSV[key]=value end end,
    })
    self.power={health={0,0},stamina={0,0},magicka={0,0}}; self.shieldValue=0; self.hudVisible=true
    self:Guard("HUD creation",function() self:CreateHUD() end)
    -- Register with the other add-ons during the normal load phase. Late
    -- LibVotans AddAddon calls can rebuild/corrupt its shared console tables;
    -- AddSettings batching keeps this normal initialization pass bounded.
    if not self.settingsRegistered then
        self:Guard("settings registration",function()
            if self.RegisterSettings then self:RegisterSettings(); self.settingsRegistered=true end
        end)
    end
    self:Guard("event registration",function() self:RegisterEvents() end)
    SLASH_COMMANDS["/curvedhud"]=function(arg)
        arg=string.lower(arg or "")
        if arg=="preview" then self.sv.preview=not self.sv.preview; self:ApplyLayout()
        elseif arg=="debug" then self.sv.debug=not self.sv.debug; self:Log("Debug "..(self.sv.debug and "enabled" or "disabled"),true)
        elseif arg=="status" then
            local hc,hm,he=GetUnitPower("player",HEALTH_POWER)
            self:Log(string.format("Health API: type=%s current=%s max=%s effective=%s cached=%s/%s shield=%s",tostring(HEALTH_POWER),tostring(hc),tostring(hm),tostring(he),tostring(self.power.health[1]),tostring(self.power.health[2]),tostring(self.shieldValue)),true)
        elseif arg=="report" then self:PrintDiagnosticReport()
        elseif arg=="memory" then
            local trackerCount=0; for _ in pairs(self.trackers or {}) do trackerCount=trackerCount+1 end
            local memoryKb=collectgarbage and collectgarbage("count") or 0
            self:Log(string.format("Runtime footprint: %d instantiated trackers; total UI Lua memory %.0f KB",trackerCount,memoryKb),true)
        else self:Log("Loaded "..self.version..". Commands: /curvedhud preview, /curvedhud debug, /curvedhud status, /curvedhud memory, /curvedhud report",true) end
    end
    self:Log("Loaded "..self.version.."; HUD, shield, and trackers created",true)
end
local function loaded(_,addonName)
    if addonName~=CH.name then return end; EVENT_MANAGER:UnregisterForEvent(CH.name,EVENT_ADD_ON_LOADED); CH:Guard("initialization",function() CH:Initialize() end)
end
EVENT_MANAGER:RegisterForEvent(CH.name,EVENT_ADD_ON_LOADED,loaded)
