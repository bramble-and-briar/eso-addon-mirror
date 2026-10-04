local A, S = PBS_HUD_MANAGER, PBS_HUD_MANAGER_STRINGS

local function Print(text)
    for line in (text .. "\n"):gmatch("(.-)\n") do d(line) end
end

-- The command does what the buttons do, minus the second press: typing it is already
-- deliberate.
function A:Command(input)
    local command, rest = string.lower(input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    -- The name is typed in its own case, so it is taken from the original text.
    local original = (input or ""):match("^%s*%S+%s+%S+%s*(.-)%s*$") or ""
    if command == "save" or command == "load" then
        local number = rest:match("^(%S+)")
        local index = self:ValidSlot(number)
        if not index then
            Print(self:Format(S.badSlot, { max = self.slotCount }))
            return
        end
        if command == "save" then self:Save(index, original) else self:Load(index) end
        Print(self.message)
    elseif command == "" or command == "list" or command == "status" then
        for _, line in ipairs(self:ListLines()) do Print(line) end
        if command == "" then Print(S.help) end
    else
        Print(S.help)
    end
end

local function OnLoaded(_, name)
    if name ~= A.name then return end
    EVENT_MANAGER:UnregisterForEvent(A.name, EVENT_ADD_ON_LOADED)
    A.sv = ZO_SavedVars:NewAccountWide("PBsHudManager_Data", 1, nil, A.defaults)
    A:Normalize()
    A:InitSettings()
    SLASH_COMMANDS["/pbhud"] = function(input) A:Command(input) end
    EVENT_MANAGER:RegisterForEvent(A.name, EVENT_PLAYER_ACTIVATED, function()
        A:EnsureInitialSet()
    end)
end
EVENT_MANAGER:RegisterForEvent(A.name, EVENT_ADD_ON_LOADED, OnLoaded)
