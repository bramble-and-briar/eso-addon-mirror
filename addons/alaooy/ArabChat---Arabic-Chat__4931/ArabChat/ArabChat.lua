-- ArabChat v1.0.5: Arabic typing + correct display in ESO chat. Works on its own:
-- the game can stay in English, no translation addon is needed.
-- Typing : Latin keys -> Arabic letters (Arabic 101 layout) while Arabic mode is ON.
-- Display: ESO draws text left-to-right only, so incoming/outgoing chat text is joined
--          and re-ordered by arabic.lua ("visual" mode, ON by default for everyone).
-- Font   : the chat font is switched to the Arabic font in fonts/ (skipped if EsoAR is installed).
-- Diagnostics: "/arabic status", "/arabic debug", "/arabic test".

ArabChat = ArabChat or {}
local AC = ArabChat
AC.name = "ArabChat"
AC.version = "1.2.2"
AC.arabic = false -- keyboard mode (used when EsoAR is not installed)
AC.debug = false
AC.hooks = {}
AC.defaults = { shapeChat = true, preview = true, width = 0, chatMode = "visual", previewMode = "visual",
                font = true, fontSize = 18, fontKey = "noto" }
AC.sv = AC.defaults

local KEYMAP = {
  ["`"] = "ذ", ["q"] = "ض", ["w"] = "ص", ["e"] = "ث", ["r"] = "ق", ["t"] = "ف",
  ["y"] = "غ", ["u"] = "ع", ["i"] = "ه", ["o"] = "خ", ["p"] = "ح", ["["] = "ج", ["]"] = "د",
  ["a"] = "ش", ["s"] = "س", ["d"] = "ي", ["f"] = "ب", ["g"] = "ل", ["h"] = "ا", ["j"] = "ت",
  ["k"] = "ن", ["l"] = "م", [";"] = "ك", ["'"] = "ط",
  ["z"] = "ئ", ["x"] = "ء", ["c"] = "ؤ", ["v"] = "ر", ["b"] = "لا", ["n"] = "ى", ["m"] = "ة",
  [","] = "و", ["."] = "ز", ["/"] = "ظ", ["?"] = "؟",
  ["T"] = "لإ", ["Y"] = "إ", ["G"] = "لأ", ["H"] = "أ", ["B"] = "لآ", ["N"] = "آ",
  ["J"] = "ـ", ["K"] = "،", ["P"] = "؛", ["M"] = "’",
}

local function say(msg)
  if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
    CHAT_ROUTER:AddSystemMessage("|c9fd8ffArabChat:|r " .. msg)
  else
    d("ArabChat: " .. msg)
  end
end

-- If EsoAR is installed, share its keyboard flag so its keybinding keeps working.
local function isArabic()
  if EsoAR ~= nil and type(langKeyboard) == "string" then return langKeyboard == "ar" end
  return AC.arabic
end

local function setArabic(on)
  AC.arabic = on and true or false
  if EsoAR ~= nil then langKeyboard = on and "ar" or "en" end
end

function ArabChat_Toggle()
  setArabic(not isArabic())
  say(isArabic() and "Arabic keyboard ON" or "Arabic keyboard OFF")
end

-------------------------------------------------------------------------------
-- Who converts the typed keys?
--   * EsoAR not installed        -> this addon does it.
--   * EsoAR installed (default)  -> EsoAR does it; this addon stays out of the way.
--   * "/arabic own on"           -> this addon does it and EsoAR's converter is muted.
-------------------------------------------------------------------------------
local function ownTypingOn()
  if AC.sv.own ~= nil then return AC.sv.own end
  return EsoAR == nil
end

local origConvert, captured = nil, false
local function applyEsoAR()
  if EsoAR == nil then return end
  if not captured then
    origConvert = EsoAR.Convert
    captured = true
  end
  if ownTypingOn() then
    EsoAR.Convert = function() end
  else
    EsoAR.Convert = origConvert
  end
end

