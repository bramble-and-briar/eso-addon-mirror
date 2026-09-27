------------------------------------------------------------
-- RYTICTANK RESOURCE HUD v3.0 - module-isolated lifecycle
-- Event-driven resource tracking
--
-- Health:   bottom -> top (one continuous bar)
-- Health center notch: visual 50% marker only
-- Stamina:  center -> top
-- Magicka:  center -> bottom
------------------------------------------------------------

local RyticTank = RyticTank

RyticTank.Resources = {}
local Resources = RyticTank.Resources

-- Cache frequently used ESO globals/functions for resource update paths.
local EM = EVENT_MANAGER
local WM = WINDOW_MANAGER
local GetUnitPower = GetUnitPower
local tonumber = tonumber
local tostring = tostring
local math_floor = math.floor
local string_upper = string.upper
local string_sub = string.sub

local TEX = "RyticTankTools/textures/"

local THEME_TEXTURES = {
    FEMALE = {},
    MALE = {
        TEX.."male/male_tl.dds",
        TEX.."male/male_bl.dds",
        TEX.."male/male_tr.dds",
        TEX.."male/male_br.dds",
    },
}

local function NormalizeTheme(v)
    v=string_upper(tostring(v or "REGULAR"))
    if v~="MALE" and v~="FEMALE" then v="REGULAR" end
    return v
end


local ARC_W  = 128
local ARC_H  = 512
local HALF_H = 256

local HEALTH = {0.90, 0.05, 0.05}
local STAM   = {0.10, 0.90, 0.12}
local MAG    = {0.08, 0.32, 1.00}
local WARN   = {0.72, 0.18, 1.00}
local SHIELD = {1.00, 0.70, 0.70}

