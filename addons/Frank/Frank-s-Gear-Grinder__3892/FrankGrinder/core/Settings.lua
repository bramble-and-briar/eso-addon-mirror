local function boolOrDefault(v, d)
    if v == true or v == false then return v end
    return d == true
end

-- Lead warning settings
function FrankGrinder:GetSettingLeadWarningEnabled()
    local x = self.SV.options.leadWarningEnabled
    return boolOrDefault(x, self.defaults.options.leadWarningEnabled)
end

function FrankGrinder:SetSettingLeadWarningEnabled(value)
    self.SV.options.leadWarningEnabled = boolOrDefault(value, self.defaults.options.leadWarningEnabled)
    self:LeadWarnings_ResetState()
    self:InitializeLeadWarning()
end

function FrankGrinder:GetSettingLeadWarningAnnounce()
    local x = self.SV.options.leadWarningAnnounce
    return boolOrDefault(x, self.defaults.options.leadWarningAnnounce)
end

function FrankGrinder:SetSettingLeadWarningAnnounce(value)
    self.SV.options.leadWarningAnnounce = boolOrDefault(value, self.defaults.options.leadWarningAnnounce)
end

function FrankGrinder:GetSettingLeadWarningChatWindow()
    local x = self.SV.options.leadWarningChatWindow
    return boolOrDefault(x, self.defaults.options.leadWarningChatWindow)
end

function FrankGrinder:SetSettingLeadWarningChatWindow(value)
    self.SV.options.leadWarningChatWindow = boolOrDefault(value, self.defaults.options.leadWarningChatWindow)
end

function FrankGrinder:GetSettingLeadWarningPeriod()
    local x = self.SV.options.leadWarningPeriod
    return tonumber(x) or tonumber(self.defaults.options.leadWarningPeriod)
end

function FrankGrinder:SetSettingLeadWarningPeriod(value)
    local n = tonumber(value)
    if not n then n = tonumber(self.defaults.options.leadWarningPeriod) end
    if n < 1 then n = 1 end
    if n > 20 then n = 20 end
    self.SV.options.leadWarningPeriod = n
end

function FrankGrinder:GetSettingLeadNoWarningPeriod()
    local x = self.SV.options.leadNoWarningPeriod
    return tonumber(x) or tonumber(self.defaults.options.leadNoWarningPeriod)
end

function FrankGrinder:SetSettingLeadNoWarningPeriod(value)
    local n = tonumber(value)
    if not n then n = tonumber(self.defaults.options.leadNoWarningPeriod) end
    if n < 1 then n = 1 end
    if n > 120 then n = 120 end
    self.SV.options.leadNoWarningPeriod = n
end

function FrankGrinder:GetSettingLeadWarningState(antiquityId)
    local x = self.SV.leadWarning[tonumber(antiquityId)]
    if x == nil then return true end
    return x
end

function FrankGrinder:SetSettingLeadWarningState(antiquityId, value)
    if value == false then
        self.SV.leadWarning[tonumber(antiquityId)] = false
    else
        self.SV.leadWarning[tonumber(antiquityId)] = nil
    end
end

-- Group Finder settings
function FrankGrinder:GetSettingGroupFinderEnabled()
    local x = self.SV.options.groupFinderEnabled
    return boolOrDefault(x, self.defaults.options.groupFinderEnabled)
end

function FrankGrinder:SetSettingGroupFinderEnabled(value)
    self.SV.options.groupFinderEnabled = boolOrDefault(value, self.defaults.options.groupFinderEnabled)
    self:InitializeGroupFinderNotifications()
end

function FrankGrinder:GetSettingGroupFinderCheckInterval()
    local x = self.SV.options.groupFinderCheckInterval
    return tonumber(x) or tonumber(self.defaults.options.groupFinderCheckInterval)
end

function FrankGrinder:SetSettingGroupFinderCheckInterval(value)
    local n = tonumber(value)
    if not n then n = tonumber(self.defaults.options.groupFinderCheckInterval) end
    if n < 5 then n = 5 end
    if n > 60 then n = 60 end
    self.SV.options.groupFinderCheckInterval = n
    self:InitializeGroupFinderNotifications()
end

