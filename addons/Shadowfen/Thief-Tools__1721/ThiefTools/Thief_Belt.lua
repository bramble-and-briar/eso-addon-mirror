local SF = LibSFUtils

local TT = ThiefTools

local L = GetString
local ZOS_addSystemMsg = CHAT_SYSTEM.AddMessage

local logDebug = TT.logDebug

local SF_Color = SF.SF_Color
local rgb = SF.rgb

-- ----------------------------------------------------
--[[ Defines the ThiefTools belt controls and their default presentation settings.

    Each entry specifies the control's name, horizontal spacing, label spacing,
    initial label text, icon texture, icon color, and tooltip description.
    The control definitions are consumed by make_control() to create the UI
    elements and by TT:UpdateControls() to position, display, and color them.

    Fields:
        name        - Unique control name used to identify its icon, label, and
                    visibility setting.
        offset      - Horizontal spacing, scaled by the display scale, between
                    this control's icon and the preceding visible label.
        labelOffset - Horizontal spacing between the icon and its text label.
        text        - Initial or measurement text for the label.
        showText    - Flag of whether or not to show text on the belt.
        texture     - ESO texture path for the control icon.
        color       - Default icon color, using an SF.rgb color value.
        tooltip     - Description intended for the control's tooltip. (TBD)

    Control order:
        Kill          - Attack-innocents indicator.
        Loot          - Automatic-stealing indicator.
        Value         - Total value of stolen items.
        SellsLeft     - Remaining fence transactions.
        LaundersLeft  - Remaining laundering transactions.
        FenceTimer    - Fence timer.
        BountyTimer   - Bounty timer.
        Bounty        - Current bounty.
        ClemencyTimer - Clemency availability timer.
        Average       - Average item value.
        Estimate      - Estimated total stolen-item value.
        Quality       - Item quality summary.

--]]
local controls = {
    {
        name = "Kill",
        offset = 0,
        labelOffset = 8,
        text = " ",
        showText = false,
        texture = "/esoui/art/floatingmarkers/darkbrotherhood_target.dds",
        color = rgb.red,
        tooltip = L(TT_BELT_KILL),
    },
    {
        name = "Loot",
        offset = 10,
        labelOffset = 4,
        text = " ",
        showText = false,
        texture = "/esoui/art/icons/item_generic_coinbag.dds",
        color = rgb.superior,
        tooltip = L(TT_BELT_AUTOLOOT),
        fas_integ = true,
    },
    {
        name = "Value",
        offset = 10,
        labelOffset = 8,
        text = "0000000",
        showText = true,
        texture = "/esoui/art/tutorial/guildstore_sell_tabicon_up.dds",
        color = rgb.gold,
        tooltip = L(TT_BELT_VALUE),
    },
    {
        name = "SellsLeft",
        offset = 10,
        labelOffset = 4,
        text = "000/000",
        showText = true,
        texture = "/esoui/art/inventory/inventory_stolenitem_icon.dds",
        color = rgb.purple,
        tooltip = L(TT_BELT_FENCE_REMAINS),
    },
    {
        name = "LaundersLeft",
        offset = 10,
        labelOffset = 4,
        text = "000/000",
        showText = true,
        texture = "/esoui/art/vendor/vendor_tabicon_sell_down.dds",
        color = rgb.red,
        tooltip = L(TT_BELT_LAUNDER_REMAINS),
    },
    {
        name = "FenceTimer",
        offset = 10,
        labelOffset = 4,
        text = "00:00:00",
        showText = true,
        texture = "/esoui/art/miscellaneous/gamepad/gp_icon_timer32.dds",
        color = rgb.bronze,
        tooltip = L(TT_BELT_FENCE_TIMER),
    },
    {
        name = "BountyTimer",
        offset = 10,
        labelOffset = 4,
        text = "00:00:00",
        showText = true,
        texture = "/esoui/art/miscellaneous/gamepad/gp_icon_timer32.dds",
        color = rgb.red,
        tooltip = L(TT_BELT_BOUNTY_TIMER),
    },
    {
        name = "Bounty",
        offset = 10,
        labelOffset = 8,
        text = "0000000",
        showText = true,
        texture = "/esoui/art/currency/currency_gold.dds",
        color = rgb.red,
        tooltip = L(TT_BELT_CURRENT_BOUNTY),
    },
    {
        name = "ClemencyTimer",
        offset = 10,
        labelOffset = 4,
        text = "00:00:00",
        showText = true,
        texture = "/esoui/art/miscellaneous/gamepad/gp_icon_timer32.dds",
        color = rgb.fine,
        tooltip = L(TT_BELT_CLEMENCY_TIMER),
    },
    {
        name = "Average",
        offset = 10,
        labelOffset = 6,
        text = "0000.00",
        showText = true,
        texture = "/esoui/art/crafting/smithing_tabicon_improve_up.dds",
        color = rgb.superior,
        tooltip = L(TT_BELT_AVE_VALUE),
    },
    {
        name = "Estimate",
        offset = 10,
        labelOffset = 6,
        text = "0000000",
        showText = true,
        texture = "/esoui/art/vendor/vendor_tabicon_sell_down.dds",
        color = rgb.legendary,
        tooltip = L(TT_BELT_EST_VALUE),
    },
    {
        name = "Quality",
        offset = 10,
        labelOffset = 8,
        text = "0.00",
        showText = true,
        texture = "/esoui/art/crafting/smithing_tabicon_improve_up.dds",
        color = rgb.normal,
        tooltip = L(TT_BELT_QUALITY),
    },
}

