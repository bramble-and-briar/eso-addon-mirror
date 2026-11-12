-- Weapon Skills module: Maelstrom timers, IDs, equipped-set detection.
local SSRT = SoraReticleTracker
SSRT.WeaponSkills = SSRT.WeaponSkills or {}
local SLOT_FIRST = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1
local SLOT_LAST = SLOT_FIRST + 4

local MAELSTROM_SET_SETTING = {
    [369] = "maelstromStampedeEnabled",
    [522] = "maelstromStampedeEnabled",
    [373] = "maelstromWallEnabled",
    [526] = "maelstromWallEnabled",
    [372] = "maelstromHailEnabled",
    [525] = "maelstromHailEnabled",
}

local MAELSTROM_SETTING_KIND = {
    maelstromStampedeEnabled = "stampede",
    maelstromWallEnabled = "wall",
    maelstromHailEnabled = "hail",
}

local STAMPEDE_IDS = {
    [38794] = true,
    [38791] = true,
}
local BLOCKADE_IDS = {
    [39011] = true,
    [39012] = true,
    [39018] = true,
    [39028] = true,
    [39053] = true,
    [39073] = true,
}
local UNSTABLE_WALL_IDS = {
    [39052] = true,
    [39045] = true,
    [39061] = true,
    [39067] = true,
    [39071] = true,
}
local ENDLESS_HAIL_IDS = {
    [38692] = true,
    [38689] = true,
}

local STAMPEDE_TEXTURE_TOKEN = "ability_2handed_003_a"
local ENDLESS_HAIL_TEXTURE_TOKEN = "ability_bow_003_a"
local BLOCKADE_TEXTURE_TOKEN = "ability_destructionstaff_002a"
local UNSTABLE_WALL_TEXTURE_TOKEN = "ability_destructionstaff_002b"

local function GetEquippedSetId(equipSlot)
    local itemLink = GetItemLink(BAG_WORN, equipSlot, LINK_STYLE_DEFAULT)
    if not itemLink or itemLink == "" then return 0 end

    local hasSet, _, _, _, _, setId = GetItemLinkSetInfo(itemLink)
    if not hasSet then return 0 end
    return setId or 0
end

local function IsMaelstromTrackingEnabled()
    return SSRT.sv.maelstromEnabled
        and (
            SSRT.sv.maelstromStampedeEnabled
            or SSRT.sv.maelstromWallEnabled
            or SSRT.sv.maelstromHailEnabled
        )
end

local function GetBarArenaKind(category)
    local main, off
    if category == HOTBAR_CATEGORY_PRIMARY then
        main, off = EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND
    else
        main, off = EQUIP_SLOT_BACKUP_MAIN, EQUIP_SLOT_BACKUP_OFF
    end
    -- An off-hand arena weapon must not be hidden by an unrelated main-hand set.
    for _, equipSlot in ipairs({main, off}) do
        local settingName = MAELSTROM_SET_SETTING[GetEquippedSetId(equipSlot)]
        if settingName and SSRT.sv[settingName] then
            return MAELSTROM_SETTING_KIND[settingName]
        end
    end
    return nil
end

local function IdMatches(id, idSet)
    return id ~= nil and id ~= 0 and idSet[id] == true
end

local function TextureMatches(texture, token)
    if not texture or texture == "" then return false end
    return zo_strlower(texture):find(token, 1, true) ~= nil
end

local function GetSlotIds(slotIndex, category)
    local boundId = GetSlotBoundId(slotIndex, category) or 0
    if boundId == 0 then return 0, 0 end
    local effectiveId = GetEffectiveAbilityIdForAbilityOnHotbar(boundId, category) or boundId
    return boundId, effectiveId
end

local function IsTrackedMaelstromSkill(slotIndex, kind, category)
    local boundId, effectiveId = GetSlotIds(slotIndex, category)
    local texture = GetSlotTexture(slotIndex, category) or ""
    if kind == "stampede" then
        return IdMatches(boundId, STAMPEDE_IDS)
            or IdMatches(effectiveId, STAMPEDE_IDS)
            or TextureMatches(texture, STAMPEDE_TEXTURE_TOKEN)
    elseif kind == "wall" then
        return IdMatches(boundId, BLOCKADE_IDS)
            or IdMatches(effectiveId, BLOCKADE_IDS)
            or IdMatches(boundId, UNSTABLE_WALL_IDS)
            or IdMatches(effectiveId, UNSTABLE_WALL_IDS)
            or TextureMatches(texture, BLOCKADE_TEXTURE_TOKEN)
            or TextureMatches(texture, UNSTABLE_WALL_TEXTURE_TOKEN)
    elseif kind == "hail" then
        return IdMatches(boundId, ENDLESS_HAIL_IDS)
            or IdMatches(effectiveId, ENDLESS_HAIL_IDS)
            or TextureMatches(texture, ENDLESS_HAIL_TEXTURE_TOKEN)
    end
    return false
