-- =========================================================
-- MugShot - Portraits  (Data/Portraits.lua)
-- Portrait resolution for target frame units.
-- Architecture: Single unified portrait map with dynamic
-- discovery from ESO native Collectibles and Abilities APIs.
-- =========================================================

local MugShot = MugShot

MugShot.Portraits = {}

-- ── Static Trial Bosses ──────────────────────────────────
MugShot.Portraits.BossPortraits = {
    ['Iron Atronach']                    = '/esoui/art/icons/achievement_u29_dun2_flavorc.dds',
    ['Frost Atronach']                   = '/esoui/art/icons/achievement_u25_dun1_flavor_boss_1a.dds',
    ['Haj Mota']                         = '/esoui/art/icons/achievement_murkmire_loyalty.dds',
    ['Soul-Sworn Thrall']                = '/esoui/art/icons/item_soulswornthrall.dds',
    ['Target Iron Atronach, Trial']      = '/esoui/art/icons/achievement_u29_dun2_flavorc.dds',
    ['Target Skeleton, Robust Humanoid'] = '/esoui/art/icons/event_witchfest_sacking_skelet.dds',
    ['Target Skeleton, Humanoid']        = '/esoui/art/icons/event_witchfest_sacking_skelet.dds',
    ['Target Ogrim']                     = '/esoui/art/icons/target_greenarmoredogrim.dds',
    ['The Precursor']                    = '/esoui/art/icons/targetdummy_theprecursor.dds',

    -- Rockgrove
    ['Havocrel Annihilator']             = '/esoui/art/icons/achievement_u32_havocrel_uniques.dds',
    ['Havocrel Butcher']                 = '/esoui/art/icons/achievement_u32_havocrel_uniques.dds',
    ['Havocrel Barbarian']               = '/esoui/art/icons/achievement_u32_havocrel_uniques.dds',
    ['Havocrel Torchcaster']             = '/esoui/art/icons/achievement_u32_havocrel_uniques.dds',
    ['Sul-xan Bloodseeker']              = '/esoui/art/icons/achievement_u30_vtrialkillmonstersa.dds',
    ['Sul-xan Reaver']                   = '/esoui/art/icons/achievement_u30_vtrialkillmonstersa.dds',
    ['Sul-xan Soulweaver']               = '/esoui/art/icons/achievement_u30_vtrialkillmonstersa.dds',
    ['Oaxiltso']                         = '/esoui/art/icons/achievement_u30_vtrial_b1_hardmode.dds',
    ['Death Hopper']                     = '/esoui/art/icons/achievement_u30_groupboss4.dds',
    ['Flesh Abomination']                = '/esoui/art/icons/ability_necromancer_006.dds',
    ['Fire Behemoth']                    = '/esoui/art/icons/achievement_u32_havocrel_uniques.dds',
    ['Flame-Herald Bahsei']              = '/esoui/art/icons/achievement_u30_vtrial_b2_hardmode.dds',
    ['Daedroth']                         = '/esoui/art/icons/achievement_092.dds',
    ['Flame Watcher']                    = '/esoui/art/icons/achievement_u29_dun2_killmonstersb.dds',
    ['Xalvakka']                         = '/esoui/art/icons/achievement_u30_vtrial_all_hardmode.dds',
    ['Havocrel Goliath']                 = '/esoui/art/icons/achievement_u32_havocrel_uniques.dds',

    -- Sanctum Ophidia
    ['Possessed Mantikora']              = '/esoui/art/icons/achievement_u32_dl_groupboss2.dds',
    ['Stonebreaker']                     = '/esoui/art/icons/gear_undauntedtroll_head_a.dds',
    ['Ozara']                            = '/esoui/art/icons/housing_uni_inc_mountedtrophylamia001.dds',
    ['The Serpent']                      = '/esoui/art/icons/ability_mundusstones_004.dds',

    -- Hel Ra Citadel
    ['Ra Kotu']                          = '/esoui/art/icons/u34_vtrial_all_hardmode.dds',
    ['Yokeda Kai']                       = '/esoui/art/icons/gear_yokudan_heavy_head_a.dds',
    ["Yokeda Rok'dun"]                   = '/esoui/art/icons/gear_yokudan_heavy_head_a.dds',
    ['The Warrior']                      = '/esoui/art/icons/achievement_update11_dungeons_001.dds',

    -- Sunspire
    ['Lokkestiiz']                       = '/esoui/art/icons/achievement_els_sunspire_flavor_2.dds',
    ['Yolnahkriin']                      = '/esoui/art/icons/achievement_els_sunspire_flavor_1.dds',
    ['Nahviintaas']                      = '/esoui/art/icons/achievement_els_sunspire_flavor_3.dds',
    ["Alkosh's Roar"]                    = '/esoui/art/icons/mounticon_monstroussenche_raht.dds',
    ["Jone's Gale-Claw"]                 = '/esoui/art/icons/mount_queenclawsencheraht.dds',
    ["Jode's Fire-Fang"]                 = '/esoui/art/icons/mount_sencherahtc.dds',
    ['Fury of Alkosh']                   = '/esoui/art/icons/ability_werewolf_002_b.dds',
    ['Ruin of Alkosh']                   = '/esoui/art/icons/ability_1handed_003.dds',
    ["Alkosh's Fate"]                    = '/esoui/art/icons/death_recap_cold_aoe.dds',
    ["Alkosh's Will"]                    = '/esoui/art/icons/ability_2handed_004_b.dds',

    -- Dreadsail Reef
    ['Lylanar']                          = '/esoui/art/icons/death_recap_fire_aoe.dds',
    ['Turlassil']                        = '/esoui/art/icons/death_recap_cold_aoe.dds',
    ['Reef Guardian']                    = '/esoui/art/icons/u34_vtrial_b2_hardmode.dds',
    ['Tideborn Taleria']                 = '/esoui/art/icons/u34_vtrial_all_hardmode.dds',
    ['Bow Breaker']                      = '/esoui/art/icons/achievement_update11_dungeons_014.dds',
    ['Sail Ripper']                      = '/esoui/art/icons/u34_vtrial_flavor_4.dds',

    -- Cloudrest
    ["Z'Maja"]                           = '/esoui/art/icons/achievement_su_karnwasten_groupevent.dds',
    ['Shade of Siroria']                 = '/esoui/art/icons/ability_dragonknight_010.dds',
    ['Shade of Relequen']                = '/esoui/art/icons/ability_sorcerer_thundering_presence.dds',
    ['Shade of Galenwe']                 = '/esoui/art/icons/death_recap_cold_aoe.dds',
    ['Yaghra Monstrosity']               = '/esoui/art/icons/pet_191_yaghradarkblue-yellow.dds',
    ['Yaghra Strider']                   = '/esoui/art/icons/achievement_summerset_boss_002.dds',
    ['Yaghra Spewer']                    = '/esoui/art/icons/achievement_summerset_boss_002.dds',
    ['Nocturnal Creeper']                = '/esoui/art/icons/death_recap_magic_ranged.dds',

    -- Sanity's Edge
    ['Exarchanic Yaseyla']               = '/esoui/art/icons/ability_debuff_disorient.dds',
    ['Contramagis Wamasu']               = '/esoui/art/icons/achievement_update12_dungeons_002.dds',
    ['Chimera']                          = '/esoui/art/icons/achievement_u36_zone_groupboss1.dds',
    ['Ansuul the Tormentor']             = '/esoui/art/icons/achievement_u38_vtrial_meta.dds',
}
MugShot.Portraits.SpecificPortraits = MugShot.Portraits.BossPortraits

