local lastStarted = nil
local lastUpdated = nil
local lastPreDeliver = nil


function LeoAltholicChecklistUI.normalizeSettings()
    if not LeoAltholic.globalData.checklist then LeoAltholic.globalData.checklist = {} end
    if not LeoAltholic.globalData.settings.checklist then LeoAltholic.globalData.settings.checklist = {} end
    if not LeoAltholic.charData.settings.checklist then LeoAltholic.charData.settings.checklist = {} end
end

function LeoAltholicChecklistUI.SetPosition(left, top)
    LeoAltholic.globalData.checklist.position = {
        left = left,
        top = top
    }
end
function LeoAltholicChecklistUI.GetPosition()
    return LeoAltholic.globalData.checklist.position or { left = 950; top = 42; }    --TevaNOTE was: { left = 100; top = 200; }
end

function LeoAltholicChecklistUI.SetFontScale(value)
    LeoAltholic.globalData.settings.checklist.fontScale = value
    LeoAltholicChecklistUI.update()
end
function LeoAltholicChecklistUI.GetFontScale()
    return LeoAltholic.globalData.settings.checklist.fontScale or 100
end
function LeoAltholicChecklistUI.SetMinimized(value)
    LeoAltholic.globalData.settings.checklist.minimized = value
end
function LeoAltholicChecklistUI.IsMinimized()
    if LeoAltholic.globalData.settings.checklist.minimized == nil then LeoAltholic.globalData.settings.checklist.minimized = false end
    return LeoAltholic.globalData.settings.checklist.minimized
end
function LeoAltholicChecklistUI.SetDisplayName(value)
    LeoAltholic.globalData.settings.checklist.displayName = value
    LeoAltholicChecklistUI.update()
end
function LeoAltholicChecklistUI.DisplayName()
    if LeoAltholic.globalData.settings.checklist.displayName == nil then LeoAltholic.globalData.settings.checklist.displayName = false end    --TevaNOTE: was true
    return LeoAltholic.globalData.settings.checklist.displayName
end
function LeoAltholicChecklistUI.SetHideWhenToolbar(value)
    LeoAltholic.globalData.settings.checklist.hideWhenToolbar = value
    LeoAltholicChecklistUI.update()
end
function LeoAltholicChecklistUI.IsHideWhenToolbar()
    if LeoAltholic.globalData.settings.checklist.hideWhenToolbar == nil then LeoAltholic.globalData.settings.checklist.hideWhenToolbar = true end    --TevaNOTE: was false
    return LeoAltholic.globalData.settings.checklist.hideWhenToolbar
end

function LeoAltholicChecklistUI.SetUpwards(value)
    LeoAltholic.globalData.settings.checklist.upwards = value
    LeoAltholicChecklistUI.update()
end
function LeoAltholicChecklistUI.IsUpwards()
    return LeoAltholic.globalData.settings.checklist.upwards or false
end

function LeoAltholicChecklistUI.SetEnabled(value)
    LeoAltholic.charData.settings.checklist.enabled = value
    LeoAltholicChecklistUI.RestorePosition()
end

function LeoAltholicChecklistUI.IsEnabled()
    if not LeoAltholic.charData
        or not LeoAltholic.charData.settings
        or not LeoAltholic.charData.settings.checklist then
        return false
    end
    return LeoAltholic.charData.settings.checklist.enabled
end

function LeoAltholicChecklistUI.SetCraft(craft, value)
    if not LeoAltholic.charData.settings.checklist.craft then LeoAltholic.charData.settings.checklist.craft = {} end
    LeoAltholic.charData.settings.checklist.craft[craft] = value
    LeoAltholicChecklistUI.update()
end
function LeoAltholicChecklistUI.GetCraft(craft)
    if not LeoAltholic.charData.settings.checklist.craft then LeoAltholic.charData.settings.checklist.craft = {} end
    return LeoAltholic.charData.settings.checklist.craft[craft]
end
function LeoAltholicChecklistUI.SetRiding(value)
    LeoAltholic.charData.settings.checklist.riding = value
    LeoAltholicChecklistUI.update()
end
function LeoAltholicChecklistUI.GetRiding()
    if LeoAltholic.charData.settings.checklist.riding == nil then LeoAltholic.charData.settings.checklist.riding = true end
    local char = LeoAltholic.GetMyself()
    return LeoAltholic.charData.settings.checklist.riding and
        (char.attributes.riding.speed < char.attributes.riding.speedMax or
        char.attributes.riding.stamina < char.attributes.riding.staminaMax or
        char.attributes.riding.capacity < char.attributes.riding.capacityMax)
end

