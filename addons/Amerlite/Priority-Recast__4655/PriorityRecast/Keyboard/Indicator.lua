local PriorityRecast = PriorityRecast
local NextRecast     = PriorityRecast.NextRecast
local AbilityIcon    = GetAbilityIcon

local Window         = PriorityIndicator
local Icon           = PriorityIndicatorIcon

local inCombat       = false

-------------------------------------------------------------------------------
-- INDICATOR FUNCTIONALITY
-------------------------------------------------------------------------------

-- Initialize Window ----------------------------------------------------------

function Window.Initialize()

	-- Add to the the window to the HUD.
	HUD_SCENE:AddFragment(ZO_HUDFadeSceneFragment:New(Window))

	-- Make HUD position editable.
	local label = GetString(PRIORITYRECAST_TOOLTIP)
	HUD_MANAGER:RegisterKeyboardElement(Window, label, {
		defaultAnchor = ZO_Anchor:New(RIGHT, nil, CENTER, -50, 0),
		tooltipText   = label
	}, COMPASS_OPTIONS)

	-- Update with initial combat state.
	inCombat = IsUnitInCombat("player")
	Window.Update()
end


-- Update Indicator -----------------------------------------------------------

function Window.Update()
	PriorityRecast:ForgetUpdate()

	-- Stop if no longer in combat.
	if not inCombat then return Icon:SetHidden(true) end

	-- Update UI with next skill.
	local skillId = NextRecast()
	Icon:SetHidden(skillId == nil)
	Icon:SetTexture(AbilityIcon(skillId))

	-- Queue the next update.
	PriorityRecast:OnUpdate(100, Window.Update)
end


-- On Combat Change -----------------------------------------------------------

function Window.OnCombatState(_, state)
	inCombat = state
	if inCombat then Window.Update() end
end

-------------------------------------------------------------------------------
-- ADDON INITIALIZE
-------------------------------------------------------------------------------

PriorityRecast:RegisterCallback("AddonLoaded", function()
	Window.Initialize()
	PriorityRecast:On(EVENT_PLAYER_COMBAT_STATE, Window.OnCombatState)
end)