-- ── Badges Metadata ───────────────────────────────────────
MugShot.Portraits.RaceIdToName = {
    [1]  = 'breton',    [2]  = 'redguard',  [3]  = 'orc',
    [4]  = 'dunmer',    [5]  = 'nord',      [6]  = 'argonian',
    [7]  = 'altmer',    [8]  = 'bosmer',    [9]  = 'khajiit',
    [10] = 'imperial',
}

MugShot.Portraits.AllianceNames = {
    [1] = 'aldmeri', [2] = 'ebonheart', [3] = 'daggerfall',
}

MugShot.Portraits.AllianceColors = {
    [1] = { 1.0, 1.0, 0.5 },
    [2] = { 1.0, 0.5, 0.5 },
    [3] = { 0.5, 0.5, 1.0 },
}

MugShot.Portraits.ClassIcons = {
    [1]   = '/esoui/art/icons/class/gamepad/gp_class_dragonknight.dds',
    [2]   = '/esoui/art/icons/class/gamepad/gp_class_sorcerer.dds',
    [3]   = '/esoui/art/icons/class/gamepad/gp_class_nightblade.dds',
    [4]   = '/esoui/art/icons/class/gamepad/gp_class_warden.dds',
    [5]   = '/esoui/art/icons/class/gamepad/gp_class_necromancer.dds',
    [6]   = '/esoui/art/icons/class/gamepad/gp_class_templar.dds',
    [117] = '/esoui/art/icons/class/gamepad/gp_class_arcanist.dds',
}

