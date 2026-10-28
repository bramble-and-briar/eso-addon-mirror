GuildMarketScannerDev = GuildMarketScannerDev or {}
-- Tamriel Collections GMS: isolated fragment detection (runtime test build)
-- No background polling or saved-variable allocations.
local GMS = GuildMarketScannerDev
GMS.fragmentQuantityRules = GMS.fragmentQuantityRules or {}
GMS.fragmentComponentRules = GMS.fragmentComponentRules or {}

-- Rules are keyed ONLY by verified physical item IDs. A nil answer means unknown.
function GMS:MissingQuantityFragment(link)
    if type(link) ~= 'string' or type(GetItemLinkItemId) ~= 'function' then return nil end
    local ok, itemId = pcall(GetItemLinkItemId, link)
    if not ok then return nil end
    local rule = self.fragmentQuantityRules[itemId]
    if not rule or type(rule.getProgress) ~= 'function' or type(rule.required) ~= 'number' then return nil end
    local success, count = pcall(rule.getProgress)
    if not success or type(count) ~= 'number' then return nil end
    return count < rule.required
end

function GMS:MissingComponentFragment(link)
    if type(link) ~= 'string' or type(GetItemLinkItemId) ~= 'function' then return nil end
    local ok, itemId = pcall(GetItemLinkItemId, link)
    if not ok or type(itemId) ~= 'number' then return nil end
    local rule = self.fragmentComponentRules[itemId]
    if rule and type(rule.getCollected) == 'function' then
        local success, collected = pcall(rule.getCollected)
        if success and type(collected) == 'boolean' then return not collected end
    end
    -- Optional installed library; no dependency or external addon required.
    -- Only a completed reward can be safely excluded from this lookup.
    local lib = LibRunebox
    if type(lib) == 'table' and type(lib.GetRuneboxForFragment) == 'function' then
        local success, runeboxId = pcall(lib.GetRuneboxForFragment, lib, itemId)
        if success and type(runeboxId) == 'number' and runeboxId > 0
            and type(lib.IsRuneboxCollected) == 'function' then
            local status, collected = pcall(lib.IsRuneboxCollected, lib, runeboxId)
            if status and collected == true then return false end
        end
    end
    return nil
end

function GMS:MissingFragment(link)
    local quantity = self:MissingQuantityFragment(link)
    if quantity ~= nil then return quantity end
    return self:MissingComponentFragment(link)
end

-- Existing Missing() is never modified. This is a separate result-stage check.
function GMS:MissingWithFragments(link)
    local fragment = self:MissingFragment(link)
    if fragment ~= nil then return fragment end
    return self:Missing(link)
end

-- Runtime diagnostic: paste an item link after /gmsfragment to inspect how
-- the fragment detector classifies it. Does not modify saved variables.
local function FragmentSay(message)
    if CHAT_ROUTER and type(CHAT_ROUTER.AddSystemMessage)=='function' then
        CHAT_ROUTER:AddSystemMessage('[GMS Fragments] '..tostring(message))
    elseif type(d)=='function' then d('[GMS Fragments] '..tostring(message)) end
end
local function ParseLink(text)
    if type(text)~='string' then return nil end
    return text:match('(|H[^|]+|h.-|h)') or text:match('(|H[^|]+|h.-|h|r)')
end
SLASH_COMMANDS = SLASH_COMMANDS or {}
SLASH_COMMANDS['/gmsfragment'] = function(argument)
    local link=ParseLink(argument)
    if not link then
        FragmentSay('Paste an item link after /gmsfragment. Example: /gmsfragment [linked item]')
        return
    end
    local ok,id=pcall(GetItemLinkItemId,link)
    local result=GMS:MissingFragment(link)
    FragmentSay('itemId='..tostring(ok and id or '?')..' fragment='..(result==nil and 'unmapped' or result and 'MISSING' or 'COMPLETE'))
    local native=GMS:Missing(link)
    FragmentSay('original detector='..(native==nil and 'unknown' or native and 'MISSING' or 'KNOWN'))
end
-- Allows a verified mapping to be registered without changing the original detector.
-- getProgress is evaluated only when the corresponding item appears in a listing.
function GMS:RegisterQuantityFragment(itemId, required, getProgress)
    if type(itemId)~='number' or itemId<=0 or type(required)~='number' or required<=0 or type(getProgress)~='function' then return false end
    self.fragmentQuantityRules[itemId]={required=required,getProgress=getProgress}
    return true
end
function GMS:RegisterComponentFragment(itemId, collectibleId)
    if type(itemId)~='number' or itemId<=0 or type(collectibleId)~='number' or collectibleId<=0 then return false end
    self.fragmentComponentRules[itemId]={getCollected=function()
        if type(IsCollectibleUnlocked)~='function' then return nil end
        return IsCollectibleUnlocked(collectibleId)
    end}
    return true
end
