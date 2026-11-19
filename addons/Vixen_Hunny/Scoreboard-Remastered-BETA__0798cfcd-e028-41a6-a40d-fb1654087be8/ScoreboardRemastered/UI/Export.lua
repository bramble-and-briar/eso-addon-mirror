-- Copyable text export (ESO has no clipboard API: select-all + Ctrl+C in the box).
local SBR = ScoreboardRemastered
local EX = {}
SBR.Export = EX

local WM = WINDOW_MANAGER
local MAX_CHARS = 30000

function EX:Create()
    if self.control then return end
    local tlw = WM:CreateTopLevelWindow("ScoreboardRemasteredExport")
    self.control = tlw
    tlw:SetDimensions(760, 520)
    tlw:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    tlw:SetHidden(true)
    tlw:SetMouseEnabled(true)
    tlw:SetMovable(true)
    tlw:SetClampedToScreen(true)
    tlw:SetDrawLayer(DL_OVERLAY)
    tlw:SetDrawTier(DT_HIGH)
    tlw:SetDrawLevel(10)

    local bg = WM:CreateControlFromVirtual("$(parent)BG", tlw, "ZO_DefaultBackdrop")
    bg:SetAnchorFill(tlw)

    local title = WM:CreateControl("$(parent)Title", tlw, CT_LABEL)
    title:SetFont("ZoFontWinH3")
    title:SetAnchor(TOPLEFT, tlw, TOPLEFT, 14, 10)
    self.title = title

    local hint = WM:CreateControl("$(parent)Hint", tlw, CT_LABEL)
    hint:SetFont("ZoFontGameSmall")
    hint:SetColor(0.7, 0.7, 0.7, 1)
    hint:SetText("Text is pre-selected: press Ctrl+C to copy.")
    hint:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 2)

    local close = WM:CreateControlFromVirtual("$(parent)Close", tlw, "ZO_CloseButton")
    close:SetAnchor(TOPRIGHT, tlw, TOPRIGHT, -6, 6)
    close:SetHandler("OnClicked", function() tlw:SetHidden(true) end)

    local editBg = WM:CreateControlFromVirtual("$(parent)EditBG", tlw, "ZO_EditBackdrop")
    editBg:SetAnchor(TOPLEFT, tlw, TOPLEFT, 14, 60)
    editBg:SetAnchor(BOTTOMRIGHT, tlw, BOTTOMRIGHT, -14, -14)

    local edit = WM:CreateControlFromVirtual("$(parent)Edit", editBg, "ZO_DefaultEditMultiLineForBackdrop")
    edit:SetMaxInputChars(MAX_CHARS)
    edit:SetFont("ZoFontGameSmall")
    edit:SetHandler("OnEscape", function(control) control:LoseFocus() tlw:SetHidden(true) end)
    self.edit = edit
end

function EX:Open(titleText, text)
    self:Create()
    if #text > MAX_CHARS then text = text:sub(1, MAX_CHARS - 20) .. "\n...(truncated)" end
    self.title:SetText(titleText)
    self.control:SetHidden(false)
    self.edit:SetText(text)
    self.edit:TakeFocus()
    self.edit:SelectAll()
end

local function csv(v)
    if v == nil then return "" end
    v = tostring(v)
    if v:find("[,\"\n]") then v = '"' .. v:gsub('"', '""') .. '"' end
    return v
end

local FIGHT_KEYS = {
    "damageDone", "healingDone", "damageTaken", "healingTaken", "dps", "hps", "killingBlows", "deaths",
    "interrupts", "interrupted", "ccApplied", "ccTaken", "damageShielded", "damageBlocked", "mitigated", "overheal",
    "critRate", "healCritRate", "maxHit", "lightAttacks", "heavyAttacks", "skillCasts", "ultimates", "weaves", "fights", "activeTime",
}
local VS_KEYS = { "damageFromYou", "damageToYou", "healedByYou", "healedYou", "killedByYou", "killedYou" }

