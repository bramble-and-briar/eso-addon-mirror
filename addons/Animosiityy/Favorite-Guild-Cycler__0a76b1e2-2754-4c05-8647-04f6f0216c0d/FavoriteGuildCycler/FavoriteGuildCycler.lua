--[[
    Favorite Guild Cycler (PS5 / Console & Gamepad Edition)
    Version: 1.4.0
    Author: Animosity (Guild: CRY)
    Credits: Created by Animosity with special credit to the guild CRY.
    Description:
        Automatically cycles the player's displayed / represented guild underneath
        their character nameplate across selected favorite guilds (Slots 1-5).
        - Smooth, zero-scroll-reset PS5 Character Sheet (GAMEPAD_STATS) integration:
          uses persistent pre-commit row injection, in-place RefreshVisible() updates,
          isolated keybind handling, and automatic Character Sheet pause so respeccing
          attributes and inspecting buffs/active effects is completely seamless.
        - Enforces a strict minimum 1-second interval to respect ESO's represented-guild API limit.
        - Persists favorite guild identities (guild IDs), not just changeable guild-slot numbers.
        - 5 Rotation Modes: Sequential, Reverse, True Shuffle Bag (No Repeat), Priority Bias (50% Primary),
          and Ping-Pong Bounce (1 <-> 5).
        - Context Automation: Quick Guild Pin/Lock, PvP Zone Guild Lock, PvE Dungeon/Trial Guild Lock,
          Group Leader Guild Match, and Smart Pause rules (Character Sheet, Interactions, Combat,
          Menus, Stealth, Dead, Mounted, Player Housing).
        - Full LibHarvensAddonSettings menu under Options -> Add-Ons -> Favorite Guild Cycler.
        - One-word /fgc slash command to toggle ON/OFF immediately.
]]

FavoriteGuildCycler = FavoriteGuildCycler or {}
local FGC = FavoriteGuildCycler

FGC.name = "FavoriteGuildCycler"
FGC.title = "Favorite Guild Cycler"
FGC.author = "Animosity"
FGC.guildCredit = "CRY"
FGC.version = "1.4.0"
FGC.savedVarsVersion = 2

-- Cycle Order Mode Constants
FGC.MODE_SEQUENTIAL = 1
FGC.MODE_REVERSE    = 2
FGC.MODE_RANDOM     = 3
FGC.MODE_PRIORITY   = 4
FGC.MODE_PINGPONG   = 5

local MODE_NAMES = {
    [FGC.MODE_SEQUENTIAL] = "Sequential (1 -> 5)",
    [FGC.MODE_REVERSE]    = "Reverse (5 -> 1)",
    [FGC.MODE_RANDOM]     = "Shuffle Bag (No Repeat)",
    [FGC.MODE_PRIORITY]   = "Priority Bias (Primary 50%)",
    [FGC.MODE_PINGPONG]   = "Ping-Pong Bounce (1 <-> 5)",
}

-- Safe speed presets (in seconds). The represented-guild API should not be called
-- more frequently than once per second, so sub-second cycling is intentionally disabled.
local SPEED_PRESETS = { 1, 2, 3, 4, 5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 300 }

local MIN_ALLOWED_INTERVAL_SECONDS = 1
local MIN_ALLOWED_INTERVAL_MS = 1000
local REPRESENTED_GUILD_API_INTERVAL_MS = 1000
local MAX_GUILD_SLOTS = MAX_GUILDS or 5
local QUICK_DIALOG_NAME = "FGC_CHARACTER_SHEET_QUICK_DIALOG"

-- Runtime State
FGC.isInitialized = false
FGC.isMenuBuilt = false
FGC.isCharSheetHooked = false
FGC.isMainListHooked = false
FGC.isCharacterSheetOpen = false
FGC.isPrimaryKeybindAdded = false
FGC.currentSlotIndex = 0
FGC.lastSecondarySlotIndex = 0
FGC.pingPongDirection = 1
FGC.shuffleBag = {}
FGC.lastDisplayedGuildId = nil
FGC.originalGuildId = nil
FGC.priorityToggleFlip = false
FGC.lastSwitchTimestampMs = 0
FGC.sessionSwitchCount = 0
FGC.inCombat = false
FGC.resolvedSetterName = nil
FGC.resolvedGetterName = nil
FGC.charSheetRows = nil

-- Default Settings Table
local DEFAULT_SETTINGS = {
    enabled = true,
    useCharacterSettings = false,
    onlySelectedGuilds = true,
    favoriteSlots = {
        [1] = true,
        [2] = true,
        [3] = true,
        [4] = false,
        [5] = false,
    },
    -- Persist favorites against actual guild IDs so changes in slot order do not
    -- silently cause the addon to favorite a different guild after a reload.
    favoriteGuilds = {},
    cycleIntervalSeconds = 5,
    useSubSecondSpeed = false, -- Legacy key retained for compatibility with v1 saved variables.
    cycleMode = FGC.MODE_SEQUENTIAL,
    primaryGuildSlot = 1,
    pinnedGuildSlot = 0,       -- 0 = Off, 1..5 = Temporarily pin/lock a single guild slot
    includeUnrepresentedStep = false,

    -- Combat & Smart Pause Settings
    pauseInCharacterSheet = true,  -- Pauses background switching while viewing Character Sheet so attributes/buffs never jump
    pauseInInteractions = true,    -- Pauses while interacting with crafting stations, bankers, merchants, or shrines
    pauseInCombat = false,         -- Active in combat by default; optional toggle to pause
    pauseInMenus = false,
    pauseInStealth = false,
    pauseWhenDead = true,
    pauseInHousing = false,
    pauseWhenMounted = false,

    -- Character Sheet Integration
    showInCharacterSheet = true,

    -- Zone, Instance & Group Context Automation
    pvpOverrideSlot = 0,           -- 0 = Disabled, 1..5 = Force specific guild slot in Cyrodiil/IC/BGs
    pveInstanceOverrideSlot = 0,   -- 0 = Disabled, 1..5 = Force specific guild slot in Dungeons/Trials/Arenas
    matchGroupLeaderGuild = false, -- Represent shared favorite guild with current Group Leader

    -- Fallback & Restoration
    restoreOnDisable = true,
    fallbackGuildSlot = 1,         -- 0 = Clear/None, 1..5 = Specific guild slot when stopped

    -- Optional Physical Tabard Sync (Appearance Slot)
    syncPhysicalTabard = false,
    tabardItemInstanceIds = {
        [1] = nil,
        [2] = nil,
        [3] = nil,
        [4] = nil,
        [5] = nil,
    },

    -- Feedback & Notifications
    chatNotifications = false,
    onScreenNotifications = false,
    showStartupMessage = false,
}

--------------------------------------------------------------------------------
-- Logging & Notification Helpers
--------------------------------------------------------------------------------

local function PrintMessage(msg)
    if CHAT_ROUTER then
        CHAT_ROUTER:AddSystemMessage(string.format("|cEECA2A[Guild Cycler]|r %s", tostring(msg)))
    elseif d then
        d(string.format("|cEECA2A[Guild Cycler]|r %s", tostring(msg)))
    end
end

local function NotifyGuildSwitch(guildName, slotIndex, forceChat)
    if not FGC.db then return end
    local label = guildName and string.format("%s (Guild %d)", guildName, slotIndex) or "No Guild Displayed"

    if FGC.db.chatNotifications or forceChat then
        PrintMessage("Now displaying: |cFFFFFF" .. label .. "|r")
    end

    if FGC.db.onScreenNotifications and ZO_Alert then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, string.format("Displayed Guild: %s", label))
    end
end

--------------------------------------------------------------------------------
-- Speed & Interval Helpers
--------------------------------------------------------------------------------

function FGC:GetEffectiveIntervalMilliseconds()
    if not self.db then return 5000 end
    local sec = tonumber(self.db.cycleIntervalSeconds) or 5
    return math.max(MIN_ALLOWED_INTERVAL_MS, math.floor(sec * 1000 + 0.5))
end

function FGC:GetFormattedSpeedText()
    local ms = self:GetEffectiveIntervalMilliseconds()
    local sec = ms / 1000
    if math.floor(sec) == sec then
        return string.format("%ds", math.floor(sec))
    end
    return string.format("%.2gs", sec)
end

function FGC:SetSpeedSeconds(secondsValue)
    local sec = math.max(MIN_ALLOWED_INTERVAL_SECONDS, tonumber(secondsValue) or 1)
    self.db.useSubSecondSpeed = false
    self.db.cycleIntervalSeconds = sec
    self:StartOrUpdateTimer()
    self:RefreshCharacterSheetRowsInPlace()
end

function FGC:StepCycleSpeedPreset(direction)
    direction = direction or 1
    local currentSec = self:GetEffectiveIntervalMilliseconds() / 1000
    local bestIdx = 1
    for i, val in ipairs(SPEED_PRESETS) do
        if math.abs(val - currentSec) < 0.02 or val >= currentSec then
            bestIdx = i
            break
        end
        bestIdx = i
    end
    local nextIdx = bestIdx + direction
    if nextIdx > #SPEED_PRESETS then
        nextIdx = 1
    elseif nextIdx < 1 then
        nextIdx = #SPEED_PRESETS
    end
    local chosenSec = SPEED_PRESETS[nextIdx]
    self:SetSpeedSeconds(chosenSec)
    return chosenSec
end

--------------------------------------------------------------------------------
-- Guild Helper Functions
--------------------------------------------------------------------------------

function FGC:GetGuildDetailsBySlot(slotIndex)
    if not slotIndex or slotIndex < 1 or slotIndex > MAX_GUILD_SLOTS then
        return nil, nil
    end
    local numGuilds = GetNumGuilds and GetNumGuilds() or 0
    if slotIndex > numGuilds then
        return nil, nil
    end
    local guildId = GetGuildId and GetGuildId(slotIndex)
    if not guildId or guildId == 0 then
        return nil, nil
    end
    local guildName = GetGuildName and GetGuildName(guildId) or ("Guild " .. tostring(slotIndex))
    return guildId, guildName
end

function FGC:GetFormattedGuildSlotLabel(slotIndex)
    local guildId, guildName = self:GetGuildDetailsBySlot(slotIndex)
    if guildId and guildName and guildName ~= "" then
        return string.format("Favorite Guild %d (%s)", slotIndex, guildName)
    end
    return string.format("Favorite Guild %d (Empty Slot)", slotIndex)
end

function FGC:GetCurrentlyDisplayedGuildSummary()
    local currentId = self:GetCurrentRepresentedGuildId()
    if not currentId or currentId == 0 then
        return "None"
    end
    local numGuilds = GetNumGuilds and GetNumGuilds() or 0
    for slot = 1, math.min(numGuilds, MAX_GUILD_SLOTS) do
        local gId, gName = self:GetGuildDetailsBySlot(slot)
        if gId == currentId then
            return string.format("%s (Slot %d)", gName or "Guild", slot)
        end
    end
    local fallbackName = GetGuildName and GetGuildName(currentId)
    if fallbackName and fallbackName ~= "" then
        return fallbackName
    end
    return "Guild ID " .. tostring(currentId)
end

-- Favorites are persisted by guild ID; slot numbers are only the current UI order.
function FGC:GetGuildFavoriteKey(guildId)
    if not guildId or guildId == 0 then return nil end
    return tostring(guildId)
