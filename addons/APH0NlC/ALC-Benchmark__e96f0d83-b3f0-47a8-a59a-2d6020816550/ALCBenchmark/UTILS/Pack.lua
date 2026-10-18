--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local AB = ALCBenchmark
local UI = AB.UI

UI.PACK = { scale = { lua = 10, pool = 10, away = 1 }, cache = setmetatable({}, { __mode = "k" }) }

function UI.PackSeries(series)
	local packed = {}
	for key, scale in pairs(UI.PACK.scale) do
		if series[key] then packed[key] = LibAPH.PackNumbers(series[key], scale) end
	end
	return packed
end

function UI.Series(column)
	if column.series then return column.series end
	local packed = column.packed
	if not packed then return nil end
	local series = UI.PACK.cache[column]
	if series then return series end
	series = {}
	for key, scale in pairs(UI.PACK.scale) do
		if packed[key] then series[key] = LibAPH.UnpackNumbers(packed[key], scale) end
	end
	UI.PACK.cache[column] = series
	return series
end
