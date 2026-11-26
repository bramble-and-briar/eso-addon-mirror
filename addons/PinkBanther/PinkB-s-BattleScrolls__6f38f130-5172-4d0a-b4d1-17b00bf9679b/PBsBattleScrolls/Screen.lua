PBsBattleScrolls = PBsBattleScrolls or {}
local ADDON = PBsBattleScrolls

---------------------------------------------------------------------------------------------------
-- The breakdown screen
--
-- A window of its own, opened from the game's main menu (Menu.lua), built only from a top-level
-- window, textures and labels (no client template, no client function). Seven pages, LB / RB:
--
--   1 Summary   the fight's numbers, the enemies damaged, the players healed
--   2 Damage    per skill: total, share, DPS, hits, crit rate, biggest hit
--   3 Healing   per skill: total, share, HPS, overheal, hits, crit rate
--   4 Buffs     uptime of set procs, the player's own buffs, buffs from others, debuffs on enemies
--   5 Skills    how often each skill was pressed, and per minute
--   6 Group     the members who shared their readings (Group.lua) and the player: DPS, HPS, shares
--   7 History   the last ten fights; A opens one
--
-- Left / right step through the fights (the one going on first, then the last ten), up / down
-- scroll a list (or choose a fight on the history page), X goes back to the latest fight. A skill's
-- or a buff's icon is drawn beside its name.
--
-- Built the first time it is shown. The font is the largest named gamepad font at which the columns
-- fit, as the client measures them.
---------------------------------------------------------------------------------------------------

local screen = {
    page = 1,
    pinned = nil, -- the record shown; nil = the latest
    top = {}, -- [page] = first row shown
    selected = 1, -- history page: the chosen row
}
ADDON.screen = screen

local NAME = "PBsBattleScrollsScreen"
local PAD = 24
local GAP = 16
local COL_GAP = 18
local ICON_GAP = 8
local SIDE_MARGIN = 60
local TOP_MARGIN = 40
local BOTTOM_RESERVE = 150
local MAX_WIDTH = 1780
local MAX_HEIGHT = 880
local MIN_NAME_WIDTH = 300
local MIN_ROWS = 10
local TITLE_FONT = "ZoFontGamepadBold34"
local TAB_FONT = "ZoFontGamepadBold22"

local FONT_TIERS = {
    { row = "ZoFontGamepad27", head = "ZoFontGamepadBold27" },
    { row = "ZoFontGamepad25", head = "ZoFontGamepadBold25" },
    { row = "ZoFontGamepad22", head = "ZoFontGamepadBold22" },
    { row = "ZoFontGamepad20", head = "ZoFontGamepadBold20" },
}

local ACCENT = { 1, 0.75, 0.3 }
local WHITE = { 0.95, 0.95, 0.92 }
local GREY = { 0.62, 0.65, 0.69 }
local GOLD = { 1, 0.84, 0.25 }
local BACKGROUND = { 0.03, 0.035, 0.07, 1 }
local HIGHLIGHT = { 1, 0.75, 0.3, 0.22 }
local KIND_COLORS = {
    set = { 1, 0.84, 0.25 },
    own = { 0.4, 0.85, 0.45 },
    ext = { 0.4, 0.7, 1 },
    debuff = { 1, 0.42, 0.38 },
}

local L = ADDON.L
local Commas, Percent, Duration = ADDON.Commas, ADDON.Percent, ADDON.Duration

local function Ratio(part, whole)
    if not whole or whole <= 0 then
        return 0
    end
    return part / whole
end

local function PerMinute(count, secs)
    return string.format("%.1f", (count or 0) * 60 / math.max(1, secs or 1))
end

local function KindText(fx)
    if fx.set then
        return L(SI_PBSBS_KIND_SET)
    end
    return L(fx.kind == "own" and SI_PBSBS_KIND_OWN or fx.kind == "ext" and SI_PBSBS_KIND_EXT or SI_PBSBS_KIND_DEBUFF)
end

