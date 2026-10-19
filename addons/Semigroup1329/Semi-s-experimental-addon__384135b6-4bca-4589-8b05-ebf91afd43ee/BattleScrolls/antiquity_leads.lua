if not SemisPlaygroundCheckAccess() then return end

-- Personal playground module, enabled with inventory automation.
local ACCOUNTS = { ['@Semigroup'] = true, ['@Semigroup1329'] = true }
if not ACCOUNTS[GetDisplayName()] then return end

---@class AntiquityLeadReminder
---@field fiber Fiber<nil>|nil
local leads = {}
BattleScrolls.antiquityLeads = leads
local inventory = BattleScrolls.inventoryPoc

---@class ExpiringAntiquityLead
---@field id number
---@field setId number
---@field rewardId number
---@field remaining number

local EVENT_NAME = 'BattleScrollsAntiquityLeads'
local EXPIRING_SECONDS = 14 * 24 * 60 * 60
local ACTIVATION_DELAY_MS = 3000

---@param rewardId number
---@return boolean
local function furnishingReward(rewardId)
    local rewardType = GetRewardType(rewardId)
    if rewardType == REWARD_ENTRY_TYPE_ITEM then
        local link = GetItemRewardItemLink(rewardId, 1, 0, LINK_STYLE_DEFAULT)
        return GetItemLinkItemType(link) == ITEMTYPE_FURNISHING
    elseif rewardType == REWARD_ENTRY_TYPE_COLLECTIBLE then
        local collectibleId = GetCollectibleRewardCollectibleId(rewardId)
        -- Mounts and pets can be placed in houses too; they still belong in
        -- this reminder. Only the actual furniture category is excluded.
        return GetCollectibleCategoryType(collectibleId) == COLLECTIBLE_CATEGORY_TYPE_FURNITURE
    end
    return false
end

---@param antiquityId number
---@return ExpiringAntiquityLead|nil
local function expiringLead(antiquityId)
    if not DoesAntiquityHaveLead(antiquityId) or not DoesAntiquityRequireLead(antiquityId) then return nil end
    local remaining = GetAntiquityLeadTimeRemainingSeconds(antiquityId)
    if remaining <= 0 or remaining >= EXPIRING_SECONDS then return nil end
    local setId = GetAntiquitySetId(antiquityId)
    local rewardId = setId ~= 0 and GetAntiquitySetRewardId(setId) or 0
    if rewardId == 0 then rewardId = GetAntiquityRewardId(antiquityId) end
    if furnishingReward(rewardId) and (setId == 0 or GetNumAntiquitiesRecovered(antiquityId) > 0) then return nil end
    return { id = antiquityId, setId = setId, rewardId = rewardId, remaining = remaining }
end

function leads.stop()
    if leads.fiber then leads.fiber:Cancel() end
end

function leads.report()
    leads.stop()
    if not inventory.enabled then return end
    leads.fiber = LibEffect.Async(function()
        LibEffect.Sleep(ACTIVATION_DELAY_MS):Await()
        ---@type ExpiringAntiquityLead[]
        local entries = {}
        local antiquityId, scanned = GetNextAntiquityId(), 0
        while antiquityId do
            local entry = expiringLead(antiquityId)
            if entry then entries[#entries + 1] = entry end
            antiquityId = GetNextAntiquityId(antiquityId)
            scanned = scanned + 1
            if scanned % 10 == 0 then LibEffect.Yield():Await() end
        end
        table.sort(entries, function(a, b)
            if a.remaining == b.remaining then return a.id < b.id end
            return a.remaining < b.remaining
        end)
        local printedHeader = false
        for _, candidate in ipairs(entries) do
            -- A dig or lead expiry can happen while the scan yields.
            local entry = expiringLead(candidate.id)
            if entry then
                if not printedHeader then
                    d(GetString(BATTLESCROLLS_ANTIQUITY_LEADS_HEADER))
                    printedHeader = true
                end
                local name = zo_strformat(SI_ANTIQUITY_NAME_FORMATTER, GetAntiquityName(entry.id))
                if entry.setId ~= 0 then
                    name = zo_strformat(BATTLESCROLLS_ANTIQUITY_LEADS_FRAGMENT, name,
                        zo_strformat(SI_ANTIQUITY_SET_NAME_FORMATTER, GetAntiquitySetName(entry.setId)))
                end
                local rewardType = REWARDS_MANAGER:GetRewardContextualTypeString(entry.rewardId)
                    or GetString(SI_ANTIQUITY_TYPE_FALLBACK)
                local zone = zo_strformat(SI_ZONE_NAME, GetZoneNameById(GetAntiquityZoneId(entry.id)))
                d(zo_strformat(BATTLESCROLLS_ANTIQUITY_LEADS_ENTRY, rewardType, name, zone,
                    ZO_FormatAntiquityLeadTime(entry.remaining)))
            end
            LibEffect.Yield():Await()
        end
    end):Ensure(function()
        leads.fiber = nil
        BattleScrolls.gc:RequestGC(2)
    end):Run()
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_PLAYER_ACTIVATED, leads.report)
EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_PLAYER_DEACTIVATED, leads.stop)
