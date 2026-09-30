-- ESO Adventurer Suite
-- Native ESO Edit HUD integration (Update 51 / API 101051).
-- ESO owns HUD position editing; Suite modules continue to own presentation,
-- visibility, behavior, and their legacy saved-position compatibility keys.

ESOProgressionCoach = ESOProgressionCoach or {}
local EPC = ESOProgressionCoach

EPC.NativeHUDEditor = EPC.NativeHUDEditor or {}
local H = EPC.NativeHUDEditor

H.owner = "NativeHUDEditor"
H.registered = H.registered or setmetatable({}, { __mode = "k" })
H.elementDefs = H.elementDefs or setmetatable({}, { __mode = "k" })
H.callbacksInstalled = H.callbacksInstalled or false
H.editorHooksInstalled = H.editorHooksInstalled or false
H.previewActive = H.previewActive == true
H.previewStates = H.previewStates or setmetatable({}, { __mode = "k" })
H.pointerStates = H.pointerStates or setmetatable({}, { __mode = "k" })
H.modulePreviewStates = H.modulePreviewStates or {}
H.available = false

local function topLeft(control, leftKey, topKey, xAdjust, yAdjust)
    if not control or not EPC.saved then return end
    local left = tonumber(control.GetLeft and control:GetLeft())
    local top = tonumber(control.GetTop and control:GetTop())
    if left == nil or top == nil then return end
    EPC.saved[leftKey] = left + (tonumber(xAdjust) or 0)
    EPC.saved[topKey] = top + (tonumber(yAdjust) or 0)
    if EPC.CharacterProfile and type(EPC.CharacterProfile.CaptureKey) == "function" then
        pcall(EPC.CharacterProfile.CaptureKey, EPC.CharacterProfile, leftKey)
        pcall(EPC.CharacterProfile.CaptureKey, EPC.CharacterProfile, topKey)
    end
end

local function moduleControl(moduleName, field)
    return function()
        local module = EPC[moduleName]
        return module and module[field] or nil
    end
end

local function namedControl(name)
    return function()
        return rawget(_G, name)
    end
end

local function unitFrameControl(field, kind)
    return {
        name = "ESO Adventurer Suite - " .. kind,
        get = moduleControl("UnitFrames", field),
        save = function(control)
            if EPC.UnitFrames and EPC.UnitFrames.SaveWindowPosition then
                EPC.UnitFrames:SaveWindowPosition(control, string.lower(kind):gsub(" ", ""))
            end
        end,
    }
end

