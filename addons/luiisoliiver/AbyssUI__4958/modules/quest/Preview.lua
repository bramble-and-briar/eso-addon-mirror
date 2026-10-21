-- Предпросмотр оформления: пока открыта страница настроек аддона, справа от
-- меню видны панель заданий, панель мест и панель заданий карты — цвета и
-- прозрачность меняются на глазах, не нужно закрывать настройки.
-- Кнопки на экране тоже показываются на своих местах.
-- Выключается в настройках («Предпросмотр при настройке»).
local QTM = AbyssQuest

local Preview = {}
QTM.Preview = Preview

local WIDTH      = 360   -- ширина колонки предпросмотра
local EDGE       = 16    -- отступ от правого края экрана
local MARGIN_TOP = 70
local MARGIN_BOTTOM = 90 -- внизу полоса клавиш меню
local GAP        = 10
local MIN_PANEL  = 200   -- ниже панели карты не помещаются

function Preview:Initialize()
    if not CALLBACK_MANAGER then return end

    local function IsHostPanel(panel)
        return panel ~= nil and panel.GetName and panel:GetName() == QTM.hostPanelName
    end

    -- Mostra a pré-visualização só enquanto a pasta "AbyssQuest" está aberta
    -- no painel do AbyssUI (as outras pastas têm as próprias pré-visualizações).
    local function Update()
        zo_callLater(function()
            local submenu = _G[QTM.submenuRef]
            if submenu and submenu.open == true then self:Show() else self:Hide() end
        end, 50)
    end

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", function(panel)
        if not IsHostPanel(panel) then return end
        local submenu = _G[QTM.submenuRef]
        if not submenu or submenu.questPreviewHooked then return end
        if ZO_PostHookHandler then
            if submenu.label then ZO_PostHookHandler(submenu.label, "OnMouseUp", Update) end
            if submenu.btmToggle then ZO_PostHookHandler(submenu.btmToggle, "OnMouseUp", Update) end
        end
        submenu.questPreviewHooked = true
        Update()
    end)
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
        if IsHostPanel(panel) then Update() end
    end)
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(panel)
        if IsHostPanel(panel) then self:Hide() end
    end)
    -- На случай, если меню закрыли целиком
    local scene = SCENE_MANAGER and SCENE_MANAGER:GetScene("gameMenuInGame")
    if scene then
        scene:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_HIDING or newState == SCENE_HIDDEN then self:Hide() end
        end)
    end
end

function Preview:IsActive()
    return self.active == true
end

function Preview:Show()
    if self.active or QTM.sv.settingsPreview == false then return end
    self.active = true
    self:Layout()
    -- Кнопки на экране: на своих местах, поверх меню
    local hud = QTM.Buttons and QTM.Buttons.hud
    if hud then
        self.hudTier = hud:GetDrawTier()
        hud:SetDrawTier(DT_HIGH)
        hud:SetHidden(false)
    end
end

-- Колонка у правого края: панель заданий, под ней панель мест и задания карты
function Preview:Layout()
    local right = GuiRoot:GetWidth() - EDGE
    local top = MARGIN_TOP
    local bottom = GuiRoot:GetHeight() - MARGIN_BOTTOM
    local y = QTM.QuestTracker:SetPreview(true, right, top, WIDTH)
    if y > top then y = y + GAP end

    local mapOn  = QTM.MapPanel:IsEnabled()
    local infoOn = QTM.InfoPanel:IsEnabled()
    local rest = bottom - y
    if mapOn and infoOn and rest >= MIN_PANEL * 2 + GAP then
        local height = zo_floor((rest - GAP) * 0.42)
        QTM.MapPanel:SetPreview(true, right, y, WIDTH, height)
        QTM.InfoPanel:SetPreview(true, right, y + height + GAP, WIDTH, rest - height - GAP)
    elseif infoOn and rest >= MIN_PANEL then
        QTM.InfoPanel:SetPreview(true, right, y, WIDTH, rest)
    elseif mapOn and rest >= MIN_PANEL then
        QTM.MapPanel:SetPreview(true, right, y, WIDTH, rest)
    end
end

function Preview:Hide()
    if not self.active then return end
    self.active = false
    QTM.QuestTracker:SetPreview(false)
    QTM.MapPanel:SetPreview(false)
    QTM.InfoPanel:SetPreview(false)
    local hud = QTM.Buttons and QTM.Buttons.hud
    if hud and self.hudTier then
        hud:SetDrawTier(self.hudTier)
        hud:SetHidden(true)   -- на экране игры кнопки снова покажет их фрагмент
    end
    self.hudTier = nil
end

-- Тема или настройки панелей изменились
function Preview:Refresh()
    if not self.active then return end
    QTM.MapPanel:RefreshPreview()
    QTM.InfoPanel:RefreshPreview()
end

-- Включили или выключили панель в настройках — перестроить колонку
function Preview:Rebuild()
    if not self.active then return end
    self:Hide()
    self:Show()
end
