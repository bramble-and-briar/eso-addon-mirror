-- =========================================================
-- MugShot - TargetController  (Core/TargetController.lua)
-- Orchestrates the full data → display pipeline:
--
--   ESO events
--     └→ TargetController
--          ├→ EsoAdapter      (read raw identity, vitals, shield, effects)
--          ├→ TargetState     (store raw data)
--          ├→ TargetPolicy    (should we display?)
--          ├→ Presentation    (transform to display tables)
--          ├→ TargetFrameView (render)
--          └→ NativeFrameBridge (hide/show native frame)
-- =========================================================

local MugShot = MugShot

local TargetController = {}
TargetController.__index = TargetController

-- Localized functions for Lua 5.1 bytecode speed (Code65536 / Baertram pattern)
local ipairs             = ipairs
local tostring           = tostring
local string_format      = string.format
local math_max           = math.max
local math_ceil          = math.ceil
local table_insert       = table.insert
local GetGameTimeSeconds = GetGameTimeSeconds

local RGBA                  = MugShot.Constants.RGBA
local ICONS                 = MugShot.Constants.ICONS
local COLOR_WHITE_ARRAY     = RGBA.WHITE_ARRAY
local COLOR_HOSTILE_DEFAULT = RGBA.REACTION_HOSTILE

local DEFAULT_CLASS_ICON = "/esoui/art/icons/class/class_dragonknight.dds"

-- Native ability icon resolver (queries engine via GetAbilityIcon or falls back to missing icon)
local function ResolveAbilityIcon(abilityId, fallback)
    if abilityId and abilityId > 0 and GetAbilityIcon then
        local icon = GetAbilityIcon(abilityId)
        if icon and icon ~= "" then
            return icon
        end
    end
    return fallback or ICONS.MISSING
end

local SAMPLE_EFFECT_DEFS = {
    { abilityId = 61744, defaultIcon = "/esoui/art/icons/icon_missing.dds", timerText = "3s", stackText = "x2", isGroup = true },
    { abilityId = 39077, defaultIcon = "/esoui/art/icons/icon_missing.dds", timerText = "15s", stackText = "" },
    { abilityId = 17906, defaultIcon = "/esoui/art/icons/icon_missing.dds", timerText = "2s", stackText = "" },
}

function TargetController:GetSampleEffects()
    local sample = {}
    for i, def in ipairs(SAMPLE_EFFECT_DEFS) do
        local icon = ResolveAbilityIcon(def.abilityId, def.defaultIcon)
        sample[i] = {
            abilityId = def.abilityId,
            icon      = icon,
            timerText = def.timerText,
            stackText = def.stackText,
            isGroup   = def.isGroup,
            borderR   = def.isGroup and 0.18 or 0,
            borderG   = def.isGroup and 0.78 or 0,
            borderB   = def.isGroup and 0.96 or 0,
            borderA   = 1,
        }
    end
    return sample
end

-- Backward compatibility alias
local SAMPLE_EFFECTS = TargetController:GetSampleEffects()

-- ── Role Debuff Builder Templates (Line 3 Privileged Debuffs) ─────────
local BUILDER_TEMPLATES = {
    tank = {
        name = "Tank (Raid)",
        debuffs = {
            { tag = "CRUSH",   name = "Crusher",       abilityId = 17906, isPair = false, timerText = "4s",  isActive = true, fromPlayer = true },
            { tag = "BREACH",  name = "Breach",        majorAbilityId = 61743, minorAbilityId = 61742, isPair = true,  majorName = "Major Breach", minorName = "Minor Breach", majorTimerText = "18s", minorTimerText = "22s", majorActive = true, minorActive = true, majorFromPlayer = true, minorFromPlayer = false },
            { tag = "BRIT",    name = "Brittle",       majorAbilityId = 145975, minorAbilityId = 145977, isPair = true,  majorName = "Major Brittle", minorName = "Minor Brittle", majorTimerText = "8s", minorTimerText = "0s", majorActive = true, minorActive = false, majorFromPlayer = false, minorFromPlayer = false },
            { tag = "LN-BRK",  name = "Line Breaker",  abilityId = 139708, isPair = false, timerText = "0s",  isActive = false, isGhost = true },
            { tag = "MAIM",    name = "Maim",          majorAbilityId = 61725, minorAbilityId = 61723, isPair = true,  majorName = "Major Maim", minorName = "Minor Maim", majorTimerText = "6s", minorTimerText = "0s", majorActive = true, minorActive = false, majorFromPlayer = false, minorFromPlayer = false },
            { tag = "WEAK",    name = "Weakening",     abilityId = 17945, isPair = false, timerText = "3s",  isActive = true, fromPlayer = true },
            { tag = "OFF-BAL", name = "Off Balance",   abilityId = 39077, isPair = false, timerText = "0s",  isActive = false, isGhost = true },
        }
    },
    healer = {
        name = "Healer (Raid)",
        debuffs = {
            { tag = "PRAYER",  name = "Combat Prayer",    abilityId = 61902, isPair = false, timerText = "10s", isActive = true, fromPlayer = true },
            { tag = "BRIT",    name = "Brittle",          majorAbilityId = 145975, minorAbilityId = 145977, isPair = true,  majorName = "Major Brittle", minorName = "Minor Brittle", majorTimerText = "0s", minorTimerText = "12s", majorActive = false, minorActive = true, majorFromPlayer = false, minorFromPlayer = true },
            { tag = "WEAK",    name = "Weakening",        abilityId = 17945, isPair = false, timerText = "5s",  isActive = true, fromPlayer = false },
            { tag = "SPC",     name = "Spell Power Cure", abilityId = 67342, isPair = false, timerText = "15s", isActive = true, fromPlayer = true },
            { tag = "MAIM",    name = "Maim",             majorAbilityId = 61725, minorAbilityId = 61723, isPair = true,  majorName = "Major Maim", minorName = "Minor Maim", majorTimerText = "0s", minorTimerText = "9s", majorActive = false, minorActive = true, majorFromPlayer = false, minorFromPlayer = true },
            { tag = "OFF-BAL", name = "Off Balance",     abilityId = 39077, isPair = false, timerText = "0s",  isActive = false, isGhost = true },
        }
    },
    dps = {
        name = "DPS Mag (Z'en / MK)",
        debuffs = {
            { tag = "Z'EN",    name = "Touch of Z'en",     abilityId = 126597, isPair = false, timerText = "14s", stackText = "5", isActive = true, fromPlayer = true },
            { tag = "MK",      name = "Martial Knowledge", abilityId = 127070, isPair = false, timerText = "5s",  stackText = "",  isActive = true, fromPlayer = true },
            { tag = "HEAT",    name = "Heat Shock",        abilityId = 0, icon = "/esoui/art/icons/icon_missing.dds", isPair = false, timerText = "8s",  stackText = "3",  isActive = true, fromPlayer = true },
            { tag = "VULN",    name = "Vulnerability",     majorAbilityId = 106754, minorAbilityId = 106757, isPair = true,  majorName = "Major Vulnerability", minorName = "Minor Vulnerability", majorTimerText = "7s", minorTimerText = "12s", majorActive = true, minorActive = true, majorFromPlayer = false, minorFromPlayer = false },
            { tag = "OFF-BAL", name = "Off Balance",       abilityId = 39077, isPair = false, timerText = "15s", stackText = "",  isActive = true, fromPlayer = true },
            { tag = "MORAG",   name = "The Morag Tong",    abilityId = 104743, isPair = false, timerText = "0s",  stackText = "",  isActive = false, isGhost = true },
        }
    },
}

