--[[
Author: Ayantir
Filename: SuperStar.lua
Contributors: Armodeniz, SigoDest, senorblackbean, Ego_666, Lykeion
Version: 8.0.0
--]] -- Init SuperStar variables
SuperStar = {}
SuperStarSkills = ZO_Object:Subclass()
local ADDON_NAME = "SuperStar"

local TAG_ATTRIBUTES = "#"
local TAG_SKILLS = "@"
local TAG_CP = "%"

local SUPERSTAR_SHARE = "sss"
local SUPERSTAR_SHARE_NAME = "SuperStar"
local SUPERSTAR_PRINT_QUEUE = "superstar_print_queue"
-- Revisions
local REVISION_ATTRIBUTES = "1"
local REVISION_SKILLS_MORROWIND = "2"
local REVISION_SKILLS_SUMMERSET = "3"
local REVISION_SKILLS_GREYMOOR = "4"
local REVISION_SKILLS_BLACKWOOD = "5"
local REVISION_SKILLS_NECROM = "6"
local REVISION_SKILLS_GOLDROAD = "7"
local REVISION_SKILLS = REVISION_SKILLS_GOLDROAD

local REVISION_CP = "2" -- changed to "2" after CP2.0 (100034)

-- No mode for attrs
local MODE_SKILLS = "1" -- changed to 1 at v5
local MODE_CP = "2"
local CURRENT_VALID_SKILL_TAG = TAG_SKILLS .. REVISION_SKILLS .. MODE_SKILLS

local skillsDataForRespec
local cpDataForRespec

local showingCharInMain = true
local summaryKeybindStripDescriptor = {}

local xmlIncludeAttributes = true
local xmlIncludeSkills = true
local xmlInclChampionSkills = true

local SKILL_ABILITY_DATA = 1
local SKILL_HEADER_DATA = 2

local ABILITY_TYPE_ULTIMATE = 0
local ABILITY_TYPE_ACTIVE = 1
local ABILITY_TYPE_PASSIVE = 2
local ABILITY_TYPE_CRAFTED = 3

local CLASS_DRAGONKNIGHT = 1
local CLASS_SORCERER = 2
local CLASS_NIGHTBLADE = 3
local CLASS_WARDEN = 4
local CLASS_NECROMANCER = 5
local CLASS_TEMPLAR = 6
-- Lykeion@v5.0.5
local CLASS_ARCANIST = 117

local ABILITY_LEVEL_NONMORPHED = 0
local ABILITY_LEVEL_UPPERMORPH = 1
local ABILITY_LEVEL_LOWERMORPH = 2

local ABILITY_TYPE_ULTIMATE_RANGE = 4
local ABILITY_TYPE_ACTIVE_RANGE = 8
local ABILITY_TYPE_CRAFTED_RANGE = 12
local ABILITY_TYPE_PASSIVE_RANGE = 16

local SKILLTYPE_THRESHOLD = 42

local CHAMPION_DISCIPLINE_DIVISION = 200

local ATTR_MAX_SPENDABLE_POINTS = 64
local SP_MAX_SPENDABLE_POINTS = 561 -- in 6.0.0 U42
local CP_MAX_SPENDABLE_POINTS = 120 -- Per champion skill

local MAX_PLAYABLE_RACES = 10

local SKILLTYPES_IN_SKILLBUILDER = 8

local FOOD_BUFF_NONE = 0
local FOOD_BUFF_MAX_HEALTH = 1
local FOOD_BUFF_MAX_MAGICKA = 2
local FOOD_BUFF_MAX_STAMINA = 4
local FOOD_BUFF_REGEN_HEALTH = 8
local FOOD_BUFF_REGEN_MAGICKA = 16
local FOOD_BUFF_REGEN_STAMINA = 32
local FOOD_BUFF_SPECIAL_VAMPIRE = 64

local FOOD_TYPE_I18N = {
    [FOOD_BUFF_MAX_MAGICKA] = SI_DERIVEDSTATS4,
    [FOOD_BUFF_REGEN_MAGICKA] = SI_DERIVEDSTATS5,
    [FOOD_BUFF_MAX_HEALTH] = SI_DERIVEDSTATS7,
    [FOOD_BUFF_REGEN_HEALTH] = SI_DERIVEDSTATS8,
    [FOOD_BUFF_MAX_STAMINA] = SI_DERIVEDSTATS29,
    [FOOD_BUFF_REGEN_STAMINA] = SI_DERIVEDSTATS30,
}

local FOOD_BUFF_MAX_HEALTH_MAGICKA = FOOD_BUFF_MAX_HEALTH + FOOD_BUFF_MAX_MAGICKA
local FOOD_BUFF_MAX_HEALTH_STAMINA = FOOD_BUFF_MAX_HEALTH + FOOD_BUFF_MAX_STAMINA
local FOOD_BUFF_MAX_MAGICKA_STAMINA = FOOD_BUFF_MAX_MAGICKA + FOOD_BUFF_MAX_STAMINA
local FOOD_BUFF_REGEN_HEALTH_MAGICKA = FOOD_BUFF_REGEN_HEALTH + FOOD_BUFF_REGEN_MAGICKA
local FOOD_BUFF_REGEN_HEALTH_STAMINA = FOOD_BUFF_REGEN_HEALTH + FOOD_BUFF_REGEN_STAMINA
local FOOD_BUFF_REGEN_MAGICKA_STAMINA = FOOD_BUFF_REGEN_MAGICKA + FOOD_BUFF_REGEN_STAMINA
local FOOD_BUFF_MAX_ALL = FOOD_BUFF_MAX_HEALTH + FOOD_BUFF_MAX_MAGICKA + FOOD_BUFF_MAX_STAMINA
local FOOD_BUFF_REGEN_ALL = FOOD_BUFF_REGEN_HEALTH + FOOD_BUFF_REGEN_MAGICKA + FOOD_BUFF_REGEN_STAMINA
local FOOD_BUFF_MAX_HEALTH_REGEN_HEALTH = FOOD_BUFF_MAX_HEALTH + FOOD_BUFF_REGEN_HEALTH
local FOOD_BUFF_MAX_HEALTH_REGEN_MAGICKA = FOOD_BUFF_MAX_HEALTH + FOOD_BUFF_REGEN_MAGICKA
local FOOD_BUFF_MAX_HEALTH_REGEN_STAMINA = FOOD_BUFF_MAX_HEALTH + FOOD_BUFF_REGEN_STAMINA
local FOOD_BUFF_MAX_HEALTH_REGEN_ALL = FOOD_BUFF_MAX_HEALTH + FOOD_BUFF_REGEN_HEALTH + FOOD_BUFF_REGEN_MAGICKA +
                                           FOOD_BUFF_REGEN_STAMINA
local FOOD_BUFF_MAX_MAGICKA_REGEN_STAMINA = FOOD_BUFF_MAX_MAGICKA + FOOD_BUFF_REGEN_STAMINA
local FOOD_BUFF_MAX_MAGICKA_REGEN_HEALTH = FOOD_BUFF_MAX_MAGICKA + FOOD_BUFF_REGEN_HEALTH
local FOOD_BUFF_MAX_STAMINA_REGEN_STAMINA = FOOD_BUFF_MAX_STAMINA + FOOD_BUFF_REGEN_STAMINA
local FOOD_BUFF_MAX_STAMINA_REGEN_MAGICKA = FOOD_BUFF_MAX_STAMINA + FOOD_BUFF_REGEN_MAGICKA
local FOOD_BUFF_MAX_MAGICKA_REGEN_MAGICKA = FOOD_BUFF_MAX_MAGICKA + FOOD_BUFF_REGEN_MAGICKA
local FOOD_BUFF_MAX_HEALTH_REGEN_STAMINA_MAGICKA = FOOD_BUFF_MAX_HEALTH + FOOD_BUFF_REGEN_STAMINA +
                                                       FOOD_BUFF_REGEN_MAGICKA
local FOOD_BUFF_MAX_HEALTH_STAMINA_REGEN_STAMINA = FOOD_BUFF_MAX_HEALTH + FOOD_BUFF_MAX_STAMINA +
                                                       FOOD_BUFF_REGEN_STAMINA
local FOOD_BUFF_MAX_HEALTH_MAGICKA_REGEN_MAGICKA = FOOD_BUFF_MAX_HEALTH + FOOD_BUFF_MAX_MAGICKA +
                                                       FOOD_BUFF_REGEN_MAGICKA
local FOOD_BUFF_MAX_HEALTH_MAGICKA_REGEN_HEALTH_MAGICKA = FOOD_BUFF_MAX_HEALTH + FOOD_BUFF_MAX_MAGICKA +
                                                               FOOD_BUFF_REGEN_HEALTH + FOOD_BUFF_REGEN_MAGICKA
local FOOD_BUFF_MAX_HEALTH_STAMINA_REGEN_HEALTH_STAMINA = FOOD_BUFF_MAX_HEALTH + FOOD_BUFF_MAX_STAMINA +
                                                               FOOD_BUFF_REGEN_HEALTH + FOOD_BUFF_REGEN_STAMINA
local FOOD_BUFF_MAX_HEALTH_REGEN_HEALTH_MAGICKA_STAMINA = FOOD_BUFF_MAX_HEALTH + FOOD_BUFF_REGEN_HEALTH +
                                                               FOOD_BUFF_REGEN_MAGICKA + FOOD_BUFF_REGEN_STAMINA
local FOOD_BUFF_MAX_HEALTH_MAGICKA_SPECIAL_VAMPIRE = FOOD_BUFF_MAX_HEALTH + FOOD_BUFF_MAX_MAGICKA +
                                                         FOOD_BUFF_SPECIAL_VAMPIRE

local SUPERSTAR_GENERIC_NA = "N/A"
-- previously in sharedskills.lua -- v5: need to change
local ZO_SKILLS_MORPH_STATE = 1
local ZO_SKILLS_PURCHASE_STATE = 2
local ZO_SKILLS_REFUND_STATE = 3
function ZO_Skills_SetAlertButtonTextures(control, styleTable)
    if control:GetType() == CT_TEXTURE then
        control:AddIcon(styleTable.normal)
    elseif control:GetType() == CT_BUTTON then
        control:SetNormalTexture(styleTable.normal)
        control:SetPressedTexture(styleTable.mouseDown)
        control:SetMouseOverTexture(styleTable.mouseover)
    end
end

-- Lykeion@v6.0.0
local SIDEBAR_INDEX_HISTORY = 0
local SIDEBAR_INDEX_FAVORITE = 1
local CACHED_SIDEBAR_INDEX = SIDEBAR_INDEX_HISTORY

local SIDEBAR_SKILL_MAX = 8
local SIDEBAR_FAV_PAGE = 1

local renderingSlot = nil
local allowToShowScribingResult = false
local scribingXmlGroup = nil
local scribingData = {
    [SCRIBING_SLOT_NONE] = nil,
    [SCRIBING_SLOT_PRIMARY] = nil,
    [SCRIBING_SLOT_SECONDARY] = nil,
    [SCRIBING_SLOT_TERTIARY] = nil
}
local craftedAbilityDict = {}
local cachedChatboxInfo = {}
local pickedHistory = {}
local pickedFavorites = {}
local scribingQueue = {}
local scribingQueueRemove = nil
local scribingQueueNest = nil

local mundusBoons = {
    [13940] = 1, -- Boon: The Warrior
    [13943] = 2, -- Boon: The Mage
    [13974] = 3, -- Boon: The Serpent
    [13975] = 4, -- Boon: The Thief
    [13976] = 5, -- Boon: The Lady
    [13977] = 6, -- Boon: The Steed
    [13978] = 7, -- Boon: The Lord
    [13979] = 8, -- Boon: The Apprentice
    [13980] = 9, -- Boon: The Ritual
    [13981] = 10, -- Boon: The Lover
    [13982] = 11, -- Boon: The Atronach
    [13984] = 12, -- Boon: The Shadow
    [13985] = 13 -- Boon: The Tower
}

local VampWW = {
    [35658] = 5, -- Lycantropy
    [135397] = 1, -- Vampirism: Stage 1
    [135399] = 2, -- Vampirism: Stage 2
    [135400] = 3, -- Vampirism: Stage 3
    [135402] = 4 -- Vampirism: Stage 4
}

local defaults = {
    favoritesList = {},
    historyScribed = {},
    favoriteScribed = {},
    latestMajorUpdateVersion = nil
}

local LMM = LibMainMenu2
local LSF = LibSkillsFactory

-- Blk: Define SuperStar Windows ======================================================
local MENU_CATEGORY_SUPERSTAR
local SUPERSTAR_SKILLS_WINDOW
local SUPERSTAR_SKILLS_PRESELECTORWINDOW
local SUPERSTAR_SKILLS_BUILDERWINDOW
local SUPERSTAR_SKILLS_SCENE

local SUPERSTAR_FAVORITES_WINDOW
local SUPERSTAR_IMPORT_WINDOW
-- Favorite Window var
local favoritesManager
local isFavoriteShown = false
local isFavoriteLocked = false
local isFavoriteHaveSP = false
local isFavoriteHaveCP = false
local isFavoriteValid = false
local isFavoriteOutdated = false
local isImportedBuildValid = false
local virtualFavorite = "$" .. GetUnitName("player")
-- Repec Window var
local RESPEC_MODE_SP = 1
local RESPEC_MODE_CP = 2

local db -- saved datas

-- Blk: Utility ================================================================
local function Base62(value)
    local r = false
    local state = type(value)
    if value == nil then
        d("[superstar] value is nil")
        return
    end
    local u = string.sub(value, 1, 1) == "-"
    if state == "number" then
        local k = math.floor(math.abs(value)) -- no decimals, only integers, no negatives
        if k > 9 then
            local m
            r = ""
            while k > 0 do
                m = k % 62
                k = (k - m) / 62
                if m >= 36 then
                    m = m + 61
                elseif m >= 10 then
                    m = m + 55
                else
                    m = m + 48
                end
                r = string.char(m) .. r
            end
        else
            r = tostring(k)
        end
        if value < 0 then
            r = "-" .. r
        end
    elseif state == "string" then
        if u then
            value = value:sub(value, 1, -2)
        end
        if value:match("^%w+$") then
            local n = #value
            local k = 1
            local c
            r = 0
            for i = n, 1, -1 do
                c = value:byte(i, i)
                if c >= 48 and c <= 57 then
                    c = c - 48
                elseif c >= 65 and c <= 90 then
                    c = c - 55
                elseif c >= 97 and c <= 122 then
                    c = c - 61
                else
                    r = nil
                    break
                end
                r = r + c * k
                k = k * 62
            end
            if u then
                r = 0 - r
            end
        end
    end
    return r
end

-- Blk: Skill Builder ==========================================================
local function SetAbilityButtonTextures(button, passive)
    if passive then
        button:SetNormalTexture("EsoUI/Art/ActionBar/passiveAbilityFrame_round_up.dds")
        button:SetPressedTexture("EsoUI/Art/ActionBar/passiveAbilityFrame_round_up.dds")
        button:SetMouseOverTexture(nil)
        button:SetDisabledTexture("EsoUI/Art/ActionBar/passiveAbilityFrame_round_up.dds")
    else
        button:SetNormalTexture("EsoUI/Art/ActionBar/abilityFrame64_up.dds")
        button:SetPressedTexture("EsoUI/Art/ActionBar/abilityFrame64_down.dds")
        button:SetMouseOverTexture("EsoUI/Art/ActionBar/actionBar_mouseOver.dds")
        button:SetDisabledTexture("EsoUI/Art/ActionBar/abilityFrame64_up.dds")
    end
end

-- Lykeion@6.0.0
local function GetCraftedAbilityDisplayIcon(craftedSkillId)
    if craftedSkillId == 4 then
        return "/esoui/art/icons/ability_grimoire_2handed.dds"
    elseif craftedSkillId == 3 then
        return "/esoui/art/icons/ability_grimoire_1handed.dds"
    elseif craftedSkillId == 7 then
        return "/esoui/art/icons/ability_grimoire_dualwield.dds"
    elseif craftedSkillId == 1 then
        return "/esoui/art/icons/ability_grimoire_bow.dds"
    elseif craftedSkillId == 5 then
        return "/esoui/art/icons/ability_grimoire_staffdestro.dds"
    elseif craftedSkillId == 6 then
        return "/esoui/art/icons/ability_grimoire_staffresto.dds"
    elseif craftedSkillId == 2 then
        return "/esoui/art/icons/ability_grimoire_soulmagic1.dds"
    elseif craftedSkillId == 8 then
        return "/esoui/art/icons/ability_grimoire_soulmagic2.dds"
    elseif craftedSkillId == 10 then
        return "/esoui/art/icons/ability_grimoire_fightersguild.dds"
    elseif craftedSkillId == 9 then
        return "/esoui/art/icons/ability_grimoire_magesguild.dds"
    elseif craftedSkillId == 11 then
        return "/esoui/art/icons/ability_grimoire_assault.dds"
    else
        return "/esoui/art/icons/ability_grimoire_support.dds"
    end
end

local function GetCraftedAbilitySkilllineName(craftedSkillId)
    if craftedSkillId == 4 then
        return GetSkillLineNameById(30)
    elseif craftedSkillId == 3 then
        return GetSkillLineNameById(29)
    elseif craftedSkillId == 7 then
        return GetSkillLineNameById(31)
    elseif craftedSkillId == 1 then
        return GetSkillLineNameById(32)
    elseif craftedSkillId == 5 then
        return GetSkillLineNameById(33)
    elseif craftedSkillId == 6 then
        return GetSkillLineNameById(34)
    elseif craftedSkillId == 2 then
        return GetSkillLineNameById(72)
    elseif craftedSkillId == 8 then
        return GetSkillLineNameById(72)
    elseif craftedSkillId == 10 then
        return GetSkillLineNameById(45)
    elseif craftedSkillId == 9 then
        return GetSkillLineNameById(44)
    elseif craftedSkillId == 11 then
        return GetSkillLineNameById(48)
    else
        return GetSkillLineNameById(67)
    end
end

local function InitCraftedAbilityDict()
    for i = 1, GetNumCraftedAbilities() do
        craftedAbilityDict[GetCraftedAbilityIdAtIndex(i)] = true
    end
end

function SuperStarSkills:New(container)

    local manager = ZO_Object.New(SuperStarSkills)
    LSF:Initialize(GetUnitClassId("player"), GetUnitRaceId("player"))

    SuperStarSkills.builderFactory = SuperStarSkills:InitSkillsFactory() -- SuperStarSkills:InitInternalFactoryForBuilder() -- Init the build saver
    SuperStarSkills:InitializePreSelector()

    SuperStarSkills.availableSkillsPoints = SuperStarSkills:GetAvailableSkillPoints()

    manager.displayedAbilityProgressions = {}

    manager.container = container
    manager.availablePoints = 0
    -- manager.availablePointsLabel = GetControl(container, "AvailablePoints")

    manager.navigationTree = ZO_Tree:New(GetControl(container, "NavigationContainerScrollChild"), 60, -10, 300)

    local function TreeHeaderSetup(node, control, skillType, open)
        control.skillType = skillType
        control.text:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)
        control.text:SetText(GetString("SI_SKILLTYPE", skillType))
        local down, up, over = ZO_Skills_GetIconsForSkillType(skillType)

        control.icon:SetTexture(open and down or up)
        control.iconHighlight:SetTexture(over)

        ZO_IconHeader_Setup(control, open)
    end

    manager.navigationTree:AddTemplate("ZO_IconHeader", TreeHeaderSetup, nil, nil, nil, 0)

    local function TreeEntrySetup(node, control, data, open)
        local name = LSF:GetSkillLineName(data.skillType, data.skillLineIndex)
        control:SetText(zo_strformat(SI_SKILLS_TREE_NAME_FORMAT, name))
    end
    local function TreeEntryOnSelected(control, data, selected, reselectingDuringRebuild)
        control:SetSelected(selected)
        if selected and not reselectingDuringRebuild then
            manager:RefreshSkillInfo()
            manager:RefreshList()
        end

    end
    local function TreeEntryEquality(left, right)
        return left.skillType == right.skillType and left.skillLineIndex == right.skillLineIndex
    end

    manager.navigationTree:AddTemplate("SuperStarXMLSkillsNavigationEntry", TreeEntrySetup, TreeEntryOnSelected,
        TreeEntryEquality)

    manager.navigationTree:SetExclusive(true)
    manager.navigationTree:SetOpenAnimation("ZO_TreeOpenAnimation")

    manager.skillInfo = GetControl(container, "SkillInfo")

    manager.abilityList = GetControl(container, "AbilityList")
    ZO_ScrollList_Initialize(manager.abilityList)
    ZO_ScrollList_AddDataType(manager.abilityList, SKILL_ABILITY_DATA, "SuperStarXMLSkillsAbility", 70,
        function(control, data)
            manager:SetupAbilityEntry(control, data)
        end)
    ZO_ScrollList_AddDataType(manager.abilityList, SKILL_HEADER_DATA, "SuperStarXMLSkillsAbilityTypeHeader", 32,
        function(control, data)
            manager:SetupHeaderEntry(control, data)
        end)
    ZO_ScrollList_AddResizeOnScreenResize(manager.abilityList)

    manager.morphDialog = GetControl("SuperStarXMLSkillsMorphDialog")
    manager.morphDialog.desc = GetControl(manager.morphDialog, "Description")

    manager.morphDialog.baseAbility = GetControl(manager.morphDialog, "BaseAbility")
    manager.morphDialog.baseAbility.icon = GetControl(manager.morphDialog.baseAbility, "Icon")

    manager.morphDialog.morphAbility1 = GetControl(manager.morphDialog, "MorphAbility1")
    manager.morphDialog.morphAbility1.icon = GetControl(manager.morphDialog.morphAbility1, "Icon")
    manager.morphDialog.morphAbility1.selectedCallout = GetControl(manager.morphDialog.morphAbility1, "SelectedCallout")
    manager.morphDialog.morphAbility1.morph = ABILITY_LEVEL_UPPERMORPH
    manager.morphDialog.morphAbility1.rank = 4

    manager.morphDialog.morphAbility2 = GetControl(manager.morphDialog, "MorphAbility2")
    manager.morphDialog.morphAbility2.icon = GetControl(manager.morphDialog.morphAbility2, "Icon")
    manager.morphDialog.morphAbility2.selectedCallout = GetControl(manager.morphDialog.morphAbility2, "SelectedCallout")
    manager.morphDialog.morphAbility2.morph = ABILITY_LEVEL_LOWERMORPH
    manager.morphDialog.morphAbility2.rank = 4

    manager.morphDialog.confirmButton = GetControl(manager.morphDialog, "Confirm")

    local function SetupMorphAbilityConfirmDialog(dialog, abilityControl)
        if abilityControl.ability.atMorph then

            local ability = abilityControl.ability
            local slot = abilityControl.ability.slot

            dialog.desc:SetText(zo_strformat(SI_SKILLS_SELECT_MORPH, ability.name))

            dialog.baseAbility.skillType = abilityControl.skillType
            dialog.baseAbility.skillLineIndex = abilityControl.skillLineIndex
            dialog.baseAbility.abilityIndex = abilityControl.abilityIndex
            dialog.baseAbility.abilityId = abilityControl.abilityId
            dialog.baseAbility.abilityLevel = ABILITY_LEVEL_NONMORPHED
            dialog.baseAbility.icon:SetTexture(slot.iconFile)

            dialog.morphAbility1.abilityId = LSF:GetAbilityId(dialog.baseAbility.skillType,
                dialog.baseAbility.skillLineIndex, dialog.baseAbility.abilityIndex, dialog.morphAbility1.morph)
            local morph1Icon = GetAbilityIcon(dialog.morphAbility1.abilityId)
            dialog.morphAbility1.skillType = dialog.baseAbility.skillType
            dialog.morphAbility1.skillLineIndex = dialog.baseAbility.skillLineIndex
            dialog.morphAbility1.abilityIndex = dialog.baseAbility.abilityIndex
            dialog.morphAbility1.abilityLevel = ABILITY_LEVEL_UPPERMORPH
            dialog.morphAbility1.icon:SetTexture(morph1Icon)
            dialog.morphAbility1.selectedCallout:SetHidden(true)
            ZO_ActionSlot_SetUnusable(dialog.morphAbility1.icon, false)

            dialog.morphAbility2.abilityId = LSF:GetAbilityId(dialog.baseAbility.skillType,
                dialog.baseAbility.skillLineIndex, dialog.baseAbility.abilityIndex, dialog.morphAbility2.morph)
            local morph2Icon = GetAbilityIcon(dialog.morphAbility2.abilityId)
            dialog.morphAbility2.skillType = dialog.baseAbility.skillType
            dialog.morphAbility2.skillLineIndex = dialog.baseAbility.skillLineIndex
            dialog.morphAbility2.abilityIndex = dialog.baseAbility.abilityIndex
            dialog.morphAbility2.abilityLevel = ABILITY_LEVEL_LOWERMORPH
            dialog.morphAbility2.icon:SetTexture(morph2Icon)
            dialog.morphAbility2.selectedCallout:SetHidden(true)
            ZO_ActionSlot_SetUnusable(dialog.morphAbility2.icon, false)

            dialog.confirmButton:SetState(BSTATE_DISABLED)

            dialog.chosenSkillType = dialog.baseAbility.skillType
            dialog.chosenSkillLineIndex = dialog.baseAbility.skillLineIndex
            dialog.chosenAbilityIndex = dialog.baseAbility.abilityIndex
            dialog.chosenMorph = nil

        end
    end

    ZO_Dialogs_RegisterCustomDialog("SUPERSTAR_MORPH_ABILITY_CONFIRM", {
        customControl = manager.morphDialog,
        setup = SetupMorphAbilityConfirmDialog,
        title = {
            text = SI_SKILLS_MORPH_ABILITY
        },
        buttons = {
            [1] = {
                control = GetControl(manager.morphDialog, "Confirm"),
                text = SI_SKILLS_MORPH_CONFIRM,
                callback = function(dialog)
                    if dialog.chosenMorph then
                        SuperStarSkills:MorphAbility(dialog.chosenSkillType, dialog.chosenSkillLineIndex,
                            dialog.chosenAbilityIndex, dialog.chosenMorph)
                    end
                end
            },

            [2] = {
                control = GetControl(manager.morphDialog, "Cancel"),
                text = SI_CANCEL
            }
        }
    })

    manager.confirmDialog = GetControl("SuperStarXMLSkillsConfirmDialog")
    manager.confirmDialog.abilityName = GetControl(manager.confirmDialog, "AbilityName")
    manager.confirmDialog.ability = GetControl(manager.confirmDialog, "Ability")
    manager.confirmDialog.ability.icon = GetControl(manager.confirmDialog.ability, "Icon")

    local function SetupPurchaseAbilityConfirmDialog(dialog, abilityControl)
        local ability = abilityControl.ability
        local slot = abilityControl.ability.slot

        SetAbilityButtonTextures(dialog.ability, ability.passive)

        dialog.abilityName:SetText(ability.plainName)

        dialog.ability.skillType = abilityControl.skillType
        dialog.ability.skillLineIndex = abilityControl.skillLineIndex
        dialog.ability.abilityIndex = abilityControl.abilityIndex
        dialog.ability.abilityId = abilityControl.abilityId
        dialog.ability.abilityLevel = abilityControl.abilityLevel
        dialog.ability.icon:SetTexture(slot.iconFile)

        dialog.chosenSkillType = abilityControl.skillType
        dialog.chosenSkillLineIndex = abilityControl.skillLineIndex
        dialog.chosenAbilityIndex = abilityControl.abilityIndex
    end

    ZO_Dialogs_RegisterCustomDialog("SUPERSTAR_PURCHASE_ABILITY_CONFIRM", {
        customControl = manager.confirmDialog,
        setup = SetupPurchaseAbilityConfirmDialog,
        title = {
            text = SI_SKILLS_CONFIRM_PURCHASE_ABILITY
        },
        buttons = {
            [1] = {
                control = GetControl(manager.confirmDialog, "Confirm"),
                text = SI_SKILLS_UNLOCK_CONFIRM,
                callback = function(dialog)
                    if dialog.chosenSkillType and dialog.chosenSkillLineIndex and dialog.chosenAbilityIndex then
                        SuperStarSkills:PurchaseAbility(dialog.chosenSkillType, dialog.chosenSkillLineIndex,
                            dialog.chosenAbilityIndex)
                    end
                end
            },
            [2] = {
                control = GetControl(manager.confirmDialog, "Cancel"),
                text = SI_CANCEL
            }
        }
    })

    manager.upgradeDialog = GetControl("SuperStarXMLSkillsUpgradeDialog")
    manager.upgradeDialog.desc = GetControl(manager.upgradeDialog, "Description")

    manager.upgradeDialog.baseAbility = GetControl(manager.upgradeDialog, "BaseAbility")
    manager.upgradeDialog.baseAbility.icon = GetControl(manager.upgradeDialog.baseAbility, "Icon")

    manager.upgradeDialog.upgradeAbility = GetControl(manager.upgradeDialog, "UpgradeAbility")
    manager.upgradeDialog.upgradeAbility.icon = GetControl(manager.upgradeDialog.upgradeAbility, "Icon")

    local function SetupUpgradeAbilityDialog(dialog, abilityControl)

        local ability = abilityControl.ability
        local slot = abilityControl.ability.slot

        dialog.desc:SetText(zo_strformat(SI_SKILLS_UPGRADE_DESCRIPTION, ability.plainName))

        SetAbilityButtonTextures(dialog.baseAbility, ability.passive)
        SetAbilityButtonTextures(dialog.upgradeAbility, ability.passive)

        dialog.baseAbility.skillType = abilityControl.skillType
        dialog.baseAbility.skillLineIndex = abilityControl.skillLineIndex
        dialog.baseAbility.abilityIndex = abilityControl.abilityIndex
        dialog.baseAbility.abilityId = abilityControl.abilityId
        dialog.baseAbility.abilityLevel = abilityControl.abilityLevel

        dialog.baseAbility.icon:SetTexture(slot.iconFile)

        local nextAbilityId = LSF:GetAbilityId(abilityControl.skillType, abilityControl.skillLineIndex,
            abilityControl.abilityIndex, ability.rank + 1)
        local upgradeIcon = GetAbilityIcon(nextAbilityId)

        dialog.upgradeAbility.skillType = abilityControl.skillType
        dialog.upgradeAbility.skillLineIndex = abilityControl.skillLineIndex
        dialog.upgradeAbility.abilityIndex = abilityControl.abilityIndex
        dialog.upgradeAbility.abilityId = nextAbilityId
        dialog.upgradeAbility.abilityLevel = abilityControl.abilityLevel + 1
        dialog.upgradeAbility.icon:SetTexture(upgradeIcon)

        dialog.chosenSkillType = abilityControl.skillType
        dialog.chosenSkillLineIndex = abilityControl.skillLineIndex
        dialog.chosenAbilityIndex = abilityControl.abilityIndex

    end

    ZO_Dialogs_RegisterCustomDialog("SUPERSTAR_UPGRADE_ABILITY_CONFIRM", {
        customControl = manager.upgradeDialog,
        setup = SetupUpgradeAbilityDialog,
        title = {
            text = SI_SKILLS_UPGRADE_ABILITY
        },
        buttons = {
            [1] = {
                control = GetControl(manager.upgradeDialog, "Confirm"),
                text = SI_SKILLS_UPGRADE_CONFIRM,
                callback = function(dialog)
                    if dialog.chosenSkillType and dialog.chosenSkillLineIndex and dialog.chosenAbilityIndex then
                        SuperStarSkills:UpgradeAbility(dialog.chosenSkillType, dialog.chosenSkillLineIndex,
                            dialog.chosenAbilityIndex)
                    end
                end
            },
            [2] = {
                control = GetControl(manager.upgradeDialog, "Cancel"),
                text = SI_CANCEL
            }
        }
    })

    local function Refresh()
        manager:Refresh()
    end

    local function OnSkillPointsChanged()
        manager:RefreshSkillInfo()
        manager:RefreshList()
    end

    container:RegisterForEvent(EVENT_SKILLS_FULL_UPDATE, Refresh)
    container:RegisterForEvent(EVENT_SKILL_POINTS_CHANGED, OnSkillPointsChanged)
    container:RegisterForEvent(EVENT_PLAYER_ACTIVATED, Refresh)

    return manager

end

function SuperStarSkills:SetupAbilityEntry(ability, data)

    -- Texture used for buttons
    local ALERT_TEXTURES = {
        [ZO_SKILLS_MORPH_STATE] = {
            normal = "EsoUI/Art/Progression/morph_up.dds",
            mouseDown = "EsoUI/Art/Progression/morph_down.dds",
            mouseover = "EsoUI/Art/Progression/morph_over.dds"
        },
        [ZO_SKILLS_PURCHASE_STATE] = {
            normal = "EsoUI/Art/Progression/addPoints_up.dds",
            mouseDown = "EsoUI/Art/Progression/addPoints_down.dds",
            mouseover = "EsoUI/Art/Progression/addPoints_over.dds"
        },
        -- Lykeion@5.1.0 
        [ZO_SKILLS_REFUND_STATE] = {
            normal = "EsoUI/Art/Progression/removePoints_up.dds",
            mouseDown = "EsoUI/Art/Progression/removePoints_down.dds",
            mouseover = "EsoUI/Art/Progression/removePoints_over.dds"
        }
    }

    SetAbilityButtonTextures(ability.slot, data.passive)
    ability.name = data.name
    ability.plainName = data.plainName
    ability.nameLabel:SetText(data.name)

    ability.cancel.skillType = data.skillType
    ability.cancel.skillLineIndex = data.skillLineIndex
    ability.cancel.abilityIndex = data.abilityIndex
    ability.cancel.abilityId = data.abilityId
    ability.cancel.abilityLevel = data.abilityLevel
    ability.cancel.rank = data.rank
    -- To dialogs
    ability.alert.skillType = data.skillType
    ability.alert.skillLineIndex = data.skillLineIndex
    ability.alert.abilityIndex = data.abilityIndex
    ability.alert.abilityId = data.abilityId
    ability.alert.abilityLevel = data.abilityLevel
    ability.alert.rank = data.rank

    -- To this function
    ability.purchased = data.purchased
    ability.passive = data.passive
    ability.rank = data.rank
    ability.maxUpgradeLevel = data.maxUpgradeLevel
    ability.crafted = data.crafted

    -- To icon
    local slot = ability.slot
    slot.skillType = data.skillType
    slot.skillLineIndex = data.skillLineIndex
    slot.abilityIndex = data.abilityIndex
    slot.abilityId = data.abilityId
    slot.abilityLevel = data.abilityLevel
    slot.icon:SetTexture(data.icon)
    slot.iconFile = data.icon

    ability:ClearAnchors()

    if (not ability.passive) then
        ability.atMorph = true
    else
        ability.atMorph = false
        ability.upgradeAvailable = false
        if (ability.maxUpgradeLevel) then
            ability.upgradeAvailable = ability.rank < ability.maxUpgradeLevel
        end
    end

    ability.nameLabel:SetAnchor(LEFT, ability.slot, RIGHT, 10, 0)

    if ability.purchased then
        if LSF:IsSkillAbilityAutoGrant(slot.skillType, slot.skillLineIndex, slot.abilityIndex) ~= 1 then
            ability.cancel:SetHidden(false)
            ZO_Skills_SetAlertButtonTextures(ability.cancel, ALERT_TEXTURES[ZO_SKILLS_REFUND_STATE])
        else 
            if ability.passive then
                if ability.rank > LSF:SkillAbilityAutoGrantInfo(slot.skillType, slot.skillLineIndex, slot.abilityIndex) then
                    ability.cancel:SetHidden(false)
                    ZO_Skills_SetAlertButtonTextures(ability.cancel, ALERT_TEXTURES[ZO_SKILLS_REFUND_STATE])
                else
                    ability.cancel:SetHidden(true)
                end
            else
                ability.cancel:SetHidden(true)
            end
            
        end

        slot:SetEnabled(true)
        ZO_ActionSlot_SetUnusable(slot.icon, false)
        ability.nameLabel:SetColor(PURCHASED_COLOR:UnpackRGBA())

        if ability.atMorph and SUPERSTAR_SKILLS_WINDOW.availablePoints > 0 then
            ability.alert:SetHidden(false)
            ability.lock:SetHidden(true)
            ZO_Skills_SetAlertButtonTextures(ability.alert, ALERT_TEXTURES[ZO_SKILLS_MORPH_STATE])
        elseif not ability.maxUpgradeLevel then
            ability.alert:SetHidden(true)
            ability.lock:SetHidden(true)
        elseif ability.upgradeAvailable and SUPERSTAR_SKILLS_WINDOW.availablePoints > 0 then
            ability.alert:SetHidden(false)
            ability.lock:SetHidden(true)
            ZO_Skills_SetAlertButtonTextures(ability.alert, ALERT_TEXTURES[ZO_SKILLS_PURCHASE_STATE])
        else
            ability.alert:SetHidden(true)
            ability.lock:SetHidden(true)
        end

        if ability.crafted then
            ability.alert:SetHidden(true)
        end

    else
        ability.cancel:SetHidden(true)
        slot:SetEnabled(false)
        ZO_ActionSlot_SetUnusable(slot.icon, true)
        ability.nameLabel:SetColor(UNPURCHASED_COLOR:UnpackRGBA())
        ability.lock:SetHidden(true)

        if SUPERSTAR_SKILLS_WINDOW.availablePoints > 0 then
            ability.alert:SetHidden(false)
            ZO_Skills_SetAlertButtonTextures(ability.alert, ALERT_TEXTURES[ZO_SKILLS_PURCHASE_STATE])
        else
            ability.alert:SetHidden(true)
        end

        if ability.crafted then
            ability.alert:SetHidden(true)
        end

    end
end

function SuperStarSkills:SetupHeaderEntry(header, data)
    local label = GetControl(header, "Label")

    if data.passive then
        label:SetText(GetString(SI_SKILLS_PASSIVE_ABILITIES))
    elseif data.ultimate then
        label:SetText(GetString(SI_SKILLS_ULTIMATE_ABILITIES))
    -- elseif data.crafted then
    --     label:SetText(GetString(SI_SCRIBING_CRAFTED_ABILITIES))
    else
        label:SetText(GetString(SI_SKILLS_ACTIVE_ABILITIES))
    end
end

function SuperStarSkills:RefreshList()
    if SUPERSTAR_SKILLS_WINDOW.container:IsHidden() then
        SUPERSTAR_SKILLS_WINDOW.dirty = true
        return
    end

    local skillType = SuperStarSkills:GetSelectedSkillType()
    local skillLineIndex = SuperStarSkills:GetSelectedSkillLineIndex()

    SuperStarSkills.scrollData = ZO_ScrollList_GetDataList(SUPERSTAR_SKILLS_WINDOW.abilityList)
    ZO_ScrollList_Clear(SUPERSTAR_SKILLS_WINDOW.abilityList)
    SUPERSTAR_SKILLS_WINDOW.displayedAbilityProgressions = {}

    local numAbilities = LSF:GetNumSkillAbilities(skillType, skillLineIndex)

    local foundFirstActiveOrCrafted = false
    local foundFirstPassive = false
    local foundFirstUltimate = false

    for abilityIndex = 1, numAbilities do

        local abilityType, maxUpgradeLevel = LSF:GetAbilityType(skillType, skillLineIndex, abilityIndex)

        local passive, ultimate, crafted
        if abilityType == ABILITY_TYPE_ULTIMATE then
            passive = false
            ultimate = true
            crafted = false
        elseif abilityType == ABILITY_TYPE_ACTIVE then
            passive = false
            ultimate = false
            crafted = false
        elseif abilityType == ABILITY_TYPE_PASSIVE then
            passive = true
            ultimate = false
            crafted = false
        elseif abilityType == ABILITY_TYPE_CRAFTED then
            passive = false
            ultimate = false
            crafted = true
        end

        local abilityId, earnedRank, icon, rank, name, plainName, abilityLevel, spentIn, purchased
        abilityLevel = SuperStarSkills.builderFactory[skillType][skillLineIndex][abilityIndex].abilityLevel
        spentIn = SuperStarSkills.builderFactory[skillType][skillLineIndex][abilityIndex].spentIn

        -- active / ult
        if (not passive and not crafted) then
            rank = 4
            abilityId = LSF:GetAbilityId(skillType, skillLineIndex, abilityIndex, abilityLevel)
            icon = GetAbilityIcon(abilityId)
            name = GetAbilityName(abilityId)
            plainName = zo_strformat(SI_ABILITY_NAME, name)
            name = SuperStarSkills:GenerateAbilityName(name, rank, maxUpgradeLevel, abilityType)
        elseif crafted then
            rank = 0
            abilityId = LSF:GetAbilityId(skillType, skillLineIndex, abilityIndex, rank)
            name = GetCraftedAbilityDisplayName(abilityId)
            icon = GetCraftedAbilityDisplayIcon(abilityId)
            abilityId = 0 -- use fake ability id
            plainName = zo_strformat(SI_ABILITY_NAME, name)
        else
            -- passive
            if abilityLevel > 0 then
                rank = abilityLevel
            else
                rank = 1
            end
            abilityId = LSF:GetAbilityId(skillType, skillLineIndex, abilityIndex, rank)
            icon = GetAbilityIcon(abilityId)
            name = GetAbilityName(abilityId)
            plainName = zo_strformat(SI_ABILITY_NAME, name)
            name = SuperStarSkills:GenerateAbilityName(name, abilityLevel, maxUpgradeLevel, abilityType)
        end
        -- check for auto grant abilities
        if spentIn == 0 then
            purchased = LSF:IsSkillAbilityAutoGrant(skillType, skillLineIndex, abilityIndex) == 1
            abilityLevel = LSF:SkillAbilityAutoGrantInfo(skillType, skillLineIndex, abilityIndex)
        else
            purchased = true
        end

        local isActiveOrCrafted = (not passive and not ultimate)
        local isUltimate = (not passive and ultimate and not crafted)

        local addHeader = (passive and not foundFirstPassive) or
                            (isUltimate and not foundFirstUltimate) or 
                              (isActiveOrCrafted and not foundFirstActiveOrCrafted)
        if addHeader then
            table.insert(SuperStarSkills.scrollData, ZO_ScrollList_CreateDataEntry(SKILL_HEADER_DATA, {
                passive = passive,
                ultimate = isUltimate
            }))
        end

        foundFirstActiveOrCrafted = foundFirstActiveOrCrafted or isActiveOrCrafted
        foundFirstPassive = foundFirstPassive or passive
        foundFirstUltimate = foundFirstUltimate or isUltimate

        table.insert(SuperStarSkills.scrollData, ZO_ScrollList_CreateDataEntry(SKILL_ABILITY_DATA, {
            skillType = skillType,
            skillLineIndex = skillLineIndex,
            abilityIndex = abilityIndex,
            abilityId = abilityId,
            abilityLevel = abilityLevel,
            plainName = plainName,
            name = name,
            icon = icon,
            -- earnedRank = earnedRank,
            passive = passive,
            ultimate = ultimate,
            crafted = crafted,
            purchased = purchased,
            rank = rank,
            maxUpgradeLevel = maxUpgradeLevel
        }))
    end

    ZO_ScrollList_Commit(SUPERSTAR_SKILLS_WINDOW.abilityList)

end

function SuperStarSkills:GetSkillData(skillType, skillLineIndex, abilityIndex)
    local skillData
    if skillType == SKILL_TYPE_CLASS then
        if skillLineIndex > 0 and skillLineIndex < 4 then
            local cid = LSF:GetSkillLineIdFromClass((SuperStarSkills.class or GetUnitClassId()), skillLineIndex)
            for _, sl in SKILLS_DATA_MANAGER:GetSkillTypeData(skillType):SkillLineIterator() do
                if sl:GetId() == cid then
                    return sl:GetSkillDataByIndex(abilityIndex)
                end
            end
        end
    elseif skillType == SKILL_TYPE_RACIAL then
        if skillLineIndex > 0 and skillLineIndex < 11 then
            local rid = LSF:GetSkillLineIdFromRace(SuperStarSkills.race or GetUnitRaceId())
            for _, sl in SKILLS_DATA_MANAGER:GetSkillTypeData(skillType):SkillLineIterator() do
                if sl:GetId() == rid then
                    return sl:GetSkillDataByIndex(abilityIndex)
                end
            end
        end
    else
        skillData = SKILLS_DATA_MANAGER:GetSkillDataByIndices(skillType, skillLineIndex, abilityIndex)
    end
    return skillData
end

function SuperStarSkills:InitSkillsFactory()

    local skillParser = {}

    for skillType = 1, SKILLTYPES_IN_SKILLBUILDER do
        skillParser[skillType] = {}
        for skillLineIndex = 1, LSF:GetNumSkillLinesPerChar(skillType) do
            skillParser[skillType][skillLineIndex] = {}
            skillParser[skillType][skillLineIndex].skillLineId = 0
            skillParser[skillType][skillLineIndex].pointsSpent = 0
            for abilityIndex = 1, LSF:GetNumSkillAbilities(skillType, skillLineIndex) do
                skillParser[skillType][skillLineIndex][abilityIndex] = {}

                skillParser[skillType][skillLineIndex][abilityIndex].abilityId = 0
                skillParser[skillType][skillLineIndex][abilityIndex].spentIn = 0
                skillParser[skillType][skillLineIndex][abilityIndex].abilityLevel =
                    LSF:SkillAbilityAutoGrantInfo(skillType, skillLineIndex, abilityIndex)
            end
        end
    end

    return skillParser
end

function SuperStarSkills:GenerateAbilityName(name, currentUpgradeLevel, maxUpgradeLevel, abilityType)
    if abilityType ~= ABILITY_TYPE_CRAFTED then
        return zo_strformat(SI_SKILLS_ENTRY_NAME_FORMAT, name)
    elseif currentUpgradeLevel and maxUpgradeLevel and maxUpgradeLevel > 1 then
        return zo_strformat(SI_ABILITY_NAME_AND_UPGRADE_LEVELS, name, currentUpgradeLevel, maxUpgradeLevel)
    elseif abilityType ~= ABILITY_TYPE_PASSIVE then
        if currentUpgradeLevel then
            return zo_strformat(SI_ABILITY_NAME_AND_RANK, name, currentUpgradeLevel)
        end
    end

    return zo_strformat(SI_SKILLS_ENTRY_NAME_FORMAT, name)
end

function SuperStarSkills:RefreshSkillInfo()

    if SUPERSTAR_SKILLS_WINDOW.container:IsHidden() then
        SUPERSTAR_SKILLS_WINDOW.dirty = true
        return
    end

    SUPERSTAR_SKILLS_WINDOW.availablePoints = SuperStarSkills.spentSkillPoints
    -- SUPERSTAR_SKILLS_WINDOW.availablePointsLabel:SetText(zo_strformat(SI_SKILLS_POINTS_TO_SPEND,
    --     SUPERSTAR_SKILLS_WINDOW.availablePoints))

end

-- Serve as a workaround until ZOS fix game crashing
--_Returns:_ *string* _name_, *textureName* _texture_, *luaindex* _earnedRank_, *bool* _passive_, *bool* _ultimate_, *bool* _purchased_, *luaindex:nilable* _progressionIndex_, *integer* _rank_, *bool* _isCrafted_
local function GetSkillAbilityInfoSafe(skillType, skillLineIndex, abilityIndex)
    if IsCraftedAbilitySkill(skillType, skillLineIndex, abilityIndex) then
        local craftedAbilityId = GetCraftedAbilitySkillCraftedAbilityId(skillType, skillLineIndex, abilityIndex)
        -- local name = GetCraftedAbilityDisplayName(craftedAbilityId)
        local abilityId = GetAbilityIdForCraftedAbilityId(craftedAbilityId)
        local abilityName = GetAbilityName(abilityId)
        local icon = GetAbilityIcon(abilityId)
        return abilityName, icon, 0, false, false, false, nil, 0, true
    else
        return GetSkillAbilityInfo(skillType, skillLineIndex, abilityIndex), false
    end
end

local function GetSkillAbilityPurchaseInfo(skillType, skillLineIndex, abilityIndex)

    local _, _, _, isPassive, isUltimate, isPurchased, progressionIndex, rank, isCrafted =
        GetSkillAbilityInfoSafe(skillType, skillLineIndex, abilityIndex)
    local spentIn, morph, passiveLevel

    if not isPurchased then
        spentIn = 0
    elseif progressionIndex then

        -- Active skills
        _, morph = GetAbilityProgressionInfo(progressionIndex)
        spentIn = math.min(morph + 1, 2) -- morph = 0,1,2
        if LSF:IsSkillAbilityAutoGrant(skillType, skillLineIndex, abilityIndex) then
            spentIn = spentIn - 1
        end

    else

        -- Passive skills
        passiveLevel = GetSkillAbilityUpgradeInfo(skillType, skillLineIndex, abilityIndex) or 1
        spentIn = passiveLevel

        if LSF:IsSkillAbilityAutoGrant(skillType, skillLineIndex, abilityIndex) then
            spentIn = spentIn - 1
        end

    end

    return isPassive, isUltimate, isPurchased, spentIn, morph, passiveLevel, isCrafted

end

function SuperStarSkills:GetAvailableSkillPoints()

    local skillPoints = 0
    local numLines
    local spentIn = 0

    -- SkillTypes (class, etc)
    for skillType = 1, SKILLTYPES_IN_SKILLBUILDER do

        -- SkillLine (Bow, etc)
        numLines = LSF:GetNumSkillLinesPerChar(skillType)
        for skillLineIndex = 1, numLines do

            for abilityIndex = 1, GetNumSkillAbilities(skillType, skillLineIndex) do
                _, _, _, spentIn = GetSkillAbilityPurchaseInfo(skillType, skillLineIndex, abilityIndex)
                if spentIn < 0 then
                    d(skillType .. "-" .. skillLineIndex .. "-" .. abilityIndex)
                    d(spentIn)
                end
                skillPoints = skillPoints + spentIn
            end
        end
    end

    SuperStarSkills.spentSkillPoints = skillPoints + GetAvailableSkillPoints()

    return SuperStarSkills.spentSkillPoints

end

function SuperStarSkills:GetSelectedSkillType()
    local selectedData = SUPERSTAR_SKILLS_WINDOW.navigationTree:GetSelectedData()
    if selectedData then
        return selectedData.skillType
    end
end

function SuperStarSkills:GetSelectedSkillLineIndex()
    local selectedData = SUPERSTAR_SKILLS_WINDOW.navigationTree:GetSelectedData()
    if selectedData then
        return selectedData.skillLineIndex
    end
end

function SuperStarSkills:Refresh()

    local skillTypeToSound = {
        [SKILL_TYPE_CLASS] = SOUNDS.SKILL_TYPE_CLASS,
        [SKILL_TYPE_WEAPON] = SOUNDS.SKILL_TYPE_WEAPON,
        [SKILL_TYPE_ARMOR] = SOUNDS.SKILL_TYPE_ARMOR,
        [SKILL_TYPE_WORLD] = SOUNDS.SKILL_TYPE_WORLD,
        [SKILL_TYPE_GUILD] = SOUNDS.SKILL_TYPE_GUILD,
        [SKILL_TYPE_AVA] = SOUNDS.SKILL_TYPE_AVA,
        [SKILL_TYPE_RACIAL] = SOUNDS.SKILL_TYPE_RACIAL,
        [SKILL_TYPE_TRADESKILL] = SOUNDS.SKILL_TYPE_TRADESKILL
    }

    if SUPERSTAR_SKILLS_WINDOW.container:IsHidden() then
        SUPERSTAR_SKILLS_WINDOW.dirty = true
        return
    end

    SUPERSTAR_SKILLS_WINDOW.navigationTree:Reset()
    for skillType = 1, SKILLTYPES_IN_SKILLBUILDER do
        local numSkillLines = LSF:GetNumSkillLinesPerChar(skillType)
        if numSkillLines > 0 then
            local parent = SUPERSTAR_SKILLS_WINDOW.navigationTree:AddNode("ZO_IconHeader", skillType, nil,
                skillTypeToSound[skillType])
            for skillLineIndex = 1, numSkillLines do
                if LSF:GetNumSkillAbilities(skillType, skillLineIndex) > 0 then -- Handle an Empty SkillLine (removed)
                    local node = SUPERSTAR_SKILLS_WINDOW.navigationTree:AddNode("SuperStarXMLSkillsNavigationEntry", {
                        skillType = skillType,
                        skillLineIndex = skillLineIndex
                    }, parent, SOUNDS.SKILL_LINE_SELECT)
                end
            end
        end
    end

    SUPERSTAR_SKILLS_WINDOW.navigationTree:Commit()

    SuperStarSkills:RefreshSkillInfo()
    SuperStarSkills:RefreshList()

end

function SuperStarSkills:GetNumSkillAbilitiesForBuilder(skillType, skillLineIndex)

    if SuperStarSkills.builderFactory[skillType][skillLineIndex] then
        return #SuperStarSkills.builderFactory[skillType][skillLineIndex]
    end

    return 0

end

function SuperStarSkills:OnShown()
    if SUPERSTAR_SKILLS_WINDOW.dirty then
        SuperStarSkills:Refresh()
    end
end

function SuperStarSkills:PurchaseAbility(skillType, skillLineIndex, abilityIndex)

    SuperStarSkills.builderFactory[skillType][skillLineIndex][abilityIndex].spentIn = 1

    if LSF:GetAbilityType(skillType, skillLineIndex, abilityIndex) == ABILITY_TYPE_PASSIVE then
        SuperStarSkills.builderFactory[skillType][skillLineIndex][abilityIndex].abilityLevel = 1
    end

    SuperStarSkills.spentSkillPoints = SuperStarSkills.spentSkillPoints - 1

    SuperStarSkills:RefreshSkillInfo()
    SuperStarSkills:RefreshList()
end

function SuperStarSkills:UpgradeAbility(skillType, skillLineIndex, abilityIndex)

    SuperStarSkills.builderFactory[skillType][skillLineIndex][abilityIndex].spentIn =
        SuperStarSkills.builderFactory[skillType][skillLineIndex][abilityIndex].spentIn + 1
    SuperStarSkills.builderFactory[skillType][skillLineIndex][abilityIndex].abilityLevel =
        SuperStarSkills.builderFactory[skillType][skillLineIndex][abilityIndex].abilityLevel + 1
    SuperStarSkills.spentSkillPoints = SuperStarSkills.spentSkillPoints - 1

    SuperStarSkills:RefreshSkillInfo()
    SuperStarSkills:RefreshList()

end

function SuperStarSkills:MorphAbility(skillType, skillLineIndex, abilityIndex, morphChoiceIndex)

    if SuperStarSkills.builderFactory[skillType][skillLineIndex][abilityIndex].abilityLevel == ABILITY_LEVEL_NONMORPHED then
        SuperStarSkills.builderFactory[skillType][skillLineIndex][abilityIndex].spentIn =
            SuperStarSkills.builderFactory[skillType][skillLineIndex][abilityIndex].spentIn + 1
        SuperStarSkills.spentSkillPoints = SuperStarSkills.spentSkillPoints - 1
    end

    SuperStarSkills.builderFactory[skillType][skillLineIndex][abilityIndex].abilityLevel = morphChoiceIndex

    SuperStarSkills:RefreshSkillInfo()
    SuperStarSkills:RefreshList()

end

-- Called by Keybind
local function ResetSkillBuilder()

    -- sigo@v4.3.1 - stop asking if the values are boolean and not actual data
    -- if SuperStarSkills.pendingCPDataForBuilder or SuperStarSkills.pendingAttrDataForBuilder then
    if type(SuperStarSkills.pendingCPDataForBuilder) == "table" or type(SuperStarSkills.pendingAttrDataForBuilder) ==
        "table" then
        ZO_Dialogs_ShowDialog("SUPERSTAR_REINIT_SKILLBUILDER_WITH_ATTR_CP")
    else

        SuperStarSkills.builderFactory = SuperStarSkills:InitSkillsFactory() -- SuperStarSkills:InitInternalFactoryForBuilder()
        SuperStarSkills:InitializePreSelector()
        SuperStarSkills:Refresh()

        SUPERSTAR_SKILLS_SCENE:RemoveFragment(SUPERSTAR_SKILLS_BUILDERWINDOW)
        SUPERSTAR_SKILLS_SCENE:AddFragment(SUPERSTAR_SKILLS_PRESELECTORWINDOW)
    end

end

-- sigo@v4.3.1
-- created a separate function to ensure dialog is answered before loading a build
local function ResetSkillBuilderAndLoadBuild()

    if type(SuperStarSkills.pendingCPDataForBuilder) == "table" or type(SuperStarSkills.pendingAttrDataForBuilder) ==
        "table" then
        ZO_Dialogs_ShowDialog("SUPERSTAR_REINIT_SKILLBUILDER_WITH_ATTR_CP2")
    else
        local skillsData = SuperStarSkills.pendingSkillsDataForLoading
        local cpData = SuperStarSkills.pendingCPDataForLoading
        local attrData = SuperStarSkills.pendingAttrDataForLoading

        if skillsData and cpData and attrData then

            ResetSkillBuilder()

            -- allow builds to be edited even if you don't have enough skill points
            if SuperStarSkills.spentSkillPoints < skillsData.pointsRequired then
                SuperStarSkills.spentSkillPoints = math.max(SP_MAX_SPENDABLE_POINTS, skillsData.pointsRequired) -- set to SP_MAX_SPENDABLE_POINTS or skillsData.pointsRequired
                SuperStarXMLSkillsPreSelector:GetNamedChild("SkillPoints"):GetNamedChild("Display"):SetText(
                    SuperStarSkills.spentSkillPoints)
                SuperStarXMLSkillsPreSelector:GetNamedChild("SkillPoints"):GetNamedChild("Display"):SetColor(1, 0, 0, 1)
            end
            local availablePoints = SuperStarSkills.spentSkillPoints - skillsData.pointsRequired

            if availablePoints >= 0 then
                SuperStarSkills.class = skillsData.classId
                SuperStarSkills.race = skillsData.raceId
                LSF:Initialize(skillsData.classId, skillsData.raceId)
                SuperStarSkills.builderFactory = skillsData
                SuperStarSkills.pendingCPDataForBuilder = cpData
                SuperStarSkills.pendingAttrDataForBuilder = attrData

                SuperStarSkills.spentSkillPoints = availablePoints

                SUPERSTAR_SKILLS_SCENE:RemoveFragment(SUPERSTAR_SKILLS_PRESELECTORWINDOW)
                SUPERSTAR_SKILLS_SCENE:AddFragment(SUPERSTAR_SKILLS_BUILDERWINDOW)

                LMM:Update(MENU_CATEGORY_SUPERSTAR, "SuperStarSkills")
            else
                -- d(string.format("[SuperStar] Not enough available skill points. Have: %u, Need: %u", SuperStarSkills.spentSkillPoints, db.favoritesList[index].sp))
            end
        end

        SuperStarSkills.pendingSkillsDataForLoading = nil
        SuperStarSkills.pendingCPDataForLoading = nil
        SuperStarSkills.pendingAttrDataForLoading = nil
    end

end

-- Called by XML
function SuperStar_AbilityAlert_OnClicked(control)
    if not control.ability.purchased then
        ZO_Dialogs_ShowDialog("SUPERSTAR_PURCHASE_ABILITY_CONFIRM", control)
    elseif control.ability.atMorph then
        ZO_Dialogs_ShowDialog("SUPERSTAR_MORPH_ABILITY_CONFIRM", control)
    elseif control.ability.upgradeAvailable then
        ZO_Dialogs_ShowDialog("SUPERSTAR_UPGRADE_ABILITY_CONFIRM", control)
    end
end

-- Lykeion@5.1.0 
function SuperStarSkills:RefundAbility(skillType, skillLineIndex, abilityIndex)

    SuperStarSkills.builderFactory[skillType][skillLineIndex][abilityIndex].spentIn = SuperStarSkills.builderFactory[skillType][skillLineIndex][abilityIndex].spentIn - 1

    if LSF:GetAbilityType(skillType, skillLineIndex, abilityIndex) == ABILITY_TYPE_PASSIVE then
        SuperStarSkills.builderFactory[skillType][skillLineIndex][abilityIndex].abilityLevel = SuperStarSkills.builderFactory[skillType][skillLineIndex][abilityIndex].abilityLevel - 1
    end

    if LSF:GetAbilityType(skillType, skillLineIndex, abilityIndex) ~= ABILITY_TYPE_PASSIVE and SuperStarSkills.builderFactory[skillType][skillLineIndex][abilityIndex].abilityLevel > 0 then
        SuperStarSkills.builderFactory[skillType][skillLineIndex][abilityIndex].abilityLevel = 0
    end

    SuperStarSkills.spentSkillPoints = SuperStarSkills.spentSkillPoints + 1

    SuperStarSkills:RefreshSkillInfo()
    SuperStarSkills:RefreshList()
end

-- Called by XML
function SuperStar_AbilityRefund_OnClicked(control)
    SuperStarSkills:RefundAbility(control.skillType, control.skillLineIndex, control.abilityIndex)
end

-- Called by XML
function SuperStar_AbilitySlot_OnMouseEnter(control)
    local abilityId = control.abilityId
    local skillType = control.skillType
    local skillLineIndex = control.skillLineIndex
    local abilityIndex = control.abilityIndex
    local abilityLevel = control.abilityLevel or 0
    local abilityType = LSF:GetAbilityType(skillType, skillLineIndex, abilityIndex)
    local numAvailableSkillPoints = SKILL_POINT_ALLOCATION_MANAGER:GetAvailableSkillPoints()

    if (DoesAbilityExist(abilityId)) then
        if skillType == SKILL_TYPE_CLASS or skillType == SKILL_TYPE_RACIAL then
            local sd = SuperStarSkills:GetSkillData(skillType, skillLineIndex, abilityIndex)
            if sd then
                skillType, skillLineIndex, abilityIndex = sd:GetIndices()
            end
        end

        local skd = SKILLS_DATA_MANAGER:GetSkillDataByIndices(skillType, skillLineIndex, abilityIndex)
        local skdpd = skd:GetCurrentProgressionData()

        InitializeTooltip(SuperStarAbilityTooltip, control, TOPLEFT, 5, -5, TOPRIGHT)
        -- summerset : override to make up for lack of progression data
        -- SuperStarAbilityTooltip:SetAbilityId(abilityId)
        if abilityType == ABILITY_TYPE_PASSIVE then
            if abilityLevel == 0 then
                abilityLevel = 1
            end
            local s = EsoStrings[SI_SKILL_ABILITY_TOOLTIP_RANK_UNLOCK_INFO ]
            EsoStrings[SI_SKILL_ABILITY_TOOLTIP_RANK_UNLOCK_INFO ] = nil
            SuperStarAbilityTooltip:SetPassiveSkill(skillType, skillLineIndex, abilityIndex, abilityLevel, abilityLevel,
                numAvailableSkillPoints, true)
            EsoStrings[SI_SKILL_ABILITY_TOOLTIP_RANK_UNLOCK_INFO ] = s
        else
            -- active/ultimate
            -- let's cheat a bit here
            local s = EsoStrings[SI_SKILL_ABILITY_TOOLTIP_RANK_UNLOCK_INFO ]
            EsoStrings[SI_SKILL_ABILITY_TOOLTIP_RANK_UNLOCK_INFO ] = nil
            SuperStarAbilityTooltip:SetActiveSkill(skillType, skillLineIndex, abilityIndex, abilityLevel, true, false,
                false, numAvailableSkillPoints, false, true, false, false, 4)
            EsoStrings[SI_SKILL_ABILITY_TOOLTIP_RANK_UNLOCK_INFO ] = s
        end

    end

end

function SuperStarSkills:GetAbilityFullDesc(abilityId)

    local fullDesc = ""

    if (DoesAbilityExist(abilityId)) then

        local abilityName = GetAbilityName(abilityId)
        fullDesc = fullDesc .. zo_strformat(SI_ABILITY_TOOLTIP_NAME, abilityName) .. ": "

        if (not IsAbilityPassive(abilityId)) then

            local channeled, castTime, channelTime = GetAbilityCastInfo(abilityId)
            if (channeled) then
                fullDesc = fullDesc .. "Chan:" ..
                               string.gsub(ZO_FormatTimeMilliseconds(channelTime, TIME_FORMAT_STYLE_CHANNEL_TIME,
                        TIME_FORMAT_PRECISION_TENTHS_RELEVANT, TIME_FORMAT_DIRECTION_NONE):gsub("%s", ""), "%a+", "s")
            else
                if castTime == 0 then
                    fullDesc = fullDesc .. "Instant"
                else
                    fullDesc = fullDesc .. "Cast:" ..
                                   string.gsub(
                            ZO_FormatTimeMilliseconds(castTime, TIME_FORMAT_STYLE_CAST_TIME,
                                TIME_FORMAT_PRECISION_TENTHS_RELEVANT, TIME_FORMAT_DIRECTION_NONE):gsub("%s", ""),
                            "%a+", "s")
                end
            end

            local targetDescription = GetAbilityTargetDescription(abilityId)

            if (targetDescription) then

                -- Zone, Area, Fläche = Zone (PBAoE)
                -- Cible, Enemy, Feind = Cible (Mono)
                -- Sol, Ground, Bodenziel = Sol (GTAoE)
                -- Vous-même, Self, Eigener Charakter = Self
                -- Cône, Cone, Kegel = CAoE

                if targetDescription == "Zone" or targetDescription == "Area" or targetDescription == "Fläche" then
                    fullDesc = fullDesc .. "/PBAoE"
                elseif targetDescription == "Ennemi" or targetDescription == "Enemy" or targetDescription == "Feind" then
                    fullDesc = fullDesc .. "/Mono"
                elseif targetDescription == "Sol" or targetDescription == "Ground" or targetDescription == "Bodenziel" then
                    fullDesc = fullDesc .. "/GTAoE"
                elseif targetDescription == "Vous-même" or targetDescription == "Self" or targetDescription ==
                    "Eigener Charakter" then
                    fullDesc = fullDesc .. "/Self"
                elseif targetDescription == "Cône" or targetDescription == "Cone" or targetDescription == "Kegel" then
                    fullDesc = fullDesc .. "/CAoE"
                end

            end

            local minRange, maxRange = GetAbilityRange(abilityId)
            if (maxRange > 0) then
                if (minRange == 0) then
                    fullDesc = fullDesc .. "/Range:" ..
                                   string.gsub(
                            zo_strformat(SI_ABILITY_TOOLTIP_RANGE, FormatFloatRelevantFraction(maxRange / 100)):gsub(
                                "è", ""):gsub("%s", ""), "%a+", "m")
                else
                    fullDesc = fullDesc .. "/Range:" ..
                                   string.gsub(
                            zo_strformat(SI_ABILITY_TOOLTIP_MIN_TO_MAX_RANGE,
                                FormatFloatRelevantFraction(minRange / 100), FormatFloatRelevantFraction(maxRange / 100)):gsub(
                                "è", ""):gsub("%s", ""), "%a+", "m")
                end
            end

            local radius = GetAbilityRadius(abilityId)
            local distance = GetAbilityAngleDistance(abilityId)
            if (radius > 0) then
                if (distance > 0) then
                    fullDesc = fullDesc .. "/AOE:" ..
                                   string.gsub(
                            zo_strformat(SI_ABILITY_TOOLTIP_AOE_DIMENSIONS, FormatFloatRelevantFraction(radius / 100),
                                FormatFloatRelevantFraction(distance / 100)):gsub("è", ""):gsub("%s", ""), "%a+", "m")
                else
                    fullDesc = fullDesc .. "/Radius:" .. string.gsub(
                        zo_strformat(SI_ABILITY_TOOLTIP_RADIUS, FormatFloatRelevantFraction(radius / 100)):gsub("è", "")
                            :gsub("%s", ""), "%a+", "m")
                end
            end

            local duration = GetAbilityDuration(abilityId)
            if (duration > 0) then
                fullDesc = fullDesc .. "/Dur:" ..
                               string.gsub(
                        ZO_FormatTimeMilliseconds(duration, TIME_FORMAT_STYLE_DURATION,
                            TIME_FORMAT_PRECISION_TENTHS_RELEVANT, TIME_FORMAT_DIRECTION_NONE):gsub("%s", ""), "%a+",
                        "s")
            end

        end

        local descriptionHeader = GetAbilityDescriptionHeader(abilityId)
        local description = GetAbilityDescription(abilityId)

        if (descriptionHeader ~= "" or description ~= "") then

            if (descriptionHeader ~= "") then
                fullDesc = fullDesc .. " " .. zo_strformat(SI_ABILITY_TOOLTIP_DESCRIPTION_HEADER, descriptionHeader)
            end

            if (description ~= "") then
                fullDesc = fullDesc .. " " .. zo_strformat(SI_ABILITY_TOOLTIP_DESCRIPTION, description)
            end

        end

    end

    return fullDesc:gsub("|[cC]%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\r\n", " "):gsub("  ", " ")

end

-- Called by XML
function SuperStar_AbilitySlot_OnMouseExit()
    ClearTooltip(SuperStarAbilityTooltip)
end

-- Called by XML
function SuperStarSkillsMorphAbilitySlot_OnClicked(control)
    SuperStarSkills:ChooseMorph(control)
end

function SuperStarSkills:SetMorphButtonTextures(button, chosen)
    if chosen then
        ZO_ActionSlot_SetUnusable(button.icon, false)
        button.selectedCallout:SetHidden(false)
    else
        ZO_ActionSlot_SetUnusable(button.icon, true)
        button.selectedCallout:SetHidden(true)
    end
end

function SuperStarSkills:ChooseMorph(morphSlot)
    if morphSlot then

        SUPERSTAR_SKILLS_WINDOW.morphDialog.chosenMorph = morphSlot.morph

        if morphSlot == SUPERSTAR_SKILLS_WINDOW.morphDialog.morphAbility1 then
            SuperStarSkills:SetMorphButtonTextures(SUPERSTAR_SKILLS_WINDOW.morphDialog.morphAbility1, true)
            SuperStarSkills:SetMorphButtonTextures(SUPERSTAR_SKILLS_WINDOW.morphDialog.morphAbility2, false)
        else
            SuperStarSkills:SetMorphButtonTextures(SUPERSTAR_SKILLS_WINDOW.morphDialog.morphAbility1, false)
            SuperStarSkills:SetMorphButtonTextures(SUPERSTAR_SKILLS_WINDOW.morphDialog.morphAbility2, true)
        end

        SUPERSTAR_SKILLS_WINDOW.morphDialog.confirmButton:SetState(BSTATE_NORMAL)

    end
end

-- Called by XML
function SuperStarSkills:InitializePreSelector()
    local classId = GetUnitClassId("player")
    SuperStar_SetSkillBuilderClass(classId) -- Select class

    local raceId = GetUnitRaceId("player")
    SuperStar_SetSkillBuilderRace(raceId) -- Select race

    local availablePointsForChar = 9999

    -- SuperStarXMLSkillsPreSelector:GetNamedChild("SkillPoints"):GetNamedChild("Display"):SetColor(1, 1, 1, 1)
    -- SuperStarXMLSkillsPreSelector:GetNamedChild("SkillPoints"):GetNamedChild("Display"):SetText(availablePointsForChar)

    SuperStarSkills.spentSkillPoints = availablePointsForChar
    SuperStarSkills.availableSkillsPointsForBuilder = availablePointsForChar
end

-- Called by XML
function SuperStarSkills_OnClickedAbility(control, button)

    if button == MOUSE_BUTTON_INDEX_LEFT then
        -- Display ability in chat
        if CHAT_SYSTEM.textEntry:GetText() == "" then
            local abilityFullDesc = SuperStarSkills:GetAbilityFullDesc(control.abilityId)
            if string.len(abilityFullDesc) > 347 then
                abilityFullDesc = string.sub(abilityFullDesc, 0, 347) .. " .."
            end
            CHAT_SYSTEM.textEntry:Open(abilityFullDesc)
            ZO_ChatWindowTextEntryEditBox:SelectAll()
        end
    elseif button == MOUSE_BUTTON_INDEX_MIDDLE then

        local skillType = control.skillType
        local skillLineIndex = control.skillLineIndex
        local abilityIndex = control.abilityIndex

        local abilityType, maxRank = LSF:GetAbilityType(skillType, skillLineIndex, abilityIndex)

        if not maxRank then
            maxRank = 1
        end

        local actualRank = SuperStarSkills.builderFactory[skillType][skillLineIndex][abilityIndex].spentIn

        if abilityType == ABILITY_TYPE_PASSIVE and actualRank < maxRank and SuperStarSkills.spentSkillPoints >=
            (maxRank - actualRank) then

            SuperStarSkills.builderFactory[skillType][skillLineIndex][abilityIndex].spentIn = maxRank
            SuperStarSkills.builderFactory[skillType][skillLineIndex][abilityIndex].abilityLevel = maxRank
            SuperStarSkills.spentSkillPoints = SuperStarSkills.spentSkillPoints - (maxRank - actualRank)

            SuperStarSkills:RefreshSkillInfo()
            SuperStarSkills:RefreshList()

        end

    elseif button == MOUSE_BUTTON_INDEX_RIGHT then

        local skillType = control.skillType
        local skillLineIndex = control.skillLineIndex
        local abilityIndex = control.abilityIndex

        -- Remove it from Skill Builder
        local oldSpentIn = SuperStarSkills.builderFactory[skillType][skillLineIndex][abilityIndex].spentIn
        if oldSpentIn >= 1 then

            SuperStarSkills.builderFactory[skillType][skillLineIndex][abilityIndex].spentIn = 0
            SuperStarSkills.builderFactory[skillType][skillLineIndex][abilityIndex].abilityLevel =
                LSF:SkillAbilityAutoGrantInfo(skillType, skillLineIndex, abilityIndex)
            SuperStarSkills.spentSkillPoints = SuperStarSkills.spentSkillPoints + oldSpentIn

            SuperStarSkills:RefreshSkillInfo()
            SuperStarSkills:RefreshList()
        end

    end

end

-- Called by XML
function SuperStarSkills_ChangeSP(delta)

    local displayedValue = SuperStarXMLSkillsPreSelector:GetNamedChild("SkillPoints"):GetNamedChild("Display"):GetText()

    if displayedValue ~= "" then
        local value = tonumber(displayedValue)
        value = value + delta

        if value < 0 then
            value = 0
        end
        if value > SP_MAX_SPENDABLE_POINTS then
            value = SP_MAX_SPENDABLE_POINTS
        end

        SuperStarXMLSkillsPreSelector:GetNamedChild("SkillPoints"):GetNamedChild("Display"):SetText(value)
        SuperStarSkills.spentSkillPoints = value
        SuperStarSkills.availableSkillsPointsForBuilder = value

        if value < SuperStarSkills.availableSkillsPoints then
            SuperStarXMLSkillsPreSelector:GetNamedChild("SkillPoints"):GetNamedChild("Display"):SetColor(0, 1, 0, 1)
        elseif value > SuperStarSkills.availableSkillsPoints then
            SuperStarXMLSkillsPreSelector:GetNamedChild("SkillPoints"):GetNamedChild("Display"):SetColor(1, 0, 0, 1)
        else
            SuperStarXMLSkillsPreSelector:GetNamedChild("SkillPoints"):GetNamedChild("Display"):SetColor(1, 1, 1, 1)
        end

    else
        SuperStarXMLSkillsPreSelector:GetNamedChild("SkillPoints"):GetNamedChild("Display"):SetText(
            SuperStarSkills.availableSkillsPoints)
        SuperStarSkills.spentSkillPoints = SuperStarSkills.availableSkillsPoints
        SuperStarSkills.availableSkillsPointsForBuilder = SuperStarSkills.availableSkillsPoints
        -- sigo@v4.1.3
        SuperStarXMLSkillsPreSelector:GetNamedChild("SkillPoints"):GetNamedChild("Display"):SetColor(1, 1, 1, 1)
    end

end

-- Called by XML
function SuperStar_SetSkillBuilderRace(raceId)

    SuperStarXMLSkillsPreSelector:GetNamedChild("Race" .. raceId):SetState(BSTATE_PRESSED, false)
    SuperStarSkills.race = raceId

    for button = 1, 10 do
        if button ~= raceId then
            SuperStarXMLSkillsPreSelector:GetNamedChild("Race" .. button):SetState(BSTATE_NORMAL, false)
        end
    end
end

-- Called by XML
function SuperStar_SkillBuilderPreselector_HoverClass(control, classId)
    InitializeTooltip(InformationTooltip, control, BOTTOM, 5, -5)
    InformationTooltip:AddLine(zo_strformat(SI_CLASS_NAME, GetClassName(GetUnitGender("player"), classId)))
end

-- Called by XML
function SuperStar_SkillBuilderPreselector_ExitClass()
    ClearTooltip(InformationTooltip)
end

-- Called by XML
function SuperStar_SkillBuilderPreselector_HoverRace(control, raceId)
    InitializeTooltip(InformationTooltip, control, BOTTOM, 5, -5)
    InformationTooltip:AddLine(zo_strformat(SI_CLASS_NAME, GetRaceName(GetUnitGender("player"), raceId)))
end

-- Called by XML
function SuperStar_SkillBuilderPreselector_ExitRace()
    ClearTooltip(InformationTooltip)
end

-- Called by XML
function SuperStar_SetSkillBuilderClass(classId)

    -- SuperStarXMLSkillsPreSelector:GetNamedChild("Class" .. classId):SetState(BSTATE_PRESSED, false)
    SuperStarSkills.class = classId
    -- Lykeion@v5.0.5 - addapt to Arcanist
    local arr = {1, 2, 3, 4, 5, 6, 117}
    for i = 1,#arr do
        local id = arr[i]
        if id ~= classId then
            -- SuperStarXMLSkillsPreSelector:GetNamedChild("Class" .. id):SetState(BSTATE_NORMAL, false)
        end
    end

    if SuperStarXMLSkillsPreSelectorStartBuild:IsHidden() == true then
        SuperStarXMLSkillsPreSelectorStartBuild:SetHidden(false)
    end
end

-- Called by XML
function SuperStar_StartSkillBuilder()

    if SuperStarSkills.class and SuperStarSkills.race then

        -- local displayedValue = SuperStarXMLSkillsPreSelector:GetNamedChild("SkillPoints"):GetNamedChild("Display")
        --     :GetText()

        local spentSkillPoints = 999

        -- SuperStarXMLSkillsPreSelector:GetNamedChild("SkillPoints"):GetNamedChild("Display")
        --     :SetText(spentSkillPoints)
        SuperStarSkills.spentSkillPoints = spentSkillPoints

        -- if displayedValue ~= "" then

        --     local spentSkillPoints = tonumber(displayedValue)
        --     local maxPoints = SP_MAX_SPENDABLE_POINTS

        --     if spentSkillPoints < 0 then
        --         spentSkillPoints = 0
        --     end
        --     if spentSkillPoints > maxPoints then
        --         spentSkillPoints = maxPoints
        --     end

        --     SuperStarXMLSkillsPreSelector:GetNamedChild("SkillPoints"):GetNamedChild("Display")
        --         :SetText(spentSkillPoints)
        --     SuperStarSkills.spentSkillPoints = spentSkillPoints

        -- else
        --     SuperStarXMLSkillsPreSelector:GetNamedChild("SkillPoints"):GetNamedChild("Display"):SetText(
        --         SuperStarSkills.availableSkillsPoints)
        --     SuperStarSkills.spentSkillPoints = SuperStarSkills.availableSkillsPoints
        --     SuperStarSkills.availableSkillsPointsForBuilder = SuperStarSkills.spentSkillPoints
        -- end

        LSF:Initialize(SuperStarSkills.class, SuperStarSkills.race)
        SUPERSTAR_SKILLS_SCENE:RemoveFragment(SUPERSTAR_SKILLS_PRESELECTORWINDOW)
        SUPERSTAR_SKILLS_SCENE:AddFragment(SUPERSTAR_SKILLS_BUILDERWINDOW)
    end

end

-- Called by XML
function SuperStar_ShowSkills(self)
    SUPERSTAR_SKILLS_WINDOW:OnShown()
end

local function InitSkills(control)
    SUPERSTAR_SKILLS_WINDOW = SuperStarSkills:New(control)
end

-- v5: rewrite the whole hash build, respec system
-- Blk: Hash Builder ===========================================================

local function FormatOn2BytesInBase62(base10Char) -- For cp hash building, return 2 bytes hash
    if base10Char < 62 then
        return "0" .. Base62(base10Char)
    else
        return Base62(base10Char)
    end
end

local function BuildChampionHash()

    local hash = zo_strformat("<<1>><<2>><<3>>", TAG_CP, REVISION_CP, MODE_CP) -- version tag
    local pointsSpentInTotal = 0

    if IsChampionSystemUnlocked() then

        for disciplineIndex = 1, GetNumChampionDisciplines() do
            for skillIndex = 1, GetNumChampionDisciplineSkills(disciplineIndex) do

                local pointsSpent = GetNumPointsSpentOnChampionSkill(GetChampionSkillId(disciplineIndex, skillIndex))
                hash = hash .. FormatOn2BytesInBase62(pointsSpent)
                pointsSpentInTotal = pointsSpentInTotal + pointsSpent

            end
            hash = hash .. Base62(CHAMPION_DISCIPLINE_DIVISION)
        end
    else
        hash = ""
    end

    return hash, pointsSpentInTotal

end

local function BuildLegitSkillsHash()

    local playerClassId = GetUnitClassId("player")
    local playerRaceId = GetUnitRaceId("player")
    local pointsSpentInTotal = 0
    local esoSkillLineId, lsfSkillLineIndex

    local hash = zo_strformat("<<1>><<2>><<3>>", TAG_SKILLS, REVISION_SKILLS, MODE_SKILLS) -- version tag

    -- skill types
    for skillType = 1, SKILLTYPES_IN_SKILLBUILDER do
        -- skill lines
        for skillLineIndex = 1, LSF:GetNumSkillLinesPerChar(skillType) do
            local pointsSpentInLine = 0
            local nextHash = ""

            -- let every skillline starts with a universal virtual index
            esoSkillLineId = GetSkillLineId(skillType, skillLineIndex)
            lsfSkillLineIndex = LSF:GetSkillLineLSFIndexFromSkillLineId(esoSkillLineId)
            if lsfSkillLineIndex then
                nextHash = nextHash .. Base62(skillType + SKILLTYPE_THRESHOLD) .. Base62(lsfSkillLineIndex)
            else -- A skillLine which is not yet handled. Abort
                return "", 0
            end

            -- Start building skill hash
            for abilityIndex = 1, GetNumSkillAbilities(skillType, skillLineIndex) do
                local name = GetSkillAbilityInfoSafe(skillType, skillLineIndex, abilityIndex)
                local isPassive, isUltimate, isPurchased, spentIn, morphChoice, passiveLevel, isCrafted =
                    GetSkillAbilityPurchaseInfo(skillType, skillLineIndex, abilityIndex) -- defined in the Skill Builder Block
                    
                    local blockCode

                    if isPassive then
                        blockCode = ABILITY_TYPE_PASSIVE_RANGE
                    elseif isUltimate then
                        blockCode = ABILITY_TYPE_ULTIMATE_RANGE
                    elseif isCrafted then
                        blockCode = ABILITY_TYPE_CRAFTED_RANGE
                    else
                        blockCode = ABILITY_TYPE_ACTIVE_RANGE
                    end

                    if isPurchased then
                        if isPassive then
                            blockCode = blockCode + passiveLevel
                        elseif isCrafted then
                            blockCode = blockCode
                        else
                            blockCode = blockCode + morphChoice + 1
                        end
                    end

                    pointsSpentInLine = pointsSpentInLine + spentIn

                    if blockCode == nil then
                        d(GetSkillAbilityId(skillType, skillLineIndex, abilityIndex, true))
                    else
                        nextHash = nextHash .. Base62(blockCode)
                    end
            end
            if pointsSpentInLine > 0 then
                -- d(string.format("[%d][%d] Name: %s (Purchased)", skillType, skillLineIndex, LSF:GetSkillLineInfo2(skillType, skillLineIndex)))
                pointsSpentInTotal = pointsSpentInTotal + pointsSpentInLine
                hash = hash .. nextHash
            end
        end

    end
    -- d(hash)
    return hash, pointsSpentInTotal
end

local function BuildBuilderSkillsHash()

    local classId = SuperStarSkills.class
    local raceId = SuperStarSkills.race
    local pointsSpentInTotal = 0
    local esoSkillLineId, lsfSkillLineIndex

    local hash = zo_strformat("<<1>><<2>><<3>>", TAG_SKILLS, REVISION_SKILLS, MODE_SKILLS) -- version tag

    -- skill types
    for skillType = 1, SKILLTYPES_IN_SKILLBUILDER do
        -- skill lines
        for skillLineIndex = 1, LSF:GetNumSkillLinesPerChar(skillType) do
            local pointsSpentInLine = 0
            local nextHash = ""

            -- let every skillline starts with a universal virtual index
            if skillType == SKILL_TYPE_CLASS then
                -- esoSkillLineId = LSF:GetSkillLineIdFromClass(classId, skillLineIndex)
                -- workaround for subclassing
                esoSkillLineId = LSF:GetSkillLineIdFromLSFIndex(SKILL_TYPE_CLASS, skillLineIndex)
            elseif skillType == SKILL_TYPE_RACIAL then
                esoSkillLineId = LSF:GetSkillLineIdFromRace(raceId)
            else
                esoSkillLineId = GetSkillLineId(skillType, skillLineIndex)
            end
            lsfSkillLineIndex = LSF:GetSkillLineLSFIndexFromSkillLineId(esoSkillLineId)
            if lsfSkillLineIndex then
                nextHash = nextHash .. Base62(skillType + SKILLTYPE_THRESHOLD) .. Base62(lsfSkillLineIndex)
            else -- A skillLine which is not yet handled. Abort
                return "", 0
            end

            -- Start building skill hash
            for abilityIndex = 1, LSF:GetNumSkillAbilities(skillType, skillLineIndex) do

                local spentIn = SuperStarSkills.builderFactory[skillType][skillLineIndex][abilityIndex].spentIn
                local abilityType = LSF:GetAbilityType(skillType, skillLineIndex, abilityIndex)
                local abilityLevel = SuperStarSkills.builderFactory[skillType][skillLineIndex][abilityIndex]
                                         .abilityLevel
                local blockCode

                if abilityType == ABILITY_TYPE_PASSIVE then
                    blockCode = ABILITY_TYPE_PASSIVE_RANGE
                elseif abilityType == ABILITY_TYPE_ULTIMATE then
                    blockCode = ABILITY_TYPE_ULTIMATE_RANGE
                elseif abilityType == ABILITY_TYPE_CRAFTED then
                    blockCode = ABILITY_TYPE_CRAFTED_RANGE
                else
                    blockCode = ABILITY_TYPE_ACTIVE_RANGE
                end

                if spentIn > 0 or LSF:IsSkillAbilityAutoGrant(skillType, skillLineIndex, abilityIndex) == 1 then

                    if abilityType == ABILITY_TYPE_CRAFTED then
                        blockCode = blockCode
                    elseif abilityType ~= ABILITY_TYPE_PASSIVE then
                        blockCode = blockCode + abilityLevel + 1
                    else
                        blockCode = blockCode + abilityLevel
                    end
                end

                pointsSpentInLine = pointsSpentInLine + spentIn

                if blockCode == nil then
                    d(GetSkillAbilityId(skillType, skillLineIndex, abilityIndex, true))
                else
                    nextHash = nextHash .. Base62(blockCode)
                end
            end
            if pointsSpentInLine > 0 then
                -- d(string.format("[%d][%d] Name: %s (Purchased)", skillType, skillLineIndex, LSF:GetSkillLineInfo2(skillType, skillLineIndex)))
                pointsSpentInTotal = pointsSpentInTotal + pointsSpentInLine
                hash = hash .. nextHash
            end
        end

    end
    -- d("hash: " .. hash)
    return hash, pointsSpentInTotal
end

local function BuildSkillsHash(skillsFromBuilder)

    if skillsFromBuilder then
        return BuildBuilderSkillsHash()
    else
        return BuildLegitSkillsHash()
    end

end

local function BuildAttributesHash()

    local attrMagicka = GetAttributeSpentPoints(ATTRIBUTE_MAGICKA)
    local attrHealth = GetAttributeSpentPoints(ATTRIBUTE_HEALTH)
    local attrStamina = GetAttributeSpentPoints(ATTRIBUTE_STAMINA)

    local formattedMagicka = FormatOn2BytesInBase62(attrMagicka)
    local formattedHealth = FormatOn2BytesInBase62(attrHealth)
    local formattedStamina = FormatOn2BytesInBase62(attrStamina)

    local hash = zo_strformat("<<1>><<2>><<3>><<4>><<5>>", TAG_ATTRIBUTES, REVISION_ATTRIBUTES, formattedMagicka,
        formattedHealth, formattedStamina)

    return hash, attrMagicka + attrHealth + attrStamina

end

local function BuildHashs(inclChampionSkills, includeSkills, includeAttributes, skillsFromBuilder)

    local CHash = ""
    local SHash = ""
    local AHash = ""
    local FHash = "" -- full hash

    local CRequired = 0
    local SRequired = 0
    local ARequired = 0

    if inclChampionSkills then
        CHash, CRequired = BuildChampionHash()
        FHash = FHash .. CHash
    end

    if includeSkills then
        SHash, SRequired = BuildSkillsHash(skillsFromBuilder)
        FHash = FHash .. SHash
    end

    if includeAttributes then
        AHash, ARequired = BuildAttributesHash()
        FHash = FHash .. AHash
    end

    return FHash, CRequired, SRequired, ARequired

end

local function RefreshImport(inclChampionSkills, includeSkills, includeAttributes)
    local hash = BuildHashs(inclChampionSkills, includeSkills, includeAttributes)
    SuperStarXMLImport:GetNamedChild("MyBuildValue"):GetNamedChild("Edit"):SetText(hash)
end

function SuperStar_ToggleImportAttr()

    if xmlIncludeAttributes then
        xmlIncludeAttributes = false
        SuperStarXMLImport:GetNamedChild("MyBuildIclAttr"):SetText(GetString(SUPERSTAR_IMPORT_ATTR_DISABLED))
    else
        xmlIncludeAttributes = true
        SuperStarXMLImport:GetNamedChild("MyBuildIclAttr"):SetText(GetString(SUPERSTAR_IMPORT_ATTR_ENABLED))
    end

    RefreshImport(xmlInclChampionSkills, xmlIncludeSkills, xmlIncludeAttributes)

end

function SuperStar_ToggleImportSP()

    if xmlIncludeSkills then
        xmlIncludeSkills = false
        SuperStarXMLImport:GetNamedChild("MyBuildIclSP"):SetText(GetString(SUPERSTAR_IMPORT_SP_DISABLED))
    else
        xmlIncludeSkills = true
        SuperStarXMLImport:GetNamedChild("MyBuildIclSP"):SetText(GetString(SUPERSTAR_IMPORT_SP_ENABLED))
    end

    RefreshImport(xmlInclChampionSkills, xmlIncludeSkills, xmlIncludeAttributes)

end

function SuperStar_ToggleImportCP()

    if xmlInclChampionSkills then
        xmlInclChampionSkills = false
        SuperStarXMLImport:GetNamedChild("MyBuildIclCP"):SetText(GetString(SUPERSTAR_IMPORT_CP_DISABLED))
    else
        xmlInclChampionSkills = true
        SuperStarXMLImport:GetNamedChild("MyBuildIclCP"):SetText(GetString(SUPERSTAR_IMPORT_CP_ENABLED))
    end

    RefreshImport(xmlInclChampionSkills, xmlIncludeSkills, xmlIncludeAttributes)

end

-- Blk: Parse the Hashs ========================================================

local function UpdateOlderSkillHash(hash, revision, mode)
    local newHash = hash
    local ver = revision
    local md = mode

    -- Armodeniz
    if ver == REVISION_SKILLS_GREYMOOR and md == '1' then
        newHash = newHash:gsub("@41", "@42")
        md = '2'
        -- Armour skills clear
        newHash = newHash:gsub("(Y1%w)(%w%w%w%w%w)", "%1GG%2")
        newHash = newHash:gsub("(Y2%w)(%w%w%w%w%w)", "%1G%2")
        newHash = newHash:gsub("(Y3%w)(%w%w%w%w%w)", "%1GG%2")
        if GetCVar("Language.2") == "fr" then
            -- Werewolf change 
            newHash = newHash:gsub("(Z3%w%w%w%w%w%w%w%w%w)(%w)(%w)", "%1%3%2")
            -- Vampire
            newHash = newHash:gsub("(Z6%w%w%w%w%w%w%w%w%w)(%w)(%w)", "%1%3%2")
            -- Assault change
            newHash = newHash:gsub("(b1%w)(%w%w)", "%188")
            -- Enchantment Food skill 
            newHash = newHash:gsub("d4(%w)(%w)", "d4%2%1")
            newHash = newHash:gsub("d6(%w)(%w)", "d6%2%1")
        elseif GetCVar("Language.2") == "de" then
            -- Werewolf change 
            newHash = newHash:gsub("(Z6%w%w%w%w%w%w%w%w%w)(%w)(%w)", "%1%3%2")
            -- Vampire
            newHash = newHash:gsub("(Z5%w%w%w%w%w%w%w%w%w)(%w)(%w)", "%1%3%2")
            -- Assault change
            newHash = newHash:gsub("(b2%w)(%w%w)", "%188")
            -- Enchantment Food skill 
            newHash = newHash:gsub("d7(%w)(%w)", "d7%2%1")
            newHash = newHash:gsub("d6(%w)(%w)", "d6%2%1")
        else
            -- Werewolf change 
            newHash = newHash:gsub("(Z6%w%w%w%w%w%w%w%w%w)(%w)(%w)", "%1%3%2")
            -- Vampire
            newHash = newHash:gsub("(Z5%w%w%w%w%w%w%w%w%w)(%w)(%w)", "%1%3%2")
            -- Assault change
            newHash = newHash:gsub("(b1%w)(%w%w)", "%188")
            -- Enchantment Food skill 
            newHash = newHash:gsub("d4(%w)(%w)", "d4%2%1")
            newHash = newHash:gsub("d6(%w)(%w)", "d6%2%1")
        end
    end

    if ver == REVISION_SKILLS_GREYMOOR and md == '2' then
        newHash = newHash:gsub("@42", "@43")
        md = '3'

        if GetCVar("Language.2") == "ru" then
            newHash = newHash:gsub("Z1", "e5")
            newHash = newHash:gsub("Z6", "Z1")
            newHash = newHash:gsub("Z2", "Z6")
            newHash = newHash:gsub("Z3", "Z2")
            newHash = newHash:gsub("Z4", "Z3")
            newHash = newHash:gsub("Z5", "Z4")
            newHash = newHash:gsub("e5", "Z5")

            newHash = newHash:gsub("a1", "e2")
            newHash = newHash:gsub("a6", "a1")
            newHash = newHash:gsub("a4", "a6")
            newHash = newHash:gsub("a5", "a4")
            newHash = newHash:gsub("a2", "a5")
            newHash = newHash:gsub("e2", "a2")

            newHash = newHash:gsub("b1", "e2")
            newHash = newHash:gsub("b3", "b1")
            newHash = newHash:gsub("b2", "b3")
            newHash = newHash:gsub("e2", "b2")

            newHash = newHash:gsub("d2", "e4")
            newHash = newHash:gsub("d4", "d2")
            newHash = newHash:gsub("e4", "d4")
            newHash = newHash:gsub("d3", "e5")
            newHash = newHash:gsub("d5", "d3")
            newHash = newHash:gsub("e5", "d5")
            newHash = newHash:gsub("d6", "e7")
            newHash = newHash:gsub("d7", "d6")
            newHash = newHash:gsub("e7", "d7")

        elseif GetCVar("Language.2") == "de" then
            newHash = newHash:gsub("Z3", "e4")
            newHash = newHash:gsub("Z4", "Z3")
            newHash = newHash:gsub("e4", "Z4")

            newHash = newHash:gsub("a1", "e5")
            newHash = newHash:gsub("a2", "a1")
            newHash = newHash:gsub("a3", "a2")
            newHash = newHash:gsub("a4", "a3")
            newHash = newHash:gsub("a5", "a4")
            newHash = newHash:gsub("e5", "a5")

            newHash = newHash:gsub("b1", "e2")
            newHash = newHash:gsub("b2", "b1")
            newHash = newHash:gsub("e2", "b2")

            newHash = newHash:gsub("d2", "e5")
            newHash = newHash:gsub("d4", "d2")
            newHash = newHash:gsub("d7", "d4")
            newHash = newHash:gsub("d5", "d7")
            newHash = newHash:gsub("e5", "d5")
            newHash = newHash:gsub("d3", "e6")
            newHash = newHash:gsub("d6", "d3")
            newHash = newHash:gsub("e6", "d6")

        elseif GetCVar("Language.2") == "fr" then
            newHash = newHash:gsub("Z1", "e2")
            newHash = newHash:gsub("Z2", "Z1")
            newHash = newHash:gsub("e2", "Z2")
            newHash = newHash:gsub("Z3", "e6")
            newHash = newHash:gsub("Z5", "Z3")
            newHash = newHash:gsub("Z6", "Z5")
            newHash = newHash:gsub("e6", "Z6")

            newHash = newHash:gsub("a4", "e5")
            newHash = newHash:gsub("a6", "a4")
            newHash = newHash:gsub("a5", "a6")
            newHash = newHash:gsub("e4", "a4")

        else
            newHash = newHash:gsub("d2", "e5")
            newHash = newHash:gsub("d3", "d2")
            newHash = newHash:gsub("d6", "d3")
            newHash = newHash:gsub("d5", "d6")
            newHash = newHash:gsub("e5", "d5")
        end
    end
    if ver == REVISION_SKILLS_GREYMOOR and md == '3' then
        newHash = newHash:gsub("@43", "@51")
        ver = REVISION_SKILLS_BLACKWOOD
        md = '1'
    end

    return newHash
end

local function ParseAttrHash(hash)

    local VALID_ATTR_TAG = TAG_ATTRIBUTES .. REVISION_ATTRIBUTES
    local VALID_ATTR_LEN = 8

    if string.sub(hash, 1, 2) ~= VALID_ATTR_TAG then
        return false
    end
    if string.len(hash) ~= VALID_ATTR_LEN then
        return false
    end

    local AttrMagick = Base62(string.sub(hash, 3, 4))
    local AttrHealth = Base62(string.sub(hash, 5, 6))
    local AttrStamin = Base62(string.sub(hash, 7, 8))

    if type(AttrMagick) ~= "number" or type(AttrHealth) ~= "number" or type(AttrStamin) ~= "number" then
        return false
    elseif AttrMagick + AttrHealth + AttrStamin > ATTR_MAX_SPENDABLE_POINTS then
        return false
    end

    return {
        magick = AttrMagick,
        health = AttrHealth,
        stam = AttrStamin,
        pointsRequired = AttrMagick + AttrHealth + AttrStamin
    }
end

local function ParseSkillsHash(hash)

    local VALID_SKILLS_TAG = TAG_SKILLS .. REVISION_SKILLS .. MODE_SKILLS

    if string.sub(hash, 1, 3) ~= VALID_SKILLS_TAG then
        return false
    end -- check version

    local skillData

    local classId = GetUnitClassId("player")
    local raceId = GetUnitRaceId("player")

    skillData = SuperStarSkills:InitSkillsFactory()
    skillData.pointsRequired = 0

    local needToParse = true
    local nextBlockIdx = 4
    local skillType, skillLineIndex, skillLineId, abilityIndex, numSkillLines, numAbilities

    local nextIsSkillType = true
    local nextIsSkillLine = false

    local nextIsClass = false
    local nextIsRace = false

    while needToParse do

        local blockToCheck = string.sub(hash, nextBlockIdx, nextBlockIdx)
        nextBlockIdx = nextBlockIdx + 1

        if blockToCheck ~= "" then

            local decimalBlock = Base62(blockToCheck)

            if nextIsSkillType then
                nextIsSkillType = false

                -- Only 32/39 range is defined for now
                if decimalBlock < (SKILLTYPE_THRESHOLD + SKILL_TYPE_CLASS) or decimalBlock >
                    (SKILLTYPE_THRESHOLD + SKILL_TYPE_TRADESKILL) then
                    -- d(string.format("[ERROR] Block out of range -- block: %s, index: %u", blockToCheck, nextBlockIdx-1))
                    return false
                end

                if decimalBlock == (SKILLTYPE_THRESHOLD + SKILL_TYPE_CLASS) then
                    nextIsClass = true
                elseif decimalBlock == (SKILLTYPE_THRESHOLD + SKILL_TYPE_RACIAL) then
                    nextIsRace = true
                else
                    nextIsSkillLine = true
                end

                skillType = decimalBlock - SKILLTYPE_THRESHOLD
                -- d("========")

            elseif nextIsClass then
                nextIsClass = false
                if decimalBlock < 1 or decimalBlock > 21 then -- out of range of classid
                    d("false2")
                    return false
                end
                if decimalBlock <= 3 then
                    skillLineIndex = decimalBlock
                    classId = CLASS_DRAGONKNIGHT
                elseif decimalBlock <= 6 then
                    skillLineIndex = decimalBlock
                    classId = CLASS_SORCERER
                elseif decimalBlock <= 9 then
                    skillLineIndex = decimalBlock
                    classId = CLASS_NIGHTBLADE
                elseif decimalBlock <= 12 then
                    skillLineIndex = decimalBlock
                    classId = CLASS_TEMPLAR
                elseif decimalBlock <= 15 then
                    skillLineIndex = decimalBlock 
                    classId = CLASS_WARDEN
                elseif decimalBlock <= 18 then
                    -- @sigo:21MAY2019:Elsweyr update 22 - Added support for Necromancer class
                    skillLineIndex = decimalBlock
                    classId = CLASS_NECROMANCER
                else
                    -- @Lykeion:2023 June:Necrom update 38 - Added support for Arcanist class
                    skillLineIndex = decimalBlock
                    classId = CLASS_ARCANIST
                end

                skillData[skillType][skillLineIndex].skillLineId =
                    LSF:GetSkillLineIdFromLSFIndex(skillType, decimalBlock)
                numAbilities = LSF:GetNumSkillAbilitiesFromLSFIndex(skillType, skillLineIndex)
                abilityIndex = 1
                -- d(skillLineIndex)

            elseif nextIsRace then
                nextIsRace = false

                if decimalBlock < 1 or decimalBlock > MAX_PLAYABLE_RACES then
                    d("false3")
                    return false
                end

                raceId = decimalBlock
                skillLineIndex = 1
                skillData[skillType][skillLineIndex].skillLineId =
                    LSF:GetSkillLineIdFromLSFIndex(skillType, decimalBlock)
                numAbilities = LSF:GetNumSkillAbilities(skillType, skillLineIndex)
                abilityIndex = 1

            elseif nextIsSkillLine then
                nextIsSkillLine = false

                -- local numSkillLines = LSF:GetNumSkillLines(skillType)
                local numSkillLines = LSF:GetNumSkillLinesPerChar(skillType)
                -- Invalid skillLine
                if decimalBlock < 1 or decimalBlock > numSkillLines then
                    d("false4")
                    return false
                end

                skillLineId = LSF:GetSkillLineIdFromLSFIndex(skillType, decimalBlock) -- identify the skill line
                _, skillLineIndex = GetSkillLineIndicesFromSkillLineId(skillLineId)
                numAbilities = LSF:GetNumSkillAbilities(skillType, skillLineIndex)
                skillData[skillType][skillLineIndex].skillLineId = skillLineId
                abilityIndex = 1
                -- d(skillLineIndex)
            else
                local correctType, maxLevel = LSF:GetAbilityType(skillType, skillLineIndex, abilityIndex)
                local abilityLevel, spentIn
                local abilityId

                if decimalBlock > SKILLTYPE_THRESHOLD then
                    return false -- out of range
                elseif decimalBlock >= ABILITY_TYPE_PASSIVE_RANGE and correctType == ABILITY_TYPE_PASSIVE then
                    -- Passive ability
                    abilityLevel = decimalBlock - ABILITY_TYPE_PASSIVE_RANGE
                    if maxLevel and abilityLevel > maxLevel then
                        d("false6" .. skillType .. skillLineIndex .. abilityIndex)
                        return false
                    end
                    spentIn = abilityLevel
                    -- abilityId = LSF:GetAbilityId(skillType, skillLineIndex, abilityIndex, 1)
                elseif decimalBlock >= ABILITY_TYPE_CRAFTED_RANGE and correctType == ABILITY_TYPE_CRAFTED then
                    -- Crafted Ability
                    abilityLevel = 1
                    spentIn = 0
                    -- abilityId = LSF:GetAbilityId(skillType, skillLineIndex, abilityIndex, abilityLevel)
                elseif decimalBlock >= ABILITY_TYPE_ACTIVE_RANGE and correctType == ABILITY_TYPE_ACTIVE then
                    -- Active Ability
                    abilityLevel = math.max(decimalBlock - ABILITY_TYPE_ACTIVE_RANGE - 1, 0)
                    spentIn = math.min(decimalBlock - ABILITY_TYPE_ACTIVE_RANGE, 2)
                    -- abilityId = LSF:GetAbilityId(skillType, skillLineIndex, abilityIndex, abilityLevel)

                elseif decimalBlock >= ABILITY_TYPE_ULTIMATE_RANGE and correctType == ABILITY_TYPE_ULTIMATE then
                    -- Ultimate Ability
                    abilityLevel = math.max(decimalBlock - ABILITY_TYPE_ULTIMATE_RANGE - 1, 0)
                    spentIn = math.min(decimalBlock - ABILITY_TYPE_ULTIMATE_RANGE, 2)
                    -- abilityId = LSF:GetAbilityId(skillType, skillLineIndex, abilityIndex, abilityLevel)
                else
                    -- d("false7")
                    d(GetString(SUPERSTAR_CHATBOX_TEMPLATE_OUTDATED))
                    return false -- out of range
                end

                spentIn = spentIn - LSF:IsSkillAbilityAutoGrant(skillType, skillLineIndex, abilityIndex)

                skillData[skillType][skillLineIndex][abilityIndex].spentIn = spentIn
                skillData[skillType][skillLineIndex][abilityIndex].abilityLevel = abilityLevel
                skillData[skillType][skillLineIndex].pointsSpent =
                    skillData[skillType][skillLineIndex].pointsSpent + spentIn
                skillData.pointsRequired = skillData.pointsRequired + spentIn

                if abilityIndex < numAbilities then
                    -- Next is another ability
                    abilityIndex = abilityIndex + 1
                else
                    nextIsSkillType = true
                    -- d(skillData.pointsRequired)
                end

            end
        elseif not nextIsSkillType then -- tha hash need to be ended with nextIsSkillType, and the hash is not complete
            return false
        else
            needToParse = false
        end

    end
    -- d(skillData.pointsRequired)

    skillData.classId = classId
    skillData.raceId = raceId

    return skillData
end

local function ParseCPHash(hash)

    local VALID_CP_TAG = TAG_CP .. REVISION_CP .. MODE_CP
    local VALID_HASH_LEN = 201

    if string.sub(hash, 1, 3) ~= VALID_CP_TAG then
        return false
    end -- check hash version
    -- if string.len(hash) ~= VALID_HASH_LEN then return false end -- check hash length

    local startPos = 4
    local pointsSpent
    local cpData = {}
    cpData.pointsRequired = 0

    for disciplineIndex = 1, GetNumChampionDisciplines() do
        cpData[disciplineIndex] = {}
        local numSkills = GetNumChampionDisciplineSkills(disciplineIndex)
        for skillIndex = 1, numSkills + 1 do

            pointsSpent = Base62(string.sub(hash, startPos, startPos + 1))

            if pointsSpent == CHAMPION_DISCIPLINE_DIVISION then
                startPos = startPos + 2
                break
            elseif skillIndex == numSkills + 1 then
                break
            end

            if type(pointsSpent) == "number" and pointsSpent <= CP_MAX_SPENDABLE_POINTS then
                cpData[disciplineIndex][skillIndex] = pointsSpent
                cpData.pointsRequired = cpData.pointsRequired + pointsSpent
            else
                cpData = nil
                d(disciplineIndex .. "-" .. skillIndex .. "-" .. pointsSpent)
                return false -- the hash is wrong
            end
            startPos = startPos + 2

        end
    end

    return cpData

end

local function CheckImportedBuild(build)

    local hasAttr = string.find(build, TAG_ATTRIBUTES)
    local hasSkills = string.find(build, TAG_SKILLS)
    local hasCP = string.find(build, "%%") -- special char for gsub (TAG_CP)

    local hashAttr = ""
    local hashSkills = ""
    local hashCP = ""

    if hasAttr then
        hashAttr = string.sub(build, hasAttr)
    end

    if hasSkills then
        if hasAttr then
            hashSkills = string.sub(build, hasSkills, hasAttr - 1)
        else
            hashSkills = string.sub(build, hasSkills)
        end
    end

    if hasCP then
        if hasSkills then
            hashCP = string.sub(build, 1, hasSkills - 1)
        elseif hasAttr then
            hashCP = string.sub(build, 1, hasAttr - 1)
        else
            hashCP = build
        end
    end

    local attrData, skillsData, cpData

    if hasAttr or hasSkills or hasCP then

        attrData = true
        skillsData = true
        cpData = true

        if hasAttr and hashAttr then
            attrData = ParseAttrHash(hashAttr)
        end

        if hasSkills and hashSkills then
            skillsData = ParseSkillsHash(hashSkills)
        end

        if hasCP and hashCP then
            cpData = ParseCPHash(hashCP)
        end

    end

    return attrData, skillsData, cpData

end

local function UpdateHashDataContainer(attrData, skillsData, cpData)

    if not attrData and not skillsData and not cpData then
        SuperStarXMLImport:GetNamedChild("Container"):SetHidden(true)
        SuperStarXMLImport:GetNamedChild("ImportSeeBuild"):SetText(GetString(SUPERSTAR_IMPORT_BUILD_NOK))
        SuperStarXMLImport:GetNamedChild("ImportSeeBuild"):SetState(BSTATE_DISABLED, true)
    else

        isImportedBuildValid = true

        SuperStarXMLImport:GetNamedChild("Container"):SetHidden(false)

        if attrData then
            if type(attrData) == "boolean" then

                local MagickaAttributeLabel = SuperStarXMLImportHashData:GetNamedChild("MagickaAttributeLabel")
                local HealthAttributeLabel = SuperStarXMLImportHashData:GetNamedChild("HealthAttributeLabel")
                local StaminaAttributeLabel = SuperStarXMLImportHashData:GetNamedChild("StaminaAttributeLabel")

                MagickaAttributeLabel:SetText(SUPERSTAR_GENERIC_NA)
                HealthAttributeLabel:SetText(SUPERSTAR_GENERIC_NA)
                StaminaAttributeLabel:SetText(SUPERSTAR_GENERIC_NA)

            else

                local MagickaAttributeLabel = SuperStarXMLImportHashData:GetNamedChild("MagickaAttributeLabel")
                local HealthAttributeLabel = SuperStarXMLImportHashData:GetNamedChild("HealthAttributeLabel")
                local StaminaAttributeLabel = SuperStarXMLImportHashData:GetNamedChild("StaminaAttributeLabel")

                MagickaAttributeLabel:SetText(attrData.magick)
                HealthAttributeLabel:SetText(attrData.health)
                StaminaAttributeLabel:SetText(attrData.stam)

            end
        end

        if skillsData then
            if type(skillsData) == "boolean" then
                local SkillPointsValue = SuperStarXMLImportHashData:GetNamedChild("SkillPointsValue")
                SkillPointsValue:SetText(SUPERSTAR_GENERIC_NA)

                SuperStarXMLImport:GetNamedChild("ImportSeeBuild"):SetText(GetString(SUPERSTAR_IMPORT_BUILD_NO_SKILLS))
                SuperStarXMLImport:GetNamedChild("ImportSeeBuild"):SetState(BSTATE_DISABLED, true)

            else

                local SkillPointsValue = SuperStarXMLImportHashData:GetNamedChild("SkillPointsValue")
                SkillPointsValue:SetText(skillsData.pointsRequired)

                SuperStarXMLImport:GetNamedChild("ImportSeeBuild"):SetText(GetString(SUPERSTAR_IMPORT_BUILD_OK))
                SuperStarXMLImport:GetNamedChild("ImportSeeBuild"):SetState(BSTATE_NORMAL, true)

            end
        end
        -- Armodeniz
        local ACTION_BAR_DISCIPLINE_TEXTURES = {
            [CHAMPION_DISCIPLINE_TYPE_COMBAT] = {
                border = "EsoUI/Art/Champion/ActionBar/champion_bar_slot_frame.dds",
                selected = "EsoUI/Art/Champion/ActionBar/champion_bar_combat_selection.dds",
                slotted = "EsoUI/Art/Champion/ActionBar/champion_bar_combat_slotted.dds",
                empty = "EsoUI/Art/Champion/ActionBar/champion_bar_combat_empty.dds",
                disabled = "EsoUI/Art/Champion/ActionBar/champion_bar_slot_frame_disabled.dds",
                points = "esoui/art/champion/champion_points_magicka_icon.dds"
            },
            [CHAMPION_DISCIPLINE_TYPE_CONDITIONING] = {
                border = "EsoUI/Art/Champion/ActionBar/champion_bar_slot_frame.dds",
                selected = "EsoUI/Art/Champion/ActionBar/champion_bar_conditioning_selection.dds",
                slotted = "EsoUI/Art/Champion/ActionBar/champion_bar_conditioning_slotted.dds",
                empty = "EsoUI/Art/Champion/ActionBar/champion_bar_conditioning_empty.dds",
                disabled = "EsoUI/Art/Champion/ActionBar/champion_bar_slot_frame_disabled.dds",
                points = "esoui/art/champion/champion_points_health_icon.dds"
            },
            [CHAMPION_DISCIPLINE_TYPE_WORLD] = {
                border = "EsoUI/Art/Champion/ActionBar/champion_bar_slot_frame.dds",
                selected = "EsoUI/Art/Champion/ActionBar/champion_bar_world_selection.dds",
                slotted = "EsoUI/Art/Champion/ActionBar/champion_bar_world_slotted.dds",
                empty = "EsoUI/Art/Champion/ActionBar/champion_bar_world_empty.dds",
                disabled = "EsoUI/Art/Champion/ActionBar/champion_bar_slot_frame_disabled.dds",
                points = "esoui/art/champion/champion_points_stamina_icon.dds"
            }
        }
        if cpData then
            if type(cpData) ~= "boolean" then
                local VIRTUALNAME = "SuperStarChampionSkillFrame"
                local disciplineIndex
                for disciplineIndex = 1, GetNumChampionDisciplines() do
                    local Discipline = SuperStarXMLImportHashData:GetNamedChild("Discipline" .. disciplineIndex)
                    local DisType = GetChampionDisciplineType(disciplineIndex)
                    local TextureSlot = ACTION_BAR_DISCIPLINE_TEXTURES[DisType].slotted
                    local TextureSelect = ACTION_BAR_DISCIPLINE_TEXTURES[DisType].selected
                    Discipline:GetNamedChild("Name"):SetText(GetChampionDisciplineName(disciplineIndex))
                    Discipline:GetNamedChild("Icon"):SetTexture(ACTION_BAR_DISCIPLINE_TEXTURES[DisType].points)
                    Discipline:GetNamedChild("Points"):SetText(GetNumSpentChampionPoints(disciplineIndex))
                    local CSkillId
                    local CSkillName
                    local CSkillPoint
                    local CSkillAnchor = ZO_Anchor:New(TOPLEFT, Discipline, TOPLEFT, 0, 0)
                    local NumChampionSkillActivated = 0
                    local NumChampionSkill = GetNumChampionDisciplineSkills(math.mod(disciplineIndex, 3) + 1)
                    if NumChampionSkill > 0 then
                        -- Searching for nonslotable CP
                        for CSkillIndex = 1, NumChampionSkill do
                            if NumChampionSkillActivated > 17 then
                                break
                            end
                            local windowName = VIRTUALNAME .. disciplineIndex .. "of" .. (NumChampionSkillActivated + 1)
                            local CSkillFrame = GetControl(windowName)
                            if not CSkillFrame then
                                CSkillFrame = CreateControlFromVirtual(windowName, Discipline, VIRTUALNAME)
                            end
                            CSkillFrame:SetHidden(true)
                            CSkillId = GetChampionSkillId(math.mod(disciplineIndex, 3) + 1, CSkillIndex)
                            CSkillPoint = cpData[math.mod(disciplineIndex, 3) + 1][CSkillIndex]
                            if CSkillPoint > 0 then
                                CSkillName = zo_strformat(SI_CHAMPION_STAR_NAME, GetChampionSkillName(CSkillId))
                                CSkillAnchor:SetOffsets(math.mod(NumChampionSkillActivated, 2) * 150,
                                    25 + math.floor(NumChampionSkillActivated / 2) * 25)

                                NumChampionSkillActivated = NumChampionSkillActivated + 1
                                CSkillAnchor:Set(CSkillFrame)
                                CSkillFrame:SetHidden(false)
                                CSkillFrame.cSkillId = CSkillId
                                CSkillFrame:GetNamedChild("Name"):SetText(CSkillName)
                                CSkillFrame:GetNamedChild("Value"):SetText(CSkillPoint)
                                CSkillFrame:GetNamedChild("Star"):SetHidden(true)
                                CSkillFrame:GetNamedChild("StarBorder"):SetHidden(true)
                                CSkillFrame:GetNamedChild("StarSelect"):SetHidden(true)
                            end
                        end
                    end
                end

            end
        end

    end

    KEYBIND_STRIP:UpdateKeybindButtonGroup(SUPERSTAR_IMPORT_WINDOW.importKeybindStripDescriptor)

end

-- Lykeion@6.0.0
local function hideChildrenControls(control, startIndex)
    local index = startIndex or 1
    while control:GetChild(index) ~= nil do
        local child = control:GetChild(index)
        child:SetHidden(true)
        index = index + 1
    end
end

local function renderSidebar(index)
    local sidebar = GetControl("SuperStarXMLScribingSidebar")
    if index == SIDEBAR_INDEX_HISTORY then
        GetControl("SuperStarXMLScribingSidebarHistory"):SetMouseEnabled(false)
        GetControl("SuperStarXMLScribingSidebarFavorites"):SetMouseEnabled(true)

        CALLBACK_MANAGER:FireCallbacks("SuperStarExistPickedFavorites", false)
        if #pickedHistory > 0 then
            CALLBACK_MANAGER:FireCallbacks("SuperStarExistPickedHistory", true)
        end
        
        hideChildrenControls(sidebar:GetNamedChild("List"))
        sidebar:GetNamedChild("Icon"):SetTexture("esoui/art/tradinghouse/tradinghouse_racial_style_motif_book_up.dds")
        sidebar:GetNamedChild("Title"):SetText(GetString(SI_WINDOW_TITLE_GUILD_HISTORY))

        sidebar:GetNamedChild("History"):GetNamedChild("Text"):SetColor(ZO_SELECTED_TEXT:UnpackRGBA())
        sidebar:GetNamedChild("History"):GetNamedChild("Divider"):SetHidden(false)
        sidebar:GetNamedChild("Favorites"):GetNamedChild("Text"):SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
        sidebar:GetNamedChild("Favorites"):GetNamedChild("Divider"):SetHidden(true)

        sidebar:GetNamedChild("Spinner"):SetHidden(true)
        -- render history in reverted order
        for i = #db.historyScribed, 1, -1 do
            local VIRTUALNAME = "SuperStarScribingHistory"
            -- Build up crafted ability info
            local windowName = VIRTUALNAME .. i
            local CurrentFrame = GetControl(windowName)
            if not CurrentFrame then
                -- CreateControlFromVirtual(controlName, parent, templateName)
                CurrentFrame = CreateControlFromVirtual(windowName, SuperStarXMLScribingSidebarList, VIRTUALNAME)
            end
            CurrentFrame:SetHidden(false)

            if CurrentFrame.picked then
                CurrentFrame:GetNamedChild("Highlight"):SetAlpha(1)
            end

            CurrentFrame[SCRIBING_SLOT_NONE] = db.historyScribed[i][SCRIBING_SLOT_NONE]
            CurrentFrame[SCRIBING_SLOT_PRIMARY] = db.historyScribed[i][SCRIBING_SLOT_PRIMARY]
            CurrentFrame[SCRIBING_SLOT_SECONDARY] = db.historyScribed[i][SCRIBING_SLOT_SECONDARY]
            CurrentFrame[SCRIBING_SLOT_TERTIARY] = db.historyScribed[i][SCRIBING_SLOT_TERTIARY]
            CurrentFrame:GetNamedChild("Icon"):SetTexture(GetCraftedAbilityDisplayIcon(db.historyScribed[i][SCRIBING_SLOT_NONE]))

            CurrentFrame:GetNamedChild("MainText"):SetText(GetCraftedAbilityDisplayName(db.historyScribed[i][SCRIBING_SLOT_NONE]))
            CurrentFrame:GetNamedChild("SubText"):SetText(GetCraftedAbilityScriptDisplayName(db.historyScribed[i][SCRIBING_SLOT_PRIMARY]) .. " / " ..
                                                        GetCraftedAbilityScriptDisplayName(db.historyScribed[i][SCRIBING_SLOT_SECONDARY]) .. " / " ..
                                                        GetCraftedAbilityScriptDisplayName(db.historyScribed[i][SCRIBING_SLOT_TERTIARY]))
            if not IsCraftedAbilityUnlocked(CurrentFrame[SCRIBING_SLOT_NONE]) or 
            not IsCraftedAbilityScriptUnlocked(CurrentFrame[SCRIBING_SLOT_PRIMARY]) or 
            not IsCraftedAbilityScriptUnlocked(CurrentFrame[SCRIBING_SLOT_SECONDARY]) or 
            not IsCraftedAbilityScriptUnlocked(CurrentFrame[SCRIBING_SLOT_TERTIARY]) then
                CurrentFrame:GetNamedChild("Lock"):SetHidden(false)
            else
                CurrentFrame:GetNamedChild("Lock"):SetHidden(true)
            end

            local CurrentAnchor = ZO_Anchor:New(TOPLEFT, SuperStarXMLScribingSidebarList, BOTTOMLEFT, 0, (#db.historyScribed - i) * 60)
            CurrentAnchor:Set(CurrentFrame)
            CurrentFrame:SetHidden(false)
            CurrentFrame:SetAlpha(0.001)
            CurrentFrame.anim = ANIMATION_MANAGER:CreateTimeline()
            CurrentFrame.anim.alpha = CurrentFrame.anim:InsertAnimation( ANIMATION_ALPHA, CurrentFrame, (#db.historyScribed - i) * 30 )
            CurrentFrame.anim.alpha:SetDuration(300)
            CurrentFrame.anim.alpha:SetEasingFunction(ZO_EaseOutQuintic)
            CurrentFrame.anim.alpha:SetAlphaValues(CurrentFrame:GetAlpha(), 1)
            CurrentFrame.anim:PlayFromStart()
        end
    elseif index == SIDEBAR_INDEX_FAVORITE then
        GetControl("SuperStarXMLScribingSidebarFavorites"):SetMouseEnabled(false)
        GetControl("SuperStarXMLScribingSidebarHistory"):SetMouseEnabled(true)

        CALLBACK_MANAGER:FireCallbacks("SuperStarExistPickedHistory", false)
        if #pickedFavorites > 0 then
            CALLBACK_MANAGER:FireCallbacks("SuperStarExistPickedFavorites", true)
        end
 
        hideChildrenControls(sidebar:GetNamedChild("List"))
        sidebar:GetNamedChild("Icon"):SetTexture("esoui/art/tradinghouse/tradinghouse_trophy_treasure_map_up.dds")
        sidebar:GetNamedChild("Title"):SetText(GetString(SI_COLLECTIONS_FAVORITES_CATEGORY_HEADER))

        sidebar:GetNamedChild("Favorites"):GetNamedChild("Text"):SetColor(ZO_SELECTED_TEXT:UnpackRGBA())
        sidebar:GetNamedChild("Favorites"):GetNamedChild("Divider"):SetHidden(false)
        sidebar:GetNamedChild("History"):GetNamedChild("Text"):SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
        sidebar:GetNamedChild("History"):GetNamedChild("Divider"):SetHidden(true)

        local maxPage = math.ceil(#db.favoriteScribed / SIDEBAR_SKILL_MAX)
        if maxPage == 0 then
            maxPage = 1
        end
        -- render spinner
        if maxPage == 1 then
            sidebar:GetNamedChild("Spinner"):SetHidden(true)
        elseif SIDEBAR_FAV_PAGE == 1 then
            sidebar:GetNamedChild("Spinner"):SetHidden(false)
            sidebar:GetNamedChild("Spinner"):GetNamedChild("PageNum"):SetText(SIDEBAR_FAV_PAGE)
            sidebar:GetNamedChild("Spinner"):GetNamedChild("Left"):SetState(BSTATE_DISABLED, true)
            sidebar:GetNamedChild("Spinner"):GetNamedChild("Right"):SetState(BSTATE_NORMAL, false)
        elseif SIDEBAR_FAV_PAGE == maxPage then
            sidebar:GetNamedChild("Spinner"):SetHidden(false)
            sidebar:GetNamedChild("Spinner"):GetNamedChild("PageNum"):SetText(SIDEBAR_FAV_PAGE)
            sidebar:GetNamedChild("Spinner"):GetNamedChild("Left"):SetState(BSTATE_NORMAL, false)
            sidebar:GetNamedChild("Spinner"):GetNamedChild("Right"):SetState(BSTATE_DISABLED, true)
        else
            sidebar:GetNamedChild("Spinner"):SetHidden(false)
            sidebar:GetNamedChild("Spinner"):GetNamedChild("PageNum"):SetText(SIDEBAR_FAV_PAGE)
            sidebar:GetNamedChild("Spinner"):GetNamedChild("Left"):SetState(BSTATE_NORMAL, false)
            sidebar:GetNamedChild("Spinner"):GetNamedChild("Right"):SetState(BSTATE_NORMAL, false)
        end


        -- render favorite
        for i = (SIDEBAR_FAV_PAGE - 1) * SIDEBAR_SKILL_MAX + 1, SIDEBAR_FAV_PAGE * SIDEBAR_SKILL_MAX, 1 do    
            if db.favoriteScribed[i] then
                local VIRTUALNAME = "SuperStarScribingFavorite"
                -- Build up crafted ability info
                local windowName = VIRTUALNAME .. i
                local CurrentFrame = GetControl(windowName)
                if not CurrentFrame then
                    -- CreateControlFromVirtual(controlName, parent, templateName)
                    CurrentFrame = CreateControlFromVirtual(windowName, SuperStarXMLScribingSidebarList, VIRTUALNAME)
                end
                CurrentFrame:SetHidden(false)

                CurrentFrame[SCRIBING_SLOT_NONE] = db.favoriteScribed[i][SCRIBING_SLOT_NONE]
                CurrentFrame[SCRIBING_SLOT_PRIMARY] = db.favoriteScribed[i][SCRIBING_SLOT_PRIMARY]
                CurrentFrame[SCRIBING_SLOT_SECONDARY] = db.favoriteScribed[i][SCRIBING_SLOT_SECONDARY]
                CurrentFrame[SCRIBING_SLOT_TERTIARY] = db.favoriteScribed[i][SCRIBING_SLOT_TERTIARY]
                CurrentFrame:GetNamedChild("Icon"):SetTexture(GetCraftedAbilityDisplayIcon(db.favoriteScribed[i][SCRIBING_SLOT_NONE]))

                CurrentFrame:GetNamedChild("MainText"):SetText(GetCraftedAbilityDisplayName(db.favoriteScribed[i][SCRIBING_SLOT_NONE]))
                CurrentFrame:GetNamedChild("SubText"):SetText(GetCraftedAbilityScriptDisplayName(db.favoriteScribed[i][SCRIBING_SLOT_PRIMARY]) .. " / " ..
                                                            GetCraftedAbilityScriptDisplayName(db.favoriteScribed[i][SCRIBING_SLOT_SECONDARY]) .. " / " ..
                                                            GetCraftedAbilityScriptDisplayName(db.favoriteScribed[i][SCRIBING_SLOT_TERTIARY]))
                if not IsCraftedAbilityUnlocked(CurrentFrame[SCRIBING_SLOT_NONE]) or 
                not IsCraftedAbilityScriptUnlocked(CurrentFrame[SCRIBING_SLOT_PRIMARY]) or 
                not IsCraftedAbilityScriptUnlocked(CurrentFrame[SCRIBING_SLOT_SECONDARY]) or 
                not IsCraftedAbilityScriptUnlocked(CurrentFrame[SCRIBING_SLOT_TERTIARY]) then
                    CurrentFrame:GetNamedChild("Lock"):SetHidden(false)
                else
                    CurrentFrame:GetNamedChild("Lock"):SetHidden(true)
                end

                local CurrentAnchor = ZO_Anchor:New(TOPLEFT, SuperStarXMLScribingSidebarList, BOTTOMLEFT, 0, (i - ((SIDEBAR_FAV_PAGE - 1) * SIDEBAR_SKILL_MAX + 1)) * 60)
                CurrentAnchor:Set(CurrentFrame)
                CurrentFrame:SetHidden(false)
                CurrentFrame:SetAlpha(0.001)
                CurrentFrame.anim = ANIMATION_MANAGER:CreateTimeline()
                CurrentFrame.anim.alpha = CurrentFrame.anim:InsertAnimation( ANIMATION_ALPHA, CurrentFrame, (i - ((SIDEBAR_FAV_PAGE - 1) * SIDEBAR_SKILL_MAX + 1)) * 30 )
                CurrentFrame.anim.alpha:SetDuration(300)
                CurrentFrame.anim.alpha:SetEasingFunction(ZO_EaseOutQuintic)
                CurrentFrame.anim.alpha:SetAlphaValues(CurrentFrame:GetAlpha(), 1)
                CurrentFrame.anim:PlayFromStart()
            end
        end        
    end
end

local function resetPicking(index)
    if index == SIDEBAR_INDEX_HISTORY then
        for i = #db.historyScribed, 1, -1 do
            local VIRTUALNAME = "SuperStarScribingHistory"
            local windowName = VIRTUALNAME .. i
            local CurrentFrame = GetControl(windowName)
            if CurrentFrame then
                CurrentFrame.picked = false
                CurrentFrame:GetNamedChild("Highlight"):SetAlpha(0.001)
            end
        end
        pickedHistory = {}
        CALLBACK_MANAGER:FireCallbacks("SuperStarExistPickedHistory", false)
    elseif index == SIDEBAR_INDEX_FAVORITE then
        for i = #db.favoriteScribed, 1, -1 do
            local VIRTUALNAME = "SuperStarScribingFavorite"
            local windowName = VIRTUALNAME .. i
            local CurrentFrame = GetControl(windowName)
            if CurrentFrame then
                CurrentFrame.picked = false
                CurrentFrame:GetNamedChild("Highlight"):SetAlpha(0.001)
            end
        end
        pickedFavorites = {}
        CALLBACK_MANAGER:FireCallbacks("SuperStarExistPickedFavorites", false)
    end
    renderSidebar(index)
end

local function getCompatibleList(slotType)
    local index = 1
    local result = {}
    if slotType == SCRIBING_SLOT_NONE then
        for craftedAbilityId, _ in ipairs(craftedAbilityDict) do
            if IsCraftedAbilityScriptCompatibleWithSelections(scribingData[SCRIBING_SLOT_PRIMARY], craftedAbilityId, scribingData[SCRIBING_SLOT_PRIMARY], scribingData[SCRIBING_SLOT_SECONDARY], scribingData[SCRIBING_SLOT_TERTIARY]) and
            IsCraftedAbilityScriptCompatibleWithSelections(scribingData[SCRIBING_SLOT_SECONDARY], craftedAbilityId, scribingData[SCRIBING_SLOT_PRIMARY], scribingData[SCRIBING_SLOT_SECONDARY], scribingData[SCRIBING_SLOT_TERTIARY]) and
            IsCraftedAbilityScriptCompatibleWithSelections(scribingData[SCRIBING_SLOT_TERTIARY], craftedAbilityId, scribingData[SCRIBING_SLOT_PRIMARY], scribingData[SCRIBING_SLOT_SECONDARY], scribingData[SCRIBING_SLOT_TERTIARY]) then
                result[index] = craftedAbilityId
                index = index + 1
            end
        end
    else
        for i = 1, GetNumScriptsInSlotForCraftedAbility(scribingData[SCRIBING_SLOT_NONE], slotType) do
            local scriptId = GetScriptIdAtSlotIndexForCraftedAbility(scribingData[SCRIBING_SLOT_NONE], slotType, i)
            if IsCraftedAbilityScriptCompatibleWithSelections(scriptId, scribingData[SCRIBING_SLOT_NONE], scribingData[SCRIBING_SLOT_PRIMARY], scribingData[SCRIBING_SLOT_SECONDARY], scribingData[SCRIBING_SLOT_TERTIARY]) then
                result[index] = scriptId
                index = index + 1
            end
        end
    end
    
    return result
end

-- called from Import tab "See skills of this build"
function SuperStar_SeeImportedBuild(self)
    local hash = SuperStarXMLImport:GetNamedChild("ImportValue"):GetNamedChild("Edit"):GetText()

    if hash ~= "" then
        local attrData, skillsData, cpData = CheckImportedBuild(hash)

        if attrData and skillsData and cpData then

            SuperStarSkills.pendingSkillsDataForLoading = skillsData
            SuperStarSkills.pendingCPDataForLoading = cpData
            SuperStarSkills.pendingAttrDataForLoading = attrData
            ResetSkillBuilderAndLoadBuild()
            -- ResetSkillBuilder()

        else
            --
        end
    end

end

function SuperStar_CheckImportedBuild(self)
    local text = self:GetText()

    isImportedBuildValid = false

    if text ~= "" then

        local attrData, skillsData, cpData = CheckImportedBuild(text)
        SuperStarXMLImport:GetNamedChild("ImportSeeBuild"):SetHidden(false)

        if attrData and skillsData and cpData then
            UpdateHashDataContainer(attrData, skillsData, cpData)
        else
            UpdateHashDataContainer(false, false, false)
        end

    else
        SuperStarXMLImport:GetNamedChild("ImportSeeBuild"):SetHidden(true)
        UpdateHashDataContainer(false, false, false)
    end

end

-- Blk: Respec =================================================================

local SUPERSTAR_NOWARNING = 0
local SUPERSTAR_INVALID_CLASS = 1
local SUPERSTAR_NOT_ENOUGHT_SP = 2
local SUPERSTAR_INVALID_RACE = 3
local SUPERSTAR_REQ_SKILLLINE_BUTNOTFOUND = 4
local SUPERSTAR_INVALID_CHAMPION = 5
local SUPERSTAR_NOT_ENOUGHT_CP = 6

local function AnnounceCPRespecDone()
    local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, SOUNDS.LEVEL_UP)
    messageParams:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_SKILL_POINTS_GAINED)
    messageParams:SetText(GetString(SUPERSTAR_CSA_RESPECDONE_TITLE))
    CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
end

local function AnnounceSPRespecDone(totalPointSet)
    local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, SOUNDS.LEVEL_UP)
    messageParams:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_SKILL_POINTS_GAINED)
    messageParams:SetText(GetString(SUPERSTAR_CSA_RESPECDONE_TITLE),
        zo_strformat(SUPERSTAR_CSA_RESPECDONE_POINTS, totalPointSet))
    CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
end

local function AnnounceSPRespecProgress(skillType)
    local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_SMALL_TEXT,
        SOUNDS.QUEST_OBJECTIVE_COMPLETE)
    messageParams:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_OBJECTIVE_COMPLETED)
    messageParams:SetText(GetString("SUPERSTAR_RESPEC_INPROGRESS", skillType))
    CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
end

local function AnnounceSPRespecStarted(totalPointSet)

    local minutes
    if totalPointSet < 150 then
        minutes = 1
    elseif totalPointSet < 300 then
        minutes = 2
    else
        minutes = 3
    end

    -- CENTER_SCREEN_ANNOUNCE:AddMessage(999, CSA_EVENT_COMBINED_TEXT, SOUNDS.CHAMPION_WINDOW_OPENED, GetString(SUPERSTAR_CSA_RESPEC_INPROGRESS), zo_strformat(SUPERSTAR_CSA_RESPEC_TIME, minutes), nil, nil, nil, nil)
    local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_SMALL_TEXT,
        SOUNDS.QUEST_OBJECTIVE_COMPLETE)
    messageParams:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_OBJECTIVE_COMPLETED)
    messageParams:SetText(GetString(SUPERSTAR_CSA_RESPEC_INPROGRESS), zo_strformat(SUPERSTAR_CSA_RESPEC_TIME, minutes))
    CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)

end
-- zo_callLater is here to prevent ZOS limitation of 100 messages / minute
local function RespecSkillPoints(skillsData) -- Jump

    local function DoAbilityRespec(skillsData, skillType, skillLineIndex, abilityIndex, numPointsSet)
        -- d(skillType .. "-" .. skillLineIndex .. "-" .. abilityIndex .. "-" .. numPointsSet)
        -- Check index
        local delayTime = math.max(GetLatency() + 100, 300)
        if skillsData.noRace == true and skillType == SKILL_TYPE_RACIAL then
            zo_callLater(function()
                DoAbilityRespec(skillsData, skillType + 1, 1, 1, numPointsSet)
            end, 1)
            return
        end
        if skillType > SKILLTYPES_IN_SKILLBUILDER then
            AnnounceSPRespecDone(numPointsSet) -- Respec Finish
            skillsDataForRespec = nil
            return
        end
        if skillLineIndex > LSF:GetNumSkillLinesPerChar(skillType) then
            AnnounceSPRespecProgress(skillType) -- This skill type is finished
            zo_callLater(function()
                DoAbilityRespec(skillsData, skillType + 1, 1, 1, numPointsSet)
            end, 1) -- Next skill type
            return
        end
        local _, _, _, isDiscovered = GetSkillLineDynamicInfo(skillType, skillLineIndex)
        if not isDiscovered then
            zo_callLater(function()
                DoAbilityRespec(skillsData, skillType, skillLineIndex + 1, 1, numPointsSet)
            end, 300)
            return
        end
        if abilityIndex > #skillsData[skillType][skillLineIndex] then
            zo_callLater(function()
                DoAbilityRespec(skillsData, skillType, skillLineIndex + 1, 1, numPointsSet)
            end, 1)
            return
        end
        
        -- Start respec

        -- workaround for subclassing
        local esoSkillLineIndex
        if skillType == SKILL_TYPE_CLASS then
            local LSFESO = LSF:GetLSFESOClassSkillLineIndexMappingTable()
            esoSkillLineIndex = LSFESO[skillLineIndex]
        else
            esoSkillLineIndex = skillLineIndex
        end

        local spentIn = skillsData[skillType][esoSkillLineIndex][abilityIndex].spentIn
        local abilityLevel = skillsData[skillType][esoSkillLineIndex][abilityIndex].abilityLevel
        local result, nextAbility

        if spentIn == 0 then
            zo_callLater(function()
                DoAbilityRespec(skillsData, skillType, skillLineIndex, abilityIndex + 1, numPointsSet)
            end, 1)
            return
        else
            -- if purchase is needed
            local skillData = SKILLS_DATA_MANAGER:GetSkillDataByIndices(skillType, esoSkillLineIndex, abilityIndex) -- get current skill data
            if skillData:IsPassive() then -- is passive
                local currentRank = GetSkillAbilityUpgradeInfo(skillType, esoSkillLineIndex, abilityIndex) or 1
                if not skillData:IsPurchased() then
                    result = skillData:GetPointAllocator():Purchase() -- if not purchased then purchase
                    nextAbility = skillData:GetCurrentRank() >= abilityLevel
                elseif currentRank < abilityLevel then -- need levelup
                    -- d("al-"..abilityLevel .. "-" .. skillData:GetCurrentRank())
                    result = skillData:GetPointAllocator():IncreaseRank()
                    nextAbility = skillData:GetCurrentRank() >= abilityLevel
                else
                    result = false
                end
            elseif skillData:IsCraftedAbility() then
                -- do nothing
            else -- is active or ultimate
                -- d("Level-".. abilityLevel)
                if abilityLevel > 0 then -- need morph
                    if not skillData:IsPurchased() then
                        result = skillData:GetPointAllocator():Purchase()
                        nextAbility = false -- do morph in the next run
                    else
                        result = skillData:GetPointAllocator():Morph(abilityLevel)
                        nextAbility = true -- morph finished
                    end
                else
                    result = skillData:GetPointAllocator():Purchase()
                    nextAbility = true
                end
            end
        end
        if result == true then -- purchase or levelup successfully
            if nextAbility == true then -- go to next ability
                zo_callLater(function()
                    DoAbilityRespec(skillsData, skillType, skillLineIndex, abilityIndex + 1, numPointsSet + 1)
                end, delayTime) -- this time delay should be long enough for server updating
            else -- stay at current ability
                zo_callLater(function()
                    DoAbilityRespec(skillsData, skillType, skillLineIndex, abilityIndex, numPointsSet + 1)
                end, delayTime)
            end
        else -- no purchase happened
            zo_callLater(function()
                DoAbilityRespec(skillsData, skillType, skillLineIndex, abilityIndex + 1, numPointsSet)
            end, 300)
        end
    end

    AnnounceSPRespecStarted(skillsData.pointsRequired)
    DoAbilityRespec(skillsData, 1, 1, 1, 0)
end

-- Armodeniz modified for CP2.0
local function RespecCPPoints(cpDataForRespec)

    PrepareChampionPurchaseRequest(true)
    -- d(cpDataForRespec)
    for disciplineIndex = 1, GetNumChampionDisciplines() do
        for skillIndex = 1, GetNumChampionDisciplineSkills(disciplineIndex) do
            if cpDataForRespec[disciplineIndex][skillIndex] > 0 then
                AddSkillToChampionPurchaseRequest(GetChampionSkillId(disciplineIndex, skillIndex),
                    cpDataForRespec[disciplineIndex][skillIndex])
                -- d(GetChampionSkillName(GetChampionSkillId(disciplineIndex,skillIndex)))
            end
        end
    end
    local result = GetExpectedResultForChampionPurchaseRequest()
    if result ~= CHAMPION_PURCHASE_SUCCESS then
        ZO_AlertEvent(EVENT_CHAMPION_PURCHASE_RESULT, result)
        return
    end

    if GetChampionRespecCost() > 0 then
        ZO_Dialogs_ShowDialog("SUPERSTAR_CONFIRM_CPRESPEC_COST", nil, {
            mainTextParams = {GetChampionRespecCost(), ZO_Currency_GetPlatformFormattedGoldIcon()}
        }) -- pay
    else
        ZO_Dialogs_ShowDialog("SUPERSTAR_CONFIRM_CPRESPEC_NOCOST") -- free
    end
end

local function FinalizeCPRespec(shouldFinalize)

    if shouldFinalize then
        -- cpRespecInProgress = true
        SendChampionPurchaseRequest()
        AnnounceCPRespecDone()
        SuperStar_ToggleSuperStarPanel()
    else
        CHAMPION_DATA_MANAGER:ClearChanges()
        -- ClearPendingChampionPoints()
    end

end

local function CheckSPrespec(skillsData)

    local letsGo = false
    local returnCode = SUPERSTAR_NOWARNING

    -- no longer blocked since subclassing
    -- if GetUnitClassId("player") ~= skillsData.classId then
    --     returnCode = SUPERSTAR_INVALID_CLASS
    --     return letsGo, returnCode
    -- end

    letsGo = true

    -- local currentUpgradeLevel, _ = GetSkillAbilityUpgradeInfo(skillType, skillLineIndex, skillIndex)
    if GetAvailableSkillPoints() < skillsData.pointsRequired then
        returnCode = SUPERSTAR_NOT_ENOUGHT_SP
        return letsGo, returnCode
    end

    -- authorized
    if GetUnitRaceId("player") ~= skillsData.raceId then
        returnCode = SUPERSTAR_INVALID_RACE
    end

    return letsGo, returnCode

end

local function CheckRespecSkillLines(skillsData)

    local realSkillLines = {}
    local refSkillLines = {}
    local skillLinesNotFound = ""
    local numLines

    for skillType, skillTypeData in SKILLS_DATA_MANAGER:SkillTypeIterator() do
        -- racial skills should always be available
        -- we might not be the proper rank to use them though!
        -- if skillType ~= SKILL_TYPE_CLASS and skillType ~= SKILL_TYPE_RACIAL then
        if skillType ~= SKILL_TYPE_RACIAL then
            for skillLineIndex, skillLineData in skillTypeData:SkillLineIterator() do
                if not skillLineData:IsAvailable() then
                    -- do we purchase skills in this line?
                    if skillsData[skillType][skillLineIndex] and skillsData[skillType][skillLineIndex].pointsSpent and skillsData[skillType][skillLineIndex].pointsSpent > 0 then
                        skillLinesNotFound = skillLinesNotFound .. skillLineData:GetName() .. ", "
                    end
                end
            end
        end
    end

    if skillLinesNotFound ~= "" then
        skillLinesNotFound = string.sub(skillLinesNotFound, 0, -3)
    else
        skillLinesNotFound = " "
    end
    return skillLinesNotFound

end

local function CheckCPrespec(cpData)

    local letsGo = false
    local returnCode = SUPERSTAR_NOWARNING

    -- blocked
    local result = GetChampionPurchaseAvailability()
    if result ~= CHAMPION_PURCHASE_SUCCESS then
        returnCode = SUPERSTAR_INVALID_CHAMPION
        return letsGo, returnCode
    end

    -- blocked
    -- if GetUnitChampionPoints("player") < cpData.pointsRequired then
    if GetPlayerChampionPointsEarned() < cpData.pointsRequired then
        returnCode = SUPERSTAR_NOT_ENOUGHT_CP
        return letsGo, returnCode
    end

    letsGo = true

    return letsGo, returnCode

end

function ShowRespecScene(favoriteIndex, mode)
    local hash = db.favoritesList[favoriteIndex].hash
    local favName = db.favoritesList[favoriteIndex].name
    local attrData, skillsData, cpData = CheckImportedBuild(hash)
    SuperStarXMLFavoritesRespec:SetHidden(false)
    SuperStarXMLFavoritesHeaders:SetHidden(true)
    SuperStarXMLFavoritesList:SetHidden(true)

    if mode == RESPEC_MODE_SP then

        if skillsData then
            LSF:Initialize(skillsData.classId, skillsData.raceId)
            -- LMM:Update(MENU_CATEGORY_SUPERSTAR, "SuperStarRespec")

            local doRespec, returnCode = CheckSPrespec(skillsData)
            SuperStarXMLFavoritesRespec:GetNamedChild("Warning"):SetText("")

            if doRespec then

                skillsDataForRespec = skillsData
                skillsDataForRespec.noRace = returnCode == SUPERSTAR_INVALID_RACE
                local skillLinesNotFound = CheckRespecSkillLines(skillsData)

                SuperStarXMLFavoritesRespec:GetNamedChild("Title"):SetText(zo_strformat(SUPERSTAR_RESPEC_SPTITLE, favName))

                if returnCode == SUPERSTAR_NOT_ENOUGHT_SP then
                    SuperStarXMLFavoritesRespec:GetNamedChild("Warning"):SetText(SuperStarXMLFavoritesRespec:GetNamedChild("Warning"):GetText() .. "\n\n" .. GetString("SUPERSTAR_RESPEC_ERROR", returnCode))
                end

                if skillLinesNotFound == " " then
                    SuperStarXMLFavoritesRespec:GetNamedChild("Warning"):SetText(SuperStarXMLFavoritesRespec:GetNamedChild("Warning"):GetText() .. "\n\n" .. " ") -- Set to keep the position of Respec button
                else
                    SuperStarXMLFavoritesRespec:GetNamedChild("Warning"):SetText(SuperStarXMLFavoritesRespec:GetNamedChild("Warning"):GetText() .. "\n\n" .. GetString(SUPERSTAR_RESPEC_SKILLLINES_MISSING))
                end
                SuperStarXMLFavoritesRespec:GetNamedChild("SkillLines"):SetText(skillLinesNotFound)
                SuperStarXMLFavoritesRespec:GetNamedChild("Respec"):SetHidden(false)
                SuperStarXMLFavoritesRespec:GetNamedChild("Back"):SetHidden(false)

            else
                SuperStarXMLFavoritesRespec:GetNamedChild("Title"):SetText(zo_strformat(SUPERSTAR_RESPEC_SPTITLE, favName))
                SuperStarXMLFavoritesRespec:GetNamedChild("Warning"):SetText(GetString("SUPERSTAR_RESPEC_ERROR", returnCode))
                SuperStarXMLFavoritesRespec:GetNamedChild("SkillLines"):SetText("")
                SuperStarXMLFavoritesRespec:GetNamedChild("Respec"):SetHidden(true)
                SuperStarXMLFavoritesRespec:GetNamedChild("Back"):SetHidden(false)
                skillsDataForRespec = nil
            end

        else
            -- Build error
        end
    elseif mode == RESPEC_MODE_CP then

        if cpData then

            -- LMM:Update(MENU_CATEGORY_SUPERSTAR, "SuperStarRespec")

            local doRespec, returnCode = CheckCPrespec(cpData)

            if doRespec then

                cpDataForRespec = cpData

                SuperStarXMLFavoritesRespec:GetNamedChild("Title"):SetText(zo_strformat(SUPERSTAR_RESPEC_CPTITLE, favName))
                SuperStarXMLFavoritesRespec:GetNamedChild("Warning"):SetText(
                    zo_strformat(GetString(SUPERSTAR_RESPEC_CPREQUIRED), cpData.pointsRequired))
                SuperStarXMLFavoritesRespec:GetNamedChild("SkillLines"):SetText("")
                SuperStarXMLFavoritesRespec:GetNamedChild("Respec"):SetHidden(false)
                SuperStarXMLFavoritesRespec:GetNamedChild("Back"):SetHidden(false)

            else
                SuperStarXMLFavoritesRespec:GetNamedChild("Title"):SetText(zo_strformat(SUPERSTAR_RESPEC_CPTITLE, favName))
                SuperStarXMLFavoritesRespec:GetNamedChild("Warning"):SetText(GetString("SUPERSTAR_RESPEC_ERROR", returnCode))
                SuperStarXMLFavoritesRespec:GetNamedChild("SkillLines"):SetText("")
                SuperStarXMLFavoritesRespec:GetNamedChild("Respec"):SetHidden(true)
                SuperStarXMLFavoritesRespec:GetNamedChild("Back"):SetHidden(false)
                cpDataForRespec = nil
            end

        else
            -- Build error
        end

    end

end

function SuperStar_DoRespec()
    if skillsDataForRespec then
        RespecSkillPoints(skillsDataForRespec)
        SuperStar_ToggleSuperStarPanel()
    elseif cpDataForRespec then
        RespecCPPoints(cpDataForRespec)
    end
end

function SuperStar_DoBack()
    SuperStarXMLFavoritesHeaders:SetHidden(false)
    SuperStarXMLFavoritesList:SetHidden(false)
    SuperStarXMLFavoritesRespec:SetHidden(true)
end
-- Blk: Main Scene =============================================================

-- Called by XML
function SuperStar_HoverRowOfSlot(control)
    if type(control.abilityId) ~= "number" then
        return
    end
    InitializeTooltip(SuperStarAbilityTooltip, control, TOPLEFT, 5, 5, BOTTOMRIGHT)
    SuperStarAbilityTooltip:SetAbilityId(control.abilityId)
end

-- Called by XML
function SuperStar_ExitRowOfSlot(control)
    ClearTooltip(SuperStarAbilityTooltip)
end

-- Called by XML
function SuperStar_HoverSkillLine(control)
    if type(control.masterySkillId) == "number" then
        InitializeTooltip(SuperStarAbilityTooltip, control, TOPLEFT, 5, 5, BOTTOMRIGHT)
        SuperStarAbilityTooltip:SetAbilityId(control.masterySkillId)
    elseif type(control.skillLineId) == "number" then
        InitializeTooltip(SkillTooltip, control, TOPLEFT, 5, 5, BOTTOMRIGHT)
        if control.isSubclassing then
            SkillTooltip:SetSubclassingSkillLineById(control.skillLineId)
        else
            SkillTooltip:SetSkillLineById(control.skillLineId)
        end
    end
end

-- Called by XML
function SuperStar_ExitSkillLine(control)
    ClearTooltip(SkillTooltip)
    ClearTooltip(SuperStarAbilityTooltip)
end

local SKILL_LINE_ROW_CHILDREN = {
    ClassIcon = false,
    SkillLineIcon = false,
    ClassName = false,
    SkillLineName = true,
    ClassMasteryIcon = true,
}

local function SetSkillLineRowHover(SSkillFrame, masteryOnly)
    for childName, masteryChild in pairs(SKILL_LINE_ROW_CHILDREN) do
        SSkillFrame:GetNamedChild(childName):SetMouseEnabled(masteryChild or not masteryOnly)
    end
end

local MASTERY_RING_SIZE = 38
local MASTERY_RING_OFFSET_X = 0
local MASTERY_RING_OFFSET_Y = -1
local MASTERY_RING_ALPHA = 1

local function ShowMasteryIcon(SSkillFrame, masterySkillId, skillLineIcon)
    local cmIcon = SSkillFrame:GetNamedChild("ClassMasteryIcon")
    local cmRing = SSkillFrame:GetNamedChild("ClassMasteryRing")
    cmIcon:SetTexture(GetAbilityIcon(masterySkillId))
    cmIcon:SetHidden(false)
    cmRing:SetTexture(skillLineIcon)
    cmRing:SetAlpha(MASTERY_RING_ALPHA)
    cmRing:SetDimensions(MASTERY_RING_SIZE, MASTERY_RING_SIZE)
    cmRing:ClearAnchors()
    cmRing:SetAnchor(CENTER, cmIcon, CENTER, MASTERY_RING_OFFSET_X, MASTERY_RING_OFFSET_Y)
    cmRing:SetHidden(false)
end

local function HideMasteryIcon(SSkillFrame)
    SSkillFrame:GetNamedChild("ClassMasteryIcon"):SetHidden(true)
    SSkillFrame:GetNamedChild("ClassMasteryRing"):SetHidden(true)
end

-- Lykeion@6.0.0
-- Called by XML
function SuperStar_HoverGrimoire(control)
    if type(control.scribingId) ~= "number" then
        return
    end
    SetCraftedAbilityScriptSelectionOverride(control.scribingId, 0, 0, 0)
    local abilityId = GetCraftedAbilityRepresentativeAbilityId(control.scribingId)
    InitializeTooltip(SuperStarAbilityTooltip, control, TOPLEFT, 5, 5, BOTTOMRIGHT)
    SuperStarAbilityTooltip:SetAbilityId(abilityId)

    local highlight = control:GetNamedChild("Highlight")
    highlight:SetHidden(false)
    highlight:SetAlpha(1)
end

function SuperStar_ExitGrimoire(control)
    ResetCraftedAbilityScriptSelectionOverride()
    ClearTooltip(SuperStarAbilityTooltip)

    local highlight = control:GetNamedChild("Highlight")
    highlight.anim = ANIMATION_MANAGER:CreateTimeline()
    highlight.anim.alpha = highlight.anim:InsertAnimation( ANIMATION_ALPHA, highlight, 0 )
    highlight.anim.alpha:SetDuration(300)
    highlight.anim.alpha:SetEasingFunction(ZO_EaseOutQuintic)
    highlight.anim.alpha:SetAlphaValues(highlight:GetAlpha(), 0.001)
    zo_callLater(function() highlight:SetHidden(true) end, 300)
    highlight.anim:PlayFromStart()
end

function SuperStar_HoverScript(control)
    if type(control.scribingId) ~= "number" then
        return
    end
    InitializeTooltip(SuperStarAbilityTooltip, control, TOPLEFT, 5, 5, BOTTOMRIGHT)
    local displayFlags = SCRIBING_TOOLTIP_DISPLAY_FLAGS_SHOW_ACQUIRE_HINT + SCRIBING_TOOLTIP_DISPLAY_FLAGS_SHOW_ERRORS
    displayFlags = ZO_FlagHelpers.SetMaskFlag(displayFlags, SCRIBING_TOOLTIP_DISPLAY_FLAGS_SHOW_ACQUIRE_HINT + SCRIBING_TOOLTIP_DISPLAY_FLAGS_SHOW_ERRORS)

    -- SetCraftedAbilityScript(int selectedCraftedAbilityId, int scriptId, int primaryScriptId, int secondaryScriptId, int tertiaryScriptId, int displayFlags)
    SuperStarAbilityTooltip:SetCraftedAbilityScript(scribingData[SCRIBING_SLOT_NONE], control.scribingId, 0, 0, 0, displayFlags)

    local highlight = control:GetNamedChild("Divider")
    highlight:SetHidden(false)
    highlight:SetAlpha(1)
end

function SuperStar_ExitScript(control)
    ClearTooltip(SuperStarAbilityTooltip)
    local highlight = control:GetNamedChild("Divider")
    highlight.anim = ANIMATION_MANAGER:CreateTimeline()
    highlight.anim.alpha = highlight.anim:InsertAnimation( ANIMATION_ALPHA, highlight, 0 )
    highlight.anim.alpha:SetDuration(300)
    highlight.anim.alpha:SetEasingFunction(ZO_EaseOutQuintic)
    highlight.anim.alpha:SetAlphaValues(highlight:GetAlpha(), 0.001)
    zo_callLater(function() highlight:SetHidden(true) end, 300)
    highlight.anim:PlayFromStart()
end

function SuperStar_HoverChosen(control)
    if type(control.scribingId) ~= "number" then
        return
    end
    -- wheel not allowed when picking other slots
    if scribingData[SCRIBING_SLOT_NONE] == nil or scribingData[SCRIBING_SLOT_PRIMARY] == nil or scribingData[SCRIBING_SLOT_SECONDARY] == nil or scribingData[SCRIBING_SLOT_TERTIARY] == nil then
        return
    end
    local spinner = control:GetNamedChild("Spinner")
    spinner:SetHidden(false)
end

function SuperStar_ExitChosen(control)
    local spinner = control:GetNamedChild("Spinner")
    spinner:SetHidden(true)
end

function SuperStar_WheelChosen(control, delta)
    -- wheel not allowed while picking other slots
    if scribingData[SCRIBING_SLOT_NONE] == nil or scribingData[SCRIBING_SLOT_PRIMARY] == nil or scribingData[SCRIBING_SLOT_SECONDARY] == nil or scribingData[SCRIBING_SLOT_TERTIARY] == nil then
        return
    end

    local compatibles = getCompatibleList(control.slotType)
    local currentIndex
    for i = 1, #compatibles do
        if compatibles[i] == control.scribingId then
            currentIndex = i
            break
        end
    end
    -- math.fmod works weirdly here so I do it manually
    if currentIndex - delta > #compatibles then
        currentIndex = 1
    elseif currentIndex - delta < 1 then
        currentIndex = #compatibles
    else
        currentIndex = currentIndex - delta
    end
    -- d("compatibles length: "..#compatibles.."/ currentIndex: "..currentIndex.."/ delta: "..delta)
    control.scribingId = compatibles[currentIndex]
    if control.slotType == SCRIBING_SLOT_NONE then
        control.icon = GetCraftedAbilityIcon(control.scribingId)
        control.skillLineName = GetCraftedAbilitySkilllineName(control.scribingId)
        control.displayName = GetCraftedAbilityDisplayName(control.scribingId)
        control:GetNamedChild("Icon"):SetTexture(GetCraftedAbilityIcon(control.scribingId))
        control:GetNamedChild("MainText"):SetText(GetCraftedAbilityDisplayName(control.scribingId))
        control:GetNamedChild("SubText"):SetText(GetCraftedAbilitySkilllineName(control.scribingId))
    else
        control.icon = GetCraftedAbilityScriptIcon(control.scribingId)
        control.displayName = GetCraftedAbilityScriptDisplayName(control.scribingId)
        control:GetNamedChild("Icon"):SetTexture(GetCraftedAbilityScriptIcon(control.scribingId))
        control:GetNamedChild("MainText"):SetText(GetCraftedAbilityScriptDisplayName(control.scribingId))  
    end
    
    scribingData[control.slotType] = compatibles[currentIndex]
    SuperStar_SwitchScribingResult(scribingData[SCRIBING_SLOT_NONE], scribingData[SCRIBING_SLOT_PRIMARY], scribingData[SCRIBING_SLOT_SECONDARY], scribingData[SCRIBING_SLOT_TERTIARY])
end

function SuperStar_HoverSidebar(control)
    SuperStar_HideScribingResult()
    SuperStar_ShowScribingResult(control[SCRIBING_SLOT_NONE], control[SCRIBING_SLOT_PRIMARY], control[SCRIBING_SLOT_SECONDARY], control[SCRIBING_SLOT_TERTIARY])
    if not control.picked then
        local highlight = control:GetNamedChild("Highlight")
        highlight:SetHidden(false)
        highlight:SetAlpha(0.4)
    end
end

function SuperStar_ExitSidebar(control)
    SuperStar_HideScribingResult()
    SuperStar_ShowScribingResult(scribingData[SCRIBING_SLOT_NONE], scribingData[SCRIBING_SLOT_PRIMARY], scribingData[SCRIBING_SLOT_SECONDARY], scribingData[SCRIBING_SLOT_TERTIARY])
    if not control.picked then
        local highlight = control:GetNamedChild("Highlight")
        highlight.anim = ANIMATION_MANAGER:CreateTimeline()
        highlight.anim.alpha = highlight.anim:InsertAnimation( ANIMATION_ALPHA, highlight, 0 )
        highlight.anim.alpha:SetDuration(300)
        highlight.anim.alpha:SetEasingFunction(ZO_EaseOutQuintic)
        highlight.anim.alpha:SetAlphaValues(highlight:GetAlpha(), 0.001)
        zo_callLater(function() highlight:SetHidden(true) end, 300)
        highlight.anim:PlayFromStart()
    end
end

function SuperStar_ShowScribingResult(craftedId, pri, sec, ter)
    if scribingData[SCRIBING_SLOT_NONE] ~= nil and scribingData[SCRIBING_SLOT_PRIMARY] ~= nil and scribingData[SCRIBING_SLOT_SECONDARY] ~= nil and scribingData[SCRIBING_SLOT_TERTIARY] ~= nil then
        SetCraftedAbilityScriptSelectionOverride(craftedId, pri, sec, ter)
        local resultControl = GetControl("SuperStarXMLScribingResult")
        local abilityId = GetCraftedAbilityRepresentativeAbilityId(craftedId)
        InitializeTooltip(SuperStarScribingResultTooltip, resultControl, TOPLEFT, 0, 0, TOPLEFT)
        CALLBACK_MANAGER:FireCallbacks("SuperStarExistScribingResult", true)

        SuperStarScribingResultTooltip:SetAbilityId(abilityId)
        SuperStarScribingResultTooltip:SetHidden(false)
        SuperStarScribingResultTooltip:SetAlpha(0.001)
        SuperStarScribingResultTooltip.anim = ANIMATION_MANAGER:CreateTimeline()
        SuperStarScribingResultTooltip.anim.slide = SuperStarScribingResultTooltip.anim:InsertAnimation( ANIMATION_TRANSLATE, SuperStarScribingResultTooltip, 0 )
        SuperStarScribingResultTooltip.anim.slide:SetDuration(300)
        SuperStarScribingResultTooltip.anim.slide:SetEasingFunction(ZO_EaseOutQuintic)
        SuperStarScribingResultTooltip.anim.slide:SetTranslateDeltas(70, 0)
        SuperStarScribingResultTooltip.anim.alpha = SuperStarScribingResultTooltip.anim:InsertAnimation( ANIMATION_ALPHA, SuperStarScribingResultTooltip, 0 )
        SuperStarScribingResultTooltip.anim.alpha:SetDuration(300)
        SuperStarScribingResultTooltip.anim.alpha:SetEasingFunction(ZO_EaseOutQuintic)
        SuperStarScribingResultTooltip.anim.alpha:SetAlphaValues(SuperStarScribingResultTooltip:GetAlpha(), 1)
        SuperStarScribingResultTooltip.anim:PlayFromStart()
    end
end

function SuperStar_HideScribingResult()
    ResetCraftedAbilityScriptSelectionOverride()
    ClearTooltip(SuperStarScribingResultTooltip)
    CALLBACK_MANAGER:FireCallbacks("SuperStarExistScribingResult", false)
end

-- Directly replaces the contents of the tooltip to minimize flickering when using the wheel
function SuperStar_SwitchScribingResult(craftedId, pri, sec, ter)
    if not SuperStarScribingResultTooltip then
        return
    end
    SuperStar_HideScribingResult()
    SetCraftedAbilityScriptSelectionOverride(craftedId, pri, sec, ter)
    local resultControl = GetControl("SuperStarXMLScribingResult")
    local abilityId = GetCraftedAbilityRepresentativeAbilityId(craftedId)
    InitializeTooltip(SuperStarScribingResultTooltip, resultControl, TOPLEFT, 70, 0, TOPLEFT)
    SuperStarScribingResultTooltip:SetAbilityId(abilityId)
    SuperStarScribingResultTooltip:SetHidden(false)
end

function SuperStar_PickTab(control)
    renderSidebar(control.index)
end

function SuperStar_Favorite_WheelPage(delta)
    local maxPage = math.ceil(#db.favoriteScribed / SIDEBAR_SKILL_MAX)
    if maxPage == 0 then
        maxPage = 1
    end
    if SIDEBAR_FAV_PAGE - delta <= 0 then
        SIDEBAR_FAV_PAGE = 1
    elseif SIDEBAR_FAV_PAGE - delta > maxPage then
        SIDEBAR_FAV_PAGE = maxPage
    else
        SIDEBAR_FAV_PAGE = SIDEBAR_FAV_PAGE - delta
        renderSidebar(SIDEBAR_INDEX_FAVORITE)
    end  
end

function SuperStar_Favorite_TurnPage(offset)
    local maxPage = math.ceil(#db.favoriteScribed / SIDEBAR_SKILL_MAX)
    if maxPage == 0 then
        maxPage = 1
    end
    if SIDEBAR_FAV_PAGE + offset <= 0 then
        SIDEBAR_FAV_PAGE = 1
    elseif SIDEBAR_FAV_PAGE + offset > maxPage then
        SIDEBAR_FAV_PAGE = maxPage
    else
        SIDEBAR_FAV_PAGE = SIDEBAR_FAV_PAGE + offset
        renderSidebar(SIDEBAR_INDEX_FAVORITE)  
    end
end

-- Called by XML
-- Armodeniz modified for CP2.0
function SuperStar_HoverRowOfCSkill(control)
    InitializeTooltip(SuperStarCSkillTooltip, control, TOPLEFT, 5, 5, BOTTOMRIGHT)
    SuperStarCSkillTooltip:SetChampionSkill(control.cSkillId, control.nPPoints, 0, false)
end

-- Called by XML
function SuperStar_ExitRowOfCSkill(control)
    ClearTooltip(SuperStarCSkillTooltip)
end

-- Called by XML
function SuperStar_HoverRowOfStuff(control)

    if control.itemLink then
        InitializeTooltip(SuperStarItemTooltip, control, TOPLEFT, 5, 5, BOTTOMRIGHT)
        SuperStarItemTooltip:SetLink(control.itemLink)
    end

end

-- Called by XML
function SuperStar_ExitRowOfStuff(control)
    ClearTooltip(SuperStarItemTooltip)
end
-- These 2 functions are used both in main scene and in companion scene
local function GetWeaponIconPair(firstWeapon, secondWeapon)
    if firstWeapon ~= WEAPONTYPE_NONE then
        if firstWeapon == WEAPONTYPE_FIRE_STAFF then
            return "/esoui/art/progression/icon_firestaff.dds", 0
        elseif firstWeapon == WEAPONTYPE_FROST_STAFF then
            return "/esoui/art/progression/icon_icestaff.dds", 1
        elseif firstWeapon == WEAPONTYPE_LIGHTNING_STAFF then
            return "/esoui/art/progression/icon_lightningstaff.dds", 2
        elseif firstWeapon == WEAPONTYPE_HEALING_STAFF then
            return "/esoui/art/progression/icon_healstaff.dds", 3
        elseif firstWeapon == WEAPONTYPE_TWO_HANDED_AXE or firstWeapon == WEAPONTYPE_TWO_HANDED_HAMMER or firstWeapon == WEAPONTYPE_TWO_HANDED_SWORD then
            return "/esoui/art/progression/icon_2handed.dds", 4
        elseif firstWeapon == WEAPONTYPE_BOW then
            return "/esoui/art/progression/icon_bows.dds", 5
        elseif secondWeapon ~= WEAPONTYPE_NONE and secondWeapon ~= WEAPONTYPE_SHIELD then
            return "/esoui/art/progression/icon_dualwield.dds", 6
        elseif secondWeapon == WEAPONTYPE_SHIELD then
            return "/esoui/art/progression/icon_1handed.dds", 7
        else
            return "/esoui/art/progression/icon_1handplusrune.dds", 8
        end
    else
        return "", 9
    end
end

local function GetWeaponIconByIndex(index)
    if index ~= nil then
        if index == 0 then
            return "/esoui/art/progression/icon_firestaff.dds"
        elseif index == 1 then
            return "/esoui/art/progression/icon_icestaff.dds"
        elseif index == 2 then
            return "/esoui/art/progression/icon_lightningstaff.dds"
        elseif index == 3 then
            return "/esoui/art/progression/icon_healstaff.dds"
        elseif index == 4 then
            return "/esoui/art/progression/icon_2handed.dds"
        elseif index == 5 then
            return "/esoui/art/progression/icon_bows.dds"
        elseif index == 6 then
            return "/esoui/art/progression/icon_dualwield.dds"
        elseif index == 7 then
            return "/esoui/art/progression/icon_1handed.dds"
        elseif index == 8 then
            return "/esoui/art/progression/icon_1handplusrune.dds"
        else
            
        end
    else
        return ""
    end
end

local function ShowSlotTexture(control, abilityId)
    if type(abilityId) == "number" and abilityId ~= 0 then
        -- @Lykeion
        if craftedAbilityDict[abilityId] then
            -- control:SetTexture(GetAbilityIcon(GetAbilityIdForCraftedAbilityId(abilityId)))
            control:SetTexture(GetCraftedAbilityDisplayIcon(abilityId))
            control:SetHidden(false)
            control.abilityId = GetAbilityIdForCraftedAbilityId(abilityId)
        else
            control:SetTexture(GetAbilityIcon(abilityId))
            control:SetHidden(false)
            control.abilityId = abilityId
        end
        
    elseif type(abilityId) == "string" and abilityId ~= "" then
        control:SetTexture(abilityId)
        control:SetHidden(false)
    else
        control:SetHidden(true)
    end
end

local FOOD_BUFF_ABILITY_MAP = {
    [61218] = FOOD_BUFF_MAX_ALL,
    [61255] = FOOD_BUFF_MAX_HEALTH_STAMINA,
    [61257] = FOOD_BUFF_MAX_HEALTH_MAGICKA,
    [61259] = FOOD_BUFF_MAX_HEALTH,
    [61260] = FOOD_BUFF_MAX_MAGICKA,
    [61261] = FOOD_BUFF_MAX_STAMINA,
    [61294] = FOOD_BUFF_MAX_MAGICKA_STAMINA,
    [61322] = FOOD_BUFF_REGEN_HEALTH,
    [61325] = FOOD_BUFF_REGEN_MAGICKA,
    [61328] = FOOD_BUFF_REGEN_STAMINA,
    [61340] = FOOD_BUFF_REGEN_HEALTH_STAMINA,
    [61345] = FOOD_BUFF_REGEN_MAGICKA_STAMINA,
    [61335] = FOOD_BUFF_REGEN_HEALTH_MAGICKA,
    [61350] = FOOD_BUFF_REGEN_ALL,
    [68411] = FOOD_BUFF_MAX_ALL, -- Crown store
    [68416] = FOOD_BUFF_REGEN_ALL, -- Crown store
    [71057] = FOOD_BUFF_MAX_HEALTH_REGEN_STAMINA,
    [72816] = FOOD_BUFF_MAX_HEALTH_REGEN_MAGICKA,
    [72819] = FOOD_BUFF_MAX_HEALTH_REGEN_STAMINA,
    [72822] = FOOD_BUFF_MAX_HEALTH_REGEN_HEALTH,
    [72824] = FOOD_BUFF_MAX_HEALTH_REGEN_ALL,
    [84681] = FOOD_BUFF_MAX_MAGICKA_STAMINA, -- 2h Witches event
    [84709] = FOOD_BUFF_MAX_MAGICKA_REGEN_STAMINA, -- 2h Witches event
    [84725] = FOOD_BUFF_MAX_MAGICKA_REGEN_HEALTH, -- 2h Witches event
    [84678] = FOOD_BUFF_MAX_MAGICKA, -- 2h Witches event
    [84700] = FOOD_BUFF_REGEN_HEALTH_MAGICKA, -- 2h Witches event
    [84704] = FOOD_BUFF_REGEN_ALL, -- 2h Witches event
    [84720] = FOOD_BUFF_MAX_MAGICKA_REGEN_MAGICKA, -- 2h Witches event
    [84731] = FOOD_BUFF_MAX_HEALTH_MAGICKA_REGEN_MAGICKA, -- 2h Witches event
    [84735] = FOOD_BUFF_MAX_HEALTH_MAGICKA_SPECIAL_VAMPIRE, -- 2h Witches event
    [86673] = FOOD_BUFF_MAX_STAMINA_REGEN_STAMINA,
    [89955] = FOOD_BUFF_MAX_STAMINA_REGEN_MAGICKA, -- 2h Witches event
    [89957] = FOOD_BUFF_MAX_HEALTH_STAMINA_REGEN_STAMINA, -- 2h Witches event
    [89971] = FOOD_BUFF_MAX_HEALTH_REGEN_STAMINA_MAGICKA, -- Jester event
    [100498] = FOOD_BUFF_MAX_HEALTH_MAGICKA_REGEN_HEALTH_MAGICKA,
    [107748] = FOOD_BUFF_MAX_HEALTH_MAGICKA, -- Artaeum Pickled Fish Bowl
    [107789] = FOOD_BUFF_MAX_HEALTH_STAMINA_REGEN_HEALTH_STAMINA,
    [127596] = FOOD_BUFF_MAX_HEALTH_REGEN_HEALTH_MAGICKA_STAMINA,
}

local function GetFoodBuffAbilityId(foodType)
    for abilityId, foodBuff in pairs(FOOD_BUFF_ABILITY_MAP) do
        if foodBuff == foodType then
            return abilityId
        end
    end
    return nil
end

local function GetActiveFoodTypeBonus()

    local numBuffs = GetNumBuffs("player")
    local hasActiveEffects = numBuffs > 0
    if (hasActiveEffects) then
        for i = 1, numBuffs do
            local _, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
            if FOOD_BUFF_ABILITY_MAP[abilityId] then
                return FOOD_BUFF_ABILITY_MAP[abilityId]
            end
        end
    end

    return FOOD_BUFF_NONE

end

local function GetEnchantQuality(itemLink)	-- From Enchanted Quality (Rhyono, votan)
    local subIdToQuality = {}

	local itemId, itemIdSub, enchantSub = itemLink:match("|H[^:]+:item:([^:]+):([^:]+):[^:]+:[^:]+:([^:]+):")
	if not itemId then return 0 end

	enchantSub = tonumber(enchantSub)

	if enchantSub == 0 and not IsItemLinkCrafted(itemLink) then

		local hasSet = GetItemLinkSetInfo(itemLink, false)
		if hasSet then enchantSub = tonumber(itemIdSub) end -- For non-crafted sets, the "built-in" enchantment has the same quality as the item itself

	end

	if enchantSub > 0 then

		local quality = subIdToQuality[enchantSub]

		if not quality then

			-- Create a fake itemLink to get the quality from built-in function
			local itemLink = string.format("|H1:item:%i:%i:50:0:0:0:0:0:0:0:0:0:0:0:0:1:1:0:0:10000:0|h|h", itemId, enchantSub)
			quality = GetItemLinkQuality(itemLink)
			subIdToQuality[enchantSub] = quality
		end

		return quality
	end
	return 0
end

local function getStaticVampWWIconFile(buffId)
    if buffId == 35658 then
        return "/esoui/art/icons/ability_werewolf_010.dds"
    elseif buffId == 135397 then
        return "/esoui/art/icons/ability_u26_vampire_infection_stage1.dds"
    elseif buffId == 135399 then
        return "/esoui/art/icons/ability_u26_vampire_infection_stage2.dds"
    elseif buffId == 135400 then
        return "/esoui/art/icons/ability_u26_vampire_infection_stage3.dds"
    elseif buffId == 135402 then
        return "/esoui/art/icons/ability_u26_vampire_infection_stage4.dds"
    else
        return nil
    end
end

local RACE_ICON = {
    [1] = "EsoUI/Art/CharacterCreate/charactercreate_bretonicon_up.dds",
    [2] = "EsoUI/Art/CharacterCreate/charactercreate_redguardicon_up.dds",
    [3] = "EsoUI/Art/CharacterCreate/charactercreate_orcicon_up.dds",
    [4] = "EsoUI/Art/CharacterCreate/charactercreate_dunmericon_up.dds",
    [5] = "EsoUI/Art/CharacterCreate/charactercreate_nordicon_up.dds",
    [6] = "EsoUI/Art/CharacterCreate/charactercreate_argonianicon_up.dds",
    [7] = "EsoUI/Art/CharacterCreate/charactercreate_altmericon_up.dds",
    [8] = "EsoUI/Art/CharacterCreate/charactercreate_bosmericon_up.dds",
    [9] = "EsoUI/Art/CharacterCreate/charactercreate_khajiiticon_up.dds",
    [10] = "EsoUI/Art/CharacterCreate/charactercreate_imperialicon_up.dds",
}

local function GetRaceIcon(raceId)
    return RACE_ICON[raceId]
end

-- Lykeion: Utility
-- len(2^53) = 16 and len(75^8) = 16, so encode every 15-bit decimal number as a 8-bit base75 character
-- Choose 15 in case of overflow 2^53
local base = "0123456789BCDFGHJKLMNPQRSTVWXYZbcdfghjklmnpqrstvwxyz(){}[]<>.!?+-/;~@&$^_=`"

-- Since zos unfortunately censors the content in itemlink and replaces the content with *, in some cases the compressed string is broken
-- This is a little safer dictionary, reducing the likelihood of sensitive words that may appear in compressed strings. But for backward compatibility, I won't enable it until the next major update.
-- local base = "ABCD-/GHIJKLMNOPQRSTUVWXYZabcd*]ghijklmnopqrstuvwxyz123456789!@#&=_{};,<>`~"

local function decToBase(decStr)
    local num = tonumber(decStr)
    if not num then return nil end
    if num == 0 then return base:sub(1, 1) end
    local result = ""
    while num > 0 do
        local remainder = num % string.len(base)
        result = base:sub(remainder + 1, remainder + 1) .. result
        num = math.floor(num / string.len(base))
    end
    return result
end

local function baseToDec(baseStr)
    local leadingZeros = baseStr:match("^0+")
    local basePart = baseStr:match("^[0]*(.*)")
    local num = 0
    for i = 1, #basePart do
        local char = basePart:sub(i, i)
        local value = base:find(char, 1, true)
        if not value then
            -- backward compatibility
            -- value = legacyBase:find(char)
            -- if not value then
            -- In fact, the link is probably not outdated, but rather part of it is unfortunately composed of sensitive words that have been replaced by *
                d(GetString(SUPERSTAR_CHATBOX_SUPERSTAR_OUTDATED))
                return nil
            -- end
        end
        num = num * string.len(base) + (value - 1)
    end
    local decStr = tostring(string.format("%.0f", num))
    return decStr
end

-- local function get9BitBase52Str(...)
--     local decStr = ""
--     local args = {...}
--     for i, value in ipairs(args) do
--         d(value)
--         -- Use reverse order when storing, cuz decoding is also done in reverse order
--         decStr = tostring(value) .. decStr
--     end
--     local base52Str = decToBase(tonumber(decStr))
--     return string.format("%09s", base52Str)
-- end

-- local function longDecToBase(input)
--     local chunkSize = 15
--     local result = ""
--     local length = #input

--     for i = length, 1, -chunkSize do
--         local chunk = string.sub(input, math.max(i - chunkSize + 1, 1), i)
--         local decimalValue = tonumber(chunk)
--         if decimalValue then
--             local baseChunk = decToBase(decimalValue)
--             if (i - chunkSize + 1) > 1 then
--                 while #baseChunk < 8 do
--                     baseChunk = base:sub(1, 1) .. baseChunk
--                 end
--                 result = baseChunk .. result
--             else
--                 result = baseChunk .. result
--             end
--         end
--     end

--     return result
-- end

-- local function baseToLongDec(input)
--     local chunkSize = 8
--     local result = ""
--     local length = #input

--     for i = length, 1, -chunkSize do
--         local chunk = string.sub(input, math.max(i - chunkSize + 1, 1), i)
--         if chunk then
--             local baseChunk = baseToDec(chunk)
--             result = string.format("%015s", string.format("%.0f", baseChunk)) .. result
--         end
--     end
--     return result
-- end

-- local function getStackStr(...)
--     local resultStr = ""
--     local args = {...}
--     for i, value in ipairs(args) do
--         -- Use reverse order when storing, cuz decoding is also done in reverse order
--         resultStr = tostring(value) .. resultStr
--     end
--     return resultStr
-- end

-- local function truncateTail(inputString, length)
--     local truncatedPart = inputString:sub(-length)
--     local remainingPart = inputString:sub(1, -length - 1)
--     -- d(tonumber(truncatedPart))
--     return remainingPart, tonumber(truncatedPart)
-- end

local function numberToBinary(num, width)
    local binary = ""
    for i = 1, width do
        binary = ((num % 2 == 1) and "1" or "0") .. binary
        num = math.floor(num / 2)
    end
    return binary
end

local function binaryToNumber(binaryStr)
    local num = 0
    for i = 1, #binaryStr do
        num = num * 2 + (binaryStr:sub(i, i) == "1" and 1 or 0)
    end
    return num
end

local function bitBufWrite(buf, value, width)
    for i = width - 1, 0, -1 do
        buf.bits = buf.bits .. ((math.floor(value / 2 ^ i) % 2 == 1) and "1" or "0")
    end
end

local function bitBufRead(buf, width)
    local value = 0
    for i = 1, width do
        value = value * 2 + (buf.bits:sub(buf.pos + i - 1, buf.pos + i - 1) == "1" and 1 or 0)
    end
    buf.pos = buf.pos + width
    return value
end

local function bitBufEncode(buf)
    local bits = buf.bits
    local bitCount = #bits
    local chunkBitSize = 49
    local remainder = bitCount % chunkBitSize
    if remainder ~= 0 then
        bits = bits .. string.rep("0", chunkBitSize - remainder)
    end
    local result = ""
    for i = 1, #bits, chunkBitSize do
        local chunk = bits:sub(i, i + chunkBitSize - 1)
        local num = binaryToNumber(chunk)
        local baseChunk = decToBase(num)
        while #baseChunk < 8 do
            baseChunk = base:sub(1, 1) .. baseChunk
        end
        result = result .. baseChunk
    end
    return result
end

local function bitBufDecode(baseStr)
    local bits = ""
    for i = 1, #baseStr, 8 do
        local chunk = baseStr:sub(i, i + 7)
        local num = tonumber(baseToDec(chunk))
        if not num then return nil end
        bits = bits .. numberToBinary(num, 49)
    end
    return {bits = bits, pos = 1}
end

-- Bit widths for each field
-- pretty confident the width used here will be sufficient for U50 and probably for quite a long time after that too
local BIT_WIDTH = {
    RACE = 4, -- 2^4 = 16 > 10 races needed
    CLASS = 3,
    SKILL_ID = 19,
    ACTIVE_BOONS = 4,
    VAMPWW_ID = 3,
    ATTRIBUTE = 16,
    MAX_STAT = 17,
    REGEN = 12,
    POWER = 14,
    CRIT = 15,
    RESIST = 16,
    ITEM_ID = 19,
    QUALITY = 3,
    TRAIT = 7,
    ENCHANT_ID = 17,
    ENCHANT_QUALITY = 3,
    CP_SLOT = 9,
    SKILL_LINE = 5,
    FOOD_BUFF = 6,
}

local EQUIP_SLOT_ORDER = {
    EQUIP_SLOT_HEAD,
    EQUIP_SLOT_NECK,
    EQUIP_SLOT_CHEST,
    EQUIP_SLOT_SHOULDERS,
    EQUIP_SLOT_MAIN_HAND,
    EQUIP_SLOT_OFF_HAND,
    EQUIP_SLOT_WAIST,
    EQUIP_SLOT_LEGS,
    EQUIP_SLOT_FEET,
    EQUIP_SLOT_RING1,
    EQUIP_SLOT_RING2,
    EQUIP_SLOT_HAND,
    EQUIP_SLOT_BACKUP_MAIN,
    EQUIP_SLOT_BACKUP_OFF,
}

local function IsSubclassing()
    local playerClassId = GetUnitClassId("player")
    local activeClassSkillLineIndex = 0
    local numSkillLines = GetNumSkillLines(SKILL_TYPE_CLASS)

    for skillLineIndex = 1, numSkillLines do
        local currentRank, isAdvised, isActive, isDiscovered, isProgressionAccountWide, isInTraining = GetSkillLineDynamicInfo(SKILL_TYPE_CLASS, skillLineIndex)
        if isActive then
            activeClassSkillLineIndex = activeClassSkillLineIndex + 1
            -- d(activeClassSkillLineIndex)
            if activeClassSkillLineIndex <= 3 then
                local _, _, _, skillLineId = GetSkillLineInfo(SKILL_TYPE_CLASS, skillLineIndex)
                local nativeSkillLineId = LSF:GetSkillLineIdFromClass(playerClassId, activeClassSkillLineIndex)
                if skillLineId ~= nativeSkillLineId then
                    return true
                end
            else
                return false
            end
        end
    end
    return false
end

local function generateShareLink()
    local buf = {bits = "", pos = 1}

    -- Race & Class
    local race = GetUnitRaceId("player")
    if race == 10 then race = 0 end
    local class = GetUnitClassId("player")
    if class == 117 then class = 7 end
    bitBufWrite(buf, race, BIT_WIDTH.RACE)
    bitBufWrite(buf, class, BIT_WIDTH.CLASS)

    -- Skills (primary 1-6, backup 1-6)
    for category = HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP do
        for slot = 3, 8 do
            local skill = GetSlotBoundId(slot, category)
            bitBufWrite(buf, skill, BIT_WIDTH.SKILL_ID)
        end
    end

    -- Active Boons & Vamp/WW
    local activeBoons = 0
    local vampWWId = 0
    local numBuffs = GetNumBuffs("player")
    if numBuffs > 0 then
        for i = 1, numBuffs do
            local _, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
            if mundusBoons[abilityId] then
                activeBoons = mundusBoons[abilityId]
            end
            if VampWW[abilityId] then
                vampWWId = VampWW[abilityId]
            end
        end
    end
    bitBufWrite(buf, activeBoons, BIT_WIDTH.ACTIVE_BOONS)
    bitBufWrite(buf, vampWWId, BIT_WIDTH.VAMPWW_ID)

    -- magicka + health + stamina + unspent = 64, 16 bits
    local magicka = GetAttributeSpentPoints(ATTRIBUTE_MAGICKA)
    local health = GetAttributeSpentPoints(ATTRIBUTE_HEALTH)
    local stamina = GetAttributeSpentPoints(ATTRIBUTE_STAMINA)
    local rank = 0
    for i = 0, magicka - 1 do 
        rank = rank + (66 - i) * (65 - i) / 2 
    end
    for i = 0, health - 1 do 
        rank = rank + (65 - magicka - i) 
    end
    rank = rank + stamina
    bitBufWrite(buf, rank, BIT_WIDTH.ATTRIBUTE)

    bitBufWrite(buf, GetPlayerStat(STAT_MAGICKA_MAX), BIT_WIDTH.MAX_STAT)
    bitBufWrite(buf, GetPlayerStat(STAT_HEALTH_MAX), BIT_WIDTH.MAX_STAT)
    bitBufWrite(buf, GetPlayerStat(STAT_STAMINA_MAX), BIT_WIDTH.MAX_STAT)

    bitBufWrite(buf, math.min(GetPlayerStat(STAT_MAGICKA_REGEN_COMBAT), 2 ^ BIT_WIDTH.REGEN - 1), BIT_WIDTH.REGEN)
    bitBufWrite(buf, math.min(GetPlayerStat(STAT_HEALTH_REGEN_COMBAT), 2 ^ BIT_WIDTH.REGEN - 1), BIT_WIDTH.REGEN)
    bitBufWrite(buf, math.min(GetPlayerStat(STAT_STAMINA_REGEN_COMBAT), 2 ^ BIT_WIDTH.REGEN - 1), BIT_WIDTH.REGEN)

    bitBufWrite(buf, math.min(GetPlayerStat(STAT_SPELL_POWER), 2 ^ BIT_WIDTH.POWER - 1), BIT_WIDTH.POWER)
    bitBufWrite(buf, math.min(GetPlayerStat(STAT_POWER), 2 ^ BIT_WIDTH.POWER - 1), BIT_WIDTH.POWER)
    bitBufWrite(buf, math.min(GetPlayerStat(STAT_SPELL_CRITICAL), 2 ^ BIT_WIDTH.CRIT - 1), BIT_WIDTH.CRIT)
    bitBufWrite(buf, math.min(GetPlayerStat(STAT_CRITICAL_STRIKE), 2 ^ BIT_WIDTH.CRIT - 1), BIT_WIDTH.CRIT)

    bitBufWrite(buf, math.min(GetPlayerStat(STAT_SPELL_PENETRATION), 2 ^ BIT_WIDTH.CRIT - 1), BIT_WIDTH.CRIT)
    bitBufWrite(buf, math.min(GetPlayerStat(STAT_PHYSICAL_PENETRATION), 2 ^ BIT_WIDTH.CRIT - 1), BIT_WIDTH.CRIT)

    bitBufWrite(buf, math.min(GetPlayerStat(STAT_SPELL_RESIST), 2 ^ BIT_WIDTH.RESIST - 1), BIT_WIDTH.RESIST)
    bitBufWrite(buf, math.min(GetPlayerStat(STAT_PHYSICAL_RESIST), 2 ^ BIT_WIDTH.RESIST - 1), BIT_WIDTH.RESIST)

    -- Food buff type bitmask (6 bits)
    local foodBuffType = 0
    local numBuffs = GetNumBuffs("player")
    for i = 1, numBuffs do
        local _, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
        if FOOD_BUFF_ABILITY_MAP[abilityId] and foodBuffType == 0 then
            foodBuffType = FOOD_BUFF_ABILITY_MAP[abilityId]
        end
    end
    if foodBuffType > FOOD_BUFF_SPECIAL_VAMPIRE then
        foodBuffType = foodBuffType - FOOD_BUFF_SPECIAL_VAMPIRE
    end
    bitBufWrite(buf, foodBuffType, BIT_WIDTH.FOOD_BUFF)

    for _, slotId in ipairs(EQUIP_SLOT_ORDER) do
        local itemLink = GetItemLink(BAG_WORN, slotId)
        if itemLink ~= "" then
            bitBufWrite(buf, 1, 1) -- occupied
            bitBufWrite(buf, GetItemLinkItemId(itemLink), BIT_WIDTH.ITEM_ID)
            bitBufWrite(buf, GetItemLinkDisplayQuality(itemLink), BIT_WIDTH.QUALITY)
            bitBufWrite(buf, GetItemLinkTraitInfo(itemLink), BIT_WIDTH.TRAIT)
            local enchantId = itemLink:match("|H[^:]+:item:[^:]+:[^:]+:[^:]+:([^:]+):") or 0
            bitBufWrite(buf, enchantId, BIT_WIDTH.ENCHANT_ID)
            bitBufWrite(buf, GetEnchantQuality(itemLink), BIT_WIDTH.ENCHANT_QUALITY)
        else
            bitBufWrite(buf, 0, 1) -- empty
        end
    end

    -- Champion bar slots
    local cBarStart, cBarEnd = GetAssignableChampionBarStartAndEndSlots()
    for disciplineIndex = 1, GetNumChampionDisciplines() do
        for CSlotIndex = cBarStart, cBarEnd do
            if disciplineIndex == GetRequiredChampionDisciplineIdForSlot(CSlotIndex, HOTBAR_CATEGORY_CHAMPION) then
                local CSlotId = GetSlotBoundId(CSlotIndex, HOTBAR_CATEGORY_CHAMPION)
                bitBufWrite(buf, CSlotId, BIT_WIDTH.CP_SLOT)
            end
        end
    end

    -- Determine Class Mastery passives (if any) for non-subclassing characters
    local useClassMastery = false
    local masteryPassive1, masteryPassive2
    if not IsSubclassing() then
        local classId = GetUnitClassId("player")
        local masterySkillLineId = LSF:GetClassMasterySkillLineId(classId)
        local _, masteryESOIndex = GetSkillLineIndicesFromSkillLineId(masterySkillLineId)
        if masteryESOIndex then
            for i = 1, 5 do
                local _, _, _, _, _, isPurchased = GetSkillAbilityInfo(SKILL_TYPE_CLASS, masteryESOIndex, i)
                if isPurchased then
                    if not masteryPassive1 then
                        masteryPassive1 = i
                        useClassMastery = true
                    elseif not masteryPassive2 then
                        masteryPassive2 = i
                    end
                end
            end
        end
    end

    if useClassMastery then
        -- Class Mastery: write 2 passive indices and left the 3rd empty
        bitBufWrite(buf, masteryPassive1 or 0, BIT_WIDTH.SKILL_LINE)
        bitBufWrite(buf, masteryPassive2 or 0, BIT_WIDTH.SKILL_LINE)
        bitBufWrite(buf, 0, BIT_WIDTH.SKILL_LINE)
    else
        -- Subclassing (or pure class with no mastery passives): write 3 active skill line LSF indices
        local numSkillLines = GetNumSkillLines(SKILL_TYPE_CLASS)
        local writtenLines = 0
        for skillLineIndex = 1, numSkillLines do
            local _, _, isActive = GetSkillLineDynamicInfo(SKILL_TYPE_CLASS, skillLineIndex)
            if isActive and writtenLines < 3 then
                local _, _, _, skillLindId = GetSkillLineInfo(SKILL_TYPE_CLASS, skillLineIndex)
                bitBufWrite(buf, LSF:GetSkillLineLSFIndexFromSkillLineId(skillLindId), BIT_WIDTH.SKILL_LINE)
                writtenLines = writtenLines + 1
            end
        end
        while writtenLines < 3 do
            bitBufWrite(buf, 0, BIT_WIDTH.SKILL_LINE)
            writtenLines = writtenLines + 1
        end
    end

    local resultSharelink = ZO_LinkHandler_CreateLink(SUPERSTAR_SHARE_NAME, nil, SUPERSTAR_SHARE, bitBufEncode(buf))
    for category = HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP do
        for slot = 3, 8 do
            local abilityId = GetSlotBoundId(slot, category)
            if craftedAbilityDict[abilityId] then
                craftedAbilityDict[abilityId] = false
                local script1, script2, script3 = GetCraftedAbilityActiveScriptIds(abilityId)
                local msg = "|H1:crafted_ability:" .. abilityId .. ":" .. script1 .. ":" .. script2 .. ":" .. script3 .. "|h|h"
                resultSharelink = resultSharelink .. msg
            end
        end
    end
    InitCraftedAbilityDict()
    return resultSharelink
end

local function insertShareLink()
	CHAT_SYSTEM.textEntry:InsertLink(generateShareLink())
end


function SuperStar:fetchShareLink()
    return generateShareLink()
end

local function createIngameShareLink()
    local setEquipped = {}
    for _, slotId in ipairs(EQUIP_SLOT_ORDER) do
        local itemLink = GetItemLink(BAG_WORN, slotId, LINK_STYLE_BRACKETS)
        local hasSet, _, _, _, maxEquipped, setId = GetItemLinkSetInfo(itemLink, true)
        if hasSet then
            local isTwoHanded = GetItemLinkWeaponType(itemLink) == WEAPONTYPE_HEALING_STAFF or
            GetItemLinkWeaponType(itemLink) == WEAPONTYPE_FIRE_STAFF or
            GetItemLinkWeaponType(itemLink) == WEAPONTYPE_FROST_STAFF or
            GetItemLinkWeaponType(itemLink) == WEAPONTYPE_LIGHTNING_STAFF or
            GetItemLinkWeaponType(itemLink) == WEAPONTYPE_BOW or
            GetItemLinkWeaponType(itemLink) == WEAPONTYPE_TWO_HANDED_AXE or
            GetItemLinkWeaponType(itemLink) == WEAPONTYPE_TWO_HANDED_HAMMER or
            GetItemLinkWeaponType(itemLink) == WEAPONTYPE_TWO_HANDED_SWORD
            local count
            if isTwoHanded then
                count = 2
            else
                count = 1
            end
            if not setEquipped[setId] then
                setEquipped[setId] = {numEquipped = count, link = itemLink, maxEquipped = maxEquipped}
            else
                setEquipped[setId].numEquipped = setEquipped[setId].numEquipped + count
                setEquipped[setId].link = itemLink
            end
        end
    end
    for _, data in pairs(setEquipped) do
        if data.numEquipped >= data.maxEquipped then
            CHAT_SYSTEM.textEntry:InsertLink(data.link)
        end
    end
    
    local skillPri1 = GetSlotBoundId(3, HOTBAR_CATEGORY_PRIMARY) -- 6 each
    local skillPri2 = GetSlotBoundId(4, HOTBAR_CATEGORY_PRIMARY)
    local skillPri3 = GetSlotBoundId(5, HOTBAR_CATEGORY_PRIMARY)
    local skillPri4 = GetSlotBoundId(6, HOTBAR_CATEGORY_PRIMARY)
    local skillPri5 = GetSlotBoundId(7, HOTBAR_CATEGORY_PRIMARY)
    local skillPri6 = GetSlotBoundId(8, HOTBAR_CATEGORY_PRIMARY)
    local skillBac1 = GetSlotBoundId(3, HOTBAR_CATEGORY_BACKUP)
    local skillBac2 = GetSlotBoundId(4, HOTBAR_CATEGORY_BACKUP)
    local skillBac3 = GetSlotBoundId(5, HOTBAR_CATEGORY_BACKUP)
    local skillBac4 = GetSlotBoundId(6, HOTBAR_CATEGORY_BACKUP)
    local skillBac5 = GetSlotBoundId(7, HOTBAR_CATEGORY_BACKUP)
    local skillBac6 = GetSlotBoundId(8, HOTBAR_CATEGORY_BACKUP)
    local skills = {skillPri1, skillPri2, skillPri3, skillPri4, skillPri5, skillPri6, 
    skillBac1, skillBac2, skillBac3, skillBac4, skillBac5, skillBac6}
    for i, v in pairs(skills) do
        local abilityId = v
        if craftedAbilityDict[abilityId] then
            craftedAbilityDict[abilityId] = false
            local script1, script2, script3 = GetCraftedAbilityActiveScriptIds(abilityId)
            local msg = "|H1:crafted_ability:" .. abilityId .. ":" .. script1 .. ":" .. script2 .. ":" .. script3 .. "|h|h"
            CHAT_SYSTEM.textEntry:InsertLink(msg)
        end
    end
    InitCraftedAbilityDict()
end

local MAIN_STUFF_ROW_ORDER = {
    EQUIP_SLOT_HEAD,
    EQUIP_SLOT_SHOULDERS,
    EQUIP_SLOT_CHEST,
    EQUIP_SLOT_HAND,
    EQUIP_SLOT_WAIST,
    EQUIP_SLOT_LEGS,
    EQUIP_SLOT_FEET,
    EQUIP_SLOT_NECK,
    EQUIP_SLOT_RING1,
    EQUIP_SLOT_RING2,
    EQUIP_SLOT_MAIN_HAND,
    EQUIP_SLOT_OFF_HAND,
    EQUIP_SLOT_BACKUP_MAIN,
    EQUIP_SLOT_BACKUP_OFF
}

local COMPANION_STUFF_ROW_ORDER = {
    EQUIP_SLOT_HEAD,
    EQUIP_SLOT_SHOULDERS,
    EQUIP_SLOT_CHEST,
    EQUIP_SLOT_HAND,
    EQUIP_SLOT_WAIST,
    EQUIP_SLOT_LEGS,
    EQUIP_SLOT_FEET,
    EQUIP_SLOT_NECK,
    EQUIP_SLOT_RING1,
    EQUIP_SLOT_RING2,
    EQUIP_SLOT_MAIN_HAND,
    EQUIP_SLOT_OFF_HAND
}

local function EnsureMainSceneVirtualControls(control)
    if control.superStarMainVirtualControlsReady then
        return
    end

    local controlName = control:GetName()

    for index, slotId in ipairs(MAIN_STUFF_ROW_ORDER) do
        local rowControl = CreateControlFromVirtual(controlName .. "Stuff" .. slotId, control,
            "SuperStarXMLMainStuffRowTemplate")
        rowControl:ClearAnchors()
        rowControl:SetAnchor(TOPLEFT, control, TOPLEFT, 10, 180 + ((index - 1) * 40))

        local labelControl = rowControl:GetNamedChild("Label")
        labelControl:ClearAnchors()
        labelControl:SetAnchor(TOPLEFT, rowControl, TOPLEFT, 0, 0)

        if slotId == EQUIP_SLOT_BACKUP_MAIN or slotId == EQUIP_SLOT_BACKUP_OFF then
            local enchantControl = rowControl:GetNamedChild("Enchant")
            enchantControl:SetDimensions(300, 20)
            enchantControl:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
        end
    end

    control.superStarMainVirtualControlsReady = true
end

local function EnsureCompanionSceneVirtualControls(control)
    if control.superStarCompanionVirtualControlsReady then
        return
    end

    local controlName = control:GetName()
    for index, slotId in ipairs(COMPANION_STUFF_ROW_ORDER) do
        local rowControl = CreateControlFromVirtual(controlName .. "Stuff" .. slotId, control,
            "SuperStarXMLCompStuffTemplate")
        rowControl:ClearAnchors()
        rowControl:SetAnchor(TOPLEFT, control, TOPLEFT, 10, 180 + ((index - 1) * 40))
    end

    control.superStarCompanionVirtualControlsReady = true
end

local function GetMainStuffRowControls(control, slotId)
    local rowControl = control:GetNamedChild("Stuff" .. slotId)
    return rowControl:GetNamedChild("Label"), rowControl:GetNamedChild("Value"), rowControl:GetNamedChild("Level"),
        rowControl:GetNamedChild("Trait"), rowControl:GetNamedChild("Enchant")
end

local function BuildMainSceneShare(dataString, text)
    SCENE_MANAGER:Show("SuperStarMain")
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME)

    local craftedAblityList
    if cachedChatboxInfo[dataString:sub(-10)] then
        GetControl("LMMXMLSceneGroupBarLabel"):SetText(cachedChatboxInfo[dataString:sub(-10)]["name"])
        if cachedChatboxInfo[dataString:sub(-10)]["abilityList"] then
            craftedAblityList = cachedChatboxInfo[dataString:sub(-10)]["abilityList"]
        end
    end
    -- ZO_MenuBar_ClearButtons(LMMXMLSceneGroupBar)
    ZO_MenuBar_UpdateButtons(LMMXMLSceneGroupBar)
    KEYBIND_STRIP:RemoveKeybindButtonGroup(summaryKeybindStripDescriptor)

    local buf = bitBufDecode(dataString)
    if not buf then return end

    local control  = SuperStarXMLMainCharacter
    control:SetHidden(false)
    EnsureMainSceneVirtualControls(control)

    -- local playerAlliance = bitBufRead(buf, 2)
    local race = bitBufRead(buf, BIT_WIDTH.RACE)
    if race == 0 then
        race = 10
    end
    local class = bitBufRead(buf, BIT_WIDTH.CLASS)
    if class == 7 then
        class = 117
    end
    -- local dataString, rank = truncateTail(dataString, 2)
    -- local dataString, skillPoints = truncateTail(dataString, 3)
    -- local dataString, championPoints = truncateTail(dataString, 4)
    -- local playerLevel
    -- if tostring(championPoints):sub(1, 2) == "88" then
    --     championPoints = 0
    --     playerLevel = tonumber(tostring(championPoints):sub(3, 4))
    -- else
    --     playerLevel = 50
    -- end

    local maxStuffRank = GetMaxLevel()
    -- local showCPIcon
    -- if championPoints > 0 then
    --     maxStuffRank = math.min(GetChampionPointsPlayerProgressionCap(), championPoints)
    --     showCPIcon = true
    -- end
    local SkillPointsLabel = control:GetNamedChild("SkillPointsLabel")
    SkillPointsLabel:SetHidden(true)
    local ChampionPointsLabel = control:GetNamedChild("ChampionPointsLabel")
    ChampionPointsLabel:SetHidden(true)
    local LevelValue = control:GetNamedChild("LevelValue")
    local LevelValue = control:GetNamedChild("LevelValue")
    LevelValue:SetText("")
    local CPIcon = control:GetNamedChild("CPIcon")
    CPIcon:SetTexture(GetChampionPointsIcon())
    CPIcon:SetHidden(true)
    local ClassAndRaceValue = control:GetNamedChild("ClassAndRaceValue")
    ClassAndRaceValue:SetText(zo_strformat(SI_STATS_RACE_CLASS, GetRaceName(nil, race), GetClassName(nil, class)))
    ClassAndRaceValue:SetFont("ZoFontWindowTitle")

    local shareRaceIcon = control:GetNamedChild("ShareRaceIcon")
    local shareClassIcon = control:GetNamedChild("ShareClassIcon")
    shareRaceIcon:SetTexture(GetRaceIcon(race))
    shareRaceIcon:SetHidden(false)
    local classIndex = GetClassIndexById(class)
    local _, _, classNormalIcon = GetClassInfo(classIndex)
    shareClassIcon:SetTexture(classNormalIcon)
    shareClassIcon:SetHidden(false)
    ClassAndRaceValue:SetAnchor(LEFT, shareClassIcon, RIGHT, -5, 2)

    local AllianceTexture = control:GetNamedChild("AllianceTexture")
    local AvaRankTexture = control:GetNamedChild("AvaRankTexture")
    local AvaRankName = control:GetNamedChild("AvaRankName")
    local AvaRankValue = control:GetNamedChild("AvaRankValue")
    AllianceTexture:SetTexture("/esoui/art/icons/blank.dds")
    AvaRankValue:SetText("")
    AvaRankName:SetText("")
    AvaRankTexture:SetTexture("/esoui/art/icons/blank.dds")
    local SkillPointsValue = control:GetNamedChild("SkillPointsValue")
    SkillPointsValue:SetText("")
    local ChampionPointsValue = control:GetNamedChild("ChampionPointsValue")
    ChampionPointsValue:SetText("")


    -- local mainIndex = bitBufRead(buf, 6)
    -- local offIndex = bitBufRead(buf, 6)
    local skillPri1 = bitBufRead(buf, BIT_WIDTH.SKILL_ID)
    local skillPri2 = bitBufRead(buf, BIT_WIDTH.SKILL_ID)
    local skillPri3 = bitBufRead(buf, BIT_WIDTH.SKILL_ID)
    local skillPri4 = bitBufRead(buf, BIT_WIDTH.SKILL_ID)
    local skillPri5 = bitBufRead(buf, BIT_WIDTH.SKILL_ID)
    local skillPri6 = bitBufRead(buf, BIT_WIDTH.SKILL_ID)
    local skillBac1 = bitBufRead(buf, BIT_WIDTH.SKILL_ID)
    local skillBac2 = bitBufRead(buf, BIT_WIDTH.SKILL_ID)
    local skillBac3 = bitBufRead(buf, BIT_WIDTH.SKILL_ID)
    local skillBac4 = bitBufRead(buf, BIT_WIDTH.SKILL_ID)
    local skillBac5 = bitBufRead(buf, BIT_WIDTH.SKILL_ID)
    local skillBac6 = bitBufRead(buf, BIT_WIDTH.SKILL_ID)

    local ActiveMWeapon = control:GetNamedChild("ActiveMWeapon")
    local ActiveMSkill1 = control:GetNamedChild("ActiveMSkill1")
    local ActiveMSkill2 = control:GetNamedChild("ActiveMSkill2")
    local ActiveMSkill3 = control:GetNamedChild("ActiveMSkill3")
    local ActiveMSkill4 = control:GetNamedChild("ActiveMSkill4")
    local ActiveMSkill5 = control:GetNamedChild("ActiveMSkill5")
    local ActiveMSkill6 = control:GetNamedChild("ActiveMSkill6")
    local ActiveOWeapon = control:GetNamedChild("ActiveOWeapon")
    local ActiveOSkill1 = control:GetNamedChild("ActiveOSkill1")
    local ActiveOSkill2 = control:GetNamedChild("ActiveOSkill2")
    local ActiveOSkill3 = control:GetNamedChild("ActiveOSkill3")
    local ActiveOSkill4 = control:GetNamedChild("ActiveOSkill4")
    local ActiveOSkill5 = control:GetNamedChild("ActiveOSkill5")
    local ActiveOSkill6 = control:GetNamedChild("ActiveOSkill6")
    -- ActiveMWeapon:SetHidden(true)
    -- ActiveOWeapon:SetHidden(true)
    ShowSlotTexture(ActiveMSkill1, skillPri1)
    ShowSlotTexture(ActiveMSkill2, skillPri2)
    ShowSlotTexture(ActiveMSkill3, skillPri3)
    ShowSlotTexture(ActiveMSkill4, skillPri4)
    ShowSlotTexture(ActiveMSkill5, skillPri5)
    ShowSlotTexture(ActiveMSkill6, skillPri6)
    ShowSlotTexture(ActiveOSkill1, skillBac1)
    ShowSlotTexture(ActiveOSkill2, skillBac2)
    ShowSlotTexture(ActiveOSkill3, skillBac3)
    ShowSlotTexture(ActiveOSkill4, skillBac4)
    ShowSlotTexture(ActiveOSkill5, skillBac5)
    ShowSlotTexture(ActiveOSkill6, skillBac6)

    -- Lykeion@6.0.0
    local scribing = control:GetNamedChild("Scribing")
    scribing:SetHidden(true)
    local list = scribing:GetNamedChild("List")
    hideChildrenControls(list)
    if craftedAblityList ~= nil then
        scribing:SetHidden(false)
        local VIRTUALNAME = "SuperStarScribingSkillFrameReadOnly"
        local windowIndex = 0
        for i, craftedAbilityInfo in ipairs(craftedAblityList) do
            -- Build up crafted ability info
            local windowName = VIRTUALNAME .. windowIndex
            windowIndex = windowIndex + 1
            local SSkillFrame = GetControl(windowName)
            if not SSkillFrame then
                -- CreateControlFromVirtual(controlName, parent, templateName)
                SSkillFrame = CreateControlFromVirtual(windowName, list, VIRTUALNAME)
            end
            SSkillFrame:SetHidden(false)
    
            SSkillFrame.abilityId = GetAbilityIdForCraftedAbilityId(tonumber(craftedAbilityInfo[SCRIBING_SLOT_NONE]))
            SSkillFrame:GetNamedChild("Icon"):SetTexture(GetCraftedAbilityDisplayIcon(tonumber(craftedAbilityInfo[SCRIBING_SLOT_NONE])))
    
            local skillLineName = GetCraftedAbilitySkilllineName(tonumber(craftedAbilityInfo[SCRIBING_SLOT_NONE]))
            -- GetSkillLineNameById(LSF:GetSkillLineIdFromLSFIndex(skillType, skillLineIndex))
            -- local abilityName = GetAbilityName(GetAbilityIdForCraftedAbilityId(v[SCRIBING_SLOT_NONE]))
            SetCraftedAbilityScriptSelectionOverride(tonumber(craftedAbilityInfo[SCRIBING_SLOT_NONE]), craftedAbilityInfo[SCRIBING_SLOT_PRIMARY], craftedAbilityInfo[SCRIBING_SLOT_SECONDARY], craftedAbilityInfo[SCRIBING_SLOT_TERTIARY])
            SSkillFrame:GetNamedChild("MainText"):SetText(skillLineName .. " / " .. GetAbilityName(GetCraftedAbilityRepresentativeAbilityId(tonumber(craftedAbilityInfo[SCRIBING_SLOT_NONE]))))
            ResetCraftedAbilityScriptSelectionOverride()
            SSkillFrame:GetNamedChild("SubText"):SetText(GetCraftedAbilityScriptDisplayName(craftedAbilityInfo[SCRIBING_SLOT_PRIMARY]) .. " / " ..
                                                        GetCraftedAbilityScriptDisplayName(craftedAbilityInfo[SCRIBING_SLOT_SECONDARY]) .. " / " ..
                                                        GetCraftedAbilityScriptDisplayName(craftedAbilityInfo[SCRIBING_SLOT_TERTIARY]))
    
            local SSkillAnchor = ZO_Anchor:New(TOPLEFT, list, TOPLEFT, 0, 0)
            SSkillAnchor:SetOffsets(0, (windowIndex - 1) * 60)
            SSkillAnchor:Set(SSkillFrame)
        end
    end

    local activeBoons = bitBufRead(buf, BIT_WIDTH.ACTIVE_BOONS)
    local vampWWId = bitBufRead(buf, BIT_WIDTH.VAMPWW_ID)
    local MundusBoonValue = control:GetNamedChild("MundusBoonValue")
    if activeBoons ~= 0 then
        for k, v in pairs(mundusBoons) do
            if v == activeBoons then
                activeBoons = k
                break
            end
        end
        MundusBoonValue:SetText(zo_strformat(SI_ABILITY_TOOLTIP_NAME, GetAbilityName(activeBoons)))
    else
        MundusBoonValue:SetText(SUPERSTAR_GENERIC_NA)
    end 
    local VampWWVIcon = control:GetNamedChild("VampWWVIcon")
    local VampWWValue = control:GetNamedChild("VampWWValue")
    if vampWWId ~= 0 then
        for k, v in pairs(VampWW) do
            if v == vampWWId then
                vampWWId = k
                break
            end
        end
        VampWWVIcon:SetTexture(getStaticVampWWIconFile(vampWWId))
        VampWWValue:SetText(zo_strformat(SI_ABILITY_TOOLTIP_NAME, GetAbilityName(vampWWId)))
        VampWWVIcon:SetHidden(false)
        VampWWValue:SetHidden(false)
    else
        VampWWVIcon:SetHidden(true)
        VampWWValue:SetHidden(true)
    end 
    local rank = bitBufRead(buf, BIT_WIDTH.ATTRIBUTE)
    -- Decode Attributes
    local magickaAttr = 0
    local prefix = 0
    while magickaAttr < 64 do
        local next = (66 - magickaAttr) * (65 - magickaAttr) / 2
        if prefix + next <= rank then
            prefix = prefix + next
            magickaAttr = magickaAttr + 1
        else
            break
        end
    end
    rank = rank - prefix

    local healthAttr = 0
    local healthPrefix = 0
    while healthAttr < 64 - magickaAttr do
        local next = 65 - magickaAttr - healthAttr
        if healthPrefix + next <= rank then
            healthPrefix = healthPrefix + next
            healthAttr = healthAttr + 1
        else
            break
        end
    end
    local staminaAttr = rank - healthPrefix
    local magMax = bitBufRead(buf, BIT_WIDTH.MAX_STAT)
    local heaMax = bitBufRead(buf, BIT_WIDTH.MAX_STAT)
    local staMax = bitBufRead(buf, BIT_WIDTH.MAX_STAT)
    local magReg = bitBufRead(buf, BIT_WIDTH.REGEN)
    local heaReg = bitBufRead(buf, BIT_WIDTH.REGEN)
    local staReg = bitBufRead(buf, BIT_WIDTH.REGEN)
    local magDmg = bitBufRead(buf, BIT_WIDTH.POWER)
    local staDmg = bitBufRead(buf, BIT_WIDTH.POWER)
    local magCri = bitBufRead(buf, BIT_WIDTH.CRIT)
    local staCri = bitBufRead(buf, BIT_WIDTH.CRIT)
    local magPen = bitBufRead(buf, BIT_WIDTH.CRIT)
    local staPen = bitBufRead(buf, BIT_WIDTH.CRIT)
    local magRes = bitBufRead(buf, BIT_WIDTH.RESIST)
    local staRes = bitBufRead(buf, BIT_WIDTH.RESIST)
    local foodBuffType = bitBufRead(buf, BIT_WIDTH.FOOD_BUFF)

    local MagickaAttributeLabel = control:GetNamedChild("MagickaAttributeLabel")
    local HealthAttributeLabel = control:GetNamedChild("HealthAttributeLabel")
    local StaminaAttributeLabel = control:GetNamedChild("StaminaAttributeLabel")
    local MagickaAttributePoints = control:GetNamedChild("MagickaAttributePoints")
    local HealthAttributePoints = control:GetNamedChild("HealthAttributePoints")
    local StaminaAttributePoints = control:GetNamedChild("StaminaAttributePoints")
    local MagickaAttributeRegen = control:GetNamedChild("MagickaAttributeRegen")
    local HealthAttributeRegen = control:GetNamedChild("HealthAttributeRegen")
    local StaminaAttributeRegen = control:GetNamedChild("StaminaAttributeRegen")
    MagickaAttributeLabel:SetText(magickaAttr)
    HealthAttributeLabel:SetText(healthAttr)
    StaminaAttributeLabel:SetText(staminaAttr)
    MagickaAttributePoints:SetText(magMax)
    HealthAttributePoints:SetText(heaMax)
    StaminaAttributePoints:SetText(staMax)
    MagickaAttributeRegen:SetText(magReg)
    HealthAttributeRegen:SetText(heaReg)
    StaminaAttributeRegen:SetText(staReg)

    -- Inline food buff arrows driven by share link data
    local FoodBonusControl = {}
    FoodBonusControl[FOOD_BUFF_MAX_HEALTH] = control:GetNamedChild("MaxHealth")
    FoodBonusControl[FOOD_BUFF_MAX_MAGICKA] = control:GetNamedChild("MaxMagicka")
    FoodBonusControl[FOOD_BUFF_MAX_STAMINA] = control:GetNamedChild("MaxStamina")
    FoodBonusControl[FOOD_BUFF_REGEN_HEALTH] = control:GetNamedChild("RegenHealth")
    FoodBonusControl[FOOD_BUFF_REGEN_MAGICKA] = control:GetNamedChild("RegenMagicka")
    FoodBonusControl[FOOD_BUFF_REGEN_STAMINA] = control:GetNamedChild("RegenStamina")
    FoodBonusControl[FOOD_BUFF_MAX_HEALTH]:SetHidden(true)
    FoodBonusControl[FOOD_BUFF_MAX_MAGICKA]:SetHidden(true)
    FoodBonusControl[FOOD_BUFF_MAX_STAMINA]:SetHidden(true)
    FoodBonusControl[FOOD_BUFF_REGEN_HEALTH]:SetHidden(true)
    FoodBonusControl[FOOD_BUFF_REGEN_MAGICKA]:SetHidden(true)
    FoodBonusControl[FOOD_BUFF_REGEN_STAMINA]:SetHidden(true)
    local fbType = foodBuffType
    if fbType > FOOD_BUFF_SPECIAL_VAMPIRE then
        fbType = fbType - FOOD_BUFF_SPECIAL_VAMPIRE
    end
    local arrowVals = {FOOD_BUFF_MAX_HEALTH, FOOD_BUFF_MAX_MAGICKA, FOOD_BUFF_MAX_STAMINA, FOOD_BUFF_REGEN_HEALTH,
                       FOOD_BUFF_REGEN_MAGICKA, FOOD_BUFF_REGEN_STAMINA}
    local i = #arrowVals
    while fbType ~= 0 and i > 0 do
        if arrowVals[i] <= fbType then
            fbType = fbType - arrowVals[i]
            FoodBonusControl[arrowVals[i]]:SetHidden(false)
        end
        i = i - 1
    end

    local MagickaDmg = control:GetNamedChild("MagickaDmg")
    local StaminaDmg = control:GetNamedChild("StaminaDmg")
    local MagickaCrit = control:GetNamedChild("MagickaCrit")
    local StaminaCrit = control:GetNamedChild("StaminaCrit")
    local MagickaCritPercent = control:GetNamedChild("MagickaCritPercent")
    local StaminaCritPercent = control:GetNamedChild("StaminaCritPercent")
    local MagickaPene = control:GetNamedChild("MagickaPene")
    local StaminaPene = control:GetNamedChild("StaminaPene")
    local MagickaResist = control:GetNamedChild("MagickaResist")
    local StaminaResist = control:GetNamedChild("StaminaResist")
    local MagickaResistPercent = control:GetNamedChild("MagickaResistPercent")
    local StaminaResistPercent = control:GetNamedChild("StaminaResistPercent")
    local magickaColor = GetItemQualityColor(ITEM_QUALITY_ARCANE)
    local staminaColor = GetItemQualityColor(ITEM_QUALITY_MAGIC)
    MagickaDmg:SetText(magDmg)
    StaminaDmg:SetText(staDmg)
    MagickaDmg:SetColor(magickaColor.r, magickaColor.g, magickaColor.b)
    StaminaDmg:SetColor(staminaColor.r, staminaColor.g, staminaColor.b)
    local spellCritical = magCri
    local weaponCritical = staCri
    MagickaCrit:SetText(spellCritical)
    StaminaCrit:SetText(weaponCritical)
    -- MagickaCrit:SetColor(magickaColor.r, magickaColor.g, magickaColor.b)
    -- StaminaCrit:SetColor(staminaColor.r, staminaColor.g, staminaColor.b)
    MagickaCritPercent:SetText(zo_strformat(SI_STAT_VALUE_PERCENT, GetCriticalStrikeChance(spellCritical, true)))
    StaminaCritPercent:SetText(zo_strformat(SI_STAT_VALUE_PERCENT, GetCriticalStrikeChance(weaponCritical, true)))
    MagickaCritPercent:SetColor(magickaColor.r, magickaColor.g, magickaColor.b)
    StaminaCritPercent:SetColor(staminaColor.r, staminaColor.g, staminaColor.b)
    MagickaPene:SetText(magPen)
    StaminaPene:SetText(staPen)
    MagickaPene:SetColor(magickaColor.r, magickaColor.g, magickaColor.b)
    StaminaPene:SetColor(staminaColor.r, staminaColor.g, staminaColor.b)
    local spellResist = magRes
    local weaponResist = staRes
    MagickaResist:SetText(spellResist)
    StaminaResist:SetText(weaponResist)
    -- MagickaResist:SetColor(magickaColor.r, magickaColor.g, magickaColor.b)
    -- StaminaResist:SetColor(staminaColor.r, staminaColor.g, staminaColor.b)
    local championPointsForStatsCalculation = GetChampionPointsPlayerProgressionCap() / 10
    local spellResistPercent = math.max((spellResist - 100), 0) / ((50 + championPointsForStatsCalculation) * 10)
    local weaponResistPercent = math.max((weaponResist - 100), 0) / ((50 + championPointsForStatsCalculation) * 10)
    MagickaResistPercent:SetText(zo_strformat(SI_STAT_VALUE_PERCENT, spellResistPercent))
    StaminaResistPercent:SetText(zo_strformat(SI_STAT_VALUE_PERCENT, weaponResistPercent))
    MagickaResistPercent:SetColor(magickaColor.r, magickaColor.g, magickaColor.b)
    StaminaResistPercent:SetColor(staminaColor.r, staminaColor.g, staminaColor.b)
    if spellResistPercent > 50 then
        MagickaResistPercent:SetColor(1, 0, 0)
    end
    if weaponResistPercent > 50 then
        StaminaResistPercent:SetColor(1, 0, 0)
    end

    -- Food buff info panel
    for i = 1, 4 do
        local oldRow = GetControl("FoodBuffRow" .. i)
        if oldRow then oldRow:SetHidden(true) end
    end
    -- if foodBuffType > FOOD_BUFF_SPECIAL_VAMPIRE then
    --     foodBuffType = foodBuffType - FOOD_BUFF_SPECIAL_VAMPIRE
    -- end
    local originalFoodType = foodBuffType
    local vals = {FOOD_BUFF_REGEN_STAMINA, FOOD_BUFF_REGEN_MAGICKA, FOOD_BUFF_REGEN_HEALTH, FOOD_BUFF_MAX_STAMINA,
                  FOOD_BUFF_MAX_MAGICKA, FOOD_BUFF_MAX_HEALTH}
    local rows = {}
    for _, v in ipairs(vals) do
        if v <= foodBuffType then
            foodBuffType = foodBuffType - v
            table.insert(rows, v)
        end
    end
    local rowCount = #rows
    local fbInfo = control:GetNamedChild("FoodBuffInfo")
    local foodIconTexture = fbInfo:GetNamedChild("Icon")
    if rowCount > 0 then
        local abilityId = GetFoodBuffAbilityId(originalFoodType)
        if abilityId then
            foodIconTexture:SetTexture(GetAbilityIcon(abilityId))
        end
        foodIconTexture:SetHidden(false)
        local labelH = 18
        local gapY = 5
        local totalTextH = rowCount * labelH + (rowCount - 1) * gapY
        local _, iconH = foodIconTexture:GetDimensions()
        local firstRowY = iconH / 2 - totalTextH / 2 - 3

        for i, foodType in ipairs(rows) do
            local rowName = "FoodBuffRow" .. i
            local row = GetControl(rowName)
            if not row then
                row = CreateControlFromVirtual(rowName, fbInfo, "SuperStarXMLFoodBuffRowTemplate")
            end
            row:SetHidden(false)
            local rowLabel = row:GetNamedChild("Label")
            rowLabel:SetText("+ " .. GetString(FOOD_TYPE_I18N[foodType]))
            rowLabel:SetHidden(false)
            rowLabel:ClearAnchors()
            local rowY = firstRowY + (i - 1) * (labelH + gapY)
            rowLabel:SetAnchor(TOPLEFT, foodIconTexture, TOPLEFT, iconH + 8, rowY)
        end
    else
        foodIconTexture:SetTexture(GetAbilityIcon(47856))
        foodIconTexture:SetHidden(false)
        local _, iconH = foodIconTexture:GetDimensions()
        local firstRowY = iconH / 2 - 9
        local row = GetControl("FoodBuffRow1")
        if not row then
            row = CreateControlFromVirtual("FoodBuffRow1", fbInfo, "SuperStarXMLFoodBuffRowTemplate")
        end
        row:SetHidden(false)
        local rowLabel = row:GetNamedChild("Label")
        rowLabel:SetText(zo_strformat(GetString(SI_DEATH_PROMPT_NO_SOUL_GEMS_PVP), GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES403)))
        rowLabel:SetHidden(false)
        rowLabel:ClearAnchors()
        rowLabel:SetAnchor(TOPLEFT, foodIconTexture, TOPLEFT, iconH + 8, firstRowY)
        for i = 2, 4 do
            local r = GetControl("FoodBuffRow" .. i)
            if r then r:SetHidden(true) end
        end
    end


    local slots = {
        [EQUIP_SLOT_HEAD] = true,
        [EQUIP_SLOT_NECK] = true,
        [EQUIP_SLOT_CHEST] = true,
        [EQUIP_SLOT_SHOULDERS] = true,
        [EQUIP_SLOT_MAIN_HAND] = true,
        [EQUIP_SLOT_OFF_HAND] = true,
        [EQUIP_SLOT_WAIST] = true,
        [EQUIP_SLOT_LEGS] = true,
        [EQUIP_SLOT_FEET] = true,
        [EQUIP_SLOT_RING1] = true,
        [EQUIP_SLOT_RING2] = true,
        [EQUIP_SLOT_HAND] = true,
        [EQUIP_SLOT_BACKUP_MAIN] = true,
        [EQUIP_SLOT_BACKUP_OFF] = true
    }
    local SSslotData = {}
    local setEquipped = {}
    local mainWeapons = {}
    local offWeapons = {}
    for _, slotId in ipairs(EQUIP_SLOT_ORDER) do
        local occupied = bitBufRead(buf, 1)

        SSslotData[slotId] = {}
        if GetString("SUPERSTAR_SLOTNAME", slotId) ~= "" then
            SSslotData[slotId].slotName = GetString("SUPERSTAR_SLOTNAME", slotId)
        else
            SSslotData[slotId].slotName = zo_strformat(SI_ITEM_FORMAT_STR_BROAD_TYPE, GetString("SI_EQUIPSLOT", slotId))
        end

        if occupied == 1 then
            local itemId = bitBufRead(buf, BIT_WIDTH.ITEM_ID)
            local itemQuality = bitBufRead(buf, BIT_WIDTH.QUALITY)
            local itemTrait = bitBufRead(buf, BIT_WIDTH.TRAIT)
            local itemEnchantId = bitBufRead(buf, BIT_WIDTH.ENCHANT_ID)
            local itemEnchantquality = bitBufRead(buf, BIT_WIDTH.ENCHANT_QUALITY)
            -- Create a fake itemLink
            local itemLink = string.format("|H1:item:%i:%i:50:%i:370:50:%i:0:0:0:0:0:0:0:2049:9:0:1:0:2900:0|h|h", itemId, 359 + itemQuality, itemEnchantId, itemTrait)
            if slotId == EQUIP_SLOT_MAIN_HAND or slotId == EQUIP_SLOT_OFF_HAND then
                table.insert(mainWeapons, itemLink)
            elseif slotId == EQUIP_SLOT_BACKUP_MAIN or slotId == EQUIP_SLOT_BACKUP_OFF then
                table.insert(offWeapons, itemLink)
            end

            local name = GetItemLinkName(itemLink)
            local requiredLevel = GetItemLinkRequiredLevel(itemLink)
            local requiredCPRank = GetItemLinkRequiredChampionPoints(itemLink)
            local traitType, traitDescription = GetItemLinkTraitInfo(itemLink)
            local hasCharges, enchantHeader, enchantDescription = GetItemLinkEnchantInfo(itemLink)
            local quality = GetItemLinkDisplayQuality(itemLink)
            local enchantQuality = itemEnchantquality
            local armorType = GetItemLinkArmorType(itemLink)
            local icon = GetItemLinkInfo(itemLink)
            local hasSet, setName, numBonuses, numNormalEquipped, maxEquipped, setId, numPerfectedEquipped =
                GetItemLinkSetInfo(itemLink, true)
            local setMinRequires = GetItemLinkSetBonusInfo(itemLink, true, 1)
            local _, _, isPerfected = GetItemLinkSetBonusInfo(itemLink, true, math.max(numBonuses - 1, 1))

            name = GetItemQualityColor(quality):Colorize(zo_strformat(SI_TOOLTIP_ITEM_NAME, name))

            if hasSet then
                local isTwoHanded = GetItemLinkWeaponType(itemLink) == WEAPONTYPE_HEALING_STAFF or
                GetItemLinkWeaponType(itemLink) == WEAPONTYPE_FIRE_STAFF or
                GetItemLinkWeaponType(itemLink) == WEAPONTYPE_FROST_STAFF or
                GetItemLinkWeaponType(itemLink) == WEAPONTYPE_LIGHTNING_STAFF or
                GetItemLinkWeaponType(itemLink) == WEAPONTYPE_BOW or
                GetItemLinkWeaponType(itemLink) == WEAPONTYPE_TWO_HANDED_AXE or
                GetItemLinkWeaponType(itemLink) == WEAPONTYPE_TWO_HANDED_HAMMER or
                GetItemLinkWeaponType(itemLink) == WEAPONTYPE_TWO_HANDED_SWORD
                if not setEquipped[setId] then
                    if isTwoHanded then
                        setEquipped[setId] = {
                            numEquipped = 2,
                            enabled = 2 >= setMinRequires
                        }
                    else
                        setEquipped[setId] = {
                            numEquipped = 1,
                            enabled = 1 >= setMinRequires
                        }
                    end


                    -- if setEquipped[setId].isPerfected then
                    --     setEquipped[setId].numEquipped = numPerfectedEquipped
                    -- end

                    -- if setEquipped[setId].enabled then
                    --     name = zo_strformat("<<1>> " ..
                    --                             GetItemQualityColor(ITEM_QUALITY_MAGIC):Colorize(("<<2>>: <<3>>/<<4>>")),
                    --         name, GetString(SUPERSTAR_EQUIP_SET_BONUS), setEquipped[setId].numEquipped,
                    --         setEquipped[setId].maxEquipped)
                    -- else
                    --     name = zo_strformat("<<1>> |cFF0000<<2>>: <<3>>/<<4>>|r", name,
                    --         GetString(SUPERSTAR_EQUIP_SET_BONUS), setEquipped[setId].numEquipped,
                    --         setEquipped[setId].maxEquipped)
                    -- end
                else
                    if isTwoHanded then
                        setEquipped[setId] = {
                            numEquipped = setEquipped[setId].numEquipped + 2,
                            enabled = setEquipped[setId].numEquipped + 2 >= setMinRequires
                        }
                    else
                        setEquipped[setId] = {
                            numEquipped = setEquipped[setId].numEquipped + 1,
                            enabled = setEquipped[setId].numEquipped + 1 >= setMinRequires
                        }
                    end

                end
            end

            local requiredFormattedLevel
            if requiredCPRank > 0 then
                requiredFormattedLevel = "|t32:32:" .. GetChampionPointsIcon() .. "|t" .. requiredCPRank
            else
                requiredFormattedLevel = requiredLevel
            end

            local traitName
            if (traitType ~= ITEM_TRAIT_TYPE_NONE and traitType ~= ITEM_TRAIT_TYPE_SPECIAL_STAT and traitDescription ~=
                "") then
                traitName = GetString("SI_ITEMTRAITTYPE", traitType)
            else
                traitName = SUPERSTAR_GENERIC_NA
            end

            if enchantDescription == "" then
                enchantDescription = SUPERSTAR_GENERIC_NA
            else
                enchantDescription = enchantHeader
            end

            SSslotData[slotId].name = name
            SSslotData[slotId].requiredFormattedLevel = requiredFormattedLevel
            SSslotData[slotId].traitName = traitName
            SSslotData[slotId].icon = icon
            SSslotData[slotId].enchantDescription = enchantDescription

            SSslotData[slotId].labelControl, SSslotData[slotId].valueControl, SSslotData[slotId].levelControl,
                SSslotData[slotId].traitControl, SSslotData[slotId].enchantControl =
                GetMainStuffRowControls(control, slotId)

            SSslotData[slotId].labelControl:SetText(SSslotData[slotId].slotName)

            if armorType == ARMORTYPE_HEAVY then
                SSslotData[slotId].labelControl:SetColor(1, 0, 0)
            elseif armorType == ARMORTYPE_MEDIUM then
                SSslotData[slotId].labelControl:SetColor(staminaColor.r, staminaColor.g, staminaColor.b)
            elseif armorType == ARMORTYPE_LIGHT then
                SSslotData[slotId].labelControl:SetColor(magickaColor.r, magickaColor.g, magickaColor.b)
            else
                SSslotData[slotId].labelControl:SetColor(ZO_NORMAL_TEXT:UnpackRGB())
            end

            SSslotData[slotId].valueControl:SetText(SSslotData[slotId].name)
            SSslotData[slotId].valueControl.itemLink = itemLink

            if requiredCPRank < maxStuffRank then
                SSslotData[slotId].levelControl:SetColor(1, 0, 0)
            else
                SSslotData[slotId].levelControl:SetColor(1, 1, 1)
            end

            SSslotData[slotId].levelControl:SetText(SSslotData[slotId].requiredFormattedLevel)
            SSslotData[slotId].traitControl:SetText(SSslotData[slotId].traitName)
            SSslotData[slotId].enchantControl:SetText(SSslotData[slotId].enchantDescription)
            SSslotData[slotId].enchantControl:SetColor(GetItemQualityColor(enchantQuality):UnpackRGBA())
            SSslotData[slotId].enchantControl:SetAlpha(0.75)

        else
            SSslotData[slotId].dontWearSlot = true

            SSslotData[slotId].labelControl, SSslotData[slotId].valueControl, SSslotData[slotId].levelControl,
                SSslotData[slotId].traitControl, SSslotData[slotId].enchantControl =
                GetMainStuffRowControls(control, slotId)
            SSslotData[slotId].labelControl:SetText(SSslotData[slotId].slotName)
            SSslotData[slotId].labelControl:SetColor(ZO_DISABLED_TEXT:UnpackRGBA())

            SSslotData[slotId].valueControl:SetText(SUPERSTAR_GENERIC_NA)

            SSslotData[slotId].levelControl:SetText(SUPERSTAR_GENERIC_NA)
            SSslotData[slotId].traitControl:SetText(SUPERSTAR_GENERIC_NA)
            SSslotData[slotId].enchantControl:SetText(SUPERSTAR_GENERIC_NA)
            SSslotData[slotId].enchantControl:SetColor(ZO_DISABLED_TEXT:UnpackRGBA())
            SSslotData[slotId].enchantControl:SetAlpha(0.75)

        end
    end

    for slotId in pairs(slots) do
        local checkLink = SSslotData[slotId].valueControl.itemLink
        local _, _, checkNumBonuses, _, checkMaxEquipped, checkSetId, _ = GetItemLinkSetInfo(checkLink, true)
        local _, _, isPerfected = GetItemLinkSetBonusInfo(checkLink, true, math.max(checkNumBonuses - 1, 1))
        isPerfected = isPerfected and 1 or 0
        local checkName
        if setEquipped[checkSetId] then
            if setEquipped[checkSetId].enabled then
                checkName = zo_strformat("<<1>> " ..
                                        GetItemQualityColor(ITEM_QUALITY_MAGIC):Colorize(("<<2>>: <<3>>/<<4>>")),
                                        SSslotData[slotId].valueControl:GetText(), GetString(SUPERSTAR_EQUIP_SET_BONUS), setEquipped[checkSetId].numEquipped,
                                        checkMaxEquipped)
            else
                checkName = zo_strformat("<<1>> |cFF0000<<2>>: <<3>>/<<4>>|r", SSslotData[slotId].valueControl:GetText(),
                    GetString(SUPERSTAR_EQUIP_SET_BONUS), setEquipped[checkSetId].numEquipped,
                    checkMaxEquipped)
            end
            SSslotData[slotId].valueControl:SetText(checkName)
            setEquipped[checkSetId] = nil
        end
    end

    local _, mainIndex = GetWeaponIconPair(GetItemLinkWeaponType(mainWeapons[1]), GetItemLinkWeaponType(mainWeapons[2]))
    ShowSlotTexture(ActiveMWeapon, GetWeaponIconByIndex(mainIndex))
    local _, offIndex = GetWeaponIconPair(GetItemLinkWeaponType(offWeapons[1]), GetItemLinkWeaponType(offWeapons[2]))
    ShowSlotTexture(ActiveOWeapon, GetWeaponIconByIndex(offIndex))

    local ACTION_BAR_DISCIPLINE_TEXTURES = {
        [CHAMPION_DISCIPLINE_TYPE_COMBAT] = {
            border = "EsoUI/Art/Champion/ActionBar/champion_bar_slot_frame.dds",
            selected = "EsoUI/Art/Champion/ActionBar/champion_bar_combat_selection.dds",
            slotted = "EsoUI/Art/Champion/ActionBar/champion_bar_combat_slotted.dds",
            empty = "EsoUI/Art/Champion/ActionBar/champion_bar_combat_empty.dds",
            disabled = "EsoUI/Art/Champion/ActionBar/champion_bar_slot_frame_disabled.dds",
            points = "esoui/art/champion/champion_points_magicka_icon.dds"
        },
        [CHAMPION_DISCIPLINE_TYPE_CONDITIONING] = {
            border = "EsoUI/Art/Champion/ActionBar/champion_bar_slot_frame.dds",
            selected = "EsoUI/Art/Champion/ActionBar/champion_bar_conditioning_selection.dds",
            slotted = "EsoUI/Art/Champion/ActionBar/champion_bar_conditioning_slotted.dds",
            empty = "EsoUI/Art/Champion/ActionBar/champion_bar_conditioning_empty.dds",
            disabled = "EsoUI/Art/Champion/ActionBar/champion_bar_slot_frame_disabled.dds",
            points = "esoui/art/champion/champion_points_health_icon.dds"
        },
        [CHAMPION_DISCIPLINE_TYPE_WORLD] = {
            border = "EsoUI/Art/Champion/ActionBar/champion_bar_slot_frame.dds",
            selected = "EsoUI/Art/Champion/ActionBar/champion_bar_world_selection.dds",
            slotted = "EsoUI/Art/Champion/ActionBar/champion_bar_world_slotted.dds",
            empty = "EsoUI/Art/Champion/ActionBar/champion_bar_world_empty.dds",
            disabled = "EsoUI/Art/Champion/ActionBar/champion_bar_slot_frame_disabled.dds",
            points = "esoui/art/champion/champion_points_stamina_icon.dds"
        }
    }
    local skillDisplayNumCap = 4
    local CPsIndex = 1
    local CSlotId
    local VIRTUALNAME = "SuperStarChampionSkillFrame"
    local cBarStart, cBarEnd = GetAssignableChampionBarStartAndEndSlots()
    local disciplineIndex
    for disciplineIndex = 1, GetNumChampionDisciplines() do
        local Discipline = control:GetNamedChild("Discipline" .. disciplineIndex)
        local DisType = GetChampionDisciplineType(disciplineIndex)
        local TextureSlot = ACTION_BAR_DISCIPLINE_TEXTURES[DisType].slotted
        local TextureSelect = ACTION_BAR_DISCIPLINE_TEXTURES[DisType].selected
        Discipline:GetNamedChild("Name"):SetText(GetChampionDisciplineName(disciplineIndex))
        Discipline:GetNamedChild("Icon"):SetTexture(ACTION_BAR_DISCIPLINE_TEXTURES[DisType].points)
        Discipline:GetNamedChild("Points"):SetText("")
        local CSkillId
        local CSkillName
        local CSkillPoint
        local CSkillAnchor = ZO_Anchor:New(TOPLEFT, Discipline, TOPLEFT, 0, 0)
        for cpIndex = 1 , skillDisplayNumCap do
            local windowName = VIRTUALNAME .. disciplineIndex .. "at" .. cpIndex
            local CSkillFrame = GetControl(windowName)
            if not CSkillFrame then
                -- CreateControlFromVirtual(controlName, parent, templateName)
                CSkillFrame = CreateControlFromVirtual(windowName, Discipline, VIRTUALNAME)
            end
            CSkillFrame:SetHidden(true)
            CSlotId = bitBufRead(buf, BIT_WIDTH.CP_SLOT)
            CSkillPoint =  GetChampionSkillMaxPoints(CSlotId)
            CSkillName = zo_strformat(SI_CHAMPION_STAR_NAME, GetChampionSkillName(CSlotId))
            -- anchor offsets be align with frame's dimension
            CSkillAnchor:SetOffsets(math.mod((cpIndex - 1), 2) * 150 + 2,
                25 + math.floor((cpIndex - 1) / 2) * 25 + 4)
            CSkillAnchor:Set(CSkillFrame)
            CSkillFrame:SetHidden(false)
            CSkillFrame.cSkillId = CSlotId
            CSkillFrame.nPPoints = CSkillPoint
            CSkillFrame:GetNamedChild("Name"):SetText(CSkillName)
            CSkillFrame:GetNamedChild("Value"):SetText(CSkillPoint)
            CSkillFrame:GetNamedChild("Star"):SetTexture(TextureSlot)
            CSkillFrame:GetNamedChild("Star"):SetHidden(false)
            CSkillFrame:GetNamedChild("StarSelect"):SetTexture(TextureSelect)
            CSkillFrame:GetNamedChild("StarSelect"):SetHidden(false)
            CSkillFrame:GetNamedChild("StarBorder"):SetHidden(true)

            -- if NumChampionSkillActivated < skillDisplayNumCap then
            --     for CSkillIndex = NumChampionSkillActivated, 18 do
            --         local windowName = VIRTUALNAME .. disciplineIndex .. "at" .. (CSkillIndex + 1)
            --         local CSkillFrame = GetControl(windowName)
            --         if not CSkillFrame then
            --             CSkillFrame = CreateControlFromVirtual(windowName, Discipline, VIRTUALNAME)
            --         end
            --         CSkillFrame:SetHidden(true)
            --         -- d(CSkillFrame:GetNamedChild("Name"):SetText(CSkillName))
            --     end
            -- end
        end
    end

    -- Subclassing skill line / Class Mastery display
    VIRTUALNAME = "SuperStarSkillLineFrame"
    local virtualParent = control:GetNamedChild("SkillLine"):GetNamedChild("List")
    hideChildrenControls(virtualParent)

    local skLine1 = bitBufRead(buf, BIT_WIDTH.SKILL_LINE)
    local skLine2 = bitBufRead(buf, BIT_WIDTH.SKILL_LINE)
    local skLine3 = bitBufRead(buf, BIT_WIDTH.SKILL_LINE)

    if skLine3 == 0 then
        local classId = class
        local _, _, _, pressedClassIcon = GetClassInfo(GetClassIndexById(classId))
        local masteryClassName = GetClassName(GetUnitGender("player"), classId)

        local masteryPassives = {skLine1, skLine2, 0}
        for skillLineCount = 1, 3 do
            local nativeSkillLineId = LSF:GetSkillLineIdFromClass(classId, skillLineCount)
            local nativeSkillLineIcon = GetCollectibleIcon(GetSkillLineMasteryCollectibleId(nativeSkillLineId))
            local nativeSkillLineName = GetSkillLineNameById(nativeSkillLineId)
            local passiveIdx = masteryPassives[skillLineCount]
            local windowName = VIRTUALNAME .. skillLineCount
            local SSkillFrame = GetControl(windowName)
            if not SSkillFrame then
                SSkillFrame = CreateControlFromVirtual(windowName, virtualParent, VIRTUALNAME)
            end
            SSkillFrame:SetHidden(true)
            SSkillFrame:GetNamedChild("ClassIcon"):SetTexture(pressedClassIcon)
            SSkillFrame:GetNamedChild("SkillLineIcon"):SetTexture(nativeSkillLineIcon)
            if skillLineCount == 1 then
                SSkillFrame:GetNamedChild("ClassName"):SetText(masteryClassName)
            else
                SSkillFrame:GetNamedChild("ClassName"):SetText("")
            end

            local skillLineNameLabel = SSkillFrame:GetNamedChild("SkillLineName")
            skillLineNameLabel:SetAnchor(TOPLEFT, SSkillFrame:GetNamedChild("Divider"), BOTTOMLEFT, 35, 8)
            skillLineNameLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

            SSkillFrame.skillLineId = nil
            SSkillFrame.masterySkillId = nil
            SSkillFrame.isSubclassing = nil
            SetSkillLineRowHover(SSkillFrame, true)
            if passiveIdx > 0 and skillLineCount < 3 then
                local skillId = LSF:GetClassMasterySkillId(classId, passiveIdx)
                if skillId then
                    ShowMasteryIcon(SSkillFrame, skillId, nativeSkillLineIcon)
                    skillLineNameLabel:SetText(GetAbilityName(skillId))
                    SSkillFrame.masterySkillId = skillId
                else
                    HideMasteryIcon(SSkillFrame)
                    skillLineNameLabel:SetText("")
                end
            else
                HideMasteryIcon(SSkillFrame)
                skillLineNameLabel:SetText("")
            end

            local SSkillAnchor = ZO_Anchor:New(TOPLEFT, virtualParent, TOPLEFT, 0, 0)
            SSkillAnchor:SetOffsets(0, skillLineCount * 40 - 40)
            SSkillAnchor:Set(SSkillFrame)
            SSkillFrame:SetHidden(false)
        end
    else
        local indices = {skLine1, skLine2, skLine3}
        for skillLineCount = 1, 3 do
            local staticSkillLineIndex = indices[skillLineCount]
            local skillLineId = LSF:GetSkillLineIdFromLSFIndex(SKILL_TYPE_CLASS, staticSkillLineIndex)
            local skillLineName = GetSkillLineNameById(skillLineId)
            local skillLineIcon = GetCollectibleIcon(GetSkillLineMasteryCollectibleId(skillLineId))
            local _, _, _, pressedClassIcon = GetClassInfo(GetClassIndexById(LSF:GetClassIdFromLSFSkillLineId(staticSkillLineIndex)))
            local className = GetClassName(GetUnitGender("player"), LSF:GetClassIdFromLSFSkillLineId(staticSkillLineIndex))
            local windowName = VIRTUALNAME .. skillLineCount
            local SSkillFrame = GetControl(windowName)
            if not SSkillFrame then
                SSkillFrame = CreateControlFromVirtual(windowName, virtualParent, VIRTUALNAME)
            end
            SSkillFrame:SetHidden(true)
            SSkillFrame:GetNamedChild("ClassIcon"):SetTexture(pressedClassIcon)
            SSkillFrame:GetNamedChild("SkillLineIcon"):SetTexture(skillLineIcon)
            SSkillFrame:GetNamedChild("ClassName"):SetText(className)
            SSkillFrame:GetNamedChild("SkillLineName"):SetText(skillLineName)
            HideMasteryIcon(SSkillFrame)
            SSkillFrame.skillLineId = skillLineId
            SSkillFrame.masterySkillId = nil
            SSkillFrame.isSubclassing = true
            SetSkillLineRowHover(SSkillFrame, false)

            local skillLineNameLabel = SSkillFrame:GetNamedChild("SkillLineName")
            skillLineNameLabel:SetAnchor(TOPLEFT, SSkillFrame:GetNamedChild("Divider"), BOTTOMLEFT, 40, 0)
            skillLineNameLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

            local SSkillAnchor = ZO_Anchor:New(TOPLEFT, virtualParent, TOPLEFT, 0, 0)
            SSkillAnchor:SetOffsets(0, skillLineCount * 40 - 40)
            SSkillAnchor:Set(SSkillFrame)
            SSkillFrame:SetHidden(false)
        end
    end
end

local function BuildMainSceneLocal(control)
    EnsureMainSceneVirtualControls(control)
    -- Level / CPRank
    local LevelValue = control:GetNamedChild("LevelValue")
    local CPIcon = control:GetNamedChild("CPIcon")

    local playerCPRank = GetUnitChampionPoints("player") or 0

    local playerLevel = GetUnitLevel("player")
    local showCPIcon
    local maxStuffRank = GetMaxLevel()

    if playerCPRank > 0 then
        maxStuffRank = math.min(GetChampionPointsPlayerProgressionCap(), playerCPRank)
        showCPIcon = true
    end

    LevelValue:SetText(GetLevelOrChampionPointsStringNoIcon(playerLevel, playerCPRank))

    CPIcon:SetTexture(GetChampionPointsIcon())
    CPIcon:SetHidden(not showCPIcon)

    -- Class / Race
    local ClassAndRaceValue = control:GetNamedChild("ClassAndRaceValue")
    ClassAndRaceValue:SetText(zo_strformat(SI_STATS_RACE_CLASS, GetUnitRace("player"), GetUnitClass("player")))
    ClassAndRaceValue:SetFont("ZoFontHeader2")
    ClassAndRaceValue:SetAnchor(LEFT, control:GetNamedChild("AllianceTexture"), RIGHT, 95, -17)
    control:GetNamedChild("ShareRaceIcon"):SetHidden(true)
    control:GetNamedChild("ShareClassIcon"):SetHidden(true)

    -- Ava Rank

    local playerAlliance = GetUnitAlliance("player")
    local AllianceTexture = control:GetNamedChild("AllianceTexture")
    local AvaRankTexture = control:GetNamedChild("AvaRankTexture")
    local AvaRankName = control:GetNamedChild("AvaRankName")
    local AvaRankValue = control:GetNamedChild("AvaRankValue")

    AllianceTexture:SetTexture(GetLargeAllianceSymbolIcon(playerAlliance))
    local rank = GetUnitAvARank("player")

    AvaRankValue:SetText(rank)
    AvaRankName:SetText(zo_strformat(SI_STAT_RANK_NAME_FORMAT, GetAvARankName(GetUnitGender("player"), rank)))
    AvaRankTexture:SetTexture(GetLargeAvARankIcon(rank))

    -- Skill points
    local SkillPointsLabel = control:GetNamedChild("SkillPointsLabel")
    SkillPointsLabel:SetHidden(false)
    local ChampionPointsLabel = control:GetNamedChild("ChampionPointsLabel")
    ChampionPointsLabel:SetHidden(false)
    local SkillPointsValue = control:GetNamedChild("SkillPointsValue")
    -- SkillPointsValue:SetText(SuperStarSkills.spentSkillPoints)
    SkillPointsValue:SetText(SuperStarSkills:GetAvailableSkillPoints(true))

    -- Champion Points

    local ChampionPointsValue = control:GetNamedChild("ChampionPointsValue")

    local isCPUnlocked = IsChampionSystemUnlocked()
    if isCPUnlocked then
        ChampionPointsValue:SetText(GetPlayerChampionPointsEarned())
        if GetPlayerChampionPointsEarned() > GetMaxSpendableChampionPointsInAttribute() * 3 then
            ChampionPointsValue:SetText(GetPlayerChampionPointsEarned() .. " |cFF0000(+" ..
                                            (GetPlayerChampionPointsEarned() -
                                                GetMaxSpendableChampionPointsInAttribute() * 3) .. ")|r")
        end
    else
        ChampionPointsValue:SetText(ZO_DISABLED_TEXT:Colorize(SUPERSTAR_GENERIC_NA))
    end

    -- Active Skills

    local ActiveMWeapon = control:GetNamedChild("ActiveMWeapon")
    local ActiveMSkill1 = control:GetNamedChild("ActiveMSkill1")
    local ActiveMSkill2 = control:GetNamedChild("ActiveMSkill2")
    local ActiveMSkill3 = control:GetNamedChild("ActiveMSkill3")
    local ActiveMSkill4 = control:GetNamedChild("ActiveMSkill4")
    local ActiveMSkill5 = control:GetNamedChild("ActiveMSkill5")
    local ActiveMSkill6 = control:GetNamedChild("ActiveMSkill6")

    local ActiveOWeapon = control:GetNamedChild("ActiveOWeapon")
    local ActiveOSkill1 = control:GetNamedChild("ActiveOSkill1")
    local ActiveOSkill2 = control:GetNamedChild("ActiveOSkill2")
    local ActiveOSkill3 = control:GetNamedChild("ActiveOSkill3")
    local ActiveOSkill4 = control:GetNamedChild("ActiveOSkill4")
    local ActiveOSkill5 = control:GetNamedChild("ActiveOSkill5")
    local ActiveOSkill6 = control:GetNamedChild("ActiveOSkill6")

    local ActiveSWeapon = control:GetNamedChild("ActiveSWeapon")
    local ActiveSSkill1 = control:GetNamedChild("ActiveSSkill1")
    local ActiveSSkill2 = control:GetNamedChild("ActiveSSkill2")
    local ActiveSSkill3 = control:GetNamedChild("ActiveSSkill3")
    local ActiveSSkill4 = control:GetNamedChild("ActiveSSkill4")
    local ActiveSSkill5 = control:GetNamedChild("ActiveSSkill5")
    local ActiveSSkill6 = control:GetNamedChild("ActiveSSkill6")

    ActiveMWeapon:SetHidden(true)
    ActiveOWeapon:SetHidden(true)
    ActiveSWeapon:SetHidden(true)

    local firstWeapon, secondWeapon
    -- MainHand weapon and skills
    firstWeapon = GetItemWeaponType(BAG_WORN, EQUIP_SLOT_MAIN_HAND)
    secondWeapon = GetItemWeaponType(BAG_WORN, EQUIP_SLOT_OFF_HAND)
    ShowSlotTexture(ActiveMWeapon, GetWeaponIconPair(firstWeapon, secondWeapon))
    ShowSlotTexture(ActiveMSkill1, GetSlotBoundId(3, HOTBAR_CATEGORY_PRIMARY))
    ShowSlotTexture(ActiveMSkill2, GetSlotBoundId(4, HOTBAR_CATEGORY_PRIMARY))
    ShowSlotTexture(ActiveMSkill3, GetSlotBoundId(5, HOTBAR_CATEGORY_PRIMARY))
    ShowSlotTexture(ActiveMSkill4, GetSlotBoundId(6, HOTBAR_CATEGORY_PRIMARY))
    ShowSlotTexture(ActiveMSkill5, GetSlotBoundId(7, HOTBAR_CATEGORY_PRIMARY))
    ShowSlotTexture(ActiveMSkill6, GetSlotBoundId(8, HOTBAR_CATEGORY_PRIMARY))
    -- BackupHand weapon and skills
    firstWeapon = GetItemWeaponType(BAG_WORN, EQUIP_SLOT_BACKUP_MAIN)
    secondWeapon = GetItemWeaponType(BAG_WORN, EQUIP_SLOT_BACKUP_OFF)
    ShowSlotTexture(ActiveOWeapon, GetWeaponIconPair(firstWeapon, secondWeapon))
    ShowSlotTexture(ActiveOSkill1, GetSlotBoundId(3, HOTBAR_CATEGORY_BACKUP))
    ShowSlotTexture(ActiveOSkill2, GetSlotBoundId(4, HOTBAR_CATEGORY_BACKUP))
    ShowSlotTexture(ActiveOSkill3, GetSlotBoundId(5, HOTBAR_CATEGORY_BACKUP))
    ShowSlotTexture(ActiveOSkill4, GetSlotBoundId(6, HOTBAR_CATEGORY_BACKUP))
    ShowSlotTexture(ActiveOSkill5, GetSlotBoundId(7, HOTBAR_CATEGORY_BACKUP))
    ShowSlotTexture(ActiveOSkill6, GetSlotBoundId(8, HOTBAR_CATEGORY_BACKUP))

    local specialHotBarType
    specialHotBarType = HOTBAR_CATEGORY_WEREWOLF
    ShowSlotTexture(ActiveSSkill1, GetSlotBoundId(3, specialHotBarType))
    ShowSlotTexture(ActiveSSkill2, GetSlotBoundId(4, specialHotBarType))
    ShowSlotTexture(ActiveSSkill3, GetSlotBoundId(5, specialHotBarType))
    ShowSlotTexture(ActiveSSkill4, GetSlotBoundId(6, specialHotBarType))
    ShowSlotTexture(ActiveSSkill5, GetSlotBoundId(7, specialHotBarType))
    ShowSlotTexture(ActiveSSkill6, GetSlotBoundId(8, specialHotBarType))

    -- Attribute Stats

    local MagickaAttributeLabel = control:GetNamedChild("MagickaAttributeLabel")
    local HealthAttributeLabel = control:GetNamedChild("HealthAttributeLabel")
    local StaminaAttributeLabel = control:GetNamedChild("StaminaAttributeLabel")
    local MagickaAttributePoints = control:GetNamedChild("MagickaAttributePoints")
    local HealthAttributePoints = control:GetNamedChild("HealthAttributePoints")
    local StaminaAttributePoints = control:GetNamedChild("StaminaAttributePoints")
    local MagickaAttributeRegen = control:GetNamedChild("MagickaAttributeRegen")
    local HealthAttributeRegen = control:GetNamedChild("HealthAttributeRegen")
    local StaminaAttributeRegen = control:GetNamedChild("StaminaAttributeRegen")

    MagickaAttributeLabel:SetText(GetAttributeSpentPoints(ATTRIBUTE_MAGICKA))
    HealthAttributeLabel:SetText(GetAttributeSpentPoints(ATTRIBUTE_HEALTH))
    StaminaAttributeLabel:SetText(GetAttributeSpentPoints(ATTRIBUTE_STAMINA))

    MagickaAttributePoints:SetText(GetPlayerStat(STAT_MAGICKA_MAX))
    HealthAttributePoints:SetText(GetPlayerStat(STAT_HEALTH_MAX))
    StaminaAttributePoints:SetText(GetPlayerStat(STAT_STAMINA_MAX))

    MagickaAttributeRegen:SetText(GetPlayerStat(STAT_MAGICKA_REGEN_COMBAT))
    HealthAttributeRegen:SetText(GetPlayerStat(STAT_HEALTH_REGEN_COMBAT))
    StaminaAttributeRegen:SetText(GetPlayerStat(STAT_STAMINA_REGEN_COMBAT))

    -- Vampirism / WW
    local VampWWVIcon = control:GetNamedChild("VampWWVIcon")
    local VampWWValue = control:GetNamedChild("VampWWValue")

    local numBuffs = GetNumBuffs("player")
    local hasActiveEffects = numBuffs > 0
    local activeVampWW = {}

    if (hasActiveEffects) then
        for i = 1, numBuffs do
            local _, _, _, _, _, iconFilename, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
            if VampWW[abilityId] then
                table.insert(activeVampWW, {
                    abilityId = abilityId,
                    iconFilename = iconFilename
                })
            end
        end
    end

    if #activeVampWW == 0 then
        VampWWVIcon:SetHidden(true)
        VampWWValue:SetHidden(true)
    elseif #activeVampWW == 1 then
        VampWWVIcon:SetTexture(activeVampWW[1].iconFilename)
        VampWWValue:SetText(zo_strformat(SI_ABILITY_TOOLTIP_NAME, GetAbilityName(activeVampWW[1].abilityId)))
        VampWWVIcon:SetHidden(false)
        VampWWValue:SetHidden(false)
    end

    -- Mundus
    local MundusBoonIcon = control:GetNamedChild("MundusBoonIcon")
    MundusBoonIcon:SetTexture(GetAbilityIcon(13940))
    local MundusBoonValue = control:GetNamedChild("MundusBoonValue")

    local MundusBoonIcon2 = control:GetNamedChild("MundusBoonIcon2")
    MundusBoonIcon2:SetTexture(GetAbilityIcon(13940))
    local MundusBoonValue2 = control:GetNamedChild("MundusBoonValue2")

    -- Many Thanks to Srendarr
    local undesiredBuffs = {
        [29667] = true, -- Concentration (Light Armour)
        [40359] = true, -- Fed On Ally (Vampire)
        [45569] = true, -- Medicinal Use (Alchemy)
        [62760] = true, -- Spell Shield (Champion Point Ability)
        [63601] = true, -- ESO Plus Member
        [64160] = true, -- Crystal Fragments Passive (Not Timed)
        [36603] = true, -- Soul Siphoner Passive I
        [45155] = true, -- Soul Siphoner Passive II
        [57472] = true, -- Rapid Maneuver (Extra Aura)
        [57475] = true, -- Rapid Maneuver (Extra Aura)
        [57474] = true, -- Rapid Maneuver (Extra Aura)
        [57476] = true, -- Rapid Maneuver (Extra Aura)
        [57480] = true, -- Rapid Maneuver (Extra Aura)
        [57481] = true, -- Rapid Maneuver (Extra Aura)
        [57482] = true, -- Rapid Maneuver (Extra Aura)
        [64945] = true, -- Guard Regen (Guarded Extra)
        [64946] = true, -- Guard Regen (Guarded Extra)
        [46672] = true, -- Propelling Shield (Extra Aura)
        [42197] = true, -- Spinal Surge (Extra Aura)
        [42198] = true, -- Spinal Surge (Extra Aura)
        [62587] = true, -- Focused Aim (2s Refreshing Aura)
        [42589] = true, -- Flawless Dawnbreaker (2s aura on Weaponswap)
        [40782] = true, -- Acid Spray (Extra Aura)
        [14890] = true, -- Brace (Generic)
        [39269] = true, -- Soul Summons (Rank 1)
        [43752] = true, -- Soul Summons (Rank 2)
        [45590] = true, -- Soul Summons (Rank 2)
        [35658] = true, -- Lycanthropy
        [35771] = true, -- Stage 1 Vampirism (trivia: has a duration even though others don't)
        [35773] = true, -- Stage 2 Vampirism
        [35780] = true, -- Stage 3 Vampirism
        [35786] = true, -- Stage 4 Vampirism
        [35792] = true, -- Stage 4 Vampirism
        [39472] = true, -- Vampirism
        [40521] = true, -- Sanies Lupinus
        [40525] = true, -- Bit an ally
        [40539] = true -- Fed on ally
    }

    local numBuffs = GetNumBuffs("player")
    local hasActiveEffects = numBuffs > 0
    local activeBoons = {}
    local activeBuff = {}

    if (hasActiveEffects) then
        for i = 1, numBuffs do
            local _, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
            if mundusBoons[abilityId] then
                table.insert(activeBoons, abilityId)
            elseif not undesiredBuffs[abilityId] then
                table.insert(activeBuff, abilityId)
            end
        end
    end

    if #activeBoons == 0 then
        MundusBoonValue:SetText(SUPERSTAR_GENERIC_NA)
        MundusBoonIcon2:SetHidden(true)
        MundusBoonValue2:SetHidden(true)
    elseif #activeBoons == 1 then
        MundusBoonValue:SetText(zo_strformat(SI_ABILITY_TOOLTIP_NAME, GetAbilityName(activeBoons[1])))
        MundusBoonIcon2:SetHidden(true)
        MundusBoonValue2:SetHidden(true)
    else
        MundusBoonValue:SetText(zo_strformat(SI_ABILITY_TOOLTIP_NAME, GetAbilityName(activeBoons[1])))
        MundusBoonValue2:SetText(zo_strformat(SI_ABILITY_TOOLTIP_NAME, GetAbilityName(activeBoons[2])))
        MundusBoonIcon2:SetHidden(false)
        MundusBoonValue2:SetHidden(false)
    end

    local foodBuffs = {}

    local foodBonus = GetActiveFoodTypeBonus()
    local FoodBonusControl = {}
    FoodBonusControl[FOOD_BUFF_MAX_HEALTH] = control:GetNamedChild("MaxHealth")
    FoodBonusControl[FOOD_BUFF_MAX_MAGICKA] = control:GetNamedChild("MaxMagicka")
    FoodBonusControl[FOOD_BUFF_MAX_STAMINA] = control:GetNamedChild("MaxStamina")
    FoodBonusControl[FOOD_BUFF_REGEN_HEALTH] = control:GetNamedChild("RegenHealth")
    FoodBonusControl[FOOD_BUFF_REGEN_MAGICKA] = control:GetNamedChild("RegenMagicka")
    FoodBonusControl[FOOD_BUFF_REGEN_STAMINA] = control:GetNamedChild("RegenStamina")

    FoodBonusControl[FOOD_BUFF_MAX_HEALTH]:SetHidden(true)
    FoodBonusControl[FOOD_BUFF_MAX_MAGICKA]:SetHidden(true)
    FoodBonusControl[FOOD_BUFF_MAX_STAMINA]:SetHidden(true)
    FoodBonusControl[FOOD_BUFF_REGEN_HEALTH]:SetHidden(true)
    FoodBonusControl[FOOD_BUFF_REGEN_MAGICKA]:SetHidden(true)
    FoodBonusControl[FOOD_BUFF_REGEN_STAMINA]:SetHidden(true)

    if foodBonus > FOOD_BUFF_NONE then

        if foodBonus > FOOD_BUFF_SPECIAL_VAMPIRE then
            foodBonus = foodBonus - FOOD_BUFF_SPECIAL_VAMPIRE -- Vampire mess the UI
        end

        local vals = {FOOD_BUFF_MAX_HEALTH, FOOD_BUFF_MAX_MAGICKA, FOOD_BUFF_MAX_STAMINA, FOOD_BUFF_REGEN_HEALTH,
                      FOOD_BUFF_REGEN_MAGICKA, FOOD_BUFF_REGEN_STAMINA}
        local i = #vals

        while foodBonus ~= 0 and i > 0 do
            if vals[i] <= foodBonus then
                foodBonus = foodBonus - vals[i]
                FoodBonusControl[vals[i]]:SetHidden(false)
            end
            i = i - 1
        end
    end

    -- Food buff info panel (replaces 3x3 buff icon grid)
    local foodBuffInfo = control:GetNamedChild("FoodBuffInfo")
    local foodIconTexture = foodBuffInfo:GetNamedChild("Icon")
    local foodTypeValue = 0

    if numBuffs > 0 then
        for i = 1, numBuffs do
            local _, _, _, _, _, icon, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
            local foodBuffId = FOOD_BUFF_ABILITY_MAP[abilityId]
            if foodBuffId then
                foodTypeValue = foodBuffId
                foodIconTexture:SetTexture(icon)
                break
            end
        end
    end

    if foodTypeValue > FOOD_BUFF_SPECIAL_VAMPIRE then
        foodTypeValue = foodTypeValue - FOOD_BUFF_SPECIAL_VAMPIRE
    end

    local vals = {FOOD_BUFF_REGEN_STAMINA, FOOD_BUFF_REGEN_MAGICKA, FOOD_BUFF_REGEN_HEALTH, FOOD_BUFF_MAX_STAMINA,
                  FOOD_BUFF_MAX_MAGICKA, FOOD_BUFF_MAX_HEALTH}
    local rows = {}
    for _, v in ipairs(vals) do
        if v <= foodTypeValue then
            foodTypeValue = foodTypeValue - v
            table.insert(rows, v)
        end
    end
    local rowCount = #rows
    if rowCount > 0 then
        foodIconTexture:SetHidden(false)
        local labelH = 18
        local gapY = 5
        local totalTextH = rowCount * labelH + (rowCount - 1) * gapY
        local _, iconH = foodIconTexture:GetDimensions()
        local firstRowY = iconH / 2 - totalTextH / 2 - 3

        for i, foodType in ipairs(rows) do
            local rowName = "FoodBuffRow" .. i
            local row = GetControl(rowName)
            if not row then
                row = CreateControlFromVirtual(rowName, foodBuffInfo, "SuperStarXMLFoodBuffRowTemplate")
            end
            row:SetHidden(false)
            local rowLabel = row:GetNamedChild("Label")
            rowLabel:SetText("+ " .. GetString(FOOD_TYPE_I18N[foodType]))
            rowLabel:SetHidden(false)
            rowLabel:ClearAnchors()
            local rowY = firstRowY + (i - 1) * (labelH + gapY)
            rowLabel:SetAnchor(TOPLEFT, foodIconTexture, TOPLEFT, iconH + 8, rowY)
        end
        for i = rowCount + 1, 4 do
            local rowLabel = GetControl("FoodBuffRow" .. i)
            if rowLabel then rowLabel:SetHidden(true) end
        end
    else
        foodIconTexture:SetTexture(GetAbilityIcon(47856))
        foodIconTexture:SetHidden(false)
        local _, iconH = foodIconTexture:GetDimensions()
        local firstRowY = iconH / 2 - 9
        local row = GetControl("FoodBuffRow1")
        if not row then
            row = CreateControlFromVirtual("FoodBuffRow1", foodBuffInfo, "SuperStarXMLFoodBuffRowTemplate")
        end
        row:SetHidden(false)
        local rowLabel = row:GetNamedChild("Label")
        rowLabel:SetText(zo_strformat(GetString(SI_DEATH_PROMPT_NO_SOUL_GEMS_PVP), GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES403)))
        rowLabel:SetHidden(false)
        rowLabel:ClearAnchors()
        rowLabel:SetAnchor(TOPLEFT, foodIconTexture, TOPLEFT, iconH + 8, firstRowY)
        for i = 2, 4 do
            local r = GetControl("FoodBuffRow" .. i)
            if r then r:SetHidden(true) end
        end
    end

    -- Magicka Stamina Dmg, Crit chance, Resist, Penetration
    local MagickaDmg = control:GetNamedChild("MagickaDmg")
    local StaminaDmg = control:GetNamedChild("StaminaDmg")
    local MagickaCrit = control:GetNamedChild("MagickaCrit")
    local StaminaCrit = control:GetNamedChild("StaminaCrit")
    local MagickaCritPercent = control:GetNamedChild("MagickaCritPercent")
    local StaminaCritPercent = control:GetNamedChild("StaminaCritPercent")
    local MagickaPene = control:GetNamedChild("MagickaPene")
    local StaminaPene = control:GetNamedChild("StaminaPene")
    local MagickaResist = control:GetNamedChild("MagickaResist")
    local StaminaResist = control:GetNamedChild("StaminaResist")
    local MagickaResistPercent = control:GetNamedChild("MagickaResistPercent")
    local StaminaResistPercent = control:GetNamedChild("StaminaResistPercent")

    local magickaColor = GetItemQualityColor(ITEM_QUALITY_ARCANE)
    local staminaColor = GetItemQualityColor(ITEM_QUALITY_MAGIC)

    MagickaDmg:SetText(GetPlayerStat(STAT_SPELL_POWER))
    StaminaDmg:SetText(GetPlayerStat(STAT_POWER))

    MagickaDmg:SetColor(magickaColor.r, magickaColor.g, magickaColor.b)
    StaminaDmg:SetColor(staminaColor.r, staminaColor.g, staminaColor.b)

    local spellCritical = GetPlayerStat(STAT_SPELL_CRITICAL)
    local weaponCritical = GetPlayerStat(STAT_CRITICAL_STRIKE)

    MagickaCrit:SetText(spellCritical)
    StaminaCrit:SetText(weaponCritical)

    -- MagickaCrit:SetColor(magickaColor.r, magickaColor.g, magickaColor.b)
    -- StaminaCrit:SetColor(staminaColor.r, staminaColor.g, staminaColor.b)

    MagickaCritPercent:SetText(zo_strformat(SI_STAT_VALUE_PERCENT, GetCriticalStrikeChance(spellCritical, true)))
    StaminaCritPercent:SetText(zo_strformat(SI_STAT_VALUE_PERCENT, GetCriticalStrikeChance(weaponCritical, true)))

    MagickaCritPercent:SetColor(magickaColor.r, magickaColor.g, magickaColor.b)
    StaminaCritPercent:SetColor(staminaColor.r, staminaColor.g, staminaColor.b)

    MagickaPene:SetText(GetPlayerStat(STAT_SPELL_PENETRATION))
    StaminaPene:SetText(GetPlayerStat(STAT_PHYSICAL_PENETRATION))

    MagickaPene:SetColor(magickaColor.r, magickaColor.g, magickaColor.b)
    StaminaPene:SetColor(staminaColor.r, staminaColor.g, staminaColor.b)

    local spellResist = GetPlayerStat(STAT_SPELL_RESIST)
    local weaponResist = GetPlayerStat(STAT_PHYSICAL_RESIST)

    MagickaResist:SetText(spellResist)
    StaminaResist:SetText(weaponResist)

    -- MagickaResist:SetColor(magickaColor.r, magickaColor.g, magickaColor.b)
    -- StaminaResist:SetColor(staminaColor.r, staminaColor.g, staminaColor.b)

    local championPointsForStatsCalculation = math.min(playerCPRank, GetChampionPointsPlayerProgressionCap()) / 10
    local spellResistPercent = math.max((spellResist - 100), 0) / ((playerLevel + championPointsForStatsCalculation) * 10)
    local weaponResistPercent = math.max((weaponResist - 100), 0) / ((playerLevel + championPointsForStatsCalculation) * 10)

    MagickaResistPercent:SetText(zo_strformat(SI_STAT_VALUE_PERCENT, spellResistPercent))
    StaminaResistPercent:SetText(zo_strformat(SI_STAT_VALUE_PERCENT, weaponResistPercent))

    MagickaResistPercent:SetColor(magickaColor.r, magickaColor.g, magickaColor.b)
    StaminaResistPercent:SetColor(staminaColor.r, staminaColor.g, staminaColor.b)

    if spellResistPercent >= 50 then
        MagickaResistPercent:SetColor(1, 0, 0)
    end

    if weaponResistPercent >= 50 then
        StaminaResistPercent:SetColor(1, 0, 0)
    end

    -- Stuff

    local slots = {
        [EQUIP_SLOT_HEAD] = true,
        [EQUIP_SLOT_NECK] = true,
        [EQUIP_SLOT_CHEST] = true,
        [EQUIP_SLOT_SHOULDERS] = true,
        [EQUIP_SLOT_MAIN_HAND] = true,
        [EQUIP_SLOT_OFF_HAND] = true,
        [EQUIP_SLOT_WAIST] = true,
        [EQUIP_SLOT_LEGS] = true,
        [EQUIP_SLOT_FEET] = true,
        [EQUIP_SLOT_RING1] = true,
        [EQUIP_SLOT_RING2] = true,
        [EQUIP_SLOT_HAND] = true,
        [EQUIP_SLOT_BACKUP_MAIN] = true,
        [EQUIP_SLOT_BACKUP_OFF] = true
    }

    local poisons = {
        [EQUIP_SLOT_POISON] = EQUIP_SLOT_MAIN_HAND,
        [EQUIP_SLOT_BACKUP_POISON] = EQUIP_SLOT_BACKUP_MAIN
    }

    local SSslotData = {}
    local setEquipped = {}

    for slotId in pairs(slots) do

        local itemLink = GetItemLink(BAG_WORN, slotId)

        SSslotData[slotId] = {}
        if GetString("SUPERSTAR_SLOTNAME", slotId) ~= "" then
            SSslotData[slotId].slotName = GetString("SUPERSTAR_SLOTNAME", slotId)
        else
            SSslotData[slotId].slotName = zo_strformat(SI_ITEM_FORMAT_STR_BROAD_TYPE, GetString("SI_EQUIPSLOT", slotId))
        end

        if itemLink ~= "" then
            local name = GetItemLinkName(itemLink)
            local requiredLevel = GetItemLinkRequiredLevel(itemLink)
            local requiredCPRank = GetItemLinkRequiredChampionPoints(itemLink)
            local traitType, traitDescription = GetItemLinkTraitInfo(itemLink)
            local hasCharges, enchantHeader, enchantDescription = GetItemLinkEnchantInfo(itemLink)
            local quality = GetItemLinkDisplayQuality(itemLink)
            local enchantQuality = GetEnchantQuality(itemLink)
            local armorType = GetItemLinkArmorType(itemLink)
            local icon = GetItemLinkInfo(itemLink)
            local hasSet, _, numBonuses, numNormalEquipped, maxEquipped, setId, numPerfectedEquipped =
                GetItemLinkSetInfo(itemLink, true)
            local setMinRequires = GetItemLinkSetBonusInfo(itemLink, true, 1)
            local _, _, isPerfected = GetItemLinkSetBonusInfo(itemLink, true, math.max(numBonuses - 1, 1))

            name = GetItemQualityColor(quality):Colorize(zo_strformat(SI_TOOLTIP_ITEM_NAME, name))

            if hasSet then
                if not setEquipped[setId] then
                    setEquipped[setId] = {
                        numEquipped = numNormalEquipped + numPerfectedEquipped,
                        maxEquipped = maxEquipped,
                        enabled = (numNormalEquipped + numPerfectedEquipped) >= setMinRequires,
                        isPerfected = isPerfected
                    }

                    -- if setEquipped[setId].isPerfected then
                    --     setEquipped[setId].numEquipped = numPerfectedEquipped
                    -- end

                    if setEquipped[setId].enabled then
                        name = zo_strformat("<<1>> " ..
                                                GetItemQualityColor(ITEM_QUALITY_MAGIC):Colorize(("<<2>>: <<3>>/<<4>>")),
                            name, GetString(SUPERSTAR_EQUIP_SET_BONUS), setEquipped[setId].numEquipped,
                            setEquipped[setId].maxEquipped)
                    else
                        name = zo_strformat("<<1>> |cFF0000<<2>>: <<3>>/<<4>>|r", name,
                            GetString(SUPERSTAR_EQUIP_SET_BONUS), setEquipped[setId].numEquipped,
                            setEquipped[setId].maxEquipped)
                    end

                end
            end

            local requiredFormattedLevel
            if requiredCPRank > 0 then
                requiredFormattedLevel = "|t32:32:" .. GetChampionPointsIcon() .. "|t" .. requiredCPRank
            else
                requiredFormattedLevel = requiredLevel
            end

            local traitName
            if (traitType ~= ITEM_TRAIT_TYPE_NONE and traitType ~= ITEM_TRAIT_TYPE_SPECIAL_STAT and traitDescription ~=
                "") then
                traitName = GetString("SI_ITEMTRAITTYPE", traitType)
            else
                traitName = SUPERSTAR_GENERIC_NA
            end

            if enchantDescription == "" then
                enchantDescription = SUPERSTAR_GENERIC_NA
            else
                enchantDescription = enchantHeader
            end
            -- elseif string.len(enchantDescription) > 60 then
            --     enchantDescription = enchantHeader
            -- else
            --     enchantDescription = enchantDescription:gsub("\n", " "):gsub(GetString(SUPERSTAR_DESC_ENCHANT_MAX), "")
            --         :gsub(GetString(SUPERSTAR_DESC_ENCHANT_SEC), GetString(SUPERSTAR_DESC_ENCHANT_SEC_SHORT))
            --     enchantDescription = enchantDescription:gsub(GetString(SUPERSTAR_DESC_ENCHANT_MAGICKA_DMG),
            --         GetString(SUPERSTAR_DESC_ENCHANT_MAGICKA_DMG_SHORT)):gsub(GetString(SUPERSTAR_DESC_ENCHANT_BASH),
            --         GetString(SUPERSTAR_DESC_ENCHANT_BASH_SHORT))
            --     enchantDescription = enchantDescription:gsub(GetString(SUPERSTAR_DESC_ENCHANT_REDUCE),
            --         GetString(SUPERSTAR_DESC_ENCHANT_REDUCE_SHORT))
            -- end

            SSslotData[slotId].name = name
            SSslotData[slotId].requiredFormattedLevel = requiredFormattedLevel
            SSslotData[slotId].traitName = traitName
            SSslotData[slotId].icon = icon
            SSslotData[slotId].enchantDescription = enchantDescription

            SSslotData[slotId].labelControl, SSslotData[slotId].valueControl, SSslotData[slotId].levelControl,
                SSslotData[slotId].traitControl, SSslotData[slotId].enchantControl =
                GetMainStuffRowControls(control, slotId)

            SSslotData[slotId].labelControl:SetText(SSslotData[slotId].slotName)

            if armorType == ARMORTYPE_HEAVY then
                SSslotData[slotId].labelControl:SetColor(1, 0, 0)
            elseif armorType == ARMORTYPE_MEDIUM then
                SSslotData[slotId].labelControl:SetColor(staminaColor.r, staminaColor.g, staminaColor.b)
            elseif armorType == ARMORTYPE_LIGHT then
                SSslotData[slotId].labelControl:SetColor(magickaColor.r, magickaColor.g, magickaColor.b)
            else
                SSslotData[slotId].labelControl:SetColor(ZO_NORMAL_TEXT:UnpackRGB())
            end

            SSslotData[slotId].valueControl:SetText(SSslotData[slotId].name)
            SSslotData[slotId].valueControl.itemLink = itemLink

            if requiredCPRank < maxStuffRank then
                SSslotData[slotId].levelControl:SetColor(1, 0, 0)
            else
                SSslotData[slotId].levelControl:SetColor(1, 1, 1)
            end

            SSslotData[slotId].levelControl:SetText(SSslotData[slotId].requiredFormattedLevel)
            SSslotData[slotId].traitControl:SetText(SSslotData[slotId].traitName)
            SSslotData[slotId].enchantControl:SetText(SSslotData[slotId].enchantDescription)
            SSslotData[slotId].enchantControl:SetColor(GetItemQualityColor(enchantQuality):UnpackRGBA())
            SSslotData[slotId].enchantControl:SetAlpha(0.75)

        else
            SSslotData[slotId].dontWearSlot = true

            SSslotData[slotId].labelControl, SSslotData[slotId].valueControl, SSslotData[slotId].levelControl,
                SSslotData[slotId].traitControl, SSslotData[slotId].enchantControl =
                GetMainStuffRowControls(control, slotId)
            SSslotData[slotId].labelControl:SetText(SSslotData[slotId].slotName)
            SSslotData[slotId].labelControl:SetColor(ZO_DISABLED_TEXT:UnpackRGBA())

            SSslotData[slotId].valueControl:SetText(SUPERSTAR_GENERIC_NA)

            SSslotData[slotId].levelControl:SetText(SUPERSTAR_GENERIC_NA)
            SSslotData[slotId].traitControl:SetText(SUPERSTAR_GENERIC_NA)
            SSslotData[slotId].enchantControl:SetText(SUPERSTAR_GENERIC_NA)
            SSslotData[slotId].enchantControl:SetColor(ZO_DISABLED_TEXT:UnpackRGBA())
            SSslotData[slotId].enchantControl:SetAlpha(0.75)

        end

    end

    local function changeQuality(itemLink)

        local quality = ITEM_QUALITY_NORMAL

        if quality < ITEM_QUALITY_LEGENDARY then
            for i = 1, GetMaxTraits() do

                local hasTraitAbility = GetItemLinkTraitOnUseAbilityInfo(itemLink, i)

                if (hasTraitAbility) then
                    quality = quality + 1
                end

            end

            if quality == ITEM_QUALITY_NORMAL then
                quality = ITEM_QUALITY_MAGIC
            end
        end

        return quality

    end

    for slotId, correspondance in pairs(poisons) do

        local itemLink = GetItemLink(BAG_WORN, slotId)
        local itemLinkCorresp = GetItemLink(BAG_WORN, correspondance)

        SSslotData[slotId] = {}

        if itemLink ~= "" and itemLink ~= "" then

            local name = GetItemLinkName(itemLink)

            local quality = GetItemLinkQuality(itemLink)
            if select(24, ZO_LinkHandler_ParseLink(itemLink)) ~= "0" then
                quality = changeQuality(quality)
            end

            name = GetItemQualityColor(quality):Colorize(zo_strformat(SI_TOOLTIP_ITEM_NAME, name))

            local _, _, _, _, enchantControl = GetMainStuffRowControls(control, correspondance)
            SSslotData[correspondance].enchantControl = enchantControl
            SSslotData[correspondance].enchantControl:SetText(name)

        end
    end

    -- Lykeion@6.0.0
    local VIRTUALNAME = "SuperStarScribingSkillFrame"
    local windowIndex = 0
    local scribing = control:GetNamedChild("Scribing")
    scribing:SetHidden(true)
    local virtualParent = scribing:GetNamedChild("List")
    hideChildrenControls(virtualParent)
    local hotbars = {HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP}
    for i, v in pairs(hotbars) do
        for index = 1, 6 do
            local abilityId = GetSlotBoundId(2 + index, v)
            if craftedAbilityDict[abilityId] then
                craftedAbilityDict[abilityId] = false
                scribing:SetHidden(false)
                -- Build up crafted ability info
                local windowName = VIRTUALNAME .. windowIndex
                windowIndex = windowIndex + 1
                local SSkillFrame = GetControl(windowName)
                if not SSkillFrame then
                    -- CreateControlFromVirtual(controlName, parent, templateName)
                    SSkillFrame = CreateControlFromVirtual(windowName, virtualParent, VIRTUALNAME)
                end
                SSkillFrame:SetHidden(false)

                SSkillFrame.abilityId = GetAbilityIdForCraftedAbilityId(abilityId)
                SSkillFrame:GetNamedChild("Icon"):SetTexture(GetCraftedAbilityDisplayIcon(abilityId))

                local skillType, skillLineIndex, skillIndex = GetSkillAbilityIndicesFromCraftedAbilityId(abilityId)
                local skillLineName = GetCraftedAbilitySkilllineName(abilityId)
                -- GetSkillLineNameById(LSF:GetSkillLineIdFromLSFIndex(skillType, skillLineIndex))
                local abilityName = GetAbilityName(GetAbilityIdForCraftedAbilityId(abilityId))
                SSkillFrame:GetNamedChild("MainText"):SetText(skillLineName .. " / " .. abilityName)


                local script1, script2, script3 = GetCraftedAbilityActiveScriptIds(abilityId)
                SSkillFrame:GetNamedChild("SubText"):SetText(GetCraftedAbilityScriptDisplayName(script1) .. " / " ..
                                                            GetCraftedAbilityScriptDisplayName(script2) .. " / " ..
                                                            GetCraftedAbilityScriptDisplayName(script3))

                local SSkillAnchor = ZO_Anchor:New(TOPLEFT, virtualParent, TOPLEFT, 0, 0)
                SSkillAnchor:SetOffsets(0, (windowIndex - 1) * 60)
                SSkillAnchor:Set(SSkillFrame)
            end
        end
    end
    InitCraftedAbilityDict()

    VIRTUALNAME = "SuperStarSkillLineFrame"
    virtualParent = control:GetNamedChild("SkillLine"):GetNamedChild("List")

    local masteryPassives = {}
    if not IsSubclassing() then
        local classId = GetUnitClassId("player")
        local masterySkillLineId = LSF:GetClassMasterySkillLineId(classId)
        local _, masteryESOIndex = GetSkillLineIndicesFromSkillLineId(masterySkillLineId)
        if masteryESOIndex then
            for i = 1, 5 do
                local _, _, _, _, _, isPurchased = GetSkillAbilityInfo(SKILL_TYPE_CLASS, masteryESOIndex, i)
                if isPurchased and #masteryPassives < 2 then
                    table.insert(masteryPassives, i)
                end
            end
        end
    end

    if #masteryPassives > 0 then
        local classId = GetUnitClassId("player")
        local _, _, _, pressedClassIcon = GetClassInfo(GetClassIndexById(classId))
        local className = GetClassName(GetUnitGender("player"), classId)
        for skillLineCount = 1, 3 do
            local nativeSkillLineId = LSF:GetSkillLineIdFromClass(classId, skillLineCount)
            local nativeSkillLineName = GetSkillLineNameById(nativeSkillLineId)
            local nativeSkillLineIcon = GetCollectibleIcon(GetSkillLineMasteryCollectibleId(nativeSkillLineId))
            local windowName = VIRTUALNAME .. skillLineCount
            local SSkillFrame = GetControl(windowName)
            if not SSkillFrame then
                SSkillFrame = CreateControlFromVirtual(windowName, virtualParent, VIRTUALNAME)
            end
            SSkillFrame:SetHidden(false)
            SSkillFrame:GetNamedChild("ClassIcon"):SetTexture(pressedClassIcon)
            SSkillFrame:GetNamedChild("SkillLineIcon"):SetTexture(nativeSkillLineIcon)
            if skillLineCount == 1 then
                SSkillFrame:GetNamedChild("ClassName"):SetText(className)
            else
                SSkillFrame:GetNamedChild("ClassName"):SetText("")
            end

            local skillLineNameLabel = SSkillFrame:GetNamedChild("SkillLineName")
            skillLineNameLabel:SetAnchor(TOPLEFT, SSkillFrame:GetNamedChild("Divider"), BOTTOMLEFT, 35, 8)
            skillLineNameLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

            local passiveIdx = masteryPassives[skillLineCount]
            SSkillFrame.skillLineId = nil
            SSkillFrame.masterySkillId = nil
            SSkillFrame.isSubclassing = nil
            SetSkillLineRowHover(SSkillFrame, true)
            if passiveIdx and skillLineCount < 3 then
                local skillId = LSF:GetClassMasterySkillId(classId, passiveIdx)
                if skillId then
                    ShowMasteryIcon(SSkillFrame, skillId, nativeSkillLineIcon)
                    skillLineNameLabel:SetText(GetAbilityName(skillId))
                    SSkillFrame.masterySkillId = skillId
                else
                    HideMasteryIcon(SSkillFrame)
                    skillLineNameLabel:SetText("")
                end
            else
                HideMasteryIcon(SSkillFrame)
                skillLineNameLabel:SetText("")
            end

            local SSkillAnchor = ZO_Anchor:New(TOPLEFT, virtualParent, TOPLEFT, 0, 0)
            SSkillAnchor:SetOffsets(0, skillLineCount * 40 - 40)
            SSkillAnchor:Set(SSkillFrame)
        end
    else
        local skillLineCount = 1
        local numSkillLines = GetNumSkillLines(SKILL_TYPE_CLASS)
        for skillLineIndex = 1, numSkillLines do
            local currentRank, isAdvised, isActive, isDiscovered, isProgressionAccountWide, isInTraining = GetSkillLineDynamicInfo(SKILL_TYPE_CLASS, skillLineIndex)
            if isActive then
                local skillLineName, _, _, skillLineId, _, _, _, _ = GetSkillLineInfo(SKILL_TYPE_CLASS, skillLineIndex)
                local skillLineIcon = GetCollectibleIcon(GetSkillLineMasteryCollectibleId(skillLineId))
                local _, _, _, pressedClassIcon = GetClassInfo(GetClassIndexById(GetSkillLineClassId(SKILL_TYPE_CLASS, skillLineIndex)))
                local className = GetClassName(GetUnitGender("player"), select(1, GetClassInfo(GetClassIndexById(GetSkillLineClassId(SKILL_TYPE_CLASS, skillLineIndex)))))
                local windowName = VIRTUALNAME .. skillLineCount
                local SSkillFrame = GetControl(windowName)
                if not SSkillFrame then
                    SSkillFrame = CreateControlFromVirtual(windowName, virtualParent, VIRTUALNAME)
                end
                SSkillFrame:SetHidden(false)
                SSkillFrame:GetNamedChild("ClassIcon"):SetTexture(pressedClassIcon)
                SSkillFrame:GetNamedChild("SkillLineIcon"):SetTexture(skillLineIcon)
                SSkillFrame:GetNamedChild("ClassName"):SetText(className)
                SSkillFrame:GetNamedChild("SkillLineName"):SetText(skillLineName)
                HideMasteryIcon(SSkillFrame)
                SSkillFrame.skillLineId = skillLineId
                SSkillFrame.masterySkillId = nil
                SSkillFrame.isSubclassing = true
                SetSkillLineRowHover(SSkillFrame, false)

                local skillLineNameLabel = SSkillFrame:GetNamedChild("SkillLineName")
                skillLineNameLabel:SetAnchor(TOPLEFT, SSkillFrame:GetNamedChild("Divider"), BOTTOMLEFT, 40, 0)
                skillLineNameLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

                local SSkillAnchor = ZO_Anchor:New(TOPLEFT, virtualParent, TOPLEFT, 0, 0)
                SSkillAnchor:SetOffsets(0, skillLineCount * 40 - 40)
                SSkillAnchor:Set(SSkillFrame)
                skillLineCount = skillLineCount + 1
                if skillLineCount > 3 then
                    break
                end
            end
        end
    end

    -- CP
    -- Armodeniz modified for CP 2.0
    local ACTION_BAR_DISCIPLINE_TEXTURES = {
        [CHAMPION_DISCIPLINE_TYPE_COMBAT] = {
            border = "EsoUI/Art/Champion/ActionBar/champion_bar_slot_frame.dds",
            selected = "EsoUI/Art/Champion/ActionBar/champion_bar_combat_selection.dds",
            slotted = "EsoUI/Art/Champion/ActionBar/champion_bar_combat_slotted.dds",
            empty = "EsoUI/Art/Champion/ActionBar/champion_bar_combat_empty.dds",
            disabled = "EsoUI/Art/Champion/ActionBar/champion_bar_slot_frame_disabled.dds",
            points = "esoui/art/champion/champion_points_magicka_icon.dds"
        },
        [CHAMPION_DISCIPLINE_TYPE_CONDITIONING] = {
            border = "EsoUI/Art/Champion/ActionBar/champion_bar_slot_frame.dds",
            selected = "EsoUI/Art/Champion/ActionBar/champion_bar_conditioning_selection.dds",
            slotted = "EsoUI/Art/Champion/ActionBar/champion_bar_conditioning_slotted.dds",
            empty = "EsoUI/Art/Champion/ActionBar/champion_bar_conditioning_empty.dds",
            disabled = "EsoUI/Art/Champion/ActionBar/champion_bar_slot_frame_disabled.dds",
            points = "esoui/art/champion/champion_points_health_icon.dds"
        },
        [CHAMPION_DISCIPLINE_TYPE_WORLD] = {
            border = "EsoUI/Art/Champion/ActionBar/champion_bar_slot_frame.dds",
            selected = "EsoUI/Art/Champion/ActionBar/champion_bar_world_selection.dds",
            slotted = "EsoUI/Art/Champion/ActionBar/champion_bar_world_slotted.dds",
            empty = "EsoUI/Art/Champion/ActionBar/champion_bar_world_empty.dds",
            disabled = "EsoUI/Art/Champion/ActionBar/champion_bar_slot_frame_disabled.dds",
            points = "esoui/art/champion/champion_points_stamina_icon.dds"
        }
    }
    -- changed from 18 to 4 in Gold Road to spare room for scribing
    local skillDisplayNumCap = 4
    if isCPUnlocked then
        local VIRTUALNAME = "SuperStarChampionSkillFrame"
        local cBarStart, cBarEnd = GetAssignableChampionBarStartAndEndSlots()
        local disciplineIndex
        for disciplineIndex = 1, GetNumChampionDisciplines() do
            local Discipline = control:GetNamedChild("Discipline" .. disciplineIndex)
            local DisType = GetChampionDisciplineType(disciplineIndex)
            local TextureSlot = ACTION_BAR_DISCIPLINE_TEXTURES[DisType].slotted
            local TextureSelect = ACTION_BAR_DISCIPLINE_TEXTURES[DisType].selected
            Discipline:GetNamedChild("Name"):SetText(GetChampionDisciplineName(disciplineIndex))
            Discipline:GetNamedChild("Icon"):SetTexture(ACTION_BAR_DISCIPLINE_TEXTURES[DisType].points)
            Discipline:GetNamedChild("Points"):SetText(GetNumSpentChampionPoints(disciplineIndex))
            local CSkillId
            local CSkillName
            local CSkillPoint
            local CSkillAnchor = ZO_Anchor:New(TOPLEFT, Discipline, TOPLEFT, 0, 0)
            local NumChampionSkillActivated = 0
            local NumChampionSkill = GetNumChampionDisciplineSkills(math.mod(disciplineIndex, 3) + 1)
            -- d(NumChampionSkill)
            if NumChampionSkill > 0 then
                -- Searching for sloted CP
                for CSlotIndex = cBarStart, cBarEnd do
                    local windowName = VIRTUALNAME .. disciplineIndex .. "at" .. (NumChampionSkillActivated + 1)
                    local CSkillFrame = GetControl(windowName)
                    if not CSkillFrame then
                        -- CreateControlFromVirtual(controlName, parent, templateName)
                        CSkillFrame = CreateControlFromVirtual(windowName, Discipline, VIRTUALNAME)
                    end
                    CSkillFrame:SetHidden(true)
                    if disciplineIndex == GetRequiredChampionDisciplineIdForSlot(CSlotIndex, HOTBAR_CATEGORY_CHAMPION) then
                        local CSlotId = GetSlotBoundId(CSlotIndex, HOTBAR_CATEGORY_CHAMPION)
                        CSkillPoint = GetNumPointsSpentOnChampionSkill(CSlotId)
                        if CSkillPoint > 0 then
                            CSkillName = zo_strformat(SI_CHAMPION_STAR_NAME, GetChampionSkillName(CSlotId))
                            -- anchor offsets be align with frame's dimension
                            CSkillAnchor:SetOffsets(math.mod(NumChampionSkillActivated, 2) * 150 + 2,
                                25 + math.floor(NumChampionSkillActivated / 2) * 25 + 4)
                                
                            NumChampionSkillActivated = NumChampionSkillActivated + 1
                            CSkillAnchor:Set(CSkillFrame)
                            CSkillFrame:SetHidden(false)
                            CSkillFrame.cSkillId = CSlotId
                            CSkillFrame.nPPoints = CSkillPoint
                            CSkillFrame:GetNamedChild("Name"):SetText(CSkillName)
                            CSkillFrame:GetNamedChild("Value"):SetText(CSkillPoint)
                            CSkillFrame:GetNamedChild("Star"):SetTexture(TextureSlot)
                            CSkillFrame:GetNamedChild("Star"):SetHidden(false)
                            CSkillFrame:GetNamedChild("StarSelect"):SetTexture(TextureSelect)
                            CSkillFrame:GetNamedChild("StarSelect"):SetHidden(false)
                            CSkillFrame:GetNamedChild("StarBorder"):SetHidden(true)
                        end
                    end
                end
                -- Searching for nonslotable CP
                -- if #scribingSkillSlotted ~= 0 then
                --     for CSkillIndex = 1, NumChampionSkill do
                --         if NumChampionSkillActivated >= skillDisplayNumCap then
                --             break
                --         end
                --         local windowName = VIRTUALNAME .. disciplineIndex .. "at" .. (NumChampionSkillActivated + 1)
                --         local CSkillFrame = GetControl(windowName)
                --         if not CSkillFrame then
                --             CSkillFrame = CreateControlFromVirtual(windowName, Discipline, VIRTUALNAME)
                --         end
                --         CSkillFrame:SetHidden(true)
                --         CSkillId = GetChampionSkillId(math.mod(disciplineIndex, 3) + 1, CSkillIndex)
                --         CSkillPoint = GetNumPointsSpentOnChampionSkill(CSkillId)
                --         if CSkillPoint > 0 and not CanChampionSkillTypeBeSlotted(GetChampionSkillType(CSkillId)) then
                --             CSkillName = zo_strformat(SI_CHAMPION_STAR_NAME, GetChampionSkillName(CSkillId))
                --             CSkillAnchor:SetOffsets(math.mod(NumChampionSkillActivated, 2) * 150,
                --                 20 + math.floor(NumChampionSkillActivated / 2) * 20)

                --             NumChampionSkillActivated = NumChampionSkillActivated + 1
                --             CSkillAnchor:Set(CSkillFrame)
                --             CSkillFrame:SetHidden(false)
                --             CSkillFrame.cSkillId = CSkillId
                --             CSkillFrame.nPPoints = CSkillPoint
                --             CSkillFrame:GetNamedChild("Name"):SetText(CSkillName)
                --             CSkillFrame:GetNamedChild("Value"):SetText(CSkillPoint)
                --             CSkillFrame:GetNamedChild("Star"):SetHidden(true)
                --             CSkillFrame:GetNamedChild("StarBorder"):SetHidden(true)
                --             CSkillFrame:GetNamedChild("StarSelect"):SetHidden(true)
                --             -- d(CSkillName)
                --         end
                --     end
                --     d(NumChampionSkillActivated)
                -- end

                if NumChampionSkillActivated < skillDisplayNumCap then
                    for CSkillIndex = NumChampionSkillActivated, 18 do
                        local windowName = VIRTUALNAME .. disciplineIndex .. "at" .. (CSkillIndex + 1)
                        local CSkillFrame = GetControl(windowName)
                        if not CSkillFrame then
                            CSkillFrame = CreateControlFromVirtual(windowName, Discipline, VIRTUALNAME)
                        end
                        CSkillFrame:SetHidden(true)
                        -- d(CSkillFrame:GetNamedChild("Name"):SetText(CSkillName))
                    end
                end
            end
        end
    end
end


-- Blk: Favorites List =========================================================

local function GetDataByName(name, array)
    local dataList = db[array]
    for index, data in ipairs(dataList) do
        if (data.name == name) then
            return data, index
        end
    end
end

local favoritesList = ZO_SortFilterList:Subclass()

function favoritesList:New(control)

    SuperStarSkills.localPlayerHash, SuperStarSkills.localPlayerCRequired, SuperStarSkills.localPlayerSRequired, SuperStarSkills.localPlayerARequired =
        BuildHashs(true, true, true)

    ZO_SortFilterList.InitializeSortFilterList(self, control)

    local SorterKeys = {
        ["name"] = {},
        ["cp"] = {
            tiebreaker = "name",
            isNumeric = true
        },
        ["sp"] = {
            tiebreaker = "name",
            isNumeric = true
        },
        ["attr"] = {
            tiebreaker = "name",
            isNumeric = true
        }
    }

    self.masterList = {}

    ZO_ScrollList_AddDataType(self.list, 1, "SuperStarXMLFavoriteRowTemplate", 32, function(control, data)
        self:SetupEntry(control, data)
    end)
    ZO_ScrollList_EnableHighlight(self.list, "ZO_ThinListHighlight")

    self.currentSortKey = "name"
    self.sortFunction = function(listEntry1, listEntry2)
        return ZO_TableOrderingFunction(listEntry1.data, listEntry2.data, self.currentSortKey, SorterKeys,
            self.currentSortOrder)
    end
    self:SetAlternateRowBackgrounds(true)

    return self

end

function favoritesList:SetupEntry(control, data)

    control.data = data
    control.name = GetControl(control, "Name")
    control.sp = GetControl(control, "SP")
    control.cp = GetControl(control, "CP")
    control.attr = GetControl(control, "Attr")

    control.name:SetText(data.name)
    control.sp:SetText(data.sp)
    control.cp:SetText(data.cp)
    control.attr:SetText(data.attr)

    ZO_SortFilterList.SetupRow(self, control, data)

end

function favoritesList:BuildMasterList()
    self.masterList = {}

    local _, index = GetDataByName(virtualFavorite, "favoritesList")
    local updatedDataForLocalChar = {
        name = virtualFavorite,
        cp = SuperStarSkills.localPlayerCRequired,
        attr = SuperStarSkills.localPlayerARequired,
        hash = SuperStarSkills.localPlayerHash,
        sp = SuperStarSkills.localPlayerSRequired,
        favoriteLocked = true
    }

    if index then
        db.favoritesList[index] = updatedDataForLocalChar
    else
        table.insert(db.favoritesList, updatedDataForLocalChar)
    end

    if db.favoritesList then
        for k, v in ipairs(db.favoritesList) do
            local data = v
            table.insert(self.masterList, data)
        end
    end

end

function favoritesList:SortScrollList()
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    table.sort(scrollData, self.sortFunction)
end

function favoritesList:FilterScrollList()
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    ZO_ClearNumericallyIndexedTable(scrollData)

    for i = 1, #self.masterList do
        local data = self.masterList[i]
        table.insert(scrollData, ZO_ScrollList_CreateDataEntry(1, data))
    end
end

local function CleanSortListForDB(array)
    -- :RefreshData() adds dataEntry recursively, delete it to avoid overflow in SavedVars
    for i = #db[array], 1, -1 do
        db[array][i].dataEntry = nil
    end
end

local function AddFavoriteFromSkillBuilder(control)

    local hash = BuildBuilderSkillsHash()
    -- d("hash: " .. hash)
    if hash ~= "" then
        ZO_Dialogs_ShowDialog("SUPERSTAR_SAVE_SKILL_FAV", {
            hash = hash
        }, {
            mainTextParams = {functionName}
        })
    end

end

local function AddFavoriteWithCPFromSkillBuilder(control)

    local hash = BuildHashs(true, true, false, true)
    if hash ~= "" then
        ZO_Dialogs_ShowDialog("SUPERSTAR_SAVE_SKILL_FAV", {
            hash = hash
        }, {
            mainTextParams = {functionName}
        })
    end

end

local function AddFavoriteFromImport(control)
    local hash = SuperStarXMLImport:GetNamedChild("ImportValueEdit"):GetText()
    ZO_Dialogs_ShowDialog("SUPERSTAR_SAVE_FAV", {
        hash = hash
    }, {
        mainTextParams = {functionName}
    })
end

local function ConfirmSaveFav(favName, hash)
    -- Show SuperStar Build Scene
    LMM:Update(MENU_CATEGORY_SUPERSTAR, "SuperStarFavorites")

    local attrData, skillsData, cpData = CheckImportedBuild(hash)

    if attrData and skillsData and cpData then

        if string.len(favName) > 40 then
            favName = string.sub(favName, 1, 40) .. " ..."
        end

        local cpPoints = 0
        local attrPoints = 0
        local spPoints = 0

        if type(cpData) == "table" then
            cpPoints = cpData.pointsRequired
        end
        if type(attrData) == "table" then
            attrPoints = attrData.pointsRequired
        end
        if type(skillsData) == "table" then
            spPoints = skillsData.pointsRequired
        end

        local data = {
            name = favName,
            cp = cpPoints,
            attr = attrPoints,
            hash = hash,
            sp = spPoints
        }
        local entry = ZO_ScrollList_CreateDataEntry(1, data)
        local entryList = ZO_ScrollList_GetDataList(favoritesManager.list)

        table.insert(entryList, entry)
        table.insert(db.favoritesList, {
            name = favName,
            cp = cpPoints,
            attr = attrPoints,
            hash = hash,
            sp = spPoints
        }) -- "data" variable is modified by ZO_ScrollList_CreateDataEntry and will crash eso if saved to savedvars

        favoritesManager:RefreshData()
        CleanSortListForDB("favoritesList")

    end

end

local function RemoveFavorite(control)
    local data = ZO_ScrollList_GetData(WINDOW_MANAGER:GetMouseOverControl())
    if data.name ~= virtualFavorite then
        local _, index = GetDataByName(data.name, "favoritesList")
        table.remove(db.favoritesList, index)
        favoritesManager:RefreshData()
        CleanSortListForDB("favoritesList")
    end
end

-- called from Favorites tab "View Skills"
local function ViewFavorite()
    local data = ZO_ScrollList_GetData(WINDOW_MANAGER:GetMouseOverControl())
    local _, index = GetDataByName(data.name, "favoritesList")

    local attrData, skillsData, cpData = CheckImportedBuild(db.favoritesList[index].hash)

    if attrData and skillsData and cpData then

        SuperStarSkills.pendingSkillsDataForLoading = skillsData
        SuperStarSkills.pendingCPDataForLoading = cpData
        SuperStarSkills.pendingAttrDataForLoading = attrData
        ResetSkillBuilderAndLoadBuild()
        -- ResetSkillBuilder()

        --[[
        --sigo@v4.1.3
        --allow builds to be edited even if you don't have enough skill points
        if SuperStarSkills.spentSkillPoints < db.favoritesList[index].sp then
        SuperStarSkills.spentSkillPoints = math.max(SP_MAX_SPENDABLE_POINTS, db.favoritesList[index].sp) -- set to SP_MAX_SPENDABLE_POINTS or db.favoritesList[index].sp
        SuperStarXMLSkillsPreSelector:GetNamedChild("SkillPoints"):GetNamedChild("Display"):SetText(SuperStarSkills.spentSkillPoints)
        SuperStarXMLSkillsPreSelector:GetNamedChild("SkillPoints"):GetNamedChild("Display"):SetColor(1, 0, 0, 1)
        end
        local availablePoints = SuperStarSkills.spentSkillPoints - db.favoritesList[index].sp

        -- summerset
        -- do we really care if they have enough points? it's a skill builder
        -- shouldn't this be >=?
        if availablePoints >= 0 then
        --sigo@v4.1.3
        SuperStarSkills.class = skillsData.classId
        SuperStarSkills.race = skillsData.raceId
        LSF:Initialize(skillsData.classId, skillsData.raceId)
        SuperStarSkills.builderFactory = skillsData
        SuperStarSkills.pendingCPDataForBuilder = cpData
        SuperStarSkills.pendingAttrDataForBuilder = attrData

        SuperStarSkills.spentSkillPoints = availablePoints

        SUPERSTAR_SKILLS_SCENE:RemoveFragment(SUPERSTAR_SKILLS_PRESELECTORWINDOW)
        SUPERSTAR_SKILLS_SCENE:AddFragment(SUPERSTAR_SKILLS_BUILDERWINDOW)

        LMM:Update(MENU_CATEGORY_SUPERSTAR, "SuperStarSkills")
        else
        --d(string.format("[SuperStar] Not enough available skill points. Have: %u, Need: %u", SuperStarSkills.spentSkillPoints, db.favoritesList[index].sp))
        end
        ]] --

    else
        -- d("[ERROR] Unable to load favorite in skill builder")
    end

end

local function ViewFavoriteHash()

    local data = ZO_ScrollList_GetData(WINDOW_MANAGER:GetMouseOverControl())
    local _, index = GetDataByName(data.name, "favoritesList")

    local attrData, skillsData, cpData = CheckImportedBuild(db.favoritesList[index].hash)

    if attrData and skillsData and cpData then

        SuperStarXMLImport:GetNamedChild("ImportValueEdit"):SetText(db.favoritesList[index].hash)

        local text = db.favoritesList[index].hash

        isImportedBuildValid = false

        if text ~= "" then

            local attrData, skillsData, cpData = CheckImportedBuild(text)
            SuperStarXMLImport:GetNamedChild("ImportSeeBuild"):SetHidden(false)

            if attrData and skillsData and cpData then
                UpdateHashDataContainer(attrData, skillsData, cpData)
            else
                UpdateHashDataContainer(false, false, false)
            end

        else
            SuperStarXMLImport:GetNamedChild("ImportSeeBuild"):SetHidden(true)
            UpdateHashDataContainer(false, false, false)
        end

        LMM:Update(MENU_CATEGORY_SUPERSTAR, "SuperStarImport")

    end

end

-- summerset
-- copied this function for now, don't want to change the original
local function CheckOutdatedBuild(build)
    local hasAttr = string.find(build, TAG_ATTRIBUTES)
    local hasSkills = string.find(build, TAG_SKILLS)
    local hasCP = string.find(build, "%%") -- special char for gsub (TAG_CP)

    local hashAttr = ""
    local hashSkills = ""
    local hashCP = ""

    if hasAttr then
        hashAttr = string.sub(build, hasAttr)
    end

    if hasSkills then
        if hasAttr then
            hashSkills = string.sub(build, hasSkills, hasAttr - 1)
        else
            hashSkills = string.sub(build, hasSkills)
        end
    end

    if hasCP then
        if hasSkills then
            hashCP = string.sub(build, 1, hasSkills - 1)
        elseif hasAttr then
            hashCP = string.sub(build, 1, hasAttr - 1)
        else
            hashCP = build
        end
    end

    local attrData
    local skillsData
    local cpData

    if hasAttr or hasSkills or hasCP then

        attrData = true
        skillsData = true
        cpData = true

        if hasAttr and hashAttr then
            attrData = ParseAttrHash(hashAttr)
        end

        if hasSkills and hashSkills then
            -- update the skills
            local hashVersion = string.sub(hashSkills, 2, 2)
            local hashMode = string.sub(hashSkills, 3, 3)
            -- d(hashSkills)
            hashSkills = UpdateOlderSkillHash(hashSkills, hashVersion, hashMode)
            -- d(hashSkills)
            skillsData = ParseSkillsHash(hashSkills)
            -- d(skillsData == false)
        end

        if hasCP and hashCP then
            local hashCPVersion = string.sub(hashCP, 2, 2)
            local hashCPMode = string.sub(hashCP, 3, 3)
            if hashCPVersion ~= REVISION_CP then
                hashCP = ""
            elseif hashCPMode ~= MODE_CP then
                hashCP = ""
            else
                cpData = ParseCPHash(hashCP)
                d(cpData == false)
            end
        end
    end

    if attrData and skillsData and cpData then
        return hashCP .. hashSkills .. hashAttr
    else
        return nil
    end

end

local function UpdateFavoriteHash()
    local data = ZO_ScrollList_GetData(WINDOW_MANAGER:GetMouseOverControl())
    local _, index = GetDataByName(data.name, "favoritesList")
    local hash = CheckOutdatedBuild(db.favoritesList[index].hash)

    if hash ~= db.favoritesList[index].hash then
        -- hash conversion appears to be successful
        ZO_Dialogs_ShowDialog("SUPERSTAR_SAVE_SKILL_FAV", {
            hash = hash
        }, {
            mainTextParams = {functionName}
        })
    end
end

-- Called by XML
function SuperStar_HoverRowOfFavorite(control)
    favoritesList:Row_OnMouseEnter(control)
    local data = ZO_ScrollList_GetData(WINDOW_MANAGER:GetMouseOverControl())

    isFavoriteLocked = data.favoriteLocked and "$" .. GetUnitName("player") == data.name
    isFavoriteShown = true
    -- isFavoriteOutdated = string.find(data.hash, "@21")
    isFavoriteOutdated = not string.find(data.hash, CURRENT_VALID_SKILL_TAG) or
                             not string.find(data.hash, '%' .. TAG_CP .. REVISION_CP .. MODE_CP)

    local attrData, skillsData, cpData = CheckImportedBuild(data.hash)
    if attrData and skillsData and cpData then
        isFavoriteValid = true
        isFavoriteHaveSP = type(skillsData) == "table" and skillsData.pointsRequired > 0
        isFavoriteHaveCP = type(cpData) == "table" and cpData.pointsRequired > 0
    end

    KEYBIND_STRIP:UpdateKeybindButtonGroup(SUPERSTAR_FAVORITES_WINDOW.favoritesKeybindStripDescriptor)

end

-- Called by XML
function SuperStar_ExitRowOfFavorite(control)

    isFavoriteShown = false
    isFavoriteLocked = false
    isFavoriteHaveSP = false
    isFavoriteHaveCP = false
    isFavoriteValid = false
    isFavoriteOutdated = false

    favoritesList:Row_OnMouseExit(control)
    KEYBIND_STRIP:UpdateKeybindButtonGroup(SUPERSTAR_FAVORITES_WINDOW.favoritesKeybindStripDescriptor)

end
-- Blk: Companion Scene ========================================================
local function BuildCompanionScene(control)
    EnsureCompanionSceneVirtualControls(control)

    -- d(GetAllUnitAttributeVisualizerEffectInfo("companion"))
    local CompanionIcon = control:GetNamedChild("CompanionIcon")
    local Level = control:GetNamedChild("Level")
    local Name = control:GetNamedChild("Name")
    local Rapport = control:GetNamedChild("Rapport")
    local RapportLevel = control:GetNamedChild("RapportLevel")
    local MaxHealth = control:GetNamedChild("MaxHealthPoints")
    local PassivePerk = control:GetNamedChild("PassivePerk")
    local PassivePerkName = PassivePerk:GetNamedChild("Value")

    -- Active Skills
    local ActiveWeapon = control:GetNamedChild("ActiveWeapon")
    local ActiveSkill1 = control:GetNamedChild("ActiveSkill1")
    local ActiveSkill2 = control:GetNamedChild("ActiveSkill2")
    local ActiveSkill3 = control:GetNamedChild("ActiveSkill3")
    local ActiveSkill4 = control:GetNamedChild("ActiveSkill4")
    local ActiveSkill5 = control:GetNamedChild("ActiveSkill5")
    local ActiveSkill6 = control:GetNamedChild("ActiveSkill6")

    local companionId = GetActiveCompanionDefId()
    local name = GetCompanionName(companionId)
    local passivePerkId = GetCompanionPassivePerkAbilityId(companionId)
    local level, currentExp = GetActiveCompanionLevelInfo()
    local rapport = GetActiveCompanionRapport()
    local rapportLevel = GetActiveCompanionRapportLevel()
    local _, maxHealth = GetUnitPower("companion", POWERTYPE_HEALTH)
    local numCompanionSlotsUnlocked = GetCompanionNumSlotsUnlockedForLevel(level)
    -- GetUnitBuffInfo

    CompanionIcon:SetTexture(ZO_COMPANION_MANAGER:GetActiveCompanionIcon())
    Level:SetText(level)
    Name:SetText(zo_strformat(SI_COMPANION_NAME_FORMATTER, name))
    MaxHealth:SetText(maxHealth)
    PassivePerk.passivePerkId = passivePerkId
    PassivePerkName:SetText(ZO_CachedStrFormat(SI_ABILITY_NAME, GetAbilityName(passivePerkId)))

    -- Set Rapport
    Rapport:SetText(rapport)
    RapportLevel:SetText(GetString("SI_COMPANIONRAPPORTLEVEL", rapportLevel))
    RapportLevel.rapportDesc = GetActiveCompanionRapportLevelDescription(rapportLevel)
    local rapportMinValue = GetMinimumRapport()
    local rapportMaxValue = GetMaximumRapport()
    local RAPPORT_GRADIENT_START = ZO_ColorDef:New("722323") -- Red
    local RAPPORT_GRADIENT_END = ZO_ColorDef:New("009966") -- Green
    local RAPPORT_GRADIENT_MIDDLE = ZO_ColorDef:New("9D840D") -- Yellow
    local percentProgress = zo_percentBetween(rapportMinValue, rapportMaxValue, rapport)
    local rapportColor
    if percentProgress > 0.5 then
        rapportColor = RAPPORT_GRADIENT_MIDDLE:Lerp(RAPPORT_GRADIENT_END, percentProgress - 0.5)
    else
        rapportColor = RAPPORT_GRADIENT_START:Lerp(RAPPORT_GRADIENT_MIDDLE, percentProgress)
    end
    RapportLevel:SetColor(rapportColor:UnpackRGB())

    -- Set weapon and skill texture
    local firstWeapon, secondWeapon
    firstWeapon = GetItemWeaponType(BAG_COMPANION_WORN, EQUIP_SLOT_MAIN_HAND)
    secondWeapon = GetItemWeaponType(BAG_COMPANION_WORN, EQUIP_SLOT_OFF_HAND)

    ShowSlotTexture(ActiveWeapon, GetWeaponIconPair(firstWeapon, secondWeapon))
    for index = 1, 6 do
        local ActiveSkill = control:GetNamedChild("ActiveSkill" .. index)
        if index <= numCompanionSlotsUnlocked then
            ShowSlotTexture(ActiveSkill, GetSlotBoundId(2 + index, HOTBAR_CATEGORY_COMPANION))
        else
            ShowSlotTexture(ActiveSkill, "/esoui/art/miscellaneous/status_locked.dds")
        end
    end

    -- Set Gears
    local slots = {
        [EQUIP_SLOT_HEAD] = true,
        [EQUIP_SLOT_NECK] = true,
        [EQUIP_SLOT_CHEST] = true,
        [EQUIP_SLOT_SHOULDERS] = true,
        [EQUIP_SLOT_MAIN_HAND] = true,
        [EQUIP_SLOT_OFF_HAND] = true,
        [EQUIP_SLOT_WAIST] = true,
        [EQUIP_SLOT_LEGS] = true,
        [EQUIP_SLOT_FEET] = true,
        [EQUIP_SLOT_RING1] = true,
        [EQUIP_SLOT_RING2] = true,
        [EQUIP_SLOT_HAND] = true
    }

    local SSslotData = {}

    for slotId in pairs(slots) do

        local itemLink = GetItemLink(BAG_COMPANION_WORN, slotId)

        SSslotData[slotId] = {}
        if GetString("SUPERSTAR_SLOTNAME", slotId) ~= "" then
            SSslotData[slotId].slotName = GetString("SUPERSTAR_SLOTNAME", slotId)
        else
            SSslotData[slotId].slotName = zo_strformat(SI_ITEM_FORMAT_STR_BROAD_TYPE, GetString("SI_EQUIPSLOT", slotId))
        end

        SSslotData[slotId].labelControl = control:GetNamedChild("Stuff" .. slotId .. "Label")
        SSslotData[slotId].valueControl = control:GetNamedChild("Stuff" .. slotId .. "Name")
        SSslotData[slotId].traitControl = control:GetNamedChild("Stuff" .. slotId .. "Trait")
        SSslotData[slotId].traitDescControl = control:GetNamedChild("Stuff" .. slotId .. "TraitDesc")

        if itemLink ~= "" then
            local name = GetItemLinkName(itemLink)
            local traitType, traitDescription = GetItemLinkTraitInfo(itemLink)
            local quality = GetItemLinkDisplayQuality(itemLink)
            local armorType = GetItemLinkArmorType(itemLink)
            local icon = GetItemLinkInfo(itemLink)

            name = GetItemQualityColor(quality):Colorize(zo_strformat(SI_TOOLTIP_ITEM_NAME, name))

            local traitName
            if (traitType ~= ITEM_TRAIT_TYPE_NONE and traitType ~= ITEM_TRAIT_TYPE_SPECIAL_STAT and traitDescription ~=
                "") then
                traitName = GetString("SI_ITEMTRAITTYPE", traitType)
                traitDescription = zo_strformat("<<1>>", traitDescription)
            else
                traitName = SUPERSTAR_GENERIC_NA
                traitDescription = SUPERSTAR_GENERIC_NA
            end

            SSslotData[slotId].name = name
            SSslotData[slotId].traitName = traitName
            SSslotData[slotId].icon = icon

            SSslotData[slotId].labelControl:SetText(SSslotData[slotId].slotName)

            local magickaColor = GetItemQualityColor(ITEM_QUALITY_ARCANE)
            local staminaColor = GetItemQualityColor(ITEM_QUALITY_MAGIC)
            if armorType == ARMORTYPE_HEAVY then
                SSslotData[slotId].labelControl:SetColor(1, 0, 0)
            elseif armorType == ARMORTYPE_MEDIUM then
                SSslotData[slotId].labelControl:SetColor(staminaColor.r, staminaColor.g, staminaColor.b)
            elseif armorType == ARMORTYPE_LIGHT then
                SSslotData[slotId].labelControl:SetColor(magickaColor.r, magickaColor.g, magickaColor.b)
            end

            SSslotData[slotId].valueControl:SetText(SSslotData[slotId].name)
            SSslotData[slotId].valueControl.itemLink = itemLink

            SSslotData[slotId].traitControl:SetText(SSslotData[slotId].traitName)
            SSslotData[slotId].traitDescControl:SetText(traitDescription)

        else
            SSslotData[slotId].dontWearSlot = true

            SSslotData[slotId].labelControl:SetText(SSslotData[slotId].slotName)
            SSslotData[slotId].labelControl:SetColor(ZO_DISABLED_TEXT:UnpackRGBA())
            SSslotData[slotId].valueControl:SetText(SUPERSTAR_GENERIC_NA)
            SSslotData[slotId].traitControl:SetText(SUPERSTAR_GENERIC_NA)
            SSslotData[slotId].traitDescControl:SetText(SUPERSTAR_GENERIC_NA)
        end
    end
end

local function BuildMainScene()
    if showingCharInMain then
        SuperStarXMLMainCompanion:SetHidden(true)
        SuperStarXMLMainCharacter:SetHidden(false)
        BuildMainSceneLocal(SuperStarXMLMainCharacter)
    else
        SuperStarXMLMainCharacter:SetHidden(true)
        SuperStarXMLMainCompanion:SetHidden(false)
        BuildCompanionScene(SuperStarXMLMainCompanion)
    end
end

local function AnimateFadeSwitch(fromControl, toControl, isToCharacter)
    toControl:SetAlpha(0)
    toControl:SetHidden(false)
    if isToCharacter then
        BuildMainSceneLocal(toControl)
    else
        BuildCompanionScene(toControl)
    end

    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local fadeOut = timeline:InsertAnimation(ANIMATION_ALPHA, fromControl)
    fadeOut:SetDuration(200)
    fadeOut:SetEasingFunction(ZO_EaseOutQuintic)
    fadeOut:SetAlphaValues(1, 0)

    local fadeIn = timeline:InsertAnimation(ANIMATION_ALPHA, toControl, 200)
    fadeIn:SetDuration(200)
    fadeIn:SetEasingFunction(ZO_EaseOutQuintic)
    fadeIn:SetAlphaValues(0, 1)

    timeline:SetHandler("OnStop", function()
        fromControl:SetHidden(true)
        fromControl:SetAlpha(1)
    end)
    timeline:PlayFromStart()
end

local function ToggleCharacterCompanion(control)
    showingCharInMain = not showingCharInMain
    if showingCharInMain then
        AnimateFadeSwitch(SuperStarXMLMainCompanion, SuperStarXMLMainCharacter, true)
    else
        AnimateFadeSwitch(SuperStarXMLMainCharacter, SuperStarXMLMainCompanion, false)
    end
end

local function RespecFavoriteSP(control)
    local data = ZO_ScrollList_GetData(WINDOW_MANAGER:GetMouseOverControl())
    local _, index = GetDataByName(data.name, "favoritesList")
    ShowRespecScene(index, RESPEC_MODE_SP)
end

local function RespecFavoriteCP(control)
    local data = ZO_ScrollList_GetData(WINDOW_MANAGER:GetMouseOverControl())
    local _, index = GetDataByName(data.name, "favoritesList")
    ShowRespecScene(index, RESPEC_MODE_CP)
end

-- Lykeion@6.0.0
local function isQueueable(index)
    if index == SIDEBAR_INDEX_HISTORY then
        for i, v in ipairs(pickedHistory) do
            if not IsCraftedAbilityUnlocked(v[SCRIBING_SLOT_NONE]) or 
            not IsCraftedAbilityScriptUnlocked(v[SCRIBING_SLOT_PRIMARY]) or 
            not IsCraftedAbilityScriptUnlocked(v[SCRIBING_SLOT_SECONDARY]) or 
            not IsCraftedAbilityScriptUnlocked(v[SCRIBING_SLOT_TERTIARY]) then
                return false
            end
        end
    elseif index == SIDEBAR_INDEX_FAVORITE then
        for i, v in ipairs(pickedFavorites) do
            if not IsCraftedAbilityUnlocked(v[SCRIBING_SLOT_NONE]) or 
            not IsCraftedAbilityScriptUnlocked(v[SCRIBING_SLOT_PRIMARY]) or 
            not IsCraftedAbilityScriptUnlocked(v[SCRIBING_SLOT_SECONDARY]) or 
            not IsCraftedAbilityScriptUnlocked(v[SCRIBING_SLOT_TERTIARY]) then
                return false
            end
        end
    else
        return false
    end
    return true
end

local function AddScribingSkillToFav(_)
    for i = 1, #pickedHistory do
        local duplicate = false
        for j = 1 ,#db.favoriteScribed do
            if pickedHistory[i][SCRIBING_SLOT_NONE] == db.favoriteScribed[j][SCRIBING_SLOT_NONE] and 
            pickedHistory[i][SCRIBING_SLOT_PRIMARY] == db.favoriteScribed[j][SCRIBING_SLOT_PRIMARY] and 
            pickedHistory[i][SCRIBING_SLOT_SECONDARY] == db.favoriteScribed[j][SCRIBING_SLOT_SECONDARY] and 
            pickedHistory[i][SCRIBING_SLOT_TERTIARY] == db.favoriteScribed[j][SCRIBING_SLOT_TERTIARY] then
                duplicate = true
                break
            end
        end
        if not duplicate then
            table.insert(db.favoriteScribed, 
            {[SCRIBING_SLOT_NONE] = pickedHistory[i][SCRIBING_SLOT_NONE], 
            [SCRIBING_SLOT_PRIMARY] = pickedHistory[i][SCRIBING_SLOT_PRIMARY], 
            [SCRIBING_SLOT_SECONDARY] = pickedHistory[i][SCRIBING_SLOT_SECONDARY], 
            [SCRIBING_SLOT_TERTIARY] = pickedHistory[i][SCRIBING_SLOT_TERTIARY]}
        )
        end
    end
    PlaySound("Champion_RespecToggled")
    resetPicking(SIDEBAR_INDEX_FAVORITE)
    resetPicking(SIDEBAR_INDEX_HISTORY)
end

local function RemoveScribingSkillFromFav(_)
    for i = 1, #pickedFavorites do
        for j = #db.favoriteScribed, 1, -1  do
            if pickedFavorites[i][SCRIBING_SLOT_NONE] == db.favoriteScribed[j][SCRIBING_SLOT_NONE] and 
            pickedFavorites[i][SCRIBING_SLOT_PRIMARY] == db.favoriteScribed[j][SCRIBING_SLOT_PRIMARY] and 
            pickedFavorites[i][SCRIBING_SLOT_SECONDARY] == db.favoriteScribed[j][SCRIBING_SLOT_SECONDARY] and 
            pickedFavorites[i][SCRIBING_SLOT_TERTIARY] == db.favoriteScribed[j][SCRIBING_SLOT_TERTIARY] then
                table.remove(db.favoriteScribed, j)
                break
            end
        end
    end
    PlaySound(SOUNDS.QUICKSLOT_USE_EMPTY)
    resetPicking(SIDEBAR_INDEX_FAVORITE)
end

local function ClearQueue(index)
    ZO_Dialogs_ShowDialog("SUPERSTAR_SCRIBING_CLEAR", {
        index = index
    }, {
        mainTextParams = {functionName}
    })
end

local function getInkConsumption(queue)
    local consumption = 0
    for i, data in ipairs(queue) do
        consumption = consumption + GetCostToScribeScripts(data[SCRIBING_SLOT_NONE], data[SCRIBING_SLOT_PRIMARY], data[SCRIBING_SLOT_SECONDARY], data[SCRIBING_SLOT_TERTIARY])
    end
    return consumption
end

local function addPickedToQueue(index)
    local isDuplicate
    local picked
    
    if index == SIDEBAR_INDEX_HISTORY then
        picked = pickedHistory
    elseif index == SIDEBAR_INDEX_FAVORITE then
        picked = pickedFavorites
    else
        return
    end
    for i, data in ipairs(picked) do
        isDuplicate = false
        -- check if it is already scribed, if so then continue
        local pri, sec, ter = GetCraftedAbilityActiveScriptIds(data[SCRIBING_SLOT_NONE])
        if (pri == data[SCRIBING_SLOT_PRIMARY] and sec == data[SCRIBING_SLOT_SECONDARY] and ter == data[SCRIBING_SLOT_TERTIARY]) then
            -- do nothing, as continue
        else
            -- if same skill is queued, then overwrite it with the newer one
            for j, skill in ipairs(scribingQueue) do
                if data[SCRIBING_SLOT_NONE] == skill[SCRIBING_SLOT_NONE] then
                    skill[SCRIBING_SLOT_PRIMARY] = data[SCRIBING_SLOT_PRIMARY]
                    skill[SCRIBING_SLOT_SECONDARY] = data[SCRIBING_SLOT_SECONDARY]
                    skill[SCRIBING_SLOT_TERTIARY] = data[SCRIBING_SLOT_TERTIARY]
                    isDuplicate = true
                end
            end
            if not isDuplicate then
                table.insert(scribingQueue, {[SCRIBING_SLOT_NONE] = data[SCRIBING_SLOT_NONE], [SCRIBING_SLOT_PRIMARY] = data[SCRIBING_SLOT_PRIMARY], [SCRIBING_SLOT_SECONDARY] = data[SCRIBING_SLOT_SECONDARY], [SCRIBING_SLOT_TERTIARY] = data[SCRIBING_SLOT_TERTIARY]})
            end
        end
    end
end

-- My first attempt to auto scribing, yet unsuccessful, cuz EVENT_CRAFT_COMPLETED is also throwed when interrupting craft and leaving station. WEIRD BEHAVIOR
-- local function OnScribingCompleted(_, craftSkill )
--     if craftSkill ~= CRAFTING_TYPE_SCRIBING then
--         return
--     end
--     if scribingQueue[1] then
--         RequestScribe(scribingQueue[1][SCRIBING_SLOT_NONE], scribingQueue[1][SCRIBING_SLOT_PRIMARY], scribingQueue[1][SCRIBING_SLOT_SECONDARY], scribingQueue[1][SCRIBING_SLOT_TERTIARY])
--         table.remove(scribingQueue, 1)
--     else
--         scribingQueueCompleted = true
--         d("scribingQueueCompleted: "..tostring(scribingQueueCompleted))
--         scribingQueue = {}
--         EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_CRAFT_COMPLETED)
--         return
--     end
-- end

-- local function startScribingQueue()
--     scribingQueueCompleted = false
--     d("scribingQueueCompleted: "..tostring(scribingQueueCompleted))
--     if scribingQueue[1] then
--         RequestScribe(scribingQueue[1][SCRIBING_SLOT_NONE], scribingQueue[1][SCRIBING_SLOT_PRIMARY], scribingQueue[1][SCRIBING_SLOT_SECONDARY], scribingQueue[1][SCRIBING_SLOT_TERTIARY])
--         table.remove(scribingQueue, 1)
--         EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CRAFT_COMPLETED, OnScribingCompleted)
--     else
--         return
--     end
-- end

local function queueForScribing()
    if scribingQueue[1] then
        RequestScribe(scribingQueue[1][SCRIBING_SLOT_NONE], scribingQueue[1][SCRIBING_SLOT_PRIMARY], scribingQueue[1][SCRIBING_SLOT_SECONDARY], scribingQueue[1][SCRIBING_SLOT_TERTIARY])
        scribingQueueRemove = zo_callLater(function() table.remove(scribingQueue, 1) end, 2250)
        scribingQueueNest = zo_callLater(queueForScribing, GetLatency() + 2250)
    else
        return
    end
end

local function OnLeavingCraftingStation(_, craftSkill, _, _ )
    if craftSkill ~= CRAFTING_TYPE_SCRIBING then
        return
    end
    if scribingQueue[1] then
        d(GetString(SUPERSTAR_CHATBOX_QUEUE_ABORTED))
    end
    scribingQueue = {}
    zo_removeCallLater(scribingQueueRemove)
    scribingQueueRemove = nil    
    zo_removeCallLater(scribingQueueNest)
    scribingQueueNest = nil
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_END_CRAFTING_STATION_INTERACT)
end

local function OnUsingCraftingStation(_, craftSkill, _, _ )
    if craftSkill ~= CRAFTING_TYPE_SCRIBING then 
        return
    end
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_END_CRAFTING_STATION_INTERACT, OnLeavingCraftingStation)
    local consumption = getInkConsumption(scribingQueue)
    local owned = select(1, GetItemLinkStacks(GetScribingInkItemLink(LINK_STYLE_DEFAULT))) + select(2, GetItemLinkStacks(GetScribingInkItemLink(LINK_STYLE_DEFAULT))) + select(3, GetItemLinkStacks(GetScribingInkItemLink(LINK_STYLE_DEFAULT)))
    if consumption > owned then
        d(zo_strformat(SUPERSTAR_CHATBOX_QUEUE_CANCELED, consumption, owned))
    else
        queueForScribing()
    end
    -- startScribingQueue()
    resetPicking(SIDEBAR_INDEX_FAVORITE)
    resetPicking(SIDEBAR_INDEX_HISTORY)
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_CRAFTING_STATION_INTERACT)
end

local function InitScribingScene()
    renderSidebar(CACHED_SIDEBAR_INDEX)
    local scribingRoot = GetControl("SuperStarXMLScribing")
    scribingXmlGroup = {
        [SCRIBING_SLOT_NONE] = scribingRoot:GetNamedChild("Grimoire"),
        [SCRIBING_SLOT_PRIMARY] = scribingRoot:GetNamedChild("Primary"),
        [SCRIBING_SLOT_SECONDARY] = scribingRoot:GetNamedChild("Secondary"),
        [SCRIBING_SLOT_TERTIARY] = scribingRoot:GetNamedChild("Tertiary"),
    }
    scribingXmlGroup[SCRIBING_SLOT_NONE].slotType = SCRIBING_SLOT_NONE
    scribingXmlGroup[SCRIBING_SLOT_PRIMARY].slotType = SCRIBING_SLOT_PRIMARY
    scribingXmlGroup[SCRIBING_SLOT_SECONDARY].slotType = SCRIBING_SLOT_SECONDARY
    scribingXmlGroup[SCRIBING_SLOT_TERTIARY].slotType = SCRIBING_SLOT_TERTIARY

    scribingRoot:GetNamedChild("Sidebar"):GetNamedChild("History").index = SIDEBAR_INDEX_HISTORY
    scribingRoot:GetNamedChild("Sidebar"):GetNamedChild("Favorites").index = SIDEBAR_INDEX_FAVORITE

    if (scribingData[SCRIBING_SLOT_NONE] == nil) then
        SuperStar_RenderSlot(scribingXmlGroup[SCRIBING_SLOT_NONE])
    end
end

function SuperStar_PickHistory(control)
    if not control.picked then
        table.insert(pickedHistory, {
            [SCRIBING_SLOT_NONE] = control[SCRIBING_SLOT_NONE], 
            [SCRIBING_SLOT_PRIMARY] = control[SCRIBING_SLOT_PRIMARY], 
            [SCRIBING_SLOT_SECONDARY] = control[SCRIBING_SLOT_SECONDARY], 
            [SCRIBING_SLOT_TERTIARY] = control[SCRIBING_SLOT_TERTIARY]})        
        PlaySound("Recipe_Learned")
        control:GetNamedChild("Highlight"):SetAlpha(1)
        control.picked = true
    else
        -- Iterate from back to front to move the lastest and to remove safely
        for i = #pickedHistory, 1, -1 do
            if pickedHistory[i][SCRIBING_SLOT_NONE] == control[SCRIBING_SLOT_NONE] and 
            pickedHistory[i][SCRIBING_SLOT_PRIMARY] == control[SCRIBING_SLOT_PRIMARY] and
            pickedHistory[i][SCRIBING_SLOT_SECONDARY] == control[SCRIBING_SLOT_SECONDARY] and
            pickedHistory[i][SCRIBING_SLOT_TERTIARY] == control[SCRIBING_SLOT_TERTIARY]  then
                table.remove(pickedHistory, i)
                -- Even if there are duplicates, only remove current one and break. Duplication check will be done when confirming the queue
                break
            end
        end
        PlaySound("Recipe_Learned")
        control:GetNamedChild("Highlight"):SetAlpha(0.001)
        control.picked = false
    end

    if #pickedHistory > 0 then
        CALLBACK_MANAGER:FireCallbacks("SuperStarExistPickedHistory", true)
    else
        CALLBACK_MANAGER:FireCallbacks("SuperStarExistPickedHistory", false)
    end
end

local function HandleChatboxClick(link, button, text, linkStyle, linkType, dataString)
    if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
    if linkType == SUPERSTAR_PRINT_QUEUE then
        for i, v in ipairs(scribingQueue) do
            d("|cCC922F" .. GetCraftedAbilityDisplayName(v[SCRIBING_SLOT_NONE]) .. "|c215895 / " .. 
            GetCraftedAbilityScriptDisplayName(v[SCRIBING_SLOT_PRIMARY]) .. " / " .. 
            GetCraftedAbilityScriptDisplayName(v[SCRIBING_SLOT_SECONDARY]).. " / " .. 
            GetCraftedAbilityScriptDisplayName(v[SCRIBING_SLOT_TERTIARY]) .. "|r\n")
        end
        return true
    end
    if linkType == SUPERSTAR_SHARE then
        BuildMainSceneShare(dataString, text)
        -- Avoiding some situations where Unresgistering Update is delayed
        zo_callLater(function()BuildMainSceneShare(dataString, text) end, 10)
        return true
	end
end
LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_CLICKED_EVENT, HandleChatboxClick)
LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_MOUSE_UP_EVENT, HandleChatboxClick)


function SuperStar_PickFavorite(control)
    if not control.picked then
        table.insert(pickedFavorites, {
            [SCRIBING_SLOT_NONE] = control[SCRIBING_SLOT_NONE], 
            [SCRIBING_SLOT_PRIMARY] = control[SCRIBING_SLOT_PRIMARY], 
            [SCRIBING_SLOT_SECONDARY] = control[SCRIBING_SLOT_SECONDARY], 
            [SCRIBING_SLOT_TERTIARY] = control[SCRIBING_SLOT_TERTIARY]})        
        PlaySound("Recipe_Learned")
        control:GetNamedChild("Highlight"):SetAlpha(1)
        control.picked = true
    else
        for i = #pickedFavorites, 1, -1 do
            if pickedFavorites[i][SCRIBING_SLOT_NONE] == control[SCRIBING_SLOT_NONE] and 
            pickedFavorites[i][SCRIBING_SLOT_PRIMARY] == control[SCRIBING_SLOT_PRIMARY] and
            pickedFavorites[i][SCRIBING_SLOT_SECONDARY] == control[SCRIBING_SLOT_SECONDARY] and
            pickedFavorites[i][SCRIBING_SLOT_TERTIARY] == control[SCRIBING_SLOT_TERTIARY]  then
                table.remove(pickedFavorites, i)
                break
            end
        end
        PlaySound("Recipe_Learned")
        control:GetNamedChild("Highlight"):SetAlpha(0.001)
        control.picked = false
    end

    if #pickedFavorites > 0 then
        CALLBACK_MANAGER:FireCallbacks("SuperStarExistPickedFavorites", true)
    else
        CALLBACK_MANAGER:FireCallbacks("SuperStarExistPickedFavorites", false)
    end
end

function SuperStar_RenderSlot(control)
    if renderingSlot and renderingSlot == control.slotType then
        return
    end
    -- renderingSlot is used to record slot currently be rendered while ALL OTHERS ARE PICKED. If any other slot is not picked then renderingSlot should be nil
    -- If trying to open another slot while a slot is still open, prevent player from doing so.
    if control.slotType ~= SCRIBING_SLOT_NONE and renderingSlot ~= nil and scribingData[(renderingSlot) % 3 + 1] ~= nil and scribingData[(renderingSlot + 1) % 3 + 1] ~= nil then
        -- PlaySound(SOUNDS.ABILITY_NOT_ENOUGH_STAMINA)
        scribingXmlGroup[renderingSlot].anim = ANIMATION_MANAGER:CreateTimeline()
        scribingXmlGroup[renderingSlot]:SetAlpha(1)
        scribingXmlGroup[renderingSlot].anim.alpha = scribingXmlGroup[renderingSlot].anim:InsertAnimation( ANIMATION_SCALE, scribingXmlGroup[renderingSlot], 0 )
        scribingXmlGroup[renderingSlot].anim.alpha:SetDuration(300)
        scribingXmlGroup[renderingSlot].anim.alpha:SetEasingFunction(ZO_EaseOutQuintic)
        scribingXmlGroup[renderingSlot].anim.alpha:SetScaleValues(1, 1.1)
        scribingXmlGroup[renderingSlot].anim.alpha = scribingXmlGroup[renderingSlot].anim:InsertAnimation( ANIMATION_SCALE, scribingXmlGroup[renderingSlot], 500 )
        scribingXmlGroup[renderingSlot].anim.alpha:SetDuration(300)
        scribingXmlGroup[renderingSlot].anim.alpha:SetEasingFunction(ZO_EaseOutQuintic)
        scribingXmlGroup[renderingSlot].anim.alpha:SetScaleValues(1.1, 1)
        scribingXmlGroup[renderingSlot].anim.alpha = scribingXmlGroup[renderingSlot].anim:InsertAnimation( ANIMATION_ALPHA, scribingXmlGroup[renderingSlot], 0 )
        scribingXmlGroup[renderingSlot].anim.alpha:SetDuration(300)
        scribingXmlGroup[renderingSlot].anim.alpha:SetEasingFunction(ZO_EaseOutQuintic)
        scribingXmlGroup[renderingSlot].anim.alpha:SetAlphaValues(1, 0.7)
        scribingXmlGroup[renderingSlot].anim.alpha = scribingXmlGroup[renderingSlot].anim:InsertAnimation( ANIMATION_ALPHA, scribingXmlGroup[renderingSlot], 500 )
        scribingXmlGroup[renderingSlot].anim.alpha:SetDuration(300)
        scribingXmlGroup[renderingSlot].anim.alpha:SetEasingFunction(ZO_EaseOutQuintic)
        scribingXmlGroup[renderingSlot].anim.alpha:SetAlphaValues(0.7, 1)
        scribingXmlGroup[renderingSlot].anim:PlayFromStart()
        return
    end

    renderingSlot = control.slotType
    SuperStar_HideScribingResult()
    scribingData[control.slotType] = nil

    if control.slotType == SCRIBING_SLOT_NONE then
        scribingXmlGroup[control.slotType]:SetHidden(false)
        scribingXmlGroup[control.slotType]:GetNamedChild("Icon"):SetTexture("esoui/art/crafting/scribing_activescript_icon.dds")
        hideChildrenControls(scribingXmlGroup[control.slotType], 3)

        -- while choosing grimoire, other slots should be unavailable and wiped
        for i = 1, 3 do
            scribingData[i] = nil
            scribingXmlGroup[i]:GetNamedChild("Icon"):SetTexture("esoui/art/crafting/scribing_activescript_icon.dds")
            hideChildrenControls(scribingXmlGroup[i], 3)
            local CurrentAnchor = ZO_Anchor:New(TOPLEFT, scribingXmlGroup[i - 1], BOTTOMLEFT, 0, 0)
            CurrentAnchor:Set(scribingXmlGroup[i])
            scribingXmlGroup[i]:SetHidden(true)
        end

        local index = 0
        for skillType = 1, GetNumSkillTypes() do
            for skillLineIndex = 1, GetNumSkillLines(skillType) do
                for skillIndex = 1, GetNumSkillAbilities(skillType, skillLineIndex) do
                    if (IsCraftedAbilitySkill(skillType, skillLineIndex, skillIndex)) then
                        local skillLineName, _, _, _, _, _, _, _ = GetSkillLineInfo(skillType, skillLineIndex)
                        local CAbilityId = GetCraftedAbilitySkillCraftedAbilityId(skillType, skillLineIndex, skillIndex)
                        local displayName = GetCraftedAbilityDisplayName(CAbilityId)
    
                        local VIRTUALNAME = "SuperStarScribingGrimoireOptionFrame"
                        local windowName = VIRTUALNAME .. control.slotType .. index
                        local CurrentFrame = GetControl(windowName)
                        if not CurrentFrame then
                            -- CreateControlFromVirtual(controlName, parent, templateName)
                            CurrentFrame = CreateControlFromVirtual(windowName, scribingXmlGroup[control.slotType], VIRTUALNAME)
                        end
                        CurrentFrame:SetHidden(false)
    
                        CurrentFrame.scribingId = CAbilityId
                        CurrentFrame.icon = GetCraftedAbilityIcon(CAbilityId)
                        CurrentFrame.skillLineName = skillLineName
                        CurrentFrame.displayName = displayName
                        CurrentFrame.slotType = control.slotType
                        CurrentFrame:GetNamedChild("Icon"):SetTexture(GetCraftedAbilityIcon(CAbilityId))
                        CurrentFrame:GetNamedChild("MainText"):SetText(displayName)
                        CurrentFrame:GetNamedChild("SubText"):SetText(skillLineName)
                        local CurrentAnchor = ZO_Anchor:New(TOPLEFT, scribingXmlGroup[control.slotType], BOTTOMLEFT, 0, 0)
                        CurrentAnchor:Set(CurrentFrame)

                        CurrentFrame:SetHidden(false)
                        CurrentFrame:SetAlpha(0.001)
                        CurrentFrame.anim = ANIMATION_MANAGER:CreateTimeline()
                        CurrentFrame.anim.slide = CurrentFrame.anim:InsertAnimation( ANIMATION_TRANSLATE, CurrentFrame, index * 30 )
                        CurrentFrame.anim.slide:SetDuration(500)
                        CurrentFrame.anim.slide:SetEasingFunction(ZO_EaseOutQuintic)
                        CurrentFrame.anim.slide:SetTranslateDeltas((math.mod(index, 3)) * 200, math.floor(index / 3) * 75)
                        CurrentFrame.anim.alpha = CurrentFrame.anim:InsertAnimation( ANIMATION_ALPHA, CurrentFrame, index * 30 )
                        CurrentFrame.anim.alpha:SetDuration(500)
                        CurrentFrame.anim.alpha:SetEasingFunction(ZO_EaseOutQuintic)
                        CurrentFrame.anim.alpha:SetAlphaValues(CurrentFrame:GetAlpha(), 1)
                        CurrentFrame.anim:PlayFromStart()
                        index = index + 1
                    end
                end
            end
        end
    
        local SubAnchor = ZO_Anchor:New(TOPLEFT, scribingXmlGroup[control.slotType], BOTTOMLEFT, 0, 0)
        SubAnchor:SetOffsets(0, math.ceil(index / 3) * 75)
        SubAnchor:Set(scribingXmlGroup[control.slotType + 1])

    elseif control.slotType == SCRIBING_SLOT_PRIMARY or control.slotType == SCRIBING_SLOT_SECONDARY or control.slotType == SCRIBING_SLOT_TERTIARY then
        scribingXmlGroup[control.slotType]:SetHidden(false)
        scribingXmlGroup[control.slotType]:GetNamedChild("Icon"):SetTexture("esoui/art/crafting/scribing_activescript_icon.dds")
        hideChildrenControls(scribingXmlGroup[control.slotType], 3)
        if scribingData[(control.slotType) % 3 + 1] == nil then
            hideChildrenControls(scribingXmlGroup[(control.slotType) % 3 + 1], 3)
        end
        if scribingData[(control.slotType + 1) % 3 + 1] == nil then
            hideChildrenControls(scribingXmlGroup[(control.slotType + 1) % 3 + 1], 3)
        end
        local index = 0
        for i = 1, GetNumScriptsInSlotForCraftedAbility(scribingData[SCRIBING_SLOT_NONE], control.slotType) do
            local scriptId = GetScriptIdAtSlotIndexForCraftedAbility(scribingData[SCRIBING_SLOT_NONE], control.slotType, i)
            if IsCraftedAbilityScriptCompatibleWithSelections(scriptId, scribingData[SCRIBING_SLOT_NONE], scribingData[SCRIBING_SLOT_PRIMARY], scribingData[SCRIBING_SLOT_SECONDARY], scribingData[SCRIBING_SLOT_TERTIARY]) then
                local VIRTUALNAME = "SuperStarScribingScriptOptionFrame"
                local windowName = VIRTUALNAME .. control.slotType .. index
                local CurrentFrame = GetControl(windowName)
                if not CurrentFrame then
                    -- CreateControlFromVirtual(controlName, parent, templateName)
                    CurrentFrame = CreateControlFromVirtual(windowName, scribingXmlGroup[control.slotType], VIRTUALNAME)
                end
                CurrentFrame:SetHidden(false)

                CurrentFrame.scribingId = scriptId
                CurrentFrame.icon = GetCraftedAbilityScriptIcon(scriptId)
                CurrentFrame.displayName = GetCraftedAbilityScriptDisplayName(scriptId)
                CurrentFrame.slotType = control.slotType
                CurrentFrame:GetNamedChild("Icon"):SetTexture(GetCraftedAbilityScriptIcon(scriptId))
                CurrentFrame:GetNamedChild("MainText"):SetText(GetCraftedAbilityScriptDisplayName(scriptId))

                local CurrentAnchor = ZO_Anchor:New(TOPLEFT, scribingXmlGroup[control.slotType], BOTTOMLEFT, 0, 0)
                CurrentAnchor:Set(CurrentFrame)
                CurrentFrame:SetHidden(false)
                CurrentFrame:SetAlpha(0.001)
                CurrentFrame.anim = ANIMATION_MANAGER:CreateTimeline()
                CurrentFrame.anim.slide = CurrentFrame.anim:InsertAnimation( ANIMATION_TRANSLATE, CurrentFrame, index * 30 )
                CurrentFrame.anim.slide:SetDuration(500)
                CurrentFrame.anim.slide:SetEasingFunction(ZO_EaseOutQuintic)
                CurrentFrame.anim.slide:SetTranslateDeltas((math.mod(index, 3)) * 200, math.floor(index / 3) * 75)
                CurrentFrame.anim.alpha = CurrentFrame.anim:InsertAnimation( ANIMATION_ALPHA, CurrentFrame, index * 30 )
                CurrentFrame.anim.alpha:SetDuration(500)
                CurrentFrame.anim.alpha:SetEasingFunction(ZO_EaseOutQuintic)
                CurrentFrame.anim.alpha:SetAlphaValues(CurrentFrame:GetAlpha(), 1)
                CurrentFrame.anim:PlayFromStart()

                index = index + 1
            else
                -- if this one is incompatible do nothing, as continue
            end
        end

        for i = 0, 2 do
            local SubAnchor = ZO_Anchor:New(TOPLEFT, scribingXmlGroup[i], BOTTOMLEFT, 0, 0)
            if i == control.slotType then
                SubAnchor:SetOffsets(0, math.ceil(index / 3) * 75)
            else
                if scribingData[i] ~= nil then
                    SubAnchor:SetOffsets(0, 75)
                end                
            end
            SubAnchor:Set(scribingXmlGroup[i + 1])
        end
    else

    end
end

function SuperStar_PickSlot(control)
    -- save
    if control.scribingId ~= nil then
        renderingSlot = nil
        if control.slotType == SCRIBING_SLOT_NONE then
            PlaySound("Champion_RespecToggled")
        else
            PlaySound("Stable_FeedCarry")
        end
        scribingData[control.slotType] = control.scribingId
    else
        return
    end

    -- change title icon
    scribingXmlGroup[control.slotType]:GetNamedChild("Icon"):SetTexture("esoui/art/crafting/scribing_activescript_icon_hidden.dds")
    hideChildrenControls(scribingXmlGroup[control.slotType], 3)

    -- render chosen panel
    if control.slotType == SCRIBING_SLOT_NONE then
        local VIRTUALNAME = "SuperStarScribingGrimoireChosenFrame"
        -- Build up crafted ability info
        local windowName = VIRTUALNAME .. control.slotType
        local CurrentFrame = GetControl(windowName)
        if not CurrentFrame then
            -- CreateControlFromVirtual(controlName, parent, templateName)
            CurrentFrame = CreateControlFromVirtual(windowName, scribingXmlGroup[control.slotType], VIRTUALNAME)
        end
        CurrentFrame:SetHidden(false)

        CurrentFrame.scribingId = control.scribingId
        CurrentFrame.slotType = control.slotType
        CurrentFrame:GetNamedChild("Icon"):SetTexture(control.icon)
        CurrentFrame:GetNamedChild("MainText"):SetText(control.displayName)
        CurrentFrame:GetNamedChild("SubText"):SetText(control.skillLineName)

        local _, point, relTo, relPoint, offsX, offsY = control:GetAnchor(0)
        local CurrentAnchor = ZO_Anchor:New(TOPLEFT, scribingXmlGroup[control.slotType], BOTTOMLEFT, offsX, offsY)
        CurrentAnchor:Set(CurrentFrame)
        CurrentFrame.anim = ANIMATION_MANAGER:CreateTimeline()
        CurrentFrame.anim.slide = CurrentFrame.anim:InsertAnimation( ANIMATION_TRANSLATE, CurrentFrame, 0 )
        CurrentFrame.anim.slide:SetDuration(500)
        CurrentFrame.anim.slide:SetEasingFunction(ZO_EaseOutQuintic)
        CurrentFrame.anim.slide:SetTranslateDeltas(0 - offsX, 0 - offsY)
        CurrentFrame.anim:PlayFromStart()

        scribingXmlGroup[SCRIBING_SLOT_PRIMARY]:SetHidden(false)
        scribingXmlGroup[SCRIBING_SLOT_SECONDARY]:SetHidden(false)
        scribingXmlGroup[SCRIBING_SLOT_TERTIARY]:SetHidden(false)
    else
        local VIRTUALNAME = "SuperStarScribingScriptChosenFrame"
        local windowName = VIRTUALNAME .. control.slotType
        local CurrentFrame = GetControl(windowName)
        if not CurrentFrame then
            CurrentFrame = CreateControlFromVirtual(windowName, scribingXmlGroup[control.slotType], VIRTUALNAME)
        end
        CurrentFrame:SetHidden(false)

        CurrentFrame.scribingId = control.scribingId
        CurrentFrame.slotType = control.slotType
        CurrentFrame:GetNamedChild("Icon"):SetTexture(control.icon)
        CurrentFrame:GetNamedChild("MainText"):SetText(control.displayName)

        local _, point, relTo, relPoint, offsX, offsY = control:GetAnchor(0)
        local CurrentAnchor = ZO_Anchor:New(TOPLEFT, scribingXmlGroup[control.slotType], BOTTOMLEFT, offsX, offsY)
        CurrentAnchor:Set(CurrentFrame)
        CurrentFrame.anim = ANIMATION_MANAGER:CreateTimeline()
        CurrentFrame.anim.slide = CurrentFrame.anim:InsertAnimation( ANIMATION_TRANSLATE, CurrentFrame, 0 )
        CurrentFrame.anim.slide:SetDuration(500)
        CurrentFrame.anim.slide:SetEasingFunction(ZO_EaseOutQuintic)
        CurrentFrame.anim.slide:SetTranslateDeltas(0 - offsX, 0 - offsY)
        CurrentFrame.anim:PlayFromStart()
    end

    for i = 1, 3 do
        if scribingData[i] == nil then
            SuperStar_RenderSlot(scribingXmlGroup[i])
            break
        end

        -- if all slots are picked render the result
        if scribingData[SCRIBING_SLOT_NONE] ~= nil and scribingData[SCRIBING_SLOT_PRIMARY] ~= nil and scribingData[SCRIBING_SLOT_SECONDARY] ~= nil and scribingData[SCRIBING_SLOT_TERTIARY] ~= nil then
            PlaySound("Skill_Gained")
            SuperStar_ShowScribingResult(scribingData[SCRIBING_SLOT_NONE], scribingData[SCRIBING_SLOT_PRIMARY], scribingData[SCRIBING_SLOT_SECONDARY], scribingData[SCRIBING_SLOT_TERTIARY])
            if #db.historyScribed == 0 or 
            (not (db.historyScribed[#db.historyScribed][SCRIBING_SLOT_NONE] == scribingData[SCRIBING_SLOT_NONE]
            and db.historyScribed[#db.historyScribed][SCRIBING_SLOT_PRIMARY] == scribingData[SCRIBING_SLOT_PRIMARY]
            and  db.historyScribed[#db.historyScribed][SCRIBING_SLOT_SECONDARY] == scribingData[SCRIBING_SLOT_SECONDARY]
            and  db.historyScribed[#db.historyScribed][SCRIBING_SLOT_TERTIARY] == scribingData[SCRIBING_SLOT_TERTIARY])) then
                table.insert(db.historyScribed, 
                    {
                        [SCRIBING_SLOT_NONE] = scribingData[SCRIBING_SLOT_NONE], 
                        [SCRIBING_SLOT_PRIMARY] = scribingData[SCRIBING_SLOT_PRIMARY], 
                        [SCRIBING_SLOT_SECONDARY] = scribingData[SCRIBING_SLOT_SECONDARY], 
                        [SCRIBING_SLOT_TERTIARY] = scribingData[SCRIBING_SLOT_TERTIARY], 
                    })
            end
            while #db.historyScribed > SIDEBAR_SKILL_MAX do 
                table.remove(db.historyScribed, 1) -- FIFO
            end
            resetPicking(SIDEBAR_INDEX_HISTORY)

            for i = 0, 2 do
                local SubAnchor = ZO_Anchor:New(TOPLEFT, scribingXmlGroup[i], BOTTOMLEFT, 0, 0)
                SubAnchor:SetOffsets(0, 75)
                SubAnchor:Set(scribingXmlGroup[i + 1])
            end
        end
    end

    
end

-- Called by XML
function SuperStar_Companion_PassivePerk_OnMouseEnter(control)
    if control.passivePerkId then
        InitializeTooltip(AbilityTooltip, control, RIGHT, -5, 0, LEFT)
        AbilityTooltip:SetAbilityId(control.passivePerkId)
    end
end

function SuperStar_Companion_PassivePerk_OnMouseExit(control)
    ClearTooltip(AbilityTooltip)
end

function SuperStar_Companion_RapportLevel_OnMouseEnter(control)
    if control.rapportDesc then
        InitializeTooltip(InformationTooltip, control, RIGHT, -5, 0, LEFT)
        SetTooltipText(InformationTooltip, control.rapportDesc)
    end
end

function SuperStar_Companion_RapportLevel_OnMouseExit(control)
    ClearTooltip(InformationTooltip)
end

-- Blk: Dialogs ================================================================
local function InitializeDialogs()

    favoritesManager = favoritesList:New(SuperStarXMLFavorites)
    favoritesManager:RefreshData()
    CleanSortListForDB("favoritesList")

    ZO_Dialogs_RegisterCustomDialog("SUPERSTAR_SAVE_SKILL_FAV", {
        title = {
            text = SI_ARMORYBUILDOPERATIONTYPE1
        },
        mainText = {
            text = SI_INVENTORY_SORT_TYPE_NAME
        },
        editBox = {
            defaultText = ""
        },
        buttons = {{
            text = SI_DIALOG_CONFIRM,
            requiresTextInput = true,
            callback = function(dialog)
                local favName = ZO_Dialogs_GetEditBoxText(dialog)
                if favName and favName ~= "" then
                    ConfirmSaveFav(favName, dialog.data.hash)
                end
            end
        }, {
            text = SI_DIALOG_CANCEL,
            callback = function(dialog)
                return true
            end
        }}
    })

    ZO_Dialogs_RegisterCustomDialog("SUPERSTAR_SAVE_FAV", {
        title = {
            text = SUPERSTAR_SAVEFAV
        },
        mainText = {
            text = SUPERSTAR_FAVNAME
        },
        editBox = {
            defaultText = ""
        },
        buttons = {{
            text = SI_DIALOG_CONFIRM,
            requiresTextInput = true,
            callback = function(dialog)
                local favName = ZO_Dialogs_GetEditBoxText(dialog)
                if favName and favName ~= "" then
                    ConfirmSaveFav(favName, dialog.data.hash)
                end
            end
        }, {
            text = SI_DIALOG_CANCEL,
            callback = function(dialog)
                return true
            end
        }}
    })

    -- No longer used
    -- ZO_Dialogs_RegisterCustomDialog("SUPERSTAR_CONFIRM_SPRESPEC", {
    --     title = {
    --         text = SUPERSTAR_DIALOG_SPRESPEC_TITLE
    --     },
    --     mainText = {
    --         text = SUPERSTAR_DIALOG_SPRESPEC_TEXT
    --     },
    --     buttons = {{
    --         text = SI_DIALOG_CONFIRM,
    --         callback = RespecSkills
    --     }, {
    --         text = SI_DIALOG_CANCEL
    --     }}
    -- })


    ZO_Dialogs_RegisterCustomDialog("SUPERSTAR_MAJOR_UPDATE", {
        title = {
            text = "|c385f86S|r|c4a667bu|r|c5d6c70p|r|c6f7265e|r|c82795br|r|c947f50S|r|ca78545t|r|cb98c3aa|r|ccc922fr|r"
        },
        mainText = {
            text = zo_strformat(GetString(SUPERSTAR_DIALOG_MAJOR_UPDATE_TEXT), GetString(SI_GAMEPAD_SKILLS_CLASS_MASTERY_POINTS))
        },
        buttons = {{
            text = SI_GUILD_HISTORY_SHOW_MORE,
            callback = function()
                SCENE_MANAGER:Show("SuperStarMain")
                -- createShareLink()
            end
        }, {
            text = SI_DIALOG_CANCEL
        }}
    })

    ZO_Dialogs_RegisterCustomDialog("SUPERSTAR_SCRIBING_REJECTED", {
        title = {
            text = SUPERSTAR_DIALOG_QUEUE_REJECTED_TITLE
        },
        mainText = {
            text = SUPERSTAR_DIALOG_QUEUE_REJECTED_TEXT
        },
        buttons = {
            {text = SI_DIALOG_CANCEL}
        }
    })

    ZO_Dialogs_RegisterCustomDialog("SUPERSTAR_SCRIBING_QUEUE", {
        title = {
            text = SUPERSTAR_QUEUE_SCRIBING
        },
        mainText = {
            text = SUPERSTAR_DIALOG_QUEUE_FOR_SCRIBING_TEXT
        },
        buttons = {{
            text = SI_DIALOG_CONFIRM,
            callback = function(dialog)
                addPickedToQueue(dialog.data.index)
                resetPicking(dialog.data.index)
                local printLink = ZO_LinkHandler_CreateLinkWithoutBrackets(GetString(SUPERSTAR_CHATBOX_PRINT), nil, SUPERSTAR_PRINT_QUEUE)
                local ownedInk = select(1, GetItemLinkStacks(GetScribingInkItemLink(LINK_STYLE_DEFAULT))) + select(2, GetItemLinkStacks(GetScribingInkItemLink(LINK_STYLE_DEFAULT))) + select(3, GetItemLinkStacks(GetScribingInkItemLink(LINK_STYLE_DEFAULT)))
                if getInkConsumption(scribingQueue) <= ownedInk then
                    CHAT_ROUTER:AddSystemMessage(zo_strformat(SUPERSTAR_CHATBOX_QUEUE_INFO, #scribingQueue, getInkConsumption(scribingQueue), ownedInk) .. " " .. printLink)
                else
                    CHAT_ROUTER:AddSystemMessage(zo_strformat(SUPERSTAR_CHATBOX_QUEUE_WARN, #scribingQueue, getInkConsumption(scribingQueue), ownedInk) .. " " .. printLink)
                end
                EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CRAFTING_STATION_INTERACT, OnUsingCraftingStation)
            end
        }, {
            text = SI_DIALOG_CANCEL
        }}
    })
    ZO_Dialogs_RegisterCustomDialog("SUPERSTAR_SCRIBING_CLEAR", {
        title = {
            text = SUPERSTAR_CLEAR_QUEUE
        },
        mainText = {
            text = SUPERSTAR_DIALOG_CLEAR_QUEUE_TEXT
        },
        buttons = {{
            text = SI_DIALOG_CONFIRM,
            callback = function(dialog)
                scribingQueue = {}
                local ownedInk = select(1, GetItemLinkStacks(GetScribingInkItemLink(LINK_STYLE_DEFAULT))) + select(2, GetItemLinkStacks(GetScribingInkItemLink(LINK_STYLE_DEFAULT))) + select(3, GetItemLinkStacks(GetScribingInkItemLink(LINK_STYLE_DEFAULT)))
                CHAT_ROUTER:AddSystemMessage(zo_strformat(SUPERSTAR_CHATBOX_QUEUE_INFO, #scribingQueue, getInkConsumption(scribingQueue), ownedInk))
                if dialog.data.index == SIDEBAR_INDEX_HISTORY then
                    resetPicking(SIDEBAR_INDEX_FAVORITE)
                    resetPicking(SIDEBAR_INDEX_HISTORY)
                elseif dialog.data.index == SIDEBAR_INDEX_FAVORITE then
                    resetPicking(SIDEBAR_INDEX_HISTORY)
                    resetPicking(SIDEBAR_INDEX_FAVORITE)
                end
                EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_CRAFTING_STATION_INTERACT)
            end
        }, {
            text = SI_DIALOG_CANCEL
        }}
    })

    ZO_Dialogs_RegisterCustomDialog("SUPERSTAR_REINIT_SKILLBUILDER_WITH_ATTR_CP", {
        title = {
            text = SUPERSTAR_DIALOG_REINIT_SKB_ATTR_CP_TITLE
        },
        mainText = {
            text = SUPERSTAR_DIALOG_REINIT_SKB_ATTR_CP_TEXT
        },
        buttons = {{
            text = SI_DIALOG_CONFIRM,
            callback = function()
                SuperStarSkills.pendingCPDataForBuilder = nil
                SuperStarSkills.pendingAttrDataForBuilder = nil
                ResetSkillBuilder()
            end
        }, {
            text = SI_DIALOG_CANCEL
        }}
    })

    -- called when loading a new build and the current build has cp/attr set
    ZO_Dialogs_RegisterCustomDialog("SUPERSTAR_REINIT_SKILLBUILDER_WITH_ATTR_CP2", {
        title = {
            text = SUPERSTAR_DIALOG_REINIT_SKB_ATTR_CP_TITLE
        },
        mainText = {
            text = SUPERSTAR_DIALOG_REINIT_SKB_ATTR_CP_TEXT
        },
        buttons = {{
            text = SI_DIALOG_CONFIRM,
            callback = function()
                SuperStarSkills.pendingCPDataForBuilder = nil
                SuperStarSkills.pendingAttrDataForBuilder = nil
                -- ResetSkillBuilder()
                ResetSkillBuilderAndLoadBuild()
            end
        }, {
            text = SI_DIALOG_CANCEL
        }}
    })

    local customControl = ZO_ChampionRespecConfirmationDialog
    ZO_Dialogs_RegisterCustomDialog("SUPERSTAR_CONFIRM_CPRESPEC_COST", {
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.BASIC
        },
        customControl = customControl,
        title = {
            text = SI_CHAMPION_DIALOG_CONFIRM_CHANGES_TITLE
        },
        mainText = {
            text = zo_strformat(SI_CHAMPION_DIALOG_TEXT_FORMAT, GetString(SI_CHAMPION_DIALOG_CONFIRM_POINT_COST))
        },
        setup = function()
            ZO_CurrencyControl_SetSimpleCurrency(customControl:GetNamedChild("BalanceAmount"), CURT_MONEY,
                GetCarriedCurrencyAmount(CURT_MONEY))
            ZO_CurrencyControl_SetSimpleCurrency(customControl:GetNamedChild("RespecCost"), CURT_MONEY,
                GetChampionRespecCost())
        end,
        buttons = {{
            control = customControl:GetNamedChild("Confirm"),
            text = SI_DIALOG_CONFIRM,
            callback = function()
                FinalizeCPRespec(true)
            end
        }, {
            control = customControl:GetNamedChild("Cancel"),
            text = SI_DIALOG_CANCEL,
            callback = function()
                FinalizeCPRespec(false)
            end
        }}
    })

    ZO_Dialogs_RegisterCustomDialog("SUPERSTAR_CONFIRM_CPRESPEC_NOCOST", {
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.BASIC
        },
        title = {
            text = SI_CHAMPION_DIALOG_CONFIRM_CHANGES_TITLE
        },
        mainText = {
            text = SUPERSTAR_DIALOG_CPRESPEC_NOCOST_TEXT
        },
        buttons = {{
            text = SI_DIALOG_CONFIRM,
            callback = function()
                FinalizeCPRespec(true)
            end
        }, {
            text = SI_DIALOG_CANCEL,
            callback = function()
                FinalizeCPRespec(false)
            end
        }}
    })

end
-- Blk: Scene management =======================================================
local function CreateScenes()

    -- Build the Menu
    -- Its name for the menu (the meta scene)
    ZO_CreateStringId("SI_SUPERSTAR_CATEGORY_MENU_TITLE", ADDON_NAME)

    -- Its infos
    local SUPERSTAR_MAIN_MENU_CATEGORY_DATA = {
        binding = "SUPERSTAR_SHOW_PANEL",
        categoryName = SI_SUPERSTAR_CATEGORY_MENU_TITLE,
        normal = "esoui/art/journal/journal_tabicon_achievements_up.dds",
        pressed = "esoui/art/journal/journal_tabicon_achievements_down.dds",
        highlight = "esoui/art/journal/journal_tabicon_achievements_over.dds",
        callback = function()
            LMM:ToggleCategory(MENU_CATEGORY_SUPERSTAR)
        end,
    }

    -- Then the scenes

    -- Main Scene
    local SUPERSTAR_MAIN_SCENE = ZO_Scene:New("SuperStarMain", SCENE_MANAGER)

    -- Mouse standard position and background
    SUPERSTAR_MAIN_SCENE:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    SUPERSTAR_MAIN_SCENE:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_STANDARD_RIGHT_PANEL)

    --  Background Right, it will set ZO_RightPanelFootPrint and its stuff.
    SUPERSTAR_MAIN_SCENE:AddFragment(RIGHT_BG_FRAGMENT)

    -- The title fragment
    SUPERSTAR_MAIN_SCENE:AddFragment(TITLE_FRAGMENT)

    -- Set Title
    ZO_CreateStringId("SUPERSTAR_MAIN_MENU_TITLE", GetUnitName("player"))
    local SUPERSTAR_MAIN_TITLE_FRAGMENT = ZO_SetTitleFragment:New(SI_SUPERSTAR_CATEGORY_MENU_TITLE)
    SUPERSTAR_MAIN_SCENE:AddFragment(SUPERSTAR_MAIN_TITLE_FRAGMENT)

    -- Add the XML to our scene
    local SUPERSTAR_MAIN_WINDOW = ZO_HUDFadeSceneFragment:New(SuperStarXMLMain, DEFAULT_SCENE_TRANSITION_TIME, 0)
    SUPERSTAR_MAIN_SCENE:AddFragment(SUPERSTAR_MAIN_WINDOW)

    summaryKeybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_CENTER,
        {
            name = GetString(SUPERSTAR_XML_BUTTON_SHARE),
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = insertShareLink,
            -- visible = function()
            --     if LibChatMessage then
            --         return true
            --     else
            --         return false
            --     end
            -- end
        },
        {
            name = GetString(SUPERSTAR_XML_BUTTON_SHARE_LINK),
            keybind = "UI_SHORTCUT_SECONDARY",
            callback = createIngameShareLink,
        },
        {
            name = GetString(SI_GAMEPAD_TOGGLE_OPTION) .. " " .. GetString(SI_MAIN_MENU_CHARACTER) .. "/" .. GetString(SI_COMPANION_MENU_ROOT_TITLE),
            keybind = "UI_SHORTCUT_QUATERNARY",
            callback = ToggleCharacterCompanion,
            visible = function()
                return HasActiveCompanion()
            end
        },
    }

    SUPERSTAR_MAIN_SCENE:RegisterCallback("StateChange", function(oldState, newState)
        if (newState == SCENE_SHOWING) then
            KEYBIND_STRIP:AddKeybindButtonGroup(summaryKeybindStripDescriptor)
            showingCharInMain = true
            SuperStarXMLMainCompanion:SetHidden(true)
            SuperStarXMLMainCharacter:SetHidden(false)
            BuildMainSceneLocal(SuperStarXMLMainCharacter)
            EVENT_MANAGER:RegisterForUpdate(ADDON_NAME, 1000, function()
                BuildMainScene()
            end)
        elseif (newState == SCENE_HIDDEN) then
            GetControl("LMMXMLSceneGroupBarLabel"):SetText(GetUnitName("player"))
            KEYBIND_STRIP:RemoveKeybindButtonGroup(summaryKeybindStripDescriptor)
            EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME)
        end
    end)

    -- Skill Simulator Scene
    SUPERSTAR_SKILLS_SCENE = ZO_Scene:New("SuperStarSkills", SCENE_MANAGER)

    -- Mouse standard position and background
    SUPERSTAR_SKILLS_SCENE:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    SUPERSTAR_SKILLS_SCENE:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_STANDARD_RIGHT_PANEL)

    -- Background Right, it will set ZO_RightPanelFootPrint and its stuff.
    SUPERSTAR_SKILLS_SCENE:AddFragment(RIGHT_BG_FRAGMENT)

    -- The title fragment
    SUPERSTAR_SKILLS_SCENE:AddFragment(TITLE_FRAGMENT)

    SUPERSTAR_SKILLS_SCENE:AddFragment(TREE_UNDERLAY_FRAGMENT)
    SUPERSTAR_SKILLS_SCENE:AddFragment(FRAME_EMOTE_FRAGMENT_SKILLS)
    SUPERSTAR_SKILLS_SCENE:AddFragment(SKILLS_WINDOW_SOUNDS)

    -- Set Title
    ZO_CreateStringId("SUPERSTAR_BUILD_MENU_TITLE", ZO_CachedStrFormat(SI_ARMORY_BUILD_DEFAULT_NAME_FORMATTER, nil))
    local SUPERSTAR_SKILLS_TITLE_FRAGMENT = ZO_SetTitleFragment:New(SI_SUPERSTAR_CATEGORY_MENU_TITLE)
    SUPERSTAR_SKILLS_SCENE:AddFragment(SUPERSTAR_SKILLS_TITLE_FRAGMENT)

    -- Add the XML to our scene
    SUPERSTAR_SKILLS_PRESELECTORWINDOW = ZO_HUDFadeSceneFragment:New(SuperStarXMLSkillsPreSelector, DEFAULT_SCENE_TRANSITION_TIME, 0)
    SUPERSTAR_SKILLS_BUILDERWINDOW = ZO_HUDFadeSceneFragment:New(SuperStarXMLSkills, DEFAULT_SCENE_TRANSITION_TIME, 0)

    local skillBuilderKeybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_CENTER,
        {
            name = GetString(SI_ARMORYBUILDOPERATIONTYPE1),
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = AddFavoriteFromSkillBuilder
        },
        {
            name = GetString(SUPERSTAR_XML_BUTTON_FAV_WITH_CP),
            keybind = "UI_SHORTCUT_TERTIARY",
            callback = AddFavoriteWithCPFromSkillBuilder
        },
        {
            name = GetString(SUPERSTAR_XML_BUTTON_REINIT),
            keybind = "UI_SHORTCUT_SECONDARY",
            callback = ResetSkillBuilder
        }
    }

    SUPERSTAR_SKILLS_BUILDERWINDOW:RegisterCallback("StateChange", function(oldState, newState)
        if (newState == SCENE_SHOWING) then
            KEYBIND_STRIP:AddKeybindButtonGroup(skillBuilderKeybindStripDescriptor)
        elseif (newState == SCENE_HIDDEN) then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(skillBuilderKeybindStripDescriptor)
            ResetSkillBuilder()
        end
    end)

    SUPERSTAR_SKILLS_SCENE:AddFragment(SUPERSTAR_SKILLS_PRESELECTORWINDOW)

    -- -- Import Scene
    -- local SUPERSTAR_IMPORT_SCENE = ZO_Scene:New("SuperStarImport", SCENE_MANAGER)

    -- -- Mouse standard position and background
    -- SUPERSTAR_IMPORT_SCENE:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    -- SUPERSTAR_IMPORT_SCENE:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_STANDARD_RIGHT_PANEL)

    -- --  Background Right, it will set ZO_RightPanelFootPrint and its stuff.
    -- SUPERSTAR_IMPORT_SCENE:AddFragment(RIGHT_BG_FRAGMENT)

    -- -- The title fragment
    -- SUPERSTAR_IMPORT_SCENE:AddFragment(TITLE_FRAGMENT)

    -- -- Tree background
    -- SUPERSTAR_IMPORT_SCENE:AddFragment(TREE_UNDERLAY_FRAGMENT)

    -- -- Set Title
    -- local SUPERSTAR_IMPORT_TITLE_FRAGMENT = ZO_SetTitleFragment:New(SI_SUPERSTAR_CATEGORY_MENU_TITLE)
    -- SUPERSTAR_IMPORT_SCENE:AddFragment(SUPERSTAR_IMPORT_TITLE_FRAGMENT)

    -- -- Add the XML to our scene
    -- SUPERSTAR_IMPORT_WINDOW = ZO_HUDFadeSceneFragment:New(SuperStarXMLImport, DEFAULT_SCENE_TRANSITION_TIME ,0)
    -- SUPERSTAR_IMPORT_SCENE:AddFragment(SUPERSTAR_IMPORT_WINDOW)

    -- SUPERSTAR_IMPORT_WINDOW.importKeybindStripDescriptor = {
    --     alignment = KEYBIND_STRIP_ALIGN_CENTER,
    --     {
    --         name = GetString(SUPERSTAR_XML_BUTTON_FAV),
    --         keybind = "UI_SHORTCUT_PRIMARY",
    --         callback = AddFavoriteFromImport,
    --         visible = function()
    --             return isImportedBuildValid
    --         end
    --     }
    -- }

    -- SUPERSTAR_IMPORT_SCENE:RegisterCallback("StateChange", function(oldState, newState)
    --     if (newState == SCENE_SHOWING) then
    --         RefreshImport(xmlInclChampionSkills, xmlIncludeSkills, xmlIncludeAttributes)
    --         KEYBIND_STRIP:AddKeybindButtonGroup(SUPERSTAR_IMPORT_WINDOW.importKeybindStripDescriptor)
    --     elseif (newState == SCENE_HIDDEN) then
    --         KEYBIND_STRIP:RemoveKeybindButtonGroup(SUPERSTAR_IMPORT_WINDOW.importKeybindStripDescriptor)
    --     end
    -- end)

    -- Favorites Scene
    local SUPERSTAR_FAVORITES_SCENE = ZO_Scene:New("SuperStarFavorites", SCENE_MANAGER)

    -- Mouse standard position and background
    SUPERSTAR_FAVORITES_SCENE:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    SUPERSTAR_FAVORITES_SCENE:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_STANDARD_RIGHT_PANEL)

    --  Background Right, it will set ZO_RightPanelFootPrint and its stuff.
    SUPERSTAR_FAVORITES_SCENE:AddFragment(RIGHT_BG_FRAGMENT)

    -- The title fragment
    SUPERSTAR_FAVORITES_SCENE:AddFragment(TITLE_FRAGMENT)

    -- Tree background
    SUPERSTAR_FAVORITES_SCENE:AddFragment(TREE_UNDERLAY_FRAGMENT)

    -- Set Title
    local SUPERSTAR_FAVORITES_TITLE_FRAGMENT = ZO_SetTitleFragment:New(SI_SUPERSTAR_CATEGORY_MENU_TITLE)
    SUPERSTAR_FAVORITES_SCENE:AddFragment(SUPERSTAR_FAVORITES_TITLE_FRAGMENT)

    -- Add the XML to our scene
    SUPERSTAR_FAVORITES_WINDOW = ZO_HUDFadeSceneFragment:New(SuperStarXMLFavorites, DEFAULT_SCENE_TRANSITION_TIME, 0)
    SUPERSTAR_FAVORITES_SCENE:AddFragment(SUPERSTAR_FAVORITES_WINDOW)

    SUPERSTAR_FAVORITES_WINDOW.favoritesKeybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_CENTER,
        {
            name = GetString(SUPERSTAR_VIEWFAV),
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = ViewFavorite,
            visible = function()
                return isFavoriteShown and isFavoriteHaveSP
            end
        },
        {
            name = GetString(SUPERSTAR_RESPECFAV_SP),
            keybind = "UI_SHORTCUT_SECONDARY",
            callback = RespecFavoriteSP,
            visible = function()
                return isFavoriteShown and isFavoriteHaveSP
            end
        },
        {
            name = GetString(SUPERSTAR_RESPECFAV_CP),
            keybind = "UI_SHORTCUT_TERTIARY",
            callback = RespecFavoriteCP,
            visible = function()
                return isFavoriteShown and isFavoriteHaveCP
            end
        },
        -- {
        --     name = GetString(SUPERSTAR_VIEWHASH),
        --     keybind = "UI_SHORTCUT_QUATERNARY",
        --     callback = ViewFavoriteHash,
        --     visible = function()
        --         return isFavoriteShown and isFavoriteValid
        --     end
        -- },
        {
            name = GetString(SUPERSTAR_REMFAV),
            keybind = "UI_SHORTCUT_NEGATIVE",
            callback = RemoveFavorite,
            visible = function()
                return isFavoriteShown and not isFavoriteLocked
            end
        },
        -- try to convert oudated hashes to the current format
        -- {
        --     name = GetString(SUPERSTAR_UPDATEHASH),
        --     keybind = "UI_SHORTCUT_QUICK_SLOTS",
        --     callback = UpdateFavoriteHash,
        --     visible = function()
        --         return isFavoriteShown and not isFavoriteValid and isFavoriteOutdated
        --     end
        -- }
    }

    SUPERSTAR_FAVORITES_WINDOW:RegisterCallback("StateChange", function(oldState, newState)
        if (newState == SCENE_SHOWING) then
            KEYBIND_STRIP:AddKeybindButtonGroup(SUPERSTAR_FAVORITES_WINDOW.favoritesKeybindStripDescriptor)
        elseif (newState == SCENE_HIDDEN) then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(SUPERSTAR_FAVORITES_WINDOW.favoritesKeybindStripDescriptor)
            SuperStar_DoBack()
        end
    end)

    -- -- Respec Scene
    -- local SUPERSTAR_RESPEC_SCENE = ZO_Scene:New("SuperStarRespec", SCENE_MANAGER)

    -- -- Mouse standard position and background
    -- SUPERSTAR_RESPEC_SCENE:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    -- SUPERSTAR_RESPEC_SCENE:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_STANDARD_RIGHT_PANEL)

    -- --  Background Right, it will set ZO_RightPanelFootPrint and its stuff.
    -- SUPERSTAR_RESPEC_SCENE:AddFragment(RIGHT_BG_FRAGMENT)

    -- -- The title fragment
    -- SUPERSTAR_RESPEC_SCENE:AddFragment(TITLE_FRAGMENT)

    -- -- Tree background
    -- -- SUPERSTAR_RESPEC_SCENE:AddFragment(TREE_UNDERLAY_FRAGMENT)

    -- -- Set Title
    -- local SUPERSTAR_RESPEC_TITLE_FRAGMENT = ZO_SetTitleFragment:New(SI_SUPERSTAR_CATEGORY_MENU_TITLE)
    -- SUPERSTAR_RESPEC_SCENE:AddFragment(SUPERSTAR_RESPEC_TITLE_FRAGMENT)

    -- -- Add the XML to our scene
    -- local SUPERSTAR_RESPEC_WINDOW = ZO_HUDFadeSceneFragment:New(SuperStarXMLFavoritesRespec, DEFAULT_SCENE_TRANSITION_TIME, 0)
    -- SUPERSTAR_RESPEC_SCENE:AddFragment(SUPERSTAR_RESPEC_WINDOW)

    
    -- Scribing Scene =========
    local SUPERSTAR_SCRIBING_SCENE = ZO_Scene:New("SuperStarScribing", SCENE_MANAGER)

    -- Mouse standard position and background
    SUPERSTAR_SCRIBING_SCENE:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    SUPERSTAR_SCRIBING_SCENE:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_STANDARD_RIGHT_PANEL)

    --  Background Right, it will set ZO_RightPanelFootPrint and its stuff.
    SUPERSTAR_SCRIBING_SCENE:AddFragment(RIGHT_BG_FRAGMENT)

    -- The title fragment
    SUPERSTAR_SCRIBING_SCENE:AddFragment(TITLE_FRAGMENT)

    -- Tree background
    SUPERSTAR_SCRIBING_SCENE:AddFragment(TREE_UNDERLAY_FRAGMENT)

    -- Set Title
    -- ZO_CreateStringId("SUPERSTAR_SCRIBING_MENU_TITLE", GetString(SI_TRADESKILLTYPE8))
    local SUPERSTAR_COMPANION_TITLE_FRAGMENT = ZO_SetTitleFragment:New(SI_SUPERSTAR_CATEGORY_MENU_TITLE)
    SUPERSTAR_SCRIBING_SCENE:AddFragment(SUPERSTAR_COMPANION_TITLE_FRAGMENT)

    -- Add the XML to our scene
    local SUPERSTAR_SCRIBING_WINDOW = ZO_HUDFadeSceneFragment:New(SuperStarXMLScribing, DEFAULT_SCENE_TRANSITION_TIME, 0)
    -- local SUPERSTAR_SCRIBING_WINDOW_BLANK = ZO_HUDFadeSceneFragment:New(SuperStarXMLScribingBlank, DEFAULT_SCENE_TRANSITION_TIME, 0)
    SUPERSTAR_SCRIBING_SCENE:AddFragment(SUPERSTAR_SCRIBING_WINDOW)

    InitCraftedAbilityDict()

    local historyKeybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_CENTER,
        {
            name = GetString(SUPERSTAR_QUEUE_SCRIBING),
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function()
                if isQueueable(SIDEBAR_INDEX_HISTORY) then
                    ZO_Dialogs_ShowDialog("SUPERSTAR_SCRIBING_QUEUE", {
                        index = SIDEBAR_INDEX_HISTORY
                    }, {
                        mainTextParams = {functionName}
                    })
                else
                    ZO_Dialogs_ShowDialog("SUPERSTAR_SCRIBING_REJECTED", {
                    }, {
                        mainTextParams = {functionName}
                    })
                end
            end,
        },
        {
            name = GetString(SI_COLLECTIBLE_ACTION_ADD_FAVORITE),
            keybind = "UI_SHORTCUT_TERTIARY",
            callback = AddScribingSkillToFav
        },
        {
            name = GetString(SUPERSTAR_CLEAR_QUEUE),
            keybind = "UI_SHORTCUT_SECONDARY",
            callback = function()
                ClearQueue(SIDEBAR_INDEX_HISTORY)
            end,
        }
    }

    local favoriteKeybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_CENTER,
        {
            name = GetString(SUPERSTAR_QUEUE_SCRIBING),
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function()
                if isQueueable(SIDEBAR_INDEX_FAVORITE) then
                    ZO_Dialogs_ShowDialog("SUPERSTAR_SCRIBING_QUEUE", {
                        index = SIDEBAR_INDEX_FAVORITE
                    }, {
                        mainTextParams = {functionName}
                    })
                else
                    ZO_Dialogs_ShowDialog("SUPERSTAR_SCRIBING_REJECTED", {
                    }, {
                        mainTextParams = {functionName}
                    })
                end
            end,
        },
        {
            name = GetString(SI_COLLECTIBLE_ACTION_REMOVE_FAVORITE),
            keybind = "UI_SHORTCUT_TERTIARY",
            callback = RemoveScribingSkillFromFav
        },
        {
            name = GetString(SUPERSTAR_CLEAR_QUEUE),
            keybind = "UI_SHORTCUT_SECONDARY",
            callback = function()
                ClearQueue(SIDEBAR_INDEX_FAVORITE)
            end,
        }
    }

    local linkInChatKeybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = GetString(SI_ITEM_ACTION_LINK_TO_CHAT),
            keybind = "UI_SHORTCUT_QUATERNARY",
            callback = function()
                local msg = "|H1:crafted_ability:" .. scribingData[SCRIBING_SLOT_NONE] .. ":" .. scribingData[SCRIBING_SLOT_PRIMARY] .. ":" .. scribingData[SCRIBING_SLOT_SECONDARY] .. ":" .. scribingData[SCRIBING_SLOT_TERTIARY] .. "|h|h"
                CHAT_SYSTEM.textEntry:SetText( msg )
                CHAT_SYSTEM:Maximize()
                CHAT_SYSTEM.textEntry:Open()
                CHAT_SYSTEM.textEntry:FadeIn()
            end,
        },
        {
            name = GetString(SI_ITEM_ACTION_LINK_TO_CHAT) .. " (" .. GetString(SI_WORLD_MAP_FILTERS_SHOW_DETAILS) ..  ")",
            keybind = "UI_SHORTCUT_QUINARY",
            callback = function()
                local msg = "|H1:crafted_ability:" .. scribingData[SCRIBING_SLOT_NONE] .. ":" .. scribingData[SCRIBING_SLOT_PRIMARY] .. ":" .. scribingData[SCRIBING_SLOT_SECONDARY] .. ":" .. scribingData[SCRIBING_SLOT_TERTIARY] .. "|h|h "
                .. GetCraftedAbilityScriptDisplayName(scribingData[SCRIBING_SLOT_PRIMARY]) .. " / " .. GetCraftedAbilityScriptDisplayName(scribingData[SCRIBING_SLOT_SECONDARY]) .. " / " .. GetCraftedAbilityScriptDisplayName(scribingData[SCRIBING_SLOT_TERTIARY])
                CHAT_SYSTEM.textEntry:SetText( msg )
                CHAT_SYSTEM:Maximize()
                CHAT_SYSTEM.textEntry:Open()
                CHAT_SYSTEM.textEntry:FadeIn()
            end,
        }
    }

    local function OnPickedHistoryExistenceChange(show)
        if show then
            KEYBIND_STRIP:AddKeybindButtonGroup(historyKeybindStripDescriptor)
        else
            KEYBIND_STRIP:RemoveKeybindButtonGroup(historyKeybindStripDescriptor)
        end
    end

    local function OnPickedFavoritesExistenceChange(show)
        if show then
            KEYBIND_STRIP:AddKeybindButtonGroup(favoriteKeybindStripDescriptor)
        else
            KEYBIND_STRIP:RemoveKeybindButtonGroup(favoriteKeybindStripDescriptor)
        end
    end

    local function OnScribingResultExistenceChange(show)
        if show then
            if not KEYBIND_STRIP:HasKeybindButtonGroup(linkInChatKeybindStripDescriptor) then
                KEYBIND_STRIP:AddKeybindButtonGroup(linkInChatKeybindStripDescriptor)
            end
        else
            KEYBIND_STRIP:RemoveKeybindButtonGroup(linkInChatKeybindStripDescriptor)
        end
    end

    CALLBACK_MANAGER:RegisterCallback("SuperStarExistPickedHistory", OnPickedHistoryExistenceChange)
    CALLBACK_MANAGER:RegisterCallback("SuperStarExistPickedFavorites", OnPickedFavoritesExistenceChange)
    CALLBACK_MANAGER:RegisterCallback("SuperStarExistScribingResult", OnScribingResultExistenceChange)

    SUPERSTAR_SCRIBING_SCENE:RegisterCallback("StateChange", function(oldState, newState)
        if (newState == SCENE_SHOWING) then
            SUPERSTAR_SCRIBING_SCENE:AddFragment(SUPERSTAR_SCRIBING_WINDOW)
            InitScribingScene()
            if scribingData[SCRIBING_SLOT_NONE] ~= nil and scribingData[SCRIBING_SLOT_PRIMARY] ~= nil and scribingData[SCRIBING_SLOT_SECONDARY] ~= nil and scribingData[SCRIBING_SLOT_TERTIARY] ~= nil then
                SuperStar_ShowScribingResult(scribingData[SCRIBING_SLOT_NONE], scribingData[SCRIBING_SLOT_PRIMARY], scribingData[SCRIBING_SLOT_SECONDARY], scribingData[SCRIBING_SLOT_TERTIARY])
            end
        elseif (newState == SCENE_HIDDEN) then
            if GetControl("SuperStarXMLScribingSidebarHistory"):IsMouseEnabled() == true then
                CACHED_SIDEBAR_INDEX = SIDEBAR_INDEX_FAVORITE
            else
                CACHED_SIDEBAR_INDEX = SIDEBAR_INDEX_HISTORY
            end
            SuperStar_HideScribingResult()
        end
    end)

    -- To build a window with multiple scene, we need to use a ZO_SceneGroup
    -- Set tabs and visibility, etc

    do
        local iconData = {{
            categoryName = SUPERSTAR_MAIN_MENU_TITLE,
            descriptor = "SuperStarMain",
            normal = "esoui/art/journal/journal_tabicon_achievements_up.dds",
            pressed = "esoui/art/journal/journal_tabicon_achievements_down.dds",
            highlight = "esoui/art/journal/journal_tabicon_achievements_over.dds",
        }, {
            categoryName = SUPERSTAR_XML_SKILL_BUILD,
            descriptor = "SuperStarSkills",
            normal = "EsoUI/Art/MainMenu/menuBar_skills_up.dds",
            pressed = "EsoUI/Art/MainMenu/menuBar_skills_down.dds",
            highlight = "EsoUI/Art/MainMenu/menuBar_skills_over.dds"
        -- }, {
        --     categoryName = SUPERSTAR_IMPORT_MENU_TITLE,
        --     descriptor = "SuperStarImport",
        --     normal = "esoui/art/guild/tabicon_roster_up.dds",
        --     pressed = "esoui/art/guild/tabicon_roster_down.dds",
        --     highlight = "esoui/art/guild/tabicon_roster_over.dds"
        }, {
            categoryName = SI_GAMEPAD_OPTIONS_TEMPLATES,
            descriptor = "SuperStarFavorites",
            normal = "EsoUI/Art/Collections/collections_tabIcon_DLC_up.dds",
            pressed = "EsoUI/Art/Collections/collections_tabIcon_DLC_down.dds",
            highlight = "EsoUI/Art/Collections/collections_tabIcon_DLC_over.dds"
        -- }, {
        --     categoryName = SUPERSTAR_RESPEC_MENU_TITLE,
        --     descriptor = "SuperStarRespec",
        --     normal = "EsoUI/Art/Guild/tabicon_history_up.dds",
        --     pressed = "EsoUI/Art/Guild/tabicon_history_down.dds",
        --     highlight = "EsoUI/Art/Guild/tabicon_history_over.dds"
        -- }, {
        --     categoryName = SUPERSTAR_COMPANION_MENU_TITLE,
        --     descriptor = "SuperStarCompanion",
        --     normal = "esoui/art/dye/dyes_tabicon_companion_up.dds",
        --     pressed = "esoui/art/dye/dyes_tabicon_companion_down.dds",
        --     highlight = "esoui/art/dye/dyes_tabicon_companion_over.dds"
        }, 
        {
            categoryName = SUPERSTAR_SCRIBING_MENU_TITLE,
            descriptor = "SuperStarScribing",
            normal = "esoui/art/crafting/scribing_tabicon_scribing_up.dds",
            pressed = "esoui/art/crafting/scribing_tabicon_scribing_down.dds",
            highlight = "esoui/art/crafting/scribing_tabicon_scribing_over.dds"
        }
    }

        -- Register Scenes and the group name
        SCENE_MANAGER:AddSceneGroup("SuperStarSceneGroup",
            ZO_SceneGroup:New(
            "SuperStarMain", 
            "SuperStarSkills", 
            -- "SuperStarImport", 
            "SuperStarFavorites", 
            -- "SuperStarRespec", 
            -- "SuperStarCompanion", 
            "SuperStarScribing"))
        MENU_CATEGORY_SUPERSTAR = LMM:AddCategory(SUPERSTAR_MAIN_MENU_CATEGORY_DATA)

        -- Register the group and add the buttons (we cannot all AddRawScene, only AddSceneGroup, so we emulate both functions).
        LMM:AddSceneGroup(MENU_CATEGORY_SUPERSTAR, "SuperStarSceneGroup", iconData)
        LMM:AddMenuItem("SuperStarSceneGroup", SUPERSTAR_MAIN_MENU_CATEGORY_DATA)
    end

end

function SuperStar_HandleSlashCommand(command)
    if command == "share" then
        insertShareLink()
    elseif command == "link" then
        createIngameShareLink()
    else
        LMM:ToggleCategory(MENU_CATEGORY_SUPERSTAR)
    end
end

-- Called by Bindings and Slash Command
function SuperStar_ToggleSuperStarPanel()
    LMM:ToggleCategory(MENU_CATEGORY_SUPERSTAR)
end

local function InitTests()
    SLASH_COMMANDS["/test1superstar"] = function()
        local hash = BuildLegitSkillHash();
        local skillsData = ParseSkillsHash(hash);
        RespecSkillPoints(skillsData)
    end
    SLASH_COMMANDS["/test2superstar"] = function()
        d(Base62(-150))
    end
    SLASH_COMMANDS["/test3superstar"] = function()

    end
end

-- local function PtsAndLiveConvert() -- to load 100034 settings while testing on 100035
--     if GetAPIVersion() == 100034 then
--         MODE_CP = "1"
--     end
-- end

local function InitMajorUpdateCheck()
    if db.latestMajorUpdateVersion ~= "8.0.0" then
        db.latestMajorUpdateVersion = "8.0.0"
        db.favoritesList = {}
        EVENT_MANAGER:RegisterForUpdate( ADDON_NAME, 1000, function()
            if not ZO_Dialogs_IsShowingDialog() then
                ZO_Dialogs_ShowDialog("SUPERSTAR_MAJOR_UPDATE", {
                }, {
                    mainTextParams = {functionName}
                })
                EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME)
            end
        end )
    end

    
    local currentDate = os.date("*t")
    if currentDate.month == 4 and currentDate.day == 1 then
        local impressiveTitle = {}
        local postFix = GetString(SI_KEYCODE107) .. GetString(SI_KEYCODE107) .. GetString(SI_KEYCODE107) ..
                            GetString(SI_CRAFTING_COMPONENT_TOOLTIP_UNKNOWN_TRAIT)
        local impressiveAchievement = {
            705,
            1838,
            2075,
            2139,
            2467,
            2746,
            3003,
            3249,
            3564,
            4019,
            4273,
            2368
        }
        table.insert(impressiveTitle, GetString(SI_CAMPAIGN_UNKNOWN_EMPEROR) .. postFix)
        for i = 1, #impressiveAchievement do
            local _, titl = GetAchievementRewardTitle(impressiveAchievement[i])
            table.insert(impressiveTitle, titl .. postFix)
        end
        GetUnitTitle = function(unitTag)
            return impressiveTitle[math.random(1, #impressiveTitle)]
        end
    else
        local GetUnitTitle_original = GetUnitTitle
        GetUnitTitle = function(unitTag)
            if (GetUnitDisplayName(unitTag) == "@Lykeion") then
                if GetUnitName(unitTag) == "This One Adores Inigo" then
                    if GetCVar("language.2") == "zh" then
                        return "|c9d1112鲜|r|c8b1011血|r|c790e0f铸|r|c670d0e就|r"
                    else
                        return "|cab1213A|r|ca61112g|r|ca21112e|r|c9d1112d|r |c991011T|r|c941011h|r|c901011r|r|c8b1011o|r|c870f10u|r|c820f10g|r|c7e0f10h|r |c790e0fB|r|c750e0fl|r|c700e0fo|r|c6c0d0eo|r|c670d0ed|r"
                    end
                elseif GetUnitName(unitTag) == "This One Might Have Wares" then
                    if GetCVar("language.2") == "zh" then
                        return "|c365f88黎|r|c4b677c明|r|c616e6f纪|r|c767562元|r|c8c7c55的|r|ca18449风|r|cb78b3c笛|r|ccc922f手|r"
                    else
                        return "|c275a91P|r|c2e5d8di|r|c365f88p|r|c3d6284e|r|c446480r|r |c4b677ca|r|c526977t|r |c596b73t|r|c616e6fh|r|c68706be|r |c6f7366G|r|c767562a|r|c7d775et|r|c847a5ae|r|c8c7c55s|r |c937f51o|r|c9a814df|r |ca18449D|r|ca88644a|r|caf8840w|r|cb78b3cn|r |cbe8d38E|r|cc59033r|r|ccc922fa|r"
                    end
                elseif GetUnitName(unitTag) == "This One Smuggles Skooma" then
                    if GetCVar("language.2") == "zh" then
                        return "|c5b33b4与|r|c4d309a死|r|c402e81者|r|c322b67共|r|c25284d舞|r"
                    else
                        return "|c6435c7D|r|c6134c0a|r|c5d34b9n|r|c5933b1c|r|c5532aai|r|c5231a3n|r|c4e319cg|r |c4a3095w|r|c472f8ei|r|c432e86t|r|c3f2d7fh|r |c3b2d78t|r|c382c71h|r|c342b6ae|r |c302a63D|r|c2c2a5be|r|c292954a|r|c25284dd|r"
                    end
                elseif GetUnitName(unitTag) == "This One Bears With You" then
                    if GetCVar("language.2") == "zh" then
                        return "|cbed768生|r|cd4cb61吞|r|ce9be5b活|r|cffb254剥|r"
                    else
                        return "|cb1de6bE|r|cb9d969a|r|cc2d466t|r|ccbcf64e|r|cd4cb61n|r |cdcc65eA|r|ce5c15cl|r|ceebc59i|r|cf6b757v|r|cffb254e|r"
                    end
                elseif GetUnitName(unitTag) == "This One Needs Moonsugar" then
                    if GetCVar("language.2") == "zh" then
                        return  "|cf3a300吾|r|ce77600心|r|cda4a00之|r|cce1d00形|r"
                    else
                        return  "|cfcc200S|r|cf8b600h|r|cf5a900a|r|cf19c00p|r|cee8f00e|r |cea8300o|r|ce77600f|r |ce36900M|r|ce05d00y|r |cdc5000H|r|cd94300e|r|cd53600a|r|cd22a00r|r|cce1d00t|r"
                    end
                elseif GetUnitName(unitTag) == "This One Steals Nothing" then
                    if GetCVar("language.2") == "zh" then
                        return "|c7ee1ca晶|r|c5ec9b0体|r|c3db196管|r"
                    else
                        return "|c95f2dcT|r|c8bebd4r|r|c82e3cda|r|c78dcc5n|r|c6ed5bds|r|c64ceb5i|r|c5ac7ads|r|c51bfa6t|r|c47b89eo|r|c3db196r|r"
                    end
                elseif GetUnitName(unitTag) == "This One Tells No Lie" then
                    if GetCVar("language.2") == "zh" then
                        return "|cd7d4a7恶|r|caeab87业|r|c868367长|r|c5d5a47存|r"
                    else
                        return "|cf5f2bfT|r|cebe8b7h|r|ce1deafe|r |cd7d4a7E|r|cccc99fv|r|cc2bf97i|r|cb8b58fl|r |caeab87T|r|ca4a17fh|r|c9a9777a|r|c908d6ft|r |c868367M|r|c7b785fe|r|c716e57n|r |c67644fD|r|c5d5a47o|r"
                    end
                else
                    if GetCVar("language.2") == "zh" then
                        return "|c3c6646沥|r|c3c6258青|r|c3d5e69世|r|c3d5a7b界|r"
                    else
                        return "|c3b693aA|r|c3b6740s|r|c3c6646p|r|c3c654ch|r|c3c6352a|r|c3c6258l|r|c3c615dt|r |c3c5f63W|r|c3d5e69o|r|c3d5d6fr|r|c3d5b75l|r|c3d5a7bd|r"
                    end
                end
            elseif (GetUnitDisplayName(unitTag) == "@lsxun" or GetUnitDisplayName(unitTag) == "@Isxun") then
                if GetCVar("language.2") == "zh" then
                    return "|cdcc9bc喵|cc48241喵|c8b5030喵|c3a3231喵|r"
                else
                    return "|cdcc9bcMeow |cc48241Meow |c8b5030Meow |c3a3231Meow|r"
                end
            else
                return GetUnitTitle_original(unitTag)   
            end
        end
    end
end

local function OnChatMessage( _, channelType, fromName, text, isCustomerService, fromDisplayName)
    local style, linkType, data, name = string.match( text, "||H(%d):(.-):(.-)||h(.-)||h" )
    if linkType == SUPERSTAR_SHARE and name == "[" .. SUPERSTAR_SHARE_NAME .. "]" then
        local temp = {}
        temp["name"] = fromDisplayName
        -- CHAT_ROUTER:AddSystemMessage(fromDisplayName .. " shared a Superstar Build")
        local pattern = "crafted_ability:(%d+):(%d+):(%d+):(%d+)"
        local abilityList = {}
        for abilityId, script1, script2, script3 in string.gmatch(text, pattern) do
            table.insert(abilityList, 
            {
                [SCRIBING_SLOT_NONE] = abilityId, 
                [SCRIBING_SLOT_PRIMARY] = script1, 
                [SCRIBING_SLOT_SECONDARY] = script2, 
                [SCRIBING_SLOT_TERTIARY] = script3, 
            })
        end
        if #abilityList ~= 0 then
            temp["abilityList"] = abilityList
        end
        cachedChatboxInfo[data:sub(-10)] = temp
    end
	
end

local function InitShareSetup()
    LibChatMessage:RegisterCustomChatLink( SUPERSTAR_SHARE, function( linkStyle, linkType, data, displayText )
        return ZO_LinkHandler_CreateLinkWithoutBrackets( displayText, nil, SUPERSTAR_SHARE, data )
    end )
    SLASH_COMMANDS["/ss"] = SuperStar_HandleSlashCommand
    SLASH_COMMANDS["/sss"] = insertShareLink
    SLASH_COMMANDS["/ssl"] = createIngameShareLink

    EVENT_MANAGER:RegisterForEvent( ADDON_NAME, EVENT_CHAT_MESSAGE_CHANNEL, OnChatMessage )
end

-- Initialises the settings and settings menu
local function OnAddonLoaded(_, addonName)
    -- Protect
    if addonName == ADDON_NAME then
        -- PtsAndLiveConvert()
        -- Fetch the saved variables
        db = ZO_SavedVars:NewAccountWide('SUPERSTAR', 1, nil, defaults)

        -- Init Share
        InitShareSetup()

        -- Init Scenes
        CreateScenes()

        -- Init Skill Builder
        InitSkills(SuperStarXMLSkills)

        -- Init Dialogs
        InitializeDialogs()

        -- Init Major Update Check
        InitMajorUpdateCheck()

        -- Register Slash commands
        SLASH_COMMANDS["/superstar"] = SuperStar_HandleSlashCommand
        if GetUnitDisplayName("player") == "@Lykeion" then
            SLASH_COMMANDS["/sst"] = function() SuperStar.test() end
        end

        -- InitTests()
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    end

end

-- Initialize
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)


function SuperStar.test()
    d(tostring(IsSubclassing()))
end
