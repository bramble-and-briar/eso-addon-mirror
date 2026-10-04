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
end
