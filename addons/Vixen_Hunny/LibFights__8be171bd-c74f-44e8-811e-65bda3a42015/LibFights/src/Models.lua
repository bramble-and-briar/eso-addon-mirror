--[[
    LibFights - Models (lightweight online machine-learning models)
    ------------------------------------------------------------------------
    All models learn incrementally while logging (they are only fed by the logger)
    and are cheap enough to run inside combat on PC and console.

      * Recursive Least Squares (RLS) regression per ability:
            hit = w0 + w1*maxMagicka + w2*maxStamina + w3*spellDamage + w4*weaponDamage
        trained on non-critical hits.  A separate "reference" model is trained only on
        targets with known resistance (target dummies by default, 18,200 resistance).
      * Target resistance / damage-reduction estimator: compares hits on a target with the
        reference model's prediction, converts the ratio into mitigation and resistance
        (660 resistance = 1%, 50% cap) and smooths with a 1-D Kalman filter.
      * Relative toughness: same comparison against the all-target model when no
        reference data exists yet.
      * Crit model: Beta-Bernoulli posterior of crit chance (overall and per ability) and a
        critical-damage estimate from mean(crit) / mean(non-crit) of the same ability.
      * Incoming damage reduction: armor mitigation (known from your resistances) plus an
        estimate of "other" DR (block, Major/Minor Protection, Evasion...) relative to the
        least-mitigated armor-normalised hit seen from each enemy ability.
      * Time-to-kill: exponentially-weighted linear regression of boss health over time.
      * DPS forecast: Holt's double exponential smoothing on per-second damage.

    The estimates are statistical: they assume damage-taken modifiers on the target
    (Vulnerability etc.) behave like on the reference target.  Every estimate exposes its
    sample count and variance so callers can judge confidence.
]]

local LF = LibFights
local Util, Const = LF.Util, LF.Const
local Models = {}
LF.Models = Models

local Clamp = Util.Clamp
local sqrt, max, min, exp = math.sqrt, math.max, math.min, math.exp

local function S() return LF.GetSettings() end

-- ===========================================================================
-- Primitive models
-- ===========================================================================

-- Recursive least squares with forgetting factor ---------------------------
local RLS = {}
RLS.__index = RLS
Models.RLS = RLS

local scratchPx, scratchK = {}, {}

function Models.NewRLS(n, lambda, delta)
    local o = setmetatable({ n = n, lambda = lambda or 0.998, w = {}, P = {}, count = 0, mse = 0 }, RLS)
    delta = delta or 100
    for i = 1, n do
        o.w[i] = 0
        o.P[i] = {}
        for j = 1, n do o.P[i][j] = (i == j) and delta or 0 end
    end
    return o
end

function RLS:Predict(x)
    local y, w = 0, self.w
    for i = 1, self.n do y = y + w[i] * x[i] end
    return y
end

function RLS:Update(x, y)
    local n, P, lam = self.n, self.P, self.lambda
    local Px, k = scratchPx, scratchK
    local denom = lam
    for i = 1, n do
        local s, Pi = 0, P[i]
        for j = 1, n do s = s + Pi[j] * x[j] end
        Px[i] = s
    end
    for i = 1, n do denom = denom + x[i] * Px[i] end
    if denom <= 1e-12 then return 0 end
    for i = 1, n do k[i] = Px[i] / denom end
    local err = y - self:Predict(x)
    local w = self.w
    for i = 1, n do w[i] = w[i] + k[i] * err end
    for i = 1, n do
        local Pi, ki = P[i], k[i]
        for j = 1, n do Pi[j] = (Pi[j] - ki * Px[j]) / lam end
    end
    self.count = self.count + 1
    self.mse = self.mse * 0.97 + err * err * 0.03
    return err
end

function RLS:GetRMSE()
    return sqrt(self.mse or 0)
end

-- 1-D Kalman filter (random walk) ------------------------------------------
local Kalman = {}
Kalman.__index = Kalman
Models.Kalman = Kalman

function Models.NewKalman(q, r)
    return setmetatable({ q = q, r = r, x = nil, p = nil, n = 0 }, Kalman)
end

