local LeoAltholic = LeoAltholic
local lastStarted = nil
local lastUpdated = nil
local lastPreDeliver = nil

function LeoAltholic.ChecklistUI.normalizeSettings()
    if not LeoAltholic.globalData.checklist then LeoAltholic.globalData.checklist = {} end
    if not LeoAltholic.globalData.settings.checklist then LeoAltholic.globalData.settings.checklist = {} end
    if not LeoAltholic.charData.settings.checklist then LeoAltholic.charData.settings.checklist = {} end
end

function LeoAltholic.ChecklistUI.SetPosition(left, top)
    LeoAltholic.globalData.checklist.position = {
        left = left,
        top = top
    }
end
function LeoAltholic.ChecklistUI.GetPosition()
    return LeoAltholic.globalData.checklist.position or { left = 950; top = 42; }    --TevaNOTE was: { left = 100; top = 200; }
end

function LeoAltholic.ChecklistUI.SetFontScale(value)
    LeoAltholic.globalData.settings.checklist.fontScale = value
    LeoAltholic.ChecklistUI.update()
end
function LeoAltholic.ChecklistUI.GetFontScale()
    return LeoAltholic.globalData.settings.checklist.fontScale or 100
end
function LeoAltholic.ChecklistUI.SetMinimized(value)
    LeoAltholic.globalData.settings.checklist.minimized = value
end
function LeoAltholic.ChecklistUI.IsMinimized()
    if LeoAltholic.globalData.settings.checklist.minimized == nil then LeoAltholic.globalData.settings.checklist.minimized = false end
    return LeoAltholic.globalData.settings.checklist.minimized
end
function LeoAltholic.ChecklistUI.SetDisplayName(value)
    LeoAltholic.globalData.settings.checklist.displayName = value
    LeoAltholic.ChecklistUI.update()
end
function LeoAltholic.ChecklistUI.DisplayName()
    if LeoAltholic.globalData.settings.checklist.displayName == nil then LeoAltholic.globalData.settings.checklist.displayName = false end    --TevaNOTE: was true
    return LeoAltholic.globalData.settings.checklist.displayName
end
function LeoAltholic.ChecklistUI.SetHideWhenToolbar(value)
    LeoAltholic.globalData.settings.checklist.hideWhenToolbar = value
    LeoAltholic.ChecklistUI.update()
end
function LeoAltholic.ChecklistUI.IsHideWhenToolbar()
    if LeoAltholic.globalData.settings.checklist.hideWhenToolbar == nil then LeoAltholic.globalData.settings.checklist.hideWhenToolbar = true end    --TevaNOTE: was false
    return LeoAltholic.globalData.settings.checklist.hideWhenToolbar
end

function LeoAltholic.ChecklistUI.SetUpwards(value)
    LeoAltholic.globalData.settings.checklist.upwards = value
    LeoAltholic.ChecklistUI.update()
end
function LeoAltholic.ChecklistUI.IsUpwards()
    return LeoAltholic.globalData.settings.checklist.upwards or false
end

function LeoAltholic.ChecklistUI.SetEnabled(value)
    LeoAltholic.charData.settings.checklist.enabled = value
    LeoAltholic.ChecklistUI.RestorePosition()
end

function LeoAltholic.ChecklistUI.IsEnabled()
    if not LeoAltholic.charData
        or not LeoAltholic.charData.settings
        or not LeoAltholic.charData.settings.checklist then
        return false
    end
    return LeoAltholic.charData.settings.checklist.enabled
end

function LeoAltholic.ChecklistUI.SetCraft(craft, value)
    if not LeoAltholic.charData.settings.checklist.craft then LeoAltholic.charData.settings.checklist.craft = {} end
    LeoAltholic.charData.settings.checklist.craft[craft] = value
    LeoAltholic.ChecklistUI.update()
end
function LeoAltholic.ChecklistUI.GetCraft(craft)
    if not LeoAltholic.charData.settings.checklist.craft then LeoAltholic.charData.settings.checklist.craft = {} end
    return LeoAltholic.charData.settings.checklist.craft[craft]
end
function LeoAltholic.ChecklistUI.SetRiding(value)
    LeoAltholic.charData.settings.checklist.riding = value
    LeoAltholic.ChecklistUI.update()
end
function LeoAltholic.ChecklistUI.GetRiding()
    if LeoAltholic.charData.settings.checklist.riding == nil then LeoAltholic.charData.settings.checklist.riding = true end
    local char = LeoAltholic.GetMyself()
    return LeoAltholic.charData.settings.checklist.riding and
        (char.attributes.riding.speed < char.attributes.riding.speedMax or
        char.attributes.riding.stamina < char.attributes.riding.staminaMax or
        char.attributes.riding.capacity < char.attributes.riding.capacityMax)