local function Clamp01(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

function Resources.GetPercent(powerType)
    -- ESO exposes current and maximum power from GetUnitPower.
    -- GetUnitPowerMax is not a valid function in this client/API.
    local current, maximum = GetUnitPower("player", powerType)
    current = tonumber(current) or 0
    maximum = tonumber(maximum) or 0
    if maximum <= 0 then return 0 end
    return (current / maximum) * 100
end

local function CommaNumber(value)
    local n = math_floor(tonumber(value) or 0)
    local s = tostring(n)
    local sign = ""
    if string_sub(s, 1, 1) == "-" then
        sign = "-"
        s = string_sub(s, 2)
    end
    while true do
        local changed
        s, changed = string.gsub(s, "^(%d+)(%d%d%d)", "%1,%2")
        if changed == 0 then break end
    end
    return sign .. s
end

local function ResourceText(powerType)
    local current = GetUnitPower("player", powerType) or 0
    return CommaNumber(current)
end

local function MakeTexture(parent, path)
    local c = WM:CreateControl(nil, parent, CT_TEXTURE)
    c:SetTexture(path)
    return c
end

local function SetColor(control, rgb)
    control:SetColor(rgb[1], rgb[2], rgb[3], 1)
end

-- Crop the ORIGINAL artwork instead of scaling the whole curve.
-- Bottom-up: bottom remains fixed and top moves down as resource is spent.
local function CropBottomUp(control, pct, width, fullHeight)
    local p = Clamp01(pct / 100)
    local h = math.max(1, fullHeight * p)
    control:SetDimensions(width, h)
    control:SetTextureCoords(0, 1, 1 - p, 1)
end

-- Top-down: top remains fixed and bottom moves up as resource is spent.
local function CropTopDown(control, pct, width, fullHeight)
    local p = Clamp01(pct / 100)
    local h = math.max(1, fullHeight * p)
    control:SetDimensions(width, h)
    control:SetTextureCoords(0, 1, 0, p)
end

-- Draw only the portion of the original curved health artwork between two
-- percentages. Used for the live shield segment above the current HP fill.
local function CropBottomSegment(control, startPct, endPct, width, fullHeight)
    local a = Clamp01((startPct or 0) / 100)
    local b = Clamp01((endPct or 0) / 100)

    if b <= a then
        control:SetHidden(true)
        return
    end

    local h = math.max(1, fullHeight * (b - a))
    control:SetDimensions(width, h)
    control:SetTextureCoords(0, 1, 1 - b, 1 - a)
    control:ClearAnchors()
    control:SetAnchor(BOTTOM, Resources.healthBack, BOTTOM, 0, -(fullHeight * a))
    control:SetHidden(false)
end

function Resources.CreateHUD()
    local wm = WM

    local hud = wm:CreateTopLevelWindow("RyticTankResourceHUD")
    Resources.window = hud
    Resources.hudFragment=RyticTank.UI.Attach(hud,function()
        local settings=RyticTank.saved.resources
        return settings.enabled~=false and not IsUnitDead("player") and
            (Resources.editMode or not settings.hideOutOfCombat or IsUnitInCombat("player"))
    end,function() Resources.RefreshAll() end)
    hud:SetDimensions(620, 560)
    hud:ClearAnchors()
    hud:SetAnchor(
        TOPLEFT, GuiRoot, TOPLEFT,
        RyticTank.saved.resources.position.x,
        RyticTank.saved.resources.position.y
    )
    hud:SetClampedToScreen(true)

    -- Robust edit mode. This does not depend on LibAddonMenu refreshing the lock state.
    Resources.editMode = false
    hud:SetMouseEnabled(true)
    hud:SetMovable(true)

    local function SaveHUDPosition()
        local left, top = hud:GetLeft(), hud:GetTop()
        if left and top then
            RyticTank.saved.resources.position.x = left
            RyticTank.saved.resources.position.y = top
        end
    end

    hud:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and Resources.editMode then
            hud:StartMoving()
        end
    end)
    hud:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and Resources.editMode then
            hud:StopMovingOrResizing()
            SaveHUDPosition()
        end
    end)


    -- HEALTH BACKGROUND
    local healthBack = MakeTexture(hud, TEX.."health_arc.dds")
    healthBack:SetDimensions(ARC_W, ARC_H)
    healthBack:SetAnchor(CENTER, hud, CENTER, -220, 0)
    healthBack:SetColor(0.03,0.03,0.035,0.78)
    Resources.healthBack = healthBack

    -- HEALTH FILL: bottom -> top
    local health = MakeTexture(hud, TEX.."health_arc.dds")
    health:SetDimensions(ARC_W, ARC_H)
    health:SetAnchor(BOTTOM, healthBack, BOTTOM, 0, 0)
    SetColor(health, HEALTH)
    Resources.healthBar = health

    -- DAMAGE SHIELD OVERLAY.
    -- Hyperioxes method: shield is its own max-health-scaled bar layered over health.
    local shield = MakeTexture(hud, TEX.."health_arc.dds")
    shield:SetDimensions(ARC_W, ARC_H)
    shield:SetAnchor(BOTTOM, healthBack, BOTTOM, 0, 0)
    shield:SetColor(SHIELD[1],SHIELD[2],SHIELD[3],0.60)
    shield:SetDrawLayer(DL_OVERLAY)
    shield:SetHidden(true)
    Resources.shieldBar = shield

    -- HEALTH 50% MARKER
    local hpMarker = wm:CreateControl(nil, hud, CT_BACKDROP)
    hpMarker:SetDimensions(22, 4)
    hpMarker:SetAnchor(CENTER, healthBack, CENTER, 12, 0)
    hpMarker:SetCenterColor(0.95,0.95,0.95,0.9)
    hpMarker:SetEdgeColor(0,0,0,0.9)
    Resources.healthMarker = hpMarker

    -- STAMINA BACKGROUND: upper right half
    local stamBack = MakeTexture(hud, TEX.."stamina_arc.dds")
    stamBack:SetDimensions(ARC_W, HALF_H)
    stamBack:SetAnchor(BOTTOM, hud, CENTER, 220, 0)
    stamBack:SetColor(0.03,0.03,0.035,0.78)
    Resources.staminaBack = stamBack

    -- STAMINA FILL: center -> top
    local stamina = MakeTexture(hud, TEX.."stamina_arc.dds")
    stamina:SetDimensions(ARC_W, HALF_H)
    stamina:SetAnchor(BOTTOM, stamBack, BOTTOM, 0, 0)
    SetColor(stamina, STAM)
    Resources.staminaBar = stamina

    -- MAGICKA BACKGROUND: lower right half
    local magBack = MakeTexture(hud, TEX.."magicka_arc.dds")
    magBack:SetDimensions(ARC_W, HALF_H)
    magBack:SetAnchor(TOP, hud, CENTER, 220, 0)
    magBack:SetColor(0.03,0.03,0.035,0.78)
    Resources.magickaBack = magBack

    -- MAGICKA FILL: center -> bottom
    local magicka = MakeTexture(hud, TEX.."magicka_arc.dds")
    magicka:SetDimensions(ARC_W, HALF_H)
    magicka:SetAnchor(TOP, magBack, TOP, 0, 0)
    SetColor(magicka, MAG)
    Resources.magickaBar = magicka

    -- RIGHT CENTER JOIN MARKER
    local join = wm:CreateControl(nil, hud, CT_BACKDROP)
    join:SetDimensions(22,4)
    join:SetAnchor(CENTER, hud, CENTER, 208, 0)
    join:SetCenterColor(0.95,0.95,0.95,0.9)
    join:SetEdgeColor(0,0,0,0.9)

    -- TEXT
    local hpText = wm:CreateControl(nil,hud,CT_LABEL)
    hpText:SetFont("ZoFontGameBold")
    hpText:SetDimensions(180,28)
    hpText:SetAnchor(CENTER,hud,CENTER,-125,0)
    hpText:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    Resources.healthText=hpText

    local stamText = wm:CreateControl(nil,hud,CT_LABEL)
    stamText:SetFont("ZoFontGameBold")
    stamText:SetDimensions(180,28)
    stamText:SetAnchor(CENTER,hud,CENTER,145,-60)
    stamText:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    Resources.staminaText=stamText

    local magText = wm:CreateControl(nil,hud,CT_LABEL)
    magText:SetFont("ZoFontGameBold")
    magText:SetDimensions(180,28)
    magText:SetAnchor(CENTER,hud,CENTER,145,60)
    magText:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    Resources.magickaText=magText

    local potion = wm:CreateControl(nil,hud,CT_LABEL)
    potion:SetFont("ZoFontWinH3")
    potion:SetDimensions(180,32)
    potion:SetAnchor(CENTER,hud,CENTER,0,95)
    potion:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    potion:SetText("")
    Resources.potionText=potion

    hud:SetHandler("OnMoveStop",function()
        local left,top=hud:GetLeft(),hud:GetTop()
        if left and top then
            RyticTank.saved.resources.position.x=left
            RyticTank.saved.resources.position.y=top
        end
    end)

    -- Cosmetic HUD themes.
    -- FEMALE uses Rytic's intact floral frame.
    -- MALE keeps the existing four-corner setup.
    local corners={}
    local anchors={
        {CENTER, healthBack, TOP,    -28,  18, false,false},
        {CENTER, healthBack, BOTTOM, -28, -18, false,true },
        {CENTER, stamBack,   TOP,     28,  18, true, false},
        {CENTER, magBack,    BOTTOM,  28, -18, true, true },
    }

    for i,a in ipairs(anchors) do
        local t=MakeTexture(hud,TEX.."male/male_tl.dds")
        t:SetDimensions(165,175)
        t:SetAnchor(a[1],a[2],a[3],a[4],a[5])
        t:SetDrawLayer(DL_OVERLAY)
        t:SetDrawTier(DT_HIGH)
        t:SetMouseEnabled(false)
        t:SetHidden(true)
        corners[i]=t
    end
    Resources.themeCorners=corners

    -- Rytic public floral frame: one intact texture on a 1024x1024 canvas.
    local ryticFloralBorder=MakeTexture(hud,TEX.."rytic/rytic_floral_border.dds")
    ryticFloralBorder:SetDimensions(669,611)
    ryticFloralBorder:SetTextureCoords(0,0.6533203125,0,0.5966796875)
    ryticFloralBorder:SetAnchor(CENTER,hud,CENTER,0,0)
    ryticFloralBorder:SetDrawLayer(DL_OVERLAY)
    ryticFloralBorder:SetDrawTier(DT_HIGH)
    ryticFloralBorder:SetMouseEnabled(false)
    ryticFloralBorder:SetHidden(true)
    Resources.ryticFloralBorder=ryticFloralBorder

    Resources.ApplyLock()
    Resources.ApplyTheme()
