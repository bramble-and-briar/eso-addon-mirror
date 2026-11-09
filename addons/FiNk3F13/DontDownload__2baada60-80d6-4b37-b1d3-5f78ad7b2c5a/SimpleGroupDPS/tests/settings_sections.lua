local env = dofile('tests/standalone.lua')
assert(env.menuEntries[1].label == 'Autor: FiNk3--F13--')
assert(env.menuEntries[2].label == 'DPS-HUD')
local sections, current = {}, nil
for _, entry in ipairs(env.menuEntries) do
    if entry.type == LibHarvensAddonSettings.ST_SECTION then
        current = entry.label
        sections[#sections + 1] = current
        assert(entry.subMenu ~= false, 'Console sections must open submenus like ObsidianHUD')
    elseif entry.label == 'Autor: FiNk3--F13--' then
        assert(current == nil, 'Author belongs above the first HUD section')
    else
        assert(current, 'Every setting belongs to a section')
        if entry.label:find('Anteil%-HUD') or entry.label:find('Gruppenanteil%-HUD') then
            assert(current == 'Gruppenanteil-HUD', 'Personal HUD controls belong together')
        elseif entry.label == 'Nach Kampfende anzeigen' or entry.label == 'Messvergleich ausgeben' then
            assert(current == 'Allgemein', 'Shared retention applies to both HUDs')
        else
            assert(current == 'DPS-HUD', 'Group display controls belong together')
        end
    end
end
assert(table.concat(sections, ',') == 'DPS-HUD,Gruppenanteil-HUD,Allgemein')
local saved, menu, group, personal = env.saved, env.menu, env.window, env.personalWindow
saved.posX, saved.posY, saved.personalPosX, saved.personalPosY = 100, 120, 400, 450
group.left, group.top, personal.left, personal.top = 100, 120, 400, 450
local scale, personalScale, width = saved.scale, saved.personalScale, saved.dpsWidth
menu['Move UI'].clickHandler()
menu['DPS-HUD-Position zurücksetzen'].clickHandler()
assert(not group.movable and env.updates.SimpleGroupDPSMove == nil, 'Reset ends active movement')
assert(saved.posX == 720 and saved.posY == 300 and group.left == 720 and group.top == 300)
assert(saved.personalPosX == 400 and saved.personalPosY == 450, 'Group reset preserves personal position')
menu['Anteil-HUD verschieben'].clickHandler()
menu['Gruppenanteil-HUD-Position zurücksetzen'].clickHandler()
assert(not personal.movable and env.updates.SimpleGroupDPSMove == nil)
assert(saved.personalPosX == 32 and saved.personalPosY == math.max(0, GuiRoot:GetHeight() - personal:GetHeight() - 80))
assert(personal.left == saved.personalPosX and personal.top == saved.personalPosY)
assert(saved.posX == 720 and saved.posY == 300, 'Personal reset preserves group position')
assert(saved.scale == scale and saved.personalScale == personalScale and saved.dpsWidth == width, 'Position reset preserves size and layout')
print('PASS: ObsidianHUD-style sections and independent position resets')
