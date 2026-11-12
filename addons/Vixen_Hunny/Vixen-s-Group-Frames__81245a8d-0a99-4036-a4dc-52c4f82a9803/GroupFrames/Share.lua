---------------------------------------------------------------------------
-- Share.lua - sharing tracked effects with groupmates
--
-- Flow: the sender presses "Share my effects" (GF.ShareTrackedEffects), the
-- list travels through LibGroupBroadcast, and on every other GroupFrames
-- user OnData files the effects under GF.sharedEffects until that player
-- adds them (GF.AcceptSharedEffect) - or adds them straight away when they
-- chose "add shared effects automatically".
--
-- Without LibGroupBroadcast nothing here does anything; GF.canShare tells
-- the settings menu whether sharing is available.
---------------------------------------------------------------------------

local GF = GroupFrames

-- Sharing of the user-added effects with groupmates through LibGroupBroadcast.
--
-- Effects travel as ability ids, so the list also works between clients in
-- different languages. Entries that track one exact ability go into `ids`,
-- entries that track an effect by name go into `names` (as the id of any
-- ability with that name; the receiver turns it back into the name).
--
-- NOTE: protocol ids must be unique across all addons. Reserve this one at
-- https://wiki.esoui.com/LibGroupBroadcast_IDs before releasing the addon.
local PROTOCOL_ID = 230
local PROTOCOL_NAME = "GroupFramesEffects"
local MAX_SHARED = 30 -- per list
local MAX_ABILITY_ID = 1048575 -- 20 bits

local protocol -- the declared LibGroupBroadcast protocol, nil if unavailable

-- Effects received from groupmates that are waiting to be added:
-- key (as in sv.trackedEffects) -> { display, from, id }
GF.sharedEffects = {}

-- Returns an ability id that carries the given (lower-case) effect name, or
-- nil if that effect has never been seen in game. Found ids are saved so
-- the entry can still be shared in later sessions.
local function FindAbilityIdForName(key)
    local sv = GF.sv
    if sv.effectIds[key] then return sv.effectIds[key] end
    for name, abilityId in pairs(GF.seenEffects) do
        if name:lower() == key then
            sv.effectIds[key] = abilityId
            return abilityId
        end
    end
end

