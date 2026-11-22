-- RSS Theme Bars

local ADDON = "RSSThemeBars"
local DISPLAY = "RSS Theme Bars"
local EM = EVENT_MANAGER
local WM = WINDOW_MANAGER
local TEX = "RSSThemeBars/textures/"

-- Approved resource-bar geometry -- do not change without explicit approval.
local ARC_W, ARC_H, RIGHT_H, OVERLAP = 128, 512, 272, 32
local HEALTH = {0.95, 0.08, 0.08}
local STAM   = {0.05, 0.88, 0.28}
local MAG    = {0.12, 0.32, 1.00}

local defaults = { enabled=true, locked=true, scale=100, theme="Default", x=0, y=0, winterGap=0, themeGap=0, ghostfireColor={0.10,1.0,0.20}, straightPositions={} }
local Bars, saved = {}, nil
local STRAIGHT_DEFAULTS = { health={x=-350,y=0}, magicka={x=0,y=0}, stamina={x=350,y=0} }
local STRAIGHT_WIDTH, STRAIGHT_HEIGHT = 320, 76
-- Grouped themes share the same screen-relative TOP of their resource bars.
local GROUP_BAR_DEFAULT_Y = 220
local GROUP_BAR_W = {magicka=260, health=299, stamina=266}
local function groupedDefaultY(height, barTop)
    return GROUP_BAR_DEFAULT_Y + height/2 - barTop
end
local function resetGroupedPosition(group, key, height, barTop)
    local y = groupedDefaultY(height, barTop)
    saved[key]={x=0,y=y}
    if group then group:ClearAnchors(); group:SetAnchor(CENTER,GuiRoot,CENTER,0,y) end
end
local THEMES = {"Default", "Dragon", "Halloween", "Spooky Cute", "Hibiscus", "Sunflower", "Swords", "Winter", "Stardust Dragon", "Ghostfire", "Simple Glow", "Enchanted Butterfly", "Fairy Garden", "Frozen Elegance", "Moonlit Magic", "Midnight Wings", "Golden Dragon"}
local hudFragment, playerDead = nil, false
local ghostfireTick = 0
local function applyGhostfireColor()
    if not Bars.ghostfire then return end
    local c = saved and saved.ghostfireColor or defaults.ghostfireColor
    for _,fire in ipairs(Bars.ghostfire) do
        fire:SetColor(c[1] or 0.10,c[2] or 1,c[3] or 0.20,1)
    end
    if Bars.ghostfireGlow then
        for _,glow in ipairs(Bars.ghostfireGlow) do
            glow:SetColor(c[1] or 0.10,c[2] or 1,c[3] or 0.20,1)
        end
    end
end

local function clamp(v) if v < 0 then return 0 elseif v > 1 then return 1 end return v end
local function makeTexture(parent,path) local t=WM:CreateControl(nil,parent,CT_TEXTURE); t:SetTexture(path); return t end
local function tint(t,c,a) t:SetColor(c[1],c[2],c[3],a or 1) end

local function cropBottomUp(control,pct,width,fullHeight)
    local p=clamp((pct or 0)/100); local h=math.max(1,fullHeight*p)
    control:SetDimensions(width,h); control:SetTextureCoords(0,1,1-p,1)
end
local function cropTopDown(control,pct,width,fullHeight)
    local p=clamp((pct or 0)/100); local h=math.max(1,fullHeight*p)
    control:SetDimensions(width,h); control:SetTextureCoords(0,1,0,p)
end
local function percent(powerType)
    local current,maximum=GetUnitPower("player",powerType); current,maximum=tonumber(current) or 0,tonumber(maximum) or 0
    if maximum<=0 then return 0 end return (current/maximum)*100
end
local function commaNumber(value)
    local n=math.floor(tonumber(value) or 0)
    local str=tostring(n)
    while true do
        local changed
        str,changed=string.gsub(str,"^(%d+)(%d%d%d)","%1,%2")
        if changed==0 then break end
    end
    return str
end
local function resourceText(powerType)
    local current=GetUnitPower("player",powerType) or 0
    return commaNumber(current)
end
local function setResourceLabelText(mainLabel, glowLabels, text)
    if mainLabel then mainLabel:SetText(text) end
    if glowLabels then
        for _,label in ipairs(glowLabels) do label:SetText(text) end
    end
end
-- Straight-bar fill uses the same power events and numeric values as curved bars.
local function updateStraight(key,pct)
    local items = {Bars.straight and Bars.straight[key], Bars.moonBars and Bars.moonBars[key], Bars.midnightBars and Bars.midnightBars[key], Bars.goldenBars and Bars.goldenBars[key], Bars.simpleGroupBars and Bars.simpleGroupBars[key], Bars.fairyBars and Bars.fairyBars[key], Bars.frozenBars and Bars.frozenBars[key], Bars.lunarBars and Bars.lunarBars[key]}
    for _,item in pairs(items) do
    if item then
    local p = clamp((pct or 0)/100)
    local width = item.width or STRAIGHT_WIDTH
    local visible = math.max(0.01, width*p)
    for _,texture in ipairs({item.fill,item.glow}) do
        texture:SetWidth(visible)
        texture:SetTextureCoords(0,p,0,1)
        texture:SetHidden(p<=0)
    end
    item.number:SetText(resourceText(item.power))
    for _,label in ipairs(item.numberGlows) do label:SetText(resourceText(item.power)) end
    end
    end
end

local function updateHealth(pct)
    setResourceLabelText(Bars.healthText,Bars.healthGlowText,resourceText(POWERTYPE_HEALTH))
    updateStraight("health",pct)
    Bars.healthGlow:ClearAnchors(); Bars.healthGlow:SetAnchor(BOTTOM,Bars.healthBack,BOTTOM,0,0); cropBottomUp(Bars.healthGlow,pct,ARC_W,ARC_H)
    Bars.health:ClearAnchors(); Bars.health:SetAnchor(BOTTOM,Bars.healthBack,BOTTOM,0,0); cropBottomUp(Bars.health,pct,ARC_W,ARC_H)
    if Bars.winterHealthGlow then
        Bars.winterHealthGlow:ClearAnchors(); Bars.winterHealthGlow:SetAnchor(BOTTOM,Bars.healthBack,BOTTOM,0,0); cropBottomUp(Bars.winterHealthGlow,pct,ARC_W,ARC_H)
    end
    if Bars.winterHealth then
        Bars.winterHealth:ClearAnchors(); Bars.winterHealth:SetAnchor(BOTTOM,Bars.healthBack,BOTTOM,0,0); cropBottomUp(Bars.winterHealth,pct,ARC_W,ARC_H)
    end
end
local function updateStamina(pct)
    setResourceLabelText(Bars.staminaText,Bars.staminaGlowText,resourceText(POWERTYPE_STAMINA))
    updateStraight("stamina",pct)
    Bars.staminaGlow:ClearAnchors(); Bars.staminaGlow:SetAnchor(BOTTOM,Bars.staminaBack,BOTTOM,0,0); cropBottomUp(Bars.staminaGlow,pct,ARC_W,RIGHT_H)
    Bars.stamina:ClearAnchors(); Bars.stamina:SetAnchor(BOTTOM,Bars.staminaBack,BOTTOM,0,0); cropBottomUp(Bars.stamina,pct,ARC_W,RIGHT_H)
end
local function updateMagicka(pct)
    setResourceLabelText(Bars.magickaText,Bars.magickaGlowText,resourceText(POWERTYPE_MAGICKA))
    updateStraight("magicka",pct)
    Bars.magickaGlow:ClearAnchors(); Bars.magickaGlow:SetAnchor(TOP,Bars.magickaBack,TOP,0,0); cropTopDown(Bars.magickaGlow,pct,ARC_W,RIGHT_H)
    Bars.magicka:ClearAnchors(); Bars.magicka:SetAnchor(TOP,Bars.magickaBack,TOP,0,0); cropTopDown(Bars.magicka,pct,ARC_W,RIGHT_H)
end
local function refresh()
    updateHealth(percent(POWERTYPE_HEALTH)); updateStamina(percent(POWERTYPE_STAMINA)); updateMagicka(percent(POWERTYPE_MAGICKA))
end
local function onPower(_,unitTag,_,powerType,value,maxValue,effectiveMax)
    local m=effectiveMax or maxValue; if not m or m<=0 then return end
    local pct=(value/m)*100
    if powerType==POWERTYPE_HEALTH then updateHealth(pct)
    elseif powerType==POWERTYPE_STAMINA then updateStamina(pct)
    elseif powerType==POWERTYPE_MAGICKA then updateMagicka(pct) end
end

local function fragmentShown()
    return hudFragment and hudFragment:GetState() == SCENE_FRAGMENT_SHOWN
end

local function applyVisibility()
    if not Bars.hud then return end
    local shouldHide = (not saved.enabled) or playerDead or IsUnitDead("player") or (hudFragment and not fragmentShown())
    Bars.hud:SetHidden(shouldHide)
    if Bars.straight then
        for _,bar in pairs(Bars.straight) do
            bar.control:SetHidden(true) -- Legacy independent bars retained, replaced by matching group
        end
    end
    if Bars.moonGroup then Bars.moonGroup:SetHidden(shouldHide or saved.theme ~= "Enchanted Butterfly") end
    if Bars.midnightGroup then Bars.midnightGroup:SetHidden(shouldHide or saved.theme ~= "Midnight Wings") end
    if Bars.goldenGroup then Bars.goldenGroup:SetHidden(shouldHide or saved.theme ~= "Golden Dragon") end
    if Bars.simpleGroup then Bars.simpleGroup:SetHidden(shouldHide or saved.theme ~= "Simple Glow") end
    if Bars.fairyGroup then Bars.fairyGroup:SetHidden(shouldHide or saved.theme ~= "Fairy Garden") end
    if Bars.frozenGroup then Bars.frozenGroup:SetHidden(shouldHide or saved.theme ~= "Frozen Elegance") end
    if Bars.lunarGroup then Bars.lunarGroup:SetHidden(shouldHide or saved.theme ~= "Moonlit Magic") end
end

local function applyScale()
    if Bars.hud then Bars.hud:SetScale((saved.scale or 100)/100) end
    if Bars.straight then
        for key,bar in pairs(Bars.straight) do
            bar.control:SetScale((saved.scale or 100)/100)
        end
    end
    if Bars.moonGroup then Bars.moonGroup:SetScale((saved.scale or 100)/100) end
    if Bars.midnightGroup then Bars.midnightGroup:SetScale((saved.scale or 100)/100) end
    if Bars.goldenGroup then Bars.goldenGroup:SetScale((saved.scale or 100)/100) end
    if Bars.simpleGroup then Bars.simpleGroup:SetScale((saved.scale or 100)/100) end
    if Bars.fairyGroup then Bars.fairyGroup:SetScale((saved.scale or 100)/100) end
    if Bars.frozenGroup then Bars.frozenGroup:SetScale((saved.scale or 100)/100) end
    if Bars.lunarGroup then Bars.lunarGroup:SetScale((saved.scale or 100)/100) end
end

