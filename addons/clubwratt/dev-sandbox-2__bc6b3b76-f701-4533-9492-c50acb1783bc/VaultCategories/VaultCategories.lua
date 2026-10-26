-- VaultCategories.lua: furniture category headers for the gamepad bank lists.
--
-- How the gamepad bank list groups items: ZO_GamepadInventoryList:AddSlotDataToTable writes
-- slotData.bestGamepadItemCategoryName = (self.categorizationFunction or
-- ZO_InventoryUtils_Gamepad_GetBestItemCategoryDescription)(slotData), the bank sorts the slots by
-- that string (tiebreaker: name) and starts a header whenever it changes. The bank's two lists
-- are created with no categorizationFunction, so every furnishing lands under one "Furnishing"
-- header. We give those lists (withdraw + deposit, created in OnDeferredInitialize) a function
-- that returns the furniture category / subcategory name for furnishings while the Furnishing
-- Vault is open, and defers to the game's own function for everything else. No hooks on game
-- calls other than a SecurePostHook to learn when the lists exist.
VaultCategories = {
    name = "VaultCategories",
    displayName = "Vault Categories",
    version = "0.1.0",
    savedVarsName = "VaultCategoriesSavedVars",
    savedVarsVersion = 1,
    defaults = {
        enabled = true,
        -- "Category - Subcategory" headers (true) or category-only headers (false).
        subcategories = true,
        -- Also group furnishings this way in the regular bank / house banks and the inventory side
        -- of those screens (where they sit next to other item types).
        everywhere = false,
        debug = false,
    },
}
local VC = VaultCategories
VC.savedVars = VC.defaults

local function Fmt(fmt, ...)
    local ok, s = pcall(string.format, fmt, ...)
    return ok and s or tostring(fmt)
end

local function Chat(line)
    if CHAT_ROUTER then
        CHAT_ROUTER:AddSystemMessage(Fmt("[%s] %s", VC.displayName, line))
    end
end

local function Debug(fmt, ...)
    if not VC.savedVars.debug then
        return
    end
    local line = Fmt(fmt, ...)
    Chat(line)
    local lib = rawget(_G, "LibConsoleLogger")
    if lib and lib.Buffer then
        lib:Buffer("[" .. VC.name .. "] " .. line)
    end
end

-- Category lookup -------------------------------------------------------------------

local categoryNameCache = {} -- furnitureDataId -> header string (per subcategories setting)
local cacheUsesSubcategories = nil

local function CategoryName(categoryId)
    if not categoryId or categoryId == 0 then
        return nil
    end
    local ok, name = pcall(GetFurnitureCategoryInfo, categoryId)
    if ok and name and name ~= "" then
        return name
    end
    return nil
end

---Header text for a furnishing, or nil when the game knows no category for it.
---@param bagId integer
---@param slotIndex integer
---@return string|nil
local function FurnitureHeader(bagId, slotIndex)
    if cacheUsesSubcategories ~= VC.savedVars.subcategories then
        categoryNameCache = {}
        cacheUsesSubcategories = VC.savedVars.subcategories
    end
    local okId, furnitureDataId = pcall(GetItemFurnitureDataId, bagId, slotIndex)
    if not okId or not furnitureDataId or furnitureDataId == 0 then
        return nil
    end
    local cached = categoryNameCache[furnitureDataId]
    if cached ~= nil then
        return cached or nil
    end
    local okInfo, categoryId, subcategoryId = pcall(GetFurnitureDataInfo, furnitureDataId)
    local header = nil
    if okInfo then
        local category = CategoryName(categoryId)
        local subcategory = VC.savedVars.subcategories and CategoryName(subcategoryId) or nil
        if category and subcategory and subcategory ~= category then
            header = category .. " - " .. subcategory
        else
            header = category or subcategory
        end
    end
    categoryNameCache[furnitureDataId] = header or false
    return header
end

-- Categorization function installed on the bank lists ---------------------------------

local function ShouldCategorize(slotData)
    if not VC.savedVars.enabled or slotData.itemType ~= ITEMTYPE_FURNISHING then
        return false
    end
    if VC.savedVars.everywhere then
        return true
    end
    local ok, bankBag = pcall(GetBankingBag)
    return ok and bankBag ~= nil and IsFurnitureVault(bankBag)
end