function LeoAltholicChecklistUI.OnWindowMoveStop()
    LeoAltholicChecklistUI.SetPosition(LeoAltholicChecklist:GetLeft(), LeoAltholicChecklist:GetTop())
end

function LeoAltholicChecklistUI.ToggleUI()
    if not LeoAltholicChecklistUI.IsEnabled() then return end
    LeoAltholicChecklist:SetHidden(not LeoAltholicChecklist:IsHidden())
end

function LeoAltholicChecklistUI.ShowUI()
    if not LeoAltholicChecklistUI.IsEnabled() then return end
    LeoAltholicChecklist:SetHidden(false)
end

function LeoAltholicChecklistUI.CheckHide()
    if not LeoAltholicChecklistUI.IsEnabled() or LeoAltholicChecklistUI.IsHideWhenToolbar() then
        LeoAltholicChecklist:SetHidden(true)
        return
    end

    if LeoAltholicChecklistUI.checkAllDone() then
        LeoAltholicChecklist:SetHidden(true)
        return
    end

    LeoAltholicChecklist:SetHidden(false)
    LeoAltholicChecklistUI.MaximizeUI()
end

function LeoAltholicChecklistUI.RestorePosition()
    local position = LeoAltholicChecklistUI.GetPosition()
    local left = position.left
    local top = position.top
    LeoAltholicChecklist:ClearAnchors()
    LeoAltholicChecklist:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    LeoAltholicChecklistUI:CheckHide()
end

local SPACE = 34
local checklist = WINDOW_MANAGER:GetControlByName("LeoAltholicChecklist")
local panel = GetControl(checklist, "Panel")
local height = 0
local checklistHeight = 0
local checklistSavedTop = 0
local lastChecklist = GetTimeStamp()

function LeoAltholicChecklistUI.MinimizeUI()
    if not LeoAltholicChecklistUI.IsEnabled() then return end
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

    if LeoAltholicChecklistUI.IsUpwards() then
        checklist:SetAnchor(BOTTOMLEFT, GuiRoot, TOPLEFT, checklist:GetLeft(), headerBottom)
    else
        checklist:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, checklist:GetLeft(), headerTop)
    end

    LeoAltholicChecklistUI.SetMinimized(true)
end

function LeoAltholicChecklistUI.MaximizeUI()
    if not LeoAltholicChecklistUI.IsEnabled() then return end
    panel:SetHidden(false)
    LeoAltholicChecklistMinButton:SetHidden(false)
    LeoAltholicChecklistMaxButton:SetHidden(true)

--    checklist:ClearAnchors()
--    checklist:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, checklist:GetLeft(), checklistSavedTop)
    checklist:SetHeight(checklistHeight)

    LeoAltholicChecklistUI.SetMinimized(false)
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
        local scaledSpace = SPACE * (LeoAltholicChecklistUI.GetFontScale() / 100)
        height = height + scaledSpace
        if LeoAltholicChecklistUI.DisplayName() then
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

function LeoAltholicChecklistUI.checkReset()
    if LeoAltholic.IsBeforeReset(lastChecklist) then
        LeoAltholicChecklistUI.update()
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

function LeoAltholicChecklistUI.checkAllDone()
    local char = LeoAltholic.GetMyself()

    for _, craft in pairs(LeoAltholic.allCrafts) do
        if LeoAltholicChecklistUI.GetCraft(craft) then
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
    if LeoAltholicChecklistUI.GetRiding() and char.attributes.riding.time - GetTimeStamp() < 0 then
        return false
    end

    return true
end

function LeoAltholicChecklistUI.doneWrit(craft)
    lastUpdated = nil
    lastPreDeliver = nil
--TevaNOTE: above lines added by Teva
    if not LeoAltholicChecklistUI.IsEnabled() then return end
    local label = GetControl(panel, "Craft"..craft)
    local texture = GetControl(panel, "Craft"..craft.."Status")
    writdoneItem(label, texture)        --TevaNOTE: was doneItem but was always saying that instead of between, so modified to at least warn it might be wrong
    LeoAltholicChecklistUI.update()    --TevaNOTE: this line may be the key to solving the between/done issue in the checklist!
end

function LeoAltholicChecklistUI.betweenWrit(craft) --Teva added this function
    lastUpdated = nil
    lastPreDeliver = nil
    if not LeoAltholicChecklistUI.IsEnabled() then return end
    local label = GetControl(panel, "Craft"..craft)
    local texture = GetControl(panel, "Craft"..craft.."Status")
    betweenItem(label, texture)
end

