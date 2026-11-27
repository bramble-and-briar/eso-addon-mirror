local LeoAltholic = LeoAltholic
LeoAltholic.ToolbarUI.items = {
    INVENTORY = 1,
    BANKSIZE = 2,
    WRITSTATUS = 3,
    RESEARCH = 4,
    RIDING = 5
}

local targetUnitFrame

function LeoAltholic.ToolbarUI.normalizeSettings()
    if not LeoAltholic.globalData.toolbar then LeoAltholic.globalData.toolbar = {} end
    if not LeoAltholic.globalData.settings.toolbar then LeoAltholic.globalData.settings.toolbar = {} end
end

function LeoAltholic.ToolbarUI.SetPosition(left, top)
    LeoAltholic.globalData.toolbar.position = {
        left = left,
        top = top
    }
end
function LeoAltholic.ToolbarUI.GetPosition()
--    return LeoAltholic.globalData.toolbar.position or    { left = 100; top = 200; }        --original code
    return LeoAltholic.globalData.toolbar.position or    { left = 1200; top = 1580; }    --Teva's mod to personalize position for all accounts
end

function LeoAltholic.ToolbarUI.SetEnabled(value)
    LeoAltholic.globalData.settings.toolbar.enabled = value
    LeoAltholic.ToolbarUI.RestorePosition()
end
function LeoAltholic.ToolbarUI.IsEnabled()
    if LeoAltholic.globalData.settings.toolbar.enabled == nil then LeoAltholic.globalData.settings.toolbar.enabled = false end
    return LeoAltholic.globalData.settings.toolbar.enabled
end

function LeoAltholic.ToolbarUI.SetHideDoneWrit(value)
    LeoAltholic.globalData.settings.toolbar.hideDoneWrit = value
end
function LeoAltholic.ToolbarUI.GetHideDoneWrit()
    if LeoAltholic.globalData.settings.toolbar.hideDoneWrit == nil then LeoAltholic.globalData.settings.toolbar.hideDoneWrit = false end
    return LeoAltholic.globalData.settings.toolbar.hideDoneWrit
end

function LeoAltholic.ToolbarUI.SetBumpCompass(value)
    LeoAltholic.globalData.settings.toolbar.bumpCompass = value
    LeoAltholic.ToolbarUI.BumpCompass()
end
function LeoAltholic.ToolbarUI.GetBumpCompass()
    if LeoAltholic.globalData.settings.toolbar.bumpCompass == nil then LeoAltholic.globalData.settings.toolbar.bumpCompass = false end
    return LeoAltholic.globalData.settings.toolbar.bumpCompass
end
function LeoAltholic.ToolbarUI.BumpCompass(enabled)
    if enabled == nil then enabled = true end

    local hasWykkydsToolbar = false
    if WYK_Toolbar and wykkydsToolbar then hasWykkydsToolbar = true end

    if not hasWykkydsToolbar and LeoAltholic.ToolbarUI.IsEnabled() and LeoAltholic.ToolbarUI.GetBumpCompass() then
        targetUnitFrame = targetUnitFrame or WINDOW_MANAGER:GetControlByName("ZO_TargetUnitFramereticleover")

        if LeoAltholicToolbar:GetTop() <= 60 and enabled then
            if math.floor(ZO_CompassFrame:GetTop()) ~= math.floor(LeoAltholicToolbar:GetTop()) + 60 then
                ZO_CompassFrame:ClearAnchors()
                ZO_CompassFrame:SetAnchor(TOP, GuiRoot, TOP, 0, LeoAltholicToolbar:GetTop() + 60)
                if targetUnitFrame then
                    targetUnitFrame:ClearAnchors()
                    targetUnitFrame:SetAnchor(TOP, GuiRoot, TOP, 0, LeoAltholicToolbar:GetTop() + 110)
                end
            end
        elseif ZO_CompassFrame:GetTop() ~= 40 or not enabled then
            ZO_CompassFrame:ClearAnchors()
            ZO_CompassFrame:SetAnchor(TOP, GuiRoot, TOP, 0, 40)
            if targetUnitFrame then
                targetUnitFrame:ClearAnchors()
                targetUnitFrame:SetAnchor(TOP, GuiRoot, TOP, 0, 88)
            end
        end
    end
