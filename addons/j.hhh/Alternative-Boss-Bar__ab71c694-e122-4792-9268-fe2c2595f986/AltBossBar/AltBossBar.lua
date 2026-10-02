local NAME = 'AltBossBar'
local SV_VER = 3

local SETTINGS

-- ABB_MAX_BOSSES is not exposed on all console UI builds.
-- ESO exposes boss unit tags boss1 through boss6.
local ABB_MAX_BOSSES = tonumber(_G.MAX_BOSSES) or 6

local ICONSIZE = ZO_COMPASS_FRAME_HEIGHT_KEYBOARD-8
local ABB_TEMPLATE_NAME = "ABB_BossBar_Emb"
local FN_ABB_GET_WIDTH = nil

local THEME_OFFSET = 0

local OVERSHIELD_COLOR_START = ZO_ColorDef:New("392952")
local OVERSHIELD_COLOR_END = ZO_ColorDef:New("968498")
local UNWAVERING_COLOR_START = ZO_ColorDef:New("7D7750")
local UNWAVERING_COLOR_END = ZO_ColorDef:New("DDDDCB")

local OVERSHIELD_GRADIENT = { OVERSHIELD_COLOR_START, OVERSHIELD_COLOR_END }
local UNWAVERING_GRADIENT = { UNWAVERING_COLOR_START, UNWAVERING_COLOR_END }

-- equal to ZO_POWER_BAR_GRADIENT_COLORS[COMBAT_MECHANIC_FLAGS_HEALTH]
local DEFAULT_HP_COLOR_START = { 0.447, 0.137, 0.137 }
local DEFAULT_HP_COLOR_END = { 0.855, 0.188, 0.188 }

local THEMES = {
    ["Plain"] = {
        template = "ABB_BossBar",
        calcWidth = function() return GuiRoot:GetWidth() * 0.35 end
    },
    ["Embellished"] = {
        template = "ABB_BossBar_Emb",
        calcWidth = function() return GuiRoot:GetWidth() * 0.35 - 20 end
    }
}

-- Threshold/mechanic data is provided by CrutchAlerts 2.26+.
-- Keeping this addon as a renderer avoids duplicating encounter data and lets
-- CrutchAlerts handle difficulty and dynamic encounter overrides.
local function GetCrutchBossHealthBar()
    return CrutchAlerts and CrutchAlerts.BossHealthBar
end

local PercentLineManager = ZO_ControlPool:Subclass()
function PercentLineManager:New(parent, ...)
    local obj = ZO_ControlPool.New(self, "ABB_HP_Line_"..SETTINGS.PERCENTAGE_LINE_STYLE.."_Template", parent, "ABB_HP_Line")
    --obj:Initialize( ... )
    return obj
end

local ABB_BossBar = ZO_Object:Subclass()
function ABB_BossBar:New(...)
    local bar = ZO_Object.New(self)
    bar:Initialize(...)
    return bar
end

function ABB_BossBar:Initialize(bossTag, topLevelCtrl, previousBar, skipUnitEvents)
    self.unitTag = bossTag
    self.parent = topLevelCtrl
    self.control = CreateControlFromVirtual("ABB_Frame"..bossTag, topLevelCtrl, ABB_TEMPLATE_NAME)
    self.control:SetHidden(true)
    local healthControl = GetControl(self.control, "Health")
    self.healthControl = healthControl
    self.nameText = GetControl(healthControl, "Name")
    self.healthText = GetControl(healthControl, "Text")
    self.healthBar = GetControl(healthControl, "Bar")
    self.healthLeftBgBar = GetControl(healthControl, "LeftBgBar")


    -- Dedicated fill area. The visible frame remains completely independent.
    self.hpFillContainer = WINDOW_MANAGER:CreateControl("ABB_HPFill_" .. bossTag, self.control, CT_CONTROL)
    self.previousBar = previousBar
    self.nextBar = nil
    self.percentLinePool = PercentLineManager:New(self.healthBar)
    self.bossPercentages = nil
    self.hasShield = false
    self.hasImmunity = false
    self.bracketLeft = self.control:GetNamedChild("BracketLeft")
    self.bracketRight = self.control:GetNamedChild("BracketRight")
    self.bgLeft = self.control:GetNamedChild("BgLeft")
    self.bgRight = self.control:GetNamedChild("BgRight")
    self.frameCenter = self.control:GetNamedChild("FrameCenter")
    self.frameRight = self.control:GetNamedChild("FrameRight")
    self.scaleX = 1.0
    self.shouldWarn = false
    self.warner = GetControl(self.control, "Warner")
    self.warnerAnimation = ZO_AlphaAnimation:New(self.warner)
    -- Center label: next CrutchAlerts threshold/mechanic.
    self.mechanicText = WINDOW_MANAGER:CreateControl("ABB_Mechanic_" .. bossTag, healthControl, CT_LABEL)
    self.mechanicText:SetFont("ZoFontGamepad22")
    self.mechanicText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.mechanicText:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.mechanicText:SetAnchor(CENTER, healthControl, CENTER, 0, -1)
    self.mechanicText:SetDimensions(healthControl:GetWidth(), 32)
    self.mechanicText:SetDrawLayer(DL_OVERLAY)
    self.mechanicText:SetText("")


    if not skipUnitEvents then
        local function PowerUpdateHandlerFunction(unitTag, powerPoolIndex, powerType, powerPool, powerPoolMax)
            self:OnPowerUpdate(unitTag, powerPool, powerPoolMax, false)
        end
        local powerUpdateEventHandler = ZO_MostRecentPowerUpdateHandler:New("BossBar"..bossTag, PowerUpdateHandlerFunction)
        powerUpdateEventHandler:AddFilterForEvent(REGISTER_FILTER_POWER_TYPE, POWERTYPE_HEALTH)
        
        if bossTag == "reticleover" then
            powerUpdateEventHandler:AddFilterForEvent(REGISTER_FILTER_UNIT_TAG, bossTag)
        else
            powerUpdateEventHandler:AddFilterForEvent(REGISTER_FILTER_UNIT_TAG_PREFIX, "boss")
        end

        self:RegisterUnit(bossTag)
    end
    self.control:RegisterForEvent(EVENT_PLAYER_ACTIVATED, function() self:UpdateWidth() end)
    self.control:RegisterForEvent(EVENT_SCREEN_RESIZED, function() self:UpdateWidth() end)
    
    self:ResetColors()
    self:ApplyStyle()
    self:ApplyAnchors()
