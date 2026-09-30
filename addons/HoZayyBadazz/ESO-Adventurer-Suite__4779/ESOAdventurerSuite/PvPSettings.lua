-- ESO Adventurer Suite
-- Unified PvP settings integration.
-- Adds one organized PvP category to the existing Suite settings panel.

local EPC = ESOProgressionCoach
if not EPC or not EPC.Settings then return end
local S = EPC.Settings
local P = EPC.PvP
if not P then return end

if S._easPvPSettings029753 then return end
S._easPvPSettings029753 = true


local function sv()
    return EPC.saved or EPC.defaults
end

local function refresh()
    if P and P.RefreshAll then P:RefreshAll() end
end

local function disabledByMaster()
    return sv().pvpEnabled029753 == false
end

local function sectionDisabled(key)
    return function()
        return disabledByMaster() or sv()[key] == false
    end
end

local function checkbox(name, key, tooltip, parentKey)
    local c = {
        type = "checkbox",
        name = name,
        tooltip = tooltip,
        getFunc = function() return sv()[key] ~= false end,
        setFunc = function(v) sv()[key] = v == true refresh() end,
        default = EPC.defaults[key],
        width = "full",
    }
    if parentKey then c.disabled = sectionDisabled(parentKey) else c.disabled = disabledByMaster end
    return c
end

local function slider(name, key, min, max, step, tooltip, parentKey)
    local c = {
        type = "slider",
        name = name,
        tooltip = tooltip,
        min = min, max = max, step = step,
        getFunc = function() return tonumber(sv()[key]) or tonumber(EPC.defaults[key]) or min end,
        setFunc = function(v) sv()[key] = tonumber(v) or min refresh() end,
        default = EPC.defaults[key],
        width = "full",
    }
    if parentKey then c.disabled = sectionDisabled(parentKey) else c.disabled = disabledByMaster end
    return c
end

local function header(name)
    return { type = "header", name = name, width = "full" }
end

local function description(title, text)
    return {
        type = "description",
        title = title,
        text = text,
        width = "full",
    }
end

local function subsection(name, controls)
    return {
        type = "submenu",
        name = name,
        controls = controls,
    }
end

