MyGridHelper = {}
MyGridHelper.name = "MyGridHelper"
MyGridHelper.panel = {}
MyGridHelper.abilityState = {}

-- 監視するアビリティ ID
local UNLUCKY_VISION_ABILITY_ID = 241224
local IMPENDING_ANNIHILATION_ABILITY_ID = 241229

-- デフォルトの部屋範囲
MyGridHelper.ROOM = {
    xMin = 0.2909, xMax = 0.6970,
    zMin = 0.2970, zMax = 0.6909,
}

-----------------------------------------------------------
-- 視点(2/4/6/8)に応じたレイアウト回転
-----------------------------------------------------------
local layouts = {
    [8] = {1,2,3,4,5,6,7,8,9},      -- 北（回転なし）
    [2] = {9,8,7,6,5,4,3,2,1},      -- 南（180度）
    [4] = {3,6,9,2,5,8,1,4,7},      -- 西（左回転）
    [6] = {7,4,1,8,5,2,9,6,3},      -- 東（右回転）
}

local function GetFacingDirection()
    local h = GetPlayerCameraHeading()
    local deg = math.deg(h)

    if deg >= 315 or deg < 45 then return 6      -- 東
    elseif deg < 135 then return 2              -- 南
    elseif deg < 225 then return 4              -- 西
    else return 8                                -- 北
    end
end

local function ApplyLayout(sector, facing)
    local layout = layouts[facing]
    if not layout then return sector end
    return layout[sector] or sector
end

-----------------------------------------------------------
-- マップ上のセクター判定（3x3）左右反転修正済み
-----------------------------------------------------------
local function GetCurrentSectorIndex(unitTag, room)
    unitTag = unitTag or "player"
    room = room or MyGridHelper.ROOM
    if not room then return nil end

    local x, z = GetMapPlayerPosition(unitTag)
    if not x or not z then return nil end

    local width  = room.xMax - room.xMin
    local height = room.zMax - room.zMin
    if width <= 0 or height <= 0 then return nil end

    local pctX = (x - room.xMin) / width
    local pctZ = (z - room.zMin) / height
    if pctX < 0 or pctX > 1 or pctZ < 0 or pctZ > 1 then return nil end

    local col = math.floor(pctX * 3)
    local row = math.floor(pctZ * 3)

    if col > 2 then col = 2 end
    if row > 2 then row = 2 end

    local invertedRow = 2 - row
    local invertedCol = 2 - col

    return (invertedRow * 3) + invertedCol + 1
end

-----------------------------------------------------------
-- パネルの強調表示（視点回転対応）
-----------------------------------------------------------
function MyGridHelper.HighlightSector(number)
    for i = 1, 9 do
        if MyGridHelper.panel[i] then
            MyGridHelper.panel[i]:SetCenterColor(0, 0, 0, 0.6)
            MyGridHelper.panel[i]:SetEdgeColor(1, 1, 1, 0.4)
        end
    end

    if number and number >= 1 and number <= 9 then
        local facing = GetFacingDirection()
        local rotated = ApplyLayout(number, facing)

        if MyGridHelper.panel[rotated] then
            MyGridHelper.panel[rotated]:SetCenterColor(1, 1, 0, 0.8)
            MyGridHelper.panel[rotated]:SetEdgeColor(1, 1, 1, 0.9)
        end
    end
end

-----------------------------------------------------------
-- UI作成 (3x3パネル) ※フォント拡大済み
-----------------------------------------------------------
local function CreateUI()
    local wm = WINDOW_MANAGER
    local tlc = wm:CreateTopLevelWindow("MyGridHelperTLC")
    tlc:SetDimensions(180, 180)
    tlc:SetAnchor(CENTER, GuiRoot, CENTER, 300, 0)

    for i = 1, 9 do
        local cell = wm:CreateControl("MyGridSector" .. i, tlc, CT_BACKDROP)
        cell:SetDimensions(56, 56)
        local col = (i - 1) % 3
        local row = math.floor((i - 1) / 3)
        cell:SetAnchor(TOPLEFT, tlc, TOPLEFT, col * 60 + 2, row * 60 + 2)
        cell:SetCenterColor(0, 0, 0, 0.6)
        cell:SetEdgeColor(1, 1, 1, 0.4)

        local label = wm:CreateControl(nil, cell, CT_LABEL)
        label:SetFont("$(BOLD_FONT)|18|soft-shadow-thick")
        label:SetText(i)
        label:SetAnchor(CENTER, cell, CENTER, 0, 0)
        label:SetColor(1, 1, 1, 1)

        MyGridHelper.panel[i] = cell
    end
