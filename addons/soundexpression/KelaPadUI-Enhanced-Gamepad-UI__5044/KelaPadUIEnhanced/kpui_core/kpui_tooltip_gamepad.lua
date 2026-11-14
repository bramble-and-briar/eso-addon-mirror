KPUI_GamepadTooltip = {}
local colors = kpuiConst.Colors


local function LayoutFunction(self, tooltipType, ...)
    local tooltipContainer = self:GetTooltipContainer(tooltipType)
    if tooltipContainer == nil then
        return
    end

    local tooltipContainerTip = self:GetAndInitializeTooltipContainerTip(tooltipType)

    local tooltipFunction = tooltipContainerTip.tooltip[self.currentLayoutFunctionName] or nil
    if tooltipFunction == nil then
        return nil -- if this line fired you called a function that does not exist on KPUI_GamepadTooltip or KPUI_Tooltip
    end

    local tooltipInfo = self:GetTooltipInfo(tooltipType)
    tooltipContainerTip:ClearLines(tooltipInfo.resetScroll)
    local returnValue = tooltipFunction(tooltipContainerTip.tooltip, ...)
    local tooltipFragment = self:GetTooltipFragment(tooltipType)
    if tooltipContainerTip:HasControls() then
        SCENE_MANAGER:AddFragment(tooltipFragment)
        if self:DoesAutoShowTooltipBg(tooltipType) then
            SCENE_MANAGER:AddFragment(self:GetTooltipBgFragment(tooltipType))
        end
    else
        SCENE_MANAGER:RemoveFragment(tooltipFragment)
        if self:DoesAutoShowTooltipBg(tooltipType) then
            SCENE_MANAGER:RemoveFragment(self:GetTooltipBgFragment(tooltipType))
        end
    end
    return returnValue
end

KPUI_GamepadTooltip.metaTable =
{
    __index = function(t, key)
        local value = KPUI_GamepadTooltip[key]
        if value == nil then
            t.currentLayoutFunctionName = key
            return LayoutFunction
        end
        return value
    end,
}

KPUI_GAMEPAD_RIGHT_TOOLTIP = "KPUI_GAMEPAD_RIGHT_TOOLTIP"
KPUI_GAMEPAD_TRADING_TOOLTIP = "KPUI_GAMEPAD_TRADING_TOOLTIP"
KPUI_GAMEPAD_COMPARE_TOOLTIP = "KPUI_GAMEPAD_COMPARE_TOOLTIP"
KPUI_GAMEPAD_COMPARE_TOOLTIP2 = "KPUI_GAMEPAD_COMPARE_TOOLTIP2"
KPUI_GAMEPAD_LEFT_DIALOG_TOOLTIP = "KPUI_GAMEPAD_LEFT_DIALOG_TOOLTIP"

KPUI_GAMEPAD_TOOLTIP_NORMAL_BG = 1
KPUI_GAMEPAD_TOOLTIP_DARK_BG = 2

function KPUI_GamepadTooltip:New(...)
    local gamepadTooltip = {}
    setmetatable(gamepadTooltip, self.metaTable)
    gamepadTooltip:Initialize(...)
    return gamepadTooltip
end

function KPUI_GamepadTooltip:Initialize(control, dialogControl)
    self.control = control
    self.dialogControl = dialogControl
    self.tooltips = {}

    local AUTO_SHOW_BG = true
    self:InitializeTooltip(KPUI_GAMEPAD_RIGHT_TOOLTIP, self.control, "Right", AUTO_SHOW_BG, LEFT)
    self:InitializeTooltip(KPUI_GAMEPAD_TRADING_TOOLTIP, self.control, "Trading", AUTO_SHOW_BG, RIGHT)
    self:InitializeTooltip(KPUI_GAMEPAD_COMPARE_TOOLTIP, self.control, "Compare", AUTO_SHOW_BG, LEFT)
    self:InitializeTooltip(KPUI_GAMEPAD_COMPARE_TOOLTIP2, self.control, "Compare2", AUTO_SHOW_BG, LEFT)
    self:InitializeTooltip(KPUI_GAMEPAD_LEFT_DIALOG_TOOLTIP, self.dialogControl, "Left", AUTO_SHOW_BG, RIGHT)
