PlayerRoleIndicator = PlayerRoleIndicator or {}
local PRI = PlayerRoleIndicator
PRI.name = "PlayerRoleIndicator"
PRI.version = "1.3.1"
PRI.variableVersion = 11
PRI.roleLookup = {}
PRI.infoCache = {}
PRI.activeIcons = {}
PRI.currentZoneId = 0
PRI.shadeByName = {}
PRI.shadeWatcherActive = false
PRI.noteNum = 5
PRI.noteLabels = {}
PRI.noteUnlocked = false
PRI.customMax = 20
PRI.EVENT = {
	CUSTOM_ROLE_CHANGED = "PRI_CustomRoleChanged",
}

local noteId = PRI.noteNum
local LCM = LibCustomMenu

local SHADOW_OF_THE_FALLEN_ABILITY_ID = 102271
local CLOUDREST_ZONE_ID = 1051

PRI.default = {
	iconSize = 48,
	yOffsetDead = 50,
	yOffsetAlive = 325,
	scaleWithDistance = 0,

	showShade = true,
	shadeColour = { r = (100 / 255), g = 0, b = (160 / 255), a = 1 },

	useRezColour = true,
	rezPendingColour = { r = 1, g = 1, b = 1, a = 0.25 },
	rezingColour = { r = 1, g = 1, b = 1, a = 0.25 },

	useNote = true,
	noteSize = 1,
	notePos = { x = 0, y = 0 },
	noteUseAccountName = false,
	noteDuration = 3,
	noteUseIcon = true,
	noteRez = true,

	useCustom = true,
	customNum = 0,
	customRole = {},
	customDefault = {
		name = "Custom role",
		show = false,
		showOnAlive = false,
		texturePath = "/esoui/art/compass/groupmember.dds",
		iconSizeMultiplier = 1,
		colourAlive = { r = 1, g = 1, b = 1, a = 1 },
		colourDead = { r = 1, g = 1, b = 1, a = 1 },
		players = {},
	},

	leader = {
		show = false,
		showOnAlive = false,
		texturePath = "/esoui/art/compass/groupleader.dds",
		iconSizeMultiplier = 1,
		colourAlive = { r = 1, g = 1, b = 1, a = 1 },
		colourDead = { r = 1, g = 1, b = 1, a = 1 },
	},
	dps = {
		show = false,
		showOnAlive = false,
		texturePath = "/esoui/art/tutorial/gamepad/gp_lfg_dps.dds",
		iconSizeMultiplier = 1,
		colourAlive = { r = 1, g = 1, b = 1, a = 1 },
		colourDead = { r = 1, g = 1, b = 1, a = 1 },
	},
	tank = {
		show = true,
		showOnAlive = false,
		texturePath = "/esoui/art/tutorial/gamepad/gp_lfg_tank.dds",
		iconSizeMultiplier = 1,
		colourAlive = { r = 1, g = 1, b = 1, a = 1 },
		colourDead = { r = 1, g = 1, b = 1, a = 1 },
	},
	healer = {
		show = true,
		showOnAlive = false,
		texturePath = "/esoui/art/tutorial/gamepad/gp_lfg_healer.dds",
		iconSizeMultiplier = 1,
		colourAlive = { r = 1, g = 1, b = 1, a = 1 },
		colourDead = { r = 1, g = 1, b = 1, a = 1 },
	},
}

function PRI.InvalidateInfoCache()
	PRI.infoCache = {}
end

--Seeds shadeByName since EVENT_EFFECT_CHANGED only reports transitions, not current state
function PRI.ScanShadeBuffs()
	for i = 1, GetGroupSize(), 1 do
		local unitTag = GetGroupUnitTagByIndex(i)
		if unitTag then
			local hasShade = false
			for j = 1, GetNumBuffs(unitTag), 1 do
				local abilityId = ({ GetUnitBuffInfo(unitTag, j) })[11]
				if abilityId == SHADOW_OF_THE_FALLEN_ABILITY_ID then
					hasShade = true
					break
				end
			end
			PRI.shadeByName[GetUnitDisplayName(unitTag)] = hasShade or nil
		end
	end
end