function Kalman:Update(z)
    if self.x == nil then
        self.x, self.p = z, self.r
    else
        self.p = self.p + self.q
        local k = self.p / (self.p + self.r)
        self.x = self.x + k * (z - self.x)
        self.p = (1 - k) * self.p
    end
    self.n = self.n + 1
    return self.x
end

function Kalman:Std()
    return self.p and sqrt(self.p) or nil
end

-- Welford running mean / variance ------------------------------------------
local Welford = {}
Welford.__index = Welford
Models.Welford = Welford

function Models.NewWelford()
    return setmetatable({ n = 0, mean = 0, m2 = 0 }, Welford)
end

function Welford:Add(x)
    self.n = self.n + 1
    local d = x - self.mean
    self.mean = self.mean + d / self.n
    self.m2 = self.m2 + d * (x - self.mean)
end

function Welford:Variance()
    if self.n < 2 then return 0 end
    return self.m2 / (self.n - 1)
end

function Welford:Std()
    return sqrt(self:Variance())
end

-- Beta-Bernoulli rate -------------------------------------------------------
local Beta = {}
Beta.__index = Beta
Models.Beta = Beta

function Models.NewBeta(a, b)
    return setmetatable({ a = a or 1, b = b or 1 }, Beta)
end

function Beta:Observe(success)
    if success then self.a = self.a + 1 else self.b = self.b + 1 end
end

function Beta:Mean()
    return self.a / (self.a + self.b)
end

function Beta:Std()
    local a, b = self.a, self.b
    return sqrt(a * b / ((a + b) ^ 2 * (a + b + 1)))
end

function Beta:Count()
    return self.a + self.b - 2
end

-- Exponentially weighted linear trend (for time-to-kill) --------------------
local Trend = {}
Trend.__index = Trend
Models.Trend = Trend

function Models.NewTrend(halfLifeSec)
    return setmetatable({ hl = halfLifeSec or 30, sw = 0, st = 0, sy = 0, stt = 0, sty = 0, n = 0, t0 = nil, lastT = nil }, Trend)
end

function Trend:Add(t, y)
    if self.t0 == nil then self.t0 = t end
    local rt = t - self.t0
    if self.lastT then
        local decay = 0.5 ^ ((rt - self.lastT) / self.hl)
        self.sw, self.st, self.sy, self.stt, self.sty = self.sw * decay, self.st * decay, self.sy * decay, self.stt * decay, self.sty * decay
    end
    self.sw = self.sw + 1
    self.st = self.st + rt
    self.sy = self.sy + y
    self.stt = self.stt + rt * rt
    self.sty = self.sty + rt * y
    self.n = self.n + 1
    self.lastT = rt
    self.lastY = y
end

-- returns slope, intercept (relative time)
function Trend:Fit()
    if self.n < 3 then return nil end
    local denom = self.sw * self.stt - self.st * self.st
    if math.abs(denom) < 1e-9 then return nil end
    local slope = (self.sw * self.sty - self.st * self.sy) / denom
    local intercept = (self.sy - slope * self.st) / self.sw
    return slope, intercept
end

-- Holt linear exponential smoothing ----------------------------------------
local Holt = {}
Holt.__index = Holt
Models.Holt = Holt

function Models.NewHolt(alpha, beta)
    return setmetatable({ alpha = alpha or 0.3, beta = beta or 0.1, level = nil, trend = 0, n = 0 }, Holt)
end

function Holt:Update(y)
    if self.level == nil then
        self.level, self.trend = y, 0
    else
        local prev = self.level
        self.level = self.alpha * y + (1 - self.alpha) * (self.level + self.trend)
        self.trend = self.beta * (self.level - prev) + (1 - self.beta) * self.trend
    end
    self.n = self.n + 1
end

function Holt:Forecast(h)
    if self.level == nil then return nil end
    return self.level + (h or 1) * self.trend
end

-- ===========================================================================
-- Model state
-- ===========================================================================
local N_FEATURES = 5
local MIN_REF_SAMPLES = 8
local MIN_GEN_SAMPLES = 12
local state