-- TTFAS_isEnabled() returns a boolean from the TTFAS addon (when available)
local function isTTFASenabled()
    return TTFAS_isEnabled and TTFAS_isEnabled()
end

--[[ Attaches a tooltip to a belt control.

    Displays the specified tooltip when the mouse enters the control
    and clears it when the mouse leaves.
--]]
local function addTooltip(control, tooltipText)
    if not control or not tooltipText then return end

    control:SetMouseEnabled(true)

    control:SetHandler("OnMouseEnter", function(self)
        InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -5)
        SetTooltipText(InformationTooltip, tooltipText)
    end)

    control:SetHandler("OnMouseExit", function()
        ClearTooltip(InformationTooltip)
    end)
end

--[[ Attaches a dynamic tooltip to an Auto Steal belt control.

    Reads the tooltip text from the Loot control definition whenever
    the mouse enters, allowing colorAutoLootIcon() to change the
    tooltip without reinstalling the handler.
--]]
local function addAutoLootTooltip(control, autolootctl)
    if not control then return end

    control:SetMouseEnabled(true)

    control:SetHandler("OnMouseEnter", function(self)
        InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -5)
        SetTooltipText(InformationTooltip, autolootctl.tooltip)
    end)

    control:SetHandler("OnMouseExit", function()
        ClearTooltip(InformationTooltip)
    end)
end


--[[ Updates the Loot control definition's icon color to indicate which
    automatic-stealing mode is active:
        Bronze   - ThiefTools automatic stealing is enabled.
        Superior - Thief Framework Auto Steal (TTFAS) is enabled.
        Junk     - Neither automatic-stealing mode is enabled.

    Sets the color field on the supplied control definition.

    @param autolootctl (table) The Loot control definition to update.
--]]
local function colorAutoLootIcon(autolootctl)
    if not autolootctl then return end

    local color
    local tooltip

    if TT.options.chartt.autoSteal then
        -- ThiefTools auto-steal enabled.
        color = rgb.bronze
        tooltip = L(TT_BELT_AUTOLOOT)

    elseif isTTFASenabled() then
        -- Thief Framework Auto Steal enabled.
        color = rgb.superior
        tooltip = L(TT_BELT_FAS_AUTOLOOT)

    else
        -- Neither auto-steal mode is enabled.
        color = rgb.junk
        tooltip = L(TT_BELT_NOAUTOLOOT)
    end

    -- Update the control definition.
    autolootctl.color = color
    autolootctl.tooltip = tooltip

    -- Update the existing icon.
    local win = TT.window
    local icon = win and win["icon_loot"]

    if icon then
        icon:SetColor(SF_Color.UnpackRGBA(color))
    end

