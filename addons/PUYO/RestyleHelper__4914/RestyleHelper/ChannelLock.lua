local RH = RestyleHelper
local L = RH.L

---------------------------------------------------------------------------
-- 染料枠ロック
-- 服飾台の標準画面で、各部位のメイン/サブ/アクセント(3つの染料枠)のうち
-- 1か所だけをロックできる。Ctrl+クリックで切替。ロック中の枠は
-- ランダム化・配色シャッフルで変更されない。
---------------------------------------------------------------------------
local LOCK_TEX = "EsoUI/Art/Miscellaneous/status_locked.dds"

local function GetOverlay(ctl)
    if ctl.rshLockIcon then return ctl.rshLockIcon end
    local tex = WINDOW_MANAGER:CreateControl(nil, ctl, CT_TEXTURE)
    tex:SetDimensions(18, 18)
    tex:SetTexture(LOCK_TEX)
    tex:SetDrawLayer(DL_OVERLAY)
    tex:SetMouseEnabled(false)
    tex:SetAnchor(CENTER, ctl, CENTER, 0, 0)
    tex:SetHidden(true)
    ctl.rshLockIcon = tex
    return tex
end

local function UpdateOverlay(ctl)
    if not ctl.rshMode then return end
    GetOverlay(ctl):SetHidden(not RH.IsChannelLocked(ctl.rshMode, ctl.rshSlotType, ctl.rshChannel))
end

local function HookControl(ctl)
    if ctl.rshHooked then return end
    ctl.rshHooked = true
    ZO_PreHookHandler(ctl, "OnMouseUp", function(c, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT and IsControlKeyDown() and c.rshMode then
            local now = not RH.IsChannelLocked(c.rshMode, c.rshSlotType, c.rshChannel)
            RH.SetChannelLocked(c.rshMode, c.rshSlotType, c.rshChannel, now)
            UpdateOverlay(c)
            RH.Msg(now and L.MSG_CHANNEL_LOCK_ON or L.MSG_CHANNEL_LOCK_OFF)
            return true -- ゲーム標準のクリック処理は行わない
        end
        return false
    end)
end

---------------------------------------------------------------------------
-- 使い方のヒント表示(服飾台の防具欄、いちばん上の段の右側の空きスペース)
---------------------------------------------------------------------------
local hintWin, hintLabel, hintAnchor

local function EnsureHint()
    if hintWin then return end
    hintWin = WINDOW_MANAGER:CreateTopLevelWindow("RestyleHelperChannelHint")
    hintWin:SetDimensions(190, 40)
    hintWin:SetMouseEnabled(false)
    hintWin:SetDrawTier(DT_MEDIUM)
    hintWin:SetHidden(true)
    hintLabel = WINDOW_MANAGER:CreateControl("RestyleHelperChannelHintText", hintWin, CT_LABEL)
    hintLabel:SetFont("ZoFontGameSmall")
    hintLabel:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
    hintLabel:SetWidth(190)
    hintLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    hintLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    hintLabel:SetText("|t16:16:" .. LOCK_TEX .. "|t " .. L.HINT_CHANNEL_LOCK_LONG)
    hintLabel:SetAnchor(LEFT, hintWin, LEFT, 0, 0)
end

-- いちばん上にある染料枠(頭スロット)の右側にヒントを置く
local function PlaceHint(ctl)
    EnsureHint()
    local ok, top = pcall(ctl.GetTop, ctl)
    if not ok or not top then return end
    if hintAnchor and hintAnchor ~= ctl then
        local ok2, bestTop = pcall(hintAnchor.GetTop, hintAnchor)
        if ok2 and bestTop and bestTop < top - 1 then return end
        if ok2 and bestTop and math.abs(bestTop - top) <= 1 then
            -- 同じ段なら右側にある方
            local okL, curL = pcall(ctl.GetLeft, ctl)
            local okB, bestL = pcall(hintAnchor.GetLeft, hintAnchor)
            if okL and okB and curL and bestL and curL <= bestL then return end
        end
    end
    hintAnchor = ctl
    hintWin:ClearAnchors()
    hintWin:SetAnchor(LEFT, ctl, RIGHT, 14, 0)
end

function RH.SetChannelHintShown(show)
    if not hintWin then return end
    hintWin:SetHidden(not show)
end

local function OnRefresh(dyeControls, rsd)
    if type(dyeControls) ~= "table" or type(rsd) ~= "table" then return end
    local mode, slotType = rsd.restyleMode, rsd.restyleSlotType
    if mode == nil or slotType == nil then return end
    for i, ctl in ipairs(dyeControls) do
        ctl.rshMode, ctl.rshSlotType, ctl.rshChannel = mode, slotType, i
        local ok = pcall(HookControl, ctl)
        if ok then UpdateOverlay(ctl) end
    end
    -- 右端の染料枠を目印にヒントの位置を決める(初回表示も兼ねる)
    local last = dyeControls[#dyeControls]
    if last then
        pcall(PlaceHint, last)
        if RH.stationOpen then RH.SetChannelHintShown(true) end
    end
end

function RH.InstallChannelLockUI()
    if RH.channelLockInstalled then return end
    if type(ZO_Dyeing_RefreshDyeableSlotControlDyes) ~= "function" then return end
    RH.channelLockInstalled = true
    ZO_PostHook("ZO_Dyeing_RefreshDyeableSlotControlDyes", function(dyeControls, rsd)
        pcall(OnRefresh, dyeControls, rsd)
    end)
end
