local ME = MyExtras
local QoL = {}
ME.QualityOfLife = QoL

--------------------------------------------------
-- Config
--------------------------------------------------
local SUBMENU_ICON   = "EsoUI/Art/Addons/Gamepad/gp_mod_listing_category_utility.dds"
local EVENT_NAME     = ME.name .. "_QualityOfLife"
local CLAIM_NAME     = EVENT_NAME .. "_Claim"
local CLAIM_SOON     = EVENT_NAME .. "_ClaimSoon"
local RIDING_NAME    = EVENT_NAME .. "_Riding"
local CLAIM_WAIT_MS  = 5000
local REWARD_WAIT_MS = 30000
local CLAIM_DELAY_MS = 250
local CLAIM_CHECK_MS = 1500
local RIDING_MAX_MS  = 3600000
local ERROR_KEEP     = 20
local ERROR_FEATURE  = "Lua Errors"
local ERROR_KEYBIND  = "Show Error"
local BLOCKED_TEXT   = "Dismount to interact."
local RIDING_FEATURE = "Riding"
local CLAIM_FEATURE  = "Auto Claim"
local RIDING_ICON    = "EsoUI/Art/Mounts/ridingSkill_ready.dds"
local VETERAN_ICON   = "EsoUI/Art/Campaign/Gamepad/gp_campaign_menuIcon_veterancy.dds"
local GOLDEN_ICON    = "EsoUI/Art/LFG/Gamepad/LFG_menuIcon_PromotionalEvents.dds"

QoL.charDefaults = {
    qolUseCharacter = false,
}


QoL.skipChoices = {
    { name = "Travel", value = "travel" },
    { name = "Logout", value = "logout" },
}

QoL.mountChoices = {
    { name = "Use",  value = "use"  },
    { name = "Open", value = "open" },
    { name = "Talk", value = "talk" },
}

QoL.claimChoices = {
    { name = "Tome Points",     value = "tome"      },
    { name = "Golden Pursuits", value = "golden"    },
    { name = "PvP Veterancy",   value = "veterancy" },
}

QoL.errorChoices = {
    { name = "Show",         value = "show" },
    { name = "Hide",         value = "hide" },
    { name = "List In Chat", value = "chat" },
}

local SKIP_KEYS  = { travel = "qolSkipTravel", logout = "qolSkipLogout" }
local MOUNT_KEYS = { use = "qolMountUse", open = "qolMountOpen", talk = "qolMountTalk" }
local CLAIM_KEYS = { tome = "qolClaimTome", golden = "qolClaimGolden", veterancy = "qolClaimVeterancy" }

local MOUNT_ACTIONS = {
    use  = SI_GAMECAMERAACTIONTYPE5,
    open = SI_GAMECAMERAACTIONTYPE13,
    talk = SI_GAMECAMERAACTIONTYPE2,
}

local CLAIM_EVENTS = {
    "EVENT_TIMED_ACTIVITY_PROGRESS_UPDATED",
    "EVENT_TIMED_ACTIVITIES_UPDATED",
    "EVENT_TIMED_ACTIVITY_SYSTEM_STATUS_UPDATED",
    "EVENT_PROMOTIONAL_EVENTS_ACTIVITY_PROGRESS_UPDATED",
    "EVENT_PROMOTIONAL_EVENTS_CAMPAIGNS_UPDATED",
    "EVENT_PROMOTIONAL_EVENTS_REWARDS_CLAIMED",
    "EVENT_REWARD_TRACK_PROGRESS_GAINED",
    "EVENT_REWARD_TRACK_UPDATE_RECEIVED",
}

local hooked      = {}
local active      = false
local claimWatch  = false
local ridingWatch = false
local ridingShown = false
local printing    = false
local showing     = false
local claimWait   = {}
local vetBlocked  = nil
local seenErrors  = {}
local errorList   = {}
local errorOrder  = {}
local nextError   = 0

--------------------------------------------------
-- Helpers
--------------------------------------------------
local GROUP_PREFIXES = {
    { "qolSkip",          "confirmations" },
    { "qolInstantConfirm", "confirmations" },
    { "qolStayMounted",   "mounts" },
    { "qolMount",         "mounts" },
    { "qolRidingReminder", "mounts" },
    { "qolClaim",         "claims" },
    { "qolLuaErrors",     "luaErrors" },
    { "questTracker",     "questTracker" },
    { "arc",              "readyCheck" },
    { "dnl",              "doNotLearn" },
    { "mi",               "missingItems" },
}

