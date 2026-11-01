-- SetCooldownTracker v1.0.0 : パネルUI
SetCooldownTracker = SetCooldownTracker or {}
local SCT = SetCooldownTracker
local UI = {}
SCT.UI = UI

local MAX_ROWS = 12
local PAD = 6
local panel, bg, title, fragment
local nameLabels, timeLabels = {}, {}
local created = false

local function FontString(size)
    return string.format("$(MEDIUM_FONT)|%d|soft-shadow-thin", size)
end

function UI:Create()
    if created then return end
    created = true
    panel = WINDOW_MANAGER:CreateTopLevelWindow("SCT_Panel")
    panel:SetMouseEnabled(false)
    panel:SetMovable(false)
    panel:SetHidden(true)

    bg = WINDOW_MANAGER:CreateControl("SCT_PanelBG", panel, CT_TEXTURE)
    bg:SetAnchorFill(panel)
    bg:SetDrawLayer(DL_BACKGROUND)
    bg:SetColor(0, 0, 0, 0.4)

    title = WINDOW_MANAGER:CreateControl("SCT_PanelTitle", panel, CT_LABEL)
    title:SetText("SET COOLDOWN")
    title:SetColor(0.9, 0.9, 0.9, 1)

    for i = 1, MAX_ROWS do
        local n = WINDOW_MANAGER:CreateControl("SCT_RowName" .. i, panel, CT_LABEL)
        n:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        n:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        n:SetHidden(true)
        local t = WINDOW_MANAGER:CreateControl("SCT_RowTime" .. i, panel, CT_LABEL)
        t:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        t:SetHidden(true)
        nameLabels[i], timeLabels[i] = n, t
    end

    -- HUD表示中のみ表示(メニュー・マップ等では自動的に隠れる)
    fragment = ZO_SimpleSceneFragment:New(panel)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
end

function UI:Layout(db)
    if not created then return end
    local fs = db.fontSize
    local rowH = fs + 4
    local w = db.width
    panel:SetScale(db.scale / 100)
    panel:SetWidth(w)
    bg:SetColor(0, 0, 0, db.bgAlpha / 100)
    title:SetFont(FontString(fs))
    title:SetDimensions(w - PAD * 2, rowH)
    title:ClearAnchors()
    title:SetAnchor(TOPLEFT, panel, TOPLEFT, PAD, PAD)
    UI.showTitle = db.showTitle

    local top = PAD + (db.showTitle and rowH or 0)
    for i = 1, MAX_ROWS do
        local n, t = nameLabels[i], timeLabels[i]
        n:SetFont(FontString(fs))
        t:SetFont(FontString(fs))
        n:SetDimensions((w - PAD * 2) * 0.62, rowH)
        t:SetDimensions((w - PAD * 2) * 0.38, rowH)
        n:ClearAnchors()
        t:ClearAnchors()
        n:SetAnchor(TOPLEFT, panel, TOPLEFT, PAD, top + (i - 1) * rowH)
        t:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -PAD, top + (i - 1) * rowH)
    end
    self.rowH, self.top = rowH, top

    local gw, gh = GuiRoot:GetWidth(), GuiRoot:GetHeight()
    local x = math.max(0, (gw - w * db.scale / 100) * db.posX / 100)
    local y = math.max(0, (gh - 40) * db.posY / 100)
    panel:ClearAnchors()
    panel:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

-- rows = { {name=, text=, r=, g=, b=}, ... }
function UI:SetRows(rows)
    if not created then return end
    local n = math.min(#rows, MAX_ROWS)
    if n == 0 then
        UI:HideContent()
        return
    end
    bg:SetHidden(false)
    title:SetHidden(not UI.showTitle)
    for i = 1, MAX_ROWS do
        local row = rows[i]
        if row and i <= MAX_ROWS then
            nameLabels[i]:SetText(row.name)
            timeLabels[i]:SetText(row.text)
            nameLabels[i]:SetColor(row.r, row.g, row.b, 1)
            timeLabels[i]:SetColor(row.r, row.g, row.b, 1)
            nameLabels[i]:SetHidden(false)
            timeLabels[i]:SetHidden(false)
        else
            nameLabels[i]:SetHidden(true)
            timeLabels[i]:SetHidden(true)
        end
    end
    panel:SetHeight((self.top or PAD) + n * (self.rowH or 24) + PAD)
end

-- 表示対象が無い時は中身だけ隠す(panel本体の表示/非表示はシーンのフラグメントが管理する)
function UI:HideContent()
    if not created then return end
    bg:SetHidden(true)
    title:SetHidden(true)
    for i = 1, MAX_ROWS do
        nameLabels[i]:SetHidden(true)
        timeLabels[i]:SetHidden(true)
    end
end

function UI:Hide()
    self:HideContent()
end
