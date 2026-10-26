---------------------------------------------------------------------
-- DM2_ParseFightStats.lua — menu-first stats viewer (legacy overlay removed)
-- "DM2 Parse & Fight Stats" — capture, history, gamepad menu
--
-- Goals (v1):
--  • Track fight sessions (outgoing damage), store history (ring buffer, default 20)
--  • 2s rolling buckets to find top 2 spikes and bottom 2 dips
--  • Crit sustain overall + per spike/dip bucket
--  • Skill damage breakdown grid (amount, hits, avg hit, crit%, dps, dot/direct split)
--  • Buff uptime grid with source hints (Skill/Set/Self/External) for player's effects
--  • Light attack weaving readout using confirmed LA-hit rhythm and interval health
--  • Slash commands: /dm2stats, /dm2statsshow, /dm2statshide, /dm2statsclear
--
-- Notes:
--  • Set attribution (armor/weapon sets) is non-trivial; v1 focuses on skill/ability IDs.
--  • LAW uses server-confirmed light attack hit timing; skill timing remains approximate.
---------------------------------------------------------------------

DM2Stats = DM2Stats or {}
local R = DM2Stats

R.name        = "DM2_ParseFightStats"
R.displayName = "DM2 Parse & Fight Stats"
R.version     = "3.18.4"

-- Keep the original SV name so existing parse history is preserved for all users.
-- v3.17.4: auto-compact history after load (strip bulk combat tables, keep outcomes/coach).
-- Note: if a file is so huge the client dies *during* SV parse, that rare case still needs
-- a one-time clear — normal users with older history compact in place and keep fights.
R.ns          = "DM2_ParseFightStats_SV"

local EM = EVENT_MANAGER
local WM = WINDOW_MANAGER

-- ----------------------------
-- Safe console UI check
-- ----------------------------
local function isConsoleUI()
  -- Console/gamepad detection differs a bit across platforms/builds.
  if type(IsConsoleUI) == "function" then return IsConsoleUI() end
  if type(ZO_IsConsoleUI) == "function" then return ZO_IsConsoleUI() end
  -- Fallback for gamepad-mode UIs (works on PC gamepad + consoles)
  if type(IsInGamepadPreferredMode) == "function" then return IsInGamepadPreferredMode() end
  if type(IsInGamepadMode) == "function" then return IsInGamepadMode() end
  return false
end

-- ----------------------------
-- Defaults / SavedVars
-- ----------------------------
R.defaults = {
  settings = {
    enable = true,
    autoPopupAfterParse = true,
    resultsPopupDelaySecs = 2, -- delay stats popup after fight ends (0-5)
    autoCloseSecs = 0,    -- unused (legacy overlay removed; kept for old SV files)

    historyMax = 20,        -- ring buffer 1..20; newest is always #1, oldest rolls off
    bucketMs = 2000,

    -- Heuristics
    minFightMs = 8000,      -- ignore tiny skirmishes
    minDamage = 50000,
    -- When false: only start captures that look like dummy/housing parses (saves open-world spam)
    trackOpenWorld = true,

    -- Spike detection window exclusions
    ignoreFirstMs = 2000,
    ignoreLastMs  = 1500,

    -- Weaving heuristics
    weaveFollowMs = 1500,
    weavePocketMinMs = 350,
    weavePocketMaxMs = 900,


    -- Weave detection tuning (latency-adjusted)
    weaveMinLeadMs = 30,
    weaveWindowMaxMs = 0,      -- 0 = auto (1000ms + latency pad)
    queueOverwriteMs = 450,
    -- Dummy/parse detection
    dummyStrict = false,    -- false = name OR housing; true = name AND housing
    debugRotation = false,  -- /dm2stats debug — capture skip/press counts on session
    showWeaveFlash = false, -- real-time weave quality flash at screen center during combat
    weaveFlashSize = 36,    -- font size for weave flash (20-52)
    weaveFlashDuration = 500, -- flash duration in ms (200-800)
    weaveFlashSound = false,  -- play a sound cue on each weave result
    showRaidStrip = true,          -- left-side strip in dungeons/trials
    showRaidStripOnDummy = true,   -- left-side strip in housing / dummy parses (independent)
    -- v3.5.0: gamepad menu shell entry in Journal (still used)
    experimentalGamepadMenu = true,
    -- unused (legacy overlay removed; kept for old SV files)
    statsViewer = "menu",
  },
  ui = {
    x = 120,
    y = 120,
    w = 1400,
    h = 920,
    locked = false,
    bgAlpha = 0.65,   -- background opacity (0.0 = transparent, 1.0 = solid)
  },
  history = {},
  lastIndex = 0,
  lastAnnouncementVersion = "",
  -- Phase 2.5 scaffold: one active controlled experiment at a time (filled by menu coach)
  experiments = {
    active = nil, -- { id, ruleId, title, baselineFingerprint, changeDetail, targetRuns, runs = {} }
  },
}

local SV = nil

-- Weave timeline symbols (ESO color markup, ASCII-safe)
local SYM_OK        = "+"       -- good weave
local SYM_LATE      = "~"       -- late weave
local SYM_MISS      = "x"       -- missed weave
local SYM_FAST      = ">>"      -- too fast
local SYM_EXTRA     = "*"       -- extra LA
local SYM_CHANNEL   = "---"     -- channel pause
local SYM_POST_OK   = "+"       -- post-channel recovered
local SYM_POST_MISS = "x"       -- post-channel missed

-- ----------------------------
-- Runtime state
-- ----------------------------
R.inCombat = false
R.session = nil
R._pendingPopupToken = 0
R._weaveFlashToken = 0    -- debounce token for timed flash hide
R._announcementToken = 0  -- debounce token for announcement auto-dismiss

-- ----------------------------
-- Version announcements (shown once per version string at login)
-- To add a future announcement: add an entry below and update _latestAnnouncementVersion.
-- ----------------------------
R._announcements = {
  ["3.2.0"] = {
    title = "NEW: Weave Flash Training!",
    body = "Real-time Good / Late / Missed feedback flashes at\nscreen center during combat. Great for learning\nthe LA weave rhythm.\n\nEnable in addon Settings > Weave Flash.",
  },
  ["3.2.2"] = {
    title = "NEW: Visual Upgrades & Analytics!",
    body = "Pulse Strip: colored blocks show weave health at a glance.\nDPS Sparkline: bar chart of DPS over time on Summary page.\nPer-Skill Weave: see which skills you weave best/worst.\nDOT Uptime: tracks how well you maintain your DOTs.\nBar-colored skills: Front bar green, Back bar blue in timeline.",
  },
  ["3.2.7"] = {
    title = "NEW: Sound Cues, Chat Export & More!",
    body = "Weave Sound Cue: optional audio chime/alert per weave result.\nEnable in Settings > Weave Flash > Sound Cue.\n\nExport to Chat: /dm2stats share posts a parse summary.\n\nWeave Analysis: per-skill and DOT tables now on their own page.",
  },
  ["3.2.15"] = {
    title = "FIX & NEW: Set Contribution + Skill Icons!",
    body = "Null Arca / Sliver Assault now shows correctly in Set Contribution.\n\nSkill icons: the Overview Top Damage Skills table now shows ability icons.\nMore visual polish is coming in future updates.",
  },
  ["3.2.16"] = {
    title = "FIX: Top Skills Table Alignment",
    body = "Skill names were missing from the Overview Top Damage Skills table\nafter icons were added. Columns are aligned again.\n\nIcons on that table are unchanged.",
  },
  ["3.2.17"] = {
    title = "NEW: Skill Icons on More Tables!",
    body = "Ability icons now appear on:\n• Damage Breakdown\n• Buffs / Uptime\n• Weave Analysis (per-skill + DOT uptime)\n\nOverview Top Damage Skills already had icons from 3.2.15.",
  },
  ["3.2.18"] = {
    title = "FIX: UI Error on Parse Open",
    body = "Fixed a crash when opening the stats viewer after a parse.\n\nSkill icons on all tables from 3.2.17 are unchanged.",
  },
  ["3.2.19"] = {
    title = "NEW: Front / Back Bar Chips!",
    body = "Skill rows now show a small color chip:\nGreen = front bar, Blue = back bar.\n\nA legend appears above each skill table.\nMatches the timeline colors on Rotation Diagnostics.",
  },
  ["3.2.20"] = {
    title = "FIX: Back Bar Chips & Legend!",
    body = "Back bar (blue) chips now appear reliably on all skill tables,\nincluding buffs, DOTs, and damage from alternate ability IDs.\n\nLegend uses real color swatches instead of missing font glyphs.",
  },
  ["3.2.21"] = {
    title = "FIX: Combat Start Crash!",
    body = "Fixed a crash on first hit when capturing slotted ability bars.\n\nBar chips and legend from 3.2.20 are unchanged.",
  },
  ["3.2.22"] = {
    title = "FIX: Weave Skill Names [7] / [12]",
    body = "Weave Analysis no longer shows bracketed slot placeholders\nwhen the console API returns [N] instead of a skill name.\n\nNames re-resolve after the fight using the captured ability ID.",
  },
  ["3.2.23"] = {
    title = "FIX: Last Missing Weave Skill Name",
    body = "Console placeholders like [7] are no longer cached as skill names.\n\nWeave rows now fall back to the fight-start bar snapshot\n(slot + bar) when ability lookup still fails.",
  },
  ["3.3.5"] = {
    title = "NEW: Damage Share Bars!",
    body = "Contribution columns now show proportional share bars\nbehind the percentage on skill and set proc tables.\n\nOverview top skills, Damage Breakdown, Set Contribution,\nand Proc Analysis all updated.",
  },
  ["3.4.0"] = {
    title = "NEW: 3-Hub Navigation + Parse Trends!",
    body = "L1/R1 now switches 3 hubs: Overview, Combat Analysis,\nand Build & History (scroll for sub-sections).\n\nDummy parse trend chart below the comparison table.\nCircle/O closes the viewer. Debug log hidden from UI.",
  },
  ["3.4.1"] = {
    title = "FIX: Console Page Navigation Restored!",
    body = "L1/R1 again steps through all 8 sections (one page each),\nlike before 3.4.0 — works on PS5 without scrolling.\n\nKeeps: dummy parse trend chart, history list fix,\nCircle/O close, and hidden debug UI.",
  },
  ["3.4.9"] = {
    title = "FIX: List Rows No Longer Cut Off!",
    body = "List panels are slightly taller at the bottom so the last\nrow or two is not clipped with a dead scrollbar.\n\nApplies to Damage Breakdown, Buffs, Gear, and other tables.",
  },
  ["3.5.0"] = {
    title = "NEW: Experimental Gamepad Menu!",
    body = "Open stats in a native gamepad menu scene:\n/dm2stats menu  (console gamepad mode)\n\nPhase 1: Overview + L2/R2 fight history + O/back.\nExisting post-parse overlay is unchanged.",
  },
  ["3.5.1"] = {
    title = "NEW: Menu Skills + Layout Polish!",
    body = "Gamepad menu Phase 2:\n• Skills section — top damage skills with icons\n• Stick select Overview / Skills on the left rail\n• Content plate nudged right (less left-edge bleed)\n\nL2/R2 history and O/back unchanged.",
  },
  ["3.6.0"] = {
    title = "NEW: Full Gamepad Menu Review Build!",
    body = "Experimental menu now has all four sections:\n• Overview — encounter KPIs\n• Dashboard — fight + bars + gear snapshot\n• Skills — top damage with icons\n• Trends — dummy sparklines + recent list\n\nOpen: /dm2stats menu  (gamepad mode)\nL2/R2 fights · O/back · overlay unchanged.",
  },
  ["3.7.0"] = {
    title = "NEW: Full Menu Content Preview!",
    body = "Experimental gamepad menu now covers the full parse surface:\n• Overview, Dashboard, Damage, Weave, Buffs\n• Gear, Procs, Rotation, History\n\nStill preview-only (settings button / /dm2stats menu).\nPost-parse overlay is unchanged and remains the default.",
  },
  ["3.7.1"] = {
    title = "FIX: Menu Open Freeze!",
    body = "Fixed experimental gamepad menu locking up on open\n(CPU time budget exceeded while building all panels).\n\nPanels now load one-at-a-time when you select them.\nOverlay path unchanged.",
  },
  ["3.7.2"] = {
    title = "NEW: Dense Menu Overview!",
    body = "Experimental menu Overview now mirrors Summary:\nKPI tiles, rotation health, burst/drop, DPS sparkline,\nset contribution, and top skills with bar chips.\n\nStill preview-only. Overlay unchanged.",
  },
  ["3.7.3"] = {
    title = "FIX: Menu L2/R2 History + Overview Layout!",
    body = "L2/R2 again walk fight history (nav list was stealing triggers).\nOverview KPI/rotation/burst alignment and sizing polished.\n\nOverlay path unchanged.",
  },
  ["3.7.4"] = {
    title = "NEW: Dense Menu Damage + Weave!",
    body = "Experimental menu now has dense pages for:\n• Overview (Summary)\n• Damage Breakdown (skill table)\n• Weave Analysis (KPIs + per-skill + DoT)\n\nAlso: L2/R2 history walk fixed.\nStill preview-only. Overlay unchanged.",
  },
  ["3.7.5"] = {
    title = "FIX: Menu Layout + More Rows!",
    body = "Tables no longer push metrics to the far right.\nDamage shows more skills; Weave/Buffs fill height.\nGear page denser (bars + two-col worn list).\n\nPreview-only. Overlay unchanged.",
  },
  ["3.7.6"] = {
    title = "NEW: All Menu Pages Enriched!",
    body = "Experimental menu dense pages now include:\nBuffs, Procs, Gear, Rotation, History\n(plus Overview/Damage/Weave from earlier).\n\nL2/R2 history walk validated.\nStill preview-only. Overlay default.",
  },
  ["3.7.7"] = {
    title = "FIX: Rotation Colors + History Layout!",
    body = "Rotation timeline is color-coded (+ ~ x >)\nand KPIs are no longer scrunched boxes.\n\nHistory: fight cards, trend bars in the middle,\nand a real comparison table at the bottom.\n\nPreview-only. Overlay unchanged.",
  },
  ["3.8.0"] = {
    title = "NEW: Insights + Menu Polish!",
    body = "• Content plate no longer bleeds past edges\n• Rotation: skill icons + fine pulse + patterns\n• History bars labeled with values\n• Gear: worn + enchant formatting\n• Weave: full column words + tip line\n• NEW Insights page for coaching patterns\n\nL2/R2 history still works. Overlay default.",
  },
  ["3.8.1"] = {
    title = "FIX: Menu Layout Polish!",
    body = "• Weave tip no longer merges into skill list\n• Gear worn is a real table with slot icons\n• Rotation icons use thick color rings\n• History stats sit right of target name\n• Fight # once above trend columns\n\nPreview-only. Overlay default.",
  },
  ["3.8.2"] = {
    title = "FIX: History Order + Clarity!",
    body = "• Fight #1 is always newest\n• Trend bars newest→oldest like comparison\n• Buff tiers: Always-on / Sustained / Situational\n• U chip for ultimates; E for effects\n• Longer names; enchant effect text\n\nPreview-only. Overlay default.",
  },
  ["3.8.3"] = {
    title = "NEW: Buff Hybrid + Dmg Split!",
    body = "• Buffs: Always-on left + Sustained/Situational right\n• Damage contribution on Damage/Dashboard/Overview\n• U/S/E chips (Ult/Set/Effect) with clearer colors\n• Insights: comparative last-20% rush only\n• Bar snapshot icons for scribed skills\n\nPreview-only. Overlay default.",
  },
  ["3.9.0"] = {
    title = "NEW: Menu is Default!",
    body = "The dual-pane gamepad menu is now the default stats viewer.\n\n• Post-parse opens the menu (not the old overlay)\n• /dm2stats show / toggle use the menu\n• Settings: Stats viewer = menu | overlay (rollback)\n• /dm2stats legacy still opens the old window\n\nOverlay code kept for one cycle — not deleted.",
  },
  ["3.9.1"] = {
    title = "NEW: Parse Diagnosis!",
    body = "Insights is now a DPS coach:\n\n• Ranked “Where Did My DPS Go?” opportunities\n• Estimates from YOUR parse (DoTs, missed LAs, cadence…)\n• Personal best / recent average comparison\n• Opener · sustained · late phase breakdown\n• One clear next drill to practice\n\nMenu remains the default viewer.",
  },
  ["3.9.2"] = {
    title = "CLEANUP: Menu-First Settings!",
    body = "• Overlay page buttons removed from settings\n• Legacy overlay only under Advanced\n• Auto-close defaults off (use O/back)\n• Insights layout denser + clearer columns\n\nMenu stays the default stats viewer.",
  },
  ["3.9.3"] = {
    title = "Dashboard CP + Insights polish",
    body = "• Dashboard Build column: slotted Champion Points\n• Insights column headers: gold title color + spacing\n\nParse Diagnosis opportunities still need a parse with data to populate.",
  },
  ["3.9.4"] = {
    title = "NEW: Insights Build Fit!",
    body = "Juggle CP against your actual parse:\n\n• Top damage sources ranked with F/B/U/S chips\n• Slotted CP scored Strong / OK / Soft vs this fight’s Direct·DoT·crit mix\n• Heuristic fit — not A/B tested free DPS\n• Same live CP list as Dashboard\n\nParse Diagnosis + Build Fit on Insights.",
  },
  ["3.9.5"] = {
    title = "FIX: Champion bar CP read",
    body = "Slotted CP was empty on console/PC because we used the wrong API.\n\n• Now reads HOTBAR_CATEGORY_CHAMPION via GetSlotBoundId (ESOUI path)\n• Dashboard + Insights Build Fit share the fixed collector\n• Empty state text clarified\n\nReload and check Dashboard / Insights CP lists.",
  },
  ["3.9.6"] = {
    title = "Dashboard CP by constellation",
    body = "Slotted Champion Points on Dashboard are grouped and tinted:\n\n• |cE85D5DCombat|r (Warfare / red)\n• |c5B9BD5Fitness|r (blue)\n• |c6FBF73Craft|r (green)\n\nSame live champion bar read as 3.9.5.",
  },
  ["3.9.7"] = {
    title = "FIX: CP tree labels",
    body = "Combat / Fitness / Craft headers were rotated.\n\n• Discipline APIs need disciplineId (not index)\n• Prefer each slot’s required constellation + name\n• Known-star name fallback (Thaumaturge→Combat, Boundless→Fitness…)\n\nReload Dashboard and confirm groups match your CP bar.",
  },
  ["3.9.8"] = {
    title = "Insights: hide Craft CP",
    body = "Insights Build Fit no longer lists Craft/world stars (Gifted Rider, Master Gatherer, etc.).\n\nDashboard still shows all slotted CP by constellation.",
  },
  ["3.9.9"] = {
    title = "Stats, Mundus, Buff sources",
    body = "• Insights: longer text; Sets% fixed; CHAR STATS column (base→buffed)\n• Dashboard: Mundus stone + Crit/Pen/Power/HP\n• Buffs: Source (Skill/Set/Group/External…) + Major/Minor effect text\n• Fight-end stat snapshot; trial support tips when you bring Major/Minor\n\nNew parses get full snapshots; older history may show live stats.",
  },
  ["3.9.10"] = {
    title = "NEW: Target debuffs / status",
    body = "Buffs page is now Buffs / Debuffs:\n\n• Right panel: enemy status you applied (Off Balance, Concussed, Breach…)\n• Apps = how many times applied · Up% ≈ active window\n• Captured from combat effect events + known status names\n• Left = your buffs (Always-on, then Sustained)\n\nNeeds a new parse after reload — old history has no debuff table.",
  },
  ["3.9.11"] = {
    title = "FIX: Char stats + 3-col buffs",
    body = "• CHAR STATS: columns Now | +buffs (green = from food/skills/sets — not stacked twice)\n• Crit% from rating (was stuck at 0%)\n• Stam + phys/spell pen + resists\n• Build Fit CP reason text wider\n• Buffs: Always-on | Sustained/Sit | Target debuffs\n\nLegend under stats explains Now vs +buffs.",
  },
  ["3.10.0"] = {
    title = "Build & Sets · clearer stats · Insights rework",
    body = "• Dashboard CHAR STATS: Sheet | Temp columns (not stacked twice)\n• Pen phys + spell vs 18.2k @cap · crit chance vs crit dmg · key self-buff uptimes\n• Recovery + attribute points · fight start+end snapshots · @parse #N badge\n• Buffs: wider Effect column · more Major/Minor/status hints\n• Insights: What you brought (own block) · CP Equipped|Impact · CHAR STATS moved off page\n• Procs tab → Build & Sets (parse build strip + set contribution)\n\nNew parse after reload for full start/end stats.",
  },
  ["3.11.0"] = {
    title = "NEW: Trial-prep coach (Phase 1)",
    body = "Insights is now a five-section coach:\n1 Parse Diagnosis · 2 Wasted/Missing Value · 3 Build Contribution\n4 Execution · 5 Next Test\n\n• Profile: Trial-prep dummy (outcomes DPS unchanged)\n• Confidence tags: Observed / Calculated / Estimated / Insufficient Data\n• Build fingerprint at fight start + end\n• Build & Sets: Champion Point impact list\n• Dashboard: all 8 slotted CP stars (fixed clipping)\n\nReload + new parse for fingerprints. More coach math in later updates.",
  },
  ["3.12.0"] = {
    title = "NEW: Coach analysis (Phase 2)",
    body = "Insights coach is smarter:\n\n• Waste: pen vs trial-prep group assumptions · Force uptime · crit-damage overcap risk\n• Champion Points: eligible % of this parse by damage category (not fake +DPS)\n• Sets: direct procs + equipped-without-proc notes\n• History: Build ID row · vs previous dummy notes (weave/LA/set-proc)\n• Next Test: sample size → execution → pen/crit waste → soft CP → hold build\n\nConfidence tags on claims. Reload + parse to exercise new lines.",
  },
  ["3.12.1"] = {
    title = "FIX: Insights + Dashboard polish",
    body = "• DoT advice no longer targets ultimates (separate ult timing note)\n• Dashboard CP: Combat | Fitness | Craft columns\n• CHAR STATS: Sheet / Bonus / Base columns (Bonus already inside Sheet)\n• Pen recipe on Insights + Dashboard (personal + group = effective)\n• Larger Insights fonts; less text cutoff\n• Food on Build & Sets · ability IDs on Damage/Buffs · clearer CP marginal note\n\nReload after install.",
  },
  ["3.13.0"] = {
    title = "Insights split + capture fixes",
    body = "• Insights split: Insights: DPS · Insights: Build (more room, larger type)\n• Trial-prep assumptions explained under title\n• Damage: more skill rows · Type = Direct/DoT + Physical/Magic/…\n• Debuff Up% fixed (reapply no longer resets window)\n• Off Balance tracking improved · source id on target debuffs\n• CHAR STATS: TOTAL / FROM BUFFS / UNBUFFED (From buffs already in Total)\n• Food capture improved · CP shows “id NNN” · A/B explained on Build & Sets\n• Gear: wider Trait column\n\nNew parse required for debuff uptime + food + damage types.",
  },
  ["3.14.0"] = {
    title = "Fundamentals pass (layout + stats + CP)",
    body = "Screen-by-screen QA fixes:\n\n• CP capture: merge hotbar + IsChampionSkillSlotted (missing 4th Warfare star / Backstabber)\n• CHAR STATS math: prefer sheet GetPlayerStat; crit from ratings; no fake unbuffed 1000 WD; TOTAL = end-of-fight\n• Damage: Skills | Effects dual panel · Type includes ST/AoE · no long ability ids on this page\n• Nav: Rotation under Weave · F/B/U tags on rotation icons\n• Buffs/Gear/Build & Sets/Insights Build density & column width fixes\n• Character menu entry attempt (with Journal entry)\n\nNew parse recommended for ST/AoE target counts + stats snapshot.",
  },
  ["3.14.1"] = {
    title = "Layout polish (names + CP rows)",
    body = "• Build & Sets: longer set names · CP note no longer covers first rows · constellation color chip · no spam “needs A/B” on every star\n• Damage: names clear of icons · panels lower under header text\n• Gear: wider Trait + Enchant shifted right\n• Buffs: longer Sustained names · Kind / Detail split on target debuffs\n• History: clearer “Why #1 ≠ #2” comparison row",
  },
  ["3.14.2"] = {
    title = "History compare polish",
    body = "• History row label: vs Fight #2\n• Signed deltas (+/−) for set-proc and DPS (fmtDps no longer ate the sign)\n• No trailing “vs #2” on the note · Fight #2 column is just ←\n• Note right-anchored (grows left, single line)\n• Build ID wording on Build & Sets + Insights Build",
  },
  ["3.14.3"] = {
    title = "Nav fix + Buffs/DoT tips",
    body = "• Fixed menu nav: Rotation/Buffs/Gear/Build&Sets tabs matched wrong pages after reorder\n• Buffs: longer Target Detail · Sustained Effect wider/left\n• DoT tips no longer scold weapon-enchant statuses (Hemorrhaging etc.); proc tip instead",
  },
  ["3.15.0"] = {
    title = "Phase 2.5.1 + 2.5.2b (coach depth)",
    body = "• Crit-dmg exposure: mid-fight sheet samples + profile ceiling · Insights waste + Dashboard cue\n• CP A/B marginal: same bars/sets/Mundus, champion swap · ΔDPS on Build & Sets + Insights Build\n• End-of-fight sheet fallback when mid-fight API returns 0\n\nNeed 2+ dummy parses with a one-star CP swap to see A/B lines. New parse recommended for exposure series.",
  },
  ["3.16.0"] = {
    title = "Phase 2.5 complete (trustworthy depth)",
    body = "Closes the coach loop after playtest scaffolds:\n\n• Crit exposure: clearer confidence wording (sheet samples; no per-hit mult on console)\n• CP A/B: strict one-star swap · median ΔDPS · Observed when n≥3 pairs\n• Experiment loop: Y on Insights: DPS starts/clears a 3-parse experiment (CP holds core build, execution holds full fingerprint)\n• Buffs: pen context footer → Insights recipe\n• History: fingerprint cohort strip + EXP tags on experiment runs\n\nReload UI, open Insights: DPS, press Y to start a controlled test.",
  },
  ["3.17.0"] = {
    title = "Insights Evolution Phase 3",
    body = "Phase 3 P0 — execution richness (no resource polling yet):\n\n• Insights §4 exception-driven: bars, ult casts, DoT gaps, best/worst active 20s\n• §1 opportunities: window collapse + DoT gaps when strong\n• Rotation markers: S swap · U ult · L late phase\n• Weave DoT table: gap counts (maintainable skills only)\n• Capture: bar dwell, swap-delay distribution, ult cast times (capped)\n\nNew parse recommended. Resources/potions come later (P1).",
  },
  ["3.17.4"] = {
    title = "History auto-compact (keeps your parses)",
    body = "Console stability without wiping everyone’s fight history.\n\n• On load: strip bulk combat tables from stored fights\n• Keeps DPS, skills, weave, fingerprints, windows/gaps\n• History size default 12 (max 20)",
  },
  ["3.17.5"] = {
    title = "SV re-bloat fix (coach write-back)",
    body = "Stops SavedVariables from exploding after browsing the menu:\n\n• Coach analysis no longer stores cross-links between history fights (the n² logout bloat bug)\n• History scrubbed on logout / character select\n• Trash fights skip heavy finalize work\n• Combat events filtered to you + pet (open-world CPU)\n• Live timeline/tick caps; history still kept and auto-compacted\n\nReload once. No history wipe for normal users.",
  },
  ["3.17.6"] = {
    title = "Parse QA: fingerprint, DoT uptime, rotation",
    body = "Testing fixes:\n\n• Build ID more stable (merge bar slots on swap; CP union start+end)\n• Experiment X: if fingerprint drifts but bars/sets/Mundus match, still count (no more stuck 2/3)\n• DoT uptime: running activeMs — Stampede/LL/Hurricane no longer undercount after tick caps\n• Rotation: S/U under timeline on dummy only; drop duplicate header strip + L marker\n• Late weave window slightly wider (1.2–2.2s); skill→skill still Missed\n• Insights CP list: 8 rows + fight-time champion snapshot for A/B impact lines\n\nNew dummy parses recommended for uptime + experiment counter.",
  },
  ["3.17.7"] = {
    title = "Critical: fight history save fix",
    body = "New dummy parses were not writing into History.\n\n• Combat-end finalize is now fully error-hardened (a single Lua error can no longer drop the parse)\n• History ring write still happens even if compact fails\n• Console-safe wall clock for fight timestamps\n• Rotation: S (swap) / U (ult) markers sit under the skill icon where they occurred\n\nReload, then complete one dummy — it should appear as #1 in History. Chat will show an error line only if something still fails.",
  },
  ["3.17.8"] = {
    title = "History still stuck — combat capture fix",
    body = "• Combat enter no longer wipes an in-progress parse (mid-dummy combat re-fire bug)\n• Combat flag accepts 1/0 (console), not only true/false\n• Watchdog polls IsUnitInCombat as backup when combat-state event is missed\n• Chat confirms every save: target · DPS · history N/max\n• Or explains why a fight was skipped (too short / no damage)\n• R2 on #1 no longer spams \"already on latest fight\"\n\nAfter reload: kill one dummy and look for green \"DM2 Parse: saved …\" in chat.",
  },
  ["3.17.9"] = {
    title = "History: 20-fight ring (newest = #1)",
    body = "• History holds up to 20 fights (settings slider 5–20, default 20)\n• Newest parse is always #1; at the limit the oldest rolls off\n• Same combat-save + chat confirmation as 3.17.8\n\nReload, parse one dummy — chat should say saved … history N/20.",
  },
  ["3.17.10"] = {
    title = "Dummy capture with open-world OFF",
    body = "Fixed: with Track open-world OFF, the first combat event with an empty/non-dummy name permanently blocked the whole pull (\"no parse was captured\").\n\n• No more sticky skip — dummy name or housing can start on a later hit\n• Stronger dummy name list (Iron Atronach / Trial / dummy / atronach)\n• You can turn Track open-world OFF again for dummy-only parses\n\nReload + one dummy. Expect green saved … in chat.",
  },
  ["3.17.11"] = {
    title = "Buffs · DPS · fingerprint · full rotation",
    body = "• Buffs: seed always-on at pull start + FULL_REFRESH (dummy Major Courage etc. no longer vanish)\n• DPS: duration ends at last damage hit (aligns with Simple DPS / chat)\n• Fingerprint: food is NOT in build ID — expiring food will not force a new fingerprint\n• Rotation: keep full skill timeline (not last 64 only); page with Y · all S/U markers\n\nNew dummy parse recommended for buffs + DPS + full rotation.",
  },
  ["3.17.12"] = {
    title = "DPS accuracy restore (lean combat path)",
    body = "Parse totals drifted low after combat-event path got heavy (DoT sampling, debuffs, build snaps on first hit) and combat-end flicker cut pulls short.\n\n• Damage counted first like Simple DPS / older Parse (3.7.x) — hitValue + overflow\n• Heavy start snapshots deferred off the combat tick\n• Combat-end grace while damage still landing (housing dummy flicker)\n• Chat save line shows total damage + duration for cross-check\n\nNew dummy required. Compare Total Dmg / DPS to Simple DPS.",
  },
  ["3.17.13"] = {
    title = "DPS match Simple meter (same duration, higher total)",
    body = "QA: Simple 111.9k / 4.70M vs Parse 91k / 3.80M at identical 42.0s — missing ~900k damage, not clock skew.\n\n• Combat registration copied from Simple DPS (player+pet filters only; no IS_ERROR filter)\n• No Lua sourceType re-check (console filtered events can omit type and were dropped)\n• Damage results = Simple’s four (DAMAGE / CRIT / DOT / DOT CRIT) for totals\n• Hot path: totalDamage += hitValue only, then lean skill/bucket — no set-name resolve on every tick\n\nReload + new dummy. Chat total should match Simple Fight Total.",
  },
  ["3.17.14"] = {
    title = "Damage list + Rotation icon count",
    body = "• Damage page: 22 skill + 22 effect rows (was 16) — shows counts / top-N when more exist\n• Do not add damage to totals before capture starts (fixes empty skill rows vs inflated total)\n• Rotation: 64 icons/page, fit-to-panel layout (no clipped last row), clearer presses vs timeline counts\n\nNew dummy recommended.",
  },
  ["3.17.15"] = {
    title = "Full rotation on one screen · Fitness CP",
    body = "• Rotation: the whole dummy skill timeline draws on one screen (shrink-to-fit).\n  Square/Y only appears if a fight is longer than the panel can hold.\n• Skill icons: channel skills (Stampede etc.) keep their real icon, not initials.\n• Fitness CP: still listed, but dummy parses no longer rate them Strong/Soft.\n  Dummy does not hit back — survivability stars are N/A on a dummy.\n\nNew dummy recommended for rotation icons.",
  },
  ["3.17.16"] = {
    title = "Rotation on one screen · Fitness CP not dummy-rated",
    body = "• Rotation: whole dummy skill timeline on one screen (icons shrink to fit).\n  Square/Y only if the fight is longer than the panel can hold.\n• Channel skills keep real icons (not initials). New dummy for this.\n• Fitness CP still listed, but dummy parses no longer rate them Strong/Soft.\n  Dummy does not hit back — survivability stars show N/A.",
  },
  ["3.17.17"] = {
    title = "Build ID · quieter chat · Buffs labels",
    body = "• Chat: only a captured-fight DPS line (ESO-style Result: X DPS, Ys). Skip reasons silent.\n• Build ID: same bars/sets/Mundus/CP should hash the same (slot order + end recapture).\n  New dummy parses needed — old history IDs will still differ.\n• Insights: crit damage uses a Force/Brittle/CP recipe when the sheet API is 0.\n• Buffs: Target Debuffs names fully visible. Skill hit = your skill landing on the dummy.\n• Damage: same-name rows (Sundering Knife, Crystal Fragments) tagged with ability id.",
  },
  ["3.17.18"] = {
    title = "FIX: food no longer changes Build ID",
    body = "Eating or losing food was minting a new Build ID.\n\nMundus detection matched \"mage\" inside \"magicka\" on food buffs, so food-up and food-down hashed differently.\n\n• Mundus is only the 13 stones (Boon: The Thief, etc.)\n• Food is still recorded on the parse — it just cannot change the ID\n\nReload, then parse once with food and once without. Those two should share an ID.",
  },
  ["3.17.19"] = {
    title = "FIX: top Warfare CP Eligible % visible",
    body = "The first Warfare star (Deadly Aim etc.) showed no Eligible % when it had A/B history.\n\nA color chip was truncated mid-code and console hid the whole line.\nRows 2–4 were fine. Any star in that #1/A/B slot went blank.\n\nReload UI, open Build & Sets — row 1 should read like the others (#1 Eligible …).",
  },
  ["3.18.0"] = {
    title = "NEW: Insights: Build is a real page",
    body = "Insights: Build is no longer a thin clone of Damage / CP lists.\n\n• Mix · honest sets (buff sets are not 0 DPS) · what you brought\n• CP story vs this dummy’s Direct/DoT mix · Front/Back dwell + damage\n• Potions: uses + coverage (tri-stat / magicka / stamina) — no fake potion DPS\n  Pre-pot at pull counts as use #1. New dummy required for potion numbers.\n\nInsights: DPS still owns execution, weave, and the experiment (Y).",
  },
  ["3.18.1"] = {
    title = "NEW: raid strip + stiffer Build ID",
    body = "• Left-side RAID strip: two independent toggles — dungeons/trials, and dummy/housing.\n  Force, Slayer, Berserk, Courage, Heroism, Breach, Crusher, Brittle, Vuln, Pen.\n  ON / MIN / OFF — Pen is % of the usual 18.2k recipe (CAP at 100%).\n• Buffs page: raid-essentials legend at the bottom (Major/Minor effects).\n• Build ID: no extra CP/set union, Perfected names normalized, Craft CP ignored. History vs #2 says bars/sets/mundus/CP if it still drifts.\n\nSettings > Raid strip. Test in housing first.",
  },
  ["3.18.2"] = {
    title = "FIX: raid strip names + spacing",
    body = "Left RAID strip: full names (BERSERK, COURAGE, …) and right-justified ON/MIN/CAP so status never runs into the label.\n\nSame two toggles: dungeons/trials, dummy/housing.",
  },
  ["3.18.3"] = {
    title = "CLEANUP: old overlay removed",
    body = "The legacy multi-page overlay window is gone.\n\n• Stats always open in the gamepad menu\n• Overlay settings and /dm2stats legacy are gone\n• Capture, history, raid strip, and Insights unchanged\n\nO/back still closes. Smaller addon memory footprint.",
  },
  ["3.18.4"] = {
    title = "Pace bar and sheet crit",
    body = "Rotation top bar: how late the next skill was. Tick is the light attack.\nCRIT under PEN matches your sheet.",
  },
}
R._latestAnnouncementVersion = "3.18.4"

