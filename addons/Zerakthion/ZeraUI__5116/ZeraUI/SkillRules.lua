-- Curated exact effect IDs. Only
-- ability-specific observations override native duration; common Major/Minor
-- buffs, set procs, ambiguous scribing affixes and channels are excluded.
ZeraUISkillRules={duration={},stacks={},singleTarget={}}
local R=ZeraUISkillRules
-- Persistent placed areas own one cast timer, not a timer for each victim.
-- Explicit identities also protect weapon variants that report Area rather
-- than Ground in the tooltip. Triggered traps/runes are intentionally absent.
R.groundTimers={}
for _,id in ipairs({28858,28807,28854,28849,39052,39053,39073,39067,39011,39012,39018,39028,
    33376,40242,40255,23182,23205,23200,26188,26858,26869,21752,21755,21758,38689,117850}) do R.groundTimers[id]=true end
local function effect(ability,id,placement)
    R.duration["a:"..ability]={{effect=id,mode="effect",duration=0,nativeFallback=true,placement=placement}}
end
local function effects(map) for ability,id in pairs(map) do effect(ability,id) end end

-- Weapon lines: bleed, ground DOT, weapon-specific morphs, restoration.
effects({[38788]=38791,[38745]=38747,[83216]=83217,[83229]=83230,[83238]=83239,
    [28379]=29293,[38839]=38841,[38845]=38848,[83600]=85156,[85187]=85192,[85179]=85182,
    [38701]=38703,[28869]=44540,[38645]=44545,[38660]=44549,[85451]=85458,
    [29073]=62648,[29089]=62722,[29078]=62692,[38944]=62682,[38978]=62745,[38970]=62712,
    [38401]=38404})
-- Dragonknight: morph-specific effects, not shared Major/Minor buffs.
effects({[23806]=256798,[20805]=122658,[20668]=44369,[20917]=31102,
    [29043]=258658,[31874]=258666,[31888]=258661,[31816]=134340})
-- These delayed bursts run on the caster, not on the enemy interrupted by
-- Soul of Flame. Keep the countdown independent of reticle debuff matching.
R.selfCastNames={ ["core of flame"]=4,["soul of flame"]=4,["heart of flame"]=4 }
-- Sorcerer: pets' activated skills, Dark Exchange, Atronachs, Liquid Lightning.
effects({[24584]=114903,[24589]=114909,[24595]=114908,[77182]=77187,[23316]=77187,
    [77140]=77354,[24636]=77354,[108840]=108842,[23304]=108844,
    [23634]=80459,[23492]=80463,[23495]=23668,[18718]=18746,[19109]=19118,[19123]=19125,
    [23182]=157462,[23205]=157537,[23200]=157535})
-- Templar
effects({[26188]=95933,[26858]=95957,[26869]=26880,[22178]=22179,[22180]=49091,[22182]=22183,
    [22138]=62593,[22139]=62607,[22144]=62599,[21726]=21728,[21732]=21734,[21729]=21731,
    [21752]=21576,[21755]=22003,[21758]=22001})
-- Warden
effects({[85999]=130140,[86023]=101703,[86027]=101904,[86031]=101944,[86037]=177288,
    [86041]=177289,[86045]=177290,[85564]=90266,[85858]=88726,[86148]=90833,
    [86156]=90834,[86152]=90835,[86113]=132429})
-- Nightblade: only the specific heal/DOT/ultimate effects, never off-balance.
effects({[33291]=33292,[34838]=34841,[34835]=34836,[33308]=108925,[34721]=108927,[34727]=108932,
    [33326]=33333,[36943]=36947,[36957]=36960,[33398]=61389,[36508]=61393,
    [113105]=113107,[36514]=61400,[25091]=25093,[35460]=35462})
-- Necromancer: actual tether effect rather than an estimate on key press.
effects({[114860]=114863,[117330]=114863,[117690]=117691,[117693]=117691,[118223]=122625,
    [117883]=117886,[115315]=115326,[118017]=118022,[118809]=118814,
    [116445]=115924,[118009]=118008,[118764]=118763,[116450]=115926,[118071]=118070})
-- Arcanist: keep crux separate from duration; don't substitute it for a timer.
effects({[185817]=185818,[183006]=183008,[185823]=185825,[185836]=185838,[185839]=185840,
    [182988]=182989,[201296]=182989,[189791]=189792,[189837]=189838,[183430]=187742,
    [183241]=184362,[185912]=194637,[183401]=194646,[183542]=195167,[186211]=195190,
    [186220]=195204,[183709]=183712,[193794]=193797,[193558]=193559})