local function buildPvPControls()
    local options = {
        description(
            "PvP Settings",
            "A role-neutral PvP suite for solo players, damage dealers, tanks, support players, bombers, small groups, large groups, Battlegrounds, Cyrodiil, Imperial City, Vengeance, and Duels. Every major subsystem has its own master switch, and every important feature underneath it remains individually toggleable. Turning a section off does not erase the settings inside that section."
        ),
        {
            type = "checkbox",
            name = "Enable PvP",
            tooltip = "Master switch for all ESO Adventurer Suite PvP systems.",
            getFunc = function() return sv().pvpEnabled029753 ~= false end,
            setFunc = function(v) sv().pvpEnabled029753 = v == true refresh() end,
            default = EPC.defaults.pvpEnabled029753,
            width = "full",
        },
        {
            type = "dropdown",
            name = "PvP preset",
            tooltip = "Presets change several PvP switches at once, but they never lock the settings. You can change any individual option afterward.",
            choices = { "Custom", "Minimal", "Solo PvP", "Small Group", "Large Group", "Battlegrounds", "Streamer" },
            choicesValues = { "CUSTOM", "MINIMAL", "SOLO", "SMALL_GROUP", "LARGE_GROUP", "BATTLEGROUNDS", "STREAMER" },
            getFunc = function() return sv().pvpPreset029753 or "CUSTOM" end,
            setFunc = function(v) if P and P.ApplyPreset then P:ApplyPreset(v) else sv().pvpPreset029753 = v end end,
            default = EPC.defaults.pvpPreset029753,
            width = "full",
            disabled = disabledByMaster,
        },
        checkbox("Only show PvP HUD systems in PvP areas", "pvpOnlyInPvP029753", "Hides Suite PvP HUD elements outside Cyrodiil, Imperial City, Battlegrounds, and other PvP contexts."),
        checkbox("Automatically use the appropriate PvP context", "pvpAutoProfile029753", "Lets the Suite detect Cyrodiil, Imperial City, Battlegrounds, and other PvP contexts automatically."),
        checkbox("Show PvP Status HUD", "pvpStatusHud029753", "Shows K/D/A, session AP, AP per hour, Tel Var risk where relevant, and current streak in one compact role-neutral panel."),
        slider("PvP Status scale", "pvpStatusHudScale029753", 0.65, 1.60, 0.05, "Scales the compact PvP Command Center panel."),
        slider("PvP Status opacity", "pvpStatusHudAlpha029753", 0.35, 1.00, 0.05, "Controls the opacity of the compact PvP Command Center panel."),
        checkbox("Show Battlefield Intelligence HUD", "pvpBattlefieldHud029754", "Shows context-aware Cyrodiil, Imperial City, Battleground, Vengeance, Alliance Rank, and Veterancy information in one movable panel."),
        slider("Battlefield Intelligence scale", "pvpBattlefieldScale029754", 0.65, 1.60, 0.05, "Scales the Battlefield Intelligence panel.", "pvpBattlefieldHud029754"),
        slider("Battlefield Intelligence opacity", "pvpBattlefieldAlpha029754", 0.35, 1.00, 0.05, "Controls the Battlefield Intelligence panel opacity.", "pvpBattlefieldHud029754"),
        {
            type = "button",
            name = "PvP HUD position",
            buttonText = "Reset Position",
            tooltip = "Resets the compact PvP HUD and kill feed to their default positions. Both can also be moved in Suite HUD Layout Mode.",
            func = function()
                local s = sv()
                s.pvpStatusHudLeft029753, s.pvpStatusHudTop029753 = -1, -1
                s.pvpKillFeedLeft029753, s.pvpKillFeedTop029753 = -1, -1
                if P and P.statusHud then P:RestorePosition(P.statusHud, "pvpStatusHudLeft029753", "pvpStatusHudTop029753", TOP, 0, 145) end
                if P and P.killFeed then P:RestorePosition(P.killFeed, "pvpKillFeedLeft029753", "pvpKillFeedTop029753", TOPRIGHT, -90, 210) end
                refresh()
            end,
            width = "full",
            disabled = disabledByMaster,
        },

        subsection("Combat Alerts", {
            description("Combat Alerts", "Incoming combat warnings are optional and role-neutral. Use only the categories you want; disabling Combat Alerts suspends the entire alert subsystem without changing the individual selections below."),
            checkbox("Enable Combat Alerts", "pvpCombatAlerts029753", "Master switch for PvP combat alerts."),
            checkbox("Incoming heavy attack warnings", "pvpAlertIncomingHeavy029753", "Warn when the Suite can identify an incoming heavy attack.", "pvpCombatAlerts029753"),
            checkbox("Crowd control warnings", "pvpAlertCrowdControl029753", "Warn for detected stuns, knockbacks, fears, silences, disorients, and roots.", "pvpCombatAlerts029753"),
            checkbox("Execute pressure warnings", "pvpAlertExecute029753", "Allow execute-range pressure warnings when the Suite can identify them.", "pvpCombatAlerts029753"),
            checkbox("Siege damage warnings", "pvpAlertSiege029753", "Allow warnings for detected incoming siege pressure.", "pvpCombatAlerts029753"),
            checkbox("Ultimate warnings", "pvpAlertUltimate029753", "Allow warnings for important hostile ultimate events when the ESO API exposes enough information.", "pvpCombatAlerts029753"),
            checkbox("Purge-worthy effect warnings", "pvpAlertPurge029753", "Allow high-priority warnings for selected negative effects.", "pvpCombatAlerts029753"),
            checkbox("Low-health warnings", "pvpAlertLowHealth029753", "Allow a low-health pressure warning.", "pvpCombatAlerts029753"),
            checkbox("Low-resource warnings", "pvpAlertLowResources029753", "Allow low Magicka or Stamina warnings.", "pvpCombatAlerts029753"),
            checkbox("Alert sounds", "pvpAlertSound029753", "Plays a short sound for important PvP alerts.", "pvpCombatAlerts029753"),
            checkbox("Screen-flash alerts", "pvpAlertScreenFlash029753", "Allows a stronger visual flash for critical alerts. Off by default.", "pvpCombatAlerts029753"),
            slider("Alert scale", "pvpAlertScale029753", 0.65, 1.60, 0.05, "Scales PvP alert text.", "pvpCombatAlerts029753"),
            slider("Alert duration (ms)", "pvpAlertDuration029753", 600, 4000, 100, "How long a PvP alert remains visible.", "pvpCombatAlerts029753"),
        }),

        subsection("Player & Target Awareness", {
            description("Player & Target Awareness", "Tracks useful PvP encounter information without assigning any combat role. Awareness features remain configurable independently."),
            checkbox("Enable Player & Target Awareness", "pvpPlayerAwareness029753", "Master switch for enemy and target-awareness features."),
            checkbox("Nearby enemy count", "pvpEnemyCount029753", "Show nearby hostile-player count when reliable data is available.", "pvpPlayerAwareness029753"),
            checkbox("Recent attackers", "pvpRecentAttackers029753", "Remember recent hostile players who directly interacted with you.", "pvpPlayerAwareness029753"),
            checkbox("Enemy class and alliance", "pvpEnemyClassAlliance029753", "Show class/alliance information when the ESO API exposes it.", "pvpPlayerAwareness029753"),
            checkbox("Target intelligence panel", "pvpTargetIntelligence029753", "Show PvP information for the current player target when available.", "pvpPlayerAwareness029753"),
            checkbox("Watch / Rival / Friendly list support", "pvpWatchList029753", "Enable local personal player labels and encounter notifications.", "pvpPlayerAwareness029753"),
        }),

        subsection("Group Awareness", {
            description("Group Awareness", "This section is intentionally not tied to healer, tank, or damage roles. Players choose exactly which group-state signals they want to see."),
            checkbox("Enable Group Awareness", "pvpGroupAwareness029753", "Master switch for role-neutral PvP group awareness."),
            checkbox("Group health pressure", "pvpGroupHealthPressure029753", "Emphasize group members under heavy health pressure.", "pvpGroupAwareness029753"),
            checkbox("Deaths", "pvpGroupDeaths029753", "Track dead group members.", "pvpGroupAwareness029753"),
            checkbox("Resurrection status", "pvpGroupResurrection029753", "Show resurrection-related group status when available.", "pvpGroupAwareness029753"),
            checkbox("Range status", "pvpGroupRange029753", "Show useful range state where ESO exposes it.", "pvpGroupAwareness029753"),
            checkbox("Ultimate readiness", "pvpGroupUltimate029753", "Show group ultimate readiness where available.", "pvpGroupAwareness029753"),
            checkbox("Important buffs / debuffs", "pvpGroupBuffs029753", "Show selected important group effects.", "pvpGroupAwareness029753"),
            checkbox("Crown / leader emphasis", "pvpGroupCrown029753", "Emphasize the group leader/crown.", "pvpGroupAwareness029753"),
        }),

        subsection("Kill Feed, Streaks & Bombs", {
            description("Kill Feed, Streaks & Bombs", "A Suite-native PvP kill feed with session streaks, multi-kills, and bomb tracking. Filters let players keep the feed quiet or broad."),
            checkbox("Enable Kill Feed", "pvpKillFeed029753", "Master switch for the Suite PvP kill feed."),
            checkbox("Show my kills and deaths", "pvpKillFeedSelf029753", "Show events directly involving your character.", "pvpKillFeed029753"),
            checkbox("Show group kill events", "pvpKillFeedGroup029753", "Allow group-related kill events when detectable.", "pvpKillFeed029753"),
            checkbox("Show all visible PvP kill-feed events", "pvpKillFeedEveryone029753", "Broad feed mode. Off by default to reduce clutter.", "pvpKillFeed029753"),
            checkbox("Show killing ability when available", "pvpKillFeedAbility029753", "Appends the killing ability when ESO provides it.", "pvpKillFeed029753"),
            checkbox("Show AP with kill events when available", "pvpKillFeedAP029753", "Allows AP information to be associated with kill events.", "pvpKillFeed029753"),
            checkbox("Track kill streaks", "pvpStreaks029753", "Tracks current and best session kill streaks."),
            checkbox("Track multi-kills", "pvpMultiKills029753", "Tracks kills occurring close together and displays multi-kill callouts."),
            checkbox("Track bombs / rapid multi-kills", "pvpBombTracker029753", "Keeps rapid multi-kill records for bomb-style engagements."),
            slider("Kill-feed scale", "pvpKillFeedScale029753", 0.65, 1.60, 0.05, "Scales the Suite PvP kill feed.", "pvpKillFeed029753"),
            slider("Kill-feed line duration (ms)", "pvpKillFeedDuration029753", 2000, 15000, 500, "How long each kill-feed line remains visible.", "pvpKillFeed029753"),
        }),

        subsection("Cyrodiil", {
            description("Cyrodiil", "Cyrodiil battlefield information is grouped here so the player can turn the entire category off or select only the objective information they care about."),
            checkbox("Enable Cyrodiil features", "pvpCyrodiil029753", "Master switch for Suite Cyrodiil features."),
            checkbox("Campaign information", "pvpCyrodiilCampaign029753", "Campaign score/population/reward information when available.", "pvpCyrodiil029753"),
            checkbox("Keep information", "pvpCyrodiilKeeps029753", "Keep ownership and under-attack information.", "pvpCyrodiil029753"),
            checkbox("Resource information", "pvpCyrodiilResources029753", "Farm, mine, and lumbermill objective information.", "pvpCyrodiil029753"),
            checkbox("Elder Scroll information", "pvpCyrodiilScrolls029753", "Scroll state and location information when exposed.", "pvpCyrodiil029753"),
            checkbox("Emperor information", "pvpCyrodiilEmperor029753", "Emperor/campaign information.", "pvpCyrodiil029753"),
            checkbox("Capture progress", "pvpCyrodiilCapture029753", "Objective capture progress when available.", "pvpCyrodiil029753"),
            checkbox("Forward camps", "pvpCyrodiilCamps029753", "Forward-camp status and related map/world information.", "pvpCyrodiil029753"),
            checkbox("Siege assistant information", "pvpCyrodiilSiege029753", "Siege readiness/inventory/pressure information where the API allows it.", "pvpCyrodiil029753"),
            checkbox("Offensive / defensive AP ticks", "pvpCyrodiilTicks029753", "Track Cyrodiil AP ticks as part of the PvP session.", "pvpCyrodiil029753"),
        }),

        subsection("Imperial City", {
            description("Imperial City", "Tel Var risk, session gain/loss, and district information are separated from normal Cyrodiil controls."),
            checkbox("Enable Imperial City features", "pvpImperialCity029753", "Master switch for Imperial City features."),
            checkbox("Tel Var HUD", "pvpTelVarHud029753", "Show current carried Tel Var in the compact PvP HUD.", "pvpImperialCity029753"),
            checkbox("Tel Var risk level", "pvpTelVarRisk029753", "Adds a simple LOW / ELEVATED / HIGH / EXTREME risk label based on carried Tel Var.", "pvpImperialCity029753"),
            checkbox("Tel Var session gains / losses", "pvpTelVarSession029753", "Track Tel Var changes during the current Imperial City session.", "pvpImperialCity029753"),
            checkbox("District information", "pvpICDistricts029753", "Allow district ownership/objective information when available.", "pvpImperialCity029753"),
        }),

        subsection("Battlegrounds", {
            description("Battlegrounds", "Live match information and persistent match history live together here. All features remain optional."),
            checkbox("Enable Battleground features", "pvpBattlegrounds029753", "Master switch for Suite Battleground features."),
            checkbox("Battleground HUD", "pvpBGHud029753", "Show Suite Battleground match information.", "pvpBattlegrounds029753"),
            checkbox("Team / match score", "pvpBGScore029753", "Show score information when available.", "pvpBattlegrounds029753"),
            checkbox("K/D/A", "pvpBGKDA029753", "Show Battleground kills, deaths, and assists.", "pvpBattlegrounds029753"),
            checkbox("Medals", "pvpBGMedals029753", "Show medal information when exposed by ESO.", "pvpBattlegrounds029753"),
            checkbox("Objective information", "pvpBGObjectives029753", "Show mode-specific objective information when available.", "pvpBattlegrounds029753"),
            checkbox("Save match history", "pvpBGHistory029753", "Store compact local Battleground match summaries.", "pvpBattlegrounds029753"),
            checkbox("Battleground analytics", "pvpBGAnalytics029753", "Use saved match history for local performance summaries.", "pvpBattlegrounds029753"),
        }),

        subsection("Vengeance", {
            description("Vengeance", "Dedicated switches for the permanent Vengeance PvP environment, kept separate so its altered rules can be handled without changing normal Cyrodiil settings."),
            checkbox("Enable Vengeance features", "pvpVengeance029753", "Master switch for Vengeance-specific support."),
            checkbox("Vengeance HUD adjustments", "pvpVengeanceHud029753", "Allow Vengeance-specific HUD behavior.", "pvpVengeance029753"),
            checkbox("Vengeance / Veterancy progression", "pvpVengeanceProgress029753", "Allow Vengeance-related progression information when exposed by ESO.", "pvpVengeance029753"),
        }),

        subsection("Duels", {
            description("Duels", "Optional duel history and opponent information. This remains separate from Cyrodiil/Battleground statistics."),
            checkbox("Enable Duel features", "pvpDuels029753", "Master switch for duel tracking."),
            checkbox("Save duel history", "pvpDuelHistory029753", "Store compact local duel summaries.", "pvpDuels029753"),
            checkbox("Opponent record", "pvpDuelOpponent029753", "Show prior local duel record against the current opponent when available.", "pvpDuels029753"),
        }),

        subsection("Alliance Points & Veterancy", {
            description("Alliance Points & Veterancy", "Session AP, AP/hour, Alliance Rank, and PvP Veterancy progression controls."),
            checkbox("Enable AP & Veterancy tracking", "pvpAPVeterancy029753", "Master switch for AP and Veterancy tracking."),
            checkbox("Session AP", "pvpAPSession029753", "Track AP gained during the active PvP session.", "pvpAPVeterancy029753"),
            checkbox("AP per hour", "pvpAPPerHour029753", "Show an AP/hour estimate based on the current session.", "pvpAPVeterancy029753"),
            checkbox("Alliance Rank progress", "pvpAllianceRankProgress029753", "Allow Alliance Rank progress information.", "pvpAPVeterancy029753"),
            checkbox("PvP Veterancy progress", "pvpVeterancyProgress029753", "Allow PvP Veterancy progress information when exposed by ESO.", "pvpAPVeterancy029753"),
        }),

        subsection("Statistics, History & Records", {
            description("Statistics, History & Records", "Local PvP statistics are designed to explain your sessions, not dictate a role or build."),
            checkbox("Enable PvP statistics", "pvpStatistics029753", "Master switch for PvP statistics."),
            checkbox("Save session summaries", "pvpSessionSummary029753", "Save compact local summaries when leaving a PvP context.", "pvpStatistics029753"),
            checkbox("Lifetime K/D/A", "pvpLifetimeKDA029753", "Maintain local lifetime PvP K/D/A totals.", "pvpStatistics029753"),
            checkbox("Class breakdown", "pvpClassBreakdown029753", "Allow statistics by opponent class when enough API data is available.", "pvpStatistics029753"),
            checkbox("Enhanced death recap data", "pvpDeathRecap029753", "Allow a local recent-combat timeline for PvP death review.", "pvpStatistics029753"),
            checkbox("Save build snapshot with PvP sessions", "pvpBuildSnapshot029753", "Allow compact build-context snapshots for PvP history.", "pvpStatistics029753"),
            checkbox("Personal records", "pvpPersonalRecords029753", "Track local records such as best streak and best rapid multi-kill.", "pvpStatistics029753"),
            checkbox("Combat statistics", "pvpCombatStats029754", "Track role-neutral PvP combat totals for damage, healing, and crowd control.", "pvpStatistics029753"),
            checkbox("Damage dealt / taken", "pvpCombatStatsDamage029754", "Track session damage dealt, incoming damage, and largest hits.", "pvpCombatStats029754"),
            checkbox("Healing done / received", "pvpCombatStatsHealing029754", "Track session healing without assuming a healer role.", "pvpCombatStats029754"),
            checkbox("Crowd-control statistics", "pvpCombatStatsCrowdControl029754", "Track crowd-control events applied and received.", "pvpCombatStats029754"),
        }),

        subsection("3D World Markers", {
            description("3D World Markers", "Uses the Suite marker philosophy: distance-capped, count-capped, individually toggleable, and performance-aware."),
            checkbox("Enable PvP 3D markers", "pvp3DMarkers029753", "Master switch for Suite PvP 3D world markers."),
            checkbox("Objectives", "pvp3DObjectives029753", "Allow objective 3D markers.", "pvp3DMarkers029753"),
            checkbox("Group crown", "pvp3DGroupCrown029753", "Allow group-leader/crown emphasis.", "pvp3DMarkers029753"),
            checkbox("Forward camps", "pvp3DCamps029753", "Allow camp-related 3D markers.", "pvp3DMarkers029753"),
            checkbox("Rally points", "pvp3DRally029753", "Allow rally-point 3D markers.", "pvp3DMarkers029753"),
            checkbox("Elder Scrolls", "pvp3DScrolls029753", "Allow Elder Scroll 3D markers when location information is available.", "pvp3DMarkers029753"),
            slider("Maximum 3D marker distance", "pvp3DDistance029753", 75, 1200, 25, "Maximum distance used by Suite PvP 3D marker systems.", "pvp3DMarkers029753"),
            slider("Maximum visible PvP 3D markers", "pvp3DMaxVisible029753", 4, 48, 1, "Hard cap to protect FPS during large fights.", "pvp3DMarkers029753"),
        }),

        subsection("Map & Mini Map", {
            description("Map & Mini Map", "Choose exactly which PvP layers are allowed on the Suite map/minimap systems."),
            checkbox("Enable PvP map layers", "pvpMap029753", "Master switch for Suite PvP map/minimap layers."),
            checkbox("Objectives", "pvpMapObjectives029753", "Allow PvP objectives on supported map views.", "pvpMap029753"),
            checkbox("Group members", "pvpMapGroup029753", "Allow PvP group information on supported map views.", "pvpMap029753"),
            checkbox("Forward camps", "pvpMapCamps029753", "Allow forward camps on supported map views.", "pvpMap029753"),
            checkbox("Elder Scrolls", "pvpMapScrolls029753", "Allow Elder Scroll information on supported map views.", "pvpMap029753"),
            checkbox("Danger / pressure markers", "pvpMapDanger029753", "Allow Suite-generated PvP danger indicators when supported by reliable data.", "pvpMap029753"),
            checkbox("Active battle locations", "pvpMapActiveBattles029754", "Shows ESO-reported PvP kill-location activity as Suite map pins.", "pvpMap029753"),
        }),

        subsection("Notifications", {
            description("Notifications", "PvP notifications use Suite-style concise alerts and remain independently configurable."),
            checkbox("Enable PvP notifications", "pvpNotifications029753", "Master switch for PvP notifications."),
            checkbox("Objective notifications", "pvpNotifyObjective029753", "Allow objective-state notifications.", "pvpNotifications029753"),
            checkbox("Keep notifications", "pvpNotifyKeep029753", "Allow keep attack/capture notifications.", "pvpNotifications029753"),
            checkbox("Watch-list notifications", "pvpNotifyWatch029753", "Notify when a locally watched player is encountered, when detectable.", "pvpNotifications029753"),
            checkbox("Personal-record notifications", "pvpNotifyRecord029753", "Notify when a local PvP record is broken.", "pvpNotifications029753"),
        }),

        subsection("Performance", {
            description("Performance", "Large PvP fights can generate a huge number of events. These controls cap work, history, and 3D output instead of allowing the PvP module to become an FPS problem."),
            checkbox("Enable PvP performance controls", "pvpPerformance029753", "Master switch for adaptive PvP performance safeguards."),
            checkbox("Large Battle Performance Mode", "pvpLargeBattleMode029753", "Uses stricter caps and quieter presentation for large-scale fights.", "pvpPerformance029753"),
            checkbox("Adaptive refresh", "pvpAdaptiveRefresh029753", "Keeps normal refresh work conservative and only increases responsiveness where useful.", "pvpPerformance029753"),
            checkbox("Reduce nonessential animations", "pvpReduceAnimations029753", "Reduces visual animation work during PvP. Off by default.", "pvpPerformance029753"),
            slider("Maximum tracked players", "pvpMaxTrackedPlayers029753", 16, 128, 8, "Hard cap for local encounter/player caches.", "pvpPerformance029753"),
            slider("Maximum saved PvP history entries", "pvpHistoryLimit029753", 25, 1000, 25, "Limits stored local session/history records so SavedVariables stay controlled.", "pvpPerformance029753"),
        }),
    }

    -- v0.29.758: keep the PvP page easy to scan. The original feature sections
    -- remain intact below, but they are grouped into five clear categories instead
    -- of presenting a long wall of individual submenus.
    local overview = options[1]
    local generalControls = {}
    local sections = {}

    for i, option in ipairs(options) do
        if i > 1 then
            if option.type == "submenu" and option.name then
                sections[option.name] = option
            else
                generalControls[#generalControls + 1] = option
            end
        end
    end

    local function appendSectionControls(target, sectionName)
        local section = sections[sectionName]
        if not section or type(section.controls) ~= "table" then return end

        target[#target + 1] = {
            type = "header",
            name = sectionName,
            width = "full",
        }

        for _, control in ipairs(section.controls) do
            if control.type == "description" then
                -- The group header already names the feature. Keep only the useful
                -- explanation text so the section does not repeat its title twice.
                control.title = nil
                control.width = "full"
            end
            target[#target + 1] = control
        end
    end

    local combatControls = {}
    appendSectionControls(combatControls, "Combat Alerts")
    appendSectionControls(combatControls, "Player & Target Awareness")
    appendSectionControls(combatControls, "Group Awareness")
    appendSectionControls(combatControls, "Kill Feed, Streaks & Bombs")

    local modeControls = {}
    appendSectionControls(modeControls, "Cyrodiil")
    appendSectionControls(modeControls, "Imperial City")
    appendSectionControls(modeControls, "Battlegrounds")
    appendSectionControls(modeControls, "Vengeance")
    appendSectionControls(modeControls, "Duels")

    local progressControls = {}
    appendSectionControls(progressControls, "Alliance Points & Veterancy")
    appendSectionControls(progressControls, "Statistics, History & Records")

    local displayControls = {}
    appendSectionControls(displayControls, "3D World Markers")
    appendSectionControls(displayControls, "Map & Mini Map")
    appendSectionControls(displayControls, "Notifications")
    appendSectionControls(displayControls, "Performance")

    return {
        overview,
        subsection("General & HUD", generalControls),
        subsection("Combat & Awareness", combatControls),
        subsection("PvP Modes", modeControls),
        subsection("Progress & Records", progressControls),
        subsection("Map, Markers & Performance", displayControls),
    }
end

local function insertPvPSubmenu(options)
    if type(options) ~= "table" then return end

    -- Add PvP after Combat so related settings stay near each other while still
    -- having a dedicated top-level category.
    local insertAt = #options + 1
    for i, option in ipairs(options) do
        if option and option.type == "submenu" and option.name == "Combat Advisor & Boss Mechanics" then
            insertAt = i + 1
            break
        end
    end

    table.insert(options, insertAt, {
        type = "submenu",
        name = "PvP",
        tooltip = "Role-neutral Cyrodiil, Imperial City, Battleground, Vengeance, Duel, combat-alert, kill-feed, statistics, marker, and PvP performance controls.",
        controls = buildPvPControls(),
    })
end

S:RegisterOptionsExtension("PvP", function(options)
    insertPvPSubmenu(options)
end, 200)