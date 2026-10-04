-- SnipersFriendSettingsActions.lua: LibHarvensAddonSettings menu (optional dependency)
--
-- Console: direct camera writes are impossible (SetCVar/SetSetting private), so the
-- camera section is about LIMITS - how far the game's own Settings > Camera sliders
-- may go. Direct-value sliders only appear where the engine lets us call them (PC).

local SnipersFriend = SnipersFriend
local SU = SnipersFriend.SettingsUtils
local ReticleUtils = SnipersFriend.ReticleUtils
local CameraUtils = SnipersFriend.CameraUtils
local RANGES = CameraUtils.RANGES
local LIMITS = CameraUtils.LIMIT_RANGES

local SettingsActions = {}

---@return SnipersFriendReticleSettings
local function Reticle() return SnipersFriend.state.savedVars.reticle end
---@return SnipersFriendCameraSettings
local function Camera() return SnipersFriend.state.savedVars.camera end
---@return SnipersFriendCameraLimits
local function Limits() return SnipersFriend.state.savedVars.camera.limits end
local function ReticleActions() return SnipersFriend.ReticleActions end
local function CameraActions() return SnipersFriend.CameraActions end

local function AddReticleSection(panel, LAS)
    panel:AddSetting({ type = LAS.ST_SECTION, label = "Reticle dot" })
    panel:AddSetting(SU.CheckboxParams("Replace crosshair with dot",
        "Hides the game's animated crosshair and shows a fixed dot in its place.",
        function() return Reticle().enabled end,
        function(v) ReticleActions().SetEnabled(v) end))
    panel:AddSetting({
        type = LAS.ST_DROPDOWN, label = "Style",
        items = ReticleUtils.StyleItems(),
        getFunction = function() return ReticleUtils.GetStyle(Reticle().style).label end,
        setFunction = function(_, _, item)
            local key = item and item.data or nil
            if key then
                Reticle().style = key
                ReticleActions().RefreshStyle()
            end
        end,
    })
    panel:AddSetting(SU.SliderParams("Size", "Dot size in UI pixels.",
        { min = 8, max = 128, step = 2 }, "%d",
        function() return Reticle().size end,
        function(v) Reticle().size = v; ReticleActions().RefreshStyle() end))
    panel:AddSetting(SU.SliderParams("Vertical nudge", "Move the dot up (negative) or down (positive).",
        { min = -200, max = 200, step = 2 }, "%d",
        function() return Reticle().offsetY end,
        function(v) Reticle().offsetY = v; ReticleActions().RefreshStyle() end))
    panel:AddSetting(SU.ColorParams("Color", nil,
        function() return ReticleUtils.UnpackColor(Reticle().color) end,
        function(r, g, b, a)
            Reticle().color = { r = r, g = g, b = b, a = a }
            ReticleActions().RefreshColor()
        end))
    panel:AddSetting(SU.CheckboxParams("Tint on attackable target",
        "Recolor the dot while aiming at something you can attack.",
        function() return Reticle().hostileTint end,
        function(v) Reticle().hostileTint = v; ReticleActions().RefreshColor() end))
    panel:AddSetting(SU.ColorParams("Attackable color", nil,
        function() return ReticleUtils.UnpackColor(Reticle().hostileColor) end,
        function(r, g, b, a)
            Reticle().hostileColor = { r = r, g = g, b = b, a = a }
            ReticleActions().RefreshColor()
        end))
    panel:AddSetting(SU.CheckboxParams("Flash on hit",
        "Briefly flash red when you land a heavy hit (mirrors the native crosshair).",
        function() return Reticle().hitFlash end,
        function(v) Reticle().hitFlash = v end))
end