end

function LeoAltholic.ChecklistUI.OnWindowMoveStop()
    LeoAltholic.ChecklistUI.SetPosition(LeoAltholicChecklist:GetLeft(), LeoAltholicChecklist:GetTop())
end

function LeoAltholic.ChecklistUI.ToggleUI()
    if not LeoAltholic.ChecklistUI.IsEnabled() then return end
    LeoAltholicChecklist:SetHidden(not LeoAltholicChecklist:IsHidden())
end

function LeoAltholic.ChecklistUI.ShowUI()
    if not LeoAltholic.ChecklistUI.IsEnabled() then return end
    LeoAltholicChecklist:SetHidden(false)
end

function LeoAltholic.ChecklistUI.CheckHide()
    if not LeoAltholic.ChecklistUI.IsEnabled() or LeoAltholic.ChecklistUI.IsHideWhenToolbar() then
        LeoAltholicChecklist:SetHidden(true)
        return
    end

    if LeoAltholic.ChecklistUI.checkAllDone() then
        LeoAltholicChecklist:SetHidden(true)
        return
    end

    LeoAltholicChecklist:SetHidden(false)
    LeoAltholic.ChecklistUI.MaximizeUI()
end

function LeoAltholic.ChecklistUI.RestorePosition()
    local position = LeoAltholic.ChecklistUI.GetPosition()
    local left = position.left
    local top = position.top
    LeoAltholicChecklist:ClearAnchors()
    LeoAltholicChecklist:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    LeoAltholic.ChecklistUI:CheckHide()
end

local SPACE = 34
local checklist = WINDOW_MANAGER:GetControlByName("LeoAltholicChecklist")
local panel = GetControl(checklist, "Panel")
local height = 0
local checklistHeight = 0
local checklistSavedTop = 0
local lastChecklist = GetTimeStamp()

function LeoAltholic.ChecklistUI.MinimizeUI()
    if not LeoAltholic.ChecklistUI.IsEnabled() then return end
    checklistSavedTop = checklist:GetTop()
    local header = GetControl(checklist, "BGHeader")
    local headerHeight = header:GetHeight()
    local headerTop = header:GetTop()
    local headerBottom = header:GetBottom()

    panel:SetHidden(true)
    LeoAltholicChecklistMinButton:SetHidden(true)
    LeoAltholicChecklistMaxButton:SetHidden(false)

    checklist:SetHeight(headerHeight)
--    checklist:ClearAnchors()

    if LeoAltholic.ChecklistUI.IsUpwards() then
        checklist:SetAnchor(BOTTOMLEFT, GuiRoot, TOPLEFT, checklist:GetLeft(), headerBottom)
    else
        checklist:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, checklist:GetLeft(), headerTop)
    end

    LeoAltholic.ChecklistUI.SetMinimized(true)
end

function LeoAltholic.ChecklistUI.MaximizeUI()
    if not LeoAltholic.ChecklistUI.IsEnabled() then return end
    panel:SetHidden(false)
    LeoAltholicChecklistMinButton:SetHidden(false)
    LeoAltholicChecklistMaxButton:SetHidden(true)

--    checklist:ClearAnchors()
--    checklist:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, checklist:GetLeft(), checklistSavedTop)
    checklist:SetHeight(checklistHeight)

    LeoAltholic.ChecklistUI.SetMinimized(false)
end

local function createItem(label, labelText, texture, craftIcon, canShow)
    if canShow == true then
--Teva changed lines below
        texture:SetTexture("esoui/art/buttons/decline_up.dds")
        texture.tooltip = "Never Done or Needs /reloadUI"
--        texture:SetColor(1,0,0,1) --red
--Teva changed lines above
        texture:SetDimensions(32, 32)
        texture:SetAnchor(TOPLEFT, panel, TOPLEFT, 10, height)
        local scaledSpace = SPACE * (LeoAltholic.ChecklistUI.GetFontScale() / 100)
        height = height + scaledSpace
        if LeoAltholic.ChecklistUI.DisplayName() then
            label:SetText(labelText)
            label:SetHidden(false)
            craftIcon:SetHidden(true)
        else
            craftIcon:SetHidden(false)
            label:SetHidden(true)
        end
        texture:SetHidden(false)
    else
        label:SetHidden(true)
        texture:SetHidden(true)
        craftIcon:SetHidden(true)
    end
