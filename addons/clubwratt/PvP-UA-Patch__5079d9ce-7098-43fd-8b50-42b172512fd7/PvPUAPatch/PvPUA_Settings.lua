local PvPUA = PvPUAPatch
local U = PvPUA.util
local RainbowText = U.RainbowText
local SAVED_ACCOUNT_TIP = U.SAVED_ACCOUNT_TIP
local PI = PvPUA.playerIcon

local function PanelCall(method)
    local panel = PvPUA.settingsPanel
    if panel and panel[method] then panel[method](panel) end
end

--------------------------------------------------
-- Reset All
--------------------------------------------------
local function CopyDefaults(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" then
            target[k] = {}
            CopyDefaults(target[k], v)
        else
            target[k] = v
        end
    end
end

local function RawSaved(sv)
    local mt = getmetatable(sv)
    local raw = mt and mt.__index
    if type(raw) == "table" then return raw end
    return sv
end

local function ClearSaved(sv, keep)
    local raw = RawSaved(sv)
    local keys = {}
    for k in pairs(raw) do
        if not keep[k] then keys[#keys + 1] = k end
    end
    for i = 1, #keys do
        raw[keys[i]] = nil
    end
end

local RESET_KEEP_ACCOUNT = { version = true, lastSeenVersion = true }
local RESET_KEEP_CHARACTER = { version = true, iconMigrated = true, groupFramesCleared = true }

function PvPUA:ResetAllSettings()
    if self.savedVariables then
        ClearSaved(self.savedVariables, RESET_KEEP_ACCOUNT)
        CopyDefaults(self.savedVariables, PvPUA.defaults)
    end
    if self.charVariables then
        ClearSaved(self.charVariables, RESET_KEEP_CHARACTER)
        CopyDefaults(self.charVariables, PvPUA.charDefaults)
    end
    self:InvalidateFontCache()
    self:ApplyPosition()
    self:ApplyScale()
    self:RefreshBackdropColors()
    self:UpdateHUDScenes()
    self:HKClear()
    for i = 1, #PvPUA.effectAlertDefs do
        self:EAApplyMetrics(PvPUA.effectAlertDefs[i].key)
        self:EAApplyPosition(PvPUA.effectAlertDefs[i].key)
        self:EARefresh(PvPUA.effectAlertDefs[i].key)
    end
    self:EAApplyCombatListener()
    pcall(PI.OnMyStyleChanged)
    pcall(PI.RefreshGroupFrameIcons)
    self:ApplyBackdropOpacity()
    self:RefreshBackdropColors()
    self:RefreshRankLabel()
    self:ApplyCreditVisibility()
    self:EndSettingsPreviews()
    if self.AIStop then pcall(self.AIStop, self) end
    if self.AIKickStop then pcall(self.AIKickStop, self) end
    local potion = self.Potion
    if potion then
        potion:InvalidateFont()
        potion:ApplyPosition()
        potion:RefreshDisplay()
    end
    PanelCall("ApplyTextSize")
    PanelCall("ApplyOpacity")
    PanelCall("ApplyAccent")
end

--------------------------------------------------
-- Menu
--------------------------------------------------
function PvPUA:SettingsMenu()
    return { type = "submenu",
          name = "Settings",
          icon = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_settings.dds",
          tooltip = SAVED_ACCOUNT_TIP,
          options = {
        { type = "slider", name = "Font Size", min = 18, max = 44, step = 1,
          default = PvPUA.defaults.settingsFontSize,
          tooltip = "Default is 30.",
          getFunc = function() return self.savedVariables.settingsFontSize end,
          setFunc = function(v)
              self.savedVariables.settingsFontSize = v
              PanelCall("ApplyTextSize")
          end },
        { type = "slider", name = "Opacity", min = 0, max = 100, step = 5,
          default = PvPUA.defaults.settingsOpacity,
          tooltip = "Default is 100.",
          getFunc = function() return self.savedVariables.settingsOpacity end,
          setFunc = function(v)
              self.savedVariables.settingsOpacity = v
              PanelCall("ApplyOpacity")
          end },
        { type = "stylecolor", name = RainbowText("Highlight / Slider Color"),
          choices = { "Alliance", "Custom" },
          customValue = "Custom",
          default = PvPUA.defaults.settingsHighlight,
          colorDefault = { r = 1, g = 1, b = 1 },
          details = function()
              if self.savedVariables.settingsHighlight == "Custom" then
                  return "Highlights and sliders use your color."
              end
              return "Highlights and sliders use your alliance color."
          end,
          getFunc = function() return self.savedVariables.settingsHighlight end,
          setFunc = function(val)
              self.savedVariables.settingsHighlight = val
              PanelCall("ApplyAccent")
          end,
          getColor = function()
              local c = self.savedVariables.settingsHighlightColor
              if type(c) == "table" then return c.r or 1, c.g or 1, c.b or 1 end
              return 1, 1, 1
          end,
          setColor = function(r, g, b)
              self.savedVariables.settingsHighlightColor = { r = r, g = g, b = b, a = 1 }
              PanelCall("ApplyAccent")
          end },
        { type = "toggle", name = "Remember Last Page", preset = "YES_NO",
          default = PvPUA.defaults.settingsRemember,
          tooltip = "Reopens the last page where you left off.",
          getFunc = function() return self.savedVariables.settingsRemember end,
          setFunc = function(v) self.savedVariables.settingsRemember = v end },
        -- Patch: kill-marker / kill-feed diagnostics through the optional LibConsoleLogger (buffer only, no chat).
        { type = "toggle", name = "Debug Log", preset = "YES_NO",
          default = PvPUA.defaults.debugLog,
          tooltip = function()
              if not self:DebugLogAvailable() then
                  return "Needs the LibConsoleLogger add-on (not installed). Records why places are or aren't listed from battle markers and kill-feed chat lines, for bug reports."
              end
              return "Records why places are or aren't listed from battle markers and kill-feed chat lines into LibConsoleLogger's buffer (never chat). Also enable logging in LibConsoleLogger's own settings, and cap its Buffer size (300 is plenty) so an export is only a few browser round trips."
          end,
          getFunc = function() return self.savedVariables.debugLog == true end,
          setFunc = function(v)
              self.savedVariables.debugLog = v == true
          end },
        { type = "button", name = "Export Debug Log",
          buttonText = "Export",
          tooltip = "Sends LibConsoleLogger's buffer to the Export URL set in its settings (opens the in-game browser once per chunk). Same as that add-on's own Export button.",
          func = function()
              local ok, reason = self:DebugLogExport()
              local text = ok and "Debug log export started." or ("Debug log export failed: " .. tostring(reason or "?"))
              if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then pcall(CHAT_ROUTER.AddSystemMessage, CHAT_ROUTER, text)
              elseif d then d(text) end
          end },
        { type = "button", name = "|cFF3333Reset All|r",
          buttonText = "Reset All",
          tooltip = function() return "Puts every " .. PVPUA_MENU_TITLE_COLORED .. " setting back to its default. Auto Invite and Icon are only reset on this character." end,
          confirm = function() return "Reset every " .. PVPUA_MENU_TITLE_COLORED .. " setting to its default? This can't be undone." end,
          func = function() self:ResetAllSettings() end },
          } }
end
