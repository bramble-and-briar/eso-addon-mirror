local O = OneCrosshair
O.PresetRegistry = { list = {}, byId = {} }
function O.PresetRegistry.Register(preset)
    assert(type(preset.id) == "string" and not O.PresetRegistry.byId[preset.id])
    assert(preset.states.normal and preset.states.target and preset.states.block)
    O.PresetRegistry.byId[preset.id] = preset
    table.insert(O.PresetRegistry.list, preset)
end
function O.PresetRegistry.Get(id)
    return O.PresetRegistry.byId[id] or O.PresetRegistry.list[1]
end
