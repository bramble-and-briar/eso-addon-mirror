local PE = PrismaticEmotes
PE.Commands = {}
local Commands = PE.Commands

local function parseCharacterName(argument)
    if not argument then
        return nil
    end
    local name = argument:match("^%s*(.-)%s*$")
    -- Only double quotes delimit names; apostrophes stay literal.
    if name:sub(1, 1) == '"' then
        if #name < 2 or name:sub(-1) ~= '"' then
            return nil
        end
        name = name:sub(2, -2):match("^%s*(.-)%s*$")
    end
    if name == "" then
        return nil
    end
    return name
end

local function printHelp()
    PE.Print("/pe on|off   - Enable/disable coloring")
    PE.Print("/pe mode author|body|both   - Choose the area to color")
    PE.Print("/pe mentions on|off   - Highlight names already encountered")
    PE.Print('/pe color "Character Name" #RRGGBB   - Set a manual color')
    PE.Print('/pe auto "Character Name"   - Restore the assigned automatic color')
    PE.Print('/pe forget "Character Name" | /pe forget all   - Remove colors')
    PE.Print("Names may include spaces and punctuation; double quotes and # are optional.")
    PE.Print("/pe list | status | preview | rehook | help")
end

local function status()
    local rows = PE.Palette.List()
    local state = PE.saved.enabled and "on" or "off"
    PE.Print(string.format("v%s | %s | mode: %s | mentions: %s | characters: %d | hook: %s",
        PE.version, state, PE.saved.mode, PE.saved.highlightMentions and "on" or "off",
        #rows, PE.Chat.IsInstalled() and "active" or "not attached"))
end

local function preview()
    -- Use a throwaway palette: a preview should never occupy real color slots.
    local samples = {
        { "Leiadriel Milandris", "watches the travelers crossing the bridge." },
        { "Eirnich", "leans on the railing and looks toward Leiadriel Milandris." },
        { "Varvyn", "approaches Eirnich cautiously." },
    }
    local mentions = {}
    for i, sample in ipairs(samples) do
        mentions[#mentions + 1] = {
            key = string.lower(sample[1]),
            color = PE.Palette.colors[i],
        }
    end
    for i, sample in ipairs(samples) do
        local hex = PE.Palette.colors[i]
        local message = sample[1] .. " " .. sample[2]
        PE.Print(PE.Markup.Format(message, sample[2], sample[1], "", hex,
            PE.saved.mode, PE.saved.highlightMentions, mentions))
    end
end

function Commands.Handle(argument)
    if not PE.saved then
        return
    end
    local input = tostring(argument or ""):match("^%s*(.-)%s*$")
    local command, remainder = input:match("^(%S+)%s*(.-)$")
    command = (command or "help"):lower()
    remainder = remainder or ""

    if command == "help" or command == "" then
        printHelp()
    elseif command == "on" or command == "off" then
        PE.saved.enabled = command == "on"
        status()
    elseif command == "status" then
        status()
    elseif command == "mode" then
        local selected = remainder:lower()
        if selected == "author" or selected == "body" or selected == "both" then
            PE.saved.mode = selected
            status()
        else
            PE.Print("Usage: /pe mode author|body|both")
        end
    elseif command == "mentions" then
        local selected = remainder:lower()
        if selected == "on" or selected == "off" then
            PE.saved.highlightMentions = selected == "on"
            status()
        else
            PE.Print("Usage: /pe mentions on|off")
        end
    elseif command == "color" then
        -- Only the final token is the color; the rest is the complete name.
        local name, hex = remainder:match("^(.-)%s+(#?%x%x%x%x%x%x)$")
        name = parseCharacterName(name)
        if name and PE.Palette.SetOverride(name, hex) then
            PE.Print(name .. " -> |c" .. hex:gsub("^#", ""):upper() .. hex .. "|r")
        else
            PE.Print('Usage: /pe color "Character Name" #RRGGBB')
        end
    elseif command == "auto" then
        local name = parseCharacterName(remainder)
        if not name then
            PE.Print('Usage: /pe auto "Character Name"')
        elseif PE.Palette.ClearOverride(name) then
            PE.Print("Restored automatic color for " .. name)
        else
            PE.Print("Unknown character: " .. name)
        end
    elseif command == "forget" then
        local name = parseCharacterName(remainder)
        if remainder:lower() == "all" then
            PE.Palette.ForgetAll()
            PE.Print("All learned character colors cleared.")
        elseif name and PE.Palette.Forget(name) then
            PE.Print("Forgot color for " .. name)
        else
            PE.Print('Unknown character. Usage: /pe forget "Character Name"')
        end
    elseif command == "list" then
        local rows = PE.Palette.List()
        PE.Print("Learned characters: " .. #rows)
        for i = 1, math.min(#rows, 20) do
            local entry = rows[i]
            PE.Print("|c" .. entry.color .. entry.name .. "|r (" .. entry.color
                .. (entry.manual and ", manual" or "") .. ")")
        end
        if #rows > 20 then PE.Print("Showing the first 20 characters.") end
    elseif command == "preview" then
        preview()
    elseif command == "rehook" then
        PE.Print(PE.Chat.Install() and "Chat formatter attached." or
            "Chat formatter unavailable.")
    else
        PE.Print("Unknown command: " .. command)
        printHelp()
    end
end

function Commands.Register()
    SLASH_COMMANDS["/pe"] = Commands.Handle
    SLASH_COMMANDS["/prismaticemotes"] = Commands.Handle
end
