--------------------------------------------------------------------
--  AutoInteract.lua  –  v1.8.6  (April 01 2026)					  --
--------------------------------------------------------------------

AutoInteract          = AutoInteract or {}
AutoInteract.Name     = "AutoInteract"
AutoInteract.Version  = "1.8.5"
AutoInteract.IsPaused = false

local EM = EVENT_MANAGER
--------------------------------------------------------------------
-- Debug helper: only prints when Debug Mode is on			      --
--------------------------------------------------------------------
function AutoInteract:Debug(fmt, ...)
    if self.SavedVariables.DebugMode then
        d(("|c88ccff[AI]|r" .. fmt):format(...))
    end
end

--------------------------------------------------------------------
--  Keybinds                                                      --
--------------------------------------------------------------------

BINDING_HEADER_AUTOINTERACT = "AutoInteract"
function AutoInteract.InitializeKeybinds()
    ZO_CreateStringId(
      "SI_BINDING_NAME_AUTOINTERACT_TOGGLE_ENABLED",
      "Toggle AutoInteract"
    )
    BINDING_NAME_AUTOINTERACT_TOGGLE_ENABLED = "AutoInteract.ToggleMaster"
end


function AutoInteract.ToggleMaster()
    local SV = AutoInteract.SavedVariables
    SV.Enabled = not SV.Enabled
    CHAT_SYSTEM:AddMessage(
      (" %s"):format(SV.Enabled and "Enabled" or "Disabled")
    )
end

--------------------------------------------------------------------
--  Helper utils                                                  --
--------------------------------------------------------------------

local function IsConsole()
    local p = GetUIPlatform()
    return p == UI_PLATFORM_XBOX or p == UI_PLATFORM_PS4 or p == UI_PLATFORM_PS5
end
AutoInteract.IsConsole = IsConsole

function AutoInteract.QuestOffered(eventCode, questIndex)
    if type(GetNumChatterOptions) ~= "function" then return end
    local oc = GetNumChatterOptions()
    AutoInteract.ChatterBegin(eventCode, oc)
end

function AutoInteract.ToggleDialogues()
    local sv = AutoInteract.SavedVariables
    sv.SkipDialogues = not sv.SkipDialogues
    AutoInteract:Debug( string.format("AutoInteract %s", sv.SkipDialogues and "enabled" or "disabled") )
end

--------------------------------------------------------------------
--  Saved-variable bootstrap                                      --
--------------------------------------------------------------------

function AutoInteract.InitSavedVariables()
    local defaults = {
        SkipDialogues           = true,
        SkipBooks               = true,
        SkipImportantChoices    = false,
        DebugMode               = false,
        UseWritDetection        = true,
        KeywordBlacklist        = {},
        UseHardModeDetection    = true,
        UseCostDetection        = true,
        AutoBindSetItems        = false,
        AutoLearnCollectibles   = false,
		AutoMarkJunkItems       = false,
		AutoSellJunkOnMerchant  = false,
		Enabled                 = true,    -- master on/off switch
    }
    AutoInteract.SavedVariables = ZO_SavedVars:NewCharacterIdSettings(
        "AutoInteractVars", 2, nil, defaults
    )
end

--------------------------------------------------------------------
--  Crafting writ detection                                       --
--------------------------------------------------------------------

local DUMMY_ITEM_LINK = "|H1:item:45850:20:1:0:0:0:0:0|h|h" -- Mundane Rune

local _probeUsable
local function ProbeHelper()
    if _probeUsable ~= nil then return end
    local probe = DoesItemLinkFulfillJournalQuestCondition
    if type(probe) == "function" then
        local ok = pcall(function()
            return probe(DUMMY_ITEM_LINK, 1, 1, 1)
        end)
        _probeUsable = ok
    else
        _probeUsable = false
    end
end

local writDirty   = true
local writPresent = false

local function MarkWritDirty()
    writDirty = true
end

local journalEvents = {
    EVENT_QUEST_ADDED,
    EVENT_QUEST_REMOVED,
    EVENT_QUEST_LIST_UPDATED,
    EVENT_QUEST_CONDITION_COUNTER_CHANGED,
}
for _, e in ipairs(journalEvents) do
    EM:RegisterForEvent("AutoInteract_WritDirty", e, MarkWritDirty)
