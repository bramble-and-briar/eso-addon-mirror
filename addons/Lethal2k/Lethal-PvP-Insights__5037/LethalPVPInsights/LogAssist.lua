-- Lethal PVP Insights - automatic encounter log capture
--
-- Gear and skill bars of group members are written to Encounter.log (PLAYER_INFO lines) when
-- combat starts. The addon cannot read the log, so it *predicts* when it has enough:
--   1. You're grouped in a PvP area and some online members have no gear data -> log ON.
--   2. Each time you enter combat while it's on, every member who still needs data and is in
--      group support range counts as "covered" (their PLAYER_INFO was written).
--   3. Once nobody is left uncovered -> log OFF a few seconds later (the log stays small).
--   4. Out of combat -> the import window pops up; the desktop Companion pops up too.
-- Safety: switched off after 10 minutes, when you leave the group or the PvP area.
-- A log the user started with /encounterlog is never switched off.
local PDI = PVPDataInsight
local LA = {}
PDI.LogAssist = LA

local EM = EVENT_MANAGER
local NS = PDI.name .. "_LogAssist"
local WM = WINDOW_MANAGER

local PROMPT_COOLDOWN_SEC  = 15 * 60  -- "ask" mode: don't nag more often than this
local CYCLE_COOLDOWN_SEC   = 60       -- auto mode: pause between two capture cycles
local MAX_ON_SEC           = 10 * 60  -- auto mode: give up after this long
local COVERAGE_RETRY_SEC   = 2 * 3600 -- covered but never imported -> try again after this
local OFF_AFTER_COVER_MS   = 3000     -- keep logging briefly after the combat start that completed coverage
local OFF_DELAY_MS         = 4000     -- manual "fight" mode: wait after combat ends

LA.ownedByUs    = false  -- we switched the log on
LA.mode         = nil    -- "auto" | "fight" | "timed"
LA.fought       = false
LA.covered      = {}     -- this cycle: [@account] = true
LA.lastCaptured = {}
LA.lastPrompt   = 0
LA.lastCycleEnd = 0
LA.pendingPopup = false
local token = 0

local function settings() return PDI.sv.settings end
local function coverage() return PDI.sv.logCoverage end

function LA:IsOn() return IsEncounterLogEnabled ~= nil and IsEncounterLogEnabled() end

function LA:LogPath()
    local p = settings().logPath
    if p and p ~= "" then
        -- accept a folder too: append the file name
        if not string.lower(p):find("%.log$") then p = p:gsub("[\\/]+$", "") .. "\\Encounter.log" end
        return p
    end
    local realm = (GetWorldName and (GetWorldName() or ""):find("PTS")) and "pts" or "live"
    return "%USERPROFILE%\\Documents\\Elder Scrolls Online\\" .. realm .. "\\Logs\\Encounter.log"
end

local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end

---------------------------------------------------------------------------
-- Who still needs data
---------------------------------------------------------------------------
function LA:NeedsData(acct)
    if not acct or PDI.Import:Has(acct) then return false end
    local t = coverage()[acct]
    return not (t and PDI.Now() - t < COVERAGE_RETRY_SEC)
end