-- Move both bar groups and their corresponding theme decorations symmetrically.
-- The right stamina/magicka pair retains its original relative alignment.
local function applyThemeGap()
    if not Bars.hud or not saved then return end
    local gap = (saved.theme == "Winter") and (tonumber(saved.winterGap) or 0) or (tonumber(saved.themeGap) or 0)
    gap = math.max(0, math.min(40, gap))
    local hud = Bars.hud
    if Bars.healthBack then
        Bars.healthBack:ClearAnchors()
        Bars.healthBack:SetAnchor(CENTER,hud,CENTER,-190-gap,0)
    end
    if Bars.staminaBack then
        Bars.staminaBack:ClearAnchors()
        Bars.staminaBack:SetAnchor(BOTTOM,hud,CENTER,190+gap,OVERLAP/2)
    end
    if Bars.magickaBack then
        Bars.magickaBack:ClearAnchors()
        Bars.magickaBack:SetAnchor(TOP,hud,CENTER,190+gap,-OVERLAP/2)
    end
    if Bars.winterLeft then
        Bars.winterLeft:ClearAnchors()
        Bars.winterLeft:SetAnchor(CENTER,hud,CENTER,-140-gap,0)
    end
    if Bars.winterRight then
        Bars.winterRight:ClearAnchors()
        Bars.winterRight:SetAnchor(CENTER,hud,CENTER,140+gap,0)
    end
    -- Reposition theme-specific cropped slices, keeping the center bat fixed.
    if Bars.splitThemes then
        for _, pieces in pairs(Bars.splitThemes) do
            for _, part in ipairs(pieces) do
                part.control:ClearAnchors()
                part.control:SetAnchor(CENTER,hud,CENTER,part.x + (part.side * gap),0)
            end
        end
    end
    for _,group in ipairs({{Bars.healthText,Bars.healthGlowText,-110,-gap},
                            {Bars.staminaText,Bars.staminaGlowText,0,gap},
                            {Bars.magickaText,Bars.magickaGlowText,110,gap}}) do
        local label, glows, x, shift = group[1],group[2],group[3],group[4]
        if label then
            label:ClearAnchors()
            label:SetAnchor(CENTER,hud,CENTER,x+shift,-165)
        end
        if glows then
            for _,g in ipairs(glows) do
                -- Preserve each glow's original offset relative to the main label.
                local offsets = Bars.labelGlowOffsets and Bars.labelGlowOffsets[g] or {0,0}
                local dx,dy = offsets[1],offsets[2]
                g:ClearAnchors()
                g:SetAnchor(CENTER,hud,CENTER,x+shift+dx,-165+dy)
            end
        end
    end
end

local function applyLock()
    if not Bars.hud then return end
    local unlocked = not saved.locked
    Bars.hud:SetMovable(unlocked and saved.theme ~= "Simple Glow" and saved.theme ~= "Enchanted Butterfly" and saved.theme ~= "Fairy Garden" and saved.theme ~= "Frozen Elegance")
    Bars.hud:SetMouseEnabled(unlocked and saved.theme ~= "Simple Glow" and saved.theme ~= "Enchanted Butterfly" and saved.theme ~= "Fairy Garden" and saved.theme ~= "Frozen Elegance")
    if Bars.moveOverlay then
        Bars.moveOverlay:SetMouseEnabled(unlocked and saved.theme ~= "Simple Glow" and saved.theme ~= "Enchanted Butterfly" and saved.theme ~= "Fairy Garden" and saved.theme ~= "Frozen Elegance")
        Bars.moveOverlay:SetHidden(saved.theme == "Simple Glow" or saved.theme == "Enchanted Butterfly" or saved.theme == "Fairy Garden" or saved.theme == "Frozen Elegance" or saved.theme == "Moonlit Magic" or saved.theme == "Midnight Wings" or saved.theme == "Golden Dragon" or not unlocked)
    end
    if Bars.moveHint then Bars.moveHint:SetHidden(saved.theme == "Simple Glow" or saved.theme == "Enchanted Butterfly" or saved.theme == "Fairy Garden" or saved.theme == "Frozen Elegance" or saved.theme == "Moonlit Magic" or saved.theme == "Midnight Wings" or saved.theme == "Golden Dragon" or not unlocked) end
    if Bars.straight then
        for _,bar in pairs(Bars.straight) do
            bar.control:SetMovable(unlocked)
            bar.control:SetMouseEnabled(false)
            if bar.drag then
                bar.drag:SetMouseEnabled(false)
                bar.drag:SetHidden(true)
            end
        end
    end
    if Bars.moonDrag then
        Bars.moonDrag:SetMouseEnabled(unlocked and saved.theme == "Enchanted Butterfly")
        Bars.moonDrag:SetHidden(not (unlocked and saved.theme == "Enchanted Butterfly"))
    end
    if Bars.moonGroup then Bars.moonGroup:SetMovable(unlocked and saved.theme == "Enchanted Butterfly") end
    if Bars.midnightGroup then Bars.midnightGroup:SetMovable(unlocked and saved.theme == "Midnight Wings") end
    if Bars.goldenGroup then Bars.goldenGroup:SetMovable(unlocked and saved.theme == "Golden Dragon") end
    if Bars.simpleGroup then Bars.simpleGroup:SetMovable(unlocked and saved.theme == "Simple Glow") end
    if Bars.simpleDrag then Bars.simpleDrag:SetMouseEnabled(unlocked and saved.theme == "Simple Glow"); Bars.simpleDrag:SetHidden(not (unlocked and saved.theme == "Simple Glow")) end
    if Bars.goldenDrag then Bars.goldenDrag:SetMouseEnabled(unlocked and saved.theme == "Golden Dragon"); Bars.goldenDrag:SetHidden(not (unlocked and saved.theme == "Golden Dragon")) end
    if Bars.fairyDrag then Bars.fairyDrag:SetMouseEnabled(unlocked and saved.theme == "Fairy Garden"); Bars.fairyDrag:SetHidden(not (unlocked and saved.theme == "Fairy Garden")) end
    if Bars.fairyGroup then Bars.fairyGroup:SetMovable(unlocked and saved.theme == "Fairy Garden") end
    if Bars.frozenDrag then Bars.frozenDrag:SetMouseEnabled(unlocked and saved.theme == "Frozen Elegance"); Bars.frozenDrag:SetHidden(not (unlocked and saved.theme == "Frozen Elegance")) end
    if Bars.frozenGroup then Bars.frozenGroup:SetMovable(unlocked and saved.theme == "Frozen Elegance") end
    if Bars.lunarDrag then Bars.lunarDrag:SetMouseEnabled(unlocked and saved.theme == "Moonlit Magic"); Bars.lunarDrag:SetHidden(not (unlocked and saved.theme == "Moonlit Magic")) end
    if Bars.lunarGroup then Bars.lunarGroup:SetMovable(unlocked and saved.theme == "Moonlit Magic") end
end

local function savePosition()
    local cx,cy=GuiRoot:GetCenter(); local hx,hy=Bars.hud:GetCenter()
    saved.x,saved.y=hx-cx,hy-cy
end

local function setupHudFragment()
    if hudFragment or not Bars.hud or not HUD_SCENE or not HUD_UI_SCENE then return end
    hudFragment = ZO_HUDFadeSceneFragment:New(Bars.hud, nil, 0)
    HUD_SCENE:AddFragment(hudFragment)
    HUD_UI_SCENE:AddFragment(hudFragment)
    hudFragment:RegisterCallback("StateChange", function() applyVisibility() end)
end

local function onPlayerActivated()
    setupHudFragment(); playerDead=IsUnitDead("player"); applyVisibility(); refresh()
end
local function onPlayerDead() playerDead=true; applyVisibility() end
local function onPlayerAlive() playerDead=false; applyVisibility(); refresh() end


local function applyTheme()
    if not Bars.themeLayer then return end
    local hibiscus = saved.theme == "Hibiscus"
    local dragon = saved.theme == "Dragon"
    local halloween = saved.theme == "Halloween"
    local spookycute = saved.theme == "Spooky Cute"
    local sunflower = saved.theme == "Sunflower"
    local swords = saved.theme == "Swords"
    local winter = saved.theme == "Winter"
    local straight = saved.theme == "Simple Glow" or saved.theme == "Enchanted Butterfly" or saved.theme == "Fairy Garden" or saved.theme == "Frozen Elegance" or saved.theme == "Moonlit Magic" or saved.theme == "Midnight Wings" or saved.theme == "Golden Dragon"
    Bars.themeLayer:SetHidden(true)
    if Bars.winterLeft then Bars.winterLeft:SetHidden(not winter) end
    if Bars.winterRight then Bars.winterRight:SetHidden(not winter) end
    if Bars.splitThemes then
        for name, pieces in pairs(Bars.splitThemes) do
            for _, part in ipairs(pieces) do part.control:SetHidden(saved.theme ~= name) end
        end
    end
    if Bars.ghostfire then
        for _,fire in ipairs(Bars.ghostfire) do fire:SetHidden(saved.theme ~= "Ghostfire") end
        if Bars.ghostfireGlow then
            for _,glow in ipairs(Bars.ghostfireGlow) do glow:SetHidden(saved.theme ~= "Ghostfire") end
        end
    end
    applyThemeGap()
    applyGhostfireColor()
    -- All original curved controls remain untouched; only their visibility changes.
    for _,control in ipairs({Bars.healthBack,Bars.health,Bars.healthGlow,
        Bars.staminaBack,Bars.stamina,Bars.staminaGlow,
        Bars.magickaBack,Bars.magicka,Bars.magickaGlow}) do
        if control then control:SetHidden(straight) end
    end
    for _,control in ipairs({Bars.healthText,Bars.staminaText,Bars.magickaText}) do
        if control then control:SetHidden(straight) end
    end
    for _,glows in ipairs({Bars.healthGlowText or {},Bars.staminaGlowText or {},Bars.magickaGlowText or {}}) do
        for _,label in ipairs(glows) do label:SetHidden(straight) end
    end
    if Bars.straight then
        for _,bar in pairs(Bars.straight) do bar.control:SetHidden(true) end -- Legacy bars retained; grouped Simple Glow is shown
    end
    if Bars.moonGroup then Bars.moonGroup:SetHidden(saved.theme ~= "Enchanted Butterfly" or not saved.enabled or playerDead) end
    if Bars.midnightGroup then Bars.midnightGroup:SetHidden(saved.theme ~= "Midnight Wings" or not saved.enabled or playerDead) end
    if Bars.goldenGroup then Bars.goldenGroup:SetHidden(saved.theme ~= "Golden Dragon" or not saved.enabled or playerDead) end
    if Bars.simpleGroup then Bars.simpleGroup:SetHidden(saved.theme ~= "Simple Glow" or not saved.enabled or playerDead) end
    if Bars.fairyGroup then Bars.fairyGroup:SetHidden(saved.theme ~= "Fairy Garden" or not saved.enabled or playerDead) end
    if Bars.frozenGroup then Bars.frozenGroup:SetHidden(saved.theme ~= "Frozen Elegance" or not saved.enabled or playerDead) end
    if Bars.lunarGroup then Bars.lunarGroup:SetHidden(saved.theme ~= "Moonlit Magic" or not saved.enabled or playerDead) end
    applyLock()
    -- Winter changes only the health-bar rendering. Other themes retain the normal red bar/glow.
    if Bars.health then Bars.health:SetHidden(winter or straight) end
    if Bars.healthGlow then Bars.healthGlow:SetHidden(winter or straight) end
    if Bars.winterHealth then Bars.winterHealth:SetHidden(not winter or straight) end
    if Bars.winterHealthGlow then Bars.winterHealthGlow:SetHidden(not winter or straight) end
end

