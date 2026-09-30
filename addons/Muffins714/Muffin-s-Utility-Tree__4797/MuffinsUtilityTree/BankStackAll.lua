-- Create a local shortcut for global
local MUT = MuffinsUtilityTree

---------------------------------------------------------------------------------------------
-- Bank Stack All
---------------------------------------------------------------------------------------------
local stackAllKeybindEntry = {
    name = GetString(MUT_BANK_STACK_ALL),
    keybind = "UI_SHORTCUT_QUATERNARY",
    visible = function()
        if not GAMEPAD_BANKING then return false end
        -- Block Furniture Vault
        if IsFurnitureVault(GetBankingBag()) then
            return
        end
        if GAMEPAD_BANKING:IsInDepositMode() then return false end
        return GAMEPAD_BANKING:IsInWithdrawMode()
    end,
    callback = function()
        StackBag(GetBankingBag())
    end,
}

local isKeybindInjected = false

local function AddBankStackKeybind()
    if isKeybindInjected then return end
    if not GAMEPAD_BANKING or not GAMEPAD_BANKING.mainKeybindStripDescriptor then return end

    table.insert(GAMEPAD_BANKING.mainKeybindStripDescriptor, stackAllKeybindEntry)
    isKeybindInjected = true
end

local function RemoveKeybind()
    if not isKeybindInjected then return end
    if GAMEPAD_BANKING and GAMEPAD_BANKING.mainKeybindStripDescriptor then
        for i, entry in ipairs(GAMEPAD_BANKING.mainKeybindStripDescriptor) do
            if entry == stackAllKeybindEntry then
                table.remove(GAMEPAD_BANKING.mainKeybindStripDescriptor, i)
                break
            end
        end
        if KEYBIND_STRIP:HasKeybindButtonGroup(GAMEPAD_BANKING.mainKeybindStripDescriptor) then
            KEYBIND_STRIP:UpdateKeybindButtonGroup(GAMEPAD_BANKING.mainKeybindStripDescriptor)
        end
    end
    isKeybindInjected = false
end

---------------------------------------------------------------------------------------------
-- Enable / disable
---------------------------------------------------------------------------------------------
function MUT.SetBankStackAllEnabled(isEnabled)
    if isEnabled then
        AddBankStackKeybind()
    else
        RemoveKeybind()
    end
end

---------------------------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------------------------
-- Retry until GAMEPAD_BANKING exists because it's created on first bank interaction not on load
local function EnsureInjected(attempt)
    if isKeybindInjected then return end
    if not MUT.GetSettings().bankStackAllEnabled then return end
    attempt = attempt or 1

    if not GAMEPAD_BANKING or not GAMEPAD_BANKING.mainKeybindStripDescriptor then
        if attempt < 10 then
            zo_callLater(function() EnsureInjected(attempt + 1) end, 200)
        end
        return
    end

    AddBankStackKeybind()
end

function MUT.Initialize_BankStackAll()
    local settings = MUT.GetSettings()
    if settings.bankStackAllEnabled then
        EnsureInjected()
    end
end