end

local function ExpensiveWritScan()
    ProbeHelper()
    local useProbe = _probeUsable
    local probeFn  = useProbe and DoesItemLinkFulfillJournalQuestCondition or nil

    for qi = 1, GetNumJournalQuests() do
        if IsValidQuestIndex(qi)
        and GetJournalQuestType(qi) == QUEST_TYPE_CRAFTING
        and not GetJournalQuestIsComplete(qi) then
            if not useProbe then return true end
            local steps = GetJournalQuestNumSteps(qi)

            for si = 1, steps do
                local conds = GetJournalQuestNumConditions(qi, si)
                for ci = 1, conds do
                    local _,_,_,_, done = GetJournalQuestConditionInfo(qi, si, ci)
                    if not done and type(probeFn) == "function" then
                        local ok, fulfills = pcall(probeFn, DUMMY_ITEM_LINK, qi, si, ci)
                        if ok and fulfills then return true end
                    end
                end
            end
            return true
        end
    end
    return false
end

local function HasActiveCraftingWrit()
    if writDirty then
        writPresent = ExpensiveWritScan()
        writDirty   = false
    end
    return writPresent
end

--------------------------------------------------------------------
--  Misc helpers                                                  --
--------------------------------------------------------------------

function AutoInteract.SafeGetOptionCurrency(i)
    if type(GetChatterOptionCurrency) == "function" then
        return GetChatterOptionCurrency(i)
    end
    return false, nil, 0
end

--------------------------------------------------------------------
--  Book interaction                                              --
--------------------------------------------------------------------

function AutoInteract.ShowBook()
    if AutoInteract.IsPaused then return end
	if not AutoInteract.SavedVariables.Enabled then return end
    if AutoInteract.SavedVariables.SkipBooks then EndInteraction(INTERACTION_BOOK) end
end

--------------------------------------------------------------------
--  Dialogue skipping & pause logic                               --
--------------------------------------------------------------------

local function ShouldPauseInteraction(optCount)
    local SV = AutoInteract.SavedVariables
	if not AutoInteract.SavedVariables.Enabled then return end
    if SV.UseWritDetection and HasActiveCraftingWrit() then
        if SV.DebugMode and not IsConsole() then
            AutoInteract:Debug("crafting writ detected → pause")
        end
        return true
    end

local function InVet()
    if type(IsUnitInDungeon) ~= "function"
    or type(GetCurrentDifficultySetting) ~= "function" then
        return false
    end

    return IsUnitInDungeon("player")
       and GetCurrentDifficultySetting() == DUNGEON_DIFFICULTY_VETERAN
end


    for i = 1, optCount do
        local txt = GetChatterOption(i)
        if txt then
            local lower = txt:lower()
            for _, kw in ipairs(SV.KeywordBlacklist) do
                if kw ~= "" and lower:find(kw:lower(), 1, true) then
                    if SV.DebugMode and not IsConsole() then
                        AutoInteract:Debug("keyword ‘" .. kw .. "’ → pause")
                    end
                    return true
                end
            end
            if SV.UseHardModeDetection and InVet() then
                if lower:find("hard",1,true) or lower:find("suffer",1,true) or lower:find("prove",1,true) then
                    if SV.DebugMode and not IsConsole() then AutoInteract:Debug("hard-mode string → pause") end
                    return true
                end
            end
        end
        if SV.UseCostDetection then
            local cost, _, amt = AutoInteract.SafeGetOptionCurrency(i)
            if cost and amt > 0 then
                if SV.DebugMode and not IsConsole() then
                    AutoInteract:Debug(string.format("option %d costs %d → pause", i, amt))
                end
                return true
            end
        end
    end
    return false
end

function AutoInteract.ConversationUpdated(_, _, oc) AutoInteract.ChatterBegin(_, oc) end

