require "zos"
require "en"
require "tk"

local TK = TestKit

--[[
ZOS functions
]]


--[[
end ZOS functions
]]

--[[
test utility functions
]]
local function bool2str(bool)
  if bool then
    return "true"
  end
  return "false"
end

local function printIndex(ndx)
    for k,v in pairs(ndx) do
        d(k," = ",v)
    end
end
--[[
functions under test
]]

require "ThiefTools.ItemTypeHandler"
require "ThiefTools.libs.LibSFUtils.LibSFUtils"
local ItemTypeHandler = ThiefTools_ItemTypeHandler
local SF = LibSFUtils

TK.init()

-- New table
local ith = ItemTypeHandler:New(1)
--ith:displayHandlerList()
--d("- -")

-- Get handler that is not there
TK.assertTrue(ith:getHandlerName(5) == "No handler","TestGetHandlerName - no handler")
--d("- -")


-- Setup new defaults
default = function(...) d("doing default") end
ItemTypeHandler.defaultHandler = default
ItemTypeHandler.namelist[default]="named doing default"
TK.assertTrue(ith:getHandlerName(5) == "named doing default","TestGetHandlerName - set default name")
--d(ith:getHandlerName(5))

-- Set primary for ith
p = function(...) d("primary function") end
ith:setPrimary(p,"primary func")
TK.assertTrue(ith.primary == p, "TestSetPrimary")
TK.assertTrue(ith:getEffectivePrimary() == p, "TestGetEffectivePrimary(nil) - primary")

-- Add an alternate for ith
a5 = function(...) d("alternate 5") end
ith:setAlternate(5, a5, "alternate 5")
TK.assertTrue(ith:getEffectivePrimary(1) == p, "TestGetEffectivePrimary(1) - primary")
TK.assertTrue(ith:getEffectivePrimary(5) == a5, "TestGetEffectivePrimary(5) - alternate 5")

-- New instance
local ith2 = ItemTypeHandler:New(2)
TK.assertTrue(ith2:getHandlerName(5) == "named doing default","Test2GetHandlerName - default name")
TK.assertTrue(ith2.primary == nil, "Test2Primary is unset")
TK.assertTrue(ith2:getEffectivePrimary(5) == default,"Test2 Effective primary is default")

-- New instance alternates
a2 = function(...) d("alternate 2") end
ith2:setAlternate(2, a2, "alternate 2")
TK.assertTrue(ith2:getEffectivePrimary(1) == default, "Test2GetEffectivePrimary(1) - default")
TK.assertTrue(ith2:getEffectivePrimary(5) == default, "Test2GetEffectivePrimary(5) - default")
TK.assertTrue(ith2:getEffectivePrimary(2) == a2, "Test2GetEffectivePrimary(2) - alternate 2")

-- retest ith to ensure that it still passes
TK.assertTrue(ith:getEffectivePrimary(1) == p, "TestGetEffectivePrimary(1) - primary")
TK.assertTrue(ith:getEffectivePrimary(2) == p, "TestGetEffectivePrimary(2) - primary")
TK.assertTrue(ith:getEffectivePrimary(5) == a5, "TestGetEffectivePrimary(5) - alternate 5")

-- Set array of subtypes
local ith3 = ItemTypeHandler:New(3)
TK.assertTrue(ith3:getHandlerName(5) == "named doing default","Test3GetHandlerName - default name")
TK.assertTrue(ith3.primary == nil, "Test2Primary is unset")
TK.assertTrue(ith3:getEffectivePrimary(5) == default,"Test3 Effective primary is default")
a7 = function(...) d("alternate 7") end
ith3:setAlternate({2,3,5}, a7, "alternate 7")
ith3:setAlternate(4,a2)
ith3:displayAlternateList()
ith2:displayAlternateList()
ith:displayAlternateList()

TK.showResult()