end

function Resources.SetEditMode(enabled)
    local hud=Resources.window
    if not hud then return end

    enabled = enabled and true or false
    Resources.editMode = enabled
    RyticTank.saved.resources.locked = not enabled

    hud:SetMovable(enabled)
    hud:SetMouseEnabled(enabled)

    -- Full-HUD drag catcher so curved textures/labels cannot swallow the drag.
    if not Resources.moveOverlay then
        local overlay=WM:CreateControl(nil,hud,CT_BACKDROP)
        overlay:SetAnchorFill(hud)
        overlay:SetCenterColor(0,0,0,0.06)
        overlay:SetEdgeColor(0.72,0.18,1,0.90)
        overlay:SetEdgeTexture("",1,1,2,0)
        overlay:SetDrawLayer(DL_OVERLAY)
        overlay:SetDrawTier(DT_HIGH)
        overlay:SetMouseEnabled(true)

        overlay:SetHandler("OnMouseDown",function(_,button)
            if button==MOUSE_BUTTON_INDEX_LEFT and Resources.editMode then
                hud:StartMoving()
            end
        end)

        overlay:SetHandler("OnMouseUp",function(_,button)
            if button==MOUSE_BUTTON_INDEX_LEFT and Resources.editMode then
                hud:StopMovingOrResizing()
                local left,top=hud:GetLeft(),hud:GetTop()
                if left and top then
                    RyticTank.saved.resources.position.x=left
                    RyticTank.saved.resources.position.y=top
                end
            end
        end)

        Resources.moveOverlay=overlay
    end

    if not Resources.moveLabel then
        local label=WM:CreateControl(nil,hud,CT_LABEL)
        label:SetFont("ZoFontWinH2")
        label:SetAnchor(TOP,hud,TOP,0,10)
        label:SetText("|cB82EFFRSS HUD UNLOCKED - DRAG ANYWHERE|r")
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetDrawLayer(DL_OVERLAY)
        label:SetDrawTier(DT_HIGH)
        Resources.moveLabel=label
    end

    Resources.moveOverlay:SetHidden(not enabled)
    Resources.moveLabel:SetHidden(not enabled)

    -- One visibility owner: edit mode changes state, then the normal RSS
    -- visibility routine decides whether the HUD may actually be shown.
    if Resources.Update then Resources.Update() end
