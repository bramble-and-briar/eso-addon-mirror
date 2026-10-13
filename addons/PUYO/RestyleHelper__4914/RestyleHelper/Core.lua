RestyleHelper = RestyleHelper or {}
local RH = RestyleHelper
local L = RH.L

RH.name        = "RestyleHelper"
RH.version     = "1.13.2"
RH.LINK_TYPE   = "rsh"
RH.SHARE_TAG   = "RSH1"
RH.MAX_UNDO    = 10
RH.stationOpen = false

local defaults = {
    locks          = {},
    weaponStyle    = false,
    weaponDye      = false,
    unifyWeight    = false,
    lockDyes       = true,
    orderPerSlot   = false,
    hideMissing    = false,
    themeMinSlots  = 5,
    showPanel      = true,
    panelPos       = nil,
    sharePos       = nil,
    presets        = {},
    favorites      = {},
    favoritesOnly  = false,
    chatMessages   = false,
    shareMessages  = true,
    colorFamilies  = {},
    requiredDyes   = {},
    excludedDyes   = {},
    channelLocks   = {},
    favPos         = nil,
}

---------------------------------------------------------------------------
-- 汎用
---------------------------------------------------------------------------
function RH.Msg(fmt, ...)
    if RH.sv and not RH.sv.chatMessages and not RH.forceMsg then return end
    local text = (select("#", ...) > 0) and string.format(fmt, ...) or tostring(fmt)
    text = "|cC8A2C8[Restyle Helper]|r " .. text
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(text)
    else
        d(text)
    end
end

