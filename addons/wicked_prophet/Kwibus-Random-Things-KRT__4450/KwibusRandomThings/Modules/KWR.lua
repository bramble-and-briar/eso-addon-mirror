KwibusRandomThings = KwibusRandomThings or {}
local KRT = KwibusRandomThings
local EM = EVENT_MANAGER
local WM = WINDOW_MANAGER
local ADDON_NAME = KRT.name

local IsNonEmptyString = KRT.IsNonEmptyString
local RGBToHex = KRT.RGBToHex

-- Module-local defaults wrapper
local DEFAULTS = { kwr = {
    enabled = true,
    showCSA = true,
    showChat = true,
    color = { r = 0.043, g = 1.0, b = 1.0 },
    posX = 0,
    posY = 200,
    lifespanMs = 5000,
    keepVisible = false,
    textScale = 1.0,
  } }

KRT.KWR = {
  id = "kwr",
  defaults = DEFAULTS.kwr,
  DIFF_NORMAL = 1,
  DIFF_VETERAN = 2,

  initialized = false,
  deactivated = false,
  trialDiff = 1,

  COOLDOWN_MS = 2000,
  cooldownTimerId = nil,

  pendingMsg = nil,

  ui = { tlw = nil, label = nil, hideNonce = 0, lastMessage = nil, pad = 12 },
}

function KRT.KWR:SV() return KRT.GetModuleSV(self.id, self.defaults) end

function KRT.KWR:SeedDifficultyFromGame()
  local eff = ZO_GetEffectiveDungeonDifficulty()
  self.trialDiff = (eff == DUNGEON_DIFFICULTY_VETERAN) and self.DIFF_VETERAN or self.DIFF_NORMAL
end

function KRT.KWR:DiffToColored(diff)
  return (diff == self.DIFF_VETERAN) and "|c00FF00Veteran|r" or "|cFF0000Normal|r"
end

function KRT.KWR:HideBigNow()
  local tlw = self.ui.tlw
  if tlw and not tlw:IsHidden() then tlw:SetHidden(true) end
end

function KRT.KWR:ApplyOverlayPosition()
  local tlw = self.ui.tlw
  if not tlw then return end
  local sv = self:SV()
  if not sv then return end
  tlw:ClearAnchors()
  tlw:SetAnchor(CENTER, GuiRoot, CENTER, sv.posX or 0, sv.posY or DEFAULTS.kwr.posY)
end

function KRT.KWR:ApplyTextScale()
  local label = self.ui.label
  if not label then return end
  local sv = self:SV()
  if not sv then return end
  label:SetScale(zo_clamp(tonumber(sv.textScale) or 1.0, 0.5, 2.0))
end

function KRT.KWR:SizeTLWToText()
  local tlw, label = self.ui.tlw, self.ui.label
  if not (tlw and label) then return end
  local sv = self:SV()
  if not sv then return end

  local scale = zo_clamp(tonumber(sv.textScale) or 1.0, 0.5, 2.0)
  KRT.ResizeTextHitbox("KWR_Size", tlw, label, scale, 120, 40)
end

function KRT.KWR:EnsureOverlay()
  if self.ui.tlw and self.ui.label then return end

  local tlw = WM:CreateTopLevelWindow("KwibusReset_BigTLW")
  tlw:SetMouseEnabled(false)
  tlw:SetMovable(true)
  tlw:SetClampedToScreen(true)
  tlw:SetResizeHandleSize(0)
  tlw:SetDrawTier(DT_HIGH)
  tlw:SetDrawLayer(DL_OVERLAY)
  tlw:SetDrawLevel(999)

  tlw:SetHandler("OnMoveStop", function(selfTlw)
    local cx, cy = selfTlw:GetCenter()
    local rootW, rootH = GuiRoot:GetDimensions()
    local s = KRT.KWR:SV()
    if not s then return end
    s.posX = zo_round(cx - rootW * 0.5)
    s.posY = zo_round(cy - rootH * 0.5)
    KRT.KWR:ApplyOverlayPosition()
  end)

  local label = WM:CreateControl("$(parent)Label", tlw, CT_LABEL)
  label:SetFont("ZoFontAnnounceLarge")
  label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
  label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  label:SetMouseEnabled(true)
  label:ClearAnchors()
  label:SetAnchor(CENTER, tlw, CENTER, 0, 0)
  label:SetHandler("OnMouseDown", function() tlw:StartMoving() end)
  label:SetHandler("OnMouseUp", function() tlw:StopMovingOrResizing() end)

  tlw:SetDimensions(120, 40)

  self.ui.tlw, self.ui.label = tlw, label
  self:ApplyTextScale()
  self:ApplyOverlayPosition()
  tlw:SetHidden(true)
