local ADDON = "MyMapPos"

------------------------------------------------------------
-- プレイヤーの現在地を取得してチャットに表示
------------------------------------------------------------
local function PrintPlayerMapPosition()
    -- 正規化座標 (0.0〜1.0)
    local x, y = GetMapPlayerPosition("player")

    -- チャットに表示
    d(string.format("[MyMapPos] x=%.4f, y=%.4f", x, y))
end

------------------------------------------------------------
-- スラッシュコマンド登録 (/mpos)
------------------------------------------------------------
SLASH_COMMANDS["/mpos"] = PrintPlayerMapPosition

------------------------------------------------------------
-- 現在のマップの zoneId を表示するコマンド (/mpzone)
-- ESO の現行 API で zoneId を取得できる唯一の正しい方法
------------------------------------------------------------
SLASH_COMMANDS["/mpzone"] = function()
    -- プレイヤーがいるゾーンの zoneIndex を取得
    local zoneIndex = GetUnitZoneIndex("player")

    -- zoneIndex から zoneId を取得
    local zoneId = GetZoneId(zoneIndex)

    d("[MyMapPos] zoneId = " .. tostring(zoneId))
end

------------------------------------------------------------
-- AddOn 初期化
------------------------------------------------------------
local function OnAddOnLoaded(event, addonName)
    if addonName ~= ADDON then return end

    d("[MyMapPos] Loaded. Use /mpos to print your map position.")
    d("[MyMapPos] Use /mpzone to print current map zoneId.")
end

EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, OnAddOnLoaded)