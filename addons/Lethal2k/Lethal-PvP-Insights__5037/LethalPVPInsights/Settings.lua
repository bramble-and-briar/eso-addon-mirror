-- Lethal PVP Insights - settings: the option list, shown in the addon's own entry of the game's Settings
-- menu (SettingsPanel.lua draws it; no LibAddonMenu needed). Every setting also has a /lpi command.
local PDI = PVPDataInsight
local S = {}
PDI.Settings = S

local PANEL_NAME = "PVPDataInsightOptions"
S.diagnostics = nil
S.triedOnce = false


local function sv() return PDI.sv.settings end

local function refreshUI()
    if PDI.UI and PDI.UI.RefreshIfVisible then PDI.UI:RefreshIfVisible() end
end

-- General: the window, update notice and death recap
local function GeneralLPI()
    return {
        { type = "header", name = "Lethal PVP Insights" },
        {
            type = "button", name = "Open Lethal PVP Insights", width = "half",
            tooltip = "Opens the main window (same as /lpi or the keybind).",
            func = function() PDI.UI:Show() end,
        },
        {
            type = "button", name = "Get the LPI Companion", width = "half",
            tooltip = "Opens esopvp.com/companion in your browser (the game asks first). The Companion is an optional " ..
                "Windows helper: it imports group members' gear and skill bars from Encounter.log and, only if you " ..
                "agree, uploads your data to esopvp.com. It isn't part of the addon download.",
            func = function() PDI.OpenCompanionPage() end,
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
            type = "checkbox", name = "Real Death Recap",
            tooltip = "When you die in a PvP area (Cyrodiil, Imperial City, Battlegrounds), shows the 5 skills/players that did the most damage to you in that fight and the " ..
                      "last 20 hits before death. Set a key under Controls > Addon Keybinds > Lethal PVP Insights to show or hide it " ..
                      "(like the game's own death recap); /lpi recap shows the last one again.",
            getFunc = function() return sv().deathRecap == true end,
            setFunc = function(v) PDI.Recap:SetOn(v) end,
            default = PDI.defaults.settings.deathRecap,
        },
    }
end

