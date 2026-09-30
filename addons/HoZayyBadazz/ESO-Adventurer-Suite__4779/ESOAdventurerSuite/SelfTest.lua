-- ESO Adventurer Suite - Safe full-suite self test / copyable diagnostic report
-- This intentionally DOES NOT blindly execute protected/gameplay functions.
-- It validates module load state, capability/API presence, libraries, runtime
-- errors, secure-path guards, controls, and current-context readiness.

ESOProgressionCoach = ESOProgressionCoach or {}
local EPC = ESOProgressionCoach
EPC.SelfTest = EPC.SelfTest or {}
local T = EPC.SelfTest

local REPORT_LIMIT = 11500

local MODULES = {
    {"BUG_CATCHER","BugCatcher"}, {"ROLE","Role"}, {"TRAVEL","Travel"},
    {"ACTIVITIES","Activities"}, {"DUNGEON_FINDER","DungeonFinder"},
    {"DUNGEON_HISTORY","DungeonHistory"}, {"ACTIVITY_RUN_HISTORY","ActivityRunHistory"},
    {"QUEST_FINDER","QuestFinder"}, {"SET_JOURNAL","SetJournal"}, {"ENDGAME","Endgame"},
    {"TARGET_BUILD","TargetBuild"}, {"GEAR_OPTIMIZER","GearOptimizer"},
    {"COMPANION_OPTIMIZER","CompanionOptimizer"}, {"GEAR_LOADOUT_OVERLAY","GearLoadoutOverlay"},
    {"CHARACTER_GEAR_SCREEN","CharacterGearScreen"}, {"LOADOUT_MANAGER","LoadoutManager"},
    {"RECIPE_STYLE_LEARNER","RecipeStyleLearner"}, {"ALCHEMY_POTION_MAKER","AlchemyPotionMaker"},
    {"WAYSHRINE_AUTO_MESSAGE","WayshrineAutoMessage"}, {"ADVISOR","Advisor"},
    {"COMBAT_PRESENTATION","CombatPresentation"}, {"COMBAT","Combat"},
    {"BOSS_MECHANICS_ASSISTANT","BossMechanicsAssistant"}, {"GAME_MODE_REPORT","GameModeReport"},
    {"ROTATION_ASSISTANT","RotationAssistant"}, {"MAINTENANCE","Maintenance"},
    {"UNIT_FRAMES","UnitFrames"}, {"TEAM_VISIBILITY","TeamVisibility"},
    {"DUNGEON_CHEST_FINDER","DungeonChestFinder"}, {"RESOURCE_PINS","ResourcePins"},
    {"TREASURE_LOCATOR","TreasureLocator"}, {"ANTIQUITY_ASSISTANT","AntiquityAssistant"},
    {"ANTIQUITY_LEAD_FINDER","AntiquityLeadFinder"}, {"ALLIANCE_RANK","AllianceRank"},
    {"CHAMPION_OVERLAY","ChampionOverlay"}, {"ABILITY_OVERLAYS","AbilityOverlays"},
    {"DUAL_ACTION_BAR","DualActionBar"}, {"QUICKSLOT_OVERLAY","QuickslotOverlay"},
    {"INFINITE_ARCHIVE_OVERLAY","InfiniteArchiveOverlay"}, {"SYNERGY_OVERLAY","SynergyOverlay"},
    {"CUSTOM_RETICLE","Reticle"}, {"REPAIR_COST_OVERLAY","RepairCostOverlay"},
    {"PERFORMANCE_OVERLAY","PerformanceOverlay"}, {"TICK_TRACKER","TickTracker"},
    {"ENCOUNTER_REMINDERS","EncounterReminders"}, {"OVERLAND_DIFFICULTY","OverlandDifficulty"},
    {"CHALLENGE_DIFFICULTY_OVERLAY","ChallengeDifficultyOverlay"}, {"STABLE_TIMER","StableTimer"},
    {"CLOCK","Clock"}, {"ACTIVE_QUEST","ActiveQuest"}, {"GOLDEN_PURSUITS","GoldenPursuits"},
    {"JOURNAL","Journal"}, {"MINI_MAP","MiniMap"}, {"UTILITY_SUITE","UtilitySuite"},
    {"INVENTORY_GRID","InventoryGrid"}, {"SKILL_MORPH_COMPARE","SkillMorphCompare"},
}

