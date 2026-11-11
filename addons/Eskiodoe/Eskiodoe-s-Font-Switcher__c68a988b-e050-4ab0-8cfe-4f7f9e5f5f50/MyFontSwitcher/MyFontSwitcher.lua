local ADDON_NAME = "MyFontSwitcher"

local FONTS = {
    { name = "Alagard",          path = "MyFontSwitcher/fonts/Alagard.slug" },
    { name = "American Cursive", path = "MyFontSwitcher/fonts/AmericanCursive.slug" },
    { name = "Gothic Pixel",     path = "MyFontSwitcher/fonts/GothicPixel.slug" },
    { name = "Pixel Love",       path = "MyFontSwitcher/fonts/PixelLove.slug" },
    { name = "Pokemon Classic",  path = "MyFontSwitcher/fonts/PokemonClassic.slug" },
    { name = "Rainy Hearts",     path = "MyFontSwitcher/fonts/RainyHearts.slug" },
    { name = "Venice Classic",   path = "MyFontSwitcher/fonts/VeniceClassic.slug" },
}

local STYLES = {
    { name = "Soft Shadow Thin",  value = "soft-shadow-thin" },
    { name = "Soft Shadow Thick", value = "soft-shadow-thick" },
    { name = "Shadow",            value = "shadow" },
    { name = "Outline",           value = "outline" },
    { name = "Thick Outline",     value = "thick-outline" },
    { name = "None",              value = "" },
}

local defaults = {
    selected = 1,
    size = 24,                  -- general UI
    style = 1,
    nameplateSize = 26,         -- floating player names
    overheadSize = 20,          -- the one that was previously called chatSize (overhead text)
    chatWindowSize = 20,        -- NEW: actual chat window
    nameplatesEnabled = true,
}

local savedVars

local function Log(msg)
    d("[Font Switcher] " .. tostring(msg))
end

local function GetCurrentFont()
    local index = tonumber(savedVars.selected) or 1
    if index < 1 or index > #FONTS then
        index = 1
        savedVars.selected = 1
    end
    return FONTS[index]
end

local function GetCurrentStyle()
    local index = tonumber(savedVars.style) or 1
    if index < 1 or index > #STYLES then
        index = 1
        savedVars.style = 1
    end
    return STYLES[index]
end

-- Apply only to the actual chat-window text buffers.
-- This deliberately does not touch chat window alpha, fading, or visibility.
local function ApplyChatWindowFont(chatWindowString)
    if not CHAT_SYSTEM or not CHAT_SYSTEM.containers then
        return 0
    end

    local changed = 0
    local iterator = zo_insecurePairs or pairs

    for _, container in iterator(CHAT_SYSTEM.containers) do
        if container.windows then
            for _, window in iterator(container.windows) do
                local buffer = window and window.buffer
                if buffer and buffer.SetFont then
                    local ok = pcall(function()
                        buffer:SetFont(chatWindowString)
                    end)
                    if ok then
                        changed = changed + 1
                    end
                end
            end
        end
    end

    return changed
end

local function ApplyFont()
    local font = GetCurrentFont()
    local style = GetCurrentStyle()

    local uiSize         = math.max(12, math.min(48, tonumber(savedVars.size) or 24))
    local nameplateSize  = math.max(12, math.min(48, tonumber(savedVars.nameplateSize) or 26))
    local overheadSize   = math.max(12, math.min(48, tonumber(savedVars.overheadSize) or 20))
    local chatWindowSize = math.max(12, math.min(48, tonumber(savedVars.chatWindowSize) or 20))

    savedVars.size = uiSize
    savedVars.nameplateSize = nameplateSize
    savedVars.overheadSize = overheadSize
    savedVars.chatWindowSize = chatWindowSize

    -- UI font string
    local fontString
    if style.value == "" then
        fontString = string.format("%s|%d", font.path, uiSize)
    else
        fontString = string.format("%s|%d|%s", font.path, uiSize, style.value)
    end

    local nameplateString = string.format("%s|%d", font.path, nameplateSize)

    -- Overhead text string (whatever the previous "chat" slider was controlling)
    local overheadString
    if style.value == "" then
        overheadString = string.format("%s|%d", font.path, overheadSize)
    else
        overheadString = string.format("%s|%d|%s", font.path, overheadSize, style.value)
    end

    -- Actual chat window string
    local chatWindowString
    if style.value == "" then
        chatWindowString = string.format("%s|%d", font.path, chatWindowSize)
    else
        chatWindowString = string.format("%s|%d|%s", font.path, chatWindowSize, style.value)
    end

    Log("=== APPLYING FONT ===")
    Log("Font: " .. font.name)
    Log(string.format("UI:%d | Nameplate:%d | Overhead:%d | Chat Window:%d", uiSize, nameplateSize, overheadSize, chatWindowSize))

    local changed = 0
    local iterator = zo_insecurePairs or pairs

    -- General UI. Chat font objects are handled separately below so their
    -- dedicated overhead-text size is not overwritten by the general UI pass.
    for key, value in iterator(_G) do
        if type(key) == "string"
            and key:find("^Zo")
            and key ~= "ZoFontChat"
            and key ~= "ZoFontEditChat"
            and type(value) == "userdata"
            and value.SetFont then
            local ok = pcall(function()
                value:SetFont(fontString)
            end)
            if ok then changed = changed + 1 end
        end
    end

    -- Nameplates
    if savedVars.nameplatesEnabled then
        if SetNameplateKeyboardFont then
            pcall(function() SetNameplateKeyboardFont(nameplateString, 1) end)
        end
        if SetNameplateGamepadFont then
            pcall(function() SetNameplateGamepadFont(nameplateString, 1) end)
        end
    end

    -- Overhead text (previous chat slider behavior)
    if ZoFontChat then pcall(function() ZoFontChat:SetFont(overheadString) end) end
    if ZoFontEditChat then pcall(function() ZoFontEditChat:SetFont(overheadString) end) end

    -- Actual chat window: change its text buffers only. Keep ZoFontChat and
    -- ZoFontEditChat dedicated to overhead text; do not alter fade/alpha behavior.
    local chatBuffersChanged = ApplyChatWindowFont(chatWindowString)
    Log("Chat window buffers changed: " .. chatBuffersChanged)

    Log("Fonts changed: " .. changed)
    Log("=====================")
