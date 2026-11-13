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
    menuFont = 1,
    chatFont = 1,
    bookFont = 1,
    tooltipFont = 1,
    overheadFont = 1,
    bookStyleEnabled = true,
    size = 24,
    style = 1,
    menuEnabled = true,
    overheadEnabled = true,
    tooltipFontsEnabled = true,
    bookFontsEnabled = true,
    menuSize = 24,
    overheadSize = 26,
    bookSize = 24,
    suppressLog = true,
}

local savedVars
local bookApiHookInstalled = false
local popupMessageHookInstalled = false
local popupFontSizeHookInstalled = false
local popupWindowHookInstalled = false
local loreLifecycleHooksInstalled = false

local original = {
    nameplateKeyboard = nil,
    nameplateGamepad  = nil,
}
local managedFontOriginals = {}
local tooltipStyleOriginals = {}
local tooltipStyleSeen = {}

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

local function GetAreaFont(area)
    local keys = {
        menu = "menuFont",
        chat = "chatFont",
        book = "bookFont",
        tooltip = "tooltipFont",
        overhead = "overheadFont",
    }
    local key = keys[area]
    local index = key and tonumber(savedVars[key]) or tonumber(savedVars.selected) or 1
    if not index or index < 1 or index > #FONTS then
        index = 1
        if key then savedVars[key] = 1 end
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

    local newString = finalStyle == "" 
        and string.format("%s|%d", newFace, finalSize)
        or string.format("%s|%d|%s", newFace, finalSize, finalStyle)

    return pcall(function() obj:SetFont(newString) end)
end

local function SetManagedFont(obj, area, enabled, face, size, style)
    if not obj or not obj.SetFont or not obj.GetFontInfo then return false end
    if not managedFontOriginals[obj] then
        local ok, originalFace, originalSize, originalStyle = pcall(function() return obj:GetFontInfo() end)
        if ok and originalFace then
            managedFontOriginals[obj] = {
                area = area,
                descriptor = MakeFontString(originalFace, originalSize or 18, originalStyle or ""),
            }
        end
    end
    local saved = managedFontOriginals[obj]
    if saved and saved.area ~= area then return false end
    if enabled then
        return ReplaceFontFace(obj, face, size, style)
    elseif saved then
        local ok = pcall(function() obj:SetFont(saved.descriptor) end)
        if ok then managedFontOriginals[obj] = nil end
        return ok
    end
    return false
end

local function RestoreManagedArea(area)
    for obj, saved in pairs(managedFontOriginals) do
        if saved.area == area and obj and obj.SetFont then
            pcall(function() obj:SetFont(saved.descriptor) end)
            managedFontOriginals[obj] = nil
        end
    end
end

-------------------------------------------------
-- WORKING CORE
-------------------------------------------------
local function ApplyCoreFonts()
    local style = GetCurrentStyle()
    local face = GetAreaFont("menu").path
    local overheadFace = GetAreaFont("overhead").path
    local styleValue = style.value

    local menuSize = math.max(12, math.min(48, tonumber(savedVars.menuSize) or savedVars.size or 24))
    local overheadSize = math.max(12, math.min(48, tonumber(savedVars.overheadSize) or 26))
    savedVars.menuSize, savedVars.overheadSize = menuSize, overheadSize

    -- General UI fonts only. Specialized text areas are deliberately excluded
    -- so their individual toggles and size sliders remain independent.
    local excluded = {
        ZoFontChat = true, ZoFontEditChat = true,
        ZoFontBookPaper = true, ZoFontBookPaperTitle = true,
        ZoFontBookLetter = true, ZoFontBookLetterTitle = true,
        ZoFontBookNote = true, ZoFontBookNoteTitle = true,
        ZoFontBookScroll = true, ZoFontBookScrollTitle = true,
        ZoFontBookTablet = true, ZoFontBookTabletTitle = true,
        ZoFontBookSkin = true, ZoFontBookSkinTitle = true,
        ZoFontBookRubbing = true, ZoFontBookRubbingTitle = true,
        ZoFontTooltip = true, ZoFontTooltipTitle = true, ZoFontTooltipSubtitle = true,
        ZoFontGamepadTooltip = true, ZoFontGamepadTooltipTitle = true,
        ZoFontGamepadTooltipSubtitle = true,
    }

    local changed = 0
    if savedVars.menuEnabled then
        local iterator = zo_insecurePairs or pairs
        for key, value in iterator(_G) do
            if type(key) == "string" and key:find("^Zo") and not excluded[key]
                and not key:find("Book") and not key:find("Tooltip")
                and not key:find("Interaction") and not key:find("Dialogue")
                and not key:find("Dialog") and type(value) == "userdata" then
                if SetManagedFont(value, "menu", true, face, menuSize, styleValue) then
                    changed = changed + 1
                end
            end
        end
    else
        RestoreManagedArea("menu")
    end


    -- Overhead labels/nameplates use the game's dedicated font APIs.
    local overheadString = MakeFontString(overheadFace, overheadSize, styleValue)
    if savedVars.overheadEnabled then
        if SetNameplateKeyboardFont then pcall(function() SetNameplateKeyboardFont(overheadString, 1) end) end
        if SetNameplateGamepadFont then pcall(function() SetNameplateGamepadFont(overheadString, 1) end) end
    else
        if original.nameplateKeyboard and SetNameplateKeyboardFont then
            pcall(function() SetNameplateKeyboardFont(original.nameplateKeyboard, 1) end)
        end
        if original.nameplateGamepad and SetNameplateGamepadFont then
            pcall(function() SetNameplateGamepadFont(original.nameplateGamepad, 1) end)
        end
    end

    return face, menuSize, styleValue, changed