local fallbackLogs = 0
local function Categorize(slotData)
    if ShouldCategorize(slotData) then
        local header = FurnitureHeader(slotData.bagId, slotData.slotIndex)
        if header then
            return header
        end
        if fallbackLogs < 10 then
            fallbackLogs = fallbackLogs + 1
            Debug("no furniture category for '%s' (bag %s slot %s)", tostring(slotData.name), tostring(slotData.bagId), tostring(slotData.slotIndex))
        end
    end
    return ZO_InventoryUtils_Gamepad_GetBestItemCategoryDescription(slotData)
end

local installedLists = setmetatable({}, { __mode = "k" })
local function InstallOnList(list, label)
    if type(list) ~= "table" or installedLists[list] then
        return
    end
    if list.categorizationFunction ~= nil then
        Debug("%s list already has a categorization function; wrapping it", label)
        local original = list.categorizationFunction
        list.categorizationFunction = function(slotData)
            if ShouldCategorize(slotData) then
                local header = FurnitureHeader(slotData.bagId, slotData.slotIndex)
                if header then
                    return header
                end
            end
            return original(slotData)
        end
    else
        list.categorizationFunction = Categorize
    end
    installedLists[list] = true
    Debug("categorization installed on %s list", label)
end

local function InstallOnBanking(banking)
    if not banking then
        return
    end
    InstallOnList(banking.withdrawList, "withdraw")
    InstallOnList(banking.depositList, "deposit")
end

local function RefreshBankLists()
    local banking = rawget(_G, "GAMEPAD_BANKING")
    if not banking then
        return
    end
    for _, list in ipairs({ banking.withdrawList, banking.depositList }) do
        if list and list.RefreshList then
            pcall(function() list:RefreshList() end)
        end
    end
end

-- Commands ---------------------------------------------------------------------------

local function Help()
    Chat("/vcat on | off | sub (toggle subcategory headers) | everywhere (toggle furnishings grouping outside the vault) | status | debug")
end

SLASH_COMMANDS["/vcat"] = function(args)
    local command = string.lower(string.match(args or "", "^%s*(%S*)") or "")
    local sv = VC.savedVars
    if command == "on" or command == "off" then
        sv.enabled = command == "on"
        Chat(Fmt("category headers %s", sv.enabled and "enabled" or "disabled"))
    elseif command == "sub" then
        sv.subcategories = not sv.subcategories
        Chat(Fmt("subcategory headers %s", sv.subcategories and "ON" or "OFF"))
    elseif command == "everywhere" then
        sv.everywhere = not sv.everywhere
        Chat(Fmt("grouping furnishings outside the vault %s", sv.everywhere and "ON" or "OFF"))
    elseif command == "debug" then
        sv.debug = not sv.debug
        Chat(Fmt("debug %s", sv.debug and "ON" or "OFF"))
    elseif command == "status" then
        local banking = rawget(_G, "GAMEPAD_BANKING")
        Chat(Fmt("v%s enabled=%s subcategories=%s everywhere=%s lists=%s/%s bankingBag=%s", VC.version, tostring(sv.enabled), tostring(sv.subcategories),
            tostring(sv.everywhere), tostring(banking and banking.withdrawList and installedLists[banking.withdrawList] == true),
            tostring(banking and banking.depositList and installedLists[banking.depositList] == true), tostring(GetBankingBag())))
    else
        Help()
        return
    end
    RefreshBankLists()
end

-- Load --------------------------------------------------------------------------------

local function Initialize()
    local ok, savedVars = pcall(ZO_SavedVars.NewAccountWide, ZO_SavedVars, VC.savedVarsName, VC.savedVarsVersion, nil, VC.defaults)
    if ok then
        VC.savedVars = savedVars
    else
        Chat("saved variables unavailable; using defaults")
    end

    if not rawget(_G, "ZO_BankingCommon_Gamepad") then
        Chat("gamepad banking UI not available; addon inactive")
        return
    end
    -- Lists are created on the bank's first open (OnDeferredInitialize); install then. If the
    -- bank was already initialized before we loaded (never on a normal load), install right away.
    local hook = SecurePostHook or ZO_PostHook
    hook(ZO_BankingCommon_Gamepad, "OnDeferredInitialize", function(self)
        pcall(InstallOnBanking, self)
    end)
    InstallOnBanking(rawget(_G, "GAMEPAD_BANKING"))
    Debug("loaded v%s", VC.version)
end

EVENT_MANAGER:RegisterForEvent(VC.name .. "_Loaded", EVENT_ADD_ON_LOADED, function(_event, addonName)
    if addonName == VC.name then
        EVENT_MANAGER:UnregisterForEvent(VC.name .. "_Loaded", EVENT_ADD_ON_LOADED)
        Initialize()
    end
end)