end

--[[ Creates an icon and text label for a configured ThiefTools UI control.

    Creates the icon using the control's texture, dimensions, and configured color,
    then anchors it horizontally relative to the preceding control or the window
    background when no preceding control is supplied. Creates and configures the
    label, anchoring it to the right of the icon with a scale-adjusted label offset.

    Stores references to the icon and label on TT.window using lowercase control
    names, matching the naming convention expected by TT:UpdateControls().

    Parameters:
        control - Control definition containing:
            name        - Control name used to identify its UI elements.
            texture     - Icon texture path.
            offset      - Horizontal spacing after the preceding control.
            labelOffset - Horizontal spacing between the icon and label.
            text        - Initial label text.
            color       - Optional icon color in the format expected by
                        SF_Color.UnpackRGBA().
            tooltip     - Optional tooltip description; not used by this function.
        rel - The preceding label used to position this control's icon, or nil
            to anchor the icon to the window background.

    Returns:
        The newly created label, for use as the relative control when creating
        the next control.
--]]
local function make_control(control, rel)
    local WM = WINDOW_MANAGER
    local w = TT.window
    local display = TT.options.display
    local scale = display.scale
    local name = control.name
    local bg = w.bg
    local pixel2UI = GetUIGlobalScale()


    logDebug("making control for ", name)

    -- Icon creation
    local icon = WM:CreateControl(TT.name .. "Icon" .. name, bg, CT_TEXTURE)
    icon:SetTexture(control.texture)
    icon:SetDimensions(24, 24)

    if rel then
        icon:SetAnchor(LEFT, rel, RIGHT, control.offset * scale, 0)
    else
        icon:SetAnchor(LEFT, w.bg, LEFT, display.border, 0)
    end

    -- special handling of autoloot for ThiefTools vs TTFAS autolooting
    if control.name == "Loot" then
        colorAutoLootIcon(control)     -- changes certain control settings
    end

    -- create this to make icon hover work for tooltips
    local hit = WM:CreateControl(TT.name .. "IconHit" .. name, bg, CT_CONTROL)
    hit:SetDimensions(24, 24)
    hit:SetAnchorFill(icon)
    hit:SetMouseEnabled(true)

    -- Label creation
    local label = WM:CreateControl(TT.name .. "Label" .. name, bg, CT_LABEL)
    label:SetFont("ZoFontGame")
    label:SetAnchor(LEFT, icon, RIGHT,
        math.min(control.labelOffset, scale * control.labelOffset), 0)
    label:SetText(control.text)
    label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

    -- Measure the configured placeholder text without the previous
    -- width constraining the measurement.
    label:SetWidth(0)
    label:SetText(control.showText and control.text or " ")

    local labelWidth = (label:GetStringWidth(control.showText and control.text or " ")/pixel2UI) * math.min(1.0, scale)

    label:SetWidth(labelWidth)
    label:SetText(text)

    -- Store controls using the names expected by UpdateControls().
    local lowerName = string.lower(name)
    w["icon_" .. lowerName] = icon
    w["l_" .. lowerName] = label
    w["hit_" .. lowerName] = hit

    if name == "Loot" then
        addAutoLootTooltip(hit, control)
        addAutoLootTooltip(label, control)
    else
        addTooltip(hit, control.tooltip)
        addTooltip(label, control.tooltip)
    end
    return label
end

