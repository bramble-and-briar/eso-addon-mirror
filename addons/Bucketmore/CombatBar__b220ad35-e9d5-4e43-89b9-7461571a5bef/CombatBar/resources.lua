-- Combat Bar : HP・MP・STバー(自分のリソースのみ)
-- 値は EVENT_POWER_UPDATE (自分・該当リソースのみ) で変化した時だけ更新する。常時更新は行わない。
local CB = CombatBar
local WM = WINDOW_MANAGER
local EM = EVENT_MANAGER

local KINDS = { "hp", "mp", "st" }
local LABEL = { hp = "HP", mp = "MP", st = "ST" }

local bars = {}
local registeredKinds = {}

local function Font(size)
    return string.format("$(BOLD_FONT)|%d|soft-shadow-thick", size or 18)
end

---------------------------------------------------------------
-- 部品(実HUDと設定画面プレビューで共通)
---------------------------------------------------------------
function CB.BuildBarControls(parent, prefix)
    local b = {}
    b.body = WM:CreateControl(prefix .. "Body", parent, CT_CONTROL)
    b.body:SetAnchorFill(parent)

    b.glow = WM:CreateControl(prefix .. "Glow", b.body, CT_BACKDROP)
    b.glow:SetAnchor(TOPLEFT, b.body, TOPLEFT, -2, -2)
    b.glow:SetAnchor(BOTTOMRIGHT, b.body, BOTTOMRIGHT, 2, 2)
    b.glow:SetCenterColor(0, 0, 0, 0)

    b.bg = WM:CreateControl(prefix .. "Bg", b.body, CT_BACKDROP)
    b.bg:SetAnchorFill(b.body)

    b.fill = WM:CreateControl(prefix .. "Fill", b.body, CT_TEXTURE)
    b.fill:SetAnchor(TOPLEFT, b.body, TOPLEFT, 1, 1)

    b.label = WM:CreateControl(prefix .. "Label", b.body, CT_LABEL)
    b.label:SetAnchor(LEFT, b.body, LEFT, 6, 0)

    b.value = WM:CreateControl(prefix .. "Value", b.body, CT_LABEL)
    b.value:SetAnchor(RIGHT, b.body, RIGHT, -6, 0)
    return b
end

-- 見た目(サイズ・色・フォント・枠)を設定から反映
function CB.StyleBar(b, cfg, parent, labelText)
    local sv = CB.sv
    local theme = CB.Theme
    parent:SetDimensions(cfg.w, cfg.h)
    b.body:SetAlpha((cfg.alpha or 100) / 100)

    local bgc = cfg.bgColor
    b.bg:SetCenterColor(bgc[1], bgc[2], bgc[3], bgc[4] or 0.6)
    CB.SetFrame(b.bg, sv.designFrame, theme.gold, 1)

    local glowAlpha = ((sv.designGlow or 0) / 100) * 0.6
    local cy = theme.cyan
    CB.SetFrame(b.glow, sv.designFrame and glowAlpha > 0, { cy[1], cy[2], cy[3], glowAlpha }, 2)

    local c = cfg.color
    b.fill:SetColor(c[1], c[2], c[3], 1)

    b.label:SetFont(Font(cfg.fontSize))
    b.label:SetText(labelText or "")
    b.label:SetColor(theme.gold[1], theme.gold[2], theme.gold[3], 1)
    b.label:SetHidden(not cfg.showLabel)

    b.value:SetFont(Font(cfg.fontSize))
    b.value:SetColor(1, 1, 1, 1)
end

-- 値の反映。cur が nil(取得不可)の時は "--" とし、推測した値は出さない。
function CB.SetBarValues(b, cfg, cur, max)
    if not cur then
        b.fill:SetHidden(true)
        b.value:SetText("--")
        return
    end
    if max and max > 0 then
        local ratio = cur / max
        if ratio > 1 then ratio = 1 end
        if ratio < 0 then ratio = 0 end
        local w = zo_floor((cfg.w - 2) * ratio)
        if w < 1 then
            b.fill:SetHidden(true)
        else
            b.fill:SetDimensions(w, cfg.h - 2)
            b.fill:SetHidden(false)
        end
    else
        b.fill:SetHidden(true)
    end

    local text = ""
    if cfg.showValue then
        text = max and (cur .. " / " .. max) or tostring(cur)
    end
    if cfg.showPercent and max and max > 0 then
        local pct = string.format("%d%%", zo_floor(cur / max * 100 + 0.5))
        text = (text == "") and pct or (text .. "  " .. pct)
    end
    b.value:SetText(text)
end

---------------------------------------------------------------
-- 実HUD
---------------------------------------------------------------
function CB.CreateResourceBars()
    if next(bars) then return end
    for _, kind in ipairs(KINDS) do
        local name = "CB_Res_" .. kind
        local win = WM:CreateTopLevelWindow(name)
        win:SetMouseEnabled(false)
        win:SetDimensions(220, 22)
        local b = CB.BuildBarControls(win, name)
        b.win = win
        b.body:SetHidden(true)
        bars[kind] = b
        CB.AttachToHud(win)
    end
end

function CB.UpdateResource(kind)
    local b = bars[kind]
    local sv = CB.sv
    if not b or not sv or not sv.enabled then return end
    local cfg = sv.resources[kind]
    if not cfg.enabled then return end
    local cur, max = CB.GetResource(kind)
    CB.SetBarValues(b, cfg, cur, max)
end

function CB.UpdateAllResources()
    for _, kind in ipairs(KINDS) do CB.UpdateResource(kind) end
end

-- 表示中のバーに対応するイベントだけを登録する(重複登録なし)
function CB.SyncResourceEvents()
    local sv = CB.sv
    local mech = CB.resourceMech
    for _, kind in ipairs(KINDS) do
        local want = sv.enabled and sv.resources[kind].enabled and mech[kind] ~= nil
        local name = "CombatBarRes" .. kind
        if want and not registeredKinds[kind] then
            EM:RegisterForEvent(name, EVENT_POWER_UPDATE, function() CB.UpdateResource(kind) end)
            EM:AddFilterForEvent(name, EVENT_POWER_UPDATE,
                REGISTER_FILTER_POWER_TYPE, mech[kind],
                REGISTER_FILTER_UNIT_TAG, "player")
            registeredKinds[kind] = true
        elseif not want and registeredKinds[kind] then
            EM:UnregisterForEvent(name, EVENT_POWER_UPDATE)
            registeredKinds[kind] = false
        end
    end
end

-- 位置・見た目・表示状態を反映(設定変更時・ゾーン移動時)
function CB.ApplyResources()
    local sv = CB.sv
    if not sv or not next(bars) then return end
    local anchor = GetControl("ActionButton3")
    for _, kind in ipairs(KINDS) do
        local b = bars[kind]
        local cfg = sv.resources[kind]
        b.win:ClearAnchors()
        if anchor then
            -- 初期配置: アクションバー左側に縦並び(HP→MP→ST)
            b.win:SetAnchor(TOPRIGHT, anchor, TOPLEFT, cfg.x, cfg.y)
        else
            b.win:SetAnchor(TOPRIGHT, GuiRoot, BOTTOM, cfg.x - 100, cfg.y - 140)
        end
        CB.StyleBar(b, cfg, b.win, LABEL[kind])
        b.body:SetHidden(not (sv.enabled and cfg.enabled))
    end
    CB.SyncResourceEvents()
    CB.UpdateAllResources()
end

CB.ResourceKinds = KINDS
CB.ResourceLabel = LABEL
