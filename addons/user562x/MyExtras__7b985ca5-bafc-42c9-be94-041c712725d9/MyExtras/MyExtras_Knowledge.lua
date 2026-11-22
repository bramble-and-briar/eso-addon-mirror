local ME = MyExtras
local QoL = ME.QualityOfLife
local CK = {}
ME.Knowledge = CK

--------------------------------------------------
-- Config
--------------------------------------------------
local KNOWN_HEX   = "33DD33"
local UNKNOWN_HEX = "FF4444"
local UNCHECKED_HEX = "888888"
local HEADER_TEXT = "Characters"
local KNOWN_ICON = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_accept_down.dds"
local UNKNOWN_ICON = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_cancel_down.dds"
local MOTIF_BOOK_ID = 2166
local MOTIF_ITEM_LINK = "|H1:item:16424:4:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
local RECORD_DELAY = 1500
local RECORD_NAME = "MyExtras_KnowledgeRecord"

local DEFAULTS = {
    ckEnabled  = false,
    ckScripts  = true,
    ckRecipes  = true,
    ckPlans    = true,
    ckMotifs   = true,
    ckResearch = true,
}
QoL:AddDefaults(DEFAULTS)

CK.typeChoices = {
    { name = "Scripts",          value = "ckScripts"  },
    { name = "Recipes",          value = "ckRecipes"  },
    { name = "Furnishing Plans", value = "ckPlans"    },
    { name = "Motifs",           value = "ckMotifs"   },
    { name = "Research",         value = "ckResearch" },
}

local RESEARCH_CRAFTS = {
    CRAFTING_TYPE_BLACKSMITHING,
    CRAFTING_TYPE_CLOTHIER,
    CRAFTING_TYPE_WOODWORKING,
    CRAFTING_TYPE_JEWELRYCRAFTING,
}

local ARMOR_SLOTS = {
    EQUIP_TYPE_CHEST, EQUIP_TYPE_FEET, EQUIP_TYPE_HAND, EQUIP_TYPE_HEAD,
    EQUIP_TYPE_LEGS, EQUIP_TYPE_SHOULDERS, EQUIP_TYPE_WAIST,
}

local SCAN_BAGS = { BAG_WORN, BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }

local hookedTips = {}
local recordPending = false
local researchLines

--------------------------------------------------
-- Helpers
--------------------------------------------------
local function SV()
    return QoL:Settings()
end

local function Data()
    local sv = ME.savedVariables
    if type(sv.knowledge) ~= "table" then sv.knowledge = {} end
    local data = sv.knowledge
    if type(data.characters) ~= "table" then data.characters = {} end
    if type(data.lines) ~= "table" then data.lines = {} end
    return data
end

local function IsOn()
    return SV().ckEnabled == true
end

local function Bits(count, isSet)
    local bits = {}
    for i = 1, count do bits[i] = isSet(i) and "1" or "0" end
    return table.concat(bits)
end

local function BitAt(bits, index)
    if type(bits) ~= "string" or index < 1 or index > #bits then return nil end
    return string.sub(bits, index, index) == "1"
end

local function Colorize(hex, text)
    return "|c" .. hex .. text .. "|r"
end

--------------------------------------------------
-- Characters
--------------------------------------------------
local function CurrentId()
    return GetCurrentCharacterId and tostring(GetCurrentCharacterId() or "") or ""
end

