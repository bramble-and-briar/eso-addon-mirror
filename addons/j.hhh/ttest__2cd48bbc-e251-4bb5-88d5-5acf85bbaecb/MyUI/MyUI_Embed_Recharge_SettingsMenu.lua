-- Simplified console-safe My UI recharge/repair settings.
-- No nested desktop controls, unsupported sliders, or separate addon panel.
local Recharge = Recharge

local function EnforceFivePercent()
    local sv = Recharge and Recharge.settings
    if not sv then return end
    sv.minChargePercent = 0.05
    sv.minConditionPercent = 0.05
    sv.chargeDuringCombat = false
    sv.repairDuringCombat = false
    sv.chargeOnWeaponChange = false
    sv.chargeOnWeaponChangeOnlyInCombat = false
end

function Recharge.BuildSettingsMenu()
    EnforceFivePercent()
    local options = {
        {
            type = "description",
            text = "Beide Funktionen arbeiten ausschließlich außerhalb des Kampfes und erst bei 5% oder weniger Restladung / Haltbarkeit. Die Schwellenwerte sind fest eingestellt.",
        },
        {
            type = "checkbox", name = "Auto Recharge (5%, nur außerhalb Kampf)",
            tooltip = "Lädt ausgerüstete Waffen mit Seelensteinen bei höchstens 5% Restladung auf; niemals im Kampf.",
            getFunc = function() return Recharge.settings and Recharge.settings.chargeEnabled == true end,
            setFunc = function(value)
                if Recharge.settings then Recharge.settings.chargeEnabled = value == true; EnforceFivePercent() end
            end,
            default = true, width = "full",
        },
        {
            type = "checkbox", name = "Auto Repair (5%, nur außerhalb Kampf)",
            tooltip = "Repariert ausgerüstete Rüstung mit Reparaturkits bei höchstens 5% Haltbarkeit; niemals im Kampf.",
            getFunc = function() return Recharge.settings and Recharge.settings.repairEnabled == true end,
            setFunc = function(value)
                if Recharge.settings then Recharge.settings.repairEnabled = value == true; EnforceFivePercent() end
            end,
            default = true, width = "full",
        },
    }
    if MyUI_RegisterExternalSection then
        MyUI_RegisterExternalSection(19, "Recharge", "19. Auto Recharge & Repair", options)
    end
end