end

-------------------------------------------------
-- EXTENDED UI INTEGRATIONS
-------------------------------------------------

local function GetFontStyleEnum(styleValue)
    if styleValue == nil or styleValue == "" then
        return FONT_STYLE_NORMAL or 0
    end
    if GetFontStyleString and FONT_STYLE_ITERATION_BEGIN and FONT_STYLE_ITERATION_END then
        for styleId = FONT_STYLE_ITERATION_BEGIN, FONT_STYLE_ITERATION_END do
            if GetFontStyleString(styleId) == styleValue then return styleId end
        end
    end
    return FONT_STYLE_NORMAL or 0
end

local function ApplyToFontObject(name, area, enabled, face, size, style)
    local obj = _G[name]
    if not obj or not obj.SetFont then return false end
    return SetManagedFont(obj, area, enabled, face, size, style)
end

-- Update 48+ book rendering obtains its font data from this API rather
-- than relying solely on the older ZO_LoreReader font globals.
local function InstallBookFontIntegration()
    if bookApiHookInstalled or type(GetBookMediumFontInfo) ~= "function" then
        return
    end

    local originalGetBookMediumFontInfo = GetBookMediumFontInfo
    _G.GetBookMediumFontInfo = function(mediumId, isGamepad, ...)
        local values = { originalGetBookMediumFontInfo(mediumId, isGamepad, ...) }

        if savedVars and savedVars.bookFontsEnabled then
            local face = GetAreaFont("book").path
            local size = math.max(12, math.min(48, tonumber(savedVars.bookSize) or savedVars.size or 24))
            local styleValue = savedVars.bookStyleEnabled and GetCurrentStyle().value or ""
            local style = GetFontStyleEnum(styleValue)

            -- API return positions: title face/size/style = 1/2/3,
            -- body face/size/style = 4/5/6. Keep all color/style returns intact.
            values[1] = face
            values[2] = size
            values[3] = style
            values[4] = face
            values[5] = size
            values[6] = style
        end

        return unpack(values)
    end

    bookApiHookInstalled = true
    Log("Book font API integration installed")
end

local function InstallLoreLifecycleHooks()
    if loreLifecycleHooksInstalled then return end

    if LORE_READER then
        if ZO_PreHook then
            ZO_PreHook(LORE_READER, "Show", function()
                -- The book API is queried while the reader opens. The API
                -- wrapper checks the saved setting at the moment of query.
                InstallBookFontIntegration()
            end)
        end
    end

    loreLifecycleHooksInstalled = true
end