-------------------------------------------------------------------------------
-- Arabic font for the chat (only when EsoAR is not installed: EsoAR sets its own fonts)
-------------------------------------------------------------------------------
local FONT_DIR = "ArabChat/fonts/"
local MIN_SIZE, MAX_SIZE, DEFAULT_SIZE = 10, 40, 18
-- Fonts offered in the settings window. Add a font here only after its .slug file is inside
-- the fonts folder AND its license text (for example OFL.txt) is shipped with the addon.
local FONTS = {
  { key = "noto", label = "Noto Naskh Arabic", file = "NotoNaskhArabic.slug" },
  { key = "tajawal", label = "Alternative (game fallback)", file = "Tajawal-Regular.ttf" },
}
local CHAT_FONTS = { ZoFontChat = "soft-shadow-thin", ZoFontEditChat = "shadow" }

local function currentFontFile()
  if AC.testFile then return AC.testFile end -- "/arabic fonttest <file>" (not saved)
  for _, f in ipairs(FONTS) do
    if f.key == AC.sv.fontKey then return f.file end
  end
  return FONTS[1].file
end

local function fontString(style, size)
  return FONT_DIR .. currentFontFile() .. "|" .. (size or AC.sv.fontSize or DEFAULT_SIZE) .. "|" .. style
end

-- Returns a short report so "/arabic status" and "/arabic fonttest" can show what worked.
local function applyChatFont()
  if EsoAR ~= nil or not AC.sv.font then
    AC.lastFontReport = "skipped"
    return AC.lastFontReport
  end
  local objOk, bufOk, editOk = 0, 0, "no"
  -- 1) the named game fonts
  for name, style in pairs(CHAT_FONTS) do
    local obj = _G[name]
    if obj and pcall(function() obj:SetFont(fontString(style)) end) then objOk = objOk + 1 end
  end
  -- 2) the real chat windows (they may keep their own font, not the named one)
  if CHAT_SYSTEM and CHAT_SYSTEM.containers then
    for _, container in pairs(CHAT_SYSTEM.containers) do
      for _, window in pairs(container.windows or {}) do
        if window.buffer and pcall(function() window.buffer:SetFont(fontString("soft-shadow-thin")) end) then
          bufOk = bufOk + 1
        end
      end
    end
  end
  -- 3) the typing box
  local edit = CHAT_SYSTEM and CHAT_SYSTEM.textEntry and CHAT_SYSTEM.textEntry.editControl
  if edit and pcall(function() edit:SetFont(fontString("shadow")) end) then editOk = "yes" end
  AC.lastFontReport = "objects=" .. objOk .. " windows=" .. bufOk .. " edit=" .. editOk
  return AC.lastFontReport
end

local function previewFont()
  if EsoAR == nil and AC.sv.font then return fontString("soft-shadow-thin") end
  return "ZoFontChat"
end

-------------------------------------------------------------------------------
-- Settings panel: Settings > Add-Ons > ArabChat (needs the LibAddonMenu-2.0 library)
-------------------------------------------------------------------------------
local lamPanel

local function getLAM()
  return LibAddonMenu2 or (LibStub and LibStub("LibAddonMenu-2.0", true))
end

-- "Donate" in the settings header: open the in-game mail with the address and subject filled in
function ArabChat_ComposeDonationMail()
  local subject = "Donation: ArabChat " .. tostring(AC.version)
  local ok = pcall(function()
    if MAIL_SEND and MAIL_SEND.ComposeMailTo then
      SCENE_MANAGER:Show("mailSend")
      MAIL_SEND:ComposeMailTo("@alaooy", subject)
    else
      error("no mail")
    end
  end)
  if not ok then
    d("ArabChat: could not open the mail window. Send gold to @alaooy by mail. Thank you!")
  end
end