-- ── Constructor ───────────────────────────────────────────
function TargetController.New(deps)
    local self = setmetatable({}, TargetController)
    self._state              = deps.state
    self._adapter            = deps.adapter
    self._eventBindings      = deps.eventBindings
    self._nativeBridge       = deps.nativeBridge
    self._view               = deps.view
    self._settings           = deps.settings
    self._inMoveMode         = false
    self._moveModeTarget     = "player"
    self._inDebugMode        = false
    self._isInTrial          = false
    self._currentTemplate    = "tank"
    self._effectsBuffer      = {} -- Reusable zero-GC presentation buffer
    self._effectsRawBuffer   = {} -- Reusable zero-GC raw effects buffer
    self._clearTargetTimerId = nil
    MugShot._controller      = self
    return self
end

-- ── Lifecycle ─────────────────────────────────────────────
function TargetController:Start()
    self._isInTrial = self._adapter:IsInTrial()
    self._nativeBridge:Start()
    self._nativeBridge:SetReplacementActive(true)
    self._eventBindings:Start(self)
    self:RefreshTarget()
    MugShot.logger:Info("TargetController: started")
end

function TargetController:Stop()
    if self._clearTargetTimerId then
        zo_removeCallLater(self._clearTargetTimerId)
        self._clearTargetTimerId = nil
    end
    self._eventBindings:Stop()
    self._view:SetVisible(false)
    self._nativeBridge:SetReplacementActive(false)
    self._nativeBridge:Stop()
    MugShot.logger:Info("TargetController: stopped")
end

function TargetController:ApplySettings(settings)
    self._view:ApplyLayout(settings)
end

function TargetController:GetGeneration()
    return self._state and self._state.generation or 0
end

function TargetController:IsInMoveMode()
    return self._inMoveMode == true
end

-- ── Private Helpers (DRY) ─────────────────────────────────

-- Checks whether a callback is from an older target generation
function TargetController:_IsStale(targetGeneration)
    if targetGeneration ~= nil and targetGeneration ~= self._state.generation then
        MugShot.logger:Debug("TargetController dropped stale update (gen=%s, current=%s)",
            tostring(targetGeneration), tostring(self._state.generation))
        return true
    end
    return false
end

-- Hides frame, resets view, and maintains native frame suppression
function TargetController:_ClearTarget(suppressNative)
    self._eventBindings:StopEffectTimer()
    self._view:SetVisible(false)
    self._view:Reset()
    if self._state then
        self._state.exists = false
    end
    if suppressNative ~= false then
        self._nativeBridge:SetReplacementActive(true)
    else
        self._nativeBridge:SetReplacementActive(false)
    end
end

-- Builds and applies vitals presentation table to the view
function TargetController:_UpdateVitalsView()
    local Presentation = MugShot.Presentation
    local vitalsPres = Presentation.BuildVitals(self._state, self._settings:Get())
    self._view:SetVitals(vitalsPres)
    return vitalsPres
end

-- Returns the active debuff list (from custom settings or role template)
function TargetController:_GetActiveDebuffList()
    local sv = self._settings and self._settings:Get()
    if sv and sv.customDebuffs and #sv.customDebuffs > 0 then
        for _, d in ipairs(sv.customDebuffs) do
            local id = d.abilityId or d.majorAbilityId or d.minorAbilityId
            if id and id > 0 then
                d.icon = ResolveAbilityIcon(id, d.icon)
            end
        end
        return sv.customDebuffs
    end
    local activeTemplate = self._currentTemplate or (sv and sv.builderTemplate) or "tank"
    local t = BUILDER_TEMPLATES[activeTemplate] or BUILDER_TEMPLATES.tank
    local list = {}
    for i, d in ipairs(t.debuffs) do
        local copy = {}
        for k, v in pairs(d) do copy[k] = v end
        local id = copy.abilityId or copy.majorAbilityId or copy.minorAbilityId
        if id and id > 0 then
            copy.icon = ResolveAbilityIcon(id, copy.icon)
        end
        list[i] = copy
    end
    return list