end

function FGC:IsSlotFavorite(slotIndex)
    if not self.db or not slotIndex then return false end
    local guildId = GetGuildId and GetGuildId(slotIndex)
    local key = self:GetGuildFavoriteKey(guildId)
    if key and self.db.favoriteGuilds and self.db.favoriteGuilds[key] ~= nil then
        return self.db.favoriteGuilds[key] == true
    end
    return self.db.favoriteSlots and self.db.favoriteSlots[slotIndex] == true or false
end

function FGC:SetSlotFavorite(slotIndex, selected)
    if not self.db or not slotIndex or slotIndex < 1 or slotIndex > MAX_GUILD_SLOTS then return end
    self.db.favoriteSlots = self.db.favoriteSlots or {}
    self.db.favoriteGuilds = self.db.favoriteGuilds or {}
    selected = selected == true
    self.db.favoriteSlots[slotIndex] = selected

    local guildId = GetGuildId and GetGuildId(slotIndex)
    local key = self:GetGuildFavoriteKey(guildId)
    if key then
        self.db.favoriteGuilds[key] = selected
    end
    self.shuffleBag = {}
    self:RefreshCharacterSheetRowsInPlace()
end

function FGC:SetAllGuildFavorites(selected)
    if not self.db then return end
    for slot = 1, MAX_GUILD_SLOTS do
        self:SetSlotFavorite(slot, selected)
    end
end

function FGC:SyncFavoriteSlotsFromGuildIds()
    if not self.db then return end
    self.db.favoriteSlots = self.db.favoriteSlots or {}
    self.db.favoriteGuilds = self.db.favoriteGuilds or {}

    local numGuilds = math.min(GetNumGuilds and GetNumGuilds() or 0, MAX_GUILD_SLOTS)
    if numGuilds == 0 then return end

    local mapHasEntries = next(self.db.favoriteGuilds) ~= nil
    if not mapHasEntries then
        -- One-time migration from v1's slot-only favorites to guild-ID favorites.
        for slot = 1, numGuilds do
            local guildId = GetGuildId(slot)
            local key = self:GetGuildFavoriteKey(guildId)
            if key then
                self.db.favoriteGuilds[key] = self.db.favoriteSlots[slot] == true
            end
        end
    else
        local hasKnownCurrentGuild = false
        for slot = 1, numGuilds do
            local key = self:GetGuildFavoriteKey(GetGuildId(slot))
            if key and self.db.favoriteGuilds[key] ~= nil then
                hasKnownCurrentGuild = true
                break
            end
        end

        for slot = 1, numGuilds do
            local key = self:GetGuildFavoriteKey(GetGuildId(slot))
            if key and self.db.favoriteGuilds[key] ~= nil then
                self.db.favoriteSlots[slot] = self.db.favoriteGuilds[key] == true
            elseif hasKnownCurrentGuild then
                self.db.favoriteSlots[slot] = false
            else
                self.db.favoriteSlots[slot] = false
            end
        end
    end
    self.shuffleBag = {}
    self:RefreshCharacterSheetRowsInPlace()
end

function FGC:GetActiveFavoriteCount()
    local count = 0
    local numGuilds = GetNumGuilds and GetNumGuilds() or 0
    for slot = 1, math.min(numGuilds, MAX_GUILD_SLOTS) do
        if not self.db.onlySelectedGuilds or self:IsSlotFavorite(slot) then
            count = count + 1
        end
    end
    return count, numGuilds
end

function FGC:ToggleEnabled(silent)
    if not self.db then return false end
    self.db.enabled = not self.db.enabled
    if self.db.enabled then
        self:StartOrUpdateTimer()
        if not self:IsCharacterSheetSceneShowing() then
            self:OnTimerTick()
        end
        if not silent then
            PrintMessage("Guild Cycling |c00FF00ON|r (Every " .. self:GetFormattedSpeedText() .. ").")
        end
    else
        self:StopTimer(true)
        if not silent then
            PrintMessage("Guild Cycling |cFF4444OFF|r.")
        end
    end
    self:RefreshCharacterSheetRowsInPlace()
    if KEYBIND_STRIP and self.charSheetKeybindStripDescriptor and self:IsCharacterSheetSceneShowing() then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.charSheetKeybindStripDescriptor)
    end
    return self.db.enabled
end

-- Checks if the current Group Leader is a member of one of the player's favorited guilds
function FGC:FindSharedGroupLeaderGuildSlot()
    if not IsUnitGrouped or not IsUnitGrouped("player") or not GetGroupLeaderUnitTag then
        return nil
    end
    local leaderTag = GetGroupLeaderUnitTag()
    if not leaderTag or leaderTag == "" or (AreUnitsEqual and AreUnitsEqual("player", leaderTag)) then
        return nil
    end

    local leaderDisplayName = GetUnitDisplayName and GetUnitDisplayName(leaderTag)
    if not leaderDisplayName or leaderDisplayName == "" then
        return nil
    end

    local numGuilds = GetNumGuilds and GetNumGuilds() or 0
    for slot = 1, math.min(numGuilds, MAX_GUILD_SLOTS) do
        if not self.db.onlySelectedGuilds or self:IsSlotFavorite(slot) then
            local guildId = GetGuildId(slot)
            if guildId and guildId ~= 0 and GetGuildMemberIndexFromDisplayName then
                local memberIndex = GetGuildMemberIndexFromDisplayName(guildId, leaderDisplayName)
                if memberIndex and memberIndex > 0 then
                    return slot
                end
            end
        end
    end

    return nil
end

--------------------------------------------------------------------------------
-- ESO Represented Guild API Resolver & Physical Tabard Sync
--------------------------------------------------------------------------------

function FGC:ResolveRepresentationAPI()
    self.resolvedSetterName = type(SetRepresentedGuildId) == "function" and "SetRepresentedGuildId" or nil
    self.resolvedGetterName = type(GetRepresentedGuildId) == "function" and "GetRepresentedGuildId" or nil
end

function FGC:GetCurrentRepresentedGuildId()
    if self.resolvedGetterName and type(_G[self.resolvedGetterName]) == "function" then
        local ok, result = pcall(_G[self.resolvedGetterName])
        if ok and result then
            return result
        end
    end
    return self.lastDisplayedGuildId or 0
end

function FGC:SyncCurrentRepresentedStateFromClient()
    local currentGuildId = self:GetCurrentRepresentedGuildId()
    if currentGuildId and currentGuildId ~= 0 then
        self.lastDisplayedGuildId = currentGuildId
        local numGuilds = GetNumGuilds and GetNumGuilds() or 0
        for slot = 1, math.min(numGuilds, MAX_GUILD_SLOTS) do
            if GetGuildId and GetGuildId(slot) == currentGuildId then
                self.currentSlotIndex = slot
                break
            end
        end
    elseif currentGuildId == 0 then
        self.lastDisplayedGuildId = 0
        self.currentSlotIndex = 0
    end
end

function FGC:TryEquipRegisteredTabard(slotIndex)
    if not self.db or not self.db.syncPhysicalTabard then return end
    if IsUnitInCombat and IsUnitInCombat("player") then return end

    if not slotIndex or slotIndex == 0 then
        if UnequipItem and EQUIP_SLOT_COSTUME then
            pcall(UnequipItem, EQUIP_SLOT_COSTUME)
        end
        return
    end

    local targetInstanceId = self.db.tabardItemInstanceIds and self.db.tabardItemInstanceIds[slotIndex]
    if not targetInstanceId or not SHARED_INVENTORY then return end

    local backpackCache = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK)
    if not backpackCache then return end

    for _, itemData in ipairs(backpackCache) do
        local itemInstanceId = GetItemInstanceId(BAG_BACKPACK, itemData.slotIndex)
        if itemInstanceId and itemInstanceId == targetInstanceId then
            if EquipItem and EQUIP_SLOT_COSTUME then
                pcall(EquipItem, BAG_BACKPACK, itemData.slotIndex, EQUIP_SLOT_COSTUME)
            end
            return
        end
    end
end

function FGC:RegisterEquippedTabardToSlot(slotIndex)
    if not EQUIP_SLOT_COSTUME or not GetItemInstanceId then return false end
    local instanceId = GetItemInstanceId(BAG_WORN, EQUIP_SLOT_COSTUME)
    if not instanceId or instanceId == 0 then
        PrintMessage("No tabard is currently equipped in your Appearance/Costume slot.")
        return false
    end
    self.db.tabardItemInstanceIds[slotIndex] = instanceId
    local itemName = GetItemName(BAG_WORN, EQUIP_SLOT_COSTUME) or "Guild Tabard"
    local _, guildName = self:GetGuildDetailsBySlot(slotIndex)
    PrintMessage(string.format("Registered '%s' to Guild %d (%s).", itemName, slotIndex, guildName or "Empty"))
    return true
end

-- Applies the selected guild representation, with a strict one-second API safety guard.
function FGC:ApplyGuildRepresentation(slotIndex, isSilent, forceChatNotify)
    local guildId, guildName = nil, nil
    if slotIndex and slotIndex >= 1 and slotIndex <= MAX_GUILD_SLOTS then
        guildId, guildName = self:GetGuildDetailsBySlot(slotIndex)
        if not guildId then
            return false
        end
    else
        slotIndex = 0
        guildId = 0
    end

    if self.lastDisplayedGuildId == guildId then
        self.currentSlotIndex = slotIndex
        if forceChatNotify and not isSilent then
            NotifyGuildSwitch(guildName, slotIndex, true)
        end
        return true
    end

    local nowMs = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
    if nowMs > 0 and self.lastSwitchTimestampMs > 0 then
        local elapsed = nowMs - self.lastSwitchTimestampMs
        if elapsed < REPRESENTED_GUILD_API_INTERVAL_MS then
            return false, REPRESENTED_GUILD_API_INTERVAL_MS - elapsed
        end
    end

    -- Call exactly one supported setter path. Never call GAMEPAD_STATS:SetRepresentedGuildId
    -- while the Character Sheet is open, as that can trigger a list rebuild.
    local requestSucceeded = false
    if self.resolvedSetterName and type(_G[self.resolvedSetterName]) == "function" then
        local ok = pcall(_G[self.resolvedSetterName], guildId)
        requestSucceeded = ok
    elseif GAMEPAD_STATS and type(GAMEPAD_STATS.SetRepresentedGuildId) == "function" and not self:IsCharacterSheetSceneShowing() then
        local ok = pcall(function() GAMEPAD_STATS:SetRepresentedGuildId(guildId) end)
        requestSucceeded = ok
    else
        if not self.warnedMissingRepresentationApi then
            self.warnedMissingRepresentationApi = true
            PrintMessage("This ESO client does not expose SetRepresentedGuildId, so guild switching is unavailable.")
        end
        return false
    end

    if not requestSucceeded then
        if not self.warnedRepresentationApiError then
            self.warnedRepresentationApiError = true
            PrintMessage("ESO rejected a represented-guild change. Cycling has been left unchanged; check add-on compatibility after game updates.")
        end
        return false
    end

    -- Optional physical tabard sync is separate from the nameplate guild API.
    if self.db and self.db.syncPhysicalTabard then
        self:TryEquipRegisteredTabard(slotIndex)
    end

    self.lastDisplayedGuildId = guildId
    self.currentSlotIndex = slotIndex
    self.lastSwitchTimestampMs = nowMs
    self.sessionSwitchCount = (self.sessionSwitchCount or 0) + 1

    if not isSilent then
        NotifyGuildSwitch(guildName, slotIndex, forceChatNotify)
    end

    return true
