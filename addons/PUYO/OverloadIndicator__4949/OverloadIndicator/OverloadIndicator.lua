-- Overload Indicator
-- Sorcererのアルティメット「オーバーロード」のON/OFF状態を視覚的に表示するアドオン

local ADDON_NAME = "OverloadIndicator"

local defaults = {
    point       = CENTER,
    relPoint    = CENTER,
    x           = 0,
    y           = -220,
    locked      = false,
    scale       = 1.0,
    hideWhenOff = false, -- true にすると OFF 中は完全非表示になる
    hideInMenu  = true,  -- true にするとインベントリ等のメニューを開いている間は非表示になる
    slottedOnly = false, -- true にするとオーバーロードがセットされているバーの時だけ表示（デフォルトOFF＝常時表示）
    knownIconPaths = {
        -- 実機確認済みのアイコン画像パス（Overload本体＋両モーフ）。言語非依存の判定に使う。
        ["/esoui/art/icons/ability_sorcerer_overload.dds"] = true,
        ["/esoui/art/icons/ability_sorcerer_power_overload.dds"] = true,
        ["/esoui/art/icons/ability_sorcerer_energy_overload.dds"] = true,
    },
    iconSize      = 58,   -- アイコンのサイズ（ピクセル、32〜160）
    warnEnabled   = true, -- 発動中、指定量を切ったら画面中央に警告を出すか
    warnThreshold = 150,  -- 警告を出すウルト量のしきい値
    warnDuration  = 5,    -- 警告を表示し続ける秒数（3〜30）
    warnX         = 0,    -- 警告の表示位置（画面中央からの横オフセット）
    warnY         = 0,    -- 警告の表示位置（画面中央からの縦オフセット）
    language      = "auto", -- "auto" / "ja" / "en"
}

-- ============================================================
-- 多言語対応（日本語クライアント=jp、それ以外=en）
-- ============================================================
local ADDON_VERSION = "1.8.2"

-- 言語判定: CVar(大文字小文字の両方) と、ゲーム内文字列にひらがな・カタカナが含まれるかで調べる。
-- 日本語と分かったら固定。分からない間は呼ぶたびに調べ直す。sv.language ("auto"/"ja"/"en") で手動指定も可能。
local detectedJa = false
local langSv -- sv への参照（OnAddOnLoaded で設定）
local function HasKana(v)
    return type(v) == "string" and v:find("\227[\129-\131]") ~= nil
end
local function DetectJa()
    if detectedJa then return true end
    local ja = false
    if GetCVar then
        for _, key in ipairs({ "language.2", "Language.2" }) do
            local ok, v = pcall(GetCVar, key)
            if ok and type(v) == "string" then
                v = v:lower()
                if v == "ja" or v == "jp" then ja = true end
            end
        end
    end
    if not ja and GetString then
        for _, key in ipairs({ "SI_DIALOG_CANCEL", "SI_DIALOG_ACCEPT", "SI_DIALOG_YES", "SI_DIALOG_NO", "SI_DIALOG_CLOSE" }) do
            local id = _G[key]
            if id then
                local ok, v = pcall(GetString, id)
                if ok and HasKana(v) then ja = true break end
            end
        end
    end
    if ja then detectedJa = true end
    return ja
end
local function GetLang()
    local o = langSv and langSv.language
    if o == "ja" then return "jp" elseif o == "en" then return "en" end
    return DetectJa() and "jp" or "en"
end