end

local ACCENT_MAP = {
    ["É"] = "e", ["È"] = "e", ["Ê"] = "e", ["Ë"] = "e",
    ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e",
    ["À"] = "a", ["Â"] = "a", ["Ä"] = "a",
    ["à"] = "a", ["â"] = "a", ["ä"] = "a",
    ["Î"] = "i", ["Ï"] = "i",
    ["î"] = "i", ["ï"] = "i",
    ["Ô"] = "o", ["Ö"] = "o",
    ["ô"] = "o", ["ö"] = "o",
    ["Ù"] = "u", ["Û"] = "u", ["Ü"] = "u",
    ["ù"] = "u", ["û"] = "u", ["ü"] = "u",
    ["Ç"] = "c", ["ç"] = "c",
    ["ß"] = "ss",
}

local NORMALIZE_CACHE = {}
local function NormalizeStr(s)
    if not s or s == "" then return "" end
    local cached = NORMALIZE_CACHE[s]
    if cached then return cached end
    local res = s
    for k, v in pairs(ACCENT_MAP) do
        res = res:gsub(k, v)
    end
    res = res:lower()
    NORMALIZE_CACHE[s] = res
    return res
end

-- Debuff Multilingual Keywords for robust language-agnostic detection
local DEBUFF_KEYWORDS = {
    ["Breach"]             = { "breach", "breche", "bruch", "fraktur" },
    ["Crusher"]            = { "crusher", "ecrasement", "zerschlagen" },
    ["Brittle"]            = { "brittle", "friabilite", "glaciale", "sprode" },
    ["Maim"]               = { "maim", "mutilation", "estropiement", "verstummeln" },
    ["Weakening"]          = { "weakening", "affaiblissement", "schwachung" },
    ["Off Balance"]        = { "off balance", "off-balance", "desequilibre", "aus dem gleichgewicht" },
    ["Vulnerability"]      = { "vulnerability", "vulnerabilite", "verwundbarkeit" },
    ["Line Breaker"]       = { "line breaker", "line-breaker", "brise-ligne", "brise ligne", "linienbrecher" },
    ["Touch of Z'en"]      = { "z'en", "zen" },
    ["Martial Knowledge"]  = { "martial knowledge", "savoir martial", "connaissance martiale", "kriegerische kenntnis" },
    ["Combat Prayer"]      = { "combat prayer", "priere de combat", "kampfgebet" },
    ["Spell Power Cure"]   = { "spell power cure", "puissance curative", "heilkraft" },
}

local function MatchesDebuffKeywords(name, debuffName)
    if not name or name == "" or not debuffName then return false end
    local norm = NormalizeStr(name)
    local kwList = DEBUFF_KEYWORDS[debuffName]
    if kwList then
        for _, kw in ipairs(kwList) do
            if norm:find(kw, 1, true) then
                return true
            end
        end
    end
    return norm:find(NormalizeStr(debuffName), 1, true) ~= nil
end

local function IsMajorEffect(eff)
    if eff.isMajor == true then return true end
    local n = NormalizeStr(eff.name or "")
    return n:find("major", 1, true) ~= nil or n:find("majeur", 1, true) ~= nil or n:find("grosere", 1, true) ~= nil
end

local function IsMinorEffect(eff)
    if eff.isMinor == true then return true end
    local n = NormalizeStr(eff.name or "")
    return n:find("minor", 1, true) ~= nil or n:find("mineur", 1, true) ~= nil or n:find("kleinere", 1, true) ~= nil
end

