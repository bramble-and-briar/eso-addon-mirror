if FCOCS == nil then FCOCS = {} end
local FCOChangeStuff = FCOCS

local EM = EVENT_MANAGER
local strlow = string.lower

------------------------------------------------------------------------------------------------------------------------
-- Sounds --
------------------------------------------------------------------------------------------------------------------------

--======== DISABLE SOUNDS ====================================================
FCOChangeStuff.disabledSoundBackups = {}
FCOChangeStuff.disableSoundsShifterBoxControl = nil
local sfxSoundMuted = false
local soundVolumesBefore = {}

FCOChangeStuff.LSB = LibShifterBox

local function searchKeyAndValue(shifterBox, entry, searchStr)
    --Search for key OR value: entry.value entry.key
    local found = false
    local searchTermLower = strlow(searchStr)
    if entry.name then
        found = entry.name:find(searchStr) ~= nil
        if not found then
            found = strlow(entry.name):find(searchTermLower) ~= nil
        end
    end
    if not found and entry.value then
        found = entry.value:find(searchStr) ~= nil
        if not found then
            found = strlow(entry.value):find(searchTermLower) ~= nil
        end
    end
    return found
end

---Disable sunds LibShifterBox settings and style
local disableSoundsLibShifterBoxCustomSettings = {
    --[[
    callbackRegister = {
        [FCOChangeStuff.LSB.EVENT_LEFT_LIST_CREATED]            = function()
            d("LSB: Event left list created")
        end,
        [FCOChangeStuff.LSB.EVENT_RIGHT_LIST_CREATED]           = function()
            d("LSB: Event right list created")
        end,
        [FCOChangeStuff.LSB.EVENT_LEFT_LIST_ROW_ON_MOUSE_ENTER] = function()
            d("[FCOCS]LSB event left list row on mouse enter")
        end,
        [FCOChangeStuff.LSB.EVENT_LEFT_LIST_ROW_ON_MOUSE_EXIT]  = function()
            d("[FCOCS]LSB event left list row on mouse exit")
        end,
        [FCOChangeStuff.LSB.EVENT_LEFT_LIST_ROW_ON_DRAG_START]  = function()
            d("[FCOCS]LSB event left list row on drag start")
        end,
        [FCOChangeStuff.LSB.EVENT_RIGHT_LIST_ROW_ON_DRAG_END]   = function()
            d("[FCOCS]LSB event right list row on drag end")
        end,
    },
    rowOnMouseEnter = function(rowControl)
        local data = ZO_ScrollList_GetData(rowControl)
        d("LSB: OnMouseEnter: " ..tostring(data.tooltipText))
    end,
    rowOnMouseExit = function(rowControl) d("LSB: OnMouseExit")  end,
    rowOnMouseRightClick = function(rowControl, data) d("LSB: OnMouseRightClick") end,
    rowSetupCallback = function(rowControl, data)
        d("LSB: SetupCallback -> Calls self:SetupRowEntry, then this function, finally ZO_SortFilterList.SetupRow")
        data.tooltipText = "Hello world"
    end,
    rowDataTypeSelectSound = "ACTIVE_SKILL_RESPEC_MORPH_CHOSEN",
    rowResetControlCallback = function() d("LSB: ResetControlCallback")  end,
    rowSetupAdditionalDataCallback = function(rowControl, data)
        d("LSB: SetupAdditionalDataCallback")
            data.tooltipText = data.value
        return rowControl, data
    end,
    ]]
    leftList = {
        title = "Available sounds",
    },
    rightList = {
        title = "Disabled sounds",
        buttonTemplates = {
            moveButton = {
                normalTexture = "/esoui/art/inventory/inventory_tabicon_craftbag_up.dds",
                mouseOverTexture = "/esoui/art/inventory/inventory_tabicon_craftbag_over.dds",
                pressedTexture = "/esoui/art/inventory/inventory_tabicon_craftbag_down.dds",
                disabledTexture = "/esoui/art/inventory/inventory_tabicon_craftbag_disabled.dds",
                anchors = {
                    [1] = { BOTTOMRIGHT, "$(parent)List", BOTTOMLEFT, -2, 0 },
                },
                dimensions = { x=20, y=20 }
            },
            moveAllButton = {
                normalTexture = "/esoui/art/inventory/inventory_trait_not_researched_icon.dds",
                mouseOverTexture = "/esoui/art/inventory/inventory_trait_not_researched_icon.dds",
                pressedTexture = "/esoui/art/inventory/inventory_trait_not_researched_icon.dds",
                disabledTexture = "/esoui/art/inventory/inventory_trait_not_researched_icon.dds",
                anchors = {
                    [1] = { BOTTOM , "$(parent)Button", TOP, 0, -2 },
                },
                dimensions = { x=20, y=20 }
            },
            searchButton = {
                normalTexture = "/esoui/art/inventory/inventory_trait_not_researched_icon.dds",
                mouseOverTexture = "/esoui/art/inventory/inventory_trait_not_researched_icon.dds",
                pressedTexture = "/esoui/art/inventory/inventory_trait_not_researched_icon.dds",
                disabledTexture = "/esoui/art/inventory/inventory_trait_not_researched_icon.dds",
                anchors = {
                    [1] = { RIGHT, "$(parent)", RIGHT, -60, 0 },
                },
                dimensions = { x=60, y=60 }
            }
        }
    },
    search = {
            enabled = true,
            searchFunc = searchKeyAndValue
    },
}
local disableSoundsLibShifterBoxStyle = {
    width       = 600,
    height      = 200,
}

