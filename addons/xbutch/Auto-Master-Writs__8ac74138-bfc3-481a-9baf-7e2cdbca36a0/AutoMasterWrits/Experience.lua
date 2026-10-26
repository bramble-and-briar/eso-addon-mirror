local AMW = AutoMasterWrits
AMW.xpEffects = { [64210]=50, [66776]=50, [85501]=50, [89683]=100, [85502]=100, [88445]=150, [85503]=150 }
AMW.xpMinimumSeconds = 3

function AMW:RefreshXPWorker()
    local revision = self.xpRevision or 0
    local best = { percent = 0, ends = 0, name = "No recognized XP consumable" }
    for index = 1, GetNumBuffs("player") do
        local name, _, ends, _, _, _, _, _, _, _, id = GetUnitBuffInfo("player", index)
        local percent = self.xpEffects[id]
        if percent and ends and ends > GetFrameTimeSeconds()
            and (percent > best.percent or (percent == best.percent and ends > best.ends)) then
            best = { percent = percent, ends = ends, name = name, abilityId = id }
        end
        self:Yield()
    end
    if revision == (self.xpRevision or 0) then
        self.xpCache, self.xpDirty = best, false
    else
        self.xpDirty = true
    end
    return self:GetXPStatus()
end

function AMW:GetXPStatus()
    local cached = self.xpCache
    local remaining = cached and math.max(0, cached.ends - GetFrameTimeSeconds()) or 0
    return {
        name = cached and cached.name or "XP status not checked",
        percent = cached and cached.percent or 0,
        remaining = remaining,
        ready = not self.xpDirty and cached and cached.percent >= 150 and remaining >= self.xpMinimumSeconds or false,
    }
end

function AMW:RequireXP()
    if self:GetXPStatus().ready then return true end
    return false, "Delivery paused: 150% XP consumable missing or expiring."
end

function AMW:ShowXPStatus()
    if not self:EnsureRuntime() then return end
    self:StartJob("xpStatus", function()
        local xp = self:RefreshXPWorker()
        self:Print(string.format("%s: %d%%, %.0f seconds remaining.", xp.name, xp.percent, xp.remaining))
    end)
end

function AMW:PrintBuffDiagnostics()
    if not self:EnsureRuntime() then return end
    self:StartJob("diagnostics", function()
        self:Print("Active effects (ID, name, remaining seconds):")
        for index = 1, GetNumBuffs("player") do
            local name, _, ends, _, _, _, _, _, _, _, id = GetUnitBuffInfo("player", index)
            self:Print(string.format("%s: %s, %.0fs", tostring(id), name or "", math.max(0, (ends or 0) - GetFrameTimeSeconds())))
            self:Yield()
        end
    end)
end

