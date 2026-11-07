
local ADDON_NAME = "MyFontSwitcher"

--------------------------------------------------
-- AVAILABLE FONTS
--------------------------------------------------

local FONTS = {
    { name = "Alagard", path = "MyFontSwitcher/fonts/Alagard.slug" },
    { name = "American Cursive", path = "MyFontSwitcher/fonts/AmericanCursive.slug" },
    { name = "Gothic Pixel", path = "MyFontSwitcher/fonts/GothicPixel.slug" },
    { name = "Pixel Love", path = "MyFontSwitcher/fonts/PixelLove.slug" },
    { name = "Pokemon Classic", path = "MyFontSwitcher/fonts/PokemonClassic.slug" },
    { name = "Rainy Hearts", path = "MyFontSwitcher/fonts/RainyHearts.slug" },
    { name = "Venice Classic", path = "MyFontSwitcher/fonts/VeniceClassic.slug" },
}

--------------------------------------------------
-- DEFAULT SETTINGS
--------------------------------------------------

local defaults = {
    selected = 1,
    size = 24,
}

local savedVars

-- Remember original font information so fonts
-- can be changed repeatedly without losing originals.
local originalFonts = {}

--------------------------------------------------
-- DEBUG
--------------------------------------------------

local function Log(message)
    d("[MyFontSwitcher] " .. tostring(message))
end

--------------------------------------------------
-- GET SELECTED FONT
--------------------------------------------------

local function GetCurrentFont()

    local index = tonumber(savedVars.selected) or 1

    if index < 1 or index > #FONTS then
        index = 1
        savedVars.selected = 1
    end

    return FONTS[index]
end

--------------------------------------------------
-- STANDARD ESO FONT PATHS
--------------------------------------------------

local STANDARD_FONTS = {
    ["EsoUI/Common/Fonts/Univers57.slug"] = true,
    ["EsoUI/Common/Fonts/Univers67.slug"] = true,
    ["EsoUI/Common/Fonts/Univers87.slug"] = true,

    ["$(MEDIUM_FONT)"] = true,
    ["$(BOLD_FONT)"] = true,

    ["EsoUI/Common/Fonts/FTN47.slug"] = true,
    ["EsoUI/Common/Fonts/FTN57.slug"] = true,
    ["EsoUI/Common/Fonts/FTN87.slug"] = true,

    ["$(GAMEPAD_LIGHT_FONT)"] = true,
    ["$(GAMEPAD_MEDIUM_FONT)"] = true,
    ["$(GAMEPAD_BOLD_FONT)"] = true,
}

--------------------------------------------------
-- APPLY UI FONTS
--------------------------------------------------

local function ApplyUIFont()

    local font = GetCurrentFont()

    local size = tonumber(savedVars.size) or defaults.size

    size = math.max(12, math.min(48, size))
    savedVars.size = size

    local fontString = string.format(
        "%s|%d|soft-shadow-thin",
        font.path,
        size
    )

    local changed = 0
    local failed = 0
    local matched = 0

    local processed = {}

    Log("Applying UI font: " .. font.name)
    Log("Font size: " .. size)

    --------------------------------------------------
    -- SCAN ESO GLOBAL FONT OBJECTS
    --------------------------------------------------

    for key, value in zo_insecurePairs(_G) do

        if type(key) == "string"
        and key:find("^Zo")
        and value
        and value.GetFontInfo
        and value.SetFont
        and not processed[value] then

            processed[value] = true

            local ok, result = pcall(function()

                local original = originalFonts[value]

                -- Save original font the first time
                -- this font object is encountered.

                if not original then

                    local info = {
                        value:GetFontInfo()
                    }

                    if STANDARD_FONTS[info[1]] then

                        original = {
                            path = info[1],
                            size = info[2],
                            style = info[3],
                        }

                        originalFonts[value] = original

                    end

                end

                -- Only replace recognized standard fonts
                -- or objects previously recorded by this addon.

                if original then

                    matched = matched + 1

                    value:SetFont(fontString)

                    return true

                end

                return false

            end)

            if ok and result then

                changed = changed + 1

            elseif not ok then

                failed = failed + 1

                Log("Font error: " .. key)
                Log(result)

            end

        end

    end

    Log("UI fonts matched: " .. matched)
    Log("UI fonts changed: " .. changed)
    Log("UI font errors: " .. failed)

    return changed

end

--------------------------------------------------
-- APPLY CHAT FONT
--------------------------------------------------

