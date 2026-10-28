
local addonName = "ExoYsJuggernautificator"
local sv = {}
local EM = GetEventManager() 

local function CalcOffensiveMetric()
    local weaponDmg = GetPlayerStat(STAT_POWER,STAT_BONUS_OPTION_APPLY_BONUS)
    local spellDmg = GetPlayerStat(STAT_SPELL_POWER,STAT_BONUS_OPTION_APPLY_BONUS)
    local weaponCrit = GetPlayerStat(STAT_CRITICAL_STRIKE,STAT_BONUS_OPTION_APPLY_BONUS)
    local spellCrit = GetPlayerStat(STAT_SPELL_CRITICAL,STAT_BONUS_OPTION_APPLY_BONUS)

    local offensiveMetric = (weaponDmg + spellDmg)*5.7 + (weaponCrit + spellCrit)*2.26

    return offensiveMetric

end

local function CalcDefensiveMetric()
    local _, maxHealth = GetUnitPower("player", 32)
    local physicalRes = GetPlayerStat(STAT_PHYSICAL_RESIST,STAT_BONUS_OPTION_APPLY_BONUS)
    local spellRes = GetPlayerStat(STAT_SPELL_RESIST,STAT_BONUS_OPTION_APPLY_BONUS)

    local defensiveMetric = maxHealth + physicalRes + spellRes

    return defensiveMetric
end


local function CalcTheoreticalDmgBoni() 
    local physicalRes = GetPlayerStat(STAT_PHYSICAL_RESIST,STAT_BONUS_OPTION_APPLY_BONUS)
    local spellRes = GetPlayerStat(STAT_SPELL_RESIST,STAT_BONUS_OPTION_APPLY_BONUS)
    local maxHealth = GetUnitPower("player", 32)

    local dmgBoni = (physicalRes + spellRes + maxHealth)/4500

    return dmgBoni 
end