-- Splits the tracked effects into the two id lists of the message. Returns
-- ids, names and how many entries had to be left out.
local function BuildPayload()
    local ids, names, skipped = {}, {}, 0
    for key in pairs(GF.sv.trackedEffects) do
        if type(key) == "number" then
            if #ids < MAX_SHARED and key <= MAX_ABILITY_ID then
                ids[#ids + 1] = key
            else
                skipped = skipped + 1
            end
        else
            local abilityId = FindAbilityIdForName(key)
            if abilityId and #names < MAX_SHARED and abilityId <= MAX_ABILITY_ID then
                names[#names + 1] = abilityId
            else
                skipped = skipped + 1
            end
        end
    end
    return ids, names, skipped
end

-- Sends your tracked effects to the group. Returns success and a message
-- for the user.
function GF.ShareTrackedEffects()
    if not protocol then
        return false, GF.shareError or "LibGroupBroadcast is not installed"
    end
    if not IsUnitGrouped("player") then
        return false, "you are not in a group"
    end
    if not protocol:IsEnabled() then
        return false, "sending is disabled for GroupFrames in the LibGroupBroadcast settings"
    end

    local ids, names, skipped = BuildPayload()
    if #ids + #names == 0 then
        if skipped > 0 then
            return false, "none of your effects could be shared yet - they have to be seen in game once first"
        end
        return false, "you have no additional effects to share"
    end

    if not protocol:Send({ ids = ids, names = names }) then
        return false, "the message could not be queued"
    end

    local message = "shared " .. (#ids + #names) .. " effect(s) with your group"
    if skipped > 0 then
        message = message .. " (" .. skipped .. " skipped: not seen in game yet, or over the limit of " .. MAX_SHARED .. ")"
    end
    return true, message
end

-- Handles one received effect: adds it, or queues it for the player to
-- accept. Returns false when there is nothing to do: already tracked, a
-- listed Major/Minor buff (those have their own checkboxes) or blacklisted.
local function Offer(key, display, name, abilityId, from)
    local sv = GF.sv
    if sv.trackedEffects[key] or GF.IsListedBuff(name) or GF.IsBlacklisted(name, abilityId) then
        return false
    end
    if sv.autoAcceptShared then
        sv.trackedEffects[key] = display
        if type(key) == "string" then sv.effectIds[key] = abilityId end
    else
        GF.sharedEffects[key] = { display = display, from = from, id = abilityId }
    end
    return true
end

-- Called by LibGroupBroadcast when a groupmate's list arrives. `data` holds
-- the two arrays declared in InitSharing. Ids are turned back into names
-- with this client's own language.
local function OnData(unitTag, data)
    if AreUnitsEqual(unitTag, "player") then return end -- our own message

    local from = zo_strformat("<<1>>", GetUnitName(unitTag))
    local count = 0

    for _, abilityId in ipairs(data.ids or {}) do
        local name = zo_strformat("<<1>>", GetAbilityName(abilityId))
        if name ~= "" and Offer(abilityId, name .. " (" .. abilityId .. ")", name, abilityId, from) then
            count = count + 1
        end
    end
    for _, abilityId in ipairs(data.names or {}) do
        local name = zo_strformat("<<1>>", GetAbilityName(abilityId))
        if name ~= "" and Offer(name:lower(), name, name, abilityId, from) then
            count = count + 1
        end
    end

    if count == 0 then return end
    if GF.sv.autoAcceptShared then
        d(string.format("GroupFrames: added %d effect(s) shared by %s.", count, from))
    else
        d(string.format("GroupFrames: %s shared %d effect(s). Open the GroupFrames settings to add them.", from, count))
    end
    if GF.OnSharedEffectsChanged then GF.OnSharedEffectsChanged() end
end

-- Starts tracking an effect a groupmate shared. Without a key, all of them.
function GF.AcceptSharedEffect(key)
    local sv = GF.sv
    local function Accept(k, entry)
        sv.trackedEffects[k] = entry.display
        if type(k) == "string" then sv.effectIds[k] = entry.id end
        GF.sharedEffects[k] = nil
    end
    if key ~= nil then
        local entry = GF.sharedEffects[key]
        if entry then Accept(key, entry) end
    else
        local keys = {}
        for k in pairs(GF.sharedEffects) do keys[#keys + 1] = k end
        for _, k in ipairs(keys) do Accept(k, GF.sharedEffects[k]) end
    end
end

-- Registers GroupFrames with LibGroupBroadcast and declares the message
-- format: two arrays of ability ids, each id 20 bits wide. Called once at
-- start-up. The handler is kept in GF.lgbHandler because an addon may only
-- register once and Stats.lua declares a second protocol on it.
function GF.InitSharing()
    local LGB = LibGroupBroadcast
    if not (LGB and LGB.RegisterHandler) then return end

    -- a clash with another addon's protocol id must not break the frames
    local ok, err = pcall(function()
        local handler = LGB:RegisterHandler(GF.name)
        handler:SetDisplayName("GroupFrames")
        handler:SetDescription("Lets group members share the additional effects they track and their active weapon bar.")
        GF.lgbHandler = handler -- also used by Stats.lua

        local declared = handler:DeclareProtocol(PROTOCOL_ID, PROTOCOL_NAME)
        declared:SetDisplayName("Tracked effects")
        declared:AddField(LGB.CreateArrayField(
            LGB.CreateNumericField("ids", { minValue = 0, maxValue = MAX_ABILITY_ID }),
            { maxLength = MAX_SHARED }))
        declared:AddField(LGB.CreateArrayField(
            LGB.CreateNumericField("names", { minValue = 0, maxValue = MAX_ABILITY_ID }),
            { maxLength = MAX_SHARED }))
        declared:OnData(OnData)
        if not declared:Finalize({ isRelevantInCombat = false, replaceQueuedMessages = true }) then
            error("the protocol could not be finalized")
        end
        protocol = declared
    end)

    if not ok then
        GF.shareError = "sharing is unavailable: " .. tostring(err)
    end
    GF.canShare = protocol ~= nil
end
