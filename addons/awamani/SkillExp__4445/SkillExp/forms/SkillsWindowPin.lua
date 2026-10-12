-- Pin button in the game's Skills window (keyboard UI) for pinning skill lines to SkillExp

-- ─────────────────────────────────────────────────────────────────────────────
-- Constants
-- ─────────────────────────────────────────────────────────────────────────────
-- Same pin toggle textures as the game's "Pin Task" button in Golden Pursuits
local PIN_BUTTON_UP = "EsoUI/Art/Buttons/radioButton_pin_up.dds"
local PIN_BUTTON_DOWN = "EsoUI/Art/Buttons/radioButton_pin_down.dds"
local PIN_BUTTON_OVER = "EsoUI/Art/Buttons/radioButton_pin_highlight.dds"
local PIN_INDICATOR = "EsoUI/Art/Buttons/Gamepad/gp_trackingPin.dds"
local PIN_BUTTON_SIZE = 32
local TOOLTIP_OFFSET_Y = 20 -- below the pin, clear of the mouse cursor

-- ─────────────────────────────────────────────────────────────────────────────
-- State
-- ─────────────────────────────────────────────────────────────────────────────
local pinButton

-- ─────────────────────────────────────────────────────────────────────────────
-- Pin button
-- ─────────────────────────────────────────────────────────────────────────────
local function GetSelectedSkillLineData()
    local skillLineData = SKILLS_WINDOW:GetSelectedSkillLineData()
    if skillLineData and not skillLineData.isSubclassingNode then
        return skillLineData
    end
    return nil
end

local function AddTooltipLine(text, color)
    local r, g, b = color:UnpackRGB()
    InformationTooltip:AddLine(text, "", r, g, b, LEFT, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_LEFT, true)
end

local function ShowPinTooltip(control)
    InitializeTooltip(InformationTooltip, control, TOP, 0, TOOLTIP_OFFSET_Y, BOTTOM)
    AddTooltipLine("SkillExp Pin", ZO_SELECTED_TEXT)
    if control.isPinned then
        AddTooltipLine(zo_strformat("<<1>> is pinned to the SkillExp display.", control.skillLineName), ZO_NORMAL_TEXT)
    else
        AddTooltipLine(zo_strformat("Pin <<1>> to the SkillExp display so it is always shown.", control.skillLineName), ZO_NORMAL_TEXT)
    end
    AddTooltipLine("Pins are saved per character and removed automatically when the skill line reaches max rank.", ZO_NORMAL_TEXT)
    AddTooltipLine(control.isPinned and "Click to unpin" or "Click to pin", ZO_TOOLTIP_INSTRUCTIONAL_COLOR)
end

local function RefreshPinButton(skillLineData)
    skillLineData = skillLineData or GetSelectedSkillLineData()
    if not skillLineData then
        pinButton:SetHidden(true)
        return
    end

    local skillLineId = skillLineData:GetId()
    local isPinned = SkillExp_IsSkillLinePinned(skillLineId)
    if not isPinned and not SkillExp_CanPinSkillLine(skillLineId) then
        pinButton:SetHidden(true)
        return
    end

    pinButton.skillLineId = skillLineId
    pinButton.skillLineName = skillLineData:GetName()
    pinButton.isPinned = isPinned
    if isPinned then
        pinButton:SetState(BSTATE_PRESSED, true)
    else
        pinButton:SetState(BSTATE_NORMAL, false)
    end
    pinButton:SetHidden(false)

    if InformationTooltip:GetOwner() == pinButton then
        ShowPinTooltip(pinButton)
    end
end

local function CreatePinButton()
    local skillInfo = SKILLS_WINDOW.skillInfo

    pinButton = WINDOW_MANAGER:CreateControl("SkillExpSkillsWindowPin", skillInfo, CT_BUTTON)
    pinButton:SetDimensions(PIN_BUTTON_SIZE, PIN_BUTTON_SIZE)
    pinButton:SetAnchor(LEFT, skillInfo.name, RIGHT, 10, 0)
    pinButton:SetNormalTexture(PIN_BUTTON_UP)
    pinButton:SetPressedTexture(PIN_BUTTON_DOWN)
    pinButton:SetMouseOverTexture(PIN_BUTTON_OVER)
    pinButton:SetPressedMouseOverTexture(PIN_BUTTON_OVER)
    pinButton:SetClickSound(SOUNDS.DEFAULT_CLICK)
    pinButton:SetHidden(true)

    pinButton:SetHandler("OnMouseEnter", ShowPinTooltip)
    pinButton:SetHandler(
        "OnMouseExit", function()
            ClearTooltip(InformationTooltip)
        end)
    pinButton:SetHandler(
        "OnClicked", function(self)
            if self.skillLineId then
                SkillExp_ToggleSkillLinePin(self.skillLineId)
            end
            -- Re-apply state in case the toggle was refused
            RefreshPinButton()
        end)

    -- Follow the selected skill line
    ZO_PostHook(
        "ZO_SkillLineInfo_Keyboard_Refresh", function(skillLineInfo, skillLineData)
            if skillLineInfo == skillInfo and not skillLineData.isSubclassingNode then
                RefreshPinButton(skillLineData)
            end
        end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Skill line tree: pin status icon on pinned entries
-- ─────────────────────────────────────────────────────────────────────────────
local function HookSkillLineTree()
    local templateInfo = SKILLS_WINDOW.skillLinesTree.templateInfo["ZO_SkillsNavigationEntry"]
    local originalSetup = templateInfo.setupFunction

    templateInfo.setupFunction = function(node, control, skillLineData, ...)
        originalSetup(node, control, skillLineData, ...)

        if not skillLineData.isSubclassingNode and SkillExp_IsSkillLinePinned(skillLineData:GetId()) then
            -- Hide/Show around AddIcon so ZO_MultiIcon re-evaluates cycling
            local statusIcon = control.statusIcon
            statusIcon:Hide()
            statusIcon:AddIcon(PIN_INDICATOR)
            statusIcon:Show()
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Init
-- ─────────────────────────────────────────────────────────────────────────────
local function Initialize()
    if not SKILLS_WINDOW then
        return
    end

    CreatePinButton()
    HookSkillLineTree()

    CALLBACK_MANAGER:RegisterCallback(
        "OnSkillExpPinsChanged", function()
            RefreshPinButton()
            SKILLS_WINDOW.skillLinesTreeRefreshGroup:MarkDirty("Visible")
        end)
end

CALLBACK_MANAGER:RegisterCallback("OnSkillExpInitialized", Initialize)
