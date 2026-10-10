-- ESO can return an escaped unit name even when chat supplies the correct name.
-- Patch the two unit-name getters, keeping descriptors such as ^Mx intact.
local ADDON_NAME = "ApostropheNameFix"
local enabled = true
local corrections = 0
local originalGetRawUnitName = GetRawUnitName
local originalGetUnitName = GetUnitName
local BACKSLASH = string.char(92)
local ESCAPED_APOSTROPHE = BACKSLASH .. "'"
local ESCAPED_APOSTROPHE_PATTERN = BACKSLASH .. "+'"

-- Plain text to share, never evaluated by this addon. The recipient can run
-- it explicitly on their own client. string.char avoids chat escaping issues.
-- The flag makes repeat pastes harmless; /anf prevents stacking on this addon.
local TEMP_FIX_SCRIPT = [[/script if not ANF_Temp and not SLASH_COMMANDS["/anf"] then ANF_Temp=true for _,k in ipairs({"GetRawUnitName","GetUnitName"}) do local f=_G[k] _G[k]=function(...) local s=f(...) return type(s)=="string" and(s:gsub(string.char(92).."+'","'"))or s end end end GROUP_LIST_MANAGER:RefreshData() UNIT_FRAMES:UpdateNames()]]

local function NormalizeName(name)
    if type(name) ~= "string" or not name:find(ESCAPED_APOSTROPHE, 1, true) then
        return name
    end

    -- In Lua patterns the escape character is %, so backslash is literal here.
    -- Collapse one or more backslashes only when followed by an apostrophe.
    -- Parentheses discard gsub's second return value (the replacement count).
    return (name:gsub(ESCAPED_APOSTROPHE_PATTERN, "'"))
end

local function FilterName(name)
    if not enabled then
        return name
    end
    local fixed = NormalizeName(name)
    if fixed ~= name then
        corrections = corrections + 1
    end
    return fixed
end

-- Install at file load so later addon initialization sees the wrappers.
-- Keep them in place when toggling off: replacing the globals on each toggle
-- could break a wrapper installed by another addon after this one.
GetRawUnitName = function(...)
    return FilterName(originalGetRawUnitName(...))
end

GetUnitName = function(...)
    return FilterName(originalGetUnitName(...))
end

local function Print(message)
    CHAT_SYSTEM:AddMessage("|c88CCFFANF:|r " .. message)
end

local function RefreshNames()
    -- The built-in travel menu uses characterName from this cached roster.
    if GROUP_LIST_MANAGER then
        GROUP_LIST_MANAGER:RefreshData()
    end
    if UNIT_FRAMES then
        UNIT_FRAMES:UpdateNames()
    end
end

local function ShowValue(label, value)
    if type(value) ~= "string" then
        Print(label .. " = " .. tostring(value))
        return
    end
    local _, backslashes = value:gsub(BACKSLASH, "")
    local bytes = table.concat({ value:byte(1, #value) }, ",")
    -- Do not use %q: its own escaping would obscure the evidence.
    local visible = value:gsub("|", "<pipe>")
    Print(label .. " [" .. visible .. "] BS=" .. backslashes .. " bytes=" .. bytes)
end

local function CheckUnit(unitTag, onlyInteresting)
    -- Read through the function captured before our hook, regardless of mode.
    local original = originalGetRawUnitName(unitTag)
    if onlyInteresting and (type(original) ~= "string"
        or not original:find("'", 1, true)) then
        return false
    end
    ShowValue(unitTag .. " before", original)
    ShowValue(unitTag .. " after", GetRawUnitName(unitTag))
    ShowValue(unitTag .. " display", GetUnitName(unitTag))
    return true
end

local function ShowStatus()
    Print("patch=" .. (enabled and "on" or "off")
        .. "; corrected getter results=" .. corrections
        .. "; /anf check to compare original and current names")
end

local function PrepareDraft(message)
    -- Check the actual game's limit before putting anything in its edit box.
    local limit = MAX_TEXT_CHAT_INPUT_CHARACTERS or 350
    if #message > limit then
        Print("draft exceeds the chat limit; use the sharing guide included with the addon")
        return
    end
    Print("preparing a draft in your current channel; copy it or press Enter to send")
    -- The slash-command handler is still submitting/closing its own entry.
    -- Reopen on the next UI tick, without submitting the new text.
    zo_callLater(function()
        StartChatInput(message)
    end, 0)
end

local function ShareTemporaryFix()
    Print("recipient: paste only from /script onward; lasts until logout or /reloadui")
    PrepareDraft("Temp fix until reload; paste: " .. TEMP_FIX_SCRIPT)
end

local function ShareTravel(unitTag)
    unitTag = unitTag ~= "" and unitTag:lower() or "player"
    local account = GetUnitDisplayName(unitTag)
    if type(account) ~= "string" or account == "" then
        Print("no account found for " .. unitTag .. "; use /anf travel [player|group1|reticleover]")
        return
    end
    -- Use an account name with the built-in command. The recipient needs
    -- neither this addon nor Lua to bypass the malformed character name.
    local jumpCommand = GetString(SI_SLASH_JUMP_TO_GROUP_MEMBER)
    local name = NormalizeName(originalGetUnitName(unitTag)) or account
    PrepareDraft("Group travel to " .. name .. " (paste command): " .. jumpCommand .. " " .. account)
end

local function Command(arguments)
    local command, unitTag = (arguments or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()

    if command == "on" or command == "off" then
        enabled = command == "on"
        RefreshNames()
        ShowStatus()
    elseif command == "refresh" then
        RefreshNames()
        Print("group roster and unit-frame names refreshed")
    elseif command == "share" then
        ShareTemporaryFix()
    elseif command == "travel" then
        ShareTravel(unitTag)
    elseif command == "check" then
        if unitTag ~= "" then
            CheckUnit(unitTag:lower(), false)
        else
            local found = CheckUnit("player", true)
            for i = 1, GetGroupSize() do
                local tag = GetGroupUnitTagByIndex(i)
                if tag and CheckUnit(tag, true) then
                    found = true
                end
            end
            if not found then
                Print("no apostrophe names found in player/group units; try /anf check reticleover")
            end
        end
    elseif command == "" or command == "status" then
        ShowStatus()
    else
        Print("/anf on | off | status | refresh | check [unitTag] | share | travel [unitTag]")
    end
end

SLASH_COMMANDS["/anf"] = Command

-- Core UI creates its initial roster before addons load. Rebuild after login
-- or reload, once the group and unit-frame managers are ready.
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, function()
    RefreshNames()
end)
