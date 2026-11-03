-- Fish Alert: sound + big on-screen text when a fish bites, plus a saved catch counter and a rare fish
-- tracker for the current zone (achievement IDs live in FishAlertData.lua).

FishAlert = { name = "FishAlert" }
local FA = FishAlert

-- A fish bite fires EVENT_VIBRATION with these values (observed by the FishingSound
-- addon author, not a documented API contract)
local BITE_DURATION = 2500    -- milliseconds
local BITE_COARSE = 0.01      -- arrives as 0.0099999997764826 (float precision)
local BITE_FINE = 0.05
local DURATION_TOLERANCE = 50
local MOTOR_TOLERANCE = 0.005
local COOLDOWN_MS = 5000      -- ignore further bite vibrations for this long after an alert
local SHOW_MS = 2500          -- how long the text stays on screen

local POLL_MS = 200           -- how often to check the fishing state for the counter
local HIDE_DELAY_MS = 5000    -- keep the counter up this long after fishing stops (between casts)
local CATCH_WINDOW_MS = 5000  -- loot must arrive within this long after a cast ends to count
local MOVE_MODE_TIMEOUT_MS = 120000  -- /fishalert move locks again by itself after this long
local MENU_GRACE_MS = 1000    -- a menu must stay open this long to end move mode (skips scene transitions)

local ITEM_LOOKUP_LINK_FORMAT = "|H0:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"    -- look up an item by ID only
local CAUGHT_ICON = zo_iconFormat("EsoUI/Art/Buttons/checkbox_checked.dds", 16, 16)
local MISSING_ICON = zo_iconFormat("EsoUI/Art/Buttons/checkbox_unchecked.dds", 16, 16)
local CELEBRATION_SHOW_MS = 6000
local SPECIAL_SHOW_MS = 3000         -- RARE FISH!, BONUS LOOT!, BAIT FOUND!, FURNISHING FOUND! and JUNK CAUGHT! banners
local WET_GUNNY_SACK_ITEM_ID = 43757 -- item ID from the loot event's link on two real Wet Gunny Sack catches
-- Fishing junk, by item ID: only items seen in a real catch's loot link. Many other items share ESO's trash type.
local FISHING_JUNK_ITEM_IDS = {
    [42878] = true,    -- Used Bait
}

-- Sound choices are stored as key names from ESO's SOUNDS table; "OFF" plays nothing
local SOUND_OFF = "OFF"
local SOUND_EVENTS = { "bite", "normalFish", "rareFish", "gunnySack", "zoneCompleted", "baitFound", "furnishingFound",
    "junkCaught" }
local SOUND_EVENT_NAMES = {
    bite = "Fishing Bite",
    normalFish = "Normal Fish",
    rareFish = "Rare Trophy Fish",
    gunnySack = "Wet Gunny Sack",
    zoneCompleted = "Zone Completed",
    baitFound = "Bait Found",
    furnishingFound = "Furnishing Found",
    junkCaught = "Junk Caught",
}
local DEFAULT_SOUNDS = {
    bite = "DUEL_START",
    normalFish = SOUND_OFF,
    rareFish = "ITEM_MONEY_CHANGED",
    gunnySack = "ANTIQUITIES_FANFARE_BONUS_ITEM_FOUND",
    zoneCompleted = "LEVEL_UP",
    baitFound = SOUND_OFF,
    furnishingFound = SOUND_OFF,
    junkCaught = SOUND_OFF,
}
-- Curated sounds offered for every event, grouped by feel. Each key is an entry in ESO's SOUNDS table
-- (API 101051) with its own audio name; how alike two of them sound can only be judged by ear.
local SOUND_LIBRARY = {
    { key = "ITEM_MONEY_CHANGED", name = "Coins: Gold Transaction" },
    { key = "STORE_WINDOW_SELL_CLICKED", name = "Coins: Merchant Sale" },
    { key = "STORE_WINDOW_BUY_CLICKED", name = "Coins: Merchant Purchase" },
    { key = "HOUSING_BUY_FOR_GOLD", name = "Coins: Housing Purchase" },
    { key = "FENCE_ITEM_LAUNDERED", name = "Coins: Fence Laundering" },
    { key = "TELVAR_GAINED", name = "Coins: Tel Var Gained" },
    { key = "JUSTICE_PICKPOCKET_BONUS", name = "Coins: Pickpocket Bonus" },
    { key = "CROWN_CRATES_GAIN_GEMS", name = "Coins: Crown Gems Gained" },
    { key = "ANTIQUITIES_FANFARE_BONUS_ITEM_FOUND", name = "Treasure: Bonus Item Found" },
    { key = "ANTIQUITIES_FANFARE_FRAGMENT_FOUND", name = "Treasure: Fragment Found" },
    { key = "LEVEL_UP_REWARD_CLAIM", name = "Treasure: Reward Claimed" },
    { key = "CROWN_CRATES_DEAL_BONUS", name = "Treasure: Crown Crate Bonus" },
    { key = "ANTIQUITIES_FANFARE_NEW_LEAD_FOUND", name = "Treasure: New Lead Found" },
    { key = "ANTIQUITIES_FANFARE_FRAGMENT_DISCOVERED_FINAL", name = "Treasure: All Fragments Found" },
    { key = "CROWN_CRATES_DEAL_PRIMARY", name = "Treasure: Crown Crate Deal" },
    { key = "CROWN_CRATES_CARDS_REVEAL_ALL", name = "Treasure: Crate Cards Revealed" },
    { key = "GIFT_INVENTORY_VIEW_FANFARE_SPARKS", name = "Treasure: Gift Sparkles" },
    { key = "LOCKPICKING_UNLOCKED", name = "Chest: Lock Opened" },
    { key = "LOCKPICKING_SUCCESS_CELEBRATION", name = "Chest: Lockpick Success" },
    { key = "LOOT_WINDOW_OPEN", name = "Chest: Loot Window" },
    { key = "TREASURE_MAP_OPEN", name = "Chest: Treasure Map" },
    { key = "LEVEL_UP", name = "Victory: Level Up" },
    { key = "ACHIEVEMENT_AWARDED", name = "Victory: Achievement" },
    { key = "QUEST_COMPLETED", name = "Victory: Quest Complete" },
    { key = "ANTIQUITIES_FANFARE_COMPLETED", name = "Victory: Antiquity Complete" },
    { key = "BOOK_COLLECTION_COMPLETED", name = "Victory: Book Collection" },
    { key = "LEVEL_UP_REWARD_FANFARE", name = "Victory: Reward Fanfare" },
    { key = "DAILY_LOGIN_REWARDS_CLAIM_FANFARE", name = "Victory: Daily Reward Fanfare" },
    { key = "SKILL_LINE_LEVELED_UP", name = "Victory: Skill Line Up" },
    { key = "RUMOR_COMPLETED", name = "Victory: Rumor Complete" },
    { key = "GIFT_INVENTORY_VIEW_FANFARE_BLAST", name = "Victory: Gift Fanfare" },
    { key = "RAID_TRIAL_COMPLETED", name = "Victory: Trial Complete" },
    { key = "RAID_TRIAL_NEW_BEST", name = "Victory: Trial New Best" },
    { key = "TRIBUTE_SUMMARY_BEGIN_VICTORY", name = "Victory: Tribute Win" },
    { key = "RANK_UP", name = "Victory: Rank Up" },
    { key = "BATTLEGROUND_MEDAL_RECEIVED", name = "Victory: Battleground Medal" },
    { key = "COLLECTIBLE_UNLOCKED", name = "Magic: Collectible Unlocked" },
    { key = "ENCHANTING_CREATE_TOOLTIP_GLOW", name = "Magic: Enchanting Glow" },
    { key = "CHAMPION_POINT_GAINED", name = "Magic: Champion Point" },
    { key = "CHAMPION_STAR_UNLOCKED", name = "Magic: Champion Star" },
    { key = "CRAFTED_ABILITY_UNLOCKED", name = "Magic: Crafted Ability Unlocked" },
    { key = "DUEL_START", name = "Alert: Duel Start" },
    { key = "NEW_NOTIFICATION", name = "Alert: Notification" },
    { key = "NEW_MAIL", name = "Alert: New Mail" },
    { key = "OBJECTIVE_COMPLETED", name = "Alert: Objective Complete" },
    { key = "BOOK_ACQUIRED", name = "Alert: Book Acquired" },
    { key = "LFG_READY_CHECK", name = "Alert: Ready Check" },
    { key = "COUNTDOWN_WARNING", name = "Alert: Countdown Warning" },
    { key = "NEW_TIMED_NOTIFICATION", name = "Alert: Timed Notification" },
    { key = "TRADE_PARTICIPANT_READY", name = "Alert: Trade Ready" },
}
local SOUND_REPEAT_GUARD_MS = 250    -- an event's sound never plays twice within this window

