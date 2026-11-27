-- Gamepad resource bar placement.
--   * Attribute bar shift: moves the Magicka and Stamina bars the same distance
--     toward the health bar (a negative value moves them outward). The game
--     anchors Magicka by its RIGHT edge and Stamina by its LEFT edge to their
--     parent.
--   * Health bar height: moves the health bar up (a negative value moves it
--     down). The siege and shield bars hang off the health bar, so they follow.
-- The base-game HUD manager (Edit HUD) resets those anchors on load, on a
-- gamepad/keyboard mode change, and on screen resize; the offsets are
-- re-applied after each reset. A bar the player moved in Edit HUD is left alone.
-- Moving the combined group in Edit HUD moves the parent, so these offsets stay
-- relative to wherever the player put it.

local NAMESPACE = "KelaPadUIEnhanced_ResourceBars"
local KELA_OPTIONS_SCENE_NAME = "kela_options_root"

-- offset(): the bar's (x, y) offset from the game's own anchor. Magicka and
-- Stamina move sideways toward the center (+1 right, -1 left); health moves up.
local function GetSettingNumber(settingId)
	if not IsInGamepadPreferredMode() then
		return 0
	end
	return KelaGetSetting_Number(SETTING_TYPE_KELA, settingId) or 0
end

local function SideShift(direction)
	return function()
		return direction * GetSettingNumber(KELA_SETTING_PANEL_ACTIONBAR_RESOURCE_SHIFT), 0
	end
end

local BARS =
{
	{ controlName = "ZO_PlayerAttributeMagicka", offset = SideShift(1) },
	{ controlName = "ZO_PlayerAttributeStamina", offset = SideShift(-1) },
	{ controlName = "ZO_PlayerAttributeHealth", offset = function()
		return 0, -GetSettingNumber(KELA_SETTING_PANEL_ACTIONBAR_HEALTH_RAISE)
	end },
}

local baseAnchors = {}
-- The offset last applied to each bar, so a bar is only touched while it has
-- one to apply or to take back.
local appliedOffsets = {}

-- A bar the player positioned in Edit HUD keeps that position.
local function IsMovedInHudEditor(control)
	local element = HUD_MANAGER and HUD_MANAGER:GetGamepadElementForControl(control)
	return element ~= nil and not element:IsUsingDefaultAnchor()
end

local function CaptureBaseAnchor(bar, control)
	if baseAnchors[bar.controlName] then
		return baseAnchors[bar.controlName]
	end
	local isValid, point, relativeTo, relativePoint, offsetX, offsetY = control:GetAnchor(0)
	if not isValid then
		return nil
	end
	local base = { point = point, relativeTo = relativeTo, relativePoint = relativePoint, offsetX = offsetX, offsetY = offsetY }
	baseAnchors[bar.controlName] = base
	return base
end

local function Apply()
	for _, bar in ipairs(BARS) do
		local offsetX, offsetY = bar.offset()
		local key = offsetX .. ":" .. offsetY
		-- Nothing to do when no offset is set and none was applied before.
		local control = _G[bar.controlName]
		if control and (key ~= "0:0" or appliedOffsets[bar.controlName]) and not IsMovedInHudEditor(control) then
			local base = CaptureBaseAnchor(bar, control)
			if base then
				-- One anchor only: the HUD manager asserts a single anchor.
				control:ClearAnchors()
				control:SetAnchor(base.point, base.relativeTo, base.relativePoint, base.offsetX + offsetX, base.offsetY + offsetY)
				appliedOffsets[bar.controlName] = key ~= "0:0" and key or nil
			end
		end
	end
end

function KelaSetupResourceBars()
	if KelaPadUI.KelaResourceBarsInitialized then
		return
	end
	KelaPadUI.KelaResourceBarsInitialized = true

	-- Capture the game's own anchors before anything moves the bars.
	for _, bar in ipairs(BARS) do
		local control = _G[bar.controlName]
		if control then
			CaptureBaseAnchor(bar, control)
		end
	end

	if HUD_MANAGER then
		HUD_MANAGER:RegisterCallback("PropagateSettings", Apply)
		HUD_MANAGER:RegisterCallback("OffsetsChanged", Apply)
	end
	EVENT_MANAGER:RegisterForEvent(NAMESPACE, EVENT_PLAYER_ACTIVATED, Apply)
	-- Fired by the shift slider, so the bars move while the menu is open.
	CALLBACK_MANAGER:RegisterCallback("KELA_ACTIONBAR_SETTINGS_CHANGED", Apply)

	local optionsScene = SCENE_MANAGER:GetScene(KELA_OPTIONS_SCENE_NAME)
	if optionsScene then
		optionsScene:RegisterCallback("StateChange", function(_, newState)
			if newState == SCENE_HIDDEN then
				Apply()
			end
		end)
	end
end
