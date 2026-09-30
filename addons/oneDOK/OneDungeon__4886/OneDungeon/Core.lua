OneDungeon = { name = "OneDungeon", version = "1.0", errors = {} }
local A = OneDungeon
function A:Log(message)
    if self.saved and self.saved.debug then d("OneDungeon: " .. tostring(message)) end
end
function A:Optional(label, callback, fallback)
    local ok, result = pcall(callback)
    if ok then return result end
    self.errors[label] = tostring(result)
    self:Log(label .. ": " .. tostring(result))
    return fallback
end
function A:Invalidate()
    self.questCache = nil
    self.achievementCache = {}
end
