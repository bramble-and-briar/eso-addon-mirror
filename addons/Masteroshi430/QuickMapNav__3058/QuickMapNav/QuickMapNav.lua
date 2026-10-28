--[[
-------------------------------------------------------------------------------
-- QuickMapNav, by @Masteroshi430 (EU)
-------------------------------------------------------------------------------
]]

QMN = {}

QMN.name = "|cf49b42QuickMapNav|r"
QMN.version = "2026.10.27"
QMN.throttle = {}
QMN.activeControls = {} -- controls currently shown by UpdateMapID, so we only have to hide these next update
QMN.defaults = {
	topLeftZoneName = false,
	lessFlashyMap = 0.87,
	desaturation = 0.20,
	seconds = false,
	abbreviatedKeeps = true,
}

function QMN.CreateConfiguration()
	
	local LAM = LibAddonMenu2
	

	local panelData = {
		type = "panel",
		name = QMN.name,
		author = "|c3CB371@Masteroshi430|r",
		version = QMN.version,
		registerForDefaults = true,
		registerForRefresh = true,
	}

	LAM:RegisterAddonPanel(QMN.name.."Config", panelData)

	local controlData = {
		[1] = {
			type = "slider",
			min = 66,
			max = 100,
			step = 1,
			name = GetString( LESS_FLASHY ),
			tooltip = GetString( LESS_FLASHY_TOOLTIP ),
			getFunc = function() return QMN.vars.lessFlashyMap * 100 end,
			setFunc = function(value) QMN.vars.lessFlashyMap = value / 100 end,
			default = QMN.defaults.lessFlashyMap * 100,
			requiresReload = true,
		},
		[2] = {
			type = "slider",
			min = 0,
			max = 100,
			step = 1,
			name = GetString( DESATURATION ),
			tooltip = GetString( DESATURATION_TOOLTIP ),
			getFunc = function() return QMN.vars.desaturation * 100 end,
			setFunc = function(value) QMN.vars.desaturation = value / 100 end,
			default = QMN.defaults.desaturation * 100,
			requiresReload = true,
		},
		[3] = {
			type = "checkbox",
			name = GetString( DEFAULT_TOPLEFT ),
			tooltip = GetString( PERFECT_PIXEL ),
			getFunc = function() return QMN.vars.topLeftZoneName end,
			setFunc = function(value) QMN.vars.topLeftZoneName = value end,
			default = QMN.defaults.topLeftZoneName,
		},
		[4] = {
			type = "checkbox",
			name = GetString( SECONDS ),
			tooltip = GetString( SECONDS_TOOLTIP ),
			getFunc = function() return QMN.vars.seconds end,
			setFunc = function(value) QMN.vars.seconds = value end,
			default = QMN.defaults.seconds,
			disabled = function()
                return (QMN.vars.topLeftZoneName)
            end,
		},		
		[5] = {
			type = "checkbox",
			name = GetString( ABBR ),
			tooltip = GetString( ABBR_TOOLTIP ),
			getFunc = function() return QMN.vars.abbreviatedKeeps end,
			setFunc = function(value) QMN.vars.abbreviatedKeeps = value end,
			default = QMN.defaults.abbreviatedKeeps,
		},			
		

	}

LAM:RegisterOptionControls(QMN.name.."Config", controlData)

end

local ADDON_NAME = "QuickMapNav"
local QUICK_MAP_NAV

-- definition if QuickMapNav object 
local QuickMapNav = ZO_Object:Subclass()

function QuickMapNav:New(...)
	local obj = ZO_Object.New(self)
	obj:Initialize(...)
	return obj
end


QMN.Time = ZO_FormatClockTime()



function QuickMapNav:SpaceToNewlineNameId(id)
     local vn = "failed"
     vn = QuickMapNav:ColorMapTextById(id):gsub(GetMapNameById(1782)..": ", ""):gsub("Griffenoire", ""):gsub("Schwarzweite", ""):gsub("Graumoorkavernen", "Graumoor\nkavernen"):gsub(": ", ""):gsub("-", "\n"):gsub(" ", "\n")
     return vn
end


function QuickMapNav:ColorMapTextById(Id)
    return string.format("|c000000%s|r", zo_strformat("<<1>>",GetMapNameById(Id)))
end

function QuickMapNav:ColorPortalMapTextById(ID)
    return string.format("|c000000%s|r", zo_strformat("|t24:24:esoui/art/icons/poi/poi_portal_complete.dds|t<<1>>|t24:24:esoui/art/icons/poi/poi_portal_complete.dds|t",GetMapNameById(ID)))
end

function QuickMapNav:colorMapTitle()
     return string.format("|cFFFFFF%s|r", zo_strformat("<<1>>",QMN.LMD.mapName))
end



