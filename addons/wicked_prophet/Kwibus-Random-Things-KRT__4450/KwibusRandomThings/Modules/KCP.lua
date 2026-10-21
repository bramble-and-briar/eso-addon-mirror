KwibusRandomThings = KwibusRandomThings or {}
local KRT = KwibusRandomThings
local EM = EVENT_MANAGER
local WM = WINDOW_MANAGER
local ADDON_NAME = KRT.name

local IsNonEmptyString = KRT.IsNonEmptyString

local DEFAULTS = { kcp = {
    enabled = true,
    text = "BRITTLE MISSING!",
    offsetX = 0,
    offsetY = 100,
    fontScale = 1.0,
    enableReposition = false,
  } }

KRT.KCP = {
  id = "kcp",
  defaults = DEFAULTS.kcp,
  SKILL_ID = 183267,
  DEBUFF_ID = 145975,

  ui = nil,
  lbl = nil,

  _slotted = false,
  _hasDebuff = false,
  _hasDebuffAtMs = 0,
}

local BARS_TO_CHECK = { 0, 1 } -- PERFORMANCE FIX

function KRT.KCP:SV() return KRT.GetModuleSV(self.id, self.defaults) end

function KRT.KCP:EnsureOverlay()
  if self.ui then return end
  local sv = self:SV()
  if not sv then return end

  local win = WM:CreateTopLevelWindow("KwibusColorlessPool_UI")
  win:SetDimensions(120, 40)
  win:SetHidden(true)
  win:SetMouseEnabled(false)
  win:SetMovable(false)
  win:SetClampedToScreen(true)
  win:SetDrawLayer(DL_OVERLAY)
  win:SetDrawTier(DT_HIGH)
  win:SetDrawLevel(9999)

  local label = WM:CreateControl("KwibusColorlessPool_Lbl", win, CT_LABEL)
  label:SetAnchor(CENTER, win, CENTER, 0, 0)
  label:SetFont("ZoFontCallout")
  label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
  label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  label:SetColor(1, 0, 0, 1)

  self.ui = win
  self.lbl = label

  self:ApplyAnchor()
  self:UpdateTextAndScale()
end

function KRT.KCP:UpdateTextAndScale()
  local win, label = self.ui, self.lbl
  if not (win and label) then return end
  local sv = self:SV()
  if not sv then return end

  local scale = sv.fontScale or 1.0
  local text = sv.text or DEFAULTS.kcp.text
  label:SetText(text)
  label:SetScale(scale)

  KRT.ResizeTextHitbox("KCP_Resize", win, label, scale, 60, 30)
end

function KRT.KCP:ApplyAnchor()
  KRT.ApplyCenterAnchor(self.ui, self:SV(), DEFAULTS.kcp.offsetY)
end

function KRT.KCP:EnableDragging(enable)
  local sv = self:SV()
  KRT.EnableDragging(self.ui, self.lbl, sv, enable, function() self:ApplyAnchor() end, function() self:OnCombatUpdate() end)
end

function KRT.KCP:_ComputeIsSkillSlotted()
  for _, bar in ipairs(BARS_TO_CHECK) do
    for slot = 3, 8 do
      if GetSlotBoundId(slot, bar) == self.SKILL_ID then return true end
    end
  end
  return false
end

function KRT.KCP:UpdateSlottedState()
  self._slotted = self:_ComputeIsSkillSlotted()
end

function KRT.KCP:_ComputeHasDebuff()
  for i = 1, GetNumBuffs("reticleover") do
    local _, _, _, _, _, _, _, _, _, _, id = GetUnitBuffInfo("reticleover", i)
    if id == self.DEBUFF_ID then return true end
  end
  return false
end

function KRT.KCP:HasDebuffCached(maxAgeMs)
  local nowMs = GetFrameTimeMilliseconds()
  if (nowMs - (self._hasDebuffAtMs or 0)) > (maxAgeMs or 120) then
    self._hasDebuff = self:_ComputeHasDebuff()
    self._hasDebuffAtMs = nowMs
  end
  return self._hasDebuff
end

function KRT.KCP:OnCombatUpdate()
  local sv = self:SV()
  if not sv then return end

  if not sv.enabled then
    if self.ui then self.ui:SetHidden(true) end
    return
  end

  if sv.enableReposition then
    if self.ui then self.ui:SetHidden(false) end
    return
  end

  if not self._slotted then
    if self.ui then self.ui:SetHidden(true) end
    return
  end

  if not self.ui then return end

  if IsUnitInCombat("player")
      and DoesUnitExist("reticleover")
      and IsUnitAttackable("reticleover")
      and not IsUnitDead("reticleover") then
    self.ui:SetHidden(self:HasDebuffCached(120))
    return
  end

  self.ui:SetHidden(true)
