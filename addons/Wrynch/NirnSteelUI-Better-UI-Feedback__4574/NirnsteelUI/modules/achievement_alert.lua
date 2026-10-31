local ADDON_NAME = "NirnsteelUI"
local NAMESPACE = ADDON_NAME .. "_AchievementAlert"

Nirnsteel_UI = Nirnsteel_UI or {}
local Alert = { queue = {} }
Nirnsteel_UI.AchievementAlert = Alert
local ART = "NirnsteelUI/ui/achievement/"

local function Settings()
    return Nirnsteel_UI.Settings:GetAchievementAlert()
end

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, tonumber(value) or minimum))
end

local function Texture(parent, width, height, anchor, relative, x, y, path)
    local control = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
    control:SetDimensions(width, height)
    control:SetAnchor(anchor, parent, relative, x, y)
    if path then control:SetTexture(path) end
    return control
end

local function Label(parent, size, y, color)
    local control = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    control:SetAnchor(TOP, parent, TOP, 0, y)
    control:SetWidth(520)
    control:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    control:SetFont("$(ANTIQUE_FONT)|" .. size .. "|soft-shadow-thick")
    control:SetColor(unpack(color))
    return control
end

function Alert:CreateView()
    if self.root then return end
    if Nirnsteel_UI.GetAssetPath then ART = Nirnsteel_UI:GetAssetPath("ui/achievement/") end
    local root = WINDOW_MANAGER:CreateTopLevelWindow(NAMESPACE)
    self.root = root
    root:SetDimensions(560, 230)
    root:SetClampedToScreen(true)
    root:SetMouseEnabled(false)
    root:SetDrawTier(DT_HIGH)
    root:SetHidden(true)

    local frame = WINDOW_MANAGER:CreateControl(nil, root, CT_CONTROL)
    frame:SetDimensions(560, 230)
    self.frame = frame
    -- Soft edge-free contrast beneath the lettering, not a rectangular panel.
    self.shade = Texture(frame, 640, 270, CENTER, CENTER, 0, 20, ART .. "iron_shade_dxt5.dds")
    self.shade:SetDrawLayer(DL_BACKGROUND)
    self.shade:SetDrawLevel(0)
    self.rule = Texture(frame, 512, 32, TOP, TOP, 0, 38, ART .. "iron_rule_dxt5.dds")
    self.rule:SetDrawLevel(2)
    self.glow = Texture(frame, 240, 200, TOP, TOP, 0, -47, ART .. "iron_halo_dxt5.dds")
    self.glow:SetBlendMode(TEX_BLEND_MODE_ADD)
    self.glow:SetTransformNormalizedOriginPoint(0.5, 0.5)
    self.glow:SetDrawLayer(DL_BACKGROUND)
    self.glow:SetDrawLevel(1)
    self.crest = Texture(frame, 108, 108, TOP, TOP, 0, 0, ART .. "iron_crest_dxt5.dds")
    self.crest:SetTransformNormalizedOriginPoint(0.5, 0.5)
    self.crest:SetDrawLevel(3)
    self.minimalSeal = Texture(frame, 64, 64, TOP, TOP, 0, 0, ART .. "minimal_seal_dxt5.dds")
    self.minimalSeal:SetColor(0.82, 0.79, 0.70, 1)
    self.minimalSeal:SetDrawLevel(3)
    self.minimalRule = Texture(frame, 440, 16, TOP, TOP, 0, 24, ART .. "minimal_rule_dxt5.dds")
    self.minimalRule:SetColor(0.76, 0.73, 0.64, 1)
    self.minimalRule:SetDrawLevel(2)
    self.minimalRewardRule = Texture(frame, 260, 16, TOP, TOP, 0, 148, ART .. "minimal_reward_rule_dxt5.dds")
    self.minimalRewardRule:SetColor(0.76, 0.73, 0.64, 0.8)
    self.minimalRewardRule:SetDrawLevel(2)
    self.icon = Texture(frame, 42, 42, TOP, TOP, 0, 33, ART .. "iron_trophy_dxt5.dds")
    self.icon:SetTransformNormalizedOriginPoint(0.5, 0.5)
    self.icon:SetDrawLayer(DL_ARTWORK)
    self.icon:SetDrawLevel(4)
    self.caption = Label(frame, 16, 114, { 0.68, 0.74, 0.79, 1 })
    self.caption:SetText(GetString(SI_ACHIEVEMENT_AWARDED_CENTER_SCREEN))
    self.title = Label(frame, 32, 137, { 0.91, 0.94, 0.96, 1 })
    self.title:SetHeight(0)
    self.points = Label(frame, 17, 185, { 0.70, 0.76, 0.80, 1 })
    self.points:SetFont("$(MEDIUM_FONT)|17|soft-shadow-thick")
    self.sweep = Texture(frame, 130, 28, TOP, TOP, 0, 40, ART .. "iron_spark_dxt5.dds")
    self.sweep:SetBlendMode(TEX_BLEND_MODE_ADD)
    self.sweep:SetDrawLayer(DL_OVERLAY)
    self.motes = {}
    for i = 1, 10 do
        local mote = Texture(frame, 14, 14, TOP, TOP, 0, 54, ART .. "iron_spark_dxt5.dds")
        mote:SetBlendMode(TEX_BLEND_MODE_ADD)
        mote:SetDrawLayer(DL_OVERLAY)
        self.motes[i] = mote
    end
    self:ApplyTheme()
