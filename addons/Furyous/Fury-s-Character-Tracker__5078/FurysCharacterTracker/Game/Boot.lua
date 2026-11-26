-- Starting up in game: the saved data, the first read, the windows, key bindings and /fct.
local CT = FurysCharacterTracker
local U = CT.Util
local X = CT.TEXT

ZO_CreateStringId("SI_BINDING_NAME_FURYCT_WINDOW", "Open/close the board")
ZO_CreateStringId("SI_BINDING_NAME_FURYCT_BRAG", "Open/close the brag card")
ZO_CreateStringId("SI_BINDING_NAME_FURYCT_TIMERS", "Open/close research timers")

-- Windows -----------------------------------------------------------------------------------

-- Every window of the addon, with its size. On a screen with less room than a window needs, for
-- example a 4:3 monitor, it shrinks to fit so the close button stays on the screen.
local function Windows()
    return { { FurysCharacterTracker_Window, 1420, 784 }, { FurysCharacterTracker_Timers, 1000, 620 }, { FurysCharacterTracker_Details, 1000, 720 },
             { FurysCharacterTracker_Brag, 960, 726 }, { FurysCharacterTracker_Text, 820, 520 } }
end
CT.Windows = Windows

function CT.FitWindows()
    local screenWidth, screenHeight = GuiRoot:GetWidth(), GuiRoot:GetHeight()
    for _, window in ipairs(Windows()) do
        window[1]:SetScale(math.min(1, (screenWidth - 20) / window[2], (screenHeight - 20) / window[3]))
    end
end

-- The window you open or click comes to the front: each raise puts it one draw level above the last.
local topLevel = 10
function CT.Raise(control)
    topLevel = topLevel + 1
    control:SetDrawLevel(topLevel)
    control:BringWindowToTop()
end

-- Redraws whatever is open, after a read or a change.
function CT.Refresh()
    CT.Window:RefreshIfShown()
    CT.Timers:RefreshIfShown()
end

-- Switches of the Start here page and the settings page (listed in Data/Text.lua).
function CT.SetSwitch(switch, on)
    CT.sv[switch.field] = on
    if switch.alerts then CT.Alerts:Restart() end
end

-- Export --------------------------------------------------------------------------------------
-- The game only writes saved data on a reload or logout, so save and reload in one go.
-- AutoExport.ps1 (Windows Tools, turned on with "Turn On Auto Export.cmd") sees the new request and writes the CSV.
function CT.RequestExport()
    CT.Roster:BuildExportRows()
    CT.sv.exportRequestedAt = GetTimeStamp()
    CT.sv.exportPending = true
    ReloadUI("ingame")
end

-- Every way to export asks first (the button, the settings, /fct export): nothing reloads the UI
-- without a warning and a way to cancel.
local function ExportConfirmed() CT.RequestExport() end

-- 1.5.8: the pop-up is the shared one (UI/Theme.lua), the same in every Fury addon.
function CT.ConfirmExport()
    CT.Theme.Confirm(X.EXPORT_TITLE, X.EXPORT_BODY, "Export and reload", ExportConfirmed)
end

-- 1.5.8: in game, chat lines go through the shared chat line (UI/Theme.lua). Core/Util.lua keeps
-- its own plain version for the offline viewer, which has no theme.
function U.Print(fmt, ...)
    local text = select("#", ...) > 0 and string.format(fmt, ...) or fmt
    CT.Theme.Chat(text)
end

-- /fct --------------------------------------------------------------------------------------------

local function ReadNow()
    CT.Scan:Run()
    U.Print("Updated %s.", CT.Scan.CurrentName())
end
CT.ReadNow = ReadNow

