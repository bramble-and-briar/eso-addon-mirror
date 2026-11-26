MWC.Price = {}

function MWC.Price.Available()
  return TamrielTradeCentrePrice ~= nil
end

-- TTC's suggested price (X in its tooltip's "Suggested X ~ Y"), as WritWorthy takes it through LibPrice.
-- Without it: the listing average. Nil when TTC has no data for the item.
-- TTC's data doesn't change while playing: each item is looked up once per session (false = no data).
local cache = {}

function MWC.Price.Of(link)
  if not MWC.Price.Available() then return nil end
  local price = cache[link]
  if price == nil then
    local info = TamrielTradeCentrePrice:GetPriceInfo(link)
    price = info and (info.SuggestedPrice or info.Avg) or false
    cache[link] = price
  end
  return price or nil
end
