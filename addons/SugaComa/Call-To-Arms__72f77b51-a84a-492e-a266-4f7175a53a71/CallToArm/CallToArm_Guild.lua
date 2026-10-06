-- CallToArm_Guild.lua (guild selection + lock)
local CallToArm = _G.CallToArm or {}
_G.CallToArm = CallToArm
CallToArm.Guild = CallToArm.Guild or {}

local G = CallToArm.Guild

local function Trim(text)
    if zo_strtrim then
        return zo_strtrim(text)
    end
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

--------------------------------------------------------------
-- Guild selection
--------------------------------------------------------------
function G.FindGuildIdByName(name)
    if not name or name == "" then return 0 end
    for i = 1, GetNumGuilds() do
        local gid = GetGuildId(i)
        if gid and gid ~= 0 then
            if GetGuildName(gid) == name then
                return gid
            end
        end
    end
    return 0
end

function G.AutoSelectDefaultGuildIfNeeded()
    if (CallToArm.SV.selectedGuildId or 0) ~= 0 then return end
    local want = (CallToArm.SV.guild and CallToArm.SV.guild.defaultName) or "CallToArm"
    local gid = G.FindGuildIdByName(want)
    if gid ~= 0 then
        CallToArm.SV.selectedGuildId = gid
    end
end

function G.GetSelectedGuildId()
    return CallToArm.SV.selectedGuildId or 0
end

function G.SetSelectedGuildId(gid)
    gid = tonumber(gid) or 0
    local previousGuildId = tonumber(CallToArm.SV.selectedGuildId) or 0
    CallToArm.SV.selectedGuildId = gid

    if previousGuildId ~= gid and CallToArm.Leaderboard then
        CallToArm.Leaderboard._journalGuildCache = {}
        CallToArm.Leaderboard._lastCacheAt = 0
        if gid ~= 0 and CallToArm.Leaderboard.RefreshGuildMemberCache then
            CallToArm.Leaderboard.RefreshGuildMemberCache(gid, true)
        end
    end
end

function G.GetSelectedGuildName()
    local gid = G.GetSelectedGuildId()
    if gid == 0 then return "" end
    return GetGuildName(gid) or ""
end

--------------------------------------------------------------
-- Per-guild storage (byGuild)
--------------------------------------------------------------
local function EnsureByGuild(gid)
    if not CallToArm.SV then return nil end
    CallToArm.SV.byGuild = CallToArm.SV.byGuild or {}
    if gid and gid ~= 0 then
        if CallToArm.SV.byGuild[gid] == nil then
            CallToArm.SV.byGuild[gid] = {}
        end
        local g = CallToArm.SV.byGuild[gid]
        g.campaign = g.campaign or { homeCampaignId = 0 }
        g.cta = g.cta or {}
        return g
    end
    return nil
end

--------------------------------------------------------------
-- Lock state
--------------------------------------------------------------
local function EnsureLockState()
    CallToArm.SV.lock = CallToArm.SV.lock or {
        enabled = false,
        armingUntil = 0,
        lockedUntil = 0,
        guildId = 0,
        campaignId = 0,
        triggeredAt = 0,
    }
    return CallToArm.SV.lock
end

function G.GetLockState()
    return EnsureLockState()
end

function G.GetLockedGuildId()
    local lock = EnsureLockState()
    return tonumber(lock.guildId) or 0
end

function G.GetLockedCampaignId()
    local lock = EnsureLockState()
    return tonumber(lock.campaignId) or 0
end

function G.IsLockArming()
    local lock = EnsureLockState()
    local now = GetTimeStamp and GetTimeStamp() or 0
    return lock.enabled == true and (tonumber(lock.armingUntil) or 0) > now
end

function G.IsLocked()
    local lock = EnsureLockState()
    local now = GetTimeStamp and GetTimeStamp() or 0
    return lock.enabled == true and (tonumber(lock.lockedUntil) or 0) > now
end

function G.IsLockActive()
    return G.IsLockArming() or G.IsLocked()
end

function G.CancelLock()
    local lock = EnsureLockState()
    lock.enabled = false
    lock.armingUntil = 0
    lock.lockedUntil = 0
    lock.guildId = 0
    lock.campaignId = 0
    lock.triggeredAt = 0
end

local function ApplyHardLock(lock, now, durationSeconds)
    durationSeconds = tonumber(durationSeconds) or 0
    if durationSeconds < 0 then durationSeconds = 0 end

    lock.enabled = true
    lock.armingUntil = 0
    lock.lockedUntil = now + durationSeconds
    lock.triggeredAt = now

    if CallToArm.CTA and CallToArm.CTA.SetRepresentedGuild then
        CallToArm.CTA.SetRepresentedGuild(lock.guildId)
    end