end

-----------------------------------------------------------
-- Ability開始／完了処理
-----------------------------------------------------------
local function StartAbility(abilityId, nowMs)
    nowMs = nowMs or GetGameTimeMilliseconds()
    local state = MyGridHelper.abilityState[abilityId] or {}
    state.tracking = true
    state.startTime = nowMs
    MyGridHelper.abilityState[abilityId] = state
    d("[MyGridHelper] ability " .. abilityId .. " 開始検知")
end

local function CompleteAbility(abilityId, nowMs)
    nowMs = nowMs or GetGameTimeMilliseconds()
    local state = MyGridHelper.abilityState[abilityId]
    if not state or not state.tracking then return end

    if abilityId == UNLUCKY_VISION_ABILITY_ID then
        local sector = GetCurrentSectorIndex("player")
        if sector then
            MyGridHelper.HighlightSector(sector)
            d("[MyGridHelper] 不吉な幻視 完了 → セクター " .. tostring(sector))
        else
            d("[MyGridHelper] 不吉な幻視 完了だが座標外")
        end
    elseif abilityId == IMPENDING_ANNIHILATION_ABILITY_ID then
        MyGridHelper.HighlightSector(nil)
        d("[MyGridHelper] 迫る壊滅 完了 → ハイライト解除")
    end

    state.tracking = false
    MyGridHelper.abilityState[abilityId] = state
end

-----------------------------------------------------------
-- イベントハンドラ
-----------------------------------------------------------
local function OnEffectChanged(
    eventCode, changeType, effectSlot, effectName, unitTag,
    beginTime, endTime, stackCount, iconName, buffType, effectType,
    abilityType, statusEffectType, unitName, unitId, abilityId, sourceType
)
    if unitTag ~= "player" then return end
    if effectType ~= BUFF_EFFECT_TYPE_DEBUFF then return end
    if changeType ~= EFFECT_RESULT_GAINED then return end

    if abilityId == UNLUCKY_VISION_ABILITY_ID or abilityId == IMPENDING_ANNIHILATION_ABILITY_ID then
        StartAbility(abilityId, beginTime * 1000)
        local delayMs = math.floor((endTime - GetGameTimeSeconds()) * 1000)
        if delayMs < 0 then delayMs = 0 end
        zo_callLater(function() CompleteAbility(abilityId, endTime * 1000) end, delayMs)
    end
end

local function OnCombatChanged(eventCode, inCombat)
    if not inCombat then
        MyGridHelper.HighlightSector(nil)
        MyGridHelper.abilityState = {}
    end
end

-----------------------------------------------------------
-- デバッグコマンド
-----------------------------------------------------------
SLASH_COMMANDS["/test"] = function(extraOptions)
    local num = tonumber(extraOptions)
    if num then
        MyGridHelper.HighlightSector(num)
        d("[MyGridHelper] セクター " .. num .. " を強調しました。")
    else
        d("[MyGridHelper] 1～9 の数字を入力してください。例: /test 5")
    end
end

SLASH_COMMANDS["/sector"] = function()
    local s = GetCurrentSectorIndex("player")
    if s then
        d("[MyGridHelper] 現在のセクター: " .. tostring(s))
    else
        d("[MyGridHelper] ROOM 範囲外または座標取得失敗")
    end
end

-----------------------------------------------------------
-- 初期化
-----------------------------------------------------------
local function OnAddOnLoaded(event, addonName)
    if addonName ~= MyGridHelper.name then return end

    CreateUI()

    EVENT_MANAGER:RegisterForEvent(MyGridHelper.name, EVENT_PLAYER_COMBAT_STATE, OnCombatChanged)
    EVENT_MANAGER:RegisterForEvent(MyGridHelper.name, EVENT_EFFECT_CHANGED, OnEffectChanged)

    d("MyGridHelper がロードされました。/test 1～9 と /sector が使用可能です。")
    EVENT_MANAGER:UnregisterForEvent(MyGridHelper.name, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(MyGridHelper.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)