--[[ Creates the six item-quality indicator bars for the ThiefTools belt.

    Each bar is an 8-pixel-wide texture anchored horizontally after the previous
    control, starting at the supplied relative control. Bars are initially created
    with zero height; their heights are updated elsewhere to represent the
    distribution of stolen item qualities.

    Parameters:
        rel - The control to which the first bar is anchored.

    Stores the created bars in TT.window.bar, indexed by quality:
        [0] Junk       (grey)
        [1] Normal     (white)
        [2] Fine       (green)
        [3] Superior   (blue)
        [4] Epic       (purple)
        [5] Legendary  (yellow)
--]]
local function make_bars(rel)
    local WM = WINDOW_MANAGER
    local w = TT.window
    local last_bar = rel

    local  make_bar = function(name, rgbc, offsetx, offsety)
        offsetx = offsetx or 0
        offsety = offsety or 0
        local bar = WM:CreateControl(TT.name  .. "WindowBar" .. name, w.bg, CT_TEXTURE)
        bar:SetAnchor(BOTTOMLEFT, last_bar, BOTTOMRIGHT, 4+offsetx, offsety)
        bar:SetDimensions(8, 0)
        bar:SetColor(SF_Color.UnpackRGBA(rgbc))
        last_bar = bar
        return bar
    end

   w.bar = {}
   w.bar[0] = make_bar("0", rgb.junk, 4, -4) -- Grey   / Junk
   w.bar[1] = make_bar("1", rgb.normal)      -- White  / Normal
   w.bar[2] = make_bar("2", rgb.fine)        -- Green  / Fine
   w.bar[3] = make_bar("3", rgb.superior)    -- Blue   / Superior
   w.bar[4] = make_bar("4", rgb.epic)        -- Purple / Epic
   w.bar[5] = make_bar("5", rgb.legendary)   -- Yellow / Legendary
end



--[[ Updates the dynamic visibility state of the Auto Steal (Loot) control.
    The control is shown when either ThiefTools automatic stealing is enabled
    or Thief Framework Auto Steal (TTFAS) is enabled.

    Also updates the control's icon color to reflect the active stealing mode.
    Mutates TT.dshow in place; does not replace the dynamic visibility table.
--]]
function TT.shouldShowAutoSteal()
    TT.dshow.Loot = TT.options.chartt.autoSteal
        or isTTFASenabled()
    --TT.dshow.Loot = true
end


--[[ Creates and initializes the belt's controls.

    Creates the icons and labels defined in controls, followed by the
    quality bars. Establishes their parent relationships and then
    initializes their visibility, layout, and appearance.

    Does nothing if the controls have already been created for the
    current window.
--]]
function TT:InitializeBelt()
    local win = TT.window
    if not win then return end
    if TT.beltWindow == win then return end

    local bg = win.bg
    local last

    -- Create icons and labels in display order.
    for _, control in ipairs(controls) do
        last = make_control(control, last)
    end

    -- Create quality bars relative to the final label.
    make_bars(last)

    -- All controls are initially created with bg as their parent.
    -- Record which window owns these controls.
    TT.beltWindow = win

    -- Apply initial visibility, layout, and styling.
    self:UpdateControls()
end

