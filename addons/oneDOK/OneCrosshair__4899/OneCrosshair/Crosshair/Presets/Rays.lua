local O = OneCrosshair
local preset = { id = "rays", name = SI_ONECROSSHAIR_PRESET_RAYS,
    elements = {}, states = { normal = {}, target = {}, block = {} } }
local target = { {0,-10}, {-8.660254,5}, {8.660254,5} }
-- Rotate the three persistent corners by 60 degrees rather than crossing
-- the center with a 180-degree inversion. Both produce the inverted triangle.
local block = { {8.660254,-5}, {-8.660254,-5}, {0,10} }
local function arm(vertices, i, neighbor)
    local a, b = vertices[i], vertices[neighbor]
    local dx, dy = b[1]-a[1], b[2]-a[2]
    local fraction = 5.2 / math.sqrt(dx*dx+dy*dy)
    return { x = a[1], y = a[2], x2 = a[1]+dx*fraction, y2 = a[2]+dy*fraction }
end
for i = 1, 3 do
    for side = 1, 2 do
        local index = (i-1)*2+side
        local vertex = target[i]
        preset.elements[index] = { kind = "line", thickness = 1.2 }
        -- Two coincident arms become one spoke at rest. Reveal the second
        -- as the endpoints separate into an open corner on acquisition/block.
        preset.states.normal[index] = { x = vertex[1], y = vertex[2],
            x2 = vertex[1]*.3, y2 = vertex[2]*.3, alpha = side == 1 and 1 or 0 }
        local neighbor = (i+side-1)%3+1
        preset.states.target[index] = arm(target, i, neighbor)
        preset.states.block[index] = arm(block, i, neighbor)
    end
end
O.PresetRegistry.Register(preset)