end

function KRT.KWR:ShowBigMovable(textNoOuterColor)
  local sv = self:SV()
  if not (sv and sv.enabled and sv.showCSA and IsNonEmptyString(textNoOuterColor)) then
    self:HideBigNow()
    return
  end

  self:EnsureOverlay()
  local scale = zo_clamp(tonumber(sv.textScale) or 1.0, 0.5, 2.0)
  self.ui.label:SetScale(scale)

  local c = sv.color or DEFAULTS.kwr.color
  self.ui.label:SetText(RGBToHex(c.r, c.g, c.b) .. textNoOuterColor .. "|r")

  KRT.ResizeTextHitbox("KWR_Size", self.ui.tlw, self.ui.label, scale, 120, 40)

  self.ui.tlw:SetHidden(false)

  self.ui.hideNonce = (self.ui.hideNonce or 0) + 1
  local myNonce = self.ui.hideNonce
  if not sv.keepVisible then
    zo_callLater(function()
      local sv2 = self:SV()
      if myNonce == self.ui.hideNonce and sv2 and sv2.enabled and sv2.showCSA and not sv2.keepVisible then
        self:HideBigNow()
      end
    end, sv.lifespanMs or 5000)
  end
end

function KRT.KWR:BuildMessageText(diffText)
  return zo_strformat("Instance reset. Difficulty: <<1>> – charge ult", diffText)
end

function KRT.KWR:ShowNotification(textNoOuterColor)
  local sv = self:SV()
  if not (sv and sv.enabled and IsNonEmptyString(textNoOuterColor)) then return end

  self.ui.lastMessage = textNoOuterColor

  if sv.showCSA then self:ShowBigMovable(textNoOuterColor) else self:HideBigNow() end

  if sv.showChat and CHAT_SYSTEM then
    local c = sv.color or DEFAULTS.kwr.color
    CHAT_SYSTEM:AddMessage(RGBToHex(c.r, c.g, c.b) .. textNoOuterColor .. "|r")
  end
end

function KRT.KWR:ArmCooldown(messageNoOuterColor)
  self.pendingMsg = messageNoOuterColor
  if self.cooldownTimerId then
    zo_removeCallLater(self.cooldownTimerId)
    self.cooldownTimerId = nil
  end
  self.cooldownTimerId = zo_callLater(function()
    self.cooldownTimerId = nil
    if self.pendingMsg then
      local msg = self.pendingMsg
      self.pendingMsg = nil
      self:ShowNotification(msg)
    end
  end, self.COOLDOWN_MS)
end

function KRT.KWR:QueueResetMessage(newDiff)
  self:ArmCooldown(self:BuildMessageText(self:DiffToColored(newDiff)))
end

function KRT.KWR:CancelPending()
  if self.cooldownTimerId then
    zo_removeCallLater(self.cooldownTimerId)
    self.cooldownTimerId = nil
  end
  self.pendingMsg = nil
end

function KRT.KWR:UpdateDifficulty(newDiff)
  local sv = self:SV()
  if not (sv and sv.enabled) then
    self.trialDiff = newDiff
    return
  end
  if not self.initialized then self.trialDiff = newDiff; return end
  if newDiff == self.trialDiff then return end
  self.trialDiff = newDiff
  if not self.deactivated then self:QueueResetMessage(newDiff) end
end

function KRT.KWR:OnPlayerActivated()
  self:SeedDifficultyFromGame()
  self.deactivated = false
  self:CancelPending()

  local sv = self:SV()
  if not (sv and sv.enabled) then
    self:HideBigNow()
    return
  end

  if not self.initialized then
    self:EnsureOverlay()
    self:ApplyTextScale()
    self:ApplyOverlayPosition()
    self.initialized = true
  end

  if sv.showCSA and sv.keepVisible then
    self:ShowBigMovable(self.ui.lastMessage or "Reset notification will appear here")
  else
    self:HideBigNow()
  end
end

function KRT.KWR:OnDeactivated() self.deactivated = true end