end

-- Keep each bar's own equipment/skill combination. A Maelstrom weapon may
-- be on the front bar, and the player may instead use the back bar as main.
local bindings = {}
-- The cast-event timer is the sole Maelstrom countdown.
-- Never trigger from a different ability sharing a slot after a bar change.
local castTimer = nil
local function GetCastDurationMs(slot, category)
    local duration = GetActionSlotEffectDuration(slot, category) or 0
    if duration > 0 then return duration end
    local boundId, effectiveId = GetSlotIds(slot, category)
    -- Some ability descriptions report seconds; the ESO API duration is in ms.
    -- No arbitrary fixed time is invented when a duration is unavailable.
    for _, id in ipairs({effectiveId, boundId}) do
        if id and id > 0 then
            local ms = GetAbilityDuration(id) or 0
            if ms > 0 then return ms end
        end
    end
    -- ESO's slot-effect metadata can be zero on some clients.
    -- Use known skill durations only for recognized morphs; this never
    -- replaces a positive duration supplied by the game.
    local texture = zo_strlower(GetSlotTexture(slot, category) or "")
    if texture:find(STAMPEDE_TEXTURE_TOKEN, 1, true) then return 15000 end
    if texture:find(BLOCKADE_TEXTURE_TOKEN, 1, true) then return 15000 end
    if texture:find(UNSTABLE_WALL_TEXTURE_TOKEN, 1, true) then return 10000 end
    return 0
end

local function OnMaelstromSkillUsed(_, slot)
    if not IsMaelstromTrackingEnabled() then return end
    local category = GetActiveHotbarCategory()
    -- Reconcile stale bindings without altering any other trackers.
    local matched = nil
    for _, binding in ipairs(bindings) do
        if binding.slot == slot and binding.category == category
            and IsTrackedMaelstromSkill(slot, binding.kind, category) then
            matched = binding
            break
        end
    end
    if not matched then return end
    local duration = GetCastDurationMs(slot, category)
    if duration <= 0 then return end
    castTimer = {
        endsAt = GetGameTimeMilliseconds() + duration,
        kind = matched.kind,
        category = category,
        slot = slot,
        duration = duration,
    }
end

SSRT.WeaponSkills.OnSkillUsed = OnMaelstromSkillUsed
local function RefreshMaelstromBinding()
    bindings = {}
    SSRT.maelstromKind, SSRT.maelstromSlot = nil, nil
    if not IsMaelstromTrackingEnabled() then return end
    for _, category in ipairs({HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP}) do
        local kind = GetBarArenaKind(category)
        if kind then
            for slotIndex = SLOT_FIRST, SLOT_LAST do
                if IsTrackedMaelstromSkill(slotIndex, kind, category) then
                    bindings[#bindings + 1] = {category=category,slot=slotIndex,kind=kind}
                    break
                end
            end
        end
    end
    local first = bindings[1]
    if first then
        SSRT.maelstromKind = first.kind
        SSRT.maelstromSlot = first.slot
    end
end

local function ReadMaelstromTimer()
    if not IsMaelstromTrackingEnabled() then return 0 end
    -- Use the cast-event timer; the old slot remaining-time path is intentionally disabled.
    if not castTimer then return 0 end
    local remaining = castTimer.endsAt - GetGameTimeMilliseconds()
    if remaining <= 0 then
        castTimer = nil
        return 0
    end
    -- A new cast is valid only while its original weapon+skill binding exists.
    -- The timer continues after swapping to the other bar.
    for _, binding in ipairs(bindings) do
        if binding.category == castTimer.category and binding.slot == castTimer.slot
            and binding.kind == castTimer.kind then
            SSRT.maelstromKind = binding.kind
            SSRT.maelstromSlot = binding.slot
            return remaining
        end
    end
    return 0
end

SSRT.WeaponSkills.IsTrackingEnabled = IsMaelstromTrackingEnabled
SSRT.WeaponSkills.RefreshBinding = RefreshMaelstromBinding
SSRT.WeaponSkills.ReadTimer = ReadMaelstromTimer
