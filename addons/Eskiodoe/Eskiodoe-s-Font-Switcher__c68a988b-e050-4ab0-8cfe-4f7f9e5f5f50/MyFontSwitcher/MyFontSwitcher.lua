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
    menuFont = 0,
    chatFont = 0,
    bookFont = 0,
    tooltipFont = 0,
    combatFont = 0,
    dialogueFont = 0,
    bookStyleEnabled = true,
    style = 1,
    menuSize = 16,
    combatSize = 26,
    bookSize = 17,
    chatSize = 17,
    dialogueSize = 17,
    suppressLog = true,
    secretEmoteEnabled = false,
}

local savedVars
local bookApiHookInstalled = false
local popupMessageHookInstalled = false
local popupFontSizeHookInstalled = false
local popupWindowHookInstalled = false
local loreLifecycleHooksInstalled = false

local original = {
    nameplateKeyboard = nil,
    nameplateGamepad = nil,
}
local managedFontOriginals = {}
local tooltipStyleOriginals = {}
local tooltipStyleSeen = {}

local function Log(msg)
    if savedVars and savedVars.suppressLog then return end
    d("[Font Switcher] " .. tostring(msg))
end

local function GetCurrentStyle()
    local index = tonumber(savedVars.style) or 1
    if index < 1 or index > #STYLES then
        return STYLES[1]
    end
    return STYLES[index]
end

local function MakeFontString(path, size, styleValue)
    if not styleValue or styleValue == "" then
        return string.format("%s|%d", path, size)
    end
    return string.format("%s|%d|%s", path, size, styleValue)
end

local function GetAreaFont(area)
    local keys = {
        menu = "menuFont",
        chat = "chatFont",
        book = "bookFont",
        tooltip = "tooltipFont",
        combat = "combatFont",
        nameplate = "nameplateFont",
        dialogue = "dialogueFont",
    }
    local key = keys[area]
    if not key then return nil end
    local index = tonumber(savedVars[key])
    if index == nil or index == 0 then return nil end
    if index < 1 or index > #FONTS then return nil end
    return FONTS[index]
end

local function IsAreaEnabled(area)
    return GetAreaFont(area) ~= nil
end

local function IsDialogueRelatedKey(key)
    if type(key) ~= "string" then return false end
    return key:find("Conversation")
        or key:find("Dialogue")
        or key:find("Dialog")
        or key:find("Interaction")
        or key:find("Subtitle")
        or key:find("Announce")
        or key:find("Callout")
        or key:find("Chatter")
end

local function ReplaceFontFace(obj, newFace, forcedSize, forcedStyle)
    if not obj or not obj.GetFontInfo or not obj.SetFont then return false end
    local ok, face, size, style = pcall(function() return obj:GetFontInfo() end)
    if not ok then return false end
    local finalSize = forcedSize or size or 18
    local finalStyle = forcedStyle
    if finalStyle == nil then finalStyle = style or "" end
    if type(finalStyle) ~= "string" then finalStyle = "" end
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
    else
        managedFontOriginals[obj].area = area
    end
    if enabled then
        return ReplaceFontFace(obj, face, size, style)
    end
    local saved = managedFontOriginals[obj]
    if saved then
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

local function ApplyDescriptorToControlTree(control, descriptor, depth)
    if not control or depth > 12 then return end
    if control.SetFont then
        pcall(function() control:SetFont(descriptor) end)
    end
    local ok, count = pcall(function() return control:GetNumChildren() end)
    if ok and count then
        for i = 1, count do
            local child = control:GetChild(i)
            if child then
                ApplyDescriptorToControlTree(child, descriptor, depth + 1)
            end
        end
    end
end

local dialogueFontCache = {}
local dialogueFontCacheSet = {}
local dialogueFontCacheValid = false

