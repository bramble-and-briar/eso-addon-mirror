-- Layout correction for Backpack Decon Select All 0.2.0.
local NAME = "BackpackDeconSelectAllAlignmentFix"

local function FixAlignment()
    for _, suffix in ipairs({ "Smithing", "Universal" }) do
        local checkbox = _G["BackpackDeconSelectAll" .. suffix .. "Checkbox"]
        if checkbox then
            local label = checkbox:GetNamedChild("Label")
            if label then
                label:ClearAnchors()
                label:SetAnchor(LEFT, checkbox, RIGHT, 6, 0)
                label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
                label:SetWidth(480)
                label:SetHeight(48)
            end
        end
    end
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, FixAlignment)
EVENT_MANAGER:RegisterForEvent(NAME, EVENT_CRAFTING_STATION_INTERACT, FixAlignment)