function PRI.OnShadeEffectChanged(eventCode, changeType, effectSlot, effectName, unitTag)
	local displayName = GetUnitDisplayName(unitTag)
	if changeType == EFFECT_RESULT_FADED then
		PRI.shadeByName[displayName] = nil
	else
		PRI.shadeByName[displayName] = true
	end
end

function PRI.UpdateCurrentZone()
	PRI.currentZoneId = GetZoneId(GetUnitZoneIndex("player"))

	if PRI.currentZoneId == CLOUDREST_ZONE_ID then
		if not PRI.shadeWatcherActive then
			PRI.shadeWatcherActive = true
			PRI.ScanShadeBuffs()
			EVENT_MANAGER:RegisterForEvent(
				"PlayerRoleIndicatorShadeEffect",
				EVENT_EFFECT_CHANGED,
				PRI.OnShadeEffectChanged
			)
			EVENT_MANAGER:AddFilterForEvent(
				"PlayerRoleIndicatorShadeEffect",
				EVENT_EFFECT_CHANGED,
				REGISTER_FILTER_UNIT_TAG_PREFIX,
				"group",
				REGISTER_FILTER_ABILITY_ID,
				SHADOW_OF_THE_FALLEN_ABILITY_ID
			)
		end
	elseif PRI.shadeWatcherActive then
		PRI.shadeWatcherActive = false
		EVENT_MANAGER:UnregisterForEvent("PlayerRoleIndicatorShadeEffect", EVENT_EFFECT_CHANGED)
		PRI.shadeByName = {}
	end
end

--Emulates a C-style switch, should have better performance than if-else chains
function PRI.UpdateRoleSwitch()
	PRI.InvalidateInfoCache()
	local sv = PRI.savedVariables
	PRI.roleLookup = {
		[LFG_ROLE_TANK] = {
			show = sv.tank.show,
			showOnAlive = sv.tank.showOnAlive,
			sv = sv.tank,
		},
		[LFG_ROLE_HEAL] = {
			show = sv.healer.show,
			showOnAlive = sv.healer.showOnAlive,
			sv = sv.healer,
		},
		[LFG_ROLE_DPS] = {
			show = sv.dps.show,
			showOnAlive = sv.dps.showOnAlive,
			sv = sv.dps,
		},
		["Leader"] = {
			show = sv.leader.show,
			showOnAlive = sv.leader.showOnAlive,
			sv = sv.leader,
		},
		[LFG_ROLE_INVALID] = {
			show = false,
			showOnAlive = false,
			sv = {
				texturePath = "",
				colourAlive = { r = 1, g = 1, b = 1, a = 0 },
				colourDead = { r = 1, g = 1, b = 1, a = 0 },
			},
		},
	}
end

function PRI.GetInfo(unitTag)
	local cached = PRI.infoCache[unitTag]
	if cached then
		return cached.role, cached.displayName
	end

	local customRole = nil
	local sv = PRI.savedVariables
	local displayName = GetUnitDisplayName(unitTag)
	for i = 1, sv.customNum do
		local value = sv.customRole[i]
		for index, playerName in ipairs(value.players) do
			if playerName == displayName then
				customRole = value
				break
			end
		end
		if customRole then
			break
		end
	end

	local role = nil
	if customRole then
		role = {}
		role.name = customRole.name
		role.show = customRole.show
		role.showOnAlive = customRole.showOnAlive
		role.sv = {
			texturePath = customRole.texturePath,
			iconSizeMultiplier = customRole.iconSizeMultiplier,
			colourAlive = customRole.colourAlive,
			colourDead = customRole.colourDead,
		}
	elseif AreUnitsEqual(GetGroupLeaderUnitTag(), unitTag) and PRI.roleLookup["Leader"].show then
		role = PRI.roleLookup["Leader"]
	else
		role = PRI.roleLookup[GetGroupMemberSelectedRole(unitTag)]
	end

	PRI.infoCache[unitTag] = { role = role, displayName = displayName }
	return role, displayName
end

