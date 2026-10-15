-- Select eligible gear at deconstruction assistants and crafting stations. This module
-- never starts a crafting process or clears the player's manual selections.
local addon = ASJ
local NAMESPACE = addon.addOnName .. "_Deconstruction"
local PREFIX = "|cE5C07BASJ|r "
local SELECT_KEYBIND = "UI_SHORTCUT_QUINARY" -- Hold Y / Hold Triangle
local METICULOUS_DISASSEMBLY_ID = 83
local EXTRACTION_ABILITIES = {
    [CRAFTING_TYPE_BLACKSMITHING] = 48165, -- Metal Extraction
    [CRAFTING_TYPE_CLOTHIER] = 48195, -- Unraveling
    [CRAFTING_TYPE_WOODWORKING] = 48180, -- Wood Extraction
}
local stationStates = {}

local function Announce(message)
    if type(d) == "function" then d(PREFIX .. "Select eligible: " .. message) end
end

local function IsMeticulousDisassemblyActive()
    local points = GetNumPointsSpentOnChampionSkill(METICULOUS_DISASSEMBLY_ID)
    local maxPoints = GetChampionSkillMaxPoints(METICULOUS_DISASSEMBLY_ID)
    if type(points) ~= "number" or type(maxPoints) ~= "number" or maxPoints <= 0
            or points < maxPoints then
        return false
    end

    local skillType = GetChampionSkillType(METICULOUS_DISASSEMBLY_ID)
    -- Since Update 45, this is a passive: purchased points activate it.
    if skillType == CHAMPION_SKILL_TYPE_NORMAL then return true end
    if not skillType or not CanChampionSkillTypeBeSlotted(skillType) then return false end

    -- Also respect the actual bar if a client makes this star slottable.
    local firstSlot, lastSlot = GetAssignableChampionBarStartAndEndSlots()
    if type(firstSlot) ~= "number" or type(lastSlot) ~= "number" then return false end
    for slot = firstSlot, lastSlot do
        if GetSlotBoundId(slot, HOTBAR_CATEGORY_CHAMPION) == METICULOUS_DISASSEMBLY_ID then
            return true
        end
    end
    return false
end

local function HasMaximumExtraction(abilityId)
    local skillType, skillLineIndex, skillIndex = GetSpecificSkillAbilityKeysByAbilityId(abilityId)
    if skillType ~= SKILL_TYPE_TRADESKILL or type(skillLineIndex) ~= "number" or skillLineIndex <= 0
            or type(skillIndex) ~= "number" or skillIndex <= 0 then
        return false
    end
    local _, _, _, passive, _, purchased = GetSkillAbilityInfo(skillType, skillLineIndex, skillIndex)
    local currentRank, maxRank = GetSkillAbilityUpgradeInfo(skillType, skillLineIndex, skillIndex)
    return passive == true and purchased == true and type(currentRank) == "number"
        and type(maxRank) == "number" and maxRank > 0 and currentRank == maxRank
end

