--this is Utils.lua. To use it, change the first line only, and add Utils.lua as the last entry on the manifest. You can then call the utils with [addonname].Utils.[function]()
local addon = FlobotsBlameGame or {}
addon.Utils = addon.Utils or {}
addon.Utils.addon = addon
local this = addon.Utils

-- Cache for computed fallback name
local cachedDisplayName = addon.DisplayName  -- may be nil

local function UnCamelCase(str)
    str = str:gsub("(%l)(%u)", "%1 %2")
    str = str:gsub("(%u)(%u%l)", "%1 %2")
    str = str:gsub("(%a)(%d)", "%1 %2")
    return str
end

function this.DisplayName()
	if cachedDisplayName then  return cachedDisplayName end

	cachedDisplayName = this.addon.Name or "NoNameDefined"
	cachedDisplayName = UnCamelCase(cachedDisplayName)
    
    return cachedDisplayName
end
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

----------------------------------------------------------------
--	Messsaging
----------------------------------------------------------------
function this.DebugMessage(message)
    if nn.accountWide.debugEnabled then
        d("|c4FC3F7" .. this.DisplayName() .. " (DEBUG):|r " .. message)
    end
end

function this.DebugMessage(message)   
    -- If the addon has no debugEnabled flag, warn the author once
    if this.addon.debugEnabled == nil then
        d(string.format(
            "|cFF5252%s Utils:|r debugEnabled flag is missing on addon '%s'. " ..
            "Add: %s.debugEnabled = true/false",
            this.addon.Name or "UnknownAddon",
            this.addon.Name or "UnknownAddon",
            this.addon.Name or "UnknownAddon"
        ))
        return
    end

    -- Normal debug behaviour
    if addon.debugEnabled then
        d("|c4FC3F7" .. this.DisplayName() .. " (DEBUG):|r " .. tostring(message))
    end
end

function this.UserMessage(message, alert)
	if (message) then d("|cFFFFFF" .. this.DisplayName() .. ": |r" .. message) end
	if (alert) then this.ShowAlertSmall("|cFFFFFF" .. alert .. "|r") end
end

function this.UserError(message, alert)	
    if (message) then d("|cFF5252" .. this.DisplayName() .. ": |r" .. message) end
	if (alert) then this.ShowAlertSmall("|cFF5252" .. alert .. "|r") end
end

function this.UserWarning(message, alert)
	if (message) then d("|cFFEB3B" .. this.DisplayName() .. ": |r" .. message) end
	if (alert) then this.ShowAlertSmall("|cFFEB3B" .. alert .. "|r") end
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