function QuickMapNav:Initialize(parent)
	self.attachedTo = ZO_WorldMapScroll

	self.control = parent
	self.control:SetHidden(true)
	self.control:SetDrawTier(1) -- 2 moved to 1 to draw under wayshrine travel confirmation prompt 
	self.control:SetDrawLayer(1) -- 3 moved to 1 to draw under tooltips
	self.control:SetDrawLevel(0)
	
	self:OnGamepadPreferredModeChanged()
	
    local passSymbol = string.format("|c000000%s|r", zo_strformat("<<1>>","|t24:24:QuickMapNav/art/icons/pass.dds|t"))
	  local portalSymbol = string.format("|c000000%s|r", zo_strformat("<<1>>","|t24:24:esoui/art/icons/mapkey/mapkey_portal.dds|t"))
    local liftSymbol = string.format("|c000000%s|r", zo_strformat("<<1>>","|t28:28:esoui/art/icons/poi/poi_u26_dwemergear_complete.dds|t"))
    QMN.WSSymbol = string.format("|c000000%s|r", zo_strformat("<<1>>","|t32:32:esoui/art/icons/poi/poi_wayshrine_complete.dds|t"))
	QMN.WSSymbolBlack = string.format("|c000000%s|r", zo_strformat("<<1>>","|t32:32:esoui/art/icons/poi/poi_wayshrine_incomplete.dds|t"))
	
	-- if perfect pixel then ZO_WorldMap:GetHeight()
	
	local multiplicandX = ZO_WorldMapScroll:GetHeight()/930
	local multiplicandY = ZO_WorldMapScroll:GetWidth()/930
	
	

	
    -- this corrects wrong maths, don't touch kid!
    local multiX = 1 * multiplicandX
    local multiY = 1.111111 * multiplicandY
	
	-- exq's reso : 3440 x 1440 
	-- ZO_WorldMapScroll:GetHeight() -- always 930 for me 
	-- ZO_WorldMapScroll:GetWidth()  -- always 930 looks like max x,y position is 1 or 1000 but size is 930
    
    -- Localisation
    local language = GetCVar("language.2")

    -- Font settings 
    local path =  "$(HANDWRITTEN_FONT)"
	local pathTitle = "$(BOLD_FONT)"
	local size = 18
	if language == "ru" then size = 16 end
	
	QMN.zoomLevel = QMN.zoomLevel or 0

	local sizeTitle = 30
	local sizeTime = 20
    local outline = "thin-outline"
	local outlineTitle = "soft-shadow-thick"
    local alpha = 1
    local alphaTitle = 1

    
    -- Alik'r Desert to Glenumbra
	self.alikrGle = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.alikrGle:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*70),math.floor(multiY*80), 0, 0) 
	self.alikrGle:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.alikrGle:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.alikrGle:SetAlpha(alpha)
    self.alikrGle:SetHorizontalAlignment(TEXT_ALIGN_CENTER) 
	self.alikrGle:SetTransformRotationZ(math.rad(15))
    self.alikrGle:SetText(QuickMapNav:ColorMapTextById((1)))
	self.alikrGle:SetMouseEnabled(true)
    self.alikrGle:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1)
        end
    end)


	-- Alik'r Desert to Stormhaven
	self.alikrSto = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.alikrSto:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*450),math.floor(multiY*80), 0, 0)
	self.alikrSto:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.alikrSto:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.alikrSto:SetAlpha(alpha)
    self.alikrSto:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.alikrSto:SetTransformRotationZ(math.rad(15))	
	self.alikrSto:SetText(QuickMapNav:ColorMapTextById(12))
	self.alikrSto:SetMouseEnabled(true)
    self.alikrSto:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(12)
        end
    end)

	-- Alik'r Desert to Bangkorai
	self.alikrBan = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.alikrBan:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*10),math.floor(multiY*-120), 0, 0) 
	self.alikrBan:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.alikrBan:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.alikrBan:SetAlpha(alpha-0.13)
    self.alikrBan:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.alikrBan:SetTransformRotationZ(math.rad(-85))	
	self.alikrBan:SetText(QuickMapNav:ColorMapTextById(20))
	self.alikrBan:SetMouseEnabled(true)
    self.alikrBan:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(20)
        end
    end)
	
	-- Alik'r Desert to Bangkorai (pass)
	self.alikrBanPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.alikrBanPass:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*-90),math.floor(multiY*-130), 0, 0) 
	self.alikrBanPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.alikrBanPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.alikrBanPass:SetAlpha(1)
    self.alikrBanPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.alikrBanPass:SetTransformRotationZ(math.rad(60))
	self.alikrBanPass:SetText(passSymbol)
	self.alikrBanPass:SetMouseEnabled(true)
    self.alikrBanPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(20)
        end
    end)
	self.alikrBanPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(20))) 
    end)
    self.alikrBanPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)

	-- Alik'r Desert to Betnikh
	self.alikrBet = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.alikrBet:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT,math.floor(multiX*-10),math.floor(multiY*100), 0, 0) 
	self.alikrBet:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.alikrBet:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.alikrBet:SetAlpha(alpha-0.13)
    self.alikrBet:SetHorizontalAlignment(TEXT_ALIGN_CENTER) 
	self.alikrBet:SetTransformRotationZ(math.rad(102))
	self.alikrBet:SetText(QuickMapNav:ColorMapTextById(227))
	self.alikrBet:SetMouseEnabled(true)
    self.alikrBet:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(227)
        end
    end)
    
    -- Alik'r Desert to Isle of Balfiera
	self.alikrBal = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.alikrBal:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT, math.floor(multiX*270),math.floor(multiY*150), 0, 0) 
	self.alikrBal:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.alikrBal:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.alikrBal:SetAlpha(alpha-0.13)
    self.alikrBal:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.alikrBal:SetTransformRotationZ(math.rad(15))	
    self.alikrBal:SetText(self:SpaceToNewlineNameId(1997))
	self.alikrBal:SetMouseEnabled(true)
    self.alikrBal:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(1997)
        end
    end)

	-- Auridon to Summerset
	self.aurSum = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.aurSum:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*30),math.floor(multiY*-300), 0, 0) 
	self.aurSum:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.aurSum:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.aurSum:SetAlpha(alpha-0.13)
    self.aurSum:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.aurSum:SetTransformRotationZ(math.rad(90))	
	self.aurSum:SetText(QuickMapNav:ColorMapTextById(1349))
	self.aurSum:SetMouseEnabled(true)
    self.aurSum:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1349)
        end
    end)

	-- Auridon to Stros M'Kai
	self.aurStro = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.aurStro:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*150),math.floor(multiY*10), 0, 0) 
	self.aurStro:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.aurStro:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.aurStro:SetAlpha(alpha)
    self.aurStro:SetHorizontalAlignment(TEXT_ALIGN_CENTER) 
	self.aurStro:SetText(QuickMapNav:ColorMapTextById(201))
	self.aurStro:SetMouseEnabled(true)
    self.aurStro:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(201)
        end
    end)
    
    -- Auridon to Stirk
	self.aurStirk = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.aurStirk:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-175),math.floor(multiY*10), 0, 0) 
	self.aurStirk:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.aurStirk:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.aurStirk:SetAlpha(alpha-0.13)
    self.aurStirk:SetHorizontalAlignment(TEXT_ALIGN_CENTER) 
	self.aurStirk:SetText(QuickMapNav:ColorMapTextById(415))
	self.aurStirk:SetMouseEnabled(true)
    self.aurStirk:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(415)
        end
    end)

	-- Auridon to Hew's Bane
	self.aurHew = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.aurHew:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-350),math.floor(multiY*10), 0, 0) 
	self.aurHew:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.aurHew:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.aurHew:SetAlpha(alpha)
    self.aurHew:SetHorizontalAlignment(TEXT_ALIGN_CENTER) 
	self.aurHew:SetText(QuickMapNav:ColorMapTextById(994))
	self.aurHew:SetMouseEnabled(true)
    self.aurHew:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(994)
        end
    end)
	
	-- Auridon to Gold Coast
	self.aurGol = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.aurGol:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-70),math.floor(multiY*10), 0, 0) 
	self.aurGol:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.aurGol:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.aurGol:SetAlpha(alpha)
    self.aurGol:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.aurGol:SetText(QuickMapNav:ColorMapTextById(1006)) 
	self.aurGol:SetMouseEnabled(true)
    self.aurGol:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1006)
        end
    end)
	
	-- Auridon to Malabal Tor
	self.aurMal = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.aurMal:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-30),math.floor(multiY*125), 0, 0) 
	self.aurMal:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.aurMal:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.aurMal:SetAlpha(alpha-0.13)
    self.aurMal:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.aurMal:SetTransformRotationZ(math.rad(-90))
	self.aurMal:SetText(QuickMapNav:ColorMapTextById(22))
	self.aurMal:SetMouseEnabled(true)
    self.aurMal:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(22)
        end
    end)
	
	-- Auridon to Greenshade
	self.aurGre = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.aurGre:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-30),math.floor(multiY*-175), 0, 0) 
	self.aurGre:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.aurGre:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.aurGre:SetAlpha(alpha-0.13)
    self.aurGre:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.aurGre:SetTransformRotationZ(math.rad(-90))
	self.aurGre:SetText(QuickMapNav:ColorMapTextById(300)) 
	self.aurGre:SetMouseEnabled(true)
    self.aurGre:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(300)
        end
    end)

	-- Auridon to Artaeum
	self.aurArt = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.aurArt:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*300),math.floor(multiY*-10), 0, 0) 
	self.aurArt:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.aurArt:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.aurArt:SetAlpha(alpha)
    self.aurArt:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.aurArt:SetText(QuickMapNav:ColorPortalMapTextById(1429)) 
	self.aurArt:SetMouseEnabled(true)
    self.aurArt:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1429)
        end
    end)
    
	-- Auridon to High isle
	self.aurHigh = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.aurHigh:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*100),math.floor(multiY*50), 0, 0) 
	self.aurHigh:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.aurHigh:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.aurHigh:SetAlpha(alpha)
    self.aurHigh:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.aurHigh:SetText(QuickMapNav:ColorMapTextById(2114)) 
	self.aurHigh:SetMouseEnabled(true)
    self.aurHigh:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(2114)
        end
    end)
	
	-- Auridon to Eyevea
	self.aurEye = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.aurEye:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*55),math.floor(multiY*80), 0, 0) 
	self.aurEye:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.aurEye:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.aurEye:SetAlpha(alpha-0.13)
    self.aurEye:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.aurEye:SetText(QuickMapNav:ColorPortalMapTextById(108)) 
	self.aurEye:SetMouseEnabled(true)
    self.aurEye:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(108)
        end
    end)
    
    
	-- Artaeum to Summerset
	self.artSum = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.artSum:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*200),math.floor(multiY*-15), 0, 0) 
	self.artSum:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.artSum:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.artSum:SetAlpha(alpha)
    self.artSum:SetHorizontalAlignment(TEXT_ALIGN_CENTER)	
	self.artSum:SetText(QuickMapNav:ColorPortalMapTextById(1349)) 
	self.artSum:SetMouseEnabled(true)
    self.artSum:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1349)
        end
    end)
    
	-- Artaeum to Auridon
	self.artAur = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.artAur:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*700),math.floor(multiY*-15), 0, 0) 
	self.artAur:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.artAur:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.artAur:SetAlpha(alpha)
    self.artAur:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.artAur:SetText(QuickMapNav:ColorPortalMapTextById(143)) 
	self.artAur:SetMouseEnabled(true)
    self.artAur:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(143)
        end
    end)
	
	-- Bal Foyen to Stonefalls
	self.balSto = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.balSto:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT,math.floor(multiX*-25),math.floor(multiY*50), 0, 0) 
	self.balSto:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.balSto:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.balSto:SetAlpha(alpha-0.13)
    self.balSto:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.balSto:SetTransformRotationZ(math.rad(90))
	self.balSto:SetText(QuickMapNav:ColorMapTextById(7))
	self.balSto:SetMouseEnabled(true)
    self.balSto:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(7)
        end
    end)
    
	-- Bal Foyen to Stonefalls (pass)
	self.balStoPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.balStoPass:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT,math.floor(multiX*40),math.floor(multiY*40), 0, 0) 
	self.balStoPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.balStoPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.balStoPass:SetAlpha(1)
    self.balStoPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.balStoPass:SetTransformRotationZ(math.rad(60))
	self.balStoPass:SetText(passSymbol)
	self.balStoPass:SetMouseEnabled(true)
    self.balStoPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(7)
        end
    end)
    self.balStoPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(7))) 
    end)
    self.balStoPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
    
	-- Bal Foyen to Vvardenfell
	self.balVvar = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.balVvar:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*400),math.floor(multiY*40), 0, 0)
	self.balVvar:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.balVvar:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.balVvar:SetAlpha(alpha)
    self.balVvar:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.balVvar:SetText(QuickMapNav:ColorMapTextById(1060)) 
	self.balVvar:SetMouseEnabled(true)
    self.balVvar:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1060)
        end
    end)
    
    -- Bal Foyen to Deshaan
	self.balDesh = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.balDesh:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*-40),math.floor(multiY*-10), 0, 0) 
	self.balDesh:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.balDesh:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.balDesh:SetAlpha(alpha)
    self.balDesh:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.balDesh:SetText(QuickMapNav:ColorMapTextById(13)) 
	self.balDesh:SetMouseEnabled(true)
    self.balDesh:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(13)
        end
    end)
	
    -- Bal Foyen to Telvanni Peninsula
	self.balTel = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.balTel:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*60),math.floor(multiY*150), 0, 0) 
	self.balTel:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.balTel:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.balTel:SetAlpha(alpha)
    self.balTel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.balTel:SetTransformRotationZ(math.rad(-90))
	self.balTel:SetText(QuickMapNav:ColorMapTextById(2274)) 
	self.balTel:SetMouseEnabled(true)
    self.balTel:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(2274)
        end
    end)
	
    -- Bal Foyen to Telvanni Peninsula (pass)
	self.balTelPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.balTelPass:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT, math.floor(multiX*-140),math.floor(multiY*45), 0, 0) 
	self.balTelPass:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.balTelPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.balTelPass:SetAlpha(1)
    self.balTelPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.balTelPass:SetText(passSymbol) 
    self.balTelPass:SetTransformRotationZ(math.rad(-70))
	self.balTelPass:SetMouseEnabled(true)
    self.balTelPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(2274)
        end
    end)
    self.balTelPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(2274)))
    end)
    self.balTelPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
    
	-- Bangkorai to Craglorn
	self.banCrag = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.banCrag:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*-30),math.floor(multiY*-3), 0, 0) 
	self.banCrag:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.banCrag:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.banCrag:SetAlpha(alpha-0.13)
    self.banCrag:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.banCrag:SetTransformRotationZ(math.rad(-90))
	self.banCrag:SetText(QuickMapNav:ColorMapTextById(1126)) 
	self.banCrag:SetMouseEnabled(true)
    self.banCrag:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1126)
        end
    end)
	
	-- Bangkorai to Craglorn (pass)
	self.banCragPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.banCragPass:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*-215),math.floor(multiY*125), 0, 0) 
	self.banCragPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.banCragPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.banCragPass:SetAlpha(1)
    self.banCragPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.banCragPass:SetTransformRotationZ(math.rad(-90))
	self.banCragPass:SetText(passSymbol)
	self.banCragPass:SetMouseEnabled(true)
    self.banCragPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1126)
        end
    end)
	self.banCragPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(1126))) 
    end)
    self.banCragPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Bangkorai to The valley of blades
	self.banVal = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.banVal:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-90),math.floor(multiY*-100), 0, 0) 
	self.banVal:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.banVal:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.banVal:SetAlpha(alpha-0.13)
    self.banVal:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.banVal:SetText(self:SpaceToNewlineNameId(1706)) 
	self.banVal:SetMouseEnabled(true)
    self.banVal:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		     WORLD_MAP_MANAGER:SetMapById(1706)
        end
    end)
		
    
	-- Bangkorai to The Reach
	self.banRea = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.banRea:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-70),math.floor(multiY*125), 0, 0) 
	self.banRea:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.banRea:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.banRea:SetAlpha(alpha-0.13)
    self.banRea:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.banRea:SetTransformRotationZ(math.rad(-90))
	self.banRea:SetText(QuickMapNav:ColorMapTextById(1814)) 
	self.banRea:SetMouseEnabled(true)
    self.banRea:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1814)
        end
    end)
    
	-- Bangkorai to Wrothgar
	self.banWroth = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.banWroth:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*250),math.floor(multiY*40), 0, 0) 
	self.banWroth:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.banWroth:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.banWroth:SetAlpha(alpha-0.13)
    self.banWroth:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.banWroth:SetTransformRotationZ(math.rad(30))
	self.banWroth:SetText(QuickMapNav:ColorMapTextById(667)) 
	self.banWroth:SetMouseEnabled(true)
    self.banWroth:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(667)
        end
    end)
	
	-- Bangkorai to Wrothgar (pass)
	self.banWrothPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.banWrothPass:SetAnchor(TOP, ZO_WorldMapContainer, TOP,math.floor(multiX*-125),math.floor(multiY*80), 0, 0) 
	self.banWrothPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.banWrothPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.banWrothPass:SetAlpha(1)
    self.banWrothPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.banWrothPass:SetTransformRotationZ(math.rad(15))
	self.banWrothPass:SetText(passSymbol)
	self.banWrothPass:SetMouseEnabled(true)
    self.banWrothPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(667)
        end
    end)
	self.banWrothPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(667))) 
    end)
    self.banWrothPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Bangkorai to Stormhaven
	self.banSto = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.banSto:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*70),math.floor(multiY*300), 0, 0) 
	self.banSto:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.banSto:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.banSto:SetAlpha(alpha-0.13)
    self.banSto:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.banSto:SetTransformRotationZ(math.rad(45))
	self.banSto:SetText(QuickMapNav:ColorMapTextById(12)) 
	self.banSto:SetMouseEnabled(true)
    self.banSto:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(12)
        end
    end)
    
	-- Bangkorai to Stormhaven (pass)
	self.banStoPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.banStoPass:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT,math.floor(multiX*255),math.floor(multiY*-75), 0, 0) 
	self.banStoPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.banStoPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.banStoPass:SetAlpha(1)
    self.banStoPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.banStoPass:SetTransformRotationZ(math.rad(-60))
	self.banStoPass:SetText(passSymbol)
	self.banStoPass:SetMouseEnabled(true)
    self.banStoPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(12)
        end
    end)
	self.banStoPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(12))) 
    end)
    self.banStoPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
    
	-- Bangkorai to Alik'r Desert
	self.banAlik = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.banAlik:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*50),math.floor(multiY*-170), 0, 0) 
	self.banAlik:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.banAlik:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.banAlik:SetAlpha(alpha-0.13)
    self.banAlik:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.banAlik:SetTransformRotationZ(math.rad(90))
	self.banAlik:SetText(QuickMapNav:ColorMapTextById(30)) 
	self.banAlik:SetMouseEnabled(true)
    self.banAlik:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(30)
        end
    end)
	
	-- Bangkorai to Alik'r desert (pass)
	self.banAliPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.banAliPass:SetAnchor(BOTTOMLEFT, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*190),math.floor(multiY*-110), 0, 0) 
	self.banAliPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.banAliPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.banAliPass:SetAlpha(1)
    self.banAliPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.banAliPass:SetTransformRotationZ(math.rad(-60))
	self.banAliPass:SetText(passSymbol)
	self.banAliPass:SetMouseEnabled(true)
    self.banAliPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(30)
        end
    end)
	self.banAliPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(30))) 
    end)
    self.banAliPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)

	-- Bangkorai to Earthforge 
	self.banEarth = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.banEarth:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-190),math.floor(multiY*28), 0, 0) 
	self.banEarth:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.banEarth:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.banEarth:SetAlpha(alpha-0.13)
    self.banEarth:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.banEarth:SetText(QuickMapNav:ColorMapTextById(103))
	self.banEarth:SetMouseEnabled(true)
    self.banEarth:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(103)
        end
    end)

	-- Betnikh to Glenumbra
	self.betGle = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.betGle:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*200),math.floor(multiY*10), 0, 0)
	self.betGle:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.betGle:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.betGle:SetAlpha(alpha)
    self.betGle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.betGle:SetText(QuickMapNav:ColorMapTextById(1))
	self.betGle:SetMouseEnabled(true)
    self.betGle:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1)
        end
    end)
    
	-- Betnikh to Alik'r Desert
	self.betAlik = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.betAlik:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-90),math.floor(multiY*10), 0, 0)
	self.betAlik:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.betAlik:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.betAlik:SetAlpha(alpha)
    self.betAlik:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.betAlik:SetText(QuickMapNav:ColorMapTextById(30))
	self.betAlik:SetMouseEnabled(true)
    self.betAlik:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(30)
        end
    end)

    -- Betnikh to High isle
	self.betHigh = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.betHigh:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*-80),math.floor(multiY*-10), 0, 0) 
	self.betHigh:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.betHigh:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.betHigh:SetAlpha(alpha)
    self.betHigh:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.betHigh:SetText(QuickMapNav:ColorMapTextById(2114)) 
	self.betHigh:SetMouseEnabled(true)
    self.betHigh:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(2114)
        end
    end)

	-- Bleakrock Isle to Vvardenfell
	self.bleaVvar = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.bleaVvar:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-70),math.floor(multiY*-150), 0, 0) 
	self.bleaVvar:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.bleaVvar:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.bleaVvar:SetAlpha(alpha)
    self.bleaVvar:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.bleaVvar:SetText(QuickMapNav:ColorMapTextById(1060)) 
	self.bleaVvar:SetMouseEnabled(true)
    self.bleaVvar:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1060)
        end
    end)

	-- Bleakrock Isle to Eastmarch
	self.bleaEast = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.bleaEast:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*70),math.floor(multiY*-70), 0, 0) 
	self.bleaEast:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.bleaEast:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.bleaEast:SetAlpha(alpha)
    self.bleaEast:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.bleaEast:SetText(QuickMapNav:ColorMapTextById(61)) 
	self.bleaEast:SetMouseEnabled(true)
    self.bleaEast:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(61)
        end
    end)
    
    -- Coldharbour to Deshaan 
	self.coldDesh = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.coldDesh:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*1),math.floor(multiY*-30), 0, 0)
	self.coldDesh:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.coldDesh:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.coldDesh:SetAlpha(alpha)
    self.coldDesh:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.coldDesh:SetText(QuickMapNav:ColorPortalMapTextById(13))
	self.coldDesh:SetMouseEnabled(true)
    self.coldDesh:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(13)
        end
    end)
    
	-- Craglorn to Cyrodiil
	self.cragCyr = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.cragCyr:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-60),math.floor(multiY*-70), 0, 0) 
	self.cragCyr:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.cragCyr:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.cragCyr:SetAlpha(alpha)
    self.cragCyr:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.cragCyr:SetText(QuickMapNav:ColorMapTextById(16)) 
	self.cragCyr:SetMouseEnabled(true)
    self.cragCyr:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(16)
        end
    end)
	
	-- Craglorn to West Weald
	self.cragWW = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.cragWW:SetAnchor(BOTTOMRIGHT, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-175),math.floor(multiY*-30), 0, 0) 
	self.cragWW:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.cragWW:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.cragWW:SetAlpha(alpha-0.13)
    self.cragWW:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.cragWW:SetText(QuickMapNav:ColorMapTextById(2427))
	self.cragWW:SetMouseEnabled(true)
    self.cragWW:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(2427)
        end
    end)
	
	-- Craglorn to West Weald (pass)
	self.cragWWPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.cragWWPass:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*130),math.floor(multiY*-220), 0, 0) 
	self.cragWWPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.cragWWPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.cragWWPass:SetAlpha(1)
    self.cragWWPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.cragWWPass:SetTransformRotationZ(math.rad(-45))
	self.cragWWPass:SetText(passSymbol)
	self.cragWWPass:SetMouseEnabled(true)
    self.cragWWPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(2427)
        end
    end)
    self.cragWWPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(2427))) 
    end)
    self.cragWWPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	

	-- Craglorn to The Reach
	self.cragRea = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.cragRea:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*200),math.floor(multiY*70), 0, 0)
	self.cragRea:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.cragRea:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.cragRea:SetAlpha(alpha)
    self.cragRea:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.cragRea:SetText(QuickMapNav:ColorMapTextById(1814)) 
	self.cragRea:SetMouseEnabled(true)
    self.cragRea:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1814)
        end
    end)
	
	-- Craglorn to Bangkorai
	self.cragBan = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.cragBan:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT,math.floor(multiX*-10),math.floor(multiY*-20), 0, 0) 
	self.cragBan:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.cragBan:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.cragBan:SetAlpha(alpha-0.13)
    self.cragBan:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.cragBan:SetTransformRotationZ(math.rad(90))
	self.cragBan:SetText(QuickMapNav:ColorMapTextById(20))
	self.cragBan:SetMouseEnabled(true)
    self.cragBan:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(20)
        end
    end)
    
	-- Craglorn to Bangkorai (pass)
	self.cragBanPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.cragBanPass:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT,math.floor(multiX*110),math.floor(multiY*25), 0, 0) 
	self.cragBanPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.cragBanPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.cragBanPass:SetAlpha(1)
    self.cragBanPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.cragBanPass:SetTransformRotationZ(math.rad(90))
	self.cragBanPass:SetText(passSymbol)
	self.cragBanPass:SetMouseEnabled(true)
    self.cragBanPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(20)
        end
    end)
	self.cragBanPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(20))) 
    end)
    self.cragBanPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Craglorn to The valley of blades
	self.cragVal = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.cragVal:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*130),math.floor(multiY*-250), 0, 0) 
	self.cragVal:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.cragVal:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.cragVal:SetAlpha(alpha-0.13)
    self.cragVal:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.cragVal:SetText(self:SpaceToNewlineNameId(1706)) 
	self.cragVal:SetMouseEnabled(true)
    self.cragVal:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		     WORLD_MAP_MANAGER:SetMapById(1706) 
        end
    end)
    
	-- Cyrodiil to The Rift
	self.cyrRift = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.cyrRift:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-250),math.floor(multiY*30), 0, 0) 
	self.cyrRift:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.cyrRift:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.cyrRift:SetAlpha(alpha)
    self.cyrRift:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.cyrRift:SetText(QuickMapNav:ColorMapTextById(125)) 
	self.cyrRift:SetMouseEnabled(true)
    self.cyrRift:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(125)
        end
    end)
	
	-- Cyrodiil to Jerall Mountains
	self.cyrJer = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.cyrJer:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-115),math.floor(multiY*40), 0, 0) 
	self.cyrJer:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.cyrJer:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.cyrJer:SetAlpha(alpha-0.13)
    self.cyrJer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.cyrJer:SetText(QuickMapNav:ColorMapTextById(1056)) 
	self.cyrJer:SetMouseEnabled(true)
    self.cyrJer:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		      WORLD_MAP_MANAGER:SetMapById(1056)
        end
    end)
	
	-- Cyrodiil to Arcwind point
	self.cyrArc = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.cyrArc:SetAnchor(TOP, ZO_WorldMapContainer, TOP,math.floor(multiX*1),math.floor(multiY*20), 0, 0) 
	self.cyrArc:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.cyrArc:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
  self.cyrArc:SetAlpha(alpha-0.13)
  self.cyrArc:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.cyrArc:SetText(QuickMapNav:ColorMapTextById(590))
	self.cyrArc:SetMouseEnabled(true)
  self.cyrArc:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(590)
        end
    end)
    
	-- Cyrodiil to Jerall Pass
	self.cyrJerp = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.cyrJerp:SetAnchor(TOP, ZO_WorldMapContainer, TOP,math.floor(multiX*-100),math.floor(multiY*20), 0, 0) 
	self.cyrJerp:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.cyrJerp:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
  self.cyrJerp:SetAlpha(alpha-0.13)
  self.cyrJerp:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.cyrJerp:SetText(QuickMapNav:ColorMapTextById(2847))
	self.cyrJerp:SetMouseEnabled(true)
  self.cyrJerp:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(2847)
        end
    end)
	
	-- Cyrodiil to Fort Grief
	self.cyrFort = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.cyrFort:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-235),math.floor(multiY*-175), 0, 0) 
	self.cyrFort:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.cyrFort:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.cyrFort:SetAlpha(alpha-0.13)
    self.cyrFort:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.cyrFort:SetText(QuickMapNav:ColorMapTextById(2066)) 
	self.cyrFort:SetMouseEnabled(true)
    self.cyrFort:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		     WORLD_MAP_MANAGER:SetMapById(2066)
        end
    end)
    
    -- Cyrodiil to Stonefalls
	self.cyrSto = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.cyrSto:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-50),math.floor(multiY*120), 0, 0)
	self.cyrSto:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.cyrSto:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.cyrSto:SetAlpha(alpha-0.13)
    self.cyrSto:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.cyrSto:SetTransformRotationZ(math.rad(-70))
	self.cyrSto:SetText(QuickMapNav:ColorMapTextById(7))
	self.cyrSto:SetMouseEnabled(true)
    self.cyrSto:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(7)
        end
    end)
    
    -- Cyrodiil to Craglorn
	self.cyrCrag = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.cyrCrag:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*52),math.floor(multiY*100), 0, 0) 
	self.cyrCrag:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.cyrCrag:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.cyrCrag:SetAlpha(alpha-0.13)
    self.cyrCrag:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.cyrCrag:SetTransformRotationZ(math.rad(55))
	self.cyrCrag:SetText(QuickMapNav:ColorMapTextById(1126))
	self.cyrCrag:SetMouseEnabled(true)
    self.cyrCrag:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1126)
        end
    end)
    
    -- Cyrodiil to Reaper's March
	self.cyrReap = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.cyrReap:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*250),math.floor(multiY*-130), 0, 0) 
	self.cyrReap:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.cyrReap:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.cyrReap:SetAlpha(alpha-0.13)
    self.cyrReap:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.cyrReap:SetTransformRotationZ(math.rad(-55))
	self.cyrReap:SetText(QuickMapNav:ColorMapTextById(256)) 
	self.cyrReap:SetMouseEnabled(true)
    self.cyrReap:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(256)
        end
    end)
    
	-- Cyrodiil to Northern Elsweyr
	self.cyrNorth = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.cyrNorth:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*400),math.floor(multiY*-10), 0, 0) 
	self.cyrNorth:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.cyrNorth:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.cyrNorth:SetAlpha(alpha)
    self.cyrNorth:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.cyrNorth:SetText(QuickMapNav:ColorMapTextById(1555))
	self.cyrNorth:SetMouseEnabled(true)
    self.cyrNorth:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1555)
        end
    end)
	
	-- Cyrodiil to West Weald
	self.cyrWW = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.cyrWW:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT,math.floor(multiX*20),math.floor(multiY*10), 0, 0) 
	self.cyrWW:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.cyrWW:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.cyrWW:SetAlpha(alpha-0.13)
    self.cyrWW:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.cyrWW:SetTransformRotationZ(math.rad(-55))
	self.cyrWW:SetText(QuickMapNav:ColorMapTextById(2427))
	self.cyrWW:SetMouseEnabled(true)
    self.cyrWW:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(2427)
        end
    end)
	
	-- Deshaan to Stonefalls
	self.deshSto = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.deshSto:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*250),math.floor(multiY*140), 0, 0)
	self.deshSto:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.deshSto:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.deshSto:SetAlpha(alpha)
    self.deshSto:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.deshSto:SetText(QuickMapNav:ColorMapTextById(7))  
	self.deshSto:SetMouseEnabled(true)
    self.deshSto:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(7)
        end
    end)
    
	-- Deshaan to Stonefalls (pass)
	self.deshStoPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.deshStoPass:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT, math.floor(multiX*125),math.floor(multiY*-130), 0, 0)
	self.deshStoPass:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.deshStoPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.deshStoPass:SetAlpha(1)
    self.deshStoPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.deshStoPass:SetText(passSymbol)
    self.deshStoPass:SetTransformRotationZ(math.rad(15))	
	self.deshStoPass:SetMouseEnabled(true)
    self.deshStoPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(7)
        end
    end)
    self.deshStoPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(7)))
    end)
    self.deshStoPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Deshaan to Shadowfen
	self.deshSha = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.deshSha:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*250),math.floor(multiY*-200), 0, 0) 
	self.deshSha:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.deshSha:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.deshSha:SetAlpha(alpha)
    self.deshSha:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.deshSha:SetText(QuickMapNav:ColorMapTextById(26)) 
	self.deshSha:SetMouseEnabled(true)
    self.deshSha:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(26)
        end
    end)
    
	-- Deshaan to Shadowfen (pass)
	self.deshShaPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.deshShaPass:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*-70),math.floor(multiY*-230), 0, 0) 
	self.deshShaPass:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.deshShaPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.deshShaPass:SetAlpha(1)
    self.deshShaPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.deshShaPass:SetText(passSymbol)
	self.deshShaPass:SetTransformRotationZ(math.rad(15))
	self.deshShaPass:SetMouseEnabled(true)
    self.deshShaPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(26)
        end
    end)
    self.deshShaPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(26)))
    end)
    self.deshShaPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
    
    -- Deshaan to Clockwork City
	self.deshClock = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.deshClock:SetAnchor(BOTTOMLEFT, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*50),math.floor(multiY*-15), 0, 0)
	self.deshClock:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.deshClock:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.deshClock:SetAlpha(alpha)
    self.deshClock:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.deshClock:SetText(QuickMapNav:ColorPortalMapTextById(1313))
	self.deshClock:SetMouseEnabled(true)
    self.deshClock:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1313)
        end
    end)
	
	-- Deshaan to Clockwork City (portal) 
	self.deshClockPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.deshClockPass:SetAnchor(CENTER, ZO_WorldMapContainer, CENTER,math.floor(multiX*-22),math.floor(multiY*-57), 0, 0) 
	self.deshClockPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.deshClockPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.deshClockPass:SetAlpha(1)
    self.deshClockPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.deshClockPass:SetText(portalSymbol) 
	self.deshClockPass:SetMouseEnabled(true)
    self.deshClockPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		    WORLD_MAP_MANAGER:SetMapById(1313)
        end
    end)
    self.deshClockPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(1313)))
    end)
    self.deshClockPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
    
    -- Deshaan to Coldharbour
	self.deshCold = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.deshCold:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*1),math.floor(multiY*-150), 0, 0)
	self.deshCold:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.deshCold:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.deshCold:SetAlpha(alpha)
    self.deshCold:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.deshCold:SetText(QuickMapNav:ColorPortalMapTextById(255))
	self.deshCold:SetMouseEnabled(true)
    self.deshCold:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(255)
        end
    end)
    
    -- Deshaan to Bal Foyen
	self.deshBal = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.deshBal:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-220),math.floor(multiY*140), 0, 0) 
	self.deshBal:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.deshBal:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.deshBal:SetAlpha(alpha)
    self.deshBal:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.deshBal:SetText(QuickMapNav:ColorMapTextById(75)) 
	self.deshBal:SetMouseEnabled(true)
    self.deshBal:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(75)
        end
    end)
	
    -- Deshaan to Telvanni Peninsula
	self.deshTel = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.deshTel:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*60),math.floor(multiY*-140), 0, 0) 
	self.deshTel:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.deshTel:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.deshTel:SetAlpha(alpha)
    self.deshTel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.deshTel:SetTransformRotationZ(math.rad(-90))
	self.deshTel:SetText(QuickMapNav:ColorMapTextById(2274)) 
	self.deshTel:SetMouseEnabled(true)
    self.deshTel:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(2274)
        end
    end)
	
    -- Deshaan to Telvanni Peninsula (pass)
	self.deshTelPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.deshTelPass:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT, math.floor(multiX*-15),math.floor(multiY*-45), 0, 0) 
	self.deshTelPass:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.deshTelPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.deshTelPass:SetAlpha(1)
    self.deshTelPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.deshTelPass:SetText(passSymbol) 
    self.deshTelPass:SetTransformRotationZ(math.rad(-70))
	self.deshTelPass:SetMouseEnabled(true)
    self.deshTelPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(2274)
        end
    end)
    self.deshTelPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(2274)))
    end)
    self.deshTelPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
    
    -- Eastmarch to Bleakrock Isle
	self.eastBlea = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.eastBlea:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-120),math.floor(multiY*175), 0, 0) 
	self.eastBlea:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.eastBlea:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.eastBlea:SetAlpha(alpha-0.13)
    self.eastBlea:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.eastBlea:SetTransformRotationZ(math.rad(-30))
	self.eastBlea:SetText(QuickMapNav:ColorMapTextById(74)) 
	self.eastBlea:SetMouseEnabled(true)
    self.eastBlea:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(74)
        end
    end)
	
	
    -- Eastmarch to Fulstrom Homestead
	self.eastFul = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.eastFul:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-270),math.floor(multiY*200), 0, 0) 
	self.eastFul:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.eastFul:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.eastFul:SetAlpha(alpha-0.13)
    self.eastFul:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.eastFul:SetText(self:SpaceToNewlineNameId(996)) 
	self.eastFul:SetMouseEnabled(true)
    self.eastFul:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(996)
        end
    end)	
	
    
	-- Eastmarch to Vvardenfell
	self.eastVvar = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.eastVvar:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*10),math.floor(multiY*-50), 0, 0) 
	self.eastVvar:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.eastVvar:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.eastVvar:SetAlpha(alpha-0.13)
    self.eastVvar:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.eastVvar:SetTransformRotationZ(math.rad(-90))
	self.eastVvar:SetText(QuickMapNav:ColorMapTextById(1060))
	self.eastVvar:SetMouseEnabled(true)
    self.eastVvar:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1060)
        end
    end)
	
	-- Eastmarch to The Rift
	self.eastRift = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.eastRift:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*400),math.floor(multiY*-100), 0, 0) 
	self.eastRift:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.eastRift:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.eastRift:SetAlpha(alpha)
    self.eastRift:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.eastRift:SetText(QuickMapNav:ColorMapTextById(125))
	self.eastRift:SetMouseEnabled(true)
    self.eastRift:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(125)
        end
    end)
    
	-- Eastmarch to The Rift (pass)
	self.eastRiftPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.eastRiftPass:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-290),math.floor(multiY*-190), 0, 0) 
	self.eastRiftPass:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.eastRiftPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.eastRiftPass:SetAlpha(1)
    self.eastRiftPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.eastRiftPass:SetText(passSymbol)
	self.eastRiftPass:SetTransformRotationZ(math.rad(15))
	self.eastRiftPass:SetMouseEnabled(true)
    self.eastRiftPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(125)
        end
    end)
    self.eastRiftPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(125)))
    end)
    self.eastRiftPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Eastmarch to Mzark Cavern
	self.eastMzark = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.eastMzark:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT,math.floor(multiX*250),math.floor(multiY*-180), 0, 0) 
	self.eastMzark:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.eastMzark:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.eastMzark:SetAlpha(1)
    self.eastMzark:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.eastMzark:SetText(passSymbol)
	self.eastMzark:SetTransformRotationZ(math.rad(30))
	self.eastMzark:SetMouseEnabled(true)
    self.eastMzark:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(1748)
        end
    end)
    self.eastMzark:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(1748)))
    end)
    self.eastMzark:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Eastmarch to Mzark Cavern by lift
	self.eastMzarkLift = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.eastMzarkLift:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT,math.floor(multiX*270),math.floor(multiY*-120), 0, 0) 
	self.eastMzarkLift:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.eastMzarkLift:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.eastMzarkLift:SetAlpha(1)
    self.eastMzarkLift:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.eastMzarkLift:SetText(liftSymbol)
	self.eastMzarkLift:SetTransformRotationZ(math.rad(30))
	self.eastMzarkLift:SetMouseEnabled(true)
    self.eastMzarkLift:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(1748)
        end
    end)
    self.eastMzarkLift:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(1748)))
    end)
    self.eastMzarkLift:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	
    -- Glenumbra to Rivenspire
	self.gleRiv = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.gleRiv:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-190), math.floor(multiY*20), 0, 0) 
	self.gleRiv:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.gleRiv:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.gleRiv:SetAlpha(alpha)
    self.gleRiv:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.gleRiv:SetText(QuickMapNav:ColorMapTextById(10))
	self.gleRiv:SetMouseEnabled(true)
    self.gleRiv:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(10)
        end
    end)
	
	-- Glenumbra to Stormhaven
	self.gleSto = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.gleSto:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-50), math.floor(multiY*80), 0, 0) 
	self.gleSto:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.gleSto:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.gleSto:SetAlpha(alpha-0.13)
    self.gleSto:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.gleSto:SetTransformRotationZ(math.rad(-60))
	self.gleSto:SetText(QuickMapNav:ColorMapTextById(12))
	self.gleSto:SetMouseEnabled(true)
    self.gleSto:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(12)
        end
    end)
    
	-- Glenumbra to Stormhaven (pass)
	self.gleStoPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.gleStoPass:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-50), math.floor(multiY*120), 0, 0) 
	self.gleStoPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.gleStoPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.gleStoPass:SetAlpha(1)
    self.gleStoPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.gleStoPass:SetTransformRotationZ(math.rad(-60))
	self.gleStoPass:SetText(passSymbol)
	self.gleStoPass:SetMouseEnabled(true)
    self.gleStoPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(12)
        end
    end)
    self.gleStoPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(12))) 
    end)
    self.gleStoPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Glenumbra to Alik'r Desert
	self.gleAlik = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.gleAlik:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-100), math.floor(multiY*-200), 0, 0) 
	self.gleAlik:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.gleAlik:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.gleAlik:SetAlpha(alpha-0.13)
    self.gleAlik:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.gleAlik:SetTransformRotationZ(math.rad(30))
	self.gleAlik:SetText(QuickMapNav:ColorMapTextById(30))
	self.gleAlik:SetMouseEnabled(true)
    self.gleAlik:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(30)
        end
    end)
	
	-- Glenumbra to Betnikh
	self.gleBeth = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.gleBeth:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*1), math.floor(multiY*-5), 0, 0) 
	self.gleBeth:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.gleBeth:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.gleBeth:SetAlpha(alpha)
    self.gleBeth:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.gleBeth:SetText(QuickMapNav:ColorMapTextById(227))
	self.gleBeth:SetMouseEnabled(true)
    self.gleBeth:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(227)
        end
    end)
    
    -- Glenumbra to Isle of Balfiera
	self.gleBal = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.gleBal:SetAnchor(CENTER, ZO_WorldMapContainer, RIGHT, math.floor(multiX*-165),math.floor(multiY*55), 0, 0) 
	self.gleBal:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.gleBal:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.gleBal:SetAlpha(alpha-0.13)
    self.gleBal:SetHorizontalAlignment(TEXT_ALIGN_CENTER) 
    self.gleBal:SetText(self:SpaceToNewlineNameId(1997))
	self.gleBal:SetMouseEnabled(true)
    self.gleBal:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(1997)
        end
    end)
	
	-- Gold Coast to Hew's Bane
	self.goldHew = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.goldHew:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*60),math.floor(multiY*250), 0, 0) 
	self.goldHew:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.goldHew:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.goldHew:SetAlpha(alpha)
    self.goldHew:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.goldHew:SetText(self:SpaceToNewlineNameId(994))
	self.goldHew:SetMouseEnabled(true)
    self.goldHew:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(994)
        end
    end)
    
    -- Gold Coast to Auridon
	self.goldAur = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.goldAur:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*100),math.floor(multiY*-85), 0, 0) 
	self.goldAur:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.goldAur:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.goldAur:SetAlpha(alpha-0.13)
    self.goldAur:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.goldAur:SetTransformRotationZ(math.rad(-15))
	self.goldAur:SetText(QuickMapNav:ColorMapTextById(143))
	self.goldAur:SetMouseEnabled(true)
    self.goldAur:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(143)
        end
    end)
	
	-- Gold Coast to Malabal Tor
	self.goldMal = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.goldMal:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-250),math.floor(multiY*-30), 0, 0) 
	self.goldMal:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.goldMal:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.goldMal:SetAlpha(alpha-0.13)
    self.goldMal:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.goldMal:SetTransformRotationZ(math.rad(15))
	self.goldMal:SetText(QuickMapNav:ColorMapTextById(22))
	self.goldMal:SetMouseEnabled(true)
    self.goldMal:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(22)
        end
    end)
	
	-- Gold Coast to West Weald
	self.goldWW = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.goldWW:SetAnchor(TOPRIGHT, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-100),math.floor(multiY*30), 0, 0) 
	self.goldWW:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.goldWW:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.goldWW:SetAlpha(alpha-0.13)
    self.goldWW:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.goldWW:SetText(QuickMapNav:ColorMapTextById(2427))
	self.goldWW:SetMouseEnabled(true)
    self.goldWW:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(2427)
        end
    end)
	
	-- Gold Coast to West Weald (pass 1)
	self.goldWWPassOne = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.goldWWPassOne:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT, math.floor(multiX*-37),math.floor(multiY*-60), 0, 0) 
	self.goldWWPassOne:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.goldWWPassOne:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.goldWWPassOne:SetAlpha(1)
    self.goldWWPassOne:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.goldWWPassOne:SetTransformRotationZ(math.rad(0))
	self.goldWWPassOne:SetText(passSymbol)
	self.goldWWPassOne:SetMouseEnabled(true)
    self.goldWWPassOne:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(2427)
        end
    end)
    self.goldWWPassOne:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(2427))) 
    end)
    self.goldWWPassOne:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)

	-- Gold Coast to West Weald (pass 2)
	self.goldWWPassTwo = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.goldWWPassTwo:SetAnchor(CENTER, ZO_WorldMapContainer, CENTER, math.floor(multiX*-105),math.floor(multiY*-175), 0, 0) 
	self.goldWWPassTwo:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.goldWWPassTwo:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.goldWWPassTwo:SetAlpha(1)
    self.goldWWPassTwo:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.goldWWPassTwo:SetTransformRotationZ(math.rad(0))
	self.goldWWPassTwo:SetText(passSymbol)
	self.goldWWPassTwo:SetMouseEnabled(true)
    self.goldWWPassTwo:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(2427)
        end
    end)
    self.goldWWPassTwo:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(2427))) 
    end)
    self.goldWWPassTwo:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Gold Coast to Stirk
	self.goldStirk = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.goldStirk:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT,math.floor(multiX*40),math.floor(multiY*50), 0, 0) 
	self.goldStirk:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.goldStirk:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.goldStirk:SetAlpha(alpha-0.13)
    self.goldStirk:SetHorizontalAlignment(TEXT_ALIGN_CENTER) 
	self.goldStirk:SetText(QuickMapNav:ColorMapTextById(415))
	self.goldStirk:SetMouseEnabled(true)
    self.goldStirk:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(415)
        end
    end)
	
	-- Grahtwood to Khenarthi's Roost
	self.grahKhen = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.grahKhen:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-120),math.floor(multiY*-70), 0, 0) 
	self.grahKhen:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.grahKhen:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.grahKhen:SetAlpha(alpha-0.13)
    self.grahKhen:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.grahKhen:SetTransformRotationZ(math.rad(45))
	self.grahKhen:SetText(QuickMapNav:ColorMapTextById(258))
	self.grahKhen:SetMouseEnabled(true)
    self.grahKhen:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(258)
        end
    end)
	
	-- Grahtwood to Greenshade
	self.grahGreen = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.grahGreen:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*70),math.floor(multiY*300), 0, 0) 
	self.grahGreen:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.grahGreen:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.grahGreen:SetAlpha(alpha-0.13)
    self.grahGreen:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.grahGreen:SetTransformRotationZ(math.rad(90))
	self.grahGreen:SetText(QuickMapNav:ColorMapTextById(300)) 
	self.grahGreen:SetMouseEnabled(true)
    self.grahGreen:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(300)
        end
    end)
	
	-- Grahtwood to Greenshade (pass)
	self.grahGreenPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.grahGreenPass:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*140),math.floor(multiY*160), 0, 0) 
	self.grahGreenPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.grahGreenPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.grahGreenPass:SetAlpha(1)
    self.grahGreenPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.grahGreenPass:SetTransformRotationZ(math.rad(-45))
	self.grahGreenPass:SetText(passSymbol)
	self.grahGreenPass:SetMouseEnabled(true)
    self.grahGreenPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(300)
        end
    end)
    self.grahGreenPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(300)))
    end)
    self.grahGreenPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Grahtwood to Malabal Tor
	self.grahMal = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.grahMal:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*150),math.floor(multiY*10), 0, 0) 
	self.grahMal:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.grahMal:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.grahMal:SetAlpha(alpha)
    self.grahMal:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.grahMal:SetText(QuickMapNav:ColorMapTextById(22)) 
	self.grahMal:SetMouseEnabled(true)
    self.grahMal:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(22)
        end
    end)
	
	-- Grahtwood to Malabal Tor (pass)
	self.grahMalPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.grahMalPass:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*135),math.floor(multiY*25), 0, 0) 
	self.grahMalPass:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.grahMalPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.grahMalPass:SetAlpha(1)
    self.grahMalPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.grahMalPass:SetText(passSymbol)
	self.grahMalPass:SetMouseEnabled(true)
    self.grahMalPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(22)
        end
    end)
    self.grahMalPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(22)))
    end)
    self.grahMalPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Grahtwood to Reaper's March
	self.grahRea = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.grahRea:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-350),math.floor(multiY*20), 0, 0) 
	self.grahRea:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.grahRea:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.grahRea:SetAlpha(alpha)
    self.grahRea:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.grahRea:SetText(QuickMapNav:ColorMapTextById(256))
	self.grahRea:SetMouseEnabled(true)
    self.grahRea:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(256)
        end
    end)
	
	-- Grahtwood to Reaper's March (pass)
	self.grahReaPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.grahReaPass:SetAnchor(TOP, ZO_WorldMapContainer, TOP,math.floor(multiX*120),math.floor(multiY*120), 0, 0) 
	self.grahReaPass:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.grahReaPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.grahReaPass:SetAlpha(1)
    self.grahReaPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.grahReaPass:SetText(passSymbol)
	self.grahReaPass:SetTransformRotationZ(math.rad(-90))
	self.grahReaPass:SetMouseEnabled(true)
    self.grahReaPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(256)
        end
    end)
    self.grahReaPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(256)))
    end)
    self.grahReaPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
    -- Grahtwood to Northern Elsweyr
	self.grahEls = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.grahEls:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-200),math.floor(multiY*100), 0, 0) 
	self.grahEls:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.grahEls:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.grahEls:SetAlpha(alpha-0.13)
    self.grahEls:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.grahEls:SetTransformRotationZ(math.rad(-45))
	self.grahEls:SetText(QuickMapNav:ColorMapTextById(1555))
	self.grahEls:SetMouseEnabled(true)
    self.grahEls:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1555)
        end
    end)
	
    -- Grahtwood to Northern Elsweyr (pass)
	self.grahElsPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.grahElsPass:SetAnchor(TOP, ZO_WorldMapContainer, TOP,math.floor(multiX*110),math.floor(multiY*90), 0, 0) 
	self.grahElsPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.grahElsPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.grahElsPass:SetAlpha(1)
    self.grahElsPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.grahElsPass:SetTransformRotationZ(math.rad(-45))
	self.grahElsPass:SetText(passSymbol)
	self.grahElsPass:SetMouseEnabled(true)
    self.grahElsPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1555)
        end
    end)
    self.grahElsPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(1555)))
    end)
    self.grahElsPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
    
	-- Grahtwood to Southern Elsweyr
	self.grahtSouth = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.grahtSouth:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*50),math.floor(multiY*80), 0, 0) 
	self.grahtSouth:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.grahtSouth:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.grahtSouth:SetAlpha(alpha-0.13)
    self.grahtSouth:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.grahtSouth:SetTransformRotationZ(math.rad(-90))
	self.grahtSouth:SetText(QuickMapNav:ColorMapTextById(1654)) 
	self.grahtSouth:SetMouseEnabled(true)
    self.grahtSouth:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1654)
        end
    end)
	
    -- Grahtwood to Vahlokzin's Domain
	self.graVah = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.graVah:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT, math.floor(multiX*-80),math.floor(multiY*-180), 0, 0) 
	self.graVah:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.graVah:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.graVah:SetAlpha(alpha-0.13)
    self.graVah:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.graVah:SetTransformRotationZ(math.rad(-45))	
    self.graVah:SetText(self:SpaceToNewlineNameId(1707))
	self.graVah:SetMouseEnabled(true)
    self.graVah:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(1707)
        end
    end)
	
	-- Greenshade to Auridon
	self.greenAur = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.greenAur:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT,math.floor(multiX*-10),math.floor(multiY*10), 0, 0) 
	self.greenAur:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.greenAur:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.greenAur:SetAlpha(alpha-0.13)
    self.greenAur:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.greenAur:SetTransformRotationZ(math.rad(90))
	self.greenAur:SetText(QuickMapNav:ColorMapTextById(143))
	self.greenAur:SetMouseEnabled(true)
    self.greenAur:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(143)
        end
    end)
	
	-- Greenshade to Malabal Tor
	self.greenMal = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.greenMal:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-270),math.floor(multiY*130), 0, 0) 
	self.greenMal:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.greenMal:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.greenMal:SetAlpha(alpha-0.13)
    self.greenMal:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.greenMal:SetTransformRotationZ(math.rad(-45))
	self.greenMal:SetText(QuickMapNav:ColorMapTextById(22))
	self.greenMal:SetMouseEnabled(true)
    self.greenMal:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(22)
        end
    end)
	
	-- Greenshade to Malabal Tor (pass)
	self.greenMalPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.greenMalPass:SetAnchor(TOP, ZO_WorldMapContainer, TOP,math.floor(multiX*-165),math.floor(multiY*1), 0, 0)  
	self.greenMalPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.greenMalPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.greenMalPass:SetAlpha(1)
    self.greenMalPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.greenMalPass:SetText(passSymbol)
	self.greenMalPass:SetMouseEnabled(true)
    self.greenMalPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(22)
        end
    end)
    self.greenMalPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(22)))
    end)
    self.greenMalPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Greenshade to Grahtwood
	self.greenGrath = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.greenGrath:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-70),math.floor(multiY*-300), 0, 0) 
	self.greenGrath:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.greenGrath:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.greenGrath:SetAlpha(alpha-0.13)
    self.greenGrath:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.greenGrath:SetTransformRotationZ(math.rad(-90))
	self.greenGrath:SetText(QuickMapNav:ColorMapTextById(9))
	self.greenGrath:SetMouseEnabled(true)
    self.greenGrath:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(9)
        end
    end)
	
	-- Greenshade to Grahtwood (pass)
	self.greenGrathPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.greenGrathPass:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*-130),math.floor(multiY*-30), 0, 0) 
	self.greenGrathPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.greenGrathPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.greenGrathPass:SetAlpha(1)
    self.greenGrathPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.greenGrathPass:SetTransformRotationZ(math.rad(-45))
	self.greenGrathPass:SetText(passSymbol)
	self.greenGrathPass:SetMouseEnabled(true)
    self.greenGrathPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(9)
        end
    end)
    self.greenGrathPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(9)))
    end)
    self.greenGrathPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Greenshade to Fargrave City District
	self.greenFar = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.greenFar:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*-225),math.floor(multiY*70), 0, 0) 
	self.greenFar:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.greenFar:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.greenFar:SetAlpha(1)
    self.greenFar:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.greenFar:SetText(portalSymbol)
	self.greenFar:SetMouseEnabled(true)
    self.greenFar:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		   WORLD_MAP_MANAGER:SetMapById(2035) 
        end
    end)
    self.greenFar:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(2119)))
    end)
    self.greenFar:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Greenshade to Stirk
	self.greenStirk = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.greenStirk:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*140),math.floor(multiY*10), 0, 0) 
	self.greenStirk:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.greenStirk:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.greenStirk:SetAlpha(alpha-0.13)
    self.greenStirk:SetHorizontalAlignment(TEXT_ALIGN_CENTER) 
	self.greenStirk:SetText(QuickMapNav:ColorMapTextById(415))
	self.greenStirk:SetMouseEnabled(true)
    self.greenStirk:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(415)
        end
    end)
	
	-- Greenshade to Hew's Bane
	self.greenHew = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.greenHew:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*70),math.floor(multiY*10), 0, 0) 
	self.greenHew:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.greenHew:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.greenHew:SetAlpha(alpha)
    self.greenHew:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.greenHew:SetText(self:SpaceToNewlineNameId(994))
	self.greenHew:SetMouseEnabled(true)
    self.greenHew:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(994)
        end
    end)
	
	-- Hew's Bane to Stros M'Kai
	self.hewStros = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.hewStros:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*70),math.floor(multiY*-170), 0, 0) 
	self.hewStros:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.hewStros:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.hewStros:SetAlpha(alpha)
    self.hewStros:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.hewStros:SetText(QuickMapNav:ColorMapTextById(201))
	self.hewStros:SetMouseEnabled(true)
    self.hewStros:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(201)
        end
    end)
	
    -- Hew's Bane to Summerset
	self.hewSum = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.hewSum:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*100),math.floor(multiY*-85), 0, 0) 
	self.hewSum:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.hewSum:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.hewSum:SetAlpha(alpha)
    self.hewSum:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.hewSum:SetText(QuickMapNav:ColorMapTextById(1349))
	self.hewSum:SetMouseEnabled(true)
    self.hewSum:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1349)
        end
    end)
	
	-- Hew's Bane to Auridon
	self.hewAur = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.hewAur:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*300),math.floor(multiY*-10), 0, 0) 
	self.hewAur:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.hewAur:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.hewAur:SetAlpha(alpha)
    self.hewAur:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.hewAur:SetText(QuickMapNav:ColorMapTextById(143))
	self.hewAur:SetMouseEnabled(true)
    self.hewAur:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(143)
        end
    end)
	
	-- Hew's Bane to Gold Coast
	self.hewGold = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.hewGold:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-70),math.floor(multiY*-175), 0, 0) 
	self.hewGold:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.hewGold:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.hewGold:SetAlpha(alpha)
    self.hewGold:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.hewGold:SetText(QuickMapNav:ColorMapTextById(1006))
	self.hewGold:SetMouseEnabled(true)
    self.hewGold:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1006)
        end
    end)
	
	-- Hew's Bane to Malabal Tor
	self.hewMal = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.hewMal:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-150),math.floor(multiY*-90), 0, 0) 
	self.hewMal:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.hewMal:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.hewMal:SetAlpha(alpha)
    self.hewMal:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.hewMal:SetText(QuickMapNav:ColorMapTextById(22))
	self.hewMal:SetMouseEnabled(true)
    self.hewMal:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(22)
        end
    end)
	
	-- Hew's Bane to Stirk
	self.hewStirk = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.hewStirk:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-175),math.floor(multiY*-30), 0, 0) 
	self.hewStirk:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.hewStirk:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.hewStirk:SetAlpha(alpha-0.13)
    self.hewStirk:SetHorizontalAlignment(TEXT_ALIGN_CENTER) 
	self.hewStirk:SetText(QuickMapNav:ColorMapTextById(415))
	self.hewStirk:SetMouseEnabled(true)
    self.hewStirk:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(415) 
        end
    end)
	
	-- Hew's Bane to Greenshade
	self.hewGreen = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.hewGreen:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-300),math.floor(multiY*-50), 0, 0) 
	self.hewGreen:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.hewGreen:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.hewGreen:SetAlpha(alpha)
    self.hewGreen:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.hewGreen:SetText(QuickMapNav:ColorMapTextById(300))
	self.hewGreen:SetMouseEnabled(true)
    self.hewGreen:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(300)
        end
    end)
	
    -- Khenarthi's Roost to Southern Elsweyr
	self.khenSouth = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.khenSouth:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-120),math.floor(multiY*90), 0, 0) 
	self.khenSouth:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.khenSouth:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.khenSouth:SetAlpha(alpha-0.13)
    self.khenSouth:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.khenSouth:SetTransformRotationZ(math.rad(-45))
	self.khenSouth:SetText(QuickMapNav:ColorMapTextById(1654))
	self.khenSouth:SetMouseEnabled(true)
    self.khenSouth:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1654)
        end
    end)
	
	-- Khenarthi's Roost to Grahtwood
	self.khenGraht = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.khenGraht:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*100),math.floor(multiY*120), 0, 0)
	self.khenGraht:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.khenGraht:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.khenGraht:SetAlpha(alpha-0.13)
    self.khenGraht:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.khenGraht:SetTransformRotationZ(math.rad(45))
	self.khenGraht:SetText(QuickMapNav:ColorMapTextById(9)) 
	self.khenGraht:SetMouseEnabled(true)
    self.khenGraht:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(9)
        end
    end)
	
	-- Khenarthi's Roost to Solstice
	self.khenSol = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.khenSol:SetAnchor(BOTTOMRIGHT, ZO_WorldMapContainer, BOTTOMRIGHT, math.floor(multiX*-20), math.floor(multiY*-130), 0, 0) 
	self.khenSol:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.khenSol:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.khenSol:SetAlpha(alpha-0.13)
    self.khenSol:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.khenSol:SetTransformRotationZ(math.rad(45))
	self.khenSol:SetText(QuickMapNav:ColorMapTextById(2603)) 
	self.khenSol:SetMouseEnabled(true)
    self.khenSol:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(2603) 
        end
    end)
	
	-- Malabal Tor to Gold Coast
	self.malGold = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.malGold:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*400),math.floor(multiY*80), 0, 0)
	self.malGold:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.malGold:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.malGold:SetAlpha(alpha)
    self.malGold:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.malGold:SetText(QuickMapNav:ColorMapTextById(1006))
	self.malGold:SetMouseEnabled(true)
    self.malGold:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1006)
        end
    end)
	
	-- Malabal Tor to Reaper's March
	self.malReap = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.malReap:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-50),math.floor(multiY*-300), 0, 0) 
	self.malReap:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.malReap:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.malReap:SetAlpha(alpha-0.13)
    self.malReap:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.malReap:SetTransformRotationZ(math.rad(-90))
	self.malReap:SetText(QuickMapNav:ColorMapTextById(256)) 
	self.malReap:SetMouseEnabled(true)
    self.malReap:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(256)
        end
    end)
	
	-- Malabal Tor to West Weald
	self.malWW = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.malWW:SetAnchor(TOPRIGHT, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-100),math.floor(multiY*20), 0, 0) 
	self.malWW:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.malWW:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.malWW:SetAlpha(alpha-0.13)
    self.malWW:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.malWW:SetText(QuickMapNav:ColorMapTextById(2427))
	self.malWW:SetMouseEnabled(true)
    self.malWW:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(2427)
        end
    end)
	
	-- Malabal Tor to Reaper's March (pass)
	self.malReapPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.malReapPass:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*-80),math.floor(multiY*-135), 0, 0) 
	self.malReapPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.malReapPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.malReapPass:SetAlpha(1)
    self.malReapPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.malReapPass:SetTransformRotationZ(math.rad(-90))
	self.malReapPass:SetText(passSymbol) 
	self.malReapPass:SetMouseEnabled(true)
    self.malReapPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(256)
        end
    end)
	self.malReapPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(256)))
    end)
    self.malReapPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Malabal Tor to Grahtwood
	self.malGrath = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.malGrath:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-250),math.floor(multiY*-50), 0, 0) 
	self.malGrath:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.malGrath:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.malGrath:SetAlpha(alpha)
    self.malGrath:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.malGrath:SetText(QuickMapNav:ColorMapTextById(9))
	self.malGrath:SetMouseEnabled(true)
    self.malGrath:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(9)
        end
    end)
	
	-- Malabal Tor to Grahtwood (pass)
	self.malGrathPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.malGrathPass:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*105),math.floor(multiY*-60), 0, 0) 
	self.malGrathPass:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.malGrathPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.malGrathPass:SetAlpha(1)
    self.malGrathPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.malGrathPass:SetText(passSymbol)
	self.malGrathPass:SetMouseEnabled(true)
    self.malGrathPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(9)
        end
    end)
    self.malGrathPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(9)))
    end)
    self.malGrathPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Malabal Tor to Greenshade
	self.malGreen = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.malGreen:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*270),math.floor(multiY*-180), 0, 0) 
	self.malGreen:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.malGreen:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.malGreen:SetAlpha(alpha)
    self.malGreen:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.malGreen:SetText(QuickMapNav:ColorMapTextById(300))
	self.malGreen:SetMouseEnabled(true)
    self.malGreen:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(300)
        end
    end)
	
	-- Malabal Tor to Greenshade (pass)
	self.malGreenPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.malGreenPass:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*90),math.floor(multiY*-300), 0, 0) 
	self.malGreenPass:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.malGreenPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.malGreenPass:SetAlpha(1)
    self.malGreenPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.malGreenPass:SetText(passSymbol)
	self.malGreenPass:SetMouseEnabled(true)
    self.malGreenPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(300)
        end
    end)
    self.malGreenPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(300)))
    end)
    self.malGreenPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Malabal Tor to Auridon
	self.malAur = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.malAur:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT,math.floor(multiX*-20),math.floor(multiY*30), 0, 0) 
	self.malAur:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.malAur:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.malAur:SetAlpha(alpha-0.13)
    self.malAur:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.malAur:SetTransformRotationZ(math.rad(90))
	self.malAur:SetText(QuickMapNav:ColorMapTextById(143))
	self.malAur:SetMouseEnabled(true)
    self.malAur:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(143)
        end
    end)
	
	-- Malabal Tor to Hew's Bane
	self.malHew = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.malHew:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*100),math.floor(multiY*80), 0, 0) 
	self.malHew:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.malHew:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.malHew:SetAlpha(alpha)
    self.malHew:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.malHew:SetText(QuickMapNav:ColorMapTextById(994))
	self.malHew:SetMouseEnabled(true)
    self.malHew:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(994)
        end
    end)
	
	-- Malabal Tor to Stirk
	self.malStirk = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.malStirk:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*55),math.floor(multiY*170), 0, 0) 
	self.malStirk:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.malStirk:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.malStirk:SetAlpha(alpha-0.13)
    self.malStirk:SetHorizontalAlignment(TEXT_ALIGN_CENTER) 
	self.malStirk:SetText(QuickMapNav:ColorMapTextById(415))
	self.malStirk:SetMouseEnabled(true)
    self.malStirk:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(415)
        end
    end)
	
	-- Murkmire to Norg-Tzel 
	self.murkNorg = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.murkNorg:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-70),math.floor(multiY*-70), 0, 0) 
	self.murkNorg:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.murkNorg:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.murkNorg:SetAlpha(alpha-0.13)
    self.murkNorg:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.murkNorg:SetText(QuickMapNav:ColorMapTextById(1552))
	self.murkNorg:SetMouseEnabled(true)
    self.murkNorg:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1552)
        end
    end)
    
	-- Murkmire to Blackwood
	self.murkBlack = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.murkBlack:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*100),math.floor(multiY*70), 0, 0) 
	self.murkBlack:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.murkBlack:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.murkBlack:SetAlpha(alpha-0.13)
    self.murkBlack:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.murkBlack:SetTransformRotationZ(math.rad(30))
	self.murkBlack:SetText(QuickMapNav:ColorMapTextById(1887)) 
	self.murkBlack:SetMouseEnabled(true)
    self.murkBlack:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1887) 
        end
    end)
	
	-- Murkmire to Solstice
	self.murkSol = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.murkSol:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM, math.floor(multiX*100), math.floor(multiY*-1), 0, 0) 
	self.murkSol:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.murkSol:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.murkSol:SetAlpha(alpha-0.13)
    self.murkSol:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.murkSol:SetText(QuickMapNav:ColorMapTextById(2603)) 
	self.murkSol:SetMouseEnabled(true)
    self.murkSol:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(2603) 
        end
    end)
	
	-- Norg-Tzel to Murkmire
	self.norgMurk = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.norgMurk:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*85),math.floor(multiY*100), 0, 0) 
	self.norgMurk:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.norgMurk:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.norgMurk:SetAlpha(alpha-0.13)
    self.norgMurk:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.norgMurk:SetTransformRotationZ(math.rad(30))
	self.norgMurk:SetText(QuickMapNav:ColorMapTextById(1484))
	self.norgMurk:SetMouseEnabled(true)
    self.norgMurk:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1484)
        end
    end)
	
    -- Northern Elsweyr to Grahtwood
	self.northGrah = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.northGrah:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*55),math.floor(multiY*-40), 0, 0) 
	self.northGrah:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.northGrah:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.northGrah:SetAlpha(alpha)
    self.northGrah:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.northGrah:SetText(self:SpaceToNewlineNameId(9))
	self.northGrah:SetMouseEnabled(true)
    self.northGrah:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(9)
        end
    end)
	
    -- Northern Elsweyr to Grahtwood (pass)
	self.northGrahPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.northGrahPass:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*80),math.floor(multiY*-150), 0, 0) 
	self.northGrahPass:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.northGrahPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.northGrahPass:SetAlpha(1)
    self.northGrahPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.northGrahPass:SetText(passSymbol) 
	self.northGrahPass:SetTransformRotationZ(math.rad(-15))
	self.northGrahPass:SetMouseEnabled(true)
    self.northGrahPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(9)
        end
    end)
    self.northGrahPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(9)))
    end)
    self.northGrahPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Northern Elsweyr to Reaper's March
	self.northReap = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.northReap:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*70),math.floor(multiY*255), 0, 0) 
	self.northReap:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.northReap:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.northReap:SetAlpha(alpha-0.13)
    self.northReap:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.northReap:SetTransformRotationZ(math.rad(90))
	self.northReap:SetText(QuickMapNav:ColorMapTextById(256))
	self.northReap:SetMouseEnabled(true)
    self.northReap:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(256)
        end
    end)

	-- Northern Elsweyr to Reaper's March (pass)
	self.northReapPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.northReapPass:SetAnchor(TOP, ZO_WorldMapContainer, TOP,math.floor(multiX*-60),math.floor(multiY*30), 0, 0) 
	self.northReapPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.northReapPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.northReapPass:SetAlpha(1)
    self.northReapPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.northReapPass:SetText(passSymbol) 
	self.northReapPass:SetMouseEnabled(true)
    self.northReapPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(256)
        end
    end)
    self.northReapPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(256)))
    end)
    self.northReapPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)

	-- Northern Elsweyr to Cyrodiil
	self.northCyr = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.northCyr:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-350),math.floor(multiY*10), 0, 0) 
	self.northCyr:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.northCyr:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.northCyr:SetAlpha(alpha)
    self.northCyr:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.northCyr:SetText(QuickMapNav:ColorMapTextById(16))
	self.northCyr:SetMouseEnabled(true)
    self.northCyr:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(16)
        end
    end)
    
	-- Northern Elsweyr to Southern Elsweyr
	self.northSouth = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.northSouth:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*-10),math.floor(multiY*-10), 0, 0) 
	self.northSouth:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.northSouth:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.northSouth:SetAlpha(alpha)
    self.northSouth:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.northSouth:SetText(QuickMapNav:ColorMapTextById(1654))
	self.northSouth:SetMouseEnabled(true)
    self.northSouth:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1654)
        end
    end)
	
	-- Northern Elsweyr to Blackwood
	self.northBlack = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.northBlack:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*20),math.floor(multiY*-50), 0, 0) 
	self.northBlack:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.northBlack:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.northBlack:SetAlpha(alpha-0.13)
    self.northBlack:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.northBlack:SetTransformRotationZ(math.rad(-90))
	self.northBlack:SetText(QuickMapNav:ColorMapTextById(1887))
	self.northBlack:SetMouseEnabled(true)
    self.northBlack:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1887) 
        end
    end)
    
	-- Northern Elsweyr to Blackwood (pass)
	self.northBlackPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.northBlackPass:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*-50),math.floor(multiY*-115), 0, 0) 
	self.northBlackPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.northBlackPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.northBlackPass:SetAlpha(1)
    self.northBlackPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.northBlackPass:SetTransformRotationZ(math.rad(-90))
	self.northBlackPass:SetText(passSymbol) 
	self.northBlackPass:SetMouseEnabled(true)
    self.northBlackPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1887) 
        end
    end)
    self.northBlackPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(1887)))
    end)
    self.northBlackPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	
    -- Northern Elsweyr to Vahlokzin's Domain
	self.northVah = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.northVah:SetAnchor(BOTTOMLEFT, ZO_WorldMapContainer, BOTTOMLEFT, math.floor(multiX*100),math.floor(multiY*-105), 0, 0) 
	self.northVah:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.northVah:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.northVah:SetAlpha(alpha-0.13)
    self.northVah:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    --self.northVah:SetTransformRotationZ(math.rad(-45))	
    self.northVah:SetText(self:SpaceToNewlineNameId(1707))
	self.northVah:SetMouseEnabled(true)
    self.northVah:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(1707)
        end
    end)
	
	
	-- Reaper's March to Grahtwood
	self.reapGrah = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.reapGrah:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*190),math.floor(multiY*-5), 0, 0) 
	self.reapGrah:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.reapGrah:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.reapGrah:SetAlpha(alpha)
    self.reapGrah:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.reapGrah:SetText(QuickMapNav:ColorMapTextById(9))
	self.reapGrah:SetMouseEnabled(true)
    self.reapGrah:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(9)
        end
    end)
	
	-- Reaper's March to West Weald
	self.reapWW = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.reapWW:SetAnchor(TOPLEFT, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*120),math.floor(multiY*10), 0, 0) 
	self.reapWW:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.reapWW:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.reapWW:SetAlpha(alpha-0.13)
    self.reapWW:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.reapWW:SetText(QuickMapNav:ColorMapTextById(2427))
	self.reapWW:SetMouseEnabled(true)
    self.reapWW:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(2427)
        end
    end)
	
	--Reaper's March to West Weald (pass)
	self.reapWWPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.reapWWPass:SetAnchor(TOP, ZO_WorldMapContainer, TOP, math.floor(multiX*20),math.floor(multiY*10), 0, 0) 
	self.reapWWPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.reapWWPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.reapWWPass:SetAlpha(1)
    self.reapWWPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.reapWWPass:SetTransformRotationZ(math.rad(0))
	self.reapWWPass:SetText(passSymbol)
	self.reapWWPass:SetMouseEnabled(true)
    self.reapWWPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(2427)
        end
    end)
    self.reapWWPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(2427))) 
    end)
    self.reapWWPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	

	-- Reaper's March to Grahtwood (pass)
	self.reapGrahPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.reapGrahPass:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*-135),math.floor(multiY*-115), 0, 0) 
	self.reapGrahPass:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.reapGrahPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.reapGrahPass:SetAlpha(1)
    self.reapGrahPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.reapGrahPass:SetText(passSymbol) 
	self.reapGrahPass:SetTransformRotationZ(math.rad(-45))
	self.reapGrahPass:SetMouseEnabled(true)
    self.reapGrahPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(9)
        end
    end)
    self.reapGrahPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(9)))
    end)
    self.reapGrahPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Reaper's March to Malabal Tor
	self.reapMal = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.reapMal:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*50),math.floor(multiY*330), 0, 0) 
	self.reapMal:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.reapMal:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.reapMal:SetAlpha(alpha-0.13)
    self.reapMal:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.reapMal:SetTransformRotationZ(math.rad(90))
	self.reapMal:SetText(QuickMapNav:ColorMapTextById(22)) 
	self.reapMal:SetMouseEnabled(true)
    self.reapMal:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(22)
        end
    end)

	-- Reaper's March to Malabal Tor (pass)
	self.reapMalPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.reapMalPass:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT,math.floor(multiX*100),math.floor(multiY*-50), 0, 0) 
	self.reapMalPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.reapMalPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.reapMalPass:SetAlpha(1)
    self.reapMalPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.reapMalPass:SetTransformRotationZ(math.rad(90))
	self.reapMalPass:SetText(passSymbol) 
	self.reapMalPass:SetMouseEnabled(true)
    self.reapMalPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(22)
        end
    end)
    self.reapMalPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(22)))
    end)
    self.reapMalPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)

	-- Reaper's March to Cyrodiil
	self.reapCyr = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.reapCyr:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*700),math.floor(multiY*20), 0, 0) 
	self.reapCyr:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.reapCyr:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.reapCyr:SetAlpha(alpha)
    self.reapCyr:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.reapCyr:SetText(QuickMapNav:ColorMapTextById(16))
	self.reapCyr:SetMouseEnabled(true)
    self.reapCyr:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(16)
        end
    end)
	
	-- Reaper's March to Northern Elsweyr
	self.reapNorth = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.reapNorth:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-200),math.floor(multiY*-200), 0, 0) 
	self.reapNorth:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.reapNorth:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.reapNorth:SetAlpha(alpha-0.13)
    self.reapNorth:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.reapNorth:SetTransformRotationZ(math.rad(52))
	self.reapNorth:SetText(QuickMapNav:ColorMapTextById(1555))
	self.reapNorth:SetMouseEnabled(true)
    self.reapNorth:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1555)
        end
    end)

	-- Reaper's March to Northern Elsweyr (pass)
	self.reapNorthPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.reapNorthPass:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-100),math.floor(multiY*160), 0, 0) 
	self.reapNorthPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.reapNorthPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.reapNorthPass:SetAlpha(1)
    self.reapNorthPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.reapNorthPass:SetTransformRotationZ(math.rad(90))
	self.reapNorthPass:SetText(passSymbol) 
	self.reapNorthPass:SetMouseEnabled(true)
    self.reapNorthPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1555)
        end
    end)
    self.reapNorthPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(1555)))
    end)
    self.reapNorthPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)

	-- Rivenspire to Grayhome
	self.rivGray = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.rivGray:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*700),math.floor(multiY*20), 0, 0) 
	self.rivGray:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.rivGray:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.rivGray:SetAlpha(alpha-0.13)
    self.rivGray:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.rivGray:SetText(QuickMapNav:ColorMapTextById(1864))
	self.rivGray:SetMouseEnabled(true)
    self.rivGray:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(1864)
        end 
    end)
    
    
    -- Rivenspire to Glenumbra
	self.rivGle = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.rivGle:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*130),math.floor(multiY*-140), 0, 0) 
	self.rivGle:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.rivGle:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.rivGle:SetAlpha(alpha)
    self.rivGle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.rivGle:SetText(QuickMapNav:ColorMapTextById(1))
	self.rivGle:SetMouseEnabled(true)
    self.rivGle:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1)
        end
    end)
	
	-- Rivenspire to Stormhaven
	self.rivSto = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.rivSto:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*1),math.floor(multiY*-80), 0, 0) 
	self.rivSto:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.rivSto:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.rivSto:SetAlpha(alpha)
    self.rivSto:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.rivSto:SetText(QuickMapNav:ColorMapTextById(12))
	self.rivSto:SetMouseEnabled(true)
    self.rivSto:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(12)
        end
    end)

	-- Rivenspire to Stormhaven (pass)
	self.rivStoPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.rivStoPass:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*-5),math.floor(multiY*-110), 0, 0) 
	self.rivStoPass:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.rivStoPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.rivStoPass:SetAlpha(1)
    self.rivStoPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.rivStoPass:SetText(passSymbol) 
	self.rivStoPass:SetTransformRotationZ(math.rad(30))
	self.rivStoPass:SetMouseEnabled(true)
    self.rivStoPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(12)
        end
    end)
    self.rivStoPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(12))) 
    end)
    self.rivStoPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)

	-- Rivenspire to Wrothgar
	self.rivWroth = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.rivWroth:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-250),math.floor(multiY*-130), 0, 0) 
	self.rivWroth:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.rivWroth:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.rivWroth:SetAlpha(alpha)
    self.rivWroth:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.rivWroth:SetText(QuickMapNav:ColorMapTextById(667))
	self.rivWroth:SetMouseEnabled(true)
    self.rivWroth:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(667)
        end
    end)
	
	-- Shadowfen to Deshaan
	self.shaDesh = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.shaDesh:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-350),math.floor(multiY*10), 0, 0) 
	self.shaDesh:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.shaDesh:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.shaDesh:SetAlpha(alpha)
    self.shaDesh:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.shaDesh:SetText(QuickMapNav:ColorMapTextById(13)) 
	self.shaDesh:SetMouseEnabled(true)
    self.shaDesh:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(13)
        end
    end)

	-- Shadowfen to Deshaan (pass)
	self.shaDeshPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.shaDeshPass:SetAnchor(TOP, ZO_WorldMapContainer, TOP,math.floor(multiX*70),math.floor(multiY*125), 0, 0) 
	self.shaDeshPass:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.shaDeshPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.shaDeshPass:SetAlpha(1)
    self.shaDeshPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.shaDeshPass:SetText(passSymbol) 
	self.shaDeshPass:SetMouseEnabled(true)
    self.shaDeshPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(13)
        end
    end)
    self.shaDeshPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(13)))
    end)
    self.shaDeshPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Shadowfen to Blackwood
	self.shaBlack = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.shaBlack:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*60),math.floor(multiY*-10), 0, 0) 
	self.shaBlack:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.shaBlack:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.shaBlack:SetAlpha(alpha)
    self.shaBlack:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.shaBlack:SetText(QuickMapNav:ColorMapTextById(1887))
	self.shaBlack:SetMouseEnabled(true)
    self.shaBlack:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1887)
        end
    end)
	
	-- Shadowfen to Blackwood (pass)
	self.shaBlackPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.shaBlackPass:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*260),math.floor(multiY*-85), 0, 0) 
	self.shaBlackPass:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.shaBlackPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.shaBlackPass:SetAlpha(1)
    self.shaBlackPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.shaBlackPass:SetText(passSymbol) 
	self.shaBlackPass:SetMouseEnabled(true)
    self.shaBlackPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1887)
        end
    end)
    self.shaBlackPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(1887)))
    end)
    self.shaBlackPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)

    -- Southern Elsweyr to Khenarthi's Roost
	self.southKhen = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.southKhen:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*100),math.floor(multiY*-35), 0, 0) 
	self.southKhen:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.southKhen:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.southKhen:SetAlpha(alpha)
    self.southKhen:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.southKhen:SetText(self:SpaceToNewlineNameId(258))
	self.southKhen:SetMouseEnabled(true)
    self.southKhen:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(258)
        end
    end)

	-- Southern Elsweyr to Grahtwood
	self.southGraht = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.southGraht:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT,math.floor(multiX*-20),math.floor(multiY*-20), 0, 0) 
	self.southGraht:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.southGraht:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.southGraht:SetAlpha(alpha-0.13)
    self.southGraht:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.southGraht:SetTransformRotationZ(math.rad(90))
	self.southGraht:SetText(zo_strformat("|c000000<<1>>|r",QuickMapNav:ColorMapTextById(9)))
	self.southGraht:SetMouseEnabled(true)
    self.southGraht:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(9)
        end
    end)
    
	-- Southern Elsweyr to Blackwood
	self.southBlack = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.southBlack:SetAnchor(TOP, ZO_WorldMapContainer, TOP,math.floor(multiX*150),math.floor(multiY*20), 0, 0) 
	self.southBlack:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.southBlack:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.southBlack:SetAlpha(alpha)
    self.southBlack:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.southBlack:SetText(QuickMapNav:ColorMapTextById(1887)) 
	self.southBlack:SetMouseEnabled(true)
    self.southBlack:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1887)
        end
    end)
    
	-- Southern Elsweyr to Northern Elsweyr
	self.southNorth = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.southNorth:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*250),math.floor(multiY*20), 0, 0) 
	self.southNorth:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.southNorth:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.southNorth:SetAlpha(alpha)
    self.southNorth:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.southNorth:SetText(QuickMapNav:ColorMapTextById(1555)) 
	self.southNorth:SetMouseEnabled(true)
    self.southNorth:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1555)
        end
    end)
    
	-- Southern Elsweyr to Jode's Core
	self.southJod = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.southJod:SetAnchor(TOP, ZO_WorldMapContainer,LEFT,math.floor(multiX*60),math.floor(multiY*-160), 0, 0) 
	self.southJod:SetFont(path .. "|" .. size-3 .. "|" ..  outline)
	self.southJod:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.southJod:SetAlpha(alpha-0.13)
    self.southJod:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.southJod:SetTransformRotationZ(math.rad(90))
	self.southJod:SetText(QuickMapNav:ColorMapTextById(1668))
	self.southJod:SetMouseEnabled(true)
    self.southJod:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(1668)
        end 
    end)

    -- Southern Elsweyr to Dragonhold
	self.southDrag = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.southDrag:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM, math.floor(multiX*-140),math.floor(multiY*-85), 0, 0) 
	self.southDrag:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.southDrag:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.southDrag:SetAlpha(alpha-0.13)
    self.southDrag:SetHorizontalAlignment(TEXT_ALIGN_CENTER) 
    self.southDrag:SetText(QuickMapNav:ColorMapTextById(1687))
	self.southDrag:SetMouseEnabled(true)
    self.southDrag:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(1687)
        end
    end)
	
    -- Southern Elsweyr to Halls of Colossus
	self.southHalls = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.southHalls:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT, math.floor(multiX*55),math.floor(multiY*15), 0, 0) 
	self.southHalls:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.southHalls:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.southHalls:SetAlpha(alpha-0.13)
    self.southHalls:SetHorizontalAlignment(TEXT_ALIGN_CENTER) 
    self.southHalls:SetText(QuickMapNav:ColorMapTextById(1588))
	self.southHalls:SetMouseEnabled(true)
    self.southHalls:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(1588)
        end
    end)
	
	-- Southern Elsweyr to Solstice
	self.southSol = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.southSol:SetAnchor(BOTTOMRIGHT, ZO_WorldMapContainer, BOTTOMRIGHT, math.floor(multiX*-250), math.floor(multiY*-1), 0, 0) 
	self.southSol:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.southSol:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.southSol:SetAlpha(alpha-0.13)
    self.southSol:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.southSol:SetText(QuickMapNav:ColorMapTextById(2603)) 
	self.southSol:SetMouseEnabled(true)
    self.southSol:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(2603) 
        end
    end)
	
	-- Stonefalls to The Rift
	self.stoRift = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.stoRift:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*70),math.floor(multiY*80), 0, 0) 
	self.stoRift:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.stoRift:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.stoRift:SetAlpha(alpha-0.13)
    self.stoRift:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.stoRift:SetTransformRotationZ(math.rad(45))
	self.stoRift:SetText(QuickMapNav:ColorMapTextById(125))
	self.stoRift:SetMouseEnabled(true)
    self.stoRift:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(125)
        end
    end)

	-- Stonefalls to The Rift (pass)
	self.stoRiftPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.stoRiftPass:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*120),math.floor(multiY*100), 0, 0) 
	self.stoRiftPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.stoRiftPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.stoRiftPass:SetAlpha(1)
    self.stoRiftPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.stoRiftPass:SetTransformRotationZ(math.rad(15))
	self.stoRiftPass:SetText(passSymbol) 
	self.stoRiftPass:SetMouseEnabled(true)
    self.stoRiftPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(125)
        end
    end)
    self.stoRiftPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(125)))
    end)
    self.stoRiftPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)

	-- Stonefalls to Cyrodiil
	self.stoCrag = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.stoCrag:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*45),math.floor(multiY*250), 0, 0) 
	self.stoCrag:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.stoCrag:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.stoCrag:SetAlpha(alpha-0.13)
    self.stoCrag:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.stoCrag:SetTransformRotationZ(math.rad(70))
	self.stoCrag:SetText(QuickMapNav:ColorMapTextById(16))
	self.stoCrag:SetMouseEnabled(true)
    self.stoCrag:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(16)
        end
    end)

	-- Stonefalls to Deshaan
	self.stoDesh = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.stoDesh:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-250),math.floor(multiY*-130), 0, 0) 
	self.stoDesh:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.stoDesh:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.stoDesh:SetAlpha(alpha)
    self.stoDesh:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.stoDesh:SetText(QuickMapNav:ColorMapTextById(13))
	self.stoDesh:SetMouseEnabled(true)
    self.stoDesh:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(13)
        end
    end)
	
	-- Stonefalls to Deshaan (pass)
	self.stoDeshPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.stoDeshPass:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*-70),math.floor(multiY*-170), 0, 0) 
	self.stoDeshPass:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.stoDeshPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.stoDeshPass:SetAlpha(1)
    self.stoDeshPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.stoDeshPass:SetText(passSymbol) 
	self.stoDeshPass:SetTransformRotationZ(math.rad(15))
	self.stoDeshPass:SetMouseEnabled(true)
    self.stoDeshPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(13)
        end
    end)
    self.stoDeshPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(13))) 
    end)
    self.stoDeshPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Stonefalls to Bal Foyen
	self.stoBal = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.stoBal:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*30),math.floor(multiY*5), 0, 0)
	self.stoBal:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.stoBal:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.stoBal:SetAlpha(alpha-0.13)
    self.stoBal:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.stoBal:SetTransformRotationZ(math.rad(-90))
	self.stoBal:SetText(QuickMapNav:ColorMapTextById(75))
	self.stoBal:SetMouseEnabled(true)
    self.stoBal:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(75)
        end
    end)

	-- Stonefalls to Bal Foyen (pass)
	self.stoBalPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.stoBalPass:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*-25),math.floor(multiY*-10), 0, 0)
	self.stoBalPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.stoBalPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.stoBalPass:SetAlpha(1)
    self.stoBalPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.stoBalPass:SetTransformRotationZ(math.rad(15))
	self.stoBalPass:SetText(passSymbol) 
	self.stoBalPass:SetMouseEnabled(true)
    self.stoBalPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(75)
        end
    end)
    self.stoBalPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(75))) 
    end)
    self.stoBalPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	

	-- Stonefalls to Vvardenfell
	self.stoVvar = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.stoVvar:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*700),math.floor(multiY*20), 0, 0) 
	self.stoVvar:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.stoVvar:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.stoVvar:SetAlpha(alpha)
    self.stoVvar:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.stoVvar:SetText(QuickMapNav:ColorMapTextById(1060))
	self.stoVvar:SetMouseEnabled(true)
    self.stoVvar:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1060)
        end
    end)
	
	-- Stormhaven to Glenumbra
	self.storGle = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.storGle:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*30),math.floor(multiY*250), 0, 0) 
	self.storGle:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.storGle:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.storGle:SetAlpha(alpha-0.13)
    self.storGle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.storGle:SetTransformRotationZ(math.rad(90))
	self.storGle:SetText(QuickMapNav:ColorMapTextById(1))
	self.storGle:SetMouseEnabled(true)
    self.storGle:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1)
        end
    end)

	-- Stormhaven to Glenumbra (pass)
	self.storGlePass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.storGlePass:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*50),math.floor(multiY*250), 0, 0) 
	self.storGlePass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.storGlePass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.storGlePass:SetAlpha(1)
    self.storGlePass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.storGlePass:SetTransformRotationZ(math.rad(60))
	self.storGlePass:SetText(passSymbol) 
	self.storGlePass:SetMouseEnabled(true)
    self.storGlePass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1)
        end
    end)
    self.storGlePass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(1))) 
    end)
    self.storGlePass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Stormhaven to Rivenspire
	self.storRiv = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.storRiv:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*140),math.floor(multiY*50), 0, 0) 
	self.storRiv:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.storRiv:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.storRiv:SetAlpha(alpha-0.13)
    self.storRiv:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.storRiv:SetTransformRotationZ(math.rad(30))
	self.storRiv:SetText(QuickMapNav:ColorMapTextById(10))
	self.storRiv:SetMouseEnabled(true)
    self.storRiv:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(10)
        end
    end)

	-- Stormhaven to Rivenspire (pass)
	self.storRivPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.storRivPass:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*210),math.floor(multiY*80), 0, 0) 
	self.storRivPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.storRivPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.storRivPass:SetAlpha(1)
    self.storRivPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.storRivPass:SetText(passSymbol) 
	self.storRivPass:SetMouseEnabled(true)
    self.storRivPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(10)
        end
    end)
    self.storRivPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(10))) 
    end)
    self.storRivPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Stormhaven Tor to Wrothgar
	self.storWroth = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.storWroth:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*400),math.floor(multiY*200), 0, 0)
	self.storWroth:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.storWroth:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.storWroth:SetAlpha(alpha-0.13)
    self.storWroth:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.storWroth:SetTransformRotationZ(math.rad(-30))
	self.storWroth:SetText(QuickMapNav:ColorMapTextById(667))
	self.storWroth:SetMouseEnabled(true)
    self.storWroth:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(667)
        end
    end)

	-- Stormhaven to Wrothgar (pass)
	self.storWrothPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.storWrothPass:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*360),math.floor(multiY*200), 0, 0)
	self.storWrothPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.storWrothPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.storWrothPass:SetAlpha(1)
    self.storWrothPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.storWrothPass:SetTransformRotationZ(math.rad(-30))
	self.storWrothPass:SetText(passSymbol) 
	self.storWrothPass:SetMouseEnabled(true)
    self.storWrothPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(667)
        end
    end)
    self.storWrothPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(667))) 
    end)
    self.storWrothPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Stormhaven to Bangkorai
	self.storBan = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.storBan:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*-20),math.floor(multiY*150), 0, 0) 
	self.storBan:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.storBan:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.storBan:SetAlpha(alpha-0.13)
    self.storBan:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.storBan:SetTransformRotationZ(math.rad(45))
	self.storBan:SetText(QuickMapNav:ColorMapTextById(20))
	self.storBan:SetMouseEnabled(true)
    self.storBan:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(20)
        end
    end)
    
	-- Stormhaven to Bangkorai (pass)
	self.storBanPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.storBanPass:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*-40),math.floor(multiY*-30), 0, 0) 
	self.storBanPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.storBanPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.storBanPass:SetAlpha(1)
    self.storBanPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.storBanPass:SetTransformRotationZ(math.rad(-60))
	self.storBanPass:SetText(passSymbol) 
	self.storBanPass:SetMouseEnabled(true)
    self.storBanPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(20)
        end
    end)
	self.storBanPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(20))) 
    end)
    self.storBanPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
    
	-- Stormhaven to Alik'r Desert
	self.storAlik = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.storAlik:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*450),math.floor(multiY*-90), 0, 0) 
	self.storAlik:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.storAlik:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.storAlik:SetAlpha(alpha-0.13)
    self.storAlik:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.storAlik:SetTransformRotationZ(math.rad(15))
	self.storAlik:SetText(QuickMapNav:ColorMapTextById(30)) 
	self.storAlik:SetMouseEnabled(true)
    self.storAlik:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(30)
        end
    end)
    
    -- Stormhaven to Isle of Balfiera
	self.storBal = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.storBal:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT, math.floor(multiX*50),math.floor(multiY*-190), 0, 0) 
	self.storBal:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.storBal:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.storBal:SetAlpha(alpha-0.13)
    self.storBal:SetHorizontalAlignment(TEXT_ALIGN_CENTER) 
    self.storBal:SetText(self:SpaceToNewlineNameId(1997))
	self.storBal:SetMouseEnabled(true)
    self.storBal:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(1997)
        end
    end)
    
	-- Stros M'Kai to Hew's Bane
	self.strosHew = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.strosHew:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-40),math.floor(multiY*70), 0, 0) 
	self.strosHew:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.strosHew:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.strosHew:SetAlpha(alpha)
    self.strosHew:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.strosHew:SetText(self:SpaceToNewlineNameId(994))
	self.strosHew:SetMouseEnabled(true)
    self.strosHew:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(994)
        end
    end)
    
	-- Stros M'Kai Tor to Gold Coast
	self.strosGold = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.strosGold:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*30),math.floor(multiY*10), 0, 0) 
	self.strosGold:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.strosGold:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.strosGold:SetAlpha(alpha-0.13)
    self.strosGold:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.strosGold:SetTransformRotationZ(math.rad(-90))
	self.strosGold:SetText(QuickMapNav:ColorMapTextById(1006))
	self.strosGold:SetMouseEnabled(true)
    self.strosGold:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1006)
        end
    end)
    
	-- Stros M'Kai to Malabal Tor
	self.strosMal = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.strosMal:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-70),math.floor(multiY*-175), 0, 0) 
	self.strosMal:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.strosMal:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.strosMal:SetAlpha(alpha-0.13)
    self.strosMal:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.strosMal:SetTransformRotationZ(math.rad(60))
	self.strosMal:SetText(QuickMapNav:ColorMapTextById(22))
	self.strosMal:SetMouseEnabled(true)
    self.strosMal:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(22)
        end
    end)
    
	-- Stros M'Kai to Greenshade
	self.strosGreen = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.strosGreen:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-200),math.floor(multiY*-70), 0, 0) 
	self.strosGreen:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.strosGreen:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.strosGreen:SetAlpha(alpha)
    self.strosGreen:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.strosGreen:SetText(QuickMapNav:ColorMapTextById(300))
	self.strosGreen:SetMouseEnabled(true)
    self.strosGreen:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(300)
        end
    end)

	-- Stros M'Kai to Auridon
	self.strosAur = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.strosAur:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-350),math.floor(multiY*-10), 0, 0) 
	self.strosAur:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.strosAur:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.strosAur:SetAlpha(alpha)
    self.strosAur:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.strosAur:SetText(QuickMapNav:ColorMapTextById(143)) 
	self.strosAur:SetMouseEnabled(true)
    self.strosAur:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(143)
        end
    end)

    -- Stros M'Kai to Summerset
	self.strosSum = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.strosSum:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*100),math.floor(multiY*-85), 0, 0) 
	self.strosSum:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.strosSum:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.strosSum:SetAlpha(alpha)
    self.strosSum:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.strosSum:SetText(QuickMapNav:ColorMapTextById(1349)) 
	self.strosSum:SetMouseEnabled(true)
    self.strosSum:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1349)
        end
    end)
    
	-- Stros M'Kai to High isle
	self.strosHigh = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.strosHigh:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*50),math.floor(multiY*-150), 0, 0) 
	self.strosHigh:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.strosHigh:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.strosHigh:SetAlpha(alpha)
    self.strosHigh:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.strosHigh:SetText(QuickMapNav:SpaceToNewlineNameId(2114))
	self.strosHigh:SetMouseEnabled(true)
    self.strosHigh:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(2114)
        end
    end)
	
	-- Stros M'Kai to Eyevea
	self.strosEye = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.strosEye:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*80),math.floor(multiY*-205), 0, 0) 
	self.strosEye:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.strosEye:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.strosEye:SetAlpha(alpha-0.13)
    self.strosEye:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.strosEye:SetText(QuickMapNav:ColorPortalMapTextById(108)) 
	self.strosEye:SetMouseEnabled(true)
    self.strosEye:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(108)
        end
    end)
    
	-- Stros M'Kai to Stirk
	self.strosStirk = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.strosStirk:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-35),math.floor(multiY*-250), 0, 0) 
	self.strosStirk:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.strosStirk:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.strosStirk:SetAlpha(alpha-0.13)
    self.strosStirk:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.strosStirk:SetText(QuickMapNav:ColorMapTextById(415))
	self.strosStirk:SetMouseEnabled(true)
    self.strosStirk:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		        WORLD_MAP_MANAGER:SetMapById(415)
        end
    end)
    
    
	-- Summerset to Auridon
	self.sumAur = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.sumAur:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-70),math.floor(multiY*175), 0, 0) 
	self.sumAur:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.sumAur:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.sumAur:SetAlpha(alpha-0.13)
    self.sumAur:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.sumAur:SetTransformRotationZ(math.rad(-90))
	self.sumAur:SetText(QuickMapNav:ColorMapTextById(143)) 
	self.sumAur:SetMouseEnabled(true)
    self.sumAur:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(143)
        end
    end)

	-- Summerset to Stros M'Kai
	self.sumStros = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.sumStros:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-350),math.floor(multiY*10), 0, 0) 
	self.sumStros:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.sumStros:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.sumStros:SetAlpha(alpha)
    self.sumStros:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.sumStros:SetText(QuickMapNav:ColorMapTextById(201)) 
	self.sumStros:SetMouseEnabled(true)
    self.sumStros:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(201)
        end
    end)

	-- Summerset to Artaeum
	self.sumArt = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.sumArt:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-300),math.floor(multiY*-50), 0, 0) 
	self.sumArt:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.sumArt:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.sumArt:SetAlpha(alpha)
    self.sumArt:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.sumArt:SetText(QuickMapNav:ColorPortalMapTextById(1429)) 
	self.sumArt:SetMouseEnabled(true)
    self.sumArt:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1429)
        end
    end)
    
	-- Summerset to Greenshade
	self.sumGre = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.sumGre:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-70),math.floor(multiY*-190), 0, 0) 
	self.sumGre:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.sumGre:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.sumGre:SetAlpha(alpha-0.13)
    self.sumGre:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.sumGre:SetTransformRotationZ(math.rad(-90))
	self.sumGre:SetText(QuickMapNav:ColorMapTextById(300)) 
	self.sumGre:SetMouseEnabled(true)
    self.sumGre:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(300)
        end
    end)
	
	-- Summerset to High isle
	self.sumHigh = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.sumHigh:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*160),math.floor(multiY*10), 0, 0) 
	self.sumHigh:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.sumHigh:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.sumHigh:SetAlpha(alpha)
    self.sumHigh:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.sumHigh:SetText(QuickMapNav:ColorMapTextById(2114)) 
	self.sumHigh:SetMouseEnabled(true)
    self.sumHigh:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(2114)
        end
    end)
    
	-- Summerset to Eyevea
	self.sumEye = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.sumEye:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*200),math.floor(multiY*40), 0, 0) 
	self.sumEye:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.sumEye:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.sumEye:SetAlpha(alpha-0.13)
    self.sumEye:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.sumEye:SetText(QuickMapNav:ColorPortalMapTextById(108))
	self.sumEye:SetMouseEnabled(true)
    self.sumEye:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(108)
        end
    end)

    
	-- Summerset to Wasten Coraldale
	self.sumWast = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.sumWast:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*70),math.floor(multiY*470), 0, 0)  
	self.sumWast:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.sumWast:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.sumWast:SetAlpha(alpha-0.13)
    self.sumWast:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.sumWast:SetText(self:SpaceToNewlineNameId(1469))
	self.sumWast:SetMouseEnabled(true)
    self.sumWast:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		        WORLD_MAP_MANAGER:SetMapById(1469)
        end
    end)

	-- Summerset to College of Sapiarchs
	self.sumSap = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.sumSap:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*45),math.floor(multiY*300), 0, 0)  
	self.sumSap:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.sumSap:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.sumSap:SetAlpha(alpha-0.13)
    self.sumSap:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.sumSap:SetText(self:SpaceToNewlineNameId(1412))
	self.sumSap:SetMouseEnabled(true)
    self.sumSap:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		        WORLD_MAP_MANAGER:SetMapById(1412)
        end
    end)
	
	-- The Reach to Western Skyrim
	self.reachWest = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.reachWest:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-350),math.floor(multiY*10), 0, 0) 
	self.reachWest:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.reachWest:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.reachWest:SetAlpha(alpha)
    self.reachWest:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.reachWest:SetText(QuickMapNav:ColorMapTextById(1719)) 
	self.reachWest:SetMouseEnabled(true)
    self.reachWest:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1719)
        end
    end)

	-- The Reach to Western Skyrim (pass)
	self.reachWestPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.reachWestPass:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*-315),math.floor(multiY*-147), 0, 0) 
	self.reachWestPass:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.reachWestPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.reachWestPass:SetAlpha(1)
    self.reachWestPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.reachWestPass:SetText(passSymbol) 
	self.reachWestPass:SetTransformRotationZ(math.rad(-45))
	self.reachWestPass:SetMouseEnabled(true)
    self.reachWestPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1719)
        end
    end)
    self.reachWestPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(1719)))
    end)
    self.reachWestPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
    
	-- The Reach to Craglorn
	self.reachCrag = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.reachCrag:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*400),math.floor(multiY*-10), 0, 0) 
	self.reachCrag:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.reachCrag:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.reachCrag:SetAlpha(alpha)
    self.reachCrag:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.reachCrag:SetText(QuickMapNav:ColorMapTextById(1126)) 
	self.reachCrag:SetMouseEnabled(true)
    self.reachCrag:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1126)
        end
    end)
    
	--  The Reach to Bangkorai
	self.reachBang = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.reachBang:SetAnchor(TOP, ZO_WorldMapContainer, LEFT,math.floor(multiX*30),math.floor(multiY*10), 0, 0) 
	self.reachBang:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.reachBang:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.reachBang:SetAlpha(alpha-0.13)
    self.reachBang:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.reachBang:SetTransformRotationZ(math.rad(90))
	self.reachBang:SetText(QuickMapNav:ColorMapTextById(20))
	self.reachBang:SetMouseEnabled(true)
    self.reachBang:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(20)
        end
    end)
    
	-- The Reach to Wrothgar
	self.reaWroth = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.reaWroth:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*80),math.floor(multiY*120), 0, 0) 
	self.reaWroth:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.reaWroth:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.reaWroth:SetAlpha(alpha)
    self.reaWroth:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.reaWroth:SetText(QuickMapNav:ColorMapTextById(667)) 
	self.reaWroth:SetMouseEnabled(true)
    self.reaWroth:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(667)
        end
    end)
	
	-- The Reach to Earthforge 
	self.reaEarth = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.reaEarth:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*60),math.floor(multiY*300), 0, 0) 
	self.reaEarth:SetFont(path .. "|" .. size-2 .. "|" ..  outline)
	self.reaEarth:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.reaEarth:SetAlpha(alpha-0.13)
    self.reaEarth:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.reaEarth:SetTransformRotationZ(math.rad(60))
	self.reaEarth:SetText(QuickMapNav:ColorMapTextById(103))
	self.reaEarth:SetMouseEnabled(true)
    self.reaEarth:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(103)
        end
    end)
	
	-- The Rift to Eastmarch
	self.riftEast = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.riftEast:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*400),math.floor(multiY*80), 0, 0)
	self.riftEast:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.riftEast:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.riftEast:SetAlpha(alpha)
    self.riftEast:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.riftEast:SetText(QuickMapNav:ColorMapTextById(61)) 
	self.riftEast:SetMouseEnabled(true)
    self.riftEast:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(61)
        end
    end)
    
	-- The Rift to Eastmarch (pass)
	self.riftEastPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.riftEastPass:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-280),math.floor(multiY*160), 0, 0)
	self.riftEastPass:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.riftEastPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.riftEastPass:SetAlpha(1)
    self.riftEastPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.riftEastPass:SetText(passSymbol) 
	self.riftEastPass:SetMouseEnabled(true)
    self.riftEastPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(61)
        end
    end)
    self.riftEastPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(61)))
    end)
    self.riftEastPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- The Rift to Stonefalls
	self.riftStone = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.riftStone:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-70),math.floor(multiY*-175), 0, 0) 
	self.riftStone:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.riftStone:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.riftStone:SetAlpha(alpha)
    self.riftStone:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.riftStone:SetText(QuickMapNav:ColorMapTextById(7)) 
	self.riftStone:SetMouseEnabled(true)
    self.riftStone:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(7)
        end
    end)

	-- The Rift to Stonefalls (pass)
	self.riftStonePass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.riftStonePass:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-60),math.floor(multiY*-260), 0, 0) 
	self.riftStonePass:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.riftStonePass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.riftStonePass:SetAlpha(1)
    self.riftStonePass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.riftStonePass:SetText(passSymbol) 
    self.riftStonePass:SetTransformRotationZ(math.rad(15))
	self.riftStonePass:SetMouseEnabled(true)
    self.riftStonePass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(7)
        end
    end)
    self.riftStonePass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(7)))
    end)
    self.riftStonePass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)

	-- The Rift to Cyrodiil
	self.riftCyr = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.riftCyr:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*300),math.floor(multiY*-220), 0, 0) 
	self.riftCyr:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.riftCyr:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.riftCyr:SetAlpha(alpha)
    self.riftCyr:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.riftCyr:SetText(QuickMapNav:ColorMapTextById(16)) 
	self.riftCyr:SetMouseEnabled(true)
    self.riftCyr:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(16)
        end
    end)
	
	-- The Rift to Jerall Mountains
	self.riftGer = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.riftGer:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*75),math.floor(multiY*-220), 0, 0) 
	self.riftGer:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.riftGer:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.riftGer:SetAlpha(alpha-0.13)
    self.riftGer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.riftGer:SetText(QuickMapNav:ColorMapTextById(1056))
	self.riftGer:SetMouseEnabled(true)
    self.riftGer:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(1056)
        end
    end)
    
	-- The Rift to Arcwind point
	self.riftArc = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.riftArc:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT,math.floor(multiX*70),math.floor(multiY*20), 0, 0) 
	self.riftArc:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.riftArc:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
  self.riftArc:SetAlpha(alpha-0.13)
  self.riftArc:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.riftArc:SetTransformRotationZ(math.rad(-30))
	self.riftArc:SetText(QuickMapNav:ColorMapTextById(590))
	self.riftArc:SetMouseEnabled(true)
  self.riftArc:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(590)
        end
    end)
    
	-- The Rift to Jerall Pass
	self.riftJerp = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.riftJerp:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT,math.floor(multiX*5),math.floor(multiY*25), 0, 0) 
	self.riftJerp:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.riftJerp:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
  self.riftJerp:SetAlpha(alpha-0.13)
  self.riftJerp:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
  self.riftJerp:SetTransformRotationZ(math.rad(90))
	self.riftJerp:SetText(QuickMapNav:ColorMapTextById(2847))
	self.riftJerp:SetMouseEnabled(true)
  self.riftJerp:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(2847)
        end
    end)
	
	-- The Rift to Vvardenfell
	self.riftVvar = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.riftVvar:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT ,math.floor(multiX*-20),math.floor(multiY*-150), 0, 0)
	self.riftVvar:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.riftVvar:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.riftVvar:SetAlpha(alpha-0.13)
    self.riftVvar:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.riftVvar:SetTransformRotationZ(math.rad(-90))
	self.riftVvar:SetText(QuickMapNav:ColorMapTextById(1060)) 
	self.riftVvar:SetMouseEnabled(true)
    self.riftVvar:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1060)
        end
    end)
    
	-- Vvardenfell to Bleakrock Isle
	self.vvarBleak = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.vvarBleak:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*30),math.floor(multiY*130), 0, 0) 
	self.vvarBleak:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.vvarBleak:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.vvarBleak:SetAlpha(alpha-0.13)
    self.vvarBleak:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.vvarBleak:SetTransformRotationZ(math.rad(90))
	self.vvarBleak:SetText(QuickMapNav:ColorMapTextById(74)) 
	self.vvarBleak:SetMouseEnabled(true)
    self.vvarBleak:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(74)
        end
    end)
    
	-- Vvardenfell to Eastmarch
	self.vvarEast = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.vvarEast:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*30),math.floor(multiY*300), 0, 0) 
	self.vvarEast:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.vvarEast:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.vvarEast:SetAlpha(alpha-0.1)
    self.vvarEast:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.vvarEast:SetTransformRotationZ(math.rad(90))
	self.vvarEast:SetText(QuickMapNav:ColorMapTextById(61)) 
	self.vvarEast:SetMouseEnabled(true)
    self.vvarEast:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(61)
        end
    end)
    
	-- Vvardenfell to Stonefalls
	self.vvarStone = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.vvarStone:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*400),math.floor(multiY*-10), 0, 0) 
	self.vvarStone:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.vvarStone:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.vvarStone:SetAlpha(alpha)
    self.vvarStone:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.vvarStone:SetText(QuickMapNav:ColorMapTextById(7)) 
	self.vvarStone:SetMouseEnabled(true)
    self.vvarStone:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(7)
        end
    end)
	
	-- Vvardenfell to Firemoth Island
	self.vvarFir = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.vvarFir:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*225),math.floor(multiY*-75), 0, 0) 
	self.vvarFir:SetFont(path .. "|" .. size-2 .. "|" ..  outline)
	self.vvarFir:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.vvarFir:SetAlpha(alpha-0.13)
    self.vvarFir:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.vvarFir:SetText(QuickMapNav:ColorMapTextById(1248)) 
	self.vvarFir:SetMouseEnabled(true)
    self.vvarFir:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		        WORLD_MAP_MANAGER:SetMapById(1248)
        end
    end)

	-- Vvardenfell to Bal Foyen
	self.vvarBal = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.vvarBal:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-170),math.floor(multiY*-10), 0, 0) 
	self.vvarBal:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.vvarBal:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.vvarBal:SetAlpha(alpha)
    self.vvarBal:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.vvarBal:SetText(QuickMapNav:ColorMapTextById(75)) 
	self.vvarBal:SetMouseEnabled(true)
    self.vvarBal:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(75)
        end
    end)
    
    -- Vvardenfell to The Rift
	self.vvarRift = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.vvarRift:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*30),math.floor(multiY*-175), 0, 0) 
	self.vvarRift:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.vvarRift:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.vvarRift:SetAlpha(alpha-0.13)
    self.vvarRift:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.vvarRift:SetTransformRotationZ(math.rad(90))
	self.vvarRift:SetText(QuickMapNav:ColorMapTextById(125))
	self.vvarRift:SetMouseEnabled(true)
    self.vvarRift:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(125)
        end
    end)
	
    -- Vvardenfell to Telvanni Peninsula
	self.vvarTel = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.vvarTel:SetAnchor(BOTTOMRIGHT, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*60),math.floor(multiY*-100), 0, 0) 
	self.vvarTel:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.vvarTel:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.vvarTel:SetAlpha(alpha)
    self.vvarTel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.vvarTel:SetTransformRotationZ(math.rad(-90))
	self.vvarTel:SetText(QuickMapNav:ColorMapTextById(2274)) 
	self.vvarTel:SetMouseEnabled(true)
    self.vvarTel:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(2274)
        end
    end)
	
	-- Western Skyrim to The Reach
	self.skyReach = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.skyReach:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*60),math.floor(multiY*-170), 0, 0) 
	self.skyReach:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.skyReach:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.skyReach:SetAlpha(alpha)
    self.skyReach:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.skyReach:SetText(QuickMapNav:ColorMapTextById(1814)) 
	self.skyReach:SetMouseEnabled(true)
    self.skyReach:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1814)
        end
    end)

	-- Western Skyrim to The Reach (pass)
	self.skyReachPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.skyReachPass:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*200),math.floor(multiY*-177), 0, 0) 
	self.skyReachPass:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.skyReachPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.skyReachPass:SetAlpha(1)
    self.skyReachPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.skyReachPass:SetText(passSymbol) 
    self.skyReachPass:SetTransformRotationZ(math.rad(-45))
	self.skyReachPass:SetMouseEnabled(true)
    self.skyReachPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1814)
        end
    end)
    self.skyReachPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(1814)))
    end)
    self.skyReachPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
    
	-- Western Skyrim to Wrothgar
	self.westWroth = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.westWroth:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT,math.floor(multiX*-20), math.floor(multiY*10), 0, 0) 
	self.westWroth:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.westWroth:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.westWroth:SetAlpha(alpha-0.13)
    self.westWroth:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.westWroth:SetTransformRotationZ(math.rad(90))
	self.westWroth:SetText(QuickMapNav:ColorMapTextById(667))
	self.westWroth:SetMouseEnabled(true)
    self.westWroth:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(667)
        end
    end)
	
	-- Western Skyrim to Greymoor Caverns
	self.westGrey = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.westGrey:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM, math.floor(multiX*-65),math.floor(multiY*-200), 0, 0)
	self.westGrey:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.westGrey:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.westGrey:SetAlpha(1)
    self.westGrey:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.westGrey:SetText(passSymbol) 
	self.westGrey:SetMouseEnabled(true)
    self.westGrey:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1747)
        end
    end)
    self.westGrey:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(1747))) 
    end)
    self.westGrey:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Western Skyrim to Red Eagle Ridge 
	self.westRed = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.westRed:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*-150),math.floor(multiY*-175), 0, 0) 
	self.westRed:SetFont(path .. "|" .. size-2 .. "|" ..  outline)
	self.westRed:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.westRed:SetAlpha(alpha-0.13)
    self.westRed:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.westRed:SetText(QuickMapNav:ColorMapTextById(1821))
	self.westRed:SetMouseEnabled(true)
    self.westRed:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		    WORLD_MAP_MANAGER:SetMapById(1821)
        end
    end)
	
	-- Wrothgar to Bangkorai
	self.wrothBang = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.wrothBang:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-150),math.floor(multiY*-90), 0, 0) 
	self.wrothBang:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.wrothBang:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.wrothBang:SetAlpha(alpha-0.13)
    self.wrothBang:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.wrothBang:SetTransformRotationZ(math.rad(30))
	self.wrothBang:SetText(QuickMapNav:ColorMapTextById(20)) 
	self.wrothBang:SetMouseEnabled(true)
    self.wrothBang:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(20)
        end
    end)

	-- Wrothgar to Bangkorai (pass)
	self.wrothBangPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.wrothBangPass:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*90),math.floor(multiY*-140), 0, 0) 
	self.wrothBangPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.wrothBangPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.wrothBangPass:SetAlpha(1)
    self.wrothBangPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.wrothBangPass:SetText(passSymbol) 
	self.wrothBangPass:SetMouseEnabled(true)
    self.wrothBangPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(20)
        end
    end)
	self.wrothBangPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(20))) 
    end)
    self.wrothBangPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Wrothgar to Stormhaven
	self.wrothStorm = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.wrothStorm:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*300),math.floor(multiY*-10), 0, 0) 
	self.wrothStorm:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.wrothStorm:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.wrothStorm:SetAlpha(alpha)
    self.wrothStorm:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.wrothStorm:SetText(QuickMapNav:ColorMapTextById(12)) 
	self.wrothStorm:SetMouseEnabled(true)
    self.wrothStorm:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(12)
        end
    end)
     
	-- Wrothgar to Stormhaven (pass)
	self.wrothStormPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.wrothStormPass:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*120),math.floor(multiY*-105), 0, 0) 
	self.wrothStormPass:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.wrothStormPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.wrothStormPass:SetAlpha(1)
    self.wrothStormPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.wrothStormPass:SetText(passSymbol)  
	self.wrothStormPass:SetMouseEnabled(true)
    self.wrothStormPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(12)
        end
    end)
    self.wrothStormPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(12))) 
    end)
    self.wrothStormPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
    
	-- Wrothgar to Rivenspire
	self.wrothRiv = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.wrothRiv:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*60),math.floor(multiY*-290), 0, 0) 
	self.wrothRiv:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.wrothRiv:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.wrothRiv:SetAlpha(alpha)
    self.wrothRiv:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.wrothRiv:SetText(QuickMapNav:ColorMapTextById(10)) 
	self.wrothRiv:SetMouseEnabled(true)
    self.wrothRiv:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(10)
        end
    end)
    
    -- Wrothgar to Grayhome
	self.wrothGray = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.wrothGray:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-350),math.floor(multiY*10), 0, 0) 
	self.wrothGray:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.wrothGray:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.wrothGray:SetAlpha(alpha-0.13)
    self.wrothGray:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.wrothGray:SetText(QuickMapNav:ColorMapTextById(1864)) 
	self.wrothGray:SetMouseEnabled(true)
    self.wrothGray:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(1864) 
        end
    end)
    
    -- Wrothgar to The Reach
	self.wrothReach = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.wrothReach:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*-10),math.floor(multiY*120), 0, 0) 
	self.wrothReach:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.wrothReach:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.wrothReach:SetAlpha(alpha-0.13)
    self.wrothReach:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.wrothReach:SetTransformRotationZ(math.rad(65))
	self.wrothReach:SetText(QuickMapNav:ColorMapTextById(1814)) 
	self.wrothReach:SetMouseEnabled(true)
    self.wrothReach:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1814)
        end
    end)
    
	-- Wrothgar to Western Skyrim
	self.wrothWest = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.wrothWest:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-25), math.floor(multiY*300), 0, 0) 
	self.wrothWest:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.wrothWest:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.wrothWest:SetAlpha(alpha-0.13)
    self.wrothWest:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.wrothWest:SetTransformRotationZ(math.rad(-90))
	self.wrothWest:SetText(QuickMapNav:ColorMapTextById(1719))
	self.wrothWest:SetMouseEnabled(true)
    self.wrothWest:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1719)
        end
    end)
   
    -- Grayhome to Rivenspire
	self.grayRiven = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.grayRiven:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*200),math.floor(multiY*-85), 0, 0) 
	self.grayRiven:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.grayRiven:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.grayRiven:SetAlpha(alpha)
    self.grayRiven:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.grayRiven:SetText(QuickMapNav:ColorMapTextById(10)) 
	self.grayRiven:SetMouseEnabled(true)
    self.grayRiven:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(10)
        end
    end)
    
    
    -- Grayhome to Wrothgar
	self.grayWroth = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.grayWroth:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-140),math.floor(multiY*-175), 0, 0) 
	self.grayWroth:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.grayWroth:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.grayWroth:SetAlpha(alpha)
    self.grayWroth:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.grayWroth:SetText(QuickMapNav:ColorMapTextById(667)) 
	self.grayWroth:SetMouseEnabled(true)
    self.grayWroth:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(667)
        end
    end)
    
	-- Eyevea to Summerset
	self.eyeSum = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.eyeSum:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-250),math.floor(multiY*-70), 0, 0) 
	self.eyeSum:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.eyeSum:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.eyeSum:SetAlpha(alpha)
    self.eyeSum:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.eyeSum:SetText(QuickMapNav:ColorPortalMapTextById(1349)) 
	self.eyeSum:SetMouseEnabled(true)
    self.eyeSum:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1349)
        end
    end)
    
	-- Eyevea to Auridon
	self.eyeAur = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.eyeAur:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-30),math.floor(multiY*215), 0, 0) 
	self.eyeAur:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.eyeAur:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.eyeAur:SetAlpha(alpha-0.13)
    self.eyeAur:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.eyeAur:SetTransformRotationZ(math.rad(-90))
	self.eyeAur:SetText(QuickMapNav:ColorPortalMapTextById(143)) 
	self.eyeAur:SetMouseEnabled(true)
    self.eyeAur:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(143)
        end
    end)
    
    -- Eyevea to Stros M'Kai
	self.eyeStros = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.eyeStros:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-70),math.floor(multiY*10), 0, 0) 
	self.eyeStros:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.eyeStros:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.eyeStros:SetAlpha(alpha)
    self.eyeStros:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.eyeStros:SetText(QuickMapNav:ColorPortalMapTextById(201)) 
	self.eyeStros:SetMouseEnabled(true)
    self.eyeStros:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(201)
        end
    end)
    
    -- Eyevea to Stirk
	self.eyeStirk = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.eyeStirk:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-200),math.floor(multiY*10), 0, 0) 
	self.eyeStirk:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.eyeStirk:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.eyeStirk:SetAlpha(alpha-0.13)
    self.eyeStirk:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.eyeStirk:SetText(self:ColorPortalMapTextById(415))
	self.eyeStirk:SetMouseEnabled(true)
    self.eyeStirk:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(415) 
        end
    end)
	
	-- Eyevea to High isle
	self.eyeHigh = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.eyeHigh:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*160),math.floor(multiY*10), 0, 0) 
	self.eyeHigh:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.eyeHigh:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.eyeHigh:SetAlpha(alpha)
    self.eyeHigh:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.eyeHigh:SetText(QuickMapNav:ColorPortalMapTextById(2114)) 
	self.eyeHigh:SetMouseEnabled(true)
    self.eyeHigh:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(2114)
        end
    end)
	
	-- Eyevea wayshrine 
	self.eyeWay = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.eyeWay:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*-106),math.floor(multiY*-117), 0, 0) 
	self.eyeWay:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.eyeWay:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.eyeWay:SetAlpha(1)
    self.eyeWay:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.eyeWay:SetText(QMN.WSSymbol)
	self.eyeWay:SetMouseEnabled(true)
	local eyeknown, eyerecallLocationName = GetFastTravelNodeInfo(215)
    self.eyeWay:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside and eyeknown and QMN.FastTravelInteraction then
			 FastTravelToNode(215)
        end
    end)
    self.eyeWay:SetHandler("OnMouseEnter", function(self)
	    if eyeknown and QMN.FastTravelInteraction then
            ZO_Tooltips_ShowTextTooltip(self, TOP, eyerecallLocationName.." "..GetString(WAYSHRINE).."\n"..GetString(SI_TOOLTIP_WAYSHRINE_CLICK_TO_RECALL))
		else
		    ZO_Tooltips_ShowTextTooltip(self, TOP, eyerecallLocationName.." "..GetString(WAYSHRINE).."\n"..GetString(WAYSHRINE_ONLY))
        end		
    end)
    self.eyeWay:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	local playerAlliance = GetUnitAlliance("player")
	local EyeveaPortalOne
	local EyeveaPortalTwo
	local EyeveaPortalThree
	local EyeveaPortalFour
	local EyeveaPortalFive
	
	if playerAlliance == ALLIANCE_EBONHEART_PACT then
		 EyeveaPortalOne = 7 -- Stonefalls
		 EyeveaPortalTwo = 13 -- Deshaan
		 EyeveaPortalThree = 26 -- shadowfen
		 EyeveaPortalFour = 61 -- Eastmarch
		 EyeveaPortalFive = 125 -- the rift 
	
	elseif playerAlliance == ALLIANCE_DAGGERFALL_COVENANT then  
		 EyeveaPortalOne = 63 -- Daggerfall
		 EyeveaPortalTwo = 12 -- Stormhaven
		 EyeveaPortalThree = 10 -- Rivenspire
		 EyeveaPortalFour = 30 -- Alik'r
		 EyeveaPortalFive = 20 -- Bangkorai
	elseif playerAlliance == ALLIANCE_ALDMERI_DOMINION then 
		 EyeveaPortalOne =  143 -- Auridon
		 EyeveaPortalTwo = 9 -- Grahtwood
		 EyeveaPortalThree = 300 -- Greenshade
		 EyeveaPortalFour = 22 -- Malabal Tor
		 EyeveaPortalFive = 256 -- Reaper's March
	end
	
	-- Eyevea to Portal 5
	self.eyeRift = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.eyeRift:SetAnchor(LEFT, ZO_WorldMapContainer,LEFT,math.floor(multiX*285),math.floor(multiY*35), 0, 0) 
	self.eyeRift:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.eyeRift:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.eyeRift:SetAlpha(1)
    self.eyeRift:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.eyeRift:SetText(portalSymbol) 
	self.eyeRift:SetMouseEnabled(true)
    self.eyeRift:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		    WORLD_MAP_MANAGER:SetMapById(EyeveaPortalFive) 
        end
    end)
    self.eyeRift:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(EyeveaPortalFive)))
    end)
    self.eyeRift:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Eyevea to Portal 4
	self.eyeEast = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.eyeEast:SetAnchor(LEFT, ZO_WorldMapContainer,LEFT,math.floor(multiX*255),math.floor(multiY*20), 0, 0) 
	self.eyeEast:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.eyeEast:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.eyeEast:SetAlpha(1)
    self.eyeEast:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.eyeEast:SetText(portalSymbol) 
	self.eyeEast:SetMouseEnabled(true)
    self.eyeEast:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		    WORLD_MAP_MANAGER:SetMapById(EyeveaPortalFour) 
        end
    end)
    self.eyeEast:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(EyeveaPortalFour)))
    end)
    self.eyeEast:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Eyevea to Portal 3
	self.eyeSha = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.eyeSha:SetAnchor(LEFT, ZO_WorldMapContainer,LEFT,math.floor(multiX*245),math.floor(multiY*-73), 0, 0) 
	self.eyeSha:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.eyeSha:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.eyeSha:SetAlpha(1)
    self.eyeSha:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.eyeSha:SetText(portalSymbol) 
	self.eyeSha:SetMouseEnabled(true)
    self.eyeSha:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		    WORLD_MAP_MANAGER:SetMapById(EyeveaPortalThree) 
        end
    end)
    self.eyeSha:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(EyeveaPortalThree)))
    end)
    self.eyeSha:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Eyevea to Portal 2
	self.eyeDesh = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.eyeDesh:SetAnchor(LEFT, ZO_WorldMapContainer,LEFT,math.floor(multiX*285),math.floor(multiY*-85), 0, 0) 
	self.eyeDesh:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.eyeDesh:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.eyeDesh:SetAlpha(1)
    self.eyeDesh:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.eyeDesh:SetText(portalSymbol) 
	self.eyeDesh:SetMouseEnabled(true)
    self.eyeDesh:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		    WORLD_MAP_MANAGER:SetMapById(EyeveaPortalTwo) 
        end
    end)
    self.eyeDesh:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(EyeveaPortalTwo)))
    end)
    self.eyeDesh:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Eyevea to Portal 1
	self.eyeSto = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.eyeSto:SetAnchor(LEFT, ZO_WorldMapContainer,LEFT,math.floor(multiX*315),math.floor(multiY*-125), 0, 0) 
	self.eyeSto:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.eyeSto:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.eyeSto:SetAlpha(1)
    self.eyeSto:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.eyeSto:SetText(portalSymbol) 
	self.eyeSto:SetMouseEnabled(true)
    self.eyeSto:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		   if EyeveaPortalOne == "DF" then
		        WORLD_MAP_MANAGER:SetMapById(63) 
		   else 
		         WORLD_MAP_MANAGER:SetMapById(EyeveaPortalOne)
		   end
		    
        end
    end)
    self.eyeSto:SetHandler("OnMouseEnter", function(self)
		        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(EyeveaPortalOne)))
    end)
    self.eyeSto:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	
	-- High isle to Summerset
	self.highSum = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.highSum:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-300),math.floor(multiY*-10), 0, 0) 
	self.highSum:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.highSum:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.highSum:SetAlpha(alpha)
    self.highSum:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.highSum:SetText(QuickMapNav:ColorMapTextById(1349)) 
	self.highSum:SetMouseEnabled(true)
    self.highSum:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1349)
        end
    end)
	
	-- High isle to Galen
	self.highGal = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.highGal:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*150),math.floor(multiY*100), 0, 0) 
	self.highGal:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.highGal:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.highGal:SetAlpha(alpha)
    self.highGal:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.highGal:SetText(QuickMapNav:ColorMapTextById(2212)) 
	self.highGal:SetMouseEnabled(true)
    self.highGal:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(2212)
        end
    end)
    
	-- High isle to Auridon
	self.highAur = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.highAur:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-50),math.floor(multiY*-115), 0, 0) 
	self.highAur:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.highAur:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.highAur:SetAlpha(alpha)
    self.highAur:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.highAur:SetText(QuickMapNav:ColorMapTextById(143)) 
	self.highAur:SetMouseEnabled(true)
    self.highAur:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(143)
        end
    end)
    
    -- High isle to Stros M'Kai
	self.highStros = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.highStros:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-70),math.floor(multiY*120), 0, 0) 
	self.highStros:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.highStros:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.highStros:SetAlpha(alpha)
    self.highStros:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.highStros:SetText(QuickMapNav:ColorMapTextById(201)) 
	self.highStros:SetMouseEnabled(true)
    self.highStros:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(201)
        end
    end)
    
    -- High isle to Stirk
	self.highStirk = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.highStirk:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*-20),math.floor(multiY*50), 0, 0) 
	self.highStirk:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.highStirk:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.highStirk:SetAlpha(alpha-0.13)
    self.highStirk:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.highStirk:SetText(self:SpaceToNewlineNameId(415))
	self.highStirk:SetMouseEnabled(true)
    self.highStirk:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(415)
        end
    end)
	
	-- High isle to Eyevea
	self.highEye = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.highEye:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-200),math.floor(multiY*-75), 0, 0) 
	self.highEye:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.highEye:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.highEye:SetAlpha(alpha-0.13)
    self.highEye:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.highEye:SetText(self:ColorPortalMapTextById(108))
	self.highEye:SetMouseEnabled(true)
    self.highEye:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		        WORLD_MAP_MANAGER:SetMapById(108)
        end
    end)
	
	-- High isle to Betnikh
	self.highBeth = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.highBeth:SetAnchor(TOP, ZO_WorldMapContainer, TOP,math.floor(multiX*100), math.floor(multiY*5), 0, 0) 
	self.highBeth:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.highBeth:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.highBeth:SetAlpha(alpha)
    self.highBeth:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.highBeth:SetText(QuickMapNav:ColorMapTextById(227))
	self.highBeth:SetMouseEnabled(true)
    self.highBeth:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(227)
        end
    end)
	
	-- port to Eyevea
	self.portEye = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.portEye:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*1),math.floor(multiY*-15), 0, 0) 
	self.portEye:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.portEye:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.portEye:SetAlpha(alpha-0.13)
    self.portEye:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.portEye:SetText(self:ColorPortalMapTextById(108))
	self.portEye:SetMouseEnabled(true)
    self.portEye:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		        WORLD_MAP_MANAGER:SetMapById(108) 
        end
    end)
    
	-- Arkthzand Cavern to Greymoor Caverns
	self.arkthGrey = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.arkthGrey:SetAnchor(TOP, ZO_WorldMapContainer, TOP, math.floor(multiX*60),math.floor(multiY*140), 0, 0)
	self.arkthGrey:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.arkthGrey:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.arkthGrey:SetAlpha(1)
    self.arkthGrey:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.arkthGrey:SetText(passSymbol) 
	self.arkthGrey:SetMouseEnabled(true)
    self.arkthGrey:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1747)
        end
    end)
    self.arkthGrey:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(1747))) 
    end)
    self.arkthGrey:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
    
	-- Greymoor Caverns to Arkthzand Cavern
	self.greyArkth = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.greyArkth:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*100),math.floor(multiY*-220), 0, 0) 
	self.greyArkth:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.greyArkth:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.greyArkth:SetAlpha(1)
    self.greyArkth:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.greyArkth:SetText(passSymbol) 
	self.greyArkth:SetTransformRotationZ(math.rad(90))
	self.greyArkth:SetMouseEnabled(true)
    self.greyArkth:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1850)
        end
    end)
    self.greyArkth:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(1850))) 
    end)
    self.greyArkth:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Greymoor Caverns to Western Skyrim
	self.greyWest = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.greyWest:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*285),math.floor(multiY*-285), 0, 0) 
	self.greyWest:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.greyWest:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.greyWest:SetAlpha(1)
    self.greyWest:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.greyWest:SetText(passSymbol) 
	self.greyWest:SetTransformRotationZ(math.rad(-15))
	self.greyWest:SetMouseEnabled(true)
    self.greyWest:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1719)
        end
    end)
    self.greyWest:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(1719))) 
    end)
    self.greyWest:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	

	-- Greymoor Caverns to Mzark Cavern
	self.greyMzark = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.greyMzark:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-80),math.floor(multiY*-225), 0, 0) 
	self.greyMzark:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.greyMzark:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.greyMzark:SetAlpha(1)
    self.greyMzark:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.greyMzark:SetText(passSymbol) 
	self.greyMzark:SetTransformRotationZ(math.rad(90))
	self.greyMzark:SetMouseEnabled(true)
    self.greyMzark:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(1748) 
        end
    end)
    self.greyMzark:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(1748))) 
    end)
    self.greyMzark:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Greymoor Caverns to Kagnthamz
	self.greyKagn = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.greyKagn:SetAnchor(BOTTOM, ZO_WorldMapContainer,BOTTOM,math.floor(multiX*65),math.floor(multiY*-120), 0, 0) 
	self.greyKagn:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.greyKagn:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.greyKagn:SetAlpha(1)
    self.greyKagn:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.greyKagn:SetText(passSymbol)
	self.greyKagn:SetTransformRotationZ(math.rad(45))
	self.greyKagn:SetMouseEnabled(true)
    self.greyKagn:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		        WORLD_MAP_MANAGER:SetMapById(1776)
        end
    end)
    self.greyKagn:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(1776))) 
    end)
    self.greyKagn:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
    
    -- Mzark Cavern to Greymoor Caverns
	self.mzarkGrey = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.mzarkGrey:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT, math.floor(multiX*2),math.floor(multiY*-95), 0, 0) 
	self.mzarkGrey:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.mzarkGrey:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.mzarkGrey:SetAlpha(1)
    self.mzarkGrey:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.mzarkGrey:SetText(passSymbol) 
    self.mzarkGrey:SetTransformRotationZ(math.rad(90))	
	self.mzarkGrey:SetMouseEnabled(true)
    self.mzarkGrey:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1747)
        end
    end)
    self.mzarkGrey:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(1747))) 
    end)
    self.mzarkGrey:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Mzark Cavern to Eastmarch
	self.mzarkEast = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.mzarkEast:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-100),math.floor(multiY*-130), 0, 0)
	self.mzarkEast:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.mzarkEast:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.mzarkEast:SetAlpha(1)
    self.mzarkEast:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.mzarkEast:SetText(passSymbol) 
	self.mzarkEast:SetTransformRotationZ(math.rad(15))
	self.mzarkEast:SetMouseEnabled(true)
    self.mzarkEast:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(61)
        end
    end)
    self.mzarkEast:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(61)))
    end)
    self.mzarkEast:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	-- Mzark Cavern to Eastmarch by lift
	self.mzarkEastLift = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.mzarkEastLift:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT,math.floor(multiX*65),math.floor(multiY*-220), 0, 0)
	self.mzarkEastLift:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.mzarkEastLift:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.mzarkEastLift:SetAlpha(1)
    self.mzarkEastLift:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.mzarkEastLift:SetText(liftSymbol) 
	self.mzarkEastLift:SetMouseEnabled(true)
    self.mzarkEastLift:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(61)
        end
    end)
    self.mzarkEastLift:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(61)))
    end)
    self.mzarkEastLift:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
    

	-- Mournhold to Clockwork City (portal) 
	self.mournClock = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.mournClock:SetAnchor(TOP, ZO_WorldMapContainer, TOP,math.floor(multiX*160),math.floor(multiY*80), 0, 0) 
	self.mournClock:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.mournClock:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.mournClock:SetAlpha(1)
    self.mournClock:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.mournClock:SetText(portalSymbol) 
	self.mournClock:SetMouseEnabled(true)
    self.mournClock:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		    WORLD_MAP_MANAGER:SetMapById(1313)
        end
    end)
    self.mournClock:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(1313)))
    end)
    self.mournClock:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
    
    -- Mournhold to Coldharbour
	self.mournCold = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.mournCold:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*200),math.floor(multiY*-15), 0, 0)
	self.mournCold:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.mournCold:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.mournCold:SetAlpha(alpha)
    self.mournCold:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.mournCold:SetText(QuickMapNav:ColorPortalMapTextById(255))
	self.mournCold:SetMouseEnabled(true)
    self.mournCold:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(255)
        end
    end)
    
   
    -- Clockwork City to Deshaan
	self.clockDesh = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.clockDesh:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*1),math.floor(multiY*-15), 0, 0)
	self.clockDesh:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.clockDesh:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.clockDesh:SetAlpha(alpha)
    self.clockDesh:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.clockDesh:SetText(QuickMapNav:ColorPortalMapTextById(13))
	self.clockDesh:SetMouseEnabled(true)
    self.clockDesh:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(13)
        end
    end)
    
	-- Stirk to Eyevea
	self.stirkEye = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.stirkEye:SetAnchor(LEFT, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*15),math.floor(multiY*-200), 0, 0) 
	self.stirkEye:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.stirkEye:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.stirkEye:SetAlpha(alpha-0.13)
    self.stirkEye:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.stirkEye:SetText(self:ColorPortalMapTextById(108))
	self.stirkEye:SetMouseEnabled(true)
    self.stirkEye:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		        WORLD_MAP_MANAGER:SetMapById(108)
        end
    end)
    
	-- Stirk to Auridon
	self.stirkAur = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.stirkAur:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*60),math.floor(multiY*-10), 0, 0) 
	self.stirkAur:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.stirkAur:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.stirkAur:SetAlpha(alpha)
    self.stirkAur:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.stirkAur:SetText(QuickMapNav:ColorMapTextById(143)) 
	self.stirkAur:SetMouseEnabled(true)
    self.stirkAur:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(143)
        end
    end)
    
	-- Stirk to Stros M'Kai
	self.stirkStros = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.stirkStros:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*75),math.floor(multiY*50), 0, 0) 
	self.stirkStros:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.stirkStros:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.stirkStros:SetAlpha(alpha)
    self.stirkStros:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.stirkStros:SetText(QuickMapNav:ColorMapTextById(201)) 
	self.stirkStros:SetMouseEnabled(true)
    self.stirkStros:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(201)
        end
    end)
	
	-- Stirk to Hew's Bane
	self.stirkHew = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.stirkHew:SetAnchor(TOP, ZO_WorldMapContainer, TOP,math.floor(multiX*-200),math.floor(multiY*10), 0, 0) 
	self.stirkHew:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.stirkHew:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.stirkHew:SetAlpha(alpha)
    self.stirkHew:SetHorizontalAlignment(TEXT_ALIGN_CENTER) 
	self.stirkHew:SetText(QuickMapNav:ColorMapTextById(994))
	self.stirkHew:SetMouseEnabled(true)
    self.stirkHew:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(994)
        end
    end)
	
	-- Stirk to High isle
	self.stirkHigh = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.stirkHigh:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT,math.floor(multiX*15),math.floor(multiY*-50), 0, 0) 
	self.stirkHigh:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.stirkHigh:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.stirkHigh:SetAlpha(alpha)
    self.stirkHigh:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.stirkHigh:SetText(QuickMapNav:SpaceToNewlineNameId(2114)) 
	self.stirkHigh:SetMouseEnabled(true)
    self.stirkHigh:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(2114)
        end
    end)
	
	-- Stirk to Malabal Tor
	self.stirkMal = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.stirkMal:SetAnchor(BOTTOM, ZO_WorldMapContainer,BOTTOMRIGHT,math.floor(multiX*-70),math.floor(multiY*-20), 0, 0) 
	self.stirkMal:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.stirkMal:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.stirkMal:SetAlpha(alpha)
    self.stirkMal:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.stirkMal:SetText(QuickMapNav:ColorMapTextById(22))
	self.stirkMal:SetMouseEnabled(true)
    self.stirkMal:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(22)
        end
    end)
	
	-- Stirk to Greenshade
	self.stirkGre = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.stirkGre:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*100),math.floor(multiY*-20), 0, 0) 
	self.stirkGre:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.stirkGre:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.stirkGre:SetAlpha(alpha)
    self.stirkGre:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.stirkGre:SetText(QuickMapNav:ColorMapTextById(300)) 
	self.stirkGre:SetMouseEnabled(true)
    self.stirkGre:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(300)
        end
    end)
	
	--Stirk to Gold Coast
	self.stirkGol = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.stirkGol:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*30),math.floor(multiY*20), 0, 0) 
	self.stirkGol:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.stirkGol:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.stirkGol:SetAlpha(alpha-0.13)
    self.stirkGol:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.stirkGol:SetTransformRotationZ(math.rad(-90))
	self.stirkGol:SetText(QuickMapNav:ColorMapTextById(1006)) 
	self.stirkGol:SetMouseEnabled(true)
    self.stirkGol:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1006)
        end
    end)
	
	-- Blackwood to Shadowfen
	self.blackSha = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.blackSha:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-70),math.floor(multiY*20), 0, 0) 
	self.blackSha:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.blackSha:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.blackSha:SetAlpha(alpha)
    self.blackSha:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.blackSha:SetText(QuickMapNav:ColorMapTextById(9)) 
	self.blackSha:SetMouseEnabled(true)
    self.blackSha:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(26)
        end
    end)
    
	-- Blackwood to Shadowfen (pass)
	self.blackShaPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.blackShaPass:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*-160),math.floor(multiY*-180), 0, 0) 
	self.blackShaPass:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.blackShaPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.blackShaPass:SetAlpha(1)
    self.blackShaPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.blackShaPass:SetText(passSymbol) 
	self.blackShaPass:SetTransformRotationZ(math.rad(-15))
	self.blackShaPass:SetMouseEnabled(true)
    self.blackShaPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(26)
        end
    end)
    self.blackShaPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(26)))
    end)
    self.blackShaPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
    
	-- Blackwood to Murkmire
	self.blackMurk = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.blackMurk:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-80),math.floor(multiY*-20), 0, 0) 
	self.blackMurk:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.blackMurk:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.blackMurk:SetAlpha(alpha)
    self.blackMurk:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.blackMurk:SetText(QuickMapNav:ColorMapTextById(1484)) 
	self.blackMurk:SetMouseEnabled(true)
    self.blackMurk:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1484)
        end
    end)
    
	-- Blackwood to Blackwood Borderlands
	self.blackBor = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.blackBor:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-60),math.floor(multiY*-160), 0, 0) 
	self.blackBor:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.blackBor:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.blackBor:SetAlpha(alpha-0.13)
    self.blackBor:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.blackBor:SetText(self:SpaceToNewlineNameId(1061)) 
	self.blackBor:SetMouseEnabled(true)
    self.blackBor:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(1061)
        end
    end)
	
	-- Blackwood to Southern Elsweyr
	self.blackSouth = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.blackSouth:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*40),math.floor(multiY*-200), 0, 0) 
	self.blackSouth:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.blackSouth:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.blackSouth:SetAlpha(alpha-0.13)
    self.blackSouth:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.blackSouth:SetTransformRotationZ(math.rad(90))
	self.blackSouth:SetText(QuickMapNav:ColorMapTextById(1654)) 
	self.blackSouth:SetMouseEnabled(true)
    self.blackSouth:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1654)
        end
    end)
	
	-- Blackwood to Northern Elsweyr
	self.blackNorth = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.blackNorth:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*100),math.floor(multiY*200), 0, 0) 
	self.blackNorth:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.blackNorth:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.blackNorth:SetAlpha(alpha-0.13)
    self.blackNorth:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.blackNorth:SetTransformRotationZ(math.rad(50))
	self.blackNorth:SetText(QuickMapNav:ColorMapTextById(1555)) 
	self.blackNorth:SetMouseEnabled(true)
    self.blackNorth:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1555)
        end
    end)
    
	-- Blackwood to Northern Elsweyr (pass)
	self.blackNorthPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.blackNorthPass:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT,math.floor(multiX*60),math.floor(multiY*-110), 0, 0) 
	self.blackNorthPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.blackNorthPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.blackNorthPass:SetAlpha(1)
    self.blackNorthPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.blackNorthPass:SetTransformRotationZ(math.rad(50))
	self.blackNorthPass:SetText(passSymbol) 
	self.blackNorthPass:SetMouseEnabled(true)
    self.blackNorthPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1555)
        end
    end)
    self.blackNorthPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(1555)))
    end)
    self.blackNorthPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
    
	-- Isle of Balfiera to Glenumbra
	self.balGle = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.balGle:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT,math.floor(multiX*-30),math.floor(multiY*20), 0, 0) 
	self.balGle:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.balGle:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.balGle:SetAlpha(alpha-0.13)
    self.balGle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.balGle:SetTransformRotationZ(math.rad(90))
	self.balGle:SetText(QuickMapNav:ColorMapTextById(1)) 
	self.balGle:SetMouseEnabled(true)
    self.balGle:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1)
        end
    end)
    
	-- Isle of Balfiera to Stormhaven
	self.balStorm = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.balStorm:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-100),math.floor(multiY*40), 0, 0)
	self.balStorm:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.balStorm:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.balStorm:SetAlpha(alpha)
    self.balStorm:SetHorizontalAlignment(TEXT_ALIGN_CENTER) 
	self.balStorm:SetText(QuickMapNav:ColorMapTextById(12))
	self.balStorm:SetMouseEnabled(true)
    self.balStorm:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(12)
        end
    end)
    
	-- Isle of Balfiera to Alik'r Desert
	self.balAlik = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.balAlik:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-50), math.floor(multiY*-125), 0, 0) 
	self.balAlik:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.balAlik:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.balAlik:SetAlpha(alpha)
    self.balAlik:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.balAlik:SetText(self:SpaceToNewlineNameId(30))
	self.balAlik:SetMouseEnabled(true)
    self.balAlik:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(30)
        end
    end)
    
	-- Jerall Mountains to The Rift
	self.jerRift = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.jerRift:SetAnchor(TOP, ZO_WorldMapContainer, TOP,math.floor(multiX*1),math.floor(multiY*40), 0, 0)
	self.jerRift:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.jerRift:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.jerRift:SetAlpha(alpha)
    self.jerRift:SetHorizontalAlignment(TEXT_ALIGN_CENTER) 
	self.jerRift:SetText(QuickMapNav:ColorMapTextById(125))
	self.jerRift:SetMouseEnabled(true)
    self.jerRift:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(125)
        end
    end)

	-- Jerall Mountains to Cyrodiil
	self.jerCyr = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.jerCyr:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*60),math.floor(multiY*-10), 0, 0) 
	self.jerCyr:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.jerCyr:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.jerCyr:SetAlpha(alpha)
    self.jerCyr:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.jerCyr:SetText(QuickMapNav:ColorMapTextById(16))
	self.jerCyr:SetMouseEnabled(true)
    self.jerCyr:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(16)
        end
    end)

	-- Valley of Blades to Craglorn
	self.valCrag = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.valCrag:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-60),math.floor(multiY*10), 0, 0) 
	self.valCrag:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.valCrag:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.valCrag:SetAlpha(alpha)
    self.valCrag:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.valCrag:SetText(QuickMapNav:ColorMapTextById(1126))
	self.valCrag:SetMouseEnabled(true)
    self.valCrag:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1126)
        end
    end)

	-- Valley of Blades to Bangkorai
	self.valBang = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.valBang:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*60),math.floor(multiY*10), 0, 0) 
	self.valBang:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.valBang:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.valBang:SetAlpha(alpha)
    self.valBang:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.valBang:SetText(QuickMapNav:ColorMapTextById(20))
	self.valBang:SetMouseEnabled(true)
    self.valBang:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(20)
        end
    end)
	
	-- Blackwood Borderlands to Blackwood 
	self.borBlack = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.borBlack:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*65),math.floor(multiY*130), 0, 0) 
	self.borBlack:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.borBlack:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.borBlack:SetAlpha(alpha)
    self.borBlack:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.borBlack:SetText(QuickMapNav:ColorMapTextById(1887)) 
	self.borBlack:SetMouseEnabled(true)
    self.borBlack:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1887)
        end
    end)

	-- Jode's Core to Northern Elsweyr
	self.jodNorth = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.jodNorth:SetAnchor(TOP, ZO_WorldMapContainer, TOP,math.floor(multiX*1),math.floor(multiY*20), 0, 0) 
	self.jodNorth:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.jodNorth:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.jodNorth:SetAlpha(alpha)
    self.jodNorth:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.jodNorth:SetText(QuickMapNav:ColorMapTextById(1555)) 
	self.jodNorth:SetMouseEnabled(true)
    self.jodNorth:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1555)
        end
    end)


	-- Jode's Core to Southern Elsweyr
	self.jodeSouth = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.jodeSouth:SetAnchor(TOP, ZO_WorldMapContainer, RIGHT,math.floor(multiX*-50),math.floor(multiY*100), 0, 0) 
	self.jodeSouth:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.jodeSouth:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.jodeSouth:SetAlpha(alpha)
    self.jodeSouth:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.jodeSouth:SetText(self:SpaceToNewlineNameId(1654)) 
	self.jodeSouth:SetMouseEnabled(true)
    self.jodeSouth:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1654)
        end
    end)


	-- Jode's Core to Grahtwood
	self.jodGrath = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.jodGrath:SetAnchor(BOTTOM, ZO_WorldMapContainer,LEFT,math.floor(multiX*70),math.floor(multiY*75), 0, 0) 
	self.jodGrath:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.jodGrath:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.jodGrath:SetAlpha(alpha)
    self.jodGrath:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.jodGrath:SetText(QuickMapNav:ColorMapTextById(9))
	self.jodGrath:SetMouseEnabled(true)
    self.jodGrath:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(9)
        end
    end)

	-- Fargrave City District to The Shambles
	self.farSham = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.farSham:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-220),math.floor(multiY*10), 0, 0)  
	self.farSham:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.farSham:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.farSham:SetAlpha(alpha-0.13)
    self.farSham:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.farSham:SetText(QuickMapNav:ColorMapTextById(2082))
	self.farSham:SetMouseEnabled(true)
    self.farSham:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(2082)
        end
    end)

	-- Fargrave City District to Greenshade
	self.farGreen = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.farGreen:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*50),math.floor(multiY*-80), 0, 0)  
	self.farGreen:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.farGreen:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.farGreen:SetAlpha(1)
    self.farGreen:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.farGreen:SetText(portalSymbol)
	self.farGreen:SetMouseEnabled(true)
    self.farGreen:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
            WORLD_MAP_MANAGER:SetMapById(300)
        end
    end)	
    self.farGreen:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(300)))
    end)
    self.farGreen:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)


	-- The Shambles to Fargrave City District 
	self.shamFar = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.shamFar:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*220),math.floor(multiY*-10), 0, 0)  
	self.shamFar:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.shamFar:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.shamFar:SetAlpha(alpha-0.13)
    self.shamFar:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.shamFar:SetText(QuickMapNav:ColorMapTextById(2035))
	self.shamFar:SetMouseEnabled(true)
    self.shamFar:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		        WORLD_MAP_MANAGER:SetMapById(2035)
        end
    end)

	-- EarthForge to Bangkorai
	self.earthBan = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.earthBan:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*80),math.floor(multiY*-30), 0, 0) 
	self.earthBan:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.earthBan:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.earthBan:SetAlpha(alpha)
    self.earthBan:SetHorizontalAlignment(TEXT_ALIGN_CENTER) 
	self.earthBan:SetText(QuickMapNav:ColorMapTextById(20)) 
	self.earthBan:SetMouseEnabled(true)
    self.earthBan:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(20)
        end
    end)
	
	-- EarthForge to The Reach
	self.earthRea = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.earthRea:SetAnchor(TOP, ZO_WorldMapContainer, RIGHT,math.floor(multiX*-70),math.floor(multiY*125), 0, 0) 
	self.earthRea:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.earthRea:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.earthRea:SetAlpha(alpha)
    self.earthRea:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.earthRea:SetText(QuickMapNav:ColorMapTextById(1814)) 
	self.earthRea:SetMouseEnabled(true)
    self.earthRea:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1814)
        end
    end)
	
	-- EarthForge wayshrine
	self.earthWay = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.earthWay:SetAnchor(TOP, ZO_WorldMapContainer, RIGHT,math.floor(multiX*-285),math.floor(multiY*90), 0, 0) 
	self.earthWay:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.earthWay:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.earthWay:SetAlpha(1)
    self.earthWay:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.earthWay:SetText(QMN.WSSymbol)
	self.earthWay:SetMouseEnabled(true)
	local earthknown, earthrecallLocationName = GetFastTravelNodeInfo(221)
    self.earthWay:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside and earthknown and QMN.FastTravelInteraction then
			 FastTravelToNode(221)
        end
    end)
    self.earthWay:SetHandler("OnMouseEnter", function(self)
	    if earthknown and QMN.FastTravelInteraction then
            ZO_Tooltips_ShowTextTooltip(self, TOP, earthrecallLocationName.." "..GetString(WAYSHRINE).."\n"..GetString(SI_TOOLTIP_WAYSHRINE_CLICK_TO_RECALL))
		else
		    ZO_Tooltips_ShowTextTooltip(self, TOP, earthrecallLocationName.." "..GetString(WAYSHRINE).."\n"..GetString(WAYSHRINE_ONLY))
        end		
    end)
    self.earthWay:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	

	-- Fort Grief to Cyrodiil
	self.fortCyr = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.fortCyr:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*50),math.floor(multiY*10), 0, 0) 
	self.fortCyr:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.fortCyr:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.fortCyr:SetAlpha(alpha)
    self.fortCyr:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.fortCyr:SetText(QuickMapNav:ColorMapTextById(16))
	self.fortCyr:SetMouseEnabled(true)
    self.fortCyr:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(16)
        end
    end)
	
	-- Galen to High isle
	self.galHigh = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.galHigh:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*10),math.floor(multiY*-30), 0, 0) 
	self.galHigh:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.galHigh:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.galHigh:SetAlpha(alpha)
    self.galHigh:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.galHigh:SetText(QuickMapNav:ColorMapTextById(2114)) 
	self.galHigh:SetMouseEnabled(true)
    self.galHigh:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(2114)
        end
    end)
	
	
    -- Telvanni Peninsula to Bal Foyen
	self.telBal = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.telBal:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT,math.floor(multiX*85),math.floor(multiY*110), 0, 0) 
	self.telBal:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.telBal:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.telBal:SetAlpha(alpha)
    self.telBal:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.telBal:SetTransformRotationZ(math.rad(-30))
	self.telBal:SetText(QuickMapNav:ColorMapTextById(75)) 
	self.telBal:SetMouseEnabled(true)
    self.telBal:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(75)
        end
    end)

    -- Telvanni Peninsula to Deshaan
	self.telDesh = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.telDesh:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM, math.floor(multiX*-250),math.floor(multiY*-20), 0, 0) 
	self.telDesh:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.telDesh:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.telDesh:SetAlpha(alpha)
    self.telDesh:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.telDesh:SetText(QuickMapNav:ColorMapTextById(13)) 
	self.telDesh:SetMouseEnabled(true)
    self.telDesh:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(13)
        end
    end)

	-- Telvanni Peninsula to Vvardenfell
	self.telVvar = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.telVvar:SetAnchor(TOPLEFT, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*100),math.floor(multiY*30), 0, 0)
	self.telVvar:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.telVvar:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.telVvar:SetAlpha(alpha)
    self.telVvar:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.telVvar:SetText(QuickMapNav:ColorMapTextById(1060)) 
	self.telVvar:SetMouseEnabled(true)
    self.telVvar:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1060)
        end
    end)

    -- Telvanni Peninsula to Deshaan (pass)
	self.telDeshPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.telDeshPass:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*300),math.floor(multiY*-130), 0, 0) 
	self.telDeshPass:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.telDeshPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.telDeshPass:SetAlpha(1)
    self.telDeshPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.telDeshPass:SetText(passSymbol) 
    self.telDeshPass:SetTransformRotationZ(math.rad(-45))
	self.telDeshPass:SetMouseEnabled(true)
    self.telDeshPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(13)
        end
    end)
    self.telDeshPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(13)))
    end)
    self.telDeshPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)


    -- Telvanni Peninsula to Bal Foyen (pass)
	self.telBalPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.telBalPass:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT,math.floor(multiX*200),math.floor(multiY*105), 0, 0) 
	self.telBalPass:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.telBalPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.telBalPass:SetAlpha(1)
    self.telBalPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.telBalPass:SetText(passSymbol) 
    self.telBalPass:SetTransformRotationZ(math.rad(-45))
	self.telBalPass:SetMouseEnabled(true)
    self.telBalPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(75)
        end
    end)
    self.telBalPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(75)))
    end)
    self.telBalPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)



	-- Arcwind Point to Cyrodiil
	self.arcCyr = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.arcCyr:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*1),math.floor(multiY*-20), 0, 0) 
	self.arcCyr:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.arcCyr:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.arcCyr:SetAlpha(alpha)
    self.arcCyr:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.arcCyr:SetText(QuickMapNav:ColorMapTextById(16)) 
	self.arcCyr:SetMouseEnabled(true)
    self.arcCyr:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(16)
        end
    end)

	-- Arcwind Point to The Rift
	self.arcRift = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.arcRift:SetAnchor(TOP, ZO_WorldMapContainer, TOP,math.floor(multiX*1),math.floor(multiY*30), 0, 0) 
	self.arcRift:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.arcRift:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.arcRift:SetAlpha(alpha)
    self.arcRift:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.arcRift:SetText(QuickMapNav:ColorMapTextById(125)) 
	self.arcRift:SetMouseEnabled(true)
    self.arcRift:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(125)
        end
    end)
    
	-- Arcwind Point to Jerall Pass
	self.arcJerp = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.arcJerp:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT,math.floor(multiX*5),math.floor(multiY*1), 0, 0) 
	self.arcJerp:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.arcJerp:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
  self.arcJerp:SetAlpha(alpha-0.13)
  self.arcJerp:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
  self.arcJerp:SetTransformRotationZ(math.rad(90))
	self.arcJerp:SetText(QuickMapNav:ColorMapTextById(2847))
	self.arcJerp:SetMouseEnabled(true)
  self.arcJerp:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(2847)
        end
    end)

	-- Imperial City to Imperial Sewers 
	self.icIs = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.icIs:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*1),math.floor(multiY*-10), 0, 0)  
	self.icIs:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.icIs:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
  self.icIs:SetAlpha(alpha-0.13)
  self.icIs:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.icIs:SetText(QuickMapNav:ColorMapTextById(657))
	self.icIs:SetMouseEnabled(true)
  self.icIs:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		        WORLD_MAP_MANAGER:SetMapById(657)
        end
    end)

	-- Imperial Sewers to Imperial City  
	self.isIc = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.isIc:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*1),math.floor(multiY*-10), 0, 0)  
	self.isIc:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.isIc:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.isIc:SetAlpha(alpha-0.13)
    self.isIc:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.isIc:SetText(QuickMapNav:ColorMapTextById(660))
	self.isIc:SetMouseEnabled(true)
    self.isIc:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		        WORLD_MAP_MANAGER:SetMapById(660)
        end
    end)

    -- Vahlokzin's Domain to Grahtwood
	self.vahlGrah = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.vahlGrah:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*55),math.floor(multiY*-40), 0, 0) 
	self.vahlGrah:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.vahlGrah:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.vahlGrah:SetAlpha(alpha)
    self.vahlGrah:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.vahlGrah:SetText(self:SpaceToNewlineNameId(9))
	self.vahlGrah:SetMouseEnabled(true)
    self.vahlGrah:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(9)
        end
    end)
	
	-- Vahlokzin's Domain to Northern Elsweyr
	self.vahlNorth = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.vahlNorth:SetAnchor(TOP, ZO_WorldMapContainer, TOP,math.floor(multiX*200),math.floor(multiY*20), 0, 0) 
	self.vahlNorth:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.vahlNorth:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.vahlNorth:SetAlpha(alpha)
    self.vahlNorth:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.vahlNorth:SetText(QuickMapNav:ColorMapTextById(1555)) 
	self.vahlNorth:SetMouseEnabled(true)
    self.vahlNorth:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1555)
        end
    end)
	
	
    -- West Weald to Reaper's March
	self.WWReap = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.WWReap:SetAnchor(BOTTOMRIGHT, ZO_WorldMapContainer, BOTTOMRIGHT,math.floor(multiX*-100),math.floor(multiY*-130), 0, 0) 
	self.WWReap:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.WWReap:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.WWReap:SetAlpha(alpha-0.13)
    self.WWReap:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.WWReap:SetText(QuickMapNav:ColorMapTextById(256)) 
	self.WWReap:SetMouseEnabled(true)
    self.WWReap:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(256)
        end
    end)

	-- West Weald to Reaper's March (pass)
	self.WWReapPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.WWReapPass:SetAnchor(BOTTOMRIGHT, ZO_WorldMapContainer, BOTTOMRIGHT, math.floor(multiX*-135),math.floor(multiY*-195), 0, 0) 
	self.WWReapPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.WWReapPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.WWReapPass:SetAlpha(1)
    self.WWReapPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.WWReapPass:SetTransformRotationZ(math.rad(0))
	self.WWReapPass:SetText(passSymbol)
	self.WWReapPass:SetMouseEnabled(true)
    self.WWReapPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(256)
        end
    end)
    self.WWReapPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(256))) 
    end)
    self.WWReapPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)	
	
	
	-- West Weald to Cyrodiil
	self.WWCyr = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.WWCyr:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*-30),math.floor(multiY*1), 0, 0) 
	self.WWCyr:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.WWCyr:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.WWCyr:SetAlpha(alpha)
    self.WWCyr:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.WWCyr:SetTransformRotationZ(math.rad(-90))
	self.WWCyr:SetText(QuickMapNav:ColorMapTextById(16)) 
	self.WWCyr:SetMouseEnabled(true)
    self.WWCyr:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(16)
        end
    end)	
	
	
	-- West Weald to Craglorn
	self.WWCrag = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.WWCrag:SetAnchor(TOP, ZO_WorldMapContainer, TOP,math.floor(multiX*30),math.floor(multiY*10), 0, 0) 
	self.WWCrag:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.WWCrag:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.WWCrag:SetAlpha(alpha-0.13)
    self.WWCrag:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.WWCrag:SetText(QuickMapNav:ColorMapTextById(1126)) 
	self.WWCrag:SetMouseEnabled(true)
    self.WWCrag:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1126)
        end
    end)
    
	-- West Weald to Craglorn (pass)
	self.WWCragPass = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.WWCragPass:SetAnchor(TOP, ZO_WorldMapContainer, TOP, math.floor(multiX*130),math.floor(multiY*70), 0, 0) 
	self.WWCragPass:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.WWCragPass:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.WWCragPass:SetAlpha(1)
    self.WWCragPass:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.WWCragPass:SetTransformRotationZ(math.rad(45))
	self.WWCragPass:SetText(passSymbol)
	self.WWCragPass:SetMouseEnabled(true)
    self.WWCragPass:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1126)
        end
    end)
    self.WWCragPass:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(1126))) 
    end)
    self.WWCragPass:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)
	
	
	-- West Weald to Gold Coast
	self.WWGold = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.WWGold:SetAnchor(BOTTOMLEFT, ZO_WorldMapContainer, BOTTOMLEFT,math.floor(multiX*175),math.floor(multiY*-175), 0, 0) 
	self.WWGold:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.WWGold:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.WWGold:SetAlpha(alpha)
    self.WWGold:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.WWGold:SetText(QuickMapNav:ColorMapTextById(1006))
	self.WWGold:SetMouseEnabled(true)
    self.WWGold:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1006)
        end
    end)

	-- West Weald to Gold Coast (pass 1)
	self.WWGoldPassOne = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.WWGoldPassOne:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM, math.floor(multiX*-150),math.floor(multiY*-155), 0, 0) 
	self.WWGoldPassOne:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.WWGoldPassOne:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.WWGoldPassOne:SetAlpha(1)
    self.WWGoldPassOne:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.WWGoldPassOne:SetTransformRotationZ(math.rad(90))
	self.WWGoldPassOne:SetText(passSymbol)
	self.WWGoldPassOne:SetMouseEnabled(true)
    self.WWGoldPassOne:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1006)
        end
    end)
    self.WWGoldPassOne:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(1006))) 
    end)
    self.WWGoldPassOne:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)

	-- West Weald to Gold Coast (pass 2)
	self.WWGoldPassTwo = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.WWGoldPassTwo:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT, math.floor(multiX*90),math.floor(multiY*160), 0, 0) 
	self.WWGoldPassTwo:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.WWGoldPassTwo:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.WWGoldPassTwo:SetAlpha(1)
    self.WWGoldPassTwo:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.WWGoldPassTwo:SetTransformRotationZ(math.rad(90))
	self.WWGoldPassTwo:SetText(passSymbol)
	self.WWGoldPassTwo:SetMouseEnabled(true)
    self.WWGoldPassTwo:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1006)
        end
    end)
    self.WWGoldPassTwo:SetHandler("OnMouseEnter", function(self)
        ZO_Tooltips_ShowTextTooltip(self, TOP, GetString( TO )..zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, GetMapNameById(1006))) 
    end)
    self.WWGoldPassTwo:SetHandler("OnMouseExit", function(self) 
        ZO_Tooltips_HideTextTooltip()
    end)	
	
	
	-- West Weald to Malabal Tor
	self.WWMal = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.WWMal:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*1),math.floor(multiY*-30), 0, 0) 
	self.WWMal:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.WWMal:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.WWMal:SetAlpha(alpha)
    self.WWMal:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.WWMal:SetText(QuickMapNav:ColorMapTextById(22)) 
	self.WWMal:SetMouseEnabled(true)
    self.WWMal:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(22)
        end
    end)
	
	
	-- Solstice to Khenarthi's Roost
	self.solKhen = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.solKhen:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*20),math.floor(multiY*250), 0, 0) 
	self.solKhen:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.solKhen:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.solKhen:SetAlpha(alpha-0.13)
    self.solKhen:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.solKhen:SetTransformRotationZ(math.rad(90))
	self.solKhen:SetText(QuickMapNav:ColorMapTextById(258))
	self.solKhen:SetMouseEnabled(true)
    self.solKhen:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(258)
        end
    end)
	
	
	-- Solstice to Southern Elsweyr
	self.solSouth = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.solSouth:SetAnchor(TOP, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*100),math.floor(multiY*80), 0, 0) 
	self.solSouth:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.solSouth:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.solSouth:SetAlpha(alpha-0.13)
    self.solSouth:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.solSouth:SetTransformRotationZ(math.rad(45))
	self.solSouth:SetText(QuickMapNav:ColorMapTextById(1654)) 
	self.solSouth:SetMouseEnabled(true)
    self.solSouth:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1654)
        end
    end)
	
	-- Solstice to Murkmire
	self.solMurk = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.solMurk:SetAnchor(TOP, ZO_WorldMapContainer, TOPRIGHT, math.floor(multiX*-100),math.floor(multiY*10), 0, 0) 
	self.solMurk:SetFont(path .. "|" .. size+2 .. "|" ..  outline)
	self.solMurk:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
  self.solMurk:SetAlpha(alpha-0.13)
  self.solMurk:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.solMurk:SetText(QuickMapNav:ColorMapTextById(1484))
	self.solMurk:SetMouseEnabled(true)
  self.solMurk:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(1484)
        end
    end)
    
	-- Jerall Pass to Cyrodiil
	self.jerpCyr = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.jerpCyr:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*1),math.floor(multiY*-10), 0, 0) 
	self.jerpCyr:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.jerpCyr:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
  self.jerpCyr:SetAlpha(alpha)
  self.jerpCyr:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.jerpCyr:SetText(QuickMapNav:ColorMapTextById(16)) 
	self.jerpCyr:SetMouseEnabled(true)
  self.jerpCyr:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(16)
        end
  end)
  
	-- Jerall Pass to Arcwind point
	self.jerpArc = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.jerpArc:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT ,math.floor(multiX*-10),math.floor(multiY*1), 0, 0) 
	self.jerpArc:SetFont(path .. "|" .. size-5 .. "|" ..  outline)
	self.jerpArc:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
  self.jerpArc:SetAlpha(alpha-0.13)
  self.jerpArc:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.jerpArc:SetTransformRotationZ(math.rad(-90))
	self.jerpArc:SetText(QuickMapNav:ColorMapTextById(590))
	self.jerpArc:SetMouseEnabled(true)
  self.jerpArc:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
		       WORLD_MAP_MANAGER:SetMapById(590)
        end
    end)
    
  -- Jerall Pass to The Rift
	self.jerpRift = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.jerpRift:SetAnchor(TOPRIGHT, ZO_WorldMapContainer, TOPRIGHT, math.floor(multiX*-50),math.floor(multiY*60), 0, 0) 
	self.jerpRift:SetFont(path .. "|" .. size .. "|" ..  outline)
	self.jerpRift:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
  self.jerpRift:SetAlpha(alpha)
  self.jerpRift:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.jerpRift:SetText(QuickMapNav:ColorMapTextById(125)) 
	self.jerpRift:SetMouseEnabled(true)
  self.jerpRift:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
			  WORLD_MAP_MANAGER:SetMapById(125)
        end
  end)
	
	
	-- Abbreviated keep names
	
	-- Fort warden
	self.ward = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.ward:SetAnchor(TOPLEFT, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*200),math.floor(multiY*145), 0, 0) 
	self.ward:SetFont(pathTitle .. "|" .. size-5 .. "|" ..  outlineTitle)
	self.ward:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.ward:SetAlpha(1)
    self.ward:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.ward:SetText(string.format("|cFFFFFF%s|r", zo_strformat("<<1>>","Ward"))) 
	
	-- Fort Rayles
	self.ray = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.ray:SetAnchor(TOPLEFT, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*152),math.floor(multiY*270), 0, 0) 
	self.ray:SetFont(pathTitle .. "|" .. size-5 .. "|" ..  outlineTitle)
	self.ray:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.ray:SetAlpha(1)
    self.ray:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.ray:SetText(string.format("|cFFFFFF%s|r", zo_strformat("<<1>>","Ray"))) 	
	
	-- Fort Glademist
	self.glade = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.glade:SetAnchor(TOPLEFT, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*240),math.floor(multiY*228), 0, 0) 
	self.glade:SetFont(pathTitle .. "|" .. size-5 .. "|" ..  outlineTitle)
	self.glade:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.glade:SetAlpha(1)
    self.glade:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.glade:SetText(string.format("|cFFFFFF%s|r", zo_strformat("<<1>>","Glade"))) 	
	
	-- Fort Ash
	self.ash = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.ash:SetAnchor(CENTER, ZO_WorldMapContainer, CENTER,math.floor(multiX*-157),math.floor(multiY*-60), 0, 0) 
	self.ash:SetFont(pathTitle .. "|" .. size-5 .. "|" ..  outlineTitle)
	self.ash:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.ash:SetAlpha(1)
    self.ash:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.ash:SetText(string.format("|cFFFFFF%s|r", zo_strformat("<<1>>","Ash")))
	
	-- Castle Brindle
	self.bri = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.bri:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT,math.floor(multiX*200),math.floor(multiY*65), 0, 0) 
	self.bri:SetFont(pathTitle .. "|" .. size-5 .. "|" ..  outlineTitle)
	self.bri:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.bri:SetAlpha(1)
    self.bri:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.bri:SetText(string.format("|cFFFFFF%s|r", zo_strformat("<<1>>","Bri")))	
	
	-- Carmala Outpost
	self.car = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.car:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT,math.floor(multiX*197),math.floor(multiY*7), 0, 0) 
	self.car:SetFont(pathTitle .. "|" .. size-5 .. "|" ..  outlineTitle)
	self.car:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.car:SetAlpha(1)
    self.car:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.car:SetText(string.format("|cFFFFFF%s|r", zo_strformat("<<1>>","Car")))	

	-- Castle Roeback
	self.roe = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.roe:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT,math.floor(multiX*380),math.floor(multiY*65), 0, 0) 
	self.roe:SetFont(pathTitle .. "|" .. size-5 .. "|" ..  outlineTitle)
	self.roe:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.roe:SetAlpha(1)
    self.roe:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.roe:SetText(string.format("|cFFFFFF%s|r", zo_strformat("<<1>>","Roe")))	
	
	-- Vlastarus
	self.vla = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.vla:SetAnchor(LEFT, ZO_WorldMapContainer, LEFT,math.floor(multiX*277),math.floor(multiY*140), 0, 0) 
	self.vla:SetFont(pathTitle .. "|" .. size-5 .. "|" ..  outlineTitle)
	self.vla:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.vla:SetAlpha(1)
    self.vla:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.vla:SetText(string.format("|cFFFFFF%s|r", zo_strformat("<<1>>","Vla")))	
	
	-- Nikel Outpost
	self.nik = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.nik:SetAnchor(CENTER, ZO_WorldMapContainer, CENTER,math.floor(multiX*-130),math.floor(multiY*25), 0, 0) 
	self.nik:SetFont(pathTitle .. "|" .. size-5 .. "|" ..  outlineTitle)
	self.nik:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.nik:SetAlpha(1)
    self.nik:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.nik:SetText(string.format("|cFFFFFF%s|r", zo_strformat("<<1>>","Nik")))
	
	-- Fort Alsewell
	self.well = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.well:SetAnchor(TOPLEFT, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*370),math.floor(multiY*228), 0, 0) 
	self.well:SetFont(pathTitle .. "|" .. size-5 .. "|" ..  outlineTitle)
	self.well:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.well:SetAlpha(1)
    self.well:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.well:SetText(string.format("|cFFFFFF%s|r", zo_strformat("<<1>>","well"))) 	
	
	-- Bleaker's Outpost
	self.blea = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.blea:SetAnchor(TOPLEFT, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*450),math.floor(multiY*228), 0, 0) 
	self.blea:SetFont(pathTitle .. "|" .. size-5 .. "|" ..  outlineTitle)
	self.blea:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.blea:SetAlpha(1)
    self.blea:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.blea:SetText(string.format("|cFFFFFF%s|r", zo_strformat("<<1>>","Blea"))) 	
	
	-- Fort Dragonclaw
	self.drag = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.drag:SetAnchor(TOPLEFT, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*445),math.floor(multiY*90), 0, 0) 
	self.drag:SetFont(pathTitle .. "|" .. size-5 .. "|" ..  outlineTitle)
	self.drag:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.drag:SetAlpha(1)
    self.drag:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.drag:SetText(string.format("|cFFFFFF%s|r", zo_strformat("<<1>>","Drag")))
	
	-- Bruma
	self.bru = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.bru:SetAnchor(TOPLEFT, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*435),math.floor(multiY*140), 0, 0) 
	self.bru:SetFont(pathTitle .. "|" .. size-5 .. "|" ..  outlineTitle)
	self.bru:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.bru:SetAlpha(1)
    self.bru:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.bru:SetText(string.format("|cFFFFFF%s|r", zo_strformat("<<1>>","Bru")))	
	
	-- Chalman Keep
	self.chal = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.chal:SetAnchor(TOPLEFT, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*525),math.floor(multiY*232), 0, 0) 
	self.chal:SetFont(pathTitle .. "|" .. size-5 .. "|" ..  outlineTitle)
	self.chal:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.chal:SetAlpha(1)
    self.chal:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.chal:SetText(string.format("|cFFFFFF%s|r", zo_strformat("<<1>>","Chal"))) 	
	
	-- winter's peak outpost
	self.win = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.win:SetAnchor(TOPLEFT, ZO_WorldMapContainer, TOPLEFT,math.floor(multiX*527),math.floor(multiY*142), 0, 0) 
	self.win:SetFont(pathTitle .. "|" .. size-5 .. "|" ..  outlineTitle)
	self.win:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.win:SetAlpha(1)
    self.win:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.win:SetText(string.format("|cFFFFFF%s|r", zo_strformat("<<1>>","Win")))	
	
	-- Kingscrest Keep
	self.kings = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.kings:SetAnchor(TOPRIGHT, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-235),math.floor(multiY*150), 0, 0) 
	self.kings:SetFont(pathTitle .. "|" .. size-5 .. "|" ..  outlineTitle)
	self.kings:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.kings:SetAlpha(1)
    self.kings:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.kings:SetText(string.format("|cFFFFFF%s|r", zo_strformat("<<1>>","Kings")))	
	
	-- Arrius Keep
	self.arr = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.arr:SetAnchor(TOPRIGHT, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-268),math.floor(multiY*270), 0, 0) 
	self.arr:SetFont(pathTitle .. "|" .. size-5 .. "|" ..  outlineTitle)
	self.arr:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.arr:SetAlpha(1)
    self.arr:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.arr:SetText(string.format("|cFFFFFF%s|r", zo_strformat("<<1>>","Arr")))	
	
	-- Farragut Keep
	self.farr = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.farr:SetAnchor(TOPRIGHT, ZO_WorldMapContainer, TOPRIGHT,math.floor(multiX*-138),math.floor(multiY*275), 0, 0) 
	self.farr:SetFont(pathTitle .. "|" .. size-5 .. "|" ..  outlineTitle)
	self.farr:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.farr:SetAlpha(1)
    self.farr:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.farr:SetText(string.format("|cFFFFFF%s|r", zo_strformat("<<1>>","Farr")))	
	
	-- Blue Road Keep
	self.brk = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.brk:SetAnchor(CENTER, ZO_WorldMapContainer, CENTER,math.floor(multiX*150),math.floor(multiY*-60), 0, 0) 
	self.brk:SetFont(pathTitle .. "|" .. size-5 .. "|" ..  outlineTitle)
	self.brk:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.brk:SetAlpha(1)
    self.brk:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.brk:SetText(string.format("|cFFFFFF%s|r", zo_strformat("<<1>>","BRK")))	
	
	-- harlun's outpost
	self.harl = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.harl:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*-178),math.floor(multiY*-23), 0, 0) 
	self.harl:SetFont(pathTitle .. "|" .. size-5 .. "|" ..  outlineTitle)
	self.harl:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.harl:SetAlpha(1)
    self.harl:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.harl:SetText(string.format("|cFFFFFF%s|r", zo_strformat("<<1>>","Harl")))	
	
	-- Castle Alessia
	self.sia = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.sia:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*-393),math.floor(multiY*59), 0, 0) 
	self.sia:SetFont(pathTitle .. "|" .. size-5 .. "|" ..  outlineTitle)
	self.sia:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.sia:SetAlpha(1)
    self.sia:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.sia:SetText(string.format("|cFFFFFF%s|r", zo_strformat("<<1>>","sia")))	
	
	-- Drakelowe Keep
	self.dlk = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.dlk:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*-198),math.floor(multiY*70), 0, 0) 
	self.dlk:SetFont(pathTitle .. "|" .. size-5 .. "|" ..  outlineTitle)
	self.dlk:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.dlk:SetAlpha(1)
    self.dlk:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.dlk:SetText(string.format("|cFFFFFF%s|r", zo_strformat("<<1>>","DLK")))
	
	-- Cropsford
	self.crop = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.crop:SetAnchor(RIGHT, ZO_WorldMapContainer, RIGHT,math.floor(multiX*-275),math.floor(multiY*113), 0, 0) 
	self.crop:SetFont(pathTitle .. "|" .. size-5 .. "|" ..  outlineTitle)
	self.crop:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.crop:SetAlpha(1)
    self.crop:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.crop:SetText(string.format("|cFFFFFF%s|r", zo_strformat("<<1>>","Crop")))

	-- Castle Faregyl
	self.fg = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.fg:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*-7),math.floor(multiY*-250), 0, 0) 
	self.fg:SetFont(pathTitle .. "|" .. size-5 .. "|" ..  outlineTitle)
	self.fg:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.fg:SetAlpha(1)
    self.fg:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.fg:SetText(string.format("|cFFFFFF%s|r", zo_strformat("<<1>>","FG")))

	-- Castle Black Boot
	self.bb = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.bb:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*-85),math.floor(multiY*-175), 0, 0) 
	self.bb:SetFont(pathTitle .. "|" .. size-5 .. "|" ..  outlineTitle)
	self.bb:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.bb:SetAlpha(1)
    self.bb:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.bb:SetText(string.format("|cFFFFFF%s|r", zo_strformat("<<1>>","BB")))

	-- Castle Bloodmayne
	self.bm = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.bm:SetAnchor(BOTTOM, ZO_WorldMapContainer, BOTTOM,math.floor(multiX*70),math.floor(multiY*-175), 0, 0) 
	self.bm:SetFont(pathTitle .. "|" .. size-5 .. "|" ..  outlineTitle)
	self.bm:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.bm:SetAlpha(1)
    self.bm:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.bm:SetText(string.format("|cFFFFFF%s|r", zo_strformat("<<1>>","BM")))

	-- Sejanus outpost
	self.sej = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.sej:SetAnchor(CENTER, ZO_WorldMapContainer, CENTER,math.floor(multiX*135),math.floor(multiY*10), 0, 0) 
	self.sej:SetFont(pathTitle .. "|" .. size-5 .. "|" ..  outlineTitle)
	self.sej:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.sej:SetAlpha(1)
    self.sej:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.sej:SetText(string.format("|cFFFFFF%s|r", zo_strformat("<<1>>","Sej")))

	
	
	


	-- CENTERED MAP TITLE
	self.mapTitle = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.mapTitle:SetAnchor(BOTTOM, ZO_WorldMapScroll, TOP,math.floor(multiX*1), math.floor(multiY*-7), 0, 0) 
	self.mapTitle:SetFont(pathTitle .. "|" .. sizeTitle .. "|" ..  outlineTitle)
	self.mapTitle:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.mapTitle:SetAlpha(alphaTitle)
    self.mapTitle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.mapTitle:SetText(QuickMapNav:colorMapTitle()) 
	
	-- TIME
	self.time = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
	self.time:SetAnchor(BOTTOM, ZO_WorldMapScroll, TOPLEFT,math.floor(multiX*40), math.floor(multiY*-7), 0, 0) 
	self.time:SetFont(pathTitle .. "|" .. sizeTime .. "|" ..  outlineTitle)
	self.time:SetColor(ZO_CONTRAST_TEXT:UnpackRGBA())
    self.time:SetAlpha(alphaTitle)
    self.time:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	self.time:SetText(zo_strformat("|cffffff<<1>>|r",QMN.Time))
    QMN.shelf = self	

	-- Ensure every zone-link label starts hidden (they inherit the parent
	-- control's hidden state at creation, so without this they all pop
	-- visible the moment the world map fragment is shown, before the
	-- first UpdateMapID call has a chance to hide the irrelevant ones)
	local allLinkControls = {
		self.alikrGle, self.alikrSto, self.alikrBan, self.alikrBanPass, self.alikrBet, self.alikrBal, self.aurSum, self.aurStro,
		self.aurStirk, self.aurHew, self.aurGol, self.aurMal, self.aurGre, self.aurArt, self.aurHigh, self.aurEye,
		self.artSum, self.artAur, self.balSto, self.balStoPass, self.balVvar, self.balDesh, self.balTel, self.balTelPass,
		self.banCrag, self.banCragPass, self.banVal, self.banRea, self.banWroth, self.banWrothPass, self.banSto, self.banStoPass,
		self.banAlik, self.banAliPass, self.banEarth, self.betGle, self.betAlik, self.betHigh, self.bleaVvar, self.bleaEast,
		self.coldDesh, self.cragCyr, self.cragWW, self.cragWWPass, self.cragRea, self.cragBan, self.cragBanPass, self.cragVal,
		self.cyrRift, self.cyrJer, self.cyrArc, self.cyrJerp, self.cyrFort, self.cyrSto, self.cyrCrag, self.cyrReap, self.cyrNorth,
		self.cyrWW, self.deshSto, self.deshStoPass, self.deshSha, self.deshShaPass, self.deshClock, self.deshClockPass, self.deshCold,
		self.deshBal, self.deshTel, self.deshTelPass, self.eastBlea, self.eastFul, self.eastVvar, self.eastRift, self.eastRiftPass,
		self.eastMzark, self.eastMzarkLift, self.gleRiv, self.gleSto, self.gleStoPass, self.gleAlik, self.gleBeth, self.gleBal,
		self.goldHew, self.goldAur, self.goldMal, self.goldWW, self.goldWWPassOne, self.goldWWPassTwo, self.goldStirk, self.grahKhen,
		self.grahGreen, self.grahGreenPass, self.grahMal, self.grahMalPass, self.grahRea, self.grahReaPass, self.grahEls, self.grahElsPass,
		self.grahtSouth, self.graVah, self.greenAur, self.greenMal, self.greenMalPass, self.greenGrath, self.greenGrathPass, self.greenFar,
		self.greenStirk, self.greenHew, self.hewStros, self.hewSum, self.hewAur, self.hewGold, self.hewMal, self.hewStirk,
		self.hewGreen, self.khenSouth, self.khenGraht, self.khenSol, self.malGold, self.malReap, self.malWW, self.malReapPass,
		self.malGrath, self.malGrathPass, self.malGreen, self.malGreenPass, self.malAur, self.malHew, self.malStirk, self.murkNorg,
		self.murkBlack, self.murkSol, self.norgMurk, self.northGrah, self.northGrahPass, self.northReap, self.northReapPass, self.northCyr,
		self.northSouth, self.northBlack, self.northBlackPass, self.northVah, self.reapGrah, self.reapWW, self.reapWWPass, self.reapGrahPass,
		self.reapMal, self.reapMalPass, self.reapCyr, self.reapNorth, self.reapNorthPass, self.rivGray, self.rivGle, self.rivSto,
		self.rivStoPass, self.rivWroth, self.shaDesh, self.shaDeshPass, self.shaBlack, self.shaBlackPass, self.southKhen, self.southGraht,
		self.southBlack, self.southNorth, self.southJod, self.southDrag, self.southHalls, self.southSol, self.stoRift, self.stoRiftPass,
		self.stoCrag, self.stoDesh, self.stoDeshPass, self.stoBal, self.stoBalPass, self.stoVvar, self.storGle, self.storGlePass,
		self.storRiv, self.storRivPass, self.storWroth, self.storWrothPass, self.storBan, self.storBanPass, self.storAlik, self.storBal,
		self.strosHew, self.strosGold, self.strosMal, self.strosGreen, self.strosAur, self.strosSum, self.strosHigh, self.strosEye,
		self.strosStirk, self.sumAur, self.sumStros, self.sumArt, self.sumGre, self.sumHigh, self.sumEye, self.sumWast,
		self.sumSap, self.reachWest, self.reachWestPass, self.reachCrag, self.reachBang, self.reaWroth, self.reaEarth, self.riftEast,
		self.riftEastPass, self.riftStone, self.riftStonePass, self.riftCyr, self.riftGer, self.riftArc, self.riftJerp, self.riftVvar, self.vvarBleak,
		self.vvarEast, self.vvarStone, self.vvarFir, self.vvarBal, self.vvarRift, self.vvarTel, self.skyReach, self.skyReachPass,
		self.westWroth, self.westGrey, self.westRed, self.wrothBang, self.wrothBangPass, self.wrothStorm, self.wrothStormPass, self.wrothRiv,
		self.wrothGray, self.wrothReach, self.wrothWest, self.grayRiven, self.grayWroth, self.eyeSum, self.eyeAur, self.eyeStros,
		self.eyeStirk, self.eyeHigh, self.eyeWay, self.eyeRift, self.eyeEast, self.eyeSha, self.eyeDesh, self.eyeSto,
		self.highSum, self.highGal, self.highAur, self.highStros, self.highStirk, self.highEye, self.highBeth, self.portEye,
		self.arkthGrey, self.greyArkth, self.greyWest, self.greyMzark, self.greyKagn, self.mzarkGrey, self.mzarkEast, self.mzarkEastLift,
		self.mournClock, self.mournCold, self.clockDesh, self.stirkEye, self.stirkAur, self.stirkStros, self.stirkHew, self.stirkHigh,
		self.stirkMal, self.stirkGre, self.stirkGol, self.blackSha, self.blackShaPass, self.blackMurk, self.blackBor, self.blackSouth,
		self.blackNorth, self.blackNorthPass, self.balGle, self.balStorm, self.balAlik, self.jerRift, self.jerCyr, self.valCrag,
		self.valBang, self.borBlack, self.jodNorth, self.jodeSouth, self.jodGrath, self.farSham, self.farGreen, self.shamFar,
		self.earthBan, self.earthRea, self.earthWay, self.fortCyr, self.galHigh, self.telBal, self.telDesh, self.telVvar,
		self.telDeshPass, self.telBalPass, self.arcCyr, self.arcRift, self.arcJerp, self.icIs, self.isIc, self.vahlGrah, self.vahlNorth,
		self.WWReap, self.WWReapPass, self.WWCyr, self.WWCrag, self.WWCragPass, self.WWGold, self.WWGoldPassOne, self.WWGoldPassTwo,
		self.WWMal, self.solKhen, self.solSouth, self.solMurk, self.jerpCyr, self.jerpArc, self.jerpRift, self.ward, self.ray, self.glade, self.ash,
		self.bri, self.car, self.roe, self.vla, self.nik, self.well, self.blea, self.drag,
		self.bru, self.chal, self.win, self.kings, self.arr, self.farr, self.brk, self.harl,
		self.sia, self.dlk, self.crop, self.fg, self.bb, self.bm, self.sej, self.mapTitle,
		self.time
	}
	for i = 1, #allLinkControls do
		allLinkControls[i]:SetHidden(true)
	end