-- Keep this registry declarative. Position callbacks are compatibility bridges
-- only; ESO's HUD_MANAGER remains the authoritative edit surface.
H.definitions = {
    { name="ESO Adventurer Suite - Player Frame", get=moduleControl("UnitFrames","playerFrame"),
      save=function(c) topLeft(c,"playerFrameLeft","playerFrameTop") end },
    { name="ESO Adventurer Suite - Player Effects", get=moduleControl("UnitFrames","playerEffectsFrame"),
      save=function(c) topLeft(c,"playerEffectsLeft","playerEffectsTop") end },
    { name="ESO Adventurer Suite - Target Frame", get=moduleControl("UnitFrames","targetFrame"),
      save=function(c) topLeft(c,"targetFrameLeft","targetFrameTop") end },
    { name="ESO Adventurer Suite - Group Frame", get=moduleControl("UnitFrames","groupFrame"),
      save=function(c) topLeft(c,"groupFrameLeft","groupFrameTop") end },
    { name="ESO Adventurer Suite - Raid Frame", get=moduleControl("UnitFrames","raidFrame"),
      save=function(c) topLeft(c,"raidFrameLeft","raidFrameTop") end },
    { name="ESO Adventurer Suite - Combat Stats", get=moduleControl("UnitFrames","statsFrame"),
      save=function(c) topLeft(c,"statsFrameLeft","statsFrameTop") end },

    { name="ESO Adventurer Suite - Combat HUD", get=moduleControl("UI","combatHud"),
      save=function(c) topLeft(c,"combatHudLeft","combatHudTop") end },
    { name="ESO Adventurer Suite - Mini Map", get=moduleControl("MiniMap","frame"),
      save=function(c) topLeft(c,"miniMapLeft","miniMapTop") end },
    { name="ESO Adventurer Suite - Stable Timer", get=moduleControl("StableTimer","frame"),
      save=function(c) topLeft(c,"stableTimerLeft","stableTimerTop") end },
    { name="ESO Adventurer Suite - Clock", get=moduleControl("Clock","frame"),
      save=function(c) topLeft(c,"clockLeft","clockTop") end },
    { name="ESO Adventurer Suite - Active Quest", get=moduleControl("ActiveQuest","frame"),
      save=function(c) topLeft(c,"activeQuestLeft","activeQuestTop") end },
    { name="ESO Adventurer Suite - Golden Pursuits", get=moduleControl("GoldenPursuits","frame2505"),
      save=function(c) topLeft(c,"goldenPursuitsLeft","goldenPursuitsTop") end },
    { name="ESO Adventurer Suite - Alliance Rank", get=moduleControl("AllianceRank","frame"),
      save=function(c) topLeft(c,"allianceRankLeft","allianceRankTop") end },
    { name="ESO Adventurer Suite - Level / Champion", get=moduleControl("ChampionOverlay","frame"),
      save=function(c) topLeft(c,"championOverlayLeft","championOverlayTop") end },

    { name="ESO Adventurer Suite - Ability Bar", get=moduleControl("AbilityOverlays","singleBarGroup029734"),
      save=function(c)
          local A = EPC.AbilityOverlays
          local first = A and A.widgets and A.widgets[1]
          if not first or not A.GetPositionKeys then return end
          local leftKey, topKey = A:GetPositionKeys(first.epcSlot)
          topLeft(c, leftKey, topKey, 4, 4)
      end },
    { name="ESO Adventurer Suite - Dual Action Bar", get=moduleControl("DualActionBar","window"),
      save=function(c) topLeft(c,"dualActionBarLeft029189","dualActionBarTop029189") end },
    { name="ESO Adventurer Suite - Quickslot", get=moduleControl("QuickslotOverlay","frame"),
      save=function(c) topLeft(c,"quickslotOverlayLeft","quickslotOverlayTop") end },
    { name="ESO Adventurer Suite - Infinite Archive", get=moduleControl("InfiniteArchiveOverlay","previewFrame"),
      save=function(c) topLeft(c,"infiniteArchiveOverlayLeft","infiniteArchiveOverlayTop") end },

    { name="ESO Adventurer Suite - Repair / Recharge", get=moduleControl("RepairCostOverlay","frame"),
      save=function(c) topLeft(c,"repairCostLeft","repairCostTop") end },
    { name="ESO Adventurer Suite - Repair HUD", get=moduleControl("RepairCostOverlay","compactFrame"),
      save=function(c) topLeft(c,"repairCostCompactLeft","repairCostCompactTop") end },
    { name="ESO Adventurer Suite - FPS / Latency", get=moduleControl("PerformanceOverlay","frame"),
      save=function(c) topLeft(c,"performanceOverlayLeft","performanceOverlayTop") end },

    { name="ESO Adventurer Suite - Armor Reminder", get=moduleControl("EncounterReminders","repairFrame"),
      save=function(c)
          topLeft(c,"encounterRepairLeft","encounterRepairTop")
          if EPC.saved then EPC.saved.encounterRepairPreset = "CUSTOM" end
      end },
    { name="ESO Adventurer Suite - Potion Reminder", get=moduleControl("EncounterReminders","potionFrame"),
      save=function(c)
          topLeft(c,"encounterPotionLeft","encounterPotionTop")
          if EPC.saved then EPC.saved.encounterPotionPreset = "CUSTOM" end
      end },
    { name="ESO Adventurer Suite - Boss Mechanics", get=moduleControl("BossMechanicsAssistant","frame"),
      save=function(c) topLeft(c,"bossMechanicsLeft029198","bossMechanicsTop029198") end },
    { name="ESO Adventurer Suite - Challenge Difficulty", get=moduleControl("ChallengeDifficultyOverlay","frame"),
      save=function(c) topLeft(c,"overlandDifficultyOverlayLeft","overlandDifficultyOverlayTop") end },

    { name="ESO Adventurer Suite - Dungeon Queue",
      get=function()
          local D = EPC.DungeonFinder
          if D and not D.queueHud2768 and D.CreateQueueHud2768 then
              pcall(D.CreateQueueHud2768, D)
          end
          return D and D.queueHud2768 or nil
      end,
      save=function(c) topLeft(c,"dungeonQueueHudLeft","dungeonQueueHudTop") end },
    { name="ESO Adventurer Suite - Rotation Advisor", get=moduleControl("RotationAssistant","window"),
      save=function(c) topLeft(c,"rotationAssistantLeft","rotationAssistantTop") end },
    { name="ESO Adventurer Suite - Block Warning", get=moduleControl("RotationAssistant","blockWindow029161"),
      save=function(c) topLeft(c,"rotationBlockWarningLeft029161","rotationBlockWarningTop029161") end },
    { name="ESO Adventurer Suite - Weapon Swap Cue", get=moduleControl("RotationAssistant","swapCue029161"),
      save=function(c) topLeft(c,"rotationSwapCueLeft029196","rotationSwapCueTop029196") end },

    { name="ESO Adventurer Suite - Excavation Guide", get=moduleControl("AntiquityAssistant","guide"),
      save=function(c) topLeft(c,"antiquityGuideLeft","antiquityGuideTop") end },
    { name="ESO Adventurer Suite - Excavation Tile Picker", get=moduleControl("AntiquityAssistant","tilePicker"),
      save=function(c) topLeft(c,"antiquityTilePickerLeft","antiquityTilePickerTop") end },
    { name="ESO Adventurer Suite - Map Teleporter", get=moduleControl("Travel","mapTeleporter"),
      save=function(c) topLeft(c,"mapTeleporterLeft","mapTeleporterTop") end },
    { name="ESO Adventurer Suite - Alchemy Station Icon", get=moduleControl("AlchemyPotionMaker","button"),
      save=function(c) topLeft(c,"alchemyPotionMakerLeft","alchemyPotionMakerTop") end },

}

