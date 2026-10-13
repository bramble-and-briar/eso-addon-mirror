if FCOCS == nil then FCOCS = {} end
local FCOChangeStuff = FCOCS

------------------------------------------------------------------------------------------------------------------------
-- Dialogs --
------------------------------------------------------------------------------------------------------------------------

--local dialogHooksApplied = {}

local dialogOnShowHooked = false
local function loadDialogOnShowHook()
    if not dialogOnShowHooked then
        --Suppress the trading house "Cancel listing" dialog
        ZO_PreHook("ZO_Dialogs_ShowDialog", function(dialogName)
            --d("[ZO_Dialogs_ShowDialog]dialogName: " ..tostring(dialogName))
            if dialogName ~= nil then
                local suppressDialog = FCOChangeStuff.settingsVars.settings.suppressDialog
                if dialogName == "CONFIRM_TRADING_HOUSE_CANCEL_LISTING" and suppressDialog[dialogName] == true then
                    --d(">supressing confirm cancel tarding house listing dialog")
                    local listIndex = TRADING_HOUSE.cancelListingDialog.listingIndex
                    if listIndex ~= nil then
                        --d(">>ListIndex: " ..tostring(listIndex))
                        CancelTradingHouseListing(listIndex)
                        TRADING_HOUSE.cancelListingDialog.listingIndex = nil
                        return true --Suppress the showing of the dialog
                    end
                end
            end
        end)
        dialogOnShowHooked = true
    end
end

--[[
function FCOChangeStuff.tradingHouseDialogChanges(dialogType)
    local suppressDialog = FCOChangeStuff.settingsVars.settings.suppressDialog
    if dialogType == nil then
        for dialogTypeLoop, isEnabled in pairs(suppressDialog) do
            FCOChangeStuff.tradingHouseDialogChanges(dialogTypeLoop)
        end
    else
        if suppressDialog[dialogType] == true then
            if dialogType == "CONFIRM_TRADING_HOUSE_CANCEL_LISTING" then
                if not dialogHooksApplied[dialogType] then
-- -- [ [
                    ZO_PreHook(TRADING_HOUSE, "ShowCancelListingConfirmation", function(selTradingHouse, listingIndex)
d("[FCOCS]TRADING_HOUSE:ShowCancelListingConfirmation - listingIndex: " ..tostring(listingIndex))
                        --End the function which will try to show the dialog
                        if suppressDialog[dialogType] == true then return true end
                    end)
                    dialogHooksApplied[dialogType] = true
-- - - - --  --  ]  ]
                end
            end
        end
    end
end
]]

function FCOChangeStuff.dialogsChanges()
    --FCOChangeStuff.tradingHouseDialogChanges()
    loadDialogOnShowHook()
end