local STRINGS = {
    jp = {
        msgLock = "位置をロックしました。",
        msgUnlock = "位置ロックを解除しました。ドラッグで移動できます。",
        msgHide = "OFF時は非表示になります。",
        msgShow = "OFF時も消灯アイコンを表示します。",
        msgSlotOnlyOn = "オーバーロードをセットしているバーの時だけ表示します。",
        msgSlotOnlyOff = "オーバーロードがセットされていなくても常時表示します。",
        msgMenuHideOn = "メニューを開いている間は非表示にします。",
        msgMenuHideOff = "メニューを開いていても表示し続けます。",
        msgReset = "位置をリセットしました。",
        msgMoveTo = "位置を x=%s y=%s に設定しました。",
        msgMoved = "位置を x=%s y=%s に移動しました。",
        msgWarnOn = "ウルト警告を有効にしました。",
        msgWarnOff = "ウルト警告を無効にしました。",
        msgWarnAt = "警告を出すウルト量を %d に設定しました。",
        msgWarnDur = "警告の表示時間を %d 秒に設定しました。",
        msgWarnPos = "警告の表示位置を X=%d, Y=%d に設定しました。",
        msgWarnTest = "警告のプレビューを表示します。",
        msgPreviewOn = "プレビューモードON: 警告をマウスドラッグで移動できます（カーソルモードにしてください）。",
        msgPreviewOff = "プレビューモードOFF。",
        msgLang = "言語を %s に設定しました（設定画面は /reloadui 後に反映）。",
        msgSize = "アイコンサイズを %d に設定しました。",
        helpTitle = "コマンド一覧:",
        helpLock = "位置をロック",
        helpUnlock = "位置ロック解除（ドラッグで移動）",
        helpHide = "OFF時は非表示",
        helpShow = "OFF時も表示（デフォルト）",
        helpSlotOnly = "オーバーロードをセットしたバーの時だけ表示するか（デフォルトoff＝常時表示）",
        helpMenuHide = "メニューを開いた時に非表示にするか（デフォルトon）",
        helpReset = "表示位置をリセット",
        helpMoveTo = "座標を直接指定（例: /overload moveto 0 -220）",
        helpMove = "現在位置から相対移動（例: /overload move 0 -20 で20px上へ）",
        helpWarn = "画面中央の警告表示ON/OFF",
        helpWarnAt = "警告を出すウルト量を変更（デフォルト150）",
        helpWarnDur = "警告の表示時間を変更（3〜30秒、デフォルト5秒）",
        helpWarnPos = "警告の表示位置を変更（画面中央からのオフセット）",
        helpWarnTest = "警告をプレビュー表示",
        helpPreview = "プレビューモード切替（警告をドラッグで移動）",
        helpLang = "言語を指定（ja / en / auto）",
        helpSize = "アイコンサイズを変更（32〜160、デフォルト58）",
        helpDebug = "現在の内部状態を表示（不具合調査用）",
        menuDescription = "ソーサラーのオーバーロードON/OFFを画面上に表示します。(作者: PUYO / AIの支援で作成)",
        menuLockName = "位置をロック",
        menuLockTip = "有効にするとドラッグで動かせなくなります。",
        menuHideOffName = "OFF時は非表示にする",
        menuHideOffTip = "有効にするとオーバーロードOFF中はインジケーターが消えます。無効だと消灯した状態のアイコンが表示され続けます。",
        menuSlotOnlyName = "オーバーロードをセットしたバーの時だけ表示",
        menuSlotOnlyTip = "有効にすると、オーバーロードがセットされているスキルバーの時だけ表示します。無効（初期設定）の場合はセットの有無に関係なく常に表示します。",
        menuMenuHideName = "メニューを開いたら非表示にする",
        menuMenuHideTip = "有効にするとインベントリ・マップなどのメニューを開いている間はインジケーターが消えます。",
        menuWarnName = "ウルト量が閾値を切ったら画面中央に警告",
        menuWarnTip = "オーバーロード発動中、ウルト量が指定値を下回ると画面中央に赤字で「OFF」と表示します。",
        menuWarnAtName = "警告を出すウルト量",
        menuWarnAtTip = "この値を下回ると画面中央に警告が表示されます。",
        menuWarnDurName = "警告の表示時間（秒）",
        menuWarnDurTip = "警告が画面中央に表示され続ける秒数です。",
        menuWarnXName = "警告の位置 X（左右）",
        menuWarnYName = "警告の位置 Y（上下）",
        menuWarnPosTip = "警告の表示位置を画面中央からのオフセットで指定します。変更時にプレビューが数秒表示されます。",
        menuPreviewName = "警告プレビューモード（ドラッグで移動）",
        menuPreviewTip = "ONの間、警告を常に表示し、カーソルモードでマウスドラッグして好きな位置に動かせます。位置は自動保存されます。調整後はOFFに戻してください。",
        menuSizeName = "アイコンサイズ",
        menuSizeTip = "アイコン自体のサイズ（ピクセル）を変更します。表示スケールとは別に、アイコンの基本サイズを直接調整できます。",
        menuScaleName = "表示スケール",
        menuResetPosName = "表示位置をリセット",
    },
    en = {
        msgLock = "Position locked.",
        msgUnlock = "Position unlocked. You can now drag the icon.",
        msgHide = "The icon will be hidden while Overload is OFF.",
        msgShow = "The dimmed icon will be shown while Overload is OFF.",
        msgSlotOnlyOn = "The icon will only be shown when Overload is slotted on the current bar.",
        msgSlotOnlyOff = "The icon will always be shown, even if Overload is not slotted.",
        msgMenuHideOn = "The icon will be hidden while menus are open.",
        msgMenuHideOff = "The icon will stay visible while menus are open.",
        msgReset = "Position reset.",
        msgMoveTo = "Position set to x=%s y=%s.",
        msgMoved = "Moved to x=%s y=%s.",
        msgWarnOn = "Low-ultimate warning enabled.",
        msgWarnOff = "Low-ultimate warning disabled.",
        msgWarnAt = "Warning threshold set to %d ultimate.",
        msgWarnDur = "Warning display time set to %d seconds.",
        msgWarnPos = "Warning position set to X=%d, Y=%d.",
        msgWarnTest = "Showing warning preview.",
        msgPreviewOn = "Preview mode ON: drag the warning with the mouse to move it (switch to cursor mode).",
        msgPreviewOff = "Preview mode OFF.",
        msgLang = "Language set to %s (settings menu updates after /reloadui).",
        msgSize = "Icon size set to %d.",
        helpTitle = "Commands:",
        helpLock = "Lock position",
        helpUnlock = "Unlock position (drag to move)",
        helpHide = "Hide the icon while Overload is OFF",
        helpShow = "Show the icon while Overload is OFF (default)",
        helpSlotOnly = "Only show when Overload is slotted on the current bar (default: off = always shown)",
        helpMenuHide = "Hide while menus are open (default: on)",
        helpReset = "Reset position",
        helpMoveTo = "Set position directly (e.g. /overload moveto 0 -220)",
        helpMove = "Move relative to the current position (e.g. /overload move 0 -20 moves 20px up)",
        helpWarn = "Enable/disable the center-screen warning",
        helpWarnAt = "Ultimate value that triggers the warning (default 150)",
        helpWarnDur = "Warning display time (3-30 seconds, default 5)",
        helpWarnPos = "Warning position (offset from screen center)",
        helpWarnTest = "Show a warning preview",
        helpPreview = "Toggle preview mode (drag the warning to move it)",
        helpLang = "Set language (ja / en / auto)",
        helpSize = "Icon size (32-160, default 58)",
        helpDebug = "Print internal state (for troubleshooting)",
        menuDescription = "Shows whether the Sorcerer ultimate Overload is ON or OFF on screen. (Author: PUYO / Created with the assistance of AI)",
        menuLockName = "Lock position",
        menuLockTip = "When enabled, the icon can no longer be dragged.",
        menuHideOffName = "Hide when Overload is OFF",
        menuHideOffTip = "When enabled, the indicator disappears while Overload is OFF. When disabled, a dimmed icon stays visible.",
        menuSlotOnlyName = "Only show when Overload is slotted on the current bar",
        menuSlotOnlyTip = "When enabled, the icon is only shown while Overload is slotted on the current skill bar. When disabled (default), it is always shown.",
        menuMenuHideName = "Hide while menus are open",
        menuMenuHideTip = "When enabled, the indicator is hidden while menus such as the inventory or map are open.",
        menuWarnName = "Warn at screen center when ultimate is low",
        menuWarnTip = "While Overload is active, shows a red \"OFF\" at the center of the screen when your ultimate drops below the set value.",
        menuWarnAtName = "Warning ultimate threshold",
        menuWarnAtTip = "A warning is shown at the center of the screen when your ultimate drops below this value.",
        menuWarnDurName = "Warning display time (seconds)",
        menuWarnDurTip = "How long the warning stays on screen.",
        menuWarnXName = "Warning position X (horizontal)",
        menuWarnYName = "Warning position Y (vertical)",
        menuWarnPosTip = "Warning position as an offset from the screen center. A preview is shown for a few seconds when changed.",
        menuPreviewName = "Warning preview mode (drag to move)",
        menuPreviewTip = "While ON, the warning is always shown and can be dragged with the mouse (in cursor mode). The position is saved automatically. Turn it OFF when done.",
        menuSizeName = "Icon size",
        menuSizeTip = "Changes the base size of the icon in pixels, independently of the display scale.",
        menuScaleName = "Display scale",
        menuResetPosName = "Reset position",
    },
}

