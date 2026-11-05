local L = SimpleGroupDPS_Translate or function(text) return text end
local panel = {}
SimpleGroupDPS_PersonalDPSPanel = panel

local function share(personal, group)
    if type(personal) ~= "number" or type(group) ~= "number" or personal < 0 or group < 0
        or personal ~= personal or group ~= group or personal == math.huge or group == math.huge then return nil end
    if group == 0 then return personal == 0 and 0 or nil end
    return personal / group * 100
end

function panel:GetShares(stats)
    return share(stats.total, stats.groupTotal), share(stats.bossTotal, stats.groupBossTotal)
end

local function percent(value)
    if SimpleGroupDPS_Language and SimpleGroupDPS_Language.english then
        return value and string.format("%.1f %%", value) or "-- %"
    end
    return value and (string.format("%.1f %%", value):gsub("%.", ",", 1)) or "-- %"
end

function panel:Create()
    local window = WINDOW_MANAGER:CreateTopLevelWindow("SimpleGroupDPSPersonalWindow")
    window:SetDimensions(500, 86)
    window:SetClampedToScreen(true)
    window:SetMouseEnabled(false)
    window:SetMovable(false)
    window:SetHidden(true)
    local function label(y, size)
        local control = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
        control:SetAnchor(TOPLEFT, window, TOPLEFT, 12, y)
        control:SetDimensions(476, 26)
        control:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thin", size))
        control:SetMaxLineCount(1)
        control:SetColor(0.9, 0.96, 1, 1)
        return control
    end
    window.title = label(4, 18)
    window.title:SetText(L("Dein Schaden · Gruppenanteil"))
    window.primary = label(28, 22)
    window.secondary = label(54, 22)
    return window
end

function panel:Render(window, stats, visible)
    if not visible then window:SetHidden(true); return end
    local allShare, bossShare = self:GetShares(stats)
    local format = SimpleGroupDPS_DPSPanel
    local total = format:FormatValue(stats.dps or 0)
    if stats.bossDPS ~= nil then
        window.primary:SetText("Boss: " .. format:FormatValue(stats.bossDPS) .. " DPS | " .. percent(bossShare))
        window.secondary:SetText(L("(Gesamt: ") .. total .. " DPS | " .. percent(allShare) .. ")")
        window.secondary:SetHidden(false)
        window:SetDimensions(500, 86)
    else
        window.primary:SetText("DPS: " .. total .. " | " .. percent(allShare))
        window.secondary:SetText("")
        window.secondary:SetHidden(true)
        window:SetDimensions(500, 60)
    end
    window:SetHidden(false)
end