end

function Alert:LayoutContent(minimal)
    self.frame:SetDimensions(560, 230)
    self.icon:SetDimensions(minimal and 36 or 42, minimal and 36 or 42)
    self.icon:ClearAnchors()
    self.icon:SetAnchor(TOP, self.frame, TOP, 0, minimal and 14 or 33)
    for _, label in ipairs({ self.caption, self.title, self.points }) do
        label:ClearAnchors()
        label:SetWidth(minimal and 480 or 520)
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    end
    self.caption:SetAnchor(TOP, self.frame, TOP, 0, minimal and 78 or 114)
    local titleY = minimal and (78 + math.max(16, self.caption:GetTextHeight()) + 8) or 137
    self.title:SetAnchor(TOP, self.frame, TOP, 0, titleY)
    -- The reward and its fine rules follow the last line of a localized title.
    local titleBottom = titleY + math.max(minimal and 34 or 38, self.title:GetTextHeight())
    local pointsY = titleBottom + (minimal and 12 or 6)
    self.points:SetAnchor(TOP, self.frame, TOP, 0, pointsY)
    if minimal then
        local bottom = titleBottom
        local pointsHeight = math.max(16, self.points:GetTextHeight())
        if Settings().showPoints then bottom = pointsY + pointsHeight end
        self.frame:SetHeight(bottom + 12)
        -- Wide translations keep their own clear space between the rules.
        local pointsWidth = self.points:GetTextWidth()
        self.minimalRewardRule:SetHidden(not Settings().showPoints or pointsWidth > 108 or pointsHeight > 20)
        self.minimalRewardRule:ClearAnchors()
        self.minimalRewardRule:SetAnchor(TOP, self.frame, TOP, 0, pointsY + (pointsHeight - 16) / 2)
    end
    self.shade:SetDimensions(640, minimal and math.max(250, self.frame:GetHeight() + 64) or 270)
end

function Alert:ApplyTheme()
    local themes = Nirnsteel_UI.Themes
    if not themes or not self.root then return end
    local minimal = themes:IsMinimal()
    for _, decoration in ipairs({ self.rule, self.glow, self.crest }) do
        decoration:SetHidden(minimal)
    end
    self.shade:SetAlpha(minimal and 0.8 or 1)
    for _, decoration in ipairs({ self.minimalSeal, self.minimalRule, self.minimalRewardRule }) do
        decoration:SetHidden(not minimal)
    end
    self.rule:SetColor(themes:Color("rim", 1, 1, 1, 1))
    self.crest:SetColor(themes:Color("highlight", 1, 1, 1, 1))
    self.glow:SetColor(themes:Color("highlight", 1, 1, 1, 1))
    themes:ApplyMinimalBorder(self.icon, true, DL_ARTWORK)
    -- Theme only the bundled trophy; earned achievement icons keep their colors.
    if self.current and self.current.icon then
        self.icon:SetTexture(self.current.icon)
        self.icon:SetColor(1, 1, 1, 1)
    elseif minimal then
        self.icon:SetTexture(ART .. "minimal_mark_dxt5.dds")
        self.icon:SetColor(0.88, 0.85, 0.75, 1)
    else
        self.icon:SetTexture(ART .. "iron_trophy_dxt5.dds")
        self.icon:SetColor(themes:Color("text", 1, 1, 1, 1))
    end
    if minimal then
        self.caption:SetColor(0.68, 0.68, 0.64, 1)
        self.title:SetColor(0.96, 0.95, 0.91, 1)
        self.points:SetColor(0.82, 0.79, 0.70, 1)
    else
        self.caption:SetColor(themes:Color("body", 0.68, 0.74, 0.79, 1))
        self.title:SetColor(themes:Color("text", 0.91, 0.94, 0.96, 1))
        self.points:SetColor(themes:Color("body", 0.70, 0.76, 0.80, 1))
    end
    self.caption:SetFont(minimal and "$(MEDIUM_FONT)|13|soft-shadow-thick" or "$(ANTIQUE_FONT)|16|soft-shadow-thick")
    self.title:SetFont(minimal and "$(ANTIQUE_FONT)|28|soft-shadow-thin" or "$(ANTIQUE_FONT)|32|soft-shadow-thick")
    self.points:SetFont(minimal and "$(MEDIUM_FONT)|14|soft-shadow-thin" or "$(MEDIUM_FONT)|17|soft-shadow-thick")
    self:LayoutContent(minimal)
end