end

function G.StartLockArming(gid, campaignId, armingSeconds)
    gid = tonumber(gid) or 0
    campaignId = tonumber(campaignId) or 0
    armingSeconds = tonumber(armingSeconds) or 300
    if armingSeconds < 1 then armingSeconds = 1 end
    if gid == 0 or campaignId == 0 then return false end

    local lock = EnsureLockState()
    local now = GetTimeStamp and GetTimeStamp() or 0
    lock.enabled = true
    lock.guildId = gid
    lock.campaignId = campaignId
    lock.armingUntil = now + armingSeconds
    lock.lockedUntil = 0
    lock.triggeredAt = 0
    return true
end

function G.ConfirmLockNow(gid, campaignId)
    gid = tonumber(gid) or 0
    campaignId = tonumber(campaignId) or 0

    local lock = EnsureLockState()
    if gid == 0 then gid = tonumber(lock.guildId) or 0 end
    if campaignId == 0 then campaignId = tonumber(lock.campaignId) or 0 end
    if gid == 0 or campaignId == 0 then return false end

    local now = GetTimeStamp and GetTimeStamp() or 0
    local remaining = 0
    if GetSecondsUntilCampaignEnd then
        remaining = tonumber(GetSecondsUntilCampaignEnd(campaignId)) or 0
    end
    if remaining < 0 then remaining = 0 end

    lock.guildId = gid
    lock.campaignId = campaignId
    ApplyHardLock(lock, now, remaining)
    return true
end

function G.UpdateLockState()
    local lock = EnsureLockState()
    if lock.enabled ~= true then return false end

    local now = GetTimeStamp and GetTimeStamp() or 0
    local armingUntil = tonumber(lock.armingUntil) or 0
    local lockedUntil = tonumber(lock.lockedUntil) or 0

    if armingUntil > 0 and now >= armingUntil and lockedUntil <= now then
        return G.ConfirmLockNow(lock.guildId, lock.campaignId)
    end

    if lockedUntil > 0 and now >= lockedUntil then
        G.CancelLock()
        return true
    end

    return false
end

--------------------------------------------------------------
-- Campaign
--------------------------------------------------------------
function G.GetHomeCampaignId(gid)
    gid = gid or G.GetSelectedGuildId()
    local g = EnsureByGuild(gid)
    if not g then return 0 end
    return tonumber(g.campaign and g.campaign.homeCampaignId) or 0
end

function G.SetHomeCampaignId(gid, campaignId)
    gid = gid or G.GetSelectedGuildId()
    local g = EnsureByGuild(gid)
    if not g then return end
    g.campaign.homeCampaignId = tonumber(campaignId) or 0
end

function G.FindDefaultHomeCampaignId()
    -- Update 51 exposes the actual assigned/home campaign directly. Prefer it
    -- over guessing from the browser list.
    if GetAssignedCampaignId then
        local assignedCampaignId = tonumber(GetAssignedCampaignId()) or 0
        if assignedCampaignId ~= 0 then return assignedCampaignId end
    end

    if GetNumSelectionCampaigns and GetSelectionCampaignId then
        local best = 0
        local bestDuration = -1
        for i = 1, GetNumSelectionCampaigns() do
            local campaignId = GetSelectionCampaignId(i)
            if campaignId and campaignId ~= 0 then
                local rulesetId = GetCampaignRulesetId and GetCampaignRulesetId(campaignId) or nil
                local rulesetType = rulesetId and GetCampaignRulesetType and GetCampaignRulesetType(rulesetId) or nil
                local isCyrodiil = rulesetType == nil or rulesetType == CAMPAIGN_RULESET_TYPE_CYRODIIL
                local duration = rulesetId and GetCampaignRulesetDurationInSeconds
                    and tonumber(GetCampaignRulesetDurationInSeconds(rulesetId)) or 0
                if isCyrodiil and duration > bestDuration then
                    best = campaignId
                    bestDuration = duration
                end
            end
        end
        if best ~= 0 then
            return best
        end
    end
    return 0
end

--------------------------------------------------------------
-- Alliance cache
--------------------------------------------------------------
function G.RefreshSelectedGuildAllianceCache()
    local gid = G.GetSelectedGuildId()
    if gid == 0 then
        CallToArm.SV.guild.alliance = 0
        return 0
    end

    local alliance = GetGuildAlliance(gid) or 0
    CallToArm.SV.guild.alliance = alliance
    return alliance
end

function G.GetSelectedGuildAlliance()
    local cached = CallToArm.SV.guild and CallToArm.SV.guild.alliance or 0
    if cached and cached ~= 0 then return cached end
    return G.RefreshSelectedGuildAllianceCache()
end