local function L(key)
    local lang = GetLang()
    return (STRINGS[lang] and STRINGS[lang][key]) or STRINGS.en[key] or key
end

local function Say(text)
    d("|c99CCEF[Overload Indicator]|r " .. text)
end


local sv
local topLevel
local glowTexture
local outerGlowTexture
local iconTexture
local redOverlayTexture
local ringTexture
local warningControl
local warningLabel
local warningBackdrop
local warningPreview = false
local isOverloadActive = false
local currentUltimate = 0
local currentIconPath = "/esoui/art/icons/ability_sorcerer_overload.dds" -- Overloadのデフォルトアイコン（実際のバフ発生時は実際のアイコンに差し替わる）
local pulseStartTime = 0
local warningGeneration = 0

-- ============================================================
-- UI 作成
-- ============================================================
local function CreateUI()
    topLevel = WINDOW_MANAGER:CreateTopLevelWindow(ADDON_NAME .. "TopLevel")
    topLevel:SetDimensions(96, 96)
    topLevel:SetClampedToScreen(true)
    topLevel:SetMouseEnabled(true)
    topLevel:SetMovable(true)
    topLevel:SetDrawTier(DT_HIGH) -- スキルバーなど他のHUD要素より手前に表示する

    -- 点灯風の光彩（外側の大きな光暈＋内側の明るい光の二重構成でグロウ感を強調）
    outerGlowTexture = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "OuterGlow", topLevel, CT_TEXTURE)
    outerGlowTexture:SetAnchor(CENTER, topLevel, CENTER, 0, 0)
    outerGlowTexture:SetTexture("EsoUI/Art/LFG/LFG_iconBG_glow.dds")
    outerGlowTexture:SetBlendMode(TEX_BLEND_MODE_ADD)
    outerGlowTexture:SetDrawLevel(0)

    glowTexture = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "Glow", topLevel, CT_TEXTURE)
    glowTexture:SetAnchor(CENTER, topLevel, CENTER, 0, 0)
    glowTexture:SetTexture("EsoUI/Art/LFG/LFG_iconBG_glow.dds")
    glowTexture:SetBlendMode(TEX_BLEND_MODE_ADD)
    glowTexture:SetDrawLevel(1)

    -- アイコン本体（バフの実際のアイコンを表示）
    iconTexture = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "Icon", topLevel, CT_TEXTURE)
    iconTexture:SetAnchor(CENTER, topLevel, CENTER, 0, 0)
    iconTexture:SetTexture(currentIconPath)
    iconTexture:SetDrawLevel(2)

    -- アイコンに重ねて赤く染める加算合成レイヤー（元アイコンの色に関係なく確実に赤くする）
    redOverlayTexture = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "RedOverlay", topLevel, CT_TEXTURE)
    redOverlayTexture:SetAnchor(CENTER, topLevel, CENTER, 0, 0)
    redOverlayTexture:SetTexture(currentIconPath)
    redOverlayTexture:SetBlendMode(TEX_BLEND_MODE_ADD)
    redOverlayTexture:SetDrawLevel(3)

    -- 縁取り（枠）
    ringTexture = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "Ring", topLevel, CT_TEXTURE)
    ringTexture:SetAnchor(CENTER, topLevel, CENTER, 0, 0)
    ringTexture:SetTexture("EsoUI/Art/Miscellaneous/UI_SkillPoint_Circle.dds")
    ringTexture:SetDrawLevel(4)

    -- ドラッグ移動
    -- GetAnchor() はドラッグ後に内部的な基準点が変わっていることがあるため使わず、
    -- 実際の画面上のピクセル位置から CENTER 基準のオフセットを計算し直す（常に安定した形式で保存する）
    topLevel:SetHandler("OnMoveStop", function()
        local screenWidth, screenHeight = GuiRoot:GetWidth(), GuiRoot:GetHeight()
        local left, top = topLevel:GetLeft(), topLevel:GetTop()
        local width, height = topLevel:GetWidth(), topLevel:GetHeight()
        local centerX = left + width / 2
        local centerY = top + height / 2

        sv.point, sv.relPoint = CENTER, CENTER
        sv.x = centerX - screenWidth / 2
        sv.y = centerY - screenHeight / 2

        topLevel:ClearAnchors()
        topLevel:SetAnchor(sv.point, GuiRoot, sv.relPoint, sv.x, sv.y)
    end)

    topLevel:SetHandler("OnMouseDown", function(self, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and sv.locked then
            self:StartMoving()
        end
    end)
    topLevel:SetHandler("OnMouseUp", function(self)
        self:StopMovingOrResizing()
    end)
end

-- ドラッグ操作に頼らず、確実に位置を指定するための関数
local function SetPosition(x, y)
    sv.point, sv.relPoint = CENTER, CENTER
    sv.x, sv.y = x, y
    topLevel:ClearAnchors()
    topLevel:SetAnchor(sv.point, GuiRoot, sv.relPoint, sv.x, sv.y)
end

-- アイコンサイズの変更を各パーツに反映する
local function ApplyIconSize()
    local size = sv.iconSize
    iconTexture:SetDimensions(size, size)
    redOverlayTexture:SetDimensions(size, size)
    ringTexture:SetDimensions(size + 8, size + 8)
    glowTexture:SetDimensions(size * 2.2, size * 2.2)
    outerGlowTexture:SetDimensions(size * 3.1, size * 3.1)
    topLevel:SetDimensions(size + 24, size + 24)
end

-- ============================================================
-- 点灯（グロー）アニメーション
-- ============================================================
-- 注意: topLevel:SetHandler("OnUpdate", ...) を使うと、ドラッグ移動
-- （StartMoving）が内部的に使っている毎フレーム更新の仕組みと競合し、
-- ドラッグが効かなくなることがあるため、独立したタイマーを使う。
local PULSE_UPDATE_NAME = ADDON_NAME .. "Pulse"

local function OnPulseUpdate()
    -- 点灯中はゆらゆらと明滅させて「灯りが点いている」感じを出す
    local elapsed = GetGameTimeMilliseconds() - pulseStartTime
    local innerPulse = 0.65 + 0.35 * math.sin(elapsed / 220)
    local outerPulse = 0.35 + 0.25 * math.sin(elapsed / 420 + 1) -- 外側はゆっくり・控えめに明滅
    glowTexture:SetColor(1, 0.2, 0.15, innerPulse) -- 赤みがかった光（内側）
    outerGlowTexture:SetColor(1, 0.15, 0.1, outerPulse) -- 赤みがかった光（外側・大きめ）
end

local function StartPulse()
    pulseStartTime = GetGameTimeMilliseconds()
    EVENT_MANAGER:RegisterForUpdate(PULSE_UPDATE_NAME, 16, OnPulseUpdate)
end

local function StopPulse()
    EVENT_MANAGER:UnregisterForUpdate(PULSE_UPDATE_NAME)
end

-- ============================================================
-- 画面中央の警告表示（ウルトが閾値を切った時）
-- ============================================================
local function CreateWarningUI()
    warningControl = WINDOW_MANAGER:CreateTopLevelWindow(ADDON_NAME .. "Warning")
    warningControl:SetDimensions(500, 120)
    warningControl:SetAnchor(CENTER, GuiRoot, CENTER, sv.warnX or 0, sv.warnY or 0)
    warningControl:SetDrawTier(DT_HIGH)
    warningControl:SetHidden(true)

    warningLabel = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "WarningLabel", warningControl, CT_LABEL)
    warningLabel:SetAnchorFill(warningControl)
    warningLabel:SetFont("ZoFontGameBold|48|thick-outline")
    warningLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    warningLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    warningLabel:SetColor(1, 0.15, 0.15, 1)
    warningLabel:SetText("OFF")

    -- プレビューモード用の枠（位置が分かりやすいように表示）
    warningBackdrop = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "WarningBackdrop", warningControl, CT_BACKDROP)
    warningBackdrop:SetAnchorFill(warningControl)
    warningBackdrop:SetCenterColor(0, 0, 0, 0.35)
    warningBackdrop:SetEdgeColor(1, 1, 1, 0.8)
    warningBackdrop:SetEdgeTexture("", 1, 1, 1)
    warningBackdrop:SetHidden(true)
    warningBackdrop:SetDrawLevel(0)

    warningControl:SetMovable(true)
    warningControl:SetMouseEnabled(false)
    -- 当たり判定を広げる（見た目より周囲30pxほど大きく反応させる）
    if warningControl.SetHitInsets then warningControl:SetHitInsets(-30, -30, 30, 30) end

    -- 子コントロール（文字・枠）上でクリックしても親ウィンドウを動かせるように、同じ処理を全てに設定する
    local function AttachDrag(ctrl)
        ctrl:SetHandler("OnMouseDown", function(_, button)
            if button == MOUSE_BUTTON_INDEX_LEFT and warningPreview then
                warningControl:StartMoving()
            end
        end)
        ctrl:SetHandler("OnMouseUp", function()
            warningControl:StopMovingOrResizing()
        end)
    end
    AttachDrag(warningControl)
    AttachDrag(warningBackdrop)
    AttachDrag(warningLabel)
    warningControl:SetHandler("OnMoveStop", function()
        local cx = warningControl:GetLeft() + warningControl:GetWidth() / 2
        local cy = warningControl:GetTop() + warningControl:GetHeight() / 2
        sv.warnX = zo_round(cx - GuiRoot:GetWidth() / 2)
        sv.warnY = zo_round(cy - GuiRoot:GetHeight() / 2)
        warningControl:ClearAnchors()
        warningControl:SetAnchor(CENTER, GuiRoot, CENTER, sv.warnX, sv.warnY)
    end)