-- "32.1% (2/5)": the player's share of the group and place in it; "-" without group readings.
local function ShareText(share, rank, group)
    if not share or not group then
        return "-"
    end
    return string.format("%s (%d/%d)", Percent(share), rank or 1, #group)
end

local HEAL_KIND = { self = SI_PBSBS_TARGET_SELF, group = SI_PBSBS_TARGET_GROUP, other = SI_PBSBS_TARGET_OTHER }

local function SkillName(entry)
    local name = entry.name ~= "" and entry.name or ("#" .. tostring(entry.id))
    if entry.pet then
        name = name .. L(SI_PBSBS_PET_SUFFIX)
    end
    return name
end

---------------------------------------------------------------------------------------------------
-- What each table shows
---------------------------------------------------------------------------------------------------

local function Right(sample)
    return { right = true, sample = sample }
end

local function Col(head, spec)
    spec = spec or {}
    spec.head = head
    return spec
end

screen.TABLES = {
    summary = {
        heading = SI_PBSBS_BLOCK_SUMMARY,
        columns = { Col(SI_PBSBS_COL_ITEM, { flex = true }), Col(SI_PBSBS_COL_VALUE, Right("9,999,999 (99.9%)")) },
        rows = function(r)
            local rows = {}
            local function add(label, value, color)
                rows[#rows + 1] = { cells = { L(label), value }, rowColor = color }
            end
            add(SI_PBSBS_SUM_DPS, Commas(r.dmg / r.secs), ACCENT)
            add(SI_PBSBS_SUM_DAMAGE, Commas(r.dmg))
            add(SI_PBSBS_SUM_DMG_CRIT, Percent(Ratio(r.dmgCrits, r.dmgHits)))
            add(SI_PBSBS_SUM_DMG_SHARE, ShareText(r.dmgShare, r.dpsRank, r.group))
            add(SI_PBSBS_SUM_BOSS_SHARE, r.bossShare and Percent(r.bossShare) or "-", r.bossShare and GOLD or nil)
            add(SI_PBSBS_SUM_HPS, Commas(r.heal / r.secs), KIND_COLORS.own)
            add(SI_PBSBS_SUM_HEAL, Commas(r.heal))
            add(SI_PBSBS_SUM_OVERHEAL, string.format("%s (%s)", Commas(r.over), Percent(Ratio(r.over, r.heal + r.over))))
            add(SI_PBSBS_SUM_HEAL_CRIT, Percent(Ratio(r.healCrits, r.healHits)))
            add(SI_PBSBS_SUM_HEAL_SHARE, ShareText(r.healShare, r.healRank, r.group))
            add(SI_PBSBS_SUM_TIME, Duration(r.secs))
            add(SI_PBSBS_SUM_CASTS, string.format("%d (%s/min)", r.castN, PerMinute(r.castN, r.secs)))
            add(SI_PBSBS_SUM_LIGHT, string.format("%d (%s/min)", r.la, PerMinute(r.la, r.secs)))
            add(SI_PBSBS_SUM_HEAVY, tostring(r.ha))
            local sets = 0
            for _, fx in ipairs(r.fx or {}) do
                if fx.set then
                    sets = sets + 1
                end
            end
            add(SI_PBSBS_SUM_PROCS, tostring(sets))
            return rows
        end,
    },
    dmgTargets = {
        heading = SI_PBSBS_BLOCK_DMG_TARGETS,
        -- names are short enough here: the boss column gets the room
        minFlex = 200,
        columns = { Col(SI_PBSBS_COL_TARGET, { flex = true }), Col(SI_PBSBS_COL_TOTAL, Right("9,999,999")), Col(SI_PBSBS_COL_SHARE, Right("100.0%")),
            Col(SI_PBSBS_COL_BOSS_SHARE, Right("100.0%")) },
        rows = function(r)
            local rows = {}
            for _, t in ipairs(r.dmgTgt or {}) do
                local bossShare = ADDON.bosses.TargetShare(r, t.name)
                rows[#rows + 1] = {
                    color = bossShare and GOLD or nil,
                    cells = { t.name, Commas(t.total), Percent(Ratio(t.total, r.dmg)), bossShare and Percent(bossShare) or "" },
                }
            end
            return rows
        end,
    },
    healTargets = {
        heading = SI_PBSBS_BLOCK_HEAL_TARGETS,
        columns = { Col(SI_PBSBS_COL_TARGET, { flex = true }), Col(SI_PBSBS_COL_TOTAL, Right("9,999,999")), Col(SI_PBSBS_COL_KIND, { sample = L(SI_PBSBS_TARGET_GROUP) }) },
        rows = function(r)
            local rows = {}
            for _, t in ipairs(r.healTgt or {}) do
                rows[#rows + 1] = { cells = { t.name, Commas(t.total), L(HEAL_KIND[t.kind] or SI_PBSBS_TARGET_OTHER) } }
            end
            return rows
        end,
    },
    damage = {
        columns = {
            Col(SI_PBSBS_COL_SKILL, { flex = true, icon = true }),
            Col(SI_PBSBS_COL_TOTAL, Right("99,999,999")),
            Col(SI_PBSBS_COL_SHARE, Right("100.0%")),
            Col(SI_PBSBS_COL_DPS, Right("999,999")),
            Col(SI_PBSBS_COL_HITS, Right("9,999")),
            Col(SI_PBSBS_COL_CRIT, Right("100.0%")),
            Col(SI_PBSBS_COL_MAX, Right("999,999")),
        },
        rows = function(r)
            local rows = {}
            for _, a in ipairs(r.dmgAb or {}) do
                rows[#rows + 1] = {
                    icon = ADDON.Icon(a.id), color = a.set and GOLD or nil,
                    cells = { SkillName(a), Commas(a.total), Percent(Ratio(a.total, r.dmg)), Commas(a.total / r.secs),
                        Commas(a.hits), Percent(Ratio(a.crits, a.hits)), Commas(a.max) },
                }
            end
            return rows
        end,
    },
    heal = {
        columns = {
            Col(SI_PBSBS_COL_SKILL, { flex = true, icon = true }),
            Col(SI_PBSBS_COL_TOTAL, Right("99,999,999")),
            Col(SI_PBSBS_COL_SHARE, Right("100.0%")),
            Col(SI_PBSBS_COL_HPS, Right("999,999")),
            Col(SI_PBSBS_COL_OVERHEAL, Right("100.0%")),
            Col(SI_PBSBS_COL_HITS, Right("9,999")),
            Col(SI_PBSBS_COL_CRIT, Right("100.0%")),
        },
        rows = function(r)
            local rows = {}
            for _, a in ipairs(r.healAb or {}) do
                rows[#rows + 1] = {
                    icon = ADDON.Icon(a.id), color = a.set and GOLD or nil,
                    cells = { SkillName(a), Commas(a.total), Percent(Ratio(a.total, r.heal)), Commas(a.total / r.secs),
                        Percent(Ratio(a.over, a.total + a.over)), Commas(a.hits), Percent(Ratio(a.crits, a.hits)) },
                }
            end
            return rows
        end,
    },
    buffs = {
        columns = {
            Col(SI_PBSBS_COL_EFFECT, { flex = true, icon = true }),
            Col(SI_PBSBS_COL_KIND, { sample = L(SI_PBSBS_KIND_DEBUFF) }),
            Col(SI_PBSBS_COL_UPTIME, { right = true, sample = "100.0%", bar = true, minWidth = 360 }),
            Col(SI_PBSBS_COL_TIME, Right("59:59")),
            Col(SI_PBSBS_COL_GAINS, Right("9,999")),
            Col(SI_PBSBS_COL_STACKS, Right("99")),
        },
        rows = function(r)
            local rows = {}
            for _, fx in ipairs(r.fx or {}) do
                local kindKey = fx.set and "set" or fx.kind
                rows[#rows + 1] = {
                    icon = ADDON.Icon(fx.id), color = fx.set and GOLD or nil,
                    bar = Ratio(fx.up, r.secs), barColor = KIND_COLORS[kindKey],
                    cells = { fx.name ~= "" and fx.name or ("#" .. tostring(fx.id)), KindText(fx), Percent(Ratio(fx.up, r.secs)),
                        Duration(fx.up), Commas(fx.gains), fx.stacks and tostring(fx.stacks) or "-" },
                    kindColor = KIND_COLORS[kindKey],
                }
            end
            return rows
        end,
    },
    skills = {
        columns = {
            Col(SI_PBSBS_COL_SKILL, { flex = true, icon = true }),
            Col(SI_PBSBS_COL_CASTS, Right("9,999")),
            Col(SI_PBSBS_COL_SHARE, Right("100.0%")),
            Col(SI_PBSBS_COL_PER_MIN, Right("999.9")),
        },
        rows = function(r)
            local rows = {}
            for _, c in ipairs(r.casts or {}) do
                rows[#rows + 1] = {
                    icon = ADDON.Icon(c.id),
                    cells = { c.name ~= "" and c.name or ("#" .. tostring(c.id)), Commas(c.total), Percent(Ratio(c.total, r.castN)), PerMinute(c.total, r.secs) },
                }
            end
            if r.la > 0 then
                rows[#rows + 1] = { cells = { L(SI_PBSBS_LIGHT_ATTACKS), Commas(r.la), "-", PerMinute(r.la, r.secs) }, rowColor = GREY }
            end
            return rows
        end,
    },
    group = {
        columns = {
            Col(SI_PBSBS_COL_MEMBER, { flex = true }),
            Col(SI_PBSBS_COL_DPS, Right("9,999,999")),
            Col(SI_PBSBS_COL_SHARE, Right("100.0%")),
            Col(SI_PBSBS_COL_HPS, Right("999,999")),
            Col(SI_PBSBS_COL_SHARE, Right("100.0%")),
            Col(SI_PBSBS_COL_TIME, Right("59:59")),
        },
        rows = function(r)
            local rows = {}
            if not r.group then
                rows[1] = { cells = { L(SI_PBSBS_NO_GROUP), "", "", "", "", "" }, rowColor = GREY }
            else
                for index, m in ipairs(r.group) do
                    rows[#rows + 1] = {
                        rowColor = m.self and ACCENT or nil,
                        cells = { index .. "  " .. m.name, Commas(m.dps), Percent(m.dpsShare or 0), Commas(m.hps), Percent(m.hpsShare or 0), Duration(m.secs) },
                    }
                end
            end
            -- The share from the bosses' health counts everybody, add-on or not.
            for _, b in ipairs(r.bosses or {}) do
                rows[#rows + 1] = {
                    rowColor = GOLD,
                    cells = { string.format(L(SI_PBSBS_BOSS_ROW), b.name, ADDON.Short(b.lost)), "", Percent(b.share or 0), "", "", "" },
                }
            end
            return rows
        end,
    },
    history = {
        select = true,
        columns = {
            Col(SI_PBSBS_COL_NUMBER, Right("10")),
            Col(SI_PBSBS_COL_WHEN, { sample = "23:59" }),
            Col(SI_PBSBS_COL_TIME, Right("59:59")),
            Col(SI_PBSBS_COL_DPS, Right("999,999")),
            Col(SI_PBSBS_COL_DPS_SHARE, Right("100.0%")),
            Col(SI_PBSBS_COL_HPS, Right("999,999")),
            Col(SI_PBSBS_COL_HPS_SHARE, Right("100.0%")),
            Col(SI_PBSBS_COL_BOSS_SHARE, Right("100.0%")),
            Col(SI_PBSBS_COL_DAMAGE, Right("99,999,999")),
            Col(SI_PBSBS_COL_TARGET, { flex = true }),
        },
        rows = function(_, list)
            local rows = {}
            for index, r in ipairs(list) do
                rows[#rows + 1] = {
                    rowColor = r.live and ACCENT or nil,
                    cells = { r.live and "*" or tostring(index - (list[1].live and 1 or 0)), ADDON.Clock(r.clock), Duration(r.secs),
                        Commas(r.dmg / r.secs), r.dmgShare and Percent(r.dmgShare) or "-",
                        Commas(r.heal / r.secs), r.healShare and Percent(r.healShare) or "-",
                        r.bossShare and Percent(r.bossShare) or "-", Commas(r.dmg),
                        (r.target ~= "" and r.target or "-") .. (r.zone ~= "" and ("  |  " .. r.zone) or "") },
                }
            end
            return rows
        end,
    },
}

-- Pages: which tables, and how much of the width each takes.
screen.PAGES = {
    { title = SI_PBSBS_PAGE_SUMMARY, tables = { { id = "summary", w = 0.36 }, { id = "dmgTargets", w = 0.32 }, { id = "healTargets", w = 0.32 } } },
    { title = SI_PBSBS_PAGE_DAMAGE, tables = { { id = "damage", w = 1 } }, scroll = true },
    { title = SI_PBSBS_PAGE_HEAL, tables = { { id = "heal", w = 1 } }, scroll = true },
    { title = SI_PBSBS_PAGE_BUFFS, tables = { { id = "buffs", w = 1 } }, scroll = true },
    { title = SI_PBSBS_PAGE_SKILLS, tables = { { id = "skills", w = 1 } }, scroll = true },
    { title = SI_PBSBS_PAGE_GROUP, tables = { { id = "group", w = 1 } }, scroll = true },
    { title = SI_PBSBS_PAGE_HISTORY, tables = { { id = "history", w = 1 } }, select = true },
}
local NUM_PAGES = #screen.PAGES

---------------------------------------------------------------------------------------------------
-- Controls
---------------------------------------------------------------------------------------------------

local serial = 0
local function Create(parent, kind)
    serial = serial + 1
    return WINDOW_MANAGER:CreateControl(NAME .. serial, parent, kind)
end

local function Label(parent, font, width, height, right)
    local label = Create(parent, CT_LABEL)
    label:SetFont(font)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    label:SetMaxLineCount(1)
    label:SetDimensions(width, height)
    if right then
        label:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    end
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return label
end

local function Texture(parent, color)
    local texture = Create(parent, CT_TEXTURE)
    if color then
        texture:SetColor(color[1], color[2], color[3], color[4] or 1)
    end
    return texture
end

local function Place(control, parent, x, y)
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
end

local function Color(control, color)
    control:SetColor(color[1], color[2], color[3], color[4] or 1)
end

local function Width(font, text)
    return ADDON.MeasureText(font, text) or (#text * ADDON.MeasureFont(font) * 0.55)
end

---------------------------------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------------------------------

function screen:Size()
    local width = math.floor(math.min(MAX_WIDTH, GuiRoot:GetWidth() - SIDE_MARGIN * 2))
    local height = math.floor(math.min(MAX_HEIGHT, GuiRoot:GetHeight() - BOTTOM_RESERVE - TOP_MARGIN))
    return math.max(800, width), math.max(500, height)
end

-- Column widths of a table at a tier and total width; the flex column takes the rest. Also returns
-- whether the flex column keeps at least MIN_NAME_WIDTH.
function screen:Columns(spec, tier, width, rowHeight)
    local widths, fixed, flex = {}, 0, nil
    for index, column in ipairs(spec.columns) do
        if column.flex then
            flex = index
        else
            local w = math.max(Width(tier.head, L(column.head)), column.sample and Width(tier.row, column.sample) or 0)
            w = math.max(math.ceil(w) + 4, column.minWidth or 0)
            widths[index] = w
            fixed = fixed + w + COL_GAP
        end
    end
    local iconRoom = 0
    if flex and spec.columns[flex].icon then
        iconRoom = rowHeight + ICON_GAP
    end
    local rest = width - fixed
    if flex then
        widths[flex] = math.max(80, rest - iconRoom)
    end
    return widths, iconRoom, (not flex) or rest - iconRoom >= (spec.minFlex or MIN_NAME_WIDTH)
end

function screen:Metrics(tier, width, height)
    local m = {}
    m.titleHeight = ADDON.MeasureFont(TITLE_FONT) + 6
    m.rowHeight = ADDON.MeasureFont(tier.row) + 8
    m.headHeight = ADDON.MeasureFont(tier.head) + 8
    m.titleY = PAD - 6
    m.subY = m.titleY + m.titleHeight
    m.sub2Y = m.subY + m.rowHeight
    m.lineY = m.sub2Y + m.rowHeight + 6
    m.contentY = m.lineY + 12
    -- Single-table pages: column heads then rows. The summary page has a heading above its heads.
    m.rows = math.floor((height - PAD - m.contentY - m.headHeight) / m.rowHeight)
    m.innerWidth = width - PAD * 2
    return m
end

function screen:Fits(tier, width, height)
    local m = self:Metrics(tier, width, height)
    if m.rows - 1 < MIN_ROWS then
        return false, m
    end
    for _, page in ipairs(self.PAGES) do
        for _, place in ipairs(page.tables) do
            local tableWidth = math.floor(m.innerWidth * place.w) - (place.w < 1 and GAP or 0)
            local _, _, ok = self:Columns(self.TABLES[place.id], tier, tableWidth, m.rowHeight)
            if not ok then
                return false, m
            end
        end
    end
    return true, m
end

function screen:Build()
    if self.root then
        return true
    end
    if not WINDOW_MANAGER or not GuiRoot then
        return false
    end
    local width, height = self:Size()
    local chosen, metrics
    for _, tier in ipairs(FONT_TIERS) do
        local fits, m = self:Fits(tier, width, height)
        chosen, metrics = tier, m
        if fits then
            break
        end
    end
    self.tier, self.m, self.width, self.height = chosen, metrics, width, height
    local m = metrics

    local root = WINDOW_MANAGER:CreateTopLevelWindow(NAME)
    root:SetHidden(true)
    root:SetMouseEnabled(false)
    root:SetDimensions(width, height)
    root:SetAnchor(CENTER, GuiRoot, CENTER, 0, math.floor((TOP_MARGIN - BOTTOM_RESERVE) / 2))
    self.root = root

    local fill = Texture(root, BACKGROUND)
    fill:SetAnchorFill(root)

    self.title = Label(root, TITLE_FONT, math.floor(width * 0.45), m.titleHeight)
    Place(self.title, root, PAD, m.titleY)
    Color(self.title, ACCENT)
    self.title:SetText(ADDON.title)

    -- Page names along the right of the title row; the current one is lit.
    self.tabs = {}
    local right = PAD
    for page = NUM_PAGES, 1, -1 do
        local text = L(self.PAGES[page].title)
        local tabWidth = math.ceil(Width(TAB_FONT, text)) + 8
        local tab = Label(root, TAB_FONT, tabWidth, m.titleHeight, true)
        tab:ClearAnchors()
        tab:SetAnchor(TOPRIGHT, root, TOPRIGHT, -right, m.titleY)
        tab:SetText(text)
        self.tabs[page] = tab
        right = right + tabWidth + 20
    end

    self.sub = Label(root, chosen.head, m.innerWidth, m.rowHeight)
    Place(self.sub, root, PAD, m.subY)
    Color(self.sub, WHITE)
    self.sub2 = Label(root, chosen.row, m.innerWidth, m.rowHeight)
    Place(self.sub2, root, PAD, m.sub2Y)
    Color(self.sub2, GREY)

    local line = Texture(root, { ACCENT[1], ACCENT[2], ACCENT[3], 0.8 })
    line:SetDimensions(m.innerWidth, 2)
    Place(line, root, PAD, m.lineY)

    self.empty = Label(root, chosen.row, m.innerWidth, m.rowHeight)
    Place(self.empty, root, PAD, m.contentY + m.headHeight)
    Color(self.empty, GREY)
    self.empty:SetText(L(SI_PBSBS_NO_FIGHTS))
    self.empty:SetHidden(true)

    self.pageTables = {}
    return true
end

-- One table's controls: a heading (optional), the column heads, and a pool of rows.
function screen:BuildTable(spec, x, width, y, rowCount)
    local m, tier, root = self.m, self.tier, self.root
    local widths, iconRoom = self:Columns(spec, tier, width, m.rowHeight)
    local t = { spec = spec, controls = {}, rows = {}, widths = widths }
    local function keep(control)
        t.controls[#t.controls + 1] = control
        return control
    end

    if spec.heading then
        local heading = keep(Label(root, tier.head, width, m.headHeight))
        Place(heading, root, x, y)
        Color(heading, ACCENT)
        heading:SetText(L(spec.heading))
        y = y + m.headHeight
        rowCount = rowCount - 1
    end

    -- Column x positions.
    local xs, cx = {}, x
    for index, column in ipairs(spec.columns) do
        if column.flex and column.icon then
            cx = cx + iconRoom
        end
        xs[index] = cx
        cx = cx + widths[index] + COL_GAP
    end
    t.xs = xs

    for index, column in ipairs(spec.columns) do
        local head = keep(Label(root, tier.head, widths[index], m.headHeight, column.right))
        Place(head, root, xs[index], y)
        Color(head, GREY)
        head:SetText(L(column.head))
    end
    y = y + m.headHeight

    local iconSize = m.rowHeight - 6
    for r = 1, rowCount do
        local rowY = y + (r - 1) * m.rowHeight
        local row = { cells = {} }
        if spec.select then
            row.highlight = keep(Texture(root, HIGHLIGHT))
            row.highlight:SetDimensions(width, m.rowHeight)
            Place(row.highlight, root, x, rowY)
        end
        for index, column in ipairs(spec.columns) do
            if column.bar then
                row.bar = keep(Texture(root))
                row.barColumn = index
                row.barY = rowY + 4
            end
            if column.icon then
                row.icon = keep(Texture(root))
                row.icon:SetDimensions(iconSize, iconSize)
                Place(row.icon, root, xs[index] - iconRoom, rowY + 3)
            end
        end
        for index, column in ipairs(spec.columns) do
            local cell = keep(Label(root, tier.row, widths[index], m.rowHeight, column.right))
            Place(cell, root, xs[index], rowY)
            row.cells[index] = cell
        end
        t.rows[r] = row
    end
    t.rowCount = rowCount
    return t
end

function screen:EnsurePage(page)
    local built = self.pageTables[page]
    if built then
        return built
    end
    local m = self.m
    built = {}
    local x = PAD
    for _, place in ipairs(self.PAGES[page].tables) do
        local tableWidth = math.floor(m.innerWidth * place.w) - (place.w < 1 and GAP or 0)
        built[#built + 1] = self:BuildTable(self.TABLES[place.id], x, tableWidth, m.contentY, m.rows + 1)
        x = x + tableWidth + (place.w < 1 and GAP or 0)
    end
    self.pageTables[page] = built
    return built
end

local function ShowTable(t, shown)
    for _, control in ipairs(t.controls) do
        control:SetHidden(not shown)
    end
end

---------------------------------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------------------------------

-- The fights that can be shown: the one going on first, then the history, newest first.
function screen:FightList()
    local list = {}
    local snapshot = ADDON.fights:Snapshot()
    if snapshot then
        list[1] = snapshot
    end
    for _, record in ipairs(ADDON.history) do
        list[#list + 1] = record
    end
    return list
end

function screen:CurrentIndex(list)
    if self.pinned then
        for index, record in ipairs(list) do
            if record == self.pinned then
                return index
            end
        end
        self.pinned = nil
    end
    return 1
end

local function DrawRow(t, row, data)
    local hidden = data == nil
    for index, cell in ipairs(row.cells) do
        cell:SetHidden(hidden)
        if data then
            cell:SetText(data.cells[index] or "")
            local color = data.rowColor or (index == 1 and data.color) or (index == 2 and data.kindColor) or WHITE
            Color(cell, color)
        end
    end
    if row.icon then
        if data and data.icon then
            row.icon:SetTexture(data.icon)
            row.icon:SetHidden(false)
        else
            row.icon:SetHidden(true)
        end
    end
    if row.bar then
        if data and data.bar and data.bar > 0 then
            local full = t.widths[row.barColumn]
            row.bar:SetDimensions(math.max(2, math.floor(full * math.min(1, data.bar))), screen.m.rowHeight - 8)
            Place(row.bar, screen.root, t.xs[row.barColumn], row.barY)
            local c = data.barColor or ACCENT
            row.bar:SetColor(c[1], c[2], c[3], 0.45)
            row.bar:SetHidden(false)
        else
            row.bar:SetHidden(true)
        end
    end
    if row.highlight then
        row.highlight:SetHidden(true)
    end
end

function screen:DrawTable(t, record, list, first, selected)
    local rows = record and t.spec.rows(record, list) or {}
    t.total = #rows
    for r = 1, t.rowCount do
        local data = rows[first + r - 1]
        DrawRow(t, t.rows[r], data)
        if t.rows[r].highlight and data and first + r - 1 == selected then
            t.rows[r].highlight:SetHidden(false)
        end
    end
    return #rows
end

function screen:Header(record, index)
    if not record then
        self.sub:SetText(L(SI_PBSBS_NO_FIGHTS_SHORT))
        self.sub2:SetText("")
        return
    end
    local which = record.live and L(SI_PBSBS_LIVE)
        or string.format(L(SI_PBSBS_FIGHT_OF), index - (self.list[1] and self.list[1].live and 1 or 0), #ADDON.history)
    local target = record.target ~= "" and record.target or "-"
    self.sub:SetText(string.format(L(SI_PBSBS_HEADER), which, ADDON.Clock(record.clock), Duration(record.secs), target))
    self.sub2:SetText(string.format(L(SI_PBSBS_HEADER2), Commas(record.dmg / record.secs), Commas(record.dmg),
        Commas(record.heal / record.secs), Commas(record.heal), record.zone ~= "" and record.zone or "-"))
end

function screen:Refresh()
    if not self:Build() then
        return
    end
    local list = self:FightList()
    self.list = list
    local index = self:CurrentIndex(list)
    local record = list[index]
    self:Header(record, index)

    for page = 1, NUM_PAGES do
        Color(self.tabs[page], page == self.page and ACCENT or GREY)
    end
    for page, built in pairs(self.pageTables) do
        if page ~= self.page then
            for _, t in ipairs(built) do
                ShowTable(t, false)
            end
        end
    end

    local spec = self.PAGES[self.page]
    local built = self:EnsurePage(self.page)
    local isHistory = spec.select
    local showEmpty = (record == nil)
    self.empty:SetHidden(not showEmpty)
    for _, t in ipairs(built) do
        ShowTable(t, not showEmpty)
        if not showEmpty then
            local first = 1
            if spec.scroll then
                first = self.top[self.page] or 1
            elseif isHistory then
                self.selected = math.max(1, math.min(self.selected, #list))
                first = self.top[self.page] or 1
                if self.selected < first then
                    first = self.selected
                elseif self.selected >= first + t.rowCount then
                    first = self.selected - t.rowCount + 1
                end
                self.top[self.page] = first
            end
            local total = self:DrawTable(t, record, list, first, isHistory and self.selected or nil)
            -- A list that got shorter: show its end.
            if spec.scroll and first > 1 and first > total - t.rowCount + 1 then
                self.top[self.page] = math.max(1, total - t.rowCount + 1)
            end
        end
    end
end

---------------------------------------------------------------------------------------------------
-- Input (keybind strip callbacks)
---------------------------------------------------------------------------------------------------

-- The A button comes and goes with the page: the strip is told to look again.
local function UpdateStrip()
    local binds = ADDON.menu and ADDON.menu.binds
    if binds and KEYBIND_STRIP and KEYBIND_STRIP.UpdateKeybindButtonGroup then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(binds)
    end
end

function screen:MovePage(delta)
    self.page = (self.page - 1 + delta) % NUM_PAGES + 1
    if self.page == NUM_PAGES then
        self.selected = self:CurrentIndex(self.list or self:FightList())
    end
    self:Refresh()
    UpdateStrip()
end

function screen:MoveFight(delta)
    local list = self.list or self:FightList()
    if #list == 0 then
        return
    end
    local index = math.max(1, math.min(#list, self:CurrentIndex(list) + delta))
    -- The first one is "the latest": it stays the latest when a new fight comes in.
    self.pinned = index > 1 and list[index] or nil
    self.selected = index
    self:Refresh()
end

function screen:MoveRow(delta)
    local spec = self.PAGES[self.page]
    if spec.select then
        self.selected = self.selected + delta
        self:Refresh()
        return
    end
    if not spec.scroll then
        return
    end
    local built = self.pageTables[self.page]
    local t = built and built[1]
    if not t then
        return
    end
    local maxFirst = math.max(1, (t.total or 0) - t.rowCount + 1)
    self.top[self.page] = math.max(1, math.min(maxFirst, (self.top[self.page] or 1) + delta))
    self:Refresh()
end

-- History page: A opens the chosen fight on the summary page.
function screen:Activate()
    local list = self.list or self:FightList()
    local record = list[self.selected]
    if not record then
        return
    end
    self.pinned = (self.selected > 1) and record or nil
    self.page = 1
    self:Refresh()
    UpdateStrip()
end

function screen:Latest()
    self.pinned = nil
    self.selected = 1
    self.top = {}
    self:Refresh()
end

function screen:Keybinds()
    local group = { alignment = KEYBIND_STRIP_ALIGN_LEFT }
    local function bind(keybind, name, callback, ethereal, visible)
        group[#group + 1] = { keybind = keybind, name = name, callback = callback, ethereal = ethereal, visible = visible }
    end
    bind("UI_SHORTCUT_NEGATIVE", L(SI_PBSBS_KEY_BACK), function() SCENE_MANAGER:HideCurrentScene() end)
    bind("UI_SHORTCUT_PRIMARY", L(SI_PBSBS_KEY_OPEN), function() self:Activate() end, false, function() return self.PAGES[self.page].select == true end)
    bind("UI_SHORTCUT_SECONDARY", L(SI_PBSBS_KEY_LATEST), function() self:Latest() end)
    bind("UI_SHORTCUT_LEFT_SHOULDER", L(SI_PBSBS_KEY_PREV_PAGE), function() self:MovePage(-1) end)
    bind("UI_SHORTCUT_RIGHT_SHOULDER", L(SI_PBSBS_KEY_NEXT_PAGE), function() self:MovePage(1) end)
    bind("UI_SHORTCUT_INPUT_LEFT", L(SI_PBSBS_KEY_NEWER), function() self:MoveFight(-1) end, true)
    bind("UI_SHORTCUT_INPUT_RIGHT", L(SI_PBSBS_KEY_OLDER), function() self:MoveFight(1) end, true)
    bind("UI_SHORTCUT_INPUT_UP", L(SI_PBSBS_KEY_UP), function() self:MoveRow(-1) end, true)
    bind("UI_SHORTCUT_INPUT_DOWN", L(SI_PBSBS_KEY_DOWN), function() self:MoveRow(1) end, true)
    return group
end
