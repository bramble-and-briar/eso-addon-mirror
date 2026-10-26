ExtraRadialMenuWheels = ExtraRadialMenuWheels or {}
local ERMWheels = ExtraRadialMenuWheels

ERMWheels.ERM_WHEEL1 = HOTBAR_CATEGORY_MAX_VALUE + 100 + 1
ERMWheels.ERM_WHEEL2 = HOTBAR_CATEGORY_MAX_VALUE + 100 + 2
ERMWheels.ERM_WHEEL3 = HOTBAR_CATEGORY_MAX_VALUE + 100 + 3
ERMWheels.ERM_WHEEL4 = HOTBAR_CATEGORY_MAX_VALUE + 100 + 4
ERMWheels.ERM_WHEEL5 = HOTBAR_CATEGORY_MAX_VALUE + 100 + 5
ERMWheels.ERM_WHEEL6 = HOTBAR_CATEGORY_MAX_VALUE + 100 + 6
ERMWheels.ERM_WHEEL7 = HOTBAR_CATEGORY_MAX_VALUE + 100 + 7

ERMWheels.TypeAssistants = 1
ERMWheels.TypeCompanions = 2
ERMWheels.TypeHouses = 3
ERMWheels.TypeMementos = 4
ERMWheels.TypeEmotes = 5

ERMWheels.wheels = {
	[ERMWheels.ERM_WHEEL1] = { id = ERMWheels.ERM_WHEEL1, name = "Assistants", type = ERMWheels.TypeAssistants },
	[ERMWheels.ERM_WHEEL2] = { id = ERMWheels.ERM_WHEEL2, name = "Companions", type = ERMWheels.TypeCompanions },
	[ERMWheels.ERM_WHEEL3] = { id = ERMWheels.ERM_WHEEL3, name = "Houses", type = ERMWheels.TypeHouses },

	[ERMWheels.ERM_WHEEL4] = { id = ERMWheels.ERM_WHEEL4, name = "Houses 2", type = ERMWheels.TypeHouses },
	[ERMWheels.ERM_WHEEL5] = { id = ERMWheels.ERM_WHEEL5, name = "Assistants 2", type = ERMWheels.TypeAssistants },
	[ERMWheels.ERM_WHEEL6] = { id = ERMWheels.ERM_WHEEL6, name = "Mementos 2", type = ERMWheels.TypeMementos },
	[ERMWheels.ERM_WHEEL7] = { id = ERMWheels.ERM_WHEEL7, name = "Emotes 2", type = ERMWheels.TypeEmotes },
}

ZO_CreateStringId(string.format("SI_HOTBARCATEGORY%d", ERMWheels.ERM_WHEEL1), ERMWheels.wheels[ERMWheels.ERM_WHEEL1].name)
ZO_CreateStringId(string.format("SI_HOTBARCATEGORY%d", ERMWheels.ERM_WHEEL2), ERMWheels.wheels[ERMWheels.ERM_WHEEL2].name)
ZO_CreateStringId(string.format("SI_HOTBARCATEGORY%d", ERMWheels.ERM_WHEEL3), ERMWheels.wheels[ERMWheels.ERM_WHEEL3].name)

ZO_CreateStringId(string.format("SI_HOTBARCATEGORY%d", ERMWheels.ERM_WHEEL4), ERMWheels.wheels[ERMWheels.ERM_WHEEL4].name)
ZO_CreateStringId(string.format("SI_HOTBARCATEGORY%d", ERMWheels.ERM_WHEEL5), ERMWheels.wheels[ERMWheels.ERM_WHEEL5].name)
ZO_CreateStringId(string.format("SI_HOTBARCATEGORY%d", ERMWheels.ERM_WHEEL6), ERMWheels.wheels[ERMWheels.ERM_WHEEL6].name)
ZO_CreateStringId(string.format("SI_HOTBARCATEGORY%d", ERMWheels.ERM_WHEEL7), ERMWheels.wheels[ERMWheels.ERM_WHEEL7].name)

HOTBAR_CATEGORY_ALLY_WHEEL = HOTBAR_CATEGORY_ALLY_WHEEL or 13

local UTILITY_WHEEL_CATEGORIES_FULL =
{
	HOTBAR_CATEGORY_QUICKSLOT_WHEEL,
	HOTBAR_CATEGORY_ALLY_WHEEL,
	ERMWheels.ERM_WHEEL1,
	ERMWheels.ERM_WHEEL2,
	ERMWheels.ERM_WHEEL3,
	HOTBAR_CATEGORY_MEMENTO_WHEEL,
	HOTBAR_CATEGORY_TOOL_WHEEL,
	HOTBAR_CATEGORY_EMOTE_WHEEL,
}

local UTILITY_WHEEL_CATEGORIES_ORIGINAL =
{
	HOTBAR_CATEGORY_QUICKSLOT_WHEEL,
	HOTBAR_CATEGORY_ALLY_WHEEL,
	HOTBAR_CATEGORY_MEMENTO_WHEEL,
	HOTBAR_CATEGORY_TOOL_WHEEL,
	HOTBAR_CATEGORY_EMOTE_WHEEL,
}

