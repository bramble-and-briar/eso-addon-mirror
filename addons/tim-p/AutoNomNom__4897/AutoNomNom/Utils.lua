--this is Utils.lua. To use it, change the first line only, and add Utils.lua as the last entry on the manifest. You can then call the utils with [addonname].Utils.[function]()
local addon = AutoNomNom or {}
addon.Utils = addon.Utils or {}
local this = addon.Utils

------------------------------------------------------------
--	Announcements
------------------------------------------------------------

local function ShowCSA(message, category)
    local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(
        category,
        SOUNDS.NONE
    )

    params:SetText(message)
    params:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_DISPLAY_ANNOUNCEMENT)
    params:MarkSuppressIconFrame()

    CENTER_SCREEN_ANNOUNCE:DisplayMessage(params)
end

function this.ShowAlertLarge(message)
    ShowCSA(message, CSA_CATEGORY_LARGE_TEXT)
end

function this.ShowAlertMedium(message)
    ShowCSA(message, CSA_CATEGORY_MAJOR_TEXT)
end

function this.ShowAlertSmall(message)
    ShowCSA(message, CSA_CATEGORY_SMALL_TEXT)
end

------------------------------------------------------------
--	Formatting
------------------------------------------------------------
function this.FormatTime(seconds)
    seconds = math.floor(seconds)

    if seconds < 60 then
        return seconds .. "s"
    end

    local minutes = math.floor(seconds / 60)
    local remaining = seconds % 60

    if remaining == 0 then
        return minutes .. "m"
    end

    return string.format("%dm %ds", minutes, remaining)
end
