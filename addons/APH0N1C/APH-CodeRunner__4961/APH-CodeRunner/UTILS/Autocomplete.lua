--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local APHCR = APHCodeRunnerCore

APHCR.SUGGEST_MAX = 8
APHCR.SUGGEST_IDLE_TEXT = "Autocomplete: type 2 letters, or press . or : after a name"
local SUGGEST_COLORS = {
	["function"] = "DCDCAA", table = "4EC9B0", userdata = "4EC9B0",
	number = "4FC1FF", string = "4FC1FF", boolean = "4FC1FF", word = "9CDCFE",
}
APHCR.suggest_labels = {}
APHCR.suggestions = {}

local function ResolveChain(chain, text)
	local parts = {}
	for part in chain:gmatch("[%a_][%w_]*") do parts[#parts + 1] = part end
	if #parts == 0 then return nil end
	local function Walk(names)
		local value = _G
		for _, name in ipairs(names) do
			if type(value) ~= "table" and type(value) ~= "userdata" then return nil end
			local ok, member = pcall(function() return value[name] end)
			if not ok or member == nil then return nil end
			value = member
		end
		return value
	end
	local value = Walk(parts)
	if value == nil and rawget(_G, parts[1]) == nil then
		local alias = text:match("local%s+" .. parts[1] .. "%s*=%s*([%a_][%w_%.]*)")
		if alias then
			local names = {}
			for part in alias:gmatch("[%a_][%w_]*") do names[#names + 1] = part end
			for index = 2, #parts do names[#names + 1] = parts[index] end
			value = Walk(names)
		end
	end
	return value
end

local MAX_SKIPPED_PRIVATE = 20000
local global_entries
local autocomplete_broken = false

local function EachKey(container, visit)
	local key, skipped = nil, 0
	while true do
		local ok, next_key, value = pcall(next, container, key)
		if ok then
			if next_key == nil then return true end
			key = next_key
			visit(key, value)
		else
			local private_name = tostring(next_key):match("private function '([^']+)'")
			skipped = skipped + 1
			if not private_name or skipped > MAX_SKIPPED_PRIVATE then return false end
			key = private_name
			visit(private_name, nil, "function")
		end
	end
end

local function GlobalEntries()
	if global_entries then return global_entries end
	local entries = {}
	EachKey(_G, function(key, value, forced_kind)
		if type(key) == "string" and #key >= 2 then
			entries[#entries + 1] = { name = key, kind = forced_kind or type(value) }
		end
	end)
	if #entries == 0 then autocomplete_broken = true end
	global_entries = entries
	return entries
end

local function CollectSuggestions(prefix, owner, text)
	local lower_prefix = prefix:lower()
	local length = #lower_prefix
	local found, seen = {}, {}
	local function Consider(name, kind)
		if seen[name] or name == prefix or #found >= 4000 then return end
		if name:sub(1, length):lower() ~= lower_prefix then return end
		seen[name] = true
		found[#found + 1] = { name = name, kind = kind }
	end
	if owner ~= nil then
		local function FromTable(container)
			EachKey(container, function(key, value, forced_kind)
				if type(key) == "string" then Consider(key, forced_kind or type(value)) end
			end)
		end
		if type(owner) == "table" then FromTable(owner) end
		local ok, meta = pcall(getmetatable, owner)
		if ok and type(meta) == "table" and type(meta.__index) == "table" then FromTable(meta.__index) end
	else
		for word in text:gmatch("[%a_][%w_]*") do
			if #word >= 2 then Consider(word, "word") end
		end
		for _, entry in ipairs(GlobalEntries()) do
			Consider(entry.name, entry.kind)
		end
	end
	table.sort(found, function(a, b)
		local a_exact, b_exact = a.name:sub(1, length) == prefix, b.name:sub(1, length) == prefix
		if a_exact ~= b_exact then return a_exact end
		if #a.name ~= #b.name then return #a.name < #b.name end
		return a.name < b.name
	end)
	return found
end

function APHCR.HideSuggestions()
	APHCR.suggestions = {}
	for _, label in ipairs(APHCR.suggest_labels) do label:SetHidden(true) end
	if APHCR.suggest_hint then
		APHCR.suggest_hint:SetText(autocomplete_broken and "Autocomplete is unavailable here" or APHCR.SUGGEST_IDLE_TEXT)
	end
end

function APHCR.UpdateSuggestions()
	if not (APHCR.editor and APHCR.suggest_bar) then return end
	local box = APHCR.editor.box
	if autocomplete_broken or not box:HasFocus() then
		APHCR.HideSuggestions()
		return
	end
	local text = box:GetText()
	local before = text:sub(1, box:GetCursorPosition())
	local prefix = before:match("[%a_][%w_]*$") or ""
	local head = before:sub(1, #before - #prefix)
	local chain = head:match("([%a_][%w_%.]*)[%.:]$")
	if not chain and #prefix < 2 then
		APHCR.HideSuggestions()
		return
	end
	local owner
	if chain then
		owner = ResolveChain(chain, text)
		if owner == nil then
			APHCR.HideSuggestions()
			return
		end
	end
	local found = CollectSuggestions(prefix, owner, text)
	APHCR.suggestions = {}
	if autocomplete_broken then
		APHCR.HideSuggestions()
		return
	end
	if #found == 0 then
		APHCR.HideSuggestions()
		return
	end
	APHCR.suggest_hint:SetText("Tab:")
	local room = APHCR.suggest_bar:GetWidth() - APHCR.suggest_hint:GetTextWidth() - 24
	local used, previous = 0, APHCR.suggest_hint
	for index, item in ipairs(found) do
		if index > APHCR.SUGGEST_MAX then break end
		local label = APHCR.suggest_labels[index]
		label:SetText("|c" .. (SUGGEST_COLORS[item.kind] or "9CDCFE") .. item.name .. "|r")
		local width = label:GetTextWidth() + 14
		if used + width > room and #APHCR.suggestions > 0 then break end
		used = used + width
		label:ClearAnchors()
		label:SetAnchor(LEFT, previous, RIGHT, 14, 0)
		label:SetHidden(false)
		APHCR.suggestions[#APHCR.suggestions + 1] = item
		previous = label
	end
	for index = #APHCR.suggestions + 1, #APHCR.suggest_labels do APHCR.suggest_labels[index]:SetHidden(true) end
end

function APHCR.AcceptSuggestion(index)
	local item = APHCR.suggestions[index]
	if not item then return end
	local box = APHCR.editor.box
	local text = box:GetText()
	local cursor = box:GetCursorPosition()
	local prefix = text:sub(1, cursor):match("[%a_][%w_]*$") or ""
	APHCR.HideSuggestions()
	if item.name:sub(1, #prefix) == prefix then
		box:InsertText(item.name:sub(#prefix + 1))
	else
		APHCR.editor:ReplaceText(text:sub(1, cursor - #prefix) .. item.name .. text:sub(cursor + 1), cursor - #prefix + #item.name)
	end
	box:TakeFocus()
end