function KRT.KWR:Initialize()
  self:SeedDifficultyFromGame()
  self:EnsureOverlay()
  self:ApplyTextScale()
  self:ApplyOverlayPosition()
  self.initialized = true

  EM:RegisterForEvent(ADDON_NAME .. "_KWR_Deactivated", EVENT_PLAYER_DEACTIVATED, function() self:OnDeactivated() end)

  EM:RegisterForEvent(ADDON_NAME .. "_KWR_Vet1", EVENT_VETERAN_DIFFICULTY_CHANGED, function(_, _, isDifficult)
    self:UpdateDifficulty(isDifficult and self.DIFF_VETERAN or self.DIFF_NORMAL)
  end)

  EM:RegisterForEvent(ADDON_NAME .. "_KWR_Vet2", EVENT_GROUP_VETERAN_DIFFICULTY_CHANGED, function(_, isVeteranDifficulty)
    self:UpdateDifficulty(isVeteranDifficulty and self.DIFF_VETERAN or self.DIFF_NORMAL)
  end)

  EM:RegisterForEvent(ADDON_NAME .. "_KWR_Joined", EVENT_GROUP_MEMBER_JOINED, function(_, _, _, isPlayer)
    if isPlayer then self:SeedDifficultyFromGame() end
  end)

  EM:RegisterForEvent(ADDON_NAME .. "_KWR_Left", EVENT_GROUP_MEMBER_LEFT, function(_, _, _, isLocalPlayer)
    if isLocalPlayer then self:SeedDifficultyFromGame() end
  end)

  EM:RegisterForEvent(ADDON_NAME .. "_KWR_Activated", EVENT_PLAYER_ACTIVATED, function()
    self:OnPlayerActivated()
  end)
end

-- =========================================================

local function SV() return KRT.KWR:SV() end

function KRT.KWR:GetLAMSubmenu()
    return {
      type = "submenu",
      name = "Kwibus Reset",
      controls = {
        {
          type = "checkbox",
          name = "Enable Module",
          getFunc = function() return SV().enabled end,
          setFunc = function(v)
            SV().enabled = v
            if not v then
              KRT.KWR:CancelPending()
              KRT.KWR:HideBigNow()
            end
          end,
          width = "full",
        },
        {
          type = "checkbox",
          name = "Enable On-Screen Notification",
          getFunc = function() return SV().showCSA end,
          setFunc = function(v) SV().showCSA = v; if not v then KRT.KWR:HideBigNow() end end,
          width = "full",
          disabled = function() return not SV().enabled end,
        },
        {
          type = "checkbox",
          name = "Enable Chat Notifications",
          getFunc = function() return SV().showChat end,
          setFunc = function(v) SV().showChat = v end,
          width = "full",
          disabled = function() return not SV().enabled end,
        },
        {
          type = "checkbox",
          name = "Enable Repositioning (Drag)",
          tooltip = "Keeps the notification on screen so it can be dragged to a new position.",
          getFunc = function() return SV().keepVisible end,
          setFunc = function(v)
            SV().keepVisible = v
            KRT.KWR:EnsureOverlay()
            if v and SV().showCSA then
              KRT.KWR:ShowBigMovable(KRT.KWR.ui.lastMessage or "Reset notification will appear here")
            else
              KRT.KWR:HideBigNow()
            end
          end,
          width = "full",
          disabled = function() return not SV().enabled end,
        },
        {
          type = "button",
          name = "Reset Horizontal Position",
          func = function() SV().posX = 0; KRT.KWR:ApplyOverlayPosition() end,
          width = "half",
          disabled = function() return not SV().enabled or not SV().keepVisible end,
        },
        {
          type = "button",
          name = "Reset Vertical Position",
          func = function() SV().posY = DEFAULTS.kwr.posY; KRT.KWR:ApplyOverlayPosition() end,
          width = "half",
          disabled = function() return not SV().enabled or not SV().keepVisible end,
        },
        {
          type = "colorpicker",
          name = "Notification Color",
          getFunc = function()
            local c = SV().color
            return c.r, c.g, c.b
          end,
          setFunc = function(r, g, b)
            local c = SV().color
            c.r, c.g, c.b = r, g, b
            if SV().keepVisible and SV().showCSA then
              KRT.KWR:ShowBigMovable(KRT.KWR.ui.lastMessage or "Reset notification will appear here")
            end
          end,
          width = "full",
          disabled = function() return not SV().enabled end,
        },
        {
          type = "slider",
          name = "Text Scale (%)",
          min = 50,
          max = 200,
          step = 5,
          getFunc = function() return math.floor((SV().textScale or 1.0) * 100 + 0.5) end,
          setFunc = function(v)
            SV().textScale = zo_clamp((tonumber(v) or 100) / 100, 0.5, 2.0)
            KRT.KWR:EnsureOverlay()
            KRT.KWR:ApplyTextScale()
          end,
          width = "full",
          disabled = function() return not SV().enabled end,
        },
        {
          type = "slider",
          name = "Duration (Seconds)",
          min = 1,
          max = 10,
          step = 1,
          getFunc = function() return math.floor((SV().lifespanMs or 5000) / 1000) end,
          setFunc = function(v) SV().lifespanMs = v * 1000 end,
          width = "full",
          disabled = function() return not SV().enabled end,
        },
      },
    }
end

KRT:RegisterModule(KRT.KWR)
