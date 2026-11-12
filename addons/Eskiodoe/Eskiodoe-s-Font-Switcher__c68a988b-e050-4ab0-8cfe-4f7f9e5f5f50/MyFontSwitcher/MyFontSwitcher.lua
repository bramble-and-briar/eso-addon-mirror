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
    size = 24,
    style = 1,
    nameplateSize = 26,
    overheadSize = 20,
    nameplatesEnabled = true,
    suppressLog = true,
    experimentalMode = false,
}

local savedVars
local chatHooksInstalled = false
local loreHookInstalled = false
local experimentalFontString = nil
local forceTimerRunning = false

local original = {
    nameplateKeyboard = nil,
    nameplateGamepad  = nil,
}

local function Log(msg)
    if savedVars and savedVars.suppressLog then return end
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

local function MakeFontString(path, size, styleValue)
    if not styleValue or styleValue == "" then
        return string.format("%s|%d", path, size)
    end
    return string.format("%s|%d|%s", path, size, styleValue)
end

local function ReplaceFontFace(obj, newFace, forcedSize, forcedStyle)
    if not obj or not obj.GetFontInfo or not obj.SetFont then return false end

    local ok, face, size, style = pcall(function()
        return obj:GetFontInfo()
    end)
    if not ok then return false end

    local finalSize  = forcedSize or size or 18
    local finalStyle = forcedStyle
    if finalStyle == nil then finalStyle = style or "" end

    local newString
    if finalStyle == "" then
        newString = string.format("%s|%d", newFace, finalSize)
    else
        newString = string.format("%s|%d|%s", newFace, finalSize, finalStyle)
    end

    return pcall(function() obj:SetFont(newString) end)
end

-------------------------------------------------
-- WORKING CORE
-------------------------------------------------
local function ApplyFont()
    local font  = GetCurrentFont()
    local style = GetCurrentStyle()
    local newFace = font.path

    local uiSize        = math.max(12, math.min(48, tonumber(savedVars.size) or 24))
    local nameplateSize = math.max(12, math.min(48, tonumber(savedVars.nameplateSize) or 26))
    local overheadSize  = math.max(12, math.min(48, tonumber(savedVars.overheadSize) or 20))

    savedVars.size          = uiSize
    savedVars.nameplateSize = nameplateSize
    savedVars.overheadSize  = overheadSize

    local styleValue = style.value

    Log("=== APPLYING FONT ===")
    Log("Font: " .. font.name)

    local changed = 0
    local iterator = zo_insecurePairs or pairs

    for key, value in iterator(_G) do
        if type(key) == "string" and key:find("^Zo")
            and key ~= "ZoFontChat" and key ~= "ZoFontEditChat"
            and type(value) == "userdata" then
            if ReplaceFontFace(value, newFace, uiSize, styleValue) then
                changed = changed + 1
            end
        end
    end

    -- Nameplates
    local nameplateString = string.format("%s|%d", newFace, nameplateSize)
    if savedVars.nameplatesEnabled then
        if SetNameplateKeyboardFont then
            pcall(function() SetNameplateKeyboardFont(nameplateString, 1) end)
        end
        if SetNameplateGamepadFont then
            pcall(function() SetNameplateGamepadFont(nameplateString, 1) end)
        end
    else
        if original.nameplateKeyboard and SetNameplateKeyboardFont then
            pcall(function() SetNameplateKeyboardFont(original.nameplateKeyboard, 1) end)
        end
        if original.nameplateGamepad and SetNameplateGamepadFont then
            pcall(function() SetNameplateGamepadFont(original.nameplateGamepad, 1) end)
        end
    end

    -- Overhead
    local overheadString = MakeFontString(newFace, overheadSize, styleValue)
    if ZoFontChat then pcall(function() ZoFontChat:SetFont(overheadString) end) end
    if ZoFontEditChat then pcall(function() ZoFontEditChat:SetFont(overheadString) end) end

    Log("UI fonts touched: " .. changed)

    if savedVars.experimentalMode then
        Experimental_StartPersistentForce(newFace, uiSize, styleValue)
    end

    Log("=====================")