end

function LeoAltholic.ChecklistUI.checkReset()
    if LeoAltholic.IsBeforeReset(lastChecklist) then
        LeoAltholic.ChecklistUI.update()
        lastChecklist = GetTimeStamp()
    end
end

local function doneItem(label, texture)    --Teva changed these settings
    texture:SetTexture("esoui/art/cadwell/checkboxicon_checked.dds")    --("esoui/art/buttons/checkbox_checked.dds") --("esoui/art/loot/loot_finesseItem.dds")
    texture:SetColor(0.7,0.7,0.7,1) --now gray instead of green(0,1,0,1)
    texture.tooltip = "Done for Today"    --TevaNOTE: consider labeling as "Delivered, /reloadUI to check if new writ may be available" after was GetString(SI_ACHIEVEMENTS_TOOLTIP_COMPLETE)
end

local function writdoneItem(label, texture)    --Teva added this function
    texture:SetTexture("esoui/art/buttons/checkbox_checked.dds")        --("esoui/art/cadwell/checkboxicon_checked.dds")    --("esoui/art/cadwell/checkboxicon_unchecked.dds") --("esoui/art/buttons/decline_up.dds")
    texture:SetColor(1,1,1,1)            --TevaNOTE: was (1,0,0,1) --red
    texture.tooltip = "Quest Completed, /reloadUI or look to toolbar to see if Today's Writ may be available"
end                --Teva added this function

local function betweenItem(label, texture)    --Teva added this function
    texture:SetTexture("esoui/art/cadwell/checkboxicon_unchecked.dds") --("esoui/art/buttons/decline_up.dds")
    texture:SetColor(1,0,0,1) --red
    texture.tooltip = "Need Today's Writ"
end    --eof added by Teva

local function startItem(label, texture)    --Teva changed these settings
    texture:SetTexture("esoui/art/buttons/pointsminus_up.dds")
    texture:SetColor(1,0.5,0,1) --now orange instead of white(1,1,1,1)
    texture.tooltip = "Have Quest, No Progress"
end

local function updateItem(label, texture)    --Teva changed these settings
    texture:SetTexture("esoui/art/buttons/pointsplus_up.dds")
    texture:SetColor(1,1,0,1) --now yellow instead of darkyellow(1,0.9,0,1)
    texture.tooltip = "Partially Complete"
end

local function preDeliverItem(label, texture)    --Teva changed these settings
    texture:SetTexture("esoui/art/loot/loot_finesseItem.dds") --("esoui/art/buttons/decline_up.dds" or "esoui/art/loot/loot_finesseItem.dds")
    texture:SetColor(0,1,0,1) --now green instead of yellow(1,1,0,1)
    texture.tooltip = "Ready for Delivery"
end

local function stoppedItem(label, texture)    --Teva changed these settings
    texture:SetTexture("esoui/art/buttons/decline_up.dds")
    texture:SetColor(1,0,0,1) --red
    texture.tooltip = "Quest Abandoned"
end

function LeoAltholic.ChecklistUI.checkAllDone()
    local char = LeoAltholic.GetMyself()

    for _, craft in pairs(LeoAltholic.allCrafts) do
        if LeoAltholic.ChecklistUI.GetCraft(craft) then
            for _, writ in pairs(char.quests.writs) do
                if craft == writ.craft then
--                    if writ.lastDone == nil or not LeoAltholic.IsAfterReset(writ.lastDone) then return false end
--next section modified by Teva to add more conditions
                    if writ.lastDone == nil or writ.lastStarted == nil then
                        return false
                    elseif LeoAltholic.IsBeforeReset(writ.lastStarted) then
                        return false
                    elseif LeoAltholic.IsBeforeReset(writ.lastDone) then
                        return false
                    elseif writ.lastDone < writ.lastStarted then
                        return false
                    end
--end Teva's mods
                end
            end
        end
    end
    if LeoAltholic.ChecklistUI.GetRiding() and char.attributes.riding.time - GetTimeStamp() < 0 then
        return false
    end

    return true
end

function LeoAltholic.ChecklistUI.doneWrit(craft)
    lastUpdated = nil
    lastPreDeliver = nil
--TevaNOTE: above lines added by Teva
    if not LeoAltholic.ChecklistUI.IsEnabled() then return end
    local label = GetControl(panel, "Craft"..craft)
    local texture = GetControl(panel, "Craft"..craft.."Status")
    writdoneItem(label, texture)        --TevaNOTE: was doneItem but was always saying that instead of between, so modified to at least warn it might be wrong
    LeoAltholic.ChecklistUI.update()    --TevaNOTE: this line may be the key to solving the between/done issue in the checklist!
