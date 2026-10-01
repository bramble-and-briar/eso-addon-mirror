local O = OneCrosshair
local diamond = "OneCrosshair/Assets/Diamond.dds"
O.PresetRegistry.Register({
    id = "diamonds", name = SI_ONECROSSHAIR_PRESET_DIAMONDS,
    elements = { { size = 5, texture = diamond }, { size = 5, texture = diamond }, { size = 5, texture = diamond } },
    states = {
        normal = { { x = 0, y = 0 }, { x = 0, y = 0, alpha = 0 }, { x = 0, y = 0, alpha = 0 } },
        target = { { x = 0, y = -8 }, { x = -7, y = 3 }, { x = 7, y = 3 } },
        block = { { x = 0, y = 4 }, { x = -5, y = -3.5 }, { x = 5, y = -3.5 } },
    },
    combatFeedback = function(index, x, y, pulse)
        local angle = -math.pi / 2 + (index - 1) * math.pi * 2 / 3
        return x + math.cos(angle) * 2 * pulse, y + math.sin(angle) * 2 * pulse
    end,
})
