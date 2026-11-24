-- The brag card (/fct brag): the roster's best numbers on one screen, sized for a screenshot
-- to share on Discord, like the Combat Metrics or SuperStar panels.
local CT = FurysCharacterTracker
local U = CT.Util
local Brag = {}
CT.Brag = Brag

local COLS, ROWS = 4, 4
local TILE_W, TILE_H, GAP = 219, 104, 12
local CLASS_COUNT = 7   -- Dragonknight, Sorcerer, Nightblade, Templar, Warden, Necromancer, Arcanist
local ROLE_KEYS = { "Tank", "Healer", "DPS" }

local T = CT.Theme                    -- Fury Night colors and fonts (UI/Theme.lua)
local GOLD = T.RGB.VIOLET             -- the numbers and bars
local PARCH = T.RGB.TEXT
local DIM = T.RGB.MUTED

-- Numbers ------------------------------------------------------------------------------

local function Comma(n) return ZO_CommaDelimitNumber(zo_round(n or 0)) end

function Brag:Compute()
    local s = {
        characters = 0, hours = 0, skillPoints = 0, linesMaxed = 0, linesTotal = 0, research = 0, researchAll = 0,
        grandmasters = 0, vampWolf = 0, scribing = 0, companions = 0, riding = 0, bestRecipes = 0, bestRecipesName = "",
        bestAch = 0, bestAchName = "", bestPlans = 0, bestPlansName = "", bestMotifs = 0, bestMotifsName = "",
        recipesTotal = 0, plansTotal = 0, motifsTotal = 0, researchTotal = 0,
        classes = {}, classOrder = {},
    }
    for _, entry in ipairs(CT.Roster:List()) do
        local c, m = CT.Roster:Get(entry.name)
        local lines = c.lines or {}
        s.characters = s.characters + 1
        s.hours = s.hours + (c.playedHours or 0)
        s.skillPoints = s.skillPoints + (c.skillPoints or 0)
        s.research = s.research + (c.research or 0)
        s.researchTotal = s.researchTotal + (c.researchTotal or CT.RESEARCH_TOTAL)
        s.recipesTotal = math.max(s.recipesTotal, c.recipesTotal or 0)
        s.plansTotal = math.max(s.plansTotal, c.furnishingsTotal or 0)
        s.motifsTotal = math.max(s.motifsTotal, c.motifsTotal or 0)

        for _, group in ipairs(CT.GROUPS) do
            for _, line in ipairs(group.lines) do
                s.linesTotal = s.linesTotal + 1
                if (lines[line.name] or 0) >= line.max then s.linesMaxed = s.linesMaxed + 1 end
            end
        end
        local allTraits = (c.research or 0) >= (c.researchTotal or CT.RESEARCH_TOTAL)
        if allTraits then s.researchAll = s.researchAll + 1 end
        if allTraits and (c.craftMaxed or 0) >= 7 then s.grandmasters = s.grandmasters + 1 end
        local vamp, wolf = CT.LINE_BY_NAME["Vampire"], CT.LINE_BY_NAME["Werewolf"]
        if (lines[vamp.name] or 0) >= vamp.max and (lines[wolf.name] or 0) >= wolf.max then s.vampWolf = s.vampWolf + 1 end
        if c.scriptsTotal and (c.scripts or 0) >= c.scriptsTotal then s.scribing = s.scribing + 1 end
        if #(c.companions or {}) >= (c.companionsTotal or CT.COMPANION_TOTAL) then s.companions = s.companions + 1 end
        if (c.riding or 0) >= (c.ridingMax or CT.RIDING_MAX) then s.riding = s.riding + 1 end
        if (c.recipes or 0) > s.bestRecipes then s.bestRecipes, s.bestRecipesName = c.recipes, entry.name end
        if (c.achievementPoints or 0) > s.bestAch then s.bestAch, s.bestAchName = c.achievementPoints, entry.name end
        if (c.furnishings or 0) > s.bestPlans then s.bestPlans, s.bestPlansName = c.furnishings, entry.name end
        if (c.motifs or 0) > s.bestMotifs then s.bestMotifs, s.bestMotifsName = c.motifs, entry.name end

        -- Which roles each class is played in, from your Role picks ("DPS/Healer" counts for both).
        local class = c.class or "?"
        if not s.classes[class] then
            s.classes[class] = {}
            s.classOrder[#s.classOrder + 1] = class
        end
        for _, key in ipairs(ROLE_KEYS) do
            if m.role and zo_plainstrfind(m.role, key) then s.classes[class][key] = true end
        end
    end
    table.sort(s.classOrder)
    return s
end

-- pct = how far along (0 to 1), shown in the tile corner and as a bar; nil = no finish line.
local function Pct(done, total)
    if not total or total <= 0 then return nil end
    return math.min(1, (done or 0) / total)
end

local function Tiles(s)
    local n = s.characters
    local account = CT.Data().account or {}
    local cp = CT.IsHome() and GetPlayerChampionPointsEarned() or account.championPoints   -- nil: not saved yet
    local achTotal = CT.IsHome() and GetTotalAchievementPoints() or account.achievementTotal
    local years = s.hours / 24 / 365.25
    local timeNote = years >= 1 and string.format("%.1f years, nonstop", years) or string.format("%s days, nonstop", Comma(s.hours / 24))
    local function OfAll(count) return string.format("%d / %d", count, n) end
    return {
        { value = Comma(s.hours), label = "Hours played", note = timeNote },
        { value = cp and Comma(cp) or "?", label = "Champion Points",
          note = cp and ("of " .. Comma(CT.CP_MAX) .. ", account-wide") or "log in to read", pct = cp and Pct(cp, CT.CP_MAX) or nil },
        { value = Comma(s.bestAch), label = "Most achievement points", note = s.bestAchName,
          pct = Pct(s.bestAch, achTotal) },
        { value = Comma(s.skillPoints), label = "Skill points earned", note = string.format("across %d characters", n),
          pct = Pct(s.skillPoints, n * CT.SKILL_POINTS_MAX) },
        { value = Comma(s.linesMaxed), label = "Skill lines maxed", note = "of " .. Comma(s.linesTotal) .. " tracked",
          pct = Pct(s.linesMaxed, s.linesTotal) },
        { value = Comma(s.research), label = "Traits researched", note = string.format("%d know every trait", s.researchAll),
          pct = Pct(s.research, s.researchTotal) },
        { value = OfAll(s.grandmasters), label = "Grandmaster crafters", note = "7 crafts at 50 + every trait", pct = Pct(s.grandmasters, n) },
        { value = OfAll(s.vampWolf), label = "Vampire + Werewolf", note = "both lines maxed", pct = Pct(s.vampWolf, n) },
        { value = OfAll(s.scribing), label = "Scribing complete", note = "every grimoire and script", pct = Pct(s.scribing, n) },
        { value = OfAll(s.companions), label = "All companions", note = "every one unlocked", pct = Pct(s.companions, n) },
        { value = OfAll(s.riding), label = "Riding maxed", note = "speed, stamina, carry", pct = Pct(s.riding, n) },
        { value = Comma(s.bestRecipes), label = "Most recipes known", note = s.bestRecipesName, pct = Pct(s.bestRecipes, s.recipesTotal) },
        { value = Comma(s.bestPlans), label = "Most furnishing plans", note = s.bestPlansName, pct = Pct(s.bestPlans, s.plansTotal) },
        { value = Comma(s.bestMotifs), label = "Most motif styles", note = s.bestMotifsName, pct = Pct(s.bestMotifs, s.motifsTotal) },
        { value = Comma(account.setPieces), label = "Set items collected",
          note = account.setPiecesTotal and ("of " .. Comma(account.setPiecesTotal) .. " (sticker book)") or "log in to read",
          pct = Pct(account.setPieces, account.setPiecesTotal) },
        { value = Comma(account.outfitStyles), label = "Outfit styles",
          note = account.outfitStylesTotal and ("of " .. Comma(account.outfitStylesTotal)) or "log in to read",
          pct = Pct(account.outfitStyles, account.outfitStylesTotal) },
    }
end

-- Window -------------------------------------------------------------------------------

local function Label(name, parent, font, rgb)
    local label = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    label:SetFont(font)
    label:SetColor(rgb[1], rgb[2], rgb[3], 1)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    return label
end

function Brag:Build()
    if self.tiles then return end
    SCENE_MANAGER:RegisterTopLevel(FurysCharacterTracker_Brag, false)
    self.tiles = {}
    for i = 1, COLS * ROWS do
        local col, row = (i - 1) % COLS, zo_floor((i - 1) / COLS)
        local tile = WINDOW_MANAGER:CreateControl("FurysCharacterTracker_BragTile" .. i, FurysCharacterTracker_BragTiles, CT_TEXTURE)
        T.Paint(tile, T.STRIPE)
        tile:SetDimensions(TILE_W, TILE_H)
        tile:SetAnchor(TOPLEFT, FurysCharacterTracker_BragTiles, TOPLEFT, col * (TILE_W + GAP), row * (TILE_H + GAP))
        local edge = WINDOW_MANAGER:CreateControl("FurysCharacterTracker_BragTile" .. i .. "Edge", tile, CT_TEXTURE)
        edge:SetColor(GOLD[1], GOLD[2], GOLD[3], 0.85)
        edge:SetDimensions(TILE_W, 2)
        edge:SetAnchor(TOPLEFT, tile, TOPLEFT, 0, 0)
        local value = Label("FurysCharacterTracker_BragTile" .. i .. "Value", tile, "ZoFontWinH1", GOLD)
        value:SetDimensions(TILE_W - 12, 44)
        value:SetAnchor(TOP, tile, TOP, 0, 6)
        local label = Label("FurysCharacterTracker_BragTile" .. i .. "Label", tile, "ZoFontGameBold", PARCH)
        label:SetDimensions(TILE_W - 12, 22)
        label:SetAnchor(TOP, value, BOTTOM, 0, 2)
        local note = Label("FurysCharacterTracker_BragTile" .. i .. "Note", tile, "ZoFontGameSmall", DIM)
        note:SetDimensions(TILE_W - 12, 18)
        note:SetAnchor(TOP, label, BOTTOM, 0, 0)
        local pct = Label("FurysCharacterTracker_BragTile" .. i .. "Pct", tile, "ZoFontGameBold", GOLD)
        pct:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        pct:SetDimensions(56, 18)
        pct:SetAnchor(BOTTOMRIGHT, tile, BOTTOMRIGHT, -8, -12)
        local track = WINDOW_MANAGER:CreateControl("FurysCharacterTracker_BragTile" .. i .. "Track", tile, CT_TEXTURE)
        T.Paint(track, T.HOVER)
        track:SetDimensions(TILE_W - 16, 4)
        track:SetAnchor(BOTTOMLEFT, tile, BOTTOMLEFT, 8, -6)
        local bar = WINDOW_MANAGER:CreateControl("FurysCharacterTracker_BragTile" .. i .. "Bar", tile, CT_TEXTURE)
        bar:SetColor(GOLD[1], GOLD[2], GOLD[3], 1)
        bar:SetAnchor(BOTTOMLEFT, tile, BOTTOMLEFT, 8, -6)
        self.tiles[i] = { value = value, label = label, note = note, pct = pct, track = track, bar = bar }
    end
    FurysCharacterTracker_BragCoverageTitle:SetFont(T.FONT_SECTION)
    self.classes = {}
    local width = zo_floor(912 / CLASS_COUNT)
    for i = 1, CLASS_COUNT do
        local name = Label("FurysCharacterTracker_BragClass" .. i, FurysCharacterTracker_BragCoverage, "ZoFontGameBold", PARCH)
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
    local s = self:Compute()
    FurysCharacterTracker_BragTitle:SetText(CT.view.account)
    local onAccount = #CT.Roster:AccountCharacters()
    local count = (s.characters < onAccount) and string.format("%d of %d characters read (/fct todo)", s.characters, onAccount)
                                             or string.format("%d characters", s.characters)
    FurysCharacterTracker_BragSubtitle:SetText(string.format("%s  ·  %d of %d classes  ·  %s", count, #s.classOrder, CLASS_COUNT, CT.view.world))

    for i, t in ipairs(Tiles(s)) do
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
            -- Whole percent, but never round up to 100% before it is really done.
            local shown = (t.pct >= 1) and 100 or math.min(99, zo_floor(t.pct * 100 + 0.5))
            tile.pct:SetText(shown .. "%")
            tile.bar:SetDimensions(math.max(1, (TILE_W - 16) * t.pct), 4)
        end
    end

    -- Class x role coverage: violet role = you have a character playing it.
    local everything = #s.classOrder >= CLASS_COUNT
    for i, slot in ipairs(self.classes) do
        local class = s.classOrder[i]
        if class then
            local parts = {}
            for _, key in ipairs(ROLE_KEYS) do
                if s.classes[class][key] then
                    parts[#parts + 1] = "|cA08CFF" .. key .. "|r"
                else
                    parts[#parts + 1] = "|c4A4670" .. key .. "|r"
                    everything = false
                end
            end
            slot.name:SetText(class)
            slot.roles:SetText(table.concat(parts, "  "))
        else
            slot.name:SetText("")
            slot.roles:SetText("")
        end
    end
    FurysCharacterTracker_BragCoverageTitle:SetText(everything and "Every class. Every role." or "Classes & roles")

    FurysCharacterTracker_BragFooterLeft:SetText(os.date("%B %d, %Y"))
    FurysCharacterTracker_BragFooter:SetText("Fury's Character Tracker v" .. CT.version)
end

function Brag:Show()
    self:Build()
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
