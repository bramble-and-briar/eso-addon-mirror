-- local LAM = LibAddonMenu2
local Util = DariansUtilities
local CM = CombatMetronome
CombatMetronome.SV = CombatMetronome.SV or {}

local MIN_WIDTH = 50
local MAX_WIDTH = GuiRoot:GetWidth()
local MIN_HEIGHT = 10
local MAX_HEIGHT = 100

	---------------------------
	---- Build Progressbar ----
	---------------------------

function CombatMetronome:BuildUI()

	-------------------------
	---- Create Controls ----
	-------------------------
	
	local function CreateControls()
	
		self.Progressbar.frame = self.Progressbar.frame or Util.Controls:NewFrame(self.name.."ProgressbarFrame", "Progressbar")
		self.Progressbar.frame:SetDimensionConstraints(MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT)
		self.Progressbar.frame:SetHandler("OnMoveStop", function(...)
			CombatMetronome.SV.Progressbar.xOffset = self.Progressbar.frame:GetLeft()
			CombatMetronome.SV.Progressbar.yOffset = self.Progressbar.frame:GetTop()
			self.Progressbar.UI.Anchors()
			-- self:BuildUI()
		end)
		self.Progressbar.frame:SetHandler("OnResizeStop", function(...)
			CombatMetronome.SV.Progressbar.width = self.Progressbar.frame:GetWidth()
			CombatMetronome.SV.Progressbar.height = self.Progressbar.frame:GetHeight()
			self.Progressbar.UI.Size()
			-- self:BuildUI()
		end)
				
		self.Progressbar.bar = self.Progressbar.bar or Util.Bar:New(self.name.."TimerBar", self.Progressbar.frame)
		self.Progressbar.bar.background:SetEdgeTexture("/esoui/art/miscellaneous/borderedinsettransparent_edgefile.dds", 128, 16, CombatMetronome.SV.Progressbar.height/3)
		
		self.Progressbar.spellIcon = self.Progressbar.spellIcon or WINDOW_MANAGER:CreateControl(self.name.."SpellIcon", self.Progressbar.frame, CT_TEXTURE)
		self.Progressbar.spellIcon:SetDrawLayer(4)
		self.Progressbar.spellIcon:SetDrawTier(2)
		self.Progressbar.spellIconBorder = self.Progressbar.spellIconBorder or WINDOW_MANAGER:CreateControl(self.name.."SpellIconBorder", self.Progressbar.spellIcon, CT_TEXTURE)
		self.Progressbar.spellIconBorder:SetTexture("/esoui/art/actionbar/abilityframe64_up.dds")
		self.Progressbar.spellIconBorder:SetDrawLayer(4)
		self.Progressbar.spellIconBorder:SetDrawTier(2)
	
		self.Progressbar.bar.backgroundTexture = self.Progressbar.bar.backgroundTexture or WINDOW_MANAGER:CreateControl(self.name.."BackgroundTexture", self.Progressbar.frame, CT_STATUSBAR)
		self.Progressbar.bar.backgroundTexture:SetTexture("/esoui/art/unitattributevisualizer/gamepad/gp_attributebar_dynamic_fill_gloss.dds")
		self.Progressbar.bar.backgroundTexture:SetTextureCoords(0, 1, 0.5, 0.36)
		self.Progressbar.bar.backgroundTexture:SetDrawLayer(4)
		self.Progressbar.bar.backgroundTexture:SetDrawTier(2)
		self.Progressbar.bar.borderL = self.Progressbar.bar.borderL or WINDOW_MANAGER:CreateControl(self.name.."SpellBarBorderL", self.Progressbar.frame, CT_TEXTURE)
		self.Progressbar.bar.borderL:SetTexture("/esoui/art/unitframes/playercastbar_inset_left.dds")
		self.Progressbar.bar.borderL:SetDrawLayer(2)
		self.Progressbar.bar.borderL:SetDrawTier(1)
		self.Progressbar.bar.borderL:SetDesaturation(1)
		self.Progressbar.bar.borderR = self.Progressbar.bar.borderR or WINDOW_MANAGER:CreateControl(self.name.."SpellBarBorderR", self.Progressbar.frame, CT_TEXTURE)
		self.Progressbar.bar.borderR:SetTexture("/esoui/art/unitframes/playercastbar_inset_right.dds")
		self.Progressbar.bar.borderR:SetDrawLayer(2)
		self.Progressbar.bar.borderR:SetDrawTier(1)
		self.Progressbar.bar.borderR:SetDesaturation(1)

		self.Progressbar.spellLabel = self.Progressbar.spellLabel or WINDOW_MANAGER:CreateControl(self.name.."SpellLabel", self.Progressbar.frame, CT_LABEL)
		self.Progressbar.spellLabel:SetColor(1, 1, 1, 1)
		self.Progressbar.spellLabel:SetText("")
		self.Progressbar.spellLabel:SetDrawLayer(4)
		self.Progressbar.spellLabel:SetDrawTier(2)
		
		self.Progressbar.timeLabel = self.Progressbar.timeLabel or WINDOW_MANAGER:CreateControl(self.name.."TimeLabel", self.Progressbar.frame, CT_LABEL)
		self.Progressbar.timeLabel:SetColor(1, 1, 1, 1)
		self.Progressbar.timeLabel:SetText("")
		self.Progressbar.timeLabel:SetDrawLayer(4)
		self.Progressbar.timeLabel:SetDrawTier(2)
			
    -------------------------------
	---- Create label Controls ----
	-------------------------------

		self.Resources = self.Resources or {}
		self.Resources.frame = self.Resources.frame or Util.Controls:NewFrame(self.name.."ResourcesFrame", "Resource Labels")
		self.Resources.frame:SetDimensionConstraints(MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT)
		self.Resources.frame:SetHandler("OnMoveStop", function(...)
			CombatMetronome.SV.Resources.xOffset = self.Resources.frame:GetLeft()
			CombatMetronome.SV.Resources.yOffset = self.Resources.frame:GetTop()
		end)
		self.Resources.frame:SetHandler("OnResizeStop", function(...)
			CombatMetronome.SV.Resources.width = self.Resources.frame:GetWidth()
			CombatMetronome.SV.Resources.height = self.Resources.frame:GetHeight()
		end)

		self.Resources.ultLabel = self.Resources.ultLabel or WINDOW_MANAGER:CreateControl(self.name.."UltLabel", self.Resources.frame, CT_LABEL)
		self.Resources.ultLabel:SetText("")

		self.Resources.stamLabel = self.Resources.stamLabel or WINDOW_MANAGER:CreateControl(self.name.."StamLabel", self.Resources.frame, CT_LABEL)
		self.Resources.stamLabel:SetText("")

		self.Resources.magLabel = self.Resources.magLabel or WINDOW_MANAGER:CreateControl(self.name.."MagLabel", self.Resources.frame, CT_LABEL)
		self.Resources.magLabel:SetText("")

		self.Resources.hpLabel = self.Resources.hpLabel or WINDOW_MANAGER:CreateControl(self.name.."HPLabel", self.Resources.frame, CT_LABEL)
		self.Resources.hpLabel:SetText("")
		
		--------------------------
		---- Execute Reminder ----
		--------------------------
		
		self.Resources.executeFrame = self.Resources.executeFrame or Util.Controls:NewFrame(self.name.."ExecuteFrame", "")
		self.Resources.executeFrame:ClearAnchors()
		self.Resources.executeFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, CombatMetronome.SV.Resources.executeX, CombatMetronome.SV.Resources.executeY)
		self.Resources.executeFrame:SetUnlocked(CombatMetronome.SV.Resources.unlockExecuteReminder)
		self.Resources.executeFrame:SetHidden(not CombatMetronome.SV.Resources.unlockExecuteReminder)
		self.Resources.executeFrame:SetDimensionConstraints(MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT)
		self.Resources.executeFrame:SetDimensions(CombatMetronome.SV.Resources.executeWidth, CombatMetronome.SV.Resources.executeHeight)
		self.Resources.executeFrame:SetHandler("OnMoveStop", function(...)
			CombatMetronome.SV.Resources.executeX = self.Resources.executeFrame:GetLeft()
			CombatMetronome.SV.Resources.executeY = self.Resources.executeFrame:GetTop()
		end)
		self.Resources.executeFrame:SetHandler("OnResizeStop", function(...)
			CombatMetronome.SV.Resources.executeHeight = self.Resources.executeFrame:GetHeight()
			self.Resources.executeLabel:SetFont(Util.Text.getFontString(tostring("$("..CombatMetronome.SV.Progressbar.labelFont..")"), CombatMetronome.SV.Resources.executeHeight, CombatMetronome.SV.Progressbar.fontStyle))
			CombatMetronome.SV.Resources.executeWidth = self.Resources.executeLabel:GetWidth()
			self.Resources.executeFrame:SetWidth(CombatMetronome.SV.Resources.executeWidth)
			self.Resources.executeLabel:ClearAnchors()
			self.Resources.executeLabel:SetAnchor(TOPLEFT, self.Resources.executeFrame, TOPLEFT, 0, -CombatMetronome.SV.Resources.executeHeight/10)
		end)
		self.Resources.executeLabel = self.Resources.executeLabel or WINDOW_MANAGER:CreateControl(self.name.."ExecuteLabel", self.Resources.executeFrame, CT_LABEL)
		self.Resources.executeLabel:SetText("EXECUTE!")
		self.Resources.executeLabel:SetColor(unpack(CombatMetronome.SV.Resources.executeColor))
		self.Resources.executeLabel:SetFont(Util.Text.getFontString(tostring("$("..CombatMetronome.SV.Progressbar.labelFont..")"), CombatMetronome.SV.Resources.executeHeight, CombatMetronome.SV.Progressbar.fontStyle))
		self.Resources.executeLabel:ClearAnchors()
		self.Resources.executeLabel:SetAnchor(TOPLEFT, self.Resources.executeFrame, TOPLEFT, 0, -CombatMetronome.SV.Resources.executeHeight/10)
		self.Resources.executeLabel:SetHidden(not CombatMetronome.SV.Resources.unlockExecuteReminder)
	end
	
	local function FadeScenes(scene)
		local fragment = ZO_HUDFadeSceneFragment:New(CombatMetronome.Progressbar.frame)
		if scene == "Sample" then
			SCENE_MANAGER:GetScene("gameMenuInGame"):AddFragment(fragment)
		elseif scene == "NoSample" then
			SCENE_MANAGER:GetScene("gameMenuInGame"):RemoveFragment(fragment)
		elseif scene == "NoUI" then
			SCENE_MANAGER:GetScene("hud"):RemoveFragment(fragment)
			SCENE_MANAGER:GetScene("hudui"):RemoveFragment(fragment)
		elseif scene == "UI" then
			SCENE_MANAGER:GetScene("hud"):AddFragment(fragment)
			SCENE_MANAGER:GetScene("hudui"):AddFragment(fragment)
		end
	end
	
	local function Position(value)
		self.Progressbar.frame:ClearAnchors()
		if value == "UI" then
			self.Progressbar.frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, CombatMetronome.SV.Progressbar.xOffset, CombatMetronome.SV.Progressbar.yOffset)
		elseif value == "Sample" then
			self.Progressbar.frame:SetAnchor(RIGHT, GuiRoot, RIGHT, -GuiRoot:GetWidth()/8, -GuiRoot:GetHeight()/6)
		end
	end
	
	local function ResourcesPosition(value)
		self.Resources.frame:ClearAnchors()
		if value == "UI" and CombatMetronome.SV.Resources.anchorResourcesToProgressbar then
			self.Resources.frame:SetAnchor(BOTTOM, self.Progressbar.frame, TOP, 0, 0)
		elseif value == "UI" and not CombatMetronome.SV.Resources.anchorResourcesToProgressbar then
			self.Resources.frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, CombatMetronome.SV.Resources.xOffset, CombatMetronome.SV.Resources.yOffset)
		elseif value == "Sample" and not CombatMetronome.SV.Resources.anchorResourcesToProgressbar then
			self.Resources.frame:SetAnchor(RIGHT, GuiRoot, RIGHT, -GuiRoot:GetWidth()/8, 0)
		elseif value == "Sample" and CombatMetronome.SV.Resources.anchorResourcesToProgressbar then
			self.Resources.frame:SetAnchor(RIGHT, GuiRoot, RIGHT, -GuiRoot:GetWidth()/8, -GuiRoot:GetHeight()/6 - CombatMetronome.SV.Progressbar.height - CombatMetronome.SV.Resources.height/2)
		end
	end
		
	local function Fonts()
		self.Resources.hpLabel:SetFont(Util.Text.getFontString(tostring("$("..CombatMetronome.SV.Progressbar.labelFont..")"), CombatMetronome.SV.Resources.healthSize, CombatMetronome.SV.Progressbar.fontStyle))
		self.Resources.magLabel:SetFont(Util.Text.getFontString(tostring("$("..CombatMetronome.SV.Progressbar.labelFont..")"), CombatMetronome.SV.Resources.magSize, CombatMetronome.SV.Progressbar.fontStyle))
		self.Resources.stamLabel:SetFont(Util.Text.getFontString(tostring("$("..CombatMetronome.SV.Progressbar.labelFont..")"), CombatMetronome.SV.Resources.stamSize, CombatMetronome.SV.Progressbar.fontStyle))
		self.Resources.ultLabel:SetFont(Util.Text.getFontString(tostring("$("..CombatMetronome.SV.Progressbar.labelFont..")"), CombatMetronome.SV.Resources.ultSize, CombatMetronome.SV.Progressbar.fontStyle))
		self.Progressbar.timeLabel:SetFont(Util.Text.getFontString(tostring("$("..CombatMetronome.SV.Progressbar.labelFont..")"), CombatMetronome.SV.Progressbar.spellSize, CombatMetronome.SV.Progressbar.fontStyle))
		self.Progressbar.spellLabel:SetFont(Util.Text.getFontString(tostring("$("..CombatMetronome.SV.Progressbar.labelFont..")"), CombatMetronome.SV.Progressbar.spellSize, CombatMetronome.SV.Progressbar.fontStyle))
	end
	
	local function LabelColors()
		self.Resources.hpLabel:SetColor(unpack(CombatMetronome.SV.Resources.healthColor))
		self.Resources.magLabel:SetColor(unpack(CombatMetronome.SV.Resources.magColor))
		self.Resources.stamLabel:SetColor(unpack(CombatMetronome.SV.Resources.stamColor))
		self.Resources.ultLabel:SetColor(unpack(CombatMetronome.SV.Resources.ultColor))
	end
	
	local function HiddenStates()
		if self.Resources.showSample then
			self.Resources.magLabel:SetHidden(not self.SV.Resources.showMagicka)
			self.Resources.stamLabel:SetHidden(not self.SV.Resources.showStamina)
			self.Resources.ultLabel:SetHidden(not self.SV.Resources.showUltimate)
			self.Resources.hpLabel:SetHidden(not self.SV.Resources.showHealth)
		else
			self.Resources.magLabel:SetHidden(true)
			self.Resources.stamLabel:SetHidden(true)
			self.Resources.ultLabel:SetHidden(true)
			self.Resources.hpLabel:SetHidden(true)
		end
		if self.Progressbar.showSample then
			self.Progressbar.bar:SetHidden(false)
			self.Progressbar.timeLabel:SetHidden(not self.SV.Progressbar.showTimeRemaining)
			self.Progressbar.spellLabel:SetHidden(not self.SV.Progressbar.showSpell)
			self.Progressbar.bar.backgroundTexture:SetHidden(not CombatMetronome.SV.Progressbar.makeItFancy)
			self.Progressbar.bar.borderL:SetHidden(not CombatMetronome.SV.Progressbar.makeItFancy)
			self.Progressbar.bar.borderR:SetHidden(not CombatMetronome.SV.Progressbar.makeItFancy)
			local edgecolor = CombatMetronome.SV.Progressbar.makeItFancy and {1,1,1,1} or {1,1,1,0}
			self.Progressbar.bar.background:SetEdgeColor(unpack(edgecolor))
			self.Progressbar.spellIcon:SetHidden(not self.SV.Progressbar.showSpell)
			self.Progressbar.spellIconBorder:SetHidden(not self.SV.Progressbar.showSpell)
		else
			self.Progressbar.bar:SetHidden(not CombatMetronome.SV.Progressbar.dontHide)
			self.Progressbar.timeLabel:SetHidden(true)
			self.Progressbar.spellLabel:SetHidden(true)
			self.Progressbar.bar.backgroundTexture:SetHidden(not (CombatMetronome.SV.Progressbar.makeItFancy and CombatMetronome.SV.Progressbar.dontHide))
			self.Progressbar.bar.borderL:SetHidden(not (CombatMetronome.SV.Progressbar.makeItFancy and CombatMetronome.SV.Progressbar.dontHide))
			self.Progressbar.bar.borderR:SetHidden(not (CombatMetronome.SV.Progressbar.makeItFancy and CombatMetronome.SV.Progressbar.dontHide))
			local edgecolor = CombatMetronome.SV.Progressbar.makeItFancy and {1,1,1,1} or {1,1,1,0}
			self.Progressbar.bar.background:SetEdgeColor(unpack(edgecolor))
			self.Progressbar.spellIcon:SetHidden(true)
			self.Progressbar.spellIconBorder:SetHidden(true)
		end
	end
	
	local function Anchors()
		self.Progressbar.timeLabel:ClearAnchors()
		self.Progressbar.bar.backgroundTexture:ClearAnchors()
		self.Progressbar.spellIcon:ClearAnchors()
		self.Progressbar.spellIconBorder:ClearAnchors()
		self.Progressbar.spellIconBorder:SetAnchor(CENTER, self.Progressbar.spellIcon, CENTER, 0, 0)
		self.Progressbar.bar.borderR:ClearAnchors()
		self.Progressbar.bar.borderR:SetAnchor(RIGHT, self.Progressbar.bar.background, RIGHT, 0, 0)
		self.Progressbar.bar.borderL:ClearAnchors()
		self.Progressbar.bar.borderL:SetAnchor(LEFT, self.Progressbar.bar.background, LEFT, 0, 0)
		self.Progressbar.spellLabel:ClearAnchors()
		self.Progressbar.spellLabel:SetAnchor(CENTER, self.Progressbar.frame, CENTER, 0, 0)
		self.Progressbar.bar.background:ClearAnchors()
		self.Progressbar.bar.background:SetAnchor(CENTER, self.Progressbar.frame, CENTER, 0, 0)
		if CombatMetronome.SV.Progressbar.barAlign == "Right" then
			self.Progressbar.timeLabel:SetAnchor(LEFT, self.Progressbar.frame, LEFT, (CombatMetronome.SV.Progressbar.height/5), 0)
			self.Progressbar.bar.backgroundTexture:SetAnchor(RIGHT, self.Progressbar.frame, RIGHT, 0, 0)
			self.Progressbar.spellIcon:SetAnchor(LEFT, self.Progressbar.frame, RIGHT, (CombatMetronome.SV.Progressbar.height/10), 0)
			self.Progressbar.bar.align = RIGHT
		elseif CombatMetronome.SV.Progressbar.barAlign == "Left" then
			self.Progressbar.bar.backgroundTexture:SetAnchor(LEFT, self.Progressbar.frame, LEFT, 0, 0)
			self.Progressbar.timeLabel:SetAnchor(RIGHT, self.Progressbar.frame, RIGHT, -(CombatMetronome.SV.Progressbar.height/5), 0) 
			self.Progressbar.spellIcon:SetAnchor(RIGHT, self.Progressbar.frame, LEFT, -(CombatMetronome.SV.Progressbar.height/10), 0)
			self.Progressbar.bar.align = LEFT
		else
			self.Progressbar.bar.backgroundTexture:SetAnchor(CENTER, self.Progressbar.frame, CENTER, 0, 0)
			self.Progressbar.timeLabel:SetAnchor(RIGHT, self.Progressbar.frame, RIGHT, -(CombatMetronome.SV.Progressbar.height/5), 0) 
			self.Progressbar.spellIcon:SetAnchor(RIGHT, self.Progressbar.frame, LEFT, -(CombatMetronome.SV.Progressbar.height/10), 0)
			self.Progressbar.bar.align = CENTER
		end
		
		-----------------------
		---- Label Anchors ----
		-----------------------
		
		self.Resources.hpLabel:ClearAnchors()
		if CombatMetronome.SV.Resources.reticleHp then
			self.Resources.hpLabel:SetAnchor(LEFT, GuiRoot, CENTER, 40, 0)
		else
			self.Resources.hpLabel:SetAnchor(BOTTOMRIGHT, self.Resources.frame, BOTTOMRIGHT, 0, 0)
		end
		self.Resources.magLabel:ClearAnchors()
		self.Resources.stamLabel:ClearAnchors()
		local magActive, stamActive
		magActive = CombatMetronome.SV.Resources.showMagicka or (CombatMetronome.SV.Resources.coralBahsei and CombatMetronome.Resources.bahseiActive)
		stamActive = CombatMetronome.SV.Resources.showStamina or (CombatMetronome.SV.Resources.coralBahsei and CombatMetronome.Resources.coralActive)
		if CombatMetronome.SV.Resources.reticleMagStam then
			if magActive and (not stamActive) then
				self.Resources.magLabel:SetAnchor(RIGHT, GuiRoot, CENTER, -40, 0)
			elseif stamActive and (not magActive) then
				self.Resources.stamLabel:SetAnchor(RIGHT, GuiRoot, CENTER, -40, 0)
			else
				self.Resources.magLabel:SetAnchor(TOPLEFT, GuiRoot, CENTER, -80, 0)
				self.Resources.stamLabel:SetAnchor(BOTTOMLEFT, GuiRoot, CENTER, -80, 0)
			end
		else
			if magActive and (not stamActive) then
				self.Resources.magLabel:SetAnchor(LEFT, self.Resources.frame, LEFT, 0, 0)
			elseif stamActive and (not magActive) then
				self.Resources.stamLabel:SetAnchor(LEFT, self.Resources.frame, LEFT, 0, 0)
			else
				self.Resources.magLabel:SetAnchor(TOPLEFT, self.Resources.frame, TOPLEFT, 0, 0)
				self.Resources.stamLabel:SetAnchor(BOTTOMLEFT, self.Resources.frame, BOTTOMLEFT, 0, 0)
			end
		end
		self.Resources.ultLabel:ClearAnchors()
		self.Resources.ultLabel:SetAnchor(BOTTOM, self.Resources.frame, BOTTOM, 0, 0)
		self.Resources.frame:ClearAnchors()
		if CombatMetronome.SV.Resources.anchorResourcesToProgressbar then
			self.Resources.frame:SetAnchor(BOTTOM, self.Progressbar.frame, TOP, 0, 0)
		else
			self.Resources.frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, CombatMetronome.SV.Resources.xOffset, CombatMetronome.SV.Resources.yOffset)
		end
	end
	
	local function Size()
		self.Progressbar.frame:SetDimensions(CombatMetronome.SV.Progressbar.width, CombatMetronome.SV.Progressbar.height)
		self.Progressbar.bar.background:SetDimensions(CombatMetronome.SV.Progressbar.width, CombatMetronome.SV.Progressbar.height)
		self.Progressbar.bar.borderR:SetDimensions(CombatMetronome.SV.Progressbar.width/2, CombatMetronome.SV.Progressbar.height)
		self.Progressbar.bar.borderL:SetDimensions(CombatMetronome.SV.Progressbar.width/2, CombatMetronome.SV.Progressbar.height)
		self.Progressbar.bar.backgroundTexture:SetDimensions(CombatMetronome.SV.Progressbar.width, CombatMetronome.SV.Progressbar.height)
		self.Progressbar.spellIconBorder:SetDimensions(CombatMetronome.SV.Progressbar.height, CombatMetronome.SV.Progressbar.height)
		self.Progressbar.spellIcon:SetDimensions(CombatMetronome.SV.Progressbar.height, CombatMetronome.SV.Progressbar.height)
		if CombatMetronome.SV.Resources.anchorResourcesToProgressbar then
			CombatMetronome.SV.Resources.width = CombatMetronome.SV.Progressbar.width
			CombatMetronome.SV.Resources.height = 50
		end
		self.Resources.frame:SetDimensions(CombatMetronome.SV.Resources.width, CombatMetronome.SV.Resources.height)
		Anchors()
	end
	
	local function BarColors()
		self.Progressbar.bar.background:SetCenterColor(unpack(CombatMetronome.SV.Progressbar.backgroundColor))
		local edgecolor = CombatMetronome.SV.Progressbar.makeItFancy and {1,1,1,1} or {1,1,1,0}
		self.Progressbar.bar.background:SetEdgeColor(unpack(edgecolor))
		self.Progressbar.bar:UpdateSegment(1, {
			color = CombatMetronome.SV.Progressbar.pingColor,
		})
		self.Progressbar.bar:UpdateSegment(2, {
			color = CombatMetronome.SV.Progressbar.progressColor,
			clip = true,
		})
	end
		
	SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, newState)
		if scene:GetName() == "gameMenuInGame" and newState == "hiding" then
			if self.Progressbar.showSample then
				--if CombatMetronome.SV.debug.enabled then CombatMetronome.debug:Print("should've changed visibility on sampleBar") end
				self.Progressbar.showSample = false
				Position("UI")
				HiddenStates()
			end
			if self.Resources.showSample then
				self.Resources.showSample = false
				ResourcesPosition("UI")
				HiddenStates()
			end
		end
	end)
	
	CreateControls()
	Position()
	Size()
	Anchors()
	BarColors()
	Fonts()
	LabelColors()
	HiddenStates()
	Position("UI")
	ResourcesPosition("UI")
	
	return {
		Fonts = Fonts,
		LabelColors = LabelColors,
		HiddenStates = HiddenStates,
		Anchors = Anchors,
		Size = Size,
		BarColors = BarColors,
		CreateControls = CreateControls,
		FadeScenes = FadeScenes,
		Position = Position,
		ResourcesPosition = ResourcesPosition,
	}
		