H.previewModuleNames = {
    "StableTimer", "Clock", "ActiveQuest", "GoldenPursuits",
    "AllianceRank", "ChampionOverlay", "AbilityOverlays", "DualActionBar",
    "QuickslotOverlay", "InfiniteArchiveOverlay", "RepairCostOverlay",
    "PerformanceOverlay", "BossMechanicsAssistant",
    "ChallengeDifficultyOverlay", "DungeonFinder", "RotationAssistant",
    "Travel", "AlchemyPotionMaker",
}

function H:BeginModulePreviews()
    self.modulePreviewStates = {}
    for _, name in ipairs(self.previewModuleNames) do
        local module = EPC[name]
        if module and type(module.SetLayoutMode) == "function" then
            self.modulePreviewStates[name] = { layoutMode = module.layoutMode == true }
            pcall(module.SetLayoutMode, module, true)
        end
    end

    local reminders = EPC.EncounterReminders
    if reminders and type(reminders.SetNativeEditHudPreview) == "function" then
        self.modulePreviewStates.EncounterReminders = { native = reminders.nativeEditHudPreview029780 == true }
        pcall(reminders.SetNativeEditHudPreview, reminders, true)
    end

    local antiquity = EPC.AntiquityAssistant
    if antiquity and type(antiquity.SetNativeEditHudPreview) == "function" then
        self.modulePreviewStates.AntiquityAssistant = { native = antiquity.nativeEditHudPreview029780 == true }
        pcall(antiquity.SetNativeEditHudPreview, antiquity, true)
    end

    local ui = EPC.UI
    if ui and type(ui.SetCombatHUDMoveMode) == "function" then
        self.modulePreviewStates.UI = { combatHudMoveMode = ui.combatHudMoveMode == true }
        pcall(ui.SetCombatHUDMoveMode, ui, true)
    end
end

function H:EndModulePreviews()
    for _, name in ipairs(self.previewModuleNames) do
        local module = EPC[name]
        local state = self.modulePreviewStates and self.modulePreviewStates[name]
        if module and type(module.SetLayoutMode) == "function" then
            pcall(module.SetLayoutMode, module, state and state.layoutMode == true or false)
        end
    end

    local reminders = EPC.EncounterReminders
    local reminderState = self.modulePreviewStates and self.modulePreviewStates.EncounterReminders
    if reminders and type(reminders.SetNativeEditHudPreview) == "function" then
        pcall(reminders.SetNativeEditHudPreview, reminders, reminderState and reminderState.native == true or false)
    end

    local antiquity = EPC.AntiquityAssistant
    local antiquityState = self.modulePreviewStates and self.modulePreviewStates.AntiquityAssistant
    if antiquity and type(antiquity.SetNativeEditHudPreview) == "function" then
        pcall(antiquity.SetNativeEditHudPreview, antiquity, antiquityState and antiquityState.native == true or false)
    end

    local ui = EPC.UI
    local uiState = self.modulePreviewStates and self.modulePreviewStates.UI
    if ui and type(ui.SetCombatHUDMoveMode) == "function" then
        pcall(ui.SetCombatHUDMoveMode, ui, uiState and uiState.combatHudMoveMode == true or false)
    end
    self.modulePreviewStates = {}
end

function H:IsAvailable()
    return type(HUD_MANAGER) == "table"
        and type(HUD_MANAGER.RegisterKeyboardElement) == "function"
        and type(SCENE_MANAGER) == "table"
        and type(SCENE_MANAGER.Show) == "function"
end

function H:IsESOPositionOwner(control)
    if not control or not self:IsAvailable() or type(HUD_MANAGER.GetKeyboardElementForControl) ~= "function" then return false end
    local ok, element = pcall(HUD_MANAGER.GetKeyboardElementForControl, HUD_MANAGER, control)
    return ok and element ~= nil and self.elementDefs[control] == nil
end

function H:IsControlEligible(control)
    if not control or control == GuiRoot then return false end
    if type(control.GetName) ~= "function"
        or type(control.GetAnchor) ~= "function"
        or type(control.GetDimensions) ~= "function" then
        return false
    end

    local okName, name = pcall(control.GetName, control)
    if not okName or type(name) ~= "string" or name == "" then return false end

    -- ZOS' HUD manager asserts exactly one primary anchor.
    local okPrimary, hasPrimary = pcall(control.GetAnchor, control, 0)
    if not okPrimary or hasPrimary ~= true then return false end

    local okSecondary, hasSecondary = pcall(control.GetAnchor, control, 1)
    if okSecondary and hasSecondary == true then return false end

    local okSize, width, height = pcall(control.GetDimensions, control)
    if not okSize or (tonumber(width) or 0) <= 0 or (tonumber(height) or 0) <= 0 then return false end

    return true
end

function H:IsPreviewActive()
    return self.previewActive == true
end

function H:IsSuiteElementData(elementData)
    if not elementData or type(elementData.GetControl) ~= "function" then return false end
    local ok, control = pcall(elementData.GetControl, elementData)
    return ok and control ~= nil and self.elementDefs[control] ~= nil
end

