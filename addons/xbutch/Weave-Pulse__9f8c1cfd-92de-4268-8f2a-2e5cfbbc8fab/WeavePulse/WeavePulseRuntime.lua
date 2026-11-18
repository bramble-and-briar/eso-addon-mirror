-- Console lifecycle and fixes around the privately adapted upstream modules.
local W, U = WeavePulse, WeavePulse.Util
local T, ST, LA = U.Ability.Tracker, W.StackTracker, W.LATracker
local D = W.DEFAULT_SAVED_VARS
D.Progressbar.hide, D.Progressbar.showOOC, D.Progressbar.hideInPVP = false, false, false
D.Progressbar.noTickOnHeavy, D.Progressbar.showHeavyDetails = false, false
D.Progressbar.alwaysShowSpell, D.Progressbar.alwaysShowTimeRemaining = false, false
D.Progressbar.soundTickMidAbility, D.Progressbar.tickVolume = false, 15
for _, key in ipairs({ "trackRolldodge", "trackMounting", "showMountNick", "trackCollectibles", "trackItems", "trackSynergies", "trackBreakingFree" }) do
    D.Progressbar[key] = false
end
D.Resources.hideInPVP, D.Resources.reticleMagStam = false, false
D.StackTracker.onlyInCombat = false
D.LATracker.hideInPVP, D.LATracker.isUnlocked, D.LATracker.showLALogAfterFight = false, false, false
for index, skill in ipairs({ "BA", "Crux", "FI", "FS", "GF", "MW" }) do
    D.StackTracker[skill].xOffset = (GuiRoot:GetWidth() - 180) / 2
    D.StackTracker[skill].yOffset = GuiRoot:GetHeight() / 2 + 65 + (index - 1) * 42
end

function W:LoadPreferences()
    self.characterSV = ZO_SavedVars:NewCharacterIdSettings("WeavePulseSavedVars", 2, nil, self:Copy(D))
    self.accountSV = ZO_SavedVars:NewAccountWide("WeavePulseSavedVars", 2, nil, self:Copy(D))
    self.SV = self.characterSV.global and self.accountSV or self.characterSV
    self.SV.global = self.characterSV.global
end
function W:SwitchProfile(accountWide)
    self.characterSV.global = accountWide
    self.SV = accountWide and self.accountSV or self.characterSV
    self.SV.global = accountWide
    -- The generated stack option closures capture their profile. Rebuild only
    -- the data model here; native controls continue to be pooled by the list.
    self.Settings.panels, self.menu.panels = {}, nil
    self.Settings.modelReady = false
    self.Settings:EnsureModel()
    self:RebindStackPreferences()
    self:ApplyPreferences()
    if self.Settings.ui then self.Settings:ShowPanel("General") end
end
function W:ResetPreferences()
    local global = self.characterSV.global
    for key, value in pairs(D) do
        if key ~= "global" and key ~= "lastAddOnVersion" and key ~= "showBetaMessage" then self.SV[key] = self:Copy(value) end
    end
    self.SV.global = global
    self.Settings.panels, self.menu.panels = {}, nil
    self.Settings.modelReady = false
    self.Settings:EnsureModel()
    self:RebindStackPreferences()
    self:ApplyPreferences()
    if self.Settings.ui then self.Settings:ShowPanel("General") end
end

function W:SetForceDisplay(value)
    self.force = value == true
    self:RefreshResources()
    self:Wake()
end
function W:ToggleSounds(which)
    local sv = self.SV.Progressbar
    if which == "both" or which == "tick" then sv.soundTickEnabled = not sv.soundTickEnabled end
    if which == "both" or which == "tock" then sv.soundTockEnabled = not sv.soundTockEnabled end
    self.Progressbar.soundTickPlayed, self.Progressbar.soundTockPlayed = true, true
    self.Settings:Refresh()
end
function W:SetAllDebugFalse()
    for key, value in pairs(self.SV.debug) do if type(value) == "boolean" then self.SV.debug[key] = false end end
end
function W:AutomaticSVCleanup()
    local year, month, day = GetDateElementsFromTimestamp(GetTimeStamp())
    local last = self.SV.automaticSVCleanup.lastCleanup
    if not last or year > (last.year or 0) then
        self:CleanupSVEntries()
        self.SV.automaticSVCleanup.lastCleanup = { year = year, month = month, day = day }
    end
