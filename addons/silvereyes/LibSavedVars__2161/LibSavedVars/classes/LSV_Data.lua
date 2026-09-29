--[[ LibSavedVars data storage class.
--]]

local LIBNAME      = "LibSavedVars"
local CLASSNAME    = "Data"
local CLASSVERSION = 1.8

-- If a newer version of this class is already loaded, exit
local class, protected = LibSavedVars:LoadClass(CLASSNAME, CLASSVERSION)
if not class then return end

LSV_Data = class

-- Used for readability
local DO_NOT_OVERWRITE = true

-- Toggle on to only print debug messages for this class
local debugMode = false

-- Private member declarations.  Definitions are at the end of the file.
local initAccountWide, initCharacterSettings, initToggle, onToggleLazyLoaded, 
      validateScope

-- Lua 5.1 versions of next() and ipairs()
local rawnext = LibLua52 and LibLua52.rawnext or next
local rawipairs = LibLua52 and LibLua52.rawipairs or ipairs



---------------------------------------
--
--       Constructors
-- 
---------------------------------------

--[[ Creates a new data object with account-wide saved vars as the default. You can add a character-specific saved vars
     toggle by chaining :AddCharacterSettingsToggle() below.  
     
     You can also chain with several other methods, such as :Migrate(), :RemoveSettings(), :RenameSettings() and 
     :Version().
     
     savedVariableTableName:  The name of the top-level global table containing the saved vars. Required. 
                              Matches the name in ## SavedVariables: in the manifest text file.
     
     version:                 (optional) The numeric current saved vars version. Defaults to 1.
                                         WARNING! Incrementing this value without adding a chained :Version() call after
                                         for the new version number will cause all settings to be reset to defaults.
     
     namespace:               (optional) An string namespace to separate other variables using the same table.
     
     defaults:                (optional) A table describing the default saved variables.
     
     profile:                 (optional) String used to group several saved vars tables together as a unit.  
                                         Usually either nil, "Default" or the megaserver name 
                                         (i.e. "NA Megaserver", "EU Megaserver", "PTS"). Defaults to megaserver name.
                                         
     displayName:             (optional) The account name the saved vars are for. Defaults to the current account name.
--]]
function LSV_Data:NewAccountWide(savedVariableTable, version, namespace, defaults, profile, displayName)

    version, namespace, defaults, _, profile, displayName = 
        LSV_Data.shiftOptionalParams(version, namespace, defaults, nil, profile, displayName)

    protected.zoDebug(debugMode, "LSV_Data:NewAccountWide(<<1>>, <<2>>, <<3>>, <<4>>, <<5>>, <<6>>)",
        savedVariableTable, version, namespace, defaults, profile, displayName)

    local data = { 
        __dataSource = { defaultToAccount = true }
    }
    setmetatable(data, self)

    initAccountWide(data, savedVariableTable, version, namespace, defaults, profile, displayName)

    return data
end

--[[ Creates a new data object with character-specific saved vars as the default. You can add an account-wide saved 
     vars toggle by chaining :AddAccountWideToggle() below.  
     
     You can also chain with several other methods, such as :Migrate(), :RemoveSettings(), :RenameSettings() and 
     :Version(). See the Public Methods section below for details.
     
     savedVariableTableName:  The name of the top-level global table containing the saved vars. Required. 
                              Matches the name in ## SavedVariables: in the manifest text file.
     
     version:                 (optional) The numeric current saved vars version. Defaults to 1.
                                         WARNING! Incrementing this value without adding a chained :Version() call after
                                         for the new version number will cause all settings to be reset to defaults.
     
     namespace:               (optional) An string namespace to separate other variables using the same table.
     
     defaults:                (optional) A table describing the default saved variables.
     
     profile:                 (optional) String used to group several saved vars tables together as a unit.  
                                         Usually either nil, "Default" or the megaserver name 
                                         (i.e. "NA Megaserver", "EU Megaserver", "PTS"). Defaults to megaserver name.
                                         
     displayName:             (optional) The account name the saved vars are for. Defaults to the current account name.
     
     
     characterName:           (optional) The character name the saved vars belong to. Defaults to the current character.
     
     characterId:             (optional) The character id the saved vars belong to. Defaults to the current character id.
--]]
function LSV_Data:NewCharacterSettings(savedVariableTable, version, namespace, defaults, profile, displayName, 
                                       characterName, characterId, characterKeyType)
    
    local _
    version, namespace, defaults, _, profile, displayName, characterName, characterId, characterKeyType = 
        LSV_Data.shiftOptionalParams(version, namespace, defaults, nil, profile, displayName, characterName, characterId, characterKeyType)
    
    protected.zoDebug(debugMode, "LSV_Data:NewCharacterSettings(<<1>>, <<2>>, <<3>>, <<4>>, <<5>>, <<6>>, <<7>>, <<8>>, <<9>>)", 
        savedVariableTable, version, namespace, defaults, profile, displayName,
        characterName, characterId, characterKeyType)
    
    local data = { 
        __dataSource = { defaultToAccount = false } 
    }
    setmetatable(data, self)
    
    initCharacterSettings(data, savedVariableTable, version, namespace, defaults, defaults, profile, displayName, 
                          characterName, characterId, characterKeyType)

    return data
