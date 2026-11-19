-- The extra markers: 24 flat symbols, assets/icon01.dds .. icon24.dds (drawn by scripts/build_assets.py).
--
-- The NUMBER of an icon is what goes over LibGroupBroadcast, so an icon is never renumbered or taken out: new ones are
-- added at the end (and ICON_COUNT in Core.lua and the protocol's 6-bit field, 63 at most, say how many there can be).
local A, S = PBS_PME, PBS_PME_STRINGS

A.ICON_KEYS = {
	"heart", "diamond", "arrow", "exclaim", "question", "bolt", "flame", "drop",
	"shield", "sword", "cross", "x", "check", "hexagon", "crown", "eye",
	"snowflake", "leaf", "sun", "target", "flag", "bomb", "stop", "vortex",
	"ranger_red", "ranger_blue", "ranger_yellow", "ranger_green", "ranger_pink", "ranger_black",
	"ranger_navy", "ranger_purple", "ranger_white", "ranger_orange", "ranger_silver",
}

-- Where the pictures are: the folder the manifest gives. Textures.lua looks at whether the game loads them from there and,
-- if not, whether it loads them from the path the game's own add-on list reports; A.ICON_PATH is what is in use.
A.ICON_PATH_DEFAULT = "PBsPlayerMarkerExtension/assets/"
A.ICON_PATH = A.ICON_PATH_DEFAULT

function A.IsIcon(id)
	return type(id) == "number" and id == math.floor(id) and id >= 1 and id <= A.ICON_COUNT
end

function A.IconPath(id)
	return string.format("%sicon%02d.dds", A.ICON_PATH, id)
end

-- The wheel's "clear" entry (a ring with a slash)
A.CLEAR_PATH = A.ICON_PATH .. "clear.dds"

function A.IconName(id)
	local names = S.icons
	return (names and names[id]) or A.ICON_KEYS[id] or ("#" .. tostring(id))
end

A.MARK("Icons")