function AutoInteract.ChatterBegin(_, oc)
    if not AutoInteract.SavedVariables then return end
	if not AutoInteract.SavedVariables.Enabled then return end
    if ShouldPauseInteraction(oc) then
        AutoInteract.IsPaused = true
        return
    end

    local SV = AutoInteract.SavedVariables
    local allChosen, special = true, nil

    for i = 1, oc do
        local txt, typ, _, imp, chosen = GetChatterOption(i)
        allChosen = allChosen and chosen
        if SV.SkipDialogues and not chosen and (txt:sub(1,10)=="[Persuade]" or txt:sub(1,11)=="[Intimidate]") then
            special = special or i
        end
    end

    if special then
        if SV.DebugMode and not IsConsole() then AutoInteract:Debug("picked special option") end
        SelectChatterOption(special) return end

    for i = 1, oc do
        local txt, typ,_, imp, chosen = GetChatterOption(i)
        if SV.SkipDialogues and not chosen and ((not imp) or SV.SkipImportantChoices) and AutoInteract.OptionsWhitelist[typ] then
            SelectChatterOption(i) return end
    end

    if SV.SkipDialogues and allChosen then EndInteraction(INTERACTION_CONVERSATION)
    end
end

function AutoInteract.QuestComplete()
    if AutoInteract.IsPaused then return end
	if not AutoInteract.SavedVariables.Enabled then return end
    if AutoInteract.SavedVariables.SkipDialogues then CompleteQuest() end
end

--------------------------------------------------------------------
--  Interaction end                                               --
--------------------------------------------------------------------

function AutoInteract.OnChatterEnd()
    if AutoInteract.IsPaused then
	if not AutoInteract.SavedVariables.Enabled then return end
        AutoInteract.IsPaused = false
        if AutoInteract.SavedVariables.DebugMode and not IsConsole() then AutoInteract:Debug("unpaused") end
    end
end


--------------------------------------------------------------------
-- Auto-bind & auto-learn 									      --
--------------------------------------------------------------------
-- Queue protected calls when ESO blocks them (typically combat lockdown)
local unpack = unpack or table.unpack
local pendingSecureCalls = {}

