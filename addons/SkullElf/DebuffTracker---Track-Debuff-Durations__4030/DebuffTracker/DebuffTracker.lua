-- Startup: saved variables, 4.x import, module init, events, slash commands, keybind labels and the
-- optional LibAddonMenu entry. Loaded last (see DebuffTracker.txt).

local DT = DebuffTracker
local U = DT.Util
local L = DT.L

DT.perf = { loadMs = 0, activatedMs = 0, startedAt = 0 }

local function OnPlayerActivated()
    local t0 = GetGameTimeMilliseconds()
    DT.Load.ClassifyZone()
    DT.Effects.OnZoneChanged()
    DT.Gear.Refresh()
    DT.Procs.OnLoadoutChanged()
    DT.Procs.OnActivated()
    DT.Marker.OnActivated()
    DT.Profiles.ApplyAutoSwitch()
    DT.Engine.StandingChanged()      -- zone, gear: what listens may change
    DT.perf.activatedMs = GetGameTimeMilliseconds() - t0
    -- Cooldowns running next to us: point at the one-click import (once)
    local sv = DT.Profiles.SV()
    if not sv.cooldownsImported and not sv.cooldownsHinted and DT.Migration.FindCooldowns() then
        sv.cooldownsHinted = true
        zo_callLater(function()
            U.Print(L("Cooldowns detected. DebuffTracker can replace it: |cF3D27A/dt cooldowns|r imports your procs, positions, colours and sounds."))
        end, 4000)
    end
    if not sv.untauntedImported and not sv.untauntedHinted and DT.Migration.FindUntaunted() then
        sv.untauntedHinted = true
        zo_callLater(function()
            U.Print(L("Untaunted detected. DebuffTracker can replace it: |cF3D27A/dt untaunted|r imports your abilities, window and settings."))
        end, 5000)
    end
    if not sv.btgImported and not sv.btgHinted and DT.Migration.FindBTG() then
        sv.btgHinted = true
        zo_callLater(function()
            U.Print(L("BuffTheGroup detected. DebuffTracker can replace it: |cF3D27A/dt btg|r imports your buff windows."))
        end, 6000)
    end
    if not sv.staggerImported and not sv.staggerHinted and DT.Migration.FindStagger() then
        sv.staggerHinted = true
        zo_callLater(function()
            U.Print(L("StaggerTracker detected. DebuffTracker can replace it: |cF3D27A/dt stagger|r imports its icon."))
        end, 7000)
    end
    if not sv.exoyImported and not sv.exoyHinted and DT.Migration.FindExoY() then
        sv.exoyHinted = true
        zo_callLater(function()
            U.Print(L("ExoY's ProcSet Timer detected. DebuffTracker can replace it: |cF3D27A/dt exoy|r imports your proc icons."))
        end, 8000)
    end
    if not DT.Profiles.SV().seenWelcome then
        DT.Profiles.SV().seenWelcome = true
        U.Print(L("5.0 is here: build any tracker you like. Type |cF3D27A/dt|r to open the editor."))
    end
end

local function HelpText()
    U.Print(L("Commands:"))
    d("  /dt  -  " .. L("open / close the editor"))
    d("  /dt move  -  " .. L("drag tracker windows (again to lock)"))
    d("  /dt test  -  " .. L("toggle sample data on all trackers"))
    d("  /dt profile <name>  -  " .. L("switch profile"))
    d("  /dt perf  -  " .. L("show how much time DebuffTracker uses"))
    d("  /dt cooldowns  -  " .. L("import your setup from the Cooldowns addon"))
    d("  /dt untaunted  -  " .. L("import your setup from the Untaunted addon"))
    d("  /dt btg  -  " .. L("import your setup from BuffTheGroup"))
    d("  /dt stagger  -  " .. L("import your setup from StaggerTracker"))
    d("  /dt exoy  -  " .. L("import your setup from ExoY's ProcSet Timer"))
    d("  /dt meterskull  -  " .. L("import your setup from Meterskull"))
    d("  /dt miat  -  " .. L("import your setup from Miat's Ticks Tracker"))
    d("  /dt altgroupframes  -  " .. L("import your setup from Alternative Group Frames"))
    d("  /dt weavedelays  -  " .. L("import your setup from WeaveDelays"))
    d("  /dt credits  -  " .. L("the add-ons and authors DebuffTracker is built on"))
    d("  /dt weave  -  " .. L("hide / show the weaving trackers; /dt weave reset clears them"))
    d("  /dt gcd  -  " .. L("import your setup from Combat Metronome / GCD Bar / Global Cooldown Monitor"))
    d("  /dt debug  -  " .. L("toggle debug messages (also logged)"))
    d("  /dt tabtest  -  " .. L("30 s check of tab targeting and enemy positions (for bug reports)"))
    d("  /dt watch <ID>  -  " .. L("30 s check of one effect: the game's events, what DebuffTracker stored and shows (for bug reports)"))
    d("  /dt log  -  " .. L("copy the debug log"))
    d("  /dt clearlog  -  " .. L("empty the debug log"))
