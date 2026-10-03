-- SnipersFriendGroundTargetUtils.lua: Pure helpers for the ground-target range / LOS indicator

local GroundTargetUtils = {}

-- Engine verdicts we care about (ACTION_RESULT_* from GetGroundTargetingError).
-- Unknown codes fall into "other" and are logged by /sf gt log so we can learn them.
GroundTargetUtils.RESULT_OUT_OF_RANGE = ACTION_RESULT_TARGET_OUT_OF_RANGE or 2100
GroundTargetUtils.RESULT_NOT_IN_VIEW = ACTION_RESULT_TARGET_NOT_IN_VIEW or 2070
GroundTargetUtils.RESULT_CANT_SEE = ACTION_RESULT_CANT_SEE_TARGET or 2330
GroundTargetUtils.RESULT_TOO_CLOSE = ACTION_RESULT_TARGET_TOO_CLOSE or 2370
GroundTargetUtils.RESULT_BAD_TARGET = ACTION_RESULT_BAD_TARGET or 2040
GroundTargetUtils.RESULT_INVALID_LOCATION = 2700

---@alias SnipersFriendGtState "idle"|"ok"|"range"|"los"|"invalid"|"other"

---@param err integer|nil
---@return SnipersFriendGtState
function GroundTargetUtils.Classify(err)
    if err == nil then return "ok" end
    if err == GroundTargetUtils.RESULT_OUT_OF_RANGE or err == GroundTargetUtils.RESULT_TOO_CLOSE then
        return "range"
    end
    if err == GroundTargetUtils.RESULT_NOT_IN_VIEW or err == GroundTargetUtils.RESULT_CANT_SEE then
        return "los"
    end
    if err == GroundTargetUtils.RESULT_BAD_TARGET or err == GroundTargetUtils.RESULT_INVALID_LOCATION then
        return "invalid"
    end
    return "other"
end

---Action slots that can hold a castable ability on the current bar.
---@return integer[]
function GroundTargetUtils.AbilitySlots()
    local first = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX or 2
    local ult = ACTION_BAR_ULTIMATE_SLOT_INDEX or 7
    local slots = {}
    for i = first + 1, ult + 1 do -- luaindex: constants are 0-based offsets
        slots[#slots + 1] = i
    end
    return slots
end

---Find slotted ground-target abilities on the active bar via their tooltip target text.
---"Ground" = placed at a point (traps, Elemental Explosion). "Area" with a range > 0 =
---channelled / placed AoEs (e.g. Volley-style). Self-centred AoEs have range 0 and are skipped.
---@param groundLabel string localized "Ground" (SI_ABILITY_TOOLTIP_TARGET_TYPE_GROUND)
---@param areaLabel string|nil localized "Area" (SI_ABILITY_TOOLTIP_TARGET_TYPE_AREA)
---@return {slot: integer, abilityId: integer, name: string, maxRangeM: number|nil, targetType: string}[]
function GroundTargetUtils.FindGroundAbilities(groundLabel, areaLabel)
    local found = {}
    for _, slot in ipairs(GroundTargetUtils.AbilitySlots()) do
        local slotType = GetSlotType(slot)
        if slotType == ACTION_TYPE_ABILITY or slotType == ACTION_TYPE_CRAFTED_ABILITY then
            local id = GetSlotBoundId(slot)
            if id and id > 0 then
                local desc = GetAbilityTargetDescription(id, nil, "player")
                local isGround = desc ~= nil and desc == groundLabel
                local isArea = desc ~= nil and areaLabel ~= nil and desc == areaLabel
                if isGround or isArea then
                    local _, maxCM = GetAbilityRange(id, nil, "player")
                    local maxRangeM = maxCM and maxCM / 100 or nil
                    if isGround or (maxRangeM and maxRangeM > 0) then
                        found[#found + 1] = {
                            slot = slot,
                            abilityId = id,
                            name = GetAbilityName(id, "player"),
                            maxRangeM = maxRangeM,
                            targetType = isGround and "ground" or "area",
                        }
                    end
                end
            end
        end
    end
    return found
end

---Linear blend of two RGBA tables.
---@param a SnipersFriendRGBA
---@param b SnipersFriendRGBA
---@param t number 0..1
---@return number, number, number, number
function GroundTargetUtils.Lerp(a, b, t)
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    return a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t
end

SnipersFriend.GroundTargetUtils = GroundTargetUtils
