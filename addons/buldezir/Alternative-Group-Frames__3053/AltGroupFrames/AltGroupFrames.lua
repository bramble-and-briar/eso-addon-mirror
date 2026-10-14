ZO_CreateStringId("SI_BINDING_NAME_ALTGF_TRAVEL_TO_LEADER", "Jump to group leader")

local NAME = "AltGroupFrames"
local SV_VER = 4

local EVENT = {
	MANAGER_CREATED = "AltGroupManagerCreated",
	UNIT_FRAME_CREATED = "AltGroupUnitFrameCreated",
	UNIT_FRAME_ACTIVATED = "AltGroupUnitFrameActivated",
	UNIT_FRAME_DEACTIVATED = "AltGroupUnitFrameDisactivated",
	UNIT_FRAME_DATA_CHANGED = "AltGroupUnitFrameDataChanged",
}
ALT_GROUP_FRAMES = {
	EVENT = EVENT,
	VERSION = "1.1",
}

local ROLE_ORDER = {
	LFG_ROLE_TANK,
	LFG_ROLE_HEAL,
	LFG_ROLE_DPS,
	LFG_ROLE_INVALID,
}

local ROLE_ICONS = {
	[LFG_ROLE_DPS] = "/esoui/art/tutorial/gamepad/gp_lfg_dps.dds",
	[LFG_ROLE_TANK] = "/esoui/art/tutorial/gamepad/gp_lfg_tank.dds",
	[LFG_ROLE_HEAL] = "/esoui/art/tutorial/gamepad/gp_lfg_healer.dds",
	[LFG_ROLE_INVALID] = "esoui/art/lfg/gamepad/gp_lfg_menuicon_random.dds",
}

local SHOW_NONE = 0
local SHOW_ROLES = 1
local SHOW_CLASSES = 2

local osiConfig = {
	["dead"] = false,
	["mechanic"] = false,
	["raid"] = true,
	["leader"] = false,
	["tank"] = false,
	["healer"] = false,
	["dps"] = false,
	["bg"] = false,
	["custom"] = true,
	["unique"] = true,
	["anim"] = false,
}

-------------------------------------
--Default Settings--
-------------------------------------
local DEFAULTS = {

	USE_CHARACTER_NAMES = false,
	SHOW_LEVEL = false,
	SHOW_NOGROUP = false,
	SHOW_CUSTOM_ROLE_ICONS = true,
	SHOW_CUSTOM_ODY_ICONS = true,
	SHOW_DIFFICULTY_ON_LEAD = true,
	SHOW_CUSTOM_ROLE_MENU = false,

	COLORS_SHOW = SHOW_ROLES,
	ICONS_SHOW = SHOW_CLASSES,
	SHOW_DPS_ICON = false,
	HIDE_ICON_MARKER = false,

	FULL_ALPHA_VALUE = 1,
	FADED_ALPHA_VALUE = 0.4,

	SINGLE_ROW_FRAME = true,
	FRAMES_PER_COLUMN = 12,

	FRAME_CONTAINER_BASE_OFFSET_X = 50,
	FRAME_CONTAINER_BASE_OFFSET_Y = 55,

	UNIT_FRAME_WIDTH = 230,
	UNIT_FRAME_HEIGHT = 32,
	UNIT_FRAME_PAD_X = 4,
	UNIT_FRAME_PAD_Y = 2,

	UNIT_FRAME_ALT_SIZE = { 4, 50, 55, 120, 50, 4, 2 },

	UNIT_FRAME_FONTSIZE = 22,
	UNIT_FRAME_ICONSIZE = 22,

	LFG_COLORS = {
		[LFG_ROLE_TANK] = ZO_POWER_BAR_GRADIENT_COLORS[POWERTYPE_HEALTH],
		[LFG_ROLE_HEAL] = ZO_SKILL_XP_BAR_GRADIENT_COLORS,
		[LFG_ROLE_DPS] = ZO_POWER_BAR_GRADIENT_COLORS[POWERTYPE_MAGICKA],
	},

	CLASS_COLORS = {
		[1] = { ZO_ColorDef:New("e68600"), ZO_ColorDef:New("ff9500") }, -- dk orange
		[2] = { ZO_ColorDef:New("987de8"), ZO_ColorDef:New("b8a8f0") }, -- sorc light purple
		[3] = { ZO_ColorDef:New("bd2828"), ZO_ColorDef:New("d74242") }, -- nb pale red
		[4] = { ZO_ColorDef:New("f2de00"), ZO_ColorDef:New("ffea00") }, -- plar yellow
		[5] = { ZO_ColorDef:New("209020"), ZO_ColorDef:New("24a824") }, -- warden dark green
		[6] = { ZO_ColorDef:New("4d0066"), ZO_ColorDef:New("600080") }, -- necro dark purple
		[7] = { ZO_ColorDef:New("7ed900"), ZO_ColorDef:New("86e600") }, -- arca light green
	},

	COMPANION_COLORS = { ZO_ColorDef:New("2F3630"), ZO_ColorDef:New("525C53") },

	SHIELD_COLOR = ZO_ColorDef:New(1, 0.49, 0.13, 0.80),
	TRAUMA_COLOR = ZO_ColorDef:New(0.8, 0.8, 0.8, 0.6),

	USE_CUSTOM_ORDER = false,
	CUSTOM_ORDER = {},
	CUSTOM_ORDER_TTL = 864000, -- 10 days in seconds; 0 = never prune
	CUSTOM_ORDER_MAX_SIZE = 50,
}

local CONTANER_PAD = 5

local ALTGF_MostRecentPowerUpdateHandler = ZO_MostRecentEventHandler:Subclass()