end



---------------------------------------
--
--          Public Methods
-- 
---------------------------------------

--[[ Used to add an account-wide saved vars scope to an existing character-specific scope that can then be toggled
     back and forth at runtime, automatically switching the behavior of reading and writing settings on this instance.
     
     See the NewAccountWide() constructor above for parameter descriptions.
--]]
function LSV_Data:AddAccountWideToggle(savedVariableTableName, version, namespace, defaults, profile, displayName)
    if not self then
        return
    end
    
    protected.zoDebug(debugMode, "LSV_Data:AddAccountWideToggle(<<1>>, <<2>>, <<3>>, <<4>>, <<5>>, <<6>>)",
        savedVariableTableName, version, namespace, defaults, profile, displayName)
    
    version, namespace, defaults, _, profile, displayName = 
        LSV_Data.shiftOptionalParams(version, namespace, defaults, nil, profile, displayName)
    
    local ds = self.__dataSource
    
    if savedVariableTableName == nil then
        savedVariableTableName = ds.character.name
    end
    
    local characterDefaults = ZO_ShallowTableCopy(ds.character.defaults)
    characterDefaults[LIBNAME] = nil
    if defaults == nil then
        defaults = characterDefaults
    else
        ds.pinnedAccountKeys = LSV_Data.tableDiffKeys(defaults, characterDefaults)
        defaults = protected.tableMerge(defaults, characterDefaults)
    end
    
    if profile == nil then
        profile = ds.character.profile
    end
    
    if displayName == nil then
        displayName = ds.character.displayName
    end
    
    initAccountWide(self, savedVariableTableName, version, namespace, defaults, profile, displayName)
    initToggle(self)
    
    return self
end

--[[ Used to add an character-specific saved vars scope to an existing account-wide scope that can then be toggled
     back and forth at runtime, automatically switching the behavior of reading and writing settings on this instance.
     
     See the NewCharacterSettings() constructor above for parameter descriptions.
--]]
function LSV_Data:AddCharacterSettingsToggle(savedVariableTableName, version, namespace, defaults, profile, 
                                             displayName, characterName, characterId, characterKeyType)
    if not self then
        return
    end
    
    local _
    version, namespace, defaults, _, profile, displayName, characterName, characterId, characterKeyType = 
        LSV_Data.shiftOptionalParams(version, namespace, defaults, nil, profile, displayName, characterName, characterId, characterKeyType)
    
    protected.zoDebug(debugMode, "LSV_Data:AddCharacterSettingsToggle(<<1>>, <<2>>, <<3>>, <<4>>, <<5>>, <<6>>, <<7>>, <<8>>, <<9>>)", 
        savedVariableTableName, version, namespace, defaults, profile, displayName, 
        characterName, characterId, characterKeyType)
    
    local ds = self.__dataSource
    
    if savedVariableTableName == nil then
        savedVariableTableName = ds.account.name
    end
    
    local trimDefaults
    if defaults == nil then
        defaults = { }
        trimDefaults = ZO_ShallowTableCopy(ds.account.defaults)
    else
        ds.pinnedAccountKeys = LSV_Data.tableDiffKeys(ds.account.defaults, defaults)
        local defaultsNotOnAccount = LSV_Data.tableDiffKeys(defaults, ds.account.defaults)
        if next(defaultsNotOnAccount) ~= nil then
            ds.account.defaults = protected.tableMerge(ds.account.defaults, defaultsNotOnAccount)
        end
    end
    
    if profile == nil then
        profile = ds.account.profile
    end
    
    if displayName == nil then
        displayName = ds.account.displayName
    end
    
    initCharacterSettings(self, savedVariableTableName, version, namespace, defaults, trimDefaults, profile, displayName, 
                          characterName, characterId, characterKeyType)
    initToggle(self)
    
    return self
end

