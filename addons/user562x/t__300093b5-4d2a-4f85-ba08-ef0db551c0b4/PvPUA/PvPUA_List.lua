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
    if self:IsRankBarOnly() then return false end
    return self.savedVariables ~= nil and self.savedVariables.showListInMenus == true
end

function PvPUA:ShowListWhileDead()
    if self:IsRankBarOnly() then return true end
    return self.savedVariables ~= nil and self.savedVariables.showListWhileDead == true
end

function PvPUA:ShowListWhileSieging()
    if self:IsRankBarOnly() then return true end
    return self.savedVariables ~= nil and self.savedVariables.showListWhileSieging == true
end

function PvPUA:ShowListInCombat()
    if self:IsRankBarOnly() then return true end
    return not (self.savedVariables and self.savedVariables.showListInCombat == false)
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

--------------------------------------------------
-- In Combat
--------------------------------------------------
function PvPUA:RefreshCombatHiddenReason()
    local fragment = self.controls.hudFragment
    if not (fragment and fragment.SetHiddenForReason) then return end
    local hide = IsUnitInCombat("player") and not self:ShowListInCombat()
        and not (self:IsSiegeScene() and self:ShowListWhileSieging())
    fragment:SetHiddenForReason("PvPUACombat", hide)
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
    self:RefreshCombatHiddenReason()

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
-- Layout
--------------------------------------------------
local LAYOUT_FULL     = "Full List"
local LAYOUT_RANK_BAR = "Rank Bar || K/D Only"
local VBAR_ROTATION   = -ZO_PI / 2
local VBAR_COL_W      = 120
local HBAR_KD_GAP     = 8
local VBAR_GAP        = 4
local VBAR_STEP       = 17
local VBAR_SPACE      = 8
local VBAR_PAD        = 4

function PvPUA:IsRankBarOnly()
    local layout = self.savedVariables and self.savedVariables.listLayout
    return layout ~= nil and layout ~= LAYOUT_FULL
end

function PvPUA:IsVerticalBar()
    return self:IsRankBarOnly() and self.savedVariables.barOrientation == "Vertical"
end

local function AbbreviateNumber(n)
    n = tonumber(n) or 0
    if n < 1000 then return tostring(math.floor(n)) end
    local text
    if n < 100000 then
        text = string.format("%.1f", math.floor(n / 100) / 10) .. "k"
    elseif n < 1000000 then
        text = math.floor(n / 1000) .. "k"
    else
        text = string.format("%.1f", math.floor(n / 100000) / 10) .. "M"
    end
    return (text:gsub("%.0([kM])", "%1"))
end

function PvPUA:VerticalProgressText(current, total)
    return AbbreviateNumber(current) .. "/" .. AbbreviateNumber(total)
end

local function SetLabelBox(label, width, height, hAlign, vAlign)
    label:SetDimensions(width, height)
    label:SetHorizontalAlignment(hAlign)
    label:SetVerticalAlignment(vAlign)
end

local function Place(control, point, relativeTo, relPoint, x, y)
    control:ClearAnchors()
    control:SetAnchor(point, relativeTo, relPoint, x, y)
end

