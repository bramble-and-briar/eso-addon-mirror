TeamShadowsBuffs = TeamShadowsBuffs or {}

local TSB = TeamShadowsBuffs
local EM = EVENT_MANAGER
local ADDON_NAME = TSB.name

TSB.modules = TSB.modules or {}
TSB.moduleOrder = TSB.moduleOrder or {}
TSB.moduleStates = TSB.moduleStates or {}

local function Chat(message)
    d(string.format("|c55AAFF%s|r: %s", TSB.displayName or "Team Shadows Buffs", tostring(message)))
end

TSB.Chat = Chat

function TSB.SafeCall(moduleName, actionName, fn, ...)
    if type(fn) ~= "function" then return true end

    local ok, result = pcall(fn, ...)
    if not ok then
        TSB.moduleStates[moduleName] = TSB.moduleStates[moduleName] or {}
        TSB.moduleStates[moduleName].failed = true
        TSB.moduleStates[moduleName].error = tostring(result)
        Chat(string.format("module %s désactivé : erreur dans %s.", tostring(moduleName), tostring(actionName)))
        if TSB.savedVars and TSB.savedVars.debug then
            Chat(tostring(result))
        end
        return false
    end

    return true, result
end

function TSB.RegisterModule(module)
    if type(module) ~= "table" or type(module.name) ~= "string" or module.name == "" then
        Chat("module ignoré : nom invalide.")
        return false
    end

    if TSB.modules[module.name] then
        Chat("module ignoré : doublon " .. module.name .. ".")
        return false
    end

    TSB.modules[module.name] = module
    table.insert(TSB.moduleOrder, module.name)
    TSB.moduleStates[module.name] = {
        loaded = false,
        failed = false,
        error = nil,
    }
    return true
end

local function IsModuleEnabled(moduleName)
    if not TSB.savedVars or TSB.savedVars.enabled ~= true then return false end

    local moduleVars = TSB.savedVars.modules and TSB.savedVars.modules[moduleName]
    return not moduleVars or moduleVars.enabled ~= false
end

function TSB.GetModuleSavedVars(moduleName)
    TSB.savedVars.modules = TSB.savedVars.modules or {}
    TSB.savedVars.modules[moduleName] = TSB.savedVars.modules[moduleName] or {}
    return TSB.savedVars.modules[moduleName]
end

local function LoadModule(moduleName)
    local module = TSB.modules[moduleName]
    local state = TSB.moduleStates[moduleName]
    if not module or not state or state.failed or state.loaded or not IsModuleEnabled(moduleName) then return end

    local ok = TSB.SafeCall(moduleName, "Load", module.Load, module, TSB.GetModuleSavedVars(moduleName))
    if ok then
        state.loaded = true
    end
end

local function UnloadModule(moduleName)
    local module = TSB.modules[moduleName]
    local state = TSB.moduleStates[moduleName]
    if not module or not state or not state.loaded then return end

    TSB.SafeCall(moduleName, "Unload", module.Unload, module)
    state.loaded = false
end

function TSB.LoadModules()
    for _, moduleName in ipairs(TSB.moduleOrder) do
        LoadModule(moduleName)
    end
end

function TSB.UnloadModules()
    for i = #TSB.moduleOrder, 1, -1 do
        UnloadModule(TSB.moduleOrder[i])
    end
end

function TSB.LoadModule(moduleName)
    LoadModule(moduleName)
end

function TSB.UnloadModule(moduleName)
    UnloadModule(moduleName)
end

function TSB.NotifyDisplayChanged()
    if TSB.displayRefreshQueued then return end
    TSB.displayRefreshQueued = true
    zo_callLater(function()
        TSB.displayRefreshQueued = false
        if TSB.UI then
            TSB.SafeCall("UI", "Refresh", TSB.UI.Refresh, TSB.UI)
        end
    end, 500)
end