--[[ Updates the visibility, layout, and appearance of existing belt
    controls.

    Updates dynamic visibility states, label sizing, icon colors,
    control anchors, quality-bar visibility, and background appearance.

    Does not create controls or change their parent relationships.
    InitializeBelt() must be called before this function.

    @return nil
--]]
function TT:UpdateControls()
    local win = TT.window
    if not win or TT.beltWindow ~= win then return end

    local options = TT.options
    local display = options.display
    local show = options.show
    local dynamicEnabled = options.dshow
    local dynamicState = TT.dshow
    local bg = win.bg

    local scale = display.scale
    local border = display.border
    local min = math.min
    local unpackRGBA = SF_Color.UnpackRGBA

    -- Background appearance.
    local alpha = show.Background == true and 1 or 0
    bg:SetCenterColor(0, 0, 0, alpha)
    bg:SetEdgeColor(0, 0, 0, alpha)

    -- Control 1: Attack Innocents (Kill).
    local safeInnocents = GetSetting(SETTING_TYPE_COMBAT,
        COMBAT_SETTING_PREVENT_ATTACKING_INNOCENTS)
    dynamicState.Kill = safeInnocents == "0"

    -- Control 2: Auto Steal (Loot).
    TT.shouldShowAutoSteal()
    colorAutoLootIcon(controls[2])

    -- Update existing controls.
    local last
    for _, control in ipairs(controls) do
        local name = control.name
        local lowerName = string.lower(name)
        local icon = win["icon_" .. lowerName]
        local label = win["l_" .. lowerName]

        local enabled = show[name]
            and (not dynamicEnabled[name] or dynamicState[name])

        label:SetHidden(not enabled)
        if icon then
            icon:SetHidden(not enabled)
        end

        if enabled then
            label:ClearAnchors()

            -- Measure the configured label text.
            local text = control.showText and label:GetText() or " "
            label:SetText(text)

            local labelWidth = label:GetTextWidth() * min(1.0, scale)
            label:SetWidth(labelWidth)

            -- Measure the configured label text.
            --[[local text = label:GetText()

            if control.showText then
                label:SetText(control.text)
            else
                label:SetText(" ")
            end
            

            local labelWidth = label:GetTextWidth() * min(1.0, scale)
            --]]
            label:SetDimensionConstraints(labelWidth, 0, 0, 0)
            label:SetText(text)
            label:SetDimensionConstraints(0, 0, 0, 0)
            --label:SetWidth(labelWidth)

            if icon then
                icon:ClearAnchors()

                -- Apply the current control color.
                if control.name ~= "Loot" and control.color then
                    icon:SetColor(unpackRGBA(control.color))
                end

                -- Position the icon after the preceding enabled label.
                if last then
                    icon:SetAnchor(LEFT, last, RIGHT, control.offset * scale, 0)
                else
                    icon:SetAnchor(LEFT, bg, LEFT, border, 0)
                end

                label:SetAnchor(LEFT, icon, RIGHT,
                    min(control.labelOffset, scale * control.labelOffset),0)
            end

            last = label
        end
    end

    -- Quality bars remain parented to bg; only visibility and anchors
    -- are updated.
    local barsVisible = last ~= nil and show.QualityBars == true
    for i = 0, 5 do
        win.bar[i]:SetHidden(not barsVisible)
    end

    if barsVisible then
        win.bar[0]:ClearAnchors()
        win.bar[0]:SetAnchor(BOTTOMLEFT, last, BOTTOMRIGHT, 4 * scale, -4 * scale)
    end
end

--[[ Updates the visibility of the ThiefTools display window.

    Determines whether the display should be hidden based on the
    current game scene, whether the player is in a justice area, and
    the user's display and thief-status settings.

    The display is hidden when the applicable visibility conditions
    are met; otherwise, it is shown.

    This function reads the current ThiefTools options and game state
    and updates the display window accordingly.

	Returns:
		boolean		is the belt currently supposed to be displayed
--]]
function TT:UpdateDisplay()
    local w = TT.window
	if not w then return false end

    local shouldDisplay = TT:ShouldDisplayBelt()
    w:SetHidden(not shouldDisplay)

    -- Only update displayed values when the belt is visible.
    if not shouldDisplay then return false end

    -- aliases
    local options = TT.options
    local showLaunders = options.show.LaundersLeft
    local fenceCount = TT.fenceCount
    local totalQual = TT.totalQual
    local quality = TT.quality
    local bars = w.bar

	-- only do this part when visible
	local totalSells, sellsUsed = GetFenceSellTransactionInfo()
	local totalLaunders, laundersUsed = GetFenceLaunderTransactionInfo()
	local sellsLeft = totalSells - sellsUsed
	local laundersLeft = totalLaunders - laundersUsed
	local totFenceValue = TT.totalValue

	w.l_sellsleft:SetText(string.format("%d/%d", fenceCount, sellsLeft))
	if showLaunders then
		w.l_laundersleft:SetText(string.format("%d/%d", TT.launderCount, laundersLeft))

	else
		w.l_laundersleft:SetText("")
	end

	w.l_value:SetText(string.format("%d", totFenceValue))
	w.l_bounty:SetText(string.format("%d", GetReducedBountyPayoffAmount()))

    local average = 0
    local estimate = 0
    local averageQuality = 0

    if fenceCount > 0 then
        average = totFenceValue / fenceCount
        estimate = math.floor(average) * sellsLeft
        averageQuality = totalQual / fenceCount
    end

    w.l_average:SetText(string.format("%.2f", average))
    w.l_estimate:SetText(string.format("%d", estimate))
    w.l_quality:SetText(string.format("%.2f", averageQuality))

	-- quality bars
    local barScale = fenceCount > 0 and (14 / fenceCount) or 0

	for i = 0, 5 do
        local height = 0

        if barScale > 0 then
            local count = quality[i]
            if count and count > 0 then
                height = math.max(1, count * barScale)
            end
        end

        bars[i]:SetHeight(height)
	end
	return true
