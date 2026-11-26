--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

local floor, abs = math.floor, math.abs
local CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"
local CHUNK = 1900
local HASH_MOD = 4294967296
local EXACT_LIMIT = 2 ^ 52
local digit = {}
for at = 1, #CHARS do digit[CHARS:byte(at)] = at - 1 end
local claimed = {}

function LibAPH.PackNumbers(list, scale)
	scale = scale or 1
	local out, previous = {}, 0
	for index = 1, #list do
		local value = list[index]
		if type(value) ~= "number" then
			out[#out + 1] = "!"
		else
			local number = floor(value * scale + 0.5)
			local delta = number - previous
			previous = number
			local zigzag = delta >= 0 and delta * 2 or -delta * 2 - 1
			repeat
				local d = zigzag % 32
				zigzag = floor(zigzag / 32)
				local at = (zigzag > 0 and d + 32 or d) + 1
				out[#out + 1] = CHARS:sub(at, at)
			until zigzag == 0
		end
	end
	local text = table.concat(out)
	if #text <= CHUNK then return text end
	local chunks = {}
	for first = 1, #text, CHUNK do chunks[#chunks + 1] = text:sub(first, first + CHUNK - 1) end
	return chunks
end

function LibAPH.UnpackNumbers(packed, scale)
	scale = scale or 1
	local text = type(packed) == "table" and table.concat(packed) or tostring(packed or "")
	local list, previous, value, place = {}, 0, 0, 1
	for index = 1, #text do
		local byte = text:byte(index)
		if byte == 33 then
			list[#list + 1] = false
		else
			local d = digit[byte] or 0
			value = value + (d % 32) * place
			if d >= 32 then
				place = place * 32
			else
				local delta = value % 2 == 0 and value / 2 or -(value + 1) / 2
				previous = previous + delta
				list[#list + 1] = previous / scale
				value, place = 0, 1
			end
		end
	end
	return list
end

function LibAPH.RoundNumbers(value, decimals)
	local scale = 10 ^ (decimals or 2)
	for key, item in pairs(value) do
		if type(item) == "number" and item ~= floor(item) then
			value[key] = floor(item * scale + 0.5) / scale
		elseif type(item) == "table" then
			LibAPH.RoundNumbers(item, decimals)
		end
	end
	return value
end

local function Hash(text)
	local a, b = 5381, 0
	for index = 1, #text do
		local byte = text:byte(index)
		a = (a * 33 + byte) % HASH_MOD
		b = (b * 65599 + byte) % HASH_MOD
	end
	return string.format("%08x%08x", a, b)
end

local function SortKeys(a, b)
	if type(a) == type(b) then return a < b end
	return type(a) == "number"
end

function LibAPH.CreateSeal(opts)
	opts = opts or {}
	local salt = opts.salt
	if type(salt) ~= "string" or salt == "" or claimed[salt] then return nil end
	claimed[salt] = true
	local skip = { seal = true, seal_account = true, seal_world = true }
	for _, key in ipairs(opts.skip or {}) do skip[key] = true end
	local decimals = opts.decimals or 2
	local scale = 10 ^ decimals
	local verify = opts.verify
	local checked = setmetatable({}, { __mode = "k" })

	local function Canon(value, out, top)
		local kind = type(value)
		if kind == "string" then
			out[#out + 1] = "s" .. #value .. ":" .. value
		elseif kind == "number" then
			local scaled = value * scale
			if abs(scaled) >= EXACT_LIMIT then
				out[#out + 1] = string.format("n%.17g", value)
			else
				local whole = floor(scaled + 0.5)
				if whole / scale ~= value then return false end
				out[#out + 1] = string.format("n%.0f", whole)
			end
		elseif kind == "boolean" then
			out[#out + 1] = value and "t" or "f"
		elseif kind == "table" then
			local keys = {}
			for key in pairs(value) do
				if not (top and skip[key]) then keys[#keys + 1] = key end
			end
			table.sort(keys, SortKeys)
			out[#out + 1] = "{"
			for _, key in ipairs(keys) do
				if Canon(key, out) == false or Canon(value[key], out) == false then return false end
			end
			out[#out + 1] = "}"
		end
	end

	local function Digest(record, account, world)
		local out = { salt, "|", tostring(account), "|", tostring(world), "|" }
		if Canon(record, out, true) == false then return nil end
		return Hash(table.concat(out))
	end

	local sealer = {}

	function sealer.Seal(record)
		if type(record) ~= "table" or record.seal ~= nil then return false end
		LibAPH.RoundNumbers(record, decimals)
		local account, world = GetDisplayName(), GetWorldName()
		local digest = Digest(record, account, world)
		if not digest then return false end
		record.seal, record.seal_account, record.seal_world = digest, account, world
		return true
	end

	function sealer.Check(record)
		if type(record) ~= "table" then return "not_sealed" end
		local status = checked[record]
		if status then return status end
		if type(record.seal) ~= "string" then
			status = "not_sealed"
		else
			local account, world = GetDisplayName(), GetWorldName()
			local from_account, from_world = record.seal_account, record.seal_world
			if Digest(record, account, world) == record.seal then
				status = "sealed"
			elseif type(from_account) == "string" and type(from_world) == "string" and (from_account ~= account or from_world ~= world)
				and Digest(record, from_account, from_world) == record.seal then
				status = from_account ~= account and "other_player" or "other_server"
			else
				status = "changed"
			end
			if status ~= "changed" and verify and verify(record) == false then status = "changed" end
		end
		checked[record] = status
		return status
	end

	return sealer
end
