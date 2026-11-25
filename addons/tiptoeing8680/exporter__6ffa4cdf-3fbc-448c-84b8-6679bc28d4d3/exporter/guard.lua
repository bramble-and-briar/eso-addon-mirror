-- guard.lua: decides whether this add-on is allowed to run for the current account.
--
-- Console uploads are public and there is no private test channel. The ESOUI moderators
-- suggest guarding test builds so they do nothing for anyone but the author.
--
-- BEFORE UPLOADING TO CONSOLE: set ALLOWED_DISPLAY_NAME (the one line below) to your own
-- account @handle. The leading "@" is optional and capitalisation doesn't matter.
-- While it is left at "@CHANGE_ME", the add-on is inert on console.
-- On the PC dev client it always runs (it's only ever uploaded to console).

CompanionExport = CompanionExport or {}

if CompanionExport_MemMarks then
    CompanionExport_MemMarks.afterVendor = collectgarbage("count") -- qrencode.lua has just loaded
end

CompanionExport.ALLOWED_DISPLAY_NAME = "@meow-flash" -- <-- the only line to edit

local PLACEHOLDER = "@CHANGE_ME"

local function normalise(name)
    name = string.lower(name or "")
    if string.sub(name, 1, 1) ~= "@" then
        name = "@" .. name
    end
    return name
end

function CompanionExport.IsAllowed()
    if not IsConsoleUI() then
        return true
    end
    local allowed = normalise(CompanionExport.ALLOWED_DISPLAY_NAME)
    if allowed == normalise(PLACEHOLDER) then
        return false
    end
    return normalise(GetDisplayName()) == allowed
end
