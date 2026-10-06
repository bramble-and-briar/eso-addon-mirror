--[[
    PvPTargetInfo.lua (2.0.0 完成版)

    これまでのv1.4.x系(イベント駆動+キャッシュ方式)を土台にせず、
    「現在ターゲット(reticleover)に実際に付いているBUFF/DEBUFFを
    GetNumBuffs+GetUnitBuffInfoで直接・定期的に読み取る」方式で
    ゼロから再構築した版。

    設計方針(重要):
    - EVENT_EFFECT_CHANGEDには依存しない。使っていない。
      ターゲット変更はEVENT_RETICLE_TARGET_CHANGEDで検知して即時スキャンし、
      ターゲット中は一定間隔(既定250ms、非戦闘中は間引いて実質2倍の間隔)の
      定期スキャンだけで表示を更新し続ける。取りこぼしが起きない構造。
    - 敵/味方の判定は IsUnitPlayer のみ。GetUnitReaction/AreUnitsCurrentlyAllied
      等の敵味方判定APIは一切使わない(過去バージョンで繰り返し誤判定を
      起こし、敵BUFF検知そのものを止めてしまった経緯があるため)。
    - 毎フレーム処理・高頻度スキャン・無限ループは行わない。
--]]

PvPTargetInfo = PvPTargetInfo or {}
local PTI = PvPTargetInfo
PTI.name = "PvPTargetInfo"
PTI.version = "2.0.1"

local SV_VERSION = 1

local defaults = {
    enabled = true,
    debug = false,
    previewMode = false,

    buffUI = {
        enabled = true,
        point = CENTER,
        relPoint = CENTER,
        x = -220,
        y = -140,
        iconSize = 20,
        maxRows = 6,
    },
    debuffUI = {
        enabled = true,
        point = CENTER,
        relPoint = CENTER,
        x = 220,
        y = -140,
        iconSize = 20,
        maxRows = 6,
    },

    -- 自動検知(Major/Minor/(強)/(弱)等のキーワードやCC種別)では拾えない
    -- 特定の敵BUFF/DEBUFFを追加したい場合の補助的な手動登録。
    -- カンマ区切りのAbilityId文字列(例: "12345, 67890")。/pti debug on で
    -- チャットにAbilityIdが出るので、追加したいものが見つかったら設定画面か
    -- このテキストに追記する。
    importantIdsText = "",
}

--------------------------------------------------------------------------
-- SavedVariables
--------------------------------------------------------------------------
local function InitializeSavedVariables()
    -- ZO_SavedVars:NewAccountWide は defaults に無いキーを安全に補完するため、
    -- SavedVariablesが存在しない/古い/一部欠損していても既定値で起動できる。
    PTI.sv = ZO_SavedVars:NewAccountWide("PvPTargetInfo_SavedVariables", SV_VERSION, nil, defaults)

    -- 想定外の型(過去の壊れたデータ等)が入っていた場合の最低限の防御。
    if type(PTI.sv.buffUI) ~= "table" then PTI.sv.buffUI = ZO_DeepTableCopy(defaults.buffUI) end
    if type(PTI.sv.debuffUI) ~= "table" then PTI.sv.debuffUI = ZO_DeepTableCopy(defaults.debuffUI) end
    if type(PTI.sv.importantIdsText) ~= "string" then PTI.sv.importantIdsText = "" end
end

--------------------------------------------------------------------------
-- スラッシュコマンド
--------------------------------------------------------------------------
local function PrintUsage()
    d("|c55CCFF[PvPTargetInfo]|r コマンド一覧:")
    d("  /pti on | off — アドオン全体の有効/無効")
    d("  /pti buff on|off — 敵BUFFパネルの表示/非表示")
    d("  /pti debuff on|off — 敵DEBUFFパネルの表示/非表示")
    d("  /pti pos buff|debuff <x> <y> — パネル位置を数値で指定")
    d("  /pti iconsize buff|debuff <8-64> — アイコンサイズ")
    d("  /pti maxrows buff|debuff <1-12> — 最大表示件数")
    d("  /pti preview on|off — 位置確認用のプレビュー表示")
    d("  /pti debug on|off — デバッグログ(通常は不要)")
    d("  /pti resetpos — パネル位置を初期値に戻す")
end

local function PanelFor(key)
    if key == "buff" then return PTI.sv.buffUI end
    if key == "debuff" then return PTI.sv.debuffUI end
    return nil
end