function H:SnapshotRegisteredControls()
    self.previewStates = setmetatable({}, { __mode = "k" })
    for control in pairs(self.registered) do
        if control then
            local state = {}
            if type(control.IsHidden) == "function" then
                local ok, value = pcall(control.IsHidden, control)
                if ok then state.hidden = value == true end
            end
            if type(control.IsMouseEnabled) == "function" then
                local ok, value = pcall(control.IsMouseEnabled, control)
                if ok then state.mouseEnabled = value == true end
            end
            self.previewStates[control] = state
        end
    end
end

local function walkControlTree(root, callback)
    if not root or type(callback) ~= "function" then return end
    callback(root)
    if type(root.GetNumChildren) ~= "function" or type(root.GetChild) ~= "function" then return end
    local okCount, count = pcall(root.GetNumChildren, root)
    count = okCount and tonumber(count) or 0
    for i = 1, count do
        local okChild, child = pcall(root.GetChild, root, i)
        if okChild and child then walkControlTree(child, callback) end
    end
end

function H:DisablePreviewPointerTree(control)
    walkControlTree(control, function(node)
        if self.pointerStates[node] == nil then
            local state = {}
            if type(node.IsMouseEnabled) == "function" then
                local ok, enabled = pcall(node.IsMouseEnabled, node)
                if ok then state.mouseEnabled = enabled == true end
            end
            self.pointerStates[node] = state
        end
        if type(node.SetMouseEnabled) == "function" then pcall(node.SetMouseEnabled, node, false) end
        if node == control and type(node.SetMovable) == "function" then pcall(node.SetMovable, node, false) end
    end)
end

function H:RestorePreviewPointerTree()
    for node, state in pairs(self.pointerStates or {}) do
        if node and state and state.mouseEnabled ~= nil and type(node.SetMouseEnabled) == "function" then
            pcall(node.SetMouseEnabled, node, state.mouseEnabled)
        end
    end
    self.pointerStates = setmetatable({}, { __mode = "k" })
end

function H:ExposeRegisteredControls()
    for control in pairs(self.registered) do
        if control then
            local state = self.previewStates[control]
            if not state then
                -- Controls created lazily after the snapshot are treated as
                -- preview-only unless they were already visible at creation.
                state = {}
                if type(control.IsHidden) == "function" then
                    local ok, value = pcall(control.IsHidden, control)
                    if ok then state.hidden = value == true end
                end
                if type(control.IsMouseEnabled) == "function" then
                    local ok, value = pcall(control.IsMouseEnabled, control)
                    if ok then state.mouseEnabled = value == true end
                end
                self.previewStates[control] = state
            end
            if type(control.SetHidden) == "function" then pcall(control.SetHidden, control, false) end
            -- ESO's editor owns pointer input. Disable mouse input on the entire
            -- Suite preview tree, including child drag shields/buttons, so the
            -- native editor hitbox always receives the drag.
            self:DisablePreviewPointerTree(control)
        end
    end
end

function H:BeginPreview()
    -- Capture the true gameplay state BEFORE the native editor exemption makes
    -- conditional/hidden overlays visible for positioning.
    self:SnapshotRegisteredControls()
    self.previewActive = true
    if EPC.HudVisibility and EPC.HudVisibility.Refresh then
        EPC.HudVisibility:Refresh("native-edit-hud-showing", true)
    end
    if EPC.RefreshGameplayOverlays then pcall(EPC.RefreshGameplayOverlays, EPC) end
    if EPC.UnitFrames and EPC.UnitFrames.SetNativeEditHudPreview then
        pcall(EPC.UnitFrames.SetNativeEditHudPreview, EPC.UnitFrames, true)
    end
    self:BeginModulePreviews()
    self:ExposeRegisteredControls()
    local nativeEditor = rawget(_G, "HUD_EDITOR_KEYBOARD")
    if nativeEditor and type(nativeEditor.RefreshAllElements) == "function" then
        pcall(nativeEditor.RefreshAllElements, nativeEditor)
    end

end

