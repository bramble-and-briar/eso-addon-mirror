local PBE = PacketByteExporter
PBE.Schema = {}
local Schema = PBE.Schema

-- Version 2's fixed field dictionary. Order is part of the wire format: the
-- matching table in receiver/lib/schema.mjs must change only with a new version.
-- Frequent fields get one-character codes; the rest get two-character codes.
local fields = [=[
name abilityId championPoints displayQuality slot points description slotType skillId enchant
itemId level id trait unspent set skills spent category index empty active earned rank
type purchased progressionId passive ultimate upgrade maxUpgrade morph crafted scripts
criteria known remaining required duration current lastRank nextRank accountSkill advised
inTraining skillsIncluded total unlocked purchasable categoryType subcategory tracked
questType stack styleId locked meetsRequirement functionalQuality equipType sellPrice link state
system character attributes stats mundus equipment bars champion companion actionBars
championBar disciplines activeCategory addonVersion apiVersion capturedAt gamepadMode
platformService profile schemaVersion world alliance allianceId characterId class classId
genderId race raceId title championPointsEarned experience experienceMax accountName
location subzone zone zoneId zoneIndex health magicka stamina healthMax magickaMax
staminaMax healthRecovery magickaRecovery staminaRecovery weaponDamage spellDamage
weaponCritical spellCritical physicalPenetration spellPenetration physicalResistance
spellResistance criticalResistance criticalDamage criticalHealing healingDone healingTaken
damageDone damageTaken blockMitigation blockCost bashDamage bashCost sprintCost sprintSpeed
started ending stacks effectType abilityType statusEffectType canClickOff castByPlayer
bonuses equipped hasSet maxEquipped perfectedEquipped hasCharges icon sourceBagId
sourceSlotIndex equipSlotId armoryState definitionId hasActive rapport rapportDescription
slots primary secondary curseType iconIndex outfitIndex skillPointsSpent activeStep
activeStepType trackerText completed pushed zoneDisplayType availablePoints
detailOmitted types lines xp max pool available enlightenment amount size used
inventory inventoryMax speed speedMax nextResearchSeconds traits hidesLocked
hidesPoints nickname hint subcategoryIndex earnedPoints totalPoints date time selected
craftingResearch inventorySummary activeEffects activeCollectibles currencies riding
quests armoryBuilds backpack bank subscriberBank collectibles achievements titles
categories entries outfit activeCollectibleType craftedId scriptsIncluded progressionIndex
earnedRank
]=]

local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
local prefixes = "!#%&"
local originalToCode = {}
local count = 0
for field in fields:gmatch("%S+") do
    assert(originalToCode[field] == nil, "duplicate schema field: " .. field)
    local code
    if count < #alphabet then
        code = alphabet:sub(count + 1, count + 1)
    else
        local later = count - #alphabet
        local prefixIndex = math.floor(later / #alphabet) + 1
        assert(prefixIndex <= #prefixes, "schema dictionary exhausted")
        code = prefixes:sub(prefixIndex, prefixIndex)
            .. alphabet:sub(later % #alphabet + 1, later % #alphabet + 1)
    end
    originalToCode[field] = code
    count = count + 1
end

-- Called by the incremental JSON encoder as it emits each object key. This
-- avoids an extra whole-snapshot traversal in one Xbox frame.
function Schema.AliasKey(key)
    local original = tostring(key)
    local code = originalToCode[original]
    if code then return code end
    if original:sub(1, 1) == "~"
        or original:match("^[A-Za-z0-9]$")
        or original:match("^[!#%%&][A-Za-z0-9]$") then
        return "~" .. original
    end
    return original
end

local function IsArray(value)
    if PBE.Codec.ObjectMarked(value) then
        return false
    end
    local countEntries = 0
    local max = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return false
        end
        countEntries = countEntries + 1
        if key > max then max = key end
    end
    return countEntries == max
end

local function Pack(value, active)
    if type(value) ~= "table" then return value end
    assert(not active[value], "cannot pack a cyclic table")
    active[value] = true
    local isArray = IsArray(value)
    local packed = isArray and {} or PBE.Codec.Object()
    if isArray then
        for index = 1, #value do
            packed[index] = Pack(value[index], active)
        end
    else
        for key, child in pairs(value) do
            packed[Schema.AliasKey(key)] = Pack(child, active)
        end
    end
    active[value] = nil
    return packed
end

function Schema.Pack(snapshot)
    return Pack(snapshot, {})
end
