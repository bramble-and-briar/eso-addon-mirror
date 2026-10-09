--------------------------------------------------------------------------------
-- GLOBAL TABLE
--------------------------------------------------------------------------------
Meterskull = {
    name     = "Meterskull",
    version  = "1.6.1",
    modules  = {},
    db       = {},
    defaults = {},
}

-- Shortcut references
local MS = Meterskull
local EM = EVENT_MANAGER
local SM = SCENE_MANAGER

-- Debug function fallback
local function DebugLog(msg)
    if d then
        d(msg)
    else
        if CHAT_ROUTER then
            CHAT_ROUTER:AddSystemMessage(msg)
        end
    end
end

--------------------------------------------------------------------------------
-- REQUIREMENTS
--------------------------------------------------------------------------------
local LAM2 = LibAddonMenu2


local function InitializeMeterskullUI()
    if not _G.MeterskullUILayoutConfig then
        DebugLog("Meterskull ERROR: UILayoutConfig not available")
        return
    end
    if not _G.Meterskull_InitializeUI then
        DebugLog("Meterskull ERROR: UI initializer not available")
        return
    end
    _G.Meterskull_InitializeUI(MS)
end

--------------------------------------------------------------------------------
-- DEFAULT SETTINGS
--------------------------------------------------------------------------------
local defaults = {
    sharedSettings = {
        accountWideSettings  = true,
        uiLocked             = false,
        combatOnly           = false,
        renderTick           = 1000,   -- ms
        showArmorskull       = true,
        showHybridarmorskull = false,
        showPowerskull       = true,
        showCritskull        = true,
        showCritresiskull    = false,
        showPenskull         = true,
        showHealthskull      = false,
        showMagskull         = false,
        showStamskull        = false,
        animationDuration    = "standard",
    },
    armorskull = {
        location = { x = 100, y = 100 },
        settings = {
            customScale     = 20,
            backgroundColor = { 0, 0, 0, 0.8 },
            borderOpacity   = 50,
            textOpacity     = 100,
            levels = {
                physical = {
                    { color = { 1, 1, 1, 1 }, level = 0 },
                    { color = { 1, 1, 1, 1 }, level = 0 },
                    { color = { 1, 1, 1, 1 }, level = 0 },
                },
                spell = {
                    { color = { 1, 1, 1, 1 }, level = 0 },
                    { color = { 1, 1, 1, 1 }, level = 0 },
                    { color = { 1, 1, 1, 1 }, level = 0 },
                },
            },
        },
    },
    hybridarmorskull = {
        location = { x = 100, y = 200 },
        settings = {
            customScale     = 20,
            backgroundColor = { 0, 0, 0, 0.8 },
            borderOpacity   = 50,
            textOpacity     = 100,
            levels = {
                lowestResist = {
                    { color = { 1, 1, 1, 1 }, level = 0 },
                    { color = { 1, 1, 1, 1 }, level = 0 },
                    { color = { 1, 1, 1, 1 }, level = 0 },
                },
            },
        },
    },
    powerskull = {
        location = { x = 100, y = 300 },
        settings = {
            customScale     = 20,
            backgroundColor = { 0, 0, 0, 0.8 },
            borderOpacity   = 50,
            textOpacity     = 100,
            levels = {
                power = {
                    { color = { 1, 1, 1, 1 }, level = 0 },
                    { color = { 1, 1, 1, 1 }, level = 0 },
                    { color = { 1, 1, 1, 1 }, level = 0 },
                },
            },
        },
    },
    critskull = {
        location = { x = 100, y = 400 },
        settings = {
            customScale     = 20,
            backgroundColor = { 0, 0, 0, 0.8 },
            borderOpacity   = 50,
            textOpacity     = 100,
            levels = {
                critChance = {
                    { color = { 1, 1, 1, 1 }, level = 0 },
                    { color = { 1, 1, 1, 1 }, level = 0 },
                    { color = { 1, 1, 1, 1 }, level = 0 },
                },
                critDamage = {
                    { color = { 1, 1, 1, 1 }, level = 0 },
                    { color = { 1, 1, 1, 1 }, level = 0 },
                    { color = { 0, 1, 0, 1 }, level = 125 },
                },
            },
        },
    },
    critresiskull = {
        location = { x = 400, y = 400 },
        settings = {
            customScale     = 20,
            backgroundColor = { 0, 0, 0, 0.8 },
            borderOpacity   = 50,
            textOpacity     = 100,
            levels = {
                critResist = {
                    { color = { 1, 1, 1, 1 }, level = 0 },
                    { color = { 1, 1, 1, 1 }, level = 0 },
                    { color = { 1, 1, 1, 1 }, level = 0 },
                },
            },
        },
    },
    penskull = {
        location = { x = 100, y = 500 },
        settings = {
            customScale     = 20,
            backgroundColor = { 0, 0, 0, 0.8 },
            borderOpacity   = 50,
            textOpacity     = 100,
            levels = {
                penetration = {
                    { color = { 1, 1, 1, 1 }, level = 0 },
                    { color = { 0, 1, 0, 1 }, level = 18200 },
                    { color = { 1, 1, 1, 1 }, level = 0 },
                },
            },
        },
    },
    healthskull = {
        location = { x = 400, y = 100 },
        settings = {
            customScale     = 20,
            backgroundColor = { 0, 0, 0, 0.8 },
            borderOpacity   = 50,
            textOpacity     = 100,
            levels = {
                recovery = {
                    { color = { 1, 1, 1, 1 }, level = 0 },
                    { color = { 1, 1, 1, 1 }, level = 0 },
                    { color = { 1, 1, 1, 1 }, level = 0 },
                },
            },
        },
    },
    magskull = {
        location = { x = 400, y = 200 },
        settings = {
            customScale     = 20,
            backgroundColor = { 0, 0, 0, 0.8 },
            borderOpacity   = 50,
            textOpacity     = 100,
            levels = {
                recovery = {
                    { color = { 1, 1, 1, 1 }, level = 0 },
                    { color = { 1, 1, 1, 1 }, level = 0 },
                    { color = { 1, 1, 1, 1 }, level = 0 },
                },
            },
        },
    },
    stamskull = {
        location = { x = 400, y = 300 },
        settings = {
            customScale     = 20,
            backgroundColor = { 0, 0, 0, 0.8 },
            borderOpacity   = 50,
            textOpacity     = 100,
            levels = {
                recovery = {
                    { color = { 1, 1, 1, 1 }, level = 0 },
                    { color = { 1, 1, 1, 1 }, level = 0 },
                    { color = { 1, 1, 1, 1 }, level = 0 },
                },
            },
        },
    },
}
MS.defaults = defaults