function H:EndPreview()
    -- Persist the final editor geometry before preview modules restore normal
    -- visibility/anchors. The active character profile is the authoritative
    -- Suite layout; ESO's HUD editor is only the editing surface.
    self:SyncAllToSuite()
    if EPC.CharacterProfile and type(EPC.CharacterProfile.Capture) == "function" then
        pcall(EPC.CharacterProfile.Capture, EPC.CharacterProfile, "native-edit-hud-exit")
    end
    self.previewActive = false
    if EPC.UnitFrames and EPC.UnitFrames.SetNativeEditHudPreview then
        pcall(EPC.UnitFrames.SetNativeEditHudPreview, EPC.UnitFrames, false)
    end
    self:EndModulePreviews()
    self:RestorePreviewPointerTree()
    for control, state in pairs(self.previewStates or {}) do
        if control and state then
            if type(control.SetMouseEnabled) == "function" and state.mouseEnabled ~= nil then
                pcall(control.SetMouseEnabled, control, state.mouseEnabled)
            end
            if type(control.SetHidden) == "function" and state.hidden ~= nil then
                pcall(control.SetHidden, control, state.hidden)
            end
        end
    end
    self.previewStates = setmetatable({}, { __mode = "k" })
    if EPC.HudVisibility and EPC.HudVisibility.Refresh then
        EPC.HudVisibility:Refresh("native-edit-hud-hidden", true)
    end
    if EPC.RefreshGameplayOverlays then pcall(EPC.RefreshGameplayOverlays, EPC) end

    local function refreshConditionalModules()
        local modules = {
            EPC.RotationAssistant,
            EPC.AntiquityAssistant,
            EPC.EncounterReminders,
            EPC.BossMechanicsAssistant,
            EPC.DungeonFinder,
            EPC.InfiniteArchiveOverlay,
            EPC.RepairCostOverlay,
            EPC.PerformanceOverlay,
            EPC.ChallengeDifficultyOverlay,
            EPC.AlchemyPotionMaker,
            EPC.Travel,
        }
        for _, module in ipairs(modules) do
            if module then
                if type(module.RefreshVisibility) == "function" then pcall(module.RefreshVisibility, module) end
                if type(module.Refresh) == "function" then pcall(module.Refresh, module) end
                if type(module.RefreshAll) == "function" then pcall(module.RefreshAll, module, true) end
            end
        end
    end
    refreshConditionalModules()

    if type(zo_callLater) == "function" then
        zo_callLater(function()
            if H and not H.previewActive then
                if EPC.HudVisibility and EPC.HudVisibility.Refresh then
                    EPC.HudVisibility:Refresh("native-edit-hud-hidden-settled", true)
                end
                if EPC.RefreshGameplayOverlays then pcall(EPC.RefreshGameplayOverlays, EPC) end
                refreshConditionalModules()
            end
        end, 100)
    end
end

function H:Close()
    self:SyncAllToSuite()
    if EPC.CharacterProfile and type(EPC.CharacterProfile.Capture) == "function" then
        pcall(EPC.CharacterProfile.Capture, EPC.CharacterProfile, "native-edit-hud-close")
    end
    local scene = rawget(_G, "HUD_EDITOR_SCENE_KEYBOARD")
    if scene and type(scene.IsShowing) == "function" then
        local ok, showing = pcall(scene.IsShowing, scene)
        if ok and showing ~= true then return true end
    end

    -- ESO's in-game scene manager owns UI-mode exit. This is the same native
    -- path used to return from UI mode to gameplay and release the cursor.
    if SCENE_MANAGER and type(SCENE_MANAGER.SetInUIMode) == "function" then
        local ok, changed = pcall(SCENE_MANAGER.SetInUIMode, SCENE_MANAGER, false, true)
        if ok and changed == true then return true end
    end

    -- Fallback directly to the gameplay HUD scene if UI mode was already
    -- considered false but the editor scene remained on top.
    if SCENE_MANAGER and type(SCENE_MANAGER.Show) == "function" then
        local ok = pcall(SCENE_MANAGER.Show, SCENE_MANAGER, "hud")
        if ok then return true end
    end

    if SCENE_MANAGER and type(SCENE_MANAGER.Hide) == "function" then
        return pcall(SCENE_MANAGER.Hide, SCENE_MANAGER, "hud_editor_keyboard", true)
    end
    return false
end

function H:InstallDirectExitControl()
    if self.directExitInstalled029780 then
        if self.exitControl029780 then self.exitControl029780:SetHidden(false) end
        return true
    end

    local editor = rawget(_G, "HUD_EDITOR_KEYBOARD")
    local root = editor and editor.control or nil
    if not root or not WINDOW_MANAGER then return false end

    self.directExitInstalled029780 = true

    -- Capture Escape / Alt on the actual native editor root, independent of
    -- keybind-strip/action-layer behavior.
    if type(root.SetKeyboardEnabled) == "function" then
        pcall(root.SetKeyboardEnabled, root, true)
    end
    if type(root.SetHandler) == "function" then
        root:SetHandler("OnKeyDown", function(_, key)
            if key == rawget(_G, "KEY_ESCAPE") or key == rawget(_G, "KEY_ALT") then
                H:Close()
            end
        end)
    end

    -- Guaranteed mouse fallback.
    local box = WINDOW_MANAGER:CreateControl("EAS_NativeHudEditorExit029780", root, CT_BACKDROP)
    box:SetDimensions(180, 38)
    box:SetAnchor(TOPRIGHT, root, TOPRIGHT, -36, 28)
    box:SetCenterColor(0.03, 0.03, 0.04, 0.94)
    box:SetEdgeColor(0.95, 0.72, 0.20, 0.95)
    box:SetMouseEnabled(true)
    if box.SetDrawTier and DT_HIGH then box:SetDrawTier(DT_HIGH) end
    if box.SetDrawLayer and DL_OVERLAY then box:SetDrawLayer(DL_OVERLAY) end
    if box.SetDrawLevel then box:SetDrawLevel(3000) end

    local label = WINDOW_MANAGER:CreateControl(nil, box, CT_LABEL)
    label:SetAnchorFill(box)
    label:SetFont("ZoFontGameBold")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetColor(1, 0.86, 0.42, 1)
    label:SetText("EXIT EDIT HUD")

    box:SetHandler("OnMouseUp", function(_, button, upInside)
        if button == MOUSE_BUTTON_INDEX_LEFT and upInside then
            H:Close()
        end
    end)

    self.exitControl029780 = box
    return true