end

function LeoAltholic.ChecklistUI.betweenWrit(craft) --Teva added this function
    lastUpdated = nil
    lastPreDeliver = nil
    if not LeoAltholic.ChecklistUI.IsEnabled() then return end
    local label = GetControl(panel, "Craft"..craft)
    local texture = GetControl(panel, "Craft"..craft.."Status")
    betweenItem(label, texture)
end

function LeoAltholic.ChecklistUI.startedWrit(craft)
    if not LeoAltholic.ChecklistUI.IsEnabled() then return end
    local label = GetControl(panel, "Craft"..craft)
    local texture = GetControl(panel, "Craft"..craft.."Status")
    startItem(label, texture)
end

function LeoAltholic.ChecklistUI.updateWrit(craft)
    if not LeoAltholic.ChecklistUI.IsEnabled() then return end
    local label = GetControl(panel, "Craft"..craft)
    local texture = GetControl(panel, "Craft"..craft.."Status")
    updateItem(label, texture)
end

function LeoAltholic.ChecklistUI.preDeliverWrit(craft)
    if not LeoAltholic.ChecklistUI.IsEnabled() then return end
    local label = GetControl(panel, "Craft"..craft)
    local texture = GetControl(panel, "Craft"..craft.."Status")
    preDeliverItem(label, texture)
end

function LeoAltholic.ChecklistUI.stoppedWrit(craft)
    lastStarted = nil
    lastUpdated = nil
    lastPreDeliver = nil
--TevaNOTE: above lines added by Teva
    if not LeoAltholic.ChecklistUI.IsEnabled() then return end
    local label = GetControl(panel, "Craft"..craft)
    local texture = GetControl(panel, "Craft"..craft.."Status")
    stoppedItem(label, texture)
end

function LeoAltholic.ChecklistUI.doneRiding()
    if not LeoAltholic.ChecklistUI.IsEnabled() then return end
    local label = GetControl(panel, "Riding")
    local texture = GetControl(panel, "RidingStatus")
    doneItem(label, texture)
    LeoAltholic.ChecklistUI.update()
end

function LeoAltholic.ChecklistUI.initializeQuests()
    for i,trackedQuest in pairs(LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.writs) do
        for questIndex = 1, MAX_JOURNAL_QUESTS do
            if IsValidQuestIndex(questIndex) and GetJournalQuestName(questIndex) == trackedQuest.name then
                if LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.writs[i].lastStarted == nil then
                    LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.writs[i].questIndex = questIndex
                    LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.writs[i].lastPreDeliver = nil
                    LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.writs[i].lastUpdated = nil
                    LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.writs[i].lastStarted = GetTimeStamp()    --TevaNOTE: had this commented out earlier, consider again if between becomes broken
--TevaNOTE: nest these above lines in an if or move the line above that is commented out here to where it only happens at the start of the quest, this function is called in initialize() onAddonLoaded
                end
                LeoAltholic.ChecklistUI.startedWrit(trackedQuest.craft)

                local hasUpdated = false
                local numConditions = GetJournalQuestNumConditions(questIndex, QUEST_MAIN_STEP_INDEX)
                for condition = 1, numConditions do
                    local current, max =  GetJournalQuestConditionValues(questIndex, QUEST_MAIN_STEP_INDEX, condition)
                    if hasUpdated == false and current > 0 then hasUpdated = true end
                    local condText = GetJournalQuestConditionInfo(questIndex, QUEST_MAIN_STEP_INDEX, condition)
                    if string.find(condText, GetString(LEOALT_DELIVER)) then
                        LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.writs[i].lastPreDeliver = GetTimeStamp()
                        LeoAltholic.ChecklistUI.preDeliverWrit(trackedQuest.craft)
                        break
                    end
                end
                if hasUpdated then
                    LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.writs[i].lastUpdated = GetTimeStamp()
                    LeoAltholic.ChecklistUI.updateWrit(trackedQuest.craft)
                end
                break
            end
        end
        -- if not isDone then LeoAltholic.ChecklistUI.MaximizeUI() end        --Teva added this function here
    end
end