-- Builds and applies effects presentation table (filters out privileged debuffs from standard icon row)
function TargetController:_UpdateEffectsView()
    local Presentation = MugShot.Presentation
    local debuffList = self:_GetActiveDebuffList()

    local isEnemy = false
    if self._inMoveMode then
        isEnemy = (self._moveModeTarget == "enemy")
    else
        local id = self._state.identity
        if id then
            -- STRICT: only hostile reaction qualifies as enemy! (Target dummy/neutral is UNIT_REACTION_NEUTRAL)
            isEnemy = (id.reaction == UNIT_REACTION_HOSTILE)
        end
    end

    -- Reset previous privileged flags on raw effects
    for _, eff in ipairs(self._state.effects or {}) do
        eff._isPrivileged = false
    end

    local privilegedNames = nil
    local privilegedAbilityIds = nil
    if isEnemy and debuffList then
        privilegedNames = {}
        privilegedAbilityIds = {}
        for _, tDebuff in ipairs(debuffList) do
            if tDebuff.isPair then
                if tDebuff.majorAbilityId then privilegedAbilityIds[tDebuff.majorAbilityId] = true end
                if tDebuff.minorAbilityId then privilegedAbilityIds[tDebuff.minorAbilityId] = true end
                local majorLoc = (GetAbilityName and tDebuff.majorAbilityId and GetAbilityName(tDebuff.majorAbilityId))
                local minorLoc = (GetAbilityName and tDebuff.minorAbilityId and GetAbilityName(tDebuff.minorAbilityId))
                if majorLoc and majorLoc ~= "" then privilegedNames[majorLoc] = true end
                if minorLoc and minorLoc ~= "" then privilegedNames[minorLoc] = true end
                privilegedNames[tDebuff.majorName or ("Major " .. tDebuff.name)] = true
                privilegedNames[tDebuff.minorName or ("Minor " .. tDebuff.name)] = true
            else
                if tDebuff.abilityId then privilegedAbilityIds[tDebuff.abilityId] = true end
                local loc = (GetAbilityName and tDebuff.abilityId and GetAbilityName(tDebuff.abilityId))
                if loc and loc ~= "" then privilegedNames[loc] = true end
            end
            if tDebuff.name then privilegedNames[tDebuff.name] = true end
            if tDebuff.tag then privilegedNames[tDebuff.tag] = true end
        end

        -- Mark all matching effects on target as privileged so they never duplicate in the bottom row
        for _, eff in ipairs(self._state.effects or {}) do
            local effName = eff.name or ""
            for _, tDebuff in ipairs(debuffList) do
                if MatchesDebuffKeywords(effName, tDebuff.name)
                    or (tDebuff.majorAbilityId and eff.abilityId == tDebuff.majorAbilityId)
                    or (tDebuff.minorAbilityId and eff.abilityId == tDebuff.minorAbilityId)
                    or (tDebuff.abilityId and eff.abilityId == tDebuff.abilityId) then
                    eff._isPrivileged = true
                    if eff.name and eff.name ~= "" then privilegedNames[eff.name] = true end
                    if eff.abilityId and eff.abilityId > 0 then privilegedAbilityIds[eff.abilityId] = true end
                    break
                end
            end
        end
    end

    -- Process privileged debuffs for Line 3
    if self._view.SetPrivilegedDebuffs then
        local isClassic = (self._settings and self._settings:Get().layout == "classic")
        if self._inMoveMode then
            if isEnemy and not isClassic then
                local priv = (self._state.privilegedDebuffs and #self._state.privilegedDebuffs > 0) and self._state.privilegedDebuffs or debuffList
                self._view:SetPrivilegedDebuffs(priv)
            else
                self._view:SetPrivilegedDebuffs({})
            end
        else
            if not isEnemy or not self._state.exists or isClassic then
                -- Neutral, allied, or classic targets: NO privileged debuffs row
                self._view:SetPrivilegedDebuffs({})
            else
                -- Hostile / Boss / Reticle enemy / Target Dummy: populate Line 3 with active/ghost debuffs
                local privileged = {}
                for _, tDebuff in ipairs(debuffList) do
                    if tDebuff.isPair then
                        local majorName = tDebuff.majorName or ("Major " .. tDebuff.name)
                        local minorName = tDebuff.minorName or ("Minor " .. tDebuff.name)
                        local majorLoc  = (GetAbilityName and tDebuff.majorAbilityId and GetAbilityName(tDebuff.majorAbilityId))
                        local minorLoc  = (GetAbilityName and tDebuff.minorAbilityId and GetAbilityName(tDebuff.minorAbilityId))
                        local effMajor = nil
                        local effMinor = nil
                        local majorPlayerTimer = 0
                        local majorTeamTimer   = 0
                        local minorPlayerTimer = 0
                        local minorTeamTimer   = 0

                        for _, eff in ipairs(self._state.effects or {}) do
                            local effId = eff.abilityId
                            local effName = eff.name or ""
                            local matchesKw = MatchesDebuffKeywords(effName, tDebuff.name)

                            if (tDebuff.majorAbilityId and effId == tDebuff.majorAbilityId)
                                or effName == majorName
                                or (majorLoc and effName == majorLoc)
                                or (matchesKw and IsMajorEffect(eff)) then
                                effMajor = eff
                                eff._isPrivileged = true
                                local pT = eff.playerTimer or (eff.castByPlayer and eff.timer) or 0
                                local tT = eff.teamTimer or (not eff.castByPlayer and eff.timer) or 0
                                if pT > majorPlayerTimer then majorPlayerTimer = pT end
                                if tT > majorTeamTimer then majorTeamTimer = tT end
                            elseif (tDebuff.minorAbilityId and effId == tDebuff.minorAbilityId)
                                or effName == minorName
                                or (minorLoc and effName == minorLoc)
                                or (matchesKw and IsMinorEffect(eff)) then
                                effMinor = eff
                                eff._isPrivileged = true
                                local pT = eff.playerTimer or (eff.castByPlayer and eff.timer) or 0
                                local tT = eff.teamTimer or (not eff.castByPlayer and eff.timer) or 0
                                if pT > minorPlayerTimer then minorPlayerTimer = pT end
                                if tT > minorTeamTimer then minorTeamTimer = tT end
                            end
                        end

                        local majorTimerVal = math_max(majorPlayerTimer, majorTeamTimer)
                        if majorTimerVal == 0 and effMajor and effMajor.timer and effMajor.timer > 0 then
                            majorTimerVal = effMajor.timer
                            if effMajor.castByPlayer then majorPlayerTimer = majorTimerVal else majorTeamTimer = majorTimerVal end
                        end

                        local minorTimerVal = math_max(minorPlayerTimer, minorTeamTimer)
                        if minorTimerVal == 0 and effMinor and effMinor.timer and effMinor.timer > 0 then
                            minorTimerVal = effMinor.timer
                            if effMinor.castByPlayer then minorPlayerTimer = minorTimerVal else minorTeamTimer = minorTimerVal end
                        end

                        local majorActive = (majorTimerVal > 0)
                        local minorActive = (minorTimerVal > 0)
                        local majorFromPlayer = (majorPlayerTimer >= majorTeamTimer) and (majorPlayerTimer > 0)
                        local minorFromPlayer = (minorPlayerTimer >= minorTeamTimer) and (minorPlayerTimer > 0)

                        local majorTimerText = majorActive and string_format("%ds", math_ceil(majorTimerVal)) or "0s"
                        local minorTimerText = minorActive and string_format("%ds", math_ceil(minorTimerVal)) or "0s"

                        table_insert(privileged, {
                            tag             = tDebuff.tag,
                            name            = tDebuff.name,
                            isPair          = true,
                            majorTimerText  = majorTimerText,
                            minorTimerText  = minorTimerText,
                            majorActive     = majorActive,
                            minorActive     = minorActive,
                            majorFromPlayer = majorFromPlayer,
                            minorFromPlayer = minorFromPlayer,
                            isGhost         = not (majorActive or minorActive),
                            isGroup         = (effMajor and (effMajor.isGroup or (effMajor.sourceCount and effMajor.sourceCount > 1)))
                                           or (effMinor and (effMinor.isGroup or (effMinor.sourceCount and effMinor.sourceCount > 1))),
                        })
                    else
                        local locName = (GetAbilityName and tDebuff.abilityId and GetAbilityName(tDebuff.abilityId))
                        local matched = nil
                        local singlePlayerTimer = 0
                        local singleTeamTimer   = 0

                        for _, eff in ipairs(self._state.effects or {}) do
                            local effId = eff.abilityId
                            local effName = eff.name or ""
                            if (tDebuff.abilityId and effId == tDebuff.abilityId)
                                or effName == tDebuff.name
                                or (locName and effName == locName)
                                or MatchesDebuffKeywords(effName, tDebuff.name) then
                                matched = eff
                                eff._isPrivileged = true
                                local pT = eff.playerTimer or (eff.castByPlayer and eff.timer) or 0
                                local tT = eff.teamTimer or (not eff.castByPlayer and eff.timer) or 0
                                if pT > singlePlayerTimer then singlePlayerTimer = pT end
                                if tT > singleTeamTimer then singleTeamTimer = tT end
                            end
                        end

                        local singleTimerVal = math_max(singlePlayerTimer, singleTeamTimer)
                        if singleTimerVal == 0 and matched and matched.timer and matched.timer > 0 then
                            singleTimerVal = matched.timer
                            if matched.castByPlayer then singlePlayerTimer = singleTimerVal else singleTeamTimer = singleTimerVal end
                        end

                        local isActive = (singleTimerVal > 0) or (matched and matched.isActive)
                        if isActive and matched and matched.isActive and singleTimerVal == 0 then
                            singleTimerVal = matched.timer or 0
                        end

                        if isActive then
                            local fromPlayer = (singlePlayerTimer >= singleTeamTimer) and (singlePlayerTimer > 0)
                            if not fromPlayer and matched and matched.castByPlayer and not matched.castByTeam then
                                fromPlayer = true
                            end

                            local timerStr = ""
                            if singleTimerVal > 0 then
                                timerStr = string_format("%ds", math_ceil(singleTimerVal))
                            elseif matched and matched.timerText and matched.timerText ~= "" then
                                timerStr = matched.timerText
                            end

                            local stackStr = ""
                            if matched and matched.stackCount and matched.stackCount > 1 then
                                stackStr = tostring(matched.stackCount)
                            elseif matched and matched.stackText and matched.stackText ~= "" then
                                stackStr = matched.stackText
                            end

                            table_insert(privileged, {
                                tag        = tDebuff.tag,
                                name       = tDebuff.name,
                                isPair     = false,
                                isGhost    = false,
                                timerText  = (timerStr ~= "") and timerStr or "0s",
                                stackText  = stackStr,
                                isActive   = true,
                                fromPlayer = fromPlayer,
                                isGroup    = matched and (matched.isGroup or (matched.sourceCount and matched.sourceCount > 1)),
                            })
                        else
                            -- Inactive on target -> GHOST DEBUFF!
                            table_insert(privileged, {
                                tag        = tDebuff.tag,
                                name       = tDebuff.name,
                                isPair     = false,
                                isGhost    = true,
                                timerText  = "0s",
                                stackText  = "",
                                isActive   = false,
                                fromPlayer = false,
                            })
                        end
                    end
                end
                self._view:SetPrivilegedDebuffs(privileged)
            end
        end
    end

    -- Build effects presentation for the bottom row (automatically excludes eff._isPrivileged)
    local effPres
    if self._inMoveMode and isEnemy then
        effPres = self:GetSampleEffects()
    else
        effPres = Presentation.BuildEffects(self._state, self._settings:Get(), self._effectsBuffer, privilegedNames, privilegedAbilityIds)
        if self._inMoveMode and #effPres == 0 then
            effPres = self:GetSampleEffects()
        end
    end
    self._view:SetEffects(effPres)

    return effPres
end

-- Starts or stops the 250ms effect timer ticker depending on active timed buffs
function TargetController:_SyncEffectTimer(effects)
    local hasTimers = false
    for _, eff in ipairs(effects or self._state.effects or {}) do
        if eff.timer and eff.timer > 0 then
            hasTimers = true
            break
        end
    end
    if hasTimers then
        self._eventBindings:StartEffectTimer()
    elseif not self._inMoveMode then
        self._eventBindings:StopEffectTimer()
    end
end

-- ── Move & Debug Modes ────────────────────────────────────

function TargetController:SetMoveMode(active, targetType)
    if self._clearTargetTimerId then
        zo_removeCallLater(self._clearTargetTimerId)
        self._clearTargetTimerId = nil
    end
    self._inMoveMode = active
    self._moveModeTarget = targetType or self._moveModeTarget or "player"
    local state = self._state

    self._view:SetMoveMode(active, self._moveModeTarget)

    if active then
        self._eventBindings:StartMoveModeEvents()
        state:ResetForTargetChange()
        state.exists = true

        if self._moveModeTarget == "enemy" then
            self:RefreshMoveModeEnemy()
        else
            self:RefreshMoveModePlayer()
        end
        self._view:SetVisible(true)
    else
        self._eventBindings:StopMoveModeEvents()
        state.unitTag = "reticleover"
        self:RefreshTarget()
    end
end

function TargetController:ToggleMoveModeTarget()
    if not self._inMoveMode then return "enemy" end
    self._moveModeTarget = (self._moveModeTarget == "enemy") and "player" or "enemy"
    self:RefreshMoveModeTarget()
    return self._moveModeTarget
end

function TargetController:GetMoveModeTarget()
    return self._moveModeTarget or "enemy"
end

function TargetController:RefreshMoveModeTarget()
    if not self._inMoveMode then return end
    self._view:SetMoveMode(true, self._moveModeTarget)
    if self._moveModeTarget == "enemy" then
        self:RefreshMoveModeEnemy()
    else
        self:RefreshMoveModePlayer()
    end
end

function TargetController:RefreshMoveModeEnemy(customDebuffs)
    local state = self._state
    state.exists = true
    state.unitTag = "reticleover"

    local hostileColor = (MugShot.Style and MugShot.Style.REACTION_COLORS and MugShot.Style.REACTION_COLORS[UNIT_REACTION_HOSTILE]) or COLOR_HOSTILE_DEFAULT
    local enemyName = MugShot.GetText("MOCK_ENEMY_NAME") or "Target Iron Atronach, Trial"
    local idPres = {
        displayName     = enemyName,
        isPlayer        = false,
        reaction        = UNIT_REACTION_HOSTILE,
        attackable      = true,
        r               = hostileColor.r,
        g               = hostileColor.g,
        b               = hostileColor.b,
        portraitTexture = "/esoui/art/icons/achievement_u29_dun2_flavorc.dds",
        portraitCoords  = nil,
        portraitColor   = COLOR_WHITE_ARRAY,
        raceIcon        = nil,
        allianceIcon    = nil,
        allianceColor   = nil,
    }
    state.identity = {
        name            = enemyName,
        displayName     = enemyName,
        isPlayer        = false,
        reaction        = UNIT_REACTION_HOSTILE,
        attackable      = true,
        portraitTexture = "/esoui/art/icons/achievement_u29_dun2_flavorc.dds",
        portraitCoords  = nil,
        portraitColor   = COLOR_WHITE_ARRAY,
    }
    self._view:SetIdentity(idPres)

    if self._view.ApplyQuadrantLayout then
        local sv = self._settings and self._settings:Get()
        local isClassic = (sv and sv.layout == "classic")
        local qEnemy
        if isClassic then
            qEnemy = (sv and sv.quadrantsNeutral) or (MugShot.Defaults and MugShot.Defaults.quadrantsNeutral)
        else
            qEnemy = (sv and (sv.quadrantsEnemy or sv.quadrants)) or (MugShot.Defaults and MugShot.Defaults.quadrantsEnemy)
        end
        self._view:ApplyQuadrantLayout(qEnemy)
    end

    self._view:SetVitals({
        healthKnown   = true,
        percentText   = "70%",
        healthText    = "2.1M / 3.0M [250K]",
        healthPercent = 0.70,
        shieldPercent = 0.08,
        shield        = 250000,
    })

    local isClassic = (self._settings and self._settings:Get().layout == "classic")
    local debuffs
    if isClassic then
        debuffs = {}
    else
        debuffs = customDebuffs or (self._state.privilegedDebuffs and #self._state.privilegedDebuffs > 0 and self._state.privilegedDebuffs) or self:_GetActiveDebuffList()
    end
    self._state.privilegedDebuffs = debuffs
    if self._view.SetPrivilegedDebuffs then
        self._view:SetPrivilegedDebuffs(debuffs)
    end
    local sample = self:GetSampleEffects()
    self._state.effects = sample
    self._view:SetEffects(sample)
    self._view:SetVisible(true)
end

function TargetController:RefreshMoveModePlayer()
    local state = self._state
    state.exists  = true
    state.unitTag = "player"

    self:RefreshMoveModeIdentity()

    if self._view.ApplyQuadrantLayout then
        local sv = self._settings and self._settings:Get()
        local qNeutral = (sv and sv.quadrantsNeutral) or (MugShot.Defaults and MugShot.Defaults.quadrantsNeutral)
        self._view:ApplyQuadrantLayout(qNeutral)
    end

    state.vitals  = self._adapter:ReadVitals("player")
    state.effects = self._adapter:ReadEffects("player", nil, nil, self._effectsRawBuffer)

    local vitalsPres = self:_UpdateVitalsView()
    if not vitalsPres.healthKnown or not vitalsPres.healthText or vitalsPres.healthText == "" then
        self._view:SetVitals({
            healthKnown   = true,
            percentText   = "100%",
            healthText    = "100K / 100K",
            healthPercent = 1.0,
            shieldPercent = 0.0,
            shield        = 0,
        })
    end

    self:_UpdateEffectsView()
    if self._view.SetPrivilegedDebuffs then
        self._view:SetPrivilegedDebuffs({})
    end
    self._view:SetVisible(true)
    self:_SyncEffectTimer(state.effects)
end

function TargetController:RefreshMoveModeIdentity()
    if not self._inMoveMode then return end
    local state    = self._state
    local settings = self._settings:Get()
    local Presentation = MugShot.Presentation

    local id = self._adapter:ReadIdentity("player")
    local charName = (id.name and id.name ~= "" and id.name) or (GetUnitName and GetUnitName("player")) or ""
    local accName = (id.displayName and id.displayName ~= "" and id.displayName) or (GetDisplayName and GetDisplayName()) or ""
    if charName == "" and accName == "" then
        charName = MugShot.GetText("DRAG_ME_TITLE") or "[MugShot] Déplacez-moi !"
    end
    id.name = charName
    id.displayName = (accName ~= "" and accName) or charName

    state.identity = id
    local idPres = Presentation.BuildIdentity(state, settings)

    local isDummyOrMissing = not idPres.portraitTexture or idPres.portraitTexture == ""
        or (type(idPres.portraitTexture) == "string" and (idPres.portraitTexture:find("campaignbrowser_guestcampaign", 1, true) or idPres.portraitTexture:find("icon_missing", 1, true)))

    if isDummyOrMissing then
        idPres.portraitTexture = (id and id.classIcon and id.classIcon ~= "" and id.classIcon) or DEFAULT_CLASS_ICON
        idPres.portraitColor = (id and id.classColor) or COLOR_WHITE_ARRAY
    end

    if idPres.isPlayer then
        if not idPres.raceIcon or idPres.raceIcon == "" then
            idPres.raceIcon = ICONS.FALLBACK_RACE
        end
        if not idPres.allianceIcon or idPres.allianceIcon == "" then
            idPres.allianceIcon = ICONS.FALLBACK_ALLIANCE
        end
    else
        idPres.raceIcon = nil
        idPres.allianceIcon = nil
    end

    self._view:SetIdentity(idPres)
end

function TargetController:SwapPrivilegedDebuffs(s1, s2)
    local debuffs = self:_GetActiveDebuffList()
    if debuffs and debuffs[s1] and debuffs[s2] then
        local temp = debuffs[s1]
        debuffs[s1] = debuffs[s2]
        debuffs[s2] = temp
        if self._settings then
            self._settings:Set("customDebuffs", debuffs)
        end
        self._state.privilegedDebuffs = debuffs
        if self._inMoveMode and self._moveModeTarget == "enemy" then
            self:RefreshMoveModeEnemy(debuffs)
        else
            self:_UpdateEffectsView()
        end
    end
end

function TargetController:SetLayout(layoutName)
    if self._view and self._view.ApplyQuadrantLayout then
        self._view:ApplyQuadrantLayout()
    end
    if self._inMoveMode then
        if self._moveModeTarget == "enemy" then
            self:RefreshMoveModeEnemy()
        else
            self:RefreshMoveModePlayer()
        end
    else
        self:RefreshTarget()
    end
end

function TargetController:SetDebugMode(active)
    self._inDebugMode = active
    if active then
        self._view:SetIdentity({
            displayName     = "Target Skeleton, Humanoid",
            isPlayer        = false,
            reaction        = UNIT_REACTION_HOSTILE,
            attackable      = true,
            r               = 0.84,
            g               = 0.00,
            b               = 0.00,
            portraitTexture = "/esoui/art/icons/event_witchfest_sacking_skelet.dds",
            raceIcon        = nil,
            allianceIcon    = nil,
        })
        self._view:SetVitals({
            healthKnown   = true,
            percentText   = "70%",
            healthText    = "2.1M / 3.0M",
            healthPercent = 0.70,
            shieldPercent = 0.0,
            shield        = 0,
        })
        local sample = self:GetSampleEffects()
        self._state.effects = sample
        self._view:SetEffects(sample)
        local t = BUILDER_TEMPLATES.tank
        if self._view.SetPrivilegedDebuffs then
            self._view:SetPrivilegedDebuffs(t.debuffs)
        end
        self._view:SetVisible(true)
    else
        self:RefreshTarget()
    end
end

-- ── Target & Component Refreshes ──────────────────────────

function TargetController:RefreshTarget()
    if self._inMoveMode or self._inDebugMode then
        return
    end

    local unitTag = self._state.unitTag -- "reticleover"

    if not DoesUnitExist(unitTag) or AreUnitsEqual(unitTag, "player") then
        if self._state.exists and IsUnitInCombat("player") then
            if not self._clearTargetTimerId then
                local gen = self._state.generation
                self._clearTargetTimerId = zo_callLater(function()
                    self._clearTargetTimerId = nil
                    if (not DoesUnitExist(self._state.unitTag) or AreUnitsEqual(self._state.unitTag, "player")) and self._state.generation == gen then
                        self:_ClearTarget(true)
                    end
                end, 350)
            end
        else
            if self._clearTargetTimerId then
                zo_removeCallLater(self._clearTargetTimerId)
                self._clearTargetTimerId = nil
            end
            self:_ClearTarget(true)
        end
        MugShot.logger:Debug("RefreshTarget: no target")
        return
    end

    if self._clearTargetTimerId then
        zo_removeCallLater(self._clearTargetTimerId)
        self._clearTargetTimerId = nil
    end

    -- 1. Squash native frame as the very first instruction upon target acquisition
    self._nativeBridge:SetReplacementActive(true)

    local state    = self._state
    local settings = self._settings:Get()
    local Presentation = MugShot.Presentation
    local TargetPolicy = MugShot.TargetPolicy

    state:ResetForTargetChange()
    state.exists   = true
    state.identity = self._adapter:ReadIdentity(unitTag)
    state.vitals   = self._adapter:ReadVitals(unitTag)
    state.effects  = self._adapter:ReadEffects(unitTag, nil, settings and settings.trackGroupDebuffs, self._effectsRawBuffer)

    if not TargetPolicy.ShouldDisplay(state, settings, self._isInTrial) then
        self:_ClearTarget(true)
        return
    end

    if self._view.ApplyQuadrantLayout then
        local isEnemy = (state.identity and state.identity.reaction == UNIT_REACTION_HOSTILE)
        local isClassic = (settings and settings.layout == "classic")
        local targetQuadrants = (isEnemy and not isClassic) and (settings and (settings.quadrantsEnemy or settings.quadrants)) or (settings and settings.quadrantsNeutral)
        self._view:ApplyQuadrantLayout(targetQuadrants)
    end

    local idPres = Presentation.BuildIdentity(state, settings)
    self._view:SetIdentity(idPres)
    self:_UpdateVitalsView()
    self:_UpdateEffectsView()
    self._view:SetVisible(true)

    self:_SyncEffectTimer(state.effects)
    MugShot.logger:Debug("RefreshTarget: target=%s exists=true portrait=%s", state.identity.name or "?", tostring(idPres and idPres.portraitTexture or "nil"))
end

function TargetController:OnZoneChanged()
    self._isInTrial = self._adapter:IsInTrial()
    if not self._inMoveMode and not self._inDebugMode then
        self:RefreshTarget()
    end
end

function TargetController:OnTargetDeath()
    if self._inMoveMode or self._inDebugMode then return end
    if self._clearTargetTimerId then
        zo_removeCallLater(self._clearTargetTimerId)
        self._clearTargetTimerId = nil
    end
    self._state.vitals.isDead = true
    self:_ClearTarget()
end

function TargetController:RefreshVitals(cur, max, _effectiveMax, targetGeneration, unitTag)
    if self._inDebugMode or not self._state.exists or self:_IsStale(targetGeneration) then
        return
    end

    if self._inMoveMode and (self._moveModeTarget ~= "player" or unitTag ~= "player") then
        return
    end

    local state = self._state
    local isDead = (cur <= 0) or IsUnitDead(state.unitTag)
    if isDead and not self._inMoveMode then
        state.vitals.isDead = true
        self:_ClearTarget()
        return
    end

    state.vitals.isDead        = false
    state.vitals.healthKnown   = true
    state.vitals.currentHealth = cur
    state.vitals.maxHealth     = max
    state.vitals.shield        = self._adapter:ReadVitals(state.unitTag).shield or 0

    if not self._inMoveMode then
        self:RefreshIdentity(false, state.generation)
    end

    self:_UpdateVitalsView()
end

function TargetController:RefreshIdentity(force, targetGeneration, unitTag)
    if self._inMoveMode then
        if self._moveModeTarget == "player" and (not unitTag or unitTag == "player") then
            self:RefreshMoveModeIdentity()
        end
        return
    end
    if self._inDebugMode or not self._state.exists or self:_IsStale(targetGeneration) then
        return
    end

    local state = self._state
    local id = self._adapter:ReadIdentity(state.unitTag)
    if not id then return end

    local Presentation = MugShot.Presentation
    if force or not state.identity or id.reaction ~= state.identity.reaction or id.name ~= state.identity.name then
        local prevReaction = state.identity and state.identity.reaction
        state.identity = id
        local settings = self._settings:Get()
        local isEnemy = (id.reaction == UNIT_REACTION_HOSTILE)
        if prevReaction ~= id.reaction then
            if self._view.ApplyQuadrantLayout then
                local isClassic = (settings and settings.layout == "classic")
                local targetQuadrants = (isEnemy and not isClassic) and (settings and (settings.quadrantsEnemy or settings.quadrants)) or (settings and settings.quadrantsNeutral)
                self._view:ApplyQuadrantLayout(targetQuadrants)
            end
            self:_UpdateEffectsView()
        end
        local idPres = Presentation.BuildIdentity(state, settings)
        self._view:SetIdentity(idPres)
    end
end

function TargetController:RefreshShield(targetGeneration, unitTag)
    if self._inDebugMode or not self._state.exists or self:_IsStale(targetGeneration) then
        return
    end

    if self._inMoveMode and (self._moveModeTarget ~= "player" or unitTag ~= "player") then
        return
    end

    self._state.vitals.shield = self._adapter:ReadVitals(self._state.unitTag).shield or 0
    self:_UpdateVitalsView()
end

function TargetController:RefreshEffects(targetGeneration, unitTag)
    if self._inDebugMode or not self._state.exists or self:_IsStale(targetGeneration) then
        return
    end

    if self._inMoveMode and (self._moveModeTarget ~= "player" or unitTag ~= "player") then
        return
    end

    local settings = self._settings:Get()
    local effects = self._adapter:ReadEffects(self._state.unitTag, nil, settings and settings.trackGroupDebuffs, self._effectsRawBuffer)
    self._state.effects = effects

    self:_UpdateEffectsView()
    self:_SyncEffectTimer(effects)
end

function TargetController:UpdateEffectTimers(targetGeneration)
    if self._inDebugMode or not self._state.exists or #self._state.effects == 0 or self:_IsStale(targetGeneration) then
        return
    end

    if self._inMoveMode and self._moveModeTarget == "enemy" then
        return
    end

    local now = GetGameTimeSeconds() or 0
    local anyActive = false

    for _, eff in ipairs(self._state.effects) do
        if eff.playerTimeEnding and eff.playerTimeEnding > 0 then
            local pRem = eff.playerTimeEnding - now
            eff.playerTimer = (pRem > 0) and pRem or 0
        end
        if eff.teamTimeEnding and eff.teamTimeEnding > 0 then
            local tRem = eff.teamTimeEnding - now
            eff.teamTimer = (tRem > 0) and tRem or 0
        end
        if eff.timeEnding and eff.timeEnding > 0 then
            local rem = eff.timeEnding - now
            if rem > 0 then
                eff.timer = rem
                anyActive = true
            else
                eff.timer = 0
            end
        end
        local pT = eff.playerTimer or 0
        local tT = eff.teamTimer or 0
        eff.winnerFromPlayer = (pT >= tT) and (pT > 0)
    end

    self:_UpdateEffectsView()

    if not anyActive and not self._inMoveMode then
        self._eventBindings:StopEffectTimer()
    end
end

TargetController.BUILDER_TEMPLATES = BUILDER_TEMPLATES
MugShot.TargetController = TargetController
MugShot.logger:Info("=== TargetController loaded ===")
