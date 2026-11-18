-- Console / gamepad screens, built from ESO's own gamepad framework so they look
-- and behave like the rest of the console UI:
--
--   * ZO_Gamepad_ParametricList_Screen: the left list in quadrant 1 with the
--     standard header (title, LB / RB tab bar, data pairs) and parametric scrolling
--   * ZO_GamepadMenuEntryTemplate(+WithHeader): standard list entries with icons
--   * GAMEPAD_RIGHT_TOOLTIP: the details of the selected entry in quadrant 4, laid out
--     with ESO's tooltip styles (title, stat / value pairs, body sections)
--   * the stock back button, list trigger keybinds (LT / RT), menu sounds,
--     minimised chat and the quadrant 1 background
--   * narration (screen reader) through the shared entry narration
--
-- Two screens:
--   Scoreboard Remastered  tabs: Players / Kill feed / Match
--   Battleground records   tabs: Matches / Players / Lifetime
-- The PC (mouse) UI in Window.lua / MatchBrowser.lua is unchanged.
local SBR = ScoreboardRemastered
local Console = {}
SBR.Console = Console

local RESULT_TEXT = { won = "Victory", lost = "Defeat", tie = "Draw", left = "Left early", unknown = "Unfinished" }
local RESULT_COLOR = { won = "6BDC73", lost = "EB6159", tie = "D9CC8C", left = "9E9E9E", unknown = "9E9E9E" }

local function Num(v) return type(v) == "number" and v or 0 end
local function N(v) return v == nil and "-" or SBR.FormatNumber(v) end
local function Pct(v) return v == nil and "-" or string.format("%d%%", math.floor(v + 0.5)) end
local function Icon(path, size)
    if type(path) ~= "string" or path == "" then return "" end
    return zo_iconFormat(path, size or 32, size or 32)
end
local function Color(hex, text) return string.format("|c%s%s|r", hex, text) end

---------------------------------------------------------------------------
-- Tooltip layouts (ZO_Tooltip methods, dispatched by GAMEPAD_TOOLTIPS:Layout...)
---------------------------------------------------------------------------
-- Everything in a tooltip is laid out full width. Without a width, ESO sizes a line or
-- stat / value pair to its text and never wraps it, so long rows ran past the
-- tooltip's right edge, which is the right edge of the screen.
local RIGHT_ALIGNED = { horizontalAlignment = TEXT_ALIGN_RIGHT }
local STAT_MAX_CHARS = 20

-- Shortens plain text (no colour or icon markup) so a stat label leaves room for its value.
local function Fit(text, maxChars)
    text = tostring(text or "")
    maxChars = maxChars or STAT_MAX_CHARS
    if text:find("|", 1, true) or #text <= maxChars then return text end
    local cut = maxChars - 1
    while cut > 1 and text:byte(cut + 1) and text:byte(cut + 1) >= 128 and text:byte(cut + 1) < 192 do cut = cut - 1 end
    return text:sub(1, cut) .. "\226\128\166" -- "..." (never splits a UTF-8 character)
end

local function Title(tooltip, title, subtitle)
    local full = tooltip:GetStyle("fullWidth")
    local s = tooltip:AcquireSection(tooltip:GetStyle("bodySection"))
    s:AddLine(title, tooltip:GetStyle("title"), full)
    if subtitle and subtitle ~= "" then s:AddLine(subtitle, tooltip:GetStyle("bodyDescription"), full) end
    tooltip:AddSection(s)
end

local function Pairs(tooltip, header, rows, small)
    local s = tooltip:AcquireSection(tooltip:GetStyle("bodySection"))
    local full = tooltip:GetStyle("fullWidth")
    if header then s:AddLine(header, tooltip:GetStyle("bodyHeader"), full) end
    local any = false
    for _, row in ipairs(rows) do
        if row[2] ~= nil then
            local pair = s:AcquireStatValuePair(tooltip:GetStyle("statValuePair"), full)
            pair:SetStat(Fit(row[1]), tooltip:GetStyle("statValuePairStat"))
            pair:SetValue(tostring(row[2]), tooltip:GetStyle(small and "statValuePairValueSmall" or "statValuePairValue"), RIGHT_ALIGNED)
            s:AddStatValuePair(pair)
            any = true
        end
    end
    if any then tooltip:AddSection(s) end
end