end

function LeoAltholic.ToolbarUI.SetItem(item, value)
    if not LeoAltholic.globalData.settings.toolbar.items then LeoAltholic.globalData.settings.toolbar.items = {} end
    LeoAltholic.globalData.settings.toolbar.items[item] = value
    LeoAltholic.ToolbarUI.update()
end
function LeoAltholic.ToolbarUI.GetItem(item)
    if not LeoAltholic.globalData.settings.toolbar.items then LeoAltholic.globalData.settings.toolbar.items = {} end
    if LeoAltholic.globalData.settings.toolbar.items[item] == nil then LeoAltholic.globalData.settings.toolbar.items[item] = true end
    return LeoAltholic.globalData.settings.toolbar.items[item]
end

local function checkCenter()
    if LeoAltholicToolbar:GetTop() <= 60 or LeoAltholicToolbar:GetTop() >= 1500 then --Teva added the second condition
        local x = LeoAltholicToolbar:GetCenter()
        local guiRootX = GuiRoot:GetCenter()
        if x ~= guiRootX then
            x = LeoAltholicToolbar:GetLeft() + (guiRootX - x)
            LeoAltholicToolbar:ClearAnchors()
            LeoAltholicToolbar:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, LeoAltholicToolbar:GetTop())
            LeoAltholic.ToolbarUI.SetPosition(x, LeoAltholicToolbar:GetTop())
        end
    end
end

function LeoAltholic.ToolbarUI:OnWindowMoveStop()
    checkCenter()
    LeoAltholic.ToolbarUI.SetPosition(LeoAltholicToolbar:GetLeft(), LeoAltholicToolbar:GetTop())
end

function LeoAltholic.ToolbarUI.RestorePosition()
    local position = LeoAltholic.ToolbarUI.GetPosition()
    local left = position.left
    local top = position.top

    LeoAltholicToolbar:ClearAnchors()
    LeoAltholicToolbar:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    if LeoAltholic.ToolbarUI.IsEnabled() then
        LeoAltholicToolbar:SetHidden(false)
    else
        LeoAltholicToolbar:SetHidden(true)
    end
end

local function addLine(tooltip, text, color)
    if not color then color = ZO_SELECTED_TEXT end
    local r, g, b = color:UnpackRGB()
    tooltip:AddLine(text, "LeoAltholicNormalFont", r, g, b, CENTER, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_LEFT, true)
end

local function hasExpiredQueue()
    for x,data in pairs(LeoAltholic.timerQueue) do
        if GetDiffBetweenTimeStamps(data.time, GetTimeStamp()) <= 0 then
            return true
        end
    end
    return false
end

function LeoAltholic.UI.TooltipWarning(control, visible)
    if visible and hasExpiredQueue() then
        InitializeTooltip(InformationTooltip, control, TOPLEFT, -100, 40, TOPLEFT)
        for x,data in pairs(LeoAltholic.timerQueue) do
            if GetDiffBetweenTimeStamps(data.time, GetTimeStamp()) <= 0 then
                addLine(InformationTooltip, data.info)
            end
        end
        InformationTooltip:SetHidden(false)
        InformationTooltipTopLevel:BringWindowToTop()
    else
        ClearTooltip(InformationTooltip)
        InformationTooltip:SetHidden(true)
    end
end

function LeoAltholic.ToolbarUI.update()
    if not LeoAltholic.ToolbarUI.IsEnabled() then return end
    LeoAltholic.ToolbarUI.BumpCompass()
    local char = LeoAltholic.GetMyself()
    local toolbar = WINDOW_MANAGER:GetControlByName("LeoAltholicToolbar")