local UTILITY_WHEEL_CATEGORIES = UTILITY_WHEEL_CATEGORIES_ORIGINAL
local NUM_UTILITY_WHEEL_CATEGORIES = #UTILITY_WHEEL_CATEGORIES

function ZO_UtilityWheel_Shared:GetHotbarCategory()
	return UTILITY_WHEEL_CATEGORIES[self.currentHotbarCategoryIndex]
end

function ZO_UtilityWheel_Shared:GetNextHotbarCategoryIndex()
	return self.currentHotbarCategoryIndex % NUM_UTILITY_WHEEL_CATEGORIES + 1
end

function ZO_UtilityWheel_Shared:GetPreviousHotbarCategoryIndex()
	local categoryIndex = self.currentHotbarCategoryIndex - 1
	if categoryIndex == 0 then
		categoryIndex = NUM_UTILITY_WHEEL_CATEGORIES
	end
	return categoryIndex
end

function ZO_UtilityWheel_Shared:GetNextHotbarCategory()
	return UTILITY_WHEEL_CATEGORIES[self:GetNextHotbarCategoryIndex()]
end

function ZO_UtilityWheel_Shared:GetPreviousHotbarCategory()
	return UTILITY_WHEEL_CATEGORIES[self:GetPreviousHotbarCategoryIndex()]
end

--[[ local SUPPORTED_HOTBAR_CATEGORY_DATA =
{
    [HOTBAR_CATEGORY_QUICKSLOT_WHEEL] = 
    {
        [ACTION_TYPE_ITEM] = true,
        [ACTION_TYPE_COLLECTIBLE] = true,
        [ACTION_TYPE_QUEST_ITEM] = true,
        [ACTION_TYPE_EMOTE] = true,
        [ACTION_TYPE_QUICK_CHAT] = true,
    },
    [HOTBAR_CATEGORY_EMOTE_WHEEL] = 
    {
        [ACTION_TYPE_EMOTE] = true,
        [ACTION_TYPE_QUICK_CHAT] = true,
    },
    [HOTBAR_CATEGORY_MEMENTO_WHEEL] =
    {
        [ACTION_TYPE_COLLECTIBLE] = true,
    },
    [HOTBAR_CATEGORY_ALLY_WHEEL] =
    {
        [ACTION_TYPE_COLLECTIBLE] = true,
    },
    [ERM_WHEEL1] =
    {
        [ACTION_TYPE_COLLECTIBLE] = true,
    },
    [HOTBAR_CATEGORY_TOOL_WHEEL] =
    {
        [ACTION_TYPE_COLLECTIBLE] = true,
    },
}

function ZO_AssignableUtilityWheel_Shared:SetupHotbarCategories(categoryList)
	table.insert(categoryList, ERM_WHEEL1)

    local validCategories = {}
    local numValidCategories = 0
    for _, hotbarCategory in ipairs(categoryList) do
        if SUPPORTED_HOTBAR_CATEGORY_DATA[hotbarCategory] ~= nil then
            table.insert(validCategories, hotbarCategory)
            numValidCategories = numValidCategories + 1
        end
    end

    if numValidCategories > 0 then
        if self.data.includeHiddenState then
            table.insert(validCategories, ZO_UTILITY_WHEEL_HOTBAR_CATEGORY_HIDDEN)
            numValidCategories = numValidCategories + 1
        end
        self.numHotbars = numValidCategories
        self.hotbarCategories = validCategories
        self.currentHotbarCategoryIndex = 1
        return true
    else
        internalassert(false, "No valid hotbar categories found")
        return false
    end
end

function ZO_AssignableUtilityWheel_Shared:IsActionTypeSupported(actionType)
    local categoryData = SUPPORTED_HOTBAR_CATEGORY_DATA[self:GetHotbarCategory()]
    if categoryData and categoryData[actionType] then
        return true
    else
        return false
    end
end ]]

function ERMWheels.InsertWheelAtIndex(index, wheel)
	if index == 0 then return end
	table.insert(UTILITY_WHEEL_CATEGORIES, index, wheel)
	NUM_UTILITY_WHEEL_CATEGORIES = #UTILITY_WHEEL_CATEGORIES
end

function ERMWheels.RefreshWheels(wheels, keepOriginalAlliesWheel, enable)
    if not enable then
        ERMWheels.ResetWheels()
        return
    end

	local newList = {}
	for i, wheel in ipairs(UTILITY_WHEEL_CATEGORIES_FULL) do
		if wheel > HOTBAR_CATEGORY_MAX_VALUE then
			if wheels[wheel] == true then
				table.insert(newList, wheel)
			end
        elseif wheel == HOTBAR_CATEGORY_ALLY_WHEEL then
            if keepOriginalAlliesWheel == true then
                table.insert(newList, wheel)
            end
		else
			table.insert(newList, wheel)
		end
	end
	UTILITY_WHEEL_CATEGORIES = newList
	NUM_UTILITY_WHEEL_CATEGORIES = #UTILITY_WHEEL_CATEGORIES
end

function ERMWheels.ResetWheels()
    UTILITY_WHEEL_CATEGORIES = UTILITY_WHEEL_CATEGORIES_ORIGINAL
	NUM_UTILITY_WHEEL_CATEGORIES = #UTILITY_WHEEL_CATEGORIES
end
