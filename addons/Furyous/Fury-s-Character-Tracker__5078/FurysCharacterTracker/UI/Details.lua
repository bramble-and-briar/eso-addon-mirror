-- Character details: everything saved for one character, in sections. Left-click a character on the
-- board. The offline viewer shows the same sections in the same order.
local CT = FurysCharacterTracker
local U = CT.Util
local R = CT.Research
local Details = {}
CT.Details = Details

local T = CT.Theme                    -- Fury Night colors and fonts (UI/Theme.lua)
local GOLD = T.RGB.VIOLET             -- done / maxed
local PARCH = T.RGB.TEXT
local MUTED = T.RGB.SUB
local DIM = T.RGB.MUTED

local COLUMNS, COL_W, COL_GAP, KEY_W, VALUE_W, LINE_H = 3, 300, 20, 196, 100, 22

local function Comma(n) return ZO_CommaDelimitNumber(n or 0) end

-- Sections: { title =, items = { { key, value, done = true/false/nil, dim = } }, lines = { text } }
function Details.Sections(name, c, m)
    local sections = {}
    local function Progress(key, value, max)
        value = value or 0
        local text = max and (Comma(value) .. " / " .. Comma(max)) or Comma(value)
        return { key, text, done = max and value >= max, dim = value == 0 }
    end

    sections[#sections + 1] = { title = "Your picks", items = {
        { "Role", m.role or "-" }, { "DPS gear", m.dpsGear or "-" },
        { "Tank/healer gear", m.roleGear or "-" }, { "Planned race", m.plannedRace or "-" } } }

    local companions = c.companions or {}
    local progress = { title = "Progress", items = {
        Progress("Skill points", c.skillPoints, CT.SKILL_POINTS_MAX), { "Not assigned", tostring(c.unspent or "-") },
        Progress("Crafting lines at 50", c.craftMaxed, 7), Progress("Traits researched", c.research, c.researchTotal or CT.RESEARCH_TOTAL),
        Progress("Scribing", c.scripts, c.scriptsTotal or CT.SCRIPTS_TOTAL), Progress("Grimoires", c.grimoires, c.grimoiresTotal),
        Progress("Scripts", c.scriptsOnly, c.scriptsOnlyTotal), Progress("Recipes", c.recipes, c.recipesTotal),
        Progress("Furnishing plans", c.furnishings, c.furnishingsTotal), Progress("Motif styles", c.motifs, c.motifsTotal),
        Progress("Riding", c.riding, c.ridingMax or CT.RIDING_MAX), Progress("Companions", #companions, c.companionsTotal or CT.COMPANION_TOTAL),
        { "Achievement points", Comma(c.achievementPoints) }, { "Hours played", Comma(c.playedHours) } }, lines = {} }
    if #companions > 0 then progress.lines[1] = "Companions: " .. table.concat(companions, ", ") end
    sections[#sections + 1] = progress

    for _, group in ipairs(CT.GROUPS) do
        local items = {}
        for _, line in ipairs(group.lines) do
            items[#items + 1] = Progress(line.name, math.min((c.lines or {})[line.name] or 0, line.max), line.max)
        end
        sections[#sections + 1] = { title = string.format("%s (%d of %d maxed)", group.title, CT.Roster:MaxedInGroup(c, group), #group.lines),
                                    items = items }
    end

    local D, world, now0 = CT.Daily, CT.view.world, GetTimeStamp()
    local daily = { title = "Daily", items = {} }
    for _, def in ipairs(D.CRAFTS) do
        local state = D.State(c, def.craft, world, now0)
        daily.items[#daily.items + 1] = { U.Plain(GetString("SI_TRADESKILLTYPE", def.craft)) .. " writ", D.LABEL[state], done = state == D.DONE, dim = state == D.NONE }
    end
    local riding = not c.ridingReadyAt and "Maxed" or (c.ridingReadyAt <= now0 and "Ready" or R.Duration(c.ridingReadyAt - now0))
    daily.items[#daily.items + 1] = { "Riding lesson", riding, done = not c.ridingReadyAt }
    sections[#sections + 1] = daily

    local wallet = { title = "Wallet & CP", items = {
        { "Gold", Comma(c.gold) }, { "Tel Var", Comma(c.telvar) }, { "Alliance Points", Comma(c.ap) }, { "Writ vouchers", Comma(c.vouchers) },
        { "Bag", c.bagSize and (c.bagUsed .. " / " .. c.bagSize) or "-" } } }
    for _, t in ipairs(c.cp or {}) do
        wallet.items[#wallet.items + 1] = { t.name, t.spent .. " / " .. (t.spent + t.unspent), done = t.unspent == 0 and t.spent > 0 }
    end
    sections[#sections + 1] = wallet

    local research = { title = "Research", lines = {} }
    local now = GetTimeStamp()
    if not c.researchCrafts then
        research.lines[1] = (c.research or 0) >= (c.researchTotal or CT.RESEARCH_TOTAL) and "Every trait researched."
                            or "Log in on this character with version 1.1.0 or later to see research details."
    end
    for _, def in ipairs(R.CRAFTS) do
        local e = R.Entry(c, def.craft)
        if e then
            local done = e.known >= e.total
            research.lines[#research.lines + 1] = { string.format("%s: %d of %d traits%s", R.CraftName(def.craft), e.known, e.total,
                                                    done and "  ·  complete" or string.format("  ·  %d research slots", e.slots)), bold = true }
            for _, timer in ipairs(e.timers) do
                local left = timer.endsAt > now and (R.Duration(timer.endsAt - now) .. " left") or "done"
                research.lines[#research.lines + 1] = { string.format("    Researching %s: %s  ·  %s", timer.item, timer.trait, left), gold = true }
            end
            for _, item in ipairs(e.missing) do
                research.lines[#research.lines + 1] = string.format("    %s: %s", item.item, table.concat(item.traits, ", "))
            end
        end
    end
    sections[#sections + 1] = research
    return sections
end

-- Window -------------------------------------------------------------------------------

function Details:Build()
    if self.content then return end
    SCENE_MANAGER:RegisterTopLevel(FurysCharacterTracker_Details, false)
    self.content = FurysCharacterTracker_DetailsScrollScrollChild
    self.labels = {}
    local pos = CT.sv.detailsWindow
    if pos then
        FurysCharacterTracker_Details:ClearAnchors()
        FurysCharacterTracker_Details:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.x, pos.y)
    end
end

function Details.SavePosition()
    CT.sv.detailsWindow = { x = FurysCharacterTracker_Details:GetLeft(), y = FurysCharacterTracker_Details:GetTop() }
end

-- Labels are reused between characters; the ones not needed this time are hidden.
function Details:Label(index)
    local label = self.labels[index]
    if not label then
        label = WINDOW_MANAGER:CreateControl("FurysCharacterTracker_DetailsText" .. index, self.content, CT_LABEL)
        self.labels[index] = label
    end
    label:SetHidden(false)
    label:ClearAnchors()
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    return label
end

function Details:Put(index, text, font, rgb, x, y, width, align)
    local label = self:Label(index)
    label:SetFont(font)
    label:SetColor(rgb[1], rgb[2], rgb[3], 1)
    label:SetText(text)
    label:SetDimensions(width, LINE_H)
    label:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT)
    label:SetAnchor(TOPLEFT, self.content, TOPLEFT, x, y)
end

function Details:Show(name)
    local c, m = CT.Roster:Get(name)
    if not c then return end
    self:Build()
    FurysCharacterTracker_DetailsTitle:SetText(name)
    FurysCharacterTracker_DetailsSubtitle:SetText(string.format("%s  ·  Level %s %s %s  ·  %s  ·  read from the game %s", CT.ViewLabel(), c.level or "?",
                                                c.race or "", c.class or "", c.alliance or "", U.FormatDate(c.lastScan)))
    local n, y = 0, 0
    local width = COLUMNS * COL_W + (COLUMNS - 1) * COL_GAP
    for _, section in ipairs(self.Sections(name, c, m)) do
        n = n + 1
        self:Put(n, section.title, "ZoFontGameBold", T.RGB.BLUE, 0, y, width)
        y = y + LINE_H + 4
        for i, item in ipairs(section.items or {}) do
            local col = (i - 1) % COLUMNS
            local x = col * (COL_W + COL_GAP)
            n = n + 1
            self:Put(n, item[1], "ZoFontGame", MUTED, x, y, KEY_W)
            n = n + 1
            self:Put(n, item[2], item.done and "ZoFontGameBold" or "ZoFontGame", item.done and GOLD or (item.dim and DIM or PARCH),
                     x + COL_W - VALUE_W, y, VALUE_W, TEXT_ALIGN_RIGHT)
            if col == COLUMNS - 1 or i == #section.items then y = y + LINE_H end
        end
        for _, line in ipairs(section.lines or {}) do
            n = n + 1
            local text, bold, gold = line, false, false
            if type(line) == "table" then text, bold, gold = line[1], line.bold, line.gold end
            self:Put(n, text, bold and "ZoFontGameBold" or "ZoFontGame", gold and GOLD or (bold and PARCH or MUTED), 0, y, width)
            y = y + LINE_H
        end
        y = y + 12
    end
    for i = n + 1, #self.labels do self.labels[i]:SetHidden(true) end
    ZO_Scroll_ResetToTop(FurysCharacterTracker_DetailsScroll)
    SCENE_MANAGER:ShowTopLevel(FurysCharacterTracker_Details)
    CT.Raise(FurysCharacterTracker_Details)
end

function Details:Hide()
    SCENE_MANAGER:HideTopLevel(FurysCharacterTracker_Details)
end