-- returns list of { acct=, tag= } for online members (not you) that still need gear data
function LA:Missing()
    local list = {}
    if not IsUnitGrouped("player") then return list end
    for i = 1, GetGroupSize() do
        local tag = GetGroupUnitTagByIndex(i)
        if tag and DoesUnitExist(tag) and not AreUnitsEqual(tag, "player") and IsUnitOnline(tag) then
            local acct = PDI.NormalizeAccount(GetUnitDisplayName(tag))
            if self:NeedsData(acct) then list[#list + 1] = { acct = acct, tag = tag } end
        end
    end
    return list
end

---------------------------------------------------------------------------
-- On / off
---------------------------------------------------------------------------
function LA:Enable(mode, secs)
    if not SetEncounterLogEnabled then
        PDI.Msg("Type |cFFFFFF/encounterlog|r to turn the encounter log on, then fight.")
        return false
    end
    if self:IsOn() then
        if not self.ownedByUs then
            PDI.Msg("The encounter log is already on (you started it), so I'll leave it to you to switch off.")
        end
        return false
    end
    SetEncounterLogEnabled(true)
    if not self:IsOn() then
        PDI.Msg("Couldn't switch the encounter log on - type |cFFFFFF/encounterlog|r instead.")
        return false
    end
    token = token + 1
    self.ownedByUs, self.mode, self.fought, self.covered = true, mode or "auto", false, {}
    self.enabledAt = PDI.Now()
    self:RememberCapture(self.enabledAt)
    if self.mode == "timed" then
        local t = token
        secs = zo_clamp(secs or 90, 10, 1800)
        zo_callLater(function() if t == token then LA:Finish("timer") end end, secs * 1000)
        PDI.Msg(string.format("Encounter log |c00FF00ON|r for %d s - get into a fight.", secs))
    elseif self.mode == "fight" then
        PDI.Msg("Encounter log |c00FF00ON|r - it switches off by itself after your next fight.")
    else
        PDI.Msg(string.format("Encounter log |c00FF00ON|r - capturing gear for %d group member(s) at your next fight.",
            #self:Missing()))
    end
    return true
end

-- Switch our log off. Shows the import window (now, or when combat ends) if anything was captured.
function LA:Finish(reason)
    if not self.ownedByUs then
        if reason == "manual" and self:IsOn() and SetEncounterLogEnabled then
            SetEncounterLogEnabled(false)
            PDI.Msg("Encounter log |cFF4444OFF|r.")
        end
        return
    end
    token = token + 1
    SetEncounterLogEnabled(false)
    local mode = self.mode
    local captured = (mode == "auto") and count(self.covered) or (self.fought and 1 or 0)
    self.lastCaptured = (mode == "auto") and self.covered or {}
    self.ownedByUs, self.mode, self.fought, self.covered = false, nil, false, {}
    self.lastCycleEnd = PDI.Now()

    if captured > 0 then
        if mode == "auto" then
            local why = (reason == "complete") and "everyone captured" or
                        (reason == "timeout") and "time limit reached" or
                        (reason == "left") and "you left the group / PvP area" or reason
            PDI.Msg(string.format("Gear & bars captured for %d player(s) (%s) - encounter log |cFF4444OFF|r.",
                captured, why))
        else
            PDI.Msg("Fight captured - encounter log |cFF4444OFF|r. Import it, then /reloadui.")
        end
        if settings().importPopup then
            if IsUnitInCombat("player") then self.pendingPopup = true else self:ShowImportWindow() end
        end
    elseif reason == "manual" then
        PDI.Msg("Encounter log |cFF4444OFF|r.")
    else
        PDI.Msg("Encounter log |cFF4444OFF|r - no fight happened while it was on, so nothing new to import.")
    end
end

-- /pvpdi capture [seconds|off]
function LA:Capture(arg)
    if arg == "off" then self:Finish("manual"); return end
    local secs = tonumber(arg)
    if secs then self:Enable("timed", secs) else self:Enable("fight") end
end

---------------------------------------------------------------------------
-- Automatic decision
---------------------------------------------------------------------------
function LA:Evaluate()
    local mode = settings().autoLog
    local eligible = IsUnitGrouped("player") and PDI.ShouldTrackGroup()

    if self.ownedByUs and self.mode == "auto" then
        if not eligible then
            self:Finish("left")
        elseif PDI.Now() - (self.enabledAt or 0) > MAX_ON_SEC then
            self:Finish("timeout")
        end
        return
    end

    if mode == "never" or not eligible or self:IsOn() then return end
    if IsUnitInCombat("player") then return end           -- re-evaluated when combat ends
    if PDI.Now() - self.lastCycleEnd < CYCLE_COOLDOWN_SEC then return end
    local missing = #self:Missing()
    if missing == 0 then return end

    if mode == "ask" then
        if PDI.Now() - self.lastPrompt < PROMPT_COOLDOWN_SEC then return end
        self.lastPrompt = PDI.Now()
        if ZO_Dialogs_ShowDialog then
            ZO_Dialogs_ShowDialog("PVPDI_ENCOUNTER_LOG", nil, { mainTextParams = { missing } })
        end
    else -- "auto" (default; "always" is accepted as an alias)
        self:Enable("auto")
    end
end

-- Called when combat starts while our log is on: who got their PLAYER_INFO written?
function LA:OnCombatStart()
    self.fought = true
    if self.mode ~= "auto" then return end
    local now = PDI.Now()
    local stillMissing = 0
    for _, m in ipairs(self:Missing()) do
        local inRange = not IsUnitInGroupSupportRange or IsUnitInGroupSupportRange(m.tag)
        if inRange then
            self.covered[m.acct] = true
            coverage()[m.acct] = now
        else
            stillMissing = stillMissing + 1
        end
    end
    if count(self.covered) > 0 and stillMissing == 0 then
        local t = token
        zo_callLater(function() if t == token then LA:Finish("complete") end end, OFF_AFTER_COVER_MS)
    elseif stillMissing > 0 then
        PDI.Msg(string.format("|c999999Encounter log: %d captured, waiting for %d member(s) out of range.|r",
            count(self.covered), stillMissing))
    end
end

local function OnCombatState(_, inCombat)
    if inCombat then
        if LA.ownedByUs then
            if LA.mode == "fight" or LA.mode == "timed" then
                LA.mode = "fight"
                token = token + 1  -- cancel a pending switch-off
            end
            LA:OnCombatStart()
        end
        return
    end
    -- combat ended
    if LA.ownedByUs and LA.mode == "fight" and LA.fought then
        local t = token
        zo_callLater(function()
            if t == token and not IsUnitInCombat("player") then LA:Finish("fight") end
        end, OFF_DELAY_MS)
    end
    if LA.pendingPopup then
        LA.pendingPopup = false
        zo_callLater(function() if not IsUnitInCombat("player") then LA:ShowImportWindow() else LA.pendingPopup = true end end, 1500)
    end
    zo_callLater(function() LA:Evaluate() end, 2000)
end

local function evaluateSoon()
    zo_callLater(function() LA:Evaluate() end, 2500)
end

local function OnMemberLeft(_, _, _, isLocalPlayer)
    if isLocalPlayer then LA.lastPrompt = 0 end
    evaluateSoon()
end

---------------------------------------------------------------------------
-- Import window
---------------------------------------------------------------------------
function LA:BuildImportWindow()
    if self.win then return end
    local win = WM:CreateTopLevelWindow("PVPDataInsightImportWindow")
    self.win = win
    win:SetDimensions(640, 388)
    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, -120)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    local bg = WM:CreateControlFromVirtual("PVPDataInsightImportWindowBG", win, "ZO_DefaultBackdrop")
    bg:SetAnchorFill(win)

    local title = WM:CreateControl("PVPDataInsightImportTitle", win, CT_LABEL)
    title:SetFont("ZoFontWinH3")
    title:SetColor(0.77, 0.76, 0.62, 1)
    title:SetAnchor(TOPLEFT, win, TOPLEFT, 18, 14)
    title:SetText("Import gear & skill bars")

    local close = WM:CreateControlFromVirtual("PVPDataInsightImportClose", win, "ZO_CloseButton")
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -10, 14)
    close:SetHandler("OnClicked", function() LA:HideImportWindow() end)

    local body = WM:CreateControl("PVPDataInsightImportBody", win, CT_LABEL)
    body:SetFont("ZoFontGame")
    body:SetAnchor(TOPLEFT, win, TOPLEFT, 18, 50)
    body:SetDimensions(604, 100)
    body:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
    body:SetText("|cFF6655The LPI Companion must be running on your PC before you click Upload|r - " ..
        "otherwise the browser only shows \"can't be reached\". Start it with |cFFFFFFLPI COMPANION.bat|r in the " ..
        "addon folder (or the LPI Companion desktop shortcut).\n" ..
        "1. Click |cFFFFFFUpload|r and confirm the game's \"open link\" prompt.   2. Click |cFFFFFFReload UI|r.")
    self.body = body

    -- was the Companion running when the UI loaded? (it writes LPI_Companion.lua every minute)
    local cstat = WM:CreateControl("PVPDataInsightImportCompanion", win, CT_LABEL)
    cstat:SetFont("ZoFontGameBold")
    cstat:SetAnchor(TOPLEFT, win, TOPLEFT, 18, 154)
    cstat:SetDimensions(604, 22)
    cstat:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    self.companionStatus = cstat

    local summary = WM:CreateControl("PVPDataInsightImportSummary", win, CT_LABEL)
    summary:SetFont("ZoFontGameSmall")
    summary:SetColor(0.4, 0.8, 1, 1)
    summary:SetAnchor(TOPLEFT, win, TOPLEFT, 18, 180)
    summary:SetDimensions(604, 22)
    summary:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    self.summary = summary

    local lbl = WM:CreateControl("PVPDataInsightImportPathLabel", win, CT_LABEL)
    lbl:SetFont("ZoFontGameSmall")
    lbl:SetColor(0.6, 0.6, 0.6, 1)
    lbl:SetAnchor(TOPLEFT, win, TOPLEFT, 18, 204)
    lbl:SetText("Encounter log file (click, then Ctrl+C to copy):")

    local editBg = WM:CreateControlFromVirtual("PVPDataInsightImportPathBG", win, "ZO_EditBackdrop")
    editBg:SetDimensions(604, 28)
    editBg:SetAnchor(TOPLEFT, win, TOPLEFT, 18, 226)
    local edit = WM:CreateControlFromVirtual("PVPDataInsightImportPath", editBg, "ZO_DefaultEditForBackdrop")
    edit:SetMaxInputChars(400)
    edit:SetHandler("OnFocusGained", function(c) c:SelectAll() end)
    edit:SetHandler("OnTextChanged", function(c)
        -- keep the field read-only in practice: restore the path if the user types over it
        if c:GetText() ~= LA:LogPath() and not LA.settingText then c:SetText(LA:LogPath()); c:SelectAll() end
    end)
    self.pathEdit = edit

    local function btn(name, text, w, fn)
        local b = WM:CreateControlFromVirtual(name, win, "ZO_DefaultButton")
        b:SetDimensions(w, 30)
        b:SetText(text)
        b:SetHandler("OnClicked", fn)
        return b
    end
    local upload = btn("PVPDataInsightImportUpload", "Upload", 180, function() LA:Upload() end)
    upload:SetAnchor(TOPLEFT, win, TOPLEFT, 18, 268)
    local reload = btn("PVPDataInsightImportReload", "Reload UI", 180, function() ReloadUI("ingame") end)
    reload:SetAnchor(LEFT, upload, RIGHT, 10, 0)
    self.uploadStatus = WM:CreateControl("PVPDataInsightImportUploadStatus", win, CT_LABEL)
    self.uploadStatus:SetFont("ZoFontGameSmall")
    self.uploadStatus:SetColor(0.4, 0.8, 1, 1)
    self.uploadStatus:SetAnchor(TOPLEFT, win, TOPLEFT, 18, 304)
    self.uploadStatus:SetDimensions(604, 22)
    local del = btn("PVPDataInsightImportDelete", "Delete Log", 150, function() LA:DeleteLog() end)
    del:SetAnchor(LEFT, reload, RIGHT, 10, 0)
    local later = btn("PVPDataInsightImportLater", "Later", 110, function() LA:HideImportWindow() end)
    later:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -18, -16)
    local never = btn("PVPDataInsightImportNever", "Don't show again", 180, function()
        settings().importPopup = false
        PDI.Msg("Import window disabled. Turn it back on with |cFFFFFF/pvpdi popup on|r.")
        LA:HideImportWindow()
    end)
    never:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 18, -16)

    local scene = ZO_Scene:New("PVPDataInsightImportScene", SCENE_MANAGER)
    scene:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    scene:AddFragment(ZO_SimpleSceneFragment:New(win))
    self.scene = scene