end

local function CreateSettings()
    local library = LibHarvensAddonSettings
    if not library then
        Log("ERROR: LibHarvensAddonSettings not found")
        return
    end

    local panel = library:AddAddon("Font Switcher")
    if not panel then return end

    -- Font
    local fontItems = {}
    for i, f in ipairs(FONTS) do
        fontItems[#fontItems + 1] = { name = f.name, data = i }
    end

    panel:AddSetting({
        type = library.ST_DROPDOWN,
        label = "Select Font",
        items = fontItems,
        default = FONTS[1].name,
        getFunction = function() return GetCurrentFont().name end,
        setFunction = function(_, _, item)
            if item and item.data then savedVars.selected = item.data end
        end,
    })

    -- UI Size
    panel:AddSetting({
        type = library.ST_SLIDER,
        label = "UI Font Size",
        min = 12, max = 48, step = 1,
        default = 24,
        getFunction = function() return savedVars.size end,
        setFunction = function(v)
            savedVars.size = math.max(12, math.min(48, tonumber(v) or 24))
        end,
    })

    -- Nameplate Size
    panel:AddSetting({
        type = library.ST_SLIDER,
        label = "Nameplate Size",
        tooltip = "Floating player names",
        min = 12, max = 48, step = 1,
        default = 26,
        getFunction = function() return savedVars.nameplateSize end,
        setFunction = function(v)
            savedVars.nameplateSize = math.max(12, math.min(48, tonumber(v) or 26))
        end,
    })

    -- Overhead Size (the one you already relabeled)
    panel:AddSetting({
        type = library.ST_SLIDER,
        label = "Overhead Text Size",
        tooltip = "Overhead / floating text size",
        min = 12, max = 48, step = 1,
        default = 20,
        getFunction = function() return savedVars.overheadSize end,
        setFunction = function(v)
            savedVars.overheadSize = math.max(12, math.min(48, tonumber(v) or 20))
        end,
    })

    -- Style
    local styleItems = {}
    for i, s in ipairs(STYLES) do
        styleItems[#styleItems + 1] = { name = s.name, data = i }
    end

    panel:AddSetting({
        type = library.ST_DROPDOWN,
        label = "Font Style",
        items = styleItems,
        default = STYLES[1].name,
        getFunction = function() return GetCurrentStyle().name end,
        setFunction = function(_, _, item)
            if item and item.data then savedVars.style = item.data end
        end,
    })

    -- Nameplates toggle
    panel:AddSetting({
        type = library.ST_CHECKBOX,
        label = "Enable Nameplates",
        tooltip = "Turn custom nameplate fonts on or off",
        getFunction = function() return savedVars.nameplatesEnabled end,
        setFunction = function(value) savedVars.nameplatesEnabled = value end,
    })

    -- Apply
    panel:AddSetting({
        type = library.ST_BUTTON,
        label = "Apply Font",
        buttonText = "Apply Font",
        clickHandler = function() ApplyFont() end,
    })
end

local function OnAddonLoaded(_, name)
    if name ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    savedVars = ZO_SavedVars:NewAccountWide("MyFontSwitcherSavedVars", 1, nil, defaults)

    savedVars.selected        = tonumber(savedVars.selected) or 1
    savedVars.size            = math.max(12, math.min(48, tonumber(savedVars.size) or 24))
    savedVars.style           = tonumber(savedVars.style) or 1
    savedVars.nameplateSize   = math.max(12, math.min(48, tonumber(savedVars.nameplateSize) or 26))
    savedVars.overheadSize    = math.max(12, math.min(48, tonumber(savedVars.overheadSize) or 20))
    savedVars.chatWindowSize  = math.max(12, math.min(48, tonumber(savedVars.chatWindowSize) or 20))
    if savedVars.nameplatesEnabled == nil then savedVars.nameplatesEnabled = true end

    CreateSettings()

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, function()
        zo_callLater(ApplyFont, 1500)
    end)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)