end

local function ShowWarningPreview()
    if not warningControl then return end
    warningGeneration = warningGeneration + 1
    local myGeneration = warningGeneration
    warningControl:SetHidden(false)
    zo_callLater(function()
        if myGeneration == warningGeneration then
            warningControl:SetHidden(true)
        end
    end, 3000)
end

local function ApplyWarningPos(preview)
    if not warningControl then return end
    warningControl:ClearAnchors()
    warningControl:SetAnchor(CENTER, GuiRoot, CENTER, sv.warnX, sv.warnY)
    if preview and not warningPreview then ShowWarningPreview() end
end

local UpdateWarning

local function SetWarningPreview(on)
    warningPreview = on and true or false
    if not warningControl then return end
    warningGeneration = warningGeneration + 1 -- 予約済みの自動非表示を無効化
    warningControl:SetMouseEnabled(warningPreview)
    warningBackdrop:SetMouseEnabled(warningPreview)
    warningLabel:SetMouseEnabled(warningPreview)
    warningBackdrop:SetHidden(not warningPreview)
    if warningPreview then
        warningControl:SetHidden(false)
    else
        warningControl:SetHidden(true)
        UpdateWarning()
    end
end

function UpdateWarning()
    if warningPreview then return end -- プレビューモード中は常時表示のまま
    local shouldWarn = isOverloadActive and sv.warnEnabled and currentUltimate < sv.warnThreshold

    if shouldWarn then
        if warningControl:IsHidden() then
            -- 新規発生時のみ表示を開始し、指定秒数後に自動で消す
            warningGeneration = warningGeneration + 1
            local myGeneration = warningGeneration
            warningControl:SetHidden(false)
            zo_callLater(function()
                if myGeneration == warningGeneration then
                    warningControl:SetHidden(true)
                end
            end, sv.warnDuration * 1000)
        end
    else
        warningGeneration = warningGeneration + 1 -- 予約済みの自動非表示タイマーを無効化
        warningControl:SetHidden(true)
    end
