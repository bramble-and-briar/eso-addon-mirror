-- ESO Adventurer Suite
-- Combat Rotation Assistant
-- Safe UI-only combat guidance: it never casts abilities or sends input.

local EPC = ESOProgressionCoach
EPC.RotationAssistant = EPC.RotationAssistant or {}
local R = EPC.RotationAssistant
local WM = WINDOW_MANAGER

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a,b,c,d,e = pcall(fn, ...)
    if not ok then return fallback end
    if a == nil then return fallback end
    return a,b,c,d,e
end

local function now()
    return tonumber(safe(GetFrameTimeMilliseconds, 0)) or 0
end

local function lower(s) return string.lower(tostring(s or "")) end
local function contains(s, needle) return lower(s):find(lower(needle), 1, true) ~= nil end

function R:GetSlots()
    local firstBase = tonumber(ACTION_BAR_FIRST_NORMAL_SLOT_INDEX)
    local ultBase = tonumber(ACTION_BAR_ULTIMATE_SLOT_INDEX)
    local first = firstBase and (firstBase + 1) or 3
    local ult = ultBase and (ultBase + 1) or (first + 5)
    local slots = {}
    for i=0,4 do slots[#slots+1] = first+i end
    slots[#slots+1] = ult
    return slots
end

function R:GetCategory()
    return safe(GetActiveHotbarCategory, nil)
end

function R:GetBarAbilities()
    local cat = self:GetCategory()
    local out = {}
    for ordinal, slot in ipairs(self.slots) do
        local used = safe(IsSlotUsed, false, slot, cat) == true
        local name = safe(GetSlotName, "", slot, cat)
        local icon = safe(GetSlotTexture, "", slot, cat)
        local remain,duration,isGlobal = safe(GetSlotCooldownInfo, 0, slot, cat)
        local effect = safe(GetActionSlotEffectTimeRemaining, 0, slot, cat)
        out[#out+1] = {
            slot=slot, ordinal=ordinal, name=tostring(name or ""), icon=icon,
            used=used, remain=tonumber(remain) or 0, duration=tonumber(duration) or 0,
            global=isGlobal == true, effect=tonumber(effect) or 0,
            usable=safe(IsSlotUsable, true, slot, cat) ~= false,
        }
    end
    return out
end

function R:HasCrystalProc()
    if type(GetNumBuffs) ~= "function" or type(GetUnitBuffInfo) ~= "function" then return false end
    local count = tonumber(safe(GetNumBuffs, 0, "player")) or 0
    for i=1,count do
        local name = safe(GetUnitBuffInfo, "", "player", i)
        if contains(name, "crystal fragments") or contains(name, "crystal shard") then
            return true
        end
    end
    return false
end

function R:GetTargetHealth()
    if not safe(DoesUnitExist, false, "reticleover") then return 0 end
    local cur,max = safe(GetUnitPower, 0, "reticleover", POWERTYPE_HEALTH)
    cur,max = tonumber(cur) or 0, tonumber(max) or 0
    if max <= 0 then return 100 end
    return math.max(0, math.min(100, cur/max*100))
end

function R:IsSorc()
    local classId = tonumber(safe(GetUnitClassId, 0, "player")) or 0
    return classId == 2
end

function R:ScoreAbility(a, targetHP, proc)
    if not a.used or a.name == "" then return -1000, "Unavailable" end
    if not a.usable then return -500, "Not ready" end
    if a.remain > 0 and a.duration > 0 and not a.global then return -400, "Cooldown" end

    local n = lower(a.name)
    local score, reason = 10, "Use next"

    -- Proc is the highest-priority event.
    if proc and (contains(n,"crystal fragments") or contains(n,"crystal shard")) then
        return 1000, "PROC READY"
    end

    -- Sorcerer PvE priority. Timed effects get refreshed before the spammable.
    if self:IsSorc() then
        if contains(n,"daedric prey") or contains(n,"haunting curse") or contains(n,"daedric curse") then
            if a.effect <= 500 then return 900, "Debuff expired" end
            return 50, "Debuff active"
        end
        if contains(n,"unstable wall") or contains(n,"elemental blockade") or contains(n,"wall of elements") then
            if a.effect <= 500 then return 880, "Wall expired" end
            return 45, "Wall active"
        end
        if contains(n,"liquid lightning") or contains(n,"lightning flood") or contains(n,"lightning splash") then
            if a.effect <= 500 then return 870, "Ground DoT expired" end
            return 40, "Ground DoT active"
        end
        if contains(n,"hurricane") or contains(n,"boundless storm") or contains(n,"lightning form") then
            if a.effect <= 500 then return 850, "Buff expired" end
            return 35, "Buff active"
        end
        if contains(n,"critical surge") or contains(n,"power surge") then
            if a.effect <= 500 then return 840, "Buff expired" end
            return 30, "Buff active"
        end
        if contains(n,"volta") or contains(n,"twilight") or contains(n,"familiar") then
            if a.effect <= 500 then return 760, "Pet/buff needs attention" end
            return 25, "Pet active"
        end
        if contains(n,"storm atronach") or contains(n,"power overload") or contains(n,"overload") then
            local ultCurrent = tonumber((safe(GetUnitPower,0,"player",COMBAT_MECHANIC_FLAGS_ULTIMATE))) or 0
            -- GetSlotAbilityCost takes the action-bar slot and returns the
            -- actual cost of the slotted Ultimate. Do not use an arbitrary
            -- 2000/500 cap here: each Ultimate has its own cost.
            local ultCost = tonumber(safe(GetSlotAbilityCost,0,a.slot)) or 0
            if ultCost > 0 and ultCurrent >= ultCost and targetHP > 0 then
                return 820, string.format("Ultimate ready (%d%%)", math.max(0, math.min(500, math.floor(ultCurrent + 0.5))))
            end
            return 5, "Build ultimate"
        end
        if contains(n,"force pulse") or contains(n,"crushing shock") or contains(n,"force shock") then
            return 500, "Spammable"
        end
        if contains(n,"mage's wrath") or contains(n,"mages wrath") then
            if targetHP > 0 and targetHP <= 20 then return 780, "Execute" end
            return 20, "Execute"
        end
    end

    -- Generic fallback: prefer expiring effects, then usable abilities.
    if a.effect > 0 then score = score + math.min(300, a.effect/10) else score = score + 100 end
    return score, reason
end

local BuildRecommendationsImplArch

function R:BuildRecommendations(...)

    return BuildRecommendationsImplArch(self, ...)

end

BuildRecommendationsImplArch = function(self)
    local abilities = self:GetBarAbilities()
    local hp = self:GetTargetHealth()
    local proc = self:HasCrystalProc()
    local scored = {}
    for _,a in ipairs(abilities) do
        local score,reason = self:ScoreAbility(a,hp,proc)
        scored[#scored+1] = {a=a,score=score,reason=reason}
    end
    table.sort(scored,function(x,y) return x.score > y.score end)
    local result={}
    for i=1,math.min(3,#scored) do
        if scored[i].score > 0 then result[#result+1]=scored[i] end
    end
    return result, hp, proc
end

local CreateUIImplArch

function R:CreateUI(...)

    return CreateUIImplArch(self, ...)

end

CreateUIImplArch = function(self)
    if self.window then return end

    local s = EPC.saved or {}
    local baseW, baseH = 330, 112
    local w = tonumber(s.rotationAssistantWidth) or baseW
    local h = tonumber(s.rotationAssistantHeight) or baseH
    w = math.max(260, math.min(700, w))
    h = math.max(90, math.min(260, h))

    local window = WM:CreateTopLevelWindow("EAS_RotationAssistant")
    window:SetDimensions(w, h)
    if window.SetDimensionConstraints then
        window:SetDimensionConstraints(260, 90, 700, 260)
    end
    if window.SetResizeHandleSize then window:SetResizeHandleSize(20) end
    window:SetClampedToScreen(true)
    window:SetMouseEnabled(false)
    window:SetMovable(false)
    window:SetHidden(true)

    -- Match the other ESO Adventurer Suite HUD overlays:
    -- the common HUD layout button unlocks the frame for dragging/resizing.
    window:SetHandler("OnMoveStop", function(control)
        if EPC.saved then
            EPC.saved.rotationAssistantLeft = control:GetLeft()
            EPC.saved.rotationAssistantTop = control:GetTop()
        end
    end)

    window:SetHandler("OnResizeStart", function(control)
        self.resizing = true
        control:SetHandler("OnUpdate", function()
            self:UpdateScale()
        end)
    end)

    window:SetHandler("OnResizeStop", function(control)
        self.resizing = false
        control:SetHandler("OnUpdate", nil)
        local cw, ch = control:GetDimensions()
        cw = math.floor(math.max(260, math.min(700, tonumber(cw) or baseW)) + 0.5)
        ch = math.floor(math.max(90, math.min(260, tonumber(ch) or baseH)) + 0.5)
        control:SetDimensions(cw, ch)
        if EPC.saved then
            EPC.saved.rotationAssistantWidth = cw
            EPC.saved.rotationAssistantHeight = ch
        end
        self:UpdateScale()
    end)

    local canvas = WM:CreateControl("EAS_RotationAssistantCanvas", window, CT_CONTROL)
    canvas:SetDimensions(baseW, baseH)
    canvas:SetAnchor(CENTER, window, CENTER, 0, 0)
    self.canvas = canvas

    local bg=WM:CreateControl(nil,canvas,CT_BACKDROP)
    bg:SetAnchorFill(canvas)
    bg:SetCenterColor(0.015,0.018,0.028,0.94)
    bg:SetEdgeColor(0.95,0.68,0.20,0.9)
    bg:SetEdgeTexture(nil,1,1,1)

    local title=WM:CreateControl(nil,canvas,CT_LABEL)
    title:SetAnchor(TOPLEFT,canvas,TOPLEFT,10,6)
    title:SetDimensions(300,20)
    title:SetFont("$(BOLD_FONT)|16|soft-shadow-thick")
    title:SetColor(1,0.78,0.25,1)
    title:SetText("⚡ SMART COMBAT ADVISOR")

    local icon=WM:CreateControl(nil,canvas,CT_TEXTURE)
    icon:SetAnchor(TOPLEFT,canvas,TOPLEFT,10,30)
    icon:SetDimensions(58,58)

    local nextLabel=WM:CreateControl(nil,canvas,CT_LABEL)
    nextLabel:SetAnchor(TOPLEFT,canvas,TOPLEFT,78,31)
    nextLabel:SetDimensions(240,25)
    nextLabel:SetFont("$(BOLD_FONT)|21|soft-shadow-thick")
    nextLabel:SetColor(1,1,1,1)

    local reason=WM:CreateControl(nil,canvas,CT_LABEL)
    reason:SetAnchor(TOPLEFT,canvas,TOPLEFT,78,58)
    reason:SetDimensions(240,20)
    reason:SetFont("ZoFontGameSmall")
    reason:SetColor(0.95,0.80,0.35,1)

    local queue=WM:CreateControl(nil,canvas,CT_LABEL)
    queue:SetAnchor(TOPLEFT,canvas,TOPLEFT,78,79)
    queue:SetDimensions(240,20)
    queue:SetFont("ZoFontGameSmall")
    queue:SetColor(0.72,0.78,0.86,1)

    local hp=WM:CreateControl(nil,canvas,CT_LABEL)
    hp:SetAnchor(TOPRIGHT,canvas,TOPRIGHT,-8,7)
    hp:SetDimensions(70,18)
    hp:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    hp:SetFont("ZoFontGameSmall")
    hp:SetColor(0.80,0.90,1,1)

    self.window=window
    self.icon=icon
    self.nextLabel=nextLabel
    self.reason=reason
    self.queue=queue
    self.hp=hp

    local left=tonumber(EPC.saved.rotationAssistantLeft) or -1
    local top=tonumber(EPC.saved.rotationAssistantTop) or -1
    if left>=0 and top>=0 then
        window:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,left,top)
    else
        window:SetAnchor(TOPRIGHT,GuiRoot,TOPRIGHT,-35,240)
    end

    self:UpdateScale()
end

function R:UpdateScale()
    if not self.window or not self.canvas then return end
    local w,h = self.window:GetDimensions()
    local baseW,baseH = 330,112
    local scale = math.min((tonumber(w) or baseW)/baseW, (tonumber(h) or baseH)/baseH)
    scale = math.max(0.78, math.min(2.12, scale))
    self.canvas:SetScale(scale)
end

local RefreshImplArch

function R:Refresh(...)

    return RefreshImplArch(self, ...)

end

RefreshImplArch = function(self)
    self:CreateUI()
    local enabled=EPC.saved and EPC.saved.rotationAssistantEnabled ~= false
    local combat=safe(IsUnitInCombat,false,"player")
    -- Only show while in combat, except while HUD layout mode is being used.
    local show=(enabled and combat) or self.layoutMode == true
    self.window:SetHidden(not show)
    if not show then return end

    local recs,hp,proc=self:BuildRecommendations()
    self.hp:SetText(hp > 0 and string.format("Target %.0f%%",hp) or "No target")
    if #recs==0 then
        self.icon:SetTexture("")
        self.nextLabel:SetText("NO ACTION")
        self.reason:SetText("Check your action bar")
        self.queue:SetText("")
        return
    end
    local first=recs[1]
    self.icon:SetTexture(first.a.icon or "")
    self.nextLabel:SetText(first.a.name)
    self.reason:SetText(first.reason)
    local q={}
    for i=2,#recs do q[#q+1]=recs[i].a.name end
    self.queue:SetText(#q>0 and ("Next: "..table.concat(q,"  →  ")) or "")
end

local SetLayoutModeImplArch

function R:SetLayoutMode(...)

    return SetLayoutModeImplArch(self, ...)

end

SetLayoutModeImplArch = function(self, active)
    self.layoutMode = active == true
    if not self.window then self:CreateUI() end
    self.window:SetMouseEnabled(self.layoutMode)
    self.window:SetMovable(self.layoutMode)
    if self.window.SetResizeHandleSize then self.window:SetResizeHandleSize(self.layoutMode and 20 or 0) end
    self:Refresh()
end

local ResetPositionImplArch

function R:ResetPosition(...)

    return ResetPositionImplArch(self, ...)

end

ResetPositionImplArch = function(self)
    if not self.window or not EPC.saved then return end
    EPC.saved.rotationAssistantLeft = -1
    EPC.saved.rotationAssistantTop = -1
    EPC.saved.rotationAssistantWidth = 330
    EPC.saved.rotationAssistantHeight = 112
    self.window:ClearAnchors()
    self.window:SetDimensions(330,112)
    self.window:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -35, 240)
    self:UpdateScale()
end

local InitializeImplArch

function R:Initialize(...)

    return InitializeImplArch(self, ...)

end

InitializeImplArch = function(self)
    self.slots=self:GetSlots()
    self:CreateUI()
    local p=EPC.name.."_RotationAssistant"
    if EVENT_PLAYER_COMBAT_STATE then EPC.Runtime:RegisterEvent("RotationAssistant","Combat",EVENT_PLAYER_COMBAT_STATE,function() self:Refresh() end) end
    if EVENT_ACTION_SLOT_UPDATED then EPC.Runtime:RegisterEvent("RotationAssistant","Slot",EVENT_ACTION_SLOT_UPDATED,function() self:Refresh() end) end
    if EVENT_ACTIVE_WEAPON_PAIR_CHANGED then EPC.Runtime:RegisterEvent("RotationAssistant","Bar",EVENT_ACTIVE_WEAPON_PAIR_CHANGED,function() self:Refresh() end) end
    if EVENT_PLAYER_ACTIVATED then EPC.Runtime:RegisterEvent("RotationAssistant","Activated",EVENT_PLAYER_ACTIVATED,function() self:Refresh() end) end
    EPC.Runtime:RegisterUpdate("RotationAssistant","Tick",350,function()
        if not EPC.saved or EPC.saved.rotationAssistantEnabled == false then return end
        if self.layoutMode ~= true and type(IsUnitInCombat) == "function" and safe(IsUnitInCombat, false, "player") ~= true then return end
        self:Refresh()
    end)
    self:Refresh()
end

function R:SetEnabled(value)
    if EPC.saved then EPC.saved.rotationAssistantEnabled=value==true end
    self:Refresh()
end

-- v0.29.161 - Smart Combat Advisor + adaptive block warning.
-- Guidance only: this module never casts abilities, blocks, swaps bars, or sends input.
local EAS_RA_CreateUIBase029161 = CreateUIImplArch
local EAS_RA_InitializeBase029161 = InitializeImplArch
local EAS_RA_SetLayoutModeBase029161 = SetLayoutModeImplArch
local EAS_RA_ResetPositionBase029161 = ResetPositionImplArch

local function pct(currentValue, maxValue)
    local current = tonumber(currentValue) or 0
    local maximum = tonumber(maxValue) or 0
    if maximum <= 0 then return 100 end
    return math.max(0, math.min(100, current / maximum * 100))
end

local function tableHasText(text, words)
    text = lower(text)
    for _, word in ipairs(words or {}) do
        if text:find(lower(word), 1, true) then return true end
    end
    return false
end

local function actionBindingText(actionName)
    if not actionName or actionName == "" then return "" end

    if EPC.GetActionBindingMarkup029199 then
        local unified = EPC:GetActionBindingMarkup029199(actionName, 20)
        if unified ~= "" then return unified end
    end

    if type(ZO_Keybindings_GetBindingStringFromAction) == "function" then
        local textOptions = KEYBIND_TEXT_OPTIONS_ABBREVIATED_NAME or 1
        local textureOptions = KEYBIND_TEXTURE_OPTIONS_NONE or 1
        for index = 1, 4 do
            local text = tostring(safe(ZO_Keybindings_GetBindingStringFromAction, "", actionName, textOptions, textureOptions, index) or "")
            if text ~= "" then return text end
        end
    end
    return ""
end

function R:GetPlayerHealthPct029161()
    local cur, maxValue = safe(GetUnitPower, 0, "player", POWERTYPE_HEALTH)
    return pct(cur, maxValue)
end

function R:GetResourcePct029161(powerType)
    local cur, maxValue = safe(GetUnitPower, 0, "player", powerType)
    return pct(cur, maxValue), tonumber(maxValue) or 0
end

function R:GetLowestGroupHealthPct029161()
    local lowest = self:GetPlayerHealthPct029161()
    for i = 1, 12 do
        local tag = "group" .. tostring(i)
        if safe(DoesUnitExist, false, tag) == true and safe(IsUnitDead, false, tag) ~= true then
            local cur, maxValue = safe(GetUnitPower, 0, tag, POWERTYPE_HEALTH)
            local value = pct(cur, maxValue)
            if value < lowest then lowest = value end
        end
    end
    return lowest
end

function R:GetAdvisorRole029161()
    local savedMode = EPC.saved and string.upper(tostring(EPC.saved.rotationAdvisorRoleMode or "AUTO")) or "AUTO"
    if savedMode ~= "AUTO" then return savedMode end

    local suiteMode = EPC.Role and type(EPC.Role.GetMode) == "function" and EPC.Role:GetMode() or "AUTO"
    local suiteRole = EPC.Role and type(EPC.Role.GetRole) == "function" and EPC.Role:GetRole() or "DAMAGE"
    -- Explicit Suite role overrides always win.
    if suiteMode ~= "AUTO" then
        if suiteRole == "TANK" then return "TANK" end
        if suiteRole == "HEALER" then return "HEALER" end
    end

    -- In Auto mode, honor a selected support LFG role first. If ESO reports DPS
    -- (which is common while solo), inspect both bars so a real taunt/healing
    -- toolkit can still identify a tank or healer without requiring a queue role.
    if suiteRole == "TANK" then return "TANK" end
    if suiteRole == "HEALER" then return "HEALER" end
    if suiteMode == "AUTO" and type(self.GetAllBarAbilities029161) == "function" then
        local taunts, groupHeals = 0, 0
        for _, ability in ipairs(self:GetAllBarAbilities029161()) do
            if ability.used then
                local text = lower((ability.name or "") .. " " .. (ability.description or ""))
                if tableHasText(text, {"taunt", "taunting"}) then taunts = taunts + 1 end
                if tableHasText(text, {"heal", "healing", "restore health"})
                    and tableHasText(text, {"ally", "allies", "group member", "nearby", "area"}) then
                    groupHeals = groupHeals + 1
                end
            end
        end
        if taunts >= 1 then return "TANK" end
        if groupHeals >= 2 then return "HEALER" end
    end

    local _, magMax = self:GetResourcePct029161(POWERTYPE_MAGICKA)
    local _, stamMax = self:GetResourcePct029161(POWERTYPE_STAMINA)
    local largest = math.max(magMax, stamMax)
    if largest > 0 and math.abs(magMax - stamMax) / largest <= 0.10 then
        return "HYBRID"
    end
    return stamMax > magMax and "STAMINA_DPS" or "MAGICKA_DPS"
end

function R:GetAdvisorRoleLabel029161(role)
    local labels = {
        MAGICKA_DPS = "MAG DPS",
        STAMINA_DPS = "STAM DPS",
        HYBRID = "HYBRID DPS",
        HEALER = "HEALER",
        TANK = "TANK",
    }
    return labels[role] or "DPS"
end

function R:GetHotbarCategories029161()
    local primary = rawget(_G, "HOTBAR_CATEGORY_PRIMARY") or 0
    local backup = rawget(_G, "HOTBAR_CATEGORY_BACKUP") or 1
    return primary, backup
end

function R:GetAbilityDescription029161(abilityId)
    abilityId = tonumber(abilityId) or 0
    if abilityId <= 0 or type(GetAbilityDescription) ~= "function" then return "" end
    return tostring(safe(GetAbilityDescription, "", abilityId) or "")
end

local GetBarAbilities029161ImplArch

function R:GetBarAbilities029161(...)

    return GetBarAbilities029161ImplArch(self, ...)

end

GetBarAbilities029161ImplArch = function(self, category)
    local activeCategory = self:GetCategory()
    local out = {}
    for ordinal, slot in ipairs(self.slots or self:GetSlots()) do
        local used = safe(IsSlotUsed, false, slot, category) == true
        local name = tostring(safe(GetSlotName, "", slot, category) or "")
        local icon = tostring(safe(GetSlotTexture, "", slot, category) or "")
        local remain, duration, isGlobal = safe(GetSlotCooldownInfo, 0, slot, category)
        local effect = safe(GetActionSlotEffectTimeRemaining, 0, slot, category)
        local abilityId = tonumber(safe(GetSlotBoundId, 0, slot, category)) or 0
        local isUltimate = ordinal == #(self.slots or self:GetSlots())
        -- API 101050 GetSlotAbilityCost requires the resource mechanic type.
        -- We only need a precise cost for Ultimate readiness here.
        local cost = 0
        if isUltimate and COMBAT_MECHANIC_FLAGS_ULTIMATE ~= nil then
            cost = tonumber(safe(GetSlotAbilityCost, 0, slot, COMBAT_MECHANIC_FLAGS_ULTIMATE, category)) or 0
        end
        local isActiveBar = category == activeCategory
        local usable = true
        if isActiveBar then usable = safe(IsSlotUsable, true, slot, category) ~= false end
        out[#out + 1] = {
            slot = slot,
            ordinal = ordinal,
            category = category,
            activeBar = isActiveBar,
            abilityId = abilityId,
            name = name,
            icon = icon,
            description = self:GetAbilityDescription029161(abilityId),
            used = used,
            remain = tonumber(remain) or 0,
            duration = tonumber(duration) or 0,
            global = isGlobal == true,
            effect = tonumber(effect) or 0,
            usable = usable,
            cost = cost,
            isUltimate = isUltimate,
        }
    end
    return out
end

function R:GetAllBarAbilities029161()
    local primary, backup = self:GetHotbarCategories029161()
    local result = {}
    for _, ability in ipairs(self:GetBarAbilities029161(primary)) do result[#result + 1] = ability end
    if backup ~= primary then
        for _, ability in ipairs(self:GetBarAbilities029161(backup)) do result[#result + 1] = ability end
    end
    return result
end

local ClassifyAbility029161ImplArch

function R:ClassifyAbility029161(...)

    return ClassifyAbility029161ImplArch(self, ...)

end

ClassifyAbility029161ImplArch = function(self, a)
    local text = lower((a.name or "") .. " " .. (a.description or ""))
    local c = {}
    -- Set this before deriving spammable. Otherwise an Ultimate that deals
    -- damage can be misclassified as both an Ultimate and a spammable.
    c.isUltimate = a.isUltimate == true
    c.taunt = tableHasText(text, {"taunt", "taunting"})
    c.heal = tableHasText(text, {"heal", "restore health", "healing"})
    c.shield = tableHasText(text, {"damage shield", "shield that absorbs", "absorbs damage"})
    c.hot = c.heal and tableHasText(text, {"over ", "every ", "each second", "per second"})
    c.damage = tableHasText(text, {"damage", "damaging"}) and not c.heal
    c.dot = c.damage and tableHasText(text, {"over ", "every ", "each second", "per second", "damage every"})
    c.execute = tableHasText(text, {"execute", "missing health", "below 25%", "below 20%", "below 50%", "low health"})
        or tableHasText(a.name, {"killer's blade", "impale", "mage's wrath", "endless fury", "reverse slash", "executioner", "whirling blades", "radiant destruction", "radiant glory", "radiant oppression"})
    c.debuff = tableHasText(text, {"major breach", "minor breach", "vulnerability", "reduces", "off balance", "defile", "weakens", "afflicted with"})
    c.buff = tableHasText(text, {"major ", "minor ", "increase your", "increases your", "gain ", "grant ", "resolve", "brutality", "sorcery", "savagery", "prophecy"}) and not c.debuff
    c.resource = tableHasText(text, {"restore magicka", "restore stamina", "magicka recovery", "stamina recovery", "resource", "restore resources"})
    c.defensive = c.shield or tableHasText(text, {"major protection", "minor protection", "major resolve", "reduce your damage taken", "damage taken by", "block mitigation", "resistance"})
    c.interrupt = tableHasText(text, {"interrupt", "crushing shock", "venom arrow"})
    c.spammable = c.damage and not c.dot and not c.execute and not c.debuff and not c.isUltimate
    return c
end

local IsUltimateReady029161ImplArch

function R:IsUltimateReady029161(...)

    return IsUltimateReady029161ImplArch(self, ...)

end

IsUltimateReady029161ImplArch = function(self, a)
    if not a or not a.isUltimate or not COMBAT_MECHANIC_FLAGS_ULTIMATE then return false end
    -- GetUnitPower returns multiple values (current, max, effective max).
    -- Parenthesize the safe() call so only the first return value reaches
    -- tonumber(); otherwise Lua forwards the second value as tonumber's
    -- optional base argument, which can raise "base out of range".
    local current = tonumber((safe(GetUnitPower, 0, "player", COMBAT_MECHANIC_FLAGS_ULTIMATE))) or 0
    local cost = tonumber(a.cost) or 0
    return cost > 0 and current >= cost
end

local ScoreSmartAbility029161ImplArch

function R:ScoreSmartAbility029161(...)

    return ScoreSmartAbility029161ImplArch(self, ...)

end

ScoreSmartAbility029161ImplArch = function(self, a, context)
    if not a.used or a.name == "" then return -1000, "Unavailable" end
    if not a.usable then return -600, "Not usable" end
    if a.remain > 0 and a.duration > 0 and not a.global then return -500, "Cooldown" end

    local cls = self:ClassifyAbility029161(a)
    local role = context.role
    local effectActive = (tonumber(a.effect) or 0) > 1500
    local effectEnding = (tonumber(a.effect) or 0) > 0 and (tonumber(a.effect) or 0) <= 1500
    local score, reason = 100, "Best available"
    local name = lower(a.name)

    if context.crystalProc and (contains(name, "crystal fragments") or contains(name, "crystal shard")) then
        return 1200, "PROC READY"
    end

    if role == "TANK" then
        if cls.taunt then
            if not effectActive or effectEnding then return 1120, "TAUNT / refresh aggro" end
            return 260, "Taunt active"
        end
        if context.playerHP <= 45 and (cls.heal or cls.defensive) then return 1040, "Survive / stabilize" end
        if cls.defensive and (not effectActive or effectEnding) then return 930, "Defensive buff" end
        if cls.debuff and (not effectActive or effectEnding) then return 850, "Group debuff" end
        if cls.buff and (not effectActive or effectEnding) then return 800, "Support buff" end
        if context.staminaPct <= 30 and cls.resource then return 790, "Restore sustain" end
        if cls.heal and context.playerHP <= 70 then return 760, "Self heal" end
        if cls.isUltimate and self:IsUltimateReady029161(a) then return 700, "Ultimate ready" end
        if cls.damage then return 380, "Damage while stable" end
        return score, reason
    end

    if role == "HEALER" then
        if context.groupHP <= 35 and cls.heal and not cls.hot then return 1160, "EMERGENCY HEAL" end
        if context.groupHP <= 55 and cls.heal then return 1080, cls.hot and "Emergency HoT" or "Burst heal" end
        if cls.hot and (not effectActive or effectEnding) then return 960, "Refresh HoT" end
        if context.groupHP <= 75 and cls.heal then return 900, "Heal group" end
        if cls.buff and (not effectActive or effectEnding) then return 850, "Refresh group buff" end
        if cls.debuff and (not effectActive or effectEnding) then return 820, "Refresh debuff" end
        if context.magickaPct <= 30 and cls.resource then return 800, "Restore sustain" end
        if cls.isUltimate and self:IsUltimateReady029161(a) and context.groupHP <= 70 then return 780, "Support Ultimate" end
        if cls.dot and (not effectActive or effectEnding) then return 520, "Damage while stable" end
        if cls.damage then return 430, "Damage while stable" end
        return score, reason
    end

    -- DPS / hybrid priorities.
    if context.playerHP <= 35 and (cls.heal or cls.shield or cls.defensive) then return 1100, "Defend / heal" end
    if cls.execute and context.targetHP > 0 and context.targetHP <= 25 then return 1030, "EXECUTE" end
    if cls.debuff and (not effectActive or effectEnding) then return 920, "Refresh debuff" end
    if cls.dot and (not effectActive or effectEnding) then return 900, "Refresh DoT" end
    if cls.buff and (not effectActive or effectEnding) then return 870, "Refresh buff" end
    if cls.isUltimate and self:IsUltimateReady029161(a) and context.targetHP > 0 then return 840, "Ultimate ready" end
    if role == "MAGICKA_DPS" and context.magickaPct <= 20 and cls.resource then return 820, "Restore Magicka" end
    if role == "STAMINA_DPS" and context.staminaPct <= 20 and cls.resource then return 820, "Restore Stamina" end
    if role == "HYBRID" and math.min(context.magickaPct, context.staminaPct) <= 18 and cls.resource then return 810, "Restore resources" end
    if cls.interrupt then return 620, "Interrupt-capable attack" end
    if cls.spammable then return 610, "Spammable" end
    if cls.damage then return 560, "Damage" end
    if cls.heal or cls.defensive then return 240, "Defensive option" end
    return score, reason
end

BuildRecommendationsImplArch = function(self)
    local role = self:GetAdvisorRole029161()
    local magickaPct = self:GetResourcePct029161(POWERTYPE_MAGICKA)
    local staminaPct = self:GetResourcePct029161(POWERTYPE_STAMINA)
    local context = {
        role = role,
        targetHP = self:GetTargetHealth(),
        playerHP = self:GetPlayerHealthPct029161(),
        groupHP = self:GetLowestGroupHealthPct029161(),
        magickaPct = magickaPct,
        staminaPct = staminaPct,
        crystalProc = self:HasCrystalProc(),
    }

    local scored = {}
    for _, ability in ipairs(self:GetAllBarAbilities029161()) do
        local score, reason = self:ScoreSmartAbility029161(ability, context)
        if not ability.activeBar and score > 0 then
            -- Small swap friction prevents ping-ponging bars for nearly equal choices.
            score = score - 45
        end
        scored[#scored + 1] = { a = ability, score = score, reason = reason, needsSwap = not ability.activeBar }
    end
    table.sort(scored, function(x, y)
        if x.score == y.score then return (x.a.activeBar and 1 or 0) > (y.a.activeBar and 1 or 0) end
        return x.score > y.score
    end)

    local result = {}
    local seenAbility = {}
    for _, entry in ipairs(scored) do
        local key = (tonumber(entry.a.abilityId) or 0) > 0 and tostring(entry.a.abilityId) or (entry.a.name .. ":" .. tostring(entry.a.category))
        if entry.score > 0 and not seenAbility[key] then
            result[#result + 1] = entry
            seenAbility[key] = true
            if #result >= 3 then break end
        end
    end
    self.lastSmartContext029161 = context
    return result, context.targetHP, context.crystalProc, context
end

function R:CreateSmartUI029161()
    if self.smartUI029161 then return end
    if self.hp then self.hp:SetDimensions(150, 18) end

    local block = WM:CreateTopLevelWindow("EAS_SmartCombatBlockWarning029161")
    block:SetDimensions(430, 86)
    block:SetClampedToScreen(true)
    block:SetMouseEnabled(false)
    block:SetMovable(false)
    block:SetHidden(true)
    if block.SetDrawLayer and DL_OVERLAY then block:SetDrawLayer(DL_OVERLAY) end
    if block.SetDrawTier and DT_HIGH then block:SetDrawTier(DT_HIGH) end
    if block.SetDrawLevel then block:SetDrawLevel(1200) end

    local bg = WM:CreateControl(nil, block, CT_BACKDROP)
    bg:SetAnchorFill(block)
    bg:SetCenterColor(0.20, 0.015, 0.01, 0.94)
    bg:SetEdgeColor(1.00, 0.26, 0.08, 1.00)
    bg:SetEdgeTexture(nil, 4, 4, 4)

    local title = WM:CreateControl(nil, block, CT_LABEL)
    title:SetAnchor(TOPLEFT, block, TOPLEFT, 8, 7)
    title:SetAnchor(TOPRIGHT, block, TOPRIGHT, -8, 7)
    title:SetHeight(34)
    title:SetFont("$(BOLD_FONT)|28|soft-shadow-thick")
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    title:SetColor(1.00, 0.35, 0.10, 1)
    title:SetText("BLOCK NOW")

    local detail = WM:CreateControl(nil, block, CT_LABEL)
    detail:SetAnchor(TOPLEFT, block, TOPLEFT, 8, 44)
    detail:SetAnchor(TOPRIGHT, block, TOPRIGHT, -8, 44)
    detail:SetHeight(26)
    detail:SetFont("ZoFontGame")
    detail:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    detail:SetColor(1, 0.90, 0.72, 1)

    block:SetHandler("OnMoveStop", function(control)
        if EPC.saved then
            EPC.saved.rotationBlockWarningLeft029161 = control:GetLeft()
            EPC.saved.rotationBlockWarningTop029161 = control:GetTop()
        end
    end)

    local left = tonumber(EPC.saved and EPC.saved.rotationBlockWarningLeft029161) or -1
    local top = tonumber(EPC.saved and EPC.saved.rotationBlockWarningTop029161) or -1
    if left >= 0 and top >= 0 then block:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    else block:SetAnchor(CENTER, GuiRoot, CENTER, 0, -170) end

    local highlight = WM:CreateTopLevelWindow("EAS_SmartCombatActionHighlight029161")
    highlight:SetMouseEnabled(false)
    highlight:SetHidden(true)
    if highlight.SetDrawLayer and DL_OVERLAY then highlight:SetDrawLayer(DL_OVERLAY) end
    if highlight.SetDrawTier and DT_HIGH then highlight:SetDrawTier(DT_HIGH) end
    if highlight.SetDrawLevel then highlight:SetDrawLevel(1100) end
    local hbg = WM:CreateControl(nil, highlight, CT_BACKDROP)
    hbg:SetAnchorFill(highlight)
    hbg:SetCenterColor(1.00, 0.72, 0.10, 0.10)
    hbg:SetEdgeColor(1.00, 0.72, 0.10, 1.00)
    hbg:SetEdgeTexture(nil, 4, 4, 4)

    local swap = WM:CreateTopLevelWindow("EAS_SmartCombatSwapCue029161")
    swap:SetDimensions(430, 44)
    swap:SetClampedToScreen(true)
    swap:SetMouseEnabled(false)
    swap:SetMovable(false)
    swap:SetHidden(true)
    if swap.SetDrawLayer and DL_OVERLAY then swap:SetDrawLayer(DL_OVERLAY) end
    if swap.SetDrawTier and DT_HIGH then swap:SetDrawTier(DT_HIGH) end
    if swap.SetDrawLevel then swap:SetDrawLevel(1101) end

    swap:SetHandler("OnMoveStop", function(control)
        if EPC.saved then
            EPC.saved.rotationSwapCueLeft029196 = control:GetLeft()
            EPC.saved.rotationSwapCueTop029196 = control:GetTop()
        end
    end)

    local swapLeft = tonumber(EPC.saved and EPC.saved.rotationSwapCueLeft029196) or -1
    local swapTop = tonumber(EPC.saved and EPC.saved.rotationSwapCueTop029196) or -1
    if swapLeft >= 0 and swapTop >= 0 then
        swap:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, swapLeft, swapTop)
    else
        swap:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, -95)
    end

    local swapBg = WM:CreateControl(nil, swap, CT_BACKDROP)
    swapBg:SetAnchorFill(swap)
    swapBg:SetCenterColor(0.02, 0.03, 0.05, 0.88)
    swapBg:SetEdgeColor(0.98, 0.68, 0.18, 0.95)
    swapBg:SetEdgeTexture(nil, 2, 2, 2)
    local swapLabel = WM:CreateControl(nil, swap, CT_LABEL)
    swapLabel:SetAnchorFill(swap)
    swapLabel:SetFont("$(BOLD_FONT)|19|soft-shadow-thick")
    swapLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    swapLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    swapLabel:SetColor(1.00, 0.84, 0.38, 1)

    self.blockWindow029161 = block
    self.blockTitle029161 = title
    self.blockDetail029161 = detail
    self.actionHighlight029161 = highlight
    self.swapCue029161 = swap
    self.swapLabel029161 = swapLabel
    self.smartUI029161 = true
end

CreateUIImplArch = function(self)
    EAS_RA_CreateUIBase029161(self)
    self:CreateSmartUI029161()
end

-- v0.29.165 - Native in-slot recommendation highlight.
-- Do not position a separate top-level window from screen-space geometry. ESO's
-- ActionButton wrapper/button/icon controls have different local anchors, and a
-- top-level anchor can visually drift between slots on scaled/custom action bars.
-- Instead, create the advisor border as a child of the *currently visible* native
-- action slot and anchor it directly to that slot's Icon texture.
function R:GetNativeActionButtonObject029165(entry)
    if not entry or not entry.a or type(ZO_ActionBar_GetButton) ~= "function" then return nil end
    if entry.needsSwap then return nil end

    -- With no category argument ESO explicitly returns the currently visible
    -- physical action-bar button. This avoids accidentally targeting a back-bar
    -- timer slot while a weapon-swap animation/category transition is occurring.
    local actionButton = safe(ZO_ActionBar_GetButton, nil, entry.a.slot)
    if not actionButton then return nil end
    return actionButton
end

function R:GetNativeActionControl029161(entry)
    local actionButton = self:GetNativeActionButtonObject029165(entry)
    if not actionButton then return nil end
    -- The Icon child is the exact textured square visible to the player.
    return actionButton.icon
        or (actionButton.slot and type(actionButton.slot.GetNamedChild) == "function" and actionButton.slot:GetNamedChild("Icon"))
        or actionButton.slot
end

function R:GetOrCreateSlotHighlight029165(entry)
    local actionButton = self:GetNativeActionButtonObject029165(entry)
    if not actionButton or not actionButton.slot then return nil end
    local slot = tonumber(entry and entry.a and entry.a.slot) or 0
    self.nativeSlotHighlights029165 = self.nativeSlotHighlights029165 or {}

    local highlight = self.nativeSlotHighlights029165[slot]
    if highlight and highlight.GetParent and highlight:GetParent() ~= actionButton.slot then
        highlight:SetHidden(true)
        highlight = nil
        self.nativeSlotHighlights029165[slot] = nil
    end

    if not highlight then
        highlight = WM:CreateControl("EAS_SmartCombatNativeHighlight029165_" .. tostring(slot), actionButton.slot, CT_BACKDROP)
        highlight:SetMouseEnabled(false)
        highlight:SetCenterColor(1.00, 0.72, 0.10, 0.08)
        highlight:SetEdgeColor(1.00, 0.72, 0.10, 1.00)
        highlight:SetEdgeTexture(nil, 2, 2, 2)
        if highlight.SetDrawLayer and DL_OVERLAY then highlight:SetDrawLayer(DL_OVERLAY) end
        if highlight.SetDrawLevel then highlight:SetDrawLevel(1000) end
        self.nativeSlotHighlights029165[slot] = highlight
    end

    local icon = actionButton.icon
        or (type(actionButton.slot.GetNamedChild) == "function" and actionButton.slot:GetNamedChild("Icon"))
    if not icon then return nil end
    highlight:ClearAnchors()
    highlight:SetAnchor(TOPLEFT, icon, TOPLEFT, -1, -1)
    highlight:SetAnchor(BOTTOMRIGHT, icon, BOTTOMRIGHT, 1, 1)
    return highlight
end

function R:HideNativeSlotHighlights029165()
    for _, highlight in pairs(self.nativeSlotHighlights029165 or {}) do
        if highlight then highlight:SetHidden(true) end
    end
end

local HideActionGuidance029161ImplArch

function R:HideActionGuidance029161(...)

    return HideActionGuidance029161ImplArch(self, ...)

end

HideActionGuidance029161ImplArch = function(self)
    -- Keep the old top-level control permanently hidden for saved-runtime
    -- compatibility, but use only the native in-slot highlights from v0.29.165.
    if self.actionHighlight029161 then self.actionHighlight029161:SetHidden(true) end
    self:HideNativeSlotHighlights029165()
    if self.swapCue029161 then
        -- HUD Layout Mode previews the swap cue even when there is no live
        -- off-bar recommendation, allowing it to be dragged independently.
        self.swapCue029161:SetHidden(self.layoutMode ~= true)
        if self.layoutMode == true and self.swapLabel029161 then
            self.swapLabel029161:SetText("WEAPON BAR SWAP CUE  •  DRAG TO MOVE")
        end
    end
    if EPC.AbilityOverlays then EPC.AbilityOverlays.smartRecommendedSlot029161 = nil end
end

local ShowActionHighlight029161ImplArch

function R:ShowActionHighlight029161(...)

    return ShowActionHighlight029161ImplArch(self, ...)

end

ShowActionHighlight029161ImplArch = function(self, entry)
    self:HideActionGuidance029161()
    if not entry or not entry.a then return end

    -- Never outline an inactive/back bar. Ask for the swap first. Once ESO has
    -- actually switched bars, the next refresh resolves the visible physical
    -- slot with ZO_ActionBar_GetButton(slot) and highlights its Icon directly.
    if entry.needsSwap then
        if self.swapCue029161 and self.swapLabel029161 then
            local swapKey = actionBindingText("SPECIAL_MOVE_WEAPON_SWAP")
            local prefix = swapKey ~= "" and ("SWAP [" .. swapKey .. "]") or "SWAP BAR"
            self.swapLabel029161:SetText(prefix .. "  →  " .. tostring(entry.a.name or ""))
            self.swapCue029161:SetHidden(false)
        end
        return
    end

    local highlight = self:GetOrCreateSlotHighlight029165(entry)
    if highlight then
        highlight:SetAlpha(1.00)
        highlight:SetHidden(false)
    elseif EPC.AbilityOverlays then
        EPC.AbilityOverlays.smartRecommendedSlot029161 = entry.a.slot
        EPC.AbilityOverlays.smartRecommendedCategory029161 = entry.a.category
    end
end

function R:IsLikelyBlockCast029161(abilityName, abilityId)
    local name = lower(abilityName)
    local learned = EPC.saved and EPC.saved.rotationBlockLearnedAbilities029161 or {}
    local dangerous = EPC.saved and EPC.saved.rotationBlockDangerousAbilities029161 or {}
    abilityId = tonumber(abilityId) or 0
    if abilityId > 0 and (learned[tostring(abilityId)] == true or dangerous[tostring(abilityId)] == true) then return true, "learned" end

    local direct = {
        "heavy attack", "power attack", "charged attack", "crushing blow", "powerful blow",
        "uppercut", "wrecking blow", "haymaker", "skull bash", "shield bash", "massive strike",
        "heavy strike", "heavy slash", "heavy swing", "brutal strike", "devastating blow",
    }
    if tableHasText(name, direct) then return true, "heavy" end

    local sensitivity = EPC.saved and string.upper(tostring(EPC.saved.rotationBlockSensitivity029161 or "NORMAL")) or "NORMAL"
    if sensitivity == "AGGRESSIVE" then return true, "incoming cast" end
    if sensitivity == "NORMAL" then
        if tableHasText(name, {"slam", "smash", "crush", "charge", "lunge", "cleave"}) then return true, "dangerous cast" end
    end
    return false, nil
end

function R:TriggerBlockWarning029161(abilityName, abilityId, reason)
    if not EPC.saved or EPC.saved.rotationBlockWarningEnabled029161 == false then return end
    self.blockThreatUntil029161 = now() + 1800
    self.blockThreatName029161 = tostring(abilityName or "Incoming heavy attack")
    self.blockThreatReason029161 = tostring(reason or "incoming")
    self.blockThreatAbilityId029161 = tonumber(abilityId) or 0
    -- v0.29.203: BLOCK is no longer a separate HUD window. Route the reaction
    -- into the Boss Mechanics / Combat Reaction panel so the player has one
    -- authoritative mechanic overlay instead of two competing warnings.
    if EPC.BossMechanicsAssistant and EPC.BossMechanicsAssistant.TriggerReaction029203 then
        EPC.BossMechanicsAssistant:TriggerReaction029203("BLOCK", self.blockThreatName029161, 1800, 5)
    end
end

function R:OnIncomingCombat029161(_, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId)
    if isError == true then return end
    abilityId = tonumber(abilityId) or 0
    hitValue = tonumber(hitValue) or 0
    EPC.saved.rotationBlockLearnedAbilities029161 = EPC.saved.rotationBlockLearnedAbilities029161 or {}
    EPC.saved.rotationBlockDangerousAbilities029161 = EPC.saved.rotationBlockDangerousAbilities029161 or {}

    if (ACTION_RESULT_BLOCKED_DAMAGE and result == ACTION_RESULT_BLOCKED_DAMAGE) or (ACTION_RESULT_BLOCKED and result == ACTION_RESULT_BLOCKED) then
        if abilityId > 0 then EPC.saved.rotationBlockLearnedAbilities029161[tostring(abilityId)] = true end
        if self.blockThreatAbilityId029161 == abilityId then self.blockThreatUntil029161 = now() + 180 end
        return
    end

    if (ACTION_RESULT_DAMAGE and result == ACTION_RESULT_DAMAGE) or (ACTION_RESULT_CRITICAL_DAMAGE and result == ACTION_RESULT_CRITICAL_DAMAGE) then
        if EPC.saved.rotationBlockLearning029161 ~= false and abilityId > 0 then
            local _, maxHealth = safe(GetUnitPower, 0, "player", POWERTYPE_HEALTH)
            maxHealth = tonumber(maxHealth) or 0
            if maxHealth > 0 and hitValue >= maxHealth * 0.24 then
                EPC.saved.rotationBlockDangerousAbilities029161[tostring(abilityId)] = true
            end
        end
        return
    end

    if ACTION_RESULT_BEGIN and result == ACTION_RESULT_BEGIN then
        -- ESO exposes heavy attacks as an ActionSlotType on combat events. Use
        -- that native signal before any name/learned heuristic so obvious heavy
        -- attacks get the cleanest possible BLOCK NOW warning.
        if ACTION_SLOT_TYPE_HEAVY_ATTACK ~= nil and abilityActionSlotType == ACTION_SLOT_TYPE_HEAVY_ATTACK then
            self:TriggerBlockWarning029161(abilityName ~= "" and abilityName or "Heavy Attack", abilityId, "heavy attack")
            return
        end
        local warn, reason = self:IsLikelyBlockCast029161(abilityName, abilityId)
        if warn then self:TriggerBlockWarning029161(abilityName, abilityId, reason) end
    end
end

function R:RegisterBlockEvents029161()
    if self.blockEventsRegistered029161 or not EVENT_COMBAT_EVENT then return end
    self.blockEventsRegistered029161 = true
    local prefix = EPC.name .. "_SmartBlock029161_"
    local results = {
        {"Begin", ACTION_RESULT_BEGIN},
        {"BlockedDamage", ACTION_RESULT_BLOCKED_DAMAGE},
        {"Blocked", ACTION_RESULT_BLOCKED},
        {"Damage", ACTION_RESULT_DAMAGE},
        {"CriticalDamage", ACTION_RESULT_CRITICAL_DAMAGE},
    }
    if not REGISTER_FILTER_COMBAT_RESULT or not REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE or COMBAT_UNIT_TYPE_PLAYER == nil then return end
    for _, item in ipairs(results) do
        local suffix, result = item[1], item[2]
        if result ~= nil then
            local filters = {
                { REGISTER_FILTER_COMBAT_RESULT, result },
                { REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER },
            }
            if REGISTER_FILTER_IS_ERROR then filters[#filters + 1] = { REGISTER_FILTER_IS_ERROR, false } end
            EPC.Runtime:RegisterEvent("RotationAssistant", "SmartBlock" .. suffix, EVENT_COMBAT_EVENT, function(...) self:OnIncomingCombat029161(...) end, filters)
        end
    end
end

function R:RefreshBlockCue029161(combat)
    self:CreateSmartUI029161()
    -- v0.29.203: the old standalone BLOCK NOW frame is intentionally retired.
    -- Generic block threats are forwarded by TriggerBlockWarning029161 into the
    -- resizable Boss Mechanics / Combat Reaction overlay. Keep this control
    -- hidden for SavedVariables/backward compatibility with older installs.
    if self.blockWindow029161 then self.blockWindow029161:SetHidden(true) end
end

RefreshImplArch = function(self)
    self:CreateUI()
    local enabled = EPC.saved and EPC.saved.rotationAssistantEnabled ~= false
    local combat = safe(IsUnitInCombat, false, "player") == true
    local displayMode = EPC.saved and string.upper(tostring(EPC.saved.rotationAssistantDisplayMode029161 or "HIGHLIGHT")) or "HIGHLIGHT"

    local recs, hp, proc, context = self:BuildRecommendations()
    local first = recs[1]
    local cardMode = displayMode == "FULL" or displayMode == "COMPACT"
    local showWindow = cardMode and (self.layoutMode == true or (enabled and combat))
    self.window:SetHidden(not showWindow)
    if self.queue then self.queue:SetHidden(displayMode == "COMPACT" and self.layoutMode ~= true) end

    self:RefreshBlockCue029161(combat)

    if self.layoutMode == true then
        -- Layout mode is a placement preview, not a live recommendation state.
        -- Keep the independent swap cue visible and draggable at its saved spot.
        self:HideActionGuidance029161()
    elseif enabled and combat and displayMode == "HIGHLIGHT" and first then
        self:ShowActionHighlight029161(first)
    else
        self:HideActionGuidance029161()
    end

    if not showWindow then return end

    local roleLabel = self:GetAdvisorRoleLabel029161(context and context.role or self:GetAdvisorRole029161())
    self.hp:SetText((hp > 0 and string.format("%s • %.0f%%", roleLabel, hp)) or roleLabel)

    if #recs == 0 then
        self.icon:SetTexture("")
        self.nextLabel:SetText("NO ACTION")
        self.reason:SetText("Check your action bars")
        self.queue:SetText("")
        return
    end

    self.icon:SetTexture(first.a.icon or "")
    local actionKey = actionBindingText("ACTION_BUTTON_" .. tostring(first.a.slot))
    local label = tostring(first.a.name or "")
    if first.needsSwap then label = "SWAP → " .. label end
    self.nextLabel:SetText(label)
    local reason = tostring(first.reason or "Best available")
    if actionKey ~= "" and not first.needsSwap then reason = "[" .. actionKey .. "] " .. reason end
    self.reason:SetText(reason)
    local q = {}
    for i = 2, #recs do
        q[#q + 1] = (recs[i].needsSwap and "SWAP→" or "") .. tostring(recs[i].a.name or "")
    end
    self.queue:SetText(#q > 0 and ("Next: " .. table.concat(q, "  →  ")) or "")
end

SetLayoutModeImplArch = function(self, active)
    EAS_RA_SetLayoutModeBase029161(self, active)
    self:CreateSmartUI029161()
    local layout = active == true
    if self.blockWindow029161 then
        self.blockWindow029161:SetMouseEnabled(false)
        self.blockWindow029161:SetMovable(false)
        self.blockWindow029161:SetHidden(true)
    end
    if self.swapCue029161 then
        self.swapCue029161:SetMouseEnabled(layout)
        self.swapCue029161:SetMovable(layout)
    end
    self:Refresh()
end

ResetPositionImplArch = function(self)
    EAS_RA_ResetPositionBase029161(self)
    if EPC.saved then
        EPC.saved.rotationBlockWarningLeft029161 = -1
        EPC.saved.rotationBlockWarningTop029161 = -1
        EPC.saved.rotationSwapCueLeft029196 = -1
        EPC.saved.rotationSwapCueTop029196 = -1
    end
    if self.blockWindow029161 then
        self.blockWindow029161:ClearAnchors()
        self.blockWindow029161:SetAnchor(CENTER, GuiRoot, CENTER, 0, -170)
    end
    if self.swapCue029161 then
        self.swapCue029161:ClearAnchors()
        self.swapCue029161:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, -95)
    end
end

InitializeImplArch = function(self)
    EAS_RA_InitializeBase029161(self)
    self:RegisterBlockEvents029161()
    self:Refresh()
end

-- v0.29.166 - Reliable visible action-button highlight.
-- Anchor a high-layer top-level glow directly to ZO_ActionBar_GetButton(slot).button.
-- The .button control is ESO's actual visible/clickable action button and avoids
-- clipping/draw-order problems seen when parenting highlights to slot/icon wrappers.
local GetVisibleActionButtonControl029166ImplArch
function R:GetVisibleActionButtonControl029166(...)
    return GetVisibleActionButtonControl029166ImplArch(self, ...)
end
GetVisibleActionButtonControl029166ImplArch = function(self, entry)
    if not entry or not entry.a or entry.needsSwap then return nil end
    if type(ZO_ActionBar_GetButton) ~= "function" then return nil end
    local slot = tonumber(entry.a.slot)
    if not slot then return nil end
    local actionButton = safe(ZO_ActionBar_GetButton, nil, slot)
    if not actionButton then return nil end

    local candidates = { actionButton.button, actionButton.slot, actionButton.icon }
    for _, control in ipairs(candidates) do
        if control and type(control.GetDimensions) == "function" and type(control.SetAnchor) == "function" then
            local w, h = control:GetDimensions()
            if (tonumber(w) or 0) > 0 and (tonumber(h) or 0) > 0 then
                return control, actionButton
            end
        end
    end
    return nil, actionButton
end

function R:GetOrCreateVisibleHighlight029166()
    if self.visibleActionHighlight029166 then return self.visibleActionHighlight029166 end

    local glow = WM:CreateTopLevelWindow("EAS_SmartCombatVisibleHighlight029166")
    glow:SetMouseEnabled(false)
    glow:SetHidden(true)
    if glow.SetDrawLayer and DL_OVERLAY then glow:SetDrawLayer(DL_OVERLAY) end
    if glow.SetDrawTier and DT_HIGH then glow:SetDrawTier(DT_HIGH) end
    if glow.SetDrawLevel then glow:SetDrawLevel(10000) end

    local outer = WM:CreateControl(nil, glow, CT_BACKDROP)
    outer:SetAnchorFill(glow)
    outer:SetCenterColor(1.00, 0.72, 0.08, 0.18)
    outer:SetEdgeColor(1.00, 0.78, 0.10, 1.00)
    outer:SetEdgeTexture(nil, 4, 4, 4)
    if outer.SetDrawLayer and DL_OVERLAY then outer:SetDrawLayer(DL_OVERLAY) end
    if outer.SetDrawLevel then outer:SetDrawLevel(10001) end

    local inner = WM:CreateControl(nil, glow, CT_BACKDROP)
    inner:SetAnchor(TOPLEFT, glow, TOPLEFT, 3, 3)
    inner:SetAnchor(BOTTOMRIGHT, glow, BOTTOMRIGHT, -3, -3)
    inner:SetCenterColor(0, 0, 0, 0)
    inner:SetEdgeColor(1.00, 0.92, 0.42, 0.90)
    inner:SetEdgeTexture(nil, 2, 2, 2)
    if inner.SetDrawLayer and DL_OVERLAY then inner:SetDrawLayer(DL_OVERLAY) end
    if inner.SetDrawLevel then inner:SetDrawLevel(10002) end

    local tag = WM:CreateControl(nil, glow, CT_LABEL)
    tag:SetAnchor(BOTTOM, glow, TOP, 0, -2)
    tag:SetFont("$(BOLD_FONT)|14|soft-shadow-thick")
    tag:SetColor(1.00, 0.90, 0.30, 1.00)
    tag:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    tag:SetText("NEXT")
    if tag.SetDrawLayer and DL_OVERLAY then tag:SetDrawLayer(DL_OVERLAY) end
    if tag.SetDrawLevel then tag:SetDrawLevel(10003) end

    self.visibleActionHighlight029166 = glow
    self.visibleActionHighlightTag029166 = tag
    return glow
end

function R:HideVisibleActionHighlight029166()
    if self.visibleActionHighlight029166 then self.visibleActionHighlight029166:SetHidden(true) end
end

local EAS_HideActionGuidanceBase029166 = HideActionGuidance029161ImplArch
HideActionGuidance029161ImplArch = function(self)
    EAS_HideActionGuidanceBase029166(self)
    self:HideVisibleActionHighlight029166()
end

ShowActionHighlight029161ImplArch = function(self, entry)
    self:HideActionGuidance029161()
    if not entry or not entry.a then return end

    if entry.needsSwap then
        if self.swapCue029161 and self.swapLabel029161 then
            local swapKey = actionBindingText("SPECIAL_MOVE_WEAPON_SWAP")
            local prefix = swapKey ~= "" and ("SWAP [" .. swapKey .. "]") or "SWAP BAR"
            self.swapLabel029161:SetText(prefix .. "  →  " .. tostring(entry.a.name or ""))
            self.swapCue029161:SetHidden(false)
        end
        self.lastHighlightStatus029166 = "SWAP"
        return
    end

    local target = self:GetVisibleActionButtonControl029166(entry)
    if not target then
        self.lastHighlightStatus029166 = "NO_BUTTON:" .. tostring(entry.a.slot or "?")
        return
    end

    local glow = self:GetOrCreateVisibleHighlight029166()
    glow:ClearAnchors()
    glow:SetAnchor(TOPLEFT, target, TOPLEFT, -3, -3)
    glow:SetAnchor(BOTTOMRIGHT, target, BOTTOMRIGHT, 3, 3)
    glow:SetAlpha(1.00)
    glow:SetHidden(false)
    self.lastHighlightStatus029166 = "VISIBLE:" .. tostring(entry.a.slot or "?")
end

function R:TestActionHighlight029166()
    self:CreateUI()
    local chosen = nil
    if type(self.GetAllBarAbilities029161) == "function" then
        local abilities = self:GetAllBarAbilities029161() or {}
        for _, ability in ipairs(abilities) do
            if ability and ability.activeBar and ability.used and ability.name ~= "" and not ability.isUltimate then
                chosen = { a = ability, needsSwap = false, score = 9999, reason = "Highlight test" }
                break
            end
        end
        if not chosen then
            for _, ability in ipairs(abilities) do
                if ability and ability.activeBar and ability.used and ability.name ~= "" then
                    chosen = { a = ability, needsSwap = false, score = 9999, reason = "Highlight test" }
                    break
                end
            end
        end
    end

    if not chosen then
        if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then CHAT_SYSTEM:AddMessage("[EAS] No visible action-bar ability found for the highlight test.") end
        return false
    end

    self.testHighlightEntry029166 = chosen
    self.testHighlightUntil029166 = now() + 3000
    self:ShowActionHighlight029161(chosen)
    if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage("[EAS] Testing Smart Combat highlight on " .. tostring(chosen.a.name or "ability") .. " for 3 seconds.")
    end
    return true
end

local EAS_RA_RefreshBase029166 = RefreshImplArch
RefreshImplArch = function(self)
    local result = EAS_RA_RefreshBase029166(self)
    if self.testHighlightEntry029166 and (tonumber(self.testHighlightUntil029166) or 0) > now() then
        self:ShowActionHighlight029161(self.testHighlightEntry029166)
    elseif self.testHighlightEntry029166 then
        self.testHighlightEntry029166 = nil
        self.testHighlightUntil029166 = 0
    end
    return result
end


-- v0.29.167 - Highlight the Suite Ability Overlay itself.
-- The user's visible ability row is rendered by AbilityOverlays.lua, not the
-- stock ZO_ActionBar controls. Anchoring to stock controls caused the advisor
-- glow to appear offset from the Suite boxes. Prefer the exact Suite widget and
-- use the native action bar only as a fallback when Suite overlays are hidden.
local EAS_HideActionGuidanceBase029167 = HideActionGuidance029161ImplArch
HideActionGuidance029161ImplArch = function(self)
    EAS_HideActionGuidanceBase029167(self)
    if EPC.AbilityOverlays and EPC.AbilityOverlays.ClearSmartRecommendation029167 then
        EPC.AbilityOverlays:ClearSmartRecommendation029167()
    end
    if EPC.DualActionBar and EPC.DualActionBar.ClearSmartRecommendation029189 then
        EPC.DualActionBar:ClearSmartRecommendation029189()
    end
end

-- Improve the stock-action-bar fallback too: the Icon texture is the exact
-- visible 47x47/61x61 artwork, while .button is a larger interaction wrapper.
GetVisibleActionButtonControl029166ImplArch = function(self, entry)
    if not entry or not entry.a or entry.needsSwap then return nil end
    if type(ZO_ActionBar_GetButton) ~= "function" then return nil end
    local slot = tonumber(entry.a.slot)
    if not slot then return nil end
    local actionButton = safe(ZO_ActionBar_GetButton, nil, slot)
    if not actionButton then return nil end

    local candidates = { actionButton.icon, actionButton.flipCard, actionButton.slot, actionButton.button }
    for _, control in ipairs(candidates) do
        if control and type(control.GetDimensions) == "function" and type(control.SetAnchor) == "function" then
            local w, h = control:GetDimensions()
            if (tonumber(w) or 0) > 0 and (tonumber(h) or 0) > 0 then
                return control, actionButton
            end
        end
    end
    return nil, actionButton
end

local EAS_ShowActionHighlightBase029167 = ShowActionHighlight029161ImplArch
ShowActionHighlight029161ImplArch = function(self, entry)
    self:HideActionGuidance029161()
    if not entry or not entry.a then return end

    if entry.needsSwap then
        if self.swapCue029161 and self.swapLabel029161 then
            local swapKey = actionBindingText("SPECIAL_MOVE_WEAPON_SWAP")
            local prefix = swapKey ~= "" and ("SWAP [" .. swapKey .. "]") or "SWAP BAR"
            self.swapLabel029161:SetText(prefix .. "  ->  " .. tostring(entry.a.name or ""))
            self.swapCue029161:SetHidden(false)
        end
        if EPC.DualActionBar and EPC.saved and EPC.saved.showDualActionBar029189 == true
            and EPC.DualActionBar.SetSmartRecommendation029189 then
            EPC.DualActionBar:SetSmartRecommendation029189(entry.a.slot, entry.a.category, 1.00, true)
        end
        self.lastHighlightStatus029166 = "SWAP"
        return
    end

    local dualBar = EPC.DualActionBar
    if dualBar and EPC.saved and EPC.saved.showDualActionBar029189 == true
        and dualBar.SetSmartRecommendation029189 then
        if dualBar:SetSmartRecommendation029189(entry.a.slot, entry.a.category, 1.00, false) then
            self:HideVisibleActionHighlight029166()
            if self.HideNativeSlotHighlights029165 then self:HideNativeSlotHighlights029165() end
            self.lastHighlightStatus029166 = "DUAL:" .. tostring(entry.a.slot or "?")
            return
        end
    end

    local overlays = EPC.AbilityOverlays
    if overlays and EPC.saved and EPC.saved.showAbilityOverlays ~= false
        and overlays.SetSmartRecommendation029167 then
        if overlays:SetSmartRecommendation029167(entry.a.slot, entry.a.category, 1.00) then
            -- Ensure no legacy/native glow competes with the exact Suite box.
            self:HideVisibleActionHighlight029166()
            if self.HideNativeSlotHighlights029165 then self:HideNativeSlotHighlights029165() end
            self.lastHighlightStatus029166 = "SUITE:" .. tostring(entry.a.slot or "?")
            return
        end
    end

    -- Fallback for players who disable the Suite ability overlays.
    EAS_ShowActionHighlightBase029167(self, entry)
end

-- v0.29.169 - Buff-aware Smart Combat Advisor.
-- Many ESO self buffs do not expose reliable uptime through
-- GetActionSlotEffectTimeRemaining(). Track the player's real active effects
-- and match them back to slotted abilities by ability id, effect name, and
-- Major/Minor BuffType so missing/expiring buffs become part of the rotation.

local function normalizeEffectName029169(value)
    local text = lower(value or "")
    text = text:gsub("[^%w%s]", " ")
    text = text:gsub("%s+", " ")
    return text:gsub("^%s+", ""):gsub("%s+$", "")
end

function R:GetAbilityBuffType029169(abilityId)
    abilityId = tonumber(abilityId) or 0
    if abilityId <= 0 or type(GetAbilityBuffType) ~= "function" then return 0 end
    local value = tonumber((safe(GetAbilityBuffType, 0, abilityId))) or 0
    local none = tonumber(rawget(_G, "BUFF_TYPE_NONE")) or 0
    if value == none then return 0 end
    return math.max(0, value)
end

function R:GetAbilityDuration029169(abilityId)
    abilityId = tonumber(abilityId) or 0
    if abilityId <= 0 or type(GetAbilityDuration) ~= "function" then return 0 end
    return math.max(0, tonumber((safe(GetAbilityDuration, 0, abilityId))) or 0)
end

local ReadUnitEffects029169ImplArch

function R:ReadUnitEffects029169(...)

    return ReadUnitEffects029169ImplArch(self, ...)

end

ReadUnitEffects029169ImplArch = function(self, unitTag)
    local effects = {}
    if type(GetNumBuffs) ~= "function" or type(GetUnitBuffInfo) ~= "function" then return effects end
    if unitTag ~= "player" and type(DoesUnitExist) == "function" and safe(DoesUnitExist, false, unitTag) ~= true then
        return effects
    end

    local count = tonumber((safe(GetNumBuffs, 0, unitTag))) or 0
    local nowSeconds = 0
    if type(GetGameTimeMilliseconds) == "function" then
        nowSeconds = (tonumber((safe(GetGameTimeMilliseconds, 0))) or 0) / 1000
    elseif type(GetFrameTimeSeconds) == "function" then
        nowSeconds = tonumber((safe(GetFrameTimeSeconds, 0))) or 0
    end

    for index = 1, count do
        -- Do not use safe() here: GetUnitBuffInfo returns more values than the
        -- generic helper preserves, including the effect abilityId.
        local ok, effectName, timeStarted, timeEnding, buffSlot, stackCount,
            iconFilename, debugBuffType, effectType, abilityType,
            statusEffectType, effectAbilityId, canClickOff, castByPlayer =
            pcall(GetUnitBuffInfo, unitTag, index)
        if ok then
            local ending = tonumber(timeEnding) or 0
            local remainingMs = 0
            if ending > 0 then
                remainingMs = math.max(0, (ending - nowSeconds) * 1000)
            else
                -- An effect present in the unit buff list with no end time is
                -- persistent/toggled. Treat it as active instead of repeatedly
                -- recommending the ability every refresh.
                remainingMs = 3600000
            end
            local id = tonumber(effectAbilityId) or 0
            effects[#effects + 1] = {
                name = tostring(effectName or ""),
                normalizedName = normalizeEffectName029169(effectName),
                abilityId = id,
                buffType = self:GetAbilityBuffType029169(id),
                remaining = remainingMs,
                castByPlayer = castByPlayer == true,
                canClickOff = canClickOff == true,
            }
        end
    end
    return effects
end

function R:RefreshSmartEffectSnapshots029169()
    self.smartEffects029169 = {
        at = now(),
        player = self:ReadUnitEffects029169("player"),
        target = self:ReadUnitEffects029169("reticleover"),
    }
    return self.smartEffects029169
end

function R:GetTrackedEffectRemaining029169(a, cls)
    if not a then return 0 end
    local slotRemaining = math.max(0, tonumber(a.effect) or 0)
    local snapshot = self.smartEffects029169
    if type(snapshot) ~= "table" or ((now() - (tonumber(snapshot.at) or 0)) > 250) then
        snapshot = self:RefreshSmartEffectSnapshots029169()
    end

    local abilityId = tonumber(a.abilityId) or 0
    local abilityName = normalizeEffectName029169(a.name)
    local abilityBuffType = tonumber(a.buffType029169) or self:GetAbilityBuffType029169(abilityId)
    local best = slotRemaining

    local function consider(list, targetEffect)
        for _, effect in ipairs(list or {}) do
            local directId = abilityId > 0 and tonumber(effect.abilityId) == abilityId
            local directName = abilityName ~= "" and effect.normalizedName ~= "" and effect.normalizedName == abilityName
            local relatedName = false
            if abilityName ~= "" and effect.normalizedName ~= "" and #abilityName >= 6 and #effect.normalizedName >= 6 then
                relatedName = abilityName:find(effect.normalizedName, 1, true) ~= nil
                    or effect.normalizedName:find(abilityName, 1, true) ~= nil
            end
            local sameBuffType = abilityBuffType > 0 and tonumber(effect.buffType) == abilityBuffType

            -- For hostile target effects, prefer effects actually cast by the
            -- player unless there is an exact id/name match. For self buffs,
            -- an equivalent Major/Minor buff from any source already provides
            -- that benefit, so avoid recommending a redundant recast.
            local sourceAllowed = (not targetEffect) or effect.castByPlayer or directId or directName
            if sourceAllowed and (directId or directName or relatedName or sameBuffType) then
                best = math.max(best, tonumber(effect.remaining) or 0)
            end
        end
    end

    if cls and (cls.buff or cls.defensive or cls.shield or cls.resource or cls.hot) then
        consider(snapshot.player, false)
    end
    if cls and (cls.debuff or cls.dot) then
        consider(snapshot.target, true)
    end
    return best
end

local EAS_GetBarAbilitiesBase029169 = GetBarAbilities029161ImplArch
GetBarAbilities029161ImplArch = function(self, category)
    local abilities = EAS_GetBarAbilitiesBase029169(self, category) or {}
    for _, ability in ipairs(abilities) do
        ability.buffType029169 = self:GetAbilityBuffType029169(ability.abilityId)
        ability.abilityDuration029169 = self:GetAbilityDuration029169(ability.abilityId)
    end
    return abilities
end

local EAS_ClassifyAbilityBase029169 = ClassifyAbility029161ImplArch
ClassifyAbility029161ImplArch = function(self, a)
    local c = EAS_ClassifyAbilityBase029169(self, a)
    local text = lower((a and a.name or "") .. " " .. (a and a.description or ""))
    local duration = tonumber(a and a.abilityDuration029169) or self:GetAbilityDuration029169(a and a.abilityId)
    local buffType = tonumber(a and a.buffType029169) or self:GetAbilityBuffType029169(a and a.abilityId)

    c.passiveSlotBuff = tableHasText(text, {"while slotted", "while this ability is slotted"})
    c.pet = tableHasText(text, {"summon", "summons", "pet remains", "familiar", "twilight", "clannfear"})

    -- GetAbilityBuffType is the strongest language-independent signal that a
    -- slotted skill grants a Major/Minor combat buff.
    if buffType > 0 then c.buff = true end

    -- The original generic classifier treats any occurrence of the word
    -- "damage" as an attack and broad words such as "reduces" as a debuff.
    -- Stat buffs like Critical Surge ("Weapon and Spell Damage") and
    -- mitigation buffs ("reduces your damage taken") must not be mistaken for
    -- hostile attacks/debuffs. Keep true damaging skills when the description
    -- contains an actual deal/inflict/damage-over-time phrase.
    local directDamage = tableHasText(text, {
        "deals ", "deal ", "dealing ", "inflict", "damage to an enemy",
        "damage to enemies", "damage every", "damaging an enemy", "damaging enemies"
    })
    local selfMitigation = tableHasText(text, {
        "reduce your damage taken", "reduces your damage taken", "reduced damage taken",
        "reduce damage taken", "reduces damage taken", "block mitigation"
    })
    if selfMitigation then
        c.debuff = false
        c.defensive = true
        c.buff = true
    end
    if c.buff and not directDamage then
        c.damage = false
        c.dot = false
    end

    -- Cover common ESO wording not handled by the original classifier.
    if tableHasText(text, {
        "empower yourself", "surround yourself", "imbue yourself", "charge yourself",
        "granting you", "grants you", "grant yourself", "gain major", "gain minor",
        "increasing your", "increase your", "weapon and spell damage",
        "critical rating", "critical chance", "movement speed", "recovery by",
        "resistances", "physical resistance", "spell resistance", "block mitigation"
    }) then
        c.buff = true
    end

    -- A timed, non-hostile utility ability is usually a self/support buff even
    -- when its localized description does not contain one of the English
    -- Major/Minor phrases. Do not turn plain attacks/heals into buffs here.
    if duration >= 3000 and not c.isUltimate and not c.debuff
        and not c.damage and not c.heal and not c.taunt and not c.interrupt then
        c.buff = true
    end

    -- Passive "while slotted" effects are already active simply by being on
    -- the bar; they should never be cycled as a cast recommendation.
    if c.passiveSlotBuff and duration <= 0 and not c.damage and not c.heal then
        c.passiveOnly = true
    end

    -- A real maintenance buff should not also fall through as a generic
    -- spammable just because its description contains incidental damage.
    if c.buff and not c.dot and not c.execute and not c.debuff then
        c.spammable = false
    end
    return c
end

local EAS_ScoreSmartAbilityBase029169 = ScoreSmartAbility029161ImplArch
ScoreSmartAbility029161ImplArch = function(self, a, context)
    if not a or not context then return -1000, "Unavailable" end
    local cls = self:ClassifyAbility029161(a)
    if cls.passiveOnly then return -50, "Passive while slotted" end

    local tracked = self:GetTrackedEffectRemaining029169(a, cls)
    local originalEffect = a.effect
    a.effect = math.max(tonumber(originalEffect) or 0, tracked)

    local missingOrEnding = tracked <= 1500
    local role = context.role

    -- Maintenance buffs should be established before falling into the attack
    -- loop. This is intentionally above normal DoT/spammable scores, but below
    -- emergency heals, executes, procs, and tank taunt emergencies handled by
    -- the role logic.
    if cls.buff and not cls.isUltimate and missingOrEnding then
        a.effect = originalEffect
        if role == "TANK" then return 995, tracked > 0 and "Refresh defensive/support buff" or "Apply defensive/support buff" end
        if role == "HEALER" then return 985, tracked > 0 and "Refresh group/self buff" or "Apply group/self buff" end
        return 970, tracked > 0 and "Refresh damage buff" or "Apply damage buff"
    end

    local score, reason = EAS_ScoreSmartAbilityBase029169(self, a, context)
    a.effect = originalEffect
    return score, reason
end

local EAS_BuildRecommendationsBase029169 = BuildRecommendationsImplArch
BuildRecommendationsImplArch = function(self)
    local snapshot = self.smartEffects029169
    if type(snapshot) ~= "table" or (now() - (tonumber(snapshot.at) or 0)) >= 200 then
        self:RefreshSmartEffectSnapshots029169()
    end
    return EAS_BuildRecommendationsBase029169(self)
end

-- v0.29.170 - Full-behavior Smart Combat Advisor.
-- The previous classifier could suppress active skills merely because their
-- tooltip contained "while slotted" and did not understand stack spenders,
-- delayed target effects, castable utility skills, pet activations, or some
-- inactive-bar Ultimates.  This layer uses ESO ability metadata first, then
-- tooltip/state heuristics as a fallback, and keeps every real active skill
-- eligible for the role-aware advisor.

local function EAS_RA_Normalize029170(value)
    local text = lower(value or "")
    text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("[^%w%s%%'%-]", " ")
    text = text:gsub("%s+", " ")
    return text:gsub("^%s+", ""):gsub("%s+$", "")
end

local function EAS_RA_PCallFirst029170(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d
end

function R:GetAbilityRuntimeMeta029170(abilityId)
    abilityId = tonumber(abilityId) or 0
    local meta = {
        known = abilityId > 0,
        isPassive = false,
        passiveKnown = false,
        isPermanent = false,
        duration = 0,
        target = "",
        tankRole = false,
        healerRole = false,
        damageRole = false,
        baseCost = 0,
        mechanic = nil,
        channeled = false,
        castTime = 0,
        channelTime = 0,
    }
    if abilityId <= 0 then return meta end

    if type(IsAbilityPassive) == "function" then
        local value = EAS_RA_PCallFirst029170(IsAbilityPassive, abilityId)
        if value ~= nil then
            meta.passiveKnown = true
            meta.isPassive = value == true
        end
    end
    if type(IsAbilityPermanent) == "function" then
        meta.isPermanent = EAS_RA_PCallFirst029170(IsAbilityPermanent, abilityId) == true
    end

    if type(GetAbilityDuration) == "function" then
        local value = EAS_RA_PCallFirst029170(GetAbilityDuration, abilityId, nil, "player")
        if value == nil then value = EAS_RA_PCallFirst029170(GetAbilityDuration, abilityId) end
        meta.duration = math.max(0, tonumber(value) or 0)
    end

    if type(GetAbilityTargetDescription) == "function" then
        local value = EAS_RA_PCallFirst029170(GetAbilityTargetDescription, abilityId, nil, "player")
        if value == nil then value = EAS_RA_PCallFirst029170(GetAbilityTargetDescription, abilityId) end
        meta.target = tostring(value or "")
    end

    if type(GetAbilityRoles) == "function" then
        local ok, tankRole, healerRole, damageRole = pcall(GetAbilityRoles, abilityId)
        if ok then
            meta.tankRole = tankRole == true
            meta.healerRole = healerRole == true
            meta.damageRole = damageRole == true
        end
    end

    if type(GetAbilityBaseCostInfo) == "function" then
        local ok, baseCost, mechanic = pcall(GetAbilityBaseCostInfo, abilityId, nil, "player")
        if ok then
            meta.baseCost = math.max(0, tonumber(baseCost) or 0)
            meta.mechanic = mechanic
        end
    end

    if type(GetAbilityCastInfo) == "function" then
        local ok, channeled, castTime, channelTime = pcall(GetAbilityCastInfo, abilityId, nil, "player")
        if not ok then ok, channeled, castTime, channelTime = pcall(GetAbilityCastInfo, abilityId) end
        if ok then
            meta.channeled = channeled == true
            meta.castTime = math.max(0, tonumber(castTime) or 0)
            meta.channelTime = math.max(0, tonumber(channelTime) or 0)
        end
    end
    return meta
end

-- Keep all values from GetUnitBuffInfo that the advisor needs.  In particular,
-- stackCount is required for Bound Armaments, Grim Focus morphs, Molten Whip,
-- and other stack-builder/spender abilities.
ReadUnitEffects029169ImplArch = function(self, unitTag)
    local effects = {}
    if type(GetNumBuffs) ~= "function" or type(GetUnitBuffInfo) ~= "function" then return effects end
    if unitTag ~= "player" and type(DoesUnitExist) == "function" and safe(DoesUnitExist, false, unitTag) ~= true then
        return effects
    end

    local count = tonumber((safe(GetNumBuffs, 0, unitTag))) or 0
    local nowSeconds = 0
    if type(GetGameTimeMilliseconds) == "function" then
        nowSeconds = (tonumber((safe(GetGameTimeMilliseconds, 0))) or 0) / 1000
    elseif type(GetFrameTimeSeconds) == "function" then
        nowSeconds = tonumber((safe(GetFrameTimeSeconds, 0))) or 0
    end

    for index = 1, count do
        local ok, effectName, timeStarted, timeEnding, buffSlot, stackCount,
            iconFilename, debugBuffType, effectType, abilityType,
            statusEffectType, effectAbilityId, canClickOff, castByPlayer =
            pcall(GetUnitBuffInfo, unitTag, index)
        if ok then
            local ending = tonumber(timeEnding) or 0
            local remainingMs = 0
            if ending > 0 then
                remainingMs = math.max(0, (ending - nowSeconds) * 1000)
            else
                remainingMs = 3600000
            end
            local id = tonumber(effectAbilityId) or 0
            effects[#effects + 1] = {
                name = tostring(effectName or ""),
                normalizedName = EAS_RA_Normalize029170(effectName),
                abilityId = id,
                buffType = self:GetAbilityBuffType029169(id),
                remaining = remainingMs,
                stacks = math.max(0, tonumber(stackCount) or 0),
                effectType = tonumber(effectType) or 0,
                abilityType = tonumber(abilityType) or 0,
                statusEffectType = tonumber(statusEffectType) or 0,
                castByPlayer = castByPlayer == true,
                canClickOff = canClickOff == true,
            }
        end
    end
    return effects
end

local EAS_GetBarAbilitiesBase029170 = GetBarAbilities029161ImplArch
GetBarAbilities029161ImplArch = function(self, category)
    local abilities = EAS_GetBarAbilitiesBase029170(self, category) or {}
    for _, ability in ipairs(abilities) do
        ability.runtime029170 = self:GetAbilityRuntimeMeta029170(ability.abilityId)
        if ability.runtime029170.duration > 0 then
            ability.abilityDuration029169 = ability.runtime029170.duration
        end
        if type(GetEffectiveAbilityIdForAbilityOnHotbar) == "function" and (tonumber(ability.abilityId) or 0) > 0 then
            local effective = EAS_RA_PCallFirst029170(GetEffectiveAbilityIdForAbilityOnHotbar, ability.abilityId, category)
            ability.effectiveAbilityId029170 = tonumber(effective) or 0
        else
            ability.effectiveAbilityId029170 = 0
        end
    end
    return abilities
end

local function EAS_RA_SpecialFamily029170(a)
    local name = EAS_RA_Normalize029170(a and a.name or "")
    local text = EAS_RA_Normalize029170((a and a.name or "") .. " " .. (a and a.description or ""))
    local family = { kind = nil, stackThreshold = 0, aliases = {} }

    if tableHasText(name, {"daedric prey", "haunting curse", "daedric curse"}) then
        family.kind = "TARGET_MAINTENANCE"
        family.aliases = {"daedric prey", "haunting curse", "daedric curse"}
    elseif contains(name, "bound armaments") then
        family.kind = "STACK_SPENDER"
        family.stackThreshold = 4
        family.aliases = {"bound armaments", "bound weapon"}
    elseif tableHasText(name, {"merciless resolve", "relentless focus", "grim focus"}) then
        family.kind = "STACK_SPENDER"
        family.stackThreshold = 5
        family.aliases = {"merciless resolve", "relentless focus", "grim focus", "assassin's will", "assassin's scourge"}
    elseif contains(name, "molten whip") then
        family.kind = "STACK_SPENDER"
        family.stackThreshold = 3
        family.aliases = {"molten whip", "seething fury"}
    elseif tableHasText(name, {"camouflaged hunter", "expert hunter", "inner light", "magelight"}) then
        family.kind = "REVEAL_UTILITY"
        family.aliases = {name}
    elseif tableHasText(name, {"flawless dawnbreaker", "dawnbreaker of smiting", "dawnbreaker"}) then
        family.kind = "DAMAGE_ULTIMATE"
    end

    if family.kind == nil then
        local threshold = tonumber(text:match("(%d+)%s+stacks"))
            or tonumber(text:match("reach%s+(%d+)"))
            or tonumber(text:match("after%s+(%d+)%s+light"))
        if threshold and threshold >= 2 and threshold <= 10
            and tableHasText(text, {"stack", "light attack", "heavy attack", "consume"}) then
            family.kind = "STACK_SPENDER"
            family.stackThreshold = threshold
            family.aliases = {name}
        end
    end
    return family
end

function R:GetAbilityEffectState029170(a, cls)
    local snapshot = self.smartEffects029169
    if type(snapshot) ~= "table" or ((now() - (tonumber(snapshot.at) or 0)) > 250) then
        snapshot = self:RefreshSmartEffectSnapshots029169()
    end

    local family = EAS_RA_SpecialFamily029170(a)
    local abilityId = tonumber(a and a.abilityId) or 0
    local effectiveId = tonumber(a and a.effectiveAbilityId029170) or 0
    local abilityName = EAS_RA_Normalize029170(a and a.name or "")
    local bestRemaining = math.max(0, tonumber(a and a.effect) or 0)
    local bestStacks = 0

    local aliases = {}
    for _, alias in ipairs(family.aliases or {}) do aliases[#aliases + 1] = EAS_RA_Normalize029170(alias) end
    if abilityName ~= "" then aliases[#aliases + 1] = abilityName end

    local function related(effectName)
        if effectName == "" then return false end
        for _, alias in ipairs(aliases) do
            if alias ~= "" then
                if effectName == alias then return true end
                if #alias >= 6 and #effectName >= 6
                    and (effectName:find(alias, 1, true) or alias:find(effectName, 1, true)) then
                    return true
                end
            end
        end
        return false
    end

    local function scan(list, hostile)
        for _, effect in ipairs(list or {}) do
            local effectId = tonumber(effect.abilityId) or 0
            local idMatch = (abilityId > 0 and effectId == abilityId)
                or (effectiveId > 0 and effectId == effectiveId)
            local nameMatch = related(effect.normalizedName or EAS_RA_Normalize029170(effect.name))
            local sourceAllowed = not hostile or effect.castByPlayer or idMatch or nameMatch
            if sourceAllowed and (idMatch or nameMatch) then
                bestRemaining = math.max(bestRemaining, tonumber(effect.remaining) or 0)
                bestStacks = math.max(bestStacks, tonumber(effect.stacks) or 0)
            end
        end
    end

    -- Special target-maintenance abilities live on the enemy even if their
    -- generic tooltip parser also sees self-buff wording.
    if family.kind == "TARGET_MAINTENANCE" then
        scan(snapshot.target, true)
    else
        if cls and (cls.buff or cls.defensive or cls.shield or cls.resource or cls.hot
            or cls.stackSpender or cls.pet or cls.passiveSlotBuff) then
            scan(snapshot.player, false)
        end
        if cls and (cls.debuff or cls.dot) then scan(snapshot.target, true) end
    end

    -- Some stack effects use a related but not identical effect name. Search
    -- explicit aliases across all player effects even when the generic class
    -- did not recognize the ability as a buff.
    if family.kind == "STACK_SPENDER" then scan(snapshot.player, false) end

    return {
        family = family,
        remaining = bestRemaining,
        stacks = bestStacks,
        stackThreshold = tonumber(family.stackThreshold) or 0,
    }
end

local EAS_ClassifyAbilityBase029170 = ClassifyAbility029161ImplArch
ClassifyAbility029161ImplArch = function(self, a)
    local c = EAS_ClassifyAbilityBase029170(self, a)
    local runtime = a and a.runtime029170 or self:GetAbilityRuntimeMeta029170(a and a.abilityId)
    local text = EAS_RA_Normalize029170((a and a.name or "") .. " " .. (a and a.description or ""))
    local family = EAS_RA_SpecialFamily029170(a)

    -- ESO's own metadata wins over text guesses wherever available.
    if runtime.passiveKnown then c.passiveOnly = runtime.isPassive == true end
    if runtime.damageRole then c.damage = true end
    if runtime.healerRole then c.heal = true end
    if runtime.tankRole then c.defensive = true end
    c.channeled = runtime.channeled == true
    c.castTime = tonumber(runtime.castTime) or 0
    c.channelTime = tonumber(runtime.channelTime) or 0
    c.targetDescription029170 = runtime.target
    c.resourceMechanic029170 = runtime.mechanic

    c.passiveSlotBuff = c.passiveSlotBuff == true
        or tableHasText(text, {"while slotted", "while this ability is slotted"})
    c.revealUtility = family.kind == "REVEAL_UTILITY"
        or tableHasText(text, {"reveal", "reveals", "stealthed", "invisible enemies", "hidden enemies"})
    c.stackSpender = family.kind == "STACK_SPENDER"
    c.stackThreshold = tonumber(family.stackThreshold) or 0
    c.targetMaintenance = family.kind == "TARGET_MAINTENANCE"
    c.damageUltimate = family.kind == "DAMAGE_ULTIMATE"

    -- An active skill that also grants a while-slotted passive is still an
    -- active skill.  Camouflaged Hunter/Inner Light style abilities must not be
    -- removed from consideration simply because part of their tooltip is
    -- passive. Only IsAbilityPassive() may make it truly passive-only.
    if runtime.passiveKnown and runtime.isPassive ~= true then c.passiveOnly = false end

    -- "While slotted" bonuses are not maintenance timers. Do not spam-cast
    -- them unless the active half has an actual duration/role or a situational
    -- reason (for example reveal utility or a stack spender).
    c.maintenanceBuff = c.buff == true
        and not c.isUltimate
        and not c.stackSpender
        and not c.revealUtility
        and (not c.passiveSlotBuff or (tonumber(runtime.duration) or 0) > 0)

    -- API role metadata can identify damaging abilities even when localized
    -- tooltip wording does not match our English text fallback.
    if c.damage and not c.dot and not c.execute and not c.debuff and not c.isUltimate
        and not c.maintenanceBuff and not c.stackSpender then
        c.spammable = true
    end
    if c.stackSpender or c.revealUtility then c.spammable = false end
    return c
end

IsUltimateReady029161ImplArch = function(self, a)
    if not a or not a.isUltimate or COMBAT_MECHANIC_FLAGS_ULTIMATE == nil then return false end
    local current = tonumber((safe(GetUnitPower, 0, "player", COMBAT_MECHANIC_FLAGS_ULTIMATE))) or 0
    local cost = tonumber(a.cost) or 0
    local abilityId = tonumber(a.abilityId) or 0

    if cost <= 0 and abilityId > 0 and type(GetAbilityCost) == "function" then
        local value = EAS_RA_PCallFirst029170(GetAbilityCost, abilityId, COMBAT_MECHANIC_FLAGS_ULTIMATE, nil, "player")
        if value == nil then value = EAS_RA_PCallFirst029170(GetAbilityCost, abilityId, COMBAT_MECHANIC_FLAGS_ULTIMATE) end
        cost = math.max(0, tonumber(value) or 0)
    end
    if cost <= 0 and a.runtime029170 and tonumber(a.runtime029170.baseCost) then
        local mechanic = a.runtime029170.mechanic
        if mechanic == COMBAT_MECHANIC_FLAGS_ULTIMATE then cost = tonumber(a.runtime029170.baseCost) or 0 end
    end

    -- Active-bar IsSlotUsable is a useful final fallback for unusual/toggled
    -- Ultimates whose cost API intentionally reports zero.
    if cost <= 0 then
        return a.activeBar == true and a.usable == true and current > 0
    end
    return current >= cost
end

function R:IsReticleTargetHidden029170()
    if type(DoesUnitExist) == "function" and safe(DoesUnitExist, false, "reticleover") ~= true then return false end
    if type(IsUnitStealthed) == "function" then
        local result = EAS_RA_PCallFirst029170(IsUnitStealthed, "reticleover")
        if result ~= nil then return result == true end
    end
    return false
end

ScoreSmartAbility029161ImplArch = function(self, a, context)
    if not a or not context or not a.used or tostring(a.name or "") == "" then return -1000, "Unavailable" end
    if not a.usable then return -600, "Not usable" end
    if a.remain > 0 and a.duration > 0 and not a.global then return -500, "Cooldown" end

    local cls = self:ClassifyAbility029161(a)
    if cls.passiveOnly then return -80, "Passive skill" end

    local state = self:GetAbilityEffectState029170(a, cls)
    local remaining = math.max(tonumber(state.remaining) or 0, tonumber(a.effect) or 0)
    local active = remaining > 1500
    local ending = remaining > 0 and remaining <= 1500
    local missing = remaining <= 0
    local role = context.role
    local name = lower(a.name)

    -- Known instant procs/spenders always beat routine maintenance.
    if context.crystalProc and (contains(name, "crystal fragments") or contains(name, "crystal shard")) then
        return 1220, "PROC READY"
    end

    if cls.stackSpender then
        local threshold = math.max(1, tonumber(state.stackThreshold) or tonumber(cls.stackThreshold) or 1)
        local stacks = tonumber(state.stacks) or 0
        if stacks >= threshold then
            return 1120, string.format("STACKS READY %d/%d", stacks, threshold)
        elseif stacks > 0 then
            return 330, string.format("Build stacks %d/%d", stacks, threshold)
        end
        return 175, "Build stacks"
    end

    if cls.revealUtility then
        if self:IsReticleTargetHidden029170() then return 1110, "REVEAL TARGET" end
        -- Keep the active skill legal/visible to the engine, but don't waste a
        -- PvE GCD recasting a reveal skill just for its while-slotted passive.
        return 165, "Passive bonus / reveal utility"
    end

    if role == "TANK" then
        if cls.taunt then
            if not active or ending then return 1140, "TAUNT / refresh aggro" end
            return 280, "Taunt active"
        end
        if context.playerHP <= 45 and (cls.heal or cls.defensive or cls.shield) then return 1080, "Survive / stabilize" end
        if cls.maintenanceBuff and (missing or ending) then return 1005, "Defensive/support buff" end
        if cls.debuff and (missing or ending) then return 930, "Group debuff" end
        if context.staminaPct <= 30 and cls.resource then return 900, "Restore sustain" end
        if cls.heal and context.playerHP <= 70 then return 860, "Self heal" end
        if cls.isUltimate and self:IsUltimateReady029161(a) then return 820, "Tank Ultimate ready" end
        if cls.dot and (missing or ending) then return 650, "Refresh damage" end
        if cls.damage then return 430, "Damage while stable" end
        return 120, "Utility"
    end

    if role == "HEALER" then
        if context.groupHP <= 35 and cls.heal and not cls.hot then return 1180, "EMERGENCY HEAL" end
        if context.groupHP <= 55 and cls.heal then return 1100, cls.hot and "Emergency HoT" or "Burst heal" end
        if cls.hot and (missing or ending) then return 1030, "Refresh HoT" end
        if cls.maintenanceBuff and (missing or ending) then return 995, "Refresh group/self buff" end
        if cls.debuff and (missing or ending) then return 950, "Refresh debuff" end
        if context.groupHP <= 75 and cls.heal then return 920, "Heal group" end
        if context.magickaPct <= 30 and cls.resource then return 900, "Restore sustain" end
        if cls.isUltimate and self:IsUltimateReady029161(a) then return 870, "Support Ultimate ready" end
        if cls.dot and (missing or ending) then return 610, "Damage while stable" end
        if cls.damage then return 470, "Damage while stable" end
        return 120, "Utility"
    end

    -- DPS / hybrid priorities.
    if context.playerHP <= 35 and (cls.heal or cls.shield or cls.defensive) then return 1150, "Defend / heal" end
    if cls.execute and context.targetHP > 0 and context.targetHP <= 25 then return 1090, "EXECUTE" end

    -- Delayed burst/debuff families such as Daedric Prey and Haunting Curse
    -- need to be reapplied as part of the damage rotation, not buried beneath
    -- generic direct attacks.
    if cls.targetMaintenance then
        if missing or ending then return 1050, active and "Refresh target effect" or "Apply target effect" end
        return 300, "Target effect active"
    end

    if cls.maintenanceBuff and (missing or ending) then return 1020, ending and "Refresh damage buff" or "Apply damage buff" end
    if cls.debuff and (missing or ending) then return 990, "Refresh debuff" end
    if cls.dot and (missing or ending) then return 970, "Refresh DoT" end

    -- A ready damaging Ultimate should actually enter the rotation.  It sits
    -- below missing core upkeep but above ordinary spammables/direct attacks.
    if cls.isUltimate and self:IsUltimateReady029161(a) and context.inCombat then
        if cls.damageUltimate or cls.damage or (a.runtime029170 and a.runtime029170.damageRole) then
            return 955, "DPS Ultimate ready"
        end
        return 900, "Ultimate ready"
    end

    if role == "MAGICKA_DPS" and context.magickaPct <= 20 and cls.resource then return 900, "Restore Magicka" end
    if role == "STAMINA_DPS" and context.staminaPct <= 20 and cls.resource then return 900, "Restore Stamina" end
    if role == "HYBRID" and math.min(context.magickaPct, context.staminaPct) <= 18 and cls.resource then return 890, "Restore resources" end

    -- Pet active abilities can be real damage/heal buttons after the pet is
    -- summoned. Treat their castable activation like any other timed action.
    if cls.pet and cls.damage and (missing or ending) then return 930, "Pet ability" end
    if cls.interrupt then return 660, "Interrupt-capable attack" end
    if cls.channeled and cls.damage then return 645, "Channel damage" end
    if cls.spammable then return 630, "Spammable" end
    if cls.damage then return 590, "Damage" end
    if cls.heal or cls.defensive or cls.shield then return 260, "Defensive option" end

    -- Every real active skill remains known to the engine. This avoids the old
    -- behavior where unrecognized active skills silently vanished from the
    -- recommendation pool.
    return 150, "Situational utility"
end

BuildRecommendationsImplArch = function(self)
    local role = self:GetAdvisorRole029161()
    local magickaPct = self:GetResourcePct029161(POWERTYPE_MAGICKA)
    local staminaPct = self:GetResourcePct029161(POWERTYPE_STAMINA)
    local context = {
        role = role,
        targetHP = self:GetTargetHealth(),
        playerHP = self:GetPlayerHealthPct029161(),
        groupHP = self:GetLowestGroupHealthPct029161(),
        magickaPct = magickaPct,
        staminaPct = staminaPct,
        crystalProc = self:HasCrystalProc(),
        inCombat = safe(IsUnitInCombat, false, "player") == true,
        targetExists = safe(DoesUnitExist, false, "reticleover") == true,
    }

    local snapshot = self.smartEffects029169
    if type(snapshot) ~= "table" or (now() - (tonumber(snapshot.at) or 0)) >= 200 then
        self:RefreshSmartEffectSnapshots029169()
    end

    local scored = {}
    for _, ability in ipairs(self:GetAllBarAbilities029161()) do
        local score, reason = self:ScoreSmartAbility029161(ability, context)
        if not ability.activeBar and score > 0 then score = score - 45 end
        scored[#scored + 1] = { a = ability, score = score, reason = reason, needsSwap = not ability.activeBar }
    end
    table.sort(scored, function(x, y)
        if x.score == y.score then return (x.a.activeBar and 1 or 0) > (y.a.activeBar and 1 or 0) end
        return x.score > y.score
    end)

    local result, seenAbility = {}, {}
    for _, entry in ipairs(scored) do
        local key = (tonumber(entry.a.abilityId) or 0) > 0 and tostring(entry.a.abilityId)
            or (entry.a.name .. ":" .. tostring(entry.a.category))
        if entry.score > 0 and not seenAbility[key] then
            result[#result + 1] = entry
            seenAbility[key] = true
            if #result >= 3 then break end
        end
    end
    self.lastSmartContext029161 = context
    return result, context.targetHP, context.crystalProc, context
end

-- ============================================================================
-- v0.29.171 - Moment-to-moment priority engine.
-- The advisor now treats every refresh as a "best next button right now"
-- decision instead of rotating through broad categories.  It tracks the last
-- skill the player actually pressed so client-side effect latency cannot cause
-- the same maintenance skill to be recommended twice before ESO reports the
-- new buff/debuff state.
-- ============================================================================

local function EAS_RA_Clamp029171(value, lowValue, highValue)
    value = tonumber(value) or 0
    if value < lowValue then return lowValue end
    if value > highValue then return highValue end
    return value
end

local function EAS_RA_EffectUrgency029171(remainingMs, durationMs, refreshFloorMs)
    local remaining = math.max(0, tonumber(remainingMs) or 0)
    local duration = math.max(0, tonumber(durationMs) or 0)
    local refreshWindow = math.max(1200, tonumber(refreshFloorMs) or 2200)
    if duration > 0 then
        -- Refresh at roughly the final 15% of long effects, but never require
        -- a razor-thin timing window that a 100 ms advisor tick could miss.
        refreshWindow = math.max(refreshWindow, math.min(4200, duration * 0.15))
    end
    if remaining <= 0 then return 1.0, true, false end
    if remaining <= refreshWindow then
        return EAS_RA_Clamp029171((refreshWindow - remaining) / refreshWindow, 0, 1), false, true
    end
    return 0, false, false
end

local RegisterMomentToMomentEvents029171ImplArch

function R:RegisterMomentToMomentEvents029171(...)

    return RegisterMomentToMomentEvents029171ImplArch(self, ...)

end

RegisterMomentToMomentEvents029171ImplArch = function(self)
    if self.momentEventsRegistered029171 then return end
    self.momentEventsRegistered029171 = true
    self.lastUsedAbility029171 = self.lastUsedAbility029171 or {}
    self.lastUsedName029171 = self.lastUsedName029171 or {}

    local prefix = (EPC.name or "ESOAdventurerSuite") .. "_SmartMoment029171"
    if EVENT_ACTION_SLOT_ABILITY_USED then
        EPC.Runtime:RegisterEvent("RotationAssistant","Used",EVENT_ACTION_SLOT_ABILITY_USED, function(_, slotNum)
            local slot = tonumber(slotNum) or 0
            local category = safe(GetActiveHotbarCategory, nil)
            local abilityId = 0
            if type(GetSlotBoundId) == "function" then
                abilityId = tonumber((safe(GetSlotBoundId, 0, slot, category))) or 0
                if abilityId <= 0 then abilityId = tonumber((safe(GetSlotBoundId, 0, slot))) or 0 end
            end
            local abilityName = tostring(safe(GetSlotName, "", slot, category) or "")
            local stamp = now()
            self.lastActionAt029171 = stamp
            self.lastActionSlot029171 = slot
            if abilityId > 0 then self.lastUsedAbility029171[abilityId] = stamp end
            if abilityName ~= "" then self.lastUsedName029171[EAS_RA_Normalize029170(abilityName)] = stamp end
            self.lastActionAbilityId029171 = abilityId
            self.lastActionName029171 = abilityName
            -- Refresh immediately so the highlight moves away from the button
            -- the player just pressed instead of waiting for the next 100 ms tick.
            zo_callLater(function()
                if EPC and EPC.RotationAssistant then EPC.RotationAssistant:Refresh() end
            end, 0)
        end)
    end

    if EVENT_ACTIVE_WEAPON_PAIR_CHANGED then
        EPC.Runtime:RegisterEvent("RotationAssistant","ProcBar",EVENT_ACTIVE_WEAPON_PAIR_CHANGED, function()
            self.lastBarSwapAt029171 = now()
        end)
    end
end

function R:GetRecentUsePenalty029171(a, state, cls)
    local abilityId = tonumber(a and a.abilityId) or 0
    local effectiveId = tonumber(a and a.effectiveAbilityId029170) or 0
    local normalizedName = EAS_RA_Normalize029170(a and a.name or "")
    local stamp = 0
    if abilityId > 0 then stamp = math.max(stamp, tonumber(self.lastUsedAbility029171 and self.lastUsedAbility029171[abilityId]) or 0) end
    if effectiveId > 0 then stamp = math.max(stamp, tonumber(self.lastUsedAbility029171 and self.lastUsedAbility029171[effectiveId]) or 0) end
    if normalizedName ~= "" then stamp = math.max(stamp, tonumber(self.lastUsedName029171 and self.lastUsedName029171[normalizedName]) or 0) end
    if stamp <= 0 then return 0 end

    local age = now() - stamp
    if age < 0 then return 0 end
    -- One hard GCD-style lock.  Even a spammable should not remain highlighted
    -- on the same frame immediately after it was pressed.
    if age <= 520 then return -2200 end

    -- Maintenance effects sometimes take a few hundred milliseconds to appear
    -- in GetUnitBuffInfo/GetActionSlotEffectTimeRemaining. Hold them down a bit
    -- longer so the engine does not double-cast a buff/DoT because of API lag.
    if age <= 1150 and cls and (cls.maintenanceBuff or cls.dot or cls.debuff or cls.targetMaintenance or cls.hot or cls.pet) then
        local remaining = tonumber(state and state.remaining) or 0
        if remaining <= 0 then return -950 end
    end
    return 0
end

function R:GetAbilityPriorityDuration029171(a)
    local runtime = a and a.runtime029170
    local duration = tonumber(a and a.abilityDuration029169) or 0
    if duration <= 0 and runtime then duration = tonumber(runtime.duration) or 0 end
    if duration <= 0 then duration = tonumber(a and a.duration) or 0 end
    return math.max(0, duration)
end

function R:ScoreBestNextAction029171(a, context)
    if not a or not context or not a.used or tostring(a.name or "") == "" then return -10000, "Unavailable" end
    if a.usable == false then return -8000, "Not usable" end
    if (tonumber(a.remain) or 0) > 0 and (tonumber(a.duration) or 0) > 0 and a.global ~= true then return -7000, "Cooldown" end

    local cls = self:ClassifyAbility029161(a)
    if cls.passiveOnly then return -6000, "Passive skill" end

    local state = self:GetAbilityEffectState029170(a, cls)
    local remaining = math.max(tonumber(state.remaining) or 0, tonumber(a.effect) or 0)
    local expectedDuration = self:GetAbilityPriorityDuration029171(a)
    local urgency, missing, ending = EAS_RA_EffectUrgency029171(remaining, expectedDuration, 2200)
    local role = tostring(context.role or "HYBRID")
    local name = EAS_RA_Normalize029170(a.name)
    local score, reason = 0, "Situational"

    local offensive = cls.damage or cls.dot or cls.debuff or cls.targetMaintenance or cls.execute or cls.stackSpender or cls.isUltimate
    if offensive and not context.targetExists then
        -- Do not light up attacks at empty air. Self-buffs, sustain, pets and
        -- defensive skills remain eligible without a target.
        if not cls.maintenanceBuff and not cls.resource and not cls.defensive and not cls.shield and not cls.heal and not cls.hot and not cls.pet then
            return -2500, "Need target"
        end
    end

    -- Absolute emergency actions. These intentionally outrank damage.
    if context.playerHP <= 28 and (cls.heal or cls.shield or cls.defensive) then
        score, reason = 2100, "EMERGENCY SURVIVAL"
    elseif role == "HEALER" and context.groupHP <= 30 and cls.heal and not cls.hot then
        score, reason = 2080, "EMERGENCY GROUP HEAL"
    elseif role == "TANK" and cls.taunt and (missing or ending) then
        score, reason = 2040 + math.floor(urgency * 80), missing and "TAUNT NOW" or "REFRESH TAUNT"
    elseif context.crystalProc and (contains(name, "crystal fragments") or contains(name, "crystal shard")) then
        score, reason = 1980, "PROC NOW"
    elseif cls.stackSpender then
        local threshold = math.max(1, tonumber(state.stackThreshold) or tonumber(cls.stackThreshold) or 1)
        local stacks = tonumber(state.stacks) or 0
        if stacks >= threshold then
            score, reason = 1930 + math.min(40, stacks * 4), string.format("SPEND STACKS %d/%d", stacks, threshold)
        elseif stacks > 0 then
            score, reason = 620 + stacks * 18, string.format("Building stacks %d/%d", stacks, threshold)
        else
            score, reason = 500, "Build stacks"
        end
    elseif role == "HEALER" then
        if context.groupHP <= 50 and cls.heal then
            score, reason = 1880, cls.hot and "STABILIZE WITH HOT" or "BURST HEAL"
        elseif cls.hot and (missing or ending) then
            score, reason = 1760 + math.floor(urgency * 100), missing and "APPLY HOT" or "REFRESH HOT"
        elseif cls.maintenanceBuff and (missing or ending) then
            score, reason = 1690 + math.floor(urgency * 95), missing and "APPLY SUPPORT BUFF" or "REFRESH SUPPORT BUFF"
        elseif cls.debuff and (missing or ending) then
            score, reason = 1630 + math.floor(urgency * 90), "REFRESH GROUP DEBUFF"
        elseif context.magickaPct <= 28 and cls.resource then
            score, reason = 1570 + math.floor((28 - context.magickaPct) * 5), "RESTORE MAGICKA"
        elseif context.groupHP <= 78 and cls.heal then
            score, reason = 1450, "TOP OFF GROUP"
        elseif cls.isUltimate and self:IsUltimateReady029161(a) then
            score, reason = 1380, "SUPPORT ULTIMATE"
        elseif cls.dot and (missing or ending) then
            score, reason = 1120 + math.floor(urgency * 80), "DAMAGE UPTIME"
        elseif cls.damage then
            score, reason = 760, "DAMAGE WHILE SAFE"
        else
            score, reason = 350, "UTILITY"
        end
    elseif role == "TANK" then
        if context.playerHP <= 48 and (cls.heal or cls.shield or cls.defensive) then
            score, reason = 1900, "STABILIZE"
        elseif cls.maintenanceBuff and (missing or ending) then
            score, reason = 1750 + math.floor(urgency * 95), missing and "APPLY DEFENSE" or "REFRESH DEFENSE"
        elseif cls.debuff and (missing or ending) then
            score, reason = 1680 + math.floor(urgency * 90), "MAINTAIN GROUP DEBUFF"
        elseif context.staminaPct <= 30 and cls.resource then
            score, reason = 1580 + math.floor((30 - context.staminaPct) * 5), "RESTORE STAMINA"
        elseif cls.isUltimate and self:IsUltimateReady029161(a) and context.playerHP <= 65 then
            score, reason = 1510, "DEFENSIVE ULTIMATE"
        elseif cls.dot and (missing or ending) then
            score, reason = 1100 + math.floor(urgency * 75), "MAINTAIN DAMAGE"
        elseif cls.damage then
            score, reason = 720, "DAMAGE WHILE STABLE"
        else
            score, reason = 360, "UTILITY"
        end
    else
        -- DPS / Hybrid: maintain effects only when they are due, then spend
        -- procs/stacks/Ultimate, then use the strongest available filler.
        if cls.execute and context.targetHP > 0 and context.targetHP <= 25 then
            local executeBoost = math.floor((25 - context.targetHP) * 9)
            score, reason = 1870 + executeBoost, "EXECUTE NOW"
        elseif cls.maintenanceBuff and (missing or ending) then
            score, reason = 1810 + math.floor(urgency * 115), missing and "APPLY DAMAGE BUFF" or "REFRESH DAMAGE BUFF"
        elseif cls.targetMaintenance and (missing or ending) then
            score, reason = 1780 + math.floor(urgency * 110), missing and "APPLY TARGET SETUP" or "REFRESH TARGET SETUP"
        elseif cls.debuff and (missing or ending) then
            score, reason = 1740 + math.floor(urgency * 105), missing and "APPLY DEBUFF" or "REFRESH DEBUFF"
        elseif cls.dot and (missing or ending) then
            score, reason = 1710 + math.floor(urgency * 100), missing and "APPLY DOT" or "REFRESH DOT"
        elseif cls.pet and (missing or ending) and cls.damage then
            score, reason = 1650 + math.floor(urgency * 85), "PET ACTIVE DAMAGE"
        elseif cls.isUltimate and self:IsUltimateReady029161(a) and context.inCombat and context.targetExists then
            local bossBonus = context.targetIsBoss and 130 or 0
            local healthBonus = context.targetHP >= 25 and 70 or 0
            local overkillPenalty = context.targetHP > 0 and context.targetHP <= 8 and 420 or 0
            score = 1540 + bossBonus + healthBonus - overkillPenalty
            reason = context.targetIsBoss and "BURN WITH ULTIMATE" or "ULTIMATE WINDOW"
        elseif role == "MAGICKA_DPS" and context.magickaPct <= 18 and cls.resource then
            score, reason = 1510 + math.floor((18 - context.magickaPct) * 8), "RESTORE MAGICKA"
        elseif role == "STAMINA_DPS" and context.staminaPct <= 18 and cls.resource then
            score, reason = 1510 + math.floor((18 - context.staminaPct) * 8), "RESTORE STAMINA"
        elseif role == "HYBRID" and math.min(context.magickaPct, context.staminaPct) <= 15 and cls.resource then
            score, reason = 1490, "RESTORE RESOURCES"
        elseif cls.revealUtility then
            if self:IsReticleTargetHidden029170() then
                score, reason = 1900, "REVEAL TARGET"
            else
                score, reason = 310, "SITUATIONAL REVEAL"
            end
        elseif cls.interrupt and context.interruptNow029171 then
            score, reason = 1960, "INTERRUPT NOW"
        elseif cls.spammable then
            score, reason = 920, "BEST FILLER"
        elseif cls.damage then
            score, reason = 850, cls.channeled and "CHANNEL DAMAGE" or "DIRECT DAMAGE"
        elseif cls.heal or cls.defensive or cls.shield then
            score, reason = 420, "DEFENSIVE OPTION"
        else
            score, reason = 330, "UTILITY"
        end
    end

    -- Avoid wasting expensive resource skills when nearly dry unless the skill
    -- itself is sustain/defensive/emergency.  The exact API mechanic varies by
    -- ability, so this is deliberately a mild modifier rather than a hard ban.
    local runtime = a.runtime029170
    if runtime and not cls.resource and not cls.heal and not cls.defensive and not cls.shield then
        local mechanic = runtime.mechanic
        if mechanic == POWERTYPE_MAGICKA or mechanic == COMBAT_MECHANIC_FLAGS_MAGICKA then
            if context.magickaPct <= 12 then score = score - 260 end
        elseif mechanic == POWERTYPE_STAMINA or mechanic == COMBAT_MECHANIC_FLAGS_STAMINA then
            if context.staminaPct <= 12 then score = score - 260 end
        end
    end

    score = score + self:GetRecentUsePenalty029171(a, state, cls)
    return score, reason
end

-- Replace the previous scoring entry point so all existing UI/highlight code
-- automatically receives the new moment-to-moment priority values.
ScoreSmartAbility029161ImplArch = function(self, a, context)
    return self:ScoreBestNextAction029171(a, context)
end

BuildRecommendationsImplArch = function(self)
    local role = self:GetAdvisorRole029161()
    local magickaPct = self:GetResourcePct029161(POWERTYPE_MAGICKA)
    local staminaPct = self:GetResourcePct029161(POWERTYPE_STAMINA)
    local context = {
        role = role,
        targetHP = self:GetTargetHealth(),
        playerHP = self:GetPlayerHealthPct029161(),
        groupHP = self:GetLowestGroupHealthPct029161(),
        magickaPct = magickaPct,
        staminaPct = staminaPct,
        crystalProc = self:HasCrystalProc(),
        inCombat = safe(IsUnitInCombat, false, "player") == true,
        targetExists = safe(DoesUnitExist, false, "reticleover") == true,
        targetIsBoss = type(IsUnitBoss) == "function" and safe(IsUnitBoss, false, "reticleover") == true or false,
        interruptNow029171 = now() < (tonumber(self.interruptWarningUntil029171) or 0),
    }

    local snapshot = self.smartEffects029169
    if type(snapshot) ~= "table" or (now() - (tonumber(snapshot.at) or 0)) >= 150 then
        self:RefreshSmartEffectSnapshots029169()
    end

    local scored = {}
    local recentSwap = (now() - (tonumber(self.lastBarSwapAt029171) or 0)) < 650
    for _, ability in ipairs(self:GetAllBarAbilities029161()) do
        local score, reason = self:ScoreBestNextAction029171(ability, context)
        local needsSwap = not ability.activeBar
        if needsSwap and score > 0 then
            -- A bar swap costs time. Only pay it when the off-bar action is
            -- genuinely better than the current-bar choices. The penalty is
            -- temporarily larger immediately after a swap to prevent ping-pong.
            score = score - (recentSwap and 210 or 55)
        end
        scored[#scored + 1] = { a = ability, score = score, reason = reason, needsSwap = needsSwap }
    end

    table.sort(scored, function(x, y)
        if x.score == y.score then
            if x.a.activeBar ~= y.a.activeBar then return x.a.activeBar == true end
            return (tonumber(x.a.ordinal) or 99) < (tonumber(y.a.ordinal) or 99)
        end
        return x.score > y.score
    end)

    local result, seenAbility = {}, {}
    for _, entry in ipairs(scored) do
        local key = (tonumber(entry.a.abilityId) or 0) > 0 and tostring(entry.a.abilityId)
            or (tostring(entry.a.name or "") .. ":" .. tostring(entry.a.category))
        if entry.score > 0 and not seenAbility[key] then
            result[#result + 1] = entry
            seenAbility[key] = true
            if #result >= 3 then break end
        end
    end

    self.lastSmartContext029161 = context
    self.lastDecision029171 = result[1]
    return result, context.targetHP, context.crystalProc, context
end

local EAS_RA_InitializeBase029171 = InitializeImplArch
InitializeImplArch = function(self)
    -- v0.29.196: retire the large advisor card as the out-of-box experience.
    -- Existing FULL/COMPACT installs move once to action-bar highlighting;
    -- players can still explicitly select Full Overlay or Compact afterward.
    if EPC.saved and EPC.saved.rotationAdvisorHighlightDefaultMigrated029196 ~= true then
        local mode = string.upper(tostring(EPC.saved.rotationAssistantDisplayMode029161 or "HIGHLIGHT"))
        if mode == "FULL" or mode == "COMPACT" then
            EPC.saved.rotationAssistantDisplayMode029161 = "HIGHLIGHT"
        end
        EPC.saved.rotationAdvisorHighlightDefaultMigrated029196 = true
    end

    EAS_RA_InitializeBase029171(self)
    self:RegisterMomentToMomentEvents029171()
end


-- ============================================================================
-- v0.29.365 - hold advisor recommendation through cast/channel completion.
-- ============================================================================
local EAS_BuildRecommendationsBase029365= BuildRecommendationsImplArch
BuildRecommendationsImplArch = function(self)
    local t=now()
    if (tonumber(self.advisorCastLockUntil029365) or 0)>t and type(self.advisorLockedRecommendations029365)=="table" then
        local c=self.advisorLockedContext029365 or self.lastSmartContext029161 or {}
        return self.advisorLockedRecommendations029365, tonumber(c.targetHP) or self:GetTargetHealth(), c.crystalProc==true, c
    end
    local a,b,c,d=EAS_BuildRecommendationsBase029365(self)
    self.advisorLockedRecommendations029365=a
    self.advisorLockedContext029365=d
    return a,b,c,d
end
local EAS_RegisterMomentBase029365= RegisterMomentToMomentEvents029171ImplArch
RegisterMomentToMomentEvents029171ImplArch = function(self)
    if self.castLockEventInstalled029365 then return EAS_RegisterMomentBase029365(self) end
    EAS_RegisterMomentBase029365(self)
    self.castLockEventInstalled029365=true
    local prefix=(EPC.name or "ESOAdventurerSuite").."_CastLock029365"
    if EVENT_ACTION_SLOT_ABILITY_USED then
        EPC.Runtime:RegisterEvent("RotationAssistant","AbilityUsedFinal",EVENT_ACTION_SLOT_ABILITY_USED,function(_,slotNum)
            local slot=tonumber(slotNum) or 0; local category=safe(GetActiveHotbarCategory,nil)
            local abilityId=tonumber(safe(GetSlotBoundId,0,slot,category)) or 0
            if abilityId<=0 or type(self.GetAbilityRuntimeMeta029170)~="function" then return end
            local meta=self:GetAbilityRuntimeMeta029170(abilityId) or {}
            local cast=tonumber(meta.castTime) or 0; local channel=tonumber(meta.channelTime) or 0
            local duration=math.max(cast,channel)
            if duration>100 then
                -- Runtime metadata is milliseconds in ESO. Snapshot the current
                -- recommendation before the older "ability used" listener can
                -- advance it, then keep returning that snapshot until completion.
                self.advisorCastLockUntil029365=now()+duration+60
                if type(self.advisorLockedRecommendations029365)~="table" then
                    local recs,_,_,ctx=EAS_BuildRecommendationsBase029365(self); self.advisorLockedRecommendations029365=recs; self.advisorLockedContext029365=ctx
                end
                zo_callLater(function() if EPC and EPC.RotationAssistant then EPC.RotationAssistant.advisorCastLockUntil029365=0; EPC.RotationAssistant:Refresh() end end,duration+70)
            end
        end)
    end
end