end

--------------------------------------------------------------------------------
-- Active Candidate Pool & Smart Pause Evaluation
--------------------------------------------------------------------------------

function FGC:IsCharacterSheetSceneShowing()
    if self.isCharacterSheetOpen then
        return true
    end
    if SCENE_MANAGER and SCENE_MANAGER.IsShowing then
        if SCENE_MANAGER:IsShowing("gamepad_stats_root") then
            return true
        end
    end
    return false
end

function FGC:GetEligibleGuildSlots()
    local slots = {}
    local numGuilds = GetNumGuilds and GetNumGuilds() or 0

    for slot = 1, math.min(numGuilds, MAX_GUILD_SLOTS) do
        local guildId = GetGuildId and GetGuildId(slot)
        if guildId and guildId ~= 0 then
            if not self.db.onlySelectedGuilds or self:IsSlotFavorite(slot) then
                table.insert(slots, slot)
            end
        end
    end

    if self.db.includeUnrepresentedStep and #slots > 0 then
        table.insert(slots, 0)
    end

    return slots
end

function FGC:ShouldPauseCycling()
    if not self.db or not self.db.enabled then
        return true, "Disabled"
    end

    -- Prevent background guild switches while inside the Character Sheet so attribute
    -- respec spinners, active effect/buff inspection, and dropdowns never jump or reset.
    if self.db.pauseInCharacterSheet ~= false and self:IsCharacterSheetSceneShowing() then
        return true, "In Character Sheet"
    end

    if self.db.pauseInCombat and (self.inCombat or (IsUnitInCombat and IsUnitInCombat("player"))) then
        return true, "In Combat"
    end

    if self.db.pauseWhenDead and IsUnitDead and IsUnitDead("player") then
        return true, "Player Dead"
    end

    if self.db.pauseInStealth and GetUnitStealthState and STEALTH_STATE_NONE then
        if GetUnitStealthState("player") ~= STEALTH_STATE_NONE then
            return true, "In Stealth"
        end
    end

    if self.db.pauseWhenMounted and IsMounted and IsMounted() then
        return true, "Mounted"
    end

    if self.db.pauseInInteractions and GetInteractionType and INTERACTION_NONE then
        local interactionType = GetInteractionType()
        if interactionType and interactionType ~= INTERACTION_NONE then
            return true, "In World Interaction"
        end
    end

    if self.db.pauseInMenus and SCENE_MANAGER and SCENE_MANAGER.GetCurrentScene then
        local currentScene = SCENE_MANAGER:GetCurrentScene()
        local sceneName = currentScene and currentScene.GetName and currentScene:GetName()
        if sceneName and sceneName ~= "hud" and sceneName ~= "hudui" then
            return true, "In Menu (" .. tostring(sceneName) .. ")"
        end
    end

    if self.db.pauseInHousing and GetCurrentZoneHouseId then
        if GetCurrentZoneHouseId() ~= 0 then
            return true, "Inside Player Housing"
        end
    end

    return false, nil
end

function FGC:GetContextualOverrideSlot()
    if not self.db then return nil, nil end

    -- 1. Quick Pinned Guild Override
    if self.db.pinnedGuildSlot and self.db.pinnedGuildSlot > 0 then
        local guildId = self:GetGuildDetailsBySlot(self.db.pinnedGuildSlot)
        if guildId then
            return self.db.pinnedGuildSlot, "Pinned Guild Lock"
        end
    end

    -- 2. PvP Zone Override (Cyrodiil / Imperial City / Battlegrounds)
    if self.db.pvpOverrideSlot and self.db.pvpOverrideSlot > 0 then
        local inPvP = (IsPlayerInAvAWorld and IsPlayerInAvAWorld()) or (IsActiveWorldBattleground and IsActiveWorldBattleground())
        if inPvP then
            local guildId = self:GetGuildDetailsBySlot(self.db.pvpOverrideSlot)
            if guildId then
                return self.db.pvpOverrideSlot, "PvP Zone Override"
            end
        end
    end

    -- 3. PvE Dungeon / Trial / Arena Instance Override
    if self.db.pveInstanceOverrideSlot and self.db.pveInstanceOverrideSlot > 0 then
        local inPvP = (IsPlayerInAvAWorld and IsPlayerInAvAWorld()) or (IsActiveWorldBattleground and IsActiveWorldBattleground())
        local inDungeonOrTrial = IsUnitInDungeon and IsUnitInDungeon("player")
        if not inPvP and inDungeonOrTrial then
            local guildId = self:GetGuildDetailsBySlot(self.db.pveInstanceOverrideSlot)
            if guildId then
                return self.db.pveInstanceOverrideSlot, "Dungeon/Trial Override"
            end
        end
    end

    -- 4. Group Leader Shared Guild Match
    if self.db.matchGroupLeaderGuild then
        local sharedSlot = self:FindSharedGroupLeaderGuildSlot()
        if sharedSlot then
            return sharedSlot, "Group Leader Shared Guild"
        end
    end

    return nil, nil
end

--------------------------------------------------------------------------------
-- Core Cycle Step Logic (All 5 Modes: Seq, Rev, Shuffle Bag, Priority, Ping-Pong)
--------------------------------------------------------------------------------