end

function Resources.ApplyLock()
    local locked=RyticTank.saved.resources.locked
    if locked == nil then
        locked = true
        RyticTank.saved.resources.locked = true
    end
    Resources.SetEditMode(not locked)
end

function Resources.ResetPosition()
    local hud=Resources.window
    if not hud then return end

    -- Known visible default location.
    local x,y=650,250
    RyticTank.saved.resources.position.x=x
    RyticTank.saved.resources.position.y=y
    hud:ClearAnchors()
    hud:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,x,y)
    -- Re-evaluate normal visibility instead of forcing a disabled/OOC HUD visible.
    if Resources.Update then
        Resources.Update()
    end
end

function Resources.ApplyTheme()
    local corners=Resources.themeCorners
    if not corners then return end

    local theme=NormalizeTheme(RyticTank.saved.resources.theme)
    RyticTank.saved.resources.theme=theme
    local textures=THEME_TEXTURES[theme]
    local fullBorder=Resources.ryticFloralBorder

    -- FEMALE uses Rytic's intact floral border.
    -- MALE and REGULAR behavior stay unchanged.
    if fullBorder then
        fullBorder:SetHidden(theme ~= "FEMALE")
    end

    for i,t in ipairs(corners) do
        if textures and theme ~= "FEMALE" then
            t:SetTexture(textures[i])
            -- Male uses four pre-oriented DDS files.
            -- Keep ESO texture coordinates standard; no runtime mirroring.
            t:SetTextureCoords(0,1,0,1)
            t:SetAlpha(1)
            t:SetHidden(false)
        else
            t:SetHidden(true)
        end
    end
