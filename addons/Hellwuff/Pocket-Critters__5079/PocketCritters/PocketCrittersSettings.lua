local PP = PocketCritters
local unpack = unpack or table.unpack

local CARDS_PER_ROW = 3
local CARD_ROW_STEP = 92
local SHIFT = CARD_ROW_STEP
local GROW = 80
local W, H = 400, 590 + SHIFT + GROW
local PANEL_V = 873 / 1024
local UI_TEX = "PocketCritters/textures/ui.dds"
local PANEL_TEX = "PocketCritters/textures/panel.dds"
local SKIN_TEX = "PocketCritters/textures/critter_%s.dds"

local CREAM = { 1, 0.94, 0.9, 1 }
local PINK = { 1, 0.66, 0.82, 1 }
local SOFT = { 0.86, 0.76, 0.86, 1 }

local SKIN_NAMES = { hellwuff = "Hellwuff", tsardarashi = "Tsardarashi", hisani = "Hisani", azsu = "Azsu", tsaji = "Tsaji", brown = "Cocoa" }
local MOODS = {
    { "idle", "Idle" }, { "wag", "Wag" }, { "zoomies", "Zoomies" }, { "pat", "Pat" },
    { "sleep", "Nap" }, { "hide", "Hide" }, { "sad", "Sad" }, { "alert", "Alert" },
}

local ui = nil
local refreshing = false
local nameCounter = 0

local function Name(suffix)
    nameCounter = nameCounter + 1
    return "PocketCrittersSettings" .. suffix .. nameCounter
end

local function UiCell(tex, col, row)
    tex:SetTexture(UI_TEX)
    tex:SetTextureCoords(col * 0.5, (col + 1) * 0.5, row * 0.5, (row + 1) * 0.5)
end

local function Label(parent, text, font, color, align)
    local l = WINDOW_MANAGER:CreateControl(Name("Label"), parent, CT_LABEL)
    l:SetFont(font or "ZoFontGame")
    l:SetDrawLayer(DL_TEXT)
    l:SetColor(unpack(color or CREAM))
    l:SetText(text or "")
    if align then l:SetHorizontalAlignment(align) end
    return l
end

local function Divider(parent, y)
    local t = WINDOW_MANAGER:CreateControl(Name("Divider"), parent, CT_TEXTURE)
    UiCell(t, 1, 1)
    t:SetDimensions(W - 80, 16)
    t:SetDrawLayer(DL_CONTROLS)
    t:SetAnchor(TOP, parent, TOP, 0, y)
    return t
end

local function SectionTitle(parent, text, y)
    local l = Label(parent, text, "ZoFontWinH4", PINK)
    l:SetAnchor(TOPLEFT, parent, TOPLEFT, 34, y)
    return l
end

local function Button(parent, text, w, onClick)
    local b = WINDOW_MANAGER:CreateControlFromVirtual(Name("Button"), parent, "ZO_DefaultButton")
    b:SetDimensions(w, 28)
    b:SetText(text)
    b:SetHandler("OnClicked", onClick)
    return b
end

local function Checkbox(parent, text, y, onToggle)
    local c = WINDOW_MANAGER:CreateControlFromVirtual(Name("Check"), parent, "ZO_CheckButton")
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, 40, y)
    ZO_CheckButton_SetLabelText(c, text)
    ZO_CheckButton_SetToggleFunction(c, function(_, checked)
        if not refreshing then onToggle(checked) end
    end)
    return c
end

local function Slider(parent, title, y, minV, maxV, step, onChange)
    local l = Label(parent, title, "ZoFontGame", CREAM)
    l:SetAnchor(TOPLEFT, parent, TOPLEFT, 40, y)
    local s = WINDOW_MANAGER:CreateControlFromVirtual(Name("Slider"), parent, "ZO_Slider")
    s:SetDimensions(170, 16)
    s:SetAnchor(TOPLEFT, parent, TOPLEFT, 140, y + 5)
    s:SetMinMax(minV, maxV)
    s:SetValueStep(step)
    s:SetMouseEnabled(true)
    local v = Label(parent, "", "ZoFontGame", PINK)
    v:SetAnchor(TOPLEFT, parent, TOPLEFT, 322, y)
    s:SetHandler("OnValueChanged", function(_, value)
        if not refreshing then onChange(value) end
        if ui then ui.refreshValues() end
    end)
    return s, v
end

local function NapText(seconds)
    if seconds < 60 then return seconds .. " sec" end
    local m = seconds / 60
    if m == math.floor(m) then return m .. " min" end
    return string.format("%.1f min", m)
end