local addonUI = {}
local function BuildUI() 
    local WM = GetWindowManager()
    local font = ""
    local width = 250
    local height = 175
    
    local win = WM:CreateTopLevelWindow( addonName.."Window" ) 
    win:ClearAnchors() 
    win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.x, sv.y) 
    win:SetMouseEnabled(true) 
    win:SetClampedToScreen(true) 
    win:SetMovable(true) 
    win:SetHidden(false) 
    win:SetDimensions(width, height)
    win:SetHandler( "OnMoveStop", function() 
        sv.x = win:GetLeft() 
        sv.y = win:GetTop()
    end)
    
    local frag = ZO_HUDFadeSceneFragment:New(win) 
    HUD_UI_SCENE:AddFragment(frag) 
    HUD_SCENE:AddFragment(frag) 

    local ctrl = WM:CreateControl( addonName.."Control", win, CT_CONTROL)
    ctrl:ClearAnchors() 
    ctrl:SetAnchor(TOPLEFT, win, TOPLEFT, 0,0) 
    ctrl:SetDimensions(width, height) 

    local back = WM:CreateControl( addonName.."Back", ctrl, CT_BACKDROP) 
    back:ClearAnchors() 
    back:SetAnchor(TOPLEFT, ctrl, TOPLEFT, 0, 0) 
    back:SetDimensions(width,height) 
    back:SetCenterColor(0,0,0,0.6)
    back:SetEdgeColor(0,0,0,1)

    local header = WM:CreateControl( addonName.."Header", ctrl, CT_LABEL) 
    header:ClearAnchors() 
    header:SetAnchor(TOP, ctrl, TOP, 5, 0 ) 
    header:SetFont("ZoFontWinH4")
    header:SetColor(1,1,1,1) 
    header:SetText("|c00ff00ExoY|rs Juggernautificator")

    local dividerTop = WM:CreateControl(addonName.."DividerTop" , ctrl, CT_TEXTURE)
    dividerTop:ClearAnchors()
    dividerTop:SetAnchor(TOP, header, BOTTOM, 0, 0)
    dividerTop:SetDimensions(width, 7)
    dividerTop:SetTexture("esoui/art/interaction/conversation_divider.dds")

    local theoDmgLabel = WM:CreateControl( addonName.."theoDmgLabel", ctrl, CT_LABEL) 
    theoDmgLabel:ClearAnchors() 
    theoDmgLabel:SetAnchor(TOPLEFT, dividerTop, BOTTOMLEFT, 0, 0 ) 
    theoDmgLabel:SetFont("ZoFontGame")
    theoDmgLabel:SetColor(1,1,1,1) 
    theoDmgLabel:SetText("Theoretical damage done \nboni per buff instanz: ")
    theoDmgLabel:SetMouseEnabled(true)
    theoDmgLabel:SetHandler("OnMouseEnter", function() 
        InitializeTooltip(InformationTooltip, theoDmgLabel, RIGHT) 
        InformationTooltip:AddLine("This is the damage done boni you get per instanz, |c00ffffIF|r you are a juggernaut (defensive stats > offensive stats). Instanz means each sorce of this boni, e.g. the CP is one instance, the S&B passive is one instance, the heavy armore passive is one instance.", "ZoFontGame")
    end)
    theoDmgLabel:SetHandler("OnMouseExit", function() ZO_Tooltips_HideTextTooltip() end )

    local theoDmgValue = WM:CreateControl( addonName.."theoDmgValue", ctrl, CT_LABEL) 
    theoDmgValue:ClearAnchors() 
    theoDmgValue:SetAnchor(LEFT, theoDmgLabel, RIGHT, 5, 0 ) 
    theoDmgValue:SetFont("ZoFontGame")
    theoDmgValue:SetColor(1,1,1,1) 
    addonUI.UpdateTheoreticalDmgBoniValue = function() 
        theoDmgValue:SetText(string.format("%.1f%%", CalcTheoreticalDmgBoni()))
    end

    local dividerMiddle = WM:CreateControl(addonName.."DividerMiddle" , ctrl, CT_TEXTURE)
    dividerMiddle:ClearAnchors()
    dividerMiddle:SetAnchor(TOP, header, BOTTOM, 0, 60)
    dividerMiddle:SetDimensions(width, 7)
    dividerMiddle:SetTexture("esoui/art/interaction/conversation_divider.dds")
    
    local offMetricLabel = WM:CreateControl( addonName.."offMetricLabel", ctrl, CT_LABEL) 
    offMetricLabel:ClearAnchors() 
    offMetricLabel:SetAnchor(TOPLEFT, dividerMiddle, BOTTOMLEFT, 0, 0 ) 
    offMetricLabel:SetFont("ZoFontGame")
    offMetricLabel:SetColor(1,1,1,1) 
    offMetricLabel:SetText("Offensive Stats: ")
    offMetricLabel:SetMouseEnabled(true)
    offMetricLabel:SetHandler("OnMouseEnter", function() 
        InitializeTooltip(InformationTooltip, offMetricLabel, RIGHT) 
        InformationTooltip:AddLine("Value of offensive stats according to 12.0.0 patch notes.", "ZoFontGame")
    end)
    offMetricLabel:SetHandler("OnMouseExit", function() ZO_Tooltips_HideTextTooltip() end )

    local offMetricValue = WM:CreateControl( addonName.."offMetricValue", ctrl, CT_LABEL) 
    offMetricValue:ClearAnchors() 
    offMetricValue:SetAnchor(LEFT, offMetricLabel, RIGHT, 5, 0 ) 
    offMetricValue:SetFont("ZoFontGame")
    offMetricValue:SetColor(1,1,1,1) 
    addonUI.UpdateOffensiveMetricValue = function() offMetricValue:SetText(tostring( CalcOffensiveMetric() )) end

    local defMetricLabel = WM:CreateControl( addonName.."defMetricLabel", ctrl, CT_LABEL) 
    defMetricLabel:ClearAnchors() 
    defMetricLabel:SetAnchor(TOPLEFT, offMetricLabel, BOTTOMLEFT, 0, 0 ) 
    defMetricLabel:SetFont("ZoFontGame")
    defMetricLabel:SetColor(1,1,1,1) 
    defMetricLabel:SetText("Defensive Stats: ")
    defMetricLabel:SetMouseEnabled(true)
    defMetricLabel:SetHandler("OnMouseEnter", function() 
        InitializeTooltip(InformationTooltip, defMetricLabel, RIGHT) 
        InformationTooltip:AddLine("Value of defensive stats according to 12.0.0 patch notes.", "ZoFontGame")
    end)
    defMetricLabel:SetHandler("OnMouseExit", function() ZO_Tooltips_HideTextTooltip() end )

    
    local defMetricValue = WM:CreateControl( addonName.."defMetricValue", ctrl, CT_LABEL) 
    defMetricValue:ClearAnchors() 
    defMetricValue:SetAnchor(LEFT, defMetricLabel, RIGHT, 5, 0 ) 
    defMetricValue:SetFont("ZoFontGame")
    defMetricValue:SetColor(1,1,1,1) 
    addonUI.UpdateDefensiveMetricValue = function() defMetricValue:SetText(tostring( CalcDefensiveMetric() )) end

    local dividerBottom = WM:CreateControl(addonName.."DividerBottom" , ctrl, CT_TEXTURE)
    dividerBottom:ClearAnchors()
    dividerBottom:SetAnchor(TOP, header, BOTTOM, 0, 120)
    dividerBottom:SetDimensions(width, 7)
    dividerBottom:SetTexture("esoui/art/interaction/conversation_divider.dds")

    local juggernautLabel = WM:CreateControl( addonName.."juggernautLabel", ctrl, CT_LABEL) 
    juggernautLabel:ClearAnchors() 
    juggernautLabel:SetAnchor(TOPLEFT, dividerBottom, BOTTOMLEFT, 0, 0 ) 
    juggernautLabel:SetFont("ZoFontGame")
    juggernautLabel:SetColor(1,1,1,1) 
    juggernautLabel:SetText("Am I a juggernaut? ")
    juggernautLabel:SetMouseEnabled(true)
    juggernautLabel:SetHandler("OnMouseEnter", function() 
        InitializeTooltip(InformationTooltip, juggernautLabel, RIGHT) 
        InformationTooltip:AddLine("|c00ff00Yes|r means, the damage done boni is active (defensive stat > offensive stat). |cff0000No|r means the opposite.", "ZoFontGame")
    end)
    juggernautLabel:SetHandler("OnMouseExit", function() ZO_Tooltips_HideTextTooltip() end )
    
    local juggernautIndicator = WM:CreateControl( addonName.."juggernautIndicator", ctrl, CT_LABEL) 
    juggernautIndicator:ClearAnchors() 
    juggernautIndicator:SetAnchor(LEFT, juggernautLabel, RIGHT, 5, 0 ) 
    juggernautIndicator:SetFont("ZoFontGame")
    addonUI.UpdateJuggernautIndicator = function() 
        local offStat = CalcOffensiveMetric() 
        local deffStat = CalcDefensiveMetric()
        if offStat > deffStat then 
            juggernautIndicator:SetColor(1,0,0,1) 
            juggernautIndicator:SetText("NO")
        elseif offStat < deffStat then 
            juggernautIndicator:SetColor(0,1,0,1) 
            juggernautIndicator:SetText("YES")
        else 
            juggernautIndicator:SetColor(1,1,0,1) 
            juggernautIndicator:SetText("IDK")
        end
    end

    --[[
    local dmgDoneLabel = WM:CreateControl( addonName.."dmgDoneLabel", ctrl, CT_LABEL) 
    dmgDoneLabel:ClearAnchors() 
    dmgDoneLabel:SetAnchor(TOPLEFT, juggernautLabel, BOTTOMLEFT, 0, 0 ) 
    dmgDoneLabel:SetFont("ZoFontGame")
    dmgDoneLabel:SetColor(1,1,1,1) 
    dmgDoneLabel:SetText("Damage Done Boni: ")
    
    local dmgDoneValue = WM:CreateControl( addonName.."dmgDoneValue", ctrl, CT_LABEL) 
    dmgDoneValue:ClearAnchors() 
    dmgDoneValue:SetAnchor(LEFT, dmgDoneLabel, RIGHT, 5, 0 ) 
    dmgDoneValue:SetFont("ZoFontGame")
    dmgDoneValue:SetColor(1,1,1,1) 
    addonUI.UpdateCurrentDmgDoneBoni = function() 
        local offStat = CalcOffensiveMetric() 
        local deffStat = CalcDefensiveMetric()
        if offStat > deffStat then 
            dmgDoneValue:SetText( "0%" ) 
        elseif offStat < deffStat then 
            local dmgDoneInstanz = CalcTheoreticalDmgBoni()
            local currentDmgDone = 3*dmgDoneInstanz
            dmgDoneValue:SetText(string.format("%.1f%%", currentDmgDone))
        else 
            dmgDoneValue:SetColor(1,1,0,1) 
            dmgDoneValue:SetText("IDK")
        end
    end
    ]]

end



local function OnUpdate() 
    addonUI.UpdateTheoreticalDmgBoniValue()
    addonUI.UpdateOffensiveMetricValue()
    addonUI.UpdateDefensiveMetricValue()
    addonUI.UpdateJuggernautIndicator()
end





local function Initialize() 
    sv = ZO_SavedVars:NewAccountWide( "ExoYsJuggernautificatorSavedVariables" , 0, nil, {x=600, y=600} )
    BuildUI()
    EM:RegisterForUpdate(addonName, 500, OnUpdate)
end


local function OnAddonLoaded(_, loadedAddon) 
    if loadedAddon == addonName then 
        EM:UnregisterForEvent(addonName, EVENT_ADD_ON_LOADED) 
        Initialize()
    end
end
EM:RegisterForEvent(addonName, EVENT_ADD_ON_LOADED, OnAddonLoaded)