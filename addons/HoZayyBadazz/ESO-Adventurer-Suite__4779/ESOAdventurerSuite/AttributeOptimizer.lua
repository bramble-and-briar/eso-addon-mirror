-- ESO Adventurer Suite
-- Current-build attribute optimizer
local EPC = ESOProgressionCoach
EPC.AttributeOptimizer = EPC.AttributeOptimizer or {}
local A = EPC.AttributeOptimizer

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok,a,b,c,d,e = pcall(fn, ...)
    if not ok then return fallback end
    return a,b,c,d,e
end

local function num(fn, fallback, ...)
    local v = safe(fn, fallback, ...)
    v = tonumber(v)
    if v == nil then return tonumber(fallback) or 0 end
    return v
end

function A:Notify(message)
    message=tostring(message or "")
    if message=="" then return end
    if EPC and EPC.Print then EPC:Print(message) end
    if type(ZO_Alert)=="function" then pcall(ZO_Alert, UI_ALERT_CATEGORY_ALERT or 1, nil, message) end
end

function A:GetContext()
    local context = EPC.GearOptimizer and EPC.GearOptimizer.GetWornBuildContext and EPC.GearOptimizer:GetWornBuildContext() or {}
    local profile = context.profile or (EPC.GearOptimizer and EPC.GearOptimizer.GetProfile and EPC.GearOptimizer:GetProfile()) or {}
    local role = string.upper(tostring(context.role or "DAMAGE"))
    if role=="DPS" then role="DAMAGE" end
    local magicka = profile.magicka ~= false
    return {role=role, magicka=magicka, profile=profile, context=context}
end

function A:GetCurrent()
    local h=num(GetAttributeSpentPoints,0,ATTRIBUTE_HEALTH or 1)
    local m=num(GetAttributeSpentPoints,0,ATTRIBUTE_MAGICKA or 2)
    local s=num(GetAttributeSpentPoints,0,ATTRIBUTE_STAMINA or 3)
    local u=num(GetAttributeUnspentPoints,0)
    return {health=h,magicka=m,stamina=s,unspent=u,total=h+m+s+u}
end

local function split(total, healthPct, magPct, stamPct)
    total=math.max(0,math.floor(tonumber(total) or 0))
    local h=math.floor(total*healthPct+0.5)
    local m=math.floor(total*magPct+0.5)
    local s=math.max(0,total-h-m)
    if stamPct==0 and magPct>0 then m=m+s s=0 end
    if magPct==0 and stamPct>0 then s=s+m m=0 end
    return h,m,s
end

-- BuildPlan/BuildView are defined once below by the MAX POWER content-aware policy.

function A:ApplyBestAttributes()
    if type(IsUnitInCombat)=="function" and safe(IsUnitInCombat,false,"player") then
        self:Notify("ATTRIBUTES: leave combat before redistributing attributes.")
        return false
    end

    if EPC and EPC.RefreshNow then EPC:RefreshNow("pre-attribute-redistribute") end
    local p=self:BuildPlan()
    if p.current.total<=0 then
        self:Notify("ATTRIBUTES: there are no attribute points available to redistribute yet.")
        return false
    end
    if p.delta.health==0 and p.delta.magicka==0 and p.delta.stamina==0 then
        self:Notify("ATTRIBUTES: your points already match the recommended split.")
        return true
    end

    if EPC and EPC.Journal and EPC.Journal.window and not EPC.Journal.window:IsHidden() and type(EPC.Journal.Hide)=="function" then
        EPC.Journal:Hide()
    end
    if SCENE_MANAGER and type(SCENE_MANAGER.Show)=="function" then
        pcall(function() SCENE_MANAGER:Show("stats") end)
    end

    self:Notify(string.format("ATTRIBUTES: opening Character and preparing %d Health / %d Magicka / %d Stamina...", p.target.health, p.target.magicka, p.target.stamina))

    local function tryApply()
        -- Newer ESO clients may expose a free/shrine-free respec starter. Use it
        -- when available, then submit the target allocation through the protected
        -- allocation request. Everything is guarded; unsupported clients stop
        -- cleanly rather than sending a guessed or partial allocation.
        if type(StartAttributeRespecFromUI)=="function" then
            local okStart=pcall(function()
                if type(CallSecureProtected)=="function" then CallSecureProtected("StartAttributeRespecFromUI") else StartAttributeRespecFromUI() end
            end)
            if not okStart then
                self:Notify("ATTRIBUTES: ESO would not start attribute respec mode from here.")
                return false
            end
        end

        if type(SendAttributePointAllocationRequest)=="function" then
            local okSend, result=pcall(function()
                if type(CallSecureProtected)=="function" then
                    return CallSecureProtected("SendAttributePointAllocationRequest", p.target.health, p.target.magicka, p.target.stamina)
                end
                return SendAttributePointAllocationRequest(p.target.health, p.target.magicka, p.target.stamina)
            end)
            if okSend and result~=false then
                self:Notify(string.format("ATTRIBUTES: best-build allocation submitted: %d Health / %d Magicka / %d Stamina.", p.target.health, p.target.magicka, p.target.stamina))
                if EPC and EPC.RequestRefresh then EPC:RequestRefresh("attribute-respec") end
                return true
            end
            self:Notify("ATTRIBUTES: ESO did not accept the automatic allocation request. The Character Attributes screen is open with the recommended target shown; no partial allocation was submitted.")
            return false
        end

        self:Notify(string.format("ATTRIBUTES TARGET: %d Health / %d Magicka / %d Stamina. This ESO client does not expose an automatic allocation request, so the Character Attributes screen is open and no unsafe partial change was attempted.", p.target.health, p.target.magicka, p.target.stamina))
        return false
    end

    if type(zo_callLater)=="function" then
        zo_callLater(tryApply,250)
        return true
    end
    return tryApply()
