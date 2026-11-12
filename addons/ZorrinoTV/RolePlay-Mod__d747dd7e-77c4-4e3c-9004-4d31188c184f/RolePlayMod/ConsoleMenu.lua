local R, B = RolePlayMod, IHR_Runtime.Beta
local Menu = {}
R.ConsoleMenu = Menu

local function inWorld()
    local scene = SCENE_MANAGER:GetCurrentScene()
    local name = scene and scene:GetName()
    return (name == 'hud' or name == 'hudui') and not IsUnitInCombat('player')
end

local function choice(text, callback)
    return {text=text, callback=callback}
end

local function show(title, text, choices, back)
    if not inWorld() or not B.saved or not R.Gamepad.Enabled() then return false end
    if B.npc and not B.npc.consoleMenu then return false end
    if not B.npc then
        -- Use the existing free conversation panel and its movement/cancel checks.
        local zone, x, y, z = GetUnitWorldPosition('player')
        B.npc = {name='Les Voies de Tamriel', consoleMenu=true, travelOnly=true,
            zoneId=zone, x=x, y=y, z=z}
    end
    choices[#choices+1] = {text='Retour', callback=back, uiRole='back'}
    B.Show(title, text, choices)
    return B.IsOpen()
end

local function leaveFor(callback)
    return function()
        B.Close()
        callback()
    end
end

local function options(title, entries, back)
    local choices = {}
    local function redraw() return options(title, entries, back) end
    for _, entry in ipairs(entries) do
        local item = entry
        if item.type == 'description' then
            choices[#choices+1] = choice('À propos', function()
                show(title, item.text, {}, redraw)
            end)
        elseif item.type == 'submenu' then
            choices[#choices+1] = choice(item.name, function()
                options(item.name, item.controls, redraw)
            end)
        else
            local disabled = item.disabled and item.disabled()
            local label = item.name
            if item.type == 'checkbox' then
                label = label .. (item.getFunc() and ' · Oui' or ' · Non')
            elseif item.type == 'slider' then
                label = label .. ' · ' .. tostring(item.getFunc())
            elseif item.type == 'dropdown' then
                for index, value in ipairs(item.choicesValues) do
                    if value == item.getFunc() then label = label .. ' · ' .. item.choices[index] end
                end
            end
            if disabled then label = label .. ' · Indisponible' end
            choices[#choices+1] = choice(label, function()
                if item.disabled and item.disabled() then
                    return show(item.name, 'Activez d’abord la fonction dont dépend ce réglage.', {}, redraw)
                end
                if item.type == 'button' then
                    item.func()
                    return redraw()
                end
                if item.type == 'checkbox' and not item.tooltip then
                    item.setFunc(not item.getFunc())
                    return redraw()
                end
                local edit = {}
                local function set(value)
                    return function() item.setFunc(value); redraw() end
                end
                if item.type == 'checkbox' then
                    edit = {choice('Activer', set(true)), choice('Désactiver', set(false))}
                elseif item.type == 'slider' then
                    local current = item.getFunc()
                    local function step(delta)
                        local value = math.max(item.min, math.min(item.max, current+delta*item.step))
                        value = tonumber(string.format('%.2f', value))
                        return choice(tostring(value), set(value))
                    end
                    if current > item.min then edit[#edit+1] = step(-1) end
                    if current < item.max then edit[#edit+1] = step(1) end
                    if item.default ~= nil then edit[#edit+1] = choice('Valeur par défaut', set(item.default)) end
                elseif item.type == 'dropdown' then
                    for index, value in ipairs(item.choicesValues) do
                        edit[#edit+1] = choice(item.choices[index], set(value))
                    end
                end
                show(item.name, item.tooltip or label, edit, redraw)
            end)
        end
    end
    return show(title, title, choices, back)
end

function Menu.OpenOptions()
    if not R.saved or not RolePlayNeeds.settings then return false end
    return options('Réglages', R.CreateOptions(), Menu.Open)
end

function Menu.Open()
    if not inWorld() or not R.Gamepad.Enabled() or not B.saved then return false end
    if B.IsOpen() and not (B.npc and B.npc.consoleMenu) then B.Close() end
    if RolePlayNeeds.GamepadWheel.IsOpen() then RolePlayNeeds.GamepadWheel.Back() end
    local choices = {choice('Roue de survie', leaveFor(R.Gamepad.ToggleSurvival))}
    if B.saved.enabled then
        choices[#choices+1] = choice('Se renseigner auprès du PNJ visé', leaveFor(function() B.Open(false) end))
    end
    if R.Enabled('travelJournal') then
        choices[#choices+1] = choice('Carnet de voyage', leaveFor(B.TravelJournal.Open))
    end
    choices[#choices+1] = choice('Réglages', Menu.OpenOptions)
    return show('RolePlay Mod', 'Choisissez une action.', choices, B.Close)
end

-- R1 is free on the top-level gamepad menu. Square and Triangle open chat.
local menuScene = SCENE_MANAGER.GetScene and SCENE_MANAGER:GetScene('mainMenuGamepad')
if menuScene and KEYBIND_STRIP then
    local requested = false
    local group = {alignment=KEYBIND_STRIP_ALIGN_RIGHT, {
        keybind='UI_SHORTCUT_RIGHT_SHOULDER', name='RolePlay Mod',
        callback=function()
            requested = true
            SCENE_MANAGER:Hide('mainMenuGamepad')
        end,
    }}
    local installed = false
    menuScene:RegisterCallback('StateChange', function(_, state)
        if state == SCENE_SHOWN and not installed and R.Gamepad.Enabled() then
            KEYBIND_STRIP:AddKeybindButtonGroup(group)
            installed = true
        elseif state == SCENE_HIDING and installed then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(group)
            installed = false
        elseif state == SCENE_HIDDEN and requested then
            requested = false
            zo_callLater(Menu.Open, 0)
        end
    end)
end

if SLASH_COMMANDS then
    SLASH_COMMANDS['/voies'] = Menu.Open
    SLASH_COMMANDS['/roleplaymod'] = Menu.Open
end