local function PrintStatus()
    Chat(TSB.savedVars and TSB.savedVars.enabled and "addon actif." or "addon inactif.")

    for _, moduleName in ipairs(TSB.moduleOrder) do
        local state = TSB.moduleStates[moduleName] or {}
        local text = "prêt"
        if state.failed then
            text = "erreur"
        elseif state.loaded then
            text = "chargé"
        elseif not IsModuleEnabled(moduleName) then
            text = "désactivé"
        end
        Chat(string.format("%s : %s", moduleName, text))
    end
end

local function ToggleModule(moduleName)
    if not TSB.modules[moduleName] then
        Chat("module inconnu : " .. tostring(moduleName))
        return
    end

    local moduleVars = TSB.GetModuleSavedVars(moduleName)
    moduleVars.enabled = moduleVars.enabled == false
    if moduleVars.enabled then
        TSB.moduleStates[moduleName].failed = false
        TSB.LoadModule(moduleName)
    else
        TSB.UnloadModule(moduleName)
    end

    Chat(string.format("%s %s.", moduleName, moduleVars.enabled and "ON" or "OFF"))
end

local function OpenSettings()
    if TSB.OpenManager then
        TSB.SafeCall("Manager", "OpenManager", TSB.OpenManager)
    elseif TSB.OpenSettingsPanel then
        TSB.SafeCall("Settings", "OpenSettingsPanel", TSB.OpenSettingsPanel)
    else
        Chat("fenêtre de gestion indisponible.")
    end
end

local function HandleSlash(args)
    args = tostring(args or "")
    local command, rest = args:match("^(%S*)%s*(.-)$")
    command = command and string.lower(command) or ""

    if command == "settings" or command == "options" or command == "reglages" then
        OpenSettings()
    elseif command == "status" or command == "" then
        PrintStatus()
    elseif command == "off" then
        TSB.savedVars.enabled = false
        TSB.UnloadModules()
        if TSB.UI then
            TSB.SafeCall("UI", "Shutdown", TSB.UI.Shutdown, TSB.UI)
        end
        Chat("addon OFF.")
    elseif command == "on" then
        TSB.savedVars.enabled = true
        TSB.LoadModules()
        if TSB.UI then
            TSB.SafeCall("UI", "ApplySettings", TSB.UI.ApplySettings, TSB.UI)
        end
        Chat("addon ON.")
    elseif command == "toggle" and rest ~= "" then
        ToggleModule(rest)
    elseif command == "debug" then
        TSB.savedVars.debug = not TSB.savedVars.debug
        Chat(TSB.savedVars.debug and "debug ON." or "debug OFF.")
    elseif command == "unlock" then
        TSB.savedVars.unlocked = not TSB.savedVars.unlocked
        if TSB.UI then
            TSB.SafeCall("UI", "ApplySettings", TSB.UI.ApplySettings, TSB.UI)
        end
        Chat(TSB.savedVars.unlocked and "fenêtres déverrouillées." or "fenêtres verrouillées.")
    elseif command == "effects" and TSB.modules.MajorEffects and TSB.modules.MajorEffects.PrintStatus then
        TSB.SafeCall("MajorEffects", "PrintStatus", TSB.modules.MajorEffects.PrintStatus, TSB.modules.MajorEffects)
    else
        Chat("commandes : /tsb (manager) | /tsbuffs on | off | status | settings | effects | unlock | toggle MajorEffects | debug")
    end
end

local function HandleOpenManagerSlash()
    if TSB.OpenManager then
        TSB.OpenManager()
    elseif TSB.Manager and TSB.Manager.Show then
        TSB.Manager:Show()
    else
        Chat("interface du manager indisponible. Fais /reloadui, puis réessaie.")
    end
end

local function RegisterSlashCommands()
    SLASH_COMMANDS["/tsb"] = HandleOpenManagerSlash
    -- Commandes texte (debug, on/off, unlock...) : elles étaient orphelines et sont rebranchées ici.
    SLASH_COMMANDS["/tsbuffs"] = HandleSlash
end