-- Banners share the REEL IN! spot; a higher priority replaces a lower one, the bite alert is highest
local NOTIFICATIONS = {
    reelIn = { text = "REEL IN!", color = { 0.2, 1, 0.2 }, priority = 3, durationMs = SHOW_MS, sound = "bite" },
    zoneCompleted = { text = "ZONE COMPLETED!", color = { 1, 0.6, 0.15 }, priority = 2,
        durationMs = CELEBRATION_SHOW_MS, sound = "zoneCompleted" },
    rareFish = { text = "RARE FISH!", color = { 1, 0.85, 0.2 }, priority = 1, durationMs = SPECIAL_SHOW_MS,
        sound = "rareFish" },
    bonusLoot = { text = "BONUS LOOT!", color = { 0.7, 0.4, 1 }, priority = 1, durationMs = SPECIAL_SHOW_MS,
        sound = "gunnySack" },
    -- A deeper red-orange than ZONE COMPLETED! so the two read differently
    baitFound = { text = "BAIT FOUND!", color = { 1, 0.4, 0.05 }, priority = 1, durationMs = SPECIAL_SHOW_MS,
        sound = "baitFound" },
    furnishingFound = { text = "FURNISHING FOUND!", color = { 0.3, 0.85, 1 }, priority = 1,
        durationMs = SPECIAL_SHOW_MS, sound = "furnishingFound" },
    junkCaught = { text = "JUNK CAUGHT!", color = { 0.75, 0.78, 0.82 }, priority = 1, durationMs = SPECIAL_SHOW_MS,
        sound = "junkCaught" },
}

local lastAlertMs = -COOLDOWN_MS
local window

-- Account-wide saved data; the version must stay 1 or ESO wipes the saved table. Defaults only fill in
-- missing keys, so existing totals, position and sound choices are kept.
local SAVED_VARS_VERSION = 1
local SAVED_DEFAULTS = { fishCaught = 0, rareCaught = 0, debugLoot = false, sounds = DEFAULT_SOUNDS }

local savedVars
local counter, counterBackdrop, counterTitle, fishLabel, filletLabel, rareLabel
local trackerTitle, trackerLabel
local notificationTitle, notificationSubtitle
local currentNotification, pendingNotification
local notificationShowCount = 0
local lastSoundMs = {}                -- event = frame time its sound last played
local warnedSounds = {}               -- events whose stored sound was unavailable (reported once)
local lastShownFish, lastShownRare = 0, 0
local trackerZoneId                  -- zone the tracker text was last built for
local trackerDirty = true            -- achievement progress changed since the last build
local trackedAchievements = {}       -- achievement IDs shown in the tracker right now
local celebrated = {}                -- achievement IDs already celebrated this session
local fishQualityCache = {}          -- achievement ID = item quality (or false) per criterion, built once per session
local isFishing = false
local counterShown = false
local counterUnlocked = false
local moveModeEndMs = 0
local moveModeSawCursor = false
local menuOpenSinceMs
local isDragging, isMouseOver = false, false
local lastFishingActivityMs = 0
local catchWindowEndMs = 0
local castCounted, castRareCounted, castBonusShown, castBaitShown = false, false, false, false
local castBiteSeen, castFurnishingShown = false, false    -- a bite was detected during this cast / furnishing announced
local castJunkShown = false
local fishToFillet                -- live count of filletable fish in the backpack; nil until first counted
local fishToFilletStale = true       -- backpack changed since the last count

local function DebugMessage(message)
    if savedVars.debugLoot then
        d("FishAlert: " .. message)
    end
end

