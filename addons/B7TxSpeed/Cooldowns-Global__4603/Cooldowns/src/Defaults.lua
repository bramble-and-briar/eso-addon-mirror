-- -----------------------------------------------------------------------------
-- Cooldowns
-- Author:  @g4rr3t[NA], @nogetrandom[EU], @B7TxSpeed[EU]
-- Created: May 5, 2018
--
-- Defaults.lua
-- -----------------------------------------------------------------------------

Cool.Defaults 	= {}

local defaults 	= {
  debugMode 				= 0,
  sets 							= {},
  unlocked 					= true,
  snapToGrid 				= false,
  gridSize 					= 16,
  showOutsideCombat = true,
  lagCompensation 	= true,
  stacksWithinIcon   = false,
  timerX 						= 0,
  timerY 						= 0,
  size 							= 64,
  spaulderActive    = false,
  map               = "",
  lastCharacter     = "",
  global            = {
    ["artifact"]      = {
      frame   = {
        size    = 64,
        timer   = { x = 0, y = 0 },
        stack   = { x = 0, y = 0 }
      },
      noFrame = {
        size    = 64,
        timer   = { x = 0, y = 0 },
        stack   = { x = 0, y = 0 }
      }
    },
    ["monsterSet"]    = {
      frame   = {
        size    = 64,
        timer   = { x = 0, y = 0 },
        stack   = { x = 0, y = 0 }
      },
      noFrame = {
        size    = 64,
        timer   = { x = 0, y = 0 },
        stack   = { x = 0, y = 0 }
      }
    },
    ["stackSet"]      = {
      frame   = {
        size    = 64,
        timer   = { x = 0, y = 0 },
        stack   = { x = 0, y = 0 }
      },
      noFrame = {
        size    = 64,
        timer   = { x = 0, y = 0 },
        stack   = { x = 0, y = 0 }
      }
    },
    ["set"]           = {
      frame   = {
        size    = 64,
        timer   = { x = 0, y = 0 },
        stack   = { x = 0, y = 0 }
      },
      noFrame = {
        size    = 64,
        timer   = { x = 0, y = 0 },
        stack   = { x = 0, y = 0 }
      }
    },
    ["synergy"]       = {
      frame   = { size = 64, x = 0, y = 0 },
      noFrame = { size = 64, x = 0, y = 0 }
    },
    ["passive"]       = {
      frame   = {
        size    = 64,
        timer   = { x = 0, y = 0 },
        stack   = { x = 0, y = 0 }
      },
      noFrame = {
        size    = 64,
        timer   = { x = 0, y = 0 },
        stack   = { x = 0, y = 0 }
      }
    },
    ["champion"]       = {
      frame   = {
        size    = 64,
        timer   = { x = 0, y = 0 },
        stack   = { x = 0, y = 0 }
      },
      noFrame = {
        size    = 64,
        timer   = { x = 0, y = 0 },
        stack   = { x = 0, y = 0 }
      }
    },
    ["resource"]      = {
      frame   = {
        size    = 64,
        timer   = { x = 0, y = 0 },
        stack   = { x = 0, y = 0 }
      },
      noFrame = {
        size    = 64,
        timer   = { x = 0, y = 0 },
        stack   = { x = 0, y = 0 }
      }
    }
  },
  colorUp 					= {0, 1  , 0},
  colorDown 				= {1, 0  , 0},
  stackColor        = {1, 0.8, 0},
  sounds 						= {
    onProc 						= { enabled = false, sound = 'STATS_PURCHASE'   },
    onReady 					= { enabled = false, sound = 'SKILL_LINE_ADDED' }
  }
}

local artifacts   = {}
local synergies   = {}
local passives 	  = {}
local sets 			  = {}
local monsterSets = {}
local stackSets   = {}
local champion    = {}

local resourceOptionsDefault = {
  showPercent    = true,
  showProcs      = true,
  colorFrame     = true,
  mag            = {
    barColorUp     = { 0.2,  0.6,    1,    1 },
    barColorDown   = { 0.4,  0  ,    0,  0.7 },
    frameColorUp   = { 0.2,  0.6,    1 },
    frameColorDown = { 0.4,  0  ,    0 },
    dividerColor   = { 0  ,  0  ,    0 }
  },
  stam = {
    barColorUp     = { 0.2,    1,  0.6,    1 },
    barColorDown   = { 0.4,    0,    0,  0.7 },
    frameColorUp   = { 0.2,    1,  0.6 },
    frameColorDown = { 0.4,    0,    0 },
    dividerColor   = {   0,    0,    0 }
  }
}

