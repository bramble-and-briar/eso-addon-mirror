-- Jesus de Platre: optional in-game gold donation helper.
-- Never queues gold or sends mail; the player always chooses and confirms.
local ADDON = "JesusDePlatre_PrivateMarker"
local RECIPIENT = "@Evokation"
local popup
local function say(message)
  d("|c66CCFF[JDP Donate]|r " .. message)
end

local function createText(parent, text, font, x, y, w, h, r, g, b)
  local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
  label:SetFont(font)
  label:SetDimensions(w, h)
  label:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
  label:SetText(text)
  label:SetColor(r or 1, g or 1, b or 1, 1)
  return label
end

local function createClickLabel(parent, text, x, y, w, h, callback)
  local label = createText(parent, text, "ZoFontGameBold", x, y, w, h, 0.45, 0.89, 1)
  label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
  label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  label:SetMouseEnabled(true)
  label:SetHandler("OnMouseUp", function(_, button)
    if button == MOUSE_BUTTON_INDEX_LEFT then callback() end
  end)
  return label
end

local function openDonationMail()
  -- ComposeMailTo is an ESO UI helper. If another UI replaces mail,
  -- do not attempt an automatic transfer or send.
  if MAIL_SEND and type(MAIL_SEND.ComposeMailTo) == "function" then
    popup:SetHidden(true)
    local ok, err = pcall(function() MAIL_SEND:ComposeMailTo(RECIPIENT) end)
    if ok then
      say("Mail recipient: " .. RECIPIENT .. ". Attach any gold amount you choose, review, and manually press Send.")
      return
    end
    say("Could not open the mail composer: " .. tostring(err))
  else
    say("Mail composer unavailable. Open Social > Mail > Send and enter " .. RECIPIENT .. ".")
  end
end

local function createPopup()
  local wm = WINDOW_MANAGER
  popup = wm:CreateTopLevelWindow("JDPDonationPopup")
  popup:SetDimensions(430, 183)
  popup:SetAnchor(CENTER, GuiRoot, CENTER, 0, -80)
  popup:SetClampedToScreen(true)
  popup:SetDrawLayer(DL_OVERLAY)
  popup:SetDrawTier(DT_HIGH)
  popup:SetMouseEnabled(true)
  popup:SetHidden(true)

  local bg = wm:CreateControl(nil, popup, CT_BACKDROP)
  bg:SetAnchorFill(popup)
  bg:SetCenterColor(0.02, 0.04, 0.07, 0.97)
  bg:SetEdgeColor(0.12, 0.6, 0.75, 1)
  createText(popup, "SUPPORT JESUS DE PLATRE", "ZoFontGameBold", 16, 12, 375, 26, 0.60, 0.95, 1)
  createText(popup, "Optional in-game gold donation to " .. RECIPIENT, "ZoFontGame", 16, 42, 404, 26, 1, 1, 1)
  createText(popup, "Choose your amount in ESO Mail. Nothing is sent automatically.", "ZoFontGame", 16, 68, 404, 40, 0.75, 0.83, 0.87)
  createClickLabel(popup, "OPEN MAIL TO " .. RECIPIENT, 15, 125, 290, 35, openDonationMail)
  createClickLabel(popup, "CLOSE", 320, 125, 90, 35, function() popup:SetHidden(true) end)
end

local function showPopup()
  if not popup then return end
  popup:SetHidden(false)
  say("Optional donation: " .. RECIPIENT .. ". Use your mouse cursor to select OPEN MAIL.")
end

local function onLoaded(_, name)
  if name ~= ADDON then return end
  EVENT_MANAGER:UnregisterForEvent("JDPDonateLoad", EVENT_ADD_ON_LOADED)
  createPopup()
  -- Also called by the Donate link in the multi-taunt panel.
  JDPDonateShow = showPopup
  SLASH_COMMANDS["/jdpdonate"] = showPopup
end
EVENT_MANAGER:RegisterForEvent("JDPDonateLoad", EVENT_ADD_ON_LOADED, onLoaded)
