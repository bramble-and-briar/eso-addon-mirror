LiveBuffUptimeCooldowns = {}
local Cooldowns = LiveBuffUptimeCooldowns
Cooldowns.profiles = {
    { key = "turningTide", name = "Turning Tide (eigener Proc)", id = 167350, seconds = 15, effect = 106754, unit = "reticleover" },
    { key = "archdruid", name = "Archdruid Devyric (eigener Proc)", id = 176813, seconds = 15, effect = 106754, unit = "reticleover" },
    { key = "nunatak", name = "Nunatak (eigener Proc)", id = 167682, seconds = 15, effect = 145977, unit = "reticleover" },
    { key = "roaring", name = "Roaring Opportunist (pro Empfaenger)", id = 135923, seconds = 22, effect = 93109, recipient = true },
    { key = "tremorscale", name = "Tremorscale (eigener Proc)", id = 80517, seconds = 10, effect = 80866, unit = "reticleover" },
    { key = "crimsonOath", name = "Crimson Oath's Rive (eigener Proc)", id = 159291, seconds = 12, effect = 159288, unit = "reticleover" },
    { key = "martialKnowledge", name = "Martial Knowledge (eigener Proc)", id = 127070, seconds = 8, effect = 127070, unit = "reticleover" },
    { key = "drakesRush", name = "Drake's Rush (eigener Proc)", id = 150974, seconds = 18, effect = 61709, friendly = true },
    { key = "magmaIncarnate", name = "Magma Incarnate (eigener Proc)", id = 161527, seconds = 15, effect = 61693, effects = {61693, 147417}, friendly = true },
    { key = "pillager", name = "Pillager's Profit (pro Empfaenger)", id = 172056, ids = {172056, 172055}, seconds = 45, effect = 172055, recipient = true, gainOnly = true },
    { key = "symphony", name = "Symphony of Blades (pro Empfaenger)", id = 117111, seconds = 18, effect = 117111, recipient = true },
    { key = "crusader", name = "Crusader (eigener Proc)", id = 160395, seconds = 20, effect = 147417, friendly = true },
    { key = "imperium", name = "Brands of Imperium (eigener Proc)", id = 66887, seconds = 12, effect = 66887, friendly = true },
}
local procs = {}

function Cooldowns.IsProc(profile, id)
    if profile.id == id then return true end
    for _, candidate in ipairs(profile.ids or {}) do
        if candidate == id then return true end
    end
    return false
end

function Cooldowns.TrackedId(config)
    -- Compatibility for trackers created with the stack ID: measure the real debuff.
    if config.id == 172992 and config.unit == "reticleover" then return 145977 end
    return config.id
end

function Cooldowns.Profile(config, canonicalId)
    for _, profile in ipairs(Cooldowns.profiles) do
        local nunatakTracker = profile.key == "nunatak" and canonicalId == 172992
        local selected = profile.key == config.cooldownProfile or (nunatakTracker and config.cooldownProfile == nil)
        local effectMatches = profile.effect == canonicalId or nunatakTracker
        for _, id in ipairs(profile.effects or {}) do
            effectMatches = effectMatches or id == canonicalId
        end
        local unitMatches = profile.unit == config.unit
            or ((profile.recipient or profile.friendly) and (config.unit == "player" or config.unit == "group"))
        if selected and effectMatches and unitMatches then
            return profile
        end
    end
end

function Cooldowns.Start(profile, member, now)
    local key = profile.key .. ":" .. member
    local previous = procs[key]
    -- AoE hits and effect notifications from one proc must not restart the cooldown.
    if previous and previous.ends > now then return false end
    procs[key] = { starts = now, ends = now + profile.seconds }
    return true
end

function Cooldowns.Get(profile, member, now)
    local effect = profile and procs[profile.key .. ":" .. member]
    return effect and effect.ends > now and effect or nil
end