-- Pure numeric ability IDs for summons across classes
local SUMMON_ABILITY_IDS = {
    -- Sorcerer
    23304, 23319, 23316, 24613, 24636, 24639, 23492, 23495, 23498,
    -- Warden
    85982, 85986, 85990, 86122, 86126, 86130,
    -- Necromancer
    117638, 117645, 117650, 117749, 117756, 117760, 117812, 117817, 117822, 115540, 118600, 118605,
    -- Nightblade
    25375, 25380, 25385,
    -- Arcanist
    183122, 185805, 185810,
}

-- ── Unified Portrait Map ──────────────────────────────────
MugShot.Portraits.Map = {}

local function CleanUnitName(name)
    if not name or type(name) ~= "string" then return "" end
    local clean = (zo_strformat and zo_strformat("<<1>>", name)) or name:gsub("%^%a+", "")
    return clean:match("^%s*(.-)%s*$") or clean
end

local function IsValidIcon(tex)
    if not tex or type(tex) ~= "string" or tex == "" then return false end
    local l = tex:lower()
    return not l:find("campaignbrowser_guestcampaign", 1, true)
       and not l:find("icon_missing", 1, true)
end

local function Register(name, icon, indexTokens)
    if not IsValidIcon(icon) then return end
    local clean = CleanUnitName(name)
    if clean == "" then return end

    local map = MugShot.Portraits.Map
    local lower = clean:lower()

    -- 1. Exact full name match
    map[lower] = map[lower] or icon

    -- 2. Word tokens for short names / pet summons (when enabled)
    if indexTokens then
        for word in lower:gmatch("[^%s%-]+") do
            if #word >= 3 then
                map[word] = map[word] or icon
            end
        end

        local hyphenPrefix = lower:match("^([^-]+)")
        if hyphenPrefix and hyphenPrefix ~= lower and #hyphenPrefix >= 3 then
            map[hyphenPrefix] = map[hyphenPrefix] or icon
        end
    end
end

-- ── Dynamic Discovery Engine ──────────────────────────────
function MugShot.Portraits.PopulateDynamicRegistry()
    -- 1. Register static trial bosses (full name only)
    for name, icon in pairs(MugShot.Portraits.BossPortraits) do
        Register(name, icon, false)
    end

    -- 2. Scan Collectible Categories (Category 27 = Companions, Category 8 = Assistants)
    local categories = {
        COLLECTIBLE_CATEGORY_TYPE_COMPANION or 27,
        COLLECTIBLE_CATEGORY_TYPE_ASSISTANT or 8,
    }
    local count = GetTotalCollectiblesByCategoryType
    if count then
        for _, cat in ipairs(categories) do
            local n = count(cat) or 0
            for i = 1, n do
                local colId = GetCollectibleIdFromType(cat, i)
                if colId and colId > 0 then
                    local name, _, icon = GetCollectibleInfo(colId)
                    if name and icon then
                        Register(name, icon, true)
                    end
                end
            end
        end
    end

    -- 3. Scan Pet / Summon Abilities
    for _, abId in ipairs(SUMMON_ABILITY_IDS) do
        local name = GetAbilityName(abId)
        local icon = GetAbilityIcon(abId)
        if name and icon then
            Register(name, icon, true)
        end
    end
end

-- ── Companion Collectibles (called on zone change) ────────
function MugShot.Portraits.RegisterCompanionCollectibles()
    local categories = {
        COLLECTIBLE_CATEGORY_TYPE_COMPANION or 27,
        COLLECTIBLE_CATEGORY_TYPE_ASSISTANT or 8,
    }
    local map = MugShot.Portraits.Map
    local count = GetTotalCollectiblesByCategoryType
    if not count then return end
    for _, cat in ipairs(categories) do
        local n = count(cat) or 0
        for i = 1, n do
            local colId = GetCollectibleIdFromType(cat, i)
            if colId and colId > 0 then
                local name, _, icon = GetCollectibleInfo(colId)
                if name and icon and IsValidIcon(icon) then
                    local clean = CleanUnitName(name)
                    if clean ~= "" then
                        local lower = clean:lower()
                        map[lower] = map[lower] or icon
                    end
                end
            end
        end
    end
end

