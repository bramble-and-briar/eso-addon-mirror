local O=ObsidianHUD
-- Numeric ability/effect ID relationships checked against the user's local
-- FancyActionBar+ 2.19.8 config.lua. Only real positive counters are used;
-- its synthetic ready/proc symbols and target totals are not stack counts.
local groups={
    {122585,61902,61907}, {122586,61919,61930}, {122587,61927,61932}, -- Grim Focus, morphs and bow overrides
    {203447,24165}, -- Bound Armaments
    {122658,20805}, -- Molten Whip / Seething Fury
    {117638,117637,123718,123719}, -- Ricochet Skull
    {117625,117624,123699,123704}, -- Venom Skull
    {125749,125750}, -- Ruinous Scythe
    {184220,185794,188658,185803,188787,182977,188780, -- Crux
        185805,193331,183122,193397,186366,193398,183261,198282,
        186189,198288,186191,198292,183537,198309,186193,198330,
        186200,198537,183447,198563,186207,198564,186209,198567,
        183241,184362,185901,185823,238174,238249,238482},
    {51392,23234,23236,23277}, -- Bolt Escape fatigue
    {215672,36908}, -- Leeching Strikes cost reduction
    {38747,38745}, -- Carve; native counter handles target-only stacks
    {103879,103483,103571,103623,103503,103706,103710}, -- Spell Orb
    {106208,32986}, {106209,38963}, {49247,38965}, -- Mist fatigue
    {172418,132141}, {134166,134160}, {172648,135841}, -- Frenzy morphs
    {100306,46340,46348,46356}, -- Asylum destruction staff counter
    {100474,28591,38891,38861}, -- Asylum dual wield counter
    {40062,40060,99781}, -- Healing Springs / Grand Rejuvenation
    {61506,61503,61504,61505}, -- Echoing Vigor
    {267744,58405,58742,58864,58798}, -- Blood Hunger
    {137189,137184,39105}, -- Brutal Pounce / Carnage
}
O.stackSources={}
O.stackCounterIds={}
for _,group in ipairs(groups) do
    O.stackCounterIds[group[1]]=true
    for _,skill in ipairs(group) do O.stackSources[skill]=group[1] end
end
-- Counter thresholds indicate the next empowered cast, not a duration timer.
O.procStackThresholds={[117638]=2,[117625]=2,[122585]=5,[122586]=5,[122587]=5}
O.procReadyAbilities={
    [123719]=true,[123704]=true, -- third Ricochet/Venom Skull cast
    [61907]=true,[61930]=true,[61932]=true, -- spectral bow overrides
}
