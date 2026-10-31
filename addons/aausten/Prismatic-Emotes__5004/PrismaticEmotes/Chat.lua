local PE = PrismaticEmotes
PE.Chat = {}
local Chat = PE.Chat

-- ESO uses Lua 5.1; keep the newer-Lua fallback for offline tests.
local unpackResults = rawget(_G, "unpack") or rawget(table, "unpack")

local function packResults(...)
    return { n = select("#", ...), ... }
end

local function postProcess(formatted, channelType, fromName, text, fromDisplayName)
    if channelType == CHAT_CHANNEL_EMOTE and PE.saved and PE.saved.enabled
        and type(fromName) == "string" and type(text) == "string"
        and type(formatted) == "string" then
        local hex = PE.Palette.GetOrAssign(fromName)
        if hex then
            local entries = PE.saved.highlightMentions and PE.Palette.MentionEntries() or nil
            local result = PE.Markup.Format(formatted, text, fromName, fromDisplayName, hex,
                PE.saved.mode, PE.saved.highlightMentions, entries)
            if type(result) ~= "string" then
                error("Markup formatter returned a non-string message")
            end
            return result
        end
    end
    return formatted
end

local function formatEmote(original, channelType, fromName, text, isCustomerService,
                            fromDisplayName)
    local results = packResults(original(channelType, fromName, text,
        isCustomerService, fromDisplayName))
    local ok, formatted = pcall(postProcess, results[1], channelType, fromName, text, fromDisplayName)
    if ok then
        results[1] = formatted
    elseif not Chat.reportedError then
        Chat.reportedError = true
        -- Reporting a local formatting failure must not turn it into a delivery failure.
        pcall(function()
            PE.Print("Formatting error; original chat text preserved: " .. tostring(formatted))
        end)
    end
    return unpackResults(results, 1, results.n)
end

function Chat.IsInstalled()
    if not CHAT_ROUTER or not Chat.wrapper then
        return false
    end
    local formatters = CHAT_ROUTER:GetRegisteredMessageFormatters()
    return formatters and formatters[EVENT_CHAT_MESSAGE_CHANNEL] == Chat.wrapper
end

function Chat.Install()
    if not CHAT_ROUTER or type(CHAT_ROUTER.GetRegisteredMessageFormatters) ~= "function"
        or type(CHAT_ROUTER.RegisterMessageFormatter) ~= "function" then
        return false
    end
    local formatters = CHAT_ROUTER:GetRegisteredMessageFormatters()
    local previous = formatters and formatters[EVENT_CHAT_MESSAGE_CHANNEL]
    if type(previous) ~= "function" then
        return false
    end
    if previous == Chat.wrapper then
        return true
    end

    local wrapper = function(channelType, fromName, text, isCustomerService,
                             fromDisplayName)
        return formatEmote(previous, channelType, fromName, text,
            isCustomerService, fromDisplayName)
    end
    Chat.wrapper = wrapper
    CHAT_ROUTER:RegisterMessageFormatter(EVENT_CHAT_MESSAGE_CHANNEL, wrapper)
    return true
end