-- Guild, World and Alliance lines.
effects({[26768]=126890,[40328]=126895,[40317]=126897,[28567]=126370,[40452]=126371,[40457]=126374,
    [35713]=62305,[40158]=62314,[40161]=126312,[16536]=63430,[40489]=63456,[40493]=63473,
    [61503]=61504,[61505]=61506,[33376]=38549,[40242]=40251,[40255]=40265,
    [38563]=38564,[40220]=40221,[40223]=40224,[58855]=58856,[58879]=58880})
-- Placement -> actual triggered DOT. The primary effect wins when observed.
effect(35750,35756,35750); effect(40372,40375,40372); effect(40382,40385,40382)
effect(40465,40468,40465)

-- Additional exact skill/effect identities.
-- Shared Major/Minor buffs and script-affix IDs are intentionally omitted.
effects({[38910]=126667,[28719]=28720,[38405]=38407,[38452]=80625,[38705]=38707,
    [32632]=137156,[39105]=137184,[39104]=137164,
    [58317]=137206,[128709]=128712,[137861]=137865,[138097]=138098,
    [31642]=48131,[40445]=48136,[103488]=104050,[104059]=104078,
    [61489]=61498,[61519]=61522,[61524]=61526,[24371]=24559,[24578]=24581,
    [22253]=35632,[85995]=130129,[86003]=178330,[85922]=85840,
    [25255]=25256,[25267]=34739,[25260]=34733,
    [36908]=215672,[118123]=118122,[118226]=125750,[199287]=199288,[199290]=218361})
-- Arena-weapon-specific buffs are observed only when the exact effect
-- actually fires. With no relevant weapon equipped, native tracking wins.
effects({[28607]=99806,[38857]=99806,[38846]=99806,[28591]=100474,[38891]=100474,[38861]=100474,
    [46340]=100306,[46348]=100306,[46356]=100306,[28879]=113627,[38672]=113627,[38669]=113627,
    [38985]=140334,[38993]=140334,[28794]=115003,[28799]=115003,[28798]=115003,
    [39145]=115003,[39147]=115003,[39146]=115003,[39162]=115003,[39167]=115003,[39163]=115003})
-- Roaming/placed heals and shields: only confirmed non-caster recipients.
-- Each ID is a primary effect or known direct cast/effect identity, not a
-- shared stat buff. A player ID is counted once even if the effect refreshes.
R.allyCounts={}
for _,id in ipairs({61504,61506,40076,40079,37232,40126,40130,40060,
    34841,108925,108927,108932,35632,90266,88726,90833,90834,90835,
    115326,118022,118814,115926,118070,118122,85840,38552,
    38564,40221,40224,258658,258666,258661}) do R.allyCounts[id]=true end
effects({[40076]=40076,[40079]=40079,[37232]=37232,[40126]=40126,[40130]=40130,[40060]=40060})

-- Exact consecutive phase events; a late fade from an earlier phase must
-- never clear a newer phase. Timings are fixed and
-- only used when the game omits a valid expiration for a confirmed gain.
R.phaseInfo={}
local function phase(first,second,firstTime,secondTime)
    effect(first,first)
    R.duration["a:"..first][1].followup=second
    R.nextPhase=R.nextPhase or {}; R.previousPhase=R.previousPhase or {}
    R.nextPhase[first]=second; R.previousPhase[second]=first
    R.phaseInfo[first]={duration=firstTime,count=2}; R.phaseInfo[second]={duration=secondTime,count=1}
end
phase(86009,178020,3,6) -- Scorch
phase(86015,178028,3,6) -- Deep Fissure
phase(86019,146919,3,3) -- Subterranean Assault
effect(37475,76639,37475) -- Manifestation of Terror: placement versus fear

-- Active ground devices count instances, not effect stackCount.
R.devices={
    [24828]={24830,24832,24833}, -- Daedric Mines
    [24842]={24844,24846,24847}, -- Daedric Tomb
    [24834]={25157,25158,25159,25160,25162}, -- Daedric Refuge
    [86175]={86175},[86179]={86179},[86183]={86183}, -- Frozen Gate morphs
}