end

-- ============================================================
-- メニュー（インベントリ・マップ等）表示中の検知
-- ============================================================
local isInMenu = false

-- ============================================================
-- スキルバー上のウルト枠の検知
-- ============================================================
-- クライアント言語によってバフ名（effectName）が翻訳されてしまい、
-- 文字列 "Overload" と一致しないケースがあるため、
-- 実機で確認済みのアビリティID・アイコン画像パスで判定する
-- （どちらもゲーム内部の識別子/ファイル名なので言語設定に依存しない）。
local ULTIMATE_SLOT_FRONT = 8
local ULTIMATE_SLOT_BACK = 18

-- 実機確認済みのオーバーロード（本体・両モーフ）のアビリティID
local KNOWN_OVERLOAD_ABILITY_IDS = {
    [24806] = true,
}

local function GetSlottedUltimateIds()
    local id1 = GetSlotBoundId(ULTIMATE_SLOT_FRONT)
    local id2 = GetSlotBoundId(ULTIMATE_SLOT_BACK)
    return id1, id2
end

-- 実際にオーバーロード発動が確認できたアイコン画像パス／アビリティIDを記憶する
local function RememberOverloadIcon(iconPath, abilityId)
    if iconPath and iconPath ~= "" then
        sv.knownIconPaths[iconPath] = true
    end
    if abilityId and abilityId ~= 0 then
        KNOWN_OVERLOAD_ABILITY_IDS[abilityId] = true
    end
end

-- 現在スロットにセットされているウルトが、確認済みのオーバーロードのアイコン／IDと一致するか判定する。
local function IsOverloadCurrentlySlotted()
    local id1, id2 = GetSlottedUltimateIds()
    if KNOWN_OVERLOAD_ABILITY_IDS[id1] or KNOWN_OVERLOAD_ABILITY_IDS[id2] then
        return true
    end

    local tex1 = GetSlotTexture(ULTIMATE_SLOT_FRONT)
    local tex2 = GetSlotTexture(ULTIMATE_SLOT_BACK)
    return (tex1 and sv.knownIconPaths[tex1]) or (tex2 and sv.knownIconPaths[tex2]) or false
end

-- 発動したバフのアビリティIDが「確認済みのオーバーロードのID」、または
-- 「発動元のスロット（表裏どちらか、一致した方）自体が確認済みのオーバーロードのアイコンである」場合のみ許可する。
-- （表裏で別々のウルトをセットしている場合に、片方だけがオーバーロードでも誤って
-- 一致してしまわないよう、発動元のスロットだけを見る）
local function IsOverloadAbilityId(abilityId)
    if not abilityId or abilityId == 0 then return false end
    if KNOWN_OVERLOAD_ABILITY_IDS[abilityId] then return true end

    local id1, id2 = GetSlottedUltimateIds()
    if abilityId == id1 then
        local tex1 = GetSlotTexture(ULTIMATE_SLOT_FRONT)
        return (tex1 and sv.knownIconPaths[tex1]) or false
    elseif abilityId == id2 then
        local tex2 = GetSlotTexture(ULTIMATE_SLOT_BACK)
        return (tex2 and sv.knownIconPaths[tex2]) or false
    end
    return false
end

-- 保険として、英語クライアントなど名前で判定できる場合のフォールバックも残す
local function IsOverloadBuffName(buffName)
    if not buffName then return false end
    return string.find(buffName, "Overload") ~= nil
end

-- ============================================================
-- 見た目の更新
-- ============================================================
local function UpdateVisual()
    iconTexture:SetTexture(currentIconPath)
    redOverlayTexture:SetTexture(currentIconPath)

    local baseHidden
    if isOverloadActive then
        iconTexture:SetColor(1, 1, 1, 1) -- 元アイコンの色そのまま
        redOverlayTexture:SetColor(0.9, 0, 0, 0.85) -- 加算合成で強く赤く染める（点灯）
        StartPulse()
        baseHidden = false
    else
        StopPulse()
        glowTexture:SetColor(1, 1, 1, 0) -- 光を消す
        outerGlowTexture:SetColor(1, 1, 1, 0)
        redOverlayTexture:SetColor(1, 1, 1, 0) -- 赤染めを消す

        if sv.hideWhenOff then
            baseHidden = true
        else
            baseHidden = false
            iconTexture:SetColor(0.4, 0.22, 0.22, 0.75) -- 「消灯」（赤みがかったグレーアウト）
        end
    end

    -- ロックを解除している間（位置調整中）は、カーソルモード等で隠れないようにする
    -- また、そもそも現在のスキルバーにオーバーロードがセットされていない場合は常に隠す
    local notSlotted = sv.slottedOnly and not IsOverloadCurrentlySlotted()
    topLevel:SetHidden(baseHidden or (sv.hideInMenu and isInMenu and sv.locked) or notSlotted)