function Cool.Defaults:Generate()
  for key, set in pairs(Cool.Data.Sets) do

    local s, tx, ty, sx, sy
    if set.showFrame then
      if set.procType ~= "synergy" then
        s   = defaults.global[set.procType].frame.size
        tx  = defaults.global[set.procType].frame.timer.x
        ty  = defaults.global[set.procType].frame.timer.y
        sx  = defaults.global[set.procType].frame.stack.x
        sy  = defaults.global[set.procType].frame.stack.y
      else
        s   = defaults.global[set.procType].frame.size
        tx  = defaults.global[set.procType].frame.x
        ty  = defaults.global[set.procType].frame.y
      end
    else
      if set.procType ~= "synergy" then
        s   = defaults.global[set.procType].noFrame.size
        tx  = defaults.global[set.procType].noFrame.timer.x
        ty  = defaults.global[set.procType].noFrame.timer.y
        sx  = defaults.global[set.procType].noFrame.stack.x
        sy  = defaults.global[set.procType].noFrame.stack.y
      else
        s   = defaults.global[set.procType].noFrame.size
        tx  = defaults.global[set.procType].noFrame.x
        ty  = defaults.global[set.procType].noFrame.y
      end
    end

    -- Populate Sets
    defaults.sets[key] = {
      x           = 150,
      y           = 150,
      size 			  = s,
      timer       = { x = tx, y = ty },
      -- stack       = { color  = defaults.stackColor, x = sx, y = sy },
      sounds 		  = defaults.sounds,
      global      = { size = false, timer = false },
      colorUp 	  = defaults.colorUp,
      colorDown   = defaults.colorDown,
    }

    if set.stacks ~= nil then
      defaults.sets[key].stack = { color = defaults.stackColor, x = sx, y = sy }
    end

    if set.resource then
      local d = defaults.sets[key]
      for i, x in pairs(resourceOptionsDefault) do
        if i then d[i] = resourceOptionsDefault[i] end
      end
    end

    if      set.procType == "artifact"    then artifacts[key]   = true
    elseif  set.procType == "set"         then sets[key]        = true
    elseif  set.procType == "monsterSet"  then monsterSets[key] = true
    elseif  set.procType == "stackSet"    then stackSets[key]   = true
    elseif  set.procType == "champion"    then champion[key]    = true
    elseif  set.procType == "synergy"     then synergies[key]   = false
    elseif  set.procType == "passive"     then passives[key]    = false
    else    -- Unsupported procType
    end
  end
end

-- Account-wide
function Cool.Defaults.Get()
  return defaults
end

-- Per-character
function Cool.Defaults.GetCharacter()
  return {
    ["artifact"]    = artifacts,
    ["monsterSet"]  = monsterSets,
    ["stackSet"]    = stackSets,
    ["set"]         = sets,
    ["synergy"]     = synergies,
    ["champion"]    = champion,
    ["passive"]     = passives
  }
end

function Cool.Defaults.GetDefaultResourceOption(v)
  if     v ==  1 then return resourceOptionsDefault.showPercent
  elseif v ==  2 then return resourceOptionsDefault.showProcs
  elseif v ==  3 then return resourceOptionsDefault.colorFrame
  elseif v ==  4 then return resourceOptionsDefault.mag.frameColorUp
  elseif v ==  5 then return resourceOptionsDefault.mag.frameColorDown
  elseif v ==  6 then return resourceOptionsDefault.mag.barColorUp
  elseif v ==  7 then return resourceOptionsDefault.mag.barColorDown
  elseif v ==  8 then return resourceOptionsDefault.mag.dividerColor
  elseif v ==  9 then return resourceOptionsDefault.stam.frameColorUp
  elseif v == 10 then return resourceOptionsDefault.stam.frameColorDown
  elseif v == 11 then return resourceOptionsDefault.stam.barColorUp
  elseif v == 12 then return resourceOptionsDefault.stam.barColorDown
  elseif v == 13 then return resourceOptionsDefault.stam.dividerColor
  end
end

function Cool.Defaults.GetDefaultStackVariables(key)

  local set = Cool.Data.Sets[key]

  local sx, sy

  if set.showFrame then
    sx  = defaults.global[set.procType].frame.stack.x
    sy  = defaults.global[set.procType].frame.stack.y
  else
    sx  = defaults.global[set.procType].noFrame.stack.x
    sy  = defaults.global[set.procType].noFrame.stack.y
  end

  local stack = { color = defaults.stackColor, x = sx, y = sy }

  return stack
end
