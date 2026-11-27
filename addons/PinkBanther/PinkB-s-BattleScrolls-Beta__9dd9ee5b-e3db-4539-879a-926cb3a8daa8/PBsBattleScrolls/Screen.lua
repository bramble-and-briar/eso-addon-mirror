PBsBattleScrolls = PBsBattleScrolls or {}
local ADDON = PBsBattleScrolls

---------------------------------------------------------------------------------------------------
-- The breakdown screen
--
-- A window of its own, opened from the game's main menu (Menu.lua), built only from a top-level
-- window, textures and labels (no client template, no client function). Six pages, LB / RB:
--
--   1 Summary   the fight's numbers | damage by skill (top) + by target | buff uptime (top) + healing
--               by skill (top): the whole fight on one page
--   2 Damage    per skill: total, share, hits, crit rate, biggest hit | per target
--   3 Healing   per skill: total, share, overheal, hits, crit rate | per target
--               (no per-skill DPS / HPS: it is the total over the same time, so it says the same)
--   4 Buffs     uptime of set procs, own buffs, buffs from others, debuffs on enemies | skills pressed
--   5 Group     the members who shared their readings (Group.lua) and the player: DPS, HPS, shares
--   6 History   the last ten fights; A opens one
--
-- A page is columns side by side; a column holds one table or a few stacked. A table's name stands
-- in its first column head, so it costs no row of its own; rows are striped so a wide row stays easy
-- to follow.
--
-- Left / right step through the fights (the one going on first, then the last ten), up / down
-- scroll the lists (or choose a fight on the history page), X goes back to the latest fight. A
-- skill's or a buff's icon is drawn beside its name.
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
local GAP = 28 -- between the columns of a page
local COL_GAP = 16 -- between the columns of a table
local ICON_GAP = 6
local ROW_SPACE = 4 -- a row is the font's height and this
local STACK_GAP = 10 -- between tables stacked in one column
local SIDE_MARGIN = 60
local TOP_MARGIN = 40
local BOTTOM_RESERVE = 150
local MAX_WIDTH = 1780
local MAX_HEIGHT = 880
local MIN_NAME_WIDTH = 260
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
local STRIPE = { 1, 1, 1, 0.045 }
local KIND_COLORS = {
    set = { 1, 0.84, 0.25 },
    own = { 0.4, 0.85, 0.45 },
    ext = { 0.4, 0.7, 1 },
    debuff = { 1, 0.42, 0.38 },
}

local L = ADDON.L
local Commas, Percent, Duration = ADDON.Commas, ADDON.Percent, ADDON.Duration
local Shown = ADDON.names.Shown

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

local GREEN = { 0.4, 0.85, 0.45 }

-- head: a string id, or false for a column with no head of its own
local function Col(head, spec)
    spec = spec or {}
    spec.head = head
    return spec
end