end

local function RegisterMenuVisibilityHooks()
    if not HUD_SCENE then return end
    HUD_SCENE:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWN then
            isInMenu = false
            UpdateVisual()
        elseif newState == SCENE_HIDDEN then
            isInMenu = true
            UpdateVisual()
        end
    end)
end

local function SetOverloadActive(active)
    if isOverloadActive == active then return end
    isOverloadActive = active
    UpdateVisual()
    UpdateWarning()
end

local function OnPowerUpdate(eventCode, unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)
    if unitTag ~= "player" then return end
    if powerType ~= POWERTYPE_ULTIMATE then return end
    currentUltimate = powerValue
    if not isOverloadActive then
        UpdateVisual()
    end
    UpdateWarning()
end

-- ============================================================
-- バフ検知
-- ============================================================
local function OnEffectChanged(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId)
    if unitTag ~= "player" then return end
    if not (IsOverloadAbilityId(abilityId) or IsOverloadBuffName(effectName)) then return end

    if iconName and iconName ~= "" then
        currentIconPath = iconName
        RememberOverloadIcon(iconName, abilityId)
    end

    if changeType == EFFECT_RESULT_FADED then
        SetOverloadActive(false)
    else -- EFFECT_RESULT_GAINED または EFFECT_RESULT_UPDATED
        SetOverloadActive(true)
    end
end

-- UIリロード直後など、既にオーバーロードが有効な状態から始まるケースに対応
local function CheckInitialState()
    currentUltimate = GetUnitPower("player", POWERTYPE_ULTIMATE)

    local active = false
    local numBuffs = GetNumBuffs("player")
    for i = 1, numBuffs do
        local buffName, _, _, _, _, iconFilename, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
        if IsOverloadAbilityId(abilityId) or IsOverloadBuffName(buffName) then
            if iconFilename and iconFilename ~= "" then
                currentIconPath = iconFilename
                RememberOverloadIcon(iconFilename, abilityId)
            end
            active = true
            break
        end
    end

    -- SetOverloadActive は「状態が変化した時だけ」しか見た目を更新しないため、
    -- 起動直後の最初の描画はここで確実に行う
    isOverloadActive = active
    UpdateVisual()
    UpdateWarning()
end