do
	local function PowerUpdateEqualityFunction(
		existingEventInfo,
		unitTag,
		powerPoolIndex,
		powerType,
		powerPool,
		powerPoolMax
	)
		local existingUnitTag = existingEventInfo[1]
		local existingPowerType = existingEventInfo[3]
		return existingUnitTag == unitTag and existingPowerType == powerType
	end

	function ALTGF_MostRecentPowerUpdateHandler:New(namespace, handlerFunction, isCompanion)
		local obj = ZO_MostRecentEventHandler.New(
			self,
			namespace,
			EVENT_POWER_UPDATE,
			PowerUpdateEqualityFunction,
			handlerFunction
		)
		if isCompanion then
			obj:AddFilterForEvent(REGISTER_FILTER_UNIT_TAG, "companion")
		else
			obj:AddFilterForEvent(REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
		end

		obj:AddFilterForEvent(REGISTER_FILTER_POWER_TYPE, POWERTYPE_HEALTH)

		return obj
	end
end

local UnitFrames, UnitFramesManager, UnitFrame, UnitFrameCompanion, UnitFrameSettings, PRI, ODY

-------------------------------------
--Group Member Frame Settings--
-------------------------------------
local UnitFrameSettings = ZO_DataSourceObject:Subclass()
function UnitFrameSettings:New(...)
	local obj = ZO_DataSourceObject.New(self)
	obj:Initialize(...)
	return obj
end

function UnitFrameSettings:Initialize(parent)
	self:SetDataSource(parent)
end

-------------------------------------
--Group Member Frame--
-------------------------------------

local UnitFrame = ZO_Object:Subclass()
function UnitFrame:New(...)
	local obj = ZO_Object.New(self)
	obj:Initialize(...)
	return obj
end

function UnitFrame:Initialize(unitTag, index, container)
	self.unitTag = unitTag
	self.index = index
	self.container = container

	self.isActive = false
	self.isCompanion = unitTag == "companion" or IsGroupCompanionUnitTag(unitTag)

	-- data --
	self.role = LFG_ROLE_INVALID
	self.classId = nil
	self.accountName = ""
	self.characterName = ""
	self.isNearby = false
	self.isDead = false
	self.isOnline = false

	self.control = CreateControlFromVirtual("ALTGF_UnitFrame" .. unitTag, container:GetControl(), "ALTGF_UnitFrame")
	self.control:SetParent(container:GetControl())
	self.control.m_object = self
	self.borderControl = GetControl(self.control, "Border")
	self.nameControl = GetControl(self.control, "Name")
	self.levelControl = GetControl(self.control, "Level")
	self.iconControl = GetControl(self.control, "Icon")
	self.resourceNumbersControl = GetControl(self.control, "ResourceNumbers")
	self.healthBarControl = GetControl(self.control, "HP")
	self.shieldBarControl = GetControl(self.control, "Shield")
	self.traumaBarControl = GetControl(self.control, "Trauma")

	self.curHP = 0
	self.maxHP = 0
	self.curShield = 0
	self.curTrauma = 0
	self.hasMarker = false

	self.fadeComponents = {
		self.nameControl,
		self.levelControl,
		self.iconControl,
		self.resourceNumbersControl,
		self.healthBarControl,
		self.shieldBarControl,
		self.traumaBarControl,
	}

	self:RefreshView()
	self:RefreshPosition()

	CALLBACK_MANAGER:FireCallbacks(EVENT.UNIT_FRAME_CREATED, self)
end

-- on change sort index or change settings
function UnitFrame:RefreshView()
	local settings = self.container.SETTINGS
	self.control:SetDimensions(settings.UNIT_FRAME_WIDTH, settings.UNIT_FRAME_HEIGHT)

	local font = "$(GAMEPAD_MEDIUM_FONT)|" .. settings.UNIT_FRAME_FONTSIZE .. "|soft-shadow-thick"
	self.nameControl:SetFont(font)
	self.resourceNumbersControl:SetFont(font)

	local fontLevel = "$(GAMEPAD_MEDIUM_FONT)|" .. settings.UNIT_FRAME_FONTSIZE * 0.7 .. "|soft-shadow-thin"
	self.levelControl:SetFont(fontLevel)

	PRI = settings.SHOW_CUSTOM_ROLE_ICONS and PlayerRoleIndicator or nil
	ODY = settings.SHOW_CUSTOM_ODY_ICONS and OSI or nil

	self.iconControl:ClearAnchors()
	self.nameControl:ClearAnchors()
	self.levelControl:ClearAnchors()
	self.resourceNumbersControl:ClearAnchors()

	if self.container.SETTINGS.SINGLE_ROW_FRAME then
		self.levelControl:SetTransformRotationZ(math.rad(90))
		self.levelControl:SetAnchor(RIGHT, self.control, RIGHT, 0, 0)
		self.iconControl:SetAnchor(LEFT, self.control, LEFT, 5, 0)
		self.nameControl:SetAnchor(LEFT, self.iconControl, RIGHT, 2, 0)
		self.resourceNumbersControl:SetAnchor(RIGHT, self.levelControl, LEFT, -4, 0)
		self.nameControl:SetAnchor(RIGHT, self.resourceNumbersControl, LEFT, -2, 0)
	else -- What xml describes
		self.levelControl:SetTransformRotationZ(0)
		self.nameControl:SetAnchor(TOPLEFT, self.control, TOPLEFT, 4, -2)
		self.nameControl:SetAnchor(TOPRIGHT, self.control, TOPRIGHT, -4, 0)
		self.resourceNumbersControl:SetAnchor(BOTTOMRIGHT, self.control, BOTTOMRIGHT, -4, 0)
		self.iconControl:SetAnchor(BOTTOMLEFT, self.control, BOTTOMLEFT, 4, 0)
		self.levelControl:SetAnchor(BOTTOMLEFT, self.iconControl, BOTTOMRIGHT, 0, -2)
		self.levelControl:SetAnchor(BOTTOMRIGHT, self.resourceNumbersControl, BOTTOMLEFT, -4, -2)
	end

	self.shieldBarControl:SetColor(settings.SHIELD_COLOR:UnpackRGBA())
	self.traumaBarControl:SetColor(settings.TRAUMA_COLOR:UnpackRGBA())
	self:RefreshColor()
end

function UnitFrame:RefreshPosition()
	local settings = self.container.SETTINGS
	local col = zo_ceil(self.index / settings.FRAMES_PER_COLUMN)
	local row = zo_mod(self.index - 1, settings.FRAMES_PER_COLUMN)
	local x = ((col - 1) * (settings.UNIT_FRAME_WIDTH + settings.UNIT_FRAME_PAD_X)) + CONTANER_PAD
	local y = (row * (settings.UNIT_FRAME_HEIGHT + settings.UNIT_FRAME_PAD_Y)) + CONTANER_PAD
	self.control:ClearAnchors()
	self.control:SetAnchor(TOPLEFT, self.container:GetControl(), TOPLEFT, x, y)
end

-- return bool isChanged
function UnitFrame:SetSortIndex(index)
	local isChanged = self.index ~= index
	self.index = index
	self:RefreshPosition()

	return isChanged
end

function UnitFrame:RefreshData(force)
	self.accountName = GetUnitDisplayName(self.unitTag)
	self.characterName = GetUnitName(self.unitTag)
	self.classId = GetUnitClassId(self.unitTag)

	self:RefreshName()
	self:RefreshLevel()
	self:RefreshIcon()
	self:OnRoleChange(self.unitTag == "player" and GetSelectedLFGRole() or GetGroupMemberSelectedRole(self.unitTag))
	self:OnSupportRangeUpdate(IsUnitInGroupSupportRange(self.unitTag))
	self:OnDeathStatusChange(IsUnitDead(self.unitTag), true)
	self:OnOnlineStatusChange(IsUnitOnline(self.unitTag))

	if force then
		local health, maxHealth = GetUnitPower(self.unitTag, POWERTYPE_HEALTH)
		self:OnUpdateHp(health, maxHealth, true)
	end

	CALLBACK_MANAGER:FireCallbacks(EVENT.UNIT_FRAME_DATA_CHANGED, self)
end

function UnitFrame:OnUpdate()
	self:RefreshName()
	self:RefreshIcon()
end

function UnitFrame:GetIconPath()
	local targetMarkerType = GetUnitTargetMarkerType(self.unitTag)
	if targetMarkerType ~= TARGET_MARKER_TYPE_NONE then
		return ZO_GetPlatformTargetMarkerIcon(targetMarkerType)
	end
	if PRI ~= nil then
		local role = PRI.GetRole(self.unitTag)
		if role ~= nil and role.name and role.show and role.showOnAlive and role.icon.texturePath ~= nil then
			return role.icon.texturePath
		end
	end
	if ODY ~= nil then
		local texture, color, size, hodor, offset =
			ODY.GetIconDataForPlayer(GetUnitDisplayName(self.unitTag), osiConfig, self.unitTag)

		if texture ~= nil then
			return texture
		end
	end
	if IsUnitGroupLeader(self.unitTag) then
		if not self.container.SETTINGS.SHOW_DIFFICULTY_ON_LEAD then
			return "/esoui/art/compass/groupleader.dds"
		elseif IsGroupUsingVeteranDifficulty() then
			return "esoui/art/lfg/gamepad/lfg_activityicon_veterandungeon.dds"
		else
			return "esoui/art/lfg/gamepad/lfg_activityicon_normaldungeon.dds"
		end
	end
	return nil
end

function UnitFrame:RefreshName()
	local name = self.accountName:sub(2)
	if self.container.SETTINGS.USE_CHARACTER_NAMES then
		name = self.characterName
	end

	local iconPath = self:GetIconPath()
	if iconPath ~= nil then
		local xy = self.container.SETTINGS.UNIT_FRAME_ICONSIZE
		name = zo_iconTextFormatNoSpace(iconPath, xy - 2, xy - 2, name)
		self.hasMarker = true
	else
		self.hasMarker = false
	end
	self.nameControl:SetText(name)
end

function UnitFrame:RefreshLevel()
	if self.container.SETTINGS.SHOW_LEVEL and IsUnitOnline(self.unitTag) then
		local xy = self.container.SETTINGS.UNIT_FRAME_ICONSIZE
		-- Rather than showing icon, save space by showing Level as red and CP as white
		local unitCP = GetUnitChampionPoints(self.unitTag)
		if unitCP > 0 then
			self.levelControl:SetText(unitCP)
			self.levelControl:SetColor(1, 1, 1, 1)
		else
			self.levelControl:SetText(GetUnitLevel(self.unitTag))
			self.levelControl:SetColor(1, 0, 0, 1)
		end
		self.levelControl:SetHidden(false)
	else
		self.levelControl:SetHidden(true)
		self.levelControl:SetText("")
	end
end

function UnitFrame:RefreshIcon()
	local iconPath = nil
	if self.container.SETTINGS.HIDE_ICON_MARKER and self.hasMarker then
		-- hide icon
	elseif self.container.SETTINGS.ICONS_SHOW == SHOW_CLASSES then
		if self.classId and self.classId > 0 then
			iconPath = select(8, GetClassInfo(GetClassIndexById(self.classId)))
		else
			iconPath = "esoui/art/lfg/gamepad/gp_lfg_menuicon_random.dds"
		end
	elseif self.container.SETTINGS.ICONS_SHOW ~= SHOW_ROLES or IsActiveWorldBattleground() then
		-- no icon
	elseif self.container.SETTINGS.SHOW_DPS_ICON or self.role ~= LFG_ROLE_DPS then
		iconPath = ROLE_ICONS[self.role]
	end

	if iconPath ~= nil then
		local xy = self.container.SETTINGS.UNIT_FRAME_ICONSIZE
		self.iconControl:SetHidden(false)
		self.iconControl:SetText(zo_iconFormat(iconPath, xy, xy))
	else
		self.iconControl:SetHidden(true)
		self.iconControl:SetText("")
	end
end

function UnitFrame:RefreshColor()
	if self.container.SETTINGS.COLORS_SHOW == SHOW_CLASSES then
		ZO_StatusBar_SetGradientColor(
			self.healthBarControl,
			self.container.SETTINGS.CLASS_COLORS[GetClassIndexById(self.classId)]
		)
	elseif self.container.SETTINGS.COLORS_SHOW == SHOW_ROLES and self.role ~= LFG_ROLE_INVALID then
		ZO_StatusBar_SetGradientColor(self.healthBarControl, self.container.SETTINGS.LFG_COLORS[self.role])
	elseif IsActiveWorldBattleground() then
		ZO_StatusBar_SetGradientColor(self.healthBarControl, self.container.SETTINGS.LFG_COLORS[LFG_ROLE_DPS])
	else
		ZO_StatusBar_SetGradientColor(self.healthBarControl, ZO_POWER_BAR_GRADIENT_COLORS[POWERTYPE_HEALTH])
	end
end

function UnitFrame:OnRoleChange(role)
	-- change role only if role changed to valid
	if role ~= LFG_ROLE_INVALID then
		self.role = role
		self:RefreshColor()
		self:RefreshIcon()
		return true
	elseif IsActiveWorldBattleground() then
		self:RefreshColor()
		self:RefreshIcon()
		return true
	end
	return false
end

function UnitFrame:OnDeathStatusChange(isDead)
	self.isDead = isDead
	if isDead then
		local xy = self.container.SETTINGS.UNIT_FRAME_ICONSIZE
		self.resourceNumbersControl:SetText(zo_iconFormat("esoui/art/icons/mapkey/mapkey_groupboss.dds", xy, xy))
		self:OnUpdateHp(0, self.maxHP, true)
		self:OnUpdateShield(0, true)
		self:OnUpdateTrauma(0, true)

		self:UpdateResurrectionState()
	end
end

function UnitFrame:OnOnlineStatusChange(isOnline)
	self.isOnline = isOnline
	if isOnline then
		local health, maxHealth = GetUnitPower(self.unitTag, POWERTYPE_HEALTH)
		self:OnUpdateHp(health, maxHealth, true)
		self:OnUpdateShield(0, true)
		self:OnUpdateTrauma(0, true)

		self.healthBarControl:SetHidden(false)
		self.shieldBarControl:SetHidden(false)
		self.resourceNumbersControl:SetHidden(false)
	else
		self.healthBarControl:SetHidden(true)
		self.shieldBarControl:SetHidden(true)
		self.resourceNumbersControl:SetText("")
		self.resourceNumbersControl:SetHidden(true)
	end
end

function UnitFrame:OnSupportRangeUpdate(isNearby)
	self.isNearby = isNearby
	local alphaValue = isNearby and self.container.SETTINGS.FULL_ALPHA_VALUE
		or self.container.SETTINGS.FADED_ALPHA_VALUE
	for i = 1, #self.fadeComponents do
		self.fadeComponents[i]:SetAlpha(alphaValue)
	end
end

function UnitFrame:OnUpdateShield(value, force)
	if self.isDead then
		value = 0
	end
	self.curShield = value
	ZO_StatusBar_SmoothTransition(self.shieldBarControl, value, self.maxHP, force)
	self:UpdateResourceNumbers(self.curHP, self.maxHP, value, self.curTrauma)
end

function UnitFrame:OnUpdateTrauma(value, force)
	if self.isDead then
		value = 0
	end
	self.curTrauma = value
	ZO_StatusBar_SmoothTransition(self.traumaBarControl, value, self.maxHP, force)
	self:UpdateResourceNumbers(self.curHP, self.maxHP, self.curShield, value)
end

function UnitFrame:OnUpdateHp(health, maxHealth, force)
	if self.isDead then
		health = 0
	end
	self.curHP = health
	self.maxHP = maxHealth
	ZO_StatusBar_SmoothTransition(self.healthBarControl, health, maxHealth, force)
	self:UpdateResourceNumbers(health, maxHealth, self.curShield, self.curTrauma)
end

function UnitFrame:UpdateResourceNumbers(health, maxHealth, shield, trauma)
	if not self.isDead then
		local text = ""
		if (shield and shield > 0) or (trauma and trauma > 0) then
			text = ZO_AbbreviateAndLocalizeNumber(health, NUMBER_ABBREVIATION_PRECISION_LARGEST_UNIT, false) .. "["
			if shield and shield > 0 then
				text = text .. ZO_AbbreviateAndLocalizeNumber(shield, NUMBER_ABBREVIATION_PRECISION_LARGEST_UNIT, false)
			end
			if trauma and trauma > 0 then
				text = text
					.. "-"
					.. ZO_AbbreviateAndLocalizeNumber(trauma, NUMBER_ABBREVIATION_PRECISION_LARGEST_UNIT, false)
			end
			text = text .. "]"
		else
			text = ZO_AbbreviateAndLocalizeNumber(health, NUMBER_ABBREVIATION_PRECISION_TENTHS, false)
		end
		self.resourceNumbersControl:SetText(text)
	end
end

function UnitFrame:UpdateResurrectionState()
	EVENT_MANAGER:UnregisterForUpdate(NAME .. "UpdateResurrectionState" .. self.unitTag)
	local xy = self.container.SETTINGS.UNIT_FRAME_ICONSIZE

	if IsUnitDead(self.unitTag) then
		if IsUnitBeingResurrected(self.unitTag) then
			self.resourceNumbersControl:SetText(
				zo_iconTextFormat("esoui/art/icons/mapkey/mapkey_groupboss.dds", xy, xy, "Ressing...")
			)
		elseif DoesUnitHaveResurrectPending(self.unitTag) then
			self.resourceNumbersControl:SetText(
				zo_iconTextFormat("esoui/art/icons/mapkey/mapkey_groupboss.dds", xy, xy, "Pending...")
			)
		else
			self.resourceNumbersControl:SetText(zo_iconFormat("esoui/art/icons/mapkey/mapkey_groupboss.dds", xy, xy))
		end
		EVENT_MANAGER:RegisterForUpdate(NAME .. "UpdateResurrectionState" .. self.unitTag, 500, function()
			self:UpdateResurrectionState()
		end)
	elseif IsUnitReincarnating(self.unitTag) then
		self.resourceNumbersControl:SetText(
			zo_iconTextFormat("esoui/art/icons/mapkey/mapkey_groupboss.dds", xy, xy, "Ghost...")
		)

		EVENT_MANAGER:RegisterForUpdate(NAME .. "UpdateResurrectionState" .. self.unitTag, 500, function()
			self:UpdateResurrectionState()
		end)
	else
		local health, maxHealth = GetUnitPower(self.unitTag, POWERTYPE_HEALTH)
		self:UpdateResourceNumbers(health, maxHealth, 0)
	end
end

function UnitFrame:ResetBorder()
	self.borderControl:SetEdgeColor(0, 0, 0, 0)
end

function UnitFrame:SetBorderColor(r, g, b, a)
	self.borderControl:SetEdgeColor(r, g, b, a)
end

function UnitFrame:IsActive()
	return self.isActive
end

function UnitFrame:SetActive(active)
	self.isActive = active
	self.control:SetHidden(not active)
	local e = active and EVENT.UNIT_FRAME_ACTIVATED or EVENT.UNIT_FRAME_DEACTIVATED
	CALLBACK_MANAGER:FireCallbacks(e, self)
end

function UnitFrame:IsCompanion()
	return self.isCompanion
end

function UnitFrame:GetControl()
	return self.control
end

function UnitFrame:GetUnitTag()
	return self.unitTag
end

function UnitFrame:HandleMouseEnter()
	InitializeTooltip(InformationTooltip, self.control, TOP, 0, 0)
	local iconPath = self:GetIconPath()
	if iconPath ~= nil then
		SetTooltipText(InformationTooltip, zo_iconTextFormat(iconPath, 22, 22, self.accountName))
	else
		SetTooltipText(InformationTooltip, self.accountName)
	end
	InformationTooltip:AddLine(self.characterName)
	ZO_Tooltip_AddDivider(InformationTooltip)

	if IsUnitOnline(self.unitTag) then
		local health, maxHealth = GetUnitPower(self.unitTag, POWERTYPE_HEALTH)
		local hp = health .. " / " .. maxHealth
		local classIconPath = select(8, GetClassInfo(GetClassIndexById(GetUnitClassId(self.unitTag))))
		InformationTooltip:AddLine(zo_iconFormat(classIconPath, 22, 22) .. GetUnitClass(self.unitTag))
		InformationTooltip:AddLine(
			zo_iconTextFormat("esoui/art/icons/alchemy/crafting_alchemy_trait_restorehealth.dds", 22, 22, hp)
		)
		InformationTooltip:AddLine(
			zo_iconTextFormatNoSpace(
				"esoui/art/compass/ava_outpost_neutral.dds",
				22,
				22,
				ZO_CachedStrFormat(SI_ZONE_NAME, GetUnitZone(self.unitTag))
			)
		)
	else
		InformationTooltip:AddLine(GetString(SI_PLAYERSTATUS4))
	end
end

function UnitFrame:HandleMouseExit()
	ClearTooltip(InformationTooltip)
end

function UnitFrame:HandleMouseDown(button)
	if button == MOUSE_BUTTON_INDEX_LEFT and self.container.SAVEVARS.USE_CUSTOM_ORDER and not self.isCompanion then
		self.container:StartDrag(self)
	end
end

function UnitFrame:HandleMouseUp(button, upInside)
	if button == MOUSE_BUTTON_INDEX_LEFT and self.container.dragState then
		self.container:EndDrag()
		return
	end
	if button == MOUSE_BUTTON_INDEX_RIGHT and upInside then
		ClearMenu()

		local isPlayer = AreUnitsEqual(self.unitTag, "player")
		local modificationRequiresVoting = DoesGroupModificationRequireVote()

		if isPlayer or self.accountName == "" then
			-- Yourself or your own companion
			AddMenuItem(GetString(SI_GROUP_LIST_MENU_LEAVE_GROUP), function()
				GroupLeave()
			end)
		elseif IsUnitOnline(self.unitTag) then
			-- Other player or their companion, which is marked with the owner's accountName
			AddMenuItem(GetString(SI_SOCIAL_LIST_PANEL_WHISPER), function()
				StartChatInput("", CHAT_CHANNEL_WHISPER, self.accountName)
			end)
			if CanJumpToGroupMember(self.unitTag) then
				AddMenuItem(GetString(SI_SOCIAL_MENU_JUMP_TO_PLAYER), function()
					JumpToGroupMember(self.accountName)
				end)
			end
		end

		if IsUnitGroupLeader("player") then
			if isPlayer or self.accountName == "" then
				if not modificationRequiresVoting then
					AddMenuItem(GetString(SI_GROUP_LIST_MENU_DISBAND_GROUP), function()
						ZO_Dialogs_ShowDialog("GROUP_DISBAND_DIALOG")
					end)
				end
			else
				if IsUnitOnline(self.unitTag) then
					AddMenuItem(GetString(SI_GROUP_LIST_MENU_PROMOTE_TO_LEADER), function()
						GroupPromote(self.unitTag)
					end)
				end
				if not modificationRequiresVoting then
					AddMenuItem(GetString(SI_GROUP_LIST_MENU_KICK_FROM_GROUP), function()
						GroupKick(self.unitTag)
					end)
				end
			end
		end

		if modificationRequiresVoting and not isPlayer then
			AddMenuItem(GetString(SI_GROUP_LIST_MENU_VOTE_KICK_FROM_GROUP), function()
				BeginGroupElection(
					GROUP_ELECTION_TYPE_KICK_MEMBER,
					ZO_GROUP_ELECTION_DESCRIPTORS.NONE,
					self.unitTag,
					GROUP_ELECTION_FLAGS_IGNORE_OFFLINE_MEMBERS
				)
			end)
		end

		-- PlayerRoleIndicator custom role assignments
		if not isPlayer and self.accountName ~= "" and PRI and self.container.SETTINGS.SHOW_CUSTOM_ROLE_MENU then
			PRI.AddCustomRoleMenuItems(self.accountName)
		end

		ShowMenu(self.container)
	end
end

-------------------------------------
--Companion Frame--
-------------------------------------

local UnitFrameCompanion = UnitFrame:Subclass()
function UnitFrameCompanion:New(...)
	return UnitFrame.New(self, ...)
end

function UnitFrameCompanion:RefreshData(force)
	if
		self.unitTag == "companion"
		or GetUnitDisplayName(GetGroupUnitTagByCompanionUnitTag(self.unitTag)) == GetUnitDisplayName("player")
	then
		self.accountName = ""
		self.characterName = zo_strformat(SI_COMPANION_NAME_FORMATTER, GetCompanionName(GetActiveCompanionDefId()))
	else
		self.accountName = GetUnitDisplayName(GetGroupUnitTagByCompanionUnitTag(self.unitTag))
		self.characterName = self.accountName
		if self.container.SETTINGS.USE_CHARACTER_NAMES then
			self.characterName = GetUnitName(GetGroupUnitTagByCompanionUnitTag(self.unitTag))
		end
		if string.sub(self.characterName, -1) == "s" then
			self.characterName = self.characterName .. "' Companion"
		else
			self.characterName = self.characterName .. "'s Companion"
		end
	end
	self.classId = GetUnitClassId(self.unitTag)

	self:RefreshName()
	self:RefreshIcon()
	self:OnRoleChange(GetGroupMemberSelectedRole(self.unitTag))
	self:OnSupportRangeUpdate(IsUnitInGroupSupportRange(self.unitTag))
	self:OnDeathStatusChange(IsUnitDead(self.unitTag), true)
	self:OnOnlineStatusChange(IsUnitOnline(self.unitTag))

	if force then
		local health, maxHealth = GetUnitPower(self.unitTag, POWERTYPE_HEALTH)
		self:OnUpdateHp(health, maxHealth, true)
	end

	CALLBACK_MANAGER:FireCallbacks(EVENT.UNIT_FRAME_DATA_CHANGED, self)
end

function UnitFrameCompanion:RefreshName()
	self.nameControl:SetText(self.characterName)
end

function UnitFrameCompanion:RefreshIcon()
	if self.container.SETTINGS.SHOW_CLASS_ICONS then
		local xy = self.container.SETTINGS.UNIT_FRAME_ICONSIZE
		self.iconControl:SetHidden(false)
		self.iconControl:SetText(zo_iconFormat("esoui/art/companion/gamepad/gp_category_u30_allies.dds", xy, xy))
	else
		self.iconControl:SetHidden(true)
		self.iconControl:SetText("")
	end
end

function UnitFrameCompanion:RefreshColor()
	ZO_StatusBar_SetGradientColor(self.healthBarControl, self.container.SETTINGS.COMPANION_COLORS)
end

function UnitFrameCompanion:HandleMouseEnter()
	return nil
end

-------------------------------------
--Group Frames Manager--
--Used to manage the UnitFrame objects according to UnitTags ("group1", "group2", etc...)--
-------------------------------------

local UnitFramesManager = ZO_Object:Subclass()
function UnitFramesManager:New(...)
	local obj = ZO_Object.New(self)
	obj:Initialize(...)
	return obj
end

function UnitFramesManager:Initialize(topLevelControl)
	self.EVENT = EVENT
	self.dirty = false
	self.control = topLevelControl
	self.borderControl = GetControl(self.control, "Border")
	self.backgroundControl = GetControl(self.control, "Background")
	self.control.m_object = self
	self.groupSize = 0
	self.unitFrames = {}
	self.SAVEVARS = ZO_SavedVars:NewAccountWide("AltGroupFramesSavedVariables", SV_VER, nil, DEFAULTS)
	self.DEFAULTS = DEFAULTS

	-- RECREATE color objects
	for k, v in pairs(self.SAVEVARS.LFG_COLORS) do
		self.SAVEVARS.LFG_COLORS[k] = { ZO_ColorDef:New(v[1]), ZO_ColorDef:New(v[2]) }
	end
	for k, v in pairs(self.SAVEVARS.CLASS_COLORS) do
		self.SAVEVARS.CLASS_COLORS[k] = { ZO_ColorDef:New(v[1]), ZO_ColorDef:New(v[2]) }
	end
	self.SAVEVARS.COMPANION_COLORS =
		{ ZO_ColorDef:New(self.SAVEVARS.COMPANION_COLORS[1]), ZO_ColorDef:New(self.SAVEVARS.COMPANION_COLORS[2]) }
	self.SAVEVARS.SHIELD_COLOR = ZO_ColorDef:New(self.SAVEVARS.SHIELD_COLOR)
	self.SAVEVARS.TRAUMA_COLOR = ZO_ColorDef:New(self.SAVEVARS.TRAUMA_COLOR)

	self.SETTINGS = UnitFrameSettings:New(self.SAVEVARS)

	--self:RefreshData()
	--self:RefreshView()
	self:RegisterEvents(topLevelControl)
	self:InitDragControls()
	self:PruneCustomOrder()

	CALLBACK_MANAGER:FireCallbacks(EVENT.MANAGER_CREATED, self)
end

function UnitFramesManager:RegisterEvents(topLevelControl)
	local function RegisterDelayedRefresh()
		self:SetIsDirty(true)
	end

	local osiHooked = false
	local function OnPlayerActivated()
		RegisterDelayedRefresh()
		for _, unitFrame in pairs(self.unitFrames) do
			if unitFrame:IsActive() then
				unitFrame:OnSupportRangeUpdate(IsUnitInGroupSupportRange(unitFrame.unitTag))
			end
		end
		-- Hook OSI.RefreshData once to propagate icon changes to ALTGF
		if not osiHooked and OSI ~= nil then
			osiHooked = true
			ZO_PostHook(OSI, "RefreshData", RegisterDelayedRefresh)
		end
	end

	local function OnUpdate()
		for _, unitFrame in pairs(self.unitFrames) do
			if unitFrame:IsActive() then
				unitFrame:OnUpdate()
			end
		end
	end

	local function OnConnectedStatus(_, unitTag, isOnline)
		self:GetFrame(unitTag):OnOnlineStatusChange(isOnline)
		self:ReorderFrames()
	end

	local function OnRoleChanged(_, unitTag, newRole)
		if self:GetFrame(unitTag):OnRoleChange(newRole) then
			self:ReorderFrames()
		end
	end

	local function onVisualPower(
		_,
		unitTag,
		unitAttributeVisual,
		statType,
		attributeType,
		powerType,
		oldValue,
		newValue,
		oldMaxValue,
		newMaxValue
	)
		local value = oldMaxValue == nil and oldValue or newValue
		if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING then
			self:GetFrame(unitTag):OnUpdateShield(value, false)
		elseif unitAttributeVisual == ATTRIBUTE_VISUAL_TRAUMA then
			self:GetFrame(unitTag):OnUpdateTrauma(value, false)
		end
	end

	local function onVisualPowerRemoved(
		_,
		unitTag,
		unitAttributeVisual,
		statType,
		attributeType,
		powerType,
		value,
		maxValue
	)
		if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING then
			self:GetFrame(unitTag):OnUpdateShield(0, false)
		elseif unitAttributeVisual == ATTRIBUTE_VISUAL_TRAUMA then
			self:GetFrame(unitTag):OnUpdateTrauma(0, false)
		end
	end

	local function OnPowerUpdate(unitTag, _, _, powerPool, powerPoolMax)
		-- already filtered with AddFilterForEvent in ALTGF_MostRecentPowerUpdateHandler
		self:GetFrame(unitTag):OnUpdateHp(powerPool, powerPoolMax, false)
	end

	topLevelControl:RegisterForEvent(EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
	topLevelControl:RegisterForEvent(EVENT_GROUP_MEMBER_LEFT, RegisterDelayedRefresh)
	topLevelControl:RegisterForEvent(EVENT_GROUP_UPDATE, RegisterDelayedRefresh)
	topLevelControl:RegisterForEvent(EVENT_LEADER_UPDATE, OnUpdate)
	topLevelControl:RegisterForEvent(EVENT_GROUP_VETERAN_DIFFICULTY_CHANGED, function()
		self:GetFrame(GetGroupLeaderUnitTag()):OnUpdate()
	end)
	topLevelControl:RegisterForEvent(EVENT_TARGET_MARKER_UPDATE, OnUpdate)
	topLevelControl:RegisterForEvent(EVENT_GROUP_MEMBER_CONNECTED_STATUS, OnConnectedStatus)
	topLevelControl:AddFilterForEvent(EVENT_GROUP_MEMBER_CONNECTED_STATUS, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
	topLevelControl:RegisterForEvent(EVENT_UNIT_CREATED, RegisterDelayedRefresh)
	topLevelControl:AddFilterForEvent(EVENT_UNIT_CREATED, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
	topLevelControl:RegisterForEvent(EVENT_UNIT_DESTROYED, RegisterDelayedRefresh)
	topLevelControl:AddFilterForEvent(EVENT_UNIT_DESTROYED, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
	topLevelControl:RegisterForEvent(EVENT_ACTIVE_COMPANION_STATE_CHANGED, RegisterDelayedRefresh)
	topLevelControl:RegisterForEvent(EVENT_GROUP_MEMBER_ROLE_CHANGED, OnRoleChanged)
	topLevelControl:AddFilterForEvent(EVENT_GROUP_MEMBER_ROLE_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
	topLevelControl:RegisterForEvent(EVENT_GROUP_SUPPORT_RANGE_UPDATE, function(_, unitTag, isNearby)
		self:GetFrame(unitTag):OnSupportRangeUpdate(isNearby)
	end)
	topLevelControl:AddFilterForEvent(EVENT_GROUP_SUPPORT_RANGE_UPDATE, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
	topLevelControl:RegisterForEvent(EVENT_UNIT_DEATH_STATE_CHANGED, function(_, unitTag, isDead)
		self:GetFrame(unitTag):OnDeathStatusChange(isDead)
	end) -- может баговаться
	topLevelControl:AddFilterForEvent(EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
	topLevelControl:RegisterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, onVisualPower)
	topLevelControl:AddFilterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
	topLevelControl:RegisterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, onVisualPower)
	topLevelControl:AddFilterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
	topLevelControl:RegisterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, onVisualPowerRemoved)
	topLevelControl:AddFilterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")

	ALTGF_MostRecentPowerUpdateHandler:New("ALTGF_GroupList_Manager", OnPowerUpdate, false)
	ALTGF_MostRecentPowerUpdateHandler:New("ALTGF_GroupList_ManagerComp", OnPowerUpdate, true)

	-- Refresh frames when PlayerRoleIndicator custom role assignments change
	CALLBACK_MANAGER:RegisterCallback("PRI_CustomRoleChanged", RegisterDelayedRefresh)

	local gamepadSettingsOverride
	local function applyGamepadStyle()
		gamepadSettingsOverride = self:OverrideSettings()
		gamepadSettingsOverride.UNIT_FRAME_WIDTH = self.SAVEVARS.UNIT_FRAME_WIDTH + 40
		gamepadSettingsOverride.UNIT_FRAME_HEIGHT = self.SAVEVARS.UNIT_FRAME_HEIGHT + 10
		gamepadSettingsOverride.UNIT_FRAME_PAD_X = self.SAVEVARS.UNIT_FRAME_PAD_X + 2
		gamepadSettingsOverride.UNIT_FRAME_PAD_Y = self.SAVEVARS.UNIT_FRAME_PAD_Y + 2
		gamepadSettingsOverride.UNIT_FRAME_FONTSIZE = 27
		gamepadSettingsOverride.UNIT_FRAME_ICONSIZE = 27
		self:RefreshView(true)
	end
	ZO_PlatformStyle:New(function(styleFunc)
		styleFunc()
	end, function()
		if gamepadSettingsOverride ~= nil then
			self:RemoveOverrideSettings(gamepadSettingsOverride)
			gamepadSettingsOverride = nil
			self:RefreshView(true)
		end
	end, applyGamepadStyle)
end

-- use only once per module/addon
function UnitFramesManager:OverrideSettings()
	local current = self.SETTINGS
	local new = UnitFrameSettings:New(current)
	current.overridenBy = new
	self.SETTINGS = new
	return new
end

function UnitFramesManager:RemoveOverrideSettings(settingsObj)
	local parent = settingsObj:GetDataSource()
	local overridenBy = rawget(settingsObj, "overridenBy")
	if overridenBy ~= nil then
		-- if settings was already overriden by other, current pointer (self.SETTINGS) will point to other object
		-- so we need to remove settingsObj from chain, and "connect" ends
		overridenBy:SetDataSource(parent)
	else
		-- if it was last element in chain, just update pointer
		parent.overridenBy = nil
		self.SETTINGS = parent
	end
	settingsObj = nil
end

function UnitFramesManager:ForEach(callback)
	for _, unitFrame in pairs(self.unitFrames) do
		callback(unitFrame)
	end
end

function UnitFramesManager:GetControl()
	return self.control
end

function UnitFramesManager:SaveLoc()
	self.SAVEVARS.FRAME_CONTAINER_BASE_OFFSET_X = zo_round(self.control:GetLeft())
	self.SAVEVARS.FRAME_CONTAINER_BASE_OFFSET_Y = zo_round(self.control:GetTop())
end

function UnitFramesManager:SaveSize()
	local maxCol = zo_ceil(GROUP_SIZE_MAX / self.SETTINGS.FRAMES_PER_COLUMN)
	local maxRow = zo_min(GROUP_SIZE_MAX, self.SETTINGS.FRAMES_PER_COLUMN)

	local x = self.control:GetWidth() - 2 * CONTANER_PAD
	local y = self.control:GetHeight() - 2 * CONTANER_PAD

	self.SAVEVARS.UNIT_FRAME_WIDTH = zo_round(x / maxCol) - self.SETTINGS.UNIT_FRAME_PAD_X
	self.SAVEVARS.UNIT_FRAME_HEIGHT = zo_round(y / maxRow) - self.SETTINGS.UNIT_FRAME_PAD_Y

	self:RefreshView(true)
end

function UnitFramesManager:UnlockUI(movable)
	self.control:SetMouseEnabled(movable)
	self.control:SetMovable(movable)
	self.control:SetResizeHandleSize(movable and 5 or 0)
	self.borderControl:SetEdgeColor(0.75, 0.75, 0.75, movable and 1. or 0.)
	self.backgroundControl:SetColor(0.75, 0.75, 0.75, movable and 0.5 or 0.)
	self.control:SetHandler("OnMouseEnter", movable and function()
		WINDOW_MANAGER:SetMouseCursor(MOUSE_CURSOR_PAN)
	end or nil)
	self.control:SetHandler("OnMouseExit", movable and function()
		WINDOW_MANAGER:SetMouseCursor(MOUSE_CURSOR_DEFAULT_CURSOR)
	end or nil)
end

function UnitFramesManager:RefreshView(withElems)
	self.control:StopMovingOrResizing()

	local maxCol = zo_ceil(GROUP_SIZE_MAX / self.SETTINGS.FRAMES_PER_COLUMN)
	local maxRow = zo_min(GROUP_SIZE_MAX, self.SETTINGS.FRAMES_PER_COLUMN)

	local x = maxCol * (self.SETTINGS.UNIT_FRAME_WIDTH + self.SETTINGS.UNIT_FRAME_PAD_X)
	local y = maxRow * (self.SETTINGS.UNIT_FRAME_HEIGHT + self.SETTINGS.UNIT_FRAME_PAD_Y)

	self.control:SetDimensions(x + (CONTANER_PAD * 2), y + (CONTANER_PAD * 2))
	self.control:ClearAnchors()
	self.control:SetAnchor(
		TOPLEFT,
		GuiRoot,
		TOPLEFT,
		self.SETTINGS.FRAME_CONTAINER_BASE_OFFSET_X,
		self.SETTINGS.FRAME_CONTAINER_BASE_OFFSET_Y
	)

	if withElems then
		for _, unitFrame in pairs(self.unitFrames) do
			-- Refresh whether or not a frame is active, so that when switching between keyboard and
			-- controller, the frames are properly resized and ready for new group members
			unitFrame:RefreshView()
			unitFrame:RefreshPosition()
		end
	end
end

function UnitFramesManager:ReorderByRole()
	local newIndex = 0

	local function posRole(role)
		for _, unitFrame in pairs(self.unitFrames) do
			if unitFrame:IsActive() and unitFrame.role == role then
				newIndex = newIndex + 1
				unitFrame:SetSortIndex(newIndex)
			end
		end
	end

	for _, role in ipairs(ROLE_ORDER) do
		posRole(role)
	end
end

function UnitFramesManager:ReorderFrames()
	if not self.SAVEVARS.USE_CUSTOM_ORDER then
		self:ReorderByRole()
		return
	end

	local customOrder = self.SAVEVARS.CUSTOM_ORDER
	local assigned = {}
	local newIndex = 0

	-- First pass: frames present in CUSTOM_ORDER, in saved order
	for _, entry in ipairs(customOrder) do
		for _, unitFrame in pairs(self.unitFrames) do
			if unitFrame:IsActive() and unitFrame.accountName == entry.name then
				newIndex = newIndex + 1
				unitFrame:SetSortIndex(newIndex)
				assigned[unitFrame] = true
			end
		end
	end

	-- Second pass: active frames not yet ordered, sorted by role (new joiners)
	for _, role in ipairs(ROLE_ORDER) do
		for _, unitFrame in pairs(self.unitFrames) do
			if unitFrame:IsActive() and not assigned[unitFrame] and unitFrame.role == role then
				newIndex = newIndex + 1
				unitFrame:SetSortIndex(newIndex)
				assigned[unitFrame] = true
			end
		end
	end

	-- Third pass: anything still unassigned (e.g. companion, player in SHOW_NOGROUP)
	for _, unitFrame in pairs(self.unitFrames) do
		if unitFrame:IsActive() and not assigned[unitFrame] then
			newIndex = newIndex + 1
			unitFrame:SetSortIndex(newIndex)
		end
	end
end

function UnitFramesManager:InitDragControls()
	local wm = WINDOW_MANAGER

	-- Semi-transparent ghost that follows the cursor during drag
	local ghost = wm:CreateControl("ALTGF_DragGhost", GuiRoot, CT_BACKDROP)
	ghost:SetDrawTier(DT_HIGH)
	ghost:SetMouseEnabled(false)
	ghost:SetHidden(true)
	ghost:SetCenterColor(0.2, 0.5, 1, 0.4)
	ghost:SetEdgeColor(0.4, 0.7, 1, 0.9)
	self.dragGhost = ghost

	-- Yellow highlight shown at the drop-target slot
	local highlight = wm:CreateControl("ALTGF_DropHighlight", self.control, CT_BACKDROP)
	highlight:SetDrawTier(DT_HIGH)
	highlight:SetMouseEnabled(false)
	highlight:SetHidden(true)
	highlight:SetCenterColor(1, 1, 0, 0.2)
	highlight:SetEdgeColor(1, 1, 0, 0.9)
	self.dropHighlight = highlight

	-- Full-screen transparent capture to intercept mouse-up anywhere during drag
	local capture = wm:CreateControl("ALTGF_DragCapture", GuiRoot, CT_CONTROL)
	capture:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 0)
	capture:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, 0, 0)
	capture:SetDrawTier(DT_HIGH)
	capture:SetMouseEnabled(false)
	capture:SetHidden(true)
	local manager = self
	capture:SetHandler("OnMouseUp", function(_, button)
		if button == MOUSE_BUTTON_INDEX_LEFT then
			manager:EndDrag()
		end
	end)
	self.dragCapture = capture

	self.dragState = nil
end

function UnitFramesManager:StartDrag(frame)
	local settings = self.SETTINGS
	local mx, my = GetUIMousePosition()

	local ghost = self.dragGhost
	ghost:SetDimensions(settings.UNIT_FRAME_WIDTH, settings.UNIT_FRAME_HEIGHT)
	ghost:ClearAnchors()
	ghost:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, mx - settings.UNIT_FRAME_WIDTH / 2, my - settings.UNIT_FRAME_HEIGHT / 2)
	ghost:SetHidden(false)

	self.dropHighlight:SetDimensions(settings.UNIT_FRAME_WIDTH, settings.UNIT_FRAME_HEIGHT)
	self.dropHighlight:SetHidden(false)
	self:UpdateDropHighlight(frame.index)

	self.dragCapture:SetMouseEnabled(true)
	self.dragCapture:SetHidden(false)

	self.dragState = {
		frame = frame,
		targetIndex = frame.index,
	}
end

function UnitFramesManager:UpdateDrag()
	if not self.dragState then
		return
	end

	local mx, my = GetUIMousePosition()
	local settings = self.SETTINGS

	self.dragGhost:ClearAnchors()
	self.dragGhost:SetAnchor(
		TOPLEFT,
		GuiRoot,
		TOPLEFT,
		mx - settings.UNIT_FRAME_WIDTH / 2,
		my - settings.UNIT_FRAME_HEIGHT / 2
	)

	local rx = mx - self.control:GetLeft() - CONTANER_PAD
	local ry = my - self.control:GetTop() - CONTANER_PAD

	local col = math.floor(rx / (settings.UNIT_FRAME_WIDTH + settings.UNIT_FRAME_PAD_X))
	local row = math.floor(ry / (settings.UNIT_FRAME_HEIGHT + settings.UNIT_FRAME_PAD_Y))

	local maxCol = zo_ceil(self.groupSize / settings.FRAMES_PER_COLUMN)
	local maxRow = zo_min(self.groupSize, settings.FRAMES_PER_COLUMN)

	col = zo_clamp(col, 0, zo_max(maxCol - 1, 0))
	row = zo_clamp(row, 0, zo_max(maxRow - 1, 0))

	local targetIndex = zo_clamp(col * settings.FRAMES_PER_COLUMN + row + 1, 1, zo_max(self.groupSize, 1))

	if targetIndex ~= self.dragState.targetIndex then
		self.dragState.targetIndex = targetIndex
		self:UpdateDropHighlight(targetIndex)
	end
end

function UnitFramesManager:UpdateDropHighlight(targetIndex)
	local settings = self.SETTINGS
	local col = zo_ceil(targetIndex / settings.FRAMES_PER_COLUMN)
	local row = zo_mod(targetIndex - 1, settings.FRAMES_PER_COLUMN)
	local x = ((col - 1) * (settings.UNIT_FRAME_WIDTH + settings.UNIT_FRAME_PAD_X)) + CONTANER_PAD
	local y = (row * (settings.UNIT_FRAME_HEIGHT + settings.UNIT_FRAME_PAD_Y)) + CONTANER_PAD
	self.dropHighlight:ClearAnchors()
	self.dropHighlight:SetAnchor(TOPLEFT, self.control, TOPLEFT, x, y)
end

function UnitFramesManager:CancelDrag()
	if not self.dragState then
		return
	end
	self.dragState = nil
	self.dragGhost:SetHidden(true)
	self.dropHighlight:SetHidden(true)
	self.dragCapture:SetMouseEnabled(false)
	self.dragCapture:SetHidden(true)
end

function UnitFramesManager:EndDrag()
	if not self.dragState then
		return
	end
	local frame = self.dragState.frame
	local targetIndex = self.dragState.targetIndex
	self:CancelDrag()
	if targetIndex ~= frame.index then
		self:ApplyCustomReorder(frame, targetIndex)
		self:RefreshData()
	end
end

function UnitFramesManager:ApplyCustomReorder(frame, targetIndex)
	-- Collect active non-companion frames in their current display order
	local byIndex = {}
	for _, unitFrame in pairs(self.unitFrames) do
		if unitFrame:IsActive() and not unitFrame:IsCompanion() then
			table.insert(byIndex, unitFrame)
		end
	end
	table.sort(byIndex, function(a, b) return a.index < b.index end)

	local upwards = targetIndex < frame.index
	local customOrder = self.SAVEVARS.CUSTOM_ORDER

	local frameIdx = 1
	local orderIdx = 1
	local insertPos = nil
	local removedFrame = false

	while frameIdx <= #byIndex and orderIdx <= #customOrder do
		if customOrder[orderIdx].name == frame.accountName then
			table.remove(customOrder, orderIdx)
			removedFrame = true
		elseif byIndex[frameIdx].accountName == frame.accountName then
			if frameIdx == targetIndex then
				insertPos = upwards and orderIdx or orderIdx + 1
				break
			end
			frameIdx = frameIdx + 1
		elseif customOrder[orderIdx].name == byIndex[frameIdx].accountName then
			if frameIdx == targetIndex then
				insertPos = upwards and orderIdx or orderIdx + 1
				break
			end
			frameIdx = frameIdx + 1
			orderIdx = orderIdx + 1
		else
			orderIdx = orderIdx + 1
		end
	end

	while not removedFrame and orderIdx <= #customOrder do
		if customOrder[orderIdx].name == frame.accountName then
			table.remove(customOrder, orderIdx)
			removedFrame = true
		end
		orderIdx = orderIdx + 1
	end

	local now = GetTimeStamp()
	if insertPos ~= nil then
		table.insert(customOrder, insertPos, { name = frame.accountName, lastSeen = now })
	else
		-- If we ended customOrder without reaching targetIndex, append all preceding frames
		while frameIdx < targetIndex do
			if byIndex[frameIdx] ~= frame then
				table.insert(customOrder, { name = byIndex[frameIdx].accountName, lastSeen = now })
			end
			frameIdx = frameIdx + 1
		end
		table.insert(customOrder, { name = frame.accountName, lastSeen = now })
	end
end

function UnitFramesManager:PruneCustomOrder()
	local ttl = self.SAVEVARS.CUSTOM_ORDER_TTL
	if ttl == 0 then
		return
	end
	local now = GetTimeStamp()
	local order = self.SAVEVARS.CUSTOM_ORDER
	for i = #order, 1, -1 do
		if now - order[i].lastSeen > ttl then
			table.remove(order, i)
		end
	end
end

function UnitFramesManager:UpdateLastSeen()
	if not self.SAVEVARS.USE_CUSTOM_ORDER then
		return
	end
	local now = GetTimeStamp()
	local activePlayers = {}
	for _, unitFrame in pairs(self.unitFrames) do
		if unitFrame:IsActive() and not unitFrame:IsCompanion() and unitFrame.accountName ~= "" then
			activePlayers[unitFrame.accountName] = true
		end
	end
	for _, entry in ipairs(self.SAVEVARS.CUSTOM_ORDER) do
		if activePlayers[entry.name] then
			entry.lastSeen = now
		end
	end
end

function UnitFramesManager:RefreshData()
	self:CancelDrag()
	local newGroupSize = GetGroupSize() + GetNumCompanionsInGroup()

	for i = 1, GROUP_SIZE_MAX do
		local unitTag = "group" .. i
		local frame = self:GetFrame(unitTag)
		if DoesUnitExist(unitTag) then
			frame:RefreshData()
			frame:SetActive(true)
		else
			frame:SetActive(false)
		end

		local compUnitTag = GetCompanionUnitTagByGroupUnitTag(unitTag)
		if compUnitTag then
			local compFrame = self:GetFrame(compUnitTag)
			if DoesUnitExist(compUnitTag) then
				compFrame:RefreshData()
				compFrame:SetActive(true)
			else
				compFrame:SetActive(false)
			end
		end
	end

	if self.SETTINGS.SHOW_NOGROUP then
		local playerFrame = self:GetFrame("player")
		if newGroupSize > 0 then
			playerFrame:SetActive(false)
		else
			playerFrame:RefreshData()
			playerFrame:SetActive(true)
			newGroupSize = newGroupSize + 1
		end
	else
		self:GetFrame("player"):SetActive(false)
	end

	local compFrame = self:GetFrame("companion")
	if newGroupSize > 0 then
		compFrame:SetActive(false)
	else
		if HasActiveCompanion() then
			compFrame:RefreshData()
			compFrame:SetActive(true)
			newGroupSize = newGroupSize + 1
		else
			compFrame:SetActive(false)
		end
	end

	self:ReorderFrames()
	self:UpdateLastSeen()

	if self.groupSize ~= newGroupSize then
		self.groupSize = newGroupSize
		self:RefreshView(false)
	end

	self:SetIsDirty(false)
end

function UnitFramesManager:GetFrame(unitTag)
	local unitFrame = self.unitFrames[unitTag]
	if unitFrame == nil then
		if unitTag == "companion" or IsGroupCompanionUnitTag(unitTag) then
			unitFrame = UnitFrameCompanion:New(unitTag, NonContiguousCount(self.unitFrames) + 1, self)
		else
			unitFrame = UnitFrame:New(unitTag, NonContiguousCount(self.unitFrames) + 1, self)
		end
		self.unitFrames[unitTag] = unitFrame
	end

	return unitFrame
end

function UnitFramesManager:TravelToLeader()
	d("Jumping to Group Leader")
	JumpToGroupLeader()
end

function UnitFramesManager:GetIsDirty()
	return self.dirty
end

function UnitFramesManager:SetIsDirty(flag)
	self.dirty = flag
end

local function DisableZoFrames()
	ZO_UnitFramesGroups:SetHidden(true)
	zo_callLater(function()
		UNIT_FRAMES:DisableGroupAndRaidFrames()
	end, 1000)

	ZO_UnitFrames:UnregisterForEvent(EVENT_LEADER_UPDATE)
	ZO_UnitFrames:UnregisterForEvent(EVENT_GROUP_SUPPORT_RANGE_UPDATE)
	ZO_UnitFrames:UnregisterForEvent(EVENT_GROUP_UPDATE)
	ZO_UnitFrames:UnregisterForEvent(EVENT_GROUP_MEMBER_LEFT)
	ZO_UnitFrames:UnregisterForEvent(EVENT_GROUP_MEMBER_CONNECTED_STATUS)
	ZO_UnitFrames:UnregisterForEvent(EVENT_GROUP_MEMBER_ROLE_CHANGED)
	ZO_UnitFrames:UnregisterForEvent(EVENT_TARGET_MARKER_UPDATE)
end

function ALTGF_UnitFrames_Initialize(topLevelControl)
	local function OnAddOnLoaded(_, addonName)
		if addonName == NAME then
			DisableZoFrames()

			UnitFrames = UnitFramesManager:New(topLevelControl)

			ALT_GROUP_FRAMES = UnitFrames

			local fragment = ZO_SimpleSceneFragment:New(topLevelControl)
			HUD_SCENE:AddFragment(fragment)
			HUD_UI_SCENE:AddFragment(fragment)
			SIEGE_BAR_SCENE:AddFragment(fragment)
			SIEGE_BAR_UI_SCENE:AddFragment(fragment)

			EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
		end
	end

	EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
end

function ALTGF_UnitFrames_OnUpdate()
	if UnitFrames then
		UnitFrames:UpdateDrag()
		if UnitFrames:GetIsDirty() then
			UnitFrames:RefreshData()
		end
	end
end
