-- Theme definitions for Vixen's Gamepad Scene.
--
-- Every theme is drawn from plain colored blocks, so it works even on clients
-- that won't load add-on image files. Particles and the corner emblem are
-- pixel-art shapes described as horizontal runs.

VGS = VGS or {}
local VGS = VGS

-------------------------------------------------------------------------------
-- Pixel shapes: w x h grid, runs = { row, firstCol, lastCol }, optional
-- shine = { row, col } for a white highlight pixel.
-------------------------------------------------------------------------------
VGS.SHAPES = {
    heart = {
        w = 7, h = 6, shine = { 1, 1 },
        runs = { {0,1,2}, {0,4,5}, {1,0,6}, {2,0,6}, {3,1,5}, {4,2,4}, {5,3,3} },
    },
    diamond = {
        w = 5, h = 5, shine = { 1, 2 },
        runs = { {0,2,2}, {1,1,3}, {2,0,4}, {3,1,3}, {4,2,2} },
    },
    sparkle = { -- four-point star
        w = 5, h = 5,
        runs = { {0,2,2}, {1,2,2}, {2,0,4}, {3,2,2}, {4,2,2} },
    },
    star = { -- chunkier star
        w = 7, h = 7, shine = { 3, 3 },
        runs = { {0,3,3}, {1,3,3}, {2,2,4}, {3,0,6}, {4,2,4}, {5,3,3}, {6,3,3} },
    },
    snowflake = {
        w = 5, h = 5,
        runs = { {0,0,0}, {0,2,2}, {0,4,4}, {1,1,3}, {2,0,4}, {3,1,3}, {4,0,0}, {4,2,2}, {4,4,4} },
    },
    ember = {
        w = 2, h = 2,
        runs = { {0,0,1}, {1,0,1} },
    },
    square = {
        w = 3, h = 3, shine = { 0, 0 },
        runs = { {0,0,2}, {1,0,2}, {2,0,2} },
    },
    shard = { -- tall blade-like crystal
        w = 3, h = 7, shine = { 1, 1 },
        runs = { {0,1,1}, {1,0,2}, {2,0,2}, {3,0,2}, {4,1,1}, {5,1,1}, {6,1,1} },
    },
    flame = {
        w = 5, h = 7, shine = { 4, 2 },
        runs = { {0,2,2}, {1,2,3}, {2,1,3}, {3,1,4}, {4,0,4}, {5,0,4}, {6,1,3} },
    },
    bolt = { -- lightning bolt
        w = 5, h = 7,
        runs = { {0,2,4}, {1,1,3}, {2,0,4}, {3,1,3}, {4,1,2}, {5,0,1}, {6,0,0} },
    },
    leaf = {
        w = 6, h = 6, shine = { 1, 3 },
        runs = { {0,3,5}, {1,2,5}, {2,1,4}, {3,1,3}, {4,0,2}, {5,0,0} },
    },
    skull = {
        w = 5, h = 5,
        runs = { {0,1,3}, {1,0,0}, {1,2,2}, {1,4,4}, {2,0,4}, {3,1,3}, {4,1,1}, {4,3,3} },
    },
    rune = { -- hollow diamond
        w = 7, h = 7,
        runs = { {0,3,3}, {1,2,2}, {1,4,4}, {2,1,1}, {2,5,5}, {3,0,0}, {3,3,3}, {3,6,6},
                 {4,1,1}, {4,5,5}, {5,2,2}, {5,4,4}, {6,3,3} },
    },
}

