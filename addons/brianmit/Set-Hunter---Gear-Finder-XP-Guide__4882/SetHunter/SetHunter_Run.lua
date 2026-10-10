-- SetHunter_Run.lua : dungeon runs. While you're in a dungeon it notes every set
-- piece you loot (and whether it was new to your Set Collection); when the dungeon
-- is completed (or you leave with loot) a small "Run complete" window shows the time,
-- the pieces, how many were new, your runs today and your collection progress, with
-- Queue again / See loot / Close.

local S = SetHunter
local L = S.L

local run            -- the run in progress
local finishedZone   -- dungeon just completed: don't start a new run until you leave it
local sw = {}        -- summary window controls
local MAX_LOOT_LINES = 10

-- Which collection slots of a set were unlocked, as { [slotKey] = true }.
local function UnlockedSlots(setId)
    local slots = {}
    for i = 1, GetNumItemSetCollectionPieces(setId) do
        local _, slot = GetItemSetCollectionPieceInfo(setId, i)
        if IsItemSetCollectionSlotUnlocked(setId, slot) then slots[Id64ToString(slot)] = true end
    end
    return slots
end

local function CurrentDungeon()
    local loc = S.GetHereLocation()
    if loc and not loc.unknown and loc.kind == "dungeon" then return loc end
    return nil
end

local function IsVeteran()
    return GetCurrentZoneDungeonDifficulty ~= nil and DUNGEON_DIFFICULTY_VETERAN ~= nil
        and GetCurrentZoneDungeonDifficulty() == DUNGEON_DIFFICULTY_VETERAN
end

local function StartRun(loc)
    run = {
        zoneId = loc.id,
        name = loc.name,
        veteran = IsVeteran(),
        start = GetFrameTimeSeconds(),
        loot = {},
        known = {},
    }
    -- What the collection had before the run, for this dungeon's sets.
    for _, data in ipairs(S.GetSetsForLocation(loc.id, true)) do
        run.known[data.setId] = UnlockedSlots(data.setId)
    end
end