local LIBRARIES = {
    {"LibAddonMenu-2.0", function() return rawget(_G,"LibAddonMenu2") ~= nil end, true},
    {"LibMapData", function() return rawget(_G,"LibMapData") ~= nil end, true},
    {"LibGPS", function() return rawget(_G,"LibGPS3") ~= nil or rawget(_G,"LibGPS") ~= nil end, true},
    {"LibMapPins-1.0", function() return rawget(_G,"LibMapPins") ~= nil end, true},
    {"LibMapPing", function() return rawget(_G,"LibMapPing") ~= nil end, true},
    {"LibDebugLogger", function() return rawget(_G,"LibDebugLogger") ~= nil end, true},
    {"LibChatMessage", function() return rawget(_G,"LibChatMessage") ~= nil end, true},
    {"LibMainMenu-2.0", function() return rawget(_G,"LibMainMenu2") ~= nil or rawget(_G,"LibMainMenu") ~= nil end, true},
    {"LibCustomMenu", function() return rawget(_G,"LibCustomMenu") ~= nil or type(rawget(_G,"AddCustomMenuItem")) == "function" end, true},
    {"LibTreasure", function() return type(rawget(_G,"LibTreasure_GetMapIdData")) == "function" end, true},
    {"CustomCompassPins", function() return rawget(_G,"COMPASS_PINS") ~= nil end, true},
}

local function safeBool(fn)
    local ok, value = pcall(fn)
    return ok and value == true
end

local function countFunctions(object)
    if type(object) ~= "table" then return 0 end
    local n = 0
    for _, value in pairs(object) do
        if type(value) == "function" then n = n + 1 end
    end
    return n
end

local function getSuiteRuntimeBuild()
    local fallback = tonumber(EPC.addOnVersion) or 0
    if type(GetNumAddOns) == "function" and type(GetAddOnInfo) == "function" and type(GetAddOnVersion) == "function" then
        local okCount, count = pcall(GetNumAddOns)
        count = okCount and tonumber(count) or 0
        for i = 1, count do
            local okInfo, name = pcall(GetAddOnInfo, i)
            if okInfo and tostring(name or "") == tostring(EPC.name or "ESOAdventurerSuite") then
                local okVersion, build = pcall(GetAddOnVersion, i)
                if okVersion and tonumber(build) then return tonumber(build) end
                break
            end
        end
    end
    return fallback
end

local function sceneShowing(name)
    if not SCENE_MANAGER or type(SCENE_MANAGER.GetScene) ~= "function" then return false end
    local ok, scene = pcall(SCENE_MANAGER.GetScene, SCENE_MANAGER, name)
    if not ok or not scene or type(scene.IsShowing) ~= "function" then return false end
    local okShow, showing = pcall(scene.IsShowing, scene)
    return okShow and showing == true
end

local function statusRank(s)
    if s == "FAIL" then return 3 end
    if s == "WARN" then return 2 end
    if s == "SKIP" then return 1 end
    return 0
end

