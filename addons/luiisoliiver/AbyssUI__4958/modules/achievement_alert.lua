local ADDON_NAME = "AbyssUI"
local NAMESPACE = ADDON_NAME .. "_AchievementAlert"

NAGA_UI = NAGA_UI or {}
local NAGA_UI = NAGA_UI
local Alert = { queue = {} }
NAGA_UI.AchievementAlert = Alert
local ART = "AbyssUI/assets/achievement/"

local function Settings()
    return NAGA_UI.Settings:GetAchievementAlert()
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
    if NAGA_UI.GetAssetPath then ART = NAGA_UI:GetAssetPath("ui/achievement/") end
    local root = WINDOW_MANAGER:CreateTopLevelWindow(NAMESPACE)
    ApplyTemplateToControl(root, "ZO_HUDManager_Element")
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
end

function Alert:ApplyLayout()
    if not self.root then return end
    local settings = Settings()
    self.root:ClearAnchors()
    self.root:SetAnchor(CENTER, GuiRoot, CENTER, Clamp(settings.x, -1600, 1600), Clamp(settings.y, -900, 900))
    self.root:SetScale(Clamp(settings.scale, 60, 160) / 100)
    self.root:SetAlpha(Clamp(settings.opacity, 20, 100) / 100)
    self.points:SetHidden(not settings.showPoints)
    -- Long localized names expand downwards; the reward row follows the text.
    local titleHeight = math.max(38, self.title:GetTextHeight())
    self.points:ClearAnchors()
    self.points:SetAnchor(TOP, self.frame, TOP, 0, 143 + titleHeight)
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
    self.title:ClearAnchors()
    self.title:SetAnchor(TOP, self.frame, TOP, 0, 137)
    self.points:SetAlpha(Clamp((elapsed - 950) / 600, 0, 1))
    self.rule:SetAlpha(reveal)
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
    self.icon:SetTexture(self.current.icon)
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
        icon = icon and icon ~= "" and icon or ART .. "iron_trophy_dxt5.dds",
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

NAGA_UI.OnAddonLoaded(function()
    Alert:Initialize()
end)
EVENT_MANAGER:RegisterForEvent(NAMESPACE .. "_Activated", EVENT_PLAYER_ACTIVATED, function() Alert:Initialize() end)
