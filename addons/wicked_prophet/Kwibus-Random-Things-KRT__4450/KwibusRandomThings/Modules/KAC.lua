KwibusRandomThings = KwibusRandomThings or {}
local KRT = KwibusRandomThings
local ADDON_NAME = KRT.name

-- Module-local defaults wrapper 
local DEFAULTS = { kac = {
    enabled = true,
  } }

KRT.KAC = {
  id = "kac",
  defaults = DEFAULTS.kac,
  autoConfirmHooked = false,
}

function KRT.KAC:SV() return KRT.GetModuleSV(self.id, self.defaults) end

function KRT.KAC:Initialize()
  local sv = self:SV()
  if not sv then return end

  if self.autoConfirmHooked then return end
  self.autoConfirmHooked = true

  local function hook()
    local sv2 = self:SV()
    if not (sv2 and sv2.enabled) then return end

    zo_callLater(function()
      if not (self:SV() and self:SV().enabled) then return end
      if not (ZO_Dialog1 and ZO_Dialog1EditBox and not ZO_Dialog1EditBox:IsHidden()) then return end

      if ZO_Dialog1.textParams and ZO_Dialog1.textParams.mainTextParams then
        for _, v in pairs(ZO_Dialog1.textParams.mainTextParams) do
          -- 1. zo_strupper handles Cyrillic (unlike string.upper)
          -- 2. v ~= zo_strlower ensures it actually contains letters (ignores "123")
          -- 3. not string.find ensures it's a single word (ignores ALL-CAPS multi-word item names)
          if type(v) == "string" and v == zo_strupper(v) and v ~= zo_strlower(v) and not string.find(v, " ") then
            if ZO_Dialog1EditBox.SetText then
              ZO_Dialog1EditBox:SetText(v)
              ZO_Dialog1EditBox:LoseFocus()
              break
            end
          end
        end
      end
    end, 10)
  end

  ZO_PreHook("ZO_Dialogs_ShowDialog", hook)
end

-- =========================================================

local function SV() return KRT.KAC:SV() end

function KRT.KAC:GetLAMSubmenu()
    return {
      type = "submenu",
      name = "Kwibus Confirm",
      controls = {
        {
          type = "checkbox",
          name = "Enable Module",
          tooltip = "Automatically fills in 'CONFIRM' or similar text when destructive dialogs appear.",
          getFunc = function() return SV().enabled end,
          setFunc = function(v) SV().enabled = v end,
          width = "full",
        },
      },
    }
end

KRT:RegisterModule(KRT.KAC)
