local ADDON_NAME = "MyTankBars"
MyTankBars = {}
local MTB = MyTankBars

------------------------------------------------------------
-- SavedVariables
------------------------------------------------------------
local saved = nil

------------------------------------------------------------
-- イベントラッパー（ハンドル名方式）
------------------------------------------------------------
local nextEventHandleIndex = 1

local function RegisterForEvent(event, callback)
    local eventHandleName = ADDON_NAME .. nextEventHandleIndex
    EVENT_MANAGER:RegisterForEvent(eventHandleName, event, callback)
    nextEventHandleIndex = nextEventHandleIndex + 1
    return eventHandleName
end

local function UnregisterForEvent(eventHandleName, event)
    EVENT_MANAGER:UnregisterForEvent(eventHandleName, event)
end

------------------------------------------------------------
-- OnAddonLoaded(callback)
------------------------------------------------------------
local function OnAddonLoaded(callback)
    local handleName
    handleName = RegisterForEvent(EVENT_ADD_ON_LOADED, function(event, name)
        if name ~= ADDON_NAME then return end
        callback()
        UnregisterForEvent(handleName, EVENT_ADD_ON_LOADED)
    end)
end

------------------------------------------------------------
-- タンク判定（Xbox/PS5：SelectedRole を使用）
-- ★ 自分（player）はタンクでも表示しない
------------------------------------------------------------
local function IsTank(unitTag)
    local unitName   = GetUnitName(unitTag)
    local playerName = GetUnitName("player")

    if unitName == playerName then
        return false
    end

    local role = GetGroupMemberSelectedRole(unitTag)
    return role == LFG_ROLE_TANK
end

------------------------------------------------------------
-- UI 関連
------------------------------------------------------------
local tankUI = {}
local tankOrder = {}   -- ★ 作成順リスト
local tankContainer

local lastUpdate = {}
local TIMEOUT_SECONDS = 5

local function UpdateContainerPosition()
    if not tankContainer then return end
    tankContainer:ClearAnchors()
    tankContainer:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, saved.x, saved.y)
end

local function EnsureContainer()
    if tankContainer then
        tankContainer:SetHidden(false)
        return
    end

    tankContainer = WINDOW_MANAGER:CreateControl("MyTankBarsContainer", GuiRoot, CT_TOPLEVELCONTROL)
    tankContainer:SetDimensions(400, 800)

    tankContainer:SetMovable(true)
    tankContainer:SetMouseEnabled(true)
    tankContainer:SetClampedToScreen(true)

    tankContainer:SetDrawTier(DT_HIGH)
    tankContainer:SetDrawLayer(DL_OVERLAY)
    tankContainer:SetDrawLevel(999)

    tankContainer:SetHidden(false)

    UpdateContainerPosition()
end

local function CreateTankUI(parent, unitTag, playerName)
    local ui = {}

    local width  = 250
    local height = 90

    ui.control = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    ui.control:SetDimensions(width, height)

    ui.name = WINDOW_MANAGER:CreateControl(nil, ui.control, CT_LABEL)
    ui.name:SetFont("$(BOLD_FONT)|18|soft-shadow-thick")
    ui.name:SetText(playerName)
    ui.name:SetAnchor(TOPLEFT, ui.control, TOPLEFT, 0, 0)

    ui.stamina = WINDOW_MANAGER:CreateControl(nil, ui.control, CT_STATUSBAR)
    ui.stamina:SetDimensions(220, 20)
    ui.stamina:SetAnchor(TOPLEFT, ui.name, BOTTOMLEFT, 0, 10)
    ui.stamina:SetColor(0, 1, 0, 1)
    ui.stamina:SetOrientation(ORIENTATION_HORIZONTAL)
    ui.stamina:SetMinMax(0, 1)
    ui.stamina:SetValue(0)

    ui.magicka = WINDOW_MANAGER:CreateControl(nil, ui.control, CT_STATUSBAR)
    ui.magicka:SetDimensions(220, 20)
    ui.magicka:SetAnchor(TOPLEFT, ui.stamina, BOTTOMLEFT, 0, 10)
    ui.magicka:SetColor(0, 0, 1, 1)
    ui.magicka:SetOrientation(ORIENTATION_HORIZONTAL)
    ui.magicka:SetMinMax(0, 1)
    ui.magicka:SetValue(0)

    return ui
