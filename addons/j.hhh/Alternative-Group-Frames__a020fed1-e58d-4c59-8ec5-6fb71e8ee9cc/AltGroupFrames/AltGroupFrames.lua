--[[
Alternative Group Frames - Console adaptation
Based on Alternative Group Frames by BulDeZir and Glande-Pas.
Version 1.4.1

Console changes:
- Restored a PS5/gamepad settings menu through LibAddonMenu-2.0.
- Uses a concrete PS5/gamepad settings table instead of the PC platform-style override chain.
- Kept the original gamepad frame layout and account-wide saved data.
- Added console-safe fallbacks for unavailable PC globals and layout values.
- Uses the original add-on approach to disable ESO's built-in group and raid frames.
- Removed all temporary diagnostic commands and experimental native-frame probes.

Released under the GNU General Public License v3.0 or later.
See LICENSE included with this add-on.
]]

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
	VERSION = "1.4.1",
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
	GROUP_LAYOUT = 1, -- 1 = one window / 12 players, 2 = two windows / 6 players each
	GROUP_WINDOW_GAP = 24,
	PREVIEW_MODE = false,

	FRAME_CONTAINER_BASE_OFFSET_X = 50,
	FRAME_CONTAINER_BASE_OFFSET_Y = 55,
	FRAME_SCALE = 100,

	UNIT_FRAME_WIDTH = 230,
	UNIT_FRAME_HEIGHT = 32,
	UNIT_FRAME_PAD_X = 4,
	UNIT_FRAME_PAD_Y = 2,

	UNIT_FRAME_ALT_SIZE = { 4, 50, 55, 120, 50, 4, 2 },

	UNIT_FRAME_FONTSIZE = 22,
	UNIT_FRAME_ICONSIZE = 22,

	-- New installations start with a solid health-red bar for every role.
	-- Each role keeps its own start/end pair so players can create independent gradients.
	LFG_COLORS = {
		[LFG_ROLE_TANK] = { ZO_ColorDef:New("b71c1c"), ZO_ColorDef:New("b71c1c") },
		[LFG_ROLE_HEAL] = { ZO_ColorDef:New("b71c1c"), ZO_ColorDef:New("b71c1c") },
		[LFG_ROLE_DPS] = { ZO_ColorDef:New("b71c1c"), ZO_ColorDef:New("b71c1c") },
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

	MISSING_HEALTH_COLOR = ZO_ColorDef:New(0, 0, 0, 0.80),
	SHIELD_COLOR = ZO_ColorDef:New(1, 0.49, 0.13, 0.80),
	TRAUMA_COLOR = ZO_ColorDef:New(0.8, 0.8, 0.8, 0.6),
}

local CONTANER_PAD = 5

-- GROUP_SIZE_MAX was used by the original PC add-on, but it is not exposed in
-- the managed PS5 environment. Modern ESO UI code uses
-- MAX_GROUP_SIZE_THRESHOLD. Keep a hard minimum of 12 so the manager always
-- creates enough frames for a full trial, even if a context-sensitive API
-- reports a smaller current limit.
local function ResolveGroupFrameCapacity()
	local capacity = 12

	local threshold = tonumber(MAX_GROUP_SIZE_THRESHOLD)
	if threshold then
		capacity = math.max(capacity, threshold)
	end

	local legacyMaximum = tonumber(GROUP_SIZE_MAX)
	if legacyMaximum then
		capacity = math.max(capacity, legacyMaximum)
	end

	if type(GetMaxGroupSize) == "function" then
		local ok, maximum = pcall(GetMaxGroupSize)
		maximum = ok and tonumber(maximum) or nil
		if maximum then
			capacity = math.max(capacity, maximum)
		end
	end

	return math.max(1, math.floor(capacity))
end

local GROUP_FRAME_CAPACITY = ResolveGroupFrameCapacity()

