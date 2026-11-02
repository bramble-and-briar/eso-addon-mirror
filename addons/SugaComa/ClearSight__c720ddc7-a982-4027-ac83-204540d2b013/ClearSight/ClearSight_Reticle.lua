local CS = ClearSight

local function MakeBar(name, parent, layer)
    local control = WINDOW_MANAGER:CreateControl(name, parent, CT_BACKDROP)
    control:SetDrawLayer(layer or DL_OVERLAY)
    control:SetCenterColor(1, 1, 1, 1)
    control:SetEdgeColor(0, 0, 0, 0)
    return control
end

local function SetColor(control, color)
    control:SetCenterColor(color[1], color[2], color[3], color[4] or 1)
end

function CS:InitializeReticle()
    local root = WINDOW_MANAGER:CreateTopLevelWindow("ClearSightReticle")
    root:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    root:SetDimensions(140, 140)
    root:SetMouseEnabled(false)
    root:SetClampedToScreen(true)
    root:SetDrawTier(DT_HIGH)

    self.reticleRoot = root
    self.reticleBars = {}
    self.reticleOutlineBars = {}
    self.reticleBrackets = {}

    local names = { "Left", "Right", "Top", "Bottom" }
    for _, n in ipairs(names) do
        self.reticleOutlineBars[n] = MakeBar("ClearSightReticleOutline" .. n, root, DL_BACKGROUND)
        self.reticleBars[n] = MakeBar("ClearSightReticle" .. n, root, DL_OVERLAY)
    end

    for i = 1, 8 do
        self.reticleBrackets[i] = MakeBar("ClearSightReticleBracket" .. i, root, DL_OVERLAY)
    end

    EVENT_MANAGER:RegisterForEvent(self.name .. "_ReticleHidden", EVENT_RETICLE_HIDDEN_UPDATE, function()
        self:UpdateReticle()
    end)

    EVENT_MANAGER:RegisterForEvent(self.name .. "_ReticleTarget", EVENT_RETICLE_TARGET_CHANGED, function()
        self:UpdateReticle()
    end)

    -- Update immediately when the unit under the reticle changes death state.
    -- The existing visual update loop remains responsible for normal reticle tracking;
    -- this event simply avoids waiting for the next visual tick on a confirmed death.
    if EVENT_UNIT_DEATH_STATE_CHANGED then
        EVENT_MANAGER:RegisterForEvent(self.name .. "_ReticleDeath", EVENT_UNIT_DEATH_STATE_CHANGED, function(_, unitTag)
            if unitTag == "reticleover" then
                self:UpdateReticle()
            end
        end)
    end

    self:InitializeSightShapes()
    self:LayoutReticle()
end

function CS:LayoutReticle()
    if not self.reticleRoot then return end

    local s = self.saved.reticle
    local size = s.size
    local thickness = s.thickness
    local gap = s.gap
    local outline = s.outline

    local half = math.floor(size / 2)

    local function layoutPair(bars, extra)
        local t = thickness + extra * 2
        local g = math.max(0, gap - extra)

        bars.Left:ClearAnchors()
        bars.Left:SetDimensions(half - g, t)
        bars.Left:SetAnchor(RIGHT, self.reticleRoot, CENTER, -g, 0)

        bars.Right:ClearAnchors()
        bars.Right:SetDimensions(half - g, t)
        bars.Right:SetAnchor(LEFT, self.reticleRoot, CENTER, g, 0)

        bars.Top:ClearAnchors()
        bars.Top:SetDimensions(t, half - g)
        bars.Top:SetAnchor(BOTTOM, self.reticleRoot, CENTER, 0, -g)

        bars.Bottom:ClearAnchors()
        bars.Bottom:SetDimensions(t, half - g)
        bars.Bottom:SetAnchor(TOP, self.reticleRoot, CENTER, 0, g)
    end

    layoutPair(self.reticleOutlineBars, outline)
    layoutPair(self.reticleBars, 0)

    for _, bar in pairs(self.reticleOutlineBars) do
        SetColor(bar, {0, 0, 0, 0.92})
    end

    -- "Target acquired" corner brackets. These sit just outside the normal reticle.
    local r = half + 8
    local len = 14
    local bt = math.max(3, thickness)

    local bracketLayouts = {
        {1, len, bt, CENTER, -r, -r, TOPLEFT},
        {2, bt, len, CENTER, -r, -r, TOPLEFT},
        {3, len, bt, CENTER,  r, -r, TOPRIGHT},
        {4, bt, len, CENTER,  r, -r, TOPRIGHT},
        {5, len, bt, CENTER, -r,  r, BOTTOMLEFT},
        {6, bt, len, CENTER, -r,  r, BOTTOMLEFT},
        {7, len, bt, CENTER,  r,  r, BOTTOMRIGHT},
        {8, bt, len, CENTER,  r,  r, BOTTOMRIGHT},
    }

    for _, v in ipairs(bracketLayouts) do
        local bar = self.reticleBrackets[v[1]]
        bar:ClearAnchors()
        bar:SetDimensions(v[2], v[3])
        bar:SetAnchor(v[7], self.reticleRoot, v[4], v[5], v[6])
    end
