local PE = PrismaticEmotes
PE.Chat = {}
local Chat = PE.Chat

local unpackResults = unpack or table.unpack

local function packResults(...)
    return { n = select("#", ...), ... }
end

local function formatEmote(original, channelType, fromName, text, isCustomerService,
                            fromDisplayName)
    local results = packResults(original(channelType, fromName, text,
        isCustomerService, fromDisplayName))

    if channelType == CHAT_CHANNEL_EMOTE and PE.saved and PE.saved.enabled
        and type(fromName) == "string" and type(text) == "string"
        and type(results[1]) == "string" then
        local hex = PE.Palette.GetOrAssign(fromName)
        if hex then
            local entries = PE.saved.highlightMentions and PE.Palette.MentionEntries() or nil
            local ok, formatted = pcall(PE.Markup.Format, results[1], text, fromName,
                fromDisplayName, hex, PE.saved.mode, PE.saved.highlightMentions, entries)
            if ok then
                results[1] = formatted
            elseif not Chat.reportedError then
                Chat.reportedError = true
                PE.Print("Formatting error; original chat text preserved: " .. tostring(formatted))
            end
        end
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
