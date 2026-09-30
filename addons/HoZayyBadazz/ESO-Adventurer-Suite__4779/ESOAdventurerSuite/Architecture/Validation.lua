-- ESO Adventurer Suite - Architecture validation gates
ESOProgressionCoach = ESOProgressionCoach or {}
local EPC = ESOProgressionCoach
EPC.ArchitectureValidation = EPC.ArchitectureValidation or {}
local V = EPC.ArchitectureValidation

V.expectedManifestFiles = 152
V.allowedRoles = { module=true, layout=true, ["settings-extension"]=true }

function V:Validate()
    local issues = {}
    local I = EPC.ArchitectureInventory
    if not I or type(I.files) ~= "table" then return false, {"architecture inventory unavailable"} end
    local total, patches, owners = 0, 0, {}
    for path, meta in pairs(I.files) do
        total = total + 1
        if type(path) ~= "string" or path == "" then issues[#issues+1] = "invalid inventory path" end
        if type(meta) ~= "table" then
            issues[#issues+1] = "invalid inventory metadata: "..tostring(path)
        else
            if meta.role == "patch" then patches = patches + 1 end
            if not self.allowedRoles[meta.role] then issues[#issues+1] = "invalid role: "..tostring(path).." = "..tostring(meta.role) end
            if type(meta.subsystem) ~= "string" or meta.subsystem == "" then issues[#issues+1] = "missing subsystem: "..tostring(path) end
            if meta.owner then
                local owner=tostring(meta.owner)
                if owners[owner] and owners[owner] ~= path then issues[#issues+1] = "duplicate explicit owner: "..owner end
                owners[owner]=path
            end
        end
    end
    if total ~= self.expectedManifestFiles then issues[#issues+1] = "inventory count mismatch: "..tostring(total).." expected "..tostring(self.expectedManifestFiles) end
    if patches ~= 0 then issues[#issues+1] = "legacy patch debt: "..tostring(patches) end
    local audit = I.GetAudit and I:GetAudit() or nil
    if audit and audit.currentLoadedPatchFiles ~= 0 then issues[#issues+1] = "audit patch count is not zero" end
    if audit and tonumber(audit.repositoryStandalonePatchFiles) ~= 0 then issues[#issues+1] = "repository standalone patch count is not zero" end
    if audit and tonumber(audit.remainingInternalOverrideHotspots or 0) > 0 then
        issues[#issues+1] = "internal override debt remains: " .. tostring(audit.remainingInternalOverrideHotspots)
    end

    -- Hardened ownership invariants for the highest-risk shared subsystems.
    local bank = I.files["BankGridUnifiedV2.lua"]
    if not bank or bank.owner ~= "BankGridUnifiedV2" or bank.unifiedSortOwner ~= true or bank.unifiedRefreshPolicy ~= true then
        issues[#issues+1] = "bank ownership policy is not hardened"
    end
    local grid = I.files["InventoryGrid.lua"]
    if not grid or grid.owner ~= "InventoryGrid"
        or grid.authoritativeNativeCategoryRefresh ~= true
        or grid.authoritativeNativeCategoryApply ~= true
        or grid.authoritativeNativeCategoryCollect ~= true
        or grid.authoritativeNativeLinkResolver ~= true
        or grid.directCellDragOwner ~= true then
        issues[#issues+1] = "inventory grid ownership policy is not hardened"
    end
    local house = I.files["HouseStorage.lua"]
    if not house or house.owner ~= "HouseStorage" or house.sharedScenePolicy ~= true then
        issues[#issues+1] = "house storage ownership policy is not hardened"
    end
    local settings = I.files["Settings.lua"]
    if not settings or settings.owner ~= "Settings" or settings.extensionRegistry ~= true then
        issues[#issues+1] = "settings ownership policy is not hardened"
    end

    local hudEditor = I.files["Architecture/HudEditor.lua"]
    if not hudEditor or hudEditor.owner ~= "NativeHUDEditor" or hudEditor.nativeEditHud ~= true then
        issues[#issues+1] = "native Edit HUD ownership policy is not hardened"
    end

    local ability = I.files["AbilityOverlays.lua"]
    if not ability or ability.owner ~= "AbilityOverlays"
        or ability.unifiedPublicMethods ~= true
        or ability.noDualActionBarOwnership ~= true then
        issues[#issues+1] = "ability overlay ownership policy is not hardened"
    end
    local dual = I.files["DualActionBar.lua"]
    if not dual or dual.owner ~= "DualActionBar" or dual.unifiedPublicMethods ~= true then
        issues[#issues+1] = "dual action bar ownership policy is not hardened"
    end
    local gear = I.files["CharacterGearScreen.lua"]
    if not gear or gear.owner ~= "CharacterGearScreen" or gear.unifiedPublicMethods ~= true then
        issues[#issues+1] = "character gear ownership policy is not hardened"
    end
    local perf = I.files["RuntimePerformanceController.lua"]
    if not perf or perf.owner ~= "RuntimePerformance"
        or perf.unifiedActivationOwner ~= true
        or perf.unifiedCombatStateOwner ~= true
        or perf.unifiedTeamTimerOwner ~= true then
        issues[#issues+1] = "runtime performance ownership policy is not hardened"
    end
    if EPC.Runtime then
        for key, row in pairs(EPC.Runtime.events or {}) do
            if not row.owner then issues[#issues+1] = "runtime event missing owner: "..tostring(key) end
        end
        for key, row in pairs(EPC.Runtime.updates or {}) do
            if not row.owner then issues[#issues+1] = "runtime update missing owner: "..tostring(key) end
        end
    end
    return #issues == 0, issues
end
