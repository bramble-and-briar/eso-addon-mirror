Teleport.Aliases = {}

local info  = Teleport.info
local color = Teleport.color
local C     = Teleport.COLORS

--------------------------------------------------------------------------------

local ZONE_ALIASES = {
        -- Zones https://en.uesp.net/wiki/Online:Zones#Overworld_Zones
        -- ("The X" and "Label: X" get a short name automatically, see generateZoneAliases)
        ["Elsweyr"                  ] = "Northern Elsweyr",
        ["Skyrim"                   ] = "Western Skyrim",
        ["Weald"                    ] = "West Weald",
    }

local DUNGEON_ALIASES = {
        -- Trials https://en.uesp.net/wiki/Online:Trials
        ["ss"  ] = "Sunspire",
        ["cr"  ] = "Cloudrest",
        ["rg"  ] = "Rockgrove",
        ["dsr" ] = "Dreadsail Reef",

        -- Arenas https://en.uesp.net/wiki/Online:Arenas
        ["dsa" ] = "Dragonstar Arena",
        ["brp" ] = "Blackrose Prison",

        -- Base Game Dungeons https://en.uesp.net/wiki/Online:Group_Dungeons
        ["sc"  ] = "Spindleclutch I",
        ["sc1" ] = "Spindleclutch I",
        ["sc2" ] = "Spindleclutch II",
        ["vf"  ] = "Volenfell",

        -- DLC Dungeons https://en.uesp.net/wiki/Online:Group_Dungeons
        ["brf" ] = "Bloodroot Forge",
        ["scp" ] = "Scalecaller Peak",
        ["mk"  ] = "Moon Hunter Keep",
        ["fv"  ] = "Frostvault",
        ["mgf" ] = "Moongrave Fane",
        ["ir"  ] = "Icereach",
        ["cd"  ] = "The Cauldron",
        ["dc"  ] = "The Dread Cellar",
    }
	
-------------------------------------------------------------------------------

-- Generated aliases never replace a hardcoded one or an earlier generated one.
-- Names come in alphabetical order, so on a clash the alphabetically first
-- name keeps the alias; the hardcoded list above settles the clashes that matter.
local function addGeneratedDungeonAlias(alias, name)
	if #alias > 1 and not DUNGEON_ALIASES[alias] then
		DUNGEON_ALIASES[alias] = name
	end
end

-- Initials of the words (split on spaces and dashes), lowercase:
--   Kyne's Aegis -> ka, White-Gold Tower -> wgt
-- "The " can be left out:
--   The Dread Cellar -> tdc, dc
-- Numbered dungeons get the number as a digit; the bare alias is part I:
--   Fungal Grotto I -> fg, fg1    Fungal Grotto II -> fg2
--   The Banished Cells II -> tbc2, bc2
function Teleport.Aliases:generateDungeonAliases(dungeons)
	for _, name in ipairs(dungeons) do
		local number
		if Teleport.Helpers:endsWith(name, " II") then
			number = "2"
		elseif Teleport.Helpers:endsWith(name, " I") then
			number = "1"
		end

		local alias = Teleport.Helpers:initialsFromSpaceAndDash(name)
		if number then
			alias = Teleport.Helpers:removeLastChar(alias) -- the "i" of I / II
		end

		local variants = { alias }
		if Teleport.Helpers:startsWith(name, "The ") then
			table.insert(variants, Teleport.Helpers:removeFirstChar(alias))
		end

		for _, variant in ipairs(variants) do
			if number then
				addGeneratedDungeonAlias(variant .. number, name)
			end
			if number ~= "2" then
				addGeneratedDungeonAlias(variant, name)
			end
		end
	end
end

-- "The Reach" -> "Reach", "Blackreach: Greymoor Caverns" -> "Greymoor Caverns"
function Teleport.Aliases:generateZoneAliases(zones)
	for _, name in ipairs(zones) do
		if Teleport.Helpers:startsWith(name, "The ") or Teleport.Helpers:startsWithLabel(name) then
			ZONE_ALIASES[Teleport.Helpers:removeFirstWord(name)] = name
		end
	end
end

function Teleport.Aliases:getZoneAliases()
	return ZONE_ALIASES
end

