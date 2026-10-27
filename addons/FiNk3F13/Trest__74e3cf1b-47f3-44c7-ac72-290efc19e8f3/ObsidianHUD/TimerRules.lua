local O=ObsidianHUD
-- Duration/phase facts checked against the local FAB+ special-effect rules.
-- true reads ESO's current duration; numbers are seconds for explicit cases.
O.timerOnUse={
    [35750]=true,[40372]=true,[40382]=true,
    [28727]=true,[38312]=true,[38317]=true,
    [86135]=true,[86139]=true,[86143]=true,
    [116445]=20,[118009]=20,[118764]=20,
    [116450]=12,[118123]=12,[118071]=12,
    [22265]=true,[22259]=true,[22262]=true,
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
end
O.timerSharedEffects={[38254]=true,[79717]=true,[147643]=true}
function O.IsSharedTimerEffect(id)
    return (id>=61600 and id<=61800) or O.timerSharedEffects[id] or false
end