-- Data Handling: everything about recording, importing and sharing the data
local function BuildOptions()
    local LA = PDI.LogAssist
    local opts = {
        { type = "header", name = "What LPI records" },
        {
            type = "description",
            text = "Your kills and assists, the kill feed, what enemy players hit you with, and the players you group with. " ..
                "It all stays on your PC unless you choose to upload it with the LPI Companion (see Data sharing below).",
        },
        {
            type = "checkbox", name = "Record only in PvP areas",
            tooltip = "ON: kills, opponents and group builds are recorded only in Cyrodiil, Imperial City and Battlegrounds.\n" ..
                "OFF: everywhere (duels and PvE included).",
            getFunc = function() return sv().onlyPvP end,
            setFunc = function(v) sv().onlyPvP = v end,
            default = PDI.defaults.settings.onlyPvP,
        },
        {
            type = "dropdown", name = "Remember players I group with",
            tooltip = "Where the Group tab records your group members (and where their gear may be captured).",
            choices = { "In PvP areas", "Outside PvP areas", "Everywhere" },
            choicesValues = { "pvp", "pve", "both" },
            getFunc = function() return sv().groupScope or "pvp" end,
            setFunc = function(v) sv().groupScope = v; PDI.Group:Scan(); PDI.LogAssist:Evaluate(); refreshUI() end,
            default = PDI.defaults.settings.groupScope,
        },
        {
            type = "checkbox", name = "Chat message on my kills and assists",
            tooltip = "Prints a line in chat for each of your killing blows and assists.",
            getFunc = function() return sv().chatNotify end,
            setFunc = function(v) sv().chatNotify = v end,
            default = PDI.defaults.settings.chatNotify,
        },
        {
            type = "button", name = "Reset session counters", width = "half",
            tooltip = "Starts the 'Session' period of My Kills, Kill Feed and Alliance Points from zero.",
            func = function() PDI.Data:ResetSession(); PDI.Msg("Session counters reset."); refreshUI() end,
        },

        { type = "header", name = "Group members' gear & skill bars" },
        {
            type = "description",
            text = "The game writes other players' gear and skill bars only into its encounter log (Encounter.log). " ..
                "LPI can switch that log on for a short time while you're grouped, capture your group members at the " ..
                "next fight, and switch it off again. The LPI Companion (optional, separate download) then imports it.",
        },
        {
            type = "dropdown", name = "Switch the encounter log on",
            tooltip = "Automatically: by itself when group members are missing gear; off again once they're captured.\n" ..
                "Ask me first: LPI asks you each time.\nOnly with Capture now: never by itself.",
            choices = { "Automatically", "Ask me first", "Only with Capture now" },
            choicesValues = { "auto", "ask", "never" },
            getFunc = function() return sv().autoLog end,
            setFunc = function(v) sv().autoLog = v; PDI.LogAssist:Evaluate() end,
            default = PDI.defaults.settings.autoLog,
        },
        {
            type = "description",
            text = function()
                local mode = sv().autoLog
                local what = mode == "ask" and "|cFFFFFFAsk me first:|r when group members are missing gear, LPI asks before switching the log on."
                    or mode == "never" and "|cFFFFFFOnly with Capture now:|r LPI never switches the log on by itself. Click Capture now (or /lpi capture) before a fight."
                    or "|cFFFFFFAutomatically:|r when group members are missing gear, LPI switches the log on, and off again once they are captured (at most 10 minutes)."
                local now
                if LA:IsOn() then
                    now = LA.ownedByUs and "|c66DD66ON|r - switched on by LPI, which switches it off again."
                        or "|c66DD66ON|r - switched on by you or another addon. LPI leaves it on."
                else
                    now = "|c999999off|r"
                end
                return what .. "\n\n|cFFFFFFAlready logging yourself?|r If the encounter log was on before LPI needed it " ..
                    "(for example you upload your fights to esologs.com), LPI never switches it off, and the Companion " ..
                    "never deletes it.\nEncounter log right now: " .. now
            end,
        },
        {
            type = "checkbox", name = "Show the import window after a capture",
            tooltip = "After a capture, opens a small window with an Upload button (sends the log to the Companion) and Reload UI.",
            getFunc = function() return sv().importPopup end,
            setFunc = function(v) sv().importPopup = v end,
            default = PDI.defaults.settings.importPopup,
        },
        {
            type = "button", name = "Capture now", width = "half",
            tooltip = "Switches the encounter log on until the end of your next fight (if it isn't on already).",
            func = function() PDI.LogAssist:Capture(nil) end,
        },
        {
            type = "button", name = "Get the LPI Companion", width = "half",
            tooltip = "Opens esopvp.com/companion in your browser (the game asks first). The Companion is an optional " ..
                "Windows helper: it imports group members' gear and skill bars from Encounter.log and, only if you " ..
                "agree, uploads your data to esopvp.com. It isn't part of the addon download.",
            func = function() PDI.OpenCompanionPage() end,
        },
        {
            type = "submenu", name = "Advanced",
            tooltip = "Rarely needed.",
            controls = {
                {
                    type = "editbox", name = "Encounter.log path", isMultiline = false, width = "full",
                    tooltip = "Only needed if your Documents folder is somewhere else (e.g. OneDrive). Leave empty for the default:\n" ..
                        "%USERPROFILE%\\Documents\\Elder Scrolls Online\\live\\Logs\\Encounter.log",
                    getFunc = function() return sv().logPath or "" end,
                    setFunc = function(v) v = zo_strtrim(v or ""); sv().logPath = (v ~= "") and v or nil end,
                    default = "",
                },
                {
                    type = "button", name = "Open import window", width = "half",
                    func = function() PDI.LogAssist:ShowImportWindow() end,
                },
                {
                    type = "button", name = "Delete Encounter.log", width = "half",
                    tooltip = "Asks the LPI Companion to delete Encounter.log. Gear already imported is kept. If the log " ..
                        "also has logging LPI didn't start, the Companion asks first.",
                    func = function() PDI.LogAssist:DeleteLog() end,
                },
                {
                    type = "slider", name = "Keep kill feed records (days)",
                    tooltip = "Every kill feed message is stored as its own record (time, campaign, location, killer and victim). " ..
                        "Older days are deleted automatically.",
                    min = 1, max = 60, step = 1,
                    getFunc = function() return tonumber(sv().killEventDays) or 7 end,
                    setFunc = function(v) sv().killEventDays = v; PDI.Data:Prune() end,
                    default = PDI.defaults.settings.killEventDays,
                },
                {
                    type = "slider", name = "Collect a player's buffs for (hours)",
                    tooltip = "When you target a player, the buffs you see are added to what was already collected for them " ..
                        "(no duplicates). After this many hours the next look starts a fresh list.",
                    min = 1, max = 168, step = 1,
                    getFunc = function() return tonumber(sv().buffWindowHours) or 36 end,
                    setFunc = function(v) sv().buffWindowHours = v end,
                    default = PDI.defaults.settings.buffWindowHours,
                },
            },
        },

        { type = "header", name = "Data sharing (esopvp.com)" },
        {
            type = "description",
            text = "The LPI Companion uploads your LPI data to esopvp.com after each /reloadui or logout - only if you " ..
                "agreed in the Companion. Below, tick who may see each kind - you can tick several, for example your friends " ..
                "and your guild members. Opponents' combat data and the kill " ..
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
    -- per kind of data: tick every group that may see it (friends AND guild members, for example)
    for _, cat in ipairs(PDI.Share.CATEGORIES) do
        local controls = {}
        for _, g in ipairs(PDI.Share.GROUPS) do
            controls[#controls + 1] = {
                type = "checkbox", name = PDI.Share.GROUP_LABELS[g],
                tooltip = g == "all" and "Everyone signed in on esopvp.com. (Ticking this makes the others unnecessary.)" or nil,
                getFunc = function() return PDI.Share:Has(cat.key, g) end,
                setFunc = function(v) PDI.Share:SetGroup(cat.key, g, v) end,
                disabled = function() return g ~= "all" and PDI.Share:Has(cat.key, "all") end,
            }
        end
        -- one tick box per guild you're in (names are looked up when the panel is shown)
        for slot = 1, PDI.Share.MAX_GUILDS do
            controls[#controls + 1] = {
                type = "checkbox",
                name = function() local g = PDI.Share:GuildAt(slot); return "    " .. (g and g.name or ("Guild " .. slot .. " (not in a guild)")) end,
                getFunc = function() local g = PDI.Share:GuildAt(slot); return g ~= nil and PDI.Share:Get(cat.key).guilds[g.id] == true end,
                setFunc = function(v)
                    local g = PDI.Share:GuildAt(slot)
                    if g then PDI.Share:Get(cat.key).guilds[g.id] = v or nil end
                end,
                disabled = function()
                    return not PDI.Share:Has(cat.key, "guild") or PDI.Share:Has(cat.key, "all") or PDI.Share:GuildAt(slot) == nil
                end,
            }
        end
        opts[#opts + 1] = {
            type = "submenu",
            name = function() return cat.label .. " with:  |c999999" .. PDI.Share:Describe(cat.key) .. "|r" end,
            tooltip = cat.tooltip .. "\nTick every group that may see it. Nothing ticked = nobody.\nDefault: " ..
                (cat.default == "faction" and "players of my faction" or "my friends"),
            controls = controls,
        }
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

-- PvP FPS Limiter options (PvPTools.lua), grouped by their headers
local function toolsBy(...)
    local want, out = {}, {}
    for _, h in ipairs({ ... }) do want[h] = true end
    local ok, opts = pcall(function() return LPI_PvPTools and LPI_PvPTools.GetOptions and LPI_PvPTools.GetOptions() end)
    if not ok or type(opts) ~= "table" then
        return { { type = "description", text = "|cFF6655These options are not available (" .. tostring(opts) .. ").|r" } }
    end
    local keep = false
    for _, o in ipairs(opts) do
        if o.type == "header" then keep = want[o.name] == true end
        if keep then out[#out + 1] = o end
    end
    return out
end

local function join(...)
    local out = {}
    for _, list in ipairs({ ... }) do
        for _, o in ipairs(list or {}) do out[#out + 1] = o end
    end
    return out
end

local function moduleOptions(mod)
    if mod and mod.GetOptions then
        local ok, opts = pcall(mod.GetOptions, mod)
        if ok and type(opts) == "table" then return opts end
        return { { type = "description", text = "|cFF6655Error: " .. tostring(opts) .. "|r" } }
    end
    return {}
end

S.SECTIONS = {
    { name = "Data Handling",   icon = "EsoUI/Art/MainMenu/menuBar_journal_up.dds",
      options = function() return BuildOptions() end },
    { name = "Alerts",          icon = "EsoUI/Art/Miscellaneous/ESO_Icon_Warning.dds",
      options = function()
          local o = toolsBy("PvP Notifications", "Notification Display", "Break Free Alert", "Critical Alerts", "Blocking Alert")
          o[#o + 1] = { type = "header", name = "Alliance Points" }
          o[#o + 1] = { type = "checkbox", name = "Chat line when I earn AP from keeps and resources",
              tooltip = "Writes a line in chat, for example \"+1,250 AP Capturing Chalman Keep\", whenever you get AP for capturing or defending a keep, outpost or resource.",
              getFunc = function() return PDI.sv.settings.apChat == true end,
              setFunc = function(v) PDI.sv.settings.apChat = v end }
          return o
      end },
    { name = "Group Features",  icon = "EsoUI/Art/MainMenu/menuBar_group_up.dds",
      options = function() return toolsBy("Group Leader Marker") end },
    { name = "General",         icon = "EsoUI/Art/Guild/tabIcon_home_up.dds",
      options = function() return join(GeneralLPI(), toolsBy("Campaign Queue"), moduleOptions(PDI.Quests)) end },
    { name = "PvP Performance", icon = "EsoUI/Art/MainMenu/menuBar_ava_up.dds",
      options = function() return toolsBy("Zone FPS Limits", "Performance Boost (PvP Graphics Preset)") end },
    { name = "Quick Slots",     icon = "EsoUI/Art/Inventory/inventory_tabIcon_quickslot_up.dds",
      options = function() return toolsBy("Quickslots") end },
    { name = "Skill Blocker",   icon = "EsoUI/Art/MainMenu/menuBar_skills_up.dds",
      options = function() return moduleOptions(PDI.SkillBlocker) end },
}

-- Settings > Lethal PVP Insights: the addon's own entry in the game's Settings menu (no library needed)
function S:Create()
    if self.created then return end
    local ok, res = pcall(function() return PDI.SettingsPanel:Create(S.SECTIONS) end)
    self.created = ok and res == true
    self.diagnostics = { panelRegistered = self.created, lastError = (not ok) and tostring(res) or nil,
                         keyboardUI = IsKeyboardUISupported and IsKeyboardUISupported() }
    if not ok then PDI.Msg("Settings panel could not be created: " .. tostring(res)) end
end

function S:Open(section)
    if not (self.created and PDI.SettingsPanel:Open(section)) then
        PDI.Msg("The Settings panel isn't available (gamepad mode?). Use /lpi help for commands.")
    end
end

function S:PrintDiagnostics()
    local diag = self.diagnostics or {}
    PDI.Msg(string.format("Settings panel: %s | Keyboard UI: %s%s", tostring(diag.panelRegistered),
        tostring(diag.keyboardUI), diag.lastError and (" | Error: " .. diag.lastError) or ""))
end

function S:Init()
    self:Create()
end
