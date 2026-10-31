local ADDON_NAME = "HARDCORE"
HARDCORE = HARDCORE or {}
local HARDCORE = HARDCORE
HARDCORE.name = ADDON_NAME
HARDCORE.version = "1.5.1"

-- SavedVars
HARDCORE.defaults = {
    hasSeenIntro = false,
    isActive = false,
    minHealthPct = 100,
    persistedMinHealthPct = 100,
    difficultyTier = 2,
    disableVisionDim = false,
    disableLowHealthVolume = false,
    disableNotificationMessages = false,
    neverDie = false,
    allowHomeTravel = false,
    debugMode = false,
    hasSeenCongrats = false,
    hasSeenFeatPermanentWarning = false,
    hasDied = false
}

local function AreNotificationMessagesDisabled()
    return HARDCORE.saved and HARDCORE.saved.disableNotificationMessages == true
end

function HARDCORE.AreNotificationMessagesDisabled()
    return AreNotificationMessagesDisabled()
end

function HARDCORE.ShowAlert(category, soundId, message, ...)
    if AreNotificationMessagesDisabled() then
        return
    end
    ZO_Alert(category, soundId, message, ...)
end

function HARDCORE.ShowAlertNoSuppression(category, soundId, message, ...)
    if AreNotificationMessagesDisabled() then
        return
    end
    ZO_AlertNoSuppression(category, soundId, message, ...)
end

function HARDCORE.IsNeverDieEnabled()
    return HARDCORE.saved and HARDCORE.saved.neverDie == true
end

function HARDCORE.IsHomeTravelAllowed()
    return HARDCORE.saved and HARDCORE.saved.allowHomeTravel == true
end

local COLOR = {
    white = ZO_ColorDef:New(1, 1, 1, 1),
    gold = ZO_ColorDef:New(1, 0.84, 0, 1),
    gray = ZO_ColorDef:New(0.78, 0.78, 0.78, 1),
    dim = ZO_ColorDef:New(0.85, 0.85, 0.85, 0.65),
    red = ZO_ColorDef:New(0.85, 0.15, 0.15, 1)
}

local RULE_ICONS = {
    mail = "/esoui/art/addons/gamepad/gp_mod_listing_category_mail.dds",
    crafting = "/esoui/art/inventory/inventory_craft_tabicon_active.dds",
    gear = "/esoui/art/tradinghouse/gamepad/gp_tradinghouse_materials_trait_armortrait.dds",
    sets = "/esoui/art/icons/icon_1handed.dds",
    cp = "/esoui/art/armory/buildicons/buildicon_5.dds",
    trade = "/esoui/art/icons/emotes/emotecategoryicon_social.dds",
    hud = "/esoui/art/icons/heraldrycrests_misc_eye_01.dds",
    enemy = "/esoui/art/hud/hud_countdown_badge_dueling.dds",
    compass = "/esoui/art/addons/gamepad/gp_mod_listing_category_mapandcompass.dds",
    aoe = "/esoui/art/treeicons/u46_helpcategory_update46_down.dds",
    tp = "/esoui/art/zonestories/completiontypeicon_wayshrine.dds",
    healing = "/esoui/art/lfg/lfg_healer_down_no_glow_64.dds",
    safezone = "/esoui/art/icons/mapkey/mapkey_avatown.dds",
    grouping = "/esoui/art/treeicons/gamepad/gp_tutorial_idexicon_groups.dds",
    repairkit = "/esoui/art/vendor/vendor_tabicon_repair_down.dds",
    vendor = "/esoui/art/vendor/vendor_tabicon_repair_down.dds",
    permadeath = "/esoui/art/trials/vitalitydepletion.dds",
    soulgem = "/esoui/art/inventory/inventory_tabicon_soulgem_down.dds",
    bank = "/esoui/art/icons/servicemappins/servicepin_bank.dds",
    guildstore = "/esoui/art/tutorial/gamepad/gp_playermenu_icon_guilds.dds",
    rations = "/esoui/art/tradinghouse/gamepad/gp_tradinghouse_materials_provisioning_food.dds",
    weariness = "/esoui/art/ava/ava_rankicon64_prefect.dds",
    swim = "/esoui/art/inventory/inventory_tabicon_craftbag_fishing_up.dds",
    lockpick = "/esoui/art/lockpicking/lock_pick.dds",
    barbarian = "/esoui/art/inventory/inventory_tabicon_2handed_up.dds",
    barefoot = "/esoui/art/tradinghouse/tradinghouse_apparel_feet_up.dds",
    handsfree = "/esoui/art/inventory/inventory_tabicon_weapons_up.dds",
    selfmade = "/esoui/art/tradinghouse/gamepad/gp_tradinghouse_materials_trait_armortrait.dds",
    noswimming = "/esoui/art/inventory/inventory_tabicon_craftbag_fishing_up.dds",
    nudist = "/esoui/art/inventory/inventory_tabicon_armor_up.dds",
    blood = "/esoui/art/lfg/lfg_dps_up_64.dds",
    potions = "/esoui/art/tradinghouse/tradinghouse_potions_potionsolvent_up.dds",
    trinkets = "/esoui/art/tradinghouse/tradinghouse_apparel_accessories_ring_up.dds",
    npctalk = "EsoUI/Art/MainMenu/menuBar_social_up.dds",
    map = "/esoui/art/mainmenu/menubar_map_up.dds",
    armorDiscipline = "/esoui/art/crafting/smithing_tabicon_armorset_up.dds",
    oathboundWeapon = "/esoui/art/crafting/smithing_tabicon_weaponset_up.dds",
    scavengersPoverty = "/esoui/art/vendor/vendor_tabicon_sell_up.dds",
    questlessExile = "/esoui/art/journal/journal_tabicon_quest_up.dds",
    unseenWhispers = "/esoui/art/treeicons/antiquities_indexicon_scryable_up.dds",
    lightsOut = "/esoui/art/stealth/stealth_64.dds"
}

local RULES = {{
    text = "Sealed Mail",
    icon = RULE_ICONS.mail,
    tip = "Couriers refuse your letters and parcels.",
    ruleId = "NoMail"
}, {
    text = "Restricted Crafting",
    icon = RULE_ICONS.crafting,
    tip = "Only cooking and alchemy are permitted. All other crafting arts are forbidden on this journey.",
    ruleId = "NoCrafting"
}, {
    text = "Humble Gear Only",
    icon = RULE_ICONS.gear,
    tip = "You may arm yourself only with simple gear of white, green, or blue quality.",
    ruleId = "LimitedGear"
}, {
    text = "Two-Set Limit",
    icon = RULE_ICONS.sets,
    tip = "You may wear no more than two items from the same set; the greater set bonuses are off-limits.",
    ruleId = "LimitedSets"
}, {
    text = "Sealed Champion Power",
    icon = RULE_ICONS.cp,
    tip = "Champion power remains sealed; none may be gained or used.",
    ruleId = "NoCP"
}, {
    text = "Adventurer's HUD",
    icon = RULE_ICONS.hud,
    tip = "Your health bar is hidden. As your strength wanes, your vision dims and narrows, and your action bars remain concealed, revealed only in brief moments.",
    ruleId = "HardcoreHUD"
}, {
    text = "Blind Combat",
    icon = RULE_ICONS.enemy,
    tip = "Foes show no names, no health bars, and no target frame. Read the battle, not the UI.",
    ruleId = "NoHealthBar"
}, {
    text = "No Guiding Compass",
    icon = RULE_ICONS.compass,
    tip = "Your compass is silent, offering no markers or guidance.",
    ruleId = "NoCompass"
}, {
    text = "Hidden AOE Threats",
    icon = RULE_ICONS.aoe,
    tip = "Enemy area attacks leave no ground telegraphs. Danger must be sensed, not seen.",
    ruleId = "HiddenAOEThreats"
}, {
    text = "Locked Banks",
    icon = RULE_ICONS.bank,
    tip = "All banks remain inaccessible.",
    ruleId = "NoBank"
}, {
    text = "Closed Guild Markets",
    icon = RULE_ICONS.guildstore,
    tip = "Guild traders and their markets are closed to you.",
    ruleId = "NoGuildStore"
}, {
    text = "Self-Reliant Journey",
    icon = RULE_ICONS.trade,
    tip = "No direct trade may pass between you and other adventurers.",
    ruleId = "NoTrade"
}, {
    text = "Irreparable Gear",
    icon = RULE_ICONS.repairkit,
    tip = "Gear cannot be repaired; once worn down, it must be replaced.",
    ruleId = "NoRepair"
}, {
    text = "Dormant Soul Gems",
    icon = RULE_ICONS.soulgem,
    tip = "Soul gems cannot restore weapon charges on this challenge.",
    ruleId = "NoSoulGems"
}, {
    text = "Sanctuary Skill Changes",
    icon = RULE_ICONS.safezone,
    tip = "Skills may be adjusted only within towns and safe settlements.",
    ruleId = "EquipmentCitySkills"
}, {
    text = "Bound Wayshrines",
    icon = RULE_ICONS.tp,
    tip = "Fast travel is restricted to wayshrine-to-wayshrine only.",
    ruleId = "LimitedTP"
}, {
    text = "One Life Run",
    icon = RULE_ICONS.permadeath,
    tip = "DEATH = DELETE",
    alwaysOn = true
}}

-- Difficulty tiers (slider presets)
local DIFFICULTY_TIERS = {
    [1] = "|t24:24:/esoui/art/armory/buildicons/buildicon_58.dds|t  Novice",
    [2] = "|t24:24:/esoui/art/armory/buildicons/buildicon_39.dds|t  Adept",
    [3] = "|t24:24:/esoui/art/armory/buildicons/buildicon_34.dds|t  Master",
    [4] = "|t24:24:/esoui/art/armory/buildicons/buildicon_18.dds|t  Legendary",
    [5] = "|t24:24:/esoui/art/campaign/campaign_tabicon_summary_up.dds|t  Custom"
}

local FEATS = {{
    title = "Trail Rations",
    flavor = "Hunger and thirst drain as the road stretches on. Keep food and drink in your pack, or starvation will dim the world around you.",
    icon = RULE_ICONS.rations,
    difficulty = 2,
    ruleId = "TrailRations"
}, {
    title = "Road Weariness",
    flavor = "Travel, stamina loss, and battle wear you down. /Sit or /sleep to rest before exhaustion makes weapons and NPCs slip out of reach.",
    icon = RULE_ICONS.weariness,
    difficulty = 1,
    ruleId = "RoadWeariness"
}, {
    title = "Mandatory Bath Time",
    flavor = "Every fifteen minutes, the bath bell tolls. Enter water and soak for ten seconds, or the short grace countdown ends the run." ,
    icon = RULE_ICONS.swim,
    difficulty = 5,
    ruleId = "SwimDiscipline"
}, {
    title = "Lockpick Nerves",
    flavor = "Each failed or broken pick leaves a panic mark for ten seconds. Three marks break your nerve and end the run; a clean lock steadies your hands.",
    icon = RULE_ICONS.lockpick,
    difficulty = 3,
    ruleId = "LockpickNerves"
}, {
    title = "Barbarian",
    flavor = "Live by the great weapon: only two-handed axes, hammers, and swords may stay equipped. Head and chest stay bare; all other armor must be heavy.",
    icon = RULE_ICONS.barbarian,
    difficulty = 3,
    ruleId = "Barbarian"
}, {
    title = "Barefoot Pilgrim",
    flavor = "Boots are a comfort for softer roads. Footwear is removed whenever the vow is active.",
    icon = RULE_ICONS.barefoot,
    difficulty = 1,
    ruleId = "BarefootPilgrim"
}, {
    title = "Hands Free",
    flavor = "Weapons are off the table. Improvise, punch, dodge, pray, or discover how persuasive empty hands can be.",
    icon = RULE_ICONS.handsfree,
    difficulty = 4,
    ruleId = "HandsFree"
}, {
    title = "Oathbound Weapon",
    flavor = "The first weapon type found in your hands becomes your oath. Other weapon types are removed whenever they appear.",
    icon = RULE_ICONS.oathboundWeapon,
    difficulty = 5,
    ruleId = "OathboundWeapon"
}, {
    title = "Self Made",
    flavor = "Only gear crafted by your own hands may stay equipped. The forge, clothier, woodworking, and jewelry stations open just enough to make your kit.",
    icon = RULE_ICONS.selfmade,
    difficulty = 5,
    ruleId = "SelfMade"
}, {
    title = "No Swimming",
    flavor = "Deep water gives you fifteen seconds of mercy. Keep swimming after the timer runs dry and the challenge ends.",
    icon = RULE_ICONS.noswimming,
    difficulty = 2,
    ruleId = "NoSwimming"
}, {
    title = "Nudist",
    flavor = "Armor slots must stay bare: no helm, chest, shoulders, gloves, belt, legs, or boots. Weapons and jewelry are still allowed.",
    icon = RULE_ICONS.nudist,
    difficulty = 3,
    ruleId = "Nudist"
}, {
    title = "Need of Blood",
    flavor = "Every ten minutes, the blood demand wakes. Only kills during its twenty-second window count; fail to feed it and the run ends.",
    icon = RULE_ICONS.blood,
    difficulty = 4,
    ruleId = "NeedOfBlood"
}, {
    title = "No Potions",
    flavor = "Drink a potion and the run ends. No emergency bottle, no alchemist's mercy.",
    icon = RULE_ICONS.potions,
    difficulty = 2,
    ruleId = "NoPotions"
}, {
    title = "No Trinkets",
    flavor = "Necklaces and rings are stripped away. Survival has no room for lucky charms.",
    icon = RULE_ICONS.trinkets,
    difficulty = 2,
    ruleId = "NoTrinkets"
}, {
    title = "Scavenger's Poverty",
    flavor = "Gold cannot soften exile. Vendors and fences are closed; buying, selling, buyback, junk selling, and laundering are blocked.",
    icon = RULE_ICONS.scavengersPoverty,
    difficulty = 5,
    ruleId = "ScavengersPoverty"
}, {
    title = "Silent Pilgrim",
    flavor = "You have taken a vow of silence: no talking to NPCs, no quest chatter, no turn-ins. Dialogue is closed before a single word leaves your mouth.",
    icon = RULE_ICONS.npctalk,
    difficulty = 4,
    ruleId = "NoNpcTalk"
}, {
    title = "No Map",
    flavor = "The road must be remembered, not drawn.",
    icon = RULE_ICONS.map,
    difficulty = 3,
    ruleId = "NoMap"
}, {
    title = "No Wayshrines",
    flavor = "No wayshrines, no recall, no shortcuts. Travel on foot, by mount, or not at all.",
    icon = RULE_ICONS.tp,
    difficulty = 1,
    ruleId = "NoWayshrines"
}, {
    title = "Unseen Whispers",
    flavor = "From time to time, the silence forgets itself.",
    icon = RULE_ICONS.unseenWhispers,
    difficulty = 1,
    ruleId = "UnseenWhispers"
}, {
    title = "Lights Out",
    flavor = "Every so often, the light simply leaves.",
    icon = RULE_ICONS.lightsOut,
    difficulty = 1,
    ruleId = "LightsOut"
}, {
    title = "Single Armor Discipline",
    flavor = "The first armor weight found on your body becomes your discipline. Other armor weights are removed.",
    icon = RULE_ICONS.armorDiscipline,
    difficulty = 3,
    ruleId = "SingleArmorDiscipline"
}, {
    title = "Questless Exile",
    flavor = "Abandonable quests are dropped. Offers and turn-ins are blocked. Main quests stay, but cannot advance.",
    icon = RULE_ICONS.questlessExile,
    difficulty = 5,
    ruleId = "QuestlessExile"
}}
local FEAT_RULE_IDS = {
    TrailRations = true,
    RoadWeariness = true,
    SwimDiscipline = true,
    LockpickNerves = true,
    Barbarian = true,
    BarefootPilgrim = true,
    HandsFree = true,
    OathboundWeapon = true,
    SelfMade = true,
    NoSwimming = true,
    Nudist = true,
    NeedOfBlood = true,
    NoPotions = true,
    NoTrinkets = true,
    ScavengersPoverty = true,
    NoNpcTalk = true,
    NoMap = true,
    NoWayshrines = true,
    UnseenWhispers = true,
    LightsOut = true,
    SingleArmorDiscipline = true,
    QuestlessExile = true
}

local FEATS_EMPTY_TEXT = "No feats are available yet."

local function GetSortedFeats()
    local sorted = {}
    for i, feat in ipairs(FEATS) do
        sorted[i] = feat
    end

    table.sort(sorted, function(a, b)
        local aDifficulty = tonumber(a and a.difficulty) or 1
        local bDifficulty = tonumber(b and b.difficulty) or 1
        if aDifficulty == bDifficulty then
            return tostring(a and a.title or "") < tostring(b and b.title or "")
        end
        return aDifficulty < bDifficulty
    end)

    return sorted
end