--------------------------------------------------------------------------------
-- ANIMATION UTILS
--------------------------------------------------------------------------------
local animationDurations = {
    off      = 0,
    fast     = 150,
    standard = 300,
    slow     = 450,
}

-- Frame update intervals based on chosen duration (optimization)
local frameIntervals = {
    fast     = 8,   -- ~120fps
    standard = 16,  -- ~60fps
    slow     = 33,  -- ~30fps
    off      = 0,
}

local function EaseOutExpo(t, b, c, d)
    return c * (-math.pow(2, -10 * t / d) + 1) + b
end

function MS.AnimateTextTransition(control, startValue, endValue, formatString, animationType)
    formatString = formatString or "%.0f"
    startValue = startValue or 0
    endValue = endValue or 0

    local animName  = control:GetName() .. "Animation"
    local startTime = GetFrameTimeMilliseconds()

    -- Use unified setting; fallback to "standard" if missing/invalid
    local animDurationSetting = MS.db.sharedSettings.animationDuration
    local duration = animationDurations[animDurationSetting] or animationDurations.standard
    local tick     = frameIntervals[animDurationSetting] or frameIntervals.standard

    local endTime    = startTime + duration
    local initialVal = startValue

    local function OnUpdate()
        local now = GetFrameTimeMilliseconds()
        if now >= endTime then
            control:SetText(string.format(formatString, endValue))
            EVENT_MANAGER:UnregisterForUpdate(animName)
            return
        end

        local elapsedTime  = now - startTime
        local progress     = EaseOutExpo(elapsedTime, 0, 1, duration)
        local safeInitial  = initialVal or 0
        local safeEnd      = endValue or 0
        local currentValue = safeInitial + (safeEnd - safeInitial) * progress
        control:SetText(string.format(formatString, currentValue))
    end

    EVENT_MANAGER:UnregisterForUpdate(animName)

    if duration > 0 and tick > 0 then
        EVENT_MANAGER:RegisterForUpdate(animName, tick, OnUpdate)
    else
        control:SetText(string.format(formatString, endValue))
    end