-- Straight bars are independent top-level controls anchored to GuiRoot.
-- This avoids converting between the curved HUD's scaled coordinates and screen coordinates.
local function positionStraightBar(key, x, y)
    local bar = Bars.straight and Bars.straight[key]
    if not bar then return end
    local control = bar.control
    local rootW, rootH = GuiRoot:GetDimensions()
    local scale = (saved.scale or 100) / 100
    if scale <= 0 then scale = 1 end
    local halfW, halfH = STRAIGHT_WIDTH * scale / 2, STRAIGHT_HEIGHT * scale / 2
    x = math.max(-rootW/2 + halfW, math.min(rootW/2 - halfW, tonumber(x) or 0))
    y = math.max(-rootH/2 + halfH, math.min(rootH/2 - halfH, tonumber(y) or 0))
    control:ClearAnchors()
    control:SetAnchor(CENTER, GuiRoot, CENTER, x, y)
    saved.straightPositionsV7[key] = {x=x, y=y}
end
local function resetStraightPositions()
    saved.straightPositionsV7 = {}
    for key,pos in pairs(STRAIGHT_DEFAULTS) do
        positionStraightBar(key,pos.x,pos.y)
    end
end

local function createSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end
    local panel = LAM:RegisterAddonPanel("RSSThemeBarsOptions", {
        type="panel", name=DISPLAY, displayName=DISPLAY, author="WifeyRytic", version="1.4.1",
        registerForRefresh=true, registerForDefaults=true,
        resetFunc=function()
            resetStraightPositions()
            resetGroupedPosition(Bars.moonGroup, "moonPosition", 168, 65)
            resetGroupedPosition(Bars.midnightGroup, "midnightPosition", 168, 65)
            resetGroupedPosition(Bars.goldenGroup, "goldenPosition", 168, 65)
            resetGroupedPosition(Bars.simpleGroup, "simplePosition", 168, 65)
            resetGroupedPosition(Bars.fairyGroup, "fairyPosition", 168, 80)
            resetGroupedPosition(Bars.frozenGroup, "frozenPosition", 280, 111)
            resetGroupedPosition(Bars.lunarGroup, "lunarPosition", 356, 142)
        end,
    })
    local options = {
        { type="checkbox", name="Enable Resource Bars", tooltip="Master on/off switch for the entire resource-bar HUD.",
          getFunc=function() return saved.enabled end,
          setFunc=function(v) saved.enabled=v; applyVisibility() end,
          default=defaults.enabled, width="full" },
        { type="checkbox", name="Lock Position", tooltip="Unlock to drag Health, Stamina, Magicka, and theme artwork together as one HUD.",
          getFunc=function() return saved.locked end,
          setFunc=function(v) saved.locked=v; applyLock() end,
          default=defaults.locked, width="full" },
        { type="slider", name="Size", tooltip="Scale the entire HUD together.", min=50, max=150, step=1,
          getFunc=function() return saved.scale end,
          setFunc=function(v) saved.scale=v; applyScale() end,
          default=defaults.scale, width="full" },
        { type="slider", name="Middle Gap",
          tooltip="Adjusts the space between the health bar and the stamina/magicka bars without changing their sizes. Theme decorations move with the bars.",
          min=0, max=40, step=2,
          getFunc=function() return saved.theme == "Winter" and (saved.winterGap or 0) or (saved.themeGap or 0) end,
          setFunc=function(v) if saved.theme == "Winter" then saved.winterGap=v else saved.themeGap=v end; applyThemeGap() end,
          default=0, width="full" },
        { type="dropdown", name="Theme", tooltip="Choose the visual theme.",
          choices=THEMES, choicesValues=THEMES,
          getFunc=function() return saved.theme end,
          setFunc=function(v) saved.theme=v; applyTheme(); refresh() end,
          default=defaults.theme, width="full" },
        { type="description", text="Simple Glow: one movable group matching the decorated bars. Enchanted Butterfly, Fairy Garden, and Frozen Elegance: draggable groups with live bars and RSS numbers below." },
        { type="button", name="Reset Straight Bar Positions", tooltip="Reset the Simple Glow grouped bars to the decorated theme default.",
          func=function() resetStraightPositions() end, width="full" },
        { type="colorpicker", name="Ghostfire Flame & Glow Color", tooltip="Tint Ghostfire flames and soft glow together. Resource bar colors stay unchanged.",
          getFunc=function() local c=saved.ghostfireColor or defaults.ghostfireColor; return c[1],c[2],c[3],1 end,
          setFunc=function(r,g,b,a) saved.ghostfireColor={r,g,b}; applyGhostfireColor() end,
          default={defaults.ghostfireColor[1],defaults.ghostfireColor[2],defaults.ghostfireColor[3],1}, width="full",
          disabled=function() return saved.theme ~= "Ghostfire" end },
    }
    LAM:RegisterOptionControls("RSSThemeBarsOptions", options)
end