end

function CS:GetReticleState()
    local unitTag = "reticleover"
    local hasReticleUnit = DoesUnitExist and DoesUnitExist(unitTag)

    if not hasReticleUnit then
        return "normal"
    end

    -- Death must win over reaction. A corpse can briefly retain the reaction it
    -- had while alive, so checking this first prevents a dead enemy staying red.
    if IsUnitDead and IsUnitDead(unitTag) then
        return "dead"
    end

    local reaction = GetUnitReaction and GetUnitReaction(unitTag) or nil

    if reaction == UNIT_REACTION_HOSTILE then
        return "hostile"
    elseif reaction == UNIT_REACTION_FRIENDLY
        or reaction == UNIT_REACTION_NPC_ALLY
        or reaction == UNIT_REACTION_PLAYER_ALLY
        or reaction == UNIT_REACTION_COMPANION then
        return "friendly"
    end

    -- Neutral units, attackable-but-not-hostile units, interactables and empty
    -- reticle space all use the normal white accessibility state.
    return "normal"
end

function CS:UpdateReticle()
    if not self.reticleRoot then return end

    local s = self.saved.reticle
    local stockReticleHidden = IsReticleHidden and IsReticleHidden()

    -- Mirror ESO's own HUD visibility rather than maintaining a menu/scene list.
    -- IsControlHidden includes inherited visibility, so ClearSight disappears when
    -- a menu or interaction scene hides the stock reticle through a parent fragment.
    if not stockReticleHidden and ZO_Reticle and ZO_Reticle.IsControlHidden then
        stockReticleHidden = ZO_Reticle:IsControlHidden()
    end
    if not stockReticleHidden and ZO_Reticle and ZO_Reticle.GetAlpha then
        stockReticleHidden = ZO_Reticle:GetAlpha() <= 0.01
    end

    local preview = self.compassPreviewScene and self.compassPreviewScene:GetState() ~= SCENE_HIDDEN
    local hidden = not preview and ((not s.enabled) or stockReticleHidden)
    self.reticleRoot:SetHidden(hidden)
    if hidden then return end
    self.previewStealthText:SetHidden(not preview)
    if preview then
        self:HideSightShapes()
        self:UpdateSightShape("Compass", s.normalColor, "normal")
        self:UpdateReticleWayfinder()
        return
    end

    local state = self:GetReticleState()
    local color = s.normalColor
    if state == "dead" then
        color = s.deadColor
    elseif state == "hostile" then
        color = s.hostileColor
    elseif state == "friendly" then
        color = s.friendlyColor
    end

    self:HideSightShapes()
    if s.style and s.style ~= "Cross" then
        self:UpdateSightShape(s.style, color, state)
        self:UpdateReticleWayfinder()
        return
    end

    for _, bar in pairs(self.reticleBars) do
        SetColor(bar, color)
        bar:SetHidden(false)
    end

    for _, bar in pairs(self.reticleOutlineBars) do
        bar:SetHidden(false)
    end

    if state == "normal" then
        -- NORMAL / PASSIVE RETICLE:
        -- Leave a square opening in the centre for ESO's own reticle and
        -- stealth eye. The active/acquired and hostile layouts remain the
        -- original full cross.
        local size = s.size
        local thickness = s.thickness
        local outline = s.outline

        -- Wider than the standard centre gap so the game's native reticle can
        -- sit cleanly inside ClearSight without being covered.
        local normalGap = math.max(s.gap + 8, thickness * 3)
        local half = math.floor(size / 2)

        local function layoutNormal(bars, extra)
            local t = thickness + extra * 2
            local g = math.max(0, normalGap - extra)

            bars.Left:ClearAnchors()
            bars.Left:SetDimensions(math.max(1, half - g), t)
            bars.Left:SetAnchor(RIGHT, self.reticleRoot, CENTER, -g, 0)

            bars.Right:ClearAnchors()
            bars.Right:SetDimensions(math.max(1, half - g), t)
            bars.Right:SetAnchor(LEFT, self.reticleRoot, CENTER, g, 0)

            -- Remove the top bar entirely in the passive state.
            bars.Top:SetHidden(true)

            -- Drop the bottom bar by the same centre-gap distance used by
            -- the left/right bars, producing an open square around the eye.
            bars.Bottom:ClearAnchors()
            bars.Bottom:SetDimensions(t, math.max(1, half - g))
            bars.Bottom:SetAnchor(TOP, self.reticleRoot, CENTER, 0, g)
        end

        layoutNormal(self.reticleOutlineBars, outline)
        layoutNormal(self.reticleBars, 0)
    else
        -- FRIENDLY / HOSTILE / DEAD:
        -- Restore the original full-cross layout exactly as before.
        self:LayoutReticle()
        for _, bar in pairs(self.reticleBars) do
            SetColor(bar, color)
            bar:SetHidden(false)
        end
        for _, bar in pairs(self.reticleOutlineBars) do
            bar:SetHidden(false)
        end
    end

    local showBrackets = s.showAcquiredBrackets and state ~= "normal"
    for _, bar in ipairs(self.reticleBrackets) do
        bar:SetHidden(not showBrackets)
        if showBrackets then
            SetColor(bar, color)
        end
    end
    self:UpdateReticleWayfinder()
