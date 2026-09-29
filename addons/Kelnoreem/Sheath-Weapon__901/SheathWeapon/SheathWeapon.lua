-- Sheath Weapon is a ESO plugin created by GlassHalfFull
-- This plug-in has one purpose, to sheath your weapon when out of combat


-- define some variables
local wm = GetWindowManager()
local em = GetEventManager()
local _

-- create a namespace for SW by declaring a top-level table that will hold everything else.
if SW == nil then SW = {} end

-- The AddOn name
SW.name = "SheathWeapon"
SW.version = "3.24"

SW.settings = {}                          

-- default values for saved variables, using milli seconds
SW.defaults = {
	timeToWaitBeforeSheathing = 3500,
	timeToLoop = 2500,
	timeToCheckCombatState = 4000,
}


--
-- This function that will initialize our addon with ESO
--
function SW.Initialize(event, addon)
	if addon ~= SW.name then return end

	em:UnregisterForEvent("SheathWeaponInitialize", EVENT_ADD_ON_LOADED)

	-- load our saved variables
	SW.settings = ZO_SavedVars:New("SheathWeaponSavedVars", 1, nil, SW.defaults)

	-- make a label for our keybinding
	ZO_CreateStringId("SI_BINDING_NAME_SHEATH_WEAPON_TOGGLE", "Toggle Window")

	-- make our options menu
	SW.MakeMenu()

    -- Register SW.Trigger here in Initialize where SW.settings will not be NIL
    em:RegisterForEvent("SheathWeaponTrigger", EVENT_PLAYER_COMBAT_STATE, SW.Trigger)
end



-- EVENT_PLAYER_COMBAT_STATE sends 'true' once when combat starts
-- and then 'nil' on every update, so we just check for 'true' to start our loop
-- Update: A player reported gamepad mode has issues, for now, do nothing to avoid those issues.
-- Gamepad mode will need more research.
function SW.Trigger(_, inCombat)
    if IsInGamepadPreferredMode() then
        -- d("Hello, gamepad user!")
        -- todo: place gamepad code here, once i research what is needed
    else
        if inCombat then
            zo_callLater(SW.Loop, SW.settings.timeToCheckCombatState)
        end
    end
end

-- Determine whether we're still in combat. If we're not, wait timeToWaitBeforeSheathing 
-- to let animations finish playing, then call TogglePlayerWield to sheath weapons.  
-- Otherwise wait timeToLoop.
function SW.Loop()
	if IsUnitInCombat("player") == false then
		zo_callLater(TogglePlayerWield, SW.settings.timeToWaitBeforeSheathing)
	else
		zo_callLater(SW.Loop, SW.settings.timeToLoop)
	end
end



-- register to be initialized when we're ready
em:RegisterForEvent("SheathWeaponInitialize", EVENT_ADD_ON_LOADED, function(...) SW.Initialize(...) end)

