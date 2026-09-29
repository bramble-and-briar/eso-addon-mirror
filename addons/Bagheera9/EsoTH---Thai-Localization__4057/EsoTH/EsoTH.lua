local LMP = LibMediaProvider
EsoTH = EsoTH or {
  name = "EsoTH",
  firstInit = true,
  chat = { changed = true, privCursorPos = 0, editing = false },
  version = "0.15",
  langKeyboard = "en",
  langVer = {
  ["stable"] = "th",
  },
}
EsoTH.Defaults = {
  Anchor = { BOTTOMRIGHT, BOTTOMRIGHT, 0, 7 },
  ignorePatcher = true,
  lang = "th",
}
EsoTH.savedVars = EsoTH.Defaults

local thai = { EsoTH.langVer.stable, }
local isNeedToChangeAdditionalFontTable = { EsoTH.langVer.stable, "en", }

function EsoTH:setLanguage(lang)
  zo_callLater(function()
    SetCVar("language.2", lang)
    EsoTH.savedVars.lang = lang
    ReloadUI()
  end, 500)
end

function EsoTH:getLanguage() return GetCVar("language.2") end

function EsoTH:getFontPath()
  for _, x in pairs(isNeedToChangeAdditionalFontTable) do if self:getLanguage() == x then return "EsoTH/Fonts/" end end
  return "EsoUI/Common/Fonts/"
end

function EsoTH:fontChangeWhenInit()
  local styles = { "ZO_TOOLTIP_STYLES", "ZO_CRAFTING_TOOLTIP_STYLES", "ZO_GAMEPAD_DYEING_TOOLTIP_STYLES" }
  local path = EsoTH:getFontPath()
  local function f(x) return path .. x end
  local fontFaces = EsoTH.fontFaces
  for _, v in pairs(styles) do for k, fnt in pairs(fontFaces[v]) do _G[v][k]["fontFace"] = f(fnt) end end

  local fontString = "EsoTH/fonts/google-sans.slug"
  for _, fontStyle in pairs(styles) do
    local fontInformation = _G[fontStyle]
    for key, fontData in pairs(fontInformation) do
      fontData["fontFace"] = fontString
    end
  end

  LMP:Register("font", "TH Google Sans", "$(ESOTH_GOOGLE_SANS_FONT)")
  LMP:Register("font", "TH Google Sans Medium", "$(ESOTH_GOOGLE_SANS_MEDIUM_FONT)")
  LMP:Register("font", "TH Google Sans Bold", "$(ESOTH_GOOGLE_SANS_BOLD_FONT)")
  LMP:Register("font", "TH Noto Serif Medium", "$(ESOTH_NOTO_SERIF_MEDIUM_FONT)")

  SetSCTKeyboardFont(f(fontFaces.FTN87) .. "|29|soft-shadow-thick")
  SetSCTGamepadFont(f(fontFaces.FTN87) .. "|35|soft-shadow-thick")
  SetNameplateKeyboardFont(f(fontFaces.FTN87), 4)
  SetNameplateGamepadFont(f(fontFaces.FTN87), 4)

  ZoFontTributeAntique40:SetFont("EsoTH/fonts/google-sans-bold.slug|40")
  ZoFontTributeAntique30:SetFont("EsoTH/fonts/google-sans-bold.slug|30")
  ZoFontTributeAntique20:SetFont("EsoTH/fonts/google-sans-bold.slug|20")
end

local function fontChangeWhenPlayerActivated()
  local path = EsoTH:getFontPath()
  local function f(x) return path .. x end
  local fontFaces = EsoTH.fontFaces

  SetSCTKeyboardFont(f(fontFaces.FTN87) .. "|29|soft-shadow-thick")
  SetSCTGamepadFont(f(fontFaces.FTN87) .. "|35|soft-shadow-thick")
  SetNameplateKeyboardFont(f(fontFaces.FTN87) .. "|20", 4)
  SetNameplateGamepadFont(f(fontFaces.FTN87)  .. "|20", 4)
end


local function EsoTHInit()
  EsoTH:fontChangeWhenInit()
  ZO_CreateStringId("SI_BINDING_NAME_CHANGE_LANG_KEYBOARD", "สลับคีย์บอร์ดไทย/อังกฤษ")

  ZO_PreHook("ZO_ChatTextEntry_Execute", function(control) control.system:CloseTextEntry(true) end)
  ZO_PreHook("ZO_ChatTextEntry_Escape", function(control) control.system:CloseTextEntry(true) end)
  ZO_PreHook("ZO_ChatTextEntry_TextChanged", function(control, newText) EsoTH:Convert(control.system.textEntry) end)
  ZO_PreHook("ZO_EditDefaultText_OnTextChanged", function(edit) EsoTH:Convert(edit) end)
end

function EsoTH:SwitchLangKeyboard()
  if langKeyboard == "th" then langKeyboard = "en" else langKeyboard = "th" end
end

local function loadscreen(eventCode)
  fontChangeWhenPlayerActivated()
  if EsoTH.firstInit then
    EsoTH.firstInit = false
    for _, v in pairs(isNeedToChangeAdditionalFontTable) do
      if EsoTH:getLanguage() ~= v and EsoTH.savedVars.lang == v then EsoTH:setLanguage(v) end
    end
  end

  zo_callLater(function() CALLBACK_MANAGER:FireCallbacks("loadscreen") end, 1000)
end

function EsoTH:newInit()
  EsoTH.savedVars = ZO_SavedVars:NewAccountWide("EsoTH_Variables", 1, nil, { lang = EsoTH.langVer.stable })
  if EsoTH:getLanguage() ~= "en" then
    SetCVar("IgnorePatcherLanguageSetting", 1)
    if GetCVar("IgnorePatcherLanguageSetting") == "1" then EsoTH.savedVars["ignorePatcher"] = true end
  else
    SetCVar("IgnorePatcherLanguageSetting", 0)
  end
end

local function LoadscreenLoaded()
  if EsoTH.savedVars["addonVer"] ~= EsoTH.version then
    EsoTH.savedVars["addonVer"] = EsoTH.version
  end
end

local function onAddonLoaded(eventCode, addonName)
  if (addonName ~= EsoTH.name) then
    return
  end
  EVENT_MANAGER:UnregisterForEvent(EsoTH.name, EVENT_ADD_ON_LOADED)
  EsoTH:newInit()
  EsoTHInit()
end

EVENT_MANAGER:RegisterForEvent(EsoTH.name, EVENT_ADD_ON_LOADED, onAddonLoaded)
EVENT_MANAGER:RegisterForEvent("EsoTH_LoadScreen", EVENT_PLAYER_ACTIVATED, loadscreen)
CALLBACK_MANAGER:RegisterCallback("loadscreen", LoadscreenLoaded)

