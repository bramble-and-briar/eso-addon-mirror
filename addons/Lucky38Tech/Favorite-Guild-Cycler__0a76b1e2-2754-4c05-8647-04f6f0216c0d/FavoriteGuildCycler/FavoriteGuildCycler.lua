--[[
    Favorite Guild Cycler (PS5 / Console & Gamepad Edition)
    Version: 1.3.1
    Description:
        Automatically cycles the player's displayed / represented guild underneath
        their character nameplate across selected favorite guilds (Slots 1-5).
        - Enforces a minimum 1-second interval to respect the represented-guild API limit.
        - Persists favorite guild identities (guild IDs), not just changeable guild-slot numbers.
        - Works seamlessly during combat by default (with an optional menu toggle to pause in combat).
        - Integrates directly into the PS5 Gamepad Character Sheet (under Guild Nameplate)
          and Keybind Strip for instant ON/OFF toggling, speed adjustments, and favorite guild selection.
        - Full LibHarvensAddonSettings menu under Options -> Add-Ons -> Favorite Guild Cycler.
        - One-word /fgc slash command to toggle ON/OFF immediately.
]]

FavoriteGuildCycler = FavoriteGuildCycler or {}
local FGC = FavoriteGuildCycler

FGC.name = "FavoriteGuildCycler"
FGC.title = "Favorite Guild Cycler"
FGC.version = "1.3.1"
FGC.savedVarsVersion = 2

-- Cycle Order Mode Constants
FGC.MODE_SEQUENTIAL = 1
FGC.MODE_REVERSE    = 2
FGC.MODE_RANDOM     = 3
FGC.MODE_PRIORITY   = 4

