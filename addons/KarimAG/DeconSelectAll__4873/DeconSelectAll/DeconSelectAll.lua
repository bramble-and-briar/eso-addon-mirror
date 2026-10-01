--[[
    Decon Select All
    ----------------
    Adds a "Select all" button (keybind strip, bottom of the screen) to the
    keyboard crafting UI of The Elder Scrolls Online:

      * Blacksmithing / Clothing / Woodworking / Jewelry stations
            - Deconstruction tab
            - Refinement tab (raw materials)
      * Universal Deconstruction (Giladil the Ragpicker, deconstruction assistants)
      * Enchanting station - Extraction tab (glyphs)

    One click slots every item currently listed in the panel's inventory list
    (so the game's own tab filters, "Include banked items" checkbox and any
    filtering add-on such as FCO CraftFilter / AdvancedFilters are respected),
    minus the items the safety rules exclude.  The game then still asks you to
    confirm the multi-deconstruct, exactly as when you slot items one by one.

    The add-on never deconstructs anything by itself.

    Verified against the ESO UI source (esoui 12.0.8, API 101050):
      ZO_SharedSmithingExtraction / ZO_UniversalDeconstructionPanel_Shared /
      ZO_SharedEnchanting  ->  :AddItemToCraft(), :IsSlotted(), :CanItemBeAddedToCraft()
      ZO_CraftingMultiSlotBase (extraction slot)  ->  :GetNumItems(), :GetStackCount(), :HasItems()
      ZO_CraftingInventory  ->  .list  (ZO_ScrollList, entries carry data.bagId / data.slotIndex)

    AI disclosure: the code was generated with an AI assistant (Anthropic Claude) under the
    author's direction, and tested in-game by the author.

    Credits: the "select all" concept and several of the safety rules exist in earlier add-ons
    whose ESOUI pages were reviewed while designing this one (no code was taken from them):
      DeconstructAll (awfuldead), Deconstruction Assistant (CodeStripper),
      IsJusta Decon Carried Items List (IsJustaGhost), Lazy Deconstructor (StorybookTerror),
      Mass Deconstructor (ahmetertem, sinnereso), DoItAll (Thenedus, Baertram).
    FCO ItemSaver protection is honoured through its public API (Baertram).
]]

DeconSelectAll = DeconSelectAll or {}
local DSA = DeconSelectAll

DSA.name          = "DeconSelectAll"
DSA.displayName   = "Decon Select All"
DSA.version       = "1.0.1"
DSA.author        = "Karim"
DSA.savedVarsName = "DeconSelectAll_SavedVars"

local KEYBIND_ACTION = "DECONSELECTALL_SELECT_ALL"

-- ---------------------------------------------------------------------------
-- Defaults (account wide)
-- ---------------------------------------------------------------------------
local defaults =
{
    skipSetItems     = true,   -- items belonging to an item set
    skipResearchable = true,   -- items whose trait you could still research
    skipOrnate       = true,   -- ornate items are worth more sold to a merchant
    skipArmory       = true,   -- items used by an Armory build
    maxQuality       = ITEM_FUNCTIONAL_QUALITY_ARTIFACT or 4, -- purple; gold (legendary) is skipped by default
    chatSummary      = true,   -- print a one-line summary in the chat after selecting
}