-- ============================================================
-- スラッシュコマンド
-- ============================================================
local function RegisterSlashCommands()
    SLASH_COMMANDS["/overload"] = function(args)
        args = string.lower(args or "")
        if args == "lock" then
            sv.locked = true
            UpdateVisual()
            Say(L("msgLock"))
        elseif args == "unlock" then
            sv.locked = false
            UpdateVisual()
            Say(L("msgUnlock"))
        elseif args == "hide" then
            sv.hideWhenOff = true
            UpdateVisual()
            Say(L("msgHide"))
        elseif args == "show" then
            sv.hideWhenOff = false
            UpdateVisual()
            Say(L("msgShow"))
        elseif args == "slotonly on" then
            sv.slottedOnly = true
            UpdateVisual()
            Say(L("msgSlotOnlyOn"))
        elseif args == "slotonly off" then
            sv.slottedOnly = false
            UpdateVisual()
            Say(L("msgSlotOnlyOff"))
        elseif args == "menuhide on" then
            sv.hideInMenu = true
            UpdateVisual()
            Say(L("msgMenuHideOn"))
        elseif args == "menuhide off" then
            sv.hideInMenu = false
            UpdateVisual()
            Say(L("msgMenuHideOff"))
        elseif args == "reset" then
            SetPosition(defaults.x, defaults.y)
            Say(L("msgReset"))
        elseif string.match(args, "^moveto%s+-?%d+%s+-?%d+$") then
            local x, y = string.match(args, "^moveto%s+(-?%d+)%s+(-?%d+)$")
            SetPosition(tonumber(x), tonumber(y))
            Say(string.format(L("msgMoveTo"), x, y))
        elseif string.match(args, "^move%s+-?%d+%s+-?%d+$") then
            local dx, dy = string.match(args, "^move%s+(-?%d+)%s+(-?%d+)$")
            SetPosition(sv.x + tonumber(dx), sv.y + tonumber(dy))
            Say(string.format(L("msgMoved"), sv.x, sv.y))
        elseif args == "warn on" then
            sv.warnEnabled = true
            UpdateWarning()
            Say(L("msgWarnOn"))
        elseif args == "warn off" then
            sv.warnEnabled = false
            UpdateWarning()
            Say(L("msgWarnOff"))
        elseif string.match(args, "^warnat%s+%d+$") then
            local value = tonumber(string.match(args, "%d+"))
            sv.warnThreshold = value
            UpdateWarning()
            Say(string.format(L("msgWarnAt"), value))
        elseif string.match(args, "^warndur%s+%d+$") then
            local value = tonumber(string.match(args, "%d+"))
            if value < 3 then value = 3 elseif value > 30 then value = 30 end
            sv.warnDuration = value
            Say(string.format(L("msgWarnDur"), value))
        elseif string.match(args, "^warnpos%s+%-?%d+%s+%-?%d+$") then
            local px, py = string.match(args, "^warnpos%s+(%-?%d+)%s+(%-?%d+)$")
            sv.warnX, sv.warnY = tonumber(px), tonumber(py)
            ApplyWarningPos(true)
            Say(string.format(L("msgWarnPos"), sv.warnX, sv.warnY))
        elseif args == "warnpreview" or args == "warnpreview on" or args == "warnpreview off" then
            local on
            if args == "warnpreview on" then on = true
            elseif args == "warnpreview off" then on = false
            else on = not warningPreview end
            SetWarningPreview(on)
            Say(L(on and "msgPreviewOn" or "msgPreviewOff"))
        elseif string.match(args, "^lang%s+%a+$") then
            local v = string.match(args, "^lang%s+(%a+)$")
            if v == "ja" or v == "en" or v == "auto" then
                sv.language = v
                Say(string.format(L("msgLang"), v))
            end
        elseif args == "warntest" then
            ShowWarningPreview()
            Say(L("msgWarnTest"))
        elseif string.match(args, "^size%s+%d+$") then
            local value = tonumber(string.match(args, "%d+"))
            if value < 32 then value = 32 elseif value > 160 then value = 160 end
            sv.iconSize = value
            ApplyIconSize()
            Say(string.format(L("msgSize"), value))
        elseif args == "debug" then
            local id1, id2 = GetSlottedUltimateIds()
            Say("locked=" .. tostring(sv.locked)
                .. " hideWhenOff=" .. tostring(sv.hideWhenOff)
                .. " slottedOnly=" .. tostring(sv.slottedOnly)
                .. " hideInMenu=" .. tostring(sv.hideInMenu)
                .. " active=" .. tostring(isOverloadActive)
                .. " ultimate=" .. tostring(currentUltimate))
            Say("point=" .. tostring(sv.point)
                .. " relPoint=" .. tostring(sv.relPoint)
                .. " x=" .. tostring(sv.x) .. " y=" .. tostring(sv.y))
            Say("front ultimate slot id=" .. tostring(id1)
                .. " back ultimate slot id=" .. tostring(id2))
            Say("slotted=" .. tostring(IsOverloadCurrentlySlotted()))
        else
            Say(L("helpTitle"))
            d("  /overload lock   - " .. L("helpLock"))
            d("  /overload unlock - " .. L("helpUnlock"))
            d("  /overload hide   - " .. L("helpHide"))
            d("  /overload show   - " .. L("helpShow"))
            d("  /overload slotonly on/off - " .. L("helpSlotOnly"))
            d("  /overload menuhide on/off - " .. L("helpMenuHide"))
            d("  /overload reset  - " .. L("helpReset"))
            d("  /overload moveto x y - " .. L("helpMoveTo"))
            d("  /overload move dx dy - " .. L("helpMove"))
            d("  /overload warn on/off - " .. L("helpWarn"))
            d("  /overload warnat <n> - " .. L("helpWarnAt"))
            d("  /overload warndur <sec> - " .. L("helpWarnDur"))
            d("  /overload warnpos x y - " .. L("helpWarnPos"))
            d("  /overload warnpreview - " .. L("helpPreview"))
            d("  /overload lang ja|en|auto - " .. L("helpLang"))
            d("  /overload warntest - " .. L("helpWarnTest"))
            d("  /overload size <n> - " .. L("helpSize"))
            d("  /overload debug  - " .. L("helpDebug"))
        end
    end
end

