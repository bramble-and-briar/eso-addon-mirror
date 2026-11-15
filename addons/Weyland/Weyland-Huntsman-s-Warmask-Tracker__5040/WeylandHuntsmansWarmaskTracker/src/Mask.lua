--[[
    Mask detection and ACTIVE / STANDBY switching.
]]

local ADDON = "WeylandHuntsmansWarmaskTracker"
local HMK = _G[ADDON]
local EM = EVENT_MANAGER
local WARMASK_PLAYER_EFFECT_ABILITY_ID = HMK.WARMASK_PLAYER_EFFECT_ABILITY_ID
local SCAN_SLOTS, CleanName = HMK.SCAN_SLOTS, HMK.CleanName
local SyncPlayerWarmaskEffect = HMK.SyncPlayerWarmaskEffect
local OnPlayerEffectChanged = HMK.OnPlayerEffectChanged

local function IsMaskSet(setName, setId)
    if HMK.sv.maskSetId ~= 0 and setId == HMK.sv.maskSetId then return true end
    local n = CleanName(setName)
    if n:find("huntsman", 1, true) and n:find("warmask", 1, true) then
        if setId and setId > 0 then HMK.sv.maskSetId = setId end   -- learn the id
        return true
    end
    return false
end

local function IsMaskEquipped()
    for _, slot in ipairs(SCAN_SLOTS) do
        local link = GetItemLink(BAG_WORN, slot)
        if link and link ~= "" then
            local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(link, true)
            if hasSet and IsMaskSet(setName, setId) then
                return true
            end
        end
    end
    return false
end

-- Only listen for the Warmask self effect on the player. The target-side mark
-- (252048) is deliberately not tracked by this HUD anymore.
local EFFECT_EVENT_NAME = ADDON .. "_PlayerEffect"

local function SetActive(on)
    if on == HMK.active then return end
    HMK.active = on

    if on then
        EM:RegisterForEvent(EFFECT_EVENT_NAME, EVENT_EFFECT_CHANGED, OnPlayerEffectChanged)
        EM:AddFilterForEvent(EFFECT_EVENT_NAME, EVENT_EFFECT_CHANGED,
            REGISTER_FILTER_UNIT_TAG, "player",
            REGISTER_FILTER_ABILITY_ID, WARMASK_PLAYER_EFFECT_ABILITY_ID)

        SyncPlayerWarmaskEffect()
    else
        EM:UnregisterForEvent(EFFECT_EVENT_NAME, EVENT_EFFECT_CHANGED)
        HMK.ClearMark()
    end
end

local function RefreshMask()
    SetActive(IsMaskEquipped())
end

HMK.IsMaskEquipped = IsMaskEquipped
HMK.RefreshMask = RefreshMask