-- Public API: Other addons can query what custom role(s) we assign
-- NB. unfortunate historic 'sv' name kept as backwards compatibility is deprecated
function PRI.GetRole(unitTag)
	local role = PRI.GetInfo(unitTag)
	local icon = {
		texturePath = role.sv.texturePath,
		iconSizeMultiplier = role.sv.iconSizeMultiplier,
		colourAlive = role.sv.colourAlive,
		colourDead = role.sv.colourDead,
	}

	return {
		name = role.name,
		show = role.show,
		showOnAlive = role.showOnAlive,
		icon = icon,
		sv = icon, -- deprecated: use the renamed 'icon' field above instead
	}
end

-- Public API: add custom role "Add to / Remove from" items to any ESO menu.
-- addItemFunc(label, callback) defaults to AddMenuItem (vanilla ESO right-click menu).
-- onChangedFunc() is called after each role assignment change; may be nil.
function PRI.AddCustomRoleMenuItems(accountName, addItemFunc, onChangedFunc)
	if PRI.savedVariables == nil then
		return
	end
	addItemFunc = addItemFunc or AddMenuItem
	local sv = PRI.savedVariables
	for i = 1, sv.customNum do
		local roleEntry = sv.customRole[i]
		if roleEntry.show then
			local playerIndex = 0
			for index, playerName in ipairs(roleEntry.players) do
				if playerName == accountName then
					playerIndex = index
					break
				end
			end
			local capturedEntry = roleEntry
			local capturedIndex = playerIndex
			if capturedIndex == 0 then
				addItemFunc(string.format("Add to %s", capturedEntry.name), function()
					table.insert(capturedEntry.players, accountName)
					if onChangedFunc then
						onChangedFunc()
					end
					CALLBACK_MANAGER:FireCallbacks(PRI.EVENT.CUSTOM_ROLE_CHANGED, accountName)
				end)
			else
				addItemFunc(string.format("Remove from %s", capturedEntry.name), function()
					table.remove(capturedEntry.players, capturedIndex)
					if onChangedFunc then
						onChangedFunc()
					end
					CALLBACK_MANAGER:FireCallbacks(PRI.EVENT.CUSTOM_ROLE_CHANGED, accountName)
				end)
			end
		end
	end
end

function PRI.UnitChecks(unitTag)
	return DoesUnitExist(unitTag)
		and (not AreUnitsEqual("player", unitTag))
		and IsUnitPlayer(unitTag)
		and IsUnitOnline(unitTag)
		and IsUnitGrouped(unitTag)
		and IsGroupMemberInSameInstanceAsPlayer(unitTag)
		and IsGroupMemberInSameWorldAsPlayer(unitTag)
		and (not IsGroupMemberInRemoteRegion(unitTag))
end

function PRI.GetIconControl(unitTag)
	local icon = PRI.activeIcons[unitTag]
	return icon and icon.control
end

function PRI.AcquireIcon(unitTag)
	if PRI.activeIcons[unitTag] then
		return
	end
	local control, key = PRI.iconPool:AcquireObject()
	control:SetAnchor(CENTER, PlayerRoleIndicatorWindow, CENTER, 0, 0)
	control:SetMouseEnabled(false)
	control:SetHidden(true)
	PRI.activeIcons[unitTag] = { control = control, key = key, hasRenderSpace = false }
end

function PRI.SetIconVisible(unitTag, visible)
	local icon = PRI.activeIcons[unitTag]
	if visible == icon.hasRenderSpace then
		-- Do nothing.
	elseif visible then -- not hasRenderSpace
		icon.control:Create3DRenderSpace()
		icon.hasRenderSpace = true
	else -- not visible and hasRenderSpace
		-- NB. SetHidden alone doesn't remove a 3D render space from the scene
		icon.control:Destroy3DRenderSpace()
		icon.hasRenderSpace = false
	end
	icon.control:SetHidden(not visible)
end

function PRI.ReleaseIcon(unitTag)
	local icon = PRI.activeIcons[unitTag]
	if not icon then
		return
	end
	if icon.hasRenderSpace then
		icon.control:Destroy3DRenderSpace()
	end
	icon.control:SetHidden(true)
	PRI.iconPool:ReleaseObject(icon.key)
	PRI.activeIcons[unitTag] = nil
end

function PRI.ReleaseAllIcons()
	for unitTag in pairs(PRI.activeIcons) do
		PRI.ReleaseIcon(unitTag)
	end
end

