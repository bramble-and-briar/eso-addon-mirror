local IA_MultiIconTimer = ZO_Object:Subclass ( )

function IA_MultiIconTimer:New ( )
  local timer = ZO_Object.New ( self )
  timer.alpha = 0
  timer.cycle = 0
  timer.multiIcons = { }

  timer.timeline = ANIMATION_MANAGER:CreateTimelineFromVirtual ( "IA_MultiIconAnimation" )
  timer.timeline.object = timer
  timer.timeline:PlayFromStart ( )

  return timer
end

function IA_MultiIconTimer:SetupMultiIcon ( multiIcon )
  if #multiIcon.iconTextures > 0 then
    local index = ( self.cycle % #multiIcon.iconTextures ) + 1
    multiIcon:SetTexture ( multiIcon.iconTextures [ index ].icon )
    multiIcon:SetColor ( multiIcon.iconTextures [ index ].color.r, multiIcon.iconTextures [ index ].color.g, multiIcon.iconTextures [ index ].color.b, multiIcon.iconTextures [ index ].color.a )
    multiIcon:SetAlpha ( self.alpha ) 
  end
end

function IA_MultiIconTimer:AddMultiIcon ( multiIcon )
  table.insert ( self.multiIcons, multiIcon )
  self:SetupMultiIcon ( multiIcon )
end

function IA_MultiIconTimer:RemoveMultiIcon ( multiIcon )
  for i = 1, #self.multiIcons do
    if ( self.multiIcons [ i ] == multiIcon ) then
      table.remove ( self.multiIcons, i )
      break
    end
  end
end

function IA_MultiIconTimer:SetAlphas ( alpha )
  self.alpha = alpha
  for i = 1, #self.multiIcons do
    self.multiIcons [ i ]:SetAlpha ( alpha )
  end
end

function IA_MultiIconTimer:OnAnimationComplete ( )
  self.cycle = ( self.cycle + 1 ) % 100
  for i = 1, #self.multiIcons do
    self:SetupMultiIcon ( self.multiIcons [ i ] )
  end
  self.timeline:PlayFromStart ( )
end

--Global XML

function IA_MultiIconAnimation_SetAlpha ( animation, alpha )
  animation:GetTimeline ( ).object:SetAlphas ( alpha )
end

function IA_MultiIconAnimation_OnStop ( timeline )
  if timeline:GetProgress ( ) == 1 then
    timeline.object:OnAnimationComplete ( )
  end
end

do
  local MULTI_ICON_TIMER
  
  local function ClearIcons ( self )
    if self.iconTextures then
      ZO_ClearNumericallyIndexedTable ( self.iconTextures )
    end
  end

  local function AddIcon ( self, iconTexture )
    if not self.iconTextures then
      self.iconTextures = { }
    end
    table.insert ( self.iconTextures, iconTexture )
  end

  function IA_MultiIcon_OnShow ( self )
    if self.iconTextures then
      if #self.iconTextures > 1 then
        MULTI_ICON_TIMER:AddMultiIcon ( self )
      else
        MULTI_ICON_TIMER:RemoveMultiIcon ( self )
        self:SetTexture ( self.iconTextures [ 1 ].icon )
        self:SetColor ( self.iconTextures [ 1 ].color.r, self.iconTextures [ 1 ].color.g, self.iconTextures [ 1 ].color.b, self.iconTextures [ 1 ].color.a )
        self:SetAlpha ( 1 ) 
      end
    end
  end

  function IA_MultiIcon_OnHide ( self )
    if self.iconTextures then
      if #self.iconTextures > 1 then
        MULTI_ICON_TIMER:RemoveMultiIcon ( self )
      end
    end
  end

  function IA_MultiIcon_Initialize ( self )
    if not MULTI_ICON_TIMER then
      MULTI_ICON_TIMER = IA_MultiIconTimer:New ( )
    end

    self.ClearIcons = ClearIcons
    self.AddIcon = AddIcon
  end
end