-- GetUnitPower uses CombatMechanicType. POWERTYPE_HEALTH is currently an
-- alias, but the native ESO unit frames use COMBAT_MECHANIC_FLAGS_HEALTH.
-- Prefer the native constant explicitly for console compatibility.
local HEALTH_POWER_TYPE = COMBAT_MECHANIC_FLAGS_HEALTH or POWERTYPE_HEALTH

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

	function ALTGF_MostRecentPowerUpdateHandler:New(namespace, handlerFunction, unitScope)
		local obj = ZO_MostRecentEventHandler.New(
			self,
			namespace,
			EVENT_POWER_UPDATE,
			PowerUpdateEqualityFunction,
			handlerFunction
		)
		if unitScope == "player" or unitScope == "companion" then
			obj:AddFilterForEvent(REGISTER_FILTER_UNIT_TAG, unitScope)
		else
			obj:AddFilterForEvent(REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
		end

		obj:AddFilterForEvent(REGISTER_FILTER_POWER_TYPE, HEALTH_POWER_TYPE)

		return obj
	end
end

local UnitFrames, UnitFramesManager, UnitFrame, UnitFrameCompanion, PRI, ODY
local DisableZoFrames

-------------------------------------
--Console Settings--
-------------------------------------
-- The original PC add-on builds a chain of ZO_DataSourceObject settings and
-- then applies a ZO_PlatformStyle override.  On managed-console add-ons that
-- inherited lookup can be unavailable while the gamepad style is being
-- initialized, leaving values such as FRAMES_PER_COLUMN nil.  PS5 never needs
-- to switch to keyboard UI, so use one concrete, fully populated table.
local function BuildConsoleSettings(savedVars)
	local settings = {}

	for key, defaultValue in pairs(DEFAULTS) do
		local value = savedVars and savedVars[key]
		if value == nil then
			value = defaultValue
		end
		settings[key] = value
	end

	settings.GROUP_LAYOUT = tonumber(settings.GROUP_LAYOUT) == 2 and 2 or 1
	-- Console layout is intentionally restricted to the two supported choices.
	settings.FRAMES_PER_COLUMN = settings.GROUP_LAYOUT == 2 and 6 or 12
	settings.GROUP_WINDOW_GAP = zo_clamp(
		math.floor((tonumber(settings.GROUP_WINDOW_GAP) or DEFAULTS.GROUP_WINDOW_GAP) + 0.5),
		0,
		200
	)
	settings.FRAME_CONTAINER_BASE_OFFSET_X = tonumber(settings.FRAME_CONTAINER_BASE_OFFSET_X)
		or DEFAULTS.FRAME_CONTAINER_BASE_OFFSET_X
	settings.FRAME_CONTAINER_BASE_OFFSET_Y = tonumber(settings.FRAME_CONTAINER_BASE_OFFSET_Y)
		or DEFAULTS.FRAME_CONTAINER_BASE_OFFSET_Y
	settings.FRAME_SCALE = zo_clamp(
		math.floor((tonumber(settings.FRAME_SCALE) or DEFAULTS.FRAME_SCALE) + 0.5),
		50,
		200
	)

	-- The console settings page now focuses on individually configurable role
	-- colors. Migrate the former class-color bar mode to role colors while
	-- retaining class icons and the old data for source compatibility.
	if settings.COLORS_SHOW == SHOW_CLASSES then
		settings.COLORS_SHOW = SHOW_ROLES
		if savedVars then
			savedVars.COLORS_SHOW = SHOW_ROLES
		end
	end

	-- Preserve the original add-on's gamepad sizing, but apply it directly.
	settings.UNIT_FRAME_WIDTH = (tonumber(settings.UNIT_FRAME_WIDTH) or DEFAULTS.UNIT_FRAME_WIDTH) + 40
	settings.UNIT_FRAME_HEIGHT = (tonumber(settings.UNIT_FRAME_HEIGHT) or DEFAULTS.UNIT_FRAME_HEIGHT) + 10
	settings.UNIT_FRAME_PAD_X = (tonumber(settings.UNIT_FRAME_PAD_X) or DEFAULTS.UNIT_FRAME_PAD_X) + 2
	settings.UNIT_FRAME_PAD_Y = (tonumber(settings.UNIT_FRAME_PAD_Y) or DEFAULTS.UNIT_FRAME_PAD_Y) + 2
	settings.UNIT_FRAME_FONTSIZE = 27
	settings.UNIT_FRAME_ICONSIZE = 27

	return settings
end

-------------------------------------
--Group Member Frame--
-------------------------------------

-- Read the current shield/trauma state when a frame is first shown. Event-only
-- tracking misses effects that were already active before the frame became
-- visible, which is especially noticeable with the solo player preview.
local function GetCurrentAttributeVisualValue(unitTag, visualType)
	if type(GetUnitAttributeVisualizerEffectInfo) ~= "function" then
		return 0
	end

	local powerType = HEALTH_POWER_TYPE
	if not powerType or not STAT_MITIGATION or not ATTRIBUTE_HEALTH then
		return 0
	end

	local ok, value = pcall(
		GetUnitAttributeVisualizerEffectInfo,
		unitTag,
		visualType,
		STAT_MITIGATION,
		ATTRIBUTE_HEALTH,
		powerType
	)

	if not ok then
		return 0
	end

	return math.max(0, tonumber(value) or 0)
end

UnitFrame = ZO_Object:Subclass()
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

	-- Creating every possible group slot at once can exceed the console Lua CPU
	-- budget. If a previous frame was interrupted immediately after control
	-- creation, reuse that already-created control instead of trying to create a
	-- duplicate with the same global name on the next UI tick.
	local controlName = "ALTGF_UnitFrame" .. unitTag
	self.control = (_G and _G[controlName]) or CreateControlFromVirtual(controlName, container:GetControl(), "ALTGF_UnitFrame")
	self.control:SetParent(container:GetControl())
	self.control.m_object = self
	self.backgroundControl = GetControl(self.control, "Background")
	self.borderControl = GetControl(self.control, "Border")
	self.nameControl = GetControl(self.control, "Name")
	self.levelControl = GetControl(self.control, "Level")
	self.iconControl = GetControl(self.control, "Icon")
	self.resourceNumbersControl = GetControl(self.control, "ResourceNumbers")
	self.healthBarControl = GetControl(self.control, "HP")
	self.shieldBarControl = GetControl(self.control, "Shield")
	self.traumaBarControl = GetControl(self.control, "Trauma")

	-- Status bars can briefly display their default white fill before their
	-- first power event on gamepad/console. Initialize every bar explicitly,
	-- and keep overlays hidden until they contain a real value.
	self.healthBarControl:SetMinMax(0, 1)
	self.healthBarControl:SetValue(0)
	self.shieldBarControl:SetMinMax(0, 1)
	self.shieldBarControl:SetValue(0)
	self.shieldBarControl:SetHidden(true)
	self.traumaBarControl:SetMinMax(0, 1)
	self.traumaBarControl:SetValue(0)
	self.traumaBarControl:SetHidden(true)

	self.curHP = 0
	self.maxHP = 0
	self.curShield = 0
	self.curTrauma = 0
	self.healthDataReady = false
	self.healthRefreshGeneration = 0
	self.healthRefreshPending = false
	self.unitIdentity = nil
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

	self.backgroundControl:SetColor(settings.MISSING_HEALTH_COLOR:UnpackRGBA())
	self.shieldBarControl:SetColor(settings.SHIELD_COLOR:UnpackRGBA())
	self.traumaBarControl:SetColor(settings.TRAUMA_COLOR:UnpackRGBA())
	self:RefreshColor()
end

function UnitFrame:RefreshPosition()
	local settings = self.container.SETTINGS
	local framesPerColumn = tonumber(settings.FRAMES_PER_COLUMN) or DEFAULTS.FRAMES_PER_COLUMN
	local frameWidth = tonumber(settings.UNIT_FRAME_WIDTH) or (DEFAULTS.UNIT_FRAME_WIDTH + 40)
	local frameHeight = tonumber(settings.UNIT_FRAME_HEIGHT) or (DEFAULTS.UNIT_FRAME_HEIGHT + 10)
	local padX = tonumber(settings.UNIT_FRAME_PAD_X) or (DEFAULTS.UNIT_FRAME_PAD_X + 2)
	local padY = tonumber(settings.UNIT_FRAME_PAD_Y) or (DEFAULTS.UNIT_FRAME_PAD_Y + 2)
	local col = zo_ceil(self.index / framesPerColumn)
	local row = zo_mod(self.index - 1, framesPerColumn)
	local groupGap = tonumber(settings.GROUP_WINDOW_GAP) or DEFAULTS.GROUP_WINDOW_GAP

	-- Two-window console layout, always vertical:
	-- window 1 = slots 1-6, then 13-18 directly underneath
	-- window 2 = slots 7-12, then 19-24 directly underneath
	if settings.GROUP_LAYOUT == 2 then
		local block = zo_floor((self.index - 1) / 6)
		col = zo_mod(block, 2) + 1
		row = zo_floor(block / 2) * 6 + zo_mod(self.index - 1, 6)
	end

	local splitGap = settings.GROUP_LAYOUT == 2 and ((col - 1) * groupGap) or 0
	local x = ((col - 1) * (frameWidth + padX)) + splitGap + CONTANER_PAD
	local y = (row * (frameHeight + padY)) + CONTANER_PAD
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

-- A group unit tag can be reused for a different player, and the client may
-- briefly expose the new identity before its power values are available. Reset
-- stale values on identity changes, but show a neutral full-bar placeholder
-- instead of treating an uninitialized 0/0 response as real missing health.
function UnitFrame:ResetHealthState(identity)
	self.unitIdentity = identity
	self.healthDataReady = false
	self.healthRefreshGeneration = (self.healthRefreshGeneration or 0) + 1
	self.healthRefreshPending = false
	self.curHP = 0
	self.maxHP = 0
	self.curShield = 0
	self.curTrauma = 0

	self.healthBarControl:SetMinMax(0, 1)
	self.healthBarControl:SetValue(1)
	self.resourceNumbersControl:SetText("")

	self.shieldBarControl:SetMinMax(0, 1)
	self.shieldBarControl:SetValue(0)
	self.shieldBarControl:SetHidden(true)
	self.traumaBarControl:SetMinMax(0, 1)
	self.traumaBarControl:SetValue(0)
	self.traumaBarControl:SetHidden(true)
end

function UnitFrame:PrepareUnitIdentity(identity)
	identity = tostring(identity or "")
	if self.unitIdentity ~= identity then
		self:ResetHealthState(identity)
		return true
	end
	return false
end

function UnitFrame:ShowPendingHealth()
	if self.isOnline and not self.isDead and not self.healthDataReady then
		self.healthBarControl:SetMinMax(0, 1)
		self.healthBarControl:SetValue(1)
		self.healthBarControl:SetHidden(false)
		self.resourceNumbersControl:SetText("")
	end
end

function UnitFrame:ScheduleHealthRefresh()
	if self.healthDataReady or self.healthRefreshPending or not self.isOnline or self.isDead then
		return
	end

	self.healthRefreshPending = true
	local generation = self.healthRefreshGeneration
	local delays = { 50, 100, 200, 400, 800, 1200, 2000 }
	local attempt = 1

	local function Retry()
		if generation ~= self.healthRefreshGeneration then
			return
		end
		if not self:IsActive() or not self.isOnline or self.isDead then
			self.healthRefreshPending = false
			return
		end
		if self:RefreshHealthFromUnit(true) then
			self.healthRefreshPending = false
			return
		end

		attempt = math.min(attempt + 1, #delays)
		zo_callLater(Retry, delays[attempt])
	end

	zo_callLater(Retry, delays[attempt])
end

function UnitFrame:RefreshData(force)
	local accountName = GetUnitDisplayName(self.unitTag)
	local characterName = GetUnitName(self.unitTag)
	self:PrepareUnitIdentity(accountName .. "\31" .. characterName)

	self.accountName = accountName
	self.characterName = characterName
	self.classId = GetUnitClassId(self.unitTag)

	self:RefreshName()
	self:RefreshLevel()
	self:RefreshIcon()
	self:OnRoleChange(self.unitTag == "player" and GetSelectedLFGRole() or GetGroupMemberSelectedRole(self.unitTag))
	self:OnSupportRangeUpdate(IsUnitInGroupSupportRange(self.unitTag))
	self:OnDeathStatusChange(IsUnitDead(self.unitTag), true)
	self:OnOnlineStatusChange(IsUnitOnline(self.unitTag))

	if force and self.isOnline and not self.isDead and not self.healthDataReady then
		if not self:RefreshHealthFromUnit(true) then
			self:ScheduleHealthRefresh()
		end
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
		if role ~= nil and role.name and role.show and role.showOnAlive and role.sv.texturePath ~= nil then
			return role.sv.texturePath
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
		local classIndex = self.classId and GetClassIndexById(self.classId) or nil
		local classGradient = classIndex and self.container.SETTINGS.CLASS_COLORS[classIndex] or nil
		ZO_StatusBar_SetGradientColor(
			self.healthBarControl,
			classGradient or ZO_POWER_BAR_GRADIENT_COLORS[HEALTH_POWER_TYPE]
		)
	elseif self.container.SETTINGS.COLORS_SHOW == SHOW_ROLES and self.role ~= LFG_ROLE_INVALID then
		ZO_StatusBar_SetGradientColor(self.healthBarControl, self.container.SETTINGS.LFG_COLORS[self.role])
	elseif IsActiveWorldBattleground() then
		ZO_StatusBar_SetGradientColor(self.healthBarControl, self.container.SETTINGS.LFG_COLORS[LFG_ROLE_DPS])
	else
		ZO_StatusBar_SetGradientColor(self.healthBarControl, ZO_POWER_BAR_GRADIENT_COLORS[HEALTH_POWER_TYPE])
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
	elseif self.isOnline then
		if not self:RefreshHealthFromUnit(true) then
			self:ShowPendingHealth()
			self:ScheduleHealthRefresh()
		end
	end
end

function UnitFrame:OnOnlineStatusChange(isOnline)
	self.isOnline = isOnline
	if isOnline then
		if not self:RefreshHealthFromUnit(true) then
			self:ShowPendingHealth()
			self:ScheduleHealthRefresh()
		end
		self:RefreshAttributeVisuals(true)

		self.healthBarControl:SetHidden(false)
		-- Shield and trauma visibility is controlled by their current values.
		self.resourceNumbersControl:SetHidden(false)
	else
		self.healthRefreshGeneration = (self.healthRefreshGeneration or 0) + 1
		self.healthRefreshPending = false
		self.healthBarControl:SetHidden(true)
		self.shieldBarControl:SetHidden(true)
		self.traumaBarControl:SetHidden(true)
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

function UnitFrame:RefreshAttributeVisuals(force)
	local shield = GetCurrentAttributeVisualValue(self.unitTag, ATTRIBUTE_VISUAL_POWER_SHIELDING)
	local trauma = 0
	if ATTRIBUTE_VISUAL_TRAUMA ~= nil then
		trauma = GetCurrentAttributeVisualValue(self.unitTag, ATTRIBUTE_VISUAL_TRAUMA)
	end

	self:OnUpdateShield(shield, force)
	self:OnUpdateTrauma(trauma, force)
end

function UnitFrame:OnUpdateShield(value, force)
	value = math.max(0, tonumber(value) or 0)
	if self.isDead then
		value = 0
	end
	self.curShield = value
	ZO_StatusBar_SmoothTransition(self.shieldBarControl, value, math.max(1, tonumber(self.maxHP) or 0), force)
	self.shieldBarControl:SetHidden(not self.isOnline or value <= 0 or not self.healthDataReady)
	self:UpdateResourceNumbers(self.curHP, self.maxHP, value, self.curTrauma)
end

function UnitFrame:OnUpdateTrauma(value, force)
	value = math.max(0, tonumber(value) or 0)
	if self.isDead then
		value = 0
	end
	self.curTrauma = value
	ZO_StatusBar_SmoothTransition(self.traumaBarControl, value, math.max(1, tonumber(self.maxHP) or 0), force)
	self.traumaBarControl:SetHidden(not self.isOnline or value <= 0 or not self.healthDataReady)
	self:UpdateResourceNumbers(self.curHP, self.maxHP, self.curShield, value)
end

local function NormalizeHealthSample(health, maxHealth, effectiveMaxHealth)
	health = math.max(0, tonumber(health) or 0)
	maxHealth = math.max(0, tonumber(maxHealth) or 0)
	effectiveMaxHealth = math.max(0, tonumber(effectiveMaxHealth) or 0)
	if maxHealth <= 0 and effectiveMaxHealth > 0 then
		maxHealth = effectiveMaxHealth
	end
	return health, maxHealth
end

-- ESO's own group frames keep a health cache on their ZO_UnitFrameBar. The
-- console client can populate that cache before a custom add-on receives a
-- usable GetUnitPower result, especially for full-health members who have not
-- generated a power event yet. Keep the native controls hidden, but use their
-- data as a fallback.
local function GetNativeFrameHealth(unitTag)
	if not UNIT_FRAMES or type(UNIT_FRAMES.GetFrame) ~= "function" then
		return 0, 0
	end

	local ok, nativeFrame = pcall(UNIT_FRAMES.GetFrame, UNIT_FRAMES, unitTag)
	if not ok or not nativeFrame or not nativeFrame.healthBar then
		return 0, 0
	end

	local healthBar = nativeFrame.healthBar
	return NormalizeHealthSample(healthBar.currentValue, healthBar.maxValue)
end

local function GetHealthFromPowerInfo(unitTag)
	if type(GetUnitPowerInfo) ~= "function" then
		return 0, 0
	end

	local maxIndex = tonumber(COMBAT_MECHANIC_FLAGS_MAX_INDEX) or tonumber(NUM_POWER_POOLS) or 16
	for index = 1, maxIndex do
		local powerType, health, maxHealth, effectiveMaxHealth = GetUnitPowerInfo(unitTag, index)
		if powerType == HEALTH_POWER_TYPE then
			return NormalizeHealthSample(health, maxHealth, effectiveMaxHealth)
		end
	end

	return 0, 0
end

function UnitFrame:GetAuthoritativeHealth()
	if not DoesUnitExist(self.unitTag) then
		return 0, 0
	end

	local health, maxHealth = 0, 0
	if type(GetUnitPower) == "function" then
		local current, maximum, effectiveMaximum = GetUnitPower(self.unitTag, HEALTH_POWER_TYPE)
		health, maxHealth = NormalizeHealthSample(current, maximum, effectiveMaximum)
	end

	-- A living unit reporting 0 current health is also treated as incomplete.
	-- Prefer the native cache or power-info table before accepting it.
	if maxHealth <= 0 or (health <= 0 and not IsUnitDead(self.unitTag)) then
		local nativeHealth, nativeMaxHealth = GetNativeFrameHealth(self.unitTag)
		if nativeMaxHealth > 0 and (nativeHealth > 0 or IsUnitDead(self.unitTag)) then
			return nativeHealth, nativeMaxHealth
		end

		local infoHealth, infoMaxHealth = GetHealthFromPowerInfo(self.unitTag)
		if infoMaxHealth > 0 and (infoHealth > 0 or IsUnitDead(self.unitTag)) then
			return infoHealth, infoMaxHealth
		end
	end

	return health, maxHealth
end

function UnitFrame:RefreshHealthFromUnit(force)
	local health, maxHealth = self:GetAuthoritativeHealth()
	return self:OnUpdateHp(health, maxHealth, force)
end

-- Only a usable maximum initializes health. A zero current value for an
-- online, living unit is treated as incomplete unless death is confirmed.
function UnitFrame:OnUpdateHp(health, maxHealth, force)
	health, maxHealth = NormalizeHealthSample(health, maxHealth)

	local confirmedDead = self.isDead or IsUnitDead(self.unitTag)
	if confirmedDead then
		local resolvedMax = maxHealth > 0 and maxHealth or math.max(0, tonumber(self.maxHP) or 0)
		self.curHP = 0
		if resolvedMax > 0 then
			self.maxHP = resolvedMax
		end
		ZO_StatusBar_SmoothTransition(self.healthBarControl, 0, math.max(1, resolvedMax), force)
		return true
	end

	if maxHealth <= 0 then
		return false
	end

	-- EVENT_POWER_UPDATE can briefly report 0 before the death-state event. Do
	-- not erase a valid living frame. For a brand-new member with a known max,
	-- display the safe full-health value until the real current value arrives.
	if health <= 0 then
		if self.healthDataReady and (tonumber(self.curHP) or 0) > 0 then
			health = zo_clamp(self.curHP, 0, maxHealth)
		else
			health = maxHealth
		end
	end

	health = zo_clamp(health, 0, maxHealth)
	self.curHP = health
	self.maxHP = maxHealth
	self.healthDataReady = true
	self.healthRefreshGeneration = (self.healthRefreshGeneration or 0) + 1
	self.healthRefreshPending = false

	ZO_StatusBar_SmoothTransition(self.healthBarControl, health, maxHealth, force)
	ZO_StatusBar_SmoothTransition(self.shieldBarControl, self.curShield, maxHealth, true)
	ZO_StatusBar_SmoothTransition(self.traumaBarControl, self.curTrauma, maxHealth, true)
	self.shieldBarControl:SetHidden(not self.isOnline or self.curShield <= 0)
	self.traumaBarControl:SetHidden(not self.isOnline or self.curTrauma <= 0)
	self:UpdateResourceNumbers(health, maxHealth, self.curShield, self.curTrauma)
	return true
end

function UnitFrame:UpdateResourceNumbers(health, maxHealth, shield, trauma)
	if self.isDead then
		return
	end

	if not self.healthDataReady or (tonumber(self.maxHP) or 0) <= 0 then
		self.resourceNumbersControl:SetText("")
		return
	end

	health = tonumber(health)
	maxHealth = tonumber(maxHealth)
	if not health or not maxHealth or maxHealth <= 0 then
		health = self.curHP
		maxHealth = self.maxHP
	else
		health = zo_clamp(health, 0, maxHealth)
	end

	shield = tonumber(shield) or 0
	trauma = tonumber(trauma) or 0

	local text = ""
	if shield > 0 or trauma > 0 then
		text = ZO_AbbreviateAndLocalizeNumber(health, NUMBER_ABBREVIATION_PRECISION_LARGEST_UNIT, false) .. "["
		if shield > 0 then
			text = text .. ZO_AbbreviateAndLocalizeNumber(shield, NUMBER_ABBREVIATION_PRECISION_LARGEST_UNIT, false)
		end
		if trauma > 0 then
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
		local health, maxHealth = GetUnitPower(self.unitTag, HEALTH_POWER_TYPE)
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
	if active then
		if self.isOnline and not self.isDead and not self.healthDataReady then
			self:ShowPendingHealth()
			self:ScheduleHealthRefresh()
		end
	else
		self.healthRefreshGeneration = (self.healthRefreshGeneration or 0) + 1
		self.healthRefreshPending = false
	end
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
		local health, maxHealth = GetUnitPower(self.unitTag, HEALTH_POWER_TYPE)
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

function UnitFrame:HandleMouseUp(button, upInside)
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

UnitFrameCompanion = UnitFrame:Subclass()
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
	self:PrepareUnitIdentity(self.accountName .. "\31" .. self.characterName)
	self.classId = GetUnitClassId(self.unitTag)

	self:RefreshName()
	self:RefreshIcon()
	self:OnRoleChange(GetGroupMemberSelectedRole(self.unitTag))
	self:OnSupportRangeUpdate(IsUnitInGroupSupportRange(self.unitTag))
	self:OnDeathStatusChange(IsUnitDead(self.unitTag), true)
	self:OnOnlineStatusChange(IsUnitOnline(self.unitTag))

	if force and self.isOnline and not self.isDead and not self.healthDataReady then
		if not self:RefreshHealthFromUnit(true) then
			self:ScheduleHealthRefresh()
		end
	end

	CALLBACK_MANAGER:FireCallbacks(EVENT.UNIT_FRAME_DATA_CHANGED, self)
end

function UnitFrameCompanion:RefreshName()
	self.nameControl:SetText(self.characterName)
end

function UnitFrameCompanion:RefreshIcon()
	if self.container.SETTINGS.ICONS_SHOW ~= SHOW_NONE then
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

UnitFramesManager = ZO_Object:Subclass()
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
	self.SAVEVARS.MISSING_HEALTH_COLOR = ZO_ColorDef:New(self.SAVEVARS.MISSING_HEALTH_COLOR)
	self.SAVEVARS.SHIELD_COLOR = ZO_ColorDef:New(self.SAVEVARS.SHIELD_COLOR)
	self.SAVEVARS.TRAUMA_COLOR = ZO_ColorDef:New(self.SAVEVARS.TRAUMA_COLOR)

	self.SETTINGS = BuildConsoleSettings(self.SAVEVARS)

	--self:RefreshData()
	--self:RefreshView()
	self:RegisterEvents(topLevelControl)

	CALLBACK_MANAGER:FireCallbacks(EVENT.MANAGER_CREATED, self)
end

function UnitFramesManager:RegisterEvents(topLevelControl)
	local function RegisterDelayedRefresh()
		self:SetIsDirty(true)
		if DisableZoFrames then
			DisableZoFrames()
		end
	end

	local osiHooked = false
	local function OnPlayerActivated()
		RegisterDelayedRefresh()
		if DisableZoFrames then
			DisableZoFrames()
		end
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
		self:ReorderByRole()
	end

	local function OnRoleChanged(_, unitTag, newRole)
		if self:GetFrame(unitTag):OnRoleChange(newRole) then
			self:ReorderByRole()
		end
	end

	local function ApplyAttributeVisualValue(unitTag, unitAttributeVisual, value, force)
		local frame = self:GetFrame(unitTag)
		if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING then
			frame:OnUpdateShield(value, force)
		elseif ATTRIBUTE_VISUAL_TRAUMA ~= nil and unitAttributeVisual == ATTRIBUTE_VISUAL_TRAUMA then
			frame:OnUpdateTrauma(value, force)
		end
	end

	-- Added and Updated have different argument layouts in the current API.
	-- Keeping separate callbacks prevents the sequenceId from being mistaken for
	-- oldMaxValue and prevents maxValue from being used as the current shield.
	local function OnVisualPowerAdded(
		_,
		unitTag,
		unitAttributeVisual,
		statType,
		attributeType,
		powerType,
		value,
		maxValue,
		sequenceId
	)
		ApplyAttributeVisualValue(unitTag, unitAttributeVisual, value, false)
	end

	local function OnVisualPowerUpdated(
		_,
		unitTag,
		unitAttributeVisual,
		statType,
		attributeType,
		powerType,
		oldValue,
		newValue,
		oldMaxValue,
		newMaxValue,
		sequenceId
	)
		ApplyAttributeVisualValue(unitTag, unitAttributeVisual, newValue, false)
	end

	local function OnVisualPowerRemoved(
		_,
		unitTag,
		unitAttributeVisual,
		statType,
		attributeType,
		powerType,
		value,
		maxValue,
		sequenceId
	)
		ApplyAttributeVisualValue(unitTag, unitAttributeVisual, 0, false)
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
		local leaderUnitTag = GetGroupLeaderUnitTag()
		if leaderUnitTag and leaderUnitTag ~= "" then
			self:GetFrame(leaderUnitTag):OnUpdate()
		end
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
	local function RegisterAttributeVisualEvents(namespace, filterType, filterValue)
		EVENT_MANAGER:RegisterForEvent(namespace, EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, OnVisualPowerAdded)
		EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, filterType, filterValue)
		EVENT_MANAGER:RegisterForEvent(namespace, EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, OnVisualPowerUpdated)
		EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, filterType, filterValue)
		EVENT_MANAGER:RegisterForEvent(namespace, EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, OnVisualPowerRemoved)
		EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, filterType, filterValue)
	end

	RegisterAttributeVisualEvents(NAME .. "_GroupAttributeVisuals", REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
	RegisterAttributeVisualEvents(NAME .. "_PlayerAttributeVisuals", REGISTER_FILTER_UNIT_TAG, "player")
	RegisterAttributeVisualEvents(NAME .. "_CompanionAttributeVisuals", REGISTER_FILTER_UNIT_TAG, "companion")

	ALTGF_MostRecentPowerUpdateHandler:New("ALTGF_GroupList_Manager", OnPowerUpdate, "group")
	ALTGF_MostRecentPowerUpdateHandler:New("ALTGF_GroupList_ManagerPlayer", OnPowerUpdate, "player")
	ALTGF_MostRecentPowerUpdateHandler:New("ALTGF_GroupList_ManagerComp", OnPowerUpdate, "companion")


	-- Refresh frames when PlayerRoleIndicator custom role assignments change
	CALLBACK_MANAGER:RegisterCallback("PRI_CustomRoleChanged", RegisterDelayedRefresh)

	-- PS5 is permanently in gamepad UI.  The concrete settings table was built
	-- during Initialize, so no ZO_PlatformStyle callback or inherited override
	-- object is needed here.
	self:RefreshView(true)
end

function UnitFramesManager:ForEach(callback)
	for _, unitFrame in pairs(self.unitFrames) do
		callback(unitFrame)
	end
end

function UnitFramesManager:GetControl()
	return self.control
end

function UnitFramesManager:ApplySavedSettings(refreshElements, refreshData)
	self.SETTINGS = BuildConsoleSettings(self.SAVEVARS)
	self:RefreshView(refreshElements ~= false)
	if refreshData then
		self:RefreshData()
	end
end

function UnitFramesManager:SaveLoc()
	self.SAVEVARS.FRAME_CONTAINER_BASE_OFFSET_X = zo_round(self.control:GetLeft())
	self.SAVEVARS.FRAME_CONTAINER_BASE_OFFSET_Y = zo_round(self.control:GetTop())
end

function UnitFramesManager:SaveSize()
	-- Retained for source compatibility; the console package does not expose
	-- mouse resizing.  Keep every arithmetic input guarded regardless.
	local framesPerColumn = tonumber(self.SETTINGS.FRAMES_PER_COLUMN) or DEFAULTS.FRAMES_PER_COLUMN
	local padX = tonumber(self.SETTINGS.UNIT_FRAME_PAD_X) or (DEFAULTS.UNIT_FRAME_PAD_X + 2)
	local padY = tonumber(self.SETTINGS.UNIT_FRAME_PAD_Y) or (DEFAULTS.UNIT_FRAME_PAD_Y + 2)
	local maxCol = zo_ceil(GROUP_FRAME_CAPACITY / framesPerColumn)
	local maxRow = zo_min(GROUP_FRAME_CAPACITY, framesPerColumn)

	local x = self.control:GetWidth() - 2 * CONTANER_PAD
	local y = self.control:GetHeight() - 2 * CONTANER_PAD

	self.SAVEVARS.UNIT_FRAME_WIDTH = zo_round(x / maxCol) - padX
	self.SAVEVARS.UNIT_FRAME_HEIGHT = zo_round(y / maxRow) - padY

	self.SETTINGS = BuildConsoleSettings(self.SAVEVARS)
	self:RefreshView(true)
end

function UnitFramesManager:UnlockUI(movable)
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

	local settings = self.SETTINGS or BuildConsoleSettings(self.SAVEVARS)
	self.SETTINGS = settings

	local framesPerColumn = tonumber(settings.FRAMES_PER_COLUMN) or DEFAULTS.FRAMES_PER_COLUMN
	local frameWidth = tonumber(settings.UNIT_FRAME_WIDTH) or (DEFAULTS.UNIT_FRAME_WIDTH + 40)
	local frameHeight = tonumber(settings.UNIT_FRAME_HEIGHT) or (DEFAULTS.UNIT_FRAME_HEIGHT + 10)
	local padX = tonumber(settings.UNIT_FRAME_PAD_X) or (DEFAULTS.UNIT_FRAME_PAD_X + 2)
	local padY = tonumber(settings.UNIT_FRAME_PAD_Y) or (DEFAULTS.UNIT_FRAME_PAD_Y + 2)
	local offsetX = tonumber(settings.FRAME_CONTAINER_BASE_OFFSET_X) or DEFAULTS.FRAME_CONTAINER_BASE_OFFSET_X
	local offsetY = tonumber(settings.FRAME_CONTAINER_BASE_OFFSET_Y) or DEFAULTS.FRAME_CONTAINER_BASE_OFFSET_Y
	local scale = (tonumber(settings.FRAME_SCALE) or DEFAULTS.FRAME_SCALE) / 100

	local maxCol = zo_ceil(GROUP_FRAME_CAPACITY / framesPerColumn)
	local maxRow = zo_min(GROUP_FRAME_CAPACITY, framesPerColumn)
	if settings.GROUP_LAYOUT == 2 then
		maxCol = 2
		maxRow = 12
	end

	local groupGap = tonumber(settings.GROUP_WINDOW_GAP) or DEFAULTS.GROUP_WINDOW_GAP
	local splitGap = settings.GROUP_LAYOUT == 2 and groupGap or 0
	local x = maxCol * (frameWidth + padX) + splitGap
	local y = maxRow * (frameHeight + padY)
	local containerWidth = x + (CONTANER_PAD * 2)
	local containerHeight = y + (CONTANER_PAD * 2)

	self.control:SetScale(scale)
	self.control:SetDimensions(containerWidth, containerHeight)

	-- Keep slider-selected positions valid after a scale change.
	local rootWidth = tonumber(GuiRoot:GetWidth()) or containerWidth
	local rootHeight = tonumber(GuiRoot:GetHeight()) or containerHeight
	local maxOffsetX = math.max(0, rootWidth - (containerWidth * scale))
	local maxOffsetY = math.max(0, rootHeight - (containerHeight * scale))
	offsetX = zo_clamp(offsetX, 0, maxOffsetX)
	offsetY = zo_clamp(offsetY, 0, maxOffsetY)
	settings.FRAME_CONTAINER_BASE_OFFSET_X = offsetX
	settings.FRAME_CONTAINER_BASE_OFFSET_Y = offsetY
	self.SAVEVARS.FRAME_CONTAINER_BASE_OFFSET_X = zo_round(offsetX)
	self.SAVEVARS.FRAME_CONTAINER_BASE_OFFSET_Y = zo_round(offsetY)

	self.control:ClearAnchors()
	self.control:SetAnchor(
		TOPLEFT,
		GuiRoot,
		TOPLEFT,
		offsetX,
		offsetY
	)

	if withElems then
		for _, unitFrame in pairs(self.unitFrames) do
			-- Refresh whether or not a frame is active, so that when switching between keyboard and
			-- controller, the frames are properly resized and ready for new group members
			unitFrame:RefreshView()
			unitFrame:RefreshPosition()
		end
	end
	self:RefreshPreview()
end

function UnitFramesManager:EnsurePreviewFrames()
	if self.previewFrames then return end
	self.previewFrames = {}
	for i = 1, GROUP_FRAME_CAPACITY do
		local control = CreateControlFromVirtual("ALTGF_PreviewFrame" .. i, self.control, "ALTGF_UnitFrame")
		local nameControl = GetControl(control, "Name")
		local hpControl = GetControl(control, "HP")
		local resourceControl = GetControl(control, "ResourceNumbers")
		local iconControl = GetControl(control, "Icon")
		local levelControl = GetControl(control, "Level")
		local shieldControl = GetControl(control, "Shield")
		local traumaControl = GetControl(control, "Trauma")
		nameControl:SetText("Preview Player " .. i)
		resourceControl:SetText("30000 / 30000")
		resourceControl:SetHidden(false)
		iconControl:SetHidden(true)
		levelControl:SetHidden(true)
		shieldControl:SetHidden(true)
		traumaControl:SetHidden(true)
		hpControl:SetMinMax(0, 100)
		hpControl:SetValue(100)
		hpControl:SetHidden(false)
		ZO_StatusBar_SetGradientColor(hpControl, self.SETTINGS.LFG_COLORS[LFG_ROLE_DPS])
		control:SetHidden(true)
		self.previewFrames[i] = control
	end
end

function UnitFramesManager:RefreshPreview()
	local settings = self.SETTINGS

	-- Do not eagerly instantiate all preview controls while preview mode is off.
	-- They are purely visual test frames, so creating them only when requested
	-- avoids spending a large part of the per-frame Lua CPU budget at login.
	if not settings.PREVIEW_MODE and not self.previewFrames then
		return
	end

	self:EnsurePreviewFrames()
	local framesPerColumn = tonumber(settings.FRAMES_PER_COLUMN) or DEFAULTS.FRAMES_PER_COLUMN
	local frameWidth = tonumber(settings.UNIT_FRAME_WIDTH) or (DEFAULTS.UNIT_FRAME_WIDTH + 40)
	local frameHeight = tonumber(settings.UNIT_FRAME_HEIGHT) or (DEFAULTS.UNIT_FRAME_HEIGHT + 10)
	local padX = tonumber(settings.UNIT_FRAME_PAD_X) or (DEFAULTS.UNIT_FRAME_PAD_X + 2)
	local padY = tonumber(settings.UNIT_FRAME_PAD_Y) or (DEFAULTS.UNIT_FRAME_PAD_Y + 2)
	local groupGap = tonumber(settings.GROUP_WINDOW_GAP) or DEFAULTS.GROUP_WINDOW_GAP

	for i, control in ipairs(self.previewFrames) do
		control:SetDimensions(frameWidth, frameHeight)
		local col = zo_ceil(i / framesPerColumn)
		local row = zo_mod(i - 1, framesPerColumn)

		-- Preview shows all 24 slots. In two-window mode they stay in two
		-- vertical windows: 1-6 + 13-18 on the left, 7-12 + 19-24 on the right.
		if settings.GROUP_LAYOUT == 2 then
			local block = zo_floor((i - 1) / 6)
			col = zo_mod(block, 2) + 1
			row = zo_floor(block / 2) * 6 + zo_mod(i - 1, 6)
		end
		local splitGap = settings.GROUP_LAYOUT == 2 and ((col - 1) * groupGap) or 0
		local x = ((col - 1) * (frameWidth + padX)) + splitGap + CONTANER_PAD
		local y = (row * (frameHeight + padY)) + CONTANER_PAD
		control:ClearAnchors()
		control:SetAnchor(TOPLEFT, self.control, TOPLEFT, x, y)
		control:SetHidden(not settings.PREVIEW_MODE)
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

function UnitFramesManager:RefreshData()
	local groupSize = type(GetGroupSize) == "function" and tonumber(GetGroupSize()) or 0
	local companionCount = type(GetNumCompanionsInGroup) == "function"
		and tonumber(GetNumCompanionsInGroup())
		or 0
	local newGroupSize = groupSize + companionCount

	for i = 1, GROUP_FRAME_CAPACITY do
		local unitTag = "group" .. i
		if DoesUnitExist(unitTag) then
			-- Create controls only for slots that actually exist. Previously the
			-- refresh path created every possible group slot (up to 24) in one Lua
			-- frame even when most were empty, which can hit the 1000 ms console
			-- add-on budget and leave a half-created control behind.
			local frame = self:GetFrame(unitTag)
			frame:RefreshData()
			frame:SetActive(true)
		else
			local frame = self.unitFrames[unitTag]
			if frame then
				frame:SetActive(false)
			end
		end

		local compUnitTag = GetCompanionUnitTagByGroupUnitTag(unitTag)
		if compUnitTag then
			if DoesUnitExist(compUnitTag) then
				local compFrame = self:GetFrame(compUnitTag)
				compFrame:RefreshData()
				compFrame:SetActive(true)
			else
				local compFrame = self.unitFrames[compUnitTag]
				if compFrame then
					compFrame:SetActive(false)
				end
			end
		end
	end

	-- A companion unit tag can disappear entirely when a companion is dismissed.
	-- Deactivate any already-created group companion frame whose unit no longer
	-- exists, without creating any new controls during this cleanup pass.
	for unitTag, frame in pairs(self.unitFrames) do
		if frame.isCompanion and unitTag ~= "companion" and not DoesUnitExist(unitTag) then
			frame:SetActive(false)
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

	self:ReorderByRole()

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

-- Keep ESO's native group-frame controls visually hidden, but leave their
-- manager and events active. On console those hidden native frames prime and
-- cache health for untouched group members; disabling the update pipeline made
-- custom frames receive 0/0 until somebody took damage.
DisableZoFrames = function()
	local groupControl = _G and _G["ZO_UnitFramesGroups"] or ZO_UnitFramesGroups
	if groupControl and type(groupControl.SetHidden) == "function" then
		groupControl:SetHidden(true)
	end
end

function ALTGF_UnitFrames_Initialize(topLevelControl)
	local function OnAddOnLoaded(_, addonName)
		if addonName == NAME then
			DisableZoFrames()

			UnitFrames = UnitFramesManager:New(topLevelControl)

			ALT_GROUP_FRAMES = UnitFrames

			local fragment = ZO_SimpleSceneFragment:New(topLevelControl)
			local scenes = {
				HUD_SCENE,
				HUD_UI_SCENE,
				SIEGE_BAR_SCENE,
				SIEGE_BAR_UI_SCENE,
			}
			for _, scene in ipairs(scenes) do
				if scene and type(scene.AddFragment) == "function" then
					scene:AddFragment(fragment)
				end
			end

			EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
		end
	end

	EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
end

function ALTGF_UnitFrames_OnUpdate()
	-- Native frames continue updating off-screen so their health cache remains
	-- available, but the parent is forced hidden in case a scene refresh toggles it.
	DisableZoFrames()
	if UnitFrames and UnitFrames:GetIsDirty() then
		UnitFrames:RefreshData()
	end
end