end

--------------------------------------------------------------------------------
-- SHARED UTILS
--------------------------------------------------------------------------------
function MS.GetThresholdColor(thresholds, value)
    local finalColor = { 1, 1, 1, 1 }
    for _, data in ipairs(thresholds) do
        local lvl = tonumber(data.level) or 0
        if lvl ~= 0 and value >= lvl then
            finalColor = data.color
        end
    end
    return finalColor
end

--------------------------------------------------------------------------------
-- ENHANCED BLOCK DETECTION
--------------------------------------------------------------------------------

MS.blockTracking = {
    dodgeStartTime = 0,
    shieldWallEndTime = 0,
}

function MS.IsReallyBlocking()
    local currentTime = GetGameTimeMilliseconds()
    local isDodging = currentTime <= MS.blockTracking.dodgeStartTime + 600
    
    if currentTime < MS.blockTracking.shieldWallEndTime then
        return true
    end
    
    if not IsBlockActive() then
        return false
    end
    
    local stamReg = 0
    local magReg = 0
    if IsUnitInCombat("player") then
        stamReg = GetPlayerStat(STAT_STAMINA_REGEN_COMBAT, STAT_BONUS_OPTION_APPLY_BONUS)
        magReg = GetPlayerStat(STAT_MAGICKA_REGEN_COMBAT, STAT_BONUS_OPTION_APPLY_BONUS)
    else
        stamReg = GetPlayerStat(STAT_STAMINA_REGEN_IDLE, STAT_BONUS_OPTION_APPLY_BONUS)
        magReg = GetPlayerStat(STAT_MAGICKA_REGEN_IDLE, STAT_BONUS_OPTION_APPLY_BONUS)
    end
    
    if stamReg ~= 0 and magReg ~= 0 and not isDodging then
        return false
    end
    
    return true
end

function MS.RegisterModule(moduleTable)
    MS.modules[moduleTable.name] = moduleTable
end

--------------------------------------------------------------------------------
-- SCALE FACTOR CALCULATION
--------------------------------------------------------------------------------
function MS.CalculateScaleFactor(value)
    local UIConfig = _G.MeterskullUILayoutConfig
    local scaleConfig = UIConfig and UIConfig.SCALE_FORMULA
    if scaleConfig then
        local defaultValue = scaleConfig.DEFAULT_VALUE or 20
        if value == defaultValue then
            return 1.0
        elseif value < defaultValue then
            local ratio = value / defaultValue
            return scaleConfig.MIN_SCALE + (1.0 - scaleConfig.MIN_SCALE) * ratio
        else
            local ratio = (value - defaultValue) / (100 - defaultValue)
            return 1.0 + (scaleConfig.MAX_SCALE - 1.0) * ratio
        end
    else
        return 0.5 + (value * 2.5 / 100)
    end
end

--------------------------------------------------------------------------------
-- DEFAULT SCALE
--------------------------------------------------------------------------------
function MS.DefaultScale(self, value)
    local cfg = _G.MeterskullModuleUIConfig[self.name]
    if not cfg or not self.uiRefs then return end

    local scaleFactor = MS.CalculateScaleFactor(value)

    local big   = tostring(32 * scaleFactor)
    local small = tostring(14 * scaleFactor)

    for _, field in ipairs(cfg.fields) do
        local valueControl = self.uiRefs[field.name]
        local labelControl = self.uiRefs[field.name .. "Label"]
        local secondLabelControl = self.uiRefs[field.name .. "SecondLabel"]

        if valueControl then
            valueControl:SetFont('$(GAMEPAD_BOLD_FONT)|'..big..'|thin-outline')
        end
        if labelControl then
            labelControl:SetFont('$(BOLD_FONT)|'..small..'|thin-outline')
        end
        if secondLabelControl then
            secondLabelControl:SetFont('$(BOLD_FONT)|'..small..'|thin-outline')
        end
    end

    local w = cfg.baseSize.w * scaleFactor
    local h = cfg.baseSize.h * scaleFactor
    self.uiRefs.main:SetDimensions(w, h)
    self.uiRefs.bg:SetDimensions(w, h)

    if _G.Meterskull_RecalculateModuleLayout then
        _G.Meterskull_RecalculateModuleLayout(self.name, value)
    end
