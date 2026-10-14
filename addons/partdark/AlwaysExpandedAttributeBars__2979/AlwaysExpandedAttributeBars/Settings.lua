local AEAB = AEAB or {}
AEAB.name = "AlwaysExpandedAttributeBars"
AEAB.version = "4.0 u51"
AEAB.APPLY_DELAY_MS = 50 -- Delay before applying settings after player activation

-- Available font faces and shadow/outline styles
local FONT_FACES = {
    "$(MEDIUM_FONT)",                -- Default ESO medium font (Univers57)
    "$(BOLD_FONT)",                  -- Bold font (Univers67)
    "$(ANTIQUE_FONT)",               -- Antique/serif font
    "$(HANDWRITTEN_FONT)",           -- Handwritten font
    "$(CHAT_FONT)",                  -- Chat font
    "EsoUI/Common/Fonts/Univers57.otf",
    "EsoUI/Common/Fonts/Univers67.otf",
    "EsoUI/Common/Fonts/UniversCondensed.otf",
    "EsoUI/Common/Fonts/TrajanPro-Regular.otf",
    "EsoUI/Common/Fonts/TrajanPro-Bold.otf",
    "EsoUI/Common/Fonts/Handwritten.otf",
}

local FONT_STYLES = {
    "none",
    "soft-shadow-thin",
    "soft-shadow-thick",
    "soft-shadow-thickest",
    "hard-shadow",
    "outline",
    "outline-thin",
    "outline-thick",
}

local FONT_STYLE_SET = {}
for _, style in ipairs(FONT_STYLES) do
    FONT_STYLE_SET[style] = true
end

-- Default settings with standard ESO colors
AEAB.defaults = {
    healthColor = {0.901, 0.196, 0.164, 1},     -- Standard ESO health red
    magickaColor = {0.176, 0.568, 0.929, 1},    -- Standard ESO magicka blue
    staminaColor = {0.513, 0.772, 0.254, 1},    -- Standard ESO stamina green
    shieldColor = {0.368, 0.439, 0.909, 1},     -- Standard ESO shield blue
    useCustomHealthColor = false,  -- Use custom color for health bar
    useCustomMagickaColor = false, -- Use custom color for magicka bar
    useCustomStaminaColor = false, -- Use custom color for stamina bar
    useCustomShieldColor = false,  -- Use custom color for shield
   -- playerBarGradient = 'red',     -- Player health bar gradient: 'red' (stock) or 'blue'
    blueForFriendlyPlayers = false, -- Target bar: friendly players get the light blue color instead of the standard red
    
    -- Font settings
    fontFace = "$(MEDIUM_FONT)",   -- Default font face
    fontSize = 16,                 -- Default font size
    fontStyle = "soft-shadow-thick", -- Default font style (shadow/outline)
    
    -- Bar size settings
    barWidth = 323,                -- Legacy bar width (fallback when the separate sizes are not set)
    barHeight = 25,                -- Legacy bar height (fallback when the separate sizes are not set)
    healthBarWidth = 323,          -- Health bar width
    healthBarHeight = 25,          -- Health bar height
    resourceBarWidth = 323,        -- Stamina/Magicka bar width
    resourceBarHeight = 25,        -- Stamina/Magicka bar height
    barGap = 112,                  -- Gap between health and magicka/stamina bars
    repositionBarsOnResize = false, -- Keep the bars centered/evenly spaced on width change (off by default)

    -- Visual effects settings
    disableMaxResourceChangeEffects = false,  -- Disable visual effects when max resource changes

    -- Target attribute bars module
    enableTargetBarsResizer = false,  -- Resize target unit frame attribute bars (module disabled by default)
    targetBarWidth = 360,             -- Target bar width
    targetBarHeight = 18,             -- Target bar height
    targetBarColorByReaction = false, -- Color the target bar by reaction (enemy/neutral/ally/player/self)
    targetEnemyColor = {0.9, 0.2, 0.16, 1},     -- Target bar color: enemy
    targetNeutralColor = {0.87, 0.63, 0.25, 1}, -- Target bar color: neutral
    targetAllyColor = {0.42, 0.68, 0.24, 1},    -- Target bar color: ally
    targetPlayerColor = {1.0, 1.0, 1.0, 1},     -- Target bar color: yourself
    targetPlayerCharacterColor = {0.36, 0.58, 0.93, 1}, -- Target bar color: other player characters
    targetColorSource = "custom",      -- Target color source: "custom" (picked colors) or "game" (game reaction colors)

    -- Unit frame numbers module (sub-addon, modeled after ImprovedAttributeBars)
    enableUnitNumbersModule = false,          -- Sub-addon: full numbers for player bars and the boss bar (requires reload)
    playerNumberStyle = 'currentmaxpercent',  -- Player bar numbers: 'currentmax', 'currentmaxpercent', 'current', 'percent'
    numbersShowShield = true,                 -- Show damage absorption ([+N]) on the health bar
    numbersShowTrauma = true,                 -- Show heal absorption ([-N]) on the health bar
    bossShowNumbers = true,                   -- Show full numbers on the boss health bar
    bossNumberStyle = 'currentmaxpercent',    -- Boss bar numbers: 'currentmax', 'currentmaxpercent', 'current', 'percent'
    targetShowNumbers = true,                 -- Show full numbers on the target health bar
    targetNumberStyle = 'currentmaxpercent',  -- Target bar numbers: 'currentmax', 'currentmaxpercent', 'current', 'percent'
    numberSeparator = '',                     -- Thousands separator: '' (none), ',', '.', ' ', "'"
    bossNumberSeparator = '',                 -- Boss bar thousands separator: '' (none), ',', '.', ' ', "'"
    xpBarShowNumbers = true,                  -- Show current / required XP (percent) on the level bar
    targetFontFace = "$(BOLD_FONT)",          -- Target frame font face
    targetFontSize = 17,                      -- Target frame font size
    targetFontStyle = "soft-shadow-thick",    -- Target frame font style

    -- Static size / layout behavior
    staticBarSize = true,                     -- Change the player bars to a static (always expanded) size
    showTargetEliteBrackets = true,           -- Show the elite/boss difficulty brackets on the target frame
}