local function AddGroundTargetSection(panel, LAS)
    local function GT() return SnipersFriend.state.savedVars.groundTarget end
    local function Actions() return SnipersFriend.GroundTargetActions end
    panel:AddSetting({ type = LAS.ST_SECTION, label = "Ground-target range / line of sight" })
    panel:AddSetting({
        type = LAS.ST_LABEL,
        label = "While placing a ground-target ability (Elemental Explosion, etc.) the dot shows the game's own verdict for the spot you are aiming at: green = castable, red = out of range, orange = no line of sight. Range buffs from passives, keeps and siege shields are included automatically.",
    })
    panel:AddSetting(SU.CheckboxParams("Enable indicator", nil,
        function() return GT().enabled end,
        function(v) GT().enabled = v; Actions().Refresh() end))
    panel:AddSetting(SU.ColorParams("Castable color", nil,
        function() return ReticleUtils.UnpackColor(GT().okColor) end,
        function(r, g, b, a) GT().okColor = { r = r, g = g, b = b, a = a }; Actions().Refresh() end))
    panel:AddSetting(SU.ColorParams("Out of range color", nil,
        function() return ReticleUtils.UnpackColor(GT().rangeColor) end,
        function(r, g, b, a) GT().rangeColor = { r = r, g = g, b = b, a = a }; Actions().Refresh() end))
    panel:AddSetting(SU.ColorParams("No line of sight color", nil,
        function() return ReticleUtils.UnpackColor(GT().losColor) end,
        function(r, g, b, a) GT().losColor = { r = r, g = g, b = b, a = a }; Actions().Refresh() end))
    panel:AddSetting(SU.ColorParams("Invalid target color", nil,
        function() return ReticleUtils.UnpackColor(GT().invalidColor) end,
        function(r, g, b, a) GT().invalidColor = { r = r, g = g, b = b, a = a }; Actions().Refresh() end))
    panel:AddSetting(SU.CheckboxParams("Fade into out-of-range color",
        "Blend from castable to out-of-range over the fade time, so clipping the edge looks different from aiming far past it.",
        function() return GT().dwellFade end,
        function(v) GT().dwellFade = v end))
    panel:AddSetting(SU.SliderParams("Fade time (ms)", nil, { min = 100, max = 2000, step = 50 }, "%d",
        function() return GT().dwellMs end,
        function(v) GT().dwellMs = v end))
    panel:AddSetting(SU.CheckboxParams("Show range and reason under the dot", nil,
        function() return GT().showLabel end,
        function(v) GT().showLabel = v; Actions().Refresh() end))
    panel:AddSetting(SU.SliderParams("Text offset below dot", nil, { min = 0, max = 120, step = 2 }, "%d",
        function() return GT().labelOffsetY end,
        function(v) GT().labelOffsetY = v; Actions().Refresh() end))
    panel:AddSetting(SU.CheckboxParams("Log verdict changes (for tuning)", "View with /sf gt log",
        function() return GT().debugLog end,
        function(v) GT().debugLog = v end))
end

