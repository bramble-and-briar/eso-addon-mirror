-- Minimal gameplay exceptions from CombatMetronome 1.7.7 Ability.lua and
-- Stacks.lua. No UI data or fixed weapon-duration table. Audit on API updates.
local D = {
    errorGraceMs = 100, dodgeId = 28549, cruxId = 184220, cruxExtensionMs = 338,
    fatecarver = { [183122] = true, [193397] = true },
    beams = { [63029] = true, [63044] = true, [63046] = true },
    -- Indefinite/toggled abilities have no meaningful finite 0..100% charge.
    -- Do not import the reference's artificial Meditate 1000 ms bar.
    unbounded = { [103665] = true, [103492] = true, [103652] = true },
    mendWounds = { [107579]=true, [107583]=true, [107629]=true, [107630]=true,
        [107636]=true, [107637]=true, [107638]=true, [114990]=true, [114991]=true,
        [114992]=true, [118617]=true, [118638]=true, [118645]=true },
    controlLoss = {}, failures = {}, directHit = {},
}
OneCrosshair.HeavyChannelData = D
local function Set(target, ...)
    for i = 1, select("#", ...) do local value = select(i, ...); if value ~= nil then target[value] = true end end
end
Set(D.controlLoss, ACTION_RESULT_KNOCKBACK, ACTION_RESULT_PACIFIED, ACTION_RESULT_STAGGERED,
    ACTION_RESULT_STUNNED, ACTION_RESULT_INTERRUPT, ACTION_RESULT_FEARED, ACTION_RESULT_LEVITATED)
Set(D.failures, ACTION_RESULT_FAILED, ACTION_RESULT_FAILED_REQUIREMENTS, ACTION_RESULT_ABILITY_ON_COOLDOWN,
    ACTION_RESULT_INSUFFICIENT_RESOURCE, ACTION_RESULT_SILENCED, ACTION_RESULT_TARGET_DEAD,
    ACTION_RESULT_NO_LOCATION_FOUND, ACTION_RESULT_IMMUNE, ACTION_RESULT_CASTER_DEAD)
Set(D.directHit, ACTION_RESULT_DAMAGE, ACTION_RESULT_CRITICAL_DAMAGE, ACTION_RESULT_DAMAGE_SHIELDED,
    ACTION_RESULT_BLOCKED_DAMAGE)
function D.Crux()
    for i = 1, GetNumBuffs("player") do
        local _, _, _, _, stacks, _, _, _, _, _, id = GetUnitBuffInfo("player", i)
        if id == D.cruxId then return math.max(0, math.min(3, stacks or 0)) end
    end
    return 0
end
