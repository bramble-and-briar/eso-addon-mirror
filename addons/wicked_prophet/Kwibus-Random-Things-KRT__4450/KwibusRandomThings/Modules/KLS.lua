local KRT = KwibusRandomThings
local EM = EVENT_MANAGER
local ADDON_NAME = KRT.name

-- Module-local defaults wrapper
local DEFAULTS = { kls = {
    enabled = false,
    promptToEnglishOnTrial = true,
    promptBackToRussian = true,
    swapBackDelayMs = 300000, -- 5 minutes
    englishCode = "en",
    russianCode = "ru",
    debug = false,
  } }

KRT.KLS = {
    id = "kls",
    defaults = DEFAULTS.kls,
  TIMER_NAME = ADDON_NAME .. "_KLS_Timer",
  wasInTrial = false,
}

function KRT.KLS:SV() return KRT.GetModuleSV(self.id, self.defaults) end
function KRT.KLS:Dbg(msg) local sv = self:SV(); if sv and sv.debug then d("[KLS] " .. tostring(msg)) end end

function KRT.KLS:AttemptSwapBackPrompt()
  EM:UnregisterForUpdate(self.TIMER_NAME)
  local sv = self:SV()
  if not (sv and sv.enabled and sv.promptBackToRussian) then return end
  if GetCVar("language.2") == sv.englishCode then
    ZO_Dialogs_ShowDialog("KRT_LANG_SWAP_BACK")
  end
end

function KRT.KLS:OnPlayerActivated()
  local sv = self:SV()
  if not (sv and sv.enabled) then return end
  local zoneId = GetZoneId(GetUnitZoneIndex("player"))
  local isTrial = (IsRaidZone and IsRaidZone()) or (KRT.TRIAL_ZONES and KRT.TRIAL_ZONES[zoneId]) or false

  if isTrial then
    EM:UnregisterForUpdate(self.TIMER_NAME)
    self.wasInTrial = true
    if sv.promptToEnglishOnTrial and GetCVar("language.2") ~= sv.englishCode then
      ZO_Dialogs_ShowDialog("KRT_LANG_SWAP_EN")
    end
  else
    if self.wasInTrial then
      self.wasInTrial = false
      local delay = tonumber(sv.swapBackDelayMs) or DEFAULTS.kls.swapBackDelayMs
      EM:RegisterForUpdate(self.TIMER_NAME, delay, function() self:AttemptSwapBackPrompt() end)
    end
  end
end

function KRT.KLS:Initialize()
  ZO_Dialogs_RegisterCustomDialog("KRT_LANG_SWAP_EN", {
    title = { text = "Trial Detected" },
    mainText = { text = "You are entering a Trial. Swap language to English?" },
    buttons = {
      [1] = { text = "Yes", callback = function()
        local sv = self:SV(); if sv then SetCVar("language.2", sv.englishCode or "en") end
      end },
      [2] = { text = "No" },
    },
  })

  ZO_Dialogs_RegisterCustomDialog("KRT_LANG_SWAP_BACK", {
    title = { text = "Trial Finished" },
    mainText = { text = "You left the Trial a while ago. Swap back to Russian?" },
    buttons = {
      [1] = { text = "Yes", callback = function()
        local sv = self:SV(); if sv then SetCVar("language.2", sv.russianCode or "ru") end
      end },
      [2] = { text = "No" },
    },
  })

  EM:RegisterForEvent(ADDON_NAME .. "_KLS_Activated", EVENT_PLAYER_ACTIVATED, function()
    self:OnPlayerActivated()
  end)
end

-- =========================================================

local function SV() return KRT.KLS:SV() end

function KRT.KLS:GetLAMSubmenu()
    return {
      type = "submenu",
      name = "Kwibus Language Swap",
      controls = {
        {
          type = "checkbox",
          name = "Enable Module",
          getFunc = function() return SV().enabled end,
          setFunc = function(v)
            SV().enabled = v
            if not v then
              EM:UnregisterForUpdate(KRT.KLS.TIMER_NAME)
              KRT.KLS.wasInTrial = false
            end
          end,
          width = "full",
        },
        {
          type = "checkbox",
          name = "Prompt to Swap to English on Trial Entry",
          getFunc = function() return SV().promptToEnglishOnTrial end,
          setFunc = function(v) SV().promptToEnglishOnTrial = v end,
          width = "full",
          disabled = function() return not SV().enabled end,
        },
        {
          type = "checkbox",
          name = "Prompt to Swap Back to Russian After Leaving",
          getFunc = function() return SV().promptBackToRussian end,
          setFunc = function(v) SV().promptBackToRussian = v end,
          width = "full",
          disabled = function() return not SV().enabled end,
        },
        {
          type = "slider",
          name = "Swap-Back Delay (Seconds)",
          min = 5,
          max = 900,
          step = 5,
          getFunc = function() return math.floor((SV().swapBackDelayMs or 300000) / 1000) end,
          setFunc = function(v) SV().swapBackDelayMs = v * 1000 end,
          width = "full",
          disabled = function() return not SV().enabled end,
        },
        {
          type = "checkbox",
          name = "Enable Debug Logging",
          getFunc = function() return SV().debug end,
          setFunc = function(v) SV().debug = v end,
          width = "full",
          disabled = function() return not SV().enabled end,
        },
      },
    }
end

KRT:RegisterModule(KRT.KLS)