end
function W:CleanupSVEntries()
    -- Only retire explicitly obsolete aliases. Preserve preferences, selected
    -- abilities, announcement acknowledgement and unknown forward-version data.
    self.SV.Progressbar.hideProgressbar = nil
    self.SV.Resources.hideResourcesInPVP = nil
    for id in pairs(self.SV.Progressbar.abilityAdjusts) do
        if type(id) ~= "number" or id <= 0 then self.SV.Progressbar.abilityAdjusts[id] = nil end
    end
end

-- Replace LibSetDetection with a bounded, equipment-driven native query.
function W:UpdateCoralBahsei()
    local active = {}
    for _, slot in ipairs({ EQUIP_SLOT_HEAD, EQUIP_SLOT_CHEST, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_WAIST,
        EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET, EQUIP_SLOT_HAND, EQUIP_SLOT_NECK, EQUIP_SLOT_RING1,
        EQUIP_SLOT_RING2, EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND, EQUIP_SLOT_BACKUP_MAIN, EQUIP_SLOT_BACKUP_OFF }) do
        local link = GetItemLink(BAG_WORN, slot, LINK_STYLE_DEFAULT)
        if link and link ~= "" then
            local hasSet, _, _, equipped, _, setId = GetItemLinkSetInfo(link, true)
            if hasSet and equipped >= 5 then
                local base = GetItemSetUnperfectedSetId(setId)
                active[base and base > 0 and base or setId] = true
            end
        end
    end
    self.Resources.coralActive = active[647] == true
    self.Resources.bahseiActive = active[587] == true
    self.Resources.mkActive = active[147] == true
    if self.Progressbar.UI then self.Progressbar.UI.Anchors() end
end
function W:RegisterCoralBahsei()
    self.coralBahseiRegistered = true
    self:UpdateCoralBahsei()
end
function W:UnregisterCoralBahsei()
    self.coralBahseiRegistered = false
    self.Resources.coralActive, self.Resources.bahseiActive, self.Resources.mkActive = false, false, false
end

-- The reference inventory event scanned every backpack item on use. Keep a
-- small cache and update it per slot instead, then identify a consumed item.
function W:CacheItem(slot)
    local name = U.Text.CropZOSString(GetItemName(BAG_BACKPACK, slot), "item")
    self.backpack[slot] = { name = name, icon = GetItemInfo(BAG_BACKPACK, slot) }
