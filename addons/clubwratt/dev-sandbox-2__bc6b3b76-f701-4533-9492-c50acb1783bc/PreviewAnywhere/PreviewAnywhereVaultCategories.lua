-- PreviewAnywhereVaultCategories.lua: furniture category headers in the gamepad bank lists
-- (merged from the standalone Vault Categories 0.1.0 addon).
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
local PA = PreviewAnywhere

local VaultCategories = {}

-- Category lookup -------------------------------------------------------------------

local categoryNameCache = {} -- furnitureDataId -> header string, or false when none
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
    local useSubcategories = PA.state.savedVars.vaultSubcategories ~= false
    if cacheUsesSubcategories ~= useSubcategories then
        categoryNameCache = {}
        cacheUsesSubcategories = useSubcategories
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
        local subcategory = useSubcategories and CategoryName(subcategoryId) or nil
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
    local sv = PA.state.savedVars
    if sv.vaultCategories == false or slotData.itemType ~= ITEMTYPE_FURNISHING then
        return false
    end
    if sv.vaultEverywhere then
        return true
    end
    local ok, bankBag = pcall(GetBankingBag)
    return ok and bankBag ~= nil and IsFurnitureVault(bankBag)
end

local fallbackLogs = 0
---Header for a slot: furniture category when it applies, else whatever `fallback` says.
---@param slotData table
---@param fallback function
---@return string
local function Categorize(slotData, fallback)
    if ShouldCategorize(slotData) then
        local header = FurnitureHeader(slotData.bagId, slotData.slotIndex)
        if header then
            return header
        end
        if fallbackLogs < 10 then
            fallbackLogs = fallbackLogs + 1
            PA.Debug("vault categories: no furniture category for '%s' (bag %s slot %s)", tostring(slotData.name), tostring(slotData.bagId), tostring(slotData.slotIndex))
        end
    end
    return fallback(slotData)
end

local installedLists = setmetatable({}, { __mode = "k" })
local function InstallOnList(list, label)
    if type(list) ~= "table" or installedLists[list] then
        return
    end
    -- Wrap whatever the list already has (another addon, or the game in a later patch).
    local original = list.categorizationFunction or ZO_InventoryUtils_Gamepad_GetBestItemCategoryDescription
    list.categorizationFunction = function(slotData)
        return Categorize(slotData, original)
    end
    installedLists[list] = true
    PA.Log("vault categories installed on %s list", label)
end

local function InstallOnBanking(banking)
    if not banking then
        return
    end
    InstallOnList(banking.withdrawList, "withdraw")
    InstallOnList(banking.depositList, "deposit")
end

---Rebuild the open bank lists so a settings change shows at once.
function VaultCategories.Refresh()
    local banking = rawget(_G, "GAMEPAD_BANKING")
    if not banking then
        return
    end
    for _, list in ipairs({ banking.withdrawList, banking.depositList }) do
        if list and list.RefreshList then
            PA.SafeCall("VaultCategories.Refresh", list.RefreshList, list)
        end
    end
end

---One line for /pva status and /pva vault status.
---@return string
function VaultCategories.StatusLine()
    local sv = PA.state.savedVars
    local banking = rawget(_G, "GAMEPAD_BANKING")
    return PA.Fmt("vault categories=%s subcategories=%s everywhere=%s lists=%s/%s", tostring(sv.vaultCategories ~= false), tostring(sv.vaultSubcategories ~= false),
        tostring(sv.vaultEverywhere == true), tostring(banking and banking.withdrawList and installedLists[banking.withdrawList] == true),
        tostring(banking and banking.depositList and installedLists[banking.depositList] == true))
end

---`/pva vault <on|off|sub|everywhere|status>` (also `/vcat ...`).
---@param args string
function VaultCategories.Command(args)
    local command = string.lower(string.match(args or "", "^%s*(%S*)") or "")
    local sv = PA.state.savedVars
    if command == "on" or command == "off" then
        sv.vaultCategories = command == "on"
        PA.Chat(PA.Fmt("vault category headers %s", sv.vaultCategories and "enabled" or "disabled"))
    elseif command == "sub" then
        sv.vaultSubcategories = sv.vaultSubcategories == false
        PA.Chat(PA.Fmt("vault subcategory headers %s", sv.vaultSubcategories and "ON" or "OFF"))
    elseif command == "everywhere" then
        sv.vaultEverywhere = not sv.vaultEverywhere
        PA.Chat(PA.Fmt("furnishing category headers outside the vault %s", sv.vaultEverywhere and "ON" or "OFF"))
    elseif command == "status" then
        PA.Chat(VaultCategories.StatusLine())
        return
    else
        PA.Chat("/pva vault on | off | sub (Category - Subcategory, or category only) | everywhere (also regular bank / house banks) | status")
        return
    end
    VaultCategories.Refresh()
end

function VaultCategories.Initialize()
    assert(rawget(_G, "ZO_BankingCommon_Gamepad"), "gamepad banking UI not available")
    -- Lists are created on the bank's first open (OnDeferredInitialize); install then. If the
    -- bank was already initialized before we loaded (never on a normal load), install right away.
    PA.SecureHook(ZO_BankingCommon_Gamepad, "OnDeferredInitialize", PA.Guard("VaultCategories.OnDeferredInitialize", InstallOnBanking))
    InstallOnBanking(rawget(_G, "GAMEPAD_BANKING"))
end

PA.VaultCategories = VaultCategories
