local PvPUA = PvPUA
local U = PvPUA.util
local DC_HEX = U.DC_HEX
local AD_HEX = U.AD_HEX
local EP_HEX = U.EP_HEX
local RainbowText = U.RainbowText
local GetColorForAlliance = U.GetColorForAlliance
local IsInCyrodiilOrIC = U.IsInCyrodiilOrIC
local ScreenBounds = U.ScreenBounds
local DetailsFont = U.DetailsFont
local EA_FONT_CHOICES = U.EA_FONT_CHOICES
local SAVED_ACCOUNT_TIP = U.SAVED_ACCOUNT_TIP

--------------------------------------------------
-- Position & Scale
--------------------------------------------------
function PvPUA:ApplyPosition()
    self.controls.TLW:ClearAnchors()
    self.controls.TLW:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT,
        self.savedVariables.posX or PvPUA.defaults.posX,
        self.savedVariables.posY or PvPUA.defaults.posY)
end

function PvPUA:ApplyScale()
    if not self.controls.TLW then return end
    local scale = self.savedVariables and self.savedVariables.uiScale or 1.0
    self.controls.TLW:SetScale(scale)
end

--------------------------------------------------
-- Apply Size
--------------------------------------------------
function PvPUA:ApplyListSize()
    self.config.entryHeight         = 34
    self.config.nameWidth           = 180
    self.config.width               = 510
    self.config.siegeWidth          = 38
    self.config.underAttackForWidth = 65
    self.config.flagFlipWidth       = 60
    self:InvalidateFontCache()
end

--------------------------------------------------
-- Visibility
--------------------------------------------------
function PvPUA:ShowCredit()
    return not (self.savedVariables and self.savedVariables.showCredit == false)
end

function PvPUA:HeaderTop()
    return self:ShowCredit() and 20 or 0
end

function PvPUA:ApplyCreditVisibility()
    local c = self.controls
    if not (c and c.TLW) then return end
    self.headerShift = nil
    self:ApplyHeaderLayout()
    local rootControl = c.TLW.rootControl
    if rootControl then
        rootControl:ClearAnchors()
        rootControl:SetAnchor(TOPLEFT, c.TLW, TOPLEFT, 0, self:HeaderTop() + self.config.entryHeight * 2)
    end
    if c.creditLabel and not self:ShowCredit() then
        c.creditLabel:SetHidden(true)
    end
end

function PvPUA:ShowListInMenus()
    return self.savedVariables ~= nil and self.savedVariables.showListInMenus == true
end

function PvPUA:ShowListWhileDead()
    return self.savedVariables ~= nil and self.savedVariables.showListWhileDead == true
end

function PvPUA:ShowListWhileSieging()
    return self.savedVariables ~= nil and self.savedVariables.showListWhileSieging == true
end

--------------------------------------------------
-- Scenes
--------------------------------------------------
local LIST_HUD_SCENES   = { "hud", "hudui" }
local LIST_SIEGE_SCENES = { "siegeBar", "siegeBarUI" }

local function IsSceneNamed(names, sceneName)
    for i = 1, #names do
        if names[i] == sceneName then return true end
    end
    return false
end

function PvPUA:CurrentSceneName()
    return (SCENE_MANAGER and SCENE_MANAGER:GetCurrentSceneName()) or ""
end

function PvPUA:IsHudScene()
    return IsSceneNamed(LIST_HUD_SCENES, self:CurrentSceneName())
end

function PvPUA:IsSiegeScene()
    return IsSceneNamed(LIST_SIEGE_SCENES, self:CurrentSceneName())
end

local function SettingsSceneName()
    local panel = PvPUA.settingsPanel
    return panel and panel.SCENE_NAME
end

function PvPUA:IsSettingsScene()
    local name = SettingsSceneName()
    return name ~= nil and self:CurrentSceneName() == name
end

function PvPUA:IsSettingsSceneObject(scene)
    local name = SettingsSceneName()
    return name ~= nil and scene ~= nil and scene.GetName ~= nil and scene:GetName() == name
end

--------------------------------------------------
-- While Dead
--------------------------------------------------
function PvPUA:RefreshDeadHiddenReason()
    local fragment = self.controls.hudFragment
    if not (fragment and fragment.SetHiddenForReason) then return end
    local hide = self:EAIsPlayerDead() and not self:ShowListWhileDead()
    fragment:SetHiddenForReason("PvPUADead", hide)
end

function PvPUA:EndSettingsPreviews()
    self.listPreview = false
    for key, a in pairs(self.effectAlerts) do
        if a.preview then
            a.preview = false
            self:EARefresh(key)
        end
    end
    local potion = self.Potion
    if potion and potion.previewMode then
        potion.previewMode = false
        potion:RefreshDisplay()
    end
end

