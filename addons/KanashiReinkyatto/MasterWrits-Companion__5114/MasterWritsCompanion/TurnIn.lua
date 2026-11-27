local L = MWC.L
-- Turning writs in: starting one master writ quest per craft (the game allows one each) for writs whose items
-- are ready in the bag, and, with Autodelivery on, handing them in while the player talks to the Mastercraft
-- Mediator, then starting the next batch when the conversation ends. Talking and walking stay manual.
MWC.TurnIn = {}

local EVENT_NS = MWC.name .. "TurnIn"
-- Starting quests waits only for the writ item's own cooldown, checked every POLL_MS.
local POLL_MS = 20
local OFFER_TIMEOUT_MS = 1500
-- An accepted quest counts only once it is in the journal (EVENT_QUEST_ADDED, seen 50-110 ms after accepting);
-- without that in time the writ is used again (the acceptance was lost: seen on the second quest of a batch),
-- then the craft is given up for this batch. A quest that still arrives late, while its retry waits, counts.
local CONFIRM_TIMEOUT_MS, MAX_RETRIES = 600, 2
local NEXT_QUEST_DELAY_MS = 100
local COOLDOWN_WAIT_LIMIT_MS = 5000
-- As Dolgubon's Lazy Writ Crafter does it: the option is picked and the quest completed in the same moment the
-- game shows them, the conversation is closed once no writ quest is left to hand in, and nothing heavy runs
-- during it (the list and the bag marks are rebuilt once when it ends).
local FREE_SLOT_RESERVE = 2
-- Hand-ins are only picked at the mediators: their names in the language file (MWC.L.MEDIATORS), plus any NPC
-- a writ was once handed in to (so a client language without those names works after one manual hand-in). The
-- option is told by its type, not the localized text.
local function IsMediator(npc)
  if npc == "" then return false end
  for _, name in ipairs(MWC.L.MEDIATORS or {}) do
    if name == npc then return true end
  end
  return MWC.sv.mediators ~= nil and MWC.sv.mediators[npc] == true
end
local TURN_IN_OPTION_TYPES = {}
for _, name in ipairs({ "CHATTER_START_COMPLETE_QUEST", "CHATTER_START_ADVANCE_COMPLETABLE_QUEST_CONDITIONS",
    "CHATTER_COMPLETE_QUEST" }) do
  if _G[name] then
    TURN_IN_OPTION_TYPES[_G[name]] = true
  end
end

-- Starting quests: only exists while it runs.
local run = nil
-- The current conversation with a mediator: how many writs were handed in during it.
local conversation = nil

local function CanUseItems()
  return not IsUnitInCombat("player") and not IsLooting() and GetInteractionType() == INTERACTION_NONE
end

-- Other addons that also hand in at the mediator: two of them choosing options in one conversation trip each
-- other up (seen: only 2 of 3 quests handed in). Dolgubon's Lazy Writ Crafter does it with its auto accept on.
function MWC.TurnIn.ConflictingAddons()
  local found = {}
  local ok, settings = pcall(function() return WritCreater and WritCreater.GetSettings and WritCreater:GetSettings() end)
  if ok and settings and settings.autoAccept then
    table.insert(found, L.DOLGUBON_CONFLICT)
  end
  return found
end

-- Dolgubon's settings, opened from a chat link at its Timesavers submenu, where "Automatic complete" is. The
-- panel builds its controls the first time it is shown, so the submenu is opened once it exists (as a click on
-- its title would). Without LibAddonMenu or the panel, the way there is printed instead.
local SETTINGS_LINK_TYPE = "mwcsettings"

function MWC.TurnIn.OpenDolgubonSettings()
  local LAM, panel = LibAddonMenu2, _G["DolgubonsWritCrafter"]
  if not (LAM and LAM.OpenToPanel and panel) then
    MWC.Print(L.TURN_OFF, L.DOLGUBON_PATH)
    return
  end
  LAM:OpenToPanel(panel)
  local waited = 0
  EVENT_MANAGER:RegisterForUpdate(EVENT_NS .. "Dolgubon", 100, function()
    waited = waited + 100
    local submenu = _G["WritCreaterTimesaverSubmenu"]
    if submenu and not panel:IsHidden() then
      EVENT_MANAGER:UnregisterForUpdate(EVENT_NS .. "Dolgubon")
      if not submenu.open and submenu.label then
        pcall(function() submenu.label:GetHandler("OnMouseUp")(submenu.label) end)
      end
    elseif waited >= 5000 then
      EVENT_MANAGER:UnregisterForUpdate(EVENT_NS .. "Dolgubon")
    end
  end)
end

local function DolgubonLink()
  return MWC.Colorize(MWC.COLOR.BLUE, string.format("|H0:%s:dolgubon|h%s|h", SETTINGS_LINK_TYPE, L.OPEN_ITS_SETTINGS))
end

LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_MOUSE_UP_EVENT, function(_, button, _, _, linkType)
  if linkType ~= SETTINGS_LINK_TYPE then return end
  if button == MOUSE_BUTTON_INDEX_LEFT then
    MWC.TurnIn.OpenDolgubonSettings()
  end
  return true
end)

-- Another addon handing in too: said in chat with the way to its setting.
local function WarnAboutConflicts()
  local conflicts = MWC.TurnIn.ConflictingAddons()
  if #conflicts == 0 then return false end
  MWC.Print("%s", MWC.Colorize(MWC.COLOR.RED, string.format(L.CONFLICT_CHAT, table.concat(conflicts, ", "))) .. " " .. DolgubonLink())
  return true
end

-- Autodelivery is never saved: it starts off after every login or reload and is switched on by hand when
-- turning in begins, so it can't take writs from the bank while the player is still gathering materials.
local autodelivery = false

function MWC.TurnIn.IsAutoHandIn()
  return autodelivery
end

-- Holiday writs with Autodelivery (and the Event checkbox): the game allows one holiday writ quest at a time, so
-- one is started from a ready holiday writ in the bag, handed in at a writ crate (see OnEventChatter), and the
-- next one is started as soon as it is gone.
local EVENT_START_WAIT_MS = 15000
local eventStart = nil

local function ActiveEventQuest()
  for questIndex = 1, MAX_JOURNAL_QUESTS do
    if IsValidQuestIndex(questIndex) and MWC.Journal.IsEventQuest(questIndex) then return true end
  end
  return false
end

-- Holiday writs are started in runs, so one writ crate takes them one after another: by holiday (Witches Festival,
-- New Life, Deep Winter, Imperial), and within it by craft (each craft has its own crate). The last started
-- holiday and craft go on while there are any, then the same holiday's next craft, then the next holiday, in
-- order (holiday, craft, name).
local lastEvent, lastEventCraft = nil, nil

local function ReadyEventWrit()
  if not MWC.sv.showEvent then return nil end
  local candidates = {}
  for _, group in ipairs(MWC.Plan.Build().groups) do
    if group.event and group.queued > 0 and not group.problem and (group.readyBag or 0) > 0 then
      for _, writ in ipairs(group.writs) do
        if not writ.state and writ.bag == BAG_BACKPACK and not MWC.Session.IsExcluded(writ.uid) then
          table.insert(candidates, { writ = writ, group = group })
          break
        end
      end
    end
  end
  table.sort(candidates, function(a, b)
    if a.group.event ~= b.group.event then return a.group.event < b.group.event end
    if a.group.typeOrder ~= b.group.typeOrder then return (a.group.typeOrder or 0) < (b.group.typeOrder or 0) end
    return (a.group.name or "") < (b.group.name or "")
  end)
  local pick, sameEvent
  for _, candidate in ipairs(candidates) do
    if candidate.group.event == lastEvent then
      if candidate.group.type == lastEventCraft then
        pick = candidate
        break
      end
      sameEvent = sameEvent or candidate
    end
  end
  pick = pick or sameEvent or candidates[1]
  if pick then return pick.writ, pick.group end
end

-- The Turn in panel shows the holiday quest's state; redrawn after the current refresh, never inside it.
local function ShowEventState()
  zo_callLater(function() MWC.UI.Refresh("view") end, 0)
end

local function StopEventStart(why)
  EVENT_MANAGER:UnregisterForUpdate(EVENT_NS .. "Event")
  EVENT_MANAGER:UnregisterForEvent(EVENT_NS .. "Event", EVENT_QUEST_OFFERED)
  if eventStart and why then
    MWC.Log("Event: quest start stopped, %s", why)
  end
  if eventStart then
    ShowEventState()
  end
  eventStart = nil
end