function FGC:RefillShuffleBag(eligibleSlots)
    self.shuffleBag = {}
    for _, slot in ipairs(eligibleSlots) do
        table.insert(self.shuffleBag, slot)
    end
    -- Fisher-Yates shuffle
    for i = #self.shuffleBag, 2, -1 do
        local j = math.random(1, i)
        self.shuffleBag[i], self.shuffleBag[j] = self.shuffleBag[j], self.shuffleBag[i]
    end
    -- Prevent boundary repeat where the first item pulled (from the end of the bag)
    -- matches the currently displayed slot.
    if #self.shuffleBag > 1 and self.shuffleBag[#self.shuffleBag] == self.currentSlotIndex then
        local swapIdx = math.random(1, #self.shuffleBag - 1)
        self.shuffleBag[#self.shuffleBag], self.shuffleBag[swapIdx] = self.shuffleBag[swapIdx], self.shuffleBag[#self.shuffleBag]
    end
end

function FGC:SelectNextSlot(eligibleSlots)
    local count = #eligibleSlots
    if count == 0 then return nil end
    if count == 1 then return eligibleSlots[1] end

    local mode = self.db.cycleMode or FGC.MODE_SEQUENTIAL

    -- Mode 4: Priority Bias (Primary Guild gets 50% display time, while rotating
    -- evenly across ALL other eligible guilds using lastSecondarySlotIndex).
    if mode == FGC.MODE_PRIORITY then
        local primarySlot = self.db.primaryGuildSlot or 1
        local primaryId = self:GetGuildDetailsBySlot(primarySlot)
        local secondarySlots = {}
        for _, slot in ipairs(eligibleSlots) do
            if slot ~= primarySlot then
                table.insert(secondarySlots, slot)
            end
        end

        if primaryId and #secondarySlots > 0 then
            self.priorityToggleFlip = not self.priorityToggleFlip
            if self.priorityToggleFlip and self.currentSlotIndex ~= primarySlot then
                return primarySlot
            end

            local secPos = nil
            for i, slot in ipairs(secondarySlots) do
                if slot == self.lastSecondarySlotIndex then
                    secPos = i
                    break
                end
            end
            local nextSecPos = (not secPos or secPos >= #secondarySlots) and 1 or (secPos + 1)
            local chosenSecondary = secondarySlots[nextSecPos]
            self.lastSecondarySlotIndex = chosenSecondary
            return chosenSecondary
        end
    end

    -- Mode 3: True Shuffle Bag (every favorite guild shown once per bag in random order, no immediate repeat)
    if mode == FGC.MODE_RANDOM then
        local validSet = {}
        for _, slot in ipairs(eligibleSlots) do
            validSet[slot] = true
        end
        -- Prune any stale entries from shuffleBag
        for i = #self.shuffleBag, 1, -1 do
            if not validSet[self.shuffleBag[i]] then
                table.remove(self.shuffleBag, i)
            end
        end
        if #self.shuffleBag == 0 then
            self:RefillShuffleBag(eligibleSlots)
        end
        local pick = table.remove(self.shuffleBag)
        if pick == self.currentSlotIndex and #self.shuffleBag > 0 then
            local alt = table.remove(self.shuffleBag)
            table.insert(self.shuffleBag, 1, pick)
            pick = alt
        end
        return pick or eligibleSlots[1]
    end

    -- Locate current position in eligibleSlots for Sequential, Reverse, and Ping-Pong
    local currentPos = nil
    for i, slot in ipairs(eligibleSlots) do
        if slot == self.currentSlotIndex then
            currentPos = i
            break
        end
    end

    -- Mode 5: Ping-Pong Bounce (1 -> 2 -> 3 -> 2 -> 1)
    if mode == FGC.MODE_PINGPONG then
        if not currentPos then
            self.pingPongDirection = 1
            return eligibleSlots[1]
        end
        local dir = self.pingPongDirection or 1
        local nextPos = currentPos + dir
        if nextPos > count then
            self.pingPongDirection = -1
            nextPos = math.max(1, count - 1)
        elseif nextPos < 1 then
            self.pingPongDirection = 1
            nextPos = math.min(count, 2)
        end
        return eligibleSlots[nextPos]
    end

    -- Mode 2: Reverse (5 -> 1)
    if mode == FGC.MODE_REVERSE then
        if not currentPos or currentPos <= 1 then
            return eligibleSlots[count]
        else
            return eligibleSlots[currentPos - 1]
        end
    end

    -- Mode 1: Sequential (1 -> 5)
    if not currentPos or currentPos >= count then
        return eligibleSlots[1]
    else
        return eligibleSlots[currentPos + 1]
    end
end

function FGC:OnTimerTick()
    local isPaused, _ = self:ShouldPauseCycling()
    if isPaused then
        return
    end

    local overrideSlot, _ = self:GetContextualOverrideSlot()
    if overrideSlot then
        self:ApplyGuildRepresentation(overrideSlot, false, false)
        return
    end

    local eligibleSlots = self:GetEligibleGuildSlots()
    if #eligibleSlots == 0 then
        return
    end

    local nextSlot = self:SelectNextSlot(eligibleSlots)
    if nextSlot ~= nil then
        self:ApplyGuildRepresentation(nextSlot, false, false)
    end
end

function FGC:ForceNextGuild()
    local eligibleSlots = self:GetEligibleGuildSlots()
    if #eligibleSlots == 0 then
        PrintMessage("No eligible guilds selected! Enable at least one guild in your Character Sheet or Add-On Settings.")
        return
    end
    local nextSlot = self:SelectNextSlot(eligibleSlots)
    if nextSlot == nil then return end

    local ok, waitMs = self:ApplyGuildRepresentation(nextSlot, false, true)
    if not ok and waitMs and waitMs > 0 and zo_callLater then
        -- Queue the manual switch for the exact moment the 1-second API cooldown expires
        if self.pendingForceNextCall then return end
        self.pendingForceNextCall = true
        zo_callLater(function()
            self.pendingForceNextCall = false
            self:ApplyGuildRepresentation(nextSlot, false, true)
            self:RefreshCharacterSheetRowsInPlace()
        end, waitMs + 15)
    else
        self:RefreshCharacterSheetRowsInPlace()
    end
end

--------------------------------------------------------------------------------
-- Timer Management (EVENT_MANAGER)
--------------------------------------------------------------------------------

function FGC:StartOrUpdateTimer()
    EVENT_MANAGER:UnregisterForUpdate(self.name .. "_CycleTimer")

    if not self.db or not self.db.enabled then
        return
    end

    if not self.originalGuildId then
        self.originalGuildId = self:GetCurrentRepresentedGuildId()
    end

    local intervalMs = self:GetEffectiveIntervalMilliseconds()

    EVENT_MANAGER:RegisterForUpdate(self.name .. "_CycleTimer", intervalMs, function()
        self:OnTimerTick()
    end)
end

function FGC:StopTimer(restoreFallback)
    EVENT_MANAGER:UnregisterForUpdate(self.name .. "_CycleTimer")

    if not (restoreFallback and self.db and self.db.restoreOnDisable) then
        return
    end

    local fallbackSlot = self.db.fallbackGuildSlot or 1
    local function applyFallback()
        if not self.db or self.db.enabled then return end
        if fallbackSlot >= 1 and fallbackSlot <= MAX_GUILD_SLOTS then
            self:ApplyGuildRepresentation(fallbackSlot, true, false)
        elseif fallbackSlot == 0 then
            self:ApplyGuildRepresentation(0, true, false)
        end
    end

    local nowMs = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
    if nowMs > 0 and self.lastSwitchTimestampMs > 0 and zo_callLater then
        local elapsed = nowMs - self.lastSwitchTimestampMs
        local remaining = REPRESENTED_GUILD_API_INTERVAL_MS - elapsed
        if remaining > 0 then
            zo_callLater(applyFallback, remaining + 10)
            return
        end
    end

    applyFallback()
end

--------------------------------------------------------------------------------
-- SavedVariables Management (Account-Wide vs. Per-Character)
--------------------------------------------------------------------------------

function FGC:LoadSavedVariables()
    self.accountVars = ZO_SavedVars:NewAccountWide(
        "FavoriteGuildCycler_SavedVars",
        self.savedVarsVersion,
        nil,
        DEFAULT_SETTINGS,
        GetWorldName()
    )

    self.characterVars = ZO_SavedVars:NewCharacterIdSettings(
        "FavoriteGuildCycler_SavedVars",
        self.savedVarsVersion,
        nil,
        DEFAULT_SETTINGS,
        GetWorldName()
    )

    if self.characterVars.useCharacterSettings then
        self.db = self.characterVars
    else
        self.db = self.accountVars
    end

    self.db.useSubSecondSpeed = false
    self.db.cycleIntervalSeconds = math.max(1, tonumber(self.db.cycleIntervalSeconds) or 5)
    self.db.favoriteGuilds = self.db.favoriteGuilds or {}
    self.db.favoriteSlots = self.db.favoriteSlots or ZO_ShallowTableCopy(DEFAULT_SETTINGS.favoriteSlots)
    if self.db.pauseInCharacterSheet == nil then
        self.db.pauseInCharacterSheet = true
    end
    if self.db.pauseInInteractions == nil then
        self.db.pauseInInteractions = true
    end
    self.db.pinnedGuildSlot = tonumber(self.db.pinnedGuildSlot) or 0
    self.db.pveInstanceOverrideSlot = tonumber(self.db.pveInstanceOverrideSlot) or 0
end

function FGC:SetUseCharacterSettings(useChar)
    self.characterVars.useCharacterSettings = useChar
    self.accountVars.useCharacterSettings = useChar
    if useChar then
        self.db = self.characterVars
    else
        self.db = self.accountVars
    end
    self.db.useSubSecondSpeed = false
    self.db.cycleIntervalSeconds = math.max(1, tonumber(self.db.cycleIntervalSeconds) or 5)
    self:SyncFavoriteSlotsFromGuildIds()
    self:StartOrUpdateTimer()
end

--------------------------------------------------------------------------------
-- PS5 Character Sheet Quick-Cycler Dialog & Zero-Scroll-Reset Integration
--------------------------------------------------------------------------------

-- Helper to refresh the Parametric Quick Dialog in place while keeping the
-- user's cursor on the exact row they had highlighted.
function FGC:RefreshQuickDialog(dialog)
    if not dialog or not dialog.setupFunc then return end
    local prevIndex = dialog.entryList and dialog.entryList.GetSelectedIndex and dialog.entryList:GetSelectedIndex() or 1
    dialog.info.parametricList = self:BuildParametricQuickDialogEntries()
    dialog:setupFunc()
    if dialog.entryList and prevIndex and prevIndex > 1 then
        local numEntries = dialog.entryList.GetNumEntries and dialog.entryList:GetNumEntries() or 1
        local targetIndex = math.min(prevIndex, math.max(1, numEntries))
        if dialog.entryList.SetSelectedIndexWithoutAnimation then
            dialog.entryList:SetSelectedIndexWithoutAnimation(targetIndex, true, false)
        end
    end
    self:RefreshCharacterSheetRowsInPlace()
end

function FGC:BuildParametricQuickDialogEntries()
    local entries = {}
    if not ZO_GamepadEntryData then return entries end

    -- 1. Master ON / OFF Toggle Row
    local statusText = self.db.enabled and "|c00FF00ON|r" or "|cFF4444OFF|r"
    local toggleEntry = ZO_GamepadEntryData:New(string.format("Guild Cycler: %s", statusText))
    toggleEntry:AddSubLabel(string.format("Displaying: %s | Press X to toggle ON or OFF", self:GetCurrentlyDisplayedGuildSummary()))
    toggleEntry.onSelect = function(dialog)
        self:ToggleEnabled(true)
        self:RefreshQuickDialog(dialog)
    end
    table.insert(entries, {
        template = "ZO_GamepadMenuEntryTemplate",
        entryData = toggleEntry,
    })

    -- 2. Cycle Speed Row (minimum one second to respect ESO's API rate limit)
    local speedEntry = ZO_GamepadEntryData:New(string.format("Cycle Speed: |cEECA2A%s|r", self:GetFormattedSpeedText()))
    speedEntry:AddSubLabel("Press X to step through safe speeds (1s, 2s, 3s, 4s, 5s, 10s, 15s, 20s, 30s, 45s, 60s...)")
    speedEntry.onSelect = function(dialog)
        self:StepCycleSpeedPreset(1)
        self:RefreshQuickDialog(dialog)
    end
    table.insert(entries, {
        template = "ZO_GamepadMenuEntryTemplate",
        entryData = speedEntry,
    })

    -- 3. Cycle Order Mode Row (All 5 Modes)
    local modeLabel = MODE_NAMES[self.db.cycleMode] or MODE_NAMES[FGC.MODE_SEQUENTIAL]
    local modeEntry = ZO_GamepadEntryData:New(string.format("Rotation Order: |cFFFFFF%s|r", modeLabel))
    modeEntry:AddSubLabel("Press X to cycle: Sequential, Reverse, Shuffle Bag, Priority Bias, or Ping-Pong")
    modeEntry.onSelect = function(dialog)
        local nextMode = (self.db.cycleMode % 5) + 1
        self.db.cycleMode = nextMode
        self.shuffleBag = {}
        self:RefreshQuickDialog(dialog)
    end
    table.insert(entries, {
        template = "ZO_GamepadMenuEntryTemplate",
        entryData = modeEntry,
    })

    -- 4. Quick Pin / Lock Guild Slot Row
    local pinnedSlot = tonumber(self.db.pinnedGuildSlot) or 0
    local pinLabel = "Off (Normal Rotation)"
    if pinnedSlot >= 1 and pinnedSlot <= MAX_GUILD_SLOTS then
        local _, gName = self:GetGuildDetailsBySlot(pinnedSlot)
        pinLabel = string.format("|c00FFFFPinned to Guild %d (%s)|r", pinnedSlot, gName or "Empty")
    end
    local pinEntry = ZO_GamepadEntryData:New(string.format("Pin Single Guild: %s", pinLabel))
    pinEntry:AddSubLabel("Temporarily lock one guild without losing your saved favorite checkboxes")
    pinEntry.onSelect = function(dialog)
        local nextPin = (pinnedSlot + 1) % (MAX_GUILD_SLOTS + 1)
        self.db.pinnedGuildSlot = nextPin
        if nextPin > 0 then
            self:ApplyGuildRepresentation(nextPin, false, false)
        end
        self:RefreshQuickDialog(dialog)
    end
    table.insert(entries, {
        template = "ZO_GamepadMenuEntryTemplate",
        entryData = pinEntry,
    })

    -- 5. Immediate Next Guild Switch Row
    local switchNowEntry = ZO_GamepadEntryData:New("Switch to Next Favorite Guild Now")
    switchNowEntry:AddSubLabel("Immediately rotate your displayed guild nameplate (respects 1s API guard)")
    switchNowEntry.onSelect = function(dialog)
        self:ForceNextGuild()
        self:RefreshQuickDialog(dialog)
    end
    table.insert(entries, {
        template = "ZO_GamepadMenuEntryTemplate",
        entryData = switchNowEntry,
    })

    -- 6. Filter Mode Toggle (Only Selected Favorites vs. All Joined Guilds)
    local filterText = self.db.onlySelectedGuilds and "|c00FF00Only Selected Favorites|r" or "|cFFFFFFAll Joined Guilds|r"
    local filterEntry = ZO_GamepadEntryData:New(string.format("Guild Filter: %s", filterText))
    filterEntry:AddSubLabel("Press X to switch between cycling only starred favorites below or all joined guilds")
    filterEntry.onSelect = function(dialog)
        self.db.onlySelectedGuilds = not self.db.onlySelectedGuilds
        self.shuffleBag = {}
        self:RefreshQuickDialog(dialog)
    end
    table.insert(entries, {
        template = "ZO_GamepadMenuEntryTemplate",
        entryData = filterEntry,
    })

    -- 7. Individual Favorite Guild Toggle Rows (Guilds 1-5)
    for slot = 1, MAX_GUILD_SLOTS do
        local guildSlot = slot
        local _, gName = self:GetGuildDetailsBySlot(guildSlot)
        local isFav = self:IsSlotFavorite(guildSlot)
        local badge = isFav and "|c00FF00[FAVORITE]|r" or "|c888888[  OFF  ]|r"
        local displayGuild = (gName and gName ~= "") and gName or "(Empty Guild Slot)"
        local guildRow = ZO_GamepadEntryData:New(string.format("%s Guild %d: %s", badge, guildSlot, displayGuild))
        guildRow:AddSubLabel("Press X to include or exclude this guild from your nameplate rotation")
        guildRow.onSelect = function(dialog)
            self:SetSlotFavorite(guildSlot, not self:IsSlotFavorite(guildSlot))
            self.db.onlySelectedGuilds = true
            self:RefreshQuickDialog(dialog)
        end
        table.insert(entries, {
            template = "ZO_GamepadMenuEntryTemplate",
            entryData = guildRow,
        })
    end

    -- 8. Combat Pause Quick Toggle Row
    local combatText = self.db.pauseInCombat and "|cFFAA00Paused in Combat|r" or "|c00FF00Active in Combat (Default)|r"
    local combatEntry = ZO_GamepadEntryData:New(string.format("Combat Behavior: %s", combatText))
    combatEntry:AddSubLabel("Press X to toggle whether guilds keep cycling during combat")
    combatEntry.onSelect = function(dialog)
        self.db.pauseInCombat = not self.db.pauseInCombat
        self:RefreshQuickDialog(dialog)
    end
    table.insert(entries, {
        template = "ZO_GamepadMenuEntryTemplate",
        entryData = combatEntry,
    })

    return entries
end

function FGC:ShowCharacterSheetQuickDialog()
    if not ZO_Dialogs_ShowGamepadDialog then return end
    ZO_Dialogs_ShowGamepadDialog(QUICK_DIALOG_NAME)
end

function FGC:GetSelectedCharacterSheetCyclerRow()
    if not GAMEPAD_STATS or not GAMEPAD_STATS.mainList then return nil end
    if GAMEPAD_STATS.mainList.IsActive and not GAMEPAD_STATS.mainList:IsActive() then
        return nil
    end
    local targetData = GAMEPAD_STATS.mainList:GetTargetData()
    if targetData and targetData.isFavoriteGuildCyclerRow then
        return targetData
    end
    return nil
end

-- Creates and updates persistent ZO_GamepadEntryData instances for the Character Sheet
-- so their table identity never changes across RefreshMainList() calls.
function FGC:EnsurePersistentCharacterSheetRows()
    if not ZO_GamepadEntryData then return nil end

    if not self.charSheetRows then
        local toggleRow = ZO_GamepadEntryData:New("Cycle Favorite Guilds")
        toggleRow:SetHeader("Favorite Guild Cycler (by Animosity / CRY)")
        toggleRow.isFavoriteGuildCyclerRow = true
        toggleRow.fgcRowKey = "toggle"
        toggleRow.fgcActionLabel = "Toggle ON/OFF"
        toggleRow.onCharacterSheetSelect = function()
            self:ToggleEnabled(false)
        end

        local speedRow = ZO_GamepadEntryData:New("Cycle Speed")
        speedRow.isFavoriteGuildCyclerRow = true
        speedRow.fgcRowKey = "speed"
        speedRow.fgcActionLabel = "Change Speed"
        speedRow.onCharacterSheetSelect = function()
            self:StepCycleSpeedPreset(1)
            PrintMessage("Cycle speed set to |cFFFFFF" .. self:GetFormattedSpeedText() .. "|r.")
        end

        local favRow = ZO_GamepadEntryData:New("Favorite Guilds")
        favRow.isFavoriteGuildCyclerRow = true
        favRow.fgcRowKey = "fav"
        favRow.fgcActionLabel = "Manage Guild Cycler"
        favRow.onCharacterSheetSelect = function()
            self:ShowCharacterSheetQuickDialog()
        end

        self.charSheetRows = {
            toggle = toggleRow,
            speed = speedRow,
            fav = favRow,
        }
    end

    local favCount, totalGuilds = self:GetActiveFavoriteCount()
    local stateLabel = (self.db and self.db.enabled) and "|c00FF00ON|r" or "|cFF4444OFF|r"
    local pinnedSlot = self.db and tonumber(self.db.pinnedGuildSlot) or 0
    if pinnedSlot and pinnedSlot > 0 then
        local _, pinnedName = self:GetGuildDetailsBySlot(pinnedSlot)
        stateLabel = string.format("%s |c00FFFF(Pinned: %s)|r", stateLabel, pinnedName or ("Guild " .. pinnedSlot))
    end

    local toggleText = string.format("Cycle Favorite Guilds: %s", stateLabel)
    local modeName = MODE_NAMES[self.db and self.db.cycleMode or FGC.MODE_SEQUENTIAL] or "Sequential"
    local speedText = string.format("Cycle Speed: |cEECA2A%s|r (%s)", self:GetFormattedSpeedText(), modeName)
    local favText = string.format("Favorite Guilds: |c00FF00%d/%d Selected|r (Quick Menu)", favCount, totalGuilds)

    self.charSheetRows.toggle.text = toggleText
    if self.charSheetRows.toggle.SetText then self.charSheetRows.toggle:SetText(toggleText) end

    self.charSheetRows.speed.text = speedText
    if self.charSheetRows.speed.SetText then self.charSheetRows.speed:SetText(speedText) end

    self.charSheetRows.fav.text = favText
    if self.charSheetRows.fav.SetText then self.charSheetRows.fav:SetText(favText) end

    return self.charSheetRows
end

-- Updates the Character Sheet rows in place using RefreshVisible() without clearing
-- or rebuilding GAMEPAD_STATS.mainList, preventing any scroll jump.
function FGC:RefreshCharacterSheetRowsInPlace()
    if not self.db or not self.db.showInCharacterSheet then return end
    self:EnsurePersistentCharacterSheetRows()
    if GAMEPAD_STATS and GAMEPAD_STATS.mainList and self:IsCharacterSheetSceneShowing() then
        if GAMEPAD_STATS.mainList.RefreshVisible then
            pcall(function() GAMEPAD_STATS.mainList:RefreshVisible() end)
        end
    end
    if KEYBIND_STRIP and self.charSheetKeybindStripDescriptor and self:IsCharacterSheetSceneShowing() then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.charSheetKeybindStripDescriptor)
    end
end

function FGC:AppendCharacterSheetRowsToMainList(mainList)
    if not mainList or not self.db or not self.db.showInCharacterSheet then return end
    local rows = self:EnsurePersistentCharacterSheetRows()
    if not rows then return end

    mainList:AddEntryWithHeader("ZO_GamepadMenuEntryTemplate", rows.toggle)
    mainList:AddEntry("ZO_GamepadMenuEntryTemplate", rows.speed)
    mainList:AddEntry("ZO_GamepadMenuEntryTemplate", rows.fav)
end

function FGC:SyncCharacterSheetPrimaryKeybind()
    if not KEYBIND_STRIP or not self.charSheetPrimaryKeybindDescriptor then return end
    local shouldShowPrimary = self:IsCharacterSheetSceneShowing() and (self:GetSelectedCharacterSheetCyclerRow() ~= nil)
    if shouldShowPrimary and not self.isPrimaryKeybindAdded then
        self.isPrimaryKeybindAdded = true
        KEYBIND_STRIP:AddKeybindButtonGroup(self.charSheetPrimaryKeybindDescriptor)
    elseif not shouldShowPrimary and self.isPrimaryKeybindAdded then
        self.isPrimaryKeybindAdded = false
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.charSheetPrimaryKeybindDescriptor)
    elseif shouldShowPrimary and self.isPrimaryKeybindAdded then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.charSheetPrimaryKeybindDescriptor)
    end
end

function FGC:EnsureMainListHooks(statsSelf)
    local mainList = statsSelf and statsSelf.mainList
    if not mainList or mainList._fgcCommitWrapped then return end
    mainList._fgcCommitWrapped = true

    -- Intercept mainList:Commit() during RefreshMainList() so our persistent rows are added
    -- BEFORE ESO's single native Commit() runs, instead of calling CommitWithoutReselect()
    -- after Commit() (which was resetting selection to row 1 at the top of the Character Sheet).
    local origCommit = mainList.Commit
    mainList.Commit = function(listSelf, dontReselect, blockSelectionChangedCallback)
        if statsSelf._fgcPendingPreCommitAppend then
            statsSelf._fgcPendingPreCommitAppend = false
            if self.db and self.db.showInCharacterSheet and not statsSelf._fgcAppendingRows then
                statsSelf._fgcAppendingRows = true
                pcall(function()
                    self:AppendCharacterSheetRowsToMainList(listSelf)
                end)
                statsSelf._fgcAppendingRows = false
            end

            -- Run ESO's single native Commit with dontReselect = false so selection is preserved
            local result = origCommit(listSelf, false, blockSelectionChangedCallback)

            -- Post-Commit Scroll & Selection Guard:
            -- 1. If the user was previously highlighting one of our FGC rows, keep that exact row selected.
            -- 2. If the user was scrolled down (e.g. inspecting Active Effects/Buffs at the bottom of the
            --    Character Sheet) and a buff tick/expiry caused Commit() to fall back to index 1, immediately
            --    restore their previous scroll index without animation.
            local prevIdx = statsSelf._fgcPrevSelectedIndex
            local currentIdx = listSelf.GetSelectedIndex and listSelf:GetSelectedIndex() or 1
            local numEntries = listSelf.GetNumEntries and listSelf:GetNumEntries() or 0

            if statsSelf._fgcWasFgcRow and statsSelf._fgcPrevFgcRowKey and numEntries > 0 then
                local currentData = listSelf.GetTargetData and listSelf:GetTargetData()
                if not (currentData and currentData.fgcRowKey == statsSelf._fgcPrevFgcRowKey) then
                    for i = 1, numEntries do
                        local entryData = listSelf.GetDataForDataIndex and listSelf:GetDataForDataIndex(i)
                        if entryData and entryData.fgcRowKey == statsSelf._fgcPrevFgcRowKey then
                            if listSelf.SetSelectedIndexWithoutAnimation then
                                listSelf:SetSelectedIndexWithoutAnimation(i, true, false)
                            end
                            break
                        end
                    end
                end
            elseif prevIdx and prevIdx > 1 and currentIdx == 1 and numEntries > 1 then
                local restoredIdx = math.min(prevIdx, numEntries)
                if listSelf.SetSelectedIndexWithoutAnimation then
                    listSelf:SetSelectedIndexWithoutAnimation(restoredIdx, true, false)
                end
            end

            return result
        end

        return origCommit(listSelf, dontReselect, blockSelectionChangedCallback)
    end

    if mainList.RegisterCallback then
        mainList:RegisterCallback("TargetDataChanged", function()
            self:SyncCharacterSheetPrimaryKeybind()
            if KEYBIND_STRIP and self.charSheetKeybindStripDescriptor and self:IsCharacterSheetSceneShowing() then
                KEYBIND_STRIP:UpdateKeybindButtonGroup(self.charSheetKeybindStripDescriptor)
            end
        end)
    end
end

function FGC:SetupCharacterSheetIntegration()
    if self.isCharSheetHooked then return end
    self.isCharSheetHooked = true

    -- 1. Register the Native Gamepad Parametric Quick Dialog
    if ZO_Dialogs_RegisterCustomDialog and GAMEPAD_DIALOGS then
        ZO_Dialogs_RegisterCustomDialog(QUICK_DIALOG_NAME, {
            gamepadInfo = {
                dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
                allowShowOnNextScene = true,
            },
            title = {
                text = "Favorite Guild Cycler",
            },
            mainText = {
                text = "Created by Animosity (Guild: CRY). Configure favorite guilds, rotation mode, and speed (1s minimum interval for ESO API rate-limit safety).",
            },
            setup = function(dialog)
                dialog.info.parametricList = self:BuildParametricQuickDialogEntries()
                dialog:setupFunc()
            end,
            parametricList = {},
            buttons = {
                {
                    keybind = "DIALOG_PRIMARY",
                    text = SI_GAMEPAD_SELECT_OPTION,
                    callback = function(dialog)
                        local targetData = dialog.entryList and dialog.entryList:GetTargetData()
                        if targetData and targetData.onSelect then
                            targetData.onSelect(dialog)
                        end
                    end,
                },
                {
                    keybind = "DIALOG_SECONDARY",
                    text = "Quick Toggle ON/OFF",
                    callback = function(dialog)
                        self:ToggleEnabled(false)
                        self:RefreshQuickDialog(dialog)
                    end,
                },
                {
                    keybind = "DIALOG_RESET",
                    text = "Step Speed",
                    callback = function(dialog)
                        self:StepCycleSpeedPreset(1)
                        self:RefreshQuickDialog(dialog)
                    end,
                },
                {
                    keybind = "DIALOG_NEGATIVE",
                    text = SI_DIALOG_CLOSE,
                },
            },
        })
    end

    -- 2. Wrap GAMEPAD_STATS:RefreshMainList for Pre-Commit Row Injection & Scroll Preservation
    if GAMEPAD_STATS and type(GAMEPAD_STATS.RefreshMainList) == "function" then
        local origRefreshMainList = GAMEPAD_STATS.RefreshMainList
        GAMEPAD_STATS.RefreshMainList = function(statsSelf, ...)
            self:EnsureMainListHooks(statsSelf)

            local mainList = statsSelf and statsSelf.mainList
            if mainList and self.db and self.db.showInCharacterSheet and ZO_GamepadEntryData then
                local prevSelectedIndex = mainList.GetSelectedIndex and mainList:GetSelectedIndex() or nil
                local prevTargetData = mainList.GetTargetData and mainList:GetTargetData() or nil

                statsSelf._fgcPrevSelectedIndex = prevSelectedIndex
                statsSelf._fgcWasFgcRow = (prevTargetData and prevTargetData.isFavoriteGuildCyclerRow) == true
                statsSelf._fgcPrevFgcRowKey = prevTargetData and prevTargetData.fgcRowKey or nil
                statsSelf._fgcPendingPreCommitAppend = true
            else
                if statsSelf then
                    statsSelf._fgcPendingPreCommitAppend = false
                end
            end

            local ok, result = pcall(origRefreshMainList, statsSelf, ...)
            if statsSelf then
                statsSelf._fgcPendingPreCommitAppend = false
            end
            self:SyncCharacterSheetPrimaryKeybind()
            if ok then
                return result
            end
        end
    end

    -- 3. Separate Primary Keybind (only active when highlighting an FGC row so it never
    --    collides with GAMEPAD_STATS's native X button on Attributes, Outfit, Title, or Guild)
    self.charSheetPrimaryKeybindDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_CENTER,
        {
            name = function()
                local row = self:GetSelectedCharacterSheetCyclerRow()
                return (row and row.fgcActionLabel) or "Select"
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function()
                local row = self:GetSelectedCharacterSheetCyclerRow()
                if row and row.onCharacterSheetSelect then
                    row.onCharacterSheetSelect()
                end
            end,
        },
    }

    -- Secondary/Tertiary Keybind Strip Shortcuts on the Character Sheet
    self.charSheetKeybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_CENTER,
        {
            name = function()
                local status = (self.db and self.db.enabled) and "|c00FF00ON|r" or "|cFF4444OFF|r"
                return string.format("Guild Cycler (%s / %s)", status, self:GetFormattedSpeedText())
            end,
            keybind = "UI_SHORTCUT_TERTIARY",
            callback = function()
                self:ShowCharacterSheetQuickDialog()
            end,
        },
        {
            name = "Toggle Guild Cycler",
            keybind = "UI_SHORTCUT_QUATERNARY",
            callback = function()
                self:ToggleEnabled(false)
            end,
        },
    }

    local function AttachKeybindsToCharacterSheetScene(sceneName)
        if not SCENE_MANAGER then return end
        local scene = SCENE_MANAGER:GetScene(sceneName)
        if scene then
            scene:RegisterCallback("StateChange", function(oldState, newState)
                if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
                    self.isCharacterSheetOpen = true
                    if GAMEPAD_STATS then
                        self:EnsureMainListHooks(GAMEPAD_STATS)
                    end
                    if newState == SCENE_SHOWN and KEYBIND_STRIP then
                        KEYBIND_STRIP:AddKeybindButtonGroup(self.charSheetKeybindStripDescriptor)
                        self:SyncCharacterSheetPrimaryKeybind()
                    end
                elseif newState == SCENE_HIDING or newState == SCENE_HIDDEN then
                    if newState == SCENE_HIDING and KEYBIND_STRIP then
                        if self.isPrimaryKeybindAdded then
                            self.isPrimaryKeybindAdded = false
                            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.charSheetPrimaryKeybindDescriptor)
                        end
                        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.charSheetKeybindStripDescriptor)
                    end
                    if newState == SCENE_HIDDEN then
                        self.isCharacterSheetOpen = false
                        -- Sync in case the player manually changed their guild via ESO's native dropdown
                        self:SyncCurrentRepresentedStateFromClient()
                    end
                end
            end)
        end
    end

    AttachKeybindsToCharacterSheetScene("gamepad_stats_root")
