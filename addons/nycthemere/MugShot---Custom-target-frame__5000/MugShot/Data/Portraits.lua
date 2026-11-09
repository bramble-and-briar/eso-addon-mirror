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
    ['Atronach de fer, épreuve']         = '/esoui/art/icons/achievement_u29_dun2_flavorc.dds',
    ['Atronach de fer']                  = '/esoui/art/icons/achievement_u29_dun2_flavorc.dds',
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

-- ── Badges Metadata (Referenced from Constants) ───────────
MugShot.Portraits.RaceIdToName   = MugShot.Constants.RACE_ID_TO_NAME
MugShot.Portraits.ClassIcons     = MugShot.Constants.CLASS_ICONS
MugShot.Portraits.AllianceIcons  = MugShot.Constants.ALLIANCE_ICONS

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
    local clean = zo_strformat("<<1>>", name)
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

    -- 2. Scan Collectible Categories (Companions & Assistants)
    local categories = {
        COLLECTIBLE_CATEGORY_TYPE_COMPANION,
        COLLECTIBLE_CATEGORY_TYPE_ASSISTANT,
    }
    for _, cat in ipairs(categories) do
        local n = GetTotalCollectiblesByCategoryType(cat) or 0
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

    -- 3. Scan Pet / Summon Abilities
    for _, abId in ipairs(SUMMON_ABILITY_IDS) do
        local name = GetAbilityName(abId)
        local icon = GetAbilityIcon(abId)
        if name and icon then
            Register(name, icon, true)
        end
    end
end

-- ── Companion Collectibles (called on zone change / activation) ────────
function MugShot.Portraits.RegisterCompanionCollectibles()
    MugShot.Portraits.PopulateDynamicRegistry()
end