end
-- v0.29.174 - MAX POWER attributes. Content-aware survival is kept only where
-- losing all damage to deaths/blocks would be worse; organized PvE DPS remains
-- fully stacked into its dominant offensive resource.
function A:BuildPlan()
    local current=self:GetCurrent()
    local c=self:GetContext()
    local total=current.total
    local g=EPC.GearOptimizer
    local gc=g and type(g.GetWornBuildContext)=="function" and g:GetWornBuildContext() or {}
    local mode=gc.maxPowerMode or (g and g.ResolveMaxPowerMode029174 and g:ResolveMaxPowerMode029174()) or "SOLO"
    local power=gc.power or {}
    local role=string.upper(tostring(c.role or "DAMAGE"))
    local magicka=c.magicka==true
    if power.hybrid then
        magicka=(tonumber(power.maxMagicka) or 0)>=(tonumber(power.maxStamina) or 0)
    end
    local h,m,s=0,0,0
    local reason="Maximum offensive resource"

    if role=="TANK" then
        local hpPct=0.60
        if mode=="TRIAL_BOSS" then hpPct=0.66
        elseif mode=="INFINITE_ARCHIVE" then hpPct=0.64
        elseif mode=="PVP" then hpPct=0.62
        elseif mode=="SOLO" then hpPct=0.58 end
        h=math.floor(total*hpPct+0.5)
        -- Stamina remains slightly higher than Magicka so common tank resource
        -- return mechanics restore the blocking pool. Keep some Magicka for class
        -- utility instead of the old fixed Health/Stamina-only split.
        local rem=math.max(0,total-h)
        s=math.ceil(rem*0.58)
        m=math.max(0,rem-s)
        reason="Tank effective-health + block/sustain balance"
    elseif role=="HEALER" then
        local healthPct=(mode=="PVP" and 0.16) or (mode=="INFINITE_ARCHIVE" and 0.10) or 0
        h=math.floor(total*healthPct+0.5)
        if magicka then m=total-h else s=total-h end
        reason=healthPct>0 and "Healing power with content survival floor" or "Maximum healing resource"
    else
        local healthPct=0
        if mode=="INFINITE_ARCHIVE" then healthPct=0.16
        elseif mode=="PVP" then healthPct=0.22
        elseif mode=="SOLO" then healthPct=0.08 end
        h=math.floor(total*healthPct+0.5)
        if magicka then m=total-h else s=total-h end
        reason=healthPct>0 and "Maximum damage after content survival reserve" or "Maximum damage resource"
    end

    return {
        context=c,current=current,mode=mode,modeLabel=gc.maxPowerLabel or mode,reason=reason,
        target={health=h,magicka=m,stamina=s,total=total},
        delta={health=h-current.health,magicka=m-current.magicka,stamina=s-current.stamina},
        cost=num(GetAttributeRespecGoldCost,0),
    }
end

function A:BuildView()
    local p=self:BuildPlan()
    return {
        cost=p.cost,role=p.context.role,
        build=p.context.profile and p.context.profile.label or (p.context.magicka and "Magicka" or "Stamina"),
        current=p.current,target=p.target,mode=p.modeLabel,reason=p.reason,
        changed=(p.delta.health~=0 or p.delta.magicka~=0 or p.delta.stamina~=0),
    }
end