function PvPUA:ApplyListVisibility()
    local tlw = self.controls.TLW
    if not tlw then return end

    self:RefreshDeadHiddenReason()

    if self:IsHudScene() or self:IsSiegeScene() then return end

    local show
    if self:IsSettingsScene() then
        show = self.listPreview == true
    else
        show = self:ShowListInMenus()
    end

    if IsInCyrodiilOrIC() and show then
        tlw:SetAlpha(1)
        tlw:SetHidden(false)
    else
        tlw:SetHidden(true)
    end
end

function PvPUA:ApplyFragmentToScenes(names, wanted)
    local fragment = self.controls.hudFragment
    for i = 1, #names do
        local scene = SCENE_MANAGER:GetScene(names[i])
        if scene then
            local has = scene:HasFragment(fragment)
            if wanted and not has then
                scene:AddFragment(fragment)
            elseif not wanted and has then
                scene:RemoveFragment(fragment)
            end
        end
    end
end

function PvPUA:UpdateHUDScenes()
    if not self.controls.hudFragment then return end
    local inPvP = IsInCyrodiilOrIC()
    self:ApplyFragmentToScenes(LIST_HUD_SCENES, inPvP)
    self:ApplyFragmentToScenes(LIST_SIEGE_SCENES, inPvP and self:ShowListWhileSieging())
    self:ApplyListVisibility()
end

--------------------------------------------------
-- RefreshBackdropColors
--------------------------------------------------
function PvPUA:ApplyBackdropOpacity()
    local pct = tonumber(self.savedVariables and self.savedVariables.backdropOpacity) or 25
    if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end
    self.config.backdropAlphaOdd = pct / 100
    self.config.backdropAlphaEven = pct / 100 * 0.6
end

function PvPUA:RefreshBackdropColors()
    local useAlliance = self.savedVariables and self.savedVariables.backdropStyle == "Alliance"
    local bc = self.savedVariables and self.savedVariables.backdropColor
    local br = bc and bc.r or 0
    local bg_c = bc and bc.g or 0
    local bb = bc and bc.b or 0
    if self.controls.scoreRowBg then
        if useAlliance then
            self.controls.scoreRowBg:SetCenterColor(0, 0, 0, self.config.backdropAlphaEven)
        else
            self.controls.scoreRowBg:SetCenterColor(br, bg_c, bb, self.config.backdropAlphaEven)
        end
    end
    if self.controls.infoBg then
        if useAlliance then
            self.controls.infoBg:SetCenterColor(0, 0, 0, self.config.backdropAlphaOdd)
        else
            self.controls.infoBg:SetCenterColor(br, bg_c, bb, self.config.backdropAlphaOdd)
        end
    end
    if self.state and self.state.visibleControls then
        for i, control in ipairs(self.state.visibleControls) do
            if control and control.backdrop then
                local ac = { r = 0, g = 0, b = 0 }
                if useAlliance and self.state.lastItems and self.state.lastItems[i] then
                    ac = GetColorForAlliance(self.state.lastItems[i].owningAlliance)
                end
                if useAlliance then
                    local rr, rg, rb = ac.r, ac.g, ac.b
                    local li = self.state.lastItems and self.state.lastItems[i]
                    if li and li.isScrollDropped then rr, rg, rb = 1, 1, 1 end
                    if i % 2 == 0 then
                        control.backdrop:SetCenterColor(rr, rg, rb, self.config.backdropAlphaEven)
                    else
                        control.backdrop:SetCenterColor(rr, rg, rb, self.config.backdropAlphaOdd)
                    end
                else
                    if i % 2 == 0 then
                        control.backdrop:SetCenterColor(br, bg_c, bb, self.config.backdropAlphaEven)
                    else
                        control.backdrop:SetCenterColor(br, bg_c, bb, self.config.backdropAlphaOdd)
                    end
                end
            end
        end
    end
end

--------------------------------------------------
-- Rank Display
--------------------------------------------------
function PvPUA:RankDisplayLeftText()
    local label = self.controls and self.controls.infoRankNum
    if not label then return "" end
    self:RefreshRankLabel()
    return label:GetText() or ""
end

