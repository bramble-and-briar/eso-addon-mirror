-- Optional WW room/boss detection. Manual hotkeys remain independent.
WWDpadAuto = {}
local A = WWDpadAuto
local config, submit
local generation = 0
local lastAccepted
local manualOverride = false

local function Enabled()
    return config and config.enabled and config.autoBossEnabled
end

local function LiveName(tag)
    if not DoesUnitExist(tag) or IsUnitDead(tag) then return end
    local name = GetUnitName(tag)
    if type(name) == "string" and name ~= "" then return name end
end

function A.Check()
    if not Enabled() then return end
    if IsUnitInCombat("player") or IsUnitDeadOrReincarnating("player") then return end
    local ww = WizardsWardrobe
    if not ww or not ww.selection or not ww.selection.zone then return end
    local plan, observed
    -- User-requested WW-style pre-boss recognition. Selected trial resolvers
    -- return nil outside their own instance; do not run their auto-equip path.
    local zone = ww.selection.zone
    if type(zone.GetBossByLocation) == "function" then
        local name = zone.GetBossByLocation()
        local trash = zone.bosses and zone.bosses[1] and zone.bosses[1].name
        if type(name) == "string" and name ~= "" and name ~= trash then
            observed = name
            if config.autoBossMode == "target" then plan = WWDpadRouting.Plan(true, true)
            else plan = WWDpadRouting.PlanForBoss(name) end
        end
    end
    -- Six documented boss unit tags, independent of MAX_BOSSES on console.
    for i = 1, 6 do
        if plan then break end
        local name = LiveName("boss" .. i)
        if name then
            observed = observed or name
            if config.autoBossMode == "target" then
                plan = WWDpadRouting.Plan(true, true)
            else
                plan = WWDpadRouting.PlanForBoss(name)
            end
            if plan then observed = name; break end
        end
    end
    -- An exactly named/mapped hostile target can identify a miniboss even
    -- without a boss bar. A generic target must not trigger the fixed setup.
    if not plan and config.autoBossMode ~= "target" and IsUnitAttackable("reticleover") then
        local name = LiveName("reticleover")
        if name then plan = WWDpadRouting.PlanForBoss(name); if plan then observed = name end end
    end
    if not observed then lastAccepted = nil; manualOverride = false end
    if not plan then return end
    local key = plan.context .. ":" .. tostring(plan.index)
    if config.autoBossMode == "target" then key = key .. ":" .. observed end
    if manualOverride then lastAccepted = key; manualOverride = false; return end
    if key == lastAccepted then return end
    if submit(plan) then lastAccepted = key end
end

function A.ManualOverride()
    if Enabled() then manualOverride = true end
end

function A.Schedule()
    generation = generation + 1
    local token = generation
    if not Enabled() then lastAccepted = nil; manualOverride = false; return end
    zo_callLater(function()
        if token ~= generation or not Enabled() then return end
        local ok = pcall(A.Check)
        if not ok then
            -- Detection failure must not break the manual shortcuts.
            config.autoBossEnabled = false
            d("[WW D-Pad] Bosserkennung wegen eines Fehlers ausgeschaltet. Manuelle Hotkeys bleiben verfuegbar.")
        end
    end, 100)
end

function A.Initialize(settings, request)
    config, submit = settings, request
    if EVENT_BOSSES_CHANGED then EVENT_MANAGER:RegisterForEvent("WWDpadAutoBoss", EVENT_BOSSES_CHANGED, A.Schedule) end
    if EVENT_RETICLE_TARGET_CHANGED then EVENT_MANAGER:RegisterForEvent("WWDpadAutoTarget", EVENT_RETICLE_TARGET_CHANGED, A.Schedule) end
    -- WW also polls room boundaries. A modest interval permits pre-boss
    -- detection while event bursts are coalesced separately by Schedule.
    EVENT_MANAGER:RegisterForUpdate("WWDpadAutoRooms", 1000, A.Schedule)
end
