local RH = RestyleHelper
local L = RH.L

---------------------------------------------------------------------------
-- お気に入りスタイル
-- sv.favorites = { [collectibleId] = 登録時刻 }
---------------------------------------------------------------------------
function RH.IsFavorite(id)
    return id and RH.sv.favorites[id] ~= nil
end

function RH.ToggleFavorite(id)
    if not RH.IsStyleCollectible(id) then return end
    local name = RH.GetCollectibleDisplayName(id)
    if RH.IsFavorite(id) then
        RH.sv.favorites[id] = nil
        RH.Msg(L.MSG_FAV_REMOVED, name)
    else
        RH.sv.favorites[id] = GetTimeStamp()
        RH.Msg(L.MSG_FAV_ADDED, name)
    end
    if RH.RefreshFavoritesWindow then RH.RefreshFavoritesWindow() end
    RH.RefreshStylePanel()
end

-- 登録順(新しい順)のリスト
function RH.GetFavoriteList()
    local list = {}
    for id, t in pairs(RH.sv.favorites) do
        list[#list + 1] = { id = id, time = t }
    end
    table.sort(list, function(a, b)
        if a.time == b.time then return a.id < b.id end
        return a.time > b.time
    end)
    return list
end

function RH.HasFavorites()
    return next(RH.sv.favorites) ~= nil
end

-- お気に入りに含まれるスタイル(styleId)の集合
-- ランダム時は「お気に入りに登録したピースと同じスタイル」の他部位も候補にする
function RH.GetFavoriteStyleSet()
    local idx = RH.GetStyleIndex()
    local set = {}
    for id in pairs(RH.sv.favorites) do
        local info = idx.info[id]
        if info and info.styleId ~= 0 then set[info.styleId] = true end
    end
    return set
end

function RH.IsFavoriteMatch(id, styleSet)
    if RH.sv.favorites[id] then return true end
    local info = RH.GetStyleIndex().info[id]
    return info ~= nil and styleSet[info.styleId] == true
end

-- 説明文: 「胴体 / 重装」など
function RH.GetFavoriteDetail(id)
    local info = RH.GetStyleIndex().info[id]
    if not info then return "" end
    local parts = {}
    local slot = info.slots[1]
    if slot then parts[#parts + 1] = RH.GetSlotName(slot) end
    if info.armorType and info.armorType ~= 0 then
        local w = GetString("SI_VISUALARMORTYPE", info.armorType)
        if w and w ~= "" then parts[#parts + 1] = zo_strformat("<<1>>", w) end
    end
    return table.concat(parts, " / ")
end

-- お気に入りのピースを対応する部位に着せる
function RH.ApplyFavoriteToSlot(id)
    local om = RH.RequireManipulator()
    if not om then return end
    if not RH.IsUnlocked(id) then
        RH.Msg(L.MSG_FAV_LOCKED, RH.GetCollectibleDisplayName(id))
        return
    end
    local info = RH.GetStyleIndex().info[id]
    if not info then return end
    for _, slot in ipairs(info.slots) do
        local sm = RH.GetSlotManip(om, slot)
        if sm then
            RH.PushUndo(om)
            RH.SetSlotStyle(sm, id, RH.DEFAULT_MATERIAL)
            RH.Msg(L.MSG_FAV_APPLIED, RH.GetCollectibleDisplayName(id), RH.GetSlotName(slot))
            return
        end
    end
end

---------------------------------------------------------------------------
-- スタイル一覧への反映(星マーク / お気に入りのみ表示)
-- 着想: OutfitStylesFavorites (@timere-nemo) のような「星マーク + お気に入りのみ表示」。コードは独自実装。
---------------------------------------------------------------------------
local FAVORITE_ICON = "EsoUI/Art/Collections/Favorite_StarOnly.dds"

RH.showFavoritesOnly = false

-- グリッドを作り直して星マーク・フィルターを反映
function RH.RefreshStylePanel()
    local panel = ZO_OUTFIT_STYLES_PANEL_KEYBOARD
    if panel and panel.fragment and panel.fragment:IsShowing() then
        pcall(panel.RefreshVisible, panel, true)
    end
end

-- グリッド項目データからスタイルのコレクションIDを取る(空セル/「なし」項目は nil)
local function EntryStyleId(data)
    if type(data) ~= "table" or data.isEmptyCell or data.clearAction then return nil end
    if type(data.GetId) == "function" then
        local ok, id = pcall(data.GetId, data)
        if ok and type(id) == "number" then return id end
    end
    return data.collectibleId
end

-- 星マーク: セルのコントロールごとに1つだけ作り、更新のたびに表示/非表示を切り替える
local starByControl = setmetatable({}, { __mode = "k" })

local function StarFor(control)
    local star = starByControl[control]
    if star then return star end
    star = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
    star:SetDimensions(22, 22)
    star:SetTexture(FAVORITE_ICON)
    star:SetDrawLayer(DL_OVERLAY)
    star:SetMouseEnabled(false)
    star:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, -2, -2)
    star:SetHidden(true)
    starByControl[control] = star
    return star
end

local function InstallStar(panel)
    if type(panel.RefreshGridEntryMultiIcon) ~= "function" then return end
    ZO_PostHook(panel, "RefreshGridEntryMultiIcon", function(_, control, data)
        local id = EntryStyleId(data)
        StarFor(control):SetHidden(not (id and RH.IsFavorite(id)))
    end)
end

-- 「お気に入りのみ」: 一覧にエントリーを追加する時点で、お気に入り以外を除外する
local function InstallFilter(panel)
    local gridList = panel.gridListPanelList
    if not gridList or type(gridList.AddEntry) ~= "function" then return end
    ZO_PreHook(gridList, "AddEntry", function(_, data)
        if not RH.showFavoritesOnly then return false end
        local id = EntryStyleId(data)
        if not id then return false end                      -- 「なし」などの特殊項目は残す
        if RH.GetStyleSetIsHidden(id) then return false end   -- 「非表示」項目は常に表示
        return not RH.IsFavorite(id)                          -- お気に入り以外は追加しない(true で抑止)
    end)
end

-- 「お気に入りのみ」チェックボックス: 種類フィルター(右端)の左隣に置く
local function InstallCheckbox(panel)
    local typeFilter = panel.typeFilterControl
    if not (typeFilter and panel.control) then return end

    local text = RH.L.CHK_FAV_ONLY
    local box = WINDOW_MANAGER:CreateControlFromVirtual("RestyleHelper_ShowFavorites", panel.control, "ZO_CheckButton")
    ZO_CheckButton_SetLabelText(box, text)
    ZO_CheckButton_SetCheckState(box, false)
    ZO_CheckButton_SetToggleFunction(box, function(_, checked)
        RH.showFavoritesOnly = checked
        panel:RefreshVisible()
    end)

    -- ボタン(16px) + 余白 + 文字幅 の分だけ、種類フィルターから左へ離す
    local textWidth = 80
    pcall(function()
        textWidth = GetStringWidthScaled("ZoFontGameBold", text, 1, SPACE_INTERFACE)
    end)
    box:ClearAnchors()
    box:SetAnchor(RIGHT, typeFilter, LEFT, -(textWidth + 5 + 24), 0)
    RH.ui.favFilterCheck = box
end

function RH.InstallFavoritesUI()
    if RH.favUIInstalled then return end
    local panel = ZO_OUTFIT_STYLES_PANEL_KEYBOARD
    if not panel then return end
    RH.favUIInstalled = true
    for name, fn in pairs({ star = InstallStar, filter = InstallFilter, checkbox = InstallCheckbox }) do
        local ok, err = pcall(fn, panel)
        if not ok and RH.debug then RH.Msg("favorites ui (%s) error: %s", name, tostring(err)) end
    end
end

---------------------------------------------------------------------------
-- 診断: /rsh stats
---------------------------------------------------------------------------
function RH.PrintStats()
    local idx = RH.GetStyleIndex()
    local total, unlocked = 0, 0
    for id in pairs(idx.info) do
        total = total + 1
        if RH.IsUnlocked(id) then unlocked = total and (unlocked + 1) end
    end
    local styles, styleWithOwned = 0, 0
    local cover = { [7] = 0, [6] = 0, [5] = 0, [4] = 0, [3] = 0, [2] = 0, [1] = 0 }
    for styleId, bySlot in pairs(idx.byStyle) do
        styles = styles + 1
        local c = 0
        for _, slot in ipairs(RH.armorSlots) do
            for _, id in ipairs(bySlot[slot] or {}) do
                if RH.IsUnlocked(id) then c = c + 1 break end
            end
        end
        if c > 0 then
            styleWithOwned = styleWithOwned + 1
            cover[c] = (cover[c] or 0) + 1
        end
    end
    RH.Msg(L.STATS_LINE1, total, unlocked, idx.noStyle)
    RH.Msg(L.STATS_LINE2, styles, styleWithOwned)
    RH.Msg(L.STATS_LINE3, cover[7] or 0, cover[6] or 0, cover[5] or 0, cover[4] or 0, cover[3] or 0, cover[2] or 0, cover[1] or 0)
end
