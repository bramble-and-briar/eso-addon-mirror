--[[
    ARC_CustomFonts
    Author: @arcsinan
    Description: High-quality, royalty-free open-source fonts for ESO.
                 Registers fonts with LibMediaProvider (LMP) and provides optional in-game UI overrides.
]]

ARC_CustomFonts = ARC_CustomFonts or {}
local ADDON_NAME = "ARC_CustomFonts"
local ADDON_VERSION = "1.0.0"

ARC_CustomFonts.name = ADDON_NAME
ARC_CustomFonts.version = ADDON_VERSION

-- Curated list of 100% free, royalty-free open-source fonts
ARC_CustomFonts.fontList = {
    {
        key = "Cinzel",
        path = "ARC_CustomFonts/fonts/Cinzel-Regular.slug",
        ttf = "ARC_CustomFonts/fonts/Cinzel-Regular.ttf",
        desc = "Classic Roman fantasy serif; ideal for titles, lore, and character names."
    },
    {
        key = "Cinzel Decorative",
        path = "ARC_CustomFonts/fonts/CinzelDecorative-Bold.slug",
        ttf = "ARC_CustomFonts/fonts/CinzelDecorative-Bold.ttf",
        desc = "Intricate fantasy serif capitals; great for achievements and chapter headers."
    },
    {
        key = "MedievalSharp",
        path = "ARC_CustomFonts/fonts/MedievalSharp-Regular.slug",
        ttf = "ARC_CustomFonts/fonts/MedievalSharp-Regular.ttf",
        desc = "Handcrafted Gothic / Celtic fantasy style."
    },
    {
        key = "Bebas Neue",
        path = "ARC_CustomFonts/fonts/BebasNeue-Regular.slug",
        ttf = "ARC_CustomFonts/fonts/BebasNeue-Regular.ttf",
        desc = "High-impact condensed all-caps; excellent for combat numbers and cooldown timers."
    },
    {
        key = "Inter",
        path = "ARC_CustomFonts/fonts/Inter-Regular.slug",
        ttf = "ARC_CustomFonts/fonts/Inter-Regular.ttf",
        desc = "World-class legibility; crisp, clean modern sans-serif for chat and inventory."
    },
    {
        key = "Outfit",
        path = "ARC_CustomFonts/fonts/Outfit-Regular.slug",
        ttf = "ARC_CustomFonts/fonts/Outfit-Regular.ttf",
        desc = "Contemporary geometric sans-serif for a sleek, minimalist game interface."
    },
    {
        key = "Lora",
        path = "ARC_CustomFonts/fonts/Lora-Regular.slug",
        ttf = "ARC_CustomFonts/fonts/Lora-Regular.ttf",
        desc = "Warm editorial serif; highly legible for dialogue, lorebooks, and quest texts."
    },
    {
        key = "DejaVu Sans",
        path = "ARC_CustomFonts/fonts/DejaVuSans.slug",
        ttf = "ARC_CustomFonts/fonts/DejaVuSans.ttf",
        desc = "Rock-solid, universally legible classic sans-serif."
    },
    {
        key = "DejaVu Sans Bold",
        path = "ARC_CustomFonts/fonts/DejaVuSans-Bold.slug",
        ttf = "ARC_CustomFonts/fonts/DejaVuSans-Bold.ttf",
        desc = "Bold variant of DejaVu Sans; universally legible classic sans-serif."
    },
    {
        key = "Turkish Font Regular",
        path = "ARC_CustomFonts/fonts/TurkishFont-Regular.slug",
        ttf = "ARC_CustomFonts/fonts/TurkishFont-Regular.ttf",
        desc = "High-compatibility Unicode font with complete Turkish diacritics support."
    },
    {
        key = "Turkish Font Bold",
        path = "ARC_CustomFonts/fonts/TurkishFont-Bold.slug",
        ttf = "ARC_CustomFonts/fonts/TurkishFont-Bold.ttf",
        desc = "Bold high-compatibility Unicode font with complete Turkish diacritics support."
    },
}

-- Default SavedVariables
local defaults = {
    language = "en",
    enableOverrides = false,
    chatFont = "None",
    uiFont = "None",
    headerFont = "None",
    bookFont = "None",
    combatFont = "None",
}

-- Helper to find font path by key
function ARC_CustomFonts:GetFontPathByKey(fontKey)
    if not fontKey or fontKey == "None" then return nil end
    for _, font in ipairs(self.fontList) do
        if font.key == fontKey then
            return font.path
        end
    end
    return nil
end

-- Safely formats a new font string while preserving original size and shadow/outline styling
local function FormatFont(newFontPath, targetFontObject, fallbackSize, fallbackStyle)
    if not newFontPath or not targetFontObject or not targetFontObject.GetFontInfo then
        return nil
    end

    local currentFontString = targetFontObject:GetFontInfo() or ""
    local parts = { zo_strsplit("|", currentFontString) }
    local size = parts[2] or fallbackSize or "18"
    local style = parts[3] or fallbackStyle or "soft-shadow-thin"

    return string.format("%s|%s|%s", newFontPath, size, style)
end

-- Safely updates a font object
local function ApplyFontToControl(fontObject, newFontPath, fallbackSize, fallbackStyle)
    if not fontObject or not fontObject.SetFont then return end
    local formatted = FormatFont(newFontPath, fontObject, fallbackSize, fallbackStyle)
    if formatted then
        fontObject:SetFont(formatted)
    end
end

-- Register all fonts with LibMediaProvider-1.0
function ARC_CustomFonts:RegisterWithLMP()
    local LMP = LibMediaProvider
    if not LMP then return false end

    for _, font in ipairs(self.fontList) do
        -- Register with primary .slug path (for ESO Update 41+ Slug font renderer)
        LMP:Register("font", font.key, font.path)
    end
    return true
