local O = OneCrosshair
-- Native gameplay ownership is restored by Runtime. These atlas endpoints
-- are ONLY the isolated settings preview (ESO reticle.xml: 16 cells, 64x64).
local texture = "EsoUI/Art/Reticle/reticleAnim.dds"
O.PresetRegistry.Register({
    id = "eso", name = SI_ONECROSSHAIR_PRESET_ESO, native = true,
    elements = {
        { size = 64, texture = texture, textureCoords = { 0, 1/16, 0, 1 } },
        { size = 64, texture = texture, textureCoords = { 15/16, 1, 0, 1 } },
    },
    states = {
        normal = { { alpha = 1 }, { alpha = 0 } },
        target = { { alpha = 0 }, { alpha = 1 } },
        -- Vanilla has no distinct Block shape; show its normal endpoint.
        block = { { alpha = 1 }, { alpha = 0 } },
    },
})