end

function H:RemoveDirectExitControl()
    if self.exitControl029780 then self.exitControl029780:SetHidden(true) end
end

function H:InstallExitBindings()
    if self.exitBindingsInstalled029780 then return true end
    if type(KEYBIND_STRIP) ~= "table" or type(KEYBIND_STRIP.AddKeybindButtonGroup) ~= "function" then
        return false
    end

    self.exitKeybindGroup029780 = self.exitKeybindGroup029780 or {
        {
            name = (type(GetString) == "function" and rawget(_G, "SI_EXIT_BUTTON") and GetString(SI_EXIT_BUTTON)) or "Exit",
            keybind = "UI_SHORTCUT_EXIT",
            order = -10000,
            callback = function() H:Close() end,
        },
    }

    KEYBIND_STRIP:AddKeybindButtonGroup(self.exitKeybindGroup029780)
    self.exitBindingsInstalled029780 = true
    return true
end

function H:RemoveExitBindings()
    if not self.exitBindingsInstalled029780 then return end
    if type(KEYBIND_STRIP) == "table" and type(KEYBIND_STRIP.RemoveKeybindButtonGroup) == "function"
        and self.exitKeybindGroup029780 then
        pcall(KEYBIND_STRIP.RemoveKeybindButtonGroup, KEYBIND_STRIP, self.exitKeybindGroup029780)
    end
    self.exitBindingsInstalled029780 = false
end

function H:InstallEditorHooks()
    if self.editorHooksInstalled or not self:IsAvailable() then return false end
    local editor = rawget(_G, "HUD_EDITOR_KEYBOARD")
    local elementClass = rawget(_G, "ZO_HUDEditorElement_Keyboard")
    if type(editor) ~= "table" or type(editor.PopulateElementControls) ~= "function"
        or type(elementClass) ~= "table" then
        return false
    end

    self.editorHooksInstalled = true

    -- Suite-focused Edit HUD: do not delete or unregister ESO elements from
    -- HUD_MANAGER. Filter only the editor presentation so ESO's native HUD
    -- manager remains intact for the game itself.
    editor.easOriginalPopulate029780 = editor.easOriginalPopulate029780 or editor.PopulateElementControls
    editor.PopulateElementControls = function(selfEditor, dataToSelect)
        ZO_ClearNumericallyIndexedTable(selfEditor.elementControls)
        local iterator = IsInGamepadPreferredMode() and HUD_MANAGER.GamepadElementIterator or HUD_MANAGER.KeyboardElementIterator
        local objectToSelect = nil

        for _, elementData in iterator(HUD_MANAGER, { ZO_HUDManager_Element.IsValid }) do
            if H:IsSuiteElementData(elementData) then
                local element = selfEditor.customizableElementControlPool:AcquireObject()
                element.object:AssignElementData(elementData)
                table.insert(selfEditor.elementControls, element)
                if elementData == dataToSelect then objectToSelect = element.object end
            end
        end

        table.sort(selfEditor.elementControls, function(left, right)
            return left.object:GetElementData():GetDisplayName() < right.object:GetElementData():GetDisplayName()
        end)

        if objectToSelect then objectToSelect:Select() end
    end

    -- Reset All in the Suite-focused editor must never reset ESO's stock HUD.
    editor.easOriginalResetAll029780 = editor.easOriginalResetAll029780 or editor.ResetAllToDefault
    editor.ResetAllToDefault = function(selfEditor)
        for _, elementControl in ipairs(selfEditor.elementControls or {}) do
            local object = elementControl.object
            local data = object and object.GetElementData and object:GetElementData() or nil
            if H:IsSuiteElementData(data) and data.ResetToDefaultAnchor then
                data:ResetToDefaultAnchor()
            end
        end
        selfEditor:RefreshAllElements()
    end

    -- Keep the real Suite HUD item visually attached to ESO's selection box
    -- while dragging, instead of moving only the blue rectangle until mouse-up.
    if not H.suiteEditorVisualHookInstalled029780 and type(elementClass.RefreshColors) == "function" then
        H.suiteEditorVisualHookInstalled029780 = true
        local originalRefreshColors = elementClass.RefreshColors
        elementClass.RefreshColors = function(selfElement)
            local elementData = selfElement.GetElementData and selfElement:GetElementData() or nil
            if not H:IsSuiteElementData(elementData) then
                return originalRefreshColors(selfElement)
            end

            -- Suite entries never enter ESO's stock cyan/blue center-fill path.
            -- This avoids the one-frame flash that happened when ESO painted
            -- first and the Suite cleared it immediately afterward.
            local box = selfElement.control
            if box then
                if type(box.SetDrawLevel) == "function" then
                    pcall(box.SetDrawLevel, box, selfElement.selected and 2001 or 2000)
                end
                if type(box.SetCenterColor) == "function" then
                    pcall(box.SetCenterColor, box, 0, 0, 0, 0)
                end
                if type(box.SetEdgeColor) == "function" then
                    if selfElement.selected then
                        pcall(box.SetEdgeColor, box, 1.0, 0.78, 0.24, 0.92)
                    elseif selfElement.mouseOver then
                        pcall(box.SetEdgeColor, box, 0.45, 0.82, 1.0, 0.38)
                    else
                        pcall(box.SetEdgeColor, box, 0.30, 0.65, 0.82, 0.16)
                    end
                end
            end

            if selfElement.nameControl then
                if type(selfElement.nameControl.SetColor) == "function" then
                    if selfElement.selected then
                        pcall(selfElement.nameControl.SetColor, selfElement.nameControl, 1.0, 0.86, 0.40, 1.0)
                    else
                        pcall(selfElement.nameControl.SetColor, selfElement.nameControl, 0.75, 0.90, 1.0, 0.72)
                    end
                end
                if type(selfElement.nameControl.SetHidden) == "function" then
                    pcall(selfElement.nameControl.SetHidden, selfElement.nameControl, not selfElement.selected)
                end
            end
        end
    end

    if type(ZO_PostHookHandler) == "function" and not H.liveDragHookInstalled029780 then
        H.liveDragHookInstalled029780 = true
        local originalAssign = elementClass.AssignElementData
        elementClass.AssignElementData = function(selfElement, data)
            originalAssign(selfElement, data)
            local editorControl = selfElement.control
            if not editorControl or editorControl.easSuiteLiveDrag029780 then return end
            editorControl.easSuiteLiveDrag029780 = true
            ZO_PostHookHandler(editorControl, "OnRectChanged", function()
                local object = editorControl.object
                if not object or not object.dragging then return end
                local elementData = object.GetElementData and object:GetElementData() or nil
                if not H:IsSuiteElementData(elementData) then return end
                local point = object.primaryAnchorPoint
                if not point then return end
                local offsetX, offsetY = ZO_GetControlPointOffsetFromGuiRoot(editorControl, point)
                if type(elementData.ApplyOffset) == "function" then
                    pcall(elementData.ApplyOffset, elementData, offsetX, offsetY, false)
                end
            end)
        end
    end

    local scene = rawget(_G, "HUD_EDITOR_SCENE_KEYBOARD")
    if scene and type(scene.RegisterCallback) == "function" and not H.sceneHookInstalled029780 then
        H.sceneHookInstalled029780 = true
        scene:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_SHOWING then
                H:RefreshRegistrations()
                H:BeginPreview()
                H:InstallExitBindings()
                H:InstallDirectExitControl()
            elseif newState == SCENE_HIDING then
                H:RemoveExitBindings()
                H:RemoveDirectExitControl()
                H:EndPreview()
            elseif newState == SCENE_HIDDEN then
                H:RemoveExitBindings()
                H:RemoveDirectExitControl()
            end
        end)
    end

    return true