--Teva moved these definitions up so can adjust offsetX and prevent warning from visually stacking atop an icon
    local checklistOffsetX = 0
    local offsetX = 0 --TevaNote: affects left of inventory count
    local width = 120
    local numSections = 0
    local totalWidth = 0 --TevaNote: affects right of inventory count and left of research warning
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- INVENTORY --
    local line
    local label = GetControl(toolbar, "Inventory")
    local texture = GetControl(toolbar, "InventoryTexture")
    label:SetHidden(true)
    texture:SetHidden(true)
    if LeoAltholic.ToolbarUI.GetItem(LeoAltholic.ToolbarUI.items.INVENTORY) then
        local color = '|c' .. LeoAltholic.color.hex.green
        if char.inventory.free <= 25 then color = '|c'..LeoAltholic.color.hex.yellow end
        if char.inventory.free <= 10 then color = '|c'..LeoAltholic.color.hex.red end
        label:SetText(color .. char.inventory.used .. "|r / " .. char.inventory.size)
        label:SetHidden(false)
        texture:SetHidden(false)
        texture:SetAnchor(TOPLEFT, toolbar, TOPLEFT, offsetX, 0)
        offsetX = offsetX + 100
        numSections = numSections + 1
        totalWidth = totalWidth + 105
    end
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- BANKSIZE    -- Teva added this section
    local bankfree = GetNumBagFreeSlots(BAG_BANK) + GetNumBagFreeSlots(BAG_SUBSCRIBER_BANK)
    local bankused = GetNumBagUsedSlots(BAG_BANK) + GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK)
    local banksize = bankfree + bankused

    line = GetControl(toolbar, "BankSize")
    label = GetControl(toolbar, "Bank")
    texture = GetControl(toolbar, "BankSizeTexture")
    label:SetHidden(true)
    texture:SetHidden(true)
    if LeoAltholic.ToolbarUI.GetItem(LeoAltholic.ToolbarUI.items.BANKSIZE) then
        local bankcolor = '|c' .. LeoAltholic.color.hex.green
        if bankfree <= 25 then bankcolor = '|c'..LeoAltholic.color.hex.yellow end
        if bankfree <= 10 then bankcolor = '|c'..LeoAltholic.color.hex.red end
        label:SetText(bankcolor..bankused.."|r / ".. banksize)
        label:SetHidden(false)
        texture:SetHidden(false)
        texture:SetAnchor(TOPLEFT, toolbar, TOPLEFT, offsetX, 0)
        offsetX = offsetX + 100
        numSections = numSections + 1
        totalWidth = totalWidth + 105
    end
--Teva added the code section above
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- RESEARCH, complete --
    local warning = GetControl(toolbar, "WarningIcon")
    if hasExpiredQueue() then
        totalWidth = totalWidth + 25    --added by Teva to stop the warning icon stacking
        warning:SetHidden(false)
        line = GetControl(toolbar, "WarningLine")
        line:SetHidden(false)
        line:SetAnchor(TOPLEFT, warning, TOPLEFT, 2, 0)
        line:SetAnchor(BOTTOMRIGHT, warning, BOTTOMLEFT, 2, 0)
    else
        warning:SetHidden(true)
    end
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- STATUS aka WRITSTATUS: SECTIONS FOR WRIT STATUS & RIDING --
    local checklist = GetControl(toolbar, "Checklist")
    local shownChecklist = false
    if LeoAltholic.ToolbarUI.GetItem(LeoAltholic.ToolbarUI.items.WRITSTATUS) then
        checklist:SetAnchor(TOPLEFT, toolbar, TOPLEFT, offsetX, 0)
        checklist:SetHidden(false)
        local icon
        for _, craft in pairs(LeoAltholic.allCrafts) do
            icon = GetControl(checklist, "Craft"..craft.."Icon")
            if LeoAltholic.ChecklistUI.GetCraft(craft) then
                local isDone = false    --Teva commented this out, don't recall why... double-check if it tests right with it back in now that all else works
                for _, writ in pairs(char.quests.writs) do
                    if craft == writ.craft then