function PvPUA:RankDisplayBar()
    local ac = GetColorForAlliance(GetUnitAlliance("player"))
    if self.savedVariables and self.savedVariables.barMode == "Veterancy" then
        local v = self:GetVeterancyInfo()
        local icon, ir, ig, ib = v.icon, 1, 1, 1
        if not icon then
            icon = ZO_CampaignAvARankIcon and ZO_CampaignAvARankIcon:GetTextureFileName() or nil
            ir, ig, ib = ac.r, ac.g, ac.b
        end
        local pct, right = v.ok and 100 or 0, ""
        if v.ok and v.total and v.total > 0 then
            pct = (v.progress / v.total) * 100
            right = ZO_CommaDelimitNumber(v.progress) .. " / " .. ZO_CommaDelimitNumber(v.total)
        end
        return icon, ir, ig, ib, pct, self:RankDisplayLeftText(), right, ac.r, ac.g, ac.b
    end

    local icon = ZO_CampaignAvARankIcon and ZO_CampaignAvARankIcon:GetTextureFileName() or ""
    if icon == "" then icon = GetAvARankIcon(GetUnitAvARank("player")) end
    local currentXP = GetUnitAvARankPoints("player")
    local lastRankXP, nextRankXP = GetAvARankProgress(currentXP)
    local pct, right = 100, ""
    local required = nextRankXP and (nextRankXP - lastRankXP) or 0
    if nextRankXP and required > 0 then
        pct = (currentXP - lastRankXP) / required * 100
        right = ZO_CommaDelimitNumber(currentXP - lastRankXP) .. " / " .. ZO_CommaDelimitNumber(required)
    end
    return icon, ac.r, ac.g, ac.b, pct, self:RankDisplayLeftText(), right, ac.r, ac.g, ac.b
end