local function AddAimLineSection(panel, LAS)
    local function AL() return SnipersFriend.state.savedVars.aimLine end
    local function Actions() return SnipersFriend.AimLineActions end
    panel:AddSetting({ type = LAS.ST_SECTION, label = "Aim guide (distance icons / max range)" })
    panel:AddSetting({
        type = LAS.ST_LABEL,
        label = "Icons along your aim at fixed horizontal distances from you (e.g. every 3.5 m) up to your ground ability's range (passives, keep and siege-shield buffs included), with a marker at max range. Icons always face you and never stretch. Walls hide the icons behind them, so the last visible icon tells you how far your aim reaches.",
    })
    panel:AddSetting(SU.CheckboxParams("Show aim guide", nil,
        function() return AL().enabled end,
        function(v) AL().enabled = v; Actions().Refresh() end))
    panel:AddSetting(SU.CheckboxParams("Walls hide icons (depth test)",
        "Off = everything is drawn through walls (pure range reference).",
        function() return AL().depthTest end,
        function(v) AL().depthTest = v; Actions().Refresh() end))
    panel:AddSetting(SU.CheckboxParams("Distance icons",
        "Camera-facing icons at fixed horizontal distances from you.",
        function() return AL().showTicks end,
        function(v) AL().showTicks = v end))
    panel:AddSetting(SU.SliderParams("Icon every (m)", nil, { min = 0.5, max = 10, step = 0.5 }, "%.1f",
        function() return AL().tickIntervalM end,
        function(v) AL().tickIntervalM = v end))
    panel:AddSetting(SU.SliderParams("Larger icon every N icons (0 = off)", nil, { min = 0, max = 5, step = 1 }, "%d",
        function() return AL().majorTickEvery end,
        function(v) AL().majorTickEvery = v end))
    panel:AddSetting(SU.SliderParams("Icon size (m)", "World size of each icon. With 'same size on screen' this is the size at 10 m.",
        { min = 0.1, max = 3, step = 0.1 }, "%.1f",
        function() return AL().iconSizeM end,
        function(v) AL().iconSizeM = v end))
    panel:AddSetting(SU.CheckboxParams("Icons same size on screen",
        "Scale icons with distance so far ones don't shrink.",
        function() return AL().iconConstantScreenSize end,
        function(v) AL().iconConstantScreenSize = v end))
    panel:AddSetting(SU.CheckboxParams("Icons on the camera ray (occlusion range finder)",
        "Off = icons run from your character to the aim point, spread across the screen. On = icons sit exactly on your line of sight: they stack at the crosshair (nearer = bigger) and every icon behind a wall vanishes, so the smallest ring you can see is how far your aim reaches.",
        function() return AL().iconPath == "ray" end,
        function(v) AL().iconPath = v and "ray" or "line" end))
    panel:AddSetting(SU.ColorParams("Icon color", nil,
        function() return ReticleUtils.UnpackColor(AL().tickColor) end,
        function(r, g, b, a) AL().tickColor = { r = r, g = g, b = b, a = a }; Actions().Refresh() end))
    panel:AddSetting(SU.CheckboxParams("Line strip character -> aim point",
        "Flat strip along the aim. Its texture visibly stretches as you look up or down; off by default.",
        function() return AL().showLine end,
        function(v) AL().showLine = v end))
    panel:AddSetting(SU.SliderParams("Line width (m)", nil, { min = 0.02, max = 0.5, step = 0.02 }, "%.2f",
        function() return AL().lineWidthM end,
        function(v) AL().lineWidthM = v end))
    panel:AddSetting(SU.ColorParams("Line color", nil,
        function() return ReticleUtils.UnpackColor(AL().lineColor) end,
        function(r, g, b, a) AL().lineColor = { r = r, g = g, b = b, a = a }; Actions().Refresh() end))
    panel:AddSetting(SU.CheckboxParams("Ground marker (flat ground only)",
        "Ring on the floor where your view line meets your own floor level: green inside range, red beyond. Assumes flat ground - wrong on slopes and platforms.",
        function() return AL().showGround end,
        function(v) AL().showGround = v end))
    panel:AddSetting(SU.SliderParams("Ground marker size (m)", nil, { min = 0.3, max = 4, step = 0.1 }, "%.1f",
        function() return AL().groundSizeM end,
        function(v) AL().groundSizeM = v; Actions().Refresh() end))
    panel:AddSetting(SU.CheckboxParams("Show end marker at max range", nil,
        function() return AL().showCap end,
        function(v) AL().showCap = v end))
    panel:AddSetting(SU.SliderParams("End marker size (m)", nil, { min = 0.2, max = 3, step = 0.1 }, "%.1f",
        function() return AL().capSizeM end,
        function(v) AL().capSizeM = v; Actions().Refresh() end))
    panel:AddSetting(SU.ColorParams("End marker color", nil,
        function() return ReticleUtils.UnpackColor(AL().capColor) end,
        function(r, g, b, a) AL().capColor = { r = r, g = g, b = b, a = a }; Actions().Refresh() end))
    panel:AddSetting(SU.CheckboxParams("Show even without a ground ability slotted", nil,
        function() return AL().showWithoutGroundAbility end,
        function(v) AL().showWithoutGroundAbility = v end))
    panel:AddSetting(SU.SliderParams("Range when no ground ability (m)", nil, { min = 5, max = 60, step = 1 }, "%d",
        function() return AL().fallbackRangeM end,
        function(v) AL().fallbackRangeM = v end))
    panel:AddSetting(SU.SliderParams("Range override (m, 0 = use ability)", nil, { min = 0, max = 60, step = 1 }, "%d",
        function() return AL().rangeOverrideM end,
        function(v) AL().rangeOverrideM = v end))