end

function ABB_BossBar:RegisterUnit(unitTag)
    self:UnregisterUnit()
    self.unitTag = unitTag
    self.control:RegisterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, function(eventCode, unitTag, ...) self:OnUavUpdate(...) end)
    self.control:AddFilterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, REGISTER_FILTER_UNIT_TAG, self.unitTag)
    self.control:RegisterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, function(eventCode, unitTag, ...) self:OnUavUpdate(...) end)
    self.control:AddFilterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, REGISTER_FILTER_UNIT_TAG, self.unitTag)
    self.control:RegisterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, function(eventCode, unitTag, ...) self:OnUavRemoval(...) end)
    self.control:AddFilterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, REGISTER_FILTER_UNIT_TAG, self.unitTag)
end

function ABB_BossBar:UnregisterUnit()
    self.control:UnregisterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED)
    self.control:UnregisterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED)
    self.control:UnregisterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED)
end

function ABB_BossBar:GetBossPercentagesByName(name)
    self.bossPercentages = nil
    self.bossMechanics = nil
    self.shouldWarn = false

    local BHB = GetCrutchBossHealthBar()
    if BHB and BHB.GetBossThresholds then
        local thresholds = BHB.GetBossThresholds(name)
        if thresholds then
            -- Multi-boss encounters can provide a table specifically for boss1,
            -- boss2, etc. Prefer it; otherwise use the backwards-compatible
            -- numeric values on the top level.
            local source = thresholds[self.unitTag] or thresholds
            local percentages = {}
            local mechanics = {}
            for threshold, mechanic in pairs(source) do
                if type(threshold) == "number" then
                    table.insert(percentages, threshold)
                    mechanics[threshold] = mechanic
                end
            end
            table.sort(percentages, function(a, b) return a > b end)
            if #percentages > 0 then
                self.bossPercentages = percentages
                self.bossMechanics = mechanics
                self.shouldWarn = true
                return
            end
        end
    end

    -- Optional fallback for encounters CrutchAlerts does not define.
    if SETTINGS.SHOW_DEFAULTS then
        self.bossPercentages = { 75, 50, 25 }
        self.bossMechanics = {}
    end
end

function ABB_BossBar:CreateLine(percent)
    local line = self.percentLinePool:AcquireObject()
    local x = (self.healthBar:GetWidth() / 100) * percent
    if SETTINGS.THEME_NAME == "Embellished" then
        x = x - 8.5
    else
        x = x - 9 -- mod for better simmetry cause of healthLeftBgBar
    end
    line:SetAnchor(TOPLEFT, self.healthBar, TOPLEFT, x, 0)
    line:SetAnchor(BOTTOMRIGHT, self.healthBar, TOPLEFT,  x, -0 + self.healthBar:GetHeight())
end

function ABB_BossBar:Refresh(force)
    if force then
        self:ApplyStyle()
        self:ResetColors()
        self:ApplyAnchors()
    else
        self:UpdateWidth()
    end
    local bossName = GetUnitName(self.unitTag)
    local health, maxHealth = GetUnitPower(self.unitTag, POWERTYPE_HEALTH)
    self:GetBossPercentagesByName(bossName)
    -- CrutchAlerts thresholds are displayed as text only.
    -- Do not draw percentage divider lines on the boss bar.
    self.percentLinePool:ReleaseAllObjects()
    self.nameText:SetText(bossName)
    self:OnPowerUpdate(self.unitTag, health, maxHealth, force)
end


function ABB_BossBar:UpdateMechanicText(health, maxHealth)
    if not self.mechanicText then return end
    if not self.bossPercentages or not self.bossMechanics or maxHealth == 0 then
        self.mechanicText:SetText("")
        return
    end

    local currentPercent = (health / maxHealth) * 100
    local nextThreshold, nextMechanic
    -- bossPercentages is sorted high -> low. The first threshold not yet crossed
    -- is the next mechanic the group will reach.
    for i = 1, #self.bossPercentages do
        local threshold = self.bossPercentages[i]
        if currentPercent >= threshold then
            nextThreshold = threshold
            nextMechanic = self.bossMechanics[threshold]
            break
        end
    end

    if nextThreshold and nextMechanic and nextMechanic ~= "" then
        self.mechanicText:SetText(string.format("next at %s%%: %s", tostring(nextThreshold), tostring(nextMechanic)))
        self.mechanicText:SetHidden(false)
    else
        self.mechanicText:SetText("")
    end
