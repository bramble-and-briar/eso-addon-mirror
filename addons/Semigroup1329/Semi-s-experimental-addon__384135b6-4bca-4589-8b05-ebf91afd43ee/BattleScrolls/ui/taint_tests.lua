---@diagnostic disable: undefined-field, inject-field -- Native UI objects expose additional runtime fields
if not SemisPlaygroundCheckAccess() then return end

-- Personal playground module: the in-game checks of docs/inventory-addon/ui-taint.md
-- behind one command. Addon code is untrusted exactly like a /script chunk, so
-- each check observes what its documented snippet does.
--   /bst          checks 1, 2a, 2b, 4, 7, 8, 9 and 10
--   /bst 5        one or more named checks; 3, 5 and 6 report after their wait
--   /bst hide     close the result window
local ACCOUNTS = { ['@Semigroup'] = true, ['@Semigroup1329'] = true }
if not ACCOUNTS[GetDisplayName()] then return end

local EVENT_NAME = 'BattleScrollsTaintTests'
local INSTANT = { '1', '2a', '2b', '4', '7', '8', '9', '10' }
local CHAT_LINES, CHAT_WIDTH = 6, 99
local WINDOW_WIDTH, WINDOW_PADDING, WINDOW_MS = 1200, 24, 45000
---@type table<string, boolean>
local selected = {}
local window, text

local function hideWindow()
    EVENT_MANAGER:UnregisterForUpdate(EVENT_NAME .. 'Hide')
    if window then window:SetHidden(true) end
end

---Results stay out of ESO's dialogs: a dialog shown from addon code would
---taint the shared button pool that check 5 inspects.
---@param lines string[]
local function showWindow(lines)
    if not window then
        window = WINDOW_MANAGER:CreateTopLevelWindow('BattleScrollsTaintTestResults')
        window:SetDrawTier(DT_HIGH)
        window:SetDrawLayer(DL_OVERLAY)
        window:SetAnchor(TOP, GuiRoot, TOP, 0, 60)
        local background = WINDOW_MANAGER:CreateControl('$(parent)Background', window, CT_BACKDROP)
        background:SetAnchorFill(window)
        background:SetCenterColor(0, 0, 0, 0.92)
        background:SetEdgeColor(0, 0, 0, 0)
        background:SetEdgeTexture('', 1, 1, 1, 0)
        text = WINDOW_MANAGER:CreateControl('$(parent)Text', window, CT_LABEL)
        text:SetFont('ZoFontGamepad27')
        text:SetAnchor(TOPLEFT, window, TOPLEFT, WINDOW_PADDING, WINDOW_PADDING)
        text:SetWidth(WINDOW_WIDTH - 2 * WINDOW_PADDING)
    end
    text:SetText(table.concat(lines, '\n'))
    window:SetDimensions(WINDOW_WIDTH, text:GetTextHeight() + 2 * WINDOW_PADDING)
    window:SetHidden(false)
    EVENT_MANAGER:UnregisterForUpdate(EVENT_NAME .. 'Hide')
    EVENT_MANAGER:RegisterForUpdate(EVENT_NAME .. 'Hide', WINDOW_MS, hideWindow)
end

---Short results go to chat; anything longer gets the window.
---@param lines string[]
local function report(lines)
    local chat = #lines <= CHAT_LINES
    for _, line in ipairs(lines) do chat = chat and #line <= CHAT_WIDTH end
    if not chat then showWindow(lines); return end
    for _, line in ipairs(lines) do d(line) end
end

---@param ... any
---@return string
local function join(...)
    local parts = {}
    for index = 1, select('#', ...) do parts[index] = tostring((select(index, ...))) end
    return table.concat(parts, ' ')
end