function Alert:ApplyLayout()
    if not self.root then return end
    local settings = Settings()
    self.root:ClearAnchors()
    self.root:SetAnchor(CENTER, GuiRoot, CENTER, Clamp(settings.x, -1600, 1600), Clamp(settings.y, -900, 900))
    self.root:SetScale(Clamp(settings.scale, 60, 160) / 100)
    self.root:SetAlpha(Clamp(settings.opacity, 20, 100) / 100)
    self.points:SetHidden(not settings.showPoints)
    self:ApplyTheme()
end

function Alert:Animate()
    local elapsed = self.elapsed or 0
    local duration = self.duration
    local entrance = Clamp(elapsed / 700, 0, 1)
    local exit = Clamp((elapsed - duration + 700) / 700, 0, 1)
    -- Fades only for every profile, including old saved reducedMotion=false values.
    self.frame:SetAlpha(entrance * (1 - exit))
    self.frame:ClearAnchors()
    self.frame:SetAnchor(CENTER, self.root, CENTER, 0, 0)
    self.crest:SetTransformScale(1)
    self.icon:SetTransformScale(1)
    local reveal = Clamp((elapsed - 350) / 650, 0, 1)
    self.caption:SetAlpha(reveal)
    self.title:SetAlpha(Clamp((elapsed - 550) / 650, 0, 1))
    self.points:SetAlpha(Clamp((elapsed - 950) / 600, 0, 1))
    self.rule:SetAlpha(reveal)
    self.minimalRule:SetAlpha(reveal)
    self.minimalRewardRule:SetAlpha(Clamp((elapsed - 950) / 600, 0, 1))
    self.rule:SetWidth(512)
    self.glow:SetAlpha(0.48)
    self.glow:SetTransformScale(1)
    self.sweep:SetAlpha(0)
    for _, mote in ipairs(self.motes) do
        mote:SetAlpha(0)
    end
end

function Alert:StartNext()
    self.current = table.remove(self.queue, 1)
    if not self.current then
        self.root:SetHidden(true)
        EVENT_MANAGER:UnregisterForUpdate(NAMESPACE)
        return
    end
    self.elapsed = 0
    self.duration = Clamp(Settings().duration, 3, 12) * 1000
    self.lastTime = GetFrameTimeMilliseconds()
    self.icon:SetTexture(self.current.icon or ART .. "iron_trophy_dxt5.dds")
    self.title:SetText(self.current.name)
    self.points:SetText("+" .. tostring(self.current.points) .. " " .. GetString(SI_ACHIEVEMENTS_POINTS_STATIC))
    self.soundPlayed = false
    self:ApplyLayout()
    self:Animate()
    self:Update()
    EVENT_MANAGER:RegisterForUpdate(NAMESPACE, 16, function() self:Update() end)
end

function Alert:Update()
    if not self.current then return end
    local now = GetFrameTimeMilliseconds()
    local visible = self.current.preview or SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")
    self.root:SetHidden(not visible)
    if visible then
        if not self.soundPlayed then
            self.soundPlayed = true
            if Settings().sound then PlaySound(SOUNDS.ACHIEVEMENT_AWARDED) end
        end
        self.elapsed = self.elapsed + math.max(0, now - self.lastTime)
        self:Animate()
    end
    self.lastTime = now
    if self.elapsed >= self.duration then self:StartNext() end
end

function Alert:Enqueue(name, points, id, preview)
    if not Settings().enabled then return false end
    self:CreateView()
    local icon = id and select(4, GetAchievementInfo(id))
    self.queue[#self.queue + 1] = {
        name = zo_strformat("<<1>>", name or ""), points = tonumber(points) or 0,
        icon = icon and icon ~= "" and icon or nil,
        preview = preview,
    }
    if not self.current then self:StartNext() end
    return true
end

function Alert:Preview()
    -- Repeated preview clicks never build a backlog or discard earned achievements.
    if self.current then return end
    self:Enqueue("A Legend Forged", 50, nil, true)
end

function Alert:RefreshSettings()
    if not self.root then return end
    self:ApplyLayout()
    if not Settings().enabled then
        self.queue = {}
        self.current = nil
        self.root:SetHidden(true)
        EVENT_MANAGER:UnregisterForUpdate(NAMESPACE)
    end
end

function Alert:Initialize()
    if self.hooked or not CENTER_SCREEN_ANNOUNCE then return end
    self:CreateView()
    -- Intercept the event, not its CSA type: dye/title unlocks share that type.
    -- Disabled settings fall through to the original handler immediately.
    ZO_PreHook(CENTER_SCREEN_ANNOUNCE, "OnCenterScreenEvent", function(_, eventId, name, points, id)
        if eventId == EVENT_ACHIEVEMENT_AWARDED and Settings().enabled then
            return self:Enqueue(name, points, id)
        end
        return false
    end)
    self.hooked = true
end

EVENT_MANAGER:RegisterForEvent(NAMESPACE .. "_Loaded", EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(NAMESPACE .. "_Loaded", EVENT_ADD_ON_LOADED)
    Alert:Initialize()
end)
EVENT_MANAGER:RegisterForEvent(NAMESPACE .. "_Activated", EVENT_PLAYER_ACTIVATED, function() Alert:Initialize() end)
