-- Console-safe Tel Var banking. No HUD and no deprecated PC compatibility aliases.
local BANK_EVENT = "_TelVarBank"

local function TargetAmount(settings)
    local value = tonumber(settings.telvarTarget) or 0
    return math.min(10000, math.max(0, math.floor(value / 1000 + 0.5) * 1000))
end

function ICT.BankTelVar()
    local settings = ICT.savedVariables
    if not settings or not settings.autoBankTelVar then return end
    if type(GetCurrencyAmount) ~= "function" or type(TransferCurrency) ~= "function" then return end
    if not CURT_TELVAR_STONES or not CURRENCY_LOCATION_CHARACTER or not CURRENCY_LOCATION_BANK then return end

    local currency = CURT_TELVAR_STONES
    local carried = GetCurrencyAmount(currency, CURRENCY_LOCATION_CHARACTER)
    local banked = GetCurrencyAmount(currency, CURRENCY_LOCATION_BANK)
    if type(carried) ~= "number" or type(banked) ~= "number" then return end

    local target = TargetAmount(settings)
    if carried > target then
        TransferCurrency(currency, carried - target, CURRENCY_LOCATION_CHARACTER, CURRENCY_LOCATION_BANK)
    elseif carried < target and banked > 0 then
        TransferCurrency(currency, math.min(target - carried, banked), CURRENCY_LOCATION_BANK, CURRENCY_LOCATION_CHARACTER)
    end
end

function ICT.RegisterTelVarBanking()
    -- Only one transfer per bank opening. Registered only after PSN whitelist check.
    EVENT_MANAGER:RegisterForEvent(ICT.name .. BANK_EVENT, EVENT_OPEN_BANK, function()
        -- Wait until gamepad banking interaction is active before transferring.
        zo_callLater(function()
            if ICT.IsAuthorizedPSN() then ICT.BankTelVar() end
        end, 200)
    end)
end