local function AccountCharacters()
    if not (GetNumCharacters and GetCharacterInfo) then return nil end
    local count = GetNumCharacters()
    if type(count) ~= "number" or count == 0 then return nil end
    local list = {}
    for i = 1, count do
        local name, _, _, _, _, _, id = GetCharacterInfo(i)
        if id ~= nil and name then
            list[#list + 1] = { id = tostring(id), name = zo_strformat("<<1>>", name) }
        end
    end
    return list
end

local function PruneDeleted()
    local list = AccountCharacters()
    if not list then return end
    local valid = {}
    for i = 1, #list do valid[list[i].id] = list[i].name end
    if not valid[CurrentId()] then return end
    local characters = Data().characters
    for id, record in pairs(characters) do
        if not valid[id] then
            characters[id] = nil
        elseif type(record) == "table" then
            record.name = valid[id]
        end
    end
end

local function OrderedCharacters()
    local list = AccountCharacters()
    if list then return list end
    list = {}
    for id, record in pairs(Data().characters) do
        list[#list + 1] = { id = id, name = record.name or id }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

--------------------------------------------------
-- Research Lines
--------------------------------------------------
local function ResearchLines()
    if researchLines then return researchLines end
    researchLines = {}
    for c = 1, #RESEARCH_CRAFTS do
        local craft = RESEARCH_CRAFTS[c]
        if craft then
            researchLines[craft] = {}
            for line = 1, GetNumSmithingResearchLines(craft) do
                local name, _, numTraits = GetSmithingResearchLineInfo(craft, line)
                local traits = {}
                for t = 1, numTraits do
                    local traitType = GetSmithingResearchLineTraitInfo(craft, line, t)
                    traits[traitType] = t
                end
                researchLines[craft][line] = { name = name, traits = traits, numTraits = numTraits }
            end
        end
    end
    return researchLines
end

local function GearKey(itemLink)
    local itemType = GetItemLinkItemType(itemLink)
    if itemType == ITEMTYPE_WEAPON then
        return "w" .. tostring(GetItemLinkWeaponType(itemLink))
    elseif itemType == ITEMTYPE_ARMOR then
        local equipType = GetItemLinkEquipType(itemLink)
        if equipType == EQUIP_TYPE_NECK or equipType == EQUIP_TYPE_RING then
            return "j" .. tostring(equipType)
        end
        return "a" .. tostring(GetItemLinkArmorType(itemLink)) .. ":" .. tostring(equipType)
    end
    return nil
end

local function DefaultLine(itemLink)
    local itemType = GetItemLinkItemType(itemLink)
    if itemType == ITEMTYPE_WEAPON then
        local weaponType = GetItemLinkWeaponType(itemLink)
        local smith = {
            [WEAPONTYPE_AXE] = 1, [WEAPONTYPE_HAMMER] = 2, [WEAPONTYPE_SWORD] = 3,
            [WEAPONTYPE_TWO_HANDED_AXE] = 4, [WEAPONTYPE_TWO_HANDED_HAMMER] = 5,
            [WEAPONTYPE_TWO_HANDED_SWORD] = 6, [WEAPONTYPE_DAGGER] = 7,
        }
        local wood = {
            [WEAPONTYPE_BOW] = 1, [WEAPONTYPE_FIRE_STAFF] = 2, [WEAPONTYPE_FROST_STAFF] = 3,
            [WEAPONTYPE_LIGHTNING_STAFF] = 4, [WEAPONTYPE_HEALING_STAFF] = 5, [WEAPONTYPE_SHIELD] = 6,
        }
        if smith[weaponType] then return CRAFTING_TYPE_BLACKSMITHING, smith[weaponType] end
        if wood[weaponType] then return CRAFTING_TYPE_WOODWORKING, wood[weaponType] end
        return nil
    elseif itemType == ITEMTYPE_ARMOR then
        local equipType = GetItemLinkEquipType(itemLink)
        if equipType == EQUIP_TYPE_RING then return CRAFTING_TYPE_JEWELRYCRAFTING, 1 end
        if equipType == EQUIP_TYPE_NECK then return CRAFTING_TYPE_JEWELRYCRAFTING, 2 end
        local slot
        for i = 1, #ARMOR_SLOTS do
            if ARMOR_SLOTS[i] == equipType then slot = i break end
        end
        if not slot then return nil end
        local armorType = GetItemLinkArmorType(itemLink)
        if armorType == ARMORTYPE_HEAVY then return CRAFTING_TYPE_BLACKSMITHING, 7 + slot end
        if armorType == ARMORTYPE_LIGHT then return CRAFTING_TYPE_CLOTHIER, slot end
        if armorType == ARMORTYPE_MEDIUM then return CRAFTING_TYPE_CLOTHIER, 7 + slot end
    end
    return nil
end

local function LineFromName(craft, lineName)
    local lines = ResearchLines()[craft]
    if not lines or not lineName then return nil end
    for line = 1, #lines do
        if lines[line].name == lineName then return line end
    end
    return nil
end

local function LearnLine(itemLink, bagId, slotIndex)
    if not (GetRearchLineInfoFromRetraitItem and bagId and slotIndex) then return end
    local key = GearKey(itemLink)
    if not key then return end
    local craft, lineName = GetRearchLineInfoFromRetraitItem(bagId, slotIndex)
    local line = LineFromName(craft, lineName)
    if craft and line then Data().lines[key] = { craft, line } end
end

local function ResearchSlot(itemLink)
    local traitType = GetItemLinkTraitInfo(itemLink)
    if not traitType or traitType == ITEM_TRAIT_TYPE_NONE then return nil end
    local key = GearKey(itemLink)
    if not key then return nil end
    local craft, line
    local saved = Data().lines[key]
    if type(saved) == "table" then
        craft, line = saved[1], saved[2]
    else
        craft, line = DefaultLine(itemLink)
    end
    if not craft then return nil end
    local lines = ResearchLines()[craft]
    local info = lines and lines[line]
    local traitIndex = info and info.traits[traitType]
    if not traitIndex then return nil end
    return craft, line, traitIndex
end

local function ScanBagsForLines()
    if not (GetBagSize and GetItemLink) then return end
    for b = 1, #SCAN_BAGS do
        local bagId = SCAN_BAGS[b]
        if bagId then
            for slotIndex = 0, GetBagSize(bagId) - 1 do
                local itemLink = GetItemLink(bagId, slotIndex)
                if itemLink ~= "" then
                    local key = GearKey(itemLink)
                    if key and not Data().lines[key] then pcall(LearnLine, itemLink, bagId, slotIndex) end
                end
            end
        end
    end
end

--------------------------------------------------
-- Recording
--------------------------------------------------
local function FindMotifCategory()
    local data = Data()
    if data.motifCategoryId then return end
    local categoryIndex = GetLoreBookIndicesFromBookId(MOTIF_BOOK_ID)
    if not categoryIndex and GetItemLinkItemUseType(MOTIF_ITEM_LINK) == ITEM_USE_TYPE_BOOK then
        categoryIndex = GetLoreBookIndicesFromBookId(GetItemLinkItemUseReferenceId(MOTIF_ITEM_LINK))
    end
    if categoryIndex then
        local _, _, categoryId = GetLoreCategoryInfo(categoryIndex)
        data.motifCategoryId = categoryId
    end
end

local function MotifCategory()
    pcall(FindMotifCategory)
    local categoryId = Data().motifCategoryId
    if not categoryId then return nil end
    for categoryIndex = 1, GetNumLoreCategories() do
        local _, _, id = GetLoreCategoryInfo(categoryIndex)
        if id == categoryId then return categoryIndex end
    end
    return nil
end

local function RecordRecipes(record)
    local recipes = {}
    for listIndex = 1, GetNumRecipeLists() do
        local _, numRecipes = GetRecipeListInfo(listIndex)
        recipes[listIndex] = Bits(numRecipes or 0, function(recipeIndex)
            return GetRecipeInfo(listIndex, recipeIndex) == true
        end)
    end
    record.recipes = recipes
end

local function RecordScribing(record)
    local grimoires, scripts = {}, {}
    local slots = { SCRIBING_SLOT_PRIMARY, SCRIBING_SLOT_SECONDARY, SCRIBING_SLOT_TERTIARY }
    for index = 1, GetNumCraftedAbilities() do
        local craftedAbilityId = GetCraftedAbilityIdAtIndex(index)
        if craftedAbilityId then
            if IsCraftedAbilityUnlocked(craftedAbilityId) then grimoires[craftedAbilityId] = true end
            for s = 1, #slots do
                local slot = slots[s]
                if slot then
                    for i = 1, GetNumScriptsInSlotForCraftedAbility(craftedAbilityId, slot) do
                        local scriptId = GetScriptIdAtSlotIndexForCraftedAbility(craftedAbilityId, slot, i)
                        if scriptId and IsCraftedAbilityScriptUnlocked(scriptId) then scripts[scriptId] = true end
                    end
                end
            end
        end
    end
    record.grimoires = grimoires
    record.scripts = scripts
end

local function RecordMotifs(record)
    local categoryIndex = MotifCategory()
    if not categoryIndex then return end
    local motifs = {}
    local _, numCollections = GetLoreCategoryInfo(categoryIndex)
    for collectionIndex = 1, numCollections do
        local _, _, _, totalBooks = GetLoreCollectionInfo(categoryIndex, collectionIndex)
        motifs[collectionIndex] = Bits(totalBooks or 0, function(bookIndex)
            local _, _, known = GetLoreBookInfo(categoryIndex, collectionIndex, bookIndex)
            return known == true
        end)
    end
    record.motifs = motifs
end

local function RecordResearch(record)
    local research = {}
    for craft, lines in pairs(ResearchLines()) do
        research[craft] = {}
        for line = 1, #lines do
            research[craft][line] = Bits(lines[line].numTraits, function(traitIndex)
                local _, _, known = GetSmithingResearchLineTraitInfo(craft, line, traitIndex)
                return known == true
            end)
        end
    end
    record.research = research
end

function CK:Record()
    local id = CurrentId()
    if id == "" then return end
    local characters = Data().characters
    local record = characters[id] or {}
    record.name = zo_strformat("<<1>>", GetUnitName("player"))
    pcall(RecordRecipes, record)
    pcall(RecordScribing, record)
    pcall(RecordMotifs, record)
    pcall(RecordResearch, record)
    characters[id] = record
end

local function QueueRecord()
    if recordPending then return end
    recordPending = true
    zo_callLater(function()
        recordPending = false
        CK:Record()
    end, RECORD_DELAY)
end

function CK:RegisterRecording()
    if self.recordingRegistered then return end
    self.recordingRegistered = true
    local events = {
        EVENT_RECIPE_LEARNED,
        EVENT_MULTIPLE_RECIPES_LEARNED,
        EVENT_STYLE_LEARNED,
        EVENT_LORE_BOOK_LEARNED,
        EVENT_SMITHING_TRAIT_RESEARCH_COMPLETED,
        EVENT_CRAFTED_ABILITY_LOCK_STATE_CHANGED,
        EVENT_CRAFTED_ABILITY_SCRIPT_LOCK_STATE_CHANGED,
    }
    for i = 1, #events do
        if events[i] then
            EVENT_MANAGER:RegisterForEvent(RECORD_NAME .. i, events[i], QueueRecord)
        end
    end
end

--------------------------------------------------
-- Lookup
--------------------------------------------------
local function MotifIndices(itemLink)
    if GetItemLinkItemUseType(itemLink) ~= ITEM_USE_TYPE_BOOK then return nil end
    local bookId = GetItemLinkItemUseReferenceId(itemLink)
    if not bookId or bookId == 0 then return nil end
    local categoryIndex, collectionIndex, bookIndex = GetLoreBookIndicesFromBookId(bookId)
    if not categoryIndex then return nil end
    local _, _, categoryId = GetLoreCategoryInfo(categoryIndex)
    local data = Data()
    if data.motifCategoryId ~= categoryId then
        data.motifCategoryId = categoryId
        QueueRecord()
    end
    return collectionIndex, bookIndex
end

local function Checker(itemLink)
    local sv = SV()
    local useType = GetItemLinkItemUseType(itemLink)

    if useType == ITEM_USE_TYPE_CRAFTED_ABILITY and sv.ckScripts then
        local id = GetItemLinkItemUseReferenceId(itemLink)
        return function(record) return record.grimoires and record.grimoires[id] == true end
    end
    if useType == ITEM_USE_TYPE_CRAFTED_ABILITY_SCRIPT and sv.ckScripts then
        local id = GetItemLinkItemUseReferenceId(itemLink)
        return function(record) return record.scripts and record.scripts[id] == true end
    end

    local listIndex, recipeIndex = GetItemLinkGrantedRecipeIndices(itemLink)
    if listIndex and recipeIndex then
        local isPlan = IsItemLinkFurnitureRecipe(itemLink)
        if (isPlan and not sv.ckPlans) or (not isPlan and not sv.ckRecipes) then return nil end
        return function(record)
            return record.recipes and BitAt(record.recipes[listIndex], recipeIndex)
        end
    end

    if GetItemLinkItemType(itemLink) == ITEMTYPE_RACIAL_STYLE_MOTIF and sv.ckMotifs then
        local collectionIndex, bookIndex = MotifIndices(itemLink)
        if not collectionIndex then return nil end
        return function(record)
            return record.motifs and BitAt(record.motifs[collectionIndex], bookIndex)
        end
    end

    if sv.ckResearch then
        local craft, line, traitIndex = ResearchSlot(itemLink)
        if craft then
            return function(record)
                local lines = record.research and record.research[craft]
                return lines and BitAt(lines[line], traitIndex)
            end
        end
    end
    return nil
end

local function KnowledgeLine(itemLink)
    local check = Checker(itemLink)
    if not check then return nil end
    local hidden = SV().ckHidden or {}
    local characters = Data().characters
    local known, unknown, unchecked = {}, {}, {}
    for _, character in ipairs(OrderedCharacters()) do
        if not hidden[character.id] then
            local record = characters[character.id]
            local result = record and check(record)
            if result == true then
                known[#known + 1] = character.name
            elseif result == false then
                unknown[#unknown + 1] = character.name
            else
                unchecked[#unchecked + 1] = character.name
            end
        end
    end
    local lines = {}
    if #known > 0 then
        lines[#lines + 1] = zo_iconFormat(KNOWN_ICON, "100%", "100%") .. " " .. Colorize(KNOWN_HEX, table.concat(known, ", "))
    end
    if #unknown > 0 then
        lines[#lines + 1] = zo_iconFormat(UNKNOWN_ICON, "100%", "100%") .. " " .. Colorize(UNKNOWN_HEX, table.concat(unknown, ", "))
    end
    if #unchecked > 0 then
        lines[#lines + 1] = Colorize(UNCHECKED_HEX, table.concat(unchecked, ", "))
    end
    if #lines == 0 then return nil end
    return lines
end

--------------------------------------------------
-- Tooltips
--------------------------------------------------
local function AddKnowledge(tooltip, itemLink)
    if not IsOn() or type(itemLink) ~= "string" or itemLink == "" then return end
    if tooltip.myExtrasBag then
        LearnLine(itemLink, tooltip.myExtrasBag, tooltip.myExtrasSlot)
    end
    local lines = KnowledgeLine(itemLink)
    if not lines then return end
    local header = tooltip:AcquireSection(tooltip:GetStyle("bodyHeader"))
    header:AddLine(HEADER_TEXT)
    tooltip:AddSection(header)
    for i = 1, #lines do
        local body = tooltip:AcquireSection(tooltip:GetStyle("bodySection"))
        body:AddLine(lines[i], tooltip:GetStyle("bodyDescription"))
        tooltip:AddSection(body)
    end
end

local function HookTooltip(tooltip)
    if not tooltip or hookedTips[tooltip] or type(tooltip.LayoutItem) ~= "function" then return end
    hookedTips[tooltip] = true

    if type(tooltip.AddItemTitle) == "function" then
        local addItemTitle = tooltip.AddItemTitle
        tooltip.AddItemTitle = function(self, itemLink, ...)
            local results = { addItemTitle(self, itemLink, ...) }
            if self.myExtrasKnowledgeAdded ~= true then
                if self.myExtrasKnowledgeAdded == false then self.myExtrasKnowledgeAdded = true end
                pcall(AddKnowledge, self, itemLink)
            end
            return unpack(results)
        end
    end

    local layoutItem = tooltip.LayoutItem
    tooltip.LayoutItem = function(self, itemLink, ...)
        self.myExtrasKnowledgeAdded = false
        local results = { layoutItem(self, itemLink, ...) }
        if not self.myExtrasKnowledgeAdded then pcall(AddKnowledge, self, itemLink) end
        self.myExtrasKnowledgeAdded = nil
        return unpack(results)
    end

    if type(tooltip.LayoutBagItem) == "function" then
        local layoutBagItem = tooltip.LayoutBagItem
        tooltip.LayoutBagItem = function(self, bagId, slotIndex, ...)
            self.myExtrasBag, self.myExtrasSlot = bagId, slotIndex
            local results = { layoutBagItem(self, bagId, slotIndex, ...) }
            self.myExtrasBag, self.myExtrasSlot = nil, nil
            return unpack(results)
        end
    end
end

function CK:HookTooltips()
    local manager = GAMEPAD_TOOLTIPS
    if not manager or self.tooltipsHooked or type(manager.GetAndInitializeTooltipContainerTip) ~= "function" then return end
    self.tooltipsHooked = true

    local getTip = manager.GetAndInitializeTooltipContainerTip
    manager.GetAndInitializeTooltipContainerTip = function(self, ...)
        local tip = getTip(self, ...)
        if tip and tip.tooltip then pcall(HookTooltip, tip.tooltip) end
        return tip
    end

    if type(manager.tooltips) == "table" then
        for _, info in pairs(manager.tooltips) do
            local container = info.control and info.control.container
            local tip = container and container.tip
            if tip and tip.initialized and tip.tooltip then pcall(HookTooltip, tip.tooltip) end
        end
    end
end

--------------------------------------------------
-- Menu
--------------------------------------------------
local function TypeValues()
    local sv = SV()
    local values = {}
    for i = 1, #CK.typeChoices do
        local key = CK.typeChoices[i].value
        if sv[key] then values[#values + 1] = key end
    end
    return values
end

local function SaveTypes(values)
    local sv = SV()
    local set = {}
    for i = 1, #(values or {}) do set[values[i]] = true end
    for i = 1, #CK.typeChoices do
        local key = CK.typeChoices[i].value
        sv[key] = set[key] == true
    end
end

local function CharacterChoices()
    local choices = {}
    for _, character in ipairs(OrderedCharacters()) do
        choices[#choices + 1] = { name = character.name, value = character.id }
    end
    return choices
end

local function CharacterValues()
    local hidden = SV().ckHidden or {}
    local values = {}
    for _, character in ipairs(OrderedCharacters()) do
        if not hidden[character.id] then values[#values + 1] = character.id end
    end
    return values
end

local function SaveCharacters(values)
    local shown = {}
    for i = 1, #(values or {}) do shown[values[i]] = true end
    local hidden = {}
    for _, character in ipairs(OrderedCharacters()) do
        if not shown[character.id] then hidden[character.id] = true end
    end
    SV().ckHidden = hidden
end

function CK:Options()
    local function IsCkOff() return not IsOn() end
    local allTypes = {}
    for i = 1, #CK.typeChoices do allTypes[i] = CK.typeChoices[i].value end
    return {
        {
            type     = "toggle",
            name     = "Enabled",
            preset   = "YES_NO",
            default  = DEFAULTS.ckEnabled,
            tooltip  = "Adds a list of your characters to item tooltips. A green check knows it, a red X doesn't, "
                    .. "grey hasn't been checked yet. Log in once on each character so it can be checked.",
            getFunc  = function() return SV().ckEnabled end,
            setFunc  = function(val) SV().ckEnabled = val end,
        },
        {
            type     = "checklist",
            name     = "Knowledge Types",
            choices  = CK.typeChoices,
            default  = allTypes,
            disabled = IsCkOff,
            tooltip  = "Which items show your characters.\n\n"
                    .. "Scripts: scribing grimoires and scripts.\n"
                    .. "Recipes: food and drink recipes.\n"
                    .. "Furnishing Plans: plans for every crafting type.\n"
                    .. "Motifs: crafting motifs and their chapters.\n"
                    .. "Research: which characters still need to research the trait on armor, weapons and jewelry.",
            getFunc  = TypeValues,
            setFunc  = SaveTypes,
        },
        {
            type     = "checklist",
            name     = "Characters",
            choices  = CharacterChoices,
            disabled = IsCkOff,
            tooltip  = "Which characters show in item tooltips.",
            getFunc  = CharacterValues,
            setFunc  = SaveCharacters,
        },
    }
end

function CK:SubmenuOption()
    return {
        type    = "submenu",
        name    = "Character Knowledge",
        tooltip = "Shows which of your characters know an item in its tooltip.\n\n" .. ME.SAVED_ACCOUNT_TIP,
        options = self:Options(),
    }
end

--------------------------------------------------
-- Lifecycle
--------------------------------------------------
function CK:Init()
    self:RegisterRecording()
    self:HookTooltips()
end

function CK:OnPlayerActivated()
    self:RegisterRecording()
    self:HookTooltips()
    if not self.recordedThisSession then
        self.recordedThisSession = true
        PruneDeleted()
        zo_callLater(function()
            pcall(ScanBagsForLines)
            CK:Record()
        end, RECORD_DELAY)
    end
end

ME:RegisterFeature(CK)
