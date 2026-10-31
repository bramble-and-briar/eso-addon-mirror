-- Inject a unique top-level entry into ESO's gamepad menu registry.
-- The stock gamepad menu uses global ZO_MENU_ENTRIES; do not alter stock categories.
local TC = TamrielCollections
local function Install()
    if TC.menuEntryInstalled then return true end
    if type(ZO_MENU_ENTRIES) ~= 'table' or not ZO_GamepadEntryData then return false end
    local icon = 'TamrielCollectionsMotifs/art/collections_puzzle_native_v4.dds'
    local data = {
        name = 'TAMRIEL ARCHIVE',
        icon = icon,
        isSubmenu = true,
        scene = 'tamrielCollectionsGamepad',
    }
    local entry = ZO_GamepadEntryData:New(data.name, data.icon)
    -- Supply both entry-level and data-level texture hints for different menu renderers.
    if entry.SetIcon then pcall(function() entry:SetIcon(icon) end) end
    entry.icon = icon
    entry:SetIconTintOnSelection(true)
    entry:SetIconDisabledTintOnSelection(true)
    entry.data = data
    entry.isSubmenu = true
    entry.hasChildren = true
    entry.id = 10001
    -- Locate Social by multiple supported representations. The earlier build
    -- inspected only candidate.data.name, which did not match on PS5.
    local position = #ZO_MENU_ENTRIES + 1
    local function EntryLabel(candidate)
        local d = candidate.data or candidate
        local values = { d.name, d.label, d.text, candidate.name, candidate.label }
        if type(candidate.GetText) == 'function' then
            local ok, value = pcall(candidate.GetText, candidate)
            if ok then values[#values + 1] = value end
        end
        for _, value in pairs(values) do
            if type(value) == 'string' and string.find(string.lower(value), 'social', 1, true) then
                return true
            end
        end
        return false
    end
    for i, candidate in ipairs(ZO_MENU_ENTRIES) do
        if EntryLabel(candidate) then position = i + 1; break end
    end
    table.insert(ZO_MENU_ENTRIES, position, entry)
    TC.menuEntryInstalled = true
    if MAIN_MENU_GAMEPAD and MAIN_MENU_GAMEPAD.RefreshMainList then
        MAIN_MENU_GAMEPAD:RefreshMainList()
    end
    return true
end
EVENT_MANAGER:RegisterForEvent('TCArchiveMotifsMenuInit', EVENT_PLAYER_ACTIVATED, function()
    EVENT_MANAGER:UnregisterForEvent('TCArchiveMotifsMenuInit', EVENT_PLAYER_ACTIVATED)
    local ok, result = pcall(Install)
    if (not ok or not result) and d then d('[TCM] Main-menu entry could not be installed.') end
end)