local TIER_RULE_IDS = {
    [1] = {"HardcoreHUD", "HiddenAOEThreats", "NoCompass", "LimitedTP"},
    [2] = {"HardcoreHUD", "HiddenAOEThreats", "NoCompass", "LimitedTP", "NoTrade", "NoBank", "NoGuildStore",
           "NoCrafting", "NoSoulGems", "NoMail"},
    [3] = {"HardcoreHUD", "HiddenAOEThreats", "NoCompass", "LimitedTP", "NoTrade", "NoBank", "NoGuildStore",
           "NoCrafting", "NoSoulGems", "NoHealthBar", "NoCP", "NoMail"},
    [4] = {"HardcoreHUD", "HiddenAOEThreats", "NoCompass", "LimitedTP", "NoTrade", "NoBank", "NoGuildStore",
           "NoCrafting", "NoSoulGems", "NoHealthBar", "NoCP", "LimitedGear", "LimitedSets", "NoRepair",
           "EquipmentCitySkills", "NoMail"}
}

local function BuildSet(arr)
    local s = {}
    for _, id in ipairs(arr or {}) do
        s[id] = true
    end
    return s
end

function HARDCORE.InitRulesSaved()
    HARDCORE = HARDCORE or {}
    if not HARDCORE.rulesSaved then
        HARDCORE.rulesSaved = ZO_SavedVars:NewCharacterIdSettings("HARDCORE_Rules_SV", 1, nil, {
            enabled = {}
        }, GetWorldName())
    end
    HARDCORE.rulesSaved.enabled = HARDCORE.rulesSaved.enabled or {}
    return HARDCORE.rulesSaved
end

local function GetRulesSV()
    return HARDCORE.InitRulesSaved()
end