--------------------------------------------------
-- Menu
--------------------------------------------------
function PvPUA:AppearanceMenu()
    local screenW, screenH = ScreenBounds()
    return { type = "submenu",
          name = "|c" .. DC_HEX .. "Appearance|r",
          tooltip = SAVED_ACCOUNT_TIP,
          icon = "EsoUI/Art/Addons/Gamepad/gp_mod_listing_category_uiGraphics.dds",
          options = {
        { type = "checklist",
          name = "Show List",
          noSelectionText = "None",
          choices = {
              { name = "In Menus",      value = "showListInMenus" },
              { name = "While Sieging", value = "showListWhileSieging" },
              { name = "While Dead",    value = "showListWhileDead" },
          },
          default = { "showListWhileDead" },
          getFunc = function()
              local sv = PvPUA.savedVariables
              local sel = {}
              if sv.showListInMenus then sel[#sel + 1] = "showListInMenus" end
              if sv.showListWhileSieging then sel[#sel + 1] = "showListWhileSieging" end
              if sv.showListWhileDead then sel[#sel + 1] = "showListWhileDead" end
              return sel
          end,
          setFunc = function(values)
              local on = {}
              if type(values) == "table" then
                  for _, v in ipairs(values) do on[v] = true end
              end
              local sv = PvPUA.savedVariables
              sv.showListInMenus = on.showListInMenus == true
              sv.showListWhileSieging = on.showListWhileSieging == true
              sv.showListWhileDead = on.showListWhileDead == true
              PvPUA:UpdateHUDScenes()
          end },
        { type = "toggle", name = "Preview List",
          tooltip = "Shows the list here so you can size and position it. Turns off when you close settings.",
          disabled = function() return not IsInCyrodiilOrIC() end,
          getFunc = function() return PvPUA.listPreview == true end,
          setFunc = function(v)
              PvPUA.listPreview = v == true
              PvPUA:ApplyListVisibility()
          end },
        { type = "slider", name = "Size", min = 80, max = 150, step = 5,
          default = 100,
          tooltip = "Default is 100.",
          getFunc = function() return math.floor((self.savedVariables.uiScale or 1.0) * 100 + 0.5) end,
          setFunc = function(v) self.savedVariables.uiScale = v / 100; self:ApplyScale() end },
        { type = "slider", name = "Horizontal Position", min = 0, max = screenW, step = 5,
          default = PvPUA.defaults.posX,
          tooltip = "Default is " .. PvPUA.defaults.posX .. ".",
          getFunc = function() return self.savedVariables.posX end,
          setFunc = function(v) self.savedVariables.posX = v; self:ApplyPosition() end },
        { type = "slider", name = "Vertical Position", min = 0, max = screenH, step = 5,
          default = PvPUA.defaults.posY,
          tooltip = "Default is " .. PvPUA.defaults.posY .. ".",
          getFunc = function() return self.savedVariables.posY end,
          setFunc = function(v) self.savedVariables.posY = v; self:ApplyPosition() end },
        { type = "checklist",
          name = "Show in List",
          noSelectionText = "None",
          choices = {
              { name = "Milegates", value = "showMilegates" },
              { name = "Bridges", value = "showBridges" },
              { name = "Towns", value = "showTowns" },
              { name = "Resources", value = "showResources" },
              { name = "Scroll Carriers", value = "showScrollCarriers" },
              { name = "Volendrung", value = "showVolendrungRow" },
              { name = "THE TRUTH", value = "showCredit" },
          },
          default = { "showMilegates", "showBridges", "showTowns", "showResources", "showScrollCarriers", "showVolendrungRow", "showCredit" },
          getFunc = function()
              local sv = PvPUA.savedVariables
              local sel = {}
              if sv.showMilegates then sel[#sel + 1] = "showMilegates" end
              if sv.showBridges then sel[#sel + 1] = "showBridges" end
              if sv.showTowns then sel[#sel + 1] = "showTowns" end
              if sv.showResources then sel[#sel + 1] = "showResources" end
              if sv.showScrollCarriers then sel[#sel + 1] = "showScrollCarriers" end
              if sv.showVolendrungRow then sel[#sel + 1] = "showVolendrungRow" end
              if sv.showCredit ~= false then sel[#sel + 1] = "showCredit" end
              return sel
          end,
          setFunc = function(values)
              local on = {}
              if type(values) == "table" then
                  for _, v in ipairs(values) do on[v] = true end
              end
              local sv = PvPUA.savedVariables
              sv.showMilegates = on.showMilegates == true
              sv.showBridges = on.showBridges == true
              sv.showTowns = on.showTowns == true
              sv.showResources = on.showResources == true
              sv.showScrollCarriers = on.showScrollCarriers == true
              sv.showVolendrungRow = on.showVolendrungRow == true
              sv.showCredit = on.showCredit == true
              PvPUA:ApplyCreditVisibility()
          end },
        { type = "dropdown", name = "Cap List At",
          choices = PvPUA.capChoices,
          default = 0,
          details = function()
              local cap = tonumber(self.savedVariables.listCap) or 0
              if cap <= 0 then return "Shows every row." end
              return string.format("Shows at most %d rows. Rows past that are hidden.", cap)
          end,
          getFunc = function() return self.savedVariables.listCap end,
          setFunc = function(val) self.savedVariables.listCap = val end },
        { type = "dropdown", name = "Rank Display",
          choices = { "AP Progress Bar", "Veterancy Progress Bar" },
          sampleBar = function() return self:RankDisplayBar() end,
          getFunc = function()
              return (self.savedVariables.barMode == "Veterancy")
                  and "Veterancy Progress Bar" or "AP Progress Bar"
          end,
          setFunc = function(val)
              self.savedVariables.barMode = (val == "Veterancy Progress Bar") and "Veterancy" or "AP"
              self:RefreshRankLabel()
          end },
        { type = "dropdown", name = "Font",
          choices = EA_FONT_CHOICES,
          default = PvPUA.defaults.font,
          sample = function() return PVPUA_MENU_TITLE_COLORED, DetailsFont(self.savedVariables.font, 40), 1, 1, 1 end,
          getFunc = function() return self.savedVariables.font end,
          setFunc = function(val) self.savedVariables.font = val; self:InvalidateFontCache() end,
        },
        { type = "colorpicker", name = RainbowText("Timer Color"),
          tooltip = "Changes the UA! timer color.",
          default = { r = 1, g = 1, b = 1, a = 1 },
          getFunc = function()
              local c = self.savedVariables.timerColor
              if type(c) == "table" then
                  return c.r or 1, c.g or 1, c.b or 1, 1
              end
              return 1, 1, 1, 1
          end,
          setFunc = function(r, g, b, a)
              self.savedVariables.timerColor = { r = r, g = g, b = b, a = a }
          end,
        },
        { type = "stylecolor", name = RainbowText("Background Color"),
          choices = { "Alliance", "Custom" },
          customValue = "Custom",
          default = PvPUA.defaults.backdropStyle,
          colorDefault = { r = 0, g = 0, b = 0 },
          details = function()
              if self.savedVariables.backdropStyle == "Custom" then
                  return "Rows use your color."
              end
              return "Rows use the colors of |c" .. DC_HEX .. "Daggerfall|r, |c" .. AD_HEX .. "Aldmeri|r and |c" .. EP_HEX .. "Ebonheart|r. Switch to Custom to pick your own."
          end,
          getFunc = function() return self.savedVariables.backdropStyle end,
          setFunc = function(val)
              self.savedVariables.backdropStyle = val
              self:RefreshBackdropColors()
          end,
          getColor = function()
              local c = self.savedVariables.backdropColor
              if type(c) == "table" then
                  return c.r or 0, c.g or 0, c.b or 0
              end
              return 0, 0, 0
          end,
          setColor = function(r, g, b, a)
              self.savedVariables.backdropColor = { r = r, g = g, b = b, a = a or 1 }
              self:RefreshBackdropColors()
          end },
        { type = "slider", name = "Background Opacity", min = 0, max = 100, step = 5,
          default = PvPUA.defaults.backdropOpacity,
          tooltip = "Default is 25.",
          getFunc = function() return self.savedVariables.backdropOpacity end,
          setFunc = function(v)
              self.savedVariables.backdropOpacity = v
              self:ApplyBackdropOpacity()
              self:RefreshBackdropColors()
          end },
          } }
end
