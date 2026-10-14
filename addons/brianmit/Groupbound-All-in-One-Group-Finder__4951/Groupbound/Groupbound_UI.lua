-- Groupbound_UI.lua : the board as a game menu, layout A (picked 2026-10-12: "like part of the
-- game"). Built like the game's Friends list (esoui friendslist_keyboard.lua / keyboardingamescenes
-- .lua): its own scene with the game's right-side background, title, camera framing and keybind
-- strip (E / R / X... are the game's own menu keys), a window on the game's right-panel footprint
-- (930 x 690). Left: category tree with counts, "Yours" (Applicants, Alerts, Post a group), filter
-- checkboxes, your application / listing (or "List again"). Right: the list with column headers
-- (click = sort), or the Applicants / Alerts / Post a group pages. Details of a group: the game's
-- tooltip when you hover it. Applying to a group whose leader checks each player opens a small
-- window for your message first.
--
-- Animations (picked 2026-10-12, quiet like the game's menus):
--   open      the scene fades (game), the divider draws out from the middle
--   rows      hover / selected highlight fade (the game's list highlight)
--   tree      old rows fade out, the new list fades in top to bottom
--   live      a new group fades in while the rows below slide down; gone = fades, gap closes
--   sort      rows glide to their new places
--   apply     the key's label changes ("Applying..."), a spinner in the row, then "Applied"
--   post      the list fades out, the form's fields fade in one by one

local G = Groupbound
local C = G.COLOR
local L = G.L
local Anim = G.Anim
local W = G.W
local Content = G.Content
local Parse = G.Parse
local Board = G.Board
local Finder = G.Finder
local Chat = G.Chat
local UI = {}
G.UI = UI

local SCENE_NAME = "groupbound"
-- (wider and taller than the game's 930 x 690 panel since 2026-10-13: the user wants every text in
-- full, no "..."; long texts wrap and their row grows)
local WIN_W, WIN_H = 1260, 740
local LEFT_X = 30
local TREE_W = 240
local TOP_Y = 100                -- below the divider
local RIGHT_X = LEFT_X + TREE_W + 24
local RIGHT_W = WIN_W - RIGHT_X - 30
local ROW_H = 36
local HEADER_H = 32
local RELIST_FOR = 3 * 3600      -- "List again" is offered for 3 h after your last listing
local WAIT_ICON = "EsoUI/Art/Miscellaneous/wait_icon.dds"

-- list columns: x, width (inside the right side)
-- (the run is its full name: user 2026-10-13, "more neat" than nMOL / vSS)
local COLS = {
    { key = "trial", x = 0, w = 205 },
    { key = "group", x = 209, w = 206 },
    { key = "open", x = 507, w = 176 },
    { key = "leader", x = 687, w = 165 },
    { key = "from", x = 856, w = RIGHT_W - 14 - 856 },
    -- (index 6, between GROUP and OPEN PLACES on screen: "6 / 12" already in the group, user 2026-10-13)
    { key = "size", x = 419, w = 84 },
}
local ROW_PAD = 10               -- a row that grows (wrapped text): space above + below
local ROLE_STEP = 44             -- open places: one role icon + count every 44 px
local ROLE_SLOTS = { "tank", "heal", "dps", "any" }   -- each role's fixed spot in OPEN PLACES

local ui = { rowsById = {}, free = {}, treeItems = {}, checks = {} }
local scene, fragment

-- ---------------------------------------------------------------------------
-- Small helpers

local function Sel()
    return ui.selId and Board.Find(ui.selId) or nil
end

local function ListView()
    local v = G.sv.view
    return v ~= "post" and v ~= "alerts" and v ~= "applicants"
end

local function OpenRoles(e)
    local out = {}
    if not e.need then return out end
    for _, role in ipairs({ "tank", "heal", "dps", "any" }) do
        local n = e.need[role] or 0
        if n > 0 then out[#out + 1] = { role = role, n = n } end
    end
    return out
end

local function StartText(e)
    if e.startNow then return L("START_NOW") end
    if e.startAt then
        local inMin = math.floor((e.startAt - G.Now()) / 60 + 0.5)
        if inMin <= 0 then return L("START_NOW") end
        return L("START_AT", G.ClockText(e.startAt), inMin)
    end
end

-- the RUN column: the full name ("Maelstrom Arena"), else the place, else LFG / LFM
local function RunName(e)
    -- an ad, not a group: say so where the run's name would be
    local ad = Board.AdKind(e)
    if ad == "recruit" then return L("AD_GUILD") end
    if ad == "sale" then return L("AD_SALE") end
    if e.content then return Content.Name(e.content) end
    if e.place and e.place ~= "" then return e.place end
    -- a Group Finder listing we couldn't read: its category in the game's words ("Trial"), not "GF"
    if e.finder and e.cat then
        local name = GetString("SI_GROUPFINDERCATEGORY", e.cat)
        if name and name ~= "" then return name end
    end
    return Board.Tag(e)
end

-- under the name: "Normal" (green) / "Veteran" (gold), "HM" (red-orange); plain for dimmed rows
local function RunDifficulty(e, plain)
    if Board.AdKind(e) then return "" end
    return Board.DifficultyText(e, plain)
end

-- an ad's text, shortened to about two lines at a word ("...click to read all" follows); the
-- opened row shows it all
local AD_CHARS = 90
local function AdShort(text)
    text = text or ""
    if #text <= AD_CHARS then return text, false end
    local cut = text:sub(1, AD_CHARS):gsub("%s+%S*$", "")
    return cut, true
end

local function SourceShort(e)
    if e.finder then return L("FROM_FINDER") end
    return e.src == "guild" and L("FROM_GUILD") or L("FROM_ZONE")
end

local function StatusOf(e)
    if e.full then return L("STATUS_FULL"), C.bad end
    if e.applied then return L("STATUS_APPLIED"), C.good end
    local c = e.contact
    if c then
        if c.replied then return L("STATUS_REPLIED"), C.good end
        return L(c.how == "applied" and "STATUS_APPLIED" or (c.how == "invited" and "STATUS_INVITED" or "STATUS_WHISPERED")), C.good
    end
end

-- "New" mark (2026-10-14): groups that weren't on the board when you last closed it get the game's
-- inventory "new" icon before the run's name. A group = leader + title (a leader with a different
-- group counts as new). ui.seenBase = what was there at the last close (nil the very first time:
-- no marks then); kept in sv.boardSeen across reloads.
local NEW_ICON = "EsoUI/Art/Inventory/newItem_icon.dds"

local function NewKey(e)
    return tostring(e.id) .. "|" .. tostring(Board.Title(e) or "")
end

local function IsNew(e)
    return ui.seenBase ~= nil and not ui.seenBase[NewKey(e)]
end

-- the primary action's name for a group
local function PrimaryName(e)
    if not e then return "" end
    if Board.AdKind(e) then return L("WHISPER") end
    if e.finder then
        if Finder.ApplyPending() then return L("APPLYING") end
        if e.applied then return L("TAKE_BACK") end
        return L(e.auto and "JOIN" or "APPLY")
    end
    if e.kind == "player" then return L("INVITE") end
    return L("WHISPER_ROLE", Board.WhisperText(e))
end

-- ---------------------------------------------------------------------------
-- Keybind strip (the game's own, like the Friends list)

local keys = {}

local function UpdateKeys()
    if not scene or not scene:IsShowing() then return end
    for _, group in pairs(keys) do
        if KEYBIND_STRIP:HasKeybindButtonGroup(group) then KEYBIND_STRIP:RemoveKeybindButtonGroup(group) end
    end
    KEYBIND_STRIP:AddKeybindButtonGroup(keys.static)
    if G.sv.view == "post" then
        KEYBIND_STRIP:AddKeybindButtonGroup(keys.post)
    elseif G.sv.view == "applicants" then
        KEYBIND_STRIP:AddKeybindButtonGroup(keys.apps)
    elseif ListView() then
        KEYBIND_STRIP:AddKeybindButtonGroup(keys.board)
    end
end

local function RefreshKeys()
    if not scene or not scene:IsShowing() then return end
    for _, group in pairs(keys) do
        if KEYBIND_STRIP:HasKeybindButtonGroup(group) then KEYBIND_STRIP:UpdateKeybindButtonGroup(group) end
    end
end
UI.RefreshKeys = RefreshKeys

-- ---------------------------------------------------------------------------
-- Rows (one control per group id, so rows can glide and fade)

local PaintRowHighlight

-- Look (picked 2026-10-13, sketches B + C + E): a thin divider line between rows, a gold edge on
-- the left of the hovered / picked row, your role's open places with the game's glowing role icon
-- and a gold number (others dim),
-- and the picked row opens up: the leader's text, size / age / CP / achievements, and buttons.
local DETAIL_BTN_H = 30

-- your role's open places (picked 2026-10-13, option B; the square gold frame was "ugly"): the
-- game's own role icon WITH its soft glow (the art the Group menu shows for a picked role:
-- LFG_<role>_down_64.dds; the list's other icons are the _no_glow versions) + the number in gold
local GLOW_ICON = {
    tank = "EsoUI/Art/LFG/LFG_tank_down_64.dds",
    heal = "EsoUI/Art/LFG/LFG_healer_down_64.dds",
    dps = "EsoUI/Art/LFG/LFG_dps_down_64.dds",
}

-- the part under a picked row: leader's text, facts, buttons (made the first time it's needed)
local function MakeDetail(row)
    local d = WINDOW_MANAGER:CreateControl(nil, row, CT_CONTROL)
    d:SetWidth(RIGHT_W - 14 - 24)
    d.text = W.Label(d, "ZoFontGame", C.normal, "")
    d.text:SetAnchor(TOPLEFT, d, TOPLEFT, 0, 0)
    d.text:SetWidth(RIGHT_W - 14 - 24)
    d.info = W.Label(d, "ZoFontGameSmall", C.dim, "")
    d.info:SetWidth(RIGHT_W - 14 - 24)
    local function Btn(fn, width)
        return W.Button(d, "", function()
            local e = row.id and Board.Find(row.id)
            if e then fn(e) end
        end, width)
    end
    d.primary = Btn(function(e) UI.Primary(e) end, 200)
    d.whisper = Btn(function(e) UI.WhisperEmpty(e) end, 160)
    d.alert = Btn(function(e) UI.ToggleWatch(e.content) end, 200)
    d.whisper:SetAnchor(LEFT, d.primary, RIGHT, 10, 0)
    d.alert:SetAnchor(LEFT, d.whisper, RIGHT, 10, 0)
    d:SetHidden(true)
    row.detail = d
    return d
end

local function MakeRow()
    local row = WINDOW_MANAGER:CreateControl(nil, ui.listChild, CT_CONTROL)
    row:SetDimensions(RIGHT_W - 14, ROW_H)
    row:SetMouseEnabled(true)
    -- an even dark background with no gaps between rows (the game's row stripe left dark seams)
    row.bg = W.Tex(row, nil, nil, nil, C.panel, 0.28)
    row.bg:SetAnchorFill(row)
    row.hl = W.Highlight(row, 0.12)
    row.sel = W.Highlight(row, 0.22, 0.16)   -- (light 0.16: user wanted the picked row a bit softer)
    -- divider line on top (hidden on the first row) and the gold edge on the left
    row.line = W.Tex(row, nil, nil, nil, C.normal, 0.18)
    row.line:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
    row.line:SetAnchor(TOPRIGHT, row, TOPRIGHT, 0, 0)
    row.line:SetHeight(1)
    -- (no line limit, no "...": long texts wrap and the row grows, see FitRow)
    local function Col(i, font)
        local l = W.Label(row, font or "ZoFontGame", C.normal)
        l:SetWidth(COLS[i].w - 6)
        l.col = i
        return l
    end
    row.trial = Col(1, "ZoFontGameBold")
    -- difficulty under the run's name ("Veteran · HM")
    row.diff = Col(1, "ZoFontGameSmall")
    row.group = Col(2)
    row.leader = Col(4)
    row.from = Col(5, "ZoFontGameSmall")
    row.unknown = Col(3, "ZoFontGameSmall")
    -- (centered under the MEMBERS header: FitRow gives it the header's width)
    row.size = Col(6)
    row.size:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    row.icons, row.counts = {}, {}
    for i = 1, 4 do
        local icon = W.Tex(row, nil, 32, 32)
        local count = W.Label(row, "ZoFontGameBold", C.normal)
        count:SetAnchor(LEFT, icon, RIGHT, 0, 1)
        row.icons[i], row.counts[i] = icon, count
    end
    row.wait = W.Tex(row, WAIT_ICON, 18, 18)
    row.wait:SetHidden(true)
    row.hover = false

    row:SetHandler("OnMouseEnter", function()
        row.hover = true
        PaintRowHighlight(row)
        -- (the picked row shows everything itself: no tooltip there)
        if row.id ~= ui.selId then UI.RowTooltip(row) end
    end)
    row:SetHandler("OnMouseExit", function()
        row.hover = false
        PaintRowHighlight(row)
        ClearTooltip(InformationTooltip)
    end)
    row:SetHandler("OnMouseUp", function(_, button, upInside)
        if not upInside or not row.id then return end
        if button == MOUSE_BUTTON_INDEX_LEFT then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            ClearTooltip(InformationTooltip)
            -- click the picked row again: it folds up (not the 2nd click of a double-click)
            local now = GetFrameTimeMilliseconds()
            local quick = row.lastClick and now - row.lastClick < 400
            row.lastClick = now
            if row.id ~= ui.selId then
                UI.Select(row.id)
            elseif not quick then
                UI.Select(nil)
            end
        elseif button == MOUSE_BUTTON_INDEX_RIGHT then
            UI.Select(row.id)
            UI.EntryMenu(Board.Find(row.id), row)
        end
    end)
    row:SetHandler("OnMouseDoubleClick", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and row.id then UI.Primary(Board.Find(row.id)) end
    end)
    return row
end

-- the soft light (picked 2026-10-14, sketch C, no gold edge): hover fades it in, the picked row
-- keeps a stronger one
function PaintRowHighlight(row)
    local key = "Groupbound_RowHl" .. tostring(row)
    local picked = row.id ~= nil and row.id == ui.selId
    W.HighlightTo(row.hl, key, row.hover and not picked, 120)
    W.HighlightTo(row.sel, key .. "S", picked, 160)
end

-- the facts under a picked row: age, CP, start, where from; achievements; why you can't join
-- (not the size: the MEMBERS column shows it)
local function DetailInfo(e)
    local parts = {}
    if e.listedAt then
        local listedMin = math.floor((G.Now() - e.listedAt) / 60)
        if listedMin >= 5 then parts[#parts + 1] = L("TT_LISTED", listedMin) end
    end
    if e.cp then parts[#parts + 1] = L("CP_MIN", e.cp) end
    local start = StartText(e)
    if start then parts[#parts + 1] = start end
    local src = Board.SourceText(e)
    if not e.finder then src = src .. ", " .. G.Ago(e.lastSeen) end
    parts[#parts + 1] = src
    if e.lang then parts[#parts + 1] = L("TT_LANG", L("LANG_" .. zo_strupper(e.lang))) end
    if e.voip then parts[#parts + 1] = L("FINDER_VOIP") end
    local lines = { table.concat(parts, "  ·  ") }
    if e.changedAt and G.Now() - e.changedAt > Board.STALE_AFTER then
        lines[#lines + 1] = G.Colorize(C.bad, L("TT_STALE", math.floor((G.Now() - e.changedAt) / 60)))
    end
    for _, id in ipairs(e.achs or {}) do
        local name = G.Achieve.Name(id)
        if name then
            local done, progress = G.Achieve.Status(id)
            local state = done and L("ACH_HAVE") or (progress and L("ACH_MISSING_PROGRESS", progress) or L("ACH_MISSING"))
            lines[#lines + 1] = G.Colorize(done and C.good or C.bad, L("TT_ACH", name, state))
        end
    end
    local note = G.Note(e.account)
    if note and note.good then lines[#lines + 1] = G.Colorize(C.good, L("MARK_GOOD_TAG")) end
    if note and note.note and note.note ~= "" then lines[#lines + 1] = L("TT_NOTE", note.note) end
    if e.why then lines[#lines + 1] = G.Colorize(C.bad, L("WHY_" .. zo_strupper(e.why))) end
    return table.concat(lines, "\n")
end

local function FillDetail(row, e)
    local picked = e.id == ui.selId
    if not picked then
        if row.detail then row.detail:SetHidden(true) end
        row.open = false
        return
    end
    local d = row.detail or MakeDetail(row)
    -- the leader's own words (chat posts already show theirs in the GROUP column)
    local text = ""
    if Board.AdKind(e) then
        -- the whole ad (the GROUP column shows only its start)
        text = e.finder and (e.desc ~= "" and e.desc or e.title) or (e.text or "")
    elseif e.finder then
        text = e.desc ~= "" and e.desc or ""
        if e.chatText and e.chatText ~= "" then
            text = (text ~= "" and text .. "\n" or "") .. L("CHAT_SAYS") .. " " .. e.chatText
        end
    end
    text = Board.Readable(text)
    d.text:SetText(text)
    d.text:SetHidden(text == "")
    d.info:ClearAnchors()
    if text ~= "" then
        d.info:SetAnchor(TOPLEFT, d.text, BOTTOMLEFT, 0, 6)
    else
        d.info:SetAnchor(TOPLEFT, d, TOPLEFT, 0, 0)
    end
    d.info:SetText(DetailInfo(e))
    d.primary:ClearAnchors()
    d.primary:SetAnchor(TOPLEFT, d.info, BOTTOMLEFT, 0, 10)
    d.primary:SetText(PrimaryName(e))
    d.primary:SetEnabled(not Finder.ApplyPending())
    d.whisper:SetText(L("WHISPER"))
    d.alert:SetHidden(e.content == nil)
    if e.content then
        d.alert:SetText(L(G.sv.watches[e.content] and "KEY_ALERT_OFF" or "KEY_ALERT_ON"))
    end
    d:SetHidden(false)
    -- opening: the details fade in
    if not row.open then
        d:SetAlpha(0)
        W.FadeTo(d, "Groupbound_RowD" .. tostring(row), 1, 220)
    end
    row.open = true
end

local function FillRow(row, e)
    row.id = e.id
    local ad = Board.AdKind(e)
    local dimmed = e.fit == "no"
    -- ads: dim text, the label in the guild color
    local textColor = dimmed and C.disabled or (ad and C.dim or C.normal)
    row.trial:SetText((IsNew(e) and zo_iconFormat(NEW_ICON, 16, 16) .. " " or "") .. RunName(e))
    row.trial:SetColor(G.RGBA(dimmed and C.disabled or (ad and C.guild or C.selected)))
    local diff = RunDifficulty(e, dimmed)
    row.diff:SetText(diff)
    row.diff:SetColor(G.RGBA(dimmed and C.disabled or C.dim))
    row.diff:SetHidden(diff == "")
    row.hasDiff = diff ~= ""
    local title = Board.Readable(Board.Title(e))
    if ad then
        local short, cut = AdShort(title)
        title = short
        if cut then title = title .. "  " .. G.Colorize(C.dim, L("AD_MORE")) end
    end
    -- an achievement it asks for: its icon (details when the row opens / in the tooltip)
    if e.achs then
        local icon = G.Achieve.Icon(e.achs[1])
        if icon then title = zo_iconFormat(icon, 20, 20) .. " " .. title end
    end
    -- written in another language than your game: "DE"
    if e.lang and e.lang ~= G.ClientLang() then title = title .. "  " .. G.Colorize(C.dim, zo_strupper(e.lang)) end
    local status, statusColor = StatusOf(e)
    if status then title = title .. "  " .. G.Colorize(statusColor, status) end
    row.group:SetText(title)
    row.group:SetColor(G.RGBA(textColor))
    row.leader:SetText(e.account or "")
    row.leader:SetColor(G.RGBA(textColor))
    row.from:SetText(G.Colorize(Board.SourceColor(e), SourceShort(e)))
    -- members: "6 / 12" (only the Group Finder knows; chat posts don't say)
    if e.finder and (e.size or 0) > 0 then
        row.size:SetText(string.format("%d / %d", e.members or 0, e.size))
    else
        row.size:SetText("")
    end
    row.size:SetColor(G.RGBA(textColor))
    -- open places: every role in its own fixed spot (tank, healer, damage, any), so the same role
    -- lines up down the list; your role (or "any") with the game's glowing icon and a gold number
    local roles = OpenRoles(e)
    local byRole = {}
    for _, r in ipairs(roles) do byRole[r.role] = r end
    local mine = G.MyRole()
    for i, slotRole in ipairs(ROLE_SLOTS) do
        local r = byRole[slotRole]
        row.icons[i]:SetHidden(r == nil)
        row.counts[i]:SetHidden(r == nil)
        local isMine = r ~= nil and (r.role == mine or r.role == "any")
        if r then
            local glow = isMine and not dimmed and GLOW_ICON[r.role]
            row.icons[i]:SetTexture(glow or G.ROLE_ICON[r.role])
            row.icons[i]:SetAlpha(dimmed and 0.4 or (isMine and 1 or 0.45))
            row.counts[i]:SetText(tostring(r.n))
            row.counts[i]:SetColor(G.RGBA(dimmed and textColor or (isMine and C.diffVet or C.dim)))
        end
    end
    row.unknown:SetHidden(#roles > 0 or ad ~= nil)
    if #roles == 0 and not ad then
        row.unknown:SetText(e.kind == "player" and L("ROW_PLAYER") or (e.finder and L("ROW_FULL_ROLES") or L("ROW_ROLES_UNKNOWN")))
        row.unknown:SetColor(G.RGBA(C.dim))
    end
    local waiting = Finder.ApplyPending() and ui.applyingId == e.id
    row.wait:SetHidden(not waiting)
    FillDetail(row, e)
    PaintRowHighlight(row)
    return UI.FitRow(row)
end

-- a row as tall as its longest (wrapped) text (+ the opened details); returns the height. Every
-- column sits in the middle of the top band (baseH); the run's name + difficulty as one block.
function UI.FitRow(row)
    local nameH = row.trial:GetTextHeight() or 0
    local diffH = row.hasDiff and (row.diff:GetTextHeight() or 0) or 0
    local tallest = nameH + diffH
    for _, l in ipairs({ row.group, row.leader, row.from, row.size }) do
        tallest = math.max(tallest, l:GetTextHeight() or 0)
    end
    if not row.unknown:IsHidden() then tallest = math.max(tallest, row.unknown:GetTextHeight() or 0) end
    local baseH = math.max(ROW_H, tallest + ROW_PAD)
    local mid = baseH / 2
    row.trial:ClearAnchors()
    row.trial:SetAnchor(LEFT, row, TOPLEFT, COLS[1].x + 6, mid - diffH / 2)
    row.diff:ClearAnchors()
    row.diff:SetAnchor(TOPLEFT, row.trial, BOTTOMLEFT, 0, 0)
    for _, l in ipairs({ row.group, row.leader, row.from, row.unknown, row.size }) do
        l:ClearAnchors()
        l:SetAnchor(LEFT, row, TOPLEFT, COLS[l.col].x + 6, mid)
    end
    -- "6 / 12" exactly centered under the word MEMBERS
    local headW = ui.sizeHead and ui.sizeHead:GetTextWidth() or 0
    if headW > 0 then row.size:SetWidth(headW) end
    for i = 1, 4 do
        local x = COLS[3].x + (i - 1) * ROLE_STEP
        row.icons[i]:ClearAnchors()
        row.icons[i]:SetAnchor(LEFT, row, TOPLEFT, x, mid)
    end
    row.wait:ClearAnchors()
    row.wait:SetAnchor(RIGHT, row, TOPRIGHT, -6, mid)
    local h = baseH
    if row.open and row.detail then
        local d = row.detail
        d:ClearAnchors()
        d:SetAnchor(TOPLEFT, row, TOPLEFT, COLS[1].x + 6, baseH)
        local textH = d.text:IsHidden() and 0 or ((d.text:GetTextHeight() or 0) + 6)
        local detailH = textH + (d.info:GetTextHeight() or 0) + 10 + DETAIL_BTN_H
        d:SetHeight(detailH)
        h = baseH + detailH + 14
    end
    row.h = h
    row:SetHeight(h)
    return h
end

local function TakeRow()
    local row = table.remove(ui.free)
    if not row then row = MakeRow() end
    row:SetHidden(false)
    return row
end

local function ReleaseRow(row)
    row.id = nil
    row.hover = false
    row:SetHidden(true)
    ui.free[#ui.free + 1] = row
end

local function PlaceRow(row, y, glide)
    local key = "Groupbound_RowY" .. tostring(row)
    local from = row.y or y
    row.y = y
    if not glide or from == y then
        Anim.Stop(key)
        row:ClearAnchors()
        row:SetAnchor(TOPLEFT, ui.listChild, TOPLEFT, 0, y)
        return
    end
    Anim.Run(key, 280, Anim.Out, function(p)
        row:ClearAnchors()
        row:SetAnchor(TOPLEFT, ui.listChild, TOPLEFT, 0, Anim.Lerp(from, y, p))
    end)
end

-- the list in the chosen column order
local SORTERS = {
    trial = function(e) return zo_strlower(RunName(e)) end,
    group = function(e) return zo_strlower(Board.Title(e)) end,
    open = function(e) return -(e.open or (e.need and ((e.need[G.MyRole()] or 0) + (e.need.any or 0))) or 0) end,
    leader = function(e) return zo_strlower(e.account or "") end,
    size = function(e) return -(e.finder and e.members or -1) end,
    from = function(e) return SourceShort(e) end,
}

local function SortedList()
    local list = {}
    for i, e in ipairs(Board.Visible()) do list[i] = e end
    local key = G.sv.sortKey
    local get = SORTERS[key]
    if get then
        local up = G.sv.sortUp
        local rank = {}
        for i, e in ipairs(list) do rank[e] = i end
        table.sort(list, function(a, b)
            local va, vb = get(a), get(b)
            if va ~= vb then
                if up then return va < vb end
                return va > vb
            end
            return rank[a] < rank[b]
        end)
    end
    return list
end

-- mode: "live" (glide + fade new / gone rows), "swap" (tree change: out, then fade in top to
-- bottom) or "now" (no animation)
function UI.LayoutList(mode)
    if not ui.win or not ListView() then return end
    local list = SortedList()
    local wanted = {}
    for _, e in ipairs(list) do wanted[e.id] = true end
    if mode == "swap" then
        for id, row in pairs(ui.rowsById) do
            ui.rowsById[id] = nil
            ReleaseRow(row)
        end
    else
        for id, row in pairs(ui.rowsById) do
            if not wanted[id] then
                ui.rowsById[id] = nil
                if mode == "live" then
                    row.id = nil
                    W.FadeTo(row, "Groupbound_RowA" .. tostring(row), 0, 200, function() ReleaseRow(row) end)
                else
                    ReleaseRow(row)
                end
            end
        end
    end
    local y = 0
    for i, e in ipairs(list) do
        local row = ui.rowsById[e.id]
        if row then
            local h = FillRow(row, e)
            PlaceRow(row, y, mode == "live")
            y = y + h
            Anim.Stop("Groupbound_RowA" .. tostring(row))
            row:SetAlpha(1)
        else
            row = TakeRow()
            ui.rowsById[e.id] = row
            row.y = nil
            local h = FillRow(row, e)
            PlaceRow(row, y, false)
            y = y + h
            if mode == "now" then
                row:SetAlpha(1)
            else
                row:SetAlpha(0)
                local delay = mode == "swap" and math.min(i - 1, 14) * 55 or 0
                local key = "Groupbound_RowA" .. tostring(row)
                if delay > 0 then
                    G.Later(function()
                        if row.id == e.id then W.FadeTo(row, key, 1, 200) end
                    end, delay, "UI")
                else
                    W.FadeTo(row, key, 1, 200)
                end
            end
        end
    end
    ui.listChild:SetHeight(y)
    ui.order = {}
    for i, e in ipairs(list) do
        ui.order[i] = e.id
        -- (divider lines only between rows)
        local row = ui.rowsById[e.id]
        if row then row.line:SetHidden(i == 1) end
    end
    -- (text heights of new labels are only right a moment later: fit again then)
    G.Later(UI.RefitList, 50, "UI")
    UI.PaintEmpty(#list)
    -- the picked group is gone: nothing picked
    if ui.selId and not wanted[ui.selId] then ui.selId = nil end
    UI.PaintHeaders()
end

-- heights again for the rows on screen (no fading, no new rows): wrapped texts settled
function UI.RefitList()
    if not ui.win or not ui.order or not ListView() then return end
    local y = 0
    for _, id in ipairs(ui.order) do
        local row = ui.rowsById[id]
        if row and row.id == id then
            local h = UI.FitRow(row)
            if row.y ~= y then PlaceRow(row, y, false) end
            y = y + h
        end
    end
    ui.listChild:SetHeight(y)
end

-- tree click: the old rows fade out first, then the new list fades in top to bottom
local function SwapList()
    local any = false
    for _, row in pairs(ui.rowsById) do
        any = true
        W.FadeTo(row, "Groupbound_RowA" .. tostring(row), 0, 150)
    end
    if any then
        G.Later(function() UI.LayoutList("swap") end, 150, "UI")
    else
        UI.LayoutList("swap")
    end
end

-- ---------------------------------------------------------------------------
-- Tooltip: the group's details (the game's tooltip, like the Group Finder's)

function UI.RowTooltip(row)
    local e = row.id and Board.Find(row.id)
    if not e then return end
    InitializeTooltip(InformationTooltip, row, RIGHT, -12, 0, LEFT)
    local name = Board.ContentName(e)
    local diff = Board.DifficultyText(e)
    if diff ~= "" then name = name .. "  ·  " .. diff end
    SetTooltipText(InformationTooltip, name)
    local function Line(text, color)
        if text and text ~= "" then
            local c = color or C.normal
            InformationTooltip:AddLine(text, "", c.r, c.g, c.b)
        end
    end
    local function Divider()
        if ZO_Tooltip_AddDivider then ZO_Tooltip_AddDivider(InformationTooltip) end
    end
    Divider()
    if e.finder then
        Line(e.title, C.selected)
        Line(e.desc)
        Line(e.playstyle, C.dim)
        if e.chatText then Line(L("CHAT_SAYS") .. " " .. e.chatText) end
    else
        Line(e.text, C.selected)
    end
    Divider()
    local tags = {}
    for _, t in ipairs({ "prog", "farm", "teach", "score" }) do
        if e.tags and e.tags[t] then tags[#tags + 1] = L("TAG_" .. zo_strupper(t)) end
    end
    if #tags > 0 then Line(table.concat(tags, "  ·  "), C.selected) end
    local roles = OpenRoles(e)
    if #roles > 0 then
        local parts = {}
        for _, r in ipairs(roles) do parts[#parts + 1] = L("ROLE_OPEN", r.n, G.RoleName(r.role)) end
        Line(L("TT_OPEN", table.concat(parts, ", ")))
    elseif e.kind == "player" then
        Line(L("ROLES_PLAYER"))
    else
        Line(e.finder and L("ROLES_FULL") or L("ROLES_UNKNOWN"), C.dim)
    end
    if e.finder then Line(L("FINDER_SIZE", e.members or 0, e.size or 0)) end
    -- how long it's been up, and whether anyone joins (ghost listings stay for ages)
    if e.listedAt then
        local listedMin = math.floor((G.Now() - e.listedAt) / 60)
        if listedMin >= 5 then Line(L("TT_LISTED", listedMin), C.dim) end
    end
    if e.changedAt and G.Now() - e.changedAt > Board.STALE_AFTER then
        Line(L("TT_STALE", math.floor((G.Now() - e.changedAt) / 60)), C.bad)
    end
    if e.cp then Line(L("CP_MIN", e.cp)) end
    -- achievements it asks for, and whether YOU have them
    for _, id in ipairs(e.achs or {}) do
        local name = G.Achieve.Name(id)
        if name then
            local done, progress = G.Achieve.Status(id)
            local state = done and L("ACH_HAVE") or (progress and L("ACH_MISSING_PROGRESS", progress) or L("ACH_MISSING"))
            Line(L("TT_ACH", name, state), done and C.good or C.bad)
        end
    end
    if e.lang then Line(L("TT_LANG", L("LANG_" .. zo_strupper(e.lang))), C.dim) end
    if e.voip then Line(L("FINDER_VOIP")) end
    Line(StartText(e))
    local src = Board.SourceText(e)
    if not e.finder then src = src .. "  ·  " .. G.Ago(e.lastSeen) end
    if (e.count or 1) > 1 then src = src .. "  ·  " .. L("POSTED_TIMES", e.count) end
    Line(src, C.dim)
    local leader = e.account or ""
    if e.char and e.char ~= "" then leader = leader .. " (" .. e.char .. ")" end
    Line(L("TT_LEADER", leader))
    local note = G.Note(e.account)
    if note and note.good then Line(L("MARK_GOOD_TAG"), C.good) end
    if note and note.note and note.note ~= "" then Line(L("TT_NOTE", note.note)) end
    if e.why then Line(L("WHY_" .. zo_strupper(e.why)), C.bad) end
    Line(L("TT_HINT"), C.dim)
end

-- ---------------------------------------------------------------------------
-- Actions

-- sends the application (message = what the leader reads)
local function SendApplication(e, message)
    ui.applyingId = e.id
    Finder.Apply(e, message or Board.ApplyMessage())
    UI.Refresh()
end

function UI.Primary(e)
    if not e then return end
    -- an ad: just an empty whisper (no "+dd 1850 CP" to an advertiser)
    if Board.AdKind(e) then
        UI.WhisperEmpty(e)
        return
    end
    if e.finder then
        if Finder.ApplyPending() then return end
        if e.applied then
            Finder.Rescind()
            return
        end
        -- a leader who checks each player reads a message: write one first (the game's own Apply
        -- window takes over for groups with an invite code, it has its own message box)
        if G.sv.askApplyMsg and not e.auto and not e.invite then
            UI.ApplyDialog(e)
            return
        end
        SendApplication(e)
    elseif e.kind == "player" then
        local ok = pcall(GroupInviteByName, e.account)
        if ok then
            G.Print(L("INVITED", e.account))
            Board.MarkContacted(e, "invited")
        end
    else
        Chat.Whisper(e.account, Board.WhisperText(e))
        Board.MarkContacted(e, "whispered")
    end
end

function UI.WhisperEmpty(e)
    if e then Chat.Whisper(e.account, "") end
end

function UI.ToggleWatch(key)
    if not key then return end
    G.sv.watches[key] = not G.sv.watches[key] or nil
    if G.sv.watches[key] then G.Print(L("ALERT_ADDED", Content.Name(key))) end
    Board.Changed()
    RefreshKeys()
    if G.sv.view == "alerts" then UI.RefreshAlerts() end
    UI.PaintTree()
end

function UI.ToggleGood(account)
    local n = G.EnsureNote(account)
    if not n then return end
    n.good = not n.good or nil
    G.TidyNote(account)
    Board.Changed()
end

function UI.HidePlayer(account)
    local n = G.EnsureNote(account)
    if not n then return end
    n.hidden = true
    G.Print(L("HID_PLAYER", account))
    Board.Changed()
end

-- right-click menu of a row
-- Right-click menu of a group (picked 2026-10-13, sketch D): a header card (the run, difficulty in
-- its color, members, open places for you), then THIS GROUP (join / apply / whisper-as-role, alert
-- me) and the LEADER (whisper, note, good run, hide their groups in red); the game's icons, and
-- the key that does the same on the right (the game's own key text). Click outside closes it.
local EM_W = 300
local EM_ROW_H = 30
local em = { rows = {}, heads = {}, lines = {} }
local EM_ICON = {
    primary = "EsoUI/Art/HUD/radialIcon_inviteGroup_up.dds",
    alert = "EsoUI/Art/Miscellaneous/new_icon.dds",
    whisper = "EsoUI/Art/ChatWindow/chat_notification_up.dds",
    note = "EsoUI/Art/Buttons/edit_up.dds",
    good = "EsoUI/Art/Collections/Favorite_StarOnly.dds",
    hide = "EsoUI/Art/Buttons/cancel_up.dds",
}

-- the key bound to one of the board's actions, as the game writes it (or "")
local function KeyText(action)
    if not action or not ZO_Keybindings_GetHighestPriorityBindingStringFromAction then return "" end
    local ok, text = pcall(ZO_Keybindings_GetHighestPriorityBindingStringFromAction, action)
    return ok and text or ""
end

function UI.CloseEntryMenu()
    if em.win then em.win:SetHidden(true) end
    G.EM:UnregisterForEvent("Groupbound_EntryMenuClick", EVENT_GLOBAL_MOUSE_DOWN)
end

local function CreateEntryMenu()
    local win = WINDOW_MANAGER:CreateTopLevelWindow("Groupbound_EntryMenu")
    win:SetDimensions(EM_W, 100)
    win:SetDrawTier(DT_HIGH)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    W.Backdrop(win)
    em.win = win
    em.title = W.Label(win, "ZoFontGameBold", C.selected, "")
    em.title:SetAnchor(TOPLEFT, win, TOPLEFT, 14, 10)
    em.title:SetWidth(EM_W - 50)
    em.sub = W.Label(win, "ZoFontGameSmall", C.dim, "")
    em.sub:SetAnchor(TOPLEFT, em.title, BOTTOMLEFT, 0, 0)
    em.sub:SetWidth(EM_W - 28)
    -- small x top right (user 2026-10-14): closes the menu
    -- (in-game the texture itself got no mouse events, 2026-10-14: an invisible 26 px click area on
    -- top carries hover + click, and the window's own OnMouseUp checks the spot as a backup)
    local x = W.Tex(win, "EsoUI/Art/Buttons/closeButton_up.dds", 16, 16)
    x:SetAnchor(TOPRIGHT, win, TOPRIGHT, -8, 8)
    x:SetDrawLevel(5)
    local shownOver
    local function Paint(over)
        if over == shownOver then return end
        shownOver = over
        x:SetTexture(over and "EsoUI/Art/Buttons/closeButton_mouseOver.dds" or "EsoUI/Art/Buttons/closeButton_up.dds")
    end
    local function Close()
        PlaySound(SOUNDS.DEFAULT_CLICK)
        Paint(false)
        UI.CloseEntryMenu()
    end
    local hit = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    hit:SetDimensions(26, 26)
    hit:SetAnchor(CENTER, x, CENTER, 0, 0)
    hit:SetDrawLevel(20)
    hit:SetMouseEnabled(true)
    hit:SetHandler("OnMouseEnter", function() Paint(true) end)
    hit:SetHandler("OnMouseExit", function() Paint(false) end)
    hit:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then Close() end
    end)
    win:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and G.IsOver(hit) then Close() end
    end)
    -- (hover by position too, only while the menu is open)
    win:SetHandler("OnUpdate", function() Paint(G.IsOver(hit)) end)
    em.close = x
end

-- (pooled pieces: a heading, a divider line, an action row)
local function EmHead(i)
    local h = em.heads[i]
    if not h then
        h = W.Label(em.win, "ZoFontGameSmall", C.selected, "")
        em.heads[i] = h
    end
    h:SetHidden(false)
    return h
end

local function EmLine(i)
    local l = em.lines[i]
    if not l then
        l = W.Tex(em.win, nil, nil, nil, C.normal, 0.18)
        l:SetHeight(1)
        em.lines[i] = l
    end
    l:SetHidden(false)
    return l
end

local function EmRow(i)
    local row = em.rows[i]
    if not row then
        row = WINDOW_MANAGER:CreateControl(nil, em.win, CT_CONTROL)
        row:SetDimensions(EM_W - 12, EM_ROW_H)
        row:SetMouseEnabled(true)
        row.hl = W.Highlight(row, 0.15)
        row.icon = W.Tex(row, nil, 20, 20)
        row.icon:SetAnchor(LEFT, row, LEFT, 10, 0)
        row.label = W.Label(row, "ZoFontGame", C.normal, "")
        row.label:SetAnchor(LEFT, row, LEFT, 40, 0)   -- (fixed, so smaller icons keep the text lined up)
        row.label:SetWidth(EM_W - 12 - 40 - 50)
        row.key = W.Label(row, "ZoFontGameSmall", C.dim, "", TEXT_ALIGN_RIGHT)
        row.key:SetAnchor(RIGHT, row, RIGHT, -8, 0)
        row:SetHandler("OnMouseEnter", function() W.HighlightTo(row.hl, "Groupbound_EmHl" .. i, true, 100) end)
        row:SetHandler("OnMouseExit", function() W.HighlightTo(row.hl, "Groupbound_EmHl" .. i, false, 100) end)
        row:SetHandler("OnMouseUp", function(_, button, upInside)
            if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT or not row.fn then return end
            PlaySound(SOUNDS.DEFAULT_CLICK)
            local fn = row.fn
            if row.stay then
                -- an on / off switch: the menu stays open and shows the new state
                fn()
                if em.redo then em.redo() end
                return
            end
            UI.CloseEntryMenu()
            fn()
        end)
        em.rows[i] = row
    end
    row:SetHidden(false)
    row.hl:SetAlpha(0)
    row.hl:SetHidden(true)
    return row
end

-- Paints the menu: title, sub line, then sections { head (optional), upper, items = { icon (EM_ICON
-- key or a file, optional), text, key (keybind action), red, keepColor, fn, state = function -> on/off
-- (a switch: shows On / Off on the right and keeps the menu open) } }.
local function PaintMenu(title, subText, sections)
    em.title:SetText(title or "")
    em.sub:SetText(subText or "")
    for _, list in ipairs({ em.rows, em.heads, em.lines }) do
        for _, c in ipairs(list) do c:SetHidden(true) end
    end
    local y = 10 + (em.title:GetTextHeight() or 20) + (subText ~= "" and (em.sub:GetTextHeight() or 16) or 0) + 8
    local nRow, nHead, nLine = 0, 0, 0
    for _, section in ipairs(sections) do
        nLine = nLine + 1
        local line = EmLine(nLine)
        line:ClearAnchors()
        line:SetAnchor(TOPLEFT, em.win, TOPLEFT, 10, y)
        line:SetAnchor(TOPRIGHT, em.win, TOPRIGHT, -10, y)
        y = y + 6
        if section.head then
            nHead = nHead + 1
            local h = EmHead(nHead)
            h:SetText(section.upper and zo_strupper(section.head) or section.head)
            h:ClearAnchors()
            h:SetAnchor(TOPLEFT, em.win, TOPLEFT, 14, y)
            y = y + 20
        end
        for _, item in ipairs(section.items) do
            nRow = nRow + 1
            local row = EmRow(nRow)
            row:ClearAnchors()
            row:SetAnchor(TOPLEFT, em.win, TOPLEFT, 6, y)
            local icon = item.icon and (EM_ICON[item.icon] or item.icon)
            row.icon:SetHidden(not icon)
            if icon then row.icon:SetTexture(icon) end
            local size = item.iconSize or 20
            row.icon:SetDimensions(size, size)
            row.icon:ClearAnchors()
            row.icon:SetAnchor(LEFT, row, LEFT, 10 + (20 - size) / 2, 0)
            if item.keepColor then
                row.icon:SetColor(1, 1, 1, 1)
            else
                row.icon:SetColor(G.RGBA(item.red and C.bad or C.normal))
            end
            row.label:SetText(item.text or "")
            row.label:SetColor(G.RGBA(item.red and C.bad or C.normal))
            if item.state then
                local on = item.state()
                row.key:SetText(L(on and "MENU_ON" or "MENU_OFF"))
                row.key:SetColor(G.RGBA(on and C.good or C.dim))
            else
                row.key:SetText(KeyText(item.key))
                row.key:SetColor(G.RGBA(C.dim))
            end
            row.stay = item.state ~= nil
            row.fn = item.fn
            -- (in-game 2026-10-14 "Mark: good run with this leader" wrapped into the next row and
            -- covered it: the label takes the key column's room when there's no key, and a row
            -- grows with its text)
            local hasKey = (row.key:GetText() or "") ~= ""
            row.label:SetWidth(EM_W - 12 - 40 - (hasKey and 50 or 12))
            local h = math.max(EM_ROW_H, math.ceil(row.label:GetTextHeight() or 0) + 10)
            row:SetHeight(h)
            y = y + h
        end
        y = y + 4
    end
    em.win:SetHeight(y + 6)
end

-- opens the menu at the mouse; build() returns title, sub line, sections (called again after a
-- switch is clicked, so the menu shows the new state)
function UI.ShowMenu(build)
    if not em.win then CreateEntryMenu() end
    em.redo = function() PaintMenu(build()) end
    PaintMenu(build())
    local mx, my = GetUIMousePosition()
    em.win:ClearAnchors()
    em.win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, mx + 4, my + 4)
    em.win:SetHidden(false)
    em.win:SetAlpha(0)
    W.FadeTo(em.win, "Groupbound_EntryMenu", 1, 120)
    -- (wrapped text heights settle a moment later: lay the rows out again then)
    G.Later(function()
        if em.win and not em.win:IsHidden() and em.redo then em.redo() end
    end, 50, "UI")
    -- a click anywhere else closes it
    G.EM:RegisterForEvent("Groupbound_EntryMenuClick", EVENT_GLOBAL_MOUSE_DOWN, function()
        if em.win and not em.win:IsHidden() and not G.IsOver(em.win) then UI.CloseEntryMenu() end
    end)
end

function UI.EntryMenu(e, anchor)
    if not e then return end
    UI.ShowMenu(function() return UI.EntryMenuParts(e) end)
end

function UI.EntryMenuParts(e)
    -- header: the run, its difficulty in color, members, open places for your role
    local sub = {}
    local diff = Board.DifficultyText(e)
    if diff ~= "" and not Board.AdKind(e) then sub[#sub + 1] = diff end
    if e.finder and (e.size or 0) > 0 then sub[#sub + 1] = G.Colorize(C.dim, string.format("%d / %d", e.members or 0, e.size)) end
    if e.open and e.open > 0 then sub[#sub + 1] = G.Colorize(C.dim, L("MENU_OPEN_FOR_YOU", e.open)) end

    -- the actions, in two sections
    local note = G.Note(e.account)
    local sections = {
        { head = L("MENU_THIS_GROUP"), upper = true, items = {
            { icon = "primary", text = PrimaryName(e), key = "UI_SHORTCUT_PRIMARY", fn = function() UI.Primary(e) end },
        } },
        { head = e.account or "", items = {
            { icon = "whisper", text = L("WHISPER"), key = "UI_SHORTCUT_SECONDARY", fn = function() UI.WhisperEmpty(e) end },
            { icon = "note", text = L("EDIT_NOTE"), fn = function() UI.EditNote(e.account) end },
            { icon = "good", text = L(note and note.good and "UNMARK_GOOD" or "MARK_GOOD"), keepColor = true, fn = function() UI.ToggleGood(e.account) end },
            { icon = "hide", text = L("HIDE_PLAYER"), red = true, fn = function() UI.HidePlayer(e.account) end },
        } },
    }
    -- "Alert me" only for a run Groupbound knows
    if e.content then
        table.insert(sections[1].items, { icon = "alert",
            text = L(G.sv.watches[e.content] and "MENU_ALERT_OFF" or "MENU_ALERT_ON", Content.Name(e.content)),
            key = "UI_SHORTCUT_TERTIARY", fn = function() UI.ToggleWatch(e.content) end })
    end
    return RunName(e), table.concat(sub, G.Colorize(C.dim, "  ·  ")), sections
end

-- picks a group (nil = none): its row opens up, the rows below glide down
function UI.Select(id)
    local changed = ui.selId ~= id
    ui.selId = id
    for _, row in pairs(ui.rowsById) do PaintRowHighlight(row) end
    if changed then UI.LayoutList("live") end
    RefreshKeys()
end

-- ---------------------------------------------------------------------------
-- Note about a player (a small window like the game's)

local noteWin
function UI.EditNote(account)
    if not account then return end
    if not noteWin then
        noteWin = WINDOW_MANAGER:CreateTopLevelWindow("Groupbound_Note")
        noteWin:SetDimensions(420, 230)
        noteWin:SetAnchor(CENTER, GuiRoot, CENTER, 0, -60)
        noteWin:SetDrawTier(DT_HIGH)
        noteWin:SetMouseEnabled(true)
        noteWin:SetMovable(true)
        noteWin:SetClampedToScreen(true)
        W.Backdrop(noteWin)
        noteWin.title = W.Label(noteWin, "ZoFontWinH4", C.selected, "")
        noteWin.title:SetAnchor(TOPLEFT, noteWin, TOPLEFT, 20, 16)
        noteWin.title:SetWidth(380)
        local box, edit = W.MultiEdit(noteWin, 380, 110, L("NOTE_HINT"))
        box:SetAnchor(TOPLEFT, noteWin, TOPLEFT, 20, 52)
        if edit.SetMaxInputChars then edit:SetMaxInputChars(500) end
        noteWin.edit = edit
        local save = W.Button(noteWin, L("SAVE"), function()
            local text = noteWin.edit:GetText() or ""
            local n = G.EnsureNote(noteWin.account)
            if n then
                n.note = text ~= "" and text or nil
                G.TidyNote(noteWin.account)
            end
            noteWin:SetHidden(true)
            Board.Changed()
        end, 150)
        save:SetAnchor(BOTTOMRIGHT, noteWin, BOTTOMRIGHT, -20, -16)
        local cancel = W.Button(noteWin, L("CANCEL"), function() noteWin:SetHidden(true) end, 150)
        cancel:SetAnchor(RIGHT, save, LEFT, -10, 0)
        edit:SetHandler("OnEscape", function() noteWin:SetHidden(true) end, "Groupbound")
    end
    noteWin.account = account
    noteWin.title:SetText(L("NOTE_ABOUT", account))
    local n = G.Note(account)
    noteWin.edit:SetText(n and n.note or "")
    noteWin:SetHidden(false)
    noteWin:SetAlpha(0)
    W.FadeTo(noteWin, "Groupbound_NoteWin", 1, 200)
    noteWin.edit:TakeFocus()
end

-- ---------------------------------------------------------------------------
-- Apply with a message (a small window like the note window): the leader's text above, your
-- message below (role and CP filled in), Send / Cancel. Players asked for this: leaders who check
-- each player often want gear, experience or an achievement named.

local applyWin
local function ApplyMaxChars()
    return GROUP_FINDER_GROUP_LISTING_APPLICATION_MESSAGE_MAX_LENGTH or 200
end

-- the window as tall as its texts: title, "The leader writes:", their text, your message box,
-- the buttons
local function FitApplyWin()
    if not applyWin then return end
    local h = 16 + (applyWin.title:GetTextHeight() or 0) + 10 + (applyWin.says:GetTextHeight() or 0) + 2
        + (applyWin.desc:GetTextHeight() or 0) + 14 + (applyWin.yours:GetTextHeight() or 0) + 4
        + 76 + 16 + 30 + 16
    applyWin:SetHeight(math.max(260, h))
end

function UI.ApplyDialog(e)
    if not applyWin then
        applyWin = WINDOW_MANAGER:CreateTopLevelWindow("Groupbound_Apply")
        applyWin:SetDimensions(460, 330)
        applyWin:SetAnchor(CENTER, GuiRoot, CENTER, 0, -60)
        applyWin:SetDrawTier(DT_HIGH)
        applyWin:SetMouseEnabled(true)
        applyWin:SetMovable(true)
        applyWin:SetClampedToScreen(true)
        W.Backdrop(applyWin)
        applyWin.title = W.Label(applyWin, "ZoFontWinH4", C.selected, "")
        applyWin.title:SetAnchor(TOPLEFT, applyWin, TOPLEFT, 20, 16)
        -- (everything in full: the window grows with the leader's text, see FitApplyWin)
        applyWin.title:SetWidth(420)
        local says = W.Label(applyWin, "ZoFontGameSmall", C.dim, L("APPLY_LEADER_SAYS"))
        says:SetAnchor(TOPLEFT, applyWin.title, BOTTOMLEFT, 0, 10)
        says:SetWidth(420)
        applyWin.says = says
        applyWin.desc = W.Label(applyWin, "ZoFontGame", C.normal, "")
        applyWin.desc:SetAnchor(TOPLEFT, says, BOTTOMLEFT, 0, 2)
        applyWin.desc:SetWidth(420)
        local yours = W.Label(applyWin, "ZoFontGameSmall", C.dim, L("APPLY_YOUR_MSG"))
        yours:SetAnchor(TOPLEFT, applyWin.desc, BOTTOMLEFT, 0, 14)
        yours:SetWidth(420)
        applyWin.yours = yours
        local box, edit = W.MultiEdit(applyWin, 420, 76, L("APPLY_MSG_HINT"))
        box:SetAnchor(TOPLEFT, yours, BOTTOMLEFT, 0, 4)
        if edit.SetMaxInputChars then edit:SetMaxInputChars(ApplyMaxChars()) end
        applyWin.edit = edit
        local function Close() applyWin:SetHidden(true) end
        local send = W.Button(applyWin, L("APPLY_SEND"), UI.SendApplyDialog, 190)
        send:SetAnchor(BOTTOMRIGHT, applyWin, BOTTOMRIGHT, -20, -16)
        local cancel = W.Button(applyWin, L("CANCEL"), Close, 150)
        cancel:SetAnchor(RIGHT, send, LEFT, -10, 0)
        edit:SetHandler("OnEscape", Close, "Groupbound")
    end
    applyWin.entry = e
    applyWin.title:SetText(L("APPLY_TITLE", Board.Readable(Board.Title(e))))
    local desc = Board.Readable(e.desc ~= "" and e.desc or (e.chatText or ""))
    applyWin.desc:SetText(desc ~= "" and desc or L("APPLY_NO_TEXT"))
    applyWin.desc:SetColor(G.RGBA(desc ~= "" and C.normal or C.dim))
    applyWin.edit:SetText(Board.ApplyMessage() .. " ")
    FitApplyWin()
    G.Later(FitApplyWin, 50, "UI")
    applyWin:SetHidden(false)
    applyWin:SetAlpha(0)
    W.FadeTo(applyWin, "Groupbound_ApplyWin", 1, 200)
    applyWin.edit:TakeFocus()
end

-- the window's "Send application"
function UI.SendApplyDialog()
    if not applyWin or applyWin:IsHidden() then return end
    local entry = applyWin.entry and Board.Find(applyWin.entry.id) or applyWin.entry
    local text = zo_strtrim(applyWin.edit:GetText() or "")
    applyWin:SetHidden(true)
    if entry then SendApplication(entry, text) end
end

function UI.CloseApplyDialog()
    if applyWin then applyWin:SetHidden(true) end
end

-- ---------------------------------------------------------------------------
-- Left: the tree, filters, your application / listing

local TREE = {
    -- (icons: the game's own, from esoui activity finder / leaderboards)
    { head = "TREE_ALL_GROUPS" },
    { view = "all", key = "TREE_ALL", icon = "EsoUI/Art/LFG/LFG_indexIcon_groupFinder_up.dds" },
    { view = "trial", key = "TREE_TRIALS", icon = "EsoUI/Art/Journal/leaderboard_indexIcon_raids_up.dds" },
    { view = "dungeon", key = "TREE_DUNGEONS", icon = "EsoUI/Art/LFG/LFG_indexIcon_dungeon_up.dds" },
    { view = "arena", key = "TREE_ARENAS", icon = "EsoUI/Art/Journal/leaderboard_indexIcon_challenge_up.dds" },
    { view = "other", key = "TREE_OTHER", icon = "EsoUI/Art/LFG/LFG_indexIcon_zoneStories_up.dds" },
    { head = "TREE_YOURS" },
    { view = "applicants", key = "TREE_APPLICANTS" },
    { view = "alerts", key = "TREE_ALERTS" },
    { view = "post", key = "TREE_POST" },
}

function UI.PaintTree()
    if not ui.win then return end
    for _, item in ipairs(ui.treeItems) do
        local text = L(item.def.key)
        local n
        if item.def.view == "alerts" then
            n = 0
            for _ in pairs(G.sv.watches) do n = n + 1 end
        elseif item.def.view == "applicants" then
            -- only while you have a listing
            if Finder.MyListing() then n = #Finder.Applicants() end
        elseif item.def.view ~= "post" then
            n = Board.Count(item.def.view)
        end
        if n then text = text .. "  " .. G.Colorize(C.dim, "(" .. n .. ")") end
        if item.def.icon then text = zo_iconFormat(item.def.icon, 26, 26) .. " " .. text end
        item:SetText(text)
        local picked = G.sv.view == item.def.view
        item:SetSelected(picked)
        -- the picked entry: soft glow behind it + the thin gold edge on the left
        if picked and ui.treeSel then
            ui.treeSel:ClearAnchors()
            ui.treeSel:SetAnchor(LEFT, item, LEFT, -10, 0)
            ui.treeEdge:ClearAnchors()
            ui.treeEdge:SetAnchor(LEFT, item, LEFT, -10, 0)
            ui.treeSel:SetHidden(false)
            ui.treeEdge:SetHidden(false)
        end
    end
    for _, c in ipairs(ui.checks) do c:Refresh() end
end

function UI.SetView(view)
    local old = G.sv.view
    if old == view then return end
    G.sv.view = view
    UI.CloseAchPicker()
    UI.CloseListPicker()
    PlaySound(SOUNDS.TREE_SUBCATEGORY_CLICK or SOUNDS.DEFAULT_CLICK)
    ui.selId = nil
    Board.Rebuild()
    UI.PaintTree()
    UI.ShowPage(old)
    UpdateKeys()
end

local function PageOf(view)
    if view == "post" then return ui.post end
    if view == "alerts" then return ui.alerts end
    if view == "applicants" then return ui.apps end
    return ui.list
end

-- the right side: list, applicants, alerts or post form; fades between them (post: fields one by one)
function UI.ShowPage(oldView)
    local view = G.sv.view
    local page = PageOf(view)
    local oldPage = PageOf(oldView)
    if page == oldPage then
        if page == ui.list then SwapList() end
        return
    end
    W.FadeTo(oldPage, "Groupbound_PageOut", 0, 150, function() oldPage:SetHidden(true) end)
    G.Later(function()
        page:SetHidden(false)
        page:SetAlpha(1)
        if page == ui.list then
            UI.LayoutList("swap")
        elseif page == ui.post then
            UI.RefreshPost()
            for i, field in ipairs(ui.postFields) do
                field:SetAlpha(0)
                G.Later(function() W.FadeTo(field, "Groupbound_PostF" .. i, 1, 200) end, (i - 1) * 70, "UI")
            end
        elseif page == ui.apps then
            UI.RefreshApplicants()
            page:SetAlpha(0)
            W.FadeTo(page, "Groupbound_PageIn", 1, 200)
        else
            UI.RefreshAlerts()
            page:SetAlpha(0)
            W.FadeTo(page, "Groupbound_PageIn", 1, 200)
        end
    end, 150, "UI")
end

function UI.RefreshSide()
    if not ui.win then return end
    local text, btnText, btnFn
    local listing = Finder.MyListing()
    local app = Finder.MyApplication()
    local last = Finder.LastListing()
    if listing then
        text = L("SIDE_LISTING", listing.title)
        local n = #Finder.Applicants()
        if n > 0 then text = text .. "\n" .. L("SIDE_APPLICANTS", n) end
        btnText, btnFn = L("REMOVE_LISTING"), Finder.RemoveListing
    elseif app then
        text = L("SIDE_APPLIED", app.title, app.leader)
        btnText, btnFn = L("TAKE_BACK"), Finder.Rescind
    elseif Finder.ApplyPending() then
        text = L("FINDER_APPLYING")
    elseif last and G.Now() - (last.t or 0) <= RELIST_FOR and IsUnitSoloOrGroupLeader("player") then
        -- leaders re-list after someone leaves: one click
        text = L("RELIST_LAST", last.title)
        btnText, btnFn = L("RELIST"), Finder.Relist
    elseif IsUnitGrouped("player") then
        text = L("SIDE_GROUPED")
    elseif Board.ContactCount() > 0 then
        text = L("SIDE_CONTACTS", Board.ContactCount())
    else
        text = L("SIDE_TIP")
    end
    ui.side:SetText(text)
    ui.sideBtn:SetHidden(btnText == nil)
    if btnText then
        ui.sideBtn:SetText(btnText)
        ui.sideBtn.fn = btnFn
    end
end

-- ---------------------------------------------------------------------------
-- Top: who you are, the Group Finder's state, column headers

-- The game's role picker, copied from esoui preferredroles.xml / .lua (the Group menu's
-- "Preferred role" buttons): same art (LFG_<role>_up/down/over/down_over/disabled_64.dds), same
-- tooltip lines, same click sounds, and it sets the game's own role (UpdateSelectedLFGRole), so
-- the Group menu and Groupbound always agree. With an application that enforces roles, the game's
-- own warning dialog asks first (changing role takes the application back).
local ROLE_BUTTONS = {
    { role = "tank", lfg = "LFG_ROLE_TANK", art = "tank", tip = "SI_GROUP_PREFERRED_ROLE_TANK_TOOLTIP", sound = "GROUP_ROLE_TANK_CLICK" },
    { role = "heal", lfg = "LFG_ROLE_HEAL", art = "healer", tip = "SI_GROUP_PREFERRED_ROLE_HEAL_TOOLTIP", sound = "GROUP_ROLE_HEAL_CLICK" },
    { role = "dps", lfg = "LFG_ROLE_DPS", art = "dps", tip = "SI_GROUP_PREFERRED_ROLE_DPS_TOOLTIP", sound = "GROUP_ROLE_DPS_CLICK" },
}
local ROLE_BUTTON_SIZE = 50

local function CanChangeRole()
    if not CanUpdateSelectedLFGRole then return true end
    local ok, can = pcall(CanUpdateSelectedLFGRole)
    return not ok or can
end

local function SelectedLfg()
    local ok, lfg = pcall(GetSelectedLFGRole)
    return ok and lfg or nil
end

local function ApplyRole(lfg)
    if not CanChangeRole() or not UpdateSelectedLFGRole then return end
    UpdateSelectedLFGRole(lfg)
    if ZO_ACTIVITY_FINDER_ROOT_MANAGER and ZO_ACTIVITY_FINDER_ROOT_MANAGER.UpdateLocationData then
        pcall(ZO_ACTIVITY_FINDER_ROOT_MANAGER.UpdateLocationData, ZO_ACTIVITY_FINDER_ROOT_MANAGER)
    end
    -- the game's own role buttons follow, and everyone listening (Groupbound's board too) hears it
    if PREFERRED_ROLES then
        if PREFERRED_ROLES.RefreshRoles then pcall(PREFERRED_ROLES.RefreshRoles, PREFERRED_ROLES) end
        if PREFERRED_ROLES.FireCallbacks then pcall(PREFERRED_ROLES.FireCallbacks, PREFERRED_ROLES, "LFGRoleChanged") end
    else
        Board.Changed()
        G.callbacks:FireCallbacks("RoleChanged")
    end
    UI.PaintTop()
end

local function PickRole(def)
    local lfg = _G[def.lfg]
    if SelectedLfg() == lfg then return end
    local applied = GROUP_FINDER_GROUP_LISTING_USER_TYPE_APPLIED_TO_GROUP_LISTING
    local enforces = false
    if applied and DoesGroupFinderUserTypeGroupListingEnforceRoles then
        local ok, yes = pcall(DoesGroupFinderUserTypeGroupListingEnforceRoles, applied)
        enforces = ok and yes
    end
    if enforces then
        local ok = pcall(ZO_Dialogs_ShowDialog, "RADIO_BUTTON_GROUP_CHANGE_SELECTION_CONFIRMATION", {
            title = GetString(SI_GROUP_FINDER_CHANGE_ROLE_WARNING_DIALOG_TITLE),
            mainText = GetString(SI_GROUP_FINDER_CHANGE_ROLE_WARNING_DIALOG_TEXT),
            onConfirmCallback = function()
                RequestResolveGroupListingApplication(RESOLVE_GROUP_LISTING_APPLICATION_REQUEST_RESCIND)
                ApplyRole(lfg)
            end,
        })
        if ok then return end
    end
    ApplyRole(lfg)
end

local function RoleTooltip(b)
    local def = b.def
    InitializeTooltip(InformationTooltip, b, BOTTOM, 0, 0)
    local c = ZO_TOOLTIP_DEFAULT_COLOR
    local r, g, bl = 1, 1, 1
    if c and c.UnpackRGB then r, g, bl = c:UnpackRGB() end
    InformationTooltip:AddLine(GetString("SI_LFGROLE", _G[def.lfg]), "", r, g, bl)
    InformationTooltip:AddLine(GetString(_G[def.tip] or 0), "", r, g, bl)
    if SI_GROUP_PREFERRED_ROLE_DESCRIPTION then
        InformationTooltip:AddLine(GetString(SI_GROUP_PREFERRED_ROLE_DESCRIPTION), "", r, g, bl)
    end
    if not CanChangeRole() and SI_GROUP_LIST_PANEL_DISABLED_ROLE_TOOLTIP then
        InformationTooltip:AddLine(GetString(SI_GROUP_LIST_PANEL_DISABLED_ROLE_TOOLTIP), "", 1, 0, 0)
    end
end

local function CreateRoleButtons(win)
    ui.roleButtons = {}
    local prev
    for _, def in ipairs(ROLE_BUTTONS) do
        local b = WINDOW_MANAGER:CreateControl(W.Name("Role"), win, CT_BUTTON)
        b:SetDimensions(ROLE_BUTTON_SIZE, ROLE_BUTTON_SIZE)
        local path = "EsoUI/Art/LFG/LFG_" .. def.art .. "_%s_64.dds"
        b:SetNormalTexture(string.format(path, "up"))
        b:SetPressedTexture(string.format(path, "down"))
        b:SetMouseOverTexture(string.format(path, "over"))
        b:SetPressedMouseOverTexture(string.format(path, "down_over"))
        b:SetDisabledTexture(string.format(path, "disabled"))
        b:SetDisabledPressedTexture(string.format(path, "down_disabled"))
        b.def = def
        b:SetHandler("OnClicked", function(self)
            PlaySound(SOUNDS[def.sound] or SOUNDS.DEFAULT_CLICK)
            PickRole(def)
            UI.PaintRoleButtons()
        end)
        b:SetHandler("OnMouseEnter", function(self) RoleTooltip(self) end)
        b:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
        if prev then
            b:SetAnchor(LEFT, prev, RIGHT, 2, 0)
        else
            -- (20: room for the "YOUR ROLE" heading above, user 2026-10-13)
            b:SetAnchor(TOPLEFT, win, TOPLEFT, LEFT_X - 8, 20)
        end
        prev = b
        ui.roleButtons[#ui.roleButtons + 1] = b
    end
    return prev
end

-- the picked role stays pressed (locked), like the game's radio buttons
function UI.PaintRoleButtons()
    if not ui.roleButtons then return end
    local selected = SelectedLfg()
    local enabled = CanChangeRole()
    for _, b in ipairs(ui.roleButtons) do
        local on = _G[b.def.lfg] == selected
        if on then
            b:SetState(enabled and BSTATE_PRESSED or BSTATE_DISABLED_PRESSED, true)
        else
            b:SetState(enabled and BSTATE_NORMAL or BSTATE_DISABLED, false)
        end
    end
end

function UI.PaintTop()
    if not ui.win then return end
    UI.PaintRoleButtons()
    -- the role, in the game's own words (crossfades when it changes)
    local roleText = zo_strupper(GetString("SI_LFGROLE", SelectedLfg() or 0))
    if roleText == "" then roleText = zo_strupper(G.RoleName(G.MyRole())) end
    if ui.roleTitle:GetText() ~= roleText then
        if ui.roleTitle:GetText() == "" then
            ui.roleTitle:SetText(roleText)
        else
            W.FadeTo(ui.roleTitle, "Groupbound_RoleTitle", 0, 100, function()
                ui.roleTitle:SetText(roleText)
                W.FadeTo(ui.roleTitle, "Groupbound_RoleTitle", 1, 180)
            end)
        end
    end
    -- you: class icon, name, class, CP (or level)
    local parts = {}
    local classId = GetUnitClassId and GetUnitClassId("player")
    local icon = classId and ZO_GetClassIcon and ZO_GetClassIcon(classId)
    local name = zo_strformat("<<1>>", GetUnitName("player"))
    parts[1] = (icon and zo_iconFormat(icon, 24, 24) .. " " or "") .. G.Colorize(C.selected, name)
    local className = GetUnitClass and GetUnitClass("player")
    if className and className ~= "" then parts[#parts + 1] = zo_strformat("<<1>>", className) end
    local cp = G.MyCP()
    if cp > 0 then
        local cpIcon = ZO_GetChampionIconMarkupString and ZO_GetChampionIconMarkupString(20) or ""
        parts[#parts + 1] = cpIcon .. " " .. cp
    else
        parts[#parts + 1] = L("HEADER_LEVEL", GetUnitLevel("player"))
    end
    ui.charLine:SetText(table.concat(parts, "  ·  "))
    -- what's going on: group, how many groups fit you, the Group Finder
    local status = {}
    if IsUnitGrouped("player") then
        status[1] = L("HEADER_GROUP", GetGroupSize())
    else
        status[1] = L("HEADER_SOLO")
    end
    local fits = Board.ForMeCount()
    status[#status + 1] = fits == 1 and L("HEADER_FIT_ONE") or L("HEADER_FIT", fits)
    status[#status + 1] = Finder.StatusText()
    ui.statusLine:SetText(table.concat(status, "  ·  "))
end

function UI.PaintHeaders()
    if not ui.headers then return end
    for _, h in ipairs(ui.headers) do
        h:SetSelected(G.sv.sortKey == h.key)
    end
end

-- ---------------------------------------------------------------------------
-- Alerts page

function UI.RefreshAlerts()
    if not ui.alerts then return end
    local keysList = {}
    for key in pairs(G.sv.watches) do
        if Content.Get(key) then keysList[#keysList + 1] = key end
    end
    table.sort(keysList, function(a, b) return Content.Name(a) < Content.Name(b) end)
    for i = 1, math.max(#keysList, #ui.alertRows) do
        local r = ui.alertRows[i]
        local key = keysList[i]
        if key and not r then
            r = WINDOW_MANAGER:CreateControl(nil, ui.alerts, CT_CONTROL)
            r:SetDimensions(RIGHT_W - 14, ROW_H)
            r.bg = W.Tex(r, nil, nil, nil, C.panel, 0.28)
            r.bg:SetAnchorFill(r)
            r.name = W.Label(r, "ZoFontGame", C.normal)
            r.name:SetAnchor(LEFT, r, LEFT, 10, 0)
            r.remove = W.TextButton(r, "ZoFontGame", L("REMOVE"), function(self)
                PlaySound(SOUNDS.DEFAULT_CLICK)
                UI.ToggleWatch(self.key)
            end)
            r.remove:SetAnchor(RIGHT, r, RIGHT, -10, 0)
            ui.alertRows[i] = r
        end
        if r then
            r:SetHidden(key == nil)
            if key then
                r:ClearAnchors()
                r:SetAnchor(TOPLEFT, ui.alerts, TOPLEFT, 0, 96 + (i - 1) * ROW_H)
                r.name:SetText(Content.Name(key))
                r.remove.key = key
            end
        end
    end
    ui.alertsNone:SetHidden(#keysList > 0)
end

-- ---------------------------------------------------------------------------
-- Applicants page (YOURS > Applicants): who applied to your listing, like the game's own
-- applications list but with your notes about players. Accept (E or double-click), Decline (R),
-- Whisper (X); right-click for more. On top: your listing and Remove listing / List again.

local APP_COLS = {
    { key = "COL_ROLE", x = 0, w = 40 },
    { key = "COL_PLAYER", x = 44, w = 300 },
    { key = "COL_CP", x = 348, w = 110 },
    { key = "COL_MESSAGE", x = 462, w = 340 },
    { key = "COL_TIME", x = 806, w = RIGHT_W - 14 - 806 },
}
local APPS_TOP = 76

local function SelApp()
    if not ui.appSel or not ui.appList then return nil end
    for _, a in ipairs(ui.appList) do
        if a.key == ui.appSel then return a end
    end
end

local function TimeLeftText(a)
    if a.pending then return L("APPS_PENDING") end
    if not a.left then return "" end
    if ZO_FormatTimeLargestTwo and TIME_FORMAT_STYLE_DESCRIPTIVE_MINIMAL then
        local ok, text = pcall(ZO_FormatTimeLargestTwo, a.left, TIME_FORMAT_STYLE_DESCRIPTIVE_MINIMAL)
        if ok and text then return text end
    end
    return string.format("%d:%02d", math.floor(a.left / 60), a.left % 60)
end

local function CpText(a)
    if (a.cp or 0) > 0 then return L("APPS_CP", a.cp) end
    return L("HEADER_LEVEL", a.level or 0)
end

function UI.AppTooltip(row)
    local a = row.app
    if not a then return end
    InitializeTooltip(InformationTooltip, row, RIGHT, -12, 0, LEFT)
    local char = a.char ~= "" and zo_strformat("<<1>>", a.char) or a.account
    SetTooltipText(InformationTooltip, char)
    local function Line(text, color)
        if text and text ~= "" then
            local c = color or C.normal
            InformationTooltip:AddLine(text, "", c.r, c.g, c.b)
        end
    end
    Line(a.account, C.dim)
    local classIcon = a.classId and ZO_GetClassIcon and ZO_GetClassIcon(a.classId)
    Line((classIcon and zo_iconFormat(classIcon, 24, 24) .. " " or "") .. G.RoleName(a.role) .. "  ·  " .. CpText(a))
    if a.note ~= "" then Line(a.note, C.selected) end
    -- an achievement named or linked in their message: say so, but it can't be checked
    local last = Finder.LastListing()
    local mentioned = G.Achieve.InText(a.note, last and last.key)
    for _, id in ipairs(mentioned) do
        local name = G.Achieve.Name(id)
        if name then Line(L("APPS_MENTIONS", name), C.dim) end
    end
    local note = G.Note(a.account)
    if note and note.good then Line(L("MARK_GOOD_TAG"), C.good) end
    if note and note.hidden then Line(L("APPS_HIDDEN"), C.bad) end
    if note and note.note and note.note ~= "" then Line(L("TT_NOTE", note.note)) end
    Line(L("APPS_TT_HINT"), C.dim)
end

function UI.AppMenu(a, anchor)
    if not a then return end
    ClearMenu()
    if not a.pending then
        AddMenuItem(L("ACCEPT"), function() Finder.Resolve(a, true) end)
        AddMenuItem(L("DECLINE"), function() Finder.Resolve(a, false) end)
    end
    AddMenuItem(L("WHISPER"), function() Chat.Whisper(a.account, "") end)
    AddMenuItem(L("EDIT_NOTE"), function() UI.EditNote(a.account) end)
    local note = G.Note(a.account)
    AddMenuItem(L(note and note.good and "UNMARK_GOOD" or "MARK_GOOD"), function() UI.ToggleGood(a.account) end)
    ShowMenu(anchor)
end

local function PaintAppHighlight(row)
    local key = "Groupbound_AppHl" .. tostring(row)
    W.HighlightTo(row.hl, key, row.hover, 120)
    W.HighlightTo(row.sel, key .. "S", row.app ~= nil and row.app.key == ui.appSel, 160)
end

local function MakeAppRow(i)
    local row = WINDOW_MANAGER:CreateControl(nil, ui.apps, CT_CONTROL)
    row:SetDimensions(RIGHT_W - 14, ROW_H)
    row:SetMouseEnabled(true)
    row.bg = W.Tex(row, nil, nil, nil, C.panel, 0.28)
    row.bg:SetAnchorFill(row)
    row.hl = W.Highlight(row, 0.12)
    row.sel = W.Highlight(row, 0.22, 0.16)   -- (light 0.16: user wanted the picked row a bit softer)
    row.role = W.Tex(row, nil, 32, 32)
    row.role:SetAnchor(LEFT, row, LEFT, APP_COLS[1].x + 2, 0)
    local function Col(c, font)
        local l = W.Label(row, font or "ZoFontGame", C.normal)
        l:SetAnchor(LEFT, row, LEFT, c.x + 6, 0)
        l:SetWidth(c.w - 6)
        return l
    end
    row.player = Col(APP_COLS[2])
    row.cp = Col(APP_COLS[3])
    row.note = Col(APP_COLS[4], "ZoFontGameSmall")
    row.time = Col(APP_COLS[5], "ZoFontGameSmall")
    row.hover = false
    row:SetHandler("OnMouseEnter", function()
        row.hover = true
        PaintAppHighlight(row)
        UI.AppTooltip(row)
    end)
    row:SetHandler("OnMouseExit", function()
        row.hover = false
        PaintAppHighlight(row)
        ClearTooltip(InformationTooltip)
    end)
    row:SetHandler("OnMouseUp", function(_, button, upInside)
        if not upInside or not row.app then return end
        UI.SelectApplicant(row.app.key)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            PlaySound(SOUNDS.DEFAULT_CLICK)
        elseif button == MOUSE_BUTTON_INDEX_RIGHT then
            UI.AppMenu(row.app, row)
        end
    end)
    row:SetHandler("OnMouseDoubleClick", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and row.app and not row.app.pending then Finder.Resolve(row.app, true) end
    end)
    return row
end

local function FillAppRow(row, a)
    row.app = a
    local note = G.Note(a.account)
    local nameColor = (note and note.hidden) and C.bad or ((note and note.good) and C.good or C.selected)
    local char = a.char ~= "" and zo_strformat("<<1>>", a.char) or a.account
    row.player:SetText(G.Colorize(nameColor, char) .. "  " .. G.Colorize(C.dim, a.account))
    row.role:SetTexture(G.ROLE_ICON[a.role])
    row.cp:SetText(CpText(a))
    row.note:SetText(a.note ~= "" and a.note or "")
    row.time:SetText(TimeLeftText(a))
    row.time:SetColor(G.RGBA(a.pending and C.dim or ((a.left or 999) < 60 and C.bad or C.normal)))
    PaintAppHighlight(row)
    -- as tall as its longest (wrapped) text, like the board's rows
    local tallest = 0
    for _, l in ipairs({ row.player, row.cp, row.note, row.time }) do
        tallest = math.max(tallest, l:GetTextHeight() or 0)
    end
    row.h = math.max(ROW_H, tallest + ROW_PAD)
    row:SetHeight(row.h)
    return row.h
end

-- rows one under the other, each as tall as it needs
local function PlaceAppRows()
    local y = APPS_TOP
    for _, row in ipairs(ui.appRows) do
        if row.app then
            row:ClearAnchors()
            row:SetAnchor(TOPLEFT, ui.apps, TOPLEFT, 0, y)
            y = y + (row.h or ROW_H)
        end
    end
end

function UI.RefreshApplicants()
    if not ui.apps then return end
    local listing = Finder.MyListing()
    local list = listing and Finder.Applicants() or {}
    ui.appList = list
    if listing then
        local have, places = Finder.MyListingSize()
        ui.appsListing:SetText(L("APPS_LISTING", listing.title, have, places))
        ui.appsBtn:SetText(L("REMOVE_LISTING"))
        ui.appsBtn.fn = Finder.RemoveListing
        ui.appsBtn:SetHidden(false)
    else
        local last = Finder.LastListing()
        ui.appsListing:SetText(last and L("RELIST_LAST", last.title) or "")
        ui.appsBtn:SetText(L("RELIST"))
        ui.appsBtn.fn = Finder.Relist
        ui.appsBtn:SetHidden(last == nil)
    end
    for i, a in ipairs(list) do
        local row = ui.appRows[i]
        if not row then
            row = MakeAppRow(i)
            ui.appRows[i] = row
        end
        row:SetHidden(false)
        FillAppRow(row, a)
    end
    for i = #list + 1, #ui.appRows do
        ui.appRows[i].app = nil
        ui.appRows[i]:SetHidden(true)
    end
    PlaceAppRows()
    -- (wrapped text heights settle a moment later)
    G.Later(function()
        for _, row in ipairs(ui.appRows) do
            if row.app then FillAppRow(row, row.app) end
        end
        PlaceAppRows()
    end, 50, "UI")
    if ui.appSel and not SelApp() then ui.appSel = nil end
    local empty
    if not listing then
        empty = L("APPS_NO_LISTING")
    elseif #list == 0 then
        empty = Finder.MyListingAutoAccepts() and L("APPS_AUTO") or L("APPS_NONE")
    end
    ui.appsEmpty:SetHidden(empty == nil)
    ui.appsEmpty:SetText(empty or "")
    for _, h in ipairs(ui.appHeads) do h:SetHidden(#list == 0) end
end

-- every second while the page shows: the time left counts down
local function TickApplicants()
    if G.sv.view ~= "applicants" or not ui.appRows then return end
    local fresh = Finder.Applicants()
    local byKey = {}
    for _, a in ipairs(fresh) do byKey[a.key] = a end
    for _, row in ipairs(ui.appRows) do
        local a = row.app and byKey[row.app.key]
        if a then
            row.app = a
            row.time:SetText(TimeLeftText(a))
            row.time:SetColor(G.RGBA(a.pending and C.dim or ((a.left or 999) < 60 and C.bad or C.normal)))
        end
    end
end

local function CreateApplicants(win)
    local p = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    p:SetAnchor(TOPLEFT, win, TOPLEFT, RIGHT_X, TOP_Y)
    p:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -30, -20)
    p:SetHidden(true)
    ui.apps = p
    ui.appRows = {}
    ui.appsBtn = W.Button(p, "", function(b) if b.fn then b.fn() end end, 180)
    ui.appsBtn:SetAnchor(TOPRIGHT, p, TOPRIGHT, -14, 0)
    ui.appsListing = W.Label(p, "ZoFontGameLargeBold", C.normal, "")
    ui.appsListing:SetAnchor(TOPLEFT, p, TOPLEFT, 0, 4)
    ui.appsListing:SetWidth(RIGHT_W - 210)
    ui.appHeads = {}
    for _, col in ipairs(APP_COLS) do
        local h = W.Label(p, "ZoFontGame", C.normal, zo_strupper(L(col.key)))
        h:SetAnchor(TOPLEFT, p, TOPLEFT, col.x + 6, APPS_TOP - HEADER_H + 6)
        ui.appHeads[#ui.appHeads + 1] = h
    end
    ui.appsEmpty = W.Label(p, "ZoFontGame", C.dim, "", TEXT_ALIGN_CENTER)
    ui.appsEmpty:SetAnchor(TOP, p, TOP, 0, 110)
    ui.appsEmpty:SetWidth(RIGHT_W - 80)
end

function UI.SelectApplicant(key)
    ui.appSel = key
    for _, r in ipairs(ui.appRows or {}) do PaintAppHighlight(r) end
    RefreshKeys()
end

-- opens the board on your applicants (the "new application" notice)
function UI.ShowApplicants()
    if UI.IsShown() then
        UI.SetView("applicants")
    else
        G.sv.view = "applicants"
        UI.Show()
    end
end

-- ---------------------------------------------------------------------------
-- Post a group page

local post = {}

-- the achievement picked for the post, if it belongs to the run you typed
local function PostAch(key)
    local id = G.sv.post.ach
    if not id or not key then return nil end
    for _, a in ipairs(G.Achieve.ForContent(key)) do
        if a.id == id then return id end
    end
end

local function PostSpec()
    local sv = G.sv.post
    local info = Parse.Scan(sv.text or "")
    return {
        key = info.content, vet = info.vet, hm = info.hm, raw = sv.text,
        need = { tank = sv.tank or 0, heal = sv.heal or 0, dps = sv.dps or 0 },
        cp = tonumber(sv.cp) or 0, startIn = Parse.StartInput(sv.time), note = sv.note,
        ach = PostAch(info.content),
        -- the game's own listing options (Group Finder only)
        cat = sv.cat, primaryIdx = sv.primaryIdx, secondaryIdx = sv.secondaryIdx, size = sv.size,
        playstyle = sv.playstyle, voip = sv.voip, auto = sv.auto, enforce = sv.enforce ~= false,
        code = sv.codeOn and tonumber(sv.code) or nil,
    }
end

-- the listing's category: picked, else from the run you typed, else Custom
local function PostCategory(spec)
    return spec.cat or Content.Category(spec.key) or GROUP_FINDER_CATEGORY_CUSTOM
end

-- "Ask for an achievement": the run's achievements (the ones you have are marked)
-- ---------------------------------------------------------------------------
-- Achievement picker (picked 2026-10-13, sketch C "list + preview"): a panel under the button.
-- Left: the run's name, filter chips (All / Hard modes / You have), the list (each achievement's
-- own icon, a green check when you have it, one entry per name). Right: the picked one big (icon,
-- name, points, what it asks for, whether you have it) and "Ask for this". "No achievement" on top.

local ACH_W, ACH_H = 680, 440
local ACH_LIST_W = 330
local ACH_ROW_H = 32
local CHECK_ICON = "EsoUI/Art/Miscellaneous/check_icon_32.dds"
local ach = { rows = {}, filter = "all" }

local function AchFiltered()
    local out = {}
    local hmWords = {}
    for w in (L("ACH_HM_WORDS") or ""):gmatch("[^,]+") do hmWords[#hmWords + 1] = zo_strlower(zo_strtrim(w)) end
    for _, a in ipairs(ach.list or {}) do
        local keep = true
        if ach.filter == "have" then
            keep = a.done
        elseif ach.filter == "hm" then
            local _, desc = G.Achieve.Info(a.id)
            local text = zo_strlower(a.name .. " " .. (desc or ""))
            keep = false
            for _, w in ipairs(hmWords) do
                if w ~= "" and text:find(w, 1, true) then keep = true break end
            end
        end
        if keep then out[#out + 1] = a end
    end
    return out
end

-- the right side: the picked achievement in full
local function PaintAchPreview()
    local p = ach.preview
    local id = ach.sel
    if not id then
        p.icon:SetHidden(true)
        p.name:SetText(L("POST_ACH_CLEAR"))
        p.points:SetText("")
        p.desc:SetText(L("ACH_NONE_HINT"))
        p.state:SetText("")
        p.ask:SetText(L("ACH_ASK_NONE"))
        return
    end
    local name, desc, points, icon, done = G.Achieve.Info(id)
    p.icon:SetHidden(icon == nil)
    if icon then p.icon:SetTexture(icon) end
    p.name:SetText(name or "")
    p.points:SetText(L("ACH_POINTS", points or 0))
    p.desc:SetText(desc or "")
    local _, progress = G.Achieve.Status(id)
    if done then
        p.state:SetText(G.Colorize(C.good, L("ACH_YOU_HAVE")))
    else
        p.state:SetText(G.Colorize(C.bad, progress and L("ACH_YOU_MISS_PROGRESS", progress) or L("ACH_YOU_MISS")))
    end
    p.ask:SetText(L("ACH_ASK"))
end

local function PaintAchRows()
    local list = AchFiltered()
    ach.shown = list
    -- row 1 = "No achievement", then the list
    local entries = { { none = true } }
    for _, a in ipairs(list) do entries[#entries + 1] = a end
    for i, entry in ipairs(entries) do
        local row = ach.rows[i]
        if not row then
            row = WINDOW_MANAGER:CreateControl(nil, ach.child, CT_CONTROL)
            row:SetDimensions(ACH_LIST_W - 14, ACH_ROW_H)
            row:SetAnchor(TOPLEFT, ach.child, TOPLEFT, 0, (i - 1) * ACH_ROW_H)
            row:SetMouseEnabled(true)
            row.hl = W.Highlight(row, 0.12)
            row.sel = W.Highlight(row, 0.22)
            row.line = W.Tex(row, nil, nil, nil, C.normal, 0.14)
            row.line:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
            row.line:SetAnchor(TOPRIGHT, row, TOPRIGHT, 0, 0)
            row.line:SetHeight(1)
            row.edge = W.Tex(row, nil, 2, nil, C.diffVet, 1)
            row.edge:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
            row.edge:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, 0, 0)
            row.icon = W.Tex(row, nil, 24, 24)
            row.icon:SetAnchor(LEFT, row, LEFT, 8, 0)
            row.name = W.Label(row, "ZoFontGame", C.normal, "")
            row.name:SetAnchor(LEFT, row.icon, RIGHT, 8, 0)
            row.name:SetWidth(ACH_LIST_W - 14 - 8 - 24 - 8 - 30)
            row.check = W.Tex(row, CHECK_ICON, 20, 20)
            row.check:SetAnchor(RIGHT, row, RIGHT, -8, 0)
            row.check:SetColor(G.RGBA(C.good))
            row:SetHandler("OnMouseEnter", function() W.HighlightTo(row.hl, "Groupbound_AchHl" .. i, true, 120) end)
            row:SetHandler("OnMouseExit", function() W.HighlightTo(row.hl, "Groupbound_AchHl" .. i, false, 120) end)
            row:SetHandler("OnMouseUp", function(_, button, upInside)
                if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
                PlaySound(SOUNDS.DEFAULT_CLICK)
                ach.sel = row.entry and row.entry.id or nil
                PaintAchRows()
                PaintAchPreview()
            end)
            row:SetHandler("OnMouseDoubleClick", function(_, button)
                if button == MOUSE_BUTTON_INDEX_LEFT then UI.AskForAch(row.entry and row.entry.id or nil) end
            end)
            ach.rows[i] = row
        end
        row.entry = (not entry.none) and entry or nil
        row:SetHidden(false)
        row.line:SetHidden(i == 1)
        if entry.none then
            row.icon:SetHidden(true)
            row.name:ClearAnchors()
            row.name:SetAnchor(LEFT, row, LEFT, 40, 0)
            row.name:SetText(L("POST_ACH_CLEAR"))
            row.name:SetColor(G.RGBA(C.dim))
            row.check:SetHidden(true)
        else
            local _, _, _, icon = G.Achieve.Info(entry.id)
            row.icon:SetHidden(icon == nil)
            if icon then row.icon:SetTexture(icon) end
            row.name:ClearAnchors()
            row.name:SetAnchor(LEFT, row.icon, RIGHT, 8, 0)
            row.name:SetText(entry.name)
            row.name:SetColor(G.RGBA(entry.done and C.normal or C.dim))
            row.check:SetHidden(not entry.done)
        end
        local picked = (entry.none and ach.sel == nil) or (not entry.none and entry.id == ach.sel)
        W.HighlightTo(row.sel, "Groupbound_AchSel" .. i, picked, 140)
        row.edge:SetHidden(not picked)
    end
    for i = #entries + 1, #ach.rows do
        ach.rows[i].entry = nil
        ach.rows[i]:SetHidden(true)
    end
    ach.child:SetHeight(#entries * ACH_ROW_H)
    for _, chip in ipairs(ach.chips) do chip:SetSelected(chip.filter == ach.filter) end
end

local function CreateAchPicker()
    local win = WINDOW_MANAGER:CreateTopLevelWindow("Groupbound_AchPicker")
    win:SetDimensions(ACH_W, ACH_H)
    win:SetDrawTier(DT_HIGH)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    W.Backdrop(win)
    ach.win = win
    ach.title = W.Label(win, "ZoFontWinH4", C.selected, "")
    ach.title:SetAnchor(TOPLEFT, win, TOPLEFT, 20, 14)
    ach.title:SetWidth(ACH_W - 80)
    local close = W.TextButton(win, "ZoFontWinH4", "x", function() UI.CloseAchPicker() end)
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -16, 10)
    -- filter chips (text tabs, the picked one white)
    ach.chips = {}
    local prev
    for _, def in ipairs({ { "all", "ACH_FILTER_ALL" }, { "hm", "ACH_FILTER_HM" }, { "have", "ACH_FILTER_HAVE" } }) do
        local chip = W.TextButton(win, "ZoFontGameBold", L(def[2]), function(self)
            PlaySound(SOUNDS.DEFAULT_CLICK)
            ach.filter = self.filter
            PaintAchRows()
        end)
        chip.filter = def[1]
        if prev then chip:SetAnchor(LEFT, prev, RIGHT, 18, 0) else chip:SetAnchor(TOPLEFT, win, TOPLEFT, 20, 48) end
        prev = chip
        ach.chips[#ach.chips + 1] = chip
    end
    local scroll, child = W.Scroll(win, "Groupbound_AchScroll")
    scroll:SetAnchor(TOPLEFT, win, TOPLEFT, 16, 78)
    scroll:SetDimensions(ACH_LIST_W, ACH_H - 78 - 18)
    ach.child = child
    -- the divider between list and preview
    local split = W.Tex(win, nil, 1, nil, C.normal, 0.2)
    split:SetAnchor(TOPLEFT, win, TOPLEFT, 16 + ACH_LIST_W + 12, 50)
    split:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 16 + ACH_LIST_W + 12, -18)
    -- preview
    local px = 16 + ACH_LIST_W + 28
    local pw = ACH_W - px - 20
    local p = {}
    p.icon = W.Tex(win, nil, 56, 56)
    p.icon:SetAnchor(TOPLEFT, win, TOPLEFT, px, 54)
    p.name = W.Label(win, "ZoFontWinH4", C.selected, "")
    p.name:SetAnchor(TOPLEFT, win, TOPLEFT, px + 66, 56)
    p.name:SetWidth(pw - 66)
    p.points = W.Label(win, "ZoFontGameSmall", C.dim, "")
    p.points:SetAnchor(TOPLEFT, p.name, BOTTOMLEFT, 0, 2)
    p.desc = W.Label(win, "ZoFontGame", C.normal, "")
    p.desc:SetAnchor(TOPLEFT, win, TOPLEFT, px, 124)
    p.desc:SetWidth(pw)
    p.state = W.Label(win, "ZoFontGameBold", C.normal, "")
    p.state:SetAnchor(TOPLEFT, p.desc, BOTTOMLEFT, 0, 12)
    p.state:SetWidth(pw)
    p.ask = W.Button(win, "", function() UI.AskForAch(ach.sel) end, 220)
    p.ask:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, px, -20)
    ach.preview = p
end

-- "Ask for this" (id nil = no achievement): set it for the post and close
function UI.AskForAch(id)
    G.sv.post.ach = id
    UI.CloseAchPicker()
    UI.RefreshPost()
end

function UI.CloseAchPicker()
    if ach.win then ach.win:SetHidden(true) end
end

-- the "Achievement" button on the Post page opens it under the button
function UI.AchMenu(anchor)
    local spec = PostSpec()
    if not spec.key then
        G.Print(L("POST_ACH_NEED_RUN"))
        return
    end
    local list = G.Achieve.Unique(spec.key)
    if #list == 0 then
        G.Print(L("POST_ACH_NONE", Content.Name(spec.key)))
        return
    end
    if not ach.win then CreateAchPicker() end
    if not ach.win:IsHidden() then
        UI.CloseAchPicker()
        return
    end
    ach.list = list
    ach.filter = "all"
    ach.sel = PostAch(spec.key)
    ach.title:SetText(zo_strupper(L("ACH_TITLE", Content.Name(spec.key))))
    PaintAchRows()
    PaintAchPreview()
    ach.win:ClearAnchors()
    if anchor then
        ach.win:SetAnchor(TOPRIGHT, anchor, BOTTOMRIGHT, 0, 6)
    else
        ach.win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    ach.win:SetHidden(false)
    ach.win:SetAlpha(0)
    W.FadeTo(ach.win, "Groupbound_AchWin", 1, 180)
end

local function PostTitle(spec)
    local parts = {}
    if spec.key then
        parts[1] = (Content.Name(spec.key):gsub("'", ""))
        if Content.Category(spec.key) ~= GROUP_FINDER_CATEGORY_ENDLESS_DUNGEON then
            parts[#parts + 1] = spec.vet and L("VETERAN") or L("NORMAL")
        end
        if spec.hm then parts[#parts + 1] = "HM" end
    else
        parts[1] = spec.raw or ""
    end
    return table.concat(parts, " ")
end

function UI.RefreshPost()
    if not post.text then return end
    local spec = PostSpec()
    if spec.key then
        local what = { Content.Name(spec.key) }
        if spec.vet == true then what[#what + 1] = L("VETERAN") elseif spec.vet == false then what[#what + 1] = L("NORMAL") end
        if spec.hm then what[#what + 1] = "HM" end
        local text = table.concat(what, "  ·  ")
        if post.restoredFor == spec.key then text = text .. "  ·  " .. G.Colorize(C.dim, L("POST_RESTORED")) end
        post.resolved:SetText(text)
        post.resolved:SetColor(G.RGBA(C.selected))
    elseif zo_strtrim(G.sv.post.text or "") ~= "" then
        post.resolved:SetText(L("POST_NOT_RECOGNIZED"))
        post.resolved:SetColor(G.RGBA(C.dim))
    else
        post.resolved:SetText(L("POST_TYPE_HINT"))
        post.resolved:SetColor(G.RGBA(C.dim))
    end
    post.preview:SetText(Parse.BuildPost(spec))
    post.ach:SetText(spec.ach and (G.Achieve.Name(spec.ach) or "") or L("POST_ACH"))
    for _, s in ipairs(post.spinners) do s:Refresh() end
    UI.RefreshPostOptions(spec)
    local listing = Finder.MyListing()
    post.listing:SetText(listing and L("SIDE_LISTING", listing.title) or "")
end

-- Your setup per run (2026-10-14): what you posted last for a run (roles, Min. CP, note, achievement,
-- auto-accept) comes back when you type that run again. Not the start time (that's for one evening).
function UI.RememberPost(spec)
    if not spec or not spec.key then return end
    local sv = G.sv.post
    G.sv.postByRun = G.sv.postByRun or {}
    G.sv.postByRun[spec.key] = {
        tank = sv.tank or 0, heal = sv.heal or 0, dps = sv.dps or 0,
        cp = tonumber(sv.cp) or 0, note = sv.note or "", ach = sv.ach, auto = sv.auto,
    }
end

-- the run you typed changed: bring back that run's setup (if you posted it before)
local function RestorePost(key)
    if key == post.lastKey then return end
    post.lastKey = key
    post.restoredFor = nil
    local saved = key and G.sv.postByRun and G.sv.postByRun[key]
    if not saved then return end
    local sv = G.sv.post
    sv.tank, sv.heal, sv.dps = saved.tank, saved.heal, saved.dps
    sv.ach, sv.auto = saved.ach, saved.auto
    post.restoredFor = key
    -- (setting the fields' text updates sv.cp / sv.note through their own handlers)
    post.cpEdit:SetText(saved.cp and saved.cp > 0 and tostring(saved.cp) or "")
    post.noteEdit:SetText(saved.note or "")
end

function UI.PostToFinder()
    local spec = PostSpec()
    local ownTitle = zo_strtrim(G.sv.post.title or "")
    if not spec.key and zo_strtrim(spec.raw or "") == "" and ownTitle == "" then
        G.Print(L("POST_EMPTY"))
        return
    end
    if G.sv.post.codeOn and not spec.code then
        G.Print(L("POST_CODE_MISSING"))
        return
    end
    spec.title = ownTitle ~= "" and ownTitle or PostTitle(spec)
    -- your own description, else the one built from roles / CP / start / note
    local ownDesc = zo_strtrim(G.sv.post.desc or "")
    spec.desc = ownDesc ~= "" and ownDesc or Parse.BuildPost(spec, true)
    -- a listing is up: change it (the game's Edit), else list a new one
    local editing = Finder.MyListing() ~= nil
    local ok, why = Finder.CreateListing(spec, editing)
    if not ok then G.Print(why or L("POST_FAILED")) else UI.RememberPost(spec) end
end

function UI.PostToChat(channel)
    UI.RememberPost(PostSpec())
    local text = Parse.BuildPost(PostSpec())
    UI.Hide()
    Chat.Prepare(channel, text)
end

function UI.GuildMenu(anchor)
    local guilds = Chat.Guilds()
    if #guilds == 0 then
        G.Print(L("NO_GUILDS"))
        return
    end
    ClearMenu()
    for _, g in ipairs(guilds) do
        AddMenuItem(g.name, function() UI.PostToChat(g.channel) end)
    end
    ShowMenu(anchor or ui.win)
end

-- one role: icon, -, number, +
local function RoleSpinner(parent, role)
    local s = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    s:SetDimensions(150, 32)
    local sv = G.sv.post
    s.icon = W.Tex(s, G.ROLE_ICON[role], 28, 28)
    s.icon:SetAnchor(LEFT, s, LEFT, 0, 0)
    s.minus = W.Button(s, "-", function()
        local v = (tonumber(sv[role]) or 0) - 1
        sv[role] = v > 0 and v or 0
        UI.RefreshPost()
    end, 36)
    s.minus:SetAnchor(LEFT, s.icon, RIGHT, 6, 0)
    s.value = W.Label(s, "ZoFontGameLargeBold", C.selected, "0", TEXT_ALIGN_CENTER)
    s.value:SetDimensions(28, 28)
    s.value:SetAnchor(LEFT, s.minus, RIGHT, 2, 0)
    s.plus = W.Button(s, "+", function()
        sv[role] = math.min(11, (sv[role] or 0) + 1)
        UI.RefreshPost()
    end, 36)
    s.plus:SetAnchor(LEFT, s.value, RIGHT, 2, 0)
    function s:Refresh()
        -- (%d: a stored "-0" showed as "-0" in-game)
        local v = math.max(0, math.floor(tonumber(sv[role]) or 0))
        self.value:SetText(string.format("%d", v))
        self.value:SetColor(G.RGBA(v > 0 and C.selected or C.dim))
    end
    W.Tip(s.icon, G.RoleName(role))
    return s
end

-- ---------------------------------------------------------------------------
-- A small list picker (the Post page's Group Finder options: category, difficulty / option, run /
-- zone, group size, playstyle). A plain right-click menu got too tall for long lists (60 dungeons),
-- so: a panel under the button, scrolls, the current choice marked; click = pick, click outside /
-- x = close. items = { { value, name } }; the first item may be { auto = true, name }.

local LIST_ROW_H = 28
local lp = { rows = {} }

function UI.CloseListPicker()
    if lp.win then lp.win:SetHidden(true) end
    G.EM:UnregisterForEvent("Groupbound_ListPickerClick", EVENT_GLOBAL_MOUSE_DOWN)
end

local function CreateListPicker()
    local win = WINDOW_MANAGER:CreateTopLevelWindow("Groupbound_ListPicker")
    win:SetDimensions(320, 200)
    win:SetDrawTier(DT_HIGH)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    W.Backdrop(win)
    lp.win = win
    lp.title = W.Label(win, "ZoFontWinH5", C.selected, "")
    lp.title:SetAnchor(TOPLEFT, win, TOPLEFT, 14, 10)
    local close = W.TextButton(win, "ZoFontGameBold", "x", function() UI.CloseListPicker() end)
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -12, 6)
    local scroll, child = W.Scroll(win, "Groupbound_ListPickerScroll")
    scroll:SetAnchor(TOPLEFT, win, TOPLEFT, 8, 36)
    scroll:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -8, -10)
    lp.child = child
end

function UI.ListPicker(anchor, title, items, current, onPick)
    if not lp.win then CreateListPicker() end
    lp.title:SetText(zo_strupper(title or ""))
    for i, item in ipairs(items) do
        local row = lp.rows[i]
        if not row then
            row = WINDOW_MANAGER:CreateControl(nil, lp.child, CT_CONTROL)
            row:SetDimensions(290, LIST_ROW_H)
            row:SetAnchor(TOPLEFT, lp.child, TOPLEFT, 0, (i - 1) * LIST_ROW_H)
            row:SetMouseEnabled(true)
            row.hl = W.Highlight(row, 0.14)
            row.label = W.Label(row, "ZoFontGame", C.normal, "")
            row.label:SetAnchor(LEFT, row, LEFT, 10, 0)
            row.label:SetWidth(240)
            row.check = W.Tex(row, CHECK_ICON, 18, 18)
            row.check:SetAnchor(RIGHT, row, RIGHT, -6, 0)
            row.check:SetColor(G.RGBA(C.diffVet))
            row:SetHandler("OnMouseEnter", function() W.HighlightTo(row.hl, "Groupbound_LpHl" .. i, true, 100) end)
            row:SetHandler("OnMouseExit", function() W.HighlightTo(row.hl, "Groupbound_LpHl" .. i, false, 100) end)
            row:SetHandler("OnMouseUp", function(_, button, upInside)
                if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT or not row.item then return end
                PlaySound(SOUNDS.DEFAULT_CLICK)
                local pick = lp.onPick
                local item = row.item
                UI.CloseListPicker()
                if pick then pick(item) end
            end)
            lp.rows[i] = row
        end
        row.item = item
        row.label:SetText(item.name or "")
        row.label:SetColor(G.RGBA(item.auto and C.dim or C.normal))
        local isCurrent = (item.auto and current == nil) or (not item.auto and item.value == current)
        row.check:SetHidden(not isCurrent)
        row:SetHidden(false)
    end
    for i = #items + 1, #lp.rows do
        lp.rows[i].item = nil
        lp.rows[i]:SetHidden(true)
    end
    lp.child:SetHeight(#items * LIST_ROW_H)
    lp.onPick = onPick
    lp.win:SetHeight(math.min(46 + #items * LIST_ROW_H, 420))
    lp.win:ClearAnchors()
    lp.win:SetAnchor(TOPLEFT, anchor, BOTTOMLEFT, 0, 4)
    lp.win:SetHidden(false)
    lp.win:SetAlpha(0)
    W.FadeTo(lp.win, "Groupbound_ListPicker", 1, 150)
    -- a click anywhere else closes it
    G.EM:RegisterForEvent("Groupbound_ListPickerClick", EVENT_GLOBAL_MOUSE_DOWN, function()
        if lp.win and not lp.win:IsHidden() and not G.IsOver(lp.win) then UI.CloseListPicker() end
    end)
end

-- ---------------------------------------------------------------------------
-- The Post page's Group Finder options (picked 2026-10-13: "the exact same options as the game's
-- own Group Finder"): category, difficulty / option, run / zone, group size, playstyle, title,
-- voice chat, auto-accept, enforce roles, invite code (+ Min. CP and the roles above).

local function CategoryName(cat)
    local name = cat ~= nil and GetString("SI_GROUPFINDERCATEGORY", cat) or ""
    return name ~= "" and name or tostring(cat)
end

local function NameOf(list, value)
    for _, item in ipairs(list) do
        if item.value == value then return item.name end
    end
end

local function WithAuto(autoText, list)
    local items = { { auto = true, name = autoText } }
    for _, item in ipairs(list) do items[#items + 1] = item end
    return items
end

local OPT_LABEL_W = 120          -- the listing's option rows: label width, then the choice
local OPT_ROW_H = 36

-- ---------------------------------------------------------------------------
-- Drawers (picked 2026-10-14, sketch C "essentials + drawers", user: "too hectic, make it neat"):
-- what you run + who you need always open at the top; the rest in three drawers that fold to one
-- summary line (gold when something in it differs from the default). Opened drawers stay open
-- (sv.postOpen). Opening one unfolds its body (fade) while the drawers below glide down; when they
-- wouldn't all fit above the preview, the other open drawers close.
local FULL_W = RIGHT_W - 20
local DRAWER_ARROW = "EsoUI/Art/Buttons/tree_closed_up.dds"   -- turned -pi/2 = points down (open)
local DRAWER_HEAD_H = 34
local DRAWER_BODY_GAP = 8         -- header line -> body
local DRAWER_AFTER = 10           -- below an open body
local DRAWER_STEP = 4             -- between drawers
local ROW2_Y = 90                 -- Min. CP / Starts / Note / Auto-accept line
local DRAWERS_TOP = 158           -- under the always-open part
local POST_BOTTOM_H = 140         -- preview + buttons at the page bottom
local GRID_GAP = 40
local GRID_W = math.floor((FULL_W - GRID_GAP) / 2)

-- a button's text, remembered for the summaries (the game's buttons have no GetText: calling it
-- broke the whole page in-game 2026-10-14)
local function BtnText(b, text)
    b:SetText(text)
    b.gbText = text
end

local function DrawerHeight(d)
    local h = d.headH or DRAWER_HEAD_H
    if G.sv.postOpen[d.key] then h = h + DRAWER_BODY_GAP + (d.bodyH or 0) + DRAWER_AFTER end
    return h
end

-- places the drawers one under the other (animate: glide + body fade + arrow turn)
local function LayoutDrawers(animate)
    if not post.drawers then return end
    local y = DRAWERS_TOP
    for i, d in ipairs(post.drawers) do
        local open = G.sv.postOpen[d.key] and true or false
        d.head:SetHeight(d.headH or DRAWER_HEAD_H)
        d.body:SetHeight(d.bodyH or 0)
        d.body:ClearAnchors()
        d.body:SetAnchor(TOPLEFT, d.ctrl, TOPLEFT, 0, (d.headH or DRAWER_HEAD_H) + DRAWER_BODY_GAP)
        -- position
        if d.targetY ~= y then
            local from = d.curY or y
            d.targetY = y
            local key = "Groupbound_DrawerY" .. i
            local function Place(v)
                d.curY = v
                d.ctrl:ClearAnchors()
                d.ctrl:SetAnchor(TOPLEFT, ui.post, TOPLEFT, 0, v)
            end
            if animate and d.curY then
                local to = y
                Anim.Run(key, Anim.STD, Anim.Out, function(p) Place(Anim.Lerp(from, to, p)) end)
            else
                Anim.Stop(key)
                Place(y)
            end
        end
        -- body + arrow
        if d.shownOpen ~= open then
            d.shownOpen = open
            local fromRot = open and 0 or -math.pi / 2
            local toRot = open and -math.pi / 2 or 0
            local bodyKey = "Groupbound_DrawerBody" .. i
            if open then
                d.body:SetHidden(false)
                if animate then
                    d.body:SetAlpha(0)
                    G.Later(function() W.FadeTo(d.body, bodyKey, 1, Anim.OPEN) end, 80, "UI")
                else
                    Anim.Stop(bodyKey)
                    d.body:SetAlpha(1)
                end
            elseif animate then
                W.FadeTo(d.body, bodyKey, 0, 120, function() d.body:SetHidden(true) end)
            else
                Anim.Stop(bodyKey)
                d.body:SetHidden(true)
            end
            if animate then
                Anim.Run("Groupbound_DrawerArrow" .. i, Anim.STD, Anim.Out, function(p)
                    d.arrow:SetTextureRotation(Anim.Lerp(fromRot, toRot, p))
                end)
            else
                d.arrow:SetTextureRotation(toRot)
            end
        end
        y = y + DrawerHeight(d) + DRAWER_STEP
    end
    -- YOUR POST + buttons follow right under the drawers (user 2026-10-14: no big gap), never
    -- below the page bottom
    local b = post.bottom
    if b then
        local maxY = (ui.post:GetHeight() or 0) - POST_BOTTOM_H
        local to = y + 12
        if maxY > 0 and to > maxY then to = maxY end
        if b.targetY ~= to then
            local from = b.curY or to
            b.targetY = to
            local function Place(v)
                b.curY = v
                b:ClearAnchors()
                b:SetAnchor(TOPLEFT, ui.post, TOPLEFT, 0, v)
            end
            if animate and b.curY then
                Anim.Run("Groupbound_PostBottom", Anim.STD, Anim.Out, function(p) Place(Anim.Lerp(from, to, p)) end)
            else
                Anim.Stop("Groupbound_PostBottom")
                Place(to)
            end
        end
    end
end

-- the room the drawers have (page height minus the always-open part and the preview)
local function DrawerRoom()
    local h = ui.post and ui.post:GetHeight() or 0
    if h <= 0 then h = WIN_H - TOP_Y - 20 end
    return h - POST_BOTTOM_H - 6 - DRAWERS_TOP
end

function UI.TogglePostDrawer(key)
    local open = G.sv.postOpen
    open[key] = not open[key] or nil
    UI.CloseListPicker()
    UI.CloseAchPicker()
    if open[key] then
        -- too tall for the page: close the other open drawers (first ones first)
        local function Total()
            local t = 0
            for _, d in ipairs(post.drawers) do t = t + DrawerHeight(d) + DRAWER_STEP end
            return t
        end
        for _, d in ipairs(post.drawers) do
            if Total() <= DrawerRoom() then break end
            if d.key ~= key and open[d.key] then open[d.key] = nil end
        end
    end
    PlaySound(SOUNDS.DEFAULT_CLICK)
    LayoutDrawers(true)
end

-- one drawer's summary line: parts joined with " · ", gold when changed
local function SetSummary(d, parts, changed)
    d.sum:SetText(table.concat(parts, "  ·  "))
    d.sum:SetColor(G.RGBA(changed and C.diffVet or C.dim))
    -- a long summary wraps: the header grows with it
    local h = math.max(DRAWER_HEAD_H, math.ceil(d.sum:GetTextHeight()) + 14)
    if h ~= d.headH then
        d.headH = h
        return true
    end
end

local function PaintSummaries(spec, cat)
    local sv = G.sv.post
    local relayout = false
    -- more details: achievement + description
    local parts, changed = {}, false
    if spec.ach then
        parts[#parts + 1] = L("SUM_ACH", G.Achieve.Name(spec.ach) or "")
        changed = true
    else
        parts[#parts + 1] = L("POST_ACH_CLEAR")
    end
    local own = zo_strtrim(sv.desc or "") ~= ""
    parts[#parts + 1] = L(own and "SUM_DESC_OWN" or "SUM_DESC_AUTO")
    if own then changed = true end
    if SetSummary(post.drawerMore, parts, changed) then relayout = true end
    -- the Group Finder listing (auto-accept is on the page itself)
    parts, changed = {}, false
    parts[1] = post.catBtn.gbText or ""
    for _, row in ipairs({ post.rowPrim, post.rowSec, post.rowSize, post.rowStyle }) do
        if row.shown and row.isSet() then
            parts[#parts + 1] = row.ctrl.gbText or ""
            changed = true
        end
    end
    if sv.cat then changed = true end
    if zo_strtrim(sv.title or "") ~= "" then
        parts[#parts + 1] = L("SUM_TITLE")
        changed = true
    end
    if sv.voip then parts[#parts + 1] = L("POST_VOIP") changed = true end
    if sv.enforce ~= false then parts[#parts + 1] = L("SUM_ENFORCE") else parts[#parts + 1] = L("SUM_ANY_ROLE") changed = true end
    if sv.codeOn then parts[#parts + 1] = L("POST_CODE") changed = true end
    if SetSummary(post.drawerListing, parts, changed) then relayout = true end
    return relayout
end

-- what the option buttons say, which option rows show (the rest close up)
function UI.RefreshPostOptions(spec)
    local sv = G.sv.post
    local cat = PostCategory(spec)
    BtnText(post.catBtn, sv.cat and CategoryName(sv.cat) or L("POST_AUTO_IS", CategoryName(cat)))
    local choices = Finder.DraftChoices(cat, sv.primaryIdx)
    post.choices = choices
    -- primary: the difficulty for trials / dungeons / arenas, else the category's first option
    local hasPrimary = #choices.primaries > 0
    post.rowPrim.shown = hasPrimary
    if hasPrimary then
        post.rowPrim.label:SetText(Finder.HasDifficulty(cat) and L("POST_DIFFICULTY") or L("POST_OPTION"))
        local name = sv.primaryIdx and NameOf(choices.primaries, sv.primaryIdx)
        if not name then
            if Finder.HasDifficulty(cat) then
                name = L("POST_AUTO_IS", spec.vet and L("VETERAN") or L("NORMAL"))
            else
                name = L("POST_GAME_DEFAULT")
            end
        end
        BtnText(post.primBtn, name)
    end
    -- secondary: the run / zone / campaign
    local hasSecondary = #choices.secondaries > 0
    post.rowSec.shown = hasSecondary
    if hasSecondary then
        local name = sv.secondaryIdx and NameOf(choices.secondaries, sv.secondaryIdx)
        if not name then
            if spec.key and Content.Category(spec.key) == cat then
                name = L("POST_AUTO_IS", Content.Name(spec.key))
            else
                name = L("POST_GAME_DEFAULT")
            end
        end
        BtnText(post.secBtn, name)
    end
    post.rowSize.shown = #choices.sizes > 0
    BtnText(post.sizeBtn, sv.size and NameOf(choices.sizes, sv.size) or L("POST_GAME_DEFAULT"))
    BtnText(post.styleBtn, sv.playstyle and NameOf(Finder.Playstyles(), sv.playstyle) or L("POST_GAME_DEFAULT"))
    if post.titleEdit.SetDefaultText then post.titleEdit:SetDefaultText(PostTitle(spec)) end
    -- the description box shows (in grey) what Groupbound would write
    if post.descEdit.SetDefaultText then post.descEdit:SetDefaultText(Parse.BuildPost(spec, true)) end
    -- a listing is up: the button changes it
    local editing = Finder.MyListing() ~= nil
    post.listBtn:SetText(L(editing and "POST_UPDATE" or "POST_FINDER"))
    post.codeBox:SetHidden(not sv.codeOn)
    for _, c in ipairs(post.checks) do c:Refresh() end
    -- the listing's rows two by two (left, right, next line), hidden ones leave no gap
    local body = post.drawerListing.body
    local n = 0
    for _, row in ipairs(post.optRows) do
        row.label:SetHidden(not row.shown)
        row.ctrl:SetHidden(not row.shown)
        if row.shown then
            local x = (n % 2) * (GRID_W + GRID_GAP)
            local y = math.floor(n / 2) * OPT_ROW_H
            row.label:ClearAnchors()
            row.label:SetAnchor(LEFT, body, TOPLEFT, x, y + 17)
            row.ctrl:ClearAnchors()
            row.ctrl:SetAnchor(LEFT, body, TOPLEFT, x + OPT_LABEL_W, y + 17)
            n = n + 1
        end
    end
    local checksY = math.ceil(n / 2) * OPT_ROW_H + 4
    post.checksHolder:ClearAnchors()
    post.checksHolder:SetAnchor(TOPLEFT, body, TOPLEFT, 0, checksY)
    local bodyH = checksY + 32
    local relayout = PaintSummaries(spec, cat)
    if bodyH ~= post.drawerListing.bodyH then
        post.drawerListing.bodyH = bodyH
        relayout = true
    end
    if relayout or not post.drawersPlaced then
        post.drawersPlaced = true
        LayoutDrawers(false)
        -- (wrapped text heights settle a frame later)
        G.Later(function() if PaintSummaries(PostSpec(), PostCategory(PostSpec())) then LayoutDrawers(false) end end, 50, "UI")
    end
end

-- Layout (2026-10-14, sketch C, see the drawers above):
--   top      WHAT DO YOU RUN? (left) and WHO YOU NEED (right), always open
--   drawers  REQUIREMENTS AND DETAILS (Min. CP, starts, note, achievement), GROUP FINDER LISTING
--            (option rows two by two + the checkboxes), DESCRIPTION
--   bottom   YOUR POST (preview) and the buttons
local COL_GAP = 40
local COL_W = math.floor((RIGHT_W - 20 - COL_GAP) / 2)

local function CreatePost(win)
    local p = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    p:SetAnchor(TOPLEFT, win, TOPLEFT, RIGHT_X, TOP_Y)
    p:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -30, -20)
    p:SetHidden(true)
    ui.post = p
    ui.postFields = {}
    local sv = G.sv.post
    local function Changed() UI.RefreshPost() end

    -- a column (it fades in as one piece when the page opens)
    local function Column(x, w, h)
        local c = WINDOW_MANAGER:CreateControl(nil, p, CT_CONTROL)
        c:SetDimensions(w, h)
        c:SetAnchor(TOPLEFT, p, TOPLEFT, x, 0)
        ui.postFields[#ui.postFields + 1] = c
        return c
    end
    -- a section heading (small white caps + a faint line), returns the y below it
    local function Heading(parent, y, key)
        local h = W.Label(parent, "ZoFontWinH5", C.selected, zo_strupper(L(key)))
        h:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, y)
        local line = W.Tex(parent, nil, nil, nil, C.normal, 0.2)
        line:SetAnchor(LEFT, h, RIGHT, 10, 1)
        line:SetAnchor(RIGHT, parent, TOPRIGHT, 0, y + 10)
        line:SetHeight(1)
        return y + 28
    end
    local function Label(parent, text, x, y, font)
        local l = W.Label(parent, font or "ZoFontGameBold", C.normal, text)
        l:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
        return l
    end

    -- a drawer: header (arrow, title, summary right) + a body that folds away
    post.drawers = {}
    local function Drawer(key, titleKey, tip)
        local d = { key = key, headH = DRAWER_HEAD_H, bodyH = 0 }
        d.ctrl = WINDOW_MANAGER:CreateControl(nil, p, CT_CONTROL)
        d.ctrl:SetWidth(FULL_W)
        d.ctrl:SetHeight(DRAWER_HEAD_H)
        d.head = WINDOW_MANAGER:CreateControl(nil, d.ctrl, CT_CONTROL)
        d.head:SetAnchor(TOPLEFT, d.ctrl, TOPLEFT, 0, 0)
        d.head:SetDimensions(FULL_W, DRAWER_HEAD_H)
        d.head:SetMouseEnabled(true)
        d.hl = W.Highlight(d.head, 0.12)
        d.arrow = W.Tex(d.head, DRAWER_ARROW, 16, 16, C.normal)
        d.arrow:SetAnchor(LEFT, d.head, LEFT, 4, 0)
        d.title = W.Label(d.head, "ZoFontWinH5", C.selected, zo_strupper(L(titleKey)))
        d.title:SetAnchor(LEFT, d.arrow, RIGHT, 8, 0)
        d.sum = W.Label(d.head, "ZoFontGame", C.dim, "", TEXT_ALIGN_RIGHT)
        d.sum:SetAnchor(RIGHT, d.head, RIGHT, -8, 0)
        d.sum:SetWidth(FULL_W - 320)
        local line = W.Tex(d.head, nil, nil, nil, C.normal, 0.2)
        line:SetAnchor(BOTTOMLEFT, d.head, BOTTOMLEFT, 0, 0)
        line:SetAnchor(BOTTOMRIGHT, d.head, BOTTOMRIGHT, 0, 0)
        line:SetHeight(1)
        d.body = WINDOW_MANAGER:CreateControl(nil, d.ctrl, CT_CONTROL)
        d.body:SetWidth(FULL_W)
        d.body:SetHidden(true)
        local hlKey = "Groupbound_DrawerHl" .. key
        d.head:SetHandler("OnMouseEnter", function(self)
            W.HighlightTo(d.hl, hlKey, true, 100)
            d.title:SetColor(G.RGBA(C.highlight))
            d.arrow:SetColor(G.RGBA(C.highlight))
            InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -4, TOP)
            SetTooltipText(InformationTooltip, (tip and L(tip) .. "\n" or "") .. L("POST_DRAWER_TT"))
        end)
        d.head:SetHandler("OnMouseExit", function()
            W.HighlightTo(d.hl, hlKey, false, 150)
            d.title:SetColor(G.RGBA(C.selected))
            d.arrow:SetColor(G.RGBA(C.normal))
            ClearTooltip(InformationTooltip)
        end)
        d.head:SetHandler("OnMouseUp", function(_, button, upInside)
            if upInside and button == MOUSE_BUTTON_INDEX_LEFT then UI.TogglePostDrawer(key) end
        end)
        post.drawers[#post.drawers + 1] = d
        ui.postFields[#ui.postFields + 1] = d.ctrl
        return d
    end

    -- ---------------------------------------------------------------- top: always open
    local left = Column(0, COL_W, ROW2_Y - 4)
    local y = Heading(left, 0, "POST_WHAT")
    local box, edit = W.Edit(left, COL_W, L("POST_WHAT_HINT"))
    box:SetAnchor(TOPLEFT, left, TOPLEFT, 0, y)
    edit:SetMaxInputChars(60)
    edit:SetText(sv.text or "")
    -- (the run already typed when the page is made: don't overwrite your fields with its saved setup)
    post.lastKey = Parse.Scan(sv.text or "").content
    edit:SetHandler("OnTextChanged", function()
        sv.text = edit:GetText() or ""
        RestorePost(Parse.Scan(sv.text).content)
        UI.RefreshPost()
    end, "Groupbound")
    post.text = edit
    post.resolved = W.Label(left, "ZoFontGame", C.dim, "")
    post.resolved:SetAnchor(TOPLEFT, left, TOPLEFT, 0, y + 34)
    post.resolved:SetWidth(COL_W)

    local need = Column(COL_W + COL_GAP, COL_W, ROW2_Y - 4)
    y = Heading(need, 0, "POST_NEED")
    post.spinners = {}
    for i, role in ipairs(G.ROLES) do
        local s = RoleSpinner(need, role)
        s:SetAnchor(TOPLEFT, need, TOPLEFT, (i - 1) * 146, y)
        post.spinners[i] = s
    end

    -- ---------------------------------------------------------------- top, 2nd line: the usual extras
    -- (user 2026-10-14: the options most people set stay on the page, the rest in the drawers)
    -- Min. CP | Starts | Note | Auto-accept (labels above the fields)
    local row2 = WINDOW_MANAGER:CreateControl(nil, p, CT_CONTROL)
    row2:SetDimensions(FULL_W, 56)
    row2:SetAnchor(TOPLEFT, p, TOPLEFT, 0, ROW2_Y)
    ui.postFields[#ui.postFields + 1] = row2
    left = row2
    y = 0
    local NOTE_X = 320
    local AUTO_W = 170
    local noteW = FULL_W - NOTE_X - 30 - AUTO_W
    Label(left, L("POST_CP"), 0, y)
    local cpBox, cpEdit = W.Edit(left, 110, "0")
    cpBox:SetAnchor(TOPLEFT, left, TOPLEFT, 0, y + 22)
    cpEdit:SetTextType(TEXT_TYPE_NUMERIC_UNSIGNED_INT)
    cpEdit:SetMaxInputChars(4)
    cpEdit:SetText(sv.cp and sv.cp > 0 and tostring(sv.cp) or "")
    cpEdit:SetHandler("OnTextChanged", function()
        sv.cp = tonumber(cpEdit:GetText()) or 0
        UI.RefreshPost()
    end, "Groupbound")
    post.cpEdit = cpEdit
    local startLabel = Label(left, L("POST_START"), 130, y)
    W.Tip(startLabel, L("POST_START_TT"))
    local startBox, startEdit = W.Edit(left, NOTE_X - 20 - 130, L("POST_START_HINT"))
    startBox:SetAnchor(TOPLEFT, left, TOPLEFT, 130, y + 22)
    startEdit:SetMaxInputChars(8)
    startEdit:SetText(sv.time or "")
    startEdit:SetHandler("OnTextChanged", function()
        sv.time = startEdit:GetText() or ""
        UI.RefreshPost()
    end, "Groupbound")

    Label(left, L("POST_NOTE"), NOTE_X, y)
    local noteBox, noteEdit = W.Edit(left, noteW, L("POST_NOTE_HINT"))
    noteBox:SetAnchor(TOPLEFT, left, TOPLEFT, NOTE_X, y + 22)
    noteEdit:SetMaxInputChars(120)
    noteEdit:SetText(sv.note or "")
    noteEdit:SetHandler("OnTextChanged", function()
        sv.note = noteEdit:GetText() or ""
        UI.RefreshPost()
    end, "Groupbound")
    post.noteEdit = noteEdit
    -- auto-accept: join right away or apply (the one listing option most people set)
    post.checks = {}
    local autoCheck = W.Check(left, L("POST_AUTO_ACCEPT"), function() return sv.auto end, function(v)
        sv.auto = v
        Changed()
    end, L("POST_AUTO_ACCEPT_TT"))
    autoCheck:SetAnchor(TOPLEFT, left, TOPLEFT, FULL_W - AUTO_W, y + 28)
    post.checks[#post.checks + 1] = autoCheck

    -- ---------------------------------------------------------------- drawer 1: more details
    -- an achievement the group asks for (chat posts get its link) + the listing's description
    -- (empty = Groupbound writes it, shown in grey)
    local more = Drawer("more", "POST_SEC_MORE")
    post.drawerMore = more
    more.bodyH = 128
    Label(more.body, L("POST_ACH_LABEL"), 0, 6)
    post.ach = W.Button(more.body, L("POST_ACH"), function(b) UI.AchMenu(b) end, 300, L("POST_ACH_TT"))
    post.ach:SetAnchor(TOPLEFT, more.body, TOPLEFT, OPT_LABEL_W, 0)
    local descLabel = Label(more.body, L("POST_DESC"), 0, 42)
    W.Tip(descLabel, L("POST_DESC_TT"))
    local descBox, descEdit = W.MultiEdit(more.body, FULL_W, 64, "")
    descBox:SetAnchor(TOPLEFT, more.body, TOPLEFT, 0, 64)
    if descEdit.SetMaxInputChars then descEdit:SetMaxInputChars(GROUP_FINDER_GROUP_LISTING_DESCRIPTION_MAX_LENGTH or 300) end
    descEdit:SetText(sv.desc or "")
    descEdit:SetHandler("OnTextChanged", function()
        sv.desc = descEdit:GetText() or ""
        Changed()
    end, "Groupbound")
    post.descEdit = descEdit

    -- ---------------------------------------------------------------- drawer 2: the Group Finder listing
    local listing = Drawer("listing", "POST_SEC_LISTING", "POST_LISTING_HINT")
    post.drawerListing = listing
    local right = listing.body
    post.optRows = {}
    -- one option row: label left, a button that opens the list picker right (placed two by two in
    -- RefreshPostOptions); isSet = you picked something (not Auto / Game default)
    local function OptRow(key, open, isSet)
        local row = { shown = true, isSet = isSet or function() return false end }
        row.label = W.Label(right, "ZoFontGameBold", C.normal, L(key))
        local b
        b = W.Button(right, "", function() open(b) end, GRID_W - OPT_LABEL_W)
        row.ctrl = b
        post.optRows[#post.optRows + 1] = row
        return row, b
    end
    post.rowCat, post.catBtn = OptRow("POST_CATEGORY", function(b)
        UI.ListPicker(b, L("POST_CATEGORY"), WithAuto(L("POST_AUTO"), Finder.Categories()), sv.cat, function(item)
            sv.cat = item.value
            -- (another category has other options)
            sv.primaryIdx, sv.secondaryIdx, sv.size = nil, nil, nil
            Changed()
        end)
    end)
    post.rowPrim, post.primBtn = OptRow("POST_DIFFICULTY", function(b)
        local items = WithAuto(L("POST_AUTO"), post.choices and post.choices.primaries or {})
        UI.ListPicker(b, post.rowPrim.label:GetText(), items, sv.primaryIdx, function(item)
            sv.primaryIdx = item.value
            sv.secondaryIdx = nil
            Changed()
        end)
    end, function() return sv.primaryIdx ~= nil end)
    post.rowSec, post.secBtn = OptRow("POST_RUN", function(b)
        local items = WithAuto(L("POST_AUTO"), post.choices and post.choices.secondaries or {})
        UI.ListPicker(b, L("POST_RUN"), items, sv.secondaryIdx, function(item)
            sv.secondaryIdx = item.value
            Changed()
        end)
    end, function() return sv.secondaryIdx ~= nil end)
    post.rowSize, post.sizeBtn = OptRow("POST_SIZE", function(b)
        local items = WithAuto(L("POST_GAME_DEFAULT"), post.choices and post.choices.sizes or {})
        UI.ListPicker(b, L("POST_SIZE"), items, sv.size, function(item)
            sv.size = item.value
            Changed()
        end)
    end, function() return sv.size ~= nil end)
    post.rowStyle, post.styleBtn = OptRow("POST_PLAYSTYLE", function(b)
        UI.ListPicker(b, L("POST_PLAYSTYLE"), WithAuto(L("POST_GAME_DEFAULT"), Finder.Playstyles()), sv.playstyle, function(item)
            sv.playstyle = item.value
            Changed()
        end)
    end, function() return sv.playstyle ~= nil end)
    -- the title row: a text field instead of a button
    local titleRow = { shown = true }
    titleRow.label = W.Label(right, "ZoFontGameBold", C.normal, L("POST_TITLE"))
    local titleBox, titleEdit = W.Edit(right, GRID_W - OPT_LABEL_W, "")
    titleRow.ctrl = titleBox
    titleEdit:SetMaxInputChars(GROUP_FINDER_GROUP_LISTING_TITLE_MAX_LENGTH or 40)
    titleEdit:SetText(sv.title or "")
    titleEdit:SetHandler("OnTextChanged", function()
        sv.title = titleEdit:GetText() or ""
        Changed()
    end, "Groupbound")
    W.Tip(titleBox, L("POST_TITLE_TT"))
    post.titleEdit = titleEdit
    post.optRows[#post.optRows + 1] = titleRow

    -- the game's checkboxes in one line (+ the invite code's field)
    local holder = WINDOW_MANAGER:CreateControl(nil, right, CT_CONTROL)
    holder:SetDimensions(FULL_W, 30)
    post.checksHolder = holder
    local function Check(x, cy, key, tip, get, set)
        local c = W.Check(holder, L(key), get, function(v)
            set(v)
            Changed()
        end, tip and L(tip) or nil)
        c:SetAnchor(TOPLEFT, holder, TOPLEFT, x, cy)
        post.checks[#post.checks + 1] = c
        return c
    end
    -- (voice | enforce roles under the left options, invite code + field under the right ones;
    -- auto-accept sits on the page itself)
    local col2 = GRID_W + GRID_GAP
    local half = math.floor(GRID_W / 2)
    Check(0, 6, "POST_VOIP", nil, function() return sv.voip end, function(v) sv.voip = v end)
    Check(half, 6, "POST_ENFORCE", "POST_ENFORCE_TT", function() return sv.enforce ~= false end, function(v) sv.enforce = v end)
    Check(col2, 6, "POST_CODE", "POST_CODE_TT", function() return sv.codeOn end, function(v) sv.codeOn = v end)
    local codeBox, codeEdit = W.Edit(holder, 90, L("POST_CODE_HINT"))
    codeBox:SetAnchor(TOPRIGHT, holder, TOPRIGHT, 0, 0)
    codeEdit:SetTextType(TEXT_TYPE_NUMERIC_UNSIGNED_INT)
    codeEdit:SetMaxInputChars(GROUP_FINDER_GROUP_LISTING_INVITE_CODE_MAX_LENGTH or 6)
    codeEdit:SetText(sv.code or "")
    codeEdit:SetHandler("OnTextChanged", function() sv.code = codeEdit:GetText() or "" end, "Groupbound")
    post.codeBox = codeBox

    -- ---------------------------------------------------------------- bottom: your post + buttons
    local bottom = WINDOW_MANAGER:CreateControl(nil, p, CT_CONTROL)
    bottom:SetDimensions(RIGHT_W - 20, POST_BOTTOM_H)
    -- (placed under the drawers by LayoutDrawers)
    bottom:SetAnchor(BOTTOMLEFT, p, BOTTOMLEFT, 0, 0)
    post.bottom = bottom
    ui.postFields[#ui.postFields + 1] = bottom
    local by = Heading(bottom, 0, "POST_PREVIEW")
    post.preview = W.Label(bottom, "ZoFontGame", C.selected, "")
    post.preview:SetAnchor(TOPLEFT, bottom, TOPLEFT, 0, by - 2)
    post.preview:SetWidth(RIGHT_W - 20)
    local listBtn = W.Button(bottom, L("POST_FINDER"), function() UI.PostToFinder() end, 230, function()
        return L(Finder.MyListing() and "POST_UPDATE_TT" or "POST_FINDER_TT")
    end)
    listBtn:SetAnchor(BOTTOMLEFT, bottom, BOTTOMLEFT, 0, -26)
    post.listBtn = listBtn
    local zoneBtn = W.Button(bottom, L("POST_ZONE"), function() UI.PostToChat(CHAT_CHANNEL_ZONE) end, 160, L("POST_CHAT_TT"))
    zoneBtn:SetAnchor(LEFT, listBtn, RIGHT, 10, 0)
    local guildBtn
    guildBtn = W.Button(bottom, L("POST_GUILD"), function() UI.GuildMenu(guildBtn) end, 160, L("POST_CHAT_TT"))
    guildBtn:SetAnchor(LEFT, zoneBtn, RIGHT, 10, 0)
    post.listing = W.Label(bottom, "ZoFontGame", C.good, "")
    post.listing:SetAnchor(LEFT, guildBtn, RIGHT, 20, 0)
    post.listing:SetWidth(RIGHT_W - 20 - 580)
    local chatHint = W.Label(bottom, "ZoFontGameSmall", C.dim, L("POST_HINT"))
    chatHint:SetAnchor(BOTTOMLEFT, bottom, BOTTOMLEFT, 0, 0)
    chatHint:SetWidth(RIGHT_W - 20)
end

-- ---------------------------------------------------------------------------
-- The window

local function CreateAlerts(win)
    local p = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    p:SetAnchor(TOPLEFT, win, TOPLEFT, RIGHT_X, TOP_Y)
    p:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -30, -20)
    p:SetHidden(true)
    ui.alerts = p
    ui.alertRows = {}
    local intro = W.Label(p, "ZoFontGame", C.normal, L("ALERTS_INTRO"))
    intro:SetAnchor(TOPLEFT, p, TOPLEFT, 0, 0)
    intro:SetWidth(RIGHT_W - 20)
    local all = W.Check(p, L("SET_ALERT_ALL"), function() return G.sv.alertAll end, function(v) G.sv.alertAll = v end, L("SET_ALERT_ALL_TT"))
    all:SetAnchor(TOPLEFT, p, TOPLEFT, 0, 52)
    ui.checks[#ui.checks + 1] = all
    ui.alertsNone = W.Label(p, "ZoFontGame", C.dim, L("ALERTS_NONE"))
    ui.alertsNone:SetAnchor(TOPLEFT, p, TOPLEFT, 0, 100)
    ui.alertsNone:SetWidth(RIGHT_W - 20)
end

local function CreateList(win)
    local p = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    p:SetAnchor(TOPLEFT, win, TOPLEFT, RIGHT_X, TOP_Y)
    p:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -30, -20)
    ui.list = p
    -- column headers (the game's sort header look: uppercase, white when sorted by it)
    ui.headers = {}
    local HEADERS = { trial = "COL_TRIAL", group = "COL_GROUP", open = "COL_OPEN", leader = "COL_LEADER", from = "COL_FROM", size = "COL_SIZE" }
    for _, col in ipairs(COLS) do
        local h = W.TextButton(p, "ZoFontGame", zo_strupper(L(HEADERS[col.key])), function(self)
            PlaySound(SOUNDS.DEFAULT_CLICK)
            if G.sv.sortKey == self.key then
                if not G.sv.sortUp then
                    -- third click: back to "best for you"
                    G.sv.sortKey, G.sv.sortUp = "best", true
                else
                    G.sv.sortUp = false
                end
            else
                G.sv.sortKey, G.sv.sortUp = self.key, true
            end
            UI.LayoutList("live")
        end)
        h.key = col.key
        h.tooltip = L("SORT_TT")
        if col.key == "size" then ui.sizeHead = h end
        h:SetAnchor(TOPLEFT, p, TOPLEFT, col.x + 6, 6)
        ui.headers[#ui.headers + 1] = h
    end
    local scroll, child = W.Scroll(p, "Groupbound_ListScroll")
    scroll:SetAnchor(TOPLEFT, p, TOPLEFT, 0, HEADER_H)
    scroll:SetAnchor(BOTTOMRIGHT, p, BOTTOMRIGHT, 0, 0)
    ui.listScroll, ui.listChild = scroll, child
    ui.empty = W.Label(p, "ZoFontGame", C.dim, "", TEXT_ALIGN_CENTER)
    ui.empty:SetAnchor(TOP, p, TOP, 0, 90)
    ui.empty:SetWidth(RIGHT_W - 80)
    -- an empty board isn't a dead end (2026-10-14): "Alert me" for the run you searched, and
    -- "Post your own" (the Post page with that run typed in)
    ui.emptyAlert = W.Button(p, "", function()
        if ui.emptyKey then
            UI.ToggleWatch(ui.emptyKey)
            UI.PaintEmpty(0)
        end
    end, 280)
    ui.emptyAlert:SetAnchor(TOPRIGHT, ui.empty, BOTTOM, -10, 20)
    ui.emptyPost = W.Button(p, "", function()
        local q = ui.search and zo_strtrim(ui.search:GetText() or "") or ""
        if ui.emptyKey and q ~= "" then
            G.sv.post.text = q
            if post.text then post.text:SetText(q) end
        end
        UI.SetView("post")
    end, 280)
    ui.emptyPost:SetAnchor(TOPLEFT, ui.empty, BOTTOM, 10, 20)
end

-- the empty board: a known run searched = "No vSS groups right now." + Alert me + Post your own;
-- else the usual text + Post a group
function UI.PaintEmpty(count)
    if not ui.empty then return end
    local empty = count == 0
    ui.empty:SetHidden(not empty)
    ui.emptyPost:SetHidden(not empty)
    ui.emptyAlert:SetHidden(true)
    if not empty then return end
    local q = ui.search and zo_strtrim(ui.search:GetText() or "") or ""
    local key = q ~= "" and Parse.Scan(q).content or nil
    ui.emptyKey = key
    if key then
        ui.empty:SetText(L("EMPTY_RUN", Content.Name(key)))
        ui.emptyAlert:SetHidden(false)
        ui.emptyAlert:SetText(L(G.sv.watches[key] and "EMPTY_ALERT_ON" or "EMPTY_ALERT"))
        ui.emptyPost:SetText(L("EMPTY_POST_OWN"))
        ui.emptyPost:ClearAnchors()
        ui.emptyPost:SetAnchor(TOPLEFT, ui.empty, BOTTOM, 10, 20)
    else
        ui.empty:SetText(Board.query ~= "" and L("EMPTY_SEARCH") or L("EMPTY_BOARD"))
        ui.emptyPost:SetText(L("POST_A_GROUP"))
        ui.emptyPost:ClearAnchors()
        ui.emptyPost:SetAnchor(TOP, ui.empty, BOTTOM, 0, 20)
    end
end

local function CreateTree(win)
    local y = TOP_Y
    -- glow + gold edge behind the picked entry (placed by PaintTree); plain see-through fill (a
    -- gradient's alpha is ignored on plain textures)
    ui.treeSel = W.Tex(win, nil, TREE_W + 4, 30, C.selected, 0.08)
    ui.treeSel:SetHidden(true)
    ui.treeEdge = W.Tex(win, nil, 2, 30, C.diffVet, 1)
    ui.treeEdge:SetHidden(true)
    for _, def in ipairs(TREE) do
        if def.head then
            local h = W.Label(win, "ZoFontWinH5", C.selected, zo_strupper(L(def.head)))
            h:SetAnchor(TOPLEFT, win, TOPLEFT, LEFT_X, y + (y > TOP_Y and 10 or 0))
            y = y + (y > TOP_Y and 38 or 28)
        else
            local item = W.TextButton(win, "ZoFontHeader2", "", function()
                UI.SetView(def.view)
            end)
            item.def = def
            item:SetAnchor(TOPLEFT, win, TOPLEFT, LEFT_X + 12, y)
            item:SetWidth(TREE_W - 12)
            ui.treeItems[#ui.treeItems + 1] = item
            y = y + 30
        end
    end
    -- filters (the game's checkboxes, like the Friends list's "Hide offline")
    local head = W.Label(win, "ZoFontWinH5", C.selected, zo_strupper(L("TREE_SHOW")))
    head:SetAnchor(TOPLEFT, win, TOPLEFT, LEFT_X, y + 10)
    y = y + 38
    local function Flag(text, tip, get, set)
        local c = W.Check(win, text, get, function(v)
            set(v)
            G.callbacks:FireCallbacks("SettingsChanged")
        end, tip)
        c:SetAnchor(TOPLEFT, win, TOPLEFT, LEFT_X + 12, y)
        ui.checks[#ui.checks + 1] = c
        y = y + 22
    end
    local sv = G.sv
    Flag(L("CHIP_FOR_ME"), L("CHIP_FOR_ME_TT"), function() return sv.forMe end, function(v) sv.forMe = v end)
    Flag(L("CHIP_TEACH"), L("CHIP_TEACH_TT"), function() return sv.teach end, function(v) sv.teach = v end)
    Flag(L("CHIP_PLAYERS"), L("CHIP_PLAYERS_TT"), function() return sv.players end, function(v) sv.players = v end)
    Flag(L("CHIP_LANG"), L("CHIP_LANG_TT"), function() return sv.langFilter end, function(v) sv.langFilter = v end)
    y = y + 6
    Flag(L("CHIP_FINDER"), L("CHIP_FINDER_TT"), function() return sv.sources.finder end, function(v) sv.sources.finder = v end)
    Flag(L("CHIP_ZONE"), L("CHIP_ZONE_TT"), function() return sv.sources.zone end, function(v) sv.sources.zone = v end)
    Flag(L("CHIP_GUILD"), L("CHIP_GUILD_TT"), function() return sv.sources.guild end, function(v) sv.sources.guild = v end)

    -- your application / listing / next step (bottom left)
    ui.sideBtn = W.Button(win, "", function(b) if b.fn then b.fn() end end, TREE_W)
    ui.sideBtn:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, LEFT_X, -20)
    ui.sideBtn:SetHidden(true)
    ui.side = W.Label(win, "ZoFontGameSmall", C.normal, "")
    ui.side:SetAnchor(BOTTOMLEFT, ui.sideBtn, TOPLEFT, 0, -6)
    ui.side:SetWidth(TREE_W)
end

function UI.Create()
    if ui.win then return end
    local win = WINDOW_MANAGER:CreateTopLevelWindow("Groupbound_Board")
    ui.win = win
    -- on the right like the game's menus (ZO_RightPanelFootPrint: RIGHT of GuiRoot, y 32), wider
    win:SetDimensions(WIN_W, WIN_H)
    win:SetAnchor(RIGHT, GuiRoot, RIGHT, 0, 32)
    -- (a big UI scale makes the screen narrower in UI units: stay inside it)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    if DT_MEDIUM then win:SetDrawTier(DT_MEDIUM) end

    -- background: the game's own (RIGHT_BG_FRAGMENT) only covers its 930 px panel, the wider left
    -- part stayed clear (user 2026-10-13: hard to read). Own dark shade from the screen's right edge
    -- over the whole window, full screen height, with a soft fade at its left edge like the game's.
    -- (0.6 was too light over bright scenery at the top, user 2026-10-13: one even shade, darker)
    local BG_ALPHA, BG_FADE = 0.72, 110
    ui.bg = W.Tex(win, nil, nil, nil, C.panel, BG_ALPHA)
    ui.bg:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, 0, 0)
    ui.bg:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, 0, 0)
    ui.bg:SetWidth(WIN_W + 10)
    -- the fade: thin strips side by side, each a bit lighter (a gradient texture drew as a solid
    -- black bar in-game: its alpha was ignored). Strips touch exactly, no overlap (no seams).
    local STRIP = 5
    local n = math.floor(BG_FADE / STRIP)
    local prev = ui.bg
    ui.bgFade = {}
    for i = 1, n do
        local s = W.Tex(win, nil, STRIP, nil, C.panel, BG_ALPHA * (1 - i / (n + 1)))
        s:SetAnchor(TOPRIGHT, prev, TOPLEFT, 0, 0)
        s:SetAnchor(BOTTOMRIGHT, prev, BOTTOMLEFT, 0, 0)
        s:SetWidth(STRIP)
        if DL_BACKGROUND then s:SetDrawLayer(DL_BACKGROUND) end
        ui.bgFade[i] = s
        prev = s
    end
    if DL_BACKGROUND then ui.bg:SetDrawLayer(DL_BACKGROUND) end

    -- title above the window, like the game's menu titles (big caps + a divider under it)
    ui.title = W.Label(win, "ZoFontWinH1", C.selected, zo_strupper(L("TITLE")))
    ui.title:SetAnchor(BOTTOMLEFT, win, TOPLEFT, LEFT_X - 10, -16)
    ui.titleRule = W.Divider(win)
    ui.titleRule:SetAnchor(TOPLEFT, win, TOPLEFT, LEFT_X - 14, -14)
    ui.titleRule:SetAnchor(TOPRIGHT, win, TOPRIGHT, -30, -14)

    -- top: you (click = pick a role), the Group Finder's state, search (like the Friends list)
    -- top left: the game's role buttons, then your role, you, what's going on
    local lastRole = CreateRoleButtons(win)
    -- heading above the three role buttons, like GROUPS / YOURS / SHOW on the left
    ui.roleHead = W.Label(win, "ZoFontWinH5", C.selected, zo_strupper(L("HEADER_YOUR_ROLE")))
    ui.roleHead:SetAnchor(TOPLEFT, win, TOPLEFT, LEFT_X, 2)
    -- your role's name starts on the same line as the "YOUR ROLE" heading (two clean columns: heading
    -- + buttons left, role / you / status right; it floated between them before, user 2026-10-13)
    ui.roleTitle = W.Label(win, "ZoFontWinH2", C.selected, "")
    ui.roleTitle:SetAnchor(TOPLEFT, lastRole, TOPRIGHT, 14, -22)
    ui.charLine = W.Label(win, "ZoFontGame", C.normal, "")
    ui.charLine:SetAnchor(TOPLEFT, ui.roleTitle, BOTTOMLEFT, 0, -2)
    ui.charLine:SetWidth(700)
    ui.statusLine = W.Label(win, "ZoFontGameSmall", C.dim, "")
    ui.statusLine:SetAnchor(TOPLEFT, ui.charLine, BOTTOMLEFT, 0, 0)
    ui.statusLine:SetWidth(700)
    local searchBox, searchEdit = W.Edit(win, 300, L("SEARCH_HINT"))
    searchBox:SetAnchor(TOPRIGHT, win, TOPRIGHT, -38, 34)
    local searchLabel = W.Label(win, "ZoFontGameLargeBold", C.normal, L("SEARCH"))
    searchLabel:SetAnchor(BOTTOMLEFT, searchBox, TOPLEFT, 0, -2)
    searchEdit:SetHandler("OnTextChanged", function()
        Board.query = zo_strlower(zo_strtrim(searchEdit:GetText() or ""))
        Board.Rebuild()
    end, "Groupbound")
    ui.search = searchEdit

    -- the divider (draws out from the middle when the window opens)
    ui.dividerHolder = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    ui.dividerHolder:SetAnchor(TOPLEFT, win, TOPLEFT, LEFT_X, 84)
    ui.dividerHolder:SetAnchor(TOPRIGHT, win, TOPRIGHT, -30, 84)
    ui.dividerHolder:SetHeight(6)
    ui.divider = W.Divider(ui.dividerHolder)
    ui.divider:SetAnchor(TOP, ui.dividerHolder, TOP, 0, 0)
    ui.divider:SetWidth(WIN_W - LEFT_X - 30)

    CreateTree(win)
    CreateList(win)
    CreateApplicants(win)
    CreateAlerts(win)
    CreatePost(win)
end

-- the divider draws out from the middle
local function DrawDivider()
    local full = WIN_W - LEFT_X - 30
    ui.divider:SetWidth(0)
    Anim.Run("Groupbound_Divider", 450, Anim.Out, function(p) ui.divider:SetWidth(math.max(1, full * p)) end)
end

local function OnShowing()
    UI.Create()
    ui.seenBase = G.sv.boardSeen
    if ui.search and Board.query ~= zo_strlower(zo_strtrim(ui.search:GetText() or "")) then
        ui.search:SetText("")
    end
    Finder.SetWatching(true)
    Board.Rebuild()
    local view = G.sv.view
    ui.list:SetHidden(not ListView())
    ui.list:SetAlpha(1)
    ui.alerts:SetHidden(view ~= "alerts")
    ui.alerts:SetAlpha(1)
    ui.apps:SetHidden(view ~= "applicants")
    ui.apps:SetAlpha(1)
    ui.post:SetHidden(view ~= "post")
    ui.post:SetAlpha(1)
    for _, f in ipairs(ui.postFields) do f:SetAlpha(1) end
    UI.PaintTop()
    UI.PaintTree()
    UI.RefreshSide()
    if view == "post" then
        UI.RefreshPost()
    elseif view == "alerts" then
        UI.RefreshAlerts()
    elseif view == "applicants" then
        UI.RefreshApplicants()
    end
    UI.LayoutList("swap")
    DrawDivider()
    keys.static = keys.static or UI.StaticKeys()
    UpdateKeys()
    G.EM:RegisterForUpdate("Groupbound_UIStatus", 1000, function()
        UI.PaintTop()
        TickApplicants()
        -- the apply spinner turns
        if Finder.ApplyPending() and ui.applyingId then
            local row = ui.rowsById[ui.applyingId]
            if row then
                row.wait:SetHidden(false)
                row.wait:SetTextureRotation((GetFrameTimeMilliseconds() / 1000 * 4) % (2 * math.pi))
            end
        end
    end)
end

local function OnHidden()
    -- everything on the board now counts as seen (no "new" mark next time)
    G.sv.boardSeen = Board.Keys(NewKey)
    for _, group in pairs(keys) do
        if KEYBIND_STRIP:HasKeybindButtonGroup(group) then KEYBIND_STRIP:RemoveKeybindButtonGroup(group) end
    end
    Finder.SetWatching(false)
    G.EM:UnregisterForUpdate("Groupbound_UIStatus")
    ClearTooltip(InformationTooltip)
    UI.CloseApplyDialog()
    UI.CloseAchPicker()
    UI.CloseListPicker()
    UI.CloseEntryMenu()
    if noteWin then noteWin:SetHidden(true) end
end

-- ---------------------------------------------------------------------------
-- Keybind groups

function UI.StaticKeys()
    return {
        alignment = KEYBIND_STRIP_ALIGN_CENTER,
        {
            name = L("POST_A_GROUP"),
            keybind = "UI_SHORTCUT_QUATERNARY",
            visible = function() return G.sv.view ~= "post" end,
            callback = function() UI.SetView("post") end,
        },
        {
            name = function()
                if Finder.MyListing() then return L("REMOVE_LISTING") end
                return L("TAKE_BACK")
            end,
            keybind = "UI_SHORTCUT_NEGATIVE",
            visible = function() return Finder.MyListing() ~= nil or Finder.MyApplication() ~= nil end,
            callback = function()
                if Finder.MyListing() then Finder.RemoveListing() else Finder.Rescind() end
            end,
        },
    }
end

local function BoardKeys()
    return {
        alignment = KEYBIND_STRIP_ALIGN_RIGHT,
        {
            name = function() return PrimaryName(Sel()) end,
            keybind = "UI_SHORTCUT_PRIMARY",
            visible = function() return Sel() ~= nil end,
            enabled = function() return not Finder.ApplyPending() end,
            callback = function() UI.Primary(Sel()) end,
        },
        {
            name = L("WHISPER"),
            keybind = "UI_SHORTCUT_SECONDARY",
            visible = function() return Sel() ~= nil end,
            callback = function() UI.WhisperEmpty(Sel()) end,
        },
        {
            name = function()
                local e = Sel()
                return L(e and e.content and G.sv.watches[e.content] and "KEY_ALERT_OFF" or "KEY_ALERT_ON")
            end,
            keybind = "UI_SHORTCUT_TERTIARY",
            visible = function()
                local e = Sel()
                return e ~= nil and e.content ~= nil
            end,
            callback = function()
                local e = Sel()
                if e then UI.ToggleWatch(e.content) end
            end,
        },
    }
end

local function AppKeys()
    local function Can()
        local a = SelApp()
        return a ~= nil and not a.pending
    end
    return {
        alignment = KEYBIND_STRIP_ALIGN_RIGHT,
        {
            name = L("ACCEPT"),
            keybind = "UI_SHORTCUT_PRIMARY",
            visible = function() return SelApp() ~= nil end,
            enabled = Can,
            callback = function() Finder.Resolve(SelApp(), true) end,
        },
        {
            name = L("DECLINE"),
            keybind = "UI_SHORTCUT_SECONDARY",
            visible = function() return SelApp() ~= nil end,
            enabled = Can,
            callback = function() Finder.Resolve(SelApp(), false) end,
        },
        {
            name = L("WHISPER"),
            keybind = "UI_SHORTCUT_TERTIARY",
            visible = function() return SelApp() ~= nil end,
            callback = function()
                local a = SelApp()
                if a then Chat.Whisper(a.account, "") end
            end,
        },
    }
end

local function PostKeys()
    return {
        alignment = KEYBIND_STRIP_ALIGN_RIGHT,
        { name = function() return L(Finder.MyListing() and "POST_UPDATE" or "POST_FINDER") end,
          keybind = "UI_SHORTCUT_PRIMARY", callback = function() UI.PostToFinder() end },
        { name = L("POST_ZONE"), keybind = "UI_SHORTCUT_SECONDARY", callback = function() UI.PostToChat(CHAT_CHANNEL_ZONE) end },
        { name = L("POST_GUILD"), keybind = "UI_SHORTCUT_TERTIARY", callback = function() UI.GuildMenu(ui.post) end },
    }
end

-- ---------------------------------------------------------------------------
-- Public

function UI.Show()
    if scene then SCENE_MANAGER:Show(SCENE_NAME) end
end

function UI.Hide()
    if scene and scene:IsShowing() then SCENE_MANAGER:Hide(SCENE_NAME) end
end

function UI.IsShown()
    return scene ~= nil and scene:IsShowing()
end

function UI.Toggle()
    if scene then SCENE_MANAGER:Toggle(SCENE_NAME) end
end

function UI.ShowPost()
    if not UI.IsShown() then G.sv.view = "post" UI.Show() else UI.SetView("post") end
end

-- opens the board on one group (from the alert / the small board)
function UI.ShowEntry(id)
    local e = Board.Find(id)
    if e then
        local kind = Board.KindOf(e)
        if G.sv.view ~= "all" and G.sv.view ~= kind then G.sv.view = kind end
    end
    ui.selId = id
    if UI.IsShown() then
        UI.PaintTree()
        UI.LayoutList("live")
        RefreshKeys()
    else
        UI.Show()
    end
end

function UI.Refresh()
    if not UI.IsShown() then return end
    UI.PaintTop()
    UI.PaintTree()
    UI.RefreshSide()
    if ListView() then UI.LayoutList("live") end
    if G.sv.view == "post" then UI.RefreshPost() end
    if G.sv.view == "applicants" then UI.RefreshApplicants() end
    RefreshKeys()
end

function UI.Init()
    if not (ZO_Scene and SCENE_MANAGER and ZO_FadeSceneFragment) then return end
    UI.Create()
    fragment = ZO_FadeSceneFragment:New(ui.win)
    scene = ZO_Scene:New(SCENE_NAME, SCENE_MANAGER)
    -- like the game's Friends list scene (keyboardingamescenes.lua)
    if FRAGMENT_GROUP then
        if FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW then scene:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW) end
        if FRAGMENT_GROUP.FRAME_TARGET_STANDARD_RIGHT_PANEL then scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_STANDARD_RIGHT_PANEL) end
    end
    -- (no RIGHT_BG_FRAGMENT: the window draws its own wider background, see UI.Create)
    -- (the game's title fragment sits where its 930 px panel starts: our wider window draws its own
    -- title, see UI.Create)
    if FRAME_EMOTE_FRAGMENT_SOCIAL then scene:AddFragment(FRAME_EMOTE_FRAGMENT_SOCIAL) end
    scene:AddFragment(fragment)
    keys.board = BoardKeys()
    keys.post = PostKeys()
    keys.apps = AppKeys()
    scene:RegisterCallback("StateChange", G.Safe(function(_, newState)
        if newState == SCENE_SHOWING then
            OnShowing()
        elseif newState == SCENE_HIDDEN then
            OnHidden()
        end
    end, "UI"))

    G.callbacks:RegisterCallback("BoardChanged", UI.Refresh)
    G.callbacks:RegisterCallback("FinderState", function()
        if not Finder.ApplyPending() then ui.applyingId = nil end
        Board.Changed()   -- (application taken back / declined / ran out: "Applied" goes away)
        UI.Refresh()
    end)
    G.callbacks:RegisterCallback("RoleChanged", UI.Refresh)
    G.callbacks:RegisterCallback("ApplicantsChanged", UI.Refresh)
    G.EM:RegisterForEvent("Groupbound_UIGroup", EVENT_GROUP_MEMBER_JOINED, function() UI.RefreshSide() end)
    G.EM:RegisterForEvent("Groupbound_UIGroupLeft", EVENT_GROUP_MEMBER_LEFT, function() UI.RefreshSide() end)
end