local function registerSettingsPanel()
  local LAM = getLAM()
  if not LAM then return false end

  local fontChoices, fontValues = {}, {}
  for _, f in ipairs(FONTS) do
    fontChoices[#fontChoices + 1] = f.label
    fontValues[#fontValues + 1] = f.key
  end

  lamPanel = LAM:RegisterAddonPanel("ArabChatPanel", {
    type = "panel",
    name = "ArabChat",
    displayName = "ArabChat - Arabic Chat",
    author = "@alaooy",
    version = AC.version,
    website = "https://discord.gg/mwSHxSzzU5",
    feedback = "https://discord.gg/mwSHxSzzU5",
    donation = function() ArabChat_ComposeDonationMail() end,
    registerForRefresh = true,
    registerForDefaults = true,
  })

  local options = {}
  if EsoAR ~= nil then
    options[#options + 1] = { type = "description", text = "EsoAR is installed: it controls the chat font, so the font options below have no effect." }
  end
  local more = {
    { type = "header", name = "Chat font" },
    {
      type = "checkbox", name = "Use the Arabic chat font",
      tooltip = "Turning this off brings the original font back after /reloadui.",
      getFunc = function() return AC.sv.font end,
      setFunc = function(v) AC.sv.font = v if v then applyChatFont() end end,
      default = true,
    },
    {
      type = "dropdown", name = "Font",
      choices = fontChoices, choicesValues = fontValues,
      getFunc = function() return AC.sv.fontKey end,
      setFunc = function(v) AC.sv.fontKey = v applyChatFont() end,
      default = FONTS[1].key,
    },
    {
      type = "slider", name = "Font size",
      min = MIN_SIZE, max = MAX_SIZE, step = 1,
      getFunc = function() return AC.sv.fontSize or DEFAULT_SIZE end,
      setFunc = function(v) AC.sv.fontSize = v applyChatFont() end,
      default = DEFAULT_SIZE,
    },
    { type = "header", name = "Chat" },
    {
      type = "checkbox", name = "Show the preview box while typing",
      getFunc = function() return AC.sv.preview end,
      setFunc = function(v) AC.sv.preview = v end,
      default = true,
    },
    {
      type = "checkbox", name = "Join letters and fix direction in chat",
      tooltip = "Turn off only if another chat addon already does this.",
      getFunc = function() return AC.sv.shapeChat end,
      setFunc = function(v) AC.sv.shapeChat = v end,
      default = true,
    },
  }
  for _, o in ipairs(more) do options[#options + 1] = o end
  LAM:RegisterOptionControls("ArabChatPanel", options)
  return true
end

-- "/arabic settings" and the keybinding open the panel
function ArabChat_ToggleSettings()
  local LAM = getLAM()
  if lamPanel and LAM and LAM.OpenToPanel then
    LAM:OpenToPanel(lamPanel)
  else
    say("Open Settings > Add-Ons > ArabChat. (This needs the LibAddonMenu-2.0 library.)")
  end
end

-------------------------------------------------------------------------------
-- Live preview line (what the message will look like in chat)
-------------------------------------------------------------------------------
local preview, previewLabel
local function hidePreview()
  if preview then preview:SetHidden(true) end
end

local function showPreview(anchor, text)
  if not preview then
    preview = WINDOW_MANAGER:CreateTopLevelWindow("ArabChatPreviewWin")
    preview:SetDrawLayer(DL_OVERLAY)
    preview:SetDrawTier(DT_HIGH)
    preview:SetMouseEnabled(false)
    preview:SetHeight(34)
    local bg = WINDOW_MANAGER:CreateControl("ArabChatPreviewBg", preview, CT_BACKDROP)
    bg:SetAnchorFill(preview)
    bg:SetCenterColor(0, 0, 0, 0.6)
    bg:SetEdgeColor(0, 0, 0, 0)
    previewLabel = WINDOW_MANAGER:CreateControl("ArabChatPreviewLabel", preview, CT_LABEL)
    previewLabel:SetAnchorFill(preview)
    previewLabel:SetColor(1, 0.95, 0.65, 1)
    previewLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    previewLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  end
  previewLabel:SetFont(previewFont())
  previewLabel:ClearAnchors()
  previewLabel:SetAnchor(TOPLEFT, preview, TOPLEFT, 8, 0)
  previewLabel:SetAnchor(BOTTOMRIGHT, preview, BOTTOMRIGHT, -8, 0)
  previewLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  previewLabel:SetText(AC.Arabic.process(text, { width = 0, mode = AC.sv.previewMode }))
  local tw = previewLabel:GetTextWidth() or 200
  preview:SetWidth(math.min(math.max(tw + 40, 300), 600))
  preview:ClearAnchors()
  local okA = anchor and anchor.GetLeft and anchor:GetLeft() ~= nil
  if okA then
    preview:SetAnchor(BOTTOMLEFT, anchor, TOPLEFT, 75, -4)
  else
    preview:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT, 40, -240)
  end
  preview:SetHidden(false)
end

local function updatePreview(anchor, text)
  if not AC.sv.preview or not text or text == "" or not AC.Arabic.hasArabic(text) then
    return hidePreview()
  end
  local ok, err = pcall(showPreview, anchor, text)
  AC.previewState = ok and "shown" or ("error: " .. tostring(err))
end

-------------------------------------------------------------------------------
-- Typing: convert the key that was just typed
-------------------------------------------------------------------------------
local lastText, busy = "", false

local function getEdit(control)
  if control and control.GetText and control.SetText then return control end
  if control and control.system and control.system.textEntry then return control.system.textEntry end
  return nil
end

local function onTextChanged(control, src)
  if busy then return end
  local edit = getEdit(control)
  if not edit then
    if AC.debug then say("hook " .. tostring(src) .. ": no edit control (" .. type(control) .. ")") end
    return
  end
  local text = edit:GetText() or ""
  local prev = lastText
  lastText = text

  local converted = false
  if ownTypingOn() and isArabic() and #text == #prev + 1 and text:sub(1, #prev) == prev then
    local mapped = KEYMAP[text:sub(-1)]
    -- don't touch the slash command itself ("/w", "/g", "/zone" ...)
    local typingCommand = (text:sub(1, 1) == "/" and not text:find(" ")) or text:lower():sub(1, 7) == "/arabic"
    if mapped and not typingCommand then
      busy = true
      text = prev .. mapped
      edit:SetText(text)
      busy = false
      lastText = text
      converted = true
    end
  end

  if AC.debug then
    say("hook " .. tostring(src) .. " len=" .. #text .. " arabicKb=" .. tostring(isArabic())
      .. " own=" .. tostring(ownTypingOn()) .. " converted=" .. tostring(converted))
  end
  updatePreview(edit, text)
end

local function onEntryClosed()
  lastText = ""
  hidePreview()
end

-- Try every known way to see keystrokes in the chat edit box; report what worked.
local function hookTyping()
  if type(ZO_ChatTextEntry_TextChanged) == "function" then
    local ok = pcall(ZO_PreHook, "ZO_ChatTextEntry_TextChanged", function(control) onTextChanged(control, "global") end)
    AC.hooks[#AC.hooks + 1] = "global=" .. tostring(ok)
  else
    AC.hooks[#AC.hooks + 1] = "global=missing"
  end

  local seen = {}
  local function hookEdit(ctrl, label)
    if not ctrl then
      AC.hooks[#AC.hooks + 1] = label .. "=missing"
      return
    end
    if seen[ctrl] then return end
    seen[ctrl] = true
    local ok = pcall(ZO_PreHookHandler, ctrl, "OnTextChanged", function(self) onTextChanged(self, label) end)
    AC.hooks[#AC.hooks + 1] = label .. "=" .. tostring(ok)
  end
  hookEdit(ZO_ChatWindowTextEntryEditBox, "editbox")
  hookEdit(CHAT_SYSTEM and CHAT_SYSTEM.textEntry and CHAT_SYSTEM.textEntry.editControl, "chatsystem")

  for _, name in ipairs({ "ZO_ChatTextEntry_Execute", "ZO_ChatTextEntry_Escape" }) do
    if type(_G[name]) == "function" then
      pcall(ZO_PreHook, name, function() onEntryClosed() end)
    end
  end
end

-------------------------------------------------------------------------------
-- Display: wrap the chat message formatter (only changes text when shapeChat is on)
-------------------------------------------------------------------------------
local function installChatHandler()
  if AC.installed then return true end
  if not ZO_ChatSystem_GetEventHandlers then return false end
  local handlers = ZO_ChatSystem_GetEventHandlers()
  local orig = handlers and handlers[EVENT_CHAT_MESSAGE_CHANNEL]
  if not orig then return false end

  handlers[EVENT_CHAT_MESSAGE_CHANNEL] = function(...)
    local n = select("#", ...)
    local args = { ... }
    if AC.sv.shapeChat and AC.sv.chatMode ~= "raw" then
      local idx = (type(args[2]) == "number") and 4 or 3 -- text argument
      if type(args[idx]) == "string" then
        local ok, res = pcall(AC.Arabic.process, args[idx], { width = AC.sv.width, mode = AC.sv.chatMode })
        if ok and type(res) == "string" then args[idx] = res end
      end
    end
    return orig(unpack(args, 1, n))
  end
  AC.installed = true
  return true
end

-------------------------------------------------------------------------------
-- Slash command
-------------------------------------------------------------------------------
local function onOff(word, current)
  if word == "on" then return true elseif word == "off" then return false end
  return not current
end

SLASH_COMMANDS["/arabic"] = function(arg)
  local cmd, rest = (arg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = (cmd or ""):lower()
  if cmd == "" then
    ArabChat_Toggle()
  elseif cmd == "on" then setArabic(true) say("Arabic keyboard ON")
  elseif cmd == "off" then setArabic(false) say("Arabic keyboard OFF")
  elseif cmd == "status" then
    say("v" .. AC.version .. " EsoAR=" .. tostring(EsoAR ~= nil) .. " keyboard=" .. (isArabic() and "ar" or "en")
      .. " ownTyping=" .. tostring(ownTypingOn()))
    say("hooks: " .. (#AC.hooks > 0 and table.concat(AC.hooks, ", ") or "none yet"))
    say("shape=" .. tostring(AC.sv.shapeChat) .. " chatMode=" .. tostring(AC.sv.chatMode)
      .. " previewMode=" .. tostring(AC.sv.previewMode) .. " preview=" .. tostring(AC.sv.preview)
      .. " font=" .. tostring(AC.sv.font) .. "/" .. tostring(AC.sv.fontSize))
    say("font report: " .. tostring(AC.lastFontReport))
    say("preview state: " .. tostring(AC.previewState))
  elseif cmd == "previewtest" then
    local ok, err = pcall(showPreview, nil, "x")
    pcall(function()
      preview:ClearAnchors()
      preview:SetAnchor(CENTER, GuiRoot, CENTER, 0, -200)
      preview:SetWidth(600)
      previewLabel:SetText(AC.Arabic.process("\216\167\216\168\216\172 \216\167\216\168\216\172", { width = 0, mode = AC.sv.previewMode }))
      preview:SetHidden(false)
    end)
    say("previewtest: " .. (ok and "ok" or tostring(err)) .. " hidden=" .. tostring(preview and preview:IsHidden())
      .. " size=" .. tostring(preview and preview:GetWidth()) .. "x" .. tostring(preview and preview:GetHeight())
      .. " len=" .. tostring(previewLabel and #previewLabel:GetText()))
    zo_callLater(hidePreview, 20000)
  elseif cmd == "debug" then
    AC.debug = onOff(rest:lower(), AC.debug)
    say("debug " .. (AC.debug and "on (type a letter in chat)" or "off"))
  elseif cmd == "own" then
    AC.sv.own = onOff(rest:lower(), ownTypingOn())
    applyEsoAR()
    say("own typing converter " .. (AC.sv.own and "ON (EsoAR converter muted)" or "OFF (EsoAR converts)"))
  elseif cmd == "font" then
    AC.sv.font = onOff(rest:lower(), AC.sv.font)
    if AC.sv.font then applyChatFont() end
    say("Arabic chat font " .. (AC.sv.font and "on" or "off (type /reloadui to get the original font back)"))
  elseif cmd == "settings" then
    ArabChat_ToggleSettings()
  elseif cmd == "fonttest" then
    -- "/arabic fonttest" shows a big test word. "/arabic fonttest <file>" tries another font
    -- file from the fonts folder (for testing only, not saved). "/arabic fonttest reset" undoes it.
    if rest == "" or rest:lower() == "reset" then AC.testFile = nil else AC.testFile = rest end
    say("font file in use: " .. currentFontFile())
    say("font apply: " .. tostring(applyChatFont()))
    pcall(function()
      if not AC.fontTest then
        AC.fontTest = WINDOW_MANAGER:CreateControl("ArabChatFontTest", GuiRoot, CT_LABEL)
        AC.fontTest:SetColor(1, 1, 0.6, 1)
        AC.fontTest:SetDrawLayer(DL_OVERLAY)
        AC.fontTest:SetDrawTier(DT_HIGH)
        AC.fontTest:SetAnchor(CENTER, GuiRoot, CENTER, 0, -150)
      end
      AC.fontTest:SetFont(fontString("soft-shadow-thick", 36))
      AC.fontTest:SetText(AC.Arabic.process("مرحبا بكم", { mode = "visual" }))
      AC.fontTest:SetHidden(false)
      zo_callLater(function() AC.fontTest:SetHidden(true) end, 8000)
    end)
    say("a big Arabic test word shows in the middle of the screen for 8 seconds")
  elseif cmd == "fontsize" then
    local n = tonumber(rest)
    if not n then
      say("usage: /arabic fontsize 18   (" .. MIN_SIZE .. " to " .. MAX_SIZE .. ")")
    else
      AC.sv.fontSize = math.max(MIN_SIZE, math.min(MAX_SIZE, math.floor(n)))
      applyChatFont()
      say("font size " .. AC.sv.fontSize)
    end
  elseif cmd == "preview" then
    AC.sv.preview = onOff(rest:lower(), AC.sv.preview)
    if not AC.sv.preview then hidePreview() end
    say("preview " .. (AC.sv.preview and "on" or "off"))
  elseif cmd == "shape" then
    AC.sv.shapeChat = onOff(rest:lower(), AC.sv.shapeChat)
    say("chat shaping " .. (AC.sv.shapeChat and "on" or "off"))
  elseif cmd == "width" then
    local w = tonumber(rest) or 0
    AC.sv.width = math.max(0, math.floor(w))
    say("line width " .. (AC.sv.width == 0 and "off" or AC.sv.width))
  elseif cmd == "chatmode" or cmd == "previewmode" then
    local m = rest:lower()
    if m ~= "visual" and m ~= "logical" and m ~= "raw" then
      say(cmd .. " must be raw, visual or logical")
    else
      if cmd == "chatmode" then AC.sv.chatMode = m else AC.sv.previewMode = m end
      say(cmd .. " = " .. m)
    end
  elseif cmd == "test" then
    local function hexOf(str)
      local out, i = {}, 1
      while i <= #str do
        local by = str:byte(i)
        local size, cp = 1, by
        if by >= 0xE0 then
          size = 3
          cp = (by - 0xE0) * 4096 + ((str:byte(i + 1) or 128) - 128) * 64 + ((str:byte(i + 2) or 128) - 128)
        elseif by >= 0xC0 then
          size = 2
          cp = (by - 0xC0) * 64 + ((str:byte(i + 1) or 128) - 128)
        end
        out[#out + 1] = string.format("%04X", cp)
        i = i + size
      end
      return table.concat(out, " ")
    end
    local P = AC.Arabic.process
    say("test v" .. AC.version .. " / arabic.lua v" .. tostring(AC.Arabic.version)
      .. " / chatMode=" .. tostring(AC.sv.chatMode))
    local probe = "مرحبا"
    local out = P(probe, { mode = "logical" })
    say("diag: bytes=" .. #probe .. " find=" .. tostring(string.find(probe, "[\216-\219]"))
      .. " scan=" .. tostring(AC.Arabic.hasArabic(probe)) .. " changed=" .. tostring(out ~= probe)
      .. " reason=" .. tostring(AC.Arabic.lastReason))
    -- what the Lua code really produced (codes, independent of how the game draws them)
    say("code L: " .. hexOf(out))
    say("code V: " .. hexOf(P(probe, { mode = "visual" })))
    -- how the game draws different forms (correct = reads right-to-left: مرحبا بكم)
    say("1 raw: A مرحبا بكم B")
    say("2 L: " .. P("A مرحبا بكم B", { mode = "logical" }))
    say("3 V: " .. P("A مرحبا بكم B", { mode = "visual" }))
    say("4 L: " .. P("مرحبا بكم في Elder Scrolls Online", { mode = "logical" }))
    say("5 V: " .. P("مرحبا بكم في Elder Scrolls Online", { mode = "visual" }))
  else
    say("/arabic [on/off] / status / previewtest / debug / own [on/off]  test  settings  font [on/off]  fontsize N  fonttest [file]  preview [on/off]  shape [on/off]  chatmode raw/visual/logical  previewmode raw/visual/logical  width N")
  end
end

-------------------------------------------------------------------------------
-- Init
-------------------------------------------------------------------------------
local function onAddonLoaded(_, addonName)
  if addonName ~= AC.name then return end
  EVENT_MANAGER:UnregisterForEvent(AC.name, EVENT_ADD_ON_LOADED)
  -- version 3: resets settings saved by older test builds so everyone starts from the defaults
  AC.sv = ZO_SavedVars:NewAccountWide("ArabChat_Variables", 3, nil, AC.defaults)
  AC.sv.chatMode = AC.sv.chatMode or "visual"
  AC.sv.previewMode = AC.sv.previewMode or "visual"
  AC.sv.fontKey = AC.sv.fontKey or FONTS[1].key
  AC.sv.fontSize = AC.sv.fontSize or DEFAULT_SIZE

  ZO_CreateStringId("SI_BINDING_NAME_ARABCHAT_TOGGLE", "Toggle Arabic keyboard (ArabChat)")
  ZO_CreateStringId("SI_BINDING_NAME_ARABCHAT_SETTINGS", "Open settings (ArabChat)")
  local ok, err = pcall(registerSettingsPanel)
  if not ok then AC.panelError = tostring(err) end

  applyEsoAR()
end

local warned = false
local function onPlayerActivated()
  -- standalone: use the Arabic font shipped with this addon (idempotent, safe to repeat)
  applyChatFont()
  -- everything in the base UI exists by now: hook typing once
  if not AC.typingHooked then
    AC.typingHooked = true
    hookTyping()
  end
  -- install after other chat addons so we wrap on top of their formatter
  if installChatHandler() then
    EVENT_MANAGER:UnregisterForEvent(AC.name .. "_Activated", EVENT_PLAYER_ACTIVATED)
  elseif not warned then
    warned = true
    say("could not hook the chat formatter; incoming messages will not be shaped.")
  end
end

EVENT_MANAGER:RegisterForEvent(AC.name, EVENT_ADD_ON_LOADED, onAddonLoaded)
EVENT_MANAGER:RegisterForEvent(AC.name .. "_Activated", EVENT_PLAYER_ACTIVATED, onPlayerActivated)
EVENT_MANAGER:RegisterForEvent(AC.name .. "_Font", EVENT_PLAYER_ACTIVATED, function() applyChatFont() end)