local function ApplyBookFontObjects(face, size, style)
    local names = {
        "ZoFontBookPaper", "ZoFontBookPaperTitle",
        "ZoFontBookLetter", "ZoFontBookLetterTitle",
        "ZoFontBookNote", "ZoFontBookNoteTitle",
        "ZoFontBookScroll", "ZoFontBookScrollTitle",
        "ZoFontBookTablet", "ZoFontBookTabletTitle",
        "ZoFontBookSkin", "ZoFontBookSkinTitle",
        "ZoFontBookRubbing", "ZoFontBookRubbingTitle",
        "ZoFontGamepadBookPaper", "ZoFontGamepadBookPaperTitle",
        "ZoFontGamepadBookLetter", "ZoFontGamepadBookLetterTitle",
        "ZoFontGamepadBookNote", "ZoFontGamepadBookNoteTitle",
        "ZoFontGamepadBookScroll", "ZoFontGamepadBookScrollTitle",
        "ZoFontGamepadBookTablet", "ZoFontGamepadBookTabletTitle",
        "ZoFontGamepadBookSkin", "ZoFontGamepadBookSkinTitle",
        "ZoFontGamepadBookRubbing", "ZoFontGamepadBookRubbingTitle",
    }

    local count = 0
    for _, name in ipairs(names) do
        if ApplyToFontObject(name, "book", savedVars.bookFontsEnabled, face, size, style) then count = count + 1 end
    end
    return count
end

