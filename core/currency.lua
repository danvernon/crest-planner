local addonName, CrestPlanner = ...

local Currency = {}
CrestPlanner.Currency = Currency

local Constants = CrestPlanner.Constants

function Currency:GetCurrentCrestBalances()
    local balances = {}

    for crestName, currencyID in pairs(Constants.CREST_CURRENCY_IDS) do
        local info
        if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
            info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
        end
        balances[crestName] = {
            amount = info and info.quantity or 0,
            weeklyMax = info and info.maxWeeklyQuantity or 0,
            totalMax = info and info.maxQuantity or 0,
        }
    end

    return balances
end