function LeoAltholic.ChecklistUI.update()
    if not LeoAltholic.ChecklistUI.IsEnabled() then return end
    local char = LeoAltholic.GetMyself()
    local texture, label, craftIcon
    height = 0
    local scale = LeoAltholic.ChecklistUI.GetFontScale() / 100
    for _, craft in pairs(LeoAltholic.allCrafts) do
        label = GetControl(panel, "Craft"..craft)
        craftIcon = GetControl(panel, "Craft"..craft.."Icon")
        texture = GetControl(panel, "Craft"..craft.."Status")
        local isDone = false
        local isBetween = false
        local isPreDeliver = false
        local isUpdated = false
        local isStarted = false
        for _, writ in pairs(char.quests.writs) do
            if craft == writ.craft then
                if writ.lastStarted ~= nil then
                    if writ.lastDone ~= nil and writ.lastDone > writ.lastStarted then
                        if LeoAltholic.IsBeforeReset(writ.lastStarted) then    --
                            isBetween = true            --Status: Need Today's Writ, completed old writ
                        --    icon:SetColor(1,0,0,1)        --red
                        elseif LeoAltholic.IsAfterReset(writ.lastStarted) then        --
                            isDone = true                --Status: Done for Today    --
                        --    icon:SetColor(1,1,1,1)        --Teva added this line to make icons white when complete
                        end                                                            --
                    elseif writ.lastPreDeliver ~= nil then
                        isPreDeliver = true            --Status: Ready to Deliver
                    --    icon:SetColor(0,1,0,1)        --now green, was yellow(1,1,0,1)
                    elseif writ.lastUpdated ~= nil then
                        isUpdated = true
                    --    icon:SetColor(1,1,0,1)        --now yellow, was darkyellow(1,0.8,0,1)
                    else    --if writ.lastStarted ~= nil then
                        isStarted = true            --Status: Quest Acquired, No Progress
                    --    icon:SetColor(1,0.5,0,1)    --now orange,was???(0.8,0.8,0.8,1)
                    end
                else    --if writ.lastStarted == nil then
                    texture:SetTexture("esoui/art/cadwell/checkboxicon_unchecked.dds")
                    texture:SetColor(1,0,0,1) --red
                    texture.tooltip = "Not Started While this Addon was active"
                end
            end
        end
        local canShow = LeoAltholic.ChecklistUI.GetCraft(craft)
        createItem(label, ZO_CachedStrFormat(SI_ABILITY_NAME, ZO_GetCraftingSkillName(craft)), texture, craftIcon, canShow)
        if canShow == true then
            if isDone then
                doneItem(label, texture)
            elseif isBetween then    --Teva added the isBetween condition and effects
                betweenItem(label, texture)
            elseif isPreDeliver then
                preDeliverItem(label, texture)
            elseif isUpdated then
                updateItem(label, texture)
            elseif isStarted then
                startItem(label, texture)
            else
                texture:SetTexture("esoui/art/buttons/decline_up.dds")
                texture.tooltip = "Never Done or Needs Reload UI"
                --texture:SetColor(1,0,0,1) --red
            end
        end
    end

    label = GetControl(panel, "Riding")
    label:SetColor(1,1,1,1)
    texture = GetControl(panel, "RidingStatus")
    craftIcon = GetControl(panel, "RidingIcon")
    createItem(label, GetString(SI_STAT_GAMEPAD_RIDING_HEADER_TRAINING), texture, craftIcon, LeoAltholic.ChecklistUI.GetRiding())
    if char.attributes.riding.time > 0 and char.attributes.riding.time - GetTimeStamp() > 0 then
        doneItem(label, texture)
    else
        betweenItem(label, texture)
    end
    checklistHeight = height + 2*(100 - LeoAltholic.ChecklistUI.GetFontScale())
    checklist:SetHeight(checklistHeight)
    panel:SetHeight(checklistHeight)
    panel:ClearAnchors()
    local header = GetControl(checklist, "BGHeader")
    header:ClearAnchors()
    if LeoAltholic.ChecklistUI.IsUpwards() then
        header:SetAnchor(BOTTOMLEFT, checklist, BOTTOMLEFT, 0, 0)
        panel:SetAnchor(BOTTOMLEFT, header, TOPLEFT, 0, 2)
    else
        header:SetAnchor(TOPLEFT, checklist, TOPLEFT, 0, 0)
        panel:SetAnchor(TOPLEFT, header, BOTTOMLEFT, 0, 2)
    end

    local width = 200
    if not LeoAltholic.ChecklistUI.DisplayName() then
        width = 120
    end
    checklist:SetWidth(width)
    panel:SetWidth(width)
    header:SetWidth(width)
    checklist:SetScale(scale)

    LeoAltholic.ChecklistUI:CheckHide()
end