function T:EnsureReportWindow()
    if self.reportWindow then return self.reportWindow end
    if not WINDOW_MANAGER or not GuiRoot then return nil end

    local root = WINDOW_MANAGER:CreateTopLevelWindow("EAS_SelfTestReportWindow029467")
    root:SetDimensions(900, 650)
    root:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    root:SetDrawLayer(DL_OVERLAY)
    root:SetDrawLevel(1000)
    root:SetMouseEnabled(true)
    root:SetMovable(true)
    root:SetClampedToScreen(true)
    root:SetHidden(true)

    local bg = WINDOW_MANAGER:CreateControl("EAS_SelfTestReportBG029467", root, CT_BACKDROP)
    bg:SetAnchorFill(root)
    bg:SetCenterTexture("EsoUI/Art/Tooltips/UI-TooltipCenter.dds")
    bg:SetEdgeTexture("EsoUI/Art/Tooltips/UI-TooltipBorder.dds", 16, 4, 4)
    bg:SetCenterColor(0.015, 0.015, 0.02, 0.97)
    bg:SetEdgeColor(0.85, 0.68, 0.20, 0.95)

    local title = WINDOW_MANAGER:CreateControl("EAS_SelfTestReportTitle029467", root, CT_LABEL)
    title:SetFont("$(BOLD_FONT)|20|soft-shadow-thick")
    title:SetColor(1, 0.84, 0.28, 1)
    title:SetText("ESO Adventurer Suite - Self Test Report")
    title:SetAnchor(TOPLEFT, root, TOPLEFT, 18, 14)
    title:SetDimensions(700, 30)

    local hint = WINDOW_MANAGER:CreateControl("EAS_SelfTestReportHint029467", root, CT_LABEL)
    hint:SetFont("$(MEDIUM_FONT)|14|soft-shadow-thin")
    hint:SetColor(0.92, 0.92, 0.92, 1)
    hint:SetText("Click inside the report, press Ctrl+A, then Ctrl+C to copy it.")
    hint:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 2)
    hint:SetDimensions(760, 24)

    local close = WINDOW_MANAGER:CreateControl("EAS_SelfTestReportClose029467", root, CT_BUTTON)
    close:SetDimensions(82, 30)
    close:SetAnchor(TOPRIGHT, root, TOPRIGHT, -16, 12)
    close:SetFont("$(BOLD_FONT)|15|soft-shadow-thick")
    close:SetText("CLOSE")
    close:SetNormalFontColor(1, 0.84, 0.28, 1)
    close:SetMouseOverFontColor(1, 1, 1, 1)
    close:SetHandler("OnClicked", function() root:SetHidden(true) end)

    local edit = WINDOW_MANAGER:CreateControl("EAS_SelfTestReportEdit029467", root, CT_EDITBOX)
    edit:SetAnchor(TOPLEFT, root, TOPLEFT, 20, 74)
    edit:SetAnchor(BOTTOMRIGHT, root, BOTTOMRIGHT, -20, -20)
    edit:SetFont("$(MEDIUM_FONT)|14|soft-shadow-thin")
    edit:SetColor(1, 1, 1, 1)
    edit:SetMultiLine(true)
    if type(edit.SetMaxInputChars) == "function" then edit:SetMaxInputChars(REPORT_LIMIT) end
    edit:SetMouseEnabled(true)

    self.reportWindow = root
    self.reportEdit = edit
    return root
end

function T:ShowReport(report)
    local root = self:EnsureReportWindow()
    if not root or not self.reportEdit then
        if EPC.Print then EPC:Print("Self Test report window could not be created; report was printed to chat instead.") end
        self:PrintReport(report)
        return
    end
    report = tostring(report or self.lastReport or "No report has been generated yet.")
    if #report > REPORT_LIMIT then report = string.sub(report, 1, REPORT_LIMIT - 32) .. "\n...[report truncated for copy box]" end
    self.reportEdit:SetText(report)
    root:SetHidden(false)
    if type(self.reportEdit.TakeFocus) == "function" then pcall(self.reportEdit.TakeFocus, self.reportEdit) end
end

function T:PrintReport(report)
    report = tostring(report or self.lastReport or "")
    if report == "" then return end
    if type(d) == "function" then
        for line in string.gmatch(report .. "\n", "([^\n]*)\n") do d(line) end
    elseif EPC.Print then
        for line in string.gmatch(report .. "\n", "([^\n]*)\n") do EPC:Print(line) end
    end
end

