--======================================================================
-- Battleboard_Share.lua
--======================================================================
-- Battleground scoreboard sharing via a compact, chat-safe link.
--
--   right-click a
--   history card    -> "Share" does the same for that specific match.
--
-- Anyone with Battleboard installed who clicks the [Battleboard] link gets a
-- standalone pop-up that mirrors the in-addon match details panel
-- (team summary strip + player table), WITHOUT character names.
--
-- DESIGN PRIORITY (per the addon's high-end PvP audience):
--   * K/D/A are stored losslessly.
--   * Damage/healing are stored at DISPLAY precision (nearest 1k under 1m, nearest
--     100k at/above 1m) so FormatBigNumber prints "766k" / "1.2m" as expected.
--   * Medals are not shared (dropped to make room).
--   * The User ID is truncated to NAME_CHARS chars; if it was longer, "..." is
--     appended so the reader can see it was cut. "@Solantris" -> "@Solan...".
--======================================================================

local BL = Battleboard            -- Battleboard is global (declared in Battleboard.lua)
BL.Share = BL.Share or {}
local Share = BL.Share

local LINK_TYPE  = "bgls"          -- our custom chat link type (the "header")
local LINK_TEXT  = "Battleboard"    -- renders as [Battleboard]
local FORMAT_VER = 4               -- bump if the packed layout ever changes
local MAX_PLAYERS = BL.__constants.MAX_SCOREBOARD_PLAYERS
local NAME_CHARS_MIN = 3           -- User ID chars for a full 18-player match
local NAME_CHARS_MAX = 12          -- cap (fits the column and real @names)
local LINK_BIT_BUDGET = 1372       -- 28 chunks -> 224 chars -> 249-char link (clean)
local MAX_LINK_LEN = 350           -- ESO chat input hard limit
local SAFE_RENDER_LEN = 265        -- ESO's chat entry stops rendering links beyond
                                   -- ~this many chars (measured). Stay under it so
                                   -- the [Battleboard] link shows in your own chat.

-- NOTE: we deliberately do NOT capture LibChatMessage into a local here. The
-- global may not be populated at the instant this file is parsed; capturing it
-- early would freeze a nil and silently skip link registration. Instead we read
-- the global directly inside InitShare (runtime), after the library has loaded.

--======================================================================
-- 1. CHAT-SAFE BASE-75 BIT CODEC
--======================================================================
-- 49 bits <-> 8 characters. The alphabet omits vowels (so the payload cannot
-- spell a censored word, which ZOS would mask with '*' and corrupt) and avoids
-- ':' and '|' which would break the link syntax.
local base = "0123456789BCDFGHJKLMNPQRSTVWXYZbcdfghjklmnpqrstvwxyz(){}[]<>.!?+-/;~@&$^_=`"
local BASE_LEN = #base

local function decToBase(num)
    if num == 0 then return base:sub(1, 1) end
    local result = ""
    while num > 0 do
        local r = num % BASE_LEN
        result = base:sub(r + 1, r + 1) .. result
        num = math.floor(num / BASE_LEN)
    end
    return result
end

local function baseToDec(str)
    local num = 0
    for i = 1, #str do
        local v = base:find(str:sub(i, i), 1, true)
        if not v then return nil end       -- corrupted (e.g. censored)
        num = num * BASE_LEN + (v - 1)
    end
    return num
end

local function numberToBinary(num, width)
    local b = ""
    for _ = 1, width do
        b = ((num % 2 == 1) and "1" or "0") .. b
        num = math.floor(num / 2)
    end
    return b
end

local function binaryToNumber(str)
    local num = 0
    for i = 1, #str do
        num = num * 2 + (str:sub(i, i) == "1" and 1 or 0)
    end
    return num
end

local function bufWrite(buf, value, width)
    value = math.floor(tonumber(value) or 0)
    local maxv = 2 ^ width - 1
    if value < 0 then value = 0 elseif value > maxv then value = maxv end
    for i = width - 1, 0, -1 do
        buf.bits = buf.bits .. ((math.floor(value / 2 ^ i) % 2 == 1) and "1" or "0")
    end
end

local function bufRead(buf, width)
    local value = 0
    for i = 1, width do
        local c = buf.bits:sub(buf.pos + i - 1, buf.pos + i - 1)
        value = value * 2 + (c == "1" and 1 or 0)
    end
    buf.pos = buf.pos + width
    return value
end

local CHUNK = 49
local function bufEncode(buf)
    local bits = buf.bits
    local rem = #bits % CHUNK
    if rem ~= 0 then bits = bits .. string.rep("0", CHUNK - rem) end
    local out = ""
    for i = 1, #bits, CHUNK do
        local s = decToBase(binaryToNumber(bits:sub(i, i + CHUNK - 1)))
        while #s < 8 do s = base:sub(1, 1) .. s end
        out = out .. s
    end
    return out
end

local function bufDecode(str)
    local bits = ""
    for i = 1, #str, 8 do
        local num = baseToDec(str:sub(i, i + 7))
        if not num then return nil end
        bits = bits .. numberToBinary(num, CHUNK)
    end
    return { bits = bits, pos = 1 }
end

--======================================================================
-- 2. NAME CODEC (lossy) and GAME-TYPE DICTIONARY
--======================================================================
-- Name = 1 truncation flag bit + NAME_CHARS chars * 6 bits each.
-- Name = 1 truncation flag bit + nc chars * 6 bits each (nc varies by match size;
-- see computeNameChars). 6 bits per char: index 0 = blank/terminator; 1..63 map
-- to NAME_ALPHA. The flag records whether the original was longer than nc, so the
-- reader can append "..." to show the ID was cut.
local NAME_ALPHA = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
local function writeName(buf, displayName, nc)
    local s = tostring(displayName or "")
    s = s:gsub("^@", "")                 -- @ is added back by the reader, not stored
    bufWrite(buf, (#s > nc) and 1 or 0, 1)   -- truncation flag
    for i = 1, nc do
        local ch = s:sub(i, i)
        local idx = (ch ~= "" and NAME_ALPHA:find(ch, 1, true)) or 0
        bufWrite(buf, idx, 6)
    end
end
local function readName(buf, nc)
    local trunc = bufRead(buf, 1)
    local s = ""
    for _ = 1, nc do
        local idx = bufRead(buf, 6)
        if idx >= 1 and idx <= #NAME_ALPHA then s = s .. NAME_ALPHA:sub(idx, idx) end
    end
    if s == "" then return "" end
    return "@" .. s .. (trunc == 1 and "..." or "")
end

-- Compact game-type names -> 3-bit dictionary index (0 = unknown/fallback).
local GAME_TYPES = {
    "Battleground",        -- 0  (unknown / fallback)
    "Deathmatch",          -- 1
    "Domination",          -- 2
    "Chaosball",           -- 3
    "Capture the Relic",   -- 4
    "Crazy King",          -- 5
}
local GAME_TYPE_INDEX = {}
for i, name in ipairs(GAME_TYPES) do GAME_TYPE_INDEX[string.lower(name)] = i - 1 end
local function gameTypeToCode(s)  return GAME_TYPE_INDEX[string.lower(tostring(s or ""))] or 0 end
local function codeToGameType(c)  return GAME_TYPES[(c or 0) + 1] or "Battleground" end

--======================================================================
-- 3. FIELD WIDTHS
--======================================================================
-- SIZE NOTE: ESO's chat ENTRY box renders custom links cleanly only up to ~255
-- chars; right at the edge (~265) it mangles, past it (~280+) it shows raw. Link
-- length is quantized in 8-char steps (241 -> 249 -> 257 ...). Removing the Medal
-- field (-14 bits/player) and trimming damage/healing to 11 bits each freed enough
  -- room to grow the User ID while keeping a full scoreboard link under ESO's
  -- reliable rendering limit (with a truncation "..." flag).
--
-- Damage/Healing are stored at DISPLAY precision in a single 11-bit code:
--   code <= 1000        -> value < 1m, stored to the nearest 1,000   (e.g. 766k)
--   code  > 1000        -> value >= 1m, stored to the nearest 100,000 (e.g. 1.2m)
-- Decoded back to a representative number, then shown via FormatBigNumber. Lossy
-- vs the raw figure, but the printed string matches the requested rounding.
local TS_EPOCH = 1704067200   -- 2024-01-01
local DAY = 86400
local W = {
    VER       = 6,
    GAMETYPE  = 3,    -- dictionary index (0..7); already packed, not a string
    WINNER    = 2,    -- 0 = draw/none, else winning alliance (1..3)
    TEAM_MASK = 3,    -- which of alliances 1..3 are present
    TEAM_SCORE= 10,   -- stored match score per present team (<=1023; win at ~500)
    CAPTURED  = 14,   -- DAYS since TS_EPOCH (date only; ~44 years of range)
    LOCALIDX  = 5,    -- 1-based index of local player (0 = none)
    COUNT     = 5,    -- player count (0..18)
    CLASS     = 3,
    ALLY      = 2,
    KILLS     = 7,    -- <= 127
    DEATHS    = 7,
    ASSISTS   = 7,
    BIG       = 11,   -- damage / healing, display-precision (see writeBig below)
    -- (NAME is 1 truncation bit + NAME_CHARS * 6 bits)
}

local function packClass(classId)
    if tonumber(classId) == 117 then return 7 end
    return tonumber(classId) or 0
end
local function unpackClass(stored)
    if stored == 7 then return 117 end
    return stored
end

-- Damage/Healing in a single 11-bit code. Below 1m: nearest 1,000 (so 765,875 ->
-- 766k). At/above 1m: nearest 100,000 (so 1,240,202 -> 1.2m). Decodes to a
-- representative number that FormatBigNumber then prints in the expected form.
local function writeBig(buf, value)
    value = math.floor(tonumber(value) or 0)
    local code
    if value < 1000000 then
        code = math.floor(value / 1000 + 0.5)                      -- nearest 1k -> 0..1000
    else
        code = 1000 + math.floor((value - 1000000) / 100000 + 0.5) -- nearest 100k
    end
    if code > 2047 then code = 2047 end                            -- 11-bit cap (~105m)
    bufWrite(buf, code, W.BIG)
end
local function readBig(buf)
    local code = bufRead(buf, W.BIG)
    if code <= 1000 then return code * 1000 end
    return 1000000 + (code - 1000) * 100000
end

-- More room in smaller matches -> longer User IDs. An 18-player match uses three
-- characters per User ID; 16-player and smaller matches have spare bits,
-- so each name gets more characters. Encoder and decoder compute this identically
-- from the player count and the number of teams present (both known before names
-- are read), so no extra bits are needed to communicate the length.
local function computeNameChars(playerCount, presentTeams)
    if playerCount <= 0 then return NAME_CHARS_MIN end
    local headerBits = W.VER + W.GAMETYPE + W.WINNER + W.CAPTURED + W.TEAM_MASK
                     + presentTeams * W.TEAM_SCORE + W.LOCALIDX + W.COUNT
    local perPlayerFixed = W.CLASS + W.ALLY + W.KILLS + W.DEATHS + W.ASSISTS + W.BIG * 2 + 1
    local avail = LINK_BIT_BUDGET - headerBits - playerCount * perPlayerFixed
    local nc = math.floor(avail / (playerCount * 6))
    if nc < NAME_CHARS_MIN then nc = NAME_CHARS_MIN end
    if nc > NAME_CHARS_MAX then nc = NAME_CHARS_MAX end
    return nc
end

--======================================================================
-- 4. ENCODE / DECODE A MATCH
--======================================================================
function Share.Encode(match)
    local buf = { bits = "", pos = 1 }
    local players = match.players or {}
    local n = math.min(#players, MAX_PLAYERS)

    bufWrite(buf, FORMAT_VER, W.VER)
    bufWrite(buf, gameTypeToCode(match.gameType), W.GAMETYPE)
    bufWrite(buf, tonumber(match.winner) or 0, W.WINNER)
    local cap = tonumber(match.capturedAt) or 0
    bufWrite(buf, (cap > TS_EPOCH) and math.floor((cap - TS_EPOCH) / DAY) or 0, W.CAPTURED)

    -- Per-team stored match score (the only team value not derivable from players).
    -- Alliance is implied by position: a present-mask flags which of 1..3 exist,
    -- then their scores follow in alliance order.
    local scores = match.scores or {}
    local mask = 0
    local presentTeams = 0
    for ally = 1, 3 do
        if scores[ally] ~= nil then mask = mask + 2 ^ (ally - 1); presentTeams = presentTeams + 1 end
    end
    bufWrite(buf, mask, W.TEAM_MASK)
    for ally = 1, 3 do
        if scores[ally] ~= nil then bufWrite(buf, scores[ally], W.TEAM_SCORE) end
    end

    -- Local player index (so the recipient can highlight who shared it)
    local localIdx = 0
    for i = 1, n do if players[i].isLocalPlayer then localIdx = i break end end
    bufWrite(buf, localIdx, W.LOCALIDX)

    -- Players
    bufWrite(buf, n, W.COUNT)
    local nc = computeNameChars(n, presentTeams)
    for i = 1, n do
        local p = players[i]
        bufWrite(buf, packClass(p.classId), W.CLASS)
        bufWrite(buf, tonumber(p.alliance) or 0, W.ALLY)
        bufWrite(buf, p.kills,   W.KILLS)
        bufWrite(buf, p.deaths,  W.DEATHS)
        bufWrite(buf, p.assists, W.ASSISTS)
        writeBig(buf, p.damage)
        writeBig(buf, p.healing)
        writeName(buf, p.displayName, nc)
    end

    return bufEncode(buf)
end

function Share.Decode(dataString)
    local buf = bufDecode(dataString)
    if not buf then return nil end

    local ok, match = pcall(function()
        local ver = bufRead(buf, W.VER)
        if ver ~= FORMAT_VER then return nil end

        local m = {}
        m.gameType   = codeToGameType(bufRead(buf, W.GAMETYPE))
        m.winner     = bufRead(buf, W.WINNER)
        local capDays = bufRead(buf, W.CAPTURED)
        m.capturedAt = (capDays > 0) and (capDays * DAY + TS_EPOCH) or 0

        local mask = bufRead(buf, W.TEAM_MASK)
        m.scores = {}
        local presentTeams = 0
        for ally = 1, 3 do
            if math.floor(mask / 2 ^ (ally - 1)) % 2 == 1 then
                m.scores[ally] = bufRead(buf, W.TEAM_SCORE)
                presentTeams = presentTeams + 1
            end
        end

        local localIdx = bufRead(buf, W.LOCALIDX)
        local n = bufRead(buf, W.COUNT)
        if n > MAX_PLAYERS then n = MAX_PLAYERS end
        local nc = computeNameChars(n, presentTeams)

        m.players = {}
        for i = 1, n do
            m.players[i] = {
                classId  = unpackClass(bufRead(buf, W.CLASS)),
                alliance = bufRead(buf, W.ALLY),
                kills    = bufRead(buf, W.KILLS),
                deaths   = bufRead(buf, W.DEATHS),
                assists  = bufRead(buf, W.ASSISTS),
                damage   = readBig(buf),
                healing  = readBig(buf),
                displayName  = readName(buf, nc),
                isLocalPlayer = (i == localIdx),
            }
        end
        return m
    end)

    if not ok then return nil end
    return match
end

function Share.BuildLink(match)
    return ZO_LinkHandler_CreateLink(LINK_TEXT, nil, LINK_TYPE, Share.Encode(match))
end

--======================================================================
-- 5. THEME (kept local so this file stays standalone)
--======================================================================
local classIcons = {
    [1] = "esoui/art/icons/class/gamepad/gp_class_dragonknight.dds",
    [2] = "esoui/art/icons/class/gamepad/gp_class_sorcerer.dds",
    [3] = "esoui/art/icons/class/gamepad/gp_class_nightblade.dds",
    [4] = "esoui/art/icons/class/gamepad/gp_class_warden.dds",
    [5] = "esoui/art/icons/class/gamepad/gp_class_necromancer.dds",
    [6] = "esoui/art/icons/class/gamepad/gp_class_templar.dds",
    [117] = "esoui/art/icons/class/gamepad/gp_class_arcanist.dds",
}
local BLANK_ICON = "/esoui/art/icons/icon_missing.dds"
local teamIcons = {
    [1] = "/esoui/art/battlegrounds/battlegrounds_teamicon_orange_64.dds", -- Fire Drakes
    [2] = "/esoui/art/battlegrounds/battlegrounds_teamicon_green_64.dds",  -- Pit Daemons
    [3] = "/esoui/art/battlegrounds/battlegrounds_teamicon_purple_64.dds", -- Storm Lords
}
local allianceNames  = { [1] = "Fire Drakes", [2] = "Pit Daemons", [3] = "Storm Lords" }
local allianceColours = {
    [1] = { 0.85, 0.40, 0.00 },
    [2] = { 0.36, 0.60, 0.00 },
    [3] = { 0.50, 0.30, 0.60 },
}
local DMG_ICON  = "/esoui/art/addons/gamepad/gp_mod_listing_category_combat.dds"
local HEAL_ICON = "/esoui/art/lfg/gamepad/lfg_roleicon_healer_down.dds"

local function FormatBigNumber(value)
    value = tonumber(value) or 0
    if value >= 1000000 then return string.format("%.1fm", value / 1000000)
    elseif value >= 1000 then return string.format("%dk", math.floor(value / 1000)) end
    return tostring(value)
end

local function FormatTimestamp(ts)
    ts = tonumber(ts) or 0
    if ts > 0 then
        local d = GetDateStringFromTimestamp(ts)
        if d and d ~= "" then return d end
    end
    return ""
end

--======================================================================
-- 6. THE STANDALONE POP-UP  (mirrors the in-addon details panel)
--======================================================================
-- Columns mirror the main panel's player table, minus the Character column.
-- `sort` is the key clicked-to-sort uses; "reset" returns to the default order.
local COLS = {
    { key = "team",    text = "", w = 26, kind = "teamicon",  sort = "reset",
      headerIcon = "/esoui/art/treeicons/achievements_indexicon_general_up.dds" },
    { key = "class",   text = "", w = 26, kind = "classicon", sort = "class" },
    { key = "name",    text = "User ID", w = 150, align = TEXT_ALIGN_LEFT,   sort = "name" },
    { key = "kills",   text = "K", w = 40, align = TEXT_ALIGN_CENTER, sort = "kills" },
    { key = "deaths",  text = "D", w = 40, align = TEXT_ALIGN_CENTER, sort = "deaths" },
    { key = "assists", text = "A", w = 40, align = TEXT_ALIGN_CENTER, sort = "assists" },
    { key = "damage",  text = "", w = 56, align = TEXT_ALIGN_CENTER, icon = DMG_ICON,  sort = "damage" },
    { key = "healing", text = "", w = 56, align = TEXT_ALIGN_CENTER, icon = HEAL_ICON, sort = "healing" },
}

-- Everything in the pop-up is scaled from this one factor. 1.2 keeps it a touch
-- larger than the game default while fitting on screen (2.0 ran off the bottom).
local SCALE = 1.2
local function s(v) return math.floor(v * SCALE) end

-- Fonts: use the SAME named ESO fonts as the page-1 player table so the shared
-- board matches it exactly (ZoFontWinH5 body / ZoFontWinH4 header). Headline rows
-- use larger members of the same Win family.
local CELL_FONT    = "ZoFontWinH5"     -- == DETAIL_TABLE_BODY_FONT
local HEADER_FONT  = "ZoFontWinH4"
local TITLE_FONT   = "ZoFontWinH1"
local META_FONT    = "ZoFontWinH5"
local OUTCOME_FONT = "ZoFontWinH2"
local TSCORE_FONT  = "ZoFontWinH2"
local TSTATS_FONT  = "ZoFontWinH5"

local COL_GAP   = s(6)
local PAD       = s(18)
local ROW_H     = s(24)
local HEADER_H  = s(30)
local EXTRA_H   = 0             -- extra window height beyond the table
local SORT_UP   = "/esoui/art/miscellaneous/list_sortheader_icon_up.dds"
local SORT_DOWN = "/esoui/art/miscellaneous/list_sortheader_icon_down.dds"

local function tableWidth()
    local w = 0
    for i, c in ipairs(COLS) do
        w = w + s(c.w)
        if i < #COLS then w = w + COL_GAP end
    end
    return w
end
local function colX(index)
    local x = 0
    for i = 1, index - 1 do x = x + s(COLS[i].w) + COL_GAP end
    return x
end
local function colW(i) return s(COLS[i].w) end

local popup, popupRows
local currentMatch, currentSort
local RenderRows                 -- forward declaration
local function wm() return WINDOW_MANAGER end

local function NewLabel(parent, font, color)
    local l = wm():CreateControl(nil, parent, CT_LABEL)
    l:SetFont(font)
    if color then l:SetColor(unpack(color)) end
    l:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return l
end

-- Click-to-sort, mirroring the main details panel: team column resets to the
-- default order; clicking the active column toggles direction; text sorts A-Z
-- first, numbers high-first.
local function DoSort(colSort)
    if colSort == "reset" then
        currentSort = nil
    elseif currentSort and currentSort.key == colSort then
        currentSort.ascending = not currentSort.ascending
    else
        currentSort = { key = colSort, ascending = (colSort == "name") }
    end
    RenderRows()
end

local function CreatePopup()
    local TW = tableWidth()
    local width = TW + PAD * 2
    local TABLE_Y = s(160)
    local tableH = s(24) + ROW_H * MAX_PLAYERS + s(8)
    local height = TABLE_Y + tableH + PAD + EXTRA_H

    local tlw = wm():CreateTopLevelWindow("BattleboardSharePopup")
    tlw:SetDimensions(width, height)
    -- Offset left of screen centre so the popup doesn't sit on top of the Battleboard
    -- menu when a link is clicked with it open. The window is movable + clamped,
    -- so this is just a sensible default the player can drag from.
    local POPUP_X_OFFSET = -(math.floor(width / 2) + 40)
    tlw:SetAnchor(CENTER, GuiRoot, CENTER, POPUP_X_OFFSET, 0)
    tlw:SetMovable(true)
    tlw:SetMouseEnabled(true)
    tlw:SetClampedToScreen(true)
    tlw:SetHidden(true)
    tlw:SetDrawLayer(DL_OVERLAY)

    local bg = wm():CreateControl("$(parent)Bg", tlw, CT_BACKDROP)
    bg:SetAnchorFill(tlw)
    bg:SetCenterColor(0.05, 0.045, 0.04, 0.80)
    bg:SetEdgeColor(0.549, 0.541, 0.451, 1)
    bg:SetEdgeTexture("", 1, 1, 1)
    bg:SetInsets(0, 0, 0, 0)
    bg:SetMouseEnabled(true)
    bg:SetHandler("OnMouseDown", function() tlw:StartMoving() end)
    bg:SetHandler("OnMouseUp",   function() tlw:StopMovingOrResizing() end)

    local title = NewLabel(tlw, TITLE_FONT, { 1, 0.82, 0.28, 1 })
    title:SetAnchor(TOP, tlw, TOP, 0, s(12))
    title:SetText("Scoreboard")
    tlw.title = title

    local meta = NewLabel(tlw, META_FONT, { 0.80, 0.76, 0.66, 1 })
    meta:SetAnchor(TOP, title, BOTTOM, 0, s(2))
    tlw.meta = meta

    -- Outcome strip: VICTORY/DEFEAT/DRAW on a transparent black panel,
    -- framed by gold-grey divider lines above and below.
    local outcomeBg = wm():CreateControl("$(parent)OutcomeBg", tlw, CT_BACKDROP)
    outcomeBg:SetCenterColor(0, 0, 0, 0.45)
    outcomeBg:SetEdgeColor(0, 0, 0, 0)
    outcomeBg:SetAnchor(TOP, meta, BOTTOM, 0, s(5))
    outcomeBg:SetDimensions(s(230), s(32))
    tlw.outcomeBg = outcomeBg

    local divTop = wm():CreateControl("$(parent)OutcomeDivTop", tlw, CT_BACKDROP)
    divTop:SetCenterColor(0.62, 0.58, 0.40, 0.95)
    divTop:SetEdgeColor(0, 0, 0, 0)
    divTop:SetDimensions(s(250), 2)
    divTop:SetAnchor(BOTTOM, outcomeBg, TOP, 0, -1)

    local divBot = wm():CreateControl("$(parent)OutcomeDivBot", tlw, CT_BACKDROP)
    divBot:SetCenterColor(0.62, 0.58, 0.40, 0.95)
    divBot:SetEdgeColor(0, 0, 0, 0)
    divBot:SetDimensions(s(250), 2)
    divBot:SetAnchor(TOP, outcomeBg, BOTTOM, 0, 1)

    local outcome = NewLabel(tlw, OUTCOME_FONT, { 1, 1, 1, 1 })
    outcome:SetAnchor(CENTER, outcomeBg, CENTER, 0, 0)
    outcome:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    tlw.outcome = outcome

    local close = wm():CreateControlFromVirtual("$(parent)Close", tlw, "ZO_CloseButton")
    close:SetAnchor(TOPRIGHT, tlw, TOPRIGHT, -s(8), s(8))
    close:SetHandler("OnClicked", function() tlw:SetHidden(true) end)

    -- Team summary strip
    local strip = wm():CreateControl("$(parent)TeamStrip", tlw, CT_CONTROL)
    strip:SetAnchor(TOPLEFT, tlw, TOPLEFT, PAD, s(105))
    strip:SetDimensions(TW, s(48))
    tlw.strip = strip

    -- Player table host
    local table_ = wm():CreateControl("$(parent)Table", tlw, CT_CONTROL)
    table_:SetAnchor(TOPLEFT, tlw, TOPLEFT, PAD, TABLE_Y)
    table_:SetDimensions(TW, tableH)
    tlw.table = table_

    -- Header background + underline
    local hbg = wm():CreateControl("$(parent)HeaderBg", table_, CT_BACKDROP)
    hbg:SetDimensions(TW, HEADER_H)
    hbg:SetAnchor(TOPLEFT, table_, TOPLEFT, 0, 0)
    hbg:SetCenterColor(0.010, 0.009, 0.007, 0.86)
    hbg:SetEdgeColor(0, 0, 0, 0)

    local underline = wm():CreateControl("$(parent)HeaderLine", table_, CT_BACKDROP)
    underline:SetDimensions(TW, s(2))
    underline:SetAnchor(TOPLEFT, table_, TOPLEFT, 0, HEADER_H - s(2))
    underline:SetCenterColor(0.549, 0.541, 0.451, 1)
    underline:SetEdgeColor(0, 0, 0, 0)

    -- Clickable, sortable column headers (icon or text)
    tlw.headers = {}
    local iconSz = s(26)
    for i, col in ipairs(COLS) do
        local x, cw = colX(i), colW(i)
        local hit = wm():CreateControl(nil, table_, CT_CONTROL)
        hit:SetDimensions(cw, HEADER_H)
        hit:SetAnchor(TOPLEFT, table_, TOPLEFT, x, 0)
        hit:SetMouseEnabled(true)
        if col.sort then
            hit:SetHandler("OnMouseUp", function(_, button, upInside)
                if upInside and button == MOUSE_BUTTON_INDEX_LEFT then DoSort(col.sort) end
            end)
        end

        local label
        if col.icon or col.headerIcon then
            local tex = wm():CreateControl(nil, table_, CT_TEXTURE)
            tex:SetTexture(col.icon or col.headerIcon)
            tex:SetDimensions(iconSz, iconSz)
            tex:SetAnchor(LEFT, table_, TOPLEFT, x + math.floor((cw - iconSz) / 2), HEADER_H / 2)
            tex:SetMouseEnabled(false)
        elseif col.text ~= "" then
            label = NewLabel(table_, HEADER_FONT, { 0.80, 0.76, 0.66, 1 })
            label:SetDimensions(cw, HEADER_H)
            label:SetAnchor(TOPLEFT, table_, TOPLEFT, x, 0)
            if col.align then label:SetHorizontalAlignment(col.align) end
            label:SetText(col.text)
            label:SetMouseEnabled(false)
        end
        tlw.headers[i] = { col = col, label = label, x = x, w = cw }
    end

    -- single shared sort arrow, repositioned by RenderRows
    local arrow = wm():CreateControl(nil, table_, CT_TEXTURE)
    arrow:SetDimensions(s(12), s(12))
    arrow:SetMouseEnabled(false)
    arrow:SetHidden(true)
    tlw.sortArrow = arrow

    -- row slots
    popupRows = {}
    local glyph = s(20)
    for i = 1, MAX_PLAYERS do
        local rowY = HEADER_H + (i - 1) * ROW_H + s(4)
        local row = {}

        row.bg = wm():CreateControl(nil, table_, CT_BACKDROP)
        row.bg:SetDimensions(TW, ROW_H - s(2))
        row.bg:SetAnchor(TOPLEFT, table_, TOPLEFT, 0, rowY)
        row.bg:SetEdgeColor(0, 0, 0, 0)
        row.bg:SetHidden(true)

        row.team = wm():CreateControl(nil, table_, CT_TEXTURE)
        row.team:SetDimensions(glyph, glyph)
        row.team:SetAnchor(TOPLEFT, table_, TOPLEFT, colX(1) + math.floor((colW(1) - glyph) / 2), rowY + math.floor((ROW_H - glyph) / 2))

        row.class = wm():CreateControl(nil, table_, CT_TEXTURE)
        row.class:SetDimensions(glyph, glyph)
        row.class:SetAnchor(TOPLEFT, table_, TOPLEFT, colX(2) + math.floor((colW(2) - glyph) / 2), rowY + math.floor((ROW_H - glyph) / 2))

        row.cells = {}
        for ci, col in ipairs(COLS) do
            if col.kind ~= "teamicon" and col.kind ~= "classicon" then
                local cell = NewLabel(table_, CELL_FONT, { 0.88, 0.86, 0.78, 0.96 })
                cell:SetDimensions(colW(ci), ROW_H - s(2))
                cell:SetAnchor(TOPLEFT, table_, TOPLEFT, colX(ci), rowY)
                if col.align then cell:SetHorizontalAlignment(col.align) end
                row.cells[col.key] = cell
            end
        end
        popupRows[i] = row
    end

    tlw.teamBlocks = {}
    popup = tlw
    return tlw
end

local function SumTeams(players)
    local t = {}
    for _, p in ipairs(players) do
        local a = tonumber(p.alliance) or 0
        if a > 0 then
            t[a] = t[a] or { kills = 0, deaths = 0 }
            t[a].kills  = t[a].kills  + (tonumber(p.kills)  or 0)
            t[a].deaths = t[a].deaths + (tonumber(p.deaths) or 0)
        end
    end
    return t
end

local function BuildTeamStrip(tlw, match)
    -- clear previous
    for _, b in pairs(tlw.teamBlocks) do b:SetHidden(true) end

    local totals = SumTeams(match.players or {})
    -- Fixed left-to-right slot order: Fire Drakes (red) | Storm Lords (purple) | Pit Daemons (green)
    local DISPLAY_ORDER = { 1, 3, 2 }
    local present = {}
    for _, ally in ipairs(DISPLAY_ORDER) do
        if totals[ally] or (match.scores and match.scores[ally]) then present[#present + 1] = ally end
    end
    local blockW = math.floor(tableWidth() / math.max(#present, 1))

    for i, ally in ipairs(present) do
        local key = "block" .. ally
        local b = tlw.teamBlocks[key]
        if not b then
            b = wm():CreateControl(nil, tlw.strip, CT_CONTROL)
            b.icon  = wm():CreateControl(nil, b, CT_TEXTURE)
            b.icon:SetDimensions(s(28), s(28))
            b.icon:SetAnchor(LEFT, b, LEFT, s(4), 0)
            b.score = NewLabel(b, TSCORE_FONT, { 1, 1, 1, 1 })
            b.score:SetAnchor(LEFT, b.icon, RIGHT, s(6), 0)
            b.stats = NewLabel(b, TSTATS_FONT, { 0.82, 0.80, 0.72, 1 })
            b.stats:SetAnchor(RIGHT, b, RIGHT, -s(8), 0)   -- right edge -> block spans full width
            b.stats:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
            tlw.teamBlocks[key] = b
        end
        b:ClearAnchors()
        b:SetAnchor(TOPLEFT, tlw.strip, TOPLEFT, (i - 1) * blockW, 0)
        b:SetDimensions(blockW, s(48))
        b.icon:SetTexture(teamIcons[ally] or BLANK_ICON)
        b.score:SetText(tostring((match.scores and match.scores[ally]) or "--"))
        local tt = totals[ally] or { kills = 0, deaths = 0 }
        b.stats:SetText(string.format("K %d   D %d", tt.kills, tt.deaths))
        local col = allianceColours[ally] or { 1, 1, 1 }
        b.score:SetColor(col[1] + 0.25, col[2] + 0.25, col[3] + 0.25, 1)
        b:SetHidden(false)
    end
end

-- Sort the player list. sort==nil -> default order: grouped by team (alliance
-- ascending), highest damage first within a team. Otherwise sort by the clicked
-- key; text ascending, numbers per sort.ascending.
local function SortPlayersBy(players, sort)
    local copy = {}
    for i, p in ipairs(players) do copy[i] = p end
    local key = sort and sort.key
    if not key then
        table.sort(copy, function(a, b)
            local aa, ba = tonumber(a.alliance) or 0, tonumber(b.alliance) or 0
            if aa ~= ba then return aa < ba end
            return (tonumber(a.damage) or 0) > (tonumber(b.damage) or 0)
        end)
        return copy
    end
    local asc = sort.ascending
    table.sort(copy, function(a, b)
        local av, bv
        if key == "name" then
            av = string.lower(tostring(a.displayName or "")); bv = string.lower(tostring(b.displayName or ""))
        elseif key == "class" then
            av = tonumber(a.classId) or 0; bv = tonumber(b.classId) or 0
        else
            av = tonumber(a[key]) or 0; bv = tonumber(b[key]) or 0
        end
        if av == bv then return tostring(a.displayName or "") < tostring(b.displayName or "") end
        if asc then return av < bv else return av > bv end
    end)
    return copy
end

-- (forward-declared above) populate rows from currentMatch + currentSort
RenderRows = function()
    if not (popup and currentMatch and popupRows) then return end
    local sorted = SortPlayersBy(currentMatch.players, currentSort)
    for i = 1, MAX_PLAYERS do
        local row = popupRows[i]
        local p = sorted[i]
        if p then
            local tc = allianceColours[tonumber(p.alliance)] or { 0.2, 0.2, 0.2 }
            row.bg:SetCenterColor(tc[1], tc[2], tc[3], 0.14)
            row.bg:SetHidden(false)

            row.team:SetTexture(teamIcons[p.alliance] or BLANK_ICON)
            row.team:SetHidden(false)
            row.class:SetTexture(classIcons[p.classId] or BLANK_ICON)
            row.class:SetHidden(false)

            local cellColor = p.isLocalPlayer and { 1, 0.82, 0.28, 1 } or { 0.88, 0.86, 0.78, 0.96 }
            local vals = {
                name    = p.displayName or "",
                kills   = tostring(p.kills or 0),
                deaths  = tostring(p.deaths or 0),
                assists = tostring(p.assists or 0),
                damage  = FormatBigNumber(p.damage),
                healing = FormatBigNumber(p.healing),
            }
            for key, cell in pairs(row.cells) do
                cell:SetText(vals[key] or "")
                cell:SetColor(unpack(cellColor))
                cell:SetHidden(false)
            end
        else
            row.bg:SetHidden(true)
            row.team:SetHidden(true)
            row.class:SetHidden(true)
            for _, cell in pairs(row.cells) do cell:SetHidden(true) end
        end
    end

    for _, h in ipairs(popup.headers) do
        if h.label then h.label:SetColor(0.80, 0.76, 0.66, 1) end
    end
    local arrow = popup.sortArrow
    if currentSort and currentSort.key then
        for _, h in ipairs(popup.headers) do
            if h.col.sort == currentSort.key then
                if h.label then h.label:SetColor(1, 0.82, 0.28, 1) end
                arrow:SetTexture(currentSort.ascending and SORT_UP or SORT_DOWN)
                arrow:ClearAnchors()
                arrow:SetAnchor(LEFT, popup.table, TOPLEFT, h.x + h.w - s(12), HEADER_H / 2)
                arrow:SetHidden(false)
                return
            end
        end
    end
    arrow:SetHidden(true)
end

function Share.ShowMatch(match)
    if not match or not match.players then
        d("|cFFD700[Battleboard]|r Couldn't read that scoreboard (link may be from a newer version).")
        return
    end
    local tlw = popup or CreatePopup()
    currentMatch = match
    currentSort  = nil

    local parts = {}
    if match.gameType then parts[#parts + 1] = tostring(match.gameType) end
    local ts = FormatTimestamp(match.capturedAt)
    if ts ~= "" then parts[#parts + 1] = ts end
    local divider = string.char(226, 128, 162)
    tlw.meta:SetText(table.concat(parts, "  " .. divider .. "  "))

    local localPlayer
    for _, p in ipairs(match.players) do if p.isLocalPlayer then localPlayer = p break end end
    if localPlayer and match.winner and match.winner > 0 then
        local won = (tonumber(localPlayer.alliance) == tonumber(match.winner))
        tlw.outcome:SetText(won and "|c33CC33VICTORY|r" or "|cCC3333DEFEAT|r")
    elseif match.winner and match.winner > 0 then
        local wname = allianceNames[match.winner]
        tlw.outcome:SetText(wname and (string.upper(wname) .. " WIN") or "VICTORY")
    else
        tlw.outcome:SetText("|cD0C070DRAW|r")
    end

    BuildTeamStrip(tlw, match)
    RenderRows()

    tlw:SetHidden(false)
    tlw:BringWindowToTop()
end

function Share.ShowFromData(dataString)
    Share.ShowMatch(Share.Decode(dataString))
end

function Share.IsPopupOpen()
    return popup ~= nil and not popup:IsHidden()
end
function Share.HidePopup()
    if popup then popup:SetHidden(true) end
end

--======================================================================
-- 7. SENDING  (slash command + right-click) and RECEIVING (chat link)
--======================================================================
function BL.ShareMatch(match)
    if not match or not match.players then
        d("|cFFD700[Battleboard]|r Nothing to share.")
        return
    end
    local link = Share.BuildLink(match)
    if #link > SAFE_RENDER_LEN then
        d(string.format("|cFFD700[Battleboard]|r Note: link is %d chars (>%d). It may show raw in your own chat but still works for recipients.", #link, SAFE_RENDER_LEN))
    end
    -- A bare InsertLink and nothing else; extra formatting breaks click handling.
    CHAT_SYSTEM.textEntry:InsertLink(link)
end

function BL.ShareSelectedMatch()
    local id = BL.selectedMatchId
    local match = id and BL.GetMatch(id)
    if not match then
        d("|cFFD700[Battleboard]|r Select a match first, then right-click a card and Share.")
        return
    end
    BL.ShareMatch(match)
end

local function OnLinkClicked(rawLink, button, linkText, linkStyle, linkType, dataString)
    if linkType ~= LINK_TYPE then return end
    if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
    Share.ShowFromData(dataString)
    return true
end

-- Register click handlers at FILE-LOAD time (top level): LINK_HANDLER callbacks
-- must be registered at file scope, not inside a function, to fire reliably.
-- This guarantees clicks work even if BL.InitShare never runs.
LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_CLICKED_EVENT, OnLinkClicked)
LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_MOUSE_UP_EVENT, OnLinkClicked)

function BL.InitShare()
    Share._initRan = true
    -- Render registration: makes ESO collapse our |H...|h markup to a clickable
    -- [Battleboard] link. Read the global at runtime with a LibStub fallback, and
    -- pcall it so a library-version mismatch surfaces instead of aborting silently.
    local lib = LibChatMessage or (LibStub and LibStub:GetLibrary("LibChatMessage", true))
    Share._libFound = (lib ~= nil)
    if lib and lib.RegisterCustomChatLink then
        local ok, err = pcall(function()
            lib:RegisterCustomChatLink(LINK_TYPE, function(linkStyle, linkType, data, displayText)
                return ZO_LinkHandler_CreateLinkWithoutBrackets(displayText, nil, LINK_TYPE, data)
            end)
        end)
        Share._registered = ok
        Share._regError = err
    else
        Share._registered = false
        Share._regError = "no RegisterCustomChatLink on lib"
    end

    -- Close the scoreboard pop-up when Escape is pressed. Over the HUD, Escape
    -- opens the in-game menu scene; if our pop-up is showing, swallow that and
    -- hide the pop-up instead.
    if not Share._escapeHooked then
        Share._escapeHooked = true
        local scene = SCENE_MANAGER:GetScene("gameMenuInGame")
        if scene then
            scene:RegisterCallback("StateChange", function(_, newState)
                if newState == SCENE_SHOWING and Share.IsPopupOpen and Share.IsPopupOpen() then
                    Share.HidePopup()
                    SCENE_MANAGER:ShowBaseScene()
                end
            end)
        end
    end
end