-- ── Portrait Resolution ───────────────────────────────────
function MugShot.Portraits.GetPortraitInfo(unitTag)
    local isPlayer = IsUnitPlayer(unitTag) or (unitTag == 'player')

    if isPlayer then
        -- 1. Custom avatar (LibCustomIcons / HodorReflexes)
        local customIcon, customCoords = nil, nil
        local settings = MugShot.settings
        local allowCustom = not settings or settings:Get().useHodorIcons ~= false

        if allowCustom then
            local displayName = GetUnitDisplayName(unitTag) or GetDisplayName() or ""
            if displayName ~= "" then
                local handle = displayName:sub(1, 1) == "@" and displayName or ("@" .. displayName)
                if LibCustomIcons then
                    if LibCustomIcons.GetStatic then
                        local tex, l, r, t, b = LibCustomIcons.GetStatic(handle)
                        if tex and IsValidIcon(tex) then
                            customIcon, customCoords = tex, { l or 0, r or 1, t or 0, b or 1 }
                        end
                    end
                    if not customIcon and LibCustomIcons.GetAnimated then
                        local anim = LibCustomIcons.GetAnimated(handle)
                        if type(anim) == "table" and anim[1] and IsValidIcon(anim[1]) then
                            customIcon, customCoords = anim[1], { 0, 1 / (anim[2] or 1), 0, 1 / (anim[3] or 1) }
                        end
                    end
                elseif HodorReflexes and HodorReflexes.util and HodorReflexes.util.GetUserIcon then
                    local tex, coords = HodorReflexes.util.GetUserIcon(handle, 0)
                    if tex and IsValidIcon(tex) then
                        customIcon, customCoords = tex, coords
                    end
                end
            end
        end

        -- 2. Class icon
        local classId = GetUnitClassId(unitTag)
        local classIcon = (classId and MugShot.Portraits.ClassIcons[classId])
            or '/esoui/art/icons/class/gamepad/gp_class_dragonknight.dds'

        -- 3. Race badge
        local raceIcon = nil
        local raceId = GetUnitRaceId(unitTag)
        local rName = raceId and MugShot.Portraits.RaceIdToName[raceId]
        if rName then
            raceIcon = '/esoui/art/charactercreate/gamepad/charactercreate_' .. rName .. 'icon_down.dds'
        end

        -- 4. Alliance badge
        local allianceIcon, allianceColor = nil, nil
        local aId = GetUnitAlliance(unitTag)
        local aName = aId and MugShot.Portraits.AllianceNames[aId]
        if aName then
            allianceIcon  = '/esoui/art/stats/alliancebadge_' .. aName .. '.dds'
            allianceColor = MugShot.Portraits.AllianceColors[aId]
        end

        return {
            portraitTexture = customIcon or classIcon,
            portraitCoords  = customCoords,
            classIcon       = classIcon,
            customIcon      = customIcon,
            raceIcon        = raceIcon,
            allianceIcon    = allianceIcon,
            allianceColor   = allianceColor,
        }
    else
        -- Non-player (Boss, Companion, Pet, NPC)
        if not next(MugShot.Portraits.Map) then
            MugShot.Portraits.PopulateDynamicRegistry()
        end

        local rawName = GetUnitName(unitTag) or ""
        local clean = CleanUnitName(rawName)
        local lower = clean:lower()
        local map = MugShot.Portraits.Map

        -- 1. Exact full name match
        local tex = map[lower] or map[rawName:lower()]

        -- 2. Word token match (matches "sharp", "vif", "familiar", "gardien", etc.)
        if not tex then
            for word in lower:gmatch("[^%s%-]+") do
                if map[word] then
                    tex = map[word]
                    break
                end
            end
        end

        -- 3. Active companion fallback (when unit is active companion)
        if not tex and (unitTag == "companion" or (DoesUnitExist("companion") and DoesUnitExist(unitTag) and AreUnitsEqual(unitTag, "companion"))) then
            local defId = GetActiveCompanionDefId()
            if defId and defId > 0 then
                local colId = GetCompanionCollectibleId(defId)
                if colId and colId > 0 then
                    local _, _, compIcon = GetCollectibleInfo(colId)
                    if IsValidIcon(compIcon) then
                        tex = compIcon
                    end
                end
            end
        end

        return {
            portraitTexture = tex,
            portraitCoords  = nil,
            classIcon       = nil,
            customIcon      = nil,
            raceIcon        = nil,
            allianceIcon    = nil,
            allianceColor   = nil,
        }
    end
end

-- Initialize dynamic registry at file load
MugShot.Portraits.PopulateDynamicRegistry()

MugShot.logger:Info("=== Portraits loaded ===")