-- Index-to-tag mapping isn't stable across roster changes; release anything no longer current
function PRI.SyncActiveIcons()
	local currentTags = {}
	for i = 1, GetGroupSize(), 1 do
		local unitTag = GetGroupUnitTagByIndex(i)
		if unitTag then
			currentTags[unitTag] = true
		end
	end
	for unitTag in pairs(PRI.activeIcons) do
		if not currentTags[unitTag] then
			PRI.ReleaseIcon(unitTag)
		end
	end
end

function PRI.OnGroupChanged()
	PRI.InvalidateInfoCache()
	PRI.SyncActiveIcons()
end

local function unpackColour(colour)
	return colour.r, colour.g, colour.b, colour.a
end

function PRI.UpdateIconVisual(unitTag, role, displayName, isDead)
	-- NB. PRI.UnitChecks(unitTag) is known to be true here
	local icon = PRI.GetIconControl(unitTag)
	if not icon then
		return
	end
	local sv = PRI.savedVariables

	if role.show then
		icon:SetTexture(role.sv.texturePath)

		if isDead then
			if sv.showShade and PRI.shadeByName[displayName] then
				icon:SetColor(unpackColour(sv.shadeColour))
				return
			elseif IsUnitBeingResurrected(unitTag) then
				icon:SetColor(unpackColour(sv.rezingColour))
			elseif DoesUnitHaveResurrectPending(unitTag) then
				icon:SetColor(unpackColour(sv.rezPendingColour))
			else
				icon:SetColor(unpackColour(role.sv.colourDead))
			end
		elseif role.showOnAlive then
			icon:SetColor(unpackColour(role.sv.colourAlive))
		end
	end
end

function PRI.UpdateAllIconVisuals()
	for unitTag in pairs(PRI.activeIcons) do
		if PRI.UnitChecks(unitTag) then
			local role, displayName = PRI.GetInfo(unitTag)
			local isDead = IsUnitDead(unitTag)
			PRI.UpdateIconVisual(unitTag, role, displayName, isDead)
		end
	end
end

-- Lazily creates note label i (and its icon) on first access to speed up load times
function PRI.GetNoteLabel(i)
	if i > PRI.noteNum then -- we never do this
		return nil
	end

	local entry = PRI.noteLabels[i]
	if entry then
		return entry.label, entry.icon
	end

	local noteSize = PRI.savedVariables.noteSize
	local label = PRI.notePanel:CreateControl(string.format("$(parent)Note%u", i), CT_LABEL)
	label:SetId(i)
	label:SetFont("ZoFontWinH1")
	label:SetText("Unit has died")
	label:SetWidth(label:GetStringWidth("Unit has died"))
	label:SetScale(noteSize)
	local textHeight = label:GetTextHeight()
	label:SetAnchor(TOPLEFT, PRI.notePanel, TOPLEFT, textHeight * noteSize, textHeight * (i - 1) * 1.25 * noteSize)
	label:SetMouseEnabled(false)
	label:SetHidden(true)

	local labelIcon = label:CreateControl("$(parent)Icon", CT_TEXTURE)
	labelIcon:SetDimensions(textHeight, textHeight)
	labelIcon:SetTexture("/esoui/art/tutorial/gamepad/gp_lfg_dps.dds")
	labelIcon:SetAnchor(TOPRIGHT, label, TOPLEFT, textHeight * -0.25, 0)
	labelIcon:SetMouseEnabled(false)
	labelIcon:SetHidden(true)

	PRI.noteLabels[i] = { label = label, icon = labelIcon }
	return label, labelIcon
end

function PRI.UpdateAllNoteSize()
	if PRI.noteUnlocked then
		return
	end

	local notePos = PRI.savedVariables.notePos
	PRI.notePanel:SetAnchor(TOPLEFT, PlayerRoleIndicatorWindow, TOPLEFT, notePos.x, notePos.y)
	local noteSize = PRI.savedVariables.noteSize
	for i = 1, #PRI.noteLabels, 1 do
		local label, labelIcon = PRI.GetNoteLabel(i)

		label:SetScale(noteSize)
		local textHeight = label:GetTextHeight()
		label:SetAnchor(TOPLEFT, PRI.notePanel, TOPLEFT, textHeight * noteSize, textHeight * (i - 1) * 1.25 * noteSize)

		labelIcon:SetDimensions(textHeight, textHeight)
		labelIcon:SetAnchor(TOPRIGHT, label, TOPLEFT, textHeight * -0.25, 0)
	end