function LSV_Data:EnableDefaultsTrimming()
    local ds = rawget(self, "__dataSource")
    if not ds then return self end
    if ds.account then
        ds.account:EnableDefaultsTrimming()
    end
    if ds.character then
        ds.character:EnableDefaultsTrimming()
    end
    return self
end

--[[ Returns true if account-wide saved vars are currently toggled on. When no character-specific settings have been
     specified, always returns true.
 --]]
function LSV_Data:GetAccountSavedVarsActive()
    if not self then return end
    protected.zoDebug(debugMode, "LSV_Data:GetAccountSavedVarsActive()")
    local ds = rawget(self, "__dataSource")
    
    if ds then
      if ds.active then
          return ds.active == ds.account
      else
          return ds.account ~= nil
      end
    end
    return false
end

--[[ Returns the internal ZO_SavedVars instance that is active for the currently logged in character.
     
     Usage note: if no settings have yet been accessed with getters or setters, calling this method will cause an 
     underlying call to ZO_SavedVars:NewCharacterIdSettings() or ZO_SavedVars:NewAccountWide().
--]]
function LSV_Data:GetActiveSavedVars(key)
    if not self then return end
    protected.zoDebug(debugMode, "LSV_Data:GetActiveSavedVars(<<1>>)", key)

    local ds = rawget(self, "__dataSource")

    -- Get account pinned vars
    if key ~= nil and ds.account and ds.pinnedAccountKeys and ds.pinnedAccountKeys[key] ~= nil then
        return ds.account.savedVars
    end

    if not ds.active then
        if ds.account then
            ds.active = ds.account
        else
            ds.active = ds.character
        end
    end

    return ds.active and ds.active.savedVars or nil
end