-- ---------------------------------------------------------------------------
-- Localisation (falls back to English)
-- ---------------------------------------------------------------------------
local STRINGS =
{
    en =
    {
        SELECT_ALL      = "Select all",
        BINDING_NAME    = "Select all (deconstruction)",
        NO_PANEL        = "Open the Deconstruction, Refinement or Extraction tab of a crafting station first.",
        BUSY            = "Wait for the current crafting operation to finish.",
        GAMEPAD         = "Gamepad UI mode is not supported.",
        NOTHING         = "Nothing to select in the current list.",
        RESULT          = "<<1>> item(s) selected, <<2>> total in the slot.",
        SKIPPED         = "Skipped: <<1>>.",
        LIMIT           = "Game limit reached (max <<1>> items per batch): deconstruct, then select again for the rest.",
        SKIP_locked     = "<<1>> locked",
        SKIP_fcois      = "<<1>> protected by FCO ItemSaver",
        SKIP_armory     = "<<1>> in an Armory build",
        SKIP_quality    = "<<1>> above the quality limit",
        SKIP_set        = "<<1>> set item(s)",
        SKIP_research   = "<<1>> researchable",
        SKIP_ornate     = "<<1>> ornate",
        HELP_TITLE      = "Decon Select All <<1>> - commands:",
        HELP_SELECT     = "/dsa select - select all listed items (same as the button)",
        HELP_SETS       = "/dsa sets - toggle skipping set items (currently: <<1>>)",
        HELP_RESEARCH   = "/dsa research - toggle skipping researchable traits (currently: <<1>>)",
        HELP_ORNATE     = "/dsa ornate - toggle skipping ornate items (currently: <<1>>)",
        HELP_ARMORY     = "/dsa armory - toggle skipping Armory build items (currently: <<1>>)",
        HELP_QUALITY    = "/dsa quality <1-5> - highest quality to select, 1=white ... 5=gold (currently: <<1>>)",
        HELP_QUIET      = "/dsa quiet - toggle the chat summary (currently: <<1>>)",
        HELP_KEYBIND    = "A key can be bound under Settings > Controls > Keybindings > Decon Select All.",
        ON              = "on",
        OFF             = "off",
        SETTING_SET     = "<<1>> is now <<2>>.",
        OPT_SETS        = "Skip set items",
        OPT_SETS_TT     = "Never select items that belong to an item set.",
        OPT_RESEARCH    = "Skip researchable traits",
        OPT_RESEARCH_TT = "Never select items whose trait you have not researched yet (the research icon).",
        OPT_ORNATE      = "Skip ornate items",
        OPT_ORNATE_TT   = "Ornate items sell for more gold than their deconstruction is worth.",
        OPT_ARMORY      = "Skip Armory build items",
        OPT_ARMORY_TT   = "Never select items that are part of an Armory build.",
        OPT_QUALITY     = "Highest quality to select",
        OPT_QUALITY_TT  = "Items above this quality are never selected.",
        OPT_QUIET       = "Chat summary",
        OPT_QUIET_TT    = "Print a one-line summary in the chat after each selection.",
        OPT_DESC        = "Items are always selected from the list currently displayed, so the game's own tab filters and the \"Include banked items\" checkbox apply. Locked items and items protected by FCO ItemSaver are always skipped.",
    },
    fr =
    {
        SELECT_ALL      = "Tout sélectionner",
        BINDING_NAME    = "Tout sélectionner (déconstruction)",
        NO_PANEL        = "Ouvrez d'abord l'onglet Déconstruction, Raffinage ou Extraction d'un atelier.",
        BUSY            = "Attendez la fin de l'opération d'artisanat en cours.",
        GAMEPAD         = "L'interface manette n'est pas prise en charge.",
        NOTHING         = "Rien à sélectionner dans la liste actuelle.",
        RESULT          = "<<1>> objet(s) sélectionné(s), <<2>> au total dans l'emplacement.",
        SKIPPED         = "Ignorés : <<1>>.",
        LIMIT           = "Limite du jeu atteinte (<<1>> objets max par lot) : déconstruisez, puis relancez la sélection pour le reste.",
        SKIP_locked     = "<<1>> verrouillé(s)",
        SKIP_fcois      = "<<1>> protégé(s) par FCO ItemSaver",
        SKIP_armory     = "<<1>> dans une configuration d'Arsenal",
        SKIP_quality    = "<<1>> au-dessus de la qualité limite",
        SKIP_set        = "<<1>> objet(s) d'ensemble",
        SKIP_research   = "<<1>> trait(s) à rechercher",
        SKIP_ornate     = "<<1>> ornemental(aux)",
        HELP_TITLE      = "Decon Select All <<1>> - commandes :",
        HELP_SELECT     = "/dsa select - sélectionne tous les objets listés (comme le bouton)",
        HELP_SETS       = "/dsa sets - ignorer ou non les objets d'ensemble (actuellement : <<1>>)",
        HELP_RESEARCH   = "/dsa research - ignorer ou non les traits à rechercher (actuellement : <<1>>)",
        HELP_ORNATE     = "/dsa ornate - ignorer ou non les objets ornementaux (actuellement : <<1>>)",
        HELP_ARMORY     = "/dsa armory - ignorer ou non les objets d'une configuration d'Arsenal (actuellement : <<1>>)",
        HELP_QUALITY    = "/dsa quality <1-5> - qualité maximale sélectionnée, 1=blanc ... 5=or (actuellement : <<1>>)",
        HELP_QUIET      = "/dsa quiet - afficher ou non le résumé dans le tchat (actuellement : <<1>>)",
        HELP_KEYBIND    = "Une touche peut être assignée dans Paramètres > Commandes > Raccourcis > Decon Select All.",
        ON              = "activé",
        OFF             = "désactivé",
        SETTING_SET     = "<<1>> : <<2>>.",
        OPT_SETS        = "Ignorer les objets d'ensemble",
        OPT_SETS_TT     = "Ne jamais sélectionner un objet appartenant à un ensemble.",
        OPT_RESEARCH    = "Ignorer les traits à rechercher",
        OPT_RESEARCH_TT = "Ne jamais sélectionner un objet dont le trait n'est pas encore recherché (icône de recherche).",
        OPT_ORNATE      = "Ignorer les objets ornementaux",
        OPT_ORNATE_TT   = "Les objets ornementaux rapportent plus vendus à un marchand que déconstruits.",
        OPT_ARMORY      = "Ignorer les objets d'une configuration d'Arsenal",
        OPT_ARMORY_TT   = "Ne jamais sélectionner un objet utilisé par une configuration d'Arsenal.",
        OPT_QUALITY     = "Qualité maximale sélectionnée",
        OPT_QUALITY_TT  = "Les objets au-dessus de cette qualité ne sont jamais sélectionnés.",
        OPT_QUIET       = "Résumé dans le tchat",
        OPT_QUIET_TT    = "Affiche une ligne de résumé dans le tchat après chaque sélection.",
        OPT_DESC        = "Les objets sont toujours pris dans la liste affichée : les filtres du jeu et la case « Inclure les objets de la banque » s'appliquent. Les objets verrouillés et ceux protégés par FCO ItemSaver sont toujours ignorés.",
    },
}

