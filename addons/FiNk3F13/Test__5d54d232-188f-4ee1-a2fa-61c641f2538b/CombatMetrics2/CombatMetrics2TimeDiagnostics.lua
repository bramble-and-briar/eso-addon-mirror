-- Read-only reporting of this add-on's stored fight data. No live collectors or external add-ons are accessed.
local A = CMX2

function A.BuildBossTimeDiagnostic(fight, selection)
    local lines = {}
    local function add(text) lines[#lines + 1] = "[CMX2 Zeit] " .. text end
    if not fight or not fight.units then
        add("Zuerst den abgeschlossenen Kampf im Bericht oeffnen.")
        return lines
    end
    local base = tonumber(fight.combatstart)
    local function stamp(value)
        if type(value) ~= "number" then return "--" end
        local offset = base and string.format(" | ab Kampfstart: %.3f s", (value - base) / 1000) or ""
        return string.format("%.0f ms", value) .. offset
    end
    add("Kampfstart: " .. stamp(base) .. " | Auswahl: " .. (selection and "gewaehlte Ziele" or "alle Bosse"))
    local ids = {}
    for id, unit in pairs(fight.units) do
        if (selection and selection[id] ~= nil) or (not selection and unit.bossId ~= nil) then
            ids[#ids + 1] = id
        end
    end
    table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
    if #ids == 0 then add("Kein Boss gefunden. Im Zielbereich einen Gegner auswaehlen.") end
    for _, id in ipairs(ids) do
        local unit = fight.units[id]
        local amount = tonumber(unit.damageOutTotal) or 0
        local calculated = fight.calculated and fight.calculated.units and fight.calculated.units[id]
        local rowAmount = calculated and tonumber(calculated.damageOutTotal) or amount
        local first, last = tonumber(unit.dpsstart), tonumber(unit.dpsend)
        local rawMS = first and last and last - first
        -- Same denominator and rounding as the report's target row.
        local rowSeconds = rawMS and math.max(rawMS / 1000, 1) or 1
        add(string.format("Ziel: %s | ID: %s | Schaden: %.0f | Zielzeilen-Schaden: %.0f", unit.name or "?", tostring(id), amount, rowAmount))
        add("Start: " .. stamp(first))
        add("Ende: " .. stamp(last))
        add(string.format("Zielspanne: %s | Zielzeilen-Zeit: %.3f s | Ziel-DPS: %.0f", rawMS and string.format("%.3f s", rawMS / 1000) or "--", rowSeconds, rowAmount / rowSeconds))
    end
    add(string.format("Gesamtschaden: %.0f | DPS-Active-Time: %s", tonumber(fight.damageOutTotal) or 0,
        type(fight.dpstime) == "number" and string.format("%.3f s", fight.dpstime) or "--"))
    return lines
end

function A.PrintBossTimeDiagnostic(fight, selection)
    for _, line in ipairs(A.BuildBossTimeDiagnostic(fight, selection)) do d(line) end
end