end

function KPUI_GamepadTooltip:InitializeTooltip(tooltipType, baseControl, prefix, autoShowBg, scrollIndicatorSide)
    local control = baseControl:GetNamedChild(prefix.."Tooltip")
    local bgControl = baseControl:GetNamedChild(prefix.."TooltipBg")
    local darkBgControl = baseControl:GetNamedChild(prefix.."TooltipDarkBg")

    local container = control:GetNamedChild("Container")
    container.tip = container:GetNamedChild("Tip")
    container.tip.initialized = false
    control.container = container

    local bgFragment = ZO_FadeSceneFragment:New(bgControl, true)
    _G[tooltipType.."_BACKGROUND_FRAGMENT"] = bgFragment
    bgControl:SetAnchorFill(control)

    local darkBgFragment = ZO_FadeSceneFragment:New(darkBgControl, true)
    _G[tooltipType.."_DARK_BACKGROUND_FRAGMENT"] = darkBgFragment
    darkBgControl:SetAnchorFill(control)

    local needBG = KPUI_GAMEPAD_TOOLTIP_NORMAL_BG
    if tooltipType == KPUI_GAMEPAD_LEFT_DIALOG_TOOLTIP then needBG = KPUI_GAMEPAD_TOOLTIP_DARK_BG end
    if tooltipType == KPUI_GAMEPAD_COMPARE_TOOLTIP then needBG = KPUI_GAMEPAD_TOOLTIP_DARK_BG end
    if tooltipType == KPUI_GAMEPAD_COMPARE_TOOLTIP2 then needBG = KPUI_GAMEPAD_TOOLTIP_DARK_BG end

    self.tooltips[tooltipType] =
    {
        control = control,
        bgControl = bgControl,
        darkBgControl = darkBgControl,
        fragment = ZO_FadeSceneFragment:New(control, true),
        bgFragment = bgFragment,
        darkBgFragment = darkBgFragment,
        autoShowBg = autoShowBg,
        defaultAutoShowBg = autoShowBg,
        bgType = needBG,
        resetScroll = true,
        scrollIndicatorSide = scrollIndicatorSide,
    }

    self:SetScrollIndicatorSide(tooltipType, scrollIndicatorSide)
end


function KPUI_GamepadTooltip:HideTooltip(tooltipType)
	SCENE_MANAGER:RemoveFragment(self:GetTooltipFragment(tooltipType))
	SCENE_MANAGER:RemoveFragment(self:GetTooltipBgFragment(tooltipType))
end
--Set retainFragment to true if you intend to re-layout this tooltip immediately after calling ClearTooltip
--This saves us the performance cost of removing the fragment just to add it right back in again
--Particularly when done in an update loop
function KPUI_GamepadTooltip:ClearTooltip(tooltipType, retainFragment)
	
	local tooltipContainer = self:GetTooltipContainer(tooltipType)
    if tooltipContainer then
        local tooltipContainerTip = self:GetAndInitializeTooltipContainerTip(tooltipType)

        local tooltipInfo = self:GetTooltipInfo(tooltipType)
        tooltipContainerTip:ClearLines(tooltipInfo.resetScroll)
        if not retainFragment then
            SCENE_MANAGER:RemoveFragment(self:GetTooltipFragment(tooltipType))
            if self:DoesAutoShowTooltipBg(tooltipType) then
                SCENE_MANAGER:RemoveFragment(self:GetTooltipBgFragment(tooltipType))
            end
        end
    end
end


function KPUI_GamepadTooltip:SetScrollIndicatorSide(tooltipType, side)
    local tooltipContainer = self:GetTooltipContainer(tooltipType)
    if tooltipContainer then
        local tooltipInfo = self:GetTooltipInfo(tooltipType)
        local scrollIndicator = tooltipContainer.tip:GetNamedChild("ScrollIndicator")
        ZO_Scroll_Gamepad_SetScrollIndicatorSide(scrollIndicator, tooltipInfo.bgControl, side)
    end
