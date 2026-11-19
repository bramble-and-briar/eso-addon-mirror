local strings = {
    [SI_ONEFRAME_DEBUG] = "Debug",
    [SI_ONEFRAME_DEBUG_OFF] = "無効",
    [SI_ONEFRAME_DEBUG_SMALL] = "小グループ",
    [SI_ONEFRAME_DEBUG_LARGE] = "大グループ",
    [SI_ONEFRAME_DISPLAY] = "表示",
    [SI_ONEFRAME_TANK_ROLE] = "タンク",
    [SI_ONEFRAME_HEALER_ROLE] = "ヒーラー",
    [SI_ONEFRAME_DAMAGE_ROLE] = "ダメージディーラー",
    [SI_ONEFRAME_SHOW_STATISTIC] = "表示する統計",
    [SI_ONEFRAME_NOTHING] = "なし",
    [SI_ONEFRAME_LEVEL_CP] = "レベル / チャンピオンポイント",
    [SI_ONEFRAME_GROUP_DPS] = "グループDPS",
    [SI_ONEFRAME_HEALTH_THOUSANDS] = "%.1fk",
    [SI_ONEFRAME_GENERAL] = "一般",
    [SI_ONEFRAME_SORT] = "グループをロール順に並べる",
    [SI_ONEFRAME_CLASS] = "クラスアイコンを表示",
    [SI_ONEFRAME_DPS_LABEL] = "DPS",
    [SI_ONEFRAME_HPS_LABEL] = "HPS",
    [SI_ONEFRAME_UNAVAILABLE] = "—",
    [SI_ONEFRAME_KILO] = "%.1fk",
    [SI_ONEFRAME_MILLION] = "%.2fm",
    [SI_ONEFRAME_SHIELD_COLOR] = "シールドの色",
    [SI_ONEFRAME_CONTEXT_MENU] = "右クリックメニュー",
    [SI_ONEFRAME_WHISPER] = "ささやく",
    [SI_ONEFRAME_TRAVEL] = "プレイヤーの所へ移動",
    [SI_ONEFRAME_REMOVE] = "グループから除外",
    [SI_ONEFRAME_UNSUPPORTED] = "OneFrame: このESOのUIバージョンは未検証のため、フレームの拡張機能は無効です。",
    [SI_ONEFRAME_MISSING] = "OneFrame: 標準フレームに対応できないため、拡張機能を適用できませんでした。",
}

for id, text in pairs(strings) do
    SafeAddString(id, text, 1)
end