-- { { alias = , name = }, ... } sorted by name, then alias
function Teleport.Aliases:getDungeonAliases()
	local list = {}
	for alias, name in pairs(DUNGEON_ALIASES) do
		table.insert(list, { alias = alias, name = name })
	end
	table.sort(list, function(a, b)
		if a.name ~= b.name then return a.name < b.name end
		if #a.alias ~= #b.alias then return #a.alias < #b.alias end
		return a.alias < b.alias
	end)
	return list
end

-------------------------------------------------------------------------------    

local SAVED_VARS
function Teleport.Aliases:setSavedVars(savedVars)
    SAVED_VARS = savedVars
    -- Input is lowercased before the lookup, so aliases saved with capital
    -- letters by older versions could never be used. Store them lowercased.
    local mixedCase = {}
    for alias in pairs(savedVars) do
        if string.lower(alias) ~= alias then
            table.insert(mixedCase, alias)
        end
    end
    for _, alias in ipairs(mixedCase) do
        local lower = string.lower(alias)
        if savedVars[lower] == nil then
            savedVars[lower] = savedVars[alias]
        end
        savedVars[alias] = nil
    end
end

-------------------------------------------------------------------------------    

function Teleport.Aliases:getDungeonByAlias(alias)
    alias = string.lower(alias)
    local expansion = DUNGEON_ALIASES[alias]
    if expansion then return expansion, nil end
    local difficulty = string.sub(alias, 1, 1)
    if difficulty == 'n' or difficulty == 'v' or difficulty == 'r' then
        expansion = DUNGEON_ALIASES[string.sub(alias, 2)]
        if expansion then return expansion, difficulty end
    end
    
    return nil, nil
end

-------------------------------------------------------------------------------    

function Teleport.Aliases:expandUserDefined(alias)
    alias = string.lower(alias)
    return SAVED_VARS[alias] or alias
end

function Teleport.Aliases:listAliases()
    local aliases = {}
    for alias in pairs(SAVED_VARS) do
        table.insert(aliases, alias)
    end
    if #aliases == 0 then
        info("No aliases yet. Add one with " .. color("/tp --add <alias> <destination>", C.ALIAS))
        return
    end
    table.sort(aliases)
    info("Your aliases:")
    for _, alias in ipairs(aliases) do
        info(color(alias, C.ALIAS) .. ' => ' .. color(SAVED_VARS[alias], C.ALIAS))
    end
end

-- Built-in dungeon/trial/arena aliases, one line per instance.
function Teleport.Aliases:listDungeonAliases()
    local lines, order = {}, {}
    for _, entry in ipairs(self:getDungeonAliases()) do
        if not lines[entry.name] then
            lines[entry.name] = {}
            table.insert(order, entry.name)
        end
        table.insert(lines[entry.name], entry.alias)
    end
    info("Dungeon, trial and arena aliases (prefix with n, v or r for normal, veteran or reset):")
    for _, name in ipairs(order) do
        info(color(name, C.DUNGEON) .. ': ' .. color(table.concat(lines[name], ', '), C.ALIAS))
    end
end

function Teleport.Aliases:addAlias(alias)
    if not alias or alias == '' then
        info("USAGE: /tp --add " .. color("<alias-name> <alias-expansion>", C.ALIAS))
        return
    end
    local expansion
    alias, expansion = Teleport.Helpers:splitOnSpace(alias)
    alias = alias and string.lower(alias)
    if not alias or alias == '' or expansion == '' then
        info("USAGE: /tp --add " .. color("<alias-name> <alias-expansion>", C.ALIAS))
        return
    end
    if SAVED_VARS[alias] then
        info("Alias " .. color(alias, C.NOT_FOUND) .. " already exists, remove it first:")
        info(color(alias, C.ALIAS) .. ' => ' .. color(SAVED_VARS[alias], C.ALIAS))
        return
    end

    SAVED_VARS[alias] = expansion
    info("New alias added:")
    info(color(alias, C.ALIAS) .. ' => ' .. color(expansion, C.ALIAS))
end

function Teleport.Aliases:removeAlias(alias)
    if not alias or alias == '' then
        info("USAGE: /tp --remove " .. color("<alias-name>", C.ALIAS))
        return
    end
    alias = string.lower(alias)
    if not SAVED_VARS[alias] then
        info("Alias " .. color(alias, C.NOT_FOUND) .. " doesn't exist")
        return
    end

    local expansion = SAVED_VARS[alias]
    SAVED_VARS[alias] = nil
    info("Alias removed:")
    info(color(alias, C.ALIAS) .. ' => ' .. color(expansion, C.ALIAS))
end
