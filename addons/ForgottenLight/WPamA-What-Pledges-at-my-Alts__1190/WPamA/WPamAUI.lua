local WPamA = WPamA
local nvl = WPamA.SF_NvlN

function WPamA:SetScaledText(ctrlName, strText, baseFontSize)
  if baseFontSize == nil then baseFontSize = 18 end
  local ScaledTextFormatter = self.Consts.ScaledTextFormatter
--  if self.i18n.Lng == "RU" and RuESO_init ~= nil then strFont1 = "RuEso/fonts/univers57.otf|" end -- chat font from RuESO
  ctrlName:SetFont( zo_strformat(ScaledTextFormatter, baseFontSize) )
  ctrlName:SetText(strText)
  while ctrlName:WasTruncated() do
    baseFontSize = baseFontSize - 1
    ctrlName:SetFont( zo_strformat(ScaledTextFormatter, baseFontSize) )
    if baseFontSize < 10 then break end
  end
end

function WPamA:UI_InitMainWindow()
  local i18n = self.i18n
-- Create UI controls and links for quick access
  self.ctrlTabs = {}
  self.ctrlTbBG = {}
  for i = 1, self.TabBCount do
    local tb = GetControl(WPamA_Win,"TabsB" .. i)
    self.ctrlTabs[i] = tb
    tb:SetFont("$(CHAT_FONT)|18|soft-shadow-thin")
    local bg = GetControl(WPamA_Win,"TabsBG" .. i)
    self.ctrlTbBG[i] = bg
    bg:SetCenterColor(self:GetColor(self.Colors.BGTabCenter))
    bg:SetEdgeColor(self:GetColor(self.Colors.BGTabEdge))
  end
  self.ctrlRows = {}
-- Main: Header
  self.ctrlRows[0] = {
    Row = GetControl(WPamA_Win,"Headers"),
  }
  local r = self.ctrlRows[0]
  r.Lvl = GetControl(r.Row, "Lvl")
  r.Char = GetControl(r.Row, "Char")
  r.B = {}
  for j = 1, self.ColBCount do
    r.B[j] = GetControl(r.Row, "B" .. j)
  end
-- Main: Rows
  for i = 1, self.Consts.RowCnt do
    self.ctrlRows[i] = {
      Row = CreateControlFromVirtual("WPamA_WinRow", WPamA_Win, "WPamA_WinVRow", i),
    }
    local r = self.ctrlRows[i]
    r.Row:SetAnchor(TOPLEFT, self.ctrlRows[i-1].Row, BOTTOMLEFT, 0, 0)
    r.BG = GetControl(r.Row, "BG")
    r.BG:SetAnchorFill()
    --r.BG:SetAnchor(TOPLEFT, r.Row, TOPLEFT, 0, -1)
    --r.BG:SetDimensions(self.Consts.WinSizeMinX, self.Consts.WinSizeStepY+2)
    r.BG:SetCenterColor(self:GetColor(self.Colors.BGCenter))
    r.BG:SetEdgeColor(self:GetColor(self.Colors.BGEdge))
    r.Lvl = GetControl(r.Row, "Lvl")
    r.Char = GetControl(r.Row, "Char")
    r.B = {}
    for j = 1, self.ColBCount do
      r.B[j] = GetControl(r.Row, "B" .. j)
    end
  end
-- Main: Msg
  self.ctrlWMsg = {}
  for i = 1, 2 do
    self.ctrlWMsg[i] = {
      Row = GetControl(WPamA_Msg, "R" .. i),
      B = {},
    }
    local r = self.ctrlWMsg[i]
    r.Txt = GetControl(r.Row, "Txt")
--    self.SetToolTip(r.Txt, -1)
    for j = 1, self.ColBCount do
      r.B[j] = GetControl(r.Row, "B" .. j)
    end
  end
-- Main: Select Mode
  self.ctrlWSelMode = {}
  local n  = self.WindCount
  WPamA_SelWind:SetDimensions(i18n.SelModeWin.x, i18n.SelModeWin.y + i18n.SelModeWin.dy * n)
  for j = 0, n-1 do
    local c = GetControl(WPamA_SelWind, "Wind" .. j)
    if c then
      self.ctrlWSelMode[j] = c
      c:SetText((j+1) .. ". " .. i18n.Wind[j].Capt)
    end
  end