local function GetCompletedFeatTitles()
    local completed = {}
    local rulesSV = GetRulesSV()
    local enabled = rulesSV and rulesSV.enabled
    if not enabled then
        return completed
    end

    for _, feat in ipairs(GetSortedFeats()) do
        if feat.ruleId and enabled[feat.ruleId] == true then
            completed[#completed + 1] = feat.title
        end
    end

    return completed
end

local function GetArmorTypeName(armorType)
    if armorType == ARMORTYPE_LIGHT then
        return "Light"
    elseif armorType == ARMORTYPE_MEDIUM then
        return "Medium"
    elseif armorType == ARMORTYPE_HEAVY then
        return "Heavy"
    end
    return nil
end

local function IsFeatAccepted(ruleId)
    local rulesSV = GetRulesSV()
    return rulesSV and rulesSV.enabled and rulesSV.enabled[ruleId] == true
end

function HARDCORE.IsFeatAccepted(ruleId)
    return IsFeatAccepted(ruleId)
end

function HARDCORE.RefreshFeatAcceptButtons()
    for _, refresh in ipairs(HARDCORE._featAcceptRefreshers or {}) do
        refresh()
    end
end

local function GetFeatBlockedReason(ruleId)
    if ruleId == "Barbarian" and IsFeatAccepted("SingleArmorDiscipline") and HARDCORE.GetSingleArmorDisciplineArmorType then
        local armorType = HARDCORE.GetSingleArmorDisciplineArmorType()
        if armorType and armorType ~= ARMORTYPE_HEAVY then
            return "Blocked: Single Armor Discipline is bound to " .. GetArmorTypeName(armorType) .. " armor."
        end
    end

    if ruleId == "SingleArmorDiscipline" and IsFeatAccepted("Barbarian") then
        return "Blocked: Barbarian is already accepted."
    end

    return nil
end

local function NormalizeHealthPct(value)
    value = tonumber(value) or 100
    if value < 0 then
        return 0
    end
    if value > 100 then
        return 100
    end
    return math.floor(value + 0.5)
end

local function GetChallengeLowestHealthPct()
    local sv = HARDCORE.saved
    if not sv then
        return 100
    end

    local value = sv.minHealthPct
    if value == nil then
        value = sv.persistedMinHealthPct
    end

    return NormalizeHealthPct(value)
end

local function FormatCompletedFeatsText(completedFeats)
    if #completedFeats == 0 then
        return "No optional feats completed."
    end

    local lines = {}
    local line = ""

    for _, title in ipairs(completedFeats) do
        local candidate = line == "" and title or (line .. ", " .. title)
        if line ~= "" and string.len(candidate) > 68 then
            lines[#lines + 1] = line
            line = title
        else
            line = candidate
        end
    end

    if line ~= "" then
        lines[#lines + 1] = line
    end

    return table.concat(lines, "\n")
end

local function GetPlayedTimeSeconds()
    return tonumber(GetSecondsPlayed()) or 0
end

local function GetPlayedTimeText()
    return ZO_FormatTime(GetPlayedTimeSeconds(), TIME_FORMAT_STYLE_DESCRIPTIVE, TIME_FORMAT_PRECISION_SECONDS)
end

local function GetCompactPlayedTimeText()
    return ZO_FormatTimeLargestTwo(GetPlayedTimeSeconds(), TIME_FORMAT_STYLE_DESCRIPTIVE_MINIMAL)
end

function HARDCORE.SetDifficultySliderEnabled(enabled)
    HARDCORE._difficultyControlsEnabled = enabled and true or false

    if not HARDCORE.difficultySlider then
        return
    end

    HARDCORE.difficultySlider:SetEnabled(enabled)

    HARDCORE.difficultySlider:SetAlpha(enabled and 1 or 0.35)

    HARDCORE.difficultySlider:SetMouseEnabled(enabled)
end

local function IsCustomDifficultyTier(tier)
    return tonumber(tier) == 5
end

local function GetRuleEnabledSetForUI(tier)
    if IsCustomDifficultyTier(tier) then
        local sv = GetRulesSV()
        return sv.enabled or {}
    end
    return BuildSet(TIER_RULE_IDS[tier])
end

function HARDCORE.ApplyDifficultyPreset(tier)
    tier = zo_clamp(tonumber(tier) or 1, 1, 5)
    HARDCORE.saved.difficultyTier = tier

    local sv = GetRulesSV()
    local enabledSet = BuildSet(TIER_RULE_IDS[tier])

    if HARDCORE.RuleManager and HARDCORE.RuleManager.ForEachRule then
        HARDCORE.RuleManager:ForEachRule(function(id, _rule)
            if not FEAT_RULE_IDS[id] then
                sv.enabled[id] = enabledSet[id] == true
            end
        end)
    else
        for id in pairs(sv.enabled) do
            if not FEAT_RULE_IDS[id] then
                sv.enabled[id] = enabledSet[id] == true
            end
        end
        for id in pairs(enabledSet) do
            sv.enabled[id] = true
        end
    end

    HARDCORE.RefreshDifficultyUI()
end

function HARDCORE.RefreshDifficultyUI()
    if not HARDCORE._ruleRows then
        return
    end
    local tier = (HARDCORE.saved and HARDCORE.saved.difficultyTier) or 1
    local enabledSet = GetRuleEnabledSetForUI(tier)

    if HARDCORE.difficultyLabel then
        HARDCORE.difficultyLabel:SetText(DIFFICULTY_TIERS[tier] or ("Tier " .. tostring(tier)))
    end
    if HARDCORE.difficultySlider then
        HARDCORE.difficultySlider:SetValue(tier)
    end

    for _, row in ipairs(HARDCORE._ruleRows) do
        local r = row._ruleData
        local isAlways = r and r.alwaysOn
        local active = isAlways or ((r and r.ruleId and enabledSet[r.ruleId]) == true)

        if row._icon then
            row._icon:SetAlpha(active and 0.95 or 0.25)
        end
        if row._label then
            if active then
                row._label:SetColor(COLOR.white:UnpackRGBA())
            else
                row._label:SetColor(COLOR.dim:UnpackRGBA())
            end
        end
        if row._bg then
            row._bg:SetAlpha(active and 0.18 or 0.05)
        end

        row:SetMouseEnabled(true)
        if row._hitArea then
            row._hitArea:SetMouseEnabled(true)
        end
    end
end

local function ShowTip(ctrl, text)
    if not text or text == "" then
        return
    end
    InitializeTooltip(InformationTooltip, ctrl, RIGHT, -8, 0)
    SetTooltipText(InformationTooltip, text)
end
local function HideTip()
    ClearTooltip(InformationTooltip)
end

local function AnnounceTrialBegins()
    if AreNotificationMessagesDisabled() then
        return
    end
    local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, SOUNDS.QUEST_ACCEPTED)
    params:SetText("The Trial Begins")
    CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
end

local function HARDCORE_GetPlayerClassIngameIcon()
    local classId = GetUnitClassId("player")
    local classIndex = GetClassIndexById(classId)
    if not classIndex then
        return nil
    end

    local _, _, _, _, _, _, ingameIconKeyboard = GetClassInfo(classIndex)
    return ingameIconKeyboard
end

function HARDCORE.UpdateActiveStatsUI()
    if not HARDCORE.activeStats then
        return
    end

    if not (HARDCORE.saved and HARDCORE.saved.isActive) then
        HARDCORE.activeStats:SetHidden(true)
        return
    end

    HARDCORE.activeStats:SetHidden(false)

    local icon = HARDCORE_GetPlayerClassIngameIcon()
    if icon and HARDCORE.activeStats.classIcon then
        HARDCORE.activeStats.classIcon:SetTexture(icon)
    end

    local lvl = GetUnitLevel("player")
    if HARDCORE.activeStats.levelLabel then
        HARDCORE.activeStats.levelLabel:SetText(string.format("Lv %d", lvl))
    end

    -- persisted minimum health reached
    local minPct = (HARDCORE.saved and HARDCORE.saved.persistedMinHealthPct) or 100
    if HARDCORE.activeStats.minHpLabel then
        HARDCORE.activeStats.minHpLabel:SetText(string.format("%d%%", minPct))
    end
    if HARDCORE.activeStats.playedTimeLabel then
        HARDCORE.activeStats.playedTimeLabel:SetText("Alive: " .. GetCompactPlayedTimeText())
    end
end

local MINHP_EVENT_NAME = ADDON_NAME .. "_MinHP"

local function HARDCORE_OnPowerUpdate(_, unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)
    local cur, maxVal = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_HEALTH)
    if not maxVal or maxVal <= 0 then
        return
    end

    local pct = zo_floor((cur / maxVal) * 100 + 0.5)

    local prev = HARDCORE.saved.minHealthPct
    if prev == nil then
        HARDCORE.saved.minHealthPct = 100
        prev = 100
    end

    if pct < prev then
        HARDCORE.saved.minHealthPct = pct
        if not HARDCORE.saved.persistedMinHealthPct or pct < HARDCORE.saved.persistedMinHealthPct then
            HARDCORE.saved.persistedMinHealthPct = pct
        end
        HARDCORE.UpdateActiveStatsUI()
    end
end

local function HARDCORE_EnableMinHpTracking()
    EVENT_MANAGER:UnregisterForEvent(MINHP_EVENT_NAME, EVENT_POWER_UPDATE)
    if HARDCORE.saved and HARDCORE.saved.isActive then
        EVENT_MANAGER:RegisterForEvent(MINHP_EVENT_NAME, EVENT_POWER_UPDATE, HARDCORE_OnPowerUpdate)
        EVENT_MANAGER:AddFilterForEvent(MINHP_EVENT_NAME, EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "player", REGISTER_FILTER_POWER_TYPE, COMBAT_MECHANIC_FLAGS_HEALTH)
    end
end

function HARDCORE.SetMainPanelMode(active)
    active = active and true or false

    if HARDCORE.setupControls then
        for _, ctrl in ipairs(HARDCORE.setupControls) do
            if ctrl then
                ctrl:SetHidden(active)
            end
        end
    end

    if HARDCORE.challengeControls then
        for _, ctrl in ipairs(HARDCORE.challengeControls) do
            if ctrl then
                ctrl:SetHidden(not active)
            end
        end
    end

    if HARDCORE.activeStats then
        HARDCORE.activeStats:SetHidden(not active)
    end

    if active and HARDCORE.UpdateActiveStatsUI then
        HARDCORE.UpdateActiveStatsUI()
    end
end

local function HARDCORE_DisableMinHpTracking()
    EVENT_MANAGER:UnregisterForEvent(MINHP_EVENT_NAME, EVENT_POWER_UPDATE)
end

function HARDCORE.BeginChallengeRun()
    local sv = HARDCORE.saved
    if sv.isActive then
        return
    end
    sv.isActive = true
    sv.hasSeenCongrats = false
    sv.minHealthPct = 100
    if not sv.persistedMinHealthPct then
        sv.persistedMinHealthPct = 100
    end
    HARDCORE_EnableMinHpTracking()

    if HARDCORE.RuleManager and HARDCORE.RuleManager.SetActive then
        HARDCORE.RuleManager:SetActive(true)
    end

    if HARDCORE.UpdateActionButton then
        HARDCORE.UpdateActionButton()
    end
end

function HARDCORE.SurrenderChallenge()
    HARDCORE.saved.isActive = false
    HARDCORE_DisableMinHpTracking()

    if HARDCORE.RuleManager and HARDCORE.RuleManager.SetActive then
        HARDCORE.RuleManager:SetActive(false)
    end
end

function HARDCORE.FailChallenge(reason)
    if not (HARDCORE.saved and HARDCORE.saved.isActive) then
        return
    end
    HARDCORE.saved.hasDied = true
    HARDCORE.SurrenderChallenge()
    if HARDCORE.RestoreHUDSettings then
        HARDCORE.RestoreHUDSettings()
    end
    if reason and reason ~= "" then
        HARDCORE.ShowAlertNoSuppression(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK, reason)
    end
    if HARDCORE.ShowDeathWindow then
        HARDCORE.ShowDeathWindow()
    end
    if HARDCORE.UpdateActionButton then
        HARDCORE.UpdateActionButton()
    end
end

function HARDCORE.DebugResetFailedChallenge()
    if not HARDCORE.saved then
        return false
    end

    if HARDCORE.saved.isActive then
        HARDCORE.SurrenderChallenge()
    else
        HARDCORE_DisableMinHpTracking()
        if HARDCORE.RuleManager and HARDCORE.RuleManager.SetActive then
            HARDCORE.RuleManager:SetActive(false)
        end
    end

    HARDCORE.saved.hasDied = false
    HARDCORE.saved.minHealthPct = 100
    HARDCORE.saved.persistedMinHealthPct = 100

    if HARDCORE.deathWindow then
        HARDCORE.deathWindow:SetHidden(true)
    end
    if HARDCORE.subtitle then
        HARDCORE.subtitle:SetText(HARDCORE.saved.hasSeenIntro and
            "Hardcore Mode is inactive. You can re-enter anytime." or
            "Accept the challenge to enable the ruleset on this character.")
    end
    if HARDCORE.UpdateActionButton then
        HARDCORE.UpdateActionButton()
    end
    if HARDCORE.RefreshDifficultyUI then
        HARDCORE.RefreshDifficultyUI()
    end

    return true
end

local function GetMainMenuBar()
    return MAIN_MENU_KEYBOARD and MAIN_MENU_KEYBOARD.categoryBar
end

local function DeactivateMenuButton()
    local bar = GetMainMenuBar()
    if bar then
        ZO_MenuBar_ClearSelection(bar)
    end
end

local function ActivateMenuButton()
    local bar = GetMainMenuBar()
    if bar then
        ZO_MenuBar_SelectDescriptor(bar, "HARDCORE_MAINMENU", true)
    end
end

local function AddHardcoreMainMenuButton()
    local bar = MAIN_MENU_KEYBOARD and MAIN_MENU_KEYBOARD.categoryBar
    if not bar or HARDCORE._mainMenuBtnAdded then
        return
    end

    local data = {
        descriptor = "HARDCORE_MAINMENU",
        normal = "/art/fx/texture/modelfxtextures/blurred_skull.dds",
        pressed = "/art/fx/texture/modelfxtextures/blurred_skull.dds",
        highlight = "/art/fx/texture/modelfxtextures/blurred_skull.dds",
        categoryName = "HARDCORE",
        callback = function()
            if not HARDCORE then
                return
            end
            local bar = MAIN_MENU_KEYBOARD and MAIN_MENU_KEYBOARD.categoryBar

            if HARDCORE.saved and HARDCORE.saved.isActive then
                if GetUnitLevel("player") >= 50 and not HARDCORE.saved.hasSeenCongrats then
                    HARDCORE.ShowCongratulationsWindow()
                    if bar then ZO_MenuBar_ClearSelection(bar) end
                else
                    if HARDCORE.ToggleIntro then
                        HARDCORE.ToggleIntro()
                    end
                    if bar and HARDCORE.window then
                        if HARDCORE.window:IsHidden() then
                            ZO_MenuBar_ClearSelection(bar)
                        else
                            ZO_MenuBar_SelectDescriptor(bar, "HARDCORE_MAINMENU", true)
                        end
                    end
                end
            else
                if HARDCORE.ToggleIntro then
                    HARDCORE.ToggleIntro()
                end
                if bar and HARDCORE.window then
                    if HARDCORE.window:IsHidden() then
                        ZO_MenuBar_ClearSelection(bar)
                    else
                        ZO_MenuBar_SelectDescriptor(bar, "HARDCORE_MAINMENU", true)
                    end
                end
            end
        end

    }

    local btn = ZO_MenuBar_AddButton(bar, data)
    if btn then
        btn:SetHandler("OnMouseEnter", function(self)
            InitializeTooltip(InformationTooltip, self, TOP, 0, 10)
            SetTooltipText(InformationTooltip, "HARDCORE")
        end)
        btn:SetHandler("OnMouseExit", function()
            ClearTooltip(InformationTooltip)
        end)
    end

    HARDCORE._mainMenuBtnAdded = true
end

local function HARDCORE_OnPlayerActivatedMainMenu()
    AddHardcoreMainMenuButton()
end

local function HARDCORE_OnUnitDeathStateChanged(_, unitTag, isDead)
    if isDead and HARDCORE.saved and HARDCORE.saved.isActive then
        if HARDCORE.IsNeverDieEnabled() then
            HARDCORE.ShowAlertNoSuppression(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK,
                "HARDCORE: Plot armor absorbed that death.")
            return
        end
        HARDCORE.FailChallenge("HARDCORE: Challenge failed. You died.")
    end
end

local function HARDCORE_OnLevelUpdate(_, unitTag, newLevel)
    if newLevel >= 50 and HARDCORE.saved and HARDCORE.saved.isActive and not HARDCORE.saved.hasSeenCongrats then
        HARDCORE.ShowCongratulationsWindow()
    end
end

local function HARDCORE_HasAnyChampionSlotted()
    local startSlot, endSlot = GetAssignableChampionBarStartAndEndSlots()
    if not startSlot or not endSlot then
        return false
    end
    for i = startSlot, endSlot do
        if IsSlotUsed(i, HOTBAR_CATEGORY_CHAMPION) then
            return true
        end
    end
    return false
end

local function HARDCORE_ShowCPBlockedDialog()
    if not HARDCORE._cpDialogRegistered then
        ZO_Dialogs_RegisterCustomDialog("HARDCORE_CP_BLOCKED", {
            title = {
                text = "Champion Points Detected"
            },
            mainText = {
                text = "Champion Points need to be unslotted before starting the challenge."
            },
            buttons = {
                [1] = {
                    text = SI_OK
                }
            },
            noChoiceCallback = function()
            end
        })
        HARDCORE._cpDialogRegistered = true
    end

    ZO_Dialogs_ShowDialog("HARDCORE_CP_BLOCKED")
end

local function HARDCORE_ShowFeatPermanentWarningDialog(confirmCallback)
    if not HARDCORE._featPermanentWarningDialogRegistered then
        ZO_Dialogs_RegisterCustomDialog("HARDCORE_FEAT_PERMANENT_WARNING", {
            title = {
                text = "Permanent Feat"
            },
            mainText = {
                text = "Feats are permanent and cannot be deactivated.\n\nDo you want to accept this feat?"
            },
            buttons = {
                [1] = {
                    text = "Accept Feat",
                    callback = function(dialog)
                        if dialog.data and dialog.data.confirmCallback then
                            dialog.data.confirmCallback()
                        end
                    end
                },
                [2] = {
                    text = SI_DIALOG_CANCEL
                }
            },
            noChoiceCallback = function()
            end
        })
        HARDCORE._featPermanentWarningDialogRegistered = true
    end

    ZO_Dialogs_ShowDialog("HARDCORE_FEAT_PERMANENT_WARNING", {
        confirmCallback = confirmCallback
    })
end

local function CreateIntroWindow()
    if HARDCORE.window then
        return
    end

    local wm = WINDOW_MANAGER

    local win = wm:CreateTopLevelWindow("HARDCORE_IntroWindow")
    HARDCORE.window = win
    win:SetMovable(false)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetResizeHandleSize(0)
    win:SetHidden(true)
    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, -40)
    win:SetDimensions(980, 610)

    local frame = wm:CreateControl(nil, win, CT_BACKDROP)
    frame:SetAnchorFill()
    frame:SetCenterColor(0, 0, 0, 0.88)
    frame:SetEdgeTexture("/esoui/art/chatwindow/chat_bg_edge.dds", 32, 4, 4)
    frame:SetEdgeColor(0.9, 0.85, 0.65, 1)

    local inner = wm:CreateControl("HARDCORE_Inner", win, CT_CONTROL)
    inner:SetAnchor(TOPLEFT, win, TOPLEFT, 8, 8)
    inner:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -8, -8)

    local bg = wm:CreateControl("HARDCORE_InnerBG", inner, CT_TEXTURE)
    bg:SetAnchorFill(inner)
    bg:SetTexture("/esoui/art/loadingscreens/loadscreen_bw_prologue2_01.dds")
    bg:SetTextureCoords(0, 1, 0, 1)
    bg:SetDrawTier(DT_LOW)
    bg:SetDrawLayer(DL_BACKGROUND)
    bg:SetAlpha(0.64)
    bg:SetBlendMode(TEX_BLEND_MODE_ALPHA)

    local wash = wm:CreateControl("HARDCORE_InnerWash", inner, CT_BACKDROP)
    wash:SetAnchorFill(inner)
    wash:SetCenterColor(0, 0, 0, 0.46)
    wash:SetEdgeColor(0, 0, 0, 0)
    wash:SetEdgeTexture(nil, 1, 1, 0, 0)
    wash:SetDrawTier(DT_LOW)
    wash:SetDrawLayer(DL_BACKGROUND)
    wash:SetDrawLevel(1)

    local subtleEdge = wm:CreateControl("HARDCORE_InnerEdge", inner, CT_BACKDROP)
    subtleEdge:SetAnchorFill(inner)
    subtleEdge:SetCenterColor(0, 0, 0, 0)
    subtleEdge:SetEdgeTexture("/esoui/art/miscellaneous/dark_edgeframe_8_thin.dds", 32, 4, 4)
    subtleEdge:SetEdgeColor(0, 0, 0, 0.25)
    subtleEdge:SetDrawLayer(DL_OVERLAY)
    subtleEdge:SetDrawLevel(1)

    local function Corner(name, tex, anchorPoint, xOff, yOff, w, h)
        local t = wm:CreateControl(name, inner, CT_TEXTURE)
        t:SetTexture(tex)
        t:SetDimensions(w or 16, h or 16)
        t:SetBlendMode(TEX_BLEND_MODE_ALPHA)
        t:SetAlpha(0.9)
        t:SetDrawLayer(DL_OVERLAY)
        t:SetDrawLevel(5)
        t:SetAnchor(anchorPoint, inner, anchorPoint, xOff or 0, yOff or 0)
        return t
    end

    Corner("HARDCORE_CornerTL", "/esoui/art/reticle/border_topleft.dds", TOPLEFT, -1, -1, 16, 16)
    Corner("HARDCORE_CornerTR", "/esoui/art/reticle/border_topright.dds", TOPRIGHT, 1, -1, 16, 16)
    Corner("HARDCORE_CornerBL", "/esoui/art/reticle/border_bottomleft.dds", BOTTOMLEFT, -1, 1, 16, 16)
    Corner("HARDCORE_CornerBR", "/esoui/art/reticle/border_bottomright.dds", BOTTOMRIGHT, 1, 1, 16, 16)

    local title = wm:CreateControl(nil, inner, CT_LABEL)
    title:SetAnchor(TOP, inner, TOP, 0, 20)
    title:SetFont("$(BOLD_FONT)|38|soft-shadow-thick")
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    title:SetText("HARDCORE")
    title:SetColor(COLOR.gold:UnpackRGBA())

    local iconLeft = wm:CreateControl(nil, inner, CT_TEXTURE)
    iconLeft:SetDimensions(40, 40)
    iconLeft:SetAnchor(RIGHT, title, LEFT, -12, 0)
    iconLeft:SetTexture("/esoui/art/icons/poi/poi_solotrial_incomplete.dds")

    local iconRight = wm:CreateControl(nil, inner, CT_TEXTURE)
    iconRight:SetDimensions(40, 40)
    iconRight:SetAnchor(LEFT, title, RIGHT, 12, 0)
    iconRight:SetTexture("/esoui/art/icons/poi/poi_solotrial_incomplete.dds")

    local divider = wm:CreateControl(nil, inner, CT_TEXTURE)
    divider:SetAnchor(TOP, title, BOTTOM, 0, 8)
    divider:SetDimensions(520, 8)
    divider:SetTexture("/esoui/art/miscellaneous/horizontaldivider.dds")
    divider:SetAlpha(0.55)

    local sub = wm:CreateControl(nil, inner, CT_LABEL)
    sub:SetAnchor(TOP, divider, BOTTOM, 0, 10)
    sub:SetFont("$(MEDIUM_FONT)|18|soft-shadow-thin")
    sub:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    sub:SetColor(COLOR.gray:UnpackRGBA())
    sub:SetText("Accept the challenge to enable the ruleset on this character.")
    HARDCORE.subtitle = sub
    HARDCORE.setupControls = {}
    HARDCORE.challengeControls = {}
    HARDCORE._featAcceptRefreshers = {}

    -- Difficulty preset slider
    HARDCORE._ruleRows = {}
    local tier = (HARDCORE.saved and HARDCORE.saved.difficultyTier) or 1

    local diffLabel = wm:CreateControl(nil, inner, CT_LABEL)
    diffLabel:SetAnchor(TOP, sub, BOTTOM, 0, 10)
    diffLabel:SetFont("$(MEDIUM_FONT)|18|soft-shadow-thin")
    diffLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    diffLabel:SetColor(COLOR.gold:UnpackRGBA())
    HARDCORE.difficultyLabel = diffLabel
    table.insert(HARDCORE.setupControls, diffLabel)

    local slider = wm:CreateControlFromVirtual("HARDCORE_DifficultySlider", inner, "ZO_Slider")
    slider:SetDimensions(520, 18)
    slider:SetAnchor(TOP, diffLabel, BOTTOM, 0, 10)
    slider:SetMinMax(1, 5)
    slider:SetValueStep(1)
    slider:SetAllowDraggingFromThumb(true)
    slider:SetValue(tier)
    HARDCORE.difficultySlider = slider
    table.insert(HARDCORE.setupControls, slider)

    slider:SetHandler("OnValueChanged", function(_, value, eventReason)
        if eventReason == EVENT_REASON_HARDWARE then
            local v = zo_round(value)
            slider:SetValue(v) -- snap
            HARDCORE.ApplyDifficultyPreset(v)
        end
    end)

    local scroll = wm:CreateControlFromVirtual("HARDCORE_RulesScroll", inner, "ZO_ScrollContainer")
    scroll:SetAnchor(TOPLEFT, inner, TOPLEFT, 34, 205)
    scroll:SetDimensions(908, 318)
    local scrollChild = scroll:GetNamedChild("ScrollChild")
    table.insert(HARDCORE.setupControls, scroll)

    local COLS, COL_W, ROW_H, ICON = 3, 300, 44, 28

    local function CreateRuleRow(parent, idx, rule)
        local col = ((idx - 1) % COLS) + 1
        local row = math.floor((idx - 1) / COLS)
        local x = (col - 1) * COL_W
        local y = row * ROW_H

        local rowCtrl = wm:CreateControl("HARDCORE_RuleRow" .. idx, parent, CT_CONTROL)
        rowCtrl:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
        rowCtrl:SetDimensions(COL_W - 10, ROW_H)
        rowCtrl:SetMouseEnabled(true)

        local bg = wm:CreateControl(nil, rowCtrl, CT_BACKDROP)
        bg:SetAnchorFill()
        bg:SetCenterColor(0, 0, 0, 0.18)
        bg:SetEdgeColor(1, 1, 1, 0.04)

        local icon = wm:CreateControl(nil, rowCtrl, CT_TEXTURE)
        icon:SetDimensions(ICON, ICON)
        icon:SetAnchor(LEFT, rowCtrl, LEFT, 4, 0)
        icon:SetTexture(rule.icon)
        icon:SetAlpha(0.95)

        local label = wm:CreateControl(nil, rowCtrl, CT_LABEL)
        label:SetAnchor(LEFT, icon, RIGHT, 10, 0)
        label:SetFont("$(MEDIUM_FONT)|20|soft-shadow-thin")
        label:SetText(rule.text)
        label:SetColor(COLOR.white:UnpackRGBA())
        label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

        rowCtrl._bg = bg
        rowCtrl._icon = icon
        rowCtrl._label = label
        rowCtrl._ruleData = rule
        table.insert(HARDCORE._ruleRows, rowCtrl)

        local hitArea = wm:CreateControl(nil, rowCtrl, CT_CONTROL)
        hitArea:SetAnchorFill()
        hitArea:SetMouseEnabled(true)
        rowCtrl._hitArea = hitArea

        local function ToggleCustomRule()
            if rule.alwaysOn or not rule.ruleId then
                return
            end
            if not IsCustomDifficultyTier(HARDCORE.saved and HARDCORE.saved.difficultyTier) then
                return
            end
            if HARDCORE.saved and HARDCORE.saved.isActive then
                return
            end
            if HARDCORE._difficultyControlsEnabled == false then
                return
            end

            local sv = GetRulesSV()
            local enabled = sv.enabled[rule.ruleId] == true
            if HARDCORE.RuleManager and HARDCORE.RuleManager.SetRuleEnabled then
                HARDCORE.RuleManager:SetRuleEnabled(rule.ruleId, not enabled)
            else
                sv.enabled[rule.ruleId] = not enabled
            end
            HARDCORE.RefreshDifficultyUI()
        end

        local function OnEnter()
            label:SetColor(COLOR.gold:UnpackRGBA())
            ShowTip(rowCtrl, rule.tip)
        end

        local function OnExit()
            HideTip()
            if HARDCORE.RefreshDifficultyUI then
                HARDCORE.RefreshDifficultyUI()
            else
                label:SetColor(COLOR.white:UnpackRGBA())
            end
        end

        hitArea:SetHandler("OnMouseEnter", OnEnter)
        hitArea:SetHandler("OnMouseExit", OnExit)
        hitArea:SetHandler("OnMouseUp", ToggleCustomRule)

        return rowCtrl
    end

    for i, rule in ipairs(RULES) do
        CreateRuleRow(scrollChild, i, rule)
    end

    local challengeHeader = wm:CreateControl("HARDCORE_ChallengesHeader", inner, CT_CONTROL)
    challengeHeader:SetAnchor(TOPLEFT, inner, TOPLEFT, 54, 122)
    challengeHeader:SetDimensions(860, 40)
    challengeHeader:SetHidden(true)
    table.insert(HARDCORE.challengeControls, challengeHeader)

    local challengeHeaderLine = wm:CreateControl(nil, challengeHeader, CT_TEXTURE)
    challengeHeaderLine:SetAnchor(BOTTOM, challengeHeader, BOTTOM, 0, 0)
    challengeHeaderLine:SetDimensions(800, 8)
    challengeHeaderLine:SetTexture("/esoui/art/quest/questjournal_divider.dds")
    challengeHeaderLine:SetAlpha(0.75)

    local challengeHeaderIcon = wm:CreateControl(nil, challengeHeader, CT_TEXTURE)
    challengeHeaderIcon:SetAnchor(LEFT, challengeHeader, LEFT, 0, -3)
    challengeHeaderIcon:SetDimensions(26, 26)
    challengeHeaderIcon:SetTexture("/esoui/art/quest/questjournal_trackedquest_icon.dds")
    challengeHeaderIcon:SetAlpha(0.86)

    local challengeHeaderLabel = wm:CreateControl(nil, challengeHeader, CT_LABEL)
    challengeHeaderLabel:SetAnchor(LEFT, challengeHeaderIcon, RIGHT, 9, -2)
    challengeHeaderLabel:SetFont("$(BOLD_FONT)|23|soft-shadow-thick")
    challengeHeaderLabel:SetColor(COLOR.gold:UnpackRGBA())
    challengeHeaderLabel:SetText("Available Feats")

    local challengeScroll = wm:CreateControlFromVirtual("HARDCORE_ChallengesScroll", inner, "ZO_ScrollContainer")
    challengeScroll:SetAnchor(TOPLEFT, inner, TOPLEFT, 54, 178)
    challengeScroll:SetDimensions(860, 318)
    challengeScroll:SetHidden(true)
    table.insert(HARDCORE.challengeControls, challengeScroll)
    local challengeScrollChild = challengeScroll:GetNamedChild("ScrollChild")

    local function CreateStars(parent, difficulty)
        local stars = wm:CreateControl(nil, parent, CT_CONTROL)
        difficulty = zo_clamp(tonumber(difficulty) or 1, 1, 5)
        stars:SetDimensions((difficulty * 23) - 4, 24)
        local starTexture = "/esoui/art/targetmarkers/target_gold_star_64.dds"

        for i = 1, difficulty do
            local star = wm:CreateControl(nil, stars, CT_TEXTURE)
            star:SetDimensions(19, 19)
            star:SetAnchor(LEFT, stars, LEFT, (i - 1) * 23, 0)
            star:SetTexture(starTexture)
            star:SetAlpha(0.95)
        end

        return stars
    end

    local function CreateChallengeRow(parent, idx, challenge)
        local rowCtrl = wm:CreateControl("HARDCORE_ChallengeRow" .. idx, parent, CT_CONTROL)
        rowCtrl:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, (idx - 1) * 104)
        rowCtrl:SetDimensions(842, 92)
        rowCtrl:SetMouseEnabled(true)

        local bg = wm:CreateControl(nil, rowCtrl, CT_BACKDROP)
        bg:SetAnchorFill()
        bg:SetCenterColor(0.02, 0.015, 0.01, 0.76)
        bg:SetEdgeTexture("/esoui/art/chatwindow/chat_bg_edge.dds", 32, 4, 4)
        bg:SetEdgeColor(0.9, 0.72, 0.34, 0.30)

        local glow = wm:CreateControl(nil, rowCtrl, CT_TEXTURE)
        glow:SetAnchorFill()
        glow:SetTexture("/esoui/art/quest/texthighlight.dds")
        glow:SetAlpha(0.07)
        glow:SetBlendMode(TEX_BLEND_MODE_ADD)

        local iconFrame = wm:CreateControl(nil, rowCtrl, CT_BACKDROP)
        iconFrame:SetAnchor(LEFT, rowCtrl, LEFT, 16, 0)
        iconFrame:SetDimensions(42, 42)
        iconFrame:SetCenterColor(0, 0, 0, 0.20)
        iconFrame:SetEdgeTexture(nil, 1, 1, 0, 0)
        iconFrame:SetEdgeColor(0, 0, 0, 0)

        local icon = wm:CreateControl(nil, iconFrame, CT_TEXTURE)
        icon:SetAnchor(CENTER, iconFrame, CENTER, 0, 0)
        icon:SetDimensions(26, 26)
        icon:SetTexture(challenge.icon)
        icon:SetAlpha(0.95)

        local titleLabel = wm:CreateControl(nil, rowCtrl, CT_LABEL)
        titleLabel:SetAnchor(TOPLEFT, iconFrame, TOPRIGHT, 16, -8)
        titleLabel:SetDimensions(486, 25)
        titleLabel:SetFont("$(BOLD_FONT)|20|soft-shadow-thick")
        titleLabel:SetColor(COLOR.white:UnpackRGBA())
        titleLabel:SetText(challenge.title)
        titleLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

        local flavorLabel = wm:CreateControl(nil, rowCtrl, CT_LABEL)
        flavorLabel:SetAnchor(TOPLEFT, titleLabel, BOTTOMLEFT, 0, 2)
        flavorLabel:SetDimensions(510, 48)
        flavorLabel:SetFont("$(MEDIUM_FONT)|15|soft-shadow-thin")
        flavorLabel:SetColor(COLOR.gray:UnpackRGBA())
        flavorLabel:SetText(challenge.flavor)
        flavorLabel:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)

        local actionArea = wm:CreateControl(nil, rowCtrl, CT_CONTROL)
        actionArea:SetAnchor(RIGHT, rowCtrl, RIGHT, -16, 0)
        actionArea:SetDimensions(232, 58)

        local actionDivider = wm:CreateControl(nil, actionArea, CT_TEXTURE)
        actionDivider:SetAnchor(CENTER, actionArea, CENTER, -3, 0)
        actionDivider:SetDimensions(2, 42)
        actionDivider:SetTexture("/esoui/art/miscellaneous/verticaldivider_64.dds")
        actionDivider:SetAlpha(0.34)

        local difficultyArea = wm:CreateControl(nil, actionArea, CT_CONTROL)
        difficultyArea:SetAnchor(LEFT, actionArea, LEFT, 0, 0)
        difficultyArea:SetDimensions(96, 58)

        local stars = CreateStars(difficultyArea, challenge.difficulty or 1)
        stars:SetAnchor(TOP, difficultyArea, TOP, 0, 3)

        local difficultyLabel = wm:CreateControl(nil, difficultyArea, CT_LABEL)
        difficultyLabel:SetAnchor(TOP, stars, BOTTOM, 0, -2)
        difficultyLabel:SetDimensions(96, 20)
        difficultyLabel:SetFont("$(MEDIUM_FONT)|13|soft-shadow-thin")
        difficultyLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        difficultyLabel:SetColor(COLOR.dim:UnpackRGBA())
        difficultyLabel:SetText("Difficulty")

        local acceptButton = wm:CreateControlFromVirtual("HARDCORE_ChallengeAccept" .. idx, rowCtrl, "ZO_DefaultButton")
        acceptButton:SetAnchor(RIGHT, actionArea, RIGHT, 0, 0)
        acceptButton:SetDimensions(104, 34)
        local function IsAccepted()
            return challenge.ruleId and GetRulesSV().enabled[challenge.ruleId] == true
        end
        local function RefreshAcceptButton()
            local accepted = IsAccepted()
            local blockedReason = GetFeatBlockedReason(challenge.ruleId)
            local blocked = not accepted and blockedReason ~= nil
            acceptButton:SetText(accepted and "Accepted" or (blocked and "Blocked" or "Accept"))
            acceptButton:SetEnabled(not accepted and not blocked)
            acceptButton:SetState((accepted or blocked) and BSTATE_DISABLED or BSTATE_NORMAL, accepted or blocked)
        end
        table.insert(HARDCORE._featAcceptRefreshers, RefreshAcceptButton)
        RefreshAcceptButton()
        acceptButton:SetHandler("OnMouseEnter", function()
            titleLabel:SetColor(COLOR.gold:UnpackRGBA())
            if IsAccepted() then
                ShowTip(acceptButton, "This optional challenge is active for the current hardcore run.")
            elseif GetFeatBlockedReason(challenge.ruleId) then
                ShowTip(acceptButton, GetFeatBlockedReason(challenge.ruleId))
            else
                ShowTip(acceptButton, "Accept this optional challenge for the current hardcore run.")
            end
        end)
        acceptButton:SetHandler("OnMouseExit", function()
            titleLabel:SetColor(COLOR.white:UnpackRGBA())
            HideTip()
        end)
        local function AcceptFeat()
            if not challenge.ruleId or IsAccepted() then
                return
            end
            local blockedReason = GetFeatBlockedReason(challenge.ruleId)
            if blockedReason then
                HARDCORE.ShowAlertNoSuppression(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK,
                    "HARDCORE: " .. blockedReason)
                RefreshAcceptButton()
                return
            end
            if HARDCORE.RuleManager and HARDCORE.RuleManager.SetRuleEnabled then
                HARDCORE.RuleManager:SetRuleEnabled(challenge.ruleId, true)
            else
                GetRulesSV().enabled[challenge.ruleId] = true
            end
            HARDCORE.RefreshFeatAcceptButtons()
            PlaySound(SOUNDS.QUEST_ACCEPTED)
            HARDCORE.ShowAlertNoSuppression(UI_ALERT_CATEGORY_ALERT, SOUNDS.QUEST_ACCEPTED,
                "HARDCORE: " .. challenge.title .. " accepted.")
        end
        acceptButton:SetHandler("OnClicked", function()
            if not challenge.ruleId or IsAccepted() then
                return
            end
            local blockedReason = GetFeatBlockedReason(challenge.ruleId)
            if blockedReason then
                HARDCORE.ShowAlertNoSuppression(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK,
                    "HARDCORE: " .. blockedReason)
                RefreshAcceptButton()
                return
            end
            if HARDCORE.saved and not HARDCORE.saved.hasSeenFeatPermanentWarning then
                HARDCORE_ShowFeatPermanentWarningDialog(function()
                    HARDCORE.saved.hasSeenFeatPermanentWarning = true
                    AcceptFeat()
                end)
                return
            end
            AcceptFeat()
        end)

        rowCtrl:SetHandler("OnMouseEnter", function()
            bg:SetCenterColor(0.055, 0.04, 0.025, 0.84)
            bg:SetEdgeColor(1, 0.84, 0.42, 0.52)
        end)
        rowCtrl:SetHandler("OnMouseExit", function()
            bg:SetCenterColor(0.02, 0.015, 0.01, 0.76)
            bg:SetEdgeColor(0.9, 0.72, 0.34, 0.30)
        end)

        return rowCtrl
    end

    local emptyFeatsLabel = wm:CreateControl(nil, challengeScrollChild, CT_LABEL)
    emptyFeatsLabel:SetAnchor(TOPLEFT, challengeScrollChild, TOPLEFT, 16, 16)
    emptyFeatsLabel:SetDimensions(810, 32)
    emptyFeatsLabel:SetFont("$(MEDIUM_FONT)|18|soft-shadow-thin")
    emptyFeatsLabel:SetColor(COLOR.gray:UnpackRGBA())
    emptyFeatsLabel:SetText(FEATS_EMPTY_TEXT)
    emptyFeatsLabel:SetHidden(#FEATS > 0)

    for i, challenge in ipairs(GetSortedFeats()) do
        CreateChallengeRow(challengeScrollChild, i, challenge)
    end

    local savedTier = (HARDCORE.saved and HARDCORE.saved.difficultyTier) or 1
    if IsCustomDifficultyTier(savedTier) then
        HARDCORE.saved.difficultyTier = savedTier
    else
        HARDCORE.ApplyDifficultyPreset(savedTier)
    end
    HARDCORE.RefreshDifficultyUI()

    local function GetHUDSV()
        HARDCORE = HARDCORE or {}
        if not HARDCORE.hudBackup then
            HARDCORE.hudBackup = ZO_SavedVars:NewCharacterIdSettings("HARDCORE_HUD_BACKUP", 1, nil, {
                saved = {
                    allNameplates = nil,
                    allHealthbars = nil,
                    combatCues = nil
                }
            }, GetWorldName())
        end
        return HARDCORE.hudBackup
    end

    local function _boolToSetting(v)
        return v and "1" or "0"
    end

    function HARDCORE.SaveHUDSettings()
        local sv = GetHUDSV()
        sv.saved.allNameplates = GetSetting_Bool(SETTING_TYPE_NAMEPLATES, NAMEPLATE_TYPE_ALL_NAMEPLATES)
        sv.saved.allHealthbars = GetSetting_Bool(SETTING_TYPE_NAMEPLATES, NAMEPLATE_TYPE_ALL_HEALTHBARS)
        sv.saved.combatCues = GetSetting_Bool(SETTING_TYPE_COMBAT, COMBAT_SETTING_MONSTER_TELLS_ENABLED)
    end

    function HARDCORE.RestoreHUDSettings()
        local sv = GetHUDSV()
        if sv.saved.allNameplates ~= nil then
            SetSetting(SETTING_TYPE_NAMEPLATES, NAMEPLATE_TYPE_ALL_NAMEPLATES, _boolToSetting(sv.saved.allNameplates))
        end
        if sv.saved.allHealthbars ~= nil then
            SetSetting(SETTING_TYPE_NAMEPLATES, NAMEPLATE_TYPE_ALL_HEALTHBARS, _boolToSetting(sv.saved.allHealthbars))
        end
        if sv.saved.combatCues ~= nil then
            SetSetting(SETTING_TYPE_COMBAT, COMBAT_SETTING_MONSTER_TELLS_ENABLED, _boolToSetting(sv.saved.combatCues))
        end
    end

    -- Accept / Re-enter / Surrender 
    local btn = wm:CreateControlFromVirtual("HARDCORE_ActionButton", win, "ZO_DefaultButton")
    HARDCORE.actionButton = btn
    btn:SetAnchor(BOTTOM, win, BOTTOM, 0, -18)
    btn:SetDimensions(260, 44)

    local stats = wm:CreateControl("HARDCORE_ActiveStats", win, CT_CONTROL)
    HARDCORE.activeStats = stats
    stats:SetAnchor(LEFT, btn, RIGHT, 82, 0)
    stats:SetDimensions(260, 62)
    stats:SetHidden(true)

    local statsBg = wm:CreateControl(nil, stats, CT_BACKDROP)
    statsBg:SetAnchorFill()
    statsBg:SetCenterColor(0.02, 0.015, 0.01, 0.56)
    statsBg:SetEdgeTexture("/esoui/art/chatwindow/chat_bg_edge.dds", 32, 4, 4)
    statsBg:SetEdgeColor(0.9, 0.72, 0.34, 0.26)

    local classIcon = wm:CreateControl(nil, stats, CT_TEXTURE)
    stats.classIcon = classIcon
    classIcon:SetDimensions(28, 28)
    classIcon:SetAnchor(TOPLEFT, stats, TOPLEFT, 12, 8)
    classIcon:SetAlpha(0.95)

    local levelLabel = wm:CreateControl(nil, stats, CT_LABEL)
    stats.levelLabel = levelLabel
    levelLabel:SetAnchor(LEFT, classIcon, RIGHT, 6, 0)
    levelLabel:SetFont("$(BOLD_FONT)|18|soft-shadow-thin")
    levelLabel:SetColor(COLOR.white:UnpackRGBA())
    levelLabel:SetText("Lv ?")

    local minHpIcon = wm:CreateControl(nil, stats, CT_TEXTURE)
    stats.minHpIcon = minHpIcon
    minHpIcon:SetDimensions(24, 24)
    minHpIcon:SetAnchor(LEFT, levelLabel, RIGHT, 12, 0)
    minHpIcon:SetTexture("/esoui/art/icons/alchemy/crafting_alchemy_trait_restorehealth_conflict.dds")
    minHpIcon:SetAlpha(0.95)

    local arrowIcon = wm:CreateControl(nil, stats, CT_TEXTURE)
    stats.arrowIcon = arrowIcon
    arrowIcon:SetDimensions(16, 16)
    arrowIcon:SetAnchor(LEFT, minHpIcon, RIGHT, 4, 0)
    arrowIcon:SetTexture("/esoui/art/miscellaneous/gamepad/gp_scrollarrow.dds")
    arrowIcon:SetAlpha(0.95)

    local minHpLabel = wm:CreateControl(nil, stats, CT_LABEL)
    stats.minHpLabel = minHpLabel
    minHpLabel:SetAnchor(LEFT, arrowIcon, RIGHT, 4, 0)
    minHpLabel:SetFont("$(BOLD_FONT)|18|soft-shadow-thin")
    minHpLabel:SetColor(COLOR.gray:UnpackRGBA())
    minHpLabel:SetText("100%")

    local playedTimeLabel = wm:CreateControl(nil, stats, CT_LABEL)
    stats.playedTimeLabel = playedTimeLabel
    playedTimeLabel:SetAnchor(TOPLEFT, stats, TOPLEFT, 12, 38)
    playedTimeLabel:SetDimensions(236, 18)
    playedTimeLabel:SetFont("$(MEDIUM_FONT)|13|soft-shadow-thin")
    playedTimeLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    playedTimeLabel:SetColor(COLOR.dim:UnpackRGBA())
    playedTimeLabel:SetText("Alive: --")

    local function UpdateActionButton()
        btn:SetHidden(false)

        local isActive = HARDCORE.saved and HARDCORE.saved.isActive
        if HARDCORE.SetDifficultySliderEnabled then
            HARDCORE.SetDifficultySliderEnabled(not isActive)
        end
        if HARDCORE.SetMainPanelMode then
            HARDCORE.SetMainPanelMode(isActive)
        end

        if isActive then
            local isCompletedRun = HARDCORE.saved.hasSeenCongrats and GetUnitLevel("player") >= 50
            btn:SetEnabled(true)
            btn:SetState(BSTATE_NORMAL, false)
            btn:SetText(isCompletedRun and "End Challenge" or "Surrender")
            if HARDCORE.subtitle then
                HARDCORE.subtitle:SetText("")
            end
            btn:SetHandler("OnMouseEnter", function()
                ShowTip(btn, isCompletedRun and
                    "End the completed hardcore challenge and return to normal." or
                    "End the hardcore challenge and deactivate the rules.")
            end)
            btn:SetHandler("OnMouseExit", HideTip)
            btn:SetHandler("OnClicked", function()
                PlaySound(SOUNDS.NEGATIVE_CLICK)
                HARDCORE.SetDifficultySliderEnabled(true)
                HARDCORE.SurrenderChallenge()
                HARDCORE.RestoreHUDSettings()
                if HARDCORE.subtitle then
                    HARDCORE.subtitle:SetText("Hardcore Mode is inactive. You can re-enter anytime.")
                end
                HARDCORE.ShowAlertNoSuppression(UI_ALERT_CATEGORY_ALERT, SOUNDS.QUEST_ACCEPTED,
                    isCompletedRun and
                    "HARDCORE: Challenge ended. Settings restored." or
                    "HARDCORE: Challenge surrendered. Settings restored.")
                HARDCORE.UpdateActionButton()
                -- Reload UI to apply restored settings
                zo_callLater(function()
                    ReloadUI()
                end, 500)
            end)
            HARDCORE_EnableMinHpTracking()
            HARDCORE.UpdateActiveStatsUI()
        elseif HARDCORE.saved.hasDied then
            btn:SetEnabled(false)
            btn:SetState(BSTATE_DISABLED, true)
            btn:SetText("Challenge Failed")
            btn:SetHandler("OnMouseEnter", function()
                ShowTip(btn, "Your character has fallen. The challenge cannot be reactivated.")
            end)
            btn:SetHandler("OnMouseExit", HideTip)
            btn:SetHandler("OnClicked", nil)
            HARDCORE_DisableMinHpTracking()
            if HARDCORE.SetMainPanelMode then
                HARDCORE.SetMainPanelMode(false)
            end
        else
            btn:SetEnabled(true)
            btn:SetState(BSTATE_NORMAL, false)
            btn:SetText(HARDCORE.saved.hasSeenIntro and "Re-enter Challenge" or "Accept Challenge")
            btn:SetHandler("OnMouseEnter", function()
                ShowTip(btn, "Enable Hardcore Mode on this character.")
            end)
            btn:SetHandler("OnMouseExit", HideTip)
            btn:SetHandler("OnClicked", function()
                local tier = (HARDCORE.saved and tonumber(HARDCORE.saved.difficultyTier)) or 1
                local rulesSV = GetRulesSV()

                if ((tier >= 3 and not IsCustomDifficultyTier(tier)) or
                    (IsCustomDifficultyTier(tier) and rulesSV.enabled.NoCP == true)) and HARDCORE_HasAnyChampionSlotted() then
                    PlaySound(SOUNDS.NEGATIVE_CLICK)
                    HARDCORE_ShowCPBlockedDialog()
                    return
                end
                PlaySound(SOUNDS.INSTANCE_SHUTDOWN)
                PlaySound(SOUNDS.QUEST_ACCEPTED)
                PlaySound(SOUNDS.ENDLESS_DUNGEON_SCORE_FINAL_FLIP)
                HARDCORE.SetDifficultySliderEnabled(false)
                AnnounceTrialBegins()
                HARDCORE.saved.hasSeenIntro = true
                HARDCORE.SaveHUDSettings()
                HARDCORE.BeginChallengeRun()
                if HARDCORE.RuleManager and HARDCORE.RuleManager.SetActive then
                    HARDCORE.RuleManager:SetActive(true)
                end
                if HARDCORE.ChallengeManager and HARDCORE.ChallengeManager.SetActive then
                    HARDCORE.ChallengeManager:SetActive(true)
                end
                HARDCORE.ShowAlertNoSuppression(UI_ALERT_CATEGORY_ALERT, SOUNDS.QUEST_ACCEPTED,
                    "HARDCORE: Challenge active. Good luck!")
                if HARDCORE.subtitle then
                    HARDCORE.subtitle:SetText("")
                end
                HARDCORE.UpdateActionButton()
            end)
            HARDCORE_DisableMinHpTracking()
            if HARDCORE.SetMainPanelMode then
                HARDCORE.SetMainPanelMode(false)
            end
        end
    end

    HARDCORE.UpdateActionButton = UpdateActionButton
    UpdateActionButton()

    local close = wm:CreateControlFromVirtual("HARDCORE_Close", win, "ZO_CloseButton")
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -18, 14)
    close:SetHandler("OnClicked", function()
        win:SetHidden(true)
        DeactivateMenuButton()
    end)

    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local fade = timeline:InsertAnimation(ANIMATION_ALPHA, win)
    fade:SetAlphaValues(0, 1)
    fade:SetDuration(200)
    HARDCORE.fadeIn = function()
        win:SetAlpha(0)
        timeline:PlayFromStart()
    end