end

local function AddLimitSlider(panel, label, tooltip, key, range, fmt)
    panel:AddSetting(SU.SliderParams(label, tooltip, range, fmt,
        function() return Limits()[key] end,
        function(v) Limits()[key] = v; CameraActions().ApplySliderLimits() end))
end

local function AddLimitsSection(panel, LAS)
    panel:AddSetting({ type = LAS.ST_SECTION, label = "Camera slider limits" })
    panel:AddSetting({
        type = LAS.ST_LABEL,
        label = "The game only lets addons change camera values through its own Settings > Camera menu. These controls widen the ranges of those sliders (and add Camera Distance sliders there). Set the limit here, then adjust the actual value in Settings > Camera.",
    })
    panel:AddSetting(SU.CheckboxParams("Widen game's Camera sliders",
        "Off = stock ranges (sensitivity 0.65-1.05, height -0.30-0.50, FOV 35-65).",
        function() return Camera().unlockNativeSliders end,
        function(v)
            Camera().unlockNativeSliders = v
            if v then CameraActions().ApplySliderLimits() else CameraActions().RestoreNativeSliders() end
        end))
    AddLimitSlider(panel, "Look sensitivity max", "Stock max is 1.05. MOR Camera Sensitivity uses 2.", "sensitivityMax", LIMITS.sensitivityMax, "%.2f")
    AddLimitSlider(panel, "Camera distance max", "Stock stick zoom tops out around 2.5. Adds 'Camera Distance' sliders to Settings > Camera.", "distanceMax", LIMITS.distanceMax, "%.2f")
    AddLimitSlider(panel, "Camera height min", "Stock min is -0.30 (lower camera).", "heightMin", LIMITS.heightMin, "%.2f")
    AddLimitSlider(panel, "Camera height max", "Stock max is 0.50 (higher camera).", "heightMax", LIMITS.heightMax, "%.2f")
    AddLimitSlider(panel, "Horizontal offset max (+/-)", "Stock is +/-1.00 (over-the-shoulder).", "offsetMax", LIMITS.offsetMax, "%.2f")
    AddLimitSlider(panel, "Field of view min", "Stock min is 35.", "fovMin", LIMITS.fovMin, "%d")
    AddLimitSlider(panel, "Field of view max", "Stock max is 65.", "fovMax", LIMITS.fovMax, "%d")
    panel:AddSetting({
        type = LAS.ST_BUTTON, label = "Reset limits to Snipers Friend defaults", buttonText = "Reset",
        clickHandler = function()
            local d = SnipersFriend.State.Defaults().camera.limits
            local L = Limits()
            for k, v in pairs(d) do L[k] = v end
            CameraActions().ApplySliderLimits()
        end,
    })
end