-- Main: Button
  self.SetToolTip(WPamA_WinClose, 0, nil, true)
  self.SetToolTip(WPamA_WinOptions, 1, nil, true)
  self.SetToolTip(WPamA_WinSwap, 2, nil, true)
  self.SetToolTip(WPamA_WinChatTd, 3, nil, true)
  self.SetToolTip(WPamA_WinLFGP, 10, nil, true)
end 

function WPamA:UI_SelWindUpdColor()
  local m = false
  local cle = self.Colors.MenuEnabled
  local cla = self.Colors.MenuActive
  local cld = self.Colors.MenuDisabled
  local n  = self.WindCount
  local WinInd = n
  if self.SV_Main ~= nil then
    if self.SV_Main.isWindVisible ~= nil then
      m = self.SV_Main.isWindVisible
    end
    if self.SV_Main.ShowMode ~= nil then
      WinInd = self.ModeSettings[self.SV_Main.ShowMode].WinInd
    end
  end
  for j = 0, n-1 do
    local c = self.ctrlWSelMode[j]
    if c then
      if WinInd == j then
        c:SetColor(self:GetColor(cla))
      elseif m == false or m[j] then
        c:SetColor(self:GetColor(cle))
      else
        c:SetColor(self:GetColor(cld))
      end
    end
  end
end 

function WPamA:RGLACtrlSetText(i, s)
  local x = 1
  if s == "" or type(s) ~= "string" then
    self.ctrlRGLA[i]:SetText("")
  else
    self.ctrlRGLA[i]:SetText(s)
    local l = string.len(s)
    if l <= 3 then x = 43
    elseif l == 4 then x = 50
    else x = 63
    end
  end
  self.ctrlRGLA[i]:SetDimensions(x, self.Consts.TabsHeight)
end

function WPamA:UI_InitRGLAWindow()
  local i18n = self.i18n
-- RGLA Main
  self.ctrlRGLA = {}
  for j = 1, 6 do
    self.ctrlRGLA[j] = GetControl(WPamA_RGLA, "B" .. j)
    self:RGLACtrlSetText(j, self.WorldBosses.Bosses[j].H)
  end
  self.SetToolTip(WPamA_RGLAClose, 0, nil, true)
  self.SetToolTip(WPamA_RGLAOptions, 1, nil, true)
  WPamA_RGLAStart:SetText(i18n.RGLAStart) 
  WPamA_RGLAPost:SetText(i18n.RGLAPost) 
  WPamA_RGLAStop:SetText(i18n.RGLAStop) 
  WPamA_RGLAShare:SetText(i18n.RGLAShare)
-- RGLA Msg
  WPamA_RGLA_MsgLangTxt:SetText(i18n.RGLALangTxt) 
  for j = 1, self.Consts.RGLAMsgCnt do
    GetControl(WPamA_RGLA_Msg, "Txt" .. j):SetText(i18n.RGLAMsg[j])
  end
end 

function WPamA:UI_UpdMainWindowSize(ShowMode, z)
  local c = self.Consts
  local dx = c.WinSizeMinX
  local dy = c.WinSizeMinY
  local m = self.ModeSettings[ShowMode]
  if self.SV_Main and self.SV_Main.AlwaysMaxWinX then
    dx = c.WinSizeMaxX
  elseif m and m.WinX then
    dx = m.WinX
  end
  if z == 0 then
    dy = dy + c.WinSizeStepY
  else
    dy = dy + c.WinSizeStepY * z
  end
  WPamA_Win:SetDimensions(dx, dy)
  WPamA_WinLine1:SetDimensions(dx+70, 3)
  WPamA_WinLine2:SetDimensions(dx+70, 3)
  for i = 0, c.RowCnt do
    self.ctrlRows[i].Row:SetDimensions(dx, c.WinSizeStepY)
  end

  self.ShowMsg = false
  if WPamA_Msg ~= nil then
    if ShowMode == 25 or type(self.Inventory.InvtItemModes[ShowMode]) == "number" then
      self.ShowMsg = true
      WPamA_Msg:SetDimensions(dx, c.WinMsgSizeMaxY)
      for i = 1, 2 do
        local r = self.ctrlWMsg[i]
        r.Row:SetHidden(false)
        r.Txt:SetText(self.i18n.TotalRow[i])
        r.Txt:SetDimensions(c.MsgSizeMinX, c.MsgSizeMinY)
        for j = 1, self.ColBCount do
          r.B[j]:SetHidden(false)
        end
      end
      WPamA_Msg:SetHidden(WPamA_Win:IsHidden())
    else
      WPamA_Msg:SetHidden(true)
    end
  end