end

	-----------------------------
	---- Build Stack Tracker ----
	-----------------------------

CombatMetronome.StackTracker = CombatMetronome.StackTracker or {}
local StackTracker = CombatMetronome.StackTracker

function StackTracker:BuildUI(skill)
	local attributes = self.SKILL_ATTRIBUTES[skill]
	local sv = CombatMetronome.SV.StackTracker[skill]
	local isUnlocked = CombatMetronome.SV.StackTracker.isUnlocked
	local size = sv.indicatorSize
	local distance = size/5
	local multiplier = attributes.multiplier or 1
	
	------------------------------
	---- Build TopLevelWindow ----
	------------------------------
	
	-- if not stacksWindow then
		-- local stacksWindow = Util.Controls:NewFrame(self.name..skill.."StackTrackerWindow")
		local stacksWindow = WINDOW_MANAGER:CreateTopLevelWindow(self.name..skill.."StackTrackerWindow")
		stacksWindow:SetHandler( "OnMoveStop", function(...)
			sv.xOffset = stacksWindow:GetLeft()
			sv.yOffset = stacksWindow:GetTop()
		end)
		stacksWindow:SetDimensions((size*attributes.iMax+distance*(attributes.iMax-1)), size*multiplier)
		stacksWindow:SetMouseEnabled(true)
		stacksWindow:SetMovable(sv.isUnlocked)
		stacksWindow:SetClampedToScreen(true)
		stacksWindow:SetHidden(true)
		-- stacksWindow:SetDrawTier(DT_HIGH)
	-- end
		
	local function Position(value)
		stacksWindow:ClearAnchors()
		if value == "UI" then
			stacksWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.xOffset, sv.yOffset)
		-- elseif value == "Sample" then
			-- stacksWindow:SetAnchor(RIGHT, GuiRoot, RIGHT, -GuiRoot:GetWidth()/8, GuiRoot:GetHeight()/6)
		end
	end
		
	-----------------------------
	---- Generate Indicators ----
	-----------------------------
	
	local indicator = {}

	local function GetIndicator(i)
	
	-----------------------------
	---- Build new indicator ----
	-----------------------------
		
		local stackIndicator = WINDOW_MANAGER:CreateControl(self.name..skill.."StackIndicator"..tostring(i), stacksWindow, CT_CONTROL)
	
		local icon = WINDOW_MANAGER:CreateControl(self.name..skill.."StackIcon"..tostring(i), stackIndicator, CT_TEXTURE)
		icon:ClearAnchors() 
		icon:SetAnchor(TOPLEFT, stackIndicator, TOPLEFT, 0, 0) 
		icon:SetDesaturation(0.1)
	
		local frame = WINDOW_MANAGER:CreateControl(self.name..skill.."StackFrame"..tostring(i), stackIndicator, CT_TEXTURE)
		frame:ClearAnchors()
		frame:SetAnchor(TOPLEFT, stackIndicator, TOPLEFT, 0, 0)
		-- frame:SetTexture("esoui/art/champion/actionbar/champion_bar_slot_frame_disabled.dds")
		frame:SetTexture("/esoui/art/actionbar/abilityframe64_up.dds")
	
		local highlight = WINDOW_MANAGER:CreateControl(self.name..skill.."StackHighlight"..tostring(i), stackIndicator, CT_TEXTURE)
		highlight:ClearAnchors()
		highlight:SetAnchor(TOPLEFT, stackIndicator, TOPLEFT, 0, 0)
		highlight:SetDesaturation(0.4)
		highlight:SetTexture("/esoui/art/actionbar/actionslot_toggledon.dds")
		highlight:SetColor(unpack(attributes.highlight))
		
		local highlightAnimation = WINDOW_MANAGER:CreateControl(self.name..skill.."StackHighlightAnimation"..tostring(i), stackIndicator, CT_TEXTURE)
		highlightAnimation:ClearAnchors()
		highlightAnimation:SetTexture("/esoui/art/actionbar/abilityhighlight_mage_med.dds")
		highlightAnimation:SetDrawTier(DT_HIGH)
		highlightAnimation:SetColor(unpack(attributes.highlightAnimation))
		
		local highlightAnimationTimeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("StackReadyLoop", highlightAnimation)
		highlightAnimation:SetHidden(true)
		
	------------------------------
	---- Highlighting Handler ----
	------------------------------
		
		local function Activate()
			icon:SetColor(1,1,1,0.8)
			highlight:SetAlpha(0.8)
		end

		local function Deactivate()
			icon:SetColor(0.1,0.1,0.1,0.7)
			highlight:SetAlpha(0)
		end
		
		local function Animate()
			--if CombatMetronome.SV.debug.enabled then CombatMetronome.debug:Print(tostring(highlightAnimationTimeline:GetDuration())) end
			-- highlightAnimation:SetHidden(false)
			highlightAnimationTimeline:PlayFromStart()
			--if CombatMetronome.SV.debug.enabled then CombatMetronome.debug:Print("Animation should've started") end
		end
		
		local function StopAnimation()
			highlightAnimationTimeline:Stop()
			-- highlightAnimation:SetHidden(true)
			--if CombatMetronome.SV.debug.enabled then CombatMetronome.debug:Print("Animation should've stopped") end
		end
		
		local function SetAnimationHidden(value)
			highlightAnimation:SetHidden(value)
		end
		
		local controls = {
		stackIndicator = stackIndicator,
		frame = frame,
		icon = icon,
		highlight = highlight,
		highlightAnimation = highlightAnimation,
		highlightAnimationTimeline = highlightAnimationTimeline,
		}
		return {
		stacksWindow = stacksWindow,
		controls = controls,
		Activate = Activate,
		Deactivate = Deactivate,
		Animate = Animate,
		StopAnimation = StopAnimation,
		SetAnimationHidden = SetAnimationHidden,
		}
	end

	for i =1,attributes.iMax*multiplier do 
		indicator[i] = GetIndicator(i)
	end
	
		------------------------
		---- Timer Controls ----
		------------------------
		
	local function CreateTimerControls()
		local windowWidth = stacksWindow:GetWidth()
		local timer = WINDOW_MANAGER:CreateControl(self.name..skill.."BuffTimer", stacksWindow, CT_LABEL)
		timer:SetDrawTier(DT_HIGH)
		timer:SetColor(unpack(attributes.highlight))
		timer:SetAlpha(1)
		timer:SetFont(Util.Text.getFontString(tostring("$(BOLD_FONT)"), size*multiplier, "outline"))
		timer:SetHidden(not (isUnlocked and sv.showTimer))
		timer:SetText("2.5s")
		
		local timerBarBackdrop = WINDOW_MANAGER:CreateControl(self.name..skill.."TimerBarBackdrop", stacksWindow, CT_BACKDROP)
		timerBarBackdrop:SetDrawTier(DT_HIGH)
		timerBarBackdrop:SetCenterColor(0.06, 0.06, 0.06, 0.7)
		timerBarBackdrop:SetEdgeTexture("/esoui/art/miscellaneous/borderedinsettransparent_edgefile.dds", 128, 16, size/2)
		timerBarBackdrop:SetHidden(not (isUnlocked and sv.showTimerBar))
		
		local timerBar = WINDOW_MANAGER:CreateControl(self.name..skill.."TimerBar", stacksWindow, CT_STATUSBAR)
		timerBar:SetDrawTier(DT_HIGH)
		local r,g,b,a = unpack(attributes.highlight)
		timerBar:SetColor(r,g,b,0.35)
		timerBar:SetHidden(not (isUnlocked and sv.showTimerBar))
		timerBar:SetValue(0.5)
		
		local timerBarGloss = WINDOW_MANAGER:CreateControl(self.name..skill.."TimerBarGloss", timerBar, CT_TEXTURE)
		timerBarGloss:SetDrawTier(DT_HIGH)
		timerBarGloss:SetAlpha(0.9)
		timerBarGloss:SetTexture("/esoui/art/unitattributevisualizer/gamepad/gp_attributebar_dynamic_fill_gloss.dds")
		timerBarGloss:SetTextureCoords(0, 1, 0.5, 0.36)
		timerBarGloss:SetHidden(not (isUnlocked and sv.showTimerBar))
		
		local timerBarTimer = WINDOW_MANAGER:CreateControl(self.name..skill.."TimerBarTimer", timerBar, CT_LABEL)
		timerBarTimer:SetDrawTier(DT_HIGH)
		timerBarTimer:SetAlpha(1)
		timerBarTimer:SetFont(Util.Text.getFontString(tostring("$(BOLD_FONT)"), size*0.7, "outline"))
		timerBarTimer:SetHidden(not isUnlocked and sv.showTimer)
		timerBarTimer:SetText("2.5s")
				
		local function TimerBarOrientation(orientation)
			timerBar:ClearAnchors()
			if orientation == "LEFT" then
				timerBar:SetAnchor(LEFT, timerBarBackdrop, LEFT, size*0.075, 0)
			else
				timerBar:SetAnchor(RIGHT, timerBarBackdrop, RIGHT, -size*0.075, 0)
			end
		end
		
		local function TimerBarAnchors()
			timer:ClearAnchors()
			timer:SetAnchor(LEFT, stacksWindow, RIGHT, 2*distance, 0)
			timerBarBackdrop:ClearAnchors()
			timerBarBackdrop:SetAnchor(TOP, stacksWindow, BOTTOM, 0, distance*multiplier)
			timerBarGloss:SetAnchorFill(timerBar)
			timerBarTimer:ClearAnchors()
			timerBarTimer:SetAnchor(CENTER, timerBarBackdrop, CENTER, 0, 0)
			TimerBarOrientation(sv.timerBarOrientation)
		end
				
		return {
		stacksWindow = stacksWindow,
		timer = timer,
		timerBar = timerBar,
		timerBarGloss = timerBarGloss,
		timerBarBackdrop = timerBarBackdrop,
		timerBarTimer = timerBarTimer,
		TimerBarOrientation = TimerBarOrientation,
		TimerBarAnchors = TimerBarAnchors,
		}
	end
	
	local tracker = ZO_HUDFadeSceneFragment:New(stacksWindow) 
	local function FadeScenes(value)
		if value == "UI" then
			SCENE_MANAGER:GetScene("hud"):AddFragment(tracker)
			SCENE_MANAGER:GetScene("hudui"):AddFragment(tracker)
		elseif value == "NoUI" then
			SCENE_MANAGER:GetScene("hud"):RemoveFragment(tracker)
			SCENE_MANAGER:GetScene("hudui"):RemoveFragment(tracker)
		elseif value == "Sample" then
			SCENE_MANAGER:GetScene("gameMenuInGame"):AddFragment(tracker)
		elseif value == "NoSample" then
			SCENE_MANAGER:GetScene("gameMenuInGame"):RemoveFragment(tracker)
		end
	end
		
	if attributes.duration then
		local timerControls = CreateTimerControls()
		indicator.timer = timerControls.timer
		indicator.timerBar = timerControls.timerBar
		indicator.timerBarGloss = timerControls.timerBarGloss
		indicator.timerBarBackdrop = timerControls.timerBarBackdrop
		indicator.timerBarTimer = timerControls.timerBarTimer
		indicator.TimerBarOrientation = timerControls.TimerBarOrientation
		indicator.TimerBarAnchors = timerControls.TimerBarAnchors
	end
	
	-----------------------
	---- Changing Size ----
	-----------------------
	
	local function ApplySize(size)
		local dis = size/5
		stacksWindow:SetDimensions((size*attributes.iMax+dis*(attributes.iMax-1)), size*multiplier)
		
		for i=1,attributes.iMax*multiplier do 
			indicator[i].controls.frame:SetDimensions(size,size)
			indicator[i].controls.highlight:SetDimensions(size,size)
			indicator[i].controls.icon:SetDimensions(size,size)
			indicator[i].controls.highlightAnimation:SetAnchor(TOPLEFT, stackIdicator, TOPLEFT, math.floor(size/20), math.floor(size/20))
			indicator[i].controls.highlightAnimation:SetAnchor(BOTTOMRIGHT, stackIndicator, BOTTOMRIGHT, size-math.floor(size/20), size-math.floor(size/20))
			
			-- Applying correct distances
			
			if i <= attributes.iMax then
				local xOffset = (i-1)*(size+dis)
				indicator[i].controls.stackIndicator:ClearAnchors()
				indicator[i].controls.stackIndicator:SetAnchor(TOPLEFT, stacksWindow, TOPLEFT, xOffset, 0)
			else
				local xOffset = (i-attributes.iMax-1)*(size+dis)
				indicator[i].controls.stackIndicator:ClearAnchors()
				indicator[i].controls.stackIndicator:SetAnchor(TOPLEFT, stacksWindow, TOPLEFT, xOffset, size+dis)
			end
		end
		
			-- Timer Controls
			
		if indicator.timer then
			local width = stacksWindow:GetWidth()
			indicator.timer:SetDimensions(size*multiplier*1.5, size*multiplier)
			indicator.timer:SetFont(Util.Text.getFontString(tostring("$(BOLD_FONT)"), size*multiplier, "outline"))
			indicator.timerBar:SetDimensions(width-size*0.15, size*0.85)
			indicator.timerBarBackdrop:SetDimensions(width, size)
			indicator.timerBarBackdrop:SetEdgeTexture("/esoui/art/miscellaneous/borderedinsettransparent_edgefile.dds", 128, 16, size/2)
			indicator.timerBarTimer:SetFont(Util.Text.getFontString(tostring("$(BOLD_FONT)"), size*0.7, "outline"))
			-- indicator.timerBarFrame:SetDimensions(stacksWindow:GetWidth(), size)
			
			indicator.TimerBarAnchors()
		end
	end
	indicator.ApplySize = ApplySize
	
	-- local function ApplyDistance(distance, size) 
		-- for i=1,attributes.iMax*multiplier do
			-- if i <= attributes.iMax then
				-- local xOffset = (i-1)*(size+distance)
				-- indicator[i].controls.stackIndicator:ClearAnchors()
				-- indicator[i].controls.stackIndicator:SetAnchor(TOPLEFT, stacksWindow, TOPLEFT, xOffset, 0)
			-- else
				-- local xOffset = (i-attributes.iMax-1)*(size+distance)
				-- indicator[i].controls.stackIndicator:ClearAnchors()
				-- indicator[i].controls.stackIndicator:SetAnchor(TOPLEFT, stacksWindow, TOPLEFT, xOffset, size+distance)
			-- end
		-- end
	-- end
	-- indicator.ApplyDistance = ApplyDistance
	
	local function ApplyIcon()
		if skill == "GF" then
			attributes.graphic = attributes.icon[Util.Stacks.morphs.GF]
		elseif skill == "FS" then
			attributes.graphic = attributes.icon[Util.Stacks.morphs.FS]
		end
		for i=1,attributes.iMax*multiplier do
			indicator[i].controls.icon:SetTexture(attributes.graphic)
		end
	end
	indicator.ApplyIcon = ApplyIcon
	
	local function ApplyAlpha()
		for i=1,attributes.iMax*multiplier do 
			indicator[i].controls.frame:SetAlpha(sv.alpha)
			indicator[i].controls.highlight:SetAlpha(sv.alpha*0.2)
			indicator[i].controls.icon:SetAlpha(sv.alpha)
			indicator[i].controls.highlightAnimation:SetAlpha(sv.alpha*0.8)
		end
		if indicator.timer then
			indicator.timer:SetAlpha(sv.alpha)
			indicator.timerBar:SetAlpha(sv.alpha)
			indicator.timerBarBackdrop:SetAlpha(sv.alpha)
			indicator.timerBarGloss:SetAlpha(sv.alpha)
			indicator.timerBarTimer:SetAlpha(sv.alpha)
		end
	end
	indicator.ApplyAlpha = ApplyAlpha
	
	local function Hide(value)
		for i=1,attributes.iMax*multiplier do 
			indicator[i].controls.stackIndicator:SetHidden(value)
			indicator[i].controls.icon:SetHidden(value)
			indicator[i].controls.frame:SetHidden(value)
			indicator[i].controls.highlight:SetHidden(value)
		end
		if indicator.timer then
			-- local hideTimer = value or ((CombatMetronome.StackTracker.timers and CombatMetronome.StackTracker.timers[skill] == nil) and not sv.isUnlocked)
			indicator.timer:SetHidden(value or not sv.showTimer or (CombatMetronome.StackTracker.stacks[skill] == 0 and not isUnlocked))
			indicator.timerBar:SetHidden(value or not sv.showTimerBar or (CombatMetronome.StackTracker.stacks[skill] == 0 and not isUnlocked))
			indicator.timerBarGloss:SetHidden(value or not sv.showTimerBar or (CombatMetronome.StackTracker.stacks[skill] == 0 and not isUnlocked))
			indicator.timerBarBackdrop:SetHidden(value or not sv.showTimerBar or (CombatMetronome.StackTracker.stacks[skill] == 0 and not isUnlocked))
			indicator.timerBarTimer:SetHidden(value or not sv.showTimerBar or sv.showTimer or (CombatMetronome.StackTracker.stacks[skill] == 0 and not isUnlocked))
		end
	end
	
	Position("UI")
	
	SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, newState)
		if scene:GetName() == "gameMenuInGame" and newState == "hiding" and self.showSampleTracker then
			self.showSampleTracker = false
			Position("UI")
			FadeScenes("NoSample")
		end
	end)

	return {
	stacksWindow = stacksWindow,
	indicator = indicator,
	FadeScenes = FadeScenes,
	Position = Position,
	Hide = Hide,
	}