function TSB.NormalizeLayout(value)
    value = tostring(value or "")
    if value == "individual" or value == "Chaque tracker separe" then
        return "individual"
    end
    if value == "separate" or value == "Buffs et debuffs separes" or value == "Deux fenetres: Buffs / Debuffs" then
        return "separate"
    end
    return "combined"
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON_NAME and addonName ~= TSB.displayName then return end

    EM:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    local accountVars = ZO_SavedVars:NewAccountWide(
        TSB.savedVariableName,
        TSB.savedVariableVersion,
        nil,
        TSB.defaults
    )

    local characterVars = ZO_SavedVars:NewCharacterIdSettings(
        TSB.savedVariableName,
        TSB.savedVariableVersion,
        nil,
        TSB.characterDefaults or {}
    )

    local characterFields = {
        effectSettings = true,
        panelSettings = true,
        playerOrder = true,
        bossOrder = true,
        trackerPositions = true,
        groupTrackerPositions = true,
        panels = true,
    }
    local function DeepCopy(value, seen)
        if type(value) ~= "table" then return value end
        seen = seen or {}
        if seen[value] then return seen[value] end
        local copy = {}
        seen[value] = copy
        for key, child in pairs(value) do copy[DeepCopy(key, seen)] = DeepCopy(child, seen) end
        return copy
    end

    -- Au premier chargement de cette version, le personnage actuellement joué
    -- récupère l'ancien profil global. Les autres personnages commencent vides.
    if characterVars.profileInitialized ~= true then
        local characterId = GetCurrentCharacterId and tostring(GetCurrentCharacterId()) or "unknown"
        if accountVars.trackerProfileMigrationCharacterId == nil then
            for key in pairs(characterFields) do
                if accountVars[key] ~= nil then characterVars[key] = DeepCopy(accountVars[key]) end
            end
            accountVars.trackerProfileMigrationCharacterId = characterId
        end
        characterVars.effectSettings = characterVars.effectSettings or {}
        characterVars.panelSettings = characterVars.panelSettings or {}
        characterVars.playerOrder = characterVars.playerOrder or TSB.defaults.playerOrder
        characterVars.bossOrder = characterVars.bossOrder or TSB.defaults.bossOrder
        characterVars.trackerPositions = characterVars.trackerPositions or {}
        characterVars.groupTrackerPositions = characterVars.groupTrackerPositions or {}
        characterVars.panels = characterVars.panels or {}
        characterVars.profileInitialized = true
    end

    -- Vue commune pour ne modifier aucune logique existante : chaque lecture ou
    -- L'écriture d'un champ de profil est dirigée vers le personnage, le reste vers
    -- les données du compte.
    TSB.accountSavedVars = accountVars
    accountVars.itemSetCollectionScans = nil
    TSB.characterSavedVars = characterVars
    TSB.savedVars = setmetatable({}, {
        __index = function(_, key)
            if characterFields[key] then return characterVars[key] end
            return accountVars[key]
        end,
        __newindex = function(_, key, value)
            if characterFields[key] then characterVars[key] = value else accountVars[key] = value end
        end,
    })

    -- Les anciennes fiches "proc" et "cooldown" deviennent une fiche unique.
    -- On conserve destinations, couleurs et positions déjà choisies par le joueur.
    local mergedTrackerKeys = {
        crimson_oath_proc = "crimson_oath",
        tremorscale_proc = "tremorscale",
        pillagers_profit_cd = "pillagers_profit",
        major_sorcery = "major_brutality",
        major_prophecy = "major_savagery",
    }
    local function MergeTrackerSettings(oldKey, newKey)
        local all = characterVars.effectSettings or {}
        local old = all[oldKey]
        if not old then return end
        local current = all[newKey] or {}
        current.destinations = current.destinations or {}
        local hasCurrentDestination = current.destination ~= nil or next(current.destinations) ~= nil
        if not hasCurrentDestination then
            if old.destination then
                current.destination = old.destination
                current.destinations[old.destination] = old.enabled ~= false
            end
            for destination, enabled in pairs(old.destinations or {}) do
                current.destinations[destination] = enabled
            end
        end
        for key, value in pairs(old) do
            if key ~= "destination" and key ~= "destinations" and key ~= "name" and key ~= "shortName" and current[key] == nil then
                current[key] = DeepCopy(value)
            end
        end
        all[newKey] = current
        all[oldKey] = nil
        for _, positions in ipairs({ characterVars.trackerPositions, characterVars.groupTrackerPositions }) do
            if positions and positions[oldKey] and not positions[newKey] then positions[newKey] = positions[oldKey] end
            if positions then positions[oldKey] = nil end
        end
    end
    local function ReplaceKeysInOrder(orderText)
        local result, seen = {}, {}
        for key in tostring(orderText or ""):gmatch("[^,%s]+") do
            key = mergedTrackerKeys[key] or key
            if not seen[key] then result[#result + 1], seen[key] = key, true end
        end
        return table.concat(result, ",")
    end
    for oldKey, newKey in pairs(mergedTrackerKeys) do MergeTrackerSettings(oldKey, newKey) end
    characterVars.playerOrder = ReplaceKeysInOrder(characterVars.playerOrder)
    characterVars.bossOrder = ReplaceKeysInOrder(characterVars.bossOrder)
    for _, panel in pairs(characterVars.panelSettings or {}) do
        if type(panel.order) == "string" then panel.order = ReplaceKeysInOrder(panel.order) end
    end

    for key, value in pairs(TSB.defaults or {}) do
        if key ~= "modules" and TSB.savedVars[key] == nil then
            TSB.savedVars[key] = value
        end
    end

    TSB.savedVars.modules = TSB.savedVars.modules or {}
    for moduleName, moduleDefaults in pairs(TSB.defaults.modules or {}) do
        TSB.savedVars.modules[moduleName] = TSB.savedVars.modules[moduleName] or {}
        for key, value in pairs(moduleDefaults) do
            if TSB.savedVars.modules[moduleName][key] == nil then
                TSB.savedVars.modules[moduleName][key] = value
            end
        end
    end

    if TSB.EnsureEffectSettingsDefaults then
        TSB.SafeCall("MajorEffects", "EnsureEffectSettingsDefaults", TSB.EnsureEffectSettingsDefaults)
    end

    -- Cette migration ne s'exécute qu'une fois par personnage. Elle applique le
    -- nouveau choix par défaut sans écraser les verrouillages manuels ultérieurs.
    if characterVars.defaultUnlockedMigration118 ~= true then
        TSB.savedVars.unlocked = true
        TSB.savedVars.modules = TSB.savedVars.modules or {}
        TSB.savedVars.modules.CombatStats = TSB.savedVars.modules.CombatStats or {}
        TSB.savedVars.modules.CombatStats.unlocked = true
        for _, settings in pairs(characterVars.panelSettings or {}) do
            if type(settings) == "table" then settings.unlocked = true end
        end
        for _, settings in pairs(characterVars.effectSettings or {}) do
            if type(settings) == "table" then settings.unlocked = true end
        end
        characterVars.defaultUnlockedMigration118 = true
    end

    -- Corrige uniquement les anciennes variantes fautives connues. Un nom
    -- réellement personnalisé par le joueur reste inchangé.
    local olorimeSettings = characterVars.effectSettings and characterVars.effectSettings.olorime
    if olorimeSettings and type(olorimeSettings.name) == "string" then
        local obsoleteOlorimeNames = {
            ["Vestment d'Olorime"] = true,
            ["Vestment of Olirime"] = true,
            ["Vêtement d'Olorime"] = true,
            ["Vêtement d'Olirime"] = true,
        }
        if obsoleteOlorimeNames[olorimeSettings.name] then olorimeSettings.name = nil end
    end
    TSB.savedVars.modules.GroupSetCoverage = nil
    TSB.savedVars.groupTrackerPositions = TSB.savedVars.groupTrackerPositions or {}
    TSB.savedVars.layout = TSB.NormalizeLayout(TSB.savedVars.layout)
    if type(TSB.savedVars.bossOrder) == "string" and not TSB.savedVars.bossOrder:find("off_balance", 1, true) then
        TSB.savedVars.bossOrder = TSB.savedVars.bossOrder .. ",off_balance"
    end
    TSB.savedVars.trackerPositions = TSB.savedVars.trackerPositions or {}
    TSB.savedVars.circleSize = tonumber(TSB.savedVars.circleSize) or TSB.defaults.circleSize
    if TSB.savedVars.circleSize < 20 then
        TSB.savedVars.circleSize = 40
    end
    if TSB.savedVars.previewEnabled == nil then
        TSB.savedVars.previewEnabled = TSB.defaults.previewEnabled
    end
    if TSB.savedVars.borderThickness == nil then
        TSB.savedVars.borderThickness = TSB.defaults.borderThickness
    end
    if TSB.savedVars.nameTextColor == nil then
        TSB.savedVars.nameTextColor = TSB.defaults.nameTextColor
    end
    if TSB.savedVars.timerTextColor == nil then
        TSB.savedVars.timerTextColor = TSB.defaults.timerTextColor
    end
    if TSB.savedVars.timerTextScale == nil then
        TSB.savedVars.timerTextScale = TSB.defaults.timerTextScale
    end
    if TSB.savedVars.badgeAlpha == nil then
        TSB.savedVars.badgeAlpha = TSB.defaults.badgeAlpha
    end
    if TSB.savedVars.barAlpha == nil then
        TSB.savedVars.barAlpha = TSB.defaults.barAlpha
    end
    if TSB.savedVars.textAlpha == nil then
        TSB.savedVars.textAlpha = TSB.defaults.textAlpha
    end
    if TSB.savedVars.acronymTextColor == nil then
        TSB.savedVars.acronymTextColor = TSB.defaults.acronymTextColor
    end
    if TSB.savedVars.cooldownColor == nil then
        TSB.savedVars.cooldownColor = TSB.defaults.cooldownColor
    end
    if TSB.savedVars.showNames == nil then
        TSB.savedVars.showNames = TSB.defaults.showNames
    end
    if TSB.savedVars.showTimers == nil then
        TSB.savedVars.showTimers = TSB.defaults.showTimers
    end
    if TSB.savedVars.showAcronyms == nil then
        TSB.savedVars.showAcronyms = TSB.defaults.showAcronyms
    end
    if TSB.savedVars.showStacks == nil then
        TSB.savedVars.showStacks = TSB.defaults.showStacks
    end
    if TSB.savedVars.showBar == nil then
        TSB.savedVars.showBar = TSB.defaults.showBar
    end
    if TSB.savedVars.stackTextColor == nil then
        TSB.savedVars.stackTextColor = TSB.defaults.stackTextColor
    end
    if TSB.savedVars.catalogLanguage ~= "en" then
        TSB.savedVars.catalogLanguage = "fr"
    end
    TSB.savedVars.catalogNamesByLanguage = TSB.savedVars.catalogNamesByLanguage or {}
    TSB.savedVars.catalogNamesByLanguage.fr = TSB.savedVars.catalogNamesByLanguage.fr or {}
    TSB.savedVars.catalogNamesByLanguage.en = TSB.savedVars.catalogNamesByLanguage.en or {}
    TSB.savedVars.catalogNamesByLanguage.fr.olorime = "Vêtement d'Olorimé"
    TSB.savedVars.catalogNamesByLanguage.en.olorime = "Vestment of Olorime"
    if TSB.CaptureCatalogLanguageNames then
        TSB.SafeCall("Catalog", "CaptureCatalogLanguageNames", TSB.CaptureCatalogLanguageNames)
    end

    RegisterSlashCommands()
    if TSB.UI then
        TSB.SafeCall("UI", "Initialize", TSB.UI.Initialize, TSB.UI)
        TSB.SafeCall("UI", "ApplySettings", TSB.UI.ApplySettings, TSB.UI)
    end
    if TSB.RegisterSettingsPanel then
        TSB.SafeCall("Settings", "RegisterSettingsPanel", TSB.RegisterSettingsPanel)
    end
    if TSB.Manager and TSB.Manager.InitializeLauncher then
        TSB.SafeCall("Manager", "InitializeLauncher", TSB.Manager.InitializeLauncher, TSB.Manager)
    end
    TSB.LoadModules()
end

EM:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