end


-- Lines use the same endpoint anchors as ESO's scenegraph line controls.
function CS:InitializeSightShapes()
    self.reticleWayfinder = self:CreateWingedWayfinder("ClearSightReticleWayfinder", self.reticleRoot)
    self.sightLines = {}
    for i = 1, 55 do
        local pair = {}
        for j = 1, 2 do
            local line = WINDOW_MANAGER:CreateControl("ClearSightShape" .. i .. "_" .. j, self.reticleRoot, CT_LINE)
            line:SetDrawLayer(j == 1 and DL_BACKGROUND or DL_OVERLAY)
            line:SetHidden(true)
            pair[j] = line
        end
        self.sightLines[i] = pair
    end
    self.previewStealthText = WINDOW_MANAGER:CreateControl("ClearSightPreviewStealthText", self.reticleRoot, CT_LABEL)
    self.previewStealthText:SetFont("ZoFontWinH3")
    self.previewStealthText:SetText("DETECTED")
    self.previewStealthText:SetAnchor(CENTER, self.reticleRoot, CENTER, 0, -35)
    self.previewStealthText:SetColor(1,1,1,1)
    self.previewStealthText:SetHidden(true)
    self.sightLabels = {}
    for _, text in ipairs({"N", "E", "S", "W"}) do
        local label = WINDOW_MANAGER:CreateControl("ClearSightDirection" .. text, self.reticleRoot, CT_LABEL)
        label:SetFont("$(BOLD_FONT)|28|thick-outline")
        label:SetText(text)
        label:SetDrawLayer(DL_OVERLAY)
        label:SetHidden(true)
        self.sightLabels[text] = label
    end