end 

function WPamA:GetChmpStr()
  local s = zo_strformat(" (|cCFDCBD<<2>><<1>>|r)", tostring(self.ChmPoints),
                         self.EnlitState and self.Consts.IconsW.ChmEnl or self.Consts.IconsW.Chm)
  return s
end 

local function ShrinkLabelWidth(ctrl, dx, dy, txt)
  if dx <= 28 then
    ctrl:SetDimensions(28, dy)
    return 28
  end
  local x = dx + 5
  ctrl:SetDimensions(x, dy)
  while not ctrl:WasTruncated() and x > 23 do
    x = x - 1
    ctrl:SetDimensions(x, dy)
  end
  x = x + 5
  ctrl:SetDimensions(x, dy)
--  d(x .. " " .. txt)
  return x
end

function WPamA:UI_UpdMainWindowTabs()
  local SV = self.SV_Main
  local MS = self.ModeSettings[SV.ShowMode]
  local TI = MS.TabInd
  local WS = self.WindSettings[MS.WinInd]
  local WSln = self.i18n.Wind[MS.WinInd]
  local clr = self.Colors
  local TabsHeight = self.Consts.TabsHeight
  for i = 1, self.TabBCount do
    local t = self.ctrlTabs[i]
    local g = self.ctrlTbBG[i]
    local m = WS.Mds[i]
    local b = WSln.Tab[i]
    g:SetHidden(true)
    if (m == nil) or (b == nil) then
      ---- g:SetHidden(true)
      t:SetMouseEnabled(false)
      t:SetHidden(true)
      t:SetText("")
      t:SetDimensions(1, TabsHeight)
      self.DelToolTip(t)
    else
      t:SetHidden(false)
      ---- t:SetText(b.N)
      --[[ if i == TI then -- and b.S == true
        g:SetHidden(false)
      else
        g:SetHidden(true)
      end --]]
      --- Set Tab label name ---
      local TabName = ""
      if i == TI then
        g:SetHidden(false)
        t:SetColor(self:GetColor(clr.TabActive))
        TabName = b.NC or b.N or ""
      elseif (m ~= nil) and SV.isModeVisible[m] then
        t:SetColor(self:GetColor(clr.TabEnabled))
        TabName = b.N or ""
      else
        t:SetColor(self:GetColor(clr.TabDisabled))
        TabName = b.NC or b.N or ""
      end
      t:SetText(TabName)
      --- Set Tab dimensions ---
      if b.Wx ~= nil then
        t:SetDimensions(b.Wx, TabsHeight)
      else
        b.Wx = ShrinkLabelWidth(t, b.W, TabsHeight, b.N)
      end
      --- Set Title tooltip ---
      if (m ~= nil) and SV.TitleToolTip then
        self.SetToolTip(t, self.ModeSettings[m].TT, b.A)
      elseif (b.S == true) and (b.A ~= nil) then
        self.SetTxtToolTip(t, b.A)
      else
        self.DelToolTip(t)
      end
      t:SetMouseEnabled(true)
    end
  end -- for TabBCount
end -- UI_UpdMainWindowTabs end

function WPamA:UI_UpdMainWindowHdr()
  local SV = self.SV_Main
  local ShowMode = SV.ShowMode
  local MS = self.ModeSettings[ShowMode]
  local i18n = self.i18n
  local TitleTxt = zo_strformat("<<1>> v<<2>> - <<3>>", self.Name, self.Version, i18n.Wind[MS.WinInd].Capt)
  local clr = self.Colors
--> Resize & show/hide Tabs
  self:UI_UpdMainWindowTabs()