end

function ABB_BossBar:FormatPercent(health, maxHealth)
    local percent = 0
    local percentText
    if maxHealth ~= 0 then
        percent = (health / maxHealth) * 100
    end
    if percent < 10 then
        percentText = ZO_CommaDelimitDecimalNumber(zo_roundToNearest(percent, .1))
        percentText = ZO_FastFormatDecimalNumber(percentText)
    else
        percentText = zo_round(percent)
    end

    if self.bossPercentages ~= nil and SETTINGS.NOTIFY_ALERT then
        for i = 1, #self.bossPercentages do
            local threshold = self.bossPercentages[i]
            if percent >= threshold and percent <= threshold + SETTINGS.NOTIFY_BEFORE_PERCENT then
                if SETTINGS.NOTIFY_ALERT_TYPE == "Flash" then
                    self:FlashWarning()
                else
                    return zo_iconFormat("esoui/art/interaction/questnewavailable.dds", ICONSIZE-8, ICONSIZE-8)..percentText..'%'
                end
                break
            end
        end
    end
    return percentText..'%'
end

function ABB_BossBar:OnPowerUpdate(sourceUnit, health, maxHealth, force)
    if sourceUnit ~= self.unitTag then
        return
    end

    -- Original Alternative Boss Bar / ESO status-bar behavior.
    ZO_StatusBar_SmoothTransition(self.healthBar, health, maxHealth, force)
    self.healthLeftBgBar:SetValue((health > 0 and 1 or 0))

    self:UpdateMechanicText(health, maxHealth)

    if health > 0 and not IsUnitDead(self.unitTag) then
        self.healthText:SetText(ZO_AbbreviateAndLocalizeNumber(health, NUMBER_ABBREVIATION_PRECISION_TENTHS, false) .. " " .. self:FormatPercent(health, maxHealth))
    else
        self.healthText:SetText(zo_iconFormat("esoui/art/icons/mapkey/mapkey_groupboss.dds", ICONSIZE, ICONSIZE))
    end
end

function ABB_BossBar:OnUavUpdate(unitAttributeVisual, _, _, _, value1)
    if (unitAttributeVisual == ATTRIBUTE_VISUAL_UNWAVERING_POWER) then
        if value1 ~= nil and value1 > 0 then
            if not self.hasImmunity then
                self.hasImmunity = true
                ZO_StatusBar_SetGradientColor(self.healthBar, UNWAVERING_GRADIENT)
                self.healthLeftBgBar:SetColor(UNWAVERING_COLOR_START:UnpackRGBA())
            end
        else
            self:OnUavRemoval(unitAttributeVisual)
        end
        return
    end
    if (unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING and not self.hasImmunity) then
        if value1 ~= nil and value1 > 0 then
            if not self.hasShield then
                self.hasShield = true
                ZO_StatusBar_SetGradientColor(self.healthBar, OVERSHIELD_GRADIENT)
                self.healthLeftBgBar:SetColor(OVERSHIELD_COLOR_START:UnpackRGBA())
            end
        else
            self:OnUavRemoval(unitAttributeVisual)
        end
    end
end

function ABB_BossBar:OnUavRemoval(unitAttributeVisual)
    if (unitAttributeVisual == ATTRIBUTE_VISUAL_UNWAVERING_POWER) then
        if self.hasImmunity then
            self.hasImmunity = false
            self:ResetColors()
        end
        return
    end
    if (unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING and not self.hasImmunity) then
        if self.hasShield then
            self.hasShield = false
            self:ResetColors()
        end
    end
end

function ABB_BossBar:ResetColors()
    local gradient = {ZO_ColorDef:New(unpack(SETTINGS.HP_COLOR_START) ), ZO_ColorDef:New(unpack(SETTINGS.HP_COLOR_END))}
    ZO_StatusBar_SetGradientColor(self.healthBar, gradient)
    self.healthLeftBgBar:SetColor(gradient[1]:UnpackRGBA())
end

function ABB_BossBar:ApplyAnchors()
    self.control:ClearAnchors()
    if self.previousBar ~= nil then
        self.previousBar.nextBar = self
        self.control:SetAnchor(TOP, self.previousBar.control, BOTTOM)
    else
        -- Only apply to the first bar
        self.control:SetAnchor(TOP, self.parent, TOP, 0, 0)
        -- self.warner:SetWidth(FN_ABB_GET_WIDTH() * self.scaleX)
        if SETTINGS.THEME_NAME == "Embellished" then
            self.bracketLeft:SetHidden(false)
            self.bracketRight:SetHidden(false)
        end
    end
end

function ABB_BossBar:ApplyStyle()
    ApplyTemplateToControl(self.control, ZO_GetPlatformTemplate(ABB_TEMPLATE_NAME))
    self:UpdateWidth()
end

