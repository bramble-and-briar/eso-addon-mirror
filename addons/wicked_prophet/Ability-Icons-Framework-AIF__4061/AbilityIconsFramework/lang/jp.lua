local strings = {
    -- Potion Names (Legacy & Standard)
    HP_POTION_NAME_3              = "英雄の一服",
    HP_POTION_NAME_10             = "英雄のチンキ",
    HP_POTION_NAME_20             = "英雄の小薬",
    HP_POTION_NAME_30             = "英雄の薬",
    HP_POTION_NAME_40             = "英雄の溶液",
    HP_POTION_NAME_CP10           = "英雄の霊薬",
    HP_POTION_NAME_CP50           = "英雄の万能薬",
    HP_POTION_NAME_CP100          = "英雄の蒸留液",
    HP_POTION_NAME_CP150          = "英雄のエキス",


    -- Settings Menu
    SI_AIF_PANEL_NAME             = "Ability Icons Framework",
    SI_AIF_PANEL_DESC             = "アビリティアイコンと戦闘UIをカスタマイズするためのフレームワーク。",
    SI_AIF_SETTINGS_HEADER        = "設定",
    SI_AIF_GLOBAL_SETTINGS        = "すべてのキャラクターで同じ設定を使用する",
    SI_AIF_SCRIBING_ICONS         = "カスタム書記アイコンを使用する",
    SI_AIF_BASE_GAME_ICONS        = "基本ゲームのアイコンを置き換える",
    SI_AIF_HEROISM_POTIONS        = "英雄の薬のアイコンを有効化",
    SI_AIF_RESOLUTION             = "基本ゲームアイコンの解像度",
    SI_AIF_RESOLUTION_TIP         = "デフォルトゲームアイコンに使用するテクスチャ解像度",
    SI_AIF_RESOLUTION_WARN        = "変更を適用するには /reloadui が必要です",
    SI_AIF_RELOAD_UI              = "UIを再読み込み",
    SI_AIF_PACK_ORDER_SUBMENU     = "アイコンパックの読み込み順",
    SI_AIF_PACK_PRIORITY          = "アイコンパックの優先度",

    -- Slash Commands & Chat
    SI_AIF_COMMANDS_HEADER        = "使用可能なコマンド:",
    SI_AIF_COMMAND_DETAILS        = "  /aif details <スロット 3-8> [裏バーは 1]",
    SI_AIF_COMMAND_ICONS          = "  /aif icons <スロット 3-8> [裏バーは 1]",
    SI_AIF_COMMAND_VARS           = "  /aif vars (保存された変数を確認)",
    SI_AIF_COMMAND_SETTINGS       = "  /aifgb (設定メニューを開く)",
    SI_AIF_SLOT_EMPTY             = "スロット <<1>> (バー <<2>>) は空です。",
    SI_AIF_SLOT_REDIRECT_NONE     = "  リダイレクト先: (なし)",
}

for stringId, stringValue in pairs(strings) do
    SafeAddString(_G[stringId], stringValue, 1)
end