-- ── Portrait Resolution ───────────────────────────────────
function MugShot.Portraits.GetPortraitInfo(unitTag)
    local isPlayer = IsUnitPlayer(unitTag) or (unitTag == 'player') or (AreUnitsEqual and AreUnitsEqual(unitTag, 'player'))

    if isPlayer then
        -- 1. Custom avatar (LibCustomIcons / HodorReflexes)
        local customIcon, customCoords = nil, nil
        local settings = MugShot.settings
        local allowCustom = not settings or settings:Get().useHodorIcons ~= false

        if allowCustom then
            local displayName = GetUnitDisplayName(unitTag)
            if (not displayName or displayName == "") and (unitTag == 'player' or (AreUnitsEqual and AreUnitsEqual(unitTag, 'player'))) then
                displayName = GetDisplayName()
            end
            displayName = displayName or ""
            if displayName ~= "" then
                local handle = displayName:sub(1, 1) == "@" and displayName or ("@" .. displayName)
                local raw = handle:sub(2)

                if LibCustomIcons then
                    if LibCustomIcons.GetStatic then
                        local tex, l, r, t, b = LibCustomIcons.GetStatic(handle)
                        if not tex and raw ~= handle then
                            tex, l, r, t, b = LibCustomIcons.GetStatic(raw)
                        end
                        if not tex then
                            tex, l, r, t, b = LibCustomIcons.GetStatic(handle:lower())
                        end
                        if not tex and raw ~= handle then
                            tex, l, r, t, b = LibCustomIcons.GetStatic(raw:lower())
                        end
                        if tex and IsValidIcon(tex) then
                            customIcon, customCoords = tex, { l or 0, r or 1, t or 0, b or 1 }
                        end
                    end
                    if not customIcon and LibCustomIcons.GetAnimated then
                        local anim = LibCustomIcons.GetAnimated(handle)
                        if not anim and raw ~= handle then
                            anim = LibCustomIcons.GetAnimated(raw)
                        end
                        if not anim then
                            anim = LibCustomIcons.GetAnimated(handle:lower())
                        end
                        if not anim and raw ~= handle then
                            anim = LibCustomIcons.GetAnimated(raw:lower())
                        end
                        if type(anim) == "table" and anim[1] and IsValidIcon(anim[1]) then
                            customIcon, customCoords = anim[1], { 0, 1 / (anim[2] or 1), 0, 1 / (anim[3] or 1) }
                        end
                    end
                elseif HodorReflexes and HodorReflexes.util and HodorReflexes.util.GetUserIcon then
                    local tex, coords = HodorReflexes.util.GetUserIcon(handle, 0)
                    if not tex and raw ~= handle then
                        tex, coords = HodorReflexes.util.GetUserIcon(raw, 0)
                    end
                    if not tex then
                        tex, coords = HodorReflexes.util.GetUserIcon(handle:lower(), 0)
                    end
                    if not tex and raw ~= handle then
                        tex, coords = HodorReflexes.util.GetUserIcon(raw:lower(), 0)
                    end
                    if tex and IsValidIcon(tex) then
                        customIcon, customCoords = tex, coords
                    end
                end
            end
        end

        -- 2. Full-color Gamepad Class Icon
        local classId = GetUnitClassId(unitTag)
        if (not classId or classId == 0) and (unitTag == "player" or (AreUnitsEqual and AreUnitsEqual(unitTag, "player"))) then
            classId = GetUnitClassId("player")
        end

        local classIcon = (classId and ZO_GetGamepadClassIcon(classId))
            or (classId and MugShot.Constants.CLASS_ICONS and MugShot.Constants.CLASS_ICONS[classId])

        if not classIcon then
            local className = string.lower(GetUnitClass(unitTag) or "")
            if className ~= "" then
                classIcon = '/esoui/art/icons/class/gamepad/gp_class_' .. className .. '.dds'
            end
        end

        -- 3. Race badge
        local raceId = GetUnitRaceId(unitTag)
        if (not raceId or raceId == 0) and (unitTag == "player" or (AreUnitsEqual and AreUnitsEqual(unitTag, "player"))) then
            raceId = GetUnitRaceId("player")
        end
        local raceIcon = nil
        local rName = raceId and MugShot.Constants.RACE_ID_TO_NAME and MugShot.Constants.RACE_ID_TO_NAME[raceId]
        if rName then
            raceIcon = '/esoui/art/charactercreate/gamepad/charactercreate_' .. rName .. 'icon_down.dds'
        end

        -- 4. Alliance badge composite (Base: ava_flagneutral.dds + Crest: alliancebadge_<alliance>.dds)
        local aId = GetUnitAlliance(unitTag)
        if (not aId or aId == 0) and (unitTag == "player" or (AreUnitsEqual and AreUnitsEqual(unitTag, "player"))) then
            aId = GetUnitAlliance("player")
        end
        local allianceIcon = (aId and MugShot.Constants.ALLIANCE_ICONS and MugShot.Constants.ALLIANCE_ICONS[aId])
            or (aId and ZO_GetLargeAllianceSymbolIcon(aId))
            or nil
        local allianceBase = allianceIcon and MugShot.Constants.ALLIANCE_FLAG_BASE or nil
        local allianceColor = aId and MugShot.Constants.ALLIANCE_COLORS and MugShot.Constants.ALLIANCE_COLORS[aId]

        return {
            portraitTexture = customIcon or classIcon,
            portraitCoords  = customCoords,
            portraitColor   = { 1.0, 1.0, 1.0, 1.0 },
            classIcon       = classIcon,
            customIcon      = customIcon,
            isClassIcon     = (customIcon == nil),
            raceIcon        = raceIcon,
            allianceIcon    = allianceIcon,
            allianceBase    = allianceBase,
            allianceColor   = allianceColor,
            allianceId      = aId,
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
        if not tex and AreUnitsEqual and AreUnitsEqual(unitTag, "companion") then
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
            portraitColor   = { 1.0, 1.0, 1.0, 1.0 },
            classIcon       = nil,
            customIcon      = nil,
            isClassIcon     = false,
            raceIcon        = nil,
            allianceIcon    = nil,
            allianceBase    = nil,
            allianceColor   = nil,
            allianceId      = nil,
        }
    end
end

-- Initialize dynamic registry at file load
MugShot.Portraits.PopulateDynamicRegistry()

MugShot.logger:Info("=== Portraits loaded ===")
