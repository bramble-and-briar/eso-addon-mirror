-- SatchelExchangeChatterUtils.lua: Pure helpers for reading NPC dialogue options.

local SatchelExchangeChatterUtils = {}

---Find the dialogue option that opens the vendor's store, e.g.
---"Store (Daedric Shackle Vendor)". Store options carry CHATTER_START_SHOP.
---@return integer|nil optionIndex
function SatchelExchangeChatterUtils.FindShopOptionIndex()
    for optionIndex = 1, GetChatterOptionCount() do
        local _, optionType = GetChatterOption(optionIndex)
        if optionType == CHATTER_START_SHOP then
            return optionIndex
        end
    end
    return nil
end

SatchelExchange.ChatterUtils = SatchelExchangeChatterUtils