end

--------------------------------------------------------------------------------
-- CREATE MODULE FACTORY
--------------------------------------------------------------------------------
function MS.CreateModule(name, dbKey, uiRefs, namespace, renderFunc, scaleFunc)
    local mod = {
        name           = name,
        dbKey          = dbKey,
        uiRefs         = uiRefs,
        eventNamespace = namespace or name,
        currentData    = {},
        fragment       = nil,
        renderPaused   = false,
    }

    function mod:Initialize()
        if not self.uiRefs or not self.uiRefs.main then
            DebugLog("Meterskull ERROR: uiRefs not available for " .. self.name)
            return false
        end
        self.uiRefs.main:SetHidden(true)
        self.uiRefs.bg:SetCenterColor(unpack(MS.db[self.dbKey].settings.backgroundColor))
        self:ApplyOpacity()
        self:CustomScale(MS.db[self.dbKey].settings.customScale)

        self.uiRefs.main:ClearAnchors()
        self.uiRefs.main:SetAnchor(
            TOPLEFT, GuiRoot, TOPLEFT,
            MS.db[self.dbKey].location.x,
            MS.db[self.dbKey].location.y
        )
        return true
    end

    function mod:ApplyOpacity()
        if not self.uiRefs then return end
        local settings = MS.db[self.dbKey].settings
        if self.uiRefs.bg then
            self.uiRefs.bg:SetEdgeColor(0.6, 0.6, 0.6, settings.borderOpacity / 100)
        end

        local cfg = _G.MeterskullModuleUIConfig[self.name]
        if not cfg then return end
        local alpha = settings.textOpacity / 100
        -- Control alpha preserves threshold colors and state-based color alpha.
        for _, field in ipairs(cfg.fields) do
            local valueControl = self.uiRefs[field.name]
            local labelControl = self.uiRefs[field.name .. "Label"]
            local secondLabelControl = self.uiRefs[field.name .. "SecondLabel"]
            if valueControl then valueControl:SetAlpha(alpha) end
            if labelControl then labelControl:SetAlpha(alpha) end
            if secondLabelControl then secondLabelControl:SetAlpha(alpha) end
        end
    end

    function mod:StopAnimations()
        local cfg = _G.MeterskullModuleUIConfig[self.name]
        if not cfg or not self.uiRefs then return end
        for _, field in ipairs(cfg.fields) do
            local control = self.uiRefs[field.name]
            if control then
                EVENT_MANAGER:UnregisterForUpdate(control:GetName() .. "Animation")
            end
        end
    end

    function mod:Render(initial, skipAnimation)
        if skipAnimation then
            self:StopAnimations()
            -- Refresh unchanged fields too, since their animations may be incomplete.
            initial = true
        end
        if renderFunc then renderFunc(self, initial, skipAnimation) end
    end

    function mod:ShouldShow()
        local showKey = "show"..string.gsub(self.name,"^%l",string.upper)
        return MS.db.sharedSettings[showKey] and not IsUnitDead("player")
            and (not MS.db.sharedSettings.combatOnly or IsUnitInCombat("player")
                or (MS.combatHideUntil or 0) > GetGameTimeMilliseconds())
    end

    function mod:UpdateRenderTick()
        local updateName = self.eventNamespace .. "Render"
        EVENT_MANAGER:UnregisterForUpdate(updateName)
        if not self.uiRefs or not self.uiRefs.main or self.renderPaused
            or not self:ShouldShow() then
            return
        end
        EVENT_MANAGER:RegisterForUpdate(
            updateName,
            MS.db.sharedSettings.renderTick,
            function() self:Render() end
        )
    end
    function mod:CustomScale(v)   if scaleFunc  then scaleFunc(self,v)       end end
    function mod:ToggleVisibility(show)
        local showKey = "show"..string.gsub(self.name,"^%l",string.upper)
        MS.db.sharedSettings[showKey] = show
        if not self.uiRefs or not self.uiRefs.main then return end

        -- Keep HUD fragments hidden while preview controls are shown directly.
        if MS.lamPreviewActive then
            if self.fragment then
                self.fragment:SetHiddenForReason("MeterskullPreview", true)
            end
            self.uiRefs.main:SetAlpha(1)
            self.uiRefs.main:SetHidden(not show)
            if show then self:Render(true, true) else self:StopAnimations() end
            self:UpdateRenderTick()
            return
        end

        local shouldShow = self:ShouldShow()

        if shouldShow then
            if not self.fragment then
                -- Complete scene transitions without addon animation callbacks.
                self.fragment = ZO_SimpleSceneFragment:New(self.uiRefs.main)
                ZO_MixinHideableSceneFragment(self.fragment)
            end
            if self.fragment:IsHiddenForReason("MeterskullPreview") then
                self.uiRefs.main:SetHidden(true)
                self.fragment:SetHiddenForReason("MeterskullPreview", false)
            end
            SCENE_MANAGER:GetScene("hud"):AddFragment(self.fragment)
            SCENE_MANAGER:GetScene("hudui"):AddFragment(self.fragment)
            self:Render(true, true)
        else
            self:StopAnimations()
            if self.fragment then
                SCENE_MANAGER:GetScene("hud"):RemoveFragment(self.fragment)
                SCENE_MANAGER:GetScene("hudui"):RemoveFragment(self.fragment)
            else
                self.uiRefs.main:SetHidden(true)
            end
        end
        self:UpdateRenderTick()
    end
    function mod:SaveLocation()
        local left,top = self.uiRefs.main:GetLeft(), self.uiRefs.main:GetTop()
        MS.db[self.dbKey].location.x, MS.db[self.dbKey].location.y = left, top
    end

    return mod