-- Resolve an event's chosen sound through ESO's SOUNDS table; an unknown stored name falls back to the default
local function GetEventSound(event)
    local key = savedVars.sounds[event] or DEFAULT_SOUNDS[event]
    if key == SOUND_OFF then
        return nil
    end
    if SOUNDS[key] then
        return SOUNDS[key]
    end
    if not warnedSounds[event] then
        warnedSounds[event] = true
        DebugMessage(string.format("sound %s for %s is not available, using the default", tostring(key), event))
    end
    local defaultKey = DEFAULT_SOUNDS[event]
    return defaultKey ~= SOUND_OFF and SOUNDS[defaultKey] or nil
end

-- Every FishAlert sound goes through here; it only calls PlaySound, never ESO's audio settings
local function PlayEventSound(event)
    local sound = GetEventSound(event)
    local now = GetFrameTimeMilliseconds()
    if not sound or now - (lastSoundMs[event] or -SOUND_REPEAT_GUARD_MS) < SOUND_REPEAT_GUARD_MS then
        return
    end
    lastSoundMs[event] = now
    PlaySound(sound)
end

-- Settings previews play the given choice directly
local function PreviewSound(key)
    if key ~= SOUND_OFF and SOUNDS[key] then
        PlaySound(SOUNDS[key])
    end
end

-- Build the shared banner in the REEL IN! spot (hidden until needed)
local function CreateAlertWindow()
    local wm = WINDOW_MANAGER
    window = wm:CreateTopLevelWindow("FishAlertWindow")
    window:SetDimensions(500, 120)
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, -150)
    window:SetHidden(true)

    notificationTitle = wm:CreateControl("FishAlertLabel", window, CT_LABEL)
    notificationTitle:SetAnchor(CENTER, window, CENTER, 0, 0)
    notificationTitle:SetFont("ZoFontCallout3")

    notificationSubtitle = wm:CreateControl("FishAlertSubtitle", window, CT_LABEL)
    notificationSubtitle:SetAnchor(TOP, notificationTitle, BOTTOM, 0, 4)
    notificationSubtitle:SetFont("ZoFontWinH3")
end

local DisplayNotification    -- declared early: a finished banner shows the waiting one

local function KeepPending(request)
    if not pendingNotification
        or NOTIFICATIONS[request.type].priority >= NOTIFICATIONS[pendingNotification.type].priority then
        pendingNotification = request
    end
end

DisplayNotification = function(request)
    local info = NOTIFICATIONS[request.type]
    currentNotification = request
    notificationTitle:SetText((request.icon and zo_iconFormat(request.icon, 48, 48) .. " " or "") .. info.text)
    notificationTitle:SetColor(info.color[1], info.color[2], info.color[3], 1)
    notificationSubtitle:SetText(request.subtitle or "")
    window:SetHidden(false)
    if not request.soundPlayed then
        request.soundPlayed = true
        PlayEventSound(info.sound)
    end

    -- Only the latest banner's timer may hide the window
    notificationShowCount = notificationShowCount + 1
    local showCount = notificationShowCount
    zo_callLater(function()
        if showCount ~= notificationShowCount then return end
        currentNotification = nil
        window:SetHidden(true)
        if pendingNotification then
            local nextRequest = pendingNotification
            pendingNotification = nil
            DisplayNotification(nextRequest)
        end
    end, info.durationMs)
end

-- One banner at a time: the same banner is never stacked, a higher priority replaces the current banner
-- (which shows again afterwards without replaying its sound), and anything else waits its turn
local function ShowNotification(notificationType, subtitle, icon)
    local request = { type = notificationType, subtitle = subtitle, icon = icon }
    if currentNotification then
        if currentNotification.type == notificationType then
            return
        end
        if NOTIFICATIONS[notificationType].priority > NOTIFICATIONS[currentNotification.type].priority then
            KeepPending(currentNotification)
        else
            KeepPending(request)
            return
        end
    end
    DisplayNotification(request)
end

local function ShowAlert()
    ShowNotification("reelIn")
end

local function IsNear(value, target, tolerance)
    return value ~= nil and math.abs(value - target) <= tolerance
end

-- The game rumbles the controller when a fish bites; match that specific vibration
local function OnVibration(event, duration, coarseMotor, fineMotor, leftTriggerMotor, rightTriggerMotor)
    if not IsNear(duration, BITE_DURATION, DURATION_TOLERANCE) then return end
    if not IsNear(coarseMotor, BITE_COARSE, MOTOR_TOLERANCE) then return end
    if not IsNear(fineMotor, BITE_FINE, MOTOR_TOLERANCE) then return end

    -- Remembered for furnishing detection only; the alert below is unchanged
    if GetInteractionType() == INTERACTION_FISH then
        castBiteSeen = true
    end

    local now = GetFrameTimeMilliseconds()
    if now - lastAlertMs < COOLDOWN_MS then return end
    lastAlertMs = now

    ShowAlert()
end

-- The outline shows in move mode, and while the mouse cursor is over or dragging the window
local function RefreshBackdrop()
    counterBackdrop:SetHidden(not (counterUnlocked or isDragging or isMouseOver))
end

