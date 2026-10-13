if FCOCS == nil then FCOCS = {} end
local FCOChangeStuff = FCOCS

local WM = WINDOW_MANAGER

local lootWindowOnShowHookDone= false

------------------------------------------------------------------------------------------------------------------------
-- Functions --
------------------------------------------------------------------------------------------------------------------------


--======== CURSOR ======================================================================

function FCOChangeStuff.snapCursor(snapType)
    if not snapType or snapType == "" then return end
    local settings = FCOChangeStuff.settingsVars.settings
    if snapType == "lootwindow" or snapType == "-ALL-" then
        if lootWindowOnShowHookDone  == true then return end

        LOOT_WINDOW.list.contents:SetHandler("OnEffectivelyShown", function(self)
--d("Loot window list contents: OnEffectivelyShown")
            if not settings.snapCursorToLootWindow then return false end
            local firstRowControlButton = LOOT_WINDOW.list and LOOT_WINDOW.list.data and LOOT_WINDOW.list.data[1] and
                    LOOT_WINDOW.list.data[1].control
            if firstRowControlButton ~= nil and firstRowControlButton.GetName then
--d("[FCOCS]LootWindow 1st row: " ..tostring(firstRowControlButton:GetName()))
                WM:SetMouseFocusByName(firstRowControlButton:GetName())
            end
        end, FCOChangeStuff.addonVars.addonName)
        lootWindowOnShowHookDone = true
    end
end

--======== BUTTONS ======================================================================
--Add a button to an existing parent control
local function AddButton(parent, name, callbackFunction, onMouseUpCallbackFunction, onMouseUpCallbackFunctionMouseButton, text, font, tooltipText, tooltipAlign, textureNormal, textureMouseOver, textureClicked, width, height, left, top, alignMain, alignBackup, alignControl, hideButton)
    --Abort needed?
    if  (parent == nil or name == nil or callbackFunction == nil
            or width <= 0 or height <= 0 or alignMain == nil or alignBackup == nil)
            and (textureNormal == nil or text == nil) then
        return nil
    end
    onMouseUpCallbackFunctionMouseButton = onMouseUpCallbackFunctionMouseButton or 1

    local button
    --Does the button already exist?
    button = WM:GetControlByName(name, "")
    if button == nil then
        --Create the button control at the parent
        button = WM:CreateControl(name, parent, CT_BUTTON)
    end
    --Button was created?
    if button ~= nil then
        --Set the button's size
        button:SetDimensions(width, height)

        --Align the button
        if alignControl == nil then
            alignControl = parent
        end

        --SetAnchor(point, relativeTo, relativePoint, offsetX, offsetY)
        button:SetAnchor(alignMain, alignControl, alignBackup, left, top)

        --Texture or text?
        if (text ~= nil) then
            --Text
            --Set the button's font
            if font == nil then
                button:SetFont("ZoFontGameSmall")
            else
                button:SetFont(font)
            end

            --Set the button's text
            button:SetText(text)

        else
            --Texture
            local texture

            --Check if texture exists
            texture = WM:GetControlByName(name .. "Texture", "")
            if texture == nil then
                --Create the texture for the button to hold the image
                texture = WM:CreateControl(name .. "Texture", button, CT_TEXTURE)
            end
            texture:SetAnchorFill()

            --Set the texture for normale state now
            texture:SetTexture(textureNormal)

            --Do we have seperate textures for the button states?
            button.upTexture 	  = textureNormal
            button.downTexture 	  = textureMouseOver or textureNormal
            button.clickedTexture = textureClicked or textureNormal
        end

        if tooltipAlign == nil then tooltipAlign = TOP end

        --Set a tooltip?
        if tooltipText ~= nil then
            button.tooltipText	= tooltipText
            button.tooltipAlign = tooltipAlign
            button:SetHandler("OnMouseEnter", function(self)
                self:GetChild(1):SetTexture(self.downTexture)
                ZO_Tooltips_ShowTextTooltip(self, self.tooltipAlign, self.tooltipText)
            end)
            button:SetHandler("OnMouseExit", function(self)
                self:GetChild(1):SetTexture(self.upTexture)
                ZO_Tooltips_HideTextTooltip()
            end)
        else
            button:SetHandler("OnMouseEnter", function(self)
                self:GetChild(1):SetTexture(self.downTexture)
            end)
            button:SetHandler("OnMouseExit", function(self)
                self:GetChild(1):SetTexture(self.upTexture)
            end)
        end
        --Set the callback function of the button
        button:SetHandler("OnClicked", function(...)
            callbackFunction(...)
        end)
        --Set the OnMouseUp callback function of the button
        if onMouseUpCallbackFunction ~= nil then
            button:SetHandler("OnMouseUp", function(butn, mouseButton, upInside)
                if upInside then
                    if mouseButton == onMouseUpCallbackFunctionMouseButton then
                        onMouseUpCallbackFunction(butn, mouseButton, upInside)
                    end
                end
            end)
        end
        button:SetHandler("OnMouseDown", function(butn)
            butn:GetChild(1):SetTexture(butn.clickedTexture)
        end)

        --Set the button's visibility and mouse reaction state
        button:SetHidden(hideButton)
        button:SetMouseEnabled(not hideButton)

        --Return the button control
        return button
    else
        return nil
    end
end

--Create a button control
function FCOChangeStuff.CreateButton(parent, name, callbackFunction, onMouseUpCallbackFunction, onMouseUpCallbackFunctionMouseButton, text, font, tooltipText, tooltipAlign, textureNormal, textureMouseOver, textureClicked, width, height, left, top, alignMain, alignBackup, alignControl, hideButton)
    return AddButton(parent, name, callbackFunction, onMouseUpCallbackFunction, onMouseUpCallbackFunctionMouseButton, text, font, tooltipText, tooltipAlign, textureNormal, textureMouseOver, textureClicked, width, height, left, top, alignMain, alignBackup, alignControl, hideButton)
end