end

local function SlashCommand(args)
    local cmd, rest = U.Trim(args or ""):match("^(%S*)%s*(.-)$")
    cmd = U.Lower(cmd or "")
    if cmd == "" then
        DT.UI.Toggle()
    elseif cmd == "move" or cmd == "unlock" or cmd == "lock" then
        DT.Unlock.Toggle()
    elseif cmd == "test" then
        DT.testMode = not DT.testMode
        DT.Engine.RequestUpdate()
        U.Print(DT.testMode and L("Test mode ON (sample data on every tracker).") or L("Test mode OFF."))
    elseif cmd == "perf" then
        local st, p = DT.Engine.stats, DT.perf
        local secs = math.max(1, (GetGameTimeMilliseconds() - p.startedAt) / 1000)
        U.Print(L("Load <<1>> ms, zone-in <<2>> ms. Update: <<3>> ms average, <<4>> ms slowest. <<5>> effect events per second, <<6>> event hooks.",
            p.loadMs, p.activatedMs, string.format("%.2f", st.avgMs), st.maxMs,
            string.format("%.0f", DT.Effects.eventCount / secs), DT.Effects.RegisteredCount() + DT.Combat.RegisteredCount()))
    elseif cmd == "tabtest" then
        DT.Probe.Start()
    elseif cmd == "watch" then
        DT.Probe.Watch(rest)
    elseif cmd == "marker" then
        U.Print(L("Enemy marker: <<1>>", DT.Marker.Status()))
    elseif cmd == "cooldowns" then
        local added, summary = DT.Migration.ImportCooldowns()
        if not added then U.Print(summary)
        else U.Print(L("Imported from Cooldowns: a \"My procs\" tracker plus <<1>> own tracker(s) (replaced <<2>> from an earlier import). You can disable Cooldowns now; /dt to adjust.", summary.own, summary.replaced)) end
    elseif cmd == "untaunted" then
        local added, summary = DT.Migration.ImportUntaunted()
        if not added then U.Print(summary)
        else U.Print(L("Imported from Untaunted: a \"Taunts (Untaunted)\" tracker with <<1>> abilities (replaced <<2>> from an earlier import). You can disable Untaunted now; /dt to adjust.", summary.abilities, summary.replaced)) end
    elseif cmd == "btg" or cmd == "buffthegroup" then
        local added, summary = DT.Migration.ImportBTG()
        if not added then U.Print(summary)
        else U.Print(L("Imported from BuffTheGroup: <<1>> tracker(s) (replaced <<2>> from an earlier import). You can disable BuffTheGroup now; /dt to adjust.", summary.buffs, summary.replaced)) end
    elseif cmd == "stagger" or cmd == "staggertracker" then
        local added, summary = DT.Migration.ImportStagger()
        if not added then U.Print(summary)
        else U.Print(L("Imported from StaggerTracker: a \"Heat Shock (Magma Fist)\" icon (replaced <<1>> from an earlier import). You can disable StaggerTracker now; /dt to adjust.", summary.replaced)) end
    elseif cmd == "exoy" or cmd == "ept" then
        local added, summary = DT.Migration.ImportExoY()
        if not added then U.Print(summary)
        else U.Print(L("Imported from ExoY's ProcSet Timer: a \"My procs (ExoY)\" tracker plus <<1>> own tracker(s) (replaced <<2>> from an earlier import). You can disable it now; /dt to adjust.", summary.own, summary.replaced)) end
    elseif cmd == "meterskull" or cmd == "ms" then
        local added, summary = DT.Migration.ImportMeterskull()
        if not added then U.Print(summary)
        else U.Print(L("Imported from Meterskull: <<1>> number tiles (<<2>> shown, the others switched off; replaced <<3>> from an earlier import). You can disable Meterskull now; /dt to adjust.", summary.trackers, summary.shown, summary.replaced)) end
    elseif cmd == "gcd" or cmd == "metronome" or cmd == "cm" then
        local added, summary = DT.Migration.ImportGcd()
        if not added then U.Print(summary)
        else U.Print(L("Imported from <<1>>: <<2>> \"Global cooldown\" tracker(s) where yours were (replaced <<3>> from an earlier import). You can disable it now; /dt to adjust.", summary.from, #added, summary.replaced)) end
    elseif cmd == "credits" then
        U.Print(L("DebuffTracker is built on what these add-ons' authors worked out -- thank you:"))
        for _, line in ipairs(DT.Const.CreditLines()) do d("  " .. line) end
    elseif cmd == "weavedelays" or cmd == "wd" then
        local added, summary = DT.Migration.ImportWeaveDelays()
        if not added then U.Print(summary)
        else U.Print(L("Imported from WeaveDelays: a \"Weave strip\" where yours was (replaced <<1>> from an earlier import). You can disable WeaveDelays now; /dt to adjust.", summary.replaced)) end
    elseif cmd == "weave" then
        if (rest or ""):lower():find("reset", 1, true) then
            DT.Weave.Reset()
            U.Print(L("Weaving: cleared."))
        else
            local hidden = DT.Weave.Toggle()
            U.Print(hidden and L("Weaving trackers hidden (/dt weave to show them again).") or L("Weaving trackers shown."))
        end
    elseif cmd == "altgroupframes" or cmd == "agf" or cmd == "groupframes" then
        local added, summary = DT.Migration.ImportAltGF()
        if not added then U.Print(summary)
        else U.Print(L("Imported from Alternative Group Frames: \"Group frames\" where yours were, plus <<1>> \"On group frames\" tracker(s) (replaced <<2>> from an earlier import). You can disable Alternative Group Frames now; /dt to adjust.", summary.extra, summary.replaced)) end
    elseif cmd == "miat" or cmd == "ticks" then
        local added, summary = DT.Migration.ImportMiat()
        if not added then U.Print(summary)
        else
            U.Print(L("Imported from Miat's Ticks Tracker: a \"Resource tick\" bar where yours was (replaced <<1>> from an earlier import). You can disable Miat's Ticks Tracker now; /dt to adjust.", summary.replaced))
            if summary.attached then U.Print(L("(Yours was attached to the game's resource bar; ours is its own bar -- drag it there with /dt move.)")) end
        end
    elseif cmd == "debug" then
        DT.debug = not DT.debug
        U.Print(DT.debug and L("Debug ON -- also logged: /dt log to copy it, /dt clearlog to empty it.") or L("Debug OFF"))
    elseif cmd == "log" then
        local log = U.debugLog or {}
        if #log == 0 then U.Print(L("The debug log is empty. Turn it on with /dt debug, reproduce the problem, then /dt log."))
        else
            -- the copy box holds ~200k characters: the newest lines that fit (the whole log is in the
            -- SavedVariables file after /reloadui)
            local parts, size = {}, 0
            for i = #log, 1, -1 do
                size = size + #log[i] + 1
                if size > 190000 then break end
                table.insert(parts, 1, log[i])
            end
            DT.UI.Show()
            DT.UI.ShowExport(L("Debug log (<<1>> of <<2>> lines)", #parts, #log), table.concat(parts, "\n"))
        end
    elseif cmd == "clearlog" then
        if U.debugLog then for i = #U.debugLog, 1, -1 do U.debugLog[i] = nil end end
        U.Print(L("Debug log cleared."))
    elseif cmd == "profile" then
        if rest == "" then
            U.Print(L("Profiles: <<1>> (active: <<2>>)", U.JoinList(DT.Profiles.Names()), DT.Profiles.ActiveName()))
        elseif not DT.Profiles.SetActive(rest) then
            U.Print(L("No profile named \"<<1>>\" (or it's already active).", rest))
        end
    else
        HelpText()
    end
end

local function RegisterLibAddonMenu()
    local LAM = LibAddonMenu2
    if not LAM then return end
    LAM:RegisterAddonPanel("DebuffTracker5Panel", {
        type = "panel", name = "DebuffTracker", displayName = "|cF3D27ADebuffTracker|r 5",
        author = DT.author, version = DT.version, registerForRefresh = false,
    })
    LAM:RegisterOptionControls("DebuffTracker5Panel", {
        { type = "description", text = L("DebuffTracker has its own editor with live preview, a preset library, an effect recorder and profiles.") },
        { type = "button", name = L("Open the editor"), func = function() DT.UI.Show() end, width = "half" },
        { type = "button", name = L("Move windows"), func = function() DT.Unlock.Toggle() end, width = "half" },
    })
end

-- Skills window tooltips get an "Ability ID" line (handy for building trackers). A post-hook: the
-- game's tooltip is built first and untouched; nothing is replaced.
local function HookSkillTooltips()
    if type(ZO_PostHook) ~= "function" or type(SetTooltipText) ~= "function" then return end
    local function AddId(self, tooltip)
        if not DT.Profiles.Settings().skillTooltipIds or not tooltip then return end
        local id = self.GetAbilityId and self:GetAbilityId()
        if id and id > 0 then SetTooltipText(tooltip, L("Ability ID: <<1>>", id), 0.6, 0.6, 0.6) end
    end
    for _, class in ipairs({ ZO_ActiveSkillProgressionData, ZO_PassiveSkillProgressionData }) do
        if type(class) == "table" and class.SetKeyboardTooltip then ZO_PostHook(class, "SetKeyboardTooltip", AddId) end
    end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= DT.name then return end
    EVENT_MANAGER:UnregisterForEvent(DT.name, EVENT_ADD_ON_LOADED)
    local t0 = GetGameTimeMilliseconds()
    DT.perf.startedAt = t0

    -- 4.x data lives in the default namespace of the same SavedVariables table; 5.0 uses its own
    -- "v5" namespace next to it, so the old data is never modified.
    local oldSV = ZO_SavedVars:NewAccountWide("DebuffTrackerSavedVars", 1, nil, {})
    local sv = ZO_SavedVars:NewAccountWide("DebuffTrackerSavedVars", 1, "v5", {})
    if type(oldSV.trackedAbilities) == "table" then DT.oldSV = oldSV end

    DT.Profiles.Initialize(sv)
    if DT.oldSV and not sv.migratedFromV4 then
        local trackers, profiles = DT.Migration.Run(DT.oldSV, sv)
        DT.Profiles.Initialize(sv)
        if trackers > 0 or profiles > 0 then
            zo_callLater(function()
                U.Print(L("Imported your 4.x setup: <<1>> trackers in <<2>> profiles. Your old settings are untouched.", trackers, profiles))
            end, 3000)
        end
    else
        sv.migratedFromV4 = true
    end

    DT.Units.SetDifficultyStore(sv.enemyDifficulty)
    U.debugLog = sv.debugLog
    DT.Effects.Initialize()
    DT.Gear.Initialize()
    DT.Procs.InitTargets()
    DT.Resources.InitializeUltWatch()
    DT.Load.InitializeSlots()
    DT.Announcer.Initialize()

    DT.ready = true
    DT.Engine.Rebuild()
    DT.Engine.Start()

    EVENT_MANAGER:RegisterForEvent(DT.name .. "_Activated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    if EVENT_GROUP_MEMBER_ROLE_CHANGED then
        EVENT_MANAGER:RegisterForEvent(DT.name .. "_Role", EVENT_GROUP_MEMBER_ROLE_CHANGED, function(_, unitTag)
            if unitTag == "player" or AreUnitsEqual and AreUnitsEqual(unitTag, "player") then
                DT.Profiles.ApplyAutoSwitch()
                DT.Engine.StandingChanged()      -- "Role" load conditions
            end
        end)
    end

    SLASH_COMMANDS["/dt"] = SlashCommand
    SLASH_COMMANDS["/debufftracker"] = SlashCommand

    ZO_CreateStringId("SI_BINDING_NAME_DEBUFFTRACKER5_EDITOR", L("Open / close the editor"))
    ZO_CreateStringId("SI_BINDING_NAME_DEBUFFTRACKER5_MOVE", L("Move windows (toggle)"))
    ZO_CreateStringId("SI_BINDING_NAME_DEBUFFTRACKER5_TEST", L("Sample data on all trackers (toggle)"))
    ZO_CreateStringId("SI_BINDING_NAME_DEBUFFTRACKER5_WEAVE", L("Weaving trackers: hide / show"))

    RegisterLibAddonMenu()
    U.SafeCall("skill tooltip ids", HookSkillTooltips)
    DT.perf.loadMs = GetGameTimeMilliseconds() - t0
end

-- Keybind entry points (bindings.xml)
function DebuffTracker_ToggleEditor() DT.UI.Toggle() end
function DebuffTracker_ToggleMove() DT.Unlock.Toggle() end
-- (WeaveDelays' "Toggle WeaveDelays window" key)
function DebuffTracker_ToggleWeave()
    if DebuffTracker.Weave then DebuffTracker.Weave.Toggle() end
end

function DebuffTracker_ToggleTest()
    DT.testMode = not DT.testMode
    DT.Engine.RequestUpdate()
end

EVENT_MANAGER:RegisterForEvent(DT.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