-- Build the small counter panel (hidden until fishing starts)
local function CreateCounterWindow()
    local wm = WINDOW_MANAGER
    counter = wm:CreateTopLevelWindow("FishAlertCounter")
    counter:SetDimensions(180, 70)
    counter:SetClampedToScreen(true)
    counter:SetHidden(true)
    if savedVars.counterLeft then
        counter:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, savedVars.counterLeft, savedVars.counterTop)
    else
        counter:SetAnchor(LEFT, GuiRoot, LEFT, 60, -100)
    end

    -- Always draggable; the mouse only reaches it while the cursor is active (chat open, or the "." key)
    counter:SetMovable(true)
    counter:SetMouseEnabled(true)
    counter:SetHandler("OnMoveStart", function()
        isDragging = true
        RefreshBackdrop()
    end)
    counter:SetHandler("OnMoveStop", function(control)
        savedVars.counterLeft = control:GetLeft()
        savedVars.counterTop = control:GetTop()
        isDragging = false
        RefreshBackdrop()
    end)
    counter:SetHandler("OnMouseEnter", function()
        isMouseOver = true
        RefreshBackdrop()
    end)
    counter:SetHandler("OnMouseExit", function()
        isMouseOver = false
        RefreshBackdrop()
    end)

    -- Outline shown only while unlocked, so the drag area is visible
    counterBackdrop = wm:CreateControlFromVirtual("FishAlertCounterBackdrop", counter, "ZO_ThinBackdrop")
    counterBackdrop:SetDrawLayer(DL_BACKGROUND)
    counterBackdrop:SetHidden(true)

    counterTitle = wm:CreateControl("FishAlertCounterTitle", counter, CT_LABEL)
    counterTitle:SetAnchor(TOPLEFT, counter, TOPLEFT, 0, 0)
    counterTitle:SetFont("ZoFontWinH5")
    counterTitle:SetColor(0.2, 1, 0.2, 1)
    counterTitle:SetText("FISHALERT")

    fishLabel = wm:CreateControl("FishAlertCounterFish", counter, CT_LABEL)
    fishLabel:SetAnchor(TOPLEFT, counterTitle, BOTTOMLEFT, 0, 2)
    fishLabel:SetFont("ZoFontGame")

    filletLabel = wm:CreateControl("FishAlertCounterFillet", counter, CT_LABEL)
    filletLabel:SetAnchor(TOPLEFT, fishLabel, BOTTOMLEFT, 0, 0)
    filletLabel:SetFont("ZoFontGame")
    filletLabel:SetText("Fish to Fillet: 0")

    rareLabel = wm:CreateControl("FishAlertCounterRare", counter, CT_LABEL)
    rareLabel:SetAnchor(TOPLEFT, filletLabel, BOTTOMLEFT, 0, 0)
    rareLabel:SetFont("ZoFontGame")

    -- The rare fish tracker sits under the counter in the same window, so both move together
    trackerTitle = wm:CreateControl("FishAlertTrackerTitle", counter, CT_LABEL)
    trackerTitle:SetAnchor(TOPLEFT, rareLabel, BOTTOMLEFT, 0, 10)
    trackerTitle:SetFont("ZoFontWinH5")
    trackerTitle:SetColor(0.2, 1, 0.2, 1)
    trackerTitle:SetText("RARE FISH TRACKER")

    trackerLabel = wm:CreateControl("FishAlertTrackerText", counter, CT_LABEL)
    trackerLabel:SetAnchor(TOPLEFT, trackerTitle, BOTTOMLEFT, 0, 2)
    trackerLabel:SetFont("ZoFontGame")
end


local function UpdateCounterText()
    local fish, rare = savedVars.fishCaught, savedVars.rareCaught
    -- Totals should only drop through a reset (command or settings); flag anything else in chat
    if fish < lastShownFish or rare < lastShownRare then
        d(string.format("FishAlert warning: a total went down without a reset (Fish Caught %d -> %d, Rare Fish %d -> %d). Another addon may have changed FishAlert's saved data. To find out which, turn on /fishalert debug and note what happened just before this message.",
            lastShownFish, fish, lastShownRare, rare))
    end
    lastShownFish, lastShownRare = fish, rare

    fishLabel:SetText("Fish Caught: " .. fish)
    rareLabel:SetText("Rare Fish: " .. rare)
end

local function GetPlayerZoneId()
    local zoneIndex = GetUnitZoneIndex("player")
    return zoneIndex and GetZoneId(zoneIndex) or 0
end

-- Exact zone first (Artaeum's parent is Summerset), then the parent zone for delves and sewers
local function GetZoneFishingAchievements(zoneId)
    local zoneMap = FA.ZONE_FISHING_ACHIEVEMENTS or {}
    if zoneMap[zoneId] then
        return zoneId, zoneMap[zoneId]
    end
    local parentZoneId = GetParentZoneId(zoneId)
    if parentZoneId and zoneMap[parentZoneId] then
        return parentZoneId, zoneMap[parentZoneId]
    end
    return zoneId, nil
end

-- Look up a fish item by ID; nil unless ESO still reports that exact ID as a rare fish
local function GetVerifiedFishItem(itemId)
    local link = string.format(ITEM_LOOKUP_LINK_FORMAT, itemId)
    if GetItemLinkItemId(link) ~= itemId then
        return nil
    end
    local _, specializedType = GetItemLinkItemType(link)
    if specializedType ~= SPECIALIZED_ITEMTYPE_COLLECTIBLE_RARE_FISH then
        return nil
    end
    return {
        name = zo_strlower(zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(link))),
        quality = GetItemLinkDisplayQuality(link),
    }
end