end

--[[ Creates and initializes the ThiefTools belt.

    Creates a movable, screen-clamped top-level window at the saved display
    position, then creates its background, configured controls, and item-quality
    indicator bars. The window is initially hidden when the display's hidden
    setting is enabled or the character is configured as not being a thief.

    After creating the controls, calculates the current stolen-goods statistics,
    updates control visibility and layout, and refreshes the displayed values.
    Applies the configured display scale and locks the window according to the
    current settings.

    Stores the top-level window in TT.window and its background in TT.window.bg.

    Note:
        This function creates a new window each time it is called. Call it only
        once when the UI needs to be initialized, unless repeated creation is handled
        elsewhere.
--]]
function TT:BuildUI()
    local WM = WINDOW_MANAGER
    local options = TT.options
    local display = options.display
    local chartt = options.chartt

    local border = display.border
    local anchor = TOPLEFT

    -- Top-level window
    local w = WM:CreateTopLevelWindow(TT.name .. "Window")

    w:SetHidden(not TT:ShouldDisplayBelt())
    w:SetMovable(true)
    w:SetMouseEnabled(true)
    w:SetClampedToScreen(true)
    w:SetClampedToScreenInsets(4, 4, -4, -4)
    w:SetAnchor(anchor, GuiRoot, anchor, display.offsetx, display.offsety)
    w:SetHandler("OnMoveStop", TT.SavePosition)
    w:SetResizeToFitDescendents(true)
    w:SetScale(display.scale)

    TT.window = w

    -- Background
    local bg = WM:CreateControl(TT.name .. "WindowBG", w, CT_BACKDROP)
    w.bg = bg

    bg:SetMouseEnabled(true)
    bg:SetEdgeTexture("/esoui/art/chatwindow/chat_bg_edge.dds",
        256, 256, border)
    bg:SetCenterTexture("/esoui/art/chatwindow/chat_bg_center.dds")
    bg:SetInsets(border, border, -border, -border)
    bg:SetAnchor(BOTTOMLEFT, w, BOTTOMLEFT, 0, 0)
    bg:SetResizeToFitDescendents(true)
    bg:SetResizeToFitPadding(border * 2, border)

    -- Controls
    logDebug("BuildUI - initializing belt")
    TT:InitializeBelt()

    TT:CalcStolenGoods()    -- changes belt values
    TT:UpdateControls()
    TT:UpdateDisplay()

    w:SetScale(display.scale)

    TT:lockWindow()
end

--[[ Saves the current position of the ThiefTools display window.

    Reads the window's left and top coordinates, clamps negative or missing
    coordinates to zero, and stores the resulting position in the display
    settings as offsetx and offsety.

    Returns:
        Nothing. Does nothing if the display window does not exist.
--]]
function TT.SavePosition()
    local win = TT.window
    if not win then return end

    local x = math.max(0, win:GetLeft() or 0)
    local y = math.max(0, win:GetTop() or 0)

	local display = TT.options.display
    display.offsetx = x
    display.offsety = y
end

--[[ Resets the saved position of the ThiefTools display window.

    Sets the horizontal and vertical display offsets to zero. Does not
    immediately reposition the window; the new offsets take effect when
    the window position is next applied.

    Returns:
        Nothing.
--]]
function TT:ResetPosition()
	local display = TT.options.display
   	display.offsetx = 0
   	display.offsety = 0
end

