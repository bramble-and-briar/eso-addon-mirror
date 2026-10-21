RestyleHelper = RestyleHelper or {}
local RH = RestyleHelper
local L = RH.L

RH.name        = "RestyleHelper"
RH.version     = "1.2"
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
    previewUnownedStyles = false,
    previewUnownedDyes   = false,
    keepDyes       = true,
    preferRobe     = false,
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
                RH.internalCommit = true
                pcall(o.OnSlotPendingDataChanged, o, nil)
                RH.internalCommit = false
            end
            RH.RefreshPreview(o)
            if RH.UpdateUnownedWarning then RH.UpdateUnownedWarning(o) end
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
    -- スタイル変更直後はゲームが別の色を持ち込むことがあるため、しばらく染色を監視する
    if RH.NoteSlot then RH.NoteSlot(sm, true) end
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
    local intent = { p or 0, s or 0, a or 0 }
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
    -- 染色できない枠に指定された色も「意図した色」として記憶する(後で染色できるスタイルに変えたとき使う)
    if RH.NoteSlot then RH.NoteSlot(sm, false, intent) end
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

-- 重さの正規化: 軽/中/重(1/2/3)以外の値(ローブなど)は軽装として扱う。0は重さ不明
function RH.NormWeight(at)
    if not at or at == 0 then return 0 end
    if at == (VISUAL_ARMORTYPE_MEDIUM or 2) then return 2 end
    if at == (VISUAL_ARMORTYPE_HEAVY or 3) then return 3 end
    return 1
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
            idx.info[id] = { styleId = styleId or 0, armorType = armorType or 0, weight = RH.NormWeight(armorType), rawStyleId = styleId or 0, slots = slots }
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
local WEIGHT_TOKENS = { light = true, medium = true, heavy = true, lgt = true, med = true, hvy = true, lite = true }
local PIECE_TOKENS = {
    head = true, chest = true, robe = true, shoulders = true, hands = true, waist = true, legs = true, feet = true,
    shield = true, staff = true, bow = true, dagger = true, mace = true, sword = true, axe = true, hammer = true,
    ["1hsword"] = true, ["2hsword"] = true, ["1haxe"] = true, ["2haxe"] = true, ["1hhammer"] = true, ["2hhammer"] = true,
    ["1hmace"] = true, ["2hmace"] = true, frost = true, fire = true, lightning = true, restoration = true,
    shoulder = true, hand = true, leg = true, foot = true, helm = true, helmet = true, hat = true,
    belt = true, sash = true, boots = true, boot = true, gloves = true, glove = true, jerkin = true, shirt = true,
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
        local bare = string.gsub(tok, "%d+$", "")   -- chest1 -> chest
        if WEIGHT_TOKENS[tok] or PIECE_TOKENS[tok] or WEIGHT_TOKENS[bare] or PIECE_TOKENS[bare] then
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
    RH.MergeSplitGroups(idx)
end

-- 3) 仕上げ: アイコン名などの揺れでセットが割れた場合の救済。
-- 隣り合う(ID差3以内)仮グループで、名前が前方一致(短い方が4文字以上)し、
-- 同じ部位×重さのピースがぶつからないものを1つのセットに統合する。
function RH.MergeSplitGroups(idx)
    local groups = {}
    for id, info in pairs(idx.info) do
        local sid = info.styleId
        if sid and sid < 0 then
            local g = groups[sid]
            if not g then g = { sid = sid, members = {}, first = id, last = id, used = {} }; groups[sid] = g end
            g.members[#g.members + 1] = id
            if id < g.first then g.first = id end
            if id > g.last then g.last = id end
            for _, sl in ipairs(info.slots) do g.used[sl .. ":" .. (info.armorType or 0)] = true end
        end
    end
    local list = {}
    for _, g in pairs(groups) do list[#list + 1] = g end
    table.sort(list, function(x, y) return x.first < y.first end)
    local function NameOf(g) return RH.fallbackNames[g.sid] or "" end
    local function Prefixed(a, b)
        local ca, cb = Chars(a), Chars(b)
        local short = math.min(#ca, #cb)
        return short >= 4 and CommonPrefixLen(ca, cb) == short
    end
    -- グループ名だけでなく、先頭ピースの名前・アイコン名の共通部分でも「同じセット」と判定する
    local function MemberName(g)
        local f = g.first
        return (GetCollectibleName and GetCollectibleName(f)) or ""
    end
    local function IconBase(g)
        local icon = GetCollectibleIcon and GetCollectibleIcon(g.first) or ""
        return string.lower(string.match(icon or "", "([^/\\]*)$") or "")
    end
    local function Related(a, b)
        if Prefixed(NameOf(a), NameOf(b)) then return true, "name" end
        local ca, cb = Chars(MemberName(a)), Chars(MemberName(b))
        if CommonPrefixLen(ca, cb) >= 4 then return true, "piece" end
        local ia, ib = IconBase(a), IconBase(b)
        local ip = 0
        for i = 1, math.min(#ia, #ib) do
            if string.sub(ia, i, i) ~= string.sub(ib, i, i) then break end
            ip = i
        end
        if ip >= 10 then return true, "icon" end
        return false, "none"
    end
    RH.mergeLog = {}
    local function Clashes(a, b)
        for key in pairs(b.used) do if a.used[key] then return key end end
        return nil
    end
    local function MergeInto(cur, g)
        for _, id in ipairs(g.members) do
            local info = idx.info[id]
            info.styleId = cur.sid
            for _, sl in ipairs(info.slots) do
                local bs = idx.byStyle[cur.sid]
                bs[sl] = bs[sl] or {}
                table.insert(bs[sl], id)
            end
            cur.members[#cur.members + 1] = id
        end
        for key in pairs(g.used) do cur.used[key] = true end
        cur.last = math.max(cur.last, g.last)
        cur.first = math.min(cur.first, g.first)
        if #Chars(NameOf(g)) < #Chars(NameOf(cur)) then RH.fallbackNames[cur.sid] = NameOf(g) end
        idx.byStyle[g.sid] = nil
        RH.fallbackNames[g.sid] = nil
        g.dead = true
    end
    local cur
    for _, g in ipairs(list) do
        local related, why
        if cur then related, why = Related(cur, g) end
        if cur then
            local clashKey = Clashes(cur, g)
            RH.mergeLog[#RH.mergeLog + 1] = string.format("merge? %d <- %d gap=%d related=%s(%s) clash=%s",
                cur.sid, g.sid, g.first - cur.last, tostring(related), why or "-", tostring(clashKey))
        end
        if cur and g.first - cur.last <= 3 and related then
            if not Clashes(cur, g) then
                MergeInto(cur, g)
            else
                cur = g
            end
        else
            cur = g
        end
    end

    -- 2周目: ID距離に関係なく、ピース名の共通部分(セット名)で統合する。
    -- 別時期に追加された同じセットの部位(ピットデイモン等)が別グループになるのを防ぐ。
    local function IsDigit(c) return #c == 1 and c >= "0" and c <= "9" end
    local function IsTrim(c) return c == " " or c == "\227\128\128" or c == "\227\129\174" end -- 空白/全角空白/の
    local alive = {}
    for _, g in ipairs(list) do
        if not g.dead then
            local names, common = {}, nil
            local digs = {}
            for _, id in ipairs(g.members) do
                local nm = (GetCollectibleName and GetCollectibleName(id)) or ""
                local ch = Chars(nm)
                names[#names + 1] = nm
                local k = #ch
                while k > 0 and IsDigit(ch[k]) do k = k - 1 end
                digs[#digs + 1] = table.concat(ch, "", k + 1, #ch)
                if not common then common = ch
                else
                    local p = CommonPrefixLen(common, ch)
                    local nc = {}
                    for i = 1, p do nc[i] = common[i] end
                    common = nc
                end
            end
            common = common or {}
            local e = #common
            while e > 0 and (IsDigit(common[e]) or IsTrim(common[e])) do e = e - 1 end
            table.sort(digs)
            local uniq, prev = {}, nil
            for _, d in ipairs(digs) do if d ~= prev then uniq[#uniq + 1] = d; prev = d end end
            g.nkey = table.concat(common, "", 1, e)
            g.nlen = e
            g.dkey = table.concat(uniq, ",")
            g.single = (#g.members == 1)
            g.full = names[1] or ""
            g.fullChars = Chars(g.full)
            alive[#alive + 1] = g
        end
    end
    local byKey = {}
    for _, g in ipairs(alive) do
        if g.nlen >= 3 then
            local k = g.dkey .. "|" .. g.nkey
            byKey[k] = byKey[k] or {}
            table.insert(byKey[k], g)
        end
    end
    local function Absorb(a, b, why)
        if a == b or a.dead or b.dead then return end
        local ck = Clashes(a, b)
        RH.mergeLog[#RH.mergeLog + 1] = string.format("name-merge %d <- %d key=%s/%s why=%s clash=%s",
            a.sid, b.sid, a.nkey, b.nkey, why, tostring(ck))
        if ck then return end
        if b.first < a.first then a, b = b, a end
        MergeInto(a, b)
    end
    -- (a) 同じ名前キー同士
    for _, bucket in pairs(byKey) do
        for i = 1, #bucket do
            for j = i + 1, #bucket do
                if not bucket[i].dead and not bucket[j].dead then Absorb(bucket[i], bucket[j], "same") end
            end
        end
    end
    -- (b) 1ピースだけのグループ: フルネームがほかのセット名キーで始まる(4文字以上)
    for _, g in ipairs(alive) do
        if g.single and not g.dead then
            local fc = g.fullChars
            for n = #fc, 4, -1 do
                local k = g.dkey .. "|" .. table.concat(fc, "", 1, n)
                local bucket = byKey[k]
                if bucket then
                    for _, o in ipairs(bucket) do
                        if o ~= g and not o.dead and not o.single then
                            Absorb(o, g, "prefix")
                            break
                        end
                    end
                end
                if g.dead then break end
            end
        end
    end
end

function RH.IsUnlocked(id)
    return id and id > 0 and IsCollectibleUnlocked(id)
end

-- ランダム/一括適用/プリセットで使ってよいスタイルか。
-- 通常は所持品のみ。テスト用オプション(previewUnownedStyles)がオンなら未所持もプレビューに使う
-- (未所持が含まれる間は、ゲーム側の仕様で服飾台の「適用」はできない)
function RH.IsUsable(id)
    if not (id and id > 0) then return false end
    if IsCollectibleUnlocked(id) then return true end
    return RH.sv ~= nil and RH.sv.previewUnownedStyles == true
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
-- そのスタイルの、この部位に「重さ違いのピース」があるか(重さが1種類しか無いスタイルは false)
function RH.SlotHasWeightVariants(styleId, slot)
    local idx = RH.GetStyleIndex()
    local bs = idx.byStyle[styleId]
    local list = bs and bs[slot]
    if not list then return false end
    local first
    for _, id in ipairs(list) do
        local at = idx.info[id].weight
        if first == nil then first = at elseif at ~= first then return true end
    end
    return false
end

-- ローブか(ジャーキンと区別する)。アイコン名の "robe" またはスタイル名の「ローブ/Robe」で判定
local robeCache = {}
function RH.IsRobe(id)
    local c = robeCache[id]
    if c ~= nil then return c end
    local r = false
    local icon = GetCollectibleIcon and GetCollectibleIcon(id)
    if type(icon) == "string" then
        local base = string.lower(string.match(icon, "([^/\\]*)$") or "")
        for tok in string.gmatch(string.gsub(base, "%.dds$", ""), "[^_]+") do
            if string.gsub(tok, "%d+$", "") == "robe" then r = true end
        end
    end
    if not r then
        local n = GetCollectibleName and GetCollectibleName(id)
        if type(n) == "string" and (string.find(n, "ローブ", 1, true) or string.find(string.lower(n), "robe", 1, true)) then r = true end
    end
    robeCache[id] = r
    return r
end

function RH.FindInStyle(styleId, slot, preferArmorType, preferId)
    local idx = RH.GetStyleIndex()
    local bs = idx.byStyle[styleId]
    local list = bs and bs[slot]
    if not list then return nil end
    preferArmorType = preferArmorType and RH.NormWeight(preferArmorType) or nil
    -- ジャーキンとローブの両方があるスタイルでは、オプションでローブを優先する
    if slot == OUTFIT_SLOT_CHEST and RH.sv and RH.sv.preferRobe then
        local robes, others = {}, {}
        for _, id in ipairs(list) do
            if RH.IsRobe(id) then robes[#robes + 1] = id else others[#others + 1] = id end
        end
        if #robes > 0 and #others > 0 then
            list = {}
            for _, id in ipairs(robes) do list[#list + 1] = id end
            for _, id in ipairs(others) do list[#list + 1] = id end
            if preferId and not RH.IsRobe(preferId) then preferId = nil end
        end
    end
    if preferId then
        for _, id in ipairs(list) do
            if id == preferId and RH.IsUsable(id) then return id, false end
        end
    end
    -- 重さ違いが存在しない部位は、重さを気にせず(代用扱いにせず)そのまま使う
    local variants = RH.SlotHasWeightVariants(styleId, slot)
    -- 重さが取得できないピース(armorType=0)は、どの重さにも使えるものとして扱う(優先は重さが一致するピース)
    local fallback, anyWeight
    for _, id in ipairs(list) do
        if RH.IsUsable(id) then
            local at = idx.info[id].weight
            if not RH.isArmor[slot] or not preferArmorType or preferArmorType == 0 or at == preferArmorType or not variants then
                return id, false
            end
            if (at or 0) == 0 then anyWeight = anyWeight or id end
            fallback = fallback or id
        end
    end
    if anyWeight then return anyWeight, false end
    if fallback and RH.trace then
        -- 重さ違いで代用した理由の診断(/rsh trace がオンのとき)
        local parts = {}
        for _, id in ipairs(list) do
            parts[#parts + 1] = string.format("%d(at=%s,usable=%s)", id, tostring(idx.info[id].armorType), tostring(RH.IsUsable(id)))
        end
        RH.forceMsg = true
        RH.Msg("[trace weight] style=%s(%s) slot=%s want=%s variants=%s candidates: %s", tostring(styleId), RH.GetStyleName(styleId), tostring(slot),
            tostring(preferArmorType), tostring(variants), table.concat(parts, " "))
        RH.forceMsg = false
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

RH.dyeOwned = {}  -- 実際に所持している染料

function RH.GetKnownDyes()
    local list, known = {}, {}
    local includeUnowned = RH.sv ~= nil and RH.sv.previewUnownedDyes == true
    RH.dyeOwned = {}
    for i = 1, GetNumDyes() do
        local name, isKnown, _, _, _, r, g, b, _, dyeId = GetDyeInfo(i)
        if dyeId and dyeId ~= 0 then
            RH.dyeInfo[dyeId] = { name = name, r = r, g = g, b = b, family = RH.DyeFamily(r, g, b), order = i }
            if isKnown then RH.dyeOwned[dyeId] = true end
        end
        if (isKnown or includeUnowned) and dyeId and dyeId ~= 0 then
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

---------------------------------------------------------------------------
-- 染色の維持: 服飾台でスタイルを変えたとき、ゲームが「そのスタイルに以前登録されていた色」を
-- 持ち込んで今の配色が混ざるのを防ぎ、変更前の染色を上書きして戻す。
-- アドオン自身の変更(ランダム等)は対象外。スナップショットは保留データが変わるたびに更新する。
---------------------------------------------------------------------------
RH.dyeSnap = {}
RH.RESTORE_DELAY_MS = 100   -- スタイル変更から、色を戻す(1回だけ)までの時間。継続的な監視はしない

local function SameDyes(snap, st)
    return snap.p == st.p and snap.s == st.s and snap.a == st.a
end

-- アドオン自身の変更は「正」として即座に記録する(ガードが巻き戻さないように)
-- 染色できるチャンネル(チャンネルロックは含めない、スタイル自体の可否)
local function RawDyeable(sm)
    local rsd = GetRestyleSlotData(sm)
    if rsd and rsd.AreDyeChannelsDyeable then
        local ok, d1, d2, d3 = pcall(rsd.AreDyeChannelsDyeable, rsd)
        if ok then return { d1 and true or false, d2 and true or false, d3 and true or false } end
    end
    return { true, true, true }
end

-- 部位ごとの「意図した染色」を記憶する。
-- ・染色できないチャンネル(スタイルが対応していない枠)は、ゲームが保存済みの色に戻してしまうので
--   その値は記憶に取り込まない(別のスタイルで再び染色できるようになったとき、記憶した色に戻すため)
-- ・スタイルが変わって新しく染色可能になった枠も、ゲームが持ち込んだ古い色なので取り込まない
local function Record(slot, sm, st, h, frozen, intent)
    local prev = RH.dyeSnap[slot]
    local d = RawDyeable(sm)
    local mem = { st.p, st.s, st.a }
    if not prev then
        -- 初回の記録: 染色できない枠の値はゲームが部位に保存していた(見えない)古い色なので取り込まない。
        -- 無染色(0)にしておき、染色できるスタイルに変わったとき近い枠の色で埋める。
        for i = 1, 3 do
            if not d[i] then mem[i] = 0 end
        end
    end
    if prev then
        local pm = { prev.p, prev.s, prev.a }
        for i = 1, 3 do
            if frozen or not (d[i] and prev.d and prev.d[i]) then mem[i] = pm[i] end
        end
    end
    if intent and not frozen then
        for i = 1, 3 do
            if not d[i] then mem[i] = intent[i] end
        end
    end
    h = h or {}
    RH.dyeSnap[slot] = { id = st.id, p = mem[1], s = mem[2], a = mem[3], d = d,
                         holdFrom = h.from, refresh = h.refresh }
end

-- 復元する色。記憶色が無染色(抜け)の枠は、その部位の近い枠の記憶色で埋める
local function Target(d, mem)
    local t = { mem[1], mem[2], mem[3] }
    for i = 1, 3 do
        if d[i] and t[i] == 0 then
            -- 抜けている枠: 色変更したと仮定して、その部位の近い枠の色を使う(手前の枠を優先)
            local pick
            for j = i - 1, 1, -1 do if mem[j] ~= 0 then pick = mem[j] break end end
            if not pick then
                for j = i + 1, 3 do if mem[j] ~= 0 then pick = mem[j] break end end
            end
            if pick then t[i] = pick end
        end
    end
    return t
end

-- 保留データが「本適用済みの状態」(ゲーム標準の「元に戻す」直後)かどうか
local function IsAtCurrent(sm, st)
    if sm.currentCollectibleId ~= st.id then return false end
    local rsd = GetRestyleSlotData(sm)
    if not (rsd and rsd.GetCurrentDyes) then return false end
    local ok, c1, c2, c3 = pcall(rsd.GetCurrentDyes, rsd)
    return ok and c1 == st.p and c2 == st.s and c3 == st.a
end

local function Now()
    return GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
end

-- アドオン自身の変更は「正」として記録する
-- 色を戻す予約時刻に、1回だけ確認を行う(定期的な監視はしない)
local restoreCheckPending = false
function RH.ScheduleRestoreCheck()
    if restoreCheckPending or not zo_callLater then return end
    restoreCheckPending = true
    zo_callLater(function()
        restoreCheckPending = false
        if not RH.stationOpen then return end
        local ok, err = pcall(function() RH.OnPendingChanged(RH.GetCurrentOutfitManipulator(), nil) end)
        if not ok and RH.debug then RH.Msg("dye guard error: %s", tostring(err)) end
    end, RH.RESTORE_DELAY_MS + 20)
end

function RH.NoteSlot(sm, startHold, intent)
    local slot = sm and sm.outfitSlotIndex
    if slot == nil then return end
    local st = RH.GetSlotState(sm)
    local prev = RH.dyeSnap[slot]
    local h = { from = prev and prev.holdFrom, refresh = prev and prev.refresh }
    if startHold then
        h = { from = Now() + RH.RESTORE_DELAY_MS, refresh = h.refresh }
        RH.ScheduleRestoreCheck()
    end
    Record(slot, sm, st, h, false, intent)
end

-- 保留中の変更が1つも無い(=本適用済みの状態)か。ゲーム標準の「元に戻す」直後はこうなる。
-- ゲーム側の判定(IsAnyChangePending)を優先し、無い/使えない場合は全部位が現在の状態と一致するかで判断する。
local function IsPristine(om)
    local fn = om.IsAnyChangePending
    if type(fn) == "function" then
        local ok, r = pcall(fn, om)
        if ok and r == false then return true end
    end
    local any = false
    for _, slot in ipairs(RH.allSlots) do
        local sm = RH.GetSlotManip(om, slot)
        local st = sm and RH.GetSlotState(sm)
        if st then
            any = true
            if not IsAtCurrent(sm, st) then return false end
        end
    end
    return any
end

-- 保留データを全部位チェック。スタイルが変わったら、RESTORE_DELAY_MS 後に1回だけ、
-- 染色できる枠の色が記憶と違っていれば、ゲームが持ち込んだ色とみなして記憶した染色に戻す。
-- (継続的な監視はしない。その後の色の変更はあなたの操作として記憶する)
-- 本適用済みの状態に戻された場合(ゲーム標準の「元に戻す」)は、上書きせず記憶を捨てる。
function RH.OnPendingChanged(om, slotIndex)
    if RH.dyeGuardBusy or not RH.stationOpen or not om then return end
    local keep = RH.sv and RH.sv.keepDyes ~= false
    local now = Now()
    if next(RH.dyeSnap) ~= nil and IsPristine(om) then
        -- 本適用済みの状態に戻った: 記憶を捨てて、ゲームが戻した色をそのまま使う
        if RH.trace then RH.forceMsg = true; RH.Msg("[trace] reverted to applied state: dye memory cleared"); RH.forceMsg = false end
        RH.dyeSnap = {}
    end
    for _, slot in ipairs(RH.allSlots) do
        if slotIndex == nil or slotIndex == slot then
            local sm = RH.GetSlotManip(om, slot)
            local st = sm and RH.GetSlotState(sm)
            if st then
                local snap = RH.dyeSnap[slot]
                local h = snap and { from = snap.holdFrom, refresh = snap.refresh } or {}
                if snap and RH.trace and (snap.id ~= st.id or snap.p ~= st.p or snap.s ~= st.s or snap.a ~= st.a) then
                    RH.forceMsg = true
                    RH.Msg("[trace %s] slot %s id %s->%s dyes mem %s/%s/%s -> now %s/%s/%s waiting=%s keep=%s",
                        tostring(RH.traceSrc or "poll"), tostring(slot), tostring(snap.id), tostring(st.id),
                        tostring(snap.p), tostring(snap.s), tostring(snap.a), tostring(st.p), tostring(st.s), tostring(st.a),
                        tostring(h.from ~= nil), tostring(keep))
                    RH.forceMsg = false
                end
                local reset = false
                if snap and snap.id ~= st.id and IsAtCurrent(sm, st) then
                    reset = true
                    RH.dyeSnap[slot] = nil
                    Record(slot, sm, st, nil)
                end
                if not reset then
                    -- ゲーム側でスタイルが変わった: 上書きの予約(再度変わったら予約し直し)
                    if keep and snap and st.id ~= 0 and snap.id ~= st.id then
                        h = { from = now + RH.RESTORE_DELAY_MS, refresh = h.refresh }
                        RH.ScheduleRestoreCheck()
                    end
                    local restore, target = false, nil
                    if h.from and now >= h.from then
                        if keep and snap and st.id ~= 0 then
                            local d = RawDyeable(sm)
                            local cur = { st.p, st.s, st.a }
                            target = Target(d, { snap.p, snap.s, snap.a })
                            local known = target[1] ~= 0 or target[2] ~= 0 or target[3] ~= 0
                            for i = 1, 3 do
                                if known and d[i] and cur[i] ~= target[i] then restore = true end
                            end
                            h = { from = nil, refresh = true }     -- 1回実行したら終了。最後にプレビューを更新
                        else
                            h = { from = nil, refresh = h.refresh }
                        end
                    end
                    if restore then
                        RH.dyeGuardBusy = true
                        pcall(RH.SetSlotDyes, sm, target[1], target[2], target[3])
                        RH.dyeGuardBusy = false
                        RH.dyeSnap[slot] = { id = st.id, p = snap.p, s = snap.s, a = snap.a, d = RawDyeable(sm),
                                             holdFrom = nil, refresh = true }
                    else
                        if h.refresh and not h.from then
                            h.refresh = false
                            ScheduleCommit(om)
                        end
                        -- 予約中(待機中)はゲームが書いた色かもしれないので、記憶は更新しない
                        Record(slot, sm, st, h, h.from ~= nil)
                    end
                end
            end
        end
    end
end

-- ゲーム側の経路(クリック等)でも確実に拾うため、通知フックに加えて定期チェックも行う
function RH.InstallDyeGuard()
    if RH.dyeGuardInstalled then return true end
    RH.dyeGuardInstalled = true
    local cls = ZO_OutfitManipulator
    if cls and type(cls.OnSlotPendingDataChanged) == "function" and ZO_PostHook then
        ZO_PostHook(cls, "OnSlotPendingDataChanged", function(om, slotIndex)
            RH.hookCount = (RH.hookCount or 0) + 1
            RH.traceSrc = "hook"
            local ok, err = pcall(RH.OnPendingChanged, om, slotIndex)
            RH.traceSrc = nil
            if not ok and RH.debug then RH.Msg("dye guard error: %s", tostring(err)) end
        end)
    end
    return true
end

function RH.SnapshotDyes()
    RH.dyeSnap = {}
    local om = RH.GetCurrentOutfitManipulator()
    if not om then return end
    RH.OnPendingChanged(om, nil)
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
                zo_callLater(RH.SnapshotDyes, 500)
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
    if not RH.InstallDyeGuard() then zo_callLater(RH.InstallDyeGuard, 3000) end

    EVENT_MANAGER:RegisterForEvent(RH.name, EVENT_DYEING_STATION_INTERACT_START, function()
        RH.stationOpen = true
        zo_callLater(RH.SnapshotDyes, 800)
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
        elseif arg == "dumpold" then
            RH.DumpUnclassified()
        elseif arg == "chat" then
            RH.sv.chatMessages = not RH.sv.chatMessages
            RH.forceMsg = true
            RH.Msg(RH.sv.chatMessages and L.MSG_CHAT_ON or L.MSG_CHAT_OFF)
            RH.forceMsg = false
        elseif arg == "stats" then
            RH.forceMsg = true; RH.PrintStats(); RH.forceMsg = false
        elseif arg == "dump" then
            RH.DumpAllStyles()
        elseif arg:sub(1, 4) == "find" then
            RH.forceMsg = true; RH.DiagFind((arg:match("^find%s+(.+)$"))); RH.forceMsg = false
        elseif arg == "trace" then
            RH.trace = not RH.trace
            RH.forceMsg = true
            RH.Msg("trace %s (guard installed=%s hook events=%s keepDyes=%s)", RH.trace and "ON" or "OFF",
                tostring(RH.dyeGuardInstalled), tostring(RH.hookCount or 0), tostring(RH.sv.keepDyes ~= false))
            RH.forceMsg = false
        elseif arg == "slots" then
            RH.forceMsg = true; RH.DiagSlots(); RH.forceMsg = false
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

---------------------------------------------------------------------------
-- 診断: /rsh slots  … 各部位の保留データと、マニピュレーターの関連メソッド名をチャットに出す
-- (未所持スタイルがプレビューに出ない原因調査用。服飾台で「ゲーム標準の一覧から未所持を選んだ状態」と
--  「アドオンで未所持を入れた状態」で、それぞれ実行して比較する)
---------------------------------------------------------------------------
function RH.DiagSlots()
    local om = RH.RequireManipulator()
    if not om then return end
    local names, seen = {}, {}
    for _, slot in ipairs(RH.allSlots) do
        local sm = RH.GetSlotManip(om, slot)
        if sm then
            local st = RH.GetSlotState(sm)
            local un = (st.id ~= 0) and tostring(IsCollectibleUnlocked(st.id)) or "-"
            RH.Msg("slot %s: id=%s mat=%s unlocked=%s p/s/a=%s/%s/%s", tostring(slot), tostring(st.id), tostring(st.mat), un, tostring(st.p), tostring(st.s), tostring(st.a))
            for k, v in pairs(sm) do
                if type(v) ~= "function" and type(v) ~= "table" and not seen[k] then
                    seen[k] = true
                    names[#names + 1] = tostring(k) .. "=" .. tostring(v)
                end
            end
            local mt = getmetatable(sm)
            local idx = mt and mt.__index
            if type(idx) == "table" and not seen.__m then
                seen.__m = true
                local m = {}
                for k, v in pairs(idx) do
                    if type(v) == "function" and (tostring(k):find("Lock") or tostring(k):find("Preview") or tostring(k):find("Valid") or tostring(k):find("Hidden")) then m[#m + 1] = tostring(k) end
                end
                table.sort(m)
                RH.Msg("methods: %s", table.concat(m, ", "))
            end
        end
    end
    table.sort(names)
    RH.Msg("fields: %s", table.concat(names, ", "))
    RH.Msg("om: previewing=%s", tostring(om.isPreviewing))
end

---------------------------------------------------------------------------
-- 診断: /rsh find 名前の一部 … 名前に一致するスタイルの ID・部位・重さ・グループ・所持を一覧表示
-- (セットの判定が合っているか調べる用。例: /rsh find シラベイン)
---------------------------------------------------------------------------
-- 全スタイルの情報をSavedVariablesへ書き出す(/rsh dump)
function RH.DumpAllStyles()
    local idx = RH.GetStyleIndex()
    local ids = {}
    for id in pairs(idx.info) do ids[#ids + 1] = id end
    table.sort(ids)
    local catType = COLLECTIBLE_CATEGORY_TYPE_OUTFIT_STYLE
    local total = (GetTotalCollectiblesByCategoryType and GetTotalCollectiblesByCategoryType(catType)) or 0
    local hiddenN = 0
    for _ in pairs(RH.GetHiddenStyleSet()) do hiddenN = hiddenN + 1 end
    local out = { string.format("# game total outfit styles=%d / indexed=%d / excluded(hidden-style)=%d", total, #ids, hiddenN),
                  "id|name|slots|armorType|gameStyleId|group|owned|icon" }
    -- 索引から除外された(非表示用スタイルなど)ものも別に列挙する
    local listed = {}
    for _, id in ipairs(ids) do listed[id] = true end
    local skipped = {}
    for i = 1, total do
        local id = GetCollectibleIdFromType(catType, i)
        if id and id > 0 and not listed[id] then
            skipped[#skipped + 1] = string.format("%d|%s|(not indexed: hidden-style item)", id, tostring(GetCollectibleName(id)))
        end
    end
    RH.sv.styleDumpSkipped = skipped
    for _, id in ipairs(ids) do
        local info = idx.info[id]
        local icon = GetCollectibleIcon and GetCollectibleIcon(id) or ""
        icon = string.match(icon or "", "([^/\\]*)$") or ""
        out[#out + 1] = string.format("%d|%s|%s|%s|%s|%s|%s|%s", id, tostring(GetCollectibleName(id)),
            table.concat(info.slots, ","), tostring(info.armorType), tostring(info.rawStyleId),
            tostring(info.styleId), tostring(IsCollectibleUnlocked(id)), icon)
    end
    RH.sv.styleDump = out
    RH.sv.mergeDump = RH.mergeLog
    RH.forceMsg = true
    RH.Msg("全スタイル %d件(ゲーム全体 " .. tostring(total) .. "件)を保存しました。/reloadui 後に SavedVariables\\RestyleHelper.lua の styleDump / mergeDump を送れます", #ids)
    RH.forceMsg = false
end

function RH.DiagFind(q)
    if not q or q == "" then RH.Msg("usage: /rsh find <name>") return end
    local idx = RH.GetStyleIndex()
    local ids = {}
    for id in pairs(idx.info) do
        local nm = GetCollectibleName(id) or ""
        if string.find(nm, q, 1, true) then ids[#ids + 1] = id end
    end
    table.sort(ids)
    local log = {}
    local function Out(fmt, ...)
        RH.Msg(fmt, ...)
        log[#log + 1] = string.format(fmt, ...)
    end
    Out("find '%s': %d", q, #ids)
    for n, id in ipairs(ids) do
        if n > 60 then Out("... (more)") break end
        local info = idx.info[id]
        local icon = GetCollectibleIcon and GetCollectibleIcon(id) or ""
        icon = string.match(icon or "", "([^/\\]*)$") or ""
        Out("%d %s | slot=%s at=%s grp=%s own=%s | %s", id, tostring(GetCollectibleName(id)),
            table.concat(info.slots, ","), tostring(info.armorType), tostring(info.styleId),
            tostring(IsCollectibleUnlocked(id)), icon)
    end
    -- グループの統合判定のログ(見つかったピースのグループに関係するもの)
    local sids = {}
    for _, id in ipairs(ids) do sids[tostring(idx.info[id].styleId)] = true end
    for _, line in ipairs(RH.mergeLog or {}) do
        local a, b = string.match(line, "merge%? (%-?%d+) <%- (%-?%d+)")
        if (a and sids[a]) or (b and sids[b]) then Out("%s", line) end
    end
    RH.sv.findLog = log
    Out("結果を保存しました。/reloadui 後に SavedVariables\\RestyleHelper.lua の findLog を送れます")
end