function EX:BuildCSV(match)
    local lines = {}
    local types = SBR.Battleground.scoreTypes or {}
    local scoreKeys = {}
    for _, st in ipairs(types) do
        if match.columnsSeen and match.columnsSeen[st.key] then scoreKeys[#scoreKeys + 1] = st end
    end

    lines[#lines + 1] = string.format("# %s | %s | %s | result=%s | duration=%s | started=%s",
        match.name or "?", match.gameTypeName or "?", match.id or "?", match.result or "in progress",
        SBR.FormatDuration(match.duration), SBR.FormatTimestamp(match.startedAt))
    local teamParts = {}
    for id, t in pairs(match.teams or {}) do
        teamParts[#teamParts + 1] = string.format("%s=%s", t.name or id, tostring(t.score or "-"))
    end
    lines[#lines + 1] = "# teams: " .. table.concat(teamParts, ", ")

    local header = { "Team", "Character", "Account", "Class", "Local", "Left" }
    for _, st in ipairs(scoreKeys) do header[#header + 1] = st.label end
    header[#header + 1] = "Medals"
    header[#header + 1] = "MedalList"
    for _, k in ipairs(FIGHT_KEYS) do header[#header + 1] = "fight." .. k end
    for _, k in ipairs(VS_KEYS) do header[#header + 1] = "vs." .. k end
    header[#header + 1] = "FightSource"
    lines[#lines + 1] = table.concat(header, ",")

    local players = {}
    for _, p in pairs(match.players or {}) do players[#players + 1] = p end
    table.sort(players, function(a, b)
        if a.team ~= b.team then return (a.team or 99) < (b.team or 99) end
        return ((a.scores or {}).SCORE or 0) > ((b.scores or {}).SCORE or 0)
    end)

    for _, p in ipairs(players) do
        local team = match.teams and match.teams[p.team]
        local row = {
            csv(team and team.name or p.team), csv(p.characterName), csv(p.displayName), csv(p.className),
            p.isLocal and "1" or "0", p.left and "1" or "0",
        }
        for _, st in ipairs(scoreKeys) do row[#row + 1] = csv(p.scores and p.scores[st.key]) end
        row[#row + 1] = csv(p.medalCount)
        local ml = {}
        for _, m in ipairs(p.medals or {}) do ml[#ml + 1] = string.format("%s x%d", m.name or m.id, m.count or 1) end
        row[#row + 1] = csv(table.concat(ml, "; "))
        local f = p.fight or {}
        for _, k in ipairs(FIGHT_KEYS) do
            local v = f[k]
            if type(v) == "number" and v ~= math.floor(v) then v = string.format("%.2f", v) end
            row[#row + 1] = csv(v)
        end
        local vs = p.vs or {}
        for _, k in ipairs(VS_KEYS) do row[#row + 1] = csv(vs[k]) end
        row[#row + 1] = csv(f.source)
        lines[#lines + 1] = table.concat(row, ",")
    end
    return table.concat(lines, "\n")
end

function EX:Show(match)
    if not match then
        SBR.Print("No match to export.")
        return
    end
    if SBR.IsGamepad() then
        SBR.Gamepad:Open("match") -- consoles have no clipboard; the Match tab shows the summary
    else
        self:Open("Export: " .. (match.name or "Battleground"), self:BuildCSV(match))
    end
end

function EX:BuildKillFeed(match)
    local lines = {}
    local function teamColor(id)
        local t = match.teams and match.teams[id]
        return t and t.name or tostring(id or "?")
    end
    for _, k in ipairs(match.killFeed or {}) do
        lines[#lines + 1] = string.format("[%s] %s (%s) killed %s (%s)%s",
            SBR.FormatDuration(k.t), k.killer ~= "" and k.killer or "?", teamColor(k.killerTeam),
            k.victim ~= "" and k.victim or "?", teamColor(k.victimTeam),
            k.ability and k.ability ~= "" and (" with " .. k.ability) or "")
        for _, h in ipairs(SBR.MatchLog.DecodeRecap(k)) do
            lines[#lines + 1] = string.format("      %s%s %s from %s", SBR.FormatNumber(h.hit), h.crit and "*" or "",
                h.ability ~= "" and h.ability or "?", h.source ~= "" and h.source or "?")
        end
    end
    if #(match.myMedals or {}) > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Your medals (in order earned):"
        for _, m in ipairs(match.myMedals) do
            lines[#lines + 1] = string.format("  %s  +%s", m.name or m.id, tostring(m.value or ""))
        end
    end
    local lf = match.lf
    if lf and lf.deaths and #lf.deaths > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Your deaths (LibFights recap, last hits oldest first):"
        for _, dth in ipairs(lf.deaths) do
            lines[#lines + 1] = string.format("[%s] killed by %s%s", SBR.FormatDuration(dth.t), dth.killer or "?",
                dth.fight and (" during " .. dth.fight) or "")
            for _, h in ipairs(dth.hits or {}) do
                lines[#lines + 1] = string.format("    %s %s from %s%s", SBR.FormatNumber(h.hit), h.ability or "?",
                    h.source ~= "" and h.source or "?", h.result and (" (" .. h.result .. ")") or "")
            end
        end
    end
    local fightList = lf and lf.fightList
    if not fightList and lf and lf.fights then
        fightList = {}
        for _, e in pairs(lf.fights) do
            fightList[#fightList + 1] = { title = e.title, durationSec = e.durationSec, dps = e.dps, damage = e.me.damageDone,
                healing = e.me.healingDone, killingBlows = e.me.killingBlows, deaths = e.me.deaths, startTimestamp = e.startTimestamp }
        end
        table.sort(fightList, function(a, b) return (a.startTimestamp or 0) < (b.startTimestamp or 0) end)
    end
    if fightList and #fightList > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Fights (LibFights):"
        for i, fl in ipairs(fightList) do
            lines[#lines + 1] = string.format("  %d. %s  %s  dps %s  dmg %s  heal %s  KB %s  deaths %s", i, fl.title or "?",
                SBR.FormatDuration(fl.durationSec), SBR.FormatNumber(fl.dps), SBR.FormatNumber(fl.damage),
                SBR.FormatNumber(fl.healing), tostring(fl.killingBlows or 0), tostring(fl.deaths or 0))
        end
    end
    if #lines == 0 then lines[1] = "No kills recorded for this match." end
    return table.concat(lines, "\n")
end

function EX:ShowKillFeed(match)
    if not match then
        SBR.Print("No match selected.")
        return
    end
    local title, text = "Kill feed: " .. (match.name or "Battleground"), self:BuildKillFeed(match)
    if SBR.IsGamepad() then
        SBR.Gamepad:Open("kills")
    else
        self:Open(title, text)
    end
end
ScoreboardRemastered.Mark("UI/Export.lua")
