local ADK = AntiDK2
local M   = {}
ADK.UI.MoltenStacks = M

-- Molten Whip row in main panel at Y=176
-- Stacks 0-3: danger at 3 (empowered whip ready)
local Y_START    = 176
local MAX_STACKS = 3
local barLbl, countLbl

-- "I I ." style pips: filled pips in pink, red once maxed, dim dots for empty.
local function StackBar(n)
    local c      = ADK.COLORS
    local filled = math.max(0, math.min(n, MAX_STACKS))
    local color  = (filled >= MAX_STACKS) and c.DANGER or c.PINK
    return string.rep(ADK.Colorize(color, "I"), filled)
        .. string.rep(ADK.Colorize(c.PIP_EMPTY, "."), MAX_STACKS - filled)
end

function M.Init()
    local panel = ADK.UI.MainPanel
    local c     = ADK.COLORS

    local lbl = ADK.UI.MakeLabel("AntiDK2MoltenLbl", panel, ADK.Font(13), c.GREY)
    lbl:SetText("Molten Whip")
    lbl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    lbl:SetAnchor(TOPLEFT, panel, TOPLEFT, 0, Y_START)

    barLbl = ADK.UI.MakeLabel("AntiDK2MoltenBar", panel, ADK.Font(14), c.WHITE)
    barLbl:SetText(StackBar(0))
    barLbl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    barLbl:SetAnchor(TOPLEFT, panel, TOPLEFT, 90, Y_START)

    countLbl = ADK.UI.MakeLabel("AntiDK2MoltenCount", panel, ADK.Font(18), c.PINK)
    countLbl:SetText("")
    countLbl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    countLbl:SetAnchor(TOPRIGHT, panel, TOPRIGHT, 0, Y_START)
end

-- stacks = { [name] = { count = N } }; the row shows the most dangerous enemy.
function M.Refresh(stacks)
    local maxCount = 0
    for _, e in pairs(stacks) do
        if e.count > maxCount then maxCount = e.count end
    end

    barLbl:SetText(StackBar(maxCount))

    if maxCount >= MAX_STACKS then
        countLbl:SetText(ADK.Colorize(ADK.COLORS.DANGER, "EMPOWERED"))
        countLbl:SetFont(ADK.Font(13))
    elseif maxCount > 0 then
        countLbl:SetText(maxCount .. "/" .. MAX_STACKS)
        countLbl:SetFont(ADK.Font(18))
    else
        countLbl:SetText("")
    end
    ADK.UI.SetPanelFlag("molten", maxCount > 0)
end
