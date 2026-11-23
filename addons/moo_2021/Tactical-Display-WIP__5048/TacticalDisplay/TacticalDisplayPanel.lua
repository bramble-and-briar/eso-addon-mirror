TacticalDisplay = TacticalDisplay or {}
TacticalDisplay.Panel = TacticalDisplay.Panel or {}
local _Panel = TacticalDisplay.Panel
local _OnOpponentUpdated = TacticalDisplay.Data.OnOpponentUpdated
---@diagnostic disable-next-line: undefined-global
local _AbilityTooltip = AbilityTooltip

local _config
local _defaults = {
    offsetX = 40,
    offsetY = 240,
}

local _opponentActiveDuration = 2
local _opponentVisibleDuration = 30

local FONT_BOLD = "$(BOLD_FONT)|18|soft-shadow-thick"
local FONT_NORMAL = "$(MEDIUM_FONT)|18|soft-shadow-thick"

local MIN_WIDTH = 240
local MIN_HEIGHT = 100
local CONTENT_PADDING = 8

local MAX_VISIBLE_OPPONENTS = 12
local OPPONENT_ROW_HEIGHT = 23
local OPPONENT_SIGNATURE_CAP = 4
local OPPONENT_DD_LABEL_WIDTH = 50
local OPPONENT_TANK_LABEL_WIDTH = 40
local OPPONENT_ATTACK_ICON_MARGIN = 6
local OPPONENT_ATTACK_ICON_SIZE = 20

local _visibleOpponentEntries = {} -- [index] = { opponent, isActive }

local _isPanelEnabled = false
local _fragment
local _window
local _reserve
local _contentAreaLeft
local _contentAreaRight
local _opponentRows = {}

-------------------------------------------------------------------------------
-- Create UI
-------------------------------------------------------------------------------

local function SaveWindowPosition()
    if _window and _config then
        local left, top = _window:GetLeft(), _window:GetTop()
        if left and top then
            _config.offsetX = left
            _config.offsetY = top
        end
    end
end

local function CreateRowAnimation(parent)
    local timeline = ANIMATION_MANAGER:CreateTimeline()

    local scaleAnim = timeline:InsertAnimation(ANIMATION_SCALE, parent, 0)
    scaleAnim:SetScaleValues(1.1, 1.0)
    scaleAnim:SetDuration(100)
    scaleAnim:SetEasingFunction(ZO_EaseOutQuadratic)

    local fadeOutAnim = timeline:InsertAnimation(ANIMATION_ALPHA, parent, 0)
    fadeOutAnim:SetAlphaValues(1, 0.25)
    fadeOutAnim:SetDuration(_opponentVisibleDuration * 1000 / 4 * 3)

    return timeline
end

local function SignatureIconOnMouseEnter(self)
    if not self.abilityId or self.abilityId == 0 then
        return
    end
    InitializeTooltip(_AbilityTooltip, self, BOTTOM, 0, -4)
    _AbilityTooltip:SetAbilityId(self.abilityId)
end

local function SignatureIconOnMouseExit()
    ClearTooltip(_AbilityTooltip)
end