function ABB_BossBar:LockHealthFillGeometry()
    -- HP FILL ONLY. FRAME / END CAPS ARE NOT MODIFIED.
    --
    -- Keep the original Alternative Boss Bar horizontal geometry exactly:
    -- LeftBgBar keeps its native XML width (18 px) and HealthBar begins there.
    -- HEIGHT_SCALE affects only the vertical size of the two fill controls.
    if not self.healthControl or not self.healthBar or not self.healthLeftBgBar then return end

    local heightScale = SETTINGS.HEIGHT_SCALE or 1.0
    local n = self._abbNative
    if not n then return end

    local fillHeight = math.floor(n.barH * heightScale + 0.5)
    local splitWidth = math.floor(n.leftBarW + 0.5)

    self.healthLeftBgBar:SetHidden(false)
    self.healthLeftBgBar:SetAlpha(1)
    self.healthLeftBgBar:ClearAnchors()
    self.healthLeftBgBar:SetAnchor(LEFT, self.healthControl, LEFT, 0, 0)
    self.healthLeftBgBar:SetAnchor(RIGHT, self.healthControl, LEFT, splitWidth, 0)
    self.healthLeftBgBar:SetHeight(fillHeight)

    self.healthBar:SetHidden(false)
    self.healthBar:ClearAnchors()
    self.healthBar:SetAnchor(LEFT, self.healthControl, LEFT, splitWidth, 0)
    self.healthBar:SetAnchor(RIGHT, self.healthControl, RIGHT, 0, 0)
    self.healthBar:SetHeight(fillHeight)
end

function ABB_BossBar:UpdateWidth()
    local widthScale = SETTINGS.WIDTH_SCALE or 1.0
    local heightScale = SETTINGS.HEIGHT_SCALE or 1.0
    local requestedWidth = FN_ABB_GET_WIDTH() * self.scaleX * widthScale

    self.control:SetScale(1)
    self.control:SetWidth(requestedWidth)

    if not self._abbNative then
        self._abbNative = {
            controlH = self.control:GetHeight(),
            healthH = self.healthControl:GetHeight(),
            barH = self.healthBar:GetHeight(),
            leftBarW = self.healthLeftBgBar:GetWidth(),
            leftBarH = self.healthLeftBgBar:GetHeight(),
            bgLeftW = self.bgLeft and self.bgLeft:GetWidth() or 0,
            bgLeftH = self.bgLeft and self.bgLeft:GetHeight() or 0,
            bgRightW = self.bgRight and self.bgRight:GetWidth() or 0,
            bgRightH = self.bgRight and self.bgRight:GetHeight() or 0,
            frameRightW = self.frameRight and self.frameRight:GetWidth() or 0,
            frameRightH = self.frameRight and self.frameRight:GetHeight() or 0,
        }
    end

    local n = self._abbNative

    -- Keep the outer boss-bar/frame behavior from v0.14.
    self.control:SetHeight(n.controlH * heightScale)
    self.healthControl:SetHeight(n.healthH * heightScale)

    if self.bgLeft and n.bgLeftW > 0 and n.bgLeftH > 0 then
        self.bgLeft:SetDimensions(n.bgLeftW * heightScale, n.bgLeftH * heightScale)
    end
    if self.bgRight and n.bgRightW > 0 and n.bgRightH > 0 then
        self.bgRight:SetDimensions(n.bgRightW * heightScale, n.bgRightH * heightScale)
    end
    if self.frameRight and n.frameRightW > 0 and n.frameRightH > 0 then
        self.frameRight:SetDimensions(n.frameRightW * heightScale, n.frameRightH * heightScale)
    end

    -- HP FILL ONLY:
    -- Frame/end caps remain untouched. Reassert the original split using
    -- integer coordinates so runtime refreshes cannot move the seam.
    self.hpFillContainer:ClearAnchors()
    self.hpFillContainer:SetHidden(true)
    self:LockHealthFillGeometry()

    if self.mechanicText then
        self.mechanicText:ClearAnchors()
        self.mechanicText:SetAnchor(CENTER, self.healthControl, CENTER, 0, -1)
        self.mechanicText:SetDimensions(self.healthControl:GetWidth(), 32)
    end
end

function ABB_BossBar:Show()
    self.control:SetHidden(false)
    self.control:SetAlpha(1)
    if self.mechanicText and self.mechanicText:GetText() ~= "" then
        self.mechanicText:SetHidden(false)
    end
end

function ABB_BossBar:Hide()
    self.control:SetHidden(true)
    if self.mechanicText then self.mechanicText:SetHidden(true) end
    self.hasShield = false
    self.hasImmunity = false
    self:ResetColors()
    if self.nextBar ~= nil then
        self.nextBar:Hide()
    end
end

function ABB_BossBar:FlashWarning()
    local RESOURCE_WARNER_FLASH_TIME = 300
    local RESOURCE_WARNER_NUM_FLASHES = 3
    if not self.shouldWarn then return end
    if not self.warnerAnimation:IsPlaying() then
        self.warnerAnimation:PingPong(0, 1, RESOURCE_WARNER_FLASH_TIME, RESOURCE_WARNER_NUM_FLASHES)
    else
        --Reset the animation by making it do RESOURCE_WARNER_NUM_FLASHES after this point
        local remainingLoops = self.warnerAnimation:GetPlaybackLoopsRemaining()
        local newLoops = RESOURCE_WARNER_NUM_FLASHES
        --If we're on the backswing of the ping pong we need to do one addition loop to make sure it ends in the alpha down state, otherwise it stops at full alpha
        if remainingLoops % 2 == 0 then
            newLoops = newLoops + 1
        end
        self.warnerAnimation:SetPlaybackLoopCount(newLoops)
    end