R._lastBarSwapMs = 0          -- debounce EVENT_ACTIVE_WEAPON_PAIR_CHANGED (fires up to 3x per swap)
R._activeBar = nil             -- HOTBAR_CATEGORY_PRIMARY / HOTBAR_CATEGORY_BACKUP (set on init + swap)

-- UI refs (weave flash + raid strip; no overlay window)
R.ui = {
  weaveFlash = nil,
  raidStrip = nil,
}

-- abilityId -> name cache (combat-event sourced; more reliable than GetAbilityName on console)
local ABILITY_NAME_CACHE = {}
local ABILITY_ICON_CACHE = {}

local function isBadAbilityIconTex(tex)
  if not tex or tex == "" then return true end
  local lower = string.lower(tostring(tex))
  if string.find(lower, "question", 1, true) then return true end
  if string.find(lower, "unknown", 1, true) then return true end
  if string.find(lower, "missing", 1, true) then return true end
  if string.find(lower, "icon_missing", 1, true) then return true end
  if string.find(lower, "ability_none", 1, true) then return true end
  return false
end

local function getAbilityIcon(abilityId)
  abilityId = tonumber(abilityId) or 0
  if abilityId <= 0 then return nil end
  local cached = ABILITY_ICON_CACHE[abilityId]
  if cached ~= nil then
    if cached == false then return nil end
    return cached
  end
  local icon
  if type(GetAbilityIcon) == "function" then
    local ok, tex = pcall(GetAbilityIcon, abilityId)
    if ok and tex and tex ~= "" and not isBadAbilityIconTex(tex) then icon = tex end
  end
  -- Cache misses as false so we don't re-query every frame
  ABILITY_ICON_CACHE[abilityId] = icon or false
  return icon
end

