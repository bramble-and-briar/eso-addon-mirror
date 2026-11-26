-- The brag card (/fct brag): the roster's best numbers on one screen, sized for a screenshot
-- to share on Discord. The numbers are put together in Core/Pages.lua; this file draws the card.
local CT = FurysCharacterTracker
local Brag = {}
CT.Brag = Brag

local COLS, ROWS = 4, 4
local TILE_W, TILE_H, GAP = 219, 104, 12

local T = CT.Theme                    -- Fury Night colors and fonts (UI/Theme.lua)
local VIOLET = T.RGB.VIOLET           -- the numbers and bars
local TEXT = T.RGB.TEXT
local DIM = T.RGB.MUTED

local function Label(name, parent, font, rgb)
    local label = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    label:SetFont(font)
    label:SetColor(rgb[1], rgb[2], rgb[3], 1)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    return label
end

function Brag:Build(classCount)
    if self.tiles then return end
    SCENE_MANAGER:RegisterTopLevel(FurysCharacterTracker_Brag, false)
    self.tiles = {}
    for i = 1, COLS * ROWS do
        local col, row = (i - 1) % COLS, zo_floor((i - 1) / COLS)
        local base = "FurysCharacterTracker_BragTile" .. i
        local tile = T.Rect(base, FurysCharacterTracker_BragTiles, T.STRIPE)
        tile:SetDimensions(TILE_W, TILE_H)
        tile:SetAnchor(TOPLEFT, FurysCharacterTracker_BragTiles, TOPLEFT, col * (TILE_W + GAP), row * (TILE_H + GAP))
        local edge = WINDOW_MANAGER:CreateControl(base .. "Edge", tile, CT_TEXTURE)
        edge:SetColor(VIOLET[1], VIOLET[2], VIOLET[3], 0.85)
        edge:SetDimensions(TILE_W, 2)
        edge:SetAnchor(TOPLEFT, tile, TOPLEFT, 0, 0)
        local value = Label(base .. "Value", tile, "ZoFontWinH1", VIOLET)
        value:SetDimensions(TILE_W - 12, 44)
        value:SetAnchor(TOP, tile, TOP, 0, 6)
        local label = Label(base .. "Label", tile, "ZoFontGameBold", TEXT)
        label:SetDimensions(TILE_W - 12, 22)
        label:SetAnchor(TOP, value, BOTTOM, 0, 2)
        local note = Label(base .. "Note", tile, "ZoFontGameSmall", DIM)
        note:SetDimensions(TILE_W - 12, 18)
        note:SetAnchor(TOP, label, BOTTOM, 0, 0)
        local pct = Label(base .. "Pct", tile, "ZoFontGameBold", VIOLET)
        pct:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        pct:SetDimensions(56, 18)
        pct:SetAnchor(BOTTOMRIGHT, tile, BOTTOMRIGHT, -8, -12)
        local track = WINDOW_MANAGER:CreateControl(base .. "Track", tile, CT_TEXTURE)
        T.Paint(track, T.HOVER)
        track:SetDimensions(TILE_W - 16, 4)
        track:SetAnchor(BOTTOMLEFT, tile, BOTTOMLEFT, 8, -6)
        local bar = WINDOW_MANAGER:CreateControl(base .. "Bar", tile, CT_TEXTURE)
        bar:SetColor(VIOLET[1], VIOLET[2], VIOLET[3], 1)
        bar:SetAnchor(BOTTOMLEFT, tile, BOTTOMLEFT, 8, -6)
        self.tiles[i] = { value = value, label = label, note = note, pct = pct, track = track, bar = bar }
    end
    FurysCharacterTracker_BragCoverageTitle:SetFont(T.FONT_SECTION)
    self.classes = {}
    local width = zo_floor(912 / classCount)
    for i = 1, classCount do
        local name = Label("FurysCharacterTracker_BragClass" .. i, FurysCharacterTracker_BragCoverage, "ZoFontGameBold", TEXT)
        name:SetDimensions(width - 6, 24)
        name:SetAnchor(TOPLEFT, FurysCharacterTracker_BragCoverage, TOPLEFT, (i - 1) * width, 0)
        local roles = Label("FurysCharacterTracker_BragClass" .. i .. "Roles", FurysCharacterTracker_BragCoverage, "ZoFontGameSmall", DIM)
        roles:SetDimensions(width - 6, 22)
        roles:SetAnchor(TOP, name, BOTTOM, 0, 2)
        self.classes[i] = { name = name, roles = roles }
    end
    local pos = CT.sv.bragWindow
    if pos then
        FurysCharacterTracker_Brag:ClearAnchors()
        FurysCharacterTracker_Brag:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.x, pos.y)
    end
end

function Brag.SavePosition()
    CT.sv.bragWindow = { x = FurysCharacterTracker_Brag:GetLeft(), y = FurysCharacterTracker_Brag:GetTop() }
end

function Brag:Refresh()
    local card = CT.Pages.Brag()
    self:Build(card.classCount)
    FurysCharacterTracker_BragTitle:SetText(card.title)
    FurysCharacterTracker_BragSubtitle:SetText(card.subtitle)

    for i, t in ipairs(card.tiles) do
        local tile = self.tiles[i]
        tile.value:SetText(t.value)
        tile.label:SetText(t.label)
        tile.note:SetText(t.note or "")
        local hasPct = t.pct ~= nil
        tile.note:ClearAnchors()
        if hasPct then
            tile.note:SetDimensions(TILE_W - 76, 18)
            tile.note:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
            tile.note:SetAnchor(TOPLEFT, tile.label, BOTTOMLEFT, 2, 0)
        else
            tile.note:SetDimensions(TILE_W - 12, 18)
            tile.note:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            tile.note:SetAnchor(TOP, tile.label, BOTTOM, 0, 0)
        end
        tile.pct:SetHidden(not hasPct)
        tile.track:SetHidden(not hasPct)
        tile.bar:SetHidden(not hasPct or t.pct <= 0)
        if hasPct then
            tile.pct:SetText(t.pctText)
            tile.bar:SetDimensions(math.max(1, (TILE_W - 16) * t.pct), 4)
        end
    end

    -- Class x role coverage: violet role = you have a character playing it.
    for i, slot in ipairs(self.classes) do
        local class = card.classes[i]
        if class then
            local parts = {}
            for r, role in ipairs(class.roles) do
                parts[r] = (role.on and "|cA08CFF" or "|c4A4670") .. role.key .. "|r"
            end
            slot.name:SetText(class.name)
            slot.roles:SetText(table.concat(parts, "  "))
        else
            slot.name:SetText("")
            slot.roles:SetText("")
        end
    end
    FurysCharacterTracker_BragCoverageTitle:SetText(card.coverageTitle)
    FurysCharacterTracker_BragFooterLeft:SetText(card.date)
    FurysCharacterTracker_BragFooter:SetText(card.credit)
end

function Brag:Show()
    self:Refresh()
    SCENE_MANAGER:ShowTopLevel(FurysCharacterTracker_Brag)
    CT.Raise(FurysCharacterTracker_Brag)
end

function Brag:Hide()
    SCENE_MANAGER:HideTopLevel(FurysCharacterTracker_Brag)
end

function Brag:Toggle()
    if FurysCharacterTracker_Brag:IsHidden() then self:Show() else self:Hide() end
end

function Brag:RefreshIfShown()
    if not FurysCharacterTracker_Brag:IsHidden() then self:Refresh() end
end