-- ============================================================
-- LibAddonMenu-2.0 設定パネル（導入されていれば表示される）
-- ============================================================
local function CreateSettingsMenu()
    local LAM = LibAddonMenu2
    if not LAM then return end -- LibAddonMenuが無ければ何もしない（スラッシュコマンドのみ使用可）

    local panelData = {
        type = "panel",
        name = "Overload Indicator",
        displayName = "Overload Indicator",
        author = "PUYO",
        version = ADDON_VERSION,
        registerForRefresh = true,
        registerForDefaults = true,
    }
    LAM:RegisterAddonPanel(ADDON_NAME .. "Options", panelData)

    local optionsData = {
        {
            type = "description",
            text = L("menuDescription"),
        },
        {
            type = "checkbox",
            name = L("menuLockName"),
            tooltip = L("menuLockTip"),
            getFunc = function() return sv.locked end,
            setFunc = function(value)
                sv.locked = value
                UpdateVisual()
            end,
            default = defaults.locked,
        },
        {
            type = "checkbox",
            name = L("menuHideOffName"),
            tooltip = L("menuHideOffTip"),
            getFunc = function() return sv.hideWhenOff end,
            setFunc = function(value)
                sv.hideWhenOff = value
                UpdateVisual()
            end,
            default = defaults.hideWhenOff,
        },
        {
            type = "checkbox",
            name = L("menuSlotOnlyName"),
            tooltip = L("menuSlotOnlyTip"),
            getFunc = function() return sv.slottedOnly end,
            setFunc = function(value)
                sv.slottedOnly = value
                UpdateVisual()
            end,
            default = defaults.slottedOnly,
        },
        {
            type = "checkbox",
            name = L("menuMenuHideName"),
            tooltip = L("menuMenuHideTip"),
            getFunc = function() return sv.hideInMenu end,
            setFunc = function(value)
                sv.hideInMenu = value
                UpdateVisual()
            end,
            default = defaults.hideInMenu,
        },
        {
            type = "checkbox",
            name = L("menuWarnName"),
            tooltip = L("menuWarnTip"),
            getFunc = function() return sv.warnEnabled end,
            setFunc = function(value)
                sv.warnEnabled = value
                UpdateWarning()
            end,
            default = defaults.warnEnabled,
        },
        {
            type = "slider",
            name = L("menuWarnAtName"),
            tooltip = L("menuWarnAtTip"),
            min = 0,
            max = 500,
            step = 1,
            getFunc = function() return sv.warnThreshold end,
            setFunc = function(value)
                sv.warnThreshold = value
                UpdateWarning()
            end,
            default = defaults.warnThreshold,
        },
        {
            type = "slider",
            name = L("menuWarnDurName"),
            tooltip = L("menuWarnDurTip"),
            min = 3,
            max = 30,
            step = 1,
            getFunc = function() return sv.warnDuration end,
            setFunc = function(value)
                sv.warnDuration = value
            end,
            default = defaults.warnDuration,
        },
        {
            type = "checkbox",
            name = L("menuPreviewName"),
            tooltip = L("menuPreviewTip"),
            getFunc = function() return warningPreview end,
            setFunc = function(value) SetWarningPreview(value) end,
            default = false,
        },
        {
            type = "slider",
            name = L("menuWarnXName"),
            tooltip = L("menuWarnPosTip"),
            min = -1000,
            max = 1000,
            step = 10,
            getFunc = function() return sv.warnX end,
            setFunc = function(value)
                sv.warnX = value
                ApplyWarningPos(true)
            end,
            default = defaults.warnX,
        },
        {
            type = "slider",
            name = L("menuWarnYName"),
            tooltip = L("menuWarnPosTip"),
            min = -600,
            max = 600,
            step = 10,
            getFunc = function() return sv.warnY end,
            setFunc = function(value)
                sv.warnY = value
                ApplyWarningPos(true)
            end,
            default = defaults.warnY,
        },
        {
            type = "slider",
            name = L("menuSizeName"),
            tooltip = L("menuSizeTip"),
            min = 32,
            max = 160,
            step = 4,
            getFunc = function() return sv.iconSize end,
            setFunc = function(value)
                sv.iconSize = value
                ApplyIconSize()
            end,
            default = defaults.iconSize,
        },
        {
            type = "slider",
            name = L("menuScaleName"),
            min = 50,
            max = 200,
            step = 5,
            getFunc = function() return sv.scale * 100 end,
            setFunc = function(value)
                sv.scale = value / 100
                topLevel:SetScale(sv.scale)
            end,
            default = defaults.scale * 100,
        },
        {
            type = "button",
            name = L("menuResetPosName"),
            func = function()
                SetPosition(defaults.x, defaults.y)
            end,
        },
    }
    LAM:RegisterOptionControls(ADDON_NAME .. "Options", optionsData)
end

-- ============================================================
-- 初期化
-- ============================================================
local function OnAddOnLoaded(event, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    -- ZO_SavedVars（ESO公式の保存機構）に置き換え。
    -- 自前のテーブル＋メタテーブル方式だと保存タイミング等で不具合が起きうるため、
    -- 標準ライブラリに任せることで確実に永続化する。
    sv = ZO_SavedVars:NewAccountWide("OverloadIndicator_SV", 1, nil, defaults, GetWorldName())
    langSv = sv

    -- 過去バージョンで保存された不正な値（例: 文字列の "CENTER"）が残っていた場合に備え、
    -- アンカー関連の値は型を検証し、不正なら初期値に戻す（自己修復）
    if type(sv.point) ~= "number" then sv.point = defaults.point end
    if type(sv.relPoint) ~= "number" then sv.relPoint = defaults.relPoint end
    if type(sv.x) ~= "number" then sv.x = defaults.x end
    if type(sv.y) ~= "number" then sv.y = defaults.y end
    if type(sv.warnX) ~= "number" then sv.warnX = 0 end
    if type(sv.warnY) ~= "number" then sv.warnY = 0 end

    -- 過去のバグで誤って別のアビリティのアイコンが「確認済みのオーバーロード」として
    -- 保存されてしまっている可能性があるため、実機確認済みの3種類だけにリセットする
    sv.knownIconPaths = {
        ["/esoui/art/icons/ability_sorcerer_overload.dds"] = true,
        ["/esoui/art/icons/ability_sorcerer_power_overload.dds"] = true,
        ["/esoui/art/icons/ability_sorcerer_energy_overload.dds"] = true,
    }

    CreateUI()
    CreateWarningUI()
    ApplyIconSize()
    topLevel:SetScale(sv.scale)
    topLevel:ClearAnchors()
    topLevel:SetAnchor(sv.point, GuiRoot, sv.relPoint, sv.x, sv.y)
    UpdateVisual() -- 初期状態が確定するまでの間も、とりあえず正しい見た目にしておく
    UpdateWarning()

    RegisterSlashCommands()
    RegisterMenuVisibilityHooks()

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_EFFECT_CHANGED, OnEffectChanged)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME, EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_UNIT_TAG_PREFIX, "player")

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Power", EVENT_POWER_UPDATE, OnPowerUpdate)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "Power", EVENT_POWER_UPDATE,
        REGISTER_FILTER_UNIT_TAG_PREFIX, "player",
        REGISTER_FILTER_POWER_TYPE, POWERTYPE_ULTIMATE)

    -- 武器切り替え・スキルバー編成変更などでウルト枠の中身が変わった時に表示を更新する
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "SlotUpdated", EVENT_ACTION_SLOT_UPDATED, function(eventCode, slotNum)
        if slotNum == ULTIMATE_SLOT_FRONT or slotNum == ULTIMATE_SLOT_BACK then
            UpdateVisual()
        end
    end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "HotbarSwap", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, function()
        UpdateVisual()
    end)

    -- プレイヤー準備完了後に初期状態をチェック（既にオーバーロード中でUIリロードした場合など）
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "PlayerActivated", EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "PlayerActivated", EVENT_PLAYER_ACTIVATED)
        CheckInitialState()
        CreateSettingsMenu() -- 言語判定が確実になるプレイヤー準備完了後にメニューを作成
    end)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