--[[ Returns a function like next() used to iterate over the active ZO_SavedVar instance for the currently logged in 
     character. If account-wide vars are not active, then any pinned account-wide vars are prepended.
     Appends "__dataSource" as the last key/value pair, to provide access to the internal table containing
     configuration info and references to account and character saved vars managers.
--]]
local emptyObject = setmetatable({ __dataSource = {} }, LSV_Data)
function LSV_Data:GetIterator()
    protected.zoDebug(debugMode, "LSV_Data:GetIterator()")
    if not self then return rawnext, emptyObject end
    local ds = rawget(self, "__dataSource")
    if not ds then return rawnext, emptyObject end

    if ds.iterator then return ds.iterator, self end

    local subTables = {}
    local pinnedKeys = ds.pinnedAccountKeys
    if pinnedKeys and rawnext(pinnedKeys) == nil or LSV_Data.GetAccountSavedVarsActive(self) then
        pinnedKeys = nil
    end
    if pinnedKeys then
        local accountRawDataTable = ds.account and ds.account:LoadRawTableData()
        if accountRawDataTable then
            local pinnedSettings = LSV_Data.tableFilterKeys(accountRawDataTable, pinnedKeys)
            table.insert(subTables, pinnedSettings)
        end
    end

    local savedVars = LSV_Data.GetActiveSavedVars(self)
    local rawDataTable = savedVars and LibSavedVars:GetRawDataTable(savedVars)
    if rawDataTable then
        table.insert(subTables, rawDataTable)
    end

    table.insert(subTables, { __dataSource = ds })
    protected.zoDebug(debugMode, "subTables: <<1>>, #subTables: <<2>>",subTables, #subTables)

    local subTableIndex, subTable = 1, subTables[1]
    return
        function(_, key)
            if key == nil then
                subTableIndex, subTable = 1, subTables[1]
            end
            local value
            repeat
                protected.zoDebug(debugMode, "subtableIndex: <<1>>, subTable: <<2>>, key: <<3>>",
                                subTableIndex, subTable, key)
                key, value = rawnext(subTable, key)
                if key == nil then
                    subTableIndex, subTable = subTableIndex + 1, subTables[subTableIndex + 1]
                end
            until key ~= nil or not subTable
            protected.zoDebug(debugMode, "key: <<1>>, value: <<2>>", key, value)
            if not subTable then
                ds.iterator = nil
            end
            return key, value
        end,
        self,
        nil
end

--[[ Works like the # operator. Gets the number of saved vars stored in the active internal ZO_SavedVars instance for 
     the currently logged in character. The same caveats as # apply, i.e. it is not reliable except for tables 
     stored as a numerically indexed array beginning with index 1 and having no gaps.
     Provided as a separate method, because overriding the # operator is not supported in Lua 5.1.
--]]
function LSV_Data:GetLength()
    if not self then return 0 end
    protected.zoDebug(debugMode, "LSV_Data:GetLength()")

    local accountActive = LSV_Data:GetAccountSavedVarsActive()
    if accountActive then
        if not self.account then return 0 end
        return #self.account:LoadRawTableData()
    end

    if not self.character then return 0 end
    local rawCharacterDataTable = self.character:LoadRawTableData()
    if not self.pinnedAccountKeys then
        return #rawCharacterDataTable
    end

    -- Length is only valid on contiguous numeric keys.
    -- If the pinned keys and nonpinned keys form such a sequence, then the # operator is not trustworthy for the 
    -- individual pieces.  We calculate length directly here.

    local i = 1
    while self.pinnedAccountKeys[i] ~= nil 
          or rawCharacterDataTable[i] ~= nil
    do
        i = i + 1
    end
    return i - 1
end


--[[ Returns an "Account-wide Settings" checkbox control configuration table for a LibAddonMenu-2 panel, 
     localized for English, French, German, Japanese and Russian.
     
     Defaults to the value of self.__dataSource.defaultToAccount.
     
     initializeCharacterWithAccount: if set to true, whenever character-specific settings are toggled on (i.e. the 
                                     account-wide checkbox is toggled off), copy any account-wide settings that are not 
                                     defined in the character-specific saved vars from the account saved vars.
                                     If set to false, toggling to character-specific settings inializes any undefined 
                                     saved vars with default values.
                                     (default: true)
--]]
function LSV_Data:GetLibAddonMenuAccountCheckbox(initializeCharacterWithAccount)

    if not self then return end
    protected.zoDebug(debugMode, "LSV_Data:GetLibAddonMenuAccountCheckbox(<<1>>)", initializeCharacterWithAccount)

    if initializeCharacterWithAccount == nil then
        initializeCharacterWithAccount = true
    end

    -- Account-wide settings
    return {
        type    = "checkbox",
        name    = GetString(SI_LSV_ACCOUNT_WIDE),
        tooltip = GetString(SI_LSV_ACCOUNT_WIDE_TT),
        getFunc = function() 
                      self:LoadAllSavedVars()
                      return self:GetAccountSavedVarsActive()
                  end,
        setFunc = function(value) 
                      self:LoadAllSavedVars()
                      self:SetAccountSavedVarsActive(value, initializeCharacterWithAccount)
                  end,
        default = function()
                      if self.__dataSource.active and rawget(self.__dataSource.active, "savedVars") then
                          return rawget(self.__dataSource.active, "keyType") == LIBSAVEDVARS_ACCOUNT_KEY
                      else
                          return self.__dataSource.defaultToAccount
                      end
                  end
    }
end

--[[ Gets a table containing all underlying LSV_SavedVarsManager instances for the given scope.
     
     scope: LIBSAVEDVARS_SCOPE_CHARACTER, LIBSAVEDVARS_SCOPE_ACCOUNT or '*' for all scopes. Defaults to '*'.
--]]
function LSV_Data:GetSavedVarsManagers(scope)
    protected.zoDebug(debugMode, "LSV_Data:GetSavedVarsManagers(<<1>>)", scope)

    local wildcard = not scope or scope == "*"
    validateScope(scope)
    local ds = self.__dataSource
    local savedVarManagers = { }
    if (wildcard or scope == "character") and ds.character then
        table.insert(savedVarManagers, ds.character)
    end
    if (wildcard or scope == "account") and ds.account then
        table.insert(savedVarManagers, ds.account)
    end
    protected.zoDebug(debugMode, "<<1>> saved var managers found", #savedVarManagers)
    return savedVarManagers
end

--[[ Forces the loading of all underlying ZO_SavedVars instances instead of waiting for them to be lazy-loaded.
--]]
function LSV_Data:LoadAllSavedVars()
    if not self then return end

    protected.zoDebug(debugMode, "LSV_Data:LoadAllSavedVars()")

    local ds = self.__dataSource
    -- Lazy load character saved vars
    if ds.character and ds.character.savedVars then end
    -- Lazy load account saved vars
    if ds.account and ds.account.savedVars then end

    return self
end

--[[ Moves a legacy saved var with the specified info to one or more new saved vars with their own specified info.
     
     Can be chained with other transformations like :Version(), :RemoveSettings() and :RenameSettings().
     
     See LibSavedVars.lua => LibSavedVars:Migrate() for full documentation, since this method works the same, just 
     without the toSavedVarsInfo parameters.
--]]
function LSV_Data:MigrateFrom(fromSavedVarsInfo, copyToAllServers)

    if not fromSavedVarsInfo.keyType then
        fromSavedVarsInfo.keyType = LIBSAVEDVARS_CHARACTER_NAME_KEY
    end

    protected.zoDebug(debugMode, "LSV_Data:MigrateFrom(<<1>> (<<2>>), <<3>>)",
            fromSavedVarsInfo, fromSavedVarsInfo and #fromSavedVarsInfo or nil, copyToAllServers)

    local from
    local ds = self.__dataSource
    if ds.account then
        protected.zoDebug(debugMode, "ds.account block entered")
        if copyToAllServers == nil then
            copyToAllServers = ds.account:IsProfileWorldName()
        end
        local profile = ds.account.profile
        local to
        to, from = 
            protected.MigrateToMegaserverProfiles(
                nil,
                fromSavedVarsInfo, 
                copyToAllServers,
                ds.account
            )
        if to then
            protected.zoDebug(debugMode, "Saving account saved var manager for profile ", profile, " as ",
                            to[profile])
            ds.account = to[profile]
        else
            protected.zoDebug(debugMode, "toSavedVars was nil")
        end
    end

    if ds.character 
       and (fromSavedVarsInfo.keyType ~= LIBSAVEDVARS_ACCOUNT_KEY
            or not ds.defaultToAccount)
    then
        protected.zoDebug(debugMode, "ds.character block entered")
        local profile = ds.character.profile
        local to
        to, from = 
            protected.MigrateToMegaserverProfiles(
                nil,
                fromSavedVarsInfo, 
                nil,
                ds.character
            )
        if to then
            protected.zoDebug(debugMode, "Saving character saved var manager as ", to[profile])
            ds.character = to[profile]
        else
            protected.zoDebug(debugMode, "toSavedVars was nil")
        end
    end

    protected.zoDebug(debugMode, "Migration complete.")
    
    return self
end

--[[ Same as MigrateFrom, but with a default keyType set to LIBSAVEDVARS_ACCOUNT_KEY.
--]]
function LSV_Data:MigrateFromAccountWide(fromSavedVarsInfo, copyToAllServers)
    protected.zoDebug(debugMode, "LSV_Data:MigrateFromAccountWide(<<1>> (<<2>>), <<3>>)",
                    fromSavedVarsInfo, fromSavedVarsInfo and #fromSavedVarsInfo or nil, copyToAllServers)
    fromSavedVarsInfo.keyType = LIBSAVEDVARS_ACCOUNT_KEY
    return self:MigrateFrom(fromSavedVarsInfo, copyToAllServers)
end

--[[ Same as MigrateFrom, but with a default keyType set to LIBSAVEDVARS_CHARACTER_ID_KEY.
--]]
function LSV_Data:MigrateFromCharacterId(fromSavedVarsInfo, copyToAllServers)
    protected.zoDebug(debugMode, "LSV_Data:MigrateFromCharacterId(<<1>> (<<2>>), <<3>>)",
                    fromSavedVarsInfo, fromSavedVarsInfo and #fromSavedVarsInfo or nil, copyToAllServers)
    fromSavedVarsInfo.keyType = LIBSAVEDVARS_CHARACTER_ID_KEY
    return self:MigrateFrom(fromSavedVarsInfo, copyToAllServers)
end

--[[ Same as MigrateFrom, but with a default keyType set to LIBSAVEDVARS_CHARACTER_ID_NAME.
--]]
function LSV_Data:MigrateFromCharacterName(fromSavedVarsInfo, copyToAllServers)
    protected.zoDebug(debugMode, "LSV_Data:MigrateFromCharacterName(<<1>> (<<2>>), <<3>>)",
                    fromSavedVarsInfo, fromSavedVarsInfo and #fromSavedVarsInfo or nil, copyToAllServers)
    fromSavedVarsInfo.keyType = LIBSAVEDVARS_CHARACTER_NAME_KEY
    return self:MigrateFrom(fromSavedVarsInfo, copyToAllServers)
end

--[[ Removes a list of settings from all saved vars tracked by this data instance of a given scope
     when upgrading to the given version number. Has no effect on saved vars at or above the given version.
     
     version:          Settings are only removed from saved vars below this version number.
     
     scope:            (optional) LIBSAVEDVARS_SCOPE_CHARACTER, LIBSAVEDVARS_SCOPE_ACCOUNT or '*' for all scopes. 
                                  Defaults to '*'.
     
     settingsToRemove: Either a table containing a list of string setting names to remove, or a single string 
                       setting name. If a string is given, then additional strings can be provided as extra parameters.
--]]
function LSV_Data:RemoveSettings(version, scope, settingsToRemove, ...)
    
    assert(type(version) == "number", 
           "Invalid type for argument 'version'. Expected 'number'. Got '" .. type(version) .. "' instead.")
    local params = {...}
    if scope ~= nil and type(scope) ~= "number" then
        table.insert(params, 1, settingsToRemove)
        settingsToRemove = scope
        scope = nil
    end
    if type(settingsToRemove) == "string" then
        table.insert(params, 1, settingsToRemove)
        settingsToRemove = params
    end
        
    protected.zoDebug(debugMode, "LSV_Data:RemoveSettings(<<1>>, <<2>>, <<3>> (<<4>>))",
                    version, scope, tostring(settingsToRemove), settingsToRemove and #settingsToRemove or nil)
    validateScope(scope)
    local svManagers = self:GetSavedVarsManagers(scope)
    for _, svManager in rawipairs(svManagers) do
        svManager:RemoveSettings(version, settingsToRemove)
    end
    
    return self
end

--[[ Changes the names of a list of settings in all saved vars tracked by this data instance of a given scope
     when upgrading to the given version number. Has no effect on saved vars at or above the given version.
     
     version:   Settings are only renamed on saved vars below this version number.
     
     scope:     (optional) LIBSAVEDVARS_SCOPE_CHARACTER, LIBSAVEDVARS_SCOPE_ACCOUNT or '*' for all scopes. 
                           Defaults to '*'.
     
     renameMap: A key-value table containing a mapping of old setting names (keys) to new setting names (values).
     
     callback:   (optional) A function to be called on saved vars values right before they are renamed. 
                           Used by RenameSettingsAndInvert().
--]]
function LSV_Data:RenameSettings(version, scope, renameMap, callback)

    if scope ~= nil and type(scope) ~= "number" and scope ~= "*" then
        callback = renameMap
        renameMap = scope
        scope = nil
    end
    protected.zoDebug(debugMode, "LSV_Data:RenameSettings(<<1>>, <<2>>, <<3>>, <<4>>)",
                    version, scope, renameMap, callback)
    validateScope(scope)
    local svManagers = self:GetSavedVarsManagers(scope)
    for _, svManager in rawipairs(svManagers) do
        svManager:RenameSettings(version, renameMap, callback)
    end

    return self
end

--[[ Changes the names of a list of boolean settings and inverts them in all saved vars tracked by this data instance of 
     a given scope when upgrading to the given version number. Has no effect on saved vars at or above the given version.
     
     version:   Settings are only renamed on saved vars below this version number.
     
     scope:     (optional) LIBSAVEDVARS_SCOPE_CHARACTER, LIBSAVEDVARS_SCOPE_ACCOUNT or '*' for all scopes. 
                           Defaults to '*'.
     
     renameMap: A key-value table containing a mapping of old setting names (keys) to new setting names (values).
--]]
function LSV_Data:RenameSettingsAndInvert(version, scope, renameMap)
    protected.zoDebug(debugMode, "LSV_Data:RenameSettingsAndInvert(<<1>>, <<2>>, <<3>>)",
                    version, scope, renameMap)
    return self:RenameSettings(version, scope, renameMap, protected.Invert)
end

--[[ Toggles whether account-wide settings or character-specific settings are active.
     
     accountActive:                  True to user account-wide settings for the current character; 
                                     false to use character-specific settings
                                     
     initializeCharacterWithAccount: If set to true and accountActive is false, copy any account-wide settings that are 
                                     not defined in the character-specific saved vars from the account saved vars
--]]
function LSV_Data:SetAccountSavedVarsActive(accountActive, initializeCharacterWithAccount)

    if not self then return end
    protected.zoDebug(debugMode, "LSV_Data:SetAccountSavedVarsActive(<<1>>, <<2>>)",
                    accountActive, initializeCharacterWithAccount)

    local ds = self.__dataSource

    if not ds.character 
       or not ds.account
       or not ds.character.savedVars 
       or not ds.character.savedVars[LIBNAME] 
    then 
        return self
    end

    ds.character.savedVars[LIBNAME].accountSavedVarsActive = accountActive

    initializeCharacterWithAccount = initializeCharacterWithAccount or ds.defaultToAccount

    if accountActive then
        ds.active = ds.account
        return self
    end

    ds.active = ds.character

    local characterRawDataTable = ds.character:LoadRawTableData()

    if initializeCharacterWithAccount and ds.account.savedVars then

        local accountVars = ds.account:LoadRawTableData()
        if ds.pinnedAccountKeys and accountVars then
            accountVars = LSV_Data.tableDiffKeys(accountVars, ds.pinnedAccountKeys)
        end

        if debugMode then
            protected.zoDebug(debugMode, "Copying the following settings from account-wide scope to character settings:")
            if accountVars then
                for key, value in pairs(accountVars) do
                    protected.zoDebug(debugMode, "<<1>>: <<2>>", key, tostring(value))
                end
            end
        end

        LibSavedVars:DeepSavedVarsCopy(accountVars, characterRawDataTable, DO_NOT_OVERWRITE)
    else
        LibSavedVars:DeepSavedVarsCopy(ds.character.defaults, characterRawDataTable, DO_NOT_OVERWRITE)
    end
    
    return self
end

--[[ Toggles whether to output LSV_Data debug messages to chat at runtime.
     
     enable: True enables debug messages for LSV_Data. False disables them.
--]]
function LSV_Data:SetDebugMode(enable)
    debugMode = enable
    return self
end
function LSV_Data:GetDebugMode()
    return debugMode
end

--[[ Upgrades all saved vars tracked by this data instance of a given scope to the given version number.  
     Has no effect on saved vars at or above the given version.
     
     version:         Settings are only upgraded on saved vars below this version number.
     
     scope:           (optional) LIBSAVEDVARS_SCOPE_CHARACTER, LIBSAVEDVARS_SCOPE_ACCOUNT or '*' for all scopes. 
                                 Defaults to '*'.
     
     onVersionUpdate: Upgrade script function with the signature function(rawDataTable) end to be run before updating
                      saved vars version. You can run any settings transforms in here.
--]]
function LSV_Data:Version(version, scope, onVersionUpdate)

    if type(scope) == "function" then
        onVersionUpdate = scope
        scope = nil
    end
    protected.zoDebug(debugMode, "LSV_Data:Version(<<1>>, <<2>>, <<3>>)", version, scope, onVersionUpdate)
    validateScope(scope)
    local svManagers = self:GetSavedVarsManagers(scope)
    for _, svManager in rawipairs(svManagers) do
        svManager:Version(version, onVersionUpdate)
    end

    return self

end



-----------------------------------------------------------------------------------
--
--          Meta Methods
--
--          This is where the magic awesomesauce happens that allows 
--          LSV_Data instances to be used with all the same 
--          operators/syntax as the internal ZO_SavedVars instances themselves.
--          
--          Full support included for:
--
--            data[key]          -- Get
--            data.key           -- Get
--            data[key] = value  -- Set
--            data.key = value   -- Set
--           
-----------------------------------------------------------------------------------

--[[ Allows data[key] and data.key to grab their values from the active internal ZO_SavedVars instance for the 
     currently logged in character
--]]
function LSV_Data.__index(data, key)

    protected.zoDebug(debugMode, "LSV_Data.__index(<<1>>, <<2>>)", data, key)

    if not data then return end

    -- Always use metatable for function lookups, to avoid lazy loading saved vars earlier than needed
    local meta = getmetatable(data)
    if meta and type(meta[key]) == "function" then
        return meta[key]
    end

    -- Get toggleable values from active saved vars
    local savedVars = LSV_Data.GetActiveSavedVars(data, key)
    if savedVars then
        local value = savedVars[key]
        if value ~= nil then
            return value
        end
    end

    -- Metatable fallback for non-function values
    if meta then
        return meta[key]
    end
end

--[[ Allows data[key] = value and data.key = value to set values on the active internal ZO_SavedVars instance for the 
     currently logged in character
--]]
function LSV_Data.__newindex(data, key, value)

    protected.zoDebug(debugMode, "LSV_Data.__newindex(<<1>>, <<2>>, <<3>>)", data, key, value)

    if not data then return end

    local savedVars = LSV_Data.GetActiveSavedVars(data, key)
    if savedVars then
        savedVars[key] = value
    end
end


---------------------------------------
--
--          Private Members
-- 
---------------------------------------
--[[ create and initialize the account structure for a datasource ]]
function initAccountWide(self, savedVariableTable, version, namespace, defaults, profile, displayName)

    self.__dataSource.account = 
        LSV_SavedVarsManager:New(
            {
                keyType = LIBSAVEDVARS_ACCOUNT_KEY,
                name=savedVariableTable,
                version=version,
                namespace=namespace,
                defaults=defaults,
                profile=profile or GetWorldName(),
                displayName=displayName
            }
        )
    self.__dataSource.account:EnsureRawTableData()

end

--[[ create and initialize the character structure for a datasource ]]
function initCharacterSettings(self, savedVariableTable, version, namespace, defaults, trimDefaults, profile, displayName, 
                               characterName, characterId, characterKeyType)

    self.__dataSource.character = 
        LSV_SavedVarsManager:New(
            {
                keyType=characterKeyType or LIBSAVEDVARS_CHARACTER_ID_KEY,
                name=savedVariableTable,
                version=version,
                namespace=namespace,
                defaults=defaults,
                trimDefaults=trimDefaults,
                profile=profile or GetWorldName(),
                displayName=displayName,
                characterName=characterName,
                characterId=characterId
            }
        )
    self.__dataSource.character:EnsureRawTableData()
end

--[[ create a account/char toggle for the datasource ]]
function initToggle(self)

    local ds = self.__dataSource

    if ds.character == nil then
        protected.zoDebug(debugMode, "Trying to initialized toggle failed. No character-specific saved vars manager found.")
        return
    end

    if ds.account == nil then
        protected.zoDebug(debugMode, "Trying to initialized toggle failed. No account-wide saved vars manager found.")
        return
    end

    local characterRawDataTable = ds.character:LoadRawTableData() or nil
    if not characterRawDataTable
       or (characterRawDataTable[LIBNAME] 
           and characterRawDataTable[LIBNAME].accountSavedVarsActive)
       or (ds.defaultToAccount 
           and (not characterRawDataTable[LIBNAME] 
                or characterRawDataTable[LIBNAME].accountSavedVarsActive ~= false)
          )
    then
        ds.active = ds.account
    else
        ds.active = ds.character

        -- Ensure that active character settings receive new default values from account scope
        if (not ds.character.defaults or not next(ds.character.defaults))
           and ds.account.defaults and next(ds.account.defaults)
        then
            ds.character.defaults = ZO_ShallowTableCopy(ds.account.defaults)
        end
    end

    ds.character.defaults[LIBNAME] = {
        accountSavedVarsActive = ds.defaultToAccount
    }

    ds.character.trimDefaults[LIBNAME] = {
        accountSavedVarsActive = ds.defaultToAccount
    }
end

function LSV_Data.shiftOptionalParams(version, namespace, defaults, defaultToAccount, profile, displayName, characterName, characterId, characterKeyType)

    if version ~= nil and type(version) ~= "number" then
        return LSV_Data.shiftOptionalParams(nil, version, namespace, defaults, defaultToAccount, profile, displayName, characterName, characterId)
    elseif namespace ~= nil and type(namespace) ~= "string" then
        return LSV_Data.shiftOptionalParams(version, nil, namespace, defaults, defaultToAccount, profile, displayName, characterName, characterId)
    elseif defaults ~= nil and type(defaults) ~= "table" then
        return LSV_Data.shiftOptionalParams(version, namespace, nil, defaults, defaultToAccount, profile, displayName, characterName, characterId)
    elseif defaultToAccount ~= nil and type(defaultToAccount) ~= "boolean" then
        return LSV_Data.shiftOptionalParams(version, namespace, defaults, true, defaultToAccount, profile, displayName, characterName, characterId)
    end

    return version, namespace, defaults, defaultToAccount, profile, displayName, characterName, characterId, characterKeyType
end

--[[ Gets a list of all key value pairs in table1 that do not have corresponding keys in table2.
--]]
function LSV_Data.tableDiffKeys(table1, table2)
    local diff = { }
    for key1, value1 in pairs(table1) do
        if table2[key1] == nil then
            diff[key1] = value1
        end
    end
    return diff
end

---[[ Gets a list of all key value pairs in tbl that have corresponding keys in keyTable.
--]]
function LSV_Data.tableFilterKeys(tbl, keyTable)
    local filtered = {}
    for key, value in pairs(tbl) do
        if keyTable[key] ~= nil then
            filtered[key] = value
        end
    end
    return filtered
end

--[[ Throw an error message if the scope is not valid, i.e.
        numbers outside of [LIBSAVEDVARS_SCOPE_MIN, LIBSAVEDVARS_SCOPE_MAX]
        strings not equal to "*"
    For valid values, the function simply returns.
    Nil values for scope will be interpreted as "*".
--]]
function validateScope(scope)
    if scope == nil then
        scope = "*"
    end
    if type(scope) == "string" and scope ~= "*" then
        error("Invalid type for parameter 'scope'. Expected 'number'. Got '" .. type(scope) .. "' instead.", 2)
    end
    if type(scope) == "number" and (scope < LIBSAVEDVARS_SCOPE_MIN or scope > LIBSAVEDVARS_SCOPE_MAX) then
        error("Invalid value for parameter 'scope'.  Valid values must be between " .. tostring(LIBSAVEDVARS_SCOPE_MIN)
              .. " and " .. tostring(LIBSAVEDVARS_SCOPE_MAX) .. ".", 2)
    end
end