-- Shield charges have a dedicated combat result; counting generic damage
-- ticks (or the number of shielded allies) would not represent charges.
R.shieldCharges={
    [28727]={1,28727,126604},[38312]={1,38312,126608},[38317]={1,38317,38324},
    [86135]={3,86135},[86139]={3,86139},[86143]={3,86143},
}
R.combatTimers={
    [28297]={event=28297,result="ACTION_RESULT_EFFECT_GAINED_DURATION"},
    [38794]={event=38794,result="ACTION_RESULT_EFFECT_GAINED_DURATION"},
    [117749]={event=117757,pet=true,duration=20}, -- Grave Lord's Sacrifice
    [222370]={event=222370,result="ACTION_RESULT_EFFECT_GAINED_DURATION"},
    [217512]={event=217512,result="ACTION_RESULT_POWER_ENERGIZE",duration=5},
    [216940]={event=216940,result="ACTION_RESULT_POWER_ENERGIZE",duration=5},
}
for _,id in ipairs({22265,22259,22262}) do
    effect(id,id); local rule=R.duration["a:"..id][1]
    rule.mode="auto"; rule.castDurationAPI=true
end
-- Summoned shade effect identity depends on character race.
R.racialDuration={}
for ability,ids in pairs({[33211]={38517,88662,88663},[35434]={35438,88677,88678},[35441]={38528,88696,88697},[35445]={38528,88696,88697}}) do
    local variants={}
    for i,id in ipairs(ids) do variants[i]={{effect=id,mode="effect",duration=0,nativeFallback=true}} end
    R.racialDuration[ability]=variants
end

-- Real stack sources (including transformed/proc slot IDs).
local function stacks(source,ids) for _,id in ipairs(ids) do R.stacks[id]=source end end
stacks(122585,{61902,61907}); stacks(122586,{61919,61930}); stacks(122587,{61927,61932})
stacks(203447,{24165}); stacks(51392,{23234,23236,23277})
stacks(256798,{23806,256798})
stacks(172418,{132141}); stacks(134166,{134160}); stacks(172648,{135841})
stacks(106208,{32986}); stacks(106209,{38963}); stacks(49247,{38965})
stacks(215672,{36908}); stacks(103879,{103483,103571,103623,103503,103706,103710})
stacks(40062,{40060,99781}); stacks(125749,{118226,125750})
stacks(38802,{38802}); stacks(100306,{46340,46348,46356}); stacks(100474,{28591,38891,38861})
stacks(117625,{117624,123699,123704}); stacks(117638,{117637,123718,123719}) -- Venom / Ricochet Skull
stacks(122658,{20805}); stacks(38747,{38745}) -- Molten Whip (Seething Fury) / Carve
stacks(63430,{16536,63430}); stacks(63456,{40489,63456}); stacks(63473,{40493,63473})
-- Taunt immunity stacks are target-local and can come from other players.
R.targetStacks={[31816]=134340}
for _,id in ipairs({38989,20492,20496,28306,38256,38250,39475,42056,42060,183430,186531,183165,40336,222966,217180,219972,216674}) do
    R.targetStacks[id]=52790
    if id~=183430 and id~=222966 and id~=217180 and id~=219972 and id~=216674 then effect(id,38254) end
end
stacks(184220,{183261,198282,186189,198288,186191,198292,183537,198309,186193,198330,186200,198537,
    183447,198563,186207,198564,186209,198567,183241,184362,185901,185823,238174,238249,238482,
    185794,188658,185803,188787,182977,188780,185805,193331,183122,193397,186366,193398})
stacks(267744,{58405,58742,58864,58798}); stacks(137189,{137184,39105})

-- Single-target identities: target transfer replaces the previous instance.
for _,id in ipairs({28025,28308,28311,24326,24330,24328}) do
    R.singleTarget[id]=true
    effect(id,id)
end
-- Haunting Curse has two different effect IDs, not a single fixed timer.
R.duration["a:24330"][1].followup=89491
R.singleTarget[89491]=true
R.nextPhase[24330]=89491
R.previousPhase[89491]=24330
R.phaseInfo[24330]={duration=3.5,count=2}; R.phaseInfo[89491]={duration=8.5,count=1}

-- Shared effects must be attributed to a confirmed cast, not merely to
-- the presence of a buff with the same ID. Keep their records per skill.
R.shared={}; R.sharedRecipients={}
local function shared(map,recipients)
    for ability,id in pairs(map) do
        R.shared[ability]={{effect=id,mode="effect",duration=0,nativeFallback=true,shared=true}}
        if recipients then R.sharedRecipients[ability]=id end
    end