local function NewState()
    return {
        refModels = {},     -- abilityId -> RLS (reference targets only)
        genModels = {},     -- abilityId -> RLS (all targets)
        critOverall = Models.NewBeta(1, 1),
        critAbility = {},   -- abilityId -> Beta
        critPairs = {},     -- abilityId -> { c = Welford, n = Welford }
        targets = {},       -- targetName -> estimate
        incoming = {},      -- abilityId -> { w = Welford, peak, n, name }
        incomingOther = Models.NewKalman(0.0005, 0.03),
        incomingArmor = Models.NewKalman(0.0005, 0.0005),
        ttk = {},           -- unitTag -> Trend
        dps = Models.NewHolt(0.3, 0.1),
        refSamples = 0,
        trainedHits = 0,
    }
end
state = NewState()

function Models.Reset()
    state = NewState()
end

function Models.GetState()
    return state
end

local featureBuf = { 1, 0, 0, 0, 0 }
local function Features(s)
    local x = featureBuf
    x[1] = 1
    x[2] = (s.maxMagicka or 0) / 10000
    x[3] = (s.maxStamina or 0) / 10000
    x[4] = (s.spellPower or s.weaponAndSpellDamage or 0) / 1000
    x[5] = (s.weaponPower or s.weaponAndSpellDamage or 0) / 1000
    return x
end