end

local function AttachTargetTo(anchorControl)
    -- Keep ESO's target frame/debuff stack directly below the lowest visible
    -- boss bar. When no boss bar is visible, restore it below the compass.
    if not ZO_TargetUnitFramereticleover then return end

    local targetFrame = ZO_TargetUnitFramereticleover
    targetFrame:ClearAnchors()

    if anchorControl and anchorControl ~= ZO_CompassFrame then
        targetFrame:SetAnchor(TOP, anchorControl, BOTTOM, 0, 0)
    else
        targetFrame:SetAnchor(TOP, ZO_CompassFrame, BOTTOM, 0, 0)
    end
end

-- Combined encounter presentation ported from the newer PC addon.
local COMBINED_BOSS_NAMES = {
    ["Shaper of Flesh"] = "Hall of Fleshcraft",
    ["Former des Fleisches"] = "Halle des Fleischwerks",
    ["moldeador de carne"] = "Salón de Manipulación de la Carne",
    ["façonneur de chair"] = "Salle des sculptechairs",
    ["肉の加工者"] = "肉細工の間",
    ["Формирователь плоти"] = "Зал Преображения Плоти",
    ["血肉塑形者"] = "血肉大厅",
}
local SHAPER_THRESHOLDS = {84,67,50,34,17}
local SHAPER_MECHANICS = {
    [84]="Portal Activated",[67]="Portal Activated",[50]="Portal Activated",
    [34]="Portal Activated",[17]="Portal Activated",
}

