-- KDStatTracker_ConsoleDialog.lua
-- Gamepad / console stats dialog (LibConsoleDialogs + LibHarvensAddonSettings),
-- the native confirmation / summary dialogs for both platforms, and the
-- platform-neutral open / close entry points used by the rest of the addon.

local KDST = KDStatTracker
local C = KDST.COLORS
local Views = KDST.Views

local console = { pageIndex = 1 }
KDST.consoleDialog = console

-------------------------------------------------------------------------------
-- Native dialogs (keyboard + gamepad variants of each)
-------------------------------------------------------------------------------
local DIALOG_RESET   = "KDSTATTRACKER_RESET"
local DIALOG_SUMMARY = "KDSTATTRACKER_MATCH_SUMMARY"
local DIALOG_QUICK   = "KDSTATTRACKER_QUICK_STATS"
local GAMEPAD_SUFFIX = "_GAMEPAD"

local function RegisterDialogPair(name, def)
    -- keyboard
    local kbButtons = {}
    for i, b in ipairs(def.buttons) do
        kbButtons[i] = { text = b.text, callback = b.callback }
    end
    ZO_Dialogs_RegisterCustomDialog(name, {
        canQueue = true,
        title    = { text = "<<1>>" },
        mainText = { text = "<<1>>" },
        buttons  = kbButtons,
    })

    -- gamepad
    local gpButtons = {}
    for i, b in ipairs(def.buttons) do
        gpButtons[i] = { keybind = b.keybind, text = b.text, callback = b.callback }
    end
    ZO_Dialogs_RegisterCustomDialog(name .. GAMEPAD_SUFFIX, {
        canQueue    = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
        title       = { text = "<<1>>" },
        mainText    = { text = "<<1>>" },
        buttons     = gpButtons,
    })
end

local function ShowPlatformDialog(name, data, title, body)
    local params = { titleParams = { title }, mainTextParams = { body } }
    if KDST.IsGamepadUI() then
        ZO_Dialogs_ShowGamepadDialog(name .. GAMEPAD_SUFFIX, data, params)
    else
        ZO_Dialogs_ShowDialog(name, data, params)
    end
end

local function RegisterDialogs()
    RegisterDialogPair(DIALOG_RESET, {
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_DIALOG_CONFIRM,
                callback = function(dialog)
                    KDST.ResetStats(dialog.data and dialog.data.scope)
                    if console:IsShowing() then console:Refresh() end
                end,
            },
            { keybind = "DIALOG_NEGATIVE", text = SI_DIALOG_CANCEL },
        },
    })

    RegisterDialogPair(DIALOG_SUMMARY, {
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = "View Stats",
                callback = function() KDST.OpenStatsDialog(2) end,
            },
            { keybind = "DIALOG_NEGATIVE", text = SI_DIALOG_CLOSE or "Close" },
        },
    })

    RegisterDialogPair(DIALOG_QUICK, {
        buttons = {
            { keybind = "DIALOG_NEGATIVE", text = SI_DIALOG_CLOSE or "Close" },
        },
    })
end

function KDST.ShowResetDialog(scope)
    local def = KDST.RESET_SCOPES[scope]
    if not def then return end
    ShowPlatformDialog(DIALOG_RESET, { scope = scope }, def.title, zo_strformat(def.text, KDST.charName))
end

function KDST.ShowMatchSummaryDialog(entry)
    local body = table.concat({
        string.format("%s%s", KDST.GetMatchTypeName(entry.matchType), entry.name and (" - " .. entry.name) or ""),
        "",
        string.format("Kills:  %s", KDST.Color(C.kill, entry.kills)),
        string.format("Deaths:  %s", KDST.Color(C.death, entry.deaths)),
        string.format("K/D:  %s", KDST.Color(C.ratio, KDST.Ratio(entry.kills, entry.deaths))),
        string.format("Duration:  %s", KDST.FormatDuration(entry.duration)),
    }, "\n")
    ShowPlatformDialog(DIALOG_SUMMARY, { entry = entry }, "Match Complete", body)
end