end

-- Apply the saved Resource HUD scale to the entire curved RSS window.
function Resources.ApplyScale()
    local hud = Resources.window
    if not hud then return end
    local scale = tonumber(RyticTank.saved.resources.scale) or 1.0
    hud:SetScale(scale)
end

local function UpdateVisibility()
    return Resources.window and RyticTank.UI.Refresh(Resources.window) or false
end

local function SetTrackedShield(value)
    value=math.max(0,tonumber(value) or 0)
    Resources.currentShield=value
    Resources.shieldTracked=true
end

local function OnShieldVisual(eventCode,unitTag,unitAttributeVisual,statType,attributeType,powerType,v1,v2,v3,v4)
    if unitTag~="player"
        or unitAttributeVisual~=ATTRIBUTE_VISUAL_POWER_SHIELDING
        or attributeType~=ATTRIBUTE_HEALTH
        or powerType~=POWERTYPE_HEALTH then
        return
    end

    local current=math.max(0,tonumber(Resources.currentShield) or 0)

    if eventCode==EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED then
        current=current+math.max(0,tonumber(v1) or 0)
    elseif eventCode==EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED then
        current=current-math.max(0,tonumber(v1) or 0)
    elseif eventCode==EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED then
        -- UPDATED supplies oldValue,newValue,oldMaxValue,newMaxValue.
        current=current+((tonumber(v2) or 0)-(tonumber(v1) or 0))
    end

    SetTrackedShield(current)
    Resources.UpdateShield()
end

function Resources.UpdateShield()
    local bar=Resources.shieldBar
    if not bar then return end

    local currentHealth,maxHealth=GetUnitPower("player",POWERTYPE_HEALTH)
    currentHealth=tonumber(currentHealth) or 0
    maxHealth=tonumber(maxHealth) or 0

    local shield
    if Resources.shieldTracked then
        shield=math.max(0,tonumber(Resources.currentShield) or 0)
    elseif GetUnitAttributeVisualizerEffectInfo then
        shield=GetUnitAttributeVisualizerEffectInfo(
            "player",
            ATTRIBUTE_VISUAL_POWER_SHIELDING,
            STAT_MITIGATION,
            ATTRIBUTE_HEALTH,
            POWERTYPE_HEALTH
        )
        shield=math.max(0,tonumber(shield) or 0)
        SetTrackedShield(shield)
    else
        shield=0
    end

    if maxHealth<=0 or shield<=0 then
        SetTrackedShield(0)
        bar:SetHidden(true)
        return
    end

    local hpPct=(currentHealth/maxHealth)*100
    local shieldPct=(shield/maxHealth)*100
    local startPct=math.max(0,hpPct-shieldPct)

    CropBottomSegment(bar,startPct,hpPct,ARC_W,ARC_H)
    bar:SetColor(SHIELD[1],SHIELD[2],SHIELD[3],0.88)
end

function Resources.UpdateHealth(pct)
    if not Resources.healthBar then return end
    local s=RyticTank.saved.resources

    Resources.healthBar:ClearAnchors()
    Resources.healthBar:SetAnchor(
        BOTTOM,Resources.healthBack,BOTTOM,0,0)
    CropBottomUp(Resources.healthBar,pct,ARC_W,ARC_H)

    local threshold = tonumber(s.potionHealthThreshold) or tonumber(s.potionThreshold) or tonumber(s.warningHealth) or 30
    if pct <= threshold then SetColor(Resources.healthBar,WARN)
    else SetColor(Resources.healthBar,HEALTH) end

    Resources.UpdateShield()
    local current=GetUnitPower("player",POWERTYPE_HEALTH) or 0
    local shield=math.max(0,tonumber(Resources.currentShield) or 0)
    if shield>0 then
        Resources.healthText:SetText(
            string.format("%s +%s",CommaNumber(current),CommaNumber(shield)))
    else
        Resources.healthText:SetText(CommaNumber(current))
    end
end