end

function HARDCORE.ToggleIntro(playSound)
    if not HARDCORE.window then
        CreateIntroWindow()
    end

    local hidden = HARDCORE.window:IsHidden()
    if hidden then
        HARDCORE.window:SetHidden(false)
        if HARDCORE.RefreshDifficultyUI then
            HARDCORE.RefreshDifficultyUI()
        end
        if HARDCORE.fadeIn then
            HARDCORE.fadeIn()
        end
        if HARDCORE.UpdateActionButton then
            HARDCORE.UpdateActionButton()
        end
        if HARDCORE.subtitle then
            if HARDCORE.saved.isActive then
                HARDCORE.subtitle:SetText("")
            elseif HARDCORE.saved.hasDied then
                HARDCORE.subtitle:SetText("This character has died. The challenge has ended permanently.")
            else
                HARDCORE.subtitle:SetText(HARDCORE.saved.hasSeenIntro and
                                              "Hardcore Mode is inactive. You can re-enter anytime." or
                                              "Accept the challenge to enable the ruleset on this character.")
            end
        end
        ActivateMenuButton()
        SetGameCameraUIMode(true)
        if playSound ~= false then
            PlaySound(SOUNDS.SKILL_XP_DARK_FISSURE_CLOSED)
        end
    else
        HARDCORE.window:SetHidden(true)
        DeactivateMenuButton()
        SetGameCameraUIMode(false)
    end