local MODE_NAMES = {
    [FGC.MODE_SEQUENTIAL] = "Sequential (1 -> 5)",
    [FGC.MODE_REVERSE]    = "Reverse (5 -> 1)",
    [FGC.MODE_RANDOM]     = "Random Shuffle (No Repeat)",
    [FGC.MODE_PRIORITY]   = "Priority Bias (Primary 50%)",
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
FGC.currentSlotIndex = 0
FGC.lastDisplayedGuildId = nil
FGC.originalGuildId = nil
FGC.priorityToggleFlip = false
FGC.lastSwitchTimestampMs = 0
FGC.inCombat = false
FGC.resolvedSetterName = nil
FGC.resolvedGetterName = nil

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
    includeUnrepresentedStep = false,

    -- Combat & Smart Pause Settings (Works IN COMBAT by default; optional toggle to pause)
    pauseInCombat = false,
    pauseInMenus = false,
    pauseInStealth = false,
    pauseWhenDead = true,
    pauseInHousing = false,

    -- Character Sheet Integration
    showInCharacterSheet = true,

    -- Zone & Group Context Automation
    pvpOverrideSlot = 0,           -- 0 = Disabled, 1..5 = Force specific guild slot in Cyrodiil/IC/BGs
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

local function NotifyGuildSwitch(guildName, slotIndex)
    if not FGC.db then return end
    local label = guildName and string.format("%s (Guild %d)", guildName, slotIndex) or "No Guild Displayed"

    if FGC.db.chatNotifications then
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
    -- Older versions allowed 100ms-950ms. Clamp legacy saved values to the safe
    -- minimum as well; the UI no longer exposes a sub-second option.
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
    local numGuilds = GetNumGuilds()
    if slotIndex > numGuilds then
        return nil, nil
    end
    local guildId = GetGuildId(slotIndex)
    if not guildId or guildId == 0 then
        return nil, nil
    end
    local guildName = GetGuildName(guildId)
    return guildId, guildName
end

function FGC:GetFormattedGuildSlotLabel(slotIndex)
    local guildId, guildName = self:GetGuildDetailsBySlot(slotIndex)
    if guildId and guildName and guildName ~= "" then
        return string.format("Favorite Guild %d (%s)", slotIndex, guildName)
    end
    return string.format("Favorite Guild %d (Empty Slot)", slotIndex)
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
                -- A newly joined/unrecognized guild is not silently substituted for
                -- a previously favorited guild merely because it occupies its slot.
                self.db.favoriteSlots[slot] = false
            else
                -- Saved favorites belong to different guild IDs (e.g. a different
                -- character profile). Do not guess based on their current slot order.
                self.db.favoriteSlots[slot] = false
            end
        end
    end
end

function FGC:GetActiveFavoriteCount()
    local count = 0
    local numGuilds = GetNumGuilds()
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
        self:OnTimerTick()
        if not silent then
            PrintMessage("Guild Cycling |c00FF00ON|r (Every " .. self:GetFormattedSpeedText() .. ").")
        end
    else
        self:StopTimer(true)
        if not silent then
            PrintMessage("Guild Cycling |cFF4444OFF|r.")
        end
    end
    if KEYBIND_STRIP and self.charSheetKeybindStripDescriptor then
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
    if not leaderTag or leaderTag == "" or AreUnitsEqual("player", leaderTag) then
        return nil
    end

    local leaderDisplayName = GetUnitDisplayName and GetUnitDisplayName(leaderTag)
    if not leaderDisplayName or leaderDisplayName == "" then
        return nil
    end

    local numGuilds = GetNumGuilds()
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
    -- This is the ESO API used by the current guild-rotation addons. Avoid invoking
    -- multiple speculative setters: doing so could double-submit the same request.
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

function FGC:TryEquipRegisteredTabard(slotIndex)
    if not self.db or not self.db.syncPhysicalTabard then return end
    if IsUnitInCombat("player") then return end

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
function FGC:ApplyGuildRepresentation(slotIndex, isSilent)
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
        return true
    end

    local nowMs = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
    if nowMs > 0 and self.lastSwitchTimestampMs > 0 then
        local elapsed = nowMs - self.lastSwitchTimestampMs
        if elapsed < REPRESENTED_GUILD_API_INTERVAL_MS then
            return false
        end
    end

    -- Call exactly one supported setter path. The gamepad method is used only as a
    -- fallback when the public API global is unavailable.
    local requestSucceeded = false
    if self.resolvedSetterName and type(_G[self.resolvedSetterName]) == "function" then
        local ok = pcall(_G[self.resolvedSetterName], guildId)
        requestSucceeded = ok
    elseif GAMEPAD_STATS and type(GAMEPAD_STATS.SetRepresentedGuildId) == "function" then
        local ok = pcall(function() GAMEPAD_STATS:SetRepresentedGuildId(guildId) end)
        requestSucceeded = ok
    else
        if not self.warnedMissingRepresentationApi then
            self.warnedMissingRepresentationApi = true
            PrintMessage("This ESO client does not expose SetRepresentedGuildId, so guild switching is unavailable. No guild change was made.")
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

    if not isSilent then
        NotifyGuildSwitch(guildName, slotIndex)
    end

    return true
end

--------------------------------------------------------------------------------
-- Active Candidate Pool & Smart Pause Evaluation
--------------------------------------------------------------------------------

function FGC:GetEligibleGuildSlots()
    local slots = {}
    local numGuilds = GetNumGuilds()

    for slot = 1, math.min(numGuilds, MAX_GUILD_SLOTS) do
        local guildId = GetGuildId(slot)
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

    if self.db.pauseInCombat and (self.inCombat or IsUnitInCombat("player")) then
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

    if self.db.pauseInMenus and SCENE_MANAGER then
        local currentScene = SCENE_MANAGER:GetCurrentScene()
        if currentScene and currentScene:GetName() ~= "hud" and currentScene:GetName() ~= "hudui" then
            return true, "In Menu (" .. tostring(currentScene:GetName()) .. ")"
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

    if self.db.pvpOverrideSlot and self.db.pvpOverrideSlot > 0 then
        local inPvP = (IsPlayerInAvAWorld and IsPlayerInAvAWorld()) or (IsActiveWorldBattleground and IsActiveWorldBattleground())
        if inPvP then
            local guildId = self:GetGuildDetailsBySlot(self.db.pvpOverrideSlot)
            if guildId then
                return self.db.pvpOverrideSlot, "PvP Zone Override"
            end
        end
    end

    if self.db.matchGroupLeaderGuild then
        local sharedSlot = self:FindSharedGroupLeaderGuildSlot()
        if sharedSlot then
            return sharedSlot, "Group Leader Shared Guild"
        end
    end

    return nil, nil
end

--------------------------------------------------------------------------------
-- Core Cycle Step Logic
--------------------------------------------------------------------------------

function FGC:SelectNextSlot(eligibleSlots)
    local count = #eligibleSlots
    if count == 0 then return nil end
    if count == 1 then return eligibleSlots[1] end

    local mode = self.db.cycleMode or FGC.MODE_SEQUENTIAL

    if mode == FGC.MODE_PRIORITY then
        local primarySlot = self.db.primaryGuildSlot or 1
        local primaryId = self:GetGuildDetailsBySlot(primarySlot)
        if primaryId then
            self.priorityToggleFlip = not self.priorityToggleFlip
            if self.priorityToggleFlip and self.currentSlotIndex ~= primarySlot then
                return primarySlot
            end
        end
    end

    if mode == FGC.MODE_RANDOM then
        local candidates = {}
        for _, slot in ipairs(eligibleSlots) do
            if slot ~= self.currentSlotIndex then
                table.insert(candidates, slot)
            end
        end
        if #candidates > 0 then
            local pickIndex = math.random(1, #candidates)
            return candidates[pickIndex]
        end
        return eligibleSlots[1]
    end

    local currentPos = nil
    for i, slot in ipairs(eligibleSlots) do
        if slot == self.currentSlotIndex then
            currentPos = i
            break
        end
    end

    if mode == FGC.MODE_REVERSE then
        if not currentPos or currentPos <= 1 then
            return eligibleSlots[count]
        else
            return eligibleSlots[currentPos - 1]
        end
    else
        if not currentPos or currentPos >= count then
            return eligibleSlots[1]
        else
            return eligibleSlots[currentPos + 1]
        end
    end
end

function FGC:OnTimerTick()
    local isPaused, _ = self:ShouldPauseCycling()
    if isPaused then
        return
    end

    local overrideSlot, _ = self:GetContextualOverrideSlot()
    if overrideSlot then
        self:ApplyGuildRepresentation(overrideSlot, false)
        return
    end

    local eligibleSlots = self:GetEligibleGuildSlots()
    if #eligibleSlots == 0 then
        return
    end

    local nextSlot = self:SelectNextSlot(eligibleSlots)
    if nextSlot ~= nil then
        self:ApplyGuildRepresentation(nextSlot, false)
    end
end

function FGC:ForceNextGuild()
    local eligibleSlots = self:GetEligibleGuildSlots()
    if #eligibleSlots == 0 then
        PrintMessage("No eligible guilds selected! Enable at least one guild in your Character Sheet or Add-On Settings.")
        return
    end
    local nextSlot = self:SelectNextSlot(eligibleSlots)
    if nextSlot ~= nil then
        local prevChat = self.db.chatNotifications
        self.db.chatNotifications = true
        self:ApplyGuildRepresentation(nextSlot, false)
        self.db.chatNotifications = prevChat
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
        -- Do not let a delayed fallback override cycling if the user re-enabled it.
        if not self.db or self.db.enabled then return end
        if fallbackSlot >= 1 and fallbackSlot <= MAX_GUILD_SLOTS then
            self:ApplyGuildRepresentation(fallbackSlot, true)
        elseif fallbackSlot == 0 then
            self:ApplyGuildRepresentation(0, true)
        end
    end

    -- If a switch just occurred, queue restoration until the one-second API window
    -- has elapsed instead of either violating the limit or silently skipping restore.
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

    -- The previous version stored sub-second settings. Force those profiles to the
    -- safe minimum and migrate slot-only favorites as soon as guild data is ready.
    self.db.useSubSecondSpeed = false
    self.db.cycleIntervalSeconds = math.max(1, tonumber(self.db.cycleIntervalSeconds) or 5)
    self.db.favoriteGuilds = self.db.favoriteGuilds or {}
    self.db.favoriteSlots = self.db.favoriteSlots or ZO_ShallowTableCopy(DEFAULT_SETTINGS.favoriteSlots)
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
-- PS5 Character Sheet Quick-Cycler Dialog & Under-Guild-Nameplate Controls
--------------------------------------------------------------------------------

function FGC:BuildParametricQuickDialogEntries()
    local entries = {}
    if not ZO_GamepadEntryData then return entries end

    -- 1. Master ON / OFF Toggle Row
    local statusText = self.db.enabled and "|c00FF00ON|r" or "|cFF4444OFF|r"
    local toggleEntry = ZO_GamepadEntryData:New(string.format("Guild Cycler: %s", statusText))
    toggleEntry:AddSubLabel("Press X to toggle automatic guild cycling ON or OFF")
    toggleEntry.onSelect = function(dialog)
        self:ToggleEnabled(true)
        if dialog and dialog.setupFunc then dialog:setupFunc() end
        if GAMEPAD_STATS and GAMEPAD_STATS.RefreshMainList then
            pcall(function() GAMEPAD_STATS:RefreshMainList() end)
        end
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
        if dialog and dialog.setupFunc then dialog:setupFunc() end
        if GAMEPAD_STATS and GAMEPAD_STATS.RefreshMainList then
            pcall(function() GAMEPAD_STATS:RefreshMainList() end)
        end
    end
    table.insert(entries, {
        template = "ZO_GamepadMenuEntryTemplate",
        entryData = speedEntry,
    })

    -- 3. Cycle Order Mode Row
    local modeLabel = MODE_NAMES[self.db.cycleMode] or MODE_NAMES[FGC.MODE_SEQUENTIAL]
    local modeEntry = ZO_GamepadEntryData:New(string.format("Rotation Order: |cFFFFFF%s|r", modeLabel))
    modeEntry:AddSubLabel("Press X to switch between Sequential, Reverse, Random Shuffle, and Priority Bias")
    modeEntry.onSelect = function(dialog)
        local nextMode = (self.db.cycleMode % 4) + 1
        self.db.cycleMode = nextMode
        if dialog and dialog.setupFunc then dialog:setupFunc() end
    end
    table.insert(entries, {
        template = "ZO_GamepadMenuEntryTemplate",
        entryData = modeEntry,
    })

    -- 4. Immediate Next Guild Switch Row
    local switchNowEntry = ZO_GamepadEntryData:New("Switch to Next Favorite Guild Now")
    switchNowEntry:AddSubLabel("Immediately rotate your displayed guild nameplate")
    switchNowEntry.onSelect = function(dialog)
        self:ForceNextGuild()
        if dialog and dialog.setupFunc then dialog:setupFunc() end
    end
    table.insert(entries, {
        template = "ZO_GamepadMenuEntryTemplate",
        entryData = switchNowEntry,
    })

    -- 5. Filter Mode Toggle (Only Selected Favorites vs. All Joined Guilds)
    local filterText = self.db.onlySelectedGuilds and "|c00FF00Only Selected Favorites|r" or "|cFFFFFFAll Joined Guilds|r"
    local filterEntry = ZO_GamepadEntryData:New(string.format("Guild Filter: %s", filterText))
    filterEntry:AddSubLabel("Press X to switch between cycling only starred favorites below or all joined guilds")
    filterEntry.onSelect = function(dialog)
        self.db.onlySelectedGuilds = not self.db.onlySelectedGuilds
        if dialog and dialog.setupFunc then dialog:setupFunc() end
    end
    table.insert(entries, {
        template = "ZO_GamepadMenuEntryTemplate",
        entryData = filterEntry,
    })

    -- 6. Individual Favorite Guild Toggle Rows (Guilds 1-5)
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
            if dialog and dialog.setupFunc then dialog:setupFunc() end
            if GAMEPAD_STATS and GAMEPAD_STATS.RefreshMainList then
                pcall(function() GAMEPAD_STATS:RefreshMainList() end)
            end
        end
        table.insert(entries, {
            template = "ZO_GamepadMenuEntryTemplate",
            entryData = guildRow,
        })
    end

    -- 7. Combat Pause Quick Toggle Row
    local combatText = self.db.pauseInCombat and "|cFFAA00Paused in Combat|r" or "|c00FF00Active in Combat (Default)|r"
    local combatEntry = ZO_GamepadEntryData:New(string.format("Combat Behavior: %s", combatText))
    combatEntry:AddSubLabel("Press X to toggle whether guilds keep cycling during combat")
    combatEntry.onSelect = function(dialog)
        self.db.pauseInCombat = not self.db.pauseInCombat
        if dialog and dialog.setupFunc then dialog:setupFunc() end
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
    local targetData = GAMEPAD_STATS.mainList:GetTargetData()
    if targetData and targetData.isFavoriteGuildCyclerRow then
        return targetData
    end
    return nil
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
                text = "Select options to choose favorite guilds and adjust cycling. Safe cycling is limited to one guild change per second.",
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
                        dialog.info.parametricList = self:BuildParametricQuickDialogEntries()
                        dialog:setupFunc()
                    end,
                },
                {
                    keybind = "DIALOG_RESET",
                    text = "Step Speed",
                    callback = function(dialog)
                        self:StepCycleSpeedPreset(1)
                        dialog.info.parametricList = self:BuildParametricQuickDialogEntries()
                        dialog:setupFunc()
                    end,
                },
                {
                    keybind = "DIALOG_NEGATIVE",
                    text = SI_DIALOG_CLOSE,
                },
            },
        })
    end

    -- 2. Inject 3 Interactive Rows Directly Into the PS5 Character Sheet (Under Guild Nameplate)
    if GAMEPAD_STATS and ZO_PostHook then
        ZO_PostHook(GAMEPAD_STATS, "RefreshMainList", function(statsSelf)
            if not self.db or not self.db.showInCharacterSheet then return end
            if not statsSelf or not statsSelf.mainList or not ZO_GamepadEntryData then return end
            if statsSelf._fgcAppendingRows then return end

            statsSelf._fgcAppendingRows = true
            pcall(function()
                local favCount, totalGuilds = self:GetActiveFavoriteCount()
                local stateLabel = self.db.enabled and "|c00FF00ON|r" or "|cFF4444OFF|r"

                -- Row A: Master Toggle ON/OFF
                local toggleRow = ZO_GamepadEntryData:New(string.format("Cycle Favorite Guilds: %s", stateLabel))
                toggleRow:SetHeader("Favorite Guild Cycler")
                toggleRow.isFavoriteGuildCyclerRow = true
                toggleRow.fgcActionLabel = "Toggle ON/OFF"
                toggleRow.onCharacterSheetSelect = function()
                    self:ToggleEnabled(false)
                    statsSelf:RefreshMainList()
                end
                statsSelf.mainList:AddEntryWithHeader("ZO_GamepadMenuEntryTemplate", toggleRow)

                -- Row B: Cycle Speed Stepper (1s up to 300s)
                local speedRow = ZO_GamepadEntryData:New(string.format("Cycle Speed: |cEECA2A%s|r", self:GetFormattedSpeedText()))
                speedRow.isFavoriteGuildCyclerRow = true
                speedRow.fgcActionLabel = "Change Speed"
                speedRow.onCharacterSheetSelect = function()
                    self:StepCycleSpeedPreset(1)
                    PrintMessage("Cycle speed set to |cFFFFFF" .. self:GetFormattedSpeedText() .. "|r.")
                    statsSelf:RefreshMainList()
                end
                statsSelf.mainList:AddEntry("ZO_GamepadMenuEntryTemplate", speedRow)

                -- Row C: Select Favorite Guilds Popup
                local favRow = ZO_GamepadEntryData:New(string.format("Favorite Guilds: |c00FF00%d/%d Selected|r (Manage)", favCount, totalGuilds))
                favRow.isFavoriteGuildCyclerRow = true
                favRow.fgcActionLabel = "Select Favorite Guilds"
                favRow.onCharacterSheetSelect = function()
                    self:ShowCharacterSheetQuickDialog()
                end
                statsSelf.mainList:AddEntry("ZO_GamepadMenuEntryTemplate", favRow)

                if statsSelf.mainList.CommitWithoutReselect then
                    statsSelf.mainList:CommitWithoutReselect()
                else
                    statsSelf.mainList:Commit()
                end
            end)
            statsSelf._fgcAppendingRows = false
        end)

        if GAMEPAD_STATS.mainList and GAMEPAD_STATS.mainList.RegisterCallback then
            GAMEPAD_STATS.mainList:RegisterCallback("TargetDataChanged", function()
                if KEYBIND_STRIP and self.charSheetKeybindStripDescriptor then
                    KEYBIND_STRIP:UpdateKeybindButtonGroup(self.charSheetKeybindStripDescriptor)
                end
            end)
        end
    end

    -- 3. Add Controller Keybind Strip Shortcuts to the Character Sheet only.
    -- Do not attach this descriptor to gamepad_guild_hub: doing so can override
    -- the native guild-hub keybind strip and make guild rows require an extra
    -- selection before they respond to the primary action.
    self.charSheetKeybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_CENTER,
        {
            name = function()
                local row = self:GetSelectedCharacterSheetCyclerRow()
                return (row and row.fgcActionLabel) or "Select"
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            visible = function()
                return self:GetSelectedCharacterSheetCyclerRow() ~= nil
            end,
            callback = function()
                local row = self:GetSelectedCharacterSheetCyclerRow()
                if row and row.onCharacterSheetSelect then
                    row.onCharacterSheetSelect()
                end
            end,
        },
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
                if GAMEPAD_STATS and GAMEPAD_STATS.RefreshMainList then
                    pcall(function() GAMEPAD_STATS:RefreshMainList() end)
                end
            end,
        },
    }

    local function AttachKeybindsToScene(sceneName)
        if not SCENE_MANAGER then return end
        local scene = SCENE_MANAGER:GetScene(sceneName)
        if scene then
            scene:RegisterCallback("StateChange", function(oldState, newState)
                if not KEYBIND_STRIP then return end
                if newState == SCENE_SHOWN then
                    KEYBIND_STRIP:AddKeybindButtonGroup(self.charSheetKeybindStripDescriptor)
                elseif newState == SCENE_HIDING then
                    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.charSheetKeybindStripDescriptor)
                end
            end)
        end
    end

    -- Keep the Character Sheet integration, but leave the actual Guild menu
    -- completely untouched so its native selection/keybind behavior remains intact.
    AttachKeybindsToScene("gamepad_stats_root")
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
        label = "Quick Controls & Cycle Speed",
    })

    panel:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Enable Guild Cycler (Master ON/OFF)",
        tooltip = "Turn automatic guild nameplate cycling ON or OFF. You can also toggle this anytime in your Character Sheet or by typing /fgc in chat.",
        default = DEFAULT_SETTINGS.enabled,
        getFunction = function() return self.db.enabled end,
        setFunction = function(state)
            self.db.enabled = state
            if state then
                self:StartOrUpdateTimer()
                self:OnTimerTick()
            else
                self:StopTimer(true)
            end
        end,
    })

    panel:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Cycle Speed (1 to 300 Seconds)",
        tooltip = "Set how many seconds each selected guild stays displayed (1-300 seconds). The represented-guild API should not be called faster than once per second; this add-on enforces a 1-second minimum to reduce rate-limit risk.",
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
        end,
    })

    panel:AddSetting({
        type = LHAS.ST_SECTION,
        label = "Rate-Limit Safety: Minimum 1 Second",
    })

    panel:AddSetting({
        type = LHAS.ST_DROPDOWN,
        label = "Cycle Order Mode",
        tooltip = "Choose whether guilds rotate in order (1-5), reverse order (5-1), random shuffle with no repeats, or 50% priority bias toward your primary guild.",
        default = MODE_NAMES[DEFAULT_SETTINGS.cycleMode],
        items = {
            { name = MODE_NAMES[FGC.MODE_SEQUENTIAL], data = FGC.MODE_SEQUENTIAL },
            { name = MODE_NAMES[FGC.MODE_REVERSE],    data = FGC.MODE_REVERSE },
            { name = MODE_NAMES[FGC.MODE_RANDOM],     data = FGC.MODE_RANDOM },
            { name = MODE_NAMES[FGC.MODE_PRIORITY],   data = FGC.MODE_PRIORITY },
        },
        getFunction = function()
            return MODE_NAMES[self.db.cycleMode] or MODE_NAMES[FGC.MODE_SEQUENTIAL]
        end,
        setFunction = function(control, itemName, itemData)
            local modeVal = (type(itemData) == "table" and itemData.data) or itemData or FGC.MODE_SEQUENTIAL
            self.db.cycleMode = modeVal
        end,
    })

    panel:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Primary Guild Slot (For Priority Mode)",
        tooltip = "When Cycle Order Mode is set to Priority Bias, this guild slot is displayed every other cycle (50% of total time).",
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
        setFunction = function(state) self.db.includeUnrepresentedStep = state end,
    })

    -- SECTION 3: Character Sheet & Combat / Context Options
    panel:AddSetting({
        type = LHAS.ST_SECTION,
        label = "Character Sheet, Combat & Context Rules",
    })

    panel:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Show Guild Cycler in Character Sheet",
        tooltip = "Displays your Guild Cycler rows (ON/OFF, Speed, and Favorite Guilds) and quick-access controller shortcuts directly inside your PS5 Character Sheet underneath your Guild Nameplate.",
        default = DEFAULT_SETTINGS.showInCharacterSheet,
        getFunction = function() return self.db.showInCharacterSheet end,
        setFunction = function(state) self.db.showInCharacterSheet = state end,
    })

    panel:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Pause Cycling in Combat (Optional)",
        tooltip = "OFF by default so your guilds continue cycling during combat. Turn ON only if you prefer guild cycling to pause while in combat.",
        default = DEFAULT_SETTINGS.pauseInCombat,
        getFunction = function() return self.db.pauseInCombat end,
        setFunction = function(state) self.db.pauseInCombat = state end,
    })

    panel:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Pause While Browsing Menus (Optional)",
        tooltip = "OFF by default. Turn ON if you want guild cycling to pause while a full-screen menu is open.",
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

    -- SECTION 5: Profile & Notifications
    panel:AddSetting({
        type = LHAS.ST_SECTION,
        label = "Profile & Notifications",
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
        PrintMessage("Commands:")
        PrintMessage("  |cFFFFFF/fgc|r - Instantly toggle guild cycling ON or OFF")
        PrintMessage("  |cFFFFFF/fgc menu|r - Open the Quick Guild Cycler & Favorites dialog")
        PrintMessage("  |cFFFFFF/fgc next|r - Immediately switch to next favorite guild")
        PrintMessage("  |cFFFFFF/fgc speed <1-600>|r - Set cycle speed in seconds (minimum 1s for API safety)")
        PrintMessage("  |cFFFFFF/fgc fav <1-5>|r - Toggle favorite status for Guild 1-5")
        PrintMessage("  |cFFFFFF/fgc combat|r - Toggle whether cycling pauses in combat")
        PrintMessage("  |cFFFFFF/fgc mode <seq|rev|rand|priority>|r - Change rotation order")
        PrintMessage("  |cFFFFFF/fgc list|r - Show your guilds and favorite status")
        PrintMessage("  |cFFFFFF/fgc status|r - Display current cycler status")
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
            self:OnTimerTick()
            PrintMessage("Guild Cycling |c00FF00ON|r (Every " .. self:GetFormattedSpeedText() .. ").")
        else
            self:StopTimer(true)
            PrintMessage("Guild Cycling |cFF4444OFF|r.")
        end
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
            priority = FGC.MODE_PRIORITY,
            prio = FGC.MODE_PRIORITY,
        }
        local targetMode = modeMap[modeArg or ""]
        if not targetMode then
            PrintMessage("Choose a mode: |cFFFFFFseq|r, |cFFFFFFrev|r, |cFFFFFFrand|r, or |cFFFFFFpriority|r.")
            return
        end
        self.db.cycleMode = targetMode
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

    if cmd == "status" then
        local paused, reason = self:ShouldPauseCycling()
        local stateText = self.db.enabled and (paused and ("Paused (" .. tostring(reason) .. ")") or "Active") or "Disabled"
        local eligible = self:GetEligibleGuildSlots()
        PrintMessage(string.format(
            "Status: |cFFFFFF%s|r | Speed: |cFFFFFF%s|r | Mode: |cFFFFFF%s|r | In-Combat Cycling: |cFFFFFF%s|r | Eligible Guilds: |cFFFFFF%d|r",
            stateText,
            self:GetFormattedSpeedText(),
            MODE_NAMES[self.db.cycleMode] or "Sequential",
            self.db.pauseInCombat and "Paused" or "Active",
            #eligible
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
                if not IsUnitInCombat("player") then
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
    PrintMessage("Safety warning: guild switching is limited to once per second. Sub-second cycling is disabled to reduce API/rate-limit risk. ESO does not publish a fixed Error 318 message threshold.")

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
        self.inCombat = IsUnitInCombat("player")
        self:SyncFavoriteSlotsFromGuildIds()

        -- Seed the current cursor from the guild already represented in-game, when
        -- the getter exists, so the first timer tick advances from the real state.
        local currentGuildId = self:GetCurrentRepresentedGuildId()
        if currentGuildId and currentGuildId ~= 0 then
            self.lastDisplayedGuildId = currentGuildId
            for slot = 1, math.min(GetNumGuilds(), MAX_GUILD_SLOTS) do
                if GetGuildId(slot) == currentGuildId then
                    self.currentSlotIndex = slot
                    break
                end
            end
        end

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
