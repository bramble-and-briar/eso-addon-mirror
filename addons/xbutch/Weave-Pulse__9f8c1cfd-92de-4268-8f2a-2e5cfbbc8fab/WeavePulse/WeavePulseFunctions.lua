-- Adapted from CombatMetronome 1.7.7 / DariansUtilities 1.8.7.
-- Original authors: Darianopolis and barny. Artistic License 2.0.
-- Upstream: CMFunctions.lua. See third-party/UPSTREAM.md for modifications.

local LAM = WeavePulse.Settings
local Util = WeavePulse.Util
Util.Text = Util.Text or {}
Util.Stacks = Util.Stacks or {}
WeavePulse.StackTracker = WeavePulse.StackTracker or {}
local StackTracker = WeavePulse.StackTracker

function WeavePulse:OnCDStop(reason)
    if WeavePulse.SV.Progressbar.dontHide then
        if WeavePulse.SV.Progressbar.makeItFancy then
            self:HideFancy(false)
        else
            self:HideFancy(true)
        end
    else
        self:HideFancy(true)
        self.Progressbar.bar:SetHidden(true)
    end
    self:HideLabels(true)
    self:ResetBarValues()

    if self.currentEvent then
        self:SetEventNil(reason)
    elseif reason == "" then
        self.abilityFinished = GetFrameTimeMilliseconds()
    else
        self:PrintDebug("cdStop", reason)
    end
end

function WeavePulse:ResetBarValues()
    self.Progressbar.bar.segments[1].progress = 0
    self.Progressbar.bar.segments[2].progress = 0
    self.Progressbar.bar.backgroundTexture:SetWidth(0)

    self.Progressbar.bar:Update()
end

function WeavePulse:HideBar(value)
    if WeavePulse.SV.Progressbar.makeItFancy then
        self:HideFancy(value)
    else
        self:HideFancy(true)
    end
    self.Progressbar.bar:SetHidden(value)
end

function WeavePulse:SetEventNil(reason)
    if self.currentEvent then
        self.currentEvent = nil
        self.abilityFinished = GetFrameTimeMilliseconds()
        Util.Ability.Tracker:CancelCurrentEvent(string.format("CM: %s", reason))
        Util.Ability.Tracker.lastAbilityFinished = 0
    end

    self:ResetBarValues()
end

function WeavePulse:HideLabels(value)
    self.Progressbar.spellLabel:SetHidden(value)
    self.Progressbar.timeLabel:SetHidden(value)
    self.Progressbar.spellIcon:SetHidden(value)
    self.Progressbar.spellIconBorder:SetHidden(value)
end

function WeavePulse:HideFancy(value)
    self.Progressbar.bar.backgroundTexture:SetHidden(value)
    self.Progressbar.bar.borderL:SetHidden(value)
    self.Progressbar.bar.borderR:SetHidden(value)
end

function WeavePulse:CreateMenuIconsPath(ControlName, panel)
    local number = 0
    for i, entry in ipairs(panel.controlsToRefresh) do
        if ControlName == entry.data.name then
            number = i
        end
    end
    return number
end

function WeavePulse:GCDSpecifics(text, icon, gcdProgress, wasSynergy)
    if not (text and icon) or gcdProgress == 0 then return end
    if not wasSynergy and self.Progressbar.synergy.wasUsed then self.Progressbar.synergy.wasUsed = false end
    if WeavePulse.SV.Progressbar.showSpell then
        self.Progressbar.spellLabel:SetHidden(false)
        self.Progressbar.spellIcon:SetHidden(false)
        self.Progressbar.spellIconBorder:SetHidden(false)
        self.Progressbar.spellIcon:SetTexture(icon)
        self.Progressbar.spellLabel:SetText(text)
    else
        self.Progressbar.spellLabel:SetHidden(true)
        self.Progressbar.spellIcon:SetHidden(true)
        self.Progressbar.spellIconBorder:SetHidden(true)
    end
    if WeavePulse.SV.Progressbar.showTimeRemaining then
        self.Progressbar.timeLabel:SetHidden(false)
        self.Progressbar.timeLabel:SetText(string.format("%.1fs", gcdProgress))
    else
        self.Progressbar.timeLabel:SetHidden(true)
    end
end

