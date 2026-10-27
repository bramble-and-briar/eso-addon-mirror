-- Bank currency selector is a parametric list, not an inventory search list.
-- Keep the native search update for inventory and all unknown list types.
local function InstallBankCurrencyUpdate()
    local class = ZO_GamepadBanking
    if not class or class.esoArabicCurrencyUpdate240 then return end
    local original = class.PerformUpdate
    if type(original) ~= "function" then return end
    class.PerformUpdate = function(self, ...)
        if self.dirty then
            local list = self:GetCurrentList()
            if list and list == self.currenciesList
                and type(list.RefreshList) ~= "function"
                and type(self.RefreshCurrenciesList) == "function" then
                self:RefreshCurrenciesList()
                self.dirty = false
                return
            end
        end
        return original(self, ...)
    end
    class.esoArabicCurrencyUpdate240 = true
end
InstallBankCurrencyUpdate()