--[[
local function getLeftListEntriesFull(shifterBox)
    if not shifterBox then return end
    return shifterBox:GetLeftListEntriesFull()
end

local function getRightListEntriesFull(shifterBox)
    if not shifterBox then return end
    return shifterBox:GetRightListEntriesFull()
end
]]
function FCOChangeStuff.setSoundsDisabledState()
    local backupedSounds = FCOChangeStuff.disabledSoundBackups
    local isDisableSoundLSBEnabled = FCOChangeStuff.settingsVars.settings.disableSoundsLibShifterBox
    local leftListSoundsWithoutDisabledOnes = {}
    local disabledSoundsFromSV = FCOChangeStuff.settingsVars.settings.disabledSoundEntries
    for k,v in pairs(backupedSounds) do
        --Non-disabled sound from the SavedVariables?
        if disabledSoundsFromSV[k] == nil then
            --Add the sound entry to the left list (non disabled)
            leftListSoundsWithoutDisabledOnes[k] = v
            --Re-enable the sound again
            SOUNDS[k] = v
        else
            --Disabled sound from the SavedVariables
            if isDisableSoundLSBEnabled == true then
                --Set the selected (right LibShifterBox) sound muted
                SOUNDS[k] = SOUNDS.NONE
            else
                --Re-enable the sound again
                SOUNDS[k] = v
            end
        end
    end
    return leftListSoundsWithoutDisabledOnes, disabledSoundsFromSV
end
local setSoundsDisabledState = FCOChangeStuff.setSoundsDisabledState

function FCOChangeStuff.updateDisableSoundsLibShifterBoxEntries(shifterBox)
    if not shifterBox then return end
    local leftListSoundsWithoutDisabledOnes, disabledSoundsFromSV = setSoundsDisabledState()

    shifterBox:ClearLeftList()
    shifterBox:AddEntriesToLeftList(leftListSoundsWithoutDisabledOnes)

    shifterBox:ClearRightList()
    shifterBox:AddEntriesToRightList(disabledSoundsFromSV)
end

local function myShifterBoxEventEntryMovedCallbackFunction(shifterBox, key, value, categoryId, isDestListLeftList, fromList, toList)
--d("[FCOCS]myShifterBoxEventEntryMovedCallbackFunction - key: " ..tostring(key) .. ", isDestListLeftList:  "..tostring(isDestListLeftList))
    if not shifterBox or not key then return end
    if not FCOChangeStuff.settingsVars.settings.disableSoundsLibShifterBox then return end

    --Moved to the left?
    if isDestListLeftList == true then
        FCOChangeStuff.settingsVars.settings.disabledSoundEntries[key] = nil
        --Restore the sound
        SOUNDS[key] = FCOChangeStuff.disabledSoundBackups[key]
    else
        --Moved to the right?
        FCOChangeStuff.settingsVars.settings.disabledSoundEntries[key] = value
        --Restore the sound
        local backupSoundName = value
        FCOChangeStuff.disabledSoundBackups[key] = backupSoundName
        SOUNDS[key] = SOUNDS.NONE
    end