end

	------------------------------------
	---- Build Light Attack Tracker ----
	------------------------------------
CM.LATracker = CM.LATracker or {}
local LATracker = CombatMetronome.LATracker

function LATracker:BuildUI()
	if not LATracker.frame then
		LATracker.frame = Util.Controls:NewFrame(self.name.."Frame")
		LATracker.frame:SetDimensionConstraints(50, 10, 300, 50)
		LATracker.frame:SetHeight(CombatMetronome.SV.LATracker.height)
		LATracker.frame:SetWidth(CombatMetronome.SV.LATracker.width)
		LATracker.frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, CombatMetronome.SV.LATracker.xOffset, CombatMetronome.SV.LATracker.yOffset)
	end
	
	LATracker.label = LATracker.label or WINDOW_MANAGER:CreateControl(self.name.."Label", LATracker.frame, CT_LABEL)
	LATracker.label:SetHidden(true)
	LATracker.label:SetText("")
	LATracker.label:ClearAnchors()
	LATracker.label:SetAnchor(CENTER, LATracker.frame, CENTER, 0, 0)
	
	local function LabelSettings()
		LATracker.label:SetFont(Util.Text.getFontString(tostring("$("..CombatMetronome.SV.Progressbar.labelFont..")"), LATracker.frame:GetHeight(), CombatMetronome.SV.Progressbar.fontStyle))
	end
	
	LATracker.frame:SetHandler("OnMoveStop", function(...)
		CombatMetronome.SV.LATracker.xOffset = LATracker.frame:GetLeft()
		CombatMetronome.SV.LATracker.yOffset = LATracker.frame:GetTop()
	end)
	LATracker.frame:SetHandler("OnResizeStop", function(...)
		CombatMetronome.SV.LATracker.width = LATracker.frame:GetWidth()
		CombatMetronome.SV.LATracker.height = LATracker.frame:GetHeight()
		LATracker.label:SetFont(Util.Text.getFontString(tostring("$("..CombatMetronome.SV.Progressbar.labelFont..")"), math.min(LATracker.frame:GetHeight(), LATracker.frane:GetWidth()/5), CombatMetronome.SV.Progressbar.fontStyle))
	end)
	
	LabelSettings()
	
	return {
		LabelSettings = LabelSettings,
	}
end