end

local function OpenHardcoreUI()
    if HARDCORE.saved and HARDCORE.saved.isActive and GetUnitLevel("player") >= 50 and not HARDCORE.saved.hasSeenCongrats then
        HARDCORE.ShowCongratulationsWindow()
        return
    end

    if HARDCORE.saved and HARDCORE.saved.hasDied then
        HARDCORE.ShowAlertNoSuppression(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK, "HARDCORE: Challenge failed. You cannot reactivate it.")
    end

    if not HARDCORE.window then
        CreateIntroWindow()
    end
    HARDCORE.window:SetHidden(false)
    if HARDCORE.fadeIn then
        HARDCORE.fadeIn()
    end
    if HARDCORE.UpdateActionButton then
        HARDCORE.UpdateActionButton()
    end
    SetGameCameraUIMode(true)
    PlaySound(SOUNDS.SKILL_XP_DARK_FISSURE_CLOSED)
end

local PrintDebugHelp
local RunDebugCommand

local function RegisterSlash()
    PrintDebugHelp = function()
        d("HARDCORE debug commands:")
        d("/hc debug help")
        d("/hc debug status")
        d("/hc debug revive")
        d("/hc debug failui")
        d("/hc debug victoryui")
        d("/hc debug feats abandon")
        d("/hc debug rations full")
        d("/hc debug rations empty")
        d("/hc debug rations set <hunger> <thirst>")
        d("/hc debug rations decay <minutes>")
        d("/hc debug rations hud")
        d("/hc debug weariness full")
        d("/hc debug weariness empty")
        d("/hc debug weariness set <fatigue>")
        d("/hc debug weariness rest")
        d("/hc debug weariness stop")
        d("/hc debug weariness hud")
        d("/hc debug bath status")
        d("/hc debug bath due")
        d("/hc debug bath progress <seconds>")
        d("/hc debug bath reset")
        d("/hc debug bath hud")
        d("/hc debug blood status")
        d("/hc debug blood due")
        d("/hc debug blood satisfy")
        d("/hc debug blood reset")
        d("/hc debug blood hud")
        d("/hc debug lockpick status")
        d("/hc debug lockpick fail")
        d("/hc debug lockpick break")
        d("/hc debug lockpick success")
        d("/hc debug lockpick reset")
        d("/hc debug lockpick hud")
        d("/hc debug barbarian status")
        d("/hc debug barbarian enforce")
        d("/hc debug handsfree status")
        d("/hc debug handsfree enforce")
        d("/hc debug selfmade status")
        d("/hc debug selfmade enforce")
        d("/hc debug whispers status")
        d("/hc debug whispers play")
        d("/hc debug lightsout status")
        d("/hc debug lightsout blackout")
    end

    RunDebugCommand = function(args)
        if not (HARDCORE.saved and HARDCORE.saved.debugMode) then
            HARDCORE.ShowAlertNoSuppression(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK,
                "HARDCORE: Debug mode is disabled in addon settings.")
            return
        end

        args = args or ""
        local tokens = {}
        for token in string.gmatch(args, "%S+") do
            tokens[#tokens + 1] = string.lower(token)
        end

        local area = tokens[2]
        local action = tokens[3]
        if not area or area == "help" then
            PrintDebugHelp()
            return
        end

        if area == "status" then
            d("HARDCORE active=" .. tostring(HARDCORE.saved and HARDCORE.saved.isActive) ..
                " died=" .. tostring(HARDCORE.saved and HARDCORE.saved.hasDied) ..
                " tier=" .. tostring(HARDCORE.saved and HARDCORE.saved.difficultyTier))
            if HARDCORE.DebugTrailRationsStatus then
                HARDCORE.DebugTrailRationsStatus()
            end
            if HARDCORE.DebugRoadWearinessStatus then
                HARDCORE.DebugRoadWearinessStatus()
            end
            if HARDCORE.DebugSwimDisciplineStatus then
                HARDCORE.DebugSwimDisciplineStatus()
            end
            if HARDCORE.DebugNeedOfBloodStatus then
                HARDCORE.DebugNeedOfBloodStatus()
            end
            if HARDCORE.DebugLockpickNervesStatus then
                HARDCORE.DebugLockpickNervesStatus()
            end
            if HARDCORE.DebugBarbarianStatus then
                HARDCORE.DebugBarbarianStatus()
            end
            if HARDCORE.DebugHandsFreeStatus then
                HARDCORE.DebugHandsFreeStatus()
            end
            if HARDCORE.DebugSelfMadeStatus then
                HARDCORE.DebugSelfMadeStatus()
            end
            if HARDCORE.DebugUnseenWhispersStatus then
                HARDCORE.DebugUnseenWhispersStatus()
            end
            if HARDCORE.DebugLightsOutStatus then
                HARDCORE.DebugLightsOutStatus()
            end
            return
        end

        if area == "revive" or area == "resetdeath" then
            if HARDCORE.DebugResetFailedChallenge and HARDCORE.DebugResetFailedChallenge() then
                HARDCORE.ShowAlertNoSuppression(UI_ALERT_CATEGORY_ALERT, SOUNDS.QUEST_ACCEPTED,
                    "HARDCORE: Failed challenge state reset. Use /hc to re-enter.")
            else
                HARDCORE.ShowAlertNoSuppression(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK,
                    "HARDCORE: Failed challenge state could not be reset.")
            end
            return
        end

        if area == "failui" or area == "deathui" then
            if HARDCORE.ShowDeathWindow then
                HARDCORE.ShowDeathWindow(true)
            end
            return
        end

        if area == "victoryui" or area == "winui" then
            if HARDCORE.ShowCongratulationsWindow then
                HARDCORE.ShowCongratulationsWindow(true)
            end
            return
        end

        if area == "feats" then
            if action ~= "abandon" then
                d("Usage: /hc debug feats abandon")
                return
            end

            local disabledCount = 0
            local sv = GetRulesSV()
            for id in pairs(FEAT_RULE_IDS) do
                if sv.enabled[id] == true then
                    disabledCount = disabledCount + 1
                end
                if HARDCORE.RuleManager and HARDCORE.RuleManager.SetRuleEnabled then
                    HARDCORE.RuleManager:SetRuleEnabled(id, false)
                else
                    sv.enabled[id] = false
                end
            end

            if HARDCORE.RefreshDifficultyUI then
                HARDCORE.RefreshDifficultyUI()
            end
            for _, refresh in ipairs(HARDCORE._featAcceptRefreshers or {}) do
                refresh()
            end
            HARDCORE.ShowAlertNoSuppression(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK,
                "HARDCORE: " .. tostring(disabledCount) .. " feat(s) abandoned.")
            return
        end

        if area == "weariness" then
            if not HARDCORE.DebugRoadWearinessCommand then
                d("HARDCORE: Road Weariness debug helpers are not loaded.")
                return
            end
            HARDCORE.DebugRoadWearinessCommand(action or "help", tokens[4])
            return
        end

        if area == "swim" or area == "bath" then
            if not HARDCORE.DebugSwimDisciplineCommand then
                d("HARDCORE: Mandatory Bath Time debug helpers are not loaded.")
                return
            end
            HARDCORE.DebugSwimDisciplineCommand(action or "help", tokens[4])
            return
        end

        if area == "blood" or area == "needblood" then
            if not HARDCORE.DebugNeedOfBloodCommand then
                d("HARDCORE: Need of Blood debug helpers are not loaded.")
                return
            end
            HARDCORE.DebugNeedOfBloodCommand(action or "help")
            return
        end

        if area == "lockpick" then
            if not HARDCORE.DebugLockpickNervesCommand then
                d("HARDCORE: Lockpick Nerves debug helpers are not loaded.")
                return
            end
            HARDCORE.DebugLockpickNervesCommand(action or "help")
            return
        end

        if area == "barbarian" then
            if not HARDCORE.DebugBarbarianCommand then
                d("HARDCORE: Barbarian debug helpers are not loaded.")
                return
            end
            HARDCORE.DebugBarbarianCommand(action or "help")
            return
        end

        if area == "handsfree" or area == "hands" then
            if not HARDCORE.DebugHandsFreeCommand then
                d("HARDCORE: Hands Free debug helpers are not loaded.")
                return
            end
            HARDCORE.DebugHandsFreeCommand(action or "help")
            return
        end

        if area == "selfmade" or area == "self" then
            if not HARDCORE.DebugSelfMadeCommand then
                d("HARDCORE: Self Made debug helpers are not loaded.")
                return
            end
            HARDCORE.DebugSelfMadeCommand(action or "help")
            return
        end

        if area == "whispers" or area == "unseenwhispers" then
            if not HARDCORE.DebugUnseenWhispersCommand then
                d("HARDCORE: Unseen Whispers debug helpers are not loaded.")
                return
            end
            HARDCORE.DebugUnseenWhispersCommand(action or "help")
            return
        end

        if area == "lightsout" or area == "lights" then
            if not HARDCORE.DebugLightsOutCommand then
                d("HARDCORE: Lights Out debug helpers are not loaded.")
                return
            end
            HARDCORE.DebugLightsOutCommand(action or "help")
            return
        end

        if area ~= "rations" then
            PrintDebugHelp()
            return
        end

        if not HARDCORE.DebugTrailRationsCommand then
            d("HARDCORE: Trail Rations debug helpers are not loaded.")
            return
        end

        HARDCORE.DebugTrailRationsCommand(action or "help", tokens[4], tokens[5])
    end

    local function ShowHardcoreWindow(args)
        args = args or ""
        if string.match(string.lower(args), "^%s*debug") then
            RunDebugCommand(args)
            return
        end

        OpenHardcoreUI()
    end

    SLASH_COMMANDS["/hc"] = ShowHardcoreWindow
    SLASH_COMMANDS["/hardcore"] = ShowHardcoreWindow
end

local function OnAddOnLoaded(event, addonName)
    if addonName ~= ADDON_NAME then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    HARDCORE.saved = ZO_SavedVars:NewCharacterIdSettings("HARDCORE_SV", 1, nil, HARDCORE.defaults, GetWorldName())
    if HARDCORE.saved.isActive then
        if HARDCORE.saved.minHealthPct == nil then
            HARDCORE.saved.minHealthPct = 100
        end
        if HARDCORE.saved.persistedMinHealthPct == nil then
            HARDCORE.saved.persistedMinHealthPct = 100
        end
        HARDCORE_EnableMinHpTracking()
        zo_callLater(function()
            if HARDCORE.SetDifficultySliderEnabled then
                HARDCORE.SetDifficultySliderEnabled(false)
            end
        end, 100)
    end

    if HARDCORE.RuleManager and HARDCORE.RuleManager.Init then
        HARDCORE.RuleManager:Init()
    end
    local lam = LibAddonMenu2
    if lam then
        local HUD_STYLE_SQUARE = "square"
        local HUD_STYLE_HORIZONTAL = "horizontal"
        local HUD_STYLE_CHOICES = { "Square icons", "Horizontal bars" }
        local HUD_STYLE_VALUES = { HUD_STYLE_SQUARE, HUD_STYLE_HORIZONTAL }
        local DEFAULT_HUD_SCALE = 1
        local MIN_HUD_SCALE = 0.60
        local MAX_HUD_SCALE = 1.50

        local function NormalizeHudSettings(hud)
            if hud.displayStyle ~= HUD_STYLE_HORIZONTAL and hud.displayStyle ~= HUD_STYLE_SQUARE then
                hud.displayStyle = hud.horizontalBars == true and HUD_STYLE_HORIZONTAL or HUD_STYLE_SQUARE
            end
            hud.horizontalBars = nil
            hud.scale = zo_clamp(tonumber(hud.scale) or DEFAULT_HUD_SCALE, MIN_HUD_SCALE, MAX_HUD_SCALE)
        end

        local function SetHudStyle(hud, value)
            hud.displayStyle = value == HUD_STYLE_HORIZONTAL and HUD_STYLE_HORIZONTAL or HUD_STYLE_SQUARE
            hud.horizontalBars = nil
        end

        local function SetHudScale(hud, value)
            hud.scale = zo_clamp(tonumber(value) or DEFAULT_HUD_SCALE, MIN_HUD_SCALE, MAX_HUD_SCALE)
        end

        local function RefreshNoHealthBarOptions()
            local rm = HARDCORE.RuleManager
            if not (rm and rm.GetRule) then
                return
            end
            local rule = rm:GetRule("NoHealthBar")
            if rule and rule.RefreshOptions then
                rule:RefreshOptions()
            end
        end
        local function GetTrailRationsSV()
            local sv
            if HARDCORE.GetTrailRationsSV then
                sv = HARDCORE.GetTrailRationsSV()
            else
                sv = {
                    hud = {
                        unlocked = false,
                        showLabels = true,
                        vignette = true,
                        displayStyle = HUD_STYLE_SQUARE,
                        scale = DEFAULT_HUD_SCALE
                    },
                    settings = {
                        hungerDrainMinutes = 90,
                        thirstDrainMinutes = 45,
                        useEmotes = false,
                        eatRefillAmount = 20,
                        drinkRefillAmount = 20,
                        eatStartDelayMs = 0,
                        drinkStartDelayMs = 0
                    }
                }
            end
            sv.hud = sv.hud or {}
            NormalizeHudSettings(sv.hud)
            return sv
        end
        local function RefreshTrailRationsOptions()
            if HARDCORE.RefreshTrailRationsOptions then
                HARDCORE.RefreshTrailRationsOptions()
            end
        end
        local function GetRoadWearinessSV()
            local sv
            if HARDCORE.GetRoadWearinessSV then
                sv = HARDCORE.GetRoadWearinessSV()
            else
                sv = {
                    hud = {
                        unlocked = false,
                        showLabels = true,
                        displayStyle = HUD_STYLE_SQUARE,
                        scale = DEFAULT_HUD_SCALE
                    },
                    settings = {
                        fatigueDrainMinutes = 90,
                        restoreSeconds = 60,
                        staminaDrainMultiplier = 18,
                        actionDrain = 0.35,
                        combatDrain = 0.20,
                        weaponLockThreshold = 20,
                        npcLockThreshold = 10
                    }
                }
            end
            sv.hud = sv.hud or {}
            NormalizeHudSettings(sv.hud)
            return sv
        end
        local function RefreshRoadWearinessOptions()
            if HARDCORE.RefreshRoadWearinessOptions then
                HARDCORE.RefreshRoadWearinessOptions()
            end
        end
        local function GetSwimDisciplineSV()
            if HARDCORE.GetSwimDisciplineSV then
                return HARDCORE.GetSwimDisciplineSV()
            end
            return {
                hud = {
                    unlocked = false,
                    showLabels = true
                }
            }
        end
        local function RefreshSwimDisciplineOptions()
            if HARDCORE.RefreshSwimDisciplineOptions then
                HARDCORE.RefreshSwimDisciplineOptions()
            end
        end
        local function GetNoSwimmingSV()
            if HARDCORE.GetNoSwimmingSV then
                return HARDCORE.GetNoSwimmingSV()
            end
            return {
                hud = {
                    unlocked = false,
                    showLabels = true
                }
            }
        end
        local function RefreshNoSwimmingOptions()
            if HARDCORE.RefreshNoSwimmingOptions then
                HARDCORE.RefreshNoSwimmingOptions()
            end
        end
        local function GetNeedOfBloodSV()
            if HARDCORE.GetNeedOfBloodSV then
                return HARDCORE.GetNeedOfBloodSV()
            end
            return {
                hud = {
                    unlocked = false,
                    showLabels = true
                }
            }
        end
        local function RefreshNeedOfBloodOptions()
            if HARDCORE.RefreshNeedOfBloodOptions then
                HARDCORE.RefreshNeedOfBloodOptions()
            end
        end
        local function GetLockpickNervesSV()
            if HARDCORE.GetLockpickNervesSV then
                return HARDCORE.GetLockpickNervesSV()
            end
            return {
                hud = {
                    unlocked = false,
                    showLabels = true
                }
            }
        end
        local function RefreshLockpickNervesOptions()
            if HARDCORE.RefreshLockpickNervesOptions then
                HARDCORE.RefreshLockpickNervesOptions()
            end
        end
        local function AreDebugButtonsDisabled()
            return not (HARDCORE.saved and HARDCORE.saved.debugMode)
        end
        local function RunDebugButtonCommand(command)
            if RunDebugCommand then
                RunDebugCommand(command)
            end
        end
        local debugControls = {{
            type = "checkbox",
            name = "Debug mode",
            tooltip = "Enable /hc debug commands for testing addon behavior.",
            width = "full",
            getFunc = function()
                return HARDCORE.saved and HARDCORE.saved.debugMode
            end,
            setFunc = function(val)
                if HARDCORE.saved then
                    HARDCORE.saved.debugMode = val and true or false
                end
            end,
            default = false
        }}
        local function AddDebugButton(name, command, tooltip)
            debugControls[#debugControls + 1] = {
                type = "button",
                name = name,
                tooltip = tooltip or ("/hc " .. command),
                width = "full",
                disabled = AreDebugButtonsDisabled,
                func = function()
                    RunDebugButtonCommand(command)
                end
            }
        end

        AddDebugButton("Print debug help", "debug help")
        AddDebugButton("Print full status", "debug status")
        AddDebugButton("Reset failed challenge", "debug revive")
        AddDebugButton("Preview failure UI", "debug failui")
        AddDebugButton("Preview victory UI", "debug victoryui")
        AddDebugButton("Abandon all feats", "debug feats abandon")
        AddDebugButton("Trail Rations: fill meters", "debug rations full")
        AddDebugButton("Trail Rations: empty meters", "debug rations empty")
        AddDebugButton("Trail Rations: show HUD", "debug rations hud")
        AddDebugButton("Road Weariness: fill fatigue", "debug weariness full")
        AddDebugButton("Road Weariness: empty fatigue", "debug weariness empty")
        AddDebugButton("Road Weariness: start rest", "debug weariness rest")
        AddDebugButton("Road Weariness: stop rest", "debug weariness stop")
        AddDebugButton("Road Weariness: show HUD", "debug weariness hud")
        AddDebugButton("Mandatory Bath Time: status", "debug bath status")
        AddDebugButton("Mandatory Bath Time: make due", "debug bath due")
        AddDebugButton("Mandatory Bath Time: reset", "debug bath reset")
        AddDebugButton("Mandatory Bath Time: show HUD", "debug bath hud")
        AddDebugButton("Need of Blood: status", "debug blood status")
        AddDebugButton("Need of Blood: make due", "debug blood due")
        AddDebugButton("Need of Blood: satisfy", "debug blood satisfy")
        AddDebugButton("Need of Blood: reset", "debug blood reset")
        AddDebugButton("Need of Blood: show HUD", "debug blood hud")
        AddDebugButton("Lockpick Nerves: status", "debug lockpick status")
        AddDebugButton("Lockpick Nerves: fail", "debug lockpick fail")
        AddDebugButton("Lockpick Nerves: break", "debug lockpick break")
        AddDebugButton("Lockpick Nerves: success", "debug lockpick success")
        AddDebugButton("Lockpick Nerves: reset", "debug lockpick reset")
        AddDebugButton("Lockpick Nerves: show HUD", "debug lockpick hud")
        AddDebugButton("Barbarian: status", "debug barbarian status")
        AddDebugButton("Barbarian: enforce", "debug barbarian enforce")
        AddDebugButton("Hands Free: status", "debug handsfree status")
        AddDebugButton("Hands Free: enforce", "debug handsfree enforce")
        AddDebugButton("Self Made: status", "debug selfmade status")
        AddDebugButton("Self Made: enforce", "debug selfmade enforce")
        AddDebugButton("Unseen Whispers: status", "debug whispers status")
        AddDebugButton("Unseen Whispers: play sound", "debug whispers play")
        AddDebugButton("Lights Out: status", "debug lightsout status")
        AddDebugButton("Lights Out: blackout", "debug lightsout blackout")

        local panelData = {
            type = "panel",
            name = "HARDCORE",
            version = HARDCORE.version,
            displayName = "|cFFD700HARDCORE|r",
            registerForRefresh = true,
            registerForDefaults = true
        }
        lam:RegisterAddonPanel("HARDCORE_LAM", panelData)
        lam:RegisterOptionControls("HARDCORE_LAM", {{
            type = "button",
            name = "Open HARDCORE UI",
            tooltip = "Open the main HARDCORE challenge window.",
            width = "full",
            func = OpenHardcoreUI
        }, {
            type = "submenu",
            name = "General",
            tooltip = "Configure common HARDCORE behavior.",
            controls = {{
                type = "checkbox",
                name = "Disable vision dim",
                tooltip = "Hide the health bar but skip the screen darkening/vignette effect.",
                width = "full",
                getFunc = function()
                    return HARDCORE.saved and HARDCORE.saved.disableVisionDim
                end,
                setFunc = function(val)
                    if HARDCORE.saved then
                        HARDCORE.saved.disableVisionDim = val and true or false
                    end
                    RefreshNoHealthBarOptions()
                end,
                default = false
            }, {
                type = "checkbox",
                name = "Disable low-health volume drop",
                tooltip = "Prevent audio volume from being reduced when your health is low.",
                width = "full",
                getFunc = function()
                    return HARDCORE.saved and HARDCORE.saved.disableLowHealthVolume
                end,
                setFunc = function(val)
                    if HARDCORE.saved then
                        HARDCORE.saved.disableLowHealthVolume = val and true or false
                    end
                    RefreshNoHealthBarOptions()
                end,
                default = false
            }, {
                type = "checkbox",
                name = "Disable notification messages",
                tooltip = "Hide HARDCORE alert messages generated by this addon.",
                width = "full",
                getFunc = function()
                    return HARDCORE.saved and HARDCORE.saved.disableNotificationMessages
                end,
                setFunc = function(val)
                    if HARDCORE.saved then
                        HARDCORE.saved.disableNotificationMessages = val and true or false
                    end
                end,
                default = false
            }, {
                type = "checkbox",
                name = "Plot Armor",
                tooltip = "Death can be dramatic, but it will not fail or end the active challenge.",
                width = "full",
                getFunc = function()
                    return HARDCORE.saved and HARDCORE.saved.neverDie
                end,
                setFunc = function(val)
                    if HARDCORE.saved then
                        local enabled = val and true or false
                        local wasEnabled = HARDCORE.saved.neverDie == true
                        HARDCORE.saved.neverDie = enabled
                        if enabled and not wasEnabled then
                            PlaySound(SOUNDS.DAEDRIC_ARTIFACT_SPAWNED)
                        end
                    end
                end,
                default = false
            }, {
                type = "checkbox",
                name = "Allow home travel",
                tooltip = "Allow travel to player homes while Bound Wayshrines or No Wayshrines is active.",
                width = "full",
                getFunc = function()
                    return HARDCORE.saved and HARDCORE.saved.allowHomeTravel
                end,
                setFunc = function(val)
                    if HARDCORE.saved then
                        HARDCORE.saved.allowHomeTravel = val and true or false
                    end
                end,
                default = false
            }}
        }, {
            type = "submenu",
            name = "Trail Rations",
            tooltip = "Configure hunger, thirst, ration recovery, and the survival display.",
            controls = {{
                type = "slider",
                name = "Hunger drain time",
                tooltip = "Minutes before hunger drains from full to empty.",
                min = 5,
                max = 240,
                step = 5,
                width = "full",
                getFunc = function()
                    return GetTrailRationsSV().settings.hungerDrainMinutes
                end,
                setFunc = function(value)
                    GetTrailRationsSV().settings.hungerDrainMinutes = value
                end,
                default = 90
            }, {
                type = "slider",
                name = "Thirst drain time",
                tooltip = "Minutes before thirst drains from full to empty.",
                min = 5,
                max = 240,
                step = 5,
                width = "full",
                getFunc = function()
                    return GetTrailRationsSV().settings.thirstDrainMinutes
                end,
                setFunc = function(value)
                    GetTrailRationsSV().settings.thirstDrainMinutes = value
                end,
                default = 45
            }, {
                type = "checkbox",
                name = "Use /eat and /drink emotes",
                tooltip = "Restore hunger and thirst from emote animation windows instead of food and drink consumables.",
                width = "full",
                getFunc = function()
                    return GetTrailRationsSV().settings.useEmotes == true
                end,
                setFunc = function(value)
                    GetTrailRationsSV().settings.useEmotes = value and true or false
                    RefreshTrailRationsOptions()
                end,
                default = false
            }, {
                type = "slider",
                name = "/eat animation offset",
                tooltip = "Milliseconds after /eat before hunger starts restoring. Use this to match the visible eating animation.",
                min = 0,
                max = 5000,
                step = 100,
                width = "full",
                disabled = function()
                    return GetTrailRationsSV().settings.useEmotes ~= true
                end,
                getFunc = function()
                    return GetTrailRationsSV().settings.eatStartDelayMs
                end,
                setFunc = function(value)
                    GetTrailRationsSV().settings.eatStartDelayMs = value
                end,
                default = 0
            }, {
                type = "slider",
                name = "/eat hunger restored",
                tooltip = "Hunger restored during each three-second /eat animation.",
                min = 1,
                max = 100,
                step = 1,
                width = "full",
                disabled = function()
                    return GetTrailRationsSV().settings.useEmotes ~= true
                end,
                getFunc = function()
                    return GetTrailRationsSV().settings.eatRefillAmount
                end,
                setFunc = function(value)
                    GetTrailRationsSV().settings.eatRefillAmount = value
                end,
                default = 20
            }, {
                type = "slider",
                name = "/drink animation offset",
                tooltip = "Milliseconds after /drink before thirst starts restoring. Use this to match the visible drinking animation.",
                min = 0,
                max = 5000,
                step = 100,
                width = "full",
                disabled = function()
                    return GetTrailRationsSV().settings.useEmotes ~= true
                end,
                getFunc = function()
                    return GetTrailRationsSV().settings.drinkStartDelayMs
                end,
                setFunc = function(value)
                    GetTrailRationsSV().settings.drinkStartDelayMs = value
                end,
                default = 0
            }, {
                type = "slider",
                name = "/drink thirst restored",
                tooltip = "Thirst restored during each 2.5-second /drink animation.",
                min = 1,
                max = 100,
                step = 1,
                width = "full",
                disabled = function()
                    return GetTrailRationsSV().settings.useEmotes ~= true
                end,
                getFunc = function()
                    return GetTrailRationsSV().settings.drinkRefillAmount
                end,
                setFunc = function(value)
                    GetTrailRationsSV().settings.drinkRefillAmount = value
                end,
                default = 20
            }, {
                type = "checkbox",
                name = "Unlock survival HUD",
                tooltip = "Allow the Trail Rations HUD to be dragged. Lock it again for normal play.",
                width = "full",
                getFunc = function()
                    return GetTrailRationsSV().hud.unlocked == true
                end,
                setFunc = function(val)
                    GetTrailRationsSV().hud.unlocked = val and true or false
                    RefreshTrailRationsOptions()
                end,
                default = false
            }, {
                type = "checkbox",
                name = "Show meter labels",
                tooltip = "Show Hunger and Thirst text on the survival display.",
                width = "full",
                getFunc = function()
                    return GetTrailRationsSV().hud.showLabels == true
                end,
                setFunc = function(val)
                    GetTrailRationsSV().hud.showLabels = val and true or false
                    RefreshTrailRationsOptions()
                end,
                default = true
            }, {
                type = "dropdown",
                name = "HUD style",
                tooltip = "Choose whether Trail Rations uses square icons or compact horizontal bars.",
                choices = HUD_STYLE_CHOICES,
                choicesValues = HUD_STYLE_VALUES,
                width = "full",
                getFunc = function()
                    return GetTrailRationsSV().hud.displayStyle
                end,
                setFunc = function(value)
                    SetHudStyle(GetTrailRationsSV().hud, value)
                    RefreshTrailRationsOptions()
                end,
                default = HUD_STYLE_SQUARE
            }, {
                type = "slider",
                name = "HUD scale",
                tooltip = "Scale the Trail Rations HUD in either display style.",
                min = MIN_HUD_SCALE,
                max = MAX_HUD_SCALE,
                step = 0.05,
                decimals = 2,
                width = "full",
                getFunc = function()
                    return GetTrailRationsSV().hud.scale
                end,
                setFunc = function(value)
                    SetHudScale(GetTrailRationsSV().hud, value)
                    RefreshTrailRationsOptions()
                end,
                default = DEFAULT_HUD_SCALE
            }, {
                type = "button",
                name = "Reset HUD position",
                tooltip = "Move the Trail Rations HUD back to its default position.",
                width = "full",
                func = function()
                    if HARDCORE.ResetTrailRationsHudPosition then
                        HARDCORE.ResetTrailRationsHudPosition()
                    end
                end
            }, {
                type = "button",
                name = "Reset hunger/thirst meters",
                tooltip = "Restore both survival meters to full.",
                width = "full",
                func = function()
                    if HARDCORE.ResetTrailRationsMeters then
                        HARDCORE.ResetTrailRationsMeters()
                    end
                end
            }}
        }, {
            type = "submenu",
            name = "Road Weariness",
            tooltip = "Configure fatigue, recovery, lockouts, and the weariness display.",
            controls = {{
                type = "slider",
                name = "Fatigue drain time",
                tooltip = "Minutes before weariness drains from full to empty while not resting.",
                min = 10,
                max = 300,
                step = 5,
                width = "full",
                getFunc = function()
                    return GetRoadWearinessSV().settings.fatigueDrainMinutes
                end,
                setFunc = function(value)
                    GetRoadWearinessSV().settings.fatigueDrainMinutes = value
                end,
                default = 90
            }, {
                type = "slider",
                name = "Rest recovery time",
                tooltip = "Seconds for rest to restore weariness from empty to full.",
                min = 5,
                max = 180,
                step = 5,
                width = "full",
                getFunc = function()
                    return GetRoadWearinessSV().settings.restoreSeconds
                end,
                setFunc = function(value)
                    GetRoadWearinessSV().settings.restoreSeconds = value
                end,
                default = 60
            }, {
                type = "slider",
                name = "Stamina loss penalty",
                tooltip = "Extra weariness lost from stamina spending while moving.",
                min = 0,
                max = 50,
                step = 1,
                width = "full",
                getFunc = function()
                    return GetRoadWearinessSV().settings.staminaDrainMultiplier
                end,
                setFunc = function(value)
                    GetRoadWearinessSV().settings.staminaDrainMultiplier = value
                end,
                default = 18
            }, {
                type = "slider",
                name = "Action fatigue loss",
                tooltip = "Weariness lost when using an action slot ability.",
                min = 0,
                max = 2,
                step = 0.05,
                decimals = 2,
                width = "full",
                getFunc = function()
                    return GetRoadWearinessSV().settings.actionDrain
                end,
                setFunc = function(value)
                    GetRoadWearinessSV().settings.actionDrain = value
                end,
                default = 0.35
            }, {
                type = "slider",
                name = "Combat hit fatigue loss",
                tooltip = "Weariness lost for player damage events, throttled by the rule.",
                min = 0,
                max = 2,
                step = 0.05,
                decimals = 2,
                width = "full",
                getFunc = function()
                    return GetRoadWearinessSV().settings.combatDrain
                end,
                setFunc = function(value)
                    GetRoadWearinessSV().settings.combatDrain = value
                end,
                default = 0.20
            }, {
                type = "slider",
                name = "Weapon lock threshold",
                tooltip = "At or below this weariness value, equipped weapons are removed until you rest.",
                min = 0,
                max = 100,
                step = 1,
                width = "full",
                getFunc = function()
                    return GetRoadWearinessSV().settings.weaponLockThreshold
                end,
                setFunc = function(value)
                    GetRoadWearinessSV().settings.weaponLockThreshold = value
                end,
                default = 20
            }, {
                type = "slider",
                name = "NPC lock threshold",
                tooltip = "At or below this weariness value, NPC conversations and quest dialogs are blocked.",
                min = 0,
                max = 100,
                step = 1,
                width = "full",
                getFunc = function()
                    return GetRoadWearinessSV().settings.npcLockThreshold
                end,
                setFunc = function(value)
                    GetRoadWearinessSV().settings.npcLockThreshold = value
                end,
                default = 10
            }, {
                type = "checkbox",
                name = "Unlock weariness HUD",
                tooltip = "Allow the Road Weariness HUD to be dragged. Lock it again for normal play.",
                width = "full",
                getFunc = function()
                    return GetRoadWearinessSV().hud.unlocked == true
                end,
                setFunc = function(val)
                    GetRoadWearinessSV().hud.unlocked = val and true or false
                    RefreshRoadWearinessOptions()
                end,
                default = false
            }, {
                type = "checkbox",
                name = "Show meter label",
                tooltip = "Show the Rest label on the weariness display.",
                width = "full",
                getFunc = function()
                    return GetRoadWearinessSV().hud.showLabels == true
                end,
                setFunc = function(val)
                    GetRoadWearinessSV().hud.showLabels = val and true or false
                    RefreshRoadWearinessOptions()
                end,
                default = true
            }, {
                type = "dropdown",
                name = "HUD style",
                tooltip = "Choose whether Road Weariness uses a square icon or compact horizontal bar.",
                choices = HUD_STYLE_CHOICES,
                choicesValues = HUD_STYLE_VALUES,
                width = "full",
                getFunc = function()
                    return GetRoadWearinessSV().hud.displayStyle
                end,
                setFunc = function(value)
                    SetHudStyle(GetRoadWearinessSV().hud, value)
                    RefreshRoadWearinessOptions()
                end,
                default = HUD_STYLE_SQUARE
            }, {
                type = "slider",
                name = "HUD scale",
                tooltip = "Scale the Road Weariness HUD in either display style.",
                min = MIN_HUD_SCALE,
                max = MAX_HUD_SCALE,
                step = 0.05,
                decimals = 2,
                width = "full",
                getFunc = function()
                    return GetRoadWearinessSV().hud.scale
                end,
                setFunc = function(value)
                    SetHudScale(GetRoadWearinessSV().hud, value)
                    RefreshRoadWearinessOptions()
                end,
                default = DEFAULT_HUD_SCALE
            }, {
                type = "button",
                name = "Reset HUD position",
                tooltip = "Move the Road Weariness HUD back beside the Trail Rations meters.",
                width = "full",
                func = function()
                    if HARDCORE.ResetRoadWearinessHudPosition then
                        HARDCORE.ResetRoadWearinessHudPosition()
                    end
                end
            }, {
                type = "button",
                name = "Reset fatigue meter",
                tooltip = "Restore weariness to full.",
                width = "full",
                func = function()
                    if HARDCORE.ResetRoadWearinessMeter then
                        HARDCORE.ResetRoadWearinessMeter()
                    end
                end
            }}
        }, {
            type = "submenu",
            name = "Mandatory Bath Time",
            tooltip = "Configure the periodic bath requirement display.",
            controls = {{
                type = "checkbox",
                name = "Unlock bath HUD",
                tooltip = "Allow the Mandatory Bath Time HUD to be dragged. Lock it again for normal play.",
                width = "full",
                getFunc = function()
                    return GetSwimDisciplineSV().hud.unlocked == true
                end,
                setFunc = function(val)
                    GetSwimDisciplineSV().hud.unlocked = val and true or false
                    RefreshSwimDisciplineOptions()
                end,
                default = false
            }, {
                type = "checkbox",
                name = "Show bath label",
                tooltip = "Show the Bath label above the requirement status.",
                width = "full",
                getFunc = function()
                    return GetSwimDisciplineSV().hud.showLabels == true
                end,
                setFunc = function(val)
                    GetSwimDisciplineSV().hud.showLabels = val and true or false
                    RefreshSwimDisciplineOptions()
                end,
                default = true
            }, {
                type = "button",
                name = "Reset HUD position",
                tooltip = "Move the Mandatory Bath Time HUD back beside the other feat meters.",
                width = "full",
                func = function()
                    if HARDCORE.ResetSwimDisciplineHudPosition then
                        HARDCORE.ResetSwimDisciplineHudPosition()
                    end
                end
            }, {
                type = "button",
                name = "Reset bath timer",
                tooltip = "Restart the bath interval and clear current bath progress.",
                width = "full",
                func = function()
                    if HARDCORE.ResetSwimDisciplineTimer then
                        HARDCORE.ResetSwimDisciplineTimer()
                    end
                end
            }}
        }, {
            type = "submenu",
            name = "No Swimming",
            tooltip = "Configure the water danger countdown display.",
            controls = {{
                type = "checkbox",
                name = "Unlock water HUD",
                tooltip = "Allow the No Swimming HUD to be dragged. Lock it again for normal play.",
                width = "full",
                getFunc = function()
                    return GetNoSwimmingSV().hud.unlocked == true
                end,
                setFunc = function(val)
                    GetNoSwimmingSV().hud.unlocked = val and true or false
                    RefreshNoSwimmingOptions()
                end,
                default = false
            }, {
                type = "checkbox",
                name = "Show water label",
                tooltip = "Show the Water label above the danger status.",
                width = "full",
                getFunc = function()
                    return GetNoSwimmingSV().hud.showLabels == true
                end,
                setFunc = function(val)
                    GetNoSwimmingSV().hud.showLabels = val and true or false
                    RefreshNoSwimmingOptions()
                end,
                default = true
            }, {
                type = "button",
                name = "Reset HUD position",
                tooltip = "Move the No Swimming HUD back beside the other feat meters.",
                width = "full",
                func = function()
                    if HARDCORE.ResetNoSwimmingHudPosition then
                        HARDCORE.ResetNoSwimmingHudPosition()
                    end
                end
            }}
        }, {
            type = "submenu",
            name = "Need of Blood",
            tooltip = "Configure the blood demand countdown display.",
            controls = {{
                type = "checkbox",
                name = "Unlock blood HUD",
                tooltip = "Allow the Need of Blood HUD to be dragged. Lock it again for normal play.",
                width = "full",
                getFunc = function()
                    return GetNeedOfBloodSV().hud.unlocked == true
                end,
                setFunc = function(val)
                    GetNeedOfBloodSV().hud.unlocked = val and true or false
                    RefreshNeedOfBloodOptions()
                end,
                default = false
            }, {
                type = "checkbox",
                name = "Show blood label",
                tooltip = "Show the Blood label above the demand status.",
                width = "full",
                getFunc = function()
                    return GetNeedOfBloodSV().hud.showLabels == true
                end,
                setFunc = function(val)
                    GetNeedOfBloodSV().hud.showLabels = val and true or false
                    RefreshNeedOfBloodOptions()
                end,
                default = true
            }, {
                type = "button",
                name = "Reset HUD position",
                tooltip = "Move the Need of Blood HUD back beside the other feat meters.",
                width = "full",
                func = function()
                    if HARDCORE.ResetNeedOfBloodHudPosition then
                        HARDCORE.ResetNeedOfBloodHudPosition()
                    end
                end
            }, {
                type = "button",
                name = "Reset blood timer",
                tooltip = "Restart the ten-minute countdown before the next blood demand.",
                width = "full",
                disabled = function()
                    return HARDCORE.saved and HARDCORE.saved.isActive and not HARDCORE.saved.debugMode
                end,
                func = function()
                    if HARDCORE.ResetNeedOfBloodTimer then
                        HARDCORE.ResetNeedOfBloodTimer()
                    end
                end
            }}
        }, {
            type = "submenu",
            name = "Lockpick Nerves",
            tooltip = "Configure the lockpick panic display.",
            controls = {{
                type = "checkbox",
                name = "Unlock lockpick HUD",
                tooltip = "Allow the Lockpick Nerves HUD to be dragged. Lock it again for normal play.",
                width = "full",
                getFunc = function()
                    return GetLockpickNervesSV().hud.unlocked == true
                end,
                setFunc = function(val)
                    GetLockpickNervesSV().hud.unlocked = val and true or false
                    RefreshLockpickNervesOptions()
                end,
                default = false
            }, {
                type = "checkbox",
                name = "Show lockpick label",
                tooltip = "Show the Lockpick label above the nerves status.",
                width = "full",
                getFunc = function()
                    return GetLockpickNervesSV().hud.showLabels == true
                end,
                setFunc = function(val)
                    GetLockpickNervesSV().hud.showLabels = val and true or false
                    RefreshLockpickNervesOptions()
                end,
                default = true
            }, {
                type = "button",
                name = "Reset HUD position",
                tooltip = "Move the Lockpick Nerves HUD back beside the other feat meters.",
                width = "full",
                func = function()
                    if HARDCORE.ResetLockpickNervesHudPosition then
                        HARDCORE.ResetLockpickNervesHudPosition()
                    end
                end
            }, {
                type = "button",
                name = "Reset lockpick nerves",
                tooltip = "Clear current lockpick mistake strikes.",
                width = "full",
                func = function()
                    if HARDCORE.ResetLockpickNervesStrikes then
                        HARDCORE.ResetLockpickNervesStrikes()
                    end
                end
            }}
        }, {
            type = "submenu",
            name = "Debug",
            tooltip = "Configure testing helpers.",
            controls = debugControls
        }})
    end

    CreateIntroWindow()
    RegisterSlash()

    EVENT_MANAGER:RegisterForEvent("HARDCORE_MainMenuBtn", EVENT_PLAYER_ACTIVATED, HARDCORE_OnPlayerActivatedMainMenu)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Death", EVENT_UNIT_DEATH_STATE_CHANGED, HARDCORE_OnUnitDeathStateChanged)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "_Death", EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Level", EVENT_LEVEL_UPDATE, HARDCORE_OnLevelUpdate)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "_Level", EVENT_LEVEL_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")

    if HARDCORE.saved.isActive and GetUnitLevel("player") >= 50 and not HARDCORE.saved.hasSeenCongrats then
        zo_callLater(function()
            HARDCORE.ShowCongratulationsWindow()
        end, 2000)
    end

    if not (HARDCORE.saved.hasSeenIntro or HARDCORE.saved.isActive) then
        zo_callLater(function()
            HARDCORE.ToggleIntro(false)
        end, 600)
    end