local function Lines(tooltip, header, lines)
    if not lines or #lines == 0 then return end
    local s = tooltip:AcquireSection(tooltip:GetStyle("bodySection"))
    local full = tooltip:GetStyle("fullWidth")
    if header then s:AddLine(header, tooltip:GetStyle("bodyHeader"), full) end
    for _, line in ipairs(lines) do s:AddLine(line, tooltip:GetStyle("bodyDescription"), full) end
    tooltip:AddSection(s)
end

-- Lists (abilities, medals, recaps, fights) are stat / value rows, like ESO's own
-- console tooltips: body text is 42 px and would wrap in the 470 px column.
local function AbilityRows(list, limit)
    local out = {}
    for i, a in ipairs(list or {}) do
        if i > (limit or 5) then break end
        out[#out + 1] = { Icon(a.icon, 32) .. " " .. Fit(a.name or "?", 18), N(a.damage) }
    end
    return out
end

local function MedalRows(list)
    local out = {}
    for _, m in ipairs(list or {}) do out[#out + 1] = { Icon(m.icon, 32) .. " " .. Fit(m.name or "?", 18), "x" .. (m.count or 1) } end
    return out
end

-- A player in the viewed match.
function ZO_Tooltip:LayoutScoreboardRemasteredPlayer(p, match)
    local team = match and match.teams and match.teams[p.team]
    local sub = string.format("%s %s  ·  %s", Icon(p.classIcon, 32), p.className or "", p.displayName or "")
    if team then sub = sub .. "  ·  " .. Color(team.color or "FFFFFF", team.name or "") end
    Title(self, (p.characterName or "?") .. (p.isLocal and "  (you)" or ""), sub)
    local s = p.scores or {}
    Pairs(self, nil, {
        { "Score", s.SCORE }, { "K / D / A", string.format("%s / %s / %s", tostring(s.KILL or "-"), tostring(s.DEATH or "-"), tostring(s.ASSISTS or "-")) },
        { "Damage", N(s.DAMAGE_DONE) }, { "Healing", N(s.HEALING_DONE) },
    })
    local f = p.fight
    if f then
        Pairs(self, "Fight data (" .. (f.source or "") .. ")", {
            { "DPS / HPS", f.dps and (N(f.dps) .. " / " .. (f.hps and N(f.hps) or "-")) or nil },
            { "Damage taken", f.damageTaken and N(f.damageTaken) },
            { "Healing taken", f.healingTaken and N(f.healingTaken) },
            { "Killing blows", f.killingBlows },
            { "Interrupts", Num(f.interrupts) > 0 and f.interrupts or nil },
            { "Crowd control", (f.ccApplied or f.ccTaken) and string.format("%d dealt / %d taken", Num(f.ccApplied), Num(f.ccTaken)) or nil },
            { "Shields absorbed", Num(f.damageShielded) > 0 and N(f.damageShielded) or nil },
            { "Crit rate", f.critRate and Pct(f.critRate) },
            { "Max hit", f.maxHit and N(f.maxHit) or nil },
            { "Max hit ability", f.maxHitAbility },
            { "Combat time", f.activeTime and SBR.FormatDuration(f.activeTime) or nil },
        }, true)
        Pairs(self, "Top abilities", AbilityRows(f.topAbilities, 5), true)
        if f.source and f.source:find("vs your team", 1, true) then
            Lines(self, nil, { "Enemy: only what they did to and took from your team." })
        end
    end
    Pairs(self, "Medals", MedalRows(p.medals), true)
    local v = p.vs
    if v and not p.isLocal then
        Pairs(self, "You vs them", {
            { "Damage to them", Num(v.damageFromYou) > 0 and N(v.damageFromYou) or nil },
            { "Damage to you", Num(v.damageToYou) > 0 and N(v.damageToYou) or nil },
            { "You killed them", Num(v.killedByYou) > 0 and Num(v.killedByYou) or nil },
            { "They killed you", Num(v.killedYou) > 0 and Num(v.killedYou) or nil },
            { "You healed them", Num(v.healedByYou) > 0 and N(v.healedByYou) or nil },
            { "They healed you", Num(v.healedYou) > 0 and N(v.healedYou) or nil },
        }, true)
    end
end

-- A kill from the kill feed, with the victim's last hits.
function ZO_Tooltip:LayoutScoreboardRemasteredKill(k, match)
    local function teamColored(name, teamId)
        local t = match and match.teams and match.teams[teamId]
        return t and Color(t.color or "FFFFFF", name) or name
    end
    Title(self, k.victim ~= "" and k.victim or "?", SBR.FormatDuration(k.t))
    Pairs(self, nil, {
        { "Killed by", teamColored(k.killer ~= "" and k.killer or "?", k.killerTeam) },
        { "Victim", teamColored(k.victim ~= "" and k.victim or "?", k.victimTeam) },
        { "Killing blow", k.ability ~= "" and k.ability or nil },
    }, true)
    local recap = {}
    for _, h in ipairs(k.recap or {}) do
        recap[#recap + 1] = { Fit((h.ability ~= "" and h.ability or "?") .. " · " .. (h.source ~= "" and h.source or "?")),
            N(h.hit) .. (h.crit and "*" or "") }
    end
    Pairs(self, "Last hits (oldest first)", recap, true)
end

-- Match overview / your fights / your deaths (Match tab).
function ZO_Tooltip:LayoutScoreboardRemasteredMatchPart(part, match)
    if part == "overview" then
        local res = match.result and RESULT_TEXT[match.result]
        Title(self, match.name or "Battleground", string.format("%s  ·  %s", match.gameTypeName or "",
            res and Color(RESULT_COLOR[match.result], res) or (match.stateName or "In progress")))
        local rows = {}
        for _, t in pairs(match.teams or {}) do
            if t.score ~= nil then rows[#rows + 1] = { Color(t.color or "FFFFFF", t.name or "?"), t.score } end
        end
        table.sort(rows, function(a, b) return tostring(a[1]) < tostring(b[1]) end)
        rows[#rows + 1] = { "Duration", match.duration and SBR.FormatDuration(match.duration) or nil }
        rows[#rows + 1] = { "Kills recorded", #(match.killFeed or {}) }
        Pairs(self, nil, rows)
    elseif part == "fights" then
        Title(self, "Your fights", "LibFights")
        local rows = {}
        for i, fl in ipairs(match.lf and match.lf.fightList or {}) do
            rows[#rows + 1] = { Fit(string.format("%d. %s", i, fl.title or "?"), 16) .. " · " .. SBR.FormatDuration(fl.durationSec), N(fl.dps) .. " DPS" }
        end
        if #rows > 0 then Pairs(self, nil, rows, true) else Lines(self, nil, { "No fights recorded yet." }) end
    elseif part == "deaths" then
        Title(self, "Your deaths", "LibFights death recap")
        for _, d in ipairs(match.lf and match.lf.deaths or {}) do
            local hits = {}
            for _, h in ipairs(d.hits or {}) do
                hits[#hits + 1] = { Fit((h.ability or "?") .. " · " .. (h.source or "?")), N(h.hit) }
            end
            Pairs(self, string.format("%s  killed by %s", SBR.FormatDuration(d.t), d.killer or "?"), hits, true)
        end
    end
end

-- A match record (Battleground records > Matches).
function ZO_Tooltip:LayoutScoreboardRemasteredRecord(r)
    Title(self, Color(RESULT_COLOR[r.result] or "FFFFFF", RESULT_TEXT[r.result] or "Ended") .. "  " .. (r.map or ""),
        string.format("%s  ·  %s  ·  %s  ·  %s %s", r.gameType or "", SBR.FormatDuration(r.duration), SBR.FormatTimestamp(r.at),
            Icon(r.classIcon, 32), r.character or ""))
    local teams = {}
    for _, t in ipairs(r.teams or {}) do
        teams[#teams + 1] = { Color(t.color or "FFFFFF", (t.id == r.localTeam and "* " or "") .. (t.name or "?")), t.score }
    end
    Pairs(self, nil, teams)
    Pairs(self, nil, {
        { "K / D / A", string.format("%s / %s / %s", tostring(r.kills or "-"), tostring(r.deaths or "-"), tostring(r.assists or "-")) },
        { "Damage", N(r.damage) }, { "Healing", N(r.healing) }, { "Score", N(r.score) },
    })
    Pairs(self, nil, {
        { "Team rank", r.teamRank and string.format("#%d", r.teamRank) or nil },
        { "Overall rank", r.rank and string.format("#%d of %d", r.rank, r.players or 0) or nil },
        { "Match MVP", r.mvp and (r.mvp.isYou and "You" or r.mvp.name) or nil },
        { "DPS", r.dps and N(r.dps) or nil },
        { "Max hit", r.maxHit and N(r.maxHit) or nil },
        { "Max hit ability", r.maxHitAbility },
        { "Crit rate", r.critRate and Pct(r.critRate) or nil },
    }, true)
    Pairs(self, "Medals", MedalRows(r.medals), true)
    Pairs(self, "Top abilities", AbilityRows(r.top, 3), true)
end

-- A player from the player index (Battleground records > Players).
function ZO_Tooltip:LayoutScoreboardRemasteredKnownPlayer(e)
    local sum = SBR.MatchDB:PlayerSummary(e)
    local relation = ({ you = "You", ally = "Teammate", foe = "Opponent", both = "Teammate and opponent" })[sum.relation]
    Title(self, e.name or e.key, string.format("%s %s  ·  %s  ·  %s", Icon(e.lastClassIcon, 32), e.account or "", relation,
        string.format("%d match%s", e.matches, e.matches == 1 and "" or "es")))
    if not e.isYou then
        Pairs(self, "Your record", {
            { "With them", e.withMatches > 0 and string.format("%d-%d", e.withWon, e.withMatches - e.withWon) or nil },
            { "Against them", e.againstMatches > 0 and string.format("%d-%d", e.againstWon, e.againstMatches - e.againstWon) or nil },
        })
        Pairs(self, "You vs them", {
            { "They killed you", e.killedYou }, { "You killed them", e.killedByYou },
            { "Damage to you", e.damageToYou > 0 and N(e.damageToYou) or nil },
            { "Damage to them", e.damageFromYou > 0 and N(e.damageFromYou) or nil },
            { "Healed you", e.healedYou > 0 and N(e.healedYou) or nil },
        }, true)
    end
    local pm = sum.perMatch
    Pairs(self, "Totals (per match)", {
        { "Kills", string.format("%d  (%.1f)", e.kills, pm.kills) },
        { "Deaths", string.format("%d  (%.1f)", e.deaths, pm.deaths) },
        { "Assists", string.format("%d  (%.1f)", e.assists, pm.assists) },
        { "Damage", string.format("%s  (%s)", N(e.damage), N(pm.damage)) },
        { "Healing", string.format("%s  (%s)", N(e.healing), N(pm.healing)) },
        { "Best score", string.format("%s  %s", N(e.bestScore), e.bestScoreMap or "") },
    }, true)
    local classes = {}
    for _, c in ipairs(sum.classes) do classes[#classes + 1] = { Icon(c.icon, 32) .. " " .. Fit(c.className, 18), c.matches .. " match" .. (c.matches == 1 and "" or "es") } end
    Pairs(self, "Classes played", classes, true)
    Pairs(self, "Top abilities", AbilityRows(sum.abilities, 5), true)
    Pairs(self, "Last seen", { { e.lastMap or "?", SBR.FormatTimestamp(e.lastSeen) } }, true)
end

-- Lifetime record (Battleground records > Lifetime).
function ZO_Tooltip:LayoutScoreboardRemasteredLifetime(kind, value)
    local DB = SBR.MatchDB
    if kind == "overview" then
        local a = DB:Aggregate(DB:GetRecords())
        Title(self, "Lifetime", string.format("%d matches  ·  %d won  ·  %d lost", a.matches, a.won, a.lost))
        Pairs(self, nil, {
            { "Win rate", a.winRate and Pct(a.winRate) or "-" }, { "Kill / death", string.format("%.2f", a.kd) },
            { "Times MVP", a.mvps }, { "Current streak", a.streak > 0 and ((a.streakKind == "won" and "W" or "L") .. a.streak) or "-" },
        })
        Pairs(self, "Bests", {
            { "Damage", a.bestDamage and (N(a.bestDamage.damage) .. "  " .. a.bestDamage.map) or nil },
            { "Healing", a.bestHealing and (N(a.bestHealing.healing) .. "  " .. a.bestHealing.map) or nil },
            { "Kills", a.bestKills and (a.bestKills.kills .. "  " .. a.bestKills.map) or nil },
        }, true)
        Pairs(self, "Totals", {
            { "K / D / A", string.format("%d / %d / %d", a.kills, a.deaths, a.assists) },
            { "Damage", N(a.damage) }, { "Healing", N(a.healing) }, { "Medals", a.medals },
            { "Time played", SBR.FormatDuration(a.seconds) },
        }, true)
    else
        local list = {}
        for _, r in ipairs(DB:GetRecords()) do
            if (kind == "class" and r.className == value) or (kind == "map" and r.map == value) then list[#list + 1] = r end
        end
        local a = DB:Aggregate(list)
        Title(self, value, string.format("%d matches  ·  %d won  ·  %d lost", a.matches, a.won, a.lost))
        Pairs(self, nil, {
            { "Win rate", a.winRate and Pct(a.winRate) or "-" }, { "Kill / death", string.format("%.2f", a.kd) },
            { "Average damage", a.matches > 0 and N(a.damage / a.matches) or "-" },
            { "Average healing", a.matches > 0 and N(a.healing / a.matches) or "-" },
        })
    end
end

---------------------------------------------------------------------------
-- Shared screen setup
---------------------------------------------------------------------------
local function NewScene(name, control)
    local scene = ZO_Scene:New(name, SCENE_MANAGER)
    if FRAGMENT_GROUP and FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW then scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW) end
    for _, f in ipairs({ GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT, MINIMIZE_CHAT_FRAGMENT, GAMEPAD_MENU_SOUND_FRAGMENT }) do
        if f then scene:AddFragment(f) end
    end
    scene:AddFragment(ZO_FadeSceneFragment:New(control))
    return scene
end

local function Entry(text, icon, data)
    local e = ZO_GamepadEntryData:New(text, icon)
    if icon then e:SetIconTintOnSelection(true) end
    for k, v in pairs(data or {}) do e[k] = v end
    return e
end

local function AddEntry(list, entry, header)
    if header then
        entry:SetHeader(header)
        list:AddEntry("ZO_GamepadMenuEntryTemplateWithHeader", entry)
    else
        list:AddEntry("ZO_GamepadMenuEntryTemplate", entry)
    end
end

local function ShowTooltip(layout, ...)
    GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
    if layout then GAMEPAD_TOOLTIPS[layout](GAMEPAD_TOOLTIPS, GAMEPAD_RIGHT_TOOLTIP, ...) end
end

local function SelectAudio()
    if SOUNDS and SOUNDS.GAMEPAD_MENU_FORWARD then PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD) end
end

---------------------------------------------------------------------------
-- Scoreboard Remastered (console)
---------------------------------------------------------------------------
local Scoreboard = ZO_Gamepad_ParametricList_Screen:Subclass()
Console.ScoreboardClass = Scoreboard

local PLAYER_SORTS = {
    { label = "Score", value = function(p) return p.scores and p.scores.SCORE end },
    { label = "Kills", value = function(p) return p.scores and p.scores.KILL end },
    { label = "Damage", value = function(p) return p.scores and p.scores.DAMAGE_DONE end },
    { label = "Healing", value = function(p) return p.scores and p.scores.HEALING_DONE end },
    { label = "DPS", value = function(p) return p.fight and p.fight.dps end },
}

function Scoreboard:Initialize(control)
    self.sceneName = "scoreboardRemasteredConsole"
    local scene = NewScene(self.sceneName, control)
    ZO_Gamepad_ParametricList_Screen.Initialize(self, control, ZO_GAMEPAD_HEADER_TABBAR_CREATE, true, scene)
    self.tab, self.sortIndex = "players", 1
    local function tab(name) return function() if self.tab ~= name then self.tab = name; self:Update() end end end
    self.headerData = {
        titleText = "Scoreboard Remastered",
        tabBarEntries = {
            { text = "Players", callback = tab("players") },
            { text = "Kill feed", callback = tab("kills") },
            { text = "Match", callback = tab("match") },
        },
    }
    ZO_GamepadGenericHeader_Refresh(self.header, self.headerData)
end

function Scoreboard:InitializeKeybindStripDescriptors()
    self.keybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = function() return "Sort: " .. PLAYER_SORTS[self.sortIndex].label end,
            keybind = "UI_SHORTCUT_SECONDARY",
            callback = function()
                self.sortIndex = self.sortIndex % #PLAYER_SORTS + 1
                self:Update()
                SelectAudio()
            end,
            visible = function() return self.tab == "players" end,
        },
        {
            name = "Battleground records",
            keybind = "UI_SHORTCUT_TERTIARY",
            callback = function() Console.records:Open() end,
        },
        KEYBIND_STRIP:GetDefaultGamepadBackButtonDescriptor(),
    }
    ZO_Gamepad_AddListTriggerKeybindDescriptors(self.keybindStripDescriptor, self:GetMainList())
end

function Scoreboard:GetMatch()
    return SBR.Window:GetViewedMatch()
end

function Scoreboard:RefreshHeader(match)
    -- With a tab bar, ESO's header shows the tabs in place of the title, so the map
    -- goes in the first data pair: map, the two team scores, then result or time.
    local h = self.headerData
    h.titleText = "Scoreboard Remastered"
    for i = 1, 4 do h["data" .. i .. "HeaderText"], h["data" .. i .. "Text"] = nil, nil end
    if match then
        h.data1HeaderText, h.data1Text = "Map", match.name or match.zoneName or ""
        local ids = {}
        for id, t in pairs(match.teams or {}) do if t.score ~= nil then ids[#ids + 1] = id end end
        table.sort(ids)
        for i, id in ipairs(ids) do
            if i > 2 then break end
            local t = match.teams[id]
            h["data" .. (i + 1) .. "HeaderText"] = (id == match.localTeam and "* " or "") .. (t.name or "?")
            h["data" .. (i + 1) .. "Text"] = Color(t.color or "FFFFFF", tostring(t.score))
        end
        if match.endedAt then
            h.data4HeaderText = "Result"
            h.data4Text = Color(RESULT_COLOR[match.result] or "FFFFFF", RESULT_TEXT[match.result] or "Ended")
        else
            h.data4HeaderText = "Time"
            h.data4Text = match.runningSince and SBR.FormatDuration(SBR.Now() - match.runningSince) or (match.stateName or "")
        end
    end
    ZO_GamepadGenericHeader_RefreshData(self.header, h)
end

function Scoreboard:PerformUpdate()
    self.dirty = false
    local list = self:GetMainList()
    list:Clear()
    local match = self:GetMatch()
    self.match = match
    self:RefreshHeader(match)
    if not match then
        list:AddEntry("ZO_GamepadMenuEntryTemplate", Entry("No battleground data yet"))
        list:Commit()
        return
    end
    if self.tab == "players" then
        local sort = PLAYER_SORTS[self.sortIndex].value
        local byTeam = {}
        for _, p in pairs(match.players or {}) do
            byTeam[p.team or 0] = byTeam[p.team or 0] or {}
            table.insert(byTeam[p.team or 0], p)
        end
        local teamIds = {}
        for id in pairs(byTeam) do teamIds[#teamIds + 1] = id end
        table.sort(teamIds, function(a, b)
            if a == match.localTeam then return true end
            if b == match.localTeam then return false end
            return a < b
        end)
        for _, id in ipairs(teamIds) do
            local players = byTeam[id]
            table.sort(players, function(a, b)
                local va, vb = Num(sort(a)), Num(sort(b))
                if va ~= vb then return va > vb end
                return (a.characterName or "") < (b.characterName or "")
            end)
            local t = match.teams and match.teams[id]
            local header = t and string.format("%s  %s", t.name or "?", tostring(t.score or "")) or "Players"
            for i, p in ipairs(players) do
                local name = p.characterName ~= "" and p.characterName or p.displayName or "?"
                if p.isLocal then name = name .. " (you)" end
                if p.left then name = name .. " (left)" end
                AddEntry(list, Entry(name, p.classIcon, { player = p }), i == 1 and header or nil)
            end
        end
    elseif self.tab == "kills" then
        local feed = match.killFeed or {}
        if #feed == 0 then list:AddEntry("ZO_GamepadMenuEntryTemplate", Entry("No kills yet")) end
        for i = #feed, 1, -1 do
            local k = feed[i]
            local killer = k.killer ~= "" and k.killer or "?"
            local victim = k.victim ~= "" and k.victim or "?"
            local icon
            for _, p in pairs(match.players or {}) do if p.characterName == killer then icon = p.classIcon break end end
            AddEntry(list, Entry(killer .. " > " .. victim, icon, { kill = k }), i == #feed and "Newest first" or nil)
        end
    else
        AddEntry(list, Entry("Overview", nil, { part = "overview" }), "This match")
        if match.lf then
            AddEntry(list, Entry("Your fights", nil, { part = "fights" }), "LibFights")
            if match.lf.deaths and #match.lf.deaths > 0 then
                list:AddEntry("ZO_GamepadMenuEntryTemplate", Entry("Your deaths", nil, { part = "deaths" }))
            end
        end
    end
    list:Commit()
    self:RefreshTooltip(list:GetTargetData())
end

function Scoreboard:OnTargetChanged(list, targetData)
    self:RefreshTooltip(targetData)
end

function Scoreboard:RefreshTooltip(data)
    if not data then return ShowTooltip(nil) end
    if data.player then ShowTooltip("LayoutScoreboardRemasteredPlayer", data.player, self.match)
    elseif data.kill then ShowTooltip("LayoutScoreboardRemasteredKill", data.kill, self.match)
    elseif data.part then ShowTooltip("LayoutScoreboardRemasteredMatchPart", data.part, self.match)
    else ShowTooltip(nil) end
end

function Scoreboard:OnShowing()
    ZO_GamepadGenericHeader_Activate(self.header)
    if SBR.MatchLog:GetCurrent() then SBR.MatchLog:Snapshot() end
    self:Update()
end

function Scoreboard:OnHide()
    ZO_GamepadGenericHeader_Deactivate(self.header)
    GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
end

function Scoreboard:Open()
    if not SCENE_MANAGER:IsShowing(self.sceneName) then SCENE_MANAGER:Push(self.sceneName) end
end

function Scoreboard:Close()
    if SCENE_MANAGER:IsShowing(self.sceneName) then SCENE_MANAGER:HideCurrentScene() end
end

function Scoreboard:IsShowingScene() return SCENE_MANAGER:IsShowing(self.sceneName) end

function Scoreboard:OnDataChanged()
    if self:IsShowingScene() then self:Update() end
end

---------------------------------------------------------------------------
-- Battleground records (console)
---------------------------------------------------------------------------
local Records = ZO_Gamepad_ParametricList_Screen:Subclass()
Console.RecordsClass = Records

function Records:Initialize(control)
    self.sceneName = "scoreboardRemasteredRecordsConsole"
    local scene = NewScene(self.sceneName, control)
    ZO_Gamepad_ParametricList_Screen.Initialize(self, control, ZO_GAMEPAD_HEADER_TABBAR_CREATE, true, scene)
    self.tab = "matches"
    self.state = { matches = { filter = 1, sort = 1 }, players = { filter = 1, sort = 1 } }
    local function tab(name) return function() if self.tab ~= name then self.tab = name; self:Update() end end end
    self.tabIndex = { matches = 1, players = 2, lifetime = 3 }
    self.headerData = {
        titleText = "Battleground records",
        tabBarEntries = {
            { text = "Matches", callback = tab("matches") },
            { text = "Players", callback = tab("players") },
            { text = "Lifetime", callback = tab("lifetime") },
        },
    }
    ZO_GamepadGenericHeader_Refresh(self.header, self.headerData)
end

function Records:Filters()
    local DB = SBR.MatchDB
    if self.tab == "players" then return DB.PLAYER_FILTERS, DB.PLAYER_FILTER_LABELS, DB.PLAYER_SORTS, DB.PLAYER_SORT_LABELS end
    return DB.FILTERS, DB.FILTER_LABELS, DB.SORTS, DB.SORT_LABELS
end

function Records:InitializeKeybindStripDescriptors()
    local function st() return self.state[self.tab] end
    self.keybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = "View scoreboard",
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function()
                local data = self:GetMainList():GetTargetData()
                local _, index = SBR.MatchDB:FindMatch(data and data.record and data.record.id)
                if index then
                    SBR.Window.viewIndex = index
                    Console.scoreboard:Open()
                end
            end,
            visible = function()
                local data = self:GetMainList():GetTargetData()
                return self.tab == "matches" and data and data.record and SBR.MatchDB:FindMatch(data.record.id) ~= nil
            end,
        },
        {
            name = function()
                local filters, labels = self:Filters()
                return "Filter: " .. (labels[filters[st().filter]] or "")
            end,
            keybind = "UI_SHORTCUT_SECONDARY",
            callback = function()
                local filters = self:Filters()
                st().filter = st().filter % #filters + 1
                self:Update()
                SelectAudio()
            end,
            visible = function() return self.tab ~= "lifetime" end,
        },
        {
            name = function()
                local _, _, sorts, labels = self:Filters()
                return "Sort: " .. (labels[sorts[st().sort]] or "")
            end,
            keybind = "UI_SHORTCUT_TERTIARY",
            callback = function()
                local _, _, sorts = self:Filters()
                st().sort = st().sort % #sorts + 1
                self:Update()
                SelectAudio()
            end,
            visible = function() return self.tab ~= "lifetime" end,
        },
        KEYBIND_STRIP:GetDefaultGamepadBackButtonDescriptor(),
    }
    ZO_Gamepad_AddListTriggerKeybindDescriptors(self.keybindStripDescriptor, self:GetMainList())
end

function Records:RefreshHeader()
    local DB = SBR.MatchDB
    local a = DB:Aggregate(DB:GetRecords())
    local h = self.headerData
    h.data1HeaderText, h.data1Text = "Matches", tostring(a.matches)
    h.data2HeaderText, h.data2Text = "Win rate", a.winRate and Pct(a.winRate) or "-"
    h.data3HeaderText, h.data3Text = "K/D", string.format("%.2f", a.kd)
    ZO_GamepadGenericHeader_RefreshData(self.header, h)
end

function Records:PerformUpdate()
    self.dirty = false
    local DB = SBR.MatchDB
    local list = self:GetMainList()
    list:Clear()
    self:RefreshHeader()
    if self.tab == "matches" then
        local st = self.state.matches
        local ref = DB:Query("all", "newest")[1]
        local items = DB:Query(DB.FILTERS[st.filter], DB.SORTS[st.sort], ref)
        local lastDate
        for _, r in ipairs(items) do
            local date = SBR.API("GetDateStringFromTimestamp", r.at) or ""
            -- group by day when sorted by date, otherwise one heading for the sort
            local header
            if DB.SORTS[st.sort] == "newest" then
                if date ~= lastDate then header = date end
            elseif not lastDate then
                header = DB.SORT_LABELS[DB.SORTS[st.sort]]
            end
            lastDate = date
            local res = RESULT_TEXT[r.result] or ""
            AddEntry(list, Entry(string.format("%s  %s", r.map or "?", Color(RESULT_COLOR[r.result] or "FFFFFF", res)), r.classIcon,
                { record = r }), header)
        end
        if #items == 0 then list:AddEntry("ZO_GamepadMenuEntryTemplate", Entry("No matches")) end
    elseif self.tab == "players" then
        local st = self.state.players
        local items = DB:QueryPlayers(DB.PLAYER_FILTERS[st.filter], DB.PLAYER_SORTS[st.sort])
        local lastRelation
        for _, e in ipairs(items) do
            local rel = DB:PlayerSummary(e).relation
            local relLabel = ({ you = "You", ally = "Teammates", foe = "Opponents", both = "Teammates and opponents" })[rel]
            local header
            if DB.PLAYER_SORTS[st.sort] == "seen" then
                if rel ~= lastRelation then header = relLabel end
            elseif not lastRelation then
                header = DB.PLAYER_SORT_LABELS[DB.PLAYER_SORTS[st.sort]]
            end
            lastRelation = rel
            AddEntry(list, Entry(e.name or e.key, e.lastClassIcon, { known = e }), header)
        end
        if #items == 0 then list:AddEntry("ZO_GamepadMenuEntryTemplate", Entry("No players")) end
    else
        AddEntry(list, Entry("Overview", nil, { life = "overview" }), "Lifetime")
        local a = DB:Aggregate(DB:GetRecords())
        local classes = {}
        for _, c in pairs(a.classes) do classes[#classes + 1] = c end
        table.sort(classes, function(x, y) return x.played > y.played end)
        for i, c in ipairs(classes) do
            AddEntry(list, Entry(c.className, c.icon, { life = "class", value = c.className }), i == 1 and "By class" or nil)
        end
        local maps = {}
        for _, m in pairs(a.maps) do maps[#maps + 1] = m end
        table.sort(maps, function(x, y) return x.played > y.played end)
        for i, m in ipairs(maps) do
            AddEntry(list, Entry(m.map, nil, { life = "map", value = m.map }), i == 1 and "By map" or nil)
        end
    end
    list:Commit()
    self:RefreshTooltip(list:GetTargetData())
end

function Records:OnTargetChanged(list, targetData)
    self:RefreshTooltip(targetData)
    self:RefreshKeybinds()
end

function Records:RefreshTooltip(data)
    if not data then return ShowTooltip(nil) end
    if data.record then ShowTooltip("LayoutScoreboardRemasteredRecord", data.record)
    elseif data.known then ShowTooltip("LayoutScoreboardRemasteredKnownPlayer", data.known)
    elseif data.life then ShowTooltip("LayoutScoreboardRemasteredLifetime", data.life, data.value)
    else ShowTooltip(nil) end
end

function Records:OnShowing()
    ZO_GamepadGenericHeader_Activate(self.header)
    if self.pendingTab and self.tabIndex[self.pendingTab] then
        ZO_GamepadGenericHeader_SetActiveTabIndex(self.header, self.tabIndex[self.pendingTab])
        self.tab = self.pendingTab
        self.pendingTab = nil
    end
    self:Update()
end

function Records:OnHide()
    ZO_GamepadGenericHeader_Deactivate(self.header)
    GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
end

-- tab: optional "matches" | "players" | "lifetime"
function Records:Open(tab)
    self.pendingTab = tab
    if not SCENE_MANAGER:IsShowing(self.sceneName) then SCENE_MANAGER:Push(self.sceneName) end
end

---------------------------------------------------------------------------
-- XML entry points (UI/Console.xml)
---------------------------------------------------------------------------
function ScoreboardRemastered_ScoreboardConsole_OnInitialized(control)
    Console.scoreboard = Scoreboard:New(control)
end

function ScoreboardRemastered_RecordsConsole_OnInitialized(control)
    Console.records = Records:New(control)
end
