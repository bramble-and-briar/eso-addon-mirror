local O=ObsidianHUD
-- Staff-dependent slot/effect identities from the reference's destruction-
-- staff resolver. Each morph stays separate; only its elemental variants
-- share a timer when the inactive bar reports a generic/different variant.
O.wallStaffSkills={}
for _,family in ipairs({{28858,28807,28854,28849},
    {39052,39053,39073,39067},{39011,39012,39018,39028}}) do
    for _,id in ipairs(family) do
        O.wallStaffSkills[id]=family
        O.timerAliases[id]=family[1]
    end
end
-- Duration/phase facts checked against the local FAB+ special-effect rules.
-- true reads ESO's current duration; numbers are seconds for explicit cases.
O.timerOnUse={
    -- Ground walls may not emit a usable own-target interval. Use the actual
    -- ability duration on activation, then let real effect/slot data correct it.
    [28858]=true,[39052]=true,[39011]=true,
    [35750]=true,[40372]=true,[40382]=true,
    [28727]=true,[38312]=true,[38317]=true,
    [86135]=true,[86139]=true,[86143]=true,
    [116445]=20,[118009]=20,[118764]=20,
    [116450]=12,[118123]=12,[118071]=12,
    [22265]=true,[22259]=true,[22262]=true,
    -- Skeletal Mage and morphs: the native effect is announced after the
    -- summoning animation. Start from the real ability duration on use.
    [114317]=true,[118680]=true,[118726]=true,
}
O.timerPhases={
    [24330]={id=24330,phase=1,seconds=3.5},
    [89491]={id=24330,phase=2,seconds=8.5},
    [86009]={id=86009,phase=1,seconds=3},
    [178020]={id=86009,phase=2,seconds=6},
    [86019]={id=86019,phase=1,seconds=3},
    [146919]={id=86019,phase=2,seconds=3},
    [86015]={id=86015,phase=1,seconds=3},
    [178028]={id=86015,phase=2,seconds=6},
    [35756]={id=35750,phase=2},[40375]={id=40372,phase=2},
    [40385]={id=40382,phase=2},[40468]={id=40465,phase=2},
    [76639]={id=37475,phase=2,seconds=4},
}
-- Corpse-targeted skills have a different slotted and active effect ID.
for ability,effect in pairs({[116445]=115924,[118009]=118008,[118764]=118763,
    [116450]=115926,[118123]=118122,[118071]=118070}) do
    O.timerSources[ability]=effect
    -- The client can expose this effect ID as the slotted ability too (for
    -- example Detonating Siphon 118763). Both IDs need the same cast state.
    O.timerAliases[effect]=ability
end
O.timerSharedEffects={[38254]=true,[79717]=true,[147643]=true}
-- These effects begin on a successful activation. Prefer the selected child
-- effect's actual API duration instead of an unrelated parent duration.
O.timerUseChildDuration={[61503]=61504,[61505]=61506,[61507]=61693}
for id in pairs(O.timerUseChildDuration) do O.timerOnUse[id]=true end
-- Resolving Vigor intentionally displays the 20-second resistance buff.
-- Its own cast starts this timer; other skills/allies granting the shared
-- Minor Resolve effect must not start it on an unused Vigor slot.
O.timerOnUse[61507]=20
for rank,base in pairs({[63236]=61503,[63238]=61503,[63240]=61503,
    [63243]=61505,[63245]=61505,[63247]=61505,
    [63249]=61507,[63252]=61507,[63255]=61507}) do
    O.timerAliases[rank]=base
end
-- Active shield variants use another event/slot ID for the same effect.
for variant,base in pairs({[126604]=28727,[126608]=38312,[38324]=38317}) do
    O.timerAliases[variant]=base
    O.timerOnUse[variant]=true
end
function O.IsSharedTimerEffect(id)
    return (id>=61600 and id<=61800) or O.timerSharedEffects[id] or false
end
-- These skills announce duration via combat results rather than a usable
-- EFFECT_CHANGED interval. Class-passive cooldowns are not skill durations.
O.timerCombatRules={
    [28297]={result="ACTION_RESULT_EFFECT_GAINED_DURATION"},
    [38794]={result="ACTION_RESULT_EFFECT_GAINED_DURATION"},
    [222370]={result="ACTION_RESULT_EFFECT_GAINED_DURATION"},
    [217512]={result="ACTION_RESULT_POWER_ENERGIZE",seconds=5},
    [216940]={result="ACTION_RESULT_POWER_ENERGIZE",seconds=5},
    [117757]={id=117749,seconds=20}, -- Grave Lord's Sacrifice activation
}