function T:Run(showCopyWindow)
    local rows = {}
    local counts = {PASS=0, WARN=0, FAIL=0, SKIP=0}
    local worst = "PASS"
    local function add(status, name, detail)
        status = tostring(status or "PASS")
        counts[status] = (counts[status] or 0) + 1
        if statusRank(status) > statusRank(worst) then worst = status end
        rows[#rows + 1] = string.format("%-4s | %-28s | %s", status, tostring(name or ""), tostring(detail or ""))
    end

    local api = 0
    if type(GetAPIVersion) == "function" then
        local ok, value = pcall(GetAPIVersion)
        if ok then api = tonumber(value) or 0 end
    end
    add(EPC.saved and "PASS" or "FAIL", "SavedVariables", EPC.saved and "loaded" or "missing EPC.saved")
    add(type(EPC.Print)=="function" and "PASS" or "FAIL", "Core print path", type(EPC.Print)=="function" and "available" or "missing EPC:Print")
    local runtimeBuild = getSuiteRuntimeBuild()
    add("PASS", "Suite version", tostring(EPC.version or "unknown") .. " / build " .. tostring(runtimeBuild) .. " / API " .. tostring(api))

    -- Required libraries/dependencies.
    for _, lib in ipairs(LIBRARIES) do
        local ok = safeBool(lib[2])
        add(ok and "PASS" or (lib[3] and "FAIL" or "WARN"), lib[1], ok and "loaded" or "not detected")
    end

    -- Module presence + initialize/function surface + Compatibility state.
    local moduleFunctionCount = 0
    for _, item in ipairs(MODULES) do
        local compatName, key = item[1], item[2]
        local object = EPC[key] or rawget(_G, key) or (key == "InventoryGrid" and rawget(_G,"EASInventoryGrid"))
        local funcs = countFunctions(object)
        moduleFunctionCount = moduleFunctionCount + funcs
        local state = EPC.Compatibility and type(EPC.Compatibility.GetModuleState)=="function" and EPC.Compatibility:GetModuleState(compatName) or "UNKNOWN"
        if type(object) ~= "table" then
            add("FAIL", key, "module table missing")
        elseif funcs == 0 then
            add("WARN", key, "loaded but no callable functions found; compat=" .. tostring(state))
        elseif state == "DEGRADED" then
            local err = EPC.Compatibility and EPC.Compatibility.lastErrors and EPC.Compatibility.lastErrors[compatName] or ""
            add("FAIL", key, "compat=DEGRADED " .. tostring(err or ""))
        elseif state == "UNAVAILABLE" then
            add("WARN", key, "loaded, capability unavailable in current ESO API; functions=" .. funcs)
        else
            add("PASS", key, "loaded; functions=" .. funcs .. "; compat=" .. tostring(state))
        end
    end

    -- Compatibility capability matrix.
    if EPC.Compatibility and type(EPC.Compatibility.capabilities)=="table" then
        local missing = {}
        local available = 0
        for name, value in pairs(EPC.Compatibility.capabilities) do
            if value == true then available = available + 1 else missing[#missing+1] = tostring(name) end
        end
        table.sort(missing)
        if #missing == 0 then
            add("PASS", "API capabilities", tostring(available) .. " capability probes available")
        else
            add("WARN", "API capabilities", tostring(available) .. " available; missing: " .. table.concat(missing, ", "))
        end
    else
        add("FAIL", "API capabilities", "Compatibility capability table missing")
    end

    -- Current-session runtime errors only.
    local sessionErrors = tonumber(EPC.BugCatcher and EPC.BugCatcher.sessionCaught) or 0
    add(sessionErrors == 0 and "PASS" or "FAIL", "Current-session errors", sessionErrors == 0 and "none captured" or (tostring(sessionErrors) .. " captured; use /easbugs last"))

    -- Important security/taint guards introduced by recent fixes.
    local inv = rawget(_G,"EASInventoryGrid") or EPC.InventoryGrid
    if inv and inv.nativeCategoryCommitHook029364 == true then
        add("FAIL", "Skills secure path", "InventoryGrid global scroll-list hook flag is ON")
    else
        add("PASS", "Skills secure path", "Suite global ZO_ScrollList_Commit hook disabled")
    end
    local smc = EPC.SkillMorphCompare
    if smc and smc.disabledForSecureSkills029453 == true then
        add("PASS", "Skills morph taint barrier", "load-time hard barrier active; native Skills controls untouched")
    elseif smc then
        add("WARN", "Skills morph taint barrier", "secure-disable flag not detected")
    else
        add("SKIP", "Skills morph taint barrier", "SkillMorphCompare module not loaded")
    end

    -- Key UI objects that should exist after initialization.
    add(EPC.Settings and "PASS" or "FAIL", "Suite Settings", EPC.Settings and "module loaded" or "missing")
    add(EPC.MiniMap and "PASS" or "FAIL", "Mini Map", EPC.MiniMap and ("backend=" .. tostring(EPC.MiniMap.mapBackend or "not initialized")) or "missing")
    add(EPC.ResourcePins and "PASS" or "FAIL", "3D Resource Pins", EPC.ResourcePins and "module loaded" or "missing")
    add(EPC.CharacterGearScreen and "PASS" or "FAIL", "Character Gear Screen", EPC.CharacterGearScreen and "module loaded" or "missing")

    local loadoutUI = EPC.LoadoutManager
    if loadoutUI and type(loadoutUI.LayoutUI) == "function" and type(loadoutUI.EnsureWindowSaved) == "function" then
        local ok, savedWindow = pcall(loadoutUI.EnsureWindowSaved, loadoutUI)
        local layoutVersion = ok and type(savedWindow)=="table" and tonumber(savedWindow.layoutVersion) or 0
        add(layoutVersion >= 4 and "PASS" or "WARN", "Loadout compact UI",
            string.format("responsive layout v%d; ESO-style setup tabs expected", layoutVersion))
    else
        add("FAIL", "Loadout compact UI", "responsive layout surface unavailable")
    end

    local loadoutImporter = EPC.LoadoutManager
    if loadoutImporter and type(loadoutImporter.IsESOHubBuildString) == "function" then
        local sample = "1;3;1;51:13:0;0;13940;35,36,43;20805,23236,20944,20251,32853,32719;23231,61507,20668,32722,38312,83272;45011,45012,45023,45029,44922,44933,44951,44953,45188,45190,45192,45482,45471,45472,45473,45557,45549,45559,45561,45562,45564,45565,45567,45572,45574,45533,45526,45546,45528,45529,45590,45580,29062,35804,29061,55386,45614,45621,45619,45625,33293,45309,84672,45312,45573,44610,44615;92,66,82,0,265,13,25,264,270,34,275,57;6:20,10:20,11:20,14:20,15:20,16:20,17:40,18:40,20:20,21:30,22:30,37:30,38:20,39:20,40:30,42:16,43:30,44:6,45:30,50:20,53:50,58:50,99:20,108:20,113:20,128:20;0:3:163:13:68343,2:3:281:13:68343,3:2:163:12:68343,6:1:610:12:68343,16:2:695:12:68343,8:3:695:13:68343,9:3:695:13:68343,1:0:610:32:45885,11:0:610:33:45883,12:0:813:31:45884,4:11:695:26:26587,5:11:695:7:26848,20:3:610:1:26591,21:14:610:13:68343;153629;54339:8454917;"
        local ok, recognized = pcall(loadoutImporter.IsESOHubBuildString, loadoutImporter, sample)
        add(ok and recognized == true and "PASS" or "FAIL", "ESO-Hub build importer",
            ok and recognized == true and "Mattiverse 15-part addondata recognized" or "parser did not recognize Mattiverse addondata")
    else
        add("FAIL", "ESO-Hub build importer", "LoadoutManager parser unavailable")
    end

    local settings = EPC.Settings
    if settings and tonumber(settings.organizationVersion029786) >= 4 then
        add("PASS", "Settings feature organization", "nested feature ownership v3 active")
    else
        add("FAIL", "Settings feature organization", "feature ownership tree unavailable")
    end
    if settings and tonumber(settings.searchVersion029787) == 1
        and type(settings.RefreshSettingsSearch029787) == "function"
        and type(settings.JumpToSetting029787) == "function" then
        local count = type(settings.settingsSearchIndex029787) == "table" and #settings.settingsSearchIndex029787 or 0
        add(count > 0 and "PASS" or "WARN", "Settings search", string.format("search index entries=%d; direct jump available", count))
    else
        add("FAIL", "Settings search", "search index/direct jump surface unavailable")
    end
    do
        local found = false
        if settings and type(settings.settingsSearchIndex029787) == "table" then
            for _, entry in ipairs(settings.settingsSearchIndex029787) do
                if type(entry) == "table" and string.find(tostring(entry.path or ""), "Group Loot Notifier", 1, true) then
                    found = true
                    break
                end
            end
        end
        add(found and "PASS" or "FAIL", "Group Loot settings section",
            found and "dedicated searchable Group Loot Notifier section active" or "Group Loot Notifier settings missing from final feature tree")
    end

    local activeQuest = EPC.ActiveQuest
    if activeQuest and type(activeQuest.InstallQuestCycleHook029790) == "function" then
        local installed = activeQuest.questCycleHookInstalled029790 == true
        add(installed and "PASS" or "WARN", "Update 51 quest cycle compatibility",
            installed and "native HUD tracker key path hooked; no custom binding required"
                or "hook surface available but HUD tracker was not ready yet")
    else
        add("FAIL", "Update 51 quest cycle compatibility", "native HUD tracker hook unavailable")
    end

    local dungeonFinder = EPC.DungeonFinder
    if dungeonFinder and type(dungeonFinder.GetLiveQueueInfo029785) == "function"
        and type(dungeonFinder.GetQueuedDungeonText029785) == "function" then
        add("PASS", "Dungeon queue HUD live data", "live queue difficulty + queued dungeon resolver available")
    else
        add("FAIL", "Dungeon queue HUD live data", "live queue resolver unavailable")
    end

    local characterProfile = EPC.CharacterProfile
    if characterProfile and type(characterProfile.GetDiagnostics) == "function" then
        local ok, diag = pcall(characterProfile.GetDiagnostics, characterProfile)
        local healthy = ok and type(diag) == "table" and diag.activeCharacter ~= nil and diag.activeProfile == true
        add(healthy and "PASS" or "WARN", "Character settings profile",
            healthy and string.format("active=%s; profiles=%d; applied=%s", tostring(diag.activeCharacter), tonumber(diag.profileCount) or 0, tostring(diag.applied == true))
                or "character-scoped settings profile not fully initialized")
    else
        add("FAIL", "Character settings profile", "Architecture/CharacterProfile.lua unavailable")
    end

    local nativeHud = EPC.NativeHUDEditor
    if nativeHud and nativeHud.GetDiagnostics then
        local hudDiag = nativeHud:GetDiagnostics()
        local hudReady = hudDiag.available == true and (tonumber(hudDiag.registered) or 0) > 0
        add(hudReady and "PASS" or "WARN", "ESO Edit HUD integration",
            string.format("available=%s; registered=%d/%d; suiteOnly=%s; livePreview=%s",
                tostring(hudDiag.available == true),
                tonumber(hudDiag.registered) or 0, tonumber(hudDiag.configured) or 0,
                tostring(hudDiag.suiteOnlyEditor == true),
                tostring(hudDiag.livePreview == true))
            .. "; realPreview=" .. tostring(hudDiag.realControlPreview == true))
    else
        add("WARN", "ESO Edit HUD integration", "native HUD bridge unavailable")
    end

    -- Context-dependent systems: report SKIP rather than pretending they were executed.
    local bankOpen = sceneShowing("bank") or sceneShowing("guildBank") or sceneShowing("houseBank")
    add(bankOpen and "PASS" or "SKIP", "Bank live-context test", bankOpen and "bank scene is open; native category hooks can be exercised" or "open a bank and rerun to exercise live bank UI")
    local tradeOpen = sceneShowing("tradinghouse") or sceneShowing("tradingHouse")
    add(tradeOpen and "PASS" or "SKIP", "Trade live-context test", tradeOpen and "trading house scene is open" or "open a guild trader and rerun")
    local smithingOpen = sceneShowing("smithing")
    add(smithingOpen and "PASS" or "SKIP", "Craft/decon live-context test", smithingOpen and "smithing scene is open" or "open a crafting/deconstruction station and rerun")
    local skillsOpen = sceneShowing("skills") or sceneShowing("playerSkills")
    add(skillsOpen and "PASS" or "SKIP", "Skills live-context test", skillsOpen and "Skills scene open; drag an ability after this report to verify protected pickup" or "open Skills and rerun, then drag one ability")

    -- Lore subsystem.
    local lore = rawget(_G,"EASLoreLibrary")
    add(type(lore)=="table" and "PASS" or "WARN", "Lore Books subsystem", type(lore)=="table" and "loaded" or "not detected")

    local header = {
        "=== ESO ADVENTURER SUITE SELF TEST ===",
        "Version: " .. tostring(EPC.version or "unknown") .. " | AddOnVersion: " .. tostring(runtimeBuild) .. " | ESO API: " .. tostring(api),
        "Mode: SAFE DIAGNOSTIC (protected gameplay actions are not blindly executed)",
        "Function surface inspected: " .. tostring(moduleFunctionCount) .. " Suite module functions",
        "----------------------------------------",
    }
    local footer = {
        "----------------------------------------",
        string.format("RESULT: %s | PASS %d | WARN %d | FAIL %d | SKIP %d", worst == "FAIL" and "FAIL" or (worst == "WARN" and "PASS WITH WARNINGS" or "PASS"), counts.PASS, counts.WARN, counts.FAIL, counts.SKIP),
        "Current-session Bug Catcher errors: " .. tostring(sessionErrors),
        "SKIP means the feature needs a specific live ESO context (bank/station/skills/etc.) and was not falsely executed outside that context.",
        "Commands: /eastestall | /eastestall copy | /eastestall chat | /eastestall last",
        "=== END REPORT ===",
    }

    local all = {}
    for _, line in ipairs(header) do all[#all+1] = line end
    for _, line in ipairs(rows) do all[#all+1] = line end
    for _, line in ipairs(footer) do all[#all+1] = line end
    local report = table.concat(all, "\n")
    self.lastReport = report
    self.lastCounts = counts

    if EPC.Print then
        EPC:Print(string.format("EAS Self Test complete: PASS %d | WARN %d | FAIL %d | SKIP %d. A copyable report window is opening.", counts.PASS, counts.WARN, counts.FAIL, counts.SKIP))
        if counts.FAIL > 0 then EPC:Print("Self Test found failures. Copy the report and paste it into ChatGPT for diagnosis.") end
    end
    if showCopyWindow ~= false then self:ShowReport(report) end
    return report, counts
end

function T:HandleSlash(text)
    local arg = string.lower(tostring(text or ""))
    arg = string.match(arg, "^%s*(.-)%s*$") or ""
    if arg == "copy" then
        if not self.lastReport then self:Run(false) end
        self:ShowReport(self.lastReport)
    elseif arg == "chat" then
        if not self.lastReport then self:Run(false) end
        self:PrintReport(self.lastReport)
    elseif arg == "last" then
        if self.lastReport then self:ShowReport(self.lastReport)
        else self:Run(true) end
    elseif arg == "" or arg == "run" then
        self:Run(true)
    else
        if EPC.Print then EPC:Print("Self Test commands: /eastestall, /eastestall copy, /eastestall chat, /eastestall last") end
    end
end

function T:Initialize()
    if self.initialized then return end
    self.initialized = true
    if type(SLASH_COMMANDS) == "table" then
        SLASH_COMMANDS["/eastestall"] = function(text) self:HandleSlash(text) end
    end
end