end


function KPUI_GamepadTooltip:GetTooltipContainer(tooltipType)
    return self:GetTooltipInfo(tooltipType).control.container
end

function KPUI_GamepadTooltip:GetAndInitializeTooltipContainerTip(tooltipType)
    local tooltipContainer = self:GetTooltipContainer(tooltipType)

    if tooltipContainer then
        local tooltipContainerTip = tooltipContainer.tip
        if tooltipContainerTip.initialized == false then
            tooltipContainerTip.initialized = true
            ZO_ScrollTooltip_Gamepad:Initialize(tooltipContainerTip, ZO_TOOLTIP_STYLES)
        end
        return tooltipContainerTip
    end
end

function KPUI_GamepadTooltip:GetTooltipFragment(tooltipType)
    return self:GetTooltipInfo(tooltipType).fragment
end

function KPUI_GamepadTooltip:GetTooltipBgFragment(tooltipType)
    local info = self:GetTooltipInfo(tooltipType)
    if info.bgType == KPUI_GAMEPAD_TOOLTIP_NORMAL_BG then
        return info.bgFragment
    elseif info.bgType == KPUI_GAMEPAD_TOOLTIP_DARK_BG then
        return info.darkBgFragment
    end
end


function KPUI_GamepadTooltip:DoesAutoShowTooltipBg(tooltipType)
    return self:GetTooltipInfo(tooltipType).autoShowBg
end

function KPUI_GamepadTooltip:GetTooltipInfo(tooltipType)
    return self.tooltips[tooltipType]
end

function KPUI_GamepadTooltip_OnInitialized(control, dialogControl)
    KPUI_GAMEPAD_TOOLTIPS = KPUI_GamepadTooltip:New(control, dialogControl)
end


KELA_FIRST_CALL_RECOLOR_BONUSES = true

KELA_RECOLOR_BONUS = ""
KELA_RECOLOR_BONUS_PERCENT = ""
KELA_RECOLOR_BONUS_INACTIVE = ""
KELA_RECOLOR_BONUS_INACTIVE_PERCENT = ""

-- highlight numbers in bonus descriptions
function kelaReColorDescription(activateBonus)
	if KELA_FIRST_CALL_RECOLOR_BONUSES then
		KELA_RECOLOR_BONUS = GetString(SI_ITEM_FORMAT_STR_SET_PROPERTY_BONUS)
		KELA_RECOLOR_BONUS_PERCENT = GetString(SI_ITEM_FORMAT_STR_SET_PROPERTY_BONUS_PERCENT)
		KELA_RECOLOR_BONUS_INACTIVE = GetString(SI_ITEM_FORMAT_STR_SET_PROPERTY_BONUS_INACTIVE)
		KELA_RECOLOR_BONUS_INACTIVE_PERCENT = GetString(SI_ITEM_FORMAT_STR_SET_PROPERTY_BONUS_INACTIVE_PERCENT)
		KELA_FIRST_CALL_RECOLOR_BONUSES = false
	end
	if activateBonus then 
		SafeAddString(SI_ITEM_FORMAT_STR_SET_PROPERTY_BONUS_INACTIVE, KELA_RECOLOR_BONUS, 2)
		SafeAddString(SI_ITEM_FORMAT_STR_SET_PROPERTY_BONUS_INACTIVE_PERCENT, KELA_RECOLOR_BONUS_PERCENT, 1) 
	else
		SafeAddString(SI_ITEM_FORMAT_STR_SET_PROPERTY_BONUS_INACTIVE, KELA_RECOLOR_BONUS_INACTIVE, 2)
		SafeAddString(SI_ITEM_FORMAT_STR_SET_PROPERTY_BONUS_INACTIVE_PERCENT, KELA_RECOLOR_BONUS_INACTIVE_PERCENT, 1) 
	end
end

function ZO_Tooltip:LayoutDescriptionTooltip(title, desc)
    self:AddLine(title, self:GetStyle("title"))
    local bodySection = self:AcquireSection(self:GetStyle("bodySection"))	
    if desc then bodySection:AddLine(desc, self:GetStyle("bodyDescription")) end
    self:AddSection(bodySection)