local function isPlaceholderAbilityLabel(name)
  if not name or name == "" then return true end
  name = zo_strformat("<<1>>", name)
  if name == "?" then return true end
  if string.find(name, "^%[%d+%]$") then return true end      -- [7]
  if string.find(name, "^%[#%d+%]$") then return true end     -- [#7] (console)
  if string.find(name, "^Ability %d+$") then return true end
  if string.find(name, "^Skill %d+$") then return true end
  return false
end

local function slotBarKey(barLabel, slot)
  return tostring(barLabel or "?") .. ":" .. tostring(tonumber(slot) or 0)
end

local function cacheAbilityName(abilityId, name)
  abilityId = tonumber(abilityId) or 0
  if abilityId > 0 and name and name ~= "" and not isPlaceholderAbilityLabel(name) then
    ABILITY_NAME_CACHE[abilityId] = name
  end
end

local function scanSlotNamesForAbilityId(abilityId)
  if type(GetSlotBoundId) ~= "function" or type(GetSlotName) ~= "function" then return nil end
  local categories = {}
  if type(HOTBAR_CATEGORY_PRIMARY) ~= "nil" then table.insert(categories, HOTBAR_CATEGORY_PRIMARY) end
  if type(HOTBAR_CATEGORY_BACKUP) ~= "nil" then table.insert(categories, HOTBAR_CATEGORY_BACKUP) end
  if #categories == 0 then table.insert(categories, nil) end

  for _, cat in ipairs(categories) do
    for slot = 3, 8 do
      local ok, sid
      if cat ~= nil then ok, sid = pcall(GetSlotBoundId, slot, cat)
      else ok, sid = pcall(GetSlotBoundId, slot) end
      if ok and tonumber(sid) == abilityId then
        local ok2, sn
        if cat ~= nil then ok2, sn = pcall(GetSlotName, slot, cat)
        else ok2, sn = pcall(GetSlotName, slot) end
        if ok2 and sn and sn ~= "" then
          local n = zo_strformat("<<1>>", sn)
          if n ~= "" and not isPlaceholderAbilityLabel(n) then return n end
        end
      end
    end
  end
  return nil
end

local function resolveAbilityName(abilityId, abilityName)
  -- 1. Combat event gave us a name (never cache or return console placeholders like [7])
  if abilityName and abilityName ~= "" then
    local n = zo_strformat("<<1>>", abilityName)
    if n ~= "" and not isPlaceholderAbilityLabel(n) then
      cacheAbilityName(abilityId, n)
      return n
    end
  end
  abilityId = tonumber(abilityId) or 0
  if abilityId <= 0 then return "Ability" end
  local cached = ABILITY_NAME_CACHE[abilityId]
  if cached and cached ~= "" and not isPlaceholderAbilityLabel(cached) then return cached end

  -- 2. GetAbilityName
  if type(GetAbilityName) == "function" then
    local ok, nm = pcall(GetAbilityName, abilityId)
    if ok and nm and nm ~= "" then
      local n2 = zo_strformat("<<1>>", nm)
      if n2 ~= "" and not isPlaceholderAbilityLabel(n2) then
        cacheAbilityName(abilityId, n2)
        return n2
      end
    end
  end
  -- 3. GetFormattedAbilityName (sometimes works when GetAbilityName doesn't)
  if type(GetFormattedAbilityName) == "function" then
    local ok, nm = pcall(GetFormattedAbilityName, abilityId)
    if ok and nm and nm ~= "" and not isPlaceholderAbilityLabel(nm) then
      cacheAbilityName(abilityId, nm)
      return nm
    end
  end
  -- 4. Match against front + back action bar slots
  local slotName = scanSlotNamesForAbilityId(abilityId)
  if slotName then
    cacheAbilityName(abilityId, slotName)
    return slotName
  end
  return "Ability " .. tostring(abilityId)
end

local function lookupSlottedAbilityBySlot(session, bar, slot)
  if not session or not session.slottedAbilityBySlot then return nil end
  slot = tonumber(slot) or 0
  if slot < 3 then return nil end
  return session.slottedAbilityBySlot[slotBarKey(bar, slot)]
end

-- Retry name resolution after combat ends (API may work better out of combat)
local function retryAbilityNames(session)
  if not session then return end
  if session.skills then
    for id, sk in pairs(session.skills) do
      if sk.name and isPlaceholderAbilityLabel(sk.name) then
        local resolved = resolveAbilityName(id, nil)
        if resolved and not isPlaceholderAbilityLabel(resolved) then
          sk.name = resolved
        end
      end
    end
  end
  if session.dotTicks then
    for id, entry in pairs(session.dotTicks) do
      if entry and entry.name and isPlaceholderAbilityLabel(entry.name) then
        local resolved = resolveAbilityName(id, nil)
        if resolved and not isPlaceholderAbilityLabel(resolved) then
          entry.name = resolved
        end
      end
    end
  end
end

local function resolveWeaveSkillDisplayName(session, item)
  if not item then return "?" end
  local name = item.skillName or item.label or "?"
  if not isPlaceholderAbilityLabel(name) then return name end
  local id = tonumber(item.abilityId) or 0
  if id > 0 then
    local resolved = resolveAbilityName(id)
    if not isPlaceholderAbilityLabel(resolved) then return resolved end
  end
  if session and session.skills and id > 0 and session.skills[id] then
    local skName = session.skills[id].name
    if skName and not isPlaceholderAbilityLabel(skName) then return skName end
  end
  local slot = tonumber(item.slot) or 0
  local bar = item.bar
  if slot >= 3 then
    local slotted = lookupSlottedAbilityBySlot(session, bar, slot)
    if slotted then
      local snapId = tonumber(slotted.id) or 0
      if snapId > 0 then
        local resolved = resolveAbilityName(snapId)
        if not isPlaceholderAbilityLabel(resolved) then return resolved end
      end
      if slotted.name and not isPlaceholderAbilityLabel(slotted.name) then return slotted.name end
    end
  end
  if id > 0 then return "Ability " .. tostring(id) end
  if slot >= 3 then return string.format("Slot %d (%s)", slot, bar or "?") end
  return name
end

local function reconcileWeaveTimelineNames(session)
  if not session or not session.weave or not session.weave.timeline then return end
  for _, item in ipairs(session.weave.timeline) do
    if item then
      local resolved = resolveWeaveSkillDisplayName(session, item)
      if resolved and not isPlaceholderAbilityLabel(resolved) then
        item.skillName = resolved
        item.label = resolved
      end
      if (tonumber(item.abilityId) or 0) <= 0 then
        local slot = tonumber(item.slot) or 0
        if slot >= 3 then
          local slotted = lookupSlottedAbilityBySlot(session, item.bar, slot)
          if slotted and (tonumber(slotted.id) or 0) > 0 then
            item.abilityId = slotted.id
          end
        end
      end
    end
  end
end

-- ----------------------------
-- Utility
-- ----------------------------
local function NowMs() return GetGameTimeMilliseconds() end

local function latencyPadMs()
  if type(GetLatency) == "function" then
    local p = tonumber(GetLatency()) or 0
    if p < 0 then p = 0 end
    local pad = math.floor(math.max(80, math.min(300, p * 1.2)))
    return pad
  end
  return 120
end


local function startsWithAt(s)
  return type(s) == "string" and s ~= "" and string.sub(s,1,1) == "@"
end

local function playerDisplayName()
  local dn = GetUnitDisplayName("player")
  if dn and dn ~= "" then return dn end
  return "player"
end

local function fmtInt(n)
  n = tonumber(n) or 0
  n = math.floor(n + 0.5)
  if ZO_CommaDelimitNumber then return ZO_CommaDelimitNumber(n) end
  return tostring(n)
end

local function fmtDps(dps)
  dps = tonumber(dps) or 0
  if dps < 0 then dps = 0 end
  if dps >= 1000000 then
    return string.format("%.2fm", dps/1000000)
  elseif dps >= 1000 then
    return string.format("%.1fk", dps/1000)
  end
  return string.format("%.0f", dps)
end

local function fmtPct(x)
  x = tonumber(x) or 0
  return string.format("%.1f%%", x * 100)
end

local function fmtDur(ms)
  ms = tonumber(ms) or 0
  if ms < 0 then ms = 0 end
  local total = ms / 1000
  local m = math.floor(total / 60)
  local s = total - (m * 60)
  return string.format("%d:%04.1f", m, s)
end

local function safeLower(s)
  if type(s) ~= "string" then return "" end
  return string.lower(s)
end

local function isInHousingHeuristic()
  -- Method 1: GetCurrentZoneHouseId — most reliable on console
  if type(GetCurrentZoneHouseId) == "function" then
    local ok, hid = pcall(GetCurrentZoneHouseId)
    if ok and tonumber(hid) and tonumber(hid) > 0 then
      return true
    end
  end
  -- Method 2: IsOwnerOfCurrentHouse (only true in YOUR house)
  if type(IsOwnerOfCurrentHouse) == "function" then
    local ok, res = pcall(IsOwnerOfCurrentHouse)
    if ok and res == true then return true end
  end
  -- Method 3: Housing editor mode active = definitely in a house
  if type(GetHousingEditorMode) == "function" then
    local ok, mode = pcall(GetHousingEditorMode)
    if ok and mode and mode ~= 0 then return true end
  end
  -- Method 4: Map content type
  if type(GetMapContentType) == "function" then
    local ok, ct = pcall(GetMapContentType)
    -- MAP_CONTENT_HOUSING = 4 (define locally in case constant not available)
    if ok and ct and (ct == 4 or (type(MAP_CONTENT_HOUSING) ~= "nil" and ct == MAP_CONTENT_HOUSING)) then
      return true
    end
  end
  return false
end

local DUMMY_KEYWORDS = {
  "target skeleton",
  "trial dummy",
  "iron atronach",
  "training dummy",
  "practice dummy",
  "target dummy",
  "atronach",
  "dummy",
  "serpent",
  "ra'ka",
  "raka",
}

local function isDummyName(targetName)
  local n = safeLower(zo_strformat("<<1>>", targetName or ""))
  if n == "" then return false end

  -- Trial dummy naming: "Target Iron Atronach, Trial" etc.
  if string.find(n, "target", 1, true) and string.find(n, "trial", 1, true) then
    return true
  end
  if string.find(n, "target", 1, true) and string.find(n, "dummy", 1, true) then
    return true
  end
  for _, kw in ipairs(DUMMY_KEYWORDS) do
    if string.find(n, kw, 1, true) then return true end
  end
  return false
end

-- Labeling for history badges / auto-popup (strict = name AND housing when enabled)
local function isDummyParseConfidence(targetName)
  local nameHit = isDummyName(targetName)
  local inHouse = isInHousingHeuristic()
  local strict = SV and SV.settings and SV.settings.dummyStrict
  if strict then
    return nameHit and inHouse
  end
  return nameHit or inHouse
end

-- Whether to START capturing this pull when "Track open-world" is OFF.
-- IMPORTANT: do not use sticky skip — first event often has empty/wrong name.
-- Name match alone is enough (even if housing API is flaky on console).
local function shouldStartDummyOnlyCapture(targetName)
  if isDummyName(targetName) then return true end
  if isInHousingHeuristic() then return true end
  return false
end

-- ----------------------------
-- Session model
-- ----------------------------
local function newSession()
  return {
    started = false,
    startMs = 0,
    endMs = 0,
    durationMs = 0,

    -- raw totals
    totalDamage = 0,
    directDamage = 0,
    dotDamage = 0,
    totalHealing = 0,
    effectiveHealing = 0,
    lastDamageMs = 0,   -- last outgoing damage tick (DPS duration end)

    hitCount = 0,
    critCount = 0,
    dotTicks = {},    -- v3.2.0: [abilityId] = { name, ticks={ms,...} } for DOT uptime
    maxHit = 0,

    -- Phase 2.5.1: damage-weighted crit-damage exposure
    -- source: "none" | "sheet_sample" | "sheet_end" | "event"
    -- sampleSeries[] = { dmg, pct } aggregates for finalize with profile ceiling
    critDmgStats = {
      source = "none",
      eligibleDmg = 0,       -- outgoing damage counted toward exposure
      critHitDmg = 0,        -- damage that crit
      sampleWeight = 0,      -- sum(dmg) for samples with sheet crit%
      sampleCritDmgSum = 0,  -- sum(dmg * sheetCritDmgPct) for weighted average
      atCapWeight = 0,       -- filled at finalize with profile ceiling
      overcapWeighted = 0,   -- filled at finalize
      samples = 0,
      lastSampleMs = 0,
      lastSheetCritPct = 0,
      sampleSeries = {},     -- compact mid-fight samples for re-ceiling at analyze
    },

    -- buckets (2s)
    buckets = {},     -- [bucketIndex] = { dmg, direct, dot, hits, crit, skills = { [abilityId]=dmg } }

    -- skills
    skills = {},      -- [abilityId] = { name, dmg, hits, crit, direct, dot }

    -- buffs (player)
    buffs = {},       -- [abilityId] = { name, applied=cnt, activeMs=0, activeStartMs=nil }

    -- debuffs / status effects applied to enemies (by you / pet)
    -- [key] = { id, name, kind, applied, activeMs, activeStartMs, lastTarget }
    targetDebuffs = {},

    -- weaving (v3.0.25: input-based via EVENT_ACTION_SLOT_ABILITY_USED)
    weave = {
      laCount = 0,
      lastLaHitMs = nil,
      laIntervals = {},

      tooFastCount = 0,
      onTimeCount = 0,
      lateCount = 0,
      missedCount = 0,
      extraLAs = 0,

      fastSkillPresses = 0,
      skillEventCount = 0,
      lastSkillEventMs = nil,

      timeline = {},
      pendingSkill = nil,
      pendingPostChannel = nil,

      -- input-based tracking (new in v3.0.25)
      laPressCount = 0,            -- LA button presses (slot 1) from input
      lastLaPressMs = nil,         -- timestamp of last LA button press (for weave gap + LA intervals)
      lastInputSlot = nil,         -- last slot index from EVENT_ACTION_SLOT_ABILITY_USED
      lastInputAbilityId = nil,    -- ability ID resolved at input time
      lastInputBar = nil,          -- HOTBAR_CATEGORY at input time
      lastInputMs = nil,           -- timestamp of last input event
      inputSkillPresses = 0,       -- total skill button presses captured
      barSwapCount = 0,            -- number of bar swaps during the fight
    },

    -- Phase 3 P0: execution capture (lean — running totals + capped event lists)
    meta = {
      captureSchemaVersion = "3.0",
      analysisVersion = nil, -- set at finalize
      quality = {
        markerOverflow = false,
        bucketTopSources = false,
        degraded = {},
      },
    },
    barStats = {
      frontMs = 0,
      backMs = 0,
      unknownMs = 0,
      currentBar = nil,       -- "Front" | "Back" | nil
      lastChangeMs = 0,
      pendingSwapMs = nil,    -- for swap→first action delay
      swaps = {},             -- { tMs, toBar } cap 40
      swapDelayMs = {},       -- raw delays cap 40
      delayOverThresholdCount = 0,
      delayWithMissedWeaveCount = 0,
    },
    ultEconomy = {
      casts = 0,
      castTimes = {},         -- cap 12
      damage = 0,
      firstUltMs = nil,
    },
    markers = {
      points = {},            -- { tMs, type, label } cap 40
    },
    -- Filled at finalize (MenuShell): windowStats, dotQuality, execSummary

    -- metadata
    lastTargetName = nil,
    isDummy = false,
    slottedAbilityIds = {},
    slottedAbilityNames = {},
    slottedAbilityBar = {},       -- [abilityIdStr] = "Front" | "Back"
    slottedAbilityBarByName = {}, -- [normalizedName] = "Front" | "Back" (slotted snapshot)
    slottedAbilityBySlot = {},    -- ["Front:5"] = { id, name } fight-start snapshot
    rotationDebug = {},
  }
end

local function bucketIndexFor(session, tMs)
  if not session.started then return 0 end
  local rel = tMs - session.startMs
  if rel < 0 then rel = 0 end
  return math.floor(rel / SV.settings.bucketMs)
end

local function ensureBucket(session, idx)
  local b = session.buckets[idx]
  if not b then
    b = { dmg=0, direct=0, dot=0, hits=0, crit=0, skills={} }
    session.buckets[idx] = b
  end
  return b
end

local function ensureSkill(session, abilityId, abilityName)
  abilityId = tonumber(abilityId) or 0
  local resolved = resolveAbilityName(abilityId, abilityName)
  local s = session.skills[abilityId]
  if not s then
    s = {
      id = abilityId,
      name = resolved,
      dmg = 0,
      hits = 0,
      crit = 0,
      direct = 0,
      dot = 0,
      max = 0,
      uniqueTargets = {}, -- [targetKey] = true → ST vs multi/AoE
      uniqueTargetCount = 0,
      aoeHint = nil,     -- true/false/nil from radius or name
    }
    session.skills[abilityId] = s
  else
    -- If the stored name is still a fallback like "Ability 12345" and we
    -- now have a real name from a later hit or the cache, update it.
    if resolved and resolved ~= "" and s.name ~= resolved then
      local isFallback = (s.name == ("Ability " .. tostring(abilityId))) or (s.name == "Ability")
          or isPlaceholderAbilityLabel(s.name)
      if isFallback and not isPlaceholderAbilityLabel(resolved) then
        s.name = resolved
      end
    end
    s.uniqueTargets = s.uniqueTargets or {}
  end
  return s
end

local function noteSkillTarget(skill, targetUnitId, targetName)
  if not skill then return end
  skill.uniqueTargets = skill.uniqueTargets or {}
  local key = nil
  local uid = tonumber(targetUnitId) or 0
  if uid > 0 then
    key = "u:" .. tostring(uid)
  elseif targetName and tostring(targetName) ~= "" then
    key = "n:" .. tostring(targetName)
  end
  if not key then return end
  if not skill.uniqueTargets[key] then
    skill.uniqueTargets[key] = true
    skill.uniqueTargetCount = (tonumber(skill.uniqueTargetCount) or 0) + 1
  end
end


-- ----------------------------
-- Set proc attribution (lightweight + scalable)
-- ----------------------------
-- Primary: curated abilityId -> setName map (fast, accurate when populated)
-- Secondary fallback: if an outgoing damage ability name matches an equipped set name, attribute to that set.
-- This catches common procs like "Aegis Caller" out-of-the-box without needing IDs.
local SET_PROC_BY_ABILITY_ID = {
  -- Populate over time as you learn proc IDs.
  -- Example:
  -- [123456] = "Pillar of Nirn",
  -- [234567] = "Whorl of the Depths",
}

-- Curated proc-ability-NAME -> setName map.
-- Use when a set's damage proc has an ability name that differs from the set
-- name itself, so the ability-name == equipped-set-name fallback cannot catch
-- it (and we don't have a stable abilityId, e.g. pet/summon-sourced procs
-- whose id isn't surfaced in the UI). Keys must be lowercased and
-- whitespace-trimmed name keys.
local SET_PROC_BY_ABILITY_NAME = {
  ["sliver assault"] = "Slivers of the Null Arca",   -- 5pc proc crystal ("Sliver Assault")
  ["silver assault"] = "Slivers of the Null Arca",   -- common combat-log typo
}

local function normalizeNameKey(s)
  s = zo_strformat("<<1>>", s or "")
  s = safeLower(s)
  s = s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return s
end

local function findSkillAbilityId(session, skillName)
  if not session or not session.skills or not skillName then return 0 end
  local key = normalizeNameKey(skillName)
  if key == "" then return 0 end
  for id, sk in pairs(session.skills) do
    if normalizeNameKey(sk.name) == key then return tonumber(id) or 0 end
  end
  return 0
end

local function abilityBarKey(abilityId)
  local id = tonumber(abilityId) or 0
  if id <= 0 then return nil end
  return tostring(id)
end

local ROTATION_ABILITY_ALIASES = {
  ["pragmatic fatecarver"] = "fatecarver",
  ["exhausting fatecarver"] = "fatecarver",
  ["fatecarver"] = "fatecarver",
  ["unstable wall of fire"] = "wall of elements",
  ["wall of fire"] = "wall of elements",
  ["unstable wall of storms"] = "wall of elements",
  ["wall of storms"] = "wall of elements",
  ["unstable wall of frost"] = "wall of elements",
  ["wall of frost"] = "wall of elements",
  ["cephaliarch's flail"] = "flail",
  ["tentacular dread"] = "flail",
  ["escalating runeblades"] = "runeblades",
  ["writhing runeblades"] = "runeblades",
  ["inspired scholarship"] = "scholarship",
  ["scholarship"] = "scholarship",
  ["rending slashes"] = "rending slashes",
  ["the imperfect ring"] = "imperfect ring",
  ["imperfect ring"] = "imperfect ring",
  ["soul of flame"] = "soul of flame",
}

local function canonicalizeRotationName(name)
  local key = normalizeNameKey(name)
  if key == "" then return "" end
  for pattern, canonical in pairs(ROTATION_ABILITY_ALIASES) do
    if string.find(key, pattern, 1, true) then
      return canonical
    end
  end
  return key
end

local function captureEquippedSets()
  -- Best-effort snapshot of currently equipped set names.
  -- Works even if we don't map procs perfectly; helps detect swaps between parses.
  local sets, setMap = {}, {}
  if type(GetItemLink) ~= "function" or type(BAG_WORN) == "nil" then
    return sets, setMap
  end

  local function addSetName(setName)
    if not setName or setName == "" then return end
    local key = normalizeNameKey(setName)
    if key == "" or setMap[key] then return end
    setMap[key] = setName
    table.insert(sets, setName)
  end

  -- Typical equipment slots. (Defensive: only add those constants that exist.)
  local slots = {}
  local function pushSlot(slotConstName)
    local v = _G[slotConstName]
    if type(v) == "number" then table.insert(slots, v) end
  end

  -- armor
  pushSlot("EQUIP_SLOT_HEAD"); pushSlot("EQUIP_SLOT_CHEST"); pushSlot("EQUIP_SLOT_SHOULDERS")
  pushSlot("EQUIP_SLOT_HAND"); pushSlot("EQUIP_SLOT_WAIST"); pushSlot("EQUIP_SLOT_LEGS"); pushSlot("EQUIP_SLOT_FEET")
  -- jewelry
  pushSlot("EQUIP_SLOT_NECK"); pushSlot("EQUIP_SLOT_RING1"); pushSlot("EQUIP_SLOT_RING2")
  -- weapons
  pushSlot("EQUIP_SLOT_MAIN_HAND"); pushSlot("EQUIP_SLOT_OFF_HAND")
  pushSlot("EQUIP_SLOT_BACKUP_MAIN"); pushSlot("EQUIP_SLOT_BACKUP_OFF")

  for _,slotId in ipairs(slots) do
    local okLink, link = pcall(GetItemLink, BAG_WORN, slotId)
    if okLink and link and link ~= "" then
      -- API differences across versions: try a couple common signatures.
      local okSet, hasSet, setName = pcall(function()
        local a,b,c = GetItemLinkSetInfo(link)
        -- Some versions return (hasSet, setName, numBonuses, maxEquipped, ...)
        -- Others may return more. We'll interpret safely.
        if type(a) == "boolean" then return a, b end
        if type(a) == "number" then return a ~= 0, b end
        return false, nil
      end)
      if okSet and hasSet and setName and setName ~= "" then
        addSetName(setName)
      end
    end
  end

  return sets, setMap
end

local function captureSlottedAbilities()
  local ids = {}
  local names = {}
  local bars = {}
  local barsByName = {}
  local bySlot = {}
  if type(GetSlotBoundId) ~= "function" then return ids, names, bars, barsByName, bySlot end

  local function rememberBarForName(nm, barLabel)
    if not barLabel or not nm or nm == "" then return end
    local key = normalizeNameKey(nm)
    if key ~= "" then barsByName[key] = barLabel end
    local canon = canonicalizeRotationName(nm)
    if canon ~= "" then barsByName[canon] = barLabel end
  end

  local function addSlot(slot, hotbarCategory, barLabel)
    if type(slot) ~= "number" then return end
    local ok, id
    if hotbarCategory ~= nil then
      ok, id = pcall(GetSlotBoundId, slot, hotbarCategory)
    else
      ok, id = pcall(GetSlotBoundId, slot)
    end
    id = tonumber(id) or 0
    if ok and id > 0 then
      ids[id] = true
      local key = abilityBarKey(id)
      if barLabel and key then bars[key] = barLabel end
      local nm = resolveAbilityName(id)
      -- Prefer live slot name (scribed skills often resolve better from hotbar).
      if type(GetSlotName) == "function" then
        local okN, sn
        if hotbarCategory ~= nil then okN, sn = pcall(GetSlotName, slot, hotbarCategory)
        else okN, sn = pcall(GetSlotName, slot) end
        if okN and sn and sn ~= "" and not isPlaceholderAbilityLabel(sn) then
          nm = (type(zo_strformat) == "function") and zo_strformat("<<1>>", sn) or sn
        end
      end
      -- Snapshot icon texture at capture (scribed / console-safe).
      local iconTex = nil
      if type(GetSlotTexture) == "function" then
        local okT, tex
        if hotbarCategory ~= nil then okT, tex = pcall(GetSlotTexture, slot, hotbarCategory)
        else okT, tex = pcall(GetSlotTexture, slot) end
        if okT and tex and tex ~= "" then
          local lower = string.lower(tostring(tex))
          if not string.find(lower, "question", 1, true)
              and not string.find(lower, "missing", 1, true)
              and not string.find(lower, "unknown", 1, true) then
            iconTex = tex
          end
        end
      end
      if not iconTex then iconTex = getAbilityIcon(id) end
      bySlot[slotBarKey(barLabel, slot)] = {
        id = id,
        name = (nm and not isPlaceholderAbilityLabel(nm)) and nm or nil,
        icon = iconTex,
        isUlt = (slot == 8) or nil,
      }
      if nm and nm ~= "" and not isPlaceholderAbilityLabel(nm) then
        names[normalizeNameKey(nm)] = true
        rememberBarForName(nm, barLabel)
      end
    end
  end

  -- Try explicit hotbar categories first (available in modern API)
  if type(HOTBAR_CATEGORY_PRIMARY) ~= "nil" and type(HOTBAR_CATEGORY_BACKUP) ~= "nil" then
    for slot = 3, 8 do addSlot(slot, HOTBAR_CATEGORY_PRIMARY, "Front") end
    for slot = 3, 8 do addSlot(slot, HOTBAR_CATEGORY_BACKUP, "Back") end
  else
    -- Fallback: old-style slot ranges
    for slot = 3, 8 do addSlot(slot, nil, "Front") end
    for slot = 20, 25 do addSlot(slot, nil, "Back") end
  end
  return ids, names, bars, barsByName, bySlot
end

-- Merge a fresh slot/set read into the session without wiping bars that failed to re-read.
-- Called at fight end so Build ID is not minted from a partial start snapshot.
local function mergeLiveGearAndSlots(session)
  if type(session) ~= "table" then return end
  local slotIds, slotNames, slotBars, slotBarsByName, slotBySlot = captureSlottedAbilities()
  session.slottedAbilityIds = session.slottedAbilityIds or {}
  for id, v in pairs(slotIds or {}) do session.slottedAbilityIds[id] = v end
  session.slottedAbilityNames = session.slottedAbilityNames or {}
  for nk, v in pairs(slotNames or {}) do session.slottedAbilityNames[nk] = v end
  session.slottedAbilityBar = session.slottedAbilityBar or {}
  for id, bar in pairs(slotBars or {}) do session.slottedAbilityBar[id] = bar end
  session.slottedAbilityBarByName = session.slottedAbilityBarByName or {}
  for nameKey, bar in pairs(slotBarsByName or {}) do
    session.slottedAbilityBarByName[nameKey] = bar
  end
  session.slottedAbilityBySlot = session.slottedAbilityBySlot or {}
  for k, entry in pairs(slotBySlot or {}) do
    if type(entry) == "table" and (tonumber(entry.id) or 0) > 0 then
      session.slottedAbilityBySlot[k] = entry
    end
  end
  local sets, setMap = captureEquippedSets()
  session.equippedSets = session.equippedSets or {}
  session.equippedSetMap = session.equippedSetMap or {}
  if type(setMap) == "table" then
    for key, n in pairs(setMap) do
      if key and n and not session.equippedSetMap[key] then
        session.equippedSetMap[key] = n
        session.equippedSets[#session.equippedSets + 1] = n
      end
    end
  elseif type(sets) == "table" then
    for _, n in ipairs(sets) do
      local key = normalizeNameKey(n)
      if key ~= "" and not session.equippedSetMap[key] then
        session.equippedSetMap[key] = n
        session.equippedSets[#session.equippedSets + 1] = n
      end
    end
  end
end

local function ensureSet(session, setName)
  if not session or not setName or setName == "" then return nil end
  session.sets = session.sets or {}
  local s = session.sets[setName]
  if not s then
    s = { name=setName, dmg=0, hits=0, crit=0, direct=0, dot=0 }
    session.sets[setName] = s
  end
  return s
end

local function rotationNameMatchesSlotted(session, abilityName)
  if not session or not session.slottedAbilityNames then return false end
  local key = normalizeNameKey(abilityName)
  local canon = canonicalizeRotationName(abilityName)
  if key ~= "" and session.slottedAbilityNames[key] then return true end
  if canon ~= "" and session.slottedAbilityNames[canon] then return true end
  for slottedName,_ in pairs(session.slottedAbilityNames) do
    if slottedName == key or slottedName == canon then
      return true
    end
    if canon ~= "" and string.find(slottedName, canon, 1, true) then
      return true
    end
    if slottedName ~= "" and key ~= "" and string.find(key, slottedName, 1, true) then
      return true
    end
  end
  return false
end

local function matchEquippedSetName(session, aliasName)
  if not aliasName or aliasName == "" then return aliasName end
  if not session or not session.equippedSetMap then return aliasName end

  local aliasKey = normalizeNameKey(aliasName)
  if aliasKey == "" then return aliasName end
  if session.equippedSetMap[aliasKey] then return session.equippedSetMap[aliasKey] end

  -- Fuzzy match: "Null Arca" -> "Slivers of the Null Arca", perfected variants, etc.
  for key, name in pairs(session.equippedSetMap) do
    if key:find(aliasKey, 1, true) or aliasKey:find(key, 1, true) then
      return name
    end
  end
  return aliasName
end

local function lookupSetNameByAbilityLabel(session, abilityName)
  if not abilityName or abilityName == "" then return nil end

  local key = normalizeNameKey(abilityName)
  local byName = SET_PROC_BY_ABILITY_NAME[key]
  if byName then return matchEquippedSetName(session, byName) end

  -- Partial match for curated proc aliases (handles minor name variants from API/log)
  for procKey, setAlias in pairs(SET_PROC_BY_ABILITY_NAME) do
    if key:find(procKey, 1, true) or procKey:find(key, 1, true) then
      return matchEquippedSetName(session, setAlias)
    end
  end

  -- fallback: ability name matches an equipped set name
  key = canonicalizeRotationName(abilityName)
  if key ~= "" and session.equippedSetMap and session.equippedSetMap[key] then
    return session.equippedSetMap[key]
  end

  return nil
end

local function resolveSetName(session, abilityId, abilityName)
  abilityId = tonumber(abilityId) or 0

  local byId = SET_PROC_BY_ABILITY_ID[abilityId]
  if byId then return matchEquippedSetName(session, byId) end

  local result = lookupSetNameByAbilityLabel(session, abilityName)
  if result then return result end

  -- Combat events often omit abilityName; resolve via API/cache before giving up.
  local resolved = resolveAbilityName(abilityId, abilityName)
  if resolved and resolved ~= "" then
    result = lookupSetNameByAbilityLabel(session, resolved)
    if result then return result end
  end

  return nil
end

-- Rebuild set contribution totals from resolved per-skill damage.
-- Per-hit attribution can miss procs whose names only resolve after combat ends.
local function reconcileSetContributions(session)
  if not session or not session.skills then return end

  local sets = {}
  for abilityId, sk in pairs(session.skills) do
    local setName = resolveSetName(session, abilityId, sk.name)
    if setName then
      local ps = sets[setName]
      if not ps then
        ps = { name = setName, dmg = 0, hits = 0, crit = 0, direct = 0, dot = 0 }
        sets[setName] = ps
      end
      ps.dmg = ps.dmg + (tonumber(sk.dmg) or 0)
      ps.hits = ps.hits + (tonumber(sk.hits) or 0)
      ps.crit = ps.crit + (tonumber(sk.crit) or 0)
      ps.direct = ps.direct + (tonumber(sk.direct) or 0)
      ps.dot = ps.dot + (tonumber(sk.dot) or 0)
    end
  end
  session.sets = sets
end

local function classifyBuffSource(session, buff)
  if not buff then return "Unknown" end
  local abilityId = tonumber(buff.id) or 0
  local buffName = buff.name or ""

  if abilityId > 0 and session and session.slottedAbilityIds and session.slottedAbilityIds[abilityId] then
    return "Skill"
  end

  local setName = resolveSetName(session, abilityId, buffName)
  if setName then
    return "Set"
  end

  if abilityId > 0 and session and session.skills and session.skills[abilityId] then
    return "Self"
  end

  local key = normalizeNameKey(buffName)
  if key ~= "" and session and session.equippedSetMap and session.equippedSetMap[key] then
    return "Set"
  end

  return "External"
end

local function classifyDamageSource(session, skill)
  if not skill then return "Unknown" end
  local abilityId = tonumber(skill.id) or 0
  local skillName = skill.name or ""
  local key = normalizeNameKey(skillName)

  if abilityId > 0 and session and session.slottedAbilityIds and session.slottedAbilityIds[abilityId] then
    return "Skill"
  end

  local setName = resolveSetName(session, abilityId, skillName)
  if setName then
    return "Set"
  end

  if key:find("light attack", 1, true) or key:find("heavy attack", 1, true) then
    return "Weapon"
  end

  if key:find("bash", 1, true) then
    return "Weapon"
  end

  if abilityId > 0 then
    return "Self"
  end

  return "Other"
end

local function classifyAoeSkill(session, skill)
  if not skill then return "?" end
  local name = normalizeNameKey(skill.name or "")
  local source = classifyDamageSource(session, skill)
  if source == "Set" then return "Yes" end
  if name == "" then return "?" end

  local aoeHints = {
    "wall", "hail", "volley", "trap", "stampede", "whorl", "aegis", "deep fissure",
    "eruption", "claw", "cleave", "carve", "blade cloak", "hurricane", "twister",
    "fatecarver", "beam", "sweep", "shards", "orb", "barrage", "splash", "blast",
    "meteor", "standard", "banner", "runeblades", "tentacular", "frost blockade",
    "unstable wall", "wall of", "incinerate", "burning", "poison injection", "soul trap",
    "concussion", "static reverberation", "silver assault", "shocking banner"
  }
  local singleHints = {
    "merciless", "killer", "relentless", "flail", "concealed", "surprise attack",
    "force pulse", "swallow soul", "crushing shock", "execute", "spammable", "silver shards",
    "crystal fragments", "bound armaments", "sundering knife", "haunt"
  }

  for _,hint in ipairs(aoeHints) do
    if name:find(hint, 1, true) then return "Yes" end
  end
  for _,hint in ipairs(singleHints) do
    if name:find(hint, 1, true) then return "No" end
  end
  if name:find("light attack", 1, true) or name:find("heavy attack", 1, true) then return "No" end
  return "?"
end

-- ST / AoE label for Damage table (after classifyAoeSkill — console-safe order)
local function skillAoeLabel(skill, abilityId)
  if not skill then return "?" end
  local n = tonumber(skill.uniqueTargetCount) or 0
  if n >= 2 then return "AoE" end
  abilityId = tonumber(abilityId) or tonumber(skill.id) or 0
  if abilityId > 0 and type(GetAbilityRadius) == "function" then
    local ok, r = pcall(GetAbilityRadius, abilityId)
    r = ok and tonumber(r) or 0
    if r and r > 0 then return "AoE" end
  end
  if abilityId > 0 and type(GetAbilityAngleDistance) == "function" then
    local ok, a = pcall(GetAbilityAngleDistance, abilityId)
    a = ok and tonumber(a) or 0
    if a and a > 0 then return "AoE" end
  end
  local aoe = classifyAoeSkill(nil, skill)
  if aoe == "Yes" then return "AoE" end
  if aoe == "No" then return "ST" end
  if n == 1 then return "ST" end
  return "?"
end
R.SkillAoeLabel = skillAoeLabel

local function isCritResult(result)
  return result == ACTION_RESULT_CRITICAL_DAMAGE
      or result == ACTION_RESULT_DOT_TICK_CRITICAL
      or result == ACTION_RESULT_DAMAGE_SHIELDED_CRITICAL
      or result == ACTION_RESULT_BLOCKED_DAMAGE_CRITICAL
end

local function isDotResult(result)
  return result == ACTION_RESULT_DOT_TICK or result == ACTION_RESULT_DOT_TICK_CRITICAL
end

local function isDirectDamageResult(result)
  return result == ACTION_RESULT_DAMAGE
      or result == ACTION_RESULT_CRITICAL_DAMAGE
      or result == ACTION_RESULT_BLOCKED_DAMAGE
      or result == ACTION_RESULT_BLOCKED_DAMAGE_CRITICAL
      or result == ACTION_RESULT_DAMAGE_SHIELDED
      or result == ACTION_RESULT_DAMAGE_SHIELDED_CRITICAL
end

local function isOutgoingDamageEvent(result)
  return isDirectDamageResult(result) or isDotResult(result)
end

-- EXACT result set Simple DPS uses for Fight Total / Fight Avg.
-- (Shielded/blocked kept available via isOutgoingDamageEvent for other analytics,
-- but DPS totals use this table so we cannot diverge from the meter.)
local DPS_DAMAGE_RESULTS = {
  [ACTION_RESULT_DAMAGE] = true,
  [ACTION_RESULT_CRITICAL_DAMAGE] = true,
  [ACTION_RESULT_DOT_TICK] = true,
  [ACTION_RESULT_DOT_TICK_CRITICAL] = true,
}

local function isDpsTotalDamageResult(result)
  return DPS_DAMAGE_RESULTS[result] == true
end

-- Match Simple DPS: use hitValue as-is (do not invent overflow math).
local function combatHitDamage(hitValue, overflow)
  local dmg = tonumber(hitValue) or 0
  if dmg < 0 then dmg = 0 end
  return dmg
end

-- Combat-log results that mean an effect was applied/removed (not pure damage)
local function isEffectApplyResult(result)
  if result == nil then return false end
  if type(ACTION_RESULT_EFFECT_GAINED) == "number" and result == ACTION_RESULT_EFFECT_GAINED then return true end
  if type(ACTION_RESULT_EFFECT_GAINED_DURATION) == "number" and result == ACTION_RESULT_EFFECT_GAINED_DURATION then return true end
  if type(ACTION_RESULT_EFFECT_FADED) == "number" and result == ACTION_RESULT_EFFECT_FADED then return true end
  return false
end

-- Known enemy status / control / common debuffs (parse-visible names)
local TARGET_STATUS_KIND = {
  ["off balance"] = "CC",
  ["off-balance"] = "CC",
  ["offbalance"] = "CC",
  ["unbalanced"] = "CC",
  ["off balanced"] = "CC",
  ["concussed"] = "Status",
  ["concussion"] = "Status",
  ["burning"] = "Status",
  ["chilled"] = "Status",
  ["chill"] = "Status",
  ["sundered"] = "Status",
  ["diseased"] = "Status",
  ["hemorrhaging"] = "Status",
  ["poisoned"] = "Status",
  ["poison"] = "Status",
  ["bleed"] = "Status",
  ["bleeding"] = "Status",
  ["overcharged"] = "Status",
  ["frozen"] = "Status",
  ["major breach"] = "Debuff",
  ["minor breach"] = "Debuff",
  ["major fracture"] = "Debuff",
  ["minor fracture"] = "Debuff",
  ["major maim"] = "Debuff",
  ["minor maim"] = "Debuff",
  ["major defile"] = "Debuff",
  ["minor defile"] = "Debuff",
  ["major vulnerability"] = "Debuff",
  ["minor vulnerability"] = "Debuff",
  ["major cowardice"] = "Debuff",
  ["minor cowardice"] = "Debuff",
  ["minor brittle"] = "Debuff",
  ["major brittle"] = "Debuff",
  ["crusader"] = "Debuff", -- crusher enchant often shows as named proc
  ["crusader's resolve"] = "Debuff",
  ["alkosh"] = "Debuff",
  ["roar of alkosh"] = "Debuff",
  ["tremorscale"] = "Debuff",
  ["crystal weapon"] = "Debuff",
  ["weakening"] = "Debuff",
}

local function classifyTargetStatusKind(name)
  local n = safeLower(zo_strformat("<<1>>", name or ""))
  if n == "" then return nil end
  if TARGET_STATUS_KIND[n] then return TARGET_STATUS_KIND[n] end
  for key, kind in pairs(TARGET_STATUS_KIND) do
    if string.find(n, key, 1, true) then return kind end
  end
  -- Generic major/minor enemy debuffs
  if string.find(n, "major ", 1, true) or string.find(n, "minor ", 1, true) then
    if string.find(n, "breach", 1, true) or string.find(n, "fracture", 1, true)
        or string.find(n, "maim", 1, true) or string.find(n, "defile", 1, true)
        or string.find(n, "cowardice", 1, true) or string.find(n, "vulnerability", 1, true)
        or string.find(n, "brittle", 1, true) or string.find(n, "breach", 1, true) then
      return "Debuff"
    end
  end
  return nil
end

local function targetDebuffKey(abilityId, name)
  abilityId = tonumber(abilityId) or 0
  if abilityId > 0 then return "id:" .. tostring(abilityId) end
  local n = safeLower(zo_strformat("<<1>>", name or ""))
  if n ~= "" then return "name:" .. n end
  return nil
end

local function ensureTargetDebuff(session, abilityId, name)
  if not session then return nil end
  session.targetDebuffs = session.targetDebuffs or {}
  local key = targetDebuffKey(abilityId, name)
  if not key then return nil end
  local d = session.targetDebuffs[key]
  if not d then
    local resolved = (name and name ~= "") and zo_strformat("<<1>>", name) or ("Effect " .. tostring(abilityId or "?"))
    d = {
      id = tonumber(abilityId) or 0,
      name = resolved,
      kind = classifyTargetStatusKind(resolved) or "Effect",
      applied = 0,
      activeMs = 0,
      activeStartMs = nil,
      lastTarget = nil,
    }
    session.targetDebuffs[key] = d
  end
  return d
end

local function recordTargetDebuffApply(session, abilityId, name, tMs, targetName)
  local d = ensureTargetDebuff(session, abilityId, name)
  if not d then return end
  tMs = tMs or NowMs()
  d.applied = (d.applied or 0) + 1
  -- Already active (reapply / stack / EFFECT_UPDATED): do NOT reset the
  -- window start — that was destroying uptime (hundreds of apps, ~0% Up%).
  if not d.activeStartMs then
    d.activeStartMs = tMs
  end
  if targetName and targetName ~= "" then
    d.lastTarget = zo_strformat("<<1>>", targetName)
  end
  -- Source ability for "what proc'd this" (best-effort from combat abilityId)
  if (tonumber(abilityId) or 0) > 0 then
    d.sourceAbilityId = tonumber(abilityId)
    if name and name ~= "" then d.sourceAbilityName = zo_strformat("<<1>>", name) end
  end
  -- Upgrade kind if we learn a better classification
  local k = classifyTargetStatusKind(d.name)
  if k then d.kind = k end
end

local function recordTargetDebuffFade(session, abilityId, name, tMs)
  local d = ensureTargetDebuff(session, abilityId, name)
  if not d then return end
  tMs = tMs or NowMs()
  if d.activeStartMs then
    d.activeMs = (d.activeMs or 0) + math.max(0, tMs - d.activeStartMs)
    d.activeStartMs = nil
  end
end

local function isLightAttack(abilityId, abilityName, abilityActionSlotType)
  if abilityActionSlotType ~= nil and type(ACTION_SLOT_TYPE_LIGHT_ATTACK) ~= "nil" then
    if abilityActionSlotType == ACTION_SLOT_TYPE_LIGHT_ATTACK then return true end
  end
  local resolved = resolveAbilityName(abilityId, abilityName)
  local n = safeLower(resolved or "")
  if n ~= "" and string.find(n, "light attack", 1, true) then return true end
  if type(GetSlotBoundId) == "function" then
    local ok, laId = pcall(GetSlotBoundId, 1)
    if ok and laId and laId == abilityId then return true end
  end
  return false
end

-- ----------------------------
-- Rotation diagnostics helpers
-- ----------------------------
-- Classify the weave gap: time from skill button press to next LA button press.
-- In ESO, the weave rhythm is: LA → Skill (fast, ~50-150ms) → wait GCD → LA.
-- So skill-to-next-LA gap is roughly 600-1100ms for a good weave (GCD remainder).
-- Late = LA eventually pressed but slow (1.2–2.2s). Missed = no LA in window, or
-- skill→skill with no LA between (handled separately as always Missed).
local function classifyWeaveGap(deltaMs)
  deltaMs = tonumber(deltaMs) or 0
  if deltaMs <= 0 then return SYM_MISS, "Missed" end
  if deltaMs < 400 then return SYM_FAST, "Too Fast" end
  if deltaMs <= 1200 then return SYM_OK, "Good" end
  if deltaMs <= 2200 then return SYM_LATE, "Late" end
  return SYM_MISS, "Missed"
end

-- ----------------------------
-- Real-time weave flash (v3.2.0)
-- Shows a brief color-coded result at screen center during combat.
-- ----------------------------
local function ensureWeaveFlashUI()
  if R.ui.weaveFlash then return end
  local flash = WM:CreateTopLevelWindow("DM2StatsWeaveFlash")
  flash:SetDimensions(400, 70)
  flash:SetAnchor(CENTER, GuiRoot, CENTER, 0, -120)
  flash:SetHidden(true)
  flash:SetDrawLayer(DL_OVERLAY)
  flash:SetDrawTier(DT_HIGH)
  flash:SetDrawLevel(500001)
  flash:SetMouseEnabled(false)

  local fontSize = (SV and SV.settings and SV.settings.weaveFlashSize) or 36
  local lbl = WM:CreateControl("DM2StatsWeaveFlashLabel", flash, CT_LABEL)
  lbl:SetFont(string.format("EsoUI/Common/Fonts/univers67.otf|%d|soft-shadow-thick", fontSize))
  lbl:SetColor(1, 1, 1, 1)
  lbl:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
  lbl:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  lbl:SetAnchorFill(flash)
  lbl:SetText("")
  flash.label = lbl

  R.ui.weaveFlash = flash
end

local function updateWeaveFlashFont()
  if not R.ui.weaveFlash or not R.ui.weaveFlash.label then return end
  local fontSize = (SV and SV.settings and SV.settings.weaveFlashSize) or 36
  R.ui.weaveFlash.label:SetFont(string.format("EsoUI/Common/Fonts/univers67.otf|%d|soft-shadow-thick", fontSize))
end

local function playWeaveSound(resultLabel)
  if not SV or not SV.settings.weaveFlashSound then return end
  if type(PlaySound) ~= "function" then return end
  local rl = safeLower(resultLabel or "")
  if rl == "good" then
    PlaySound(SOUNDS.QUEST_STEP_ADVANCED)
  elseif rl == "late" then
    PlaySound(SOUNDS.ABILITY_TARGET_OUT_OF_RANGE)
  elseif rl == "missed" then
    PlaySound(SOUNDS.GENERAL_ALERT_ERROR)
  end
end

local function flashWeaveResult(resultLabel)
  -- Sound cue runs independently of visual flash
  if R.inCombat then playWeaveSound(resultLabel) end

  if not SV or not SV.settings.showWeaveFlash then return end
  if not R.inCombat then return end

  ensureWeaveFlashUI()
  local flash = R.ui.weaveFlash
  if not flash then return end

  -- Set color and text based on result
  local r, g, b = 1, 1, 1
  local text = resultLabel or ""
  local rl = safeLower(resultLabel or "")
  if rl == "good" then
    r, g, b = 0.4, 1.0, 0.4
    text = "Good!"
  elseif rl == "late" then
    r, g, b = 1.0, 0.8, 0.3
    text = "Late"
  elseif rl == "missed" then
    r, g, b = 1.0, 0.3, 0.3
    text = "Missed"
  elseif rl == "too fast" then
    r, g, b = 0.4, 0.7, 1.0
    text = "Too Fast"
  end

  flash.label:SetColor(r, g, b, 1)
  flash.label:SetText(text)
  flash:SetHidden(false)

  -- Auto-hide after configured duration (debounced via token)
  local durationMs = (SV and SV.settings and SV.settings.weaveFlashDuration) or 500
  R._weaveFlashToken = (R._weaveFlashToken or 0) + 1
  local myToken = R._weaveFlashToken
  zo_callLater(function()
    if R._weaveFlashToken == myToken and R.ui.weaveFlash then
      R.ui.weaveFlash:SetHidden(true)
    end
  end, durationMs)
end

local function hideWeaveFlash()
  R._weaveFlashToken = (R._weaveFlashToken or 0) + 1
  if R.ui.weaveFlash then R.ui.weaveFlash:SetHidden(true) end
end

-- ----------------------------
-- Version announcement popup (v3.2.0)
-- Styled screen-center popup shown once per version at login.
-- ----------------------------
local _announcementWin = nil
local _announcementCountdownLabel = nil
local _announcementSecondsLeft = 10

local function dismissAnnouncement()
  R._announcementToken = (R._announcementToken or 0) + 1
  if _announcementWin then _announcementWin:SetHidden(true) end
  EM:UnregisterForUpdate(R.name .. "_AnnounceCountdown")
  if SV then SV.lastAnnouncementVersion = R._latestAnnouncementVersion end
end

local function showAnnouncementPopup(title, body)
  if _announcementWin then dismissAnnouncement() end

  local win = WM:CreateTopLevelWindow("DM2StatsAnnouncement")
  win:SetDimensions(480, 260)
  win:SetAnchor(CENTER, GuiRoot, CENTER, 0, -60)
  win:SetDrawLayer(DL_OVERLAY)
  win:SetDrawTier(DT_HIGH)
  win:SetDrawLevel(500002)
  win:SetMouseEnabled(true)
  win:SetHidden(false)

  -- Backdrop
  local bg = WM:CreateControl("DM2StatsAnnouncementBG", win, CT_BACKDROP)
  bg:SetAnchorFill(win)
  bg:SetCenterColor(0.06, 0.06, 0.10, 0.92)
  bg:SetEdgeColor(0.45, 0.85, 0.55, 0.8)
  bg:SetEdgeTexture(nil, 1, 1, 2)

  -- Header: addon name (green, small)
  local header = WM:CreateControl("DM2StatsAnnouncementHeader", win, CT_LABEL)
  header:SetFont("EsoUI/Common/Fonts/univers57.otf|15|soft-shadow-thin")
  header:SetColor(0.53, 1.0, 0.53, 1)
  header:SetAnchor(TOPLEFT, win, TOPLEFT, 20, 14)
  header:SetDimensions(420, 18)
  header:SetText(R.displayName .. "  v" .. R.version)

  -- Title (gold, large, bold)
  local titleLbl = WM:CreateControl("DM2StatsAnnouncementTitle", win, CT_LABEL)
  titleLbl:SetFont("EsoUI/Common/Fonts/univers67.otf|22|soft-shadow-thick")
  titleLbl:SetColor(1.0, 0.88, 0.35, 1)
  titleLbl:SetAnchor(TOPLEFT, header, BOTTOMLEFT, 0, 8)
  titleLbl:SetDimensions(420, 28)
  titleLbl:SetText(title or "")

  -- Body (white, word-wrap)
  local bodyLbl = WM:CreateControl("DM2StatsAnnouncementBody", win, CT_LABEL)
  bodyLbl:SetFont("EsoUI/Common/Fonts/univers57.otf|17|soft-shadow-thin")
  bodyLbl:SetColor(0.92, 0.92, 0.92, 1)
  bodyLbl:SetAnchor(TOPLEFT, titleLbl, BOTTOMLEFT, 0, 8)
  bodyLbl:SetDimensions(420, 100)
  bodyLbl:SetWrapMode(TEXT_WRAP_MODE_WORD)
  bodyLbl:SetMaxLineCount(5)
  bodyLbl:SetVerticalAlignment(TEXT_ALIGN_TOP)
  bodyLbl:SetText(body or "")

  -- "Got it!" dismiss button (clickable label)
  local btn = WM:CreateControl("DM2StatsAnnouncementBtn", win, CT_LABEL)
  btn:SetFont("EsoUI/Common/Fonts/univers67.otf|18|soft-shadow-thick")
  btn:SetColor(0.4, 0.9, 1.0, 1)
  btn:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 20, -14)
  btn:SetDimensions(100, 24)
  btn:SetText("[ Got it! ]")
  btn:SetMouseEnabled(true)
  btn:SetHandler("OnMouseUp", function() dismissAnnouncement() end)
  btn:SetHandler("OnMouseEnter", function(self) self:SetColor(0.6, 1.0, 1.0, 1) end)
  btn:SetHandler("OnMouseExit", function(self) self:SetColor(0.4, 0.9, 1.0, 1) end)

  -- Countdown label (gray, right-aligned)
  local countdown = WM:CreateControl("DM2StatsAnnouncementCountdown", win, CT_LABEL)
  countdown:SetFont("EsoUI/Common/Fonts/univers57.otf|14|soft-shadow-thin")
  countdown:SetColor(0.6, 0.6, 0.6, 1)
  countdown:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -20, -16)
  countdown:SetDimensions(160, 18)
  countdown:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

  _announcementWin = win
  _announcementCountdownLabel = countdown
  _announcementSecondsLeft = 10
  countdown:SetText(string.format("Closing in %ds...", _announcementSecondsLeft))

  -- Countdown timer: tick every 1s, dismiss at 0
  R._announcementToken = (R._announcementToken or 0) + 1
  local myToken = R._announcementToken
  EM:RegisterForUpdate(R.name .. "_AnnounceCountdown", 1000, function()
    if R._announcementToken ~= myToken then
      EM:UnregisterForUpdate(R.name .. "_AnnounceCountdown")
      return
    end
    _announcementSecondsLeft = _announcementSecondsLeft - 1
    if _announcementSecondsLeft <= 0 then
      dismissAnnouncement()
    elseif _announcementCountdownLabel then
      _announcementCountdownLabel:SetText(string.format("Closing in %ds...", _announcementSecondsLeft))
    end
  end)
end

local function pushTimelineToken(session, label, symbol, result, meta)
  if not session or not session.weave then return end
  session.weave.timeline = session.weave.timeline or {}
  local tl = session.weave.timeline
  -- Live cap (console): long stuck-in-combat events must not grow unbounded
  if #tl >= 512 then
    local keepFrom = #tl - 383 -- drop oldest, keep ~384 then append
    local slim = {}
    for i = keepFrom, #tl do slim[#slim + 1] = tl[i] end
    session.weave.timeline = slim
    tl = slim
  end
  local item = {
    label = label or "?",
    symbol = symbol or "",
    result = result or "Info",
    tMs = NowMs(), -- for S/U marker alignment under skill icons
  }
  if meta then
    for k,v in pairs(meta) do item[k] = v end
  end
  -- meta.tMs wins if caller passed an explicit stamp
  if not item.tMs then item.tMs = NowMs() end
  tl[#tl + 1] = item
end

local CHANNEL_DASH_COUNTS = {
  ["fatecarver"]            = 4,
  ["pragmatic fatecarver"]  = 4,
  ["exhausting fatecarver"] = 4,
  ["engulfing dragonfire"]  = 5,
  ["radiant destruction"]   = 3,
  ["radiant glory"]         = 3,
  ["radiant oppression"]    = 3,
  ["soul strike"]           = 3,
  ["soul assault"]          = 3,
  ["shatter soul"]          = 3,
  ["biting jabs"]           = 1,
  ["puncturing sweep"]      = 1,
  ["rapid strikes"]         = 1,
  ["bloodthirst"]           = 1,
}

local function getChannelDashCount(label)
  local n = safeLower(label or "")
  for key, count in pairs(CHANNEL_DASH_COUNTS) do
    if string.find(n, key, 1, true) then return count end
  end
  return 3
end

local function isChannelAbilityLabel(label)
  local n = safeLower(label or "")
  return string.find(n, "fatecarver", 1, true) ~= nil
      -- Templar beam (Radiant Destruction line)
      or string.find(n, "radiant destruction", 1, true) ~= nil
      or string.find(n, "radiant glory", 1, true) ~= nil
      or string.find(n, "radiant oppression", 1, true) ~= nil
      -- Templar jabs (short channel, locks out weaving)
      or string.find(n, "biting jabs", 1, true) ~= nil
      or string.find(n, "puncturing sweep", 1, true) ~= nil
      -- DW flurry (short channel, locks out weaving)
      or string.find(n, "rapid strikes", 1, true) ~= nil
      or string.find(n, "bloodthirst", 1, true) ~= nil
      -- DK channeled breath (Update 49, 4.8s channel)
      or string.find(n, "engulfing dragonfire", 1, true) ~= nil
      -- Soul Magic ultimate (long channel)
      or string.find(n, "soul strike", 1, true) ~= nil
      or string.find(n, "soul assault", 1, true) ~= nil
      or string.find(n, "shatter soul", 1, true) ~= nil
      -- Generic fallbacks
      or string.find(n, "beam", 1, true) ~= nil
      or string.find(n, "channel", 1, true) ~= nil
end

local function trimSkillLabel(label, maxLen)
  label = zo_strformat("<<1>>", label or "?")
  maxLen = tonumber(maxLen) or 22
  if string.len(label) > maxLen then
    return string.sub(label, 1, math.max(1, maxLen - 2)) .. ".."
  end
  return label
end

local function finalizePendingWeave(session, forcedMiss)
  if not session or not session.weave or not session.weave.pendingSkill then return end
  local pending = session.weave.pendingSkill
  if forcedMiss then
    pushTimelineToken(session, pending.label, SYM_MISS, "Missed", {
      skillName = pending.skillName or pending.label, kind = "skill", missed = true,
      abilityId = pending.abilityId, slot = pending.slot, bar = pending.bar, icon = pending.icon,
    })
  end
  session.weave.pendingSkill = nil
end

local ROTATION_EXCLUDE_NAMES = {
  -- weapon enchant procs
  ["poisoned weapon"] = true,
  ["fiery weapon"] = true,
  ["overcharged"] = true,
  ["befouled weapon"] = true,
  ["frozen weapon"] = true,
  ["charged weapon"] = true,
  ["hardening"] = true,
  -- status effects / debuffs
  ["chill"] = true,
  ["chilled"] = true,
  ["burning"] = true,
  ["concussion"] = true,
  ["concussed"] = true,
  ["sundered"] = true,
  ["off balance"] = true,
  ["diseased"] = true,
  ["hemorrhaging"] = true,
  ["defile"] = true,
  ["breach"] = true,
  ["fracture"] = true,
  ["maim"] = true,
  ["empower"] = true,
  -- class passives / procs (not player-cast)
  ["fated fortune"] = true,
}

-- v3.0.25: ROTATION_CAPTURE_COOLDOWN_MS, ROTATION_CAPTURE_NAME_OVERRIDES_MS,
-- and ROTATION_EFFECT_ALLOWLIST removed. No longer needed with input-based capture.

local ROTATION_ALIAS_PATTERNS = {
  { "pragmatic fatecarver", "fatecarver" },
  { "exhausting fatecarver", "fatecarver" },
  { "fatecarver", "fatecarver" },
  { "unstable wall of fire", "unstable wall" },
  { "wall of fire", "unstable wall" },
  { "unstable wall", "unstable wall" },
  { "barbed trap", "barbed trap" },
  { "lightweight beast trap", "barbed trap" },
  { "trap beast", "barbed trap" },
  { "cephaliarch", "flail" },
  { "flail", "flail" },
  { "escalating runeblades", "runeblades" },
  { "writhing runeblades", "runeblades" },
  { "runeblades", "runeblades" },
  { "inspired scholarship", "scholarship" },
  { "scholarship", "scholarship" },
  { "soul of flame", "soul of flame" },
  { "rending slashes", "rending slashes" },
  { "the imperfect ring", "the imperfect ring" },
}

local function compactRotationName(s)
  s = normalizeNameKey(s)
  if s == "" then return "" end
  s = s:gsub("[^%a%d]", "")
  return s
end

local function canonicalRotationNameKey(name)
  local key = normalizeNameKey(name)
  if key == "" then return "" end
  for _, pair in ipairs(ROTATION_ALIAS_PATTERNS) do
    if key:find(pair[1], 1, true) then
      return pair[2]
    end
  end
  return key
end

local function findMatchingSlottedNameKey(session, abilityName)
  if not session or not session.slottedAbilityNames then return nil end
  local raw = normalizeNameKey(abilityName)
  if raw ~= "" and session.slottedAbilityNames[raw] then return raw end
  local canon = canonicalRotationNameKey(abilityName)
  if canon ~= "" and session.slottedAbilityNames[canon] then return canon end
  local compact = compactRotationName(abilityName)
  if compact == "" then return nil end
  for slottedKey,_ in pairs(session.slottedAbilityNames) do
    local sc = compactRotationName(slottedKey)
    if sc ~= "" and (sc == compact or (string.len(sc) >= 6 and (sc:find(compact, 1, true) or compact:find(sc, 1, true)))) then
      return slottedKey
    end
    local slottedCanon = canonicalRotationNameKey(slottedKey)
    if slottedCanon ~= "" and slottedCanon == canon then
      return slottedKey
    end
  end
  return nil
end

local function buildWeaveSkillBarMap(session)
  local map = {}
  if not session or not session.weave or not session.weave.timeline then return map end
  for _, item in ipairs(session.weave.timeline) do
    if item and (item.bar == "Front" or item.bar == "Back") then
      local name = item.skillName or item.label
      if name and name ~= "" then
        local key = normalizeNameKey(name)
        if key ~= "" then map[key] = item.bar end
        local canon = canonicalRotationNameKey(name)
        if canon ~= "" then map[canon] = item.bar end
      end
    end
  end
  return map
end

local function rememberSkillBarName(session, abilityName, barLabel)
  if not session or not abilityName or abilityName == "" then return end
  if barLabel ~= "Front" and barLabel ~= "Back" then return end
  session.slottedAbilityBarByName = session.slottedAbilityBarByName or {}
  local key = normalizeNameKey(abilityName)
  if key ~= "" then session.slottedAbilityBarByName[key] = barLabel end
  local canon = canonicalRotationNameKey(abilityName)
  if canon ~= "" then session.slottedAbilityBarByName[canon] = barLabel end
  if session.weave then
    session.weave.skillBarByName = session.weave.skillBarByName or {}
    if key ~= "" then session.weave.skillBarByName[key] = barLabel end
    if canon ~= "" then session.weave.skillBarByName[canon] = barLabel end
  end
end

local function lookupBarByName(session, abilityName)
  if not session or not abilityName or abilityName == "" then return nil end
  local byName = session.slottedAbilityBarByName
  if byName then
    local slottedKey = findMatchingSlottedNameKey(session, abilityName)
    if slottedKey and byName[slottedKey] then return byName[slottedKey] end
    local key = normalizeNameKey(abilityName)
    if key ~= "" and byName[key] then return byName[key] end
    local canon = canonicalRotationNameKey(abilityName)
    if canon ~= "" and byName[canon] then return byName[canon] end
  end
  if session.weave and session.weave.timeline then
    if not session.weave.skillBarByName then
      session.weave.skillBarByName = buildWeaveSkillBarMap(session)
    end
    local weaveBars = session.weave.skillBarByName or {}
    local key = normalizeNameKey(abilityName)
    if key ~= "" and weaveBars[key] then
      return weaveBars[key]
    end
    local canon = canonicalRotationNameKey(abilityName)
    if canon ~= "" and weaveBars[canon] then
      return weaveBars[canon]
    end
  end
  return nil
end

local function ensureBarByNameMap(session)
  if not session or type(session.slottedAbilityBar) ~= "table" then return end
  if session.slottedAbilityBarByName and next(session.slottedAbilityBarByName) then return end
  session.slottedAbilityBarByName = session.slottedAbilityBarByName or {}
  for idKey, bar in pairs(session.slottedAbilityBar) do
    if bar == "Front" or bar == "Back" then
      local id = tonumber(idKey) or 0
      if id > 0 then rememberSkillBarName(session, resolveAbilityName(id), bar) end
    end
  end
end

local function getSkillBar(session, abilityId, abilityName)
  if not session then return nil end
  ensureBarByNameMap(session)
  local barMap = session.slottedAbilityBar
  if type(barMap) ~= "table" then return lookupBarByName(session, abilityName) end

  local key = abilityBarKey(abilityId)
  if key and barMap[key] then return barMap[key] end
  if key and barMap[tonumber(key)] then return barMap[tonumber(key)] end

  if abilityName and abilityName ~= "" then
    local byName = lookupBarByName(session, abilityName)
    if byName then return byName end
    local targetKey = normalizeNameKey(abilityName)
    if targetKey ~= "" and session.skills then
      for slotKey, bar in pairs(barMap) do
        local slotId = tonumber(slotKey) or 0
        if slotId > 0 then
          local sk = session.skills[slotId]
          if sk and normalizeNameKey(sk.name) == targetKey then return bar end
          if normalizeNameKey(resolveAbilityName(slotId)) == targetKey then return bar end
        end
      end
    end
  end
  return nil
end

local function recordSkillBar(session, abilityId, barLabel, abilityName)
  if not session or not abilityId or abilityId <= 0 then return end
  if barLabel ~= "Front" and barLabel ~= "Back" then return end
  local key = abilityBarKey(abilityId)
  if not key then return end
  session.slottedAbilityBar = session.slottedAbilityBar or {}
  session.slottedAbilityBar[key] = barLabel
  rememberSkillBarName(session, abilityName, barLabel)
end

local function getRotationCaptureKey(session, abilityId, abilityName)
  local slottedNameKey = findMatchingSlottedNameKey(session, abilityName)
  if slottedNameKey then return "slot:" .. slottedNameKey end
  local canon = canonicalRotationNameKey(abilityName)
  if canon ~= "" then return "name:" .. canon end
  local keyId = tonumber(abilityId) or 0
  if keyId > 0 then return "id:" .. tostring(keyId) end
  return "name:" .. normalizeNameKey(abilityName)
end

-- v3.0.25: isDebugRelevantRotationSkill, getRotationCaptureCooldownMs,
-- shouldCaptureRotationEvent, markRotationEventCaptured removed.
-- Input-based capture doesn't need these filters — each button press is a single event.

local function trackRotationDebug(session, abilityId, abilityName, captured, reason)
  if not SV or not SV.settings.debugRotation then return end
  if not session then return end
  -- v3.0.25: with input-based capture, log all skill presses unconditionally when debug is on.
  -- The old isDebugRelevantRotationSkill filter was needed for damage-event inference;
  -- input events are already pre-filtered (only action bar slot presses fire the event).
  session.rotationDebug = session.rotationDebug or {}
  local displayName = resolveAbilityName(abilityId, abilityName)
  local key = getRotationCaptureKey(session, abilityId, displayName)
  if key == "" then key = tostring(abilityId or 0) end
  local entry = session.rotationDebug[key]
  if not entry then
    entry = { id = tonumber(abilityId) or 0, name = displayName or "?", captured = 0, skipped = 0, lastReason = "" }
    session.rotationDebug[key] = entry
  end
  if captured then
    entry.captured = entry.captured + 1
    -- v3.0.25: store slot/bar info from input-based capture as reason
    if reason and reason ~= "" then entry.lastReason = reason end
  else
    entry.skipped = entry.skipped + 1
    entry.lastReason = reason or ""
  end
end

-- v3.0.25: isRotationEligibleSkill, captureRotationSkillEvent, shouldTrackRotationDebugEvent,
-- shouldCaptureRotationEvent, markRotationEventCaptured, getRotationCaptureCooldownMs all removed.
-- Rotation capture is now input-based via EVENT_ACTION_SLOT_ABILITY_USED in OnActionSlotAbilityUsed().
-- The old damage-inference approach with cooldown deduplication, name matching, and eligibility
-- filtering is no longer needed — each button press from the action bar is a discrete event.

-- ----------------------------
-- History management
-- ----------------------------
local function ensureSV()
  if not SV then return end
  SV.settings = SV.settings or {}
  SV.ui = SV.ui or {}
  SV.history = SV.history or {}
  if SV.lastIndex == nil then SV.lastIndex = 0 end
  -- Phase 2.5 scaffold: active controlled experiment (MenuShell reads R.SV.experiments)
  if type(SV.experiments) ~= "table" then
    SV.experiments = { active = nil }
  end

  -- one-time merge defaults
  if not SV._init then
    -- shallow merge is fine for our v1 structure
    for k,v in pairs(R.defaults.settings) do if SV.settings[k] == nil then SV.settings[k] = v end end
    for k,v in pairs(R.defaults.ui) do if SV.ui[k] == nil then SV.ui[k] = v end end
    SV._init = true
  end

  -- one-time size migration for the expanded layout
  if not SV._layout_195b then
    local curW = tonumber(SV.ui.w) or 0
    local curH = tonumber(SV.ui.h) or 0
    if curW < 1300 then SV.ui.w = 1400 end
    if curH < 850 then SV.ui.h = 920 end
    SV._layout_195b = true
  end

  -- MenuShell + coach helpers use R.SV (must be the ZO_SavedVars table, not a copy)
  R.SV = SV
end

local function clearHistory()
  if not SV then return end
  SV.history = {}
  SV.lastIndex = 0
end

-- ESO writes history into SavedVariables as a .lua file. Non-finite numbers (NaN/Inf)
-- and huge mid-fight tables can corrupt that file so the game fails loading SV
-- *before* our addon runs (stack: user:/SavedVariables/DM2_ParseFightStats.lua main chunk).
local function finiteNum(n, fallback)
  n = tonumber(n)
  if n == nil then return fallback end
  if n ~= n then return fallback end -- NaN
  if n == math.huge or n == -math.huge then return fallback end
  return n
end

-- Cap array length in-place (keep newest / tail)
local function capArrayTail(arr, maxN)
  if type(arr) ~= "table" then return end
  maxN = tonumber(maxN) or 0
  if maxN <= 0 then return end
  local n = #arr
  if n <= maxN then return end
  local drop = n - maxN
  for i = 1, maxN do arr[i] = arr[i + drop] end
  for i = maxN + 1, n do arr[i] = nil end
end

-- Aggressive compact for SavedVariables (PS5 shared addon memory).
-- Keeps coach/outcomes; drops combat hotpath bulk that can make SV multi‑MB.
local function prepareSessionForHistory(session)
  if type(session) ~= "table" then return session end

  -- Crit samples: keep aggregates only
  if type(session.critDmgStats) == "table" then
    session.critDmgStats.sampleSeries = nil
    session.critDmgStats.eligibleDmg = finiteNum(session.critDmgStats.eligibleDmg, 0)
    session.critDmgStats.sampleWeight = finiteNum(session.critDmgStats.sampleWeight, 0)
    session.critDmgStats.sampleCritDmgSum = finiteNum(session.critDmgStats.sampleCritDmgSum, 0)
    session.critDmgStats.atCapWeight = finiteNum(session.critDmgStats.atCapWeight, 0)
    session.critDmgStats.overcapWeighted = finiteNum(session.critDmgStats.overcapWeighted, 0)
  end
  if type(session.critDmgExposure) == "table" then
    local e = session.critDmgExposure
    e.avgSheetCritPct = finiteNum(e.avgSheetCritPct, 0)
    e.capUptime = finiteNum(e.capUptime, 0)
    e.overcapExposure = finiteNum(e.overcapExposure, 0)
    e.ceilingPct = finiteNum(e.ceilingPct, 125)
  end
  session.totalDamage = finiteNum(session.totalDamage, 0)
  session.durationMs = finiteNum(session.durationMs, 0)
  session.directDamage = finiteNum(session.directDamage, 0)
  session.dotDamage = finiteNum(session.dotDamage, 0)

  -- Skills: drop unique-target maps; keep numbers
  if type(session.skills) == "table" then
    for _, sk in pairs(session.skills) do
      if type(sk) == "table" then
        sk.uniqueTargets = nil
        sk.dmg = finiteNum(sk.dmg, 0)
        sk.hits = finiteNum(sk.hits, 0)
        sk.dot = finiteNum(sk.dot, 0)
        sk.direct = finiteNum(sk.direct, 0)
        sk.crit = finiteNum(sk.crit, 0)
        sk.max = finiteNum(sk.max, 0)
      end
    end
  end

  -- Buckets: keep totals only (best/worst windows use dmg; per-skill maps explode SV size)
  if type(session.buckets) == "table" then
    for idx, b in pairs(session.buckets) do
      if type(b) == "table" then
        b.skills = nil
        b.dmg = finiteNum(b.dmg, 0)
        b.direct = finiteNum(b.direct, 0)
        b.dot = finiteNum(b.dot, 0)
        b.hits = finiteNum(b.hits, 0)
        b.crit = finiteNum(b.crit, 0)
      end
    end
  end

  -- Weave: cap timeline for Rotation; drop interval arrays
  if type(session.weave) == "table" then
    local w = session.weave
    w.laIntervals = nil
    w.pendingSkill = nil
    w.pendingPostChannel = nil
    w.skillBarByName = nil
    if type(w.timeline) == "table" then
      -- Keep full skill timeline for Rotation (was 64 = only late fight + few S markers)
      capArrayTail(w.timeline, 400)
    end
  end

  -- DoT ticks: keep sparse full-span samples + running activeMs (uptime source of truth)
  if type(session.dotTicks) == "table" then
    for id, entry in pairs(session.dotTicks) do
      if type(entry) == "table" and type(entry.ticks) == "table" then
        local ticks = entry.ticks
        local n = #ticks
        if not entry.tickCount or entry.tickCount < n then
          entry.tickCount = n
        end
        if n > 48 then
          -- keep first, last, and evenly spaced middle samples (full fight span)
          local keep = { ticks[1] }
          local step = (n - 1) / 47
          for i = 1, 46 do
            local idx = 1 + math.floor(i * step + 0.5)
            if idx < 1 then idx = 1 end
            if idx > n then idx = n end
            if keep[#keep] ~= ticks[idx] then keep[#keep + 1] = ticks[idx] end
          end
          if keep[#keep] ~= ticks[n] then keep[#keep + 1] = ticks[n] end
          entry.ticks = keep
          entry.tickCountOrig = entry.tickCount or n
        end
      end
    end
  end

  -- Phase 3: drop raw lists; keep derived medians/counts
  if type(session.barStats) == "table" then
    local bs = session.barStats
    bs.swaps = nil
    bs.swapDelayMs = nil
    bs.pendingSwapMs = nil
    bs.currentBar = nil
    bs.lastChangeMs = nil
  end
  if type(session.markers) == "table" and type(session.markers.points) == "table" then
    capArrayTail(session.markers.points, 80) -- swaps + ults for full rotation page
  end
  if type(session.ultEconomy) == "table" and type(session.ultEconomy.castTimes) == "table" then
    capArrayTail(session.ultEconomy.castTimes, 16)
  end

  -- Coach recompute is fine; NEVER persist coach (may hold cross-history refs)
  session.coach = nil
  session._coachTok = nil

  -- Player stats: keep buffed/unbuffed numbers only (drop nested junk if any)
  local function thinSnap(snap)
    if type(snap) ~= "table" then return nil end
    return {
      buffed = snap.buffed,
      base = snap.base,
      attributes = snap.attributes,
      mundus = snap.mundus,
      capturedAt = snap.capturedAt,
    }
  end
  if session.playerStats then session.playerStats = thinSnap(session.playerStats) end
  if session.playerStatsEnd then session.playerStatsEnd = thinSnap(session.playerStatsEnd) end
  if session.playerStatsStart then session.playerStatsStart = thinSnap(session.playerStatsStart) end

  -- Build snapshot: drop redundant dual copies of full gear if present
  if type(session.build) == "table" and type(session.buildEnd) == "table" then
    session.buildStart = nil -- start snap rarely needed after end fingerprint exists
  end

  if not (SV and SV.settings and SV.settings.debugRotation) then
    session.rotationDebug = nil
  end

  -- Potion summary is tiny; keep it. Drop live cluster clocks only.
  if type(session.potion) == "table" then
    local p = session.potion
    p.uses = finiteNum(p.uses, 0)
    p.firstUseMs = finiteNum(p.firstUseMs, nil)
    p.coveredMs = finiteNum(p.coveredMs, 0)
    p._clusterMs = nil
    p._lastUseMs = nil
    if type(p.stats) == "table" then
      p.stats.intellect = finiteNum(p.stats.intellect, 0)
      p.stats.endurance = finiteNum(p.stats.endurance, 0)
      p.stats.fortitude = finiteNum(p.stats.fortitude, 0)
      p.stats.expedition = finiteNum(p.stats.expedition, 0)
    end
  end
  return session
end

-- History capacity: hard ceiling 20. Newest is always fight #1 (offset 0).
-- Ring buffer: when full, the next save overwrites the oldest slot.
local HISTORY_HARD_MAX = 20
local HISTORY_HARD_MIN = 5

local function clampHistoryMax(v)
  v = tonumber(v) or HISTORY_HARD_MAX
  if v < HISTORY_HARD_MIN then v = HISTORY_HARD_MIN end
  if v > HISTORY_HARD_MAX then v = HISTORY_HARD_MAX end
  return v
end

local function historyMaxSetting()
  if not SV then return HISTORY_HARD_MAX end
  SV.settings = SV.settings or {}
  local max = clampHistoryMax(SV.settings.historyMax)
  SV.settings.historyMax = max
  return max
end

-- Re-compact every history slot (call on load — fixes already-bloated SVs).
-- Preserves fights: only strips bulk fields; does not wipe history.
local function sanitizeHistoryInPlace()
  if not SV or type(SV.history) ~= "table" then return 0 end
  local n = 0
  for slot, s in pairs(SV.history) do
    if type(s) == "table" then
      prepareSessionForHistory(s)
      n = n + 1
    end
  end
  local max = historyMaxSetting()
  -- Drop slots above current max (stale from a former higher historyMax)
  for slot, _ in pairs(SV.history) do
    local i = tonumber(slot)
    if i and i > max then
      SV.history[slot] = nil
      SV.history[tostring(slot)] = nil
    end
  end
  return n
end

-- Push newest fight into ring. Slot math:
--   lastIndex++ ; slot = ((lastIndex-1) % max) + 1
-- Read path maps offset 0 → that slot, so #1 is always newest.
-- When lastIndex exceeds max, the write overwrites the oldest slot (roll-off).
local function pushHistory(session)
  if not SV then return false end
  if type(session) ~= "table" then return false end
  local max = historyMaxSetting()

  -- Compact may fail on odd tables; never skip the ring write.
  local okPrep, prepErr = pcall(prepareSessionForHistory, session)
  if not okPrep then
    d("|cFF6666DM2 Parse|r: history compact error: " .. tostring(prepErr))
    session.coach = nil
    session._coachTok = nil
  end

  SV.history = SV.history or {}
  SV.lastIndex = (tonumber(SV.lastIndex) or 0) + 1
  local slot = ((SV.lastIndex - 1) % max) + 1
  SV.history[slot] = session
  -- Avoid string-key twins after SV reload
  SV.history[tostring(slot)] = nil
  if R then R.SV = SV end
  return true, slot, tonumber(SV.lastIndex) or 0, max
end

local function historySlotGet(history, slot)
  if type(history) ~= "table" then return nil end
  local s = history[slot]
  if type(s) == "table" then return s end
  s = history[tostring(slot)]
  if type(s) == "table" then return s end
  return nil
end

local function getHistoryCount()
  if not SV then return 0 end
  local max = historyMaxSetting()
  local idx = tonumber(SV.lastIndex) or 0
  if idx <= 0 then
    -- Repair: recount filled slots if lastIndex was lost on SV load
    local n = 0
    if type(SV.history) == "table" then
      for k, v in pairs(SV.history) do
        if type(v) == "table" and (tonumber(k) or 0) > 0 then n = n + 1 end
      end
    end
    if n > 0 then
      SV.lastIndex = n
      idx = n
    end
  end
  return math.min(idx, max)
end

-- offset 0 = newest (#1), offset 1 = one older (#2), …
local function getHistoryAt(offsetFromLatest)
  offsetFromLatest = tonumber(offsetFromLatest) or 0
  if not SV or type(SV.history) ~= "table" then return nil end
  local max = historyMaxSetting()
  local idx = tonumber(SV.lastIndex) or 0
  if idx <= 0 then return nil end

  local latestSlot = ((idx - 1) % max) + 1
  local slot = latestSlot - offsetFromLatest
  while slot < 1 do slot = slot + max end
  while slot > max do slot = slot - max end
  return historySlotGet(SV.history, slot)
end

-- Public history API for experimental gamepad menu shell (MenuShell.lua).
function R:GetMenuHistoryCount()
  if not SV then return 0 end
  return getHistoryCount()
end

function R:GetMenuHistoryAt(offsetFromLatest)
  if not SV then return nil end
  return getHistoryAt(offsetFromLatest)
end

function R:GetMenuBucketMs()
  if not SV or not SV.settings then return 2000 end
  return tonumber(SV.settings.bucketMs) or 2000
end

-- ----------------------------
-- Weaving stats
-- ----------------------------
local function weaveSummary(session)
  local w = session.weave or {}
  local intervals = {}
  for _,d in ipairs(w.laIntervals or {}) do
    if d and d > 0 then table.insert(intervals, d) end
  end

  local n = #intervals
  local laCount = tonumber(w.laCount) or 0
  local durMs = tonumber(session and session.durationMs) or 0
  local laPerSec = (durMs > 0) and (laCount / (durMs / 1000)) or 0

  if n == 0 then
    return {
      laHits = laCount,
      laPerSec = laPerSec,
      avgGap = 0,
      bestGap = 0,
      worstGap = 0,
      goodTiming = 0,
      tooFast = tonumber(w.tooFastCount) or 0,
      onTime = tonumber(w.onTimeCount) or 0,
      late = tonumber(w.lateCount) or 0,
      missed = tonumber(w.missedCount) or 0,
      extraLAs = tonumber(w.extraLAs) or 0,
      fastSkillPresses = tonumber(w.fastSkillPresses) or 0,
      samples = 0,
    }
  end

  table.sort(intervals)
  local sum = 0
  local best = nil
  local worst = 0
  for _,d in ipairs(intervals) do
    sum = sum + d
    if (not best) and d >= 250 then best = d end
    if d > worst then worst = d end
  end
  if not best then best = intervals[1] end

  local onTime = tonumber(w.onTimeCount) or 0

  return {
    laHits = laCount,
    laPerSec = laPerSec,
    avgGap = sum / n,
    bestGap = best or 0,
    worstGap = worst or 0,
    goodTiming = (n > 0) and (onTime / n) or 0,
    tooFast = tonumber(w.tooFastCount) or 0,
    onTime = onTime,
    late = tonumber(w.lateCount) or 0,
    missed = tonumber(w.missedCount) or 0,
    extraLAs = tonumber(w.extraLAs) or 0,
    fastSkillPresses = tonumber(w.fastSkillPresses) or 0,
    samples = n,
  }
end

local function getWeaveSuccessRatio(session)
  if not session or not session.weave then return 0 end
  local w = session.weave
  local good = tonumber(w.onTimeCount) or 0
  local late = tonumber(w.lateCount) or 0
  local missed = tonumber(w.missedCount) or 0
  local tooFast = tonumber(w.tooFastCount) or 0
  local total = good + late + missed + tooFast
  if total <= 0 then return 0 end
  return math.max(0, math.min(1, (good + late) / total))
end

-- ----------------------------
-- Export parse to chat (v3.2.2)
-- ----------------------------
local function exportParseToChat(session)
  if not session then
    d("|c88ff88DM2 Stats|r: no fight data to share.")
    return
  end
  local dur = (session.durationMs or 0)
  local durSec = dur > 0 and (dur / 1000) or 0
  local avgDps = durSec > 0 and (session.totalDamage / durSec) or 0
  local hitCount = session.hitCount or 0
  local critCount = session.critCount or 0
  local critPct = hitCount > 0 and (critCount / hitCount) or 0
  local weaveRatio = getWeaveSuccessRatio(session)
  local ws = weaveSummary(session)
  local target = session.lastTargetName or "?"
  local dummy = session.isDummy and "Dummy" or "Live"

  -- Format duration as M:SS
  local mins = math.floor(durSec / 60)
  local secs = math.floor(durSec % 60)
  local durStr = string.format("%d:%02d", mins, secs)

  local line = string.format(
    "|c88ff88[DM2]|r %s | %s %s | Avg %s | Peak %s | Crit %s | Weave %s | LA/s %.1f",
    target, durStr, dummy,
    fmtDps(avgDps),
    fmtDps(ws.laHits > 0 and ((session.maxHit or 0)) or 0),
    fmtPct(critPct),
    fmtPct(weaveRatio),
    ws.laPerSec or 0
  )
  d(line)
end

-- ----------------------------
-- Results popup + menu Show/Hide (legacy overlay removed)
-- ----------------------------
local function cancelQueuedResultsPopup()
  R._pendingPopupToken = (tonumber(R._pendingPopupToken) or 0) + 1
end

local function queueResultsPopup()
  cancelQueuedResultsPopup()
  local delaySecs = tonumber(SV and SV.settings and SV.settings.resultsPopupDelaySecs) or 2
  if delaySecs < 0 then delaySecs = 0 end
  if delaySecs > 5 then delaySecs = 5 end
  local delayMs = math.floor(delaySecs * 1000)
  local myToken = tonumber(R._pendingPopupToken) or 0

  if delayMs <= 0 then
    R:ShowStats({ offset = 0, autoPopup = true })
    return
  end

  zo_callLater(function()
    if (tonumber(R._pendingPopupToken) or 0) ~= myToken then return end
    if R.inCombat then return end
    R:ShowStats({ offset = 0, autoPopup = true })
  end, delayMs)
end

function R:Show()
  self:ShowStats()
end

function R:PreferMenuViewer()
  if type(self.ShowMenu) ~= "function" then return false end
  return isConsoleUI()
      or (type(IsInGamepadPreferredMode) == "function" and IsInGamepadPreferredMode())
      or (type(IsInGamepadMode) == "function" and IsInGamepadMode())
end

function R:ShowStats(opts)
  opts = opts or {}
  if self:PreferMenuViewer() then
    self:ShowMenu()
    return true
  end
  d("|cFFAA00DM2 Stats|r: gamepad/console mode required for the stats menu.")
  return false
end

function R:Hide()
  cancelQueuedResultsPopup()
  if type(self.HideMenu) == "function" then
    pcall(function() self:HideMenu() end)
  end
end

function R:Toggle()
  if type(self.HideMenu) == "function" and DM2StatsMenuShell and type(DM2StatsMenuShell.IsShowing) == "function"
      and DM2StatsMenuShell.IsShowing() then
    self:HideMenu()
    return
  end
  self:ShowStats()
end

-- ----------------------------
-- Phase 3 P0 capture helpers (must sit above startIfNeeded / combat handlers)
-- ----------------------------
local P3_SWAP_DELAY_THRESHOLD_MS = 400
local P3_MAX_SWAPS = 64
local P3_MAX_MARKERS = 80
local P3_MAX_ULT_CASTS = 16

local function p3BarLabelFromCategory(cat)
  if cat == nil then return nil end
  if type(HOTBAR_CATEGORY_BACKUP) ~= "nil" and cat == HOTBAR_CATEGORY_BACKUP then return "Back" end
  if type(HOTBAR_CATEGORY_PRIMARY) ~= "nil" and cat == HOTBAR_CATEGORY_PRIMARY then return "Front" end
  if cat == 1 or cat == 0 then return "Front" end
  if cat == 2 then return "Back" end
  return nil
end

local function p3EnsureBarStats(session)
  if not session then return nil end
  if type(session.barStats) ~= "table" then
    session.barStats = {
      frontMs = 0, backMs = 0, unknownMs = 0,
      currentBar = nil, lastChangeMs = 0, pendingSwapMs = nil,
      swaps = {}, swapDelayMs = {},
      delayOverThresholdCount = 0, delayWithMissedWeaveCount = 0,
    }
  end
  session.barStats.swaps = session.barStats.swaps or {}
  session.barStats.swapDelayMs = session.barStats.swapDelayMs or {}
  return session.barStats
end

local function p3EnsureMarkers(session)
  if not session then return nil end
  if type(session.markers) ~= "table" then session.markers = { points = {} } end
  session.markers.points = session.markers.points or {}
  return session.markers
end

local function p3EnsureUlt(session)
  if not session then return nil end
  if type(session.ultEconomy) ~= "table" then
    session.ultEconomy = { casts = 0, castTimes = {}, damage = 0, firstUltMs = nil }
  end
  session.ultEconomy.castTimes = session.ultEconomy.castTimes or {}
  return session.ultEconomy
end

local function p3PushMarker(session, tMs, mtype, label)
  local m = p3EnsureMarkers(session)
  if not m then return end
  local pts = m.points
  if #pts >= P3_MAX_MARKERS then
    if session.meta and session.meta.quality then session.meta.quality.markerOverflow = true end
    table.remove(pts, 1)
  end
  pts[#pts + 1] = { tMs = tMs, type = mtype, label = label or mtype }
end

local function p3AccrueBarDwell(session, tMs)
  local bs = p3EnsureBarStats(session)
  if not bs or not session.started then return end
  local last = tonumber(bs.lastChangeMs) or 0
  if last <= 0 then
    bs.lastChangeMs = tMs
    return
  end
  local dt = tMs - last
  if dt <= 0 then return end
  local bar = bs.currentBar
  if bar == "Front" then bs.frontMs = (bs.frontMs or 0) + dt
  elseif bar == "Back" then bs.backMs = (bs.backMs or 0) + dt
  else bs.unknownMs = (bs.unknownMs or 0) + dt end
  bs.lastChangeMs = tMs
end

local function p3InitBarAtCombatStart(session, tMs)
  local bs = p3EnsureBarStats(session)
  if not bs then return end
  local cat = R._activeBar
  if type(GetActiveHotbarCategory) == "function" then
    local ok, c = pcall(GetActiveHotbarCategory)
    if ok then cat = c; R._activeBar = c end
  end
  bs.currentBar = p3BarLabelFromCategory(cat) or "Front"
  bs.lastChangeMs = tMs
  bs.pendingSwapMs = nil
end

local function p3NotePostSwapAction(session, tMs)
  local bs = p3EnsureBarStats(session)
  if not bs or not bs.pendingSwapMs then return end
  local delay = tMs - bs.pendingSwapMs
  if delay < 0 then delay = 0 end
  if delay > 15000 then delay = 15000 end
  local delays = bs.swapDelayMs
  if #delays < P3_MAX_SWAPS then
    delays[#delays + 1] = delay
  end
  if delay >= P3_SWAP_DELAY_THRESHOLD_MS then
    bs.delayOverThresholdCount = (bs.delayOverThresholdCount or 0) + 1
  end
  bs.pendingSwapMs = nil
end

local function p3IsUltPress(session, actionSlotIndex, abilityId, abilityName)
  if (tonumber(actionSlotIndex) or 0) == 8 then return true end
  abilityId = tonumber(abilityId) or 0
  if abilityId > 0 and type(GetAbilityUltimateCost) == "function" then
    local ok, cost = pcall(GetAbilityUltimateCost, abilityId)
    if ok and (tonumber(cost) or 0) > 0 then return true end
  end
  if session and type(session.slottedAbilityBySlot) == "table" then
    for _, bar in ipairs({ "Front", "Back" }) do
      local e = session.slottedAbilityBySlot[bar .. ":8"]
      if type(e) == "table" and (tonumber(e.id) or 0) == abilityId and abilityId > 0 then
        return true
      end
    end
  end
  return false
end

local function p3RecordUltCast(session, tMs, abilityId)
  local ue = p3EnsureUlt(session)
  if not ue then return end
  local times = ue.castTimes
  if #times > 0 and (tMs - (times[#times] or 0)) < 400 then return end
  if #times >= P3_MAX_ULT_CASTS then return end
  times[#times + 1] = tMs
  ue.casts = #times
  if not ue.firstUltMs then
    local start = tonumber(session.startMs) or tMs
    ue.firstUltMs = math.max(0, tMs - start)
  end
  p3PushMarker(session, tMs, "ult", "ult")
end

-- ----------------------------
-- Combat capture
-- ----------------------------
local function ensureSession()
  if not R.session then R.session = newSession() end
  return R.session
end

-- Potion coverage (3.18.0): ride EFFECT_CHANGED + pull seed. No GetUnitPower.
-- Dummy heuristic: Major Intellect / Endurance / Fortitude ≈ pot. Expedition
-- alone is often a skill. Do not invent potion DPS.
local POTION_CLUSTER_MS = 250
local POTION_REUSE_MS = 20000

local function potionStatKeyFromName(name)
  local n = safeLower(name)
  if n == "" then return nil end
  if string.find(n, "major intellect", 1, true) then return "intellect" end
  if string.find(n, "major endurance", 1, true) then return "endurance" end
  if string.find(n, "major fortitude", 1, true) then return "fortitude" end
  if string.find(n, "major expedition", 1, true) then return "expedition" end
  return nil
end

local function potionIsCoreStat(key)
  return key == "intellect" or key == "endurance" or key == "fortitude"
end

local function ensurePotion(session)
  if type(session) ~= "table" then return nil end
  local p = session.potion
  if type(p) ~= "table" then
    p = {
      uses = 0,
      kind = "unknown",
      firstUseMs = nil,
      prePot = false,
      coveredMs = 0,
      stats = { intellect = 0, endurance = 0, fortitude = 0, expedition = 0 },
      estimated = false,
    }
    session.potion = p
  end
  p.stats = p.stats or { intellect = 0, endurance = 0, fortitude = 0, expedition = 0 }
  return p
end

local function potionNoteUse(session, tMs, prePot)
  local p = ensurePotion(session)
  if not p then return end
  tMs = tonumber(tMs) or 0
  if p._clusterMs and (tMs - p._clusterMs) < POTION_CLUSTER_MS then
    p._clusterMs = tMs
    return
  end
  if p._lastUseMs and (tMs - p._lastUseMs) < POTION_REUSE_MS then
    p._clusterMs = tMs
    return
  end
  p.uses = (tonumber(p.uses) or 0) + 1
  p._lastUseMs = tMs
  p._clusterMs = tMs
  if p.firstUseMs == nil then
    local start = tonumber(session.startMs) or tMs
    p.firstUseMs = prePot and 0 or math.max(0, tMs - start)
    p.prePot = prePot and true or false
  end
end

local function potionNoteFromBuff(session, buffName, abilityId, tMs, isGain)
  if not isGain or type(session) ~= "table" then return end
  local key = potionStatKeyFromName(buffName)
  if not key then return end
  abilityId = tonumber(abilityId) or 0
  if abilityId > 0 and session.slottedAbilityIds and session.slottedAbilityIds[abilityId] then
    return -- slotted skill (e.g. Rapid Maneuver Expedition)
  end
  if not potionIsCoreStat(key) then return end
  potionNoteUse(session, tMs, false)
end

local function potionNotePrePotFromBuffs(session, tMs)
  if type(session) ~= "table" or type(session.buffs) ~= "table" then return end
  for _, b in pairs(session.buffs) do
    if type(b) == "table" then
      local key = potionStatKeyFromName(b.name)
      if potionIsCoreStat(key) then
        potionNoteUse(session, tMs or session.startMs or 0, true)
        return
      end
    end
  end
end

local function finalizePotion(session)
  if type(session) ~= "table" then return end
  local p = ensurePotion(session)
  if not p then return end
  local dur = tonumber(session.durationMs) or 0
  local stats = { intellect = 0, endurance = 0, fortitude = 0, expedition = 0 }
  if type(session.buffs) == "table" and dur > 0 then
    for _, b in pairs(session.buffs) do
      if type(b) == "table" then
        local key = potionStatKeyFromName(b.name)
        if key and stats[key] ~= nil then
          local up = math.min(1, (tonumber(b.activeMs) or 0) / dur)
          if up > stats[key] then stats[key] = up end
        end
      end
    end
  end
  p.stats = stats
  local coreMax = math.max(stats.intellect or 0, stats.endurance or 0, stats.fortitude or 0)
  p.coveredMs = math.floor(coreMax * dur + 0.5)
  if (tonumber(p.uses) or 0) <= 0 and coreMax >= 0.20 then
    p.uses = 1
    p.prePot = true
    p.firstUseMs = 0
  end
  if stats.intellect >= 0.15 and stats.endurance >= 0.15 and stats.fortitude >= 0.15 then
    p.kind = "tri-stat"
  elseif stats.intellect >= 0.15 and stats.endurance < 0.15 then
    p.kind = "magicka"
  elseif stats.endurance >= 0.15 and stats.intellect < 0.15 then
    p.kind = "stamina"
  elseif coreMax >= 0.15 then
    p.kind = "unknown"
  else
    p.kind = "unknown"
  end
  p.estimated = (session.isDummy ~= true)
  p._clusterMs = nil
  p._lastUseMs = nil
end

-- Seed buffs already active when the pull starts (Major Courage from dummy, food,
-- always-on Major/Minor, etc.). EVENT_EFFECT_CHANGED only fires on change — without
-- this, dummy-contributing buffs never appear on the Buffs page.
local function seedPlayerBuffsAtStart(session, tMs)
  if type(session) ~= "table" then return end
  if type(GetNumBuffs) ~= "function" or type(GetUnitBuffInfo) ~= "function" then return end
  session.buffs = session.buffs or {}
  local okN, n = pcall(GetNumBuffs, "player")
  n = okN and (tonumber(n) or 0) or 0
  if n <= 0 then return end
  for i = 1, n do
    local ok, buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename,
      buffType, effectType, abilityType, statusEffectType, abilityId, canClickOff,
      castByPlayer = pcall(GetUnitBuffInfo, "player", i)
    if not ok then
      -- Some clients return fewer values; try name + abilityId only
      ok, buffName = pcall(function() return select(1, GetUnitBuffInfo("player", i)) end)
      abilityId = 0
      if ok then
        local ok2, id2 = pcall(function() return select(11, GetUnitBuffInfo("player", i)) end)
        if ok2 then abilityId = tonumber(id2) or 0 end
      end
    end
    abilityId = tonumber(abilityId) or 0
    if ok and type(buffName) == "string" and buffName ~= "" then
      local name = zo_strformat and zo_strformat("<<1>>", buffName) or buffName
      -- Prefer abilityId key; fall back to stable name key so abilityId==0 still tracks
      local key = abilityId > 0 and abilityId or ("n:" .. string.lower(name))
      if not session.buffs[key] then
        session.buffs[key] = {
          id = abilityId,
          name = name,
          applied = 1,
          activeMs = 0,
          activeStartMs = tMs,
          seededAtStart = true,
        }
      else
        local b = session.buffs[key]
        if not b.activeStartMs then
          b.activeStartMs = tMs
          b.applied = (b.applied or 0) + 1
        end
      end
    end
  end
  pcall(potionNotePrePotFromBuffs, session, tMs)
end

-- Expensive gear/build/buff snapshots MUST NOT run inside EVENT_COMBAT_EVENT.
-- Doing so on the first hit (3.15–3.17) could drop subsequent combat events on
-- console and under-count multi‑million damage vs Simple DPS.
local function runDeferredStartSnapshots(session, tMs)
  if type(session) ~= "table" or session._startSnapDone then return end
  session._startSnapDone = true
  pcall(function()
    local sets, setMap = captureEquippedSets()
    session.equippedSets = sets
    session.equippedSetMap = setMap
    local slotIds, slotNames, slotBars, slotBarsByName, slotBySlot = captureSlottedAbilities()
    session.slottedAbilityIds = slotIds or session.slottedAbilityIds or {}
    session.slottedAbilityNames = slotNames or session.slottedAbilityNames or {}
    session.slottedAbilityBar = slotBars or session.slottedAbilityBar or {}
    session.slottedAbilityBarByName = slotBarsByName or session.slottedAbilityBarByName or {}
    session.slottedAbilityBySlot = slotBySlot or session.slottedAbilityBySlot or {}
    seedPlayerBuffsAtStart(session, tMs or session.startMs or NowMs())
    if DM2StatsMenuShell and type(DM2StatsMenuShell.CapturePlayerStats) == "function" then
      local okSnap, snap = pcall(DM2StatsMenuShell.CapturePlayerStats)
      if okSnap and type(snap) == "table" then session.playerStatsStart = snap end
    end
    if DM2StatsMenuShell and type(DM2StatsMenuShell.CaptureActiveMundus) == "function" then
      local okM, mundus = pcall(DM2StatsMenuShell.CaptureActiveMundus)
      if okM and mundus and mundus ~= "" then session.mundus = session.mundus or mundus end
    end
    if DM2StatsMenuShell and type(DM2StatsMenuShell.CaptureSessionBuild) == "function" then
      local okB, build = pcall(DM2StatsMenuShell.CaptureSessionBuild, session, "start")
      if okB and type(build) == "table" then
        session.buildStart = build
        session.build = session.build or build
      end
    end
    p3InitBarAtCombatStart(session, tMs or session.startMs or NowMs())
  end)
end

local function startIfNeeded(session, tMs, targetName)
  if session.started then return end
  -- When open-world tracking is OFF: only start on dummy name or housing.
  -- Never sticky-skip the session — first hits often have empty target names;
  -- a later "Target Iron Atronach, Trial" event must still be allowed to start.
  if SV and SV.settings and SV.settings.trackOpenWorld == false then
    if not shouldStartDummyOnlyCapture(targetName) then
      return
    end
  end
  session.started = true
  -- Prefer first damage timestamp if hits arrived before dummy name was recognized
  session.startMs = tonumber(session.firstDamageMs) or tMs
  session.lastTargetName = targetName
  session.lastDamageMs = tonumber(session.lastDamageMs) or tMs
  session._startSnapDone = false

  -- Lean start only. Defer gear/build/buff capture to next frame so combat events
  -- keep flowing (matches older Parse / Simple DPS accuracy priority).
  if type(zo_callLater) == "function" then
    zo_callLater(function()
      if R.session == session and session.started then
        runDeferredStartSnapshots(session, tMs)
      end
    end, 0)
  else
    runDeferredStartSnapshots(session, tMs)
  end
end

local function closeActiveBuffs(session)
  if type(session) ~= "table" then return end
  -- close any active buff windows at endMs
  if type(session.buffs) == "table" then
    for _, b in pairs(session.buffs) do
      if type(b) == "table" and b.activeStartMs then
        b.activeMs = (b.activeMs or 0) + math.max(0, (session.endMs or 0) - b.activeStartMs)
        b.activeStartMs = nil
      end
    end
  end
  -- close open enemy debuff windows
  if type(session.targetDebuffs) == "table" then
    for _, d in pairs(session.targetDebuffs) do
      if type(d) == "table" and d.activeStartMs then
        d.activeMs = (d.activeMs or 0) + math.max(0, (session.endMs or 0) - d.activeStartMs)
        d.activeStartMs = nil
      end
    end
  end
end

-- Wall-clock for history stamps (console-safe; os may be restricted)
local function safeWallClock()
  if type(GetTimeStamp) == "function" then
    local ok, ts = pcall(GetTimeStamp)
    if ok and tonumber(ts) and tonumber(ts) > 0 then return tonumber(ts) end
  end
  if type(os) == "table" and type(os.time) == "function" then
    local ok, ts = pcall(os.time)
    if ok and tonumber(ts) and tonumber(ts) > 0 then return tonumber(ts) end
  end
  return 0
end

-- Core finalize must never throw — enrichment is all pcall'd. A single Lua error
-- on combat-end previously dropped the entire parse from history.
local function finalizeSession(session)
  if type(session) ~= "table" then return nil end
  -- Ensure deferred start snaps finished before fingerprint/build end work
  if not session._startSnapDone then
    pcall(runDeferredStartSnapshots, session, session.startMs)
  end
  local combatEndMs = NowMs()
  -- DPS duration: end at last outgoing damage (matches DM2 Simple DPS / chat parse).
  -- Combat-end alone includes post-pull idle and under-reports DPS ~5–15%.
  local lastDmg = tonumber(session.lastDamageMs) or 0
  local startMs = tonumber(session.startMs) or combatEndMs
  if lastDmg > startMs then
    session.endMs = lastDmg
  else
    session.endMs = combatEndMs
  end
  session.combatEndMs = combatEndMs
  session.durationMs = math.max(0, session.endMs - startMs)
  -- Cheap reject before gear/build/Phase-3 snapshots (open-world trash fights)
  do
    local minMs = tonumber(SV and SV.settings and SV.settings.minFightMs) or 0
    local minDmg = tonumber(SV and SV.settings and SV.settings.minDamage) or 0
    if session.durationMs < minMs or (tonumber(session.totalDamage) or 0) < minDmg then
      return nil
    end
  end

  pcall(closeActiveBuffs, session)
  pcall(finalizePendingWeave, session, true)
  if session.weave and session.weave.pendingPostChannel then
    pcall(pushTimelineToken, session, session.weave.pendingPostChannel, SYM_POST_MISS, "Missed",
      { kind = "postchannel", skillName = session.weave.pendingPostChannel, missed = true })
    session.weave.pendingPostChannel = nil
  end
  pcall(retryAbilityNames, session)
  pcall(reconcileWeaveTimelineNames, session)
  pcall(reconcileSetContributions, session)
  if session.weave then
    local okMap, map = pcall(buildWeaveSkillBarMap, session)
    if okMap and type(map) == "table" then session.weave.skillBarByName = map end
  end

  session.isDummy = isDummyParseConfidence(session.lastTargetName)
  session.completedAt = safeWallClock()
  pcall(finalizePotion, session)

  -- Snapshot character stats (Sheet vs Temp) at fight end for Dashboard / Build
  if DM2StatsMenuShell and type(DM2StatsMenuShell.CapturePlayerStats) == "function" then
    local okSnap, snap = pcall(DM2StatsMenuShell.CapturePlayerStats)
    if okSnap and type(snap) == "table" then
      session.playerStats = snap
      session.playerStatsEnd = snap
    end
  end
  if DM2StatsMenuShell and type(DM2StatsMenuShell.CaptureActiveMundus) == "function" then
    local okM, mundus = pcall(DM2StatsMenuShell.CaptureActiveMundus)
    if okM and mundus and mundus ~= "" then
      session.mundus = mundus
    end
  end
  -- Refresh bars/sets before fingerprint so a partial start read cannot mint a new Build ID
  pcall(mergeLiveGearAndSlots, session)
  -- Phase 1: build snapshot + fingerprint at fight end (canonical for history)
  if DM2StatsMenuShell and type(DM2StatsMenuShell.CaptureSessionBuild) == "function" then
    local okB, build = pcall(DM2StatsMenuShell.CaptureSessionBuild, session, "end")
    if okB and type(build) == "table" then
      session.buildEnd = build
      session.build = build
      session.buildFingerprint = build.fingerprint
      session.buildFingerprintLabel = build.fingerprintLabel
      if type(build.coreKey) == "string" and build.coreKey ~= "" then
        session.coreBuildKey = build.coreKey
      end
    end
  end
  -- Phase 2.5.1: if mid-fight sheet samples were empty, try end-of-fight sheet once
  pcall(function()
    local cds = session.critDmgStats
    if type(cds) == "table" and (tonumber(cds.samples) or 0) <= 0 then
      local sheetPct = 0
      if DM2StatsMenuShell and type(DM2StatsMenuShell.ReadSheetCritDamagePercent) == "function" then
        local okS, v = pcall(DM2StatsMenuShell.ReadSheetCritDamagePercent)
        if okS and tonumber(v) and tonumber(v) > 0 then sheetPct = tonumber(v) end
      end
      if sheetPct <= 0 and type(session.playerStatsEnd) == "table" and session.playerStatsEnd.buffed then
        local raw = tonumber(session.playerStatsEnd.buffed.critDamage) or 0
        if raw > 0 then
          if raw <= 2 then sheetPct = raw * 100
          elseif raw <= 100 then sheetPct = raw
          else sheetPct = raw end
        end
      end
      if sheetPct > 0 then
        local elig = tonumber(cds.eligibleDmg) or tonumber(session.totalDamage) or 0
        if elig > 0 then
          cds.source = "sheet_end"
          cds.samples = 1
          cds.sampleWeight = elig
          cds.sampleCritDmgSum = elig * sheetPct
          cds.lastSheetCritPct = sheetPct
          cds.sampleSeries = { { dmg = elig, pct = sheetPct } }
        end
      end
    end
  end)
  -- Finalize exposure onto session (coach re-runs too; this persists for history)
  if DM2StatsMenuShell and type(DM2StatsMenuShell.FinalizeCritDmgExposure) == "function" then
    local okE, exp = pcall(DM2StatsMenuShell.FinalizeCritDmgExposure, session)
    if okE and type(exp) == "table" then
      session.critDmgExposure = exp
    end
  end

  -- Phase 3 P0: close bar dwell + finalize windows / gaps / exec summary
  pcall(p3AccrueBarDwell, session, session.endMs or NowMs())
  if DM2StatsMenuShell and type(DM2StatsMenuShell.FinalizePhase3Execution) == "function" then
    pcall(DM2StatsMenuShell.FinalizePhase3Execution, session)
  end

  -- Phase 2.5 scaffold: attach parse to active controlled experiment when fingerprint holds
  if DM2StatsMenuShell and type(DM2StatsMenuShell.TryAttachExperimentRun) == "function" then
    pcall(DM2StatsMenuShell.TryAttachExperimentRun, session)
  end

  -- Never leave coach/analysis caches on the session (SV write-back hazard)
  session.coach = nil
  session._coachTok = nil

  return session
end

-- Normalize combat flag (console may pass 1/0 instead of boolean)
local function combatFlagIsIn(inCombat)
  if inCombat == true or inCombat == 1 then return true end
  if inCombat == false or inCombat == 0 or inCombat == nil then return false end
  return not not inCombat
end

local function notifyHistorySaved(session, _pathNote)
  if type(session) ~= "table" then return end
  local dps = 0
  local dur = tonumber(session.durationMs) or 0
  local dmg = tonumber(session.totalDamage) or 0
  if dur > 0 then dps = dmg / (dur / 1000) end
  local tgt = tostring(session.lastTargetName or "fight")
  if #tgt > 40 then tgt = string.sub(tgt, 1, 37) .. "..." end
  -- Same shape as ESO dummy chat: "Result: 14332.7 DPS, 34s (Target Name)"
  d(string.format("|c88ff88DM2 Parse|r: Result: %s DPS, %0.1fs (%s)", fmtDps(dps), dur / 1000, tgt))
  -- Menu open: jump to newest fight so History isn't stuck on stale view
  if DM2StatsMenuShell and type(DM2StatsMenuShell.OnFightSaved) == "function" then
    pcall(DM2StatsMenuShell.OnFightSaved)
  end
end

function R:OnCombatState(_, inCombat)
  local nowIn = combatFlagIsIn(inCombat)
  self.inCombat = nowIn

  if nowIn then
    cancelQueuedResultsPopup()
    -- Do NOT wipe a capture already in progress (combat-state can re-fire mid-dummy).
    -- Also keep unstarted session if it already has damage (dummy name lag).
    if self.session and self.session.started then
      return
    end
    if self.session and (tonumber(self.session.totalDamage) or 0) > 0 then
      return -- preserve damage while waiting for dummy-name start
    end
    self.session = newSession()
    return
  end

  -- combat ended — hide any active weave flash
  hideWeaveFlash()

  -- Guard against double end (event + watchdog)
  if self._finalizingCombat then return end

  local live = self.session

  -- Housing dummy: combat flag can drop briefly while DoTs still tick.
  -- Defer finalize until 2.1s after last damage (same idea as Simple DPS last-hit end).
  if live and live.started and not self._forceCombatEnd then
    local last = tonumber(live.lastDamageMs) or 0
    local gap = (last > 0) and (NowMs() - last) or 99999
    if gap < 2000 then
      if type(zo_callLater) == "function" and not self._deferredCombatEnd then
        self._deferredCombatEnd = true
        local wait = math.max(100, 2100 - gap)
        zo_callLater(function()
          self._deferredCombatEnd = false
          -- Re-entered combat for real → abort deferred end
          if type(IsUnitInCombat) == "function" then
            local ok, ic = pcall(IsUnitInCombat, "player")
            if ok and combatFlagIsIn(ic) then
              self.inCombat = true
              return
            end
          end
          local still = self.session
          if still and still.started then
            local last2 = tonumber(still.lastDamageMs) or 0
            if last2 > 0 and (NowMs() - last2) < 2000 then
              -- still dealing damage; wait again
              self.inCombat = false
              self:OnCombatState(nil, false)
              return
            end
          end
          self._forceCombatEnd = true
          self.inCombat = false
          self:OnCombatState(nil, false)
          self._forceCombatEnd = false
        end, wait)
      end
      return
    end
  end

  if not live or not live.started then
    -- Never started (filters / no damage): drop with no chat
    self.session = nil
    return
  end

  self._finalizingCombat = true

  -- Never let a finalize error eat the parse
  local okFin, sOrErr = pcall(finalizeSession, live)
  local s = nil
  if okFin then
    s = sOrErr
  else
    -- Salvage: stamp duration and force-save raw session
    d("|cFF6666DM2 Parse|r: finalize error (saving raw parse): " .. tostring(sOrErr))
    local salvageEnd = tonumber(live.lastDamageMs) or 0
    if salvageEnd <= (tonumber(live.startMs) or 0) then salvageEnd = NowMs() end
    live.endMs = live.endMs or salvageEnd
    live.durationMs = math.max(0, (live.endMs or 0) - (tonumber(live.startMs) or 0))
    live.completedAt = live.completedAt or safeWallClock()
    live.isDummy = isDummyParseConfidence(live.lastTargetName)
    live.coach = nil
    live._coachTok = nil
    local minMs = tonumber(SV and SV.settings and SV.settings.minFightMs) or 0
    local minDmg = tonumber(SV and SV.settings and SV.settings.minDamage) or 0
    if live.durationMs >= minMs and (tonumber(live.totalDamage) or 0) >= minDmg then
      s = live
    end
  end

  if not s then
    -- Too short / too little damage / not dummy: drop with no chat
    self.session = nil
    self._finalizingCombat = false
    return
  end

  local okPush, retOrErr = pcall(pushHistory, s)
  if okPush and retOrErr then
    notifyHistorySaved(s, nil)
  else
    if not okPush then
      d("|cFF6666DM2 Parse|r: history save error: " .. tostring(retOrErr))
    else
      d("|cFF6666DM2 Parse|r: history save returned false (SV missing?).")
    end
    -- Last-ditch: assign into ring without compact
    if SV and type(SV.history) == "table" then
      local max = historyMaxSetting()
      SV.lastIndex = (tonumber(SV.lastIndex) or 0) + 1
      local slot = ((SV.lastIndex - 1) % max) + 1
      s.coach = nil
      s._coachTok = nil
      SV.history[slot] = s
      SV.history[tostring(slot)] = nil
      if R then R.SV = SV end
      notifyHistorySaved(s, "emergency")
    end
  end

  -- auto-popup only for dummy parses
  if SV and SV.settings and SV.settings.enable and SV.settings.autoPopupAfterParse and s.isDummy then
    pcall(queueResultsPopup)
  end

  self.session = nil
  self._finalizingCombat = false
end

-- Backup: some housing/dummy setups flicker or miss EVENT_PLAYER_COMBAT_STATE.
-- Poll IsUnitInCombat and drive the same enter/leave path.
-- Grace: if damage still landed recently, do NOT end the parse (false "out of combat"
-- mid-dummy was cutting multi‑million damage off the total).
function R:CombatWatchTick()
  if not SV or not SV.settings or not SV.settings.enable then return end
  if type(IsUnitInCombat) ~= "function" then return end
  local ok, inCombat = pcall(IsUnitInCombat, "player")
  if not ok then return end
  local nowIn = combatFlagIsIn(inCombat)
  if nowIn == (self.inCombat == true) then return end
  if not nowIn and self.session and self.session.started then
    local last = tonumber(self.session.lastDamageMs) or 0
    if last > 0 and (NowMs() - last) < 2000 then
      return -- still dealing damage; wait for real combat end
    end
  end
  self:OnCombatState(nil, nowIn)
end

-- ----------------------------
-- Input-based rotation capture (v3.0.25)
-- Fires the instant the player presses ANY action bar button (LA, skill, ultimate).
-- Both LA presses and skill presses are captured here for accurate weave timing.
-- The weave gap is measured as: skill press → next LA press (all input-based).
-- ----------------------------
function R:OnActionSlotAbilityUsed(_, actionSlotIndex)
  if not SV or not SV.settings.enable then return end
  actionSlotIndex = tonumber(actionSlotIndex) or 0
  if actionSlotIndex < 1 then return end

  -- Must be in combat or have an active session
  local session = self.session
  if not session or not session.started then return end

  local tMs = NowMs()
  local w = session.weave
  if not w then return end

  -- Slots: 1=LA, 2=HA, 3-8=abilities (3=square, 4=triangle, 5=circle, 6=L1, 7=R1), 8+=ultimate/other
  local isLA = (actionSlotIndex == 1)
  local isHA = (actionSlotIndex == 2)

  -- -------------------------------------------------------
  -- LIGHT ATTACK pressed (slot 1): resolve pending weave
  -- -------------------------------------------------------
  if isLA then
    w.laPressCount = (w.laPressCount or 0) + 1
    -- Phase 3: LA also ends swap-delay measurement
    p3NotePostSwapAction(session, tMs)

    -- Resolve post-channel: LA after a channel = good recovery
    if w.pendingPostChannel then
      pushTimelineToken(session, w.pendingPostChannel, SYM_POST_OK, "Good",
        { kind = "postchannel", skillName = w.pendingPostChannel })
      w.pendingPostChannel = nil
      flashWeaveResult("Good")

    -- Resolve pending skill: measure gap from skill press to this LA press
    elseif w.pendingSkill then
      local gap = tMs - (w.pendingSkill.tMs or tMs)
      local symbol, resultLabel = classifyWeaveGap(gap)
      if symbol == SYM_FAST then w.tooFastCount = (w.tooFastCount or 0) + 1 end
      if symbol == SYM_LATE then w.lateCount = (w.lateCount or 0) + 1 end
      if symbol == SYM_MISS then w.missedCount = (w.missedCount or 0) + 1 end
      if symbol == SYM_OK then w.onTimeCount = (w.onTimeCount or 0) + 1 end
      pushTimelineToken(session, w.pendingSkill.label, symbol, resultLabel,
        { kind = "skill", skillName = w.pendingSkill.skillName or w.pendingSkill.label,
          gapMs = gap, missed = (symbol == SYM_MISS),
          slot = w.pendingSkill.slot, bar = w.pendingSkill.bar,
          abilityId = w.pendingSkill.abilityId, icon = w.pendingSkill.icon })
      w.pendingSkill = nil
      flashWeaveResult(resultLabel)
    end

    -- Track LA-to-LA intervals from input presses
    if w.lastLaPressMs then
      local delta = tMs - w.lastLaPressMs
      if delta > 0 then
        w.laIntervals = w.laIntervals or {}
        if #w.laIntervals >= 256 then
          -- keep newest half
          local slim = {}
          for i = #w.laIntervals - 127, #w.laIntervals do slim[#slim + 1] = w.laIntervals[i] end
          w.laIntervals = slim
        end
        w.laIntervals[#w.laIntervals + 1] = delta
      end
    end
    w.lastLaPressMs = tMs
    return  -- done handling LA
  end

  -- Heavy attack: just note it, don't drive weave logic
  if isHA then return end

  -- -------------------------------------------------------
  -- SKILL pressed (slot 3-8): capture for rotation timeline
  -- -------------------------------------------------------

  -- Resolve which ability is in this slot right now
  local abilityId = 0
  local abilityName = ""
  local barCategory = nil

  if type(GetActiveHotbarCategory) == "function" then
    local ok, cat = pcall(GetActiveHotbarCategory)
    if ok then barCategory = cat end
  end

  if type(GetSlotBoundId) == "function" then
    local ok, id
    if barCategory ~= nil then
      ok, id = pcall(GetSlotBoundId, actionSlotIndex, barCategory)
    else
      ok, id = pcall(GetSlotBoundId, actionSlotIndex)
    end
    if ok then abilityId = tonumber(id) or 0 end
  end

  if abilityId <= 0 then return end  -- empty slot or failed lookup

  abilityName = resolveAbilityName(abilityId)
  if not abilityName or abilityName == "" then abilityName = "Ability " .. tostring(abilityId) end
  -- Snapshot the slot texture now (console/scribed). GetAbilityIcon often fails later.
  local iconTex = nil
  if type(GetSlotTexture) == "function" then
    local okT, tex
    if barCategory ~= nil then okT, tex = pcall(GetSlotTexture, actionSlotIndex, barCategory)
    else okT, tex = pcall(GetSlotTexture, actionSlotIndex) end
    if okT and tex and tex ~= "" and not isBadAbilityIconTex(tex) then iconTex = tex end
  end
  if not iconTex then iconTex = getAbilityIcon(abilityId) end

  -- Determine bar label for debug
  local barLabel = "?"
  if barCategory ~= nil then
    if type(HOTBAR_CATEGORY_PRIMARY) ~= "nil" and barCategory == HOTBAR_CATEGORY_PRIMARY then
      barLabel = "Front"
    elseif type(HOTBAR_CATEGORY_BACKUP) ~= "nil" and barCategory == HOTBAR_CATEGORY_BACKUP then
      barLabel = "Back"
    end
  elseif self._activeBar ~= nil then
    if type(HOTBAR_CATEGORY_PRIMARY) ~= "nil" and self._activeBar == HOTBAR_CATEGORY_PRIMARY then
      barLabel = "Front"
    elseif type(HOTBAR_CATEGORY_BACKUP) ~= "nil" and self._activeBar == HOTBAR_CATEGORY_BACKUP then
      barLabel = "Back"
    end
  end

  -- Check if this is a channel ability
  local isChannel = isChannelAbilityLabel(abilityName)

  -- Debug logging: log every skill button press
  trackRotationDebug(session, abilityId, abilityName, true,
    string.format("slot %d %s bar", actionSlotIndex, barLabel))

  -- Handle pending post-channel recovery: skill after channel without LA = miss
  if w.pendingPostChannel then
    if not isChannel then
      pushTimelineToken(session, w.pendingPostChannel, SYM_POST_MISS, "Missed",
        { kind = "postchannel", skillName = w.pendingPostChannel, missed = true })
      w.pendingPostChannel = nil
      flashWeaveResult("Missed")
    end
  end

  -- If there was already a pending skill waiting for a LA weave, mark it missed
  -- (two skills in a row without a LA between them)
  if w.pendingSkill then
    pushTimelineToken(session, w.pendingSkill.label, SYM_MISS, "Missed",
      { kind = "skill", skillName = w.pendingSkill.skillName or w.pendingSkill.label, missed = true,
        abilityId = w.pendingSkill.abilityId, slot = w.pendingSkill.slot, bar = w.pendingSkill.bar,
        icon = w.pendingSkill.icon })
    w.missedCount = (w.missedCount or 0) + 1
    w.pendingSkill = nil
    flashWeaveResult("Missed")
  end

  -- Push channel or normal skill onto timeline
  if isChannel then
    if not w.pendingPostChannel then
      local channelLabel = trimSkillLabel(abilityName)
      pushTimelineToken(session, channelLabel, "", "Channel",
        { kind = "channel", skillName = abilityName, dashes = getChannelDashCount(abilityName),
          bar = barLabel, abilityId = abilityId, slot = actionSlotIndex, icon = iconTex })
      w.pendingPostChannel = "Post-" .. trimSkillLabel(abilityName, 14)
    end
  else
    w.pendingSkill = {
      label = trimSkillLabel(abilityName),
      skillName = abilityName,
      abilityId = abilityId,
      tMs = tMs,
      slot = actionSlotIndex,
      bar = barLabel,
      icon = iconTex,
    }
  end

  -- Track fast skill presses (queue overwrites)
  local minSkillGap = 120
  local fastSkillGap = tonumber(SV.settings.queueOverwriteMs) or 450
  if w.lastSkillEventMs then
    local skillDelta = tMs - w.lastSkillEventMs
    if skillDelta >= minSkillGap then
      w.skillEventCount = (w.skillEventCount or 0) + 1
      if skillDelta < fastSkillGap then
        w.fastSkillPresses = (w.fastSkillPresses or 0) + 1
      end
    end
  else
    w.skillEventCount = (w.skillEventCount or 0) + 1
  end
  w.lastSkillEventMs = tMs

  -- Store input metadata
  w.lastInputSlot = actionSlotIndex
  w.lastInputAbilityId = abilityId
  w.lastInputBar = barLabel
  w.lastInputMs = tMs
  w.inputSkillPresses = (w.inputSkillPresses or 0) + 1
  recordSkillBar(session, abilityId, barLabel, abilityName)

  -- Phase 3 P0: swap→first action delay + ultimate casts
  p3NotePostSwapAction(session, tMs)
  if p3IsUltPress(session, actionSlotIndex, abilityId, abilityName) then
    p3RecordUltCast(session, tMs, abilityId)
  end
end

-- ----------------------------
-- Bar swap detection (v3.0.25 + Phase 3 dwell/delay)
-- ----------------------------
function R:OnActiveWeaponPairChanged(_, activeWeaponPair, locked)
  if not SV or not SV.settings.enable then return end

  -- Debounce: this event fires up to 3 times per swap
  local tMs = NowMs()
  if (tMs - self._lastBarSwapMs) < 100 then return end
  self._lastBarSwapMs = tMs

  -- Update active bar tracking
  if type(GetActiveHotbarCategory) == "function" then
    local ok, cat = pcall(GetActiveHotbarCategory)
    if ok then self._activeBar = cat end
  end

  -- Refresh slotted abilities on the session (merge — never wipe a bar that
  -- failed to re-read; replacing the whole map made build fingerprints drift).
  local session = self.session
  if session and session.started then
    local slotIds, slotNames, slotBars, slotBarsByName, slotBySlot = captureSlottedAbilities()
    session.slottedAbilityIds = session.slottedAbilityIds or {}
    for id, v in pairs(slotIds or {}) do session.slottedAbilityIds[id] = v end
    session.slottedAbilityNames = session.slottedAbilityNames or {}
    for nk, v in pairs(slotNames or {}) do session.slottedAbilityNames[nk] = v end
    session.slottedAbilityBar = session.slottedAbilityBar or {}
    for id, bar in pairs(slotBars or {}) do
      session.slottedAbilityBar[id] = bar
    end
    session.slottedAbilityBarByName = session.slottedAbilityBarByName or {}
    for nameKey, bar in pairs(slotBarsByName or {}) do
      session.slottedAbilityBarByName[nameKey] = bar
    end
    session.slottedAbilityBySlot = session.slottedAbilityBySlot or {}
    for k, entry in pairs(slotBySlot or {}) do
      if type(entry) == "table" and (tonumber(entry.id) or 0) > 0 then
        session.slottedAbilityBySlot[k] = entry
      end
    end
    if not session.weave then session.weave = {} end
    session.weave.barSwapCount = (session.weave.barSwapCount or 0) + 1

    -- Phase 3: dwell accrue + swap list + pending delay
    p3AccrueBarDwell(session, tMs)
    local bs = p3EnsureBarStats(session)
    local toBar = p3BarLabelFromCategory(self._activeBar) or "Front"
    if bs then
      bs.currentBar = toBar
      bs.pendingSwapMs = tMs
      local swaps = bs.swaps
      if #swaps < P3_MAX_SWAPS then
        swaps[#swaps + 1] = { tMs = tMs, toBar = toBar }
      end
    end
    p3PushMarker(session, tMs, "swap", toBar)
  end
end

function R:OnCombatEvent(_, result, isError, abilityName, abilityGraphic, abilityActionSlotType,
                          sourceName, sourceType, targetName, targetType, hitValue, powerType,
                          damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)
  if not SV or not SV.settings or not SV.settings.enable then return end

  ------------------------------------------------------------------
  -- Mirror Simple DPS hot path. C-side filters already restrict to
  -- PLAYER + PLAYER_PET. Do NOT re-check sourceType in Lua — on console
  -- filtered events sometimes omit/alter sourceType and we were dropping
  -- ~20% of damage (e.g. 4.70M Simple vs 3.80M Parse at identical 42.0s).
  -- Fallback unfiltered registration still needs a soft Lua gate below.
  ------------------------------------------------------------------
  if self._combatNeedsLuaSourceGate then
    if sourceType ~= COMBAT_UNIT_TYPE_PLAYER
        and not (type(COMBAT_UNIT_TYPE_PLAYER_PET) == "number"
                 and sourceType == COMBAT_UNIT_TYPE_PLAYER_PET) then
      return
    end
  end

  -- Healing (not part of DPS total)
  if result == ACTION_RESULT_HEAL or result == ACTION_RESULT_CRITICAL_HEAL then
    if isError then return end
    local heal = combatHitDamage(hitValue, overflow)
    if heal > 0 then
      local session = ensureSession()
      startIfNeeded(session, NowMs(), targetName)
      if session.started then
        session.totalHealing = (session.totalHealing or 0) + heal
        session.effectiveHealing = (session.effectiveHealing or 0) + heal
      end
    end
    return
  end

  -- Non-DPS combat rows (effect apply etc.) — keep out of total path
  if not isDpsTotalDamageResult(result) then
    if isEffectApplyResult(result) then
      local session = self.session
      if session and session.started then
        local tMs = NowMs()
        local name = resolveAbilityName(abilityId, abilityName)
        if type(ACTION_RESULT_EFFECT_FADED) == "number" and result == ACTION_RESULT_EFFECT_FADED then
          recordTargetDebuffFade(session, abilityId, name, tMs)
        else
          recordTargetDebuffApply(session, abilityId, name, tMs, targetName)
        end
      end
    end
    return
  end

  -- === Simple DPS equivalent gates ===
  if isError then return end
  local dmg = combatHitDamage(hitValue, overflow)
  if dmg <= 0 then return end

  local tMs = NowMs()
  local session = ensureSession()
  if targetName and targetName ~= "" then
    session.lastTargetName = targetName
  end
  -- Start gate BEFORE tallying — otherwise open-world-OFF rejects still inflate
  -- totalDamage with no skill rows (Damage page looks "empty" vs Simple total).
  startIfNeeded(session, tMs, targetName)
  if not session.started then return end
  if not session.firstDamageMs then session.firstDamageMs = tMs end
  -- TOTAL — same as Simple fightDamage += hitValue (once capture is live)
  session.totalDamage = (tonumber(session.totalDamage) or 0) + dmg
  session.lastDamageMs = tMs

  -- --- Lean breakdown (must stay cheap; never call resolveSetName / sheet APIs) ---
  local dot = isDotResult(result)
  local crit = (result == ACTION_RESULT_CRITICAL_DAMAGE) or (result == ACTION_RESULT_DOT_TICK_CRITICAL)
  if dot then
    session.dotDamage = (tonumber(session.dotDamage) or 0) + dmg
    local dt = session.dotTicks
    abilityId = tonumber(abilityId) or 0
    local e = dt[abilityId]
    if not e then
      e = {
        name = (abilityName and abilityName ~= "" and zo_strformat("<<1>>", abilityName)) or ("DoT " .. tostring(abilityId)),
        ticks = {},
        tickCount = 0,
        activeMs = 0,
        lastTickMs = nil,
        intervalSum = 0,
        intervalN = 0,
        medianIntervalMs = 2000,
      }
      dt[abilityId] = e
    end
    e.tickCount = (tonumber(e.tickCount) or 0) + 1
    local last = tonumber(e.lastTickMs)
    if last and tMs > last then
      local gap = tMs - last
      if gap >= 80 and gap < 8000 then
        e.intervalSum = (tonumber(e.intervalSum) or 0) + gap
        e.intervalN = (tonumber(e.intervalN) or 0) + 1
        e.medianIntervalMs = e.intervalSum / math.max(1, e.intervalN)
        local med = tonumber(e.medianIntervalMs) or 2000
        if med < 200 then med = 200 end
        if gap <= math.max(med * 2.5, 4000) then
          e.activeMs = (tonumber(e.activeMs) or 0) + gap
        end
      end
    end
    e.lastTickMs = tMs
    local ticks = e.ticks
    if type(ticks) ~= "table" then ticks = {}; e.ticks = ticks end
    if #ticks < 16 then
      ticks[#ticks + 1] = tMs
    else
      ticks[#ticks] = tMs
    end
  else
    session.directDamage = (tonumber(session.directDamage) or 0) + dmg
  end

  session.hitCount = (session.hitCount or 0) + 1
  if crit then session.critCount = (session.critCount or 0) + 1 end
  if dmg > (session.maxHit or 0) then session.maxHit = dmg end

  -- Crit exposure: running totals only (sheet sample deferred to finalize)
  do
    local cds = session.critDmgStats
    if type(cds) == "table" then
      cds.eligibleDmg = (cds.eligibleDmg or 0) + dmg
      if crit then cds.critHitDmg = (cds.critHitDmg or 0) + dmg end
    end
  end

  local idx = bucketIndexFor(session, tMs)
  local b = ensureBucket(session, idx)
  b.dmg = b.dmg + dmg
  if dot then b.dot = b.dot + dmg else b.direct = b.direct + dmg end
  b.hits = b.hits + 1
  if crit then b.crit = b.crit + 1 end
  abilityId = tonumber(abilityId) or 0
  b.skills[abilityId] = (b.skills[abilityId] or 0) + dmg

  local resolvedAbilityName = abilityName
  if resolvedAbilityName and resolvedAbilityName ~= "" and zo_strformat then
    resolvedAbilityName = zo_strformat("<<1>>", resolvedAbilityName)
  end
  local s = ensureSkill(session, abilityId, resolvedAbilityName)
  s.dmg = s.dmg + dmg
  s.hits = s.hits + 1
  if crit then s.crit = s.crit + 1 end
  if dmg > (s.max or 0) then s.max = dmg end
  if dot then s.dot = s.dot + dmg else s.direct = s.direct + dmg end
  local dt = tonumber(damageType)
  if dt then
    s.damageTypes = s.damageTypes or {}
    s.damageTypes[dt] = (s.damageTypes[dt] or 0) + dmg
  end

  if isLightAttack(abilityId, abilityName, abilityActionSlotType) then
    local w = session.weave
    if w then
      w.laCount = (w.laCount or 0) + 1
      w.lastLaHitMs = tMs
    end
  end
end

function R:OnEffectChanged(_, changeType, effectSlot, effectName, unitTag, beginTime, endTime,
                           stackCount, iconName, buffType, effectType, abilityType, statusEffectType,
                           unitName, unitId, abilityId, sourceType)
  if not SV.settings.enable then return end
  if not self.session or not self.session.started then return end

  local session = self.session
  abilityId = tonumber(abilityId) or 0
  local tMs = NowMs()
  local resolvedEffectName = resolveAbilityName(abilityId, effectName)
  if (not resolvedEffectName or resolvedEffectName == "") and effectName and effectName ~= "" then
    resolvedEffectName = zo_strformat("<<1>>", effectName)
  end

  ------------------------------------------------------------------
  -- Target / enemy debuffs (reticle target or any non-player unit)
  -- Prefer effects you (or pet) applied; also keep known status names.
  ------------------------------------------------------------------
  if unitTag ~= "player" then
    local fromUs = false
    if type(COMBAT_UNIT_TYPE_PLAYER) == "number" and sourceType == COMBAT_UNIT_TYPE_PLAYER then fromUs = true end
    if type(COMBAT_UNIT_TYPE_PLAYER_PET) == "number" and sourceType == COMBAT_UNIT_TYPE_PLAYER_PET then fromUs = true end
    -- Unknown sourceType: still accept known enemy statuses on target tags (Off Balance often)
    local knownStatus = classifyTargetStatusKind(resolvedEffectName) ~= nil
    local tag = tostring(unitTag or "")
    local isTargetTag = (tag == "reticleover" or tag == "reticleoverplayer"
      or tag == "" -- some clients omit tag
      or string.find(tag, "boss", 1, true) == 1 or string.find(tag, "target", 1, true) == 1)
    -- Allow abilityId == 0 when name is a known status (Off Balance etc.)
    local canTrack = (fromUs or knownStatus) and (isTargetTag or fromUs or knownStatus)
    if canTrack and (abilityId > 0 or knownStatus) then
      if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED
          or (type(EFFECT_RESULT_FULL_REFRESH) == "number" and changeType == EFFECT_RESULT_FULL_REFRESH) then
        recordTargetDebuffApply(session, abilityId, resolvedEffectName, tMs, unitName or session.lastTargetName)
      elseif changeType == EFFECT_RESULT_FADED then
        recordTargetDebuffFade(session, abilityId, resolvedEffectName, tMs)
      end
    end
    return
  end

  ------------------------------------------------------------------
  -- Player buffs (existing path)
  ------------------------------------------------------------------
  local resolvedName = resolvedEffectName
  if (not resolvedName or resolvedName == "") and effectName and effectName ~= "" then
    resolvedName = zo_strformat("<<1>>", effectName)
  end
  -- abilityId can be 0 on some dummy/external effects — still track by name
  if abilityId == 0 and (not resolvedName or resolvedName == "") then return end

  local key = abilityId > 0 and abilityId or ("n:" .. string.lower(tostring(resolvedName or "")))
  local b = session.buffs[key]
  if not b then
    b = {
      id = abilityId,
      name = (resolvedName and resolvedName ~= "") and resolvedName
        or ((effectName and effectName ~= "") and zo_strformat("<<1>>", effectName) or ("Buff " .. tostring(abilityId))),
      applied = 0,
      activeMs = 0,
      activeStartMs = nil,
    }
    session.buffs[key] = b
  elseif (not b.name or b.name == "") and resolvedName and resolvedName ~= "" then
    b.name = resolvedName
  end

  -- sourceType: COMBAT_UNIT_TYPE_PLAYER / GROUP / OTHER / … (when API provides it)
  if sourceType ~= nil then
    b.sourceType = sourceType
    if type(COMBAT_UNIT_TYPE_PLAYER) == "number" and sourceType == COMBAT_UNIT_TYPE_PLAYER then
      b.fromSelf = true
    elseif type(COMBAT_UNIT_TYPE_PLAYER_PET) == "number" and sourceType == COMBAT_UNIT_TYPE_PLAYER_PET then
      b.fromSelf = true
      b.fromPet = true
    elseif type(COMBAT_UNIT_TYPE_GROUP) == "number" and sourceType == COMBAT_UNIT_TYPE_GROUP then
      b.fromGroup = true
    elseif type(COMBAT_UNIT_TYPE_OTHER) == "number" and sourceType == COMBAT_UNIT_TYPE_OTHER then
      b.fromExternal = true
      b.fromDummy = true -- trial dummy / world units often report OTHER
    elseif type(COMBAT_UNIT_TYPE_NONE) == "number" and sourceType == COMBAT_UNIT_TYPE_NONE then
      -- Some clients use NONE for environment/dummy auras
      b.fromExternal = true
    end
  end

  -- changeType: GAINED / FADED / UPDATED / FULL_REFRESH (dummy re-applies use refresh)
  local isGain = (changeType == EFFECT_RESULT_GAINED)
  local isFade = (changeType == EFFECT_RESULT_FADED)
  local isUpd = (changeType == EFFECT_RESULT_UPDATED)
  local isRefresh = (type(EFFECT_RESULT_FULL_REFRESH) == "number" and changeType == EFFECT_RESULT_FULL_REFRESH)
  if isGain or isRefresh then
    b.applied = (b.applied or 0) + 1
    if not b.activeStartMs then b.activeStartMs = tMs end
    if isRefresh and b.activeStartMs then
      -- keep window open; count reapply
    end
    if isGain then
      pcall(potionNoteFromBuff, session, b.name, abilityId, tMs, true)
    end
  elseif isFade then
    if b.activeStartMs then
      b.activeMs = (b.activeMs or 0) + math.max(0, tMs - b.activeStartMs)
      b.activeStartMs = nil
    end
  elseif isUpd then
    if b.activeStartMs then
      b.activeMs = (b.activeMs or 0) + math.max(0, tMs - b.activeStartMs)
    end
    b.applied = (b.applied or 0) + 1
    b.activeStartMs = tMs
  end
end

-- ----------------------------
-- Slash commands
-- ----------------------------
local function slashHandler(text)
  text = safeLower(text or "")
  text = zo_strformat("<<1>>", text)

  if text == "" or text == "toggle" then
    -- Toggle: if menu showing hide; else ShowStats
    if type(R.HideMenu) == "function" and DM2StatsMenuShell and type(DM2StatsMenuShell.IsShowing) == "function"
        and DM2StatsMenuShell.IsShowing() then
      R:HideMenu()
      return
    end
    R:ShowStats({ autoPopup = false, interactive = true })
    return
  end

  if text == "show" then
    R:ShowStats({ autoPopup = false, interactive = true })
    return
  end

  if text == "hide" then
    R:Hide()
    return
  end

  if text == "clear" then
    clearHistory()
    R:Hide()
    d("|c88ff88DM2 Stats|r: history cleared")
    return
  end

  if text == "compact" or text == "fix" then
    local n = sanitizeHistoryInPlace()
    d("|c88ff88DM2 Stats|r: compacted " .. tostring(n) .. " stored fights (console memory).")
    return
  end

  if text == "share" then
    exportParseToChat(getHistoryAt(0))
    return
  end

  if text == "menu" or text == "shell" then
    if type(R.ShowMenu) == "function" then
      R:ShowMenu()
    else
      d("|cFFAA00DM2 Stats|r: gamepad menu shell not loaded.")
    end
    return
  end

  if text == "legacy" or text == "overlay" then
    d("|c88ff88DM2 Stats|r: legacy overlay removed. Use /dm2stats show")
    return
  end

  if text == "dump" or text == "dumpids" then
    local s = getHistoryAt(0)
    if not s then d("|c88ff88DM2 Stats|r: no fights in history") return end
    local dur = s.durationMs or 0
    local avg = (dur > 0) and (s.totalDamage / (dur/1000)) or 0
    d(string.format("|c88ff88DM2 Stats|r: unmapped abilityId dump (top damage, last fight)  Avg DPS: %s", fmtDps(avg)))
    local arr = {}
    for _,sk in pairs(s.skills or {}) do
      local setName = resolveSetName(s, sk.id, sk.name)
      if not setName then
        table.insert(arr, sk)
      end
    end
    table.sort(arr, function(a,b) return (a.dmg or 0) > (b.dmg or 0) end)
    local maxLines = 20
    for i=1, math.min(maxLines, #arr) do
      local sk = arr[i]
      local share = (s.totalDamage > 0) and ((sk.dmg or 0) / s.totalDamage) or 0
      if share < 0.005 then break end
      d(string.format("  %2d) %s  (id=%d)  %s  (%s)", i, sk.name or "?", tonumber(sk.id) or 0, fmtInt(sk.dmg or 0), fmtPct(share)))
    end
    d("|c88ff88DM2 Stats|r: add abilityId->setName entries to SET_PROC_BY_ABILITY_ID in the addon to group set procs.")
    return
  end

  -- allow /dm2stats 3 (opens menu; L2/R2 walks history)
  local n = tonumber(text)
  if n and n >= 0 then
    R:ShowStats({ autoPopup = false, interactive = true })
    return
  end

  d("|c88ff88DM2 Stats|r commands: /dm2stats [toggle|show|hide|clear|share|menu|dump]")
end

local function registerSlash()
  SLASH_COMMANDS["/dm2stats"] = function(arg)
    arg = zo_strlower((arg or ""):gsub("^%s+", ""):gsub("%s+$", ""))
    if arg == "debug" then
      SV.settings.debugRotation = not SV.settings.debugRotation
      d(string.format("DM2Stats: rotation debug log %s.", SV.settings.debugRotation and "enabled" or "disabled"))
      return
    end
    slashHandler(arg)
  end
  SLASH_COMMANDS["/dm2statsshow"] = function() R:ShowStats({ autoPopup = false, interactive = true }) end
  SLASH_COMMANDS["/dm2statshide"] = function() R:Hide() end
  SLASH_COMMANDS["/dm2statsclear"] = function() clearHistory(); R:Hide(); d("|c88ff88DM2 Stats|r: history cleared") end
  SLASH_COMMANDS["/dm2statsdebug"] = function()
    SV.settings.debugRotation = not SV.settings.debugRotation
    d(string.format("DM2Stats: rotation debug log %s.", SV.settings.debugRotation and "enabled" or "disabled"))
  end
end

-- ----------------------------
-- (Optional) LibAddonMenu settings
-- ----------------------------
local function initLAM()
  if not LibAddonMenu2 then return end

  local LAM = LibAddonMenu2
  local panelData = {
    type = "panel",
    name = R.displayName,
    displayName = R.displayName,
    author = "Fred + ChatGPT",
    version = R.version,
    registerForRefresh = true,
    registerForDefaults = true,
  }

  local panel = LAM:RegisterAddonPanel("DM2StatsLAMPanel", panelData)

  local options = {
    -- =============================================
    -- QUICK OPEN (menu is the only first-class UI)
    -- =============================================
    { type = "header", name = "Quick Open" },
    {
      type = "button",
      name = "Open Stats",
      tooltip = "Open the dual-pane stats menu. Gamepad mode. L2/R2 fight history. O/back to close. /dm2stats show",
      func = function()
        R:ShowStats({ autoPopup = false, interactive = true })
      end,
      width = "full",
    },
    {
      type = "checkbox",
      name = "Journal gamepad menu entry",
      tooltip = "When on, adds DM2 Stats under the gamepad Journal menu.",
      getFunc = function() return SV.settings.experimentalGamepadMenu ~= false end,
      setFunc = function(v) SV.settings.experimentalGamepadMenu = v and true or false end,
      default = true,
    },

    -- =============================================
    -- GENERAL
    -- =============================================
    { type = "header", name = "General" },
    {
      type = "checkbox",
      name = "Enable",
      getFunc = function() return SV.settings.enable end,
      setFunc = function(v) SV.settings.enable = v end,
      default = R.defaults.settings.enable,
    },
    {
      type = "checkbox",
      name = "Auto-popup after dummy parse",
      tooltip = "Opens the stats menu after a dummy parse ends.",
      getFunc = function() return SV.settings.autoPopupAfterParse end,
      setFunc = function(v) SV.settings.autoPopupAfterParse = v end,
      default = R.defaults.settings.autoPopupAfterParse,
    },
    {
      type = "slider",
      name = "Results popup delay (seconds)",
      tooltip = "Delays the post-fight stats menu after combat ends. Helpful for lingering animations, DoTs, and video capture.",
      min = 0, max = 5, step = 1,
      getFunc = function() return SV.settings.resultsPopupDelaySecs or 2 end,
      setFunc = function(v) SV.settings.resultsPopupDelaySecs = v end,
      default = R.defaults.settings.resultsPopupDelaySecs,
    },
    {
      type = "slider",
      name = "History size (max 20)",
      tooltip = "How many fights to keep (5–20). Newest is always #1. When full, the oldest fight rolls off. Compact sessions keep console memory safe at 20.",
      min = 5, max = 20, step = 1,
      getFunc = function() return clampHistoryMax(SV.settings.historyMax) end,
      setFunc = function(v) SV.settings.historyMax = clampHistoryMax(v) end,
      default = R.defaults.settings.historyMax,
    },
    {
      type = "button",
      name = "Clear history",
      tooltip = "Wipes all stored fights from SavedVariables. Use if the game keeps disabling addons.",
      func = function() clearHistory(); R:Hide(); d("|c88ff88DM2 Parse|r: history cleared.") end,
      width = "half",
    },
    {
      type = "button",
      name = "Compact history now",
      tooltip = "Strips bulk combat tables from stored fights (safe for coach/outcomes). Run if memory is tight.",
      func = function()
        local n = sanitizeHistoryInPlace()
        d("|c88ff88DM2 Parse|r: compacted " .. tostring(n) .. " stored fights.")
      end,
      width = "half",
    },
    {
      type = "checkbox",
      name = "Track open-world fights",
      tooltip = "When OFF, capture starts only on dummy names (e.g. Target Iron Atronach, Trial) or while in housing. First empty-name hits no longer block the pull. Turn ON for trials/dungeons/open world.",
      getFunc = function() return SV.settings.trackOpenWorld ~= false end,
      setFunc = function(v) SV.settings.trackOpenWorld = v and true or false end,
      default = R.defaults.settings.trackOpenWorld,
    },
    {
      type = "checkbox",
      name = "Dummy badge strict (name AND housing)",
      tooltip = "Only affects the Dummy badge / auto-popup labeling after the fight. Capture start uses name OR housing when open-world is OFF (not this strict gate).",
      getFunc = function() return SV.settings.dummyStrict end,
      setFunc = function(v) SV.settings.dummyStrict = v end,
      default = R.defaults.settings.dummyStrict,
    },

    -- =============================================
    -- WEAVE FLASH (Training)
    -- =============================================
    { type = "header", name = "Weave Flash (Training)" },
    {
      type = "checkbox",
      name = "Enable weave flash",
      tooltip = "Flashes Good/Late/Missed at screen center during combat after each weave. Great for learning the LA weave rhythm. Turn off once comfortable.",
      getFunc = function() return SV.settings.showWeaveFlash end,
      setFunc = function(v) SV.settings.showWeaveFlash = v end,
      default = R.defaults.settings.showWeaveFlash,
    },
    {
      type = "slider",
      name = "Flash text size",
      tooltip = "Font size for the weave flash text (default 36).",
      min = 20, max = 52, step = 2,
      getFunc = function() return SV.settings.weaveFlashSize or 36 end,
      setFunc = function(v) SV.settings.weaveFlashSize = v; updateWeaveFlashFont() end,
      default = R.defaults.settings.weaveFlashSize,
    },
    {
      type = "slider",
      name = "Flash duration (ms)",
      tooltip = "How long the flash text stays on screen (200-800ms, default 500).",
      min = 200, max = 800, step = 50,
      getFunc = function() return SV.settings.weaveFlashDuration or 500 end,
      setFunc = function(v) SV.settings.weaveFlashDuration = v end,
      default = R.defaults.settings.weaveFlashDuration,
    },
    {
      type = "checkbox",
      name = "Weave sound cue",
      tooltip = "Plays a subtle sound on each weave: chime for Good, alert for Late, error for Missed. Works independently of the visual flash.",
      getFunc = function() return SV.settings.weaveFlashSound end,
      setFunc = function(v) SV.settings.weaveFlashSound = v end,
      default = R.defaults.settings.weaveFlashSound,
    },

    { type = "header", name = "Raid strip (live)" },
    {
      type = "checkbox",
      name = "Raid strip in dungeons / trials",
      tooltip = "Left-side ON/MIN/OFF list (Force, Slayer, Berserk, Courage, Heroism, Breach, Crusher, Brittle, Vuln) plus Pen % of the usual 18.2k recipe. Independent of the dummy/housing toggle.",
      getFunc = function() return SV.settings.showRaidStrip ~= false end,
      setFunc = function(v) SV.settings.showRaidStrip = v and true or false end,
      default = true,
    },
    {
      type = "checkbox",
      name = "Raid strip on dummy / housing",
      tooltip = "Same left-side strip while in a house or dummy parse, so you can test it. Independent of the dungeon/trial toggle.",
      getFunc = function() return SV.settings.showRaidStripOnDummy ~= false end,
      setFunc = function(v) SV.settings.showRaidStripOnDummy = v and true or false end,
      default = true,
    },

  }

  LAM:RegisterOptionControls("DM2StatsLAMPanel", options)
end

-- ----------------------------
-- Init
-- ----------------------------
function R:Initialize()
  -- If SavedVariables/*.lua is corrupt, the *game* fails loading that file before we run.
  -- pcall here only catches ZO_SavedVars API errors, not a broken SV main chunk.
  local okSV, svOrErr = pcall(function()
    return ZO_SavedVars:NewAccountWide(self.ns, 1, nil, self.defaults)
  end)
  if okSV and svOrErr then
    SV = svOrErr
  else
    d("|cFF6666DM2 Parse|r: SavedVariables failed to open. Using temporary defaults this session.")
    d("|cAAAAAAErr:|r " .. tostring(svOrErr))
    -- Last resort empty table so the rest of the addon can load this session (not persisted)
    SV = {
      settings = {},
      ui = {},
      history = {},
      lastIndex = 0,
      lastAnnouncementVersion = "",
      experiments = { active = nil },
    }
  end
  ensureSV() -- also sets R.SV = SV for MenuShell / experiments / content profile

  -- Auto-compact every load: preserve fights, drop bulk tables that bloat SV / console memory.
  -- Do NOT wipe history. Cap size only at hard ceiling (20); default soft target 12 for new installs.
  do
    -- 3.17.9: raise old default 12 → 20 once (still hard-capped at 20)
    if not SV._historyMax20_3179 then
      SV._historyMax20_3179 = true
      local cur = tonumber(SV.settings.historyMax)
      if cur == nil or cur == 12 then
        SV.settings.historyMax = HISTORY_HARD_MAX
      end
    end
    SV.settings.historyMax = clampHistoryMax(SV.settings.historyMax)
    local compactN = 0
    pcall(function() compactN = sanitizeHistoryInPlace() or 0 end)
    if not SV._historyCompact_3174 then
      SV._historyCompact_3174 = true
      if compactN > 0 then
        zo_callLater(function()
          d("|c88ff88DM2 Parse|r: auto-compacted " .. tostring(compactN)
            .. " stored fight(s) — history kept, bulk data stripped for console memory.")
        end, 5000)
      end
    end
  end

  registerSlash()
  initLAM()

  -- MenuShell is the default stats viewer (v3.9.0). Always init when available so
  -- post-parse popup and /dm2stats show can open it. Journal entry still gated.
  -- Deferred: zone load is when console memory is tightest.
  zo_callLater(function()
    if DM2StatsMenuShell and type(DM2StatsMenuShell.Initialize) == "function" then
      pcall(function() DM2StatsMenuShell.Initialize() end)
    end
  end, 1500)

  EM:RegisterForEvent(self.name, EVENT_PLAYER_COMBAT_STATE, function(...) self:OnCombatState(...) end)

  -- Backup combat edge detection (housing dummy / missed combat-state events)
  if type(EM.RegisterForUpdate) == "function" then
    EM:UnregisterForUpdate(self.name .. "_CombatWatch")
    EM:RegisterForUpdate(self.name .. "_CombatWatch", 400, function()
      self:CombatWatchTick()
    end)
  end

  -- Combat events: COPY Simple DPS registration exactly.
  -- One subscription per source unit type (PLAYER, PLAYER_PET). Do NOT add
  -- REGISTER_FILTER_IS_ERROR — that combo was implicated in under-counts vs Simple.
  self._combatNeedsLuaSourceGate = true
  local function combatHandler(...) self:OnCombatEvent(...) end
  if type(EM.AddFilterForEvent) == "function" and type(REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE) ~= "nil"
      and type(COMBAT_UNIT_TYPE_PLAYER) == "number" then
    local sourceTypes = { COMBAT_UNIT_TYPE_PLAYER }
    if type(COMBAT_UNIT_TYPE_PLAYER_PET) == "number" then
      sourceTypes[#sourceTypes + 1] = COMBAT_UNIT_TYPE_PLAYER_PET
    end
    local okAll = true
    for i = 1, #sourceTypes do
      local regName = self.name .. "_Combat" .. i
      local ok = pcall(function()
        EM:RegisterForEvent(regName, EVENT_COMBAT_EVENT, combatHandler)
        EM:AddFilterForEvent(regName, EVENT_COMBAT_EVENT,
          REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, sourceTypes[i])
      end)
      if not ok then okAll = false end
    end
    -- Filters active → trust C-side; skip Lua sourceType re-check
    self._combatNeedsLuaSourceGate = not okAll
    if not okAll then
      EM:RegisterForEvent(self.name, EVENT_COMBAT_EVENT, combatHandler)
      self._combatNeedsLuaSourceGate = true
    end
  else
    EM:RegisterForEvent(self.name, EVENT_COMBAT_EVENT, combatHandler)
    self._combatNeedsLuaSourceGate = true
  end

  -- v3.0.25: Input-based rotation capture — fires the instant a skill button is pressed.
  if type(EVENT_ACTION_SLOT_ABILITY_USED) ~= "nil" then
    EM:RegisterForEvent(self.name .. "_SlotUsed", EVENT_ACTION_SLOT_ABILITY_USED,
      function(...) self:OnActionSlotAbilityUsed(...) end)
  end

  if type(EVENT_ACTIVE_WEAPON_PAIR_CHANGED) ~= "nil" then
    EM:RegisterForEvent(self.name .. "_BarSwap", EVENT_ACTIVE_WEAPON_PAIR_CHANGED,
      function(...) self:OnActiveWeaponPairChanged(...) end)
  end

  if type(GetActiveHotbarCategory) == "function" then
    local ok, cat = pcall(GetActiveHotbarCategory)
    if ok then self._activeBar = cat end
  end

  EM:RegisterForEvent(self.name, EVENT_EFFECT_CHANGED, function(...) self:OnEffectChanged(...) end)

  if type(R.StartRaidStrip) == "function" then pcall(R.StartRaidStrip) end

  -- Belt-and-braces: scrub history before SV serialization (logout / character select)
  if type(EVENT_PLAYER_DEACTIVATED) ~= "nil" then
    EM:RegisterForEvent(self.name .. "_Deact", EVENT_PLAYER_DEACTIVATED, function()
      pcall(function()
        if type(SV) == "table" and type(SV.history) == "table" then
          for _, s in pairs(SV.history) do
            if type(s) == "table" then s.coach = nil; s._coachTok = nil end
          end
        end
        sanitizeHistoryInPlace()
      end)
    end)
  end


  d(string.format("|c88ff88%s|r v%s loaded. /dm2stats show", self.displayName, self.version))

  -- Version announcement popup (delayed 3s so login UI settles)
  if SV.lastAnnouncementVersion ~= self._latestAnnouncementVersion then
    local ann = self._announcements[self._latestAnnouncementVersion]
    if ann then
      zo_callLater(function()
        showAnnouncementPopup(ann.title, ann.body)
      end, 3000)
    end
  end
end

local function OnAddOnLoaded(event, addonName)
  if addonName ~= R.name then return end
  EM:UnregisterForEvent(R.name, EVENT_ADD_ON_LOADED)
  R:Initialize()
end

EM:RegisterForEvent(R.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
