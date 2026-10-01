local O = OneCrosshair
O.PresetRegistry.Register({
    id = "dot", name = SI_ONECROSSHAIR_PRESET_DOT,
    elements = { { size = 1.5 }, { size = 1.5 }, { size = 1.5 } },
    states = {
        normal = { { x = 0, y = 0 }, { x = 0, y = 0, alpha = 0 }, { x = 0, y = 0, alpha = 0 } },
        target = { { x = 0, y = -8.75 }, { x = -7.5, y = 5 }, { x = 7.5, y = 5 } },
        block = { { x = 0, y = 5 }, { x = -4.375, y = -2.5 }, { x = 4.375, y = -2.5 } },
    },
    -- Presentation only; in NORMAL separate the coincident points briefly.
    combatFeedback = function(index, x, y, pulse)
        local angle = -math.pi / 2 + (index - 1) * math.pi * 2 / 3
        return x + math.cos(angle) * 2 * pulse, y + math.sin(angle) * 2 * pulse
    end,
})