local function create()
    -- v1.1: Keep existing 1.0 account-wide preferences as plain defaults for
    -- the initial per-server profile, without changing the old saved table.
    local legacy = ZO_SavedVars:NewAccountWide("RSSThemeBarsSaved", 1, nil, defaults)
    local serverDefaults = {
        enabled = legacy.enabled,
        locked = legacy.locked,
        scale = legacy.scale,
        theme = legacy.theme,
        x = legacy.x,
        y = legacy.y,
        winterGap = legacy.winterGap or 0,
        themeGap = legacy.themeGap or 0,
        straightPositions = {},
        straightPositionsV6 = {},
        straightPositionsV7 = {},
    }
    -- Namespace separates NA, EU, and PTS profiles; existing server data wins.
    saved=ZO_SavedVars:NewAccountWide("RSSThemeBarsSaved",1,GetWorldName(),serverDefaults)
    -- Unavailable or obsolete themes reset safely to the default.
    local validTheme = false
    for _, themeName in ipairs(THEMES) do
        if saved.theme == themeName then validTheme = true; break end
    end
    if not validTheme then saved.theme = defaults.theme end
    local hud=WM:CreateTopLevelWindow("RSSThemeBarsHUD"); Bars.hud=hud
    -- Keep the original HUD scene fragment for menu hiding.  When the addon is
    -- disabled, prevent fragment transitions from exposing the HUD even for a
    -- single render frame.  This handler does not affect enabled bars.
    hud:SetHidden(true)
    hud:SetHandler("OnShow", function(control)
        if saved and not saved.enabled then
            control:SetHidden(true)
        end
    end)
    hud:SetDimensions(560,560); hud:SetAnchor(CENTER,GuiRoot,CENTER,saved.x or 0,saved.y or 0); hud:SetClampedToScreen(true)

    local hb=makeTexture(hud,TEX.."rss_v1_health_arc.dds"); hb:SetDimensions(ARC_W,ARC_H); hb:SetAnchor(CENTER,hud,CENTER,-190,0); hb:SetColor(0.03,0.03,0.035,0.72); Bars.healthBack=hb
    local glow=makeTexture(hud,TEX.."rss_v1_health_glow.dds"); glow:SetAnchor(BOTTOM,Bars.healthBack,BOTTOM,0,0); tint(glow,HEALTH,0.82); glow:SetBlendMode(TEX_BLEND_MODE_ADD); Bars.healthGlow=glow
    local h=makeTexture(hud,TEX.."rss_v1_health_arc.dds"); h:SetAnchor(BOTTOM,hb,BOTTOM,0,0); tint(h,HEALTH); Bars.health=h

    -- Winter-only candy-cane health bar. Pre-colored red/white arc plus matching
    -- pre-colored additive glow; same geometry and same bottom-up resource crop.
    local winterGlow=makeTexture(hud,TEX.."rss_v1_winter_health_glow.dds"); winterGlow:SetAnchor(BOTTOM,hb,BOTTOM,0,0); winterGlow:SetColor(1,1,1,0.82); winterGlow:SetBlendMode(TEX_BLEND_MODE_ADD); winterGlow:SetHidden(true); Bars.winterHealthGlow=winterGlow
    local winterHealth=makeTexture(hud,TEX.."rss_v1_winter_health_arc.dds"); winterHealth:SetAnchor(BOTTOM,hb,BOTTOM,0,0); winterHealth:SetColor(1,1,1,1); winterHealth:SetHidden(true); Bars.winterHealth=winterHealth

    local sb=makeTexture(hud,TEX.."rss_v1_stamina_arc.dds"); sb:SetDimensions(ARC_W,RIGHT_H); sb:SetAnchor(BOTTOM,hud,CENTER,190,OVERLAP/2); sb:SetColor(0.03,0.03,0.035,0.72); Bars.staminaBack=sb
    local glow=makeTexture(hud,TEX.."rss_v1_stamina_glow.dds"); glow:SetAnchor(BOTTOM,Bars.staminaBack,BOTTOM,0,0); tint(glow,STAM,0.82); glow:SetBlendMode(TEX_BLEND_MODE_ADD); Bars.staminaGlow=glow
    local s=makeTexture(hud,TEX.."rss_v1_stamina_arc.dds"); s:SetAnchor(BOTTOM,sb,BOTTOM,0,0); tint(s,STAM); Bars.stamina=s

    local mb=makeTexture(hud,TEX.."rss_v1_magicka_arc.dds"); mb:SetDimensions(ARC_W,RIGHT_H); mb:SetAnchor(TOP,hud,CENTER,190,-OVERLAP/2); mb:SetColor(0.03,0.03,0.035,0.72); Bars.magickaBack=mb
    local glow=makeTexture(hud,TEX.."rss_v1_magicka_glow.dds"); glow:SetAnchor(TOP,Bars.magickaBack,TOP,0,0); tint(glow,MAG,0.82); glow:SetBlendMode(TEX_BLEND_MODE_ADD); Bars.magickaGlow=glow
    local m=makeTexture(hud,TEX.."rss_v1_magicka_arc.dds"); m:SetAnchor(TOP,mb,TOP,0,0); tint(m,MAG); Bars.magicka=m

    -- Original resource bars remain in front of the separate flame artwork.
    -- Only draw-order metadata is set; no bar texture, geometry, color or fill changes.
    for _,bar in ipairs({Bars.healthBack, Bars.healthGlow, Bars.health,
                          Bars.staminaBack, Bars.staminaGlow, Bars.stamina,
                          Bars.magickaBack, Bars.magickaGlow, Bars.magicka,
                          Bars.winterHealthGlow, Bars.winterHealth}) do
        bar:SetDrawLayer(DL_CONTROLS)
        bar:SetDrawTier(DT_HIGH)
    end

    -- Preserve the approved Ghostfire flame positions.
    -- Soft halo effects are separate left/right bar-attached overlays, tintable
    -- with the same color picker. Original resource bars always draw above them.
    Bars.ghostfire = {}
    Bars.ghostfireGlow = {}
    local function addFuzz(back, name, w, h)
        local fuzz=makeTexture(hud,TEX.."rss_v1_ghostfire_fuzz_"..name..".dds")
        fuzz:SetDimensions(w+84,h+84)
        fuzz:SetAnchor(CENTER,back,CENTER,0,0)
        fuzz:SetBlendMode(TEX_BLEND_MODE_ADD)
        fuzz:SetDrawLayer(DL_BACKGROUND)
        fuzz:SetDrawTier(DT_LOW)
        fuzz:SetMouseEnabled(false)
        fuzz:SetHidden(true)
        fuzz:SetAlpha(0.55)
        table.insert(Bars.ghostfireGlow,fuzz)
    end
    addFuzz(hb,"health",ARC_W,ARC_H)
    addFuzz(sb,"stamina",ARC_W,RIGHT_H)
    addFuzz(mb,"magicka",ARC_W,RIGHT_H)

    local function addGhostfire(back, name, yOffset)
        local outward = (name == "health") and -17 or 30
        local x, y = outward, (yOffset or 0) + 20
        local fire=makeTexture(hud,TEX.."rss_v1_ghostfire_"..name..".dds")
        fire:SetDimensions(212,596)
        fire:SetAnchor(CENTER,back,CENTER,x,y)
        fire:SetDrawLayer(DL_BACKGROUND)
        fire:SetDrawTier(DT_MEDIUM)
        fire:SetMouseEnabled(false)
        fire:SetHidden(true)
        fire:SetAlpha(0.78)
        table.insert(Bars.ghostfire,fire)
    end
    addGhostfire(hb,"health",0)
    addGhostfire(sb,"right",120)
    applyGhostfireColor()

    -- Resource labels centered on the 560-unit HUD.
    -- Green is exact center x=0; red/blue are equal offsets -110/+110. Glow intensity reduced only.
    -- Direct children of HUD: move, scale and hide with the complete RSS Theme Bars HUD.
    local function makeRSSLabel(x,y,color)
        local glows={}
        -- Broad outer bloom + brighter inner bloom.  The main label remains sharp on top.
        local glowSpecs={
            {-4,0,0.05},{4,0,0.05},{0,-4,0.05},{0,4,0.05},
            {-3,-3,0.055},{3,-3,0.055},{-3,3,0.055},{3,3,0.055},
            {-3,0,0.08},{3,0,0.08},{0,-3,0.08},{0,3,0.08},
            {-2,-2,0.10},{2,-2,0.10},{-2,2,0.10},{2,2,0.10},
            {-2,0,0.14},{2,0,0.14},{0,-2,0.14},{0,2,0.14},
            {-1,-1,0.19},{1,-1,0.19},{-1,1,0.19},{1,1,0.19},
            {-1,0,0.24},{1,0,0.24},{0,-1,0.24},{0,1,0.24}
        }
        for i,spec in ipairs(glowSpecs) do
            local g=WM:CreateControl(nil,hud,CT_LABEL)
            g:SetFont("ZoFontGameBold"); g:SetDimensions(100,28); g:SetAnchor(CENTER,hud,CENTER,x+spec[1],y+spec[2])
            Bars.labelGlowOffsets=Bars.labelGlowOffsets or {}
            Bars.labelGlowOffsets[g]={spec[1],spec[2]}
            g:SetHorizontalAlignment(TEXT_ALIGN_CENTER); g:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            g:SetColor(color[1],color[2],color[3],spec[3]); g:SetDrawLayer(DL_OVERLAY); g:SetDrawTier(DT_HIGH)
            glows[i]=g
        end
        local label=WM:CreateControl(nil,hud,CT_LABEL)
        label:SetFont("ZoFontGameBold"); label:SetDimensions(100,28); label:SetAnchor(CENTER,hud,CENTER,x,y)
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER); label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetColor(color[1],color[2],color[3],1); label:SetDrawLayer(DL_OVERLAY); label:SetDrawTier(DT_HIGH)
        return label,glows
    end
    Bars.healthText,Bars.healthGlowText=makeRSSLabel(-110,-165,HEALTH)
    Bars.staminaText,Bars.staminaGlowText=makeRSSLabel(0,-165,STAM)
    Bars.magickaText,Bars.magickaGlowText=makeRSSLabel(110,-165,MAG)



    -- Independent straight bars, anchored to GuiRoot. They reuse
    -- resource events and are hidden unless Simple Glow is selected.
    Bars.straight = {}
    saved.straightPositionsV7 = saved.straightPositionsV7 or {}
    local straightDefs = {
        {"health",POWERTYPE_HEALTH,"rss_simple_health.dds",HEALTH,-245,0},
        {"magicka",POWERTYPE_MAGICKA,"rss_simple_magicka.dds",{0.08,0.85,1},0,0},
        {"stamina",POWERTYPE_STAMINA,"rss_simple_stamina.dds",STAM,245,0},
    }
    for _,def in ipairs(straightDefs) do
        local key,power,path,color,defaultX,defaultY=unpack(def)
        local position=saved.straightPositionsV7[key] or STRAIGHT_DEFAULTS[key] or {x=defaultX,y=defaultY}
        local control=WM:CreateTopLevelWindow("RSSSimpleGlow"..key)
        control:SetDimensions(STRAIGHT_WIDTH,STRAIGHT_HEIGHT)
        control:SetAnchor(CENTER,GuiRoot,CENTER,position.x or defaultX,position.y or defaultY)
        control:SetClampedToScreen(true)
        control:SetScale((saved.scale or 100)/100)
        control:SetHidden(true)
        control:SetDrawLayer(DL_OVERLAY); control:SetDrawTier(DT_HIGH)
        -- TEST 10: use the SAME rounded DDS silhouette as the full bar.
        -- Tint it dark and keep it at full width behind the draining fill.
        -- No rectangular backdrop or border: those caused a joined black line.
        local track=makeTexture(control,TEX..path)
        track:SetDimensions(STRAIGHT_WIDTH,22)
        track:SetAnchor(TOPLEFT,control,TOPLEFT,0,30)
        track:SetColor(0.03,0.03,0.035,0.90)
        track:SetMouseEnabled(false)
        local fill=makeTexture(control,TEX..path)
        fill:SetDimensions(STRAIGHT_WIDTH,22); fill:SetAnchor(TOPLEFT,control,TOPLEFT,0,30); fill:SetMouseEnabled(false)
        fill:SetDrawLevel(7)
        local glow=makeTexture(control,TEX..path)
        glow:SetDimensions(STRAIGHT_WIDTH,22); glow:SetAnchor(TOPLEFT,control,TOPLEFT,0,30); glow:SetMouseEnabled(false)
        glow:SetBlendMode(TEX_BLEND_MODE_ADD); glow:SetAlpha(0.48)
        local numberGlows={}
        for _,delta in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
            local label=WM:CreateControl(nil,control,CT_LABEL)
            label:SetDimensions(STRAIGHT_WIDTH,23)
            label:SetAnchor(TOP,control,TOP,delta[1],56+delta[2]); label:SetMouseEnabled(false)
            label:SetFont("ZoFontGameBold")
            label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            label:SetColor(color[1],color[2],color[3],0.3)
            numberGlows[#numberGlows+1]=label
        end
        local number=WM:CreateControl(nil,control,CT_LABEL)
        number:SetDimensions(STRAIGHT_WIDTH,23); number:SetAnchor(TOP,control,TOP,0,56); number:SetMouseEnabled(false)
        number:SetFont("ZoFontGameBold")
        number:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        number:SetColor(color[1],color[2],color[3],1)
        -- Purple grab handle, like the curved HUD's unlocked border.
        local drag=WM:CreateControl(nil,control,CT_BACKDROP)
        drag:SetDimensions(38,26)
        drag:SetAnchor(TOPLEFT,control,TOPLEFT,0,30)
        drag:SetCenterColor(0.45,0.08,0.65,0.65)
        drag:SetEdgeColor(0.85,0.28,1,1)
        drag:SetEdgeTexture("",1,1,2,0)
        drag:SetDrawLayer(DL_OVERLAY); drag:SetDrawTier(DT_HIGH)
        drag:SetMouseEnabled(false); drag:SetHidden(true)
        drag:SetHandler("OnMouseDown",function(self,button)
            if button==MOUSE_BUTTON_INDEX_LEFT and not saved.locked and saved.theme=="Simple Glow" then
                control:StartMoving()
            end
        end)
        drag:SetHandler("OnMouseUp",function(self,button)
            if button==MOUSE_BUTTON_INDEX_LEFT and not saved.locked and saved.theme=="Simple Glow" then
                control:StopMovingOrResizing()
                -- ESO has finished moving this top-level window. Save its
                -- actual center relative to GuiRoot, with no HUD conversion.
                local cx,cy=control:GetCenter()
                local rx,ry=GuiRoot:GetCenter()
                positionStraightBar(key,cx-rx,cy-ry)
            end
        end)
        Bars.straight[key]={control=control,drag=drag,track=track,fill=fill,glow=glow,number=number,numberGlows=numberGlows,power=power}
    end

    -- Reapply saved positions and clamp them on-screen at login.
    for key,pos in pairs(STRAIGHT_DEFAULTS) do
        local savedPos=saved.straightPositionsV7[key] or pos
        positionStraightBar(key,savedPos.x,savedPos.y)
    end

    -- Moonlit Magic is a NEW grouped straight-bar style. TEST 12 independent
    -- controls above are deliberately not modified or reparented.
    Bars.moonBars = {}
    local moonPos = saved.moonPosition or {x=0,y=groupedDefaultY(168,65)}
    local group = WM:CreateTopLevelWindow("RSSMoonlitMagicGroup")
    Bars.moonGroup=group
    group:SetDimensions(1060,168)
    group:SetAnchor(CENTER,GuiRoot,CENTER,moonPos.x or 0,moonPos.y or groupedDefaultY(168,65))
    group:SetClampedToScreen(true)
    group:SetScale((saved.scale or 100)/100)
    group:SetDrawLayer(DL_OVERLAY); group:SetDrawTier(DT_HIGH)
    group:SetHidden(true); group:SetMouseEnabled(false)
    local ornament=makeTexture(group,TEX.."rss_moonlit_magic.dds")
    ornament:SetDimensions(1060,356)
    ornament:SetAnchor(TOPLEFT,group,TOPLEFT,0,-96) -- TEST5 FIX: original intact butterfly texture restored
    ornament:SetMouseEnabled(false)
    -- TEST 15: draw the ornament IN FRONT of the bars, without changing
    -- its vertical anchor. Keep the group positioning/drag code intact.
    ornament:SetDrawLayer(DL_OVERLAY)
    ornament:SetDrawTier(DT_HIGH)
    ornament:SetDrawLevel(5)
    local moonDefs={
        {"magicka",POWERTYPE_MAGICKA,"rss_simple_magicka.dds",{0.08,0.85,1},106,260},
        {"health",POWERTYPE_HEALTH,"rss_simple_health.dds",HEALTH,377,299},
        {"stamina",POWERTYPE_STAMINA,"rss_simple_stamina.dds",STAM,687,266},
    }
    for _,def in ipairs(moonDefs) do
        local key,power,path,color,x,mw=unpack(def)
        local track=makeTexture(group,TEX..path)
        track:SetDimensions(mw,19); track:SetAnchor(TOPLEFT,group,TOPLEFT,x,65)
        track:SetColor(0.03,0.03,0.035,0.90); track:SetMouseEnabled(false)
        track:SetDrawLevel(6)
        local fill=makeTexture(group,TEX..path)
        fill:SetDimensions(mw,19); fill:SetAnchor(TOPLEFT,group,TOPLEFT,x,65)
        fill:SetMouseEnabled(false)
        fill:SetDrawLevel(7)
        local glow=makeTexture(group,TEX..path)
        glow:SetDimensions(mw,19); glow:SetAnchor(TOPLEFT,group,TOPLEFT,x,65)
        glow:SetBlendMode(TEX_BLEND_MODE_ADD); glow:SetAlpha(0.48); glow:SetMouseEnabled(false)
        glow:SetDrawLevel(8)
        local numberGlows={}
        for _,delta in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
            local label=WM:CreateControl(nil,group,CT_LABEL)
            label:SetDimensions(mw,23); label:SetAnchor(TOPLEFT,group,TOPLEFT,x+delta[1],87+delta[2])
            label:SetFont("ZoFontGameBold"); label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            label:SetColor(color[1],color[2],color[3],0.3); label:SetMouseEnabled(false)
            label:SetDrawLevel(10)
            numberGlows[#numberGlows+1]=label
        end
        local number=WM:CreateControl(nil,group,CT_LABEL)
        number:SetDimensions(mw,23); number:SetAnchor(TOPLEFT,group,TOPLEFT,x,87)
        number:SetFont("ZoFontGameBold"); number:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        number:SetColor(color[1],color[2],color[3],1); number:SetMouseEnabled(false)
        number:SetDrawLevel(10)
        Bars.moonBars[key]={track=track,fill=fill,glow=glow,number=number,numberGlows=numberGlows,power=power,width=mw}
    end
    -- One handle moves the entire Moonlit Magic top-level window.
    local moonDrag=WM:CreateControl(nil,group,CT_BACKDROP)
    Bars.moonDrag=moonDrag
    moonDrag:SetDimensions(1060,168); moonDrag:SetAnchorFill(group)
    moonDrag:SetCenterColor(0.45,0.08,0.65,0.04)
    moonDrag:SetEdgeColor(0.85,0.28,1,1)
    moonDrag:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds",2,2,2,0)
    moonDrag:SetDrawLayer(DL_OVERLAY); moonDrag:SetDrawTier(DT_HIGH)
    moonDrag:SetHidden(true); moonDrag:SetMouseEnabled(false)
    -- Full-group purple positioning perimeter, shown only while unlocked.
    for _,edge in ipairs({
        {0,0,1060,2}, {0,166,1060,2}, {0,0,2,168}, {1058,0,2,168}
    }) do
        local line=WM:CreateControl(nil,moonDrag,CT_TEXTURE)
        line:SetTexture("EsoUI/Art/Miscellaneous/white.dds")
        line:SetColor(0.82,0.25,1,0.95)
        line:SetDimensions(edge[3],edge[4])
        line:SetAnchor(TOPLEFT,moonDrag,TOPLEFT,edge[1],edge[2])
        line:SetMouseEnabled(false)
    end

    moonDrag:SetHandler("OnMouseDown",function(self,button)
        if button==MOUSE_BUTTON_INDEX_LEFT and not saved.locked and saved.theme=="Enchanted Butterfly" then group:StartMoving() end
    end)
    moonDrag:SetHandler("OnMouseUp",function(self,button)
        if button==MOUSE_BUTTON_INDEX_LEFT and not saved.locked and saved.theme=="Enchanted Butterfly" then
            group:StopMovingOrResizing()
            local cx,cy=group:GetCenter(); local rx,ry=GuiRoot:GetCenter()
            saved.moonPosition={x=cx-rx,y=cy-ry}
            group:ClearAnchors(); group:SetAnchor(CENTER,GuiRoot,CENTER,saved.moonPosition.x,saved.moonPosition.y)
        end
    end)

    -- Midnight Wings TEST1: butterfly-matched independent grouped bars.
    -- controls above are deliberately not modified or reparented.
    Bars.midnightBars = {}
    local midnightPos = saved.midnightPosition or {x=0,y=groupedDefaultY(168,65)}
    local group = WM:CreateTopLevelWindow("RSSMidnightWingsGroup")
    Bars.midnightGroup=group
    group:SetDimensions(1060,168)
    group:SetAnchor(CENTER,GuiRoot,CENTER,midnightPos.x or 0,midnightPos.y or groupedDefaultY(168,65))
    group:SetClampedToScreen(true)
    group:SetScale((saved.scale or 100)/100)
    group:SetDrawLayer(DL_OVERLAY); group:SetDrawTier(DT_HIGH)
    group:SetHidden(true); group:SetMouseEnabled(false)
    local ornament=makeTexture(group,TEX.."rss_midnight_wings.dds")
    ornament:SetDimensions(1060,356)
    ornament:SetAnchor(TOPLEFT,group,TOPLEFT,0,-82) -- TEST5 FIX: original intact butterfly texture restored
    ornament:SetMouseEnabled(false)
    -- TEST 15: draw the ornament IN FRONT of the bars, without changing
    -- its vertical anchor. Keep the group positioning/drag code intact.
    ornament:SetDrawLayer(DL_OVERLAY)
    ornament:SetDrawTier(DT_HIGH)
    ornament:SetDrawLevel(5)
    local midnightDefs={
        {"magicka",POWERTYPE_MAGICKA,"rss_simple_magicka.dds",{0.08,0.85,1},106,260},
        {"health",POWERTYPE_HEALTH,"rss_simple_health.dds",HEALTH,377,299},
        {"stamina",POWERTYPE_STAMINA,"rss_simple_stamina.dds",STAM,687,266},
    }
    for _,def in ipairs(midnightDefs) do
        local key,power,path,color,x,mw=unpack(def)
        local track=makeTexture(group,TEX..path)
        track:SetDimensions(mw,19); track:SetAnchor(TOPLEFT,group,TOPLEFT,x,65)
        track:SetColor(0.03,0.03,0.035,0.90); track:SetMouseEnabled(false)
        track:SetDrawLevel(6)
        local fill=makeTexture(group,TEX..path)
        fill:SetDimensions(mw,19); fill:SetAnchor(TOPLEFT,group,TOPLEFT,x,65)
        fill:SetMouseEnabled(false)
        fill:SetDrawLevel(7)
        local glow=makeTexture(group,TEX..path)
        glow:SetDimensions(mw,19); glow:SetAnchor(TOPLEFT,group,TOPLEFT,x,65)
        glow:SetBlendMode(TEX_BLEND_MODE_ADD); glow:SetAlpha(0.48); glow:SetMouseEnabled(false)
        glow:SetDrawLevel(8)
        local numberGlows={}
        for _,delta in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
            local label=WM:CreateControl(nil,group,CT_LABEL)
            label:SetDimensions(mw,23); label:SetAnchor(TOPLEFT,group,TOPLEFT,x+delta[1],87+delta[2])
            label:SetFont("ZoFontGameBold"); label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            label:SetColor(color[1],color[2],color[3],0.3); label:SetMouseEnabled(false)
            label:SetDrawLevel(10)
            numberGlows[#numberGlows+1]=label
        end
        local number=WM:CreateControl(nil,group,CT_LABEL)
        number:SetDimensions(mw,23); number:SetAnchor(TOPLEFT,group,TOPLEFT,x,87)
        number:SetFont("ZoFontGameBold"); number:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        number:SetColor(color[1],color[2],color[3],1); number:SetMouseEnabled(false)
        number:SetDrawLevel(10)
        Bars.midnightBars[key]={track=track,fill=fill,glow=glow,number=number,numberGlows=numberGlows,power=power,width=mw}
    end
    -- One handle moves the entire Moonlit Magic top-level window.
    local midnightDrag=WM:CreateControl(nil,group,CT_BACKDROP)
    Bars.midnightDrag=midnightDrag
    midnightDrag:SetDimensions(1060,168); midnightDrag:SetAnchorFill(group)
    midnightDrag:SetCenterColor(0.45,0.08,0.65,0.04)
    midnightDrag:SetEdgeColor(0.85,0.28,1,1)
    midnightDrag:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds",2,2,2,0)
    midnightDrag:SetDrawLayer(DL_OVERLAY); midnightDrag:SetDrawTier(DT_HIGH)
    midnightDrag:SetHidden(true); midnightDrag:SetMouseEnabled(false)
    -- Full-group purple positioning perimeter, shown only while unlocked.
    for _,edge in ipairs({
        {0,0,1060,2}, {0,166,1060,2}, {0,0,2,168}, {1058,0,2,168}
    }) do
        local line=WM:CreateControl(nil,midnightDrag,CT_TEXTURE)
        line:SetTexture("EsoUI/Art/Miscellaneous/white.dds")
        line:SetColor(0.82,0.25,1,0.95)
        line:SetDimensions(edge[3],edge[4])
        line:SetAnchor(TOPLEFT,midnightDrag,TOPLEFT,edge[1],edge[2])
        line:SetMouseEnabled(false)
    end

    midnightDrag:SetHandler("OnMouseDown",function(self,button)
        if button==MOUSE_BUTTON_INDEX_LEFT and not saved.locked and saved.theme=="Midnight Wings" then group:StartMoving() end
    end)
    midnightDrag:SetHandler("OnMouseUp",function(self,button)
        if button==MOUSE_BUTTON_INDEX_LEFT and not saved.locked and saved.theme=="Midnight Wings" then
            group:StopMovingOrResizing()
            local cx,cy=group:GetCenter(); local rx,ry=GuiRoot:GetCenter()
            saved.midnightPosition={x=cx-rx,y=cy-ry}
            group:ClearAnchors(); group:SetAnchor(CENTER,GuiRoot,CENTER,saved.midnightPosition.x,saved.midnightPosition.y)
        end
    end)

    -- Golden Dragon TEST1: Golden Dragon TEST3 matched independent grouped bars.
    -- controls above are deliberately not modified or reparented.
    Bars.goldenBars = {}
    local midnightPos = saved.goldenPosition or {x=0,y=groupedDefaultY(168,65)}
    local group = WM:CreateTopLevelWindow("RSSGoldenDragonGroup")
    Bars.goldenGroup=group
    group:SetDimensions(1060,168)
    group:SetAnchor(CENTER,GuiRoot,CENTER,midnightPos.x or 0,midnightPos.y or groupedDefaultY(168,65))
    group:SetClampedToScreen(true)
    group:SetScale((saved.scale or 100)/100)
    group:SetDrawLayer(DL_OVERLAY); group:SetDrawTier(DT_HIGH)
    group:SetHidden(true); group:SetMouseEnabled(false)
    local ornament=makeTexture(group,TEX.."rss_golden_dragon.dds")
    ornament:SetDimensions(1060,356)
    ornament:SetAnchor(TOPLEFT,group,TOPLEFT,0,-82) -- TEST5 FIX: original intact butterfly texture restored
    ornament:SetMouseEnabled(false)
    -- TEST 15: draw the ornament IN FRONT of the bars, without changing
    -- its vertical anchor. Keep the group positioning/drag code intact.
    ornament:SetDrawLayer(DL_OVERLAY)
    ornament:SetDrawTier(DT_HIGH)
    ornament:SetDrawLevel(5)
    local goldenDefs={
        {"magicka",POWERTYPE_MAGICKA,"rss_simple_magicka.dds",{0.08,0.85,1},106,260},
        {"health",POWERTYPE_HEALTH,"rss_simple_health.dds",HEALTH,377,299},
        {"stamina",POWERTYPE_STAMINA,"rss_simple_stamina.dds",STAM,687,266},
    }
    for _,def in ipairs(goldenDefs) do
        local key,power,path,color,x,mw=unpack(def)
        local track=makeTexture(group,TEX..path)
        track:SetDimensions(mw,19); track:SetAnchor(TOPLEFT,group,TOPLEFT,x,65)
        track:SetColor(0.03,0.03,0.035,0.90); track:SetMouseEnabled(false)
        track:SetDrawLevel(6)
        local fill=makeTexture(group,TEX..path)
        fill:SetDimensions(mw,19); fill:SetAnchor(TOPLEFT,group,TOPLEFT,x,65)
        fill:SetMouseEnabled(false)
        fill:SetDrawLevel(7)
        local glow=makeTexture(group,TEX..path)
        glow:SetDimensions(mw,19); glow:SetAnchor(TOPLEFT,group,TOPLEFT,x,65)
        glow:SetBlendMode(TEX_BLEND_MODE_ADD); glow:SetAlpha(0.48); glow:SetMouseEnabled(false)
        glow:SetDrawLevel(8)
        local numberGlows={}
        for _,delta in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
            local label=WM:CreateControl(nil,group,CT_LABEL)
            label:SetDimensions(mw,23); label:SetAnchor(TOPLEFT,group,TOPLEFT,x+delta[1],87+delta[2])
            label:SetFont("ZoFontGameBold"); label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            label:SetColor(color[1],color[2],color[3],0.3); label:SetMouseEnabled(false)
            label:SetDrawLevel(10)
            numberGlows[#numberGlows+1]=label
        end
        local number=WM:CreateControl(nil,group,CT_LABEL)
        number:SetDimensions(mw,23); number:SetAnchor(TOPLEFT,group,TOPLEFT,x,87)
        number:SetFont("ZoFontGameBold"); number:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        number:SetColor(color[1],color[2],color[3],1); number:SetMouseEnabled(false)
        number:SetDrawLevel(10)
        Bars.goldenBars[key]={track=track,fill=fill,glow=glow,number=number,numberGlows=numberGlows,power=power,width=mw}
    end
    -- One handle moves the entire Moonlit Magic top-level window.
    local goldenDrag=WM:CreateControl(nil,group,CT_BACKDROP)
    Bars.goldenDrag=goldenDrag
    goldenDrag:SetDimensions(1060,168); goldenDrag:SetAnchorFill(group)
    goldenDrag:SetCenterColor(0.45,0.08,0.65,0.04)
    goldenDrag:SetEdgeColor(0.85,0.28,1,1)
    goldenDrag:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds",2,2,2,0)
    goldenDrag:SetDrawLayer(DL_OVERLAY); goldenDrag:SetDrawTier(DT_HIGH)
    goldenDrag:SetHidden(true); goldenDrag:SetMouseEnabled(false)
    -- Full-group purple positioning perimeter, shown only while unlocked.
    for _,edge in ipairs({
        {0,0,1060,2}, {0,166,1060,2}, {0,0,2,168}, {1058,0,2,168}
    }) do
        local line=WM:CreateControl(nil,goldenDrag,CT_TEXTURE)
        line:SetTexture("EsoUI/Art/Miscellaneous/white.dds")
        line:SetColor(0.82,0.25,1,0.95)
        line:SetDimensions(edge[3],edge[4])
        line:SetAnchor(TOPLEFT,goldenDrag,TOPLEFT,edge[1],edge[2])
        line:SetMouseEnabled(false)
    end

    goldenDrag:SetHandler("OnMouseDown",function(self,button)
        if button==MOUSE_BUTTON_INDEX_LEFT and not saved.locked and saved.theme=="Golden Dragon" then group:StartMoving() end
    end)
    goldenDrag:SetHandler("OnMouseUp",function(self,button)
        if button==MOUSE_BUTTON_INDEX_LEFT and not saved.locked and saved.theme=="Golden Dragon" then
            group:StopMovingOrResizing()
            local cx,cy=group:GetCenter(); local rx,ry=GuiRoot:GetCenter()
            saved.goldenPosition={x=cx-rx,y=cy-ry}
            group:ClearAnchors(); group:SetAnchor(CENTER,GuiRoot,CENTER,saved.goldenPosition.x,saved.goldenPosition.y)
        end
    end)

    -- Simple Glow: undecorated reference, exact Golden Dragon geometry.
    Bars.simpleGroupBars = {}
    local midnightPos = saved.simplePosition or {x=0,y=groupedDefaultY(168,65)}
    local group = WM:CreateTopLevelWindow("RSSSimpleGlowMatchedGroup")
    Bars.simpleGroup=group
    group:SetDimensions(1060,168)
    group:SetAnchor(CENTER,GuiRoot,CENTER,midnightPos.x or 0,midnightPos.y or groupedDefaultY(168,65))
    group:SetClampedToScreen(true)
    group:SetScale((saved.scale or 100)/100)
    group:SetDrawLayer(DL_OVERLAY); group:SetDrawTier(DT_HIGH)
    group:SetHidden(true); group:SetMouseEnabled(false)
    local simpleDefs={
        {"magicka",POWERTYPE_MAGICKA,"rss_simple_magicka.dds",{0.08,0.85,1},106,260},
        {"health",POWERTYPE_HEALTH,"rss_simple_health.dds",HEALTH,377,299},
        {"stamina",POWERTYPE_STAMINA,"rss_simple_stamina.dds",STAM,687,266},
    }
    for _,def in ipairs(simpleDefs) do
        local key,power,path,color,x,mw=unpack(def)
        local track=makeTexture(group,TEX..path)
        track:SetDimensions(mw,19); track:SetAnchor(TOPLEFT,group,TOPLEFT,x,65)
        track:SetColor(0.03,0.03,0.035,0.90); track:SetMouseEnabled(false)
        track:SetDrawLevel(6)
        local fill=makeTexture(group,TEX..path)
        fill:SetDimensions(mw,19); fill:SetAnchor(TOPLEFT,group,TOPLEFT,x,65)
        fill:SetMouseEnabled(false)
        fill:SetDrawLevel(7)
        local glow=makeTexture(group,TEX..path)
        glow:SetDimensions(mw,19); glow:SetAnchor(TOPLEFT,group,TOPLEFT,x,65)
        glow:SetBlendMode(TEX_BLEND_MODE_ADD); glow:SetAlpha(0.48); glow:SetMouseEnabled(false)
        glow:SetDrawLevel(8)
        local numberGlows={}
        for _,delta in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
            local label=WM:CreateControl(nil,group,CT_LABEL)
            label:SetDimensions(mw,23); label:SetAnchor(TOPLEFT,group,TOPLEFT,x+delta[1],87+delta[2])
            label:SetFont("ZoFontGameBold"); label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            label:SetColor(color[1],color[2],color[3],0.3); label:SetMouseEnabled(false)
            label:SetDrawLevel(10)
            numberGlows[#numberGlows+1]=label
        end
        local number=WM:CreateControl(nil,group,CT_LABEL)
        number:SetDimensions(mw,23); number:SetAnchor(TOPLEFT,group,TOPLEFT,x,87)
        number:SetFont("ZoFontGameBold"); number:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        number:SetColor(color[1],color[2],color[3],1); number:SetMouseEnabled(false)
        number:SetDrawLevel(10)
        Bars.simpleGroupBars[key]={track=track,fill=fill,glow=glow,number=number,numberGlows=numberGlows,power=power,width=mw}
    end
    -- One handle moves the entire Moonlit Magic top-level window.
    local simpleDrag=WM:CreateControl(nil,group,CT_BACKDROP)
    Bars.simpleDrag=simpleDrag
    simpleDrag:SetDimensions(1060,168); simpleDrag:SetAnchorFill(group)
    simpleDrag:SetCenterColor(0.45,0.08,0.65,0.04)
    simpleDrag:SetEdgeColor(0.85,0.28,1,1)
    simpleDrag:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds",2,2,2,0)
    simpleDrag:SetDrawLayer(DL_OVERLAY); simpleDrag:SetDrawTier(DT_HIGH)
    simpleDrag:SetHidden(true); simpleDrag:SetMouseEnabled(false)
    -- Full-group purple positioning perimeter, shown only while unlocked.
    for _,edge in ipairs({
        {0,0,1060,2}, {0,166,1060,2}, {0,0,2,168}, {1058,0,2,168}
    }) do
        local line=WM:CreateControl(nil,simpleDrag,CT_TEXTURE)
        line:SetTexture("EsoUI/Art/Miscellaneous/white.dds")
        line:SetColor(0.82,0.25,1,0.95)
        line:SetDimensions(edge[3],edge[4])
        line:SetAnchor(TOPLEFT,simpleDrag,TOPLEFT,edge[1],edge[2])
        line:SetMouseEnabled(false)
    end

    simpleDrag:SetHandler("OnMouseDown",function(self,button)
        if button==MOUSE_BUTTON_INDEX_LEFT and not saved.locked and saved.theme=="Simple Glow" then group:StartMoving() end
    end)
    simpleDrag:SetHandler("OnMouseUp",function(self,button)
        if button==MOUSE_BUTTON_INDEX_LEFT and not saved.locked and saved.theme=="Simple Glow" then
            group:StopMovingOrResizing()
            local cx,cy=group:GetCenter(); local rx,ry=GuiRoot:GetCenter()
            saved.simplePosition={x=cx-rx,y=cy-ry}
            group:ClearAnchors(); group:SetAnchor(CENTER,GuiRoot,CENTER,saved.simplePosition.x,saved.simplePosition.y)
        end
    end)

    -- Moonlit Magic TEST 1: clean bar-free decoration with independently rendered resource bars. TEST 12 independent
    -- controls above are deliberately not modified or reparented.
    Bars.lunarBars = {}
    local lunarPos = saved.lunarPosition or {x=0,y=groupedDefaultY(356,142)}
    local group = WM:CreateTopLevelWindow("RSSMoonlitMagicNewGroup")
    Bars.lunarGroup=group
    group:SetDimensions(1060,356)
    group:SetAnchor(CENTER,GuiRoot,CENTER,lunarPos.x or 0,lunarPos.y or groupedDefaultY(356,142))
    group:SetClampedToScreen(true)
    group:SetScale((saved.scale or 100)/100)
    group:SetDrawLayer(DL_OVERLAY); group:SetDrawTier(DT_HIGH)
    group:SetHidden(true); group:SetMouseEnabled(false)
    local ornament=makeTexture(group,TEX.."rss_moonlit_magic_clean.dds")
    ornament:SetDimensions(1060,356)
    ornament:SetAnchor(TOPLEFT,group,TOPLEFT,0,0)
    ornament:SetMouseEnabled(false)
    -- TEST 15: draw the ornament IN FRONT of the bars, without changing
    -- its vertical anchor. Keep the group positioning/drag code intact.
    ornament:SetDrawLayer(DL_OVERLAY)
    ornament:SetDrawTier(DT_HIGH)
    ornament:SetDrawLevel(5)
    local lunarDefs={
        {"magicka",POWERTYPE_MAGICKA,"rss_simple_magicka.dds",{0.08,0.85,1},106,260},
        {"health",POWERTYPE_HEALTH,"rss_simple_health.dds",HEALTH,377,299},
        {"stamina",POWERTYPE_STAMINA,"rss_simple_stamina.dds",STAM,687,266},
    }
    for _,def in ipairs(lunarDefs) do
        local key,power,path,color,x,mw=unpack(def)
        local track=makeTexture(group,TEX..path)
        track:SetDimensions(mw,19); track:SetAnchor(TOPLEFT,group,TOPLEFT,x,142)
        track:SetColor(0.03,0.03,0.035,0.90); track:SetMouseEnabled(false)
        track:SetDrawLevel(6)
        local fill=makeTexture(group,TEX..path)
        fill:SetDimensions(mw,19); fill:SetAnchor(TOPLEFT,group,TOPLEFT,x,142)
        fill:SetMouseEnabled(false)
        fill:SetDrawLevel(7)
        local glow=makeTexture(group,TEX..path)
        glow:SetDimensions(mw,19); glow:SetAnchor(TOPLEFT,group,TOPLEFT,x,142)
        glow:SetBlendMode(TEX_BLEND_MODE_ADD); glow:SetAlpha(0.48); glow:SetMouseEnabled(false)
        glow:SetDrawLevel(8)
        local numberGlows={}
        for _,delta in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
            local label=WM:CreateControl(nil,group,CT_LABEL)
            label:SetDimensions(mw,23); label:SetAnchor(TOPLEFT,group,TOPLEFT,x+delta[1],164+delta[2])
            label:SetFont("ZoFontGameBold"); label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            label:SetColor(color[1],color[2],color[3],0.3); label:SetMouseEnabled(false)
            label:SetDrawLevel(10)
            numberGlows[#numberGlows+1]=label
        end
        local number=WM:CreateControl(nil,group,CT_LABEL)
        number:SetDimensions(mw,23); number:SetAnchor(TOPLEFT,group,TOPLEFT,x,164)
        number:SetFont("ZoFontGameBold"); number:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        number:SetColor(color[1],color[2],color[3],1); number:SetMouseEnabled(false)
        number:SetDrawLevel(10)
        Bars.lunarBars[key]={track=track,fill=fill,glow=glow,number=number,numberGlows=numberGlows,power=power,width=mw}
    end
    -- One handle moves the entire Moonlit Magic top-level window.
    local lunarDrag=WM:CreateControl(nil,group,CT_BACKDROP)
    Bars.lunarDrag=lunarDrag
    lunarDrag:SetDimensions(1060,356); lunarDrag:SetAnchorFill(group)
    lunarDrag:SetCenterColor(0.45,0.08,0.65,0.04)
    lunarDrag:SetEdgeColor(0.85,0.28,1,1)
    lunarDrag:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds",2,2,2,0)
    lunarDrag:SetDrawLayer(DL_OVERLAY); lunarDrag:SetDrawTier(DT_HIGH)
    lunarDrag:SetHidden(true); lunarDrag:SetMouseEnabled(false)
    -- Full-group purple positioning perimeter, shown only while unlocked.
    for _,edge in ipairs({
        {0,0,1060,2}, {0,354,1060,2}, {0,0,2,356}, {1058,0,2,356}
    }) do
        local line=WM:CreateControl(nil,lunarDrag,CT_TEXTURE)
        line:SetTexture("EsoUI/Art/Miscellaneous/white.dds")
        line:SetColor(0.82,0.25,1,0.95)
        line:SetDimensions(edge[3],edge[4])
        line:SetAnchor(TOPLEFT,lunarDrag,TOPLEFT,edge[1],edge[2])
        line:SetMouseEnabled(false)
    end

    lunarDrag:SetHandler("OnMouseDown",function(self,button)
        if button==MOUSE_BUTTON_INDEX_LEFT and not saved.locked and saved.theme=="Moonlit Magic" then group:StartMoving() end
    end)
    lunarDrag:SetHandler("OnMouseUp",function(self,button)
        if button==MOUSE_BUTTON_INDEX_LEFT and not saved.locked and saved.theme=="Moonlit Magic" then
            group:StopMovingOrResizing()
            local cx,cy=group:GetCenter(); local rx,ry=GuiRoot:GetCenter()
            saved.lunarPosition={x=cx-rx,y=cy-ry}
            group:ClearAnchors(); group:SetAnchor(CENTER,GuiRoot,CENTER,saved.lunarPosition.x,saved.lunarPosition.y)
        end
    end)

    -- Fairy Garden is a NEW grouped straight-bar style. TEST 12 independent
    -- controls above are deliberately not modified or reparented.
    Bars.fairyBars = {}
    local moonPos = saved.fairyPosition or {x=0,y=groupedDefaultY(168,80)}
    local group = WM:CreateTopLevelWindow("RSSFairyGardenGroup")
    Bars.fairyGroup=group
    group:SetDimensions(1060,168)
    group:SetAnchor(CENTER,GuiRoot,CENTER,moonPos.x or 0,moonPos.y or groupedDefaultY(168,80))
    group:SetClampedToScreen(true)
    group:SetScale((saved.scale or 100)/100)
    group:SetDrawLayer(DL_OVERLAY); group:SetDrawTier(DT_HIGH)
    group:SetHidden(true); group:SetMouseEnabled(false)
    local ornament=makeTexture(group,TEX.."rss_fairy_garden.dds")
    ornament:SetDimensions(1060,168)
    ornament:SetAnchor(TOPLEFT,group,TOPLEFT,0,0)
    ornament:SetMouseEnabled(false)
    -- TEST 15: draw the ornament IN FRONT of the bars, without changing
    -- its vertical anchor. Keep the group positioning/drag code intact.
    ornament:SetDrawLayer(DL_OVERLAY)
    ornament:SetDrawTier(DT_HIGH)
    ornament:SetDrawLevel(5)
    local fairyDefs={
        {"magicka",POWERTYPE_MAGICKA,"rss_simple_magicka.dds",{0.08,0.85,1},106,260},
        {"health",POWERTYPE_HEALTH,"rss_simple_health.dds",HEALTH,377,299},
        {"stamina",POWERTYPE_STAMINA,"rss_simple_stamina.dds",STAM,687,266},
    }
    for _,def in ipairs(fairyDefs) do
        local key,power,path,color,x,mw=unpack(def)
        -- A rounded, full-width depleted track, independent of the decorative art.
        local track=makeTexture(group,TEX..path)
        track:SetDimensions(mw,19); track:SetAnchor(TOPLEFT,group,TOPLEFT,x,80)
        track:SetColor(0.03,0.03,0.035,0.90); track:SetMouseEnabled(false)
        track:SetDrawLevel(6)
        local fill=makeTexture(group,TEX..path)
        fill:SetDimensions(mw,19); fill:SetAnchor(TOPLEFT,group,TOPLEFT,x,80)
        fill:SetMouseEnabled(false)
        fill:SetDrawLevel(7)
        local glow=makeTexture(group,TEX..path)
        glow:SetDimensions(mw,19); glow:SetAnchor(TOPLEFT,group,TOPLEFT,x,80)
        glow:SetBlendMode(TEX_BLEND_MODE_ADD); glow:SetAlpha(0.10); glow:SetMouseEnabled(false)
        glow:SetDrawLevel(8)
        local numberGlows={}
        for _,delta in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
            local label=WM:CreateControl(nil,group,CT_LABEL)
            label:SetDimensions(mw,23); label:SetAnchor(TOPLEFT,group,TOPLEFT,x+delta[1],102+delta[2])
            label:SetFont("ZoFontGameBold"); label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            label:SetColor(color[1],color[2],color[3],0.3); label:SetMouseEnabled(false)
            label:SetDrawLevel(10)
            numberGlows[#numberGlows+1]=label
        end
        local number=WM:CreateControl(nil,group,CT_LABEL)
        number:SetDimensions(mw,23); number:SetAnchor(TOPLEFT,group,TOPLEFT,x,102)
        number:SetFont("ZoFontGameBold"); number:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        number:SetColor(color[1],color[2],color[3],1); number:SetMouseEnabled(false)
        number:SetDrawLevel(10)
        Bars.fairyBars[key]={fill=fill,glow=glow,number=number,numberGlows=numberGlows,power=power,width=mw}
    end
    -- One handle moves the entire Fairy Garden top-level window.
    local fairyDrag=WM:CreateControl(nil,group,CT_BACKDROP)
    Bars.fairyDrag=fairyDrag
    fairyDrag:SetDimensions(1060,168); fairyDrag:SetAnchorFill(group)
    fairyDrag:SetCenterColor(0.45,0.08,0.65,0.04)
    fairyDrag:SetEdgeColor(0.85,0.28,1,1)
    fairyDrag:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds",2,2,2,0)
    fairyDrag:SetDrawLayer(DL_OVERLAY); fairyDrag:SetDrawTier(DT_HIGH)
    fairyDrag:SetHidden(true); fairyDrag:SetMouseEnabled(false)
    -- Full-group purple positioning perimeter, shown only while unlocked.
    for _,edge in ipairs({
        {0,0,1060,2}, {0,166,1060,2}, {0,0,2,168}, {1058,0,2,168}
    }) do
        local line=WM:CreateControl(nil,fairyDrag,CT_TEXTURE)
        line:SetTexture("EsoUI/Art/Miscellaneous/white.dds")
        line:SetColor(0.82,0.25,1,0.95)
        line:SetDimensions(edge[3],edge[4])
        line:SetAnchor(TOPLEFT,fairyDrag,TOPLEFT,edge[1],edge[2])
        line:SetMouseEnabled(false)
    end

    fairyDrag:SetHandler("OnMouseDown",function(self,button)
        if button==MOUSE_BUTTON_INDEX_LEFT and not saved.locked and saved.theme=="Fairy Garden" then group:StartMoving() end
    end)
    fairyDrag:SetHandler("OnMouseUp",function(self,button)
        if button==MOUSE_BUTTON_INDEX_LEFT and not saved.locked and saved.theme=="Fairy Garden" then
            group:StopMovingOrResizing()
            local cx,cy=group:GetCenter(); local rx,ry=GuiRoot:GetCenter()
            saved.fairyPosition={x=cx-rx,y=cy-ry}
            group:ClearAnchors(); group:SetAnchor(CENTER,GuiRoot,CENTER,saved.fairyPosition.x,saved.fairyPosition.y)
        end
    end)

    -- Frozen Elegance is a NEW grouped straight-bar style. TEST 12 independent
    -- controls above are deliberately not modified or reparented.
    Bars.frozenBars = {}
    local frozenPos = saved.frozenPosition or {x=0,y=groupedDefaultY(280,111)}
    local group = WM:CreateTopLevelWindow("RSSFrozenEleganceGroup")
    Bars.frozenGroup=group
    group:SetDimensions(1060,280)
    group:SetAnchor(CENTER,GuiRoot,CENTER,frozenPos.x or 0,frozenPos.y or groupedDefaultY(280,111))
    group:SetClampedToScreen(true)
    group:SetScale((saved.scale or 100)/100)
    group:SetDrawLayer(DL_OVERLAY); group:SetDrawTier(DT_HIGH)
    group:SetHidden(true); group:SetMouseEnabled(false)
    local ornament=makeTexture(group,TEX.."rss_frozen_elegance.dds")
    ornament:SetDimensions(1050,280)
    ornament:SetAnchor(TOPLEFT,group,TOPLEFT,5,-9)
    ornament:SetMouseEnabled(false)
    -- TEST 15: draw the ornament IN FRONT of the bars, without changing
    -- its vertical anchor. Keep the group positioning/drag code intact.
    ornament:SetDrawLayer(DL_OVERLAY)
    ornament:SetDrawTier(DT_HIGH)
    ornament:SetDrawLevel(5)
    local frozenDefs={
        {"magicka",POWERTYPE_MAGICKA,"rss_simple_magicka.dds",{0.08,0.85,1},106,260},
        {"health",POWERTYPE_HEALTH,"rss_simple_health.dds",HEALTH,377,299},
        {"stamina",POWERTYPE_STAMINA,"rss_simple_stamina.dds",STAM,687,266},
    }
    for _,def in ipairs(frozenDefs) do
        local key,power,path,color,x,mw=unpack(def)
        -- A rounded, full-width depleted track, independent of the decorative art.
        local track=makeTexture(group,TEX..path)
        track:SetDimensions(mw,19); track:SetAnchor(TOPLEFT,group,TOPLEFT,x,111)
        track:SetColor(0.03,0.03,0.035,0.90); track:SetMouseEnabled(false)
        track:SetDrawLevel(6)
        local fill=makeTexture(group,TEX..path)
        fill:SetDimensions(mw,19); fill:SetAnchor(TOPLEFT,group,TOPLEFT,x,111)
        fill:SetMouseEnabled(false)
        fill:SetDrawLevel(7)
        local glow=makeTexture(group,TEX..path)
        glow:SetDimensions(mw,19); glow:SetAnchor(TOPLEFT,group,TOPLEFT,x,111)
        glow:SetBlendMode(TEX_BLEND_MODE_ADD); glow:SetAlpha(0.10); glow:SetMouseEnabled(false)
        glow:SetDrawLevel(8)
        local numberGlows={}
        for _,delta in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
            local label=WM:CreateControl(nil,group,CT_LABEL)
            label:SetDimensions(mw,23); label:SetAnchor(TOPLEFT,group,TOPLEFT,x+delta[1],136+delta[2])
            label:SetFont("ZoFontGameBold"); label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            label:SetColor(color[1],color[2],color[3],0.3); label:SetMouseEnabled(false)
            label:SetDrawLevel(10)
            numberGlows[#numberGlows+1]=label
        end
        local number=WM:CreateControl(nil,group,CT_LABEL)
        number:SetDimensions(mw,23); number:SetAnchor(TOPLEFT,group,TOPLEFT,x,136)
        number:SetFont("ZoFontGameBold"); number:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        number:SetColor(color[1],color[2],color[3],1); number:SetMouseEnabled(false)
        number:SetDrawLevel(10)
        Bars.frozenBars[key]={fill=fill,glow=glow,number=number,numberGlows=numberGlows,power=power,width=mw}
    end
    -- One handle moves the entire Frozen Elegance top-level window.
    local frozenDrag=WM:CreateControl(nil,group,CT_BACKDROP)
    Bars.frozenDrag=frozenDrag
    frozenDrag:SetDimensions(1060,280); frozenDrag:SetAnchorFill(group)
    frozenDrag:SetCenterColor(0.45,0.08,0.65,0.04)
    frozenDrag:SetEdgeColor(0.85,0.28,1,1)
    frozenDrag:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds",2,2,2,0)
    frozenDrag:SetDrawLayer(DL_OVERLAY); frozenDrag:SetDrawTier(DT_HIGH)
    frozenDrag:SetHidden(true); frozenDrag:SetMouseEnabled(false)
    -- Full-group purple positioning perimeter, shown only while unlocked.
    for _,edge in ipairs({
        {0,0,1060,2}, {0,278,1060,2}, {0,0,2,280}, {1058,0,2,280}
    }) do
        local line=WM:CreateControl(nil,frozenDrag,CT_TEXTURE)
        line:SetTexture("EsoUI/Art/Miscellaneous/white.dds")
        line:SetColor(0.82,0.25,1,0.95)
        line:SetDimensions(edge[3],edge[4])
        line:SetAnchor(TOPLEFT,frozenDrag,TOPLEFT,edge[1],edge[2])
        line:SetMouseEnabled(false)
    end

    frozenDrag:SetHandler("OnMouseDown",function(self,button)
        if button==MOUSE_BUTTON_INDEX_LEFT and not saved.locked and saved.theme=="Frozen Elegance" then group:StartMoving() end
    end)
    frozenDrag:SetHandler("OnMouseUp",function(self,button)
        if button==MOUSE_BUTTON_INDEX_LEFT and not saved.locked and saved.theme=="Frozen Elegance" then
            group:StopMovingOrResizing()
            local cx,cy=group:GetCenter(); local rx,ry=GuiRoot:GetCenter()
            saved.frozenPosition={x=cx-rx,y=cy-ry}
            group:ClearAnchors(); group:SetAnchor(CENTER,GuiRoot,CENTER,saved.frozenPosition.x,saved.frozenPosition.y)
        end
    end)

    -- Theme layer remains as the shared theme visibility controller.
    local themeLayer=WM:CreateControl(nil,hud,CT_CONTROL); Bars.themeLayer=themeLayer
    themeLayer:SetAnchorFill(hud); themeLayer:SetMouseEnabled(false)


    -- Theme artwork is displayed as texture-coordinate slices of the ORIGINAL DDS.
    -- This avoids re-encoding and lets left/right decoration travel with its bars.
    Bars.splitThemes = {}
    local function addSlice(theme, path, fullW, fullH, u0, u1, x, side, v0, v1)
        local piece=makeTexture(hud,TEX..path)
        piece:SetDimensions(fullW*(u1-u0),fullH)
        piece:SetTextureCoords(u0,u1,v0 or 0,v1 or 1)
        piece:SetAnchor(CENTER,hud,CENTER,x,0)
        piece:SetDrawLayer(DL_OVERLAY); piece:SetDrawTier(DT_HIGH)
        piece:SetMouseEnabled(false); piece:SetHidden(true)
        Bars.splitThemes[theme]=Bars.splitThemes[theme] or {}
        table.insert(Bars.splitThemes[theme],{control=piece,x=x,side=side})
    end
    local function splitTheme(theme,path,w,h,cx,u0,u1)
        u0=u0 or 0; u1=u1 or 1
        local mid=(u0+u1)/2
        local half=w/2
        addSlice(theme,path,w,h,u0,mid,cx-half/2,-1)
        addSlice(theme,path,w,h,mid,u1,cx+half/2,1)
    end
    splitTheme("Halloween","rss_v1_halloween.dds",512,512,0)
    splitTheme("Hibiscus","rss_v1_hibiscus.dds",560,560,0)
    splitTheme("Dragon","rss_v1_dragon.dds",560,560,0)
    -- Stardust Dragon: independent left/right artwork follows bar spacing.
    addSlice("Stardust Dragon","rss_v1_stardust_dragon.dds",560,560,0,0.5,-125,-1)
    addSlice("Stardust Dragon","rss_v1_stardust_dragon.dds",560,560,0.5,1,125,1)
    splitTheme("Swords","rss_v1_swords.dds",560,560,0)
    -- Sunflower DDS is 1024x1024, but the original theme renders its upper-left
    -- 512x512 quadrant at 512x512. Preserve that exact display scale.
    addSlice("Sunflower","rss_v1_sunflower.dds",1024,512,0,0.25,-122,-1,0,0.5)
    addSlice("Sunflower","rss_v1_sunflower.dds",1024,512,0.25,0.5,134,1,0,0.5)
    -- Spooky Cute: the full bottom bat spans roughly x=180..325.
    -- Keep that entire 145px center strip stationary; move outer art only.
    addSlice("Spooky Cute","rss_v1_spookycute.dds",512,512,0,180/512,-166,-1)
    addSlice("Spooky Cute","rss_v1_spookycute.dds",512,512,180/512,325/512,-3.5,0)
    addSlice("Spooky Cute","rss_v1_spookycute.dds",512,512,325/512,1,162.5,1)

    -- Split the ORIGINAL Winter DDS at its center using texture coordinates.
    -- No image re-encoding or artwork loss: each half moves with its bars.
    local winterLeft=makeTexture(hud,TEX.."rss_v1_winter.dds"); Bars.winterLeft=winterLeft
    winterLeft:SetDimensions(280,560)
    winterLeft:SetTextureCoords(0,0.5,0,1)
    winterLeft:SetAnchor(CENTER,hud,CENTER,-140,0)
    winterLeft:SetDrawLayer(DL_OVERLAY); winterLeft:SetDrawTier(DT_HIGH)
    winterLeft:SetMouseEnabled(false); winterLeft:SetHidden(true)
    local winterRight=makeTexture(hud,TEX.."rss_v1_winter.dds"); Bars.winterRight=winterRight
    winterRight:SetDimensions(280,560)
    winterRight:SetTextureCoords(0.5,1,0,1)
    winterRight:SetAnchor(CENTER,hud,CENTER,140,0)
    winterRight:SetDrawLayer(DL_OVERLAY); winterRight:SetDrawTier(DT_HIGH)
    winterRight:SetMouseEnabled(false); winterRight:SetHidden(true)



    -- Full-HUD drag catcher: when unlocked, this sits above the curved textures so
    -- the player can drag anywhere inside the HUD rectangle as one unit.
    local overlay=WM:CreateControl(nil,hud,CT_BACKDROP); Bars.moveOverlay=overlay
    overlay:SetAnchorFill(hud)
    overlay:SetCenterColor(0,0,0,0.06)
    overlay:SetEdgeColor(0.72,0.18,1,0.90)
    overlay:SetEdgeTexture("",1,1,2,0)
    overlay:SetDrawLayer(DL_OVERLAY); overlay:SetDrawTier(DT_HIGH)
    overlay:SetMouseEnabled(false); overlay:SetHidden(true)
    overlay:SetHandler("OnMouseDown",function(_,button)
        if button==MOUSE_BUTTON_INDEX_LEFT and not saved.locked then hud:StartMoving() end
    end)
    overlay:SetHandler("OnMouseUp",function(_,button)
        if button==MOUSE_BUTTON_INDEX_LEFT and not saved.locked then
            hud:StopMovingOrResizing(); savePosition()
        end
    end)

    local hint=WM:CreateControl(nil,hud,CT_LABEL); Bars.moveHint=hint
    hint:SetFont("ZoFontGameBold"); hint:SetText("RSS Theme Bars - UNLOCKED: DRAG ANYWHERE")
    hint:SetAnchor(TOP,hud,TOP,0,8); hint:SetColor(1,1,1,0.9)
    hint:SetDrawLayer(DL_OVERLAY); hint:SetDrawTier(DT_HIGH); hint:SetMouseEnabled(false); hint:SetHidden(true)

    setupHudFragment(); applyScale(); applyLock(); applyTheme(); createSettings()
    -- Gentle layered brightness variation; no changes to resource updates.
    EM:RegisterForUpdate(ADDON.."GhostfireFlicker",110,function()
        if not saved or saved.theme ~= "Ghostfire" or not Bars.ghostfire then return end
        ghostfireTick=ghostfireTick+1
        for i,fire in ipairs(Bars.ghostfire) do
            local pulse=0.72+0.12*math.sin(ghostfireTick*0.51+i*1.8)+0.06*math.sin(ghostfireTick*1.17+i)
            fire:SetAlpha(pulse)
        end
        if Bars.ghostfireGlow then
            for i,fuzz in ipairs(Bars.ghostfireGlow) do
                local pulse=0.72+0.12*math.sin(ghostfireTick*0.51+i*1.8)+0.06*math.sin(ghostfireTick*1.17+i)
                fuzz:SetAlpha(pulse*0.72)
            end
        end
    end)

    EM:RegisterForEvent(ADDON.."Power",EVENT_POWER_UPDATE,onPower); EM:AddFilterForEvent(ADDON.."Power",EVENT_POWER_UPDATE,REGISTER_FILTER_UNIT_TAG,"player")
    EM:RegisterForEvent(ADDON.."Activated",EVENT_PLAYER_ACTIVATED,onPlayerActivated)
    EM:RegisterForEvent(ADDON.."Dead",EVENT_PLAYER_DEAD,onPlayerDead)
    EM:RegisterForEvent(ADDON.."Alive",EVENT_PLAYER_ALIVE,onPlayerAlive)
    refresh(); playerDead=IsUnitDead("player"); applyVisibility()
end

local function loaded(_,addonName)
    if addonName~=ADDON then return end
    EM:UnregisterForEvent(ADDON,EVENT_ADD_ON_LOADED); create()
end
EM:RegisterForEvent(ADDON,EVENT_ADD_ON_LOADED,loaded)