end


function QuickMapNav:AttachTo(attachedTo)
	if attachedTo and type(attachedTo) == "userdata" then
		self.attachedTo = attachedTo
		self.control:ClearAnchors()
		self.control:SetAnchor(TOPLEFT,attachedTo, BOTTOMLEFT,4, self.yDelta)
		self.control:SetAnchor(TOPRIGHT,attachedTo, BOTTOMRIGHT,-4, self.yDelta)
	end
end

function QuickMapNav:ShowAndSetAlpha(control)

	    QMN.zoomLevel = QMN.zoomLevel or 0
		local multiAlpha = QMN.zoomLevel*10
		if multiAlpha > 1 then multiAlpha = 1 end
		local alpha = math.abs(1 - multiAlpha)
		
        control:SetHidden(false)
		control:SetAlpha(alpha)

		-- remember what we showed so UpdateMapID only has to hide
		-- these specific controls next time, instead of every control
		QMN.activeControls[#QMN.activeControls + 1] = control
end


-------Update Map ID
function QuickMapNav:UpdateMapID()
	local m = GetCurrentMapId()

	-- the title text and the tile desaturation both only depend on which
	-- map we're on, not on zoom level or mouseover - but this whole function
	-- runs on every zoom tick and every mouseover change, so recomputing them
	-- every time (string formatting + control-name lookups) is wasted work.
	-- Only redo that work when the map id actually changed.
	local mapChanged = (m ~= QMN.lastMapId)
	QMN.lastMapId = m

	if mapChanged then
		self.mapTitle:SetText(QuickMapNav:colorMapTitle())
	end
	QuickMapNav:UpdateTime()
	
	
-- Hide everything we displayed before
-- (only iterate the controls we actually showed last time, instead of
--  unconditionally hiding every single zone-link control on every update -
--  this runs on every zoom tick and every mouseover change, so it matters)
	for i = 1, #QMN.activeControls do
		QMN.activeControls[i]:SetHidden(true)
	end
	QMN.activeControls = {}
	
	
	if not QMN.vars.topLeftZoneName then
       ZO_WorldMapCorner:SetHidden(true)
	end

    self.mapTitle:SetHidden(true)
	self.time:SetHidden(true)

 	if not QMN.vars.topLeftZoneName then
       self.mapTitle:SetHidden(false)
	   self.time:SetHidden(false)
	end
	
    --ZO_WorldMapMapBlackOut:SetHidden(true) -- black map background
	 ZO_WorldMapContainerBackground:SetHidden(true) -- beige map background
	--ZO_WorldMapScroll:SetHidden(true)
	 --ZO_WorldMapContainer:SetHidden(true)
	 
	 
     -- map saturation
	 -- the desaturation setting itself can't change without a UI reload, and the
	 -- tile controls for a given map don't change either, so only redo this
	 -- (relatively expensive, string-lookup-based) loop when the map id changes,
	 -- rather than on every zoom tick and every mouseover update
	 if mapChanged then
	     local numHorizontalTiles, numVerticalTiles = GetMapNumTiles()
	     local numWorldMapContainers = numHorizontalTiles * numVerticalTiles 
	     local templateName = "ZO_WorldMapContainer"
	     local WM = WINDOW_MANAGER
	     for i=1, numWorldMapContainers , 1 do
	       local worldMapContainer = WM:GetControlByName(templateName , i) 
		   if worldMapContainer then
	         worldMapContainer:SetDesaturation(QMN.vars.desaturation)
			 --worldMapContainer:SetAlpha(0.25) -- test THIS
			  --worldMapContainer:SetDesaturation(1) -- test THIS
	       end
	     end
	 end

     --if not IsChapterOwned(5843) then  ZO_WorldMapScroll:SetHidden(true) end

    -- Map opacity
  	ZO_WorldMapScroll:SetAlpha(QMN.vars.lessFlashyMap)

 -- Do not display when zoom isn't maxed and when top center white description is displayed  
    if QMN.zoomLevel < 1 then 
    --CHAT_SYSTEM:AddMessage("DrawTier: "..self.alikrGle:GetDrawTier().." DrawLayer: "..self.alikrGle:GetDrawLayer().." DrawLevel: "..self.alikrGle:GetDrawLevel().." "..GetTimeStamp() )
	
	    local mouseoverName = QMN.mouseoverName
	
        -- display links on each maps
        if m == 30 then -- Alik'r desert map  
        QuickMapNav:ShowAndSetAlpha(self.alikrGle)
        QuickMapNav:ShowAndSetAlpha(self.alikrSto)
        QuickMapNav:ShowAndSetAlpha(self.alikrBan)
		QuickMapNav:ShowAndSetAlpha(self.alikrBanPass)
        QuickMapNav:ShowAndSetAlpha(self.alikrBet)
        QuickMapNav:ShowAndSetAlpha(self.alikrBal)

        
        elseif  m == 143 then -- Auridon map  
        QuickMapNav:ShowAndSetAlpha(self.aurSum)
        QuickMapNav:ShowAndSetAlpha(self.aurStro)
        if mouseoverName == "" then QuickMapNav:ShowAndSetAlpha(self.aurHew) end
        QuickMapNav:ShowAndSetAlpha(self.aurGol)
        QuickMapNav:ShowAndSetAlpha(self.aurMal)
        QuickMapNav:ShowAndSetAlpha(self.aurGre)
        QuickMapNav:ShowAndSetAlpha(self.aurArt)
        --self.aurEye:SetHidden(false)
        QuickMapNav:ShowAndSetAlpha(self.aurStirk)
		QuickMapNav:ShowAndSetAlpha(self.aurHigh)
        
        elseif  m == 1429 then -- Artaeum map 
        QuickMapNav:ShowAndSetAlpha(self.artSum)
        QuickMapNav:ShowAndSetAlpha(self.artAur)
        
        elseif  m == 75 then -- Bal Foyen  
        QuickMapNav:ShowAndSetAlpha(self.balSto)
		QuickMapNav:ShowAndSetAlpha(self.balStoPass)
        if mouseoverName == "" then QuickMapNav:ShowAndSetAlpha(self.balVvar) end
        QuickMapNav:ShowAndSetAlpha(self.balDesh)
		QuickMapNav:ShowAndSetAlpha(self.balTel)
		QuickMapNav:ShowAndSetAlpha(self.balTelPass)
        
        elseif  m == 20 then -- Bangkorai  
        QuickMapNav:ShowAndSetAlpha(self.banCrag)
		QuickMapNav:ShowAndSetAlpha(self.banCragPass)
        QuickMapNav:ShowAndSetAlpha(self.banRea)
		QuickMapNav:ShowAndSetAlpha(self.banWrothPass)
        if mouseoverName == "" then QuickMapNav:ShowAndSetAlpha(self.banWroth) end
        QuickMapNav:ShowAndSetAlpha(self.banSto)
		QuickMapNav:ShowAndSetAlpha(self.banStoPass)
        QuickMapNav:ShowAndSetAlpha(self.banAlik)
		QuickMapNav:ShowAndSetAlpha(self.banAliPass)
		QuickMapNav:ShowAndSetAlpha(self.banVal)
		if mouseoverName == "" then QuickMapNav:ShowAndSetAlpha(self.banEarth) end
        
        elseif  m == 227 then -- Betnikh  
        QuickMapNav:ShowAndSetAlpha(self.betGle)
        QuickMapNav:ShowAndSetAlpha(self.betAlik)
		QuickMapNav:ShowAndSetAlpha(self.betHigh)
        
        elseif  m == 74 then -- Bleakrock Isle  
        QuickMapNav:ShowAndSetAlpha(self.bleaVvar)
        QuickMapNav:ShowAndSetAlpha(self.bleaEast)
        
        elseif  m == 255 then -- Coldharbour
        QuickMapNav:ShowAndSetAlpha(self.coldDesh)
        
        elseif  m == 1126 then -- Craglorn  
        QuickMapNav:ShowAndSetAlpha(self.cragCyr)
		QuickMapNav:ShowAndSetAlpha(self.cragWW)
		QuickMapNav:ShowAndSetAlpha(self.cragWWPass)
        QuickMapNav:ShowAndSetAlpha(self.cragRea)
        QuickMapNav:ShowAndSetAlpha(self.cragBan)
		QuickMapNav:ShowAndSetAlpha(self.cragBanPass)
		QuickMapNav:ShowAndSetAlpha(self.cragVal)
        
        elseif  m == 16 then -- Cyrodiil  
        if mouseoverName == "" then QuickMapNav:ShowAndSetAlpha(self.cyrRift) end
        QuickMapNav:ShowAndSetAlpha(self.cyrSto)
        QuickMapNav:ShowAndSetAlpha(self.cyrCrag)
        QuickMapNav:ShowAndSetAlpha(self.cyrReap)
        QuickMapNav:ShowAndSetAlpha(self.cyrNorth)
		QuickMapNav:ShowAndSetAlpha(self.cyrWW)
		QuickMapNav:ShowAndSetAlpha(self.cyrJer)
		if mouseoverName == "" then 
       QuickMapNav:ShowAndSetAlpha(self.cyrArc)
       QuickMapNav:ShowAndSetAlpha(self.cyrJerp)
    end
		QuickMapNav:ShowAndSetAlpha(self.cyrFort)
		
			if IsInCyrodiil() and QMN.vars.abbreviatedKeeps then
				QuickMapNav:ShowAndSetAlpha(self.ward)
				QuickMapNav:ShowAndSetAlpha(self.ray)
				QuickMapNav:ShowAndSetAlpha(self.glade)
				QuickMapNav:ShowAndSetAlpha(self.ash)
				QuickMapNav:ShowAndSetAlpha(self.bri)
				QuickMapNav:ShowAndSetAlpha(self.roe)
				QuickMapNav:ShowAndSetAlpha(self.car)
				QuickMapNav:ShowAndSetAlpha(self.vla)
				QuickMapNav:ShowAndSetAlpha(self.nik)
				QuickMapNav:ShowAndSetAlpha(self.well)
				QuickMapNav:ShowAndSetAlpha(self.blea)
				QuickMapNav:ShowAndSetAlpha(self.bru)
				QuickMapNav:ShowAndSetAlpha(self.chal)
				QuickMapNav:ShowAndSetAlpha(self.win)
				QuickMapNav:ShowAndSetAlpha(self.kings)
				QuickMapNav:ShowAndSetAlpha(self.arr)
				QuickMapNav:ShowAndSetAlpha(self.farr)
				QuickMapNav:ShowAndSetAlpha(self.brk)
				QuickMapNav:ShowAndSetAlpha(self.harl)
				QuickMapNav:ShowAndSetAlpha(self.sia)
				QuickMapNav:ShowAndSetAlpha(self.dlk)
				QuickMapNav:ShowAndSetAlpha(self.crop)
				QuickMapNav:ShowAndSetAlpha(self.fg)
				QuickMapNav:ShowAndSetAlpha(self.bb)
				QuickMapNav:ShowAndSetAlpha(self.bm)
				QuickMapNav:ShowAndSetAlpha(self.sej)
				QuickMapNav:ShowAndSetAlpha(self.drag)
			end
			
        elseif  m == 13 then -- Deshaan  
        QuickMapNav:ShowAndSetAlpha(self.deshSto)
		QuickMapNav:ShowAndSetAlpha(self.deshStoPass)
        QuickMapNav:ShowAndSetAlpha(self.deshSha)
		QuickMapNav:ShowAndSetAlpha(self.deshShaPass)
        QuickMapNav:ShowAndSetAlpha(self.deshClock)
		QuickMapNav:ShowAndSetAlpha(self.deshClockPass)
        QuickMapNav:ShowAndSetAlpha(self.mournCold)
        QuickMapNav:ShowAndSetAlpha(self.deshBal)
		QuickMapNav:ShowAndSetAlpha(self.deshTel)
		QuickMapNav:ShowAndSetAlpha(self.deshTelPass)
		QuickMapNav:ShowAndSetAlpha(self.portEye)
        
        elseif  m == 61 then -- Eastmarch  
        QuickMapNav:ShowAndSetAlpha(self.eastBlea)
        QuickMapNav:ShowAndSetAlpha(self.eastVvar)
        QuickMapNav:ShowAndSetAlpha(self.eastRift)
		QuickMapNav:ShowAndSetAlpha(self.eastRiftPass)
		QuickMapNav:ShowAndSetAlpha(self.eastFul)
		QuickMapNav:ShowAndSetAlpha(self.eastMzark)
		QuickMapNav:ShowAndSetAlpha(self.eastMzarkLift)
		QuickMapNav:ShowAndSetAlpha(self.portEye)
        
        elseif  m == 1 then -- Glenumbra  
        QuickMapNav:ShowAndSetAlpha(self.gleRiv)
        QuickMapNav:ShowAndSetAlpha(self.gleSto)
		QuickMapNav:ShowAndSetAlpha(self.gleStoPass)
        QuickMapNav:ShowAndSetAlpha(self.gleAlik)
        QuickMapNav:ShowAndSetAlpha(self.gleBeth)
        QuickMapNav:ShowAndSetAlpha(self.gleBal)
        
        elseif  m == 1006 then -- Gold Coast
        QuickMapNav:ShowAndSetAlpha(self.goldHew)
        QuickMapNav:ShowAndSetAlpha(self.goldAur)
        QuickMapNav:ShowAndSetAlpha(self.goldMal)
		QuickMapNav:ShowAndSetAlpha(self.goldStirk)
		QuickMapNav:ShowAndSetAlpha(self.goldWW)
		QuickMapNav:ShowAndSetAlpha(self.goldWWPassOne)
		QuickMapNav:ShowAndSetAlpha(self.goldWWPassTwo)
        
        elseif  m == 9 then -- Grahtwood  
        QuickMapNav:ShowAndSetAlpha(self.grahKhen)
        QuickMapNav:ShowAndSetAlpha(self.grahGreen)
		QuickMapNav:ShowAndSetAlpha(self.grahGreenPass)
        QuickMapNav:ShowAndSetAlpha(self.grahMal)
		QuickMapNav:ShowAndSetAlpha(self.grahMalPass)
        if mouseoverName == "" then QuickMapNav:ShowAndSetAlpha(self.grahRea) end
		QuickMapNav:ShowAndSetAlpha(self.grahReaPass)
        QuickMapNav:ShowAndSetAlpha(self.grahEls)
		QuickMapNav:ShowAndSetAlpha(self.grahElsPass)
        QuickMapNav:ShowAndSetAlpha(self.grahtSouth)
		QuickMapNav:ShowAndSetAlpha(self.graVah)
        
        elseif  m == 300 then -- Greenshade  
        QuickMapNav:ShowAndSetAlpha(self.greenAur)
        QuickMapNav:ShowAndSetAlpha(self.greenMal)
		QuickMapNav:ShowAndSetAlpha(self.greenMalPass)
        QuickMapNav:ShowAndSetAlpha(self.greenGrath)
		QuickMapNav:ShowAndSetAlpha(self.greenGrathPass)
        QuickMapNav:ShowAndSetAlpha(self.greenHew)
		QuickMapNav:ShowAndSetAlpha(self.greenStirk)
		QuickMapNav:ShowAndSetAlpha(self.greenFar)
        
        elseif  m == 994 then -- Hew's Bane  
        QuickMapNav:ShowAndSetAlpha(self.hewStros)
        QuickMapNav:ShowAndSetAlpha(self.hewSum)
        QuickMapNav:ShowAndSetAlpha(self.hewAur)
        QuickMapNav:ShowAndSetAlpha(self.hewGold)
        QuickMapNav:ShowAndSetAlpha(self.hewMal)
        QuickMapNav:ShowAndSetAlpha(self.hewGreen)
		QuickMapNav:ShowAndSetAlpha(self.hewStirk)
        
        elseif  m == 258 then -- Khenarthi's Roost  
        QuickMapNav:ShowAndSetAlpha(self.khenSouth)
        QuickMapNav:ShowAndSetAlpha(self.khenGraht)
		QuickMapNav:ShowAndSetAlpha(self.khenSol)
        
        elseif  m == 22 then -- Malabal Tor  
        QuickMapNav:ShowAndSetAlpha(self.malGold)
        QuickMapNav:ShowAndSetAlpha(self.malReap)
		QuickMapNav:ShowAndSetAlpha(self.malWW)
		QuickMapNav:ShowAndSetAlpha(self.malReapPass)
        QuickMapNav:ShowAndSetAlpha(self.malGrath)
		QuickMapNav:ShowAndSetAlpha(self.malGrathPass)
        QuickMapNav:ShowAndSetAlpha(self.malGreen)
		QuickMapNav:ShowAndSetAlpha(self.malGreenPass)
        QuickMapNav:ShowAndSetAlpha(self.malAur)
        QuickMapNav:ShowAndSetAlpha(self.malHew)
		QuickMapNav:ShowAndSetAlpha(self.malStirk)
        
        elseif  m == 1484 then -- Murkmire  
        QuickMapNav:ShowAndSetAlpha(self.murkNorg)
        QuickMapNav:ShowAndSetAlpha(self.murkBlack)
		QuickMapNav:ShowAndSetAlpha(self.murkSol)

        elseif  m == 1552 then -- Norg-Tzel  
        QuickMapNav:ShowAndSetAlpha(self.norgMurk)

        elseif  m == 1555 then -- Northern Elsweyr 
        QuickMapNav:ShowAndSetAlpha(self.northGrah)
		QuickMapNav:ShowAndSetAlpha(self.northGrahPass)
        QuickMapNav:ShowAndSetAlpha(self.northReap)
		QuickMapNav:ShowAndSetAlpha(self.northReapPass)
        if mouseoverName == "" then QuickMapNav:ShowAndSetAlpha(self.northCyr) end
        QuickMapNav:ShowAndSetAlpha(self.northBlack)
		QuickMapNav:ShowAndSetAlpha(self.northBlackPass)
        QuickMapNav:ShowAndSetAlpha(self.northSouth)
		QuickMapNav:ShowAndSetAlpha(self.northVah)

        elseif  m == 256 then -- Reaper's March  
        QuickMapNav:ShowAndSetAlpha(self.reapGrah)
		QuickMapNav:ShowAndSetAlpha(self.reapWW)
		if mouseoverName == "" then QuickMapNav:ShowAndSetAlpha(self.reapWWPass) end
		QuickMapNav:ShowAndSetAlpha(self.reapGrahPass)
        QuickMapNav:ShowAndSetAlpha(self.reapMal)
		QuickMapNav:ShowAndSetAlpha(self.reapMalPass)
        QuickMapNav:ShowAndSetAlpha(self.reapCyr)
        QuickMapNav:ShowAndSetAlpha(self.reapNorth)
		QuickMapNav:ShowAndSetAlpha(self.reapNorthPass)
        
        elseif  m == 10 then -- Rivenspire     
        QuickMapNav:ShowAndSetAlpha(self.rivGray)
        QuickMapNav:ShowAndSetAlpha(self.rivGle)
        QuickMapNav:ShowAndSetAlpha(self.rivSto)
		QuickMapNav:ShowAndSetAlpha(self.rivStoPass)
        QuickMapNav:ShowAndSetAlpha(self.rivWroth)
        
        elseif  m == 26 then -- Shadowfen         
        if mouseoverName == "" then QuickMapNav:ShowAndSetAlpha(self.shaDesh) end
		QuickMapNav:ShowAndSetAlpha(self.shaDeshPass)
        QuickMapNav:ShowAndSetAlpha(self.shaBlack)
		QuickMapNav:ShowAndSetAlpha(self.shaBlackPass)
		QuickMapNav:ShowAndSetAlpha(self.portEye)
        
        elseif  m == 1654 then -- Southern Elsweyr  
        QuickMapNav:ShowAndSetAlpha(self.southKhen)
        QuickMapNav:ShowAndSetAlpha(self.southGraht)
        if mouseoverName == "" then 
        QuickMapNav:ShowAndSetAlpha(self.southBlack) 
        QuickMapNav:ShowAndSetAlpha(self.southNorth)
        end
		QuickMapNav:ShowAndSetAlpha(self.southJod)
        QuickMapNav:ShowAndSetAlpha(self.southDrag)	
        QuickMapNav:ShowAndSetAlpha(self.southHalls)			
        QuickMapNav:ShowAndSetAlpha(self.southSol) 
		
        elseif  m == 7 then -- Stonefalls        
        QuickMapNav:ShowAndSetAlpha(self.stoRift)
		QuickMapNav:ShowAndSetAlpha(self.stoRiftPass)
        QuickMapNav:ShowAndSetAlpha(self.stoCrag)
        QuickMapNav:ShowAndSetAlpha(self.stoDesh)
		QuickMapNav:ShowAndSetAlpha(self.stoDeshPass)
        QuickMapNav:ShowAndSetAlpha(self.stoBal)
		QuickMapNav:ShowAndSetAlpha(self.stoBalPass)
        QuickMapNav:ShowAndSetAlpha(self.stoVvar)
		QuickMapNav:ShowAndSetAlpha(self.portEye)
        
        elseif  m == 12 then -- Stormhaven       
        QuickMapNav:ShowAndSetAlpha(self.storGle)
		QuickMapNav:ShowAndSetAlpha(self.storGlePass)
        QuickMapNav:ShowAndSetAlpha(self.storRiv)
		QuickMapNav:ShowAndSetAlpha(self.storRivPass)
        QuickMapNav:ShowAndSetAlpha(self.storWroth)
		QuickMapNav:ShowAndSetAlpha(self.storWrothPass)
        QuickMapNav:ShowAndSetAlpha(self.storBan)
		QuickMapNav:ShowAndSetAlpha(self.storBanPass)
        QuickMapNav:ShowAndSetAlpha(self.storAlik)
        QuickMapNav:ShowAndSetAlpha(self.storBal)
        
        elseif  m == 201 then -- Stros M'Kai     
        QuickMapNav:ShowAndSetAlpha(self.strosHew)
        QuickMapNav:ShowAndSetAlpha(self.strosGold)
        QuickMapNav:ShowAndSetAlpha(self.strosMal)
        QuickMapNav:ShowAndSetAlpha(self.strosGreen)
        QuickMapNav:ShowAndSetAlpha(self.strosAur)
        QuickMapNav:ShowAndSetAlpha(self.strosSum)
        --QuickMapNav:ShowAndSetAlpha(self.strosEye)
        QuickMapNav:ShowAndSetAlpha(self.strosStirk)
		QuickMapNav:ShowAndSetAlpha(self.strosHigh)
        
        elseif  m == 1349 then -- Summerset     
        QuickMapNav:ShowAndSetAlpha(self.sumAur)
        if mouseoverName == "" then QuickMapNav:ShowAndSetAlpha(self.sumStros) end  
		QuickMapNav:ShowAndSetAlpha(self.sumHigh)
        QuickMapNav:ShowAndSetAlpha(self.aurArt)
        QuickMapNav:ShowAndSetAlpha(self.sumGre)
        --QuickMapNav:ShowAndSetAlpha(self.sumEye)
        QuickMapNav:ShowAndSetAlpha(self.sumWast)
		QuickMapNav:ShowAndSetAlpha(self.sumSap)
        

        elseif  m == 1814 then -- The Reach    
        if mouseoverName == "" then QuickMapNav:ShowAndSetAlpha(self.reachWest) end
		QuickMapNav:ShowAndSetAlpha(self.reachWestPass)
        QuickMapNav:ShowAndSetAlpha(self.reachCrag)
        QuickMapNav:ShowAndSetAlpha(self.reachBang)
        QuickMapNav:ShowAndSetAlpha(self.reaWroth)
		QuickMapNav:ShowAndSetAlpha(self.reaEarth)

        elseif  m == 125 then -- The Rift    
        QuickMapNav:ShowAndSetAlpha(self.riftEast)
		QuickMapNav:ShowAndSetAlpha(self.riftEastPass)
        QuickMapNav:ShowAndSetAlpha(self.riftStone)
		QuickMapNav:ShowAndSetAlpha(self.riftStonePass)
        QuickMapNav:ShowAndSetAlpha(self.riftCyr)
		QuickMapNav:ShowAndSetAlpha(self.riftGer)
        QuickMapNav:ShowAndSetAlpha(self.riftVvar)
		QuickMapNav:ShowAndSetAlpha(self.portEye)
		QuickMapNav:ShowAndSetAlpha(self.riftArc)
    QuickMapNav:ShowAndSetAlpha(self.riftJerp)

        elseif  m == 1060 then -- Vvardenfell    
        QuickMapNav:ShowAndSetAlpha(self.vvarBleak)
        QuickMapNav:ShowAndSetAlpha(self.vvarEast)
        QuickMapNav:ShowAndSetAlpha(self.vvarStone)
		QuickMapNav:ShowAndSetAlpha(self.vvarFir)
        QuickMapNav:ShowAndSetAlpha(self.vvarBal)
        QuickMapNav:ShowAndSetAlpha(self.vvarRift)
		QuickMapNav:ShowAndSetAlpha(self.vvarTel)
        
        elseif  m == 1719 then -- Western Skyrim    
        QuickMapNav:ShowAndSetAlpha(self.skyReach)
		QuickMapNav:ShowAndSetAlpha(self.skyReachPass)
        QuickMapNav:ShowAndSetAlpha(self.westWroth)
		QuickMapNav:ShowAndSetAlpha(self.westGrey)
		QuickMapNav:ShowAndSetAlpha(self.westRed)
        
        elseif  m == 667 then -- Wrothgar     
        QuickMapNav:ShowAndSetAlpha(self.wrothBang)
        QuickMapNav:ShowAndSetAlpha(self.wrothBangPass)
        QuickMapNav:ShowAndSetAlpha(self.wrothStorm)
		QuickMapNav:ShowAndSetAlpha(self.wrothStormPass)
        QuickMapNav:ShowAndSetAlpha(self.wrothRiv)
        if mouseoverName == "" then QuickMapNav:ShowAndSetAlpha(self.wrothGray) end
        QuickMapNav:ShowAndSetAlpha(self.wrothReach)
        QuickMapNav:ShowAndSetAlpha(self.wrothWest)
        
        elseif  m == 108 then -- Eyevea   

		QuickMapNav:ShowAndSetAlpha(self.eyeRift)
		QuickMapNav:ShowAndSetAlpha(self.eyeEast)
		QuickMapNav:ShowAndSetAlpha(self.eyeSha)
		QuickMapNav:ShowAndSetAlpha(self.eyeDesh)
		QuickMapNav:ShowAndSetAlpha(self.eyeSto)
	    
	    local eyeknown, eyerecallLocationName = GetFastTravelNodeInfo(215)  -- Eyevea Wayshrine
	    if eyeknown then
		    self.eyeWay:SetText(QMN.WSSymbol)
		else   
		    self.eyeWay:SetText(QMN.WSSymbolBlack) 
		end
	    if GetPlayerActiveZoneName() ~= GetMapNameById(108) then QuickMapNav:ShowAndSetAlpha(self.eyeWay) end

        
        elseif  m == 1864 then -- Grayhome
        QuickMapNav:ShowAndSetAlpha(self.grayRiven)
        QuickMapNav:ShowAndSetAlpha(self.grayWroth)
        
        elseif  m == 1850 then -- Arkthzand Cavern  
        QuickMapNav:ShowAndSetAlpha(self.arkthGrey)
        
        elseif  m == 1747 then -- Greymoor Caverns
        QuickMapNav:ShowAndSetAlpha(self.greyArkth)
        QuickMapNav:ShowAndSetAlpha(self.greyMzark)
		QuickMapNav:ShowAndSetAlpha(self.greyKagn)
		QuickMapNav:ShowAndSetAlpha(self.greyWest)
        
        elseif  m == 1748 then -- Mzark Cavern
        QuickMapNav:ShowAndSetAlpha(self.mzarkGrey)
		QuickMapNav:ShowAndSetAlpha(self.mzarkEast)
		QuickMapNav:ShowAndSetAlpha(self.mzarkEastLift)
        
        elseif  m == 205 then -- Mournhold
        QuickMapNav:ShowAndSetAlpha(self.deshClock)
        QuickMapNav:ShowAndSetAlpha(self.mournCold)
		QuickMapNav:ShowAndSetAlpha(self.mournClock)
       
        elseif  m == 1313 then -- Clockwork City
        QuickMapNav:ShowAndSetAlpha(self.clockDesh)
        
        elseif  m == 1348 then -- Brass Fortress
        QuickMapNav:ShowAndSetAlpha(self.clockDesh)
        
        elseif  m == 415 then -- Stirk
        --QuickMapNav:ShowAndSetAlpha(self.stirkEye)
        QuickMapNav:ShowAndSetAlpha(self.stirkAur)
        QuickMapNav:ShowAndSetAlpha(self.stirkStros)
		QuickMapNav:ShowAndSetAlpha(self.stirkHew)
		QuickMapNav:ShowAndSetAlpha(self.stirkGol)
		QuickMapNav:ShowAndSetAlpha(self.stirkHigh)
		QuickMapNav:ShowAndSetAlpha(self.stirkMal)
		QuickMapNav:ShowAndSetAlpha(self.stirkGre)
    
        elseif  m == 1887 then -- Blackwood
        QuickMapNav:ShowAndSetAlpha(self.blackSha)
        QuickMapNav:ShowAndSetAlpha(self.blackShaPass)
        QuickMapNav:ShowAndSetAlpha(self.blackMurk)
        QuickMapNav:ShowAndSetAlpha(self.blackSouth)
        QuickMapNav:ShowAndSetAlpha(self.blackNorth)
        QuickMapNav:ShowAndSetAlpha(self.blackNorthPass)
		QuickMapNav:ShowAndSetAlpha(self.blackBor)
        
        elseif  m == 1997 then -- Isle of Balfiera
        QuickMapNav:ShowAndSetAlpha(self.balGle)
        QuickMapNav:ShowAndSetAlpha(self.balStorm)
        QuickMapNav:ShowAndSetAlpha(self.balAlik)
		
		elseif  m == 1056 then -- Jerall Mountains
	    QuickMapNav:ShowAndSetAlpha(self.jerRift)
        QuickMapNav:ShowAndSetAlpha(self.jerCyr)
		
		elseif  m == 1706 then -- Valley of Blades	
        QuickMapNav:ShowAndSetAlpha(self.valCrag)
        QuickMapNav:ShowAndSetAlpha(self.valBang)
		
		elseif m == 1061 then -- Blackwood Borderlands
		QuickMapNav:ShowAndSetAlpha(self.borBlack)
		
		elseif m == 1668 then -- Jode's core
		QuickMapNav:ShowAndSetAlpha(self.jodNorth)
		QuickMapNav:ShowAndSetAlpha(self.jodeSouth)
		QuickMapNav:ShowAndSetAlpha(self.jodGrath)
		
		elseif m == 2035 then -- Fargrave city district
		QuickMapNav:ShowAndSetAlpha(self.farSham)
		QuickMapNav:ShowAndSetAlpha(self.farGreen)
		
		elseif m == 2082 then -- The Shambles
		QuickMapNav:ShowAndSetAlpha(self.shamFar)
		
		elseif m == 103 then -- Earth Forge
		QuickMapNav:ShowAndSetAlpha(self.earthBan)
		QuickMapNav:ShowAndSetAlpha(self.earthRea)
                              
	   local earthknown, earthrecallLocationName = GetFastTravelNodeInfo(221)  -- Earth Forge Wayshrine
	   if earthknown then
		    self.earthWay:SetText(QMN.WSSymbol)
	   else   
		    self.earthWay:SetText(QMN.WSSymbolBlack) 
	   end
	   QuickMapNav:ShowAndSetAlpha(self.earthWay) 

		elseif m == 590 then -- Arcwind point
		QuickMapNav:ShowAndSetAlpha(self.arcCyr)
		QuickMapNav:ShowAndSetAlpha(self.arcRift)
    QuickMapNav:ShowAndSetAlpha(self.arcJerp)
		
		elseif m == 2066 then -- Fort Grief
		QuickMapNav:ShowAndSetAlpha(self.fortCyr)
		
		elseif m == 2114 then -- High Isle
		QuickMapNav:ShowAndSetAlpha(self.highSum)
        QuickMapNav:ShowAndSetAlpha(self.highAur)
        QuickMapNav:ShowAndSetAlpha(self.highStros)
        QuickMapNav:ShowAndSetAlpha(self.highStirk)
		QuickMapNav:ShowAndSetAlpha(self.highGal)
		--QuickMapNav:ShowAndSetAlpha(self.highEye)
		if mouseoverName == "" then QuickMapNav:ShowAndSetAlpha(self.highBeth) end
		
		
		elseif m == 2212 then -- Galen
		QuickMapNav:ShowAndSetAlpha(self.galHigh)
		QuickMapNav:ShowAndSetAlpha(self.highStros)
		if mouseoverName == "" then QuickMapNav:ShowAndSetAlpha(self.highBeth) end
        
	
		
		elseif m == 2274 then -- Telvanni Peninsula
		QuickMapNav:ShowAndSetAlpha(self.telBal)
		QuickMapNav:ShowAndSetAlpha(self.telDesh)
		QuickMapNav:ShowAndSetAlpha(self.telVvar)
		QuickMapNav:ShowAndSetAlpha(self.telDeshPass)
		QuickMapNav:ShowAndSetAlpha(self.telBalPass)
		
		elseif m == 660 then -- Imperial City
		QuickMapNav:ShowAndSetAlpha(self.icIs)
		
		elseif m == 1707 then -- Vahlokzin's Domain
		QuickMapNav:ShowAndSetAlpha(self.vahlGrah)
		QuickMapNav:ShowAndSetAlpha(self.vahlNorth)
		
		elseif GetZoneId(GetCurrentMapZoneIndex()) == 643 then -- Imperial Sewers 
		QuickMapNav:ShowAndSetAlpha(self.isIc)
		
		elseif m == 2427 then -- West Weald
		QuickMapNav:ShowAndSetAlpha(self.WWReap)
		QuickMapNav:ShowAndSetAlpha(self.WWReapPass)
		QuickMapNav:ShowAndSetAlpha(self.WWCyr)
		if mouseoverName == "" then QuickMapNav:ShowAndSetAlpha(self.WWCrag) end
		QuickMapNav:ShowAndSetAlpha(self.WWCragPass)
		QuickMapNav:ShowAndSetAlpha(self.WWGold)
		QuickMapNav:ShowAndSetAlpha(self.WWGoldPassOne)
		QuickMapNav:ShowAndSetAlpha(self.WWGoldPassTwo)
		QuickMapNav:ShowAndSetAlpha(self.WWMal)
		
		elseif m == 2603 then -- Solstice
		QuickMapNav:ShowAndSetAlpha(self.solKhen)
		QuickMapNav:ShowAndSetAlpha(self.solSouth)
		QuickMapNav:ShowAndSetAlpha(self.solMurk)
    
		elseif m == 2847 then -- Jerall Pass
		QuickMapNav:ShowAndSetAlpha(self.jerpCyr)
		QuickMapNav:ShowAndSetAlpha(self.jerpArc)
    QuickMapNav:ShowAndSetAlpha(self.jerpRift)
		
		end
	end
	--CHAT_SYSTEM:AddMessage("QMN updated")
end

function QuickMapNav:OnUpdate()
	self:UpdateMapID()
end


function QuickMapNav:OnGamepadPreferredModeChanged()
	if IsInGamepadPreferredMode() then
		self.yDelta = 7
	else
		self.yDelta = 0
	end
	self:AttachTo(ZO_WorldMapScroll)
end


function QuickMapNav:UpdateTime()
    
	QMN.shelf.mapTitle:SetHidden(true)
	QMN.shelf.time:SetHidden(true)

 	if not QMN.vars.topLeftZoneName then
       QMN.shelf.mapTitle:SetHidden(false)
	   QMN.shelf.time:SetHidden(false)
	end
	
	if QMN.vars.seconds then 
	      QMN.Time = os.date("%H:%M:%S")
		  QMN.shelf.time:SetText(zo_strformat("|cffffff<<1>>|r",QMN.Time))
    elseif os.date("%S") == "00" then
	    QMN.Time = ZO_FormatClockTime()
	    QMN.shelf.time:SetText(zo_strformat("|cffffff<<1>>|r",QMN.Time))
	end
end	

	

local function OnAddonLoaded(event, addonName)

	if addonName == ADDON_NAME then

	-- Load the saved variables
    QMN.vars = ZO_SavedVars:NewAccountWide("QMNVars", 2, nil, QMN.defaults)
    QMN.CreateConfiguration()
	QMN.LMD = LibMapData
	
		--create instance of QuickMapNav object
		QUICK_MAP_NAV = QuickMapNav:New(WINDOW_MANAGER:CreateTopLevelWindow())

		--add scene fragment
		WORLD_MAP_SCENE:AddFragment(ZO_HUDFadeSceneFragment:New(QUICK_MAP_NAV.control))
		GAMEPAD_WORLD_MAP_SCENE:AddFragment(ZO_HUDFadeSceneFragment:New(QUICK_MAP_NAV.control))
		
		--update only when world map is active
		WORLD_MAP_SCENE:RegisterCallback("StateChange",
			function(oldState, newState)
				if newState == SCENE_SHOWING and not WORLD_MAP_MANAGER:IsInMode(MAP_MODE_VOTANS_MINIMAP) then
                    QMN.WorldMapShowing = true
					if not QMN.vars.topLeftZoneName then
                          zo_callLater(function() ZO_WorldMapCorner:SetHidden(true) end ,10)
	                end
					EVENT_MANAGER:RegisterForUpdate("QuickMapNav_OnUpdate", 1000, function() QuickMapNav:UpdateTime() end)

					--OnUpdate handler does not work if window is not defined in XML, I have to use EVENT_MANAGER:
					--EVENT_MANAGER:RegisterForUpdate("QuickMapNav_OnUpdate", 50, function() QUICK_MAP_NAV:OnUpdate() end)
				elseif newState == SCENE_HIDING then
				    QMN.WorldMapShowing = false
					EVENT_MANAGER:UnregisterForUpdate("QuickMapNav_OnUpdate")
				end
			end)
			
		--update only when world map is active
		GAMEPAD_WORLD_MAP_SCENE:RegisterCallback("StateChange",
			function(oldState, newState)
				if newState == SCENE_SHOWING and not WORLD_MAP_MANAGER:IsInMode(MAP_MODE_VOTANS_MINIMAP) then
					--QUICK_MAP_NAV:UpdateMapID()
                    QMN.WorldMapShowing = true
					if not QMN.vars.topLeftZoneName then
                          zo_callLater(function() ZO_WorldMapCorner:SetHidden(true) end ,10)
	                end
					EVENT_MANAGER:RegisterForUpdate("QuickMapNav_OnUpdate", 1000, function() QuickMapNav:UpdateTime() end)

				elseif newState == SCENE_HIDING then
				    QMN.WorldMapShowing = false
					EVENT_MANAGER:UnregisterForUpdate("QuickMapNav_OnUpdate")
				end
			end)
			
	   -- update only when zooming	
	   local mapPanAndZoom = ZO_WorldMap_GetPanAndZoom()
       SecurePostHook(mapPanAndZoom , "SetCurrentNormalizedZoomInternal", function(selfMapPanAndZoom, normalizedZoom) 
       QMN.zoomMaxed = false
		   QMN.zoomLevel = mapPanAndZoom:GetCurrentNormalizedZoom()
		   if mapPanAndZoom.canZoomOutFurther == false then
			  QMN.zoomMaxed = true 
		   end
	       QUICK_MAP_NAV:OnUpdate()
	   end)	
	   
	   -- update only when Mouseover text has changed
	     local mouseoverNameControl = WINDOW_MANAGER:GetControlByName("ZO_WorldMapMouseoverName")
	     SecurePostHook(WORLD_MAP_MANAGER, "SetMapHeader" , function(selfWorldMapManager, headerInfo)
       local mouseoverName = mouseoverNameControl:GetText() 
		   if mouseoverName ~= QMN.mouseoverName then
			    QMN.mouseoverName = mouseoverName
			    QUICK_MAP_NAV:OnUpdate() 
		   end
	   end)	

	   
	   
	  -- set fast travel interaction bool
    EVENT_MANAGER:RegisterForEvent( ADDON_NAME, EVENT_START_FAST_TRAVEL_INTERACTION, function() QMN.FastTravelInteraction = true end)
    EVENT_MANAGER:RegisterForEvent( ADDON_NAME, EVENT_END_FAST_TRAVEL_INTERACTION, function() QMN.FastTravelInteraction = false end)
		
		
		--refresh when map is changed
		--CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", function() QUICK_MAP_NAV:UpdateMapID() end)
		QMN.LMD:RegisterCallback(QMN.LMD.callbackType.OnWorldMapChanged, function() if QMN.WorldMapShowing then QUICK_MAP_NAV:UpdateMapID() end end)
		
		EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function() QUICK_MAP_NAV:OnGamepadPreferredModeChanged() end)
			
		--unregister event after initialization
		EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
		
	end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)