end

local function myShifterBoxEventEntryHighlightedCallbackFunction(control, shifterBox, key, value, categoryId, isLeftList)
    if not shifterBox or not key then return end
    if not FCOChangeStuff.settingsVars.settings.disableSoundsLibShifterBox then return end

    if isLeftList == true then
        if SOUNDS and SOUNDS[key] then
            PlaySound(SOUNDS[key])
        end
    else
        if FCOChangeStuff.disabledSoundBackups and FCOChangeStuff.disabledSoundBackups[key] then
            PlaySound(FCOChangeStuff.disabledSoundBackups[key])
        end
    end
end

local function updateDisableSoundsLibShifterBox(parentCtrl)
    local disableSoundsShifterBox = FCOChangeStuff.disableSoundsShifterBoxControl
    if not disableSoundsShifterBox or not parentCtrl then return end
    parentCtrl:SetResizeToFitDescendents(true)

    disableSoundsShifterBox:SetAnchor(TOPLEFT, parentCtrl, TOPLEFT, 0, 0) -- will automatically call ClearAnchors
    disableSoundsShifterBox:SetDimensions(disableSoundsLibShifterBoxStyle.width, disableSoundsLibShifterBoxStyle.height)

    FCOChangeStuff.updateDisableSoundsLibShifterBoxEntries(disableSoundsShifterBox)

    FCOChangeStuff.updateDisabledSoundsLibShifterBoxState(parentCtrl, disableSoundsShifterBox)

    --Add the callback function to the entry was moved event
    disableSoundsShifterBox:RegisterCallback(FCOChangeStuff.LSB.EVENT_ENTRY_MOVED, myShifterBoxEventEntryMovedCallbackFunction)
    --Add the callback for the PlaySound as an entry was highlighted at the left side
    disableSoundsShifterBox:RegisterCallback(FCOChangeStuff.LSB.EVENT_ENTRY_HIGHLIGHTED, myShifterBoxEventEntryHighlightedCallbackFunction)
end

function FCOChangeStuff.updateDisabledSoundsLibShifterBoxState(parentCtrl, disableSoundsShifterBox)
    disableSoundsShifterBox = disableSoundsShifterBox or FCOChangeStuff.disableSoundsShifterBoxControl
    if not parentCtrl or not disableSoundsShifterBox then return end
    local isDisableSoundLSBEnabled = FCOChangeStuff.settingsVars.settings.disableSoundsLibShifterBox
    parentCtrl:SetHidden(false)
    parentCtrl:SetMouseEnabled(isDisableSoundLSBEnabled)
    disableSoundsShifterBox:SetHidden(false)
    disableSoundsShifterBox:SetEnabled(isDisableSoundLSBEnabled)
end

function FCOChangeStuff.buildSoundsLibShifterBox(parentCtrl)
    if parentCtrl == nil then return end
    local addonName = FCOChangeStuff.addonVars.addonName

    FCOChangeStuff.LSB = LibShifterBox
    local disableSoundsShifterBox = FCOChangeStuff.LSB(addonName, "FCOCHANGESTUFF_LAM_CUSTOM_SOUNDS_DISABLE_PARENT_LSB", parentCtrl, disableSoundsLibShifterBoxCustomSettings)
    FCOChangeStuff.disableSoundsShifterBoxControl = disableSoundsShifterBox
    updateDisableSoundsLibShifterBox(parentCtrl)
end

function FCOChangeStuff.getSoundsLibShifterBox(parentCtrl)
    if parentCtrl == nil then return end
    FCOChangeStuff.updateSoundsLibShifterBox(parentCtrl)
    return FCOChangeStuff.disableSoundsShifterBoxControl
