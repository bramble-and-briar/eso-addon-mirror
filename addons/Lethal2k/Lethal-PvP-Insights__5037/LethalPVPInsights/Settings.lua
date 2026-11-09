-- Lethal PVP Insights - Settings panel (LibAddonMenu-2.0)
-- Same approach as PvP FPS Limiter:
--  * LibAddonMenu-2.0 is an OPTIONAL dependency - every setting also has a /pvpdi command
--  * look for the LibAddonMenu2 global first (LibStub is optional nowadays), LibStub as fallback
--  * registration is wrapped in pcall and retried on EVENT_PLAYER_ACTIVATED, because some load
--    orders / addon managers make LAM look missing at EVENT_ADD_ON_LOADED time
--  * no panelData.slashCommand (it would clash with /pvpdi) - /pvpdi settings opens the panel
--    with LAM:OpenToPanel() instead, and /pvpdi lamcheck prints diagnostics
local PDI = PVPDataInsight
local S = {}
PDI.Settings = S

local PANEL_NAME = "PVPDataInsightOptions"
S.diagnostics = nil
S.triedOnce = false

local function GetLAM()
    local LAM = LibAddonMenu2
    local viaLibStub = false
    if not LAM and LibStub then
        LAM = LibStub("LibAddonMenu-2.0", true)
        viaLibStub = LAM ~= nil
    end
    return LAM, viaLibStub
end

local function sv() return PDI.sv.settings end

local function refreshUI()
    if PDI.UI and PDI.UI.RefreshIfVisible then PDI.UI:RefreshIfVisible() end
end