end

function H:InstallCallbacks()
    if self.callbacksInstalled or not self:IsAvailable() then return end
    self.callbacksInstalled = true

    HUD_MANAGER:RegisterCallback("OffsetsChanged", function(element)
        local control = element and element.GetControl and element:GetControl() or nil
        local def = control and H.elementDefs[control] or nil
        if def and type(def.save) == "function" then
            -- Each definition writes its Suite compatibility position keys.
            -- topLeft() mirrors those keys into the active character profile;
            -- the full profile snapshot is deferred until editor exit so drag
            -- events never deep-copy loadout/settings tables every frame.
            pcall(def.save, control)
        end
    end)

    HUD_MANAGER:RegisterCallback("PropagateSettings", function()
        -- ESO may reapply its account-wide HUD profile after a resolution or
        -- keyboard/gamepad preference change. Mirror the resulting positions
        -- back to legacy Suite keys so module refreshes never snap them back.
        if type(zo_callLater) == "function" then
            zo_callLater(function() H:SyncAllToSuite() end, 0)
        else
            H:SyncAllToSuite()
        end
    end)
end

function H:RegisterDefinition(def)
    if type(def) ~= "table" or type(def.get) ~= "function" then return false end
    local ok, control = pcall(def.get)
    if not ok or not self:IsControlEligible(control) then return false end
    if self.registered[control] then return true end

    -- The editor uses hudElementRef for the outline geometry. Suite controls
    -- are already self-contained HUD rectangles, so the control is its own ref.
    control.hudElementRef = control

    local config = {
        isValid = function() return true end,
    }

    local okRegister, element = pcall(HUD_MANAGER.RegisterKeyboardElement, HUD_MANAGER, control, def.name, config)
    if not okRegister or not element then return false end

    self.registered[control] = element
    self.elementDefs[control] = def

    -- Suite character profiles own persistent positions. Do not let ESO's
    -- account-wide HUD offsets overwrite the active character at login. Instead,
    -- seed the native HUD element from the control position already restored by
    -- the Suite, then save that anchor into ESO's HUD manager for this session.
    if HUD_MANAGER.savedVars and type(rawget(_G, "ZO_Anchor")) == "table"
        and type(ZO_Anchor.New) == "function" and type(control.GetAnchor) == "function" then
        local okAnchor, valid, point, relativeTo, relativePoint, offsetX, offsetY = pcall(control.GetAnchor, control, 0)
        if okAnchor and valid == true and point ~= nil then
            local anchor = ZO_Anchor:New(point, relativeTo, relativePoint, offsetX, offsetY)
            element.defaultAnchor = anchor
            element.currentAnchor = anchor
            if type(HUD_MANAGER.SaveAnchorOffsets) == "function" then
                pcall(HUD_MANAGER.SaveAnchorOffsets, HUD_MANAGER, element)
            end
        end
    end
    if type(def.save) == "function" then pcall(def.save, control) end
    return true