--> Resize & show/hide column for all rows
  for i = 0, self.Consts.RowCnt do
    local r = self.ctrlRows[i]
    local w = {}
    local a = {}
    if i == 0 and MS.Hdr then w = MS.Hdr else w = MS.Col end
    if i == 0 and MS.HdA then a = MS.HdA else a = MS.ClA end
    if ShowMode == 22 then -- AvA Daily Rewards mode
      r.Char:SetDimensions(3 * self.Consts.CharColSize, self.Consts.ModeColHeight)
    elseif ShowMode == 27 then -- Endeavor mode
      r.Char:SetDimensions(3 * self.Consts.CharColSize, self.Consts.ModeColHeight)
    elseif ShowMode == 38 then -- World Events mode
      r.Char:SetDimensions(2 * self.Consts.CharColSize, self.Consts.ModeColHeight)
    else -- all modes by default
      r.Char:SetDimensions(self.Consts.CharColSize, self.Consts.ModeColHeight)
    end
    for j = 1, self.ColBCount do
      r.B[j]:SetMouseEnabled(i == 0)
      self.DelToolTip(r.B[j])
      r.B[j]:SetText("")
      if w[j] == nil then
        r.B[j]:SetHidden(true)
      else
        r.B[j]:SetHidden(false)
        r.B[j]:SetDimensions(w[j], self.Consts.ModeColHeight)
      end
      if a == nil or a[j] == nil then
        r.B[j]:SetHorizontalAlignment(TEXT_ALIGN_CENTER)  --TEXT_ALIGN_LEFT
      else
        r.B[j]:SetHorizontalAlignment(a[j])
      end
    end
  end
  if ShowMode == 25 or type(self.Inventory.InvtItemModes[ShowMode]) == "number" then
    local w = MS.Col
    for i=1,2 do
      local r = self.ctrlWMsg[i]
      for j=1,self.ColBCount do
        if w[j] == nil then
          r.B[j]:SetHidden(true)
        else
          r.B[j]:SetHidden(false)
          r.B[j]:SetDimensions(w[j], self.Consts.ModeColHeight)
        end
      end
    end
  end
--> The following code is only for the column 0 (header)
  local r = self.ctrlRows[0]
--> Common column: Lvl & Char
  if ShowMode == 1 then
    r.Char:SetText(i18n.HdrClnd)
    r.Lvl:SetText("")
  elseif ShowMode == 22 then
    r.Char:SetText(i18n.HdrAvAReward)
    r.Lvl:SetText("")
  elseif ShowMode == 27 then
    local taName = GetString(SI_TIMED_ACTIVITIES_TITLES)
    r.Char:SetText(taName)
    r.Lvl:SetText("")
  elseif ShowMode == 38 then
    local lvlTxt, charTxt = self:GetWEModeColumnNames("A")
    r.Char:SetText(charTxt)
    r.Lvl:SetText(lvlTxt)
  else
    r.Char:SetText(i18n.HdrName)
    r.Lvl:SetText(i18n.HdrLvl)
  end
--> Title and Colunm group array "B[]"
  for j = 1, self.ColBCount do
    if MS.BTTA then
      self.SetToolTip(r.B[j], MS.BTT[j], MS.BTTA[j])
    else
      self.SetToolTip(r.B[j], MS.BTT[j])
    end
    if MS.HdT[j] then
      self:SetScaledText(r.B[j], MS.HdT[j])
    end
  end
--> Unique for some modes
  if ShowMode == 7 then
    self:SetScaledText(r.B[1], i18n.HdrLFGRnd)
    self:SetScaledText(r.B[2], i18n.HdrLFGBG)
    self:SetScaledText(r.B[3], i18n.HdrLFGTrib)
  elseif ShowMode < 2 then
    self:SetScaledText(r.B[2], i18n.HdrMaj)
    self:SetScaledText(r.B[4], i18n.HdrGlirion)
    self:SetScaledText(r.B[6], i18n.HdrUrgarlag)
  elseif ShowMode == 38 then
    local txtB1, txtB2, txtB3 = self:GetWEModeColumnNames("B")
    self:SetScaledText(r.B[1], txtB1)
    self:SetScaledText(r.B[2], txtB2)
    self:SetScaledText(r.B[3], txtB3)
  end
  TitleTxt = TitleTxt .. self:GetChmpStr()
--> Set title
  WPamA_WinTitle:SetText(TitleTxt)
  self.DelToolTip(WPamA_WinTitle)
  if SV.TitleToolTip and IsEnlightenedAvailableForAccount() then
    if self.EnlitState then
      self.SetToolTip(WPamA_WinTitle, self.Consts.TTEnlOn)
    else
      self.SetToolTip(WPamA_WinTitle, self.Consts.TTEnlOff)
    end
  end
end 

-- ==== EVENT FUNCTIONS ==== --
-- Function header in this section must use "." instead ":".
-- Also inside the function can not be used "self".
-- Instead, it must explicitly specify the variable
function WPamA.DelToolTip(ctrl, alwaysME)
  if alwaysME ~= true then
    ctrl:SetMouseEnabled(false)
  end
  ctrl:SetHandler("OnMouseEnter", nil)
  ctrl:SetHandler("OnMouseExit", nil)
