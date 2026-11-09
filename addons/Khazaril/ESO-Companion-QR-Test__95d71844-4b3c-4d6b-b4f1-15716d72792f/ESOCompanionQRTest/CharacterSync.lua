-- CharacterSync.lua
-- Snapshot of the logged-in character for the ESO Companion app: who they are, equipped gear,
-- both skill bars, slotted Champion stars and the backpack. Names (items, sets, traits, skills)
-- come straight from the game, so the app doesn't need its own item database.
--
-- Text format: one record per line, fields separated by tabs.
--   V   format  apiVersion  timestamp
--   P   characterId  name  account  classId  className  raceId  raceName  level  championPoints  allianceName
--   SET setId  setName                                  (each set once)
--   W   slot  slotName  itemId  itemName  setId  traitName  quality
--   B   bar(1/2)  slot  abilityId  abilityName  [icon  scripts]   (icon and scripts only for scribed skills)
--   CP  slot  championSkillId  name
--   I   itemId  count  itemName  quality  setId  traitName     (backpack)
--
-- QR chunk header: ESOCC1 <characterId> <index>/<total>

ESOC_CharacterSync = ESOC_CharacterSync or {}
local CS = ESOC_CharacterSync

local function safe(fn, ...)
    local ok, a, b, c, d, e, f, g = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g end
    return nil
end

local function fmt(s)
    -- strip the game's grammar markers (e.g. "Bow^n") from names
    local ok, r = pcall(zo_strformat, "<<1>>", s or "")
    return ok and r or (s or "")
end

function CS.Collect()
    local clean = ESOC_SkillExport.clean
    local out = {}
    local function row(...)
        local t = { ... }
        for i = 1, #t do t[i] = clean(t[i]) end
        out[#out + 1] = table.concat(t, "\t")
    end
    local setsSeen = {}
    local function itemInfo(bag, slot)
        local link = safe(GetItemLink, bag, slot) or ""
        local hasSet, setName, _, _, _, setId = safe(GetItemLinkSetInfo, link, false)
        if hasSet and setId and setId ~= 0 and not setsSeen[setId] then
            setsSeen[setId] = true
            row("SET", setId, fmt(setName))
        end
        local trait = safe(GetItemTrait, bag, slot) or 0
        local traitName = (trait ~= 0) and (safe(GetString, "SI_ITEMTRAITTYPE", trait) or "") or ""
        return fmt(safe(GetItemName, bag, slot)), (hasSet and setId) or 0, traitName, safe(GetItemDisplayQuality, bag, slot) or 0
    end

    row("V", 1, safe(GetAPIVersion) or 0, safe(GetTimeStamp) or 0)
    row("P", safe(GetCurrentCharacterId) or "", fmt(safe(GetUnitName, "player")), safe(GetDisplayName) or "",
        safe(GetUnitClassId, "player") or 0, fmt(safe(GetUnitClass, "player")),
        safe(GetUnitRaceId, "player") or 0, fmt(safe(GetUnitRace, "player")),
        safe(GetUnitLevel, "player") or 0, safe(GetUnitChampionPoints, "player") or 0,
        fmt(safe(GetAllianceName, safe(GetUnitAlliance, "player") or 0)))

    -- Equipped gear
    for slot = 0, (safe(GetBagSize, BAG_WORN) or 0) - 1 do
        local id = safe(GetItemId, BAG_WORN, slot)
        if id and id ~= 0 then
            local name, setId, traitName, quality = itemInfo(BAG_WORN, slot)
            row("W", slot, fmt(safe(GetString, "SI_EQUIPSLOT", slot)), id, name, setId, traitName, quality)
        end
    end

    -- Skill bars (slots 3-7 are skills, 8 is the ultimate)
    for bar, cat in ipairs({ HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }) do
        for slot = 3, 8 do
            local id = safe(GetSlotBoundId, slot, cat)
            if id and id ~= 0 then
                if ACTION_TYPE_CRAFTED_ABILITY and safe(GetSlotType, slot, cat) == ACTION_TYPE_CRAFTED_ABILITY then
                    -- Scribed skill: the slot holds the grimoire's craftedAbilityId, not an ability id
                    local craftedId = id
                    id = safe(GetAbilityIdForCraftedAbilityId, craftedId) or 0
                    local name = safe(GetCraftedAbilityDisplayName, craftedId) or safe(GetAbilityName, id)
                    local icon = tostring(safe(GetCraftedAbilityIcon, craftedId) or ""):gsub("^/esoui/art/icons/", ""):gsub("%.dds$", "")
                    row("B", bar, slot, id, fmt(name), icon, fmt(ESOC_SkillExport.ScriptNames(craftedId)))
                else
                    row("B", bar, slot, id, fmt(safe(GetAbilityName, id)))
                end
            end
        end
    end

    -- Slotted Champion stars
    if HOTBAR_CATEGORY_CHAMPION then
        for slot = 1, 12 do
            local id = safe(GetSlotBoundId, slot, HOTBAR_CATEGORY_CHAMPION)
            if id and id ~= 0 then row("CP", slot, id, fmt(safe(GetChampionSkillName, id))) end
        end
    end

    -- Backpack
    for slot = 0, (safe(GetBagSize, BAG_BACKPACK) or 0) - 1 do
        local id = safe(GetItemId, BAG_BACKPACK, slot)
        if id and id ~= 0 then
            local name, setId, traitName, quality = itemInfo(BAG_BACKPACK, slot)
            local _, count = safe(GetItemInfo, BAG_BACKPACK, slot)
            row("I", id, count or safe(GetSlotStackSize, BAG_BACKPACK, slot) or 1, name, quality, setId, traitName)
        end
    end

    return table.concat(out, "\n"), safe(GetCurrentCharacterId) or "0"
end