-- Fallback for gamepad mode when the console libraries are not installed.
local function ShowQuickStatsDialog()
    local page = Views.Build(1)
    local lines = {}
    for _, card in ipairs(page.cards) do
        lines[#lines + 1] = string.format("%s:  %s", card.label, KDST.Color(card.color or C.text, card.value))
    end
    local session = page.sections[1]
    if session then
        lines[#lines + 1] = ""
        lines[#lines + 1] = KDST.Color(C.accent, zo_strupper(session.title))
        for _, row in ipairs(session.rows) do
            lines[#lines + 1] = string.format("%s:  %s", row.label, row.value)
        end
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = KDST.Color(C.muted, "Install LibConsoleDialogs + LibHarvensAddonSettings for the full stats dialog.")
    ShowPlatformDialog(DIALOG_QUICK, nil, KDST.displayName, table.concat(lines, "\n"))
end

-------------------------------------------------------------------------------
-- Console dialog rendering
-------------------------------------------------------------------------------
local function HasConsoleLibs()
    return LibConsoleDialogs ~= nil and type(LibConsoleDialogs.Create) == "function" and LibHarvensAddonSettings ~= nil
end

local function UseConsoleDialog()
    return KDST.IsGamepadUI() and HasConsoleLibs()
end

local Ctx = {}
Ctx.__index = Ctx

function Ctx:Section(label, tooltip)
    self.dialog:AddSetting({ type = LibHarvensAddonSettings.ST_SECTION, label = label, tooltip = tooltip })
end

-- Read-only rows are no-op buttons so they stay selectable / scrollable with the d-pad.
function Ctx:Stat(text, tooltip)
    self.dialog:AddSetting({
        type = LibHarvensAddonSettings.ST_BUTTON,
        label = text,
        tooltip = tooltip or text,
        clickHandler = function() end,
    })
end

function Ctx:Button(label, tooltip, action, keepOpen)
    self.dialog:AddSetting({
        type = LibHarvensAddonSettings.ST_BUTTON,
        label = label,
        tooltip = tooltip,
        clickHandler = function()
            action()
            local owner = self.owner or console
            if keepOpen ~= false and owner:IsShowing() then owner:Refresh() end
        end,
    })
end

local function StatText(label, value)
    return string.format("%s:  %s", label, value)
end

function console:Populate()
    local dialog = self.dialog
    dialog:Clear()
    local ctx = setmetatable({ dialog = dialog }, Ctx)
    local page = Views.Build(self.pageIndex)
    local count = Views.Count()

    -- Headline numbers
    ctx:Section(string.format("%s  (%d/%d)", page.title, self.pageIndex, count),
        zo_strformat("<<1>>", KDST.charName))
    for _, card in ipairs(page.cards or {}) do
        ctx:Stat(StatText(card.label, KDST.Color(card.color or C.text, card.value)))
    end

    -- Page navigation
    local nextIndex, prevIndex = Views.Wrap(self.pageIndex + 1), Views.Wrap(self.pageIndex - 1)
    ctx:Button(string.format("Next Page:  %s", Views.PAGES[nextIndex].title), "Show the next stats page", function()
        self.pageIndex = nextIndex
    end)
    ctx:Button(string.format("Previous Page:  %s", Views.PAGES[prevIndex].title), "Show the previous stats page", function()
        self.pageIndex = prevIndex
    end)

    -- Page body
    for _, section in ipairs(page.sections or {}) do
        ctx:Section(section.title)
        if #section.rows == 0 then
            ctx:Stat(KDST.Color(C.muted, section.empty or "Nothing here yet."))
        else
            for _, row in ipairs(section.rows) do
                local text = row.value ~= "" and StatText(row.label, row.value) or row.label
                if row.color then text = KDST.Color(row.color, text) end
                ctx:Stat(text, row.tooltip)
            end
        end
    end

    -- Actions
    ctx:Section("Actions")
    ctx:Button("Refresh", "Reload the numbers on this page", function() end)
    ctx:Button(KDST.settings.showHUD and "Hide HUD Tracker" or "Show HUD Tracker", "Toggle the on-screen tracker", function()
        KDST.ToggleHUD()
    end)
    ctx:Button("Duel Lookup", "Search your duel record against other players", function()
        KDST.OpenDuelLookup()
    end, false)
    ctx:Button("Victim Lookup", "Search the players you've killed", function()
        KDST.OpenVictimLookup()
    end, false)
    ctx:Button("Reset Session", "Clear this play session's numbers", function()
        KDST.ShowResetDialog("session")
    end, false)
    ctx:Button("Reset Character", "Clear all saved stats for this character", function()
        KDST.ShowResetDialog("character")
    end, false)
    ctx:Button("Close", "Close the stats dialog", function()
        KDST.CloseStatsDialog()
    end, false)
end

function console:IsShowing()
    local dialog = self.dialog
    return dialog ~= nil
        and dialog.selected == true
        and LibHarvensAddonSettings ~= nil
        and LibHarvensAddonSettings.scene ~= nil
        and LibHarvensAddonSettings.scene:IsShowing()
end

function console:Refresh()
    if not self.dialog then return end
    self:Populate()
    self.dialog:Show()
end

function console:Open(pageIndex)
    if pageIndex then self.pageIndex = Views.Wrap(pageIndex) end
    if not self.dialog then
        self.dialog = LibConsoleDialogs:Create(KDST.displayName)
    end
    self:Populate()
    self.dialog:Show()
end

function console:Close()
    local dialog = self.dialog
    if not dialog then return end
    dialog.selected = false
    if LibHarvensAddonSettings and LibHarvensAddonSettings.scene and LibHarvensAddonSettings.scene:IsShowing() then
        if LibConsoleDialogs and type(LibConsoleDialogs.Close) == "function" then
            LibConsoleDialogs:Close()
        else
            SCENE_MANAGER:HideCurrentScene()
        end
    end
    -- Fresh instance next time avoids stale scene / selection state.
    self.dialog = nil
end

-------------------------------------------------------------------------------
-- Gamepad journal keybind (lets console players open it without chat)
-------------------------------------------------------------------------------
local JOURNAL_SCENES = { "gamepad_journal_root", "gamepad_journal", "gamepad_quest_journal" }

local function RegisterJournalKeybinds()
    if not LibConsoleDialogs or type(LibConsoleDialogs.RegisterKeybind) ~= "function" then return end
    for _, sceneName in ipairs(JOURNAL_SCENES) do
        local scene = SCENE_MANAGER:GetScene(sceneName)
        if scene then
            LibConsoleDialogs:RegisterKeybind(scene, {
                name     = function() return KDST.displayName end,
                tooltip  = function() return "Open KD Stat Tracker" end,
                callback = function() KDST.OpenStatsDialog() end,
                visible  = function() return true end,
                enabled  = function() return true end,
                order    = 2300,
            })
        end
    end
end

-------------------------------------------------------------------------------
-- Search dialogs (console). A search box plus every matching row. Duels and
-- victims each get their own dialog; both search with LibESQL LIKE when it is
-- installed (text matches anywhere in the name; % and _ are literal) and
-- fall back to a Lua substring search otherwise.
-------------------------------------------------------------------------------
local SEARCH_LIST_MAX = 40   -- keep the list short enough to scroll on a pad
local QUICK_LIST_MAX  = 10

local searchDialogs = {}

function KDST.DuelOpponentText(e)
    return string.format("%s  -  %s W / %s L  (W/L %s, %s)", e.name,
        KDST.Color(C.kill, e.wins), KDST.Color(C.death, e.losses),
        KDST.Color(C.ratio, KDST.Ratio(e.wins, e.losses)), KDST.Percent(e.wins, e.wins + e.losses))
end

local SearchDialog = {}
SearchDialog.__index = SearchDialog

-- Same show / refresh / close behaviour as the main console dialog.
function SearchDialog:IsShowing() return console.IsShowing(self) end
function SearchDialog:Refresh() return console.Refresh(self) end
function SearchDialog:Close() return console.Close(self) end

function SearchDialog:Populate()
    local spec, dialog = self.spec, self.dialog
    dialog:Clear()
    local ctx = setmetatable({ dialog = dialog, owner = self }, Ctx)

    ctx:Section(spec.title, zo_strformat("<<1>>", KDST.charName))
    for _, line in ipairs(spec.header()) do ctx:Stat(line) end

    dialog:AddSetting({
        type = LibHarvensAddonSettings.ST_EDIT,
        label = spec.searchLabel,
        tooltip = spec.searchTooltip,
        textType = TEXT_TYPE_ALL,
        maxChars = 32,
        getFunction = function() return self.term end,
        setFunction = function(text)
            self.term = KDST.EscapeSearch(text)
            -- Rebuild after the edit box has finished closing.
            zo_callLater(function() if self.dialog then self:Refresh() end end, 0)
        end,
    })

    local list = spec.lookup(self.term)
    local searching = self.term ~= ""
    ctx:Section(searching and string.format("Matches for \"%s\"  (%d)", self.term, #list)
        or string.format("%s  (%d)", spec.allTitle, #list))
    if #list == 0 then
        ctx:Stat(KDST.Color(C.muted, searching and spec.noMatchText or spec.emptyText))
    end
    for i = 1, math.min(#list, SEARCH_LIST_MAX) do
        local e = list[i]
        ctx:Stat(spec.rowText(e), spec.rowTooltip(e))
    end
    if #list > SEARCH_LIST_MAX then
        ctx:Stat(KDST.Color(C.muted, string.format("...and %d more. Narrow the search.", #list - SEARCH_LIST_MAX)))
    end

    ctx:Section("Actions")
    if searching then
        ctx:Button("Clear Search", "Show everyone", function() self.term = "" end)
    end
    ctx:Button("Open Stats", "Open the main stats dialog", function()
        self:Close()
        zo_callLater(function() KDST.OpenStatsDialog() end, 100)
    end, false)
    ctx:Button("Close", "Close this lookup", function() self:Close() end, false)
end

function SearchDialog:Open(term)
    if term then self.term = KDST.EscapeSearch(term) end
    local function Show()
        if not self.dialog then
            self.dialog = LibConsoleDialogs:Create(KDST.displayName .. " - " .. self.spec.shortTitle)
        end
        self:Populate()
        self.dialog:Show()
    end
    -- Coming from another of our dialogs: let its scene close before opening this one.
    local closedOther = false
    if console.dialog then console:Close(); closedOther = true end
    for _, other in pairs(searchDialogs) do
        if other ~= self and other.dialog then other:Close(); closedOther = true end
    end
    if closedOther then zo_callLater(Show, 100) else Show() end
end

-- Text version for gamepad mode without the console libraries.
function SearchDialog:ShowQuick(term)
    local spec = self.spec
    local list = spec.lookup(term)
    local lines = {}
    for _, line in ipairs(spec.header()) do lines[#lines + 1] = line end
    lines[#lines + 1] = ""
    for i = 1, math.min(#list, QUICK_LIST_MAX) do lines[#lines + 1] = spec.rowText(list[i]) end
    if #list == 0 then lines[#lines + 1] = term ~= "" and spec.noMatchText or spec.emptyText end
    if #list > QUICK_LIST_MAX then lines[#lines + 1] = KDST.Color(C.muted, string.format("...and %d more", #list - QUICK_LIST_MAX)) end
    ShowPlatformDialog(DIALOG_QUICK, nil, term ~= "" and (spec.shortTitle .. ": " .. term) or spec.shortTitle, table.concat(lines, "\n"))
end

-- Opens the best version for the current UI. Returns true if a dialog was
-- shown (false on keyboard UI, where the caller prints to chat).
function SearchDialog:OpenBest(term)
    term = KDST.EscapeSearch(term)
    if UseConsoleDialog() then
        self:Open(term)
        return true
    elseif KDST.IsGamepadUI() then
        self:ShowQuick(term)
        return true
    end
    return false
end

local function NewSearchDialog(key, spec)
    local obj = setmetatable({ term = "", spec = spec }, SearchDialog)
    searchDialogs[key] = obj
    return obj
end


-- Duels ---------------------------------------------------------------------
local duelSearch = NewSearchDialog("duels", {
    title       = "Duel Lookup",
    shortTitle  = "Duels",
    searchLabel = "Search opponent",
    searchTooltip = "Type part of an @account name. Leave empty to list everyone you've dueled.",
    allTitle    = "All opponents",
    emptyText   = "No duels recorded yet.",
    noMatchText = "No duels against anyone matching that.",
    header = function()
        local mine, all = KDST.GetDuelData(), KDST.data.duels or {}
        local function Line(label, w, l)
            return StatText(label, string.format("%s W / %s L  (W/L %s, %s)", KDST.Color(C.kill, w), KDST.Color(C.death, l),
                KDST.Color(C.ratio, KDST.Ratio(w, l)), KDST.Percent(w, w + l)))
        end
        return {
            Line("This character", mine.wins or 0, mine.losses or 0),
            Line("All characters", all.wins or 0, all.losses or 0),
        }
    end,
    -- Empty search lists every opponent: "@" is in every account name.
    lookup = function(term)
        term = term ~= "" and term or "@"
        return KDST.LookupDuelOpponents(term) or KDST.Lookup(term).opponents
    end,
    rowText = KDST.DuelOpponentText,
    rowTooltip = function(e) return string.format("%s\n%d duels, W/L %s", e.name, e.wins + e.losses, KDST.Ratio(e.wins, e.losses)) end,
})
KDST.duelConsole = duelSearch

-- Victims -------------------------------------------------------------------
local victimSearch = NewSearchDialog("victims", {
    title       = "Victim Lookup",
    shortTitle  = "Victims",
    searchLabel = "Search player",
    searchTooltip = "Type part of a character name. Leave empty to list everyone you've killed.",
    allTitle    = "All victims",
    emptyText   = "No player kills recorded yet.",
    noMatchText = "You haven't killed anyone matching that.",
    header = function()
        local mine, data = KDST.GetCharData(), KDST.data
        return {
            StatText("This character", string.format("%s kills / %s deaths  (K/D %s)", KDST.Color(C.kill, mine.kills),
                KDST.Color(C.death, mine.deaths), KDST.Color(C.ratio, KDST.Ratio(mine.kills, mine.deaths)))),
            StatText("All characters", string.format("%s kills / %s deaths  (K/D %s)", KDST.Color(C.kill, data.totalKills or 0),
                KDST.Color(C.death, data.totalDeaths or 0), KDST.Color(C.ratio, KDST.Ratio(data.totalKills, data.totalDeaths)))),
        }
    end,
    lookup = function(term) return KDST.LookupVictims(term) end,
    rowText = function(e) return KDST.VictimText(e) end,
    rowTooltip = function(e) return string.format("%s\nYou killed them %d times, they killed you %d times", e.name, e.kills, e.deaths) end,
})
KDST.victimConsole = victimSearch

function KDST.OpenDuelLookup(term) return duelSearch:OpenBest(term) end
function KDST.OpenVictimLookup(term) return victimSearch:OpenBest(term) end

-------------------------------------------------------------------------------
-- Platform-neutral entry points
-------------------------------------------------------------------------------
function KDST.OpenStatsDialog(pageIndex)
    if UseConsoleDialog() then
        console:Open(pageIndex)
    elseif KDST.IsGamepadUI() then
        ShowQuickStatsDialog()
    else
        KDST.pcDialog:Open(pageIndex)
    end
end

function KDST.CloseStatsDialog()
    if KDST.pcDialog:IsShowing() then KDST.pcDialog:Close() end
    if console.dialog then console:Close() end
    for _, search in pairs(searchDialogs) do
        if search.dialog then search:Close() end
    end
end

function KDST.IsStatsDialogShowing()
    return KDST.pcDialog:IsShowing() or console:IsShowing()
end

function KDST.ToggleStatsDialog(pageIndex)
    if KDST.IsStatsDialogShowing() then
        KDST.CloseStatsDialog()
    else
        KDST.OpenStatsDialog(pageIndex)
    end
end

function KDST.InitializeDialogs()
    RegisterDialogs()
    RegisterJournalKeybinds()

    KDST.callbacks:RegisterCallback("MatchEnded", function(entry)
        if KDST.settings.showMatchSummary and not entry.abandoned then
            -- Let the end-of-match scoreboard settle first.
            zo_callLater(function() KDST.ShowMatchSummaryDialog(entry) end, 2500)
        end
    end)

    -- Switching input mode while a window is open would leave the wrong one up.
    KDST.callbacks:RegisterCallback("PlatformChanged", function()
        KDST.CloseStatsDialog()
    end)
end