local ABB_CombinedBossBar = ABB_BossBar:Subclass()
function ABB_CombinedBossBar:New(bossTag, topLevelCtrl)
    local bar=ZO_Object.New(self)
    ABB_BossBar.Initialize(bar,bossTag,topLevelCtrl,nil,true)
    bar.unitTags={}
    bar.bossHealthsCurrent={}
    bar.bossHealthsMax={}
    for i=1,ABB_MAX_BOSSES do
        local tag="boss"..i
        bar.unitTags[#bar.unitTags+1]=tag
        local function OnCombinedPowerUpdate(unitTag,powerPoolIndex,powerType,powerPool,powerPoolMax)
            bar:OnCombinedPowerUpdate(unitTag,powerPool,powerPoolMax)
        end
        local h=ZO_MostRecentPowerUpdateHandler:New("ABBCombined"..tag,OnCombinedPowerUpdate)
        h:AddFilterForEvent(REGISTER_FILTER_POWER_TYPE,POWERTYPE_HEALTH)
        h:AddFilterForEvent(REGISTER_FILTER_UNIT_TAG,tag)
    end
    return bar
end

function ABB_CombinedBossBar:OnCombinedPowerUpdate(unitTag,health,maxHealth)
    self.bossHealthsCurrent[unitTag]=health or 0
    self.bossHealthsMax[unitTag]=maxHealth or 0
    local total,totalMax=0,0
    for _,v in pairs(self.bossHealthsCurrent) do total=total+v end
    for _,v in pairs(self.bossHealthsMax) do totalMax=totalMax+v end
    if totalMax<=0 then return end
    ZO_StatusBar_SmoothTransition(self.healthBar,total,totalMax,false)
    self.healthLeftBgBar:SetValue((total>0 and 1 or 0))
    self:UpdateMechanicText(total,totalMax)
    if total>0 then
        self.healthText:SetText(ZO_AbbreviateAndLocalizeNumber(total,NUMBER_ABBREVIATION_PRECISION_TENTHS,false).." "..self:FormatPercent(total,totalMax))
    else
        self.healthText:SetText(zo_iconFormat("esoui/art/icons/mapkey/mapkey_groupboss.dds",ICONSIZE,ICONSIZE))
    end
end

function ABB_CombinedBossBar:RefreshCombined(displayName,force)
    if force then self:ApplyStyle() end
    self.nameText:SetText(displayName)
    self.bossPercentages=SHAPER_THRESHOLDS
    self.bossMechanics=SHAPER_MECHANICS
    self.shouldWarn=true
    self.percentLinePool:ReleaseAllObjects()
    local lt,lh,lm="boss1",0,0
    for _,tag in ipairs(self.unitTags) do
        local h,m=GetUnitPower(tag,POWERTYPE_HEALTH)
        self.bossHealthsCurrent[tag]=h or 0
        self.bossHealthsMax[tag]=m or 0
        lt,lh,lm=tag,h or 0,m or 0
    end
    self:OnCombinedPowerUpdate(lt,lh,lm)
    self:UpdateWidth()
end


local REEF_GUARDIAN_NAMES = {
    ["Reef Guardian"] = true,
    ["Riffwächter"] = true,
    ["Gardien du récif"] = true,
    ["Guardián del arrecife"] = true,
}

local function IsReefGuardianName(name)
    if REEF_GUARDIAN_NAMES[name] then return true end
    -- Language-safe fallback for clients/localizations not listed above.
    local lowerName = zo_strlower(name or "")
    return string.find(lowerName, "reef guardian", 1, true) ~= nil
        or string.find(lowerName, "riffwächter", 1, true) ~= nil
end

local function FindBestLivingReefGuardian()
    local bestTag, bestHealth = nil, -1
    for i = 1, ABB_MAX_BOSSES do
        local tag = "boss" .. i
        if DoesUnitExist(tag) and IsReefGuardianName(GetUnitName(tag)) and not IsUnitDead(tag) then
            local health, maxHealth = GetUnitPower(tag, POWERTYPE_HEALTH)
            health = health or 0
            maxHealth = maxHealth or 0
            if maxHealth > 0 and health > 0 and health > bestHealth then
                bestTag = tag
                bestHealth = health
            end
        end
    end
    return bestTag
end

local function FindCombinedEncounter()
    for i=1,ABB_MAX_BOSSES do
        local tag="boss"..i
        if DoesUnitExist(tag) then
            local display=COMBINED_BOSS_NAMES[GetUnitName(tag)]
            if display then return display end
        end
    end
end

local bossBars = {}
local combinedBossBar

local function InitBars(topLevelCtrl)
    local prevBossBar

    for i = 1, ABB_MAX_BOSSES do
        local bossTag = "boss"..i
        bossBars[i] = ABB_BossBar:New(bossTag, topLevelCtrl, prevBossBar)
        prevBossBar = bossBars[i]
    end
    
    if SETTINGS.INCLUDE_DUMMY then
        bossBars[ABB_MAX_BOSSES + 1] = ABB_BossBar:New("reticleover", topLevelCtrl)
    end
    combinedBossBar = ABB_CombinedBossBar:New("bossCombined", topLevelCtrl)
    combinedBossBar:Hide()
end

local function ScaleBossBars()
    local highestHealthValue = 1
    local bossOrder = {}
    
    if SETTINGS.SCALE_HP_PROPORTION then
        for i = 1, ABB_MAX_BOSSES do
            local bossTag = "boss"..i
            local _, maxHealth = GetUnitPower(bossTag, POWERTYPE_HEALTH)
            table.insert(bossOrder, { tag = bossTag, maxhp = maxHealth})
            if maxHealth > highestHealthValue then
                highestHealthValue = maxHealth
            end
        end

        table.sort(bossOrder, function(a,b) return a.maxhp > b.maxhp end)
        for i, val in ipairs(bossOrder) do
            local bar = bossBars[i]
            if bar then
                bar:RegisterUnit(val.tag)
                bar.scaleX = zo_clamp(val.maxhp / highestHealthValue, 0.4, 1.0)
            end
        end
    else
        for i = 1, ABB_MAX_BOSSES do
            local bar = bossBars[i]
            if bar then
                bar.scaleX = 1.0
            end
        end
    end
end

local function RefreshAllBosses(forceReset)
    local lastBossBar
    local combinedName=FindCombinedEncounter()

    if combinedName and combinedBossBar then
        for i=1,ABB_MAX_BOSSES do
            if bossBars[i] then bossBars[i]:Hide() end
        end
        combinedBossBar:RefreshCombined(combinedName,forceReset)
        combinedBossBar:Show()
        lastBossBar=combinedBossBar
    else
        if combinedBossBar then combinedBossBar:Hide() end
        ScaleBossBars()

        local reefTag = FindBestLivingReefGuardian()
        if reefTag then
            -- Reef Guardian: show exactly one living guardian. Prefer the one
            -- with the highest current HP so the bar does not jump needlessly.
            for i=1,ABB_MAX_BOSSES do
                if bossBars[i] then bossBars[i]:Hide() end
            end

            local selectedBar = nil
            for i=1,ABB_MAX_BOSSES do
                local bar = bossBars[i]
                if bar and bar.unitTag == reefTag then
                    selectedBar = bar
                    break
                end
            end

            -- Unit tags can be reordered by ESO; reuse the first bar if needed.
            if not selectedBar and bossBars[1] then
                selectedBar = bossBars[1]
                selectedBar:RegisterUnit(reefTag)
            end

            if selectedBar then
                selectedBar:Refresh(forceReset)
                selectedBar:Show()
                lastBossBar = selectedBar
            end
        else
            for i=1,ABB_MAX_BOSSES do
            local bar=bossBars[i]
            if bar and DoesUnitExist(bar.unitTag) then
                bar:Refresh(forceReset)
                bar:Show()
                lastBossBar=bar
            elseif bar then
                bar:Hide()
                break
            end
            end
        end
    end

    if lastBossBar then
        local hideCompass = SETTINGS.REPLACE_COMPASS
        if lastBossBar and lastBossBar.unitTag == "reticleover" and SETTINGS.INCLUDE_DUMMY then
            hideCompass = true
        end
        COMPASS_FRAME_FRAGMENT:SetHiddenForReason("ABBar", hideCompass)
        AttachTargetTo(lastBossBar.control)
    else
        COMPASS_FRAME_FRAGMENT:SetHiddenForReason("ABBar")
        AttachTargetTo(ZO_CompassFrame)
    end
end

local function RefreshExtraBar()
    local i = ABB_MAX_BOSSES + 1
    local bar = bossBars[i]
    if not bar then return end
    local isDummy = GetUnitType(bar.unitTag) == 12
    if isDummy and DoesUnitExist(bar.unitTag) then
        bar:Refresh(forceReset)
        bar:Show()
        if SETTINGS.INCLUDE_DUMMY then
            COMPASS_FRAME_FRAGMENT:SetHiddenForReason("ABBar", true)
            AttachTargetTo(bar.control)
        end
    else
        bar:Hide()
    end
end

local function OnPlayerZoneChange(topLevelCtrl)
    if (GetCurrentZoneHouseId() > 0) and SETTINGS.INCLUDE_DUMMY then
        topLevelCtrl:RegisterForEvent(EVENT_RETICLE_TARGET_CHANGED, function() RefreshExtraBar() end)
    else
        topLevelCtrl:UnregisterForEvent(EVENT_RETICLE_TARGET_CHANGED)
    end
    RefreshAllBosses()
end

ABB_FakeGloss = ZO_Object:Subclass()
function ABB_FakeGloss:New()
    return ZO_Object.New(self)
end
function ABB_FakeGloss:SetMinMax() end
function ABB_FakeGloss:SetValue() end

local function SetVisualSettings()
    local offset = SETTINGS.REPLACE_COMPASS and 0 or ZO_CompassFrame:GetHeight()
    local container = GetControl("ABB_Container")
    container:ClearAnchors()
    container:SetAnchor(TOP, ZO_CompassFrame, TOP, 0, offset)
    ABB_TEMPLATE_NAME = THEMES[SETTINGS.THEME_NAME or "Plain"].template
    FN_ABB_GET_WIDTH = THEMES[SETTINGS.THEME_NAME or "Plain"].calcWidth
end

-------------------------------------
--Settings Menu--
-------------------------------------
local function InitializeAddonMenu()
    local LAM2 = LibAddonMenu2

    LAM2:RegisterAddonPanel("ABB_Settings", {
        type = "panel",
        name = "Alternative Boss Bars",
        displayName = "Alternative Boss Bars",
        author = "|c943810BulDeZir|r",
        version = string.format('|c00FF00%s|r', 3.1),
        registerForRefresh = true,
        registerForDefaults = true,
    })

    LAM2:RegisterOptionControls("ABB_Settings", {
        {
            type = "checkbox",
            name = "Replace compass",
            tooltip = "If turned off, HP bars will show under the compass instead of replacing it.",
            getFunc = function() return SETTINGS.REPLACE_COMPASS end,
            setFunc = function(newValue)
                SETTINGS.REPLACE_COMPASS = newValue
                SetVisualSettings()
                RefreshAllBosses(true)
            end,
            default = true,
        },
        {
            type = "checkbox",
            name = "Proportional Bars",
            tooltip = "Bosses with less max HP have shorter bars, and bars are sorted from most to least HP.",
            getFunc = function() return SETTINGS.SCALE_HP_PROPORTION end,
            setFunc = function(newValue)
                SETTINGS.SCALE_HP_PROPORTION = newValue
                RefreshAllBosses(true)
            end,
            default = false,
        },
        {
            type = "slider",
            name = "Bar Width",
            tooltip = "Makes every boss bar shorter or longer from left to right.",
            min = 50,
            max = 200,
            step = 5,
            getFunc = function() return zo_round((SETTINGS.WIDTH_SCALE or 1.0) * 100) end,
            setFunc = function(newValue)
                SETTINGS.WIDTH_SCALE = newValue / 100
                RefreshAllBosses(true)
            end,
            default = 100,
        },
        {
            type = "slider",
            name = "Bar Height",
            tooltip = "Makes every boss bar thinner or taller without changing its length.",
            min = 60,
            max = 200,
            step = 5,
            getFunc = function() return zo_round((SETTINGS.HEIGHT_SCALE or 1.0) * 100) end,
            setFunc = function(newValue)
                SETTINGS.HEIGHT_SCALE = newValue / 100
                RefreshAllBosses(true)
            end,
            default = 100,
        },
        {
            type = "checkbox",
            name = "Include Combat Dummies",
            requiresReload = true,
            tooltip = "Show boss bar when fighting a dummy.",
            getFunc = function() return SETTINGS.INCLUDE_DUMMY end,
            setFunc = function(newValue)
                SETTINGS.INCLUDE_DUMMY = newValue
            end,
            default = false,
        },
        {
            type = "divider",
            height = 5,
            alpha = 1,
            width = "full"
        },
        {
            type = "dropdown",
            name = "Percentage Line Style",
            requiresReload = true,
            choices = {"Hard", "Soft"},
            getFunc = function() return SETTINGS.PERCENTAGE_LINE_STYLE end,
            setFunc = function(newValue)
                SETTINGS.PERCENTAGE_LINE_STYLE = newValue
                RefreshAllBosses()
            end,
            default = "Hard"
        },
        {
            type = "checkbox",
            name = "Show Default Percent Lines (75%, 50%, 25%)",
            getFunc = function() return SETTINGS.SHOW_DEFAULTS end,
            setFunc = function(newValue)
                SETTINGS.SHOW_DEFAULTS = newValue
                RefreshAllBosses()
            end,
            default = false,
        },
        {
            type = "checkbox",
            name = "Alert Notification",
            tooltip = "Whether the HP bar displays an alert for percent-based mechanics.",
            getFunc = function() return SETTINGS.NOTIFY_ALERT end,
            setFunc = function(newValue)
                SETTINGS.NOTIFY_ALERT = newValue
                RefreshAllBosses()
            end,
            default = false,
            width = "half"
        },
        {
            type = "slider",
            name = "Threshold (%)",
            tooltip = "Number of percent (%), BEFORE showing alert.",
            min = 0,
            max = 5,
            step = 1,
            getFunc = function() return SETTINGS.NOTIFY_BEFORE_PERCENT end,
            setFunc = function(newValue)
                SETTINGS.NOTIFY_BEFORE_PERCENT = zo_round(newValue)
                RefreshAllBosses()
            end,
            disabled = function() return not SETTINGS.NOTIFY_ALERT end,
            default = 2,
            width = "half"
        },
        {
            type = "dropdown",
            name = "Alert Type",
            tooltip = "'Icon' displays an icon near the HP total. 'Flash' makes the bar flash red.",
            choices = {"Icon", "Flash"},
            getFunc = function() return SETTINGS.NOTIFY_ALERT_TYPE end,
            setFunc = function(newValue)
                SETTINGS.NOTIFY_ALERT_TYPE = newValue
            end,
            disabled = function() return not SETTINGS.NOTIFY_ALERT end,
            default = "Flash"
        },
        {
            type = "divider",
            height = 5,
            alpha = 1,
            width = "full"
        },
        {
            type = "colorpicker",
            name = "HP Color Gradient Start",
            getFunc = function() return unpack(SETTINGS.HP_COLOR_START) end,    --(alpha is optional)
            setFunc = function(r,g,b,a)
                SETTINGS.HP_COLOR_START = { r,g,b }
                RefreshAllBosses(true)
            end,
            width = "half",
            default = ZO_POWER_BAR_GRADIENT_COLORS[COMBAT_MECHANIC_FLAGS_HEALTH][1],
        },
        {
            type = "colorpicker",
            name = "HP Color Gradient End",
            getFunc = function() return unpack(SETTINGS.HP_COLOR_END) end,    --(alpha is optional)
            setFunc = function(r,g,b,a)
                SETTINGS.HP_COLOR_END = { r,g,b }
                RefreshAllBosses(true)
            end,
            width = "half",
            default = ZO_POWER_BAR_GRADIENT_COLORS[COMBAT_MECHANIC_FLAGS_HEALTH][2],
        },
        {
            type = "dropdown",
            name = "Theme",
            requiresReload = true,
            choices = {"Plain", "Embellished"},
            getFunc = function() return SETTINGS.THEME_NAME end,
            setFunc = function(newValue)
                SETTINGS.THEME_NAME = newValue
                RefreshAllBosses()
            end,
            default = "Plain"
        },
    })
end

function ABB_Initialize(topLevelCtrl)

    local function OnAddOnLoaded(_, addonName)
        if addonName == NAME then

            SETTINGS = ZO_SavedVars:NewAccountWide("AltBossBarSavedVariables", SV_VER, nil, {
                REPLACE_COMPASS = true,
                SHOW_DEFAULTS = false,
                INCLUDE_DUMMY = false,
                PERCENTAGE_LINE_STYLE = "Hard",
                NOTIFY_ALERT = false,
                NOTIFY_BEFORE_PERCENT = 2,
                NOTIFY_ALERT_TYPE = "Flash",
                SCALE_HP_PROPORTION = false,
                WIDTH_SCALE = 1.0,
                HEIGHT_SCALE = 1.0,
                HP_COLOR_START = DEFAULT_HP_COLOR_START,
                HP_COLOR_END = DEFAULT_HP_COLOR_END,
                THEME_NAME = "Plain"
            })

            if LibAddonMenu2 then
                InitializeAddonMenu()
            end

            if COMPASS_FRAME and COMPASS_FRAME.SetBossBarHiddenForReason then
                COMPASS_FRAME:SetBossBarHiddenForReason('modded', true)
            end
            local fragment = ZO_SimpleSceneFragment:New(topLevelCtrl)
            if HUD_SCENE then HUD_SCENE:AddFragment(fragment) end
            if HUD_UI_SCENE then HUD_UI_SCENE:AddFragment(fragment) end
            SetVisualSettings()

            InitBars(topLevelCtrl)
            local BHB = GetCrutchBossHealthBar()
            if BHB and BHB.RegisterThresholdsChangeListener then
                BHB.RegisterThresholdsChangeListener(NAME, function()
                    RefreshAllBosses(false)
                end)
            end
            topLevelCtrl:RegisterForEvent(EVENT_BOSSES_CHANGED, function(_, forceReset) RefreshAllBosses(forceReset) end)
            topLevelCtrl:RegisterForEvent(EVENT_PLAYER_ACTIVATED, function() OnPlayerZoneChange(topLevelCtrl) end)
            if EVENT_GAMEPAD_PREFERRED_MODE_CHANGED then
                topLevelCtrl:RegisterForEvent(EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function() RefreshAllBosses(true) end)
            end

            if CHAT_SYSTEM then
                CHAT_SYSTEM:AddMessage("|c66FF66[AltBossBar]|r Console Crutch v0.6 geladen. CrutchAlerts API: " .. ((BHB and BHB.GetBossThresholds) and "OK" or "NICHT GEFUNDEN"))
            end
        end
    end

    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
end