end

-- Apply global font overrides to standard EsoUI font objects
function ARC_CustomFonts:ApplyOverrides()
    if not self.savedVars or not self.savedVars.enableOverrides then
        return
    end

    -- 1. Chat Font
    local chatPath = self:GetFontPathByKey(self.savedVars.chatFont)
    if chatPath then
        ApplyFontToControl(ZoFontChat, chatPath, "18", "soft-shadow-thin")
        ApplyFontToControl(ZoFontEditChat, chatPath, "18", "soft-shadow-thin")
    end

    -- 2. General UI Font
    local uiPath = self:GetFontPathByKey(self.savedVars.uiFont)
    if uiPath then
        ApplyFontToControl(ZoFontGame, uiPath, "18", "soft-shadow-thin")
        ApplyFontToControl(ZoFontGameBold, uiPath, "18", "soft-shadow-thin")
        ApplyFontToControl(ZoFontGameMedium, uiPath, "16", "soft-shadow-thin")
        ApplyFontToControl(ZoFontGameSmall, uiPath, "14", "soft-shadow-thin")
    end

    -- 3. Headers & Titles Font
    local headerPath = self:GetFontPathByKey(self.savedVars.headerFont)
    if headerPath then
        ApplyFontToControl(ZoFontHeader, headerPath, "24", "soft-shadow-thick")
        ApplyFontToControl(ZoFontHeader2, headerPath, "20", "soft-shadow-thick")
        ApplyFontToControl(ZoFontHeader3, headerPath, "18", "soft-shadow-thick")
        ApplyFontToControl(ZoFontHeader4, headerPath, "16", "soft-shadow-thick")
        ApplyFontToControl(ZoFontWindowTitle, headerPath, "28", "soft-shadow-thick")
    end

    -- 4. Book & Lore Font
    local bookPath = self:GetFontPathByKey(self.savedVars.bookFont)
    if bookPath then
        ApplyFontToControl(ZoFontBookPaper, bookPath, "20", "shadow")
        ApplyFontToControl(ZoFontBookPaperTitle, bookPath, "24", "shadow")
        ApplyFontToControl(ZoFontBookScroll, bookPath, "22", "shadow")
        ApplyFontToControl(ZoFontBookScrollTitle, bookPath, "26", "shadow")
    end
end

-- Addon Loaded Event Handler
local function OnAddOnLoaded(event, addonName)
    if addonName ~= ADDON_NAME then return end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    -- SavedVariables initialization (Account-wide with Megaserver isolation)
    ARC_CustomFonts.savedVars = ZO_SavedVars:NewAccountWide(
        "ARC_CustomFonts_SavedVariables",
        1,
        GetWorldName(),
        defaults,
        nil,
        nil
    )

    -- Apply Turkish if configured in SavedVariables (English remains default otherwise)
    if ARC_CustomFonts.savedVars.language == "tr" and ARC_CustomFonts.ApplyTurkishStrings then
        ARC_CustomFonts.ApplyTurkishStrings()
    end

    -- Register with LibMediaProvider
    ARC_CustomFonts:RegisterWithLMP()

    -- Apply font overrides if enabled
    ARC_CustomFonts:ApplyOverrides()

    -- Register Slash Commands inside OnAddOnLoaded
    local function OpenSettings()
        if LibAddonMenu2 and ARC_CustomFonts.settingsPanel then
            LibAddonMenu2:OpenToPanel(ARC_CustomFonts.settingsPanel)
        else
            d("|cFFD700[ARC Custom Fonts]|r " .. GetString(SI_ARC_CF_TITLE))
            d("Use Add-on Settings menu to configure custom fonts.")
        end
    end

    -- In-Game Gold Donation & Feedback to @arcsinan
    function ARC_CustomFonts.DonateGold(amount)
        local world = GetWorldName()
        if world ~= "" and not string.find(string.lower(world), "eu") then
            local warnFmt = GetString(SI_ARC_CF_CHAT_SERVER_WARN)
            d(string.format(warnFmt, tostring(world)))
        end

        local goldAmount = tonumber(amount) or 0

        SCENE_MANAGER:Show("mailSend")
        zo_callLater(function()
            if ZO_MailSendToField then
                ZO_MailSendToField:SetText("@arcsinan")
            end
            if ZO_MailSendSubjectField then
                ZO_MailSendSubjectField:SetText("ARC Custom Fonts Donation")
            end
            if ZO_MailSendBodyField then
                local mailBody = GetString(SI_ARC_CF_MAIL_BODY)
                ZO_MailSendBodyField:SetText(mailBody)
                ZO_MailSendBodyField:TakeFocus()
            end
            if goldAmount > 0 and QueueMoneyAttachment then
                QueueMoneyAttachment(goldAmount)
                if ZO_MailSendSendCurrency and ZO_MailSendSendCurrency.OnBeginInput then
                    ZO_MailSendSendCurrency:OnBeginInput()
                end
            end
        end, 250)
    end
    ARC_CustomFonts.OpenDonationMail = ARC_CustomFonts.DonateGold

    SLASH_COMMANDS["/customfonts"] = OpenSettings
    SLASH_COMMANDS["/arcfonts"] = OpenSettings
    SLASH_COMMANDS["/arcdonate"] = function() ARC_CustomFonts.DonateGold(0) end

    -- Initialize Settings Panel (LibAddonMenu-2.0)
    if ARC_CustomFonts.InitializeSettings then
        ARC_CustomFonts:InitializeSettings()
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