function WeavePulse:SetIconsAndNamesNil()
    if self.currentEvent then return end

    self.Progressbar.activeMount.action = ""
    self.Progressbar.collectibleInUse = nil
    self.Progressbar.itemUsed = nil
    self.Progressbar.festivalGCD = nil

    self.Progressbar.breakingFree = nil
    self.Progressbar.synergy.wasUsed = false

    self.Progressbar.timeLabel:SetHidden(true)
    self.Progressbar.spellLabel:SetHidden(true)
    self.Progressbar.spellIcon:SetHidden(true)
    self.Progressbar.spellIconBorder:SetHidden(true)

end

function WeavePulse:CheckForCombatEventsRegister()

    if WeavePulse.SV.Progressbar.trackMounting or WeavePulse.SV.Progressbar.trackSynergies or WeavePulse.SV.Progressbar.trackBreakingFree then
        return true
    end
    return false
end

local ABILITY_ADJUST_PLACEHOLDER = "Add ability adjust"

function WeavePulse:UpdateAdjustChoices()
    local names = self.menu.abilityAdjustChoices

    for k in pairs(names) do names[k] = nil end

    for id, adj in pairs(WeavePulse.SV.Progressbar.abilityAdjusts) do
        local name = "|t20:20:"..GetAbilityIcon(id).."|t "..Util.Text.CropZOSString(GetAbilityName(id), "ability")
        names[#names + 1] = name
    end

    if #names == 0 then
        names[1] = ABILITY_ADJUST_PLACEHOLDER
        self.menu.curSkillName = ABILITY_ADJUST_PLACEHOLDER
        self.menu.curSkillId = -1
    else
        if not WeavePulse.SV.Progressbar.abilityAdjusts[self.menu.curSkillId] then
            for id, _ in pairs(WeavePulse.SV.Progressbar.abilityAdjusts) do
                self.menu.curSkillId = id
                self.menu.curSkillName = GetAbilityName(id)
                break
            end
        end
    end

    local panelControls = self.menu.panels.Progressbar.controlsToRefresh
    for i = 1, #panelControls do
        local control = panelControls[i]
        if (control.data and control.data.name == "Select skill adjust") then
            control:UpdateChoices()
            control:UpdateValue()
            break
        end
    end
end

function WeavePulse:CreateAdjustList()
    local names = {}
    for id, adj in pairs(WeavePulse.SV.Progressbar.abilityAdjusts) do
        local name = "|t20:20:"..GetAbilityIcon(id).."|t "..Util.Text.CropZOSString(GetAbilityName(id), "ability")
        names[#names + 1] = name
    end
    if #names == 0 then table.insert(names, ABILITY_ADJUST_PLACEHOLDER) end
    return names
end

function WeavePulse:CropIconFromSkill(ability)
    local _, iconDivider = string.find(ability, "%|t ")

    if iconDivider then
        return string.sub(ability, iconDivider + 1, -1)
    else
        return ability
    end
end

function WeavePulse:FindSkillInAdjustList(name)
    for i, entry in ipairs(self.menu.abilityAdjustChoices) do
        if self:CropIconFromSkill(entry) == name then return i end
    end
end

function WeavePulse:IsSkillCurrentlyEquipped(id)
    for i, entry in ipairs(self.currentlyEquippedAbilities.data) do
        if id == entry.id then return i end
    end
    return false
end

function WeavePulse:GetEquippedSkillData(selectedSkill)
    for i, entry in ipairs(self.currentlyEquippedAbilities.list) do
        if entry == selectedSkill then

        return self.currentlyEquippedAbilities.data[i] end
    end
end

function WeavePulse:BuildListOfCurrentlyEquippedAbilities()
    self.Resources.executeAbilityThreshold = 0

    self.currentlyEquippedAbilities.data = Util.Stacks:StoreAbilitiesOnActionBar()

    if self.currentlyEquippedAbilities.list then
        for i in pairs(self.currentlyEquippedAbilities.list) do self.currentlyEquippedAbilities.list[i] = nil end
    end

    if not self.currentlyEquippedAbilities.list then self.currentlyEquippedAbilities.list = {} end

    local executeAbilityFound = false
    self.StackTracker.slottedSkills = {}
    for i, skill in ipairs(self.currentlyEquippedAbilities.data) do
        self.currentlyEquippedAbilities.list[i] = tostring("|t20:20:"..skill.icon.."|t "..skill.name)

        if self.StackTracker.AVAILABLE_TRACKING_IDS[skill.id] then
            self.StackTracker.slottedSkills[self.StackTracker.AVAILABLE_TRACKING_IDS[skill.id]] = true
        end

        if self.StackTracker.availableSkills.Crux and not self.StackTracker.slottedSkills.Crux then
            for _, data in ipairs(self.currentlyEquippedAbilities.data) do
                if self.StackTracker.ABILITIES_USING_OR_GENERATING_CRUX[data.id] then
                    self.StackTracker.slottedSkills.Crux = true
                    break
                end
                self.StackTracker.slottedSkills.Crux = false
            end
        end

        if self.Resources.EXECUTE_ABILITIES[skill.id] then

            self.Resources.executeAbilityThreshold = math.max(self.Resources.EXECUTE_ABILITIES[skill.id], self.Resources.executeAbilityThreshold)
        end

    end
    self:CalculateExecuteThreshold()

    local panelOptions = {
        Progressbar = "Currently equipped abilities:",
        General = "Add ability ID to debug whitelist",
    }

    for panel, option in pairs(panelOptions) do
        if self.menu.panels and self.menu.panels[panel] then
            local panelControls = self.menu.panels[panel].controlsToRefresh
            for i = 1, #panelControls do
                local control = panelControls[i]
                if (control.data and control.data.name == option) then

                    control:UpdateChoices()
                    control:UpdateValue()
                    break
                end
            end
        end
    end
end

function WeavePulse:CalculateExecuteThreshold()
    self.Resources.executeThreshold = math.max(WeavePulse.SV.Resources.showHealth and WeavePulse.SV.Resources.hpHighlightThreshold or 0, self.Resources.executeAbilityThreshold)
end

function WeavePulse:HandleAbilityUsed(event)
    local sv = WeavePulse.SV.Progressbar

    if not (self.inCombat or sv.showOOC) then return
    elseif sv.stopHATracking and event.ability.heavy then return
    end

    if event.ability then Util.Ability.Tracker:PrintDebugNotes("abilityUsed", event.ability.id, string.format("New event '%s' recieved in WeavePulse. ID: %d", event.ability.name, event.ability.id)) end

    local ability = event.ability

    event.adjust = (sv.abilityAdjusts[ability.id] or 0)
                    + ((ability.instant and sv.gcdAdjust)
                    or (ability.heavy and sv.globalHeavyAdjust)
                    or sv.globalAbilityAdjust)

    self.currentEvent = event

    Util.Ability.Tracker:PrintDebugNotes("currentEvent", ability.id, string.format("Current event is now '%s'", ability.name))

    if (sv.soundTickEnabled or sv.soundTockEnabled) and not (event.ability.heavy and sv.noTickOnHeavy) and not (sv.noSoundOnLongAbilities and event.ability.delay > 1000) then

        if sv.soundTickEnabled then self.Progressbar.soundTickPlayed = false end
        if sv.soundTockEnabled then self.Progressbar.soundTockPlayed = false end
    end

    self.lastAbilityFinished = self.abilityFinished
    self.abilityFinished = event.start + (ability.heavy and ability.delay or math.max(ability.delay, 1000))
    self.gcd = Util.Ability.Tracker.gcd
end

function StackTracker:MorphCheck()
    if StackTracker.availableSkills.FS and StackTracker.availableSkills.GF then

        Util.Stacks.morphs.GF = Util.Stacks:CheckMorph("GF")
        Util.Stacks.morphs.FS = Util.Stacks:CheckMorph("FS")
    elseif StackTracker.availableSkills.FS then

        Util.Stacks.morphs.FS = Util.Stacks:CheckMorph("FS")
        if Util.Stacks.morphs.GF then Util.Stacks.morphs.GF = nil end
    elseif StackTracker.availableSkills.GF then

        Util.Stacks.morphs.GF = Util.Stacks:CheckMorph("GF")
        if Util.Stacks.morphs.FS then Util.Stacks.morphs.FS = nil end
    else

        if Util.Stacks.morphs.GF then Util.Stacks.morphs.GF = nil end
        if Util.Stacks.morphs.FS then Util.Stacks.morphs.FS = nil end
    end
end

function StackTracker:TrackerIsActive(skill)
    if skill then

        if self.availableSkills[skill] and self.slottedSkills[skill] and WeavePulse.SV.StackTracker[skill].tracked then
            return true
        end
        return false
    else
        for skill, _ in pairs(self.SKILL_ATTRIBUTES) do

            if self.availableSkills[skill] and self.slottedSkills[skill] and WeavePulse.SV.StackTracker[skill].tracked then
                return true
            end
        end
        return false
    end
end

function StackTracker:CheckIfRegistered(skill)

        for _, aName in pairs(self.trackedIds) do
            if skill == aName then
                return true
            end
        end

    return false
end

function StackTracker:GetCurrentStacks(skill)
    local stacks

    if self.slottedSkills[skill] then
        stacks = Util.Stacks:GetCurrentNumStacksOnPlayer(skill)
        return stacks
    end
    return 0
end

function StackTracker:IsTrackingAvailable()
    for skill, entry in pairs(self.SKILL_ATTRIBUTES) do
        for _, id in ipairs(entry.skillLineId) do
            local _,_,isAvailable,_,_,_ = GetSkillLineDynamicInfo(GetSkillLineIndicesFromSkillLineId(id))
            self.availableSkills[skill] = isAvailable
            if isAvailable then break end
        end
    end

    for i in pairs(self.AVAILABLE_TRACKING_IDS) do
        self.AVAILABLE_TRACKING_IDS[i] = nil
    end
    for skill in pairs(self.availableSkills) do
        if self.availableSkills[skill] then
            for id, ability in pairs(self.ALL_IDS) do
                if skill == ability then self.AVAILABLE_TRACKING_IDS[id] = skill end
            end
        end
    end
end

function StackTracker:AbilityUpdater()
    StackTracker:IsTrackingAvailable()
    StackTracker:MorphCheck()
    WeavePulse:BuildListOfCurrentlyEquippedAbilities()

    for skill, _ in pairs(StackTracker.SKILL_ATTRIBUTES) do
        if WeavePulse.SV.StackTracker[skill].tracked then

            if StackTracker.availableSkills[skill] and StackTracker.slottedSkills[skill] then

                StackTracker:Register(skill)

            elseif not StackTracker.slottedSkills[skill] and StackTracker:CheckIfRegistered(skill) then

                StackTracker:Unregister(skill)
            end
        end
    end

end

function StackTracker:InitializeUI(skill)
    if not self.UI[skill] then
        self.UI[skill] = self:BuildUI(skill)

        self.UI[skill].indicator.ApplySize(WeavePulse.SV.StackTracker[skill].indicatorSize)
        self.UI[skill].indicator.ApplyIcon()
        self.UI[skill].stacksWindow:SetMovable(WeavePulse.SV.StackTracker.isUnlocked)
    end
    self:HandleUIVisibility(skill, "UI")
    self:UpdateTimers()
    if WeavePulse.SV.StackTracker.isUnlocked then self:HandleUIVisibility(skill, "Sample") end
end

function StackTracker:HandleUIVisibility(skill, scene)
    if StackTracker.UI[skill] then
        StackTracker.UI[skill].FadeScenes(scene)

    end
end

function StackTracker:HideTracker(skill, value)
    if self.UI[skill] then
        self.UI[skill].Hide(value)
    end
    self:UpdateTimers()
end

function WeavePulse:IsInPvPZone()
    if IsActiveWorldBattleground() or IsPlayerInAvAWorld() then
        self.inPVPZone = true
    else
        self.inPVPZone = false
    end

    return self.inPVPZone
end

function StackTracker:PVPSwitch(skill)
    if self:TrackerIsActive(skill) and self.UI[skill] then
        local registered = self:CheckIfRegistered(skill)
        if WeavePulse.SV.StackTracker[skill].hideInPVP and WeavePulse.inPVPZone then
            if registered then
                self:Unregister(skill)

            else
                self.UI[skill].FadeScenes("NoUi")

            end
        else
            if not registered then
                self:Register(skill)

            end
        end
    elseif self:TrackerIsActive(skill) and not self.UI[skill] and not WeavePulse.inPVPZone then

        self:Register(skill)
    end
end

local MENU_SOUND_CONTROLS = {
["Volume of 'tick' and 'tock'"] = true,
["Sound 'tick'"] = true,
["Sound 'tock'"] = true,
["Sound 'tick' effect"] = true,
["Sound 'tock' effect"] = true,
["Sound 'tick' offset"] = true,
["Sound 'tock' offset"] = true,
["Play 'tick' at the start of an ability"] = true,
["Don't play 'tick' on heavy attacks"] = true,
["Play sounds ooc"] = true,
}

function WeavePulse:RefreshSoundControls()

    WeavePulse.menu.panels.Progressbar:RefreshPanel()
end

function WeavePulse:PrintDebug(debugType, message)
    local debugs = WeavePulse.SV.debug

    if debugs[debugType] and self.lastDebugMessage ~= message then

        self.lastDebugMessage = message
        local formatedMessage = tostring(message)

        if debugs.printTimestamps then
            local time = GetFrameTimeMilliseconds()
            formatedMessage = string.format("%d --> %s", time, message)
        end
        WeavePulse.debug:Print(formatedMessage)
    end
end
