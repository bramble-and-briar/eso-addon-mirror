-- shared
-- What the other windows say, with no drawing in it: the details of one character, the Start here
-- page, the brag card, the research timers' top line, and the text for "Copy for Discord".
-- The game windows (UI/) and the offline viewer draw what this file hands them.
--
-- A page is a list of sections: { title =, items = { { key, value, done =, dim = } }, lines = { ... } }.
-- A line is a text, or { text, bold =, gold =, switch = (a switch from Data/Text.lua), url = true }.
local CT = FurysCharacterTracker
local U = CT.Util
local Pages = {}
CT.Pages = Pages

-- Details of one character ---------------------------------------------------------------------

function Pages.DetailsHeader(e)
    local c = e.c
    return e.name, string.format("%s  ·  Level %s %s %s  ·  %s  ·  read from the game %s (%s)", CT.ViewLabel(), c.level or "?",
                                 c.race or "", c.class or "", c.alliance or "", U.Ago(c.lastScan), U.FormatDate(c.lastScan))
end

-- Every file in Trackers/ adds its own: `summary` items go into the Progress block, `sections`
-- become blocks of their own. Two trackers that give a section the same `id` share one block.
function Pages.Details(e)
    local progress = { title = "Progress", items = {}, order = 2 }
    local sections, byId = { progress }, {}
    for _, tracker in ipairs(CT.Trackers.list) do
        for _, item in ipairs(tracker.summary and tracker.summary(e) or {}) do progress.items[#progress.items + 1] = item end
        for _, section in ipairs(tracker.sections and tracker.sections(e) or {}) do
            local shared = section.id and byId[section.id]
            if shared then
                for _, item in ipairs(section.items or {}) do shared.items[#shared.items + 1] = item end
            else
                section.order = section.order or (tracker.id == "picks" and 1) or (tracker.id == "research" and 1000) or (10 + #sections)
                section.items = section.items or {}
                sections[#sections + 1] = section
                if section.id then byId[section.id] = section end
            end
        end
    end
    for index, section in ipairs(sections) do section.index = index end
    table.sort(sections, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.index < b.index
    end)
    return sections
end

-- Start here -------------------------------------------------------------------------------------

-- Whether a switch (Data/Text.lua) is on for the account you are logged in on.
function Pages.SwitchOn(switch)
    local value = CT.sv and CT.sv[switch.field]
    if value == nil then return switch.unsetIsOn end
    return value == true
end

function Pages.Start()
    local sections = {}
    for _, def in ipairs(CT.TEXT.START) do
        local section = { title = def.title, lines = {} }
        if def.switches and CT.live then
            for _, switch in ipairs(CT.TEXT.SWITCHES) do
                local on = Pages.SwitchOn(switch)
                section.lines[#section.lines + 1] = { string.format("[ %s ]  %s: %s  Click to turn it %s.", on and "ON" or "off", switch.label,
                                                                    switch.about, on and "off" or "on"), switch = switch }
            end
        elseif def.switches then
            section.title = "4. Alerts"
            section.lines[1] = CT.TEXT.START_VIEWER
        else
            for _, line in ipairs(def.lines) do
                -- A line can read differently in the offline viewer, or be left out there.
                if type(line) == "table" and not CT.live and line.viewer ~= nil then line = line.viewer end
                if line then section.lines[#section.lines + 1] = line end
            end
        end
        sections[#sections + 1] = section
    end
    -- 1.5.7: the other Fury addons, the same lines as in every Fury addon (UI/Theme.lua). In game only.
    if CT.live then
        local more = { title = "6. " .. CT.Theme.MORE_TITLE, lines = {} }
        for _, entry in ipairs(CT.Theme.More()) do
            more.lines[#more.lines + 1] = { entry.name .. ": " .. entry.about .. "  Click for its ESOUI page (the game asks first).", more = entry.url }
        end
        more.lines[#more.lines + 1] = CT.Theme.MORE_FOOT
        sections[#sections + 1] = more
    end
    return sections
end

function Pages.StartHeader()
    return "Start here", "Fury's Character Tracker v" .. CT.version .. "  ·  open this page again with the Start here button on the board" .. (CT.live and ", or /fct start" or "")
end

-- Research timers -----------------------------------------------------------------------------

function Pages.TimersSummary(rows)
    if #rows == 0 then
        return "Nothing to show: every character here knows every trait, or none has been read yet (log in on each once)."
    end
    local running, waiting = 0, 0
    for _, row in ipairs(rows) do
        if row.kind == "timer" then running = running + 1 else waiting = waiting + (row.count or 1) end
    end
    local summary = string.format("%d researching  ·  %s free", running, U.Count(waiting, "slot"))
    if not CT.IsHome() then summary = summary .. "  ·  as saved at that account's last logout" end
    return summary
end

-- "Sat Nov 21, 03:15 PM"
function Pages.When(timestamp)
    return os.date("%a %b %d, %I:%M %p", timestamp)
end

-- One line of the research timers window, as text: { name, craft, item, trait, left, ends },
-- and waiting = true when the slot needs you (finished or idle).
function Pages.TimerRow(row, now)
    if row.kind == "timer" then
        return { name = row.name, craft = row.craftName, item = row.item, trait = row.trait,
                 left = U.Duration(row.endsAt - now), ends = Pages.When(row.endsAt), waiting = false }
    elseif row.kind == "done" then
        return { name = row.name, craft = row.craftName, item = row.item, trait = row.trait, left = "Done", ends = "slot free: start more", waiting = true }
    end
    return { name = row.name, craft = row.craftName, item = U.Count(row.count, "slot") .. " free", trait = "", left = "Idle",
             ends = "nothing researching", waiting = true }
end

-- Brag card -----------------------------------------------------------------------------------

local CLASS_COUNT = 7   -- Dragonknight, Sorcerer, Nightblade, Templar, Warden, Necromancer, Arcanist
local ROLE_KEYS = { "Tank", "Healer", "DPS" }

local function Compute(entries)
    local s = {
        characters = 0, hours = 0, skillPoints = 0, linesMaxed = 0, linesTotal = 0, research = 0, researchAll = 0,
        grandmasters = 0, vampWolf = 0, scribing = 0, companions = 0, riding = 0, bestRecipes = 0, bestRecipesName = "",
        bestAch = 0, bestAchName = "", bestPlans = 0, bestPlansName = "", bestMotifs = 0, bestMotifsName = "",
        recipesTotal = 0, plansTotal = 0, motifsTotal = 0, researchTotal = 0,
        classes = {}, classOrder = {},
    }
    local vamp, wolf = CT.LINE_BY_NAME["Vampire"], CT.LINE_BY_NAME["Werewolf"]
    for _, entry in ipairs(entries) do
        local c, m = entry.c, entry.m
        local lines = c.lines or {}
        s.characters = s.characters + 1
        s.hours = s.hours + (c.playedHours or 0)
        s.skillPoints = s.skillPoints + (c.skillPoints or 0)
        s.research = s.research + (c.research or 0)
        s.researchTotal = s.researchTotal + (c.researchTotal or CT.RESEARCH_TOTAL)
        s.recipesTotal = math.max(s.recipesTotal, c.recipesTotal or 0)
        s.plansTotal = math.max(s.plansTotal, c.furnishingsTotal or 0)
        s.motifsTotal = math.max(s.motifsTotal, c.motifsTotal or 0)

        local craftMaxed = 0
        for _, group in ipairs(CT.GROUPS) do
            local maxed = CT.Roster:MaxedInGroup(c, group)
            s.linesTotal, s.linesMaxed = s.linesTotal + #group.lines, s.linesMaxed + maxed
            if group.id == "crafting" then craftMaxed = maxed end
        end
        local allTraits = (c.research or 0) >= (c.researchTotal or CT.RESEARCH_TOTAL)
        if allTraits then s.researchAll = s.researchAll + 1 end
        if allTraits and craftMaxed >= 7 then s.grandmasters = s.grandmasters + 1 end
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
            if m.role and string.find(m.role, key, 1, true) then s.classes[class][key] = true end
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

-- The card: { title =, subtitle =, tiles = { { value =, label =, note =, pct =, pctText = } }, coverageTitle =,
--             classes = { { name =, roles = { { key =, on = } } } }, date =, credit = }
function Pages.Brag()
    local entries = CT.Roster:List()
    local s = Compute(entries)
    local n = s.characters
    local account = CT.Data().account or {}
    -- Your own account, in game: asked from the game. Otherwise what was saved (nil: not saved yet).
    local cp = CT.IsHome() and GetPlayerChampionPointsEarned() or account.championPoints
    local achTotal = CT.IsHome() and GetTotalAchievementPoints() or account.achievementTotal
    local years = s.hours / 24 / 365.25
    local timeNote = years >= 1 and string.format("%.1f years, nonstop", years) or string.format("%s days, nonstop", U.Comma(s.hours / 24))
    local function OfAll(count) return string.format("%d / %d", count, n) end
    local tiles = {
        { value = U.Comma(s.hours), label = "Hours played", note = timeNote },
        { value = cp and U.Comma(cp) or "?", label = "Champion Points",
          note = cp and ("of " .. U.Comma(CT.CP_MAX) .. ", account-wide") or "log in to read", pct = cp and Pct(cp, CT.CP_MAX) or nil },
        { value = U.Comma(s.bestAch), label = "Most achievement points", note = s.bestAchName, pct = Pct(s.bestAch, achTotal) },
        { value = U.Comma(s.skillPoints), label = "Skill points earned", note = "across " .. U.Count(n, "character"),
          pct = Pct(s.skillPoints, n * CT.SKILL_POINTS_MAX) },
        { value = U.Comma(s.linesMaxed), label = "Skill lines maxed", note = "of " .. U.Comma(s.linesTotal) .. " tracked",
          pct = Pct(s.linesMaxed, s.linesTotal) },
        { value = U.Comma(s.research), label = "Traits researched", note = string.format("%d know every trait", s.researchAll),
          pct = Pct(s.research, s.researchTotal) },
        { value = OfAll(s.grandmasters), label = "Grandmaster crafters", note = "7 crafts at 50 + every trait", pct = Pct(s.grandmasters, n) },
        { value = OfAll(s.vampWolf), label = "Vampire + Werewolf", note = "both lines maxed", pct = Pct(s.vampWolf, n) },
        { value = OfAll(s.scribing), label = "Scribing complete", note = "every grimoire and script", pct = Pct(s.scribing, n) },
        { value = OfAll(s.companions), label = "All companions", note = "every one unlocked", pct = Pct(s.companions, n) },
        { value = OfAll(s.riding), label = "Riding maxed", note = "speed, stamina, carry", pct = Pct(s.riding, n) },
        { value = U.Comma(s.bestRecipes), label = "Most recipes known", note = s.bestRecipesName, pct = Pct(s.bestRecipes, s.recipesTotal) },
        { value = U.Comma(s.bestPlans), label = "Most furnishing plans", note = s.bestPlansName, pct = Pct(s.bestPlans, s.plansTotal) },
        { value = U.Comma(s.bestMotifs), label = "Most motif styles", note = s.bestMotifsName, pct = Pct(s.bestMotifs, s.motifsTotal) },
        { value = U.Comma(account.setPieces), label = "Set items collected",
          note = account.setPiecesTotal and ("of " .. U.Comma(account.setPiecesTotal) .. " (sticker book)") or "log in to read",
          pct = Pct(account.setPieces, account.setPiecesTotal) },
        { value = U.Comma(account.outfitStyles), label = "Outfit styles",
          note = account.outfitStylesTotal and ("of " .. U.Comma(account.outfitStylesTotal)) or "log in to read",
          pct = Pct(account.outfitStyles, account.outfitStylesTotal) },
    }
    for _, tile in ipairs(tiles) do
        if tile.pct then
            -- Whole percent, but never round up to 100% before it is really done.
            local shown = (tile.pct >= 1) and 100 or math.min(99, math.floor(tile.pct * 100 + 0.5))
            tile.pctText = U.Whole(shown) .. "%"
        end
    end

    -- Class x role coverage: a lit role = you have a character playing it.
    local classes, everything = {}, #s.classOrder >= CLASS_COUNT
    for index = 1, CLASS_COUNT do
        local class = s.classOrder[index]
        if class then
            local roles = {}
            for i, key in ipairs(ROLE_KEYS) do
                roles[i] = { key = key, on = s.classes[class][key] == true }
                if not roles[i].on then everything = false end
            end
            classes[index] = { name = class, roles = roles }
        end
    end

    local onAccount = #CT.Roster:AccountRoster()
    local count = (n < onAccount) and string.format("%d of %d characters read%s", n, onAccount, CT.live and " (/fct unread)" or "")
                                  or U.Count(n, "character")
    return {
        title = CT.view and CT.view.account or "",
        subtitle = string.format("%s  ·  %d of %d classes  ·  %s", count, #s.classOrder, CLASS_COUNT, CT.view and CT.view.world or ""),
        tiles = tiles, classes = classes, classCount = CLASS_COUNT,
        coverageTitle = everything and "Every class. Every role." or "Classes & roles",
        date = os.date("%B %d, %Y", GetTimeStamp()), credit = "Fury's Character Tracker v" .. CT.version,
    }
end

-- Copy for Discord -----------------------------------------------------------------------------

local DISCORD_LIMIT = 2000

local function Pad(text, width, right)
    local gap = string.rep(" ", math.max(0, width - #text))
    return right and (gap .. text) or (text .. gap)
end

-- A tab as a text table for Discord (in a code block, so the columns line up).
-- Returns the text and a note for under it.
function Pages.DiscordTable(viewId)
    local snap = CT.Board.Snapshot(viewId)
    local widths = {}
    for i, column in ipairs(snap.columns) do
        widths[i] = #column.title
        for _, row in ipairs(snap.rows) do widths[i] = math.max(widths[i], #row.cells[i].text) end
    end
    local function Line(texts)
        local parts = {}
        for i, column in ipairs(snap.columns) do parts[i] = Pad(texts[i], widths[i], column.align ~= "left") end
        return (table.concat(parts, "  "):gsub("%s+$", ""))
    end
    local titles = {}
    for i, column in ipairs(snap.columns) do titles[i] = column.title end
    local lines = { string.format("**%s**  ·  %s  ·  Fury's Character Tracker", snap.title, CT.view and CT.ViewLabel() or ""), "```", Line(titles) }
    for _, row in ipairs(snap.rows) do
        local texts = {}
        for i, cell in ipairs(row.cells) do texts[i] = cell.text end
        lines[#lines + 1] = Line(texts)
    end
    lines[#lines + 1] = "```"
    local text = table.concat(lines, "\n")
    local note = string.format("%s characters. Press Ctrl+C to copy, then paste into Discord.", U.Comma(#text))
    if #text > DISCORD_LIMIT then
        note = string.format("%s characters: more than the %s one Discord message takes without Nitro. Paste it in two parts, or copy a narrower tab.",
                             U.Comma(#text), U.Comma(DISCORD_LIMIT))
    end
    return text, note
end

-- One character as a few lines for Discord.
function Pages.DiscordCharacter(e)
    local c, Column, Cell = e.c, CT.Trackers.Column, CT.Board.Cell
    local function Text(key) return Cell(Column(key), e).text end
    local lines = { string.format("**%s**  ·  Level %s %s %s  ·  %s", e.name, c.level or "?", c.race or "", c.class or "", c.alliance or "") }
    local first = {}
    if e.m.role then first[#first + 1] = "Role: " .. e.m.role end
    first[#first + 1] = string.format("%s / %s skill points", U.Comma(c.skillPoints), U.Comma(CT.SKILL_POINTS_MAX))
    first[#first + 1] = U.Comma(c.achievementPoints) .. " achievement points"
    first[#first + 1] = U.Comma(c.playedHours) .. " hours"
    lines[#lines + 1] = table.concat(first, "  ·  ")
    local maxed = {}
    for _, group in ipairs(CT.GROUPS) do maxed[#maxed + 1] = group.title .. " " .. Text("group." .. group.id) end
    lines[#lines + 1] = "Lines maxed: " .. table.concat(maxed, "  ·  ")
    lines[#lines + 1] = string.format("Research %s / %s  ·  Riding %s / %s  ·  Companions %s", U.Whole(c.research or 0), U.Whole(c.researchTotal or CT.RESEARCH_TOTAL),
                                      U.Whole(c.riding or 0), U.Whole(c.ridingMax or CT.RIDING_MAX), Text("companions"))
    local sets = CT.GearSets(c, "  ·  ")
    if sets ~= "" then lines[#lines + 1] = "Wearing: " .. sets end
    if e.m.note then lines[#lines + 1] = "Note: " .. e.m.note end
    return table.concat(lines, "\n"), "Press Ctrl+C to copy, then paste into Discord."
end
