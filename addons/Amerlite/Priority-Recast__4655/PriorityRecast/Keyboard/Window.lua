local PriorityRecast  = PriorityRecast
local Priorities      = PriorityRecast.Priorities
local HasDuration     = PriorityRecast.HasDuration

local ToNumber        = tonumber
local ListDefineRow   = ZO_ScrollList_AddDataType
local ListGetEntries  = ZO_ScrollList_GetDataList
local ListGetData     = ZO_ScrollList_GetData
local ListClear       = ZO_ScrollList_Clear
local ListCreateEntry = ZO_ScrollList_CreateDataEntry
local ListCommit      = ZO_ScrollList_Commit

local CallProtected   = CallSecureProtected
local CursorAbilityId = GetCursorAbilityId
local CursorContent   = GetCursorContentType
local ClearCursor     = ClearCursor
local PlaySound       = PlaySound
local AbilityIcon     = GetAbilityIcon

local ROW_TEMPLATE    = "PrioritiesListRow"
local ROW_HEIGHT      = 56
local ROW_TYPE        = 1

local Window          = PrioritiesWindow
local List            = PrioritiesWindowList
local Glow            = PrioritiesWindowGlow
local EmptyLabel      = PrioritiesWindowEmptyLabel

-------------------------------------------------------------------------------
-- WINDOW FUNCONALITY
-------------------------------------------------------------------------------

function Window.Initialize()

	-- Add the window to the skills screen.
	KEYBOARD_SKILLS_SCENE:AddFragment(ZO_FadeSceneFragment:New(Window))

	-- Define list rows and run initial update.
	ListDefineRow(List, ROW_TYPE, ROW_TEMPLATE, ROW_HEIGHT, Window.SetupRow)
	Window.UpdateEntries()

	-- Set label values.
	EmptyLabel:SetText(GetString(PRIORITYRECAST_EMPTY_LIST_LABEL))
end


function Window.UpdateEntries()

	local entries = ListGetEntries(List)
	ListClear(List)

	for index, skillId, offset in Priorities.Iter() do
		local data  = { index = index, skillId = skillId, offset = offset }
		local entry = ListCreateEntry(ROW_TYPE, data)
		entries[index] = entry
	end

	ListCommit(List)
	EmptyLabel:SetHidden(not Priorities.IsEmpty())
end


function Window.MouseEnterWindow()
	if CursorContent() == MOUSE_CONTENT_ACTION then
		Glow:SetHidden(false)
	end
end


function Window.MouseExitWindow()
	Glow:SetHidden(true)
end

-------------------------------------------------------------------------------
-- ROW FUNCONALITY
-------------------------------------------------------------------------------

function Window.SetupRow(row, data)

	local skillId = data.skillId
	local index   = data.index
	local offset  = data.offset

	-- Set the fixed row height.
	row:SetHeight(ROW_HEIGHT)

	-- Set the skill icon.
	local icon = row:GetNamedChild("Icon")
	icon:SetTexture(AbilityIcon(skillId))

	-- Set the offset time.
	local editbox = row:GetNamedChild("Offset")
	editbox:SetText(offset)

	-- Hide offset time if no duration.
	local hasDuration = HasDuration(skillId)
	editbox:SetHidden(not hasDuration)
end


function Window.TryCursorInsert(row)

	-- Ensure that the cursor is holding a skill.
	if CursorContent() ~= MOUSE_CONTENT_ACTION then return end

	-- Get the row index (can be nil) and the skill ID.
	local index   = row and ListGetData(row).index or nil
	local skillId = CursorAbilityId()

	-- Insert the skill into the priority list.
	Priorities.Insert(skillId, index)

	-- Play slotted sound and clear the cursor.
	PlaySound(SOUNDS.ABILITY_SLOTTED)
	ClearCursor()

	-- Make sure the input glow is hidden.
	Glow:SetHidden(true)
end


function Window.TryCursorPickup(row)

	-- Ensure that the cursor is empty first.
	if CursorContent() ~= MOUSE_CONTENT_EMPTY then return end

	-- Get the skill ID from the row.
	local skillId = ListGetData(row).skillId

	-- Try to pickup the skill. Fails in combat.
	CallProtected("PickupAbilityById", skillId)
end


function Window.RemoveEntry(row)

	-- Get the index from the row.
	local index = ListGetData(row).index

	-- Remove the skill from the priority list.
	Priorities.Remove(index)

	-- Play removed sound effect.
	PlaySound(SOUNDS.QUEST_SHARE_DECLINED)
end


function Window.InputDone(editbox)

	-- Get the offset time and skill ID.
	local time    = ToNumber(editbox:GetText())
	local skillId = ListGetData(editbox:GetParent()).skillId

	-- Set to zero if no input.
	editbox:SetText(time)

	-- Save the new offset for the skill.
	Priorities.SaveOffset(skillId, time)
end


function Window.MouseEnterRow(row)
	row:GetNamedChild("Highlight"):SetAlpha(0.5)
end


function Window.MouseExitRow(row)
	row:GetNamedChild("Highlight"):SetAlpha(0)
end


function Window.MouseEnterButton(button)
	button:SetAlpha(1)
	Window.MouseEnterRow(button:GetParent())
end


function Window.MouseExitButton(button)
	button:SetAlpha(0.5)
	Window.MouseExitRow(button:GetParent())
end

-------------------------------------------------------------------------------
-- ADDON INITIALIZE
-------------------------------------------------------------------------------

PriorityRecast:RegisterCallback("AddonLoaded", function()
	Window.Initialize()
	PriorityRecast:RegisterCallback("PrioritiesUpdated", Window.UpdateEntries)
end)