local function FlushPendingSecureCalls()
    if #pendingSecureCalls == 0 then return end

    local remaining = {}
    for i = 1, #pendingSecureCalls do
        local entry = pendingSecureCalls[i]
        local ok = CallSecureProtected(entry.funcName, unpack(entry.args))
        if ok then
            if AutoInteract.SavedVariables and AutoInteract.SavedVariables.DebugMode then
                AutoInteract:Debug("Flushed queued secure call: %s", entry.link or entry.funcName)
            end
        else
            remaining[#remaining + 1] = entry
        end
    end

    pendingSecureCalls = remaining
end

local function QueueSecureProtectedCall(funcName, ...)
    local args = { ... }
    local ok = CallSecureProtected(funcName, unpack(args))
    if ok then
        return true, false
    end

    pendingSecureCalls[#pendingSecureCalls + 1] = {
        funcName = funcName,
        args = args,
        link = GetItemLink(args[1], args[2]),
    }
    return false, true
end

local function OnPlayerCombatState(_, inCombat)
    if not inCombat then
        FlushPendingSecureCalls()
    end
end

-- Inventory update handler
local function OnInventorySlotUpdate(eventCode, bagId, slotIndex, isNewItem, soundCategory, updateReason)
    local SV = AutoInteract.SavedVariables
    if not SV.Enabled
    or not (SV.AutoBindSetItems or SV.AutoLearnCollectibles)
    or bagId == BAG_VIRTUAL then
        return
    end

    local isFresh = isNewItem or updateReason == ITEM_UPDATE_REASON_DEFAULT
    if not isFresh then return end

    local link = GetItemLink(bagId, slotIndex)
    if not link then return end

    -- Auto-bind set pieces
	if SV.AutoBindSetItems then
		local hasSet, setName, numBonuses, numEquipped, maxEquipped, setId
		= GetItemLinkSetInfo(link, false)
		if hasSet and setId > 0 and not IsItemBound(bagId, slotIndex) then
			local ok, queued = QueueSecureProtectedCall("UseItem", bagId, slotIndex)
			if ok then
				AutoInteract:Debug("Bound set item: %s", link)
			elseif queued and SV.DebugMode then
				AutoInteract:Debug("Bind queued (lockdown): %s", link)
			end
		elseif SV.DebugMode and hasSet and setId > 0 then
			AutoInteract:Debug("Skipped bind (already bound): %s", link)
	end
end

    -- Auto-learn collectibles
	if SV.AutoLearnCollectibles then
		local itemType, specializedType = GetItemLinkItemType(link)

		local specializedRecipes = {
			[SPECIALIZED_ITEMTYPE_RECIPE_ALCHEMY_FORMULA_FURNISHING]        = true,
			[SPECIALIZED_ITEMTYPE_RECIPE_BLACKSMITHING_DIAGRAM_FURNISHING]  = true,
			[SPECIALIZED_ITEMTYPE_RECIPE_CLOTHIER_PATTERN_FURNISHING]       = true,
			[SPECIALIZED_ITEMTYPE_RECIPE_ENCHANTING_SCHEMATIC_FURNISHING]    = true,
			[SPECIALIZED_ITEMTYPE_RECIPE_JEWELRYCRAFTING_SKETCH_FURNISHING]  = true,
			[SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_DESIGN_FURNISHING]    = true,
			[SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_FOOD]        = true,
			[SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_DRINK]       = true,
			[SPECIALIZED_ITEMTYPE_RECIPE_WOODWORKING_BLUEPRINT_FURNISHING]  = true,
			[SPECIALIZED_ITEMTYPE_TROPHY_COLLECTIBLE_FRAGMENT]             = true,
			[SPECIALIZED_ITEMTYPE_TROPHY_RECIPE_FRAGMENT]                  = true,
			[SPECIALIZED_ITEMTYPE_TROPHY_RUNEBOX_FRAGMENT]                 = true,
			[SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_BOOK]                 = true,
			[SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_CHAPTER]              = true,
		}

		local isRecipePage = (itemType == ITEMTYPE_RECIPE)
					or (itemType == ITEMTYPE_RECIPE_FRAGMENT)
					or specializedRecipes[specializedType]

		if isRecipePage then
			if not IsItemLinkRecipeKnown(link) then
            local ok, queued = QueueSecureProtectedCall("UseItem", bagId, slotIndex)
				if ok then
					AutoInteract:Debug("Learned collectible: %s", link)
				elseif queued and SV.DebugMode then
					AutoInteract:Debug("Learn attempt queued (lockdown): %s", link)
				end
			elseif SV.DebugMode then
				AutoInteract:Debug("Skipped known recipe: %s", link)
			end
		end
	end
end

--------------------------------------------------------------------
--  Whitelist for chatter option types                            --
--------------------------------------------------------------------

AutoInteract.OptionsWhitelist = {
    [CHATTER_START_TALK]               = true,
    [CHATTER_TALK_CHOICE]              = true,
    [CHATTER_START_NEW_QUEST_BESTOWAL] = true,
    [CHATTER_START_COMPLETE_QUEST]     = true,
}

--------------------------------------------------------------------
--Auto-mark junk on pickup (incl. stolen), excluding launderables --
--------------------------------------------------------------------
local LAUNDERABLE_TYPES = {
    ITEMTYPE_LOCKPICKS,
    ITEMTYPE_SOUL_GEM,
    ITEMTYPE_CRAFTING_MATERIAL,
    ITEMTYPE_FURNISHING_MATERIAL,
    ITEMTYPE_RECIPE,
    ITEMTYPE_RECIPE_FRAGMENT,
    ITEMTYPE_SURVEY_REPORT,
    ITEMTYPE_TREASURE_MAP,
    ITEMTYPE_STYLE_MATERIAL,
    ITEMTYPE_DISGUISE_STYLE,
    ITEMTYPE_ARMORY_SCENE,
    ITEMTYPE_MASTER_WRIT,
}
local LAUNDERABLE = {}
for _, t in ipairs(LAUNDERABLE_TYPES) do
    if t then LAUNDERABLE[t] = true end
end

local function OnInventorySlotUpdate_Junk(event, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason)
    local SV = AutoInteract.SavedVariables
	if not AutoInteract.SavedVariables.Enabled then return end
    if not SV.AutoMarkJunkItems then return end

    if bagId ~= BAG_BACKPACK then return end

    if not isNewItem then return end

    local link = GetItemLink(bagId, slotIndex) or "<no-link>"
    local itemType = GetItemType(bagId, slotIndex)

AutoInteract:Debug("New pickup: %s  (type=%d, reason=%d)", link, itemType, updateReason)

    if LAUNDERABLE[itemType] then
        AutoInteract:Debug("Excluding launderable type %d",itemType)
        return
    end

    local quality   = GetItemQuality(bagId, slotIndex)
    local traitType = select(1, GetItemLinkTraitInfo(link))
    local isPoor      = (quality == ITEM_QUALITY_POOR)
    local isTrash     = (itemType == ITEMTYPE_TRASH)
    local isTreasure  = (itemType == ITEMTYPE_TREASURE)
    local isTrophy    = (itemType == ITEMTYPE_TROPHY)
    local isOrnate    = (traitType == ITEM_TRAIT_TYPE_ORNATE)


    if not IsItemJunk(bagId, slotIndex)
    and ( isPoor or isTrash or isTreasure or isTrophy or isOrnate )
    then
        SetItemIsJunk(bagId, slotIndex, true)
		AutoInteract:Debug("Marked junk: %s", link)

    end
end

--------------------------------------------------------------------
--  Auto-sell junk items when interacting with a merchant		  --
--------------------------------------------------------------------
local function OnOpenStore_AutoSellJunk(_, storeType)
    local SV = AutoInteract.SavedVariables
	if not AutoInteract.SavedVariables.Enabled then return end
    if not SV.AutoSellJunkOnMerchant then return end

    for slotIndex = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if IsItemJunk(BAG_BACKPACK, slotIndex) then
            local stackSize = GetSlotStackSize(BAG_BACKPACK, slotIndex)
            SellInventoryItem(BAG_BACKPACK, slotIndex, stackSize)
        end
    end
    AutoInteract:Debug("Sold all junk items")
end

--------------------------------------------------------------------
--  Event hookup & finalisation                                   --
--------------------------------------------------------------------

function AutoInteract.OnAddOnLoaded(_, addon)
  if addon ~= "MyUI" then return end
  AutoInteract.InitSavedVariables()
  if AutoInteract.LoadLocalization then AutoInteract.LoadLocalization() end
  if AutoInteract.InitSettings     then AutoInteract.InitSettings()     end
  AutoInteract.InitializeKeybinds()

  EM:RegisterForEvent(AutoInteract.Name, EVENT_QUEST_OFFERED,         AutoInteract.QuestOffered)
  EM:RegisterForEvent(AutoInteract.Name, EVENT_QUEST_COMPLETE_DIALOG, AutoInteract.QuestComplete)
  EM:RegisterForEvent(AutoInteract.Name, EVENT_CHATTER_BEGIN,         AutoInteract.ChatterBegin)
  EM:RegisterForEvent(AutoInteract.Name, EVENT_CHATTER_END,           AutoInteract.OnChatterEnd)
  EM:RegisterForEvent(AutoInteract.Name, EVENT_CONVERSATION_UPDATED,  AutoInteract.ConversationUpdated)
  EM:RegisterForEvent(AutoInteract.Name .. "_ShowBook", EVENT_SHOW_BOOK, AutoInteract.ShowBook)

  EM:RegisterForEvent(AutoInteract.Name .. "_InventoryAutoUse", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventorySlotUpdate)
  EM:AddFilterForEvent(AutoInteract.Name .. "_InventoryAutoUse", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_IS_NEW_ITEM, true)

  EM:RegisterForEvent(AutoInteract.Name .. "_InventoryJunk", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventorySlotUpdate_Junk)
  EM:AddFilterForEvent(AutoInteract.Name .. "_InventoryJunk", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_IS_NEW_ITEM, true)
  EM:AddFilterForEvent(AutoInteract.Name .. "_InventoryJunk", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)

  EM:RegisterForEvent(AutoInteract.Name .. "_OpenStore", EVENT_OPEN_STORE, OnOpenStore_AutoSellJunk)
  EM:RegisterForEvent(AutoInteract.Name .. "_CombatState", EVENT_PLAYER_COMBAT_STATE, OnPlayerCombatState)

  EM:UnregisterForEvent(AutoInteract.Name, EVENT_ADD_ON_LOADED)
end

EM:RegisterForEvent("AutoInteract", EVENT_ADD_ON_LOADED, AutoInteract.OnAddOnLoaded)