local function AddDialogueFontToCache(control)
    local controlType = type(control)
    if not control or (controlType ~= "userdata" and controlType ~= "table") or not control.SetFont then return end
    if dialogueFontCacheSet[control] then return end
    dialogueFontCacheSet[control] = true
    dialogueFontCache[#dialogueFontCache + 1] = control
end

local function ReapplyDialogueFonts(forceGlobalScan)
    if not savedVars then return end

    local dialogueFont = GetAreaFont("dialogue")
    local styleValue = GetCurrentStyle().value
    local dialogueSize = math.max(12, math.min(48, tonumber(savedVars.dialogueSize) or 17))
    savedVars.dialogueSize = dialogueSize

    local changed = 0

    if not dialogueFont then
        RestoreManagedArea("dialogue")
        Log("Dialogue fonts touched: 0")
        return
    end

    local descriptor = MakeFontString(dialogueFont.path, dialogueSize, styleValue)

    if forceGlobalScan or not dialogueFontCacheValid then
        dialogueFontCache = {}
        dialogueFontCacheSet = {}
        local iterator = zo_insecurePairs or pairs
        for key, value in iterator(_G) do
            if IsDialogueRelatedKey(key) then
                AddDialogueFontToCache(value)
            end
        end
        dialogueFontCacheValid = true
    end

    for i = 1, #dialogueFontCache do
        local control = dialogueFontCache[i]
        if control and control.SetFont then
            if pcall(function() control:SetFont(descriptor) end) then
                changed = changed + 1
            end
        end
    end

    local function TrySet(control)
        if control and control.SetFont then
            AddDialogueFontToCache(control)
            if pcall(function() control:SetFont(descriptor) end) then
                changed = changed + 1
            end
        end
    end

    local interact = nil
    if SYSTEMS then
        if SYSTEMS.GetObject then
            interact = SYSTEMS:GetObject("interact")
        end
        if not interact and SYSTEMS.GetObjectBasedOnCurrentScene then
            interact = SYSTEMS:GetObjectBasedOnCurrentScene("interact")
        end
    end

    if interact then
        TrySet(interact.titleControl)
        TrySet(interact.textControl)
        if interact.control then
            TrySet(interact.control:GetNamedChild("TargetAreaTitle"))
            TrySet(interact.control:GetNamedChild("TargetAreaBodyText"))
            TrySet(interact.control:GetNamedChild("Title"))
            local content = interact.contentContainerControl
            if not content then
                content = interact.control:GetNamedChild("ContentContainer")
            end
            if content then
                TrySet(content:GetNamedChild("Text"))
            end
        end
    end

    for _, rootName in ipairs({
        "ZO_InteractWindow",
        "ZO_GamepadInteractTopLevel",
        "ZO_InteractWindow_Gamepad",
    }) do
        local root = _G[rootName]
        if root then
            TrySet(root:GetNamedChild("TargetAreaTitle"))
            TrySet(root:GetNamedChild("TargetAreaBodyText"))
            TrySet(root:GetNamedChild("Title"))
        end
    end

    Log("Dialogue fonts touched: " .. tostring(changed))
end

local dialogueInteractHooksInstalled = false
local dialogueHookTargets = {}
local dialogueReapplyPending = false
local dialogueLastImmediateAt = -1

local function ScheduleDialogueFontReapply(delay, forceGlobalScan)
    if dialogueReapplyPending then return end
    dialogueReapplyPending = true

    zo_callLater(function()
        dialogueReapplyPending = false
        ReapplyDialogueFonts(forceGlobalScan)
    end, delay or 100)
end

local function ApplyDialogueFontsImmediately(forceGlobalScan)
    local now = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or -1
    if now == dialogueLastImmediateAt then return end
    dialogueLastImmediateAt = now
    ReapplyDialogueFonts(forceGlobalScan)
end

local function HookDialogueMethod(target, methodName, callback)
    if not target then return false end
    if type(target[methodName]) ~= "function" then return false end

    local hooked = dialogueHookTargets[target]
    if not hooked then
        hooked = {}
        dialogueHookTargets[target] = hooked
    end
    if hooked[methodName] then return true end

    if not ZO_PostHook then return false end
    ZO_PostHook(target, methodName, callback)
    hooked[methodName] = true
    return true
end

local function InstallDialogueInteractHooks()
    local interact
    if SYSTEMS then
        if SYSTEMS.GetObject then
            interact = SYSTEMS:GetObject("interact")
        end
        if not interact and SYSTEMS.GetObjectBasedOnCurrentScene then
            interact = SYSTEMS:GetObjectBasedOnCurrentScene("interact")
        end
    end

    if not interact then return end

    HookDialogueMethod(interact, "ResetInteraction", function()
        ApplyDialogueFontsImmediately(false)
    end)
    HookDialogueMethod(interact, "InitializeInteractWindow", function()
        ApplyDialogueFontsImmediately(true)
    end)
    HookDialogueMethod(interact, "HandleChatterOptionClicked", function()
        ScheduleDialogueFontReapply(0)
    end)
    HookDialogueMethod(interact, "PopulateChatterOption", function()
        ScheduleDialogueFontReapply(0)
    end)
    HookDialogueMethod(interact, "FinalizeChatterOptions", function()
        ScheduleDialogueFontReapply(0)
    end)
    HookDialogueMethod(interact, "UpdateChatterOptions", function()
        ScheduleDialogueFontReapply(0)
    end)

    dialogueInteractHooksInstalled = true
end

local function ApplyCoreFonts()
    local styleValue = GetCurrentStyle().value
    local menuFont = GetAreaFont("menu")
    local nameplateFont = GetAreaFont("nameplate")

    local menuSize = math.max(12, math.min(48, tonumber(savedVars.menuSize) or 16))
    local nameplateSize = math.max(12, math.min(48, tonumber(savedVars.nameplateSize) or 26))
    savedVars.menuSize = menuSize
    savedVars.nameplateSize = nameplateSize

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
    if menuFont then
        local face = menuFont.path
        local iterator = zo_insecurePairs or pairs
        for key, value in iterator(_G) do
            if type(key) == "string" and key:find("^Zo") and not excluded[key]
                and not key:find("Book") and not key:find("Tooltip")
                and not IsDialogueRelatedKey(key)
                and type(value) == "userdata" then
                if SetManagedFont(value, "menu", true, face, menuSize, styleValue) then
                    changed = changed + 1
                end
            end
        end
    else
        RestoreManagedArea("menu")
    end

    if nameplateFont then
        local nameplateString = MakeFontString(nameplateFont.path, nameplateSize, styleValue)
        if SetNameplateKeyboardFont then pcall(function() SetNameplateKeyboardFont(nameplateString, 1) end) end
        if SetNameplateGamepadFont then pcall(function() SetNameplateGamepadFont(nameplateString, 1) end) end
        Log("Nameplates set: " .. nameplateString)
    else
        if original.nameplateKeyboard and SetNameplateKeyboardFont then
            pcall(function() SetNameplateKeyboardFont(original.nameplateKeyboard, 1) end)
        end
        if original.nameplateGamepad and SetNameplateGamepadFont then
            pcall(function() SetNameplateGamepadFont(original.nameplateGamepad, 1) end)
        end
    end

    return menuFont and menuFont.path or nil, menuSize, styleValue, changed
end

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

local function InstallBookFontIntegration()
    if bookApiHookInstalled or type(GetBookMediumFontInfo) ~= "function" then return end
    local originalGetBookMediumFontInfo = GetBookMediumFontInfo
    _G.GetBookMediumFontInfo = function(mediumId, isGamepad, ...)
        local values = { originalGetBookMediumFontInfo(mediumId, isGamepad, ...) }
        if savedVars and IsAreaEnabled("book") then
            local bookFont = GetAreaFont("book")
            if bookFont then
                local face = bookFont.path
                local size = math.max(12, math.min(48, tonumber(savedVars.bookSize) or 17))
                local styleValue = savedVars.bookStyleEnabled and GetCurrentStyle().value or ""
                local style = GetFontStyleEnum(styleValue)
                values[1] = face
                values[2] = size
                values[3] = style
                values[4] = face
                values[5] = size
                values[6] = style
            end
        end
        return unpack(values)
    end
    bookApiHookInstalled = true
end

local function InstallLoreLifecycleHooks()
    if loreLifecycleHooksInstalled then return end
    if LORE_READER and ZO_PreHook then
        ZO_PreHook(LORE_READER, "Show", function()
            InstallBookFontIntegration()
        end)
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
    local enabled = IsAreaEnabled("book")
    for _, name in ipairs(names) do
        if ApplyToFontObject(name, "book", enabled, face, size, style) then count = count + 1 end
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
            elseif type(value) == "string" and (key == "fontFace" or key == "font") then
                if IsAreaEnabled("tooltip") then
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
    if IsAreaEnabled("tooltip") then
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

local function ApplyPopupBuffer(window)
    if not window then return false end
    local chatFont = GetAreaFont("chat")
    if not chatFont then return false end
    local ok, buffer = pcall(function() return window.buffer end)
    if not ok or not buffer or not buffer.SetFont then return false end
    local size = math.max(12, math.min(48, tonumber(savedVars.chatSize) or 17))
    local style = ""
    if buffer.GetFontInfo then
        local got, _, currentSize, currentStyle = pcall(function() return buffer:GetFontInfo() end)
        if got then
            size = tonumber(currentSize) or size
            style = currentStyle or ""
        end
    end
    return pcall(function() buffer:SetFont(MakeFontString(chatFont.path, size, style)) end)
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
    if not IsAreaEnabled("chat") then return 0, 0 end
    local changed, found = 0, 0
    ForEachChatContainer(function(container)
        local ok, windows = pcall(function() return container.windows end)
        if ok and type(windows) == "table" then
            local iterator = zo_insecurePairs or pairs
            for _, window in iterator(windows) do
                if window and window.buffer then
                    found = found + 1
                    if ApplyPopupBuffer(window) then changed = changed + 1 end
                end
            end
        end
    end)
    return changed, found
end

local function InstallPopupChatHooks()
    if not SharedChatContainer then return end
    if not popupMessageHookInstalled and ZO_PreHook and SharedChatContainer.AddMessageToWindow then
        ZO_PreHook(SharedChatContainer, "AddMessageToWindow", function(container, window)
            ApplyPopupBuffer(window)
        end)
        popupMessageHookInstalled = true
    end
    if not popupFontSizeHookInstalled and ZO_PostHook and SharedChatContainer.SetFontSize then
        ZO_PostHook(SharedChatContainer, "SetFontSize", function(container, tabIndex)
            local window = container and container.windows and container.windows[tabIndex]
            ApplyPopupBuffer(window)
        end)
        popupFontSizeHookInstalled = true
    end
    if not popupWindowHookInstalled and ZO_PostHook and SharedChatContainer.AddRawWindow then
        ZO_PostHook(SharedChatContainer, "AddRawWindow", function(container, window)
            ApplyPopupBuffer(window)
        end)
        popupWindowHookInstalled = true
    end
end

local function ApplySpecializedFonts(face, uiSize, styleValue)
    local combatFont = GetAreaFont("combat")
    if combatFont then
        local combatString = MakeFontString(combatFont.path, math.max(12, math.min(48, tonumber(savedVars.combatSize) or 26)), styleValue)
        if SetSCTKeyboardFont then pcall(function() SetSCTKeyboardFont(combatString, 1) end) end
        if SetSCTGamepadFont then pcall(function() SetSCTGamepadFont(combatString, 1) end) end
        Log("Combat text set: " .. combatString)
    end

    local booksChanged = 0
    local bookFont = GetAreaFont("book")
    if bookFont then
        local bookSize = math.max(12, math.min(48, tonumber(savedVars.bookSize) or 17))
        local bookStyle = savedVars.bookStyleEnabled and styleValue or ""
        booksChanged = ApplyBookFontObjects(bookFont.path, bookSize, bookStyle)
        InstallBookFontIntegration()
        InstallLoreLifecycleHooks()
    else
        RestoreManagedArea("book")
    end

    local tooltipChanged = 0
    local tooltipFont = GetAreaFont("tooltip")
    if tooltipFont then
        for _, name in ipairs({
            "ZoFontTooltip", "ZoFontTooltipTitle", "ZoFontTooltipSubtitle",
            "ZoFontGamepadTooltip", "ZoFontGamepadTooltipTitle", "ZoFontGamepadTooltipSubtitle",
        }) do
            if ApplyToFontObject(name, "tooltip", true, tooltipFont.path, 18, styleValue) then
                tooltipChanged = tooltipChanged + 1
            end
        end
        tooltipChanged = tooltipChanged + ApplyTooltipStyles(tooltipFont.path)
    else
        RestoreManagedArea("tooltip")
        ApplyTooltipStyles(nil)
    end

    Log(string.format("Applied areas: books=%d, tooltip entries=%d", booksChanged, tooltipChanged))
end

local function ApplyFont()
    if not savedVars then return end
    Log("=== APPLYING FONT ===")
    InstallPopupChatHooks()
    InstallDialogueInteractHooks()
    local face, menuSize, styleValue, changed = ApplyCoreFonts()
    Log("Menu/UI fonts touched: " .. tostring(changed))
    local popupChanged, popupFound = ApplyPopupChatBuffers()
    Log(string.format(
        "Fading chat: buffers=%d changed=%d hooks=%s/%s/%s",
        popupFound, popupChanged,
        tostring(popupMessageHookInstalled),
        tostring(popupFontSizeHookInstalled),
        tostring(popupWindowHookInstalled)
    ))
    ApplySpecializedFonts(face, menuSize, styleValue)
    ReapplyDialogueFonts()
    Log("=====================")
end

local function LiveApply()
    ApplyFont()
end

local SECRET_MUDBALL_INTERVAL_MS = 2600
local secretMudballReadyAt = 0

-- Delay (ms) before the curtsey, so the memento animation does not override it.
local SECRET_CURTSEY_DELAY_MS = 1000
local SECRET_CURTSEY_COOLDOWN_MS = 3000
local secretCurtseyReadyAt = 0
local secretMementoHookInstalled = false
-- Delay (ms) before the faint; 0 = immediately.
local SECRET_FAINT_DELAY_MS = 1000

local emoteIndexCache = {}

local function FindEmoteIndex(slashName)
    if emoteIndexCache[slashName] then return emoteIndexCache[slashName] end
    if not GetEmoteInfo then return nil end
    local target = string.lower(slashName)
    local count = (GetNumEmotes and GetNumEmotes()) or 500
    for emoteIndex = 1, count do
        local name = GetEmoteInfo(emoteIndex)
        if type(name) == "string" and name ~= "" then
            local cleaned = string.lower((name:gsub("^/", "")))
            if cleaned == target then
                emoteIndexCache[slashName] = emoteIndex
                return emoteIndex
            end
        end
    end
    return nil
end

local function PlayEmoteByName(slashName)
    if PlayEmoteByIndex then
        local emoteIndex = FindEmoteIndex(slashName)
        if emoteIndex then
            Log("Playing emote '" .. slashName .. "' (index " .. tostring(emoteIndex) .. ")")
            local ok, err = pcall(PlayEmoteByIndex, emoteIndex)
            if ok then return end
            Log("PlayEmoteByIndex failed: " .. tostring(err))
        else
            Log("Emote '" .. slashName .. "' not found in emote list")
        end
    end
    Log("Falling back to chat command /" .. slashName)
    ExecuteChatCommand("/" .. slashName)
end

local function TriggerSecretCurtsey(reason)
    if not savedVars or not savedVars.secretEmoteEnabled then return end
    local now = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
    if now < secretCurtseyReadyAt then return end
    secretCurtseyReadyAt = now + SECRET_CURTSEY_COOLDOWN_MS
    Log("Secret curtsey triggered by " .. tostring(reason))
    zo_callLater(function()
        PlayEmoteByName("curtsey")
    end, SECRET_CURTSEY_DELAY_MS)
end

local SECRET_MEMENTO_FALLBACK_MS = 1500
local secretMementoPending = false

local function ArmMementoCurtsey()
    secretMementoPending = true
    zo_callLater(function()
        if secretMementoPending then
            secretMementoPending = false
            Log("Use result event never arrived; using fallback")
            TriggerSecretCurtsey("memento (fallback)")
        end
    end, SECRET_MEMENTO_FALLBACK_MS)
end

local function OnSecretCollectibleResult(_, result, isAttemptingActivation)
    Log("Collectible use result: " .. tostring(result) .. ", attempting=" .. tostring(isAttemptingActivation))
    if not secretMementoPending then return end
    local notBlocked = COLLECTIBLE_USAGE_BLOCK_REASON_NOT_BLOCKED
    secretMementoPending = false
    if notBlocked ~= nil and result ~= notBlocked then return end
    TriggerSecretCurtsey("memento (use result)")
end

local function InstallSecretMementoHook()
    if secretMementoHookInstalled then return end
    if not ZO_PreHook or type(UseCollectible) ~= "function" then return end
    secretMementoHookInstalled = true

    ZO_PreHook("UseCollectible", function(collectibleId)
        local ok, err = pcall(function()
            if not savedVars or not savedVars.secretEmoteEnabled then return end
            local name = GetCollectibleName(collectibleId)
            if type(name) ~= "string" then return end
            Log("Collectible used: " .. name)
            if not string.lower(name):find("blossom bloom", 1, true) then return end
            ArmMementoCurtsey()
        end)
        if not ok then Log("Memento hook error: " .. tostring(err)) end
        return false -- run the original UseCollectible
    end)
end

local function OnSecretCombatEvent(_, result, isError, abilityName, abilityGraphic,
        abilityActionSlotType, sourceName, sourceType, targetName, targetType,
        hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId)
    if not savedVars or not savedVars.secretEmoteEnabled then return end
    if isError or type(abilityName) ~= "string" then return end

    local lowerName = string.lower(abilityName)

    if lowerName:find("blossom bloom", 1, true) then
        local me = GetUnitName("player")
        if me and sourceName == me then TriggerSecretCurtsey("combat event") end
        return
    end

    local isMudball = lowerName:find("mudball", 1, true)
        or lowerName:find("mud ball", 1, true)
    if not isMudball then return end

    local playerName = GetUnitName("player")
    if not playerName or targetName ~= playerName then return end

    local now = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
    if now < secretMudballReadyAt then return end

    secretMudballReadyAt = now + SECRET_MUDBALL_INTERVAL_MS
    if SECRET_FAINT_DELAY_MS > 0 then
        zo_callLater(function() PlayEmoteByName("faint") end, SECRET_FAINT_DELAY_MS)
    else
        PlayEmoteByName("faint")
    end
end

local function CreateSettings()
    local library = LibHarvensAddonSettings
    if not library then
        Log("ERROR: LibHarvensAddonSettings not found")
        return
    end

    local panel = library:AddAddon("Font Switcher")
    if not panel then return end

    local function AddFontDropdown(label, savedKey)
        local fontItems = { { name = "None", data = 0 } }
        for i, f in ipairs(FONTS) do
            fontItems[#fontItems + 1] = { name = f.name, data = i }
        end
        panel:AddSetting({
            type = library.ST_DROPDOWN,
            label = label .. " Font",
            items = fontItems,
            default = "None",
            getFunction = function()
                local idx = tonumber(savedVars[savedKey]) or 0
                if idx == 0 then return "None" end
                return FONTS[idx] and FONTS[idx].name or "None"
            end,
            setFunction = function(_, _, item)
                if item and item.data ~= nil then
                    savedVars[savedKey] = item.data
                    LiveApply()
                end
            end,
        })
    end

    local function AddSizeSlider(label, savedKey, defaultSize)
        panel:AddSetting({
            type = library.ST_SLIDER,
            label = label .. " Font Size",
            min = 12, max = 48, step = 1, default = defaultSize,
            getFunction = function() return tonumber(savedVars[savedKey]) or defaultSize end,
            setFunction = function(value)
                savedVars[savedKey] = math.max(12, math.min(48, tonumber(value) or defaultSize))
                LiveApply()
            end,
        })
    end

    AddFontDropdown("Menu", "menuFont")
    AddSizeSlider("Menu", "menuSize", 16)
    AddFontDropdown("Fading Chat", "chatFont")
    AddSizeSlider("Fading Chat", "chatSize", 17)
    AddFontDropdown("Books", "bookFont")
    AddSizeSlider("Books", "bookSize", 17)
    AddFontDropdown("Tooltips", "tooltipFont")
    AddFontDropdown("Combat", "combatFont")
    AddSizeSlider("Combat", "combatSize", 26)
    AddFontDropdown("Nameplates", "nameplateFont")
    AddSizeSlider("Nameplates", "nameplateSize", 26)
    AddFontDropdown("Dialogue", "dialogueFont")
    AddSizeSlider("Dialogue", "dialogueSize", 17)

    local styleItems = {}
    for i, style in ipairs(STYLES) do
        styleItems[#styleItems + 1] = { name = style.name, data = i }
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
        type = library.ST_CHECKBOX,
        label = "Book Shadows & Outline",
        getFunction = function() return savedVars.bookStyleEnabled end,
        setFunction = function(value)
            savedVars.bookStyleEnabled = value
            LiveApply()
        end,
    })

    panel:AddSetting({
        type = library.ST_CHECKBOX,
        label = "Suppress Debug Log",
        default = true,
        getFunction = function() return savedVars.suppressLog end,
        setFunction = function(value) savedVars.suppressLog = value end,
    })

    panel:AddSetting({
        type = library.ST_CHECKBOX,
        label = "Secret",
        default = false,
        getFunction = function() return savedVars.secretEmoteEnabled end,
        setFunction = function(value) savedVars.secretEmoteEnabled = value end,
    })
end

local function OnAddonLoaded(_, name)
    if name ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    savedVars = ZO_SavedVars:NewAccountWide("MyFontSwitcherSavedVars", 1, nil, defaults)

    -- "Chat Bubble" was renamed "Combat"; migrate old values once.
    if savedVars.overheadFont ~= nil then
        savedVars.combatFont = savedVars.overheadFont
        savedVars.overheadFont = nil
    end
    if savedVars.overheadSize ~= nil then
        savedVars.combatSize = savedVars.overheadSize
        savedVars.overheadSize = nil
    end

    local function Ensure(key, fallback)
        if savedVars[key] == nil then
            savedVars[key] = fallback
        end
    end

    Ensure("menuFont", 0)
    Ensure("chatFont", 0)
    Ensure("bookFont", 0)
    Ensure("tooltipFont", 0)
    Ensure("combatFont", 0)
    Ensure("nameplateFont", 0)
    Ensure("dialogueFont", 0)
    Ensure("style", 1)
    Ensure("bookStyleEnabled", true)
    Ensure("suppressLog", true)
    Ensure("secretEmoteEnabled", false)
    Ensure("menuSize", 16)
    Ensure("combatSize", 26)
    Ensure("nameplateSize", 26)
    Ensure("bookSize", 17)
    Ensure("chatSize", 17)
    Ensure("dialogueSize", 17)

    if savedVars.dialogueFont == nil and savedVars.interactionFont ~= nil then
        savedVars.dialogueFont = savedVars.interactionFont
    end
    if savedVars.dialogueSize == nil and savedVars.interactionSize ~= nil then
        savedVars.dialogueSize = savedVars.interactionSize
    end

    savedVars.menuSize = math.max(12, math.min(48, tonumber(savedVars.menuSize) or 16))
    savedVars.combatSize = math.max(12, math.min(48, tonumber(savedVars.combatSize) or 26))
    savedVars.nameplateSize = math.max(12, math.min(48, tonumber(savedVars.nameplateSize) or 26))
    savedVars.bookSize = math.max(12, math.min(48, tonumber(savedVars.bookSize) or 17))
    savedVars.chatSize = math.max(12, math.min(48, tonumber(savedVars.chatSize) or 17))
    savedVars.dialogueSize = math.max(12, math.min(48, tonumber(savedVars.dialogueSize) or 17))

    for _, key in ipairs({"menuFont", "chatFont", "bookFont", "tooltipFont", "combatFont", "nameplateFont", "dialogueFont"}) do
        local v = tonumber(savedVars[key])
        if v == nil then
            savedVars[key] = 0
        elseif v ~= 0 and (v < 1 or v > #FONTS) then
            savedVars[key] = 0
        else
            savedVars[key] = v
        end
    end

    if GetNameplateKeyboardFont then
        local f = GetNameplateKeyboardFont()
        if f then original.nameplateKeyboard = f end
    end
    if GetNameplateGamepadFont then
        local f = GetNameplateGamepadFont()
        if f then original.nameplateGamepad = f end
    end

    CreateSettings()
    InstallDialogueInteractHooks()

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "SecretMudball", EVENT_COMBAT_EVENT, OnSecretCombatEvent)
    InstallSecretMementoHook()
    if EVENT_COLLECTIBLE_USE_RESULT then
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "SecretCollectible", EVENT_COLLECTIBLE_USE_RESULT, OnSecretCollectibleResult)
    end

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, function()
        zo_callLater(ApplyFont, 1500)
        ScheduleDialogueFontReapply(2500)
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Chatter", EVENT_CHATTER_BEGIN, function()
        InstallDialogueInteractHooks()
        ApplyDialogueFontsImmediately(true)
    end)

    if EVENT_CONVERSATION_UPDATED then
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "ConversationUpdated", EVENT_CONVERSATION_UPDATED, function()
            InstallDialogueInteractHooks()
            ScheduleDialogueFontReapply(0, false)
        end)
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
