local A = ALTHarvestItems
A.languages = {
    { code = "de", name = "Deutsch" }, { code = "en", name = "English" },
    { code = "fr", name = "Français", draft = true }, { code = "es", name = "Español", draft = true },
    { code = "ru", name = "Русский", draft = true }, { code = "zh", name = "简体中文", draft = true },
    { code = "jp", name = "日本語", draft = true },
}
function A:ClientLanguage()
    local code = GetCVar and GetCVar("language.2") or "en"
    if code == "ja" then code = "jp" end
    return self.translations[code] and code or "en"
end
function A:T(key, code)
    local entries = self.translations[code or self.locale or self:ClientLanguage()] or self.translations.en
    return entries[key] or self.translations.en[key] or key
end
function A:InitializeLanguage()
    self.locale = self.translations[self.db.language] and self.db.language or self:ClientLanguage()
    if SafeAddString then
        SafeAddString(SI_BINDING_NAME_ALTHI_TOGGLE, self:T("ALTHI_TOGGLE_WINDOW"), 1)
        SafeAddString(SI_BINDING_NAME_ALTHI_SETTINGS, self:T("ALTHI_OPEN_FILTER_LIST"), 1)
        SafeAddString(SI_BINDING_NAME_ALTHI_RESET, self:T("ALTHI_RESET_WITH_CONFIRMATION"), 1)
        SafeAddString(SI_BINDING_NAME_ALTHI_STOP, self:T("ALTHI_STOP"), 1)
        SafeAddString(SI_BINDING_NAME_ALTHI_PAUSE, self:T("ALTHI_PAUSE"), 1)
        SafeAddString(SI_BINDING_NAME_ALTHI_RUN, self:T("ALTHI_RUN_RESUME"), 1)
    end
end
function A:SelectLanguage(code)
    if not self.translations[code] then return false end
    -- Accrue active time before ReloadUI; the existing session must return paused.
    self:Pause()
    self.db.language, self.db.languageChosen = code, true
    ReloadUI()
    return true
end
function A:OpenLanguagePicker(firstRun)
    if not self.languageWindow then
        local window = WINDOW_MANAGER:CreateTopLevelWindow("ALTHILanguageWindow")
        window:SetDimensions(740, 460); window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
        window:SetMouseEnabled(true); window:SetMovable(true); window:SetClampedToScreen(true)
        self:Backdrop(window)
        window.title = self:Label(window, "ZoFontWinH2")
        window.title:SetAnchor(TOPLEFT, window, TOPLEFT, 24, 18); window.title:SetDimensions(640, 32)
        local function Paragraph(y, height)
            local label = self:Label(window)
            label:SetAnchor(TOPLEFT, window, TOPLEFT, 24, y); label:SetDimensions(690, height)
            label:SetMaxLineCount(3); label:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
            return label
        end
        window.intro = Paragraph(55, 68)
        window.itemNote = Paragraph(290, 38)
        window.packNote = Paragraph(330, 44)
        window.draftNote = Paragraph(380, 30)
        window.buttons = {}
        for index, language in ipairs(self.languages) do
            local code = language.code
            local button = self:Button(window, language.name, 330, function()
                if self.translations[code] then window.pending = code; self:RefreshLanguagePicker() end
            end)
            button:SetAnchor(TOPLEFT, window, TOPLEFT, 28 + ((index - 1) % 2) * 352, 125 + math.floor((index - 1) / 2) * 40)
            window.buttons[code] = button
        end
        window.apply = self:Button(window, "", 450, function() self:SelectLanguage(window.pending) end)
        window.apply:SetAnchor(BOTTOMLEFT, window, BOTTOMLEFT, 24, -20)
        window.close=self:CloseIcon(window)
        window.cancel=self:Button(window,self:T("CANCEL"),210,function() self:CloseDialog(window) end)
        window.cancel:SetAnchor(BOTTOMRIGHT,window,BOTTOMRIGHT,-24,-20)
        self.languageWindow = window
    end
    local window = self.languageWindow
    window.firstRun, window.pending = firstRun, firstRun and "en" or self.locale
    self:RefreshLanguagePicker()
    self:ShowDialog(window)
end
function A:RefreshLanguagePicker()
    local window = self.languageWindow
    local code = window.pending
    window.title:SetText(self:GoldText(self:T("WELCOME_TO_ALTHI", code)))
    window.intro:SetText(self:T("CHOOSE_YOUR_LANGUAGE_YOU_CAN_CHANGE_IT_LATER_IN_SETTINGS", code))
    window.itemNote:SetText(self:T("ITEM_NAMES_AND_ITEM_TOOLTIPS_FOLLOW_YOUR_ESO_GAME_LANGUAGE", code))
    window.packNote:SetText(self:T("OPTIONAL_LANGUAGE_PACKS_INFO",code))
    local draft = false
    for _, language in ipairs(self.languages) do
        local available=self.translations[language.code]~=nil
        window.buttons[language.code]:SetEnabled(available)
        window.buttons[language.code]:SetAlpha(available and 1 or 0.35)
        local selected = language.code == code
        window.buttons[language.code]:SetText((selected and "> " or "") .. language.name .. (selected and " <" or ""))
        if selected then draft = language.draft end
    end
    window.draftNote:SetText(draft and self:T("DRAFT_TRANSLATION_FEEDBACK_WELCOME", code) or "")
    window.apply:SetText(self:T("APPLY_AND_RELOAD_UI", code))
    window.close:SetHidden(window.firstRun == true)
    window.cancel:SetText(self:T("CANCEL",code)); window.cancel:SetHidden(window.firstRun == true)
end

-- Declare binding IDs before Bindings.xml loads; saved language is applied at Initialize.
ZO_CreateStringId("SI_BINDING_NAME_ALTHI_TOGGLE", A:T("ALTHI_TOGGLE_WINDOW"))
ZO_CreateStringId("SI_BINDING_NAME_ALTHI_SETTINGS", A:T("ALTHI_OPEN_FILTER_LIST"))

ZO_CreateStringId("SI_BINDING_NAME_ALTHI_RUN", A:T("ALTHI_RUN_RESUME"))

ZO_CreateStringId("SI_BINDING_NAME_ALTHI_PAUSE", A:T("ALTHI_PAUSE"))

ZO_CreateStringId("SI_BINDING_NAME_ALTHI_STOP", A:T("ALTHI_STOP"))

ZO_CreateStringId("SI_BINDING_NAME_ALTHI_RESET", A:T("ALTHI_RESET_WITH_CONFIRMATION"))