local function GroupFor(key)
    for i = 1, #GROUP_PREFIXES do
        local prefix = GROUP_PREFIXES[i][1]
        if string.sub(key, 1, #prefix) == prefix then return GROUP_PREFIXES[i][2] end
    end
    return nil
end

local scope = ME:NewScope("qolCharSettings", "qolUseCharacter")
QoL.scope = scope
QoL.defaults = scope.defaults

function QoL:UsesCharacterSettings(group)
    return scope:UsesCharacter(group)
end

local function SV()
    return scope:Settings()
end

function QoL:Settings()
    return SV()
end

function QoL:AddDefaults(list)
    scope:AddDefaults(list, GroupFor)
end

local BASE_DEFAULTS = {
    qolSkipTravel     = false,
    qolSkipLogout     = false,
    qolStayMounted    = false,
    qolMountUse       = false,
    qolMountOpen      = false,
    qolMountTalk      = false,
    qolRidingReminder = false,
    qolClaimTome      = false,
    qolClaimGolden    = false,
    qolClaimVeterancy = false,
    qolLuaErrors      = "chat",
}
QoL:AddDefaults(BASE_DEFAULTS)

function QoL:CharacterOption(group)
    return ME:CharacterOption(scope, group, function() QoL:RefreshAll() end)
end

function QoL:SavedTip(group)
    return ME:SavedTip(scope, group)
end

local function ChecklistGet(choices, keys)
    local sv = SV()
    local values = {}
    for i = 1, #choices do
        local value = choices[i].value
        if sv[keys[value]] then values[#values + 1] = value end
    end
    return values
end

local function ChecklistSet(values, keys)
    local sv = SV()
    local set = {}
    if type(values) == "table" then
        for i = 1, #values do set[values[i]] = true end
    end
    for value, key in pairs(keys) do
        sv[key] = set[value] == true
    end
end

local function ChecklistDefault(choices, keys)
    local values = {}
    for i = 1, #choices do
        local value = choices[i].value
        if QoL.defaults[keys[value]] then values[#values + 1] = value end
    end
    return values
end

--------------------------------------------------
-- Skip Travel
--------------------------------------------------
local function CanSkip(pin)
    if not (pin and pin.GetFastTravelNodeIndex) then return false end
    if pin.IsLockedByLinkedCollectible and pin:IsLockedByLinkedCollectible() then return false end
    return type(pin:GetFastTravelNodeIndex()) == "number"
end

local function CanAffordRecall(nodeIndex)
    if not (GetRecallCost and GetRecallCurrency and GetCurrencyAmount) then return true end
    local currency = GetRecallCurrency(nodeIndex)
    return GetRecallCost(nodeIndex) <= GetCurrencyAmount(currency, CURRENCY_LOCATION_CHARACTER)
end

local function TravelNow(nodeIndex, playSound)
    ZO_Dialogs_ReleaseDialog("FAST_TRAVEL_CONFIRM")
    ZO_Dialogs_ReleaseDialog("RECALL_CONFIRM")
    ZO_Dialogs_ReleaseDialog("TRAVEL_TO_HOUSE_CONFIRM")
    if not ME:CallGame("FastTravelToNode", nodeIndex) then return false end
    if playSound then PlaySound(SOUNDS.MAP_WAYSHRINE_TELEPORT) end
    SCENE_MANAGER:ShowBaseScene()
    return true
end

local function HookTravel()
    if hooked.travel then return end
    local handlers = ZO_MapPin and ZO_MapPin.PIN_CLICK_HANDLERS
    handlers = handlers and handlers[MOUSE_BUTTON_INDEX_LEFT]
    handlers = handlers and handlers[MAP_PIN_TYPE_FAST_TRAVEL_WAYSHRINE]
    if type(handlers) ~= "table" then return end
    local recall, travel = handlers[1], handlers[2]
    if type(recall) ~= "table" or type(travel) ~= "table" then return end
    if type(recall.callback) ~= "function" or type(travel.callback) ~= "function" then return end

    local recallCallback = recall.callback
    local travelCallback = travel.callback

    recall.callback = function(pin, ...)
        if SV().qolSkipTravel and CanSkip(pin) and GetRecallCooldown then
            local nodeIndex = pin:GetFastTravelNodeIndex()
            local _, premiumTimeLeft = GetRecallCooldown()
            if premiumTimeLeft == 0 and CanAffordRecall(nodeIndex) and TravelNow(nodeIndex, false) then return end
        end
        return recallCallback(pin, ...)
    end

    travel.callback = function(pin, ...)
        if SV().qolSkipTravel and CanSkip(pin) then
            if TravelNow(pin:GetFastTravelNodeIndex(), true) then return end
        end
        return travelCallback(pin, ...)
    end

    hooked.travel = true
end

--------------------------------------------------
-- Skip Logout
--------------------------------------------------
local function HookLogout()
    if hooked.logout then return end
    local ids = ZO_MENU_MAIN_ENTRIES
    if type(ZO_MENU_ENTRIES) ~= "table" or type(ids) ~= "table" or ids.LOG_OUT == nil then return end
    for _, entry in ipairs(ZO_MENU_ENTRIES) do
        local data = entry.data
        if entry.id == ids.LOG_OUT and type(data) == "table" and type(data.activatedCallback) == "function" then
            local original = data.activatedCallback
            data.activatedCallback = function(...)
                if SV().qolSkipLogout and ME:CallGame("Logout") then return end
                return original(...)
            end
            hooked.logout = true
            return
        end
    end
end

--------------------------------------------------
-- Stay Mounted
--------------------------------------------------
local function MountAllowed()
    local action = GetGameCameraInteractableActionInfo()
    if type(action) ~= "string" or action == "" then return false end
    local sv = SV()
    for value, key in pairs(MOUNT_KEYS) do
        if sv[key] and MOUNT_ACTIONS[value] and action == GetString(MOUNT_ACTIONS[value]) then return true end
    end
    return false
end

local function BlockInteract()
    if not SV().qolStayMounted or not IsMounted() then return false end
    return not MountAllowed()
end

local function HookMount()
    if hooked.mount or not RETICLE then return end
    if type(RETICLE.GetInteractPromptVisible) ~= "function" or type(RETICLE.UpdateInteractText) ~= "function" then return end
    ZO_PreHook(RETICLE, "GetInteractPromptVisible", function()
        return BlockInteract()
    end)
    ZO_PostHook(RETICLE, "UpdateInteractText", function(self)
        if not (self.interact and not self.interact:IsHidden()) then return end
        if not BlockInteract() then return end
        if self.additionalInfo then
            self.additionalInfo:SetHidden(false)
            self.additionalInfo:SetText(BLOCKED_TEXT)
        end
        if self.interactKeybindButton then
            self.interactKeybindButton:SetEnabled(false)
        end
    end)
    hooked.mount = true
end

--------------------------------------------------
-- Riding Reminder
--------------------------------------------------
local function RidingLeft()
    if not GetRidingStats then return false end
    local inventory, inventoryMax, stamina, staminaMax, speed, speedMax = GetRidingStats()
    return (inventory or 0) < (inventoryMax or 0)
        or (stamina or 0) < (staminaMax or 0)
        or (speed or 0) < (speedMax or 0)
end

local function Announce(text)
    ME:Chat(ME:ChatPrefix(RIDING_FEATURE) .. text)
end

local function CurrencyIcon(currency)
    if not currency then return "" end
    local ok, icon = pcall(ZO_Currency_GetPlatformFormattedCurrencyIcon, currency)
    if ok and type(icon) == "string" and icon ~= "" then return icon .. " " end
    return ""
end

function QoL:CheckRiding()
    EVENT_MANAGER:UnregisterForUpdate(RIDING_NAME)
    if not (active and ridingWatch and GetTimeUntilCanBeTrained) or not RidingLeft() then
        ridingShown = false
        return
    end
    local wait = GetTimeUntilCanBeTrained() or 0
    if wait <= 0 then
        if not ridingShown then
            ridingShown = true
            Announce(ME:Icon(RIDING_ICON) .. "Lesson ready.")
        end
        return
    end
    ridingShown = false
    EVENT_MANAGER:RegisterForUpdate(RIDING_NAME, zo_min(wait + 1000, RIDING_MAX_MS), function()
        QoL:CheckRiding()
    end)
end

local function OnRidingImproved()
    ridingShown = false
    zo_callLater(function() QoL:CheckRiding() end, 1000)
end

function QoL:WatchRiding(on)
    if on == ridingWatch then
        if on then self:CheckRiding() end
        return
    end
    ridingWatch = on
    if on then
        EVENT_MANAGER:RegisterForEvent(RIDING_NAME, EVENT_RIDING_SKILL_IMPROVEMENT, OnRidingImproved)
        self:CheckRiding()
    else
        EVENT_MANAGER:UnregisterForEvent(RIDING_NAME, EVENT_RIDING_SKILL_IMPROVEMENT)
        EVENT_MANAGER:UnregisterForUpdate(RIDING_NAME)
        ridingShown = false
    end
end

--------------------------------------------------
-- Auto Claim
--------------------------------------------------
local function Claim(key, waitMs, confirm, text, name, ...)
    local now = GetFrameTimeMilliseconds()
    local untilMs = claimWait[key]
    if untilMs and now < untilMs then return end
    claimWait[key] = now + waitMs
    if not ME:CallGame(name, ...) then return end
    zo_callLater(function()
        if confirm() then ME:Chat(ME:ChatPrefix(CLAIM_FEATURE) .. text) end
    end, CLAIM_CHECK_MS)
end

local function IsClaimed(flags)
    return ZO_FlagHelpers.MaskHasFlag(flags or 0, PROMOTIONAL_EVENTS_REWARD_FLAG_CLAIMED)
end

local function CleanName(name)
    if type(name) ~= "string" or name == "" then return nil end
    return zo_strformat("<<1>>", name)
end

local function OffersChoice(rewardId, depth)
    if type(rewardId) ~= "number" or rewardId == 0 or not GetRewardType then return false end
    local rewardType = GetRewardType(rewardId)
    if rewardType == REWARD_ENTRY_TYPE_CHOICE then return true end
    depth = depth or 0
    if rewardType == REWARD_ENTRY_TYPE_REWARD_LIST and depth < 3 and GetNumRewardListEntries then
        for i = 1, GetNumRewardListEntries(rewardId) do
            if OffersChoice(GetRewardListEntryInfo(rewardId, i), depth + 1) then return true end
        end
    end
    return false
end

local function Ready(threshold, progress, flags, rewardId)
    if type(rewardId) ~= "number" or rewardId == 0 then return false end
    if (threshold or 0) <= 0 or (progress or 0) < threshold then return false end
    if IsClaimed(flags) then return false end
    return not OffersChoice(rewardId)
end

local function ClearTomeBanner()
    local csa = CENTER_SCREEN_ANNOUNCE
    local bannerType = rawget(_G, "CENTER_SCREEN_ANNOUNCE_TYPE_TIMED_ACTIVITY_COMPLETED")
    if csa and csa.ClearActiveLinesByType and bannerType then
        pcall(csa.ClearActiveLinesByType, csa, bannerType)
    end
end

local function ClaimTomePoints()
    if not (IsTimedActivitySystemAvailable and IsTimedActivitySystemAvailable()) or not CURT_TOME_POINTS then return end
    for index = 1, GetNumTimedActivities() do
        if GetTimedActivityCurrencyRewardInfo(index) == CURT_TOME_POINTS then
            local maxProgress = GetTimedActivityMaxProgress(index) or 0
            local total = GetTimedActivityTotalNumTimesClaimable(index) or 0
            local claimed = GetTimedActivityNumTimesClaimed(index) or 0
            if maxProgress > 0 and (GetTimedActivityProgress(index) or 0) >= maxProgress and claimed < total then
                local id = GetTimedActivityId and GetTimedActivityId(index) or index
                local text = CurrencyIcon(CURT_TOME_POINTS)
                    .. (CleanName(GetTimedActivityName(index)) or "Tamriel Tomes activity") .. "."
                Claim("tome" .. tostring(id), CLAIM_WAIT_MS, function()
                    local done = (GetTimedActivityNumTimesClaimed(index) or 0) > claimed
                    if done then ClearTomeBanner() end
                    return done
                end, text, "ClaimTimedActivityReward", index)
            end
        end
    end
end

local function ClaimCampaign(campaignKey)
    if not ShouldPromotionalEventCampaignBeVisible(campaignKey) then return end
    local name = Id64ToString and Id64ToString(campaignKey) or tostring(campaignKey)

    for activityIndex = 1, GetNumPromotionalEventCampaignActivities(campaignKey) do
        local _, activityName, _, threshold, rewardId = GetPromotionalEventCampaignActivityInfo(campaignKey, activityIndex)
        local progress, flags = GetPromotionalEventCampaignActivityProgress(campaignKey, activityIndex)
        if Ready(threshold, progress, flags, rewardId) then
            local text = ME:Icon(GOLDEN_ICON) .. (CleanName(activityName) or "Golden Pursuits activity") .. "."
            Claim(name .. "a" .. activityIndex, CLAIM_WAIT_MS, function()
                local _, nowFlags = GetPromotionalEventCampaignActivityProgress(campaignKey, activityIndex)
                return IsClaimed(nowFlags)
            end, text, "TryClaimPromotionalEventActivityReward", campaignKey, activityIndex)
        end
    end

    local completed, capstoneFlags = GetPromotionalEventCampaignProgress(campaignKey)
    for milestoneIndex = 1, GetNumPromotionalEventCampaignMilestoneRewards(campaignKey) do
        local threshold, rewardId = GetPromotionalEventCampaignMilestoneInfo(campaignKey, milestoneIndex)
        local flags = GetPromotionalEventCampaignMilestoneRewardFlags(campaignKey, milestoneIndex)
        if Ready(threshold, completed, flags, rewardId) then
            Claim(name .. "m" .. milestoneIndex, CLAIM_WAIT_MS, function()
                return IsClaimed(GetPromotionalEventCampaignMilestoneRewardFlags(campaignKey, milestoneIndex))
            end, ME:Icon(GOLDEN_ICON) .. "Milestone.", "TryClaimPromotionalEventMilestoneReward", campaignKey, milestoneIndex)
        end
    end

    local _, _, _, threshold, rewardId = GetPromotionalEventCampaignInfo(campaignKey)
    if Ready(threshold, completed, capstoneFlags, rewardId) then
        Claim(name .. "c", CLAIM_WAIT_MS, function()
            local _, nowFlags = GetPromotionalEventCampaignProgress(campaignKey)
            return IsClaimed(nowFlags)
        end, ME:Icon(GOLDEN_ICON) .. "Final reward.", "TryClaimPromotionalEventCapstoneReward", campaignKey)
    end
end

local function ClaimGoldenPursuits()
    if not GetNumActivePromotionalEventCampaigns then return end
    if IsPromotionalEventSystemLocked and IsPromotionalEventSystemLocked() then return end
    for campaignIndex = 1, GetNumActivePromotionalEventCampaigns() do
        ClaimCampaign(GetActivePromotionalEventCampaignKey(campaignIndex))
    end
end

local function VeterancyMark(trackType, trackId, trackIndex)
    local tier = 0
    if GetInfoForRewardTrack then
        local _, currentTier = GetInfoForRewardTrack(trackType, trackIndex)
        tier = currentTier or 0
    end
    return tostring(trackId) .. ":" .. tostring(tier)
end

local function ClaimVeterancy()
    if not (IsVeterancySeasonActive and IsVeterancySeasonActive()) or not REWARD_TRACK_TYPE_AVA_VETERANCY then return end
    local trackType = REWARD_TRACK_TYPE_AVA_VETERANCY
    local trackId = GetActiveReferenceTrackIdsForRewardTrackType(trackType)
    if not trackId or trackId == 0 then return end
    local trackIndex = GetReferenceTrackIndex(trackType, trackId)
    if not trackIndex then return end
    if not HasUnclaimedRewardTrackRewards(trackType, trackIndex) then
        vetBlocked = nil
        return
    end
    if vetBlocked == VeterancyMark(trackType, trackId, trackIndex) then return end
    Claim("veterancy", REWARD_WAIT_MS, function()
        local done = not HasUnclaimedRewardTrackRewards(trackType, trackIndex)
        if done then
            vetBlocked = nil
        else
            vetBlocked = VeterancyMark(trackType, trackId, trackIndex)
        end
        return done
    end, ME:Icon(VETERAN_ICON) .. "PvP Veterancy rewards.", "ClaimAllRewardTrackRewards", trackType, trackIndex)
end

function QoL:ClaimAll()
    EVENT_MANAGER:UnregisterForUpdate(CLAIM_SOON)
    if not active then return end
    local sv = SV()
    if sv.qolClaimTome then pcall(ClaimTomePoints) end
    if sv.qolClaimGolden then pcall(ClaimGoldenPursuits) end
    if sv.qolClaimVeterancy then pcall(ClaimVeterancy) end
end

local function ClaimSoon()
    EVENT_MANAGER:UnregisterForUpdate(CLAIM_SOON)
    EVENT_MANAGER:RegisterForUpdate(CLAIM_SOON, CLAIM_DELAY_MS, function() QoL:ClaimAll() end)
end

function QoL:WatchClaims(on)
    if on and not claimWatch then
        for i = 1, #CLAIM_EVENTS do
            local event = rawget(_G, CLAIM_EVENTS[i])
            if event then EVENT_MANAGER:RegisterForEvent(CLAIM_NAME .. i, event, ClaimSoon) end
        end
        claimWatch = true
    elseif not on and claimWatch then
        for i = 1, #CLAIM_EVENTS do
            local event = rawget(_G, CLAIM_EVENTS[i])
            if event then EVENT_MANAGER:UnregisterForEvent(CLAIM_NAME .. i, event) end
        end
        EVENT_MANAGER:UnregisterForUpdate(CLAIM_SOON)
        claimWatch = false
    end
    if on then ClaimSoon() end
end

--------------------------------------------------
-- Lua Errors
--------------------------------------------------
local function ErrorTitle(errorCode)
    local code = tonumber(errorCode) and string.format("%X", tonumber(errorCode)) or ""
    if code == "" then return "Unknown error." end
    if ZO_SELECTED_TEXT then code = ZO_SELECTED_TEXT:Colorize(code) end
    return code
end

local function SelectedError()
    local list = CHAT_MENU_GAMEPAD and CHAT_MENU_GAMEPAD.list
    if not (list and list.GetTargetData) then return nil end
    local target = list:GetTargetData()
    local id = target and type(target.data) == "table" and target.data.myExtrasErrorId
    return id and errorList[id] or nil
end

local function ShowError(entry)
    local frame = ZO_ERROR_FRAME
    if not frame then return end
    local suppressed = frame.suppressErrorDialog
    frame.suppressErrorDialog = false
    showing = true
    pcall(frame.OnUIError, frame, entry.text, entry.code)
    showing = false
    frame.suppressErrorDialog = suppressed
end

local function LatestChatEntry()
    local entries = CHAT_MENU_GAMEPAD and CHAT_MENU_GAMEPAD.messageEntries
    if type(entries) ~= "table" then return nil end
    return entries[#entries]
end

local function KeepError(errorString, errorCode)
    nextError = nextError + 1
    errorList[nextError] = { text = errorString, code = errorCode }
    errorOrder[#errorOrder + 1] = nextError
    if #errorOrder > ERROR_KEEP then
        errorList[table.remove(errorOrder, 1)] = nil
    end
    return nextError
end

local function ListError(errorString, errorCode)
    local id = KeepError(errorString, errorCode)
    local before = LatestChatEntry()
    printing = true
    pcall(ME.Chat, ME, ME:ChatPrefix(ERROR_FEATURE) .. ErrorTitle(errorCode))
    printing = false
    local entry = LatestChatEntry()
    if entry and entry ~= before and type(entry.data) == "table" then
        entry.data.myExtrasErrorId = id
    end
end

local function HookErrorKeybind()
    if hooked.errorKeybind then return end
    local descriptor = CHAT_MENU_GAMEPAD and CHAT_MENU_GAMEPAD.chatEntryListKeybindDescriptor
    if type(descriptor) ~= "table" then return end
    for i = 1, #descriptor do
        local button = descriptor[i]
        if button.keybind == "UI_SHORTCUT_PRIMARY" then
            local name, enabled, visible, callback = button.name, button.enabled, button.visible, button.callback
            button.name = function(...)
                if SelectedError() then return ERROR_KEYBIND end
                if type(name) == "function" then return name(...) end
                return name
            end
            button.enabled = function(...)
                if SelectedError() then return true end
                if type(enabled) == "function" then return enabled(...) end
                return enabled == nil or enabled == true
            end
            button.visible = function(...)
                if SelectedError() then return true end
                if type(visible) == "function" then return visible(...) end
                return visible == nil or visible == true
            end
            button.callback = function(...)
                local entry = SelectedError()
                if entry then
                    ShowError(entry)
                    return
                end
                if callback then return callback(...) end
            end
            hooked.errorKeybind = true
            return
        end
    end
end

local function HookErrors()
    if hooked.errors or not (ZO_ERROR_FRAME and type(ZO_ERROR_FRAME.OnUIError) == "function") then return end
    ZO_PreHook(ZO_ERROR_FRAME, "OnUIError", function(self, errorString, errorCode)
        if showing then return false end
        local mode = SV().qolLuaErrors
        if mode ~= "hide" and mode ~= "chat" then return false end
        if mode == "chat" and not printing and errorString then
            local suppressed = errorCode ~= nil and type(self.suppressedErrors) == "table" and self.suppressedErrors[errorCode]
            local key = tostring(errorString)
            if not suppressed and not seenErrors[key] then
                seenErrors[key] = true
                HookErrorKeybind()
                ListError(errorString, errorCode)
            end
        end
        return true
    end)
    if CHAT_MENU_GAMEPAD and type(CHAT_MENU_GAMEPAD.OnShow) == "function" then
        ZO_PreHook(CHAT_MENU_GAMEPAD, "OnShow", function() HookErrorKeybind() end)
    end
    hooked.errors = true
end

--------------------------------------------------
-- Apply
--------------------------------------------------
function QoL:Refresh()
    local sv = SV()
    if sv.qolSkipTravel then HookTravel() end
    if sv.qolSkipLogout then HookLogout() end
    if sv.qolStayMounted then HookMount() end
    if sv.qolLuaErrors ~= "show" then HookErrors() end
    self:WatchClaims(sv.qolClaimTome == true or sv.qolClaimGolden == true or sv.qolClaimVeterancy == true)
    self:WatchRiding(sv.qolRidingReminder == true)
end

function QoL:RefreshAll()
    self:Refresh()
    if ME.QuestTracker then ME.QuestTracker:Apply() end
    if ME.AutoReadyCheck then ME.AutoReadyCheck:Refresh() end
    if ME.InstantConfirm then ME.InstantConfirm:Refresh() end
end

--------------------------------------------------
-- Settings
--------------------------------------------------
local function Page(name, group, description, options)
    if group then table.insert(options, 1, QoL:CharacterOption(group)) end
    return {
        type    = "submenu",
        name    = name,
        tooltip = function()
            if group then return description .. "\n\n" .. QoL:SavedTip(group) end
            return description
        end,
        options = options,
    }
end

local function AddCharacterOption(submenu, group)
    if not submenu or type(submenu.options) ~= "table" then return submenu end
    local position = 1
    if submenu.options[1] and submenu.options[1].name == "Enabled" then position = 2 end
    table.insert(submenu.options, position, QoL:CharacterOption(group))
    local description = submenu.tooltip
    submenu.tooltip = function()
        local text = type(description) == "function" and description() or description or ""
        return text .. "\n\n" .. QoL:SavedTip(group)
    end
    return submenu
end

function QoL:GetOptions()
    local defaults = self.defaults

    local function MountOff() return not SV().qolStayMounted end

    local confirmations = {
        {
            type    = "checklist",
            name    = "Skip Confirmations",
            choices = self.skipChoices,
            default = ChecklistDefault(self.skipChoices, SKIP_KEYS),
            tooltip = "Skips the pop-up asking you to confirm.\n\n"
                   .. "Travel: when you travel or recall to a wayshrine. If you don't have enough gold for a recall, it still asks.\n"
                   .. "Logout: when you log out from the menu.",
            getFunc = function() return ChecklistGet(QoL.skipChoices, SKIP_KEYS) end,
            setFunc = function(values)
                ChecklistSet(values, SKIP_KEYS)
                QoL:Refresh()
            end,
        },
    }
    if ME.InstantConfirm then confirmations[#confirmations + 1] = ME.InstantConfirm:Option() end

    local mounts = {
        {
            type    = "toggle",
            name    = "Stay Mounted",
            preset  = "YES_NO",
            default = defaults.qolStayMounted,
            tooltip = "Stops interact prompts from knocking you off your mount while you're riding. "
                   .. "Pressing interact jumps instead, and the prompt shows \"" .. BLOCKED_TEXT .. "\"",
            getFunc = function() return SV().qolStayMounted end,
            setFunc = function(val)
                SV().qolStayMounted = val
                QoL:Refresh()
            end,
        },
        {
            type     = "checklist",
            name     = "Allow While Mounted",
            choices  = self.mountChoices,
            default  = ChecklistDefault(self.mountChoices, MOUNT_KEYS),
            tooltip  = "Prompts that still work while you're riding.\n\n"
                    .. "Use: things you use, like levers and shrines.\n"
                    .. "Open: things you open, like doors.\n"
                    .. "Talk: characters you can talk to.",
            disabled = MountOff,
            getFunc  = function() return ChecklistGet(QoL.mountChoices, MOUNT_KEYS) end,
            setFunc  = function(values) ChecklistSet(values, MOUNT_KEYS) end,
        },
        {
            type    = "toggle",
            name    = "Riding Reminder",
            preset  = "YES_NO",
            default = defaults.qolRidingReminder,
            tooltip = "Tells you when your daily riding lesson is ready. It stops once your riding skills are maxed.",
            getFunc = function() return SV().qolRidingReminder end,
            setFunc = function(val)
                SV().qolRidingReminder = val
                QoL:Refresh()
            end,
        },
    }

    local claims = {
        {
            type    = "checklist",
            name    = "Rewards",
            choices = self.claimChoices,
            default = ChecklistDefault(self.claimChoices, CLAIM_KEYS),
            tooltip = "Claims these rewards for you as soon as they're ready.\n\n"
                   .. "Tome Points: finished Tamriel Tomes activities.\n"
                   .. "Golden Pursuits: finished activities, milestones and the final reward. Rewards where you choose an item are left for you to pick.\n"
                   .. "PvP Veterancy: your veterancy rank rewards. If a claim doesn't go through, it tries again when you reach a new rank.",
            getFunc = function() return ChecklistGet(QoL.claimChoices, CLAIM_KEYS) end,
            setFunc = function(values)
                ChecklistSet(values, CLAIM_KEYS)
                vetBlocked = nil
                QoL:Refresh()
            end,
        },
    }

    local luaErrors = {
        {
            type    = "dropdown",
            name    = "Errors",
            choices = self.errorChoices,
            default = defaults.qolLuaErrors,
            tooltip = "What happens when an addon has an error.",
            details = function()
                local mode = SV().qolLuaErrors
                if mode == "hide" then
                    return "Error windows are hidden."
                elseif mode == "chat" then
                    return "Error windows are hidden, and each error is listed in chat once. "
                        .. "Highlight it in text chat and press " .. ERROR_KEYBIND .. " to see the full error."
                end
                return "Error windows pop up like normal."
            end,
            getFunc = function() return SV().qolLuaErrors end,
            setFunc = function(val)
                SV().qolLuaErrors = val
                QoL:Refresh()
            end,
        },
    }

    local options = {
        Page("Confirmations", "confirmations", "Skips confirmation pop-ups and their countdowns.", confirmations),
        Page("Mounts", "mounts", "Keeps you on your mount and reminds you about riding lessons.", mounts),
        Page("Auto Claim", "claims", "Claims rewards for you as soon as they're ready.", claims),
    }
    local function Add(submenu, group)
        if not submenu then return end
        if group then AddCharacterOption(submenu, group) end
        options[#options + 1] = submenu
    end
    if ME.AutoReadyCheck then Add(ME.AutoReadyCheck:SubmenuOption(), "readyCheck") end
    if ME.DoNotLearn then Add(ME.DoNotLearn:SubmenuOption(), "doNotLearn") end
    if ME.MissingItems then Add(ME.MissingItems:SubmenuOption(), "missingItems") end
    if ME.Knowledge then Add(ME.Knowledge:SubmenuOption()) end
    if ME.QuestTracker then Add(ME.QuestTracker:SubmenuOption(), "questTracker") end
    options[#options + 1] = Page("Lua Errors", "luaErrors", "What happens when an addon has an error.", luaErrors)

    return {
        {
            type    = "submenu",
            name    = "Quality of Life",
            icon    = SUBMENU_ICON,
            tooltip = "Skips confirmations, keeps you on your mount, claims rewards for you, accepts ready checks, "
                   .. "stops you from learning things by accident, marks items you're missing, shows what your "
                   .. "characters know, moves your quest tracker and handles Lua errors.",
            options = options,
        },
    }
end

--------------------------------------------------
-- Lifecycle
--------------------------------------------------
function QoL:Init()
    self:Refresh()
end

function QoL:OnPlayerActivated()
    active = true
    self:Refresh()
end

function QoL:ResetSkipKeys()
    return scope:ResetSkipKeys()
end

function QoL:OnReset()
    scope:ResetCharacter()
    self:RefreshAll()
end

ME:RegisterFeature(QoL)