-- ---------------------------------------------------------------------------
-- Reference target detection
-- ---------------------------------------------------------------------------
local patternCache, patternSrc = nil, nil
local function RefPatterns()
    local src = S().referenceTargetPatterns or ""
    if src ~= patternSrc then
        patternSrc = src
        patternCache = {}
        for p in src:gmatch("[^,;]+") do
            p = Util.Trim(p)
            if p ~= "" then patternCache[#patternCache + 1] = Util.Lower(p) end
        end
    end
    return patternCache
end

function Models.IsReferenceTarget(targetName, targetType)
    if Const.UT_DUMMY and targetType == Const.UT_DUMMY then return true end
    if not targetName or targetName == "" then return false end
    local lname = Util.Lower(targetName)
    for _, p in ipairs(RefPatterns()) do
        if lname:find(p, 1, true) then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Outgoing damage
-- ---------------------------------------------------------------------------
local function GetTarget(name)
    local t = state.targets[name]
    if not t then
        t = {
            name = name,
            mitigation = Models.NewKalman(0.00002, 0.004),     -- fraction (0..1)
            resist = Models.NewKalman(2500, 9000000),           -- resistance points
            relative = Models.NewKalman(0.00002, 0.01),        -- damage taken vs average target
            samples = 0, relSamples = 0, overPenSamples = 0, cappedSamples = 0, lastPen = 0,
        }
        state.targets[name] = t
    end
    return t
end

function Models.ObserveOutgoing(abilityId, result, hit, damageType, targetName, targetType, isCrit, isTick)
    if hit <= 0 then return end
    -- crit chance
    state.critOverall:Observe(isCrit)
    local cb = state.critAbility[abilityId]
    if not cb then cb = Models.NewBeta(1, 1); state.critAbility[abilityId] = cb end
    cb:Observe(isCrit)
    -- crit damage pairs, per ability AND target so target mitigation does not bias the ratio
    local byTarget = state.critPairs[abilityId]
    if not byTarget then byTarget = {}; state.critPairs[abilityId] = byTarget end
    local tkey = (targetName and targetName ~= "") and targetName or "?"
    local pair = byTarget[tkey]
    if not pair then pair = { c = Models.NewWelford(), n = Models.NewWelford() }; byTarget[tkey] = pair end
    if isCrit then pair.c:Add(hit) else pair.n:Add(hit) end
    if isCrit then return end
    if result == Const.RESULT.BLOCKED_DAMAGE then return end

    local stats = LF.Stats.current
    if not stats then return end
    local x = Features(stats)
    local y = hit / 1000
    state.trainedHits = state.trainedHits + 1

    local gm = state.genModels[abilityId]
    if not gm then gm = Models.NewRLS(N_FEATURES); state.genModels[abilityId] = gm end
    local rm = state.refModels[abilityId]

    if Models.IsReferenceTarget(targetName, targetType) then
        if not rm then rm = Models.NewRLS(N_FEATURES); state.refModels[abilityId] = rm end
        rm:Update(x, y)
        state.refSamples = state.refSamples + 1
    elseif targetName and targetName ~= "" then
        local t = GetTarget(targetName)
        -- absolute estimate vs reference
        if rm and rm.count >= MIN_REF_SAMPLES then
            local pred = rm:Predict(x)
            if pred > 0 then
                local ratio = Clamp(y / pred, 0.05, 3)
                local pen = LF.Stats.GetPenetrationFor(damageType, stats)
                local refResist = S().referenceResistance or Const.DEFAULT_TARGET_RESISTANCE
                local mRef = LF.Stats.ArmorMitigationFromResist(refResist, pen)
                local mT = 1 - ratio * (1 - mRef)
                t.mitigation:Update(Clamp(mT, -1, 0.95))
                if mT <= 0 then
                    t.overPenSamples = t.overPenSamples + 1
                    t.resist:Update(pen)
                elseif mT >= Const.MAX_ARMOR_MITIGATION then
                    t.cappedSamples = t.cappedSamples + 1
                    t.resist:Update(Const.MAX_ARMOR_MITIGATION * Const.RESIST_FOR_FULL + pen)
                else
                    t.resist:Update(mT * Const.RESIST_FOR_FULL + pen)
                end
                t.samples = t.samples + 1
                t.lastPen = pen
            end
        end
        -- relative estimate vs all targets
        if gm.count >= MIN_GEN_SAMPLES then
            local pred = gm:Predict(x)
            if pred > 0 then
                t.relative:Update(Clamp(y / pred, 0.05, 3))
                t.relSamples = t.relSamples + 1
            end
        end
    end
    gm:Update(x, y)
end

-- ---------------------------------------------------------------------------
-- Incoming damage
-- ---------------------------------------------------------------------------
function Models.ObserveIncoming(abilityId, result, hit, damageType, sourceName, isCrit)
    if hit <= 0 then return end
    local stats = LF.Stats.current
    if not stats then return end
    local mArmor = LF.Stats.GetArmorMitigation(damageType, stats)
    state.incomingArmor:Update(mArmor)
    local norm = hit / (1 - mArmor)
    local inc = state.incoming[abilityId]
    if not inc then
        inc = { w = Models.NewWelford(), peak = 0, n = 0, name = GetAbilityName(abilityId), source = sourceName }
        state.incoming[abilityId] = inc
    end
    inc.w:Add(norm)
    inc.n = inc.n + 1
    if not isCrit and result ~= Const.RESULT.BLOCKED_DAMAGE then
        inc.peak = max(inc.peak * 0.9995, norm)
    end
    if inc.n >= 5 and inc.peak > 0 then
        local other = Clamp(1 - norm / inc.peak, 0, 0.95)
        state.incomingOther:Update(other)
        inc.lastOther = other
    end
    inc.lastArmor = mArmor
end

-- ---------------------------------------------------------------------------
-- Health trends / DPS
-- ---------------------------------------------------------------------------
function Models.ObserveUnitHealth(key, name, current, maxHealth, tSec)
    if not maxHealth or maxHealth <= 0 then return end
    local frac = current / maxHealth
    local m = state.ttk[key]
    if not m or m.name ~= name or frac > (m.lastY or 0) + 0.2 then
        m = Models.NewTrend(S().ttkHalfLifeSec or 30)
        m.name = name
        state.ttk[key] = m
    end
    m:Add(tSec, frac)
    m.maxHealth = maxHealth
    m.current = current
end

function Models.ObserveDPS(dps)
    state.dps:Update(dps)
end

function Models.ResetFightTransient()
    state.ttk = {}
    state.dps = Models.NewHolt(0.3, 0.1)
end

-- ===========================================================================
-- Queries
-- ===========================================================================
function Models.GetCritEstimate(abilityId)
    local out = {}
    local b = abilityId and state.critAbility[abilityId] or state.critOverall
    if b then
        out.critChance = b:Mean()
        out.critChanceStd = b:Std()
        out.samples = b:Count()
    end
    -- crit damage: weighted mean of per-ability crit / normal ratios
    local wsum, rsum = 0, 0
    local function addPair(p)
        if p.c.n >= 3 and p.n.n >= 3 and p.n.mean > 0 then
            local w = min(p.c.n, p.n.n)
            rsum = rsum + (p.c.mean / p.n.mean) * w
            wsum = wsum + w
        end
    end
    if abilityId then
        for _, p in pairs(state.critPairs[abilityId] or {}) do addPair(p) end
    else
        for _, byTarget in pairs(state.critPairs) do
            for _, p in pairs(byTarget) do addPair(p) end
        end
    end
    if wsum > 0 then
        out.critDamageMultiplier = rsum / wsum
        out.critDamagePct = (out.critDamageMultiplier - 1) * 100
        out.critDamageWeight = wsum
    end
    return out
end

-- Estimate for a target by name
function Models.GetTargetEstimate(targetName)
    local t = state.targets[targetName]
    if not t then return nil end
    local e = { name = targetName, samples = t.samples, relativeSamples = t.relSamples }
    if t.samples > 0 then
        e.predictedMitigation = t.mitigation.x
        e.predictedMitigationStd = t.mitigation:Std()
        e.predictedDRPct = (t.mitigation.x or 0) * 100
        e.predictedResistance = t.resist.x
        e.predictedResistanceStd = t.resist:Std()
        e.penetrationUsed = t.lastPen
        e.penetrationToCap = max(0, (t.resist.x or 0) - (t.lastPen or 0))
        local stats = LF.Stats.current
        if stats then
            local pen = max(stats.spellPenetration or 0, stats.physicalPenetration or 0)
            e.missingPenetration = max(0, (t.resist.x or 0) - pen)
        end
        e.overPenetratedPct = Util.SafeDiv(t.overPenSamples, t.samples)
        e.cappedPct = Util.SafeDiv(t.cappedSamples, t.samples)
        if t.overPenSamples / t.samples > 0.5 then
            e.status = "over-penetrated (resistance <= your penetration)"
        elseif t.cappedSamples / t.samples > 0.5 then
            e.status = "capped / extra damage reduction"
        else
            e.status = "ok"
        end
    end
    if t.relSamples > 0 then
        e.relativeDamageTaken = t.relative.x
        e.relativeToughnessPct = (1 - (t.relative.x or 1)) * 100
    end
    e.confidence = Clamp(t.samples / 100, 0, 1)
    return e
end

function Models.GetAllTargetEstimates()
    local list = {}
    for name in pairs(state.targets) do
        local e = Models.GetTargetEstimate(name)
        if e then list[#list + 1] = e end
    end
    table.sort(list, function(a, b) return (a.samples + a.relativeSamples) > (b.samples + b.relativeSamples) end)
    return list
end

function Models.GetIncomingDR()
    local armor = state.incomingArmor.x or 0
    local other = state.incomingOther.x or 0
    return {
        armorMitigationPct = armor * 100,
        otherDRPct = other * 100,
        totalDRPct = (1 - (1 - armor) * (1 - other)) * 100,
        samples = state.incomingOther.n,
        otherStdPct = (state.incomingOther:Std() or 0) * 100,
    }
end

-- Predicts the next hit of an incoming enemy ability against you right now
function Models.PredictIncomingHit(abilityId, damageType)
    local inc = state.incoming[abilityId]
    if not inc or inc.n < 1 then return nil end
    local mArmor = LF.Stats.GetArmorMitigation(damageType)
    return inc.w.mean * (1 - mArmor), inc.peak * (1 - mArmor)
end

-- Expected hit of one of your abilities on a target (non-crit, crit, average)
function Models.PredictHit(abilityId, targetName)
    local stats = LF.Stats.current or LF.Stats.GetSnapshot()
    local x = Features(stats)
    local base
    local rm, gm = state.refModels[abilityId], state.genModels[abilityId]
    local t = targetName and state.targets[targetName]
    if rm and rm.count >= MIN_REF_SAMPLES then
        base = rm:Predict(x) * 1000
        if t and t.samples > 0 then
            local refResist = S().referenceResistance or Const.DEFAULT_TARGET_RESISTANCE
            local pen = t.lastPen or 0
            local mRef = LF.Stats.ArmorMitigationFromResist(refResist, pen)
            base = base / (1 - mRef) * (1 - (t.mitigation.x or mRef))
        end
    elseif gm and gm.count >= 3 then
        base = gm:Predict(x) * 1000
        if t and t.relSamples > 0 then base = base * (t.relative.x or 1) end
    else
        return nil
    end
    local crit = Models.GetCritEstimate(abilityId)
    local overall = Models.GetCritEstimate()
    local mult = crit.critDamageMultiplier or overall.critDamageMultiplier or (1 + Const.BASE_CRIT_DAMAGE)
    local chance = (crit.samples or 0) >= 10 and crit.critChance or overall.critChance or 0.1
    return {
        nonCrit = base, crit = base * mult, average = base * (1 + chance * (mult - 1)),
        critChance = chance, critMultiplier = mult,
        rmse = ((rm and rm.count >= MIN_REF_SAMPLES) and rm or gm):GetRMSE() * 1000,
    }
end

-- seconds until unit reaches 0 health, current health fraction
function Models.GetTTK(key)
    local m = state.ttk[key or "boss1"]
    if not m then return nil end
    local slope, intercept = m:Fit()
    if not slope or slope >= 0 then return nil, m.lastY end
    local tZero = -intercept / slope
    return max(0, tZero - m.lastT), m.lastY
end

function Models.GetAllTTK()
    local out = {}
    for key, m in pairs(state.ttk) do
        local ttk, frac = Models.GetTTK(key)
        out[#out + 1] = { unitTag = key, name = m.name, secondsRemaining = ttk, healthFraction = frac }
    end
    table.sort(out, function(a, b) return tostring(a.unitTag) < tostring(b.unitTag) end)
    return out
end

function Models.GetDPSForecast(secondsAhead)
    return state.dps:Forecast(secondsAhead or 1)
end

-- Predicts final numbers of the running fight
function Models.PredictFightOutcome(fight)
    fight = fight or (LF.Logger and LF.Logger.GetCurrentFight())
    if not fight then return nil end
    local ttk = Models.GetTTK("boss1")
    local dur = fight:GetDurationSec()
    local dps = fight:GetDPS()
    local out = { currentDPS = dps, elapsedSec = dur, ttkSec = ttk }
    if ttk then
        out.predictedDurationSec = dur + ttk
        local f = Models.GetDPSForecast(1) or dps
        out.predictedTotalDamage = fight.totals.damageOut + f * ttk
        out.predictedFinalDPS = out.predictedTotalDamage / out.predictedDurationSec
    end
    return out
end

function Models.GetReport()
    local trained = 0
    for _, m in pairs(state.refModels) do if m.count >= MIN_REF_SAMPLES then trained = trained + 1 end end
    return {
        crit = Models.GetCritEstimate(),
        targets = Models.GetAllTargetEstimates(),
        incoming = Models.GetIncomingDR(),
        ttk = Models.GetAllTTK(),
        dpsForecast = Models.GetDPSForecast(5),
        referenceAbilitiesTrained = trained,
        referenceSamples = state.refSamples,
        trainedHits = state.trainedHits,
        abilitiesModeled = Util.Count(state.genModels),
    }
end

-- ===========================================================================
-- Persistence (optional, PC-friendly; disabled by default for console SV limits)
-- ===========================================================================
function Models.Save()
    if not LF.sv or not S().persistModels then return end
    LF.sv.models = {
        version = 1,
        refModels = Util.ToPlain(state.refModels),
        critPairs = Util.ToPlain(state.critPairs),
        critOverall = Util.ToPlain(state.critOverall),
        refSamples = state.refSamples,
    }
end

function Models.Load()
    local data = LF.sv and LF.sv.models
    if not data or data.version ~= 1 or not S().persistModels then return end
    for id, m in pairs(data.refModels or {}) do
        state.refModels[id] = setmetatable(m, RLS)
    end
    for id, byTarget in pairs(data.critPairs or {}) do
        local out = {}
        for tkey, p in pairs(byTarget) do
            if type(p) == "table" and p.c and p.n then
                out[tkey] = { c = setmetatable(p.c, Welford), n = setmetatable(p.n, Welford) }
            end
        end
        state.critPairs[id] = out
    end
    if data.critOverall then state.critOverall = setmetatable(data.critOverall, Beta) end
    state.refSamples = data.refSamples or 0
end