end
shared({[86122]=61694,[86126]=61694,[86130]=61694,
    [37243]=61693,[40094]=61744,[40103]=61693,[85862]=61704,
    [32673]=61711,[118352]=61737,[22314]=61735,[26209]=61704,[26807]=61704,
    [38566]=61736,[40211]=61736,[40215]=61736,[186489]=61721},true)
-- All three morphs give the group Minor Resolve. Minor Protection (61721)
-- is personal and remains the Freedom timer only, not a recipient source.
R.sharedRecipients[185912]=61693; R.sharedRecipients[183401]=61693; R.sharedRecipients[186489]=61693
-- Group buffs may arrive as AREA EFFECT notifications, and group recipients
-- may have a zero runtime unit ID. Only the audited group buff effects can
-- use roster identity in place of an enemy-style target ID.
R.groupBuffEffects={[258658]=true,[258666]=true,[258661]=true,[194637]=true,[194646]=true}
for _,id in pairs(R.sharedRecipients) do R.groupBuffEffects[id]=true end
-- The personal Molten Weapons morph effect is not necessarily the buff
-- reported on other group players. Accept the common Major Brutality /
-- Sorcery effect variants only during a confirmed Molten Weapons cast.
local weaponRecipients={61665,76518,61687,92503}
local resolveRecipients={61693,176991}
R.groupRecipientAliases={[29043]=weaponRecipients,[31874]=weaponRecipients,[31888]=weaponRecipients,
    [185912]=resolveRecipients,[183401]=resolveRecipients,[186489]=resolveRecipients}
for _,id in ipairs(weaponRecipients) do R.groupBuffEffects[id]=true end
for _,id in ipairs(resolveRecipients) do R.groupBuffEffects[id]=true end
-- The War Horn resource buff and Aggressive Horn's Major Force are
-- separate effects, not one thirty-second timer.
R.duration["a:40223"][2]={effect=61747,mode="effect",duration=0,shared=true}
shared({[38814]=131562,[38807]=61745,[28304]=61723,[38268]=61723,[38264]=61708,
    [21157]=61665,[38914]=61665,[83465]=55131,[85257]=55131,
    [31531]=86304,[40109]=86304,[40116]=86304,[29556]=61716,[39195]=61716,[39192]=61716,
    [29552]=61694,[39205]=61694,[39197]=61694,[58325]=61704,[58742]=61743,
    [40441]=61694,[103503]=61746,[103706]=61746,[103710]=61746,
    [21007]=61736,[21014]=61736,[20499]=61745,[22057]=61737,[22110]=61737,
    [25484]=79717,[18342]=79717,[25493]=79717,[33375]=61716,[35414]=61716,[35419]=61716,
    [25352]=147643,[37470]=147643,[33316]=61665,[36901]=61665,[36891]=61665,
    [115177]=61723,[118308]=61723,[114196]=61726,[185918]=79717,[185921]=79717,[183267]=145975,
    [183648]=61694,[185908]=61694,[186477]=61694,[238256]=61694,
    [122174]=106754,[122388]=106754,[122391]=106754})
-- Exact, non-shared effect IDs can use the usual observation path.
effects({[25375]=234617,[25380]=234617,[32633]=137257,[39114]=137312,
    [39075]=32455,[39076]=32455,[38965]=49268})
-- Only known Goading variants; crafted scripts are checked before binding.
R.craftedTaunt={ [217180]=true,[219972]=true,[222966]=true,[216674]=true }
R.tauntRule={{effect=38254,mode="effect",duration=0,nativeFallback=true,shared=true}}
-- Independent charge/proc state, never inherited from a different slot.
R.chargeSkills={[256798]=5,[20824]=5,[46331]=3,
    [35750]=1,[40372]=1,[40382]=1,[40465]=1,[37475]=1}
R.trapEffects={[35750]=35756,[40372]=40375,[40382]=40385,[40465]=40468,[37475]=76639}
R.chargeAliases={[23806]=256798,[20816]=20824}
R.chargeTrigger={[143808]=46331}
R.readyProcs={[86027]=91416}
R.contingency={}
for _,id in ipairs({221185,217611,221354,221392,221155,221156,221157,221158,217655,217613,217621,217605,221179,221180,221181,221182,221183,221184,221169,221170,221171,221172,217656,217652,217609,217610,221356,218340,221166,221167,221168,221159,221160,221161,217654,217528,217604,217616,217618,217653,217657,217659,218341,219662,221189,221352,221353,221355,221734,222285,222364,222678,221173,221174,221175,221176,221177,217608,240148,240149,240150}) do R.contingency[id]=true end
R.contingencyProcs={217528,222285,222678}
R.ultPassives={
    [37]={name="Blessing at the Peak",duration=6,ids={29474,45005}},
    [40]={name="Transfer",duration=4,ids={36589,45146}},
    [127]={name="Savage Beast",duration=8,ids={88512,88513}},
    [27]={name="Prism",duration=6,ids={31746,45217}},
    [133]={name="Corpse Consumption",duration=16,ids={120611,120612}},
    [219]={name="Implacable Outcome",duration=8,ids={185051,185070}},
}