function FrankGrinder:GetSettingGroupFinderTrials(abbv)
    local key = tostring(abbv)
    local x = self.SV.options.groupFinderTrials[key]
    if x == nil then return self.defaults.options.groupFinderTrials[key] == true end
    return x
end

function FrankGrinder:SetSettingGroupFinderTrials(abbv, value)
    local key = tostring(abbv)
    self.SV.options.groupFinderTrials[key] = boolOrDefault(value, self.defaults.options.groupFinderTrials[key])
end

-- PA override settings
function FrankGrinder:GetSettingOverridePAKnown()
    local x = self.SV.options.overridePAKnown
    return boolOrDefault(x, self.defaults.options.overridePAKnown)
end

function FrankGrinder:SetSettingOverridePAKnown(value)
    self.SV.options.overridePAKnown =
        boolOrDefault(value, self.defaults.options.overridePAKnown)

    if self:GetSettingOverridePAKnown() then
        self:PA_Install()
    else
        self:PA_Uninstall()
    end

    self:DebugPAHookStatus()
end


function FrankGrinder:GetSettingSaleValueThreshold()
    local x = self.SV.options.saleValueThreshold
    return tonumber(x) or tonumber(self.defaults.options.saleValueThreshold)
end

function FrankGrinder:SetSettingSaleValueThreshold(value)
    local n = tonumber(value)
    if not n then n = tonumber(self.defaults.options.saleValueThreshold) end
    if n < 0 then n = 0 end
    if n > 20000000 then n = 20000000 end
    self.SV.options.saleValueThreshold = n
end

function FrankGrinder:GetSettingCrafterCharacterName()
    local x = self.SV.options.crafterCharacterName
    return x ~= nil and x or self.defaults.options.crafterCharacterName
end

function FrankGrinder:SetSettingCrafterCharacterName(value)
    self.SV.options.crafterCharacterName = value ~= nil and tostring(value) or self.defaults.options.crafterCharacterName
    self:PA_ClearCaches()
end

function FrankGrinder:GetSettingTraderCharacterName()
    local x = self.SV.options.traderCharacterName
    return x ~= nil and x or self.defaults.options.traderCharacterName
end

function FrankGrinder:SetSettingTraderCharacterName(value)
    self.SV.options.traderCharacterName = value ~= nil and tostring(value) or self.defaults.options.traderCharacterName
    self:PA_ClearCaches()
end

function FrankGrinder:GetSettingWithdrawToTraderEnabled()
    local x = self.SV.options.withdrawToTrader
    return boolOrDefault(x, self.defaults.options.withdrawToTrader)
end

function FrankGrinder:SetSettingWithdrawToTraderEnabled(value)
    self.SV.options.withdrawToTrader = boolOrDefault(value, self.defaults.options.withdrawToTrader)
end

function FrankGrinder:GetSettingMailToOtherAccountEnabled()
    local x = self.SV.options.mailToOtherAccount
    return boolOrDefault(x, self.defaults.options.mailToOtherAccount)
end

function FrankGrinder:SetSettingMailToOtherAccountEnabled(value)
    self.SV.options.mailToOtherAccount =
        boolOrDefault(value, self.defaults.options.mailToOtherAccount)

    self:DebugMsg("Mail to other account = " ..
        tostring(self.SV.options.mailToOtherAccount))

    -- Apply immediately rather than waiting for a reload
    self:InitializeMailer()
end

function FrankGrinder:GetSettingMailItemsAccount()
    local x = self.SV.options.mailItemsAccount
    return x ~= nil and x or self.defaults.options.mailItemsAccount
end

function FrankGrinder:SetSettingMailItemsAccount(value)
    self.SV.options.mailItemsAccount = value ~= nil and tostring(value) or self.defaults.options.mailItemsAccount
end

function FrankGrinder:GetSettingMailMatsAccount()
    local x = self.SV.options.mailMatsAccount
    return x ~= nil and x or self.defaults.options.mailMatsAccount
end

function FrankGrinder:SetSettingMailMatsAccount(value)
    self.SV.options.mailMatsAccount = value ~= nil and tostring(value) or self.defaults.options.mailMatsAccount
end

-- Mailer: Intricate Woodcrafting
function FrankGrinder:GetSettingMailIntricateWoodcrafting()
    local x = self.SV.options.mailIntricateWoodcrafting
    return boolOrDefault(x, self.defaults.options.mailIntricateWoodcrafting)
