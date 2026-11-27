-- Compatibilidad con otros addons que tienes instalados.
local NWUI = NWUI
local CP = {}
NWUI.Compat = CP

-- Bandits UI dibuja sus propios iconos de objetos rápidos junto al botón Q.
-- NW Interfaz ya los muestra en su fila de consumibles, así que se ocultan
-- (solo los del HUD; los que Bandits muestra dentro del inventario no se tocan).
local function HideBanditsQuickslots()
    local ui = _G.BUI_QuickSlots
    if not ui then return end
    local parent = ui.GetParent and ui:GetParent()
    local q = NWUI.HUD and NWUI.HUD.QuickslotCtrl and NWUI.HUD.QuickslotCtrl()
    if parent == nil or parent == q then ui:SetHidden(true) end
end

function CP.Init()
    local s = NWUI.sv.hud
    if s.enabled and s.hideBanditsQuickslots and BUI and BUI.QuickSlots and BUI.QuickSlots.Update and SecurePostHook then
        SecurePostHook(BUI.QuickSlots, "Update", HideBanditsQuickslots)
        NWUI.On("NWUI_BUIQS", "EVENT_PLAYER_ACTIVATED", function()
            HideBanditsQuickslots()
            zo_callLater(HideBanditsQuickslots, 1500)
        end)
    end

    NWUI.On("NWUI_CompatNotice", "EVENT_PLAYER_ACTIVATED", function()
        EVENT_MANAGER:UnregisterForEvent("NWUI_CompatNotice", EVENT_PLAYER_ACTIVATED)
        if NWUI.sv.compatNoticeShown then return end
        NWUI.sv.compatNoticeShown = true
        local notes = {}
        if Azurah then
            notes[#notes + 1] = NWUI.T("compat_azurah")
        end
        if BUI then
            notes[#notes + 1] = NWUI.T("compat_bui")
        end
        for _, n in ipairs(notes) do d("|cC9A35E[NW Interfaz]|r " .. n) end
    end)
end

function CP.Diagnose()
    local out = {}
    out[#out + 1] = "Botón Q (QuickslotButton): " .. (QuickslotButton and NWUI.T("yes") or NWUI.T("no"))
    out[#out + 1] = "Tamriel Trade Centre: " .. ((NWUI.Price and NWUI.Price.HasTTC()) and NWUI.T("yes") or NWUI.T("no"))
    out[#out + 1] = "TTC Simple Price: " .. ((NWUI.Price and NWUI.Price.HasTTCSP()) and NWUI.T("yes") or NWUI.T("no"))
    out[#out + 1] = "Bandits UI: " .. (BUI and NWUI.T("yes") or NWUI.T("no")) .. " · Azurah: " .. (Azurah and NWUI.T("yes") or NWUI.T("no"))
    return out
end