end
function W:RegisterItemsTracker()
    if self.itemsTrackerRegistered then return end
    self.itemsTrackerRegistered = true
    self.backpack = self.backpack or {}
    local slot = 0
    self:StartUpdate("InventoryCache", 0, function()
        local finish = math.min(GetBagSize(BAG_BACKPACK) - 1, slot + 23)
        for index = slot, finish do self:CacheItem(index) end
        slot = finish + 1
        if slot >= GetBagSize(BAG_BACKPACK) then self:StopUpdate("InventoryCache") end
    end)
    EVENT_MANAGER:RegisterForEvent(self.name .. "InventoryItemUsed", EVENT_INVENTORY_ITEM_USED, function()
        self.lastItemUse = GetFrameTimeMilliseconds()
        self:Wake()
    end)
    EVENT_MANAGER:RegisterForEvent(self.name .. "InventoryItemInfo", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        function(_, bag, slotIndex, _, _, _, countChange)
            if bag ~= BAG_BACKPACK then return end
            local old = self.backpack[slotIndex]
            if countChange == -1 and old and self.lastItemUse and GetFrameTimeMilliseconds() - self.lastItemUse < 1000 then
                self.Progressbar.itemUsed = self:Copy(old)
                self.lastItemUse = nil
                self:Wake()
            end
            self:CacheItem(slotIndex)
        end)
    EVENT_MANAGER:AddFilterForEvent(self.name .. "InventoryItemInfo", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
end
function W:UnregisterItemsTracker()
    EVENT_MANAGER:UnregisterForEvent(self.name .. "InventoryItemUsed", EVENT_INVENTORY_ITEM_USED)
    EVENT_MANAGER:UnregisterForEvent(self.name .. "InventoryItemInfo", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    self.itemsTrackerRegistered = false
    self:StopUpdate("InventoryCache")
end
function W:UnregisterCollectiblesTracker()
    EVENT_MANAGER:UnregisterForEvent(self.name .. "CollectibleUsed", EVENT_COLLECTIBLE_UPDATED)
    self.collectiblesTrackerRegistered = false
end
function W:UnregisterCombatEvents()
    EVENT_MANAGER:UnregisterForEvent(self.name .. "CombatEvents", EVENT_COMBAT_EVENT)
    self.combatEventsRegistered = false
end
function W:UnregisterSynergyChanged()
    EVENT_MANAGER:UnregisterForEvent(self.name .. "SynergyChanged", EVENT_SYNERGY_ABILITY_CHANGED)
    self.synergyChangedRegistered = false
end
function W:SyncActionEvents()
    local sv = self.SV.Progressbar
    local active = not sv.hide and not (self.inPVPZone and sv.hideInPVP)
    local collectibles = active and sv.trackGCD and (sv.trackCollectibles or sv.trackMounting)
    if collectibles and not self.collectiblesTrackerRegistered then self:RegisterCollectiblesTracker()
    elseif not collectibles and self.collectiblesTrackerRegistered then self:UnregisterCollectiblesTracker() end
    if active and sv.trackGCD and sv.trackItems then self:RegisterItemsTracker()
    elseif self.itemsTrackerRegistered then self:UnregisterItemsTracker() end
    if active and sv.trackGCD then
        if not self.combatEventsRegistered then self:RegisterCombatEvents() end
        if not self.synergyChangedRegistered then self:RegisterSynergyChanged(); self.synergyChangedRegistered = true end
    else
        if self.combatEventsRegistered then self:UnregisterCombatEvents() end
        if self.synergyChangedRegistered then self:UnregisterSynergyChanged() end
    end
end
function W:RegisterCM() self.cmRegistered = true; self:SyncActionEvents(); self:Wake() end
function W:UnregisterCM()
    self.cmRegistered = false
    self:StopUpdate("Combat")
    self:SyncActionEvents()
end
function W:CMPVPSwitch()
    self.cmRegistered = not self.SV.Progressbar.hide and not (self.inPVPZone and self.SV.Progressbar.hideInPVP)
    self:SyncActionEvents()
    if not self.cmRegistered then self:HideBar(true); self:HideLabels(true) end
    self:Wake()
end
function W:RegisterResourceTracker() self.rtRegistered = true; self:RefreshResources() end
function W:UnregisterResourceTracker() self.rtRegistered = false; self:StopUpdate("Resources") end

local upstreamUsed = W.HandleAbilityUsed
function W:HandleAbilityUsed(event)
    upstreamUsed(self, event)
    self:Wake()
end
function W:IsHUDVisible()
    return not self.suspended and (SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui"))
end
function W:Wake()
    if self.suspended then return end
    self:StartUpdate("Combat", 1000 / 60, function() self:PumpCombat() end)
end
function W:PumpCombat()
    T:Update()
    local _, remaining = T:GCDCheck()
    if self.currentEvent and self.currentEvent.ending <= GetFrameTimeMilliseconds() and remaining <= 0 then
        T:CancelCurrentEvent("Finished")
    end
    if self.cmRegistered and (self.inCombat or self.SV.Progressbar.showOOC or self.Progressbar.showSample) then self:Update() end
    local pendingSound = not self.Progressbar.soundTockPlayed and
        GetFrameTimeMilliseconds() <= (self.abilityFinished or 0) + math.max(0, self.SV.Progressbar.soundTockOffset) + 60
    if not T.queuedEvent and not T.currentEvent and not self.currentEvent and remaining <= 0 and not pendingSound and not self.Progressbar.showSample then
        self:StopUpdate("Combat")
    end
end
-- Existing callbacks keep the upstream ordering; only this private tracker is wrapped.
for _, key in ipairs({ "HandleSlotUsed", "HandleCooldownsUpdated", "HandleOutgoingCombatEvent", "HandleIncomingCombatEvent", "HandleBarSwap", "HandleWeaponLockChange" }) do
    local method = T[key]
    T[key] = function(self, ...)
        method(self, ...)
        W:Wake()
    end
end
local upstreamStart = T.Start
function T:Start()
    upstreamStart(self)
    EVENT_MANAGER:UnregisterForUpdate(self.name .. "Update")
end
function T:HandleBarSwap(_, changed)
    if not changed then return end
    local event = self.currentEvent or W.currentEvent
    if event and (event.ability.delay > 1000 or event.ability.heavy) then self:CancelCurrentEvent("Barswap") end
    self:CancelEvent("Barswap")
    W:Wake()
end

function W:RefreshResources()
    if not self.Progressbar.UI then return end
    local sv = self.SV.Resources
    if self.suspended or (self.inPVPZone and sv.hideInPVP) then
        for _, key in ipairs({ "ultLabel", "stamLabel", "magLabel", "hpLabel", "executeLabel" }) do self.Resources[key]:SetHidden(true) end
        self:StopUpdate("Resources")
        return
    end
    self:UpdateLabels()
    local hp, _, maxHp = GetUnitPower("reticleover", POWERTYPE_HEALTH)
    local stamina, _, maxStamina = GetUnitPower("player", POWERTYPE_STAMINA)
    local magicka, _, maxMagicka = GetUnitPower("player", POWERTYPE_MAGICKA)
    local stamThreshold = math.max(sv.highlightStam and sv.stamHighlightThreshold or 0,
        sv.coralBahsei and (self.Resources.coralActive or self.Resources.mkActive) and 50 or 0)
    local magThreshold = math.max(sv.highlightMag and sv.magHighlightThreshold or 0,
        sv.coralBahsei and self.Resources.bahseiActive and 50 or 0)
    local animated = self.Resources.showSample or (self:IsHUDVisible() and (self.inCombat or self.force or sv.showResources
        or U.Targeting.isUnitValidCombatTarget("reticleover", sv.showResourcesForGuard)) and
        ((sv.showHealth and maxHp > 0 and hp > 0 and hp * 100 / maxHp < sv.hpHighlightThreshold)
        or (not self.Resources.stamLabel:IsHidden() and stamina * 100 / math.max(1, maxStamina) < stamThreshold)
        or (not self.Resources.magLabel:IsHidden() and magicka * 100 / math.max(1, maxMagicka) < magThreshold)))
    if animated then self:StartUpdate("Resources", 100, function() self:RefreshResources() end)
    else self:StopUpdate("Resources") end
end
function W:ResourcesPVPSwitch() self.rtRegistered = true; self:RefreshResources() end

-- Correct zero-time reset behavior and count every detected player LA once.
LA.count, LA.lastAttack, LA.interval = 0, nil, 0
function LA:HandleLightAttacks(time)
    if W.SV.LATracker.hideInPVP and W.inPVPZone then return end
    if not W.inCombat then return end
    self.combatStart = self.combatStart or time
    self.count = self.count + 1
    self.interval = self.lastAttack and time - self.lastAttack or 0
    self.lastAttack = time
    self:DisplayText()
end
function LA:DisplayText()
    if not self.label then return end
    local sv = W.SV.LATracker
    local visible = sv.choice ~= "Nothing" and not (sv.hideInPVP and W.inPVPZone)
        and (self.combatStart ~= nil or sv.isUnlocked or sv.timeTilHiding == 0
        or (self.lastSummary and GetFrameTimeMilliseconds() < self.lastSummary + sv.timeTilHiding * 1000))
    self.label:SetHidden(not visible)
    if not visible then return end
    local elapsed = self.combatStart and (GetGameTimeMilliseconds() - self.combatStart) / 1000 or self.summaryDuration or 0
    local count = self.combatStart and self.count or self.summaryCount or 0
    if sv.choice == "Time between light attacks" then self.label:SetText(tostring(self.interval) .. " ms")
    else self.label:SetText(string.format("%.2f la/s", elapsed > 0 and count / elapsed or 0)) end
end
function LA:StartLATracker()
    self.combatStart, self.count, self.lastAttack, self.interval = GetGameTimeMilliseconds(), 0, nil, 0
    W:StopUpdate("LAHide")
    self:DisplayText()
end
function LA:ResetLATracker()
    if not self.combatStart then return end
    self.summaryDuration = math.max(0, (GetGameTimeMilliseconds() - self.combatStart) / 1000)
    self.summaryCount, self.lastSummary = self.count, GetFrameTimeMilliseconds()
    if W.SV.LATracker.showLALogAfterFight then
        W:Print(string.format("Combat: %.1f s; %d light attacks; %.2f la/s.", self.summaryDuration,
            self.count, self.summaryDuration > 0 and self.count / self.summaryDuration or 0))
    end
    self.combatStart = nil
    self:DisplayText()
    local delay = W.SV.LATracker.timeTilHiding
    if delay > 0 then
        W:StartUpdate("LAHide", delay * 1000, function() W:StopUpdate("LAHide"); self:DisplayText() end)
    end
end

local upstreamStackChange = ST.ChangeStackCount
function ST:ChangeStackCount(skill, count)
    count = math.max(0, math.min(self.SKILL_ATTRIBUTES[skill].iMax * (self.SKILL_ATTRIBUTES[skill].multiplier or 1), count))
    upstreamStackChange(self, skill, count)
    if W.suspended or (W.SV.StackTracker.onlyInCombat and not W.inCombat and not W.SV.StackTracker.isUnlocked) then
        if self.UI[skill] then self.UI[skill].Hide(true) end
    end
end
local upstreamRegister = ST.Register
function ST:Register(skill)
    if not self:TrackerIsActive(skill) or W.suspended or (W.inPVPZone and W.SV.StackTracker[skill].hideInPVP) then return end
    local registered = self:CheckIfRegistered(skill)
    upstreamRegister(self, skill)
    if registered then return end
    -- Restore already-running durations when enabling a tracker or loading UI.
    for index = 1, GetNumBuffs("player") do
        local _, beginTime, endTime, _, count, _, _, _, _, _, id = GetUnitBuffInfo("player", index)
        if self.trackedIds[id] == skill then
            self:HandleEffectChanged(nil, EFFECT_RESULT_UPDATED, nil, nil, "player", beginTime, endTime,
                count, nil, nil, nil, nil, nil, nil, nil, id)
            break
        end
    end
end
function ST:AbilityUpdater()
    self:IsTrackingAvailable(); self:MorphCheck()
    W:BuildListOfCurrentlyEquippedAbilities()
    for skill in pairs(self.SKILL_ATTRIBUTES) do self:PVPSwitch(skill) end
end
function ST:HandleEffectChanged(_, changeType, _, _, _, beginTime, endTime, count, _, _, _, _, _, _, _, id)
    local skill = self.trackedIds[id]
    if not skill then return end
    if skill == "FI" then count = 1 elseif skill == "FS" and count == 3 then count = 0 end
    if changeType == EFFECT_RESULT_FADED then count = 0 end
    self.timers = self.timers or {}
    if count > 0 and endTime > beginTime then
        self.timers[skill] = { duration = endTime - beginTime, endTime = endTime }
    else self.timers[skill] = nil end
    self:ChangeStackCount(skill, count)
    self:UpdateTimers()
end
function ST:UpdateTimers()
    local active, time = false, GetGameTimeSeconds()
    for skill, trackerUI in pairs(self.UI) do
        local ui, sv = trackerUI.indicator, W.SV.StackTracker[skill]
        if ui.timer then
            local entry = self.timers and self.timers[skill]
            local left = entry and entry.endTime - time or 0
            local enabled = not W.suspended and self:CheckIfRegistered(skill) and sv.tracked
                and not (W.inPVPZone and sv.hideInPVP)
                and not (W.SV.StackTracker.onlyInCombat and not W.inCombat and not W.SV.StackTracker.isUnlocked)
            local visible = enabled and (W:IsHUDVisible() or (W.Settings.ui and W.Settings.ui.active and W.SV.StackTracker.isUnlocked))
            local running = enabled and entry and left > 0 and (self.stacks[skill] or 0) > 0
            local sample = W.SV.StackTracker.isUnlocked and visible and not running
            local text = sample and "2.5" or (left >= 10 and tostring(zo_round(left)) or string.format("%.1f", math.max(0, left)))
            ui.timer:SetHidden(not ((running or sample) and visible and sv.showTimer))
            ui.timer:SetText(text)
            local barVisible = (running or sample) and visible and sv.showTimerBar
            ui.timerBar:SetHidden(not barVisible); ui.timerBarBackdrop:SetHidden(not barVisible)
            ui.timerBarGloss:SetHidden(not barVisible); ui.timerBarTimer:SetHidden(not (barVisible and not sv.showTimer))
            ui.timerBarTimer:SetText(text)
            if barVisible then ui.timerBar:SetValue(sample and .5 or left / entry.duration) end
            if running then
                local reminder = not sv.remindersOnlyInCombat or W.inCombat
                local expiring = reminder and left <= sv.expirationTimer
                local multiplier = sv.animateTimer and expiring and (2 + math.sin(left * 3 * math.pi) / 2) or 1
                ui.timer:SetFont(U.Text.getFontString("$(BOLD_FONT)", math.floor(sv.indicatorSize * multiplier), "outline"))
                if expiring and sv.soundReminder and not entry.soundPlayed then
                    entry.soundPlayed = true
                    W:PlayCue(sv.expirationSound, sv.reminderVolume)
                end
                active = active or (visible and (sv.showTimer or sv.showTimerBar)) or sv.soundReminder
            elseif entry and left <= 0 then self.timers[skill] = nil end
        end
    end
    if active then self:RegisterTimerUpdater() else self:UnregisterTimerUpdater() end
end
function ST:Unregister(skill)
    EVENT_MANAGER:UnregisterForEvent(self.name .. skill .. "Stacks", EVENT_EFFECT_CHANGED)
    for id, tracked in pairs(self.trackedIds) do if tracked == skill then self.trackedIds[id] = nil end end
    self.stacks[skill] = nil
    if self.timers then self.timers[skill] = nil end
    if self.UI[skill] then
        self.UI[skill].Hide(true)
        self.UI[skill].FadeScenes("NoUI")
        self.UI[skill].FadeScenes("NoSample")
        self.UI[skill].stacksWindow:SetHidden(true)
        for _, indicator in ipairs(self.UI[skill].indicator) do indicator.StopAnimation(); indicator.SetAnimationHidden(true) end
    end
    if not self.timers or not next(self.timers) then self:UnregisterTimerUpdater() end
end
function ST:RegisterTimerUpdater()
    if W.suspended then return end
    self.timerUpdaterRegistered = true
    W:StartUpdate("StackTimers", 50, function() self:UpdateTimers() end)
end
function ST:UnregisterTimerUpdater()
    self.timerUpdaterRegistered = false
    W:StopUpdate("StackTimers")
end
function ST:PVPSwitch(skill)
    if self:TrackerIsActive(skill) and not (W.inPVPZone and W.SV.StackTracker[skill].hideInPVP) then
        self:Register(skill)
        local hidden = W.suspended or (W.SV.StackTracker.onlyInCombat and not W.inCombat and not W.SV.StackTracker.isUnlocked)
        self:HideTracker(skill, hidden)
    else self:Unregister(skill) end
end
function W:RebindStackPreferences()
    -- Private HUD proxies read the current profile without mutating old profiles.
    for skill, ui in pairs(ST.UI) do ui.Position("UI") end
end

function W:ApplyPreferences()
    if not self.Progressbar.UI then return end
    local ui, sv = self.Progressbar.UI, self.SV
    ui.Position(self.Progressbar.showSample and "Sample" or "UI")
    ui.ResourcesPosition(self.Resources.showSample and "Sample" or "UI")
    ui.Size(); ui.Anchors(); ui.Fonts(); ui.LabelColors(); ui.BarColors()
    self.Resources.executeFrame:ClearAnchors()
    self.Resources.executeFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.Resources.executeX, sv.Resources.executeY)
    self.Resources.executeFrame:SetDimensions(sv.Resources.executeWidth, sv.Resources.executeHeight)
    self.Resources.executeLabel:SetColor(unpack(sv.Resources.executeColor))
    self.Resources.executeLabel:SetFont(U.Text.getFontString("$(" .. sv.Progressbar.labelFont .. ")", sv.Resources.executeHeight, sv.Progressbar.fontStyle))
    if sv.Resources.coralBahsei then self:RegisterCoralBahsei() else self:UnregisterCoralBahsei() end
    ST:AbilityUpdater()
    for skill, trackerUI in pairs(ST.UI) do
        trackerUI.Position("UI")
        trackerUI.indicator.ApplySize(sv.StackTracker[skill].indicatorSize)
        self.StackTracker:PVPSwitch(skill)
    end
    LA.frame:ClearAnchors()
    LA.frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.LATracker.xOffset, sv.LATracker.yOffset)
    LA.frame:SetDimensions(sv.LATracker.width, sv.LATracker.height)
    LA.label:SetFont(U.Text.getFontString("$(" .. sv.Progressbar.labelFont .. ")", sv.LATracker.height, sv.Progressbar.fontStyle))
    LA:DisplayText()
    self:CalculateExecuteThreshold()
    self:CMPVPSwitch()
    self:RefreshResources()
    self:Wake()
end

function W:ClearPreviews()
    self:StopUpdate("AbilitySearch")
    self.Progressbar.showSample, self.Resources.showSample = false, false
    self.Progressbar.UI.FadeScenes("NoSample")
    for _, ui in pairs(ST.UI) do ui.FadeScenes("NoSample") end
    self:ApplyPreferences()
end

function W:FindAbilityAdjust(input)
    self:StopUpdate("AbilitySearch")
    input = tostring(input or ""):match("^%s*(.-)%s*$")
    if input == "" or input == "Add ability adjust" then return end
    local function found(id)
        self.menu.curSkillId, self.menu.curSkillName = id, U.Text.CropZOSString(GetAbilityName(id), "ability")
        self.SV.Progressbar.abilityAdjusts[id] = self.SV.Progressbar.abilityAdjusts[id] or 0
        self:UpdateAdjustChoices()
        self:StopUpdate("AbilitySearch")
        self.Settings:Refresh()
    end
    local numeric = tonumber(input)
    if numeric and numeric > 0 and numeric == math.floor(numeric) and numeric <= 300000 then
        if GetAbilityName(numeric) ~= "" then found(numeric) end
        return
    end
    if U.Ability.nameCache[input] then found(U.Ability.nameCache[input].id); return end
    local index = 1
    self:StartUpdate("AbilitySearch", 0, function()
        local start = GetGameTimeMilliseconds()
        for _ = 1, 64 do
            if index > 300000 then self:StopUpdate("AbilitySearch"); self:Print("No matching ability found."); return end
            if U.Text.CropZOSString(GetAbilityName(index), "ability") == input then found(index); return end
            index = index + 1
            if GetGameTimeMilliseconds() - start >= .5 or not self:HasBudget() then break end
        end
    end)
end

local function Event(key, event, callback, filter, value)
    EVENT_MANAGER:RegisterForEvent(W.name .. key, event, callback)
    if filter then EVENT_MANAGER:AddFilterForEvent(W.name .. key, event, filter, value) end
end
function W:RegisterMetadata()
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function()
        self:RefreshResources()
        ST:UpdateTimers()
        if self:IsHUDVisible() then self:Wake() end
    end)
    Event("Activated", EVENT_PLAYER_ACTIVATED, function()
        self.suspended = false
        self.Settings:RegisterMenu()
        self.inPVPZone = self:IsInPvPZone()
        ST:AbilityUpdater()
        self:ApplyPreferences()
        self.Announcements:Init()
    end)
    Event("Deactivated", EVENT_PLAYER_DEACTIVATED, function()
        self.suspended = true
        T:CancelEvent("Player deactivated"); T:CancelCurrentEvent("Player deactivated")
        for key in pairs(self:Copy(self.jobs)) do self:StopUpdate(key) end
    end)
    Event("CombatState", EVENT_PLAYER_COMBAT_STATE, function(_, combat)
        self.inCombat = combat == true
        LA:ManageLATracker(combat)
        for skill in pairs(ST.SKILL_ATTRIBUTES) do ST:PVPSwitch(skill) end
        self:RefreshResources(); self:Wake()
    end)
    Event("Resources", EVENT_POWER_UPDATE, function() self:RefreshResources() end, REGISTER_FILTER_UNIT_TAG, "player")
    Event("TargetHealth", EVENT_POWER_UPDATE, function() self:RefreshResources() end, REGISTER_FILTER_UNIT_TAG, "reticleover")
    Event("Reticle", EVENT_RETICLE_TARGET_CHANGED, function() self:RefreshResources() end)
    Event("Skills", EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, function() ST:AbilityUpdater(); self:RefreshResources() end)
    Event("Respec", EVENT_SKILL_RESPEC_RESULT, function() ST:AbilityUpdater() end)
    Event("Armory", EVENT_ARMORY_BUILD_RESTORE_RESPONSE, function() zo_callLater(function() ST:AbilityUpdater() end, 10) end)
    Event("Equipment", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function()
        if self.SV.Resources.coralBahsei then self:UpdateCoralBahsei(); self:RefreshResources() end
    end, REGISTER_FILTER_BAG_ID, BAG_WORN)
    Event("EquipmentHotbar", EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, function()
        if self.SV.Resources.coralBahsei then self:UpdateCoralBahsei() end
        ST:AbilityUpdater(); self:RefreshResources()
    end)