function LeoAltholicChecklistUI.startedWrit(craft)
    if not LeoAltholicChecklistUI.IsEnabled() then return end
    local label = GetControl(panel, "Craft"..craft)
    local texture = GetControl(panel, "Craft"..craft.."Status")
    startItem(label, texture)
end

function LeoAltholicChecklistUI.updateWrit(craft)
    if not LeoAltholicChecklistUI.IsEnabled() then return end
    local label = GetControl(panel, "Craft"..craft)
    local texture = GetControl(panel, "Craft"..craft.."Status")
    updateItem(label, texture)
end

function LeoAltholicChecklistUI.preDeliverWrit(craft)
    if not LeoAltholicChecklistUI.IsEnabled() then return end
    local label = GetControl(panel, "Craft"..craft)
    local texture = GetControl(panel, "Craft"..craft.."Status")
    preDeliverItem(label, texture)
end

function LeoAltholicChecklistUI.stoppedWrit(craft)
    lastStarted = nil
    lastUpdated = nil
    lastPreDeliver = nil
--TevaNOTE: above lines added by Teva
    if not LeoAltholicChecklistUI.IsEnabled() then return end
    local label = GetControl(panel, "Craft"..craft)
    local texture = GetControl(panel, "Craft"..craft.."Status")
    stoppedItem(label, texture)
end

function LeoAltholicChecklistUI.doneRiding()
    if not LeoAltholicChecklistUI.IsEnabled() then return end
    local label = GetControl(panel, "Riding")
    local texture = GetControl(panel, "RidingStatus")
    doneItem(label, texture)
    LeoAltholicChecklistUI.update()
end

function LeoAltholicChecklistUI.initializeQuests()
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
                LeoAltholicChecklistUI.startedWrit(trackedQuest.craft)

                local hasUpdated = false
                local numConditions = GetJournalQuestNumConditions(questIndex, QUEST_MAIN_STEP_INDEX)
                for condition = 1, numConditions do
                    local current, max =  GetJournalQuestConditionValues(questIndex, QUEST_MAIN_STEP_INDEX, condition)
                    if hasUpdated == false and current > 0 then hasUpdated = true end
                    local condText = GetJournalQuestConditionInfo(questIndex, QUEST_MAIN_STEP_INDEX, condition)
                    if string.find(condText, GetString(LEOALT_DELIVER)) then
                        LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.writs[i].lastPreDeliver = GetTimeStamp()
                        LeoAltholicChecklistUI.preDeliverWrit(trackedQuest.craft)
                        break
                    end
                end
                if hasUpdated then
                    LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.writs[i].lastUpdated = GetTimeStamp()
                    LeoAltholicChecklistUI.updateWrit(trackedQuest.craft)
                end
                break
            end
        end
        -- if not isDone then LeoAltholicChecklistUI.MaximizeUI() end        --Teva added this function here
    end
end

function LeoAltholicChecklistUI.update()
    if not LeoAltholicChecklistUI.IsEnabled() then return end
    local char = LeoAltholic.GetMyself()
    local texture, label, craftIcon
    height = 0
    local scale = LeoAltholicChecklistUI.GetFontScale() / 100
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
        local canShow = LeoAltholicChecklistUI.GetCraft(craft)
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
    createItem(label, GetString(SI_STAT_GAMEPAD_RIDING_HEADER_TRAINING), texture, craftIcon, LeoAltholicChecklistUI.GetRiding())
    if char.attributes.riding.time > 0 and char.attributes.riding.time - GetTimeStamp() > 0 then
        doneItem(label, texture)
    else
        betweenItem(label, texture)
    end
    checklistHeight = height + 2*(100 - LeoAltholicChecklistUI.GetFontScale())
    checklist:SetHeight(checklistHeight)
    panel:SetHeight(checklistHeight)
    panel:ClearAnchors()
    local header = GetControl(checklist, "BGHeader")
    header:ClearAnchors()
    if LeoAltholicChecklistUI.IsUpwards() then
        header:SetAnchor(BOTTOMLEFT, checklist, BOTTOMLEFT, 0, 0)
        panel:SetAnchor(BOTTOMLEFT, header, TOPLEFT, 0, 2)
    else
        header:SetAnchor(TOPLEFT, checklist, TOPLEFT, 0, 0)
        panel:SetAnchor(TOPLEFT, header, BOTTOMLEFT, 0, 2)
    end

    local width = 200
    if not LeoAltholicChecklistUI.DisplayName() then
        width = 120
    end
    checklist:SetWidth(width)
    panel:SetWidth(width)
    header:SetWidth(width)
    checklist:SetScale(scale)

    LeoAltholicChecklistUI:CheckHide()
end