end

function ZO_Tooltip:LayoutItemStatComparisonItemLink(itemLink, comparisonSlot)
 	
	local name = colors.COLOR_WHITE:Colorize(string.upper(GetString("SI_EQUIPSLOT", comparisonSlot)))
	self:AddLine(name, self:GetStyle("title"), {fontSize = KELA_TOOLTIPS_FONT_BIG, customSpacing = 0, childSpacing = 30})
	
	local statDeltaLookup = ZO_GetStatDeltaLookupFromItemComparisonReturns(CompareItemLinkToCurrentlyEquipped(itemLink, comparisonSlot))
    for _, statGroup in ipairs(ZO_INVENTORY_STAT_GROUPS) do
        local statSection = self:AcquireSection(self:GetStyle("itemComparisonStatSection"))
        for _, stat in ipairs(statGroup) do
            
            local statName = zo_strformat(SI_STAT_NAME_FORMAT, GetString("SI_DERIVEDSTATS", stat))
            local currentValue = GetPlayerStat(stat)
            local statDelta = statDeltaLookup[stat] or 0
            local valueToShow = currentValue + statDelta
            
            if stat == STAT_SPELL_CRITICAL or stat == STAT_CRITICAL_STRIKE then
                local newPercent = GetCriticalStrikeChance(valueToShow)
                valueToShow = zo_strformat(SI_STAT_VALUE_PERCENT, newPercent)
            end

            local colorStyle = self:GetStyle("itemComparisonStatValuePairDefaultColor")
            if statDelta ~= 0 then
                local icon
                if statDelta > 0 then
                    colorStyle = self:GetStyle("succeeded")
                    icon = "EsoUI/Art/Buttons/Gamepad/gp_upArrow.dds"
                else
                    colorStyle = self:GetStyle("failed")
                    icon = "EsoUI/Art/Buttons/Gamepad/gp_downArrow.dds"
                end
                valueToShow = valueToShow .. zo_iconFormatInheritColor(icon, 24, 24)
            end

            local statValuePair = statSection:AcquireStatValuePair(self:GetStyle("itemComparisonStatValuePair"))
            statValuePair:SetStat(statName, self:GetStyle("statValuePairStat"))
            statValuePair:SetValue(valueToShow, self:GetStyle("itemComparisonStatValuePairValue"), colorStyle)
            statSection:AddStatValuePair(statValuePair)
        end
        self:AddSection(statSection)
    end
end