local function Build()
    local wm = WINDOW_MANAGER
    local win = wm:CreateTopLevelWindow("PocketCrittersSettingsWindow")
    win:SetDimensions(W, H)
    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, -40)
    win:SetHidden(true)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)

    local bg = wm:CreateControl("PocketCrittersSettingsWindowBG", win, CT_TEXTURE)
    bg:SetTexture(PANEL_TEX)
    bg:SetTextureCoords(0, 1, 0, PANEL_V)
    bg:SetAnchorFill(win)
    bg:SetDrawLayer(DL_BACKGROUND)
    bg:SetDrawLevel(0)

    ui = { win = win, cards = {} }

    local title = Label(win, "Pocket Critters", "ZoFontWinH2", CREAM, TEXT_ALIGN_CENTER)
    title:SetAnchor(TOP, win, TOP, 0, 22)
    for side = -1, 1, 2 do
        local p = wm:CreateControl(Name("Paw"), win, CT_TEXTURE)
        UiCell(p, 0, 1)
        p:SetDimensions(28, 28)
        p:SetDrawLayer(DL_CONTROLS)
        p:SetAnchor(side < 0 and RIGHT or LEFT, title, side < 0 and LEFT or RIGHT, side * 8, 0)
    end
    ui.pats = Label(win, "", "ZoFontGameSmall", SOFT, TEXT_ALIGN_CENTER)
    ui.pats:SetAnchor(TOP, title, BOTTOM, 0, 2)

    local close = wm:CreateControl(Name("Close"), win, CT_BUTTON)
    close:SetDimensions(32, 32)
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -16, 16)
    close:SetNormalTexture("EsoUI/Art/Buttons/closebutton_up.dds")
    close:SetPressedTexture("EsoUI/Art/Buttons/closebutton_down.dds")
    close:SetMouseOverTexture("EsoUI/Art/Buttons/closebutton_mouseover.dds")
    close:SetHandler("OnClicked", function() SCENE_MANAGER:HideTopLevel(win) end)

    SectionTitle(win, "Pick a look", 84)
    local cardSize, gap = 66, 26
    local startX = (W - (CARDS_PER_ROW * cardSize + (CARDS_PER_ROW - 1) * gap)) / 2
    for i, skin in ipairs(PP.SKINS) do
        local col = (i - 1) % CARDS_PER_ROW
        local row = math.floor((i - 1) / CARDS_PER_ROW)
        local x = startX + col * (cardSize + gap)
        local y = 112 + row * CARD_ROW_STEP
        local card = wm:CreateControl(Name("Card"), win, CT_TEXTURE)
        UiCell(card, 0, 0)
        card:SetDimensions(cardSize, cardSize)
        card:SetAnchor(TOPLEFT, win, TOPLEFT, x, y)
        card:SetDrawLayer(DL_CONTROLS)
        card:SetDrawLevel(1)

        local face = wm:CreateControl(Name("Face"), win, CT_TEXTURE)
        face:SetTexture(string.format(SKIN_TEX, skin))
        face:SetTextureCoords(0.25, 0.5, 0, 0.125)
        face:SetDimensions(cardSize - 6, cardSize - 6)
        face:SetAnchor(CENTER, card, CENTER, 0, 1)
        face:SetDrawLayer(DL_CONTROLS)
        face:SetDrawLevel(2)

        local pick = wm:CreateControl(Name("Pick"), win, CT_BUTTON)
        pick:SetDimensions(cardSize, cardSize)
        pick:SetAnchor(CENTER, card, CENTER, 0, 0)
        pick:SetMouseEnabled(true)
        pick:SetDrawLayer(DL_CONTROLS)
        pick:SetDrawLevel(3)
        pick:SetHandler("OnClicked", function()
            PP.SetSkin(skin)
            PP.TestMood("wag")
            PP.RefreshSettings()
            PlaySound(SOUNDS.DEFAULT_CLICK)
            d("|cFF8FC8[Pocket Critters]|r New look: " .. (SKIN_NAMES[skin] or skin) .. "!")
        end)

        pick:SetHandler("OnMouseEnter", function() face:SetScale(1.08) end)
        pick:SetHandler("OnMouseExit", function() face:SetScale(1) end)

        local name = Label(win, SKIN_NAMES[skin] or skin, "ZoFontGameSmall", SOFT, TEXT_ALIGN_CENTER)
        name:SetAnchor(TOP, card, BOTTOM, 0, 2)

        ui.cards[skin] = { card = card, name = name, pick = pick }
    end

    Divider(win, 214 + SHIFT)

    SectionTitle(win, "Scale & naps", 228 + SHIFT)
    ui.scale, ui.scaleValue = Slider(win, "Scale", 260 + SHIFT, 50, 300, 5, function(v) PP.SetScale(v) end)
    ui.nap, ui.napValue = Slider(win, "Nap after", 292 + SHIFT, 10, 600, 10, function(v) PP.SetNap(v) end)

    Divider(win, 326 + SHIFT)

    SectionTitle(win, "Manners", 340 + SHIFT)
    ui.shown = Checkbox(win, "Show my critter", 372 + SHIFT, function(on) PP.SetShown(on) end)
    ui.locked = Checkbox(win, "Stay put (no dragging)", 398 + SHIFT, function(on) PP.SetLocked(on) end)
    ui.wag = Checkbox(win, "Wag at every bit of loot", 424 + SHIFT, function(on) PP.SetQuiet(not on) end)
    ui.peek = Checkbox(win, "Peek over the inventory", 450 + SHIFT, function(on) if PP.SetPeek then PP.SetPeek(on) end end)

    local nudges = { { "higher", "Higher" }, { "lower", "Lower" }, { "left", "Left" }, { "right", "Right" }, { "reset", "Reset" } }
    local nw, ngap = 60, 6
    local nx = (W - (#nudges * nw + (#nudges - 1) * ngap)) / 2
    for i, n in ipairs(nudges) do
        local b = Button(win, n[2], nw, function() if PP.PeekNudge then PP.PeekNudge(n[1]) end end)
        b:SetAnchor(TOPLEFT, win, TOPLEFT, nx + (i - 1) * (nw + ngap), 478 + SHIFT)
    end
    ui.peekSpot = Label(win, "", "ZoFontGameSmall", SOFT, TEXT_ALIGN_CENTER)
    ui.peekSpot:SetAnchor(TOP, win, TOP, 0, 510 + SHIFT)

    local reset = Button(win, "Come back!", 120, function()
        PP.ResetPosition()
        PP.TestMood("zoomies")
    end)
    reset:SetAnchor(TOPRIGHT, win, TOPRIGHT, -34, 368 + SHIFT)

    ui.fetch = Button(win, "Start fetch", 120, function() PP.ToggleFetchMode() end)
    ui.fetch:SetAnchor(TOPRIGHT, win, TOPRIGHT, -34, 402 + SHIFT)

    Divider(win, 452 + SHIFT + GROW)

    SectionTitle(win, "Try a mood", 464 + SHIFT + GROW)
    local bw, bgap = 78, 6
    local bx = (W - (4 * bw + 3 * bgap)) / 2
    for i, m in ipairs(MOODS) do
        local col = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        local b = Button(win, m[2], bw, function() PP.TestMood(m[1]) end)
        b:SetAnchor(TOPLEFT, win, TOPLEFT, bx + col * (bw + bgap), 492 + SHIFT + GROW + row * 30)
    end

    local tip = Label(win, "Tip: click your critter for pats, drag to move", "ZoFontGameSmall", SOFT, TEXT_ALIGN_CENTER)
    tip:SetAnchor(TOP, win, TOP, 0, 558 + SHIFT + GROW)

    function ui.refreshValues()
        local sv = PP.GetSettings()
        ui.scaleValue:SetText(sv.scale .. "%")
        ui.napValue:SetText(NapText(sv.sleepAfter))
    end

    SCENE_MANAGER:RegisterTopLevel(win, false)
end

function PP.RefreshSettings()
    if not ui then return end
    local sv = PP.GetSettings()
    refreshing = true
    for skin, c in pairs(ui.cards) do
        local selected = (skin == sv.skin)
        UiCell(c.card, selected and 1 or 0, 0)
        c.name:SetColor(unpack(selected and PINK or SOFT))
    end
    ui.scale:SetValue(sv.scale)
    ui.nap:SetValue(sv.sleepAfter)
    ZO_CheckButton_SetCheckState(ui.shown, not sv.hidden)
    ZO_CheckButton_SetCheckState(ui.locked, sv.locked)
    ZO_CheckButton_SetCheckState(ui.wag, not sv.quiet)
    ZO_CheckButton_SetCheckState(ui.peek, sv.peek ~= false)
    if ui.peekSpot and PP.PeekSpotText then ui.peekSpot:SetText("Peek spot: " .. PP.PeekSpotText()) end
    local pats = sv.pats or 0
    local fetches = sv.fetches or 0
    local patText = pats == 1 and "Patted once" or string.format("Patted %d times", pats)
    if fetches > 0 then
        ui.pats:SetText(patText .. (fetches == 1 and ", 1 fetch <3" or string.format(", %d fetches <3", fetches)))
    else
        ui.pats:SetText(patText .. " so far <3")
    end
    ui.fetch:SetText(PP.IsFetchMode() and "Stop fetch" or "Start fetch")
    ui.refreshValues()
    refreshing = false
end

function PP.ToggleSettings()
    if not ui then Build() end
    PP.RefreshSettings()
    SCENE_MANAGER:ToggleTopLevel(ui.win)
end
