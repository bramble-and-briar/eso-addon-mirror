-- Language loader: all seven locale tables are loaded before this file.
-- Language selection affects Wegesruhe only, never ESO's "language.2" CVar.
local WR = Wegesruhe
WR.supportedLanguages = {
    auto = true, en = true, de = true, fr = true, es = true,
    ru = true, zh = true, jp = true,
}

local function NormalizeEsoLanguage(value)
    if type(value) ~= "string" then return "en" end
    local code = string.lower(value):gsub("_", "-")
    if code == "ja" or code == "ja-jp" or code == "jp" then return "jp" end
    if code == "zh" or code == "zh-cn" or code == "zh-hans" then return "zh" end
    code = code:sub(1, 2)
    if WR.Localization[code] then return code end
    return "en"
end

function WR:GetResolvedLanguage()
    local requested = self.storage and self.storage.language or "auto"
    if not self.supportedLanguages[requested] then requested = "auto" end
    if requested == "auto" then
        return NormalizeEsoLanguage(GetCVar("language.2"))
    end
    return requested
end

function WR:InitializeLanguage()
    local resolved = self:GetResolvedLanguage()
    local chosen = self.Localization[resolved] or self.Localization.en
    local english = self.Localization.en
    -- Look up the selected language first; English fills any missing strings.
    self.L = setmetatable({}, { __index = function(_, key)
        return chosen[key] or english[key]
    end })

    -- ESO's keybinding menu always follows ESO's language, not Wegesruhe's
    -- independently selected UI language. Never change key assignments here.
    local esoTexts = self.Localization[NormalizeEsoLanguage(GetCVar("language.2"))] or english
    if SI_BINDING_NAME_WEGESRUHE_SHOW_HELP then
        SafeAddString(SI_BINDING_NAME_WEGESRUHE_SHOW_HELP, esoTexts.BINDING_SHOW_HELP, 2)
        SafeAddString(SI_BINDING_NAME_WEGESRUHE_TOGGLE, esoTexts.BINDING_TOGGLE, 2)
        SafeAddString(SI_WEGESRUHE_BINDING_CATEGORY, esoTexts.BINDING_CATEGORY, 2)
    end
end

-- Binding string IDs must exist before the ESO keybinding UI can use them.
-- The correct manual language is selected later, after SavedVariables load.
local initial = WR.Localization[NormalizeEsoLanguage(GetCVar("language.2"))] or WR.Localization.en
ZO_CreateStringId("SI_BINDING_NAME_WEGESRUHE_SHOW_HELP", initial.BINDING_SHOW_HELP)
ZO_CreateStringId("SI_BINDING_NAME_WEGESRUHE_TOGGLE", initial.BINDING_TOGGLE)
ZO_CreateStringId("SI_WEGESRUHE_BINDING_CATEGORY", initial.BINDING_CATEGORY)
WR.L = initial