local function OnLootReceived(_, _, link, quantity, _, _, isSelf)
    if not run or not isSelf then return end
    local hasSet, _, _, _, _, setId = GetItemLinkSetInfo(link, false)
    if not hasSet or not setId or setId == 0 then return end
    local key = S.SlotKey(link)
    local known = run.known[setId]
    local isNew = false
    if key and known and GetNumItemSetCollectionPieces(setId) > 0 then
        isNew = not known[key]
        known[key] = true
    end
    run.loot[#run.loot + 1] = { link = link, count = quantity or 1, new = isNew, setId = setId }
end

local function RunsToday(zoneId, add)
    local day = GetDate()
    local runs = S.sv.runs
    if runs.day ~= day then
        runs.day, runs.count = day, {}
    end
    if add then runs.count[zoneId] = (runs.count[zoneId] or 0) + 1 end
    return runs.count[zoneId] or 0
end

local function FormatTime(seconds)
    seconds = zo_floor(seconds)
    return string.format("%d:%02d", zo_floor(seconds / 60), seconds % 60)
end

-- ---------------------------------------------------------------------------
-- Summary window
-- ---------------------------------------------------------------------------
local SW_W, SW_BASE_H = 430, 320

local function MakeStat(parent, name, x)
    local K = S.UIKit
    local value = K.MakeLabel(name .. "Value", parent, "ZoFontWinH1", 120, 40, K.COLOR.selected)
    value:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    value:SetAnchor(TOP, parent, TOP, x, 0)
    local label = K.MakeLabel(name .. "Label", parent, "ZoFontGameSmall", 130, 20, K.COLOR.dim)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetAnchor(TOP, value, BOTTOM, 0, -4)
    return value, label
end

local function CloseSummary()
    if sw.win then sw.win:SetHidden(true) end
end

local function LayoutSummary()
    local lines = sw.showLoot and sw.lootLines or 0
    sw.loot:SetHidden(not sw.showLoot)
    sw.win:SetHeight(SW_BASE_H + (sw.showLoot and (lines * 22 + 16) or 0))
    sw.seeLoot:SetText(sw.showLoot and L("RUN_HIDE_LOOT") or L("RUN_SEE_LOOT"))
end

local function CreateSummary()
    local K = S.UIKit
    local C = K.COLOR
    local win = WINDOW_MANAGER:CreateTopLevelWindow("SetHunter_RunSummary")
    win:SetWidth(SW_W)
    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, -80)
    win:SetDrawTier(DT_HIGH)
    win:SetClampedToScreen(true)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    win:SetHidden(true)
    K.MakeFadePanel(win, "SetHunter_RS")
    sw.win = win

    -- the x clicks like closing the main window (the Close button has the game's own click)
    local close = K.MakeTextButton("SetHunter_RSX", win, "x", "$(BOLD_FONT)|20|soft-shadow-thin", 24, L("CLOSE"), function()
        PlaySound(SOUNDS.DEFAULT_CLICK)
        CloseSummary()
    end)
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -18, 10)

    sw.title = K.MakeLabel("SetHunter_RSTitle", win, "ZoFontWinH2", SW_W - 60, 36, C.selected)
    sw.title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    sw.title:SetAnchor(TOP, win, TOP, 0, 16)
    sw.sub = K.MakeLabel("SetHunter_RSSub", win, "ZoFontGame", SW_W - 60, 22, C.dim)
    sw.sub:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    sw.sub:SetAnchor(TOP, sw.title, BOTTOM, 0, 0)

    local divider = K.MakeDivider("SetHunter_RSDivider", win, SW_W - 60)
    divider:SetAnchor(TOP, sw.sub, BOTTOM, 0, 8)

    local stats = WINDOW_MANAGER:CreateControl("SetHunter_RSStats", win, CT_CONTROL)
    stats:SetDimensions(SW_W - 60, 64)
    stats:SetAnchor(TOP, divider, BOTTOM, 0, 8)
    sw.pieces, sw.piecesLabel = MakeStat(stats, "SetHunter_RSPieces", -125)
    sw.new, sw.newLabel = MakeStat(stats, "SetHunter_RSNew", 0)
    sw.runs, sw.runsLabel = MakeStat(stats, "SetHunter_RSRuns", 125)
    sw.piecesLabel:SetText(L("RUN_PIECES"))
    sw.newLabel:SetText(L("RUN_NEW"))
    sw.runsLabel:SetText(L("RUN_TODAY"))

    -- Collection lines (your wishlist sets here, else the dungeon's progress)
    sw.collection = WINDOW_MANAGER:CreateControl("SetHunter_RSCollection", win, CT_LABEL)
    sw.collection:SetFont("ZoFontGame")
    sw.collection:SetWidth(SW_W - 60)
    sw.collection:SetAnchor(TOPLEFT, stats, BOTTOMLEFT, 0, 8)
    K.SetHexColor(sw.collection, C.normal)

    -- Loot list (See loot)
    sw.loot = WINDOW_MANAGER:CreateControl("SetHunter_RSLoot", win, CT_LABEL)
    sw.loot:SetFont("ZoFontGameSmall")
    sw.loot:SetWidth(SW_W - 60)
    sw.loot:SetAnchor(TOPLEFT, sw.collection, BOTTOMLEFT, 0, 10)
    sw.loot:SetHidden(true)

    -- Buttons
    sw.closeBtn = K.MakeButton("SetHunter_RSClose", win, L("CLOSE"), 100, CloseSummary)
    sw.closeBtn:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -30, -18)
    sw.seeLoot = K.MakeButton("SetHunter_RSLootBtn", win, L("RUN_SEE_LOOT"), 110, function()
        sw.showLoot = not sw.showLoot
        LayoutSummary()
    end)
    sw.seeLoot:SetAnchor(RIGHT, sw.closeBtn, LEFT, -10, 0)
    sw.again = K.MakeButton("SetHunter_RSAgain", win, L("RUN_AGAIN"), 150, function()
        CloseSummary()
        if sw.zoneId then S.OpenQueueDialog(sw.zoneId, nil, sw.veteran) end
    end)
    sw.again:SetAnchor(RIGHT, sw.seeLoot, LEFT, -10, 0)
end