-- Explicit rendering semantics are independent of the global stack threshold.
R.noStackGlow={}
-- Bolt Escape / Streak / Ball of Lightning: their stacks are a cost penalty,
-- nothing to proc, so three or more never light the golden loop.
for _,id in ipairs({23234,23236,23277}) do R.noStackGlow[id]=true end
for _,id in ipairs({58405,58798,58742,58864,61902,61907,61919,61930,61927,61932,
    185794,188658,185803,188787,182977,188780}) do R.noStackGlow[id]=true end
-- Explicit golden-loop thresholds; Focus's cast-readiness threshold is
-- deliberately independent from its full ten-stack visual notification.
R.stackReadyAt={[24165]=4,[61919]=10,[61930]=10,[61927]=10,[61932]=10}
R.focusRequired={[61902]=5,[61907]=5,[61919]=5,[61930]=5,[61927]=4,[61932]=4}
-- All Focus variants fire their spectral bow at an enemy once ready.
R.focusTarget={[61902]=true,[61907]=true,[61919]=true,[61930]=true,[61927]=true,[61932]=true}
R.noExpiryGlow={}
for _,id in ipairs({39077,62988,131562,45834,137257,137312,130129,178330,125750,34733,25256}) do R.noExpiryGlow[id]=true end
R.noNativeTimer={[46324]=true,[114716]=true}
for _,id in ipairs({126659,38687,38685,43714,33386,34843,34851,117888,115307,117940,117919,115410,118367,118379}) do R.noNativeTimer[id]=true end
R.noExpiryGlow[267744]=true
R.stackOnlyEffects={[267744]=true} -- Blood Hunger: stack badge, never a duration timer.
R.authoritativeStacks={[267744]=true,[122585]=true,[122586]=true,[122587]=true,[184220]=true,[203447]=true}
R.fragProc={[46324]=true,[114716]=true}
R.noDurationFill={[46331]=true,[46324]=true,[114716]=true,[24165]=true,
    [256798]=true,[20824]=true}
for id in pairs(R.focusRequired) do R.noDurationFill[id]=true end
R.duration["a:46331"]={{effect=46331,mode="auto",duration=6,castDurationAPI=true}}
R.phaseBadge={[24330]=true}
R.fixedObservedDuration={[117805]=10} -- Boneyard's observed ground instance

-- Ferocious Roar: its group Major Courage is distinct from Off Balance and
-- the other roar buff. The second counter is plain text on the top right.
R.duration["a:39113"]={
    {effect=109966,mode="cast",duration=20},
    {mode="off",effect=0,duration=0},
    {effect=131353,mode="effect",duration=0},
}
R.sharedRecipients[39113]=109966
R.groupBuffEffects[109966]=true
R.allyCounts[109966]=true
R.topRightTimer={[39113]=true}
-- Purchased mastery only, with no synthetic cast timer.
R.wardMastery={}
for _,id in ipairs({28418,29482,29489}) do
    R.wardMastery[id]={{effect=id,mode="effect",duration=0,nativeFallback=true},
        {effect=268274,mode="effect",duration=0}}
end
-- Remaining explicit observations. Proc and shared stack
-- identities are deliberately separated from actual duration countdowns.
shared({[29173]=61743,[40195]=61744,[116095]=61665})
effects({[46324]=46327,[114716]=46327,[117637]=117638,[123718]=117638,[123719]=117638,
    [117624]=117625,[123699]=117625,[123704]=117625})
for _,id in ipairs({46324,114716}) do R.duration["a:"..id][1].nativeFallback=false end
-- Tethers start on confirmed use; the observed effect replaces the fallback.
for _,id in ipairs({116445,118009,118764,116450,118123,118071}) do
    local rule=R.duration["a:"..id][1]
    rule.mode="auto"; rule.duration=(id==116445 or id==118009 or id==118764) and 20 or 12
end
-- Actual Blood Hunger meter; no native counter from a different skill.
effects({[58405]=267744,[58798]=267744})
effect(117805,117805)