local function CreateUI()
    _window = WINDOW_MANAGER:CreateTopLevelWindow("TacticalDisplayWindow")
    _window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, _defaults.offsetX, _defaults.offsetY)
    -- _window:SetDimensions(MIN_WIDTH, CONTENT_PADDING * 2 + MAX_VISIBLE_OPPONENTS * OPPONENT_ROW_HEIGHT)
    _window:SetResizeToFitDescendents(true)
    _window:SetResizeToFitConstrains(ANCHOR_CONSTRAINS_XY)
    _window:SetResizeToFitPadding(CONTENT_PADDING * 2, CONTENT_PADDING * 2)
    _window:SetDrawTier(DT_LOW)
    _window:SetDrawLayer(DL_OVERLAY)
    _window:SetClampedToScreen(true)
    _window:SetMouseEnabled(true)
    _window:SetMovable(true)
    _window:SetHidden(false)
    _window:SetHandler("OnMoveStop", SaveWindowPosition)

    _reserve = WINDOW_MANAGER:CreateControl(nil, _window, CT_CONTROL)
    _reserve:SetAnchor(TOPLEFT, _window, TOPLEFT, 0, 0)
    _reserve:SetDimensions(MIN_WIDTH, MIN_HEIGHT)
    _reserve:SetMouseEnabled(false)

    local _reserveTitle = WINDOW_MANAGER:CreateControl(nil, _reserve, CT_LABEL)
    _reserveTitle:SetFont(FONT_BOLD)
    _reserveTitle:SetColor(1.0, 0.8, 0, 0.75)
    _reserveTitle:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    _reserveTitle:SetAnchor(TOPLEFT, _reserve, TOPLEFT, CONTENT_PADDING, CONTENT_PADDING)
    _reserveTitle:SetText("Tactical Display")
    _reserveTitle:SetHidden(false)

    local _backdrop = WINDOW_MANAGER:CreateControl(nil, _window, CT_BACKDROP)
    _backdrop:SetAnchorFill(_window)
    _backdrop:SetExcludeFromResizeToFitExtents(true)
    _backdrop:SetCenterColor(0.4, 0.2, 0, 0.2)

    _backdrop:SetEdgeColor(1.0, 1.0, 1.0, 0.5)
    _backdrop:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", CONTENT_PADDING, CONTENT_PADDING, 2, 0)
    _backdrop:SetMouseEnabled(false)

    _contentAreaLeft = WINDOW_MANAGER:CreateControl("TacticalDisplayContentLeft", _window, CT_CONTROL)
    _contentAreaLeft:SetAnchor(TOPLEFT, _window, TOPLEFT, CONTENT_PADDING, CONTENT_PADDING)
    _contentAreaLeft:SetResizeToFitDescendents(true)
    _contentAreaLeft:SetResizeToFitConstrains(ANCHOR_CONSTRAINS_XY)
    _contentAreaLeft:SetMouseEnabled(false)

    _contentAreaRight = WINDOW_MANAGER:CreateControl("TacticalDisplayContentRight", _window, CT_CONTROL)
    _contentAreaRight:SetAnchor(TOPLEFT, _contentAreaLeft, TOPRIGHT, CONTENT_PADDING, 0)
    _contentAreaRight:SetResizeToFitDescendents(true)
    _contentAreaRight:SetResizeToFitConstrains(ANCHOR_CONSTRAINS_XY)
    _contentAreaRight:SetMouseEnabled(false)

    for index = 1, MAX_VISIBLE_OPPONENTS do
        local groupLeft = WINDOW_MANAGER:CreateControl(nil, _contentAreaLeft, CT_CONTROL)
        groupLeft:SetAnchor(TOPRIGHT, _contentAreaLeft, TOPRIGHT, 0, 0)
        groupLeft:SetDimensions(0, OPPONENT_ROW_HEIGHT)
        groupLeft:SetResizeToFitDescendents(true)
        groupLeft:SetResizeToFitConstrains(ANCHOR_CONSTRAINS_X)
        groupLeft:SetMouseEnabled(false)

        local nameLabel = WINDOW_MANAGER:CreateControl(nil, groupLeft, CT_LABEL)
        nameLabel:SetAnchor(TOPRIGHT, groupLeft, TOPRIGHT, 0, 0)
        nameLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        nameLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        nameLabel:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
        nameLabel:SetFont(FONT_NORMAL)
        nameLabel:SetColor(1, 1, 1, 1)
        nameLabel:SetMouseEnabled(false)

        local groupRight = WINDOW_MANAGER:CreateControl(nil, _contentAreaRight, CT_CONTROL)
        groupRight:SetAnchor(TOPLEFT, _contentAreaRight, TOPLEFT, 0, 0)
        groupRight:SetDimensions(0, OPPONENT_ROW_HEIGHT)
        groupRight:SetResizeToFitDescendents(true)
        groupRight:SetResizeToFitConstrains(ANCHOR_CONSTRAINS_X)
        groupRight:SetMouseEnabled(false)

        local signatureIcons = {}
        for i = 1, OPPONENT_SIGNATURE_CAP do
            local icon = WINDOW_MANAGER:CreateControl(nil, groupRight, CT_TEXTURE)
            if i == 1 then
                icon:SetAnchor(TOPLEFT, groupRight, TOPLEFT, 0, 0)
            else
                icon:SetAnchor(TOPLEFT, signatureIcons[i - 1], TOPRIGHT, 1, 0)
            end
            icon:SetDimensions(OPPONENT_ATTACK_ICON_SIZE, OPPONENT_ATTACK_ICON_SIZE)
            icon:SetDrawLayer(DL_OVERLAY)
            icon:SetMouseEnabled(true)
            icon:SetHandler("OnMouseEnter", SignatureIconOnMouseEnter)
            icon:SetHandler("OnMouseExit", SignatureIconOnMouseExit)
            icon:SetHidden(true)
            signatureIcons[i] = icon
        end

        local ddLabel = WINDOW_MANAGER:CreateControl(nil, groupRight, CT_LABEL)
        ddLabel:SetAnchor(TOPLEFT, signatureIcons[OPPONENT_SIGNATURE_CAP], TOPRIGHT, 0, 0)
        ddLabel:SetDimensions(OPPONENT_DD_LABEL_WIDTH, OPPONENT_ROW_HEIGHT)
        ddLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        ddLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        ddLabel:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
        ddLabel:SetFont(FONT_NORMAL)
        ddLabel:SetColor(1, 1, 1, 1)
        ddLabel:SetMouseEnabled(false)

        local tankLabel = WINDOW_MANAGER:CreateControl(nil, groupRight, CT_LABEL)
        tankLabel:SetAnchor(LEFT, ddLabel, RIGHT, 0, 0)
        tankLabel:SetDimensions(OPPONENT_TANK_LABEL_WIDTH, OPPONENT_ROW_HEIGHT)
        tankLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        tankLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        tankLabel:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
        tankLabel:SetFont(FONT_NORMAL)
        tankLabel:SetColor(1, 1, 1, 1)
        tankLabel:SetMouseEnabled(false)

        local attackIcon = WINDOW_MANAGER:CreateControl(nil, groupRight, CT_TEXTURE)
        attackIcon:SetAnchor(LEFT, tankLabel, RIGHT, OPPONENT_ATTACK_ICON_MARGIN, 0)
        attackIcon:SetDimensions(OPPONENT_ATTACK_ICON_SIZE, OPPONENT_ATTACK_ICON_SIZE)
        attackIcon:SetMouseEnabled(false)
        attackIcon:SetHidden(true)

        local attackLabel = WINDOW_MANAGER:CreateControl(nil, groupRight, CT_LABEL)
        attackLabel:SetAnchor(LEFT, attackIcon, RIGHT, OPPONENT_ATTACK_ICON_MARGIN, 0)
        attackLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        attackLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        attackLabel:SetFont(FONT_NORMAL)
        attackLabel:SetColor(1, 1, 1, 1)
        attackLabel:SetMouseEnabled(false)

        groupLeft:SetHidden(true)
        groupRight:SetHidden(true)
        _opponentRows[index] = {
            groupLeft = groupLeft,
            groupRight = groupRight,
            timelineLeft = CreateRowAnimation(groupLeft),
            timelineRight = CreateRowAnimation(groupRight),
            nameLabel = nameLabel,
            signatureIcons = signatureIcons,
            ddLabel = ddLabel,
            tankLabel = tankLabel,
            attackIcon = attackIcon,
            attackLabel = attackLabel,
        }
    end

    _fragment = ZO_FadeSceneFragment:New(_window, true, 150)
    _fragment:SetConditional(function()
        return _isPanelEnabled
    end)
    SCENE_MANAGER:GetScene("hud"):AddFragment(_fragment)
    SCENE_MANAGER:GetScene("hudui"):AddFragment(_fragment)
