-- ESO Adventurer Suite
-- Copyright (c) 2026 HoZayyBadazz. All Rights Reserved.
-- Proprietary source. Unauthorized redistribution, republication, rebranding,
-- or public distribution of modified/derivative versions is prohibited.
-- Private personal-use modifications are permitted. See LICENSE.txt.

local EPC = ESOProgressionCoach
EPC.Settings = EPC.Settings or {}
local S = EPC.Settings
S.organizationVersion029786 = 4
S.searchVersion029787 = 1

-- Architecture hardening: Settings.lua is the only owner of LibAddonMenu
-- registration. Feature modules contribute controls through this registry
-- instead of wrapping S:Initialize or monkey-patching RegisterOptionControls.
S.optionExtensions = S.optionExtensions or {}

function S:RegisterOptionsExtension(name, callback, priority)
    if type(callback) ~= "function" then return false end
    name = tostring(name or "")
    if name == "" then return false end
    self.optionExtensions[name] = {
        callback = callback,
        priority = tonumber(priority) or 100,
    }
    return true
end

function S:ApplyOptionsExtensions(options)
    if type(options) ~= "table" then return end
    local ordered = {}
    for name, entry in pairs(self.optionExtensions or {}) do
        if type(entry) == "table" and type(entry.callback) == "function" then
            ordered[#ordered + 1] = { name = name, callback = entry.callback, priority = tonumber(entry.priority) or 100 }
        end
    end
    table.sort(ordered, function(a, b)
        if a.priority == b.priority then return a.name < b.name end
        return a.priority < b.priority
    end)
    for _, entry in ipairs(ordered) do
        local ok, err = pcall(entry.callback, options)
        if not ok and EPC and type(EPC.Print) == "function" then
            EPC:Print("Settings extension failed (" .. entry.name .. "): " .. tostring(err))
        end
    end
end


-- v0.29.787: searchable Settings index. Search never changes a SavedVariable;
-- it only opens the owning submenus and scrolls the requested LAM control into view.
local function normalizeSettingsSearch029787(value)
    value = string.lower(tostring(value or ""))
    value = string.gsub(value, "|c%x%x%x%x%x%x", "")
    value = string.gsub(value, "|r", "")
    value = string.gsub(value, "[^%w%s/_%-]", " ")
    value = string.gsub(value, "%s+", " ")
    value = string.gsub(value, "^%s+", "")
    value = string.gsub(value, "%s+$", "")
    return value
end

local function settingsSearchScore029787(entry, query)
    if query == "" then return nil end
    local name = entry.searchName or ""
    local path = entry.searchPath or ""
    local text = entry.searchText or path
    if name == query then return 0 end
    if string.sub(name, 1, #query) == query then return 10 end
    local namePos = string.find(name, query, 1, true)
    if namePos then return 20 + namePos end
    local pathPos = string.find(path, query, 1, true)
    if pathPos then return 100 + pathPos end

    local allWords = true
    local wordPenalty = 0
    for word in string.gmatch(query, "%S+") do
        local pos = string.find(text, word, 1, true)
        if not pos then allWords = false break end
        wordPenalty = wordPenalty + pos
    end
    if allWords then return 200 + wordPenalty end
    return nil
end

function S:RefreshSettingsSearch029787(query)
    query = normalizeSettingsSearch029787(query)
    self.searchQuery029787 = query
    local ranked = {}
    for _, entry in ipairs(self.settingsSearchIndex029787 or {}) do
        local score = settingsSearchScore029787(entry, query)
        if score then
            ranked[#ranked + 1] = { score = score, entry = entry }
        end
    end
    table.sort(ranked, function(a, b)
        if a.score == b.score then return a.entry.path < b.entry.path end
        return a.score < b.score
    end)

    local choices, values = {}, {}
    self.settingsSearchResults029787 = {}
    local limit = math.min(#ranked, 30)
    for i = 1, limit do
        local entry = ranked[i].entry
        self.settingsSearchResults029787[#self.settingsSearchResults029787 + 1] = entry
        choices[#choices + 1] = entry.path
        values[#values + 1] = entry.id
    end
    if #choices == 0 then
        choices[1] = query == "" and "Type a setting name above" or "No matching settings"
        values[1] = 0
    end

    self.searchSelected029787 = values[1] or 0
    local control = rawget(_G, "EAS_SettingsSearchResults029787")
    if control and type(control.UpdateChoices) == "function" then
        pcall(control.UpdateChoices, control, choices, values)
        if control.dropdown and type(control.dropdown.SetSelectedItem) == "function" then
            pcall(control.dropdown.SetSelectedItem, control.dropdown, choices[1])
        end
    end
    return self.settingsSearchResults029787
end

local function openSettingsSubmenu029787(control)
    if not control or control.open == true then return end
    control.open = true
    if control.animation and type(control.animation.PlayFromStart) == "function" then
        pcall(control.animation.PlayFromStart, control.animation)
    elseif control.scroll then
        if type(control.scroll.SetResizeToFitDescendents) == "function" then
            pcall(control.scroll.SetResizeToFitDescendents, control.scroll, true)
        end
    end
end

function S:PerformSettingsJump029787(entry)
    if type(entry) ~= "table" then return false end
    local category = entry.categoryRef and rawget(_G, entry.categoryRef) or nil
    local feature = entry.featureRef and rawget(_G, entry.featureRef) or nil
    local target = entry.controlRef and rawget(_G, entry.controlRef) or nil
    if not target then return false end

    openSettingsSubmenu029787(category)
    openSettingsSubmenu029787(feature)

    local function scrollToTarget()
        local panel = S.panelObject
        local container = panel and panel.container
        if container and type(ZO_Scroll_ScrollControlIntoCentralView) == "function" then
            pcall(ZO_Scroll_ScrollControlIntoCentralView, container, target, true)
        elseif container and type(ZO_Scroll_ScrollControlIntoView) == "function" then
            pcall(ZO_Scroll_ScrollControlIntoView, container, target)
        elseif container and type(ZO_Scroll_ScrollToControl) == "function" then
            pcall(ZO_Scroll_ScrollToControl, container, target)
        end

        -- Brief gold emphasis makes the destination obvious without changing
        -- the actual setting control or its value.
        local label = target.label
        if label and type(label.SetColor) == "function" then
            local oldR, oldG, oldB, oldA
            if type(label.GetColor) == "function" then
                local okColor, r, g, b, a = pcall(label.GetColor, label)
                if okColor then oldR, oldG, oldB, oldA = r, g, b, a end
            end
            pcall(label.SetColor, label, 0.96, 0.80, 0.36, 1)
            if zo_callLater then
                zo_callLater(function()
                    if label and type(label.SetColor) == "function" then
                        if oldR ~= nil then
                            pcall(label.SetColor, label, oldR, oldG, oldB, oldA or 1)
                        elseif ZO_DEFAULT_ENABLED_COLOR then
                            pcall(label.SetColor, label, ZO_DEFAULT_ENABLED_COLOR:UnpackRGBA())
                        end
                    end
                end, 1200)
            end
        end
    end

    if zo_callLater then zo_callLater(scrollToTarget, 120) else scrollToTarget() end
    return true
end

function S:JumpToSetting029787(id)
    id = tonumber(id) or tonumber(self.searchSelected029787) or 0
    if id <= 0 then return false end
    local entry = self.settingsSearchById029787 and self.settingsSearchById029787[id] or nil
    if not entry then return false end

    self.pendingSettingsJump029787 = entry
    if LibAddonMenu2 and self.panelObject and type(LibAddonMenu2.OpenToPanel) == "function" then
        pcall(LibAddonMenu2.OpenToPanel, LibAddonMenu2, self.panelObject)
    end

    if self:PerformSettingsJump029787(entry) then
        self.pendingSettingsJump029787 = nil
        return true
    end
    return false
end

function S:HookSettingsSearchControls029787()
    local search = rawget(_G, "EAS_SettingsSearchBox029787")
    if search and search.editbox and not search.easLiveSearchHook029787 then
        search.easLiveSearchHook029787 = true
        search.editbox:SetHandler("OnTextChanged", function(edit)
            S:RefreshSettingsSearch029787(edit:GetText())
        end)
        search.editbox:SetHandler("OnEnter", function(edit)
            S:RefreshSettingsSearch029787(edit:GetText())
            edit:LoseFocus()
            local first = S.settingsSearchResults029787 and S.settingsSearchResults029787[1]
            if first then S:JumpToSetting029787(first.id) end
        end)
    end
    self:RefreshSettingsSearch029787(self.searchQuery029787 or "")
end

function S:Initialize()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelName = "ESOProgressionCoachSettings"

    local groupSlotChoices, groupSlotValues = {}, {}
    for i = 1, 12 do
        groupSlotChoices[i] = "Group Member " .. tostring(i)
        groupSlotValues[i] = i
    end

    local function selectedGroupTag()
        local slot = tonumber(EPC.saved.teamVisibilitySelectedGroupSlot) or 1
        slot = zo_clamp(slot, 1, 12)
        return "group" .. tostring(slot)
    end

    local function selectedGroupAvailable()
        local tag = selectedGroupTag()
        if type(DoesUnitExist) ~= "function" or not DoesUnitExist(tag) then return false end
        if type(AreUnitsEqual) == "function" and AreUnitsEqual(tag, "player") then return false end
        return true
    end

    local function selectedGroupOverride(create)
        if not selectedGroupAvailable() or not EPC.TeamVisibility or not EPC.TeamVisibility.GetGroupOverride then return nil end
        return EPC.TeamVisibility:GetGroupOverride(selectedGroupTag(), create == true)
    end

    local function selectedGroupRoleColor()
        if EPC.TeamVisibility and EPC.TeamVisibility.GetBaseRoleColor then
            return EPC.TeamVisibility:GetBaseRoleColor(selectedGroupTag())
        elseif EPC.TeamVisibility and EPC.TeamVisibility.GetRoleColor then
            return EPC.TeamVisibility:GetRoleColor(selectedGroupTag())
        end
        return 0.15, 0.95, 1.00, 1.00
    end

    local challengeNames, challengeValues = { "Adventurer", "Seasoned", "Master", "Vestige" }, { 0, 1, 2, 3 }
    if EPC.OverlandDifficulty and EPC.OverlandDifficulty.GetDifficultyChoices then
        challengeNames, challengeValues = EPC.OverlandDifficulty:GetDifficultyChoices()
    end
    S.panelName = panelName
    S.panelObject = LAM:RegisterAddonPanel(panelName, {
        type = "panel",
        name = EPC.displayName,
        displayName = "|cE8B347ESO Adventurer Suite|r",
        author = EPC.author,
        version = EPC.version,
        slashCommand = "/esosuite",
        -- v0.29.375: This panel has 500+ controls. LAM's registerForRefresh=true
        -- refreshes every control whenever the panel is shown and after every setting
        -- change, which caused a visible hitch each time Addon Settings opened. Keep
        -- LAM's automatic whole-panel refresh disabled and debounce dependency
        -- refreshes only after settings that can affect other controls change.
        registerForRefresh = false,
        registerForDefaults = true,
    })

    -- v0.29.375: Dependency refreshes remain available for controls whose disabled
    -- state depends on another checkbox/dropdown. They are intentionally debounced
    -- so dragging sliders or changing several options cannot force hundreds of LAM
    -- controls to reevaluate on the same frame.
    function S:RequestDependencyRefresh029375(delayMs)
        if not self.panelObject or type(self.panelObject.RefreshPanel) ~= "function" then return end
        if not EVENT_MANAGER then
            pcall(self.panelObject.RefreshPanel, self.panelObject)
            return
        end
        local key = EPC.name .. "_SettingsDependencyRefresh029375"
        EVENT_MANAGER:UnregisterForUpdate(key)
        EVENT_MANAGER:RegisterForUpdate(key, math.max(120, tonumber(delayMs) or 220), function()
            EVENT_MANAGER:UnregisterForUpdate(key)
            if S and S.panelObject and type(S.panelObject.RefreshPanel) == "function" then
                pcall(S.panelObject.RefreshPanel, S.panelObject)
            end
        end)
    end

    local rawOptions = {
        {
            type = "description",
            title = "Gameplay hotkeys",
            text = "Assign 'Open / Close Tamriel Codex' under Controls > Keybindings > General > ESO Adventurer Suite. The same key opens and closes the Tamriel Codex. The old standalone menu has been removed; the Tamriel Codex is the main interface.",
        },
        {
            type = "description",
            title = "Compatibility status",
            text = EPC.Compatibility and (EPC.Compatibility:GetSummary() .. "\n\nThe addon cannot self-download code. If ESO updates, this build probes the current API and keeps compatible modules running where possible. Use /esosuite compat for detailed module diagnostics, then update through ESOUI/Minion when a validated build is released.") or "Compatibility diagnostics unavailable.",
        },
        {
            type = "checkbox", name = "Enable suite systems",
            getFunc = function() return EPC.saved.enabled end,
            setFunc = function(v) EPC:SetEnabled(v, "settings") end,
            default = EPC.defaults.enabled,
        },
        {
            type = "checkbox", name = "Smart Combat Advisor",
            tooltip = "Continuously evaluates every usable skill on both weapon bars and highlights the single best next button for your build at that exact moment: buffs, DoTs, debuffs, procs, stacks, executes, Ultimates, sustain, healing/defense, and bar swaps. It never casts abilities, blocks, swaps bars, presses keys, or automates combat input.",
            getFunc = function() return EPC.saved.rotationAssistantEnabled ~= false end,
            setFunc = function(v)
                if EPC.RotationAssistant then EPC.RotationAssistant:SetEnabled(v)
                else EPC.saved.rotationAssistantEnabled = v end
            end,
            default = EPC.defaults.rotationAssistantEnabled,
        },
        {
            type = "dropdown", name = "Smart Advisor specialization",
            tooltip = "Auto Detect follows Tank/Healer role selection first, then distinguishes Magicka, Stamina, or Hybrid DPS from your maximum resources. Override it here for unusual builds.",
            choices = { "Auto Detect", "Magicka DPS", "Stamina DPS", "Hybrid DPS", "Healer", "Tank" },
            choicesValues = { "AUTO", "MAGICKA_DPS", "STAMINA_DPS", "HYBRID", "HEALER", "TANK" },
            getFunc = function() return EPC.saved.rotationAdvisorRoleMode or "AUTO" end,
            setFunc = function(v) EPC.saved.rotationAdvisorRoleMode = v if EPC.RotationAssistant then EPC.RotationAssistant:Refresh() end end,
            default = EPC.defaults.rotationAdvisorRoleMode,
        },
        {
            type = "dropdown", name = "Smart Advisor display",
            tooltip = "Highlight Action Bar is the default: it glows the best next ability and shows a movable weapon-bar swap cue when the recommendation is on the other bar. Full Overlay and Compact remain optional. Hidden keeps the advisor logic running without visual attack recommendations. Block warnings are controlled separately.",
            choices = { "Full Overlay", "Compact Next Skill", "Highlight Action Bar", "Hidden / Background" },
            choicesValues = { "FULL", "COMPACT", "HIGHLIGHT", "HIDDEN" },
            getFunc = function() return EPC.saved.rotationAssistantDisplayMode029161 or "HIGHLIGHT" end,
            setFunc = function(v) EPC.saved.rotationAssistantDisplayMode029161 = v if EPC.RotationAssistant then EPC.RotationAssistant:Refresh() end end,
            default = EPC.defaults.rotationAssistantDisplayMode029161,
        },
        {
            type = "button", name = "Test Action-Bar Highlight",
            tooltip = "Highlights the first visible equipped ability for 3 seconds so you can verify the Smart Combat Advisor highlight without entering combat.",
            func = function()
                if EPC.RotationAssistant and EPC.RotationAssistant.TestActionHighlight029166 then
                    EPC.RotationAssistant:TestActionHighlight029166()
                end
            end,
            width = "half",
        },
        {
            type = "checkbox", name = "Show BLOCK reactions",
            tooltip = "Routes likely incoming heavy/dangerous attacks into the same Boss Mechanics / Combat Reaction overlay. There is no separate BLOCK window; the Suite only tells you to block and never blocks automatically.",
            getFunc = function() return EPC.saved.rotationBlockWarningEnabled029161 ~= false end,
            setFunc = function(v) EPC.saved.rotationBlockWarningEnabled029161 = v == true if EPC.RotationAssistant then EPC.RotationAssistant:Refresh() end end,
            default = EPC.defaults.rotationBlockWarningEnabled029161,
        },
        {
            type = "dropdown", name = "Block warning sensitivity",
            tooltip = "Conservative warns for obvious Heavy Attacks and learned attacks. Normal also recognizes common slam/smash/charge-style casts. Aggressive warns for any cast-time combat event that ESO reports as targeting you.",
            choices = { "Conservative", "Normal", "Aggressive" },
            choicesValues = { "CONSERVATIVE", "NORMAL", "AGGRESSIVE" },
            getFunc = function() return EPC.saved.rotationBlockSensitivity029161 or "NORMAL" end,
            setFunc = function(v) EPC.saved.rotationBlockSensitivity029161 = v end,
            default = EPC.defaults.rotationBlockSensitivity029161,
        },
        {
            type = "checkbox", name = "Learn dangerous attacks",
            tooltip = "Remembers ability IDs that you successfully block or that hit you for roughly a quarter of your maximum Health. If ESO later reports that ability beginning again, the Suite can warn you earlier.",
            getFunc = function() return EPC.saved.rotationBlockLearning029161 ~= false end,
            setFunc = function(v) EPC.saved.rotationBlockLearning029161 = v == true end,
            default = EPC.defaults.rotationBlockLearning029161,
        },
        {
            type = "dropdown", name = "Combat role awareness",
            tooltip = "Auto follows your ESO preferred Group Finder role when available. You can override it to Damage, Healer, or Tank so BUILD, GEAR, SKILLS, COMBAT, and the hidden combat HUD use role-specific priorities.",
            choices = { "Auto (Group Finder role)", "Damage", "Healer", "Tank" },
            choicesValues = { "AUTO", "DAMAGE", "HEALER", "TANK" },
            getFunc = function() return EPC.Role and EPC.Role:GetMode() or (EPC.saved.combatRoleMode or "AUTO") end,
            setFunc = function(v)
                if EPC.Role then EPC.Role:SetMode(v) else EPC.saved.combatRoleMode = v EPC:RequestRefresh("role-mode") end
            end,
            default = EPC.defaults.combatRoleMode,
        },
        {
            type = "header", name = "Boss Mechanics Coach",
        },
        {
            type = "checkbox", name = "Enable Boss Mechanics Coach",
            tooltip = "Endgame encounter coach for supported dungeons, trials, and arenas. Detects bosses and mechanics, gives role-aware live action/position callouts, learns recurring timing, and grades mechanic execution. Guidance only: it never moves, blocks, interrupts, dodges, or presses abilities for you.",
            getFunc = function() return EPC.saved.bossMechanicsEnabled029198 ~= false end,
            setFunc = function(v) EPC.saved.bossMechanicsEnabled029198 = v == true if EPC.BossMechanicsAssistant then EPC.BossMechanicsAssistant:Refresh() end end,
            default = EPC.defaults.bossMechanicsEnabled029198,
        },
        {
            type = "dropdown", name = "Boss Mechanics visibility",
            tooltip = "Controls when the unified Boss Mechanics / Combat Reaction panel is allowed to stay visible. Mechanics / Reactions Only is the clean default and hides the panel between actionable callouts.",
            choices = { "Mechanics / Reactions Only", "Boss Combat + Mechanics", "Any Combat + Mechanics", "Always" },
            choicesValues = { "MECHANIC", "BOSS", "COMBAT", "ALWAYS" },
            getFunc = function() return EPC.saved.bossMechanicsVisibility029204 or "MECHANIC" end,
            setFunc = function(v)
                EPC.saved.bossMechanicsVisibility029204 = v or "MECHANIC"
                if EPC.BossMechanicsAssistant then EPC.BossMechanicsAssistant:Refresh() end
            end,
            default = EPC.defaults.bossMechanicsVisibility029204 or "MECHANIC",
        },
        {
            type = "checkbox", name = "Show pre-pull boss briefing",
            tooltip = "Optional. Shows a supported boss briefing before combat. Leave this OFF for a completely quiet overlay until an actual mechanic/reaction needs your attention.",
            getFunc = function() return EPC.saved.bossMechanicsPrePull029204 == true end,
            setFunc = function(v) EPC.saved.bossMechanicsPrePull029204 = v == true if EPC.BossMechanicsAssistant then EPC.BossMechanicsAssistant:Refresh() end end,
            default = EPC.defaults.bossMechanicsPrePull029204 == true,
        },
        {
            type = "checkbox", name = "Role-aware boss callouts",
            tooltip = "Adds Tank, Healer, or DPS-specific mechanic instructions using your Combat role awareness selection.",
            getFunc = function() return EPC.saved.bossMechanicsRoleAware029198 ~= false end,
            setFunc = function(v) EPC.saved.bossMechanicsRoleAware029198 = v == true if EPC.BossMechanicsAssistant then EPC.BossMechanicsAssistant:Refresh() end end,
            default = EPC.defaults.bossMechanicsRoleAware029198,
        },
        {
            type = "checkbox", name = "Learn boss mechanics and timing",
            tooltip = "Learns stable ability IDs and transition timing from your own pulls. This improves matching and lets the coach adapt predictions to repeated encounters without automating combat.",
            getFunc = function() return EPC.saved.bossMechanicsLearningEnabled029198 ~= false end,
            setFunc = function(v) EPC.saved.bossMechanicsLearningEnabled029198 = v == true end,
            default = EPC.defaults.bossMechanicsLearningEnabled029198,
        },
        {
            type = "checkbox", name = "Predict likely next mechanic",
            tooltip = "Uses repeated-pull transition history and the boss health band to show a confidence-rated likely next mechanic and learned timing when enough samples exist.",
            getFunc = function() return EPC.saved.bossMechanicsPredictionEnabled029198 ~= false end,
            setFunc = function(v) EPC.saved.bossMechanicsPredictionEnabled029198 = v == true if EPC.BossMechanicsAssistant then EPC.BossMechanicsAssistant:Refresh() end end,
            default = EPC.defaults.bossMechanicsPredictionEnabled029198,
        },
        {
            type = "slider", name = "Boss Coach width", min = 420, max = 1000, step = 20,
            tooltip = "Sets the Boss Mechanics / Combat Reaction panel width. Move the panel in ESO Edit HUD; resize it with the Suite size controls.",
            getFunc = function() return math.floor(tonumber(EPC.saved.bossMechanicsWidth029203) or 640) end,
            setFunc = function(v)
                EPC.saved.bossMechanicsWidth029203 = v
                if EPC.BossMechanicsAssistant and EPC.BossMechanicsAssistant.SetSize029203 then EPC.BossMechanicsAssistant:SetSize029203(v, EPC.saved.bossMechanicsHeight029203) end
            end,
            default = EPC.defaults.bossMechanicsWidth029203 or 640,
        },
        {
            type = "slider", name = "Boss Coach height", min = 110, max = 300, step = 10,
            tooltip = "Sets the Boss Mechanics / Combat Reaction panel height. Text and spacing reflow to the new size.",
            getFunc = function() return math.floor(tonumber(EPC.saved.bossMechanicsHeight029203) or 154) end,
            setFunc = function(v)
                EPC.saved.bossMechanicsHeight029203 = v
                if EPC.BossMechanicsAssistant and EPC.BossMechanicsAssistant.SetSize029203 then EPC.BossMechanicsAssistant:SetSize029203(EPC.saved.bossMechanicsWidth029203, v) end
            end,
            default = EPC.defaults.bossMechanicsHeight029203 or 154,
        },
        {
            type = "slider", name = "Boss Coach overall scale", min = 70, max = 140, step = 5,
            tooltip = "Scales the entire panel after its width/height are applied. Position it in ESO Edit HUD and use the width/height controls above for precise sizing.",
            getFunc = function() return math.floor((tonumber(EPC.saved.bossMechanicsScale029198) or 1.0) * 100) end,
            setFunc = function(v) EPC.saved.bossMechanicsScale029198 = v / 100 if EPC.BossMechanicsAssistant then EPC.BossMechanicsAssistant:ApplyScale() end end,
            default = math.floor((EPC.defaults.bossMechanicsScale029198 or 1.0) * 100),
        },
        {
            type = "slider", name = "Boss Coach opacity", min = 50, max = 100, step = 5,
            getFunc = function() return math.floor((tonumber(EPC.saved.bossMechanicsAlpha029198) or 0.97) * 100) end,
            setFunc = function(v) EPC.saved.bossMechanicsAlpha029198 = v / 100 if EPC.BossMechanicsAssistant then EPC.BossMechanicsAssistant:ApplyScale() end end,
            default = math.floor((EPC.defaults.bossMechanicsAlpha029198 or 0.97) * 100),
        },
        {
            type = "button", name = "Reset Boss Mechanics Coach size", buttonText = "Reset Size",
            func = function() if EPC.BossMechanicsAssistant and EPC.BossMechanicsAssistant.ResetSize029203 then EPC.BossMechanicsAssistant:ResetSize029203() EPC.BossMechanicsAssistant:Refresh() end end,
            width = "half",
        },
        {
            type = "button", name = "Reset Boss Mechanics Coach position", buttonText = "Reset Position",
            func = function() if EPC.BossMechanicsAssistant then EPC.BossMechanicsAssistant:ResetPosition() EPC.BossMechanicsAssistant:Refresh() end end,
            width = "half",
        },
        {
            type = "header", name = "Gameplay & Challenge Difficulty",
        },
        {
            type = "description",
            title = "Automatically control ESO's native Challenge Difficulty",
            text = "Choose a difficulty for overland situations, or enable Leveling Journey to let your character level and the current zone choose it automatically. Difficulty changes wait until combat ends and use ESO's native Challenge Difficulty system.",
        },
        {
            type = "checkbox", name = "Enable automatic Challenge Difficulty",
            getFunc = function() return EPC.saved.overlandDifficultyEnabled == true end,
            setFunc = function(v) EPC.saved.overlandDifficultyEnabled = v == true if EPC.OverlandDifficulty then EPC.OverlandDifficulty:RequestRefresh(100) end end,
            default = EPC.defaults.overlandDifficultyEnabled,
        },
        {
            type = "checkbox", name = "Leveling Journey",
            tooltip = "Assigns adventure zones levels from 1 to 50 and automatically chooses a Challenge Difficulty based on your character's level. Your custom rules are preserved and return when this is turned off. World Bosses are capped at Master.",
            getFunc = function() return EPC.saved.overlandDifficultyLevelingJourney == true end,
            setFunc = function(v) EPC.saved.overlandDifficultyLevelingJourney = v == true if EPC.OverlandDifficulty then EPC.OverlandDifficulty:RefreshMapLevelLabel() EPC.OverlandDifficulty:RequestRefresh(100) end end,
            default = EPC.defaults.overlandDifficultyLevelingJourney,
        },
        {
            type = "checkbox", name = "Show zone levels on World Map",
            getFunc = function() return EPC.saved.overlandDifficultyShowZoneLevelsMap ~= false end,
            setFunc = function(v) EPC.saved.overlandDifficultyShowZoneLevelsMap = v == true if EPC.OverlandDifficulty then EPC.OverlandDifficulty:RefreshMapLevelLabel() end end,
            default = EPC.defaults.overlandDifficultyShowZoneLevelsMap,
            width = "half",
        },
        {
            type = "checkbox", name = "Zone entry difficulty message",
            tooltip = "Shows the zone level and the difficulty icon/name when you enter a zone.",
            getFunc = function() return EPC.saved.overlandDifficultyZoneMessages == true end,
            setFunc = function(v) EPC.saved.overlandDifficultyZoneMessages = v == true end,
            default = EPC.defaults.overlandDifficultyZoneMessages,
            width = "half",
        },
        {
            type = "checkbox", name = "Use Companion difficulty rule",
            tooltip = "When a companion is active, temporarily use the Companion difficulty selected below. When the companion is dismissed, the normal zone/activity rule returns.",
            getFunc = function() return EPC.saved.overlandDifficultyCompanionEnabled == true end,
            setFunc = function(v) EPC.saved.overlandDifficultyCompanionEnabled = v == true if EPC.OverlandDifficulty then EPC.OverlandDifficulty:RequestRefresh(100) end end,
            default = EPC.defaults.overlandDifficultyCompanionEnabled,
            width = "half",
        },
        {
            type = "dropdown", name = "Companion difficulty",
            tooltip = "Challenge Difficulty used while your companion is summoned.",
            choices = challengeNames,
            choicesValues = challengeValues,
            getFunc = function() return tonumber(EPC.saved.overlandDifficultyCompanion) or 3 end,
            setFunc = function(v) EPC.saved.overlandDifficultyCompanion = tonumber(v) or 3 if EPC.OverlandDifficulty then EPC.OverlandDifficulty:RequestRefresh(100) end end,
            default = EPC.defaults.overlandDifficultyCompanion,
            width = "half",
        },
        {
            type = "slider", name = "World Boss wave hold", min = 15, max = 120, step = 5,
            tooltip = "Keeps the World Boss difficulty rule active for this many seconds after a World Boss is detected. Prevents multi-wave bosses from reverting to Open World difficulty between waves.",
            getFunc = function() return tonumber(EPC.saved.overlandDifficultyWorldBossHoldSeconds) or 45 end,
            setFunc = function(v) EPC.saved.overlandDifficultyWorldBossHoldSeconds = tonumber(v) or 45 end,
            default = EPC.defaults.overlandDifficultyWorldBossHoldSeconds,
        },
        {
            type = "checkbox", name = "Show Challenge Difficulty symbol overlay",
            tooltip = "Displays the currently active Challenge Difficulty symbol as a movable HUD overlay. Move it in ESO Edit HUD and scale it below.",
            getFunc = function() return EPC.saved.overlandDifficultyShowOverlay == true end,
            setFunc = function(v) EPC.saved.overlandDifficultyShowOverlay = v == true if EPC.ChallengeDifficultyOverlay then EPC.ChallengeDifficultyOverlay:Refresh() end end,
            default = EPC.defaults.overlandDifficultyShowOverlay,
            width = "half",
        },
        {
            type = "slider", name = "Challenge Difficulty symbol size", min = 50, max = 200, step = 5,
            tooltip = "Scales the Challenge Difficulty symbol overlay from 50% to 200%.",
            getFunc = function() return math.floor((tonumber(EPC.saved.overlandDifficultyOverlayScale) or 1.0) * 100 + 0.5) end,
            setFunc = function(v) EPC.saved.overlandDifficultyOverlayScale = (tonumber(v) or 100) / 100 if EPC.ChallengeDifficultyOverlay then EPC.ChallengeDifficultyOverlay:Refresh() end end,
            default = (EPC.defaults.overlandDifficultyOverlayScale or 1.0) * 100,
            width = "half",
        },
        {
            type = "button", name = "Reset Challenge Difficulty overlay position", buttonText = "Reset Position",
            func = function() if EPC.ChallengeDifficultyOverlay then EPC.ChallengeDifficultyOverlay:ResetPosition() EPC.ChallengeDifficultyOverlay:Refresh() end end,
            width = "half",
        },
        {
            type = "description",
            text = "To move the Challenge Difficulty symbol, open ESO Edit HUD and place the ESO Adventurer Suite entry where you want it.",
            width = "full",
        },
        {
            type = "slider", name = "Nearby activity detection radius", min = 30, max = 200, step = 5,
            tooltip = "Distance in meters used to detect nearby World Boss, World Event, Dragon, and Public Dungeon POIs.",
            getFunc = function() return tonumber(EPC.saved.overlandDifficultyPoiRadius) or 85 end,
            setFunc = function(v) EPC.saved.overlandDifficultyPoiRadius = tonumber(v) or 85 end,
            default = EPC.defaults.overlandDifficultyPoiRadius,
        },
        {
            type = "dropdown", name = "Open World difficulty",
            choices = challengeNames,
            choicesValues = challengeValues,
            getFunc = function() return tonumber(EPC.saved.overlandDifficultyOpenWorld) or 0 end,
            setFunc = function(v) EPC.saved.overlandDifficultyOpenWorld = tonumber(v) or 0 if EPC.OverlandDifficulty then EPC.OverlandDifficulty:RequestRefresh(100) end end,
            default = EPC.defaults.overlandDifficultyOpenWorld,
        },
        {
            type = "dropdown", name = "Delve difficulty",
            choices = challengeNames,
            choicesValues = challengeValues,
            getFunc = function() return tonumber(EPC.saved.overlandDifficultyDelve) or 1 end,
            setFunc = function(v) EPC.saved.overlandDifficultyDelve = tonumber(v) or 1 if EPC.OverlandDifficulty then EPC.OverlandDifficulty:RequestRefresh(100) end end,
            default = EPC.defaults.overlandDifficultyDelve,
            width = "half",
        },
        {
            type = "dropdown", name = "Public Dungeon difficulty",
            choices = challengeNames,
            choicesValues = challengeValues,
            getFunc = function() return tonumber(EPC.saved.overlandDifficultyPublicDungeon) or 2 end,
            setFunc = function(v) EPC.saved.overlandDifficultyPublicDungeon = tonumber(v) or 2 if EPC.OverlandDifficulty then EPC.OverlandDifficulty:RequestRefresh(100) end end,
            default = EPC.defaults.overlandDifficultyPublicDungeon,
            width = "half",
        },
        {
            type = "dropdown", name = "World Boss difficulty",
            choices = challengeNames,
            choicesValues = challengeValues,
            getFunc = function() return tonumber(EPC.saved.overlandDifficultyWorldBoss) or 2 end,
            setFunc = function(v) EPC.saved.overlandDifficultyWorldBoss = tonumber(v) or 2 if EPC.OverlandDifficulty then EPC.OverlandDifficulty:RequestRefresh(100) end end,
            default = EPC.defaults.overlandDifficultyWorldBoss,
            width = "half",
        },
        {
            type = "dropdown", name = "World Event difficulty",
            choices = challengeNames,
            choicesValues = challengeValues,
            getFunc = function() return tonumber(EPC.saved.overlandDifficultyWorldEvent) or 2 end,
            setFunc = function(v) EPC.saved.overlandDifficultyWorldEvent = tonumber(v) or 2 if EPC.OverlandDifficulty then EPC.OverlandDifficulty:RequestRefresh(100) end end,
            default = EPC.defaults.overlandDifficultyWorldEvent,
            width = "half",
        },
        {
            type = "dropdown", name = "Dragon difficulty",
            choices = challengeNames,
            choicesValues = challengeValues,
            getFunc = function() return tonumber(EPC.saved.overlandDifficultyDragon) or 2 end,
            setFunc = function(v) EPC.saved.overlandDifficultyDragon = tonumber(v) or 2 if EPC.OverlandDifficulty then EPC.OverlandDifficulty:RequestRefresh(100) end end,
            default = EPC.defaults.overlandDifficultyDragon,
            width = "half",
        },
        {
            type = "checkbox", name = "History Bosses (Experimental)",
            tooltip = "When enabled, a boss targeted by your reticle can temporarily use the History Boss difficulty rule. Experimental because not every story boss is exposed consistently by ESO.",
            getFunc = function() return EPC.saved.overlandDifficultyHistoryBosses == true end,
            setFunc = function(v) EPC.saved.overlandDifficultyHistoryBosses = v == true end,
            default = EPC.defaults.overlandDifficultyHistoryBosses,
            width = "half",
        },
        {
            type = "dropdown", name = "History Boss difficulty",
            choices = challengeNames,
            choicesValues = challengeValues,
            getFunc = function() return tonumber(EPC.saved.overlandDifficultyHistoryBoss) or 2 end,
            setFunc = function(v) EPC.saved.overlandDifficultyHistoryBoss = tonumber(v) or 2 end,
            default = EPC.defaults.overlandDifficultyHistoryBoss,
            width = "half",
        },
        {
            type = "dropdown", name = "Current zone override",
            tooltip = "Sets an Open World-only override for the zone you are standing in. Delves, Public Dungeons, bosses, events, and Dragons keep their own rules.",
            choices = challengeNames,
            choicesValues = challengeValues,
            getFunc = function() return EPC.OverlandDifficulty:GetCurrentZoneOverride() or tonumber(EPC.saved.overlandDifficultyOpenWorld) or 0 end,
            setFunc = function(v) EPC.OverlandDifficulty:SetCurrentZoneOverride(v) end,
            default = EPC.defaults.overlandDifficultyOpenWorld,
            width = "half",
        },
        {
            type = "button", name = "Clear current zone override", buttonText = "Use Open World Rule",
            func = function() if EPC.OverlandDifficulty then EPC.OverlandDifficulty:SetCurrentZoneOverride(nil) end end,
            disabled = function() return not EPC.OverlandDifficulty or EPC.OverlandDifficulty:GetCurrentZoneOverride() == nil end,
            width = "half",
        },
        {
            type = "header", name = "Live Group Finder",
        },
        {
            type = "checkbox", name = "Hide WTS listings",
            tooltip = "Hides obvious WTS/selling listings from the Group Finder Codex results outside the Custom category.",
            getFunc = function() return EPC.saved.groupFinderWidgetHideWTS ~= false end,
            setFunc = function(v)
                EPC.saved.groupFinderWidgetHideWTS = v == true
                if EPC.Journal and EPC.Journal.activeTab == "GROUPFINDER" and EPC.Journal.RefreshSuitePage then EPC.Journal:RefreshSuitePage("GROUPFINDER") end
            end,
            default = EPC.defaults.groupFinderWidgetHideWTS,
        },
        {
            type = "checkbox", name = "Hide listings above my CP",
            tooltip = "Hide Codex Group Finder listings whose Champion Point requirement is above your current Champion Points.",
            getFunc = function() return EPC.saved.groupFinderWidgetHideHighCP == true end,
            setFunc = function(v)
                EPC.saved.groupFinderWidgetHideHighCP = v == true
                if EPC.Journal and EPC.Journal.activeTab == "GROUPFINDER" and EPC.Journal.RefreshSuitePage then EPC.Journal:RefreshSuitePage("GROUPFINDER") end
            end,
            default = EPC.defaults.groupFinderWidgetHideHighCP,
        },
        {
            type = "checkbox", name = "Last Boss Highlight",
            tooltip = "Makes matching last/final-boss listings in the Tamriel Codex Group Finder pulse through rainbow colors. Detection checks the listing title and description for common last-boss phrases and shorthand.",
            getFunc = function() return EPC.saved.groupFinderWidgetLastBossHighlight == true end,
            setFunc = function(v)
                EPC.saved.groupFinderWidgetLastBossHighlight = v == true
                if EPC.Journal and EPC.Journal.activeTab == "GROUPFINDER" and EPC.Journal.RefreshSuitePage then EPC.Journal:RefreshSuitePage("GROUPFINDER") end
            end,
            default = EPC.defaults.groupFinderWidgetLastBossHighlight,
        },
        {
            type = "checkbox", name = "Show combat HUD",
            tooltip = "Shows the personal combat meter. Use the visibility option below to keep it always available in gameplay or show it only while in combat.",
            getFunc = function() return EPC.saved.showCombatHud ~= false end,
            setFunc = function(v)
                EPC.saved.showCombatHud = v == true
                if EPC.UI and EPC.UI.UpdateCombatHUD and EPC.Combat then EPC.UI:UpdateCombatHUD(EPC.Combat:GetHUDSummary()) end
            end,
            default = EPC.defaults.showCombatHud,
        },
        {
            type = "dropdown", name = "Combat HUD visibility",
            choices = { "Always", "Combat Only" }, choicesValues = { "ALWAYS", "COMBAT" },
            getFunc = function() return EPC.saved.combatHudVisibility or "COMBAT" end,
            setFunc = function(v)
                EPC.saved.combatHudVisibility = v
                if EPC.RefreshGameplayOverlays then EPC:RefreshGameplayOverlays() end
                if EPC.UI and EPC.UI.UpdateCombatHUD then
                    local summary = EPC.Combat and EPC.Combat.GetHUDSummary and EPC.Combat:GetHUDSummary() or nil
                    EPC.UI:UpdateCombatHUD(summary)
                end
            end,
            default = EPC.defaults.combatHudVisibility,
        },
        {
            type = "button", name = "Move compact combat HUD",
            tooltip = "Shows a combat-HUD preview, releases the mouse, and lets you drag the combat meter independently from the main suite. Use /esosuite hud lock when finished.",
            func = function() if EPC.SetCombatHUDMoveMode then EPC:SetCombatHUDMoveMode(true) end end,
            width = "half",
        },
        {
            type = "button", name = "Lock combat HUD",
            tooltip = "Finish moving the compact combat meter and return it to non-interactive HUD behavior.",
            func = function() if EPC.SetCombatHUDMoveMode then EPC:SetCombatHUDMoveMode(false) end end,
            width = "half",
        },
        {
            type = "button", name = "Reset combat HUD position",
            tooltip = "Moves the compact combat meter back to its default upper-right position.",
            func = function() if EPC.ResetCombatHUDPosition then EPC:ResetCombatHUDPosition() end end,
            width = "half",
        },
        {
            type = "slider", name = "Combat HUD scale", min = 70, max = 140, step = 5,
            getFunc = function() return math.floor((EPC.saved.combatHudScale or 1.0) * 100) end,
            setFunc = function(v)
                EPC.saved.combatHudScale = v / 100
                if EPC.UI and EPC.UI.combatHud then EPC.UI.combatHud:SetScale(EPC.saved.combatHudScale) end
            end,
            default = math.floor((EPC.defaults.combatHudScale or 1.0) * 100),
        },
        {
            type = "slider", name = "Combat HUD opacity", min = 35, max = 100, step = 1,
            getFunc = function() return math.floor((EPC.saved.combatHudAlpha or 0.94) * 100) end,
            setFunc = function(v)
                EPC.saved.combatHudAlpha = v / 100
                if EPC.UI and EPC.UI.combatHud then EPC.UI.combatHud:SetAlpha(EPC.saved.combatHudAlpha) end
            end,
            default = math.floor((EPC.defaults.combatHudAlpha or 0.94) * 100),
        },
        {
            type = "header", name = "Game Mode Combat Report",
        },
        {
            type = "description",
            title = "Hotkey-only detailed report",
            text = "Assign Open / Close Game Mode Combat Report under Controls > Keybindings > ESO Adventurer Suite. The same key opens and closes the report; it never opens automatically after combat.",
        },
        {
            type = "checkbox", name = "Enable Game Mode Combat Report",
            tooltip = "Enables the hotkey-driven Game Mode Combat Report and keeps up to 30 recent reports. It shares the same fight recorder as Live Combat Stats, keeps player DPS/HPS separate from companions and damaging pets/summons, and records abilities, incoming damage, resources, effects, and effective PEN/PWR/SR/PR/CC/CD.",
            getFunc = function() return EPC.saved.gameModeReportEnabled ~= false end,
            setFunc = function(v)
                EPC.saved.gameModeReportEnabled = v == true
                if EPC.GameModeReport and EPC.GameModeReport.RefreshSettings then EPC.GameModeReport:RefreshSettings() end
            end,
            default = EPC.defaults.gameModeReportEnabled,
        },
        {
            type = "slider", name = "Report opacity", min = 45, max = 100, step = 1,
            getFunc = function() return math.floor((EPC.saved.gameModeReportAlpha or 0.96) * 100) end,
            setFunc = function(v)
                EPC.saved.gameModeReportAlpha = v / 100
                if EPC.GameModeReport and EPC.GameModeReport.RefreshSettings then EPC.GameModeReport:RefreshSettings() end
            end,
            default = math.floor((EPC.defaults.gameModeReportAlpha or 0.96) * 100),
        },
        {
            type = "button", name = "Reset report position and size",
            tooltip = "Returns the report to its centered 1120 x 760 layout.",
            func = function() if EPC.GameModeReport and EPC.GameModeReport.ResetPosition then EPC.GameModeReport:ResetPosition() end end,
            width = "half",
        },
        {
            type = "button", name = "Clear saved combat reports",
            tooltip = "Clears the report history. This does not reset personal bests or the compact combat HUD.",
            func = function() if EPC.GameModeReport and EPC.GameModeReport.ClearHistory then EPC.GameModeReport:ClearHistory() end end,
            width = "half",
        },
        {
            type = "header", name = "Inventory Grid Categories",
        },
        {
            type = "checkbox", name = "Enable inventory categories",
            tooltip = "Groups inventory, bank, store/trading and deconstruction items into API-based categories. Turn this off to keep the Suite grid without category headers and restore native interaction lists without Suite headers.",
            getFunc = function() return EPC.saved.inventoryGridCategoriesEnabled029365 ~= false end,
            setFunc = function(v)
                EPC.saved.inventoryGridCategoriesEnabled029365 = v == true
                local grid = rawget(_G, "EASInventoryGrid")
                if grid and grid.RefreshCategoryMode029365 then grid:RefreshCategoryMode029365() end
            end,
            default = EPC.defaults.inventoryGridCategoriesEnabled029365,
        },
        {
            type = "dropdown", name = "Category priority",
            tooltip = "Controls which broad category families appear first. Item identity is API-based; translated item names are only used for display and alphabetical tie-breaking.",
            choices = { "Gear First", "Consumables First", "Materials First", "Alphabetical" },
            choicesValues = { "GEAR_FIRST", "CONSUMABLES_FIRST", "MATERIALS_FIRST", "ALPHABETICAL" },
            getFunc = function() return EPC.saved.inventoryGridCategoryPriority029365 or "GEAR_FIRST" end,
            setFunc = function(v)
                EPC.saved.inventoryGridCategoryPriority029365 = tostring(v or "GEAR_FIRST")
                local grid = rawget(_G, "EASInventoryGrid")
                if grid and grid.RefreshCategoryMode029365 then grid:RefreshCategoryMode029365() end
            end,
            default = EPC.defaults.inventoryGridCategoryPriority029365,
        },
        {
            type = "slider", name = "Category font size", min = 12, max = 20, step = 1,
            tooltip = "Changes the category/header text size in the Suite inventory grid and the Suite category rows added to Bank, Store/Trading, and Deconstruction lists.",
            getFunc = function() return tonumber(EPC.saved.inventoryGridCategoryFontSize029377) or 15 end,
            setFunc = function(v)
                EPC.saved.inventoryGridCategoryFontSize029377 = tonumber(v) or 15
                local grid = rawget(_G, "EASInventoryGrid")
                if grid and grid.ApplyCategoryFontSize029377 then grid:ApplyCategoryFontSize029377(true) end
            end,
            default = EPC.defaults.inventoryGridCategoryFontSize029377 or 15,
        },
        {
            type = "header", name = "Character Gear Screen",
        },
        {
            type = "description",
            title = "Enhanced desktop equipment view",
            text = "Rebuilds ESO's native desktop Character / Equipment presentation around your real 3D character while keeping the real ESO equipment-slot buttons. The old center silhouette is removed. Gear information expands outward into the available side space, full item/set names get more room, while preserving the native keyboard/mouse equipment interaction.",
        },
        {
            type = "checkbox", name = "Enable Character Gear Screen",
            getFunc = function() return EPC.saved.characterGearScreenEnabled029206 ~= false end,
            setFunc = function(v)
                EPC.saved.characterGearScreenEnabled029206 = v == true
                if EPC.CharacterGearScreen then
                    if EPC.CharacterGearScreen.SetEnabled029365 then
                        EPC.CharacterGearScreen:SetEnabled029365(v == true)
                    elseif v then
                        EPC.CharacterGearScreen:RequestRefresh(10)
                    else
                        EPC.CharacterGearScreen:RestoreAll()
                    end
                end
            end,
            default = EPC.defaults.characterGearScreenEnabled029206,
        },
        {
            type = "checkbox", name = "Enhance companion equipment screen",
            getFunc = function() return EPC.saved.characterGearCompanion029206 ~= false end,
            setFunc = function(v) EPC.saved.characterGearCompanion029206 = v == true if EPC.CharacterGearScreen then EPC.CharacterGearScreen:RequestRefresh(10) end end,
            default = EPC.defaults.characterGearCompanion029206,
        },
        {
            type = "checkbox", name = "Adaptive safe-area layout",
            tooltip = "Recommended. Fits the gear cluster into the free desktop area between the left UI/chat and the inventory panel instead of using ultrawide-only coordinates.",
            getFunc = function() return EPC.saved.characterGearAdaptiveLayout029207 ~= false end,
            setFunc = function(v) EPC.saved.characterGearAdaptiveLayout029207 = v == true if EPC.CharacterGearScreen then EPC.CharacterGearScreen:RequestRefresh(10) end end,
            default = EPC.defaults.characterGearAdaptiveLayout029207,
        },
        {
            type = "dropdown", name = "Gear information density",
            tooltip = "Compact is recommended at 1440p: item name + full set name/count. Detailed also shows equipment type. Labels expand outward away from the 3D character. Icons Only removes external text while keeping condition, charge, level and quality borders on the native slot buttons.",
            choices = { "Compact (Recommended)", "Detailed", "Icons Only" },
            choicesValues = { "compact", "detailed", "icons" },
            getFunc = function() return EPC.saved.characterGearDensity029207 or "compact" end,
            setFunc = function(v) EPC.saved.characterGearDensity029207 = v if EPC.CharacterGearScreen then EPC.CharacterGearScreen:RequestRefresh(10) end end,
            default = EPC.defaults.characterGearDensity029207,
        },
        {
            type = "dropdown", name = "Character stats panel",
            tooltip = "Auto hides ESO's full attribute list on standard-width screens where it would overlap the character, gear labels, or inventory. It remains available on wide/ultrawide layouts. Show and Hide override Auto.",
            choices = { "Auto (Recommended)", "Always Show", "Always Hide" },
            choicesValues = { "auto", "show", "hide" },
            getFunc = function() return EPC.saved.characterGearStatsMode029207 or "auto" end,
            setFunc = function(v) EPC.saved.characterGearStatsMode029207 = v if EPC.CharacterGearScreen then EPC.CharacterGearScreen:RequestRefresh(10) end end,
            default = EPC.defaults.characterGearStatsMode029207,
        },
        {
            type = "slider", name = "Equipment slot size", min = 48, max = 108, step = 2,
            tooltip = "Changes the native equipment buttons without replacing their native click behavior.",
            getFunc = function() return tonumber(EPC.saved.characterGearSlotSize029206) or 96 end,
            setFunc = function(v) EPC.saved.characterGearSlotSize029206 = tonumber(v) or 96 if EPC.CharacterGearScreen then EPC.CharacterGearScreen:RequestRefresh(10) end end,
            default = EPC.defaults.characterGearSlotSize029206,
        },
        {
            type = "slider", name = "Gear detail font size", min = 11, max = 22, step = 1,
            getFunc = function() return tonumber(EPC.saved.characterGearFontSize029206) or 20 end,
            setFunc = function(v) EPC.saved.characterGearFontSize029206 = tonumber(v) or 20 if EPC.CharacterGearScreen then EPC.CharacterGearScreen:RequestRefresh(10) end end,
            default = EPC.defaults.characterGearFontSize029206,
        },
        {
            type = "checkbox", name = "Show gear text",
            getFunc = function() return EPC.saved.characterGearShowDetails029206 ~= false end,
            setFunc = function(v) EPC.saved.characterGearShowDetails029206 = v == true if EPC.CharacterGearScreen then EPC.CharacterGearScreen:RequestRefresh(10) end end,
            default = EPC.defaults.characterGearShowDetails029206,
        },
        {
            type = "checkbox", name = "Show set piece counts",
            getFunc = function() return EPC.saved.characterGearShowSetCount029206 ~= false end,
            setFunc = function(v) EPC.saved.characterGearShowSetCount029206 = v == true if EPC.CharacterGearScreen then EPC.CharacterGearScreen:RequestRefresh(10) end end,
            default = EPC.defaults.characterGearShowSetCount029206,
        },
        {
            type = "checkbox", name = "Show quality-colored slot borders",
            getFunc = function() return EPC.saved.characterGearShowQuality029206 ~= false end,
            setFunc = function(v) EPC.saved.characterGearShowQuality029206 = v == true if EPC.CharacterGearScreen then EPC.CharacterGearScreen:RequestRefresh(10) end end,
            default = EPC.defaults.characterGearShowQuality029206,
        },
        {
            type = "checkbox", name = "Show armor condition / weapon charge",
            getFunc = function() return EPC.saved.characterGearShowCondition029206 ~= false end,
            setFunc = function(v) EPC.saved.characterGearShowCondition029206 = v == true if EPC.CharacterGearScreen then EPC.CharacterGearScreen:RequestRefresh(10) end end,
            default = EPC.defaults.characterGearShowCondition029206,
        },
        {
            type = "checkbox", name = "Show item level / Champion requirement",
            getFunc = function() return EPC.saved.characterGearShowLevel029206 ~= false end,
            setFunc = function(v) EPC.saved.characterGearShowLevel029206 = v == true if EPC.CharacterGearScreen then EPC.CharacterGearScreen:RequestRefresh(10) end end,
            default = EPC.defaults.characterGearShowLevel029206,
        },
        {
            type = "slider", name = "Repair warning threshold", min = 1, max = 100, step = 1,
            tooltip = "Condition at or below this value is treated as a warning and is emphasized on the affected equipment slot/condition text.",
            getFunc = function() return tonumber(EPC.saved.characterGearRepairThreshold029206) or 25 end,
            setFunc = function(v) EPC.saved.characterGearRepairThreshold029206 = tonumber(v) or 25 if EPC.CharacterGearScreen then EPC.CharacterGearScreen:RequestRefresh(10) end end,
            default = EPC.defaults.characterGearRepairThreshold029206,
        },
        {
            type = "slider", name = "Weapon charge warning threshold", min = 1, max = 100, step = 1,
            getFunc = function() return tonumber(EPC.saved.characterGearChargeThreshold029206) or 25 end,
            setFunc = function(v) EPC.saved.characterGearChargeThreshold029206 = tonumber(v) or 25 if EPC.CharacterGearScreen then EPC.CharacterGearScreen:RequestRefresh(10) end end,
            default = EPC.defaults.characterGearChargeThreshold029206,
        },
        {
            type = "slider", name = "Item level warning gap", min = 1, max = 10, step = 1,
            tooltip = "Highlights equipment whose required level trails the character by this many levels.",
            getFunc = function() return tonumber(EPC.saved.characterGearLevelWarning029206) or 5 end,
            setFunc = function(v) EPC.saved.characterGearLevelWarning029206 = tonumber(v) or 5 if EPC.CharacterGearScreen then EPC.CharacterGearScreen:RequestRefresh(10) end end,
            default = EPC.defaults.characterGearLevelWarning029206,
        },
        {
            type = "slider", name = "Main character size", min = 65, max = 180, step = 5,
            tooltip = "Controls how large your real 3D player appears in the center. The old orange paper-doll silhouette is no longer used.",
            getFunc = function() return math.floor((tonumber(EPC.saved.characterGearFigureScale029206) or 1.28) * 100 + 0.5) end,
            setFunc = function(v) EPC.saved.characterGearFigureScale029206 = (tonumber(v) or 128) / 100 if EPC.CharacterGearScreen then EPC.CharacterGearScreen:RequestRefresh(10) end end,
            default = math.floor((EPC.defaults.characterGearFigureScale029206 or 1.2) * 100),
        },
        {
            type = "slider", name = "Character camera distance", min = 100, max = 295, step = 5,
            tooltip = "Advanced framing control for the real 3D character. Main Character Size is applied on top of this base distance. 300 is intentionally avoided because ESO treats it as a boundary value.",
            getFunc = function() return math.floor((tonumber(EPC.saved.characterGearCameraDistance029206) or 2.0) * 100 + 0.5) end,
            setFunc = function(v) EPC.saved.characterGearCameraDistance029206 = (tonumber(v) or 200) / 100 if EPC.CharacterGearScreen then EPC.CharacterGearScreen:ApplyCamera() end end,
            default = math.floor((EPC.defaults.characterGearCameraDistance029206 or 2.0) * 100),
        },
        {
            type = "button", name = "Reset Character Gear Screen", buttonText = "Reset Gear Screen",
            func = function() if EPC.CharacterGearScreen then EPC.CharacterGearScreen:ResetDefaults() end end,
            width = "half",
        },
        {
            type = "header", name = "Automatic Equipment Maintenance",
        },
        {
            type = "description",
            title = "Recharge and repair on combat transitions",
            text = "The suite can check equipped weapons and armor when combat starts and ends. It uses filled soul gems and repair kits only when an equipped item falls below your configured threshold.",
        },
        {
            type = "checkbox", name = "Enable automatic maintenance",
            getFunc = function() return EPC.saved.autoMaintenance ~= false end,
            setFunc = function(v) EPC.saved.autoMaintenance = v == true end,
            default = EPC.defaults.autoMaintenance,
        },
        {
            type = "checkbox", name = "Auto recharge equipped weapons",
            getFunc = function() return EPC.saved.autoRecharge ~= false end,
            setFunc = function(v) EPC.saved.autoRecharge = v == true end,
            default = EPC.defaults.autoRecharge,
        },
        {
            type = "slider", name = "Recharge below (%)", min = 10, max = 100, step = 5,
            getFunc = function() return tonumber(EPC.saved.autoRechargeThreshold) or 90 end,
            setFunc = function(v) EPC.saved.autoRechargeThreshold = tonumber(v) or 90 end,
            default = EPC.defaults.autoRechargeThreshold,
        },
        {
            type = "checkbox", name = "Auto repair equipped armor",
            getFunc = function() return EPC.saved.autoRepair ~= false end,
            setFunc = function(v) EPC.saved.autoRepair = v == true end,
            default = EPC.defaults.autoRepair,
        },
        {
            type = "slider", name = "Repair below (%)", min = 10, max = 100, step = 5,
            getFunc = function() return tonumber(EPC.saved.autoRepairThreshold) or 90 end,
            setFunc = function(v) EPC.saved.autoRepairThreshold = tonumber(v) or 90 end,
            default = EPC.defaults.autoRepairThreshold,
        },
        {
            type = "checkbox", name = "Check when entering combat",
            getFunc = function() return EPC.saved.autoMaintenanceOnCombatStart ~= false end,
            setFunc = function(v) EPC.saved.autoMaintenanceOnCombatStart = v == true end,
            default = EPC.defaults.autoMaintenanceOnCombatStart,
            width = "half",
        },
        {
            type = "checkbox", name = "Check when leaving combat",
            getFunc = function() return EPC.saved.autoMaintenanceOnCombatEnd ~= false end,
            setFunc = function(v) EPC.saved.autoMaintenanceOnCombatEnd = v == true end,
            default = EPC.defaults.autoMaintenanceOnCombatEnd,
            width = "half",
        },
        {
            type = "checkbox", name = "Never use Crown repair kits",
            tooltip = "Protects premium Crown repair kits from automatic consumption. Ordinary repair kits are used instead.",
            getFunc = function() return EPC.saved.maintenanceNeverUseCrown ~= false end,
            setFunc = function(v) EPC.saved.maintenanceNeverUseCrown = v == true end,
            default = EPC.defaults.maintenanceNeverUseCrown,
        },
        {
            type = "checkbox", name = "Show maintenance chat messages",
            getFunc = function() return EPC.saved.maintenanceMessages ~= false end,
            setFunc = function(v) EPC.saved.maintenanceMessages = v == true end,
            default = EPC.defaults.maintenanceMessages,
        },
        {
            type = "button", name = "Run maintenance now",
            func = function() if EPC.Maintenance then EPC.Maintenance:Run("settings", true) end end,
        },
        {
            type = "header", name = "Repair / Recharge Estimate Overlay",
        },
        {
            type = "description",
            title = "See the cost before spending gold",
            text = "Lists equipped armor/shields with current condition and per-piece vendor repair cost, plus equipped weapon charge. Weapons recharge with soul gems rather than vendor repair gold. The overlay never repairs anything by itself.",
        },
        {
            type = "checkbox", name = "Show repair / recharge estimate",
            getFunc = function() return EPC.saved.showRepairCostOverlay ~= false end,
            setFunc = function(v) EPC.saved.showRepairCostOverlay = v == true if EPC.RepairCostOverlay then EPC.RepairCostOverlay:Refresh() end end,
            default = EPC.defaults.showRepairCostOverlay,
        },
        {
            type = "dropdown", name = "Repair estimate visibility",
            tooltip = "Inventory Only keeps the full Repair / Recharge Estimate card exactly as before. Always uses the compact Repair: <gold> gameplay HUD; it uses the same ESO HUD-fade ownership as the Suite FPS overlay, so it disappears and returns with the other gameplay HUD overlays without a separate Suite idle timer.",
            choices = { "Inventory Only", "Always" }, choicesValues = { "INVENTORY", "ALWAYS" },
            getFunc = function()
                local mode = EPC.saved.repairCostVisibility
                return (mode == "ALWAYS") and "ALWAYS" or "INVENTORY"
            end,
            setFunc = function(v) EPC.saved.repairCostVisibility = v if EPC.RepairCostOverlay then EPC.RepairCostOverlay:Refresh() end end,
            default = EPC.defaults.repairCostVisibility,
        },
        {
            type = "slider", name = "Repair estimate scale", tooltip = "Scales the Repair / Recharge overlay. Move it in ESO Edit HUD; sizing remains controlled here in Suite Settings.", min = 65, max = 180, step = 5,
            getFunc = function() return math.floor((tonumber(EPC.saved.repairCostScale) or 1.0) * 100) end,
            setFunc = function(v) EPC.saved.repairCostScale = v / 100 if EPC.RepairCostOverlay then EPC.RepairCostOverlay:Refresh() end end,
            default = math.floor((EPC.defaults.repairCostScale or 1.0) * 100),
        },
        {
            type = "button", name = "Reset repair overlay positions", buttonText = "Reset Repair Overlays",
            func = function() if EPC.RepairCostOverlay then EPC.RepairCostOverlay:ResetPosition() EPC.RepairCostOverlay:Refresh() end end,
        },
        {
            type = "header", name = "Suite FPS / Latency Overlay",
        },
        {
            type = "description",
            title = "Suite replacement for ESO's performance meter",
            text = "Shows FPS and network latency in a small movable Suite HUD. It is attached directly to ESO's HUD-fade fragment, so it fades with the normal gameplay HUD and does not use a separate Suite idle timer.",
        },
        {
            type = "checkbox", name = "Show Suite FPS / Latency",
            getFunc = function() return EPC.saved.showPerformanceOverlay ~= false end,
            setFunc = function(v) EPC.saved.showPerformanceOverlay = v == true if EPC.PerformanceOverlay then EPC.PerformanceOverlay:Refresh(true) end end,
            default = EPC.defaults.showPerformanceOverlay,
        },
        {
            type = "checkbox", name = "Hide ESO built-in FPS / latency panel",
            tooltip = "When the Suite meter is enabled, suppress ESO's stock performance panel so the two displays do not overlap.",
            getFunc = function() return EPC.saved.suppressNativePerformanceMeters ~= false end,
            setFunc = function(v) EPC.saved.suppressNativePerformanceMeters = v == true if EPC.PerformanceOverlay then EPC.PerformanceOverlay:Refresh(true) end end,
            default = EPC.defaults.suppressNativePerformanceMeters,
        },
        {
            type = "slider", name = "FPS / latency scale", min = 65, max = 180, step = 5,
            getFunc = function() return math.floor((tonumber(EPC.saved.performanceOverlayScale) or 1.0) * 100) end,
            setFunc = function(v) EPC.saved.performanceOverlayScale = v / 100 if EPC.PerformanceOverlay then EPC.PerformanceOverlay:Refresh(true) end end,
            default = math.floor((EPC.defaults.performanceOverlayScale or 1.0) * 100),
        },
        {
            type = "button", name = "Reset FPS / latency position", buttonText = "Reset Performance Overlay",
            func = function() if EPC.PerformanceOverlay then EPC.PerformanceOverlay:ResetPosition() EPC.PerformanceOverlay:Refresh(true) end end,
        },
        {
            type = "header", name = "Screen Edge Info Bar",
        },
        {
            type = "description",
            title = "Optional compact screen-edge information strip",
            text = "Shows time, Stable training, bag space, ESO currencies, FPS, and Ping in a compact screen-edge strip. Dock it to a screen edge here; ESO Edit HUD is used for movable Suite HUD elements.",
            width = "full",
        },
        {
            type = "checkbox", name = "Show Screen Edge Info Bar",
            getFunc = function() return EPC.saved.showEdgeInfoBar029763 == true end,
            setFunc = function(v) EPC.saved.showEdgeInfoBar029763 = v == true if EPC.EdgeInfoBar then EPC.EdgeInfoBar:Refresh() end end,
            default = EPC.defaults.showEdgeInfoBar029763,
        },
        {
            type = "dropdown", name = "Info bar screen edge",
            choices = { "Top", "Bottom" },
            choicesValues = { "TOP", "BOTTOM" },
            getFunc = function()
                local v = EPC.saved.edgeInfoBarEdge029763 or "TOP"
                if v ~= "BOTTOM" then v = "TOP" end
                return v
            end,
            setFunc = function(v)
                EPC.saved.edgeInfoBarEdge029763 = v == "BOTTOM" and "BOTTOM" or "TOP"
                if EPC.EdgeInfoBar then EPC.EdgeInfoBar:Refresh() end
            end,
            default = EPC.defaults.edgeInfoBarEdge029763 or "TOP",
        },
        {
            type = "slider", name = "Info bar scale", min = 65, max = 160, step = 5,
            tooltip = "Changes the size of the bar and text while keeping left, center, and right information anchored across the full screen width.",
            getFunc = function() return math.floor((tonumber(EPC.saved.edgeInfoBarScale029763) or 1.0) * 100) end,
            setFunc = function(v) EPC.saved.edgeInfoBarScale029763 = (tonumber(v) or 100) / 100 if EPC.EdgeInfoBar then EPC.EdgeInfoBar:Refresh() end end,
            default = math.floor((EPC.defaults.edgeInfoBarScale029763 or 1.0) * 100),
        },
        {
            type = "slider", name = "Info bar opacity", min = 20, max = 100, step = 5,
            getFunc = function() return math.floor((tonumber(EPC.saved.edgeInfoBarAlpha029763) or 0.94) * 100) end,
            setFunc = function(v) EPC.saved.edgeInfoBarAlpha029763 = (tonumber(v) or 94) / 100 if EPC.EdgeInfoBar then EPC.EdgeInfoBar:Refresh() end end,
            default = math.floor((EPC.defaults.edgeInfoBarAlpha029763 or 0.94) * 100),
        },
        {
            type = "checkbox", name = "Show clock on info bar",
            getFunc = function() return EPC.saved.edgeInfoBarClock029763 ~= false end,
            setFunc = function(v) EPC.saved.edgeInfoBarClock029763 = v == true if EPC.EdgeInfoBar then EPC.EdgeInfoBar:Refresh() end end,
            default = EPC.defaults.edgeInfoBarClock029763,
        },
        {
            type = "dropdown", name = "Info bar clock format",
            tooltip = "Regular uses 12-hour time with AM/PM. Military uses 24-hour time.",
            choices = { "Regular (12-hour)", "Military (24-hour)" },
            choicesValues = { "12H", "24H" },
            getFunc = function() return EPC.saved.edgeInfoBarClockFormat029770 or "12H" end,
            setFunc = function(v) EPC.saved.edgeInfoBarClockFormat029770 = v or "12H" if EPC.EdgeInfoBar then EPC.EdgeInfoBar:Refresh() end end,
            default = EPC.defaults.edgeInfoBarClockFormat029770 or "12H",
            width = "full",
        },
        {
            type = "checkbox", name = "Show Stable timer on info bar",
            tooltip = "Shows the riding-training timer, READY, or MAX directly on the Screen Edge Info Bar.",
            getFunc = function() return EPC.saved.edgeInfoBarStable029770 ~= false end,
            setFunc = function(v) EPC.saved.edgeInfoBarStable029770 = v == true if EPC.EdgeInfoBar then EPC.EdgeInfoBar:Refresh() end end,
            default = EPC.defaults.edgeInfoBarStable029770 ~= false,
        },
        {
            type = "checkbox", name = "Show FPS and Ping on info bar",
            tooltip = "Adds FPS and network latency to the end of the Screen Edge Info Bar.",
            getFunc = function() return EPC.saved.edgeInfoBarPerformance029770 ~= false end,
            setFunc = function(v) EPC.saved.edgeInfoBarPerformance029770 = v == true if EPC.EdgeInfoBar then EPC.EdgeInfoBar:Refresh() end end,
            default = EPC.defaults.edgeInfoBarPerformance029770 ~= false,
        },
        {
            type = "checkbox", name = "Show backpack space on info bar",
            getFunc = function() return EPC.saved.edgeInfoBarBag029763 ~= false end,
            setFunc = function(v) EPC.saved.edgeInfoBarBag029763 = v == true if EPC.EdgeInfoBar then EPC.EdgeInfoBar:Refresh() end end,
            default = EPC.defaults.edgeInfoBarBag029763,
        },
        {
            type = "checkbox", name = "Show zero-balance currencies",
            tooltip = "Off by default so the bar only shows currencies you currently have.",
            getFunc = function() return EPC.saved.edgeInfoBarShowZero029763 == true end,
            setFunc = function(v) EPC.saved.edgeInfoBarShowZero029763 = v == true if EPC.EdgeInfoBar then EPC.EdgeInfoBar:Refresh() end end,
            default = EPC.defaults.edgeInfoBarShowZero029763,
        },
        {
            type = "header", name = "Pre-Encounter Reminders",
        },
        {
            type = "description",
            title = "Small text-only readiness reminders",
            text = "Shows no background box. In dungeons, trials, arenas, delves and public dungeons the reminders stay ready while you are out of combat. In overland and quest areas they appear when you aim at an attackable target before the pull.",
        },
        {
            type = "checkbox", name = "Show pre-encounter reminders",
            getFunc = function() return EPC.saved.showEncounterReminders ~= false end,
            setFunc = function(v) EPC.saved.showEncounterReminders = v == true if EPC.EncounterReminders then EPC.EncounterReminders:Refresh() end end,
            default = EPC.defaults.showEncounterReminders,
        },
        {
            type = "checkbox", name = "Armor repair reminder",
            tooltip = "Shows ARMOR NEEDS REPAIR before an encounter when at least one equipped armor piece is below 100% condition.",
            getFunc = function() return EPC.saved.showEncounterRepairReminder ~= false end,
            setFunc = function(v) EPC.saved.showEncounterRepairReminder = v == true if EPC.EncounterReminders then EPC.EncounterReminders:Refresh() end end,
            default = EPC.defaults.showEncounterRepairReminder,
        },
        {
            type = "checkbox", name = "Potion reminder",
            tooltip = "Shows DRINK POTION BEFORE NEXT ENCOUNTER before each new pull, then hides when combat starts.",
            getFunc = function() return EPC.saved.showEncounterPotionReminder ~= false end,
            setFunc = function(v) EPC.saved.showEncounterPotionReminder = v == true if EPC.EncounterReminders then EPC.EncounterReminders:Refresh() end end,
            default = EPC.defaults.showEncounterPotionReminder,
        },
        {
            type = "slider", name = "Armor reminder scale", min = 65, max = 180, step = 5,
            getFunc = function() return math.floor((tonumber(EPC.saved.encounterRepairScale) or 1.0) * 100) end,
            setFunc = function(v) EPC.saved.encounterRepairScale = v / 100 if EPC.EncounterReminders then EPC.EncounterReminders:Refresh() end end,
            default = math.floor((EPC.defaults.encounterRepairScale or 1.0) * 100),
            width = "half",
        },
        {
            type = "slider", name = "Potion reminder scale", min = 65, max = 180, step = 5,
            getFunc = function() return math.floor((tonumber(EPC.saved.encounterPotionScale) or 1.0) * 100) end,
            setFunc = function(v) EPC.saved.encounterPotionScale = v / 100 if EPC.EncounterReminders then EPC.EncounterReminders:Refresh() end end,
            default = math.floor((EPC.defaults.encounterPotionScale or 1.0) * 100),
            width = "half",
        },
        {
            type = "dropdown", name = "Armor reminder position",
            tooltip = "Choose a screen corner, or Custom to place it anywhere with ESO Edit HUD.",
            choices = { "Custom", "Top Left", "Top Right", "Bottom Left", "Bottom Right" },
            choicesValues = { "CUSTOM", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" },
            getFunc = function() return EPC.saved.encounterRepairPreset or "CUSTOM" end,
            setFunc = function(v) if EPC.EncounterReminders then EPC.EncounterReminders:SetRepairPreset(v) EPC.EncounterReminders:Refresh() else EPC.saved.encounterRepairPreset = v end end,
            default = EPC.defaults.encounterRepairPreset,
            width = "half",
        },
        {
            type = "dropdown", name = "Potion reminder position",
            tooltip = "Choose a screen corner, or Custom to place it anywhere with ESO Edit HUD.",
            choices = { "Custom", "Top Left", "Top Right", "Bottom Left", "Bottom Right" },
            choicesValues = { "CUSTOM", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" },
            getFunc = function() return EPC.saved.encounterPotionPreset or "CUSTOM" end,
            setFunc = function(v) if EPC.EncounterReminders then EPC.EncounterReminders:SetPotionPreset(v) EPC.EncounterReminders:Refresh() else EPC.saved.encounterPotionPreset = v end end,
            default = EPC.defaults.encounterPotionPreset,
            width = "half",
        },
        {
            type = "button", name = "Reset armor reminder position", buttonText = "Reset Armor",
            func = function() if EPC.EncounterReminders then EPC.EncounterReminders:ResetRepairPosition() EPC.EncounterReminders:Refresh() end end,
            width = "half",
        },
        {
            type = "button", name = "Reset potion reminder position", buttonText = "Reset Potion",
            func = function() if EPC.EncounterReminders then EPC.EncounterReminders:ResetPotionPosition() EPC.EncounterReminders:Refresh() end end,
            width = "half",
        },
        {
            type = "header", name = "Lore Book Locations",
        },
        {
            type = "checkbox", name = "Enable Lore Books & Scrolls",
            tooltip = "Master switch for all Lore Book, Eidetic Memory, and scroll location markers. Turn this off when you are not hunting books to hide the feature everywhere.",
            getFunc = function() return EASLoreLibrary and EASLoreLibrary.settings and EASLoreLibrary.settings:Get("loreBooksEnabled") ~= false end,
            setFunc = function(v) if EASLoreLibrary and EASLoreLibrary.settings then EASLoreLibrary.settings:Set("loreBooksEnabled", v == true) end end,
            default = true,
        },
        {
            type = "description",
            title = "Undiscovered books on map, compass and in the world",
            text = "Use the master switch to hide all Lore Book and scroll hunting markers when you are not looking for them. Lore Books are enabled by default and Eidetic Memory books start disabled. Some locations are quest-gated: the marker can show where the book will be, but ESO may not spawn the book until its related quest has been completed. Right-click a book in Journal > Lore Library to use Show on Map.",
        },
        {
            type = "checkbox", name = "Show undiscovered Lore Books",
            getFunc = function() return EASLoreLibrary and EASLoreLibrary.settings and EASLoreLibrary.settings:IsPinTypeEnabled(EASLoreLibrary.LOREBOOK) or false end,
            setFunc = function(v) if EASLoreLibrary and EASLoreLibrary.settings then EASLoreLibrary.settings:SetPinTypeEnabled(EASLoreLibrary.LOREBOOK, v == true) end end,
            default = true,
        },
        {
            type = "checkbox", name = "Show Eidetic Memory books",
            tooltip = "Disabled by default. You can also toggle this from the World Map filter panel.",
            getFunc = function() return EASLoreLibrary and EASLoreLibrary.settings and EASLoreLibrary.settings:IsPinTypeEnabled(EASLoreLibrary.EIDETICBOOK) or false end,
            setFunc = function(v) if EASLoreLibrary and EASLoreLibrary.settings then EASLoreLibrary.settings:SetPinTypeEnabled(EASLoreLibrary.EIDETICBOOK, v == true) end end,
            default = false,
        },
        {
            type = "checkbox", name = "Book markers on compass",
            getFunc = function() return EASLoreLibrary and EASLoreLibrary.settings and EASLoreLibrary.settings:Get("compassPinsEnabled") ~= false end,
            setFunc = function(v) if EASLoreLibrary and EASLoreLibrary.settings then EASLoreLibrary.settings:Set("compassPinsEnabled", v == true) end end,
            default = true,
            width = "half",
        },
        {
            type = "checkbox", name = "Book markers in 3D world",
            getFunc = function() return EASLoreLibrary and EASLoreLibrary.settings and EASLoreLibrary.settings:Get("worldPinsEnabled") ~= false end,
            setFunc = function(v) if EASLoreLibrary and EASLoreLibrary.settings then EASLoreLibrary.settings:Set("worldPinsEnabled", v == true) end end,
            default = true,
            width = "half",
        },
        {
            type = "checkbox", name = "Hide quest-dependent books in 3D",
            tooltip = "Recommended. Suppresses floating 3D icons for known quest-phased books/documents whose physical object may not exist at that location yet. Map and compass guidance remain available.",
            getFunc = function() return EASLoreLibrary and EASLoreLibrary.settings and EASLoreLibrary.settings:Get("hideQuestDependentWorldPins") ~= false end,
            setFunc = function(v) if EASLoreLibrary and EASLoreLibrary.settings then EASLoreLibrary.settings:Set("hideQuestDependentWorldPins", v == true) end end,
            default = true,
        },
        {
            type = "description",
            text = "Known phased examples include Tava's Bounty Ledger and other quest-linked Eidetic documents. The location stays visible on the map/compass; only the potentially misleading floating 3D icon is hidden.",
        },
        {
            type = "slider", name = "Compass book distance", min = 100, max = 2000, step = 100,
            getFunc = function() return EASLoreLibrary and EASLoreLibrary.settings and (tonumber(EASLoreLibrary.settings:Get("compassPinsDistance")) or 300) or 300 end,
            setFunc = function(v) if EASLoreLibrary and EASLoreLibrary.settings then EASLoreLibrary.settings:Set("compassPinsDistance", tonumber(v) or 300) end end,
            default = 300,
            width = "half",
        },
        {
            type = "slider", name = "3D book distance", min = 100, max = 1000, step = 50,
            getFunc = function() return EASLoreLibrary and EASLoreLibrary.settings and (tonumber(EASLoreLibrary.settings:Get("worldPinsDistance")) or 250) or 250 end,
            setFunc = function(v) if EASLoreLibrary and EASLoreLibrary.settings then EASLoreLibrary.settings:Set("worldPinsDistance", tonumber(v) or 250) end end,
            default = 250,
            width = "half",
        },
        {
            type = "header", name = "Dungeon / Trial Chest Finder",
        },
        {
            type = "description",
            title = "Chest-centered 3D glow",
            text = "Works only inside supported instanced PvE content such as Group Dungeons, Trials, and Arenas. ESO does not expose the chest model's exact world coordinates, so the Suite estimates the center when your reticle identifies a Chest or Heavy Sack at interaction range. Confirmed objects use one compact glow centered on that learned position until looted. Possible-spawn glows are optional and are automatically suppressed whenever a confirmed chest/Heavy Sack is being shown, preventing multiple glows from surrounding the real chest.",
        },
        {
            type = "checkbox", name = "Enable Dungeon / Trial Chest Finder",
            tooltip = "Enables learned 3D chest/Heavy Sack spawn glows only in supported instanced PvE content.",
            getFunc = function() return EPC.saved.dungeonChestFinderEnabled ~= false end,
            setFunc = function(v) EPC.saved.dungeonChestFinderEnabled = v == true if EPC.DungeonChestFinder then EPC.DungeonChestFinder:RefreshSettings() end end,
            default = EPC.defaults.dungeonChestFinderEnabled,
            width = "full",
        },
        {
            type = "checkbox", name = "Show possible chest spawn locations",
            tooltip = "Shows remembered possible spawn points only when no confirmed chest/Heavy Sack is currently being rendered. Leave this off if you only want the actual detected chest location to glow.",
            getFunc = function() return EPC.saved.dungeonChestShowPossible ~= false end,
            setFunc = function(v) EPC.saved.dungeonChestShowPossible = v == true if EPC.DungeonChestFinder then EPC.DungeonChestFinder:RefreshSettings() end end,
            default = EPC.defaults.dungeonChestShowPossible,
            width = "half",
        },
        {
            type = "checkbox", name = "Show Heavy Sack glows",
            getFunc = function() return EPC.saved.dungeonChestShowHeavySacks ~= false end,
            setFunc = function(v) EPC.saved.dungeonChestShowHeavySacks = v == true if EPC.DungeonChestFinder then EPC.DungeonChestFinder:RefreshSettings() end end,
            default = EPC.defaults.dungeonChestShowHeavySacks,
            width = "half",
        },
        {
            type = "checkbox", name = "Learn new chest locations",
            tooltip = "Saves a chest/Heavy Sack spawn point when ESO identifies it under your reticle at interaction range. Existing learned locations remain visible if this is turned off.",
            getFunc = function() return EPC.saved.dungeonChestLearnLocations ~= false end,
            setFunc = function(v) EPC.saved.dungeonChestLearnLocations = v == true end,
            default = EPC.defaults.dungeonChestLearnLocations,
            width = "half",
        },
        {
            type = "checkbox", name = "Chest glows through obstacles",
            tooltip = "When enabled, 3D chest glows ignore the depth buffer so they can remain visible through dungeon geometry where ESO permits it.",
            getFunc = function() return EPC.saved.dungeonChestThroughWalls ~= false end,
            setFunc = function(v) EPC.saved.dungeonChestThroughWalls = v == true if EPC.DungeonChestFinder then EPC.DungeonChestFinder:RefreshSettings() end end,
            default = EPC.defaults.dungeonChestThroughWalls,
            width = "half",
        },
        {
            type = "slider", name = "Chest glow distance", min = 25, max = 250, step = 5,
            tooltip = "Maximum distance in meters for learned dungeon/trial chest glows.",
            getFunc = function() return tonumber(EPC.saved.dungeonChestDistance) or 120 end,
            setFunc = function(v) EPC.saved.dungeonChestDistance = tonumber(v) or 120 if EPC.DungeonChestFinder then EPC.DungeonChestFinder:RefreshSettings() end end,
            default = EPC.defaults.dungeonChestDistance,
            width = "half",
        },
        {
            type = "slider", name = "Chest glow size", min = 50, max = 200, step = 5,
            getFunc = function() return math.floor((tonumber(EPC.saved.dungeonChestMarkerScale) or 1.0) * 100 + 0.5) end,
            setFunc = function(v) EPC.saved.dungeonChestMarkerScale = (tonumber(v) or 100) / 100 if EPC.DungeonChestFinder then EPC.DungeonChestFinder:RefreshSettings() end end,
            default = math.floor((EPC.defaults.dungeonChestMarkerScale or 1.0) * 100),
            width = "half",
        },
        {
            type = "slider", name = "Chest glow intensity", min = 5, max = 100, step = 5,
            tooltip = "Controls the brightness of chest/Heavy Sack glows. Confirmed spawns stay brighter and pulse until looted.",
            getFunc = function() return math.floor((tonumber(EPC.saved.dungeonChestGlowOpacity) or 0.60) * 100 + 0.5) end,
            setFunc = function(v) EPC.saved.dungeonChestGlowOpacity = (tonumber(v) or 60) / 100 if EPC.DungeonChestFinder then EPC.DungeonChestFinder:RefreshSettings() end end,
            default = math.floor((EPC.defaults.dungeonChestGlowOpacity or 0.60) * 100),
            width = "half",
        },
        {
            type = "colorpicker", name = "Chest glow color",
            getFunc = function() local c = EPC.saved.dungeonChestColor or EPC.defaults.dungeonChestColor return c.r or 1.0, c.g or 0.74, c.b or 0.14, 1 end,
            setFunc = function(r, g, b, a) EPC.saved.dungeonChestColor = { r = r, g = g, b = b } if EPC.DungeonChestFinder then EPC.DungeonChestFinder:RefreshSettings() end end,
            default = EPC.defaults.dungeonChestColor,
            width = "half",
        },
        {
            type = "colorpicker", name = "Heavy Sack glow color",
            getFunc = function() local c = EPC.saved.dungeonChestSackColor or EPC.defaults.dungeonChestSackColor return c.r or 0.62, c.g or 0.92, c.b or 0.52, 1 end,
            setFunc = function(r, g, b, a) EPC.saved.dungeonChestSackColor = { r = r, g = g, b = b } if EPC.DungeonChestFinder then EPC.DungeonChestFinder:RefreshSettings() end end,
            default = EPC.defaults.dungeonChestSackColor,
            width = "half",
        },
        {
            type = "button", name = "Clear learned dungeon chest locations", buttonText = "Clear Learned Chests",
            tooltip = "Deletes every dungeon/trial Chest and Heavy Sack spawn learned by this feature. This does not affect Lore Books, minimap locations, or other Suite data.",
            func = function() if EPC.DungeonChestFinder then EPC.DungeonChestFinder:ClearLearnedLocations() EPC:Print("Dungeon / Trial Chest Finder learned locations cleared.") end end,
            disabled = function() return not EPC.DungeonChestFinder end,
            width = "full",
        },
        {
            type = "header", name = "Antiquity Assistant",
        },
        {
            type = "description",
            title = "Dig-site navigation + Augur + Bonus Loot helper",
            text = "World-map and Suite-minimap pins show the active Antiquity search area. In the world, ESO's normal Antiquarian's Eye blue mist remains unchanged; once ESO exposes the real Excavate / Dig Site mound, the Suite learns a true 3D shovel position above that mound, saves the spawn, and reuses it the next time the same dig-site spawn becomes active. During Excavation, the Suite caches the Augur tile, recommends information-rich scan tiles, and only calls a main-loot tile guaranteed after ESO reports Green. After the main Antiquity is unearthed, Bonus Loot Search Mode tracks bonus finds separately and gives a best-effort board-coverage route using only information ESO exposes to addons.",
        },
        {
            type = "checkbox", name = "Enable Antiquity Assistant",
            tooltip = "Master switch for Antiquity shovel pins, excavation direction help, and skill-line recommendations.",
            getFunc = function() return EPC.saved.antiquityAssistantEnabled ~= false end,
            setFunc = function(v) EPC.saved.antiquityAssistantEnabled = v == true if EPC.AntiquityAssistant then EPC.AntiquityAssistant:RefreshSettings() end end,
            default = EPC.defaults.antiquityAssistantEnabled,
            width = "full",
        },
        {
            type = "checkbox", name = "Shovel icons on world map",
            tooltip = "Marks the center of every active Antiquity search area with the Heavy Shovel skill icon.",
            getFunc = function() return EPC.saved.antiquityShowWorldMap ~= false end,
            setFunc = function(v) EPC.saved.antiquityShowWorldMap = v == true if EPC.AntiquityAssistant then EPC.AntiquityAssistant:RefreshSettings() end end,
            default = EPC.defaults.antiquityShowWorldMap,
            width = "half",
        },
        {
            type = "checkbox", name = "Shovel icons on Suite minimap",
            tooltip = "Shows active Antiquity dig-site centers on the Suite minimap, including edge guidance when the site is off-screen.",
            getFunc = function() return EPC.saved.antiquityShowMiniMap ~= false end,
            setFunc = function(v) EPC.saved.antiquityShowMiniMap = v == true if EPC.AntiquityAssistant then EPC.AntiquityAssistant:RefreshSettings() end end,
            default = EPC.defaults.antiquityShowMiniMap,
            width = "half",
        },
        {
            type = "checkbox", name = "Exact dig-spot shovel in the world",
            tooltip = "Shows a true 3D Heavy Shovel marker above the learned excavation mound. The Suite learns the mound when ESO exposes the actual Excavate / Dig Site interaction target and can reuse that saved spawn later. The old approximate search-area-center 3D marker stays disabled.",
            getFunc = function() return EPC.saved.antiquityShow3D ~= false end,
            setFunc = function(v) EPC.saved.antiquityShow3D = v == true if EPC.AntiquityAssistant then EPC.AntiquityAssistant:RefreshSettings() end end,
            default = EPC.defaults.antiquityShow3D,
            width = "half",
        },
        {
            type = "checkbox", name = "Legacy 3D occlusion setting",
            tooltip = "Kept for saved-variable compatibility. Exact mound markers use ESO's interaction target and do not use approximate through-terrain search-area markers.",
            getFunc = function() return EPC.saved.antiquity3DThroughWalls ~= false end,
            setFunc = function(v) EPC.saved.antiquity3DThroughWalls = v == true if EPC.AntiquityAssistant then EPC.AntiquityAssistant:RefreshSettings() end end,
            default = EPC.defaults.antiquity3DThroughWalls,
            width = "half",
        },
        {
            type = "slider", name = "Known spawn 3D range", min = 200, max = 3000, step = 100,
            tooltip = "Maximum distance in meters for known dig-spawn candidate shovels. The confirmed exact mound still follows ESO's actual interaction target.",
            getFunc = function() return math.floor(tonumber(EPC.saved.antiquity3DRange) or 1200) end,
            setFunc = function(v) EPC.saved.antiquity3DRange = math.floor(tonumber(v) or 1200) if EPC.AntiquityAssistant then EPC.AntiquityAssistant:RefreshSettings() end end,
            default = EPC.defaults.antiquity3DRange,
            width = "half",
        },
        {
            type = "slider", name = "3D shovel size", min = 60, max = 200, step = 5,
            getFunc = function() return math.floor((tonumber(EPC.saved.antiquity3DScale) or 1.0) * 100 + 0.5) end,
            setFunc = function(v) EPC.saved.antiquity3DScale = (tonumber(v) or 100) / 100 if EPC.AntiquityAssistant then EPC.AntiquityAssistant:RefreshSettings() end end,
            default = math.floor((EPC.defaults.antiquity3DScale or 1.0) * 100),
            width = "half",
        },
        {
            type = "checkbox", name = "Learn & reuse exact dig-spot spawns",
            tooltip = "When ESO exposes the real Excavate / Dig Site mound under your reticle, save that learned 3D spawn in SavedVariables. The next time the same dig-site spawn becomes active, the Suite restores the shovel automatically. Turning this off stops new learning; already learned spots remain available.",
            getFunc = function() return EPC.saved.antiquityLearnExactDigSpots ~= false end,
            setFunc = function(v) EPC.saved.antiquityLearnExactDigSpots = v == true end,
            default = EPC.defaults.antiquityLearnExactDigSpots,
            width = "half",
        },
        {
            type = "checkbox", name = "Known dig-spawn locator assist",
            tooltip = "Uses the integrated known Antiquity dig-spawn reference library to filter possible mound spawns to ESO's active dig-site search area. Confirmed/learned spawns are gold; unconfirmed known possibilities are smaller cyan shovels until ESO exposes the real mound.",
            getFunc = function() return EPC.saved.antiquityKnownSpawnAssist ~= false end,
            setFunc = function(v) EPC.saved.antiquityKnownSpawnAssist = v == true if EPC.AntiquityAssistant then EPC.AntiquityAssistant:RefreshSettings() end end,
            default = EPC.defaults.antiquityKnownSpawnAssist,
            width = "half",
        },
        {
            type = "button", name = "Clear learned exact dig spots", buttonText = "Clear Learned Dig Spots",
            tooltip = "Deletes only the saved exact Antiquity mound spawn locations learned by the Suite. Search-area map/minimap pins and other Suite data are not changed.",
            func = function()
                if EPC.AntiquityAssistant and EPC.AntiquityAssistant.ClearLearnedDigSpots then EPC.AntiquityAssistant:ClearLearnedDigSpots() end
            end,
            width = "half",
        },
        {
            type = "header", name = "Antiquity Lead Finder",
        },
        {
            type = "description",
            title = "Find the lead before you scry it",
            text = "Combines ESO's live Antiquity state with integrated Display Leads source/location reference data. Use it to see leads you can still obtain, leads already in your journal, missing codex entries, recovery counts, expiration timers, find zones, and the best-known source description. Scrying and excavation remain handled by ESO and the Suite Antiquity Assistant.",
        },
        {
            type = "checkbox", name = "Enable Antiquity Lead Finder",
            tooltip = "Enables the Suite lead-source browser. The finder does not change ESO lead drops; it only organizes live lead state and source/location information.",
            getFunc = function() return EPC.saved.antiquityLeadFinderEnabled ~= false end,
            setFunc = function(v) EPC.saved.antiquityLeadFinderEnabled = v == true if EPC.AntiquityLeadFinder then EPC.AntiquityLeadFinder:RefreshSettings() end end,
            default = EPC.defaults.antiquityLeadFinderEnabled,
            width = "half",
        },
        {
            type = "button", name = "Open Antiquity Lead Finder", buttonText = "Open Lead Finder",
            tooltip = "Opens the lead browser. You can also assign its own key under Controls > Keybindings > ESO Adventurer Suite.",
            func = function() if EPC.AntiquityLeadFinder then EPC.AntiquityLeadFinder:Show() end end,
            disabled = function() return EPC.saved.antiquityLeadFinderEnabled == false or not EPC.AntiquityLeadFinder end,
            width = "half",
        },
        {
            type = "button", name = "Reset Lead Finder window", buttonText = "Reset Lead Finder",
            tooltip = "Restores the Lead Finder to its default size and centered screen position.",
            func = function() if EPC.AntiquityLeadFinder then EPC.AntiquityLeadFinder:ResetPosition() end end,
            disabled = function() return not EPC.AntiquityLeadFinder end,
            width = "half",
        },
        {
            type = "description",
            title = "Lead Finder filters",
            text = "Inside the finder use CAN FIND, HAVE LEAD, MISSING CODEX, NEVER DUG, or ALL. CURRENT ZONE narrows source locations to the zone you are presently in. Click any lead row for the detailed source description and its separate find-zone / scry-zone information.",
        },
        {
            type = "checkbox", name = "Excavation Augur direction overlay",
            tooltip = "After each successful Augur use, tap Green, Yellow, Orange, or Red. The Suite caches the clicked board cell using multiple ESO UI fallbacks and recommends the strongest next scan. It never labels a non-green prediction as a guaranteed dig. Both Antiquity overlays can be moved in ESO Edit HUD.",
            getFunc = function() return EPC.saved.antiquityExcavationGuide ~= false end,
            setFunc = function(v) EPC.saved.antiquityExcavationGuide = v == true if EPC.AntiquityAssistant then EPC.AntiquityAssistant:RefreshSettings() end end,
            default = EPC.defaults.antiquityExcavationGuide,
            width = "full",
        },
        {
            type = "checkbox", name = "Bonus Loot Search predictions",
            tooltip = "After ESO reports the main Antiquity unearthed, switches the Augur Guide into a bonus-loot coverage route. It tracks bonus loot separately, watches stability/time/dig power, and recommends the next area to work. Bonus coordinates are not exposed by ESO, so these are search-efficiency predictions rather than guaranteed locations.",
            getFunc = function() return EPC.saved.antiquityBonusLootGuide ~= false end,
            setFunc = function(v) EPC.saved.antiquityBonusLootGuide = v == true if EPC.AntiquityAssistant then EPC.AntiquityAssistant:RefreshSettings() end end,
            default = EPC.defaults.antiquityBonusLootGuide,
            width = "full",
        },
        {
            type = "description",
            title = "Movable Excavation overlays",
            text = "Use ESO Edit HUD to drag both the Augur Guide and the 10x10 Augur Tile Selector away from the excavation board. Their positions are saved independently.",
        },
        {
            type = "button", name = "Reset Antiquity overlay positions", buttonText = "Reset Antiquity Overlays",
            tooltip = "Restores the Augur Guide to the top-center and the Augur Tile Selector to the center of the screen.",
            func = function() if EPC.AntiquityAssistant and EPC.AntiquityAssistant.ResetPositions then EPC.AntiquityAssistant:ResetPositions() end end,
        },
        {
            type = "header", name = "Suite Resource Pins",
        },
        {
            type = "description",
            title = "Learned + Suite Community Resource Data",
            text = "Suite Resource Pins combines your personally learned resource locations with 124,625 bundled community resource records and ESO-native uncollected Skyshards. The full current-zone database stays available, but only the nearest capped set receives 3D controls at one time. Personal and community locations share the same temporary depletion system: harvested or already-empty nodes hide for the configured cooldown and then return automatically. As you move, the pool automatically swaps to the next nearby community pins. This avoids the severe FPS loss caused by trying to create thousands of 3D markers simultaneously.",
        },
        {
            type = "checkbox", name = "Enable Suite Resource Pins",
            tooltip = "Turns the Suite resource-node system on or off.",
            getFunc = function() return EPC.saved.resourcePinsEnabled ~= false end,
            setFunc = function(v) EPC.saved.resourcePinsEnabled = v == true if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = EPC.defaults.resourcePinsEnabled,
            width = "half",
        },
        {
            type = "checkbox", name = "Use Suite Community Resource Data",
            tooltip = "Shows pre-collected resource locations bundled with the Suite. Only the current zone is decoded into the fast 3D spatial cache. Your personally learned pins remain separate and take priority over nearby community records.",
            getFunc = function() return EPC.saved.resourcePinsCommunityEnabled ~= false end,
            setFunc = function(v) EPC.saved.resourcePinsCommunityEnabled = v == true if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = EPC.defaults.resourcePinsCommunityEnabled,
            width = "half",
        },
        {
            type = "checkbox", name = "Learn resources when gathered",
            tooltip = "Optionally records a personal copy of resource locations after you gather them. Temporary depleted-node hiding works even when personal learning is turned off.",
            getFunc = function() return EPC.saved.resourcePinsLearn ~= false end,
            setFunc = function(v) EPC.saved.resourcePinsLearn = v == true end,
            default = EPC.defaults.resourcePinsLearn,
            width = "half",
        },
        {
            type = "checkbox", name = "Hide temporarily depleted resource pins",
            tooltip = "Hides a resource pin only after ESO confirms that you personally collected loot from that resource interaction. Simply walking up to a community pin never hides it. The pin returns after the cooldown.",
            getFunc = function() return EPC.saved.resourcePinsHideDepleted ~= false end,
            setFunc = function(v) EPC.saved.resourcePinsHideDepleted = v == true if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = EPC.defaults.resourcePinsHideDepleted,
            width = "half",
        },
        {
            type = "slider", name = "Depleted node cooldown (minutes)", min = 1, max = 30, step = 1,
            tooltip = "How long a resource location stays hidden after you personally collect it before it becomes eligible to appear again.",
            getFunc = function() return math.floor(tonumber(EPC.saved.resourcePinsDepletedCooldownMinutes) or 5) end,
            setFunc = function(v) EPC.saved.resourcePinsDepletedCooldownMinutes = math.floor(tonumber(v) or 5) if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = EPC.defaults.resourcePinsDepletedCooldownMinutes or 5,
            width = "half",
        },
        {
            type = "button", name = "Temporary depleted resource states", buttonText = "Reset Depleted Pins",
            tooltip = "Immediately makes every resource pin hidden by your own recent collections eligible to show again. Community data itself is never deleted.",
            func = function() if EPC.ResourcePins then EPC.ResourcePins:ClearDepletedLocations() EPC:Print("Temporary depleted resource pins reset.") end end,
            disabled = function() return not EPC.ResourcePins or EPC.saved.resourcePinsEnabled == false end,
            width = "half",
        },
        {
            type = "checkbox", name = "Show resource pins in 3D world",
            getFunc = function() return EPC.saved.resourcePinsShow3D ~= false end,
            setFunc = function(v) EPC.saved.resourcePinsShow3D = v == true if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = EPC.defaults.resourcePinsShow3D,
            width = "half",
        },
        {
            type = "checkbox", name = "Resource pins through obstacles",
            tooltip = "Lets Suite learned and community 3D resource markers remain visible through terrain/objects where ESO permits addon 3D controls.",
            getFunc = function() return EPC.saved.resourcePinsThroughWalls ~= false end,
            setFunc = function(v) EPC.saved.resourcePinsThroughWalls = v == true if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = EPC.defaults.resourcePinsThroughWalls,
            width = "half",
        },
        {
            type = "slider", name = "Resource pin distance", min = 15, max = 500, step = 5,
            tooltip = "Maximum distance used to select nearby learned and community nodes for the dynamic 3D pool.",
            getFunc = function() return tonumber(EPC.saved.resourcePinsDistance) or 200 end,
            setFunc = function(v) EPC.saved.resourcePinsDistance = tonumber(v) or 200 if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = EPC.defaults.resourcePinsDistance,
            width = "half",
        },
        {
            type = "slider", name = "Maximum visible 3D resource pins", min = 24, max = 120, step = 8,
            tooltip = "Hard performance cap for active 3D resource controls. The full community database remains available; this only limits how many nearest pins are drawn at the same time.",
            getFunc = function() return math.floor(tonumber(EPC.saved.resourcePinsMaxVisible) or 72) end,
            setFunc = function(v) EPC.saved.resourcePinsMaxVisible = math.floor(tonumber(v) or 72) if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = EPC.defaults.resourcePinsMaxVisible or 72,
            width = "half",
        },
        {
            type = "slider", name = "Resource pin size", min = 45, max = 250, step = 5,
            getFunc = function() return math.floor((tonumber(EPC.saved.resourcePinsScale) or 1.0) * 100 + 0.5) end,
            setFunc = function(v) EPC.saved.resourcePinsScale = (tonumber(v) or 100) / 100 if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = math.floor((EPC.defaults.resourcePinsScale or 1.0) * 100),
            width = "half",
        },
        {
            type = "slider", name = "Resource pin brightness", min = 15, max = 100, step = 5,
            getFunc = function() return math.floor((tonumber(EPC.saved.resourcePinsOpacity) or 0.72) * 100 + 0.5) end,
            setFunc = function(v) EPC.saved.resourcePinsOpacity = (tonumber(v) or 72) / 100 if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = math.floor((EPC.defaults.resourcePinsOpacity or 0.72) * 100),
            width = "half",
        },
        {
            type = "checkbox", name = "Sharper 3D resource icons",
            tooltip = "Uses normalized per-resource sizing and reduced distance growth so all resource symbols stay crisp and visually consistent in the world.",
            getFunc = function() return EPC.saved.resourcePinsSharpIcons ~= false end,
            setFunc = function(v) EPC.saved.resourcePinsSharpIcons = v == true if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = EPC.defaults.resourcePinsSharpIcons,
            width = "half",
        },
        {
            type = "checkbox", name = "Glow icons by value / rarity",
            tooltip = "Adds a colored glow behind resource icons. Rarity changes glow color and intensity only; it no longer makes higher-tier icons physically larger.",
            getFunc = function() return EPC.saved.resourcePinsValueGlow ~= false end,
            setFunc = function(v) EPC.saved.resourcePinsValueGlow = v == true if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = EPC.defaults.resourcePinsValueGlow,
            width = "half",
        },
        {
            type = "slider", name = "Resource icon glow strength", min = 20, max = 100, step = 5,
            tooltip = "Controls how bright the rune-style value/rarity glow appears behind resource icons.",
            getFunc = function() return math.floor(tonumber(EPC.saved.resourcePinsGlowStrength) or 78) end,
            setFunc = function(v) EPC.saved.resourcePinsGlowStrength = math.floor(tonumber(v) or 78) if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = EPC.defaults.resourcePinsGlowStrength or 78,
            width = "half",
        },
        {
            type = "slider", name = "Resource icon size", min = 70, max = 180, step = 5,
            tooltip = "Changes the physical size of non-Glow resource icons in the 3D world without changing the general resource-pin distance settings.",
            getFunc = function() return math.floor(tonumber(EPC.saved.resourcePinsIconSize) or 100) end,
            setFunc = function(v) EPC.saved.resourcePinsIconSize = math.floor(tonumber(v) or 100) if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = EPC.defaults.resourcePinsIconSize or 100,
            width = "half",
        },
        {
            type = "slider", name = "Resource icon color strength", min = 0, max = 100, step = 5,
            tooltip = "Adds category color to the resource symbol itself. 0 keeps icons white, 100 fully tints them by resource type.",
            getFunc = function() return math.floor(tonumber(EPC.saved.resourcePinsIconTintStrength) or 85) end,
            setFunc = function(v) EPC.saved.resourcePinsIconTintStrength = math.floor(tonumber(v) or 85) if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = EPC.defaults.resourcePinsIconTintStrength or 85,
            width = "half",
        },
        {
            type = "header", name = "Resource Pin Icon Replacer",
        },
        {
            type = "description",
            title = "Choose how Suite resource markers look",
            text = "Suite Glow uses the proven glowing marker. Suite Resource Icons uses distinct ESO-native resource symbols on the same proven 3D control: mining/refining, lumber, clothier, alchemy, enchanting, water, fishing, loot and justice markers. All non-Glow icon styles use a tighter rune-style halo glow, can be resized independently, and can tint the icon itself by resource type. The glow can still shift by value/rarity: common materials use a lighter glow, better materials use blue, valuable containers use purple, and top-value treasure pins use gold. Custom Per Type lets you replace each category independently.",
        },
        {
            type = "dropdown", name = "Resource pin icon style",
            choices = { "Suite Glow", "Suite Resource Icons", "Custom Per Type" },
            choicesValues = { "SUITE_GLOW", "CATEGORY", "CUSTOM" },
            getFunc = function() return EPC.saved.resourcePinsIconMode or "SUITE_GLOW" end,
            setFunc = function(v) EPC.saved.resourcePinsIconMode = v if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = EPC.defaults.resourcePinsIconMode,
            width = "full",
        },
        {
            type = "dropdown", name = "Ore / seams icon",
            choices = { "Automatic", "Suite Glow", "Mining", "Wood", "Clothing", "Alchemy", "Enchanting", "Mushroom", "Flower", "Water Plant", "Solvent", "Fishing", "Chest", "Heavy Sack", "Giant Clam", "Trove", "Justice", "Stash" }, choicesValues = { "AUTO", "SUITE_GLOW", "MINING", "WOOD", "CLOTHING", "ALCHEMY", "ENCHANTING", "MUSHROOM", "FLOWER", "WATERPLANT", "SOLVENT", "FISH", "CHEST", "HEAVYSACK", "CLAM", "TROVE", "JUSTICE", "STASH" },
            getFunc = function() return EPC.saved.resourcePinsIconOre or "AUTO" end,
            setFunc = function(v) EPC.saved.resourcePinsIconOre = v if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = EPC.defaults.resourcePinsIconOre,
            width = "half",
        },
        {
            type = "dropdown", name = "Wood icon",
            choices = { "Automatic", "Suite Glow", "Mining", "Wood", "Clothing", "Alchemy", "Enchanting", "Mushroom", "Flower", "Water Plant", "Solvent", "Fishing", "Chest", "Heavy Sack", "Giant Clam", "Trove", "Justice", "Stash" }, choicesValues = { "AUTO", "SUITE_GLOW", "MINING", "WOOD", "CLOTHING", "ALCHEMY", "ENCHANTING", "MUSHROOM", "FLOWER", "WATERPLANT", "SOLVENT", "FISH", "CHEST", "HEAVYSACK", "CLAM", "TROVE", "JUSTICE", "STASH" },
            getFunc = function() return EPC.saved.resourcePinsIconWood or "AUTO" end,
            setFunc = function(v) EPC.saved.resourcePinsIconWood = v if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = EPC.defaults.resourcePinsIconWood,
            width = "half",
        },
        {
            type = "dropdown", name = "Cloth icon",
            choices = { "Automatic", "Suite Glow", "Mining", "Wood", "Clothing", "Alchemy", "Enchanting", "Mushroom", "Flower", "Water Plant", "Solvent", "Fishing", "Chest", "Heavy Sack", "Giant Clam", "Trove", "Justice", "Stash" }, choicesValues = { "AUTO", "SUITE_GLOW", "MINING", "WOOD", "CLOTHING", "ALCHEMY", "ENCHANTING", "MUSHROOM", "FLOWER", "WATERPLANT", "SOLVENT", "FISH", "CHEST", "HEAVYSACK", "CLAM", "TROVE", "JUSTICE", "STASH" },
            getFunc = function() return EPC.saved.resourcePinsIconCloth or "AUTO" end,
            setFunc = function(v) EPC.saved.resourcePinsIconCloth = v if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = EPC.defaults.resourcePinsIconCloth,
            width = "half",
        },
        {
            type = "dropdown", name = "Alchemy icon",
            choices = { "Automatic", "Suite Glow", "Mining", "Wood", "Clothing", "Alchemy", "Enchanting", "Mushroom", "Flower", "Water Plant", "Solvent", "Fishing", "Chest", "Heavy Sack", "Giant Clam", "Trove", "Justice", "Stash" }, choicesValues = { "AUTO", "SUITE_GLOW", "MINING", "WOOD", "CLOTHING", "ALCHEMY", "ENCHANTING", "MUSHROOM", "FLOWER", "WATERPLANT", "SOLVENT", "FISH", "CHEST", "HEAVYSACK", "CLAM", "TROVE", "JUSTICE", "STASH" },
            getFunc = function() return EPC.saved.resourcePinsIconAlchemy or "AUTO" end,
            setFunc = function(v) EPC.saved.resourcePinsIconAlchemy = v if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = EPC.defaults.resourcePinsIconAlchemy,
            width = "half",
        },
        {
            type = "dropdown", name = "Runestone icon",
            choices = { "Automatic", "Suite Glow", "Mining", "Wood", "Clothing", "Alchemy", "Enchanting", "Mushroom", "Flower", "Water Plant", "Solvent", "Fishing", "Chest", "Heavy Sack", "Giant Clam", "Trove", "Justice", "Stash" }, choicesValues = { "AUTO", "SUITE_GLOW", "MINING", "WOOD", "CLOTHING", "ALCHEMY", "ENCHANTING", "MUSHROOM", "FLOWER", "WATERPLANT", "SOLVENT", "FISH", "CHEST", "HEAVYSACK", "CLAM", "TROVE", "JUSTICE", "STASH" },
            getFunc = function() return EPC.saved.resourcePinsIconRunes or "AUTO" end,
            setFunc = function(v) EPC.saved.resourcePinsIconRunes = v if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = EPC.defaults.resourcePinsIconRunes,
            width = "half",
        },
        {
            type = "dropdown", name = "Water / solvent icon",
            choices = { "Automatic", "Suite Glow", "Mining", "Wood", "Clothing", "Alchemy", "Enchanting", "Mushroom", "Flower", "Water Plant", "Solvent", "Fishing", "Chest", "Heavy Sack", "Giant Clam", "Trove", "Justice", "Stash" }, choicesValues = { "AUTO", "SUITE_GLOW", "MINING", "WOOD", "CLOTHING", "ALCHEMY", "ENCHANTING", "MUSHROOM", "FLOWER", "WATERPLANT", "SOLVENT", "FISH", "CHEST", "HEAVYSACK", "CLAM", "TROVE", "JUSTICE", "STASH" },
            getFunc = function() return EPC.saved.resourcePinsIconWater or "AUTO" end,
            setFunc = function(v) EPC.saved.resourcePinsIconWater = v if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = EPC.defaults.resourcePinsIconWater,
            width = "half",
        },
        {
            type = "dropdown", name = "Fishing icon",
            choices = { "Automatic", "Suite Glow", "Mining", "Wood", "Clothing", "Alchemy", "Enchanting", "Mushroom", "Flower", "Water Plant", "Solvent", "Fishing", "Chest", "Heavy Sack", "Giant Clam", "Trove", "Justice", "Stash" }, choicesValues = { "AUTO", "SUITE_GLOW", "MINING", "WOOD", "CLOTHING", "ALCHEMY", "ENCHANTING", "MUSHROOM", "FLOWER", "WATERPLANT", "SOLVENT", "FISH", "CHEST", "HEAVYSACK", "CLAM", "TROVE", "JUSTICE", "STASH" },
            getFunc = function() return EPC.saved.resourcePinsIconFishing or "AUTO" end,
            setFunc = function(v) EPC.saved.resourcePinsIconFishing = v if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = EPC.defaults.resourcePinsIconFishing,
            width = "half",
        },
        {
            type = "dropdown", name = "Special resource icon",
            choices = { "Automatic", "Suite Glow", "Mining", "Wood", "Clothing", "Alchemy", "Enchanting", "Mushroom", "Flower", "Water Plant", "Solvent", "Fishing", "Chest", "Heavy Sack", "Giant Clam", "Trove", "Justice", "Stash" }, choicesValues = { "AUTO", "SUITE_GLOW", "MINING", "WOOD", "CLOTHING", "ALCHEMY", "ENCHANTING", "MUSHROOM", "FLOWER", "WATERPLANT", "SOLVENT", "FISH", "CHEST", "HEAVYSACK", "CLAM", "TROVE", "JUSTICE", "STASH" },
            getFunc = function() return EPC.saved.resourcePinsIconSpecial or "AUTO" end,
            setFunc = function(v) EPC.saved.resourcePinsIconSpecial = v if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = EPC.defaults.resourcePinsIconSpecial,
            width = "half",
        },
        {
            type = "dropdown", name = "Other / unknown icon",
            choices = { "Automatic", "Suite Glow", "Mining", "Wood", "Clothing", "Alchemy", "Enchanting", "Mushroom", "Flower", "Water Plant", "Solvent", "Fishing", "Chest", "Heavy Sack", "Giant Clam", "Trove", "Justice", "Stash" }, choicesValues = { "AUTO", "SUITE_GLOW", "MINING", "WOOD", "CLOTHING", "ALCHEMY", "ENCHANTING", "MUSHROOM", "FLOWER", "WATERPLANT", "SOLVENT", "FISH", "CHEST", "HEAVYSACK", "CLAM", "TROVE", "JUSTICE", "STASH" },
            getFunc = function() return EPC.saved.resourcePinsIconOther or "AUTO" end,
            setFunc = function(v) EPC.saved.resourcePinsIconOther = v if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = EPC.defaults.resourcePinsIconOther,
            width = "half",
        },
        {
            type = "header", name = "Farm Focus",
        },
        {
            type = "description",
            text = "Turn Farm Focus on when you only want to see specific resource types. Your normal Resource Pin Filters below are preserved and automatically return when Farm Focus is turned off.",
        },
        {
            type = "checkbox", name = "Enable Farm Focus",
            tooltip = "When enabled, only the checked Farm Targets below are rendered as resource pins. You can configure Farm Targets at any time, even while Farm Focus is off.",
            getFunc = function() return EPC.saved.resourcePinsFarmFocusEnabled == true end,
            setFunc = function(v) EPC.saved.resourcePinsFarmFocusEnabled = v == true if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = EPC.defaults.resourcePinsFarmFocusEnabled or false,
            width = "full",
        },
        {
            type = "checkbox", name = "Farm ore / seams",
            getFunc = function() return EPC.saved.resourcePinsFarmOre == true end,
            setFunc = function(v) EPC.saved.resourcePinsFarmOre = v == true if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = false, width = "half",
        },
        {
            type = "checkbox", name = "Farm wood",
            getFunc = function() return EPC.saved.resourcePinsFarmWood == true end,
            setFunc = function(v) EPC.saved.resourcePinsFarmWood = v == true if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = false, width = "half",
        },
        {
            type = "checkbox", name = "Farm cloth",
            getFunc = function() return EPC.saved.resourcePinsFarmCloth == true end,
            setFunc = function(v) EPC.saved.resourcePinsFarmCloth = v == true if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = false, width = "half",
        },
        {
            type = "checkbox", name = "Farm alchemy plants",
            getFunc = function() return EPC.saved.resourcePinsFarmAlchemy == true end,
            setFunc = function(v) EPC.saved.resourcePinsFarmAlchemy = v == true if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = false, width = "half",
        },
        {
            type = "checkbox", name = "Farm runestones",
            getFunc = function() return EPC.saved.resourcePinsFarmRunes == true end,
            setFunc = function(v) EPC.saved.resourcePinsFarmRunes = v == true if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = false, width = "half",
        },
        {
            type = "checkbox", name = "Farm water / solvents",
            getFunc = function() return EPC.saved.resourcePinsFarmWater == true end,
            setFunc = function(v) EPC.saved.resourcePinsFarmWater = v == true if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = false, width = "half",
        },
        {
            type = "checkbox", name = "Farm fishing holes",
            getFunc = function() return EPC.saved.resourcePinsFarmFishing == true end,
            setFunc = function(v) EPC.saved.resourcePinsFarmFishing = v == true if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = false, width = "half",
        },
        {
            type = "checkbox", name = "Farm special resources",
            tooltip = "Chests, Heavy Sacks, Giant Clams, Troves, Justice containers and hidden stashes.",
            getFunc = function() return EPC.saved.resourcePinsFarmSpecial == true end,
            setFunc = function(v) EPC.saved.resourcePinsFarmSpecial = v == true if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = false, width = "half",
        },
        {
            type = "checkbox", name = "Farm other / unknown",
            getFunc = function() return EPC.saved.resourcePinsFarmOther == true end,
            setFunc = function(v) EPC.saved.resourcePinsFarmOther = v == true if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
            default = false, width = "half",
        },
        {
            type = "button", name = "Farm targets", buttonText = "Select All",
            func = function() if EPC.ResourcePins then EPC.ResourcePins:SetAllFarmTargets(true) end S:RequestDependencyRefresh029375(120) end,
            width = "half",
        },
        {
            type = "button", name = "Farm targets", buttonText = "Clear All",
            func = function() if EPC.ResourcePins then EPC.ResourcePins:SetAllFarmTargets(false) end S:RequestDependencyRefresh029375(120) end,
            width = "half",
        },
        {
            type = "header", name = "Normal Resource Pin Filters",
        },
        {
            type = "checkbox", name = "Show ore / seams",
            getFunc = function() return EPC.saved.resourcePinsShowOre ~= false end,
            setFunc = function(v) EPC.saved.resourcePinsShowOre = v == true if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
        },
        {
            type = "checkbox", name = "Show wood",
            getFunc = function() return EPC.saved.resourcePinsShowWood ~= false end,
            setFunc = function(v) EPC.saved.resourcePinsShowWood = v == true if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
        },
        {
            type = "checkbox", name = "Show cloth",
            getFunc = function() return EPC.saved.resourcePinsShowCloth ~= false end,
            setFunc = function(v) EPC.saved.resourcePinsShowCloth = v == true if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
        },
        {
            type = "checkbox", name = "Show alchemy plants",
            getFunc = function() return EPC.saved.resourcePinsShowAlchemy ~= false end,
            setFunc = function(v) EPC.saved.resourcePinsShowAlchemy = v == true if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
        },
        {
            type = "checkbox", name = "Show runestones",
            getFunc = function() return EPC.saved.resourcePinsShowRunes ~= false end,
            setFunc = function(v) EPC.saved.resourcePinsShowRunes = v == true if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
        },
        {
            type = "checkbox", name = "Show water / solvents",
            getFunc = function() return EPC.saved.resourcePinsShowWater ~= false end,
            setFunc = function(v) EPC.saved.resourcePinsShowWater = v == true if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
        },
        {
            type = "checkbox", name = "Show fishing holes",
            getFunc = function() return EPC.saved.resourcePinsShowFishing ~= false end,
            setFunc = function(v) EPC.saved.resourcePinsShowFishing = v == true if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
        },
        {
            type = "checkbox", name = "Show special resources",
            tooltip = "Shows recognized special resource locations such as Chests, Heavy Sacks, Giant Clams, Troves and hidden stashes from learned and community data.",
            getFunc = function() return EPC.saved.resourcePinsShowSpecial ~= false end,
            setFunc = function(v) EPC.saved.resourcePinsShowSpecial = v == true if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
        },
        {
            type = "checkbox", name = "Show uncollected Skyshards",
            tooltip = "Shows uncollected Skyshards with ESO's native skyshard icon tinted gold on the big map, minimap, and as nearby 3D markers. Skyshard positions and completion state come directly from ESO's API; the Suite does not copy or store a second Skyshard database.",
            getFunc = function() return EPC.saved.resourcePinsShowSkyshards ~= false end,
            setFunc = function(v) EPC.saved.resourcePinsShowSkyshards = v == true if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
        },
        {
            type = "checkbox", name = "Show other / unknown",
            tooltip = "Shows resource nodes whose type could not be classified.",
            getFunc = function() return EPC.saved.resourcePinsShowOther ~= false end,
            setFunc = function(v) EPC.saved.resourcePinsShowOther = v == true if EPC.ResourcePins then EPC.ResourcePins:RefreshSettings() end end,
        },
        {
            type = "button", name = "Test Suite Resource Pin", buttonText = "Show Test Pin",
            tooltip = "Queues an ore test marker about four meters in front of you. Close Settings to view it; the 10-second preview waits while menus are open. It is not saved.",
            func = function()
                if EPC.ResourcePins and EPC.ResourcePins:StartDebugTestGlow() then EPC:Print("Suite Resource Pins test marker queued about 4m ahead. Close Settings to view it for 10 seconds.")
                else EPC:Print("Suite Resource Pins could not get your current world position.") end
            end,
            disabled = function() return not EPC.ResourcePins or EPC.saved.resourcePinsEnabled == false end, width = "half",
        },
        {
            type = "button", name = "Resource Pin status", buttonText = "Print Status",
            func = function() if EPC.ResourcePins then EPC:Print(EPC.ResourcePins:GetStatusText()) end end,
            disabled = function() return not EPC.ResourcePins end, width = "half",
        },
        {
            type = "button", name = "Clear learned resource locations", buttonText = "Clear Resource Pins",
            tooltip = "Deletes every resource location learned by ESO Adventurer Suite.",
            func = function() if EPC.ResourcePins then EPC.ResourcePins:ClearLearnedLocations() EPC:Print("Suite Resource Pins learned locations cleared.") end end,
            disabled = function() return not EPC.ResourcePins end, width = "full",
        },
        {
            type = "header", name = "Team Visibility",
        },
        {
            type = "description",
            text = "Companions and grouped teammates use the soft 3D visibility glow. Companion settings are independent and default to purple. Group defaults can be overridden per player; overrides are saved by that player's account/name so they follow the player instead of a temporary group slot. Glow intensity can now reach full brightness. Red is reserved for dead grouped players and downed companions, with a separate red brightness control. Their glow slowly pulses until they revive or recover. Type /easteam for renderer status.",
        },
        {
            type = "checkbox", name = "Enable Team Visibility",
            tooltip = "Enables the Suite's enhanced native group markers and teammate visibility system.",
            getFunc = function() return EPC.saved.teamVisibilityEnabled ~= false end,
            setFunc = function(v) EPC.saved.teamVisibilityEnabled = v == true if EPC.TeamVisibility then EPC.TeamVisibility:RefreshSettings() end end,
            default = EPC.defaults.teamVisibilityEnabled,
            width = "half",
        },
        {
            type = "checkbox", name = "Show teammate glow",
            tooltip = "Shows the visibility glow on companions and group members where ESO allows addon 3D controls.",
            getFunc = function() return EPC.saved.teamVisibilityLightsEnabled ~= false end,
            setFunc = function(v) EPC.saved.teamVisibilityLightsEnabled = v == true if EPC.TeamVisibility then EPC.TeamVisibility:RefreshSettings() end end,
            default = EPC.defaults.teamVisibilityLightsEnabled,
            width = "half",
        },
        {
            type = "slider", name = "Downed/dead red glow brightness", min = 20, max = 100, step = 5,
            tooltip = "Controls the brightness of the reserved flashing red glow used when a grouped player dies or the active companion goes down. This setting is independent from their normal glow intensity.",
            getFunc = function() return math.floor((tonumber(EPC.saved.teamVisibilityDeadOpacity) or 1.00) * 100 + 0.5) end,
            setFunc = function(v) EPC.saved.teamVisibilityDeadOpacity = (tonumber(v) or 100) / 100 if EPC.TeamVisibility then EPC.TeamVisibility:RefreshSettings() end end,
            default = 100,
            width = "half",
        },
        {
            type = "header", name = "Companion Glow",
        },
        {
            type = "description",
            text = "The active companion has its own visibility settings. The default companion color is purple. If the companion goes down, the glow temporarily turns red and slowly pulses until recovery.",
        },
        {
            type = "colorpicker", name = "Companion color",
            tooltip = "Sets the active companion's normal glow color. Red is reserved for the downed state and is converted to amber while the companion is active.",
            getFunc = function()
                local c = EPC.saved.teamVisibilityCompanionColor or EPC.defaults.teamVisibilityCompanionColor
                return c.r or 0.72, c.g or 0.38, c.b or 1.00, 1
            end,
            setFunc = function(r, g, b, a)
                if EPC.TeamVisibility and EPC.TeamVisibility.NormalizeAlivePlayerColor then
                    r, g, b = EPC.TeamVisibility:NormalizeAlivePlayerColor(r, g, b)
                end
                EPC.saved.teamVisibilityCompanionColor = { r = r, g = g, b = b }
                if EPC.TeamVisibility then EPC.TeamVisibility:RefreshSettings() end
            end,
            default = { r = 0.72, g = 0.38, b = 1.00 },
            width = "full",
        },
        {
            type = "slider", name = "Companion glow width", min = 25, max = 250, step = 5,
            tooltip = "Adjusts the companion glow width independently from group members.",
            getFunc = function() return math.floor(((tonumber(EPC.saved.teamVisibilityCompanionBeamWidth) or 3.55) / 3.55) * 100 + 0.5) end,
            setFunc = function(v) EPC.saved.teamVisibilityCompanionBeamWidth = 3.55 * ((tonumber(v) or 100) / 100) if EPC.TeamVisibility then EPC.TeamVisibility:RefreshSettings() end end,
            default = 100,
            width = "half",
        },
        {
            type = "slider", name = "Companion glow height", min = 25, max = 150, step = 5,
            tooltip = "Adjusts the companion glow height independently from group members.",
            getFunc = function() return math.floor(((tonumber(EPC.saved.teamVisibilityCompanionBeamHeight) or 8.20) / 8.20) * 100 + 0.5) end,
            setFunc = function(v) EPC.saved.teamVisibilityCompanionBeamHeight = 8.20 * ((tonumber(v) or 100) / 100) if EPC.TeamVisibility then EPC.TeamVisibility:RefreshSettings() end end,
            default = 100,
            width = "half",
        },
        {
            type = "slider", name = "Companion glow intensity", min = 10, max = 100, step = 5,
            tooltip = "Controls how transparent or bright the companion glow appears. Higher values now render at full additive brightness instead of being capped low.",
            getFunc = function() return math.floor((tonumber(EPC.saved.teamVisibilityCompanionOpacity) or 0.24) * 100 + 0.5) end,
            setFunc = function(v) EPC.saved.teamVisibilityCompanionOpacity = (tonumber(v) or 24) / 100 if EPC.TeamVisibility then EPC.TeamVisibility:RefreshSettings() end end,
            default = 24,
            width = "half",
        },
        {
            type = "checkbox", name = "Companion glow through obstacles",
            tooltip = "Keeps the companion glow visible through walls, trees, and world geometry where ESO permits it.",
            getFunc = function() return EPC.saved.teamVisibilityCompanionThroughWalls ~= false end,
            setFunc = function(v) EPC.saved.teamVisibilityCompanionThroughWalls = v == true if EPC.TeamVisibility then EPC.TeamVisibility:RefreshSettings() end end,
            default = true,
            width = "half",
        },
        {
            type = "button", name = "Reset companion glow", buttonText = "Reset Companion",
            func = function()
                EPC.saved.teamVisibilityCompanionColor = { r = 0.72, g = 0.38, b = 1.00 }
                EPC.saved.teamVisibilityCompanionBeamWidth = 3.55
                EPC.saved.teamVisibilityCompanionBeamHeight = 8.20
                EPC.saved.teamVisibilityCompanionOpacity = 0.24
                EPC.saved.teamVisibilityCompanionThroughWalls = true
                if EPC.TeamVisibility then EPC.TeamVisibility:RefreshSettings() end
            end,
            width = "half",
        },
        {
            type = "header", name = "Group Default Glow",
        },
        {
            type = "checkbox", name = "Default group glow through obstacles",
            tooltip = "Default obstacle visibility for group members that do not have a player-specific override.",
            getFunc = function() return EPC.saved.teamVisibilityThroughWalls ~= false end,
            setFunc = function(v) EPC.saved.teamVisibilityThroughWalls = v == true if EPC.TeamVisibility then EPC.TeamVisibility:RefreshSettings() end end,
            default = EPC.defaults.teamVisibilityThroughWalls,
            width = "half",
        },
        {
            type = "slider", name = "Default group glow width", min = 25, max = 250, step = 5,
            tooltip = "Default width for group members without a player-specific override.",
            getFunc = function() return math.floor(((tonumber(EPC.saved.teamVisibilityBeamWidth) or 3.55) / 3.55) * 100 + 0.5) end,
            setFunc = function(v) EPC.saved.teamVisibilityBeamWidth = 3.55 * ((tonumber(v) or 100) / 100) if EPC.TeamVisibility then EPC.TeamVisibility:RefreshSettings() end end,
            default = 100,
            width = "half",
        },
        {
            type = "slider", name = "Default group glow height", min = 25, max = 150, step = 5,
            tooltip = "Default height for group members without a player-specific override.",
            getFunc = function() return math.floor(((tonumber(EPC.saved.teamVisibilityBeamHeight) or 8.20) / 8.20) * 100 + 0.5) end,
            setFunc = function(v) EPC.saved.teamVisibilityBeamHeight = 8.20 * ((tonumber(v) or 100) / 100) if EPC.TeamVisibility then EPC.TeamVisibility:RefreshSettings() end end,
            default = 100,
            width = "half",
        },
        {
            type = "slider", name = "Default group glow intensity", min = 10, max = 100, step = 5,
            tooltip = "Default brightness for group members without a player-specific override. Higher values now render at full additive brightness instead of being capped low.",
            getFunc = function() return math.floor((tonumber(EPC.saved.teamVisibilityOpacity) or 0.24) * 100 + 0.5) end,
            setFunc = function(v) EPC.saved.teamVisibilityOpacity = (tonumber(v) or 24) / 100 if EPC.TeamVisibility then EPC.TeamVisibility:RefreshSettings() end end,
            default = 24,
            width = "half",
        },
        {
            type = "header", name = "Per-Player Group Glow",
        },
        {
            type = "description",
            text = "Choose a current group slot, then customize that teammate. The override is stored by the player's account/name and follows them if their group slot changes later. If the selected slot is empty or is your own character, the controls are disabled.",
        },
        {
            type = "dropdown", name = "Group member to customize",
            choices = groupSlotChoices,
            choicesValues = groupSlotValues,
            getFunc = function() return tonumber(EPC.saved.teamVisibilitySelectedGroupSlot) or 1 end,
            setFunc = function(v) EPC.saved.teamVisibilitySelectedGroupSlot = tonumber(v) or 1 end,
            default = 1,
            width = "full",
        },
        {
            type = "checkbox", name = "Use custom settings for selected player",
            getFunc = function() local p = selectedGroupOverride(false) return p ~= nil and p.enabled ~= false end,
            setFunc = function(v) local p = selectedGroupOverride(v == true) if p then p.enabled = v == true end if EPC.TeamVisibility then EPC.TeamVisibility:RefreshSettings() end end,
            disabled = function() return not selectedGroupAvailable() end,
            default = false,
            width = "full",
        },
        {
            type = "colorpicker", name = "Selected player color",
            tooltip = "Overrides the normal leader/role color for the selected teammate. Red is reserved for dead players and cannot be used as a living-player glow.",
            getFunc = function()
                local p = selectedGroupOverride(false)
                if p and p.color then return p.color.r or 0.15, p.color.g or 0.95, p.color.b or 1.00, 1 end
                return selectedGroupRoleColor()
            end,
            setFunc = function(r, g, b, a) local p = selectedGroupOverride(true) if p then if EPC.TeamVisibility and EPC.TeamVisibility.NormalizeAlivePlayerColor then r, g, b = EPC.TeamVisibility:NormalizeAlivePlayerColor(r, g, b) end p.enabled = true p.color = { r = r, g = g, b = b } end if EPC.TeamVisibility then EPC.TeamVisibility:RefreshSettings() end end,
            disabled = function() local p = selectedGroupOverride(false) return not selectedGroupAvailable() or not p or p.enabled == false end,
            default = { r = 0.15, g = 0.95, b = 1.00 },
            width = "full",
        },
        {
            type = "slider", name = "Selected player glow width", min = 25, max = 250, step = 5,
            getFunc = function() local p = selectedGroupOverride(false) local width = p and p.width or EPC.saved.teamVisibilityBeamWidth or 3.55 return math.floor((width / 3.55) * 100 + 0.5) end,
            setFunc = function(v) local p = selectedGroupOverride(true) if p then p.enabled = true p.width = 3.55 * ((tonumber(v) or 100) / 100) end if EPC.TeamVisibility then EPC.TeamVisibility:RefreshSettings() end end,
            disabled = function() local p = selectedGroupOverride(false) return not selectedGroupAvailable() or not p or p.enabled == false end,
            default = 100,
            width = "half",
        },
        {
            type = "slider", name = "Selected player glow height", min = 25, max = 150, step = 5,
            getFunc = function() local p = selectedGroupOverride(false) local height = p and p.height or EPC.saved.teamVisibilityBeamHeight or 8.20 return math.floor((height / 8.20) * 100 + 0.5) end,
            setFunc = function(v) local p = selectedGroupOverride(true) if p then p.enabled = true p.height = 8.20 * ((tonumber(v) or 100) / 100) end if EPC.TeamVisibility then EPC.TeamVisibility:RefreshSettings() end end,
            disabled = function() local p = selectedGroupOverride(false) return not selectedGroupAvailable() or not p or p.enabled == false end,
            default = 100,
            width = "half",
        },
        {
            type = "slider", name = "Selected player glow intensity", min = 10, max = 100, step = 5,
            tooltip = "Controls the selected teammate's normal glow brightness up to full additive brightness. Red remains reserved for the dead/downed state.",
            getFunc = function() local p = selectedGroupOverride(false) return math.floor(((p and p.opacity) or EPC.saved.teamVisibilityOpacity or 0.24) * 100 + 0.5) end,
            setFunc = function(v) local p = selectedGroupOverride(true) if p then p.enabled = true p.opacity = (tonumber(v) or 24) / 100 end if EPC.TeamVisibility then EPC.TeamVisibility:RefreshSettings() end end,
            disabled = function() local p = selectedGroupOverride(false) return not selectedGroupAvailable() or not p or p.enabled == false end,
            default = 24,
            width = "half",
        },
        {
            type = "checkbox", name = "Selected player glow through obstacles",
            getFunc = function() local p = selectedGroupOverride(false) return p and p.throughWalls ~= false or false end,
            setFunc = function(v) local p = selectedGroupOverride(true) if p then p.enabled = true p.throughWalls = v == true end if EPC.TeamVisibility then EPC.TeamVisibility:RefreshSettings() end end,
            disabled = function() local p = selectedGroupOverride(false) return not selectedGroupAvailable() or not p or p.enabled == false end,
            default = true,
            width = "half",
        },
        {
            type = "button", name = "Reset selected player override", buttonText = "Reset Player",
            func = function()
                if EPC.TeamVisibility and EPC.TeamVisibility.GetGroupOverride then
                    local _, key = EPC.TeamVisibility:GetGroupOverride(selectedGroupTag(), false)
                    if key and EPC.saved.teamVisibilityPlayerOverrides then EPC.saved.teamVisibilityPlayerOverrides[key] = nil end
                    EPC.TeamVisibility:RefreshSettings()
                end
            end,
            disabled = function() return not selectedGroupAvailable() end,
            width = "half",
        },
        {
            type = "button", name = "Clear all player overrides", buttonText = "Clear All Players",
            func = function() EPC.saved.teamVisibilityPlayerOverrides = {} if EPC.TeamVisibility then EPC.TeamVisibility:RefreshSettings() end end,
            width = "half",
        },
        {
            type = "header", name = "World Combat Visibility",
        },
        {
            type = "checkbox", name = "Show outgoing damage numbers",
            tooltip = "Enables ESO scrolling combat text for your direct damage, damage-over-time ticks, and pet damage so hits pop over enemies.",
            getFunc = function() return EPC.saved.showOutgoingDamageNumbers ~= false end,
            setFunc = function(v) EPC.saved.showOutgoingDamageNumbers = v == true if EPC.CombatPresentation then EPC.CombatPresentation:Refresh() end end,
            default = EPC.defaults.showOutgoingDamageNumbers,
        },
        {
            type = "checkbox", name = "Show taunts & combat status effects",
            tooltip = "Enables ESO status-effect combat text and target debuffs so taunts, crowd-control/debuff feedback, interrupts and similar status events are easier to see when ESO exposes them.",
            getFunc = function() return EPC.saved.showCombatStatusEffects ~= false end,
            setFunc = function(v) EPC.saved.showCombatStatusEffects = v == true if EPC.CombatPresentation then EPC.CombatPresentation:Refresh() end end,
            default = EPC.defaults.showCombatStatusEffects,
        },
        {
            type = "header", name = "Persistent HUD & Unit Frames",
        },
        {
            type = "description",
            title = "Player / Target / Group / Raid / Mini Map HUD",
            text = "ESO-style replacement HUD. Player shows Health/Magicka/Stamina without name/level text; Target shows Health only. Player/Target resource fills now extend beneath the ESO end caps so full bars look completely filled. Group and Raid use matching ESO-style framed Health bars; active companions remain a second Health + Level entry. Ability icons (skills 1-5 plus Ultimate) are independently movable. Normal gameplay overlays keep Always / Combat Only modes; the Repair / Recharge Estimate instead offers Always / Tamriel Codex Only.",
        },
        {
            type = "header", name = "Stable Training Timer",
        },
        {
            type = "description",
            title = "Next riding upgrade",
            text = "Shows the character's actual stable riding-training cooldown. When the overlay reaches 0 - READY, you can visit a stable and train Riding Speed, Stamina, or Carry Capacity again.",
        },
        {
            type = "checkbox", name = "Show stable training timer",
            tooltip = "Counts down the ESO riding-training cooldown. 0 - READY means stable training is available now.",
            getFunc = function() return EPC.saved.showStableTimer ~= false end,
            setFunc = function(v) EPC.saved.showStableTimer = v == true if EPC.StableTimer then EPC.StableTimer:Refresh() end end,
            default = EPC.defaults.showStableTimer,
        },
        {
            type = "dropdown", name = "Stable timer visibility",
            choices = { "Always", "Combat Only" }, choicesValues = { "ALWAYS", "COMBAT" },
            getFunc = function() return EPC.saved.stableTimerVisibility or "ALWAYS" end,
            setFunc = function(v) EPC.saved.stableTimerVisibility = v if EPC.StableTimer then EPC.StableTimer:Refresh() end end,
            default = EPC.defaults.stableTimerVisibility,
        },
        {
            type = "button", name = "Reset stable timer position", buttonText = "Reset Stable Timer",
            func = function() if EPC.StableTimer then EPC.StableTimer:ResetPosition() EPC.StableTimer:Refresh() end end,
        },
        {
            type = "header", name = "Clock",
        },
        {
            type = "checkbox", name = "Show clock",
            tooltip = "Shows a simple 12-hour local clock such as 3:50 PM. Move it anywhere in ESO Edit HUD.",
            getFunc = function() return EPC.saved.showClock ~= false end,
            setFunc = function(v) EPC.saved.showClock = v == true if EPC.Clock then EPC.Clock:Refresh() end end,
            default = EPC.defaults.showClock,
        },
        {
            type = "dropdown", name = "Clock visibility",
            choices = { "Always", "Combat Only" }, choicesValues = { "ALWAYS", "COMBAT" },
            getFunc = function() return EPC.saved.clockVisibility or "ALWAYS" end,
            setFunc = function(v) EPC.saved.clockVisibility = v if EPC.Clock then EPC.Clock:Refresh() end end,
            default = EPC.defaults.clockVisibility,
        },
        {
            type = "button", name = "Reset clock position", buttonText = "Reset Clock",
            func = function() if EPC.Clock then EPC.Clock:ResetPosition() EPC.Clock:Refresh() end end,
        },
        {
            type = "header", name = "Quest Tracking",
        },
        {
            type = "dropdown", name = "Quest tracker source",
            tooltip = "Choose the single authoritative quest source used for ESO assisted quest/compass behavior. Active Quest follows your selected non-main Suite Quest Finder/journal quest. Golden Pursuits follows the journal quest linked to your selected Golden Pursuit. Main Quest follows the remembered Main Story quest. Overlay visibility is independent: Active Quest and Golden Pursuits overlays can both be enabled at the same time below.",
            choices = { "Active Quest", "Golden Pursuits", "Main Quest" },
            choicesValues = { "ACTIVE_QUEST", "GOLDEN_PURSUITS", "MAIN_QUEST" },
            getFunc = function()
                if EPC.ActiveQuest and EPC.ActiveQuest.GetQuestTrackingSource2513 then
                    return EPC.ActiveQuest:GetQuestTrackingSource2513()
                end
                return EPC.saved.questTrackingSource or "ACTIVE_QUEST"
            end,
            setFunc = function(v)
                if EPC.ActiveQuest and EPC.ActiveQuest.SetQuestTrackingSource2513 then
                    EPC.ActiveQuest:SetQuestTrackingSource2513(v)
                else
                    EPC.saved.questTrackingSource = v
                end
            end,
            default = EPC.defaults.questTrackingSource or "ACTIVE_QUEST",
        },
        {
            type = "header", name = "Active Quest Overlay",
        },
        {
            type = "checkbox", name = "Show active quest overlay",
            tooltip = "Shows your focused/tracked quest and every current incomplete objective. The overlay automatically grows or shrinks to the quest content, tightens spacing for longer objective lists, and can widen slightly when needed so objectives stay readable without leaving a large empty box.",
            getFunc = function() return EPC.saved.showActiveQuestOverlay ~= false end,
            setFunc = function(v) EPC.saved.showActiveQuestOverlay = v == true if EPC.ActiveQuest then EPC.ActiveQuest:Refresh() end end,
            default = EPC.defaults.showActiveQuestOverlay,
        },
        {
            type = "dropdown", name = "Active quest visibility",
            choices = { "Always", "Combat Only" }, choicesValues = { "ALWAYS", "COMBAT" },
            getFunc = function() return EPC.saved.activeQuestVisibility or "ALWAYS" end,
            setFunc = function(v) EPC.saved.activeQuestVisibility = v if EPC.ActiveQuest then EPC.ActiveQuest:Refresh() end end,
            default = EPC.defaults.activeQuestVisibility,
        },
        {
            type = "button", name = "Reset active quest position", buttonText = "Reset Active Quest",
            func = function() if EPC.ActiveQuest then EPC.ActiveQuest:ResetPosition() EPC.ActiveQuest:Refresh() end end,
        },
        {
            type = "slider", name = "Active quest width", min = 180, max = 900, step = 10,
            tooltip = "Changes the quest overlay width. Long quest names and objectives wrap inside this width.",
            getFunc = function() return tonumber(EPC.saved.activeQuestWidth) or 420 end,
            setFunc = function(v) EPC.saved.activeQuestWidth = v if EPC.ActiveQuest then EPC.ActiveQuest:SetSize(v, tonumber(EPC.saved.activeQuestHeight) or 160) end end,
            default = EPC.defaults.activeQuestWidth or 420,
        },
        {
            type = "slider", name = "Active quest maximum auto height", min = 220, max = 520, step = 10,
            tooltip = "Sets the maximum height the Active/Main Quest overlay may use. The overlay grows only as much as needed to show the current objectives and shrinks automatically for shorter quests.",
            getFunc = function() return tonumber(EPC.saved.activeQuestAutoMaxHeight337) or 520 end,
            setFunc = function(v) EPC.saved.activeQuestAutoMaxHeight337 = v if EPC.ActiveQuest then EPC.ActiveQuest:Refresh() end end,
            default = EPC.defaults.activeQuestAutoMaxHeight337 or 520,
        },
        {
            type = "button", name = "Reset active quest size", buttonText = "Reset Quest Size",
            func = function() if EPC.ActiveQuest then EPC.ActiveQuest:ResetSize() end end,
        },
        {
            type = "header", name = "Golden Pursuits Overlay",
        },
        {
            type = "checkbox", name = "Show Golden Pursuits overlay",
            tooltip = "Shows the selected Golden Pursuit, its linked quest, live progress, and every visible incomplete objective from that linked journal quest. The panel auto-fits its content and remains independent from Quest Tracker Source.",
            getFunc = function() return EPC.saved.showGoldenPursuitsOverlay ~= false end,
            setFunc = function(v) EPC.saved.showGoldenPursuitsOverlay = v == true if EPC.GoldenPursuits then EPC.GoldenPursuits:RefreshSelectedQuestPanel2504() end end,
            default = EPC.defaults.showGoldenPursuitsOverlay,
        },
        {
            type = "dropdown", name = "Golden Pursuits visibility",
            choices = { "Always", "Combat Only" }, choicesValues = { "ALWAYS", "COMBAT" },
            getFunc = function() return EPC.saved.goldenPursuitsVisibility or "ALWAYS" end,
            setFunc = function(v) EPC.saved.goldenPursuitsVisibility = v if EPC.GoldenPursuits then EPC.GoldenPursuits:RefreshVisibility2496() end end,
            default = EPC.defaults.goldenPursuitsVisibility or "ALWAYS",
        },
        {
            type = "button", name = "Reset Golden Pursuits position", buttonText = "Reset Golden Pursuits",
            func = function() if EPC.GoldenPursuits then EPC.GoldenPursuits:ResetPosition() EPC.GoldenPursuits:RefreshSelectedQuestPanel2504() end end,
        },
        {
            type = "slider", name = "Golden Pursuits width", min = 180, max = 900, step = 10,
            tooltip = "Changes the Golden Pursuits overlay width.",
            getFunc = function() return tonumber(EPC.saved.goldenPursuitsWidth) or 420 end,
            setFunc = function(v) EPC.saved.goldenPursuitsWidth = v if EPC.GoldenPursuits then EPC.GoldenPursuits:SetSize(v, tonumber(EPC.saved.goldenPursuitsHeight) or 136) end end,
            default = EPC.defaults.goldenPursuitsWidth or 420,
        },
        {
            type = "slider", name = "Golden Pursuits maximum auto height", min = 180, max = 420, step = 10,
            tooltip = "Sets the maximum automatic height for the Golden Pursuits / linked quest overlay. It grows only when extra progress/objective rows need room and shrinks again automatically.",
            getFunc = function() return tonumber(EPC.saved.goldenPursuitsAutoMaxHeight337) or 420 end,
            setFunc = function(v) EPC.saved.goldenPursuitsAutoMaxHeight337 = v if EPC.GoldenPursuits then EPC.GoldenPursuits:RefreshSelectedQuestPanel2504() end end,
            default = EPC.defaults.goldenPursuitsAutoMaxHeight337 or 420,
        },
        {
            type = "button", name = "Reset Golden Pursuits size", buttonText = "Reset Golden Size",
            func = function() if EPC.GoldenPursuits then EPC.GoldenPursuits:ResetSize() EPC.GoldenPursuits:RefreshSelectedQuestPanel2504() end end,
        },
        {
            type = "header", name = "Alliance Rank Overlay",
        },
        {
            type = "checkbox", name = "Show Alliance Rank overlay",
            tooltip = "ESO-style PvP rank icon and Alliance Rank progress. It is movable in ESO Edit HUD and independently scalable.",
            getFunc = function() return EPC.saved.showAllianceRank ~= false end,
            setFunc = function(v) EPC.saved.showAllianceRank = v == true if EPC.AllianceRank then EPC.AllianceRank:Refresh() end end,
            default = EPC.defaults.showAllianceRank,
        },
        {
            type = "dropdown", name = "Alliance Rank visibility",
            tooltip = "Always keeps the overlay visible during gameplay. Combat Only shows it only in combat. Alliance XP / AP Gain Only keeps it hidden until you earn Alliance Rank progress, then shows it for about 10 seconds.",
            choices = { "Always", "Combat Only", "Alliance XP / AP Gain Only" }, choicesValues = { "ALWAYS", "COMBAT", "GAIN" },
            getFunc = function() return EPC.saved.allianceRankVisibility or "ALWAYS" end,
            setFunc = function(v)
                EPC.saved.allianceRankVisibility = v
                if EPC.AllianceRank then
                    EPC.AllianceRank.gainVisibleUntilMs2960 = 0
                    EPC.AllianceRank:Refresh()
                end
            end,
            default = EPC.defaults.allianceRankVisibility,
        },
        {
            type = "button", name = "Test Alliance Rank gain popup", buttonText = "Test AP Gain Popup",
            tooltip = "Shows the Alliance Rank overlay using the same 10-second popup used by Alliance XP / AP Gain Only mode. Use this to verify the overlay and its position without waiting to earn AP.",
            func = function()
                if EPC.AllianceRank and EPC.AllianceRank.ShowForAllianceGain2960 then
                    EPC.AllianceRank:ShowForAllianceGain2960()
                end
            end,
        },
        {
            type = "slider", name = "Alliance Rank scale", min = 65, max = 180, step = 5,
            getFunc = function() return math.floor((tonumber(EPC.saved.allianceRankScale) or 1.0) * 100) end,
            setFunc = function(v) EPC.saved.allianceRankScale = v / 100 if EPC.AllianceRank then EPC.AllianceRank:Refresh() end end,
            default = math.floor((EPC.defaults.allianceRankScale or 1.0) * 100),
        },
        {
            type = "button", name = "Reset Alliance Rank position", buttonText = "Reset Alliance Rank",
            func = function() if EPC.AllianceRank then EPC.AllianceRank:ResetPosition() EPC.AllianceRank:Refresh() end end,
        },
        {
            type = "header", name = "Character Level / Champion Progress Overlay",
        },
        {
            type = "checkbox", name = "Show Level / Champion overlay",
            tooltip = "Levels 1-49: shows character level and live XP progress. At level 50 it automatically switches to the Champion Point overlay with Craft, Warfare, and Fitness totals.",
            getFunc = function() return EPC.saved.showChampionOverlay ~= false end,
            setFunc = function(v)
                EPC.saved.showChampionOverlay = v == true
                if EPC.ChampionOverlay then EPC.ChampionOverlay:Refresh() end
            end,
            default = EPC.defaults.showChampionOverlay,
        },
        {
            type = "dropdown", name = "Champion-stage visibility",
            tooltip = "The Level / XP overlay stays active from levels 1-49. After level 50, Always On keeps the Champion overlay visible; Champion Point Gain Only shows it for 10 seconds when a Champion Point is earned.",
            choices = { "Always On", "Champion Point Gain Only" },
            choicesValues = { "ALWAYS", "GAIN" },
            getFunc = function()
                return (EPC.saved.championOverlayVisibility == "GAIN") and "GAIN" or "ALWAYS"
            end,
            setFunc = function(v)
                if EPC.ChampionOverlay and EPC.ChampionOverlay.SetVisibilityMode2518 then
                    EPC.ChampionOverlay:SetVisibilityMode2518(v)
                else
                    EPC.saved.championOverlayVisibility = (v == "GAIN") and "GAIN" or "ALWAYS"
                end
            end,
            default = EPC.defaults.championOverlayVisibility or "ALWAYS",
        },
        {
            type = "button", name = "Reset progression overlay position", buttonText = "Reset Progress Overlay",
            func = function() if EPC.ChampionOverlay then EPC.ChampionOverlay:ResetPosition() EPC.ChampionOverlay:Refresh() end end,
        },
        {
            type = "header", name = "Controller / Gamepad",
        },
        {
            type = "description",
            text = "Controller input remains ESO-native and event-driven. If disabling Steam Input fixed controller movement lag, keep Steam Input disabled. These options only control the UI presentation and the button prompts shown by Suite action bars; they do not poll the analog sticks or replace ESO controller input.",
            width = "full",
        },
        {
            type = "dropdown", name = "Controller UI mode",
            tooltip = "ESO Automatic uses ESO's native automatic switching. ESO Gamepad UI forces the normal gamepad interface. Keyboard UI + Controller Controls keeps ESO's keyboard/desktop UI while leaving native controller gameplay bindings available.",
            choices = { "ESO Automatic", "ESO Gamepad UI", "Keyboard UI + Controller Controls" },
            choicesValues = { "AUTOMATIC", "GAMEPAD", "KEYBOARD_CONTROLLER" },
            getFunc = function()
                local v = EPC.saved.controllerUIBehavior029761 or "AUTOMATIC"
                if v == "ESO" then v = "AUTOMATIC" end
                return v
            end,
            setFunc = function(v)
                if EPC.ControllerSupport and EPC.ControllerSupport.SetUIBehavior029761 then
                    EPC.ControllerSupport:SetUIBehavior029761(v)
                else
                    EPC.saved.controllerUIBehavior029761 = v or "AUTOMATIC"
                end
            end,
            default = EPC.defaults.controllerUIBehavior029761 or "AUTOMATIC",
            width = "full",
        },
        {
            type = "dropdown", name = "Suite action-bar button prompts",
            tooltip = "Automatic follows ESO's current input UI, except Keyboard UI + Controller Controls intentionally uses controller symbols. Controller Symbols always shows ESO's native gamepad glyphs. Keyboard Keys always shows keyboard bindings. Applies to both the single ability bar and Dual Action Bar.",
            choices = { "Automatic", "Controller Symbols", "Keyboard Keys" },
            choicesValues = { "AUTO", "CONTROLLER", "KEYBOARD" },
            getFunc = function()
                return EPC.saved.controllerPromptMode029761 or "AUTO"
            end,
            setFunc = function(v)
                if EPC.ControllerSupport and EPC.ControllerSupport.SetPromptMode029761 then
                    EPC.ControllerSupport:SetPromptMode029761(v)
                else
                    EPC.saved.controllerPromptMode029761 = v or "AUTO"
                    if EPC.AbilityOverlays and EPC.AbilityOverlays.InvalidateBindingText then
                        EPC.AbilityOverlays:InvalidateBindingText()
                    end
                    if EPC.AbilityOverlays then EPC.AbilityOverlays:Refresh() end
                    if EPC.DualActionBar then EPC.DualActionBar:Refresh() end
                end
            end,
            default = EPC.defaults.controllerPromptMode029761 or "AUTO",
            width = "full",
        },
        {
            type = "description",
            text = "The Suite uses ESO's own current gamepad binding data and native key-markup renderer, so PlayStation/Xbox-style symbols follow the controller binding ESO reports instead of using hard-coded 1-5 labels.",
            width = "full",
        },

        {
            type = "header", name = "Dual Action Bar HUD",
        },
        {
            type = "checkbox", name = "Show both weapon action bars",
            tooltip = "Shows your front and back weapon bars at the same time. The active bar is marked clearly, while the inactive bar can be faded/desaturated. This is a Suite-owned display and does not cast skills or alter your controls.",
            getFunc = function() return EPC.saved.showDualActionBar029189 == true end,
            setFunc = function(v) EPC.saved.showDualActionBar029189 = v == true if EPC.DualActionBar then EPC.DualActionBar:Refresh() end end,
            default = EPC.defaults.showDualActionBar029189,
        },
        {
            type = "description",
            text = "This is the Suite's dual-bar HUD inspired by the useful two-bar workflow seen in action-bar addons. It is independently implemented and works alongside ESO's normal action bar. If you already use the separate Ability Overlays, you may prefer to disable those to avoid duplicate skill icons.",
        },
        {
            type = "button", name = "Use dual bar instead of separate ability overlays", buttonText = "Switch to Dual Bar HUD",
            tooltip = "Turns on the Dual Action Bar HUD and turns off the six separate Ability Overlays so you do not see duplicate skill icons. You can re-enable the separate overlays at any time.",
            func = function()
                EPC.saved.showDualActionBar029189 = true
                EPC.saved.showAbilityOverlays = false
                if EPC.AbilityOverlays then EPC.AbilityOverlays:Refresh() end
                if EPC.DualActionBar then EPC.DualActionBar:Refresh() end
            end,
        },
        {
            type = "dropdown", name = "Dual action bar visibility",
            choices = { "Always", "Combat Only" }, choicesValues = { "ALWAYS", "COMBAT" },
            getFunc = function() return EPC.saved.dualActionBarVisibility029189 or "ALWAYS" end,
            setFunc = function(v) EPC.saved.dualActionBarVisibility029189 = v or "ALWAYS" if EPC.DualActionBar then EPC.DualActionBar:Refresh() end end,
            default = EPC.defaults.dualActionBarVisibility029189,
        },
        {
            type = "checkbox", name = "Use selected Skill Style icons",
            tooltip = "When a slotted skill has an active Skill Style collectible, use that style's icon on the Suite action bar. Falls back to the normal slotted icon when no style override is available.",
            getFunc = function() return EPC.saved.dualActionBarSkillStyles029189 ~= false end,
            setFunc = function(v) EPC.saved.dualActionBarSkillStyles029189 = v == true if EPC.DualActionBar then EPC.DualActionBar:Refresh() end end,
            default = EPC.defaults.dualActionBarSkillStyles029189,
        },
        {
            type = "checkbox", name = "Show effect/cooldown timers",
            getFunc = function() return EPC.saved.dualActionBarShowTimers029189 ~= false end,
            setFunc = function(v) EPC.saved.dualActionBarShowTimers029189 = v == true if EPC.DualActionBar then EPC.DualActionBar:Refresh() end end,
            default = EPC.defaults.dualActionBarShowTimers029189,
        },
        {
            type = "checkbox", name = "Show stack counters",
            tooltip = "Shows stack counts when the Suite can match an active stack effect to the slotted skill, including stack-builder/spender abilities already understood by the Smart Combat Advisor.",
            getFunc = function() return EPC.saved.dualActionBarShowStacks029189 ~= false end,
            setFunc = function(v) EPC.saved.dualActionBarShowStacks029189 = v == true if EPC.DualActionBar then EPC.DualActionBar:Refresh() end end,
            default = EPC.defaults.dualActionBarShowStacks029189,
        },
        {
            type = "description",
            text = "Readiness: a tracked stack spender glows when its displayed stack threshold is full (for example Grim Focus at 5/5). Runtime proc/mode changes such as empowered Venom Skull, free Crystal Fragments, and Power Whip use ESO's effective hotbar ability state and also glow; entering that proc state plays a short readiness sound. Active-bar skills that ESO reports as unusable are dimmed until they can be used again.",
        },
        {
            type = "header", name = "Player Frame Recovery Ticks",
        },
        {
            type = "checkbox", name = "Show recovery ticks in player bars",
            tooltip = "Uses the Suite player Health, Magicka and Stamina frames themselves to show the next estimated recovery tick. A resource-colored sweep advances inside each real bar. An optional native-framed countdown attachment is anchored directly to the left of its matching Health, Magicka or Stamina bar, so each timer looks like part of the frame and stays aligned with its resource. Hidden when full, recovery is zero, or timing is unknown. No separate tracker panel.",
            getFunc = function() return EPC.saved.showTickTracker029382 == true end,
            setFunc = function(v) EPC.saved.showTickTracker029382 = v == true if EPC.TickTracker then EPC.TickTracker:Refresh() end end,
            default = EPC.defaults.showTickTracker029382,
        },
        {
            type = "dropdown", name = "Tick readout attachment",
            tooltip = "Chooses the small readout attached to the left of each Health, Magicka and Stamina frame. Slim uses the same-height native ESO frame silhouette. Fancy uses a slightly larger, more decorative framed sidecar with a stronger resource-colored inner glow. Off hides the side attachment while keeping the in-bar tick fill active.",
            choices = { "Off (fill only)", "Slim Attachment", "Fancy Attachment" },
            choicesValues = { "OFF", "SLIM", "FANCY" },
            getFunc = function() return EPC.saved.tickTrackerReadoutStyle029417 or "SLIM" end,
            setFunc = function(v) EPC.saved.tickTrackerReadoutStyle029417 = v or "SLIM" if EPC.TickTracker then EPC.TickTracker:Refresh() end end,
            default = EPC.defaults.tickTrackerReadoutStyle029417,
        },
        {
            type = "dropdown", name = "Recovery tick detail",
            tooltip = "Basic shows only the countdown. Advanced keeps the same in-bar fill and shows a clean countdown plus predicted recovery amount. Confirmed ticks, recovery-stat changes, delayed resync, and resource pressure are communicated visually instead of adding symbol/letter suffixes to the text.",
            choices = { "Basic", "Advanced" }, choicesValues = { "BASIC", "ADVANCED" },
            getFunc = function() return EPC.saved.tickTrackerMode029415 or "ADVANCED" end,
            setFunc = function(v) EPC.saved.tickTrackerMode029415 = v or "ADVANCED" if EPC.TickTracker then EPC.TickTracker:Refresh() end end,
            default = EPC.defaults.tickTrackerMode029415,
        },
        {
            type = "checkbox", name = "Show overcap recovery waste",
            tooltip = "Advanced mode marks the readout with WASTE when part of the next natural recovery pulse would be lost because the resource is near full. The main amount remains the predicted recovery that can actually fit.",
            getFunc = function() return EPC.saved.tickTrackerWaste029415 ~= false end,
            setFunc = function(v) EPC.saved.tickTrackerWaste029415 = v == true if EPC.TickTracker then EPC.TickTracker:Refresh() end end,
            default = EPC.defaults.tickTrackerWaste029415,
        },
        {
            type = "checkbox", name = "Flash on confirmed recovery tick",
            tooltip = "Briefly flashes the matching Health, Magicka, or Stamina countdown box when ESO actually applies a recovery-sized pulse on the trusted cadence.",
            getFunc = function() return EPC.saved.tickTrackerConfirm029415 ~= false end,
            setFunc = function(v) EPC.saved.tickTrackerConfirm029415 = v == true end,
            default = EPC.defaults.tickTrackerConfirm029415,
        },
        {
            type = "checkbox", name = "Show resource pressure hint",
            tooltip = "Advanced mode subtly tints the matching countdown box when recent spending or damage over the last four seconds is outpacing natural recovery. No extra symbols are added to the text.",
            getFunc = function() return EPC.saved.tickTrackerPressure029415 ~= false end,
            setFunc = function(v) EPC.saved.tickTrackerPressure029415 = v == true end,
            default = EPC.defaults.tickTrackerPressure029415,
        },
        {
            type = "checkbox", name = "Detect delayed ticks and resync",
            tooltip = "If a trusted recovery pulse does not arrive when expected while the resource is not full, Advanced mode briefly shows SYNC instead of pretending the old cadence is still accurate. The next valid pulse automatically locks the tracker back on phase.",
            getFunc = function() return EPC.saved.tickTrackerResync029415 ~= false end,
            setFunc = function(v) EPC.saved.tickTrackerResync029415 = v == true end,
            default = EPC.defaults.tickTrackerResync029415,
        },
        {
            type = "button", name = "Preview player recovery ticks", buttonText = "Test Tick Indicators",
            tooltip = "Run a ten-second demo inside the player resource bars. Close settings to see it. Temporarily shows the Suite player frame during gameplay; the timer starts when visible.",
            func = function() if EPC.TickTracker then EPC.TickTracker:Reveal(true) end end,
        },
        {
            type = "checkbox", name = "Show ability hotkeys",
            getFunc = function() return EPC.saved.dualActionBarShowHotkeys029189 ~= false end,
            setFunc = function(v) EPC.saved.dualActionBarShowHotkeys029189 = v == true if EPC.DualActionBar then EPC.DualActionBar:Refresh() end end,
            default = EPC.defaults.dualActionBarShowHotkeys029189,
        },
        {
            type = "dropdown", name = "Active bar marker",
            choices = { "ESO Weapons Icon + Soft Gold Glow", "ESO Weapon Swap Icon Only", "Bar Number Only" },
            choicesValues = { "ICON_GLOW", "ICON", "NUMBER" },
            getFunc = function()
                local v = EPC.saved.dualActionBarMarkerStyle029189 or "ICON_GLOW"
                if v == "ARROW_NUMBER" or v == "ICON_NUMBER" then return "ICON_GLOW" end
                if v == "ARROW" then return "ICON" end
                return v
            end,
            setFunc = function(v) EPC.saved.dualActionBarMarkerStyle029189 = v or "ICON_GLOW" if EPC.DualActionBar then EPC.DualActionBar:Refresh() end end,
            default = "ICON_GLOW",
        },
        {
            type = "checkbox", name = "Put Front Bar (Bar 1) on top",
            tooltip = "On by default: Bar 1 (front/main bar) is on top and Bar 2 (back bar) is on the bottom. Turn this off to reverse the rows. The rows stay fixed when you weapon-swap; the active marker moves instead.",
            getFunc = function() return EPC.saved.dualActionBarPrimaryOnTop029189 == true end,
            setFunc = function(v) EPC.saved.dualActionBarPrimaryOnTop029189 = v == true if EPC.DualActionBar then EPC.DualActionBar:Refresh() end end,
            default = EPC.defaults.dualActionBarPrimaryOnTop029189,
        },
        {
            type = "slider", name = "Dual bar icon size", min = 42, max = 78, step = 2,
            getFunc = function() return tonumber(EPC.saved.dualActionBarIconSize029189) or 54 end,
            setFunc = function(v) EPC.saved.dualActionBarIconSize029189 = v if EPC.DualActionBar then EPC.DualActionBar:Refresh() end end,
            default = EPC.defaults.dualActionBarIconSize029189,
        },
        {
            type = "slider", name = "Dual bar scale", min = 65, max = 180, step = 5,
            getFunc = function() return math.floor((tonumber(EPC.saved.dualActionBarScale029189) or 1.0) * 100) end,
            setFunc = function(v) EPC.saved.dualActionBarScale029189 = v / 100 if EPC.DualActionBar then EPC.DualActionBar:Refresh() end end,
            default = math.floor((EPC.defaults.dualActionBarScale029189 or 1.0) * 100),
        },
        {
            type = "slider", name = "Button spacing", min = 0, max = 18, step = 1,
            getFunc = function() return tonumber(EPC.saved.dualActionBarButtonGap029189) or 4 end,
            setFunc = function(v) EPC.saved.dualActionBarButtonGap029189 = v if EPC.DualActionBar then EPC.DualActionBar:Refresh() end end,
            default = EPC.defaults.dualActionBarButtonGap029189,
        },
        {
            type = "slider", name = "Bar row spacing", min = 0, max = 24, step = 1,
            getFunc = function() return tonumber(EPC.saved.dualActionBarRowGap029189) or 6 end,
            setFunc = function(v) EPC.saved.dualActionBarRowGap029189 = v if EPC.DualActionBar then EPC.DualActionBar:Refresh() end end,
            default = EPC.defaults.dualActionBarRowGap029189,
        },
        {
            type = "slider", name = "Inactive bar opacity", min = 10, max = 100, step = 5,
            getFunc = function() return tonumber(EPC.saved.dualActionBarInactiveAlpha029189) or 45 end,
            setFunc = function(v) EPC.saved.dualActionBarInactiveAlpha029189 = v if EPC.DualActionBar then EPC.DualActionBar:Refresh() end end,
            default = EPC.defaults.dualActionBarInactiveAlpha029189,
        },
        {
            type = "slider", name = "Inactive bar desaturation", min = 0, max = 100, step = 5,
            getFunc = function() return tonumber(EPC.saved.dualActionBarInactiveDesaturation029189) or 45 end,
            setFunc = function(v) EPC.saved.dualActionBarInactiveDesaturation029189 = v if EPC.DualActionBar then EPC.DualActionBar:Refresh() end end,
            default = EPC.defaults.dualActionBarInactiveDesaturation029189,
        },
        {
            type = "button", name = "Reset dual action bar position", buttonText = "Reset Dual Action Bar",
            func = function() if EPC.DualActionBar then EPC.DualActionBar:ResetPosition() EPC.DualActionBar:Refresh() end end,
        },

        {
            type = "header", name = "Ability Overlays",
        },
        {
            type = "checkbox", name = "Show ability overlays",
            tooltip = "Shows your five normal slotted skills (positions 1-5) plus Ultimate. Position the Suite ability HUD from ESO Edit HUD; passive/non-normal slots remain excluded.",
            getFunc = function() return EPC.saved.showAbilityOverlays ~= false end,
            setFunc = function(v) EPC.saved.showAbilityOverlays = v == true if EPC.AbilityOverlays then EPC.AbilityOverlays:Refresh() end end,
            default = EPC.defaults.showAbilityOverlays,
        },
        {
            type = "dropdown", name = "Ability overlays visibility",
            choices = { "Always", "Combat Only" }, choicesValues = { "ALWAYS", "COMBAT" },
            getFunc = function() return EPC.saved.abilityOverlayVisibility or "ALWAYS" end,
            setFunc = function(v) EPC.saved.abilityOverlayVisibility = v if EPC.AbilityOverlays then EPC.AbilityOverlays:Refresh() end end,
            default = EPC.defaults.abilityOverlayVisibility,
        },
        {
            type = "slider", name = "Ability icon size", min = 40, max = 90, step = 2,
            tooltip = "Changes all custom ability icon sizes while keeping each icon's saved position independent.",
            getFunc = function() return tonumber(EPC.saved.abilityOverlaySize) or 56 end,
            setFunc = function(v) EPC.saved.abilityOverlaySize = v if EPC.AbilityOverlays then EPC.AbilityOverlays:Refresh() end end,
            default = EPC.defaults.abilityOverlaySize or 56,
        },
        {
            type = "slider", name = "Ability overlay scale", min = 65, max = 180, step = 5,
            getFunc = function() return math.floor((tonumber(EPC.saved.abilityOverlayScale) or 1.0) * 100) end,
            setFunc = function(v) EPC.saved.abilityOverlayScale = v / 100 if EPC.AbilityOverlays then EPC.AbilityOverlays:Refresh() end end,
            default = math.floor((EPC.defaults.abilityOverlayScale or 1.0) * 100),
        },
        {
            type = "button", name = "Reset ability positions", buttonText = "Reset Abilities",
            func = function() if EPC.AbilityOverlays then EPC.AbilityOverlays:ResetPositions() EPC.AbilityOverlays:Refresh() end end,
        },
        {
            type = "header", name = "Quickslot Overlay",
        },
        {
            type = "checkbox", name = "Show quickslot overlay",
            tooltip = "Master switch for the quickslot overlay. When enabled, the visibility setting below controls when it appears.",
            getFunc = function() return EPC.saved.showQuickslotOverlay ~= false end,
            setFunc = function(v)
                EPC.saved.showQuickslotOverlay = v == true
                if EPC.QuickslotOverlay then EPC.QuickslotOverlay:Refresh() end
            end,
            default = EPC.defaults.showQuickslotOverlay,
        },
        {
            type = "dropdown", name = "When quickslot overlay appears",
            tooltip = "Always = keep the selected quickslot visible during normal gameplay. Before & During Combat = hidden while roaming, appears when you line up an attackable enemy, stays visible during combat, then hides again when combat ends. Before Combat Only = show only while an attackable enemy is targeted before combat. In Combat Only = show only while fighting.",
            choices = { "Always", "Before & During Combat", "Before Combat Only", "In Combat Only" },
            choicesValues = { "ALWAYS", "BEFORE_AND_DURING", "BEFORE_ONLY", "COMBAT" },
            getFunc = function()
                local mode = EPC.saved.quickslotOverlayVisibility or "BEFORE_AND_DURING"
                -- Keep legacy values compatible without remapping the real ALWAYS mode.
                if mode == "BEFORE_COMBAT" then
                    mode = "BEFORE_AND_DURING"
                    EPC.saved.quickslotOverlayVisibility = mode
                elseif mode == "OUT_OF_COMBAT" then
                    mode = "BEFORE_ONLY"
                    EPC.saved.quickslotOverlayVisibility = mode
                end
                return mode
            end,
            setFunc = function(v)
                EPC.saved.quickslotOverlayVisibility = v or "BEFORE_AND_DURING"
                if EPC.QuickslotOverlay then EPC.QuickslotOverlay:Refresh() end
            end,
            default = "BEFORE_AND_DURING",
        },
        {
            type = "description",
            text = "Tip: use ESO Edit HUD to move the quickslot overlay. Visibility and presentation remain controlled by Suite Settings.",
        },
        {
            type = "button", name = "Reset quickslot overlay position", buttonText = "Reset Quickslot",
            func = function()
                if EPC.QuickslotOverlay then
                    EPC.QuickslotOverlay:ResetPosition()
                    EPC.QuickslotOverlay:Refresh()
                end
            end,
        },
        {
            type = "header", name = "Infinite Archive Overlay",
        },
        {
            type = "checkbox", name = "Show Infinite Archive overlay",
            tooltip = "Shows the ESO Adventurer Suite Infinite Archive tracker. ESO's built-in Infinite Archive tracker is suppressed so only the Suite overlay can appear.",
            getFunc = function() return EPC.saved.showInfiniteArchiveOverlay ~= false end,
            setFunc = function(v)
                EPC.saved.showInfiniteArchiveOverlay = v == true
                if EPC.InfiniteArchiveOverlay then EPC.InfiniteArchiveOverlay:Refresh() end
            end,
            default = EPC.defaults.showInfiniteArchiveOverlay,
        },
        {
            type = "checkbox", name = "Highlight best Infinite Archive Verse / Vision",
            tooltip = "When the Infinite Archive offers Verse or Vision choices, the Suite scores every option against your Smart Advisor role/build, current Arc, remaining Threads, and Verses/Visions already collected in this run. The best choice gets a strong BEST FOR THIS RUN highlight. The Suite never selects or rerolls it for you.",
            getFunc = function() return EPC.saved.infiniteArchiveChoiceAdvisor029171 ~= false end,
            setFunc = function(v)
                EPC.saved.infiniteArchiveChoiceAdvisor029171 = v == true
                if EPC.InfiniteArchiveOverlay and EPC.InfiniteArchiveOverlay.UpdateArchiveChoiceAdvisor029171 then
                    EPC.InfiniteArchiveOverlay:UpdateArchiveChoiceAdvisor029171()
                end
            end,
            default = EPC.defaults.infiniteArchiveChoiceAdvisor029171,
        },
        {
            type = "description",
            text = "Archive choice scoring follows the Smart Advisor specialization above (Auto Detect, Magicka DPS, Stamina DPS, Hybrid, Healer, or Tank). It also increases survival value deeper into an Archive run and reinforces synergies you have already built with active Verses/Visions.",
        },
        {
            type = "slider", name = "Infinite Archive overlay scale", min = 65, max = 180, step = 5,
            tooltip = "Changes the size of the Suite-owned Infinite Archive tracker.",
            getFunc = function() return math.floor((tonumber(EPC.saved.infiniteArchiveOverlayScale) or 1.0) * 100) end,
            setFunc = function(v)
                EPC.saved.infiniteArchiveOverlayScale = v / 100
                if EPC.InfiniteArchiveOverlay then EPC.InfiniteArchiveOverlay:Refresh() end
            end,
            default = math.floor((EPC.defaults.infiniteArchiveOverlayScale or 1.0) * 100),
        },
        {
            type = "description",
            text = "Use ESO Edit HUD to drag the Suite Infinite Archive tracker anywhere. ESO's built-in Infinite Archive tracker stays hidden at all times, including menus and focus changes.",
        },
        {
            type = "button", name = "Move Infinite Archive overlay", buttonText = "Move Infinite Archive",
            tooltip = "Opens ESO Edit HUD, where the Suite-owned Infinite Archive tracker is available as a movable HUD element.",
            func = function()
                if EPC.SetUnitFramesMoveMode then EPC:SetUnitFramesMoveMode(true)
                elseif EPC.InfiniteArchiveOverlay then EPC.InfiniteArchiveOverlay:SetLayoutMode(true) end
            end,
            width = "half",
        },
        {
            type = "button", name = "Reset Infinite Archive overlay position", buttonText = "Reset Infinite Archive",
            width = "half",
            func = function()
                if EPC.InfiniteArchiveOverlay then
                    EPC.InfiniteArchiveOverlay:ResetPosition()
                end
            end,
        },
        {
            type = "header", name = "Custom ESO Reticle",
        },
        {
            type = "checkbox", name = "Use custom reticle",
            tooltip = "Replaces only ESO's center crosshair graphic. Interaction prompts, target text, stealth indicators, and normal ESO reticle functionality remain available.",
            getFunc = function() return EPC.saved.customReticleEnabled == true end,
            setFunc = function(v) EPC.saved.customReticleEnabled = v == true if EPC.Reticle then EPC.Reticle:Refresh() end end,
            default = EPC.defaults.customReticleEnabled,
        },
        {
            type = "dropdown", name = "Reticle style",
            choices = { "ESO Default", "Tamriel Rune", "Corner Brackets", "Compass Cross", "Minimal Cross", "Daedric Diamond", "Ayleid Star", "Dragon Eye" },
            choicesValues = { "DEFAULT", "RUNE", "BRACKETS", "COMPASS", "MINIMAL", "DAEDRIC", "AYLEID", "DRAGON" },
            getFunc = function() return EPC.saved.customReticleStyle or "RUNE" end,
            setFunc = function(v) EPC.saved.customReticleStyle = v if EPC.Reticle then EPC.Reticle:Refresh() end end,
            default = EPC.defaults.customReticleStyle,
        },
        {
            type = "dropdown", name = "Reticle color",
            choices = { "ESO Gold", "Ivory", "Crimson", "Arcane Blue", "RGB Rainbow" },
            choicesValues = { "GOLD", "IVORY", "CRIMSON", "BLUE", "RGB" },
            getFunc = function() return EPC.saved.customReticleColor or "GOLD" end,
            setFunc = function(v) EPC.saved.customReticleColor = v if EPC.Reticle then EPC.Reticle:Refresh() end end,
            default = EPC.defaults.customReticleColor,
        },
        {
            type = "slider", name = "Reticle size", min = 60, max = 180, step = 5,
            tooltip = "Scales the custom reticle while keeping it centered on ESO's aim point.",
            getFunc = function() return tonumber(EPC.saved.customReticleSize) or 100 end,
            setFunc = function(v) EPC.saved.customReticleSize = v if EPC.Reticle then EPC.Reticle:Refresh() end end,
            default = EPC.defaults.customReticleSize,
        },
        {
            type = "slider", name = "Reticle opacity", min = 25, max = 100, step = 5,
            getFunc = function() return math.floor((tonumber(EPC.saved.customReticleOpacity) or 0.95) * 100 + 0.5) end,
            setFunc = function(v) EPC.saved.customReticleOpacity = v / 100 if EPC.Reticle then EPC.Reticle:Refresh() end end,
            default = math.floor((EPC.defaults.customReticleOpacity or 0.95) * 100 + 0.5),
        },
        {
            type = "header", name = "Tamriel Codex",
        },
        {
            type = "description",
            title = "Tamriel Codex hotkey",
            text = "Assign 'Open / Close Tamriel Codex' under Controls > Keybindings > General > ESO Adventurer Suite. The same hotkey opens and closes the book, including while the Codex has UI focus. The Tamriel Codex is presented as a two-page lore-style book with animated page turns, categorized personal notes with auto-save, Read/Edit modes, named checkpoints, roleplay dice and coin toss, quest/achievement records, game statistics, and crafting reference pages. The Codex uses clear ESO UI fonts instead of the cursive book script for easier reading.",
        },
        {
            type = "button", name = "Open Tamriel Codex", buttonText = "Open Codex",
            func = function() if EPC.Journal then EPC.Journal:Show() end end,
        },
        {
            type = "checkbox", name = "Hide Suite HUD in menus / map",
            tooltip = "Recommended and enabled by default. Hides Player, Target, Group, Raid, Live Stats, Stable Training timer, Clock, Active Quest, Golden Pursuits, Mini Map, Alliance Rank, and combat HUD while Pause, Character, Inventory, the full World Map, Journal, Crafting, Store, Collections, and similar UI scenes are open. Restores them automatically in gameplay.",
            getFunc = function() return EPC.saved.hudHideInMenus ~= false end,
            setFunc = function(v) EPC.saved.hudHideInMenus = v == true if EPC.RefreshGameplayOverlays then EPC:RefreshGameplayOverlays() end end,
            default = EPC.defaults.hudHideInMenus,
        },
        {
            type = "header", name = "Unit Frame Designs",
        },
        {
            type = "description",
            title = "Player / Target / Group / Raid designs",
            text = "1 - ESO Classic: traditional ESO-shaped equal-width stacked resources.\n2 - Compact Stack: a tighter equal-width stacked layout.\n3 - Rect Stack: clean rectangular resources stacked vertically.\n4 - Triple Blocks: Health, Magicka, and Stamina arranged as three horizontal blocks.\n5 - Side Meters: wide Health with compact Magicka and Stamina meters at the side.\n6 - Center Core: centered Health with smaller centered Magicka and Stamina underneath.\n7 - Slim Lines: thin, compact resource lines for a minimal HUD.",
        },
        {
            type = "checkbox", name = "Replace ALL ESO unit frames",
            tooltip = "When enabled, the Suite replaces the keyboard player, target, local companion, group, and raid frames. ESO's native boss-health display is left alone. Turn this off to restore the other native ESO frames.",
            getFunc = function() return EPC.saved.replaceDefaultUnitFrames ~= false end,
            setFunc = function(v) EPC.saved.replaceDefaultUnitFrames = v == true if EPC.UnitFrames then EPC.UnitFrames:ApplyDefaultFrameReplacement() EPC.UnitFrames:RefreshAll(true) end end,
            default = EPC.defaults.replaceDefaultUnitFrames,
        },
        {
            type = "dropdown", name = "Unit frame design",
            tooltip = "Changes the actual layout shared by the Suite Player, Target, Group, and Raid frames. The seven distinct designs are numbered 1 through 7 in display order. Saved screen positions and scale are preserved.",
            choices = { "1 - ESO Classic", "2 - Compact Stack", "3 - Rect Stack", "4 - Triple Blocks", "5 - Side Meters", "6 - Center Core", "7 - Slim Lines" },
            choicesValues = { "ESO_CLASSIC", "COMPACT_STACK", "RECT_STACK", "TRIPLE_BLOCKS", "SIDE_METERS", "CENTER_CORE", "SLIM_LINES" },
            getFunc = function()
                local v = EPC.saved.unitFrameVisualStyle or "ESO_CLASSIC"
                if v == "CLEAN_MINIMAL" then return "COMPACT_STACK" end
                -- Removed/similar designs migrate to the closest retained centered style.
                if v == "DARK_GOLD" or v == "ARCANE_BLUE" or v == "HIGH_CONTRAST"
                    or v == "SPLIT_RESOURCES" or v == "WIDE_PLATE" or v == "TACTICAL_GRID" then
                    EPC.saved.unitFrameVisualStyle = "CENTER_CORE"
                    return "CENTER_CORE"
                end
                return v
            end,
            setFunc = function(v)
                EPC.saved.unitFrameVisualStyle = v or "ESO_CLASSIC"
                if EPC.UnitFrames then
                    EPC.UnitFrames:ApplyVisualStyle()
                    EPC.UnitFrames:RefreshAll(true)
                end
            end,
            default = EPC.defaults.unitFrameVisualStyle,
        },
        {
            type = "checkbox", name = "Show player frame",
            tooltip = "ESO-style scalable self frame. Buffs appear above Health, debuffs below Health, with native-style Health, Magicka, and Stamina bars underneath.",
            getFunc = function() return EPC.saved.showPlayerFrame ~= false end,
            setFunc = function(v) EPC.saved.showPlayerFrame = v == true if EPC.UnitFrames then EPC.UnitFrames:RefreshAll(true) end end,
            default = EPC.defaults.showPlayerFrame,
        },
        {
            type = "dropdown", name = "Player frame visibility",
            choices = { "Always", "Combat Only" }, choicesValues = { "ALWAYS", "COMBAT" },
            getFunc = function() return EPC.saved.playerFrameVisibility or "ALWAYS" end,
            setFunc = function(v) EPC.saved.playerFrameVisibility = v if EPC.UnitFrames then EPC.UnitFrames:RefreshAll(true) end end,
            default = EPC.defaults.playerFrameVisibility,
        },
        {
            type = "checkbox", name = "Show target frame",
            tooltip = "ESO-style scalable target frame. It shows target identity and Health only, with buffs above Health and debuffs below. No Magicka or Stamina bars are shown for targets.",
            getFunc = function() return EPC.saved.showTargetFrame ~= false end,
            setFunc = function(v) EPC.saved.showTargetFrame = v == true if EPC.UnitFrames then EPC.UnitFrames:RefreshAll(true) end end,
            default = EPC.defaults.showTargetFrame,
        },
        {
            type = "dropdown", name = "Target frame visibility",
            choices = { "Always", "Combat Only" }, choicesValues = { "ALWAYS", "COMBAT" },
            getFunc = function() return EPC.saved.targetFrameVisibility or "ALWAYS" end,
            setFunc = function(v) EPC.saved.targetFrameVisibility = v if EPC.UnitFrames then EPC.UnitFrames:RefreshAll(true) end end,
            default = EPC.defaults.targetFrameVisibility,
        },
        {
            type = "checkbox", name = "Show group frame",
            tooltip = "Shows player/member name, level/CP, role/status, Health, and companion name + companion level where ESO exposes it. Also appears for you + your active companion while solo.",
            getFunc = function() return EPC.saved.showGroupFrame ~= false end,
            setFunc = function(v) EPC.saved.showGroupFrame = v == true if EPC.UnitFrames then EPC.UnitFrames:RefreshAll(true) end end,
            default = EPC.defaults.showGroupFrame,
        },
        {
            type = "dropdown", name = "Group frame visibility", choices = { "Always", "Combat Only" }, choicesValues = { "ALWAYS", "COMBAT" },
            getFunc = function() return EPC.saved.groupFrameVisibility or "ALWAYS" end,
            setFunc = function(v) EPC.saved.groupFrameVisibility = v if EPC.UnitFrames then EPC.UnitFrames:RefreshGroupFrames() end end,
            default = EPC.defaults.groupFrameVisibility,
        },
        {
            type = "checkbox", name = "Show raid frame",
            tooltip = "Shows a compact multi-column raid/trial frame with member name, level/CP, role/status, and Health.",
            getFunc = function() return EPC.saved.showRaidFrame ~= false end,
            setFunc = function(v) EPC.saved.showRaidFrame = v == true if EPC.UnitFrames then EPC.UnitFrames:RefreshAll(true) end end,
            default = EPC.defaults.showRaidFrame,
        },
        {
            type = "dropdown", name = "Raid frame visibility", choices = { "Always", "Combat Only" }, choicesValues = { "ALWAYS", "COMBAT" },
            getFunc = function() return EPC.saved.raidFrameVisibility or "ALWAYS" end,
            setFunc = function(v) EPC.saved.raidFrameVisibility = v if EPC.UnitFrames then EPC.UnitFrames:RefreshGroupFrames() end end,
            default = EPC.defaults.raidFrameVisibility,
        },
        {
            type = "checkbox", name = "Show live combat stat panel",
            tooltip = "PEN, PWR, Spell Resistance, Physical Resistance, Critical Chance, and Critical Damage. These exact live values now feed Game Combat, where fight-weighted effective values are saved with the same combat sample. Combat-only visibility is enabled by default.",
            getFunc = function() return EPC.saved.showCombatStatsFrame ~= false end,
            setFunc = function(v) EPC.saved.showCombatStatsFrame = v == true if EPC.UnitFrames then EPC.UnitFrames:RefreshStats() end end,
            default = EPC.defaults.showCombatStatsFrame,
        },
        {
            type = "dropdown", name = "Live Combat Stats visibility",
            choices = { "Always", "Combat Only" }, choicesValues = { "ALWAYS", "COMBAT" },
            getFunc = function() return EPC.saved.combatStatsVisibility or "COMBAT" end,
            setFunc = function(v) EPC.saved.combatStatsVisibility = v if EPC.UnitFrames then EPC.UnitFrames:RefreshStats() end end,
            default = EPC.defaults.combatStatsVisibility,
        },
        {
            type = "header", name = "World Map Teleporter",
        },
        {
            type = "description",
            text = "The Suite Teleporter can stay attached to the World Map window or be available by hotkey while you are running around. Hotkey / Outside Map has no permanent gameplay drawer: assign Open / Close Map Teleporter under Controls > Keybindings > General > ESO Adventurer Suite. The key opens the full Teleporter in UI mode so you can interact with it; press the same key again, press Escape from a Teleporter search box, or click anywhere outside the Teleporter to close it and return to gameplay. ESO Edit HUD controls its saved screen position.",
        },
        {
            type = "checkbox", name = "Enable Map Teleporter",
            tooltip = "Master switch for the Suite Teleporter.",
            getFunc = function() return EPC.saved.mapTeleporterEnabled ~= false end,
            setFunc = function(v) EPC.saved.mapTeleporterEnabled = v == true if EPC.Travel and EPC.Travel.RefreshMapTeleporterVisibility then EPC.Travel:RefreshMapTeleporterVisibility() end end,
            default = EPC.defaults.mapTeleporterEnabled,
        },
        {
            type = "dropdown", name = "Teleporter visibility",
            choices = { "Open with World Map (Attached)", "Hotkey / Outside Map" },
            choicesValues = { "MAP", "ALWAYS" },
            tooltip = "Open with World Map (Attached) anchors the collapsible Teleporter to the stable World Map window (not the zooming map canvas) and shows it only with the map. Hotkey / Outside Map removes the permanent gameplay drawer; assign Open / Close Map Teleporter under Controls > Keybindings > General > ESO Adventurer Suite to summon it while adventuring. Press the same key again or click outside the Teleporter to close it and return to gameplay.",
            getFunc = function() return EPC.saved.mapTeleporterDisplayMode or "MAP" end,
            setFunc = function(v) EPC.saved.mapTeleporterDisplayMode = (v == "ALWAYS") and "ALWAYS" or "MAP" if EPC.Travel and EPC.Travel.RefreshMapTeleporterVisibility then EPC.Travel:RefreshMapTeleporterVisibility() end end,
            default = EPC.defaults.mapTeleporterDisplayMode,
        },
        {
            type = "description",
            text = "Positioning: open ESO Edit HUD and move the ESO Adventurer Suite - Map Teleporter element. ESO owns the saved HUD position.",
        },
        {
            type = "checkbox", name = "Include owned houses",
            tooltip = "Adds your owned houses and primary residence to All, Zones, Current Map, Houses, and Favorites views.",
            getFunc = function() return EPC.saved.mapTeleporterIncludeHouses ~= false end,
            setFunc = function(v) EPC.saved.mapTeleporterIncludeHouses = v == true if EPC.Travel then EPC.Travel:RefreshMapTeleporter() end end,
            default = EPC.defaults.mapTeleporterIncludeHouses,
        },
        {
            type = "checkbox", name = "Show zones without online players",
            tooltip = "The Zones tab also lists zones reachable through a discovered wayshrine or owned house even when no Group/Friend/Guild member is there.",
            getFunc = function() return EPC.saved.mapTeleporterShowAllZones ~= false end,
            setFunc = function(v) EPC.saved.mapTeleporterShowAllZones = v == true if EPC.Travel then EPC.Travel:RefreshMapTeleporter() end end,
            default = EPC.defaults.mapTeleporterShowAllZones,
        },
        {
            type = "dropdown", name = "Teleporter sorting",
            choices = { "Smart / Favorites First", "Zone", "Source", "Player Count", "Most Used", "Last Used" },
            choicesValues = { "SMART", "ZONE", "SOURCE", "PLAYER_COUNT", "MOST_USED", "LAST_USED" },
            getFunc = function() return EPC.saved.mapTeleporterSortMode or "SMART" end,
            setFunc = function(v) EPC.saved.mapTeleporterSortMode = v if EPC.Travel then EPC.Travel:RefreshMapTeleporter() end end,
            default = EPC.defaults.mapTeleporterSortMode,
        },
        {
            type = "slider", name = "Visible teleporter rows", min = 8, max = 20, step = 1,
            tooltip = "Controls how many destination rows are shown per page. The panel still fills the map's full height.",
            getFunc = function() return EPC.saved.mapTeleporterVisibleRows or 15 end,
            setFunc = function(v) EPC.saved.mapTeleporterVisibleRows = tonumber(v) or 15 if EPC.Travel then EPC.Travel:RefreshMapTeleporter() end end,
            default = EPC.defaults.mapTeleporterVisibleRows,
        },
        {
            type = "checkbox", name = "Show blacklisted destinations",
            tooltip = "Normally blacklisted players/zones are hidden. Enable this to display them in red so they can be unblacklisted from the row context menu.",
            getFunc = function() return EPC.saved.mapTeleporterShowBlacklisted == true end,
            setFunc = function(v) EPC.saved.mapTeleporterShowBlacklisted = v == true if EPC.Travel then EPC.Travel:RefreshMapTeleporter() end end,
            default = EPC.defaults.mapTeleporterShowBlacklisted,
        },
        {
            type = "header", name = "Wayshrine Auto Message",
        },
        {
            type = "description",
            title = "Custom message when you wayshrine somewhere new",
            text = "Optional chat helper for wayshrine travel and/or brand-new wayshrine discoveries. The Suite prepares your own custom message in the selected channel. ESO does not allow addons to silently submit normal chat, so for Say/Zone/Group/Guild you still press Enter to send (or Escape to cancel). Local / Suite Chat prints only to you and needs no confirmation. Want to repeat the message manually? Type /promo in chat at any time; it re-prepares your most recent Wayshrine Auto Message using your current template and selected channel.",
        },
        {
            type = "description",
            title = "Wayshrine message status",
            text = function()
                if EPC.WayshrineAutoMessage and EPC.WayshrineAutoMessage.GetStatusText then
                    return EPC.WayshrineAutoMessage:GetStatusText()
                end
                return "Wayshrine Auto Message is waiting for initialization."
            end,
        },
        {
            type = "checkbox", name = "Enable Wayshrine Auto Message",
            tooltip = "When enabled, the selected wayshrine trigger prepares your custom message. Disabled by default so every player chooses whether to use it.",
            getFunc = function() return EPC.saved.wayshrineAutoMessageEnabled == true end,
            setFunc = function(v) EPC.saved.wayshrineAutoMessageEnabled = v == true end,
            default = EPC.defaults.wayshrineAutoMessageEnabled,
        },
        {
            type = "dropdown", name = "Wayshrine message trigger",
            tooltip = "After Wayshrine Fast Travel also includes successful travel started from the Suite Teleporter, including wayshrine, friend, guild-member, group-member, and house jumps. New Wayshrine Discovery fires only when you unlock a previously unknown wayshrine. Both enables both behaviors.",
            choices = { "After Wayshrine Fast Travel", "New Wayshrine Discovery", "Both" },
            choicesValues = { "FAST_TRAVEL", "DISCOVERY", "BOTH" },
            getFunc = function() return EPC.saved.wayshrineAutoMessageTrigger or "FAST_TRAVEL" end,
            setFunc = function(v) EPC.saved.wayshrineAutoMessageTrigger = tostring(v or "FAST_TRAVEL") end,
            default = EPC.defaults.wayshrineAutoMessageTrigger,
        },
        {
            type = "editbox", name = "Wayshrine message",
            tooltip = "Write your own message. Available placeholders: {wayshrine} or {shrine}, {zone}, {character}, {account}, {guildlink}. Example: Recruiting in {zone}! Apply here: {guildlink}",
            getFunc = function() return tostring(EPC.saved.wayshrineAutoMessageTemplate or EPC.defaults.wayshrineAutoMessageTemplate or "") end,
            setFunc = function(v) EPC.saved.wayshrineAutoMessageTemplate = tostring(v or "") end,
            default = EPC.defaults.wayshrineAutoMessageTemplate,
            width = "full",
            isMultiline = false,
        },
        {
            type = "editbox", name = "Guild Recruitment Link",
            tooltip = "Optional. Paste the clickable ESO guild recruitment/listing link here exactly as ESO creates it with Link in Chat. Then place {guildlink} anywhere in your Wayshrine message. Leave this blank if you do not want a guild link.",
            getFunc = function() return tostring(EPC.saved.wayshrineAutoMessageGuildLink or "") end,
            setFunc = function(v)
                EPC.saved.wayshrineAutoMessageGuildLink = tostring(v or ""):gsub("\r", " "):gsub("\n", " "):gsub("^%s+", ""):gsub("%s+$", "")
            end,
            default = EPC.defaults.wayshrineAutoMessageGuildLink,
            width = "full",
            isMultiline = false,
        },
        {
            type = "description",
            text = "To get the link: open your guild's Recruitment/Guild Listing page, use ESO's Link in Chat option, then paste that generated guild link above. In your custom message use {guildlink}. Players can click the link to open your guild listing and apply.",
        },
        {
            type = "dropdown", name = "Wayshrine message channel",
            tooltip = "Choose where the prepared message goes. Local / Suite Chat only prints on your own screen; the other channels open ESO chat and wait for you to press Enter.",
            choices = { "Zone", "Say", "Group", "Guild 1", "Guild 2", "Guild 3", "Guild 4", "Guild 5", "Local / Suite Chat" },
            choicesValues = { "ZONE", "SAY", "GROUP", "GUILD1", "GUILD2", "GUILD3", "GUILD4", "GUILD5", "LOCAL" },
            getFunc = function() return EPC.saved.wayshrineAutoMessageChannel or "ZONE" end,
            setFunc = function(v) EPC.saved.wayshrineAutoMessageChannel = tostring(v or "ZONE") end,
            default = EPC.defaults.wayshrineAutoMessageChannel,
        },
        {
            type = "button", name = "Test Wayshrine Auto Message", buttonText = "Prepare Test Message",
            tooltip = "Uses Example Wayshrine plus your current zone so you can check the template and selected channel without discovering anything.",
            func = function() if EPC.WayshrineAutoMessage then EPC.WayshrineAutoMessage:TestMessage() end end,
            disabled = function() return not EPC.WayshrineAutoMessage end,
            width = "full",
        },
        {
            type = "header", name = "Treasure & Survey Locator",
        },
        {
            type = "description",
            text = "Suite-native treasure-map, crafting-survey, and Tales of Tribute clue locator. It reads location data from LibTreasure; the LostTreasure addon itself is not required. World Map pins are also mirrored by the Suite Mini Map. CustomCompassPins is optional and only needed for compass markers.",
        },
        {
            type = "description",
            text = "Dependency note: LibTreasure supplies the location database. CustomCompassPins is optional and only needed for compass markers. If LibTreasure is not installed, the locator stays inactive without blocking the rest of the Suite.",
        },
        {
            type = "description",
            title = "Locator status",
            text = function()
                if EPC.TreasureLocator and EPC.TreasureLocator.GetDetailedStatusText then
                    return EPC.TreasureLocator:GetDetailedStatusText()
                end
                return "Treasure & Survey Locator is waiting for initialization."
            end,
        },
        {
            type = "button", name = "Pin preview", buttonText = "Show Pin Preview",
            tooltip = "Opens a small legend showing the exact Treasure Map, Crafting Survey, and Tribute Clue icons used by the Suite.",
            func = function() if EPC.TreasureLocator and EPC.TreasureLocator.ShowPinPreview then EPC.TreasureLocator:ShowPinPreview() end end,
            width = "half",
        },
        {
            type = "button", name = "Locator status", buttonText = "Print Status",
            tooltip = "Prints LibTreasure availability, current-map database counts, visible locator count, and compass support to chat.",
            func = function() if EPC.TreasureLocator and EPC.TreasureLocator.PrintDetailedStatus then EPC.TreasureLocator:PrintDetailedStatus() end end,
            width = "half",
        },
        {
            type = "checkbox", name = "Enable Treasure & Survey Locator",
            getFunc = function() return EPC.saved.treasureLocatorEnabled ~= false end,
            setFunc = function(v) EPC.saved.treasureLocatorEnabled = v == true if EPC.TreasureLocator then EPC.TreasureLocator:RefreshSettings() end end,
            default = EPC.defaults.treasureLocatorEnabled,
        },
        {
            type = "dropdown", name = "Locations to mark",
            choices = { "Backpack Items Only", "Opened Item Only", "All Known Locations" },
            choicesValues = { "INVENTORY", "OPENED", "ALL" },
            tooltip = "Backpack Items Only marks maps/surveys/clues you currently carry. Opened Item Only marks the item you actually opened and removes it after the item leaves your backpack. All Known Locations shows the complete LibTreasure database for the current map.",
            getFunc = function() return EPC.saved.treasureLocatorScope or "INVENTORY" end,
            setFunc = function(v) EPC.saved.treasureLocatorScope = v if EPC.TreasureLocator then EPC.TreasureLocator:RefreshSettings() end end,
            default = EPC.defaults.treasureLocatorScope,
        },
        {
            type = "checkbox", name = "Treasure map locations",
            getFunc = function() return EPC.saved.treasureLocatorTreasure ~= false end,
            setFunc = function(v) EPC.saved.treasureLocatorTreasure = v == true if EPC.TreasureLocator then EPC.TreasureLocator:RefreshSettings() end end,
            default = EPC.defaults.treasureLocatorTreasure,
            width = "half",
        },
        {
            type = "checkbox", name = "Crafting survey locations",
            getFunc = function() return EPC.saved.treasureLocatorSurvey ~= false end,
            setFunc = function(v) EPC.saved.treasureLocatorSurvey = v == true if EPC.TreasureLocator then EPC.TreasureLocator:RefreshSettings() end end,
            default = EPC.defaults.treasureLocatorSurvey,
            width = "half",
        },
        {
            type = "checkbox", name = "Tribute clue locations",
            getFunc = function() return EPC.saved.treasureLocatorClue ~= false end,
            setFunc = function(v) EPC.saved.treasureLocatorClue = v == true if EPC.TreasureLocator then EPC.TreasureLocator:RefreshSettings() end end,
            default = EPC.defaults.treasureLocatorClue,
            width = "half",
        },
        {
            type = "checkbox", name = "World Map / Suite Mini Map pins",
            tooltip = "Creates the custom map pins. The Suite Mini Map automatically mirrors these pins when they belong to the current player map.",
            getFunc = function() return EPC.saved.treasureLocatorShowMap ~= false end,
            setFunc = function(v) EPC.saved.treasureLocatorShowMap = v == true if EPC.TreasureLocator then EPC.TreasureLocator:RefreshSettings() end end,
            default = EPC.defaults.treasureLocatorShowMap,
            width = "half",
        },
        {
            type = "checkbox", name = "Compass pins",
            tooltip = "Requires CustomCompassPins. Compass markers appear when a treasure/survey/clue is within the configured map-distance range. World Map and Suite Mini Map pins work independently.",
            getFunc = function() return EPC.saved.treasureLocatorShowCompass ~= false end,
            setFunc = function(v) EPC.saved.treasureLocatorShowCompass = v == true if EPC.TreasureLocator then EPC.TreasureLocator:RefreshSettings() end end,
            disabled = function() return not EPC.TreasureLocator or not EPC.TreasureLocator:IsCompassAvailable() end,
            default = EPC.defaults.treasureLocatorShowCompass,
            width = "half",
        },
        {
            type = "slider", name = "Compass locator range", min = 2, max = 25, step = 1,
            tooltip = "How close a Treasure Map, Survey, or Tribute Clue must be before CustomCompassPins draws it. The value is a percentage of the current map width; 10 is a useful general default.",
            getFunc = function() return tonumber(EPC.saved.treasureLocatorCompassRange) or 10 end,
            setFunc = function(v) EPC.saved.treasureLocatorCompassRange = math.floor(tonumber(v) or 10) if EPC.TreasureLocator then EPC.TreasureLocator:RefreshSettings() end end,
            disabled = function() return not EPC.TreasureLocator or not EPC.TreasureLocator:IsCompassAvailable() end,
            default = EPC.defaults.treasureLocatorCompassRange or 10,
        },
        {
            type = "slider", name = "Treasure / survey pin size", min = 18, max = 64, step = 2,
            getFunc = function() return tonumber(EPC.saved.treasureLocatorPinSize) or 32 end,
            setFunc = function(v) EPC.saved.treasureLocatorPinSize = math.floor(tonumber(v) or 32) if EPC.TreasureLocator then EPC.TreasureLocator:RefreshSettings() end end,
            default = EPC.defaults.treasureLocatorPinSize,
        },
        {
            type = "header", name = "Mini Map",
        },
        {
            type = "checkbox", name = "Show mini map",
            tooltip = "Shows EPC's intelligent north-up navigation minimap. It auto-declutters by mode/context and always hides while ESO's full World Map is open.",
            getFunc = function() return EPC.saved.showMiniMap ~= false end,
            setFunc = function(v) EPC.saved.showMiniMap = v == true if EPC.MiniMap then EPC.MiniMap:Refresh(true) end end,
            default = EPC.defaults.showMiniMap,
        },
        {
            type = "dropdown", name = "Mini map visibility", choices = { "Always", "Combat Only" }, choicesValues = { "ALWAYS", "COMBAT" },
            getFunc = function() return EPC.saved.miniMapVisibility or "ALWAYS" end,
            setFunc = function(v) EPC.saved.miniMapVisibility = v if EPC.MiniMap then EPC.MiniMap:Refresh(true) end end,
            default = EPC.defaults.miniMapVisibility,
        },
        {
            type = "dropdown", name = "Mini map intelligence mode",
            tooltip = "SMART changes visible layers with context. QUEST focuses objectives, EXPLORE emphasizes nearby/unfinished POIs, GROUP prioritizes teammates/rally, MINIMAL shows only essential navigation, and CUSTOM honors all layer toggles.",
            choices = { "Smart", "Quest", "Explore", "Group", "Minimal", "Custom" },
            choicesValues = { "SMART", "QUEST", "EXPLORE", "GROUP", "MINIMAL", "CUSTOM" },
            getFunc = function() return EPC.MiniMap and EPC.MiniMap:GetMode() or (EPC.saved.miniMapMode or "SMART") end,
            setFunc = function(v) if EPC.MiniMap then EPC.MiniMap:SetMode(v) else EPC.saved.miniMapMode = v end end,
            default = EPC.defaults.miniMapMode,
        },
        {
            type = "dropdown", name = "Mini map visual style",
            tooltip = "Choose the live in-game minimap frame style.",
            choices = { "Fantasy Round", "Fantasy Square" },
            choicesValues = { "FANTASY_ROUND", "FANTASY_SQUARE" },
            getFunc = function() return (EPC.MiniMap and EPC.MiniMap:GetVisualStyle()) or (EPC.saved.miniMapVisualStyle or "FANTASY_ROUND") end,
            setFunc = function(v) EPC.saved.miniMapVisualStyle = v if EPC.MiniMap then EPC.MiniMap:ApplySizeAndStyle() EPC.MiniMap:Refresh(true) end end,
            default = EPC.defaults.miniMapVisualStyle,
        },
        {
            type = "dropdown", name = "Fantasy frame color",
            tooltip = "Choose the color of the Fantasy Round or Fantasy Square frame. Automatic matches the current character's alliance. Manual choices let any character use Aldmeri gold/yellow, Daggerfall blue, or Ebonheart red regardless of alliance.",
            choices = { "Automatic (Match Alliance)", "Aldmeri Gold / Yellow", "Daggerfall Blue", "Ebonheart Red" },
            choicesValues = { "AUTO", "AD", "BLUE", "EP" },
            getFunc = function()
                if EPC.MiniMap and EPC.MiniMap.GetFrameColorChoice then
                    return EPC.MiniMap:GetFrameColorChoice()
                end
                local choice = tostring(EPC.saved.miniMapFrameColorChoice or "")
                if choice == "AUTO" or choice == "AD" or choice == "BLUE" or choice == "EP" then
                    return choice
                end
                return EPC.saved.miniMapAllianceFrame == false and "BLUE" or "AUTO"
            end,
            setFunc = function(v)
                v = tostring(v or "AUTO")
                EPC.saved.miniMapFrameColorChoice = v
                -- Keep the old boolean coherent for backward compatibility.
                EPC.saved.miniMapAllianceFrame = (v == "AUTO")
                if EPC.MiniMap then
                    EPC.MiniMap:ApplySizeAndStyle()
                    EPC.MiniMap:Refresh(true)
                end
            end,
            default = "AUTO",
        },
        {
            type = "slider", name = "Fantasy frame size", min = 100, max = 112, step = 1,
            tooltip = "Enlarges only the Fantasy frame presentation and gives its North, East, South, and West plaques extra room so they are not clipped. The live-map zoom and your chosen icon size are kept separate.",
            getFunc = function() return math.floor((tonumber(EPC.saved.miniMapFantasyFrameScale) or 1.08) * 100 + 0.5) end,
            setFunc = function(v)
                EPC.saved.miniMapFantasyFrameScale = (tonumber(v) or 108) / 100
                if EPC.MiniMap then EPC.MiniMap:ApplySizeAndStyle() EPC.MiniMap:Refresh(true) end
            end,
            default = math.floor((EPC.defaults.miniMapFantasyFrameScale or 1.08) * 100 + 0.5),
        },
        {
            type = "dropdown", name = "Mini map theme mode",
            tooltip = "Manual keeps the exact visual style you picked. Auto by zone changes the minimap skin automatically whenever you move into a different zone or sub-zone.",
            choices = { "Manual", "Auto by zone" },
            choicesValues = { "MANUAL", "AUTO_ZONE" },
            getFunc = function() return EPC.saved.miniMapThemeMode or "MANUAL" end,
            setFunc = function(v) EPC.saved.miniMapThemeMode = v if EPC.MiniMap then EPC.MiniMap:ApplySizeAndStyle() EPC.MiniMap:Refresh(true) end end,
            default = EPC.defaults.miniMapThemeMode,
        },
        {
            type = "dropdown", name = "Zone-themed style family",
            tooltip = "When Auto by zone is enabled, choose whether zones use the Fantasy Square frame, the Fantasy Round frame, or a mix of both.",
            choices = { "Square", "Round", "Mixed" },
            choicesValues = { "SQUARE", "ROUND", "MIXED" },
            getFunc = function() return EPC.saved.miniMapZoneThemeFamily or "MIXED" end,
            setFunc = function(v) EPC.saved.miniMapZoneThemeFamily = v if EPC.MiniMap then EPC.MiniMap:ApplySizeAndStyle() EPC.MiniMap:Refresh(true) end end,
            default = EPC.defaults.miniMapZoneThemeFamily,
        },
        {
            type = "dropdown", name = "Mini map player marker style",
            tooltip = "Choose the minimap player-arrow style. Suite Arrow keeps the current Suite look. The other three use the same Suite arrow artwork with Aldmeri gold, Daggerfall blue, or Ebonheart red alliance coloring.",
            choices = { "Suite Arrow", "Aldmeri Suite Arrow", "Daggerfall Suite Arrow", "Ebonheart Suite Arrow" },
            choicesValues = { "SUITE", "MINIMAP", "MINIMAP_ARROW", "MINIMAP_GOLD_ARROW" },
            getFunc = function() return EPC.saved.miniMapPlayerMarkerStyle or "MINIMAP_GOLD_ARROW" end,
            setFunc = function(v) EPC.saved.miniMapPlayerMarkerStyle = v if EPC.MiniMap then EPC.MiniMap:ApplySizeAndStyle() EPC.MiniMap:UpdatePanAndPins(true) end end,
            default = EPC.defaults.miniMapPlayerMarkerStyle,
        },
        {
            type = "checkbox", name = "Adaptive zoom",
            tooltip = "Automatically uses a closer navigation view in cities/local maps and dungeons, with smaller mounted/combat adjustments, then returns to your base zoom without overwriting it.",
            getFunc = function() return EPC.saved.miniMapAdaptiveZoom ~= false end,
            setFunc = function(v) EPC.saved.miniMapAdaptiveZoom = v == true if EPC.MiniMap then EPC.MiniMap:RebuildMap(true) end end,
            default = EPC.defaults.miniMapAdaptiveZoom,
            width = "half",
        },
        {
            type = "checkbox", name = "Edge guidance",
            tooltip = "Keeps important off-screen quest, waypoint, rally, and group-leader markers clamped to the mini map edge instead of hiding them.",
            getFunc = function() return EPC.saved.miniMapEdgeGuidance ~= false end,
            setFunc = function(v) EPC.saved.miniMapEdgeGuidance = v == true if EPC.MiniMap then EPC.MiniMap:UpdatePanAndPins(true) end end,
            default = EPC.defaults.miniMapEdgeGuidance,
            width = "half",
        },
        {
            type = "slider", name = "Mini map size", min = 180, max = 420, step = 10,
            tooltip = "Base minimap size in UI units. Fantasy frames can be enlarged separately with Fantasy frame size so the compass plaques and ornament details stay readable.",
            getFunc = function() return tonumber(EPC.saved.miniMapSize) or 260 end,
            setFunc = function(v) EPC.saved.miniMapSize = math.floor(v) if EPC.MiniMap then EPC.MiniMap:ApplySizeAndStyle() EPC.MiniMap:Refresh(true) end end,
            default = EPC.defaults.miniMapSize,
        },
        {
            type = "slider", name = "Mini map zoom", min = 70, max = 200, step = 5,
            tooltip = "Higher values zoom closer to your character. You can also use /esosuite minimap zoom 1.25 or the mouse wheel while Mini Map Move Mode is active.",
            getFunc = function() return math.floor((tonumber(EPC.saved.miniMapZoom) or 1.38) * 100) end,
            setFunc = function(v) EPC.saved.miniMapZoom = v / 100 if EPC.MiniMap then EPC.MiniMap:RebuildMap(true) EPC.MiniMap:Refresh(true) end end,
            default = math.floor((EPC.defaults.miniMapZoom or 1.0) * 100),
        },
        {
            type = "slider", name = "Mini map icon size", min = 60, max = 160, step = 5,
            tooltip = "Scales minimap markers only. 100% is the Suite default; full-map native icon dimensions are capped separately so city/service markers stay readable without covering the minimap.",
            getFunc = function() return math.floor((tonumber(EPC.saved.miniMapIconScale) or 1.00) * 100 + 0.5) end,
            setFunc = function(v) EPC.saved.miniMapIconScale = (tonumber(v) or 100) / 100 if EPC.MiniMap then EPC.MiniMap:UpdatePanAndPins(true) end end,
            default = math.floor((EPC.defaults.miniMapIconScale or 1.00) * 100 + 0.5),
        },
        {
            type = "slider", name = "Mini map opacity", min = 35, max = 100, step = 1,
            tooltip = "Opacity of the complete mini map widget.",
            getFunc = function() return math.floor((tonumber(EPC.saved.miniMapAlpha) or 0.92) * 100) end,
            setFunc = function(v) EPC.saved.miniMapAlpha = v / 100 if EPC.MiniMap then EPC.MiniMap:ApplySizeAndStyle() end end,
            default = math.floor((EPC.defaults.miniMapAlpha or 0.92) * 100),
        },
        {
            type = "slider", name = "Map texture opacity", min = 40, max = 100, step = 1,
            tooltip = "Controls the map-art opacity inside the mini map separately from markers.",
            getFunc = function() return math.floor((tonumber(EPC.saved.miniMapMapAlpha) or 0.86) * 100) end,
            setFunc = function(v) EPC.saved.miniMapMapAlpha = v / 100 if EPC.MiniMap then EPC.MiniMap:RebuildMap(true) end end,
            default = math.floor((EPC.defaults.miniMapMapAlpha or 0.86) * 100),
        },
        {
            type = "checkbox", name = "Mini map: focused quest",
            tooltip = "Show the current assisted quest objective when ESO exposes an exact map position.",
            getFunc = function() return EPC.saved.miniMapShowQuest ~= false end,
            setFunc = function(v) EPC.saved.miniMapShowQuest = v == true if EPC.MiniMap then EPC.MiniMap:UpdatePanAndPins(true) end end,
            default = EPC.defaults.miniMapShowQuest,
        },
        {
            type = "checkbox", name = "Mini map: player waypoint",
            tooltip = "Show your ESO player waypoint when it is on the current map.",
            getFunc = function() return EPC.saved.miniMapShowWaypoint ~= false end,
            setFunc = function(v) EPC.saved.miniMapShowWaypoint = v == true if EPC.MiniMap then EPC.MiniMap:UpdatePanAndPins(true) end end,
            default = EPC.defaults.miniMapShowWaypoint,
        },
        {
            type = "checkbox", name = "Mini map: discovered wayshrines",
            tooltip = "Show discovered/unlocked wayshrines that ESO reports on the current map.",
            getFunc = function() return EPC.saved.miniMapShowWayshrines ~= false end,
            setFunc = function(v) EPC.saved.miniMapShowWayshrines = v == true if EPC.MiniMap then EPC.MiniMap:RefreshStaticPins() EPC.MiniMap:UpdatePanAndPins(true) end end,
            default = EPC.defaults.miniMapShowWayshrines,
        },
        {
            type = "checkbox", name = "Mini map: group members",
            tooltip = "Show group members when ESO reports their position on your current map.",
            getFunc = function() return EPC.saved.miniMapShowGroup ~= false end,
            setFunc = function(v) EPC.saved.miniMapShowGroup = v == true if EPC.MiniMap then EPC.MiniMap:UpdatePanAndPins(true) end end,
            default = EPC.defaults.miniMapShowGroup,
        },
        {
            type = "checkbox", name = "Mini map: companion",
            tooltip = "Show your active companion when ESO reports the companion on your current map.",
            getFunc = function() return EPC.saved.miniMapShowCompanion ~= false end,
            setFunc = function(v) EPC.saved.miniMapShowCompanion = v == true if EPC.MiniMap then EPC.MiniMap:UpdatePanAndPins(true) end end,
            default = EPC.defaults.miniMapShowCompanion,
        },
        {
            type = "checkbox", name = "Mini map: live POIs",
            tooltip = "Uses ESO's current-map POI API and shows all POIs ESO reports as visible on the current map. Pins are clustered to avoid icon spam.",
            getFunc = function() return EPC.saved.miniMapShowPOIs ~= false end,
            setFunc = function(v) EPC.saved.miniMapShowPOIs = v == true if EPC.MiniMap then EPC.MiniMap:RefreshStaticPins() EPC.MiniMap:UpdatePanAndPins(true) end end,
            default = EPC.defaults.miniMapShowPOIs,
            width = "half",
        },
        {
            type = "checkbox", name = "Mini map: rally point",
            tooltip = "Shows the active group rally point and keeps it on the map edge when it is outside the visible area.",
            getFunc = function() return EPC.saved.miniMapShowRally ~= false end,
            setFunc = function(v) EPC.saved.miniMapShowRally = v == true if EPC.MiniMap then EPC.MiniMap:UpdatePanAndPins(true) end end,
            default = EPC.defaults.miniMapShowRally,
            width = "half",
        },
        {
            type = "checkbox", name = "Mini map: movement trail",
            tooltip = "Shows a short fading breadcrumb trail behind your character. SMART hides the trail during combat to reduce clutter.",
            getFunc = function() return EPC.saved.miniMapShowTrail ~= false end,
            setFunc = function(v) EPC.saved.miniMapShowTrail = v == true if EPC.MiniMap then EPC.MiniMap:UpdatePanAndPins(true) end end,
            default = EPC.defaults.miniMapShowTrail,
            width = "half",
        },
        {
            type = "slider", name = "Mini map POI density", min = 24, max = 160, step = 4,
            tooltip = "Maximum number of visible POI pins rendered at once. Towns no longer cluster nearby POIs, so higher values keep service and landmark icons visible.",
            getFunc = function() return tonumber(EPC.saved.miniMapPOIMax) or 120 end,
            setFunc = function(v) EPC.saved.miniMapPOIMax = math.floor(v) if EPC.MiniMap then EPC.MiniMap:RefreshStaticPins() EPC.MiniMap:UpdatePanAndPins(true) end end,
            default = EPC.defaults.miniMapPOIMax,
        },
        {
            type = "button", name = "Mini Map position", buttonText = "Move Mini Map",
            tooltip = "Unlocks only the Mini Map and activates a full-map drag surface so clicks cannot be intercepted by map tiles or pins. Drag anywhere on the map; its position is saved automatically.",
            func = function() if EPC.SetMiniMapMoveMode then EPC:SetMiniMapMoveMode(true) end end,
            width = "half",
        },
        {
            type = "button", name = "Lock Mini Map", buttonText = "Lock Mini Map",
            tooltip = "Ends Mini Map Move Mode and returns the map to non-interactive gameplay behavior.",
            func = function() if EPC.SetMiniMapMoveMode then EPC:SetMiniMapMoveMode(false) end end,
            width = "half",
        },
        {
            type = "button", name = "Reset Mini Map position", buttonText = "Reset Mini Map",
            tooltip = "Restores only the Mini Map to its default upper-right position.",
            func = function() if EPC.ResetMiniMapPosition then EPC:ResetMiniMapPosition() end end,
        },
        {
            type = "button", name = "Clear legacy map icons", buttonText = "Clear Legacy Icons",
            tooltip = "Deletes only the old walk-up/interaction-saved merchant, crafting/service, and remembered POI icons from pre-0.27 minimap builds. Native ESO town icons, checkpoints, routes, and minimap settings are kept. Legacy walk-up icon learning stays disabled so the old duplicates do not return.",
            func = function()
                if EPC.MiniMap and EPC.MiniMap.ClearLegacyMapIcons then
                    EPC.MiniMap:ClearLegacyMapIcons()
                end
            end,
        },
        {
            type = "header", name = "ESO Native Loot History & Chat",
        },
        {
            type = "description",
            title = "Move and resize ESO's own Loot History and Chat",
            text = "These are ESO's real native controls. Update 51 gives ESO position ownership for Loot / XP History and the native Chat min-bar through Edit HUD. Suite Settings still provide Loot scale and expanded Chat size/docking controls without competing with ESO's saved HUD anchors.",
        },
        {
            type = "button", name = "Move Loot / XP History", buttonText = "Move Native Loot History",
            tooltip = "Closes Settings and exposes ESO's actual native Loot / XP History. Drag the native history entry itself to move it; use the mouse wheel over it to change size.",
            func = function()
                if EPC.NativeHUDLayout and EPC.NativeHUDLayout.FocusNativeLayout029710 then
                    EPC.NativeHUDLayout:FocusNativeLayout029710("LOOT")
                elseif EPC.SetUnitFramesMoveMode then
                    EPC:SetUnitFramesMoveMode(true)
                end
            end,
            width = "half",
        },
        {
            type = "button", name = "Move Chat", buttonText = "Move Native Chat",
            tooltip = "Closes Settings and exposes ESO's actual keyboard Chat control. Drag its first native tab to move it and use the native window edges to resize it.",
            func = function()
                if EPC.NativeHUDLayout and EPC.NativeHUDLayout.FocusNativeLayout029710 then
                    EPC.NativeHUDLayout:FocusNativeLayout029710("CHAT")
                elseif EPC.SetUnitFramesMoveMode then
                    EPC:SetUnitFramesMoveMode(true)
                end
            end,
            width = "half",
        },
        {
            type = "slider", name = "Loot / XP History size", min = 65, max = 180, step = 5,
            tooltip = "Scales ESO's native Loot History feed. Position the native Loot History element in ESO Edit HUD.",
            getFunc = function() return math.floor((tonumber(EPC.saved.nativeLootHistoryScale029708) or 1.0) * 100) end,
            setFunc = function(v)
                EPC.saved.nativeLootHistoryScale029708 = (tonumber(v) or 100) / 100
                if EPC.NativeHUDLayout and EPC.NativeHUDLayout.SetLootScale then EPC.NativeHUDLayout:SetLootScale(EPC.saved.nativeLootHistoryScale029708) end
            end,
            default = 100,
        },
        {
            type = "dropdown", name = "Chat dock",
            tooltip = "ESO Default leaves the stock chat placement alone. Free keeps the expanded Chat window at its custom Suite position. Left/Right/Top/Bottom dock the expanded Chat window; ESO Edit HUD owns the native minimized Chat bar.",
            choices = { "ESO Default", "Free", "Left", "Right", "Top", "Bottom" },
            choicesValues = { "NATIVE", "FREE", "LEFT", "RIGHT", "TOP", "BOTTOM" },
            getFunc = function() return EPC.saved.nativeChatDock029708 or "NATIVE" end,
            setFunc = function(v)
                EPC.saved.nativeChatDock029708 = v or "NATIVE"
                if EPC.NativeHUDLayout and EPC.NativeHUDLayout.SetChatDock then EPC.NativeHUDLayout:SetChatDock(EPC.saved.nativeChatDock029708) end
            end,
            default = "NATIVE",
        },
        {
            type = "slider", name = "Chat width", min = 320, max = 1100, step = 20,
            tooltip = "Changes the expanded native keyboard Chat width. Position controls exposed by ESO remain in Edit HUD.",
            getFunc = function()
                local value = tonumber(EPC.saved.nativeChatWidth029708) or 0
                if value > 0 then return math.floor(value) end
                if EPC.NativeHUDLayout and EPC.NativeHUDLayout.GetChatRect then
                    local _, _, width = EPC.NativeHUDLayout:GetChatRect()
                    return math.floor(tonumber(width) or 500)
                end
                return 500
            end,
            setFunc = function(v)
                local height = tonumber(EPC.saved.nativeChatHeight029708) or 0
                if EPC.NativeHUDLayout and EPC.NativeHUDLayout.GetChatRect and height <= 0 then
                    local _, _, _, currentHeight = EPC.NativeHUDLayout:GetChatRect()
                    height = tonumber(currentHeight) or 300
                end
                EPC.saved.nativeChatWidth029708 = tonumber(v) or 500
                EPC.saved.nativeChatHeight029708 = height > 0 and height or 300
                if EPC.NativeHUDLayout and EPC.NativeHUDLayout.SetChatSize then EPC.NativeHUDLayout:SetChatSize(EPC.saved.nativeChatWidth029708, EPC.saved.nativeChatHeight029708) end
            end,
            default = 500,
            width = "half",
        },
        {
            type = "slider", name = "Chat height", min = 180, max = 760, step = 20,
            tooltip = "Changes the expanded native keyboard Chat height. Position controls exposed by ESO remain in Edit HUD.",
            getFunc = function()
                local value = tonumber(EPC.saved.nativeChatHeight029708) or 0
                if value > 0 then return math.floor(value) end
                if EPC.NativeHUDLayout and EPC.NativeHUDLayout.GetChatRect then
                    local _, _, _, height = EPC.NativeHUDLayout:GetChatRect()
                    return math.floor(tonumber(height) or 300)
                end
                return 300
            end,
            setFunc = function(v)
                local width = tonumber(EPC.saved.nativeChatWidth029708) or 0
                if EPC.NativeHUDLayout and EPC.NativeHUDLayout.GetChatRect and width <= 0 then
                    local _, _, currentWidth = EPC.NativeHUDLayout:GetChatRect()
                    width = tonumber(currentWidth) or 500
                end
                EPC.saved.nativeChatHeight029708 = tonumber(v) or 300
                EPC.saved.nativeChatWidth029708 = width > 0 and width or 500
                if EPC.NativeHUDLayout and EPC.NativeHUDLayout.SetChatSize then EPC.NativeHUDLayout:SetChatSize(EPC.saved.nativeChatWidth029708, EPC.saved.nativeChatHeight029708) end
            end,
            default = 300,
            width = "half",
        },
        {
            type = "button", name = "Reset Loot / XP History layout", buttonText = "Reset Loot History",
            tooltip = "Restores ESO's stock Loot History anchor and 100% size.",
            func = function() if EPC.NativeHUDLayout and EPC.NativeHUDLayout.ResetLootHistory then EPC.NativeHUDLayout:ResetLootHistory() end end,
            width = "half",
        },
        {
            type = "button", name = "Reset Chat layout", buttonText = "Reset Chat",
            tooltip = "Returns chat to ESO's original position and size and restores ESO Default docking.",
            func = function() if EPC.NativeHUDLayout and EPC.NativeHUDLayout.ResetChat then EPC.NativeHUDLayout:ResetChat() end end,
            width = "half",
        },
        {
            type = "description",
            text = "ESO Edit HUD now owns native Alert Text positioning. The Suite also registers its Request / Invite Prompt and Compass Focused Info helpers as Edit HUD elements while preserving ESO's real behavior.",
        },
        {
            type = "button", name = "Test request / invite prompt", buttonText = "Test Prompt",
            tooltip = "Shows a harmless 6.5-second preview at the saved request-prompt position. It does not send, accept, or decline anything.",
            func = function() if EPC.PlayerRequestOverlay and EPC.PlayerRequestOverlay.TestPrompt then EPC.PlayerRequestOverlay:TestPrompt() end end,
            width = "half",
        },
        {
            type = "button", name = "Test native alert notification", buttonText = "Test Notification",
            tooltip = "Sends one harmless local ESO alert through the same native fading alert stack used by group invite results and wayshrine/location notices so you can verify its position and scale.",
            func = function() if EPC.NativeNotificationOverlay and EPC.NativeNotificationOverlay.TestNotification then EPC.NativeNotificationOverlay:TestNotification() end end,
            width = "half",
        },
        {
            type = "button", name = "ESO Edit HUD", buttonText = "Open Edit HUD",
            tooltip = "Opens ESO's native Edit HUD. ESO now owns the saved position of Suite HUD elements. Size, scale, visibility, colors, and other presentation options remain in ESO Adventurer Suite Settings.",
            func = function()
                if EPC.NativeHUDEditor and EPC.NativeHUDEditor.Open and EPC.NativeHUDEditor:Open() then
                    return
                end
                if EPC.SetUnitFramesMoveMode then EPC:SetUnitFramesMoveMode(true) end
            end,
            width = "half",
        },
        {
            type = "description",
            title = "Native HUD positioning",
            text = "Update 51 integration: movable ESO Adventurer Suite HUD elements are registered directly with ESO's Edit HUD. Move/reset positions there; use Suite Settings for sizing, scaling, visibility, and appearance.",
            width = "half",
        },
        {
            type = "button", name = "Reset HUD frame positions", buttonText = "Reset Frames",
            tooltip = "Restores default positions for Player, Target, Group, Raid, Live Combat Stats, Mini Map, Stable, Clock, Active Quest, Alliance Rank, Repair Estimate, Use Synergy, Rotation Assistant, Antiquity Augur Guide, Antiquity Tile Selector, every Ability icon, ESO Loot / XP History, ESO Chat, the ESO Request / Invite Prompt, and ESO Top-Right Notifications.",
            func = function() if EPC.ResetUnitFramePositions then EPC:ResetUnitFramePositions() end end,
        },
        {
            type = "slider", name = "Player frame size", min = 65, max = 180, step = 5,
            getFunc = function() return math.floor((EPC.saved.playerFrameScale or EPC.saved.unitFrameScale or 1.0) * 100) end,
            setFunc = function(v) EPC.saved.playerFrameScale = v / 100 if EPC.UnitFrames then EPC.UnitFrames:ApplyScalesAndAlpha() end end,
            default = math.floor((EPC.defaults.playerFrameScale or 1.0) * 100),
        },
        {
            type = "slider", name = "Target frame size", min = 65, max = 180, step = 5,
            getFunc = function() return math.floor((EPC.saved.targetFrameScale or EPC.saved.unitFrameScale or 1.0) * 100) end,
            setFunc = function(v) EPC.saved.targetFrameScale = v / 100 if EPC.UnitFrames then EPC.UnitFrames:ApplyScalesAndAlpha() end end,
            default = math.floor((EPC.defaults.targetFrameScale or 1.0) * 100),
        },
        {
            type = "slider", name = "Group / Raid frame scale", min = 65, max = 150, step = 5,
            getFunc = function() return math.floor((EPC.saved.groupFrameScale or 1.0) * 100) end,
            setFunc = function(v) EPC.saved.groupFrameScale = v / 100 if EPC.UnitFrames then EPC.UnitFrames:ApplyScalesAndAlpha() end end,
            default = math.floor((EPC.defaults.groupFrameScale or 1.0) * 100),
        },
        {
            type = "slider", name = "Live stats panel scale", min = 65, max = 150, step = 5,
            getFunc = function() return math.floor((EPC.saved.combatStatsScale or 1.0) * 100) end,
            setFunc = function(v) EPC.saved.combatStatsScale = v / 100 if EPC.UnitFrames then EPC.UnitFrames:ApplyScalesAndAlpha() end end,
            default = math.floor((EPC.defaults.combatStatsScale or 1.0) * 100),
        },
        {
            type = "checkbox", name = "Use stronger HUD panel backgrounds",
            tooltip = "Optional stronger panel style. Leave this off for the compact soft-background look.",
            getFunc = function() return EPC.saved.unitFrameBackgrounds == true end,
            setFunc = function(v) EPC.saved.unitFrameBackgrounds = v == true if EPC.UnitFrames then EPC.UnitFrames:ApplyVisualStyle() end end,
            default = EPC.defaults.unitFrameBackgrounds,
        },
        {
            type = "checkbox", name = "Dark HUD backgrounds",
            tooltip = "On by default. Adds compact dark readable backgrounds behind Player, Target, Group/Raid, aura slots, and Live Combat Stats without increasing their footprint.",
            getFunc = function() return EPC.saved.unitFrameSoftBackground ~= false end,
            setFunc = function(v) EPC.saved.unitFrameSoftBackground = v == true if EPC.UnitFrames then EPC.UnitFrames:ApplyVisualStyle() end end,
            default = EPC.defaults.unitFrameSoftBackground,
        },
        {
            type = "slider", name = "HUD background opacity", min = 45, max = 95, step = 1,
            tooltip = "Controls the dark panel opacity. v0.9.3 defaults to 72% so the world does not wash through the HUD text and bars.",
            getFunc = function() return math.floor((EPC.saved.unitFrameBackgroundAlpha or 0.20) * 100) end,
            setFunc = function(v) EPC.saved.unitFrameBackgroundAlpha = v / 100 if EPC.UnitFrames then EPC.UnitFrames:ApplyVisualStyle() end end,
            default = math.floor((EPC.defaults.unitFrameBackgroundAlpha or 0.20) * 100),
        },
        {
            type = "slider", name = "Floating HUD opacity", min = 35, max = 100, step = 1,
            tooltip = "Adjusts text, bars, icons, and accents. Soft background opacity is controlled separately.",
            getFunc = function() return math.floor((EPC.saved.unitFrameAlpha or 0.94) * 100) end,
            setFunc = function(v) EPC.saved.unitFrameAlpha = v / 100 if EPC.UnitFrames then EPC.UnitFrames:ApplyScalesAndAlpha() end end,
            default = math.floor((EPC.defaults.unitFrameAlpha or 0.94) * 100),
        },
        {
            type = "slider", name = "Target aura icons per type", min = 3, max = 6, step = 1,
            tooltip = "Compact target layout. Shows 3-6 prioritized buff icons and 3-6 prioritized debuff icons side-by-side. Extra effects are summarized as +N instead of expanding the frame.",
            getFunc = function() return math.max(3, math.min(6, tonumber(EPC.saved.targetAuraCount) or 5)) end,
            setFunc = function(v) EPC.saved.targetAuraCount = math.max(3, math.min(6, math.floor(v))) if EPC.UnitFrames then EPC.UnitFrames:RefreshTargetAuras(false) end end,
            default = EPC.defaults.targetAuraCount,
        },
        {
            type = "checkbox", name = "Auto-expand in interaction mode",
            tooltip = "If the suite is minimized when Suite interaction mode is entered, expand it automatically.",
            getFunc = function() return EPC.saved.autoExpandInteract ~= false end,
            setFunc = function(v) EPC.saved.autoExpandInteract = v == true end,
            default = EPC.defaults.autoExpandInteract,
        },
        {
            type = "dropdown", name = "Endgame suite focus",
            tooltip = "At level 50+, BUILD and ACTIVITY adapt to this goal. Auto detects questing, grouped dungeon/trial context, and support-role defaults; manual focus overrides it.",
            choices = { "Auto (context aware)", "DPS", "Gold", "XP / CP", "Gear", "Dungeons", "Trials", "Solo", "Questing" },
            choicesValues = { "AUTO", "DPS", "GOLD", "XP_CP", "GEAR", "DUNGEONS", "TRIALS", "SOLO", "QUESTING" },
            getFunc = function() return EPC.Endgame and EPC.Endgame:GetFocus() or (EPC.saved.coachFocus or "DPS") end,
            setFunc = function(v)
                if EPC.Endgame then EPC.Endgame:SetFocus(v) else EPC.saved.coachFocus = v end
            end,
            default = EPC.defaults.coachFocus,
        },
        {
            type = "dropdown", name = "Endgame gear preset",
            tooltip = "Chooses the content profile used by BEST ENDGAME. Current templates cover all seven classes for Damage, Tank, and Healer roles. AUTO uses the selected LFG role, and Combat role awareness can force a role profile.",
            choices = { "Trial / Endgame", "Single Target", "AoE / Trash", "Solo" },
            choicesValues = { "TRIAL", "SINGLE_TARGET", "AOE_TRASH", "SOLO" },
            getFunc = function()
                return EPC.GearOptimizer and select(1, EPC.GearOptimizer:GetPreset()) or (EPC.saved.gearOptimizerPreset or "TRIAL")
            end,
            setFunc = function(v)
                if EPC.GearOptimizer then EPC.GearOptimizer:SetPreset(v) else EPC.saved.gearOptimizerPreset = v end
                EPC:RequestRefresh("gear-endgame-preset")
            end,
            default = EPC.defaults.gearOptimizerPreset or "TRIAL",
        },
        {
            type = "header", name = "MAX POWER Build / Champion Points",
        },
        {
            type = "dropdown", name = "MAX POWER content target",
            tooltip = "Used by MAX POWER BUILD, MAX POWER CP, and MAX POWER ATTRIBUTES. Auto detects Infinite Archive, group size, PvP, and the Suite endgame focus. Manual choices force the optimizer to build for that content instead of using one generic setup.",
            choices = { "Auto / Current Content", "Trial / Boss", "Dungeon / Arena", "Infinite Archive", "Solo / Overland", "AoE / Trash", "PvP" },
            choicesValues = { "AUTO", "TRIAL_BOSS", "DUNGEON", "INFINITE_ARCHIVE", "SOLO", "AOE_TRASH", "PVP" },
            getFunc = function()
                return EPC.GearOptimizer and EPC.GearOptimizer.GetMaxPowerMode029174 and EPC.GearOptimizer:GetMaxPowerMode029174() or (EPC.saved.maxPowerContent or "AUTO")
            end,
            setFunc = function(v)
                if EPC.GearOptimizer and EPC.GearOptimizer.SetMaxPowerMode029174 then EPC.GearOptimizer:SetMaxPowerMode029174(v) else EPC.saved.maxPowerContent=v end
                EPC:RequestRefresh("max-power-content")
            end,
            default = EPC.defaults.maxPowerContent or "AUTO",
        },
        {
            type = "description",
            title = "How MAX POWER works",
            text = "The skill build starts from the Suite's curated class/role bars, then re-scores unlocked morphs, passives, and fallbacks from their live ESO descriptions for the selected content. Champion Points analyze that resulting bar (Direct / DoT / AoE / Single Target), role, content, and personal penetration need, then choose four slottables per discipline and spend points by marginal value instead of filling one generic star first.",
        },
        {
            type = "checkbox", name = "Intelligent Next Best Move",
            tooltip = "Combines role, build, gear, activities, combat history, and current context into one recommended next action on the BUILD tab.",
            getFunc = function() return EPC.saved.smartCoach ~= false end,
            setFunc = function(v) EPC.saved.smartCoach = v == true EPC:RequestRefresh("smart-coach") end,
            default = EPC.defaults.smartCoach,
        },
        {
            type = "header", name = "Target Build",
        },
        {
            type = "dropdown", name = "Target build profile",
            tooltip = "AUTO follows your current role/context. Manual profiles let the completion tracker judge your character against a stable role target.",
            choices = { "Auto", "Damage", "Healer", "Tank", "Solo" },
            choicesValues = { "AUTO", "DAMAGE", "HEALER", "TANK", "SOLO" },
            getFunc = function() return EPC.TargetBuild and EPC.TargetBuild:GetConfiguredProfile() or (EPC.saved.targetProfile or "AUTO") end,
            setFunc = function(v) if EPC.TargetBuild then EPC.TargetBuild:SetProfile(v) else EPC.saved.targetProfile=v end end,
            default = EPC.defaults.targetProfile,
        },
        {
            type = "editbox", name = "Target set 1",
            tooltip = "Optional exact set name. When filled, BUILD completion tracks how many pieces of this set are currently equipped.",
            getFunc = function() return EPC.saved.targetSet1 or "" end,
            setFunc = function(v) if EPC.TargetBuild then EPC.TargetBuild:SetTargetSet(1,v) else EPC.saved.targetSet1=v end end,
            default = EPC.defaults.targetSet1,
            width = "full",
        },
        {
            type = "editbox", name = "Target set 2",
            tooltip = "Optional second exact set name. Leave target-set fields blank to use generic two-complete-set readiness instead.",
            getFunc = function() return EPC.saved.targetSet2 or "" end,
            setFunc = function(v) if EPC.TargetBuild then EPC.TargetBuild:SetTargetSet(2,v) else EPC.saved.targetSet2=v end end,
            default = EPC.defaults.targetSet2,
            width = "full",
        },
        {
            type = "checkbox", name = "Target-loot alerts",
            tooltip = "When a newly looted backpack item belongs to one of your named target sets, print a TARGET KEEP notice in chat. The addon never locks, destroys, sells, or equips the item for you.",
            getFunc = function() return EPC.saved.targetLootAlerts ~= false end,
            setFunc = function(v) EPC.saved.targetLootAlerts = v == true end,
            default = EPC.defaults.targetLootAlerts,
        },
        {
            type = "header", name = "Built-in Bug Catcher",
        },
        {
            type = "description",
            title = "Suite error log",
            text = "Captures Lua errors, protected-function violations, and low-Lua-memory notices into ESO Adventurer Suite without replacing ESO's own error handler. Repeated identical errors are grouped together. Use /eastestall for the full safe Suite self-test with a copyable report, /easscan (or /easbugs scan) for a runtime addon health scan, /easbugs to list recent errors, or /easbugs last to print the full latest stack trace.",
        },
        {
            type = "checkbox", name = "Enable built-in Bug Catcher",
            getFunc = function() return EPC.saved.bugCatcherEnabled ~= false end,
            setFunc = function(v) EPC.saved.bugCatcherEnabled = v == true end,
            default = EPC.defaults.bugCatcherEnabled, width = "half",
        },
        {
            type = "checkbox", name = "Bug Catcher chat notice",
            tooltip = "Prints a short notice when an error is caught. Full stack traces are stored instead of spammed into chat automatically.",
            getFunc = function() return EPC.saved.bugCatcherNotifyChat ~= false end,
            setFunc = function(v) EPC.saved.bugCatcherNotifyChat = v == true end,
            default = EPC.defaults.bugCatcherNotifyChat, width = "half",
        },
        {
            type = "checkbox", name = "Suppress ESO Lua error popup",
            tooltip = "After the Bug Catcher records a live Lua error, ask ESO to close its standard error dialog. The error remains stored in the Suite and can be viewed with /easbugs last.",
            getFunc = function() return EPC.saved.bugCatcherSuppressPopup == true end,
            setFunc = function(v) EPC.saved.bugCatcherSuppressPopup = v == true end,
            default = EPC.defaults.bugCatcherSuppressPopup, width = "full",
        },
        {
            type = "slider", name = "Bug Catcher stored errors", min = 10, max = 100, step = 5,
            tooltip = "Maximum number of unique error records kept in SavedVariables. Duplicate occurrences are counted on the existing record.",
            getFunc = function() return tonumber(EPC.saved.bugCatcherMaxErrors) or 40 end,
            setFunc = function(v) EPC.saved.bugCatcherMaxErrors = tonumber(v) or 40 if EPC.BugCatcher then EPC.BugCatcher:TrimToLimit() end end,
            default = EPC.defaults.bugCatcherMaxErrors, width = "full",
        },
        {
            type = "button", name = "Show last caught error", buttonText = "Print Last Error",
            func = function() if EPC.BugCatcher then EPC.BugCatcher:PrintLast() end end,
            disabled = function() return not EPC.BugCatcher end, width = "half",
        },
        {
            type = "button", name = "Bug Catcher status", buttonText = "Print Bug Status",
            func = function() if EPC.BugCatcher then EPC:Print(EPC.BugCatcher:GetStatusText()) end end,
            disabled = function() return not EPC.BugCatcher end, width = "half",
        },
        {
            type = "button", name = "Clear Bug Catcher log", buttonText = "Clear Error Log",
            func = function() if EPC.BugCatcher then EPC.BugCatcher:Clear() EPC:Print("Bug Catcher log cleared.") end end,
            disabled = function() return not EPC.BugCatcher end, width = "full",
        },
        {
            type = "header", name = "Loadout Saver",
        },
        {
            type = "description",
            title = "Wardrobe-style setup manager",
            text = "Save gear, both skill bars, Champion Points, attributes and buff food into 16 setups per page. Create multiple pages for trials/raiding groups, bind pages to zones, assign raid-entry or current-boss setups, check missing gear, transfer setup gear at an open Bank, drag/drop gear/food/skills, and import/export setup codes. Assign Open / Close Loadout Saver and optional prebuff hotkeys under Controls > Keybindings > General > ESO Adventurer Suite.",
        },
        {
            type = "button", name = "Open Loadout Saver", buttonText = "Open Loadout Saver",
            tooltip = "Opens the exact same Loadout Saver UI used by its dedicated hotkey.",
            func = function() if EPC.LoadoutManager and EPC.LoadoutManager.Show then EPC.LoadoutManager:Show() end end,
            width = "full",
        },
        {
            type = "checkbox", name = "Auto-equip raid setups",
            tooltip = "When enabled, automatically selects the page bound to the current raid/trial zone and equips its raid-entry or current-boss setup. Disabled by default to avoid unexpected gear changes.",
            getFunc = function() return EPC.saved.loadoutAutoEquipRaids029272 == true end,
            setFunc = function(v) EPC.saved.loadoutAutoEquipRaids029272 = v == true if EPC.LoadoutManager then EPC.LoadoutManager:RefreshUI() end end,
            default = EPC.defaults.loadoutAutoEquipRaids029272, width = "half",
        },
        {
            type = "checkbox", name = "Use saved buff food",
            tooltip = "Uses the saved food/drink when a setup is loaded, if that item is in the backpack.",
            getFunc = function() return EPC.saved.loadoutEquipFood029272 ~= false end,
            setFunc = function(v) EPC.saved.loadoutEquipFood029272 = v == true end,
            default = EPC.defaults.loadoutEquipFood029272, width = "half",
        },
        {
            type = "checkbox", name = "Inventory setup markers",
            tooltip = "Marks Suite inventory-grid items that are referenced by any saved Loadout Saver setup.",
            getFunc = function() return EPC.saved.loadoutInventoryMarkers029272 ~= false end,
            setFunc = function(v) EPC.saved.loadoutInventoryMarkers029272 = v == true if EPC.LoadoutManager then EPC.LoadoutManager:RebuildGearIndex() end if EASInventoryGrid and EASInventoryGrid.Refresh then EASInventoryGrid:Refresh() end end,
            default = EPC.defaults.loadoutInventoryMarkers029272, width = "half",
        },
        {
            type = "checkbox", name = "Charge weapons on load",
            tooltip = "Uses the Suite maintenance engine to charge equipped weapons after loading a setup. Disabled by default.",
            getFunc = function() return EPC.saved.loadoutChargeWeapons029272 == true end,
            setFunc = function(v) EPC.saved.loadoutChargeWeapons029272 = v == true end,
            default = EPC.defaults.loadoutChargeWeapons029272, width = "half",
        },
        {
            type = "checkbox", name = "Repair armor on load",
            tooltip = "Uses the Suite maintenance engine to repair equipped armor after loading a setup. Disabled by default.",
            getFunc = function() return EPC.saved.loadoutRepairArmor029272 == true end,
            setFunc = function(v) EPC.saved.loadoutRepairArmor029272 = v == true end,
            default = EPC.defaults.loadoutRepairArmor029272, width = "half",
        },
        {
            type = "checkbox", name = "Refill saved poisons",
            tooltip = "When a saved equipped poison stack is exhausted, attempts to equip the matching saved poison from the backpack. Disabled by default.",
            getFunc = function() return EPC.saved.loadoutRefillPoisons029272 == true end,
            setFunc = function(v) EPC.saved.loadoutRefillPoisons029272 = v == true end,
            default = EPC.defaults.loadoutRefillPoisons029272, width = "half",
        },
        {
            type = "header", name = "Crafting & Learning Tools",
        },
        {
            type = "description",
            title = "Top-menu icons + hotkeys",
            text = "Crafting Assistant and Turbo Learner both have their own ESO top-menu icon and their own Open / Close hotkey. Assign them under Controls > Keybindings > General > ESO Adventurer Suite. The same assigned key closes the tool and returns you to gameplay while that tool has UI focus.",
        },
        {
            type = "header", name = "Crafting Material Hunt",
        },
        {
            type = "description",
            text = "One combined Map + 3D source finder for Alchemy, Provisioning, and Enchanting. Provisioning pins mark possible sources, not guaranteed unopened-container contents. The Suite learns containers that actually yielded provisioning ingredients and reuses those locations later.",
            width = "full",
        },
        {
            type = "checkbox", name = "Show Material Hunt bar in crafting windows",
            tooltip = "Shows the shared Material Hunt controls inside Crafting Assistant and while interacting with Alchemy, Provisioning, Enchanting, Jewelry, Woodworking, Blacksmithing, and Clothing stations.",
            getFunc = function() return EPC.saved.craftingMaterialHuntBarEnabled029765 ~= false end,
            setFunc = function(v)
                EPC.saved.craftingMaterialHuntBarEnabled029765 = v == true
                if EPC.CraftingMaterialHunt and EPC.CraftingMaterialHunt.SetBarsEnabled029765 then
                    EPC.CraftingMaterialHunt:SetBarsEnabled029765(v == true)
                end
            end,
            default = EPC.defaults.craftingMaterialHuntBarEnabled029765 ~= false,
            width = "full",
        },
        {
            type = "dropdown", name = "Material hunt type",
            choices = { "Alchemy", "Provisioning", "Enchanting", "Jewelry", "Woodworking", "Blacksmithing", "Clothing" },
            choicesValues = { "ALCHEMY", "PROVISIONING", "ENCHANTING", "JEWELRY", "WOODWORKING", "BLACKSMITHING", "CLOTHING" },
            getFunc = function() return EPC.saved.craftingMaterialHuntType029763 or "PROVISIONING" end,
            setFunc = function(v) EPC.saved.craftingMaterialHuntType029763 = v or "PROVISIONING" end,
            default = EPC.defaults.craftingMaterialHuntType029763 or "PROVISIONING",
            width = "full",
        },
        {
            type = "button", name = "Start Map + 3D material hunt", buttonText = "Start Hunt",
            tooltip = "Marks possible sources on the world map and with 3D hunt pins. Alchemy uses reagent/solvent nodes, Provisioning uses learned food containers plus known possible sources, Enchanting uses runestones, Jewelry/Blacksmithing use ore and seam sources, Woodworking uses wood nodes, and Clothing uses cloth/fiber nodes.",
            func = function()
                if EPC.CraftingMaterialHunt and EPC.CraftingMaterialHunt.Start029763 then
                    EPC.CraftingMaterialHunt:Start029763(EPC.saved.craftingMaterialHuntType029763, true)
                end
            end,
            width = "half",
        },
        {
            type = "button", name = "Stop material hunt", buttonText = "Stop Hunt",
            func = function()
                if EPC.CraftingMaterialHunt and EPC.CraftingMaterialHunt.Stop029763 then EPC.CraftingMaterialHunt:Stop029763() end
            end,
            width = "half",
        },
        {
            type = "header", name = "Turbo Learner",
        },
        {
            type = "description",
            title = "Turbo Learner access",
            text = "Open Turbo Learner from its top-menu icon, the button below, or the Open / Close Turbo Learner hotkey. It previews every unknown recipe, furnishing plan/blueprint, motif, and style page the Suite can learn. Nothing is consumed until you explicitly press LEARN ALL. ESO protected item-use calls are used out of combat; Bank items are included only while a Bank is actually open and can be moved one at a time into an empty backpack slot before learning.",
        },
        {
            type = "checkbox", name = "Enable Turbo Learner",
            tooltip = "Enables the Turbo Learner top-menu icon, hotkey, preview page, and LEARN ALL workflow.",
            getFunc = function() return EPC.saved.recipeStyleLearnerEnabled ~= false end,
            setFunc = function(v) EPC.saved.recipeStyleLearnerEnabled = v == true if EPC.RecipeStyleLearner then EPC.RecipeStyleLearner:RefreshVisibility() end end,
            default = EPC.defaults.recipeStyleLearnerEnabled,
        },
        {
            type = "checkbox", name = "Include Bank items",
            tooltip = "While the Bank is open, queue unknown learnable items from the normal and ESO Plus bank. One empty backpack slot is required to learn bank items.",
            getFunc = function() return EPC.saved.recipeStyleLearnerIncludeBank ~= false end,
            setFunc = function(v) EPC.saved.recipeStyleLearnerIncludeBank = v == true if EPC.RecipeStyleLearner then EPC.RecipeStyleLearner:RefreshStatus() end end,
            default = EPC.defaults.recipeStyleLearnerIncludeBank,
            width = "half",
        },
        {
            type = "checkbox", name = "Suppress learning popups",
            tooltip = "Temporarily hides center-screen learning announcement surfaces while Turbo Mode is running, then restores their previous visibility state.",
            getFunc = function() return EPC.saved.recipeStyleLearnerSuppressPopups ~= false end,
            setFunc = function(v) EPC.saved.recipeStyleLearnerSuppressPopups = v == true end,
            default = EPC.defaults.recipeStyleLearnerSuppressPopups,
            width = "half",
        },
        {
            type = "button", name = "Open Turbo Learner", buttonText = "Open Turbo Learner",
            tooltip = "Opens the same Turbo Learner page as the top-menu icon so you can review the learnable list before pressing LEARN ALL.",
            func = function() if EPC.RecipeStyleLearner and EPC.RecipeStyleLearner.OpenMainMenuPage then EPC.RecipeStyleLearner:OpenMainMenuPage() end end,
            disabled = function() return not EPC.RecipeStyleLearner or EPC.saved.recipeStyleLearnerEnabled == false end,
            width = "full",
        },
        {
            type = "header", name = "Crafting Assistant",
        },
        {
            type = "description",
            title = "Crafting Assistant access",
            text = "Open Crafting Assistant from its top-menu icon, the button below, or the Open / Close Crafting Assistant hotkey. It can be used anywhere as a recipe planner; loading or crafting ingredients still requires an active Alchemy Station. The optional station potion icon remains available while crafting and can be positioned through ESO Edit HUD.",
        },
        {
            type = "checkbox", name = "Enable Crafting Assistant",
            tooltip = "Enables the Crafting Assistant top-menu icon, hotkey, recipe planner, and the optional station icon shown while using an Alchemy Station.",
            getFunc = function() return EPC.saved.alchemyPotionMakerEnabled ~= false end,
            setFunc = function(v) EPC.saved.alchemyPotionMakerEnabled = v == true if EPC.AlchemyPotionMaker then EPC.AlchemyPotionMaker:RefreshVisibility() end end,
            default = EPC.defaults.alchemyPotionMakerEnabled,
        },
        {
            type = "dropdown", name = "Default mixture type",
            tooltip = "Choose whether the maker looks for potion solvents or poison solvents.",
            choices = { "Potion", "Poison" },
            choicesValues = { "POTION", "POISON" },
            getFunc = function() return EPC.saved.alchemyPotionMakerMode or "POTION" end,
            setFunc = function(v) EPC.saved.alchemyPotionMakerMode = v == "POISON" and "POISON" or "POTION" if EPC.AlchemyPotionMaker then EPC.AlchemyPotionMaker:SetMode(EPC.saved.alchemyPotionMakerMode) end end,
            default = EPC.defaults.alchemyPotionMakerMode,
            width = "half",
        },
        {
            type = "checkbox", name = "Use third reagent when unlocked",
            tooltip = "Includes three-reagent mixtures when the character has the Alchemy Laboratory Use passive. Disable this to search two-reagent mixtures only.",
            getFunc = function() return EPC.saved.alchemyPotionMakerUseThreeReagents ~= false end,
            setFunc = function(v) EPC.saved.alchemyPotionMakerUseThreeReagents = v == true if EPC.AlchemyPotionMaker then EPC.AlchemyPotionMaker:RefreshWindow(true) end end,
            default = EPC.defaults.alchemyPotionMakerUseThreeReagents,
            width = "half",
        },
        {
            type = "checkbox", name = "Auto Craft after loading ingredients",
            tooltip = "OFF by default. When enabled, clicking a READY mixture loads the selected solvent/reagents and immediately starts ESO Alchemy crafting using the amount below.",
            getFunc = function() return EPC.saved.alchemyPotionMakerAutoCraft == true end,
            setFunc = function(v) EPC.saved.alchemyPotionMakerAutoCraft = v == true if EPC.AlchemyPotionMaker then EPC.AlchemyPotionMaker:RefreshWindow(false) end end,
            default = EPC.defaults.alchemyPotionMakerAutoCraft,
            width = "half",
        },
        {
            type = "dropdown", name = "Auto Craft amount",
            tooltip = "Craft 1 makes one Alchemy iteration. Craft X uses the custom quantity below. Craft Maximum uses every complete set of the selected ingredients currently available.",
            choices = { "Craft 1", "Craft X", "Craft Maximum" },
            choicesValues = { "ONE", "CUSTOM", "MAX" },
            getFunc = function() return EPC.saved.alchemyPotionMakerAutoCraftMode or "ONE" end,
            setFunc = function(v) EPC.saved.alchemyPotionMakerAutoCraftMode = (v == "MAX" or v == "CUSTOM") and v or "ONE" if EPC.AlchemyPotionMaker then EPC.AlchemyPotionMaker:RefreshWindow(false) end end,
            default = EPC.defaults.alchemyPotionMakerAutoCraftMode,
            width = "half",
        },
        {
            type = "slider", name = "Craft X quantity",
            tooltip = "Number of Alchemy iterations to request when Auto Craft amount is set to Craft X. The Suite automatically clamps this to the maximum your current materials can make.",
            min = 1, max = 100, step = 1,
            getFunc = function() return math.max(1, math.floor(tonumber(EPC.saved.alchemyPotionMakerAutoCraftQuantity) or 1)) end,
            setFunc = function(v) EPC.saved.alchemyPotionMakerAutoCraftQuantity = math.max(1, math.floor(tonumber(v) or 1)) if EPC.AlchemyPotionMaker then EPC.AlchemyPotionMaker:RefreshWindow(false) end end,
            default = EPC.defaults.alchemyPotionMakerAutoCraftQuantity,
            width = "half",
        },
        {
            type = "description",
            title = "Auto Craft safety",
            text = "Auto Craft only starts after ESO accepts the selected solvent and reagents and reports at least one Alchemy iteration possible. Craft Maximum can consume all complete sets of those selected materials, so leave Auto Craft OFF when you only want ingredient preparation.",
            width = "half",
        },
        {
            type = "checkbox", name = "Include Bank Alchemy materials",
            tooltip = "Includes reagents and solvents stored in your normal/subscriber bank when calculating what you can make. ESO crafting stations can normally draw crafting materials from the bank.",
            getFunc = function() return EPC.saved.alchemyPotionMakerIncludeBank ~= false end,
            setFunc = function(v) EPC.saved.alchemyPotionMakerIncludeBank = v == true if EPC.AlchemyPotionMaker then EPC.AlchemyPotionMaker:ScheduleRefresh(100) end end,
            default = EPC.defaults.alchemyPotionMakerIncludeBank,
            width = "half",
        },
        {
            type = "checkbox", name = "Include Craft Bag Alchemy materials",
            tooltip = "Includes ESO Plus Craft Bag reagents and solvents when calculating and preparing mixtures.",
            getFunc = function() return EPC.saved.alchemyPotionMakerIncludeCraftBag ~= false end,
            setFunc = function(v) EPC.saved.alchemyPotionMakerIncludeCraftBag = v == true if EPC.AlchemyPotionMaker then EPC.AlchemyPotionMaker:ScheduleRefresh(100) end end,
            default = EPC.defaults.alchemyPotionMakerIncludeCraftBag,
            width = "half",
        },
        {
            type = "button", name = "Open Crafting Assistant", buttonText = "Open Crafting Assistant",
            tooltip = "Opens the same Crafting Assistant page as the top-menu icon and hotkey. Planning works anywhere; loading/crafting requires an Alchemy Station.",
            func = function() if EPC.AlchemyPotionMaker and EPC.AlchemyPotionMaker.ToggleMainMenuPage then EPC.AlchemyPotionMaker:ToggleMainMenuPage() end end,
            disabled = function() return not EPC.AlchemyPotionMaker or EPC.saved.alchemyPotionMakerEnabled == false end,
            width = "half",
        },
        {
            type = "button", name = "Reset Alchemy Maker position", buttonText = "Reset Potion Icon",
            tooltip = "Resets both the floating potion icon and the Alchemy Maker window to their default positions.",
            func = function() if EPC.AlchemyPotionMaker then EPC.AlchemyPotionMaker:ResetPosition() end end,
            disabled = function() return not EPC.AlchemyPotionMaker end,
            width = "half",
        },
        {
            type = "header", name = "Utility Command Center",
        },
        {
            type = "dropdown", name = "Default utility view",
            tooltip = "The TOOLS tab combines Inventory, Research, Collections, and Dailies. Overview summarizes the highest-value signals from all four.",
            choices = { "Overview", "Inventory", "Research", "Collections", "Dailies" },
            choicesValues = { "OVERVIEW", "INVENTORY", "RESEARCH", "COLLECTIONS", "DAILIES" },
            getFunc = function() return EPC.UtilitySuite and EPC.UtilitySuite:GetMode() or (EPC.saved.utilityMode or "OVERVIEW") end,
            setFunc = function(v) if EPC.UtilitySuite then EPC.UtilitySuite:SetMode(v) else EPC.saved.utilityMode = v EPC:RequestRefresh("utility-mode") end end,
            default = EPC.defaults.utilityMode,
        },
        {
            type = "checkbox", name = "Smart loot / research / collection alerts",
            tooltip = "For newly looted backpack items, print a notice when the item matches a named Target Set, can teach an unknown trait, or is an uncollected Sticker Book piece. No inventory action is performed automatically.",
            getFunc = function() return EPC.saved.utilityLootAlerts ~= false end,
            setFunc = function(v) EPC.saved.utilityLootAlerts = v == true end,
            default = EPC.defaults.utilityLootAlerts,
        },
        {
            type = "checkbox", name = "Remember account inventory snapshots",
            tooltip = "Stores compact item-name/count snapshots for each character that loads the addon plus the bank when accessible. Use /esosuite find <item name> to locate saved matches across those snapshots.",
            getFunc = function() return EPC.saved.utilityInventoryTracking ~= false end,
            setFunc = function(v) EPC.saved.utilityInventoryTracking = v == true end,
            default = EPC.defaults.utilityInventoryTracking,
        },
        {
            type = "description",
            title = "Inventory search",
            text = "Use /esosuite scan to refresh the current inventory snapshot, then /esosuite find <item name> to search saved character and bank snapshots. Bank results are only as current as the last scan made while bank data was available.",
        },
        {
            type = "dropdown", name = "Session planner mode",
            tooltip = "Continuous never expires. Timed plans organize the selected window, then the suite automatically returns to continuous guidance instead of stopping.",
            choices = { "Continuous", "30 minutes", "60 minutes", "120 minutes", "Custom" },
            choicesValues = { "CONTINUOUS", "30", "60", "120", "CUSTOM" },
            getFunc = function()
                if not EPC.Advisor then return "CONTINUOUS" end
                local mode = EPC.Advisor:GetSessionMode()
                if mode == "CONTINUOUS" or mode == "CUSTOM" then return mode end
                return tostring(EPC.Advisor:GetSessionMinutes())
            end,
            setFunc = function(v)
                if not EPC.Advisor then return end
                if v == "CONTINUOUS" or v == "CUSTOM" then EPC.Advisor:SetSessionMode(v)
                else EPC.Advisor:SetSessionMinutes(tonumber(v) or 60) end
            end,
            default = "CONTINUOUS",
        },
        {
            type = "slider", name = "Custom session length", min = 15, max = 240, step = 5,
            tooltip = "Used by the CUSTOM button in ACTIVITY. Changing it while Custom is active restarts the plan with the new duration.",
            getFunc = function() return EPC.Advisor and EPC.Advisor:GetCustomSessionMinutes() or 90 end,
            setFunc = function(v) if EPC.Advisor then EPC.Advisor:SetCustomSessionMinutes(v) end end,
            default = EPC.defaults.sessionCustomMinutes,
        },
        {
            type = "dropdown", name = "Activity planner goal",
            tooltip = "Choose how the Activity tab ranks visible quests and repeatable activities.",
            choices = { "Balanced", "XP", "Gold" },
            choicesValues = { "BALANCED", "XP", "GOLD" },
            getFunc = function() return EPC.saved.activityGoal or "BALANCED" end,
            setFunc = function(v)
                if EPC.Activities then EPC.Activities:SetGoal(v) else EPC.saved.activityGoal = v end
            end,
            default = EPC.defaults.activityGoal,
        },
        {
            type = "checkbox", name = "Lock window",
            getFunc = function() return EPC.saved.locked end,
            setFunc = function(v) EPC.saved.locked = v EPC.UI:ApplyInteractionState() end,
            default = EPC.defaults.locked,
        },
        {
            type = "checkbox", name = "Show recommendation reasons",
            getFunc = function() return EPC.saved.showReasons end,
            setFunc = function(v) EPC.saved.showReasons = v EPC:RequestRefresh("settings") end,
            default = EPC.defaults.showReasons,
        },
        {
            type = "slider", name = "Window opacity", min = 35, max = 100, step = 1,
            tooltip = "Changes the opacity of the visible ESO Adventurer Suite window, including the modern Codex interface.",
            getFunc = function() return math.floor((tonumber(EPC.saved.alpha) or EPC.defaults.alpha or 0.96) * 100) end,
            setFunc = function(v)
                EPC.saved.alpha = (tonumber(v) or 96) / 100
                if EPC.UI and EPC.UI.root and EPC.UI.root.SetAlpha then EPC.UI.root:SetAlpha(EPC.saved.alpha) end
                if EPC.ModernAppUI and EPC.ModernAppUI.ApplyWindowAppearance029363 then EPC.ModernAppUI:ApplyWindowAppearance029363() end
            end,
            default = math.floor(EPC.defaults.alpha * 100),
        },
        {
            type = "slider", name = "Window scale", min = 70, max = 140, step = 5,
            tooltip = "Scales the visible ESO Adventurer Suite window. This now applies to the modern Codex window as well as the legacy UI root.",
            getFunc = function() return math.floor((tonumber(EPC.saved.scale) or EPC.defaults.scale or 1.0) * 100) end,
            setFunc = function(v)
                EPC.saved.scale = (tonumber(v) or 100) / 100
                -- v0.29.376: the modern application is a separate top-level.
                -- Scaling the retired legacy root at the same time could distort
                -- hit regions/anchors when moving between Codex tabs.
                if EPC.ModernAppUI and EPC.ModernAppUI.ApplyWindowAppearance029363 then EPC.ModernAppUI:ApplyWindowAppearance029363() end
            end,
            default = math.floor(EPC.defaults.scale * 100),
        },
        {
            type = "slider", name = "Codex text size", min = 14, max = 28, step = 1,
            tooltip = "Changes Crafting Codex body text size. The page automatically re-wraps and repaginates so larger text remains readable.",
            getFunc = function() return tonumber(EPC.saved.codexModernFontSize029363) or 18 end,
            setFunc = function(v)
                EPC.saved.codexModernFontSize029363 = tonumber(v) or 18
                if EPC.ModernAppUI and EPC.ModernAppUI.ApplyCodexTextSize029363 then EPC.ModernAppUI:ApplyCodexTextSize029363() end
            end,
            default = EPC.defaults.codexModernFontSize029363 or 18,
        },
        {
            type = "button", name = "Clear last combat sample", buttonText = "Clear",
            func = function() if EPC.Combat then EPC.Combat:ResetLastFight() end end,
        },
        {
            type = "button", name = "Reset overlay position", buttonText = "Reset",
            func = function() EPC.UI:ResetPosition() end,
        },
    }

    -- v0.29.298: Rebuilt the Settings menu around clear feature categories.
    -- Existing getters, setters, defaults, and saved-variable keys are preserved;
    -- this block only changes presentation and makes information text full-width.
    local categoryOrder = {
        "GENERAL",
        "CODEX",
        "COMBAT",
        "BUILDS",
        "DIFFICULTY",
        "ACTIVITIES",
        "HUD",
        "QUESTS",
        "CONTROLLER",
        "ACTIONBARS",
        "FRAMES",
        "MAP",
        "PINS",
        "TRAVEL",
        "GROUP",
        "GEAR",
        "ANTIQUITIES",
        "CRAFTING",
        "UTILITIES",
    }

    local categoryInfo = {
        GENERAL = {
            name = "General & Help",
            tooltip = "Master Suite controls, compatibility status, and getting-started information.",
            intro = "Start here for the Suite master switch, compatibility information, and basic help. Feature-specific options are kept in their own sections so this page stays easy to scan.",
        },
        CODEX = {
            name = "Tamriel Codex & Main Window",
            tooltip = "Codex access, main Suite window behavior, appearance, and interaction controls.",
            intro = "Controls for opening and using the Tamriel Codex, plus the main Suite window's interaction, opacity, scale, and position behavior.",
        },
        COMBAT = {
            name = "Combat",
            tooltip = "Combat Advisor, Combat Stats, Combat HUD, Boss Mechanics, reports, reminders, and combat visibility.",
            intro = "Combat features are separated below by exact owner so Combat Stats, Combat HUD, Boss Mechanics, Advisor, and reminders no longer share one long mixed list.",
        },
        BUILDS = {
            name = "Builds & Loadouts",
            tooltip = "MAX POWER, Target Build, endgame presets, Champion Point guidance, and saved loadouts.",
            intro = "Use this section for build goals and setup management, including MAX POWER, target sets, endgame presets, Champion Point guidance, and saved loadouts.",
        },
        DIFFICULTY = {
            name = "Gameplay & Difficulty",
            tooltip = "Automatic Challenge Difficulty, Leveling Journey, world activity rules, and zone overrides.",
            intro = "Controls ESO's native Challenge Difficulty behavior for overland content, activities, companions, and per-zone overrides.",
        },
        ACTIVITIES = {
            name = "Activities & Group Finder",
            tooltip = "Group Finder filters, Infinite Archive assistance, activity planning, and session goals.",
            intro = "Settings for finding groups and planning activities, including listing filters, Infinite Archive guidance, activity goals, and timed or continuous play sessions.",
        },
        HUD = {
            name = "General HUD & Utility Overlays",
            tooltip = "Performance meter, stable timer, clock, custom reticle, and other general-purpose HUD utilities.",
            intro = "General HUD tools that are not tied to a specific combat, quest, gear, or action-bar feature are kept here, including performance, stable, clock, and reticle controls.",
        },
        QUESTS = {
            name = "Quest & Progress Overlays",
            tooltip = "Quest tracking, active quest, Golden Pursuits, Alliance Rank, and Level/Champion progress overlays.",
            intro = "Everything related to quest and progression information on the HUD is grouped here, with visibility, sizing, and reset controls kept beside each overlay.",
        },
        CONTROLLER = {
            name = "Controller / Gamepad",
            tooltip = "ESO Automatic, Gamepad UI, hybrid keyboard UI + controller controls, and Suite controller button symbols.",
            intro = "Choose how ESO presents its interface when using a controller and which native controller glyphs the Suite should show. This section does not poll the controller or replace ESO input.",
        },
        ACTIONBARS = {
            name = "Action Bars, Abilities & Quickslots",
            tooltip = "Dual Action Bar, ability overlays, and quickslot display.",
            intro = "Controls for combat buttons and input prompts: controller/keyboard UI behavior, native controller glyphs, Dual Action Bar, ability overlays, and quickslots.",
        },
        FRAMES = {
            name = "Unit Frames",
            tooltip = "Player, target, group, raid, recovery ticks, and frame appearance.",
            intro = "Only Player, Target, Group/Raid, and recovery-tick settings live here. Combat Stats and ESO-native HUD tools are kept in their own feature sections.",
        },
        MAP = {
            name = "Mini Map",
            tooltip = "Mini Map visibility, style, adaptive zoom, size, opacity, icon layers, and position controls.",
            intro = "All Mini Map display and behavior settings are together here: style, adaptive zoom, icon size, opacity, map layers, movement guidance, and HUD position controls.",
        },
        PINS = {
            name = "Pins, Resources & Collectibles",
            tooltip = "Resource pins, lore books, treasure/survey markers, chest markers, Farm Focus, and marker appearance.",
            intro = "Location-marker features are grouped here, including resource gathering, Farm Focus, lore books, treasure/survey locations, and dungeon/trial chest or Heavy Sack guidance.",
        },
        TRAVEL = {
            name = "Travel & Teleporter",
            tooltip = "World Map Teleporter, wayshrine behavior, travel filtering, sorting, and travel messages.",
            intro = "Travel-specific controls, including the World Map Teleporter and optional wayshrine messages, are grouped here instead of being mixed into Mini Map or marker settings.",
        },
        GROUP = {
            name = "Group, Team & Loot",
            tooltip = "Team Visibility, companion/group glow, per-player overrides, and Group Loot Notifier.",
            intro = "Group-facing features live here: teammate/companion visibility controls and the Group Loot Notifier with its loot filters, chat formatting, and session history.",
        },
        GEAR = {
            name = "Gear & Maintenance",
            tooltip = "Character Gear Screen, equipment presentation, repair/recharge estimate, and automatic equipment maintenance.",
            intro = "Equipment display and upkeep are grouped here: the Character Gear Screen, companion equipment view, repair/recharge estimates, condition thresholds, weapon charge, and automatic maintenance.",
        },
        ANTIQUITIES = {
            name = "Antiquities & Lead Finder",
            tooltip = "Dig-site navigation, shovel markers, Augur/bonus-loot assistance, learned dig locations, and Lead Finder.",
            intro = "All Scrying and Excavation assistance is kept together here, including dig-site markers, learned exact spawns, Augur help, bonus-loot guidance, and the Lead Finder.",
        },
        CRAFTING = {
            name = "Crafting & Learning",
            tooltip = "Turbo Learner, Crafting Assistant, crafting access, material sources, and learning options.",
            intro = "Crafting and knowledge tools live here, including Turbo Learner and the Crafting Assistant with their material and safety options.",
        },
        UTILITIES = {
            name = "Utilities & Diagnostics",
            tooltip = "Bug Catcher, inventory snapshots, loot/research alerts, search tools, and the Utility Command Center.",
            intro = "Maintenance and diagnostic tools that do not belong to a gameplay feature are grouped here, including Bug Catcher, inventory snapshots, alerts, and inventory search.",
        },
    }

    -- v0.29.786: Exact feature ownership inside each broad category.
    -- The old category pass flattened many unrelated features together. These
    -- nested submenus keep every setting beside the feature that owns it.
    local featureInfo = {
        GENERAL_CORE = { category="GENERAL", name="Suite Core" },
        CODEX_MAIN = { category="CODEX", name="Tamriel Codex / Main Window" },

        COMBAT_ADVISOR = { category="COMBAT", name="Smart Combat Advisor" },
        COMBAT_BOSS = { category="COMBAT", name="Boss Mechanics Coach" },
        COMBAT_HUD = { category="COMBAT", name="Combat HUD" },
        COMBAT_STATS = { category="COMBAT", name="Combat Stats & Reports" },
        COMBAT_REMINDERS = { category="COMBAT", name="Pre-Encounter Reminders" },
        COMBAT_VISIBILITY = { category="COMBAT", name="World Combat Visibility" },

        BUILDS_MAXPOWER = { category="BUILDS", name="MAX POWER / Endgame" },
        BUILDS_TARGET = { category="BUILDS", name="Target Build" },
        BUILDS_LOADOUTS = { category="BUILDS", name="Loadout Saver" },

        DIFFICULTY_MAIN = { category="DIFFICULTY", name="Challenge Difficulty" },

        ACTIVITIES_GROUPFINDER = { category="ACTIVITIES", name="Dungeon / Group Finder" },
        ACTIVITIES_ARCHIVE = { category="ACTIVITIES", name="Infinite Archive" },
        ACTIVITIES_PLANNER = { category="ACTIVITIES", name="Activity / Session Planner" },

        HUD_PERFORMANCE = { category="HUD", name="FPS / Latency Overlay" },
        HUD_EDGE = { category="HUD", name="Screen Edge Info Bar" },
        HUD_STABLE = { category="HUD", name="Stable Training Timer" },
        HUD_CLOCK = { category="HUD", name="Clock" },
        HUD_RETICLE = { category="HUD", name="Custom Reticle" },
        HUD_NATIVE = { category="HUD", name="ESO Native HUD & Edit HUD" },

        QUEST_SOURCE = { category="QUESTS", name="Quest Tracking" },
        QUEST_ACTIVE = { category="QUESTS", name="Active Quest Overlay" },
        QUEST_PURSUITS = { category="QUESTS", name="Golden Pursuits Overlay" },
        QUEST_ALLIANCE = { category="QUESTS", name="Alliance Rank Overlay" },
        QUEST_LEVEL = { category="QUESTS", name="Level / Champion Overlay" },

        CONTROLLER_MAIN = { category="CONTROLLER", name="Controller / Gamepad" },

        ACTION_DUAL = { category="ACTIONBARS", name="Dual Action Bar" },
        ACTION_ABILITIES = { category="ACTIONBARS", name="Ability Overlays" },
        ACTION_QUICKSLOT = { category="ACTIONBARS", name="Quickslot Overlay" },

        FRAMES_MAIN = { category="FRAMES", name="Player / Target / Group / Raid Frames" },
        FRAMES_TICKS = { category="FRAMES", name="Player Recovery Tick Tracker" },
        
        MAP_MINIMAP = { category="MAP", name="Mini Map" },

        PINS_LORE = { category="PINS", name="Lore Books" },
        PINS_CHESTS = { category="PINS", name="Dungeon / Trial Chest Finder" },
        PINS_RESOURCES = { category="PINS", name="Resource Pins" },
        PINS_ICONS = { category="PINS", name="Resource Pin Icons" },
        PINS_FARM = { category="PINS", name="Farm Focus" },
        PINS_FILTERS = { category="PINS", name="Normal Resource Filters" },
        PINS_TREASURE = { category="PINS", name="Treasure & Survey Locator" },

        TRAVEL_TELEPORTER = { category="TRAVEL", name="World Map Teleporter" },
        TRAVEL_MESSAGE = { category="TRAVEL", name="Wayshrine Auto Message" },

        GROUP_TEAM = { category="GROUP", name="Team Visibility" },
        GROUP_COMPANION = { category="GROUP", name="Companion Glow" },
        GROUP_DEFAULT = { category="GROUP", name="Group Default Glow" },
        GROUP_PLAYER = { category="GROUP", name="Per-Player Group Glow" },

        GEAR_INVENTORY = { category="GEAR", name="Inventory Grid Categories" },
        GEAR_CHARACTER = { category="GEAR", name="Character / Companion Gear Screen" },
        GEAR_MAINTENANCE = { category="GEAR", name="Automatic Equipment Maintenance" },
        GEAR_REPAIR = { category="GEAR", name="Repair / Recharge Overlay" },

        ANTIQUITY_ASSIST = { category="ANTIQUITIES", name="Antiquity Assistant" },
        ANTIQUITY_LEADS = { category="ANTIQUITIES", name="Lead Finder / Excavation" },

        CRAFTING_MAIN = { category="CRAFTING", name="Crafting & Learning" },
        CRAFTING_HUNT = { category="CRAFTING", name="Crafting Material Hunt" },
        CRAFTING_LEARNER = { category="CRAFTING", name="Turbo Learner" },
        CRAFTING_ASSIST = { category="CRAFTING", name="Crafting Assistant" },

        UTIL_BUGS = { category="UTILITIES", name="Built-in Bug Catcher" },
        UTIL_COMMAND = { category="UTILITIES", name="Utility Command Center" },
    }

    local defaultFeatureByCategory = {
        GENERAL="GENERAL_CORE", CODEX="CODEX_MAIN", COMBAT="COMBAT_ADVISOR",
        BUILDS="BUILDS_MAXPOWER", DIFFICULTY="DIFFICULTY_MAIN",
        ACTIVITIES="ACTIVITIES_GROUPFINDER", HUD="HUD_PERFORMANCE",
        QUESTS="QUEST_SOURCE", CONTROLLER="CONTROLLER_MAIN",
        ACTIONBARS="ACTION_DUAL", FRAMES="FRAMES_MAIN", MAP="MAP_MINIMAP",
        PINS="PINS_RESOURCES", TRAVEL="TRAVEL_TELEPORTER", GROUP="GROUP_TEAM",
        GEAR="GEAR_CHARACTER", ANTIQUITIES="ANTIQUITY_ASSIST",
        CRAFTING="CRAFTING_MAIN", UTILITIES="UTIL_COMMAND",
    }

    local headerFeature = {
        ["Boss Mechanics Coach"]="COMBAT_BOSS",
        ["Gameplay & Challenge Difficulty"]="DIFFICULTY_MAIN",
        ["Live Group Finder"]="ACTIVITIES_GROUPFINDER",
        ["Game Mode Combat Report"]="COMBAT_STATS",
        ["Inventory Grid Categories"]="GEAR_INVENTORY",
        ["Character Gear Screen"]="GEAR_CHARACTER",
        ["Automatic Equipment Maintenance"]="GEAR_MAINTENANCE",
        ["Repair / Recharge Estimate Overlay"]="GEAR_REPAIR",
        ["Suite FPS / Latency Overlay"]="HUD_PERFORMANCE",
        ["Screen Edge Info Bar"]="HUD_EDGE",
        ["Pre-Encounter Reminders"]="COMBAT_REMINDERS",
        ["Lore Book Locations"]="PINS_LORE",
        ["Dungeon / Trial Chest Finder"]="PINS_CHESTS",
        ["Antiquity Assistant"]="ANTIQUITY_ASSIST",
        ["Antiquity Lead Finder"]="ANTIQUITY_LEADS",
        ["Suite Resource Pins"]="PINS_RESOURCES",
        ["Resource Pin Icon Replacer"]="PINS_ICONS",
        ["Farm Focus"]="PINS_FARM",
        ["Normal Resource Pin Filters"]="PINS_FILTERS",
        ["Team Visibility"]="GROUP_TEAM",
        ["Companion Glow"]="GROUP_COMPANION",
        ["Group Default Glow"]="GROUP_DEFAULT",
        ["Per-Player Group Glow"]="GROUP_PLAYER",
        ["World Combat Visibility"]="COMBAT_VISIBILITY",
        ["Persistent HUD & Unit Frames"]="FRAMES_MAIN",
        ["Stable Training Timer"]="HUD_STABLE",
        ["Clock"]="HUD_CLOCK",
        ["Quest Tracking"]="QUEST_SOURCE",
        ["Active Quest Overlay"]="QUEST_ACTIVE",
        ["Golden Pursuits Overlay"]="QUEST_PURSUITS",
        ["Alliance Rank Overlay"]="QUEST_ALLIANCE",
        ["Character Level / Champion Progress Overlay"]="QUEST_LEVEL",
        ["Controller / Gamepad"]="CONTROLLER_MAIN",
        ["Dual Action Bar HUD"]="ACTION_DUAL",
        ["Player Frame Recovery Ticks"]="FRAMES_TICKS",
        ["Ability Overlays"]="ACTION_ABILITIES",
        ["Quickslot Overlay"]="ACTION_QUICKSLOT",
        ["Infinite Archive Overlay"]="ACTIVITIES_ARCHIVE",
        ["Custom ESO Reticle"]="HUD_RETICLE",
        ["Tamriel Codex"]="CODEX_MAIN",
        ["Unit Frame Designs"]="FRAMES_MAIN",
        ["World Map Teleporter"]="TRAVEL_TELEPORTER",
        ["Wayshrine Auto Message"]="TRAVEL_MESSAGE",
        ["Treasure & Survey Locator"]="PINS_TREASURE",
        ["Mini Map"]="MAP_MINIMAP",
        ["ESO Native Loot History & Chat"]="HUD_NATIVE",
        ["MAX POWER Build / Champion Points"]="BUILDS_MAXPOWER",
        ["Target Build"]="BUILDS_TARGET",
        ["Built-in Bug Catcher"]="UTIL_BUGS",
        ["Loadout Saver"]="BUILDS_LOADOUTS",
        ["Crafting & Learning Tools"]="CRAFTING_MAIN",
        ["Crafting Material Hunt"]="CRAFTING_HUNT",
        ["Turbo Learner"]="CRAFTING_LEARNER",
        ["Crafting Assistant"]="CRAFTING_ASSIST",
        ["Utility Command Center"]="UTIL_COMMAND",
    }

    -- Every feature header is assigned explicitly. This avoids the old behavior
    -- where a section could inherit the category of whichever header happened
    -- to appear before it in rawOptions.
    local headerCategory = {
        ["Boss Mechanics Coach"] = "COMBAT",
        ["Gameplay & Challenge Difficulty"] = "DIFFICULTY",
        ["Live Group Finder"] = "ACTIVITIES",
        ["Game Mode Combat Report"] = "COMBAT",
        ["Inventory Grid Categories"] = "GEAR",
        ["Character Gear Screen"] = "GEAR",
        ["Automatic Equipment Maintenance"] = "GEAR",
        ["Repair / Recharge Estimate Overlay"] = "GEAR",
        ["Suite FPS / Latency Overlay"] = "HUD",
        ["Screen Edge Info Bar"] = "HUD",
        ["Pre-Encounter Reminders"] = "COMBAT",
        ["Lore Book Locations"] = "PINS",
        ["Dungeon / Trial Chest Finder"] = "PINS",
        ["Antiquity Assistant"] = "ANTIQUITIES",
        ["Antiquity Lead Finder"] = "ANTIQUITIES",
        ["Suite Resource Pins"] = "PINS",
        ["Resource Pin Icon Replacer"] = "PINS",
        ["Farm Focus"] = "PINS",
        ["Normal Resource Pin Filters"] = "PINS",
        ["Team Visibility"] = "GROUP",
        ["Companion Glow"] = "GROUP",
        ["Group Default Glow"] = "GROUP",
        ["Per-Player Group Glow"] = "GROUP",
        ["World Combat Visibility"] = "COMBAT",
        ["Persistent HUD & Unit Frames"] = "FRAMES",
        ["ESO Native Loot History & Chat"] = "HUD",
        ["Stable Training Timer"] = "HUD",
        ["Clock"] = "HUD",
        ["Quest Tracking"] = "QUESTS",
        ["Active Quest Overlay"] = "QUESTS",
        ["Golden Pursuits Overlay"] = "QUESTS",
        ["Alliance Rank Overlay"] = "QUESTS",
        ["Character Level / Champion Progress Overlay"] = "QUESTS",
        ["Controller / Gamepad"] = "CONTROLLER",
        ["Dual Action Bar HUD"] = "ACTIONBARS",
        ["Ability Overlays"] = "ACTIONBARS",
        ["Quickslot Overlay"] = "ACTIONBARS",
        ["Infinite Archive Overlay"] = "ACTIVITIES",
        ["Custom ESO Reticle"] = "HUD",
        ["Tamriel Codex"] = "CODEX",
        ["Unit Frame Designs"] = "FRAMES",
        ["World Map Teleporter"] = "TRAVEL",
        ["Wayshrine Auto Message"] = "TRAVEL",
        ["Treasure & Survey Locator"] = "PINS",
        ["Mini Map"] = "MAP",
        ["MAX POWER Build / Champion Points"] = "BUILDS",
        ["Target Build"] = "BUILDS",
        ["Built-in Bug Catcher"] = "UTILITIES",
        ["Loadout Saver"] = "BUILDS",
        ["Crafting & Learning Tools"] = "CRAFTING",
        ["Crafting Material Hunt"] = "CRAFTING",
        ["Turbo Learner"] = "CRAFTING",
        ["Crafting Assistant"] = "CRAFTING",
        ["Utility Command Center"] = "UTILITIES",
    }

    -- A few controls intentionally sit inside a different raw header for layout
    -- reasons. Route those controls to the feature category they actually affect.
    local nameCategory = {
        ["Smart Combat Advisor"] = "COMBAT",
        ["Smart Advisor specialization"] = "COMBAT",
        ["Smart Advisor display"] = "COMBAT",
        ["Test Action-Bar Highlight"] = "COMBAT",
        ["Show BLOCK reactions"] = "COMBAT",
        ["Block warning sensitivity"] = "COMBAT",
        ["Learn dangerous attacks"] = "COMBAT",
        ["Combat role awareness"] = "COMBAT",

        ["Show combat HUD"] = "COMBAT",
        ["Combat HUD visibility"] = "COMBAT",
        ["Move compact combat HUD"] = "COMBAT",
        ["Lock combat HUD"] = "COMBAT",
        ["Reset combat HUD position"] = "COMBAT",
        ["Combat HUD scale"] = "COMBAT",
        ["Combat HUD opacity"] = "COMBAT",

        ["ESO Edit HUD"] = "HUD",
        ["Lock HUD frames"] = "HUD",
        ["Reset HUD frame positions"] = "HUD",
        ["Player frame size"] = "FRAMES",
        ["Target frame size"] = "FRAMES",
        ["Group / Raid frame scale"] = "FRAMES",
        ["Live stats panel scale"] = "COMBAT",
        ["Show live combat stat panel"] = "COMBAT",
        ["Live Combat Stats visibility"] = "COMBAT",
        ["Use stronger HUD panel backgrounds"] = "FRAMES",
        ["Dark HUD backgrounds"] = "FRAMES",
        ["HUD background opacity"] = "FRAMES",
        ["Floating HUD opacity"] = "FRAMES",
        ["Target aura icons per type"] = "FRAMES",

        ["Auto-expand in interaction mode"] = "CODEX",
        ["Lock window"] = "CODEX",
        ["Show recommendation reasons"] = "CODEX",
        ["Window opacity"] = "CODEX",
        ["Window scale"] = "CODEX",
        ["Codex text size"] = "CODEX",
        ["Reset overlay position"] = "CODEX",

        ["Endgame suite focus"] = "BUILDS",
        ["Endgame gear preset"] = "BUILDS",
        ["MAX POWER content target"] = "BUILDS",
        ["Intelligent Next Best Move"] = "BUILDS",

        ["Session planner mode"] = "ACTIVITIES",
        ["Custom session length"] = "ACTIVITIES",
        ["Activity planner goal"] = "ACTIVITIES",

        ["Clear last combat sample"] = "COMBAT",
    }

    -- Controls that historically lived under another raw header are routed to
    -- their exact owner here. This is presentation-only; getters/setters and
    -- SavedVariable keys are unchanged.
    local nameFeature = {
        ["Smart Combat Advisor"]="COMBAT_ADVISOR",
        ["Smart Advisor specialization"]="COMBAT_ADVISOR",
        ["Smart Advisor display"]="COMBAT_ADVISOR",
        ["Test Action-Bar Highlight"]="COMBAT_ADVISOR",
        ["Show BLOCK reactions"]="COMBAT_ADVISOR",
        ["Block warning sensitivity"]="COMBAT_ADVISOR",
        ["Learn dangerous attacks"]="COMBAT_ADVISOR",
        ["Combat role awareness"]="COMBAT_ADVISOR",

        ["Show combat HUD"]="COMBAT_HUD",
        ["Combat HUD visibility"]="COMBAT_HUD",
        ["Move compact combat HUD"]="COMBAT_HUD",
        ["Lock combat HUD"]="COMBAT_HUD",
        ["Reset combat HUD position"]="COMBAT_HUD",
        ["Combat HUD scale"]="COMBAT_HUD",
        ["Combat HUD opacity"]="COMBAT_HUD",

        ["Show live combat stat panel"]="COMBAT_STATS",
        ["Live Combat Stats visibility"]="COMBAT_STATS",
        ["Live stats panel scale"]="COMBAT_STATS",
        ["Clear last combat sample"]="COMBAT_STATS",

        ["Show ability hotkeys"]="ACTION_DUAL",
        ["Active bar marker"]="ACTION_DUAL",
        ["Put Front Bar (Bar 1) on top"]="ACTION_DUAL",
        ["Dual bar icon size"]="ACTION_DUAL",
        ["Dual bar scale"]="ACTION_DUAL",
        ["Button spacing"]="ACTION_DUAL",
        ["Bar row spacing"]="ACTION_DUAL",
        ["Inactive bar opacity"]="ACTION_DUAL",
        ["Inactive bar desaturation"]="ACTION_DUAL",
        ["Reset dual action bar position"]="ACTION_DUAL",

        ["ESO Edit HUD"]="HUD_NATIVE",
        ["Lock HUD frames"]="HUD_NATIVE",
        ["Reset HUD frame positions"]="HUD_NATIVE",

        ["Player frame size"]="FRAMES_MAIN",
        ["Target frame size"]="FRAMES_MAIN",
        ["Group / Raid frame scale"]="FRAMES_MAIN",
        ["Use stronger HUD panel backgrounds"]="FRAMES_MAIN",
        ["Dark HUD backgrounds"]="FRAMES_MAIN",
        ["HUD background opacity"]="FRAMES_MAIN",
        ["Floating HUD opacity"]="FRAMES_MAIN",
        ["Target aura icons per type"]="FRAMES_MAIN",

        ["Auto-expand in interaction mode"]="CODEX_MAIN",
        ["Lock window"]="CODEX_MAIN",
        ["Show recommendation reasons"]="CODEX_MAIN",
        ["Window opacity"]="CODEX_MAIN",
        ["Window scale"]="CODEX_MAIN",
        ["Codex text size"]="CODEX_MAIN",
        ["Reset overlay position"]="CODEX_MAIN",

        ["Endgame suite focus"]="BUILDS_MAXPOWER",
        ["Endgame gear preset"]="BUILDS_MAXPOWER",
        ["MAX POWER content target"]="BUILDS_MAXPOWER",
        ["Intelligent Next Best Move"]="BUILDS_MAXPOWER",

        ["Session planner mode"]="ACTIVITIES_PLANNER",
        ["Custom session length"]="ACTIVITIES_PLANNER",
        ["Activity planner goal"]="ACTIVITIES_PLANNER",
    }

    local descriptionCategory = {
        ["Gameplay hotkeys"] = "CODEX",
        ["Compatibility status"] = "GENERAL",
    }

    local grouped = {}
    local featureOrder = {}
    for _, key in ipairs(categoryOrder) do
        grouped[key] = {}
        featureOrder[key] = {}
    end

    local function ensureFeatureBucket(category, feature)
        local info = featureInfo[feature]
        if not info or info.category ~= category then
            feature = defaultFeatureByCategory[category]
            info = featureInfo[feature]
        end
        if not grouped[category][feature] then
            grouped[category][feature] = {}
            featureOrder[category][#featureOrder[category] + 1] = feature
        end
        return grouped[category][feature], feature
    end

    local currentCategory = "GENERAL"
    local currentFeature = defaultFeatureByCategory.GENERAL
    for _, control in ipairs(rawOptions) do
        -- Information/description controls should always use the full settings
        -- width so LibAddonMenu can wrap them instead of squeezing text.
        if control.type == "description" then control.width = "full" end

        if control.type == "header" then
            currentCategory = headerCategory[control.name] or currentCategory
            currentFeature = headerFeature[control.name] or defaultFeatureByCategory[currentCategory]
        else
            local category = currentCategory
            if control.name and nameCategory[control.name] then
                category = nameCategory[control.name]
            elseif control.type == "description" and control.title and descriptionCategory[control.title] then
                category = descriptionCategory[control.title]
            end
            if not grouped[category] then category = "GENERAL" end

            local feature = control.name and nameFeature[control.name] or currentFeature
            local info = featureInfo[feature]
            if not info or info.category ~= category then
                feature = defaultFeatureByCategory[category]
            end

            local bucket = ensureFeatureBucket(category, feature)
            bucket[#bucket + 1] = control
        end
    end

    self.settingsSearchIndex029787 = {}
    self.settingsSearchById029787 = {}
    local searchId029787 = 0

    local organizedOptions = {
        {
            type = "description",
            title = "ESO Adventurer Suite Settings",
            text = "Settings are organized by feature owner. Use Search Settings to jump directly to any option, or browse the feature sections below.",
            width = "full",
        },
        {
            type = "editbox",
            name = "Search Settings",
            tooltip = "Type any setting or feature name. Matches update as you type. Press Enter to jump to the best match.",
            isExtraWide = true,
            maxChars = 80,
            reference = "EAS_SettingsSearchBox029787",
            getFunc = function() return S.searchQuery029787 or "" end,
            setFunc = function(v) S:RefreshSettingsSearch029787(v) end,
            default = "",
            width = "full",
        },
        {
            type = "dropdown",
            name = "Search Results",
            tooltip = "Choose a matching setting to open its category/feature and scroll directly to it.",
            choices = { "Type a setting name above" },
            choicesValues = { 0 },
            scrollable = 12,
            reference = "EAS_SettingsSearchResults029787",
            getFunc = function() return tonumber(S.searchSelected029787) or 0 end,
            setFunc = function(v)
                S.searchSelected029787 = tonumber(v) or 0
                if S.searchSelected029787 > 0 then S:JumpToSetting029787(S.searchSelected029787) end
            end,
            default = 0,
            width = "full",
        },
        {
            type = "button",
            name = "Jump to selected setting",
            buttonText = "Go to Setting",
            tooltip = "Opens the matching feature and centers the selected setting in the Settings panel.",
            func = function() S:JumpToSetting029787(S.searchSelected029787) end,
            width = "full",
        },
    }

    for _, category in ipairs(categoryOrder) do
        local categoryFeatures = featureOrder[category]
        if categoryFeatures and #categoryFeatures > 0 then
            local categoryMeta = categoryInfo[category]
            local categoryControls = {
                {
                    type = "description",
                    text = categoryMeta.intro,
                    width = "full",
                },
            }

            local categoryRef = "EAS_SettingsCategory029787_" .. tostring(category)
            for _, feature in ipairs(categoryFeatures) do
                local controls = grouped[category][feature]
                if controls and #controls > 0 then
                    local featureMeta = featureInfo[feature]
                    local featureRef = "EAS_SettingsFeature029787_" .. tostring(feature)

                    for _, control in ipairs(controls) do
                        if control.type ~= "description" and control.name then
                            searchId029787 = searchId029787 + 1
                            local controlRef = control.reference or ("EAS_SettingsOption029787_" .. tostring(searchId029787))
                            control.reference = controlRef

                            local settingName = tostring(control.name or "")
                            local tooltip = type(control.tooltip) == "string" and control.tooltip or ""
                            local path = string.format("%s > %s > %s", categoryMeta.name, featureMeta.name, settingName)
                            local entry = {
                                id = searchId029787,
                                name = settingName,
                                path = path,
                                category = category,
                                feature = feature,
                                categoryRef = categoryRef,
                                featureRef = featureRef,
                                controlRef = controlRef,
                            }
                            entry.searchName = normalizeSettingsSearch029787(settingName)
                            entry.searchPath = normalizeSettingsSearch029787(path)
                            entry.searchText = normalizeSettingsSearch029787(path .. " " .. tooltip)
                            S.settingsSearchIndex029787[#S.settingsSearchIndex029787 + 1] = entry
                            S.settingsSearchById029787[entry.id] = entry
                        end
                    end

                    categoryControls[#categoryControls + 1] = {
                        type = "submenu",
                        name = featureMeta.name,
                        reference = featureRef,
                        controls = controls,
                    }
                end
            end

            organizedOptions[#organizedOptions + 1] = {
                type = "submenu",
                name = categoryMeta.name,
                tooltip = categoryMeta.tooltip,
                reference = categoryRef,
                controls = categoryControls,
            }
        end
    end

    -- Feature modules extend the organized tree here. Settings.lua remains the
    -- sole owner of the final LibAddonMenu registration.
    S:ApplyOptionsExtensions(organizedOptions)

    -- v0.29.788: build the search index from the FINAL settings tree after all
    -- extensions are applied. This makes late-added feature modules (such as
    -- Group Loot Notifier) first-class searchable settings instead of invisible
    -- post-processing additions.
    self.settingsSearchIndex029787 = {}
    self.settingsSearchById029787 = {}
    searchId029787 = 0

    local function indexFinalSettingsTree029788(list)
        for _, categoryOption in ipairs(list or {}) do
            if categoryOption and categoryOption.type == "submenu" and type(categoryOption.controls) == "table" then
                local categoryName = tostring(categoryOption.name or "")
                local categoryRef = categoryOption.reference
                if not categoryRef or categoryRef == "" then
                    categoryRef = "EAS_SettingsCategory029788_" .. tostring(#self.settingsSearchIndex029787 + 1)
                    categoryOption.reference = categoryRef
                end

                for _, featureOption in ipairs(categoryOption.controls) do
                    if featureOption and featureOption.type == "submenu" and type(featureOption.controls) == "table" then
                        local featureName = tostring(featureOption.name or "")
                        local featureRef = featureOption.reference
                        if not featureRef or featureRef == "" then
                            featureRef = "EAS_SettingsFeature029788_" .. tostring(#self.settingsSearchIndex029787 + 1)
                            featureOption.reference = featureRef
                        end

                        for _, control in ipairs(featureOption.controls) do
                            if control and control.type ~= "description" and control.type ~= "header" and control.name then
                                searchId029787 = searchId029787 + 1
                                local controlRef = control.reference or ("EAS_SettingsOption029788_" .. tostring(searchId029787))
                                control.reference = controlRef
                                local settingName = tostring(control.name or "")
                                local tooltip = type(control.tooltip) == "string" and control.tooltip or ""
                                local path = string.format("%s > %s > %s", categoryName, featureName, settingName)
                                local entry = {
                                    id = searchId029787,
                                    name = settingName,
                                    path = path,
                                    categoryRef = categoryRef,
                                    featureRef = featureRef,
                                    controlRef = controlRef,
                                }
                                entry.searchName = normalizeSettingsSearch029787(settingName)
                                entry.searchPath = normalizeSettingsSearch029787(path)
                                entry.searchText = normalizeSettingsSearch029787(path .. " " .. tooltip)
                                self.settingsSearchIndex029787[#self.settingsSearchIndex029787 + 1] = entry
                                self.settingsSearchById029787[entry.id] = entry
                            end
                        end
                    end
                end
            end
        end
    end
    indexFinalSettingsTree029788(organizedOptions)

    -- With global LAM refresh disabled, keep dependent disabled/enabled states
    -- responsive without paying the cost on every panel open. Only boolean/mode
    -- controls can reasonably fan out to many dependent controls; sliders/editboxes
    -- update themselves and do not trigger a 500-control refresh.
    local function wrapDependencySetters029375(list)
        for _, control in ipairs(list or {}) do
            if control.type == "submenu" and type(control.controls) == "table" then
                wrapDependencySetters029375(control.controls)
            elseif (control.type == "checkbox" or control.type == "dropdown") and type(control.setFunc) == "function" then
                local original = control.setFunc
                control.setFunc = function(...)
                    original(...)
                    S:RequestDependencyRefresh029375(220)
                end
            end
        end
    end
    wrapDependencySetters029375(organizedOptions)

    LAM:RegisterOptionControls(panelName, organizedOptions)

    -- v0.29.446: refresh once when this panel is actually opened. Global automatic
    -- refresh remains disabled for performance, but this one-shot pass prevents
    -- the small number of genuine runtime/context guards from becoming stale.
    if CALLBACK_MANAGER and type(CALLBACK_MANAGER.RegisterCallback) == "function" then
        CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", function(panel)
            if panel == S.panelObject then
                S:HookSettingsSearchControls029787()
                if S.pendingSettingsJump029787 then
                    local pending = S.pendingSettingsJump029787
                    S.pendingSettingsJump029787 = nil
                    if zo_callLater then
                        zo_callLater(function() S:PerformSettingsJump029787(pending) end, 80)
                    else
                        S:PerformSettingsJump029787(pending)
                    end
                end
            end
        end)
        CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
            if panel == S.panelObject then
                S:HookSettingsSearchControls029787()
                if S.panelObject and type(S.panelObject.RefreshPanel) == "function" then
                    pcall(S.panelObject.RefreshPanel, S.panelObject)
                end
            end
        end)
    end
end