--Teva adjusted colors and conditions below
                        if writ.lastStarted ~= nil then        -- and LeoAltholic.IsAfterReset(writ.lastStarted)
                            if writ.lastDone ~= nil and writ.lastDone > writ.lastStarted then
                                if LeoAltholic.IsAfterReset(writ.lastStarted) then
                                    isDone = true                --Status: Done for Today
                                    icon:SetColor(0.8,0.8,0.8,1)        --Teva added this line to make icons white when complete
                                --    label:SetText("Done for Today")        --Teva is trying to add a tooltip to the icon, but neither tooltip nor label seem to do it
                                --    label:SetAnchor(TOPLEFT, texture, TOPRIGHT, 2, 0)
                                elseif LeoAltholic.IsBeforeReset(writ.lastStarted) then
                                --    isBetween = true            --Status: Need Today's Writ, completed old writ
                                    icon:SetColor(0.9,0,0,1)        --red
                                --    label:SetText("Need Today's Writ (completed old writ)")    --Teva is trying to add a tooltip to the icon, but neither tooltip nor label seem to do it
                                --TevaNOTE: try adjusting the labels above until show as tooltip
                                end
                            elseif writ.lastPreDeliver ~= nil then
                            --    isPreDeliver = true            --Status: Ready to Deliver
                                icon:SetColor(0,1,0,1)        --now green, was yellow(1,1,0,1)
                            elseif writ.lastUpdated ~= nil then
                            --    isUpdated = true            --Status: Partially Complete
                                icon:SetColor(1,1,0,1)        --now yellow, was darkyellow(1,0.8,0,1)
                            else
                            --    isStarted = true            --Status: Quest Acquired, No Progress
                                icon:SetColor(1,0.5,0,1)    --now orange, was (0.8,0.8,0.8,1)
                            end
                        else    --TevaNOTE: if writ.lastStarted == nil then
                            icon:SetColor(1,0,0,1)        --red
                        end
                        --Teva adjusted colors and conditions above
                        if not isDone or not LeoAltholic.ToolbarUI.GetHideDoneWrit() then
                            shownChecklist = true
                            icon:SetHidden(false)
                            icon:SetAnchor(TOPLEFT, checklist, TOPLEFT, checklistOffsetX, -2)
                            checklistOffsetX = checklistOffsetX + 30    --TevaNOTE: was +35
                            offsetX = offsetX + 30            --TevaNOTE: was +35
                        else
                        --Teva plans to add an "if" condition to not hide the checklist if lastStart time was before DailyReset time
                        --    if LeoAltholic.IsBeforeReset(writ.lastStarted) then icon:SetHidden(false) end
                            icon:SetHidden(true)
                        end
                    end
                end
            else
                icon:SetHidden(true)    --TevaNOTE: making false should make that craft's writ status always show on the toolbar even if not shown on the checklist
            end
        end
        -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
        -- RIDING --
        icon = GetControl(checklist, "RidingIcon")
        icon:SetHidden(true)
