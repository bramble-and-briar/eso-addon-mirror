local AEAB = AEAB or {}
AEAB.name = "AlwaysExpandedAttributeBars"
AEAB.version = "3.1b u51"
AEAB.APPLY_DELAY_MS = 1000 -- Delay before applying settings after player activation

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
    
    -- Font settings
    fontFace = "$(MEDIUM_FONT)",   -- Default font face
    fontSize = 16,                 -- Default font size
    fontStyle = "soft-shadow-thick", -- Default font style (shadow/outline)
    
    -- Bar size settings
    barWidth = 323,                -- Default bar width (matches the original expanded size)
    barHeight = 25,                -- Default bar height
    barGap = 112,                  -- Gap between health and magicka/stamina bars
    repositionBarsOnResize = false, -- Keep the bars centered/evenly spaced on width change (off by default)

    -- Visual effects settings
    disableMaxResourceChangeEffects = false,  -- Disable visual effects when max resource changes

    -- Target attribute bars module
    enableTargetBarsResizer = false,  -- Resize target unit frame attribute bars (module disabled by default)
}



-- Initialize settings
function AEAB:Initialize()
    -- Load saved variables
    self.savedVars = ZO_SavedVars:NewAccountWide("AEABSavedVars", 1, nil, self.defaults)

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
    
    -- Apply custom bar dimensions
    if AEAB.ApplyDimensions then
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

    local width = sv.barWidth or self.defaults.barWidth
    local height = sv.barHeight or self.defaults.barHeight
    local gap = sv.barGap or self.defaults.barGap
    if type(width) ~= "number" then width = 323 end
    if type(height) ~= "number" then height = 25 end
    if type(gap) ~= "number" then gap = 112 end

    local health = ZO_PlayerAttributeHealth
    local magicka = ZO_PlayerAttributeMagicka
    local stamina = ZO_PlayerAttributeStamina

    -- NOTE: ESO controls support AT MOST TWO anchors per control.
    -- Every control below is therefore set up with exactly two anchors.

    local function StretchChildren(container)
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

    StretchChildren(health)
    StretchChildren(magicka)
    StretchChildren(stamina)

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
            name = "Bar Size",
        },
        {
            type = "slider",
            name = "Bar Width",
            tooltip = "Set the width of the attribute bars (applies immediately)",
            min = 200,
            max = 600,
            step = 1,
            getFunc = function() return self.savedVars.barWidth end,
            setFunc = function(value)
                self.savedVars.barWidth = value
                self:ApplySettings()
            end,
            width = "full",
        },
        {
            type = "slider",
            name = "Bar Height",
            tooltip = "Set the height of the attribute bars (applies immediately)",
            min = 10,
            max = 45,
            step = 1,
            getFunc = function() return self.savedVars.barHeight end,
            setFunc = function(value)
                self.savedVars.barHeight = value
                self:ApplySettings()
            end,
            width = "full",
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
                self.savedVars.barGap = self.defaults.barGap
                self.savedVars.repositionBarsOnResize = false
                self.savedVars.disableMaxResourceChangeEffects = false
                self.savedVars.enableTargetBarsResizer = false
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