end

function W:CustomizeSettings()
    local function visit(rows, callback)
        for _, row in ipairs(rows) do callback(row); if row.controls then visit(row.controls, callback) end end
    end
    visit(self.menu.options.General, function(row)
        if row.name == "Account Wide" then row.setFunc = function(value) self:SwitchProfile(value) end end
    end)
    visit(self.menu.options.Progressbar, function(row)
        if row.name == "Modify skill adjust (in ms)" or row.name == "Remove skill adjust" then
            row.disabled = function() return not self.menu.curSkillId or self.menu.curSkillId <= 0 end
        end
    end)
    local function slider(rows, key, label, minimum, maximum, setter)
        rows[#rows + 1] = { type = "slider", name = label, min = minimum, max = maximum, step = 1, decimals = 0,
            getFunc = function() return setter and setter() or 0 end,
            setFunc = function(value) key(value) end }
    end
    -- Every mouse-based placement action also has real controller sliders.
    local layouts = { { "Resources", self.SV.Resources, "Resource placement", 50, 600 },
        { "LATracker", self.SV.LATracker, "Light attack tracker placement", 50, 600 } }
    for _, layout in ipairs(layouts) do
        local section, data, title, low, high = unpack(layout)
        local rows = {}
        for _, dimension in ipairs({ { "xOffset", "X position", 0, GuiRoot:GetWidth() },
            { "yOffset", "Y position", 0, GuiRoot:GetHeight() }, { "width", "Width", low, high }, { "height", "Height", 10, 100 } }) do
            local key = dimension[1]
            slider(rows, function(value) data[key] = value end, dimension[2], dimension[3], dimension[4], function() return data[key] end)
        end
        table.insert(self.menu.options[section], 1, { type = "submenu", name = title, controls = rows })
    end
    local execute = {}
    for _, dimension in ipairs({ { "executeX", "X position", 0, GuiRoot:GetWidth() },
        { "executeY", "Y position", 0, GuiRoot:GetHeight() }, { "executeHeight", "Text size", 10, 100 } }) do
        local key = dimension[1]
        slider(execute, function(value) self.SV.Resources[key] = value end, dimension[2], dimension[3], dimension[4], function() return self.SV.Resources[key] end)
    end
    self.menu.options.Resources[#self.menu.options.Resources + 1] = { type = "submenu", name = "Execute reminder placement", controls = execute }
    for skill, definition in pairs(self.menu.CONTROLS.stackTracker) do
        visit(self.menu.options.StackTracker, function(row)
            if row.name == "|t20:20:" .. definition.icon .. "|t " .. definition.subName then
                local code = skill
                visit(row.controls, function(option)
                    if option.name == "Stack indicator size" or option.name == "Animation cue to fire stacks" then
                        local disabled = option.disabled
                        option.disabled = function() return not ST.UI[code] or (type(disabled) == "function" and disabled()) end
                    end
                end)
                for _, dimension in ipairs({ { "xOffset", "X position", GuiRoot:GetWidth() }, { "yOffset", "Y position", GuiRoot:GetHeight() } }) do
                    local key, code = dimension[1], skill
                    slider(row.controls, function(value) self.SV.StackTracker[code][key] = value end,
                        dimension[2], 0, dimension[3], function() return self.SV.StackTracker[code][key] end)
                end
            end
        end)
    end
    table.insert(self.menu.options.General, 1, { type = "description", name = "About WeavePulse",
        text = "Independent, unofficial Xbox adaptation inspired by CombatMetronome by Darianopolis and barny. Not an official port. Reports: DM @xbutch on Discord or ESO Xbox." })
    self.menu.options.General[#self.menu.options.General + 1] = { type = "checkbox", name = "Force resource display",
        tooltip = "Keep resources visible and show the target's absolute health. Also available as a held keybind.",
        getFunc = function() return self.force == true end, setFunc = function(value) self:SetForceDisplay(value) end }
    self.menu.options.General[#self.menu.options.General + 1] = { type = "button", name = "Toggle metronome sound cues", func = function() self:ToggleSounds("both") end }
end

function W:Init()
    if self.initialized then return end
    self.initialized = true
    self:LoadPreferences()
    self.inCombat, self.inPVPZone = IsUnitInCombat("player"), self:IsInPvPZone()
    self.gcd, self.gcdEvent = 1000, { finished = 0 }
    self.lastAbilityFinished, self.abilityFinished = 0, 0
    self.currentlyEquippedAbilities = {}
    self.menu.icons = { progressbar = {} }
    self.LSD = true -- Native equipment detection is always available.
    local mount = GetActiveCollectibleByType(COLLECTIBLE_CATEGORY_TYPE_MOUNT, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
    self.Progressbar = { activeMount = { action = "", name = U.Text.CropZOSString(GetCollectibleNickname(mount), "collectible"), icon = GetCollectibleIcon(mount) },
        synergy = {}, soundTickPlayed = true, soundTockPlayed = true }
    ST.availableSkills, ST.AVAILABLE_TRACKING_IDS, ST.slottedSkills = {}, {}, {}
    ST.trackedIds, ST.stacks, ST.UI = {}, {}, {}
    ST:IsTrackingAvailable(); ST:MorphCheck()
    self.Settings:Initialize()
    self.Progressbar.UI = self:BuildUI()
    LA:BuildUI()
    self:BuildListOfCurrentlyEquippedAbilities()
    T.WeavePulse = self
    T:Start()
    self:RegisterMetadata()
    self:ApplyPreferences()
    if self.SV.automaticSVCleanup.enabled then self:AutomaticSVCleanup() end
    self.Announcements:Init()
end
EVENT_MANAGER:RegisterForEvent(W.name .. "Loaded", EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= W.name then return end
    EVENT_MANAGER:UnregisterForEvent(W.name .. "Loaded", EVENT_ADD_ON_LOADED)
    W:Init()
end)
