-- FurnitureFinderLiteTypes.lua: central type definitions (annotations only; no runtime code).

---The generated data (FurnitureFinderLiteData.lua; format in tools/build_data.py).
---@class FurnitureFinderLiteData
---@field version string    the Furniture Catalogue commit it was built from
---@field updated string    date of that database's last change, yyyy-mm-dd
---@field count integer     furnishings
---@field records integer   sources, over all furnishings
---@field texts table<string, string[]> English texts the tokens point at, by token letter
---@field first integer[]   first furnishing id of each block
---@field blocks string[]   one line per furnishing ("id=record;record"), each between two line breaks

---One token of a source: a letter saying what it is and its value as text.
---@class FurnitureFinderLiteToken
---@field [1] string letter
---@field [2] string value

---One source of a furnishing: its tokens in the order written.
---@alias FurnitureFinderLiteRecord FurnitureFinderLiteToken[]
