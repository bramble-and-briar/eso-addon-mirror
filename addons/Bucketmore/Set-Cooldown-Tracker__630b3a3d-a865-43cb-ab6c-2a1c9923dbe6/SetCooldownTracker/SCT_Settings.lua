-- SetCooldownTracker v1.0.0 : 設定画面(LibAddonMenu-2.0 がある場合のみ。無ければ既定値で動作)
SetCooldownTracker = SetCooldownTracker or {}
local SCT = SetCooldownTracker

function SCT:InitSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end
    local db, def = self.db, self.defaults

    local function slider(name, key, min, max, step, tooltip, after)
        return {
            type = "slider", name = name, tooltip = tooltip,
            min = min, max = max, step = step,
            getFunc = function() return db[key] end,
            setFunc = function(v) db[key] = v; if after then after() else SCT:ApplyLayout() end end,
            default = def[key],
        }
    end
    local function check(name, key, tooltip, after)
        return {
            type = "checkbox", name = name, tooltip = tooltip,
            getFunc = function() return db[key] end,
            setFunc = function(v) db[key] = v; if after then after() else SCT:Rescan() end end,
            default = def[key],
        }
    end

    LAM:RegisterAddonPanel("SetCooldownTrackerPanel", {
        type = "panel", name = "SetCooldownTracker", displayName = "SetCooldownTracker",
        author = "SetCooldownTracker", version = SCT.version, registerForDefaults = true,
    })
    LAM:RegisterOptionControls("SetCooldownTrackerPanel", {
        { type = "header", name = "基本" },
        {
            type = "checkbox", name = "パネルを有効にする",
            tooltip = "OFFにすると全てのイベント登録とタイマーを停止します。",
            getFunc = function() return db.enabled end,
            setFunc = function(v) SCT:SetEnabled(v) end,
            default = def.enabled,
        },
        {
            type = "button", name = "表示位置の確認(15秒間サンプル表示)",
            func = function() SCT:ShowDemo() end,
        },
        check("READY表示", "showReady", "CD終了後・未発動のセットにREADYを表示します。"),
        slider("READY表示時間(秒)", "readySeconds", 0, 30, 1,
            "CD終了後にREADYを表示する秒数。0は装備中ずっと表示します。", function() SCT:Refresh() end),
        check("ICD不明セットの経過時間表示", "showUnknown",
            "内部CDが不明なセットを推測せず『ICD ?』と最後の発動からの経過時間で表示します。", function() SCT:Refresh() end),
        check("ツールチップ記載のCDを補助利用(*付き)", "useTooltipICD",
            "DBにCDが無い場合のみ、セット説明文中のCD表記を解析して使います。日本語表記の解析は実機未確認です。"),
        check("死亡時にCDをリセット", "resetOnDeath", "実機未確認の挙動です。ゲーム仕様と異なる場合はOFFにしてください。", function() end),
        check("ゾーン移動時にCDをリセット", "resetOnZone", "実機未確認の挙動です。", function() end),

        { type = "header", name = "パネル表示" },
        check("タイトル(SET COOLDOWN)を表示", "showTitle", nil, function() SCT:ApplyLayout() end),
        slider("位置 X(%)", "posX", 0, 100, 1, "画面左端0%〜右端100%"),
        slider("位置 Y(%)", "posY", 0, 100, 1, "画面上端0%〜下端100%"),
        slider("パネル幅", "width", 160, 520, 10),
        slider("パネル拡大率(%)", "scale", 50, 200, 5),
        slider("文字サイズ", "fontSize", 14, 40, 1),
        slider("背景の濃さ(%)", "bgAlpha", 0, 100, 5, "0で完全透明"),
    })
end
