local RH = RestyleHelper
local L = RH.L

---------------------------------------------------------------------------
-- 同一スタイルを全身へ一括適用
---------------------------------------------------------------------------
function RH.ApplyStyleToAll(collectibleId, respectLocks)
    local om = RH.RequireManipulator()
    if not om then return end
    local idx = RH.GetStyleIndex()
    local info = idx.info[collectibleId]
    if not info or info.styleId == 0 then
        RH.Msg(L.MSG_STYLE_NOINFO)
        if RH.debug then RH.Msg("id=%s info=%s", tostring(collectibleId), tostring(info)) end
        return
    end

    -- 防具スタイルなら防具7部位、武器スタイルなら武器スロットが対象
    local isArmorStyle = false
    for _, s in ipairs(info.slots) do
        if RH.isArmor[s] then isArmorStyle = true break end
    end
    local targets = isArmorStyle and RH.armorSlots or RH.weaponSlots

    RH.PushUndo(om)
    local applied, missing, substituted, hidden = 0, {}, {}, {}
    local states = {}
    for _, slot in ipairs(targets) do
        if not (respectLocks and RH.sv.locks[slot]) then
            local sm = RH.GetSlotManip(om, slot)
            if sm then
                local id, sub = RH.FindInStyle(info.styleId, slot, info.weight, collectibleId)
                if id then
                    local cur = RH.GetSlotState(sm)
                    -- 同じピースなら素材インデックスは維持
                    RH.SetSlotStyle(sm, id, (cur.id == id) and cur.mat or RH.DEFAULT_MATERIAL)
                    applied = applied + 1
                    states[slot] = sub and "sub" or "ok"
                    if sub then substituted[#substituted + 1] = RH.GetSlotName(slot) end
                elseif isArmorStyle then
                    local st = RH.HandleMissingSlot(sm, slot)
                    states[slot] = st
                    if st == "hidden" then
                        hidden[#hidden + 1] = RH.GetSlotName(slot)
                    else
                        missing[#missing + 1] = RH.GetSlotName(slot)
                    end
                end
            end
        end
    end

    local styleName = RH.GetStyleName(info.styleId)
    if isArmorStyle then RH.SetCoverage(styleName, states) end
    RH.Msg(L.MSG_APPLY_ALL_DONE, styleName, applied)
    if #substituted > 0 then RH.Msg(L.MSG_APPLY_ALL_WEIGHT, table.concat(substituted, ", ")) end
    if #hidden > 0 then RH.Msg(L.MSG_APPLY_ALL_HIDDEN, table.concat(hidden, ", ")) end
    if #missing > 0 then RH.Msg(L.MSG_APPLY_ALL_MISS, table.concat(missing, ", ")) end
end

function RH.ApplyChestToAll()
    local om = RH.RequireManipulator()
    if not om then return end
    local sm = RH.GetSlotManip(om, OUTFIT_SLOT_CHEST)
    local st = sm and RH.GetSlotState(sm)
    if not st or st.id == 0 then
        RH.Msg(L.MSG_CHEST_EMPTY)
        return
    end
    RH.ApplyStyleToAll(st.id, false)
end

---------------------------------------------------------------------------
-- 右クリックメニュー
---------------------------------------------------------------------------
-- グリッドのエントリーデータからコレクションIDを取り出す（構造差異に強くするため再帰探索）
function RH.ExtractCollectibleId(obj, depth)
    depth = depth or 0
    if obj == nil or depth > 3 then return nil end
    if type(obj) == "number" then
        return RH.IsStyleCollectible(obj) and obj or nil
    end
    if type(obj) ~= "table" then return nil end
    if RH.IsStyleCollectible(obj.collectibleId) then return obj.collectibleId end
    if type(obj.GetId) == "function" then
        local ok, id = pcall(obj.GetId, obj)
        if ok and RH.IsStyleCollectible(id) then return id end
    end
    for _, k in ipairs({ "collectibleData", "dataSource", "data", "entryData" }) do
        local v = obj[k]
        if v ~= nil and v ~= obj then
            local id = RH.ExtractCollectibleId(v, depth + 1)
            if id then return id end
        end
    end
    return nil
end

local function FindStyleIdFromControl(ctrl)
    local c = ctrl
    for _ = 1, 5 do
        if not c then return nil end
        local id = RH.ExtractCollectibleId(c.dataEntry, 0)
                or RH.ExtractCollectibleId(c.data, 0)
                or RH.ExtractCollectibleId(c.entryData, 0)
        if id then return id end
        c = c.GetParent and c:GetParent() or nil
    end
    return nil
end

-- メニュー項目を追加する
local function AddStyleMenuItems(collectibleId)
    AddMenuItem(L.MENU_APPLY_ALL, function() RH.ApplyStyleToAll(collectibleId, false) end)
    AddMenuItem(L.MENU_APPLY_ALL_LOCK, function() RH.ApplyStyleToAll(collectibleId, true) end)
    AddMenuItem(RH.IsFavorite(collectibleId) and L.MENU_FAV_REMOVE or L.MENU_FAV_ADD,
        function() RH.ToggleFavorite(collectibleId) end)
end

-- 公式の右クリック処理は ClearMenu → 項目追加 → ShowMenu の順に実行する。
-- 表示後に項目を足すとサイズが合わず押せないことがあるため、
--   1) 公式処理の直前に「どのスタイルか」を記録
--   2) 公式処理が ShowMenu を呼ぶ直前に、同じメニューへ項目を追加
-- という順で、表示前に項目を差し込む。
local pendingStyleId, pendingMs = nil, 0

function RH.InstallStyleMenuHooks()
    if RH.menuHooksInstalled then return end
    RH.menuHooksInstalled = true
    RH.InstallFavoritesUI()

    local panel = ZO_OUTFIT_STYLES_PANEL_KEYBOARD
    if panel and type(panel.OnOutfitStyleEntryRightClick) == "function" then
        ZO_PreHook(panel, "OnOutfitStyleEntryRightClick", function(_, entryData)
            pendingStyleId = RH.ExtractCollectibleId(entryData)
            pendingMs = GetFrameTimeMilliseconds()
            return false -- 公式処理は続行する
        end)

        ZO_PreHook("ShowMenu", function()
            local id = pendingStyleId
            pendingStyleId = nil
            if id and GetFrameTimeMilliseconds() - pendingMs < 300 then
                local ok, err = pcall(AddStyleMenuItems, id)
                if not ok and RH.debug then RH.Msg("menu error: " .. tostring(err)) end
            end
            return false -- 公式の ShowMenu は続行する
        end)
        RH.menuHookMode = "official"
        return
    end

    -- 公式処理が見つからない場合のフォールバック:
    -- 右クリックされたグリッド要素を直接調べて、自前でメニューを出す
    RH.menuHookMode = "fallback"
    EVENT_MANAGER:RegisterForEvent(RH.name .. "_Mouse", EVENT_GLOBAL_MOUSE_UP, function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_RIGHT or not RH.stationOpen then return end
        local id = FindStyleIdFromControl(WINDOW_MANAGER:GetMouseOverControl())
        if not id then return end
        zo_callLater(function()
            ClearMenu()
            AddStyleMenuItems(id)
            ShowMenu(nil)
        end, 50)
    end)
end

---------------------------------------------------------------------------
-- 今のスタイルを軽装 / 中装 / 重装に切り替える(防具7部位。同じスタイルの別の重さのピースに差し替え)
-- 武器・重さのないスタイル・該当ピースが無い(未所持を含む)部位は変更しない
---------------------------------------------------------------------------
RH.WEIGHT_TYPES = {
    light  = VISUAL_ARMORTYPE_LIGHT  or 1,
    medium = VISUAL_ARMORTYPE_MEDIUM or 2,
    heavy  = VISUAL_ARMORTYPE_HEAVY  or 3,
}

function RH.SwitchWeight(weightKey)
    local armorType = RH.WEIGHT_TYPES[weightKey]
    local om = RH.RequireManipulator()
    if not (om and armorType) then return end
    local idx = RH.GetStyleIndex()
    RH.PushUndo(om)
    local changed, same, missing = 0, 0, {}
    for _, slot in ipairs(RH.armorSlots) do
        local sm = RH.GetSlotManip(om, slot)
        local st = sm and RH.GetSlotState(sm)
        local id = st and st.id or 0
        local info = id ~= 0 and idx.info[id] or nil
        if info and info.styleId ~= 0 and info.weight ~= 0 then
            if info.weight == armorType or not RH.SlotHasWeightVariants(info.styleId, slot) then
                same = same + 1   -- 重さが1種類しか無い部位は、そのまま(切り替え対象外)
            else
                local newId, substituted = RH.FindInStyle(info.styleId, slot, armorType)
                if newId and not substituted and newId ~= id and RH.SetSlotStyle(sm, newId, RH.DEFAULT_MATERIAL) then
                    changed = changed + 1
                else
                    missing[#missing + 1] = RH.GetSlotName(slot)
                end
            end
        end
    end
    RH.forceMsg = true
    if changed + same == 0 and #missing == 0 then
        RH.Msg(L.MSG_WEIGHT_NONE)
    else
        RH.Msg(L.MSG_WEIGHT_DONE, L["WEIGHT_" .. weightKey], changed, same, #missing > 0 and table.concat(missing, ", ") or L.COVER_NONE)
    end
    RH.forceMsg = false
end

---------------------------------------------------------------------------
-- 未所持のスタイル / 染料が保留に含まれているときの警告表示
-- (未所持が含まれる間は、ゲームの仕様で服飾台の「適用」ができない)
---------------------------------------------------------------------------
function RH.UpdateUnownedWarning(om)
    local lbl = RH.ui and RH.ui.unownedLabel
    if not lbl then return end
    local warn = false
    local styleSlots, dyeCount = {}, 0
    RH.unownedSlots = {}
    if om then
        RH.GetKnownDyes()
        local hidden = RH.GetHiddenStyleSet()
        for _, slot in ipairs(RH.allSlots) do
            local sm = RH.GetSlotManip(om, slot)
            local st = sm and RH.GetSlotState(sm)
            if st then
                if st.id ~= 0 and not hidden[st.id] and RH.IsStyleCollectible(st.id) and not RH.IsUnlocked(st.id) then warn = true; styleSlots[#styleSlots + 1] = RH.GetSlotName(slot); RH.unownedSlots[slot] = true end
                for _, d in ipairs({ st.p, st.s, st.a }) do
                    if d and d ~= 0 and RH.dyeInfo[d] and not RH.dyeOwned[d] then warn = true; dyeCount = dyeCount + 1 end
                end
            end
        end
    end
    if warn then
        local parts = {}
        if #styleSlots > 0 then parts[#parts + 1] = string.format(L.WARN_UNOWNED_STYLE, table.concat(styleSlots, ",")) end
        if dyeCount > 0 then parts[#parts + 1] = string.format(L.WARN_UNOWNED_DYE, dyeCount) end
        lbl:SetText(string.format(L.WARN_UNOWNED_FMT, table.concat(parts, " ")))
    end
    lbl:SetHidden(not warn)
    if RH.RefreshCoverage then RH.RefreshCoverage() end
end