-- Initialize settings
function AEAB:Initialize()
    -- Load saved variables. This must happen on EVENT_ADD_ON_LOADED (not at
    -- module level) so the saved variables file is guaranteed to be loaded.
    self.savedVars = ZO_SavedVars:NewAccountWide("AEABSavedVars", 1, nil, self.defaults)

    -- Apply the static bar template (conditional on the staticBarSize setting)
    if AEAB.ApplyStaticTemplate then
        pcall(AEAB.ApplyStaticTemplate)
    end

    -- Create the settings menu FIRST so an unrelated failure can never hide it
    local ok, err = pcall(function() self:CreateSettingsMenu() end)
    if not ok then
        d("[AEAB] Settings menu error: " .. tostring(err))
    end

    -- Apply settings on load (attribute bars may not exist yet - that's fine)
    pcall(function() self:ApplySettings() end)

    -- Apply all settings once the HUD is fully loaded and on every player activation.
    -- A short delay ensures every attribute bar control exists.
    EVENT_MANAGER:RegisterForEvent(self.name .. "_PlayerActivated", EVENT_PLAYER_ACTIVATED, function()
        zo_callLater(function()
            pcall(function() self:ApplySettings() end)
            if AEAB.AddBorders then
                AEAB:AddBorders()
            end
            if self.savedVars and self.savedVars.disableMaxResourceChangeEffects then
                AEAB.DisableResourceChangeEffects()
            end
        end, AEAB.APPLY_DELAY_MS)
    end)
end

-- Apply settings to attribute bars
function AEAB:ApplySettings()
    local fontStyle = self.savedVars.fontStyle
    if not FONT_STYLE_SET[fontStyle] then fontStyle = "soft-shadow-thick" end
    local fontString = self.savedVars.fontFace .. "|" .. self.savedVars.fontSize .. "|" .. fontStyle
    
    -- Apply settings to all attribute bars
    local function ApplyBarSettings(barControl, useCustomColor, colorTable, isHealth)
        if not barControl then return end
        
        -- Apply font (with a fallback if the chosen style is not supported)
        local resourceNumbers = barControl:GetNamedChild("ResourceNumbers")
        if resourceNumbers then
            local ok, err = pcall(resourceNumbers.SetFont, resourceNumbers, fontString)
            if not ok then
                pcall(resourceNumbers.SetFont, resourceNumbers, self.savedVars.fontFace .. "|" .. self.savedVars.fontSize .. "|soft-shadow-thick")
                d("[AEAB] Invalid font style, reverted to default shadow: " .. tostring(err))
            end
        end
        
        -- Apply the selected gradient to the player health bar (red = stock, blue)
        if isHealth then
            local gradientKey = (self.savedVars.playerBarGradient == 'blue') and COMBAT_MECHANIC_FLAGS_MAGICKA or COMBAT_MECHANIC_FLAGS_HEALTH
            local gradient = ZO_POWER_BAR_GRADIENT_COLORS[gradientKey]
            if gradient then
                local barLeft = barControl:GetNamedChild("BarLeft")
                local barRight = barControl:GetNamedChild("BarRight")
                if barLeft and barRight then
                    ZO_StatusBar_SetGradientColor(barLeft, gradient)
                    ZO_StatusBar_SetGradientColor(barRight, gradient)
                end
            end
        end

        -- Apply color only if custom colors are enabled
        if useCustomColor then
            if isHealth then
                -- Health bar has two parts
                local barLeft = barControl:GetNamedChild("BarLeft")
                local barRight = barControl:GetNamedChild("BarRight")
                if barLeft and barRight then
                    barLeft:SetColor(unpack(colorTable))
                    barRight:SetColor(unpack(colorTable))
                end
            else
                -- Magicka and Stamina have single bar
                local bar = barControl:GetNamedChild("Bar")
                if bar then
                    bar:SetColor(unpack(colorTable))
                end
            end
        end
    end
    
    -- Apply settings to each bar
    ApplyBarSettings(ZO_PlayerAttributeHealth, self.savedVars.useCustomHealthColor, self.savedVars.healthColor, true)
    ApplyBarSettings(ZO_PlayerAttributeMagicka, self.savedVars.useCustomMagickaColor, self.savedVars.magickaColor, false)
    ApplyBarSettings(ZO_PlayerAttributeStamina, self.savedVars.useCustomStaminaColor, self.savedVars.staminaColor, false)
    
    -- Apply custom bar dimensions (only when the static size is enabled)
    if self.savedVars.staticBarSize ~= false and AEAB.ApplyDimensions then
        local ok, err = pcall(AEAB.ApplyDimensions, AEAB)
        if not ok then
            d("[AEAB] ApplyDimensions error: " .. tostring(err))
        end
    end

    -- Enable/disable max resource change effects
    if self.savedVars.disableMaxResourceChangeEffects then
        if AEAB.DisableResourceChangeEffects then
            AEAB.DisableResourceChangeEffects()
        end
    elseif AEAB.EnableResourceChangeEffects then
        AEAB.EnableResourceChangeEffects()
    end
end

-- Legacy function name for compatibility
function AEAB:ApplyColors()
    self:ApplySettings()
end

-- Apply custom bar dimensions (width / height) to all three attribute bars
function AEAB:ApplyDimensions()
    local sv = self.savedVars
    if not sv then return end

    -- Separate sizes: health bar vs. stamina/magicka bars.
    -- Falls back to the legacy barWidth/barHeight when the new values are absent.
    local function Num(value, fallback, default)
        if type(value) == "number" then return value end
        if type(fallback) == "number" then return fallback end
        return default
    end

    local healthWidth    = Num(sv.healthBarWidth, sv.barWidth, 323)
    local healthHeight   = Num(sv.healthBarHeight, sv.barHeight, 25)
    local resourceWidth  = Num(sv.resourceBarWidth, sv.barWidth, 323)
    local resourceHeight = Num(sv.resourceBarHeight, sv.barHeight, 25)
    local gap = sv.barGap or self.defaults.barGap
    if type(gap) ~= "number" then gap = 112 end

    local health = ZO_PlayerAttributeHealth
    local magicka = ZO_PlayerAttributeMagicka
    local stamina = ZO_PlayerAttributeStamina

    -- NOTE: ESO controls support AT MOST TWO anchors per control.
    -- Every control below is therefore set up with exactly two anchors.

    local function StretchChildren(container, width, height)
        if not container then return end

        container:SetDimensions(width, height)

        -- Background fills the container
        local bg = container:GetNamedChild("BgContainer")
        if bg then
            bg:ClearAnchors()
            bg:SetAnchor(TOPLEFT, container, TOPLEFT)
            bg:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT)
        end

        -- Magicka / Stamina: single bar fills the container
        local bar = container:GetNamedChild("Bar")
        if bar then
            bar:ClearAnchors()
            bar:SetAnchor(TOPLEFT, container, TOPLEFT)
            bar:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT)
        end

        -- Health: two halves overlapping slightly at the center so no dark
        -- seam shows through between them. Horizontal edges are anchored;
        -- the height equals the container height (set explicitly).
        local barLeft = container:GetNamedChild("BarLeft")
        local barRight = container:GetNamedChild("BarRight")
        if barLeft then
            barLeft:ClearAnchors()
            barLeft:SetDimensions(barLeft:GetWidth(), height)
            barLeft:SetAnchor(LEFT, container, LEFT)
            barLeft:SetAnchor(RIGHT, container, CENTER, 1)
        end
        if barRight then
            barRight:ClearAnchors()
            barRight:SetDimensions(barRight:GetWidth(), height)
            barRight:SetAnchor(LEFT, container, CENTER, -1)
            barRight:SetAnchor(RIGHT, container, RIGHT)
        end

        -- Frame center spans between the end caps and the full bar height,
        -- so its top/bottom lines run between the caps and never past them
        local frameCenter = container:GetNamedChild("FrameCenter")
        local frameLeft = container:GetNamedChild("FrameLeft")
        local frameRight = container:GetNamedChild("FrameRight")
        if frameCenter then
            frameCenter:ClearAnchors()
            if frameLeft and frameRight then
                frameCenter:SetAnchor(TOPLEFT, frameLeft, TOPRIGHT)
                frameCenter:SetAnchor(BOTTOMRIGHT, frameRight, BOTTOMLEFT)
            else
                frameCenter:SetAnchor(TOPLEFT, container, TOPLEFT)
                frameCenter:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT)
            end
        end

        -- End caps: exactly two anchors each, so they stretch to the bar height
        -- while keeping their own width at the edges of the bar
        local function StretchCap(cap, side)
            if not cap then return end
            local w = cap:GetWidth()
            if type(w) ~= "number" or w <= 0 then w = 16 end
            local maxW = math.max(1, width * 0.15)
            if w > maxW then w = maxW end
            cap:ClearAnchors()
            if side == "left" then
                cap:SetAnchor(TOPLEFT, container, TOPLEFT, -3, 0)
                cap:SetAnchor(BOTTOMRIGHT, container, BOTTOMLEFT, -3 + w, 0)
            else
                cap:SetAnchor(TOPLEFT, container, TOPRIGHT, 3 - w, 0)
                cap:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, 3, 0)
            end
        end

        StretchCap(frameLeft, "left")
        StretchCap(frameRight, "right")
    end

    StretchChildren(health, healthWidth, healthHeight)
    StretchChildren(magicka, resourceWidth, resourceHeight)
    StretchChildren(stamina, resourceWidth, resourceHeight)

    -- Optionally keep the three bars centered and evenly spaced for any width.
    -- Disabled by default so the player can position the bars with the game's
    -- built-in Edit Layout tools without this addon overriding them.
    if sv.repositionBarsOnResize and health then
        if magicka then
            magicka:ClearAnchors()
            magicka:SetAnchor(RIGHT, health, LEFT, -gap)
        end
        if stamina then
            stamina:ClearAnchors()
            stamina:SetAnchor(LEFT, health, RIGHT, gap)
        end
    end
