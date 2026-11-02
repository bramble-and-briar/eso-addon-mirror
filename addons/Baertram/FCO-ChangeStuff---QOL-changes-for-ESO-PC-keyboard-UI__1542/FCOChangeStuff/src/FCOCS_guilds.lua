if FCOCS == nil then FCOCS = {} end
local FCOChangeStuff = FCOCS

------------------------------------------------------------------------------------------------------------------------
-- Guilds --
------------------------------------------------------------------------------------------------------------------------

--Guild selector changes
local function updateGuildReOrderButtonsVisibility()
    local numGuilds = GetNumGuilds()
    if numGuilds >= 1 then
        local isVisible = FCOChangeStuff.settingsVars.settings.disableGuildReOrderDropdownEntries

        --Get the dropdown entries created
        local scroll = GUILD_SELECTOR.comboBox.m_scroll
        if scroll then
            local activeControls = scroll.activeControls
            --Hide the Up and Down buttons
            if activeControls and #activeControls > 0 then
                for idx, ctrl in ipairs(activeControls) do
                    if ctrl.dataEntry and ctrl.dataEntry.dataSource and ctrl.dataEntry.dataSource.guildId then
                        ctrl:GetNamedChild("Up"):SetHidden(isVisible)
                        ctrl:GetNamedChild("Down"):SetHidden(isVisible)
                    end
                end
            end
        end
    end
end

local function FCOChangeStuff_GuildsSelectorChanges()
    if GetAPIVersion() >= 101052 then
        ZO_PostHookHandler(GUILD_SELECTOR.comboBox.m_scroll, "OnEffectivelyShown", function()
            zo_callLater(function() updateGuildReOrderButtonsVisibility() end, 1)
        end)
        --Also fix the ZOs bug that the dropdown stays opened if the guild reorder was used
        SecurePostHook("AdjustGuildIndex", function()
            --Just enable the event manager's global mouseUp event again so any click outside would close the dropdown now
            -->Delay to next frame so the checks are done properly
            zo_callLater(function()
                if FCOChangeStuff.settingsVars.settings.disableGuildReOrderDropdownEntries then return end
                local comboBox = GUILD_SELECTOR.comboBox
                if comboBox:IsDropdownVisible() then
                    comboBox.m_container:RegisterForEvent(EVENT_GLOBAL_MOUSE_UP, function(...) comboBox:OnGlobalMouseUp(...) end)
                end
            end, 10)
        end)
    end
end


function FCOChangeStuff.GuildChanges()
    FCOChangeStuff_GuildsSelectorChanges()
end
