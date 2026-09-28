-- GankTracker v0.1.0 (Phase 1: PS5/CS 座標取得の検証のみ)
-- ピン表示・追従・設定画面は未実装(Phase 1の結果次第で追加)
-- 処理はターゲット変更イベントのみ。OnUpdate・常時ループなし。

local ADDON_NAME = "GankTracker"

-- 追跡対象名(キャラ名 or @表示名)。空欄 = テストモード(自分以外の任意のプレイヤーで検証)
local TARGET_NAME = ""

-- 出力の最小間隔(ms)。ターゲットを連続で切り替えてもチャットが溢れないようにする
local MIN_INTERVAL_MS = 1500
local lastPrintMs = 0

local function Say(text)
    local msg = "[GT] " .. text
    if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage(msg)
    else
        d(msg)
    end
end

local function Norm(s)
    if not s or s == "" then return "" end
    local t = zo_strlower(zo_strformat("<<1>>", s))
    t = t:gsub("^@", "")
    return t
end

local function S(v)
    if v == nil then return "nil" end
    return tostring(v)
end

local function OnReticleTargetChanged()
    if not DoesUnitExist("reticleover") then return end
    if not IsUnitPlayer("reticleover") then return end -- NPC・モンスター除外
    if AreUnitsEqual("reticleover", "player") then return end

    local rawName = GetUnitName("reticleover")
    local rawDisp = GetUnitDisplayName("reticleover")
    local name = Norm(rawName)
    local disp = Norm(rawDisp)
    local want = Norm(TARGET_NAME)

    if want ~= "" and name ~= want and disp ~= want then return end

    local now = GetGameTimeMilliseconds()
    if now - lastPrintMs < MIN_INTERVAL_MS then return end
    lastPrintMs = now

    -- 1) 識別情報(生値をそのまま表示)
    local _, reaction = pcall(GetUnitReaction, "reticleover")
    local _, alliance = pcall(GetUnitAlliance, "reticleover")
    Say(string.format("target=%s / %s reaction=%s alliance=%s",
        S(rawName), S(rawDisp), S(reaction), S(alliance)))

    -- 2) ワールド座標(reticleover / player)
    local okT, zoneT, xT, yT, zT = pcall(GetUnitWorldPosition, "reticleover")
    local okP, zoneP, xP, yP, zP = pcall(GetUnitWorldPosition, "player")

    -- 3) 正規化マップ座標(ピン化の材料)
    local okMT, nxT, nyT = pcall(GetMapPlayerPosition, "reticleover")
    local okMP, nxP, nyP = pcall(GetMapPlayerPosition, "player")

    local verdict = "COORD NG"
    local distStr = "-"
    if okT and xT and zT and (xT ~= 0 or zT ~= 0) then
        verdict = "COORD OK"
        if okP and xP and zP then
            local dx, dz = xT - xP, zT - zP
            local dist = math.sqrt(dx * dx + dz * dz) / 100 -- cm -> m
            distStr = string.format("%.1fm", dist)
            if dist < 0.01 then verdict = "COORD SAME AS PLAYER?" end
        end
    end

    Say(string.format("%s world: ok=%s zone=%s x=%s z=%s dist=%s",
        verdict, S(okT), S(zoneT), S(xT), S(zT), distStr))
    Say(string.format("map: tgt ok=%s %s,%s / self ok=%s %s,%s",
        S(okMT), S(nxT), S(nyT), S(okMP), S(nxP), S(nyP)))
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_Load", EVENT_ADD_ON_LOADED)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_RETICLE_TARGET_CHANGED, OnReticleTargetChanged)
    -- 起動メッセージはログイン完了後に1回だけ出す(読み込み直後はチャット未準備のため)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Active", EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_Active", EVENT_PLAYER_ACTIVATED)
        Say("loaded - Phase 1 (coordinate test)")
    end)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Load", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
