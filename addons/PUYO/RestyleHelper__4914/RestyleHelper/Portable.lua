local RH = RestyleHelper
local L = RH.L

-- 試験機能: 服飾台の外で使うための「仮想の衣装」
--   ・服飾台が開いていないときは、装備中の衣装を元にした仮想の衣装(アドオン内のデータ)を編集する
--   ・ランダム化 / 一括適用 / プリセットの試着 / 保存 は、この仮想の衣装に対して動く
--   ・キャラクタープレビューへの反映は RH.PreviewVirtual(下記)。ゲームのプレビュー画面
--     (収集品の衣装スタイルなど)が開いているときだけ反映できる
--   ・実際に着替える(確定する)のは服飾台でしかできない。プリセット保存 → 服飾台で適用 の流れで使う

local function ActorCat() return GAMEPLAY_ACTOR_CATEGORY_PLAYER or 0 end

local function Copy3(a, b, c) return { a or 0, b or 0, c or 0 } end

local function NewVirtual()
    local actor = ActorCat()
    local idx = GetEquippedOutfitIndex and GetEquippedOutfitIndex(actor)
    local om = { virtual = true, slots = {}, actor = actor, outfitIndex = idx }
    function om:GetActorCategory() return self.actor end
    function om:GetOutfitIndex() return self.outfitIndex end
    function om:GetSlotManipulator(slot) return self.slots[slot] end
    om.outfitSlotManipulators = om.slots -- ゲームの UpdatePreviews が参照する

    for _, slot in ipairs(RH.allSlots) do
        local sm = { owner = om, outfitSlotIndex = slot }
        -- ゲーム側のメソッド(UpdatePreview など)を使えるようにする。
        -- プレビュー用の保護関数は「ゲームのコード」から呼ばれる必要があるため。
        if ZO_OutfitSlotManipulator then setmetatable(sm, { __index = ZO_OutfitSlotManipulator }) end
        local id, mat = 0, nil
        if idx and GetOutfitSlotInfo then
            local ok, a, b = pcall(GetOutfitSlotInfo, actor, idx, slot)
            if ok then id, mat = a or 0, b end
        end
        sm.baseId, sm.baseMat = id, mat
        sm.currentCollectibleId, sm.currentItemMaterialIndex = id, mat
        sm.pendingCollectibleId, sm.pendingItemMaterialIndex = id, mat

        local rsd = { virtual = true, restyleMode = RESTYLE_MODE_OUTFIT or 1, restyleSetIndex = idx or 0, restyleSlotType = slot }
        rsd.currentDyes = { 0, 0, 0 }
        if idx and GetRestyleSlotCurrentDyes then
            local ok, a, b, c = pcall(GetRestyleSlotCurrentDyes, rsd.restyleMode, rsd.restyleSetIndex, slot)
            if ok then rsd.currentDyes = Copy3(a, b, c) end
        end
        rsd.dyes = Copy3(rsd.currentDyes[1], rsd.currentDyes[2], rsd.currentDyes[3])
        function rsd:AreDyeChannelsDyeable()
            if AreDyeChannelsDyeableForOutfitSlotData then
                local ok, a, b, c = pcall(AreDyeChannelsDyeableForOutfitSlotData, actor, slot, sm.pendingCollectibleId or 0)
                if ok then return a and true or false, b and true or false, c and true or false end
            end
            return true, true, true
        end
        function rsd:GetCurrentDyes() return self.currentDyes[1], self.currentDyes[2], self.currentDyes[3] end
        function rsd:GetPendingDyes() return self.dyes[1], self.dyes[2], self.dyes[3] end
        function rsd:AreTherePendingDyeChanges()
            for i = 1, 3 do if self.dyes[i] ~= self.currentDyes[i] then return true end end
            return false
        end
        function rsd:CleanPendingDyes()
            local d = { self:AreDyeChannelsDyeable() }
            for i = 1, 3 do if not d[i] then self.dyes[i] = self.currentDyes[i] end end
        end
        sm.restyleSlotData = rsd

        function sm:GetPendingCollectibleId() return self.pendingCollectibleId end
        function sm:GetPendingItemMaterialIndex() return self.pendingItemMaterialIndex end
        function sm:GetPendingDyeData() return rsd.dyes[1], rsd.dyes[2], rsd.dyes[3] end
        function sm:IsAnyChangePending()
            if self.pendingCollectibleId ~= self.baseId or self.pendingItemMaterialIndex ~= self.baseMat then return true end
            for i = 1, 3 do if rsd.dyes[i] ~= rsd.currentDyes[i] then return true end end
            return false
        end
        om.slots[slot] = sm
    end
    return om
end

function RH.ResetVirtual()
    RH.virtualOm = nil
    RH.Msg(L.MSG_VIRTUAL_RESET)
end

-- 編集対象の衣装: 服飾台が開いていれば従来どおり。閉じていて試験機能がオンなら仮想の衣装
local origGet = RH.GetCurrentOutfitManipulator
function RH.GetCurrentOutfitManipulator()
    if RH.stationOpen then return origGet() end
    if not (RH.sv and RH.sv.portable) then return nil end
    if not RH.virtualOm then RH.virtualOm = NewVirtual() end
    return RH.virtualOm
