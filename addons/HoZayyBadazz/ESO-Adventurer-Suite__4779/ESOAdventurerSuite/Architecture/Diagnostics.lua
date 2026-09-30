-- ESO Adventurer Suite - Architecture diagnostics
ESOProgressionCoach = ESOProgressionCoach or {}
local EPC = ESOProgressionCoach
EPC.ArchitectureDiagnostics = EPC.ArchitectureDiagnostics or {}
local D = EPC.ArchitectureDiagnostics

function D:Snapshot()
    local result = { modules={}, events=0, updates=0, hudConsumers=0 }
    if EPC.Architecture and type(EPC.Architecture.GetDiagnostics) == "function" then
        result.modules = EPC.Architecture:GetDiagnostics()
    end
    if EPC.Runtime then
        for _ in pairs(EPC.Runtime.events or {}) do result.events=result.events+1 end
        for _ in pairs(EPC.Runtime.updates or {}) do result.updates=result.updates+1 end
    end
    if EPC.HudVisibility then
        for _ in pairs(EPC.HudVisibility.consumers or {}) do result.hudConsumers=result.hudConsumers+1 end
    end
    return result
end

function D:Validate()
    local issues = {}
    local snapshot = self:Snapshot()
    local inventory = EPC.ArchitectureInventory and EPC.ArchitectureInventory:GetSummary() or nil

    for _, row in ipairs(snapshot.modules or {}) do
        if row.state == "ERROR" then
            issues[#issues + 1] = "lifecycle error: " .. tostring(row.name) .. " - " .. tostring(row.error or "unknown")
        end
    end

    if EPC.ArchitectureValidation and type(EPC.ArchitectureValidation.Validate) == "function" then
        local ok, validationIssues = EPC.ArchitectureValidation:Validate()
        if not ok then
            for _, issue in ipairs(validationIssues or {}) do
                issues[#issues + 1] = "validation: " .. tostring(issue)
            end
        end
    else
        issues[#issues + 1] = "architecture validation unavailable"
    end

    if inventory then
        if inventory.total < 1 then issues[#issues + 1] = "architecture inventory is empty" end
        if inventory.patches > 0 then
            issues[#issues + 1] = tostring(inventory.patches) .. " legacy patch files remain to be absorbed"
        end
        local audit = EPC.ArchitectureInventory:GetAudit()
        if audit and tonumber(audit.currentLoadedPatchFiles) ~= 0 then
            issues[#issues + 1] = "loaded patch-file audit is not zero"
        end
    else
        issues[#issues + 1] = "architecture inventory unavailable"
    end

    return #issues == 0, issues, snapshot, inventory
end
