if FCOCS == nil then FCOCS = {} end
local FCOChangeStuff = FCOCS

local SM = SCENE_MANAGER
local scenes = SM.scenes

------------------------------------------------------------------------------------------------------------------------
-- After login --
------------------------------------------------------------------------------------------------------------------------

--Original "You are enlightened sound"
local origEnlightenedSound = SOUNDS.ENLIGHTENED_STATE_GAINED

--Kill the "You are enlightened" sound
function FCOChangeStuff.noEnlightenedSound()
    local settings = FCOChangeStuff.settingsVars.settings
    if settings.noEnlightenedSound then
        SOUNDS.ENLIGHTENED_STATE_GAINED = SOUNDS.NONE
    else
        SOUNDS.ENLIGHTENED_STATE_GAINED = origEnlightenedSound
    end
end

--Hook the game menu scene to see if it's active
local function GameMenuScene_SetState(self, new_state, ...)
    if new_state == SCENE_SHOWN then
--d(">Game menu showing")
        FCOChangeStuff.gameMenuSceneActive = true
    end
    return false
end

--SCENE SetState hook function for the crown store advertisements
local function CrownStoreAdvertisementsScene_SetState(self, new_state, ...)
    --No game menu was shown so hide/show the crown store announcements according to the settings
    if new_state == SCENE_SHOWN then
        --Is the game menu scene shown: Then do not hide the crown announcements as the user clicked it on purpose!
        if FCOChangeStuff.gameMenuSceneActive then
--d(">Game menu scene was shown, not hiding the crown store announcements!")
            FCOChangeStuff.gameMenuSceneActive = false
            return false
        end

        local settings = FCOChangeStuff.settingsVars.settings
        local doNotShowCrownStoreAdvertisements = settings.noShopAdvertisementPopup
        if doNotShowCrownStoreAdvertisements then
--d(">>Hiding announcements scene!")
            SM:ShowBaseScene()
        end
        return doNotShowCrownStoreAdvertisements
    end
end

--Hide the shop advertisements popup
local hookWasDone = {
    ["gameMenuInGame"] = false,
    ["marketAnnouncement"] = false,
}
function FCOChangeStuff.noShopAdvertisement()
    local settings = FCOChangeStuff.settingsVars.settings
    if not settings.noShopAdvertisementPopup then return false end
    if scenes.gameMenuInGame and not hookWasDone["gameMenuInGame"] then
        ZO_PreHook(scenes.gameMenuInGame, "SetState", GameMenuScene_SetState)
        hookWasDone["gameMenuInGame"] = true
    end
    if scenes.marketAnnouncement and not hookWasDone["marketAnnouncement"]  then
        ZO_PreHook(scenes.marketAnnouncement, "SetState", CrownStoreAdvertisementsScene_SetState)
        hookWasDone["marketAnnouncement"] = true
    end
end

function FCOChangeStuff.afterLoginOrReloaduiFunctions()
    --> Already run at login once and then again as the settings menu changes it!
    --FCOChangeStuff.noEnlightenedSound()

    --Hide the crown shop advertisements popup
    FCOChangeStuff.noShopAdvertisement()
end