local function GetLanguageStrings()
    local lang = GetCVar and GetCVar("language.2") or "en"
    return STRINGS[lang] or STRINGS.en
end

-- Returns the localised string for a key (English fallback), formatted with zo_strformat when arguments are given.
function DSA.L(key, ...)
    local strings = GetLanguageStrings()
    local text = strings[key] or STRINGS.en[key] or key
    if select("#", ...) > 0 then
        return zo_strformat(text, ...)
    end
    return text
end

-- ---------------------------------------------------------------------------
-- Chat output
-- ---------------------------------------------------------------------------
function DSA.Msg(text)
    local line = "|c00BFFFDSA|r " .. tostring(text)
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(line)
    else
        d(line)
    end
end

-- Name shown in Settings > Controls > Keybindings (must exist before the keybindings UI is built)
ZO_CreateStringId("SI_BINDING_NAME_" .. KEYBIND_ACTION, DSA.L("BINDING_NAME"))

-- ---------------------------------------------------------------------------
-- Game limits (globals provided by the game, with fallbacks)
-- ---------------------------------------------------------------------------
local function GetMaxSlotsPerBatch()
    return MAX_ITEM_SLOTS_PER_DECONSTRUCTION or 100
end

local function GetMaxIterationsPerBatch()
    return MAX_ITERATIONS_PER_DECONSTRUCTION or 100
end