end

--------------------------------------------------------------------------------
-- PS5 / Console Controller Settings Menu (LibHarvensAddonSettings)
--------------------------------------------------------------------------------

function FGC:BuildGamepadSettingsMenu()
    if self.isMenuBuilt or not LibHarvensAddonSettings then
        return
    end
    self.isMenuBuilt = true

    local LHAS = LibHarvensAddonSettings
    local options = {
        allowDefaults = true,
        allowRefresh = true,
        defaultsFunction = function()
            for k, v in pairs(DEFAULT_SETTINGS) do
                if type(v) == "table" then
                    self.db[k] = ZO_ShallowTableCopy(v)
                else
                    self.db[k] = v
                end
            end
            self:SyncFavoriteSlotsFromGuildIds()
            self:StartOrUpdateTimer()
        end,
    }

    local panel = LHAS:AddAddon(self.title, options)
    if not panel then return end
    self.settingsPanel = panel

    -- SECTION 1: Easy ON/OFF & Cycle Speed
    panel:AddSetting({
        type = LHAS.ST_SECTION,
        label = "Quick Controls & Cycle Speed (by Animosity / CRY)",
    })

    panel:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Enable Guild Cycler (Master ON/OFF)",
        tooltip = "Turn automatic guild nameplate cycling ON or OFF. Created by Animosity & Guild CRY. Toggle anytime in your Character Sheet or by typing /fgc in chat.",
        default = DEFAULT_SETTINGS.enabled,
        getFunction = function() return self.db.enabled end,
        setFunction = function(state)
            self.db.enabled = state
            if state then
                self:StartOrUpdateTimer()
                if not self:IsCharacterSheetSceneShowing() then
                    self:OnTimerTick()
                end
            else
                self:StopTimer(true)
            end
            self:RefreshCharacterSheetRowsInPlace()
        end,
    })

    panel:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Cycle Speed (1 to 300 Seconds)",
        tooltip = "Set how many seconds each selected guild stays displayed (1-300 seconds). Minimum 1-second interval enforced to respect ESO's represented-guild API rate limit.",
        min = 1,
        max = 300,
        step = 1,
        unit = " s",
        format = "%d",
        default = DEFAULT_SETTINGS.cycleIntervalSeconds,
        getFunction = function()
            return math.max(1, math.floor((tonumber(self.db.cycleIntervalSeconds) or 5) + 0.5))
        end,
        setFunction = function(value)
            self.db.cycleIntervalSeconds = math.max(1, value)
            self.db.useSubSecondSpeed = false
            self:StartOrUpdateTimer()
            self:RefreshCharacterSheetRowsInPlace()
        end,
    })

    panel:AddSetting({
        type = LHAS.ST_DROPDOWN,
        label = "Cycle Order Mode",
        tooltip = "Choose Sequential (1->5), Reverse (5->1), Shuffle Bag (fair random with no repeats), Priority Bias (Primary guild 50% of the time), or Ping-Pong Bounce (1<->5).",
        default = MODE_NAMES[DEFAULT_SETTINGS.cycleMode],
        items = {
            { name = MODE_NAMES[FGC.MODE_SEQUENTIAL], data = FGC.MODE_SEQUENTIAL },
            { name = MODE_NAMES[FGC.MODE_REVERSE],    data = FGC.MODE_REVERSE },
            { name = MODE_NAMES[FGC.MODE_RANDOM],     data = FGC.MODE_RANDOM },
            { name = MODE_NAMES[FGC.MODE_PRIORITY],   data = FGC.MODE_PRIORITY },
            { name = MODE_NAMES[FGC.MODE_PINGPONG],   data = FGC.MODE_PINGPONG },
        },
        getFunction = function()
            return MODE_NAMES[self.db.cycleMode] or MODE_NAMES[FGC.MODE_SEQUENTIAL]
        end,
        setFunction = function(control, itemName, itemData)
            local modeVal = (type(itemData) == "table" and itemData.data) or itemData or FGC.MODE_SEQUENTIAL
            self.db.cycleMode = modeVal
            self.shuffleBag = {}
            self:RefreshCharacterSheetRowsInPlace()
        end,
    })

    panel:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Primary Guild Slot (For Priority Mode)",
        tooltip = "When Cycle Order Mode is set to Priority Bias, this guild slot is displayed every other cycle (50% of total time) while rotating evenly through your other favorite guilds.",
        min = 1,
        max = MAX_GUILD_SLOTS,
        step = 1,
        format = "%d",
        default = DEFAULT_SETTINGS.primaryGuildSlot,
        getFunction = function() return self.db.primaryGuildSlot end,
        setFunction = function(value) self.db.primaryGuildSlot = value end,
        disable = function() return self.db.cycleMode ~= FGC.MODE_PRIORITY end,
    })

    panel:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Pin Single Guild Slot (0 = Off, 1-5 = Guild)",
        tooltip = "Temporarily pin/lock a single guild slot without losing your saved favorite guild checkboxes. Set back to 0 to resume normal cycling.",
        min = 0,
        max = MAX_GUILD_SLOTS,
        step = 1,
        format = "%d",
        default = DEFAULT_SETTINGS.pinnedGuildSlot,
        getFunction = function() return self.db.pinnedGuildSlot or 0 end,
        setFunction = function(value)
            self.db.pinnedGuildSlot = value
            if value > 0 then
                self:ApplyGuildRepresentation(value, false, false)
            end
            self:RefreshCharacterSheetRowsInPlace()
        end,
    })

    panel:AddSetting({
        type = LHAS.ST_BUTTON,
        label = "Cycle to Next Favorite Guild Now",
        buttonText = "Switch Guild",
        tooltip = "Immediately advance to the next favorited guild in your rotation.",
        clickHandler = function()
            self:ForceNextGuild()
        end,
    })

    -- SECTION 2: Select / Toggle Favorite Guilds
    panel:AddSetting({
        type = LHAS.ST_SECTION,
        label = "Select Guilds to Cycle",
    })

    panel:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Only Cycle Selected Favorite Guilds",
        tooltip = "When ON, only cycles through the guilds toggled ON below. When OFF, cycles through all guilds your character belongs to.",
        default = DEFAULT_SETTINGS.onlySelectedGuilds,
        getFunction = function() return self.db.onlySelectedGuilds end,
        setFunction = function(state)
            self.db.onlySelectedGuilds = state
            self.shuffleBag = {}
            self:RefreshCharacterSheetRowsInPlace()
        end,
    })

    for slotIndex = 1, MAX_GUILD_SLOTS do
        local guildSlot = slotIndex
        panel:AddSetting({
            type = LHAS.ST_CHECKBOX,
            label = self:GetFormattedGuildSlotLabel(guildSlot),
            tooltip = string.format("Toggle ON to include Guild Slot %d in your nameplate rotation, or OFF to skip it.", guildSlot),
            default = DEFAULT_SETTINGS.favoriteSlots[guildSlot],
            getFunction = function() return self:IsSlotFavorite(guildSlot) end,
            setFunction = function(state)
                self:SetSlotFavorite(guildSlot, state)
            end,
            disable = function() return not self.db.onlySelectedGuilds end,
        })
    end

    panel:AddSetting({
        type = LHAS.ST_BUTTON,
        label = "Select All Joined Guilds",
        buttonText = "Select All",
        tooltip = "Marks each currently joined guild as a favorite. Newly joined guilds must be selected separately.",
        clickHandler = function()
            self:SetAllGuildFavorites(true)
            self:SyncFavoriteSlotsFromGuildIds()
            PrintMessage("All currently joined guilds marked as favorites.")
        end,
        disable = function() return not self.db.onlySelectedGuilds end,
    })

    panel:AddSetting({
        type = LHAS.ST_BUTTON,
        label = "Clear Favorite Guilds",
        buttonText = "Clear All",
        tooltip = "Clears all favorite guild selections so you can pick fresh ones.",
        clickHandler = function()
            self:SetAllGuildFavorites(false)
            self:SyncFavoriteSlotsFromGuildIds()
            PrintMessage("Cleared all favorite guilds.")
        end,
        disable = function() return not self.db.onlySelectedGuilds end,
    })

    panel:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Include 'No Guild Displayed' Step in Rotation",
        tooltip = "If enabled, adds a step at the end of each rotation that temporarily clears your displayed guild before starting the loop again.",
        default = DEFAULT_SETTINGS.includeUnrepresentedStep,
        getFunction = function() return self.db.includeUnrepresentedStep end,
        setFunction = function(state)
            self.db.includeUnrepresentedStep = state
            self.shuffleBag = {}
        end,
    })

    -- SECTION 3: Character Sheet, Smart Pauses & Context Rules
    panel:AddSetting({
        type = LHAS.ST_SECTION,
        label = "Character Sheet, Smart Pauses & Context Rules",
    })

    panel:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Show Guild Cycler in Character Sheet",
        tooltip = "Displays your Guild Cycler rows (ON/OFF, Speed, and Favorite Guilds) and controller shortcuts inside your PS5 Character Sheet without disrupting scroll position.",
        default = DEFAULT_SETTINGS.showInCharacterSheet,
        getFunction = function() return self.db.showInCharacterSheet end,
        setFunction = function(state) self.db.showInCharacterSheet = state end,
    })

    panel:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Auto-Pause While in Character Sheet (Recommended)",
        tooltip = "ON by default. Pauses background guild changes while your Character Sheet is open so respeccing attributes and inspecting buffs/effects is completely smooth and interruption-free.",
        default = DEFAULT_SETTINGS.pauseInCharacterSheet,
        getFunction = function() return self.db.pauseInCharacterSheet ~= false end,
        setFunction = function(state) self.db.pauseInCharacterSheet = state end,
    })

    panel:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Pause During Crafting / Bank / Shrine Interactions",
        tooltip = "ON by default. Pauses background guild switching while interacting with crafting stations, bankers, merchants, outfit stations, or rededication shrines.",
        default = DEFAULT_SETTINGS.pauseInInteractions,
        getFunction = function() return self.db.pauseInInteractions ~= false end,
        setFunction = function(state) self.db.pauseInInteractions = state end,
    })

    panel:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Pause Cycling in Combat (Optional)",
        tooltip = "OFF by default so your guilds continue cycling during combat. Turn ON if you prefer guild cycling to pause while in combat.",
        default = DEFAULT_SETTINGS.pauseInCombat,
        getFunction = function() return self.db.pauseInCombat end,
        setFunction = function(state) self.db.pauseInCombat = state end,
    })

    panel:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Pause While Browsing Any Menu (Optional)",
        tooltip = "OFF by default. Turn ON if you want guild cycling to pause whenever any full-screen menu is open.",
        default = DEFAULT_SETTINGS.pauseInMenus,
        getFunction = function() return self.db.pauseInMenus end,
        setFunction = function(state) self.db.pauseInMenus = state end,
    })

    panel:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Pause While Hidden / Stealthed (Optional)",
        tooltip = "OFF by default. Turn ON to pause guild switching while crouched in stealth.",
        default = DEFAULT_SETTINGS.pauseInStealth,
        getFunction = function() return self.db.pauseInStealth end,
        setFunction = function(state) self.db.pauseInStealth = state end,
    })

    panel:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Pause While Mounted (Optional)",
        tooltip = "OFF by default. Turn ON to pause guild switching while riding a mount.",
        default = DEFAULT_SETTINGS.pauseWhenMounted,
        getFunction = function() return self.db.pauseWhenMounted == true end,
        setFunction = function(state) self.db.pauseWhenMounted = state end,
    })

    panel:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Pause Inside Player Homes (Optional)",
        tooltip = "Pauses guild cycling while visiting any player house or guild hall.",
        default = DEFAULT_SETTINGS.pauseInHousing,
        getFunction = function() return self.db.pauseInHousing end,
        setFunction = function(state) self.db.pauseInHousing = state end,
    })

    panel:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "PvP Zone Guild Lock (0 = Off, 1-5 = Guild Slot)",
        tooltip = "Automatically locks your displayed guild to this specific Guild Slot (1-5) whenever you enter Cyrodiil, Imperial City, or Battlegrounds. Set to 0 to keep normal cycling in PvP.",
        min = 0,
        max = MAX_GUILD_SLOTS,
        step = 1,
        format = "%d",
        default = DEFAULT_SETTINGS.pvpOverrideSlot,
        getFunction = function() return self.db.pvpOverrideSlot end,
        setFunction = function(value)
            self.db.pvpOverrideSlot = value
            self:OnTimerTick()
        end,
    })

    panel:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Dungeon / Trial Guild Lock (0 = Off, 1-5 = Guild Slot)",
        tooltip = "Automatically locks your displayed guild to this specific Guild Slot (1-5) whenever you enter a 4-man Dungeon, 12-man Trial, or Arena. Set to 0 to keep normal cycling.",
        min = 0,
        max = MAX_GUILD_SLOTS,
        step = 1,
        format = "%d",
        default = DEFAULT_SETTINGS.pveInstanceOverrideSlot,
        getFunction = function() return self.db.pveInstanceOverrideSlot or 0 end,
        setFunction = function(value)
            self.db.pveInstanceOverrideSlot = value
            self:OnTimerTick()
        end,
    })

    panel:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Match Group Leader's Guild When Grouped",
        tooltip = "If you are in a group and the Group Leader belongs to one of your favorited guilds, automatically represent that shared guild.",
        default = DEFAULT_SETTINGS.matchGroupLeaderGuild,
        getFunction = function() return self.db.matchGroupLeaderGuild end,
        setFunction = function(state)
            self.db.matchGroupLeaderGuild = state
            self:OnTimerTick()
        end,
    })

    panel:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Restore Fallback Guild When Disabled",
        tooltip = "When you turn off the cycler, automatically switch back to your designated Fallback Guild Slot below.",
        default = DEFAULT_SETTINGS.restoreOnDisable,
        getFunction = function() return self.db.restoreOnDisable end,
        setFunction = function(state) self.db.restoreOnDisable = state end,
    })

    panel:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Fallback Guild Slot (0 = None, 1-5 = Guild)",
        tooltip = "Which guild slot to display when the cycler is paused or turned off.",
        min = 0,
        max = MAX_GUILD_SLOTS,
        step = 1,
        format = "%d",
        default = DEFAULT_SETTINGS.fallbackGuildSlot,
        getFunction = function() return self.db.fallbackGuildSlot end,
        setFunction = function(value) self.db.fallbackGuildSlot = value end,
        disable = function() return not self.db.restoreOnDisable end,
    })

    -- SECTION 4: Optional Physical Guild Tabard Sync
    panel:AddSetting({
        type = LHAS.ST_SECTION,
        label = "Physical Guild Tabard Sync (Optional)",
    })

    panel:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Also Equip Matching Physical Guild Tabard",
        tooltip = "Optional: If you also want your character's physical Guild Tabard (Appearance slot) swapped from your backpack when out of combat, enable this and register each tabard below.",
        default = DEFAULT_SETTINGS.syncPhysicalTabard,
        getFunction = function() return self.db.syncPhysicalTabard end,
        setFunction = function(state) self.db.syncPhysicalTabard = state end,
    })

    for slotIndex = 1, MAX_GUILD_SLOTS do
        local guildSlot = slotIndex
        panel:AddSetting({
            type = LHAS.ST_BUTTON,
            label = string.format("Bind Equipped Tabard to Guild %d", guildSlot),
            buttonText = "Register Tabard",
            tooltip = string.format("Equip your Guild %d tabard first, then press this button to link that physical tabard to Guild Slot %d.", guildSlot, guildSlot),
            clickHandler = function()
                self:RegisterEquippedTabardToSlot(guildSlot)
            end,
            disable = function() return not self.db.syncPhysicalTabard end,
        })
    end

    -- SECTION 5: Profile, Notifications & Credits
    panel:AddSetting({
        type = LHAS.ST_SECTION,
        label = "Profile, Notifications & Credits",
    })

    panel:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Use Per-Character Settings",
        tooltip = "When OFF (default), your favorite guilds and cycle settings are shared across all characters on your PSN account. Turn ON to save a custom setup just for this character.",
        default = DEFAULT_SETTINGS.useCharacterSettings,
        getFunction = function() return self.characterVars.useCharacterSettings end,
        setFunction = function(state)
            self:SetUseCharacterSettings(state)
        end,
    })

    panel:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Show Chat Notification on Guild Switch",
        tooltip = "Prints a message in the chat window each time your displayed guild rotates.",
        default = DEFAULT_SETTINGS.chatNotifications,
        getFunction = function() return self.db.chatNotifications end,
        setFunction = function(state) self.db.chatNotifications = state end,
    })

    panel:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Show On-Screen Alert on Guild Switch",
        tooltip = "Displays a brief top-right alert notification whenever your displayed guild changes.",
        default = DEFAULT_SETTINGS.onScreenNotifications,
        getFunction = function() return self.db.onScreenNotifications end,
        setFunction = function(state) self.db.onScreenNotifications = state end,
    })

    panel:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Show Startup Message in Chat",
        tooltip = "Prints a brief confirmation message in chat when the add-on loads.",
        default = DEFAULT_SETTINGS.showStartupMessage,
        getFunction = function() return self.db.showStartupMessage == true end,
        setFunction = function(state) self.db.showStartupMessage = state end,
    })