---The engine calls this directly, making it the outermost untrusted frame as
---the /script chunk is in the documented snippets. Checks 2a and 2b stay
---inline for that reason: a helper call would add a frame to their counts.
local function run()
    EVENT_MANAGER:UnregisterForUpdate(EVENT_NAME)
    local lines = {}
    if selected['1'] then
        local forwarded = ZO_GetCallbackForwardingFunction({}, d)
        lines[#lines + 1] = join('T1', IsTrustedFunction(ZO_GetCallbackForwardingFunction), IsTrustedFunction(forwarded),
            '| want true false')
    end
    if selected['2a'] then
        lines[#lines + 1] = join('T2a', pcall(DIRECTIONAL_INPUT.GetRightTriggerMagnitude, DIRECTIONAL_INPUT))
        lines[#lines + 1] = 'T2a want false, private IsKeyDown, 2 frames'
    end
    if selected['2b'] then
        lines[#lines + 1] = join('T2b', select(2, pcall(function() return DIRECTIONAL_INPUT:GetRightTriggerMagnitude() end)))
        lines[#lines + 1] = 'T2b want 3 frames'
    end
    if selected['4'] then
        local thread = coroutine.create(DIRECTIONAL_INPUT.GetRightTriggerMagnitude)
        lines[#lines + 1] = join('T4', coroutine.resume(thread, DIRECTIONAL_INPUT))
        lines[#lines + 1] = 'T4 want false and the private-function error'
    end
    if selected['7'] then
        local names = {}
        for name, scene in pairs(SCENE_MANAGER.scenes) do
            local info = scene.GetInteractionInfo and scene:GetInteractionInfo()
            if info and info.OnInteractionCanceled and not IsTrustedFunction(info.OnInteractionCanceled) then
                names[#names + 1] = name
            end
        end
        table.sort(names)
        lines[#lines + 1] = 'T7 ' .. (#names > 0 and table.concat(names, ', ') or 'none') .. ' | want none'
    end
    if selected['8'] then
        local descriptor = GAMEPAD_BANKING and GAMEPAD_BANKING.selectorKeybindStripDescriptor
        lines[#lines + 1] = join('T8', descriptor and descriptor[1] and IsTrustedFunction(descriptor[1].name),
            '| want nil before the first bank visit, then true')
    end
    if selected['9'] then
        local descriptor = LOOT_WINDOW_GAMEPAD and LOOT_WINDOW_GAMEPAD.keybindStripDescriptor
        lines[#lines + 1] = join('T9', descriptor and descriptor[1] and IsTrustedFunction(descriptor[1].callback),
            '| want true after ordinary loot')
    end
    if selected['10'] then
        lines[#lines + 1] = join('T10', type(rawget(_G, 'LoadString')), type(rawget(_G, 'LoadUntrustedString')),
            IsPrivateFunction('CancelTaskbarWindowFlash'), IsProtectedFunction('UseItem'), '| want function nil true true')
    end
    if selected['3'] then
        lines[#lines + 1] = join('T3', IsTrustedFunction(DIRECTIONAL_INPUT.GetRightTriggerMagnitude), '| want true; result in 1 s')
        local failure
        EVENT_MANAGER:RegisterForEvent(EVENT_NAME .. '3', EVENT_LUA_ERROR, function(_, message)
            failure = failure or message
        end)
        EVENT_MANAGER:RegisterForUpdate(EVENT_NAME .. '3', 100, DIRECTIONAL_INPUT.GetRightTriggerMagnitude)
        zo_callLater(function()
            EVENT_MANAGER:UnregisterForUpdate(EVENT_NAME .. '3')
            EVENT_MANAGER:UnregisterForEvent(EVENT_NAME .. '3', EVENT_LUA_ERROR)
            report({ 'T3 ' .. (failure or 'no error'), 'T3 want an IsKeyDown error' })
        end, 1200)
    end
    if selected['5'] then
        lines[#lines + 1] = 'T5 open a dialog with buttons within 10 s'
        zo_callLater(function()
            local results = {}
            for key, button in pairs(KEYBIND_STRIP.keybinds) do
                local descriptor = button.keybindButtonDescriptor or button
                if type(descriptor) == 'table' and descriptor.callback then
                    results[#results + 1] = 'T5 ' .. tostring(key) .. ': ' .. tostring(IsTrustedFunction(descriptor.callback))
                end
            end
            table.sort(results)
            results[#results + 1] = 'T5 want every DIALOG_ entry true'
            report(results)
        end, 10000)
    end
    if selected['6'] then
        lines[#lines + 1] = 'T6 open a bank within 8 s'
        zo_callLater(function()
            local synchronous, answered = true, false
            EVENT_MANAGER:RegisterForEvent(EVENT_NAME .. '6', EVENT_INTERACTION_ENDED, function(_, interaction)
                answered = true
                EVENT_MANAGER:UnregisterForEvent(EVENT_NAME .. '6', EVENT_INTERACTION_ENDED)
                report({ 'T6 ' .. tostring(interaction) .. ' sync=' .. tostring(synchronous) .. ' | want sync=false' })
            end)
            local interaction = GetInteractionType()
            EndInteraction(interaction)
            synchronous = false
            zo_callLater(function()
                if answered then return end
                EVENT_MANAGER:UnregisterForEvent(EVENT_NAME .. '6', EVENT_INTERACTION_ENDED)
                report({ 'T6 no interaction-ended event for interaction ' .. tostring(interaction) })
            end, 3000)
        end, 8000)
    end
    if #lines > 0 then report(lines) end
end

SLASH_COMMANDS['/bst'] = function(arguments)
    selected = {}
    for name in string.gmatch(string.lower(arguments or ''), '[%w]+') do selected[name] = true end
    if selected.hide then hideWindow(); return end
    if not next(selected) or selected.all then
        for _, name in ipairs(INSTANT) do selected[name] = true end
    end
    EVENT_MANAGER:RegisterForUpdate(EVENT_NAME, 0, run)
end