end

function FCOChangeStuff.updateSoundsLibShifterBox(parentCtrl)
    if parentCtrl == nil then return end
    if FCOChangeStuff.disableSoundsShifterBoxControl == nil then
        FCOChangeStuff.buildSoundsLibShifterBox(parentCtrl)
    else
        updateDisableSoundsLibShifterBox(parentCtrl)
    end
end

local function changeOrRestoreSound(settingType, soundType, volume, doMute)
    if soundType == nil then return end
    if doMute == true then
        --Save old volume
        soundVolumesBefore[settingType] = soundVolumesBefore[settingType] or {}
        soundVolumesBefore[settingType][soundType] = GetSetting(settingType, soundType)
        --Set new sound
        volume = volume or "0"
        SetSetting(settingType, soundType, tostring(volume))
    else
        --Load old volume
        local restoreSoundVolume = tonumber(volume) or tonumber(soundVolumesBefore[settingType][soundType])
        if restoreSoundVolume < 0 then restoreSoundVolume = 0 end
        if restoreSoundVolume > 100 then restoreSoundVolume = 100 end
        SetSetting(settingType, soundType, tostring(restoreSoundVolume))
    end
end

--Mute the sound for a chosen time (milliseconds) as you mount to disable these loud mount noises
local soundWasMutedByFCOCSDueToMountingVolumeBefore = 0
local eventMountStateChangedWasRegistered
function FCOChangeStuff.muteMountSound()
    local addonName = FCOChangeStuff.addonVars.addonName
    local settings = FCOChangeStuff.settingsVars.settings
    if settings.muteMountSound == true then
        local function onMountStateChanged(eventId, isMounted)
            if isMounted == true then
                --Is the sound enabled?
                local isSoundEnabled = GetSetting_Bool(SETTING_TYPE_AUDIO, AUDIO_SETTING_AUDIO_ENABLED)
                if not isSoundEnabled then return end
                if not settings.muteMountSound == true then return end
                --Mute the game sound now
                soundWasMutedByFCOCSDueToMountingVolumeBefore = GetSetting(SETTING_TYPE_AUDIO, AUDIO_SETTING_SFX_VOLUME)
                if soundWasMutedByFCOCSDueToMountingVolumeBefore == "0" then return end
                --Mute now/or lower volume
                changeOrRestoreSound(SETTING_TYPE_AUDIO, AUDIO_SETTING_SFX_VOLUME, settings.muteMountSoundVolume, true)
                local soundMuteDelay = settings.muteMountSoundDelay
                zo_callLater(function()
                    if soundWasMutedByFCOCSDueToMountingVolumeBefore ~= "0" then
                        --Unmute to old sound volume again
                        changeOrRestoreSound(SETTING_TYPE_AUDIO, AUDIO_SETTING_SFX_VOLUME, soundWasMutedByFCOCSDueToMountingVolumeBefore, false)
                    end
                end, soundMuteDelay)
            end
        end
        --EVENT_MOUNTED_STATE_CHANGED
        eventMountStateChangedWasRegistered = EM:RegisterForEvent(addonName.."_MOUNT_STATE_CHANGED", EVENT_MOUNTED_STATE_CHANGED, onMountStateChanged)
    else
        if eventMountStateChangedWasRegistered ~= nil then
            EM:UnregisterForEvent(addonName.."_MOUNT_STATE_CHANGED", EVENT_MOUNTED_STATE_CHANGED)
        end
    end
end

--Add a keybind to mute the SFX sound
function FCOChangeStuff.muteSFXSound()
    local volume
    if not sfxSoundMuted then
        volume = 0
    end
    changeOrRestoreSound(SETTING_TYPE_AUDIO, AUDIO_SETTING_SFX_VOLUME, volume, not sfxSoundMuted)
    sfxSoundMuted = not sfxSoundMuted
end

--Apply the sound related changes
function FCOChangeStuff.soundChanges()
    --Backup the original sounds
    FCOChangeStuff.disabledSoundBackups = ZO_ShallowTableCopy(SOUNDS)

    FCOChangeStuff.setSoundsDisabledState()
end