local function SelectEligible(state)
    if not state.active or ZO_CraftingUtils_IsPerformingCraftProcess() then return end
    local stationCraft = state.station and GetCraftingInteractionType() or nil
    if state.station and not EXTRACTION_ABILITIES[stationCraft] then return end
    -- An explicit request supersedes a queued automatic request for this visit.
    state.selectionRequested = true
    if state.station then
        -- Switching between keyboard and gamepad is still the same station visit.
        for _, stationState in ipairs(stationStates) do stationState.selectionRequested = true end
    end
    if not IsMeticulousDisassemblyActive() then
        Announce("Meticulous Disassembly is not active. Unlock it before selecting items.")
        return
    end

    local panel = state.panel
    local inventory = panel.inventory
    inventory:PerformFullRefresh()

    -- Use the native filtered list, including bank/category/add-on filters.
    -- Snapshot bag/slot pairs because adding a selection can rebuild the list.
    local entries = state.gamepad and inventory.list.dataList or ZO_ScrollList_GetDataList(inventory.list)
    local candidates = {}
    for _, entry in ipairs(entries) do
        local data = state.gamepad and entry or entry.data
        if data and data.bagId ~= nil and data.slotIndex ~= nil then
            candidates[#candidates + 1] = {bagId = data.bagId, slotIndex = data.slotIndex}
        end
    end

    -- Refresh purchased ranks on every request, including after Armory changes.
    local maxedCrafts = {}
    for craftingType, abilityId in pairs(EXTRACTION_ABILITIES) do
        maxedCrafts[craftingType] = HasMaximumExtraction(abilityId)
    end

    local selected, alreadySelected, remaining = 0, 0, 0
    local skipped = {crafted = 0, extraction = 0, discipline = 0, unavailable = 0}
    local slot = panel.extractionSlot
    for _, candidate in ipairs(candidates) do
        local bagId, slotIndex = candidate.bagId, candidate.slotIndex
        if not state.active or ZO_CraftingUtils_IsPerformingCraftProcess() then break end
        if slot:ContainsBagAndSlot(bagId, slotIndex) then
            alreadySelected = alreadySelected + 1
        elseif (bagId ~= BAG_BACKPACK and bagId ~= BAG_BANK and bagId ~= BAG_SUBSCRIBER_BANK)
                or IsItemPlayerLocked(bagId, slotIndex) or not CanItemBeDeconstructed(bagId, slotIndex, stationCraft) then
            skipped.unavailable = skipped.unavailable + 1
        else
            local itemLink = GetItemLink(bagId, slotIndex)
            -- Protect daily writ gear regardless of its crafter, bag, or skills.
            -- Only add items positively identified as not player-crafted.
            local isCrafted
            if itemLink ~= "" and type(IsItemLinkCrafted) == "function" then
                isCrafted = IsItemLinkCrafted(itemLink)
            end
            local craftingType = itemLink ~= "" and GetItemLinkCraftingSkillType(itemLink) or nil
            if isCrafted == true then
                skipped.crafted = skipped.crafted + 1
            elseif isCrafted ~= false then
                skipped.unavailable = skipped.unavailable + 1
            elseif not EXTRACTION_ABILITIES[craftingType] then
                skipped.discipline = skipped.discipline + 1
            elseif not maxedCrafts[craftingType] then
                skipped.extraction = skipped.extraction + 1
            else
                local stackCount = math.max(1, inventory:GetStackCount(bagId, slotIndex))
                if slot:GetNumItems() >= MAX_ITEM_SLOTS_PER_DECONSTRUCTION
                        or slot:GetStackCount() + stackCount > MAX_ITERATIONS_PER_DECONSTRUCTION then
                    remaining = remaining + 1
                else
                    panel:AddItemToCraft(bagId, slotIndex)
                    if slot:ContainsBagAndSlot(bagId, slotIndex) then
                        selected = selected + 1
                    else
                        skipped.unavailable = skipped.unavailable + 1
                    end
                end
            end
        end
    end

    local details = {}
    if alreadySelected > 0 then details[#details + 1] = alreadySelected .. " already selected" end
    if skipped.crafted > 0 then details[#details + 1] = skipped.crafted .. " skipped: player-crafted" end
    if skipped.extraction > 0 then details[#details + 1] = skipped.extraction .. " skipped: extraction passive not maxed" end
    if skipped.discipline > 0 then details[#details + 1] = skipped.discipline .. " skipped: other crafting disciplines" end
    if skipped.unavailable > 0 then details[#details + 1] = skipped.unavailable .. " skipped: locked or unavailable" end
    if remaining > 0 then details[#details + 1] = remaining .. " eligible remain: selection limit reached" end
    Announce(string.format("Selected %d items%s.", selected, #details > 0 and "; " .. table.concat(details, "; ") or ""))
end

local function SetupSelectionView(panel, gamepad, scene, station)
    if not panel or (not scene and not panel.control) then return end
    local state = {panel = panel, gamepad = gamepad, station = station, visit = 0}
    local keybind = {
        alignment = KEYBIND_STRIP_ALIGN_RIGHT,
        name = "Select eligible",
        keybind = SELECT_KEYBIND,
        gamepadOrder = 1030,
        callback = function() SelectEligible(state) end,
        enabled = function() return state.active and not ZO_CraftingUtils_IsPerformingCraftProcess() end,
    }

    local function OnShown()
        if state.active or (station and not EXTRACTION_ABILITIES[GetCraftingInteractionType()]) then return end
        state.visit = state.visit + 1
        state.active = true
        -- A station's tab changes must not restart automatic selection during
        -- the same crafting interaction. Assistants reset on a new scene visit.
        if not station then state.selectionRequested = false end

        -- Own the button separately from ESO's descriptors and never replace
        -- an existing action, including a gamepad-preferred alias.
        local preferredKeybinds = KEYBIND_STRIP.keybindsByGamepadPreferredKeybind
        if not KEYBIND_STRIP:HasKeybindButton(keybind)
                and not (preferredKeybinds and preferredKeybinds[SELECT_KEYBIND]) then
            KEYBIND_STRIP:AddKeybindButton(keybind)
            state.keybindAdded = true
        else
            Announce("the shortcut is already in use; its existing action was kept.")
        end

        if addon.savedVars.asjAutoSelectDeconstruction and not state.selectionRequested then
            local visit = state.visit
            zo_callLater(function()
                if state.active and state.visit == visit and not state.selectionRequested
                        and addon.savedVars.asjAutoSelectDeconstruction then
                    SelectEligible(state)
                end
            end, 0)
        end
    end

    local function OnHidden()
        state.active = false
        state.visit = state.visit + 1 -- Invalidate a queued selection on close.
        if state.keybindAdded then
            KEYBIND_STRIP:RemoveKeybindButton(keybind)
            state.keybindAdded = false
        end
    end

    if scene then
        scene:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_SHOWN then
                OnShown()
            elseif newState == SCENE_HIDING or newState == SCENE_HIDDEN then
                OnHidden()
            end
        end)
    else
        -- Keyboard stations share one scene across crafting tabs. Effective
        -- visibility follows the deconstruction tab and ancestor scene changes.
        ZO_PostHookHandler(panel.control, "OnEffectivelyShown", OnShown)
        ZO_PostHookHandler(panel.control, "OnEffectivelyHidden", OnHidden)
    end
    if station then
        state.hide = OnHidden
        stationStates[#stationStates + 1] = state
    end

    local function RefreshKeybind()
        local button = KEYBIND_STRIP.keybinds[SELECT_KEYBIND]
        local owner = button and (button.keybindButtonDescriptor or button)
        -- ESO's UpdateKeybindButton can replace a different owner. Do not steal
        -- the shortcut back if another add-on claimed it after the scene opened.
        if state.active and state.keybindAdded and owner == keybind then
            KEYBIND_STRIP:UpdateKeybindButton(keybind)
        end
    end
    CALLBACK_MANAGER:RegisterCallback("CraftingAnimationsStarted", RefreshKeybind)
    CALLBACK_MANAGER:RegisterCallback("CraftingAnimationsStopped", RefreshKeybind)
end

local function OnAddonLoaded(_, name)
    if name ~= addon.addOnName then return end
    EVENT_MANAGER:UnregisterForEvent(NAMESPACE, EVENT_ADD_ON_LOADED)
    if UNIVERSAL_DECONSTRUCTION_GAMEPAD then
        SetupSelectionView(UNIVERSAL_DECONSTRUCTION_GAMEPAD.deconstructionPanel, true, UNIVERSAL_DECONSTRUCTION_GAMEPAD.scene)
    end
    if UNIVERSAL_DECONSTRUCTION then
        SetupSelectionView(UNIVERSAL_DECONSTRUCTION.deconstructionPanel, false, UNIVERSAL_DECONSTRUCTION.scene)
    end
    if SMITHING_GAMEPAD and GAMEPAD_SMITHING_DECONSTRUCT_SCENE then
        SetupSelectionView(SMITHING_GAMEPAD.deconstructionPanel, true, GAMEPAD_SMITHING_DECONSTRUCT_SCENE, true)
    end
    if SMITHING then SetupSelectionView(SMITHING.deconstructionPanel, false, nil, true) end

    EVENT_MANAGER:RegisterForEvent(NAMESPACE .. "_StationStart", EVENT_CRAFTING_STATION_INTERACT, function()
        for _, state in ipairs(stationStates) do state.selectionRequested = false end
    end)
    EVENT_MANAGER:RegisterForEvent(NAMESPACE .. "_StationEnd", EVENT_END_CRAFTING_STATION_INTERACT, function()
        for _, state in ipairs(stationStates) do
            state.hide()
            state.selectionRequested = false
        end
    end)
end

EVENT_MANAGER:RegisterForEvent(NAMESPACE, EVENT_ADD_ON_LOADED, OnAddonLoaded)
