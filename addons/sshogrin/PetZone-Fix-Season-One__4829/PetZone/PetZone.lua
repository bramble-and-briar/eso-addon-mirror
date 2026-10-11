--[[
-------------------------------------------------------------------------------
-- PetZone, by Brotanks
-------------------------------------------------------------------------------
This software is under : CreativeCommons CC BY-NC-SA 4.0
Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)

You are free to:

    Share — copy and redistribute the material in any medium or format
    Adapt — remix, transform, and build upon the material
    The licensor cannot revoke these freedoms as long as you follow the license terms.


Under the following terms:

    Attribution — You must give appropriate credit, provide a link to the license, and indicate if changes were made. You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.
    NonCommercial — You may not use the material for commercial purposes.
    ShareAlike — If you remix, transform, or build upon the material, you must distribute your contributions under the same license as the original.
    No additional restrictions — You may not apply legal terms or technological measures that legally restrict others from doing anything the license permits.


Please read full licence at :
http://creativecommons.org/licenses/by-nc-sa/4.0/legalcode
]]

if PZ == nil then PZ = {} end
local PetZone = PZ

PetZone.addonVars = {}
PetZone.addonVars.addonVersion		        = "3.5.0"
PetZone.addonVars.addonSavedVarsVersion	    = "0.01"
PetZone.addonVars.addonName				    = "PetZone"
PetZone.addonVars.addonNameMenu  		    = "PetZone"
PetZone.addonVars.addonNameMenuDisplay	    = "|c80FF00 PetZone|r"
PetZone.addonVars.addonSavedVariablesName   = "PetZone_Settings"
PetZone.addonVars.settingsName   		    = "PetZone"
PetZone.addonVars.addonAuthor			    = "Brotanks, fix: ren108"
PetZone.addonVars.addonWebsite              = "https://www.esoui.com/downloads/info2415-PetZone.html"

PetZone.settingsVars = {}
PetZone.settingsVars.defaultSettings = {}
PetZone.settingsVars.settings = {}
PetZone.settingsVars.defaults = {}

PetZone.preventerVars = {}
PetZone.preventerVars.doNotUpdateSubZoneValue = false
PetZone.preventerVars.doNotChangePresetPet = false

PetZone.LAMDropdownSubZoneNames = {}
PetZone.LAMDropdownSubZoneValues = {}
PetZone.LAMSelectedZone       = PZ_NONE_ENTRIES
PetZone.LAMSelectedSubZone    = PZ_NONE_ENTRIES
PetZone.previousZone = nil
PetZone.previousSubZone = nil

