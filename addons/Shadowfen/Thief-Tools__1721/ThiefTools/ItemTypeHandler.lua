local SF = LibSFUtils
local color = SF.hex

local TTmsg = SF.addonChatter:New("ThiefTools")
TTmsg:disableDebug()

local logDebug = ThiefTools.logDebug

--[[
ItemTypeHandler
---------------
A registry and dispatcher for handlers associated with an item type or
equipment type. Each handler instance maintains a primary handler, an
optional secondary handler, and alternate handlers keyed by specialized
item type.

Handler selection precedence:
    1. Alternate handler matching the requested specialized item type.
    2. Primary handler.
    3. The default no-op handler.

The secondary handler is stored for use by callers but is not currently
included in the handler selection or dispatch logic.

Handler functions are registered in a shared name registry to support
diagnostic output.

Usage:
    local handler = ItemTypeHandler:New(ITEMTYPE_WEAPON)
    handler:setPrimary(handleWeapon, "Weapon handler")
    handler:setAlternate(SPECIALIZED_ITEMTYPE_XXX,
                         handleSpecialWeapon,
                         "Special weapon handler")

    -- Dispatch for an item type:
    handler:effectivePrimary(hotItem)

    -- Dispatch for an equipment type:
    handler:effectiveEquip(hotItem)

Expected hotItem fields:
    itemType             Item type identifier.
    specializedItemType  Specialized item type identifier.
    equipType            Equipment type identifier.

Dispatch methods invoke the selected handler with hotItem as its
argument and return the handler's return value. A type mismatch returns
nil without invoking a handler.
--]]
ThiefTools_ItemTypeHandler = {}
local ItemTypeHandler = ThiefTools_ItemTypeHandler
ItemTypeHandler.__index = ItemTypeHandler

-- No-op handler used when no specific handler is registered.
-- @return nil
local emptyfunction = function(...) return end

-- Default handler used when neither an alternate nor primary handler
-- is available.
ItemTypeHandler.defaultHandler = emptyfunction

-- Shared registry mapping handler functions to diagnostic names.
-- Functions not registered here are reported as "unknown".
ItemTypeHandler.namelist = {
	[emptyfunction] = "No handler",
}

-- Creates a handler registry for an item type or equipment type.
--
-- @param itemtype number The ITEMTYPE_* or EQUIP_TYPE_* identifier
--                       used to match hotItem during dispatch.
-- @return table A new ItemTypeHandler instance with no registered
--               primary, secondary, or alternate handlers.
function ItemTypeHandler:New(itemtype)
	local ith = {}
	setmetatable(ith, self)

	ith.itemType = itemtype
	ith.primary = nil
	ith.secondary = nil
	ith.alternate = {}

	return ith
end

-- Dispatches a handler for an item whose itemType matches this instance.
--
-- Selects an alternate handler matching hotItem.specializedItemType,
-- falling back to the primary handler and then the default handler.
--
-- @param hotItem table Item data containing itemType and
--                     specializedItemType.
-- @return any The selected handler's return value, or nil if the
--             item's type does not match this instance.
function ItemTypeHandler:effectivePrimary(hotItem)
	local itemType = hotItem.itemType
    if itemType ~= self.itemType then return end

	local specItem = hotItem.specializedItemType
	local handlerfunc = self:getEffectivePrimary(specItem)
	if not handlerfunc then return emptyfunction() end
	return handlerfunc(hotItem)
end

-- Dispatches a handler for an item whose equipType matches this instance.
--
-- Selects the primary handler, falling back to the default handler.
-- Alternate handlers are not selected by this method.
--
-- @param hotItem table Item data containing equipType.
-- @return any The selected handler's return value, or nil if the
--             equipment type does not match this instance.
function ItemTypeHandler:effectiveEquip(hotItem)
	local equipType = hotItem.equipType
    if equipType ~= self.itemType then
		return
	end

	local handlerfunc = self:getEffectivePrimary()
	if not handlerfunc then return emptyfunction() end
	return handlerfunc(hotItem)
end

