--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local SS = APHSearchCore

local providers = {}
local rows_by_scope = {}
local building = {}
local scope_kb, scope_used, use_tick = {}, {}, 0
SS.INDEX_BUDGET_KB = 10 * 1024
SS.INDEX_BUDGET_ALL_KB = 30 * 1024
local searching_all = false
local ROW_OVERHEAD_BYTES = 160

local function EstimateKB(rows)
	local bytes = 0
	for _, row in ipairs(rows) do
		bytes = bytes + ROW_OVERHEAD_BYTES + #(row.label or "") + #(row.detail or "") + #(row.where or "")
	end
	return bytes / 1024
end

local function Touch(scope)
	use_tick = use_tick + 1
	scope_used[scope] = use_tick
end

local function Trim(scope)
	local total = 0
	for built in pairs(rows_by_scope) do total = total + (scope_kb[built] or 0) end
	local budget = searching_all and SS.INDEX_BUDGET_ALL_KB or SS.INDEX_BUDGET_KB
	while total > budget do
		local oldest, oldest_at
		for built in pairs(rows_by_scope) do
			if built ~= scope and (not oldest_at or (scope_used[built] or 0) < oldest_at) then
				oldest, oldest_at = built, scope_used[built] or 0
			end
		end
		if not oldest then return end
		total = total - (scope_kb[oldest] or 0)
		rows_by_scope[oldest], scope_kb[oldest] = nil, nil
	end
end

local function Store(scope, rows)
	rows_by_scope[scope] = rows
	scope_kb[scope] = EstimateKB(rows)
	Touch(scope)
	Trim(scope)
end

function SS.GetIndexKB()
	local total = 0
	for built in pairs(rows_by_scope) do total = total + (scope_kb[built] or 0) end
	return total
end
local fingerprint

SS.SCOPE_ALL = "All"