end

--------------------------------------------------------------------------------
-- Slash Commands (/fgc and /guildcycle)
--------------------------------------------------------------------------------

function FGC:HandleSlashCommand(argsText)
    local args = {}
    for word in string.gmatch(argsText or "", "%S+") do
        table.insert(args, string.lower(word))
    end

    local cmd = args[1]

    -- Typing /fgc with no arguments immediately toggles ON/OFF for effortless controller use
    if not cmd or cmd == "toggle" then
        self:ToggleEnabled(false)
        return
    end

    if cmd == "help" or cmd == "?" then
        PrintMessage("Favorite Guild Cycler v" .. self.version .. " by |cFFFFFFAnimosity|r (Guild: |c00FFFFCRY|r):")
        PrintMessage("  |cFFFFFF/fgc|r - Instantly toggle guild cycling ON or OFF")
        PrintMessage("  |cFFFFFF/fgc menu|r - Open the Quick Guild Cycler & Favorites dialog")
        PrintMessage("  |cFFFFFF/fgc next|r - Immediately switch to next favorite guild")
        PrintMessage("  |cFFFFFF/fgc speed <1-600>|r - Set cycle speed in seconds (minimum 1s for API safety)")
        PrintMessage("  |cFFFFFF/fgc fav <1-5>|r - Toggle favorite status for Guild 1-5")
        PrintMessage("  |cFFFFFF/fgc pin <0-5|off>|r - Pin/lock a single guild slot (0 or off to unpin)")
        PrintMessage("  |cFFFFFF/fgc mode <seq|rev|rand|priority|pingpong>|r - Change rotation order")
        PrintMessage("  |cFFFFFF/fgc combat|r - Toggle whether cycling pauses in combat")
        PrintMessage("  |cFFFFFF/fgc list|r - Show your guilds and favorite status")
        PrintMessage("  |cFFFFFF/fgc status|r - Display current cycler status, active lock, and session stats")
        PrintMessage("  |cFFFFFF/fgc about|r - Show add-on version and credits")
        return
    end

    if cmd == "about" or cmd == "credits" or cmd == "credit" then
        PrintMessage(string.format(
            "|cFFFFFF%s v%s|r — Developed by |cEECA2A%s|r | Special credit to guild |c00FFFF%s|r.",
            self.title, self.version, self.author, self.guildCredit
        ))
        return
    end

    if cmd == "menu" or cmd == "ui" or cmd == "quick" then
        self:ShowCharacterSheetQuickDialog()
        return
    end

    if cmd == "on" or cmd == "off" then
        self.db.enabled = (cmd == "on")
        if self.db.enabled then
            self:StartOrUpdateTimer()
            if not self:IsCharacterSheetSceneShowing() then
                self:OnTimerTick()
            end
            PrintMessage("Guild Cycling |c00FF00ON|r (Every " .. self:GetFormattedSpeedText() .. ").")
        else
            self:StopTimer(true)
            PrintMessage("Guild Cycling |cFF4444OFF|r.")
        end
        self:RefreshCharacterSheetRowsInPlace()
        return
    end

    if cmd == "pin" or cmd == "lock" then
        local arg2 = args[2]
        if not arg2 or arg2 == "off" or arg2 == "none" or arg2 == "0" then
            self.db.pinnedGuildSlot = 0
            self:RefreshCharacterSheetRowsInPlace()
            PrintMessage("Guild pin cleared. Normal favorite rotation resumed.")
            return
        end
        local slot = tonumber(arg2)
        if not slot or slot < 1 or slot > MAX_GUILD_SLOTS then
            PrintMessage("Specify a guild slot 1-5 to pin, or '/fgc pin off' to unpin.")
            return
        end
        self.db.pinnedGuildSlot = slot
        self:ApplyGuildRepresentation(slot, false, true)
        self:RefreshCharacterSheetRowsInPlace()
        local _, gName = self:GetGuildDetailsBySlot(slot)
        PrintMessage(string.format("Pinned displayed guild to Guild %d (%s).", slot, gName or "Empty"))
        return
    end

    if cmd == "combat" then
        self.db.pauseInCombat = not self.db.pauseInCombat
        local stateStr = self.db.pauseInCombat and "|cFFAA00PAUSED in Combat|r" or "|c00FF00ACTIVE in Combat|r"
        PrintMessage("Combat cycling behavior: " .. stateStr)
        return
    end

    if cmd == "next" or cmd == "step" then
        self:ForceNextGuild()
        return
    end

    if cmd == "speed" or cmd == "interval" or cmd == "time" then
        local sec = tonumber(args[2])
        if not sec or sec < MIN_ALLOWED_INTERVAL_SECONDS or sec > 600 then
            PrintMessage("Please specify a cycle speed between 1 and 600 seconds (e.g., /fgc speed 1 or /fgc speed 5). Sub-second cycling is disabled for API safety.")
            return
        end
        self:SetSpeedSeconds(sec)
        PrintMessage("Cycle speed set to |cFFFFFF" .. self:GetFormattedSpeedText() .. "|r.")
        return
    end

    if cmd == "fav" or cmd == "favorite" or cmd == "slot" then
        local slot = tonumber(args[2])
        if not slot or slot < 1 or slot > MAX_GUILD_SLOTS then
            PrintMessage("Please specify a guild number from 1 to 5 (e.g., /fgc fav 2).")
            return
        end
        self:SetSlotFavorite(slot, not self:IsSlotFavorite(slot))
        local _, gName = self:GetGuildDetailsBySlot(slot)
        local statusStr = self:IsSlotFavorite(slot) and "|c00FF00FAVORITED|r" or "|cFF4444REMOVED|r"
        PrintMessage(string.format("Guild %d (%s): %s", slot, gName or "Empty Slot", statusStr))
        return
    end

    if cmd == "mode" or cmd == "order" then
        local modeArg = args[2]
        local modeMap = {
            seq = FGC.MODE_SEQUENTIAL,
            sequential = FGC.MODE_SEQUENTIAL,
            rev = FGC.MODE_REVERSE,
            reverse = FGC.MODE_REVERSE,
            rand = FGC.MODE_RANDOM,
            random = FGC.MODE_RANDOM,
            shuffle = FGC.MODE_RANDOM,
            priority = FGC.MODE_PRIORITY,
            prio = FGC.MODE_PRIORITY,
            pingpong = FGC.MODE_PINGPONG,
            bounce = FGC.MODE_PINGPONG,
            pp = FGC.MODE_PINGPONG,
        }
        local targetMode = modeMap[modeArg or ""]
        if not targetMode then
            PrintMessage("Choose a mode: |cFFFFFFseq|r, |cFFFFFFrev|r, |cFFFFFFrand|r, |cFFFFFFpriority|r, or |cFFFFFFpingpong|r.")
            return
        end
        self.db.cycleMode = targetMode
        self.shuffleBag = {}
        self:RefreshCharacterSheetRowsInPlace()
        PrintMessage("Cycle mode set to: |cFFFFFF" .. MODE_NAMES[targetMode] .. "|r")
        return
    end

    if cmd == "list" or cmd == "guilds" then
        PrintMessage("Your Joined Guilds & Favorite Status:")
        for slot = 1, MAX_GUILD_SLOTS do
            local _, gName = self:GetGuildDetailsBySlot(slot)
            local favTag = self:IsSlotFavorite(slot) and "|c00FF00[FAV]|r" or "|c888888[   ]|r"
            PrintMessage(string.format("  %s Guild %d: %s", favTag, slot, gName or "(Not in a guild)"))
        end
        return
    end

    if cmd == "status" or cmd == "stats" then
        local paused, reason = self:ShouldPauseCycling()
        local overrideSlot, overrideReason = self:GetContextualOverrideSlot()
        local stateText = self.db.enabled and (paused and ("Paused (" .. tostring(reason) .. ")") or "Active") or "Disabled"
        if overrideSlot then
            stateText = stateText .. string.format(" [%s: Guild %d]", overrideReason or "Override", overrideSlot)
        end
        local eligible = self:GetEligibleGuildSlots()
        PrintMessage(string.format(
            "Status: |cFFFFFF%s|r | Displaying: |c00FF00%s|r | Speed: |cFFFFFF%s|r | Mode: |cFFFFFF%s|r | Eligible: |cFFFFFF%d|r | Switches: |cFFFFFF%d|r",
            stateText,
            self:GetCurrentlyDisplayedGuildSummary(),
            self:GetFormattedSpeedText(),
            MODE_NAMES[self.db.cycleMode] or "Sequential",
            #eligible,
            self.sessionSwitchCount or 0
        ))
        return
    end

    PrintMessage("Unknown command. Type |cFFFFFF/fgc help|r for a list of commands.")