end

-------------------------------------------------
-- EXPERIMENTAL - PERSISTENT FORCE
-------------------------------------------------
local function Experimental_ApplyOnce(newFace, uiSize, styleValue)
    experimentalFontString = MakeFontString(newFace, uiSize, styleValue)

    -- Chat fonts
    if ZoFontChat then pcall(function() ZoFontChat:SetFont(experimentalFontString) end) end
    if ZoFontEditChat then pcall(function() ZoFontEditChat:SetFont(experimentalFontString) end) end

    -- Override the function that builds chat font strings
    if SharedChatContainer then
        if SharedChatContainer.GetChatFontFormatString then
            SharedChatContainer.GetChatFontFormatString = function(self, fontSize)
                return experimentalFontString
            end
        end

        if not chatHooksInstalled and SharedChatContainer.SetFontSize then
            local original = SharedChatContainer.SetFontSize
            SharedChatContainer.SetFontSize = function(container, tabIndex, fontSize, ...)
                original(container, tabIndex, fontSize, ...)
                local window = container and container.windows and container.windows[tabIndex]
                if window and window.buffer and window.buffer.SetFont then
                    pcall(function() window.buffer:SetFont(experimentalFontString) end)
                end
            end
            chatHooksInstalled = true
        end
    end

    -- Force all chat buffers
    if CHAT_SYSTEM then
        local function ForceBuffers(container)
            if not container or not container.windows then return end
            for _, window in pairs(container.windows) do
                if window and window.buffer and window.buffer.SetFont then
                    pcall(function() window.buffer:SetFont(experimentalFontString) end)
                end
            end
        end
        ForceBuffers(CHAT_SYSTEM.primaryContainer)
        if CHAT_SYSTEM.containers then
            for _, container in pairs(CHAT_SYSTEM.containers) do
                ForceBuffers(container)
            end
        end
    end

    -- SCT
    if SetSCTKeyboardFont then pcall(function() SetSCTKeyboardFont(experimentalFontString, 1) end) end
    if SetSCTGamepadFont then pcall(function() SetSCTGamepadFont(experimentalFontString, 1) end) end

    -- Books
    local bookFonts = {
        "ZoFontBookPaper", "ZoFontBookPaperTitle",
        "ZoFontBookLetter", "ZoFontBookLetterTitle",
        "ZoFontBookNote", "ZoFontBookNoteTitle",
        "ZoFontBookScroll", "ZoFontBookScrollTitle",
        "ZoFontBookTablet", "ZoFontBookTabletTitle",
        "ZoFontBookSkin", "ZoFontBookSkinTitle",
        "ZoFontBookRubbing", "ZoFontBookRubbingTitle",
    }
    for _, name in ipairs(bookFonts) do
        local obj = _G[name]
        if obj and obj.SetFont then
            pcall(function() obj:SetFont(experimentalFontString) end)
        end
    end

    if LORE_READER and not loreHookInstalled then
        ZO_PostHook(LORE_READER, "ApplyMedium", function()
            if not savedVars.experimentalMode then return end
            for _, name in ipairs(bookFonts) do
                local obj = _G[name]
                if obj and obj.SetFont then
                    pcall(function() obj:SetFont(experimentalFontString) end)
                end
            end
        end)
        loreHookInstalled = true
    end

    -- Tooltips
    for _, name in ipairs({"ZoFontTooltip", "ZoFontTooltipTitle", "ZoFontTooltipSubtitle"}) do
        local obj = _G[name]
        if obj then ReplaceFontFace(obj, newFace, uiSize, styleValue) end
    end
end