-- Master writs go first: a holiday quest is started only once no master writ is left to deliver, neither a
-- quest in the journal nor a queued writ in the bag or bank, crafted or not (a holiday quest takes its craft's
-- quest slot, so a master writ of that craft couldn't be started). Writs that can't be crafted (a problem, or
-- they spend kept materials) don't hold holiday quests back.
local HandableQuests, GroupCounts
local function MasterWorkLeft()
  if MWC.Journal.OpenCount() > 0 or HandableQuests() > 0 then return true end
  local _, journalQuests = MWC.Journal.ActiveCrafts()
  if journalQuests > 0 then return true end
  for _, group in ipairs(MWC.Plan.Build().groups) do
    if not group.event then
      local bag, bank, notReady = GroupCounts(group)
      if bag + bank > 0 or (notReady > 0 and not group.kept) then return true end
    end
  end
  return false
end

local function StartEventQuest()
  if not autodelivery or eventStart or run or ActiveEventQuest() then return end
  if MasterWorkLeft() then return end
  local writ, group = ReadyEventWrit()
  if not writ then return end
  eventStart = { slot = writ.slot, uid = writ.uid, name = group.name, event = group.event, craft = group.type,
    since = GetGameTimeMilliseconds() }
  ShowEventState()
  EVENT_MANAGER:RegisterForEvent(EVENT_NS .. "Event", EVENT_QUEST_OFFERED, function()
    if not (eventStart and eventStart.usedAt) then return end
    MWC.Log("Event: quest of %s accepted", eventStart.name)
    lastEvent, lastEventCraft = eventStart.event, eventStart.craft
    StopEventStart()
    AcceptOfferedQuest()
  end)
  EVENT_MANAGER:RegisterForUpdate(EVENT_NS .. "Event", POLL_MS, function()
    if not eventStart then
      EVENT_MANAGER:UnregisterForUpdate(EVENT_NS .. "Event")
      return
    end
    local now = GetGameTimeMilliseconds()
    if eventStart.usedAt then
      if now - eventStart.usedAt > OFFER_TIMEOUT_MS then StopEventStart("no quest was offered") end
      return
    end
    if now - eventStart.since > EVENT_START_WAIT_MS then
      StopEventStart("items couldn't be used in time")
      return
    end
    -- Waits for the crate's conversation to close and for the item cooldown; the slot must still hold that writ.
    if run or not CanUseItems() or (GetItemCooldownInfo(BAG_BACKPACK, eventStart.slot) or 0) > 0 then return end
    if Id64ToString(GetItemUniqueId(BAG_BACKPACK, eventStart.slot)) ~= eventStart.uid then
      StopEventStart("the writ moved")
      return
    end
    eventStart.usedAt = now
    MWC.Log("Event: starting the quest of %s", eventStart.name)
    if IsProtectedFunction("UseItem") then
      CallSecureProtected("UseItem", BAG_BACKPACK, eventStart.slot)
    else
      UseItem(BAG_BACKPACK, eventStart.slot)
    end
  end)
end

-- Crafts with an active master writ quest, the number of active crafting quests, and how many of those
-- belong to no known craft (see Journal.ActiveCrafts).
function MWC.TurnIn.ActiveCrafts()
  return MWC.Journal.ActiveCrafts()
end

function MWC.TurnIn.ActiveCraftingQuests()
  local _, count = MWC.TurnIn.ActiveCrafts()
  return count
end

-- While quests are being started: the craft tried now, how many are started and planned.
function MWC.TurnIn.Progress()
  return run and { craft = run.current, started = run.started, planned = run.planned } or nil
end

-- One group's queued bag writs: ready to start here (writ and items in the bag), ready but with something in
-- the bank, and not crafted yet. Crafted items go to the group's active quests first (they are handed in
-- with them), and those items are assumed to be in the bag.
-- Holiday writs are counted the same way but apart (see Counts): their quests start one at a time and are handed
-- in at the writ turn-in sites, not at the mediator.
GroupCounts = function(group)
  if group.queued == 0 or group.problem then return 0, 0, 0 end
  local queuedInBag = 0
  for _, writ in ipairs(group.writs) do
    if not writ.state and writ.bag == BAG_BACKPACK and not MWC.Session.IsExcluded(writ.uid) then
      queuedInBag = queuedInBag + 1
    end
  end
  local ready = math.max(0, math.min(group.queued, (group.ready or 0) - group.activeCount))
  local bagItems = math.max(0, (group.readyBag or 0) - group.activeCount)
  local bag = math.min(ready, bagItems, queuedInBag)
  return bag, ready - bag, group.queued - ready
end

-- Per craft and in total (master writs), and holiday writs on their own (Event checkbox on): see GroupCounts.
-- Writs marked skip are not counted.
function MWC.TurnIn.Counts(groups)
  local byCraft, totals = {}, { bag = 0, bank = 0, notReady = 0 }
  local event = { bag = 0, bank = 0, notReady = 0 }
  for _, group in ipairs(groups) do
    local bag, bank, notReady = GroupCounts(group)
    if group.event then
      if MWC.sv.showEvent then
        event.bag, event.bank, event.notReady = event.bag + bag, event.bank + bank, event.notReady + notReady
      end
    elseif bag + bank + notReady > 0 then
      local counts = byCraft[group.type] or { bag = 0, bank = 0, notReady = 0 }
      byCraft[group.type] = counts
      counts.bag, counts.bank, counts.notReady = counts.bag + bag, counts.bank + bank, counts.notReady + notReady
    end
  end
  for _, counts in pairs(byCraft) do
    totals.bag, totals.bank = totals.bag + counts.bag, totals.bank + counts.bank
    totals.notReady = totals.notReady + counts.notReady
  end
  return byCraft, totals, event
end

