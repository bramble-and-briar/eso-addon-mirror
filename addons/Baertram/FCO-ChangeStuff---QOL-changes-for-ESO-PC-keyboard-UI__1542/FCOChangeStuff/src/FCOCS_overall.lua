if FCOCS == nil then FCOCS = {} end
local FCOChangeStuff = FCOCS

local endInworldInteractionFragment = END_IN_WORLD_INTERACTIONS_FRAGMENT
local inventoryScene = SCENE_MANAGER:GetScene('inventory')
local treasureMapInvScene = TREASURE_MAP_INVENTORY_SCENE
local playerFrameFragment = FRAME_PLAYER_FRAGMENT
local targetCenteredFrameFragment = FRAME_TARGET_CENTERED_FRAGMENT
local orgIsCharacterPreviewingAvailable = IsCharacterPreviewingAvailable

------------------------------------------------------------------------------------------------------------------------
-- Overall --
------------------------------------------------------------------------------------------------------------------------
--Prevent the end of harvesting and other in-world interactions if you open menus
ZO_PreHook(endInworldInteractionFragment, "Show", function(self)
    --if NoThankYou addon is enabled then let it control these settings
    if FCOChangeStuff.otherAddons.NoThankYou == true then return false end

    if not FCOChangeStuff.settingsVars.settings.doNotInterruptInWorldOnMenuOpen then return end
    EndPendingInteraction()
    self:OnShown()
    return true
end)

local function removeInteractionAbortOnMenuOpen(doRemove)
    --if NoThankYou addon is enabled then let it control these settings
    if FCOChangeStuff.otherAddons.NoThankYou == true then return end
    if doRemove then
        function IsCharacterPreviewingAvailable()
            if inventoryScene:IsShowing() then
                return true
            else
                return orgIsCharacterPreviewingAvailable()
            end
        end
    else
        function IsCharacterPreviewingAvailable()
            return orgIsCharacterPreviewingAvailable()
        end
    end
end

local function removePlayerSpinFragment(doRemove)
    --if NoThankYou addon is enabled then let it control these settings
    if FCOChangeStuff.otherAddons.NoThankYou == true then return end

    local settings = FCOChangeStuff.settingsVars.settings

    if doRemove then
        if inventoryScene:HasFragment(playerFrameFragment) and settings.spinStopAtScenes["inventory"] then
            inventoryScene:RemoveFragment(playerFrameFragment)
        end
        if treasureMapInvScene:HasFragment(targetCenteredFrameFragment) then
            treasureMapInvScene:RemoveFragment(targetCenteredFrameFragment)
        end
        if treasureMapInvScene:HasFragment(playerFrameFragment) then
            treasureMapInvScene:RemoveFragment(playerFrameFragment)
        end
    else
        if not inventoryScene:HasFragment(playerFrameFragment) then
            inventoryScene:AddFragment(playerFrameFragment)
        end
        if not treasureMapInvScene:HasFragment(targetCenteredFrameFragment) then
            treasureMapInvScene:AddFragment(targetCenteredFrameFragment)
        end
        if not treasureMapInvScene:HasFragment(playerFrameFragment) then
            treasureMapInvScene:AddFragment(playerFrameFragment)
        end
    end
end

function FCOChangeStuff.overallSetDoNotInterruptInWorldOnMenuOpen(doNotInterruptInWorldOnMenuOpen)
    --if NoThankYou addon is enabled then let it control these settings
    if FCOChangeStuff.otherAddons.NoThankYou == true then return end

    removePlayerSpinFragment(doNotInterruptInWorldOnMenuOpen)
    removeInteractionAbortOnMenuOpen(doNotInterruptInWorldOnMenuOpen)
end


function FCOChangeStuff.overallFunctions()
    FCOChangeStuff.overallSetDoNotInterruptInWorldOnMenuOpen(FCOChangeStuff.settingsVars.settings.doNotInterruptInWorldOnMenuOpen)
end