--Teva added 2nd condition on next line: and riding training not complete
        if char.attributes.riding.time - GetTimeStamp() < 0 and LeoAltholic.ChecklistUI.GetRiding() then
            shownChecklist = true
            icon:SetHidden(false)
            icon:SetColor(1,0,0,1)
            icon:SetAnchor(TOPLEFT, checklist, TOPLEFT, checklistOffsetX, -4)
			checklistOffsetX = checklistOffsetX + 35
			offsetX = offsetX + 30
        end
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- ChecklistLine (associated with Writs) --
    else
        checklist:SetHidden(true) --TevaNOTE: should show/hide all writ status icons
    end

    if shownChecklist then
        line = GetControl(toolbar, "ChecklistLine")
        line:SetHidden(false)
        line:SetAnchor(TOPLEFT, checklist, TOPLEFT, 2, 0)
        line:SetAnchor(BOTTOMRIGHT, checklist, BOTTOMLEFT, 2, 0)
    end
    totalWidth = totalWidth + checklistOffsetX
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- RESEARCH ON TOOLBAR --
    line = GetControl(toolbar, "CraftLine")
    line:SetHidden(true)
    for _,craft in pairs(LeoAltholic.craftResearch) do
        label = GetControl(toolbar, "Craft"..craft)
        texture = GetControl(toolbar, "Craft"..craft.."Texture")
        label:SetHidden(true)
        texture:SetHidden(true)
    end
    if LeoAltholic.ToolbarUI.GetItem(LeoAltholic.ToolbarUI.items.RESEARCH) then
        local firstTexture
        for _,craft in pairs(LeoAltholic.craftResearch) do
            if LeoAltholic.HasStillResearchFor(craft) then
                label = GetControl(toolbar, "Craft"..craft)
                texture = GetControl(toolbar, "Craft"..craft.."Texture")
                if firstTexture == nil then
                    firstTexture = texture
                end
                local researching, total, lowest = LeoAltholic.GetResearchCounters(craft)
                local missing = LeoAltholic.GetNumMissingTraitsFor(craft)
                local color = '|c'..LeoAltholic.color.hex.green
                if researching < total and researching < missing then
                    color = '|c'..LeoAltholic.color.hex.red
                end
                label:SetText(color .. researching .. '/' .. total .. '|r ' .. LeoAltholic.FormatTime(lowest - GetTimeStamp(), true, true))
                label:SetHidden(false)
                texture:SetHidden(false)
                texture:SetAnchor(TOPLEFT, toolbar, TOPLEFT, offsetX, 0)
                label:SetAnchor(TOPLEFT, texture, TOPRIGHT, 2, 0)
                offsetX = offsetX + width
                numSections = numSections + 1
                totalWidth = totalWidth + 120
            end
        end
        if firstTexture ~= nil then
            line:SetHidden(false)
            line:SetAnchor(TOPLEFT, firstTexture, TOPLEFT, 2, 0)
            line:SetAnchor(BOTTOMRIGHT, firstTexture, BOTTOMLEFT, 2, 0)
        end
    end
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- RIDING --
    line = GetControl(toolbar, "RidingLine")
    label = GetControl(toolbar, "Riding")
    texture = GetControl(toolbar, "RidingTexture")
    line:SetHidden(true)
    label:SetHidden(true)
    texture:SetHidden(true)
    if LeoAltholic.ToolbarUI.GetItem(LeoAltholic.ToolbarUI.items.RIDING) and
            (char.attributes.riding.speed < char.attributes.riding.speedMax or
            char.attributes.riding.stamina < char.attributes.riding.staminaMax or
            char.attributes.riding.capacity < char.attributes.riding.capacityMax) then
        label:SetText(LeoAltholic.FormatTime(char.attributes.riding.time - GetTimeStamp(), true, true))
        label:SetHidden(false)
        texture:SetHidden(false)
        line:SetHidden(false)
        texture:SetAnchor(TOPLEFT, toolbar, TOPLEFT, offsetX, 0)
        line:SetAnchor(TOPLEFT, texture, TOPLEFT, 2, 0)
        line:SetAnchor(BOTTOMRIGHT, texture, BOTTOMLEFT, 2, 0)
        offsetX = offsetX + 100
        numSections = numSections + 1
        totalWidth = totalWidth + 100 --TevaNOTE: was +130
    end
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
    if numSections > 0 then
        toolbar:SetWidth(totalWidth)
        GetControl(toolbar, "BG"):SetWidth(totalWidth)
        checkCenter()
    else
        toolbar:SetHidden(true)
    end
end
