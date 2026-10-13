if FCOCS == nil then FCOCS = {} end
local FCOChangeStuff = FCOCS

------------------------------------------------------------------------------------------------------------------------
-- Battleground --
------------------------------------------------------------------------------------------------------------------------

--Save the standard anchor and offsets of the BG HUD
function FCOChangeStuff.BGHUDStandardSave()
    local bgHUDctrl = BATTLEGROUND_HUD_FRAGMENT.control
    if bgHUDctrl ~= nil then
        FCOChangeStuff.standardAnchorOfBGHUD = {}
        local _, point, relTo, relPoint, x, y = bgHUDctrl:GetAnchor(0)
        FCOChangeStuff.standardAnchorOfBGHUD = {point, relTo, relPoint, x, y}
    end
end


--Make the BG HUD reset to it's default values
function FCOChangeStuff.BGHUDReset()
    local bgHUDctrl = BATTLEGROUND_HUD_FRAGMENT.control
    if bgHUDctrl ~= nil then
        if FCOChangeStuff.standardAnchorOfBGHUD == nil then
            FCOChangeStuff.BGHUDStandardSave()
        end
--d("Reset the anchor of BG HUD to the default!")
        bgHUDctrl:ClearAnchors()
        bgHUDctrl:SetAnchor(unpack(FCOChangeStuff.standardAnchorOfBGHUD))
    end
end

--Make the BG HUD movable?
local bgHUDMovableHooked = false
function FCOChangeStuff.BGHUDMoveable()
    local settings = FCOChangeStuff.settingsVars.settings
    --Get the saved x and y axis coordinates
    local settingsBGHUDCoordinates = settings.BGHUDcoordinates
    local shouldBeMovable = settings.enableBGHUDMoveable
    local bgHUDctrl = BATTLEGROUND_HUD_FRAGMENT.control
    --Is the BG HUD visible
    if bgHUDctrl ~= nil then
        bgHUDctrl:SetMouseEnabled(shouldBeMovable)
        bgHUDctrl:SetMovable(shouldBeMovable)

        --Is the control set to be non-movale then reset it's position to the original
        if not shouldBeMovable then
            FCOChangeStuff.BGHUDReset()
        else
            --d("Reanchored BG HUD to the HUD topleft!")
            --Change the anchor of the BG HUD now and reanchor it to the HUD topleft
            bgHUDctrl:ClearAnchors()
            bgHUDctrl:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, settingsBGHUDCoordinates.x, settingsBGHUDCoordinates.y)
        end

        --[[
                --Add handler function for on show of the control
                if bgHUDctrl:GetHandler("OnShow") == nil then
                    bgHUDctrl:SetHandler("OnShow", function()
        --d(">OnShow BG HUD")
                        if not settings.enableBGHUDMoveable then return false end
                        --Get the current anchor
                        local _, point, relTo, relPoint, _, _ = bgHUDctrl:GetAnchor(0)
                        --Reposition the BG HUD control to the saved position
                        if settingsBGHUDCoordinates ~= nil then
        --d(">settings offset x: " .. tostring(settingsBGHUDCoordinates.x) .. ", y: " .. tostring(settingsBGHUDCoordinates.y))
                            local savedAnchorOfBGHUD = {point, relTo, relPoint, settingsBGHUDCoordinates.x, settingsBGHUDCoordinates.y}
                            bgHUDctrl:ClearAnchors()
                            bgHUDctrl:SetAnchor(unpack(savedAnchorOfBGHUD))
                        end
                    end)
                end
        ]]

        if bgHUDMovableHooked then return end

        --Add handler function for move stop of the control
        if bgHUDctrl:GetHandler("OnMoveStop") == nil then
            --d("OnMoveStop Handler not found on BG HUD")
            bgHUDctrl:SetHandler("OnMoveStop", function()
                --d(">OnMoveStop")
                if not settings.enableBGHUDMoveable then return false end
                --Save the new x and y coordinates to the savedvars
                local x, y = bgHUDctrl:GetScreenRect()
                settings.BGHUDcoordinates.x = x
                settings.BGHUDcoordinates.y = y
                --d(">OnMoveStop, x: " .. tostring(x) .. ",  y: " .. tostring(y))
            end)
            --else
            --d("OnMoveStop Handler already found on BG HUD")
        end

        --Add a fragment callback function for the "OnShown" state to replace the position
        BATTLEGROUND_HUD_FRAGMENT:RegisterCallback("StateChange", function(oldState, newState)
            -- possible states are:
            --    SCENE_FRAGMENT_SHOWN = "shown"
            --    SCENE_FRAGMENT_HIDDEN = "hidden"
            --    SCENE_FRAGMENT_SHOWING = "showing"
            --    SCENE_FRAGMENT_HIDING = "hiding"
            if newState == SCENE_FRAGMENT_SHOWN then
                if not settings.enableBGHUDMoveable then return false end
                --Get the BG HUD control
                local bgHUDctrl = BATTLEGROUND_HUD_FRAGMENT.control
                --Is the BG HUD visible
                if bgHUDctrl ~= nil then
                    --Reposition the BG HUD control to the saved position
                    if settingsBGHUDCoordinates ~= nil then
                        --Get the current anchor
                        local _, point, relTo, relPoint, _, _ = bgHUDctrl:GetAnchor(0)
                        --d(">settings offset x: " .. tostring(settingsBGHUDCoordinates.x) .. ", y: " .. tostring(settingsBGHUDCoordinates.y))
                        local savedAnchorOfBGHUD = {point, relTo, relPoint, settingsBGHUDCoordinates.x, settingsBGHUDCoordinates.y}
                        bgHUDctrl:ClearAnchors()
                        bgHUDctrl:SetAnchor(unpack(savedAnchorOfBGHUD))
                    end
                end
            end
        end)
        bgHUDMovableHooked = true
    end
end

--Enable the battleground modifications
function FCOChangeStuff.bgModifications()
    FCOChangeStuff.BGHUDMoveable()
end