local function Slash(arg)
    arg = zo_strlower(zo_strtrim(arg or ""))
    if arg == "" or arg == "show" then
        CT.Window:Toggle()
    elseif CT.VIEW_BY_ID[arg] then
        CT.Window:Show(arg)
    elseif arg == "todo" or arg == "needs" then
        -- 1.7.0: the Todo List is gone; the Daily tab shows the same things.
        CT.Window:Show("daily")
    elseif arg == "brag" then
        CT.Brag:Toggle()
    elseif arg == "unread" or arg:match("^unread %d+$") then
        CT.Roster:PrintToDo(tonumber(arg:match("%d+")) or 7)
    elseif arg == "scan" then
        ReadNow()
    elseif arg == "export" then
        CT.ConfirmExport()
    elseif arg == "settings" then
        CT.Settings:Open()
    elseif arg == "start" or arg == "help" then
        CT.Details:ShowStart()
    elseif arg == "tools" then
        RequestOpenUnsafeURL(CT.toolsUrl)
    elseif arg == "alerts on" or arg == "alerts off" then
        CT.Alerts:Set(arg == "alerts on")
    elseif arg == "research" then
        CT.Research:Print()
    elseif arg == "timers" then
        CT.Timers:Toggle()
    elseif arg == "ids" then
        CT.Scan:PrintIds()
    else
        U.Print("%s v%s commands:", CT.displayName, CT.version)
        for _, line in ipairs(X.HELP) do U.Print(line) end
    end
end

-- Startup -------------------------------------------------------------------------------------

local function OnAddOnLoaded(_, addonName)
    if addonName ~= CT.name then return end
    EVENT_MANAGER:UnregisterForEvent(CT.name, EVENT_ADD_ON_LOADED)
    CT.live = true

    -- Account-wide, split per megaserver: NA and EU are different rosters.
    CT.sv = ZO_SavedVars:NewAccountWide("FuryCT_SV", 1, nil, CT.defaults, GetWorldName())
    CT.home = { world = GetWorldName(), account = GetDisplayName() }
    CT.view = CT.home

    -- A brand-new install has nothing saved by any account on this PC. Everything starts turned
    -- off there, and the Start here page opens with the board the first time. Anyone who already
    -- used the addon keeps their settings exactly as they were.
    local sv = CT.sv
    local isNewInstall = sv.dataVersion == nil and #CT.Accounts() == 0
    if isNewInstall then
        sv.alertResearch, sv.alertRiding, sv.loginNotice = false, false, false
    elseif sv.dataVersion == nil then
        sv.startShown = true
    end
    CT.UpgradeProfile(sv, isNewInstall)
    CT.UpgradeAll()

    local T = CT.Theme
    CT.Window:Initialize()
    T.Window(FurysCharacterTracker_Window, { bg = "BG" })
    T.Window(FurysCharacterTracker_Timers, { bg = "BG" })
    T.Window(FurysCharacterTracker_Text, { bg = "BG" })
    T.Window(FurysCharacterTracker_Details, { bg = "BG", bar = 66 })
    T.Window(FurysCharacterTracker_Brag, { bg = "BG", bar = 92, center = true, font = "$(ANTIQUE_FONT)|36|soft-shadow-thick" })
    -- 1.5.6: every close button says what it does, the same words in every Fury addon.
    for _, win in ipairs({ FurysCharacterTracker_Window, FurysCharacterTracker_Timers,
                           FurysCharacterTracker_Text, FurysCharacterTracker_Details, FurysCharacterTracker_Brag }) do
        T.CloseTip(win:GetNamedChild("Close"))
    end
    CT.FitWindows()
    EVENT_MANAGER:RegisterForEvent(CT.name, EVENT_SCREEN_RESIZED, CT.FitWindows)
    -- Another account picked on the board: every open window shows that account.
    CT.viewListeners[#CT.viewListeners + 1] = function()
        CT.Window:Refresh()
        CT.Brag:RefreshIfShown()
        CT.Timers:RefreshIfShown()
    end
    CT.Settings:Build()
    SLASH_COMMANDS["/fct"] = Slash
end

local function OnPlayerActivated()
    -- Every zone change fires this; one full read per login or /reloadui is plenty,
    -- the game events each tracked thing listens for catch progress made after that.
    EVENT_MANAGER:UnregisterForEvent(CT.name, EVENT_PLAYER_ACTIVATED)
    CT.Scan:Start()
    if CT.sv.loginNotice ~= false then CT.Alerts:LoginNotice() end
    CT.Alerts:Start()
    if CT.sv.openAtLogin then CT.Window:Show() end
    if CT.sv.exportPending then
        CT.sv.exportPending = false
        U.Print(X.EXPORT_SAVED, U.Count(#CT.sv.exportRows - 1, "character"))
    end
end

EVENT_MANAGER:RegisterForEvent(CT.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
EVENT_MANAGER:RegisterForEvent(CT.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
