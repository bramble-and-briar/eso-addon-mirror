InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- ARMORY group: ARMORY > loadout > set > items, built from the game's Armory builds.
-- Items show here in addition to their normal group, as extra rows that share the real slot data
-- through a proxy (so each row keeps its own layout info). Pieces you're wearing come from the
-- worn bag and act like the character window's equipment slots (right click: unequip...).

local SKIPPED_EQUIP_SLOTS = {}
for _, name in ipairs({ "EQUIP_SLOT_COSTUME", "EQUIP_SLOT_POISON", "EQUIP_SLOT_BACKUP_POISON" }) do
    if _G[name] ~= nil then SKIPPED_EQUIP_SLOTS[_G[name]] = true end
end

-- Worn pieces aren't part of any inventory; this stands in for the inventory the row setup expects.
local WORN_INVENTORY = { slotType = SLOT_TYPE_EQUIPMENT }

local OTHER_GEAR_NODE = { id = "other", label = "Other Gear", color = "B5B5B5", icon = "EsoUI/Art/Inventory/inventory_tabIcon_armor_up.dds" }

local function BuildName(buildIndex)
    local buildData = ZO_ARMORY_MANAGER and ZO_ARMORY_MANAGER:GetBuildDataByIndex(buildIndex)
    if buildData then return buildData:GetName() end
    local name = GetArmoryBuildName(buildIndex)
    return name ~= "" and name or string.format("Loadout %d", buildIndex)
end

-- The icon the player picked for a loadout. The game has moved this around between versions, so
-- every known way of asking is tried and the group's own icon stands in if none of them answers.
local DEFAULT_LOADOUT_ICON = "EsoUI/Art/Armory/buildItem_icon.dds"

local function BuildIcon(buildIndex)
    local buildData = ZO_ARMORY_MANAGER and ZO_ARMORY_MANAGER.GetBuildDataByIndex
        and ZO_ARMORY_MANAGER:GetBuildDataByIndex(buildIndex)
    local candidates = {
        buildData and buildData.GetIcon and function() return buildData:GetIcon() end,
        buildData and buildData.GetIconIndex and ZO_ARMORY_MANAGER.GetBuildIcon
            and function() return ZO_ARMORY_MANAGER:GetBuildIcon(buildData:GetIconIndex()) end,
        GetArmoryBuildIcon and function() return GetArmoryBuildIcon(buildIndex) end,
        GetArmoryBuildIconIndex and ZO_ARMORY_MANAGER and ZO_ARMORY_MANAGER.GetBuildIcon
            and function() return ZO_ARMORY_MANAGER:GetBuildIcon(GetArmoryBuildIconIndex(buildIndex)) end,
    }
    for _, ask in pairs(candidates) do
        local ok, icon = pcall(ask)
        if ok and type(icon) == "string" and icon ~= "" then return icon end
    end
    return DEFAULT_LOADOUT_ICON
end

-- Worn pieces follow the list's tab filter and search box like everything else.
local function PassesListFilter(inventory, slotData, searchText)
    if searchText ~= "" and not zo_strlower(slotData.name or ""):find(searchText, 1, true) then
        return false
    end
    local filter = inventory.currentFilter
    if type(filter) == "function" then return filter(slotData) end
    if filter and ZO_ItemFilterUtils and ZO_ItemFilterUtils.IsSlotFilterDataInItemTypeDisplayCategory then
        return ZO_ItemFilterUtils.IsSlotFilterDataInItemTypeDisplayCategory(slotData, filter)
    end
    return true
end
IG.PassesListFilter = PassesListFilter

-- Saving, renaming or restoring a loadout rebuilds the lists so ARMORY stays current.
local function OnArmoryChanged()
    if IG.sv and IG.sv.armoryEnabled and IG.RefreshLists then IG.RefreshLists() end
end
for _, event in ipairs({ "EVENT_ARMORY_BUILDS_FULL_UPDATE", "EVENT_ARMORY_BUILD_UPDATED",
    "EVENT_ARMORY_BUILD_COUNT_UPDATED", "EVENT_ARMORY_BUILD_RESTORE_RESPONSE" }) do
    if _G[event] then
        EVENT_MANAGER:RegisterForEvent("InventoryGroupingArmory" .. event, _G[event], OnArmoryChanged)
    end
end

-- Returns { { data = proxy, path = path }, ... } for every piece of every loadout that's in this list
-- (or worn, when showing the backpack).
function IG.CollectArmoryEntries(inventory, inventoryType, rawEntries, searchText)
    local result = {}
    if not IG.sv.armoryEnabled or not GetNumUnlockedArmoryBuilds then return result end

    local listed = {}
    for _, entry in ipairs(rawEntries) do
        local data = entry.data
        listed[data.bagId] = listed[data.bagId] or {}
        listed[data.bagId][data.slotIndex] = data
    end
    local wornCache = inventoryType == INVENTORY_BACKPACK and SHARED_INVENTORY:GetOrCreateBagCache(BAG_WORN) or nil

    local root = IG.MakeGroupNode("ARMORY")
    for buildIndex = 1, GetNumUnlockedArmoryBuilds() do
        local loadout = {
            id = "build" .. buildIndex,
            label = BuildName(buildIndex),
            color = IG.LOADOUT_COLOR,
            icon = BuildIcon(buildIndex),
            keepIconColors = true, -- show the loadout icon as the game draws it
            order = buildIndex,
            wide = true, -- lines up with the house chests under HOME CONTAINERS
        }
        -- A loadout whose every piece is on your character is the one you last equipped.
        local slotsInBuild, slotsWorn = 0, 0
        for equipSlot = EQUIP_SLOT_ITERATION_BEGIN, EQUIP_SLOT_ITERATION_END do
            if not SKIPPED_EQUIP_SLOTS[equipSlot] then
                local slotState, bagId, slotIndex = GetArmoryBuildEquipSlotInfo(buildIndex, equipSlot)
                if slotState == ARMORY_BUILD_EQUIP_SLOT_STATE_VALID then
                    slotsInBuild = slotsInBuild + 1
                    if bagId == BAG_WORN then slotsWorn = slotsWorn + 1 end
                    local slotData, worn
                    if bagId == BAG_WORN then
                        slotData = wornCache and wornCache[slotIndex]
                        worn = true
                        if slotData and not PassesListFilter(inventory, slotData, searchText) then slotData = nil end
                    else
                        slotData = listed[bagId] and listed[bagId][slotIndex]
                    end
                    -- A piece set aside is listed where it was sent and nowhere else -- except
                    -- the one on your character, whose only row in this list is this one, and
                    -- which you can do nothing with while you are wearing it anyway.
                    if slotData and (worn or not IG.IsSetAside(slotData)) then
                        local proxy = setmetatable({ igArmory = true, inventory = worn and WORN_INVENTORY or nil },
                            { __index = slotData })
                        local itemLink = GetItemLink(slotData.bagId, slotData.slotIndex)
                        result[#result + 1] = {
                            data = proxy,
                            path = { root, loadout, IG.GetSetNode(itemLink) or OTHER_GEAR_NODE },
                        }
                    end
                end
            end
        end
        -- Wearing every piece of a loadout means it is the one you last equipped.
        if slotsInBuild > 0 and slotsWorn == slotsInBuild then
            loadout.label = loadout.label .. " (Last Equipped)"
            loadout.color = IG.Tone(IG.EQUIPPED_LOADOUT_COLOR)
        end
    end
    return result
end