end

--------------------------------------------------------------------------------
-- MODULE INITIALIZATION
--------------------------------------------------------------------------------
-- Initialize all modules and render initial values
local function InitializeModules()
    for _, mod in pairs(MS.modules) do
        mod:Initialize()
    end
end

--------------------------------------------------------------------------------
-- PLAYER ACTIVATION HANDLER
--------------------------------------------------------------------------------
-- Main player activation handler (called when player enters world)
local function OnPlayerActivated(_eventCode)
    EVENT_MANAGER:UnregisterForEvent(MS.name, EVENT_PLAYER_ACTIVATED)

    InitializeMeterskullUI()
    if not _G.Meterskull_PopulateUIRefs then
        DebugLog("Meterskull ERROR: UI ref populator not available")
        return
    end
    _G.Meterskull_PopulateUIRefs()
    InitializeModules()
    if _G.Meterskull_UpdateUIVisibility then
        _G.Meterskull_UpdateUIVisibility()
    end
    if _G.Meterskull_UpdateUILockState then
        _G.Meterskull_UpdateUILockState()
    end
    MS.RegisterGameEvents()  -- Event registration moved to Events.lua
end

function MS.OnAddOnLoaded(event, addOnName)
    if addOnName ~= MS.name then return end
    EVENT_MANAGER:UnregisterForEvent(MS.name, EVENT_ADD_ON_LOADED)
    MS.accountDb = ZO_SavedVars:NewAccountWide("MeterskullSettings", 1, nil, defaults, GetWorldName())
    if MS.accountDb.sharedSettings.accountWideSettings then
        MS.db = MS.accountDb
    else
        MS.db = ZO_SavedVars:NewCharacterIdSettings("MeterskullSettings", 1, nil, defaults, GetWorldName())
    end

    if _G.Meterskull_InitializeMenu then
        _G.Meterskull_InitializeMenu(MS)
    end

    if MS.BuildMenu then
        MS.BuildMenu()
    end

    EVENT_MANAGER:RegisterForEvent(MS.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

--------------------------------------------------------------------------------
-- EXPORT SHARED UTILITIES TO GLOBAL
--------------------------------------------------------------------------------
_G.MSDefaultScale = MS.DefaultScale
_G.MSIsReallyBlocking = MS.IsReallyBlocking

--------------------------------------------------------------------------------
-- FINALE: EVENT REGISTRATION
--------------------------------------------------------------------------------
EVENT_MANAGER:RegisterForEvent(MS.name, EVENT_ADD_ON_LOADED, MS.OnAddOnLoaded)