end

local function ApplyLayout()
    _window:ClearAnchors()
    _window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT,
        _config.offsetX or _defaults.offsetX,
        _config.offsetY or _defaults.offsetY)
end

-------------------------------------------------------------------------------
-- Update UI
-------------------------------------------------------------------------------

local function RenderRowContents(row, opponentEntry)
    local opponent = opponentEntry.opponent
    local rowFont = opponentEntry.isActive and FONT_BOLD or FONT_NORMAL

    row.nameLabel:SetFont(rowFont)
    row.nameLabel:SetText(opponent.name or "?")

    local signature = opponent.signature or {}
    local sigKeys = {}
    for abilityId in pairs(signature) do
        sigKeys[#sigKeys + 1] = abilityId
    end
    table.sort(sigKeys)

    local numSig = 1
    for _, abilityId in ipairs(sigKeys) do
        local sitem = signature[abilityId]
        local icon = row.signatureIcons[numSig]
        if not icon then
            break
        end
        icon.abilityId = abilityId
        icon:SetTexture(sitem.abilityIcon)
        icon:SetHidden(false)
        numSig = numSig + 1
    end
    for i = numSig, #row.signatureIcons do
        local icon = row.signatureIcons[i]
        icon.abilityId = 0
        icon:SetTexture(nil)
        icon:SetHidden(true)
    end

    if (opponent.lastBaseDamage or 0) > 0 then
        row.ddLabel:SetText(string.format("%d ||", opponent.lastBaseDamage))
        row.ddLabel:SetColor(1, 1, 1, 1.0)
    else
        row.ddLabel:SetText("0000 ||")
        row.ddLabel:SetColor(1, 1, 1, 0.5)
    end
    if (opponent.lastMitigation or 0) > 0 then
        local m = opponent.lastMitigation
        if m > 99 then
            m = 99
        end
        row.tankLabel:SetText(string.format("%d%%", m))
        row.tankLabel:SetColor(1, 1, 1, 1.0)
    else
        row.tankLabel:SetText("??%")
        row.tankLabel:SetColor(1, 1, 1, 0.5)
    end

    local attackIcon = nil
    local attackMarkupParts = {}

    if opponent.lastDealtAttack then
        local attack = opponent.lastDealtAttack
        attackIcon = attack.abilityIcon

        local abilityText = attack.abilityName
        local abilityMarkup = abilityText
        if attack.isCritical then
            abilityMarkup = "|cFFFF00" .. abilityText .. "|r"
        end
        if abilityText ~= "" then
            attackMarkupParts[#attackMarkupParts + 1] = abilityMarkup
        end

        local damageText = (attack.damage or -1) >= 0 and tostring(attack.damage) or ""
        local damageMarkup = damageText
        if attack.isBlocked then
            damageMarkup = "|c7F00FF" .. damageText .. "|r"
        elseif attack.isShielded then
            damageMarkup = "|c00FF00" .. damageText .. "|r"
        end

        if damageText ~= "" then
            attackMarkupParts[#attackMarkupParts + 1] = damageMarkup
        end
    end

    row.attackIcon:SetTexture(attackIcon)
    row.attackIcon:SetHidden(attackIcon == nil)

    row.attackLabel:SetFont(rowFont)
    local attackText = table.concat(attackMarkupParts, "  ")
    row.attackLabel:SetText(attackText)

    row.groupLeft:SetHidden(false)
    row.groupRight:SetHidden(false)
    row.timelineLeft:PlayFromStart()
    row.timelineRight:PlayFromStart()
end

local function ClearRowUI(row)
    row.nameLabel:SetText("")
    for _, icon in ipairs(row.signatureIcons) do
        icon.abilityId = 0
        icon:SetTexture(nil)
        icon:SetHidden(true)
    end
    row.attackIcon:SetTexture(nil)
    row.attackIcon:SetHidden(true)
    row.attackLabel:SetText("")
    row.groupLeft:SetHidden(true)
    row.groupRight:SetHidden(true)
    row.timelineLeft:Stop()
    row.timelineRight:Stop()
end

local function RenderRowUI(index, row)
    local entry = _visibleOpponentEntries[index]
    if not entry then
        if row.needsRender then
            ClearRowUI(row)
            row.needsRender = false
        end
        return
    end

    if row.needsAnchor then
        row.groupLeft:ClearAnchors()
        row.groupLeft:SetAnchor(TOPRIGHT, _contentAreaLeft, TOPRIGHT, 0, (index - 1) * OPPONENT_ROW_HEIGHT)
        row.groupRight:ClearAnchors()
        row.groupRight:SetAnchor(TOPLEFT, _contentAreaRight, TOPLEFT, 0, (index - 1) * OPPONENT_ROW_HEIGHT)
        row.needsAnchor = false
    end
    if row.needsRender then
        RenderRowContents(row, entry)
        row.needsRender = false
    end
end

local function RenderPanelUI()
    _reserve:SetHidden(#_visibleOpponentEntries > 0)

    for index, row in ipairs(_opponentRows) do
        RenderRowUI(index, row)
    end
end

local UPDATE_RENDER_NAME = "TacticalDisplay_Panel_Render"
local UPDATE_RENDER_DELAY_MS = 100

local _renderTaskScheduled = false

local function DoRenderTask()
    EVENT_MANAGER:UnregisterForUpdate(UPDATE_RENDER_NAME)
    _renderTaskScheduled = false
    RenderPanelUI()
end

local function ScheduleRenderTask()
    if _renderTaskScheduled then
        return
    end
    _renderTaskScheduled = true

    EVENT_MANAGER:RegisterForUpdate(UPDATE_RENDER_NAME, UPDATE_RENDER_DELAY_MS, DoRenderTask)
end

-------------------------------------------------------------------------------
-- Update view model
-------------------------------------------------------------------------------

local function RemoveVisibleOpponentAt(index)
    table.remove(_visibleOpponentEntries, index)
    local removedRow = table.remove(_opponentRows, index)
    table.insert(_opponentRows, removedRow)
    removedRow.needsAnchor = false
    removedRow.needsRender = true
    for rowIndex = index, #_visibleOpponentEntries do
        _opponentRows[rowIndex].needsAnchor = true
    end
end

local function InsertVisibleOpponentAtTop(opponent)
    if #_visibleOpponentEntries >= MAX_VISIBLE_OPPONENTS then
        RemoveVisibleOpponentAt(#_visibleOpponentEntries)
    end

    table.insert(_visibleOpponentEntries, 1, {
        opponent = opponent,
        isActive = true,
    })
    local row = table.remove(_opponentRows, #_visibleOpponentEntries)
    table.insert(_opponentRows, 1, row)
    row.needsAnchor = true
    row.needsRender = true
    for index = 2, #_visibleOpponentEntries do
        _opponentRows[index].needsAnchor = true
    end
end

local function AddOrUpdateVisibleOpponent(opponent)
    for index, entry in ipairs(_visibleOpponentEntries) do
        if entry.opponent == opponent then
            entry.isActive = true
            _opponentRows[index].needsRender = true
            return index
        end
    end

    InsertVisibleOpponentAtTop(opponent)
end

-------------------------------------------------------------------------------
-- Trigger: scheduled cleanup and opponent update events
-------------------------------------------------------------------------------

local UPDATE_CLEANUP_NAME = "TacticalDisplay_Panel_Cleanup"
local UPDATE_CLEANUP_INTERVAL_MS = 1000

local function CleanupOpponentEntries()
    local now = GetTimeStamp()
    local changed = false
    for index = #_visibleOpponentEntries, 1, -1 do
        local opponentEntry = _visibleOpponentEntries[index]
        local opponent = opponentEntry and opponentEntry.opponent
        if not opponent
            or not opponent.lastSeen
            or now - opponent.lastSeen >= _opponentVisibleDuration then
            RemoveVisibleOpponentAt(index)
            changed = true
        else
            local isActive = now - opponent.lastSeen <= _opponentActiveDuration
            if opponentEntry.isActive ~= isActive then
                opponentEntry.isActive = isActive
                _opponentRows[index].needsRender = true
                changed = true
            end
        end
    end
    if changed then
        ScheduleRenderTask()
    end
end

local OPPONENT_UPDATE_NAME = "TacticalDisplayPanel_Update"

local function OnOpponentUpdated(opponent)
    AddOrUpdateVisibleOpponent(opponent)
    ScheduleRenderTask()
end

-------------------------------------------------------------------------------
-- Public functions
-------------------------------------------------------------------------------

function _Panel.Initialize(savedVars)
    savedVars.panel = savedVars.panel or _defaults
    _config = savedVars.panel

    CreateUI()
    ApplyLayout()
end

function _Panel.Enable()
    if _isPanelEnabled then
        return
    end

    _OnOpponentUpdated[OPPONENT_UPDATE_NAME] = OnOpponentUpdated
    EVENT_MANAGER:RegisterForUpdate(UPDATE_CLEANUP_NAME, UPDATE_CLEANUP_INTERVAL_MS, CleanupOpponentEntries)

    _isPanelEnabled = true
    _fragment:Refresh()

    ScheduleRenderTask()
end

function _Panel.Disable()
    if not _isPanelEnabled then
        return
    end

    EVENT_MANAGER:UnregisterForUpdate(UPDATE_CLEANUP_NAME)
    _OnOpponentUpdated[OPPONENT_UPDATE_NAME] = nil

    _isPanelEnabled = false
    _fragment:Refresh()
end

function _Panel.UpdateParameters(activeDuration, visibleDuration)
    _opponentActiveDuration = activeDuration or 1
    _opponentVisibleDuration = visibleDuration or 1
end

function _Panel.ResetLayout()
    _config.offsetX = _defaults.offsetX
    _config.offsetY = _defaults.offsetY
    ApplyLayout()
end
