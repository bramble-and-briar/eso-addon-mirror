local C=CrownCrateCodex
C.translations={}
-- Display language never becomes an identity, SavedVariables profile or CSV field.
function C:LanguageCode()
    if self.activeLanguage then return self.activeLanguage end
    local chosen=self.db and self.db.settings.language or "auto"
    local game=GetCVar and GetCVar("Language.2") or "en"
    local code=chosen=="auto" and game or chosen
    if code=="jp" then code="ja" end
    return self.translations[code] and code or "en"
end
function C.L(text)
    local dictionary=C.translations[C:LanguageCode()]
    return dictionary and dictionary[text] or text
end
function C:InitializeLanguage()
    self.activeLanguage=nil
    self.activeLanguage=self:LanguageCode()
end
function C:LanguageChoices()
    return {C.L("Automatic — follow ESO"),"English","Chinese (Simplified) — 简体中文","French — Français","German — Deutsch","Japanese — 日本語","Russian — Русский","Spanish — Español"},
        {"auto","en","zh","fr","de","ja","ru","es"}
end
function C:FitLocalizedLabel(control)
    local label=control.GetLabelControl and control:GetLabelControl() or control
    if not label or not label.GetTextWidth then return end
    -- Fit translated single-line labels within their existing hit areas. Keep
    -- the user's selected size unless the rendered text actually overflows.
    local width=control:GetWidth()-4
    if width<=0 then return end
    local size=self.db.settings.displaySize=="Extra Large" and 22 or 18
    local function TextWidth()
        return label.GetStringWidth and label:GetStringWidth(label:GetText()) or label:GetTextWidth()
    end
    while TextWidth()>width and size>12 do
        size=size-1
        control:SetFont("$(MEDIUM_FONT)|"..size.."|soft-shadow-thin")
    end
end
