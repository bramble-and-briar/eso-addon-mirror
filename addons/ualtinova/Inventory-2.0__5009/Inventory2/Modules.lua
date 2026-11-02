InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- Optional groups turned on from the settings:
--   RECENT LOOT     : what dropped in your last dungeon / trial / arena (solo arenas too).
--   HOME CONTAINERS : what's in your house storage chests, saved while you're in the house.

local sv, csv

---------------------------------------------------------------------------
-- RECENT LOOT
---------------------------------------------------------------------------

-- What kind of place counts as a run, each one switchable in the settings.
-- Returns the setting key, a key identifying this particular run, and its display name
-- (or nil when here isn't a run: houses, and anything switched off).
-- Run names are written like titles: "Crypt Of Hearts I", not "crypt of hearts i".
local function TitleCase(text)
    return (text:gsub("(%S+)", function(word)
        return zo_strupper(zo_strsub(word, 1, 1)) .. zo_strsub(word, 2)
    end))
end

local function ZoneName(zoneId)
    return zo_strformat("<<C:1>>", GetZoneNameById(zoneId))
end

local function ParentZoneId()
    local zoneIndex = GetUnitZoneIndex("player")
    if ZO_ExplorationUtils_GetParentZoneIdByZoneIndex then
        return ZO_ExplorationUtils_GetParentZoneIdByZoneIndex(zoneIndex)
    end
    return GetParentZoneId(GetZoneId(zoneIndex))
end

local function CurrentRunPlace()
    if GetCurrentZoneHouseId() ~= 0 then return nil end
    local zoneId = GetZoneId(GetUnitZoneIndex("player"))
    if IsInstanceEndlessDungeon and IsInstanceEndlessDungeon() then
        return "lastRunEndless", "endless", "Endless Archive"
    elseif IsActiveWorldBattleground() or GetCurrentBattlegroundId() ~= 0 then
        return "lastRunBattlegrounds", "bg" .. zoneId, "Battleground: " .. TitleCase(ZoneName(zoneId))
    elseif IsInImperialCity() then
        return "lastRunImperialCity", "ic", "Imperial City"
    elseif IsInCyrodiil() then
        return "lastRunCyrodiil", "cyrodiil", "Cyrodiil"
    elseif GetCurrentZoneDungeonDifficulty() ~= DUNGEON_DIFFICULTY_NONE then
        -- Anything with a difficulty setting: dungeons, trials, group and solo arenas.
        return "lastRunInstances", "instance" .. zoneId, TitleCase(ZoneName(zoneId))
    end
    -- Out in a zone: delves, public dungeons and cities count toward their zone's run.
    --
    -- Named for where you were, not for what you did there. Every other bucket holds what one
    -- place gave you, but a zone gives you a quest reward, a writ's pay and a mail's contents as
    -- readily as it gives you an ore node, and a name ending in "Overland Run" claimed all of it
    -- had been looted out in the world. The zone's own name says where you were and nothing more,
    -- which is all this bucket knows.
    local parentZoneId = ParentZoneId()
    return "lastRunOverland", "zone" .. parentZoneId, TitleCase(ZoneName(parentZoneId))
end

-- What each kind of place looks like on the line that names it. Keyed by the setting that says
-- the place counts at all, which is what CurrentRunPlace hands back; every one of these is a
-- path the game ships with and the addon already draws elsewhere.
local RUN_ICONS = {
    lastRunOverland = "EsoUI/Art/LFG/LFG_indexIcon_zoneStories_up.dds",
    lastRunInstances = "EsoUI/Art/LFG/LFG_normalDungeon_up.dds",
    lastRunEndless = "EsoUI/Art/LFG/LFG_veteranDungeon_up.dds",
    lastRunBattlegrounds = "EsoUI/Art/LFG/LFG_indexIcon_battlegrounds_up.dds",
    lastRunImperialCity = "EsoUI/Art/LFG/LFG_indexIcon_imperialCity_up.dds",
    lastRunCyrodiil = "EsoUI/Art/LFG/LFG_indexIcon_allianceWar_up.dds",
}

-- A bucket saved before it started keeping its kind still says what it was in its key, which
-- CurrentRunPlace builds out of the place: "zone123", "instance456", "bg789", "ic", "cyrodiil".
local KIND_BY_PREFIX = {
    zone = "lastRunOverland", instance = "lastRunInstances", bg = "lastRunBattlegrounds",
    ic = "lastRunImperialCity", cyrodiil = "lastRunCyrodiil", endless = "lastRunEndless",
}

local function RunIcon(run)
    local kind = run.kind
    if not kind then
        for prefix, guess in pairs(KIND_BY_PREFIX) do
            if zo_strsub(run.key or "", 1, #prefix) == prefix then kind = guess break end
        end
    end
    return RUN_ICONS[kind or "lastRunOverland"]
end

-- Overland runs carry on when you come back to the same zone (e.g. after a trip home);
-- the other kinds start over every time you enter them.
local CONTINUES_ON_RETURN = { lastRunOverland = true }

-- Every run keeps its own loot in its own bucket, newest first, so leaving a dungeon for a zone
-- doesn't rename the dungeon's run or swallow what it dropped.
local MAX_RUNS = 5

local function Runs()
    return csv.lastRun.runs
end

local function CurrentRun()
    return csv.lastRun.runs[1]
end

-- The one kind of run you do not enter: it is the zone you are standing in, and you are standing
-- in one whenever you are not somewhere else. CurrentRunPlace builds its key out of the zone.
local OVERLAND_KEY = "zone"

local function IsOverlandRun(run)
    return run ~= nil and zo_strsub(run.key, 1, #OVERLAND_KEY) == OVERLAND_KEY
end

-- Where a reward that came in the post belongs. Something is finished before it is paid for, and
-- what you finish is a dungeon, a trial, an arena, a battleground or a campaign -- never the zone
-- you happen to be standing in when you open the letter. You are almost always standing in one by
-- then: the dungeon sends you home as it ends, and going home starts a run of its own, which is
-- how a random dungeon's reward ended up under an overland run.
--
-- So the letter goes to the newest run you actually entered. If there is none on the list -- with
-- "keep older runs" off there is only ever the one you are in -- it goes where it used to.
local function RewardRun()
    for _, run in ipairs(csv.lastRun.runs) do
        if not IsOverlandRun(run) then return run end
    end
    return CurrentRun()
end

-- Forget items that were sold, deconstructed or otherwise left the bag and the bank.
local function PruneLastRun()
    local present = {}
    for _, bagId in ipairs({ BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK, BAG_WORN }) do
        for slotIndex = 0, GetBagSize(bagId) - 1 do
            if HasItemInSlot(bagId, slotIndex) then
                present[Id64ToString(GetItemUniqueId(bagId, slotIndex))] = true
            end
        end
    end
    for _, run in ipairs(Runs()) do
        for id in pairs(run.ids) do
            if not present[id] then run.ids[id] = nil end
        end
    end
end

-- Entering a run starts a new one: a different place, or the same instance entered again.
local function OnPlayerActivated()
    local runs = Runs()
    local settingKey, runKey, runName = CurrentRunPlace()
    if settingKey and sv[settingKey] then
        local current = runs[1]
        local sameRun = current and current.key == runKey
            and (csv.lastRun.active or CONTINUES_ON_RETURN[settingKey])
        -- The same bucket, but the name it was written with may be an older one of ours.
        if sameRun then current.name, current.kind = runName, settingKey end
        if not sameRun then
            -- Coming back to a place that carries on (a zone) picks its bucket up again;
            -- anything else starts a fresh one at the front of the list.
            local bucket
            if CONTINUES_ON_RETURN[settingKey] then
                for index, run in ipairs(runs) do
                    if run.key == runKey then bucket = table.remove(runs, index) break end
                end
            end
            bucket = bucket or { key = runKey, ids = {} }
            bucket.name, bucket.kind = runName, settingKey
            table.insert(runs, 1, bucket)
            -- Without "keep older runs" only the one you are in survives.
            local keep = sv.lastRunAccumulate and MAX_RUNS or 1
            for index = #runs, keep + 1, -1 do runs[index] = nil end
        end
        csv.lastRun.active = true
    else
        csv.lastRun.active = false
    end
    PruneLastRun()
end

-- Rewards that come by system mail (e.g. Rewards of the Worthy after PvP) belong to the run
-- too: taking a system mail's attachments marks the next few seconds of new items as run loot.
local REWARD_MAIL_WINDOW_MS = 3000
local rewardMailUntil = 0

-- Attachments from another player are a gift or a trade, not loot: they are left out.
local playerMailUntil = 0

local function OnTakeMailAttachments(mailId)
    local _, _, _, _, _, fromSystem, fromCustomerService = GetMailItemInfo(mailId)
    if fromSystem and not fromCustomerService then
        if sv.lastRunEnabled and sv.lastRunRewardMail then
            rewardMailUntil = GetFrameTimeMilliseconds() + REWARD_MAIL_WINDOW_MS
        end
    else
        rewardMailUntil = 0
        playerMailUntil = GetFrameTimeMilliseconds() + REWARD_MAIL_WINDOW_MS
    end
end

-- Buying is not looting either: nothing that arrives while a merchant (buyback included) or a
-- guild store is open counts. Guild store purchases land straight in the bag.
local shopOpen = false

-- Quest rewards are not run loot. The reward items and EVENT_QUEST_COMPLETE arrive close together
-- but in no promised order, so items of the last moment are remembered and taken back out when a
-- quest completes, and whatever follows the completion for a short while is left out.
local QUEST_WINDOW_MS = 1500
local questUntil = 0
local recentAdds = {} -- { run, id, amount, time } of the last few run additions

local function OnQuestCompleted()
    local now = GetFrameTimeMilliseconds()
    questUntil = now + QUEST_WINDOW_MS
    for _, add in ipairs(recentAdds) do
        if now - add.time <= QUEST_WINDOW_MS then
            local tracked = add.run.ids[add.id]
            if type(tracked) == "number" and tracked > add.amount then
                add.run.ids[add.id] = tracked - add.amount
            else
                add.run.ids[add.id] = nil
            end
        end
    end
    ZO_ClearNumericallyIndexedTable(recentAdds)
end

-- Opening a box is not looting. A reward container opened in the middle of a run would otherwise
-- fill RECENT LOOT with things the run never dropped, so whatever arrives in the moment after one is
-- opened is left out. UseItem is a protected function and cannot be hooked, so the container is
-- spotted as it leaves instead: the backpack slots holding one are remembered, and a slot losing
-- its container is the player opening it. (Mail attachments are handled above and still count.)
local CONTAINER_WINDOW_MS = 1500
local containerUntil = 0
local containerSlots = {} -- [backpack slot index] = true while a container sits there

local function NoteContainerSlot(slotIndex)
    containerSlots[slotIndex] = IG.IsContainerItem(GetItemLink(BAG_BACKPACK, slotIndex)) or nil
end

local function ScanContainerSlots()
    ZO_ClearTable(containerSlots)
    for slotIndex = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if HasItemInSlot(BAG_BACKPACK, slotIndex) then NoteContainerSlot(slotIndex) end
    end
end

local function OnSlotUpdate(_, bagId, slotIndex, isNewItem, _, _, stackCountChange)
    local change = stackCountChange or 0
    if change < 0 and containerSlots[slotIndex] then
        containerUntil = GetFrameTimeMilliseconds() + CONTAINER_WINDOW_MS
    end
    if change ~= 0 then NoteContainerSlot(slotIndex) end

    if not sv.lastRunEnabled or not isNewItem or change <= 0 then return end
    local now = GetFrameTimeMilliseconds()
    if now < containerUntil or now < playerMailUntil or now < questUntil or shopOpen then return end
    local fromRewardMail = GetFrameTimeMilliseconds() < rewardMailUntil
    if not csv.lastRun.active and not fromRewardMail then return end

    local run = fromRewardMail and RewardRun() or CurrentRun()
    if not run then return end
    local id = Id64ToString(GetItemUniqueId(bagId, slotIndex))
    local stackSize = GetSlotStackSize(bagId, slotIndex)
    local tracked = run.ids[id]
    -- Loot that landed on a stack you already carried stays out of the group: the run only added
    -- a few, while the group would show the whole stack (117 soul gems after one dungeon).
    -- A stack this run itself started simply grows with whatever else the run adds to it.
    if not tracked and stackCountChange < stackSize then return end
    local before = type(tracked) == "number" and tracked or 0
    run.ids[id] = zo_min(stackSize, before + stackCountChange)
    -- Kept briefly so a quest completing right after can take it back out.
    for index = #recentAdds, 1, -1 do
        if now - recentAdds[index].time > QUEST_WINDOW_MS then table.remove(recentAdds, index) end
    end
    recentAdds[#recentAdds + 1] = { run = run, id = id, amount = run.ids[id] - before, time = now }
end

-- What a run brought of this slot, if any (NEW asks this, to leave run loot to RECENT LOOT).
local function TrackedInRun(slotData)
    if not sv.lastRunEnabled or not slotData.uniqueId then return nil end
    local id = Id64ToString(slotData.uniqueId)
    for _, run in ipairs(Runs()) do
        local tracked = run.ids[id]
        if tracked then return tracked, run end
    end
end

function IG.IsInLastRun(slotData)
    return TrackedInRun(slotData) ~= nil
end

-- Whether the player is inside something that counts as a run right now.
function IG.IsRunActive()
    if not sv or not sv.lastRunEnabled or not csv or not csv.lastRun then return false end
    return csv.lastRun.active == true
end

-- Is this slot in any run at all? The menu line is only offered when there is something to take
-- out, and a piece can be in more than one run: a stack the last two runs both added to.
local function RunsHolding(bagId, slotIndex)
    if not (sv and sv.lastRunEnabled and csv and csv.lastRun) then return nil end
    local uniqueId = GetItemUniqueId(bagId, slotIndex)
    if not uniqueId then return nil end
    local id = Id64ToString(uniqueId)
    local holding
    for _, run in ipairs(Runs()) do
        if run.ids[id] then
            holding = holding or {}
            holding[#holding + 1] = run
        end
    end
    return holding, id
end

function IG.IsSlotInLastRun(bagId, slotIndex)
    return RunsHolding(bagId, slotIndex) ~= nil
end

-- One piece out of RECENT LOOT without emptying the group. It was never anywhere else: the row
-- under the run is the same item as the row under its own category, so letting it go here only
-- stops the run claiming it.
-- Stops every run claiming this piece, and says whether any of them was. Quiet: the list is
-- not rebuilt and nothing is shown, so a caller with a hundred of these to do can do them all
-- and rebuild once.
function IG.TakeOutOfRuns(bagId, slotIndex)
    local holding, id = RunsHolding(bagId, slotIndex)
    if not holding then return false end
    for _, run in ipairs(holding) do run.ids[id] = nil end
    return true
end

function IG.DistributeOneFromLastRun(bagId, slotIndex)
    if not IG.TakeOutOfRuns(bagId, slotIndex) then return false end
    -- And the list goes where the piece went: the row it has now is opened down to and put on
    -- screen, so what the line did is watched rather than taken on trust. One piece only --
    -- with several there is no one place to go and nothing to watch.
    IG.RevealSlot(bagId, slotIndex)
    return true
end

-- Hands one place's pile back. The pieces are in their usual groups all along, so all this
-- does is stop the run claiming them -- which is the same thing Distribute does for the whole
-- group, asked of one pile instead. Which pieces were in the pile is asked of the classifier
-- again rather than remembered from the build: the heading gathers whatever stands in that
-- category now, so the answer that drew it is the answer that empties it.
function IG.DistributePileFromRun(runKey, groupKey)
    for _, run in ipairs(Runs()) do
        if run.key == runKey then
            for id in pairs(run.ids) do
                local bagId, slotIndex = IG.SlotForTrackedId and IG.SlotForTrackedId(id)
                local bag = bagId and SHARED_INVENTORY and SHARED_INVENTORY:GetOrCreateBagCache(bagId)
                local slotData = bag and slotIndex and bag[slotIndex]
                local path = slotData and IG.ClassifySlot(slotData)
                if path and path[1] and path[1].id == groupKey then run.ids[id] = nil end
            end
            break
        end
    end
    IG.RefreshLists()
end

-- Empties RECENT LOOT; the items were in their usual groups all along.
function IG.DistributeLastRun()
    -- The run you are standing in stays, emptied: without its bucket the loot that follows had
    -- nowhere to go, and nothing was recorded again until the next loading screen.
    local current = csv.lastRun.active and CurrentRun() or nil
    ZO_ClearNumericallyIndexedTable(csv.lastRun.runs)
    if current then
        current.ids = {}
        csv.lastRun.runs[1] = current
    end
    IG.RefreshLists()
end

-- The game's Junk tab hands us junked pieces and nothing else, so any group built from those
-- rows is a group of junk under another name. The modules that repeat real items ask this
-- before they build anything, and leave the tab to JUNK, whose own rows are skipped there for
-- being on the list already. Nothing is taken out of a run: unjunk the piece and it is back
-- under RECENT LOOT on the tabs that show it.
function IG.OnJunkTab(inventory)
    return ITEM_TYPE_DISPLAY_CATEGORY_JUNK ~= nil
        and inventory.currentFilter == ITEM_TYPE_DISPLAY_CATEGORY_JUNK
end

-- One run: its items sit straight under RECENT LOOT, with the run's name beside the group.
-- Several: each run gets its own sub-group, the one you did last on top.
function IG.CollectLastRunEntries(inventory, inventoryType, rawEntries)
    local result = {}
    if not sv.lastRunEnabled then return result end
    if IG.OnJunkTab(inventory) then return result end

    -- A run belongs on this list only if this list has something of it to show. What is stored
    -- says which runs happened, not which ones are still here: their loot may be in the bank, or
    -- worn, or sold since the last time the runs were pruned. Counting the stored runs instead is
    -- what made the group say "(3)" over a single run.
    -- Every pass below has to agree with the rows that are finally drawn, or the group counts
    -- places it does not draw and the Stolen heading opens over rows that are not there.
    local function Listed(data)
        -- And not what AUTOMATE keeps out of it (stolen, or sent aside by a rule).
        -- Garbage is left out as well (IG.HiddenFromRecentLoot).
        return not IG.IsSetAside(data) and not IG.HiddenFromRecentLoot(data)
    end

    local shown = {}
    for _, entry in ipairs(rawEntries) do
        if Listed(entry.data) then
            local _, run = TrackedInRun(entry.data)
            if run then shown[run] = true end
        end
    end

    local withLoot = {}
    for _, run in ipairs(Runs()) do
        if shown[run] then withLoot[#withLoot + 1] = run end
    end
    if #withLoot == 0 then return result end

    local root = IG.MakeGroupNode("LASTRUN")
    if #withLoot == 1 then
        root.subtitle = withLoot[1].name
    else
        -- The number beside the group counts the runs, not their loot: every run says how much it
        -- brought on its own header. The name itself does not change with the count -- it says
        -- what is in the group, not how many places it came from.
        root.fixedCount = #withLoot
        -- And says as much: a number on its own beside a group's name is read as the rows
        -- waiting under it, which this one is not.
        root.countLabel = "Instances"
    end
    -- Some loot is gathered rather than listed. A run through a city brings back two dozen
    -- plates and spoons; which spoon is which is not why the group is there, and the red says
    -- what they all have in common in one line instead of twenty-four. What the run brought that
    -- is worth nothing but the vendor's coin reads the same way under its own grey.
    --
    -- Below this many it is not a pile and gathering it says nothing: one stolen ring behind a
    -- heading called Stolen is a heading over a ring. Counted per place and per pile, since that
    -- is where the heading would stand.
    local PILE_MIN = 6
    -- The pile stands where the loose pieces of the same place stand. It is inside the place in
    -- the way everything under a place is inside it, and stepping it in again said it was inside
    -- something else as well.
    local PILE_FLUSH = true
    -- And is read as one of them. The pile is a row of the place it was taken from, not a
    -- heading over it: it starts where the names beside it start, in the lettering the game
    -- writes those names in, with only the +/- in front to say it opens.
    local PILE_AS_ROW = true
    -- Each pile wears the mark of the category it gathers, in that category's own colour, in the
    -- column the item icons stand in: the line says in one look what all the rows under it are.
    -- Stolen keeps the mark the game puts on every stolen thing; the rest take the icon their
    -- category is drawn with everywhere else.
    -- Each pile also names the switch that allows it. Somebody who wants to see every stolen
    -- piece by name turns that one off and the pile is never built: it is left out of the table
    -- the classifier is asked against below, so the pieces fall through as the loose rows they
    -- would be under the threshold. Nothing is hidden by any of this -- a switch decides how the
    -- run's loot is read, not what of it is listed.
    local PILES = {
        { key = "STOLEN", label = "Stolen", order = 1, setting = "lastRunPileStolen",
            icon = "EsoUI/Art/Inventory/inventory_stolenItem_icon.dds" },
    }
    local pileByKey = {}
    for _, pile in ipairs(PILES) do
        local group = IG.GROUP_BY_KEY[pile.key]
        pile.icon = pile.icon or (group and group.icon)
        if sv[pile.setting] ~= false then pileByKey[pile.key] = pile end
    end

    -- Which pile a piece belongs in is the list's own answer about it, asked of the classifier
    -- rather than worked out here: the classifier hands back one category and the stolen mark
    -- outranks what a thing is.
    local function PileFor(data)
        if not (data.bagId and data.slotIndex) then return nil end
        local path = IG.ClassifySlot(data)
        local top = path and path[1]
        return top and pileByKey[top.id] or nil
    end

    local pileOf, pileCount, pileNodes = {}, {}, {}
    for _, entry in ipairs(rawEntries) do
        local data = entry.data
        local pile = Listed(data) and PileFor(data)
        if pile then
            local _, run = TrackedInRun(data)
            if run then
                pileOf[entry] = pile
                pileCount[run] = pileCount[run] or {}
                pileCount[run][pile] = (pileCount[run][pile] or 0) + 1
            end
        end
    end

    -- A run is a place, not a category: there is nothing to decide about it and nothing to look
    -- up in it, so it is read rather than opened. The line carries the name of where the loot
    -- came from and nothing else -- a count would be the number of things from one afternoon in
    -- one zone, which answers no question anyone has.
    local asRules = sv.lastRunRules ~= false

    local nodes = {}
    for index, run in ipairs(withLoot) do
        nodes[run] = #withLoot > 1 and {
            id = "run" .. run.key,
            label = run.name,
            color = IG.DimColor(IG.GetGroupColor("LASTRUN"), 0.92),
            icon = RunIcon(run),
            order = index, -- newest run first, whatever its name
            isRule = asRules or nil,
            bareRule = asRules or nil,
        } or nil
    end

    for _, entry in ipairs(rawEntries) do
        local data = entry.data
        local tracked, run = TrackedInRun(data)
        local pile = pileOf[entry]
        if tracked and Listed(data) then
            -- The row shows what the run brought, not what the stack holds now: anything you
            -- carried before the run, or added afterwards, is not part of it.
            local count = type(tracked) == "number" and zo_min(tracked, data.stackCount or tracked) or nil
            local node = nodes[run]
            local path = node and { root, node } or { root }
            if pile and (pileCount[run][pile] or 0) >= PILE_MIN then
                pileNodes[run] = pileNodes[run] or {}
                local gathered = pileNodes[run][pile]
                if not gathered then
                    gathered = IG.MakeSubNode(node or root, pile.label)
                    gathered.flush = PILE_FLUSH
                    gathered.itemLine = PILE_AS_ROW
                    gathered.icon = pile.icon
                    gathered.iconColor = IG.GetGroupColor(pile.key)
                    gathered.order = pile.order
                    -- A pile you can hand back, and a heading that says so on hover.
                    gathered.menu = "pileRun"
                    gathered.menuRun = run.key
                    gathered.menuPile = pile.key
                    pileNodes[run][pile] = gathered
                end
                path[#path + 1] = gathered
            end
            result[#result + 1] = {
                data = setmetatable({ igLastRun = true, stackCount = count }, { __index = data }),
                path = path,
            }
        end
    end
    return result
end

---------------------------------------------------------------------------
-- HOME CONTAINERS
---------------------------------------------------------------------------

local HOUSE_BAGS = {}
for _, name in ipairs({ "BAG_HOUSE_BANK_ONE", "BAG_HOUSE_BANK_TWO", "BAG_HOUSE_BANK_THREE", "BAG_HOUSE_BANK_FOUR",
    "BAG_HOUSE_BANK_FIVE", "BAG_HOUSE_BANK_SIX", "BAG_HOUSE_BANK_SEVEN", "BAG_HOUSE_BANK_EIGHT",
    "BAG_HOUSE_BANK_NINE", "BAG_HOUSE_BANK_TEN" }) do
    if _G[name] then HOUSE_BAGS[#HOUSE_BAGS + 1] = _G[name] end
end

local GetChestCollectible = GetCollectibleForBag or GetCollectibleForHouseBankBag

local function ChestName(bagId)
    local collectibleId = GetChestCollectible and GetChestCollectible(bagId) or 0
    if collectibleId == 0 then return nil end
    local nickname = GetCollectibleNickname(collectibleId)
    local name = nickname ~= "" and nickname or GetCollectibleName(collectibleId)
    return zo_strformat("<<1>>", name)
end

-- Saves one chest's contents. Only runs while the chest's contents are actually loaded
-- (in the house), so a chest never gets wiped by an empty read from somewhere else.
local function SaveChest(bagId)
    if not IsOwnerOfCurrentHouse() then return end
    local name = ChestName(bagId)
    if not name then return end
    local items = {}
    for slotIndex = 0, GetBagSize(bagId) - 1 do
        if HasItemInSlot(bagId, slotIndex) then
            local _, stackCount = GetItemInfo(bagId, slotIndex)
            items[#items + 1] = { link = GetItemLink(bagId, slotIndex), count = stackCount, slot = slotIndex }
        end
    end
    sv.home.chests[bagId] = { name = name, items = items }
    sv.home.savedAt = GetTimeStamp()
end

local function SaveAllChests()
    if not IsOwnerOfCurrentHouse() then return end
    for _, bagId in ipairs(HOUSE_BAGS) do
        if GetNumBagUsedSlots(bagId) > 0 or sv.home.chests[bagId] == nil then
            SaveChest(bagId)
        end
    end
end

local function OnHouseBagChanged(_, bagId)
    if IsHouseBankBag(bagId) then SaveChest(bagId) end
end

-- Read-only rows: the items aren't here, so they're shown from what was saved.
function IG.CollectHomeEntries(inventory, inventoryType, searchText, rowType)
    local result = {}
    if not sv.homeEnabled or not next(sv.home.chests) then return result end
    -- Stored items can't be matched against the tab filters, so they only show on "All".
    if inventory.currentFilter ~= ITEM_TYPE_DISPLAY_CATEGORY_ALL then return result end

    local root = IG.MakeGroupNode("HOME")
    if sv.home.savedAt then
        root.badge = "saved " .. zo_strlower(ZO_FormatDurationAgo(GetTimeStamp() - sv.home.savedAt))
        root.badgeOnlyWhenExpanded = true
    end
    for bagId, chest in pairs(sv.home.chests) do
        local chestNode = { id = "chest" .. bagId, label = chest.name, color = IG.Tone(IG.CHEST_COLOR),
            icon = "EsoUI/Art/Collections/collections_tabIcon_housing_up.dds" }
        for _, item in ipairs(chest.items) do
            local name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(item.link))
            if searchText == "" or zo_strlower(name):find(searchText, 1, true) then
                result[#result + 1] = {
                    typeId = rowType,
                    -- bagId/slotIndex: where it sits in the house. Other addons read these from the row;
                    -- without them the game treats the row as the first worn slot.
                    data = { link = item.link, count = item.count, name = name, igStored = true,
                        bagId = bagId, slotIndex = item.slot or -1 },
                    path = { root, chestNode },
                }
            end
        end
    end
    return result
end

---------------------------------------------------------------------------

function IG.InitModules(accountSettings, characterSettings)
    sv, csv = accountSettings, characterSettings
    csv.lastRun = csv.lastRun or { runs = {} }
    if csv.lastRun.ids then
        -- Saved before runs were kept apart: the old pile becomes the newest run.
        csv.lastRun.runs = { { key = csv.lastRun.key or "run", name = csv.lastRun.name or "Last Run",
            ids = csv.lastRun.ids } }
        csv.lastRun.ids, csv.lastRun.key, csv.lastRun.name = nil, nil, nil
    end
    csv.lastRun.runs = csv.lastRun.runs or {}
    sv.home = sv.home or { chests = {} }

    -- Everything above only tidies the saved data. What follows watches the game, so the Global
    -- Switch stops it: switched off, the addon listens to nothing.
    if not IG.IsEnabled() then return end

    ZO_PreHook("TakeMailAttachments", OnTakeMailAttachments)

    -- RECENT LOOT and HOME CONTAINERS each watch EVENT_INVENTORY_SINGLE_SLOT_UPDATE, which fires
    -- on every bag change all session long -- registered only while their own module is on
    -- (IG.MODULE_APPLY, called from IG.SetModuleEnabled and once at load here), not left
    -- listening forever behind the sv.lastRunEnabled/homeEnabled checks the callbacks already make.
    local lastRunRegistered, homeRegistered = false, false

    local function ApplyLastRun(on)
        if on == lastRunRegistered then return end
        lastRunRegistered = on
        if on then
            EVENT_MANAGER:RegisterForEvent("InventoryGroupingLastRun", EVENT_PLAYER_ACTIVATED, function()
                OnPlayerActivated()
                ScanContainerSlots()
                SaveAllChests()
            end)
            EVENT_MANAGER:RegisterForEvent("InventoryGroupingLastRun", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnSlotUpdate)
            EVENT_MANAGER:AddFilterForEvent("InventoryGroupingLastRun", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
                REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
            local function SetShopOpen(open) return function() shopOpen = open end end
            EVENT_MANAGER:RegisterForEvent("InventoryGroupingLastRunStore", EVENT_OPEN_STORE, SetShopOpen(true))
            EVENT_MANAGER:RegisterForEvent("InventoryGroupingLastRunStore", EVENT_CLOSE_STORE, SetShopOpen(false))
            EVENT_MANAGER:RegisterForEvent("InventoryGroupingLastRunGuildStore", EVENT_OPEN_TRADING_HOUSE, SetShopOpen(true))
            EVENT_MANAGER:RegisterForEvent("InventoryGroupingLastRunGuildStore", EVENT_CLOSE_TRADING_HOUSE, SetShopOpen(false))
            EVENT_MANAGER:RegisterForEvent("InventoryGroupingLastRunQuest", EVENT_QUEST_COMPLETE, OnQuestCompleted)
        else
            EVENT_MANAGER:UnregisterForEvent("InventoryGroupingLastRun", EVENT_PLAYER_ACTIVATED)
            EVENT_MANAGER:UnregisterForEvent("InventoryGroupingLastRun", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
            EVENT_MANAGER:UnregisterForEvent("InventoryGroupingLastRunStore", EVENT_OPEN_STORE)
            EVENT_MANAGER:UnregisterForEvent("InventoryGroupingLastRunStore", EVENT_CLOSE_STORE)
            EVENT_MANAGER:UnregisterForEvent("InventoryGroupingLastRunGuildStore", EVENT_OPEN_TRADING_HOUSE)
            EVENT_MANAGER:UnregisterForEvent("InventoryGroupingLastRunGuildStore", EVENT_CLOSE_TRADING_HOUSE)
            EVENT_MANAGER:UnregisterForEvent("InventoryGroupingLastRunQuest", EVENT_QUEST_COMPLETE)
        end
    end

    local function ApplyHome(on)
        if on == homeRegistered then return end
        homeRegistered = on
        if on then
            EVENT_MANAGER:RegisterForEvent("InventoryGroupingHome", EVENT_OPEN_BANK, function(_, bagId) OnHouseBagChanged(nil, bagId) end)
            EVENT_MANAGER:RegisterForEvent("InventoryGroupingHome", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnHouseBagChanged)
        else
            EVENT_MANAGER:UnregisterForEvent("InventoryGroupingHome", EVENT_OPEN_BANK)
            EVENT_MANAGER:UnregisterForEvent("InventoryGroupingHome", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
        end
    end

    IG.MODULE_APPLY = IG.MODULE_APPLY or {}
    IG.MODULE_APPLY.lastRunEnabled = ApplyLastRun
    IG.MODULE_APPLY.homeEnabled = ApplyHome
end