-- Direct-value controls: only meaningful where the engine lets addons write (PC).
local function AddDirectSection(panel, LAS)
    local canCVar = CameraUtils.CanSetCVar()
    local canSetting = CameraUtils.CanSetSetting()
    if not (canCVar or canSetting) then return end

    panel:AddSetting({ type = LAS.ST_SECTION, label = "Direct camera values (this platform allows them)" })
    if canCVar then
        panel:AddSetting(SU.SliderParams("Horizontal look sensitivity", nil, RANGES.sensitivity, "%.2f",
            function() return Camera().sensitivityX end,
            function(v) Camera().sensitivityX = v; CameraActions().ApplySensitivity() end))
        panel:AddSetting(SU.SliderParams("Vertical look sensitivity", nil, RANGES.sensitivity, "%.2f",
            function() return Camera().sensitivityY end,
            function(v) Camera().sensitivityY = v; CameraActions().ApplySensitivity() end))
        panel:AddSetting(SU.CheckboxParams("Use same values in first person", nil,
            function() return Camera().syncFirstPerson end,
            function(v) Camera().syncFirstPerson = v; CameraActions().ApplySensitivity() end))
        panel:AddSetting(SU.SliderParams("Distance (weapons out)", nil, RANGES.distance, "%.2f",
            function() return Camera().distance end,
            function(v) Camera().distance = v; CameraActions().ApplyDistance() end))
        panel:AddSetting(SU.CheckboxParams("Same distance when sheathed", nil,
            function() return Camera().syncDistances end,
            function(v) Camera().syncDistances = v; CameraActions().ApplyDistance() end))
        panel:AddSetting(SU.SliderParams("Distance (weapons sheathed)", nil, RANGES.distance, "%.2f",
            function() return Camera().distanceSheathed end,
            function(v) Camera().distanceSheathed = v; CameraActions().ApplyDistance() end))
        panel:AddSetting(SU.SliderParams("Distance (siege)", nil, RANGES.distanceSiege, "%.2f",
            function() return Camera().distanceSiege end,
            function(v) Camera().distanceSiege = v; CameraActions().ApplyDistance() end))
        panel:AddSetting(SU.CheckboxParams("Lock distance", "Re-apply the distance every second so stick zoom can't change it.",
            function() return Camera().lockDistance end,
            function(v) Camera().lockDistance = v; CameraActions().UpdateDistanceLock() end))
    end
    if canSetting then
        panel:AddSetting(SU.SliderParams("Height (vertical offset)", nil, RANGES.height, "%.2f",
            function() return Camera().height end,
            function(v) Camera().height = v; CameraActions().ApplyHeight() end))
        panel:AddSetting(SU.SliderParams("Horizontal offset", nil, RANGES.horizontalOffset, "%.2f",
            function() return Camera().horizontalOffset end,
            function(v) Camera().horizontalOffset = v; CameraActions().ApplyHorizontalOffset() end))
        panel:AddSetting(SU.SliderParams("Field of view", nil, RANGES.fov, "%d",
            function() return Camera().fov end,
            function(v) Camera().fov = v; CameraActions().ApplyFov() end))
    end
    panel:AddSetting(SU.CheckboxParams("Apply these values on login", nil,
        function() return Camera().applyOnLoad end,
        function(v) Camera().applyOnLoad = v end))
    panel:AddSetting({
        type = LAS.ST_BUTTON, label = "Apply all now", buttonText = "Apply",
        clickHandler = function() CameraActions().ApplyAll() end,
    })
end

local function AddGeneralSection(panel, LAS)
    panel:AddSetting({ type = LAS.ST_SECTION, label = "General" })
    panel:AddSetting(SU.CheckboxParams("Debug logging", nil,
        function() return SnipersFriend.state.savedVars.debug end,
        function(v) SnipersFriend.state.savedVars.debug = v end))
end

---@return boolean
function SettingsActions.Initialize()
    local LAS = _G["LibHarvensAddonSettings"]
    if not (LAS and LAS.AddAddon) then
        SnipersFriend.SlashUtils.Debug("LibHarvensAddonSettings not present - use /sf commands")
        return false
    end
    local panel = LAS:AddAddon(SnipersFriend.displayName, { allowRefresh = true })
    if not panel then return false end
    panel.author = "clubwratt"
    panel.version = SnipersFriend.version
    SnipersFriend.state.settingsPanel = panel

    AddReticleSection(panel, LAS)
    AddGroundTargetSection(panel, LAS)
    AddAimLineSection(panel, LAS)
    AddLimitsSection(panel, LAS)
    AddDirectSection(panel, LAS)
    AddGeneralSection(panel, LAS)
    return true
end

SnipersFriend.SettingsActions = SettingsActions
