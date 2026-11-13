-- SatchelExchangeSettingsActions.lua: Gamepad-friendly settings page via
-- LibHarvensAddonSettings (register with AddAddon + AddSetting; never call
-- CreateAddonSettingsPanel from an addon).

local SatchelExchangeSettingsActions = {}

---@return SatchelExchangeSavedVars
local function GetSettings()
    return SatchelExchange.state.savedVars
end

local AUTO_OPEN_ITEMS = {
    { name = "Off", data = "off" },
    { name = "Bound containers only", data = "bound" },
    { name = "All containers", data = "all" },
}

---@param mode string
---@return string
local function GetAutoOpenName(mode)
    for _, item in ipairs(AUTO_OPEN_ITEMS) do
        if item.data == mode then
            return item.name
        end
    end
    return AUTO_OPEN_ITEMS[1].name
end

function SatchelExchangeSettingsActions.Initialize()
    local LAS = _G["LibHarvensAddonSettings"]
    if not LAS or not LAS.AddAddon then
        SatchelExchange.Log("LibHarvensAddonSettings not available; settings page disabled")
        return
    end

    local panel = LAS:AddAddon("Satchel Exchange")
    panel.author = "clubwratt"
    panel.version = "v" .. tostring(SatchelExchange.version)

    panel:AddSetting({
        type = LAS.ST_CHECKBOX,
        label = "Enable Satchel Exchange",
        tooltip = "Master switch for buying and for opening containers. Turning this off also disarms any pending auto-exchange.",
        getFunction = function()
            return GetSettings().enabled
        end,
        setFunction = function(value)
            GetSettings().enabled = value
            if not value then
                SatchelExchange.StoreActions.Stop("disabled in settings")
            end
        end,
    })

    panel:AddSetting({
        type = LAS.ST_BUTTON,
        label = "Disarm Auto-Exchange",
        tooltip = "Cancel the pending Talk-to-buy loop without turning the addon off. It also disarms via the in-store keybind or after the resume window expires.",
        buttonText = "Disarm",
        clickHandler = function()
            SatchelExchange.StoreActions.Disarm()
        end,
    })

    panel:AddSetting({
        type = LAS.ST_CHECKBOX,
        label = "Auto-exit vendor after buying",
        tooltip = "Close the store and end the interaction as soon as the satchel is bought.",
        getFunction = function()
            return GetSettings().autoCloseStore
        end,
        setFunction = function(value)
            GetSettings().autoCloseStore = value
        end,
    })

    panel:AddSetting({
        type = LAS.ST_SLIDER,
        label = "Auto-resume window (minutes)",
        tooltip = "How long the armed auto-exchange survives between vendor visits.",
        min = 1,
        max = 15,
        step = 1,
        format = "%.0f",
        getFunction = function()
            return math.floor(GetSettings().resumeWindowMs / 60000)
        end,
        setFunction = function(value)
            local minutes = tonumber(value)
            if minutes then
                GetSettings().resumeWindowMs = minutes * 60000
            end
        end,
    })

    panel:AddSetting({
        type = LAS.ST_SECTION,
        label = "Containers",
    })

    panel:AddSetting({
        type = LAS.ST_DROPDOWN,
        label = "Open containers on arrival",
        tooltip = "Open a container the moment it reaches your backpack (loot, mail, rewards, purchases) and take all its contents. Bound only leaves tradeable containers unopened. Locked items and style pages are never opened. Set AutoLoot+'s own auto unbox to None, and turn off Lazy Writ Crafter's container opening to have writ boxes opened here.",
        items = AUTO_OPEN_ITEMS,
        getFunction = function()
            return GetAutoOpenName(GetSettings().autoOpenMode)
        end,
        setFunction = function(_, _, item)
            GetSettings().autoOpenMode = item.data
        end,
    })

    panel:AddSetting({
        type = LAS.ST_CHECKBOX,
        label = "Open transmute geodes",
        tooltip = "Count transmute geodes as containers, on arrival and for Open Containers. Leave off to keep a hoard of geodes unopened.",
        getFunction = function()
            return GetSettings().openGeodes
        end,
        setFunction = function(value)
            GetSettings().openGeodes = value
        end,
    })

    panel:AddSetting({
        type = LAS.ST_BUTTON,
        label = "Open all containers now",
        tooltip = "Close this menu and open every container in your backpack, one after another. The same action is the Open Containers entry on the LibRadialMenu wheel.",
        buttonText = "Open",
        clickHandler = function()
            SatchelExchange.UnboxActions.UnboxAll()
        end,
    })

    panel:AddSetting({
        type = LAS.ST_SECTION,
        label = "Vendor satchels",
    })

    panel:AddSetting({
        type = LAS.ST_CHECKBOX,
        label = "Unbox bought satchels",
        tooltip = "Open the satchel an Auto-Buy run bought right after leaving the vendor and take all its contents, whatever the arrival setting above says.",
        getFunction = function()
            return GetSettings().autoUnbox
        end,
        setFunction = function(value)
            GetSettings().autoUnbox = value
        end,
    })

    panel:AddSetting({
        type = LAS.ST_SLIDER,
        label = "Wait for a bought satchel (seconds)",
        tooltip = "Stop waiting for a bought satchel to reach the backpack this long after leaving the vendor. Raise it only if satchels take unusually long to arrive.",
        min = 2,
        max = 15,
        step = 1,
        format = "%.0f",
        getFunction = function()
            return math.floor(GetSettings().unboxTimeoutMs / 1000)
        end,
        setFunction = function(value)
            local seconds = tonumber(value)
            if seconds then
                GetSettings().unboxTimeoutMs = seconds * 1000
            end
        end,
    })
end

SatchelExchange.SettingsActions = SatchelExchangeSettingsActions