end

function FrankGrinder:SetSettingMailIntricateWoodcrafting(value)
    self.SV.options.mailIntricateWoodcrafting =
        boolOrDefault(value, self.defaults.options.mailIntricateWoodcrafting)
end

-- Mailer: Intricate Clothier
function FrankGrinder:GetSettingMailIntricateClothier()
    local x = self.SV.options.mailIntricateClothier
    return boolOrDefault(x, self.defaults.options.mailIntricateClothier)
end

function FrankGrinder:SetSettingMailIntricateClothier(value)
    self.SV.options.mailIntricateClothier =
        boolOrDefault(value, self.defaults.options.mailIntricateClothier)
end

-- Mailer: Intricate Blacksmithing
function FrankGrinder:GetSettingMailIntricateBlacksmithing()
    local x = self.SV.options.mailIntricateBlacksmithing
    return boolOrDefault(x, self.defaults.options.mailIntricateBlacksmithing)
end

function FrankGrinder:SetSettingMailIntricateBlacksmithing(value)
    self.SV.options.mailIntricateBlacksmithing =
        boolOrDefault(value, self.defaults.options.mailIntricateBlacksmithing)
end

-- Mailer: Intricate Jewelry
function FrankGrinder:GetSettingMailIntricateJewelry()
    local x = self.SV.options.mailIntricateJewelry
    return boolOrDefault(x, self.defaults.options.mailIntricateJewelry)
end

function FrankGrinder:SetSettingMailIntricateJewelry(value)
    self.SV.options.mailIntricateJewelry =
        boolOrDefault(value, self.defaults.options.mailIntricateJewelry)
end

-- Mailer: Glyphs
function FrankGrinder:GetSettingMailGlyphs()
    local x = self.SV.options.mailGlyphs
    return boolOrDefault(x, self.defaults.options.mailGlyphs)
end

function FrankGrinder:SetSettingMailGlyphs(value)
    self.SV.options.mailGlyphs =
        boolOrDefault(value, self.defaults.options.mailGlyphs)
end

-- Mailer: Crafting Materials
function FrankGrinder:GetSettingMailCraftingMats()
    local x = self.SV.options.mailCraftingMats
    return boolOrDefault(x, self.defaults.options.mailCraftingMats)
end

function FrankGrinder:SetSettingMailCraftingMats(value)
    self.SV.options.mailCraftingMats =
        boolOrDefault(value, self.defaults.options.mailCraftingMats)
end

-- Mailer: BoE Items
function FrankGrinder:GetSettingMailBoEItems()
    local x = self.SV.options.mailBoEItems
    return boolOrDefault(x, self.defaults.options.mailBoEItems)
end

function FrankGrinder:SetSettingMailBoEItems(value)
    self.SV.options.mailBoEItems =
        boolOrDefault(value, self.defaults.options.mailBoEItems)
end

-- Mailer: Unknown Writs
function FrankGrinder:GetSettingMailUnknownWrits()
    local x = self.SV.options.mailUnknownWrits
    return boolOrDefault(x, self.defaults.options.mailUnknownWrits)
end

function FrankGrinder:SetSettingMailUnknownWrits(value)
    self.SV.options.mailUnknownWrits =
        boolOrDefault(value, self.defaults.options.mailUnknownWrits)
end

-- Mailer: Unidentified Surveys
function FrankGrinder:GetSettingMailUnknownSurveys()
    local x = self.SV.options.mailUnknownSurveys
    return boolOrDefault(x, self.defaults.options.mailUnknownSurveys)
end

function FrankGrinder:SetSettingMailUnknownSurveys(value)
    self.SV.options.mailUnknownSurveys =
        boolOrDefault(value, self.defaults.options.mailUnknownSurveys)
end

-- Mailer: Unopened Treasures
function FrankGrinder:GetSettingMailUnknownTreasures()
    local x = self.SV.options.mailUnknownTreasures
    return boolOrDefault(x, self.defaults.options.mailUnknownTreasures)
end

function FrankGrinder:SetSettingMailUnknownTreasures(value)
    self.SV.options.mailUnknownTreasures =
        boolOrDefault(value, self.defaults.options.mailUnknownTreasures)
