local A = ALTHarvestItems
A.languages = {
    { code = "de", name = "Deutsch" }, { code = "en", name = "English" },
    { code = "fr", name = "Français", draft = true }, { code = "es", name = "Español", draft = true },
    { code = "ru", name = "Русский", draft = true }, { code = "zh", name = "简体中文", draft = true },
    { code = "jp", name = "日本語", draft = true },
    { code = "auto", name = "AUTO_ESO_LANGUAGE" },
}
function A:ClientLanguage()
    local code=GetCVar and GetCVar("language.2") or "en"
    if code=="ja" then code="jp" end
    return type(code)=="string" and code:match("^[a-z][a-z]$") and code or "en"
end
-- Preserve native registration separately from any later independent UI choice.
A.nativeText={}
for key,english in pairs(A.localeTables.en) do
    local value=GetString(_G["ALTHARVESTITEMS_"..key])
    A.nativeText[key]=value and value~="" and value or english
end
if A:ClientLanguage()~="en" then A.localeTables[A:ClientLanguage()]=A.nativeText end
function A:HasLanguage(code)
    return code=="auto" or self.localeTables[code]~=nil or self.languageChoices[code]~=nil
end
function A:LanguageStrings(code)
    if code=="auto" or code==self:ClientLanguage() then return self.nativeText end
    if not self.localeTables[code] and self.languageChoices[code] then
        self.localeTables[code]=self.languageChoices[code]()
    end
    return self.localeTables[code]
end
function A:T(key,code)
    if code then
        local entries=self:LanguageStrings(code) or self.localeTables.en
        return entries[key] or self.localeTables.en[key] or key
    end
    local id=_G["ALTHARVESTITEMS_"..key]
    if id then
        local value=GetString(id)
        if value and value~="" then return value end
    end
    return self.localeTables.en[key] or key
end
function A:ApplyLanguage(code)
    local entries=self:LanguageStrings(code)
    if not entries then return false end
    -- Version 0: default; 1: native file; 2: explicit ALTHI-only preference.
    for key,english in pairs(self.localeTables.en) do
        SafeAddString(_G["ALTHARVESTITEMS_"..key],entries[key] or english,2)
    end
    return true
end
function A:InitializeLanguage()
    local chosen=self.db.language
    self.locale=chosen and chosen~="auto" and self:HasLanguage(chosen) and chosen or self:ClientLanguage()
    if chosen and chosen~="auto" and self:HasLanguage(chosen) then
        self:LanguageStrings(chosen)
        if chosen~=self:ClientLanguage() then self:ApplyLanguage(chosen) end
    end
    if SafeAddString then
        SafeAddString(SI_BINDING_NAME_ALTHI_TOGGLE, self:T("ALTHI_TOGGLE_WINDOW"), 1)
        SafeAddString(SI_BINDING_NAME_ALTHI_SETTINGS, self:T("ALTHI_OPEN_FILTER_LIST"), 1)
        SafeAddString(SI_BINDING_NAME_ALTHI_RESET, self:T("ALTHI_RESET_WITH_CONFIRMATION"), 1)
        SafeAddString(SI_BINDING_NAME_ALTHI_STOP, self:T("BINDING_LEGACY_STOP"), 1)
        SafeAddString(SI_BINDING_NAME_ALTHI_PAUSE, self:T("BINDING_TOGGLE_PAUSE"), 1)
        SafeAddString(SI_BINDING_NAME_ALTHI_RUN, self:T("BINDING_RESUME"), 1)
    end
end
function A:SelectLanguage(code)
    if not self:HasLanguage(code) then return false end
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
        window.languageNote = Paragraph(330, 44)
        window.draftNote = Paragraph(380, 30)
        window.buttons = {}
        for index, language in ipairs(self.languages) do
            local code = language.code
            local button = self:MenuButton(window, language.name, 330, function()
                if self:HasLanguage(code) then window.pending = code; self:RefreshLanguagePicker() end
            end)
            button:SetAnchor(TOPLEFT, window, TOPLEFT, 28 + ((index - 1) % 2) * 352, 125 + math.floor((index - 1) / 2) * 40)
            window.buttons[code] = button
        end
        window.apply = self:MenuButton(window, "", 450, function() self:SelectLanguage(window.pending) end)
        window.apply:SetAnchor(BOTTOMLEFT, window, BOTTOMLEFT, 24, -20)
        window.close=self:CloseIcon(window)
        window.cancel=self:MenuButton(window,self:T("CANCEL"),210,function() self:CloseDialog(window) end)
        window.cancel:SetAnchor(BOTTOMRIGHT,window,BOTTOMRIGHT,-24,-20)
        self.languageWindow = window
    end
    local window = self.languageWindow
    window.firstRun, window.pending = firstRun, firstRun and "en" or (self.db.language=="auto" and "auto" or self.locale)
    self:RefreshLanguagePicker()
    self:ShowDialog(window)
end
function A:RefreshLanguagePicker()
    local window = self.languageWindow
    local code = window.pending
    window.title:SetText(self:GoldText(self:T("WELCOME_TO_ALTHI", code)))
    window.intro:SetText(self:T("CHOOSE_YOUR_LANGUAGE_YOU_CAN_CHANGE_IT_LATER_IN_SETTINGS", code))
    window.itemNote:SetText(self:T("ITEM_NAMES_AND_ITEM_TOOLTIPS_FOLLOW_YOUR_ESO_GAME_LANGUAGE", code))
    window.languageNote:SetText(self:T("ALL_LANGUAGES_INCLUDED",code))
    local draft = false
    for _, language in ipairs(self.languages) do
        local available=self:HasLanguage(language.code)
        window.buttons[language.code]:SetEnabled(available)
        window.buttons[language.code]:SetAlpha(available and 1 or 0.35)
        local selected = language.code == code
        window.buttons[language.code]:SetText((selected and "> " or "") .. (language.code=="auto" and self:T(language.name,code) or language.name) .. (selected and " <" or ""))
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

ZO_CreateStringId("SI_BINDING_NAME_ALTHI_RUN", A:T("BINDING_RESUME"))

ZO_CreateStringId("SI_BINDING_NAME_ALTHI_PAUSE", A:T("BINDING_TOGGLE_PAUSE"))

ZO_CreateStringId("SI_BINDING_NAME_ALTHI_STOP", A:T("BINDING_LEGACY_STOP"))

ZO_CreateStringId("SI_BINDING_NAME_ALTHI_RESET", A:T("ALTHI_RESET_WITH_CONFIRMATION"))
