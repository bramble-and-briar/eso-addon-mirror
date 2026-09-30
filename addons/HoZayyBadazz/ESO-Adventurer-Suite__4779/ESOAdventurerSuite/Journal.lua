-- ESO Adventurer Suite
-- Copyright (c) 2026 HoZayyBadazz. All Rights Reserved.
-- Proprietary source. Unauthorized redistribution, republication, rebranding,
-- or public distribution of modified/derivative versions is prohibited.
-- Private personal-use modifications are permitted. See LICENSE.txt.

local EPC = ESOProgressionCoach
EPC.Journal = EPC.Journal or {}
local J = EPC.Journal
local wm = WINDOW_MANAGER

local TABS = {"NOTES", "PINS", "BUILD", "GEAR", "SKILLS", "COMBAT", "ACTIVITY", "DUNGEONS", "BATTLEGROUNDS", "GROUPFINDER", "QUESTS", "TRAVEL", "TOOLS", "ACHIEVEMENTS", "STATS", "CODEX", "DICE"}
local TAB_LABELS = {
    NOTES="Notes", PINS="Checkpoints", BUILD="Build Guide", GEAR="Gear & Sets", SKILLS="Skills & CP",
    COMBAT="Combat", ACTIVITY="Activities", DUNGEONS="Dungeon Finder", BATTLEGROUNDS="Battleground Finder", GROUPFINDER="Group Finder", QUESTS="Quest Finder", TRAVEL="Map / Travel", TOOLS="Utilities",
    ACHIEVEMENTS="Achievements", STATS="Character Stats", CODEX="Crafting Codex", DICE="Dice & Coin",
}
local TAB_TITLES = {
    NOTES="TAMRIEL CODEX", PINS="CHECKPOINTS", BUILD="BUILD GUIDE", GEAR="GEAR & SETS", SKILLS="SKILLS & CHAMPION",
    COMBAT="COMBAT", ACTIVITY="ACTIVITIES", DUNGEONS="DUNGEON FINDER", BATTLEGROUNDS="BATTLEGROUND FINDER", GROUPFINDER="GROUP FINDER", QUESTS="QUEST FINDER", TRAVEL="MAP & TRAVEL", TOOLS="UTILITIES",
    ACHIEVEMENTS="ACHIEVEMENTS", STATS="CHARACTER STATS", CODEX="CRAFTING CODEX", DICE="DICE & COIN",
}
local TAB_PAGE_NUMBERS = { NOTES="01", PINS="02", BUILD="03", GEAR="04", SKILLS="05", COMBAT="06", ACTIVITY="07", QUESTS="08", TRAVEL="09", TOOLS="10", ACHIEVEMENTS="11", STATS="12", CODEX="13", DICE="14" }
local SUITE_TABS = { BUILD=true, GEAR=true, SKILLS=true, COMBAT=true, ACTIVITY=true, DUNGEONS=true, BATTLEGROUNDS=true, GROUPFINDER=true, QUESTS=true, TRAVEL=true, TOOLS=true }
local CATEGORIES = {"ALL", "Adventure", "Quests", "Builds", "Crafting", "Roleplay", "Personal"}
local THEMES = {
    PARCHMENT = { bg={0.0,0.0,0.0,0.0}, panel={0.93,0.88,0.76,0.08}, page={0.955,0.915,0.81,0.992}, page2={0.965,0.925,0.825,0.992}, cover={0.10,0.07,0.035,0.96}, edge={0.50,0.38,0.18,0.92}, text={0.15,0.09,0.04,1}, accent={0.32,0.18,0.08,1} },
    MIDNIGHT  = { bg={0.010,0.014,0.024,0.99}, panel={0.035,0.045,0.062,0.96}, page={0.050,0.060,0.082,0.98}, page2={0.040,0.050,0.072,0.98}, cover={0.010,0.014,0.024,1}, edge={0.24,0.36,0.54,1}, text={0.88,0.92,0.98,1}, accent={0.43,0.68,0.96,1} },
    DAEDRIC   = { bg={0.050,0.008,0.008,0.99}, panel={0.12,0.025,0.025,0.96}, page={0.145,0.035,0.030,0.98}, page2={0.115,0.022,0.024,0.98}, cover={0.045,0.005,0.006,1}, edge={0.62,0.10,0.10,1}, text={0.96,0.84,0.78,1}, accent={0.98,0.31,0.22,1} },
    FROST     = { bg={0.018,0.042,0.056,0.99}, panel={0.045,0.085,0.105,0.96}, page={0.060,0.110,0.130,0.98}, page2={0.045,0.090,0.112,0.98}, cover={0.012,0.035,0.050,1}, edge={0.30,0.66,0.76,1}, text={0.87,0.96,0.99,1}, accent={0.43,0.86,0.94,1} },
}
local THEME_ORDER = {"PARCHMENT", "MIDNIGHT", "DAEDRIC", "FROST"}
local PIN_TYPE = "EAS_CUSTOM_JOURNAL_PIN"

local function getNativeLoreBookMedium()
    local medium = BOOK_MEDIUM_YELLOWED_PAPER or BOOK_MEDIUM_NOTE or BOOK_MEDIUM_SCROLL
    if not medium or type(GetBookMediumInfo) ~= "function" then return nil end
    local ok, bg, numPages, pageWidth, pageHeight, pageYOffset, leftPageXOffset, rightPageXOffset, openSound, closeSound, turnPageSound = pcall(GetBookMediumInfo, medium)
    if not ok or not bg or bg == "" then return nil end
    return {
        medium = medium, bg = bg, numPages = numPages, pageWidth = pageWidth, pageHeight = pageHeight,
        pageYOffset = pageYOffset, leftPageXOffset = leftPageXOffset, rightPageXOffset = rightPageXOffset,
        openSound = openSound, closeSound = closeSound, turnPageSound = turnPageSound,
    }
end

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a,b,c,d,e,f,g,h = pcall(fn, ...)
    if not ok then return fallback end
    return a,b,c,d,e,f,g,h
end
local function trim(s)
    s = tostring(s or "")
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end
local function nowStamp()
    return tonumber(safe(GetTimeStamp, 0)) or 0
end
local function setButtonBorderColor(button, r, g, b, a)
    if not button then return end
    if button._easBorderLines then
        for _, line in ipairs(button._easBorderLines) do
            if line then
                if line.SetCenterColor then
                    line:SetCenterColor(r, g, b, a)
                    if line.SetEdgeColor then line:SetEdgeColor(0, 0, 0, 0) end
                elseif line.SetColor then
                    line:SetColor(r, g, b, a)
                end
            end
        end
    end
end

local function setButtonStyle(button, selected, theme)
    if not button then return end
    local fallback = THEMES.PARCHMENT or {}
    local t = type(theme) == "table" and theme or fallback
    local accent = type(t.accent) == "table" and t.accent or fallback.accent or {0.43,0.68,0.96,1}
    local textColor = type(t.text) == "table" and t.text or fallback.text or {0.88,0.92,0.98,1}
    local ar,ag,ab = tonumber(accent[1]) or 0.43, tonumber(accent[2]) or 0.68, tonumber(accent[3]) or 0.96
    local tr,tg,tb = tonumber(textColor[1]) or 0.88, tonumber(textColor[2]) or 0.92, tonumber(textColor[3]) or 0.98
    if button.SetNormalFontColor then
        if selected then button:SetNormalFontColor(ar,ag,ab,1)
        else button:SetNormalFontColor(tr,tg,tb,0.92) end
        button:SetMouseOverFontColor(ar,ag,ab,1)
        button:SetPressedFontColor(ar,ag,ab,1)
    end
    if button._easBorder then
        if selected then
            button._easBorder:SetCenterColor(0.055, 0.085, 0.122, 0.70)
        else
            button._easBorder:SetCenterColor(0.035, 0.050, 0.072, 0.55)
        end
    end
    -- Selection never changes the frame color: every suite button uses the
    -- same complete cyan rectangle.
    setButtonBorderColor(button, 0.18, 0.72, 0.92, 0.96)
end

local function makeButton(name, parent, text, x, y, w, h, handler)
    local b = wm:CreateControl(name, parent, CT_BUTTON)
    b:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    b:SetDimensions(w, h)
    b:SetFont("ZoFontGameBold")
    b:SetText(text)
    if b.SetHorizontalAlignment then b:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
    if b.SetVerticalAlignment then b:SetVerticalAlignment(TEXT_ALIGN_CENTER) end

    -- Fill is separate from the frame. ESO backdrops using a nil edge texture
    -- can render as disconnected/cropped lines at small control sizes, so the
    -- border is four explicit texture strips instead.
    local bg = wm:CreateControl(name .. "BG", b, CT_BACKDROP)
    bg:SetAnchor(TOPLEFT, b, TOPLEFT, 2, 2)
    bg:SetAnchor(BOTTOMRIGHT, b, BOTTOMRIGHT, -2, -2)
    if bg.SetDrawLayer then bg:SetDrawLayer(DL_BACKGROUND) end
    if bg.SetDrawLevel then bg:SetDrawLevel(0) end
    bg:SetCenterColor(0.035, 0.050, 0.072, 0.55)
    bg:SetEdgeColor(0, 0, 0, 0)
    b._easBorder = bg

    local function borderLine(suffix)
        -- Use a solid backdrop strip instead of a texture asset. This renders
        -- reliably on every ESO UI scale and keeps the cyan frame visible.
        local line = wm:CreateControl(name .. "Border" .. suffix, b, CT_BACKDROP)
        if line.SetDrawLayer then line:SetDrawLayer(DL_CONTROLS) end
        if line.SetDrawLevel then line:SetDrawLevel(2) end
        line:SetCenterColor(0.18, 0.72, 0.92, 0.96)
        line:SetEdgeColor(0, 0, 0, 0)
        return line
    end
    local top = borderLine("Top")
    top:SetAnchor(TOPLEFT, b, TOPLEFT, 1, 1)
    top:SetAnchor(TOPRIGHT, b, TOPRIGHT, -1, 1)
    top:SetHeight(1)
    local bottom = borderLine("Bottom")
    bottom:SetAnchor(BOTTOMLEFT, b, BOTTOMLEFT, 1, -1)
    bottom:SetAnchor(BOTTOMRIGHT, b, BOTTOMRIGHT, -1, -1)
    bottom:SetHeight(1)
    local left = borderLine("Left")
    left:SetAnchor(TOPLEFT, b, TOPLEFT, 1, 1)
    left:SetAnchor(BOTTOMLEFT, b, BOTTOMLEFT, 1, -1)
    left:SetWidth(1)
    local right = borderLine("Right")
    right:SetAnchor(TOPRIGHT, b, TOPRIGHT, -1, 1)
    right:SetAnchor(BOTTOMRIGHT, b, BOTTOMRIGHT, -1, -1)
    right:SetWidth(1)
    b._easBorderLines = {top, bottom, left, right}

    if SOUNDS and SOUNDS.DEFAULT_CLICK and b.SetClickSound then b:SetClickSound(SOUNDS.DEFAULT_CLICK) end
    if handler then b:SetHandler("OnClicked", handler) end
    return b
end
local function makeLabel(name, parent, text, x, y, w, h, font)
    local l = wm:CreateControl(name, parent, CT_LABEL)
    l:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    l:SetDimensions(w, h)
    l:SetFont(font or "ZoFontGame")
    if l.SetMaxLineCount then l:SetMaxLineCount(0) end
    l:SetText(text or "")
    l:SetVerticalAlignment(TEXT_ALIGN_TOP)
    return l
end

local function getDocumentFont(fontName, targetSize)
    if _G[fontName] then return fontName end
    if type(CreateFont) == "function" then
        local ok, fontObj = pcall(CreateFont, fontName)
        if ok and fontObj then
            local face, flags
            if ZoFontGame and type(ZoFontGame.GetFontInfo) == "function" then
                local infoOk, fontFace, _, fontFlags = pcall(ZoFontGame.GetFontInfo, ZoFontGame)
                if infoOk then face, flags = fontFace, fontFlags end
            end
            if type(fontObj.SetFontInfo) == "function" and face then
                fontObj:SetFontInfo(face, tonumber(targetSize) or 20, flags or "soft-shadow-thin")
            elseif type(fontObj.SetFont) == "function" then
                fontObj:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thin", tonumber(targetSize) or 20))
            end
            return fontName
        end
    end
    return string.format("$(BOLD_FONT)|%d|soft-shadow-thin", tonumber(targetSize) or 20)
end

local function getAchievementsDocumentFont()
    return "$(BOLD_FONT)|24|soft-shadow-thin"
end

local function getStatsDocumentFont()
    return "$(BOLD_FONT)|34|soft-shadow-thin"
end

local function getBuildGuideDocumentFont()
    return getDocumentFont("EAS_BuildGuideDocumentFont", 20)
end

local function getSkillsChampionDocumentFont()
    return getDocumentFont("EAS_SkillsChampionDocumentFont", 18)
end

local function getStringWidth(label, text)
    if label and type(label.GetStringWidth) == "function" then
        local ok, width = pcall(label.GetStringWidth, label, tostring(text or ""))
        if ok and type(width) == "number" then return width end
    end
    return string.len(tostring(text or "")) * 8
end

local function makeEsoSafeBookText(text)
    text = tostring(text or "")
    -- ESO fonts do not contain every Unicode symbol. Replace common UI punctuation
    -- that can render as square/missing-glyph boxes while preserving names/text.
    local replacements = {
        {string.char(226, 134, 148), " / "},   -- bidirectional arrow
        {string.char(226, 134, 146), " -> "},  -- right arrow
        {string.char(226, 128, 148), " - "},   -- em dash
        {string.char(226, 128, 147), "-"},     -- en dash
        {string.char(226, 128, 162), "-"},     -- bullet
        {string.char(194, 187), ">"},          -- double angle quote
        {string.char(226, 156, 147), "[DONE]"},-- check mark
        {string.char(194, 183), "-"},          -- middle dot
    }
    for i = 1, #replacements do
        text = text:gsub(replacements[i][1], replacements[i][2])
    end
    return text
end

local function wrapForBook(label, text, maxWidth)
    text = makeEsoSafeBookText(text)
    maxWidth = tonumber(maxWidth) or (label and label.GetWidth and label:GetWidth()) or 320
    if maxWidth <= 0 then maxWidth = 320 end
    local out = {}
    for paragraph in string.gmatch(text .. "\n", "(.-)\n") do
        if paragraph == "" then
            out[#out+1] = ""
        else
            local line = ""
            for word in string.gmatch(paragraph, "%S+") do
                local candidate = line == "" and word or (line .. " " .. word)
                if line == "" or getStringWidth(label, candidate) <= maxWidth then
                    line = candidate
                else
                    out[#out+1] = line
                    line = word
                end
            end
            if line ~= "" then out[#out+1] = line end
        end
    end
    return table.concat(out, "\n")
end

local function setBookText(label, text, width)
    if not label then return end
    label:SetText(wrapForBook(label, text, width))
end
local function makePanel(name, parent, x, y, w, h)
    local p = wm:CreateControl(name, parent, CT_BACKDROP)
    p:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    p:SetDimensions(w, h)
    p:SetEdgeTexture(nil, 1, 1, 1)
    return p
end

local function getChanceTexture(kind, sides)
    if tostring(kind) == "COIN" then return EPC:AssetPath("Art/coin.dds") end
    local die = tonumber(sides) or 20
    die = math.max(2, math.floor(die))
    return EPC:AssetPath(string.format("Art/dice_d%d.dds", die))
end

local function styleIconButton(button, theme)
    if not button then return end
    theme = theme or THEMES.PARCHMENT
    button._theme = theme
    if button.bg then
        button.bg:SetCenterColor(theme.page[1], theme.page[2], theme.page[3], 0.34)
        button.bg:SetEdgeColor(0.24, 0.36, 0.54, 0.82)
    end
    if button.label then button.label:SetColor(theme.text[1], theme.text[2], theme.text[3], 1) end
end

local function makeIconButton(name, parent, texturePath, labelText, x, y, w, h, handler)
    local b = wm:CreateControl(name, parent, CT_BUTTON)
    b:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    b:SetDimensions(w, h)
    if SOUNDS and SOUNDS.DEFAULT_CLICK and b.SetClickSound then b:SetClickSound(SOUNDS.DEFAULT_CLICK) end
    if handler then b:SetHandler("OnClicked", handler) end

    local bg = wm:CreateControl(name.."_BG", b, CT_BACKDROP)
    bg:SetAnchor(TOPLEFT, b, TOPLEFT, 1, 1)
    bg:SetAnchor(BOTTOMRIGHT, b, BOTTOMRIGHT, -1, -1)
    bg:SetEdgeTexture(nil, 1, 1, 1)
    b.bg = bg

    local icon = wm:CreateControl(name.."_Icon", b, CT_TEXTURE)
    local iconSize = math.min(w - 18, h - 38)
    if iconSize < 24 then iconSize = math.min(w - 8, h - 8) end
    icon:SetDimensions(iconSize, iconSize)
    icon:SetAnchor(TOP, b, TOP, 0, 8)
    icon:SetTexture(texturePath)
    b.icon = icon

    local label = wm:CreateControl(name.."_Label", b, CT_LABEL)
    label:SetAnchor(BOTTOM, b, BOTTOM, 0, -6)
    label:SetDimensions(w - 10, 20)
    label:SetFont("ZoFontGameBold")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetText(labelText or "")
    b.label = label

    local function applyHover(alpha, edge)
        local t = b._theme or THEMES.PARCHMENT
        if b.bg then
            b.bg:SetCenterColor(t.page[1], t.page[2], t.page[3], alpha)
            b.bg:SetEdgeColor(0.24, 0.36, 0.54, math.max(0.72, edge))
        end
    end
    b:SetHandler("OnMouseEnter", function() applyHover(0.48, 0.72) end)
    b:SetHandler("OnMouseExit", function() applyHover(0.34, 0.48) end)
    styleIconButton(b, THEMES.PARCHMENT)
    return b
end

function J:EnsureSaved()
    EPC.saved.journal = EPC.saved.journal or {}
    local s = EPC.saved.journal
    s.entries = s.entries or {}
    s.pins = s.pins or {}
    s.theme = s.theme or "PARCHMENT"
    if s.loreBookJournalUpgrade ~= true then s.theme = "PARCHMENT" s.loreBookJournalUpgrade = true end
    if s.nativeLoreBookJournalUpgrade ~= true then s.theme = "PARCHMENT" s.nativeLoreBookJournalUpgrade = true end
    s.activeTab = s.activeTab or "NOTES"
    s.category = s.category or "ALL"
    if s.readMode == nil then s.readMode = false end
    s.nextEntryId = tonumber(s.nextEntryId) or 1
    s.nextPinId = tonumber(s.nextPinId) or 1
    return s
end

function J:GetTheme()
    local s = self:EnsureSaved()
    return THEMES[s.theme] or THEMES.PARCHMENT
end

local ApplyThemeImplArch

function J:ApplyTheme(...)
    return ApplyThemeImplArch(self, ...)
end

ApplyThemeImplArch = function(self)
    if not self.window then return end
    local t = self:GetTheme()
    local themeName = self:EnsureSaved().theme or "PARCHMENT"

    -- The journal uses ESO's native Lore Reader book art. Themes tint the stock book
    -- instead of drawing opaque addon panels over the parchment.
    if self.bookTexture then
        if themeName == "MIDNIGHT" then self.bookTexture:SetColor(0.40, 0.46, 0.62, 1)
        elseif themeName == "DAEDRIC" then self.bookTexture:SetColor(0.66, 0.37, 0.31, 1)
        elseif themeName == "FROST" then self.bookTexture:SetColor(0.68, 0.82, 0.88, 1)
        else self.bookTexture:SetColor(1, 1, 1, 1) end
    end
    if self.bg then
        if self.nativeBook then self.bg:SetCenterColor(0,0,0,0) self.bg:SetEdgeColor(0,0,0,0)
        else self.bg:SetCenterColor(t.page[1],t.page[2],t.page[3],0.98) self.bg:SetEdgeColor(t.edge[1],t.edge[2],t.edge[3],0.9) end
    end
    if self.bookCover then self.bookCover:SetCenterColor(0,0,0,0) self.bookCover:SetEdgeColor(0,0,0,0) end
    if self.leftPage then self.leftPage:SetCenterColor(0,0,0,0) self.leftPage:SetEdgeColor(0,0,0,0) end
    if self.rightPage then self.rightPage:SetCenterColor(0,0,0,0) self.rightPage:SetEdgeColor(0,0,0,0) end
    if self.spine then self.spine:SetCenterColor(0,0,0,0) self.spine:SetEdgeColor(0,0,0,0) end
    if self.flipPage then
        self.flipPage:SetCenterColor(t.page2[1],t.page2[2],t.page2[3],0.92)
        self.flipPage:SetEdgeColor(t.edge[1],t.edge[2],t.edge[3],0.35)
    end
    for _, p in pairs(self.panels or {}) do
        p:SetCenterColor(0,0,0,0)
        p:SetEdgeColor(t.edge[1],t.edge[2],t.edge[3],0.18)
    end
    for _, l in pairs(self.themeLabels or {}) do l:SetColor(t.text[1],t.text[2],t.text[3],1) end
    if self.title then self.title:SetColor(t.accent[1],t.accent[2],t.accent[3],1) end
    if self.subtitle then self.subtitle:SetColor(t.text[1],t.text[2],t.text[3],0.72) end
    if self.noteTitleEdit then self.noteTitleEdit:SetColor(t.text[1],t.text[2],t.text[3],1) end
    if self.noteBodyEdit then self.noteBodyEdit:SetColor(t.text[1],t.text[2],t.text[3],1) end
    if self.checkpointNameEdit then self.checkpointNameEdit:SetColor(t.text[1],t.text[2],t.text[3],1) end
    for name, b in pairs(self.tabButtons or {}) do setButtonStyle(b, name == self.activeTab, t) end
    for name, b in pairs(self.categoryButtons or {}) do setButtonStyle(b, name == self.category, t) end
    for mode, b in pairs(self.codexButtons or {}) do setButtonStyle(b, mode == (self.codexMode or "ALCHEMY"), t) end
    for _, b in ipairs(self.topButtons or {}) do setButtonStyle(b, false, t) end
    for _, b in ipairs(self.iconButtons or {}) do styleIconButton(b, t) end
    if self.modeButton then setButtonStyle(self.modeButton, self.readMode ~= true, t) end
    if self.themeButton then setButtonStyle(self.themeButton, false, t) end
    if self.closeButton then setButtonStyle(self.closeButton, false, t) end
    if self.prevPageButton then setButtonStyle(self.prevPageButton, false, t) end
    if self.nextPageButton then setButtonStyle(self.nextPageButton, false, t) end
    if self.diceResultPanel then
        self.diceResultPanel:SetCenterColor(t.page2[1], t.page2[2], t.page2[3], 0.42)
        self.diceResultPanel:SetEdgeColor(t.edge[1], t.edge[2], t.edge[3], 0.52)
    end
    if self.diceResultValue then self.diceResultValue:SetColor(t.accent[1], t.accent[2], t.accent[3], 1) end
end

local CycleThemeImplArch

function J:CycleTheme(...)
    return CycleThemeImplArch(self, ...)
end

CycleThemeImplArch = function(self)
    local s = self:EnsureSaved()
    local current = 1
    for i=1,#THEME_ORDER do if THEME_ORDER[i] == s.theme then current = i break end end
    current = current + 1
    if current > #THEME_ORDER then current = 1 end
    s.theme = THEME_ORDER[current]
    self:ApplyTheme()
    if self.themeButton then self.themeButton:SetText("THEME") end
end

local CreateEditBoxImplArch

function J:CreateEditBox(...)
    return CreateEditBoxImplArch(self, ...)
end

CreateEditBoxImplArch = function(self, name, parent, x, y, w, h, multiLine)
    local e = wm:CreateControl(name, parent, CT_EDITBOX)
    e:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    e:SetDimensions(w, h)
    e:SetFont("ZoFontGame")
    if e.SetMaxInputChars then e:SetMaxInputChars(multiLine and 12000 or 120) end
    if multiLine and e.SetMultiLine then e:SetMultiLine(true) end
    if multiLine and e.SetNewLineEnabled then e:SetNewLineEnabled(true) end
    e:SetColor(0.18,0.11,0.05,1)
    e:SetHandler("OnTextChanged", function() self.dirty = true end)
    e:SetHandler("OnFocusLost", function() self:SaveCurrentEntry() end)
    return e
end

function J:SetEditorEnabled(enabled)
    enabled = enabled == true
    if self.noteTitleEdit then
        if self.noteTitleEdit.SetEditEnabled then self.noteTitleEdit:SetEditEnabled(enabled) end
        self.noteTitleEdit:SetMouseEnabled(enabled)
    end
    if self.noteBodyEdit then
        if self.noteBodyEdit.SetEditEnabled then self.noteBodyEdit:SetEditEnabled(enabled) end
        self.noteBodyEdit:SetMouseEnabled(enabled)
    end
    if self.modeButton then self.modeButton:SetText(enabled and "EDIT MODE" or "READ MODE") end
end

function J:FindEntry(id)
    if not id then return nil end
    local entries = self:EnsureSaved().entries
    for i=1,#entries do if entries[i].id == id then return entries[i], i end end
    return nil
end

function J:GetFilteredEntries()
    local result = {}
    local category = self.category or "ALL"
    for _, e in ipairs(self:EnsureSaved().entries) do
        if category == "ALL" or e.category == category then result[#result+1] = e end
    end
    table.sort(result, function(a,b) return (tonumber(a.modified) or 0) > (tonumber(b.modified) or 0) end)
    return result
end

function J:SaveCurrentEntry()
    if not self.noteTitleEdit or not self.noteBodyEdit then return nil end

    local title = trim(self.noteTitleEdit:GetText())
    local body = tostring(self.noteBodyEdit:GetText() or "")

    -- v0.29.43: SAVE NOTE must work even when the user types directly into an
    -- empty editor without pressing NEW NOTE first. Previously currentEntryId
    -- was nil, so SaveCurrentEntry returned immediately and RefreshNotes then
    -- cleared the text, making the note appear to disappear.
    if not self.currentEntryId then
        if title == "" and trim(body) == "" then
            self.dirty = false
            return nil
        end
        local s = self:EnsureSaved()
        local category = self.category ~= "ALL" and self.category or "Personal"
        local stamp = nowStamp()
        local e = {
            id = s.nextEntryId,
            title = title ~= "" and title or "Untitled Note",
            body = body,
            category = category,
            created = stamp,
            modified = stamp,
        }
        s.nextEntryId = s.nextEntryId + 1
        s.entries[#s.entries + 1] = e
        self.currentEntryId = e.id
        self.dirty = false
        return e
    end

    local e = self:FindEntry(self.currentEntryId)
    if not e then return nil end
    e.title = title
    if e.title == "" then e.title = "Untitled Note" end
    e.body = body
    e.category = e.category or (self.category ~= "ALL" and self.category or "Personal")
    e.modified = nowStamp()
    self.dirty = false
    return e
end

function J:SelectEntry(id)
    self:SaveCurrentEntry()
    local e = self:FindEntry(id)
    self.currentEntryId = e and e.id or nil
    if e then
        self.noteTitleEdit:SetText(e.title or "")
        self.noteBodyEdit:SetText(e.body or "")
    else
        self.noteTitleEdit:SetText("")
        self.noteBodyEdit:SetText("Select a note or create a new one.")
    end
    self.dirty = false
    self:RefreshNotes()
end

function J:NewEntry()
    self:SaveCurrentEntry()
    local s = self:EnsureSaved()
    local category = self.category ~= "ALL" and self.category or "Personal"
    local e = { id=s.nextEntryId, title="New Note", body="", category=category, created=nowStamp(), modified=nowStamp() }
    s.nextEntryId = s.nextEntryId + 1
    s.entries[#s.entries+1] = e
    self.currentEntryId = e.id
    self.noteTitleEdit:SetText(e.title)
    self.noteBodyEdit:SetText("")
    self.dirty = false
    self:RefreshNotes()
    if self.noteTitleEdit.TakeFocus then self.noteTitleEdit:TakeFocus() end
end

function J:DeleteEntry()
    local _, idx = self:FindEntry(self.currentEntryId)
    if not idx then return end
    table.remove(self:EnsureSaved().entries, idx)
    self.currentEntryId = nil
    self:RefreshNotes()
    local list = self:GetFilteredEntries()
    if list[1] then self:SelectEntry(list[1].id) else self:SelectEntry(nil) end
end

function J:SetCategory(category)
    self:SaveCurrentEntry()
    self.category = category
    self:EnsureSaved().category = category
    self.currentEntryId = nil
    self:RefreshNotes()
    local list = self:GetFilteredEntries()
    if list[1] then self:SelectEntry(list[1].id) else self:SelectEntry(nil) end
    self:ApplyTheme()
end

function J:RefreshNotes()
    if not self.notePage then return end
    local list = self:GetFilteredEntries()
    for i=1,#self.noteRows do
        local b = self.noteRows[i]
        local e = list[i]
        if e then
            local mark = e.id == self.currentEntryId and "> " or ""
            b:SetText(mark .. (e.title or "Untitled"))
            b:SetHidden(false)
            b.entryId = e.id
        else
            b:SetHidden(true)
            b.entryId = nil
        end
        setButtonStyle(b, e and e.id == self.currentEntryId, self:GetTheme())
    end
    if self.noteCount then self.noteCount:SetText(string.format("%d note%s", #list, #list == 1 and "" or "s")) end
    if self.deleteButton and self.deleteButton.SetEnabled then self.deleteButton:SetEnabled(self.activeTab == "NOTES" and self.currentEntryId ~= nil) end
end

function J:GetPinById(id)
    if not id then return nil end
    local pins = self:EnsureSaved().pins
    for i=1,#pins do if pins[i].id == id then return pins[i], i end end
    return nil
end

function J:RegisterMapPins()
    if self.mapPinsRegistered then return end
    if type(ZO_WorldMap_AddCustomPin) ~= "function" then return end
    local layout = { level=55, texture="EsoUI/Art/MapPins/MapPing.dds", size=30 }
    local function addPins(pinManager)
        local currentMapId = tonumber(safe(GetCurrentMapId, 0)) or 0
        local currentMapIndex = tonumber(safe(GetCurrentMapIndex, 0)) or 0
        for _, pin in ipairs(J:EnsureSaved().pins) do
            local same = (pin.mapId and pin.mapId ~= 0 and pin.mapId == currentMapId)
                or (pin.mapIndex and pin.mapIndex ~= 0 and pin.mapIndex == currentMapIndex)
            if same and tonumber(pin.x) and tonumber(pin.y) then
                pinManager:CreatePin(_G[PIN_TYPE], pin, pin.x, pin.y)
            end
        end
    end
    local ok = pcall(ZO_WorldMap_AddCustomPin, PIN_TYPE, addPins, nil, layout, nil)
    if ok and _G[PIN_TYPE] then
        self.mapPinsRegistered = true
        if type(ZO_WorldMap_SetCustomPinEnabled) == "function" then pcall(ZO_WorldMap_SetCustomPinEnabled, _G[PIN_TYPE], true) end
        if type(ZO_WorldMap_RefreshCustomPinsOfType) == "function" then pcall(ZO_WorldMap_RefreshCustomPinsOfType, _G[PIN_TYPE]) end
    end
end

function J:RefreshMapPins()
    self:RegisterMapPins()
    if self.mapPinsRegistered and type(ZO_WorldMap_RefreshCustomPinsOfType) == "function" and _G[PIN_TYPE] then
        pcall(ZO_WorldMap_RefreshCustomPinsOfType, _G[PIN_TYPE])
    end
end

function J:GetSortedCheckpoints()
    local result = {}
    for _, pin in ipairs(self:EnsureSaved().pins) do result[#result+1] = pin end
    table.sort(result, function(a,b)
        local am = tonumber(a.modified or a.created) or 0
        local bm = tonumber(b.modified or b.created) or 0
        if am == bm then return tostring(a.name or "") < tostring(b.name or "") end
        return am > bm
    end)
    return result
end

function J:FindCheckpoint(query)
    query = zo_strlower(trim(query))
    if query == "" then return nil, {} end
    local exact, matches = nil, {}
    for _, pin in ipairs(self:EnsureSaved().pins) do
        local name = zo_strlower(trim(pin.name or ""))
        if name == query then exact = pin break end
        if string.find(name, query, 1, true) then matches[#matches+1] = pin end
    end
    if exact then return exact, {exact} end
    if #matches == 1 then return matches[1], matches end
    return nil, matches
end

function J:SaveCurrentLocation(customName, saveMode)
    if type(SetMapToPlayerLocation) == "function" then pcall(SetMapToPlayerLocation) end
    local x,y,_,inCurrentMap = safe(GetMapPlayerPosition, 0, "player")
    x, y = tonumber(x) or 0, tonumber(y) or 0
    if inCurrentMap == false or x <= 0 or y <= 0 then
        EPC:Print("Checkpoint could not read your current map position.")
        return false
    end

    local s = self:EnsureSaved()
    local mapName = trim(safe(GetMapName, "Current Map"))
    local zone = trim(safe(GetUnitZone, "", "player"))
    local name = trim(customName)
    if name == "" and self.checkpointNameEdit then name = trim(self.checkpointNameEdit:GetText()) end
    if name == "" then name = string.format("Checkpoint %d - %s", s.nextPinId, zone ~= "" and zone or mapName) end

    -- v0.29.44: the Suite UI now has explicit SAVE NEW and UPDATE SELECTED
    -- actions. This removes the old ambiguity where saving another checkpoint
    -- while one was selected silently moved/renamed the selected checkpoint.
    -- CLI callers keep the legacy exact-name update behavior unless they pass a
    -- saveMode explicitly.
    local mode = tostring(saveMode or "legacy")
    local existing = nil

    if mode == "update" then
        existing = self.selectedPinId and self:GetPinById(self.selectedPinId) or nil
        if not existing then
            EPC:Print("Select a checkpoint before using UPDATE SELECTED.")
            return false
        end
    elseif mode == "new" then
        -- A new checkpoint must always get its own id, even in the same zone or
        -- at the same map position. If the typed name is already used, append a
        -- small numeric suffix so every saved row remains unambiguous.
        local wanted = name
        local used = {}
        for _, pin in ipairs(s.pins) do
            used[zo_strlower(trim(pin.name or ""))] = true
        end
        if used[zo_strlower(name)] then
            local n = 2
            repeat
                name = string.format("%s (%d)", wanted, n)
                n = n + 1
            until not used[zo_strlower(name)]
        end
    else
        existing = self.selectedPinId and self:GetPinById(self.selectedPinId) or nil
        if not existing then
            for _, pin in ipairs(s.pins) do
                if zo_strlower(trim(pin.name or "")) == zo_strlower(name) then existing = pin break end
            end
        end
    end

    local zoneId, worldX, worldY, worldZ = safe(GetUnitWorldPosition, 0, "player")
    local stamp = nowStamp()
    local pin = existing or { id=s.nextPinId, created=stamp }
    if not existing then
        s.nextPinId = s.nextPinId + 1
        s.pins[#s.pins+1] = pin
    end
    pin.name = name
    pin.x, pin.y = x, y
    pin.mapId = tonumber(safe(GetCurrentMapId, 0)) or 0
    pin.mapIndex = tonumber(safe(GetCurrentMapIndex, 0)) or 0
    pin.mapName, pin.zone = mapName, zone
    pin.zoneId = tonumber(zoneId) or 0
    pin.worldX, pin.worldY, pin.worldZ = tonumber(worldX) or 0, tonumber(worldY) or 0, tonumber(worldZ) or 0
    pin.modified = stamp
    pin.kind = "checkpoint"

    -- Capture the nearest discovered wayshrine while the map is already set to the
    -- player's current location. This makes newly saved checkpoints immediately travel-ready.
    self:GetNearestWayshrineForCheckpoint(pin, true)

    self.selectedPinId = pin.id
    self.checkpointPage = 1
    if self.checkpointNameEdit then self.checkpointNameEdit:SetText(name) end
    self:RefreshPinsPage()
    self:RefreshMapPins()
    EPC:Print((existing and "Checkpoint updated: " or "Checkpoint saved: ") .. name)
    return true
end

function J:DeletePin()
    local _, idx = self:GetPinById(self.selectedPinId)
    if not idx then return false end
    local removed = table.remove(self:EnsureSaved().pins, idx)
    self.selectedPinId = nil
    if self.checkpointNameEdit then self.checkpointNameEdit:SetText("") end
    self:RefreshPinsPage()
    self:RefreshMapPins()
    if removed then EPC:Print("Checkpoint deleted: " .. tostring(removed.name or "Checkpoint")) end
    return removed ~= nil
end

function J:DeleteCheckpointByName(query)
    local pin, matches = self:FindCheckpoint(query)
    if not pin then
        if #matches > 1 then
            EPC:Print("More than one checkpoint matches '" .. tostring(query) .. "'. Use a more specific name.")
        else
            EPC:Print("No checkpoint found for: " .. tostring(query))
        end
        return false
    end
    self.selectedPinId = pin.id
    return self:DeletePin()
end

function J:SetPinWaypoint(pinOverride)
    local pin = pinOverride or self:GetPinById(self.selectedPinId)
    if not pin then return false end

    -- Current ESO clients expose a world-location waypoint call. New checkpoints save
    -- world coordinates so the waypoint can be restored without depending on which
    -- map the player currently has open. Older saved pins fall back to map+PingMap.
    if type(SetPlayerWaypointByWorldLocation) == "function" and tonumber(pin.worldX) and tonumber(pin.worldZ) and (pin.worldX ~= 0 or pin.worldZ ~= 0) then
        local ok, success = pcall(SetPlayerWaypointByWorldLocation, pin.worldX, pin.worldY or 0, pin.worldZ)
        if ok and success == true then
            self.selectedPinId = pin.id
            EPC:Print("Checkpoint waypoint set: " .. tostring(pin.name or "Checkpoint"))
            return true
        end
    end

    local mapSet = false
    if type(SetMapToMapId) == "function" and tonumber(pin.mapId) and pin.mapId > 0 then
        local ok = pcall(SetMapToMapId, pin.mapId)
        mapSet = ok
    end
    if (not mapSet) and type(SetMapToMapListIndex) == "function" and tonumber(pin.mapIndex) and pin.mapIndex > 0 then
        mapSet = pcall(SetMapToMapListIndex, pin.mapIndex)
    end

    if type(PingMap) == "function" and MAP_PIN_TYPE_PLAYER_WAYPOINT and MAP_TYPE_LOCATION_CENTERED then
        local ok = pcall(PingMap, MAP_PIN_TYPE_PLAYER_WAYPOINT, MAP_TYPE_LOCATION_CENTERED, pin.x, pin.y)
        if not ok then
            EPC:Print("Could not place the checkpoint waypoint on this map.")
            return false
        end
    else
        EPC:Print("Waypoint API unavailable; open the World Map to view the saved checkpoint.")
        return false
    end

    if mapSet and type(CALLBACK_MANAGER) == "table" and CALLBACK_MANAGER.FireCallbacks then
        pcall(CALLBACK_MANAGER.FireCallbacks, CALLBACK_MANAGER, "OnWorldMapChanged")
    end
    self.selectedPinId = pin.id
    EPC:Print("Checkpoint waypoint set: " .. tostring(pin.name or "Checkpoint"))
    return true
end

function J:GoToCheckpoint(query)
    local pin, matches = self:FindCheckpoint(query)
    if not pin then
        if #matches > 1 then
            EPC:Print("Multiple checkpoints match '" .. tostring(query) .. "':")
            for i=1,math.min(8,#matches) do EPC:Print("- " .. tostring(matches[i].name or "Checkpoint")) end
            EPC:Print("Use a more specific checkpoint name.")
        else
            EPC:Print("No checkpoint found for: " .. tostring(query))
        end
        return false
    end
    return self:SetPinWaypoint(pin)
end

function J:ListCheckpoints()
    local pins = self:GetSortedCheckpoints()
    if #pins == 0 then
        EPC:Print("No checkpoints saved yet. Use /esosuite checkpoint save <name>.")
        return
    end
    EPC:Print(string.format("Saved checkpoints (%d):", #pins))
    for i=1,math.min(20,#pins) do
        local p = pins[i]
        EPC:Print(string.format("%d. %s  -  %s", i, tostring(p.name or "Checkpoint"), tostring(p.zone or p.mapName or "Unknown")))
    end
    if #pins > 20 then EPC:Print(string.format("...and %d more. Open Tamriel Codex > Checkpoints to browse them.", #pins-20)) end
end

function J:ChangeCheckpointPage(delta)
    local pins = self:GetSortedCheckpoints()
    local pageSize = #self.pinRows > 0 and #self.pinRows or 7
    local pages = math.max(1, math.ceil(#pins / pageSize))
    self.checkpointPage = math.max(1, math.min(pages, (tonumber(self.checkpointPage) or 1) + (tonumber(delta) or 0)))
    self:RefreshPinsPage()
end

function J:GetNearestWayshrineForCheckpoint(pin, forceRefresh)
    if type(pin) ~= "table" then return nil end

    if not forceRefresh and tonumber(pin.nearestWayshrineNodeIndex) and pin.nearestWayshrineNodeIndex > 0
        and EPC.Travel and EPC.Travel.GetWayshrineNodeEntry then
        local cached = EPC.Travel:GetWayshrineNodeEntry(pin.nearestWayshrineNodeIndex)
        if cached then
            cached.exactCheckpointMapMatch = pin.nearestWayshrineExact == true
            return cached
        end
    end

    if EPC.Travel and EPC.Travel.GetNearestWayshrineToCheckpoint then
        local entry, exact = EPC.Travel:GetNearestWayshrineToCheckpoint(pin)
        if entry then
            pin.nearestWayshrineNodeIndex = entry.nodeIndex
            pin.nearestWayshrineName = entry.name
            pin.nearestWayshrineZone = entry.zoneName
            pin.nearestWayshrineExact = exact == true
            return entry
        end
    end

    pin.nearestWayshrineNodeIndex = nil
    pin.nearestWayshrineName = nil
    pin.nearestWayshrineZone = nil
    pin.nearestWayshrineExact = nil
    return nil
end

function J:TravelToNearestCheckpointWayshrine()
    local pin = self:GetPinById(self.selectedPinId)
    if not pin then
        EPC:Print("Select a checkpoint first.")
        return false
    end
    local entry = self:GetNearestWayshrineForCheckpoint(pin, false)
    if not entry then
        EPC:Print("No discovered wayshrine could be matched to this checkpoint.")
        return false
    end
    if EPC.Travel and EPC.Travel.TravelToWayshrineNode then
        return EPC.Travel:TravelToWayshrineNode(entry.nodeIndex, entry.name)
    end
    EPC:Print("Travel helper is unavailable.")
    return false
end

function J:RefreshPinsPage()
    if not self.pinRows then return end
    local pins = self:GetSortedCheckpoints()
    local pageSize = #self.pinRows
    local pages = math.max(1, math.ceil(#pins / math.max(1,pageSize)))
    self.checkpointPage = math.max(1, math.min(pages, tonumber(self.checkpointPage) or 1))
    local first = (self.checkpointPage - 1) * pageSize + 1

    for i=1,#self.pinRows do
        local b = self.pinRows[i]
        local pin = pins[first + i - 1]
        if pin then
            local mark = pin.id == self.selectedPinId and "> " or ""
            b:SetText(string.format("%s%s   -   %s", mark, pin.name or "Checkpoint", pin.zone or pin.mapName or "Map"))
            b:SetHidden(false)
            b.pinId = pin.id
        else
            b:SetHidden(true)
            b.pinId = nil
        end
        setButtonStyle(b, pin and pin.id == self.selectedPinId, self:GetTheme())
    end

    if self.checkpointPageLabel then
        self.checkpointPageLabel:SetText(string.format("%d checkpoint%s   -   page %d/%d", #pins, #pins == 1 and "" or "s", self.checkpointPage, pages))
    end
    if self.checkpointPrev and self.checkpointPrev.SetEnabled then self.checkpointPrev:SetEnabled(self.checkpointPage > 1) end
    if self.checkpointNext and self.checkpointNext.SetEnabled then self.checkpointNext:SetEnabled(self.checkpointPage < pages) end

    if self.pinInfo then
        local p = self:GetPinById(self.selectedPinId)
        if p then
            local shrine = self:GetNearestWayshrineForCheckpoint(p, false)
            self.selectedCheckpointWayshrine = shrine
            local shrineText = "Nearest discovered wayshrine: None matched"
            if shrine then
                local shrineLabel = shrine.exactCheckpointMapMatch == false and "Available discovered wayshrine in zone" or "Nearest discovered wayshrine"
                shrineText = string.format("%s: %s\nTravel: %s - %s", shrineLabel, shrine.name or "Wayshrine", shrine.costText or "Cost unknown", shrine.statusText or "Ready")
            end
            setBookText(self.pinInfo, string.format("%s\n%s\nCoordinates: %.2f, %.2f\n\n%s\n\nSET WAYPOINT marks the exact checkpoint. TRAVEL TO WAYSHRINE takes you to the nearest discovered wayshrine ESO exposes for that saved area.", p.name or "Checkpoint", p.zone or p.mapName or "", (p.x or 0)*100, (p.y or 0)*100, shrineText), self.pinInfo:GetWidth())
            if self.pinWayshrine then
                if self.pinWayshrine.SetEnabled then self.pinWayshrine:SetEnabled(shrine ~= nil) end
                setButtonStyle(self.pinWayshrine, false, self:GetTheme())
            end
        else
            self.selectedCheckpointWayshrine = nil
            setBookText(self.pinInfo, "Save named places you want to revisit  -  XP farms, material routes, fishing spots, bosses, treasure areas, or anything else. Select a checkpoint to see its nearest discovered wayshrine and travel there, or place a waypoint on the exact saved location.", self.pinInfo:GetWidth())
            if self.pinWayshrine and self.pinWayshrine.SetEnabled then self.pinWayshrine:SetEnabled(false) end
        end
    end
end

function J:Roll(sides)
    sides = math.max(2, tonumber(sides) or 20)
    local result = math.random(1, sides)
    self.diceHistory = self.diceHistory or {}
    self.lastChanceKind = "DICE"
    self.lastChanceSides = sides
    self.lastChanceResult = tostring(result)
    table.insert(self.diceHistory, 1, string.format("d%d  ->  %d", sides, result))
    while #self.diceHistory > 12 do table.remove(self.diceHistory) end
    self:RefreshDice()
end

function J:TossCoin()
    self.diceHistory = self.diceHistory or {}
    local result = math.random(1,2) == 1 and "HEADS" or "TAILS"
    self.lastChanceKind = "COIN"
    self.lastChanceSides = nil
    self.lastChanceResult = result
    table.insert(self.diceHistory, 1, "Coin  ->  " .. result)
    while #self.diceHistory > 12 do table.remove(self.diceHistory) end
    self:RefreshDice()
end

function J:RefreshDice()
    local history = self.diceHistory or {}
    local historyText = #history > 0 and table.concat(history, "\n") or "Choose a die or toss a coin."
    if self.diceHistoryOutput then
        setBookText(self.diceHistoryOutput, historyText, self.diceHistoryOutput:GetWidth())
    elseif self.diceOutput then
        setBookText(self.diceOutput, historyText, self.diceOutput:GetWidth())
    end

    if self.diceResultTitle and self.diceResultValue and self.diceResultSub then
        if self.lastChanceKind == "COIN" then
            self.diceResultTitle:SetText("COIN TOSS")
            self.diceResultValue:SetText(self.lastChanceResult or "-")
            setBookText(self.diceResultSub, "A Septim-inspired flip for quick decisions and roleplay moments.", self.diceResultSub:GetWidth())
            if self.diceResultIcon then self.diceResultIcon:SetTexture(getChanceTexture("COIN")) end
        elseif self.lastChanceKind == "DICE" then
            local sides = tonumber(self.lastChanceSides) or 20
            self.diceResultTitle:SetText(string.format("D%d RESULT", sides))
            self.diceResultValue:SetText(tostring(self.lastChanceResult or "-"))
            setBookText(self.diceResultSub, string.format("Rolled on a D%d. Use it for checks, encounters, loot calls, or any roll your party needs.", sides), self.diceResultSub:GetWidth())
            if self.diceResultIcon then self.diceResultIcon:SetTexture(getChanceTexture("DICE", sides)) end
        else
            self.diceResultTitle:SetText("LUCK OF THE DRAW")
            self.diceResultValue:SetText("READY")
            setBookText(self.diceResultSub, "Choose a die or toss a coin to see the latest result here.", self.diceResultSub:GetWidth())
            if self.diceResultIcon then self.diceResultIcon:SetTexture(getChanceTexture("DICE", 20)) end
        end
    end
end

function J:BuildQuestText()
    local lines = {"ACTIVE QUEST DOCUMENTS", ""}
    local max = MAX_JOURNAL_QUESTS or 25
    local count = 0
    if type(GetJournalQuestName) == "function" then
        for i=1,max do
            local name = trim(safe(GetJournalQuestName, "", i))
            if name ~= "" then
                count = count + 1
                local level = tonumber(safe(GetJournalQuestLevel, 0, i)) or 0
                local zone = trim(safe(GetJournalQuestLocationInfo, "", i))
                lines[#lines+1] = string.format("%02d. %s%s", count, name, level > 0 and string.format("  [Lv %d]", level) or "")
                if zone ~= "" then lines[#lines+1] = "     " .. zone end
            end
        end
    end
    if count == 0 then lines[#lines+1] = "No active quests were found in the character journal." end
    lines[#lines+1] = ""
    lines[#lines+1] = "For quests you have not started, use the Suite's QUESTS tab."
    return table.concat(lines, "\n")
end

function J:BuildAchievementText()
    local lines = {"ACHIEVEMENT DOCUMENTS", ""}
    local earned = tonumber(safe(GetEarnedAchievementPoints, 0)) or 0
    local total = tonumber(safe(GetTotalAchievementPoints, 0)) or 0
    if total > 0 then lines[#lines+1] = string.format("Achievement Points: %d / %d", earned, total) end
    local ids = { safe(GetRecentlyCompletedAchievements, nil, 12) }
    local found = 0
    for i=1,#ids do
        local id = tonumber(ids[i]) or 0
        if id > 0 and type(GetAchievementInfo) == "function" then
            local name, description, points, _, completed = safe(GetAchievementInfo, "", id)
            name = trim(name)
            if name ~= "" then
                found = found + 1
                lines[#lines+1] = string.format("%s %s%s", completed and "[DONE]" or "-", name, tonumber(points) and points > 0 and string.format("  (%d pts)", points) or "")
                if description and description ~= "" then lines[#lines+1] = "   " .. trim(description) end
            end
        end
    end
    if found == 0 then lines[#lines+1] = "Recent achievement details are not currently exposed by the client." end
    return table.concat(lines, "\n")
end

function J:BuildStatsSpread()
    local name = trim(safe(GetUnitName, "Player", "player"))
    local display = trim(safe(GetDisplayName, ""))
    local level = tonumber(safe(GetUnitLevel, 0, "player")) or 0
    local cp = tonumber(safe(GetUnitChampionPoints, 0, "player")) or 0
    local zone = trim(safe(GetUnitZone, "", "player"))
    local bagUsed, bagSize = safe(GetNumBagUsedSlots, 0, BAG_BACKPACK), safe(GetBagSize, 0, BAG_BACKPACK)
    local money = tonumber(safe(GetCurrentMoney, 0)) or 0
    local inv,maxInv,stam,maxStam,speed,maxSpeed = safe(GetRidingStats, 0)

    local function commaNumber(value)
        local n = math.floor((tonumber(value) or 0) + 0.5)
        local sign = n < 0 and "-" or ""
        local digits = tostring(math.abs(n))
        local out = {}
        while #digits > 3 do
            table.insert(out, 1, string.sub(digits, -3))
            digits = string.sub(digits, 1, -4)
        end
        table.insert(out, 1, digits)
        return sign .. table.concat(out, ",")
    end

    local left = {
        "IDENTITY",
        string.format("Name: %s", name ~= "" and name or "Player"),
    }
    if display ~= "" then left[#left+1] = "Account: " .. display end
    left[#left+1] = ""
    left[#left+1] = "PROGRESSION"
    left[#left+1] = string.format("Level: %d", level)
    left[#left+1] = string.format("Champion Points: %d", cp)
    left[#left+1] = ""
    left[#left+1] = "LOCATION"
    left[#left+1] = "Zone: " .. (zone ~= "" and zone or "Unknown")
    left[#left+1] = ""
    left[#left+1] = "INVENTORY & WEALTH"
    left[#left+1] = string.format("Backpack: %d / %d", tonumber(bagUsed) or 0, tonumber(bagSize) or 0)
    left[#left+1] = string.format("Current Gold: %s", commaNumber(money))
    left[#left+1] = ""
    left[#left+1] = "RIDING TRAINING"
    left[#left+1] = string.format("Speed: %d / %d", tonumber(speed) or 0, tonumber(maxSpeed) or 0)
    left[#left+1] = string.format("Stamina: %d / %d", tonumber(stam) or 0, tonumber(maxStam) or 0)
    left[#left+1] = string.format("Carry Capacity: %d / %d", tonumber(inv) or 0, tonumber(maxInv) or 0)

    local spending = EPC.Activities and EPC.Activities.GetGoldSpendingView and EPC.Activities:GetGoldSpendingView() or { total = 0, rows = {} }
    local byKey = {}
    for _, row in ipairs(spending.rows or {}) do
        byKey[tostring(row.key or "")] = row
    end

    local right = {
        "GOLD SPENDING",
        "",
        "TOTAL TRACKED",
        "  " .. commaNumber(spending.total) .. " gold",
        "",
    }

    local function addSpendGroup(title, keys)
        local added = false
        local groupLines = {}
        for _, key in ipairs(keys) do
            local row = byKey[key]
            local amount = row and (tonumber(row.amount) or 0) or 0
            if amount > 0 then
                groupLines[#groupLines+1] = string.format("%s: %s", tostring(row.label or key), commaNumber(amount))
                added = true
            end
        end
        if added then
            right[#right+1] = ""
            right[#right+1] = title
            right[#right+1] = ""
            for i, line in ipairs(groupLines) do
                right[#right+1] = line
                if i < #groupLines then right[#right+1] = "" end
            end
            right[#right+1] = ""
        end
    end

    addSpendGroup("CRAFTING & EQUIPMENT", {
        "blacksmith", "clothier", "woodworker", "jeweler", "armsman", "armorer", "crafting",
    })
    addSpendGroup("SUPPLIES & SERVICES", {
        "alchemist", "enchanter", "grocer", "brewer", "chef", "merchant", "stable", "repairs", "respec", "travel",
        "bagSpace", "bankSpace", "bankFees", "buyback",
    })
    addSpendGroup("MARKET & SOCIAL", {
        "guildStore", "guildStoreFees", "cashOnDelivery", "playerTrade", "mail",
    })
    addSpendGroup("JUSTICE, GUILD & PVP", {
        "laundering", "bounty", "guildCosts", "pvpCosts", "tribute",
    })
    addSpendGroup("OTHER", {"other", "unclassified"})

    if (tonumber(spending.total) or 0) <= 0 then
        right[#right+1] = "No tracked spending yet."
        right[#right+1] = ""
    end
    right[#right+1] = ""
    right[#right+1] = "Tracking starts when this feature is installed."
    right[#right+1] = ""
    right[#right+1] = "Internal bank and guild-bank transfers are not counted as spending."

    return table.concat(left, "\n"), table.concat(right, "\n")
end

function J:BuildStatsText()
    local left, right = self:BuildStatsSpread()
    return left .. "\n\n" .. right
end

local CODEX = {
    ALCHEMY = [[ALCHEMY QUICK CODEX

Core effect pairs commonly used when experimenting:
- Restore Health  /  Ravage Health
- Restore Magicka  /  Ravage Magicka
- Restore Stamina  /  Ravage Stamina
- Increase Weapon/Spell Power  /  Lower Weapon/Spell Power
- Weapon/Spell Critical  /  Reduce Critical
- Armor  /  Fracture/Breach style resistance reduction
- Speed  /  Hindrance
- Invisibility  /  Detection
- Unstoppable  /  Entrapment

The game only reveals reagent traits your character has learned. Use this page as a planning reference, then verify the exact trait set on the in-game Alchemy station before crafting.]],
    RUNES = [[ENCHANTING RUNE CODEX

ESSENCE RUNES  -  what the glyph affects
- Oko  -  Health
- Makko  -  Magicka
- Deni  -  Stamina
- Dekeipa  -  Frost
- Meip  -  Shock
- Rakeipa  -  Flame
- Okori  -  Power
- Taderi  -  Physical Harm
- Makderi  -  Spell Harm
- Haoko  -  Disease
- Kuoko  -  Poison
- Oru  -  Alchemical Resistance
- Indeko  -  Prismatic / tri-stat family

ASPECT RUNES  -  quality
- Ta  -  Normal
- Jejota  -  Fine
- Denata  -  Superior
- Rekuta  -  Epic
- Kuta  -  Legendary

POTENCY RUNES determine level and whether the essence is additive or subtractive. Always verify the resulting glyph preview before creation.]],
    MATERIALS = [[CRAFTING MATERIAL CODEX

BLACKSMITHING
Iron  ->  Steel  ->  Orichalcum  ->  Dwarven  ->  Ebony  ->  Calcinium  ->  Galatite  ->  Quicksilver  ->  Voidstone  ->  Rubedite

CLOTHING
Rawhide/Jute  ->  Hide/Flax  ->  Leather/Cotton  ->  Thick Leather/Spidersilk  ->  Fell Hide/Ebonthread  ->  Topgrain/Kresh Fiber  ->  Iron Hide/Ironthread  ->  Superb Hide/Silverweave  ->  Shadowhide/Void Cloth  ->  Rubedo Leather/Ancestor Silk

WOODWORKING
Maple  ->  Oak  ->  Beech  ->  Hickory  ->  Yew  ->  Birch  ->  Ash  ->  Mahogany  ->  Nightwood  ->  Ruby Ash

JEWELRY
Pewter  ->  Copper  ->  Silver  ->  Electrum  ->  Platinum

Research traits and improvement materials are character/account progression systems; the Codex is intended as a quick reference rather than a replacement for the crafting station's authoritative preview.]],
}

function J:SetCodexMode(mode)
    if CODEX[mode] then self.codexMode = mode self:RefreshCodex() end
end
function J:GetCodexText()
    return CODEX[self.codexMode or "ALCHEMY"] or ""
end

local RefreshCodexImplArch

function J:RefreshCodex(...)
    return RefreshCodexImplArch(self, ...)
end

RefreshCodexImplArch = function(self)
    if self.codexBody then setBookText(self.codexBody, CODEX[self.codexMode or "ALCHEMY"] or "", self.codexBody:GetWidth()) end
    for mode,b in pairs(self.codexButtons or {}) do setButtonStyle(b, mode == (self.codexMode or "ALCHEMY"), self:GetTheme()) end
end

local RefreshDocumentPageImplArch

function J:RefreshDocumentPage(...)
    return RefreshDocumentPageImplArch(self, ...)
end

RefreshDocumentPageImplArch = function(self)
    local page = self.pages and self.pages[self.activeTab]
    local body = page and page.body
    if not body then return end
    if self.activeTab == "ACHIEVEMENTS" then setBookText(body, self:BuildAchievementText(), body:GetWidth())
    elseif self.activeTab == "STATS" then setBookText(body, self:BuildStatsText(), body:GetWidth()) end
end

local function addViewStats(lines, stats)
    if type(stats) ~= "table" then return end
    for i=1,#stats do
        local row = stats[i]
        if row then lines[#lines+1] = string.format("%s: %s", tostring(row.label or ""), tostring(row.value or "")) end
    end
end

local function addViewItems(lines, header, items, limit)
    if type(items) ~= "table" or #items == 0 then return end
    lines[#lines+1] = ""
    if header and header ~= "" then lines[#lines+1] = tostring(header) end
    limit = math.min(#items, tonumber(limit) or 6)
    for i=1,limit do lines[#lines+1] = "- " .. tostring(items[i]) end
end

function J:CreateSuitePage(parent, name)
    local page = wm:CreateControl("EAS_Journal_Suite_"..name, parent, CT_CONTROL)
    page:SetAnchorFill(parent)
    local w, h = math.max(320, parent:GetWidth()), math.max(420, parent:GetHeight())
    local body = makeLabel("EAS_Journal_SuiteBody_"..name, page, "", 0, 0, w, h-72, "ZoFontGame")
    self.themeLabels[#self.themeLabels+1] = body
    page.body = body
    page.buttons = {}
    local gap = 7
    local cols = (name == "SKILLS") and 2 or ((name == "TOOLS") and 4 or 3)
    local buttonCount = (name == "TOOLS") and 8 or 6
    local rows = math.ceil(buttonCount / cols)
    local bw = math.floor((w - gap*(cols-1)) / cols)
    local buttonH = (name == "SKILLS") and 32 or 27
    local startY
    if name == "SKILLS" then
        startY = h - 103
        body:SetHeight(h-112)
    elseif name == "TOOLS" then
        -- Keep the full two-row Utilities control grid well inside the page.
        -- Some Codex layouts report a shorter page host than the outer canvas,
        -- so bottom-anchored rows could place SIZE/OPACITY controls below the
        -- visible page. Reserve a large footer-safe region and move both rows up.
        startY = math.max(250, h - 178)
        body:SetHeight(math.max(210, startY - 12))
    else
        startY = h - 64
    end
    for i=1,buttonCount do
        local row = math.floor((i-1) / cols)
        local col = (i-1) % cols
        local b = makeButton("EAS_Journal_SuiteAction_"..name.."_"..i, page, "", col*(bw+gap), startY + row*(buttonH+5), bw, buttonH, function() self:RunSuiteAction(name, i) end)
        b:SetHidden(true)
        page.buttons[i] = b
    end
    return page
end

function J:SetSuiteButtons(tab, labels)
    local page = self.pages and self.pages[tab]
    if not page or not page.buttons then return end
    local theme = self:GetTheme()
    for i=1,#page.buttons do
        local b = page.buttons[i]
        local label = labels and labels[i] or nil
        if label and label ~= "" then
            b:SetText(label)
            b:SetHidden(false)
            setButtonStyle(b, false, theme)
        else
            b:SetHidden(true)
        end
    end
end

function J:CycleOrder(current, order)
    local idx = 1
    for i=1,#order do if order[i] == current then idx = i break end end
    idx = idx + 1
    if idx > #order then idx = 1 end
    return order[idx]
end

function J:RefreshReticleToolsFast()
    local page = self.pages and self.pages.TOOLS
    if not page or not page.leftBody or not page.rightBody or not EPC.UtilitySuite then return end
    local v = EPC.UtilitySuite:BuildReticleView(EPC.lastSnapshot or {}) or {}
    local left = {tostring(v.title or "Custom Reticle")}
    if v.description and v.description ~= "" then
        left[#left+1] = ""
        left[#left+1] = tostring(v.description)
    end
    if v.stats then
        left[#left+1] = ""
        addViewStats(left, v.stats)
    end
    -- Reticle text is intentionally short and already fits the Utilities page.
    -- Avoid the expensive wrap/measure/font-fit pass used by the full page renderer.
    page.leftBody:SetText(table.concat(left, "\n"))
    local right = {"RETICLE CONTROLS", "",
        "1. ON / OFF",
        "2. STYLE",
        "3. COLOR",
        "4. SIZE - / SIZE +",
        "5. OPACITY - / OPACITY +",
        "",
        "Changes apply immediately."}
    page.rightBody:SetText(table.concat(right, "\n"))
    self:SetSuiteButtons("TOOLS", {"MODE","ON / OFF","STYLE","COLOR","SIZE -","SIZE +","OPACITY -","OPACITY +"})
end

function J:RunSuiteAction(tab, action)
    if tab == "GEAR" and EPC.SetJournal then
        if action == 1 then EPC.SetJournal:SetFilter(self:CycleOrder(EPC.SetJournal.filter or "ALL", {"ALL","OVERLAND","DUNGEON","TRIAL"}))
        elseif action == 2 then EPC.SetJournal:PromptSearch()
        elseif action == 3 then EPC.SetJournal:ChangePage(-1)
        elseif action == 4 then EPC.SetJournal:ChangePage(1)
        elseif action == 5 then local v=EPC.SetJournal:BuildView(); local n=#(v.rows or {}); if n>0 then self.suiteRowIndex.GEAR=(self.suiteRowIndex.GEAR % n)+1 EPC.SetJournal:SelectRow(self.suiteRowIndex.GEAR) end
        elseif action == 6 then EPC.SetJournal:RouteSelected() end
    elseif tab == "QUESTS" and EPC.QuestFinder then
        if action == 1 then EPC.QuestFinder:SetFilter(self:CycleOrder(EPC.QuestFinder.filter or "NOT_STARTED", {"NOT_STARTED","ACTIVE","ALL"})) EPC:RefreshNow("codex-quest-filter")
        elseif action == 2 then EPC.QuestFinder:Scroll(-(EPC.QuestFinder.PAGE_SIZE or 8))
        elseif action == 3 then EPC.QuestFinder:Scroll(EPC.QuestFinder.PAGE_SIZE or 8)
        elseif action == 4 then local v=EPC.QuestFinder:BuildView(); local n=#(v.rows or {}); if n>0 then self.suiteRowIndex.QUESTS=(self.suiteRowIndex.QUESTS % n)+1 EPC.QuestFinder:SelectRow(self.suiteRowIndex.QUESTS) end
        elseif action == 5 then EPC.QuestFinder:RouteSelected() end
    elseif tab == "TRAVEL" and EPC.Travel then
        if action == 1 then EPC.Travel:SetMode(self:CycleOrder(EPC.Travel:GetMode(), EPC.Travel.modeOrder or {"SHRINES","FRIENDS","GUILD","GROUP"}))
        elseif action == 2 then EPC.Travel:ChangePage(-1, EPC.Travel.BOOK_PAGE_SIZE or 8)
        elseif action == 3 then EPC.Travel:ChangePage(1, EPC.Travel.BOOK_PAGE_SIZE or 8)
        elseif action == 4 then local ps=EPC.Travel.BOOK_PAGE_SIZE or 8; local v=EPC.Travel:BuildView(EPC.lastSnapshot or {}, ps); local n=#(v.rows or {}); if n>0 then self.suiteRowIndex.TRAVEL=(self.suiteRowIndex.TRAVEL % n)+1 EPC.Travel:SelectVisibleRow(self.suiteRowIndex.TRAVEL, ps) end
        elseif action == 5 then EPC.Travel:TravelSelected() end
    elseif tab == "ACTIVITY" and EPC.Activities then
        if action == 1 then EPC.Activities:SetGoal(self:CycleOrder(EPC.Activities:GetGoal(), {"BALANCED","XP","GOLD"}))
        elseif action == 2 then local v=EPC.Activities:BuildView(EPC.lastSnapshot or {}); local n=#(v.rows or {}); if n>0 then self.suiteRowIndex.ACTIVITY=(self.suiteRowIndex.ACTIVITY % n)+1 EPC.Activities:SelectVisibleRow(self.suiteRowIndex.ACTIVITY) end
        end
    elseif tab == "TOOLS" and EPC.UtilitySuite then
        local mode = EPC.UtilitySuite:GetMode()
        if action == 1 then EPC.UtilitySuite:SetMode(self:CycleOrder(mode, {"OVERVIEW","INVENTORY","RESEARCH","COLLECTIONS","DAILIES","RETICLE","SELL"}))
        elseif mode == "RETICLE" and action == 2 then EPC.UtilitySuite:ToggleReticle()
        elseif mode == "RETICLE" and action == 3 then EPC.UtilitySuite:CycleReticleStyle()
        elseif mode == "RETICLE" and action == 4 then EPC.UtilitySuite:CycleReticleColor()
        elseif mode == "RETICLE" and action == 5 then EPC.UtilitySuite:DecreaseReticleSize()
        elseif mode == "RETICLE" and action == 6 then EPC.UtilitySuite:IncreaseReticleSize()
        elseif mode == "RETICLE" and action == 7 then EPC.UtilitySuite:DecreaseReticleOpacity()
        elseif mode == "RETICLE" and action == 8 then EPC.UtilitySuite:IncreaseReticleOpacity()
        elseif mode == "SELL" and EPC.VendorSell then
            if action == 2 then EPC.VendorSell:SelectDelta(-1)
            elseif action == 3 then EPC.VendorSell:SelectDelta(1)
            elseif action == 4 then EPC.VendorSell:SellSelected()
            elseif action == 5 then EPC.VendorSell:SellJunk()
            elseif action == 6 then EPC.VendorSell:ClearConfirmation() EPC.VendorSell:Refresh() end
        end
    elseif tab == "SKILLS" then
        local ts = nowStamp()
        if self.skillActionLockUntil and ts > 0 and ts < self.skillActionLockUntil then
            if EPC and EPC.Notify then EPC:Notify("Skills & Champion is already processing the last action.") end
            return
        end
        if action >= 1 and action <= 3 then
            self.skillActionLockUntil = ts > 0 and (ts + 2) or nil
        end
        if action == 1 and EPC.GearOptimizer and EPC.GearOptimizer.RespecAndApplyBestBuild then
            EPC.GearOptimizer:RespecAndApplyBestBuild()
            EPC:RefreshNow("codex-skill-respec-build")
        elseif action == 2 and EPC.ChampionOptimizer and EPC.ChampionOptimizer.ApplyBestChampionBuild then
            EPC.ChampionOptimizer:ApplyBestChampionBuild()
            EPC:RefreshNow("codex-champion-redistribute")
        elseif action == 3 and EPC.AttributeOptimizer and EPC.AttributeOptimizer.ApplyBestAttributes then
            EPC.AttributeOptimizer:ApplyBestAttributes()
            EPC:RefreshNow("codex-attribute-redistribute")
        elseif action == 4 then
            EPC:RefreshNow("codex-refresh")
        end
        if action >= 1 and action <= 3 and type(zo_callLater) == "function" then
            zo_callLater(function()
                self.skillActionLockUntil = nil
                if EPC and EPC.RefreshNow then EPC:RefreshNow("codex-skill-followup-refresh") end
                if self.window and not self.window:IsHidden() then self:RefreshSuitePage("SKILLS") end
            end, 700)
        else
            self.skillActionLockUntil = nil
        end
    elseif tab == "BUILD" or tab == "COMBAT" then
        EPC:RefreshNow("codex-refresh")
    end
    if self.window and not self.window:IsHidden() then
        if tab == "TOOLS" and EPC.UtilitySuite and EPC.UtilitySuite:GetMode() == "RETICLE" and action >= 2 and action <= 8 then
            self:RefreshReticleToolsFast()
        else
            self:RefreshSuitePage(tab)
        end
    end
end

function J:BuildSuiteText(tab)
    local model = EPC.lastModel
    if not model and EPC.RefreshNow then EPC:RefreshNow("codex-open") model = EPC.lastModel end
    local lines = {}
    local base = model and model.tabs and model.tabs[tab] or nil
    if base then
        if base.title and base.title ~= "" then lines[#lines+1] = tostring(base.title) end
        if base.description and base.description ~= "" then lines[#lines+1] = "" lines[#lines+1] = tostring(base.description) end
        if base.stats then lines[#lines+1] = "" addViewStats(lines, base.stats) end
        addViewItems(lines, base.listHeader, base.items, 6)
    end

    if tab == "GEAR" and EPC.SetJournal then
        local v = EPC.SetJournal:BuildView()
        lines[#lines+1] = ""
        lines[#lines+1] = string.format("SET JOURNAL  -  %s  -  page %d/%d", tostring(v.filter or "ALL"), tonumber(v.page) or 1, tonumber(v.pageCount) or 1)
        for i,row in ipairs(v.rows or {}) do
            local mark = v.selected and v.selected.setId == row.setId and ">" or "-"
            lines[#lines+1] = string.format("%s %s  [%d/%d]", mark, tostring(row.name or "Set"), tonumber(row.unlocked) or 0, tonumber(row.total) or 0)
            lines[#lines+1] = "   " .. tostring(row.sourceText or row.kindText or "")
        end
        if v.hint then lines[#lines+1] = "" lines[#lines+1] = tostring(v.hint) end
    elseif tab == "QUESTS" and EPC.QuestFinder then
        local v = EPC.QuestFinder:BuildView()
        lines[#lines+1] = string.format("%s  -  %d matches  -  %s", tostring(v.filter or "NOT_STARTED"), tonumber(v.total) or 0, tostring(v.scanProgress or ""))
        lines[#lines+1] = ""
        for _,row in ipairs(v.rows or {}) do
            local mark = v.selected and v.selected.key == row.key and ">" or "-"
            lines[#lines+1] = string.format("%s %s", mark, tostring(row.name or "Quest"))
            lines[#lines+1] = string.format("   %s  -  %s", tostring(row.zone or "Unknown zone"), tostring(row.status or row.type or "Quest"))
        end
        if v.selected then lines[#lines+1] = "" lines[#lines+1] = tostring(v.selected.starter or v.selected.access or "") end
    elseif tab == "TRAVEL" and EPC.Travel then
        local v = EPC.Travel:BuildView(EPC.lastSnapshot or {}, EPC.Travel.BOOK_PAGE_SIZE or 8)
        lines[#lines+1] = tostring(v.title or "Travel")
        lines[#lines+1] = tostring(v.description or "")
        lines[#lines+1] = ""
        lines[#lines+1] = string.format("%s  -  page %d/%d", tostring(v.modeLabel or v.mode or "Travel"), tonumber(v.page) or 1, tonumber(v.pageCount) or 1)
        for _,row in ipairs(v.rows or {}) do
            local mark = v.selected and v.selected.key == row.key and ">" or "-"
            lines[#lines+1] = string.format("%s %s", mark, tostring(row.name or "Destination"))
            lines[#lines+1] = string.format("   %s  -  %s", tostring(row.zoneName or "Unknown zone"), tostring(row.statusText or row.costText or ""))
        end
        if v.hint then lines[#lines+1] = "" lines[#lines+1] = tostring(v.hint) end
    elseif tab == "ACTIVITY" and EPC.Activities then
        local v = EPC.Activities:BuildView(EPC.lastSnapshot or {})
        lines[#lines+1] = tostring(v.title or "Activities")
        lines[#lines+1] = tostring(v.description or "")
        lines[#lines+1] = ""
        addViewStats(lines, v.stats)
        lines[#lines+1] = ""
        for _,row in ipairs(v.rows or {}) do
            local mark = v.selected and v.selected.key == row.key and ">" or "-"
            lines[#lines+1] = mark .. " " .. tostring(row.name or row.displayText or "Activity")
            if row.detailText then lines[#lines+1] = "   " .. tostring(row.detailText) end
        end
        if v.hint then lines[#lines+1] = "" lines[#lines+1] = tostring(v.hint) end
    elseif tab == "SKILLS" and EPC.GearOptimizer and EPC.GearOptimizer.BuildBestAbilityView then
        local v = EPC.GearOptimizer:BuildBestAbilityView()
        local c = v.context or {}
        lines[#lines+1] = ""
        lines[#lines+1] = "CURRENT-BUILD SKILL OPTIMIZER"
        lines[#lines+1] = string.format("Build: %s  -  Role: %s", tostring(c.profile and c.profile.label or "Detected build"), tostring(c.role or "DAMAGE"))
        lines[#lines+1] = string.format("Weapons: %s / %s", tostring(c.frontWeapon or "Weapon"), tostring(c.backWeapon or "Weapon"))
        if #(c.sets or {}) > 0 then lines[#lines+1] = "Worn sets: " .. table.concat(c.sets, ", ") end
        lines[#lines+1] = ""
        local meta=v.meta
        if meta and EPC.SkillMeta then
            lines[#lines+1] = "SKILL META: CURRENT"
            lines[#lines+1] = string.format("Profile: %s  -  Preset: %s", tostring(meta.label or "Current build"), tostring(meta.preset or "TRIAL"))
            lines[#lines+1] = string.format("Confidence: %s", tostring(meta.confidence or "CURATED"))
            lines[#lines+1] = ""
        end
        lines[#lines+1] = "PRIMARY BAR"
        for i,a in ipairs(v.abilities or {}) do lines[#lines+1] = string.format("%d. %s", i, tostring(a.name or "Ability")) end
        lines[#lines+1] = string.format("ULT. %s", tostring(v.ultimate and v.ultimate.name or "No Ultimate available"))
        lines[#lines+1] = ""
        lines[#lines+1] = "BACKUP BAR"
        for i,a in ipairs(v.backAbilities or {}) do lines[#lines+1] = string.format("%d. %s", i, tostring(a.name or "Ability")) end
        lines[#lines+1] = string.format("ULT. %s", tostring(v.backUltimate and v.backUltimate.name or "No Ultimate available"))
        lines[#lines+1] = ""
        if EPC.ChampionOptimizer and EPC.ChampionOptimizer.BuildView then
            local cpv=EPC.ChampionOptimizer:BuildView()
            lines[#lines+1] = ""
            lines[#lines+1] = "CHAMPION POINT OPTIMIZER"
            lines[#lines+1] = string.format("Redistribution cost: %d gold (ESO live value)", tonumber(cpv.cost) or 0)
            for _,pool in ipairs(cpv.pools or {}) do
                lines[#lines+1] = string.format("%s  -  %d/%d points planned", tostring(pool.label), tonumber(pool.spent) or 0, tonumber(pool.budget) or 0)
                for _,star in ipairs(pool.top or {}) do lines[#lines+1] = string.format("  - %s: %d%s", tostring(star.name), tonumber(star.points) or 0, star.slottable and " [SLOT]" or "") end
            end
            lines[#lines+1] = "MAX POWER CP rebuilds Craft/Warfare/Fitness from the MAX POWER skill plan, detected role/content, Direct/DoT/AoE/Single-Target mix, and penetration need. It selects up to four active stars per discipline and spends the rest by marginal value. A paid respec requires confirmation."
        end
        if EPC.AttributeOptimizer and EPC.AttributeOptimizer.BuildView then
            local av=EPC.AttributeOptimizer:BuildView()
            lines[#lines+1] = ""
            lines[#lines+1] = "ATTRIBUTE OPTIMIZER"
            lines[#lines+1] = string.format("Detected: %s  -  %s", tostring(av.role or "DAMAGE"), tostring(av.build or "Current build"))
            lines[#lines+1] = string.format("Current: %d Health / %d Magicka / %d Stamina  (+%d unspent)", tonumber(av.current and av.current.health) or 0, tonumber(av.current and av.current.magicka) or 0, tonumber(av.current and av.current.stamina) or 0, tonumber(av.current and av.current.unspent) or 0)
            lines[#lines+1] = string.format("Recommended: %d Health / %d Magicka / %d Stamina", tonumber(av.target and av.target.health) or 0, tonumber(av.target and av.target.magicka) or 0, tonumber(av.target and av.target.stamina) or 0)
            lines[#lines+1] = string.format("Redistribution cost: %d gold (ESO live value)", tonumber(av.cost) or 0)
            lines[#lines+1] = "REDISTRIBUTE ATTR uses the normal ESO attribute respec request, scales the recommendation to the character's available points, and requires a second confirmation before a paid respec."
        end

    elseif tab == "TOOLS" and EPC.UtilitySuite then
        local v = EPC.UtilitySuite:BuildView(EPC.lastSnapshot or {})
        lines[#lines+1] = tostring(v.title or "Utilities")
        lines[#lines+1] = tostring(v.description or "")
        lines[#lines+1] = ""
        addViewStats(lines, v.stats)
        addViewItems(lines, v.listHeader or ("MODE: " .. tostring(v.modeLabel or v.mode or "OVERVIEW")), v.rows or v.items, 7)
        if v.hint then lines[#lines+1] = "" lines[#lines+1] = tostring(v.hint) end
    end

    if #lines == 0 then lines = {"This Codex section is waiting for character data.", "", "Use REFRESH or reopen the Codex after the character has loaded."} end
    return table.concat(lines, "\n")
end

local RefreshSuitePageImplArch

function J:RefreshSuitePage(...)
    return RefreshSuitePageImplArch(self, ...)
end

RefreshSuitePageImplArch = function(self, tab)
    tab = tab or self.activeTab
    if not SUITE_TABS[tab] then return end
    local page = self.pages and self.pages[tab]
    if not page or not page.body then return end
    setBookText(page.body, self:BuildSuiteText(tab), page.body:GetWidth())
    if tab == "GEAR" then self:SetSuiteButtons(tab, {"FILTER","SEARCH","< PAGE","PAGE >","SELECT","ROUTE"})
    elseif tab == "QUESTS" then self:SetSuiteButtons(tab, {"FILTER","< PAGE","PAGE >","SELECT","ROUTE"})
    elseif tab == "TRAVEL" then self:SetSuiteButtons(tab, {"MODE","< PAGE","PAGE >","SELECT","TRAVEL"})
    elseif tab == "ACTIVITY" then self:SetSuiteButtons(tab, {"GOAL","SELECT","ROUTE"})
    elseif tab == "TOOLS" then
        local toolMode = EPC.UtilitySuite and EPC.UtilitySuite:GetMode() or "OVERVIEW"
        if toolMode == "RETICLE" then
            self:SetSuiteButtons(tab, {"MODE","ON / OFF","STYLE","COLOR","SIZE -","SIZE +","OPACITY -","OPACITY +"})
        elseif toolMode == "SELL" then
            self:SetSuiteButtons(tab, {"MODE","< ITEM","ITEM >","SELL ITEM","SELL JUNK","REFRESH"})
        else
            self:SetSuiteButtons(tab, {"MODE"})
        end
    elseif tab == "SKILLS" then self:SetSuiteButtons(tab, {"MAX POWER BUILD","MAX POWER CP","MAX POWER ATTRIBUTES"})
    else self:SetSuiteButtons(tab, {"REFRESH"}) end
end

local PlayPageTurnImplArch

function J:PlayPageTurn(...)
    return PlayPageTurnImplArch(self, ...)
end

PlayPageTurnImplArch = function(self)
    if not self.flipPage then return end
    local t = self:GetTheme()
    self.flipPage:SetCenterColor(unpack(t.page2 or t.page or t.panel))
    self.flipPage:SetEdgeColor(unpack(t.edge))
    self.flipPage:SetHidden(false)
    self.flipPage:SetAlpha(1)
    self.flipPage:SetScale(1)
    self.flipPage:ClearAnchors()
    self.flipPage:SetAnchor(TOPLEFT, self.rightContent or self.window, TOPLEFT, 0, self.rightContent and 88 or 238)

    if not ANIMATION_MANAGER or not ANIMATION_MANAGER.CreateTimeline or not ANIMATION_SCALE or not ANIMATION_ALPHA then
        self.flipPage:SetHidden(true)
        return
    end
    if self.pageTurnTimeline and self.pageTurnTimeline.IsPlaying and self.pageTurnTimeline:IsPlaying() then self.pageTurnTimeline:Stop() end
    local tl = ANIMATION_MANAGER:CreateTimeline()
    local shrink = tl:InsertAnimation(ANIMATION_SCALE, self.flipPage, 0)
    shrink:SetScaleValues(1.0, 0.08)
    shrink:SetDuration(150)
    local fade1 = tl:InsertAnimation(ANIMATION_ALPHA, self.flipPage, 0)
    fade1:SetAlphaValues(1.0, 0.72)
    fade1:SetDuration(150)
    tl:InsertCallback(function()
        self.flipPage:ClearAnchors()
        self.flipPage:SetAnchor(TOPLEFT, self.leftNavigation or self.window, TOPLEFT, 0, self.leftNavigation and 88 or 238)
    end, 155)
    local expand = tl:InsertAnimation(ANIMATION_SCALE, self.flipPage, 160)
    expand:SetScaleValues(0.08, 1.0)
    expand:SetDuration(150)
    local fade2 = tl:InsertAnimation(ANIMATION_ALPHA, self.flipPage, 160)
    fade2:SetAlphaValues(0.72, 0.0)
    fade2:SetDuration(150)
    tl:InsertCallback(function()
        self.flipPage:SetHidden(true)
        self.flipPage:SetAlpha(1)
        self.flipPage:SetScale(1)
    end, 315)
    self.pageTurnTimeline = tl
    if self.turnSound and type(PlaySound) == "function" then pcall(PlaySound, self.turnSound) end
    tl:PlayFromStart()
end

function J:TurnPage(delta)
    local current = 1
    for i=1,#TABS do if TABS[i] == self.activeTab then current = i break end end
    local nextIndex = current + (tonumber(delta) or 1)
    if nextIndex < 1 then nextIndex = #TABS end
    if nextIndex > #TABS then nextIndex = 1 end
    self:SetTab(TABS[nextIndex])
end

local SetTabImplArch

function J:SetTab(...)
    return SetTabImplArch(self, ...)
end

SetTabImplArch = function(self, tab)
    self:SaveCurrentEntry()
    local changed = self.activeTab ~= nil and self.activeTab ~= tab
    self.activeTab = tab
    self:EnsureSaved().activeTab = tab
    if self.pageNumber then
        local idx = 1
        for i=1,#TABS do if TABS[i] == tab then idx = i break end end
        self.pageNumber:SetText(string.format("Page %s", TAB_PAGE_NUMBERS[tab] or tostring(idx)))
    end
    if self.currentSummary or self.sectionSubtitle then
        local sub = ({
            NOTES = "Personal field reports, notes, and records",
            PINS = "Named places to revisit for farming, XP, routes, and exploration",
            BUILD = "Character build guidance and next priorities",
            GEAR = "Gear audit, Item Set Collection, and source routing",
            SKILLS = "Skill points, weapon bars, and Champion priorities",
            COMBAT = "Role-aware combat analysis and recent fight data",
            ACTIVITY = "XP, gold, quest, and activity planning",
            QUESTS = "Find active or not-yet-started quests and route toward them",
            TRAVEL = "Wayshrines, friends, guild, and group travel",
            TOOLS = "Inventory, research, collections, and daily utilities",
            ACHIEVEMENTS = "Achievement notes and completed milestones",
            STATS = "Character records, riding, inventory, and wealth",
            CODEX = "Crafting codex and reference material",
            DICE = "Roleplay dice and coin tosses",
        })[tab] or ""
        if self.currentSummary then setBookText(self.currentSummary, sub, self.currentSummary:GetWidth()) end
        if self.sectionSubtitle then setBookText(self.sectionSubtitle, sub, self.sectionSubtitle:GetWidth()) end
    end
    if self.modeButton then self.modeButton:SetText(self.readMode and "EDIT" or "READ") end
    if self.sectionTitle then self.sectionTitle:SetText(TAB_TITLES[tab] or tab) end
    if self.currentHeader then self.currentHeader:SetText(string.format("CURRENT CHAPTER  -  %s", TAB_LABELS[tab] or tab)) end
    local notesTab = tab == "NOTES"
    if self.newButton then self.newButton:SetHidden(not notesTab) end
    if self.saveButton then self.saveButton:SetHidden(not notesTab) end
    if self.deleteButton then self.deleteButton:SetHidden(not notesTab) end
    if self.modeButton then self.modeButton:SetHidden(not notesTab) end
    if self.themeButton then self.themeButton:SetHidden(false) end
    if self.closeButton then self.closeButton:SetHidden(false) end
    local showCategories = notesTab
    if self.categoryHeader then self.categoryHeader:SetHidden(not showCategories) end
    for _, b in pairs(self.categoryButtons or {}) do b:SetHidden(not showCategories) end
    if self.deleteButton and self.deleteButton.SetEnabled then self.deleteButton:SetEnabled(showCategories and self.currentEntryId ~= nil) end
    for name,page in pairs(self.pages or {}) do page:SetHidden(name ~= tab) end
    if SUITE_TABS[tab] then
        if EPC.saved then EPC.saved.activeTab = (tab == "TRAVEL" and "MAP" or tab) end
        if EPC.RefreshNow then EPC:RefreshNow("codex-" .. string.lower(tab)) end
        self:RefreshSuitePage(tab)
    elseif tab == "NOTES" then self:RefreshNotes()
    elseif tab == "PINS" then self:RefreshPinsPage()
    elseif tab == "DICE" then self:RefreshDice()
    elseif tab == "CODEX" then self:RefreshCodex()
    else self:RefreshDocumentPage() end
    self:ApplyTheme()
    if changed and self.window and not self.window:IsHidden() then self:PlayPageTurn() end
end

function J:CreateNotesPage(parent)
    local page = wm:CreateControl("EAS_Journal_NotesPage", parent, CT_CONTROL)
    page:SetAnchorFill(parent)
    self.notePage = page
    local w, h = math.max(320, parent:GetWidth()), math.max(420, parent:GetHeight())
    local listW = math.floor(w * 0.34)
    local editorX = listW + 16
    local editorW = w - editorX

    self.noteCount = makeLabel("EAS_Journal_NoteCount", page, "", 0, 0, listW, 22, "ZoFontGameSmall")
    self.themeLabels[#self.themeLabels+1] = self.noteCount
    self.noteRows = {}
    for i=1,10 do
        local b = makeButton("EAS_Journal_NoteRow"..i, page, "", 0, 28+(i-1)*32, listW, 28, function(control)
            if control.entryId then self:SelectEntry(control.entryId) end
        end)
        b:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        self.noteRows[i] = b
    end

    local divider = wm:CreateControl("EAS_Journal_NotesDivider", page, CT_BACKDROP)
    divider:SetAnchor(TOPLEFT, page, TOPLEFT, listW + 7, 8)
    divider:SetDimensions(1, h - 24)
    divider:SetCenterColor(0.26,0.17,0.08,0.25)
    divider:SetEdgeColor(0,0,0,0)

    self.noteTitleEdit = self:CreateEditBox("EAS_Journal_TitleEdit", page, editorX, 6, editorW, 34, false)
    self.noteTitleEdit:SetFont("ZoFontGameBold")
    local bodyH = math.max(280, h - 98)
    self.noteBodyEdit = self:CreateEditBox("EAS_Journal_BodyEdit", page, editorX, 52, editorW, bodyH, true)
    self.noteBodyEdit:SetFont("ZoFontGame")
    local autosave = makeLabel("EAS_Journal_Autosave", page, "Auto-saved when changing pages or closing the Tamriel Codex.", editorX, 58 + bodyH, editorW, 34, "ZoFontGameSmall")
    self.themeLabels[#self.themeLabels+1] = autosave
    return page
end

function J:CreatePinsPage(parent)
    local page = wm:CreateControl("EAS_Journal_PinsPage", parent, CT_CONTROL)
    page:SetAnchorFill(parent)
    local w, h = math.max(320, parent:GetWidth()), math.max(420, parent:GetHeight())

    local nameLabel = makeLabel("EAS_Journal_CheckpointNameLabel", page, "CHECKPOINT NAME", 0, 0, w, 20, "ZoFontGameSmall")
    self.themeLabels[#self.themeLabels+1] = nameLabel
    self.checkpointNameEdit = wm:CreateControl("EAS_Journal_CheckpointNameEdit", page, CT_EDITBOX)
    self.checkpointNameEdit:SetAnchor(TOPLEFT, page, TOPLEFT, 0, 22)
    self.checkpointNameEdit:SetDimensions(w, 32)
    self.checkpointNameEdit:SetFont("ZoFontGame")
    if self.checkpointNameEdit.SetMaxInputChars then self.checkpointNameEdit:SetMaxInputChars(80) end
    self.checkpointNameEdit:SetColor(0.15,0.09,0.04,1)

    self.pinRows = {}
    for i=1,7 do
        local b = makeButton("EAS_Journal_PinRow"..i, page, "", 0, 64+(i-1)*34, w, 30, function(control)
            self.selectedPinId = control.pinId
            local selected = self:GetPinById(control.pinId)
            if selected and self.checkpointNameEdit then self.checkpointNameEdit:SetText(selected.name or "") end
            self:RefreshPinsPage()
        end)
        b:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        self.pinRows[i] = b
    end

    self.checkpointPrev = makeButton("EAS_Journal_CheckpointPrev", page, "< PREV", 0, 306, 86, 26, function() self:ChangeCheckpointPage(-1) end)
    self.checkpointPageLabel = makeLabel("EAS_Journal_CheckpointPageLabel", page, "", 94, 308, w-188, 22, "ZoFontGameSmall")
    self.checkpointPageLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.themeLabels[#self.themeLabels+1] = self.checkpointPageLabel
    self.checkpointNext = makeButton("EAS_Journal_CheckpointNext", page, "NEXT >", w-86, 306, 86, 26, function() self:ChangeCheckpointPage(1) end)

    self.pinInfo = makeLabel("EAS_Journal_PinInfo", page, "", 0, 340, w, math.max(82, h-438), "ZoFontGame")
    self.themeLabels[#self.themeLabels+1] = self.pinInfo

    local half = math.floor((w - 12) / 2)
    self.pinSave = makeButton("EAS_Journal_PinSave", page, "SAVE / UPDATE HERE", 0, h-78, half, 32, function()
        self:SaveCurrentLocation(self.checkpointNameEdit and self.checkpointNameEdit:GetText() or "")
    end)
    self.pinWaypoint = makeButton("EAS_Journal_PinWaypoint", page, "WAYPOINT", half+12, h-78, half, 32, function() self:SetPinWaypoint() end)
    self.pinDelete = makeButton("EAS_Journal_PinDelete", page, "DELETE CHECKPOINT", math.floor((w-190)/2), h-40, 190, 28, function() self:DeletePin() end)
    return page
end

function J:CreateDicePage(parent)
    local page = wm:CreateControl("EAS_Journal_DicePage", parent, CT_CONTROL)
    page:SetAnchorFill(parent)
    local w, h = math.max(320, parent:GetWidth()), math.max(420, parent:GetHeight())
    local title = makeLabel("EAS_Journal_DiceTitle", page, "ROLEPLAY TOOLS", 0, 0, w, 34, "ZoFontWinH2")
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.themeLabels[#self.themeLabels+1] = title
    local dice = {4,6,8,10,12,20,100}
    local cell = math.floor(w / 4)
    for i,sides in ipairs(dice) do
        local col = (i-1) % 4
        local row = zo_floor((i-1) / 4)
        makeButton("EAS_Journal_D"..sides, page, "D"..sides, col*cell+4, 56+row*46, cell-8, 34, function() self:Roll(sides) end)
    end
    makeButton("EAS_Journal_Coin", page, "TOSS COIN", math.floor(w*0.25), 154, math.floor(w*0.5), 36, function() self:TossCoin() end)
    self.diceOutput = makeLabel("EAS_Journal_DiceOutput", page, "Choose a die or toss a coin.", 12, 216, w-24, h-228, "ZoFontGame")
    self.diceOutput:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.themeLabels[#self.themeLabels+1] = self.diceOutput
    return page
end

function J:CreateDocumentPage(parent, name)
    local page = wm:CreateControl("EAS_Journal_"..name.."Page", parent, CT_CONTROL)
    page:SetAnchorFill(parent)
    local w, h = math.max(320, parent:GetWidth()), math.max(420, parent:GetHeight())
    local body = makeLabel("EAS_Journal_"..name.."Body", page, "", 0, 0, w, h, "ZoFontGame")
    self.themeLabels[#self.themeLabels+1] = body
    page.body = body
    return page
end

function J:CreateCodexPage(parent)
    local page = wm:CreateControl("EAS_Journal_CodexPage", parent, CT_CONTROL)
    page:SetAnchorFill(parent)
    local w, h = math.max(320, parent:GetWidth()), math.max(420, parent:GetHeight())
    self.codexButtons = {}
    local modes = {"ALCHEMY","RUNES","MATERIALS"}
    local bw = math.floor((w - 12) / 3)
    for i,mode in ipairs(modes) do
        self.codexButtons[mode] = makeButton("EAS_Journal_Codex"..mode, page, mode, (i-1)*(bw+6), 0, bw, 32, function() self:SetCodexMode(mode) end)
    end
    self.codexBody = makeLabel("EAS_Journal_CodexBody", page, "", 0, 48, w, h-48, "ZoFontGame")
    self.themeLabels[#self.themeLabels+1] = self.codexBody
    return page
end

-- Locate an action by name and compare a raw OnKeyDown event with any of
-- that action's keyboard binding slots. This deliberately bypasses active
-- action-layer routing while the Codex is open.
function J:RawKeyMatchesAction(actionName, key, ctrl, alt, shift, command)
    if type(GetNumActionLayers) ~= "function" or type(GetActionLayerInfo) ~= "function"
        or type(GetActionLayerCategoryInfo) ~= "function" or type(GetActionInfo) ~= "function"
        or type(GetActionBindingInfo) ~= "function" then
        return false
    end

    local function modifierPresent(modifierKey, m1, m2, m3, m4)
        if type(ZO_Keybindings_DoesKeyMatchAnyModifiers) == "function" then
            return ZO_Keybindings_DoesKeyMatchAnyModifiers(modifierKey, m1, m2, m3, m4) == true
        end
        return m1 == modifierKey or m2 == modifierKey or m3 == modifierKey or m4 == modifierKey
    end

    local numLayers = GetNumActionLayers() or 0
    for layerIndex = 1, numLayers do
        local _, numCategories = GetActionLayerInfo(layerIndex)
        for categoryIndex = 1, (numCategories or 0) do
            local _, numActions = GetActionLayerCategoryInfo(layerIndex, categoryIndex)
            for actionIndex = 1, (numActions or 0) do
                local name = GetActionInfo(layerIndex, categoryIndex, actionIndex)
                if name == actionName then
                    -- Keyboard actions normally expose two binding slots. Check a few
                    -- slots defensively; invalid/unbound slots simply do not match.
                    for bindingIndex = 1, 4 do
                        local boundKey, m1, m2, m3, m4 = GetActionBindingInfo(layerIndex, categoryIndex, actionIndex, bindingIndex)
                        if boundKey and boundKey ~= KEY_INVALID and boundKey == key then
                            local wantCtrl = modifierPresent(KEY_CTRL, m1, m2, m3, m4)
                            local wantAlt = modifierPresent(KEY_ALT, m1, m2, m3, m4)
                            local wantShift = modifierPresent(KEY_SHIFT, m1, m2, m3, m4)
                            local wantCommand = KEY_COMMAND and modifierPresent(KEY_COMMAND, m1, m2, m3, m4) or false
                            if (ctrl == true) == wantCtrl and (alt == true) == wantAlt
                                and (shift == true) == wantShift and (command == true) == wantCommand then
                                return true
                            end
                        end
                    end
                    return false
                end
            end
        end
    end
    return false
end

local CreateImplArch

function J:Create(...)
    return CreateImplArch(self, ...)
end

CreateImplArch = function(self)
    local window = wm:CreateTopLevelWindow("EAS_CustomJournal")
    self.window = window
    window:SetDimensions(1024, 1024)
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, -8)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:SetMouseEnabled(true)
    window:SetHidden(true)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetDrawTier(DT_HIGH)

    -- v5: Capture the Codex toggle key directly while this top-level window
    -- has UI focus. Action-layer dispatch can be suppressed while camera UI mode
    -- is active, so compare the raw key event against the user's saved binding.
    if window.SetKeyboardEnabled then
        window:SetKeyboardEnabled(true)
    end
    window:SetHandler("OnKeyDown", function(_, key, ctrl, alt, shift, command)
        if self.window:IsHidden() then return end
        if self:RawKeyMatchesAction("ESO_PROGRESSION_COACH_TOGGLE", key, ctrl, alt, shift, command) then
            self:Hide()
        end
    end)

    local rootHeight = tonumber(GuiRoot and GuiRoot.GetHeight and GuiRoot:GetHeight()) or 1080
    if rootHeight < 1060 and window.SetScale then
        window:SetScale(math.max(0.72, (rootHeight - 28) / 1024))
    end

    local nativeBook = getNativeLoreBookMedium()
    self.nativeBook = nativeBook

    local bookTexture = wm:CreateControl("EAS_CustomJournal_NativeLoreBook", window, CT_TEXTURE)
    bookTexture:SetAnchorFill(window)
    if nativeBook then bookTexture:SetTexture(nativeBook.bg) end
    bookTexture:SetTextureCoords(0,1,0,1)
    bookTexture:SetMouseEnabled(false)
    self.bookTexture = bookTexture
    self.openSound = nativeBook and nativeBook.openSound or nil
    self.closeSound = nativeBook and nativeBook.closeSound or nil
    self.turnSound = nativeBook and nativeBook.turnPageSound or nil

    -- Fallback paper only appears if the client cannot provide the native Lore Reader medium.
    local bg = wm:CreateControl("EAS_CustomJournal_BG", window, CT_BACKDROP)
    bg:SetAnchor(TOPLEFT, window, TOPLEFT, 68, 108)
    bg:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -68, -108)
    bg:SetEdgeTexture(nil, 2, 2, 2)
    bg:SetCenterColor(0.95,0.89,0.76, nativeBook and 0 or 1)
    bg:SetEdgeColor(0.34,0.22,0.10, nativeBook and 0 or 0.85)
    self.bg = bg

    local pageW = tonumber(nativeBook and nativeBook.pageWidth) or 374
    local pageH = tonumber(nativeBook and nativeBook.pageHeight) or 620
    pageW = math.max(340, math.min(410, pageW))
    pageH = math.max(560, math.min(690, pageH))

    -- Left page: persistent chapter navigation, aligned to the native Lore Reader page geometry.
    local leftNav = wm:CreateControl("EAS_CustomJournal_LeftNavigation", window, CT_CONTROL)
    if nativeBook then leftNav:SetAnchor(LEFT, window, LEFT, tonumber(nativeBook.leftPageXOffset) or 0, tonumber(nativeBook.pageYOffset) or 0)
    else leftNav:SetAnchor(TOPLEFT, window, TOPLEFT, 126, 172) end
    leftNav:SetDimensions(pageW, pageH)
    self.leftNavigation = leftNav

    local title = makeLabel("EAS_CustomJournal_Title", leftNav, "TAMRIEL CODEX", 0, 0, pageW, 38, "ZoFontWinH2")
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    local subtitle = makeLabel("EAS_CustomJournal_Subtitle", leftNav, "INDEX OF CHAPTERS", 12, 36, pageW-24, 22, "ZoFontGameBold")
    subtitle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    local indexIntro = makeLabel("EAS_CustomJournal_IndexIntro", leftNav, "Choose a chapter on the left page. The right page displays its contents.", 18, 60, pageW-36, 34, "ZoFontGameSmall")
    indexIntro:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    local rule = wm:CreateControl("EAS_CustomJournal_LeftRule", leftNav, CT_BACKDROP)
    rule:SetAnchor(TOPLEFT, leftNav, TOPLEFT, 28, 98)
    rule:SetDimensions(pageW-56, 1)
    rule:SetCenterColor(0.26,0.17,0.08,0.32)
    rule:SetEdgeColor(0,0,0,0)

    self.title, self.subtitle, self.indexIntro = title, subtitle, indexIntro
    self.panels, self.themeLabels, self.tabButtons, self.pages = {}, {title, subtitle, indexIntro}, {}, {}

    self.tabPageLabels = {}
    for i,tab in ipairs(TABS) do
        local label = TAB_LABELS[tab] or TAB_TITLES[tab] or tab
        local rowY = 114 + (i-1)*24
        local b = makeButton("EAS_CustomJournal_Tab"..tab, leftNav, label, 20, rowY, pageW-78, 20, function() self:SetTab(tab) end)
        b:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        self.tabButtons[tab] = b
        local num = makeLabel("EAS_CustomJournal_TabPage"..tab, leftNav, TAB_PAGE_NUMBERS[tab] or tostring(i), pageW-58, rowY, 34, 20, "ZoFontGameSmall")
        num:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        self.tabPageLabels[tab] = num
        self.themeLabels[#self.themeLabels+1] = num
    end

    local currentHeader = makeLabel("EAS_CustomJournal_CurrentHeader", leftNav, "CURRENT CHAPTER", 20, pageH-212, pageW-40, 20, "ZoFontGameBold")
    local currentSummary = makeLabel("EAS_CustomJournal_CurrentSummary", leftNav, "Select an entry from the index to begin reading.", 20, pageH-188, pageW-40, 74, "ZoFontGame")
    currentSummary:SetVerticalAlignment(TEXT_ALIGN_TOP)
    self.currentHeader, self.currentSummary = currentHeader, currentSummary
    self.themeLabels[#self.themeLabels+1] = currentHeader
    self.themeLabels[#self.themeLabels+1] = currentSummary

    local categoryHeader = makeLabel("EAS_CustomJournal_CategoryHeader", leftNav, "NOTE CATEGORIES", 20, pageH-106, pageW-40, 20, "ZoFontGameSmall")
    self.themeLabels[#self.themeLabels+1] = categoryHeader
    self.categoryHeader = categoryHeader
    self.categoryButtons = {}
    for i,cat in ipairs(CATEGORIES) do
        local col = (i-1) % 2
        local row = zo_floor((i-1) / 2)
        local catW = math.floor((pageW - 48) / 2)
        local b = makeButton("EAS_Journal_Cat"..i, leftNav, cat, 18 + col*(catW+12), pageH-82 + row*22, catW, 20, function() self:SetCategory(cat) end)
        b:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        self.categoryButtons[cat] = b
    end
    local leftPageNumber = makeLabel("EAS_CustomJournal_LeftPageNumber", leftNav, "INDEX", 0, pageH-24, pageW, 20, "ZoFontGameSmall")
    leftPageNumber:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.leftPageNumber = leftPageNumber
    self.themeLabels[#self.themeLabels+1] = leftPageNumber

    -- Right page: book actions at the top, section content below.
    local rightPage = wm:CreateControl("EAS_CustomJournal_RightContent", window, CT_CONTROL)
    if nativeBook then rightPage:SetAnchor(RIGHT, window, RIGHT, tonumber(nativeBook.rightPageXOffset) or 0, tonumber(nativeBook.pageYOffset) or 0)
    else rightPage:SetAnchor(TOPLEFT, window, TOPLEFT, 550, 158) end
    rightPage:SetDimensions(pageW, pageH)
    self.rightContent = rightPage

    local gap = 4
    local actionW = math.floor((pageW - gap*5) / 6)
    local newB = makeButton("EAS_CustomJournal_New", rightPage, "NEW", 0, 0, actionW, 28, function()
        if self.activeTab ~= "NOTES" then self:SetTab("NOTES") end
        self:NewEntry()
    end)
    local saveB = makeButton("EAS_CustomJournal_Save", rightPage, "SAVE", actionW+gap, 0, actionW, 28, function() self:SaveCurrentEntry() end)
    local deleteB = makeButton("EAS_CustomJournal_Delete", rightPage, "DEL", (actionW+gap)*2, 0, actionW, 28, function()
        if self.activeTab == "NOTES" then self:DeleteEntry() end
    end)
    local mode = makeButton("EAS_CustomJournal_Mode", rightPage, "READ", (actionW+gap)*3, 0, actionW, 28, function()
        self.readMode = not self.readMode
        self:EnsureSaved().readMode = self.readMode
        self:SetEditorEnabled(not self.readMode)
        self:ApplyTheme()
    end)
    local theme = makeButton("EAS_CustomJournal_Theme", rightPage, "THEME", (actionW+gap)*4, 0, actionW, 28, function() self:CycleTheme() end)
    local close = makeButton("EAS_CustomJournal_Close", rightPage, "CLOSE", (actionW+gap)*5, 0, actionW, 28, function() self:Hide() end)
    self.newButton, self.saveButton, self.deleteButton = newB, saveB, deleteB
    self.modeButton, self.themeButton, self.closeButton = mode, theme, close
    self.topButtons = {newB, saveB, deleteB, mode, theme, close}

    local sectionTitle = makeLabel("EAS_CustomJournal_RightTitle", rightPage, "TAMRIEL CODEX", 0, 40, pageW, 30, "ZoFontWinH2")
    sectionTitle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    local sectionSubtitle = makeLabel("EAS_CustomJournal_RightSubtitle", rightPage, "", 12, 68, pageW-24, 32, "ZoFontGame")
    sectionSubtitle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    local rightRule = wm:CreateControl("EAS_CustomJournal_RightRule", rightPage, CT_BACKDROP)
    rightRule:SetAnchor(TOPLEFT, rightPage, TOPLEFT, 0, 104)
    rightRule:SetDimensions(pageW, 1)
    rightRule:SetCenterColor(0.26,0.17,0.08,0.34)
    rightRule:SetEdgeColor(0,0,0,0)
    self.sectionTitle = sectionTitle
    self.sectionSubtitle = sectionSubtitle
    self.themeLabels[#self.themeLabels+1] = sectionTitle
    self.themeLabels[#self.themeLabels+1] = sectionSubtitle

    local content = wm:CreateControl("EAS_CustomJournal_Content", rightPage, CT_CONTROL)
    content:SetAnchor(TOPLEFT, rightPage, TOPLEFT, 0, 118)
    content:SetDimensions(pageW, pageH-152)
    self.content = content

    self.pages.NOTES = self:CreateNotesPage(content)
    self.pages.PINS = self:CreatePinsPage(content)
    self.pages.BUILD = self:CreateSuitePage(content, "BUILD")
    self.pages.GEAR = self:CreateSuitePage(content, "GEAR")
    self.pages.SKILLS = self:CreateSuitePage(content, "SKILLS")
    self.pages.COMBAT = self:CreateSuitePage(content, "COMBAT")
    self.pages.ACTIVITY = self:CreateSuitePage(content, "ACTIVITY")
    self.pages.DUNGEONS = self:CreateSuitePage(content, "DUNGEONS")
    self.pages.BATTLEGROUNDS = self:CreateSuitePage(content, "BATTLEGROUNDS")
    self.pages.GROUPFINDER = self:CreateSuitePage(content, "GROUPFINDER")
    self.pages.QUESTS = self:CreateSuitePage(content, "QUESTS")
    self.pages.TRAVEL = self:CreateSuitePage(content, "TRAVEL")
    self.pages.TOOLS = self:CreateSuitePage(content, "TOOLS")
    self.pages.ACHIEVEMENTS = self:CreateDocumentPage(content, "ACHIEVEMENTS")
    self.pages.STATS = self:CreateDocumentPage(content, "STATS")
    self.pages.CODEX = self:CreateCodexPage(content)
    self.pages.DICE = self:CreateDicePage(content)
    self.suiteRowIndex = { GEAR=0, QUESTS=0, TRAVEL=0, ACTIVITY=0, DUNGEONS=0, BATTLEGROUNDS=0, GROUPFINDER=0 }

    local prevPage = makeButton("EAS_CustomJournal_PrevPage", rightPage, "< PREV", 6, pageH-28, 88, 26, function() self:TurnPage(-1) end)
    local pageNumber = makeLabel("EAS_CustomJournal_PageNumber", rightPage, "Page 1 / 7", math.floor((pageW-150)/2), pageH-26, 150, 22, "ZoFontGameSmall")
    pageNumber:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    local nextPage = makeButton("EAS_CustomJournal_NextPage", rightPage, "NEXT >", pageW-94, pageH-28, 88, 26, function() self:TurnPage(1) end)
    self.prevPageButton, self.nextPageButton, self.pageNumber = prevPage, nextPage, pageNumber
    self.themeLabels[#self.themeLabels+1] = pageNumber

    -- A translucent parchment sheet provides the page-turn illusion without replacing the native book art.
    local flip = wm:CreateControl("EAS_CustomJournal_FlipPage", window, CT_BACKDROP)
    flip:SetDimensions(pageW, pageH-96)
    flip:SetAnchor(TOPLEFT, rightPage, TOPLEFT, 0, 88)
    flip:SetEdgeTexture(nil, 1, 1, 1)
    flip:SetDrawLayer(DL_OVERLAY)
    flip:SetHidden(true)
    self.flipPage = flip
    local flipMark = makeLabel("EAS_CustomJournal_FlipMark", flip, "TAMRIEL CODEX", 20, math.floor((pageH-130)/2), pageW-40, 30, "ZoFontWinH2")
    flipMark:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.themeLabels[#self.themeLabels+1] = flipMark

    window:SetHandler("OnMoveStop", function(control)
        local s = self:EnsureSaved()
        s.left, s.top = control:GetLeft(), control:GetTop()
    end)
    local s = self:EnsureSaved()
    if tonumber(s.left) and tonumber(s.top) and s.left >= 0 and s.top >= 0 then
        window:ClearAnchors()
        window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, s.left, s.top)
    end

    self.category = s.category or "ALL"
    self.activeTab = s.activeTab or "NOTES"
    self.readMode = s.readMode == true
    self.codexMode = "ALCHEMY"
    self:SetEditorEnabled(not self.readMode)
    self:SetTab(self.activeTab)
    self:RegisterMapPins()
end

function J:ActivateCodexActionLayer()
    if not self.window or self.window:IsHidden() then return end
    if type(PushActionLayerByName) ~= "function" then return end

    -- UI mode can rebuild the active action-layer stack. Push only after the
    -- Codex is actually visible, and refresh once on the next UI tick.
    if self.codexActionLayerPushed and type(RemoveActionLayerByName) == "function" then
        pcall(RemoveActionLayerByName, "ESOAdventurerSuiteCodexLayer")
        self.codexActionLayerPushed = false
    end

    local ok = pcall(PushActionLayerByName, "ESOAdventurerSuiteCodexLayer")
    self.codexActionLayerPushed = ok == true

    if type(zo_callLater) == "function" then
        zo_callLater(function()
            if not self.window or self.window:IsHidden() then return end
            if type(RemoveActionLayerByName) == "function" then
                pcall(RemoveActionLayerByName, "ESOAdventurerSuiteCodexLayer")
            end
            local pushed = pcall(PushActionLayerByName, "ESOAdventurerSuiteCodexLayer")
            self.codexActionLayerPushed = pushed == true
        end, 100)
    end
end

local ShowImplArch

function J:Show(...)
    return ShowImplArch(self, ...)
end

ShowImplArch = function(self)
    if not self.window then return end

    local already = safe(IsGameCameraUIModeActive, false) == true
    self.ownsUIMode = not already
    if not already then
        if type(SetGameCameraUIMode) == "function" then pcall(SetGameCameraUIMode, true)
        elseif SCENE_MANAGER and SCENE_MANAGER.SetInUIMode then pcall(SCENE_MANAGER.SetInUIMode, SCENE_MANAGER, true) end
    end
    self.window:SetHidden(false)
    self:ActivateCodexActionLayer()
    if self.openSound and type(PlaySound) == "function" then pcall(PlaySound, self.openSound) end
    if SUITE_TABS[self.activeTab] then self:RefreshSuitePage(self.activeTab) end
    self:RefreshDocumentPage()
    self:RefreshPinsPage()
    if EPC.RepairCostOverlay and EPC.RepairCostOverlay.Refresh then
        EPC.RepairCostOverlay:Refresh()
    end
end

local HideImplArch

function J:Hide(...)
    return HideImplArch(self, ...)
end

HideImplArch = function(self)
    if not self.window then return end
    self:SaveCurrentEntry()
    self.window:SetHidden(true)

    if self.codexActionLayerPushed and type(RemoveActionLayerByName) == "function" then
        pcall(RemoveActionLayerByName, "ESOAdventurerSuiteCodexLayer")
        self.codexActionLayerPushed = false
    end
    if self.closeSound and type(PlaySound) == "function" then pcall(PlaySound, self.closeSound) end
    if self.ownsUIMode then
        if type(SetGameCameraUIMode) == "function" then pcall(SetGameCameraUIMode, false)
        elseif SCENE_MANAGER and SCENE_MANAGER.SetInUIMode then pcall(SCENE_MANAGER.SetInUIMode, SCENE_MANAGER, false) end
    end
    self.ownsUIMode = false
    if EPC.RepairCostOverlay and EPC.RepairCostOverlay.Refresh then
        EPC.RepairCostOverlay:Refresh()
    end
end

function J:Toggle()
    if not self.window then return end

    -- If the detached Saved Builds workspace is open, the suite key should
    -- switch back to the Tamriel Codex instead of leaving both workspaces open.
    local loadouts = EPC and EPC.LoadoutManager
    if loadouts and loadouts.window and not loadouts.window:IsHidden() then
        local transferred = false
        if type(loadouts.TransferUIModeToCodex) == "function" then
            transferred = loadouts:TransferUIModeToCodex() == true
        end
        if type(loadouts.Hide) == "function" then
            loadouts:Hide(true)
        else
            loadouts.window:SetHidden(true)
        end

        self:Show()
        if transferred then
            -- Preserve ownership so closing the Codex returns to character control
            -- when the original workspace was opened from normal gameplay.
            self.ownsUIMode = true
        end
        return
    end

    if self.window:IsHidden() then self:Show() else self:Hide() end
end

function J:Initialize()
    self:EnsureSaved()
    self:Create()
    EVENT_MANAGER:RegisterForEvent(EPC.name .. "_JournalMap", EVENT_PLAYER_ACTIVATED, function() self:RefreshMapPins() end)
end

--[[
    v0.19.0 two-page Codex override
    Keeps the existing data/model layer intact, but replaces the single-content-page
    book layout with a true two-page spread plus an index and edge chapter tabs.
]]

TABS = {"INDEX", "NOTES", "PINS", "BUILD", "GEAR", "SKILLS", "COMBAT", "ACTIVITY", "DUNGEONS", "BATTLEGROUNDS", "GROUPFINDER", "QUESTS", "TRAVEL", "TOOLS", "ACHIEVEMENTS", "STATS", "CODEX", "DICE"}
TAB_LABELS.INDEX = "Index"
TAB_LABELS.DICE = "Dice & Coin"
TAB_TITLES.INDEX = "TAMRIEL CODEX"

local EAS_TAB_SHORT = {
    INDEX="INDEX", NOTES="NOTES", PINS="PINS", BUILD="BUILD", GEAR="GEAR", SKILLS="SKILLS", COMBAT="COMBAT",
    ACTIVITY="ACTIVITY", DUNGEONS="DUNGEONS", BATTLEGROUNDS="BGS", GROUPFINDER="GROUPS", QUESTS="QUESTS", TRAVEL="TRAVEL", TOOLS="TOOLS", ACHIEVEMENTS="ACHV", STATS="STATS",
    CODEX="CRAFT", DICE="DICE",
}

local EAS_TAB_DESCRIPTIONS = {
    INDEX="A two-page index of your records, routes, guides, and discoveries.",
    NOTES="Personal notes and field reports. Browse on the left page and write on the right.",
    PINS="Named checkpoints for XP farms, material routes, bosses, fishing spots, and places worth revisiting.",
    BUILD="Character build guidance, priorities, and progression notes.",
    GEAR="Item-set collection progress, set sources, and route guidance.",
    SKILLS="Skill points, bars, progression, and Champion Point guidance.",
    COMBAT="Role-aware combat information and recent fight analysis.",
    ACTIVITY="Activities for XP, gold, quests, and progression goals.",
    DUNGEONS="All detected 4-player dungeons sorted alphabetically, with Base Game versus DLC / Chapter labeling.",
    BATTLEGROUNDS="Live ESO Battleground Finder queues, availability, team size, daily reward state, and queue controls.",
    GROUPFINDER="Browse live player-created ESO Group Finder listings by category and difficulty.",
    QUESTS="Quest discovery and routing for active and not-yet-started quests.",
    TRAVEL="Wayshrines, group, guild, and social travel destinations.",
    TOOLS="Inventory, research, collections, daily tasks, and utility information.",
    ACHIEVEMENTS="Achievement records and recent milestones.",
    STATS="Character statistics, riding progress, inventory, and wealth.",
    CODEX="Crafting reference pages for alchemy, enchanting runes, and materials.",
    DICE="Roleplay dice and coin tosses.",
}

local function easSplitSpreadText(text)
    text = tostring(text or "")
    local lines = {}
    for line in string.gmatch(text .. "\n", "(.-)\n") do lines[#lines+1] = line end
    if #lines <= 1 then return text, "" end

    local weights, total = {}, 0
    for i,line in ipairs(lines) do
        local len = string.len(line)
        local w = math.max(1, math.ceil(math.max(1, len) / 44))
        if line == "" then w = 1 end
        weights[i] = w
        total = total + w
    end
    local target = math.max(1, math.floor((total + 1) / 2))
    local used, splitAt = 0, math.max(1, math.floor(#lines / 2))
    for i,w in ipairs(weights) do
        used = used + w
        if used >= target then splitAt = i break end
    end
    if splitAt >= #lines then splitAt = math.max(1, #lines - 1) end

    local left, right = {}, {}
    for i,line in ipairs(lines) do
        if i <= splitAt then left[#left+1] = line else right[#right+1] = line end
    end
    return table.concat(left, "\n"), table.concat(right, "\n")
end

local function easMakeRule(name, parent, y, width)
    local rule = wm:CreateControl(name, parent, CT_BACKDROP)
    rule:SetAnchor(TOPLEFT, parent, TOPLEFT, 14, y)
    rule:SetDimensions(math.max(1, width - 28), 1)
    rule:SetCenterColor(0.26,0.17,0.08,0.28)
    rule:SetEdgeColor(0,0,0,0)
    return rule
end

local CreateSpreadShellImplArch

function J:CreateSpreadShell(...)
    return CreateSpreadShellImplArch(self, ...)
end

CreateSpreadShellImplArch = function(self, name)
    local spread = wm:CreateControl("EAS_CodexSpread_"..name, self.window, CT_CONTROL)
    spread:SetAnchorFill(self.window)

    local left = wm:CreateControl("EAS_CodexSpread_"..name.."_Left", spread, CT_CONTROL)
    left:SetAnchor(TOPLEFT, self.leftPageHost, TOPLEFT, 0, 0)
    left:SetDimensions(self.pageW, self.pageH)

    local right = wm:CreateControl("EAS_CodexSpread_"..name.."_Right", spread, CT_CONTROL)
    right:SetAnchor(TOPLEFT, self.rightPageHost, TOPLEFT, 0, 0)
    right:SetDimensions(self.pageW, self.pageH)

    spread.left, spread.right = left, right
    spread.key = name
    return spread
end

local AddSpreadHeaderImplArch

function J:AddSpreadHeader(...)
    return AddSpreadHeaderImplArch(self, ...)
end

AddSpreadHeaderImplArch = function(self, spread, leftTitle, rightTitle)
    local key = tostring(spread.key or leftTitle or "Spread"):gsub("%W", "")
    local lt = makeLabel("EAS_Codex_"..key.."_LeftTitle", spread.left, leftTitle or "", 8, 4, self.pageW-16, 34, "ZoFontWinH2")
    lt:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    local rt = makeLabel("EAS_Codex_"..key.."_RightTitle", spread.right, rightTitle or leftTitle or "", 8, 4, self.pageW-16, 34, "ZoFontWinH2")
    rt:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    easMakeRule("EAS_CodexRuleL_"..key, spread.left, 42, self.pageW)
    easMakeRule("EAS_CodexRuleR_"..key, spread.right, 42, self.pageW)
    self.themeLabels[#self.themeLabels+1] = lt
    self.themeLabels[#self.themeLabels+1] = rt
    spread.leftTitle, spread.rightTitle = lt, rt
end

function J:CreateIndexSpread()
    local spread = self:CreateSpreadShell("INDEX")
    self:AddSpreadHeader(spread, "TAMRIEL CODEX", "INDEX")

    local intro = makeLabel("EAS_CodexIndexIntro", spread.left,
        "Your all-in-one Tamriel command center. Choose a workspace from the navigation rail or use the arrows to move between tools.",
        20, 58, self.pageW-40, 74, "ZoFontGame")
    self.themeLabels[#self.themeLabels+1] = intro
    setBookText(intro, intro:GetText(), intro:GetWidth())

    local indexTabs = {}
    for _,tab in ipairs(TABS) do if tab ~= "INDEX" then indexTabs[#indexTabs+1] = tab end end
    local leftCount = math.ceil(#indexTabs / 2)
    for i,tab in ipairs(indexTabs) do
        local parent = i <= leftCount and spread.left or spread.right
        local localIndex = i <= leftCount and i or (i-leftCount)
        local y = (i <= leftCount and 150 or 70) + (localIndex-1)*48
        local pageIndex = 1
        for idx,name in ipairs(TABS) do if name == tab then pageIndex = idx break end end
        local firstPage = (pageIndex-1)*2 + 1
        local label = string.format("%-18s  %d", TAB_LABELS[tab] or tab, firstPage)
        local b = makeButton("EAS_CodexIndex_"..tab, parent, label, 24, y, self.pageW-48, 34, function() self:SetTab(tab) end)
        b:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        setButtonStyle(b, false, self:GetTheme())
    end

    local foot = makeLabel("EAS_CodexIndexFoot", spread.right,
        "Use the left navigation to jump directly to any tool. The workspace keeps your current section, position, size, and interface preferences.",
        24, self.pageH-126, self.pageW-48, 78, "ZoFontGameSmall")
    self.themeLabels[#self.themeLabels+1] = foot
    setBookText(foot, foot:GetText(), foot:GetWidth())
    return spread
end

local CreateNotesSpreadImplArch

function J:CreateNotesSpread(...)
    return CreateNotesSpreadImplArch(self, ...)
end

CreateNotesSpreadImplArch = function(self)
    local spread = self:CreateSpreadShell("NOTES")
    self:AddSpreadHeader(spread, "NOTES & RECORDS", "CURRENT ENTRY")
    self.notePage = spread

    local catHeader = makeLabel("EAS_CodexNotesCategoryHeader", spread.left, "CATEGORIES", 12, 54, self.pageW-24, 20, "ZoFontGameSmall")
    self.themeLabels[#self.themeLabels+1] = catHeader
    self.categoryHeader = catHeader
    self.categoryButtons = {}
    local catW = math.floor((self.pageW - 38) / 2)
    for i,cat in ipairs(CATEGORIES) do
        local col = (i-1) % 2
        local row = math.floor((i-1) / 2)
        local b = makeButton("EAS_CodexNoteCat_"..i, spread.left, cat, 12 + col*(catW+10), 78 + row*24, catW, 21, function() self:SetCategory(cat) end)
        b:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        self.categoryButtons[cat] = b
    end

    self.noteCount = makeLabel("EAS_CodexNoteCount", spread.left, "", 12, 180, self.pageW-24, 20, "ZoFontGameSmall")
    self.themeLabels[#self.themeLabels+1] = self.noteCount
    self.noteRows = {}
    local rows = 11
    for i=1,rows do
        local b = makeButton("EAS_CodexNoteRow_"..i, spread.left, "", 12, 208+(i-1)*31, self.pageW-24, 27, function(control)
            if control.entryId then self:SelectEntry(control.entryId) end
        end)
        b:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        self.noteRows[i] = b
    end

    local gap = 6
    local bw = math.floor((self.pageW - 24 - gap*3) / 4)
    self.newButton = makeButton("EAS_CodexNoteNew", spread.right, "NEW", 12, 56, bw, 27, function() self:NewEntry() end)
    self.saveButton = makeButton("EAS_CodexNoteSave", spread.right, "SAVE", 12+bw+gap, 56, bw, 27, function() self:SaveCurrentEntry() end)
    self.deleteButton = makeButton("EAS_CodexNoteDelete", spread.right, "DEL", 12+(bw+gap)*2, 56, bw, 27, function() self:DeleteEntry() end)
    self.modeButton = makeButton("EAS_CodexNoteMode", spread.right, "EDIT", 12+(bw+gap)*3, 56, bw, 27, function()
        self.readMode = not self.readMode
        self:EnsureSaved().readMode = self.readMode
        self:SetEditorEnabled(not self.readMode)
        self:ApplyTheme()
    end)
    self.topButtons[#self.topButtons+1] = self.newButton
    self.topButtons[#self.topButtons+1] = self.saveButton
    self.topButtons[#self.topButtons+1] = self.deleteButton
    self.topButtons[#self.topButtons+1] = self.modeButton

    self.noteTitleEdit = self:CreateEditBox("EAS_CodexNoteTitle", spread.right, 12, 98, self.pageW-24, 36, false)
    self.noteTitleEdit:SetFont("ZoFontGameBold")
    self.noteBodyEdit = self:CreateEditBox("EAS_CodexNoteBody", spread.right, 12, 148, self.pageW-24, self.pageH-236, true)
    self.noteBodyEdit:SetFont("ZoFontGame")
    local autosave = makeLabel("EAS_CodexNoteAutosave", spread.right, "Auto-saves when changing entries, chapters, or closing the Codex.", 12, self.pageH-72, self.pageW-24, 42, "ZoFontGameSmall")
    self.themeLabels[#self.themeLabels+1] = autosave
    setBookText(autosave, autosave:GetText(), autosave:GetWidth())
    return spread
end

local CreatePinsSpreadImplArch

function J:CreatePinsSpread(...)
    return CreatePinsSpreadImplArch(self, ...)
end

CreatePinsSpreadImplArch = function(self)
    local spread = self:CreateSpreadShell("PINS")
    self:AddSpreadHeader(spread, "CHECKPOINTS", "CHECKPOINT DETAILS")

    local nameLabel = makeLabel("EAS_CodexCheckpointNameLabel", spread.left, "CHECKPOINT NAME", 12, 56, self.pageW-24, 18, "ZoFontGameSmall")
    self.themeLabels[#self.themeLabels+1] = nameLabel
    self.checkpointNameEdit = wm:CreateControl("EAS_CodexCheckpointName", spread.left, CT_EDITBOX)
    self.checkpointNameEdit:SetAnchor(TOPLEFT, spread.left, TOPLEFT, 12, 78)
    self.checkpointNameEdit:SetDimensions(self.pageW-24, 32)
    self.checkpointNameEdit:SetFont("ZoFontGame")
    if self.checkpointNameEdit.SetMaxInputChars then self.checkpointNameEdit:SetMaxInputChars(80) end

    self.pinRows = {}
    for i=1,9 do
        local b = makeButton("EAS_CodexCheckpointRow_"..i, spread.left, "", 12, 122+(i-1)*36, self.pageW-24, 31, function(control)
            self.selectedPinId = control.pinId
            local selected = self:GetPinById(control.pinId)
            if selected and self.checkpointNameEdit then self.checkpointNameEdit:SetText(selected.name or "") end
            self:RefreshPinsPage()
        end)
        b:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        self.pinRows[i] = b
    end

    self.checkpointPrev = makeButton("EAS_CodexCheckpointPrev", spread.left, "< PREV", 12, self.pageH-62, 78, 26, function() self:ChangeCheckpointPage(-1) end)
    self.checkpointPageLabel = makeLabel("EAS_CodexCheckpointPage", spread.left, "", 96, self.pageH-60, self.pageW-192, 22, "ZoFontGameSmall")
    self.checkpointPageLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.themeLabels[#self.themeLabels+1] = self.checkpointPageLabel
    self.checkpointNext = makeButton("EAS_CodexCheckpointNext", spread.left, "NEXT >", self.pageW-90, self.pageH-62, 78, 26, function() self:ChangeCheckpointPage(1) end)

    self.pinInfo = makeLabel("EAS_CodexCheckpointInfo", spread.right, "", 18, 70, self.pageW-36, self.pageH-246, "ZoFontGame")
    self.themeLabels[#self.themeLabels+1] = self.pinInfo
    self.pinSave = makeButton("EAS_CodexCheckpointSave", spread.right, "SAVE / UPDATE HERE", 18, self.pageH-154, self.pageW-36, 32, function()
        self:SaveCurrentLocation(self.checkpointNameEdit and self.checkpointNameEdit:GetText() or "")
    end)
    self.pinWaypoint = makeButton("EAS_CodexCheckpointWaypoint", spread.right, "SET WAYPOINT", 18, self.pageH-112, self.pageW-36, 32, function() self:SetPinWaypoint() end)
    self.pinDelete = makeButton("EAS_CodexCheckpointDelete", spread.right, "DELETE CHECKPOINT", 18, self.pageH-70, self.pageW-36, 30, function() self:DeletePin() end)
    return spread
end

local CreateSuiteSpreadImplArch

function J:CreateSuiteSpread(...)
    return CreateSuiteSpreadImplArch(self, ...)
end

CreateSuiteSpreadImplArch = function(self, name)
    local spread = self:CreateSpreadShell(name)
    self:AddSpreadHeader(spread, TAB_TITLES[name] or name, "CONTINUED")
    local bodyH = self.pageH - 122
    local leftBody = makeLabel("EAS_CodexSuiteLeft_"..name, spread.left, "", 14, 58, self.pageW-28, bodyH, "ZoFontGame")
    local rightBody = makeLabel("EAS_CodexSuiteRight_"..name, spread.right, "", 14, 58, self.pageW-28, bodyH, "ZoFontGame")
    self.themeLabels[#self.themeLabels+1] = leftBody
    self.themeLabels[#self.themeLabels+1] = rightBody
    spread.leftBody, spread.rightBody = leftBody, rightBody
    spread.buttons = {}

    local gap = 5
    local bw = math.floor((self.pageW - 28 - gap*2) / 3)
    local buttonCount = (name == "TOOLS") and 8 or 6
    for i=1,buttonCount do
        local parent, x, y, width
        if name == "TOOLS" and i >= 7 then
            -- Reticle opacity controls get their own clearly visible row on the
            -- right Utilities page. The generic Suite spread only had six
            -- buttons, so actions 7/8 existed in code but could never render.
            parent = spread.right
            local opacityGap = 7
            local opacityW = math.floor((self.pageW - 28 - opacityGap) / 2)
            x = 14 + (i - 7) * (opacityW + opacityGap)
            y = self.pageH - 84
            width = opacityW
        else
            parent = i <= 3 and spread.left or spread.right
            local col = (i-1) % 3
            x = 14 + col*(bw+gap)
            y = self.pageH - 50
            width = bw
        end
        local actionIndex = i
        local b = makeButton("EAS_CodexSuiteAction_"..name.."_"..i, parent, "", x, y, width, 28, function() self:RunSuiteAction(name, actionIndex) end)
        b:SetHidden(true)
        spread.buttons[i] = b
    end
    return spread
end

function J:CreateDocumentSpread(name)
    local spread = self:CreateSpreadShell(name)
    self:AddSpreadHeader(spread, TAB_TITLES[name] or name, "CONTINUED")
    local isLowDensity = (name == "ACHIEVEMENTS" or name == "STATS")
    local bodyX = isLowDensity and 18 or 14
    local bodyY = isLowDensity and 50 or 58
    local bodyW = isLowDensity and (self.pageW - 36) or (self.pageW - 28)
    local bodyH = isLowDensity and (self.pageH - 64) or (self.pageH - 92)
    local bodyFont = "ZoFontGame"
    if name == "ACHIEVEMENTS" then
        bodyFont = getAchievementsDocumentFont()
    elseif name == "STATS" then
        bodyFont = getStatsDocumentFont()
    end
    spread.leftBody = makeLabel("EAS_CodexDocLeft_"..name, spread.left, "", bodyX, bodyY, bodyW, bodyH, bodyFont)
    spread.rightBody = makeLabel("EAS_CodexDocRight_"..name, spread.right, "", bodyX, bodyY, bodyW, bodyH, bodyFont)
    self.themeLabels[#self.themeLabels+1] = spread.leftBody
    self.themeLabels[#self.themeLabels+1] = spread.rightBody
    return spread
end

function J:CreateCodexSpread()
    local spread = self:CreateSpreadShell("CODEX")
    self:AddSpreadHeader(spread, "CRAFTING CODEX", "REFERENCE")
    self.codexButtons = {}
    local modes = {"ALCHEMY","RUNES","MATERIALS"}
    local bw = math.floor((self.pageW - 36) / 3)
    for i,mode in ipairs(modes) do
        local b = makeButton("EAS_CodexCraftMode_"..mode, spread.left, mode, 12+(i-1)*(bw+6), 58, bw, 28, function() self:SetCodexMode(mode) end)
        self.codexButtons[mode] = b
    end
    self.codexLeftBody = makeLabel("EAS_CodexCraftLeftBody", spread.left, "", 14, 104, self.pageW-28, self.pageH-132, "ZoFontGame")
    self.codexRightBody = makeLabel("EAS_CodexCraftRightBody", spread.right, "", 14, 58, self.pageW-28, self.pageH-88, "ZoFontGame")
    self.themeLabels[#self.themeLabels+1] = self.codexLeftBody
    self.themeLabels[#self.themeLabels+1] = self.codexRightBody
    return spread
end

local CreateDiceSpreadImplArch

function J:CreateDiceSpread(...)
    return CreateDiceSpreadImplArch(self, ...)
end

CreateDiceSpreadImplArch = function(self)
    local spread = self:CreateSpreadShell("DICE")
    self:AddSpreadHeader(spread, "ROLEPLAY DICE", "FORTUNE & HISTORY")

    local intro = makeLabel("EAS_CodexDiceIntro", spread.left,
        "Choose an ESO-themed die or flip a Septim-style coin for fast roleplay calls, random encounters, loot decisions, or tavern games.",
        18, 54, self.pageW-36, 54, "ZoFontGame")
    self.themeLabels[#self.themeLabels+1] = intro
    setBookText(intro, intro:GetText(), intro:GetWidth())

    self.iconButtons = self.iconButtons or {}
    local tileGap = 8
    local tileW = math.floor((self.pageW - 24 - tileGap * 2) / 3)
    local tileH = 90
    local dice = {4,6,8,10,12,20}
    for i, sides in ipairs(dice) do
        local col = (i - 1) % 3
        local row = math.floor((i - 1) / 3)
        local btn = makeIconButton(
            "EAS_CodexDice_"..sides,
            spread.left,
            getChanceTexture("DICE", sides),
            "D"..sides,
            12 + col * (tileW + tileGap),
            118 + row * (tileH + 10),
            tileW,
            tileH,
            function() self:Roll(sides) end
        )
        self.iconButtons[#self.iconButtons+1] = btn
    end

    local wideW = tileW * 2 + tileGap
    local d100 = makeIconButton("EAS_CodexDice_100", spread.left, getChanceTexture("DICE", 100), "D100", 12, 318, tileW, tileH, function() self:Roll(100) end)
    self.iconButtons[#self.iconButtons+1] = d100
    local coin = makeIconButton("EAS_CodexCoin", spread.left, getChanceTexture("COIN"), "COIN", 12 + tileW + tileGap, 318, wideW, tileH, function() self:TossCoin() end)
    self.iconButtons[#self.iconButtons+1] = coin

    local hint = makeLabel("EAS_CodexDiceHint", spread.left,
        "The latest result appears on the facing page, with your recent roll history preserved below it.",
        18, 420, self.pageW - 36, 48, "ZoFontGameSmall")
    self.themeLabels[#self.themeLabels+1] = hint
    setBookText(hint, hint:GetText(), hint:GetWidth())

    self.diceResultPanel = makePanel("EAS_CodexDiceResultPanel", spread.right, 24, 58, self.pageW - 50, 244)
    self.diceResultTitle = makeLabel("EAS_CodexDiceResultTitle", self.diceResultPanel, "LUCK OF THE DRAW", 12, 12, self.diceResultPanel:GetWidth() - 24, 28, "ZoFontWinH2")
    self.diceResultTitle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.themeLabels[#self.themeLabels+1] = self.diceResultTitle

    self.diceResultIcon = wm:CreateControl("EAS_CodexDiceResultIcon", self.diceResultPanel, CT_TEXTURE)
    self.diceResultIcon:SetDimensions(78, 78)
    self.diceResultIcon:SetAnchor(TOP, self.diceResultPanel, TOP, 0, 44)
    self.diceResultIcon:SetTexture(getChanceTexture("DICE", 20))

    self.diceResultValue = makeLabel("EAS_CodexDiceResultValue", self.diceResultPanel, "READY", 12, 124, self.diceResultPanel:GetWidth() - 24, 38, "ZoFontWinH1")
    self.diceResultValue:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.diceResultValue:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.diceResultSub = makeLabel("EAS_CodexDiceResultSub", self.diceResultPanel, "Choose a die or toss a coin to see the latest result here.", 18, 164, self.diceResultPanel:GetWidth() - 36, 72, "ZoFontGame")
    self.diceResultSub:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.diceResultSub:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.themeLabels[#self.themeLabels+1] = self.diceResultSub
    setBookText(self.diceResultSub, self.diceResultSub:GetText(), self.diceResultSub:GetWidth())

    local historyTitle = makeLabel("EAS_CodexDiceHistoryTitle", spread.right, "ROLL HISTORY", 24, 320, self.pageW-48, 24, "ZoFontGameSmall")
    historyTitle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.themeLabels[#self.themeLabels+1] = historyTitle

    self.diceHistoryOutput = makeLabel("EAS_CodexDiceHistoryOutput", spread.right, "Choose a die or toss a coin.", 24, 348, self.pageW-48, self.pageH-372, "ZoFontGame")
    self.themeLabels[#self.themeLabels+1] = self.diceHistoryOutput
    self.diceOutput = self.diceHistoryOutput
    self:RefreshDice()
    return spread
end

RefreshCodexImplArch = function(self)
    local text = CODEX[self.codexMode or "ALCHEMY"] or ""
    local left, right = easSplitSpreadText(text)
    if self.codexLeftBody then setBookText(self.codexLeftBody, left, self.codexLeftBody:GetWidth()) end
    if self.codexRightBody then setBookText(self.codexRightBody, right, self.codexRightBody:GetWidth()) end
    for mode,b in pairs(self.codexButtons or {}) do setButtonStyle(b, mode == (self.codexMode or "ALCHEMY"), self:GetTheme()) end
end

RefreshDocumentPageImplArch = function(self)
    local page = self.pages and self.pages[self.activeTab]
    if not page or not page.leftBody then return end
    local text = ""
    if self.activeTab == "ACHIEVEMENTS" then
        text = self:BuildAchievementText()
        local left, right = easSplitSpreadText(text)
        setBookText(page.leftBody, left, page.leftBody:GetWidth())
        setBookText(page.rightBody, right, page.rightBody:GetWidth())
    elseif self.activeTab == "STATS" then
        local left, right = self:BuildStatsSpread()
        setBookText(page.leftBody, left, page.leftBody:GetWidth())
        setBookText(page.rightBody, right, page.rightBody:GetWidth())
    else
        return
    end
end

RefreshSuitePageImplArch = function(self, tab)
    tab = tab or self.activeTab
    if not SUITE_TABS[tab] then return end
    local page = self.pages and self.pages[tab]
    if not page or not page.leftBody then return end
    local left, right = easSplitSpreadText(self:BuildSuiteText(tab))
    setBookText(page.leftBody, left, page.leftBody:GetWidth())
    setBookText(page.rightBody, right, page.rightBody:GetWidth())
    if tab == "GEAR" then self:SetSuiteButtons(tab, {"FILTER","SEARCH","< PAGE","PAGE >","SELECT","ROUTE"})
    elseif tab == "QUESTS" then self:SetSuiteButtons(tab, {"FILTER","< PAGE","PAGE >","SELECT","ROUTE"})
    elseif tab == "TRAVEL" then self:SetSuiteButtons(tab, {"MODE","< PAGE","PAGE >","SELECT","TRAVEL"})
    elseif tab == "ACTIVITY" then self:SetSuiteButtons(tab, {"GOAL","SELECT","ROUTE"})
    elseif tab == "TOOLS" then
        local toolMode = EPC.UtilitySuite and EPC.UtilitySuite:GetMode() or "OVERVIEW"
        if toolMode == "RETICLE" then
            self:SetSuiteButtons(tab, {"MODE","ON / OFF","STYLE","COLOR","SIZE -","SIZE +","OPACITY -","OPACITY +"})
        elseif toolMode == "SELL" then
            self:SetSuiteButtons(tab, {"MODE","< ITEM","ITEM >","SELL ITEM","SELL JUNK","REFRESH"})
        else
            self:SetSuiteButtons(tab, {"MODE"})
        end
    elseif tab == "SKILLS" then self:SetSuiteButtons(tab, {"MAX POWER BUILD","MAX POWER CP","MAX POWER ATTRIBUTES"})
    else self:SetSuiteButtons(tab, {"REFRESH"}) end
end

SetTabImplArch = function(self, tab)
    if not tab or not TAB_TITLES[tab] then tab = "INDEX" end
    self:SaveCurrentEntry()
    local changed = self.activeTab ~= nil and self.activeTab ~= tab
    self.activeTab = tab
    self:EnsureSaved().activeTab = tab

    local idx = 1
    for i,name in ipairs(TABS) do if name == tab then idx = i break end end
    if self.leftPageNumber then self.leftPageNumber:SetText(tostring((idx-1)*2 + 1)) end
    if self.rightPageNumber then self.rightPageNumber:SetText(tostring((idx-1)*2 + 2)) end
    if self.pageNumber then self.pageNumber:SetText(string.format("%d-%d", (idx-1)*2 + 1, (idx-1)*2 + 2)) end

    local notesTab = tab == "NOTES"
    if self.modeButton then self.modeButton:SetText(self.readMode and "EDIT" or "READ") end
    if self.deleteButton and self.deleteButton.SetEnabled then self.deleteButton:SetEnabled(notesTab and self.currentEntryId ~= nil) end

    for name,page in pairs(self.pages or {}) do page:SetHidden(name ~= tab) end

    if SUITE_TABS[tab] then
        if EPC.saved then EPC.saved.activeTab = (tab == "TRAVEL" and "MAP" or tab) end
        if EPC.RefreshNow then EPC:RefreshNow("codex-" .. string.lower(tab)) end
        self:RefreshSuitePage(tab)
    elseif tab == "NOTES" then self:RefreshNotes()
    elseif tab == "PINS" then self:RefreshPinsPage()
    elseif tab == "DICE" then self:RefreshDice()
    elseif tab == "CODEX" then self:RefreshCodex()
    elseif tab == "ACHIEVEMENTS" or tab == "STATS" then self:RefreshDocumentPage() end

    self:ApplyTheme()
    if changed and self.window and not self.window:IsHidden() then self:PlayPageTurn() end
end

CreateImplArch = function(self)
    local window = wm:CreateTopLevelWindow("EAS_CustomJournal")
    self.window = window
    window:SetDimensions(1024, 1024)
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, -8)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:SetMouseEnabled(true)
    window:SetHidden(true)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetDrawTier(DT_HIGH)

    local rootHeight = tonumber(GuiRoot and GuiRoot.GetHeight and GuiRoot:GetHeight()) or 1080
    if rootHeight < 1060 and window.SetScale then window:SetScale(math.max(0.72, (rootHeight - 28) / 1024)) end

    local nativeBook = getNativeLoreBookMedium()
    self.nativeBook = nativeBook
    local bookTexture = wm:CreateControl("EAS_CustomJournal_NativeLoreBook", window, CT_TEXTURE)
    bookTexture:SetAnchorFill(window)
    if nativeBook then bookTexture:SetTexture(nativeBook.bg) end
    bookTexture:SetTextureCoords(0,1,0,1)
    bookTexture:SetMouseEnabled(false)
    self.bookTexture = bookTexture
    self.openSound = nativeBook and nativeBook.openSound or nil
    self.closeSound = nativeBook and nativeBook.closeSound or nil
    self.turnSound = nativeBook and nativeBook.turnPageSound or nil

    local bg = wm:CreateControl("EAS_CustomJournal_BG", window, CT_BACKDROP)
    bg:SetAnchor(TOPLEFT, window, TOPLEFT, 68, 108)
    bg:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -68, -108)
    bg:SetEdgeTexture(nil, 2, 2, 2)
    bg:SetCenterColor(0.95,0.89,0.76, nativeBook and 0 or 1)
    bg:SetEdgeColor(0.34,0.22,0.10, nativeBook and 0 or 0.85)
    self.bg = bg

    local pageW = tonumber(nativeBook and nativeBook.pageWidth) or 374
    local pageH = tonumber(nativeBook and nativeBook.pageHeight) or 620
    pageW = math.max(340, math.min(410, pageW))
    pageH = math.max(560, math.min(690, pageH))
    self.pageW, self.pageH = pageW, pageH

    local leftHost = wm:CreateControl("EAS_CodexLeftPageHost", window, CT_CONTROL)
    if nativeBook then leftHost:SetAnchor(LEFT, window, LEFT, tonumber(nativeBook.leftPageXOffset) or 0, tonumber(nativeBook.pageYOffset) or 0)
    else leftHost:SetAnchor(TOPLEFT, window, TOPLEFT, 126, 172) end
    leftHost:SetDimensions(pageW, pageH)
    self.leftPageHost = leftHost
    self.leftNavigation = leftHost

    local rightHost = wm:CreateControl("EAS_CodexRightPageHost", window, CT_CONTROL)
    if nativeBook then rightHost:SetAnchor(RIGHT, window, RIGHT, tonumber(nativeBook.rightPageXOffset) or 0, tonumber(nativeBook.pageYOffset) or 0)
    else rightHost:SetAnchor(TOPLEFT, window, TOPLEFT, 550, 158) end
    rightHost:SetDimensions(pageW, pageH)
    self.rightPageHost = rightHost
    self.rightContent = rightHost

    self.panels, self.themeLabels, self.tabButtons, self.pages, self.topButtons = {}, {}, {}, {}, {}
    self.categoryButtons = {}

    -- Keep chapter navigation on the opening INDEX spread instead of cluttering both outer book edges.
    -- A single INDEX control remains available while reading so users can return to the table of contents.
    local indexButton = makeButton("EAS_CodexIndexButton", window, "INDEX", 698, 68, 86, 26, function() self:SetTab("INDEX") end)
    indexButton:SetDrawLayer(DL_OVERLAY)
    indexButton:SetDrawLevel(1000)
    local theme = makeButton("EAS_CodexTheme", window, "THEME", 792, 68, 86, 26, function() self:CycleTheme() end)
    local close = makeButton("EAS_CodexClose", window, "CLOSE", 886, 68, 86, 26, function() self:Hide() end)
    self.indexButton, self.themeButton, self.closeButton = indexButton, theme, close
    self.topButtons[#self.topButtons+1] = indexButton
    self.topButtons[#self.topButtons+1] = theme
    self.topButtons[#self.topButtons+1] = close

    self.pages.INDEX = self:CreateIndexSpread()
    self.pages.NOTES = self:CreateNotesSpread()
    self.pages.PINS = self:CreatePinsSpread()
    self.pages.BUILD = self:CreateSuiteSpread("BUILD")
    self.pages.GEAR = self:CreateSuiteSpread("GEAR")
    self.pages.SKILLS = self:CreateSuiteSpread("SKILLS")
    self.pages.COMBAT = self:CreateSuiteSpread("COMBAT")
    self.pages.ACTIVITY = self:CreateSuiteSpread("ACTIVITY")
    self.pages.DUNGEONS = self:CreateSuiteSpread("DUNGEONS")
    self.pages.BATTLEGROUNDS = self:CreateSuiteSpread("BATTLEGROUNDS")
    self.pages.GROUPFINDER = self:CreateSuiteSpread("GROUPFINDER")
    self.pages.QUESTS = self:CreateSuiteSpread("QUESTS")
    self.pages.TRAVEL = self:CreateSuiteSpread("TRAVEL")
    self.pages.TOOLS = self:CreateSuiteSpread("TOOLS")
    self.pages.ACHIEVEMENTS = self:CreateDocumentSpread("ACHIEVEMENTS")
    self.pages.STATS = self:CreateDocumentSpread("STATS")
    self.pages.CODEX = self:CreateCodexSpread()
    self.pages.DICE = self:CreateDiceSpread()
    self.suiteRowIndex = { GEAR=0, QUESTS=0, TRAVEL=0, ACTIVITY=0, DUNGEONS=0, BATTLEGROUNDS=0, GROUPFINDER=0 }

    local prev = makeButton("EAS_CodexPrevSpread", window, "< PREV", 336, 894, 86, 26, function() self:TurnPage(-1) end)
    local spreadNo = makeLabel("EAS_CodexSpreadNumber", window, "1-2", 452, 896, 120, 22, "ZoFontGameSmall")
    spreadNo:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    local nextB = makeButton("EAS_CodexNextSpread", window, "NEXT >", 602, 894, 86, 26, function() self:TurnPage(1) end)
    self.prevPageButton, self.nextPageButton, self.pageNumber = prev, nextB, spreadNo
    self.themeLabels[#self.themeLabels+1] = spreadNo

    local leftNum = makeLabel("EAS_CodexLeftPageNumber", leftHost, "1", math.floor((pageW-40)/2), pageH-28, 40, 20, "ZoFontGameSmall")
    leftNum:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    local rightNum = makeLabel("EAS_CodexRightPageNumber", rightHost, "2", math.floor((pageW-40)/2), pageH-28, 40, 20, "ZoFontGameSmall")
    rightNum:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.leftPageNumber, self.rightPageNumber = leftNum, rightNum
    self.themeLabels[#self.themeLabels+1] = leftNum
    self.themeLabels[#self.themeLabels+1] = rightNum

    local flip = wm:CreateControl("EAS_CustomJournal_FlipPage", window, CT_BACKDROP)
    flip:SetDimensions(pageW, pageH-72)
    flip:SetAnchor(TOPLEFT, rightHost, TOPLEFT, 0, 44)
    flip:SetEdgeTexture(nil, 1, 1, 1)
    flip:SetDrawLayer(DL_OVERLAY)
    flip:SetHidden(true)
    self.flipPage = flip
    local flipMark = makeLabel("EAS_CodexFlipMark", flip, "TAMRIEL CODEX", 18, math.floor((pageH-110)/2), pageW-36, 30, "ZoFontWinH2")
    flipMark:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.themeLabels[#self.themeLabels+1] = flipMark

    window:SetHandler("OnMoveStop", function(control)
        local s = self:EnsureSaved()
        s.left, s.top = control:GetLeft(), control:GetTop()
    end)

    local s = self:EnsureSaved()
    if s.twoPageIndexUpgrade ~= true then
        s.activeTab = "INDEX"
        s.twoPageIndexUpgrade = true
    end
    if s.cleanOpeningIndexUpgrade ~= true then
        s.activeTab = "INDEX"
        s.cleanOpeningIndexUpgrade = true
    end
    if tonumber(s.left) and tonumber(s.top) and s.left >= 0 and s.top >= 0 then
        window:ClearAnchors()
        window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, s.left, s.top)
    end

    self.category = s.category or "ALL"
    self.activeTab = s.activeTab or "INDEX"
    self.readMode = s.readMode == true
    self.codexMode = "ALCHEMY"
    self:SetEditorEnabled(not self.readMode)
    self:SetTab(self.activeTab)
    self:RegisterMapPins()
end

--[[
    v0.19.1 interactive Codex fix
    Restores the old menu's direct row selection inside the two-page book.
    Left page = filters + clickable rows. Right page = selected details + actions.
]]

local EAS_INTERACTIVE_TABS = { GEAR=true, QUESTS=true, TRAVEL=true, ACTIVITY=true, DUNGEONS=true, BATTLEGROUNDS=true, GROUPFINDER=true }

local function easSetEnabled(control, enabled)
    if not control then return end
    local active = enabled == true
    if control.SetEnabled then control:SetEnabled(active) end
    if control.SetAlpha then control:SetAlpha(active and 1 or 0.45) end
    if control._easBorder then
        if active then
            control._easBorder:SetCenterColor(0.035, 0.050, 0.072, 0.55)
        else
            control._easBorder:SetCenterColor(0.020, 0.025, 0.032, 0.42)
        end
    end
    if active then
        setButtonBorderColor(control, 0.18, 0.72, 0.92, 0.94)
    else
        setButtonBorderColor(control, 0.12, 0.44, 0.56, 0.55)
    end
end

local function easSetInk(label, selected, muted)
    if not label or not label.SetColor then return end
    local t = J:GetTheme()
    if selected then
        label:SetColor(t.accent[1], t.accent[2], t.accent[3], 1)
    elseif muted then
        label:SetColor(t.text[1], t.text[2], t.text[3], 0.66)
    else
        label:SetColor(t.text[1], t.text[2], t.text[3], 1)
    end
end

local RefreshInteractiveDungeonsImplArch

function J:RefreshInteractiveDungeons(...)
    return RefreshInteractiveDungeonsImplArch(self, ...)
end

RefreshInteractiveDungeonsImplArch = function(self, page)
    local D = EPC.DungeonFinder
    local liveMode = false -- v0.25.29 Group Finder moved to its own Codex tab
    local v = liveMode and D:BuildLiveView() or (D and D:BuildView() or {rows={},total=0,page=1,pageCount=1})

    local dungeonCtlWidths = {90, 104, 142, 78}
    local dungeonCtlX = 14
    for i=1,4 do
        local b = page.controls[i]
        if b then
            b:ClearAnchors()
            b:SetAnchor(TOPLEFT, page.left, TOPLEFT, dungeonCtlX, 54)
            b:SetDimensions(dungeonCtlWidths[i], 25)
            dungeonCtlX = dungeonCtlX + dungeonCtlWidths[i] + 4
        end
    end

    if liveMode then
        page.controls[1]:SetHidden(false); page.controls[1]:SetText("DUNGEONS")
        page.controls[2]:SetHidden(false); page.controls[2]:SetText("LIVE GROUPS")
        page.controls[3]:SetHidden(false); page.controls[3]:SetText(tostring(v.categoryName or "CATEGORY"))
        page.controls[4]:SetHidden(false); page.controls[4]:SetText("REFRESH")
        setButtonStyle(page.controls[1], false, self:GetTheme())
        setButtonStyle(page.controls[2], true, self:GetTheme())
        setButtonStyle(page.controls[3], false, self:GetTheme())
        setButtonStyle(page.controls[4], false, self:GetTheme())

        page.secondary[1]:SetText("< PREV")
        page.secondary[2]:SetText("NEXT >")
        page.secondary[3]:SetText("NORMAL")
        page.secondary[4]:SetText("VETERAN")
        for i=1,4 do page.secondary[i]:SetHidden(false) end
        setButtonStyle(page.secondary[1], false, self:GetTheme())
        setButtonStyle(page.secondary[2], false, self:GetTheme())
        setButtonStyle(page.secondary[3], v.difficulty == "NORMAL", self:GetTheme())
        setButtonStyle(page.secondary[4], v.difficulty == "VETERAN", self:GetTheme())
        easSetEnabled(page.secondary[1], (tonumber(v.page) or 1) > 1)
        easSetEnabled(page.secondary[2], (tonumber(v.page) or 1) < (tonumber(v.pageCount) or 1))

        local selected = v.selected
        for i,rowControl in ipairs(page.rows) do
            local row = v.rows and v.rows[i]
            if row then
                rowControl:SetHidden(false)
                local isSelected = selected and row.data == selected
                local rowTitle = tostring(row.title or "Group Listing")
                if row.lastBoss then rowTitle = "LAST BOSS  -  " .. rowTitle end
                rowControl.titleLabel:SetText(rowTitle)
                local detail = tostring(row.owner or "")
                if row.roles and row.roles ~= "" then detail = detail .. "   " .. row.roles end
                if row.activeApplication then detail = "PENDING   " .. detail end
                rowControl.detailLabel:SetText(detail)
                easSetInk(rowControl.titleLabel, isSelected, false)
                easSetInk(rowControl.detailLabel, isSelected, true)
                if row.lastBoss and EPC.saved.groupFinderWidgetLastBossHighlight == true and not isSelected then
                    -- v0.29.341: steady high-contrast emphasis replaces the old
                    -- per-row rainbow OnUpdate pulse. This keeps LAST BOSS obvious
                    -- without attaching frame callbacks to visible Codex rows.
                    rowControl:SetHandler("OnUpdate", nil)
                    rowControl.titleLabel:SetColor(1.00, 0.78, 0.24, 1)
                else
                    rowControl:SetHandler("OnUpdate", nil)
                end
            else rowControl:SetHandler("OnUpdate", nil); rowControl:SetHidden(true) end
        end

        page.pageLabel:SetText(string.format("PAGE %d / %d  -  %d LIVE LISTINGS", tonumber(v.page) or 1, tonumber(v.pageCount) or 1, tonumber(v.total) or 0))
        if selected then
            local function get(method, fallback)
                if type(selected[method]) == "function" then local ok,val=pcall(selected[method],selected); if ok and val ~= nil then return val end end
                return fallback
            end
            local title = cleanName and cleanName(get("GetTitle", "Group Listing")) or tostring(get("GetTitle", "Group Listing"))
            local owner = tostring(get("GetOwnerDisplayName", "Unknown"))
            local description = tostring(get("GetDescription", ""))
            local autoAccept = get("DoesGroupAutoAcceptRequests", false) == true
            local activeApplication = get("IsActiveApplication", false) == true
            local roleText = ""
            if type(selected.GetRoleStatusCount) == "function" then
                local parts = {}
                for _,r in ipairs({{LFG_ROLE_TANK,"Tank"},{LFG_ROLE_HEAL,"Healer"},{LFG_ROLE_DPS,"DPS"}}) do
                    if r[1] ~= nil then local ok,desired,attained=pcall(selected.GetRoleStatusCount,selected,r[1]); if ok and ((tonumber(desired) or 0)>0 or (tonumber(attained) or 0)>0) then parts[#parts+1]=string.format("%s %d/%d",r[2],tonumber(attained) or 0,tonumber(desired) or 0) end end
                end
                roleText = table.concat(parts, "  ")
            end
            page.detailTitle:SetText((EPC.DungeonFinder and EPC.DungeonFinder:IsLastBossListing(selected) and EPC.saved.groupFinderWidgetLastBossHighlight == true) and ("LAST BOSS  -  " .. title) or title)
            setBookText(page.detailBody, string.format("LEADER\n%s\n\nCATEGORY\n%s\n\nMODE\n%s\n\nROLES\n%s\n\nAPPLICATION\n%s\n\nDESCRIPTION\n%s", owner, tostring(v.categoryName or "Group Finder"), tostring(v.difficulty or "ALL"), roleText ~= "" and roleText or "Any / listing rules", activeApplication and "PENDING" or (autoAccept and "INSTANT JOIN" or "APPLICATION"), description ~= "" and description or "No description provided."), page.detailBody:GetWidth())
        else
            page.detailTitle:SetText((tonumber(v.total) or 0) > 0 and "Select a Live Group" or "Live Group Finder")
            setBookText(page.detailBody, "Browse ESO's live player-created Group Finder listings without leaving the Tamriel Codex. Switch category, choose Normal or Veteran where supported, select a listing, then JOIN / APPLY. Results update through ESO's Group Finder callbacks instead of a permanent polling loop.", page.detailBody:GetWidth())
        end

        page.action0:SetText("JOIN / APPLY")
        page.action1:SetText("WHISPER LEADER")
        page.action2:SetText("RESCIND APPLICATION")
        page.action3:SetText("REFRESH")
        for _, b in ipairs({page.action0,page.action1,page.action2,page.action3}) do b:SetHidden(false); setButtonStyle(b, false, self:GetTheme()) end
        easSetEnabled(page.action0, selected ~= nil)
        easSetEnabled(page.action1, selected ~= nil)
        easSetEnabled(page.action2, true)
        easSetEnabled(page.action3, true)
        return
    end

    page.controls[1]:SetHidden(false); page.controls[1]:SetText("NORMAL")
    page.controls[2]:SetHidden(false); page.controls[2]:SetText("VETERAN")
    page.controls[3]:SetHidden(false); page.controls[3]:SetText("ROLE: " .. tostring(v.role or "DPS"))
    page.controls[4]:SetHidden(false); page.controls[4]:SetText(v.scanning and "SCAN..." or "REFRESH")
    setButtonStyle(page.controls[1], v.difficulty == "NORMAL", self:GetTheme())
    setButtonStyle(page.controls[2], v.difficulty == "VETERAN", self:GetTheme())
    setButtonStyle(page.controls[3], false, self:GetTheme())
    setButtonStyle(page.controls[4], false, self:GetTheme())

    page.secondary[1]:SetText("< PREV")
    page.secondary[2]:SetText("NEXT >")
    page.secondary[3]:SetText("AUTO " .. ((v.autoAccept == true) and "ON" or "OFF"))
    page.secondary[4]:SetText("ROLES " .. ((v.enforceRoles == true) and "ON" or "OFF"))
    for i=1,4 do page.secondary[i]:SetHidden(false); setButtonStyle(page.secondary[i], (i==3 and v.autoAccept == true) or (i==4 and v.enforceRoles == true), self:GetTheme()) end
    easSetEnabled(page.secondary[1], (tonumber(v.page) or 1) > 1)
    easSetEnabled(page.secondary[2], (tonumber(v.page) or 1) < (tonumber(v.pageCount) or 1))

    local selected = v.selected
    for i,rowControl in ipairs(page.rows) do
        local row = v.rows and v.rows[i]
        if row then
            rowControl:SetHidden(false)
            local isSelected = selected and selected.activityId == row.activityId
            rowControl.titleLabel:SetText(tostring(row.name or "Dungeon"))
            local versions = ((row.normalActivityId and "N") or "-") .. "/" .. ((row.veteranActivityId and "V") or "-")
            rowControl.detailLabel:SetText(string.format("%s   [%s]", tostring(row.source or "DLC / CHAPTER"), versions))
            easSetInk(rowControl.titleLabel, isSelected, false)
            easSetInk(rowControl.detailLabel, isSelected, true)
        else rowControl:SetHandler("OnUpdate", nil); rowControl:SetHidden(true) end
    end
    if v.scanning then
        page.pageLabel:SetText(string.format("SCANNING ESO ACTIVITIES... %d FOUND", tonumber(v.total) or 0))
    else
        page.pageLabel:SetText(string.format("PAGE %d / %d  -  %d DUNGEONS  -  A-Z", tonumber(v.page) or 1, tonumber(v.pageCount) or 1, tonumber(v.total) or 0))
    end

    if selected then
        page.detailTitle:SetText(selected.name or "Dungeon")
        local req = (tonumber(selected.championMin) or 0) > 0 and ("CP "..tostring(selected.championMin)) or ((tonumber(selected.levelMin) or 0) > 0 and ("Level "..tostring(selected.levelMin)) or "ESO requirements apply")
        local queueState = v.queued and "QUEUED" or "NOT QUEUED"
        local availability = string.format("Normal: %s   Veteran: %s", selected.normalActivityId and "YES" or "NO", selected.veteranActivityId and "YES" or "NO")
        setBookText(page.detailBody, string.format("SOURCE\n%s\n\nREQUIREMENT\n%s\n\nMODE\n%s / %s\n\nHOST OPTIONS\nAuto Accept: %s\nEnforce Roles: %s\n1 Tank / 1 Healer / 2 DPS\n\nSTATUS\n%s\n%s\n\n%s", tostring(selected.source or "DLC / CHAPTER"), req, tostring(v.difficulty or "ALL"), tostring(v.role or "DPS"), v.autoAccept and "ON" or "OFF", v.enforceRoles and "ON" or "OFF", queueState, availability, tostring(selected.description or "")), page.detailBody:GetWidth())
    else
        page.detailTitle:SetText(v.scanning and "Building Dungeon Index" or "Select a Dungeon")
        setBookText(page.detailBody, "Select a dungeon on the left. Then choose Normal/Veteran and your role. QUEUE SELECTED uses ESO Activity Finder. HOST LISTING creates a Group Finder listing. LIVE GROUPS opens the new real-time player-created Group Finder browser.", page.detailBody:GetWidth())
    end

    page.action0:SetText(v.queued and "ALREADY QUEUED" or "QUEUE SELECTED")
    page.action1:SetText("HOST / CREATE LISTING")
    page.action2:SetText("FIND REPLACEMENT")
    page.action3:SetText("CANCEL QUEUE")
    for _, b in ipairs({page.action0,page.action1,page.action2,page.action3}) do b:SetHidden(selected == nil); setButtonStyle(b, false, self:GetTheme()) end
    easSetEnabled(page.action0, selected ~= nil and not v.queued)
    easSetEnabled(page.action1, selected ~= nil and not v.queued)
    easSetEnabled(page.action2, selected ~= nil)
    easSetEnabled(page.action3, selected ~= nil and v.queued)
end

local CreateBookRowImplArch

function J:CreateBookRow(...)
    return CreateBookRowImplArch(self, ...)
end

CreateBookRowImplArch = function(self, parent, name, index, y, onClick)
    local row = wm:CreateControl("EAS_CodexInteractive_"..name.."_"..index, parent, CT_BUTTON)
    row:SetAnchor(TOPLEFT, parent, TOPLEFT, 14, y)
    row:SetDimensions(self.pageW-28, 44)
    row:SetMouseEnabled(true)
    row:SetHandler("OnClicked", function() onClick(index) end)

    local title = makeLabel("EAS_CodexInteractiveTitle_"..name.."_"..index, row, "", 4, 1, self.pageW-52, 19, "ZoFontGameBold")
    local detail = makeLabel("EAS_CodexInteractiveDetail_"..name.."_"..index, row, "", 4, 21, self.pageW-52, 18, "ZoFontGameSmall")
    detail:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

    local rule = wm:CreateControl("EAS_CodexInteractiveRule_"..name.."_"..index, row, CT_BACKDROP)
    rule:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, 4, 0)
    rule:SetDimensions(self.pageW-54, 1)
    rule:SetCenterColor(0.26,0.17,0.08,0.18)
    rule:SetEdgeColor(0,0,0,0)

    row.titleLabel = title
    row.detailLabel = detail
    row.rule = rule
    row.rowIndex = index
    return row
end

function J:CreateInteractiveSuiteSpread(name)
    local spread = self:CreateSpreadShell(name)
    self:AddSpreadHeader(spread, TAB_TITLES[name] or name, "SELECTED")
    spread.interactive = true
    spread.controls = {}
    spread.rows = {}

    -- Top filter/mode row. Exact labels are populated per section.
    local ctlGap = 4
    local ctlW = math.floor((self.pageW - 28 - ctlGap*3) / 4)
    for i=1,4 do
        local b = makeButton("EAS_CodexInteractiveCtl_"..name.."_"..i, spread.left, "", 14+(i-1)*(ctlW+ctlGap), 54, ctlW, 25, function() self:RunInteractiveControl(name, i) end)
        spread.controls[i] = b
    end

    -- Secondary controls: search/clear or page navigation depending on section.
    spread.secondary = {}
    local secW = math.floor((self.pageW - 28 - ctlGap*3) / 4)
    for i=1,4 do
        local b = makeButton("EAS_CodexInteractiveSecondary_"..name.."_"..i, spread.left, "", 14+(i-1)*(secW+ctlGap), 84, secW, 25, function() self:RunInteractiveSecondary(name, i) end)
        spread.secondary[i] = b
    end

    local rowStart = 112
    local rowCount = 10
    for i=1,rowCount do
        spread.rows[i] = self:CreateBookRow(spread.left, name, i, rowStart + (i-1)*39, function(rowIndex)
            self:SelectInteractiveRow(name, rowIndex)
        end)
    end

    spread.pageLabel = makeLabel("EAS_CodexInteractivePage_"..name, spread.left, "", 14, self.pageH-70, self.pageW-28, 20, "ZoFontGame")
    spread.pageLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.themeLabels[#self.themeLabels+1] = spread.pageLabel

    spread.detailTitle = makeLabel("EAS_CodexInteractiveSelectedTitle_"..name, spread.right, "Select an entry", 18, 62, self.pageW-36, 52, "ZoFontWinH2")
    spread.detailTitle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    spread.detailBody = makeLabel("EAS_CodexInteractiveSelectedBody_"..name, spread.right, "", 18, 124, self.pageW-36, self.pageH-308, "ZoFontGame")
    spread.detailBody:SetVerticalAlignment(TEXT_ALIGN_TOP)
    self.themeLabels[#self.themeLabels+1] = spread.detailTitle
    self.themeLabels[#self.themeLabels+1] = spread.detailBody

    spread.optimizerModes = {}
    spread.armorWeightButtons = {}
    spread.loadoutButtons = {}
    if name == "GEAR" then
        local modeW = math.floor((self.pageW - 42) / 4)
        for i=1,4 do
            spread.optimizerModes[i] = makeButton("EAS_CodexOptimizerMode_"..i, spread.right, "", 10 + (i-1)*(modeW+2), self.pageH-256, modeW, 26, function()
                if EPC.GearOptimizer and EPC.GearOptimizer.PRESET_ORDER then
                    EPC.GearOptimizer:SetPreset(EPC.GearOptimizer.PRESET_ORDER[i])
                    self:RefreshSuitePage("GEAR")
                end
            end)
        end
        -- v0.27.10: Saved Builds must be directly discoverable from the
        -- Gear & Sets chapter. Do not depend on the optional Live Equipment
        -- floating panel to expose the Dressing-Room-style manager.
        spread.companionAbilitiesButton = makeButton("EAS_CodexBestCompanionAbilities", spread.right, "BEST COMPANION ABILITIES + ULT", 10, self.pageH-396, self.pageW-20, 28, function()
            if EPC.CompanionOptimizer and type(EPC.CompanionOptimizer.EquipBestAbilities) == "function" then
                EPC.CompanionOptimizer:EquipBestAbilities()
            end
            self:RefreshSuitePage("GEAR")
        end)

        spread.savedLoadoutsButton = makeButton("EAS_CodexSavedLoadouts", spread.right, "OPEN BUILDS", 10, self.pageH-362, self.pageW-20, 28, function()
            if EPC.LoadoutManager and type(EPC.LoadoutManager.Show) == "function" then
                EPC.LoadoutManager:Show()
            end
        end)

        local loadoutActions = {
            {"WEAPONS", "EquipBestWeapons"},
            {"JEWELRY", "EquipBestJewelry"},
            {"ABILITIES", "EquipBestAbilities"},
            {"POTIONS", "EquipBestPotions"},
        }
        -- v0.24.93: give the four loadout actions enough room to display
        -- their complete labels. The old four-column row clipped WEAPONS,
        -- JEWELRY, ABILITIES, and POTIONS on the Glass page width.
        local loadoutGap = 8
        local loadoutW = math.floor((self.pageW - 28 - loadoutGap) / 2)
        local loadoutY = self.pageH - 326
        for i,entry in ipairs(loadoutActions) do
            local col = (i - 1) % 2
            local row = math.floor((i - 1) / 2)
            spread.loadoutButtons[i] = makeButton("EAS_CodexBest"..entry[1], spread.right, "BEST "..entry[1], 10 + col*(loadoutW+loadoutGap), loadoutY + row*34, loadoutW, 28, function()
                local optimizer = EPC.GearOptimizer
                local fn = optimizer and optimizer[entry[2]]
                if type(fn) == "function" then fn(optimizer) end
                self:RefreshSuitePage("GEAR")
            end)
        end
        local weights = {"LIGHT","MEDIUM","HEAVY"}
        local weightW = math.floor((self.pageW - 44) / 3)
        for i,key in ipairs(weights) do
            spread.armorWeightButtons[i] = makeButton("EAS_CodexArmorWeight_"..key, spread.right, "BEST "..key, 10 + (i-1)*(weightW+2), self.pageH-222, weightW, 28, function()
                if EPC.GearOptimizer and EPC.GearOptimizer.EquipBestArmorWeight then EPC.GearOptimizer:EquipBestArmorWeight(key) end
                self:RefreshSuitePage("GEAR")
            end)
        end
    end
    spread.action0 = makeButton("EAS_CodexInteractiveAction0_"..name, spread.right, "", 18, self.pageH-208, self.pageW-36, 32, function() self:RunInteractiveGearOptimizer(name) end)
    spread.action1 = makeButton("EAS_CodexInteractiveAction1_"..name, spread.right, "ACTION", 18, self.pageH-168, self.pageW-36, 32, function() self:RunInteractivePrimary(name) end)
    spread.action2 = makeButton("EAS_CodexInteractiveAction2_"..name, spread.right, "", 18, self.pageH-128, self.pageW-36, 30, function() self:RunInteractiveSecondaryAction(name) end)
    spread.action3 = makeButton("EAS_CodexInteractiveAction3_"..name, spread.right, "", 18, self.pageH-88, self.pageW-36, 30, function() self:RunInteractiveTertiaryAction(name) end)

    if name == "TRAVEL" then
        spread.guildLeaderSelect = makeButton("EAS_CodexGuildLeaderSelect", spread.right, "GUILD LEADER: NONE", 18, self.pageH-248, self.pageW-36, 30, function()
            self:ShowGuildLeaderHomeDropdown(spread)
        end)
        spread.guildLeaderSelect:SetHidden(false)
        spread.stableTravelButton = makeButton("EAS_CodexStableTravelButton", spread.right, "TRAVEL TO NEAREST STABLEMASTER", 18, self.pageH-72, self.pageW-36, 30, function()
            if EPC.Travel and EPC.Travel.TravelToNearestService then EPC.Travel:TravelToNearestService("STABLE") end
        end)
        spread.stableTravelButton:SetHidden(false)
        spread.pledgeMasterTravelButton = makeButton("EAS_CodexPledgeMasterTravelButton", spread.right, "TRAVEL TO PLEDGE MASTER", 18, self.pageH-38, self.pageW-36, 30, function()
            if EPC.Travel and type(EPC.Travel.TravelToPledgeMaster) == "function" then
                EPC.Travel:TravelToPledgeMaster()
            else
                EPC:Print("Pledge Master travel is unavailable.")
            end
        end)
        spread.pledgeMasterTravelButton:SetHidden(false)
        spread.action0:SetText("TRAVEL TO GUILD LEADER HOME")
        spread.action0:SetHidden(false)
        spread.action0:SetHandler("OnClicked", function()
            if EPC.Travel and EPC.Travel.TravelToSelectedGuildLeaderHome then
                EPC.Travel:TravelToSelectedGuildLeaderHome()
            end
        end)
        spread.action0:ClearAnchors()
        spread.action0:SetAnchor(TOPLEFT, spread.right, TOPLEFT, 18, self.pageH-210)
        spread.action0:SetDimensions(self.pageW-36, 32)
        spread.action0:SetText("GUILD LEADER HOME")
        -- v0.27.66: compact the direct-travel stack so Pledge Master sits
        -- immediately below Stablemaster without clipping the page edge.
        spread.action1:ClearAnchors()
        spread.action1:SetAnchor(TOPLEFT, spread.right, TOPLEFT, 18, self.pageH-174)
        spread.action1:SetDimensions(self.pageW-36, 30)
        spread.action2:ClearAnchors()
        spread.action2:SetAnchor(TOPLEFT, spread.right, TOPLEFT, 18, self.pageH-140)
        spread.action2:SetDimensions(self.pageW-36, 30)
        spread.action3:ClearAnchors()
        spread.action3:SetAnchor(TOPLEFT, spread.right, TOPLEFT, 18, self.pageH-106)
        spread.action3:SetDimensions(self.pageW-36, 30)
        spread.stableTravelButton:ClearAnchors()
        spread.stableTravelButton:SetAnchor(TOPLEFT, spread.right, TOPLEFT, 18, self.pageH-72)
        spread.stableTravelButton:SetDimensions(self.pageW-36, 30)
        spread.pledgeMasterTravelButton:ClearAnchors()
        spread.pledgeMasterTravelButton:SetAnchor(TOPLEFT, spread.right, TOPLEFT, 18, self.pageH-38)
        spread.pledgeMasterTravelButton:SetDimensions(self.pageW-36, 30)

        spread.detailBody:ClearAnchors()
        spread.detailBody:SetAnchor(TOPLEFT, spread.right, TOPLEFT, 18, 124)
        spread.detailBody:SetDimensions(self.pageW-36, self.pageH-398)
    end

    -- v0.24.93: clean selected Gear layout. Keep the detail copy above the
    -- controls, then give every control row its own vertical band.
    if name == "GEAR" then
        spread.detailBody:ClearAnchors()
        spread.detailBody:SetAnchor(TOPLEFT, spread.right, TOPLEFT, 18, 124)
        spread.detailBody:SetDimensions(self.pageW-36, 150)

        local gearActionY = self.pageH - 192
        local gearActionGap = 38
        for i, button in ipairs({spread.action0, spread.action1, spread.action2, spread.action3}) do
            button:ClearAnchors()
            button:SetAnchor(TOPLEFT, spread.right, TOPLEFT, 18, gearActionY + (i-1)*gearActionGap)
            button:SetDimensions(self.pageW-36, i <= 2 and 32 or 30)
        end
    end

    -- v0.24.88: Dungeon Finder needs more breathing room on the selected side.
    -- The generic interactive layout let the detail body extend underneath the
    -- four queue/host buttons. Give DUNGEONS its own stacked action layout so
    -- every control has a dedicated vertical band and nothing overlaps.
    if name == "DUNGEONS" then
        spread.detailTitle:ClearAnchors()
        spread.detailTitle:SetAnchor(TOPLEFT, spread.right, TOPLEFT, 18, 54)
        spread.detailTitle:SetDimensions(self.pageW-36, 42)

        spread.detailBody:ClearAnchors()
        spread.detailBody:SetAnchor(TOPLEFT, spread.right, TOPLEFT, 18, 102)
        spread.detailBody:SetDimensions(self.pageW-36, 220)
        spread.detailBody:SetFont("ZoFontGameSmall")

        local actionY = 338
        local actionGap = 38
        for i, button in ipairs({spread.action0, spread.action1, spread.action2, spread.action3}) do
            button:ClearAnchors()
            button:SetAnchor(TOPLEFT, spread.right, TOPLEFT, 18, actionY + (i-1)*actionGap)
            button:SetDimensions(self.pageW-36, 32)
        end
    end

    spread.action0:SetHidden(name ~= "TRAVEL")
    spread.action2:SetHidden(true)
    spread.action3:SetHidden(true)

    if name == "QUESTS" then
        spread.left:SetMouseEnabled(true)
        spread.left:SetHandler("OnMouseWheel", function(_, delta)
            if EPC.QuestFinder then
                EPC.QuestFinder:Scroll(delta > 0 and -(EPC.QuestFinder.PAGE_SIZE or 8) or (EPC.QuestFinder.PAGE_SIZE or 8))
                self:RefreshSuitePage("QUESTS")
            end
        end)
    end

    return spread
end

-- Override the generic spread creator for sections that need row-by-row interaction.
local easOldCreateSuiteSpread_v191 = CreateSuiteSpreadImplArch
CreateSuiteSpreadImplArch = function(self, name)
    if EAS_INTERACTIVE_TABS[name] then return self:CreateInteractiveSuiteSpread(name) end
    return easOldCreateSuiteSpread_v191(self, name)
end

local RunInteractiveControlImplArch

function J:RunInteractiveControl(...)
    return RunInteractiveControlImplArch(self, ...)
end

RunInteractiveControlImplArch = function(self, tab, index)
    if tab == "GEAR" and EPC.SetJournal then
        local filters = {"ALL","OVERLAND","DUNGEON","TRIAL"}
        EPC.SetJournal:SetFilter(filters[index] or "ALL")
    elseif tab == "QUESTS" and EPC.QuestFinder then
        -- v0.27.63: the fourth visible Quest filter is CADWELL. The old
        -- click map still pointed button 4 at ALL, so pressing CADWELL could
        -- never open the Almanac view even though the button label was right.
        local filters = {"NOT_STARTED","ACTIVE","MAIN_QUEST","CADWELL"}
        if index <= 4 then EPC.QuestFinder:SetFilter(filters[index]) end
        if EPC.RefreshNow then EPC:RefreshNow("codex-quest-filter") end
    elseif tab == "TRAVEL" and EPC.Travel then
        local modes = {"SHRINES","FRIENDS","GUILD","GROUP"}
        EPC.Travel:SetMode(modes[index] or "SHRINES")
    elseif tab == "ACTIVITY" and EPC.Activities then
        local goals = {"BALANCED","XP","GOLD"}
        if index <= 3 then EPC.Activities:SetGoal(goals[index]) end
    elseif tab == "DUNGEONS" and EPC.DungeonFinder then
        EPC.DungeonFinder:SetViewMode("DUNGEONS")
        if index == 1 then EPC.DungeonFinder:SetDifficulty("NORMAL")
        elseif index == 2 then EPC.DungeonFinder:SetDifficulty("VETERAN")
        elseif index == 3 then EPC.DungeonFinder:CycleRole()
        elseif index == 4 then EPC.DungeonFinder:StartScan(true) end
    elseif tab == "GROUPFINDER" and EPC.DungeonFinder then
        EPC.DungeonFinder:SetViewMode("LIVE")
        if index == 1 then EPC.DungeonFinder:CycleLiveCategory()
        elseif index == 2 then EPC.DungeonFinder:SetLiveDifficulty("ALL")
        elseif index == 3 then EPC.DungeonFinder:SetLiveDifficulty("NORMAL")
        elseif index == 4 then EPC.DungeonFinder:SetLiveDifficulty("VETERAN") end
    end
    self:RefreshSuitePage(tab)
end

local RunInteractiveSecondaryImplArch

function J:RunInteractiveSecondary(...)
    return RunInteractiveSecondaryImplArch(self, ...)
end

RunInteractiveSecondaryImplArch = function(self, tab, index)
    if tab == "GEAR" and EPC.SetJournal then
        if index == 1 then EPC.SetJournal:PromptSearch()
        elseif index == 2 then EPC.SetJournal:ClearSearch()
        elseif index == 3 then EPC.SetJournal:ChangePage(-1)
        elseif index == 4 then EPC.SetJournal:ChangePage(1) end
    elseif tab == "QUESTS" and EPC.QuestFinder then
        if index == 1 then
            if type(StartChatInput) == "function" then StartChatInput("/esosuite quest ") end
        elseif index == 2 then EPC.QuestFinder:Scroll(-(EPC.QuestFinder.PAGE_SIZE or 8))
        elseif index == 3 then EPC.QuestFinder:Scroll(EPC.QuestFinder.PAGE_SIZE or 8)
        elseif index == 4 and EPC.RefreshNow then EPC:RefreshNow("codex-quest-refresh") end
    elseif tab == "TRAVEL" and EPC.Travel then
        if index == 1 then EPC.Travel:ChangePage(-1, EPC.Travel.BOOK_PAGE_SIZE or 8)
        elseif index == 2 then EPC.Travel:ChangePage(1, EPC.Travel.BOOK_PAGE_SIZE or 8)
        elseif index == 3 and EPC.RefreshNow then EPC:RefreshNow("codex-travel-refresh") end
    elseif tab == "ACTIVITY" and EPC.RefreshNow then
        EPC:RefreshNow("codex-activity-refresh")
    elseif tab == "DUNGEONS" and EPC.DungeonFinder then
        if index == 1 then EPC.DungeonFinder:ChangePage(-1)
        elseif index == 2 then EPC.DungeonFinder:ChangePage(1)
        elseif index == 3 then EPC.DungeonFinder.autoAccept = not (EPC.DungeonFinder.autoAccept == true)
        elseif index == 4 then EPC.DungeonFinder.enforceRoles = not (EPC.DungeonFinder.enforceRoles == true) end
    elseif tab == "GROUPFINDER" and EPC.DungeonFinder then
        if index == 1 then EPC.DungeonFinder:ChangeLivePage(-1)
        elseif index == 2 then EPC.DungeonFinder:ChangeLivePage(1)
        elseif index == 3 then EPC.DungeonFinder:CycleLiveCategory()
        elseif index == 4 then EPC.DungeonFinder:RefreshLiveListings(true) end
    end
    self:RefreshSuitePage(tab)
end

local SelectInteractiveRowImplArch

function J:SelectInteractiveRow(...)
    return SelectInteractiveRowImplArch(self, ...)
end

SelectInteractiveRowImplArch = function(self, tab, index)
    if tab == "GEAR" and EPC.SetJournal then EPC.SetJournal:SelectRow(index)
    elseif tab == "QUESTS" and EPC.QuestFinder then EPC.QuestFinder:SelectRow(index)
    elseif tab == "TRAVEL" and EPC.Travel then EPC.Travel:SelectVisibleRow(index, EPC.Travel.BOOK_PAGE_SIZE or 8)
    elseif tab == "ACTIVITY" and EPC.Activities then EPC.Activities:SelectVisibleRow(index)
    elseif tab == "DUNGEONS" and EPC.DungeonFinder then EPC.DungeonFinder:SelectRow(index)
    elseif tab == "GROUPFINDER" and EPC.DungeonFinder then EPC.DungeonFinder:SelectLiveRow(index)
    end
    self:RefreshSuitePage(tab)
end

local RunInteractiveGearOptimizerImplArch

function J:RunInteractiveGearOptimizer(...)
    return RunInteractiveGearOptimizerImplArch(self, ...)
end

RunInteractiveGearOptimizerImplArch = function(self, tab)
    if tab == "GEAR" and EPC.GearOptimizer and EPC.GearOptimizer.EquipBestRecommended then
        EPC.GearOptimizer:EquipBestRecommended()
    elseif tab == "DUNGEONS" and EPC.DungeonFinder then EPC.DungeonFinder:QueueSelected()
    elseif tab == "GROUPFINDER" and EPC.DungeonFinder then EPC.DungeonFinder:ApplySelectedLive()
    end
    self:RefreshSuitePage(tab)
end

local RunInteractivePrimaryImplArch

function J:RunInteractivePrimary(...)
    return RunInteractivePrimaryImplArch(self, ...)
end

RunInteractivePrimaryImplArch = function(self, tab)
    if tab == "GEAR" and EPC.SetJournal then EPC.SetJournal:FastTravelSelected()
    elseif tab == "QUESTS" and EPC.QuestFinder then EPC.QuestFinder:RouteSelected()
    elseif tab == "TRAVEL" and EPC.Travel then EPC.Travel:TravelSelected()
    elseif tab == "DUNGEONS" and EPC.DungeonFinder then EPC.DungeonFinder:CreateHostListing()
    elseif tab == "GROUPFINDER" and EPC.DungeonFinder then EPC.DungeonFinder:WhisperSelectedLive()
    end
    self:RefreshSuitePage(tab)
end

local RunInteractiveSecondaryActionImplArch

function J:RunInteractiveSecondaryAction(...)
    return RunInteractiveSecondaryActionImplArch(self, ...)
end

RunInteractiveSecondaryActionImplArch = function(self, tab)
    if tab == "GEAR" and EPC.SetJournal and EPC.SetJournal.RouteSelected then
        EPC.SetJournal:RouteSelected()
    elseif tab == "QUESTS" and EPC.QuestFinder and EPC.QuestFinder.TravelNearestWayshrineSelected then
        EPC.QuestFinder:TravelNearestWayshrineSelected()
    elseif tab == "TRAVEL" and EPC.Travel and EPC.Travel.TravelToNearestService then
        EPC.Travel:TravelToNearestService("MERCHANT")
    elseif tab == "DUNGEONS" and EPC.DungeonFinder then EPC.DungeonFinder:FindReplacement()
    elseif tab == "GROUPFINDER" and EPC.DungeonFinder then EPC.DungeonFinder:RescindLiveApplication()
    end
    self:RefreshSuitePage(tab)
end

local RunInteractiveTertiaryActionImplArch

function J:RunInteractiveTertiaryAction(...)
    return RunInteractiveTertiaryActionImplArch(self, ...)
end

RunInteractiveTertiaryActionImplArch = function(self, tab)
    if tab == "GEAR" and EPC.SetJournal and EPC.SetJournal.OpenSourceQuests then
        EPC.SetJournal:OpenSourceQuests()
    elseif tab == "TRAVEL" and EPC.Travel and EPC.Travel.TravelToNearestService then
        EPC.Travel:TravelToNearestService("GUILD_STORE")
    elseif tab == "DUNGEONS" and EPC.DungeonFinder then EPC.DungeonFinder:CancelQueue()
    elseif tab == "GROUPFINDER" and EPC.DungeonFinder then EPC.DungeonFinder:CreateCurrentDungeonListing()
    end
    self:RefreshSuitePage(tab)
end

local RefreshInteractiveGroupFinderImplArch

function J:RefreshInteractiveGroupFinder(...)
    return RefreshInteractiveGroupFinderImplArch(self, ...)
end

RefreshInteractiveGroupFinderImplArch = function(self, page)
    local D = EPC.DungeonFinder
    if not D then return end
    D.viewMode = "LIVE"
    local v = D:BuildLiveView()

    local widths = {142, 70, 78, 78}
    local x = 14
    for i=1,4 do
        local b = page.controls[i]
        b:ClearAnchors(); b:SetAnchor(TOPLEFT, page.left, TOPLEFT, x, 54); b:SetDimensions(widths[i], 25)
        x = x + widths[i] + 4
    end
    page.controls[1]:SetHidden(false); page.controls[1]:SetText(tostring(v.categoryName or "CATEGORY"))
    page.controls[2]:SetHidden(false); page.controls[2]:SetText("ALL")
    page.controls[3]:SetHidden(false); page.controls[3]:SetText("NORMAL")
    page.controls[4]:SetHidden(false); page.controls[4]:SetText("VETERAN")
    setButtonStyle(page.controls[1], false, self:GetTheme())
    setButtonStyle(page.controls[2], v.difficulty == "ALL", self:GetTheme())
    setButtonStyle(page.controls[3], v.difficulty == "NORMAL", self:GetTheme())
    setButtonStyle(page.controls[4], v.difficulty == "VETERAN", self:GetTheme())

    page.secondary[1]:SetText("< PREV"); page.secondary[2]:SetText("NEXT >")
    page.secondary[3]:SetText("NEXT CATEGORY"); page.secondary[4]:SetText("REFRESH")
    for i=1,4 do page.secondary[i]:SetHidden(false); setButtonStyle(page.secondary[i], false, self:GetTheme()) end
    easSetEnabled(page.secondary[1], (tonumber(v.page) or 1) > 1)
    easSetEnabled(page.secondary[2], (tonumber(v.page) or 1) < (tonumber(v.pageCount) or 1))

    local selected = v.selected
    for i,rowControl in ipairs(page.rows) do
        local row = v.rows and v.rows[i]
        if row then
            rowControl:SetHidden(false)
            local isSelected = selected and row.data == selected
            local rowTitle = tostring(row.title or "Group Listing")
            if row.lastBoss then rowTitle = "LAST BOSS  -  " .. rowTitle end
            rowControl.titleLabel:SetText(rowTitle)
            local detail = tostring(row.owner or "")
            if row.roles and row.roles ~= "" then detail = detail .. "   " .. row.roles end
            if row.activeApplication then detail = "PENDING   " .. detail end
            rowControl.detailLabel:SetText(detail)
            easSetInk(rowControl.titleLabel, isSelected, false); easSetInk(rowControl.detailLabel, isSelected, true)
            if row.lastBoss and EPC.saved.groupFinderWidgetLastBossHighlight == true and not isSelected then
                -- v0.29.341: steady emphasis; no per-frame row animation.
                rowControl:SetHandler("OnUpdate", nil)
                rowControl.titleLabel:SetColor(1.00, 0.78, 0.24, 1)
            else
                rowControl:SetHandler("OnUpdate", nil)
            end
        else rowControl:SetHandler("OnUpdate", nil); rowControl:SetHidden(true) end
    end

    local stateText = D.liveSearchPending and "SEARCHING..." or ((tonumber(v.total) or 0) == 0 and "NO LISTINGS - MONITORING" or "LIVE")
    page.pageLabel:SetText(string.format("%s  -  PAGE %d / %d  -  %d LISTINGS", stateText, tonumber(v.page) or 1, tonumber(v.pageCount) or 1, tonumber(v.total) or 0))

    if selected then
        local function get(method, fallback)
            if type(selected[method]) == "function" then local ok,val=pcall(selected[method],selected); if ok and val ~= nil then return val end end
            return fallback
        end
        local title = tostring(get("GetTitle", "Group Listing"))
        local owner = tostring(get("GetOwnerDisplayName", "Unknown"))
        local description = tostring(get("GetDescription", ""))
        local autoAccept = get("DoesGroupAutoAcceptRequests", false) == true
        local activeApplication = get("IsActiveApplication", false) == true
        local roleText = liveRoleSummary and liveRoleSummary(selected) or ""
        page.detailTitle:SetText((EPC.DungeonFinder and EPC.DungeonFinder:IsLastBossListing(selected) and EPC.saved.groupFinderWidgetLastBossHighlight == true) and ("LAST BOSS  -  " .. title) or title)
        setBookText(page.detailBody, string.format("LEADER\n%s\n\nCATEGORY\n%s\n\nMODE\n%s\n\nROLES\n%s\n\nAPPLICATION\n%s\n\nDESCRIPTION\n%s", owner, tostring(v.categoryName or "Group Finder"), tostring(v.difficulty or "ALL"), roleText ~= "" and roleText or "Any / listing rules", activeApplication and "PENDING" or (autoAccept and "INSTANT JOIN" or "APPLICATION"), description ~= "" and description or "No description provided."), page.detailBody:GetWidth())
    else
        page.detailTitle:SetText("Group Finder")
        setBookText(page.detailBody, "Live ESO player-created listings appear here. Choose a category and Normal/Veteran mode, REFRESH can be used at any time. If the current category has no listings, the page remains ready for ESO search updates. Group Finder search is unavailable while hosting your own listing, in Battlegrounds, or below level 10.", page.detailBody:GetWidth())
    end

    page.action0:SetText("JOIN / APPLY"); page.action1:SetText("WHISPER LEADER")
    page.action2:SetText("RESCIND APPLICATION"); page.action3:SetText("REFRESH")
    for _,b in ipairs({page.action0,page.action1,page.action2,page.action3}) do b:SetHidden(false); setButtonStyle(b,false,self:GetTheme()) end
    easSetEnabled(page.action0, selected ~= nil); easSetEnabled(page.action1, selected ~= nil)
    easSetEnabled(page.action2, true); easSetEnabled(page.action3, true)
end

local RefreshInteractiveGearImplArch

function J:RefreshInteractiveGear(...)
    return RefreshInteractiveGearImplArch(self, ...)
end

RefreshInteractiveGearImplArch = function(self, page)
    local v = EPC.SetJournal and EPC.SetJournal:BuildView() or {rows={}}
    if page.optimizerModes and EPC.GearOptimizer then
        local active = select(1, EPC.GearOptimizer:GetPreset())
        for i,b in ipairs(page.optimizerModes) do
            local key = EPC.GearOptimizer.PRESET_ORDER[i]
            local preset = EPC.GearOptimizer.PRESETS[key]
            b:SetHidden(false)
            b:SetText(preset and preset.label or key)
            setButtonStyle(b, key == active, self:GetTheme())
        end
    end
    if page.companionAbilitiesButton then
        page.companionAbilitiesButton:SetHidden(false)
        setButtonStyle(page.companionAbilitiesButton, false, self:GetTheme())
        if EPC.CompanionOptimizer and type(EPC.CompanionOptimizer.GetButtonLabel) == "function" then
            page.companionAbilitiesButton:SetText(EPC.CompanionOptimizer:GetButtonLabel())
        else
            page.companionAbilitiesButton:SetText("BEST COMPANION ABILITIES + ULT")
        end
        local enabled = EPC.CompanionOptimizer ~= nil
            and type(EPC.CompanionOptimizer.EquipBestAbilities) == "function"
            and type(EPC.CompanionOptimizer.IsAvailable) == "function"
            and EPC.CompanionOptimizer:IsAvailable()
        easSetEnabled(page.companionAbilitiesButton, enabled)
    end
    if page.savedLoadoutsButton then
        page.savedLoadoutsButton:SetHidden(false)
        setButtonStyle(page.savedLoadoutsButton, false, self:GetTheme())
        easSetEnabled(page.savedLoadoutsButton, EPC.LoadoutManager ~= nil and type(EPC.LoadoutManager.Toggle) == "function")
    end
    if page.loadoutButtons and EPC.GearOptimizer then
        local methods = {"EquipBestWeapons","EquipBestJewelry","EquipBestAbilities","EquipBestPotions"}
        for i,b in ipairs(page.loadoutButtons) do
            b:SetHidden(false)
            setButtonStyle(b, false, self:GetTheme())
            easSetEnabled(b, type(EPC.GearOptimizer[methods[i]]) == "function")
        end
    end
    if page.action0 then
        page.action0:SetHidden(false)
        local _,preset = EPC.GearOptimizer and EPC.GearOptimizer:GetPreset() or nil,nil
        page.action0:SetText(preset and ("OPTIMIZE: " .. preset.label) or "ENDGAME OPTIMIZE")
        easSetEnabled(page.action0, EPC.GearOptimizer ~= nil and EPC.GearOptimizer.EquipBestRecommended ~= nil)
    end
    local filters = {"ALL","OVERLAND","DUNGEON","TRIAL"}
    for i,b in ipairs(page.controls) do
        b:SetText(filters[i])
        setButtonStyle(b, filters[i] == v.filter, self:GetTheme())
    end
    page.secondary[1]:SetText("SEARCH")
    page.secondary[2]:SetText("CLEAR")
    page.secondary[3]:SetText("< PREV")
    page.secondary[4]:SetText("NEXT >")
    for i,b in ipairs(page.secondary) do b:SetHidden(false) setButtonStyle(b, false, self:GetTheme()) end
    easSetEnabled(page.secondary[3], (tonumber(v.page) or 1) > 1)
    easSetEnabled(page.secondary[4], (tonumber(v.page) or 1) < (tonumber(v.pageCount) or 1))

    local selectedId = v.selected and v.selected.setId or nil
    for i,rowControl in ipairs(page.rows) do
        local row = v.rows and v.rows[i]
        if row then
            local selected = selectedId ~= nil and selectedId == row.setId
            rowControl:SetHidden(false)
            rowControl.titleLabel:SetText(tostring(row.name or "Item Set"))
            rowControl.detailLabel:SetText(string.format("%d/%d collected  -  %s", tonumber(row.unlocked) or 0, tonumber(row.total) or 0, tostring(row.kindText or "Set pieces")))
            easSetInk(rowControl.titleLabel, selected, false)
            easSetInk(rowControl.detailLabel, selected, true)
        else rowControl:SetHandler("OnUpdate", nil); rowControl:SetHidden(true) end
    end
    page.pageLabel:SetText(string.format("PAGE %d / %d  -  %d SETS", tonumber(v.page) or 1, tonumber(v.pageCount) or 1, tonumber(v.total) or 0))
    if v.selected then
        page.detailTitle:SetText(v.selected.name or "Selected Set")
        setBookText(page.detailBody, string.format("COLLECTION\n%d / %d pieces\n\nTYPE\n%s\n\nSOURCE\n%s\n\n%s", tonumber(v.selected.unlocked) or 0, tonumber(v.selected.total) or 0, tostring(v.selected.kindText or "Set pieces"), tostring(v.selected.sourceText or "Unknown source"), tostring(v.hint or "")), page.detailBody:GetWidth())
        page.action1:SetText("FAST TRAVEL")
        page.action2:SetText("ROUTE SOURCE")
        page.action3:SetText("ZONE QUESTS")
        page.action2:SetHidden(false)
        page.action3:SetHidden(false)
        easSetEnabled(page.action1, true); easSetEnabled(page.action2, true); easSetEnabled(page.action3, true)
    else
        page.detailTitle:SetText("SELECT A SET")
        setBookText(page.detailBody, "Click any set on the left page. Its collection progress, source, and routing actions will appear here.", page.detailBody:GetWidth())
        page.action1:SetText("FAST TRAVEL")
        page.action2:SetText("ROUTE SOURCE")
        page.action3:SetText("ZONE QUESTS")
        page.action2:SetHidden(false)
        page.action3:SetHidden(false)
        easSetEnabled(page.action1, false); easSetEnabled(page.action2, false); easSetEnabled(page.action3, false)
    end
end

function J:RefreshInteractiveQuests(page)
    if page.action0 then page.action0:SetHidden(true) end
    local v = EPC.QuestFinder and EPC.QuestFinder:BuildView() or {rows={}}
    local filters = {{"NOT_STARTED","NOT STARTED"},{"ACTIVE","ACTIVE"},{"MAIN_QUEST","MAIN QUEST"},{"CADWELL","CADWELL"}}

    -- Quest filters have unequal label lengths. Give NOT STARTED and MAIN QUEST
    -- more room instead of forcing all four into identical widths, which clips
    -- those labels at normal Codex sizes.
    local gap = 4
    local usable = self.pageW - 28 - gap * 3
    local weights = { 1.24, 0.84, 1.18, 0.94 }
    local totalWeight = 4.20
    local x = 14
    for i,b in ipairs(page.controls) do
        if i <= 4 then
            local w
            if i < 4 then
                w = math.floor(usable * weights[i] / totalWeight)
            else
                w = (14 + usable + gap * 3) - x
            end
            b:ClearAnchors()
            b:SetAnchor(TOPLEFT, page.left, TOPLEFT, x, 54)
            b:SetDimensions(w, 25)
            b:SetHidden(false)
            b:SetText(filters[i][2])
            setButtonStyle(b, v.filter == filters[i][1], self:GetTheme())
            x = x + w + gap
        else
            b:SetHidden(true)
        end
    end
    page.secondary[1]:SetText("SEARCH")
    page.secondary[2]:SetText("< PREV")
    page.secondary[3]:SetText("NEXT >")
    page.secondary[4]:SetText("REFRESH")
    for _,b in ipairs(page.secondary) do b:SetHidden(false) setButtonStyle(b, false, self:GetTheme()) end
    easSetEnabled(page.secondary[2], (tonumber(v.offset) or 0) > 0)
    easSetEnabled(page.secondary[3], ((tonumber(v.offset) or 0) + #(v.rows or {})) < (tonumber(v.total) or 0))

    local selectedKey = v.selected and v.selected.key or nil
    for i,rowControl in ipairs(page.rows) do
        local row = v.rows and v.rows[i]
        if row then
            local selected = selectedKey ~= nil and selectedKey == row.key
            rowControl:SetHidden(false)
            rowControl.titleLabel:SetText(tostring(row.name or "Quest"))
            local meta = string.format("%s  -  %s", tostring(row.zone or "Unknown zone"), tostring(row.status or row.type or "Quest"))
            rowControl.detailLabel:SetText(meta)
            easSetInk(rowControl.titleLabel, selected, false)
            easSetInk(rowControl.detailLabel, selected, true)
        else rowControl:SetHandler("OnUpdate", nil); rowControl:SetHidden(true) end
    end
    local first = (tonumber(v.offset) or 0) + 1
    local last = math.min(tonumber(v.total) or 0, first + #(v.rows or {}) - 1)
    page.pageLabel:SetText(string.format("%d-%d OF %d  -  %s", (v.total or 0) > 0 and first or 0, last, tonumber(v.total) or 0, tostring(v.scanProgress or "INDEX")))
    if v.selected then
        page.detailTitle:SetText(v.selected.name or "Selected Quest")

        -- Show the resolved wayshrine directly beneath the zone. For accepted
        -- quests this uses the same Active/Main/Golden objective resolver as
        -- Map/Travel, so the label reflects the shrine actually chosen for the
        -- current objective rather than an arbitrary shrine in the zone.
        local wayshrineName = "Locating closest discovered wayshrine..."
        if EPC.Travel and type(EPC.Travel.GetFocusedQuest) == "function" then
            local focused = EPC.Travel:GetFocusedQuest(EPC.lastSnapshot or {})
            if focused and (tonumber(focused.questIndex) or 0) == (tonumber(v.selected.questIndex) or 0) then
                local position = focused.position
                if position and position.bestShrineName and tostring(position.bestShrineName) ~= "" then
                    wayshrineName = tostring(position.bestShrineName)
                elseif position and position.available == false then
                    local entry = nil
                    if type(EPC.Travel.GetNearestWayshrineForQuestSelection) == "function" then
                        entry = select(1, EPC.Travel:GetNearestWayshrineForQuestSelection(v.selected))
                    end
                    if entry and entry.name then
                        wayshrineName = tostring(entry.name)
                    else
                        wayshrineName = "No discovered wayshrine resolved"
                    end
                end
            elseif (tonumber(v.selected.questIndex) or 0) <= 0 and type(EPC.Travel.GetNearestWayshrineForQuestSelection) == "function" then
                local entry = select(1, EPC.Travel:GetNearestWayshrineForQuestSelection(v.selected))
                if entry and entry.name then wayshrineName = tostring(entry.name) end
            end
        end

        local details = {
            "STATUS\n" .. tostring(v.selected.status or v.selected.type or "Quest"),
            "ZONE\n" .. tostring(v.selected.zone or "Unknown zone"),
            "WAYSHRINE\n" .. wayshrineName,
        }
        if v.selected.mainQuest then
            details[#details+1] = "MAIN QUEST STEP\n" .. tostring(v.selected.chainOrder or "?")
        elseif v.selected.cadwell then
            details[#details+1] = "ALMANAC OBJECTIVE\n" .. tostring(v.selected.objectiveProgress or "0/0")
            details[#details+1] = "REQUIRED QUESTS\n" .. tostring(v.selected.objectiveQuests or "")
            if v.selected.targetQuestName and v.selected.targetQuestName ~= "" then
                details[#details+1] = "NEXT REQUIRED QUEST\n" .. tostring(v.selected.targetQuestName)
            end
        end
        if v.selected.mainQuest and not v.selected.questIndex then
            if v.selected.questGiver and v.selected.questGiver ~= "" then details[#details+1] = "ACCEPT FROM\n" .. tostring(v.selected.questGiver) end
            if v.selected.acceptAt and v.selected.acceptAt ~= "" then details[#details+1] = "ACCEPT AT\n" .. tostring(v.selected.acceptAt) end
            if v.selected.prerequisite and v.selected.prerequisite ~= "" then details[#details+1] = "REQUIREMENT\n" .. tostring(v.selected.prerequisite) end
            if v.selected.routeNote and v.selected.routeNote ~= "" then details[#details+1] = "ROUTE\n" .. tostring(v.selected.routeNote) end
        else
            details[#details+1] = "STARTER / ACCESS\n" .. tostring(v.selected.starter or "Starter location unknown")
            details[#details+1] = tostring(v.selected.access or "")
        end
        if v.selected.requires then details[#details+1] = "REQUIRES\n" .. tostring(v.selected.requires) end
        -- v0.27.63: Almanac objectives can contain several long quest names.
        -- Use the compact book font and single-spaced sections for Cadwell so
        -- the full required-quest list stays inside the Selected page instead
        -- of being cut off above the action buttons.
        if v.selected.cadwell then
            if page.detailBody.SetFont then page.detailBody:SetFont("ZoFontGameSmall") end
            local cadwellText = table.concat(details, "\n")
            page.detailBody:SetText(wrapForBook(page.detailBody, cadwellText, page.detailBody:GetWidth()))
        else
            setBookText(page.detailBody, table.concat(details, "\n\n"), page.detailBody:GetWidth())
        end
        if v.selected.mainQuest then
            if v.selected.completed then
                page.action1:SetText("MAIN QUEST COMPLETED")
            elseif v.selected.questIndex then
                page.action1:SetText("TRACK MAIN QUEST")
            else
                page.action1:SetText("SELECT NEXT MAIN QUEST")
            end
        elseif v.selected.cadwell then
            if v.selected.completed then page.action1:SetText("ALMANAC OBJECTIVE COMPLETE")
            elseif v.selected.questIndex then page.action1:SetText("TRACK REQUIRED QUEST")
            else page.action1:SetText("ROUTE TO ALMANAC OBJECTIVE") end
        else
            page.action1:SetText("ROUTE TO STARTER")
        end
        page.action2:SetText("TRAVEL TO NEAREST WAYSHRINE")
        page.action2:SetHidden(false)
        easSetEnabled(page.action1, not (v.selected.mainQuest and v.selected.completed))
        easSetEnabled(page.action2, not v.selected.completed and EPC.Travel ~= nil and EPC.Travel.TravelToNearestQuestStarterWayshrine ~= nil)
    else
        page.detailTitle:SetText("SELECT A QUEST")
        setBookText(page.detailBody, "Click a quest on the left page to select it. The starter/access information and route button will appear here.", page.detailBody:GetWidth())
        page.action1:SetText("ROUTE TO STARTER")
        page.action2:SetText("TRAVEL TO NEAREST WAYSHRINE")
        page.action2:SetHidden(false)
        easSetEnabled(page.action1, false)
        easSetEnabled(page.action2, false)
    end
end

function J:RefreshInteractiveTravel(page)
    if page.action0 then page.action0:SetHidden(true) end
    local bookPageSize = EPC.Travel and (EPC.Travel.BOOK_PAGE_SIZE or 8) or 8
    local v = EPC.Travel and EPC.Travel:BuildView(EPC.lastSnapshot or {}, bookPageSize) or {rows={}}
    local modes = {{"SHRINES","SHRINES"},{"FRIENDS","FRIENDS"},{"GUILD","GUILD"},{"GROUP","GROUP"}}
    for i,b in ipairs(page.controls) do
        b:SetHidden(false); b:SetText(modes[i][2]); setButtonStyle(b, v.mode == modes[i][1], self:GetTheme())
    end
    page.secondary[1]:SetText("< PREV")
    page.secondary[2]:SetText("NEXT >")
    page.secondary[3]:SetText("REFRESH")
    page.secondary[4]:SetHidden(true)
    for i,b in ipairs(page.secondary) do if i <= 3 then b:SetHidden(false) setButtonStyle(b, false, self:GetTheme()) end end
    easSetEnabled(page.secondary[1], v.canPageBack == true)
    easSetEnabled(page.secondary[2], v.canPageForward == true)
    if page.stableTravelButton then
        page.stableTravelButton:SetHidden(false)
        easSetEnabled(page.stableTravelButton, EPC.Travel ~= nil and EPC.Travel.TravelToNearestService ~= nil)
    end

    local selectedKey = v.selected and v.selected.key or nil
    for i,rowControl in ipairs(page.rows) do
        local row = v.rows and v.rows[i]
        if row then
            local selected = selectedKey ~= nil and selectedKey == row.key
            rowControl:SetHidden(false)
            if row.kind == "ZONE_HEADER" then
                local prefix = row.expanded and "v  " or ">  "
                local suffix = string.format("  (%d shrine%s)", tonumber(row.shrineCount) or 0, (tonumber(row.shrineCount) or 0) == 1 and "" or "s")
                rowControl.titleLabel:SetText(prefix .. tostring(row.name or "Zone") .. suffix)
                local tags = {}
                if row.hasQuestBest then tags[#tags+1] = "QUEST ZONE" end
                if row.isCurrentZone then tags[#tags+1] = "CURRENT ZONE" end
                rowControl.detailLabel:SetText(#tags > 0 and table.concat(tags, "  -  ") or "Click to show wayshrines")
                easSetInk(rowControl.titleLabel, row.hasQuestBest or row.isQuestZone, false)
                easSetInk(rowControl.detailLabel, false, true)
            else
                rowControl.titleLabel:SetText("   " .. tostring(row.name or "Destination"))
                local detail = string.format("%s  -  %s", tostring(row.costText or ""), tostring(row.statusText or ""))
                if row.isQuestBest then detail = "QUEST BEST  -  " .. detail end
                rowControl.detailLabel:SetText("   " .. detail)
                easSetInk(rowControl.titleLabel, selected, row.canTravel ~= true)
                easSetInk(rowControl.detailLabel, selected, true)
            end
        else rowControl:SetHandler("OnUpdate", nil); rowControl:SetHidden(true) end
    end
    page.pageLabel:SetText(string.format("PAGE %d / %d  -  %s", tonumber(v.page) or 1, tonumber(v.pageCount) or 1, tostring(v.modeLabel or v.mode or "TRAVEL")))

    if page.guildLeaderSelect and EPC.Travel and EPC.Travel.GetSelectedGuildLeaderHome then
        local leaderHome, guildOptions = EPC.Travel:GetSelectedGuildLeaderHome()
        if leaderHome then
            local multi = type(guildOptions) == "table" and #guildOptions > 1
            local label = tostring(leaderHome.guildName or "Guild") .. " - " .. tostring(leaderHome.leaderName ~= "" and leaderHome.leaderName or "Leader unavailable")
            page.guildLeaderSelect:SetText((multi and "SELECT GUILD: " or "GUILD: ") .. label .. (multi and "  v" or ""))
            easSetEnabled(page.guildLeaderSelect, true)
            page.guildLeaderSelect:SetHidden(false)
            page.action0:SetText("GUILD LEADER HOME")
            page.action0:SetHidden(false)
            easSetEnabled(page.action0, leaderHome.leaderName ~= nil and leaderHome.leaderName ~= "")
        else
            page.guildLeaderSelect:SetText("GUILD LEADER: NO GUILDS")
            page.guildLeaderSelect:SetHidden(false)
            easSetEnabled(page.guildLeaderSelect, false)
            page.action0:SetText("GUILD LEADER HOME")
            page.action0:SetHidden(false)
            easSetEnabled(page.action0, false)
        end
    end

    if v.selected then
        page.detailTitle:SetText(v.selected.name or "Selected Destination")
        local details = string.format("ZONE\n%s\n\nCOST\n%s\n\n\nSTATUS\n%s", tostring(v.selected.zoneName or "Unknown zone"), tostring(v.selected.costText or ""), tostring(v.selected.statusText or ""))
        setBookText(page.detailBody, details, page.detailBody:GetWidth())
        page.action1:SetText("TRAVEL TO SELECTED")
        page.action2:SetText("NEAREST MERCHANT")
        page.action3:SetText("NEAREST GUILD STORE")
        page.action2:SetHidden(false)
        page.action3:SetHidden(false)
        if page.stableTravelButton then
            page.stableTravelButton:SetText("NEAREST STABLEMASTER")
            page.stableTravelButton:SetHidden(false)
            easSetEnabled(page.stableTravelButton, EPC.Travel ~= nil and EPC.Travel.TravelToNearestService ~= nil)
        end
        if page.pledgeMasterTravelButton then
            page.pledgeMasterTravelButton:SetText("TRAVEL TO PLEDGE MASTER")
            page.pledgeMasterTravelButton:SetHidden(false)
            easSetEnabled(page.pledgeMasterTravelButton, EPC.Travel ~= nil and type(EPC.Travel.TravelToPledgeMaster) == "function")
        end
        easSetEnabled(page.action1, v.actionEnabled == true)
        easSetEnabled(page.action2, EPC.Travel ~= nil and EPC.Travel.TravelToNearestService ~= nil)
        easSetEnabled(page.action3, EPC.Travel ~= nil and EPC.Travel.TravelToNearestService ~= nil)
    else
        page.detailTitle:SetText("SELECT A DESTINATION")
        setBookText(page.detailBody, tostring(v.emptyText or "Click a destination on the left page, then use TRAVEL here. You can also jump directly toward the nearest merchant or guild store."), page.detailBody:GetWidth())
        page.action1:SetText("TRAVEL TO SELECTED")
        page.action2:SetText("NEAREST MERCHANT")
        page.action3:SetText("NEAREST GUILD STORE")
        page.action2:SetHidden(false)
        page.action3:SetHidden(false)
        if page.stableTravelButton then
            page.stableTravelButton:SetText("NEAREST STABLEMASTER")
            page.stableTravelButton:SetHidden(false)
            easSetEnabled(page.stableTravelButton, EPC.Travel ~= nil and EPC.Travel.TravelToNearestService ~= nil)
        end
        if page.pledgeMasterTravelButton then
            page.pledgeMasterTravelButton:SetText("TRAVEL TO PLEDGE MASTER")
            page.pledgeMasterTravelButton:SetHidden(false)
            easSetEnabled(page.pledgeMasterTravelButton, EPC.Travel ~= nil and type(EPC.Travel.TravelToPledgeMaster) == "function")
        end
        easSetEnabled(page.action1, false)
        easSetEnabled(page.action2, EPC.Travel ~= nil and EPC.Travel.TravelToNearestService ~= nil)
        easSetEnabled(page.action3, EPC.Travel ~= nil and EPC.Travel.TravelToNearestService ~= nil)
    end
end


function J:HideGuildLeaderHomeDropdown()
    if self.guildLeaderHomeDropdown then
        self.guildLeaderHomeDropdown:SetHidden(true)
    end
end

local ShowGuildLeaderHomeDropdownImplArch

function J:ShowGuildLeaderHomeDropdown(...)
    return ShowGuildLeaderHomeDropdownImplArch(self, ...)
end

ShowGuildLeaderHomeDropdownImplArch = function(self, page)
    if not EPC.Travel or not EPC.Travel.GetGuildLeaderHomeOptions then return end
    local options = EPC.Travel:GetGuildLeaderHomeOptions()
    if #options == 0 then
        if EPC.Print then EPC:Print("You are not currently in a guild.") end
        self:HideGuildLeaderHomeDropdown()
        return
    end

    local anchor = page and page.guildLeaderSelect or nil
    if not anchor then return end

    -- Use a Suite-native dropdown instead of ESO's global ShowMenu(). The
    -- global menu can render behind the Codex and does not match this UI.
    local popup = self.guildLeaderHomeDropdown
    if not popup then
        popup = wm:CreateTopLevelWindow("EAS_GuildLeaderHomeDropdown")
        popup:SetMouseEnabled(true)
        popup:SetClampedToScreen(true)
        popup:SetDrawTier(DT_HIGH)
        popup:SetDrawLayer(DL_OVERLAY)
        popup:SetDrawLevel(5000)
        popup:SetHidden(true)
        self.guildLeaderHomeDropdown = popup

        local bg = wm:CreateControl("EAS_GuildLeaderHomeDropdown_BG", popup, CT_BACKDROP)
        bg:SetAnchorFill(popup)
        bg:SetEdgeTexture(nil, 1, 1, 1)
        popup.epcBG = bg

        local title = wm:CreateControl("EAS_GuildLeaderHomeDropdown_Title", popup, CT_LABEL)
        title:SetFont("ZoFontGameBold")
        title:SetAnchor(TOPLEFT, popup, TOPLEFT, 12, 8)
        title:SetAnchor(TOPRIGHT, popup, TOPRIGHT, -12, 8)
        title:SetHeight(22)
        title:SetText("SELECT GUILD LEADER")
        title:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        title:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        popup.epcTitle = title
        popup.epcRows = {}
    elseif not popup:IsHidden() then
        popup:SetHidden(true)
        return
    end

    local theme = self:GetTheme() or THEMES.MIDNIGHT
    local accent = theme.accent or {0.43,0.68,0.96,1}
    local textColor = theme.text or {0.88,0.92,0.98,1}
    popup.epcBG:SetCenterColor(0.018, 0.024, 0.034, 0.985)
    popup.epcBG:SetEdgeColor(accent[1], accent[2], accent[3], 0.95)
    popup.epcTitle:SetColor(textColor[1], textColor[2], textColor[3], 1)

    local width = math.max(300, tonumber(anchor:GetWidth()) or 360)
    local rowH, titleH, pad = 34, 32, 8
    local height = titleH + (#options * rowH) + pad
    popup:SetDimensions(width, height)
    popup:ClearAnchors()
    if page and page.guildLeaderAnchorAbove then
        popup:SetAnchor(BOTTOMRIGHT, anchor, TOPRIGHT, 0, -5)
    else
        popup:SetAnchor(TOP, anchor, BOTTOM, 0, 5)
    end

    for i = 1, #popup.epcRows do
        popup.epcRows[i]:SetHidden(true)
    end

    local selected = EPC.Travel:GetSelectedGuildLeaderHome()
    for i,row in ipairs(options) do
        local button = popup.epcRows[i]
        if not button then
            button = wm:CreateControl("EAS_GuildLeaderHomeDropdown_Row" .. tostring(i), popup, CT_BUTTON)
            button:SetFont("ZoFontGameBold")
            button:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            button:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            button:SetDrawLayer(DL_OVERLAY)
            button:SetDrawLevel(5002)

            local rowBg = wm:CreateControl("EAS_GuildLeaderHomeDropdown_RowBG" .. tostring(i), button, CT_BACKDROP)
            rowBg:SetAnchorFill(button)
            rowBg:SetEdgeTexture(nil, 1, 1, 1)
            rowBg:SetDrawLevel(5001)
            button.epcBG = rowBg
            popup.epcRows[i] = button
        end

        button:ClearAnchors()
        button:SetAnchor(TOPLEFT, popup, TOPLEFT, 8, titleH + ((i - 1) * rowH))
        button:SetAnchor(TOPRIGHT, popup, TOPRIGHT, -8, titleH + ((i - 1) * rowH))
        button:SetHeight(rowH - 3)
        button:SetHidden(false)

        local guildId = row.guildId
        local label = tostring(row.guildName or "Guild")
        local leader = tostring(row.leaderName or "")
        if leader ~= "" then label = label .. "  -  " .. leader end
        button:SetText("  " .. label)

        local isSelected = selected and tonumber(selected.guildId) == tonumber(guildId)
        if isSelected then
            button.epcBG:SetCenterColor(accent[1], accent[2], accent[3], 0.20)
            button.epcBG:SetEdgeColor(accent[1], accent[2], accent[3], 0.82)
            button:SetNormalFontColor(accent[1], accent[2], accent[3], 1)
        else
            button.epcBG:SetCenterColor(0.035, 0.045, 0.060, 0.96)
            button.epcBG:SetEdgeColor(0.16, 0.22, 0.30, 0.78)
            button:SetNormalFontColor(textColor[1], textColor[2], textColor[3], 0.96)
        end
        button:SetMouseOverFontColor(accent[1], accent[2], accent[3], 1)
        button:SetPressedFontColor(accent[1], accent[2], accent[3], 1)
        button:SetHandler("OnMouseEnter", function(control)
            if control.epcBG then control.epcBG:SetCenterColor(accent[1], accent[2], accent[3], 0.16) end
        end)
        button:SetHandler("OnMouseExit", function(control)
            local active = EPC.Travel:GetSelectedGuildLeaderHome()
            local activeId = active and tonumber(active.guildId) or nil
            if control.epcBG then
                if activeId == tonumber(guildId) then
                    control.epcBG:SetCenterColor(accent[1], accent[2], accent[3], 0.20)
                else
                    control.epcBG:SetCenterColor(0.035, 0.045, 0.060, 0.96)
                end
            end
        end)
        button:SetHandler("OnClicked", function()
            EPC.Travel:SelectGuildLeaderGuild(guildId)
            self:HideGuildLeaderHomeDropdown()
            self:RefreshSuitePage("TRAVEL")
            if page and page.guildLeaderTravelOnSelect and EPC.Travel.TravelToSelectedGuildLeaderHome then
                EPC.Travel:TravelToSelectedGuildLeaderHome()
            end
        end)
    end

    popup:SetHidden(false)
end

local RefreshInteractiveActivityImplArch

function J:RefreshInteractiveActivity(...)
    return RefreshInteractiveActivityImplArch(self, ...)
end

RefreshInteractiveActivityImplArch = function(self, page)
    if page.action0 then page.action0:SetHidden(true) end
    local v = EPC.Activities and EPC.Activities:BuildView(EPC.lastSnapshot or {}) or {rows={}}
    local goals = {{"BALANCED","BALANCED"},{"XP","XP"},{"GOLD","GOLD"}}
    for i,b in ipairs(page.controls) do
        if i <= 3 then b:SetHidden(false); b:SetText(goals[i][2]); setButtonStyle(b, v.goal == goals[i][1], self:GetTheme()) else b:SetHidden(true) end
    end
    page.secondary[1]:SetText("REFRESH")
    page.secondary[2]:SetHidden(true)
    page.secondary[3]:SetHidden(true)
    page.secondary[4]:SetHidden(true)
    page.secondary[1]:SetHidden(false)
    setButtonStyle(page.secondary[1], false, self:GetTheme())

    local selectedKey = v.selected and v.selected.key or nil
    for i,rowControl in ipairs(page.rows) do
        local row = v.rows and v.rows[i]
        if row then
            local selected = selectedKey ~= nil and selectedKey == row.key
            rowControl:SetHidden(false)
            rowControl.titleLabel:SetText(tostring(row.name or row.displayText or "Activity"))
            rowControl.detailLabel:SetText(tostring(row.detailText or row.location or ""))
            easSetInk(rowControl.titleLabel, selected, false)
            easSetInk(rowControl.detailLabel, selected, true)
        else rowControl:SetHandler("OnUpdate", nil); rowControl:SetHidden(true) end
    end
    page.pageLabel:SetText(string.format("GOAL: %s", tostring(v.goalLabel or v.goal or "BALANCED")))
    page.action1:SetHidden(true)
    page.action2:SetHidden(true)
    easSetEnabled(page.action1, false)
    easSetEnabled(page.action2, false)

    if v.selected then
        page.detailTitle:SetText(v.selected.name or "Selected Activity")
        local primary = tostring(v.selected.detailText or v.selected.location or "")
        local note = tostring(v.selected.note or "")
        local details = primary
        if note ~= "" and note ~= primary then
            details = primary .. "\n\n" .. note
        end
        setBookText(page.detailBody, details, page.detailBody:GetWidth())
    else
        page.detailTitle:SetText("SELECT AN ACTIVITY")
        setBookText(page.detailBody, tostring(v.hint or "Select an activity on the left to view its details."), page.detailBody:GetWidth())
    end
end

-- Override the v0.19 plain-text renderer for interactive sections.
local easOldRefreshSuitePage_v191 = RefreshSuitePageImplArch
RefreshSuitePageImplArch = function(self, tab)
    tab = tab or self.activeTab
    local page = self.pages and self.pages[tab]
    if page and page.interactive then
        if tab == "GEAR" then self:RefreshInteractiveGear(page)
        elseif tab == "QUESTS" then self:RefreshInteractiveQuests(page)
        elseif tab == "TRAVEL" then self:RefreshInteractiveTravel(page)
        elseif tab == "ACTIVITY" then self:RefreshInteractiveActivity(page)
        elseif tab == "DUNGEONS" then self:RefreshInteractiveDungeons(page)
        elseif tab == "GROUPFINDER" then self:RefreshInteractiveGroupFinder(page) end
        return
    end
    return easOldRefreshSuitePage_v191(self, tab)
end

--[[
    v0.19.3 readability/layout override
    - Keeps global book controls inside the native lore-book pages.
    - Notes use an explicit TITLE field with a large NOTES body beneath it.
    - Checkpoints expose a clear NAME THIS CHECKPOINT field for labels such as XP Farm.
    - Book text uses explicit word wrapping and a smaller readable font for dense pages.
]]

-- Rebind the shared book text helper so every later refresh uses readable wrapping.
setBookText = function(label, text, width)
    if not label then return end
    text = tostring(text or "")
    width = tonumber(width) or (label.GetWidth and label:GetWidth()) or 320
    if label.SetVerticalAlignment then label:SetVerticalAlignment(TEXT_ALIGN_TOP) end

    -- Start with the normal readable game font. Dense pages automatically step down
    -- to the standard small font rather than clipping horizontally.
    if label.SetFont then label:SetFont("ZoFontGame") end
    local wrapped = wrapForBook(label, text, width)
    local lineCount = 0
    for _ in string.gmatch(wrapped .. "\n", "(.-)\n") do lineCount = lineCount + 1 end
    if lineCount > 30 and label.SetFont then
        label:SetFont("ZoFontGameSmall")
        wrapped = wrapForBook(label, text, width)
    end
    label:SetText(wrapped)
end

CreateNotesSpreadImplArch = function(self)
    local spread = self:CreateSpreadShell("NOTES")
    self:AddSpreadHeader(spread, "NOTES", "WRITE / READ NOTE")
    self.notePage = spread

    -- Left page: browse notes. Keep categories compact so the note list gets most of the page.
    local catHeader = makeLabel("EAS_CodexNotesCategoryHeader", spread.left, "CATEGORIES", 12, 54, self.pageW-24, 20, "ZoFontGameSmall")
    self.themeLabels[#self.themeLabels+1] = catHeader
    self.categoryHeader = catHeader
    self.categoryButtons = {}
    local catW = math.floor((self.pageW - 38) / 2)
    for i,cat in ipairs(CATEGORIES) do
        local col = (i-1) % 2
        local row = math.floor((i-1) / 2)
        local b = makeButton("EAS_CodexNoteCat_v193_"..i, spread.left, cat, 12 + col*(catW+10), 78 + row*24, catW, 21, function() self:SetCategory(cat) end)
        b:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        self.categoryButtons[cat] = b
    end

    self.noteCount = makeLabel("EAS_CodexNoteCount_v193", spread.left, "", 12, 180, self.pageW-24, 20, "ZoFontGameSmall")
    self.themeLabels[#self.themeLabels+1] = self.noteCount
    self.noteRows = {}
    for i=1,11 do
        local b = makeButton("EAS_CodexNoteRow_v193_"..i, spread.left, "", 12, 208+(i-1)*31, self.pageW-24, 27, function(control)
            if control.entryId then self:SelectEntry(control.entryId) end
        end)
        b:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        self.noteRows[i] = b
    end

    -- Right page: TITLE first, then the note body directly below it.
    local titleLabel = makeLabel("EAS_CodexNoteTitleLabel_v193", spread.right, "TITLE", 12, 56, self.pageW-24, 20, "ZoFontGameBold")
    self.themeLabels[#self.themeLabels+1] = titleLabel
    self.noteTitleEdit = self:CreateEditBox("EAS_CodexNoteTitle_v193", spread.right, 12, 80, self.pageW-24, 36, false)
    self.noteTitleEdit:SetFont("ZoFontGameBold")

    local notesLabel = makeLabel("EAS_CodexNoteBodyLabel_v193", spread.right, "NOTES", 12, 128, self.pageW-24, 20, "ZoFontGameBold")
    self.themeLabels[#self.themeLabels+1] = notesLabel
    local actionY = self.pageH - 102
    self.noteBodyEdit = self:CreateEditBox("EAS_CodexNoteBody_v193", spread.right, 12, 152, self.pageW-24, math.max(250, actionY-164), true)
    self.noteBodyEdit:SetFont("ZoFontGame")

    local gap = 6
    local bw = math.floor((self.pageW - 24 - gap*3) / 4)
    self.newButton = makeButton("EAS_CodexNoteNew_v193", spread.right, "NEW", 12, actionY, bw, 27, function() self:NewEntry() end)
    self.saveButton = makeButton("EAS_CodexNoteSave_v193", spread.right, "SAVE", 12+bw+gap, actionY, bw, 27, function() self:SaveCurrentEntry() end)
    self.deleteButton = makeButton("EAS_CodexNoteDelete_v193", spread.right, "DELETE", 12+(bw+gap)*2, actionY, bw, 27, function() self:DeleteEntry() end)
    self.modeButton = makeButton("EAS_CodexNoteMode_v193", spread.right, "EDIT", 12+(bw+gap)*3, actionY, bw, 27, function()
        self.readMode = not self.readMode
        self:EnsureSaved().readMode = self.readMode
        self:SetEditorEnabled(not self.readMode)
        self:ApplyTheme()
    end)
    self.topButtons[#self.topButtons+1] = self.newButton
    self.topButtons[#self.topButtons+1] = self.saveButton
    self.topButtons[#self.topButtons+1] = self.deleteButton
    self.topButtons[#self.topButtons+1] = self.modeButton

    local autosave = makeLabel("EAS_CodexNoteAutosave_v193", spread.right,
        "Auto-save is on when you change notes, change chapters, or close the Codex.",
        12, actionY+31, self.pageW-24, 34, "ZoFontGameSmall")
    self.themeLabels[#self.themeLabels+1] = autosave
    setBookText(autosave, autosave:GetText(), autosave:GetWidth())
    return spread
end

CreatePinsSpreadImplArch = function(self)
    local spread = self:CreateSpreadShell("PINS")
    self:AddSpreadHeader(spread, "CHECKPOINTS", "CHECKPOINT DETAILS")

    local nameLabel = makeLabel("EAS_CodexCheckpointNameLabel_v193", spread.left, "NAME THIS CHECKPOINT", 12, 54, self.pageW-24, 20, "ZoFontGameBold")
    self.themeLabels[#self.themeLabels+1] = nameLabel
    local hint = makeLabel("EAS_CodexCheckpointNameHint_v193", spread.left,
        "Example: XP Farm, Material Route, World Boss, Fishing Spot",
        12, 76, self.pageW-24, 38, "ZoFontGameSmall")
    self.themeLabels[#self.themeLabels+1] = hint
    setBookText(hint, hint:GetText(), hint:GetWidth())

    self.checkpointNameEdit = wm:CreateControl("EAS_CodexCheckpointName_v193", spread.left, CT_EDITBOX)
    self.checkpointNameEdit:SetAnchor(TOPLEFT, spread.left, TOPLEFT, 12, 116)
    self.checkpointNameEdit:SetDimensions(self.pageW-24, 34)
    self.checkpointNameEdit:SetFont("ZoFontGameBold")
    if self.checkpointNameEdit.SetMaxInputChars then self.checkpointNameEdit:SetMaxInputChars(80) end

    local savedLabel = makeLabel("EAS_CodexCheckpointSavedLabel_v193", spread.left, "SAVED CHECKPOINTS", 12, 160, self.pageW-24, 20, "ZoFontGameSmall")
    self.themeLabels[#self.themeLabels+1] = savedLabel
    self.pinRows = {}
    for i=1,8 do
        local b = makeButton("EAS_CodexCheckpointRow_v193_"..i, spread.left, "", 12, 184+(i-1)*39, self.pageW-24, 34, function(control)
            self.selectedPinId = control.pinId
            local selected = self:GetPinById(control.pinId)
            if selected and self.checkpointNameEdit then self.checkpointNameEdit:SetText(selected.name or "") end
            self:RefreshPinsPage()
        end)
        b:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        self.pinRows[i] = b
    end

    self.checkpointPrev = makeButton("EAS_CodexCheckpointPrev_v193", spread.left, "< PREV", 12, self.pageH-66, 78, 26, function() self:ChangeCheckpointPage(-1) end)
    self.checkpointPageLabel = makeLabel("EAS_CodexCheckpointPage_v193", spread.left, "", 96, self.pageH-64, self.pageW-192, 22, "ZoFontGameSmall")
    self.checkpointPageLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.themeLabels[#self.themeLabels+1] = self.checkpointPageLabel
    self.checkpointNext = makeButton("EAS_CodexCheckpointNext_v193", spread.left, "NEXT >", self.pageW-90, self.pageH-66, 78, 26, function() self:ChangeCheckpointPage(1) end)

    local detailsIntro = makeLabel("EAS_CodexCheckpointDetailIntro_v193", spread.right,
        "Select a saved checkpoint on the left. You can update it to your current location, place a waypoint, or delete it.",
        18, 56, self.pageW-36, 78, "ZoFontGameSmall")
    self.themeLabels[#self.themeLabels+1] = detailsIntro
    setBookText(detailsIntro, detailsIntro:GetText(), detailsIntro:GetWidth())

    self.pinInfo = makeLabel("EAS_CodexCheckpointInfo_v193", spread.right, "", 18, 140, self.pageW-36, self.pageH-390, "ZoFontGame")
    self.themeLabels[#self.themeLabels+1] = self.pinInfo
    self.pinSave = makeButton("EAS_CodexCheckpointSave_v193", spread.right, "SAVE / UPDATE HERE", 18, self.pageH-200, self.pageW-36, 30, function()
        self:SaveCurrentLocation(self.checkpointNameEdit and self.checkpointNameEdit:GetText() or "")
    end)
    self.pinWaypoint = makeButton("EAS_CodexCheckpointWaypoint_v193", spread.right, "SET EXACT CHECKPOINT WAYPOINT", 18, self.pageH-162, self.pageW-36, 30, function() self:SetPinWaypoint() end)
    self.pinWayshrine = makeButton("EAS_CodexCheckpointWayshrine_v213", spread.right, "TRAVEL TO WAYSHRINE", 18, self.pageH-124, self.pageW-36, 30, function() self:TravelToNearestCheckpointWayshrine() end)
    if self.pinWayshrine.SetEnabled then self.pinWayshrine:SetEnabled(false) end
    self.pinDelete = makeButton("EAS_CodexCheckpointDelete_v193", spread.right, "DELETE CHECKPOINT", 18, self.pageH-86, self.pageW-36, 30, function() self:DeletePin() end)
    return spread
end

-- Interactive rows should never use ellipsis. Use a compact second line and explicit wrapping.
CreateBookRowImplArch = function(self, parent, name, index, y, onClick)
    local row = wm:CreateControl("EAS_CodexInteractive_v193_"..name.."_"..index, parent, CT_BUTTON)
    row:SetAnchor(TOPLEFT, parent, TOPLEFT, 14, y)
    row:SetDimensions(self.pageW-28, 37)
    row:SetMouseEnabled(true)
    row:SetHandler("OnClicked", function() onClick(index) end)

    local title = makeLabel("EAS_CodexInteractiveTitle_v193_"..name.."_"..index, row, "", 4, 0, self.pageW-36, 18, "ZoFontGameBold")
    local detail = makeLabel("EAS_CodexInteractiveDetail_v193_"..name.."_"..index, row, "", 4, 17, self.pageW-36, 19, "ZoFontGame")
    local rule = wm:CreateControl("EAS_CodexInteractiveRule_v193_"..name.."_"..index, row, CT_BACKDROP)
    rule:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, 4, 0)
    rule:SetDimensions(self.pageW-38, 1)
    rule:SetCenterColor(0.26,0.17,0.08,0.18)
    rule:SetEdgeColor(0,0,0,0)

    row.titleLabel = title
    row.detailLabel = detail
    row.rule = rule
    row.rowIndex = index
    return row
end

-- Let the latest book creation build all pages, then move every global control onto parchment.
local easCreate_v193_base = CreateImplArch
CreateImplArch = function(self)
    easCreate_v193_base(self)

    -- The native book controls must be anchored to page hosts, not absolute window pixels.
    local footerY = -4
    if self.indexButton then
        self.indexButton:ClearAnchors()
        self.indexButton:SetAnchor(BOTTOMLEFT, self.leftPageHost, BOTTOMLEFT, 8, footerY)
        self.indexButton:SetDimensions(68, 24)
        self.indexButton:SetMouseEnabled(true)
        self.indexButton:SetDrawLayer(DL_OVERLAY)
        self.indexButton:SetDrawLevel(1000)
    end
    if self.prevPageButton then
        self.prevPageButton:ClearAnchors()
        self.prevPageButton:SetAnchor(BOTTOMRIGHT, self.leftPageHost, BOTTOMRIGHT, -8, footerY)
        self.prevPageButton:SetDimensions(76, 24)
        self.prevPageButton:SetText("< PREV")
    end
    if self.nextPageButton then
        self.nextPageButton:ClearAnchors()
        self.nextPageButton:SetAnchor(BOTTOMLEFT, self.rightPageHost, BOTTOMLEFT, 8, footerY)
        self.nextPageButton:SetDimensions(76, 24)
        self.nextPageButton:SetText("NEXT >")
    end
    if self.themeButton then
        self.themeButton:ClearAnchors()
        self.themeButton:SetAnchor(BOTTOMRIGHT, self.rightPageHost, BOTTOMRIGHT, -82, footerY)
        self.themeButton:SetDimensions(72, 24)
        self.themeButton:SetText("THEME")
    end
    if self.closeButton then
        self.closeButton:ClearAnchors()
        self.closeButton:SetAnchor(BOTTOMRIGHT, self.rightPageHost, BOTTOMRIGHT, -8, footerY)
        self.closeButton:SetDimensions(68, 24)
        self.closeButton:SetText("CLOSE")
    end

    -- The window-wide spread number was outside some native book media. Use the printed page numbers instead.
    if self.pageNumber then self.pageNumber:SetHidden(true) end
    if self.leftPageNumber then
        self.leftPageNumber:ClearAnchors()
        self.leftPageNumber:SetAnchor(BOTTOM, self.leftPageHost, BOTTOM, 0, -6)
    end
    if self.rightPageNumber then
        self.rightPageNumber:ClearAnchors()
        self.rightPageNumber:SetAnchor(BOTTOM, self.rightPageHost, BOTTOM, 0, -6)
    end

    -- One-time migration opens the clean index so users immediately see the corrected layout.
    local s = self:EnsureSaved()
    if s.readableBookControlsUpgrade ~= true then
        s.activeTab = "INDEX"
        s.readableBookControlsUpgrade = true
        self:SetTab("INDEX")
    end
end


--[[
    v0.19.4 editing / book-only / text-fit override
    - Makes both note fields and checkpoint names explicit focusable edit controls.
    - Keeps the legacy standalone window permanently hidden; Tamriel Codex is the main UI.
    - Gives Utilities a true two-page information layout so priorities/hints are not clipped.
    - Fits wrapped book text vertically using ESO label text measurements when available.
]]

local function easConfigureEditable(control, multiLine)
    if not control then return end
    control:SetMouseEnabled(true)
    if control.SetKeyboardEnabled then control:SetKeyboardEnabled(true) end
    if control.SetEditEnabled then control:SetEditEnabled(true) end
    if control.SetCopyEnabled then control:SetCopyEnabled(true) end
    if control.SetPasteEnabled then control:SetPasteEnabled(true) end
    if control.SetTextType and TEXT_TYPE_ALL then control:SetTextType(TEXT_TYPE_ALL) end
    if multiLine then
        if control.SetMultiLine then control:SetMultiLine(true) end
        if control.SetNewLineEnabled then control:SetNewLineEnabled(true) end
    end
    -- Explicit focus handling avoids cases where a bare CT_EDITBOX renders but does
    -- not begin receiving keyboard input when clicked inside the native book window.
    control:SetHandler("OnMouseUp", function(edit, button, upInside)
        if upInside ~= false and edit.TakeFocus then edit:TakeFocus() end
    end)
end

local easCreateEditBox_v194_base = CreateEditBoxImplArch
CreateEditBoxImplArch = function(self, name, parent, x, y, w, h, multiLine)
    local edit = easCreateEditBox_v194_base(self, name, parent, x, y, w, h, multiLine)
    easConfigureEditable(edit, multiLine == true)
    return edit
end

local function easSetBookTextFit(label, text, width)
    if not label then return end
    text = tostring(text or "")
    width = tonumber(width) or (label.GetWidth and label:GetWidth()) or 320
    local height = tonumber(label.GetHeight and label:GetHeight()) or 0
    if label.SetVerticalAlignment then label:SetVerticalAlignment(TEXT_ALIGN_TOP) end

    local fonts = {"ZoFontGame", "ZoFontGameSmall"}
    local chosen = fonts[1]
    local wrapped = ""
    for _,font in ipairs(fonts) do
        if label.SetFont then label:SetFont(font) end
        wrapped = wrapForBook(label, text, width)
        label:SetText(wrapped)
        chosen = font
        local textHeight = tonumber(label.GetTextHeight and label:GetTextHeight()) or 0
        if height <= 0 or textHeight <= height then break end
    end
    if chosen == "ZoFontGameSmall" and label.SetLineSpacing then label:SetLineSpacing(-1) end
    label:SetText(wrapped)
end

-- Make the shared book renderer use vertical fit as well as word wrapping.
setBookText = easSetBookTextFit

-- Utilities gets a deliberate two-page layout instead of a blind midpoint split.
local easRefreshSuitePage_v194_base = RefreshSuitePageImplArch
RefreshSuitePageImplArch = function(self, tab)
    tab = tab or self.activeTab
    if tab == "SKILLS" then
        local page = self.pages and self.pages.SKILLS
        if page and self.RefreshSkillsOrganized02716 then
            self:RefreshSkillsOrganized02716(page)
            self:ApplyTheme()
            return
        end
    end
    if tab == "TOOLS" and EPC.UtilitySuite then
        local page = self.pages and self.pages.TOOLS
        if page and page.leftBody and page.rightBody then
            local v = EPC.UtilitySuite:BuildView(EPC.lastSnapshot or {}) or {}
            local left = {}
            left[#left+1] = tostring(v.title or "Utilities")
            if v.description and v.description ~= "" then
                left[#left+1] = ""
                left[#left+1] = tostring(v.description)
            end
            if v.stats then
                left[#left+1] = ""
                addViewStats(left, v.stats)
            end

            local right = {}
            right[#right+1] = tostring(v.listHeader or ("MODE: " .. tostring(v.modeLabel or v.mode or "OVERVIEW")))
            right[#right+1] = ""
            local rows = v.rows or v.items or {}
            if #rows == 0 then
                right[#right+1] = "No utility priorities are available yet."
            else
                for i,row in ipairs(rows) do
                    local text = type(row) == "table" and (row.text or row.label or row.name or row.value) or row
                    right[#right+1] = string.format("%d. %s", i, tostring(text or ""))
                    if type(row) == "table" and row.detailText then right[#right+1] = "   " .. tostring(row.detailText) end
                end
            end
            if v.hint and v.hint ~= "" then
                right[#right+1] = ""
                right[#right+1] = "NOTE"
                right[#right+1] = tostring(v.hint)
            end

            easSetBookTextFit(page.leftBody, table.concat(left, "\n"), page.leftBody:GetWidth())
            easSetBookTextFit(page.rightBody, table.concat(right, "\n"), page.rightBody:GetWidth())
            if EPC.UtilitySuite:GetMode() == "RETICLE" then
                self:SetSuiteButtons("TOOLS", {"MODE","ON / OFF","STYLE","COLOR","SIZE -","SIZE +","OPACITY -","OPACITY +"})
            else
                self:SetSuiteButtons("TOOLS", {"MODE"})
            end
            return
        end
    end
    return easRefreshSuitePage_v194_base(self, tab)
end

local easCreate_v194_base = CreateImplArch
CreateImplArch = function(self)
    easCreate_v194_base(self)

    -- v6: Install raw keyboard capture for the single toggle key on the FINAL active Codex window.
    -- Earlier J:Create implementations are superseded later in this file, so the
    -- handler must be attached here after the complete book has been constructed.
    if self.window then
        if self.window.SetKeyboardEnabled then
            self.window:SetKeyboardEnabled(true)
        end
        self.window:SetHandler("OnKeyDown", function(_, key, ctrl, alt, shift, command)
            if not self.window or self.window:IsHidden() then return end
            if self:RawKeyMatchesAction("ESO_PROGRESSION_COACH_TOGGLE", key, ctrl, alt, shift, command) then
                self:Hide()
            end
        end)
    end

    -- One-time migration: open Notes in edit mode so both title and body are ready to type.
    local s = self:EnsureSaved()
    if s.fullNoteEditingUpgrade ~= true then
        s.readMode = false
        s.fullNoteEditingUpgrade = true
    end
    self.readMode = s.readMode == true

    easConfigureEditable(self.noteTitleEdit, false)
    easConfigureEditable(self.noteBodyEdit, true)
    easConfigureEditable(self.checkpointNameEdit, false)
    self:SetEditorEnabled(not self.readMode)

    -- Keep the obsolete menu window inaccessible even if an older saved variable says enabled.
    if EPC.UI and EPC.UI.root then EPC.UI.root:SetHidden(true) end
end

-- ============================================================================
-- v0.24.78 - Advanced glass/Glass-style Codex shell
-- Replaces the lore-book presentation while preserving all existing Codex data
-- pages and actions. The top-level window is movable/resizable and remembers
-- its size/position. Internal content scales as one workspace when resized.
-- ============================================================================

local EAS_GLASS_BASE_W = 1180
local EAS_GLASS_BASE_H = 760
local EAS_GLASS_MIN_W = 620
local EAS_GLASS_MIN_H = 400
local EAS_GLASS_MAX_W = 1680
local EAS_GLASS_MAX_H = 1080

local function easGlassBackdrop(name, parent, left, top, right, bottom, centerAlpha, edgeAlpha)
    local p = wm:CreateControl(name, parent, CT_BACKDROP)
    if left ~= nil then
        p:SetAnchor(TOPLEFT, parent, TOPLEFT, left, top)
        p:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, right, bottom)
    else
        p:SetAnchorFill(parent)
    end
    p:SetEdgeTexture(nil, 1, 1, 1)
    p:SetCenterColor(0.025, 0.032, 0.045, centerAlpha or 0.70)
    p:SetEdgeColor(0.32, 0.39, 0.50, edgeAlpha or 0.55)
    return p
end

function J:UpdateGlassScale()
    if not self.window or not self.glassCanvas then return end
    local w, h = self.window:GetDimensions()
    w, h = tonumber(w) or EAS_GLASS_BASE_W, tonumber(h) or EAS_GLASS_BASE_H
    local scale = math.min(w / EAS_GLASS_BASE_W, h / EAS_GLASS_BASE_H)
    scale = math.max(0.52, math.min(1.35, scale))
    self.glassCanvas:SetScale(scale)
    self.glassCanvas:ClearAnchors()
    self.glassCanvas:SetAnchor(CENTER, self.window, CENTER, 0, 0)
end

local easLegacyApplyTheme_2478 = ApplyThemeImplArch
ApplyThemeImplArch = function(self)
    if not self.glassMode then
        return easLegacyApplyTheme_2478(self)
    end
    if not self.window then return end

    local t = self:GetTheme()
    local accent = t.accent or {0.43, 0.68, 0.96, 1}
    local text = {0.92, 0.95, 0.99, 1}
    local muted = {0.58, 0.64, 0.73, 1}

    if self.bg then
        self.bg:SetCenterColor(0.020, 0.026, 0.038, 0.72)
        self.bg:SetEdgeColor(accent[1], accent[2], accent[3], 0.62)
    end
    if self.glassTopBar then
        self.glassTopBar:SetCenterColor(0.030, 0.038, 0.052, 0.82)
        self.glassTopBar:SetEdgeColor(0.25, 0.31, 0.40, 0.55)
    end
    if self.glassSidebar then
        self.glassSidebar:SetCenterColor(0.025, 0.032, 0.046, 0.76)
        self.glassSidebar:SetEdgeColor(0.22, 0.28, 0.36, 0.48)
    end
    if self.glassLeftCard then
        self.glassLeftCard:SetCenterColor(0.040, 0.050, 0.068, 0.68)
        self.glassLeftCard:SetEdgeColor(0.28, 0.34, 0.43, 0.58)
    end
    if self.glassRightCard then
        self.glassRightCard:SetCenterColor(0.040, 0.050, 0.068, 0.68)
        self.glassRightCard:SetEdgeColor(0.28, 0.34, 0.43, 0.58)
    end
    if self.glassAccent then
        self.glassAccent:SetCenterColor(accent[1], accent[2], accent[3], 0.95)
        self.glassAccent:SetEdgeColor(0,0,0,0)
    end
    if self.glassBrand then self.glassBrand:SetColor(text[1], text[2], text[3], 1) end
    if self.glassSubtitle then self.glassSubtitle:SetColor(muted[1], muted[2], muted[3], 1) end
    if self.glassResizeHint then self.glassResizeHint:SetColor(muted[1], muted[2], muted[3], 0.95) end

    for _, l in pairs(self.themeLabels or {}) do
        if l and l.SetColor then l:SetColor(text[1], text[2], text[3], 1) end
    end
    if self.noteTitleEdit then self.noteTitleEdit:SetColor(text[1],text[2],text[3],1) end
    if self.noteBodyEdit then self.noteBodyEdit:SetColor(text[1],text[2],text[3],1) end
    if self.checkpointNameEdit then self.checkpointNameEdit:SetColor(text[1],text[2],text[3],1) end

    for name, b in pairs(self.tabButtons or {}) do
        if b and b.SetNormalFontColor then
            local selected = name == self.activeTab
            if selected then b:SetNormalFontColor(accent[1],accent[2],accent[3],1)
            else b:SetNormalFontColor(text[1],text[2],text[3],0.88) end
            b:SetMouseOverFontColor(1,1,1,1)
            b:SetPressedFontColor(accent[1],accent[2],accent[3],1)
        end
        if b and b.glassBg then
            if name == self.activeTab then
                b.glassBg:SetCenterColor(accent[1],accent[2],accent[3],0.16)
                b.glassBg:SetEdgeColor(0.24,0.36,0.54,0.94)
                if b.glassRail then b.glassRail:SetColor(accent[1],accent[2],accent[3],1) end
            else
                b.glassBg:SetCenterColor(0.05,0.06,0.08,0.16)
                b.glassBg:SetEdgeColor(0.24,0.36,0.54,0.78)
                if b.glassRail then b.glassRail:SetColor(0,0,0,0) end
            end
        end
    end
    for name, b in pairs(self.categoryButtons or {}) do setButtonStyle(b, name == self.category, {text=text, accent=accent}) end
    for mode, b in pairs(self.codexButtons or {}) do setButtonStyle(b, mode == (self.codexMode or "ALCHEMY"), {text=text, accent=accent}) end
    for _, b in ipairs(self.topButtons or {}) do setButtonStyle(b, false, {text=text, accent=accent}) end
    for _, b in ipairs(self.iconButtons or {}) do styleIconButton(b, {page={0.08,0.10,0.13,1}, edge=accent, text=text}) end
    if self.modeButton then setButtonStyle(self.modeButton, self.readMode ~= true, {text=text, accent=accent}) end
    if self.themeButton then setButtonStyle(self.themeButton, false, {text=text, accent=accent}) end
    if self.closeButton then setButtonStyle(self.closeButton, false, {text=text, accent=accent}) end
    if self.prevPageButton then setButtonStyle(self.prevPageButton, false, {text=text, accent=accent}) end
    if self.nextPageButton then setButtonStyle(self.nextPageButton, false, {text=text, accent=accent}) end
    if self.diceResultPanel then
        self.diceResultPanel:SetCenterColor(0.05,0.065,0.09,0.62)
        self.diceResultPanel:SetEdgeColor(accent[1],accent[2],accent[3],0.45)
    end
    if self.diceResultValue then self.diceResultValue:SetColor(accent[1],accent[2],accent[3],1) end
end

local easLegacyCreateSpreadShell_2478 = CreateSpreadShellImplArch
CreateSpreadShellImplArch = function(self, name)
    if not self.glassMode then return easLegacyCreateSpreadShell_2478(self, name) end
    local parent = self.glassWorkspace or self.window
    local spread = wm:CreateControl("EAS_CodexSpread_"..name, parent, CT_CONTROL)
    spread:SetAnchorFill(parent)

    local left = wm:CreateControl("EAS_CodexSpread_"..name.."_Left", spread, CT_CONTROL)
    left:SetAnchor(TOPLEFT, self.leftPageHost, TOPLEFT, 0, 0)
    left:SetDimensions(self.pageW, self.pageH)

    local right = wm:CreateControl("EAS_CodexSpread_"..name.."_Right", spread, CT_CONTROL)
    right:SetAnchor(TOPLEFT, self.rightPageHost, TOPLEFT, 0, 0)
    right:SetDimensions(self.pageW, self.pageH)

    spread.left, spread.right = left, right
    spread.key = name
    return spread
end

CreateImplArch = function(self)
    self.glassMode = true
    local s = self:EnsureSaved()
    if s.glassGlassUpgrade ~= true then
        s.theme = "MIDNIGHT"
        s.activeTab = s.activeTab or "INDEX"
        s.glassGlassUpgrade = true
    end

    local window = wm:CreateTopLevelWindow("EAS_CustomJournal")
    self.window = window
    local savedW = math.max(EAS_GLASS_MIN_W, math.min(EAS_GLASS_MAX_W, tonumber(s.glassWidth) or EAS_GLASS_BASE_W))
    local savedH = math.max(EAS_GLASS_MIN_H, math.min(EAS_GLASS_MAX_H, tonumber(s.glassHeight) or EAS_GLASS_BASE_H))
    window:SetDimensions(savedW, savedH)
    window:SetDimensionConstraints(EAS_GLASS_MIN_W, EAS_GLASS_MIN_H, EAS_GLASS_MAX_W, EAS_GLASS_MAX_H)
    window:SetResizeHandleSize(24)
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, -8)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:SetMouseEnabled(true)
    window:SetHidden(true)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetDrawTier(DT_HIGH)

    if tonumber(s.left) and tonumber(s.top) and s.left >= 0 and s.top >= 0 then
        window:ClearAnchors()
        window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, s.left, s.top)
    end

    local canvas = wm:CreateControl("EAS_GlassCanvas", window, CT_CONTROL)
    canvas:SetDimensions(EAS_GLASS_BASE_W, EAS_GLASS_BASE_H)
    canvas:SetAnchor(CENTER, window, CENTER, 0, 0)
    self.glassCanvas = canvas

    local bg = easGlassBackdrop("EAS_CustomJournal_BG", canvas, nil, nil, nil, nil, 0.72, 0.62)
    self.bg = bg
    self.nativeBook = nil
    self.bookTexture = nil

    local topBar = wm:CreateControl("EAS_GlassTopBar", canvas, CT_BACKDROP)
    topBar:SetAnchor(TOPLEFT, canvas, TOPLEFT, 0, 0)
    topBar:SetAnchor(TOPRIGHT, canvas, TOPRIGHT, 0, 0)
    topBar:SetHeight(64)
    topBar:SetEdgeTexture(nil, 1, 1, 1)
    self.glassTopBar = topBar

    local accent = wm:CreateControl("EAS_GlassAccent", canvas, CT_BACKDROP)
    accent:SetAnchor(TOPLEFT, canvas, TOPLEFT, 0, 0)
    accent:SetDimensions(4, EAS_GLASS_BASE_H)
    accent:SetEdgeTexture(nil, 1, 1, 1)
    self.glassAccent = accent

    local brand = makeLabel("EAS_GlassBrand", canvas, "ESO ADVENTURER SUITE", 24, 12, 320, 24, "ZoFontWinH2")
    brand:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    local subtitle = makeLabel("EAS_GlassSubtitle", canvas, "COMMAND CENTER  /  TAMRIEL WORKSPACE", 25, 37, 360, 18, "ZoFontGameSmall")
    self.glassBrand, self.glassSubtitle = brand, subtitle

    local sidebar = wm:CreateControl("EAS_GlassSidebar", canvas, CT_BACKDROP)
    sidebar:SetAnchor(TOPLEFT, canvas, TOPLEFT, 12, 76)
    sidebar:SetDimensions(206, 664)
    sidebar:SetEdgeTexture(nil, 1, 1, 1)
    self.glassSidebar = sidebar

    local sideTitle = makeLabel("EAS_GlassSideTitle", sidebar, "WORKSPACE", 16, 12, 174, 20, "ZoFontGameBold")
    sideTitle:SetColor(0.62,0.68,0.78,1)

    self.panels, self.themeLabels, self.tabButtons, self.pages, self.topButtons = {}, {}, {}, {}, {}
    self.categoryButtons = {}

    local function addNav(key, label, y)
        local b = wm:CreateControl("EAS_GlassNav_"..key, sidebar, CT_BUTTON)
        b:SetAnchor(TOPLEFT, sidebar, TOPLEFT, 10, y)
        b:SetDimensions(186, 28)
        b:SetFont("ZoFontGame")
        if b.SetHorizontalAlignment then b:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
        if b.SetVerticalAlignment then b:SetVerticalAlignment(TEXT_ALIGN_CENTER) end
        b:SetText(tostring(label or key))
        b:SetHandler("OnClicked", function() self:SetTab(key) end)
        local nb = wm:CreateControl("EAS_GlassNavBG_"..key, b, CT_BACKDROP)
        nb:SetAnchor(TOPLEFT, b, TOPLEFT, 1, 1)
        nb:SetAnchor(BOTTOMRIGHT, b, BOTTOMRIGHT, -1, -1)
        nb:SetEdgeTexture(nil, 1, 1, 1)
        nb:SetDrawLevel(0)
        b.glassBg = nb
        local rail = wm:CreateControl("EAS_GlassNavRail_"..key, b, CT_TEXTURE)
        rail:SetAnchor(LEFT, b, LEFT, 4, 0)
        rail:SetDimensions(3, 19)
        b.glassRail = rail
        self.tabButtons[key] = b
        return b
    end

    addNav("INDEX", "Dashboard", 40)
    local navY = 70
    local navIndex = 0
    for _, tab in ipairs(TABS) do
        if tab ~= "INDEX" then
            navIndex = navIndex + 1
            addNav(tab, TAB_LABELS[tab] or tab, navY + (navIndex-1)*32)
        end
    end

    local workspace = wm:CreateControl("EAS_GlassWorkspace", canvas, CT_CONTROL)
    workspace:SetAnchor(TOPLEFT, canvas, TOPLEFT, 232, 76)
    workspace:SetDimensions(932, 664)
    self.glassWorkspace = workspace

    local leftCard = easGlassBackdrop("EAS_GlassLeftCard", workspace, 0, 0, -474, -8, 0.68, 0.58)
    local rightCard = easGlassBackdrop("EAS_GlassRightCard", workspace, 474, 0, -8, -8, 0.68, 0.58)
    self.glassLeftCard, self.glassRightCard = leftCard, rightCard

    local pageW, pageH = 430, 610
    self.pageW, self.pageH = pageW, pageH
    local leftHost = wm:CreateControl("EAS_CodexLeftPageHost", workspace, CT_CONTROL)
    leftHost:SetAnchor(TOPLEFT, workspace, TOPLEFT, 14, 18)
    leftHost:SetDimensions(pageW, pageH)
    self.leftPageHost = leftHost
    self.leftNavigation = leftHost

    local rightHost = wm:CreateControl("EAS_CodexRightPageHost", workspace, CT_CONTROL)
    rightHost:SetAnchor(TOPLEFT, workspace, TOPLEFT, 488, 18)
    rightHost:SetDimensions(pageW, pageH)
    self.rightPageHost = rightHost
    self.rightContent = rightHost

    local navPrev = makeButton("EAS_GlassPrev", canvas, "<", 946, 17, 38, 30, function() self:TurnPage(-1) end)
    local navNext = makeButton("EAS_GlassNext", canvas, ">", 990, 17, 38, 30, function() self:TurnPage(1) end)
    local theme = makeButton("EAS_CodexTheme", canvas, "ACCENT", 1036, 17, 68, 30, function() self:CycleTheme() end)
    local close = makeButton("EAS_CodexClose", canvas, "X", 1112, 17, 40, 30, function() self:Hide() end)
    self.prevPageButton, self.nextPageButton = navPrev, navNext
    self.themeButton, self.closeButton = theme, close
    self.topButtons[#self.topButtons+1] = navPrev
    self.topButtons[#self.topButtons+1] = navNext
    self.topButtons[#self.topButtons+1] = theme
    self.topButtons[#self.topButtons+1] = close

    self.pages.INDEX = self:CreateIndexSpread()
    self.pages.NOTES = self:CreateNotesSpread()
    self.pages.PINS = self:CreatePinsSpread()
    self.pages.BUILD = self:CreateSuiteSpread("BUILD")
    self.pages.GEAR = self:CreateSuiteSpread("GEAR")
    self.pages.SKILLS = self:CreateSuiteSpread("SKILLS")
    self.pages.COMBAT = self:CreateSuiteSpread("COMBAT")
    self.pages.ACTIVITY = self:CreateSuiteSpread("ACTIVITY")
    self.pages.DUNGEONS = self:CreateSuiteSpread("DUNGEONS")
    self.pages.BATTLEGROUNDS = self:CreateSuiteSpread("BATTLEGROUNDS")
    self.pages.GROUPFINDER = self:CreateSuiteSpread("GROUPFINDER")
    self.pages.QUESTS = self:CreateSuiteSpread("QUESTS")
    self.pages.TRAVEL = self:CreateSuiteSpread("TRAVEL")
    self.pages.TOOLS = self:CreateSuiteSpread("TOOLS")
    self.pages.ACHIEVEMENTS = self:CreateDocumentSpread("ACHIEVEMENTS")
    self.pages.STATS = self:CreateDocumentSpread("STATS")
    self.pages.CODEX = self:CreateCodexSpread()
    self.pages.DICE = self:CreateDiceSpread()
    self.suiteRowIndex = { GEAR=0, QUESTS=0, TRAVEL=0, ACTIVITY=0, DUNGEONS=0, BATTLEGROUNDS=0, GROUPFINDER=0 }

    local spreadNo = makeLabel("EAS_CodexSpreadNumber", canvas, "", 852, 22, 86, 22, "ZoFontGameSmall")
    spreadNo:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.pageNumber = spreadNo
    self.themeLabels[#self.themeLabels+1] = spreadNo

    local leftNum = makeLabel("EAS_CodexLeftPageNumber", leftHost, "", math.floor((pageW-40)/2), pageH-20, 40, 18, "ZoFontGameSmall")
    leftNum:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    local rightNum = makeLabel("EAS_CodexRightPageNumber", rightHost, "", math.floor((pageW-40)/2), pageH-20, 40, 18, "ZoFontGameSmall")
    rightNum:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.leftPageNumber, self.rightPageNumber = leftNum, rightNum
    self.themeLabels[#self.themeLabels+1] = leftNum
    self.themeLabels[#self.themeLabels+1] = rightNum

    local flip = wm:CreateControl("EAS_CustomJournal_FlipPage", workspace, CT_BACKDROP)
    flip:SetDimensions(pageW, pageH-60)
    flip:SetAnchor(TOPLEFT, rightHost, TOPLEFT, 0, 44)
    flip:SetEdgeTexture(nil, 1, 1, 1)
    flip:SetDrawLayer(DL_OVERLAY)
    flip:SetCenterColor(0.04,0.05,0.07,0.92)
    flip:SetHidden(true)
    self.flipPage = flip
    local flipMark = makeLabel("EAS_CodexFlipMark", flip, "ESO ADVENTURER SUITE", 18, math.floor((pageH-110)/2), pageW-36, 30, "ZoFontWinH2")
    flipMark:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.themeLabels[#self.themeLabels+1] = flipMark

    local resizeHint = makeLabel("EAS_GlassResizeHint", canvas, "DRAG WINDOW  /  RESIZE FROM EDGES", 816, 734, 330, 18, "ZoFontGameSmall")
    resizeHint:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.glassResizeHint = resizeHint

    window:SetHandler("OnMoveStop", function(control)
        local sv = self:EnsureSaved()
        sv.left, sv.top = control:GetLeft(), control:GetTop()
    end)
    window:SetHandler("OnResizeStop", function(control)
        local sv = self:EnsureSaved()
        local w, h = control:GetDimensions()
        sv.glassWidth = math.floor((tonumber(w) or EAS_GLASS_BASE_W) + 0.5)
        sv.glassHeight = math.floor((tonumber(h) or EAS_GLASS_BASE_H) + 0.5)
        self:UpdateGlassScale()
    end)

    self.category = s.category or "ALL"
    self.activeTab = s.activeTab or "INDEX"
    self.readMode = s.readMode == true
    self.codexMode = "ALCHEMY"
    self:SetEditorEnabled(not self.readMode)
    self:SetTab(self.activeTab)
    self:RegisterMapPins()

    -- Preserve the final Codex keyboard-close and editable-field behavior from
    -- the previous shell while using the new glass workspace.
    if self.window.SetKeyboardEnabled then self.window:SetKeyboardEnabled(true) end
    self.window:SetHandler("OnKeyDown", function(_, key, ctrl, alt, shift, command)
        if not self.window or self.window:IsHidden() then return end
        if self:RawKeyMatchesAction("ESO_PROGRESSION_COACH_TOGGLE", key, ctrl, alt, shift, command) then
            self:Hide()
        end
    end)
    easConfigureEditable(self.noteTitleEdit, false)
    easConfigureEditable(self.noteBodyEdit, true)
    easConfigureEditable(self.checkpointNameEdit, false)
    self:SetEditorEnabled(not self.readMode)
    if EPC.UI and EPC.UI.root then EPC.UI.root:SetHidden(true) end

    self:UpdateGlassScale()
    self:ApplyTheme()
end


-- ============================================================================
-- v0.24.79 - Premium Glass polish pass
-- Pushes the glass Codex closer to a modern design-tool dashboard with
-- sharper button chrome, floating toolbars, sidebar hero card, section chips,
-- and stronger visual hierarchy while preserving existing behavior.
-- ============================================================================

local easLegacySetButtonStyle_2479 = setButtonStyle
local function easEnsurePremiumButtonSkin(button)
    if not button or button.easPremiumSkin then return end
    local bg = wm:CreateControl((button:GetName() or tostring(button)).."_PremiumBG", button, CT_BACKDROP)
    bg:SetAnchorFill(button)
    bg:SetEdgeTexture(nil, 1, 1, 1)
    bg:SetDrawLevel(0)
    local glow = wm:CreateControl((button:GetName() or tostring(button)).."_PremiumGlow", button, CT_BACKDROP)
    glow:SetAnchor(TOPLEFT, button, TOPLEFT, -1, -1)
    glow:SetAnchor(BOTTOMRIGHT, button, BOTTOMRIGHT, 1, 1)
    glow:SetEdgeTexture(nil, 1, 1, 1)
    glow:SetDrawLevel(0)
    glow:SetDrawTier(DT_HIGH)
    button.easPremiumSkin = {bg=bg, glow=glow}
end

setButtonStyle = function(button, selected, theme)
    easLegacySetButtonStyle_2479(button, selected, theme)
    if not button then return end
    local t = theme or THEMES.MIDNIGHT
    easEnsurePremiumButtonSkin(button)
    if button.easPremiumSkin then
        local bg, glow = button.easPremiumSkin.bg, button.easPremiumSkin.glow
        local a = t.accent or {0.43, 0.68, 0.96, 1}
        if selected then
            bg:SetCenterColor(a[1], a[2], a[3], 0.18)
            bg:SetEdgeColor(a[1], a[2], a[3], 0.58)
            glow:SetCenterColor(a[1], a[2], a[3], 0.02)
            glow:SetEdgeColor(a[1], a[2], a[3], 0.32)
        else
            bg:SetCenterColor(0.055, 0.065, 0.085, 0.36)
            bg:SetEdgeColor(0.19, 0.24, 0.31, 0.26)
            glow:SetCenterColor(0,0,0,0)
            glow:SetEdgeColor(0.10, 0.12, 0.16, 0.06)
        end
    end
end

local easLegacyStyleIconButton_2479 = styleIconButton
styleIconButton = function(button, theme)
    easLegacyStyleIconButton_2479(button, theme)
    if not button then return end
    local t = theme or THEMES.MIDNIGHT or {}
    -- Some legacy Codex callers pass a lightweight theme table containing
    -- page/edge/text but no accent. Premium styling must support both forms.
    local accent = t.accent or t.edge or (THEMES.MIDNIGHT and THEMES.MIDNIGHT.accent) or {0.43, 0.68, 0.96, 1}
    local ar = tonumber(accent[1]) or 0.43
    local ag = tonumber(accent[2]) or 0.68
    local ab = tonumber(accent[3]) or 0.96
    if button.bg then
        button.bg:SetCenterColor(0.060, 0.075, 0.098, 0.48)
        button.bg:SetEdgeColor(ar, ag, ab, 0.34)
    end
    if not button.easPremiumIconGlow then
        local glow = wm:CreateControl((button:GetName() or tostring(button)).."_IconGlow", button, CT_BACKDROP)
        glow:SetAnchor(TOPLEFT, button, TOPLEFT, -1, -1)
        glow:SetAnchor(BOTTOMRIGHT, button, BOTTOMRIGHT, 1, 1)
        glow:SetEdgeTexture(nil, 1, 1, 1)
        glow:SetDrawLevel(0)
        button.easPremiumIconGlow = glow
    end
    if button.easPremiumIconGlow then
        button.easPremiumIconGlow:SetCenterColor(0,0,0,0)
        button.easPremiumIconGlow:SetEdgeColor(ar, ag, ab, 0.16)
    end
end

function J:EnhanceGlassPremiumVisuals()
    if not self.glassMode or not self.window or self.glassPremium2479 then return end
    self.glassPremium2479 = true

    local orderedTabs = {"INDEX"}
    for _, tab in ipairs(TABS) do
        if tab ~= "INDEX" then orderedTabs[#orderedTabs+1] = tab end
    end

    if self.glassSidebar then
        local hero = wm:CreateControl("EAS_GlassHeroCard", self.glassSidebar, CT_BACKDROP)
        hero:SetAnchor(TOPLEFT, self.glassSidebar, TOPLEFT, 10, 38)
        hero:SetDimensions(186, 92)
        hero:SetEdgeTexture(nil, 1, 1, 1)
        self.glassHeroCard = hero

        local heroStripe = wm:CreateControl("EAS_GlassHeroStripe", hero, CT_BACKDROP)
        heroStripe:SetAnchor(TOPLEFT, hero, TOPLEFT, 0, 0)
        heroStripe:SetDimensions(186, 4)
        heroStripe:SetEdgeTexture(nil, 1, 1, 1)
        self.glassHeroStripe = heroStripe

        local heroLabel = makeLabel("EAS_GlassHeroLabel", hero, "TACTICAL DASHBOARD", 14, 12, 158, 18, "ZoFontGameBold")
        local heroSub = makeLabel("EAS_GlassHeroSub", hero, "Glass workspace for builds, sets, dungeons, travel and combat tools.", 14, 34, 158, 36, "ZoFontGameSmall")
        heroSub:SetVerticalAlignment(TEXT_ALIGN_TOP)
        self.glassHeroLabel, self.glassHeroSub = heroLabel, heroSub
        table.insert(self.themeLabels, heroLabel)
        table.insert(self.themeLabels, heroSub)

        local chip1 = wm:CreateControl("EAS_GlassHeroChip1", hero, CT_BACKDROP)
        chip1:SetAnchor(TOPLEFT, hero, TOPLEFT, 14, 70)
        chip1:SetDimensions(56, 16)
        chip1:SetEdgeTexture(nil, 1, 1, 1)
        local chip1Text = makeLabel("EAS_GlassHeroChipText1", hero, "LIVE", 14, 70, 56, 16, "ZoFontGameSmall")
        chip1Text:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        local chip2 = wm:CreateControl("EAS_GlassHeroChip2", hero, CT_BACKDROP)
        chip2:SetAnchor(TOPLEFT, hero, TOPLEFT, 78, 70)
        chip2:SetDimensions(92, 16)
        chip2:SetEdgeTexture(nil, 1, 1, 1)
        local chip2Text = makeLabel("EAS_GlassHeroChipText2", hero, "SCALABLE UI", 78, 70, 92, 16, "ZoFontGameSmall")
        chip2Text:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        self.glassHeroChip1, self.glassHeroChip2 = chip1, chip2
        table.insert(self.themeLabels, chip1Text)
        table.insert(self.themeLabels, chip2Text)

        if self.glassSideTitle then self.glassSideTitle:ClearAnchors(); self.glassSideTitle:SetAnchor(TOPLEFT, self.glassSidebar, TOPLEFT, 16, 12) end
        for index, key in ipairs(orderedTabs) do
            local b = self.tabButtons and self.tabButtons[key]
            if b then
                b:ClearAnchors()
                b:SetAnchor(TOPLEFT, self.glassSidebar, TOPLEFT, 10, 142 + ((index - 1) * 31))
                b:SetDimensions(186, 27)
                if not b.glassIconBadge then
                    local badge = wm:CreateControl((b:GetName() or key).."_Badge", b, CT_BACKDROP)
                    badge:SetAnchor(LEFT, b, LEFT, 8, 0)
                    badge:SetDimensions(18, 18)
                    badge:SetEdgeTexture(nil, 1, 1, 1)
                    b.glassIconBadge = badge
                    local iconText = makeLabel((b:GetName() or key).."_BadgeText", b, string.sub(tostring(TAB_LABELS[key] or key),1,1), 8, 4, 18, 12, "ZoFontGameSmall")
                    iconText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
                    b.glassIconText = iconText
                    table.insert(self.themeLabels, iconText)
                end
            end
        end
    end

    if self.glassTopBar then
        local toolbar = wm:CreateControl("EAS_GlassFloatingToolbar", self.glassCanvas, CT_BACKDROP)
        toolbar:SetAnchor(TOPRIGHT, self.glassCanvas, TOPRIGHT, -14, 11)
        toolbar:SetDimensions(216, 42)
        toolbar:SetEdgeTexture(nil, 1, 1, 1)
        self.glassFloatingToolbar = toolbar
        if self.prevPageButton then self.prevPageButton:SetDrawTier(DT_HIGH) end
        if self.nextPageButton then self.nextPageButton:SetDrawTier(DT_HIGH) end
        if self.themeButton then self.themeButton:SetDrawTier(DT_HIGH) end
        if self.closeButton then self.closeButton:SetDrawTier(DT_HIGH) end

        local searchShell = wm:CreateControl("EAS_GlassSearchShell", self.glassCanvas, CT_BACKDROP)
        searchShell:SetAnchor(TOPLEFT, self.glassCanvas, TOPLEFT, 410, 14)
        searchShell:SetDimensions(302, 36)
        searchShell:SetEdgeTexture(nil, 1, 1, 1)
        self.glassSearchShell = searchShell
        local searchIcon = makeLabel("EAS_GlassSearchIcon", self.glassCanvas, "Q", 422, 22, 12, 12, "ZoFontGameBold")
        local searchText = makeLabel("EAS_GlassSearchText", self.glassCanvas, "Quick view: builds, sets, quests, dungeons", 444, 20, 248, 16, "ZoFontGameSmall")
        self.glassSearchIcon, self.glassSearchText = searchIcon, searchText
        table.insert(self.themeLabels, searchIcon)
        table.insert(self.themeLabels, searchText)
    end

    if self.leftPageHost and self.rightPageHost then
        self.leftPageHost:ClearAnchors()
        self.leftPageHost:SetAnchor(TOPLEFT, self.glassWorkspace, TOPLEFT, 14, 44)
        self.rightPageHost:ClearAnchors()
        self.rightPageHost:SetAnchor(TOPLEFT, self.glassWorkspace, TOPLEFT, 488, 44)

        local leftHeader = wm:CreateControl("EAS_GlassLeftHeader", self.glassWorkspace, CT_BACKDROP)
        leftHeader:SetAnchor(TOPLEFT, self.glassWorkspace, TOPLEFT, 14, 14)
        leftHeader:SetDimensions(430, 24)
        leftHeader:SetEdgeTexture(nil, 1, 1, 1)
        self.glassLeftHeader = leftHeader
        local leftHeaderText = makeLabel("EAS_GlassLeftHeaderText", self.glassWorkspace, "NAVIGATOR", 28, 19, 150, 16, "ZoFontGameBold")
        self.glassLeftHeaderText = leftHeaderText
        table.insert(self.themeLabels, leftHeaderText)

        local rightHeader = wm:CreateControl("EAS_GlassRightHeader", self.glassWorkspace, CT_BACKDROP)
        rightHeader:SetAnchor(TOPLEFT, self.glassWorkspace, TOPLEFT, 488, 14)
        rightHeader:SetDimensions(430, 24)
        rightHeader:SetEdgeTexture(nil, 1, 1, 1)
        self.glassRightHeader = rightHeader
        local rightHeaderText = makeLabel("EAS_GlassRightHeaderText", self.glassWorkspace, "DETAIL PANEL", 502, 19, 160, 16, "ZoFontGameBold")
        self.glassRightHeaderText = rightHeaderText
        table.insert(self.themeLabels, rightHeaderText)
    end

    local footer = wm:CreateControl("EAS_GlassFooterRail", self.glassCanvas, CT_BACKDROP)
    footer:SetAnchor(BOTTOMLEFT, self.glassCanvas, BOTTOMLEFT, 232, -6)
    footer:SetDimensions(932, 20)
    footer:SetEdgeTexture(nil, 1, 1, 1)
    self.glassFooterRail = footer
    local footerText = makeLabel("EAS_GlassFooterText", self.glassCanvas, "MOVE  /  RESIZE  /  REVIEW BUILDS  /  APPLY BUILDS  /  ROUTE CONTENT", 248, 739, 700, 14, "ZoFontGameSmall")
    table.insert(self.themeLabels, footerText)

    self:ApplyTheme()
end

local easLegacyApplyTheme_2479 = ApplyThemeImplArch
ApplyThemeImplArch = function(self)
    easLegacyApplyTheme_2479(self)
    if not self.glassMode then return end
    local t = self:GetTheme()
    local accent = t.accent or {0.43, 0.68, 0.96, 1}
    local text = t.text or {0.92, 0.95, 0.99, 1}
    local muted = {0.62, 0.70, 0.80, 1}

    if self.bg then self.bg:SetCenterColor(0.014, 0.018, 0.028, 0.76) self.bg:SetEdgeColor(accent[1], accent[2], accent[3], 0.40) end
    if self.glassTopBar then self.glassTopBar:SetCenterColor(0.024, 0.028, 0.040, 0.88) self.glassTopBar:SetEdgeColor(0.16, 0.20, 0.28, 0.48) end
    if self.glassSidebar then self.glassSidebar:SetCenterColor(0.020, 0.026, 0.038, 0.82) self.glassSidebar:SetEdgeColor(0.18, 0.24, 0.31, 0.46) end
    if self.glassLeftCard then self.glassLeftCard:SetCenterColor(0.042, 0.052, 0.070, 0.82) self.glassLeftCard:SetEdgeColor(0.24, 0.32, 0.40, 0.54) end
    if self.glassRightCard then self.glassRightCard:SetCenterColor(0.042, 0.052, 0.070, 0.82) self.glassRightCard:SetEdgeColor(0.24, 0.32, 0.40, 0.54) end
    if self.glassAccent then self.glassAccent:SetCenterColor(accent[1], accent[2], accent[3], 1) self.glassAccent:SetEdgeColor(0,0,0,0) end
    if self.glassFloatingToolbar then self.glassFloatingToolbar:SetCenterColor(0.045, 0.055, 0.076, 0.90) self.glassFloatingToolbar:SetEdgeColor(accent[1], accent[2], accent[3], 0.28) end
    if self.glassSearchShell then self.glassSearchShell:SetCenterColor(0.032, 0.040, 0.056, 0.84) self.glassSearchShell:SetEdgeColor(0.17, 0.22, 0.30, 0.40) end
    if self.glassHeroCard then self.glassHeroCard:SetCenterColor(0.038, 0.046, 0.064, 0.88) self.glassHeroCard:SetEdgeColor(accent[1], accent[2], accent[3], 0.28) end
    if self.glassHeroStripe then self.glassHeroStripe:SetCenterColor(accent[1], accent[2], accent[3], 0.96) self.glassHeroStripe:SetEdgeColor(0,0,0,0) end
    if self.glassHeroChip1 then self.glassHeroChip1:SetCenterColor(accent[1], accent[2], accent[3], 0.20) self.glassHeroChip1:SetEdgeColor(accent[1], accent[2], accent[3], 0.36) end
    if self.glassHeroChip2 then self.glassHeroChip2:SetCenterColor(0.07, 0.09, 0.12, 0.62) self.glassHeroChip2:SetEdgeColor(0.20, 0.25, 0.34, 0.34) end
    if self.glassLeftHeader then self.glassLeftHeader:SetCenterColor(0.050, 0.060, 0.082, 0.72) self.glassLeftHeader:SetEdgeColor(0.20, 0.24, 0.31, 0.34) end
    if self.glassRightHeader then self.glassRightHeader:SetCenterColor(0.050, 0.060, 0.082, 0.72) self.glassRightHeader:SetEdgeColor(0.20, 0.24, 0.31, 0.34) end
    if self.glassFooterRail then self.glassFooterRail:SetCenterColor(0.028, 0.032, 0.048, 0.72) self.glassFooterRail:SetEdgeColor(0.16, 0.20, 0.28, 0.30) end
    if self.glassBrand then self.glassBrand:SetColor(text[1], text[2], text[3], 1) end
    if self.glassSubtitle then self.glassSubtitle:SetColor(muted[1], muted[2], muted[3], 1) end
    if self.glassHeroLabel then self.glassHeroLabel:SetColor(text[1], text[2], text[3], 1) end
    if self.glassHeroSub then self.glassHeroSub:SetColor(muted[1], muted[2], muted[3], 1) end
    if self.glassSearchIcon then self.glassSearchIcon:SetColor(accent[1], accent[2], accent[3], 1) end
    if self.glassSearchText then self.glassSearchText:SetColor(muted[1], muted[2], muted[3], 1) end

    if self.tabButtons then
        for key, b in pairs(self.tabButtons) do
            if b and b.glassIconBadge then
                local active = key == self.activeTab
                if active then
                    b.glassIconBadge:SetCenterColor(accent[1], accent[2], accent[3], 0.24)
                    b.glassIconBadge:SetEdgeColor(accent[1], accent[2], accent[3], 0.44)
                    if b.glassIconText then b.glassIconText:SetColor(accent[1], accent[2], accent[3], 1) end
                else
                    b.glassIconBadge:SetCenterColor(0.07, 0.09, 0.12, 0.62)
                    b.glassIconBadge:SetEdgeColor(0.18, 0.24, 0.31, 0.20)
                    if b.glassIconText then b.glassIconText:SetColor(text[1], text[2], text[3], 0.86) end
                end
            end
            setButtonStyle(b, key == self.activeTab, t)
        end
    end
    for _, b in ipairs(self.topButtons or {}) do setButtonStyle(b, false, t) end
    for _, b in ipairs(self.iconButtons or {}) do styleIconButton(b, t) end
    if EPC.GearLoadoutOverlay and type(EPC.GearLoadoutOverlay.ApplyTheme) == "function" then
        EPC.GearLoadoutOverlay:ApplyTheme()
    end
end

local easLegacyCreate_2479 = CreateImplArch
CreateImplArch = function(self)
    easLegacyCreate_2479(self)
    self:EnhanceGlassPremiumVisuals()
end


-- ============================================================================
-- v0.24.80 - Glass duplicate navigation control fix
-- INDEX is excluded from the dynamic TABS loop because an earlier compatibility
-- upgrade adds INDEX to TABS. This prevents EAS_GlassNav_INDEX from being
-- created twice during startup.
-- ============================================================================


-- ============================================================================
-- v0.24.82 - Clean Glass layout + full-border live resizing
-- Reduces decorative crowding, restores more usable workspace, and enlarges
-- the native resize hit area around all four sides/corners. The canvas scales
-- continuously while resizing so controls do not bunch together mid-drag.
-- ============================================================================

function J:ApplyGlassCleanLayout2482()
    if not self.glassMode or not self.window or self.glassClean2482 then return end
    self.glassClean2482 = true

    -- Keep the advanced glass shell, but remove decorative overlays that were
    -- competing with functional controls for space.
    local hideList = {
        self.glassHeroCard, self.glassHeroStripe, self.glassHeroChip1, self.glassHeroChip2,
        self.glassHeroLabel, self.glassHeroSub,
        self.glassSearchShell, self.glassSearchIcon, self.glassSearchText,
        self.glassLeftHeader, self.glassRightHeader,
        self.glassLeftHeaderText, self.glassRightHeaderText,
        self.glassFooterRail,
    }
    for _, control in ipairs(hideList) do
        if control and control.SetHidden then control:SetHidden(true) end
    end

    -- Give the two functional work panels the full vertical space again.
    if self.leftPageHost and self.glassWorkspace then
        self.leftPageHost:ClearAnchors()
        self.leftPageHost:SetAnchor(TOPLEFT, self.glassWorkspace, TOPLEFT, 14, 18)
    end
    if self.rightPageHost and self.glassWorkspace then
        self.rightPageHost:ClearAnchors()
        self.rightPageHost:SetAnchor(TOPLEFT, self.glassWorkspace, TOPLEFT, 488, 18)
    end

    -- Compact, evenly-spaced sidebar. INDEX appears only once.
    local orderedTabs = {"INDEX"}
    for _, key in ipairs(TABS) do
        if key ~= "INDEX" then orderedTabs[#orderedTabs+1] = key end
    end
    for index, key in ipairs(orderedTabs) do
        local b = self.tabButtons and self.tabButtons[key]
        if b and self.glassSidebar then
            b:ClearAnchors()
            b:SetAnchor(TOPLEFT, self.glassSidebar, TOPLEFT, 10, 40 + ((index - 1) * 35))
            b:SetDimensions(186, 30)
            b:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
            b:SetText("        " .. tostring(TAB_LABELS[key] or key))
        end
    end

    -- Larger native hit area: ESO applies this around all sides and corners
    -- of a resizable TopLevelControl.
    if self.window.SetResizeHandleSize then self.window:SetResizeHandleSize(48) end

    -- Only attach the per-frame resize callback while the user is actively
    -- resizing. Keeping OnUpdate detached the rest of the time avoids an
    -- unnecessary Lua callback every rendered frame.
    self.glassResizeActive2482 = false
    self.window:SetHandler("OnResizeStart", function(control)
        self.glassResizeActive2482 = true
        control:SetHandler("OnUpdate", function()
            if self.glassResizeActive2482 then self:UpdateGlassScale() end
        end)
    end)
    self.window:SetHandler("OnResizeStop", function(control)
        self.glassResizeActive2482 = false
        control:SetHandler("OnUpdate", nil)
        local sv = self:EnsureSaved()
        local w, h = control:GetDimensions()
        sv.glassWidth = math.floor((tonumber(w) or EAS_GLASS_BASE_W) + 0.5)
        sv.glassHeight = math.floor((tonumber(h) or EAS_GLASS_BASE_H) + 0.5)
        self:UpdateGlassScale()
    end)

    if self.glassResizeHint then
        self.glassResizeHint:SetText("RESIZE FROM ANY SIDE OR CORNER")
        self.glassResizeHint:ClearAnchors()
        self.glassResizeHint:SetAnchor(BOTTOMRIGHT, self.glassCanvas, BOTTOMRIGHT, -16, -8)
        self.glassResizeHint:SetDimensions(320, 18)
    end
end

local easLegacyCreate_2482 = CreateImplArch
CreateImplArch = function(self)
    easLegacyCreate_2482(self)
    self:ApplyGlassCleanLayout2482()
    self:ApplyTheme()
end


-- ============================================================================
-- v0.24.83 - Clean header/title collision fix
-- Decorative Glass column labels are hidden independently from their backdrop
-- controls so they cannot overlap real Codex section titles.
-- ============================================================================

function J:ApplyGlassHeaderCollisionFix2483()
    if not self.glassMode then return end
    local controls = {
        self.glassLeftHeader, self.glassRightHeader,
        self.glassLeftHeaderText, self.glassRightHeaderText,
    }
    for _, control in ipairs(controls) do
        if control and control.SetHidden then control:SetHidden(true) end
    end
end

local easLegacyCreate_2483 = CreateImplArch
CreateImplArch = function(self)
    easLegacyCreate_2483(self)
    self:ApplyGlassHeaderCollisionFix2483()
end


-- ============================================================================
-- v0.24.84 - Toolbar centering + clean workspace labels
-- Centers the top navigation/action controls inside their glass container and
-- removes the decorative single-letter workspace badges from the sidebar.
-- ============================================================================
function J:ApplyGlassToolbarAndNavCleanup2484()
    if not self.glassMode then return end

    if self.glassFloatingToolbar then
        self.glassFloatingToolbar:ClearAnchors()
        self.glassFloatingToolbar:SetAnchor(TOPRIGHT, self.glassCanvas, TOPRIGHT, -14, 11)
        self.glassFloatingToolbar:SetDimensions(220, 42)

        local controls = {
            {self.prevPageButton, 8, 6, 36, 30},
            {self.nextPageButton, 48, 6, 36, 30},
            {self.themeButton, 88, 6, 76, 30},
            {self.closeButton, 168, 6, 44, 30},
        }
        for _, data in ipairs(controls) do
            local c = data[1]
            if c then
                c:ClearAnchors()
                c:SetAnchor(TOPLEFT, self.glassFloatingToolbar, TOPLEFT, data[2], data[3])
                c:SetDimensions(data[4], data[5])
            end
        end
    end

    local orderedTabs = {"INDEX"}
    for _, key in ipairs(TABS) do if key ~= "INDEX" then orderedTabs[#orderedTabs+1] = key end end
    for _, key in ipairs(orderedTabs) do
        local b = self.tabButtons and self.tabButtons[key]
        if b then
            if b.glassIconBadge then b.glassIconBadge:SetHidden(true) end
            if b.glassIconText then b.glassIconText:SetHidden(true) end
            b:SetText("    " .. tostring(TAB_LABELS[key] or key))
        end
    end
end

local easLegacyCreate_2484 = CreateImplArch
CreateImplArch = function(self)
    easLegacyCreate_2484(self)
    self:ApplyGlassToolbarAndNavCleanup2484()
    self:ApplyTheme()
end


-- ============================================================================
-- v0.24.86 - Smaller Glass minimum size
-- The command-center can now shrink to roughly half-scale while preserving
-- the all-sides/all-corners resize behavior from the clean Glass shell.
-- ============================================================================


-- v0.24.89 - live Gear & Sets equipment overlay bridge
local easSetTab_2489 = SetTabImplArch
SetTabImplArch = function(self, tab)
    easSetTab_2489(self, tab)
    if EPC.GearLoadoutOverlay and EPC.GearLoadoutOverlay.OnGearTabChanged then
        EPC.GearLoadoutOverlay:OnGearTabChanged(self.activeTab == "GEAR")
    end
end

local easShow_2489 = ShowImplArch
ShowImplArch = function(self)
    easShow_2489(self)
    if EPC.GearLoadoutOverlay then
        if EPC.GearLoadoutOverlay.OnGearTabChanged then EPC.GearLoadoutOverlay:OnGearTabChanged(self.activeTab == "GEAR") end
        if EPC.GearLoadoutOverlay.SetJournalVisible then EPC.GearLoadoutOverlay:SetJournalVisible(true) end
    end
end

local easHide_2489 = HideImplArch
HideImplArch = function(self)
    if EPC.GearLoadoutOverlay and EPC.GearLoadoutOverlay.SetJournalVisible then
        EPC.GearLoadoutOverlay:SetJournalVisible(false)
    end
    easHide_2489(self)
end

-- ============================================================================
-- v0.24.92 - Clean expanded list rows
-- Keep the 10-row Codex lists, but remove secondary row metadata from the
-- selectable list itself. Full metadata remains in the selected-detail panel.
-- Shorter single-line rows leave a clearer gap between each selection.
-- ============================================================================
CreateBookRowImplArch = function(self, parent, name, index, y, onClick)
    local row = wm:CreateControl("EAS_CodexInteractive_v2492_"..name.."_"..index, parent, CT_BUTTON)
    row:SetAnchor(TOPLEFT, parent, TOPLEFT, 14, y)
    row:SetDimensions(self.pageW-28, 32)
    row:SetMouseEnabled(true)
    row:SetHandler("OnClicked", function() onClick(index) end)

    -- Selection rows are intentionally name-only. The right-hand Selected
    -- panel already contains source, status, collection, cost, zone, etc.
    local title = makeLabel("EAS_CodexInteractiveTitle_v2492_"..name.."_"..index, row, "", 6, 4, self.pageW-40, 23, "ZoFontGameBold")
    if title.SetVerticalAlignment then title:SetVerticalAlignment(TEXT_ALIGN_CENTER) end

    -- Keep a hidden compatibility label because the existing refresh paths
    -- still write secondary metadata to detailLabel.
    local detail = makeLabel("EAS_CodexInteractiveDetail_v2492_"..name.."_"..index, row, "", 6, 0, self.pageW-40, 1, "ZoFontGameSmall")
    detail:SetHidden(true)

    local rule = wm:CreateControl("EAS_CodexInteractiveRule_v2492_"..name.."_"..index, row, CT_BACKDROP)
    rule:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, 6, 0)
    rule:SetDimensions(self.pageW-42, 1)
    rule:SetCenterColor(0.26, 0.17, 0.08, 0.14)
    rule:SetEdgeColor(0, 0, 0, 0)

    row.titleLabel = title
    row.detailLabel = detail
    row.rule = rule
    row.rowIndex = index
    return row
end

-- ============================================================================
-- v0.24.94 - Golden Pursuits workspace + dynamic index + gear border cleanup
-- Adds Golden Pursuits to the shared TABS registry so both the Glass nav and
-- the Index pick it up automatically. Also keeps future registered tabs in the
-- Index by continuing to build that spread directly from TABS.
-- ============================================================================

do
    local found = false
    for _, key in ipairs(TABS) do
        if key == "PURSUITS" then found = true break end
    end
    if not found then
        local insertAt = #TABS + 1
        for i, key in ipairs(TABS) do
            if key == "ACHIEVEMENTS" then insertAt = i break end
        end
        table.insert(TABS, insertAt, "PURSUITS")
    end
end

TAB_LABELS.PURSUITS = "Golden Pursuits"
TAB_TITLES.PURSUITS = "GOLDEN PURSUITS"
TAB_PAGE_NUMBERS.PURSUITS = "GP"
EAS_TAB_SHORT.PURSUITS = "PURSUITS"
EAS_TAB_DESCRIPTIONS.PURSUITS = "Live Golden Pursuits campaigns, task progress, campaign progress, and time remaining."

local function easSafeMethod2494(object, methodName, fallback, ...)
    if not object then return fallback end
    local fn = object[methodName]
    if type(fn) ~= "function" then return fallback end
    local ok, a, b, c, d = pcall(fn, object, ...)
    if not ok then return fallback end
    if a == nil then return fallback end
    return a, b, c, d
end

local function easFormatPursuitTime2494(seconds)
    seconds = math.max(0, tonumber(seconds) or 0)
    if seconds <= 0 then return "Ending soon / unavailable" end
    if type(ZO_FormatTime) == "function" and TIME_FORMAT_STYLE_SHOW_LARGEST_TWO_UNITS and TIME_FORMAT_PRECISION_TWENTY_FOUR_HOUR then
        local ok, text = pcall(ZO_FormatTime, seconds, TIME_FORMAT_STYLE_SHOW_LARGEST_TWO_UNITS, TIME_FORMAT_PRECISION_TWENTY_FOUR_HOUR)
        if ok and text and text ~= "" then return tostring(text) end
    end
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    if days > 0 then return string.format("%dd %dh", days, hours) end
    local minutes = math.floor((seconds % 3600) / 60)
    return string.format("%dh %dm", hours, minutes)
end

local BuildGoldenPursuitsView2494ImplArch

function J:BuildGoldenPursuitsView2494(...)
    return BuildGoldenPursuitsView2494ImplArch(self, ...)
end

BuildGoldenPursuitsView2494ImplArch = function(self)
    local view = { rows = {}, campaigns = {}, total = 0 }
    local manager = PROMOTIONAL_EVENT_MANAGER
    if not manager or type(manager.GetNumActiveCampaigns) ~= "function" or type(manager.GetCampaignDataByIndex) ~= "function" then
        view.status = "Golden Pursuits data is not available yet."
        return view
    end

    local countRaw = easSafeMethod2494(manager, "GetNumActiveCampaigns", 0)
    local count = tonumber(countRaw) or 0
    for campaignIndex = 1, count do
        local campaign = easSafeMethod2494(manager, "GetCampaignDataByIndex", nil, campaignIndex)
        if campaign then
            local visible = easSafeMethod2494(campaign, "ShouldCampaignBeVisible", true) ~= false
            local returning = easSafeMethod2494(campaign, "IsReturningPlayerCampaign", false) == true
            if visible and not returning then
                local campaignName = tostring(easSafeMethod2494(campaign, "GetDisplayName", "Golden Pursuit"))
                local completedRaw = easSafeMethod2494(campaign, "GetNumActivitiesCompleted", 0)
                local thresholdRaw = easSafeMethod2494(campaign, "GetCapstoneRewardThreshold", 0)
                local secondsRemainingRaw = easSafeMethod2494(campaign, "GetSecondsRemaining", 0)
                local completed = tonumber(completedRaw) or 0
                local threshold = tonumber(thresholdRaw) or 0
                local secondsRemaining = tonumber(secondsRemainingRaw) or 0
                local campaignInfo = {
                    data = campaign,
                    name = campaignName,
                    completed = completed,
                    threshold = threshold,
                    secondsRemaining = secondsRemaining,
                    allRewardsClaimed = easSafeMethod2494(campaign, "AreAllRewardsClaimed", false) == true,
                }
                view.campaigns[#view.campaigns + 1] = campaignInfo

                local activities = easSafeMethod2494(campaign, "GetActivities", {}) or {}
                for activityIndex, activity in ipairs(activities) do
                    -- Some promotional-event methods return multiple values. Passing
                    -- those returns directly to tonumber makes Lua treat return #2 as
                    -- the numeric base. Capture the first value before conversion.
                    local progressRaw = easSafeMethod2494(activity, "GetProgress", 0)
                    local goalRaw = easSafeMethod2494(activity, "GetCompletionThreshold", 0)
                    local progress = tonumber(progressRaw) or 0
                    local goal = tonumber(goalRaw) or 0
                    local complete = easSafeMethod2494(activity, "IsComplete", false) == true
                    local rewardClaimed = easSafeMethod2494(activity, "IsRewardClaimed", false) == true
                    local rewardData = easSafeMethod2494(activity, "GetRewardData", nil)
                    local rewardName = ""
                    if rewardData then rewardName = tostring(easSafeMethod2494(rewardData, "GetFormattedName", "")) end
                    view.rows[#view.rows + 1] = {
                        campaign = campaign,
                        campaignName = campaignName,
                        campaignCompleted = completed,
                        campaignThreshold = threshold,
                        secondsRemaining = secondsRemaining,
                        activity = activity,
                        activityIndex = activityIndex,
                        name = tostring(easSafeMethod2494(activity, "GetDisplayName", "Golden Pursuit Task")),
                        progress = progress,
                        goal = goal,
                        complete = complete,
                        rewardClaimed = rewardClaimed,
                        rewardName = rewardName,
                    }
                end
            end
        end
    end

    view.total = #view.rows
    if #view.campaigns == 0 then
        view.status = "No active Golden Pursuits campaign is currently available."
    elseif view.total == 0 then
        view.status = "Golden Pursuits is active, but no task rows are currently exposed."
    end
    return view
end

local CreateGoldenPursuitsSpread2494ImplArch

function J:CreateGoldenPursuitsSpread2494(...)
    return CreateGoldenPursuitsSpread2494ImplArch(self, ...)
end

CreateGoldenPursuitsSpread2494ImplArch = function(self)
    local spread = self:CreateSpreadShell("PURSUITS")
    self:AddSpreadHeader(spread, "GOLDEN PURSUITS", "SELECTED PURSUIT")
    spread.pageSize = 10
    spread.page = 1
    spread.selectedGlobalIndex = nil
    spread.rows = {}

    spread.prevButton = makeButton("EAS_GoldenPursuitsPrev2494", spread.left, "< PREV", 14, 54, 94, 28, function()
        spread.page = math.max(1, (tonumber(spread.page) or 1) - 1)
        spread.selectedGlobalIndex = nil
        self:RefreshGoldenPursuitsPage2494()
    end)
    spread.nextButton = makeButton("EAS_GoldenPursuitsNext2494", spread.left, "NEXT >", self.pageW - 108, 54, 94, 28, function()
        spread.page = (tonumber(spread.page) or 1) + 1
        spread.selectedGlobalIndex = nil
        self:RefreshGoldenPursuitsPage2494()
    end)

    local rowStart = 94
    for i = 1, spread.pageSize do
        spread.rows[i] = self:CreateBookRow(spread.left, "PURSUITS", i, rowStart + (i - 1) * 39, function(rowIndex)
            local globalIndex = ((tonumber(spread.page) or 1) - 1) * spread.pageSize + rowIndex
            spread.selectedGlobalIndex = globalIndex
            self:RefreshGoldenPursuitsPage2494()
        end)
    end

    spread.pageLabel = makeLabel("EAS_GoldenPursuitsPage2494", spread.left, "", 14, self.pageH - 64, self.pageW - 28, 22, "ZoFontGame")
    spread.pageLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.themeLabels[#self.themeLabels + 1] = spread.pageLabel

    spread.detailTitle = makeLabel("EAS_GoldenPursuitsDetailTitle2494", spread.right, "Golden Pursuits", 18, 58, self.pageW - 36, 48, "ZoFontWinH2")
    spread.detailTitle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    spread.detailBody = makeLabel("EAS_GoldenPursuitsDetailBody2494", spread.right, "", 18, 116, self.pageW - 36, self.pageH - 220, "ZoFontGame")
    spread.detailBody:SetVerticalAlignment(TEXT_ALIGN_TOP)
    self.themeLabels[#self.themeLabels + 1] = spread.detailTitle
    self.themeLabels[#self.themeLabels + 1] = spread.detailBody

    if self.topButtons then
        self.topButtons[#self.topButtons + 1] = spread.prevButton
        self.topButtons[#self.topButtons + 1] = spread.nextButton
    end

    -- v0.24.98: this action is intentionally a quest/travel action rather than
    -- a shortcut into ESO's native Golden Pursuits scene. Row selection still
    -- activates/routs immediately; this button lets the user retry the same
    -- selected pursuit action from the detail panel.
    spread.openButton = makeButton("EAS_GoldenPursuitsOpen2494", spread.right, "TRAVEL / QUEST", 18, self.pageH - 82, self.pageW - 36, 34, function()
        local view = spread.view or self:BuildGoldenPursuitsView2494()
        local globalIndex = spread.selectedGlobalIndex
        if not globalIndex and view.rows and view.rows[1] then
            globalIndex = 1
            spread.selectedGlobalIndex = 1
        end
        if globalIndex and type(self.ActivateGoldenPursuit2497) == "function" then
            self:ActivateGoldenPursuit2497(globalIndex)
        elseif EPC and EPC.Print then
            EPC:Print("Select a Golden Pursuit first.")
        end
    end)
    if self.topButtons then self.topButtons[#self.topButtons + 1] = spread.openButton end
    return spread
end

local RefreshGoldenPursuitsPage2494ImplArch

function J:RefreshGoldenPursuitsPage2494(...)
    return RefreshGoldenPursuitsPage2494ImplArch(self, ...)
end

RefreshGoldenPursuitsPage2494ImplArch = function(self)
    local page = self.pages and self.pages.PURSUITS
    if not page then return end
    local view = self:BuildGoldenPursuitsView2494()
    page.view = view

    local pageSize = page.pageSize or 10
    local pageCount = math.max(1, math.ceil((tonumber(view.total) or 0) / pageSize))
    page.page = math.max(1, math.min(tonumber(page.page) or 1, pageCount))
    local first = (page.page - 1) * pageSize + 1

    for i, rowControl in ipairs(page.rows or {}) do
        local globalIndex = first + i - 1
        local row = view.rows[globalIndex]
        if row then
            rowControl:SetHidden(false)
            local suffix = row.complete and " [DONE]" or ""
            rowControl.titleLabel:SetText(tostring(row.name or "Golden Pursuit") .. suffix)
            local selected = page.selectedGlobalIndex == globalIndex
            easSetInk(rowControl.titleLabel, selected, row.complete)
        else
            rowControl:SetHidden(true)
        end
    end

    local last = math.min(view.total or 0, first + pageSize - 1)
    if (view.total or 0) > 0 then
        page.pageLabel:SetText(string.format("%d-%d OF %d  -  PAGE %d / %d", first, last, view.total, page.page, pageCount))
    else
        page.pageLabel:SetText("NO ACTIVE TASKS")
    end
    easSetEnabled(page.prevButton, page.page > 1)
    easSetEnabled(page.nextButton, page.page < pageCount)
    setButtonStyle(page.prevButton, false, self:GetTheme())
    setButtonStyle(page.nextButton, false, self:GetTheme())
    setButtonStyle(page.openButton, false, self:GetTheme())
    easSetEnabled(page.openButton, (tonumber(view.total) or 0) > 0)

    local selected = page.selectedGlobalIndex and view.rows[page.selectedGlobalIndex] or nil
    if not selected and view.rows[first] then
        selected = view.rows[first]
        page.selectedGlobalIndex = first
    end

    if selected then
        page.detailTitle:SetText(selected.name or "Golden Pursuit")
        local progressText = string.format("%d / %d", tonumber(selected.progress) or 0, tonumber(selected.goal) or 0)
        local campaignProgress = string.format("%d / %d", tonumber(selected.campaignCompleted) or 0, tonumber(selected.campaignThreshold) or 0)
        local rewardText = selected.rewardName ~= "" and selected.rewardName or "Reward shown in ESO Golden Pursuits"
        local state = selected.complete and "COMPLETE" or "IN PROGRESS"
        local claimed = selected.rewardClaimed and "YES" or "NO"
        local text = string.format(
            "CAMPAIGN\n%s\n\nTASK PROGRESS\n%s\n\nCAMPAIGN PROGRESS\n%s\n\nTIME REMAINING\n%s\n\nSTATUS\n%s\n\nREWARD\n%s\n\nREWARD CLAIMED\n%s",
            tostring(selected.campaignName or "Golden Pursuits"), progressText, campaignProgress,
            easFormatPursuitTime2494(selected.secondsRemaining), state, rewardText, claimed)
        setBookText(page.detailBody, text, page.detailBody:GetWidth())
    else
        page.detailTitle:SetText("Golden Pursuits")
        setBookText(page.detailBody, view.status or "No active Golden Pursuits tasks are available right now.", page.detailBody:GetWidth())
    end
end

function J:RegisterGoldenPursuitsRefresh2494()
    if self.goldenPursuitsRegistered2494 then return end
    self.goldenPursuitsRegistered2494 = true
    local function refresh()
        if self.pages and self.pages.PURSUITS and self.activeTab == "PURSUITS" then
            self:RefreshGoldenPursuitsPage2494()
        end
    end
    if PROMOTIONAL_EVENT_MANAGER and type(PROMOTIONAL_EVENT_MANAGER.RegisterCallback) == "function" then
        pcall(PROMOTIONAL_EVENT_MANAGER.RegisterCallback, PROMOTIONAL_EVENT_MANAGER, "ActivityProgressUpdated", refresh)
        pcall(PROMOTIONAL_EVENT_MANAGER.RegisterCallback, PROMOTIONAL_EVENT_MANAGER, "RewardsClaimed", refresh)
    end
    if EVENT_MANAGER and EVENT_PROMOTIONAL_EVENTS_ACTIVITY_TRACKING_UPDATED then
        EVENT_MANAGER:RegisterForEvent(EPC.name .. "_GoldenPursuitsCodex2494", EVENT_PROMOTIONAL_EVENTS_ACTIVITY_TRACKING_UPDATED, refresh)
    end
end

function J:FixGearLoadoutBorders2494(page)
    if not page or not page.loadoutButtons then return end
    for _, button in ipairs(page.loadoutButtons) do
        local skin = button and button.easPremiumSkin
        if skin then
            if skin.bg then
                skin.bg:ClearAnchors()
                skin.bg:SetAnchor(TOPLEFT, button, TOPLEFT, 1, 1)
                skin.bg:SetAnchor(BOTTOMRIGHT, button, BOTTOMRIGHT, -1, -1)
            end
            if skin.glow then
                -- The old glow extended one pixel beyond the CT_BUTTON and ESO
                -- clipped the top edge. Keep the glow inside the button bounds.
                skin.glow:ClearAnchors()
                skin.glow:SetAnchor(TOPLEFT, button, TOPLEFT, 1, 1)
                skin.glow:SetAnchor(BOTTOMRIGHT, button, BOTTOMRIGHT, -1, -1)
            end
        end
    end
end

local easLegacyRefreshInteractiveGear_2494 = RefreshInteractiveGearImplArch
RefreshInteractiveGroupFinderImplArch = function(self, page)
    local D = EPC.DungeonFinder
    if not D then return end
    D.viewMode = "LIVE"
    local v = D:BuildLiveView()

    local widths = {142, 70, 78, 78}
    local x = 14
    for i=1,4 do
        local b = page.controls[i]
        b:ClearAnchors(); b:SetAnchor(TOPLEFT, page.left, TOPLEFT, x, 54); b:SetDimensions(widths[i], 25)
        x = x + widths[i] + 4
    end
    page.controls[1]:SetHidden(false); page.controls[1]:SetText(tostring(v.categoryName or "CATEGORY"))
    page.controls[2]:SetHidden(false); page.controls[2]:SetText("ALL")
    page.controls[3]:SetHidden(false); page.controls[3]:SetText("NORMAL")
    page.controls[4]:SetHidden(false); page.controls[4]:SetText("VETERAN")
    setButtonStyle(page.controls[1], false, self:GetTheme())
    setButtonStyle(page.controls[2], v.difficulty == "ALL", self:GetTheme())
    setButtonStyle(page.controls[3], v.difficulty == "NORMAL", self:GetTheme())
    setButtonStyle(page.controls[4], v.difficulty == "VETERAN", self:GetTheme())

    page.secondary[1]:SetText("< PREV"); page.secondary[2]:SetText("NEXT >")
    page.secondary[3]:SetText("NEXT CATEGORY"); page.secondary[4]:SetText("REFRESH")
    for i=1,4 do page.secondary[i]:SetHidden(false); setButtonStyle(page.secondary[i], false, self:GetTheme()) end
    easSetEnabled(page.secondary[1], (tonumber(v.page) or 1) > 1)
    easSetEnabled(page.secondary[2], (tonumber(v.page) or 1) < (tonumber(v.pageCount) or 1))

    local selected = v.selected
    for i,rowControl in ipairs(page.rows) do
        local row = v.rows and v.rows[i]
        if row then
            rowControl:SetHidden(false)
            local isSelected = selected and row.data == selected
            local rowTitle = tostring(row.title or "Group Listing")
            if row.lastBoss then rowTitle = "LAST BOSS  -  " .. rowTitle end
            rowControl.titleLabel:SetText(rowTitle)
            local detail = tostring(row.owner or "")
            if row.roles and row.roles ~= "" then detail = detail .. "   " .. row.roles end
            if row.activeApplication then detail = "PENDING   " .. detail end
            rowControl.detailLabel:SetText(detail)
            easSetInk(rowControl.titleLabel, isSelected, false); easSetInk(rowControl.detailLabel, isSelected, true)
            if row.lastBoss and EPC.saved.groupFinderWidgetLastBossHighlight == true and not isSelected then
                -- v0.29.341: steady emphasis; no per-frame row animation.
                rowControl:SetHandler("OnUpdate", nil)
                rowControl.titleLabel:SetColor(1.00, 0.78, 0.24, 1)
            else
                rowControl:SetHandler("OnUpdate", nil)
            end
        else rowControl:SetHandler("OnUpdate", nil); rowControl:SetHidden(true) end
    end

    local stateText = D.liveSearchPending and "SEARCHING..." or ((tonumber(v.total) or 0) == 0 and "NO LISTINGS - MONITORING" or "LIVE")
    page.pageLabel:SetText(string.format("%s  -  PAGE %d / %d  -  %d LISTINGS", stateText, tonumber(v.page) or 1, tonumber(v.pageCount) or 1, tonumber(v.total) or 0))

    if selected then
        local function get(method, fallback)
            if type(selected[method]) == "function" then local ok,val=pcall(selected[method],selected); if ok and val ~= nil then return val end end
            return fallback
        end
        local title = tostring(get("GetTitle", "Group Listing"))
        local owner = tostring(get("GetOwnerDisplayName", "Unknown"))
        local description = tostring(get("GetDescription", ""))
        local autoAccept = get("DoesGroupAutoAcceptRequests", false) == true
        local activeApplication = get("IsActiveApplication", false) == true
        local roleText = liveRoleSummary and liveRoleSummary(selected) or ""
        page.detailTitle:SetText((EPC.DungeonFinder and EPC.DungeonFinder:IsLastBossListing(selected) and EPC.saved.groupFinderWidgetLastBossHighlight == true) and ("LAST BOSS  -  " .. title) or title)
        setBookText(page.detailBody, string.format("LEADER\n%s\n\nCATEGORY\n%s\n\nMODE\n%s\n\nROLES\n%s\n\nAPPLICATION\n%s\n\nDESCRIPTION\n%s", owner, tostring(v.categoryName or "Group Finder"), tostring(v.difficulty or "ALL"), roleText ~= "" and roleText or "Any / listing rules", activeApplication and "PENDING" or (autoAccept and "INSTANT JOIN" or "APPLICATION"), description ~= "" and description or "No description provided."), page.detailBody:GetWidth())
    else
        page.detailTitle:SetText("Group Finder")
        setBookText(page.detailBody, "Live ESO player-created listings appear here. Choose a category and Normal/Veteran mode, REFRESH can be used at any time. If the current category has no listings, the page remains ready for ESO search updates. Group Finder search is unavailable while hosting your own listing, in Battlegrounds, or below level 10.", page.detailBody:GetWidth())
    end

    page.action0:SetText("JOIN / APPLY"); page.action1:SetText("WHISPER LEADER")
    page.action2:SetText("RESCIND APPLICATION"); page.action3:SetText("REFRESH")
    for _,b in ipairs({page.action0,page.action1,page.action2,page.action3}) do b:SetHidden(false); setButtonStyle(b,false,self:GetTheme()) end
    easSetEnabled(page.action0, selected ~= nil); easSetEnabled(page.action1, selected ~= nil)
    easSetEnabled(page.action2, true); easSetEnabled(page.action3, true)
end

RefreshInteractiveGearImplArch = function(self, page)
    easLegacyRefreshInteractiveGear_2494(self, page)
    self:FixGearLoadoutBorders2494(page)
end

local easLegacySetTab_2494 = SetTabImplArch
SetTabImplArch = function(self, tab)
    easLegacySetTab_2494(self, tab)
    if self.activeTab == "PURSUITS" then self:RefreshGoldenPursuitsPage2494() end
end

local easLegacyCreate_2494 = CreateImplArch
CreateImplArch = function(self)
    easLegacyCreate_2494(self)
    if not self.pages.PURSUITS then
        self.pages.PURSUITS = self:CreateGoldenPursuitsSpread2494()
    end

    -- Re-fit all sidebar entries after adding a new workspace. This keeps the
    -- final tab completely inside the rail instead of letting it clip at bottom.
    if self.glassSidebar and self.tabButtons then
        local orderedTabs = {"INDEX"}
        for _, key in ipairs(TABS) do if key ~= "INDEX" then orderedTabs[#orderedTabs + 1] = key end end
        -- Keep every workspace entry inside the 664px sidebar. Golden Pursuits
        -- and Group Finder bring the rail to 18 total entries, so use a tighter
        -- step only when needed and preserve comfortable spacing on shorter rails.
        local step = (#orderedTabs >= 18) and 34 or ((#orderedTabs > 16) and 36 or 37)
        for index, key in ipairs(orderedTabs) do
            local b = self.tabButtons[key]
            if b then
                b:ClearAnchors()
                b:SetAnchor(TOPLEFT, self.glassSidebar, TOPLEFT, 10, 42 + ((index - 1) * step))
                b:SetDimensions(186, 28)
                b:SetText("    " .. tostring(TAB_LABELS[key] or key))
            end
        end
    end

    self:RegisterGoldenPursuitsRefresh2494()
    self:SetTab(self.activeTab or "INDEX")
    self:ApplyTheme()
end

-- ============================================================================
-- v0.24.95 - Alliance theme labels + readable Dungeon selected status
-- The Glass accent selector now cycles only the three ESO alliances and labels
-- the active alliance directly. Dungeon availability/status is rendered as
-- separate lines instead of one compressed sentence.
-- ============================================================================

local EAS_ALLIANCE_THEME_ORDER_2495 = {"PARCHMENT", "MIDNIGHT", "DAEDRIC"}
local EAS_ALLIANCE_THEME_LABELS_2495 = {
    PARCHMENT = "ALDMERI",
    MIDNIGHT = "DAGGERFALL",
    DAEDRIC = "EBONHEART",
}

-- Make the former parchment accent read as Aldmeri gold in the glass shell.
if THEMES and THEMES.PARCHMENT then
    THEMES.PARCHMENT.edge = {0.78, 0.60, 0.14, 1}
    THEMES.PARCHMENT.accent = {0.95, 0.74, 0.16, 1}
end

function J:GetAllianceThemeLabel2495()
    local s = self:EnsureSaved()
    return EAS_ALLIANCE_THEME_LABELS_2495[s.theme] or "ALDMERI"
end

function J:UpdateAllianceThemeButton2495()
    if not self.themeButton then return end
    self.themeButton:SetText(self:GetAllianceThemeLabel2495())
    if self.themeButton.SetFont then self.themeButton:SetFont("ZoFontGameSmall") end
end

CycleThemeImplArch = function(self)
    local s = self:EnsureSaved()
    local current = 0
    for i, key in ipairs(EAS_ALLIANCE_THEME_ORDER_2495) do
        if key == s.theme then current = i break end
    end
    current = current + 1
    if current > #EAS_ALLIANCE_THEME_ORDER_2495 then current = 1 end
    s.theme = EAS_ALLIANCE_THEME_ORDER_2495[current]
    self:ApplyTheme()
end

local easLegacyApplyTheme_2495 = ApplyThemeImplArch
ApplyThemeImplArch = function(self)
    easLegacyApplyTheme_2495(self)
    self:UpdateAllianceThemeButton2495()
end

local easLegacyRefreshInteractiveDungeons_2495 = RefreshInteractiveDungeonsImplArch
RefreshInteractiveDungeonsImplArch = function(self, page)
    easLegacyRefreshInteractiveDungeons_2495(self, page)

    local v = EPC.DungeonFinder and EPC.DungeonFinder:BuildView() or nil
    local selected = v and v.selected or nil
    if not selected or not page or not page.detailBody then return end

    local req = (tonumber(selected.championMin) or 0) > 0 and ("CP " .. tostring(selected.championMin))
        or ((tonumber(selected.levelMin) or 0) > 0 and ("LEVEL " .. tostring(selected.levelMin)) or "ESO REQUIREMENTS APPLY")
    local queueState = v.queued and "QUEUED" or "NOT QUEUED"
    local normalState = selected.normalActivityId and "YES" or "NO"
    local veteranState = selected.veteranActivityId and "YES" or "NO"

    local text = string.format(
        "SOURCE\n%s\nREQUIREMENT\n%s\nMODE\n%s\nROLE\n%s\nSTATUS\n%s\nNORMAL\n%s\nVETERAN\n%s\nHOST\nAuto Accept: %s\nEnforce Roles: %s\n1 Tank / 1 Healer / 2 DPS",
        tostring(selected.source or "DLC / CHAPTER"), req,
        tostring(v.difficulty or "ALL"), tostring(v.role or "DPS"),
        queueState, normalState, veteranState,
        v.autoAccept and "ON" or "OFF", v.enforceRoles and "ON" or "OFF")
    setBookText(page.detailBody, text, page.detailBody:GetWidth())
end

local easLegacyCreate_2495 = CreateImplArch
CreateImplArch = function(self)
    -- Old Frost was a fourth non-alliance accent. Migrate it into the three-
    -- alliance selector before the final theme pass.
    local sv = self:EnsureSaved()
    if sv.theme == "FROST" then sv.theme = "PARCHMENT" end

    easLegacyCreate_2495(self)

    if self.glassFloatingToolbar then
        self.glassFloatingToolbar:SetDimensions(220, 42)
        local controls = {
            {self.prevPageButton, 8, 6, 30, 30},
            {self.nextPageButton, 42, 6, 30, 30},
            {self.themeButton, 76, 6, 98, 30},
            {self.closeButton, 178, 6, 34, 30},
        }
        for _, data in ipairs(controls) do
            local c = data[1]
            if c then
                c:ClearAnchors()
                c:SetAnchor(TOPLEFT, self.glassFloatingToolbar, TOPLEFT, data[2], data[3])
                c:SetDimensions(data[4], data[5])
            end
        end
    end

    self:ApplyTheme()
end


-- ============================================================================
-- v0.24.96 - Golden Pursuits numeric fix + two-column Dungeon details +
-- alliance-aware Index styling
-- ============================================================================

function J:ApplyIndexAllianceTheme2496()
    if not self.glassMode then return end
    local t = self:GetTheme()
    local accent = t.accent or t.edge or {0.43, 0.68, 0.96, 1}
    local text = t.text or {0.92, 0.95, 0.99, 1}
    for _, key in ipairs(TABS) do
        if key ~= "INDEX" then
            local b = _G["EAS_CodexIndex_" .. tostring(key)]
            if b then
                -- Make Index entries visibly follow the selected alliance, not
                -- just their hover/pressed state.
                if b.SetNormalFontColor then
                    b:SetNormalFontColor(accent[1], accent[2], accent[3], 1)
                    b:SetMouseOverFontColor(1, 1, 1, 1)
                    b:SetPressedFontColor(accent[1], accent[2], accent[3], 1)
                end
                easEnsurePremiumButtonSkin(b)
                if b.easPremiumSkin then
                    local bg, glow = b.easPremiumSkin.bg, b.easPremiumSkin.glow
                    if bg then
                        bg:SetCenterColor(accent[1], accent[2], accent[3], 0.075)
                        bg:SetEdgeColor(accent[1], accent[2], accent[3], 0.38)
                    end
                    if glow then
                        glow:SetCenterColor(0, 0, 0, 0)
                        glow:SetEdgeColor(accent[1], accent[2], accent[3], 0.12)
                    end
                end
            end
        end
    end
    -- Keep Index headers/body readable while the entries carry the alliance color.
    if self.pages and self.pages.INDEX then
        local p = self.pages.INDEX
        if p.leftTitle and p.leftTitle.SetColor then p.leftTitle:SetColor(text[1], text[2], text[3], 1) end
        if p.rightTitle and p.rightTitle.SetColor then p.rightTitle:SetColor(text[1], text[2], text[3], 1) end
    end
end

local easLegacyApplyTheme_2496 = ApplyThemeImplArch
ApplyThemeImplArch = function(self)
    easLegacyApplyTheme_2496(self)
    self:ApplyIndexAllianceTheme2496()
end

function J:SetupDungeonTwoColumn2496(page)
    if not page or page.dungeonTwoColumn2496 then return end
    page.dungeonTwoColumn2496 = true

    local gap = 12
    local colW = math.floor((self.pageW - 36 - gap) / 2)
    page.dungeonColumnW2496 = colW

    page.detailTitle:ClearAnchors()
    page.detailTitle:SetAnchor(TOPLEFT, page.right, TOPLEFT, 18, 54)
    page.detailTitle:SetDimensions(self.pageW - 36, 42)

    page.detailBody:ClearAnchors()
    page.detailBody:SetAnchor(TOPLEFT, page.right, TOPLEFT, 18, 104)
    page.detailBody:SetDimensions(colW, 214)
    page.detailBody:SetFont("ZoFontGame")

    local right = wm:CreateControl("EAS_DungeonSelectedRight2496", page.right, CT_LABEL)
    right:SetAnchor(TOPLEFT, page.right, TOPLEFT, 18 + colW + gap, 104)
    right:SetDimensions(colW, 214)
    right:SetFont("ZoFontGame")
    right:SetVerticalAlignment(TEXT_ALIGN_TOP)
    if right.SetMaxLineCount then right:SetMaxLineCount(0) end
    page.detailBodyRight2496 = right
    self.themeLabels[#self.themeLabels + 1] = right

    -- Queue/host actions are also a 2x2 grid so the selected side is balanced.
    local actionGap = 8
    local actionW = math.floor((self.pageW - 36 - actionGap) / 2)
    local actionY = 338
    for i, button in ipairs({page.action0, page.action1, page.action2, page.action3}) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        button:ClearAnchors()
        button:SetAnchor(TOPLEFT, page.right, TOPLEFT, 18 + col * (actionW + actionGap), actionY + row * 42)
        button:SetDimensions(actionW, 34)
        if button.SetFont then button:SetFont("ZoFontGameBold") end
    end
end

local easLegacyRefreshInteractiveDungeons_2496 = RefreshInteractiveDungeonsImplArch
RefreshInteractiveDungeonsImplArch = function(self, page)
    easLegacyRefreshInteractiveDungeons_2496(self, page)
    if not page then return end
    self:SetupDungeonTwoColumn2496(page)

    local v = EPC.DungeonFinder and EPC.DungeonFinder:BuildView() or nil
    local selected = v and v.selected or nil
    local right = page.detailBodyRight2496
    local colW = page.dungeonColumnW2496 or math.floor((self.pageW - 48) / 2)

    if not selected then
        if right then right:SetHidden(true) right:SetText("") end
        page.detailBody:SetDimensions(self.pageW - 36, 214)
        page.detailBody:SetFont("ZoFontGame")
        setBookText(page.detailBody,
            "Select a dungeon on the left. Choose Normal or Veteran and your role, then queue the selected dungeon or create a Group Finder listing.",
            page.detailBody:GetWidth())
        return
    end

    if right then right:SetHidden(false) end
    page.detailBody:SetDimensions(colW, 214)

    local req = (tonumber(selected.championMin) or 0) > 0 and ("CP " .. tostring(selected.championMin))
        or ((tonumber(selected.levelMin) or 0) > 0 and ("LEVEL " .. tostring(selected.levelMin)) or "ESO REQUIREMENTS APPLY")
    local queueState = v.queued and "QUEUED" or "NOT QUEUED"
    local normalState = selected.normalActivityId and "YES" or "NO"
    local veteranState = selected.veteranActivityId and "YES" or "NO"

    local leftText = string.format(
        "STATUS\n%s\n\nAVAILABILITY\nNORMAL  %s\nVETERAN  %s\n\nSOURCE\n%s",
        queueState, normalState, veteranState, tostring(selected.source or "DLC / CHAPTER"))
    local rightText = string.format(
        "MODE\n%s\n\nROLE\n%s\n\nREQUIREMENT\n%s\n\nHOST OPTIONS\nAUTO ACCEPT  %s\nENFORCE ROLES  %s",
        tostring(v.difficulty or "ALL"), tostring(v.role or "DPS"), req,
        v.autoAccept and "ON" or "OFF", v.enforceRoles and "ON" or "OFF")

    setBookText(page.detailBody, leftText, colW)
    if right then setBookText(right, rightText, colW) end
end

local easLegacyCreate_2496 = CreateImplArch
CreateImplArch = function(self)
    easLegacyCreate_2496(self)
    if self.pages and self.pages.DUNGEONS then
        self:SetupDungeonTwoColumn2496(self.pages.DUNGEONS)
    end
    self:ApplyTheme()
end

-- ============================================================================
-- v0.24.98 - Golden Pursuits detail action
-- Replaces the native "Open ESO Golden Pursuits" shortcut with a direct
-- TRAVEL / QUEST action for the currently selected pursuit.
-- ============================================================================

-- ============================================================================
-- v0.24.97 - Golden Pursuits select-to-track + quest/wayshrine routing
-- Selecting a pursuit makes it ESO's tracked Golden Pursuit activity. If the
-- pursuit maps to an accepted journal quest, assist that quest and travel to
-- the best discovered wayshrine ESO exposes for its current objective. When a
-- task names a place directly, fall back to a matching discovered wayshrine.
-- All travel still originates from the user's row click.
-- ============================================================================

local function easNormalizePursuitText2497(value)
    local text = tostring(value or "")
    if type(zo_strlower) == "function" then text = zo_strlower(text) else text = string.lower(text) end
    text = string.gsub(text, "|c%x%x%x%x%x%x", " ")
    text = string.gsub(text, "|r", " ")
    text = string.gsub(text, "[^%w%s']", " ")
    text = string.gsub(text, "%s+", " ")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function easPursuitCampaignKey2497(row)
    if not row then return nil end
    local key = easSafeMethod2494(row.campaign, "GetKey", nil)
    if key ~= nil then return key end
    if row.campaign and row.campaign.campaignKey ~= nil then return row.campaign.campaignKey end
    return nil
end

local easLegacyBuildGoldenPursuitsView_2497 = BuildGoldenPursuitsView2494ImplArch
BuildGoldenPursuitsView2494ImplArch = function(self)
    local view = easLegacyBuildGoldenPursuitsView_2497(self)
    for _, row in ipairs(view.rows or {}) do
        row.campaignKey = easPursuitCampaignKey2497(row)
        row.tracked = easSafeMethod2494(row.activity, "IsTracked", false) == true
        row.description = ""
        if row.campaignKey ~= nil and type(GetPromotionalEventCampaignActivityDescription) == "function" then
            local ok, description = pcall(GetPromotionalEventCampaignActivityDescription, row.campaignKey, row.activityIndex)
            if ok and description then row.description = tostring(description) end
        end
    end
    return view
end

function J:FindJournalQuestForPursuit2497(row)
    if not row or type(GetJournalQuestName) ~= "function" then return nil end
    local pursuitName = easNormalizePursuitText2497(row.name)
    local pursuitDescription = easNormalizePursuitText2497(row.description)
    local haystack = " " .. pursuitName .. " " .. pursuitDescription .. " "
    local max = MAX_JOURNAL_QUESTS or 25
    local bestIndex, bestName, bestLength = nil, nil, 0

    for questIndex = 1, max do
        local ok, questName = pcall(GetJournalQuestName, questIndex)
        questName = ok and tostring(questName or "") or ""
        local normalizedQuest = easNormalizePursuitText2497(questName)
        -- Avoid matching generic very short quest names into unrelated pursuit text.
        if #normalizedQuest >= 5 and string.find(haystack, normalizedQuest, 1, true) then
            if #normalizedQuest > bestLength then
                bestIndex, bestName, bestLength = questIndex, questName, #normalizedQuest
            end
        end
    end
    return bestIndex, bestName
end

function J:TrackGoldenPursuit2497(row)
    if not row then return false end
    local campaignKey = row.campaignKey or easPursuitCampaignKey2497(row)
    if campaignKey == nil or type(TrackPromotionalEventActivity) ~= "function" then
        return false
    end
    local ok = pcall(TrackPromotionalEventActivity, campaignKey, row.activityIndex)
    return ok == true
end

function J:FindPursuitTextWayshrine2497(row)
    if not row or not EPC.Travel or type(EPC.Travel.GetWayshrines) ~= "function" then return nil end
    local haystack = " " .. easNormalizePursuitText2497(row.name) .. " " .. easNormalizePursuitText2497(row.description) .. " "
    local entries = EPC.Travel:GetWayshrines(EPC.lastSnapshot or {})
    local best, bestScore = nil, 0

    for _, entry in ipairs(entries or {}) do
        if entry.canTravel then
            local shrineName = easNormalizePursuitText2497(entry.name)
            shrineName = string.gsub(shrineName, "%s+wayshrine%s*$", "")
            local zoneName = easNormalizePursuitText2497(entry.zoneName)
            local score = 0
            if #shrineName >= 5 and string.find(haystack, " " .. shrineName .. " ", 1, true) then
                score = 120 + #shrineName
            elseif #zoneName >= 5 and zoneName ~= "unknown zone" and string.find(haystack, " " .. zoneName .. " ", 1, true) then
                score = 70 + #zoneName
            end
            if score > 0 and entry.isCurrentZone then score = score + 20 end
            if score > bestScore then
                best, bestScore = entry, score
            end
        end
    end
    return best
end

function J:TravelTrackedPursuitQuest2497(row, questIndex, questName, attempt)
    attempt = tonumber(attempt) or 1
    if not row or not questIndex or not EPC.Travel then return false end

    local snapshot = EPC.lastSnapshot or (EPC.Engine and EPC.Engine.BuildSnapshot and EPC.Engine:BuildSnapshot()) or {}
    local entries, focusedQuest, bestQuestShrine = nil, nil, nil
    if type(EPC.Travel.GetWayshrines) == "function" then
        entries, focusedQuest, bestQuestShrine = EPC.Travel:GetWayshrines(snapshot)
    end

    local exactPositionReady = focusedQuest and focusedQuest.position and focusedQuest.position.available == true
    if bestQuestShrine and (exactPositionReady or attempt >= 6) then
        self.goldenPursuitRouteStatus2497 = string.format("ACTIVE QUEST: %s\nWAYSHRINE: %s", tostring(questName or focusedQuest.name or "Quest"), tostring(bestQuestShrine.name or "Wayshrine"))
        if self.pages and self.pages.PURSUITS then self:RefreshGoldenPursuitsPage2494() end
        if type(EPC.Travel.TravelToWayshrineNode) == "function" then
            return EPC.Travel:TravelToWayshrineNode(bestQuestShrine.nodeIndex, bestQuestShrine.name)
        end
        return false
    end

    if attempt < 6 and type(zo_callLater) == "function" then
        zo_callLater(function()
            self:TravelTrackedPursuitQuest2497(row, questIndex, questName, attempt + 1)
        end, 120)
        return true
    end

    if bestQuestShrine and type(EPC.Travel.TravelToWayshrineNode) == "function" then
        self.goldenPursuitRouteStatus2497 = string.format("ACTIVE QUEST: %s\nWAYSHRINE: %s", tostring(questName or "Quest"), tostring(bestQuestShrine.name or "Wayshrine"))
        if self.pages and self.pages.PURSUITS then self:RefreshGoldenPursuitsPage2494() end
        return EPC.Travel:TravelToWayshrineNode(bestQuestShrine.nodeIndex, bestQuestShrine.name)
    end

    self.goldenPursuitRouteStatus2497 = "Pursuit tracked. No discovered wayshrine matched this quest objective."
    EPC:Print(self.goldenPursuitRouteStatus2497)
    if self.pages and self.pages.PURSUITS then self:RefreshGoldenPursuitsPage2494() end
    return false
end

local ActivateGoldenPursuit2497ImplArch

function J:ActivateGoldenPursuit2497(...)
    return ActivateGoldenPursuit2497ImplArch(self, ...)
end

ActivateGoldenPursuit2497ImplArch = function(self, globalIndex)
    local page = self.pages and self.pages.PURSUITS
    if not page then return end
    local view = self:BuildGoldenPursuitsView2494()
    page.view = view
    local row = view.rows and view.rows[globalIndex] or nil
    if not row then return end

    page.selectedGlobalIndex = globalIndex
    self.goldenPursuitRouteStatus2497 = ""

    if self:TrackGoldenPursuit2497(row) then
        self.goldenPursuitRouteStatus2497 = "ACTIVE GOLDEN PURSUIT: YES"
    else
        self.goldenPursuitRouteStatus2497 = "Selected in Codex; ESO pursuit tracking API unavailable."
    end

    local questIndex, questName = self:FindJournalQuestForPursuit2497(row)
    if questIndex then
        if type(SetMapToQuestZone) == "function" then pcall(SetMapToQuestZone, questIndex) end
        local allowGoldenAssist2516 = EPC.ActiveQuest
            and EPC.ActiveQuest.GetQuestTrackingSource2513
            and EPC.ActiveQuest:GetQuestTrackingSource2513() == "GOLDEN_PURSUITS"
        if allowGoldenAssist2516 and TRACK_TYPE_QUEST ~= nil and type(SetTrackedIsAssisted) == "function" then
            if type(SetTracked) == "function" then pcall(SetTracked, TRACK_TYPE_QUEST, true, questIndex, 0) end
            pcall(SetTrackedIsAssisted, TRACK_TYPE_QUEST, true, questIndex, 0)
        end
        if EPC.Travel.InvalidateQuestPositionCache then EPC.Travel:InvalidateQuestPositionCache() end
        if EPC.Travel.GetFocusedQuest then EPC.Travel:GetFocusedQuest(EPC.lastSnapshot or {}) end
        self.goldenPursuitRouteStatus2497 = string.format("ACTIVE GOLDEN PURSUIT: YES\nACTIVE QUEST: %s\nFinding nearest discovered wayshrine...", tostring(questName or "Quest"))
        self:RefreshGoldenPursuitsPage2494()
        self:TravelTrackedPursuitQuest2497(row, questIndex, questName, 1)
        return
    end

    -- Many Golden Pursuits are activities rather than journal quests. If ESO's
    -- activity text explicitly names a city/zone, use the matching discovered
    -- wayshrine instead of inventing a quest association.
    local shrine = self:FindPursuitTextWayshrine2497(row)
    if shrine and EPC.Travel and type(EPC.Travel.TravelToWayshrineNode) == "function" then
        self.goldenPursuitRouteStatus2497 = string.format("ACTIVE GOLDEN PURSUIT: YES\nDESTINATION: %s", tostring(shrine.name or "Wayshrine"))
        self:RefreshGoldenPursuitsPage2494()
        EPC.Travel:TravelToWayshrineNode(shrine.nodeIndex, shrine.name)
        return
    end

    self.goldenPursuitRouteStatus2497 = "ACTIVE GOLDEN PURSUIT: YES\nNo journal quest or explicit wayshrine target was exposed for this activity."
    EPC:Print("Golden Pursuit tracked. No safe quest/wayshrine target could be matched for automatic routing.")
    self:RefreshGoldenPursuitsPage2494()
end

local WireGoldenPursuitRows2497ImplArch

function J:WireGoldenPursuitRows2497(...)
    return WireGoldenPursuitRows2497ImplArch(self, ...)
end

WireGoldenPursuitRows2497ImplArch = function(self, page)
    if not page or page.goldenPursuitRows2497 then return end
    page.goldenPursuitRows2497 = true
    for rowIndex, rowControl in ipairs(page.rows or {}) do
        rowControl:SetHandler("OnClicked", function()
            local globalIndex = ((tonumber(page.page) or 1) - 1) * (page.pageSize or 10) + rowIndex
            self:ActivateGoldenPursuit2497(globalIndex)
        end)
    end
end

local easLegacyRefreshGoldenPursuitsPage_2497 = RefreshGoldenPursuitsPage2494ImplArch
RefreshGoldenPursuitsPage2494ImplArch = function(self)
    easLegacyRefreshGoldenPursuitsPage_2497(self)
    local page = self.pages and self.pages.PURSUITS
    if not page then return end
    local view = page.view or self:BuildGoldenPursuitsView2494()

    for i, rowControl in ipairs(page.rows or {}) do
        local globalIndex = ((tonumber(page.page) or 1) - 1) * (page.pageSize or 10) + i
        local row = view.rows and view.rows[globalIndex] or nil
        if row and rowControl.titleLabel then
            local suffix = row.complete and " [DONE]" or (row.tracked and " [ACTIVE]" or "")
            rowControl.titleLabel:SetText(tostring(row.name or "Golden Pursuit") .. suffix)
        end
    end

    local selected = page.selectedGlobalIndex and view.rows and view.rows[page.selectedGlobalIndex] or nil
    if selected and page.detailBody then
        local progressText = string.format("%d / %d", tonumber(selected.progress) or 0, tonumber(selected.goal) or 0)
        local campaignProgress = string.format("%d / %d", tonumber(selected.campaignCompleted) or 0, tonumber(selected.campaignThreshold) or 0)
        local rewardText = selected.rewardName ~= "" and selected.rewardName or "Reward shown in ESO Golden Pursuits"
        local state = selected.complete and "COMPLETE" or "IN PROGRESS"
        local claimed = selected.rewardClaimed and "YES" or "NO"
        local tracked = selected.tracked and "YES" or "NO"
        local route = self.goldenPursuitRouteStatus2497 or ""
        local text = string.format(
            "CAMPAIGN\n%s\n\nTASK PROGRESS\n%s\n\nCAMPAIGN PROGRESS\n%s\n\nTIME REMAINING\n%s\n\nSTATUS\n%s\n\nACTIVE PURSUIT\n%s\n\nREWARD\n%s\n\nREWARD CLAIMED\n%s%s",
            tostring(selected.campaignName or "Golden Pursuits"), progressText, campaignProgress,
            easFormatPursuitTime2494(selected.secondsRemaining), state, tracked, rewardText, claimed,
            route ~= "" and ("\n\nROUTE\n" .. route) or "")
        setBookText(page.detailBody, text, page.detailBody:GetWidth())
    end
end

local easLegacyCreate_2497 = CreateImplArch
CreateImplArch = function(self)
    easLegacyCreate_2497(self)
    if self.pages and self.pages.PURSUITS then
        self:WireGoldenPursuitRows2497(self.pages.PURSUITS)
        self:RefreshGoldenPursuitsPage2494()
    end
end


-- v0.24.99: keep completed Golden Pursuits separate from active tasks.
-- The default list contains only unfinished tasks. A dedicated toggle shows
-- completed tasks in their own view, so completed and active rows never mix.
local easLegacyBuildGoldenPursuitsView_2499 = BuildGoldenPursuitsView2494ImplArch
BuildGoldenPursuitsView2494ImplArch = function(self)
    local view = easLegacyBuildGoldenPursuitsView_2499(self)
    local allRows = view.rows or {}
    local activeRows, completedRows = {}, {}

    for _, row in ipairs(allRows) do
        if row.complete then
            completedRows[#completedRows + 1] = row
        else
            activeRows[#activeRows + 1] = row
        end
    end

    view.allRows = allRows
    view.activeRows = activeRows
    view.completedRows = completedRows
    view.activeTotal = #activeRows
    view.completedTotal = #completedRows

    local page = self.pages and self.pages.PURSUITS
    local showCompleted = page and page.showCompleted2499 == true
    view.showCompleted = showCompleted
    view.rows = showCompleted and completedRows or activeRows
    view.total = #view.rows

    if showCompleted then
        if view.completedTotal == 0 then
            view.status = "No completed Golden Pursuits tasks yet."
        end
    elseif view.activeTotal == 0 and view.completedTotal > 0 then
        view.status = "All current Golden Pursuits tasks are complete."
    end

    return view
end

local easLegacyCreateGoldenPursuitsSpread_2499 = CreateGoldenPursuitsSpread2494ImplArch
CreateGoldenPursuitsSpread2494ImplArch = function(self)
    local spread = easLegacyCreateGoldenPursuitsSpread_2499(self)
    spread.showCompleted2499 = false

    spread.modeButton2499 = makeButton(
        "EAS_GoldenPursuitsMode2499",
        spread.left,
        "COMPLETED",
        122,
        54,
        self.pageW - 244,
        28,
        function()
            spread.showCompleted2499 = not spread.showCompleted2499
            spread.page = 1
            spread.selectedGlobalIndex = nil
            self.goldenPursuitRouteStatus2497 = ""
            self:RefreshGoldenPursuitsPage2494()
        end
    )

    if self.topButtons then
        self.topButtons[#self.topButtons + 1] = spread.modeButton2499
    end
    return spread
end

local easLegacyActivateGoldenPursuit_2499 = ActivateGoldenPursuit2497ImplArch
ActivateGoldenPursuit2497ImplArch = function(self, globalIndex)
    local page = self.pages and self.pages.PURSUITS
    if page then
        local view = page.view or self:BuildGoldenPursuitsView2494()
        local row = view.rows and view.rows[globalIndex] or nil
        if row and row.complete then
            page.selectedGlobalIndex = globalIndex
            self.goldenPursuitRouteStatus2497 = "COMPLETED TASK - no travel needed."
            self:RefreshGoldenPursuitsPage2494()
            return
        end
    end
    return easLegacyActivateGoldenPursuit_2499(self, globalIndex)
end

WireGoldenPursuitRows2497ImplArch = function(self, page)
    if not page or page.goldenPursuitRows2499 then return end
    page.goldenPursuitRows2499 = true
    page.goldenPursuitRows2497 = true

    for rowIndex, rowControl in ipairs(page.rows or {}) do
        rowControl:SetHandler("OnClicked", function()
            local globalIndex = ((tonumber(page.page) or 1) - 1) * (page.pageSize or 10) + rowIndex
            local view = page.view or self:BuildGoldenPursuitsView2494()
            local row = view.rows and view.rows[globalIndex] or nil
            if row and row.complete then
                page.selectedGlobalIndex = globalIndex
                self.goldenPursuitRouteStatus2497 = ""
                self:RefreshGoldenPursuitsPage2494()
            else
                self:ActivateGoldenPursuit2497(globalIndex)
            end
        end)
    end
end

local easLegacyRefreshGoldenPursuitsPage_2499 = RefreshGoldenPursuitsPage2494ImplArch
RefreshGoldenPursuitsPage2494ImplArch = function(self)
    easLegacyRefreshGoldenPursuitsPage_2499(self)
    local page = self.pages and self.pages.PURSUITS
    if not page then return end
    local view = page.view or self:BuildGoldenPursuitsView2494()

    if page.modeButton2499 then
        if page.showCompleted2499 then
            page.modeButton2499:SetText(string.format("ACTIVE (%d)", tonumber(view.activeTotal) or 0))
        else
            page.modeButton2499:SetText(string.format("COMPLETED (%d)", tonumber(view.completedTotal) or 0))
        end
        setButtonStyle(page.modeButton2499, page.showCompleted2499 == true, self:GetTheme())
        easSetEnabled(page.modeButton2499, true)
    end

    local pageSize = page.pageSize or 10
    local total = tonumber(view.total) or 0
    local pageCount = math.max(1, math.ceil(total / pageSize))
    local first = ((tonumber(page.page) or 1) - 1) * pageSize + 1
    local last = math.min(total, first + pageSize - 1)
    local modeName = page.showCompleted2499 and "COMPLETED" or "ACTIVE TASKS"

    if page.pageLabel then
        if total > 0 then
            page.pageLabel:SetText(string.format("%s  %d-%d OF %d  -  PAGE %d / %d", modeName, first, last, total, tonumber(page.page) or 1, pageCount))
        else
            page.pageLabel:SetText(page.showCompleted2499 and "NO COMPLETED TASKS" or "NO ACTIVE TASKS")
        end
    end

    if page.openButton then
        if page.showCompleted2499 then
            page.openButton:SetText("COMPLETED")
            easSetEnabled(page.openButton, false)
        else
            page.openButton:SetText("TRAVEL / QUEST")
            easSetEnabled(page.openButton, total > 0)
        end
        setButtonStyle(page.openButton, false, self:GetTheme())
    end
end

-- ============================================================================
-- v0.25.04 - Golden Pursuits HUD selection sync
-- Mirror the active Codex pursuit (and matched journal quest, when available)
-- into the gameplay Golden Pursuits overlay after the user selects it.
-- ============================================================================
local easLegacyActivateGoldenPursuit_2504 = ActivateGoldenPursuit2497ImplArch
ActivateGoldenPursuit2497ImplArch = function(self, globalIndex)
    local page = self.pages and self.pages.PURSUITS
    local view = page and (page.view or self:BuildGoldenPursuitsView2494()) or nil
    local row = view and view.rows and view.rows[globalIndex] or nil

    if row and not row.complete and EPC.GoldenPursuits and EPC.GoldenPursuits.SetSelectedPursuitQuest2504 then
        local questIndex, questName = self:FindJournalQuestForPursuit2497(row)
        EPC.GoldenPursuits:SetSelectedPursuitQuest2504(row.name, questIndex and questName or nil, row.campaignKey, row.activityIndex)
    end

    return easLegacyActivateGoldenPursuit_2504(self, globalIndex)
end

-- v0.25.12: a Golden Pursuit-linked journal quest can drive the same Active
-- Quest HUD / native assisted-quest sync. Whichever menu selection the player makes
-- most recently becomes the Suite's displayed/navigation quest.
local easLegacyActivateGoldenPursuit_2512 = ActivateGoldenPursuit2497ImplArch
ActivateGoldenPursuit2497ImplArch = function(self, globalIndex)
    local page = self.pages and self.pages.PURSUITS
    local view = page and (page.view or self:BuildGoldenPursuitsView2494()) or nil
    local row = view and view.rows and view.rows[globalIndex] or nil
    if row and not row.complete then
        local questIndex, questName = self:FindJournalQuestForPursuit2497(row)
        if questIndex and EPC.ActiveQuest and EPC.ActiveQuest.SetSelectedQuest2512 then
            local questId = 0
            if type(GetJournalQuestId) == "function" then
                local ok, value = pcall(GetJournalQuestId, questIndex)
                if ok then questId = tonumber(value) or 0 end
            end
            EPC.ActiveQuest:SetSelectedQuest2512(questIndex, questId, questName, "GOLDEN_PURSUIT")
        end
    end
    return easLegacyActivateGoldenPursuit_2512(self, globalIndex)
end


-- v0.25.16: whichever source is chosen in Quest Tracking Settings is
-- authoritative even after Golden Pursuits runs its legacy routing logic.
local easLegacyActivateGoldenPursuit_2516 = ActivateGoldenPursuit2497ImplArch
ActivateGoldenPursuit2497ImplArch = function(self, globalIndex)
    local result = easLegacyActivateGoldenPursuit_2516(self, globalIndex)
    if EPC.ActiveQuest and EPC.ActiveQuest.ApplySelectedSourceToESO2516 then
        EPC.ActiveQuest:ApplySelectedSourceToESO2516()
    end
    return result
end


-- v0.25.29: Group Finder is its own Codex chapter.
local easSelectTab02529 = SelectTabImplArch
local SelectTabImplArch

function J:SelectTab(...)
    return SelectTabImplArch(self, ...)
end

SelectTabImplArch = function(self, tab, ...)
    local result = easSelectTab02529(self, tab, ...)
    if tab == "GROUPFINDER" and EPC.DungeonFinder then
        EPC.DungeonFinder:SetViewMode("LIVE")
        EPC.DungeonFinder:RefreshLiveListings(true)
    elseif tab == "DUNGEONS" and EPC.DungeonFinder then
        EPC.DungeonFinder:SetViewMode("DUNGEONS")
    end
    return result
end

-- v0.25.41: Group Finder social modes share the Codex chapter with public listings.
local easRefreshInteractiveGroupFinder02541 = RefreshInteractiveGroupFinderImplArch
RefreshInteractiveGroupFinderImplArch = function(self, page)
    local D = EPC.DungeonFinder
    if not D then return end
    local mode = tostring(D.socialMode or "PUBLIC")
    if mode == "PUBLIC" then
        easRefreshInteractiveGroupFinder02541(self, page)
        -- Replace the top row with clear source selectors; public category/mode controls move to row two.
        local labels = {"PUBLIC GROUPS", "GUILD MEMBERS", "REFRESH", ""}
        local widths = {126, 126, 104, 1}
        local x = 14
        for i=1,4 do
            local b = page.controls[i]
            b:ClearAnchors(); b:SetAnchor(TOPLEFT, page.left, TOPLEFT, x, 54); b:SetDimensions(widths[i],25)
            b:SetText(labels[i]); b:SetHidden(false); setButtonStyle(b, i==1, self:GetTheme())
            x = x + widths[i] + 4
        end
        local v = D:BuildLiveView()
        page.secondary[1]:SetText("< PREV")
        page.secondary[2]:SetText("NEXT >")
        page.secondary[3]:SetText("DIFF: " .. tostring(v.difficulty or "ALL"))
        page.secondary[4]:SetText("NEXT CATEGORY")
        for i=1,4 do page.secondary[i]:SetHidden(false); setButtonStyle(page.secondary[i], false, self:GetTheme()) end
        easSetEnabled(page.secondary[1], (tonumber(v.page) or 1) > 1)
        easSetEnabled(page.secondary[2], (tonumber(v.page) or 1) < (tonumber(v.pageCount) or 1))
        return
    end

    local v = D:BuildSocialView()
    local labels = {"PUBLIC GROUPS", "GUILD MEMBERS", "REFRESH", ""}
    local widths = {126, 126, 104, 1}
    local x = 14
    for i=1,4 do
        local b = page.controls[i]
        b:ClearAnchors(); b:SetAnchor(TOPLEFT, page.left, TOPLEFT, x, 54); b:SetDimensions(widths[i],25)
        b:SetText(labels[i]); b:SetHidden(false); setButtonStyle(b, mode=="GUILD" and i==2, self:GetTheme())
        x = x + widths[i] + 4
    end
    page.secondary[1]:SetText("< PREV"); page.secondary[2]:SetText("NEXT >")
    page.secondary[3]:SetText("REFRESH"); page.secondary[4]:SetText("PUBLIC GROUPS")
    for i=1,4 do page.secondary[i]:SetHidden(false); setButtonStyle(page.secondary[i], false, self:GetTheme()) end
    easSetEnabled(page.secondary[1], (tonumber(v.page) or 1) > 1)
    easSetEnabled(page.secondary[2], (tonumber(v.page) or 1) < (tonumber(v.pageCount) or 1))

    local selected = v.selected
    for i,rowControl in ipairs(page.rows) do
        rowControl:SetHandler("OnUpdate", nil)
        local row = v.rows and v.rows[i]
        if row then
            rowControl:SetHidden(false)
            local isSelected = selected and selected.key == row.key
            local name = tostring(row.displayName or row.characterName or "Player")
            local charName = tostring(row.characterName or "")
            rowControl.titleLabel:SetText(name)
            local status = row.inYourGroup and "IN YOUR GROUP" or tostring(row.guildName or "Guild")
            local zone = tostring(row.zoneName or "")
            if zone ~= "" then status = status .. "   " .. zone end
            if charName ~= "" and charName ~= name then status = charName .. "   " .. status end
            rowControl.detailLabel:SetText(status)
            easSetInk(rowControl.titleLabel, isSelected, false); easSetInk(rowControl.detailLabel, isSelected, true)
        else
            rowControl:SetHidden(true)
        end
    end

    local title = "GUILD MEMBERS"
    page.pageLabel:SetText(string.format("%s  -  PAGE %d / %d  -  %d PLAYERS", title, tonumber(v.page) or 1, tonumber(v.pageCount) or 1, tonumber(v.total) or 0))

    if selected then
        local cp = tonumber(selected.championPoints) or 0
        local levelText = cp > 0 and ("CP " .. tostring(cp)) or ((tonumber(selected.level) or 0) > 0 and ("LEVEL " .. tostring(selected.level)) or "LEVEL UNKNOWN")
        page.detailTitle:SetText(tostring(selected.displayName or "Player"))
        setBookText(page.detailBody, string.format("CHARACTER\n%s\n\nLOCATION\n%s\n\n%s\n\nSTATUS\n%s\n\nACTIONS\nInvite or whisper this player. ESO does not expose another player's private party composition, so the Suite does not claim whether they already have a separate party.", tostring(selected.characterName or selected.displayName or "Unknown"), tostring(selected.zoneName or "Unknown"), levelText, selected.inYourGroup and "Already in your group" or "Available for invite attempt"), page.detailBody:GetWidth())
    elseif mode == "GUILD" then
        page.detailTitle:SetText("Guild Members")
        setBookText(page.detailBody, "Shows online members from your guild rosters. Select a member to WHISPER or INVITE. ESO does not expose whether an ungrouped guild member is privately grouped elsewhere, so party status is not guessed.", page.detailBody:GetWidth())
    else
        page.detailTitle:SetText("Guild Members")
        setBookText(page.detailBody, "Shows online members from your guild rosters. Select a member to WHISPER or INVITE.", page.detailBody:GetWidth())
    end

    page.action0:SetText("INVITE TO GROUP")
    page.action1:SetText("WHISPER")
    page.action2:SetText("REFRESH")
    page.action3:SetText("PUBLIC GROUPS")
    for _,b in ipairs({page.action0,page.action1,page.action2,page.action3}) do b:SetHidden(false); setButtonStyle(b,false,self:GetTheme()) end
    easSetEnabled(page.action0, selected ~= nil and selected.inYourGroup ~= true)
    easSetEnabled(page.action1, selected ~= nil)
    easSetEnabled(page.action2, true); easSetEnabled(page.action3, true)
end

local easRunInteractiveControl02541 = RunInteractiveControlImplArch
RunInteractiveControlImplArch = function(self, tab, index)
    if tab == "GROUPFINDER" and EPC.DungeonFinder then
        local D = EPC.DungeonFinder
        if index == 1 then D:SetSocialMode("PUBLIC")
        elseif index == 2 then D:SetSocialMode("GUILD")
        elseif index == 3 then
            if D.socialMode == "PUBLIC" then D:RefreshLiveListings(true) end
        end
        self:RefreshSuitePage(tab)
        return
    end
    return easRunInteractiveControl02541(self, tab, index)
end

local easRunInteractiveSecondary02541 = RunInteractiveSecondaryImplArch
RunInteractiveSecondaryImplArch = function(self, tab, index)
    if tab == "GROUPFINDER" and EPC.DungeonFinder then
        local D = EPC.DungeonFinder
        if D.socialMode == "PUBLIC" then
            if index == 1 then D:ChangeLivePage(-1)
            elseif index == 2 then D:ChangeLivePage(1)
            elseif index == 3 then
                local current = tostring(D.liveDifficulty or "ALL")
                D:SetLiveDifficulty(current == "ALL" and "NORMAL" or (current == "NORMAL" and "VETERAN" or "ALL"))
            elseif index == 4 then D:CycleLiveCategory() end
        else
            if index == 1 then D:ChangeSocialPage(-1)
            elseif index == 2 then D:ChangeSocialPage(1)
            elseif index == 3 then -- event-backed data; redraw is enough
            elseif index == 4 then D:SetSocialMode("PUBLIC") end
        end
        self:RefreshSuitePage(tab)
        return
    end
    return easRunInteractiveSecondary02541(self, tab, index)
end

local easSelectInteractiveRow02541 = SelectInteractiveRowImplArch
SelectInteractiveRowImplArch = function(self, tab, index)
    if tab == "GROUPFINDER" and EPC.DungeonFinder and EPC.DungeonFinder.socialMode ~= "PUBLIC" then
        EPC.DungeonFinder:SelectSocialRow(index)
        self:RefreshSuitePage(tab)
        return
    end
    return easSelectInteractiveRow02541(self, tab, index)
end

local easRunInteractiveGearOptimizer02541 = RunInteractiveGearOptimizerImplArch
RunInteractiveGearOptimizerImplArch = function(self, tab)
    if tab == "GROUPFINDER" and EPC.DungeonFinder and EPC.DungeonFinder.socialMode ~= "PUBLIC" then
        EPC.DungeonFinder:InviteSelectedSocial(); self:RefreshSuitePage(tab); return
    end
    return easRunInteractiveGearOptimizer02541(self, tab)
end

local easRunInteractivePrimary02541 = RunInteractivePrimaryImplArch
RunInteractivePrimaryImplArch = function(self, tab)
    if tab == "GROUPFINDER" and EPC.DungeonFinder and EPC.DungeonFinder.socialMode ~= "PUBLIC" then
        EPC.DungeonFinder:WhisperSelectedSocial(); self:RefreshSuitePage(tab); return
    end
    return easRunInteractivePrimary02541(self, tab)
end

local easRunInteractiveSecondaryAction02541 = RunInteractiveSecondaryActionImplArch
RunInteractiveSecondaryActionImplArch = function(self, tab)
    if tab == "GROUPFINDER" and EPC.DungeonFinder and EPC.DungeonFinder.socialMode ~= "PUBLIC" then
        self:RefreshSuitePage(tab); return
    end
    return easRunInteractiveSecondaryAction02541(self, tab)
end

local easRunInteractiveTertiaryAction02541 = RunInteractiveTertiaryActionImplArch
RunInteractiveTertiaryActionImplArch = function(self, tab)
    if tab == "GROUPFINDER" and EPC.DungeonFinder and EPC.DungeonFinder.socialMode ~= "PUBLIC" then
        EPC.DungeonFinder:SetSocialMode("PUBLIC"); self:RefreshSuitePage(tab); return
    end
    return easRunInteractiveTertiaryAction02541(self, tab)
end

local easSelectTab02541 = SelectTabImplArch
SelectTabImplArch = function(self, tab, ...)
    local result = easSelectTab02541(self, tab, ...)
    if tab == "GROUPFINDER" and EPC.DungeonFinder and EPC.DungeonFinder.socialMode == nil then EPC.DungeonFinder.socialMode = "PUBLIC" end
    return result
end


-- v0.25.42: Public Group Finder live-status/short-code presentation.
local easRefreshInteractiveGroupFinder02542 = RefreshInteractiveGroupFinderImplArch
RefreshInteractiveGroupFinderImplArch = function(self, page)
    easRefreshInteractiveGroupFinder02542(self, page)
    local D = EPC.DungeonFinder
    if not D or tostring(D.socialMode or "PUBLIC") ~= "PUBLIC" then return end

    local v = D:BuildLiveView()
    local supportsDifficulty = D.LiveCategorySupportsDifficulty and D:LiveCategorySupportsDifficulty(v.category)

    -- Keep the social source row intact. Use the second row as quick Group Finder controls.
    page.secondary[1]:SetText("< PREV")
    page.secondary[2]:SetText("NEXT >")
    page.secondary[3]:SetText(supportsDifficulty and ((tostring(v.difficulty or "NORMAL") == "VETERAN") and "V" or "N") or "-")
    page.secondary[4]:SetText(tostring(v.categoryName or "CATEGORY"))
    for i=1,4 do page.secondary[i]:SetHidden(false); setButtonStyle(page.secondary[i], false, self:GetTheme()) end
    easSetEnabled(page.secondary[1], (tonumber(v.page) or 1) > 1)
    easSetEnabled(page.secondary[2], (tonumber(v.page) or 1) < (tonumber(v.pageCount) or 1))
    easSetEnabled(page.secondary[3], supportsDifficulty == true)
    easSetEnabled(page.secondary[4], true)

    local selected = v.selected
    for i,rowControl in ipairs(page.rows) do
        local row = v.rows and v.rows[i]
        if row then
            local isSelected = selected and row.data == selected
            local rowTitle = tostring(row.title or "Group Listing")
            if row.shortCode and row.shortCode ~= "" then rowTitle = "[" .. tostring(row.shortCode) .. "] " .. rowTitle end
            if row.lastBoss then rowTitle = "LAST BOSS  -  " .. rowTitle end
            rowControl.titleLabel:SetText(rowTitle)

            local detail = tostring(row.owner or "")
            if row.roles and row.roles ~= "" then detail = detail .. "   " .. tostring(row.roles) end
            if row.activeApplication then detail = "PENDING   " .. detail end
            rowControl.detailLabel:SetText(detail)
            easSetInk(rowControl.titleLabel, isSelected, false)
            easSetInk(rowControl.detailLabel, isSelected, true)
        end
    end

    -- Yellow hourglass on the first search after a category/mode change.
    if not page.easGfSearchIcon02542 and WINDOW_MANAGER and CT_TEXTURE then
        local icon = WINDOW_MANAGER:CreateControl(nil, page.left, CT_TEXTURE)
        icon:SetDimensions(18, 18)
        icon:SetAnchor(BOTTOMLEFT, page.left, BOTTOMLEFT, 14, -50)
        icon:SetTexture("EsoUI/Art/Miscellaneous/timer_32.dds")
        icon:SetColor(1, 0.78, 0, 1)
        icon:SetDrawLayer(DL_OVERLAY)
        page.easGfSearchIcon02542 = icon
    end

    local inf = string.char(226, 136, 158)
    if D.liveAwaitingResults02542 then
        if page.easGfSearchIcon02542 then page.easGfSearchIcon02542:SetHidden(false) end
        page.pageLabel:SetText(string.format("|cFFD700SEARCHING|r  -  %s  -  %s", tostring(v.categoryName or "GROUP FINDER"), supportsDifficulty and tostring(v.difficulty or "NORMAL") or "LIVE"))
    elseif (tonumber(v.total) or 0) == 0 then
        if page.easGfSearchIcon02542 then page.easGfSearchIcon02542:SetHidden(true) end
        page.pageLabel:SetText(string.format("%s  MONITORING  -  %s  -  NO LISTINGS", inf, tostring(v.categoryName or "GROUP FINDER")))
    else
        if page.easGfSearchIcon02542 then page.easGfSearchIcon02542:SetHidden(true) end
        page.pageLabel:SetText(string.format("LIVE  -  %s  -  PAGE %d / %d  -  %d LISTINGS", tostring(v.categoryName or "GROUP FINDER"), tonumber(v.page) or 1, tonumber(v.pageCount) or 1, tonumber(v.total) or 0))
    end

    if selected then
        local function get(method, fallback)
            if type(selected[method]) == "function" then
                local ok, value = pcall(selected[method], selected)
                if ok and value ~= nil then return value end
            end
            return fallback
        end
        local title = tostring(get("GetTitle", "Group Listing"))
        local code = D.GetListingShortCode and D:GetListingShortCode(selected) or ""
        if code ~= "" then title = "[" .. code .. "] " .. title end
        local owner = tostring(get("GetOwnerDisplayName", "Unknown"))
        local description = tostring(get("GetDescription", ""))
        local target = tostring(get("GetSecondaryOptionText", ""))
        local roles = D.GetActualRoleSummary and D:GetActualRoleSummary(selected) or "ROLES: ANY"
        page.detailTitle:SetText(title)
        setBookText(page.detailBody, string.format("LEADER\n%s\n\nINSTANCE\n%s\n\nCATEGORY\n%s\n\nMODE\n%s\n\n%s\n\nDESCRIPTION\n%s", owner, target ~= "" and target or "Not specified", tostring(v.categoryName or "Group Finder"), supportsDifficulty and tostring(v.difficulty or "NORMAL") or "N/A", roles, description ~= "" and description or "No description provided."), page.detailBody:GetWidth())
    end
end



-- v0.25.43: Group Finder control readability pass.
local function easStyleGroupFinderButton02543(button, selected)
    if not button then return end
    button:SetFont("ZoFontGameBold")
    if button.SetNormalFontColor then
        if selected then
            button:SetNormalFontColor(1.00, 0.84, 0.28, 1)
        else
            button:SetNormalFontColor(0.94, 0.97, 1.00, 1)
        end
        button:SetMouseOverFontColor(0.20, 0.95, 1.00, 1)
        button:SetPressedFontColor(1.00, 0.84, 0.28, 1)
        if button.SetDisabledFontColor then button:SetDisabledFontColor(0.55, 0.58, 0.62, 0.95) end
    end
    setButtonStyle(button, selected, THEMES.MIDNIGHT or nil)
    if button.easPremiumSkin then
        local bg, glow = button.easPremiumSkin.bg, button.easPremiumSkin.glow
        if selected then
            bg:SetCenterColor(0.055, 0.085, 0.122, 0.94)
            bg:SetEdgeColor(0.18, 0.72, 0.92, 0.92)
            glow:SetEdgeColor(0.18, 0.72, 0.92, 0.28)
        else
            bg:SetCenterColor(0.025, 0.045, 0.075, 0.94)
            bg:SetEdgeColor(0.18, 0.72, 0.92, 0.70)
            glow:SetEdgeColor(0.18, 0.72, 0.92, 0.18)
        end
    end
end

local easRefreshInteractiveGroupFinder02543 = RefreshInteractiveGroupFinderImplArch
RefreshInteractiveGroupFinderImplArch = function(self, page)
    easRefreshInteractiveGroupFinder02543(self, page)
    local D = EPC.DungeonFinder
    if not D then return end

    -- Use shorter, unambiguous labels so none of the source buttons clip.
    local mode = tostring(D.socialMode or "PUBLIC")
    local sourceLabels = {"PUBLIC", "GUILD", "REFRESH", ""}
    local sourceSelected = {mode == "PUBLIC", mode == "GUILD", false, false}
    local gap = 6
    local usable = self.pageW - 28 - gap * 3
    local w = math.floor(usable / 4)
    for i=1,4 do
        local b = page.controls[i]
        if i <= 3 then
            local threeW = math.floor((self.pageW - 28 - gap * 2) / 3)
            b:ClearAnchors()
            b:SetAnchor(TOPLEFT, page.left, TOPLEFT, 14 + (i-1)*(threeW+gap), 54)
            b:SetDimensions(threeW, 28)
            b:SetText(sourceLabels[i])
            b:SetHidden(false)
            easStyleGroupFinderButton02543(b, sourceSelected[i])
        else
            b:SetHidden(true)
        end
    end

    -- The second row is context-sensitive but always uses readable full words.
    for i=1,4 do
        local b = page.secondary[i]
        b:ClearAnchors()
        b:SetAnchor(TOPLEFT, page.left, TOPLEFT, 14 + (i-1)*(w+gap), 86)
        b:SetDimensions(w, 28)
        easStyleGroupFinderButton02543(b, false)
    end

    if mode == "PUBLIC" then
        local v = D:BuildLiveView()
        local supportsDifficulty = D.LiveCategorySupportsDifficulty and D:LiveCategorySupportsDifficulty(v.category)
        page.secondary[1]:SetText("PREV")
        page.secondary[2]:SetText("NEXT")
        page.secondary[3]:SetText(supportsDifficulty and ((tostring(v.difficulty or "NORMAL") == "VETERAN") and "VETERAN" or "NORMAL") or "MODE")
        local cat = tostring(v.categoryName or "CATEGORY"):upper()
        if #cat > 10 then cat = cat:sub(1,10) end
        page.secondary[4]:SetText(cat)
        easStyleGroupFinderButton02543(page.secondary[3], supportsDifficulty == true)
        easStyleGroupFinderButton02543(page.secondary[4], true)
    else
        page.secondary[1]:SetText("PREV")
        page.secondary[2]:SetText("NEXT")
        page.secondary[3]:SetText("REFRESH")
        page.secondary[4]:SetText("PUBLIC")
    end

    -- In the public browser, the fourth action hosts whichever supported dungeon
    -- the player is physically inside: a Public Dungeon or a four-player Group Dungeon.
    if mode == "PUBLIC" and page.action3 then
        local groupDungeon = D.GetCurrentGroupDungeonInfo and D:GetCurrentGroupDungeonInfo() or nil
        local publicDungeon = nil
        if not groupDungeon and D.GetCurrentPublicDungeonInfo then publicDungeon = D:GetCurrentPublicDungeonInfo() end
        local currentDungeon = groupDungeon or publicDungeon
        local alreadyHosting = D.IsHostingGroupFinderListing and D:IsHostingGroupFinderListing() or false
        local canLead = true
        if type(IsUnitSoloOrGroupLeader) == "function" then
            local ok, leader = pcall(IsUnitSoloOrGroupLeader, "player")
            if ok then canLead = leader == true end
        end
        local label = "HOST CURRENT DUNGEON"
        if groupDungeon then label = "HOST CURRENT GROUP DUNGEON"
        elseif publicDungeon then label = "HOST CURRENT PUBLIC DUNGEON" end
        page.action3:SetHidden(false)
        page.action3:SetText(alreadyHosting and "ALREADY HOSTING" or label)
        easSetEnabled(page.action3, currentDungeon ~= nil and canLead and not alreadyHosting)
    end

    -- Make the right-side action buttons visually obvious too.
    for _,b in ipairs({page.action0,page.action1,page.action2,page.action3}) do
        if b and not b:IsHidden() then
            b:SetFont("ZoFontGameBold")
            easStyleGroupFinderButton02543(b, false)
        end
    end
end

local easRunInteractiveSecondary02542 = RunInteractiveSecondaryImplArch
RunInteractiveSecondaryImplArch = function(self, tab, index)
    if tab == "GROUPFINDER" and EPC.DungeonFinder and tostring(EPC.DungeonFinder.socialMode or "PUBLIC") == "PUBLIC" then
        local D = EPC.DungeonFinder
        -- v0.29.67: Group Finder no longer exposes PREV/NEXT paging controls.
        -- Keep only the two intentional top actions: difficulty and finder style.
        if index == 3 then D:ToggleLiveDifficulty()
        elseif index == 4 then D:CycleLiveCategory()
        else return end
        self:RefreshSuitePage(tab)
        return
    end
    return easRunInteractiveSecondary02542(self, tab, index)
end

-- ============================================================================
-- v0.25.68 - Random Normal / Veteran queue actions in Dungeon Finder
-- ============================================================================
function J:SetupDungeonRandomQueue2567(page)
    if not page or page.randomQueue2567 then return end
    page.randomQueue2567 = true

    local gap = 8
    local buttonW = math.floor((self.pageW - 36 - gap) / 2)
    local y = 422

    page.randomNormal2567 = makeButton(
        "EAS_DungeonRandomNormal2567", page.right, "RANDOM NORMAL",
        18, y, buttonW, 34,
        function()
            if EPC.DungeonFinder then EPC.DungeonFinder:QueueRandom("NORMAL") end
            self:RefreshSuitePage("DUNGEONS")
        end)

    page.randomVeteran2567 = makeButton(
        "EAS_DungeonRandomVeteran2567", page.right, "RANDOM VETERAN",
        18 + buttonW + gap, y, buttonW, 34,
        function()
            if EPC.DungeonFinder then EPC.DungeonFinder:QueueRandom("VETERAN") end
            self:RefreshSuitePage("DUNGEONS")
        end)

    if page.randomNormal2567.SetFont then page.randomNormal2567:SetFont("ZoFontGameBold") end
    if page.randomVeteran2567.SetFont then page.randomVeteran2567:SetFont("ZoFontGameBold") end
end

local easLegacyRefreshInteractiveDungeons_2567 = RefreshInteractiveDungeonsImplArch
RefreshInteractiveDungeonsImplArch = function(self, page)
    easLegacyRefreshInteractiveDungeons_2567(self, page)
    if not page then return end
    self:SetupDungeonRandomQueue2567(page)

    local D = EPC.DungeonFinder
    local queued = D and D:IsQueued() or false
    local rewardEligible = D and D:IsDailyRandomRewardEligible() or nil

    page.randomNormal2567:SetHidden(false)
    page.randomVeteran2567:SetHidden(false)
    easSetEnabled(page.randomNormal2567, not queued)
    easSetEnabled(page.randomVeteran2567, not queued)

    setButtonStyle(page.randomNormal2567, D and D.difficulty == "NORMAL" and not queued, self:GetTheme())
    setButtonStyle(page.randomVeteran2567, D and D.difficulty == "VETERAN" and not queued, self:GetTheme())

    if queued then
        page.randomNormal2567:SetText("ALREADY QUEUED")
        page.randomVeteran2567:SetText("ALREADY QUEUED")
    else
        page.randomNormal2567:SetText("RANDOM NORMAL")
        page.randomVeteran2567:SetText("RANDOM VETERAN")
    end

    -- Keep the random-reward purpose visible even when no specific dungeon is selected.
    if not (D and D:GetSelected()) and page.detailBody then
        local rewardText = "DAILY RANDOM REWARD\n"
        if rewardEligible == true then
            rewardText = rewardText .. "AVAILABLE - queue Random Normal or Random Veteran to earn the ESO daily random XP and rewards."
        elseif rewardEligible == false then
            rewardText = rewardText .. "Daily bonus already claimed; ESO may still grant the repeatable random reward."
        else
            rewardText = rewardText .. "Queue Random Normal or Random Veteran for ESO's random dungeon rewards."
        end
        setBookText(page.detailBody, rewardText, page.detailBody:GetWidth())
    end
end

local easLegacyCreate_2567 = CreateImplArch
CreateImplArch = function(self)
    easLegacyCreate_2567(self)
    if self.pages and self.pages.DUNGEONS then
        self:SetupDungeonRandomQueue2567(self.pages.DUNGEONS)
    end
end

-- ============================================================================
-- v0.25.83 - Visible Dungeon History view
-- The history collector already persists exact runs and imported achievement
-- completion timestamps. Expose that data directly from the Dungeon Finder page.
-- ============================================================================
local function easDungeonHistoryDate2583(timestamp, fallbackDate, fallbackTime)
    timestamp = tonumber(timestamp) or 0
    if timestamp > 0 and type(GetDateStringFromTimestamp) == "function" then
        local ok, dateText = pcall(GetDateStringFromTimestamp, timestamp)
        if ok and dateText and dateText ~= "" then
            local timeText = ""
            if type(GetTimeStringFromTimestamp) == "function" then
                local tok, t = pcall(GetTimeStringFromTimestamp, timestamp)
                if tok and t then timeText = tostring(t) end
            end
            return timeText ~= "" and (tostring(dateText) .. "  " .. timeText) or tostring(dateText)
        end
    end
    local d = tostring(fallbackDate or "")
    local t = tostring(fallbackTime or "")
    if d ~= "" and t ~= "" then return d .. "  " .. t end
    if d ~= "" then return d end
    if timestamp > 0 then return "Timestamp " .. tostring(timestamp) end
    return "Date unavailable"
end

local function easDungeonHistoryDuration2583(seconds)
    seconds = math.max(0, tonumber(seconds) or 0)
    if seconds <= 0 then return "--" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%d:%02d", m, s)
end

function J:SetupDungeonHistory2583(page)
    if not page or page.dungeonHistory2583 then return end
    page.dungeonHistory2583 = true

    page.historyButton2583 = makeButton(
        "EAS_DungeonHistoryButton2583", page.right, "DUNGEON HISTORY",
        18, 464, self.pageW - 36, 32,
        function()
            local entering = not (self.dungeonHistoryMode2583 == true)
            self.dungeonHistoryMode2583 = entering
            if entering then self.dungeonHistoryPage2584 = 1 end
            self:RefreshSuitePage("DUNGEONS")
        end)
    if page.historyButton2583.SetFont then page.historyButton2583:SetFont("ZoFontGameBold") end

    page.historyFirst2587 = makeButton(
        "EAS_DungeonHistoryFirst2587", page.right, "FIRST",
        18, 424, 62, 30,
        function()
            self.dungeonHistoryPage2584 = 1
            self:RefreshSuitePage("DUNGEONS")
        end)
    page.historyPrev2584 = makeButton(
        "EAS_DungeonHistoryPrev2584", page.right, "PREV",
        84, 424, 62, 30,
        function()
            self.dungeonHistoryPage2584 = math.max(1, (tonumber(self.dungeonHistoryPage2584) or 1) - 1)
            self:RefreshSuitePage("DUNGEONS")
        end)
    page.historyNext2584 = makeButton(
        "EAS_DungeonHistoryNext2584", page.right, "NEXT",
        self.pageW - 146, 424, 62, 30,
        function()
            self.dungeonHistoryPage2584 = (tonumber(self.dungeonHistoryPage2584) or 1) + 1
            self:RefreshSuitePage("DUNGEONS")
        end)
    page.historyLast2587 = makeButton(
        "EAS_DungeonHistoryLast2587", page.right, "LAST",
        self.pageW - 80, 424, 62, 30,
        function()
            local _, _, totalPages = self:BuildDungeonHistoryText2583(self.dungeonHistoryPage2584)
            self.dungeonHistoryPage2584 = math.max(1, tonumber(totalPages) or 1)
            self:RefreshSuitePage("DUNGEONS")
        end)
    page.historyPageLabel2584 = makeLabel(
        "EAS_DungeonHistoryPageLabel2584", page.right, "PAGE 1 / 1",
        150, 429, self.pageW - 300, 20, "ZoFontGameBold")
    page.historyPageLabel2584:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    page.historyFirst2587:SetHidden(true)
    page.historyPrev2584:SetHidden(true)
    page.historyNext2584:SetHidden(true)
    page.historyLast2587:SetHidden(true)
    page.historyPageLabel2584:SetHidden(true)
end

function J:BuildDungeonHistoryText2583(requestedPage)
    local runs, imported = {}, {}
    if EPC.DungeonHistory and EPC.DungeonHistory.GetHistory then
        runs, imported = EPC.DungeonHistory:GetHistory()
    end
    runs = type(runs) == "table" and runs or {}
    imported = type(imported) == "table" and imported or {}

    local combined = {}
    for _, run in ipairs(runs) do
        combined[#combined + 1] = {
            when = tonumber(run.completedAt) or 0,
            title = tostring(run.dungeon or "Dungeon"),
            mode = tostring(run.difficulty or "UNKNOWN"),
            duration = easDungeonHistoryDuration2583(run.durationSeconds),
            character = tostring(run.characterName or ""),
            exact = true,
        }
    end
    for _, row in pairs(imported) do
        local historicalName = tostring(row.name or "Dungeon completion")
        local evidence = string.lower(historicalName .. " " .. tostring(row.description or "") .. " " .. tostring(row.category or "") .. " " .. tostring(row.subcategory or ""))
        local historicalMode = "HISTORICAL - MODE NOT EXPOSED"
        if string.find(evidence, "veteran", 1, true)
            or string.find(evidence, "hard mode", 1, true)
            or string.find(evidence, "challenger", 1, true)
            or string.find(evidence, "conqueror", 1, true) then
            historicalMode = "VETERAN"
        end
        combined[#combined + 1] = {
            when = tonumber(row.completedAt) or 0,
            title = historicalName,
            mode = historicalMode,
            duration = "--",
            character = "",
            exact = false,
            date = row.date,
            time = row.time,
        }
    end
    table.sort(combined, function(a, b) return (tonumber(a.when) or 0) > (tonumber(b.when) or 0) end)

    local exactCount = #runs
    local importedCount = 0
    for _ in pairs(imported) do importedCount = importedCount + 1 end

    -- Three complete records fit the history panel while keeping each entry readable.
    -- Pagination is unbounded, so very large histories (15,000+ runs) remain accessible.
    local perPage = 3
    local totalPages = math.max(1, math.ceil(#combined / perPage))
    local pageNumber = math.max(1, math.min(totalPages, tonumber(requestedPage) or 1))
    local lines = {
        string.format("RECORDED RUNS  %d    IMPORTED COMPLETIONS  %d", exactCount, importedCount),
        "",
    }
    if #combined == 0 then
        lines[#lines + 1] = "No dungeon history has been recorded yet."
        lines[#lines + 1] = ""
        lines[#lines + 1] = "New Activity Finder dungeon completions will appear here automatically. Historical entries appear when ESO exposes a dungeon achievement completion date."
        return table.concat(lines, "\n"), 1, 1
    end

    local firstIndex = ((pageNumber - 1) * perPage) + 1
    local lastIndex = math.min(#combined, firstIndex + perPage - 1)
    for i = firstIndex, lastIndex do
        local row = combined[i]
        lines[#lines + 1] = tostring(row.title)
        lines[#lines + 1] = easDungeonHistoryDate2583(row.when, row.date, row.time)
        if row.exact then
            lines[#lines + 1] = "MODE: " .. tostring(row.mode or "UNKNOWN")
            lines[#lines + 1] = "DURATION: " .. tostring(row.duration or "--")
            if row.character and row.character ~= "" then
                lines[#lines + 1] = "CHARACTER: " .. row.character
            end
        else
            lines[#lines + 1] = "MODE: " .. tostring(row.mode or "UNKNOWN")
            lines[#lines + 1] = "IMPORTED FROM ESO ACHIEVEMENT HISTORY"
        end
        lines[#lines + 1] = ""
    end
    lines[#lines + 1] = string.format("ENTRIES %d-%d OF %d", firstIndex, lastIndex, #combined)
    return table.concat(lines, "\n"), pageNumber, totalPages
end

local easLegacyRefreshInteractiveDungeons_2583 = RefreshInteractiveDungeonsImplArch
RefreshInteractiveDungeonsImplArch = function(self, page)
    easLegacyRefreshInteractiveDungeons_2583(self, page)
    if not page then return end
    self:SetupDungeonHistory2583(page)

    local historyMode = self.dungeonHistoryMode2583 == true
    page.historyButton2583:SetHidden(false)
    page.historyButton2583:SetText(historyMode and "BACK TO DUNGEON FINDER" or "DUNGEON HISTORY")
    setButtonStyle(page.historyButton2583, historyMode, self:GetTheme())

    if not historyMode then
        if page.historyFirst2587 then page.historyFirst2587:SetHidden(true) end
        if page.historyPrev2584 then page.historyPrev2584:SetHidden(true) end
        if page.historyNext2584 then page.historyNext2584:SetHidden(true) end
        if page.historyLast2587 then page.historyLast2587:SetHidden(true) end
        if page.historyPageLabel2584 then page.historyPageLabel2584:SetHidden(true) end
        return
    end

    -- Re-purpose the selected side as a dedicated visible history area.
    page.detailTitle:SetText("Dungeon History")
    if page.detailBodyRight2496 then page.detailBodyRight2496:SetHidden(true) page.detailBodyRight2496:SetText("") end
    page.detailBody:SetHidden(false)
    page.detailBody:ClearAnchors()
    page.detailBody:SetAnchor(TOPLEFT, page.right, TOPLEFT, 18, 94)
    page.detailBody:SetDimensions(self.pageW - 36, 300)
    page.detailBody:SetFont("ZoFontGame")

    local historyText, currentPage, totalPages = self:BuildDungeonHistoryText2583(self.dungeonHistoryPage2584)
    self.dungeonHistoryPage2584 = currentPage
    setBookText(page.detailBody, historyText, page.detailBody:GetWidth())

    if page.historyFirst2587 then
        page.historyFirst2587:SetHidden(false)
        page.historyFirst2587:SetMouseEnabled(currentPage > 1)
        page.historyFirst2587:SetAlpha(currentPage > 1 and 1 or 0.45)
    end
    if page.historyPrev2584 then
        page.historyPrev2584:SetHidden(false)
        page.historyPrev2584:SetMouseEnabled(currentPage > 1)
        page.historyPrev2584:SetAlpha(currentPage > 1 and 1 or 0.45)
    end
    if page.historyNext2584 then
        page.historyNext2584:SetHidden(false)
        page.historyNext2584:SetMouseEnabled(currentPage < totalPages)
        page.historyNext2584:SetAlpha(currentPage < totalPages and 1 or 0.45)
    end
    if page.historyLast2587 then
        page.historyLast2587:SetHidden(false)
        page.historyLast2587:SetMouseEnabled(currentPage < totalPages)
        page.historyLast2587:SetAlpha(currentPage < totalPages and 1 or 0.45)
    end
    if page.historyPageLabel2584 then
        page.historyPageLabel2584:SetHidden(false)
        page.historyPageLabel2584:SetText(string.format("PAGE %d / %d", currentPage, totalPages))
    end

    for _, button in ipairs({page.action0, page.action1, page.action2, page.action3}) do button:SetHidden(true) end
    if page.randomNormal2567 then page.randomNormal2567:SetHidden(true) end
    if page.randomVeteran2567 then page.randomVeteran2567:SetHidden(true) end
end

local easLegacyCreate_2583 = CreateImplArch
CreateImplArch = function(self)
    easLegacyCreate_2583(self)
    if self.pages and self.pages.DUNGEONS then
        self:SetupDungeonHistory2583(self.pages.DUNGEONS)
    end
end

-- v0.25.95 - Activity History for Trials / Arenas / PvP / Battlegrounds / Archive
local function easActivityHistoryDate2595(timestamp, fallbackDate, fallbackTime)
    timestamp = tonumber(timestamp) or 0
    if timestamp > 0 and type(FormatTimeSeconds) == "function" and type(GetDateStringFromTimestamp) == "function" then
        local dateText = tostring(GetDateStringFromTimestamp(timestamp) or "")
        local sec = timestamp % 86400
        local ok, timeText = pcall(FormatTimeSeconds, sec, TIME_FORMAT_STYLE_CLOCK_TIME, TIME_FORMAT_PRECISION_TWELVE_HOUR)
        if ok and dateText ~= "" and timeText and timeText ~= "" then return dateText .. "  " .. tostring(timeText) end
    end
    local d, t = tostring(fallbackDate or ""), tostring(fallbackTime or "")
    if d ~= "" and t ~= "" then return d .. "  " .. t end
    if d ~= "" then return d end
    return timestamp > 0 and ("Timestamp " .. tostring(timestamp)) or "Date unavailable"
end

local function easActivityHistoryDuration2595(seconds)
    seconds = math.max(0, tonumber(seconds) or 0)
    if seconds <= 0 then return "--" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%d:%02d", m, s)
end

function J:SetupActivityHistory2595(page)
    if not page or page.activityHistory2595 then return end
    page.activityHistory2595 = true
    page.activityHistoryButton2595 = makeButton(
        "EAS_ActivityHistoryButton2595", page.right, "ACTIVITY HISTORY",
        18, 464, self.pageW - 36, 32,
        function()
            local entering = not (self.activityHistoryMode2595 == true)
            self.activityHistoryMode2595 = entering
            if entering then self.activityHistoryFilter2595 = "ALL"; self.activityHistoryPage2595 = 1 end
            self:RefreshSuitePage("ACTIVITY")
        end)
    if page.activityHistoryButton2595.SetFont then page.activityHistoryButton2595:SetFont("ZoFontGameBold") end

    -- v0.26.19: dedicated history buttons matching Dungeon History.
    -- Users can jump straight to the content type they want instead of opening
    -- one mixed Activity History list.
    page.activityHistoryCategoryButtons2619 = {}
    local historyKinds = {
        {"TRIAL", "TRIAL HISTORY"}, {"ARENA", "ARENA HISTORY"}, {"BATTLEGROUND", "BG HISTORY"},
        {"PVP", "PVP HISTORY"}, {"ARCHIVE", "ARCHIVE HISTORY"},
    }
    local bw = math.floor((self.pageW - 44) / 3)
    for i,info in ipairs(historyKinds) do
        local kind, label = info[1], info[2]
        local col=(i-1)%3; local row=math.floor((i-1)/3)
        local b=makeButton("EAS_ActivityHistoryKind2619_"..kind, page.right, label, 18+col*(bw+4), 426+row*34, bw, 30, function()
            self.activityHistoryFilter2595=kind
            self.activityHistoryMode2595=true
            self.activityHistoryPage2595=1
            self:RefreshSuitePage("ACTIVITY")
        end)
        page.activityHistoryCategoryButtons2619[i]=b
    end
    page.activityHistoryButton2595:ClearAnchors()
    page.activityHistoryButton2595:SetAnchor(TOPLEFT, page.right, TOPLEFT, 18, 494)
    page.activityHistoryButton2595:SetDimensions(self.pageW-36, 30)

    page.activityHistoryFirst2595 = makeButton("EAS_ActivityHistoryFirst2595", page.right, "FIRST", 18, 530, 62, 30, function()
        self.activityHistoryPage2595 = 1; self:RefreshSuitePage("ACTIVITY")
    end)
    page.activityHistoryPrev2595 = makeButton("EAS_ActivityHistoryPrev2595", page.right, "PREV", 84, 530, 62, 30, function()
        self.activityHistoryPage2595 = math.max(1, (tonumber(self.activityHistoryPage2595) or 1) - 1); self:RefreshSuitePage("ACTIVITY")
    end)
    page.activityHistoryNext2595 = makeButton("EAS_ActivityHistoryNext2595", page.right, "NEXT", self.pageW - 146, 530, 62, 30, function()
        self.activityHistoryPage2595 = (tonumber(self.activityHistoryPage2595) or 1) + 1; self:RefreshSuitePage("ACTIVITY")
    end)
    page.activityHistoryLast2595 = makeButton("EAS_ActivityHistoryLast2595", page.right, "LAST", self.pageW - 80, 530, 62, 30, function()
        local _, _, pages = self:BuildActivityHistoryText2595(self.activityHistoryPage2595)
        self.activityHistoryPage2595 = math.max(1, tonumber(pages) or 1); self:RefreshSuitePage("ACTIVITY")
    end)
    page.activityHistoryPageLabel2595 = makeLabel("EAS_ActivityHistoryPageLabel2595", page.right, "PAGE 1 / 1", 150, 535, self.pageW - 300, 20, "ZoFontGameBold")
    page.activityHistoryPageLabel2595:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    for _, b in ipairs({page.activityHistoryFirst2595, page.activityHistoryPrev2595, page.activityHistoryNext2595, page.activityHistoryLast2595}) do b:SetHidden(true) end
    page.activityHistoryPageLabel2595:SetHidden(true)
end

function J:BuildActivityHistoryText2595(requestedPage)
    local runs, imported = {}, {}
    if EPC.ActivityRunHistory and EPC.ActivityRunHistory.GetHistory then runs, imported = EPC.ActivityRunHistory:GetHistory() end
    runs = type(runs) == "table" and runs or {}
    imported = type(imported) == "table" and imported or {}
    local filter = tostring(self.activityHistoryFilter2595 or "ALL")
    local combined = {}

    for _, run in ipairs(runs) do
        local runKind = tostring(run.category or "ACTIVITY")
        if filter == "ALL" or runKind == filter then
            combined[#combined + 1] = {
                when = tonumber(run.completedAt) or 0, title = tostring(run.activity or run.category or "Activity"),
                kind = runKind, mode = tostring(run.mode or "N/A"),
                duration = easActivityHistoryDuration2595(run.durationSeconds), character = tostring(run.characterName or ""), exact = true,
                completed = run.completed ~= false,
            }
        end
    end
    for _, row in pairs(imported) do
        local rowKind = tostring(row.category or "ACTIVITY")
        if filter == "ALL" or rowKind == filter then
            combined[#combined + 1] = {
                when = tonumber(row.completedAt) or 0, title = tostring(row.activity or "Historical completion"),
                kind = rowKind, mode = tostring(row.mode or "HISTORICAL - MODE NOT EXPOSED"),
                duration = "--", character = "", exact = false, date = row.date, time = row.time,
            }
        end
    end
    table.sort(combined, function(a,b) return (tonumber(a.when) or 0) > (tonumber(b.when) or 0) end)

    local perPage = 3
    local totalPages = math.max(1, math.ceil(#combined / perPage))
    local pageNumber = math.max(1, math.min(totalPages, tonumber(requestedPage) or 1))
    local historyLabel = (filter == "ALL") and "ALL ACTIVITY" or filter
    local lines = { historyLabel .. " HISTORY", string.format("MATCHING ENTRIES  %d", #combined), "" }
    if #combined == 0 then
        lines[#lines + 1] = "No " .. historyLabel .. " history has been recorded yet."
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Future activity events are recorded automatically. Older completion dates appear when ESO exposes a matching achievement timestamp."
        return table.concat(lines, "\n"), 1, 1
    end
    local first = ((pageNumber - 1) * perPage) + 1
    local last = math.min(#combined, first + perPage - 1)
    for i = first, last do
        local row = combined[i]
        lines[#lines + 1] = tostring(row.title)
        lines[#lines + 1] = easActivityHistoryDate2595(row.when, row.date, row.time)
        lines[#lines + 1] = string.format("TYPE: %s    MODE: %s", tostring(row.kind), tostring(row.mode))
        if row.exact then
            lines[#lines + 1] = (row.completed and "DURATION: " or "SESSION: ") .. tostring(row.duration or "--")
            if row.character ~= "" then lines[#lines + 1] = "CHARACTER: " .. row.character end
        else
            lines[#lines + 1] = "IMPORTED FROM ESO ACHIEVEMENT HISTORY"
        end
        lines[#lines + 1] = ""
    end
    lines[#lines + 1] = string.format("ENTRIES %d-%d OF %d", first, last, #combined)
    return table.concat(lines, "\n"), pageNumber, totalPages
end

local easLegacyRefreshInteractiveActivity2595 = RefreshInteractiveActivityImplArch
RefreshInteractiveActivityImplArch = function(self, page)
    easLegacyRefreshInteractiveActivity2595(self, page)
    if not page then return end
    self:SetupActivityHistory2595(page)
    local mode = self.activityHistoryMode2595 == true
    page.activityHistoryButton2595:SetHidden(false)
    page.activityHistoryButton2595:SetText(mode and "BACK TO ACTIVITIES" or "ALL ACTIVITY HISTORY")
    setButtonStyle(page.activityHistoryButton2595, mode and tostring(self.activityHistoryFilter2595 or "ALL") == "ALL", self:GetTheme())
    if page.activityHistoryCategoryButtons2619 then
        local kinds={"TRIAL","ARENA","BATTLEGROUND","PVP","ARCHIVE"}
        for i,b in ipairs(page.activityHistoryCategoryButtons2619) do
            b:SetHidden(false)
            setButtonStyle(b, mode and tostring(self.activityHistoryFilter2595 or "ALL") == kinds[i], self:GetTheme())
        end
    end
    if not mode then
        for _, b in ipairs({page.activityHistoryFirst2595, page.activityHistoryPrev2595, page.activityHistoryNext2595, page.activityHistoryLast2595}) do b:SetHidden(true) end
        page.activityHistoryPageLabel2595:SetHidden(true)
        return
    end

    local historyFilterLabel = tostring(self.activityHistoryFilter2595 or "ALL")
    page.detailTitle:SetText(historyFilterLabel == "ALL" and "Activity History" or (historyFilterLabel .. " History"))
    page.detailBody:SetHidden(false)
    page.detailBody:ClearAnchors()
    page.detailBody:SetAnchor(TOPLEFT, page.right, TOPLEFT, 18, 94)
    page.detailBody:SetDimensions(self.pageW - 36, 300)
    page.detailBody:SetFont("ZoFontGame")
    local text, current, pages = self:BuildActivityHistoryText2595(self.activityHistoryPage2595)
    self.activityHistoryPage2595 = current
    setBookText(page.detailBody, text, page.detailBody:GetWidth())

    local nav = {
        {page.activityHistoryFirst2595, current > 1}, {page.activityHistoryPrev2595, current > 1},
        {page.activityHistoryNext2595, current < pages}, {page.activityHistoryLast2595, current < pages},
    }
    for _, item in ipairs(nav) do
        local b, enabled = item[1], item[2]
        b:SetHidden(false); b:SetMouseEnabled(enabled); b:SetAlpha(enabled and 1 or 0.45)
    end
    page.activityHistoryPageLabel2595:SetHidden(false)
    page.activityHistoryPageLabel2595:SetText(string.format("PAGE %d / %d", current, pages))
    for _, b in ipairs(page.controls or {}) do b:SetHidden(true) end
    for _, b in ipairs(page.secondary or {}) do b:SetHidden(true) end
    for _, row in ipairs(page.rows or {}) do row:SetHidden(true) end
    page.pageLabel:SetText("TRIALS / ARENAS / BATTLEGROUNDS / PVP / ARCHIVE")
    for _, b in ipairs({page.action0, page.action1, page.action2, page.action3}) do if b then b:SetHidden(true) end end
end

local easLegacyCreate2595 = CreateImplArch
CreateImplArch = function(self)
    easLegacyCreate2595(self)
    if self.pages and self.pages.ACTIVITY then self:SetupActivityHistory2595(self.pages.ACTIVITY) end
end

-- v0.25.99 guild leader dropdown lifecycle cleanup ------------------------------
-- Treat the popup as part of the Travel page: never let it survive Codex close
-- or a chapter/page change.
local easGuildDropdownSetTab02599 = SetTabImplArch
SetTabImplArch = function(self, tab)
    if tab ~= "TRAVEL" and self.HideGuildLeaderHomeDropdown then
        self:HideGuildLeaderHomeDropdown()
    end
    return easGuildDropdownSetTab02599(self, tab)
end

local easGuildDropdownHide02599 = HideImplArch
HideImplArch = function(self)
    if self.HideGuildLeaderHomeDropdown then
        self:HideGuildLeaderHomeDropdown()
    end
    return easGuildDropdownHide02599(self)
end

local easGuildDropdownShow02599 = ShowGuildLeaderHomeDropdownImplArch
ShowGuildLeaderHomeDropdownImplArch = function(self, page)
    -- Opening the selector always closes any stale popup first, then lets the
    -- existing toggle logic rebuild it for the current Travel page.
    if self.guildLeaderHomeDropdown and not self.guildLeaderHomeDropdown:IsHidden() then
        self.guildLeaderHomeDropdown:SetHidden(true)
    end
    return easGuildDropdownShow02599(self, page)
end


-- v0.27.14 - Saved Builds / Tamriel Codex workspace exclusivity
-- Opening the Codex closes the detached Saved Builds workspace first.
-- Hide it without dropping UI mode so the Codex can immediately take over.
local easLoadoutWorkspaceShow02714 = ShowImplArch
ShowImplArch = function(self)
    local transferredUIMode = false
    if EPC.LoadoutManager and EPC.LoadoutManager.window and not EPC.LoadoutManager.window:IsHidden() then
        if type(EPC.LoadoutManager.TransferUIModeToCodex) == "function" then
            transferredUIMode = EPC.LoadoutManager:TransferUIModeToCodex() == true
        end
        if type(EPC.LoadoutManager.Hide) == "function" then
            EPC.LoadoutManager:Hide(true)
        end
    elseif EPC.GearLoadoutOverlay and type(EPC.GearLoadoutOverlay.SetLoadoutMode) == "function" then
        EPC.GearLoadoutOverlay:SetLoadoutMode(false)
    end

    local result = easLoadoutWorkspaceShow02714(self)
    -- If Saved Builds owned the cursor because it came from normal gameplay,
    -- the Codex now becomes responsible for releasing it when the Codex closes.
    if transferredUIMode then self.ownsUIMode = true end
    return result
end

-- v0.27.16 - Dense-page organization pass
-- Re-groups the busiest Codex pages into predictable sections with shorter copy,
-- clearer spacing, and consistent action bands.
local function easSectionLabel02716(name, parent, text, y, width)
    -- Section labels are persistent named controls. RefreshSuitePage can call this
    -- layout pass many times, so reuse an existing control instead of attempting
    -- to create another control with the same global ESO UI name.
    local l = rawget(_G, name)
    if not l and type(GetControl) == "function" then
        local ok, control = pcall(GetControl, name)
        if ok then l = control end
    end
    if not l then
        l = makeLabel(name, parent, text, 18, y, width or 394, 18, "ZoFontGameBold")
    else
        l:ClearAnchors()
        l:SetAnchor(TOPLEFT, parent, TOPLEFT, 18, y)
        l:SetDimensions(width or 394, 18)
        l:SetFont("ZoFontGameBold")
        l:SetText(text)
        l:SetHidden(false)
    end
    l:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    l:SetColor(0.55, 0.68, 0.82, 1)
    return l
end

function J:OrganizeDensePages02716()
    if not self.pages then return end

    local gear = self.pages.GEAR
    if gear and gear.right and gear.interactive then
        gear.detailTitle:ClearAnchors()
        gear.detailTitle:SetAnchor(TOPLEFT, gear.right, TOPLEFT, 18, 54)
        gear.detailTitle:SetDimensions(self.pageW - 36, 38)
        gear.detailBody:ClearAnchors()
        gear.detailBody:SetAnchor(TOPLEFT, gear.right, TOPLEFT, 18, 94)
        gear.detailBody:SetDimensions(self.pageW - 36, 108)
        gear.detailBody:SetFont("ZoFontGameSmall")

        gear.sectionLoadouts02716 = easSectionLabel02716("EAS_GearSectionLoadouts02716", gear.right, "BUILDS", 207, self.pageW-36)
        gear.sectionBuild02716 = easSectionLabel02716("EAS_GearSectionBuild02716", gear.right, "BUILD TOOLS", 253, self.pageW-36)
        gear.sectionPreset02716 = easSectionLabel02716("EAS_GearSectionPreset02716", gear.right, "COMBAT PRESET", 362, self.pageW-36)
        gear.sectionArmor02716 = easSectionLabel02716("EAS_GearSectionArmor02716", gear.right, "ARMOR WEIGHT", 408, self.pageW-36)
        gear.sectionRoute02716 = easSectionLabel02716("EAS_GearSectionRoute02716", gear.right, "SET ACTIONS", 452, self.pageW-36)

        if gear.savedLoadoutsButton then
            gear.savedLoadoutsButton:ClearAnchors()
            gear.savedLoadoutsButton:SetAnchor(TOPLEFT, gear.right, TOPLEFT, 18, 226)
            gear.savedLoadoutsButton:SetDimensions(self.pageW-36, 25)
        end
        if gear.loadoutButtons then
            local gap, w = 6, math.floor((self.pageW - 42) / 2)
            for i,b in ipairs(gear.loadoutButtons) do
                local col, row = (i-1)%2, math.floor((i-1)/2)
                b:ClearAnchors()
                b:SetAnchor(TOPLEFT, gear.right, TOPLEFT, 18 + col*(w+gap), 273 + row*29)
                b:SetDimensions(w, 25)
            end
        end
        if gear.companionAbilitiesButton then
            gear.companionAbilitiesButton:ClearAnchors()
            gear.companionAbilitiesButton:SetAnchor(TOPLEFT, gear.right, TOPLEFT, 18, 331)
            gear.companionAbilitiesButton:SetDimensions(self.pageW-36, 25)
        end
        if gear.optimizerModes then
            local gap, w = 3, math.floor((self.pageW - 45) / 4)
            for i,b in ipairs(gear.optimizerModes) do
                b:ClearAnchors()
                b:SetAnchor(TOPLEFT, gear.right, TOPLEFT, 18 + (i-1)*(w+gap), 381)
                b:SetDimensions(w, 24)
            end
        end
        if gear.armorWeightButtons then
            local gap, w = 4, math.floor((self.pageW - 44) / 3)
            for i,b in ipairs(gear.armorWeightButtons) do
                b:ClearAnchors()
                b:SetAnchor(TOPLEFT, gear.right, TOPLEFT, 18 + (i-1)*(w+gap), 427)
                b:SetDimensions(w, 24)
            end
        end
        for i,b in ipairs({gear.action0, gear.action1, gear.action2, gear.action3}) do
            if b then
                b:ClearAnchors()
                b:SetAnchor(TOPLEFT, gear.right, TOPLEFT, 18, 471 + (i-1)*22)
                b:SetDimensions(self.pageW-36, 22)
                b:SetFont("ZoFontGameSmall")
            end
        end
    end

    local travel = self.pages.TRAVEL
    if travel and travel.right and travel.interactive then
        -- v0.27.32: keep the destination area visually dominant while giving
        -- the lower travel actions larger, clearer click targets.
        travel.detailTitle:ClearAnchors()
        travel.detailTitle:SetAnchor(TOPLEFT, travel.right, TOPLEFT, 18, 54)
        travel.detailTitle:SetDimensions(self.pageW-36, 30)
        travel.detailTitle:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

        travel.detailBody:ClearAnchors()
        travel.detailBody:SetAnchor(TOPLEFT, travel.right, TOPLEFT, 18, 88)
        travel.detailBody:SetDimensions(self.pageW-36, 104)
        travel.detailBody:SetFont("ZoFontGameSmall")

        -- v0.27.58: keep the breathing room while trimming button height slightly
        -- rectangle to the action instead of stretching every button full width.
        local innerW = self.pageW - 40
        local function centerTravelButton(button, width, y, height, font)
            if not button then return end
            local w = math.min(width, innerW)
            local x = 20 + math.floor((innerW - w) / 2)
            button:ClearAnchors()
            button:SetAnchor(TOPLEFT, travel.right, TOPLEFT, x, y)
            button:SetDimensions(w, height)
            if font then button:SetFont(font) end
        end

        centerTravelButton(travel.action1, 236, 196, 30, "ZoFontGameBold")

        travel.sectionGuild02716 = easSectionLabel02716("EAS_TravelSectionGuild02716", travel.right, "GUILD HOME", 246, self.pageW-36)
        centerTravelButton(travel.guildLeaderSelect, 314, 272, 28, "ZoFontGameSmall")
        centerTravelButton(travel.action0, 206, 314, 30, "ZoFontGameBold")

        travel.sectionQuick02716 = easSectionLabel02716("EAS_TravelSectionQuick02716", travel.right, "NEARBY SERVICES", 368, self.pageW-36)
        local servicesY = 396
        local serviceGap = 14
        local merchantW = 174
        local storeW = 194
        local servicesTotalW = merchantW + serviceGap + storeW
        local servicesX = 20 + math.floor((innerW - servicesTotalW) / 2)
        if travel.action2 then
            travel.action2:ClearAnchors()
            travel.action2:SetAnchor(TOPLEFT, travel.right, TOPLEFT, servicesX, servicesY)
            travel.action2:SetDimensions(merchantW, 30)
            travel.action2:SetFont("ZoFontGameSmall")
            travel.action2:SetText("NEAREST MERCHANT")
        end
        if travel.action3 then
            travel.action3:ClearAnchors()
            travel.action3:SetAnchor(TOPLEFT, travel.right, TOPLEFT, servicesX + merchantW + serviceGap, servicesY)
            travel.action3:SetDimensions(storeW, 30)
            travel.action3:SetFont("ZoFontGameSmall")
            travel.action3:SetText("NEAREST GUILD STORE")
        end
        centerTravelButton(travel.stableTravelButton, 208, 444, 30, "ZoFontGameSmall")
        if travel.stableTravelButton then travel.stableTravelButton:SetText("NEAREST STABLEMASTER") end
        centerTravelButton(travel.pledgeMasterTravelButton, 242, 480, 30, "ZoFontGameSmall")
        if travel.pledgeMasterTravelButton then travel.pledgeMasterTravelButton:SetText("TRAVEL TO PLEDGE MASTER") end
    end

    local activity = self.pages.ACTIVITY
    if activity and activity.right and activity.interactive then
        activity.detailTitle:ClearAnchors()
        activity.detailTitle:SetAnchor(TOPLEFT, activity.right, TOPLEFT, 18, 54)
        activity.detailTitle:SetDimensions(self.pageW-36, 38)
        activity.detailBody:ClearAnchors()
        activity.detailBody:SetAnchor(TOPLEFT, activity.right, TOPLEFT, 18, 100)
        activity.detailBody:SetDimensions(self.pageW-36, 205)
        activity.sectionHistory02716 = easSectionLabel02716("EAS_ActivitySectionHistory02716", activity.right, "ACTIVITY HISTORY", 326, self.pageW-36)
        if activity.activityHistoryCategoryButtons2619 then
            -- v0.27.50: history category labels need more horizontal room.
            -- Use two columns and give ARCHIVE HISTORY a full-width row so no
            -- label is clipped, even with the uniform inset button borders.
            local gap = 8
            local w = math.floor((self.pageW - 36 - gap) / 2)
            for i,b in ipairs(activity.activityHistoryCategoryButtons2619) do
                b:ClearAnchors()
                b:SetFont("ZoFontGameSmall")
                if i <= 4 then
                    local col, row = (i-1)%2, math.floor((i-1)/2)
                    b:SetAnchor(TOPLEFT, activity.right, TOPLEFT, 18 + col*(w+gap), 347 + row*36)
                    b:SetDimensions(w, 31)
                else
                    b:SetAnchor(TOPLEFT, activity.right, TOPLEFT, 18, 419)
                    b:SetDimensions(self.pageW-36, 31)
                end
            end
        end
        if activity.activityHistoryButton2595 then
            activity.activityHistoryButton2595:ClearAnchors()
            activity.activityHistoryButton2595:SetAnchor(TOPLEFT, activity.right, TOPLEFT, 18, 456)
            activity.activityHistoryButton2595:SetDimensions(self.pageW-36, 30)
        end
        -- History pagination remains lower on the page when history mode is open.
        local nav = {activity.activityHistoryFirst2595, activity.activityHistoryPrev2595, activity.activityHistoryNext2595, activity.activityHistoryLast2595}
        local xs = {18, 84, self.pageW-146, self.pageW-80}
        for i,b in ipairs(nav) do if b then b:ClearAnchors(); b:SetAnchor(TOPLEFT, activity.right, TOPLEFT, xs[i], 525) end end
        if activity.activityHistoryPageLabel2595 then
            activity.activityHistoryPageLabel2595:ClearAnchors()
            activity.activityHistoryPageLabel2595:SetAnchor(TOPLEFT, activity.right, TOPLEFT, 150, 530)
        end
    end

    local skills = self.pages.SKILLS
    if skills and skills.leftBody and skills.rightBody then
        skills.leftBody:ClearAnchors()
        skills.leftBody:SetAnchor(TOPLEFT, skills.left, TOPLEFT, 18, 62)
        skills.leftBody:SetDimensions(self.pageW-36, self.pageH-202)
        skills.rightBody:ClearAnchors()
        skills.rightBody:SetAnchor(TOPLEFT, skills.right, TOPLEFT, 18, 62)
        skills.rightBody:SetDimensions(self.pageW-36, self.pageH-202)

        local leftY = self.pageH - 88
        local leftY2 = self.pageH - 56
        local rightY = self.pageH - 72
        local halfGap = 8
        local halfW = math.floor((self.pageW - 36 - halfGap) / 2)
        local fullW = self.pageW - 36
        local fontSmall = "ZoFontGameSmall"
        local fontBold = "ZoFontGameBold"

        for i,b in ipairs(skills.buttons or {}) do
            b:ClearAnchors()
            b:SetFont((i == 1 or i == 2 or i == 3) and fontSmall or fontBold)
            if i == 1 then
                b:SetAnchor(TOPLEFT, skills.left, TOPLEFT, 18, leftY)
                b:SetDimensions(halfW, 26)
            elseif i == 2 then
                b:SetAnchor(TOPLEFT, skills.left, TOPLEFT, 18 + halfW + halfGap, leftY)
                b:SetDimensions(halfW, 26)
            elseif i == 3 then
                b:SetAnchor(TOPLEFT, skills.left, TOPLEFT, 18, leftY2)
                b:SetDimensions(fullW, 24)
            elseif i == 4 then
                b:SetAnchor(TOPLEFT, skills.right, TOPLEFT, 18, rightY)
                b:SetDimensions(halfW, 26)
            elseif i == 5 then
                b:SetAnchor(TOPLEFT, skills.right, TOPLEFT, 18 + halfW + halfGap, rightY)
                b:SetDimensions(halfW, 26)
            end
        end
    end

    local achievements = self.pages.ACHIEVEMENTS
    if achievements and achievements.leftBody and achievements.rightBody then
        achievements.leftBody:ClearAnchors()
        achievements.leftBody:SetAnchor(TOPLEFT, achievements.left, TOPLEFT, 18, 50)
        achievements.leftBody:SetDimensions(self.pageW-36, self.pageH-64)
        achievements.rightBody:ClearAnchors()
        achievements.rightBody:SetAnchor(TOPLEFT, achievements.right, TOPLEFT, 18, 50)
        achievements.rightBody:SetDimensions(self.pageW-36, self.pageH-64)
        achievements.leftBody:SetFont(getAchievementsDocumentFont())
        achievements.rightBody:SetFont(getAchievementsDocumentFont())
    end

    local stats = self.pages.STATS
    if stats and stats.leftBody and stats.rightBody then
        stats.leftBody:ClearAnchors()
        stats.leftBody:SetAnchor(TOPLEFT, stats.left, TOPLEFT, 18, 50)
        stats.leftBody:SetDimensions(self.pageW-36, self.pageH-64)
        stats.rightBody:ClearAnchors()
        stats.rightBody:SetAnchor(TOPLEFT, stats.right, TOPLEFT, 18, 50)
        stats.rightBody:SetDimensions(self.pageW-36, self.pageH-64)
        stats.leftBody:SetFont(getStatsDocumentFont())
        stats.rightBody:SetFont(getStatsDocumentFont())
    end
end

local easCreateOrganized02716 = CreateImplArch
CreateImplArch = function(self)
    local result = easCreateOrganized02716(self)
    self:OrganizeDensePages02716()
    return result
end

function J:RefreshSkillsOrganized02716(page)
    if not page or not page.leftBody or not page.rightBody then return end
    local v = EPC.GearOptimizer and EPC.GearOptimizer.BuildBestAbilityView and EPC.GearOptimizer:BuildBestAbilityView() or {}
    local c = v.context or {}
    local font = "$(BOLD_FONT)|20|soft-shadow-thin"
    local respecDetailFont = "$(BOLD_FONT)|18|soft-shadow-thin"
    local lineH = 22
    local contentW = self.pageW - 40

    page.leftBody:SetText("")
    page.rightBody:SetText("")
    if page.leftBody.SetHidden then page.leftBody:SetHidden(false) end
    if page.rightBody.SetHidden then page.rightBody:SetHidden(false) end

    local function ensureLabel(field, name, parent, x, y, w, h, labelFont)
        local label = page[field]
        if not label then
            label = makeLabel(name, parent, "", x, y, w, h, labelFont or font)
            page[field] = label
            self.themeLabels[#self.themeLabels + 1] = label
        else
            label:ClearAnchors()
            label:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
            label:SetDimensions(w, h)
            label:SetFont(labelFont or font)
        end
        label:SetVerticalAlignment(TEXT_ALIGN_TOP)
        if label.SetHidden then label:SetHidden(false) end
        return label
    end

    local function syncLines(prefix, baseName, parent, x, startY, lines, width, labelFont)
        for i, line in ipairs(lines) do
            local field = prefix .. tostring(i)
            local name = baseName .. tostring(i)
            local label = ensureLabel(field, name, parent, x, startY + (i - 1) * lineH, width, lineH, labelFont or font)
            label:SetText(tostring(line or ""))
        end
        for i = #lines + 1, 24 do
            local label = page[prefix .. tostring(i)]
            if label then
                label:SetText("")
                if label.SetHidden then label:SetHidden(true) end
            end
        end
    end

    local buildTitleY = 58
    ensureLabel("buildOverviewTitle2845", "EAS_BuildOverviewTitle2845", page.left, 20, buildTitleY, contentW, 22, font):SetText("BUILD OVERVIEW")
    local buildLines = {
        string.format("Build: %s", tostring(c.profile and c.profile.label or "Detected build")),
        string.format("Role: %s", tostring(c.role or "DAMAGE")),
        string.format("Front: %s", tostring(c.frontWeapon or "Weapon")),
        string.format("Back: %s", tostring(c.backWeapon or "Weapon")),
    }
    if v.meta and EPC.SkillMeta then
        buildLines[#buildLines + 1] = string.format("Preset: %s", tostring(v.meta.preset or "TRIAL"))
        buildLines[#buildLines + 1] = string.format("Profile: %s", tostring(v.meta.label or "Current build"))
    end
    if #(c.sets or {}) > 0 then
        buildLines[#buildLines + 1] = "Sets:"
        for _, setName in ipairs(c.sets or {}) do
            buildLines[#buildLines + 1] = "- " .. tostring(setName)
        end
    end
    syncLines("buildOverviewLine2845_", "EAS_BuildOverviewLine2845_", page.left, 20, buildTitleY + 26, buildLines, contentW, font)

    local activeTitleY = buildTitleY + 26 + (#buildLines * lineH) + 18
    ensureLabel("activeBarTitle2845", "EAS_SkillsActiveBarTitle2845", page.left, 20, activeTitleY, contentW, 22, font):SetText(v.meta and "META - PRIMARY BAR" or "RECOMMENDED PRIMARY BAR")
    local activeLines = {}
    for i = 1, 5 do
        local a = v.abilities and v.abilities[i]
        activeLines[#activeLines + 1] = string.format("%d. %s", i, tostring(a and a.name or "Empty"))
    end
    activeLines[#activeLines + 1] = "ULT. " .. tostring(v.ultimate and v.ultimate.name or "No purchased ultimate")
    syncLines("activeBarLine2845_", "EAS_SkillsActiveBarLine2845_", page.left, 20, activeTitleY + 26, activeLines, contentW, font)

    local respecTitleY = activeTitleY + 26 + (#activeLines * lineH) + 12
    ensureLabel("respecTitle2845", "EAS_SkillsRespecTitle2845", page.left, 20, respecTitleY, contentW, 22, font):SetText("RESPEC + BUILD — MAX POWER")
    ensureLabel("respecLine12845", "EAS_SkillsRespecLine12845", page.left, 20, respecTitleY + 22, contentW, 22, respecDetailFont):SetText("Uses current class/role meta; falls back only when needed.")
    ensureLabel("respecLine22845", "EAS_SkillsRespecLine22845", page.left, 20, respecTitleY + 44, contentW, 22, respecDetailFont):SetText("Paid changes require confirmation.")

    local cpTitleY = 58
    ensureLabel("cpTitle2845", "EAS_SkillsCPTitle2845", page.right, 20, cpTitleY, contentW, 22, font):SetText("CHAMPION POINT OPTIMIZER")
    local cpLines = {}
    if EPC.ChampionOptimizer and EPC.ChampionOptimizer.BuildView then
        local cpv = EPC.ChampionOptimizer:BuildView() or {}
        cpLines[#cpLines + 1] = string.format("Redistribution: %d gold", tonumber(cpv.cost) or 0)
        for _, pool in ipairs(cpv.pools or {}) do
            cpLines[#cpLines + 1] = ""
            cpLines[#cpLines + 1] = string.format("%s %d/%d", tostring(pool.label or "POOL"), tonumber(pool.spent) or 0, tonumber(pool.budget) or 0)
            for i, star in ipairs(pool.top or {}) do
                if i > 2 then break end
                cpLines[#cpLines + 1] = string.format("- %s: %d%s", tostring(star.name or "Star"), tonumber(star.points) or 0, star.slottable and " [SLOT]" or "")
            end
        end
    else
        cpLines[#cpLines + 1] = "Champion optimizer unavailable."
    end
    syncLines("cpLine2845_", "EAS_SkillsCPLine2845_", page.right, 20, cpTitleY + 26, cpLines, contentW, font)

    local av = EPC.AttributeOptimizer and EPC.AttributeOptimizer.BuildView and EPC.AttributeOptimizer:BuildView() or nil
    local attrTitleY = cpTitleY + 26 + (#cpLines * lineH) + 12
    ensureLabel("attrTitle2845", "EAS_SkillsAttrTitle2845", page.right, 20, attrTitleY, contentW, 22, font):SetText("ATTRIBUTE OPTIMIZER")
    local attrLines = {}
    if av then
        attrLines[#attrLines + 1] = string.format("Detected: %s", tostring(av.role or "DAMAGE"))
        attrLines[#attrLines + 1] = string.format("Build: %s", tostring(av.build or "Current build"))
        attrLines[#attrLines + 1] = string.format("Current: %d H / %d M / %d S", tonumber(av.current and av.current.health) or 0, tonumber(av.current and av.current.magicka) or 0, tonumber(av.current and av.current.stamina) or 0)
        attrLines[#attrLines + 1] = string.format("Recommended: %d H / %d M / %d S", tonumber(av.target and av.target.health) or 0, tonumber(av.target and av.target.magicka) or 0, tonumber(av.target and av.target.stamina) or 0)
        attrLines[#attrLines + 1] = string.format("Redistribution: %d gold", tonumber(av.cost) or 0)
        attrLines[#attrLines + 1] = "Paid changes require confirmation."
    else
        attrLines[#attrLines + 1] = "Attribute optimizer unavailable."
    end
    syncLines("attrLine2845_", "EAS_SkillsAttrLine2845_", page.right, 20, attrTitleY + 26, attrLines, contentW, font)

    self:SetSuiteButtons("SKILLS", {"MAX POWER BUILD", "MAX POWER CP", "MAX POWER ATTRIBUTES"})
    local buttons = page.buttons or {}
    local gap = 8
    local halfW = math.floor((self.pageW - 40 - gap) / 2)
    if buttons[1] then
        buttons[1]:SetHidden(false)
        buttons[1]:ClearAnchors(); buttons[1]:SetAnchor(TOPLEFT, page.left, TOPLEFT, 20, self.pageH - 84); buttons[1]:SetDimensions(halfW, 28); buttons[1]:SetFont("ZoFontGameSmall")
    end
    if buttons[2] then
        buttons[2]:SetHidden(false)
        buttons[2]:ClearAnchors(); buttons[2]:SetAnchor(TOPLEFT, page.left, TOPLEFT, 20 + halfW + gap, self.pageH - 84); buttons[2]:SetDimensions(halfW, 28); buttons[2]:SetFont("ZoFontGameSmall")
    end
    if buttons[3] then
        buttons[3]:SetHidden(false)
        buttons[3]:ClearAnchors(); buttons[3]:SetAnchor(TOPLEFT, page.left, TOPLEFT, 20, self.pageH - 50); buttons[3]:SetDimensions(self.pageW - 40, 26); buttons[3]:SetFont("ZoFontGameSmall")
    end
    if buttons[4] then buttons[4]:SetHidden(true) end
    if buttons[5] then buttons[5]:SetHidden(true) end
end

local function easEstimateAchievementLines(text, maxChars)
    text = trim(text)
    if text == "" then return 0 end
    maxChars = math.max(18, tonumber(maxChars) or 38)
    local lines = 0
    for rawLine in string.gmatch(text .. "\n", "(.-)\n") do
        local line = trim(rawLine)
        if line == "" then
            lines = lines + 1
        else
            local current, wrapped = 0, 1
            for word in string.gmatch(line, "%S+") do
                local extra = (current > 0 and 1 or 0) + #word
                if current > 0 and current + extra > maxChars then
                    wrapped = wrapped + 1
                    current = #word
                else
                    current = current + extra
                end
            end
            lines = lines + math.max(1, wrapped)
        end
    end
    return lines
end

local function easGetRecentAchievementIds(count)
    count = tonumber(count) or 10
    local ids = { safe(GetRecentlyCompletedAchievements, nil, count) }
    if #ids == 0 then ids = { safe(GetRecentlyCompletedAchievements, nil) } end
    local out, seen = {}, {}
    for i = 1, #ids do
        local id = tonumber(ids[i]) or 0
        if id > 0 and not seen[id] then
            seen[id] = true
            out[#out+1] = id
        end
    end
    return out
end

local function easPadLowDensityText02838(text, targetLines)
    local lines = {}
    for rawLine in string.gmatch(tostring(text or "") .. "\n", "(.-)\n") do
        lines[#lines+1] = rawLine
    end
    targetLines = tonumber(targetLines) or 28
    while #lines < targetLines do
        lines[#lines+1] = ""
    end
    return table.concat(lines, "\n")
end

function J:RefreshAchievementsOrganized02716(page)
    if not page or not page.leftBody or not page.rightBody then return end
    local earned = tonumber(safe(GetEarnedAchievementPoints, 0)) or 0
    local total = tonumber(safe(GetTotalAchievementPoints, 0)) or 0
    local ids = easGetRecentAchievementIds(10)
    local entries = {}
    for i = 1, #ids do
        local id = tonumber(ids[i]) or 0
        if id > 0 and type(GetAchievementInfo) == "function" then
            local name, description, points, _, completed = safe(GetAchievementInfo, "", id)
            name = trim(name)
            if name ~= "" then
                local entry = {
                    name = name,
                    description = trim(description),
                    points = tonumber(points) or 0,
                    completed = completed == true,
                }
                local title = string.format("%s%s", entry.name, entry.points > 0 and string.format("  (%d pts)", entry.points) or "")
                entry._estimatedLines = easEstimateAchievementLines(title, 29) + easEstimateAchievementLines(entry.description, 33) + 3
                entries[#entries+1] = entry
            end
        end
    end

    local left = {"PROGRESS", "", string.format("Achievement Points: %d / %d", earned, total), "", "RECENT COMPLETIONS"}
    local right = {"MORE RECENT COMPLETIONS"}
    if #entries == 0 then
        left[#left+1] = ""
        left[#left+1] = "Recent achievement details are not currently exposed by ESO."
        right[#right+1] = ""
        right[#right+1] = "Complete achievements to populate this page."
    else
        local totalWeight = 0
        for _, e in ipairs(entries) do totalWeight = totalWeight + (e._estimatedLines or 4) end
        local targetLeft = math.floor(totalWeight / 2)
        local leftWeight, split = 0, 0
        for i, e in ipairs(entries) do
            local remaining = #entries - i
            local weight = e._estimatedLines or 4
            local minimumRight = 2
            if i == 1 or (leftWeight + weight <= targetLeft or remaining >= minimumRight) then
                split = i
                leftWeight = leftWeight + weight
            else
                break
            end
        end
        if split < 1 then split = math.max(1, math.floor(#entries / 2)) end
        if split >= #entries then split = math.max(1, #entries - 1) end

        local leftCount = split
        local rightCount = #entries - split
        local leftSpacer = (#entries <= 8 and leftCount <= 4) and 2 or 1
        local rightSpacer = (#entries <= 8 and rightCount <= 4) and 2 or 1

        local function appendEntry(target, index, entry, extraSpacer)
            target[#target+1] = ""
            target[#target+1] = string.format("%d. %s%s", index, entry.name, entry.points > 0 and string.format("  (%d pts)", entry.points) or "")
            if entry.description ~= "" then
                target[#target+1] = entry.description
            end
            for _ = 1, extraSpacer do target[#target+1] = "" end
        end

        for i, e in ipairs(entries) do
            if i <= split then
                appendEntry(left, i, e, leftSpacer)
            else
                appendEntry(right, i, e, rightSpacer)
            end
        end
    end
    local font = getAchievementsDocumentFont()
    page.leftBody:SetFont(font)
    page.rightBody:SetFont(font)
    page.leftBody:ClearAnchors()
    page.leftBody:SetAnchor(TOPLEFT, page.left, TOPLEFT, 20, 48)
    page.leftBody:SetDimensions(self.pageW-40, self.pageH-58)
    page.rightBody:ClearAnchors()
    page.rightBody:SetAnchor(TOPLEFT, page.right, TOPLEFT, 20, 48)
    page.rightBody:SetDimensions(self.pageW-40, self.pageH-58)
    setBookText(page.leftBody, easPadLowDensityText02838(table.concat(left, "\n"), 30), page.leftBody:GetWidth())
    setBookText(page.rightBody, easPadLowDensityText02838(table.concat(right, "\n"), 30), page.rightBody:GetWidth())
end


local function easSpaceStatsText02836(text)
    text = tostring(text or "")
    local sections = {
        "CHARACTER OVERVIEW", "INVENTORY & WEALTH", "RIDING TRAINING",
        "GOLD SPENDING", "TOTAL TRACKED", "CRAFTING & EQUIPMENT",
        "SUPPLIES & SERVICES", "MARKET, TRAVEL & OTHER",
    }
    for _, heading in ipairs(sections) do
        text = text:gsub(heading .. "\n", heading .. "\n\n")
    end
    -- Keep deliberate section breathing room; do not compress it back down.
    text = text:gsub("\n\n\n\n+", "\n\n\n")
    return text
end

function J:RefreshStatsReadable02836(page)
    if not page or not page.leftBody or not page.rightBody then return end
    local left, right = self:BuildStatsSpread()
    local font = getStatsDocumentFont()
    page.leftBody:SetFont(font)
    page.rightBody:SetFont(font)
    page.leftBody:ClearAnchors()
    page.leftBody:SetAnchor(TOPLEFT, page.left, TOPLEFT, 20, 50)
    page.leftBody:SetDimensions(self.pageW-40, self.pageH-62)
    page.rightBody:ClearAnchors()
    page.rightBody:SetAnchor(TOPLEFT, page.right, TOPLEFT, 20, 50)
    page.rightBody:SetDimensions(self.pageW-40, self.pageH-62)
    setBookText(page.leftBody, easSpaceStatsText02836(left), page.leftBody:GetWidth())
    setBookText(page.rightBody, easSpaceStatsText02836(right), page.rightBody:GetWidth())
end

local easRefreshDocumentOrganized02716 = RefreshDocumentPageImplArch
RefreshDocumentPageImplArch = function(self)
    if self.activeTab == "ACHIEVEMENTS" then
        local page = self.pages and self.pages.ACHIEVEMENTS
        if page then self:RefreshAchievementsOrganized02716(page); return end
    elseif self.activeTab == "STATS" then
        local page = self.pages and self.pages.STATS
        if page then self:RefreshStatsReadable02836(page); return end
    end
    return easRefreshDocumentOrganized02716(self)
end

-- ============================================================================
-- v0.27.67 - Dungeon Finder multi-select presentation
-- Selected rows stay visibly checked while paging so a player can build a
-- specific queue containing one, three, or any desired set of dungeons.
-- ============================================================================
local easLegacyRefreshInteractiveDungeons2767 = RefreshInteractiveDungeonsImplArch
RefreshInteractiveDungeonsImplArch = function(self, page)
    easLegacyRefreshInteractiveDungeons2767(self, page)
    if not page or self.dungeonHistoryMode2583 == true then return end
    local D = EPC.DungeonFinder
    if not D or tostring(D.viewMode or "DUNGEONS") ~= "DUNGEONS" then return end

    local v = D:BuildView()
    local selectedCount = D.GetMultiSelectedCount and D:GetMultiSelectedCount() or 0

    for i, rowControl in ipairs(page.rows or {}) do
        local entry = v.rows and v.rows[i]
        if entry and rowControl and rowControl.titleLabel then
            local checked = D.IsEntrySelected and D:IsEntrySelected(entry)
            rowControl.titleLabel:SetText((checked and "[X] " or "[ ] ") .. tostring(entry.name or "Dungeon"))
            easSetInk(rowControl.titleLabel, checked, false)
            if rowControl.detailLabel then easSetInk(rowControl.detailLabel, checked, true) end
        end
    end

    if page.pageLabel and not v.scanning then
        page.pageLabel:SetText(string.format("PAGE %d / %d  -  %d DUNGEONS  -  %d SELECTED", tonumber(v.page) or 1, tonumber(v.pageCount) or 1, tonumber(v.total) or 0, selectedCount))
    end

    if page.action0 then
        local effectiveCount = selectedCount
        if effectiveCount == 0 and D:GetSelected() then effectiveCount = 1 end
        page.action0:SetText(v.queued and "ALREADY QUEUED" or (effectiveCount > 1 and ("QUEUE " .. tostring(effectiveCount) .. " SELECTED") or "QUEUE SELECTED"))
        page.action0:SetHidden(effectiveCount == 0)
        easSetEnabled(page.action0, effectiveCount > 0 and not v.queued)
    end

    if page.detailBody and D:GetSelected() then
        local focused = D:GetSelected()
        local checked = D.IsEntrySelected and D:IsEntrySelected(focused)
        local prefix = string.format("QUEUE SELECTION\n%s  -  %d dungeon%s selected\n\n", checked and "SELECTED" or "NOT SELECTED", selectedCount, selectedCount == 1 and "" or "s")
        local currentText = page.detailBody:GetText() or ""
        if not currentText:find("^QUEUE SELECTION") then
            setBookText(page.detailBody, prefix .. currentText, page.detailBody:GetWidth())
        end
    elseif page.detailBody and selectedCount > 0 then
        setBookText(page.detailBody, string.format("%d dungeons selected. Click any dungeon row to add or remove it from your specific queue. Then press QUEUE SELECTED.", selectedCount), page.detailBody:GetWidth())
    end
end


-- ============================================================================
-- v0.28.76 - Dedicated Battleground Finder chapter + queue-type aware HUD
-- ============================================================================
function J:RefreshInteractiveBattlegrounds02876(page)
    local B = EPC.BattlegroundFinder
    if not page or not B then return end
    local v = B:BuildView(false)

    -- Top controls: available/all filter and manual refresh.
    local labels = {"AVAILABLE", "ALL", "REFRESH", ""}
    for i = 1, 4 do
        local control = page.controls[i]
        if control then
            control:SetText(labels[i])
            control:SetHidden(i == 4)
            if i == 1 then setButtonStyle(control, v.showLocked ~= true, self:GetTheme())
            elseif i == 2 then setButtonStyle(control, v.showLocked == true, self:GetTheme())
            else setButtonStyle(control, false, self:GetTheme()) end
        end
    end

    page.secondary[1]:SetText("< PREV")
    page.secondary[2]:SetText("NEXT >")
    page.secondary[1]:SetHidden(false)
    page.secondary[2]:SetHidden(false)
    page.secondary[3]:SetHidden(true)
    page.secondary[4]:SetHidden(true)
    setButtonStyle(page.secondary[1], false, self:GetTheme())
    setButtonStyle(page.secondary[2], false, self:GetTheme())

    local selected = v.selected
    local selectedId = selected and selected.id or nil
    for i, rowControl in ipairs(page.rows or {}) do
        local row = v.rows and v.rows[i]
        if row then
            rowControl:SetHidden(false)
            rowControl.titleLabel:SetText(tostring(row.name or "Battleground"))
            rowControl.detailLabel:SetText(tostring(row.detail or ""))
            local isSelected = selectedId ~= nil and row.id == selectedId
            easSetInk(rowControl.titleLabel, isSelected, row.locked == true)
            easSetInk(rowControl.detailLabel, isSelected, true)
        else
            rowControl:SetHidden(true)
        end
    end

    page.pageLabel:SetText(string.format("PAGE %d / %d  -  %d BATTLEGROUND QUEUES", tonumber(v.page) or 1, tonumber(v.pageCount) or 1, tonumber(v.total) or 0))

    if selected then
        page.detailTitle:SetText(tostring(selected.name or "BATTLEGROUND"))
        local state = selected.locked and "LOCKED" or "READY"
        local groupSize = selected.minGroupSize == selected.maxGroupSize and tostring(selected.maxGroupSize)
            or string.format("%d-%d", tonumber(selected.minGroupSize) or 1, tonumber(selected.maxGroupSize) or 1)
        local reward = selected.dailyReady and "DAILY BONUS READY" or "STANDARD REWARD"
        local solo = selected.soloBonus and "AVAILABLE" or "N/A"
        local detail = string.format("STATUS\n%s\n\nGROUP / TEAM SIZE\n%s\n\nREWARD\n%s\n\nSOLO BONUS\n%s",
            state, groupSize, reward, solo)
        if selected.locked and selected.lockReason and selected.lockReason ~= "" then
            detail = detail .. "\n\nLOCK REASON\n" .. tostring(selected.lockReason)
        end
        if selected.description and selected.description ~= "" then
            detail = detail .. "\n\n" .. tostring(selected.description)
        end
        setBookText(page.detailBody, detail, page.detailBody:GetWidth())
    else
        page.detailTitle:SetText("BATTLEGROUND FINDER")
        setBookText(page.detailBody, tostring(v.hint or "No Battleground queues are available right now."), page.detailBody:GetWidth())
    end

    page.action0:SetText(v.queued and "ALREADY QUEUED" or "QUEUE SELECTED")
    page.action1:SetText("CANCEL QUEUE")
    page.action2:SetText("REFRESH")
    page.action3:SetHidden(true)
    page.action0:SetHidden(false)
    page.action1:SetHidden(false)
    page.action2:SetHidden(false)
    setButtonStyle(page.action0, false, self:GetTheme())
    setButtonStyle(page.action1, false, self:GetTheme())
    setButtonStyle(page.action2, false, self:GetTheme())
    easSetEnabled(page.action0, selected ~= nil and not selected.locked and not v.queued)
    easSetEnabled(page.action1, v.queued == true)
    easSetEnabled(page.action2, true)
end

local easRefreshSuitePage02876 = RefreshSuitePageImplArch
RefreshSuitePageImplArch = function(self, tab)
    tab = tab or self.activeTab
    if tab == "BATTLEGROUNDS" then
        local page = self.pages and self.pages.BATTLEGROUNDS
        if page then self:RefreshInteractiveBattlegrounds02876(page) end
        return
    end
    return easRefreshSuitePage02876(self, tab)
end

local easRunInteractiveControl02876 = RunInteractiveControlImplArch
RunInteractiveControlImplArch = function(self, tab, index)
    if tab == "BATTLEGROUNDS" and EPC.BattlegroundFinder then
        if index == 1 then EPC.BattlegroundFinder:SetShowLocked(false)
        elseif index == 2 then EPC.BattlegroundFinder:SetShowLocked(true)
        elseif index == 3 then EPC.BattlegroundFinder:BuildLocations(true) end
        self:RefreshSuitePage(tab)
        return
    end
    return easRunInteractiveControl02876(self, tab, index)
end

local easRunInteractiveSecondary02876 = RunInteractiveSecondaryImplArch
RunInteractiveSecondaryImplArch = function(self, tab, index)
    if tab == "BATTLEGROUNDS" and EPC.BattlegroundFinder then
        if index == 1 then EPC.BattlegroundFinder:ChangePage(-1)
        elseif index == 2 then EPC.BattlegroundFinder:ChangePage(1) end
        self:RefreshSuitePage(tab)
        return
    end
    return easRunInteractiveSecondary02876(self, tab, index)
end

local easSelectInteractiveRow02876 = SelectInteractiveRowImplArch
SelectInteractiveRowImplArch = function(self, tab, index)
    if tab == "BATTLEGROUNDS" and EPC.BattlegroundFinder then
        EPC.BattlegroundFinder:SelectRow(index)
        self:RefreshSuitePage(tab)
        return
    end
    return easSelectInteractiveRow02876(self, tab, index)
end

local easRunInteractiveGearOptimizer02876 = RunInteractiveGearOptimizerImplArch
RunInteractiveGearOptimizerImplArch = function(self, tab)
    if tab == "BATTLEGROUNDS" and EPC.BattlegroundFinder then
        EPC.BattlegroundFinder:QueueSelected()
        self:RefreshSuitePage(tab)
        return
    end
    return easRunInteractiveGearOptimizer02876(self, tab)
end

local easRunInteractivePrimary02876 = RunInteractivePrimaryImplArch
RunInteractivePrimaryImplArch = function(self, tab)
    if tab == "BATTLEGROUNDS" and EPC.BattlegroundFinder then
        EPC.BattlegroundFinder:CancelQueue()
        self:RefreshSuitePage(tab)
        return
    end
    return easRunInteractivePrimary02876(self, tab)
end

local easRunInteractiveSecondaryAction02876 = RunInteractiveSecondaryActionImplArch
RunInteractiveSecondaryActionImplArch = function(self, tab)
    if tab == "BATTLEGROUNDS" and EPC.BattlegroundFinder then
        EPC.BattlegroundFinder:BuildLocations(true)
        self:RefreshSuitePage(tab)
        return
    end
    return easRunInteractiveSecondaryAction02876(self, tab)
end

local easSelectTab02876 = SelectTabImplArch
SelectTabImplArch = function(self, tab, ...)
    local result = easSelectTab02876(self, tab, ...)
    if tab == "BATTLEGROUNDS" and EPC.BattlegroundFinder then
        EPC.BattlegroundFinder:BuildLocations(true)
        self:RefreshSuitePage("BATTLEGROUNDS")
    end
    return result
end


-- ============================================================================
-- v0.28.77 - Suite 2027 full Codex visual system
-- A presentation-only redesign. Feature/data logic is intentionally untouched.
-- The complete Codex now shares one Suite-inspired command-center language:
-- layered dark surfaces, subtle borders, cyan/accent focus, compact navigation,
-- modern list/action controls, consistent editors, and responsive Dice & Coin.
-- ============================================================================

local EAS_2027 = {
    canvas = {0.011, 0.016, 0.024, 0.985},
    topbar = {0.020, 0.028, 0.040, 0.985},
    sidebar = {0.016, 0.023, 0.034, 0.980},
    surface = {0.030, 0.040, 0.056, 0.965},
    surface2 = {0.042, 0.054, 0.073, 0.950},
    hover = {0.075, 0.098, 0.132, 0.975},
    border = {0.20, 0.28, 0.38, 0.72},
    borderSoft = {0.16, 0.22, 0.30, 0.52},
    text = {0.94, 0.965, 0.995, 1},
    muted = {0.62, 0.69, 0.78, 1},
    faint = {0.43, 0.50, 0.60, 1},
}

local function easAccent02877(theme)
    local t = type(theme) == "table" and theme or (J.GetTheme and J:GetTheme()) or {}
    local a = type(t.accent) == "table" and t.accent or {0.18, 0.72, 0.92, 1}
    return tonumber(a[1]) or 0.18, tonumber(a[2]) or 0.72, tonumber(a[3]) or 0.92
end

local function easSetSolid02877(control, color, alpha)
    if not control then return end
    if control.SetEdgeTexture then control:SetEdgeTexture(nil, 1, 1, 1) end
    if control.SetCenterColor then control:SetCenterColor(color[1], color[2], color[3], alpha or color[4] or 1) end
    if control.SetEdgeColor then control:SetEdgeColor(0, 0, 0, 0) end
end

local function easEnsureButtonChrome02877(button)
    if not button or button._easModernChrome02877 then return end
    button._easModernChrome02877 = true
    local name = button.GetName and tostring(button:GetName() or "") or ""
    if string.find(name, "EAS_GlassNav_", 1, true) then return end
    if button.bg then return end
    -- Shared makeButton controls already own a background and four border strips.
    -- Reuse those controls so the redesign never stacks a second frame on top.
    if button._easBorder and button._easBorderLines then return end

    local bg = wm:CreateControl(name .. "_ModernBG02877", button, CT_BACKDROP)
    bg:SetAnchor(TOPLEFT, button, TOPLEFT, 1, 1)
    bg:SetAnchor(BOTTOMRIGHT, button, BOTTOMRIGHT, -1, -1)
    if bg.SetDrawLayer then bg:SetDrawLayer(DL_BACKGROUND) end
    if bg.SetDrawLevel then bg:SetDrawLevel(0) end
    bg:SetEdgeTexture(nil, 1, 1, 1)
    bg:SetCenterColor(EAS_2027.surface2[1], EAS_2027.surface2[2], EAS_2027.surface2[3], 0.78)
    bg:SetEdgeColor(0,0,0,0)
    button._easBorder = bg

    local function line(suffix)
        local l = wm:CreateControl(name .. "_ModernBorder02877_" .. suffix, button, CT_BACKDROP)
        if l.SetDrawLayer then l:SetDrawLayer(DL_CONTROLS) end
        if l.SetDrawLevel then l:SetDrawLevel(1) end
        l:SetCenterColor(EAS_2027.border[1], EAS_2027.border[2], EAS_2027.border[3], 0.56)
        l:SetEdgeColor(0,0,0,0)
        return l
    end
    local top = line("T")
    top:SetAnchor(TOPLEFT, button, TOPLEFT, 1, 1)
    top:SetAnchor(TOPRIGHT, button, TOPRIGHT, -1, 1)
    top:SetHeight(1)
    local bottom = line("B")
    bottom:SetAnchor(BOTTOMLEFT, button, BOTTOMLEFT, 1, -1)
    bottom:SetAnchor(BOTTOMRIGHT, button, BOTTOMRIGHT, -1, -1)
    bottom:SetHeight(1)
    local left = line("L")
    left:SetAnchor(TOPLEFT, button, TOPLEFT, 1, 1)
    left:SetAnchor(BOTTOMLEFT, button, BOTTOMLEFT, 1, -1)
    left:SetWidth(1)
    local right = line("R")
    right:SetAnchor(TOPRIGHT, button, TOPRIGHT, -1, 1)
    right:SetAnchor(BOTTOMRIGHT, button, BOTTOMRIGHT, -1, -1)
    right:SetWidth(1)
    button._easBorderLines = {top, bottom, left, right}
end

local function easPaintButton02877(button, selected, theme, hovered)
    if not button then return end
    easEnsureButtonChrome02877(button)
    local ar, ag, ab = easAccent02877(theme)
    button._easSelected02877 = selected == true
    button._easTheme02877 = theme

    if button.SetNormalFontColor then
        if selected then button:SetNormalFontColor(EAS_2027.text[1], EAS_2027.text[2], EAS_2027.text[3], 1)
        else button:SetNormalFontColor(EAS_2027.text[1], EAS_2027.text[2], EAS_2027.text[3], 0.93) end
        button:SetMouseOverFontColor(1,1,1,1)
        button:SetPressedFontColor(ar,ag,ab,1)
    end

    local bg = button._easBorder or button.bg
    if bg and bg.SetCenterColor then
        if selected then bg:SetCenterColor(ar,ag,ab,0.16)
        elseif hovered then bg:SetCenterColor(EAS_2027.hover[1],EAS_2027.hover[2],EAS_2027.hover[3],0.94)
        else bg:SetCenterColor(EAS_2027.surface2[1],EAS_2027.surface2[2],EAS_2027.surface2[3],0.76) end
        if bg.SetEdgeColor then bg:SetEdgeColor(0,0,0,0) end
    end

    if button._easBorderLines then
        local r,g,b,a
        if selected then r,g,b,a = ar,ag,ab,0.94
        elseif hovered then r,g,b,a = ar,ag,ab,0.62
        else r,g,b,a = EAS_2027.border[1],EAS_2027.border[2],EAS_2027.border[3],0.58 end
        for _, l in ipairs(button._easBorderLines) do
            if l and l.SetCenterColor then l:SetCenterColor(r,g,b,a) end
        end
    end
end

-- Replaces the shared visual style used by every existing Codex action.
setButtonStyle = function(button, selected, theme)
    easPaintButton02877(button, selected, theme, button and button._easHover02877 == true)
end

local easMakeButtonPre02877 = makeButton
makeButton = function(name, parent, text, x, y, w, h, handler)
    local b = easMakeButtonPre02877(name, parent, text, x, y, w, h, handler)
    easPaintButton02877(b, false, J:GetTheme(), false)
    if b and not b._easHoverHandlers02877 then
        b._easHoverHandlers02877 = true
        b:SetHandler("OnMouseEnter", function(control)
            control._easHover02877 = true
            easPaintButton02877(control, control._easSelected02877, control._easTheme02877 or J:GetTheme(), true)
        end)
        b:SetHandler("OnMouseExit", function(control)
            control._easHover02877 = false
            easPaintButton02877(control, control._easSelected02877, control._easTheme02877 or J:GetTheme(), false)
        end)
    end
    return b
end

local easMakePanelPre02877 = makePanel
makePanel = function(name, parent, x, y, w, h)
    local p = easMakePanelPre02877(name, parent, x, y, w, h)
    if p then
        p:SetEdgeTexture(nil,1,1,1)
        p:SetCenterColor(EAS_2027.surface2[1], EAS_2027.surface2[2], EAS_2027.surface2[3], 0.88)
        p:SetEdgeColor(EAS_2027.border[1], EAS_2027.border[2], EAS_2027.border[3], 0.56)
    end
    return p
end

local easStyleIconButtonPre02877 = styleIconButton
styleIconButton = function(button, theme)
    if not button then return end
    local ar,ag,ab = easAccent02877(theme)
    if button.bg then
        button.bg:SetCenterColor(EAS_2027.surface2[1],EAS_2027.surface2[2],EAS_2027.surface2[3],0.86)
        button.bg:SetEdgeColor(EAS_2027.border[1],EAS_2027.border[2],EAS_2027.border[3],0.60)
    end
    if button.label then button.label:SetColor(EAS_2027.text[1],EAS_2027.text[2],EAS_2027.text[3],1) end
    button._theme = theme
    if not button._easHoverHandlers02877 then
        button._easHoverHandlers02877 = true
        button:SetHandler("OnMouseEnter", function(control)
            if control.bg then
                control.bg:SetCenterColor(EAS_2027.hover[1],EAS_2027.hover[2],EAS_2027.hover[3],0.98)
                control.bg:SetEdgeColor(ar,ag,ab,0.78)
            end
        end)
        button:SetHandler("OnMouseExit", function(control)
            if control.bg then
                control.bg:SetCenterColor(EAS_2027.surface2[1],EAS_2027.surface2[2],EAS_2027.surface2[3],0.86)
                control.bg:SetEdgeColor(EAS_2027.border[1],EAS_2027.border[2],EAS_2027.border[3],0.60)
            end
        end)
    end
end

local easCreateEditBoxPre02877 = CreateEditBoxImplArch
CreateEditBoxImplArch = function(self, name, parent, x, y, w, h, multiLine)
    local e = easCreateEditBoxPre02877(self, name, parent, x, y, w, h, multiLine)
    if e then
        e:SetColor(EAS_2027.text[1], EAS_2027.text[2], EAS_2027.text[3], 1)
        if not e._easInputBG02877 then
            local bg = wm:CreateControl(name .. "_ModernInputBG02877", e, CT_BACKDROP)
            bg:SetAnchorFill(e)
            if bg.SetDrawLayer then bg:SetDrawLayer(DL_BACKGROUND) end
            if bg.SetDrawLevel then bg:SetDrawLevel(0) end
            bg:SetEdgeTexture(nil,1,1,1)
            bg:SetCenterColor(EAS_2027.surface2[1],EAS_2027.surface2[2],EAS_2027.surface2[3],0.82)
            bg:SetEdgeColor(EAS_2027.border[1],EAS_2027.border[2],EAS_2027.border[3],0.64)
            e._easInputBG02877 = bg
        end
    end
    return e
end

-- Interactive enabled/selected states also use the modern palette instead of\n-- restoring the legacy all-cyan frame on every refresh.\neasSetEnabled = function(control, enabled)\n    if not control then return end\n    local active = enabled == true\n    if control.SetEnabled then control:SetEnabled(active) end\n    if control.SetAlpha then control:SetAlpha(active and 1 or 0.42) end\n    if active then\n        easPaintButton02877(control, control._easSelected02877 == true, J:GetTheme(), false)\n    else\n        easEnsureButtonChrome02877(control)\n        if control._easBorder and control._easBorder.SetCenterColor then\n            control._easBorder:SetCenterColor(0.020,0.026,0.036,0.58)\n        end\n        if control._easBorderLines then\n            for _,line in ipairs(control._easBorderLines) do\n                if line and line.SetCenterColor then line:SetCenterColor(0.14,0.19,0.26,0.38) end\n            end\n        end\n    end\nend\n\neasSetInk = function(label, selected, muted)\n    if not label or not label.SetColor then return end\n    local ar,ag,ab = easAccent02877(J:GetTheme())\n    if selected then label:SetColor(ar,ag,ab,1)\n    elseif muted then label:SetColor(EAS_2027.muted[1],EAS_2027.muted[2],EAS_2027.muted[3],0.90)\n    else label:SetColor(EAS_2027.text[1],EAS_2027.text[2],EAS_2027.text[3],0.96) end\nend\n\n-- Every chapter receives the same master/detail surface system.\nlocal easCreateSpreadShellPre02877 = CreateSpreadShellImplArch
CreateSpreadShellImplArch = function(self, name)
    local spread = easCreateSpreadShellPre02877(self, name)
    if spread and self.glassMode then
        local function surface(control, suffix)
            local bg = wm:CreateControl("EAS_ModernSurface02877_"..tostring(name)..suffix, control, CT_BACKDROP)
            bg:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
            bg:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 0, 0)
            if bg.SetDrawLayer then bg:SetDrawLayer(DL_BACKGROUND) end
            if bg.SetDrawLevel then bg:SetDrawLevel(0) end
            bg:SetEdgeTexture(nil,1,1,1)
            bg:SetCenterColor(EAS_2027.surface[1],EAS_2027.surface[2],EAS_2027.surface[3],0.52)
            bg:SetEdgeColor(EAS_2027.borderSoft[1],EAS_2027.borderSoft[2],EAS_2027.borderSoft[3],0.38)
            return bg
        end
        spread.leftSurface02877 = surface(spread.left, "L")
        spread.rightSurface02877 = surface(spread.right, "R")
    end
    return spread
end

-- Modern chapter heading treatment shared by every page.
AddSpreadHeaderImplArch = function(self, spread, leftTitle, rightTitle)
    local key = tostring(spread.key or leftTitle or "Spread"):gsub("%W", "")
    local lt = makeLabel("EAS_Codex_"..key.."_LeftTitle", spread.left, leftTitle or "", 16, 9, self.pageW-32, 28, "ZoFontWinH2")
    lt:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    local rt = makeLabel("EAS_Codex_"..key.."_RightTitle", spread.right, rightTitle or leftTitle or "", 16, 9, self.pageW-32, 28, "ZoFontWinH2")
    rt:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

    local function rule(name, parent)
        local r = wm:CreateControl(name, parent, CT_BACKDROP)
        r:SetAnchor(TOPLEFT, parent, TOPLEFT, 16, 42)
        r:SetDimensions(self.pageW-32, 1)
        r:SetCenterColor(0.18,0.72,0.92,0.62)
        r:SetEdgeColor(0,0,0,0)
        return r
    end
    spread.headerRuleLeft02877 = rule("EAS_CodexModernRuleL02877_"..key, spread.left)
    spread.headerRuleRight02877 = rule("EAS_CodexModernRuleR02877_"..key, spread.right)
    self.themeLabels[#self.themeLabels+1] = lt
    self.themeLabels[#self.themeLabels+1] = rt
    spread.leftTitle, spread.rightTitle = lt, rt
end

-- Dice & Coin is rebuilt as a compact 4x2 launcher so it cannot run outside
-- the page at any supported Codex size/scale.
CreateDiceSpreadImplArch = function(self)
    local spread = self:CreateSpreadShell("DICE")
    self:AddSpreadHeader(spread, "DICE & COIN", "RESULT & HISTORY")

    local intro = makeLabel("EAS_CodexDiceIntro", spread.left,
        "Fast roleplay rolls, loot calls, encounter checks, and coin tosses.",
        16, 54, self.pageW-32, 44, "ZoFontGame")
    self.themeLabels[#self.themeLabels+1] = intro
    setBookText(intro, intro:GetText(), intro:GetWidth())

    self.iconButtons = self.iconButtons or {}
    local gap = 8
    local cols = 4
    local tileW = math.floor((self.pageW - 32 - gap * (cols - 1)) / cols)
    local tileH = 78
    local choices = {
        {kind="DICE", sides=4, label="D4"}, {kind="DICE", sides=6, label="D6"},
        {kind="DICE", sides=8, label="D8"}, {kind="DICE", sides=10, label="D10"},
        {kind="DICE", sides=12, label="D12"}, {kind="DICE", sides=20, label="D20"},
        {kind="DICE", sides=100, label="D100"}, {kind="COIN", label="COIN"},
    }
    for i, item in ipairs(choices) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local x = 16 + col * (tileW + gap)
        local y = 108 + row * (tileH + 10)
        local texture = item.kind == "COIN" and getChanceTexture("COIN") or getChanceTexture("DICE", item.sides)
        local handler
        if item.kind == "COIN" then handler = function() self:TossCoin() end
        else local sides = item.sides handler = function() self:Roll(sides) end end
        local btn = makeIconButton("EAS_CodexChance02877_"..tostring(i), spread.left, texture, item.label, x, y, tileW, tileH, handler)
        self.iconButtons[#self.iconButtons+1] = btn
    end

    local hint = makeLabel("EAS_CodexDiceHint", spread.left,
        "Your latest result and recent history stay visible on the right.",
        16, 300, self.pageW-32, 42, "ZoFontGameSmall")
    self.themeLabels[#self.themeLabels+1] = hint
    setBookText(hint, hint:GetText(), hint:GetWidth())

    self.diceResultPanel = makePanel("EAS_CodexDiceResultPanel", spread.right, 16, 58, self.pageW-32, 212)
    self.diceResultTitle = makeLabel("EAS_CodexDiceResultTitle", self.diceResultPanel, "LUCK OF THE DRAW", 14, 12, self.diceResultPanel:GetWidth()-28, 26, "ZoFontWinH2")
    self.diceResultTitle:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    self.themeLabels[#self.themeLabels+1] = self.diceResultTitle

    self.diceResultIcon = wm:CreateControl("EAS_CodexDiceResultIcon", self.diceResultPanel, CT_TEXTURE)
    self.diceResultIcon:SetDimensions(68,68)
    self.diceResultIcon:SetAnchor(TOPLEFT, self.diceResultPanel, TOPLEFT, 18, 50)
    self.diceResultIcon:SetTexture(getChanceTexture("DICE",20))

    self.diceResultValue = makeLabel("EAS_CodexDiceResultValue", self.diceResultPanel, "READY", 104, 52, self.diceResultPanel:GetWidth()-122, 42, "ZoFontWinH1")
    self.diceResultValue:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    self.diceResultValue:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.diceResultSub = makeLabel("EAS_CodexDiceResultSub", self.diceResultPanel,
        "Choose a die or toss the coin.", 104, 98, self.diceResultPanel:GetWidth()-122, 72, "ZoFontGame")
    self.diceResultSub:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    self.diceResultSub:SetVerticalAlignment(TEXT_ALIGN_TOP)
    self.themeLabels[#self.themeLabels+1] = self.diceResultSub
    setBookText(self.diceResultSub, self.diceResultSub:GetText(), self.diceResultSub:GetWidth())

    local historyTitle = makeLabel("EAS_CodexDiceHistoryTitle", spread.right, "RECENT ROLLS", 16, 294, self.pageW-32, 22, "ZoFontGameBold")
    historyTitle:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    self.themeLabels[#self.themeLabels+1] = historyTitle
    self.diceHistoryOutput = makeLabel("EAS_CodexDiceHistoryOutput", spread.right, "Choose a die or toss a coin.", 16, 328, self.pageW-32, self.pageH-350, "ZoFontGame")
    self.themeLabels[#self.themeLabels+1] = self.diceHistoryOutput
    self.diceOutput = self.diceHistoryOutput
    self:RefreshDice()
    return spread
end

local function easStyleInput02877(edit, name)
    if not edit or edit._easInputBG02877 then return end
    local bg = wm:CreateControl(name, edit, CT_BACKDROP)
    bg:SetAnchorFill(edit)
    if bg.SetDrawLayer then bg:SetDrawLayer(DL_BACKGROUND) end
    bg:SetEdgeTexture(nil,1,1,1)
    bg:SetCenterColor(EAS_2027.surface2[1],EAS_2027.surface2[2],EAS_2027.surface2[3],0.82)
    bg:SetEdgeColor(EAS_2027.border[1],EAS_2027.border[2],EAS_2027.border[3],0.64)
    edit._easInputBG02877 = bg
    if edit.SetColor then edit:SetColor(EAS_2027.text[1],EAS_2027.text[2],EAS_2027.text[3],1) end
end

local function easStyleDirectButton02877(control)
    if not control or not control.GetName then return end
    local name = tostring(control:GetName() or "")
    if string.find(name, "EAS_GlassNav_", 1, true) then return end
    if string.find(name, "ModernBG02877", 1, true) or string.find(name, "ModernBorder02877", 1, true) then return end
    if control.SetNormalFontColor and control.SetMouseOverFontColor and control.SetPressedFontColor then
        easPaintButton02877(control, control._easSelected02877 == true, J:GetTheme(), false)
    end
end

local function easWalk02877(control, fn)
    if not control then return end
    fn(control)
    if not control.GetNumChildren or not control.GetChild then return end
    local ok, count = pcall(control.GetNumChildren, control)
    if not ok then return end
    count = tonumber(count) or 0
    for i=1,count do
        local okChild, child = pcall(control.GetChild, control, i)
        if okChild and child then easWalk02877(child, fn) end
    end
end

function J:ApplySuite2027Layout02877()
    if not self.glassMode or not self.window or self.suite2027Applied02877 then return end
    self.suite2027Applied02877 = true
    local ar,ag,ab = easAccent02877(self:GetTheme())

    -- Whole-window shell.
    if self.bg then
        self.bg:SetCenterColor(EAS_2027.canvas[1],EAS_2027.canvas[2],EAS_2027.canvas[3],EAS_2027.canvas[4])
        self.bg:SetEdgeColor(ar,ag,ab,0.48)
    end
    if self.glassTopBar then
        self.glassTopBar:SetCenterColor(EAS_2027.topbar[1],EAS_2027.topbar[2],EAS_2027.topbar[3],EAS_2027.topbar[4])
        self.glassTopBar:SetEdgeColor(EAS_2027.borderSoft[1],EAS_2027.borderSoft[2],EAS_2027.borderSoft[3],0.46)
    end
    if self.glassSidebar then
        self.glassSidebar:SetCenterColor(EAS_2027.sidebar[1],EAS_2027.sidebar[2],EAS_2027.sidebar[3],EAS_2027.sidebar[4])
        self.glassSidebar:SetEdgeColor(EAS_2027.borderSoft[1],EAS_2027.borderSoft[2],EAS_2027.borderSoft[3],0.50)
    end
    if self.glassLeftCard then
        self.glassLeftCard:SetCenterColor(EAS_2027.surface[1],EAS_2027.surface[2],EAS_2027.surface[3],0.78)
        self.glassLeftCard:SetEdgeColor(EAS_2027.borderSoft[1],EAS_2027.borderSoft[2],EAS_2027.borderSoft[3],0.40)
    end
    if self.glassRightCard then
        self.glassRightCard:SetCenterColor(EAS_2027.surface[1],EAS_2027.surface[2],EAS_2027.surface[3],0.78)
        self.glassRightCard:SetEdgeColor(EAS_2027.borderSoft[1],EAS_2027.borderSoft[2],EAS_2027.borderSoft[3],0.40)
    end
    if self.glassAccent then
        self.glassAccent:SetDimensions(3, EAS_GLASS_BASE_H)
        self.glassAccent:SetCenterColor(ar,ag,ab,0.96)
    end

    if self.glassBrand then
        self.glassBrand:SetText("ESO ADVENTURER SUITE")
        self.glassBrand:SetColor(EAS_2027.text[1],EAS_2027.text[2],EAS_2027.text[3],1)
    end
    if self.glassSubtitle then
        self.glassSubtitle:SetText("TAMRIEL COMMAND CENTER  /  SUITE 2027")
        self.glassSubtitle:SetColor(EAS_2027.muted[1],EAS_2027.muted[2],EAS_2027.muted[3],1)
    end

    -- Current-workspace breadcrumb in the command bar.
    if not self.suiteChapter02877 then
        self.suiteChapter02877 = makeLabel("EAS_SuiteChapter02877", self.glassCanvas,
            "DASHBOARD", 420, 20, 392, 24, "ZoFontGameBold")
        self.suiteChapter02877:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    end
    self.suiteChapter02877:SetColor(EAS_2027.muted[1],EAS_2027.muted[2],EAS_2027.muted[3],1)

    -- Toolbar is a compact command cluster, not four disconnected boxes.
    if self.prevPageButton then self.prevPageButton:SetText("PREV") end
    if self.nextPageButton then self.nextPageButton:SetText("NEXT") end
    if self.themeButton then self.themeButton:SetText("COLOR") end
    if self.closeButton then self.closeButton:SetText("CLOSE") end
    if self.glassFloatingToolbar then
        self.glassFloatingToolbar:SetCenterColor(EAS_2027.surface[1],EAS_2027.surface[2],EAS_2027.surface[3],0.90)
        self.glassFloatingToolbar:SetEdgeColor(EAS_2027.border[1],EAS_2027.border[2],EAS_2027.border[3],0.58)
    end

    -- Dynamic navigation sizing: Dashboard + every chapter always fits.
    local ordered = {"INDEX"}
    for _, key in ipairs(TABS) do if key ~= "INDEX" then ordered[#ordered+1] = key end end
    local count = #ordered
    local startY, bottomPad = 40, 10
    local available = 664 - startY - bottomPad
    local step = math.floor(available / math.max(1,count))
    local buttonH = math.max(23, math.min(29, step - 3))
    for i,key in ipairs(ordered) do
        local b = self.tabButtons and self.tabButtons[key]
        if b and self.glassSidebar then
            b:ClearAnchors()
            b:SetAnchor(TOPLEFT, self.glassSidebar, TOPLEFT, 10, startY + (i-1)*step)
            b:SetDimensions(186, buttonH)
            b:SetFont(buttonH <= 24 and "ZoFontGameSmall" or "ZoFontGame")
            b:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
            b:SetText("    " .. tostring(key == "INDEX" and "Dashboard" or (TAB_LABELS[key] or key)))
            if b.glassBg then
                b.glassBg:SetCenterColor(EAS_2027.surface2[1],EAS_2027.surface2[2],EAS_2027.surface2[3],0.34)
                b.glassBg:SetEdgeColor(EAS_2027.borderSoft[1],EAS_2027.borderSoft[2],EAS_2027.borderSoft[3],0.38)
            end
        end
    end

    -- One subtle divider turns the workspace into a master/detail layout.
    if self.glassWorkspace and not self.suiteDivider02877 then
        local divider = wm:CreateControl("EAS_SuiteWorkspaceDivider02877", self.glassWorkspace, CT_BACKDROP)
        divider:SetAnchor(TOP, self.glassWorkspace, TOP, 0, 12)
        divider:SetDimensions(1, 632)
        divider:SetCenterColor(EAS_2027.border[1],EAS_2027.border[2],EAS_2027.border[3],0.56)
        divider:SetEdgeColor(0,0,0,0)
        self.suiteDivider02877 = divider
    end

    -- Direct-created controls (interactive rows etc.) inherit the same chrome.
    easWalk02877(self.window, function(control)
        if control.GetName then
            local name = tostring(control:GetName() or "")
            if string.find(name, "EAS_", 1, true) == 1 then
                easStyleDirectButton02877(control)
            end
        end
    end)

    easStyleInput02877(self.noteTitleEdit, "EAS_SuiteNoteTitleBG02877")
    easStyleInput02877(self.noteBodyEdit, "EAS_SuiteNoteBodyBG02877")
    easStyleInput02877(self.checkpointNameEdit, "EAS_SuiteCheckpointBG02877")

    if self.pageNumber then self.pageNumber:SetHidden(true) end
    if self.leftPageNumber then self.leftPageNumber:SetHidden(true) end
    if self.rightPageNumber then self.rightPageNumber:SetHidden(true) end
    if self.glassResizeHint then
        self.glassResizeHint:SetText("DRAG TO MOVE  •  RESIZE FROM ANY EDGE")
        self.glassResizeHint:SetColor(EAS_2027.faint[1],EAS_2027.faint[2],EAS_2027.faint[3],0.95)
    end
end

local easApplyThemePre02877 = ApplyThemeImplArch
ApplyThemeImplArch = function(self)
    local result = easApplyThemePre02877(self)
    if not self.glassMode or not self.window then return result end
    local ar,ag,ab = easAccent02877(self:GetTheme())

    if self.bg then
        self.bg:SetCenterColor(EAS_2027.canvas[1],EAS_2027.canvas[2],EAS_2027.canvas[3],EAS_2027.canvas[4])
        self.bg:SetEdgeColor(ar,ag,ab,0.48)
    end
    if self.glassTopBar then self.glassTopBar:SetCenterColor(EAS_2027.topbar[1],EAS_2027.topbar[2],EAS_2027.topbar[3],EAS_2027.topbar[4]) end
    if self.glassSidebar then self.glassSidebar:SetCenterColor(EAS_2027.sidebar[1],EAS_2027.sidebar[2],EAS_2027.sidebar[3],EAS_2027.sidebar[4]) end
    if self.glassLeftCard then self.glassLeftCard:SetCenterColor(EAS_2027.surface[1],EAS_2027.surface[2],EAS_2027.surface[3],0.78) end
    if self.glassRightCard then self.glassRightCard:SetCenterColor(EAS_2027.surface[1],EAS_2027.surface[2],EAS_2027.surface[3],0.78) end

    for _,label in pairs(self.themeLabels or {}) do
        if label and label.SetColor then label:SetColor(EAS_2027.text[1],EAS_2027.text[2],EAS_2027.text[3],1) end
    end
    if self.glassSubtitle then self.glassSubtitle:SetColor(EAS_2027.muted[1],EAS_2027.muted[2],EAS_2027.muted[3],1) end
    if self.suiteChapter02877 then self.suiteChapter02877:SetColor(ar,ag,ab,0.94) end

    for key,b in pairs(self.tabButtons or {}) do
        if b then
            local selected = key == self.activeTab
            if b.SetNormalFontColor then
                if selected then b:SetNormalFontColor(1,1,1,1)
                else b:SetNormalFontColor(EAS_2027.text[1],EAS_2027.text[2],EAS_2027.text[3],0.86) end
                b:SetMouseOverFontColor(1,1,1,1)
                b:SetPressedFontColor(ar,ag,ab,1)
            end
            if b.glassBg then
                if selected then b.glassBg:SetCenterColor(ar,ag,ab,0.17); b.glassBg:SetEdgeColor(ar,ag,ab,0.66)
                else b.glassBg:SetCenterColor(EAS_2027.surface2[1],EAS_2027.surface2[2],EAS_2027.surface2[3],0.34); b.glassBg:SetEdgeColor(EAS_2027.borderSoft[1],EAS_2027.borderSoft[2],EAS_2027.borderSoft[3],0.38) end
            end
            if b.glassRail then
                if selected then b.glassRail:SetColor(ar,ag,ab,1) else b.glassRail:SetColor(0,0,0,0) end
            end
        end
    end

    for _,b in ipairs(self.topButtons or {}) do easPaintButton02877(b, false, self:GetTheme(), false) end
    for _,b in ipairs(self.iconButtons or {}) do styleIconButton(b, self:GetTheme()) end
    if self.diceResultPanel then
        self.diceResultPanel:SetCenterColor(EAS_2027.surface2[1],EAS_2027.surface2[2],EAS_2027.surface2[3],0.90)
        self.diceResultPanel:SetEdgeColor(ar,ag,ab,0.40)
    end
    if self.diceResultValue then self.diceResultValue:SetColor(ar,ag,ab,1) end
    return result
end

local easSetTabPre02877 = SetTabImplArch
SetTabImplArch = function(self, tab, ...)
    local result = easSetTabPre02877(self, tab, ...)
    if self.suiteChapter02877 then
        self.suiteChapter02877:SetText(string.upper(tostring(tab == "INDEX" and "DASHBOARD" or (TAB_LABELS[tab] or tab or "WORKSPACE"))))
    end
    self:ApplyTheme()
    return result
end

local easCreatePre02877 = CreateImplArch
CreateImplArch = function(self)
    local result = easCreatePre02877(self)
    self:ApplySuite2027Layout02877()
    if self.activeTab then self:SetTab(self.activeTab) end
    self:ApplyTheme()
    return result
end

-- ============================================================================
-- v0.28.79 - Hard replacement app shell
-- The legacy Codex is still constructed first so every existing feature keeps
-- its event handlers/state, but its visible shell/navigation is removed and all
-- live pages are mounted inside a new single-window dashboard application.
-- ============================================================================
TAB_LABELS.CHARACTER = "Character"
TAB_TITLES.CHARACTER = "CHARACTER"
TAB_LABELS.COMPANIONS = "Companions"
TAB_TITLES.COMPANIONS = "COMPANIONS"

local EAS_APP_GROUPS_02879 = {
    HOME = {"INDEX"},
    CHARACTER = {"CHARACTER","COMPANIONS","BUILD","GEAR","SKILLS","COMBAT","STATS","ACHIEVEMENTS"},
    ADVENTURE = {"QUESTS","PURSUITS","ACTIVITY","TRAVEL"},
    FINDERS = {"DUNGEONS","BATTLEGROUNDS","GROUPFINDER"},
    TOOLS = {"NOTES","PINS","TOOLS","CODEX","DICE"},
}
local EAS_APP_GROUP_ORDER_02879 = {"HOME","CHARACTER","ADVENTURE","FINDERS","TOOLS"}
local EAS_APP_ICONS_02879 = {
    INDEX="home", CHARACTER="character", COMPANIONS="companions", BUILD="build", GEAR="gear",
    SKILLS="skills", COMBAT="combat", STATS="stats", ACHIEVEMENTS="achievements", QUESTS="quests",
    PURSUITS="pursuits", ACTIVITY="activity", TRAVEL="travel", DUNGEONS="dungeons",
    BATTLEGROUNDS="battlegrounds", GROUPFINDER="groupfinder", NOTES="notes", PINS="pins",
    TOOLS="tools", CODEX="codex", DICE="dice",
}

local function easAppTabGroup02879(tab)
    for group, tabs in pairs(EAS_APP_GROUPS_02879) do
        for _, value in ipairs(tabs) do if value == tab then return group end end
    end
    return "HOME"
end

local function easAppPanel02879(name, parent, x, y, w, h, r,g,b,a)
    local c = wm:CreateControl(name, parent, CT_BACKDROP)
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    c:SetDimensions(w,h)
    c:SetEdgeTexture(nil,1,1,1)
    c:SetCenterColor(r or 0.035,g or 0.038,b or 0.052,a or 0.96)
    c:SetEdgeColor(0.16,0.15,0.22,0.72)
    return c
end

local function easAppLabel02879(name, parent, text, x,y,w,h,font,color)
    local l = wm:CreateControl(name, parent, CT_LABEL)
    l:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y)
    l:SetDimensions(w,h)
    l:SetFont(font or "ZoFontGame")
    l:SetText(text or "")
    local c = color or {0.94,0.94,0.98,1}
    l:SetColor(c[1],c[2],c[3],c[4] or 1)
    l:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return l
end

local function easAppButton02879(name,parent,text,x,y,w,h,callback)
    local b = wm:CreateControl(name,parent,CT_BUTTON)
    b:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y); b:SetDimensions(w,h)
    b:SetFont("ZoFontGameBold"); b:SetText(text or "")
    b:SetNormalFontColor(0.88,0.88,0.94,1); b:SetMouseOverFontColor(1,1,1,1); b:SetPressedFontColor(1,1,1,1)
    local bg = easAppPanel02879(name.."BG",b,0,0,w,h,0.055,0.055,0.075,0.96)
    bg:SetDrawLevel(0); b._appBg02879=bg
    b:SetHandler("OnMouseEnter",function(c) c._appBg02879:SetCenterColor(0.16,0.12,0.30,0.98); c._appBg02879:SetEdgeColor(0.49,0.36,1,0.95) end)
    b:SetHandler("OnMouseExit",function(c) c._appBg02879:SetCenterColor(0.055,0.055,0.075,0.96); c._appBg02879:SetEdgeColor(0.16,0.15,0.22,0.72) end)
    if callback then b:SetHandler("OnClicked",callback) end
    return b
end

local function easAppCleanName02879(value)
    local s = tostring(value or "")
    if type(zo_strformat)=="function" and s~="" then
        local ok,v=pcall(zo_strformat,"<<C:1>>",s); if ok and v then s=tostring(v) end
    end
    return s~="" and s or "Adventurer"
end

local function easAppCurrentClassTexture02879()
    local name = string.lower(tostring(safe(GetUnitClass,"Sorcerer","player") or "Sorcerer"))
    local key = "sorcerer"
    if string.find(name,"dragon",1,true) then key="dragonknight"
    elseif string.find(name,"night",1,true) then key="nightblade"
    elseif string.find(name,"warden",1,true) then key="warden"
    elseif string.find(name,"necro",1,true) then key="necromancer"
    elseif string.find(name,"templar",1,true) then key="templar"
    elseif string.find(name,"arcan",1,true) then key="arcanist" end
    return EPC:AssetPath("Art/Cards/class_"..key..".dds"), key
end

local function easAppTextureCard02879(name,parent,path,x,y,w,h,selected)
    local card=easAppPanel02879(name,parent,x,y,w,h,0.025,0.026,0.034,1)
    if selected then card:SetEdgeColor(0.49,0.36,1,1) end
    local t=wm:CreateControl(name.."Texture",card,CT_TEXTURE)
    t:SetAnchor(TOPLEFT,card,TOPLEFT,3,3); t:SetDimensions(w-6,h-6); t:SetTexture(path); t:SetTextureCoords(0,1,0,0.6914)
    return card,t
end

function J:CreateAppDashboard02879()
    local p=wm:CreateControl("EAS_AppDashboard02879",self.glassWorkspace,CT_CONTROL); p:SetAnchorFill(self.glassWorkspace)
    local hero=easAppPanel02879("EAS_AppHero02879",p,18,18,650,260,0.028,0.029,0.039,0.98)
    easAppLabel02879("EAS_AppHeroEyebrow02879",hero,"TAMRIEL COMMAND CENTER",28,24,360,22,"ZoFontGameBold",{0.49,0.36,1,1})
    self.appHeroTitle02879=easAppLabel02879("EAS_AppHeroTitle02879",hero,"YOUR ADVENTURE.\nONE COMMAND CENTER.",28,58,460,92,"$(BOLD_FONT)|30|soft-shadow-thick")
    self.appHeroSub02879=easAppLabel02879("EAS_AppHeroSub02879",hero,"",28,150,510,44,"ZoFontGame",{0.56,0.57,0.66,1})
    easAppButton02879("EAS_AppQuestButton02879",hero,"CONTINUE QUEST",28,208,190,38,function() self:SetTab("QUESTS") end)
    easAppButton02879("EAS_AppFindButton02879",hero,"FIND ACTIVITY",232,208,178,38,function() self:SetTab("DUNGEONS") end)

    local profile=easAppPanel02879("EAS_AppProfileCard02879",p,684,18,360,260,0.032,0.032,0.044,0.99)
    self.appProfileName02879=easAppLabel02879("EAS_AppProfileName02879",profile,"",20,18,190,30,"ZoFontWinH2")
    self.appProfileMeta02879=easAppLabel02879("EAS_AppProfileMeta02879",profile,"",20,50,190,36,"ZoFontGame",{0.58,0.59,0.68,1})
    local texturePath=easAppCurrentClassTexture02879()
    local art=wm:CreateControl("EAS_AppProfileArt02879",profile,CT_TEXTURE); art:SetAnchor(TOPRIGHT,profile,TOPRIGHT,-12,12); art:SetDimensions(142,196); art:SetTexture(texturePath); art:SetTextureCoords(0,1,0,0.6914); self.appProfileArt02879=art
    self.appProfileStats02879=easAppLabel02879("EAS_AppProfileStats02879",profile,"",20,100,180,94,"ZoFontGameSmall",{0.84,0.84,0.90,1})
    easAppButton02879("EAS_AppBuildButton02879",profile,"OPEN BUILD",20,210,142,34,function() self:SetTab("BUILD") end)

    local cards={
        {"QUEST","Active Quest","QUESTS"},{"GOLD","Golden Pursuits","PURSUITS"},{"QUEUE","Activity Queue","DUNGEONS"},
        {"COMP","Companion","COMPANIONS"},{"ZONE","Current Zone","TRAVEL"},{"GEAR","Gear & Sets","GEAR"},
    }
    self.appDashboardCards02879={}
    for i,data in ipairs(cards) do
        local col=(i-1)%3; local row=math.floor((i-1)/3); local x=18+col*347; local y=296+row*154
        local c=easAppPanel02879("EAS_AppDashCard02879_"..i,p,x,y,329,136,0.037,0.038,0.052,0.98)
        local tag=easAppLabel02879("EAS_AppDashTag02879_"..i,c,data[1],18,15,70,20,"ZoFontGameBold",{0.49,0.36,1,1})
        local title=easAppLabel02879("EAS_AppDashTitle02879_"..i,c,data[2],18,39,285,25,"ZoFontGameBold")
        local value=easAppLabel02879("EAS_AppDashValue02879_"..i,c,"",18,67,285,38,"ZoFontGame",{0.66,0.67,0.74,1}); value:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        local hit=wm:CreateControl("EAS_AppDashHit02879_"..i,c,CT_BUTTON); hit:SetAnchorFill(c); hit:SetHandler("OnClicked",function() self:SetTab(data[3]) end)
        hit:SetHandler("OnMouseEnter",function() c:SetEdgeColor(0.49,0.36,1,0.92) end); hit:SetHandler("OnMouseExit",function() c:SetEdgeColor(0.16,0.15,0.22,0.72) end)
        self.appDashboardCards02879[i]={value=value,target=data[3],panel=c}
    end
    return p
end

function J:CreateAppCharacterPage02879()
    local p=wm:CreateControl("EAS_AppCharacterPage02879",self.glassWorkspace,CT_CONTROL); p:SetAnchorFill(self.glassWorkspace)
    easAppLabel02879("EAS_AppCharacterTitle02879",p,"CHARACTER",22,18,500,34,"$(BOLD_FONT)|26|soft-shadow-thick")
    easAppLabel02879("EAS_AppCharacterSub02879",p,"Your active class is highlighted. Open Build, Gear, Skills or Stats from the rail for live optimization.",22,51,850,30,"ZoFontGame",{0.56,0.57,0.66,1})
    local classes={{"dragonknight","Dragonknight"},{"sorcerer","Sorcerer"},{"nightblade","Nightblade"},{"warden","Warden"},{"necromancer","Necromancer"},{"templar","Templar"},{"arcanist","Arcanist"}}
    local _,current=easAppCurrentClassTexture02879()
    self.appClassCards02879={}
    for i,d in ipairs(classes) do
        local col=(i-1)%4; local row=math.floor((i-1)/4); local x=22+col*254; local y=96+row*265
        local card=easAppTextureCard02879("EAS_AppClassCard02879_"..i,p,EPC:AssetPath("Art/Cards/class_"..d[1]..".dds"),x,y,226,246,d[1]==current)
        self.appClassCards02879[i]=card
    end
    easAppButton02879("EAS_AppCharacterBuild02879",p,"OPEN CURRENT BUILD",786,621,250,36,function() self:SetTab("BUILD") end)
    return p
end

function J:CreateAppCompanionPage02879()
    local p=wm:CreateControl("EAS_AppCompanionPage02879",self.glassWorkspace,CT_CONTROL); p:SetAnchorFill(self.glassWorkspace)
    easAppLabel02879("EAS_AppCompanionTitle02879",p,"COMPANIONS",22,18,500,34,"$(BOLD_FONT)|26|soft-shadow-thick")
    self.appCompanionSub02879=easAppLabel02879("EAS_AppCompanionSub02879",p,"",22,51,850,30,"ZoFontGame",{0.56,0.57,0.66,1})
    local companions={{"azandar","Azandar"},{"bastian","Bastian Hallix"},{"ember","Ember"},{"isobel","Isobel Veloise"},{"mirri","Mirri Elendis"},{"sharp","Sharp-as-Night"},{"tanlorin","Tanlorin"},{"zerithvar","Zerith-var"}}
    self.appCompanionCards02879={}
    for i,d in ipairs(companions) do
        local col=(i-1)%4; local row=math.floor((i-1)/4); local x=22+col*254; local y=96+row*265
        local card=easAppPanel02879("EAS_AppCompanionCard02879_"..i,p,x,y,226,246,0.025,0.026,0.034,1)

        -- v0.29.81: use the full 512x512 DXT5 portrait. The old 256x512
        -- card asset included a baked-in name strip and relied on cropped UVs;
        -- ESO could display only that lower strip while the portrait area looked
        -- blank. A full square portrait plus a real UI label is reliable.
        local art=wm:CreateControl("EAS_AppCompanionPortrait02981_"..i,card,CT_TEXTURE)
        art:SetAnchor(TOPLEFT,card,TOPLEFT,3,3)
        art:SetDimensions(220,211)
        art:SetTexture(EPC:AssetPath("Art/eas_companion_"..d[1]..".dds"))
        art:SetTextureCoords(0,1,0,1)
        art:SetDrawLevel(8)

        local nameBg=wm:CreateControl("EAS_AppCompanionNameBG02981_"..i,card,CT_BACKDROP)
        nameBg:SetAnchor(BOTTOMLEFT,card,BOTTOMLEFT,3,-3)
        nameBg:SetAnchor(BOTTOMRIGHT,card,BOTTOMRIGHT,-3,-3)
        nameBg:SetHeight(27)
        nameBg:SetCenterColor(0.018,0.020,0.028,0.96)
        nameBg:SetEdgeColor(0.10,0.11,0.15,0.90)
        nameBg:SetDrawLevel(10)

        local nameLabel=wm:CreateControl("EAS_AppCompanionName02981_"..i,nameBg,CT_LABEL)
        nameLabel:SetAnchorFill(nameBg)
        nameLabel:SetFont("ZoFontGameBold")
        nameLabel:SetText(d[2])
        nameLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        nameLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        nameLabel:SetColor(0.95,0.95,0.98,1)
        nameLabel:SetDrawLevel(12)

        self.appCompanionCards02879[i]={control=card,texture=art,key=d[1],label=d[2]}
    end
    return p
end

function J:RefreshAppPages02879()
    local player=easAppCleanName02879(safe(GetUnitName,"Adventurer","player"))
    local class=easAppCleanName02879(safe(GetUnitClass,"Adventurer","player"))
    local level=tonumber(safe(GetUnitLevel,0,"player")) or 0
    local cp=tonumber(safe(GetUnitChampionPoints,0,"player")) or 0
    local zone=easAppCleanName02879(safe(GetUnitZone,"Tamriel","player"))
    if self.appProfileName02879 then self.appProfileName02879:SetText(player) end
    if self.appProfileMeta02879 then self.appProfileMeta02879:SetText(class.."  •  "..(cp>0 and ("CP "..cp) or ("LEVEL "..level))) end
    if self.appHeroSub02879 then self.appHeroSub02879:SetText(zone.."  •  "..class.."  •  "..(cp>0 and ("Champion "..cp) or ("Level "..level))) end
    if self.appProfileArt02879 then local path=easAppCurrentClassTexture02879(); self.appProfileArt02879:SetTexture(path) end
    if self.appProfileStats02879 then
        local hc,hm=safe(GetUnitPower,0,"player",POWERTYPE_HEALTH); local mc,mm=safe(GetUnitPower,0,"player",POWERTYPE_MAGICKA); local sc,sm=safe(GetUnitPower,0,"player",POWERTYPE_STAMINA)
        self.appProfileStats02879:SetText(string.format("HEALTH   %s\nMAGICKA  %s\nSTAMINA  %s",tostring(hm or hc or "--"),tostring(mm or mc or "--"),tostring(sm or sc or "--")))
    end
    local quest="No assisted quest"
    if EPC.ActiveQuest and EPC.ActiveQuest.GetActiveQuestIndex then
        local ok,idx=pcall(EPC.ActiveQuest.GetActiveQuestIndex,EPC.ActiveQuest); if ok and tonumber(idx) and tonumber(idx)>0 then local q=safe(GetJournalQuestInfo,"",tonumber(idx)); if q and q~="" then quest=easAppCleanName02879(q) end end
    end
    local pursuit="No active pursuit"
    if self.BuildGoldenPursuitsView2494 then local ok,v=pcall(self.BuildGoldenPursuitsView2494,self); if ok and v and v.rows and v.rows[1] then local r=v.rows[1]; pursuit=tostring(r.name or r.activityName or r.description or "Golden Pursuit") end end
    local queue="Not queued"
    if EPC.BattlegroundFinder and EPC.BattlegroundFinder.IsQueued and EPC.BattlegroundFinder:IsQueued() then queue="Battleground queue active"
    elseif EPC.DungeonFinder and EPC.DungeonFinder.IsQueued and EPC.DungeonFinder:IsQueued() then queue="Dungeon queue active" end
    local companion="No active companion"
    if safe(DoesUnitExist,false,"companion") == true then companion=easAppCleanName02879(safe(GetUnitName,"Companion","companion")) end
    local values={quest,pursuit,queue,companion,zone,class.." build"}
    for i,v in ipairs(values) do if self.appDashboardCards02879 and self.appDashboardCards02879[i] then self.appDashboardCards02879[i].value:SetText(v) end end
    if self.appCompanionSub02879 then self.appCompanionSub02879:SetText("ACTIVE: "..companion.."  •  companion cards use the ESO artwork you supplied") end
    local activeKey=string.lower(companion):gsub("[^%a]","")
    for _,entry in ipairs(self.appCompanionCards02879 or {}) do
        local selected=string.find(activeKey,entry.key:gsub("[^%a]",""),1,true)~=nil
        entry.control:SetEdgeColor(selected and 0.49 or 0.16,selected and 0.36 or 0.15,selected and 1 or 0.22,selected and 1 or 0.72)
    end
end

function J:BuildAppRail02879()
    if not self.appRail02879 then return end
    for _,b in pairs(self.appRailButtons02879 or {}) do b:SetHidden(true) end
    local group=self.appActiveGroup02879 or easAppTabGroup02879(self.activeTab)
    local tabs=EAS_APP_GROUPS_02879[group] or EAS_APP_GROUPS_02879.HOME
    for i,tab in ipairs(tabs) do
        local b=self.appRailButtons02879[tab]
        if not b then
            b=wm:CreateControl("EAS_AppRailButton02879_"..tab,self.appRail02879,CT_BUTTON); b:SetDimensions(50,50)
            local bg=easAppPanel02879("EAS_AppRailButtonBG02879_"..tab,b,0,0,50,50,0.03,0.03,0.042,0); bg:SetEdgeColor(0,0,0,0); b._bg02879=bg
            local tex=wm:CreateControl("EAS_AppRailIcon02879_"..tab,b,CT_TEXTURE); tex:SetAnchor(CENTER,b,CENTER,0,0); tex:SetDimensions(25,25); tex:SetTexture(EPC:AssetPath("Art/AppIcons/"..(EAS_APP_ICONS_02879[tab] or "home")..".dds")); tex:SetColor(0.48,0.48,0.56,1); b._icon02879=tex
            b:SetHandler("OnClicked",function() self:SetTab(tab) end)
            b:SetHandler("OnMouseEnter",function(c) c._icon02879:SetColor(0.75,0.65,1,1); self.appRailTip02879:SetText(TAB_LABELS[tab] or tab); self.appRailTip02879:SetHidden(false); self.appRailTip02879:ClearAnchors(); self.appRailTip02879:SetAnchor(LEFT,c,RIGHT,10,0) end)
            b:SetHandler("OnMouseExit",function(c) self.appRailTip02879:SetHidden(true); if self.activeTab~=tab then c._icon02879:SetColor(0.48,0.48,0.56,1) end end)
            self.appRailButtons02879[tab]=b
        end
        b:ClearAnchors(); b:SetAnchor(TOPLEFT,self.appRail02879,TOPLEFT,11,96+(i-1)*58); b:SetHidden(false)
        local selected=self.activeTab==tab; b._icon02879:SetColor(selected and 0.63 or 0.48,selected and 0.47 or 0.48,selected and 1 or 0.56,1); b._bg02879:SetCenterColor(selected and 0.11 or 0.03,selected and 0.075 or 0.03,selected and 0.20 or 0.042,selected and 0.92 or 0)
    end
end

function J:UpdateAppNavigation02879()
    if not self.appShell02879 then return end
    self.appActiveGroup02879=easAppTabGroup02879(self.activeTab)
    for group,b in pairs(self.appGroupButtons02879 or {}) do
        local selected=group==self.appActiveGroup02879; b._appBg02879:SetCenterColor(selected and 0.16 or 0.045,selected and 0.11 or 0.045,selected and 0.30 or 0.06,0.98); b._appBg02879:SetEdgeColor(selected and 0.49 or 0.12,selected and 0.36 or 0.12,selected and 1 or 0.18,selected and 0.9 or 0.5)
    end
    if self.appSectionTitle02879 then self.appSectionTitle02879:SetText(string.upper(TAB_LABELS[self.activeTab] or self.activeTab or "HOME")) end
    self:BuildAppRail02879()
end

function J:ApplyHardAppShell02879()
    if self.appShell02879 or not self.glassCanvas then return end
    self.hardAppShell02879=true
    -- Remove every visible piece of the prior Codex/Glass shell.
    for _,c in ipairs({self.bg,self.glassTopBar,self.glassAccent,self.glassSidebar,self.glassLeftCard,self.glassRightCard,self.glassFloatingToolbar,self.suiteDivider02877,self.glassBrand,self.glassSubtitle,self.prevPageButton,self.nextPageButton,self.themeButton,self.closeButton,self.pageNumber,self.leftPageNumber,self.rightPageNumber,self.flipPage}) do if c and c.SetHidden then c:SetHidden(true) end end
    for _,b in pairs(self.tabButtons or {}) do if b and b.SetHidden then b:SetHidden(true) end end
    if self.bookTexture then self.bookTexture:SetHidden(true) end

    local canvas=self.glassCanvas
    local shell=easAppPanel02879("EAS_AppShell02879",canvas,0,0,EAS_GLASS_BASE_W,EAS_GLASS_BASE_H,0.018,0.018,0.026,1); shell:SetEdgeColor(0.12,0.11,0.18,1); shell:SetDrawLevel(0); self.appShell02879=shell
    local rail=easAppPanel02879("EAS_AppRail02879",canvas,0,0,76,EAS_GLASS_BASE_H,0.025,0.025,0.034,1); rail:SetEdgeColor(0.08,0.08,0.12,1); rail:SetDrawLevel(30); self.appRail02879=rail
    local logo=easAppPanel02879("EAS_AppLogo02879",rail,18,18,40,40,0.025,0.025,0.034,1); logo:SetEdgeColor(0.49,0.36,1,1)
    easAppLabel02879("EAS_AppLogoText02879",logo,"A",0,0,40,40,"ZoFontWinH2",{0.72,0.62,1,1}):SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    local top=easAppPanel02879("EAS_AppTop02879",canvas,76,0,1104,72,0.025,0.025,0.034,1); top:SetEdgeColor(0.08,0.08,0.12,1); top:SetDrawLevel(30); self.appTop02879=top
    easAppLabel02879("EAS_AppBrand02879",top,"ESO ADVENTURER SUITE",24,17,235,28,"ZoFontWinH2")
    self.appSectionTitle02879=easAppLabel02879("EAS_AppSectionTitle02879",top,"HOME",258,21,170,22,"ZoFontGameBold",{0.49,0.36,1,1})
    self.appGroupButtons02879={}
    local gx=430
    for i,group in ipairs(EAS_APP_GROUP_ORDER_02879) do local b=easAppButton02879("EAS_AppGroup02879_"..group,top,group,gx+(i-1)*104,15,96,40,function() self.appActiveGroup02879=group; self:SetTab(EAS_APP_GROUPS_02879[group][1]) end); self.appGroupButtons02879[group]=b end
    self.appProfileTopName02879=easAppLabel02879("EAS_AppTopProfile02879",top,easAppCleanName02879(safe(GetUnitName,"Adventurer","player")),950,14,116,22,"ZoFontGameBold"); self.appProfileTopName02879:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.appProfileTopClass02879=easAppLabel02879("EAS_AppTopProfileSub02879",top,easAppCleanName02879(safe(GetUnitClass,"", "player")),930,35,136,18,"ZoFontGameSmall",{0.49,0.36,1,1}); self.appProfileTopClass02879:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    local close=easAppButton02879("EAS_AppClose02879",top,"X",1070,16,34,36,function() self:Hide() end); close:SetNormalFontColor(0.7,0.7,0.76,1)
    self.appRailButtons02879={}
    self.appRailTip02879=easAppLabel02879("EAS_AppRailTip02879",canvas,"",0,0,160,28,"ZoFontGameBold"); self.appRailTip02879:SetHidden(true); self.appRailTip02879:SetDrawLevel(100)

    -- Existing live pages stay wired but are now placed inside the new app content canvas.
    self.glassWorkspace:ClearAnchors(); self.glassWorkspace:SetAnchor(TOPLEFT,canvas,TOPLEFT,88,82); self.glassWorkspace:SetDimensions(1074,662); self.glassWorkspace:SetDrawLevel(10)
    self.leftPageHost:ClearAnchors(); self.leftPageHost:SetAnchor(TOPLEFT,self.glassWorkspace,TOPLEFT,14,42); self.leftPageHost:SetDimensions(self.pageW,self.pageH)
    self.rightPageHost:ClearAnchors(); self.rightPageHost:SetAnchor(TOPLEFT,self.glassWorkspace,TOPLEFT,528,42); self.rightPageHost:SetDimensions(self.pageW,self.pageH)
    for key,page in pairs(self.pages or {}) do
        if page and page.leftSurface02877 then page.leftSurface02877:SetCenterColor(0.032,0.033,0.045,0.99); page.leftSurface02877:SetEdgeColor(0.14,0.13,0.19,0.72) end
        if page and page.rightSurface02877 then page.rightSurface02877:SetCenterColor(0.032,0.033,0.045,0.99); page.rightSurface02877:SetEdgeColor(0.14,0.13,0.19,0.72) end
        if page and page.headerRuleLeft02877 then page.headerRuleLeft02877:SetCenterColor(0.49,0.36,1,0.72) end
        if page and page.headerRuleRight02877 then page.headerRuleRight02877:SetCenterColor(0.49,0.36,1,0.72) end
    end
    local oldIndex=self.pages.INDEX; if oldIndex then oldIndex:SetHidden(true) end
    self.legacyIndexPage02879=oldIndex
    self.pages.INDEX=self:CreateAppDashboard02879()
    self.pages.CHARACTER=self:CreateAppCharacterPage02879()
    self.pages.COMPANIONS=self:CreateAppCompanionPage02879()
    self:RefreshAppPages02879(); self:UpdateAppNavigation02879()
    -- No page-turn animation in the application shell.
    self.openSound=nil; self.closeSound=nil; self.turnSound=nil
end

local easPlayPageTurnPre02879=PlayPageTurnImplArch
PlayPageTurnImplArch = function(self) if self.hardAppShell02879 then return end; return easPlayPageTurnPre02879(self) end

local easSetTabPre02879=SetTabImplArch
SetTabImplArch = function(self, tab,...)
    local result=easSetTabPre02879(self,tab,...)
    if self.appShell02879 then self:RefreshAppPages02879(); self:UpdateAppNavigation02879() end
    return result
end

local easApplyThemePre02879=ApplyThemeImplArch
ApplyThemeImplArch = function(self, ...)
    local result=easApplyThemePre02879(self,...)
    if self.appShell02879 then
        self.appShell02879:SetCenterColor(0.018,0.018,0.026,1)
        self.appRail02879:SetCenterColor(0.025,0.025,0.034,1)
        self.appTop02879:SetCenterColor(0.025,0.025,0.034,1)
        self:UpdateAppNavigation02879()
    end
    return result
end

local easCreatePre02879=CreateImplArch
CreateImplArch = function(self)
    local result=easCreatePre02879(self)
    self:ApplyHardAppShell02879()
    local wanted=self.activeTab or self:EnsureSaved().activeTab or "INDEX"
    if wanted~="CHARACTER" and wanted~="COMPANIONS" and not self.pages[wanted] then wanted="INDEX" end
    self:SetTab(wanted)
    if self.window and self.window.SetKeyboardEnabled then self.window:SetKeyboardEnabled(true) end
    if self.window then self.window:SetHandler("OnKeyDown",function(_,key,ctrl,alt,shift,command) if self.window and not self.window:IsHidden() and self:RawKeyMatchesAction("ESO_PROGRESSION_COACH_TOGGLE",key,ctrl,alt,shift,command) then self:Hide() end end) end
    -- Permanently retire the older standalone Suite menu.
    if EPC.UI and EPC.UI.root then EPC.UI.root:SetHidden(true) end
    return result
end