local function StackLabel(pool, parent, index, font, width)
    local label = pool[index]
    if not label then
        label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
        label:SetFont(font)
        label:SetColor(1, 1, 1, 1)
        SetLabelBox(label, width, VBAR_STEP + 4, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        label:SetDrawLayer(3)
        pool[index] = label
    end
    return label
end

local function HideStack(pool, from)
    for i = from, #pool do
        pool[i]:SetHidden(true)
    end
end

local function LayoutStack(pool, parent, anchorTo, font, width, text, fromBottom)
    local chars, offsets, height = {}, {}, 0
    for ch in tostring(text or ""):gmatch(".") do
        chars[#chars + 1] = ch
        if ch == " " then
            height = height + VBAR_SPACE
        else
            offsets[#chars] = height
            height = height + VBAR_STEP
        end
    end
    local used = 0
    for i = 1, #chars do
        local top = offsets[i]
        if top then
            used = used + 1
            local label = StackLabel(pool, parent, used, font, width)
            label:SetText(chars[i])
            local centerY = top + math.floor(VBAR_STEP / 2)
            if fromBottom then
                Place(label, CENTER, anchorTo, BOTTOM, 0, centerY - VBAR_PAD - height)
            else
                Place(label, CENTER, anchorTo, TOP, 0, centerY + VBAR_PAD)
            end
            label:SetHidden(false)
        end
    end
    HideStack(pool, used + 1)
end

function PvPUA:RefreshVerticalText()
    local c = self.controls
    if not (c and c.TLW and self.barGeom) then return end
    self.vbarRankPool = self.vbarRankPool or {}
    self.vbarProgressPool = self.vbarProgressPool or {}
    if not self:IsVerticalBar() then
        HideStack(self.vbarRankPool, 1)
        HideStack(self.vbarProgressPool, 1)
        return
    end
    local font = "EsoUI/Common/Fonts/FTN57.otf|" .. self.barGeom.barFontPx .. "|outline"
    local progress = ""
    local total = tonumber(self.barProgressTotal) or 0
    if total > 0 then
        progress = self:VerticalProgressText(self.barProgressCurrent, total)
    end
    local width = self.barGeom.barH + 8
    LayoutStack(self.vbarRankPool, c.TLW, c.infoBarBg, font, width, c.infoRankNum:GetText(), false)
    LayoutStack(self.vbarProgressPool, c.TLW, c.infoBarBg, font, width, progress, true)
end

function PvPUA:ApplyBarLayout(force)
    local c = self.controls
    local g = self.barGeom
    if not (c and c.TLW and c.TLW.rootControl and g) then return end

    local mode = "Full"
    if self:IsRankBarOnly() then
        mode = self:IsVerticalBar() and "Vertical" or "Horizontal"
    end
    if not force and self.barLayoutMode == mode then return end
    self.barLayoutMode = mode

    local tlw = c.TLW
    local width = self.config.width
    local bar = c.infoBar
    local vertical = mode == "Vertical"

    bar:SetTransformNormalizedOriginPoint(0.5, 0.5)
    bar:SetTransformRotationZ(vertical and VBAR_ROTATION or 0)

    tlw.rootControl:SetHidden(mode ~= "Full")
    if mode ~= "Full" then
        c.creditLabel:SetHidden(true)
        c.scoreRow:SetHidden(true)
    end
    c.infoBg:SetHidden(mode ~= "Full")
    c.infoRankNum:SetHidden(vertical)
    c.infoAPText:SetHidden(vertical)

    if vertical then
        local iconTop = g.infoH + VBAR_GAP
        local barTop = iconTop + g.rankBase + g.barPad
        local totalH = barTop + g.barW

        tlw:SetDimensions(VBAR_COL_W, totalH)

        Place(c.infoKD, TOP, tlw, TOP, 0, self.config.kdTextNudge or 0)
        SetLabelBox(c.infoKD, VBAR_COL_W, g.infoH, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        Place(c.infoRankIcon, CENTER, tlw, TOP, 0, iconTop + math.floor(g.rankBase / 2))

        Place(c.infoBarBg, TOP, tlw, TOP, 0, barTop)
        c.infoBarBg:SetDimensions(g.barH, g.barW)

        Place(bar, CENTER, c.infoBarBg, CENTER, 0, 0)
        bar:SetDimensions(g.barW - 2, g.barH - 2)
    else
        c.infoBg:SetDimensions(width, g.infoH)
        c.infoBarBg:SetDimensions(g.barW, g.barH)
        bar:SetDimensions(g.barW - 2, g.barH - 2)

        SetLabelBox(c.infoKD, 220, g.infoH, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

        if mode == "Horizontal" then
            tlw:SetDimensions(width, g.infoH)
            Place(c.infoBg, TOPLEFT, tlw, TOPLEFT, c.infoBg.baseX, c.infoBg.baseY - 20)
            Place(c.infoRankIcon, TOPLEFT, tlw, TOPLEFT, c.infoRankIcon.baseX, c.infoRankIcon.baseY - 20)
            Place(c.infoBarBg, TOPLEFT, tlw, TOPLEFT, c.infoBarBg.baseX, c.infoBarBg.baseY - 20)
            Place(bar, TOPLEFT, tlw, TOPLEFT, bar.baseX, bar.baseY - 20)
            Place(c.infoKD, LEFT, c.infoBarBg, RIGHT, HBAR_KD_GAP, self.config.kdTextNudge or 0)
            SetLabelBox(c.infoKD, 220, g.infoH, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        else
            tlw:SetDimensions(width, self.config.height + self.config.entryHeight * 2 + 20)
            self.headerShift = nil
            self:ApplyHeaderLayout()
        end
    end

    self:RefreshRankLabel()
    self:RefreshKDText()
    self:RefreshVerticalText()
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

function PvPUA:RankDisplayBar(vertical)
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
            if vertical then
                right = self:VerticalProgressText(v.progress, v.total)
            else
                right = ZO_CommaDelimitNumber(v.progress) .. " / " .. ZO_CommaDelimitNumber(v.total)
            end
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
        if vertical then
            right = self:VerticalProgressText(currentXP - lastRankXP, required)
        else
            right = ZO_CommaDelimitNumber(currentXP - lastRankXP) .. " / " .. ZO_CommaDelimitNumber(required)
        end
    end
    return icon, ac.r, ac.g, ac.b, pct, self:RankDisplayLeftText(), right, ac.r, ac.g, ac.b
end

--------------------------------------------------
-- Menu
--------------------------------------------------
function PvPUA:ListMenu()
    local screenW, screenH = ScreenBounds()
    return { type = "submenu",
          name = "|c" .. DC_HEX .. "List|r",
          tooltip = SAVED_ACCOUNT_TIP,
          icon = "EsoUI/Art/Addons/Gamepad/gp_mod_listing_category_uiGraphics.dds",
          options = {
        { type = "dropdown", name = "Layout",
          choices = { LAYOUT_FULL, LAYOUT_RANK_BAR },
          default = LAYOUT_FULL,
          details = function()
              if self:IsRankBarOnly() then
                  return "Hides the list and only shows your rank bar and K/D."
              end
              return "Shows the whole list."
          end,
          getFunc = function() return self:IsRankBarOnly() and LAYOUT_RANK_BAR or LAYOUT_FULL end,
          setFunc = function(val)
              self.savedVariables.listLayout = val
              self:ApplyBarLayout()
              self:UpdateHUDScenes()
          end },
        { type = "dropdown", name = "Orientation",
          choices = { "Horizontal", "Vertical" },
          default = PvPUA.defaults.barOrientation,
          disabled = function() return not self:IsRankBarOnly() end,
          sampleBar = function() return self:RankDisplayBar(self.savedVariables.barOrientation == "Vertical") end,
          sampleVertical = function() return self.savedVariables.barOrientation == "Vertical" end,
          getFunc = function() return self.savedVariables.barOrientation end,
          setFunc = function(val)
              self.savedVariables.barOrientation = val
              self:ApplyBarLayout()
          end },
        { type = "checklist",
          name = "Show List",
          noSelectionText = "None",
          disabled = function() return self:IsRankBarOnly() end,
          choices = {
              { name = "In Combat",     value = "showListInCombat" },
              { name = "In Menus",      value = "showListInMenus" },
              { name = "While Sieging", value = "showListWhileSieging" },
              { name = "While Dead",    value = "showListWhileDead" },
          },
          default = { "showListInCombat", "showListWhileDead" },
          getFunc = function()
              local sv = PvPUA.savedVariables
              local sel = {}
              if sv.showListInCombat ~= false then sel[#sel + 1] = "showListInCombat" end
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
              sv.showListInCombat = on.showListInCombat == true
              sv.showListInMenus = on.showListInMenus == true
              sv.showListWhileSieging = on.showListWhileSieging == true
              sv.showListWhileDead = on.showListWhileDead == true
              PvPUA:UpdateHUDScenes()
          end },
        { type = "toggle", name = "Preview",
          details = function()
              if self:IsRankBarOnly() then
                  return "Shows the rank bar and K/D here so you can size and position them. Turns off when you close settings."
              end
              return "Shows the list here so you can size and position it. Turns off when you close settings."
          end,
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
          disabled = function() return self:IsRankBarOnly() end,
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
          disabled = function() return self:IsRankBarOnly() end,
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
          sampleBar = function() return self:RankDisplayBar(self:IsVerticalBar()) end,
          sampleVertical = function() return self:IsVerticalBar() end,
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
          disabled = function() return self:IsRankBarOnly() end,
          default = PvPUA.defaults.font,
          sample = function() return PVPUA_MENU_TITLE_COLORED, DetailsFont(self.savedVariables.font, 40), 1, 1, 1 end,
          getFunc = function() return self.savedVariables.font end,
          setFunc = function(val) self.savedVariables.font = val; self:InvalidateFontCache() end,
        },
        { type = "colorpicker", name = RainbowText("Timer Color"),
          disabled = function() return self:IsRankBarOnly() end,
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
          disabled = function() return self:IsRankBarOnly() end,
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
          disabled = function() return self:IsRankBarOnly() end,
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
