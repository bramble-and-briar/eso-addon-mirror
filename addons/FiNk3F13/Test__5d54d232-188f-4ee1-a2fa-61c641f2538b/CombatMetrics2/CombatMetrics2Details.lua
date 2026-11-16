-- Native gamepad text layouts in a bounded, independently scrolling panel.
local C=CMX2.Controller

function C.CreateDetailStyles(width)
    local styles={}
    for name,original in pairs(ZO_TOOLTIP_STYLES) do
        if type(original)=="table" then
            local copy={}
            for key,value in pairs(original) do
                if key=="fontSize" then
                    value=math.min(tonumber(tostring(value):match("%d+")) or 22,24)
                elseif key=="width" and type(value)=="number" then
                    value=math.min(value,width)
                elseif type(key)=="string" and (key=="customSpacing" or key=="childSpacing" or key:match("^padding")) and type(value)=="number" then
                    value=math.min(value,12)
                end
                copy[key]=value
            end
            styles[name]=copy
        else styles[name]=original end
    end
    styles.tooltip.width=width
    styles.tooltip.fontSize=22
    styles.title.fontSize=26
    styles.title.uppercase=false
    styles.bodyDescription.fontSize=22
    if styles.statValuePair then styles.statValuePair.height=28 end
    for _,name in ipairs({"conditionOrChargeBar","championSkillBar"}) do
        if styles[name] then styles[name].height=12;styles[name].customSpacing=8 end
    end
    return styles
end

function C.InitializeDetails()
    if SI_COMBAT_METRICS2_EDIT_TITLE then
        SafeAddString(SI_COMBAT_METRICS2_EDIT_TITLE,"Auswählen: Kampfnamen bearbeiten",100)
    end
    C.detailWindow=CombatMetrics2_ConsoleDetails
    C.detailScroll=C.detailWindow:GetNamedChild("Content")
    C.detailFooter=C.detailWindow:GetNamedChild("Footer")
    C.detailStyles=C.CreateDetailStyles(360)
    ZO_ScrollTooltip_Gamepad:Initialize(C.detailScroll,C.detailStyles)
    -- The report owns the sticks; R3 explicitly switches their scroll target.
    C.detailScroll:SetInputEnabled(false)
end

function C.RefreshDetailFooter()
    if C.detailFooter then
        C.detailFooter:SetText(C.detailScrolling and "Rechter Stick: Details\nR3: zurück zur Liste"
            or "R3: Details scrollen\nRechter Stick: Liste")
    end
end

function C.HideDetails()
    C.detailGeneration=(C.detailGeneration or 0)+1
    C.detailVisible=false
    C.detailScrolling=false
    if C.detailWindow then
        C.detailWindow:SetHidden(true)
        C.detailScroll:ClearLines()
    end
end

function C.GetDetailBounds()
    local report=CombatMetrics2_Report
    return math.max(24,report:GetLeft()+16),math.max(24,report:GetTop()+64),
        math.min(GuiRoot:GetWidth()-24,report:GetRight()-16),
        math.min(GuiRoot:GetHeight()-80,report:GetBottom()-28)
end

function C.ShowDetail(kind,value,extra)
    if not C.detailWindow then return false end
    C.detailGeneration=(C.detailGeneration or 0)+1
    local generation=C.detailGeneration
    C.detailScroll:ClearLines()
    C.detailScrolling=false
    local boundLeft,boundTop,boundRight,boundBottom=C.GetDetailBounds()
    local availableWidth,availableHeight=boundRight-boundLeft,boundBottom-boundTop
    if availableWidth<100 or availableHeight<100 then return false end
    local width=math.min(400,math.max(260,availableWidth*0.32),availableWidth)
    local maxHeight=math.min(kind=="item" and 460 or kind=="ability" and 320 or kind=="champion" and 280 or 180,availableHeight)
    C.detailStyles.tooltip.width=width-24
    local tip=C.detailScroll.tooltip
    tip:SetStyles(tip:GetStyle("tooltip"))
    if kind=="item" then
        tip:LayoutItem(value)
    elseif kind=="ability" then
        tip:LayoutSimpleAbility(value)
        tip:AddLine("ID: " .. tostring(value),tip:GetStyle("bodyDescription"))
        if extra then tip:AddLine(extra,tip:GetStyle("bodyDescription")) end
    elseif kind=="text" then
        tip:AddLine(value,tip:GetStyle("title"))
        if extra then tip:AddLine(extra,tip:GetStyle("bodyDescription")) end
    elseif kind=="champion" then
        local points=tonumber(extra and extra.points) or 0
        tip:AddLine(GetChampionSkillName(value),tip:GetStyle("title"))
        tip:AddLine(string.format("%d Punkte | %s",points,extra and extra.slotted and "Eingesetzt" or "Nicht eingesetzt"),tip:GetStyle("bodyDescription"))
        tip:AddLine(GetChampionSkillDescription(value,points),tip:GetStyle("bodyDescription"))
        local bonus=GetChampionSkillCurrentBonusText(value,points)
        if bonus and bonus~="" then tip:AddLine(bonus,tip:GetStyle("bodyDescription")) end
    else
        return false
    end
    local focused=C.focused
    local x,y
    if focused then x,y=focused:GetCenter() end
    if not x then x,y=GuiRoot:GetWidth()/2,GuiRoot:GetHeight()/2 end
    local left=math.max(boundLeft,boundRight-width)
    local function place(height)
        local top=math.max(boundTop,math.min(y-80,boundBottom-height))
        C.detailWindow:SetDimensions(width,height)
        C.detailWindow:ClearAnchors()
        C.detailWindow:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,left,top)
    end
    place(maxHeight)
    C.detailVisible=true
    C.RefreshDetailFooter()
    C.detailWindow:SetHidden(false)
    -- Short enchantment/CP descriptions should not leave a tall empty panel.
    -- Long item descriptions keep a bounded viewport and remain scrollable.
    zo_callLater(function()
        if generation~=C.detailGeneration or not C.detailVisible then return end
        local contentHeight=C.detailScroll.scrollChild:GetHeight()
        place(math.min(maxHeight,math.max(100,contentHeight+72)))
    end,1)
    return true
end

function C.ToggleDetailsScroll()
    if not C.detailVisible then return end
    C.detailScrolling=not C.detailScrolling
    C.RefreshDetailFooter()
end

function C.ScrollDetails(direction)
    ZO_ScrollRelative(C.detailScroll,-direction*10)
end