end

function KRT.KCP:Initialize()
  local sv = self:SV()
  if not sv then return end

  self:EnsureOverlay()
  self:ApplyAnchor()
  self:UpdateTextAndScale()
  self:EnableDragging(sv.enableReposition)
  self:UpdateSlottedState()

  EM:RegisterForEvent(ADDON_NAME .. "_KCP_Combat", EVENT_PLAYER_COMBAT_STATE, function()
    local sv2 = self:SV()
    if not (sv2 and sv2.enabled) then return end
    self:OnCombatUpdate()
  end)

  EM:RegisterForEvent(ADDON_NAME .. "_KCP_Target", EVENT_RETICLE_TARGET_CHANGED, function()
    local sv2 = self:SV()
    if not (sv2 and sv2.enabled) then return end
    if not (IsUnitInCombat("player") or sv2.enableReposition) then return end
    self._hasDebuffAtMs = 0
    self:OnCombatUpdate()
  end)

  EM:RegisterForEvent(ADDON_NAME .. "_KCP_Effect", EVENT_EFFECT_CHANGED, function()
    local sv2 = self:SV()
    if not (sv2 and sv2.enabled) then return end
    if not (IsUnitInCombat("player") or sv2.enableReposition) then return end
    self._hasDebuffAtMs = 0
    self:OnCombatUpdate()
  end)
  EM:AddFilterForEvent(ADDON_NAME .. "_KCP_Effect", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "reticleover")
  EM:AddFilterForEvent(ADDON_NAME .. "_KCP_Effect", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, self.DEBUFF_ID)

  EM:RegisterForEvent(ADDON_NAME .. "_KCP_SlotsAll", EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, function()
    self:UpdateSlottedState()
  end)
  EM:RegisterForEvent(ADDON_NAME .. "_KCP_Slot", EVENT_ACTION_SLOT_UPDATED, function()
    self:UpdateSlottedState()
  end)
end

local function SV() return KRT.KCP:SV() end

function KRT.KCP:GetLAMSubmenu()
    return {
      type = "submenu",
      name = "Kwibus Colorless Pool",
      controls = {
        {
          type = "checkbox",
          name = "Enable Module",
          getFunc = function() return SV().enabled end,
          setFunc = function(v)
            SV().enabled = v
            if not v then
              KRT.KCP:EnableDragging(false)
              if KRT.KCP.ui then KRT.KCP.ui:SetHidden(true) end
            else
              KRT.KCP:OnCombatUpdate()
            end
          end,
          width = "full",
        },
        {
          type = "checkbox",
          name = "Enable Repositioning (Drag)",
          tooltip = "Allows you to drag and reposition the reminder overlay.",
          getFunc = function() return SV().enableReposition end,
          setFunc = function(v)
            SV().enableReposition = v
            KRT.KCP:EnableDragging(v)
            KRT.KCP:ApplyAnchor()
          end,
          width = "full",
          disabled = function() return not SV().enabled end,
        },
        {
          type = "button",
          name = "Reset Horizontal Position",
          func = function() SV().offsetX = 0; KRT.KCP:ApplyAnchor() end,
          disabled = function() return not SV().enabled or not SV().enableReposition end,
          width = "half",
        },
        {
          type = "button",
          name = "Reset Vertical Position",
          func = function() SV().offsetY = DEFAULTS.kcp.offsetY; KRT.KCP:ApplyAnchor() end,
          disabled = function() return not SV().enabled or not SV().enableReposition end,
          width = "half",
        },
        {
          type = "editbox",
          name = "Reminder Text",
          isMultiline = false,
          getFunc = function() return SV().text end,
          setFunc = function(v)
            SV().text = IsNonEmptyString(v) and v or DEFAULTS.kcp.text
            KRT.KCP:UpdateTextAndScale()
          end,
          width = "full",
          disabled = function() return not SV().enabled end,
        },
        {
          type = "slider",
          name = "Text Scale",
          min = 0.5,
          max = 3.0,
          step = 0.1,
          getFunc = function() return SV().fontScale end,
          setFunc = function(v) SV().fontScale = v; KRT.KCP:UpdateTextAndScale() end,
          width = "full",
          disabled = function() return not SV().enabled end,
        },
      },
    }
end

KRT:RegisterModule(KRT.KCP)