--Request the update to the Pet change
local function RequestPetUpdate()
    local callbackName = "PetZone_updatePetCollectible"
    
    local function Update()
        -- Use standard length operator (#) instead of deprecated table.maxn
        local maxIndex = #PetZone.DropdownPetValues
        if maxIndex == 0 then
            EVENT_MANAGER:UnregisterForUpdate(callbackName)
            return
        end
        
        local targetPetId = PetZone.DropdownPetValues[maxIndex]

        -- Check if the collectible is currently blocked (common during PvP exit loading screens)
        if GetCollectibleBlockReason(targetPetId) == 0 then
            EVENT_MANAGER:UnregisterForUpdate(callbackName)
            --Update the Pet collectible now
            PetZone.ActivatePetForZone(nil, nil) 
--          d("[PetZone] Pet update successful.")
        else
            -- SAFE RETRY: Unregister the interval update first to prevent exponential thread throttling
            EVENT_MANAGER:UnregisterForUpdate(callbackName)
            zo_callLater(Update, 1000)
--          d("[PetZone] Collectible blocked. Retrying in 1000ms...")
        end
    end

    -- Cancel any previously scheduled update to avoid race conditions
    EVENT_MANAGER:UnregisterForUpdate(callbackName)
    -- Register the initial loop
    EVENT_MANAGER:RegisterForUpdate(callbackName, 1000, function() Update() end)
end



function PetZone.EventCollectibleUseResult(eventCode, CollectibleUsageBlockReason, isAttemptingActivation)
    if not PetZone.preventerVars.doNotChangePresetPet and isAttemptingActivation then
        --Should the actively choosen Pet be saved as the zone & subzone preset Pet?
        if PetZone.settingsVars.settings.autoPresetForZoneOnNewPet then
            --Check a bit later as this event needs to finish first in order to update the active Pet with the new chosen one from the collectibles!
			zo_callLater(PetZone.checkAndPresetPetForZone, 250)
        end
    end
    PetZone.preventerVars.doNotChangePresetPet = false
end

-- EVENT_MOUNTED_STATE_CHANGED (number eventCode, boolean mounted)
function PetZone.EventMountedStateChanged(eventCode, isMounted)
		if PetZone.settingsVars.settings.MountStateChange then
            --Activate the Pet for the current zone & subzone
			zo_callLater(RequestPetUpdate, 1000)
		end
end

-- EVENT_ACTIVE_WEAPON_PAIR_CHANGED (number eventCode, number ActiveWeaponPair activeWeaponPair, boolean locked)
function PetZone.EventActiveWeaponPairChanged(eventCode, ActiveWeaponPair, locked)
	if PetZone.settingsVars.settings.WeaponSwapChange then
		RequestPetUpdate()
	end
end

-- EVENT_CURRENT_SUBZONE_LIST_CHANGED (number eventCode) 
-- EVENT_ZONE_CHANGED (number eventCode, string zoneName, string subZoneName, boolean newSubzone, number zoneId, number subZoneId) 
function PetZone.OnZoneChanged(eventCode, zoneName, subZoneName, newSubzone, zoneId, subZoneId)
--OnZoneChanged and OnSubZoneChanged turn up zones and subzones that are... weird. Putting in a check so this should only be triggered by our own zone/subzone designations
	local zone, subzone = PetZone.GetZoneAndSubzone()
	local subName = ""
	if PetZone.IdByName[zone] then
		for subNames, subIds in pairs(PetZone.IdByName[zone]) do
			if PZ.tableContains(subIds, subzone, true) then
				subName = subNames
				break
			end
		end
	else 
		return false
	end
	if 	PetZone.previousZone ~= zone or PetZone.previousSubZone ~= subName then
	--d("old zone: " ..tostring(PetZone.previousZone) .."/" ..tostring(PetZone.previousSubZone) .." new zone: " ..tostring(zone) .."/" ..tostring(subzone))
		zo_callLater(RequestPetUpdate, 250)
		PetZone.previousZone = zone
		PetZone.previousSubZone = subName
	end
end

function PetZone.InCombat(eventCode, inCombat)
	if PetZone.settingsVars.settings.HideInCombat then
		RequestPetUpdate()
	end
end

--EVENT_GROUP_MEMBER_LEFT(number eventCode, string memberCharacterName, GroupLeaveReason reason, boolean isLocalPlayer, boolean isLeader, string memberDisplayName, boolean actionRequiredVote)
--EVENT_GROUP_UPDATE (number eventCode)
function PetZone.GroupChanged()
	if PetZone.settingsVars.settings.HideInGroups then
		RequestPetUpdate()
	end
end

--EVENT_STEALTH_STATE_CHANGED (number eventCode, string unitTag, StealthState stealthState) 
function PetZone.StealthChanged(eventCode, unitTag, stealthState)
--	d("Stealth state: " .. tostring(stealthState))
	if stealthState == 0 or stealthState == 2 then
		RequestPetUpdate()
	end
end

function PetZone.OnBlocked() --eventCode, blockReason
	local zone, subZone = PetZone.GetZoneAndSubzone()
    --Get the Pet from the settings by help of the zone name, and subzone name
    local savedPetIdForZone = PetZone.GetPetByZone(zone, subZone)
    --Get the actively used Pet
    local activePetId = PetZone.GetActivePet()
	--if there's a mismatch between active and saved pet, update
	if type(savedPetIdForZone) == "number" then
		if (savedPetIdForZone > 0 and savedPetIdForZone ~= activePetId) or
		(savedPetIdForZone == -1 and (activePetId == 0 or activePetId == nil)) or
		(savedPetIdForZone == -2 and (activePetId ~= 0 or activePetId ~= nil)) then 
			d("pet usage blocked! Retrying...")
			RequestPetUpdate() 
		end
	elseif type(savedPetIdForZone) == "string" then
		local masterList = PetZone.settingsVars.settings.CustRandLists
		if not PZ.tableContains(masterList[savedPetIdForZone], activePetId, false, false) then
			d("pet usage blocked! Retrying...")
			RequestPetUpdate() 
		end
	end
end

--Player activated function
function PetZone.Player_Activated(...)
    --Reset current zone and subZone variables
	PetZone.LAMSelectedZone       = PZ_NONE_ENTRIES
    PetZone.LAMSelectedSubZone    = PZ_NONE_ENTRIES
    --Get the current game client's language
    local lang = GetCVar("language.2")
    if lang == nil or lang == "" then lang = "en" end
    PetZone.lang = lang
        --Activate the Pet for the current zone & subzone, force the activation on addon load/player activated
        RequestPetUpdate()

        --various events to check for pet updates
        EVENT_MANAGER:RegisterForEvent(PetZone.addonVars.addonName, EVENT_COLLECTIBLE_USE_RESULT, PetZone.EventCollectibleUseResult)
	--SUBZONE and ZONE events both call the same function here, since that function has a filter to align it more with our own zone/subzone designations
		EVENT_MANAGER:RegisterForEvent(PetZone.addonVars.addonName,  EVENT_CURRENT_SUBZONE_LIST_CHANGED, PetZone.OnZoneChanged)
		EVENT_MANAGER:RegisterForEvent(PetZone.addonVars.addonName,  EVENT_ZONE_CHANGED, PetZone.OnZoneChanged)
        if PetZone.settingsVars.settings.MountStateChange then EVENT_MANAGER:RegisterForEvent(PetZone.addonVars.addonName, EVENT_MOUNTED_STATE_CHANGED, PetZone.EventMountedStateChanged) end
        if PetZone.settingsVars.settings.WeaponSwapChange then EVENT_MANAGER:RegisterForEvent(PetZone.addonVars.addonName, EVENT_ACTIVE_WEAPON_PAIR_CHANGED, PetZone.EventActiveWeaponPairChanged) end
		if PetZone.settingsVars.settings.HideInCombat then EVENT_MANAGER:RegisterForEvent(PetZone.addonVars.addonName,  EVENT_PLAYER_COMBAT_STATE, PetZone.InCombat) end
		if PetZone.settingsVars.settings.HideInGroups then
			EVENT_MANAGER:RegisterForEvent(PetZone.addonVars.addonName, EVENT_GROUP_UPDATE, PetZone.GroupChanged)
			EVENT_MANAGER:RegisterForEvent(PetZone.addonVars.addonName, EVENT_GROUP_MEMBER_LEFT, PetZone.GroupChanged)
			EVENT_MANAGER:AddFilterForEvent(PetZone.addonVars.addonName, EVENT_GROUP_MEMBER_LEFT, REGISTER_FILTER_UNIT_TAG, "player")
		end
		if PetZone.settingsVars.settings.HideInStealth then EVENT_MANAGER:RegisterForEvent(PetZone.addonVars.addonName, EVENT_STEALTH_STATE_CHANGED, PetZone.StealthChanged) end
end

function PetZone.addonLoaded(eventName, addon)
	if addon ~= PetZone.addonVars.addonName then return end
    EVENT_MANAGER:UnregisterForEvent(eventName)
    --Create the settings panel object of libAddonMenu 2.0
    PetZone.LAM = LibAddonMenu2 --or LibStub('LibAddonMenu-2.0')
    --Create the zone data object of libZone
    PetZone.libZone = LibZone --or LibStub("LibZone")
	--Build the Pet data
	PetZone.BuildPetData()
    --Get the SavedVariables
    PetZone.getSettings()
    --Build the LAM
    PetZone.buildAddonMenu()
    --Register for the zone change/player ready event
    EVENT_MANAGER:RegisterForEvent(PetZone.addonVars.addonName, EVENT_PLAYER_ACTIVATED, PetZone.Player_Activated)
--	d("PetZone loaded")
	--seed for -RANDOM- choices
	math.randomseed(os.time())
	math.random()
	math.random()
	math.random()
	
end

function PetZone.initialize()
    EVENT_MANAGER:RegisterForEvent(PetZone.addonVars.addonName, EVENT_ADD_ON_LOADED, PetZone.addonLoaded)
end
PetZone.initialize()