end

-- Create settings menu using LibAddonMenu-2.0
function AEAB:CreateSettingsMenu()
    -- Register the panel only once per session
    if self.settingsMenuCreated then return end
    self.settingsMenuCreated = true

    -- Check if LibAddonMenu exists
    if not LibAddonMenu2 then
        d("[AEAB] LibAddonMenu-2.0 not found - the settings panel cannot be shown")
        return
    end
    
    local panelData = {
        type = "panel",
        name = "Always Expanded Attribute Bars",
        displayName = "Always Expanded Attribute Bars",
        author = "|cFF0000partdark|r, |c0099ffhex|r",
        version = self.version,
        slashCommand = "/aeab",
        registerForRefresh = true,
        registerForDefaults = true,
    }
    
    local optionsPanel = LibAddonMenu2:RegisterAddonPanel(self.name, panelData)
    
    local optionsData = {
        {
            type = "header",
            name = "Health Bar Colors",
        },
        {
            type = "checkbox",
            name = "Use Custom Health Color",
            tooltip = "When enabled, custom colors will be used for the health bar",
            getFunc = function() return self.savedVars.useCustomHealthColor end,
            setFunc = function(value)
                self.savedVars.useCustomHealthColor = value
                self:ApplySettings()
            end,
            requiresReload = true,
            width = "full",
        },
        {
            type = "colorpicker",
            name = "Health Color",
            tooltip = "Set the color of the health bar",
            getFunc = function() return unpack(self.savedVars.healthColor) end,
            setFunc = function(r, g, b, a)
                self.savedVars.healthColor = {r, g, b, a}
                self:ApplySettings()
            end,
            width = "full",
            disabled = function() return not self.savedVars.useCustomHealthColor end,
        },
    --[[    {
            type = "dropdown",
            name = "Health Bar Gradient",
            tooltip = "Choose the gradient tint of the player health bar: red (stock) or blue",
            choices = { "Red", "Blue" },
            getFunc = function()
                if self.savedVars.playerBarGradient == 'blue' then return "Blue" end
                return "Red"
            end,
            setFunc = function(value)
                self.savedVars.playerBarGradient = (value == "Blue") and 'blue' or 'red'
                self:ApplySettings()
            end,
            width = "full",
        },
        ]]
        {
            type = "header",
            name = "Magicka Bar Colors",
        },
        {
            type = "checkbox",
            name = "Use Custom Magicka Color",
            tooltip = "When enabled, custom colors will be used for the magicka bar",
            getFunc = function() return self.savedVars.useCustomMagickaColor end,
            setFunc = function(value)
                self.savedVars.useCustomMagickaColor = value
                self:ApplySettings()
            end,
            requiresReload = true,
            width = "full",
        },
        {
            type = "colorpicker",
            name = "Magicka Color",
            tooltip = "Set the color of the magicka bar",
            getFunc = function() return unpack(self.savedVars.magickaColor) end,
            setFunc = function(r, g, b, a) 
                self.savedVars.magickaColor = {r, g, b, a}
                self:ApplySettings()
            end,
            width = "full",
            disabled = function() return not self.savedVars.useCustomMagickaColor end,
        },
        {
            type = "header",
            name = "Stamina Bar Colors",
        },
        {
            type = "checkbox",
            name = "Use Custom Stamina Color",
            tooltip = "When enabled, custom colors will be used for the stamina bar",
            getFunc = function() return self.savedVars.useCustomStaminaColor end,
            setFunc = function(value)
                self.savedVars.useCustomStaminaColor = value
                self:ApplySettings()
            end,
            requiresReload = true,
            width = "full",
        },
        {
            type = "colorpicker",
            name = "Stamina Color",
            tooltip = "Set the color of the stamina bar",
            getFunc = function() return unpack(self.savedVars.staminaColor) end,
            setFunc = function(r, g, b, a) 
                self.savedVars.staminaColor = {r, g, b, a}
                self:ApplySettings()
            end,
            width = "full",
            disabled = function() return not self.savedVars.useCustomStaminaColor end,
        },
        {
            type = "header",
            name = "Shield Color",
        },
        {
            type = "checkbox",
            name = "Use Custom Shield Color",
            tooltip = "When enabled, custom color will be used for the shield overlay",
            getFunc = function() return self.savedVars.useCustomShieldColor end,
            setFunc = function(value) 
                self.savedVars.useCustomShieldColor = value
                self:ApplySettings()
            end,
            requiresReload = true,
            width = "full",
        },
        {
            type = "colorpicker",
            name = "Shield Color",
            tooltip = "Set the color of the shield overlay",
            getFunc = function() return unpack(self.savedVars.shieldColor) end,
            setFunc = function(r, g, b, a) 
                self.savedVars.shieldColor = {r, g, b, a}
                self:ApplySettings()
            end,
            width = "full",
            disabled = function() return not self.savedVars.useCustomShieldColor end,
        },
        {
            type = "header",
            name = "Health Bar Size",
        },
        {
            type = "slider",
            name = "Health Bar Width",
            tooltip = "Set the width of the health bar (applies immediately)",
            min = 200,
            max = 600,
            step = 1,
            getFunc = function() return self.savedVars.healthBarWidth or self.savedVars.barWidth end,
            setFunc = function(value)
                self.savedVars.healthBarWidth = value
                self:ApplySettings()
            end,
            width = "full",
            disabled = function() return self.savedVars.staticBarSize == false end,
        },
        {
            type = "slider",
            name = "Health Bar Height",
            tooltip = "Set the height of the health bar (applies immediately)",
            min = 10,
            max = 45,
            step = 1,
            getFunc = function() return self.savedVars.healthBarHeight or self.savedVars.barHeight end,
            setFunc = function(value)
                self.savedVars.healthBarHeight = value
                self:ApplySettings()
            end,
            width = "full",
            disabled = function() return self.savedVars.staticBarSize == false end,
        },
        {
            type = "header",
            name = "Stamina / Magicka Bar Size",
        },
        {
            type = "slider",
            name = "Stamina/Magicka Bar Width",
            tooltip = "Set the width of the stamina and magicka bars (applies immediately)",
            min = 200,
            max = 600,
            step = 1,
            getFunc = function() return self.savedVars.resourceBarWidth or self.savedVars.barWidth end,
            setFunc = function(value)
                self.savedVars.resourceBarWidth = value
                self:ApplySettings()
            end,
            width = "full",
            disabled = function() return self.savedVars.staticBarSize == false end,
        },
        {
            type = "slider",
            name = "Stamina/Magicka Bar Height",
            tooltip = "Set the height of the stamina and magicka bars (applies immediately)",
            min = 10,
            max = 45,
            step = 1,
            getFunc = function() return self.savedVars.resourceBarHeight or self.savedVars.barHeight end,
            setFunc = function(value)
                self.savedVars.resourceBarHeight = value
                self:ApplySettings()
            end,
            width = "full",
            disabled = function() return self.savedVars.staticBarSize == false end,
        },
        {
            type = "checkbox",
            name = "Auto-Space Attribute Bars",
            tooltip = "When enabled, the three bars are kept centered and evenly spaced when the width changes. Disable this (default) to position the bars yourself using the game's built-in Edit Layout tools. A reload is required for the change to take effect",
            getFunc = function() return self.savedVars.repositionBarsOnResize end,
            setFunc = function(value)
                self.savedVars.repositionBarsOnResize = value
                self:ApplySettings()
            end,
            requiresReload = true,
            width = "full",
        },
        {
            type = "slider",
            name = "Bar Gap",
            tooltip = "Gap between the health bar and the magicka/stamina bars when Auto-Space Attribute Bars is enabled",
            min = 0,
            max = 400,
            step = 1,
            getFunc = function() return self.savedVars.barGap or 112 end,
            setFunc = function(value)
                self.savedVars.barGap = value
                self:ApplySettings()
            end,
            width = "full",
            disabled = function() return not self.savedVars.repositionBarsOnResize end,
        },
        {
            type = "checkbox",
            name = "Static Bar Size",
            tooltip = "When enabled (default), the attribute bars are changed to a static, always-expanded size using the width and height settings. When disabled, the bars keep the game's default size and shrink/expand behavior. A reload is required",
            getFunc = function() return self.savedVars.staticBarSize ~= false end,
            setFunc = function(value)
                self.savedVars.staticBarSize = value
            end,
            requiresReload = true,
            width = "full",
        },
        {
            type = "header",
            name = "Font Settings",
        },
        {
            type = "dropdown",
            name = "Font Face",
            tooltip = "Select the font face for attribute bar numbers",
            choices = FONT_FACES,
            getFunc = function() return self.savedVars.fontFace end,
            setFunc = function(value) 
                self.savedVars.fontFace = value
                self:ApplySettings()
            end,
            width = "full",
        },
        {
            type = "slider",
            name = "Font Size",
            tooltip = "Set the font size for attribute bar numbers",
            min = 10,
            max = 24,
            step = 1,
            getFunc = function() return self.savedVars.fontSize end,
            setFunc = function(value)
                self.savedVars.fontSize = value
                self:ApplySettings()
            end,
            width = "full",
        },
        {
            type = "dropdown",
            name = "Font Style",
            tooltip = "Select the shadow/outline style for the attribute bar numbers",
            choices = FONT_STYLES,
            getFunc = function() return self.savedVars.fontStyle end,
            setFunc = function(value)
                self.savedVars.fontStyle = value
                self:ApplySettings()
            end,
            width = "full",
        },
        {
            type = "header",
            name = "Visual Effects",
        },
        {
            type = "checkbox",
            name = "Disable Max Resource Change Effects",
            tooltip = "When enabled, visual effects that appear when maximum resource values change will be disabled",
            getFunc = function() return self.savedVars.disableMaxResourceChangeEffects end,
            setFunc = function(value)
                self.savedVars.disableMaxResourceChangeEffects = value
                self:ApplySettings()
            end,
            requiresReload = true,
            width = "full",
        },
        {
            type = "header",
            name = "Target Attribute Bars",
        },
        {
            type = "checkbox",
            name = "Resize Target Attribute Bars",
            tooltip = "When enabled, the target unit frame attribute bars are resized to a fixed size. A reload is required: re-enabling and disabling both take effect after a reload, because the target frame is rebuilt by the game at startup",
            getFunc = function() return self.savedVars.enableTargetBarsResizer end,
            setFunc = function(value)
                self.savedVars.enableTargetBarsResizer = value
                self:ApplySettings()
            end,
            requiresReload = true,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Show Elite Difficulty Brackets",
            tooltip = "When enabled (default), the glowing difficulty brackets appear around the target frame when targeting an elite or boss enemy. Disable to hide them. A reload is required",
            getFunc = function() return self.savedVars.showTargetEliteBrackets ~= false end,
            setFunc = function(value)
                self.savedVars.showTargetEliteBrackets = value
            end,
            requiresReload = true,
            width = "full",
            disabled = function() return not self.savedVars.enableTargetBarsResizer end,
        },
        {
            type = "slider",
            name = "Target Bar Width",
            tooltip = "Set the width of the target health bar (applies immediately)",
            min = 200,
            max = 600,
            step = 1,
            getFunc = function() return self.savedVars.targetBarWidth end,
            setFunc = function(value)
                self.savedVars.targetBarWidth = value
                local m = AEAB.modules and AEAB.modules.targetBarsResizer
                if m and m.ApplyDimensions then m.ApplyDimensions() end
            end,
            width = "full",
            disabled = function() return not self.savedVars.enableTargetBarsResizer end,
        },
        {
            type = "slider",
            name = "Target Bar Height",
            tooltip = "Set the height of the target health bar (applies immediately)",
            min = 10,
            max = 45,
            step = 1,
            getFunc = function() return self.savedVars.targetBarHeight end,
            setFunc = function(value)
                self.savedVars.targetBarHeight = value
                local m = AEAB.modules and AEAB.modules.targetBarsResizer
                if m and m.ApplyDimensions then m.ApplyDimensions() end
            end,
            width = "full",
            disabled = function() return not self.savedVars.enableTargetBarsResizer end,
        },
        {
            type = "checkbox",
            name = "Color Target Bar By Reaction",
            tooltip = "When enabled, the target health bar is colored depending on the target: enemy, neutral, ally, or yourself. The color applies when you target something",
            getFunc = function() return self.savedVars.targetBarColorByReaction end,
            setFunc = function(value)
                self.savedVars.targetBarColorByReaction = value
                local m = AEAB.modules and AEAB.modules.targetBarsResizer
                if m then
                    if value and m.ApplyReactionColor then m.ApplyReactionColor() end
                    if not value then
                        if m.RestoreReactionColor then m.RestoreReactionColor() end
                        if m.ApplyGradient then m.ApplyGradient() end
                    end
                end
            end,
            width = "full",
        },
        {
            type = "dropdown",
            name = "Target Bar Color Source",
            tooltip = "Custom Colors: use the colors picked below. Game Reaction Colors: use the game's standard reaction colors with the gradient style",
            choices = { "Custom Colors", "Game Reaction Colors" },
            getFunc = function()
                if self.savedVars.targetColorSource == "game" then return "Game Reaction Colors" end
                return "Custom Colors"
            end,
            setFunc = function(value)
                self.savedVars.targetColorSource = (value == "Game Reaction Colors") and "game" or "custom"
                local m = AEAB.modules and AEAB.modules.targetBarsResizer
                if m and m.ApplyReactionColor then m.ApplyReactionColor() end
            end,
            width = "full",
        },
        {
            type = "colorpicker",
            name = "Enemy Target Color",
            tooltip = "Target bar color while targeting an enemy",
            getFunc = function() return unpack(self.savedVars.targetEnemyColor) end,
            setFunc = function(r, g, b, a)
                self.savedVars.targetEnemyColor = {r, g, b, a}
                local m = AEAB.modules and AEAB.modules.targetBarsResizer
                if m and m.ApplyReactionColor then m.ApplyReactionColor() end
            end,
            width = "half",
            disabled = function() return self.savedVars.targetColorSource ~= "custom" or not self.savedVars.targetBarColorByReaction end,
        },
        {
            type = "colorpicker",
            name = "Neutral Target Color",
            tooltip = "Target bar color while targeting a neutral unit",
            getFunc = function() return unpack(self.savedVars.targetNeutralColor) end,
            setFunc = function(r, g, b, a)
                self.savedVars.targetNeutralColor = {r, g, b, a}
                local m = AEAB.modules and AEAB.modules.targetBarsResizer
                if m and m.ApplyReactionColor then m.ApplyReactionColor() end
            end,
            width = "half",
            disabled = function() return self.savedVars.targetColorSource ~= "custom" or not self.savedVars.targetBarColorByReaction end,
        },
        {
            type = "colorpicker",
            name = "Ally Target Color",
            tooltip = "Target bar color while targeting an ally (friendly NPC or player)",
            getFunc = function() return unpack(self.savedVars.targetAllyColor) end,
            setFunc = function(r, g, b, a)
                self.savedVars.targetAllyColor = {r, g, b, a}
                local m = AEAB.modules and AEAB.modules.targetBarsResizer
                if m and m.ApplyReactionColor then m.ApplyReactionColor() end
            end,
            width = "half",
            disabled = function() return self.savedVars.targetColorSource ~= "custom" or not self.savedVars.targetBarColorByReaction end,
        },
        {
            type = "colorpicker",
            name = "Player (Self) Target Color",
            tooltip = "Target bar color while targeting yourself",
            getFunc = function() return unpack(self.savedVars.targetPlayerColor) end,
            setFunc = function(r, g, b, a)
                self.savedVars.targetPlayerColor = {r, g, b, a}
                local m = AEAB.modules and AEAB.modules.targetBarsResizer
                if m and m.ApplyReactionColor then m.ApplyReactionColor() end
            end,
            width = "half",
            disabled = function() return self.savedVars.targetColorSource ~= "custom" or not self.savedVars.targetBarColorByReaction end,
        },
        {
            type = "colorpicker",
            name = "Player Character Target Color",
            tooltip = "Target bar color while targeting another player character (overrides the ally/enemy colors for players)",
            getFunc = function() return unpack(self.savedVars.targetPlayerCharacterColor) end,
            setFunc = function(r, g, b, a)
                self.savedVars.targetPlayerCharacterColor = {r, g, b, a}
                local m = AEAB.modules and AEAB.modules.targetBarsResizer
                if m and m.ApplyReactionColor then m.ApplyReactionColor() end
            end,
            width = "half",
            disabled = function() return self.savedVars.targetColorSource ~= "custom" or not self.savedVars.targetBarColorByReaction end,
        },
        {
            type = "checkbox",
            name = "Blue Color for Friendly Players",
            tooltip = "When enabled, the target health bar uses the white-blue color (the game's reaction color for friendly players, a light blue gradient) when targeting a friendly player, instead of the standard red gradient. This option is the single control for friendly players: enabled = light-blue, disabled = standard red gradient, regardless of the Color Target Bar By Reaction setting",
            getFunc = function() return self.savedVars.blueForFriendlyPlayers end,
            setFunc = function(value)
                self.savedVars.blueForFriendlyPlayers = value
                local m = AEAB.modules and AEAB.modules.targetBarsResizer
                if m then
                    if m.ApplyReactionColor then m.ApplyReactionColor() end
                    if m.ApplyGradient then m.ApplyGradient() end
                end
            end,
            width = "full",
        },
        {
            type = "header",
            name = "Target Font",
        },
        {
            type = "dropdown",
            name = "Target Font Face",
            tooltip = "Select the font face for the target frame texts (name, level, caption and numbers). Requires Resize Target Attribute Bars to be enabled",
            choices = FONT_FACES,
            getFunc = function() return self.savedVars.targetFontFace end,
            setFunc = function(value)
                self.savedVars.targetFontFace = value
                local m = AEAB.modules and AEAB.modules.targetBarsResizer
                if m and m.ApplyFont then m.ApplyFont() end
            end,
            width = "full",
            disabled = function() return not self.savedVars.enableTargetBarsResizer end,
        },
        {
            type = "slider",
            name = "Target Font Size",
            tooltip = "Set the font size for the target frame texts",
            min = 10,
            max = 30,
            step = 1,
            getFunc = function() return self.savedVars.targetFontSize end,
            setFunc = function(value)
                self.savedVars.targetFontSize = value
                local m = AEAB.modules and AEAB.modules.targetBarsResizer
                if m and m.ApplyFont then m.ApplyFont() end
            end,
            width = "full",
            disabled = function() return not self.savedVars.enableTargetBarsResizer end,
        },
        {
            type = "dropdown",
            name = "Target Font Style",
            tooltip = "Select the shadow/outline style for the target frame texts",
            choices = FONT_STYLES,
            getFunc = function() return self.savedVars.targetFontStyle end,
            setFunc = function(value)
                self.savedVars.targetFontStyle = value
                local m = AEAB.modules and AEAB.modules.targetBarsResizer
                if m and m.ApplyFont then m.ApplyFont() end
            end,
            width = "full",
            disabled = function() return not self.savedVars.enableTargetBarsResizer end,
        },
        {
            type = "header",
            name = "Unit Frame Numbers",
        },
        {
            type = "checkbox",
            name = "Enable Unit Frame Numbers",
            tooltip = "Sub-addon: full numbers (current / max / percent) on the player attribute bars and the boss health bar, with damage absorption ([+N]) and heal absorption ([-N]) display.",
            getFunc = function() return self.savedVars.enableUnitNumbersModule end,
            setFunc = function(value)
                self.savedVars.enableUnitNumbersModule = value
            end,
            requiresReload = true,
            width = "full",
        },
        {
            type = "dropdown",
            name = "Player Bar Number Format",
            tooltip = "Number format for the player health / magicka / stamina bars",
            choices = { "Current / Max", "Current / Max (Percent)", "Current", "Percent" },
            getFunc = function()
                if self.savedVars.playerNumberStyle == 'currentmax' then return "Current / Max" end
                if self.savedVars.playerNumberStyle == 'current' then return "Current" end
                if self.savedVars.playerNumberStyle == 'percent' then return "Percent" end
                return "Current / Max (Percent)"
            end,
            setFunc = function(value)
                if value == "Current / Max" then
                    self.savedVars.playerNumberStyle = 'currentmax'
                elseif value == "Current" then
                    self.savedVars.playerNumberStyle = 'current'
                elseif value == "Percent" then
                    self.savedVars.playerNumberStyle = 'percent'
                else
                    self.savedVars.playerNumberStyle = 'currentmaxpercent'
                end
                local m = AEAB.modules and AEAB.modules.unitNumbers
                if m and m.Refresh then m.Refresh() end
            end,
            width = "full",
            disabled = function() return not self.savedVars.enableUnitNumbersModule end,
        },
        {
            type = "checkbox",
            name = "Show Damage Absorption",
            tooltip = "Append [+N] - the amount absorbed by shields - to the health bar numbers",
            getFunc = function() return self.savedVars.numbersShowShield end,
            setFunc = function(value)
                self.savedVars.numbersShowShield = value
                local m = AEAB.modules and AEAB.modules.unitNumbers
                if m and m.Refresh then m.Refresh() end
            end,
            width = "full",
            disabled = function() return not self.savedVars.enableUnitNumbersModule end,
        },
        {
            type = "checkbox",
            name = "Show Heal Absorption",
            tooltip = "Append [-N] - the healing absorbed by Trauma - to the health bar numbers",
            getFunc = function() return self.savedVars.numbersShowTrauma end,
            setFunc = function(value)
                self.savedVars.numbersShowTrauma = value
                local m = AEAB.modules and AEAB.modules.unitNumbers
                if m and m.Refresh then m.Refresh() end
            end,
            width = "full",
            disabled = function() return not self.savedVars.enableUnitNumbersModule end,
        },
        {
            type = "checkbox",
            name = "Show Target Bar Numbers",
            tooltip = "Show full numbers on the target health bar",
            getFunc = function() return self.savedVars.targetShowNumbers end,
            setFunc = function(value)
                self.savedVars.targetShowNumbers = value
                local m = AEAB.modules and AEAB.modules.unitNumbers
                if m and m.Refresh then m.Refresh() end
            end,
            width = "full",
            disabled = function() return not self.savedVars.enableUnitNumbersModule end,
        },
        {
            type = "dropdown",
            name = "Target Bar Number Format",
            tooltip = "Number format for the target health bar",
            choices = { "Current / Max", "Current / Max (Percent)", "Current", "Percent" },
            getFunc = function()
                if self.savedVars.targetNumberStyle == 'currentmax' then return "Current / Max" end
                if self.savedVars.targetNumberStyle == 'current' then return "Current" end
                if self.savedVars.targetNumberStyle == 'percent' then return "Percent" end
                return "Current / Max (Percent)"
            end,
            setFunc = function(value)
                if value == "Current / Max" then
                    self.savedVars.targetNumberStyle = 'currentmax'
                elseif value == "Current" then
                    self.savedVars.targetNumberStyle = 'current'
                elseif value == "Percent" then
                    self.savedVars.targetNumberStyle = 'percent'
                else
                    self.savedVars.targetNumberStyle = 'currentmaxpercent'
                end
                local m = AEAB.modules and AEAB.modules.unitNumbers
                if m and m.Refresh then m.Refresh() end
            end,
            width = "full",
            disabled = function() return not self.savedVars.enableUnitNumbersModule end,
        },
        {
            type = "checkbox",
            name = "Show Boss Bar Numbers",
            tooltip = "Show full numbers on the boss health bar",
            getFunc = function() return self.savedVars.bossShowNumbers end,
            setFunc = function(value)
                self.savedVars.bossShowNumbers = value
                local m = AEAB.modules and AEAB.modules.unitNumbers
                if m and m.Refresh then m.Refresh() end
            end,
            width = "full",
            disabled = function() return not self.savedVars.enableUnitNumbersModule end,
        },
        {
            type = "checkbox",
            name = "Show XP Numbers on Level Bar",
            tooltip = "Show the current / required XP (percent) inside the player level bar, in the same format as the attribute bars",
            getFunc = function() return self.savedVars.xpBarShowNumbers end,
            setFunc = function(value)
                self.savedVars.xpBarShowNumbers = value
                local m = AEAB.modules and AEAB.modules.unitNumbers
                if m and m.Refresh then m.Refresh() end
            end,
            width = "full",
            disabled = function() return not self.savedVars.enableUnitNumbersModule end,
        },
        {
            type = "dropdown",
            name = "Boss Bar Number Format",
            tooltip = "Number format for the boss health bar",
            choices = { "Current / Max", "Current / Max (Percent)", "Current", "Percent" },
            getFunc = function()
                if self.savedVars.bossNumberStyle == 'currentmax' then return "Current / Max" end
                if self.savedVars.bossNumberStyle == 'current' then return "Current" end
                if self.savedVars.bossNumberStyle == 'percent' then return "Percent" end
                return "Current / Max (Percent)"
            end,
            setFunc = function(value)
                if value == "Current / Max" then
                    self.savedVars.bossNumberStyle = 'currentmax'
                elseif value == "Current" then
                    self.savedVars.bossNumberStyle = 'current'
                elseif value == "Percent" then
                    self.savedVars.bossNumberStyle = 'percent'
                else
                    self.savedVars.bossNumberStyle = 'currentmaxpercent'
                end
                local m = AEAB.modules and AEAB.modules.unitNumbers
                if m and m.Refresh then m.Refresh() end
            end,
            width = "full",
            disabled = function() return not self.savedVars.enableUnitNumbersModule end,
        },
        {
            type = "dropdown",
            name = "Boss Bar Thousands Separator",
            tooltip = "Separator inserted between every 3 digits on the boss health bar: 27856 -> 27,856 or 12345678 -> 12.345.678. Use the global separator below for the player and target bars",
            choices = { "None", "Comma ( , )", "Period ( . )", "Space", "Apostrophe ( ' )" },
            getFunc = function()
                local sep = self.savedVars.bossNumberSeparator
                if sep == "," then return "Comma ( , )" end
                if sep == "." then return "Period ( . )" end
                if sep == " " then return "Space" end
                if sep == "'" then return "Apostrophe ( ' )" end
                return "None"
            end,
            setFunc = function(value)
                if value == "Comma ( , )" then
                    self.savedVars.bossNumberSeparator = ","
                elseif value == "Period ( . )" then
                    self.savedVars.bossNumberSeparator = "."
                elseif value == "Space" then
                    self.savedVars.bossNumberSeparator = " "
                elseif value == "Apostrophe ( ' )" then
                    self.savedVars.bossNumberSeparator = "'"
                else
                    self.savedVars.bossNumberSeparator = ""
                end
                local m = AEAB.modules and AEAB.modules.unitNumbers
                if m and m.Refresh then m.Refresh() end
            end,
            width = "full",
            disabled = function() return not self.savedVars.enableUnitNumbersModule end,
        },
        {
            type = "dropdown",
            name = "Thousands Separator",
            tooltip = "Separator inserted between every 3 digits in the player and target bar numbers: 27856 -> 27,856 or 12345678 -> 12.345.678",
            choices = { "None", "Comma ( , )", "Period ( . )", "Space", "Apostrophe ( ' )" },
            getFunc = function()
                local sep = self.savedVars.numberSeparator
                if sep == "," then return "Comma ( , )" end
                if sep == "." then return "Period ( . )" end
                if sep == " " then return "Space" end
                if sep == "'" then return "Apostrophe ( ' )" end
                return "None"
            end,
            setFunc = function(value)
                if value == "Comma ( , )" then
                    self.savedVars.numberSeparator = ","
                elseif value == "Period ( . )" then
                    self.savedVars.numberSeparator = "."
                elseif value == "Space" then
                    self.savedVars.numberSeparator = " "
                elseif value == "Apostrophe ( ' )" then
                    self.savedVars.numberSeparator = "'"
                else
                    self.savedVars.numberSeparator = ""
                end
                local m = AEAB.modules and AEAB.modules.unitNumbers
                if m and m.Refresh then m.Refresh() end
            end,
            width = "full",
            disabled = function() return not self.savedVars.enableUnitNumbersModule end,
        },
        {
            type = "button",
            name = "Reset All Settings",
            tooltip = "Reset all settings to default",
            func = function()
                self.savedVars.healthColor = ZO_DeepTableCopy(self.defaults.healthColor)
                self.savedVars.magickaColor = ZO_DeepTableCopy(self.defaults.magickaColor)
                self.savedVars.staminaColor = ZO_DeepTableCopy(self.defaults.staminaColor)
                self.savedVars.shieldColor = ZO_DeepTableCopy(self.defaults.shieldColor)
                self.savedVars.useCustomHealthColor = false
                self.savedVars.useCustomMagickaColor = false
                self.savedVars.useCustomStaminaColor = false
                self.savedVars.useCustomShieldColor = false
                self.savedVars.fontFace = "$(MEDIUM_FONT)"
                self.savedVars.fontSize = 16
                self.savedVars.fontStyle = "soft-shadow-thick"
                self.savedVars.barWidth = self.defaults.barWidth
                self.savedVars.barHeight = self.defaults.barHeight
                self.savedVars.healthBarWidth = self.defaults.healthBarWidth
                self.savedVars.healthBarHeight = self.defaults.healthBarHeight
                self.savedVars.resourceBarWidth = self.defaults.resourceBarWidth
                self.savedVars.resourceBarHeight = self.defaults.resourceBarHeight
                self.savedVars.barGap = self.defaults.barGap
                self.savedVars.repositionBarsOnResize = false
                self.savedVars.disableMaxResourceChangeEffects = false
                self.savedVars.enableTargetBarsResizer = false
                self.savedVars.targetBarWidth = self.defaults.targetBarWidth
                self.savedVars.targetBarHeight = self.defaults.targetBarHeight
                self.savedVars.targetBarColorByReaction = false
                self.savedVars.targetEnemyColor = ZO_DeepTableCopy(self.defaults.targetEnemyColor)
                self.savedVars.targetNeutralColor = ZO_DeepTableCopy(self.defaults.targetNeutralColor)
                self.savedVars.targetAllyColor = ZO_DeepTableCopy(self.defaults.targetAllyColor)
                self.savedVars.targetPlayerColor = ZO_DeepTableCopy(self.defaults.targetPlayerColor)
                self.savedVars.targetPlayerCharacterColor = ZO_DeepTableCopy(self.defaults.targetPlayerCharacterColor)
                self.savedVars.targetColorSource = self.defaults.targetColorSource
                self.savedVars.enableUnitNumbersModule = false
                self.savedVars.playerNumberStyle = self.defaults.playerNumberStyle
                self.savedVars.numbersShowShield = self.defaults.numbersShowShield
                self.savedVars.numbersShowTrauma = self.defaults.numbersShowTrauma
                self.savedVars.bossShowNumbers = self.defaults.bossShowNumbers
                self.savedVars.bossNumberStyle = self.defaults.bossNumberStyle
                self.savedVars.targetShowNumbers = self.defaults.targetShowNumbers
                self.savedVars.targetNumberStyle = self.defaults.targetNumberStyle
                self.savedVars.numberSeparator = self.defaults.numberSeparator
                self.savedVars.bossNumberSeparator = self.defaults.bossNumberSeparator
                self.savedVars.xpBarShowNumbers = self.defaults.xpBarShowNumbers
                self.savedVars.targetFontFace = self.defaults.targetFontFace
                self.savedVars.targetFontSize = self.defaults.targetFontSize
                self.savedVars.targetFontStyle = self.defaults.targetFontStyle
                self.savedVars.playerBarGradient = self.defaults.playerBarGradient
                self.savedVars.blueForFriendlyPlayers = self.defaults.blueForFriendlyPlayers
                self.savedVars.staticBarSize = self.defaults.staticBarSize
                self.savedVars.showTargetEliteBrackets = self.defaults.showTargetEliteBrackets
                self:ApplySettings()
            end,
            requiresReload = true,
            width = "full",
        },
    }
    
    LibAddonMenu2:RegisterOptionControls(self.name, optionsData)
end

-- Initialize when addon loads
function AEAB.OnAddOnLoaded(event, addonName)
    if addonName ~= AEAB.name then return end
    EVENT_MANAGER:UnregisterForEvent(AEAB.name, EVENT_ADD_ON_LOADED)
    AEAB:Initialize()
end

EVENT_MANAGER:RegisterForEvent(AEAB.name, EVENT_ADD_ON_LOADED, AEAB.OnAddOnLoaded)

-- Make AEAB accessible globally
_G["AEAB"] = AEAB