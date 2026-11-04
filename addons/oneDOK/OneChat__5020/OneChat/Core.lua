OneChat = {}
local A = OneChat
A.name = "OneChat"
A.schema = 2
A.windows = setmetatable({}, { __mode = "k" })

function A:Notify(id)
    ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.GENERAL_ALERT_ERROR, GetString(id))
end

-- Keep the ZO_SavedVars storage version stable: explicit schema migrations
-- preserve user data instead of letting ZO_SavedVars reset it on upgrade.
function A:Migrate(sv)
    if (sv.schema or 1) > self.schema then return false end
    if not sv.schema or sv.schema < 2 then
        if sv.showTimestamp ~= nil then sv.timestamps = sv.showTimestamp end
        sv.showTimestamp = nil
        sv.schema = 2
    end
    if not sv.tabs then
        sv.abbreviations = sv.abbreviations or {}
        sv.toolbar = sv.toolbar or { home = true }
        if sv.toolbar.reload == nil then sv.toolbar.reload = true end
        if sv.toolbar.language == nil then sv.toolbar.language = true end
    end
    return true
end

function A:InitializeSavedVariables()
    self.sv = ZO_SavedVars:NewAccountWide("OneChatSavedVariables", 1, nil, {
        schema = 1, timestamps = true, newline = false,
        abbreviations = {}, toolbar = { home = true, reload = true, language = true },
    }, GetWorldName())
    self.character = ZO_SavedVars:NewCharacterIdSettings("OneChatSavedVariables", 1, "Tabs", {
        schema = 1, tabs = {},
    }, GetWorldName())
    if not self:Migrate(self.sv) or not self:Migrate(self.character) then
        self:Notify(SI_ONECHAT_NEWER_SCHEMA)
        return false
    end
    return true
end

-- Strip presentation markup for the copy dialog; never strip links in chat.
function A:PlainText(text)
    text = text:gsub("|H[^|]*|h(.-)|h", "%1")
    text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("|t.-|t", ""):gsub("|u.-|u", "")
    return text
end