function ZO_Tooltip:LayoutSetTooltip(data)
	
	
	if KELA_SETS_LIST.comparedSetData ~= false then 

		local comparedData = KELA_SETS_LIST.comparedSetData
		local bodySection2 = self:AcquireSection(self:GetStyle("bodySection"))	
		local name2 = colors.COLOR_WHITE:Colorize(string.upper(comparedData.setName))
		if name2 then bodySection2:AddLine(name2, self:GetStyle("title")) end
		if comparedData.setObtainableItemsFull then bodySection2:AddLine(GetString(KELA_SETSLIST_HEADER_OBTAINABLEITEMS)..": "..colors.COLOR_WHITE:Colorize(comparedData.setObtainableItemsFull), self:GetStyle("bodyDescription")) end	
		self:AddSection(bodySection2)		
		local itemID = LibSets.GetSetItemId(comparedData.setID)
		local itemLink = LibSets.buildItemLink(itemID, 370)
		if itemLink then
			local bodySection2 = self:AcquireSection(self:GetStyle("bodySection"))	
			bodySection2:AddLine(colors.COLOR_WHITE:Colorize(GetString(KELA_SETS_TOOLTIP_BONUSES)), self:GetStyle("bodyDescription"))
			local _, _, numBonuses = GetItemLinkSetInfo(itemLink, false)
			for i=1, numBonuses do
				local numRequired, bonusDescription = GetItemLinkSetBonusInfo(itemLink, false, i)
				bodySection2:AddLine(bonusDescription, self:GetStyle("activeBonus"), self:GetStyle("bodyDescription"))
			end		
			self:AddSection(bodySection2)	
		end

		local bodySection2 = self:AcquireSection(self:GetStyle("bodySection"))	
		bodySection2:AddLine(" ", self:GetStyle("bodyDescription"), {customSpacing = -20}) 
		bodySection2:AddLine("________________________________", self:GetStyle("bodyDescription"), {customSpacing = -20, horizontalAlignment = TEXT_ALIGN_CENTER}) 
		bodySection2:AddLine(" ", self:GetStyle("bodyDescription"), {customSpacing = -20}) 
		self:AddSection(bodySection2)		

		local bodySection = self:AcquireSection(self:GetStyle("bodySection"))	
		local name = colors.COLOR_WHITE:Colorize(string.upper(data.setName))
		if name then bodySection:AddLine(name, self:GetStyle("title")) end
		if data.setObtainableItemsFull then bodySection:AddLine(GetString(KELA_SETSLIST_HEADER_OBTAINABLEITEMS)..": "..colors.COLOR_WHITE:Colorize(data.setObtainableItemsFull), self:GetStyle("bodyDescription")) end	
		self:AddSection(bodySection)	
		local itemID = LibSets.GetSetItemId(data.setID)
		local itemLink = LibSets.buildItemLink(itemID, 370)
		if itemLink then
			local bodySection = self:AcquireSection(self:GetStyle("bodySection"))	
			bodySection:AddLine(colors.COLOR_WHITE:Colorize(GetString(KELA_SETS_TOOLTIP_BONUSES)), self:GetStyle("bodyDescription"))
			local _, _, numBonuses = GetItemLinkSetInfo(itemLink, false)
			for i=1, numBonuses do
				local numRequired, bonusDescription = GetItemLinkSetBonusInfo(itemLink, false, i)
				bodySection:AddLine(bonusDescription, self:GetStyle("activeBonus"), self:GetStyle("bodyDescription"))
			end		
			self:AddSection(bodySection)	
		end	
		
	else	
		local bodySection = self:AcquireSection(self:GetStyle("bodySection"))	
		local name = colors.COLOR_WHITE:Colorize(string.upper(data.setName))
		if name then bodySection:AddLine(name, self:GetStyle("title")) end

		if data.setTypeName then bodySection:AddLine(GetString(KELA_SETSLIST_HEADER_SETTYPE)..": "..data.setTypeName, self:GetStyle("bodyDescription")) end
		if data.setDLCName then bodySection:AddLine(GetString(KELA_SETSLIST_HEADER_DLC)..": "..colors.COLOR_WHITE:Colorize(data.setDLCName), self:GetStyle("bodyDescription")) end
		if data.setObtainableItemsFull then bodySection:AddLine(GetString(KELA_SETSLIST_HEADER_OBTAINABLEITEMS)..": "..colors.COLOR_WHITE:Colorize(data.setObtainableItemsFull), self:GetStyle("bodyDescription")) end

		if data.setZoneNames then 
			local ZoneText
			if data.setDropMechanic then
				ZoneText = GetString(KELA_SETSLIST_HEADER_DROPZONE)..": "..colors.COLOR_WHITE:Colorize(tostring(data.setZoneNames)).." ("..data.DMText..")"
			else
				ZoneText = GetString(KELA_SETSLIST_HEADER_DROPZONE)..": "..colors.COLOR_WHITE:Colorize(tostring(data.setZoneNames))
			end
			bodySection:AddLine(ZoneText, self:GetStyle("bodyDescription")) 
		end

		bodySection:AddLine(" ", self:GetStyle("bodyDescription"), {customSpacing = -20}) 
		self:AddSection(bodySection)
		
		if data.setTraits or data.setVeteran or data.setBindType then -- or data.setWayshrines then
			local bodySection = self:AcquireSection(self:GetStyle("bodySection"))	
			bodySection:AddLine(colors.COLOR_WHITE:Colorize(GetString(KELA_SETS_TOOLTIP_EXTRA)), self:GetStyle("bodyDescription"))
			self:AddSection(bodySection)
			local ExtraList
			local infoExtraSection = self:AcquireSection(self:GetStyle("InfoTooltipDesc"))
			local infoExtra = self:AcquireStatValuePair(self:GetStyle("InfoTooltipStatValuePair"))
			local bop = colors.COLOR_BROWN:Colorize("- ")
			if data.setTraits then 
				ExtraList = bop..colors.COLOR_PINK:Colorize(GetString(KELA_SETS_TOOLTIP_TRAITS1))..colors.COLOR_WHITE:Colorize(data.setTraits)..colors.COLOR_PINK:Colorize(GetString(KELA_SETS_TOOLTIP_TRAITS2))
			end
			if data.canTeleport then 
				if ExtraList then
					ExtraList = ExtraList.."\n"..bop..colors.COLOR_STAMINA:Colorize(GetString(KELA_SETS_TOOLTIP_HAVEWAYSHRINE))
				else
					ExtraList = bop..colors.COLOR_STAMINA:Colorize(GetString(KELA_SETS_TOOLTIP_HAVEWAYSHRINE))
				end
			end
			if data.setVeteran then
				if ExtraList then
					ExtraList = ExtraList.."\n"..bop..colors.COLOR_ORANGE:Colorize(GetString(KELA_SETS_VETERANFULL))
				else
					ExtraList = bop..colors.COLOR_ORANGE:Colorize(GetString(KELA_SETS_VETERANFULL))
				end
			end
			if data.setBindType then 
				if ExtraList then
					ExtraList = ExtraList.."\n"..bop..colors.COLOR_BROWN:Colorize(GetString("SI_BINDTYPE", data.setBindType))
				else
					ExtraList = bop..colors.COLOR_BROWN:Colorize(GetString("SI_BINDTYPE", data.setBindType))
				end
			end
			infoExtra:SetStat(" ", self:GetStyle("InfoTooltipStatValuePairStat"))
			infoExtra:SetValue(ExtraList, self:GetStyle("InfoTooltipStatValuePairValueLeftAlign"))
			infoExtraSection:AddStatValuePair(infoExtra)
			self:AddSection(infoExtraSection)		
		end	
		
		local itemID = LibSets.GetSetItemId(data.setID)
		local itemLink = LibSets.buildItemLink(itemID)
		if itemLink then
			local bodySection = self:AcquireSection(self:GetStyle("bodySection"))	
			bodySection:AddLine(" ", self:GetStyle("bodyDescription"), {customSpacing = -20}) 
			bodySection:AddLine(colors.COLOR_WHITE:Colorize(GetString(KELA_SETS_TOOLTIP_BONUSES)), self:GetStyle("bodyDescription"))
			

			local _, _, numBonuses = GetItemLinkSetInfo(itemLink, false)
		
			
			for i=1, numBonuses do
				local numRequired, bonusDescription = GetItemLinkSetBonusInfo(itemLink, false, i)
				bodySection:AddLine(bonusDescription, self:GetStyle("activeBonus"), self:GetStyle("bodyDescription"))
			end		
			bodySection:AddLine(" ", self:GetStyle("bodyDescription"), {customSpacing = -20}) 
			self:AddSection(bodySection)
		end


		if data.setDropMechanic then 
			local bodySection = self:AcquireSection(self:GetStyle("bodySection"))	
			bodySection:AddLine(colors.COLOR_WHITE:Colorize(GetString(KELA_SETS_TOOLTIP_DROPMECHANIC)), self:GetStyle("bodyDescription"))
			self:AddSection(bodySection)
			local infoDMSection = self:AcquireSection(self:GetStyle("InfoTooltipDesc"))
			local infoDM = self:AcquireStatValuePair(self:GetStyle("InfoTooltipStatValuePair"))
			infoDM:SetStat(" ", self:GetStyle("InfoTooltipStatValuePairStat"))
			infoDM:SetValue(data.DMTextFull, self:GetStyle("InfoTooltipStatValuePairValueLeftAlign"))
			infoDMSection:AddStatValuePair(infoDM)
			self:AddSection(infoDMSection)	
		end	
			
	
	end
	
end