-- Resolves the handler for a specialized item type.
--
-- An alternate handler takes precedence when altType is registered.
-- Otherwise, returns the primary handler if one exists, or the
-- default handler.
--
-- @param altType any Optional specialized item type identifier.
-- @return function The selected handler function.
function ItemTypeHandler:getEffectivePrimary(altType)
	if altType ~= nil then
      if self.alternate[altType] then
          -- we have a handler for this specializedItemType
          return self.alternate[altType]
      end
	end

	if self.primary ~= nil then
      -- return the primary handler since we're not specialized for altType
      return self.primary
	end

    -- didn't even have a primary handler so go with the default
  	return self.defaultHandler
end

-- Registers the primary handler for this instance.
--
-- The primary handler is used when no matching alternate handler exists.
--
-- @param handler function Handler function called with hotItem.
-- @param handlername string|nil Optional diagnostic name shared across
--                               all ItemTypeHandler instances.
function ItemTypeHandler:setPrimary(handler, handlername)
	self.primary=handler
	if handlername ~= nil then
		ItemTypeHandler.namelist[handler] = handlername
	end
end

-- Registers a secondary handler for this instance.
--
-- The secondary handler is stored but is not used by the current
-- handler-selection or dispatch methods.
--
-- @param handler function Secondary handler function.
-- @param handlername string|nil Optional diagnostic name shared across
--                               all ItemTypeHandler instances.
function ItemTypeHandler:setSecondary(handler, handlername)
	self.secondary=handler
	if handlername ~= nil then
		ItemTypeHandler.namelist[handler] = handlername
	end
end

-- Registers an alternate handler for one or more specialized item types.
--
-- When altitemType is a table, each value in the table is used as a
-- specialized item type key. Otherwise, altitemType itself is used.
-- Alternate handlers take precedence over the primary handler during
-- effectivePrimary dispatch.
--
-- @param altitemType any A specialized item type identifier, or a table
--                       of specialized item type identifiers.
-- @param handler function Handler function called with hotItem.
-- @param handlername string|nil Optional diagnostic name shared across
--                               all ItemTypeHandler instances.
function ItemTypeHandler:setAlternate(altitemType, handler, handlername)
	if type(altitemType) == "table" then
		for k,v in pairs(altitemType) do
			self.alternate[v] = handler
		end

	else
      self.alternate[altitemType]=handler
	end
	if handlername ~= nil then
	  ItemTypeHandler.namelist[handler] = handlername
	end
end

-- Checks whether an alternate handler is registered for an item type.
--
-- @param itemType any Specialized item type identifier.
-- @return boolean True if an alternate handler exists; otherwise false.
function ItemTypeHandler:hasAlternate(itemType)
    return self.alternate[itemType] ~= nil
end

-- Logs all alternate handlers registered on this instance.
--
-- Each entry includes the parent item type, specialized item type,
-- and registered handler name.
-- Requires logDebug to be available.
function ItemTypeHandler:displayAlternateList()
	logDebug("alternates defined:")
	for k,h in pairs(self.alternate) do
		logDebug("alternate: IT=", self.itemType,"  SIT=", k, self:getHandlerName(h))
	end
end

-- Resolves a handler's diagnostic name.
--
-- If spec is a function, looks up that function directly. Otherwise,
-- treats spec as a specialized item type and resolves its effective
-- handler before looking up the name.
--
-- @param spec function|any A handler function or specialized item type.
-- @return string Registered handler name, "name lookup returned nil"
--                if resolution returns nil, or "unknown" if no name
--                is registered.
function ItemTypeHandler:getHandlerName(spec)
    local h = nil
    if type(spec) == "function"  then
        h = spec
    else
        h = self:getEffectivePrimary(spec)
    end
    if h == nil  then
        return "name lookup returned nil"
    end
    if ItemTypeHandler.namelist[h]  then
        return ItemTypeHandler.namelist[h]
    else
        logDebug("don't have name for handler")
    end
    return "unknown"
end

-- Logs all named handler functions in the shared registry.
--
-- Requires logDebug to be available. Because the registry is shared,
-- this may include handlers registered by other instances.
function ItemTypeHandler:displayHandlerList()
    for k,v in pairs(ItemTypeHandler.namelist) do
        if type(k) == "function"  then
            logDebug("[", self:getHandlerName(k), "] = ", v)
        else
            logDebug("[", k, "] = ", v)
        end
    end
end