end

function H:RefreshRegistrations()
    if not self:IsAvailable() then
        self.available = false
        return 0
    end

    self.available = true
    self:InstallCallbacks()
    self:InstallEditorHooks()

    local count = 0
    for _, def in ipairs(self.definitions) do
        if self:RegisterDefinition(def) then count = count + 1 end
    end

    if type(HUD_MANAGER.RebuildAllElements) == "function" then
        pcall(HUD_MANAGER.RebuildAllElements, HUD_MANAGER)
    end
    return count
end

function H:SyncAllToSuite()
    for control, def in pairs(self.elementDefs) do
        if control and def and type(def.save) == "function" then
            pcall(def.save, control)
        end
    end
end

function H:AdoptCurrentSuitePositionsAsDefaults()
    if not self:IsAvailable() or type(rawget(_G, "ZO_Anchor")) ~= "table"
        or type(ZO_Anchor.New) ~= "function" then return false end

    for control, element in pairs(self.registered) do
        if control and element and self.elementDefs[control] and type(control.GetAnchor) == "function" then
            local ok, valid, point, relativeTo, relativePoint, offsetX, offsetY = pcall(control.GetAnchor, control, 0)
            if ok and valid == true and point ~= nil then
                local anchor = ZO_Anchor:New(point, relativeTo, relativePoint, offsetX, offsetY)
                element.defaultAnchor = anchor
                element.currentAnchor = anchor
                if type(HUD_MANAGER.SaveAnchorOffsets) == "function" then
                    pcall(HUD_MANAGER.SaveAnchorOffsets, HUD_MANAGER, element)
                end
            end
        end
    end
    if type(HUD_MANAGER.RebuildAllElements) == "function" then
        pcall(HUD_MANAGER.RebuildAllElements, HUD_MANAGER)
    end
    return true
end

function H:GetDiagnostics()
    local registered = 0
    for _ in pairs(self.registered) do registered = registered + 1 end

    local missing = {}
    for _, def in ipairs(self.definitions) do
        local ok, control = pcall(def.get)
        if not ok or not control or not self.registered[control] then
            missing[#missing + 1] = tostring(def.name or "Unknown")
        end
    end

    return {
        available = self:IsAvailable(),
        registered = registered,
        configured = #self.definitions,
        missing = missing,
        suiteOnlyEditor = self.editorHooksInstalled == true,
        livePreview = self.liveDragHookInstalled029780 == true,
        realControlPreview = self.suiteEditorVisualHookInstalled029780 == true,
        previewAdapters = #self.previewModuleNames + 1,
        pollingFreePreview = true,
        exitBinding = self.exitBindingsInstalled029780 == true or self.exitKeybindGroup029780 ~= nil,
        directExitControl = self.directExitInstalled029780 == true,
    }
end

function H:Open()
    if not self:IsAvailable() then return false end
    self:RefreshRegistrations()
    self:InstallEditorHooks()

    -- Use the same scene ZOS' Game Menu -> Edit HUD entry opens.
    local ok = pcall(SCENE_MANAGER.Show, SCENE_MANAGER, "hud_editor_keyboard")
    return ok
end

function H:ScheduleRegistrationPasses()
    if not self:IsAvailable() then return end
    local function refresh()
        if H then H:RefreshRegistrations() end
    end
    refresh()
    if type(zo_callLater) == "function" then
        zo_callLater(refresh, 250)
        zo_callLater(refresh, 1000)
        zo_callLater(refresh, 3000)
    end
end

-- Event-driven startup only; no polling loop is introduced.
if EPC.Runtime then
    if rawget(_G, "EVENT_ADD_ON_LOADED") then
        EPC.Runtime:RegisterEvent(H.owner, "AddonLoaded", EVENT_ADD_ON_LOADED, function(_, addonName)
            if addonName ~= EPC.name then return end
            EPC.Runtime:UnregisterEvent(H.owner, "AddonLoaded")
            H:ScheduleRegistrationPasses()
        end)
    end
    if rawget(_G, "EVENT_PLAYER_ACTIVATED") then
        EPC.Runtime:RegisterEvent(H.owner, "PlayerActivated", EVENT_PLAYER_ACTIVATED, function()
            H:RefreshRegistrations()
        end)
    end
    if rawget(_G, "EVENT_GAME_CAMERA_UI_MODE_CHANGED") then
        EPC.Runtime:RegisterEvent(H.owner, "GameCameraUIModeChanged", EVENT_GAME_CAMERA_UI_MODE_CHANGED, function()
            if not H.previewActive then return end
            if type(IsGameCameraUIModeActive) == "function" then
                local ok, active = pcall(IsGameCameraUIModeActive)
                if ok and active == false then
                    H:Close()
                end
            end
        end)
    end
end