screen.TABLES = {
    summary = {
        heading = SI_PBSBS_BLOCK_SUMMARY,
        minFlex = 200,
        -- the item names must fit whole: they are measured for the font choice
        labels = { SI_PBSBS_SUM_DMG_SHARE, SI_PBSBS_SUM_BOSS_SHARE, SI_PBSBS_SUM_HEAL_SHARE, SI_PBSBS_SUM_PROCS, SI_PBSBS_SUM_OVERHEAL },
        columns = { Col(SI_PBSBS_COL_ITEM, { flex = true }), Col(false, Right("999,999 (99.9%)")) },
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
            add(SI_PBSBS_SUM_HPS, Commas(r.heal / r.secs), GREEN)
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
    -- The summary's short lists: the top of the damage, healing and buff pages.
    topDamage = {
        heading = SI_PBSBS_BLOCK_DMG_SKILLS,
        minFlex = 180,
        columns = {
            Col(SI_PBSBS_COL_SKILL, { flex = true, icon = true }),
            Col(SI_PBSBS_COL_SHARE, { right = true, sample = "100.0%", bar = true, minWidth = 170 }),
        },
        rows = function(r)
            local rows = {}
            for _, a in ipairs(r.dmgAb or {}) do
                rows[#rows + 1] = {
                    icon = ADDON.Icon(a.id), color = a.set and GOLD or nil, bar = Ratio(a.total, r.dmg),
                    cells = { SkillName(a), Percent(Ratio(a.total, r.dmg)) },
                }
            end
            return rows
        end,
    },
    topHeal = {
        heading = SI_PBSBS_BLOCK_HEAL_SKILLS,
        minFlex = 180,
        columns = {
            Col(SI_PBSBS_COL_SKILL, { flex = true, icon = true }),
            Col(SI_PBSBS_COL_SHARE, { right = true, sample = "100.0%", bar = true, minWidth = 170 }),
        },
        rows = function(r)
            local rows = {}
            for _, a in ipairs(r.healAb or {}) do
                rows[#rows + 1] = {
                    icon = ADDON.Icon(a.id), color = a.set and GOLD or nil, bar = Ratio(a.total, r.heal), barColor = GREEN,
                    cells = { SkillName(a), Percent(Ratio(a.total, r.heal)) },
                }
            end
            return rows
        end,
    },
    topBuffs = {
        heading = SI_PBSBS_BLOCK_BUFFS,
        minFlex = 180,
        columns = {
            Col(SI_PBSBS_COL_EFFECT, { flex = true, icon = true }),
            Col(SI_PBSBS_COL_UPTIME, { right = true, sample = "100.0%", bar = true, minWidth = 170 }),
        },
        rows = function(r)
            local rows = {}
            for _, fx in ipairs(r.fx or {}) do
                local kindKey = fx.set and "set" or fx.kind
                rows[#rows + 1] = {
                    icon = ADDON.Icon(fx.id), color = fx.set and GOLD or nil,
                    bar = Ratio(fx.up, r.secs), barColor = KIND_COLORS[kindKey],
                    cells = { fx.name ~= "" and fx.name or ("#" .. tostring(fx.id)), Percent(Ratio(fx.up, r.secs)) },
                }
            end
            return rows
        end,
    },
    dmgTargets = {
        heading = SI_PBSBS_BLOCK_DMG_TARGETS,
        -- names are short enough here: the boss column gets the room
        minFlex = 180,
        columns = { Col(SI_PBSBS_COL_TARGET, { flex = true }), Col(SI_PBSBS_COL_TOTAL, Right("9,999,999")), Col(SI_PBSBS_COL_SHARE, Right("100.0%")),
            Col(SI_PBSBS_COL_BOSS_SHARE, Right("100.0%")) },
        rows = function(r)
            local rows = {}
            for _, t in ipairs(r.dmgTgt or {}) do
                local bossShare = ADDON.bosses.TargetShare(r, t.name)
                rows[#rows + 1] = {
                    color = bossShare and GOLD or nil,
                    cells = { Shown(t.name, r.ids), Commas(t.total), Percent(Ratio(t.total, r.dmg)), bossShare and Percent(bossShare) or "" },
                }
            end
            return rows
        end,
    },
    -- The summary's target list: the share drawn as a bar, the boss share; the totals are on page 2.
    dmgTargetsShort = {
        heading = SI_PBSBS_BLOCK_DMG_TARGETS,
        minFlex = 180,
        columns = { Col(SI_PBSBS_COL_TARGET, { flex = true }),
            Col(SI_PBSBS_COL_SHARE, { right = true, sample = "100.0%", bar = true, minWidth = 110 }),
            Col(SI_PBSBS_COL_BOSS_SHARE, Right("100.0%")) },
        rows = function(r)
            local rows = {}
            for _, t in ipairs(r.dmgTgt or {}) do
                local bossShare = ADDON.bosses.TargetShare(r, t.name)
                rows[#rows + 1] = {
                    color = bossShare and GOLD or nil, bar = Ratio(t.total, r.dmg),
                    cells = { Shown(t.name, r.ids), Percent(Ratio(t.total, r.dmg)), bossShare and Percent(bossShare) or "" },
                }
            end
            return rows
        end,
    },
    healTargets = {
        heading = SI_PBSBS_BLOCK_HEAL_TARGETS,
        minFlex = 180,
        columns = { Col(SI_PBSBS_COL_TARGET, { flex = true }), Col(SI_PBSBS_COL_TOTAL, Right("9,999,999")), Col(SI_PBSBS_COL_KIND, { sample = L(SI_PBSBS_TARGET_GROUP) }) },
        rows = function(r)
            local rows = {}
            for _, t in ipairs(r.healTgt or {}) do
                rows[#rows + 1] = { cells = { Shown(t.name, r.ids), Commas(t.total), L(HEAL_KIND[t.kind] or SI_PBSBS_TARGET_OTHER) } }
            end
            return rows
        end,
    },
    damage = {
        columns = {
            Col(SI_PBSBS_COL_SKILL, { flex = true, icon = true }),
            Col(SI_PBSBS_COL_TOTAL, Right("99,999,999")),
            Col(SI_PBSBS_COL_SHARE, { right = true, sample = "100.0%", bar = true, minWidth = 100 }),
            Col(SI_PBSBS_COL_HITS, Right("9,999")),
            Col(SI_PBSBS_COL_CRIT, Right("100.0%")),
            Col(SI_PBSBS_COL_MAX, Right("999,999")),
        },
        rows = function(r)
            local rows = {}
            for _, a in ipairs(r.dmgAb or {}) do
                rows[#rows + 1] = {
                    icon = ADDON.Icon(a.id), color = a.set and GOLD or nil, bar = Ratio(a.total, r.dmg),
                    cells = { SkillName(a), Commas(a.total), Percent(Ratio(a.total, r.dmg)),
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
            Col(SI_PBSBS_COL_SHARE, { right = true, sample = "100.0%", bar = true, minWidth = 100 }),
            Col(SI_PBSBS_COL_OVERHEAL, Right("100.0%")),
            Col(SI_PBSBS_COL_HITS, Right("9,999")),
            Col(SI_PBSBS_COL_CRIT, Right("100.0%")),
        },
        rows = function(r)
            local rows = {}
            for _, a in ipairs(r.healAb or {}) do
                rows[#rows + 1] = {
                    icon = ADDON.Icon(a.id), color = a.set and GOLD or nil, bar = Ratio(a.total, r.heal), barColor = GREEN,
                    cells = { SkillName(a), Commas(a.total), Percent(Ratio(a.total, r.heal)),
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
            Col(SI_PBSBS_COL_UPTIME, { right = true, sample = "100.0%", bar = true, minWidth = 220 }),
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
            Col(SI_PBSBS_COL_PER_MIN, Right("999.9")),
        },
        rows = function(r)
            local rows = {}
            for _, c in ipairs(r.casts or {}) do
                rows[#rows + 1] = {
                    icon = ADDON.Icon(c.id),
                    cells = { c.name ~= "" and c.name or ("#" .. tostring(c.id)), Commas(c.total), PerMinute(c.total, r.secs) },
                }
            end
            if r.la > 0 then
                rows[#rows + 1] = { cells = { L(SI_PBSBS_LIGHT_ATTACKS), Commas(r.la), PerMinute(r.la, r.secs) }, rowColor = GREY }
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
                        cells = { index .. "  " .. Shown(m.name, r.ids), Commas(m.dps), Percent(m.dpsShare or 0), Commas(m.hps), Percent(m.hpsShare or 0), Duration(m.secs) },
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
                        (r.target ~= "" and Shown(r.target, r.ids) or "-") .. (r.zone ~= "" and ("  |  " .. r.zone) or "") },
                }
            end
            return rows
        end,
    },
}

-- Pages: columns side by side (w = the share of the width), each with its tables top to bottom.
-- In a column of several tables, each but the last takes `split` of the column's rows.
screen.PAGES = {
    { title = SI_PBSBS_PAGE_SUMMARY, columns = {
        { w = 0.315, tables = { "summary" } },
        { w = 0.365, tables = { "topDamage", "dmgTargetsShort" }, split = 0.58 },
        { w = 0.32, tables = { "topBuffs", "topHeal" }, split = 0.58 },
    } },
    { title = SI_PBSBS_PAGE_DAMAGE, scroll = true, columns = { { w = 0.63, tables = { "damage" } }, { w = 0.37, tables = { "dmgTargets" } } } },
    { title = SI_PBSBS_PAGE_HEAL, scroll = true, columns = { { w = 0.63, tables = { "heal" } }, { w = 0.37, tables = { "healTargets" } } } },
    { title = SI_PBSBS_PAGE_BUFFS, scroll = true, columns = { { w = 0.61, tables = { "buffs" } }, { w = 0.39, tables = { "skills" } } } },
    { title = SI_PBSBS_PAGE_GROUP, scroll = true, columns = { { w = 1, tables = { "group" } } } },
    { title = SI_PBSBS_PAGE_HISTORY, select = true, columns = { { w = 1, tables = { "history" } } } },
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

local function HeadText(column)
    return column.head and L(column.head) or ""
end

-- Column widths of a table at a tier and total width; the flex column takes the rest. Also returns
-- whether the flex column keeps at least its minimum (the table's minFlex or MIN_NAME_WIDTH), with
-- room for the table's name when that stands in its head.
function screen:Columns(spec, tier, width, rowHeight)
    local widths, fixed, flex = {}, 0, nil
    for index, column in ipairs(spec.columns) do
        if column.flex then
            flex = index
        else
            local w = math.max(Width(tier.head, HeadText(column)), column.sample and Width(tier.row, column.sample) or 0)
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
    local need = spec.minFlex or MIN_NAME_WIDTH
    for _, label in ipairs(spec.labels or {}) do
        need = math.max(need, math.ceil(Width(tier.row, L(label))) + 4)
    end
    if spec.heading then
        -- the name is written from the icon's place on
        need = math.max(need, math.ceil(Width(tier.head, L(spec.heading))) + 4 - iconRoom)
    end
    return widths, iconRoom, (not flex) or rest - iconRoom >= need
end

function screen:Metrics(tier, width, height)
    local m = {}
    m.titleHeight = ADDON.MeasureFont(TITLE_FONT) + 4
    m.rowHeight = ADDON.MeasureFont(tier.row) + ROW_SPACE
    m.headHeight = ADDON.MeasureFont(tier.head) + ROW_SPACE
    m.titleY = PAD - 8
    -- one line under the title: which fight on the left, its numbers on the right
    m.subY = m.titleY + m.titleHeight
    m.lineY = m.subY + m.rowHeight + 4
    m.contentY = m.lineY + 8
    m.bottom = height - PAD + 8
    -- rows of a table that has the whole height
    m.rows = math.floor((m.bottom - m.contentY - m.headHeight) / m.rowHeight)
    m.innerWidth = width - PAD * 2
    return m
end

-- Where each column of a page goes: { x, width } in the window.
function screen:ColumnPlaces(page, m)
    local places, x = {}, PAD
    local columns = page.columns
    for index, column in ipairs(columns) do
        local w
        if index == #columns then
            w = PAD + m.innerWidth - x
        else
            w = math.floor(m.innerWidth * column.w) - GAP
        end
        places[index] = { x = x, w = w }
        x = x + w + GAP
    end
    return places
end

-- The tables of a column, top to bottom: { id, y, bottom }.
function screen:Stack(column, m)
    local stack, y = {}, m.contentY
    local count = #column.tables
    local slots = math.floor((m.bottom - m.contentY - (count - 1) * STACK_GAP) / m.rowHeight)
    for index, id in ipairs(column.tables) do
        local bottom = m.bottom
        if index < count then
            bottom = y + math.floor(slots * (column.split or 0.5)) * m.rowHeight
        end
        stack[index] = { id = id, y = y, bottom = bottom }
        y = bottom + STACK_GAP
    end
    return stack
end

function screen:Fits(tier, width, height)
    local m = self:Metrics(tier, width, height)
    if m.rows < MIN_ROWS then
        return false, m
    end
    for _, page in ipairs(self.PAGES) do
        local places = self:ColumnPlaces(page, m)
        for index, column in ipairs(page.columns) do
            for _, id in ipairs(column.tables) do
                local _, _, ok = self:Columns(self.TABLES[id], tier, places[index].w, m.rowHeight)
                if not ok then
                    return false, m
                end
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
        right = right + tabWidth + 24
    end

    -- Which fight (left) and its numbers (right) share one line.
    local subWidth = math.floor(m.innerWidth * 0.42) - GAP
    self.sub = Label(root, chosen.head, subWidth, m.rowHeight)
    Place(self.sub, root, PAD, m.subY)
    Color(self.sub, WHITE)
    self.sub2 = Label(root, chosen.row, m.innerWidth - subWidth - GAP, m.rowHeight, true)
    Place(self.sub2, root, PAD + subWidth + GAP, m.subY)
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

-- One table's controls: the column heads (the first one carries the table's name when it has one)
-- and a pool of rows down to `bottom`.
function screen:BuildTable(id, x, width, y, bottom)
    local spec = self.TABLES[id]
    local m, tier, root = self.m, self.tier, self.root
    local widths, iconRoom = self:Columns(spec, tier, width, m.rowHeight)
    local t = { id = id, spec = spec, controls = {}, rows = {}, widths = widths }
    local function keep(control)
        t.controls[#t.controls + 1] = control
        return control
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
        local named = spec.heading and index == 1
        local headX, headWidth = xs[index], widths[index]
        if named and column.icon then
            headX, headWidth = x, widths[index] + iconRoom
        end
        local head = keep(Label(root, tier.head, headWidth, m.headHeight, column.right))
        Place(head, root, headX, y)
        Color(head, named and ACCENT or GREY)
        head:SetText(named and L(spec.heading) or HeadText(column))
    end
    y = y + m.headHeight

    local rowCount = math.max(1, math.floor((bottom - y) / m.rowHeight))
    local iconSize = m.rowHeight - 4
    for r = 1, rowCount do
        local rowY = y + (r - 1) * m.rowHeight
        local row = { cells = {} }
        if r % 2 == 1 then
            row.stripe = keep(Texture(root, STRIPE))
            row.stripe:SetDimensions(width, m.rowHeight)
            Place(row.stripe, root, x, rowY)
        end
        if spec.select then
            row.highlight = keep(Texture(root, HIGHLIGHT))
            row.highlight:SetDimensions(width, m.rowHeight)
            Place(row.highlight, root, x, rowY)
        end
        for index, column in ipairs(spec.columns) do
            if column.bar then
                row.bar = keep(Texture(root))
                row.barColumn = index
                row.barY = rowY + 3
            end
            if column.icon then
                row.icon = keep(Texture(root))
                row.icon:SetDimensions(iconSize, iconSize)
                Place(row.icon, root, xs[index] - iconRoom, rowY + 2)
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
    local spec = self.PAGES[page]
    built = {}
    local places = self:ColumnPlaces(spec, m)
    for index, column in ipairs(spec.columns) do
        for _, item in ipairs(self:Stack(column, m)) do
            built[#built + 1] = self:BuildTable(item.id, places[index].x, places[index].w, item.y, item.bottom)
        end
    end
    self.pageTables[page] = built
    return built
end

-- A page's table by its id (tests, and the summary's lookups).
function screen:FindTable(page, id)
    for _, t in ipairs(self:EnsurePage(page)) do
        if t.id == id then
            return t
        end
    end
    return nil
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
            row.bar:SetDimensions(math.max(2, math.floor(full * math.min(1, data.bar))), screen.m.rowHeight - 6)
            Place(row.bar, screen.root, t.xs[row.barColumn], row.barY)
            local c = data.barColor or ACCENT
            row.bar:SetColor(c[1], c[2], c[3], 0.45)
            row.bar:SetHidden(false)
        else
            row.bar:SetHidden(true)
        end
    end
    if row.stripe then
        row.stripe:SetHidden(hidden)
    end
    if row.highlight then
        row.highlight:SetHidden(true)
    end
end

-- Draws the rows from `first` on; a scrolled list that is shorter than `first` shows its end.
function screen:DrawTable(t, record, list, first, selected)
    local rows = record and t.spec.rows(record, list) or {}
    t.total = #rows
    first = math.max(1, math.min(first, #rows - t.rowCount + 1))
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
    local target = record.target ~= "" and Shown(record.target, record.ids) or "-"
    self.sub:SetText(string.format(L(SI_PBSBS_HEADER), which, ADDON.Clock(record.clock), Duration(record.secs), target))
    self.sub2:SetText(string.format(L(SI_PBSBS_HEADER2), Commas(record.dmg / record.secs), ADDON.Short(record.dmg),
        Commas(record.heal / record.secs), ADDON.Short(record.heal), record.zone ~= "" and record.zone or "-"))
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
    local longest = 0
    for _, t in ipairs(built) do
        ShowTable(t, not showEmpty)
        if not showEmpty then
            local first = 1
            if spec.scroll then
                -- one scroll position for every list of the page; each stops at its own end
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
            longest = math.max(longest, total - t.rowCount + 1)
        end
    end
    -- Lists that got shorter: the scroll position stops where the longest one ends.
    if spec.scroll and not showEmpty and (self.top[self.page] or 1) > math.max(1, longest) then
        self.top[self.page] = math.max(1, longest)
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
    -- Refresh stops it at the end of the page's longest list
    self.top[self.page] = math.max(1, (self.top[self.page] or 1) + delta)
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