local function ApplyTooltipStyles(face)
    local names = {
        "ZO_TOOLTIP_STYLES", "ZO_CRAFTING_TOOLTIP_STYLES",
        "ZO_GAMEPAD_DYEING_TOOLTIP_STYLES", "ZO_GAMEPAD_TOOLTIP_STYLES",
        "ZO_TOOLTIP_STYLES_KEYBOARD",
    }
    local changed, seen = 0, {}
    local function Walk(tbl, depth)
        if type(tbl) ~= "table" or depth > 5 or seen[tbl] then return end
        seen[tbl] = true
        for key, value in pairs(tbl) do
            if type(value) == "table" then
                Walk(value, depth + 1)
            elseif (key == "fontFace" or key == "font") and type(value) == "string" then
                if savedVars.tooltipFontsEnabled then
                    local identity = tostring(tbl) .. ":" .. tostring(key)
                    if not tooltipStyleSeen[identity] then
                        tooltipStyleOriginals[#tooltipStyleOriginals + 1] = { tbl = tbl, key = key, value = value }
                        tooltipStyleSeen[identity] = true
                    end
                    tbl[key] = face
                    changed = changed + 1
                end
            end
        end
    end
    if savedVars.tooltipFontsEnabled then
        for _, name in ipairs(names) do Walk(_G[name], 0) end
    else
        for _, saved in ipairs(tooltipStyleOriginals) do
            if saved.tbl then saved.tbl[saved.key] = saved.value end
        end
        tooltipStyleOriginals = {}
        tooltipStyleSeen = {}
    end
    return changed
end


-------------------------------------------------
-- FADING CHAT OUTPUT
-------------------------------------------------

local function ApplyPopupBuffer(window)
    if not window then return false end

    local ok, buffer = pcall(function() return window.buffer end)
    if not ok or not buffer or not buffer.SetFont then return false end

    local size = tonumber(window.fontSize) or 20
    local style = ""

    if buffer.GetFontInfo then
        local got, _, currentSize, currentStyle = pcall(function()
            return buffer:GetFontInfo()
        end)
        if got then
            size = tonumber(currentSize) or size
            style = currentStyle or ""
        end
    end

    local descriptor = MakeFontString(GetAreaFont("chat").path, size, style)
    return pcall(function() buffer:SetFont(descriptor) end)
end

local function ForEachChatContainer(callback)
    if not CHAT_SYSTEM then return end

    local seen = {}
    local function Visit(container)
        if container and not seen[container] then
            seen[container] = true
            callback(container)
        end
    end

    pcall(function() Visit(CHAT_SYSTEM.primaryContainer) end)
    pcall(function()
        local containers = CHAT_SYSTEM.containers
        if type(containers) == "table" then
            local iterator = zo_insecurePairs or pairs
            for _, container in iterator(containers) do
                Visit(container)
            end
        end
    end)
end

local function ApplyPopupChatBuffers()
    local changed, found = 0, 0

    ForEachChatContainer(function(container)
        local ok, windows = pcall(function() return container.windows end)
        if ok and type(windows) == "table" then
            local iterator = zo_insecurePairs or pairs
            for _, window in iterator(windows) do
                if window and window.buffer then
                    found = found + 1
                    if ApplyPopupBuffer(window) then
                        changed = changed + 1
                    end
                end
            end
        end
    end)

    return changed, found
end

local function InstallPopupChatHooks()
    if not SharedChatContainer then return end

    -- Apply before every new chat line is appended to the fading output buffer.
    if not popupMessageHookInstalled and ZO_PreHook
        and SharedChatContainer.AddMessageToWindow then
        ZO_PreHook(SharedChatContainer, "AddMessageToWindow",
            function(container, window)
                ApplyPopupBuffer(window)
            end)
        popupMessageHookInstalled = true
    end

    -- ESO assigns the normal chat size/font during tab setup and refresh.
    if not popupFontSizeHookInstalled and ZO_PostHook
        and SharedChatContainer.SetFontSize then
        ZO_PostHook(SharedChatContainer, "SetFontSize",
            function(container, tabIndex)
                local window = container and container.windows and container.windows[tabIndex]
                ApplyPopupBuffer(window)
            end)
        popupFontSizeHookInstalled = true
    end

    -- Cover newly-created or detached chat windows.
    if not popupWindowHookInstalled and ZO_PostHook
        and SharedChatContainer.AddRawWindow then
        ZO_PostHook(SharedChatContainer, "AddRawWindow",
            function(container, window)
                ApplyPopupBuffer(window)
            end)
        popupWindowHookInstalled = true
    end
end

local function ApplySpecializedFonts(face, uiSize, styleValue)
    -- Floating combat text is part of the overhead text category.
    if savedVars.overheadEnabled then
        local overheadString = MakeFontString(GetAreaFont("overhead").path, math.max(12, math.min(48, tonumber(savedVars.overheadSize) or 26)), styleValue)
        if SetSCTKeyboardFont then pcall(function() SetSCTKeyboardFont(overheadString, 1) end) end
        if SetSCTGamepadFont then pcall(function() SetSCTGamepadFont(overheadString, 1) end) end
    end

    local booksChanged = 0
    if savedVars.bookFontsEnabled then
        local bookSize = math.max(12, math.min(48, tonumber(savedVars.bookSize) or 24))
        local bookStyle = savedVars.bookStyleEnabled and styleValue or ""
        booksChanged = ApplyBookFontObjects(GetAreaFont("book").path, bookSize, bookStyle)
        InstallBookFontIntegration()
        InstallLoreLifecycleHooks()
    else
        RestoreManagedArea("book")
    end

    local tooltipChanged = 0
    if savedVars.tooltipFontsEnabled then
        local tooltipSize = 24 -- Fixed size; the tooltip size slider has been removed.
        for _, name in ipairs({
            "ZoFontTooltip", "ZoFontTooltipTitle", "ZoFontTooltipSubtitle",
            "ZoFontGamepadTooltip", "ZoFontGamepadTooltipTitle",
            "ZoFontGamepadTooltipSubtitle",
        }) do
            if ApplyToFontObject(name, "tooltip", true, GetAreaFont("tooltip").path, tooltipSize, GetFontStyleEnum(styleValue)) then
                tooltipChanged = tooltipChanged + 1
            end
        end
        tooltipChanged = tooltipChanged + ApplyTooltipStyles(GetAreaFont("tooltip").path)
    else
        RestoreManagedArea("tooltip")
        ApplyTooltipStyles(face)
    end


    Log(string.format(
        "Applied areas: books=%d, tooltip entries=%d",
        booksChanged, tooltipChanged
    ))
end

local function ApplyFont()
    if not savedVars then return end
    Log("=== APPLYING FONT ===")
    InstallPopupChatHooks()
    local face, menuSize, styleValue, changed = ApplyCoreFonts()
    Log("Menu/UI fonts touched: " .. tostring(changed))

    local popupChanged, popupFound = ApplyPopupChatBuffers()
    Log(string.format(
        "Fading chat diagnostic: buffers found=%d, font assignments succeeded=%d, message hook=%s, size hook=%s, new-window hook=%s",
        popupFound, popupChanged,
        tostring(popupMessageHookInstalled),
        tostring(popupFontSizeHookInstalled),
        tostring(popupWindowHookInstalled)
    ))

    ApplySpecializedFonts(face, menuSize, styleValue)
    Log("=====================")
end

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

    local function AddFontDropdown(label, area, savedKey)
        local fontItems = {}
        for i, f in ipairs(FONTS) do
            fontItems[#fontItems + 1] = { name = f.name, data = i }
        end
        panel:AddSetting({
            type = library.ST_DROPDOWN,
            label = label .. " Font",
            items = fontItems,
            default = FONTS[1].name,
            getFunction = function() return FONTS[tonumber(savedVars[savedKey]) or 1].name end,
            setFunction = function(_, _, item)
                if item and item.data then savedVars[savedKey] = item.data; LiveApply() end
            end,
        })
    end

    AddFontDropdown("Menu", "menu", "menuFont")
    AddFontDropdown("Fading Chat", "chat", "chatFont")
    AddFontDropdown("Books", "book", "bookFont")
    AddFontDropdown("Tooltips", "tooltip", "tooltipFont")
    AddFontDropdown("Overhead Text", "overhead", "overheadFont")

    local styleItems = {}
    for i, style in ipairs(STYLES) do
        styleItems[#styleItems + 1] = { name = style.name, data = i }
    end
    panel:AddSetting({
        type = library.ST_DROPDOWN, label = "Font Style", items = styleItems,
        default = STYLES[1].name,
        getFunction = function() return GetCurrentStyle().name end,
        setFunction = function(_, _, item)
            if item and item.data then savedVars.style = item.data; LiveApply() end
        end,
    })

    local function AddTextArea(label, enabledKey, sizeKey, defaultSize)
        panel:AddSetting({
            type = library.ST_CHECKBOX,
            label = label .. " Font",
            getFunction = function() return savedVars[enabledKey] end,
            setFunction = function(value) savedVars[enabledKey] = value; LiveApply() end,
        })
        panel:AddSetting({
            type = library.ST_SLIDER,
            label = label .. " Font Size",
            min = 12, max = 48, step = 1, default = defaultSize,
            getFunction = function() return savedVars[sizeKey] end,
            setFunction = function(value)
                savedVars[sizeKey] = math.max(12, math.min(48, tonumber(value) or defaultSize))
                LiveApply()
            end,
        })
    end

    AddTextArea("Menu", "menuEnabled", "menuSize", 24)
    AddTextArea("Overhead Text", "overheadEnabled", "overheadSize", 26)
    panel:AddSetting({
        type = library.ST_CHECKBOX,
        label = "Tooltip Menu Font",
        getFunction = function() return savedVars.tooltipFontsEnabled end,
        setFunction = function(value) savedVars.tooltipFontsEnabled = value; LiveApply() end,
    })
    AddTextArea("Book", "bookFontsEnabled", "bookSize", 24)
    panel:AddSetting({
        type = library.ST_CHECKBOX,
        label = "Book Font Shadows and Outline",
        getFunction = function() return savedVars.bookStyleEnabled end,
        setFunction = function(value) savedVars.bookStyleEnabled = value; LiveApply() end,
    })

    panel:AddSetting({
        type = library.ST_CHECKBOX,
        label = "Suppress Addon Debug Log",
        default = true,
        getFunction = function() return savedVars.suppressLog end,
        setFunction = function(value) savedVars.suppressLog = value end,
    })
end

local function OnAddonLoaded(_, name)
    if name ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    savedVars = ZO_SavedVars:NewAccountWide("MyFontSwitcherSavedVars", 1, nil, defaults)

    savedVars.selected = tonumber(savedVars.selected) or 1
    savedVars.style = tonumber(savedVars.style) or 1
    for _, key in ipairs({"menuFont", "chatFont", "bookFont", "tooltipFont", "overheadFont"}) do
        savedVars[key] = tonumber(savedVars[key]) or savedVars.selected
        if savedVars[key] < 1 or savedVars[key] > #FONTS then savedVars[key] = 1 end
    end
    if savedVars.bookStyleEnabled == nil then savedVars.bookStyleEnabled = true end

    -- Migrate old settings without discarding the user's existing choices.
    if savedVars.menuEnabled == nil then savedVars.menuEnabled = true end
    if savedVars.overheadEnabled == nil then savedVars.overheadEnabled = true end
    if savedVars.tooltipFontsEnabled == nil then savedVars.tooltipFontsEnabled = true end
    if savedVars.bookFontsEnabled == nil then savedVars.bookFontsEnabled = true end

    savedVars.menuSize = math.max(12, math.min(48, tonumber(savedVars.menuSize) or tonumber(savedVars.size) or 24))
    savedVars.overheadSize = math.max(12, math.min(48, tonumber(savedVars.overheadSize) or tonumber(savedVars.nameplateSize) or 26))
    savedVars.bookSize = math.max(12, math.min(48, tonumber(savedVars.bookSize) or savedVars.menuSize))
    if savedVars.suppressLog == nil then savedVars.suppressLog = true end

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