function Resources.UpdateStamina(pct)
    if not Resources.staminaBar then return end
    local s=RyticTank.saved.resources

    Resources.staminaBar:ClearAnchors()
    Resources.staminaBar:SetAnchor(
        BOTTOM,Resources.staminaBack,BOTTOM,0,0)
    CropBottomUp(Resources.staminaBar,pct,ARC_W,HALF_H)

    local threshold = tonumber(s.potionResourceThreshold) or tonumber(s.potionThreshold) or tonumber(s.warningStamina) or 30
    if pct <= threshold then SetColor(Resources.staminaBar,WARN)
    else SetColor(Resources.staminaBar,STAM) end

    Resources.staminaText:SetText(ResourceText(POWERTYPE_STAMINA))
end

function Resources.UpdateMagicka(pct)
    if not Resources.magickaBar then return end
    local s=RyticTank.saved.resources

    Resources.magickaBar:ClearAnchors()
    Resources.magickaBar:SetAnchor(
        TOP,Resources.magickaBack,TOP,0,0)
    CropTopDown(Resources.magickaBar,pct,ARC_W,HALF_H)

    local threshold = tonumber(s.potionResourceThreshold) or tonumber(s.potionThreshold) or tonumber(s.warningMagicka) or 30
    if pct <= threshold then SetColor(Resources.magickaBar,WARN)
    else SetColor(Resources.magickaBar,MAG) end

    Resources.magickaText:SetText(ResourceText(POWERTYPE_MAGICKA))
end