-- ---------------------------------------------------------------------------
-- Which panel is currently on screen?
--   returns panel, kind   ("deconstruction" | "refinement" | "universal" | "enchanting")
--   or      nil,   reason ("gamepad" | "wrong_tab" | "no_panel")
-- ---------------------------------------------------------------------------
local function GetActiveExtractionPanel()
    if IsInGamepadPreferredMode() then
        return nil, "gamepad"
    end

    if SMITHING and SCENE_MANAGER:IsShowing("smithing") then
        local mode = SMITHING:GetMode()
        if mode == SMITHING_MODE_DECONSTRUCTION and SMITHING.deconstructionPanel then
            return SMITHING.deconstructionPanel, "deconstruction"
        elseif mode == SMITHING_MODE_REFINEMENT and SMITHING.refinementPanel then
            return SMITHING.refinementPanel, "refinement"
        end
        return nil, "wrong_tab"
    end

    if UNIVERSAL_DECONSTRUCTION and SCENE_MANAGER:IsShowing("universalDeconstructionSceneKeyboard") then
        if UNIVERSAL_DECONSTRUCTION.deconstructionPanel then
            return UNIVERSAL_DECONSTRUCTION.deconstructionPanel, "universal"
        end
        return nil, "no_panel"
    end

    if ENCHANTING and SCENE_MANAGER:IsShowing("enchanting") then
        if ENCHANTING:GetEnchantingMode() == ENCHANTING_MODE_EXTRACTION then
            return ENCHANTING, "enchanting"
        end
        return nil, "wrong_tab"
    end

    return nil, "no_panel"
end