function Experimental_StartPersistentForce(newFace, uiSize, styleValue)
    if forceTimerRunning then return end
    forceTimerRunning = true

    Log("Experimental: Starting Persistent Force (4 seconds)...")

    local count = 0
    local maxCount = 12          -- 12 times
    local interval = 350         -- every 350ms ≈ 4 seconds total

    local function Tick()
        if not savedVars.experimentalMode then
            forceTimerRunning = false
            return
        end

        Experimental_ApplyOnce(newFace, uiSize, styleValue)
        count = count + 1

        if count < maxCount then
            zo_callLater(Tick, interval)
        else
            forceTimerRunning = false
            Log("Experimental: Persistent Force finished")
        end
    end

    Tick() -- run immediately, then continue
end
-------------------------------------------------
-- END EXPERIMENTAL
-------------------------------------------------

local function LiveApply()
    ApplyFont()
end

local function CreateSettings()
    local library = LibHarvensAddonSettings
    if not library then
        Log("ERROR: LibHarvensAddonSettings not found")
        return
    end

    local panel = library:AddAddon("Font Switcher")
    if not panel then return end

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
            if item and item.data then
                savedVars.selected = item.data
                LiveApply()
            end
        end,
    })

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
            if item and item.data then
                savedVars.style = item.data
                LiveApply()
            end
        end,
    })

    panel:AddSetting({
        type = library.ST_SLIDER,
        label = "UI Font Size",
        min = 12, max = 48, step = 1, default = 24,
        getFunction = function() return savedVars.size end,
        setFunction = function(v)
            savedVars.size = math.max(12, math.min(48, tonumber(v) or 24))
            LiveApply()
        end,
    })

    panel:AddSetting({
        type = library.ST_CHECKBOX,
        label = "Enable Nameplates",
        getFunction = function() return savedVars.nameplatesEnabled end,
        setFunction = function(v) savedVars.nameplatesEnabled = v LiveApply() end,
    })
    panel:AddSetting({
        type = library.ST_SLIDER,
        label = "Nameplate Size",
        min = 12, max = 48, step = 1, default = 26,
        getFunction = function() return savedVars.nameplateSize end,
        setFunction = function(v)
            savedVars.nameplateSize = math.max(12, math.min(48, tonumber(v) or 26))
            LiveApply()
        end,
    })

    panel:AddSetting({
        type = library.ST_SLIDER,
        label = "Overhead Text Size",
        min = 12, max = 48, step = 1, default = 20,
        getFunction = function() return savedVars.overheadSize end,
        setFunction = function(v)
            savedVars.overheadSize = math.max(12, math.min(48, tonumber(v) or 20))
            LiveApply()
        end,
    })

    panel:AddSetting({
        type = library.ST_CHECKBOX,
        label = "Suppress Chat Log",
        default = true,
        getFunction = function() return savedVars.suppressLog end,
        setFunction = function(v) savedVars.suppressLog = v end,
    })

    panel:AddSetting({
        type = library.ST_CHECKBOX,
        label = "Experimental Mode",
        tooltip = "Aggressively and repeatedly forces Chat, SCT, Books and Tooltips for several seconds. Turn off if unstable.",
        default = false,
        getFunction = function() return savedVars.experimentalMode end,
        setFunction = function(v)
            savedVars.experimentalMode = v
            LiveApply()
        end,
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

    if savedVars.nameplatesEnabled == nil then savedVars.nameplatesEnabled = true end
    if savedVars.suppressLog == nil then savedVars.suppressLog = true end
    if savedVars.experimentalMode == nil then savedVars.experimentalMode = false end

    if GetNameplateKeyboardFont then
        local f = GetNameplateKeyboardFont()
        if f then original.nameplateKeyboard = f end
    end
    if GetNameplateGamepadFont then
        local f = GetNameplateGamepadFont()
        if f then original.nameplateGamepad = f end
    end

    CreateSettings()

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, function()
        zo_callLater(ApplyFont, 1500)
    end)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)