end

local function PlayCongratulationsWindowSounds()
    PlaySound(SOUNDS.BOOK_COLLECTION_COMPLETED)
    zo_callLater(function() PlaySound(SOUNDS.LEVEL_UP_REWARD_CLAIM) end, 450)
    zo_callLater(function() PlaySound(SOUNDS.OBJECTIVE_COMPLETED) end, 900)
end

local function RefreshCongratulationsWindowSummary(win)
    if not win then
        return
    end

    local completedFeats = GetCompletedFeatTitles()
    local completedCount = #completedFeats

    if win.lowestHealthValue then
        win.lowestHealthValue:SetText(string.format("%d%%", GetChallengeLowestHealthPct()))
    end
    if win.featsCompletedValue then
        win.featsCompletedValue:SetText(tostring(completedCount))
    end
    if win.playedTimeValue then
        win.playedTimeValue:SetText(GetCompactPlayedTimeText())
    end
    if win.playedTimeFull then
        win.playedTimeFull:SetText("Alive: " .. GetPlayedTimeText())
    end
    if win.featsCompletedList then
        win.featsCompletedList:SetText(FormatCompletedFeatsText(completedFeats))
        win.featsCompletedList:SetColor((completedCount > 0 and COLOR.gray or COLOR.dim):UnpackRGBA())
    end