end

---------------------------------------------------------------------------
-- 仮想の衣装をキャラクタープレビューへ反映
-- プレビュー用の関数(Add...ToPreviewCollection)は保護関数で、
-- アドオンからは呼べない。服飾台のシートウィンドウが表示されている間だけ、
-- 服飾台と同じ KickPreview(ゲーム自身の更新処理に任せる方式)を使う。それ以外は反映しない。
---------------------------------------------------------------------------
RH.previewDiag = nil

function RH.PreviewVirtual(om, quiet)
    om = om or RH.virtualOm
    if not (om and om.virtual) then return false end
    -- ※ 保護関数(AddOutfitSlotPreviewElementToPreviewCollection など)は「名前を参照するだけ」でも
    --    アドオンからはエラーになるため、このファイルでは一切参照しない
    if not IsCharacterPreviewingAvailable then return false end
    if not IsCharacterPreviewingAvailable() then
        RH.previewDiag = "not available"
        if not quiet and not RH.pvHintShown then
            RH.pvHintShown = true
            RH.forceMsg = true; RH.Msg(L.MSG_PV_UNAVAILABLE); RH.forceMsg = false
        end
        return false
    end
    -- 1) ゲーム自身の OnUpdate に実行させる方法(服飾台と同じ KickPreview)。
    --    シートウィンドウが表示されている(収集品の衣装スタイル画面など)ときだけ使える
    local sw = ZO_RESTYLE_SHEET_WINDOW_KEYBOARD
    if sw and sw.control and not sw.control:IsHidden() and ZO_OutfitManipulator and ZO_OutfitManipulator.UpdatePreviews then
        RH.previewDiag = "kick"
        RH.KickPreview(om)
        return true
    end
    -- 2) ここから先は不可: プレビュー用の関数はゲームが保護しており、アドオンからは呼べない
    --    (実機で「Attempt to access a private function ... from insecure code」になることを確認済み)。
    --    回避を試みず、仮想の衣装の編集とプリセット保存だけを行う。
    RH.previewDiag = "blocked"
    if not quiet and not RH.pvHintShown then
        RH.pvHintShown = true
        RH.forceMsg = true; RH.Msg(L.MSG_PV_BLOCKED); RH.forceMsg = false
    end
    return false
end

local origRefresh = RH.RefreshPreview
function RH.RefreshPreview(om)
    if om and om.virtual then RH.PreviewVirtual(om) else origRefresh(om) end
end

-- 診断: /rsh ptest
function RH.PreviewTest()
    RH.forceMsg = true
    RH.Msg("[ptest] station=%s portable=%s", tostring(RH.stationOpen), tostring(RH.sv.portable))
    RH.Msg("[ptest] IsCharacterPreviewingAvailable=%s", tostring(IsCharacterPreviewingAvailable and IsCharacterPreviewingAvailable()))
    RH.forceMsg = false
    RH.pvHintShown = false
    local om = RH.GetCurrentOutfitManipulator()
    if om and om.virtual then
        local ok = RH.PreviewVirtual(om, true)
        RH.forceMsg = true
        RH.Msg("[ptest] result=%s (%s)", tostring(ok), tostring(RH.previewDiag))
        RH.forceMsg = false
    else
        RH.forceMsg = true
        RH.Msg("[ptest] virtual outfit not active (close the station / enable the option)")
        RH.forceMsg = false
    end
end

---------------------------------------------------------------------------
-- ゲームの「衣装スタイル」画面(収集品)を開いたらパネルを自動表示 / 閉じたら消す
---------------------------------------------------------------------------
RH.bookOpen = false
local function HookBookScene()
    local scene = ZO_OUTFIT_STYLES_BOOK_SCENE or (SCENE_MANAGER and SCENE_MANAGER:GetScene("outfitStylesBook"))
    if not scene or not scene.RegisterCallback then return false end
    scene:RegisterCallback("StateChange", function(_, newState)
        if not (RH.sv and RH.sv.portable) then return end
        if newState == SCENE_SHOWN then
            RH.bookOpen = true
            RH.pvHintShown = false
            if not RH.stationOpen and RH.sv.showPanel then RH.ShowPanel(true) end
        elseif newState == SCENE_HIDDEN then
            RH.bookOpen = false
            if not RH.stationOpen then
                RH.ShowPanel(false)
                RH.ShowShareWindow(false)
                RH.ShowFavoritesWindow(false)
                RH.ShowColorsWindow(false)
            end
        end
    end)
    return true
end
EVENT_MANAGER:RegisterForEvent(RH.name .. "_PortableBook", EVENT_PLAYER_ACTIVATED, function()
    EVENT_MANAGER:UnregisterForEvent(RH.name .. "_PortableBook", EVENT_PLAYER_ACTIVATED)
    if not HookBookScene() then zo_callLater(HookBookScene, 1000) end
end)

-- 服飾台を離れたら、次回は装備中の衣装から作り直す(服飾台で衣装が変わっている可能性があるため)
EVENT_MANAGER:RegisterForEvent(RH.name .. "_Portable", EVENT_DYEING_STATION_INTERACT_END, function()
    RH.virtualOm = nil
end)