end

-- NM hide the Zone faction tracker
function FrankGrinder:GetSettingHideAdventureZoneHudTracker()
    local x = self.SV.options.hideAdventureZoneHudTracker
    return boolOrDefault(x, self.defaults.options.hideAdventureZoneHudTracker)
end

function FrankGrinder:SetSettingHideAdventureZoneHudTracker(value)
    self.SV.options.hideAdventureZoneHudTracker =
        boolOrDefault(value, self.defaults.options.hideAdventureZoneHudTracker)

    self:ApplyAdventureZoneHudTrackerSettingWithRetry()
end

-- NM Use Elms Markers
function FrankGrinder:GetSettingEnableElmsInjection()
    local x = self.SV.options.enableElmsInjection
    return boolOrDefault(x, self.defaults.options.enableElmsInjection)
end

function FrankGrinder:SetSettingEnableElmsInjection(value)
    self.SV.options.enableElmsInjection = 
        boolOrDefault(value, self.defaults.options.enableElmsInjection)
end

-- Key Chording (Shift/Ctrl/Alt modifier keybinds)
function FrankGrinder:GetSettingKeyChordingEnabled()
    local x = self.SV.options.keyChordingEnabled
    return boolOrDefault(x, self.defaults.options.keyChordingEnabled)
end

function FrankGrinder:SetSettingKeyChordingEnabled(value)
    self.SV.options.keyChordingEnabled =
        boolOrDefault(value, self.defaults.options.keyChordingEnabled)

    self:ApplyKeyChording(self.SV.options.keyChordingEnabled)
end

-- ------------------------------------------------------------
-- Night Market: Group Finder automation config (persisted)
-- ------------------------------------------------------------
local function nmCfg(self)
  self.SV.options.nmAutomationConfig = self.SV.options.nmAutomationConfig or {}
  return self.SV.options.nmAutomationConfig
end

function FrankGrinder:GetSettingNMKeyFarmMode()
  local c = nmCfg(self)
  return c.mode or self.defaults.options.nmAutomationConfig.mode
end
function FrankGrinder:SetSettingNMKeyFarmMode(v)
  nmCfg(self).mode = tostring(v or self.defaults.options.nmAutomationConfig.mode)
end

function FrankGrinder:GetSettingNMKeyFarmTitlePrefix()
  local c = nmCfg(self)
  return c.titlePrefix ~= nil and tostring(c.titlePrefix) or self.defaults.options.nmAutomationConfig.titlePrefix
end
function FrankGrinder:SetSettingNMKeyFarmTitlePrefix(v)
  nmCfg(self).titlePrefix = tostring(v or "")
end

function FrankGrinder:GetSettingNMKeyFarmTank()
  local c = nmCfg(self)
  return tonumber(c.tank) or tonumber(self.defaults.options.nmAutomationConfig.tank) or 0
end
function FrankGrinder:SetSettingNMKeyFarmTank(v)
  nmCfg(self).tank = tonumber(v) or self.defaults.options.nmAutomationConfig.tank
end

function FrankGrinder:GetSettingNMKeyFarmHeal()
  local c = nmCfg(self)
  return tonumber(c.heal) or tonumber(self.defaults.options.nmAutomationConfig.heal) or 0
end
function FrankGrinder:SetSettingNMKeyFarmHeal(v)
  nmCfg(self).heal = tonumber(v) or self.defaults.options.nmAutomationConfig.heal
end

function FrankGrinder:GetSettingNMKeyFarmDps()
  local c = nmCfg(self)
  return tonumber(c.dps) or tonumber(self.defaults.options.nmAutomationConfig.dps) or 0
end
function FrankGrinder:SetSettingNMKeyFarmDps(v)
  nmCfg(self).dps = tonumber(v) or self.defaults.options.nmAutomationConfig.dps
end

function FrankGrinder:GetSettingNMKeyFarmCP()
  local c = nmCfg(self)
  return tonumber(c.cp) or tonumber(self.defaults.options.nmAutomationConfig.cp) or 0
end
function FrankGrinder:SetSettingNMKeyFarmCP(v)
  nmCfg(self).cp = tonumber(v) or self.defaults.options.nmAutomationConfig.cp
end