end

--------------------------------------------------------------------------------
-- Event Handlers & Initialization
--------------------------------------------------------------------------------

function FGC:OnCombatStateChanged(inCombat)
    self.inCombat = inCombat
    if not inCombat and self.db and self.db.enabled and self.db.pauseInCombat then
        if zo_callLater then
            zo_callLater(function()
                if not (IsUnitInCombat and IsUnitInCombat("player")) then
                    self:OnTimerTick()
                end
            end, 500)
        end
    end
end

function FGC:Initialize()
    if self.isInitialized then return end
    self.isInitialized = true

    self:LoadSavedVariables()
    self:ResolveRepresentationAPI()
    self:SetupCharacterSheetIntegration()

    if self.db and self.db.showStartupMessage then
        PrintMessage(string.format(
            "v%s by |cFFFFFF%s|r (Guild: |c00FFFF%s|r) loaded. (1s minimum API safety interval active.)",
            self.version, self.author, self.guildCredit
        ))
    end

    -- Register Slash Commands
    SLASH_COMMANDS["/fgc"] = function(args) self:HandleSlashCommand(args) end
    SLASH_COMMANDS["/guildcycle"] = function(args) self:HandleSlashCommand(args) end

    -- Combat State Tracking
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        self:OnCombatStateChanged(inCombat)
    end)

    -- Zone / Activation Changes
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PLAYER_ACTIVATED, function()
        self:BuildGamepadSettingsMenu()
        self.inCombat = IsUnitInCombat and IsUnitInCombat("player") or false
        self:SyncFavoriteSlotsFromGuildIds()
        self:SyncCurrentRepresentedStateFromClient()

        if self.db.enabled then
            self:StartOrUpdateTimer()
        end
    end)

    -- Refresh when joining or leaving a guild
    local function OnGuildMembershipChanged()
        local function refreshGuildFavorites()
            if not self.db then return end
            self:SyncFavoriteSlotsFromGuildIds()
            if self.db.enabled then
                self:StartOrUpdateTimer()
            end
        end
        if zo_callLater then
            zo_callLater(refreshGuildFavorites, 500)
        else
            refreshGuildFavorites()
        end
    end
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_GUILD_SELF_JOINED_GUILD, OnGuildMembershipChanged)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_GUILD_SELF_LEFT_GUILD, OnGuildMembershipChanged)
end

EVENT_MANAGER:RegisterForEvent(FGC.name, EVENT_ADD_ON_LOADED, function(eventCode, addonName)
    if addonName ~= FGC.name then return end
    EVENT_MANAGER:UnregisterForEvent(FGC.name, EVENT_ADD_ON_LOADED)
    FGC:Initialize()
end)