local function OnSlashCommand(args)
    args = args or ""
    local parts = {}
    for token in string.gmatch(args, "%S+") do
        table.insert(parts, token)
    end
    local cmd = parts[1] and parts[1]:lower() or ""

    if cmd == "on" then
        PTI.sv.enabled = true
        d("|c55CCFF[PvPTargetInfo]|r 有効にしました。")
    elseif cmd == "off" then
        PTI.sv.enabled = false
        d("|c55CCFF[PvPTargetInfo]|r 無効にしました。")
        if PTI.UI then PTI.UI.RefreshVisibility() end

    elseif cmd == "buff" or cmd == "debuff" then
        local panel = PanelFor(cmd)
        local sub = parts[2] and parts[2]:lower() or nil
        if sub == "on" then
            panel.enabled = true
        elseif sub == "off" then
            panel.enabled = false
        else
            d("|c55CCFF[PvPTargetInfo]|r 使い方: /pti " .. cmd .. " on|off")
            return
        end
        if PTI.UI then PTI.UI.RefreshVisibility() end

    elseif cmd == "pos" then
        local key = parts[2] and parts[2]:lower() or nil
        local panel = PanelFor(key or "")
        local x = tonumber(parts[3])
        local y = tonumber(parts[4])
        if not panel or not x or not y then
            d("|c55CCFF[PvPTargetInfo]|r 使い方: /pti pos buff|debuff <x> <y>")
            return
        end
        panel.x = x
        panel.y = y
        if PTI.UI then PTI.UI.ApplyPosition(key) end
        d(string.format("|c55CCFF[PvPTargetInfo]|r %sパネルの位置を (%d, %d) にしました。", key, x, y))

    elseif cmd == "iconsize" then
        local key = parts[2] and parts[2]:lower() or nil
        local panel = PanelFor(key or "")
        local size = tonumber(parts[3])
        if not panel or not size or size < 8 or size > 64 then
            d("|c55CCFF[PvPTargetInfo]|r 使い方: /pti iconsize buff|debuff <8-64>")
            return
        end
        panel.iconSize = zo_floor(size)
        if PTI.UI then PTI.UI.RefreshRowLayout(key) end
        d(string.format("|c55CCFF[PvPTargetInfo]|r %sのアイコンサイズを %d にしました。", key, panel.iconSize))

    elseif cmd == "maxrows" then
        local key = parts[2] and parts[2]:lower() or nil
        local panel = PanelFor(key or "")
        local n = tonumber(parts[3])
        if not panel or not n or n < 1 or n > 12 then
            d("|c55CCFF[PvPTargetInfo]|r 使い方: /pti maxrows buff|debuff <1-12>")
            return
        end
        panel.maxRows = zo_floor(n)
        d(string.format("|c55CCFF[PvPTargetInfo]|r %sの最大表示件数を %d にしました。", key, panel.maxRows))

    elseif cmd == "preview" then
        local sub = parts[2] and parts[2]:lower() or nil
        if sub == "on" then
            PTI.sv.previewMode = true
        elseif sub == "off" then
            PTI.sv.previewMode = false
        else
            d("|c55CCFF[PvPTargetInfo]|r 使い方: /pti preview on|off")
            return
        end
        if PTI.UI then PTI.UI.RefreshVisibility() end
        d("|c55CCFF[PvPTargetInfo]|r プレビュー表示: " .. (PTI.sv.previewMode and "ON" or "OFF"))

    elseif cmd == "debug" then
        local sub = parts[2] and parts[2]:lower() or nil
        if sub == "on" then
            PTI.sv.debug = true
        elseif sub == "off" then
            PTI.sv.debug = false
        else
            PTI.sv.debug = not PTI.sv.debug
        end
        d("|c55CCFF[PvPTargetInfo]|r デバッグログ: " .. (PTI.sv.debug and "ON" or "OFF"))

    elseif cmd == "resetpos" then
        PTI.sv.buffUI.point = defaults.buffUI.point
        PTI.sv.buffUI.relPoint = defaults.buffUI.relPoint
        PTI.sv.buffUI.x = defaults.buffUI.x
        PTI.sv.buffUI.y = defaults.buffUI.y
        PTI.sv.debuffUI.point = defaults.debuffUI.point
        PTI.sv.debuffUI.relPoint = defaults.debuffUI.relPoint
        PTI.sv.debuffUI.x = defaults.debuffUI.x
        PTI.sv.debuffUI.y = defaults.debuffUI.y
        if PTI.UI then PTI.UI.ApplyAllPositions() end
        d("|c55CCFF[PvPTargetInfo]|r パネル位置を初期値に戻しました。")

    else
        PrintUsage()
    end
end

--------------------------------------------------------------------------
-- 起動
--------------------------------------------------------------------------
local function OnAddOnLoaded(_, addonName)
    if addonName ~= PTI.name then return end
    EVENT_MANAGER:UnregisterForEvent(PTI.name, EVENT_ADD_ON_LOADED)

    InitializeSavedVariables()

    PTI.UI.Initialize()
    PTI.Target.Initialize()
    if PTI.Settings and PTI.Settings.Initialize then
        PTI.Settings.Initialize()
    end

    SLASH_COMMANDS["/pti"] = OnSlashCommand

    d("|c55CCFF[PvPTargetInfo]|r ロード完了 v" .. PTI.version .. "  (/pti でコマンド一覧)")
end
EVENT_MANAGER:RegisterForEvent(PTI.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
