LazyLearner.Utils = LazyLearner.Utils or {}
local Utils = LazyLearner.Utils
local EnchantingLearner = LazyLearner.EnchantingLearner
local AlchemyLearner = LazyLearner.AlchemyLearner

--- Converts RGB values to a hexadecimal color string.
--- This function takes RGB values in the range 0–1 and converts them to a hexadecimal color string.
--- @param r The red component (0–1).
--- @param g The green component (0–1).
--- @param b The blue component (0–1).
--- @return A string representing the color in hexadecimal format (e.g., "FF0000" for red).
function Utils.RGBToHex(r, g, b)
    -- Clamp values to range 0–255
    r = math.max(0, math.min(255, r))
    g = math.max(0, math.min(255, g))
    b = math.max(0, math.min(255, b))

    return
        string.format("%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

--- Converts RGB color values to a hexadecimal color string.
--- @param color A table containing r, g, and b fields with values in the range 0–1.
--- @return A string representing the color in hexadecimal format (e.g., "FF0000" for red).
function Utils.RGBColorToHex(color)
    return Utils.RGBToHex(color.r, color.g, color.b)
end

--- Generates an eso item link string for a given item ID.
--- @param itemId The ID of the item.
--- @return A string representing the item link.
function Utils.getItemLinkFromItemId(itemId)
    return string.format("|H1:item:%d:%d:50:0:0:0:0:0:0:0:0:0:0:0:0:%d:%d:0:0:%d:0|h|h", itemId, 0, 0, 0, 10000)
end

--- Gets the total number of available items across all bags (inventory, bank and craftbag) for a given item ID.
--- @param itemId The ID of the item.
--- @return The total number of available items.
function Utils.GetNumberOfAvailableItems(itemId)
    local bag, bank, craft = GetItemLinkStacks(Utils.getItemLinkFromItemId(itemId))
    return bag + bank + craft
end

--- Function to check if a value exists in a table
--- @param table The table to search
--- @param value The value to search for
--- @return boolean True if the value is found, false otherwise
function Utils.Contains(table, value)
    for _, v in pairs(table) do
        if v == value then
            return true
        end
    end
    return false
end

--- Announces a message in the center of the screen.
--- @param msg The message to announce.
function Utils.announceMessage(msg)
    local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, SOUNDS.ACHIEVEMENT_AWARDED)
    params:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_CRAFTING_RESULTS)
    params:SetText(msg)
    CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
end

--- Sends a chat message to the default chat window.
--- @param msg The message to send.
--- @param color The color of the message (optional). If not specified the color in the account-wide saved variable will be used.
function Utils.sendChatMessage(msg, color)
    if not color then
        color = Utils.RGBColorToHex(LazyLearner.savedVars.msgcolor)
    end
    if not LibChatMessage then
        CHAT_ROUTER:AddSystemMessage("|c" .. color .. msg .. "|r ")
        return
    end
    local chat = LibChatMessage(LazyLearner.L("LL_LAZYLEARNER"), LazyLearner.L("LL_LAZYLEARNER"))
    LibChatMessage:SetTagPrefixMode(TAG_PREFIX_SHORT)
    chat:SetTagColor(color):Print("|c" .. color .. msg .. "|r ")
end

--- Retrieves a localized string for a given key.
--- @param key The key for the localized string.
--- @return The localized string if found, otherwise returns the key itself.
function LazyLearner.L(key)
    return LazyLearner.strings and LazyLearner.strings[key] or key
end