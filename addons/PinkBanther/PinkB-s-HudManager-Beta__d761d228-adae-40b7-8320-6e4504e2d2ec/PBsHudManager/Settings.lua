local A, S = PBS_HUD_MANAGER, PBS_HUD_MANAGER_STRINGS

function A:InitSettings()
    local L = LibHarvensAddonSettings
    if not L then return end
    local panel = L:AddAddon(self.title)
    if not panel then return end
    self.panel = panel
    panel.author, panel.version = self.author, self.version

    panel:AddSetting({type = L.ST_LABEL, label = S.note})
    -- The outcome of the buttons is shown here: chat is behind the menu.
    panel:AddSetting({type = L.ST_LABEL, label = function() return self.message or S.ready end})

    -- The add-ons that are there, listed when the panel is built. This add-on loads after every
    -- one of them (see OptionalDependsOn), so the list is complete by now.
    panel:AddSetting({type = L.ST_SECTION or L.ST_LABEL, label = S.targetsHeader})
    local installed = self:InstalledTargets()
    if #installed == 0 then
        panel:AddSetting({type = L.ST_LABEL, label = S.noTargets})
    end
    for _, target in ipairs(installed) do
        panel:AddSetting({type = L.ST_LABEL, label = "- " .. target.label})
    end

    -- What has been typed into a name row and not saved yet; nil while it has not been touched,
    -- when the row shows the name the set already has. Not stored: it only has to last while
    -- the panel is open.
    self.draftNames = {}
    for index = 1, self.slotCount do
        -- The heading is the name the player gave the set, so it follows the saved name. It has to
        -- be a section: that is what divides the panel, and everything after one belongs to it.
        -- (A label here, in 1.0.1, left every row of every set under the first section.) The
        -- library takes a function for the label of any setting.
        panel:AddSetting({type = L.ST_SECTION or L.ST_LABEL, label = function() return self:SlotTitle(index) end})
        panel:AddSetting({type = L.ST_LABEL, label = function() return self:SlotDetail(index) end})
        if L.ST_EDIT then
            -- The edit row reports its text on Enter and again when it loses focus, so the setter
            -- only stores; nothing happens until the button.
            panel:AddSetting({type = L.ST_EDIT, label = S.nameLabel, tooltip = S.nameTooltip,
                maxChars = self.nameMaxChars, ignoreDefault = true,
                getFunction = function() return self.draftNames[index] or self:SlotName(index) end,
                setFunction = function(value)
                    local name = self:CleanName(value)
                    self.draftNames[index] = name ~= "" and name or nil
                end})
        end
        panel:AddSetting({type = L.ST_BUTTON, label = S.saveLabel, tooltip = S.saveTooltip,
            buttonText = S.saveButton,
            clickHandler = function()
                if self:PressSave(index, self.draftNames[index]) then
                    self.draftNames[index] = nil
                end
            end})
        panel:AddSetting({type = L.ST_BUTTON, label = S.loadLabel, tooltip = S.loadTooltip,
            buttonText = S.loadButton,
            clickHandler = function() self:PressLoad(index) end})
    end

    -- The parts of other add-ons, picked from what the HUD showed when it was last looked at.
    panel:AddSetting({type = L.ST_SECTION or L.ST_LABEL, label = S.partsHeader})
    panel:AddSetting({type = L.ST_LABEL, label = S.partsNote})
    panel:AddSetting({type = L.ST_LABEL, label = function() return self:PartsStatus() end})
    if L.ST_DROPDOWN and L.ST_BUTTON then
        -- Items are a function so the lists are rebuilt each time the panel refreshes, and there is no
        -- default: the library's reset indexes items as a table.
        panel:AddSetting({type = L.ST_DROPDOWN, label = S.partsFoundLabel, tooltip = S.partsFoundTooltip,
            ignoreDefault = true,
            items = function() return self:CandidateItems() end,
            getFunction = function() return self:SelectedItem(self:CandidateItems(), self.partDraft.candidate).name end,
            setFunction = function(_, _, item) self.partDraft.candidate = item and item.data or nil end})
        panel:AddSetting({type = L.ST_BUTTON, label = S.partsAddLabel, tooltip = S.partsAddTooltip,
            buttonText = S.partsAddButton, clickHandler = function() self:PressAddPart() end})
        panel:AddSetting({type = L.ST_DROPDOWN, label = S.partsChosenLabel, tooltip = S.partsChosenTooltip,
            ignoreDefault = true,
            items = function() return self:ChosenItems() end,
            getFunction = function() return self:SelectedItem(self:ChosenItems(), self.partDraft.chosen).name end,
            setFunction = function(_, _, item) self.partDraft.chosen = item and item.data or nil end})
        panel:AddSetting({type = L.ST_BUTTON, label = S.partsRemoveLabel, buttonText = S.partsRemoveButton,
            clickHandler = function() self:PressRemovePart() end})
        panel:AddSetting({type = L.ST_BUTTON, label = S.partsRescanLabel, tooltip = S.partsRescanTooltip,
            buttonText = S.partsRescanButton, clickHandler = function() self:PressRescan() end})
    end

    -- This add-on's own options. Not part of any set.
    panel:AddSetting({type = L.ST_SECTION or L.ST_LABEL, label = S.optionsHeader})
    panel:AddSetting({type = L.ST_CHECKBOX, label = S.combatHide, tooltip = S.combatHideTooltip,
        default = self.defaults.combat.enabled,
        getFunction = function() return self.sv.combat.enabled end,
        setFunction = function(value) self:SetCombatOption("enabled", value) end})
    for _, target in ipairs(self.combatTargets) do
        local key = target.key
        panel:AddSetting({type = L.ST_CHECKBOX, label = S["combat_" .. key], tooltip = S["combatTip_" .. key],
            default = self.defaults.combat[key],
            getFunction = function() return self.sv.combat[key] end,
            setFunction = function(value) self:SetCombatOption(key, value) end})
    end
end
