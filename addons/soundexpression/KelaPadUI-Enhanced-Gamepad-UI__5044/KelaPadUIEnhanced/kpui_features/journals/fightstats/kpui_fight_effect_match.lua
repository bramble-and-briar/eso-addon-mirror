-- KelaPadUI Fight Stats: which buffs and debuffs the pages know. The lists,
-- and how each effect is recognised on any client, are data in
-- kpui_data/kpui_fight_effects.lua; this matches an ability to its entry by
-- the names of its known ids (in the client's language), its English name, or
-- its icon, and gives the tally the filters it records with.

local ROLE_DD, ROLE_TANK, ROLE_HEAL = LFG_ROLE_DPS, LFG_ROLE_TANK, LFG_ROLE_HEAL
local CONTENT_BATTLEGROUND = KPUI_FIGHT_STATS.CONTENT_BATTLEGROUND
local DEBUFFS = KPUI_FIGHT_EFFECTS.debuffs
local BUFFS = KPUI_FIGHT_EFFECTS.buffs

local function GetAbilityText(id)
	return zo_strformat(SI_ABILITY_NAME, GetAbilityName(id))
end

local Effects = {}
KPUI_FIGHT_STATS.Effects = Effects
do
	local indexes = {}
	-- What the client calls an alias and its icon, learned from its ids or from
	-- the first effect that matched it.
	local aliasNames, aliasIcons = {}, {}

	-- "ability_buff_major_sorcery" for an effect with that icon.
	local function GetIconKey(abilityId)
		local icon = GetAbilityIcon(abilityId)
		return type(icon) == "string" and zo_strlower(icon):match("([^/]+)%.dds$") or nil
	end

	-- Names and icon keys of one list of entries, built once.
	local function GetIndex(entries)
		local index = indexes[entries]
		if index then
			return index
		end
		index = { names = {}, icons = {}, found = {} }
		indexes[entries] = index
		for _, entry in ipairs(entries) do
			for _, alias in ipairs(entry.aliases) do
				local match = { entry = entry, alias = alias }
				for _, id in ipairs(alias.ids or {}) do
					local name = GetAbilityText(id)
					if name ~= "" then
						local key = zo_strlower(name)
						index.names[key] = index.names[key] or match
						aliasNames[alias] = aliasNames[alias] or name
						aliasIcons[alias] = aliasIcons[alias] or GetAbilityIcon(id)
					end
				end
				local key = zo_strlower(alias.name)
				index.names[key] = index.names[key] or match
				if alias.icon then
					index.icons[alias.icon] = index.icons[alias.icon] or match
				end
			end
		end
		return index
	end

	local function PrepareAll()
		GetIndex(DEBUFFS)
		GetIndex(BUFFS)
	end

	-- The entry an ability is, or nil: by its name (the known ids' names in the
	-- client's language, then the English names), then by its icon.
	function Effects.Find(entries, abilityId)
		local index = GetIndex(entries)
		local match = index.found[abilityId]
		if match == nil then
			local name = GetAbilityText(abilityId)
			match = name ~= "" and index.names[zo_strlower(name)] or nil
			if not match then
				local iconKey = GetIconKey(abilityId)
				match = iconKey and index.icons[iconKey] or nil
			end
			if match then
				if name ~= "" then
					aliasNames[match.alias] = aliasNames[match.alias] or name
				end
				aliasIcons[match.alias] = aliasIcons[match.alias] or GetAbilityIcon(abilityId)
			end
			index.found[abilityId] = match or false
		end
		return match and match.entry or nil
	end

	-- "Major Brutality / Major Sorcery", in the client's language where known.
	function Effects.GetName(entry)
		PrepareAll()
		local names, seen = {}, {}
		for _, alias in ipairs(entry.aliases) do
			local name = aliasNames[alias] or alias.name
			if not seen[name] then
				seen[name] = true
				names[#names + 1] = name
			end
		end
		return table.concat(names, " / ")
	end

	function Effects.GetIcon(entry)
		PrepareAll()
		for _, alias in ipairs(entry.aliases) do
			if aliasIcons[alias] then
				return aliasIcons[alias]
			end
		end
		return nil
	end

	-- An unknown role is treated as a damage dealer.
	function Effects.IsForRole(entry, roleId, content)
		if entry.monsters and content == CONTENT_BATTLEGROUND then
			return false
		end
		if not entry.roles then
			return true
		end
		local role = (roleId == ROLE_TANK or roleId == ROLE_HEAL) and roleId or ROLE_DD
		for _, entryRole in ipairs(entry.roles) do
			if entryRole == role then
				return true
			end
		end
		return false
	end
end

-- The tally records buffs on group members only when they are an essential
-- buff (or the proc of a gear set).
function KPUI_FIGHT_STATS.InstallEffectFilter()
	KPUI_FIGHT_TALLY.SetEffectFilter(function(abilityId)
		return Effects.Find(BUFFS, abilityId) ~= nil
	end)
	-- Hits are weighed by what the target's debuffs take off it at that moment.
	-- The key is shared by every source of one effect, so it counts once.
	KPUI_FIGHT_TALLY.SetDebuffProvider(function(abilityId)
		local entry = Effects.Find(DEBUFFS, abilityId)
		if entry and ((entry.pen or 0) > 0 or (entry.crit or 0) > 0) then
			return entry.key, entry.pen, entry.crit, entry.status == true
		end
		return nil
	end)
end

