BuffTracker = BuffTracker or {}
BuffTracker.Utils = BuffTracker.Utils or {}
local Utils = BuffTracker.Utils

--- func description: Returns an iterator function that iterates over the elements of an array.
--- @param array table The array to iterate over.
--- @return function An iterator function that returns the next element in the array.
--- The iterator function returns nil when there are no more elements to iterate over.
--- This is useful for iterating over arrays in a for loop or other iteration constructs.
function Utils.GetValues(array)
  local i = 0
  return function() i = i + 1; return array[i] end
end

function Utils.CountObject(t)
  local count = 0
  for _ in pairs(t) do count = count + 1 end
  return count
end

function Utils.PrintObject(obj)
  if obj == nil then return "nil" end
  if type(obj) == "table" then
    local result = "{ "
    for k, v in pairs(obj) do
      if v and type(v) == "table" then
        local w = Utils.PrintObject(v) -- Recursive call to handle nested tables
        result = result .. tostring(k) .. ": " .. tostring(w) .. ", "   -- Recursively print nested tables
      else 
        result = result .. tostring(k) .. ": " .. tostring(v) .. ", "
      end
    end
    result = result .. " }"
    return result
  else
    return tostring(obj)
  end
end

--- func description: Returns the number of seconds remaining until the specified end time.
--- @param endTime any The end time to compare against the current time.
--- @return number The number of seconds remaining until the end time, or 0 if the end time has already passed.
function Utils.SecondsRemaining(endTime)
    return math.max(0, endTime - GetFrameTimeSeconds())
end

--- Retrieves a localized string for a given key.
--- @param key The key for the localized string.
--- @return The localized string if found, otherwise returns the key itself.
function Utils.L(key, ...)
    local str = BuffTracker.strings and BuffTracker.strings[key] or key
    if select("#", ...) > 0 then
        return string.format(str, ...)
    end
    return str
end