end

function PRI.ShowNote(event, unitTag, isDead)
	if not PRI.savedVariables.useNote then
		return
	end
	if PRI.noteUnlocked then
		return
	end
	if not PRI.UnitChecks(unitTag) then
		return
	end

	local role, displayName = PRI.GetInfo(unitTag)

	if not role.show then
		return
	end
	if (not role.showOnAlive) and not isDead then
		return
	end

	-- Shift existing notes down one slot, working from the bottom up
	for i = zo_min(#PRI.noteLabels + 1, PRI.noteNum), 2, -1 do
		local destLabel, destIcon = PRI.GetNoteLabel(i)
		local srcLabel, srcIcon = PRI.GetNoteLabel(i - 1)

		destLabel:SetColor(srcLabel:GetColor())
		destLabel:SetText(srcLabel:GetText())
		destLabel:SetWidth(srcLabel:GetTextWidth())
		destLabel:SetId(srcLabel:GetId())
		destLabel:SetHidden(srcLabel:IsHidden())
		local srcTexturePath = srcIcon:GetTextureFileName()
		destIcon:SetTexture(srcTexturePath)
		if srcTexturePath == "" then
			destIcon:SetHidden(true)
		else
			destIcon:SetColor(srcIcon:GetColor())
			destIcon:SetHidden(srcIcon:IsHidden())
		end
	end

	local label, labelIcon = PRI.GetNoteLabel(1)
	noteId = noteId + 1

	local name = PRI.savedVariables.noteUseAccountName and displayName or GetUnitName(unitTag)
	local colour = isDead and role.sv.colourDead or role.sv.colourAlive
	local text = string.format(isDead and "%s has died" or "%s has been resurrected", name)
	local texturePath = PRI.savedVariables.noteUseIcon and role.sv.texturePath or ""

	label:SetId(noteId)
	label:SetColor(unpackColour(colour))
	label:SetText(text)
	label:SetWidth(label:GetStringWidth(text))
	label:SetHidden(false)
	labelIcon:SetTexture(texturePath)
	if texturePath == "" then
		labelIcon:SetHidden(true)
	else
		labelIcon:SetColor(unpackColour(colour))
		labelIcon:SetHidden(false)
	end

	local id = noteId
	zo_callLater(function() PRI.FadeNote(id) end, PRI.savedVariables.noteDuration * 1000)
end

function PRI.FadeNote(id)
	if PRI.noteUnlocked then
		return
	end
	for i = 1, #PRI.noteLabels, 1 do
		local label = PRI.GetNoteLabel(i)
		if label:GetId() == id then
			local alpha = label:GetAlpha()
			if alpha > 0.1 then
				label:SetAlpha(alpha - 0.1)
				zo_callLater(function() PRI.FadeNote(id) end, 100)
			else
				label:SetHidden(true)
			end
			break
		end
	end
end

function PRI.PlayerLeftGroup()
	PRI.ReleaseAllIcons()
end

function PRI.UpdateForUnit(unitTag, camX, camY, camZ)
	if not PRI.UnitChecks(unitTag) then
		return true
	end

	local role, displayName = PRI.GetInfo(unitTag)

	if not role.show then
		return true
	end
	local isDead = IsUnitDead(unitTag)
	if (not role.showOnAlive) and (not isDead) then
		return true
	end

	--Gets the units world postion and adds height offset
	local sv = PRI.savedVariables
	local _, worldX, worldY, worldZ = GetUnitRawWorldPosition(unitTag)
	if isDead then
		worldY = worldY + sv.yOffsetDead
	else
		worldY = worldY + sv.yOffsetAlive
	end

	PRI.UpdateIconVisual(unitTag, role, displayName, isDead)
	PRI.SetIconVisible(unitTag, true)

	local icon = PRI.GetIconControl(unitTag)
	icon:Set3DRenderSpaceOrigin(WorldPositionToGuiRender3DPosition(worldX, worldY, worldZ))

	local t = sv.scaleWithDistance
	local iconSize = sv.iconSize * (role.sv.iconSizeMultiplier or 1) / 100
	if t == 1 then
		icon:Set3DLocalDimensions(iconSize, iconSize)
		return false
	end

	local distance = zo_distance3D(worldX, worldY, worldZ, camX, camY, camZ) / 100
	local scaledIconSize = iconSize * (t + (distance / 10) * (1 - t))
	icon:Set3DLocalDimensions(scaledIconSize, scaledIconSize)

	return false
end

function PRI.UpdateIndicators()
	if not IsUnitGrouped("player") then
		return
	end

	local forwardX, forwardY, forwardZ = GetCameraForward(SPACE_WORLD)
	local yaw = zo_atan2(forwardX, forwardZ) - math.pi
	local pitch = zo_atan2(forwardY, zo_sqrt(forwardX * forwardX + forwardZ * forwardZ))

	local RenderSpace = PRI.RenderSpace
	Set3DRenderSpaceToCurrentCamera(RenderSpace:GetName())
	local camX, camY, camZ = GuiRender3DPositionToWorldPosition(RenderSpace:Get3DRenderSpaceOrigin())

	for i = 1, GetGroupSize(), 1 do
		local unitTag = GetGroupUnitTagByIndex(i)
		if unitTag then
			PRI.AcquireIcon(unitTag)
			local hidden = PRI.UpdateForUnit(unitTag, camX, camY, camZ)
			if hidden then
				PRI.SetIconVisible(unitTag, false)
			else
				PRI.GetIconControl(unitTag):Set3DRenderSpaceOrientation(pitch, yaw, 0)
			end
		end
	end
end

function PRI.intialize(eventCode, name)
	if name ~= PRI.name then
		return
	end

	PRI.savedVariables = ZO_SavedVars:NewAccountWide(
		"PlayerRoleIndicatorVars",
		PRI.variableVersion,
		nil,
		PRI.default,
		GetWorldName()
	)
	PRI.CreateSettingsWindow()

	--Hides icons when scene is changed
	local function stateChange(oldState, newState)
		if newState == SCENE_SHOWN then
			if PlayerRoleIndicatorWindow:IsHidden() then
				PlayerRoleIndicatorWindow:SetHidden(false)
			end
		end
	end
	PRI.fragment = ZO_HUDFadeSceneFragment:New(PlayerRoleIndicatorWindow)
	HUD_SCENE:AddFragment(PRI.fragment)
	HUD_SCENE:RegisterCallback("StateChange", stateChange)
	HUD_UI_SCENE:AddFragment(PRI.fragment)

	PRI.RenderSpace = CreateControl(string.format("%sRenderSpace", PRI.name), GuiRoot, CT_CONTROL)
	PRI.RenderSpace:Create3DRenderSpace()

	PRI.iconPool = ZO_ControlPool:New("PlayerRoleIndicatorIconTemplate", PlayerRoleIndicatorWindow)

	PRI.notePanel = PlayerRoleIndicatorWindow:CreateControl("$(parent)NotePanel", CT_CONTROL)
	PRI.notePanel:SetAnchor(
		TOPLEFT,
		PlayerRoleIndicatorWindow,
		TOPLEFT,
		PRI.savedVariables.notePos.x,
		PRI.savedVariables.notePos.y
	)
	PRI.notePanel:SetResizeToFitDescendents(true)
	PRI.notePanel:SetMouseEnabled(false)
	PRI.notePanel:SetMovable(false)
	PRI.notePanel:SetHidden(false)

	PRI.UpdateRoleSwitch()
	PRI.UpdateAllIconVisuals()

	EVENT_MANAGER:RegisterForEvent("PlayerRoleIndicatorActivated", EVENT_PLAYER_ACTIVATED, function()
		local function AddItem(data)
			PRI.AddCustomRoleMenuItems(data.displayName, AddCustomMenuItem, function()
				GROUP_LIST:RefreshData()
			end)
		end

		LCM:RegisterGroupListContextMenu(AddItem, LCM.CATEGORY_LATE)

		local setupEntry = GROUP_LIST.SetupGroupEntry
		function GROUP_LIST:SetupGroupEntry(control, data)
			setupEntry(self, control, data)

			local name = data.displayName
			local icon = control.leaderIcon

			if data.leader then
				icon:SetTexture("/esoui/art/lfg/lfg_leader_icon.dds")
				icon:SetColor(1, 1, 1, 1)
				icon:SetHidden(false)
			else
				local playerIndex = nil
				local customRoleSV = PRI.savedVariables
				for i = 1, customRoleSV.customNum do
					local value = customRoleSV.customRole[i]
					if value.show then
						for index, playerName in ipairs(value.players) do
							if playerName == data.displayName then
								playerIndex = index
							end
						end

						if playerIndex then
							icon:SetHidden(false)
							icon:SetTexture(value.texturePath)
							icon:SetColor(unpackColour(value.colourAlive))
							break
						end
					end
				end

				if not playerIndex then
					icon:SetHidden(true)
				end
			end
		end

		EVENT_MANAGER:UnregisterForEvent("PlayerRoleIndicatorActivated", EVENT_PLAYER_ACTIVATED)
	end)

	-- TODO: evaluate ideal frequency
	EVENT_MANAGER:RegisterForUpdate("PlayerRoleIndicatorUpdateIndicators", 10, PRI.UpdateIndicators)

	EVENT_MANAGER:RegisterForEvent("PlayerRoleIndicatorPlayerLeftGroup", EVENT_GROUP_MEMBER_LEFT, PRI.PlayerLeftGroup)
	EVENT_MANAGER:RegisterForEvent("PlayerRoleIndicatorShowNote", EVENT_UNIT_DEATH_STATE_CHANGED, PRI.ShowNote)

	EVENT_MANAGER:RegisterForEvent("PlayerRoleIndicatorZoneChanged", EVENT_PLAYER_ACTIVATED, PRI.UpdateCurrentZone)
	EVENT_MANAGER:RegisterForEvent("PlayerRoleIndicatorTrialStarted", EVENT_RAID_TRIAL_STARTED, PRI.UpdateCurrentZone)

	-- Group composition / assigned-role changes invalidate the cached GetInfo() results
	CALLBACK_MANAGER:RegisterCallback(PRI.EVENT.CUSTOM_ROLE_CHANGED, PRI.InvalidateInfoCache)
	EVENT_MANAGER:RegisterForEvent("PlayerRoleIndicatorLeaderUpdate", EVENT_LEADER_UPDATE, PRI.InvalidateInfoCache)
	EVENT_MANAGER:RegisterForEvent(
		"PlayerRoleIndicatorMemberRoleChanged",
		EVENT_GROUP_MEMBER_ROLE_CHANGED,
		PRI.InvalidateInfoCache
	)
	-- These three can change which tag maps to which person, so also resync activeIcons
	EVENT_MANAGER:RegisterForEvent("PlayerRoleIndicatorMemberJoined", EVENT_GROUP_MEMBER_JOINED, PRI.OnGroupChanged)
	EVENT_MANAGER:RegisterForEvent("PlayerRoleIndicatorMemberLeft", EVENT_GROUP_MEMBER_LEFT, PRI.OnGroupChanged)
	EVENT_MANAGER:RegisterForEvent("PlayerRoleIndicatorGroupUpdate", EVENT_GROUP_UPDATE, PRI.OnGroupChanged)
	EVENT_MANAGER:RegisterForEvent(
		"PlayerRoleIndicatorAccountNameUpdated",
		EVENT_GROUP_MEMBER_ACCOUNT_NAME_UPDATED,
		PRI.InvalidateInfoCache
	)

	EVENT_MANAGER:AddFilterForEvent(
		"PlayerRoleIndicatorPlayerLeftGroup",
		EVENT_GROUP_MEMBER_LEFT,
		REGISTER_FILTER_UNIT_TAG,
		"player"
	)
	EVENT_MANAGER:AddFilterForEvent(
		"PlayerRoleIndicatorShowNote",
		EVENT_UNIT_DEATH_STATE_CHANGED,
		REGISTER_FILTER_UNIT_TAG_PREFIX,
		"group"
	)

	EVENT_MANAGER:UnregisterForEvent(PRI.name, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(PRI.name, EVENT_ADD_ON_LOADED, PRI.intialize)