end

local function ConfigureCongratulationsWindow(win, previewMode)
    if not (win and win.actionButton and win.closeButton) then
        return
    end

    local continueButton = win.continueButton

    if previewMode then
        win.actionButton:SetText("Close Preview")
        win.actionButton:ClearAnchors()
        win.actionButton:SetAnchor(BOTTOM, win, BOTTOM, 0, -35)
        win.actionButton:SetHandler("OnClicked", function()
            win:SetHidden(true)
            SetGameCameraUIMode(false)
        end)
        if continueButton then
            continueButton:SetHidden(true)
            continueButton:SetHandler("OnClicked", nil)
        end
        win.closeButton:SetHandler("OnClicked", function()
            win:SetHidden(true)
            SetGameCameraUIMode(false)
        end)
        return
    end

    win.actionButton:ClearAnchors()
    win.actionButton:SetAnchor(BOTTOM, win, BOTTOM, -145, -35)
    win.actionButton:SetText("End Challenge")
    win.actionButton:SetHandler("OnClicked", function()
        HARDCORE.saved.hasSeenCongrats = true
        HARDCORE.SurrenderChallenge()
        HARDCORE.RestoreHUDSettings()
        win:SetHidden(true)
        SetGameCameraUIMode(false)
        HARDCORE.ShowAlert(UI_ALERT_CATEGORY_ALERT, SOUNDS.QUEST_ACCEPTED, "Hardcore Challenge Completed!")
        zo_callLater(function() ReloadUI() end, 500)
    end)

    if continueButton then
        continueButton:SetHidden(false)
        continueButton:SetText("Continue Challenge")
        continueButton:SetHandler("OnClicked", function()
            HARDCORE.saved.hasSeenCongrats = true
            win:SetHidden(true)
            SetGameCameraUIMode(false)
            if HARDCORE.UpdateActionButton then
                HARDCORE.UpdateActionButton()
            end
        end)
    end

    win.closeButton:SetHandler("OnClicked", function()
        win:SetHidden(true)
        SetGameCameraUIMode(false)
    end)
end