end

-- Upload = ask the desktop Companion (local web endpoint) to import Encounter.log.
-- Addons can't read files or start programs; opening a localhost link is the only bridge the game offers.
LA.UPLOAD_URL = "http://127.0.0.1:47613/import"

-- Every time the addon switches the encounter log on, the start time is remembered. The Companion
-- compares these with the log's own start times (BEGIN_LOG lines): a log that also contains logging
-- the player started himself (/encounterlog) is never deleted without asking. The list reaches the
-- Companion in the Upload / Delete links right away, and through the saved data file after a reload.
function LA:RememberCapture(ts)
    local list = PDI.sv.captureStarts or {}
    PDI.sv.captureStarts = list
    list[#list + 1] = ts
    local cut = PDI.Now() - 30 * 86400
    while #list > 0 and (list[1] < cut or #list > 300) do table.remove(list, 1) end
end

function LA:CaptureQuery()
    local recent, cut = {}, PDI.Now() - 3 * 86400
    for _, ts in ipairs(PDI.sv.captureStarts or {}) do
        if ts >= cut then recent[#recent + 1] = tostring(ts) end
    end
    if #recent == 0 then return "" end
    return "?caps=" .. table.concat(recent, ",")
end

function LA:Upload()
    if not RequestOpenUnsafeURL then
        PDI.Msg("This client can't open links - use the Import button in the LPI Companion window instead.")
        return
    end
    RequestOpenUnsafeURL(self.UPLOAD_URL .. self:CaptureQuery())
    settings().uploadRequestedAt = PDI.Now()   -- checked after the reload to tell whether it worked
    if self.uploadStatus then
        self.uploadStatus:SetText(self:CompanionRunning() and "After confirming, wait for the browser page to say \"Imported\", then click Reload UI."
            or "If the browser says the page can't be reached, start LPI COMPANION.bat and click Upload again.")
    end
end

-- The Companion rewrites LPI_Companion.lua every minute while it runs; the game reads that
-- file on each UI load. So this answers "was it running at the last UI load" - addons can't check live.
LA.COMPANION_FRESH_SEC = 150
function LA:CompanionState()
    local c = PVPDataInsight_Companion
    if not c or (c.seen or 0) == 0 then return "never" end
    local age = (self.loadedAt or PDI.Now()) - c.seen
    if c.running and age <= self.COMPANION_FRESH_SEC then return "running" end
    return "stopped"
end
function LA:CompanionRunning() return self:CompanionState() == "running" end

function LA:UpdateCompanionStatus()
    if not self.companionStatus then return end
    local st = self:CompanionState()
    if st == "running" then
        self.companionStatus:SetText("|c66DD66Companion: running|r |c999999(when the UI loaded)|r")
    elseif st == "never" then
        self.companionStatus:SetText("|cFF6655Companion: never started - double-click LPI COMPANION.bat before Upload|r")
    else
        self.companionStatus:SetText("|cFF6655Companion: not running at the last UI load - start LPI COMPANION.bat first|r")
    end
end

-- Ask the Companion to delete Encounter.log (after its data has been imported)
LA.DELETE_URL = "http://127.0.0.1:47613/deletelog"
function LA:DeleteLog()
    if self:IsOn() then
        PDI.Msg("The encounter log is still on - it can be deleted once it's switched off.")
        return
    end
    if not RequestOpenUnsafeURL then
        PDI.Msg("Use the 'Delete log now' button in the LPI Companion window instead.")
        return
    end
    RequestOpenUnsafeURL(self.DELETE_URL .. self:CaptureQuery())
    if self.uploadStatus then
        self.uploadStatus:SetText("Confirm the prompt. If the log also has logging you started yourself, the page asks first.")
    end
end

function LA:ShowImportWindow()
    self:BuildImportWindow()
    if self.uploadStatus then self.uploadStatus:SetText("") end
    self:UpdateCompanionStatus()
    self.settingText = true
    self.pathEdit:SetText(self:LogPath())
    self.settingText = false
    local names = {}
    for acct in pairs(self.lastCaptured or {}) do names[#names + 1] = acct end
    table.sort(names)
    local shown = {}
    for i = 1, math.min(6, #names) do shown[i] = names[i] end
    self.summary:SetText(#names > 0 and string.format("Captured %d player(s): %s%s", #names,
        table.concat(shown, ", "), #names > 6 and string.format(" +%d more", #names - 6) or "") or "")
    SCENE_MANAGER:Show("PVPDataInsightImportScene")
end

function LA:HideImportWindow()
    if self.scene then SCENE_MANAGER:Hide("PVPDataInsightImportScene") end
end

---------------------------------------------------------------------------
function LA:Init()
    self.loadedAt = PDI.Now()
    PDI.sv.logCoverage = PDI.sv.logCoverage or {}
    -- forget coverage for players whose data has been imported, and stale entries
    for acct, t in pairs(coverage()) do
        if PDI.Import:Has(acct) or PDI.Now() - t > COVERAGE_RETRY_SEC then coverage()[acct] = nil end
    end
    if settings().autoLog == "always" then settings().autoLog = "auto" end

    if ESO_Dialogs then
        ESO_Dialogs["PVPDI_ENCOUNTER_LOG"] = {
            title = { text = "Lethal PVP Insights" },
            mainText = { text = "You're grouped and <<1>> member(s) have no gear or skill-bar data yet.\n\n" ..
                "Turn on the encounter log until their gear has been captured?" },
            buttons = {
                { text = "Turn on", callback = function() LA:Enable("auto") end },
                { text = "Not now" },
            },
        }
    end
    EM:RegisterForEvent(NS .. "Combat", EVENT_PLAYER_COMBAT_STATE, OnCombatState)
    EM:RegisterForEvent(NS .. "Joined", EVENT_GROUP_MEMBER_JOINED, evaluateSoon)
    EM:RegisterForEvent(NS .. "Update", EVENT_GROUP_UPDATE, evaluateSoon)
    EM:RegisterForEvent(NS .. "Activated", EVENT_PLAYER_ACTIVATED, evaluateSoon)
    EM:RegisterForEvent(NS .. "Left", EVENT_GROUP_MEMBER_LEFT, OnMemberLeft)
    if EVENT_GROUP_MEMBER_CONNECTED_STATUS then
        EM:RegisterForEvent(NS .. "Online", EVENT_GROUP_MEMBER_CONNECTED_STATUS, evaluateSoon)
    end
    EM:RegisterForUpdate(NS .. "Tick", 30000, function() LA:Evaluate() end)
end