local function Finish(fmt, ...)
  if not run then return end
  run = nil
  EVENT_MANAGER:UnregisterForUpdate(EVENT_NS)
  EVENT_MANAGER:UnregisterForUpdate(EVENT_NS .. "Confirm")
  EVENT_MANAGER:UnregisterForEvent(EVENT_NS, EVENT_QUEST_OFFERED)
  local message = string.format(fmt, ...)
  -- Ending the activity refreshes the list and the bag marks once.
  MWC.Activity.End(message)
  MWC.Activity.Notify(message)
  -- With the master writ quests started, a holiday one follows (one at a time).
  zo_callLater(StartEventQuest, 200)
end

-- One queued writ in the bag per craft whose items are ready in the bag too and that has no active quest:
-- worked out once when starting (the plan isn't rebuilt between two quests).
local function Candidates()
  local candidates, taken = {}, {}
  local active = MWC.TurnIn.ActiveCrafts()
  for _, group in ipairs(MWC.Plan.Build().groups) do
    -- Holiday writs never: their groups share the craft types, and their quests start one at a time after the
    -- master writs (StartEventQuest).
    if not group.event and not taken[group.type] and not active[group.type] and (GroupCounts(group)) > 0 then
      for _, writ in ipairs(group.writs) do
        if not writ.state and writ.bag == BAG_BACKPACK and not MWC.Session.IsExcluded(writ.uid) then
          taken[group.type] = true
          table.insert(candidates, { group = group, writ = writ })
          break
        end
      end
    end
  end
  return candidates
end

-- The next candidate for a craft not tried in this batch.
local function NextCandidate()
  for _, candidate in ipairs(run.candidates) do
    if not run.tried[candidate.group.type] then
      return candidate.group, candidate.writ
    end
  end
end

-- Uses the writ once its cooldown allows; an offer arrives as EVENT_QUEST_OFFERED. No offer in time means the
-- craft already has an active master writ quest, so it is skipped for this batch.
local function AcceptNext()
  if not run then return end
  local group, writ = NextCandidate()
  if not group then
    local failed = {}
    for craft in pairs(run.failed) do
      table.insert(failed, L.CRAFT[craft] or craft)
    end
    local skipped = #failed > 0 and string.format(L.QUESTS_SKIPPED,
      table.concat(failed, ", ")) or ""
    MWC.Activity.Succeed(#failed > 0)
    if run.started > 0 then
      Finish(L.QUESTS_STARTED, run.started, skipped)
    else
      Finish(L.NO_NEW_QUESTS, skipped)
    end
    return
  end
  if GetNumBagFreeSlots(BAG_BACKPACK) < FREE_SLOT_RESERVE then
    Finish(L.KEEP_SLOTS_FREE, FREE_SLOT_RESERVE)
    return
  end
  if GetNumJournalQuests() >= MAX_JOURNAL_QUESTS then
    Finish(L.JOURNAL_FULL, MAX_JOURNAL_QUESTS)
    return
  end
  run.tried[group.type] = true
  run.pending = true
  run.current = group.type
  run.currentGroup, run.currentWrit = group, writ
  MWC.Activity.Progress(run.started, string.format(L.STARTING_QUESTS_PROGRESS,
    run.started + 1, run.planned, group.name))

  local slot, waitStarted, usedAt = writ.slot, GetGameTimeMilliseconds(), nil
  EVENT_MANAGER:RegisterForUpdate(EVENT_NS, POLL_MS, function()
    if not run or not run.pending then
      EVENT_MANAGER:UnregisterForUpdate(EVENT_NS)
      return
    end
    local now = GetGameTimeMilliseconds()
    if usedAt then
      if now - usedAt > OFFER_TIMEOUT_MS then
        EVENT_MANAGER:UnregisterForUpdate(EVENT_NS)
        run.pending = false
        AcceptNext()
      end
      return
    end
    -- Waits for the item cooldown and for the last quest offer to close (items can't be used during it).
    if not CanUseItems() then
      if now - waitStarted > COOLDOWN_WAIT_LIMIT_MS then
        Finish("%s", L.CANT_START_QUESTS)
      end
      return
    end
    if (GetItemCooldownInfo(BAG_BACKPACK, slot) or 0) > 0 then
      if now - waitStarted > COOLDOWN_WAIT_LIMIT_MS then
        Finish("%s", L.COOLDOWN_STOPPED)
      end
      return
    end
    usedAt = now
    if IsProtectedFunction("UseItem") then
      CallSecureProtected("UseItem", BAG_BACKPACK, slot)
    else
      UseItem(BAG_BACKPACK, slot)
    end
  end)
end

local function NextOrFinish()
  if run.started >= run.planned then
    MWC.Activity.Succeed()
    Finish(L.QUESTS_STARTED, run.started, "")
  else
    AcceptNext()
  end
end

-- The offer is accepted at once, as Dolgubon's Lazy Writ Crafter does it, but the quest counts only when the
-- journal has it.
local function OnQuestOffered()
  if not run or not run.pending then return end
  EVENT_MANAGER:UnregisterForUpdate(EVENT_NS)
  run.pending = false
  MWC.Journal.RecordAccepted(run.currentWrit, run.currentGroup)
  local craft = run.current
  run.awaiting = { craft = craft, since = GetGameTimeMilliseconds() }
  AcceptOfferedQuest()
  EVENT_MANAGER:RegisterForUpdate(EVENT_NS .. "Confirm", POLL_MS, function()
    if not run or not run.awaiting then
      EVENT_MANAGER:UnregisterForUpdate(EVENT_NS .. "Confirm")
      return
    end
    if GetGameTimeMilliseconds() - run.awaiting.since < CONFIRM_TIMEOUT_MS then return end
    EVENT_MANAGER:UnregisterForUpdate(EVENT_NS .. "Confirm")
    run.awaiting = nil
    run.retries[craft] = (run.retries[craft] or 0) + 1
    if run.retries[craft] <= MAX_RETRIES then
      MWC.Log("Turn-in: %s quest not in the journal after accepting, using the writ again", craft)
      run.tried[craft] = nil
    else
      MWC.Log("Turn-in: %s quest still not in the journal, skipped for this batch", craft)
      run.failed[craft] = true
    end
    AcceptNext()
  end)
end

-- The journal got the accepted quest: now it counts, and the next writ is used.
local function ConfirmQuest(questIndex)
  if not run then return end
  local info = MWC.Journal.MasterWritInfo(questIndex)
  if not info then return end
  if run.awaiting and info.craft == run.awaiting.craft then
  elseif not run.awaiting and run.pending and run.current == info.craft and run.retries[info.craft] then
    -- The first acceptance went through after all: its retry is called off.
    EVENT_MANAGER:UnregisterForUpdate(EVENT_NS)
    run.pending = false
    MWC.Log("Turn-in: %s quest confirmed late, retry called off", info.craft)
  else
    return
  end
  EVENT_MANAGER:UnregisterForUpdate(EVENT_NS .. "Confirm")
  run.tried[info.craft] = true
  run.awaiting = nil
  run.started = run.started + 1
  MWC.Activity.Progress(run.started)
  -- The offer window is closed only now, once the quest is in: closing it right after accepting (as before)
  -- could cancel the acceptance.
  if GetInteractionType() ~= INTERACTION_NONE then
    ResetChatter()
  end
  -- The next writ is used a moment after the offer window closed: used at once, its acceptance was sometimes
  -- lost (a 0.6 s wait and a retry).
  zo_callLater(function()
    if run then NextOrFinish() end
  end, NEXT_QUEST_DELAY_MS)
end

-- Crafts that have a ready writ in the bag and no active quest: what one batch can start.
function MWC.TurnIn.StartableCrafts(groups)
  local byCraft = MWC.TurnIn.Counts(groups)
  local active = MWC.TurnIn.ActiveCrafts()
  local startable = 0
  for craft, counts in pairs(byCraft) do
    if counts.bag > 0 and not active[craft] then
      startable = startable + 1
    end
  end
  return startable
end

function MWC.TurnIn.StartQuests()
  if run or eventStart then return end
  local planned = MWC.TurnIn.StartableCrafts(MWC.Plan.Build().groups)
  if planned == 0 then
    MWC.Print("%s", L.NOTHING_TO_START)
    return
  end
  -- Like crafting, nothing heavy runs between two quests: the list is rebuilt once at the end.
  if not MWC.Activity.Begin(L.ACTIVITY_STARTING_QUESTS, planned, function() Finish("%s", L.STOPPED) end, true) then return end
  run = { tried = {}, retries = {}, failed = {}, started = 0, planned = planned, candidates = Candidates() }
  EVENT_MANAGER:RegisterForEvent(EVENT_NS, EVENT_QUEST_OFFERED, OnQuestOffered)
  AcceptNext()
end

-- With Auto on, starts quests as soon as nothing blocks using items (a closing conversation or bank takes
-- a moment), if any craft can start one.
local AUTO_START_POLL_MS, AUTO_START_WAIT_MS = 50, 6000
function MWC.TurnIn.AutoStart()
  if not MWC.TurnIn.IsAutoHandIn() then return end
  local waited = 0
  EVENT_MANAGER:RegisterForUpdate(EVENT_NS .. "AutoStart", AUTO_START_POLL_MS, function()
    waited = waited + AUTO_START_POLL_MS
    if CanUseItems() and not MWC.Activity.Current() then
      EVENT_MANAGER:UnregisterForUpdate(EVENT_NS .. "AutoStart")
      if MWC.TurnIn.StartableCrafts(MWC.Plan.Build().groups) > 0 then
        MWC.TurnIn.StartQuests()
      else
        MWC.UI.Refresh("view")
        StartEventQuest()
      end
    elseif waited > AUTO_START_WAIT_MS then
      EVENT_MANAGER:UnregisterForUpdate(EVENT_NS .. "AutoStart")
    end
  end)
end

-- Autodelivery ------------------------------------------------------------------

-- Master writ quests in the journal that can be handed in now: every condition of their step done (the
-- crafted item is in the bag). Quests are only started for ready writs, so normally all of them.
local function StepDone(questIndex)
  local step = QUEST_MAIN_STEP_INDEX or 1
  for condition = 1, GetJournalQuestNumConditions(questIndex, step) do
    local _, current, max, isFail, isComplete, _, isVisible = GetJournalQuestConditionInfo(questIndex, step, condition)
    if isVisible ~= false and not isFail and not isComplete and (current or 0) < (max or 1) then
      return false
    end
  end
  return true
end

HandableQuests = function()
  local count = 0
  for questIndex = 1, MAX_JOURNAL_QUESTS do
    if IsValidQuestIndex(questIndex) and MWC.Journal.MasterWritInfo(questIndex) and StepDone(questIndex) then
      count = count + 1
    end
  end
  return count
end

-- Holiday writ quests are handed in at the writ turn-in sites (the daily writs' crates), the way Dolgubon's Lazy
-- Writ Crafter hands in daily writs: the option that places the goods or completes a quest is picked, then the
-- completion window is confirmed, here only for a holiday writ quest. Options are told by type, so any client
-- language works. Only with the Event checkbox on, and never at a mediator (master writs are handed in there).
local eventChat = nil

-- A holiday quest is ready for the crate when its crafting conditions (those with writ data) are met; its
-- "Deliver the Item" condition is only met at the crate itself. On the last step (sign) nothing is left.
local function EventStepDone(questIndex)
  local step = QUEST_MAIN_STEP_INDEX or 1
  for condition = 1, GetJournalQuestNumConditions(questIndex, step) do
    local _, current, max, isFail, isComplete = GetJournalQuestConditionInfo(questIndex, step, condition)
    if GetQuestConditionMasterWritInfo(questIndex, step, condition) ~= nil and not isFail and not isComplete
        and (current or 0) < (max or 1) then
      return false
    end
  end
  return true
end

local function DoneEventQuests()
  local count = 0
  for questIndex = 1, MAX_JOURNAL_QUESTS do
    if IsValidQuestIndex(questIndex) and MWC.Journal.IsEventQuest(questIndex) and EventStepDone(questIndex) then
      count = count + 1
    end
  end
  return count
end

-- Where the holiday writs stand (Event checkbox on), for the Turn in panel: "starting" (its quest is being
-- started), "deliver" (a quest ready for a writ crate), "craft" (a quest whose item isn't made yet) or "ready" (a
-- ready holiday writ in the bag, no quest yet), with a name; nil when there is nothing.
function MWC.TurnIn.EventState()
  if not MWC.sv.showEvent then return nil end
  if eventStart then return "starting", eventStart.name end
  for questIndex = 1, MAX_JOURNAL_QUESTS do
    if IsValidQuestIndex(questIndex) and MWC.Journal.IsEventQuest(questIndex) then
      return EventStepDone(questIndex) and "deliver" or "craft", GetJournalQuestName(questIndex)
    end
  end
  local writ, group = ReadyEventWrit()
  if writ then return "ready", group.name end
end

-- True when this conversation is a holiday hand-in (handled here, not by the master writ hand-in).
local function OnEventChatter()
  if not MWC.sv.showEvent or conversation then return false end
  local npc = zo_strformat("<<1>>", GetUnitName("interact"))
  if IsMediator(npc) then return false end
  local done = DoneEventQuests()
  if done == 0 and not eventChat then return false end
  eventChat = eventChat or { picks = 0 }
  -- A quest takes up to two picks (place the goods, then sign); more means these options aren't for it.
  if eventChat.picks >= done * 2 + 2 then return true end
  local frame = GetFrameTimeMilliseconds()
  if eventChat.choseAt == frame then return true end
  for i = 1, GetChatterOptionCount() do
    local text, optionType = GetChatterOption(i)
    if TURN_IN_OPTION_TYPES[optionType] then
      eventChat.choseAt, eventChat.picks = frame, eventChat.picks + 1
      MWC.Log("Event: at %s picked %s [%s], %d holiday quests done", npc, tostring(text), tostring(optionType), done)
      SelectChatterOption(i)
      return true
    end
  end
  return true
end

-- After a hand-in the NPC rebuilds its options, and the next writ's option can show up a moment later. So the
-- conversation is closed only when no quest is left to hand in; while one is, the options are looked at again
-- every RECHECK_MS, for at most RECHECK_LIMIT_MS (a quest the game won't take doesn't hold it open forever).
local RECHECK_MS, RECHECK_LIMIT_MS = 50, 3000
local ChooseOption

-- A recheck is dropped when an option was picked in the meantime (by the game's own update event), so the
-- same option is never picked twice.
local function Recheck()
  if not conversation or conversation.pending then return end
  local current = conversation
  current.pending = true
  local picks = current.picks or 0
  zo_callLater(function()
    if conversation ~= current then return end
    current.pending = false
    if (current.picks or 0) == picks then
      ChooseOption()
    end
  end, RECHECK_MS)
end

ChooseOption = function()
  if not conversation then return end
  local choice
  local seen = {}
  for i = 1, GetChatterOptionCount() do
    local text, optionType = GetChatterOption(i)
    if MWC.DEV then
      table.insert(seen, string.format("%s [%s]", tostring(text), tostring(optionType)))
    end
    if not choice and TURN_IN_OPTION_TYPES[optionType] then
      choice = i
    end
  end
  if not choice then
    MWC.Log("Turn-in: no hand-in option among %s", #seen > 0 and table.concat(seen, "; ") or "none")
  end
  if choice then
    conversation.waitedSince = nil
    -- The game may report one update by two events in the same frame: pick only once per frame.
    local frame = GetFrameTimeMilliseconds()
    if conversation.choseAt == frame then return end
    conversation.choseAt = frame
    conversation.picks = (conversation.picks or 0) + 1
    SelectChatterOption(choice)
  elseif conversation.handedIn > 0 then
    local left = HandableQuests()
    local now = GetGameTimeMilliseconds()
    conversation.waitedSince = conversation.waitedSince or now
    if left > 0 and now - conversation.waitedSince < RECHECK_LIMIT_MS then
      Recheck()
      return
    end
    MWC.Log("Turn-in: %d handed in, %d still handable, closing the conversation after %d ms", conversation.handedIn,
      left, now - conversation.waitedSince)
    EndInteraction(INTERACTION_CONVERSATION)
  elseif not conversation.hinted and MWC.TurnIn.ActiveCraftingQuests() > 0 and not run then
    conversation.hinted = true
    MWC.Print("%s", L.NO_HANDIN_OPTION)
  end
end

local warnedAboutConflict = false

-- An NPC with a hand-in option while master writs are ready, not known as a mediator (a client language whose
-- mediator names aren't in the language file): said once per login how the addon learns it.
local hintedUnknownMediator = false

local function HintUnknownMediator()
  if hintedUnknownMediator or HandableQuests() == 0 then return end
  for i = 1, GetChatterOptionCount() do
    local _, optionType = GetChatterOption(i)
    if TURN_IN_OPTION_TYPES[optionType] then
      hintedUnknownMediator = true
      MWC.Print("%s", MWC.L.UNKNOWN_MEDIATOR)
      return
    end
  end
end

local function OnChatter()
  if OnEventChatter() then return end
  if not MWC.TurnIn.IsAutoHandIn() then return end
  if not conversation then
    local npc = zo_strformat("<<1>>", GetUnitName("interact"))
    if not IsMediator(npc) then
      HintUnknownMediator()
      return
    end
    conversation = { handedIn = 0 }
    if not warnedAboutConflict then
      warnedAboutConflict = WarnAboutConflicts()
    end
  end
  ChooseOption()
end

function MWC.TurnIn.InConversation()
  return conversation ~= nil
end

-- The "Complete Quest" window of a writ quest is confirmed. Only crafting quests, and only in a conversation
-- with a mediator (where only master writs are handed in). The master writ data alone can't tell: once the goods
-- are handed over the quest is on its last step, which carries no writ data, so that check let the window stay.
local function OnQuestCompleteDialog(_, questIndex)
  if eventChat and MWC.Journal.IsEventQuest(questIndex) then
    MWC.Log("Event: complete dialog for %s", GetJournalQuestName(questIndex))
    CompleteQuest()
    return
  end
  if not conversation then return end
  local isWrit = MWC.Journal.MasterWritInfo(questIndex) ~= nil or GetJournalQuestType(questIndex) == QUEST_TYPE_CRAFTING
  if not isWrit then
    MWC.Log("Turn-in: complete dialog for %s left to the player (not a writ)", tostring(GetJournalQuestName(questIndex)))
  end
  if isWrit then
    CompleteQuest()
  end
end

-- Every removed quest goes to the journal (handed in or abandoned, also outside a conversation).
local function OnQuestRemoved(_, isCompleted, questIndex, questName)
  -- A holiday quest handed in: the next holiday writ's quest is started (one at a time).
  if isCompleted and MWC.Journal.IsEventQuestName(questName) then
    zo_callLater(StartEventQuest, 300)
  end
  local wasWrit = MWC.Journal.OnQuestRemoved(isCompleted, questIndex, questName)
  -- A writ handed in during a conversation names the mediator, in whatever language: remembered for next time.
  local npc = zo_strformat("<<1>>", GetUnitName("interact") or "")
  if isCompleted and wasWrit and npc ~= "" and GetInteractionType() == INTERACTION_CONVERSATION then
    MWC.sv.mediators = MWC.sv.mediators or {}
    MWC.sv.mediators[npc] = true
  end
  if conversation then
    if isCompleted then
      conversation.handedIn = conversation.handedIn + 1
    end
    return
  end
  -- Any other quest of normal play costs nothing here.
  -- The writ's state is in its craft's signature, the rewards' slots are marked by the bags: no fresh plan.
  if wasWrit then
    MWC.Marks.Refresh()
    MWC.UI.Refresh(true)
  end
end

local function OnQuestAdded(_, questIndex, questName)
  -- A holiday quest the addon accepted: its offer window is closed once the quest is in (as for master writs).
  if autodelivery and not eventChat and MWC.Journal.IsEventQuest(questIndex)
      and GetInteractionType() ~= INTERACTION_NONE then
    ResetChatter()
  end
  MWC.Journal.OnQuestAdded(questIndex, questName)
  ConfirmQuest(questIndex)
  if not conversation and not MWC.Activity.IsCrafting() then
    MWC.UI.Refresh(true)
  end
end

-- After handing in (and after leaving the bank, see Init), the next batch starts by itself when Auto is on.
local function OnChatterEnd()
  eventChat = nil
  if not conversation then return end
  local handedIn = conversation.handedIn
  conversation = nil
  -- What the conversation changed is shown now, in one go.
  MWC.Marks.Refresh()
  MWC.UI.Refresh(true)
  if handedIn == 0 then return end
  MWC.TurnIn.AutoStart()
end

-- Switching Autodelivery on acts at once: at the bank it takes the ready writs (their quests start when it is
-- closed), elsewhere it starts the quests for what is ready in the bag.
function MWC.TurnIn.SetAutoHandIn(enabled)
  autodelivery = enabled and true or false
  if autodelivery then
    WarnAboutConflicts()
  else
    StopEventStart()
  end
  if autodelivery and MWC.Bank.IsPlayerBankOpen() then
    MWC.Bank.WithdrawReady(true)
  elseif autodelivery then
    MWC.TurnIn.AutoStart()
    StartEventQuest()
  end
  MWC.UI.Refresh("view")
end

-- Autodelivery switches itself off when turning in clearly isn't what is going on: a crafting station opened
-- (crafting, and maybe a bank trip for materials next), a zone change (away from the mediator and the bank),
-- or nothing left to deliver.
local function SwitchOff()
  if autodelivery then
    autodelivery = false
    StopEventStart()
    MWC.UI.Refresh("view")
  end
end

-- Holiday work left for Autodelivery (with the Event checkbox): a quest being started, one in the journal, or a
-- ready holiday writ in the bag.
local function EventWorkLeft()
  return MWC.sv.showEvent and (eventStart ~= nil or ActiveEventQuest() or ReadyEventWrit() ~= nil)
end

function MWC.TurnIn.CheckFinished(totals, event)
  if autodelivery and totals.bag + totals.bank == 0 and MWC.Journal.OpenCount() == 0 and not run
      and not EventWorkLeft() and (not event or event.bank == 0) then
    SwitchOff()
  end
end

function MWC.TurnIn.Init()
  EVENT_MANAGER:RegisterForEvent(EVENT_NS .. "Off", EVENT_CRAFTING_STATION_INTERACT, SwitchOff)
  -- Fires after the first login too, when it is off anyway.
  EVENT_MANAGER:RegisterForEvent(EVENT_NS .. "Off", EVENT_PLAYER_ACTIVATED, SwitchOff)
  EVENT_MANAGER:RegisterForEvent(EVENT_NS .. "Chat", EVENT_CHATTER_BEGIN, OnChatter)
  EVENT_MANAGER:RegisterForEvent(EVENT_NS .. "Chat", EVENT_CONVERSATION_UPDATED, OnChatter)
  EVENT_MANAGER:RegisterForEvent(EVENT_NS .. "Chat", EVENT_CHATTER_END, OnChatterEnd)
  EVENT_MANAGER:RegisterForEvent(EVENT_NS .. "Chat", EVENT_QUEST_COMPLETE_DIALOG, OnQuestCompleteDialog)
  EVENT_MANAGER:RegisterForEvent(EVENT_NS .. "Chat", EVENT_QUEST_REMOVED, OnQuestRemoved)
  EVENT_MANAGER:RegisterForEvent(EVENT_NS .. "Chat", EVENT_QUEST_ADDED, OnQuestAdded)
  EVENT_MANAGER:RegisterForEvent(EVENT_NS .. "Chat", EVENT_CLOSE_BANK, MWC.TurnIn.AutoStart)
  -- Autodelivery: opening the bank takes the ready writs at once (what Withdraw ready does), so the loop is
  -- just talking to the mediator and, when the bag runs out, to the banker.
  EVENT_MANAGER:RegisterForEvent(EVENT_NS .. "Chat", EVENT_OPEN_BANK, function()
    if MWC.TurnIn.IsAutoHandIn() then
      -- The bank module learns about the open bank from the same event; let it go first.
      zo_callLater(function() MWC.Bank.WithdrawReady(true) end, 400)
    end
  end)
end
