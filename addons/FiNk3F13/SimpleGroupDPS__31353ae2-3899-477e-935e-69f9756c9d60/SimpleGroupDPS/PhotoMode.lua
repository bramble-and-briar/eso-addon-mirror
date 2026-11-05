-- Screenshot data only: never passed to the meter, saved results or sharing bridge.
SimpleGroupDPS_PhotoMode = {}
function SimpleGroupDPS_PhotoMode:GetPreview()
    local rows = {}
    local names = {'SilverArrow','Moonblade','EmberStorm','ShadowFox','FrostNova','StarWeaver','NightBloom','SunStrike','IronGuard','StoneShield','DawnHealer','LunarGrace'}
    local classes = {2,3,1,4,6,5,117,2,1,4,6,5}
    local groupDPS, groupBossDPS = 0, 0
    for i = 1, 12 do
        local healer, tank = i > 10, i > 8 and i <= 10
        local boss = tank and (i == 9 and 8200 or 6400) or (136800 - (i - 1) * 7100)
        local total = boss + (tank and 3200 or 17600 + i * 900)
        rows[i] = {name = names[i], classId = classes[i], isPlayer = i == 3,
            role = healer and LFG_ROLE_HEAL or (tank and LFG_ROLE_TANK or LFG_ROLE_DPS),
            displayType = healer and 'healing' or 'damage',
            dps = not healer and total or nil, bossDPS = not healer and boss or nil,
            rawHPS = healer and (i == 11 and 54200 or 47600) or nil,
            effectiveHPS = healer and (i == 11 and 18400 or 16200) or nil}
        if not healer then groupDPS = groupDPS + total; groupBossDPS = groupBossDPS + boss end
    end
    local duration = 72
    local own = rows[3]
    return rows, {dps = own.dps, bossDPS = own.bossDPS, total = own.dps * duration,
        bossTotal = own.bossDPS * duration, groupDPS = groupDPS, groupBossDPS = groupBossDPS,
        groupTotal = groupDPS * duration, groupBossTotal = groupBossDPS * duration, durationMS = duration * 1000}
end