end

function WPamA.SetToolTip(ctrl, var, addTxt, alwaysME)
  if var == nil or WPamA.i18n.ToolTip == nil then
    WPamA.DelToolTip(ctrl, alwaysME)
  else
    local txt = WPamA.i18n.ToolTip[var]
    if addTxt ~= nil and addTxt ~= "" then
      if txt == nil or txt == "" then
        txt = addTxt
      else
        txt = txt .. "\n" .. addTxt
      end
    end
    if txt == nil or txt == "" then
      WPamA.DelToolTip(ctrl, alwaysME)
    else
      ctrl:SetMouseEnabled(true)
      ctrl:SetHandler("OnMouseEnter", function(self) ZO_Tooltips_ShowTextTooltip(ctrl, TOP, txt) end)
      ctrl:SetHandler("OnMouseExit", function(self) ZO_Tooltips_HideTextTooltip() end)
    end
  end
end

function WPamA.SetTxtToolTip(ctrl, txt, alwaysME)
  if txt == nil or txt == "" then
    WPamA.DelToolTip(ctrl, alwaysME)
  else
    ctrl:SetMouseEnabled(true)
    ctrl:SetHandler("OnMouseEnter", function(self) ZO_Tooltips_ShowTextTooltip(ctrl, TOP, txt) end)
    ctrl:SetHandler("OnMouseExit", function(self) ZO_Tooltips_HideTextTooltip() end)
  end
end

function WPamA.SetItemToolTip(ctrl, itemLink, alwaysME)
  if (itemLink == nil) or (itemLink == "") then
    WPamA.DelToolTip(ctrl, alwaysME)
  else
    ctrl:SetMouseEnabled(true)
    ctrl:SetHandler("OnMouseEnter", 
      function(self)
        WPamA.ITT_IsShowed = true
        local hld = WPamA.SV_Main.WinMain
        local a = WPamA.tWinAlignSettings[hld.m]
        InitializeTooltip(WPamA_ITT, WPamA_Win, a.f, a.x * 40, 0, a.t)
        WPamA_ITT:SetLink(itemLink)
      end
    )
    ctrl:SetHandler("OnMouseExit",
      function(self) 
        WPamA.ITT_IsShowed = nil
        ClearTooltip(WPamA_ITT) 
      end
    )
  end
end

function WPamA.ClearItemToolTip()
  if WPamA.ITT_IsShowed == true then
    WPamA.ITT_IsShowed = nil
    ClearTooltip(WPamA_ITT)
  end
end

function WPamA.SetAchvToolTip(ctrl, aId, aProgress, aTS, alwaysME)
  if aId == nil then
    WPamA.DelToolTip(ctrl, alwaysME)
  else
    ctrl:SetMouseEnabled(true)
    ctrl:SetHandler("OnMouseEnter",
      function(self)
--[[
        local anchor = ZO_Anchor:New(RIGHT, WPamA_Win, LEFT, 0)
        ACHIEVEMENTS.tooltip.parentControl:ClearAnchors()
        anchor:Set(ACHIEVEMENTS.tooltip.parentControl)
--]]
        ACHIEVEMENTS.tooltip:Show(aId, aProgress, aTS)
      end )
    ctrl:SetHandler("OnMouseExit", function(self) ACHIEVEMENTS.tooltip:Hide() end )
  end
end

function WPamA.SetAbilityToolTip(ctrl, abilityId)
  if (abilityId == nil) or (abilityId < 1) then
    ClearTooltip(SkillTooltip)
    --ClearTooltip(AbilityTooltip)
  else
    ctrl:SetMouseEnabled(true)
    ctrl:SetHandler("OnMouseEnter", 
      function(self)
        --- extended ability tooltip (an ability as a skill) ---
        InitializeTooltip(SkillTooltip, ctrl, TOPRIGHT, -5, 0, TOPLEFT)
        SkillTooltip:SetAbilityId(abilityId)
        --- standard ability tooltip ---
        --InitializeTooltip(AbilityTooltip, ctrl, RIGHT, -5, 0, LEFT)
        --AbilityTooltip:SetAbilityId(abilityId)
      end
    )
    ctrl:SetHandler("OnMouseExit",
      function(self)
        ClearTooltip(SkillTooltip)
        --ClearTooltip(AbilityTooltip)
      end
    )
  end
end -- SetAbilityToolTip end