end

------------------------------------------------------------
-- ★ 隙間を詰める（作成順のまま再配置）
------------------------------------------------------------
local function ReanchorAll()
    if not tankContainer then return end

    local y = 0
    for _, unitTag in ipairs(tankOrder) do
        local ui = tankUI[unitTag]
        if ui and not ui.control:IsHidden() then
            ui.control:ClearAnchors()
            ui.control:SetAnchor(TOPLEFT, tankContainer, TOPLEFT, 0, y)
            y = y + 110
        end
    end
end

------------------------------------------------------------
-- UI 非表示
------------------------------------------------------------
local function HideTankUI(unitTag)
    local ui = tankUI[unitTag]
    if not ui then return end
    ui.control:SetHidden(true)
    ReanchorAll()   -- ★ 隠したら詰める
end

------------------------------------------------------------
-- Tank UI 更新
------------------------------------------------------------
local function UpdateTankBar(unitTag, resourceType, value, maxValue)
    if maxValue == 0 then return end

    local ui = tankUI[unitTag]
    if not ui then return end

    local pct = value / maxValue

    if resourceType == "stamina" then
        ui.stamina:SetValue(pct)
    elseif resourceType == "magicka" then
        ui.magicka:SetValue(pct)
    end
end

------------------------------------------------------------
-- リソース更新ハンドラ
------------------------------------------------------------
local function HandleResourceUpdate(unitTag, resourceType, current, maximum)
    if not unitTag or not IsUnitGrouped("player") then
        return
    end

    if not IsTank(unitTag) then
        HideTankUI(unitTag)
        return
    end

    if not current or maximum == 0 then
        return
    end

    lastUpdate[unitTag] = GetFrameTimeSeconds()

    if not tankUI[unitTag] then
        EnsureContainer()
        local name = GetUnitName(unitTag)
        tankUI[unitTag] = CreateTankUI(tankContainer, unitTag, name)

        table.insert(tankOrder, unitTag)  -- ★ 作成順に追加
        ReanchorAll()                     -- ★ 新規作成時も詰める
    end

    tankUI[unitTag].control:SetHidden(false)
    UpdateTankBar(unitTag, resourceType, current, maximum)
end

------------------------------------------------------------
-- 更新停止チェック
------------------------------------------------------------
local function CheckTimeouts()
    local now = GetFrameTimeSeconds()
    for unitTag, t in pairs(lastUpdate) do
        if now - t > TIMEOUT_SECONDS then
            HideTankUI(unitTag)
        end
    end
end

------------------------------------------------------------
-- GroupResources（LibGroupBroadcast）
------------------------------------------------------------
local function RegisterResourceEvents()
    local GroupResources = LibGroupBroadcast and LibGroupBroadcast:GetHandlerApi("GroupResources")
    if not GroupResources then
        return
    end

    GroupResources:RegisterForStaminaChanges(function(unitTag, unitName, current, maximum, percentage)
        HandleResourceUpdate(unitTag, "stamina", current, maximum)
    end)

    GroupResources:RegisterForMagickaChanges(function(unitTag, unitName, current, maximum, percentage)
        HandleResourceUpdate(unitTag, "magicka", current, maximum)
    end)

    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_Timeout", 1000, CheckTimeouts)
end

------------------------------------------------------------
-- スラッシュコマンド
------------------------------------------------------------
SLASH_COMMANDS["/mtbpos"] = function(text)
    local x, y = text:match("^(%-?%d+)%s+(%-?%d+)$")
    if not x or not y then
        d("使用方法: /mtbpos <x> <y>")
        return
    end

    saved.x = tonumber(x)
    saved.y = tonumber(y)

    UpdateContainerPosition()
    d(string.format("MyTankBars: 位置を (%d, %d) に変更しました", saved.x, saved.y))
end

SLASH_COMMANDS["/mtbinfo"] = function()
    d("MyTankBars 設定:")
    d(string.format("位置: x=%d, y=%d", saved.x, saved.y))
end

------------------------------------------------------------
-- AddOn 初期化
------------------------------------------------------------
OnAddonLoaded(function()
    saved = ZO_SavedVars:NewAccountWide("MyTankBarsSaved", 1, nil, {
        x = 550,
        y = 250,
    })

    EnsureContainer()
    RegisterResourceEvents()
end)