-- Copies the (bagId, slotIndex) pairs of every row currently in the panel's inventory list.
-- A copy is taken first because slotting items refreshes the list while we iterate.
local function CollectListedItems(panel)
    local items = {}
    local inventory = panel.inventory
    if not (inventory and inventory.list) then
        return items
    end

    local scrollData = ZO_ScrollList_GetDataList(inventory.list)
    for _, entry in ipairs(scrollData) do
        local data = entry.data
        if data and data.bagId and data.slotIndex then
            items[#items + 1] = { bagId = data.bagId, slotIndex = data.slotIndex }
        end
    end
    return items
end

-- FCO ItemSaver protection (only if that add-on is running).
-- FCOIS.IsLocked(bagId, slotIndex) is FCOIS' entry point for other add-ons: it detects the panel
-- that is currently open (crafting station tab or universal deconstruction NPC) and applies the
-- marker-icon protection settings for that panel. Older FCOIS versions without IsLocked fall back
-- to the panel-specific checks.
local function IsProtectedByFCOIS(bagId, slotIndex, kind)
    if not FCOIS then
        return false
    end

    local checkFn = FCOIS.IsLocked
    if type(checkFn) ~= "function" then
        if kind == "refinement" then
            checkFn = FCOIS.IsRefinementLocked
        elseif kind == "enchanting" then
            checkFn = FCOIS.IsEnchantingExtractionLocked
        else
            checkFn = FCOIS.IsDeconstructionLocked
        end
    end
    if type(checkFn) ~= "function" then
        return false
    end

    local ok, isProtected = pcall(checkFn, bagId, slotIndex)
    return ok and isProtected == true
end

-- Returns a short reason key when the item must not be selected, nil otherwise.
local function GetSkipReason(bagId, slotIndex, kind, sv)
    -- Always skipped: locked items (the in-game padlock)
    if IsItemPlayerLocked(bagId, slotIndex) then
        return "locked"
    end

    -- Always skipped: items protected by FCO ItemSaver
    if IsProtectedByFCOIS(bagId, slotIndex, kind) then
        return "fcois"
    end

    -- Raw materials (Refinement tab): no further rules apply
    if kind == "refinement" then
        return nil
    end

    if sv.skipArmory and IsItemInArmory(bagId, slotIndex) then
        return "armory"
    end

    local quality = GetItemFunctionalQuality(bagId, slotIndex)
    if quality and quality > sv.maxQuality then
        return "quality"
    end

    -- Equipment only (glyphs have neither sets nor traits)
    if kind ~= "enchanting" then
        if sv.skipSetItems then
            local hasSet = GetItemLinkSetInfo(GetItemLink(bagId, slotIndex), false)
            if hasSet then
                return "set"
            end
        end

        local traitInformation = GetItemTraitInformation(bagId, slotIndex)
        if sv.skipResearchable and traitInformation == ITEM_TRAIT_INFORMATION_CAN_BE_RESEARCHED then
            return "research"
        end
        if sv.skipOrnate and traitInformation == ITEM_TRAIT_INFORMATION_ORNATE then
            return "ornate"
        end
    end

    return nil
end

-- Mirrors the checks the game performs in AddItemToCraft() so that we stop
-- *before* the game would show an error alert for every extra item.
local function WouldExceedGameLimits(panel, kind, bagId, slotIndex)
    local slot = panel.extractionSlot
    if slot:GetNumItems() >= GetMaxSlotsPerBatch() then
        return true
    end

    -- Enchanting only limits the number of slotted stacks
    if kind == "enchanting" then
        return false
    end

    -- Smithing / universal: total iterations are limited too (a single oversized stack is allowed when the slot is empty)
    if not slot:HasItems() then
        return false
    end

    local stackPerIteration = 1
    if kind == "refinement" then
        stackPerIteration = GetRequiredSmithingRefinementStackSize()
    end
    local newStackCount = slot:GetStackCount() + zo_max(1, panel.inventory:GetStackCount(bagId, slotIndex))
    return newStackCount > GetMaxIterationsPerBatch() * stackPerIteration
end

local SKIP_ORDER = { "locked", "fcois", "armory", "quality", "set", "research", "ornate" }

local function BuildSkippedText(counters)
    local parts = {}
    for _, key in ipairs(SKIP_ORDER) do
        if counters[key] and counters[key] > 0 then
            parts[#parts + 1] = DSA.L("SKIP_" .. key, counters[key])
        end
    end
    if #parts == 0 then
        return nil
    end
    return table.concat(parts, ", ")
end

-- ---------------------------------------------------------------------------
-- The main action
-- ---------------------------------------------------------------------------
function DSA.SelectAll()
    if ZO_CraftingUtils_IsPerformingCraftProcess() then
        DSA.Msg(DSA.L("BUSY"))
        return
    end

    local panel, kind = GetActiveExtractionPanel()
    if not panel then
        if kind == "gamepad" then
            DSA.Msg(DSA.L("GAMEPAD"))
        else
            DSA.Msg(DSA.L("NO_PANEL"))
        end
        return
    end

    local items = CollectListedItems(panel)
    if #items == 0 then
        DSA.Msg(DSA.L("NOTHING"))
        return
    end

    local sv = DSA.sv or defaults
    local slot = panel.extractionSlot
    local counters = {}
    local added = 0
    local limitHit = false

    -- The game plays a "clink" sound for every slotted item; with 100 items that is unbearable.
    -- ZO_CraftingMultiSlotBase.AddItem is the very same method minus the PlaySound call, so we
    -- shadow the instance's AddItem with it for the duration of the batch and restore it afterwards.
    -- panel:AddItemToCraft() still runs every check the game performs (limits, requirements...).
    slot.AddItem = ZO_CraftingMultiSlotBase.AddItem

    local ok, err = pcall(function()
        for _, item in ipairs(items) do
            local bagId, slotIndex = item.bagId, item.slotIndex
            if not panel:IsSlotted(bagId, slotIndex) then
                local skipReason = GetSkipReason(bagId, slotIndex, kind, sv)
                if skipReason then
                    counters[skipReason] = (counters[skipReason] or 0) + 1
                elseif WouldExceedGameLimits(panel, kind, bagId, slotIndex) then
                    limitHit = true
                elseif panel:CanItemBeAddedToCraft(bagId, slotIndex) then
                    panel:AddItemToCraft(bagId, slotIndex)
                    if panel:IsSlotted(bagId, slotIndex) then
                        added = added + 1
                    end
                end
            end
        end
    end)

    slot.AddItem = nil -- restore the class method (with its sound)

    if not ok then
        error(err)
    end

    if added > 0 then
        if kind == "enchanting" then
            PlaySound(SOUNDS.ENCHANTING_ARMOR_GLYPH_PLACED)
        else
            PlaySound(SOUNDS.SMITHING_ITEM_TO_EXTRACT_PLACED)
        end
    end

    if sv.chatSummary then
        DSA.Msg(DSA.L("RESULT", added, slot:GetNumItems()))
        local skippedText = BuildSkippedText(counters)
        if skippedText then
            DSA.Msg(DSA.L("SKIPPED", skippedText))
        end
        if limitHit then
            DSA.Msg(DSA.L("LIMIT", GetMaxSlotsPerBatch()))
        end
    end
end

-- ---------------------------------------------------------------------------
-- Keybind strip button ("Select all" next to "Deconstruct" / "Clear selections")
-- ---------------------------------------------------------------------------
local function CreateStripButton(visibleFunction)
    return
    {
        name = function()
            return DSA.L("SELECT_ALL")
        end,
        keybind = KEYBIND_ACTION,
        callback = function()
            DSA.SelectAll()
        end,
        visible = visibleFunction,
        enabled = function()
            return not ZO_CraftingUtils_IsPerformingCraftProcess()
        end,
    }
end

local function HookKeybindStrips()
    -- Smithing stations: the descriptor group is (re)added to the strip by the game whenever the scene shows,
    -- and updated on every tab change, so appending our button at load time is enough.
    if SMITHING and SMITHING.keybindStripDescriptor then
        table.insert(SMITHING.keybindStripDescriptor, CreateStripButton(function()
            local mode = SMITHING:GetMode()
            return mode == SMITHING_MODE_DECONSTRUCTION or mode == SMITHING_MODE_REFINEMENT
        end))
    end

    if UNIVERSAL_DECONSTRUCTION and UNIVERSAL_DECONSTRUCTION.keybindStripDescriptor then
        table.insert(UNIVERSAL_DECONSTRUCTION.keybindStripDescriptor, CreateStripButton(function()
            return true
        end))
    end

    if ENCHANTING and ENCHANTING.keybindStripDescriptor then
        table.insert(ENCHANTING.keybindStripDescriptor, CreateStripButton(function()
            return ENCHANTING:GetEnchantingMode() == ENCHANTING_MODE_EXTRACTION
        end))
    end
end

-- ---------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------
local function OnOff(value)
    return value and DSA.L("ON") or DSA.L("OFF")
end

local function QualityName(quality)
    local name = GetString("SI_ITEMQUALITY", quality)
    local color = GetItemQualityColor(quality)
    if color then
        return color:Colorize(name)
    end
    return name
end

local function PrintHelp()
    local sv = DSA.sv
    DSA.Msg(DSA.L("HELP_TITLE", DSA.version))
    DSA.Msg(DSA.L("HELP_SELECT"))
    DSA.Msg(DSA.L("HELP_SETS", OnOff(sv.skipSetItems)))
    DSA.Msg(DSA.L("HELP_RESEARCH", OnOff(sv.skipResearchable)))
    DSA.Msg(DSA.L("HELP_ORNATE", OnOff(sv.skipOrnate)))
    DSA.Msg(DSA.L("HELP_ARMORY", OnOff(sv.skipArmory)))
    DSA.Msg(DSA.L("HELP_QUALITY", QualityName(sv.maxQuality)))
    DSA.Msg(DSA.L("HELP_QUIET", OnOff(sv.chatSummary)))
    DSA.Msg(DSA.L("HELP_KEYBIND"))
end

local function Toggle(settingKey, labelKey)
    DSA.sv[settingKey] = not DSA.sv[settingKey]
    DSA.Msg(DSA.L("SETTING_SET", DSA.L(labelKey), OnOff(DSA.sv[settingKey])))
end

local function OnSlashCommand(args)
    args = args or ""
    local command, rest = args:match("^%s*(%S*)%s*(.-)%s*$")
    command = (command or ""):lower()

    if command == "" or command == "help" then
        PrintHelp()
    elseif command == "select" or command == "all" then
        DSA.SelectAll()
    elseif command == "sets" or command == "set" then
        Toggle("skipSetItems", "OPT_SETS")
    elseif command == "research" then
        Toggle("skipResearchable", "OPT_RESEARCH")
    elseif command == "ornate" then
        Toggle("skipOrnate", "OPT_ORNATE")
    elseif command == "armory" then
        Toggle("skipArmory", "OPT_ARMORY")
    elseif command == "quiet" then
        Toggle("chatSummary", "OPT_QUIET")
    elseif command == "quality" then
        local quality = tonumber(rest)
        local minQuality = ITEM_FUNCTIONAL_QUALITY_NORMAL or 1
        local maxQuality = ITEM_FUNCTIONAL_QUALITY_LEGENDARY or 5
        if quality and quality >= minQuality and quality <= maxQuality then
            DSA.sv.maxQuality = zo_floor(quality)
            DSA.Msg(DSA.L("SETTING_SET", DSA.L("OPT_QUALITY"), QualityName(DSA.sv.maxQuality)))
        else
            DSA.Msg(DSA.L("HELP_QUALITY", QualityName(DSA.sv.maxQuality)))
        end
    else
        PrintHelp()
    end
end

local function InitSlashCommands()
    SLASH_COMMANDS["/dsa"] = OnSlashCommand
    SLASH_COMMANDS["/deconselectall"] = OnSlashCommand
end

-- ---------------------------------------------------------------------------
-- Optional settings panel (LibAddonMenu-2.0, if the player has it)
-- ---------------------------------------------------------------------------
local function InitSettingsMenu()
    local LAM = LibAddonMenu2
    if not LAM then
        return
    end

    local sv = DSA.sv
    local panelName = DSA.name .. "_Options"

    local panelData =
    {
        type = "panel",
        name = DSA.displayName,
        displayName = DSA.displayName,
        author = DSA.author,
        version = DSA.version,
        slashCommand = "/dsaoptions",
        registerForRefresh = true,
        registerForDefaults = true,
    }
    LAM:RegisterAddonPanel(panelName, panelData)

    local qualityChoices, qualityValues = {}, {}
    local minQuality = ITEM_FUNCTIONAL_QUALITY_NORMAL or 1
    local maxQuality = ITEM_FUNCTIONAL_QUALITY_LEGENDARY or 5
    for quality = minQuality, maxQuality do
        qualityChoices[#qualityChoices + 1] = QualityName(quality)
        qualityValues[#qualityValues + 1] = quality
    end

    local optionsTable =
    {
        {
            type = "description",
            text = DSA.L("OPT_DESC"),
        },
        {
            type = "checkbox",
            name = DSA.L("OPT_SETS"),
            tooltip = DSA.L("OPT_SETS_TT"),
            getFunc = function() return sv.skipSetItems end,
            setFunc = function(value) sv.skipSetItems = value end,
            default = defaults.skipSetItems,
        },
        {
            type = "checkbox",
            name = DSA.L("OPT_RESEARCH"),
            tooltip = DSA.L("OPT_RESEARCH_TT"),
            getFunc = function() return sv.skipResearchable end,
            setFunc = function(value) sv.skipResearchable = value end,
            default = defaults.skipResearchable,
        },
        {
            type = "checkbox",
            name = DSA.L("OPT_ORNATE"),
            tooltip = DSA.L("OPT_ORNATE_TT"),
            getFunc = function() return sv.skipOrnate end,
            setFunc = function(value) sv.skipOrnate = value end,
            default = defaults.skipOrnate,
        },
        {
            type = "checkbox",
            name = DSA.L("OPT_ARMORY"),
            tooltip = DSA.L("OPT_ARMORY_TT"),
            getFunc = function() return sv.skipArmory end,
            setFunc = function(value) sv.skipArmory = value end,
            default = defaults.skipArmory,
        },
        {
            type = "dropdown",
            name = DSA.L("OPT_QUALITY"),
            tooltip = DSA.L("OPT_QUALITY_TT"),
            choices = qualityChoices,
            choicesValues = qualityValues,
            getFunc = function() return sv.maxQuality end,
            setFunc = function(value) sv.maxQuality = value end,
            default = defaults.maxQuality,
        },
        {
            type = "checkbox",
            name = DSA.L("OPT_QUIET"),
            tooltip = DSA.L("OPT_QUIET_TT"),
            getFunc = function() return sv.chatSummary end,
            setFunc = function(value) sv.chatSummary = value end,
            default = defaults.chatSummary,
        },
    }
    LAM:RegisterOptionControls(panelName, optionsTable)
end

-- ---------------------------------------------------------------------------
-- Initialisation
-- ---------------------------------------------------------------------------
local function OnAddOnLoaded(eventCode, addOnName)
    if addOnName ~= DSA.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(DSA.name, EVENT_ADD_ON_LOADED)

    DSA.sv = ZO_SavedVars:NewAccountWide(DSA.savedVarsName, 1, nil, defaults)

    HookKeybindStrips()
    InitSlashCommands()
    InitSettingsMenu()
end

EVENT_MANAGER:RegisterForEvent(DSA.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
