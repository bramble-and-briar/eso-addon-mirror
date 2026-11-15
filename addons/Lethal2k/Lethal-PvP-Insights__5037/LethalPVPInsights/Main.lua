-- Lethal PVP Insights - initialization and slash commands
local PDI = PVPDataInsight
local EM = EVENT_MANAGER

ZO_CreateStringId("SI_BINDING_NAME_PVPDI_TOGGLE", "Toggle Lethal PVP Insights window")

local function onOff(v) return v and "|c00FF00on|r" or "|cFF4444off|r" end

local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end

function PDI.WipeAll()
    for _, k in ipairs({ "my", "feed", "opponents", "names", "group", "logCoverage", "killEvents", "ap", "apEvents" }) do PDI.sv[k] = {} end
    PDI.sv.lifetime = { my = {}, feed = {}, ap = {} }
    PDI.Data:ResetSession()
    PDI.Msg("All data wiped (saved players and saved builds were kept).")
    PDI.UI:RefreshIfVisible()
end

local function Slash(arg)
    local raw = zo_strtrim(arg or "")
    local cmd, rawRest = raw:match("^(%S*)%s*(.-)$")
    cmd = string.lower(cmd or "")
    local rest = string.lower(rawRest or "")

    if cmd == "" or cmd == "show" then
        PDI.UI:Toggle()
    elseif cmd == "notify" then
        PDI.sv.settings.chatNotify = (rest == "on") or (rest ~= "off" and not PDI.sv.settings.chatNotify)
        PDI.Msg("Chat notifications: " .. onOff(PDI.sv.settings.chatNotify))
    elseif cmd == "groupscope" then
        if rest == "pvp" or rest == "pve" or rest == "both" then
            PDI.sv.settings.groupScope = rest
            PDI.Group:Scan(); PDI.LogAssist:Evaluate()
        end
        PDI.Msg("Group history records groups in: " .. (PDI.sv.settings.groupScope or "pvp") .. "  (pvp | pve | both)")
    elseif cmd == "killdays" then
        local d = tonumber(rest)
        if d and d >= 1 and d <= 60 then PDI.sv.settings.killEventDays = math.floor(d); PDI.Data:Prune() end
        PDI.Msg(string.format("Kill event log is kept for %d days.", tonumber(PDI.sv.settings.killEventDays) or 7))
    elseif cmd == "buffhours" then
        local h = tonumber(rest)
        if h and h >= 1 and h <= 168 then PDI.sv.settings.buffWindowHours = math.floor(h) end
        PDI.Msg(string.format("Buffs of targeted players are collected for %d hours, then start fresh.",
            tonumber(PDI.sv.settings.buffWindowHours) or 36))
    elseif cmd == "pvponly" then
        PDI.sv.settings.onlyPvP = (rest == "on") or (rest ~= "off" and not PDI.sv.settings.onlyPvP)
        PDI.Msg("Track only in Cyrodiil/IC/Battlegrounds: " .. onOff(PDI.sv.settings.onlyPvP))
    elseif cmd == "reset" then
        PDI.Data:ResetSession()
        PDI.Msg("Session counters reset.")
        PDI.UI:RefreshIfVisible()
    elseif cmd == "wipe" then
        if rest == "confirm" then
            PDI.WipeAll()
        else
            PDI.Msg("This deletes all kill counters and opponent data. Type |cFFFFFF/lpi wipe confirm|r to proceed.")
        end
    elseif cmd == "clearlocal" then
        if rest == "cancel" then PDI.Share:CancelClear()
        elseif rest == "confirm" then PDI.Share:RequestClearAfterUpload()
        else PDI.Msg("This uploads your data to esopvp.com, then clears it from this PC (it stays on the website). " ..
            "Type |cFFFFFF/lpi clearlocal confirm|r to proceed.") end
    elseif cmd == "resetall" then
        if rest == "confirm" then
            PDI.Share:ResetAll(PDI.Now())
            PDI.sv.skillCat, PDI.sv.buffCat = {}, {}     -- right-click skill/buff type changes too
            PDI.Msg("Everything collected on this PC was deleted (saved builds and right-click skill/buff type changes included). " ..
                "Settings are kept. Reloading the UI...")
            zo_callLater(function() ReloadUI("ingame") end, 1500)
        else
            PDI.Msg("This deletes EVERYTHING the addon collected on this PC, saved builds and right-click skill/buff type changes included (settings are kept). " ..
                "Type |cFFFFFF/lpi resetall confirm|r to proceed.")
        end
    elseif cmd == "recap" then
        if PDI.Recap.last then PDI.UI:ShowRecap(PDI.Recap.last)
        elseif not PDI.Recap:IsOn() then PDI.Msg("Real Death Recap is off - switch it on in the addon settings.")
        else PDI.Msg("No death recorded yet.") end
    elseif cmd == "minelog" then
        -- the last kill / assist decisions (to find wrong counts): time, K/A, source, victim, result
        local l = PDI.sv.mineLog or {}
        local n = tonumber(rest) or 10
        if #l == 0 then PDI.Msg("No kill/assist decisions logged yet.") end
        for i = math.max(1, #l - n + 1), #l do
            local e = l[i]
            PDI.Msg(string.format("%s %s ms=%s [%s] %s / %s -> %s", os.date("%H:%M:%S", e.t or 0),
                e.f == "k" and "KILL" or "ASSIST", tostring(e.ms or "?"), tostring(e.src or (e.feed and "feed" or "?")),
                tostring(e.c or "-"), tostring(e.a or "-"), tostring(e.r or "?")))
        end
    elseif cmd == "link" then
        PDI.Link:InsertSelected()
    elseif cmd == "settings" or cmd == "open" or cmd == "options" then
        PDI.Settings:Open()
    elseif cmd == "cleargroup" then
        if rest == "confirm" then PDI.UI:ClearGroup()
        else PDI.Msg("This deletes the whole Group tab (saved builds are kept). Type |cFFFFFF/lpi cleargroup confirm|r to proceed.") end
    elseif cmd == "skillreset" then
        PDI.sv.skillCat = {}
        PDI.sv.buffCat = {}
        PDI.Msg("Your skill and buff type corrections (right-click changes) were cleared.")
        PDI.UI:RefreshIfVisible()
    elseif cmd == "importcheck" then
        PDI.Import:ResolveAnon()
        PDI.Import:PrintDiagnostics()
    elseif cmd == "keybinds" then
        PDI.Keybinds:PrintDiagnostics()
    elseif cmd == "lamcheck" then
        PDI.Settings:PrintDiagnostics()
    elseif cmd == "capture" then
        PDI.LogAssist:Capture(rest)
    elseif cmd == "autolog" then
        if rest == "always" then rest = "auto" end
        if rest == "auto" or rest == "ask" or rest == "never" then PDI.sv.settings.autoLog = rest end
        PDI.Msg("Encounter log when grouped: |cFFFFFF" .. PDI.sv.settings.autoLog .. "|r  (auto | ask | never)")
        PDI.LogAssist:Evaluate()
    elseif cmd == "popup" then
        PDI.sv.settings.importPopup = (rest == "on") or (rest ~= "off" and not PDI.sv.settings.importPopup)
        PDI.Msg("Import window after a captured fight: " .. onOff(PDI.sv.settings.importPopup))
    elseif cmd == "deletelog" then
        PDI.LogAssist:DeleteLog()
    elseif cmd == "import" then
        PDI.LogAssist:ShowImportWindow()
    elseif cmd == "logpath" then
        if rawRest ~= "" then PDI.sv.settings.logPath = (rawRest == "default") and nil or rawRest end
        PDI.Msg("Encounter log path: |cFFFFFF" .. PDI.LogAssist:LogPath() .. "|r")
    elseif cmd == "foodcheck" then
        PDI.Quests:FoodCheck(true)
    elseif cmd == "status" then
        PDI.Msg(string.format("v%s | in PvP area: %s | tracking: %s | notify: %s | pvp-only: %s",
            PDI.version, onOff(PDI.InPvPArea()), onOff(PDI.ShouldTrack()),
            onOff(PDI.sv.settings.chatNotify), onOff(PDI.sv.settings.onlyPvP)))
        PDI.Msg(string.format("Stored: %d kill days, %d feed days, %d opponent days, %d saved, %d known names",
            count(PDI.sv.my), count(PDI.sv.feed), count(PDI.sv.opponents), count(PDI.sv.saved), count(PDI.sv.names)))
        PDI.Msg(string.format("Group history: %d/%d accounts, %d saved builds",
            count(PDI.sv.group), PDI.GROUP_HISTORY_MAX, count(PDI.sv.savedBuilds)))
        PDI.Msg(string.format("Encounter-log builds loaded: %d (imported %s)",
            count(PDI.Import.builds), PDI.Import.generated > 0 and PDI.FormatTime(PDI.Import.generated) or "never"))
        PDI.Msg("LPI Companion at the last UI load: " .. PDI.LogAssist:CompanionState())
        do
            local comp = PVPDataInsight_Companion or {}
            local up = type(comp.upload) == "table" and comp.upload or {}
            PDI.Msg(string.format("Companion: %s edition, last upload %s (%s: %s) | server reset: %s | reset applied here: %s",
                tostring(comp.edition or "?"), (tonumber(up.t) or 0) > 0 and PDI.FormatTime(up.t) or "never",
                up.ok and "ok" or "failed", tostring(up.msg or "-"),
                tonumber(comp.reset) and PDI.FormatTime(comp.reset) or "not received",
                tonumber(PDI.sv.resetSeen) and PDI.FormatTime(PDI.sv.resetSeen) or "no"))
        end
        local ne, nd = PDI.Data:CountKillEvents()
        PDI.Msg(string.format("Kill event log: %d kill(s) over %d day(s), kept %d days", ne, nd,
            tonumber(PDI.sv.settings.killEventDays) or 7))
        PDI.Msg(string.format("Encounter log: %s%s | when grouped: %s | import window: %s",
            onOff(PDI.LogAssist:IsOn()), PDI.LogAssist.ownedByUs and string.format(" (%s mode, %d captured, %d still needed)",
                PDI.LogAssist.mode or "?", count(PDI.LogAssist.covered), #PDI.LogAssist:Missing()) or "",
            PDI.sv.settings.autoLog, onOff(PDI.sv.settings.importPopup)))
    else
        PDI.Msg("Commands: /lpi (toggle window), /lpi settings, /lpi status, /lpi notify [on|off], " ..
            "/lpi pvponly [on|off], /lpi capture [seconds|off], /lpi autolog [auto|ask|never], " ..
            "/lpi popup [on|off], /lpi import, /lpi deletelog, /lpi importcheck, /lpi skillreset, /lpi buffhours [1-168], /lpi groupscope pvp|pve|both, /lpi killdays [1-60], /lpi logpath [path|default], /lpi reset (session), /lpi wipe, /lpi clearlocal, /lpi resetall, /lpi minelog [n], /lpi recap, /lpi link (selected build into chat), /lpi foodcheck")
        PDI.Msg("PvP tools: /lpi fps (status), /lpi pvp <fps>, /lpi pve <fps>, /lpi zonelimits, /lpi bg, /lpi perf, /lpi perfview <0.4-2.0>, /lpi perfrestore, " ..
            "/lpi autoaccept, /lpi notifyblock, /lpi notifyultimate, /lpi critdelay, /lpi critaoe, /lpi breakfree, /lpi blocking, /lpi leadermarker, /lpi quickslots, /lpi debug")
    end
end

local lastPruneDay
local toldUpdate = false
local function OnPlayerActivated()
    pcall(PDI.Share.RecordMe, PDI.Share)
    if not toldUpdate then
        toldUpdate = true
        local ok, newer = pcall(PDI.Share.NewerAddon, PDI.Share)
        if ok and newer and PDI.sv.settings.updateNotice ~= false then
            zo_callLater(function()
                PDI.Msg(string.format("|cFFCC66A new version of Lethal PVP Insights is available: %s|r (you have %s). " ..
                    "Update it with Minion, or download it from ESOUI or esopvp.com.", newer, PDI.version))
            end, 6000)
        end
    end
    local today = PDI.DateKey()
    if lastPruneDay ~= today then
        PDI.Data:Prune()
        lastPruneDay = today
    end
end

local function OnLoaded(_, addonName)
    if addonName ~= PDI.name then return end
    EM:UnregisterForEvent(PDI.name, EVENT_ADD_ON_LOADED)

    PDI.sv = ZO_SavedVars:NewAccountWide("PVPDataInsight_SV", 1, nil, PDI.defaults)
    -- the addon was renamed (folder PVPDataInsight -> LethalPVPInsights): the old copy must go
    pcall(function()
        local AM = GetAddOnManager()
        for i = 1, AM:GetNumAddOns() do
            local name, _, _, _, enabled = AM:GetAddOnInfo(i)
            if name == "PVPDataInsight" and enabled then
                zo_callLater(function()
                    PDI.Msg("|cFF6655The old PVPDataInsight addon folder is still installed.|r Delete AddOns\\PVPDataInsight " ..
                            "(Lethal PVP Insights replaces it) and /reloadui - running both mixes up your data.")
                end, 4000)
            end
        end
    end)
    -- ZO_SavedVars only fills in missing keys, so a changed default needs a one-time migration:
    -- v1.3 saved autoLog = "ask" for everyone; v1.4+ defaults to automatic capture.
    if not PDI.sv.settings.migratedAutoLog then
        if PDI.sv.settings.autoLog == "ask" or PDI.sv.settings.autoLog == "always" then PDI.sv.settings.autoLog = "auto" end
        PDI.sv.settings.migratedAutoLog = true
    end
    PDI.sv.logCoverage = PDI.sv.logCoverage or {}
    if not PDI.sv.settings.cleanedOpponents16 then
        local n = PDI.Data:CleanupOpponents()
        PDI.sv.settings.cleanedOpponents16 = true
        if n > 0 then PDI.Msg(string.format("Removed %d non-enemy entries (group members / friendly buffs) from Opponents.", n)) end
    end
    PDI.Data:Prune()
    lastPruneDay = PDI.DateKey()
    -- Following: daily snapshots of followed players (written again every minute while you play)
    pcall(PDI.Data.MigrateFollows, PDI.Data)
    pcall(PDI.Data.PruneFollows, PDI.Data)
    EM:RegisterForUpdate(PDI.name .. "Follows", 60000, function() pcall(PDI.Data.SyncFollows, PDI.Data) end)
    if EVENT_PLAYER_DEACTIVATED then        -- logout / reload: write the last minute too before the game saves
        EM:RegisterForEvent(PDI.name .. "Follows", EVENT_PLAYER_DEACTIVATED, function() pcall(PDI.Data.SyncFollows, PDI.Data) end)
    end
    if not PDI.sv.settings.fixedDoubleAssists then
        local ok, n = pcall(PDI.Data.FixDoubleAssists, PDI.Data)
        PDI.sv.settings.fixedDoubleAssists = true
        if ok and n and n > 0 then
            zo_callLater(function()
                PDI.Msg(string.format("Fixed %d assist(s) that were counted together with your own kill on the same player.", n))
            end, 3000)
        end
    end

    PDI.Share:CheckPendingClear()      -- before the modules start, so they only see the cleared data
    pcall(PDI.Share.KeepSaved, PDI.Share)   -- keep shared data of saved players before a new download replaces it
    PDI.Tracker:Init()
    pcall(PDI.Recap.Init, PDI.Recap)    -- Real Death Recap (only listens while switched on)
    pcall(PDI.AP.Init, PDI.AP)          -- Alliance Points history
    pcall(PDI.Keybinds.Init, PDI.Keybinds) -- our keybind category first under Addon Keybinds
    for _, m in ipairs({ PDI.SkillBlocker, PDI.Quests }) do
        local ok, err = pcall(m.Init, m)
        if not ok then PDI.Msg("Init error: " .. tostring(err)) end
    end
    PDI.Group:Init()
    PDI.Import:Init()
    PDI.LogAssist:Init()
    PDI.Settings:Init()
    PDI.UI:Init()
    pcall(PDI.Link.Init, PDI.Link)      -- build links in chat
    zo_callLater(function() pcall(PDI.Data.SyncFollows, PDI.Data) end, 5000)

    EM:RegisterForEvent(PDI.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    -- prune once an hour too, so a long session crossing midnight stays within retention
    EM:RegisterForUpdate(PDI.name .. "Prune", 3600000, OnPlayerActivated)

    -- /lpi runs everything; the PvP tools' commands (FPS limits, alerts, leader marker...) are passed on to them
    local TOOLS = { debug = 1, reapply = 1, zonelimits = 1, pvp = 1, pve = 1, bg = 1, perf = 1, perfview = 1,
        perfrestore = 1, autoaccept = 1, notifyblock = 1, notifyultimate = 1, critdelay = 1, critaoe = 1,
        breakfree = 1, blocking = 1, leadermarker = 1, quickslots = 1, fps = 1 }
    local function LPISlash(arg)
        local cmd, rest = zo_strtrim(arg or ""):match("^(%S*)%s*(.-)$")
        cmd = string.lower(cmd or "")
        if TOOLS[cmd] and LPI_PvPTools and LPI_PvPTools.Slash then
            if cmd == "fps" then return LPI_PvPTools.Slash("status") end
            return LPI_PvPTools.Slash(arg)
        end
        return Slash(arg)
    end
    SLASH_COMMANDS["/lpi"] = LPISlash
    SLASH_COMMANDS["/pvpdi"] = LPISlash            -- the old name keeps working
    SLASH_COMMANDS["/pvpdatainsight"] = LPISlash
end

EM:RegisterForEvent(PDI.name, EVENT_ADD_ON_LOADED, OnLoaded)
