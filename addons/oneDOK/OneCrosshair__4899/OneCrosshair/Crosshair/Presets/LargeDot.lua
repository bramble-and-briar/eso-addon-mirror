local O = OneCrosshair
O.PresetRegistry.Register({
    id = "large_dot", name = SI_ONECROSSHAIR_PRESET_LARGE_DOT,
    elements = { { size = 7.5 }, { size = 7.5 }, { size = 7.5 } },
    states = {
        normal = { { x = 0, y = 0 }, { x = 0, y = 0, alpha = 0 }, { x = 0, y = 0, alpha = 0 } },
        target = { { x = 0, y = -10 }, { x = -9, y = 6 }, { x = 9, y = 6 } },
        block = { { x = 0, y = 10 }, { x = -9, y = -6 }, { x = 9, y = -6 } },
    },
    combatFeedback = function(index, x, y, pulse)
        local angle = -math.pi / 2 + (index - 1) * math.pi * 2 / 3
        return x + math.cos(angle) * 2 * pulse, y + math.sin(angle) * 2 * pulse
    end,
})