end

function CS:HideSightShapes()
    self.reticleWayfinder:SetHidden(true)
    for _, pair in ipairs(self.sightLines) do
        pair[1]:SetHidden(true)
        pair[2]:SetHidden(true)
    end
    for _, label in pairs(self.sightLabels) do label:SetHidden(true) end
end

function CS:DrawSightLine(index, x1, y1, x2, y2, color, lightOutline)
    local s = self.saved.reticle
    for j, line in ipairs(self.sightLines[index]) do
        line:ClearAnchors()
        line:SetAnchor(TOPLEFT, self.reticleRoot, CENTER, x1, y1)
        line:SetAnchor(BOTTOMRIGHT, self.reticleRoot, CENTER, x2, y2)
        line:SetThickness(s.thickness + (j == 1 and s.outline * 2 or 0))
        if j == 1 then
            local edge = lightOutline and 1 or 0
            line:SetColor(edge, edge, edge, 0.92)
        else line:SetColor(color[1], color[2], color[3], color[4] or 1) end
        line:SetHidden(false)
    end
end

-- ESO camera heading is counter-clockwise from north. A fixed world bearing
-- therefore rotates clockwise on the screen as the camera turns left.
function CS:GetSightDirection(heading, bearing, radius)
    local angle = heading + bearing
    return math.sin(angle) * radius, -math.cos(angle) * radius
end

function CS:UpdateSightShape(style, color, state)
    for _, bar in pairs(self.reticleBars) do bar:SetHidden(true) end
    for _, bar in pairs(self.reticleOutlineBars) do bar:SetHidden(true) end
    local s = self.saved.reticle
    local r = s.size / 2
    if style == "Square" then
        self:DrawSightLine(1, -r, -r, r, -r, color)
        self:DrawSightLine(2, r, -r, r, r, color)
        self:DrawSightLine(3, r, r, -r, r, color)
        self:DrawSightLine(4, -r, r, -r, -r, color)
    else
        if style ~= "Compass" then
        for i = 1, 48 do
            local a, b = (i - 1) * math.pi / 24, i * math.pi / 24
            self:DrawSightLine(i, math.sin(a)*r, -math.cos(a)*r, math.sin(b)*r, -math.cos(b)*r, color)
        end
        end
        if style == "Compass" and GetPlayerCameraHeading then
            r = self:GetCompassOrbitRadius()
            local heading = GetPlayerCameraHeading()
            for i, text in ipairs({"N", "E", "S", "W"}) do
                local x, y = self:GetSightDirection(heading, (i-1)*math.pi/2, r)
                local label = self.sightLabels[text]
                label:SetFont("$(BOLD_FONT)|" .. (text == "N" and (s.compassLetterSize or 48) or (s.compassOtherLetterSize or 32)) .. "|thick-outline")
                label:ClearAnchors()
                label:SetAnchor(CENTER, self.reticleRoot, CENTER, x, y)
                label:SetColor(color[1], color[2], color[3], color[4] or 1)
                label:SetHidden(false)
            end

        end
    end
    for _, bar in ipairs(self.reticleBrackets) do
        local show = style ~= "Compass" and s.showAcquiredBrackets and state ~= "normal"
        bar:SetHidden(not show)
        if show then SetColor(bar, color) end
    end
end


function CS:GetCompassOrbitRadius()
    return self.saved.reticle.compassLetterRadius or 95
end


function CS:UpdateReticleWayfinder()
    local s = self.saved.waypoint
    if not s.enabled or s.location == "Compass" then return end
    local relative = self:GetWaypointNavigationData()
    if relative == nil then return end
    local r = self.saved.reticle.wayfinderRadius or 140
    local x, y = -math.sin(relative)*r, -math.cos(relative)*r
    self:DrawWingedWayfinder(self.reticleWayfinder, x,y,self.saved.reticle.wayfinderSize or 40,relative,relative,self:GetWaypointGuidanceColor(relative))
end