function SS.RegisterProvider(definition)
	if type(definition) ~= "table" or not definition.scope then return false end
	local spread = type(definition.buildItems) == "function" and type(definition.buildRow) == "function"
	if type(definition.build) ~= "function" and not spread then return false end
	providers[#providers + 1] = definition
	return true
end

function SS.GetProviders() return providers end

function SS.IsScopeEnabled(scope)
	if scope == nil or scope == SS.SCOPE_ALL then return true end

	local off = SS.saved and SS.saved.scopes_off
	return not (off and off[scope])
end

function SS.SetScopeEnabled(scope, enabled)
	if scope == nil or scope == SS.SCOPE_ALL then return false end
	if not SS.saved then return false end

	SS.saved.scopes_off = SS.saved.scopes_off or {}
	SS.saved.scopes_off[scope] = not enabled
	if scope == SS.SCOPE_ITEMS then
		SS.ClearIndex(scope)
		SS.WatchInventory()
	end
	return true
end

function SS.GetAllScopes()
	local scopes = {}
	for _, provider in ipairs(providers) do scopes[#scopes + 1] = provider.scope end
	return scopes
end

function SS.IsCoveredByParent(provider, scope)
	if scope ~= nil and scope ~= SS.SCOPE_ALL then return false end
	return provider.subsetOf ~= nil and SS.IsScopeEnabled(provider.subsetOf)
end

function SS.GetScopeGroups()
	return SS.SCOPE_GROUPS or {}
end

function SS.GetScopes()
	local scopes = { SS.SCOPE_ALL }
	for _, provider in ipairs(providers) do
		if SS.IsScopeEnabled(provider.scope) then scopes[#scopes + 1] = provider.scope end
	end
	return scopes
end

function SS.Fingerprint()
	local am = GetAddOnManager()
	local mode = tostring(IsInGamepadPreferredMode())
	if not am then return "none:" .. mode end

	local parts = { mode }
	for position = 1, am:GetNumAddOns() do
		local name, _, _, _, enabled, state = am:GetAddOnInfo(position)
		local version = am:GetAddOnVersion(position) or 0
		parts[#parts + 1] = string.format("%s:%s:%s:%s", name or "?", tostring(version),
			tostring(enabled), tostring(state))
	end
	return table.concat(parts, "|")
end

local REFRESH_EVERY_MS = 2000
local last_refresh

local function Refresh()
	local now = GetFrameTimeMilliseconds()
	if last_refresh and now - last_refresh < REFRESH_EVERY_MS then return end
	last_refresh = now
	local current = SS.Fingerprint()
	if fingerprint ~= current then
		rows_by_scope, building = {}, {}
		fingerprint = current
	end
end

local row_meta = {}

local function RowMeta(provider)
	local meta = row_meta[provider]
	if not meta then
		meta = { __index = { scope = provider.scope, rank = provider.rank or 9, tier = provider.tier or 1, go = provider.go } }
		row_meta[provider] = meta
	end
	return meta
end

local function Decorate(provider, built)
	local meta = RowMeta(provider)
	for _, row in ipairs(built) do setmetatable(row, meta) end
	return built
end

local function BuildRows(provider)
	if provider.buildItems then
		local rows, state = {}, {}
		local items = provider.buildItems()
		for _, item in ipairs(type(items) == "table" and items or {}) do provider.buildRow(item, rows, state) end
		return rows
	end
	return provider.build()
end

local function CachedRows(provider)
	local cached = rows_by_scope[provider.scope]
	if cached then
		Touch(provider.scope)
		return cached
	end

	local ok, built = pcall(BuildRows, provider)
	local rows = Decorate(provider, ok and type(built) == "table" and built or {})
	Store(provider.scope, rows)
	return rows
end

function SS.RowsFor(provider)
	Refresh()
	return CachedRows(provider)
end

local function BuildStep(provider)
	if not provider.buildItems then
		Refresh()
		return CachedRows(provider)
	end
	local done = rows_by_scope[provider.scope]
	if done then
		Touch(provider.scope)
		return done
	end

	local build = building[provider.scope]
	if not build then
		Refresh()
		local ok, listed = pcall(provider.buildItems)
		building[provider.scope] = { items = ok and type(listed) == "table" and listed or {}, rows = {}, state = {}, at = 0 }
		return nil
	end

	build.at = build.at + 1
	local item = build.items[build.at]
	if item ~= nil and pcall(provider.buildRow, item, build.rows, build.state) then return nil end
	building[provider.scope] = nil
	local rows = Decorate(provider, item == nil and build.rows or {})
	Store(provider.scope, rows)
	return rows
end

local PREBUILD_JOB = "APHSearchPrebuild"

function SS.StartPrebuild()
	if not LibAPH or type(LibAPH.Schedule) ~= "function" then return false end

	local at = 1
	LibAPH.Schedule(PREBUILD_JOB, function()
		searching_all = true
		local provider = providers[at]
		if not provider then
			SS.prebuilt = true
			return true
		end
		if not SS.IsScopeEnabled(provider.scope) or SS.IsScopeBuilt(provider.scope) or SS.IsCoveredByParent(provider) then
			at = at + 1
			return false
		end
		if BuildStep(provider) then at = at + 1 end
		return false
	end)
	return true
end

function SS.ClearIndex(scope)
	if scope then
		rows_by_scope[scope], scope_kb[scope], building[scope] = nil, nil, nil
	else
		rows_by_scope, scope_kb, building = {}, {}, {}
	end
	return true
end

function SS.IsScopeBuilt(scope)
	return rows_by_scope[scope] ~= nil
end

function SS.BuildIndex(force)
	if force then rows_by_scope, building = {}, {} end
	local all = {}
	for _, provider in ipairs(providers) do
		for _, row in ipairs(SS.RowsFor(provider)) do all[#all + 1] = row end
	end
	return all
end

function SS.IsIndexStale()
	return fingerprint ~= SS.Fingerprint()
end

function SS.CountByScope()
	local counts = {}
	for _, provider in ipairs(providers) do
		counts[provider.scope] = #SS.RowsFor(provider)
	end
	return counts
end

local EMPTY = {}

local function Lower(text)
	return zo_strlower(text)
end

local function WordPatterns(needle)
	local words = {}
	for word in string.gmatch(needle, "%S+") do words[#words + 1] = Lower(word) end
	return words
end

local function WordsInOrder(haystack, words)
	local at = 1
	for _, word in ipairs(words) do
		local first, last = string.find(haystack, word, at, true)
		if not first then return false end
		at = last + 1
	end
	return true
end

local function Better(a, b)
	if a.tier ~= b.tier then return a.tier < b.tier end
	if a.closeness ~= b.closeness then return a.closeness < b.closeness end
	if a.rank ~= b.rank then return a.rank < b.rank end
	return a.label < b.label
end

local function KeepBest(best, row, limit)
	local count = #best
	if count >= limit and not Better(row, best[count]) then return false end
	local at = count + 1
	while at > 1 and Better(row, best[at - 1]) do
		best[at] = best[at - 1]
		at = at - 1
	end
	best[at] = row
	if #best > limit then best[#best] = nil end
	return true
end

local function Closeness(row, provider, effects, query)
	local needle = query.needle
	local alias_exact, alias_starts = false, false
	for _, alias in ipairs(row.alias or EMPTY) do
		if alias == needle then alias_exact = true
		elseif string.sub(alias, 1, #needle) == needle then alias_starts = true end
	end

	local label = row.lower
	if not label or row.lower_of ~= row.label then
		label = Lower(row.label)
		row.lower, row.lower_of = label, row.label
	end
	if row.always then
		row.query = query.text
		if provider.describe then row.detail = provider.describe(query.text) end
		return 5
	elseif alias_exact or label == needle then
		return 1
	elseif alias_starts or string.sub(label, 1, #needle) == needle then
		return 2
	elseif string.find(label, needle, 1, true) then
		return 3
	elseif effects and row.detail and row.detail ~= "" then
		local detail = row.detail_lower
		if not detail or row.detail_lower_of ~= row.detail then
			detail = Lower(row.detail)
			row.detail_lower, row.detail_lower_of = detail, row.detail
		end
		if string.find(detail, needle, 1, true) then return 4 end
		if provider.matchEffects then
			query.words = query.words or WordPatterns(needle)
			if WordsInOrder(detail, query.words) then return 4 end
		end
	end
	return nil
end

local MATCH_CHUNK = 100

local function Wanted(provider, scope)
	return (scope == nil or scope == SS.SCOPE_ALL or provider.scope == scope) and SS.IsScopeEnabled(provider.scope)
		and not SS.IsCoveredByParent(provider, scope)
end

local function IndexReady(scope)
	for _, provider in ipairs(providers) do
		if Wanted(provider, scope) and not rows_by_scope[provider.scope] then return false end
	end
	return true
end

local function SearchStepper(text, scope, limit)
	local all = scope == nil or scope == SS.SCOPE_ALL
	searching_all = all
	if not all then Trim(scope) end
	local query = { text = text, needle = Lower(text) }
	local found, progress = {}, { changes = 0 }
	local at, provider, rows, position, effects = 0, nil, nil, 0, nil
	Refresh()

	local function Step()
		if not provider then
			at = at + 1
			provider = providers[at]
			if not provider then return true end
			if not Wanted(provider, scope) then
				provider = nil
				return false
			end
			rows, position = rows_by_scope[provider.scope], 0
			effects = (SS.saved and SS.saved.match_tooltips) or provider.matchEffects
			if rows then Touch(provider.scope) end
			return false
		end

		if not rows then
			rows = BuildStep(provider)
			return false
		end

		for _ = 1, MATCH_CHUNK do
			position = position + 1
			local row = rows[position]
			if row == nil then
				provider, rows = nil, nil
				return false
			end
			local closeness = Closeness(row, provider, effects, query)
			if closeness then
				row.closeness = closeness
				if not limit then
					found[#found + 1] = row
					progress.changes = progress.changes + 1
				elseif KeepBest(found, row, limit) then
					progress.changes = progress.changes + 1
				end
			end
		end
		return false
	end

	return Step, found, progress
end

function SS.Search(text, scope, limit)
	if type(text) ~= "string" or text == "" then return {} end

	local step, found = SearchStepper(text, scope, limit)
	while not step() do end
	if not limit then table.sort(found, Better) end
	return found
end

SS.SEARCH_LIMIT = 100
local SEARCH_JOB = "APHSearchQuery"

function SS.SearchAsync(text, scope, limit, onDone, onProgress)
	local pending = LibAPH.GetScheduledJob(SEARCH_JOB)
	if pending then pending:Cancel() end
	if type(text) ~= "string" or text == "" then
		onDone({})
		return nil
	end

	local step, found, progress = SearchStepper(text, scope, limit or SS.SEARCH_LIMIT)
	if SS.saved.instant_results and IndexReady(scope) then
		while not step() do end
		onDone(found)
		return nil
	end

	local shown, frame = 0, nil
	local function StepAndShow(job)
		if onProgress then
			local now = GetFrameTimeMilliseconds()
			if now ~= frame then
				frame = now
				if progress.changes ~= shown then
					shown = progress.changes
					onProgress(found)
				end
			end
		end
		return step(job)
	end
	return LibAPH.RunOrSchedule(SEARCH_JOB, StepAndShow, { onDone = function() onDone(found) end })
end