-------------------------------------------------------------------------------
-- Themes
--   wash       gradient top / bottom
--   line       divider and ribbon line color
--   particles  shape, colors, motion ("up", "down", "twinkle", "flicker"),
--              speed, count and size multipliers
--   corner     big emblem in the bottom-right corner
-------------------------------------------------------------------------------
VGS.THEMES = {
    -- Cute --------------------------------------------------------------------
    {
        id = "hearts", name = "Pink Hearts", group = "Cute",
        wash = { { 1.00, 0.47, 0.72 }, { 0.45, 0.10, 0.30 } },
        line = { 1.00, 0.80, 0.90 },
        particles = {
            shape = "heart", motion = "up",
            colors = { {1.00,0.55,0.78}, {1.00,0.75,0.88}, {1.00,0.38,0.66}, {1.00,0.92,0.96} },
        },
        corner = { shape = "heart", color = { 1.00, 0.38, 0.66 } },
    },

    -- Cool --------------------------------------------------------------------
    {
        id = "midnight", name = "Midnight", group = "Cool",
        wash = { { 0.10, 0.15, 0.30 }, { 0.01, 0.02, 0.07 } },
        line = { 0.55, 0.80, 1.00 },
        particles = {
            shape = "diamond", motion = "up", speed = 0.6,
            colors = { {0.40,0.85,1.00}, {0.70,0.95,1.00}, {0.30,0.50,1.00} },
        },
        corner = { shape = "diamond", color = { 0.30, 0.65, 1.00 } },
    },
    {
        id = "ember", name = "Ember", group = "Cool",
        wash = { { 0.35, 0.08, 0.02 }, { 0.04, 0.00, 0.00 } },
        line = { 1.00, 0.55, 0.20 },
        particles = {
            shape = "ember", motion = "flicker", speed = 2.5, count = 1.6, size = 0.45,
            colors = { {1.00,0.60,0.10}, {1.00,0.35,0.05}, {1.00,0.85,0.40} },
        },
        corner = { shape = "flame", color = { 1.00, 0.45, 0.08 } },
    },
    {
        id = "frost", name = "Frost", group = "Cool",
        wash = { { 0.45, 0.65, 0.85 }, { 0.05, 0.12, 0.25 } },
        line = { 0.85, 0.95, 1.00 },
        particles = {
            shape = "snowflake", motion = "down", speed = 0.8,
            colors = { {1.00,1.00,1.00}, {0.80,0.92,1.00}, {0.65,0.85,1.00} },
        },
        corner = { shape = "snowflake", color = { 0.80, 0.92, 1.00 } },
    },
    {
        id = "void", name = "Void", group = "Cool",
        wash = { { 0.20, 0.05, 0.35 }, { 0.01, 0.00, 0.04 } },
        line = { 0.75, 0.50, 1.00 },
        particles = {
            shape = "sparkle", motion = "twinkle", speed = 0.4, count = 1.4,
            colors = { {0.80,0.60,1.00}, {1.00,1.00,1.00}, {0.55,0.35,1.00} },
        },
        corner = { shape = "star", color = { 0.60, 0.40, 1.00 } },
    },
    {
        id = "neon", name = "Neon", group = "Cool",
        wash = { { 0.32, 0.00, 0.40 }, { 0.02, 0.00, 0.10 } },
        line = { 0.20, 1.00, 1.00 },
        particles = {
            shape = "square", motion = "up", speed = 0.9, size = 0.6,
            colors = { {0.20,1.00,1.00}, {1.00,0.20,0.85}, {0.55,0.35,1.00} },
        },
        corner = { shape = "diamond", color = { 1.00, 0.20, 0.85 } },
    },
    {
        id = "carbon", name = "Carbon", group = "Cool",
        wash = { { 0.20, 0.20, 0.23 }, { 0.02, 0.02, 0.03 } },
        line = { 0.75, 0.75, 0.80 },
        particles = {
            shape = "shard", motion = "down", speed = 0.5,
            colors = { {0.70,0.70,0.75}, {0.45,0.45,0.50}, {0.90,0.90,0.95} },
        },
        corner = { shape = "rune", color = { 0.60, 0.60, 0.65 } },
    },

    -- Classes -----------------------------------------------------------------
    {
        id = "dragonknight", name = "Dragonknight", group = "Class", classId = 1,
        wash = { { 0.42, 0.10, 0.02 }, { 0.07, 0.01, 0.00 } },
        line = { 1.00, 0.50, 0.15 },
        particles = {
            shape = "flame", motion = "flicker", speed = 1.8,
            colors = { {1.00,0.45,0.05}, {1.00,0.70,0.15}, {0.90,0.15,0.05} },
        },
        corner = { shape = "flame", color = { 1.00, 0.40, 0.05 } },
    },
    {
        id = "sorcerer", name = "Sorcerer", group = "Class", classId = 2,
        wash = { { 0.22, 0.08, 0.42 }, { 0.03, 0.02, 0.12 } },
        line = { 0.65, 0.70, 1.00 },
        particles = {
            shape = "bolt", motion = "twinkle", speed = 0.5,
            colors = { {0.70,0.55,1.00}, {0.55,0.75,1.00}, {0.95,0.95,1.00} },
        },
        corner = { shape = "bolt", color = { 0.60, 0.50, 1.00 } },
    },
    {
        id = "nightblade", name = "Nightblade", group = "Class", classId = 3,
        wash = { { 0.25, 0.02, 0.06 }, { 0.02, 0.00, 0.01 } },
        line = { 0.85, 0.10, 0.18 },
        particles = {
            shape = "shard", motion = "down", speed = 1.2,
            colors = { {0.80,0.05,0.12}, {0.45,0.02,0.06}, {0.95,0.30,0.35} },
        },
        corner = { shape = "shard", color = { 0.75, 0.05, 0.12 } },
    },
    {
        id = "warden", name = "Warden", group = "Class", classId = 4,
        wash = { { 0.12, 0.32, 0.18 }, { 0.02, 0.08, 0.07 } },
        line = { 0.60, 0.95, 0.70 },
        particles = {
            shape = "leaf", motion = "down", speed = 0.7,
            colors = { {0.40,0.85,0.35}, {0.65,0.95,0.50}, {0.70,0.90,1.00} },
        },
        corner = { shape = "leaf", color = { 0.35, 0.80, 0.35 } },
    },
    {
        id = "necromancer", name = "Necromancer", group = "Class", classId = 5,
        wash = { { 0.12, 0.26, 0.12 }, { 0.02, 0.04, 0.02 } },
        line = { 0.60, 1.00, 0.50 },
        particles = {
            shape = "skull", motion = "up", speed = 0.5,
            colors = { {0.90,0.90,0.80}, {0.55,1.00,0.45}, {0.75,0.80,0.65} },
        },
        corner = { shape = "skull", color = { 0.55, 1.00, 0.45 } },
    },
    {
        id = "templar", name = "Templar", group = "Class", classId = 6,
        wash = { { 0.55, 0.42, 0.12 }, { 0.10, 0.07, 0.02 } },
        line = { 1.00, 0.90, 0.55 },
        particles = {
            shape = "star", motion = "twinkle", speed = 0.5,
            colors = { {1.00,0.85,0.35}, {1.00,0.95,0.75}, {1.00,1.00,1.00} },
        },
        corner = { shape = "star", color = { 1.00, 0.80, 0.30 } },
    },
    {
        id = "arcanist", name = "Arcanist", group = "Class", classId = 117,
        wash = { { 0.05, 0.30, 0.25 }, { 0.01, 0.05, 0.05 } },
        line = { 0.30, 1.00, 0.75 },
        particles = {
            shape = "rune", motion = "twinkle", speed = 0.4,
            colors = { {0.30,1.00,0.75}, {0.55,1.00,0.85}, {0.20,0.75,0.60} },
        },
        corner = { shape = "rune", color = { 0.30, 1.00, 0.75 } },
    },
}

VGS.THEME_BY_ID = {}
VGS.THEME_BY_CLASS = {}
for _, theme in ipairs(VGS.THEMES) do
    VGS.THEME_BY_ID[theme.id] = theme
    if theme.classId then VGS.THEME_BY_CLASS[theme.classId] = theme end
end

-- "class" picks the current character's class theme.
function VGS.GetTheme()
    local id = VGS.sv and VGS.sv.theme or "hearts"
    if id == "class" then
        local classId = GetUnitClassId and GetUnitClassId("player")
        local theme = VGS.THEME_BY_CLASS[classId]
        if not theme and GetUnitClass then
            -- backup: match the (English) class name
            local className = (GetUnitClass("player") or ""):lower():gsub("[^a-z]", "")
            for _, t in ipairs(VGS.THEMES) do
                if t.classId and className:find(t.id, 1, true) then theme = t break end
            end
        end
        return theme or VGS.THEME_BY_ID.hearts
    end
    return VGS.THEME_BY_ID[id] or VGS.THEME_BY_ID.hearts
end