local function ApplyChatFont()

    local font = GetCurrentFont()

    if not ZoFontChat or not ZoFontEditChat then
        Log("Chat font objects are not available.")
        return
    end

    local chatSize = GetChatFontSize()

    local fontString = string.format(
        "%s|$(KB_%s)|soft-shadow-thin",
        font.path,
        chatSize
    )

    local ok, err = pcall(function()

        ZoFontChat:SetFont(fontString)
        ZoFontEditChat:SetFont(fontString)

        -- Refresh existing chat windows

        if CHAT_SYSTEM and CHAT_SYSTEM.containers then

            for _, container in pairs(CHAT_SYSTEM.containers) do

                if container.windows then

                    for _, window in ipairs(container.windows) do

                        if window.buffer then
                            window.buffer:SetFont(fontString)
                        end

                    end

                end

            end

        end

        if CHAT_SYSTEM then

            CHAT_SYSTEM:SetFontSize(
                CHAT_SYSTEM.GetFontSizeFromSetting()
            )

        end

    end)

    if ok then
        Log("Chat fonts applied.")
    else
        Log("Chat font error: " .. tostring(err))
    end

end

--------------------------------------------------
-- APPLY ALL FONTS
--------------------------------------------------

local function ApplyFont()

    Log("================================")
    Log("APPLY FONT BUTTON PRESSED")
    Log("================================")

    local ok, result = pcall(function()

        local changed = ApplyUIFont()

        ApplyChatFont()

        return changed

    end)

    if not ok then

        Log("APPLICATION ERROR:")
        Log(result)

        return

    end

    if result > 0 then

        Log("SUCCESS! Fonts changed: " .. result)

    else

        Log("WARNING: No matching font objects found.")

    end

    Log("================================")

end

--------------------------------------------------
-- CREATE XBOX SETTINGS MENU
--------------------------------------------------

local function CreateSettings()

    local library = LibHarvensAddonSettings

    if not library then

        Log("ERROR: LibHarvensAddonSettings not loaded.")

        return

    end

    --------------------------------------------------
    -- CREATE ADDON PANEL
    --------------------------------------------------

    local panel = library:AddAddon(
        "My Font Switcher"
    )

    if not panel then

        Log("ERROR: Could not create settings panel.")

        return

    end

    --------------------------------------------------
    -- FONT DROPDOWN
    --------------------------------------------------

    local fontItems = {}

    for index, font in ipairs(FONTS) do

        fontItems[#fontItems + 1] = {
            name = font.name,
            data = index,
        }

    end

    panel:AddSetting({

        type = library.ST_DROPDOWN,

        label = "Select Font",

        tooltip = "Choose the font you want to use.",

        items = fontItems,

        default = FONTS[1].name,

        getFunction = function()

            return GetCurrentFont().name

        end,

        setFunction = function(combobox, name, item)

            if not item then

                Log("Dropdown returned no selection.")

                return

            end

            local index = tonumber(item.data)

            if index and FONTS[index] then

                savedVars.selected = index

                Log("Selected font: " .. FONTS[index].name)

            end

        end,

    })

    --------------------------------------------------
    -- FONT SIZE SLIDER
    --------------------------------------------------

    panel:AddSetting({

        type = library.ST_SLIDER,

        label = "Font Size",

        tooltip = "Choose your preferred font size.",

        min = 12,

        max = 48,

        step = 1,

        default = defaults.size,

        getFunction = function()

            return savedVars.size

        end,

        setFunction = function(value)

            savedVars.size = math.max(
                12,
                math.min(48, tonumber(value) or defaults.size)
            )

            Log("Selected font size: " .. savedVars.size)

        end,

    })

    --------------------------------------------------
    -- APPLY FONT BUTTON
    --------------------------------------------------

    panel:AddSetting({

        type = library.ST_BUTTON,

        label = "Apply Font",

        buttonText = "Apply Font",

        tooltip = "Apply your selected font and size.",

        clickHandler = function(control, button)

            Log("APPLY BUTTON CLICKED!")

            ApplyFont()

        end,

    })

    Log("Xbox settings panel created.")

end

--------------------------------------------------
-- ADDON INITIALIZATION
--------------------------------------------------

local function OnAddonLoaded(event, addonName)

    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(
        ADDON_NAME,
        EVENT_ADD_ON_LOADED
    )

    --------------------------------------------------
    -- LOAD SAVED VARIABLES
    --------------------------------------------------

    savedVars = ZO_SavedVars:NewAccountWide(
        "MyFontSwitcherSavedVariables",
        1,
        nil,
        defaults
    )

    savedVars.selected = tonumber(savedVars.selected) or 1
    savedVars.size = tonumber(savedVars.size) or defaults.size

    if savedVars.selected < 1 or savedVars.selected > #FONTS then
        savedVars.selected = 1
    end

    savedVars.size = math.max(
        12,
        math.min(48, savedVars.size)
    )

    --------------------------------------------------
    -- CREATE SETTINGS
    --------------------------------------------------

    Log("My Font Switcher loading.")

    CreateSettings()

    -- IMPORTANT:
    -- Never apply fonts automatically.
    -- The player must press Apply Font.

    Log("Ready. Select a font and press Apply Font.")

end

--------------------------------------------------
-- REGISTER ADDON EVENT
--------------------------------------------------

EVENT_MANAGER:RegisterForEvent(
    ADDON_NAME,
    EVENT_ADD_ON_LOADED,
    OnAddonLoaded
)