function Resources.GetPotionCooldown()
    if not GetCurrentQuickslot or not GetSlotCooldownInfo then return 0,true end
    local quickslot=GetCurrentQuickslot()
    if not quickslot then return 0,true end
    local remaining,duration,globalCooldown,isUsable =
        GetSlotCooldownInfo(quickslot,HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    return remaining or 0,isUsable
end

function Resources.UpdatePotion()
    if not Resources.potionText then return end
    local s=RyticTank.saved.resources
    local combat=IsUnitInCombat("player")

    Resources.potionText:SetText("")
    if not s.potionAlert then return end
    if s.potionCombatOnly and not combat then return end

    local hp=Resources.GetPercent(POWERTYPE_HEALTH)
    local stam=Resources.GetPercent(POWERTYPE_STAMINA)
    local mag=Resources.GetPercent(POWERTYPE_MAGICKA)

    local healthThreshold = tonumber(s.potionHealthThreshold) or tonumber(s.potionThreshold) or 30
    local resourceThreshold = tonumber(s.potionResourceThreshold) or tonumber(s.potionThreshold) or 30

    local trigger =
        (s.potionHealth and hp <= healthThreshold) or
        (s.potionStamina and stam <= resourceThreshold) or
        (s.potionMagicka and mag <= resourceThreshold)

    if not trigger then return end

    local cooldown,usable=Resources.GetPotionCooldown()
    if cooldown <= 0 and usable ~= false then
        Resources.potionText:SetText("|cFF3300TRI-POT|r")
    elseif not s.potionReadyOnly then
        Resources.potionText:SetText(
            string.format("|cFFAA00POTION %.1fs|r",cooldown/1000))
    end
end

local function EnsureArcTextures()
    local R=RyticTank.Resources
    if not R.window then return end

    -- Reassert the three shipped RSS textures and their base geometry.
    -- This makes the curved bars self-healing if another UI state/addon leaves
    -- one of the texture controls hidden or with stale texture coordinates.
    if R.healthBack then
        R.healthBack:SetTexture(TEX.."health_arc.dds")
        R.healthBack:SetDimensions(ARC_W,ARC_H)
        R.healthBack:SetTextureCoords(0,1,0,1)
        R.healthBack:SetHidden(false)
        R.healthBack:SetColor(0.03,0.03,0.035,0.78)
    end
    if R.healthBar then
        R.healthBar:SetTexture(TEX.."health_arc.dds")
        R.healthBar:SetHidden(false)
    end
    if R.staminaBack then
        R.staminaBack:SetTexture(TEX.."stamina_arc.dds")
        R.staminaBack:SetDimensions(ARC_W,HALF_H)
        R.staminaBack:SetTextureCoords(0,1,0,1)
        R.staminaBack:SetHidden(false)
        R.staminaBack:SetColor(0.03,0.03,0.035,0.78)
    end
    if R.staminaBar then
        R.staminaBar:SetTexture(TEX.."stamina_arc.dds")
        R.staminaBar:SetHidden(false)
    end
    if R.magickaBack then
        R.magickaBack:SetTexture(TEX.."magicka_arc.dds")
        R.magickaBack:SetDimensions(ARC_W,HALF_H)
        R.magickaBack:SetTextureCoords(0,1,0,1)
        R.magickaBack:SetHidden(false)
        R.magickaBack:SetColor(0.03,0.03,0.035,0.78)
    end
    if R.magickaBar then
        R.magickaBar:SetTexture(TEX.."magicka_arc.dds")
        R.magickaBar:SetHidden(false)
    end
end

function Resources.RefreshAll()
    if not UpdateVisibility() then return end
    EnsureArcTextures()
    Resources.ApplyTheme()
    Resources.UpdateHealth(
        Resources.GetPercent(POWERTYPE_HEALTH))
    Resources.UpdateStamina(
        Resources.GetPercent(POWERTYPE_STAMINA))
    Resources.UpdateMagicka(
        Resources.GetPercent(POWERTYPE_MAGICKA))
    Resources.UpdateShield()
    Resources.UpdatePotion()
end

-- Kept for compatibility with the current Settings menu.
function Resources.Update()
    local enabled = RyticTank.saved.resources.enabled ~= false
    if enabled ~= (Resources.eventsRegistered == true) then
        Resources.SetEnabled(enabled)
    end
    if not enabled then return end

    if not UpdateVisibility() then return end
    Resources.UpdatePotion()
    Resources.UpdateShield()

    -- Shield expiration does not necessarily fire a health power update.
    -- Refresh the HP label here so +Shield disappears immediately.
    if Resources.healthText then
        local current=GetUnitPower("player",POWERTYPE_HEALTH)
        current=tonumber(current) or 0
        local shield=math.max(0,tonumber(Resources.currentShield) or 0)

        if shield>0 then
            Resources.healthText:SetText(
                string.format("%s +%s",CommaNumber(current),CommaNumber(shield)))
        else
            Resources.healthText:SetText(CommaNumber(current))
        end
    end
end

local function OnPowerUpdate(
    eventCode, unitTag, powerIndex, powerType,
    powerValue, powerMax, powerEffectiveMax
)
    if unitTag ~= "player" then return end
    local maxValue = powerEffectiveMax or powerMax
    if not maxValue or maxValue <= 0 then return end

    local pct=(powerValue/maxValue)*100

    if powerType == POWERTYPE_HEALTH then
        Resources.UpdateHealth(pct)
    elseif powerType == POWERTYPE_STAMINA then
        Resources.UpdateStamina(pct)
    elseif powerType == POWERTYPE_MAGICKA then
        Resources.UpdateMagicka(pct)
    end

    Resources.UpdatePotion()
    Resources.UpdateShield()
end

local function OnCombatState()
    Resources.RefreshAll()
end

-- Module lifecycle helpers.  The Settings menu already changes
-- saved.resources.enabled and calls Resources.Update().  Keep that public
-- contract, but make Update() perform a real start/stop instead of only hiding.
local function RegisterResourceEvents()
    if Resources.eventsRegistered then return end

    EM:RegisterForEvent(
        "RyticTankResourcePower",
        EVENT_POWER_UPDATE,
        OnPowerUpdate
    )
    EM:AddFilterForEvent(
        "RyticTankResourcePower",
        EVENT_POWER_UPDATE,
        REGISTER_FILTER_UNIT_TAG,
        "player"
    )

    EM:RegisterForEvent(
        "RyticTankResourceCombat",
        EVENT_PLAYER_COMBAT_STATE,
        OnCombatState
    )

    -- Refresh visibility immediately on death/resurrection instead of waiting
    -- for a power or combat-state update.
    if EVENT_PLAYER_DEAD then
        EM:RegisterForEvent("RyticTankResourceDead", EVENT_PLAYER_DEAD, OnCombatState)
    end
    if EVENT_PLAYER_ALIVE then
        EM:RegisterForEvent("RyticTankResourceAlive", EVENT_PLAYER_ALIVE, OnCombatState)
    end

    if EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED then
        EM:RegisterForEvent("RyticTankShieldAdded",EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED,OnShieldVisual)
        EM:RegisterForEvent("RyticTankShieldUpdated",EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED,OnShieldVisual)
        EM:RegisterForEvent("RyticTankShieldRemoved",EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED,OnShieldVisual)
    end

    Resources.eventsRegistered = true
end

local function UnregisterResourceEvents()
    EM:UnregisterForEvent("RyticTankResourcePower", EVENT_POWER_UPDATE)
    EM:UnregisterForEvent("RyticTankResourceCombat", EVENT_PLAYER_COMBAT_STATE)
    if EVENT_PLAYER_DEAD then
        EM:UnregisterForEvent("RyticTankResourceDead", EVENT_PLAYER_DEAD)
    end
    if EVENT_PLAYER_ALIVE then
        EM:UnregisterForEvent("RyticTankResourceAlive", EVENT_PLAYER_ALIVE)
    end
    if EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED then
        EM:UnregisterForEvent("RyticTankShieldAdded", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED)
        EM:UnregisterForEvent("RyticTankShieldUpdated", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED)
        EM:UnregisterForEvent("RyticTankShieldRemoved", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED)
    end
    Resources.eventsRegistered = false
end

function Resources.SetHideOutOfCombat(enabled)
    RyticTank.saved.resources.hideOutOfCombat = enabled and true or false
    UpdateVisibility()
end

function Resources.SetEnabled(enabled)
    enabled = enabled and true or false
    RyticTank.saved.resources.enabled = enabled

    if enabled then
        Resources.shieldTracked=false
        RegisterResourceEvents()
        Resources.RefreshAll()
    else
        UnregisterResourceEvents()
        -- OFF is authoritative; the fragment remains attached so scene lifecycle
        -- stays stable, while UpdateVisibility keeps the RSS control hidden.
        UpdateVisibility()
        if Resources.moveOverlay then
            Resources.moveOverlay:SetHidden(true)
        end
        if Resources.moveLabel then
            Resources.moveLabel:SetHidden(true)
        end
        if Resources.potionText then
            Resources.potionText:SetText("")
        end
    end
end


function Resources.Initialize()
    if not RyticTank.saved.resources then
        RyticTank.saved.resources=ZO_DeepTableCopy(RyticTank.defaults.resources)
    end
    if not RyticTank.saved.resources.position then
        RyticTank.saved.resources.position={x=650,y=250}
    end
    if RyticTank.saved.resources.theme==nil then
        RyticTank.saved.resources.theme="REGULAR"
    end

    Resources.CreateHUD()
    Resources.ApplyScale()
    Resources.ApplyLock()

    SLASH_COMMANDS["/rssrepair"] = function()
        EnsureArcTextures()
        Resources.ApplyTheme()
        Resources.RefreshAll()
        d("|c00FF00RyticTankTools RSS textures refreshed.|r")
    end

    SLASH_COMMANDS["/rssmove"] = function()
        local nextState = not Resources.editMode
        Resources.SetEditMode(nextState)
        if nextState then
            d("|cB82EFFRyticTank Resource HUD MOVE MODE ON - drag anywhere in the HUD. Type /rssmove again when finished.|r")
        else
            d("|c00FF00RyticTank Resource HUD position saved. MOVE MODE OFF.|r")
        end
    end

    -- Start only when enabled.  OFF means this module owns no resource/combat/shield events.
    Resources.eventsRegistered = false

    -- Older builds could leave resources.preview=true in SavedVariables even though
    -- RSS has no Preview control.  That stale flag bypassed Hide Out of Combat.
    -- Movement/edit mode is now the sole intentional visibility override.
    RyticTank.saved.resources.preview = false

    Resources.SetEnabled(RyticTank.saved.resources.enabled ~= false)
end