function HARDCORE.ShowCongratulationsWindow(previewMode)
    if HARDCORE.congratsWindow then
        RefreshCongratulationsWindowSummary(HARDCORE.congratsWindow)
        ConfigureCongratulationsWindow(HARDCORE.congratsWindow, previewMode == true)
        HARDCORE.congratsWindow:SetHidden(false)
        SetGameCameraUIMode(true)
        PlayCongratulationsWindowSounds()
        return
    end

    local wm = WINDOW_MANAGER
    local win = wm:CreateTopLevelWindow("HARDCORE_CongratsWindow")
    HARDCORE.congratsWindow = win
    win:SetMovable(false)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetResizeHandleSize(0)
    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, -40)
    win:SetDimensions(780, 590)

    local frame = wm:CreateControl(nil, win, CT_BACKDROP)
    frame:SetAnchorFill()
    frame:SetCenterColor(0, 0, 0, 0.88)
    frame:SetEdgeTexture("/esoui/art/chatwindow/chat_bg_edge.dds", 32, 4, 4)
    frame:SetEdgeColor(0.9, 0.85, 0.65, 1)

    local inner = wm:CreateControl("HARDCORE_CongratsInner", win, CT_CONTROL)
    inner:SetAnchor(TOPLEFT, win, TOPLEFT, 8, 8)
    inner:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -8, -8)

    local bg = wm:CreateControl("HARDCORE_CongratsInnerBG", inner, CT_TEXTURE)
    bg:SetAnchorFill(inner)
    bg:SetTexture("/esoui/art/loadingscreens/loadscreen_pantherfangchapel_01.dds")
    bg:SetTextureCoords(0, 1, 0, 1)
    bg:SetDrawTier(DT_LOW)
    bg:SetAlpha(0.60)
    bg:SetBlendMode(TEX_BLEND_MODE_ALPHA)

    local wash = wm:CreateControl("HARDCORE_CongratsInnerWash", inner, CT_BACKDROP)
    wash:SetAnchorFill(inner)
    wash:SetCenterColor(0, 0, 0, 0.40)
    wash:SetEdgeColor(0, 0, 0, 0)
    wash:SetDrawTier(DT_LOW)
    wash:SetDrawLayer(DL_BACKGROUND)
    wash:SetDrawLevel(1)

    local subtleEdge = wm:CreateControl("HARDCORE_CongratsInnerEdge", inner, CT_BACKDROP)
    subtleEdge:SetAnchorFill(inner)
    subtleEdge:SetCenterColor(0, 0, 0, 0)
    subtleEdge:SetEdgeTexture("/esoui/art/miscellaneous/dark_edgeframe_8_thin.dds", 32, 4, 4)
    subtleEdge:SetEdgeColor(0, 0, 0, 0.25)
    subtleEdge:SetDrawLayer(DL_OVERLAY)
    subtleEdge:SetDrawLevel(1)

    local function Corner(name, tex, anchorPoint, xOff, yOff, w, h)
        local t = wm:CreateControl(name, inner, CT_TEXTURE)
        t:SetTexture(tex)
        t:SetDimensions(w or 16, h or 16)
        t:SetBlendMode(TEX_BLEND_MODE_ALPHA)
        t:SetAlpha(0.9)
        t:SetDrawLayer(DL_OVERLAY)
        t:SetDrawLevel(5)
        t:SetAnchor(anchorPoint, inner, anchorPoint, xOff or 0, yOff or 0)
        return t
    end

    Corner("HARDCORE_CongratsCornerTL", "/esoui/art/reticle/border_topleft.dds", TOPLEFT, -1, -1, 16, 16)
    Corner("HARDCORE_CongratsCornerTR", "/esoui/art/reticle/border_topright.dds", TOPRIGHT, 1, -1, 16, 16)
    Corner("HARDCORE_CongratsCornerBL", "/esoui/art/reticle/border_bottomleft.dds", BOTTOMLEFT, -1, 1, 16, 16)
    Corner("HARDCORE_CongratsCornerBR", "/esoui/art/reticle/border_bottomright.dds", BOTTOMRIGHT, 1, 1, 16, 16)

    local title = wm:CreateControl(nil, inner, CT_LABEL)
    title:SetAnchor(TOP, inner, TOP, 0, 40)
    title:SetFont("$(BOLD_FONT)|42|soft-shadow-thick")
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    title:SetText("CONGRATULATIONS!")
    title:SetColor(COLOR.gold:UnpackRGBA())

    local divider = wm:CreateControl(nil, inner, CT_TEXTURE)
    divider:SetAnchor(TOP, title, BOTTOM, 0, 12)
    divider:SetDimensions(520, 8)
    divider:SetTexture("/esoui/art/miscellaneous/horizontaldivider.dds")
    divider:SetAlpha(0.55)

    local subTitle = wm:CreateControl(nil, inner, CT_LABEL)
    subTitle:SetAnchor(TOP, divider, BOTTOM, 0, 18)
    subTitle:SetFont("$(MEDIUM_FONT)|24|soft-shadow-thin")
    subTitle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    subTitle:SetColor(COLOR.white:UnpackRGBA())
    subTitle:SetText("You have reached Level 50\nand completed the Hardcore Challenge!")

    local summary = wm:CreateControl("HARDCORE_CongratsSummary", inner, CT_BACKDROP)
    summary:SetAnchor(TOP, subTitle, BOTTOM, 0, 24)
    summary:SetDimensions(640, 210)
    summary:SetCenterColor(0.02, 0.015, 0.01, 0.62)
    summary:SetEdgeTexture("/esoui/art/chatwindow/chat_bg_edge.dds", 32, 4, 4)
    summary:SetEdgeColor(0.9, 0.72, 0.34, 0.38)

    local summaryTitle = wm:CreateControl(nil, summary, CT_LABEL)
    summaryTitle:SetAnchor(TOP, summary, TOP, 0, 12)
    summaryTitle:SetDimensions(600, 24)
    summaryTitle:SetFont("$(BOLD_FONT)|18|soft-shadow-thick")
    summaryTitle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    summaryTitle:SetColor(COLOR.gold:UnpackRGBA())
    summaryTitle:SetText("Run Summary")

    local lowestHealthLabel = wm:CreateControl(nil, summary, CT_LABEL)
    lowestHealthLabel:SetAnchor(TOPLEFT, summary, TOPLEFT, 32, 50)
    lowestHealthLabel:SetDimensions(170, 22)
    lowestHealthLabel:SetFont("$(MEDIUM_FONT)|15|soft-shadow-thin")
    lowestHealthLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    lowestHealthLabel:SetColor(COLOR.dim:UnpackRGBA())
    lowestHealthLabel:SetText("Lowest Health")

    local lowestHealthValue = wm:CreateControl(nil, summary, CT_LABEL)
    win.lowestHealthValue = lowestHealthValue
    lowestHealthValue:SetAnchor(TOP, lowestHealthLabel, BOTTOM, 0, -2)
    lowestHealthValue:SetDimensions(170, 38)
    lowestHealthValue:SetFont("$(BOLD_FONT)|32|soft-shadow-thick")
    lowestHealthValue:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    lowestHealthValue:SetColor(COLOR.white:UnpackRGBA())

    local playedTimeLabel = wm:CreateControl(nil, summary, CT_LABEL)
    playedTimeLabel:SetAnchor(TOP, summary, TOP, 0, 50)
    playedTimeLabel:SetDimensions(190, 22)
    playedTimeLabel:SetFont("$(MEDIUM_FONT)|15|soft-shadow-thin")
    playedTimeLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    playedTimeLabel:SetColor(COLOR.dim:UnpackRGBA())
    playedTimeLabel:SetText("Alive")

    local playedTimeValue = wm:CreateControl(nil, summary, CT_LABEL)
    win.playedTimeValue = playedTimeValue
    playedTimeValue:SetAnchor(TOP, playedTimeLabel, BOTTOM, 0, 0)
    playedTimeValue:SetDimensions(190, 32)
    playedTimeValue:SetFont("$(BOLD_FONT)|24|soft-shadow-thick")
    playedTimeValue:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    playedTimeValue:SetColor(COLOR.white:UnpackRGBA())

    local featsCompletedLabel = wm:CreateControl(nil, summary, CT_LABEL)
    featsCompletedLabel:SetAnchor(TOPRIGHT, summary, TOPRIGHT, -32, 50)
    featsCompletedLabel:SetDimensions(170, 22)
    featsCompletedLabel:SetFont("$(MEDIUM_FONT)|15|soft-shadow-thin")
    featsCompletedLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    featsCompletedLabel:SetColor(COLOR.dim:UnpackRGBA())
    featsCompletedLabel:SetText("Feats Completed")

    local featsCompletedValue = wm:CreateControl(nil, summary, CT_LABEL)
    win.featsCompletedValue = featsCompletedValue
    featsCompletedValue:SetAnchor(TOP, featsCompletedLabel, BOTTOM, 0, -2)
    featsCompletedValue:SetDimensions(170, 38)
    featsCompletedValue:SetFont("$(BOLD_FONT)|32|soft-shadow-thick")
    featsCompletedValue:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    featsCompletedValue:SetColor(COLOR.white:UnpackRGBA())

    local featList = wm:CreateControl(nil, summary, CT_LABEL)
    win.featsCompletedList = featList
    featList:SetAnchor(TOP, summary, TOP, 0, 118)
    featList:SetDimensions(580, 54)
    featList:SetFont("$(MEDIUM_FONT)|14|soft-shadow-thin")
    featList:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    local playedTimeFull = wm:CreateControl(nil, summary, CT_LABEL)
    win.playedTimeFull = playedTimeFull
    playedTimeFull:SetAnchor(TOP, summary, TOP, 0, 174)
    playedTimeFull:SetDimensions(580, 24)
    playedTimeFull:SetFont("$(MEDIUM_FONT)|14|soft-shadow-thin")
    playedTimeFull:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    playedTimeFull:SetColor(COLOR.dim:UnpackRGBA())

    local desc = wm:CreateControl(nil, inner, CT_LABEL)
    desc:SetAnchor(TOP, summary, BOTTOM, 0, 12)
    desc:SetFont("$(MEDIUM_FONT)|20")
    desc:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    desc:SetColor(COLOR.gray:UnpackRGBA())
    desc:SetText("Your trial is complete. Keep the rules active,\nor end the challenge and return to normal.")

    local btn = wm:CreateControlFromVirtual("HARDCORE_CongratsActionButton", win, "ZO_DefaultButton")
    win.actionButton = btn
    btn:SetAnchor(BOTTOM, win, BOTTOM, 0, -35)
    btn:SetDimensions(280, 44)

    local continueButton = wm:CreateControlFromVirtual("HARDCORE_CongratsContinueButton", win, "ZO_DefaultButton")
    win.continueButton = continueButton
    continueButton:SetAnchor(BOTTOM, win, BOTTOM, 145, -35)
    continueButton:SetDimensions(260, 44)
    continueButton:SetHidden(true)

    local close = wm:CreateControlFromVirtual("HARDCORE_CongratsClose", win, "ZO_CloseButton")
    win.closeButton = close
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -18, 14)

    RefreshCongratulationsWindowSummary(win)
    ConfigureCongratulationsWindow(win, previewMode == true)
    SetGameCameraUIMode(true)
    PlayCongratulationsWindowSounds()
end

local function ConfigureDeathWindow(win, previewMode)
    if not (win and win.actionButton and win.closeButton) then
        return
    end

    if previewMode then
        win.actionButton:SetText("Close Preview")
        win.actionButton:SetHandler("OnClicked", function()
            win:SetHidden(true)
            SetGameCameraUIMode(false)
        end)
        win.closeButton:SetHandler("OnClicked", function()
            win:SetHidden(true)
            SetGameCameraUIMode(false)
        end)
        return
    end

    win.actionButton:SetText("Accept Fate")
    win.actionButton:SetHandler("OnClicked", function()
        win:SetHidden(true)
        SetGameCameraUIMode(false)
        HARDCORE.ShowAlert(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK, "Hardcore Challenge Failed.")
        zo_callLater(function() ReloadUI() end, 500)
    end)
    win.closeButton:SetHandler("OnClicked", function()
        win:SetHidden(true)
        SetGameCameraUIMode(false)
    end)
end

function HARDCORE.ShowDeathWindow(previewMode)
    if HARDCORE.deathWindow then
        ConfigureDeathWindow(HARDCORE.deathWindow, previewMode == true)
        HARDCORE.deathWindow:SetHidden(false)
        SetGameCameraUIMode(true)
        PlaySound(SOUNDS.ENDLESS_DUNGEON_RUN_COMPLETE)
        return
    end

    local wm = WINDOW_MANAGER
    local win = wm:CreateTopLevelWindow("HARDCORE_DeathWindow")
    HARDCORE.deathWindow = win
    win:SetMovable(false)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetResizeHandleSize(0)
    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, -40)
    win:SetDimensions(750, 480)

    local frame = wm:CreateControl(nil, win, CT_BACKDROP)
    frame:SetAnchorFill()
    frame:SetCenterColor(0.05, 0, 0, 0.88)
    frame:SetEdgeTexture("/esoui/art/chatwindow/chat_bg_edge.dds", 32, 4, 4)
    frame:SetEdgeColor(0.8, 0.15, 0.15, 1)

    local inner = wm:CreateControl("HARDCORE_DeathInner", win, CT_CONTROL)
    inner:SetAnchor(TOPLEFT, win, TOPLEFT, 8, 8)
    inner:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -8, -8)

    local bg = wm:CreateControl("HARDCORE_DeathInnerBG", inner, CT_TEXTURE)
    bg:SetAnchorFill(inner)
    bg:SetTexture("/esoui/art/loadingscreens/loadscreen_circus_of_the_cheerful_slaughter_01.dds")
    bg:SetTextureCoords(0, 1, 0, 1)
    bg:SetDrawTier(DT_LOW)
    bg:SetAlpha(0.60)
    bg:SetColor(0.8, 0.2, 0.2, 1)
    bg:SetBlendMode(TEX_BLEND_MODE_ALPHA)

    local wash = wm:CreateControl("HARDCORE_DeathInnerWash", inner, CT_BACKDROP)
    wash:SetAnchorFill(inner)
    wash:SetCenterColor(0.2, 0, 0, 0.50)
    wash:SetEdgeColor(0, 0, 0, 0)
    wash:SetDrawTier(DT_LOW)
    wash:SetDrawLayer(DL_BACKGROUND)
    wash:SetDrawLevel(1)

    local subtleEdge = wm:CreateControl("HARDCORE_DeathInnerEdge", inner, CT_BACKDROP)
    subtleEdge:SetAnchorFill(inner)
    subtleEdge:SetCenterColor(0, 0, 0, 0)
    subtleEdge:SetEdgeTexture("/esoui/art/miscellaneous/dark_edgeframe_8_thin.dds", 32, 4, 4)
    subtleEdge:SetEdgeColor(0.8, 0.15, 0.15, 0.35)
    subtleEdge:SetDrawLayer(DL_OVERLAY)
    subtleEdge:SetDrawLevel(1)

    local function Corner(name, tex, anchorPoint, xOff, yOff, w, h)
        local t = wm:CreateControl(name, inner, CT_TEXTURE)
        t:SetTexture(tex)
        t:SetDimensions(w or 16, h or 16)
        t:SetBlendMode(TEX_BLEND_MODE_ALPHA)
        t:SetAlpha(0.9)
        t:SetDrawLayer(DL_OVERLAY)
        t:SetDrawLevel(5)
        t:SetAnchor(anchorPoint, inner, anchorPoint, xOff or 0, yOff or 0)
        return t
    end

    Corner("HARDCORE_DeathCornerTL", "/esoui/art/reticle/border_topleft.dds", TOPLEFT, -1, -1, 16, 16)
    Corner("HARDCORE_DeathCornerTR", "/esoui/art/reticle/border_topright.dds", TOPRIGHT, 1, -1, 16, 16)
    Corner("HARDCORE_DeathCornerBL", "/esoui/art/reticle/border_bottomleft.dds", BOTTOMLEFT, -1, 1, 16, 16)
    Corner("HARDCORE_DeathCornerBR", "/esoui/art/reticle/border_bottomright.dds", BOTTOMRIGHT, 1, 1, 16, 16)

    local title = wm:CreateControl(nil, inner, CT_LABEL)
    title:SetAnchor(TOP, inner, TOP, 0, 40)
    title:SetFont("$(BOLD_FONT)|42|soft-shadow-thick")
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    title:SetText("YOU DIED")
    title:SetColor(COLOR.red:UnpackRGBA())

    local divider = wm:CreateControl(nil, inner, CT_TEXTURE)
    divider:SetAnchor(TOP, title, BOTTOM, 0, 12)
    divider:SetDimensions(520, 8)
    divider:SetTexture("/esoui/art/miscellaneous/horizontaldivider.dds")
    divider:SetAlpha(0.55)
    divider:SetColor(COLOR.red:UnpackRGBA())

    local subTitle = wm:CreateControl(nil, inner, CT_LABEL)
    subTitle:SetAnchor(TOP, divider, BOTTOM, 0, 20)
    subTitle:SetFont("$(MEDIUM_FONT)|24|soft-shadow-thin")
    subTitle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    subTitle:SetColor(COLOR.white:UnpackRGBA())
    subTitle:SetText("Your Hardcore journey has met a tragic end.")

    local desc = wm:CreateControl(nil, inner, CT_LABEL)
    desc:SetAnchor(TOP, subTitle, BOTTOM, 0, 45)
    desc:SetFont("$(MEDIUM_FONT)|20")
    desc:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    desc:SetColor(COLOR.gray:UnpackRGBA())
    desc:SetText("\nYou may continue on this character as a normal adventurer.")

    local btn = wm:CreateControlFromVirtual("HARDCORE_DeathActionButton", win, "ZO_DefaultButton")
    win.actionButton = btn
    btn:SetAnchor(BOTTOM, win, BOTTOM, 0, -35)
    btn:SetDimensions(280, 44)

    local close = wm:CreateControlFromVirtual("HARDCORE_DeathClose", win, "ZO_CloseButton")
    win.closeButton = close
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -18, 14)

    ConfigureDeathWindow(win, previewMode == true)
    SetGameCameraUIMode(true)
    PlaySound(SOUNDS.ENDLESS_DUNGEON_RUN_COMPLETE)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