-- Pair criteria with fish items by name (ignoring case and the trailing water type), never by position.
-- A criterion only gets a quality when exactly one item matches it and that item matches no other
-- criterion; anything else is false, so the fish keeps the neutral text color.
local function MatchFishQualities(achievementId, descriptions)
    local items = {}
    local itemIds = FA.FISHING_ACHIEVEMENT_FISH and FA.FISHING_ACHIEVEMENT_FISH[achievementId] or {}
    for _, itemId in ipairs(itemIds) do
        items[itemId] = GetVerifiedFishItem(itemId)
    end
    local exceptions = FA.FISH_CRITERION_EXCEPTIONS and FA.FISH_CRITERION_EXCEPTIONS[achievementId] or {}

    local matchedItems, criteriaPerItem, byException = {}, {}, {}
    for i, description in ipairs(descriptions) do
        local fishName = zo_strlower(zo_strformat(SI_ACHIEVEMENT_CRITERION_FORMAT, description))
        fishName = fishName:gsub("%s*%b()%s*$", "")
        local match
        for itemId, item in pairs(items) do
            if item.name == fishName then
                match = (match == nil) and itemId or false
            end
        end

        -- Evidence-based pairing: exact criterion text only, and the item must still check out
        local exception = exceptions[description]
        if match == nil and exception then
            local item = GetVerifiedFishItem(exception.itemId)
            if item and item.quality == exception.quality then
                items[exception.itemId] = item
                match = exception.itemId
                byException[i] = true
            end
        end

        matchedItems[i] = match or false
        if match then
            criteriaPerItem[match] = (criteriaPerItem[match] or 0) + 1
        end
    end

    local qualities, numColored, numByException = {}, 0, 0
    for i, itemId in ipairs(matchedItems) do
        qualities[i] = itemId and criteriaPerItem[itemId] == 1 and items[itemId].quality or false
        if qualities[i] then
            numColored = numColored + 1
            if byException[i] then
                numByException = numByException + 1
            end
        end
    end
    DebugMessage(string.format("rarity achievement %d: %d of %d fish colored (%d by evidence-based pairing)",
        achievementId, numColored, #descriptions, numByException))
    return qualities
end

-- Read a fishing achievement from ESO, or return nil and a reason if it doesn't match FishAlertData.lua
local function ReadFishingAchievement(achievementId)
    local expectedCriteria = FA.FISHING_ACHIEVEMENTS and FA.FISHING_ACHIEVEMENTS[achievementId]
    local name = GetAchievementInfo(achievementId)
    if not name or name == "" then
        return nil, "no achievement with this ID"
    end
    local numCriteria = GetAchievementNumCriteria(achievementId)
    if numCriteria ~= expectedCriteria then
        return nil, string.format("expected %s criteria, found %d", tostring(expectedCriteria), numCriteria)
    end

    local fish, descriptions, numCaught = {}, {}, 0
    for i = 1, numCriteria do
        local description, numCompleted, numRequired = GetAchievementCriterion(achievementId, i)
        if numRequired ~= 1 then
            return nil, string.format("criterion %d needs %d, expected 1 per fish", i, numRequired)
        end
        local caught = numCompleted >= numRequired
        if caught then
            numCaught = numCaught + 1
        end
        descriptions[i] = description
        fish[i] = { name = zo_strformat(SI_ACHIEVEMENT_CRITERION_FORMAT, description), caught = caught }
    end

    -- Fish names and items don't change during a session, so the rarity matching runs once per achievement
    local qualities = fishQualityCache[achievementId]
    if not qualities then
        qualities = MatchFishQualities(achievementId, descriptions)
        fishQualityCache[achievementId] = qualities
    end
    for i, entry in ipairs(fish) do
        entry.quality = qualities[i]
    end
    return { name = name, fish = fish, numCaught = numCaught, completed = IsAchievementComplete(achievementId) }
end

local function BuildTrackerText(zoneId)
    local mappedZoneId, achievementIds = GetZoneFishingAchievements(zoneId)
    local zoneName = zo_strformat(SI_ZONE_NAME, GetZoneNameById(mappedZoneId))
    local lines = { "|cE6C859" .. zoneName .. "|r" }
    ZO_ClearTable(trackedAchievements)

    if not achievementIds then
        table.insert(lines, "|c8F8F8FNo supported rare fish achievement here.|r")
        DebugMessage(string.format("tracker zone %d (%s), parent %d: no verified fishing achievement",
            zoneId, zoneName, GetParentZoneId(zoneId)))
        return table.concat(lines, "\n")
    end

    -- Zones with more than one achievement (Solstice, Gold Coast) get a labeled section for each
    local labelSections = #achievementIds > 1
    for sectionIndex, achievementId in ipairs(achievementIds) do
        trackedAchievements[achievementId] = true
        if sectionIndex > 1 then
            table.insert(lines, "")
        end

        local achievement, reason = ReadFishingAchievement(achievementId)
        if not achievement then
            table.insert(lines, "|c8F8F8FAchievement data unavailable.|r")
            DebugMessage(string.format("tracker achievement %d unavailable: %s", achievementId, reason))
        else
            if labelSections then
                table.insert(lines, "|cC5C29E" .. achievement.name .. "|r")
            end
            for _, fish in ipairs(achievement.fish) do
                local icon = fish.caught and CAUGHT_ICON or MISSING_ICON
                if fish.quality then
                    -- Verified rarity: ESO's own item quality color, caught or not
                    table.insert(lines, icon .. " " .. GetItemQualityColor(fish.quality):Colorize(fish.name))
                elseif fish.caught then
                    table.insert(lines, icon .. " " .. fish.name)
                else
                    table.insert(lines, icon .. " |c8F8F8F" .. fish.name .. "|r")
                end
            end
            local numFish = #achievement.fish
            table.insert(lines, string.format("Progress: %d / %d - %d%%%s", achievement.numCaught, numFish,
                math.floor(achievement.numCaught * 100 / numFish), achievement.completed and " - Completed" or ""))
            DebugMessage(string.format("tracker zone %d (%s) -> achievement %d %s: %d/%d%s", zoneId, zoneName,
                achievementId, achievement.name, achievement.numCaught, numFish, achievement.completed and ", complete" or ""))
        end
    end
    return table.concat(lines, "\n")
end

-- Size the window to its text so the drag area and outline cover both sections
local function ResizeCounter()
    local width = math.max(180, counterTitle:GetTextWidth(), fishLabel:GetTextWidth(), filletLabel:GetTextWidth(),
        rareLabel:GetTextWidth(), trackerTitle:GetTextWidth(), trackerLabel:GetTextWidth())
    local height = counterTitle:GetTextHeight() + 2 + fishLabel:GetTextHeight() + filletLabel:GetTextHeight()
        + rareLabel:GetTextHeight() + 10 + trackerTitle:GetTextHeight() + 2 + trackerLabel:GetTextHeight()
    counter:SetDimensions(width, height)
end

-- Filletable means whatever ESO's own Fillet panel accepts (an ITEMTYPE_FISH item), so trophy fish and
-- other items are left out; junk and stolen fish count. Only this character's backpack is read.
local function IsFilletable(slotIndex)
    if ZO_FishFillet_Shared_IsFilletableItem then
        return ZO_FishFillet_Shared_IsFilletableItem(BAG_BACKPACK, slotIndex)
    end
    return GetItemType(BAG_BACKPACK, slotIndex) == ITEMTYPE_FISH
end

local function RefreshFishToFillet()
    fishToFilletStale = false
    local count, numStacks, numCraftBagEligible = 0, 0, 0
    local slotIndex = ZO_GetNextBagSlotIndex(BAG_BACKPACK)
    while slotIndex do
        if IsFilletable(slotIndex) then
            count = count + GetSlotStackSize(BAG_BACKPACK, slotIndex)
            numStacks = numStacks + 1
            if CanItemBeVirtual(BAG_BACKPACK, slotIndex) then
                numCraftBagEligible = numCraftBagEligible + 1
            end
        end
        slotIndex = ZO_GetNextBagSlotIndex(BAG_BACKPACK, slotIndex)
    end

    if count ~= fishToFillet then
        DebugMessage(string.format("Fish to Fillet %s -> %d (%d stacks, %d craft-bag eligible)",
            tostring(fishToFillet or "?"), count, numStacks, numCraftBagEligible))
        fishToFillet = count
        filletLabel:SetText("Fish to Fillet: " .. count)
        ResizeCounter()
    end
end

local function RefreshTracker()
    trackerZoneId = GetPlayerZoneId()
    trackerDirty = false
    trackerLabel:SetText(BuildTrackerText(trackerZoneId))
    ResizeCounter()
end

-- Only show on the plain HUD, so menus and the map aren't covered; the tracker is only rebuilt
-- while visible, after a zone change or an achievement update
local function RefreshCounterVisibility()
    local hudShowing = HUD_SCENE:IsShowing() or HUD_UI_SCENE:IsShowing()
    local visible = counterUnlocked or (counterShown and hudShowing)
    -- The fillet count is read from the backpack only while visible, once per burst of inventory changes
    if visible and fishToFilletStale then
        RefreshFishToFillet()
    end
    if visible and (trackerDirty or GetPlayerZoneId() ~= trackerZoneId) then
        RefreshTracker()
    elseif not visible and isMouseOver then
        -- A hidden window gets no mouse-exit, so drop the hover outline here
        isMouseOver = false
        RefreshBackdrop()
    end
    counter:SetHidden(not visible)
end

local function ShowCelebration(achievementId)
    local name, _, _, icon = GetAchievementInfo(achievementId)
    ShowNotification("zoneCompleted", name, icon)
end

local function OnAchievementUpdated(event, achievementId)
    if trackedAchievements[achievementId] then
        trackerDirty = true
        DebugMessage(string.format("tracker achievement %d progress updated", achievementId))
    end
end

local function OnAchievementsUpdated()
    trackerDirty = true
end

-- ESO only awards an achievement once, when it is actually earned, so entering a completed zone or
-- loading the UI never celebrates; the session table guards against a repeated event
local function OnAchievementAwarded(event, name, points, achievementId, link)
    if not (FA.FISHING_ACHIEVEMENTS and FA.FISHING_ACHIEVEMENTS[achievementId]) then return end
    trackerDirty = true
    if celebrated[achievementId] then return end
    celebrated[achievementId] = true
    DebugMessage(string.format("fishing achievement %d completed, celebrating", achievementId))
    ShowCelebration(achievementId)
end

local function IsTargetingFishingHole()
    return select(5, GetGameCameraInteractableActionInfo()) == ADDITIONAL_INTERACT_INFO_FISHING_NODE
end

local function SetCounterUnlocked(unlocked)
    counterUnlocked = unlocked
    moveModeEndMs = GetFrameTimeMilliseconds() + MOVE_MODE_TIMEOUT_MS
    moveModeSawCursor = false
    menuOpenSinceMs = nil
    RefreshBackdrop()
    RefreshCounterVisibility()
    if unlocked then
        d("FishAlert: move mode on. Drag the window with the mouse; it locks again when you close chat, open a menu, enter combat, or after 2 minutes.")
    else
        d("FishAlert: move mode off.")
    end
end

-- Move mode ends by itself once the player is back in normal play, so the window can't stay up indefinitely
local function UpdateMoveMode(now)
    if not counterUnlocked then return end

    local inHud = HUD_SCENE:IsShowing()
    local inCursorMode = HUD_UI_SCENE:IsShowing()
    if inCursorMode then
        moveModeSawCursor = true
    end
    if inHud or inCursorMode then
        menuOpenSinceMs = nil
    else
        menuOpenSinceMs = menuOpenSinceMs or now
    end

    local backToGameplay = inHud and moveModeSawCursor
    local menuOpen = menuOpenSinceMs ~= nil and now - menuOpenSinceMs >= MENU_GRACE_MS
    if backToGameplay or menuOpen or IsUnitInCombat("player") or now >= moveModeEndMs then
        SetCounterUnlocked(false)
    end
end

-- Track casts (for catch filtering) and decide whether the counter should be up
local function UpdateFishingState()
    local now = GetFrameTimeMilliseconds()
    local interaction = GetInteractionType()
    local fishingNow = interaction == INTERACTION_FISH
    UpdateMoveMode(now)

    if fishingNow and not isFishing then
        castCounted, castRareCounted, castBonusShown, castBaitShown = false, false, false, false
        castBiteSeen, castFurnishingShown, castJunkShown = false, false, false
    elseif isFishing and not fishingNow then
        catchWindowEndMs = now + CATCH_WINDOW_MS
    end
    isFishing = fishingNow

    -- With auto-loot off, keep the catch window open while the loot window is up
    if interaction == INTERACTION_LOOT and now < catchWindowEndMs then
        catchWindowEndMs = now + CATCH_WINDOW_MS
    end

    if IsUnitInCombat("player") then
        counterShown = false
    elseif fishingNow then
        counterShown = true
        lastFishingActivityMs = now
    elseif counterShown then
        -- An already-visible window also stays up while the cursor is active, so it can be dragged
        if interaction == INTERACTION_LOOT or IsTargetingFishingHole() or isDragging or HUD_UI_SCENE:IsShowing() then
            lastFishingActivityMs = now
        elseif now - lastFishingActivityMs > HIDE_DELAY_MS then
            counterShown = false
        end
    end

    RefreshCounterVisibility()
end

-- Count looted fish, but only right after a cast; trades, mail, stores and the bank don't fire this event
local function OnLootReceived(event, receivedBy, itemLink, quantity, soundCategory, lootType, isSelf, isPickpocketLoot, questItemIcon, itemId, isStolen)
    if not isSelf or lootType ~= LOOT_TYPE_ITEM or isPickpocketLoot or isStolen then return end

    local itemType, specializedType = GetItemLinkItemType(itemLink)
    local isRare = specializedType == SPECIALIZED_ITEMTYPE_COLLECTIBLE_RARE_FISH
    local isFish = isRare or itemType == ITEMTYPE_FISH
    local fromFishing = isFishing or GetInteractionType() == INTERACTION_FISH or GetFrameTimeMilliseconds() < catchWindowEndMs

    if savedVars.debugLoot then
        d(string.format("FishAlert loot: %s type=%d special=%d fish=%s rare=%s fromFishing=%s",
            itemLink, itemType, specializedType, tostring(isFish), tostring(isRare), tostring(fromFishing)))
    end

    -- A Wet Gunny Sack is matched by item ID, gets one banner per cast, and is never counted as a fish
    if fromFishing and not castBonusShown and GetItemLinkItemId(itemLink) == WET_GUNNY_SACK_ITEM_ID then
        castBonusShown = true
        ShowNotification("bonusLoot")
    end
    -- Any bait (ESO's lure item type, so no name or ID list) gets one banner per cast and is never counted as a fish
    if fromFishing and not castBaitShown and itemType == ITEMTYPE_LURE then
        castBaitShown = true
        ShowNotification("baitFound")
    end
    -- Junk only from the verified registry (never every trash item), one banner per cast, never counted as a fish
    if fromFishing and not castJunkShown and FISHING_JUNK_ITEM_IDS[GetItemLinkItemId(itemLink)] then
        castJunkShown = true
        ShowNotification("junkCaught")
    end
    -- Placeable furnishings only (plans and materials have other item types). The loot event doesn't say where an
    -- item came from, so a furnishing must be the only catch of a cast that had a bite: a sack opened after its
    -- catch, or a container looted after a cast with no bite, is skipped
    if itemType == ITEMTYPE_FURNISHING then
        local placeable = IsItemLinkPlaceableFurniture(itemLink)
        local otherCatch = castCounted or castBonusShown or castBaitShown or castJunkShown or castFurnishingShown
        DebugMessage(string.format("furnishing placeable=%s fromFishing=%s bite=%s otherCatch=%s",
            tostring(placeable), tostring(fromFishing), tostring(castBiteSeen), tostring(otherCatch)))
        if placeable and fromFishing and castBiteSeen and not otherCatch then
            castFurnishingShown = true
            ShowNotification("furnishingFound")
        end
    end
    if not (isFish and fromFishing) then return end

    -- One catch counts once, even if it hands out more than one fish item
    local oldFish, oldRare = savedVars.fishCaught, savedVars.rareCaught
    if not castCounted then
        savedVars.fishCaught = oldFish + 1
        castCounted = true
        -- Ordinary fish only get the chosen Normal Fish sound (Off by default), no banner
        if not isRare then
            PlayEventSound("normalFish")
        end
    end
    if isRare and not castRareCounted then
        savedVars.rareCaught = oldRare + 1
        castRareCounted = true
        -- Same once-per-cast guard as the count; the banner plays the chosen Rare Trophy Fish sound (or none if Off)
        ShowNotification("rareFish")
    end
    if savedVars.debugLoot then
        d(string.format("FishAlert: Fish Caught %d -> %d, Rare Fish %d -> %d",
            oldFish, savedVars.fishCaught, oldRare, savedVars.rareCaught))
    end
    UpdateCounterText()
end

local HELP_LINES = {
    "FishAlert commands:",
    "/fishalert move - unlock the counter window so it can be dragged",
    "/fishalert reset - set Fish Caught and Rare Fish to 0 right away (no confirmation)",
    "/fishalert debug - turn troubleshooting messages in chat on or off",
    "/fishalert banner reel, rare, bonus, bait, furnishing, junk or zone - show a test banner with its sound",
    "/fishalert help - show this list",
}

local function ShowHelp()
    for _, line in ipairs(HELP_LINES) do
        d(line)
    end
end

-- /fishalert move unlocks the counter, /fishalert reset clears both totals, /fishalert debug logs loot,
-- /fishalert banner reel|rare|bonus|bait|furnishing|junk|zone shows a test banner, and /fishalert or
-- /fishalert help lists the commands. Anything else gets a usage hint, never a test alert.
local function OnSlashCommand(args)
    args = string.lower(zo_strtrim(args or ""))
    if args == "" or args == "help" then
        ShowHelp()
    elseif args == "move" then
        SetCounterUnlocked(not counterUnlocked)
    elseif args == "reset" then
        savedVars.fishCaught, savedVars.rareCaught = 0, 0
        lastShownFish, lastShownRare = 0, 0
        UpdateCounterText()
        d("FishAlert: fishing totals reset.")
    elseif args == "debug" then
        savedVars.debugLoot = not savedVars.debugLoot
        d("FishAlert: debug " .. (savedVars.debugLoot and "on" or "off"))
    elseif args == "banner reel" then
        ShowAlert()
    elseif args == "banner rare" then
        ShowNotification("rareFish")
    elseif args == "banner bonus" then
        ShowNotification("bonusLoot")
    elseif args == "banner bait" then
        ShowNotification("baitFound")
    elseif args == "banner furnishing" then
        ShowNotification("furnishingFound")
    elseif args == "banner junk" then
        ShowNotification("junkCaught")
    elseif args == "banner zone" then
        ShowNotification("zoneCompleted", "Banner test")
    elseif args == "banner" or args:find("^banner ") then
        d("FishAlert: usage: /fishalert banner followed by reel, rare, bonus, bait, furnishing, junk or zone")
    else
        d(string.format("FishAlert: unknown command \"%s\". Type /fishalert help for the list of commands.", args))
    end
end

-- The first panel saved dropdown labels such as "Lockpicking Unlocked" instead of SOUNDS keys (see
-- CreateSettingsPanel); turn those back into keys, and anything else unknown into the event's default
local function NormalizeSoundChoices()
    for _, event in ipairs(SOUND_EVENTS) do
        local stored = savedVars.sounds[event]
        if stored ~= SOUND_OFF and not (type(stored) == "string" and SOUNDS[stored]) then
            local key = DEFAULT_SOUNDS[event]
            if type(stored) == "string" then
                local label = stored:gsub(" %(default%)$", "")
                local labelKey = label:upper():gsub(" ", "_")
                if label == "Off" then
                    key = SOUND_OFF
                elseif SOUNDS[labelKey] then
                    key = labelKey
                end
            end
            savedVars.sounds[event] = key
            DebugMessage(string.format("sound choice for %s converted from %q to %s", event, tostring(stored), key))
        end
    end
end

-- Single-counter resets from the settings panel, each behind a confirmation. The confirmation is ESO's own dialog:
-- older LibAddonMenu copies bundled in other addons replace the button control with one that ignores isDangerous.
local RESET_COUNTERS = {
    { key = "fishCaught", label = "Fish Caught", dialog = "FISHALERT_RESET_FISH_CAUGHT" },
    { key = "rareCaught", label = "Rare Fish", dialog = "FISHALERT_RESET_RARE_FISH" },
}

local function ResetCounter(counter)
    savedVars[counter.key] = 0
    -- Keep the "counter went down" warning quiet for an intended reset
    if counter.key == "fishCaught" then
        lastShownFish = 0
    else
        lastShownRare = 0
    end
    UpdateCounterText()
    d("FishAlert: " .. counter.label .. " reset to 0.")
end

local function RegisterResetDialogs()
    for _, counter in ipairs(RESET_COUNTERS) do
        ZO_Dialogs_RegisterCustomDialog(counter.dialog, {
            title = { text = "Reset " .. counter.label },
            mainText = { text = "Reset " .. counter.label .. " to 0? This cannot be undone." },
            buttons = {
                { text = SI_DIALOG_CONFIRM, callback = function() ResetCounter(counter) end },
                { text = SI_DIALOG_CANCEL },
            },
        })
    end
end

-- Settings > Addons > FishAlert, when LibAddonMenu-2.0 is installed; without it the saved choices still apply.
-- Older LibAddonMenu copies bundled inside other addons can replace the shared dropdown control with one that
-- ignores choicesValues, so the dropdowns use plain labels and translate them to SOUNDS keys here.
local function CreateSettingsPanel()
    local LAM = LibAddonMenu2
    if not LAM then
        return
    end
    local panelId = FA.name .. "Settings"
    LAM:RegisterAddonPanel(panelId, { type = "panel", name = "FishAlert", author = "@Saggy3214", registerForRefresh = true })

    local options = {
        { type = "header", name = "Sounds" },
        { type = "description", text = "Choosing a sound plays a preview." },
    }
    for _, event in ipairs(SOUND_EVENTS) do
        local choices, labelToKey, keyToLabel = {}, {}, {}
        local function AddChoice(key, name)
            local label = key == DEFAULT_SOUNDS[event] and name .. " (default)" or name
            table.insert(choices, label)
            labelToKey[label] = key
            keyToLabel[key] = label
        end
        AddChoice(SOUND_OFF, "Off")
        for _, sound in ipairs(SOUND_LIBRARY) do
            if SOUNDS[sound.key] then
                AddChoice(sound.key, sound.name)
            end
        end
        table.insert(options, {
            type = "dropdown",
            name = SOUND_EVENT_NAMES[event],
            choices = choices,
            scrollable = true,
            getFunc = function() return keyToLabel[savedVars.sounds[event]] or keyToLabel[DEFAULT_SOUNDS[event]] end,
            setFunc = function(label)
                local key = labelToKey[label]
                if key then
                    savedVars.sounds[event] = key
                    PreviewSound(key)
                end
            end,
            width = "half",
        })
        table.insert(options, {
            type = "button",
            name = "Test",
            func = function()
                -- Plays exactly what the event would play, including the fallback for an unavailable choice
                local sound = GetEventSound(event)
                if sound then
                    PlaySound(sound)
                end
            end,
            width = "half",
        })
    end
    table.insert(options, {
        type = "button",
        name = "Restore Default Sounds",
        func = function()
            for _, event in ipairs(SOUND_EVENTS) do
                savedVars.sounds[event] = DEFAULT_SOUNDS[event]
            end
            ZO_ClearTable(warnedSounds)
            d("FishAlert: default sounds restored.")
        end,
        width = "full",
    })

    RegisterResetDialogs()
    table.insert(options, { type = "header", name = "Counter Management" })
    for _, counter in ipairs(RESET_COUNTERS) do
        table.insert(options, {
            type = "button",
            name = "Reset " .. counter.label,
            tooltip = "Reset the " .. counter.label .. " counter to zero without affecting other statistics.",
            -- Only opens the confirmation; the counter changes only from its Confirm button
            func = function() ZO_Dialogs_ShowDialog(counter.dialog) end,
            width = "half",
        })
    end
    LAM:RegisterOptionControls(panelId, options)
end

local function OnBackpackChanged()
    fishToFilletStale = true
end

-- Chat isn't ready during add-on load, so report the loaded totals once the player is in the world
local function OnPlayerActivated()
    EVENT_MANAGER:UnregisterForEvent(FA.name, EVENT_PLAYER_ACTIVATED)
    fishToFilletStale = true    -- the inventory is fully loaded now, after login, character switch or /reloadui
    if savedVars.debugLoot then
        d(string.format("FishAlert: loaded totals - Fish Caught %d, Rare Fish %d", savedVars.fishCaught, savedVars.rareCaught))
    end
end

local function OnAddOnLoaded(event, addonName)
    if addonName ~= FA.name then return end
    EVENT_MANAGER:UnregisterForEvent(FA.name, EVENT_ADD_ON_LOADED)

    -- Defaults only fill in missing keys, so saved totals and position are kept
    savedVars = ZO_SavedVars:NewAccountWide("FishAlertSavedVars", SAVED_VARS_VERSION, nil, SAVED_DEFAULTS)

    CreateAlertWindow()
    CreateCounterWindow()
    UpdateCounterText()
    NormalizeSoundChoices()
    CreateSettingsPanel()
    EVENT_MANAGER:RegisterForEvent(FA.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(FA.name, EVENT_ACHIEVEMENT_UPDATED, OnAchievementUpdated)
    EVENT_MANAGER:RegisterForEvent(FA.name, EVENT_ACHIEVEMENTS_UPDATED, OnAchievementsUpdated)
    EVENT_MANAGER:RegisterForEvent(FA.name, EVENT_ACHIEVEMENT_AWARDED, OnAchievementAwarded)
    EVENT_MANAGER:RegisterForEvent(FA.name, EVENT_VIBRATION, OnVibration)
    EVENT_MANAGER:RegisterForEvent(FA.name, EVENT_LOOT_RECEIVED, OnLootReceived)
    EVENT_MANAGER:RegisterForEvent(FA.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnBackpackChanged)
    EVENT_MANAGER:AddFilterForEvent(FA.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
    EVENT_MANAGER:RegisterForEvent(FA.name, EVENT_INVENTORY_FULL_UPDATE, OnBackpackChanged)
    EVENT_MANAGER:RegisterForUpdate(FA.name, POLL_MS, UpdateFishingState)

    -- Type /fishalert help in chat for the list of commands
    SLASH_COMMANDS["/fishalert"] = OnSlashCommand
end

EVENT_MANAGER:RegisterForEvent(FA.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