local function BuildOptions()
    local opts = {
        { type = "header", name = "General" },
        {
            type = "button", name = "Open Lethal PVP Insights", width = "half",
            tooltip = "Opens the main window (same as /pvpdi or the keybind).",
            func = function() PDI.UI:Show() end,
        },
        {
            type = "button", name = "Reset session counters", width = "half",
            tooltip = "Clears the 'Session' period of My Kills and Kill Feed.",
            func = function() PDI.Data:ResetSession(); PDI.Msg("Session counters reset."); refreshUI() end,
        },
        {
            type = "checkbox", name = "Track only in PvP areas",
            tooltip = "Record kills, opponents and group builds only in Cyrodiil, Imperial City and Battlegrounds.",
            getFunc = function() return sv().onlyPvP end,
            setFunc = function(v) sv().onlyPvP = v end,
            default = PDI.defaults.settings.onlyPvP,
        },
        {
            type = "checkbox", name = "Real Death Recap",
            tooltip = "When you die in a PvP area (Cyrodiil, Imperial City, Battlegrounds), shows the 5 skills/players that did the most damage to you in that fight and the " ..
                      "last 10 hits before death. /pvpdi recap shows the last one again.",
            getFunc = function() return sv().deathRecap == true end,
            setFunc = function(v) PDI.Recap:SetOn(v) end,
            default = PDI.defaults.settings.deathRecap,
        },
        {
            type = "checkbox", name = "New version notice",
            tooltip = "Tells you in chat (and next to the window title) when a newer Lethal PVP Insights is available " ..
                      "on esopvp.com. Needs the LPI Companion with uploads on.",
            getFunc = function() return sv().updateNotice ~= false end,
            setFunc = function(v) sv().updateNotice = v and true or false end,
            default = PDI.defaults.settings.updateNotice,
        },
        {
            type = "checkbox", name = "Chat message on kills and assists",
            tooltip = "Prints a line in chat for each of your killing blows and assists.",
            getFunc = function() return sv().chatNotify end,
            setFunc = function(v) sv().chatNotify = v end,
            default = PDI.defaults.settings.chatNotify,
        },

        {
            type = "dropdown", name = "Group history: record groups in",
            tooltip = "Where the Group tab records the players you group with (and where the encounter log is switched on " ..
                "to capture their gear):\nPvP - Cyrodiil, Imperial City and Battlegrounds\nPvE - everywhere else\nBoth - everywhere",
            choices = { "PvP", "PvE", "Both" },
            choicesValues = { "pvp", "pve", "both" },
            getFunc = function() return sv().groupScope or "pvp" end,
            setFunc = function(v) sv().groupScope = v; PDI.Group:Scan(); PDI.LogAssist:Evaluate(); refreshUI() end,
            default = PDI.defaults.settings.groupScope,
        },
        {
            type = "slider", name = "Kill feed event log: keep (days)",
            tooltip = "Every kill feed message is stored as its own record (time, campaign, location, killer and victim). " ..
                "Older days are deleted automatically.",
            min = 1, max = 60, step = 1,
            getFunc = function() return tonumber(sv().killEventDays) or 7 end,
            setFunc = function(v) sv().killEventDays = v; PDI.Data:Prune() end,
            default = PDI.defaults.settings.killEventDays,
        },
        {
            type = "slider", name = "Friendly player buffs: collect for (hours)",
            tooltip = "When you target a player, the buffs you see are added to what was already collected for them " ..
                "(no duplicates). After this many hours the next look starts a fresh list.",
            min = 1, max = 168, step = 1,
            getFunc = function() return tonumber(sv().buffWindowHours) or 36 end,
            setFunc = function(v) sv().buffWindowHours = v end,
            default = PDI.defaults.settings.buffWindowHours,
        },

        { type = "header", name = "Gear & skill bars (encounter log)" },
        {
            type = "description",
            text = "While you're grouped in a PvP area, the addon can switch the game's encounter log on, " ..
                "capture your group members' gear and skill bars at the next fight, then switch it off and " ..
                "pop up the import window. Keep 'LPI COMPANION.bat' running on your desktop to import with one click.",
        },
        {
            type = "dropdown", name = "Encounter log while grouped",
            tooltip = "Automatic: switch on/off by itself.\nAsk first: show a prompt before switching on.\nNever: only manually (/pvpdi capture).",
            choices = { "Automatic", "Ask first", "Never" },
            choicesValues = { "auto", "ask", "never" },
            getFunc = function() return sv().autoLog end,
            setFunc = function(v) sv().autoLog = v; PDI.LogAssist:Evaluate() end,
            default = PDI.defaults.settings.autoLog,
        },
        {
            type = "checkbox", name = "Show import window after a capture",
            tooltip = "When the log is switched off after capturing gear, open a window with the Encounter.log path and a Reload UI button.",
            getFunc = function() return sv().importPopup end,
            setFunc = function(v) sv().importPopup = v end,
            default = PDI.defaults.settings.importPopup,
        },
        {
            type = "editbox", name = "Encounter.log path", isMultiline = false, width = "full",
            tooltip = "Only needed if your Documents folder is somewhere else (e.g. OneDrive). Leave empty for the default:\n" ..
                "%USERPROFILE%\\Documents\\Elder Scrolls Online\\live\\Logs\\Encounter.log",
            getFunc = function() return sv().logPath or "" end,
            setFunc = function(v) v = zo_strtrim(v or ""); sv().logPath = (v ~= "") and v or nil end,
            default = "",
        },
        {
            type = "button", name = "Capture now", width = "half",
            tooltip = "Switch the encounter log on until the end of your next fight.",
            func = function() PDI.LogAssist:Capture(nil) end,
        },
        {
            type = "button", name = "Delete Encounter.log", width = "half",
            tooltip = "Asks the LPI Companion to delete Encounter.log. Gear already imported is kept. " ..
                "The Companion can also do this automatically after each import (tick 'Delete log after import' in its window).",
            func = function() PDI.LogAssist:DeleteLog() end,
        },
        {
            type = "button", name = "Open import window", width = "half",
            func = function() PDI.LogAssist:ShowImportWindow() end,
        },

        { type = "header", name = "Data sharing (esopvp.com)" },
        {
            type = "description",
            text = "The LPI Companion uploads your LPI data to esopvp.com after each /reloadui or logout - only if you " ..
                "agreed in the Companion. Choose who may see each kind below. Opponents' combat data and the kill " ..
                "feed are always used for the public stats.",
        },
        {
            type = "description",
            title = "Your Identifier",
            text = function()
                local ident, up = PDI.Share:UploadInfo()
                local s = ident and ident ~= "" and ("|cFFFFFF" .. ident .. "|r  - enter it when you register on esopvp.com")
                    or "|c999999Not registered yet: start the LPI Companion and agree to upload.|r"
                if up then
                    s = s .. "\nLast upload: " .. (up.ok and "|c66DD66OK|r" or "|cFF6655failed|r") ..
                        (up.t and up.t > 0 and (" " .. PDI.FormatTime(up.t)) or "") ..
                        (up.msg and up.msg ~= "" and (" - " .. up.msg) or "")
                end
                return s
            end,
        },
    }
    for _, cat in ipairs(PDI.Share.CATEGORIES) do
        opts[#opts + 1] = {
            type = "dropdown", name = cat.label,
            tooltip = cat.tooltip .. "\nAll - everyone\nYour Faction - players of your alliance\nGuild Members - members of " ..
                "the guilds you tick below\nFriends - your friends list\nNone - don't share\n\nDefault: " .. (cat.default == "faction" and "Your Faction" or "Friends"),
            choices = PDI.Share.MODE_LABELS, choicesValues = PDI.Share.MODES,
            getFunc = function() return PDI.Share:Get(cat.key).mode end,
            setFunc = function(v) PDI.Share:SetMode(cat.key, v) end,
            default = cat.default,
        }
        -- five slots, one per guild you can be in (names are looked up when the panel is shown)
        local guildControls = {}
        for slot = 1, PDI.Share.MAX_GUILDS do
            guildControls[#guildControls + 1] = {
                type = "checkbox",
                name = function() local g = PDI.Share:GuildAt(slot); return g and g.name or ("Guild " .. slot .. " (not in a guild)") end,
                getFunc = function() local g = PDI.Share:GuildAt(slot); return g ~= nil and PDI.Share:Get(cat.key).guilds[g.id] == true end,
                setFunc = function(v)
                    local g = PDI.Share:GuildAt(slot)
                    if g then PDI.Share:Get(cat.key).guilds[g.id] = v or nil end
                end,
                disabled = function() return PDI.Share:Get(cat.key).mode ~= "guild" or PDI.Share:GuildAt(slot) == nil end,
            }
        end
        opts[#opts + 1] = { type = "submenu", name = cat.label .. ": guilds", controls = guildControls,
                            tooltip = "Used when " .. cat.label .. " is set to Guild Members." }
    end
    for _, o in ipairs({
        { type = "header", name = "Data" },
        {
            type = "description",
            text = "Opponent combat data is kept for 7 days, daily kill counts for 70 days, group history for the last " ..
                PDI.GROUP_HISTORY_MAX .. " accounts. Saved opponents and saved builds are kept until you delete them.",
        },
        {
            type = "button", name = "Clear group history", width = "half", isDangerous = true,
            warning = "Deletes all players from the Group tab, including gear and skill bars imported from the encounter log. Saved builds are kept.",
            func = function() PDI.UI:ClearGroup() end,
        },
        {
            type = "button", name = "Upload, then clear local data", width = "half", isDangerous = true,
            tooltip = "Saves and uploads everything to esopvp.com, then clears it from this PC: kill counts, kill feed, " ..
                "opponents, group history and friendly players. It all stays on esopvp.com. " ..
                "Saved builds and settings are kept. Needs the LPI Companion with uploads on.",
            warning = "Reloads the UI to save and upload first. The local data is cleared once the upload is confirmed " ..
                "(usually at the next /reloadui).",
            func = function() PDI.Share:RequestClearAfterUpload() end,
        },
        {
            type = "button", name = "Wipe all data", width = "half", isDangerous = true,
            warning = "Deletes all kill counters, kill feed, opponent data and group history. Saved opponents and saved builds are kept.",
            func = function() PDI.WipeAll() end,
        },
    }) do opts[#opts + 1] = o end
    return opts
end

-- Safe to call more than once: no-op once registered; otherwise retries.
function S:Create()
    if self.diagnostics and self.diagnostics.panelRegistered then return end

    local keyboardUI = IsKeyboardUISupported and IsKeyboardUISupported()
    local LAM, viaLibStub = GetLAM()
    self.diagnostics = {
        libAddonMenu2Found = LibAddonMenu2 ~= nil,
        libStubFound = LibStub ~= nil,
        lamFound = LAM ~= nil,
        foundVia = LAM and (viaLibStub and "LibStub" or "LibAddonMenu2 global") or nil,
        keyboardUI = keyboardUI,
        panelRegistered = false,
        lastError = nil,
    }

    if not LAM then
        if not self.triedOnce then
            self.triedOnce = true
        else
            PDI.Msg("LibAddonMenu-2.0 not found, so there's no Settings panel. Install it, or use /pvpdi commands " ..
                "(/pvpdi help). Run /pvpdi lamcheck for details.")
        end
        return
    end

    if keyboardUI == false then
        PDI.Msg("Gamepad-mode UI detected: LibAddonMenu's Settings panel only shows in keyboard mode. Use /pvpdi commands instead.")
    end

    local panelData = {
        type = "panel",
        name = PDI.displayName,
        displayName = PDI.displayName,
        author = "Lethal2k",
        version = PDI.version,
        registerForRefresh = true,
        registerForDefaults = true,
    }
    local ok, panelOrErr = pcall(function() return LAM:RegisterAddonPanel(PANEL_NAME, panelData) end)
    if not ok then
        self.diagnostics.lastError = tostring(panelOrErr)
        PDI.Msg("RegisterAddonPanel failed: " .. tostring(panelOrErr))
        return
    end
    self.panel = panelOrErr

    local ok2, err2 = pcall(function() LAM:RegisterOptionControls(PANEL_NAME, BuildOptions()) end)
    if not ok2 then
        self.diagnostics.lastError = tostring(err2)
        PDI.Msg("RegisterOptionControls failed: " .. tostring(err2))
        return
    end
    self.diagnostics.panelRegistered = true
end

function S:Open()
    local LAM = GetLAM()
    if LAM and self.panel then
        LAM:OpenToPanel(self.panel)
    elseif LAM then
        PDI.Msg("LibAddonMenu-2.0 is loaded, but the panel hasn't registered yet. Run /pvpdi lamcheck for details.")
    else
        PDI.Msg("LibAddonMenu-2.0 isn't installed, so there's no Settings panel. Use /pvpdi help for commands.")
    end
end

function S:PrintDiagnostics()
    local diag = self.diagnostics or {}
    PDI.Msg(string.format("LibAddonMenu2 global: %s | LibStub: %s | LAM found: %s (via %s) | Keyboard UI: %s | Panel registered: %s%s",
        tostring(diag.libAddonMenu2Found), tostring(diag.libStubFound), tostring(diag.lamFound), tostring(diag.foundVia),
        tostring(diag.keyboardUI), tostring(diag.panelRegistered),
        diag.lastError and (" | Last error: " .. diag.lastError) or ""))
end

function S:Init()
    self:Create()
    EVENT_MANAGER:RegisterForEvent(PDI.name .. "_Settings", EVENT_PLAYER_ACTIVATED, function()
        S:Create()
        if S.diagnostics and S.diagnostics.panelRegistered then
            EVENT_MANAGER:UnregisterForEvent(PDI.name .. "_Settings", EVENT_PLAYER_ACTIVATED)
        end
    end)
end