local function ShowSummary(finished, completed)
    if not S.sv.runSummary then return end
    if not sw.win then CreateSummary() end
    local K = S.UIKit
    local C = K.COLOR

    sw.zoneId, sw.veteran = finished.zoneId, finished.veteran
    sw.title:SetText(zo_strupper(completed and L("RUN_COMPLETE") or L("RUN_ENDED")))
    sw.sub:SetText(string.format("%s  ·  %s  ·  %s", finished.name,
        finished.veteran and L("VETERAN") or L("NORMAL"), FormatTime(GetFrameTimeSeconds() - finished.start)))

    local newCount = 0
    for _, item in ipairs(finished.loot) do
        if item.new then newCount = newCount + 1 end
    end
    sw.pieces:SetText(tostring(#finished.loot))
    sw.new:SetText(tostring(newCount))
    K.SetHexColor(sw.new, newCount > 0 and C.good or C.selected)
    sw.runs:SetText(tostring(RunsToday(finished.zoneId)))

    -- Collection progress: wishlist sets that drop here first (with what this run added).
    local gained = {}
    for _, item in ipairs(finished.loot) do
        if item.new then gained[item.setId] = (gained[item.setId] or 0) + 1 end
    end
    local lines, done, total = {}, 0, 0
    for _, data in ipairs(S.GetSetsForLocation(finished.zoneId, true)) do
        if data.total > 0 then
            total = total + 1
            if data.complete then done = done + 1 end
            if data.wish and #lines < 3 then
                local line = zo_iconFormat("EsoUI/Art/Collections/Favorite_StarOnly.dds", 18, 18) .. " "
                    .. L("RUN_SET_LINE", data.name, data.have, data.total)
                if gained[data.setId] then
                    line = line .. "  " .. K.Colorize(C.good, L("RUN_GAINED", gained[data.setId]))
                elseif data.monster and not data.complete then
                    line = line .. "  " .. K.Colorize(C.dim, L("RUN_NOT_THIS_TIME"))
                end
                lines[#lines + 1] = line
            end
        end
    end
    if total > 0 then
        lines[#lines + 1] = K.Colorize(done == total and C.good or C.dim, L("RUN_COLLECTION_HERE", done, total))
    end
    sw.collection:SetText(table.concat(lines, "\n"))

    -- Loot list: quality-colored names, trait, NEW.
    local loot = {}
    for i = 1, zo_min(#finished.loot, MAX_LOOT_LINES) do
        local item = finished.loot[i]
        local quality = GetItemLinkDisplayQuality and GetItemLinkDisplayQuality(item.link) or GetItemLinkQuality(item.link)
        local name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(item.link))
        local trait = GetItemLinkTraitInfo(item.link)
        local traitName = (trait and trait ~= ITEM_TRAIT_TYPE_NONE) and GetString("SI_ITEMTRAITTYPE", trait) or ""
        local line = zo_iconFormat(GetItemLinkIcon(item.link), 20, 20) .. " "
            .. GetItemQualityColor(quality):Colorize(name) .. "  " .. K.Colorize(C.dim, traitName)
        if item.new then line = line .. "  " .. K.Colorize(C.good, L("RUN_NEW_TAG")) end
        loot[#loot + 1] = line
    end
    if #finished.loot > MAX_LOOT_LINES then
        loot[#loot + 1] = K.Colorize(C.dim, L("TT_MORE_SHORT", #finished.loot - MAX_LOOT_LINES))
    end
    if #loot == 0 then loot[1] = K.Colorize(C.dim, L("RUN_NO_LOOT")) end
    sw.loot:SetText(table.concat(loot, "\n"))
    sw.lootLines = #loot

    sw.again:SetHidden(not S.CanQueue(finished.zoneId))
    sw.showLoot = false
    LayoutSummary()
    sw.win:SetHidden(false)
    SetGameCameraUIMode(true)
end

local function FinishRun(completed)
    if not run then return end
    local finished = run
    run = nil
    if not completed and #finished.loot == 0 then return end   -- walked in and out: nothing to show
    RunsToday(finished.zoneId, true)
    ShowSummary(finished, completed)
end

local function OnPlayerActivated()
    local loc = CurrentDungeon()
    if run and (not loc or loc.id ~= run.zoneId) then FinishRun(false) end
    if not loc then finishedZone = nil end
    if loc and not run and loc.id ~= finishedZone then StartRun(loc) end
end

local function OnActivityComplete()
    if not run then return end
    finishedZone = run.zoneId
    -- Give the last loot a moment to arrive.
    zo_callLater(function() FinishRun(true) end, 2500)
end

function S.InitRuns()
    S.sv.runs = S.sv.runs or {}
    if S.sv.runSummary == nil then S.sv.runSummary = true end
    local name = "SetHunter_Run"
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_LOOT_RECEIVED, OnLootReceived)
    if EVENT_ACTIVITY_FINDER_ACTIVITY_COMPLETE then
        EVENT_MANAGER:RegisterForEvent(name, EVENT_ACTIVITY_FINDER_ACTIVITY_COMPLETE, OnActivityComplete)
    end
end

-- /sethunter testrun: shows the summary with made-up data, to check how it looks.
function S.TestRunSummary()
    local loc = CurrentDungeon() or S.GetLocation(S.ZoneIdByName("Arx Corinium"))
    if not loc then return end
    ShowSummary({ zoneId = loc.id, name = loc.name, veteran = true, start = GetFrameTimeSeconds() - 1334, loot = {} }, true)
end