function RH.Pick(t)
    if not t or #t == 0 then return nil end
    return t[math.random(#t)]
end

-- obj のメソッドを候補名の順に探して呼ぶ（API差異の吸収用）
function RH.Call(obj, names, ...)
    if not obj then return false end
    for _, n in ipairs(names) do
        local f = obj[n]
        if type(f) == "function" then
            return true, f(obj, ...)
        end
    end
    return false
end

---------------------------------------------------------------------------
-- スロット定義
---------------------------------------------------------------------------
function RH.InitSlots()
    RH.armorSlots, RH.weaponSlots, RH.allSlots = {}, {}, {}
    RH.isArmor, RH.isValidSlot = {}, {}
    local armor = { OUTFIT_SLOT_HEAD, OUTFIT_SLOT_SHOULDERS, OUTFIT_SLOT_CHEST, OUTFIT_SLOT_HANDS,
                    OUTFIT_SLOT_WAIST, OUTFIT_SLOT_LEGS, OUTFIT_SLOT_FEET }
    for i = 1, 7 do
        local s = armor[i]
        if s ~= nil then
            table.insert(RH.armorSlots, s)
            RH.isArmor[s] = true
        end
    end
    local b = OUTFIT_SLOT_ITERATION_BEGIN or 0
    local e = OUTFIT_SLOT_ITERATION_END or OUTFIT_SLOT_MAX_VALUE or 20
    for s = b, e do
        table.insert(RH.allSlots, s)
        RH.isValidSlot[s] = true
        if not RH.isArmor[s] then table.insert(RH.weaponSlots, s) end
    end
end

function RH.GetSlotName(slot)
    local n = RH.SLOT_NAMES[slot]
    if n then return n end
    local s = GetString("SI_OUTFITSLOT", slot)
    if s and s ~= "" then return zo_strformat("<<1>>", s) end
    return "Slot " .. tostring(slot)
end

---------------------------------------------------------------------------
-- 編集中の衣装マニピュレーター取得
---------------------------------------------------------------------------
function RH.GetCurrentOutfitManipulator()
    local sw = ZO_RESTYLE_SHEET_WINDOW_KEYBOARD
    if sw then
        local sheet
        local ok, s = RH.Call(sw, { "GetCurrentSheet" })
        if ok then sheet = s end
        if sheet then
            local ok2, m = RH.Call(sheet, { "GetCurrentOutfitManipulator", "GetOutfitManipulator" })
            if ok2 and m then return m end
            if sheet.currentOutfitManipulator then return sheet.currentOutfitManipulator end
            -- 衣装以外（装備）シートが開かれている
            return nil
        end
    end
    -- フォールバック: 装備中の衣装
    if ZO_OUTFIT_MANAGER and GetEquippedOutfitIndex then
        local actor = GAMEPLAY_ACTOR_CATEGORY_PLAYER or 0
        local idx = GetEquippedOutfitIndex(actor)
        if idx then return ZO_OUTFIT_MANAGER:GetOutfitManipulator(actor, idx) end
    end
    return nil
end

function RH.RequireManipulator()
    local om = RH.GetCurrentOutfitManipulator()
    if not om then RH.Msg(L.MSG_NO_OUTFIT) end
    return om
end

function RH.GetSlotManip(om, slot)
    if not om then return nil end
    local ok, sm = RH.Call(om, { "GetSlotManipulator" }, slot)
    if ok then return sm end
    return nil
end

RH.DEFAULT_MATERIAL = ZO_OUTFIT_STYLE_DEFAULT_ITEM_MATERIAL_INDEX or 1

function RH.GetSlotState(sm)
    local _, id  = RH.Call(sm, { "GetPendingCollectibleId" })
    local _, mat = RH.Call(sm, { "GetPendingItemMaterialIndex" })
    local _, p, s, a = RH.Call(sm, { "GetPendingDyeData", "GetPendingDyeIds" })
    -- mat はそのまま保持する(空スロットのゲーム側の値は nil。1に変えると「変更あり」扱いになり費用が壊れる)
    return { id = id or 0, mat = mat, p = p or 0, s = s or 0, a = a or 0 }
end

---------------------------------------------------------------------------
-- 保留データの書き込み
--
-- 公式の SetPendingCollectibleIdAndItemMaterialIndex などは内部でプレビュー更新用の
-- private 関数 (AddOutfitSlotPreviewElementToPreviewCollection) を呼ぶため、
-- アドオンから呼ぶと「Attempt to access a private function」エラーになる。
-- そこで保留データだけを直接書き込み、プレビュー更新はゲーム側の関数に任せる。
---------------------------------------------------------------------------
local function GetRestyleSlotData(sm)
    if sm.restyleSlotData then return sm.restyleSlotData end
    local ok, rsd = RH.Call(sm, { "GetRestyleSlotData" })
    return ok and rsd or nil
end

local pendingCommit = {}
local commitScheduled = false

local function ScheduleCommit(om)
    if not om then return end
    pendingCommit[om] = true
    if commitScheduled then return end
    commitScheduled = true
    zo_callLater(function()
        commitScheduled = false
        for o in pairs(pendingCommit) do
            pendingCommit[o] = nil
            -- 服飾台の表示(スロットアイコン・染料・費用)を更新
            if type(o.OnSlotPendingDataChanged) == "function" then
                pcall(o.OnSlotPendingDataChanged, o, nil)
            end
            RH.RefreshPreview(o)
        end
    end, 0)
end

-- キャラクタープレビューの更新:
-- プレビュー更新は private 関数を使うため、アドオンから直接は呼べない。
-- ゲーム自身の OnUpdate に実行させる KickPreview を使う(下記)。
-- ※ スロット一覧へのマウスオーバー時にプレビューを再読み込みさせる方式は廃止した。
function RH.RefreshPreview(om)
    RH.KickPreview(om)
end

-- 自動プレビュー更新:
-- 服飾台のシートウィンドウはゲーム自身の OnUpdate で毎フレーム
--   if self.isPreviewAvailable ~= IsCharacterPreviewingAvailable() then
--       self.modeSelectorDropdown:SetEnabled(...)
-- を実行している。isPreviewAvailable をわざと反転させ、modeSelectorDropdown を
-- 「SetEnabled = 公式の UpdatePreviews」を持つ代理オブジェクトに一瞬だけ差し替えることで、
-- 次のフレームにゲーム側の処理として全身のプレビュー更新を実行させる。
-- 実行を確認したら(または1秒経ったら)すぐ元のドロップダウンに戻す。
function RH.KickPreview(om)
    local sw = ZO_RESTYLE_SHEET_WINDOW_KEYBOARD
    local fn = ZO_OutfitManipulator and ZO_OutfitManipulator.UpdatePreviews
    if not (sw and fn and om and om.outfitSlotManipulators) then return end
    if RH.previewKickActive then return end
    local real = sw.modeSelectorDropdown
    if not real or type(sw.OnUpdate) ~= "function" or not IsCharacterPreviewingAvailable then return end

    local proxy = setmetatable({ outfitSlotManipulators = om.outfitSlotManipulators, SetEnabled = fn },
                               { __index = real })
    RH.previewKickActive = true
    sw.modeSelectorDropdown = proxy
    sw.isPreviewAvailable = not IsCharacterPreviewingAvailable()

    local started = GetFrameTimeMilliseconds()
    local updateName = RH.name .. "_PreviewKick"
    EVENT_MANAGER:RegisterForUpdate(updateName, 0, function()
        local done = (sw.isPreviewAvailable == IsCharacterPreviewingAvailable())
        if done or GetFrameTimeMilliseconds() - started > 1000 then
            EVENT_MANAGER:UnregisterForUpdate(updateName)
            if sw.modeSelectorDropdown == proxy then sw.modeSelectorDropdown = real end
            RH.previewKickActive = false
            if not done and not RH.previewHintShown then
                -- 自動更新が効かなかった場合だけ、手動での反映方法を案内
                RH.previewHintShown = true
                RH.Msg(RH.L.MSG_PREVIEW_HINT)
            end
        end
    end)
end

local function IsBlocked(sm, collectibleId)
    if not collectibleId or collectibleId == 0 or not ZO_COLLECTIBLE_DATA_MANAGER then return false end
    local data = ZO_COLLECTIBLE_DATA_MANAGER:GetCollectibleDataById(collectibleId)
    local owner = sm.owner
    if data and data.IsBlocked and owner and owner.GetActorCategory then
        return data:IsBlocked(owner:GetActorCategory())
    end
    return false
end

function RH.SetSlotStyle(sm, collectibleId, mat)
    collectibleId = collectibleId or 0
    -- スタイルなし(0)のときの素材は nil(ゲームの Clear と同じ)。0以外は未指定なら既定値
    if collectibleId == 0 then mat = nil else mat = mat or RH.DEFAULT_MATERIAL end
    if IsBlocked(sm, collectibleId) then return false end
    if sm.pendingCollectibleId == collectibleId and sm.pendingItemMaterialIndex == mat then return true end
    sm.pendingCollectibleId = collectibleId
    sm.pendingItemMaterialIndex = mat
    -- 新しいスタイルで染色できないチャンネルの染料を元に戻す（公式と同じ処理）
    local rsd = GetRestyleSlotData(sm)
    if rsd and rsd.CleanPendingDyes then pcall(rsd.CleanPendingDyes, rsd) end
    ScheduleCommit(sm.owner)
    return true
end

-- そのスロットで染色できるチャンネル {メイン, サブ, アクセント}
function RH.GetDyeable(sm)
    local rsd = GetRestyleSlotData(sm)
    if rsd then
        local ok, d1, d2, d3 = pcall(rsd.AreDyeChannelsDyeable, rsd)
        if ok then
            local t = { d1 and true or false, d2 and true or false, d3 and true or false }
            for i = 1, 3 do
                if RH.IsChannelLocked(rsd.restyleMode, rsd.restyleSlotType, i) then t[i] = false end
            end
            return t
        end
    end
    return { true, true, true }
end

function RH.SetSlotDyes(sm, p, s, a)
    local rsd = GetRestyleSlotData(sm)
    if not rsd then return false end
    local desired = { p or 0, s or 0, a or 0 }
    local okD, d1, d2, d3 = pcall(rsd.AreDyeChannelsDyeable, rsd)
    local okC, c1, c2, c3 = pcall(rsd.GetCurrentDyes, rsd)
    if okD and okC then
        local dyeable, current = { d1, d2, d3 }, { c1, c2, c3 }
        for i = 1, 3 do
            if not dyeable[i] then desired[i] = current[i] end
        end
    end
    -- 染料枠ロック中のチャンネルは今の保留値を維持
    local okP, q1, q2, q3 = pcall(rsd.GetPendingDyes, rsd)
    if okP then
        local pend = { q1, q2, q3 }
        for i = 1, 3 do
            if RH.IsChannelLocked(rsd.restyleMode, rsd.restyleSlotType, i) then desired[i] = pend[i] end
        end
    end
    local ok = pcall(SetPendingSlotDyes, rsd.restyleMode, rsd.restyleSetIndex, rsd.restyleSlotType,
                     desired[1], desired[2], desired[3])
    ScheduleCommit(sm.owner)
    return ok
end

---------------------------------------------------------------------------
-- スタイル適用状況(カバー状況)
-- states[slot] = "ok"(適用) / "sub"(重さ違いで代用) / "missing"(揃わない) / "hidden"(非表示にした) / nil(対象外)
---------------------------------------------------------------------------
function RH.SetCoverage(styleName, states)
    RH.coverage = { name = styleName, states = states }
    if RH.RefreshCoverage then RH.RefreshCoverage() end
end

-- 揃わなかった部位の処理: オプションがオンなら非表示用スタイルを設定
-- 戻り値: "hidden" または "missing"
function RH.HandleMissingSlot(sm, slot)
    if RH.sv.hideMissing then
        local hid = RH.GetHiddenStyleId(slot)
        if hid and RH.SetSlotStyle(sm, hid, RH.DEFAULT_MATERIAL) then return "hidden" end
    end
    return "missing"
end

---------------------------------------------------------------------------
-- 元に戻す
---------------------------------------------------------------------------
RH.undoStack = {}

function RH.PushUndo(om)
    local snap = { om = om, slots = {} }
    for _, slot in ipairs(RH.allSlots) do
        local sm = RH.GetSlotManip(om, slot)
        if sm then snap.slots[slot] = RH.GetSlotState(sm) end
    end
    table.insert(RH.undoStack, snap)
    while #RH.undoStack > RH.MAX_UNDO do table.remove(RH.undoStack, 1) end
end

function RH.Undo()
    local snap = table.remove(RH.undoStack)
    if not snap then RH.Msg(L.MSG_UNDO_EMPTY) return end
    for slot, st in pairs(snap.slots) do
        local sm = RH.GetSlotManip(snap.om, slot)
        if sm then
            RH.SetSlotStyle(sm, st.id, st.mat)
            RH.SetSlotDyes(sm, st.p, st.s, st.a)
        end
    end
    RH.Msg(L.MSG_UNDO_DONE)
end

---------------------------------------------------------------------------
-- スタイル索引  styleId(GetOutfitStyleItemStyleId) × スロット → コレクションID
---------------------------------------------------------------------------
-- スロットごとの「非表示用スタイル」(目に斜線のアイコン)。ランダムや一括適用の候補からは除外し、
-- 「揃わない部位を非表示にする」オプションでだけ使う。
function RH.GetHiddenStyleId(slot)
    if not GetOutfitSlotDataHiddenOutfitStyleCollectibleId then return nil end
    local ok, id = pcall(GetOutfitSlotDataHiddenOutfitStyleCollectibleId, slot)
    if ok and type(id) == "number" and id > 0 then return id end
    return nil
end

function RH.GetHiddenStyleSet()
    if RH.hiddenSet then return RH.hiddenSet end
    local set = {}
    for _, slot in ipairs(RH.allSlots) do
        local id = RH.GetHiddenStyleId(slot)
        if id then set[id] = true end
    end
    RH.hiddenSet = set
    return set
end

function RH.GetStyleSetIsHidden(id)
    return RH.GetHiddenStyleSet()[id] == true
end

function RH.GetStyleIndex()
    if RH.styleIndex then return RH.styleIndex end
    local idx = { bySlot = {}, byStyle = {}, info = {}, noStyle = 0 }
    local hiddenSet = RH.GetHiddenStyleSet()
    local catType = COLLECTIBLE_CATEGORY_TYPE_OUTFIT_STYLE
    local n = (GetTotalCollectiblesByCategoryType and GetTotalCollectiblesByCategoryType(catType)) or 0
    for i = 1, n do
        local id = GetCollectibleIdFromType(catType, i)
        if id and id > 0 and not hiddenSet[id] then
            -- 公式 (ZO_CollectibleData) と同じく、コレクションIDではなく「参照ID」で問い合わせる
            local refId     = GetCollectibleReferenceId and GetCollectibleReferenceId(id) or id
            local styleId   = GetOutfitStyleItemStyleId and GetOutfitStyleItemStyleId(refId) or 0
            local armorType = GetOutfitStyleVisualArmorType and GetOutfitStyleVisualArmorType(refId) or 0
            local slots = { GetEligibleOutfitSlotsForCollectible(id) }
            if not styleId or styleId == 0 then idx.noStyle = idx.noStyle + 1 end
            idx.info[id] = { styleId = styleId or 0, armorType = armorType or 0, slots = slots }
            for _, s in ipairs(slots) do
                idx.bySlot[s] = idx.bySlot[s] or {}
                table.insert(idx.bySlot[s], id)
                if styleId and styleId ~= 0 then
                    local bs = idx.byStyle[styleId]
                    if not bs then bs = {}; idx.byStyle[styleId] = bs end
                    bs[s] = bs[s] or {}
                    table.insert(bs[s], id)
                end
            end
        end
    end
    RH.GroupUnclassified(idx)
    RH.styleIndex = idx
    return idx
end

-- 文字(UTF-8)単位の配列
local function Chars(str)
    local t = {}
    for c in string.gmatch(str or "", "[%z\1-\127\194-\244][\128-\191]*") do t[#t + 1] = c end
    return t
end

local function CommonPrefixLen(a, b)
    local n = 0
    for i = 1, math.min(#a, #b) do
        if a[i] ~= b[i] then break end
        n = n + 1
    end
    return n
end

local function CommonSuffixLen(a, b)
    local n = 0
    for i = 1, math.min(#a, #b) do
        if a[#a - i + 1] ~= b[#b - i + 1] then break end
        n = n + 1
    end
    return n
end

-- アイテムスタイルIDを持たないスタイル(DLC等の大半)を、
-- 「ID連番 + 名前の共通部分」でセットにまとめる。
-- 仮のスタイルID(負の数)を割り当て、byStyle に登録する。
-- 診断: 分類できないスタイルの先頭付近を SavedVariables に書き出す(/rsh dump)
function RH.DumpUnclassified()
    local out = {}
    local idx = RH.GetStyleIndex()
    local ids = {}
    for id in pairs(idx.info) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local info = idx.info[id]
        if info.styleId < 0 and RH.IsUnlocked(id) then
            out[#out + 1] = string.format("%d|%s|%s|slots=%s|at=%s|grp=%d", id,
                tostring(GetCollectibleName(id)), tostring(GetCollectibleIcon and GetCollectibleIcon(id)),
                table.concat(info.slots, ","), tostring(info.armorType), info.styleId)
            if #out >= 120 then break end
        end
    end
    RH.sv.dump = out
    RH.forceMsg = true
    RH.Msg("診断データを保存しました(%d件)。/reloadui 後に SavedVariables\\RestyleHelper.lua を送ってください", #out)
    RH.forceMsg = false
end

RH.fallbackNames = {}
local WEIGHT_TOKENS = { light = true, medium = true, heavy = true }
local PIECE_TOKENS = {
    head = true, chest = true, robe = true, shoulders = true, hands = true, waist = true, legs = true, feet = true,
    shield = true, staff = true, bow = true, dagger = true, mace = true, sword = true, axe = true, hammer = true,
    ["1hsword"] = true, ["2hsword"] = true, ["1haxe"] = true, ["2haxe"] = true, ["1hhammer"] = true, ["2hhammer"] = true,
    ["1hmace"] = true, ["2hmace"] = true, frost = true, fire = true, lightning = true, restoration = true,
}

-- アイコン名からセットのキーを作る(重さ・部位の語を除く)
-- 例: gear_breton_light_robe_a -> gear_breton_a / gear_breton_heavy_head_a -> gear_breton_a
local function IconSetKey(id)
    local icon = GetCollectibleIcon and GetCollectibleIcon(id)
    if type(icon) ~= "string" or icon == "" then return nil end
    local base = string.match(icon, "([^/\\]*)$") or ""
    base = string.lower(string.gsub(base, "%.dds$", ""))
    local kept, removed = {}, false
    for tok in string.gmatch(base, "[^_]+") do
        if WEIGHT_TOKENS[tok] or PIECE_TOKENS[tok] then
            removed = true
        else
            kept[#kept + 1] = tok
        end
    end
    if not removed or #kept == 0 then return nil end
    return table.concat(kept, "_")
end

function RH.GroupUnclassified(idx)
    RH.fallbackNames = {}
    -- 1) アイコン名によるセット判定
    local byKey, rest = {}, {}
    for id, info in pairs(idx.info) do
        if info.styleId == 0 and #info.slots > 0 then
            local key = IconSetKey(id)
            if key then
                byKey[key] = byKey[key] or {}
                table.insert(byKey[key], id)
            end
        end
    end
    for _, members in pairs(byKey) do
        table.sort(members)
        local sid = -members[1]
        local chars1 = Chars(GetCollectibleName(members[1]) or "")
        local p = #chars1
        for _, id in ipairs(members) do
            p = math.min(p, CommonPrefixLen(chars1, Chars(GetCollectibleName(id) or "")))
        end
        local name = (p >= 2) and table.concat(chars1, "", 1, p) or (GetCollectibleName(members[1]) or "")
        name = string.gsub(name, "[%s%-・の]+$", "")
        local num = string.match(GetCollectibleName(members[1]) or "", "(%d+)$")
        if num then name = name .. " " .. num end
        RH.fallbackNames[sid] = name
        for _, id in ipairs(members) do
            local info = idx.info[id]
            info.styleId = sid
            for _, sl in ipairs(info.slots) do
                local bs = idx.byStyle[sid]
                if not bs then bs = {}; idx.byStyle[sid] = bs end
                bs[sl] = bs[sl] or {}
                table.insert(bs[sl], id)
            end
        end
    end
    -- 2) 残りは ID連番 + 名前の共通部分で推定
    local ids = {}
    for id, info in pairs(idx.info) do
        if info.styleId == 0 and #info.slots > 0 then ids[#ids + 1] = id end
    end
    table.sort(ids)
    local group
    local function Flush()
        if not group then return end
        local sid = -group.first
        local name = group.name
        name = string.gsub(name, "[%s%-・の]+$", "")
        RH.fallbackNames[sid] = name
        for _, id in ipairs(group.members) do
            local info = idx.info[id]
            info.styleId = sid
            for _, s in ipairs(info.slots) do
                local bs = idx.byStyle[sid]
                if not bs then bs = {}; idx.byStyle[sid] = bs end
                bs[s] = bs[s] or {}
                table.insert(bs[s], id)
            end
        end
        group = nil
    end
    for _, id in ipairs(ids) do
        local info = idx.info[id]
        local nm = Chars(GetCollectibleName(id) or "")
        local join = false
        if group and id - group.last <= 3 then
            local p = CommonPrefixLen(group.chars, nm)
            local q = CommonSuffixLen(group.chars, nm)
            local gap = id - group.last
            local icon = GetCollectibleIcon and GetCollectibleIcon(id) or ""
            local base = string.match(icon or "", "([^/\\]*)$") or ""
            local gbase = group.iconBase or ""
            local ip = 0
            for i = 1, math.min(#base, #gbase) do
                if string.sub(base, i, i) ~= string.sub(gbase, i, i) then break end
                ip = i
            end
            local clash = false
            for _, s in ipairs(info.slots) do
                local key = s .. ":" .. (info.armorType or 0)
                if group.used[key] then clash = true break end
            end
            if not clash and (p >= 2 or ip >= 6 or (gap <= 1 and p >= 1)) then join = true end
        end
        if not join then
            Flush()
            group = { first = id, last = id, chars = nm, members = {}, used = {}, name = "",
                      iconBase = string.match((GetCollectibleIcon and GetCollectibleIcon(id)) or "", "([^/\\]*)$") }
        end
        group.members[#group.members + 1] = id
        group.last = id
        for _, s in ipairs(info.slots) do group.used[s .. ":" .. (info.armorType or 0)] = true end
        -- セット名: 先頭ピースとの共通プレフィックス(無ければ先頭ピース名)
        if #group.members == 1 then
            group.name = GetCollectibleName(id) or ""
        else
            local p = CommonPrefixLen(group.chars, nm)
            if p >= 2 then
                group.name = table.concat(group.chars, "", 1, p)
            end
        end
    end
    Flush()
end

function RH.IsUnlocked(id)
    return id and id > 0 and IsCollectibleUnlocked(id)
end

function RH.IsStyleCollectible(id)
    return type(id) == "number" and id > 0
        and GetCollectibleCategoryType(id) == COLLECTIBLE_CATEGORY_TYPE_OUTFIT_STYLE
end

function RH.GetCollectibleDisplayName(id)
    if not id or id == 0 then return L.STYLE_NONE end
    local name = GetCollectibleName(id)
    if not name or name == "" then return L.UNKNOWN end
    return zo_strformat(SI_COLLECTIBLE_NAME_FORMATTER or "<<1>>", name)
end

function RH.GetStyleName(styleId)
    if styleId and styleId < 0 then
        local n = RH.fallbackNames[styleId]
        return (n and n ~= "") and zo_strformat("<<1>>", n) or L.UNKNOWN
    end
    if styleId and styleId ~= 0 and GetItemStyleName then
        local n = GetItemStyleName(styleId)
        if n and n ~= "" then return zo_strformat("<<1>>", n) end
    end
    return L.UNKNOWN
end

-- 同じ styleId から slot 用の解放済みピースを探す
-- 戻り値: collectibleId, 重さ違いで代用したか
function RH.FindInStyle(styleId, slot, preferArmorType, preferId)
    local idx = RH.GetStyleIndex()
    local bs = idx.byStyle[styleId]
    local list = bs and bs[slot]
    if not list then return nil end
    if preferId then
        for _, id in ipairs(list) do
            if id == preferId and RH.IsUnlocked(id) then return id, false end
        end
    end
    local fallback
    for _, id in ipairs(list) do
        if RH.IsUnlocked(id) then
            local at = idx.info[id].armorType
            if not RH.isArmor[slot] or not preferArmorType or preferArmorType == 0 or at == preferArmorType then
                return id, false
            end
            fallback = fallback or id
        end
    end
    if fallback then return fallback, true end
    return nil
end

---------------------------------------------------------------------------
-- 染料
---------------------------------------------------------------------------
RH.dyeInfo = {}   -- dyeId -> { name, r, g, b, family, order }

-- RGB(0-1) から色の系統を判定する
RH.FAMILIES = { "red", "orange", "yellow", "green", "blue", "purple", "pink", "brown", "black", "white", "grey" }
function RH.DyeFamily(r, g, b)
    r, g, b = r or 0, g or 0, b or 0
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    local d = mx - mn
    local v = mx
    local s = (mx > 0) and (d / mx) or 0
    if v < 0.2 then return "black" end
    if s < 0.16 then
        if v > 0.82 then return "white" end
        return "grey"
    end
    local h
    if d == 0 then h = 0
    elseif mx == r then h = 60 * (((g - b) / d) % 6)
    elseif mx == g then h = 60 * ((b - r) / d + 2)
    else h = 60 * ((r - g) / d + 4) end
    if h < 0 then h = h + 360 end
    if h >= 8 and h < 50 and v < 0.55 then return "brown" end
    if h < 15 or h >= 345 then return "red" end
    if h < 42 then return "orange" end
    if h < 70 then return "yellow" end
    if h < 170 then return "green" end
    if h < 255 then return "blue" end
    if h < 295 then return "purple" end
    return "pink"
end

function RH.GetKnownDyes()
    local list, known = {}, {}
    for i = 1, GetNumDyes() do
        local name, isKnown, _, _, _, r, g, b, _, dyeId = GetDyeInfo(i)
        if dyeId and dyeId ~= 0 then
            RH.dyeInfo[dyeId] = { name = name, r = r, g = g, b = b, family = RH.DyeFamily(r, g, b), order = i }
        end
        if isKnown and dyeId and dyeId ~= 0 then
            list[#list + 1] = dyeId
            known[dyeId] = true
        end
    end
    return list, known
end

-- ランダム用の染料プール(系統の指定を反映)と、必ず使う染料(解放済みのみ)
function RH.GetPoolDyes()
    local list, known = RH.GetKnownDyes()
    local sv = RH.sv
    local fams = sv.colorFamilies or {}
    local any = next(fams) ~= nil
    local excl = sv.excludedDyes or {}
    local pool, inPool = {}, {}
    for _, id in ipairs(list) do
        local info = RH.dyeInfo[id]
        if (not any or (info and fams[info.family])) and not excl[id] then
            pool[#pool + 1] = id
            inPool[id] = true
        end
    end
    local required = {}
    for id in pairs(sv.requiredDyes or {}) do
        if known[id] then
            required[#required + 1] = id
            if not inPool[id] then pool[#pool + 1] = id end
        end
    end
    table.sort(required)
    if #pool == 0 then -- 指定系統に使える染料が無い時は、除外色だけを避けた全染料
        for _, id in ipairs(list) do if not excl[id] then pool[#pool + 1] = id end end
    end
    if #pool == 0 then pool = list end
    return pool, required
end

-- 染料枠ロック(部位ごとのメイン/サブ/アクセントのうち1か所だけ固定)
local function LockKey(mode, slotType, ch) return tostring(mode) .. ":" .. tostring(slotType) .. ":" .. ch end
function RH.IsChannelLocked(mode, slotType, ch)
    local t = RH.sv and RH.sv.channelLocks
    return t ~= nil and t[LockKey(mode, slotType, ch)] == true
end
function RH.SetChannelLocked(mode, slotType, ch, v)
    RH.sv.channelLocks = RH.sv.channelLocks or {}
    RH.sv.channelLocks[LockKey(mode, slotType, ch)] = v and true or nil
end

function RH.GetDyeName(dyeId)
    if not dyeId or dyeId == 0 then return "-" end
    if GetDyeInfoById then
        local name = GetDyeInfoById(dyeId)
        if name and name ~= "" then return zo_strformat("<<1>>", name) end
    end
    return tostring(dyeId)
end

---------------------------------------------------------------------------
-- 初期化
---------------------------------------------------------------------------
-- 設定の保存: サーバー(NA / EU / PTS)ごとに分ける(profile = サーバー名)。
-- 旧版(サーバーを区別しない "Default" 領域)のデータは、各サーバーで最初に読み込むときに1回だけコピーして引き継ぐ。
local function DeepCopy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = DeepCopy(x) end
    return t
end

function RH.LoadSavedVars()
    local world = GetWorldName and GetWorldName() or ""
    if world == "" then world = "Default" end
    local root = RestyleHelperSV
    if type(root) == "table" and world ~= "Default" then
        local account = GetDisplayName()
        local old = root["Default"] and root["Default"][account] and root["Default"][account]["$AccountWide"]
        local newAccount = root[world] and root[world][account]
        if old and not (newAccount and newAccount["$AccountWide"]) then
            root[world] = root[world] or {}
            root[world][account] = root[world][account] or {}
            root[world][account]["$AccountWide"] = DeepCopy(old)
        end
    end
    return ZO_SavedVars:NewAccountWide("RestyleHelperSV", 1, nil, defaults, world)
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= RH.name then return end
    EVENT_MANAGER:UnregisterForEvent(RH.name, EVENT_ADD_ON_LOADED)

    RH.InitSlots()
    RH.sv = RH.LoadSavedVars()
    -- 旧設定(武器もランダム対象)からの引き継ぎ
    if RH.sv.includeWeapons ~= nil then
        if RH.sv.includeWeapons then RH.sv.weaponStyle = true; RH.sv.weaponDye = true end
        RH.sv.includeWeapons = nil
    end

    -- 旧設定(全部位そろうものだけ)からの引き継ぎ
    if RH.sv.themeCompleteOnly ~= nil then
        if RH.sv.themeCompleteOnly then RH.sv.themeMinSlots = 7 end
        RH.sv.themeCompleteOnly = nil
    end
    do
        local n = tonumber(RH.sv.themeMinSlots) or 5
        RH.sv.themeMinSlots = math.max(1, math.min(7, math.floor(n)))
    end

    math.randomseed(GetTimeStamp() + GetGameTimeMilliseconds())

    RH.InitShare()
    RH.InitUI()

    EVENT_MANAGER:RegisterForEvent(RH.name, EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(RH.name, EVENT_PLAYER_ACTIVATED)
        RH.InstallStyleMenuHooks()
        if RH.InstallChannelLockUI then RH.InstallChannelLockUI() end
        -- 同じアドオンの別フォルダ(コピー等)が有効だと古いコードが動いてしまうので警告
        local am = GetAddOnManager and GetAddOnManager()
        if am then
            for i = 1, am:GetNumAddOns() do
                local name, title, _, _, enabled = am:GetAddOnInfo(i)
                if enabled and name ~= RH.name and type(title) == "string" and title:find("Restyle Helper", 1, true) then
                    RH.Msg(L.MSG_DUPLICATE, name)
                end
            end
        end
    end)

    -- 服飾台のシーンの表示/非表示に合わせてパネルを出し入れ(離れたら必ず消す)
    local function HookScene()
        local scene = ZO_RESTYLE_SCENE or (SCENE_MANAGER and SCENE_MANAGER:GetScene("restyle_station_keyboard"))
        if not scene or not scene.RegisterCallback then return false end
        scene:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_SHOWN or newState == SCENE_SHOWING then
                RH.stationOpen = true
                if RH.SetChannelHintShown then RH.SetChannelHintShown(true) end
                if RH.sv.showPanel then RH.ShowPanel(true) end
            elseif newState == SCENE_HIDING or newState == SCENE_HIDDEN then
                RH.stationOpen = false
                if RH.SetChannelHintShown then RH.SetChannelHintShown(false) end
                RH.ShowPanel(false)
                RH.ShowShareWindow(false)
                RH.ShowFavoritesWindow(false)
                RH.ShowColorsWindow(false)
            end
        end)
        return true
    end
    if not HookScene() then zo_callLater(HookScene, 1000) end

    EVENT_MANAGER:RegisterForEvent(RH.name, EVENT_DYEING_STATION_INTERACT_START, function()
        RH.stationOpen = true
        RH.undoStack = {}
        if RH.sv.showPanel then RH.ShowPanel(true) end
    end)
    EVENT_MANAGER:RegisterForEvent(RH.name, EVENT_DYEING_STATION_INTERACT_END, function()
        RH.stationOpen = false
        if RH.SetChannelHintShown then RH.SetChannelHintShown(false) end
        RH.undoStack = {}
        RH.ShowPanel(false)
        RH.ShowShareWindow(false)
        RH.ShowFavoritesWindow(false)
        RH.ShowColorsWindow(false)
    end)
    -- コレクション解放でスタイル索引を作り直す
    EVENT_MANAGER:RegisterForEvent(RH.name, EVENT_COLLECTIBLE_NOTIFICATION_NEW, function() RH.styleIndex = nil end)

    SLASH_COMMANDS["/rsh"] = function(arg)
        local raw = zo_strtrim(arg or "")
        arg = zo_strlower(raw)
        -- /rsh save 名前  … 現在の服飾をプリセット保存(日本語名はチャット欄から入力できます)
        local saveName = string.match(raw, "^[Ss][Aa][Vv][Ee]%s*(.*)$")
        if saveName then
            local entries = RH.CaptureCurrent()
            if entries then
                RH.SavePreset(saveName, RH.EncodeEntries(entries))
                RH.forceMsg = true
                RH.Msg(L.MSG_PRESET_SAVED2, RH.SanitizeName(saveName) ~= "" and RH.SanitizeName(saveName) or L.AUTO_NAME)
                RH.forceMsg = false
                if RH.RefreshPresetList then RH.RefreshPresetList() end
            end
            return
        end
        if arg == "" then
            RH.TogglePanel()
        elseif arg == "share" then
            RH.ShowShareWindow(true)
        elseif arg == "random" or arg == "all" then
            RH.Randomize("all")
        elseif arg == "style" or arg == "dye" or arg == "theme" then
            RH.Randomize(arg)
        elseif arg == "dump" then
            RH.DumpUnclassified()
        elseif arg == "chat" then
            RH.sv.chatMessages = not RH.sv.chatMessages
            RH.forceMsg = true
            RH.Msg(RH.sv.chatMessages and L.MSG_CHAT_ON or L.MSG_CHAT_OFF)
            RH.forceMsg = false
        elseif arg == "stats" then
            RH.forceMsg = true; RH.PrintStats(); RH.forceMsg = false
        elseif false then
            RH.PrintStats()
        elseif arg == "fav" then
            RH.ShowFavoritesWindow(true)
        elseif arg == "chaos" then
            RH.Randomize("chaos")
        elseif arg == "order" then
            RH.ShuffleDyeOrder()
        elseif arg == "undo" then
            RH.Undo()
        else
            RH.Msg(L.MSG_HELP)
        end
    end
end

EVENT_MANAGER:RegisterForEvent(RH.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
