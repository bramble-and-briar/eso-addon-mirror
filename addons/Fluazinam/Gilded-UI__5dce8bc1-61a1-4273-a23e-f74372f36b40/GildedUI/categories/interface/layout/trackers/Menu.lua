if not GildedUI then return end

local Addon = GildedUI

function Addon:BuildTrackerColumnMenu(H)
    local sv = self.state.sv
    local limits = self.limits
    local controls = {
        H.Toggle(
            "Enable Tracker Column",
            function() return sv.trackerColumnEnabled end,
            function(v) Addon:SetTrackerColumnEnabled(v) end,
            Addon.defaults.trackerColumnEnabled
        ),
        H.Slider(
            "Position Y",
            limits.posY.min,
            limits.posY.max,
            5,
            function() return sv.trackerColumnPosY end,
            function(v)
                sv.trackerColumnPosY = v
                Addon:ApplyTrackerColumn()
            end,
            Addon.defaults.trackerColumnPosY
        ),
        H.Slider(
            "Scale",
            limits.trackerColumnScale.min,
            limits.trackerColumnScale.max,
            0.05,
            function() return sv.trackerColumnScale end,
            function(v)
                sv.trackerColumnScale = v
                Addon:ApplyTrackerColumn()
            end,
            Addon.defaults.trackerColumnScale
        ),
    }

    return {
        type = "submenu",
        name = "Tracker Column",
        tooltip = "Moves and scales the right-side HUD tracker panel (quests, archive, activities, and similar).",
        onEnter = function()
            Addon:SetTrackerColumnMenuPreview(true)
        end,
        onExit = function()
            Addon:SetTrackerColumnMenuPreview(false)
        end,
        options = controls,
    }
end
