--[[
-------------------------------------------------------------------------------
-- WritWorthy
-------------------------------------------------------------------------------
-- Original author: ziggr (project started 2017-02-12)
--
-- Current maintainer: Sharlikran (contributions since 2022-11-12)
-- Contributor: jogietze (formerly otac0n) — GitHub PR contributions
--
-- ----------------------------------------------------------------------------
-- Unless otherwise stated, portions of this software are © ziggr and may
-- be subject to “All Rights Reserved” status due to the absence of a public
-- open-source license declaration.
--
-- ----------------------------------------------------------------------------
-- Contributions by Sharlikran are licensed under the BSD 3-Clause License:
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice,
--    this list of conditions and the following disclaimer.
--
-- 2. Redistributions in binary form must reproduce the above copyright notice,
--    this list of conditions and the following disclaimer in the documentation
--    and/or other materials provided with the distribution.
--
-- 3. Neither the name of the author "Sharlikran" nor the names of previous
--    contributors may be used to endorse or promote products derived from this
--    software without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES ARE DISCLAIMED. IN NO EVENT SHALL THE
-- COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING IN
-- ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
-- OF SUCH DAMAGE.
--
-- Maintainer Notice:
-- Redistribution of this software outside of ESOUI.com (including Bethesda.net
-- or other platforms) is discouraged unless authorized by the current
-- maintainer. Please do not redistribute or fork without attribution,
-- permission, and license compliance.
-------------------------------------------------------------------------------
]]
-- Parse an alchemy request

local WritWorthy = _G["WritWorthy"] -- defined in WritWorthy_Define.lua

WritWorthy.Alchemy = {
  Effects = {}, -- "Speed" --> SPEED
  Reagents = {} -- "Luminous Russula" --> LUMINOUS_RUSSULA
}

local Alchemy = WritWorthy.Alchemy
local Util = WritWorthy.Util
local Fail = WritWorthy.Util.Fail
local Log = WritWorthy.Log

WritWorthy.Alchemy.Effect = {}
WritWorthy.Alchemy.Reagent = {}
local Effect = WritWorthy.Alchemy.Effect
local Reagent = WritWorthy.Alchemy.Reagent

-- I'm not a fan of constructors that do more than construct a single instance.
--
-- But it is handy here to let this constructor also interconnect two negating
-- effects, as well as register this effect in Alchemy.Effect{}

function Effect:New(effect_id, name, negates)
  local o = {
    effect_id = effect_id, -- 23
    name = name, -- "Speed"
    negates = nil, -- HINDER
    reagents = {} -- { "Blessed Thistle" --> BLESSED_THISTLE
    -- , "Namira's Rot"    --> NAMIRAS_ROT
    -- , "Scrib Jelly"     --> SCRIB_JELLY
    -- , }
  }

  -- Register this effect in our list of effects.
  Alchemy.Effects[name] = o
  Alchemy.Effects[effect_id] = o

  -- Interconnect two negating effects
  if negates then
    o.negates = negates
    negates.negates = o
  end

  setmetatable(o, self)
  self.__index = self
  return o
end

function Reagent:New(name, effects)
  local o = {
    name = name, -- "Luminous Russula"
    effects = {} -- { "Ravage Stamina" --> RAVAGE_STAMINA
    -- , "Restore Health" --> RESTORE_HEALTH
    -- , "Maim"           --> MAIM
    -- , "Hindrance"      --> HINDRANCE
    -- }
  }

  -- Register
  Alchemy.Reagents[name] = o

  -- Interconnect Effect <-> Reagents
  for _, effect in pairs(effects) do
    o.effects[effect.name] = effect
    effect.reagents[o.name] = o
  end

  setmetatable(o, self)
  self.__index = self
  return o
end

-- Connect each Effect's pointer to us as a Reagent
function Reagent:Connect()
  for _, effect in ipairs(self.effects) do
    table.insert(effect.reagents, self)
  end
end

-- Return the number of requested effects that this reagent includes.
function Reagent:EffectCount(effect1, effect2, effect3)
  local ct = 0
  if self.effects[effect1.name] then
    ct = ct + 1
  end
  if self.effects[effect2.name] then
    ct = ct + 1
  end
  if self.effects[effect3.name] then
    ct = ct + 1
  end
  return ct
end

-- Return the number of supplied reagents that include this effect.
function Effect:ReagentCount(reagent1, reagent2, reagent3)
  local ct = 0
  if self.reagents[reagent1.name] then
    ct = ct + 1
  end
  if self.reagents[reagent2.name] then
    ct = ct + 1
  end
  if self.reagents[reagent3.name] then
    ct = ct + 1
  end
  return ct
end

-- Is this effect possible with these reagents?
-- Requires 2+ effect and no negation
function Effect:Possible(reagent1, reagent2, reagent3)
  local ct = 0
  if self.reagents[reagent1.name] then
    ct = ct + 1
  end
  if self.reagents[reagent2.name] then
    ct = ct + 1
  end
  if self.reagents[reagent3.name] then
    ct = ct + 1
  end
  if ct < 2 then
    return false
  end

  local negate_name = self.negates.name
  if reagent1.effects[negate_name] or reagent2.effects[negate_name] or reagent3.effects[negate_name] then
    return false
  end

  return ct
end

local A = Alchemy -- For shorter tables

-- Effects and Reagents are interconnected.
-- First forward-declare the effects with actual symbol names so that we can
-- directly connect to them as we build this table.
--
-- instance                            name              negates (only need 1 of the 2)
A.BREACH = Effect:New(8, "Breach")
A.COWARDICE = Effect:New(12, "Cowardice")
A.DEFILE = Effect:New(30, "Defile")
A.DETECTION = Effect:New(21, "Detection")
A.ENERVATION = Effect:New(36, "Enervation")
A.ENTRAPMENT = Effect:New(20, "Entrapment")
A.FRACTURE = Effect:New(10, "Fracture")
A.GRADUAL_RAVAGE_HEALTH = Effect:New(28, "Gradual Ravage Health")
A.HEAL_ABSORPTION = Effect:New(34, "Heal Absorption")
A.HINDRANCE = Effect:New(24, "Hindrance")
A.RAVAGE_HEALTH = Effect:New(2, "Ravage Health")
A.RAVAGE_MAGICKA = Effect:New(4, "Ravage Magicka")
A.RAVAGE_STAMINA = Effect:New(6, "Ravage Stamina")
A.TIMIDITY = Effect:New(32, "Timidity")
A.UNCERTAINTY = Effect:New(16, "Uncertainty")
A.VEXATION = Effect:New(38, "Vexation")
A.VULNERABILITY = Effect:New(26, "Vulnerability")
A.CRITICAL = Effect:New(15, "Critical", A.UNCERTAINTY)
A.DAMAGE_SHIELD = Effect:New(33, "Damage Shield", A.HEAL_ABSORPTION)
A.FORCE = Effect:New(35, "Force", A.ENERVATION)
A.HEROISM = Effect:New(31, "Heroism", A.TIMIDITY)
A.INCREASE_ARMOR = Effect:New(9, "Increase Armor", A.FRACTURE)
A.INCREASE_POWER = Effect:New(11, "Increase Power", A.COWARDICE)
A.INCREASE_SPELL_RESIST = Effect:New(7, "Increase Spell Resist", A.BREACH)
A.INVISIBLE = Effect:New(22, "Invisible", A.DETECTION)
A.LINGERING_HEALTH = Effect:New(27, "Lingering Health", A.GRADUAL_RAVAGE_HEALTH)
A.MENDING = Effect:New(37, "Mending", A.VEXATION)
A.PROTECTION = Effect:New(25, "Protection", A.VULNERABILITY)
A.RESTORE_HEALTH = Effect:New(1, "Restore Health", A.RAVAGE_HEALTH)
A.RESTORE_MAGICKA = Effect:New(3, "Restore Magicka", A.RAVAGE_MAGICKA)
A.RESTORE_STAMINA = Effect:New(5, "Restore Stamina", A.RAVAGE_STAMINA)
A.SPEED = Effect:New(23, "Speed", A.HINDRANCE)
A.UNSTOPPABLE = Effect:New(19, "Unstoppable", A.ENTRAPMENT)
A.VITALITY = Effect:New(29, "Vitality", A.DEFILE)

-- Reagents
A.BEETLE_SCUTTLE = Reagent:New("Beetle Scuttle", { A.BREACH, A.INCREASE_ARMOR, A.PROTECTION, A.VITALITY })
A.BLESSED_THISTLE = Reagent:New("Blessed Thistle", { A.RESTORE_STAMINA, A.INCREASE_POWER, A.HEAL_ABSORPTION, A.SPEED })
A.BLUE_ENTOLOMA = Reagent:New("Blue Entoloma", { A.RAVAGE_MAGICKA, A.HEAL_ABSORPTION, A.RESTORE_HEALTH, A.INVISIBLE })
A.BUGLOSS = Reagent:New("Bugloss", { A.INCREASE_SPELL_RESIST, A.RESTORE_HEALTH, A.MENDING, A.RESTORE_MAGICKA })
A.BUTTERFLY_WING = Reagent:New("Butterfly Wing", { A.RESTORE_HEALTH, A.DAMAGE_SHIELD, A.LINGERING_HEALTH, A.VITALITY })
A.CHAURUS_EGG = Reagent:New("Chaurus Egg", { A.TIMIDITY, A.RAVAGE_MAGICKA, A.VEXATION, A.DETECTION })
A.CLAM_GALL = Reagent:New("Clam Gall", { A.INCREASE_SPELL_RESIST, A.HINDRANCE, A.VULNERABILITY, A.DEFILE })
A.COLUMBINE = Reagent:New("Columbine", { A.RESTORE_HEALTH, A.RESTORE_MAGICKA, A.RESTORE_STAMINA, A.UNSTOPPABLE })
A.CORN_FLOWER = Reagent:New("Corn Flower", { A.RESTORE_MAGICKA, A.INCREASE_POWER, A.RAVAGE_HEALTH, A.DETECTION })
A.CRIMSON_NIRNROOT = Reagent:New("Crimson Nirnroot", { A.TIMIDITY, A.FORCE, A.GRADUAL_RAVAGE_HEALTH, A.RESTORE_HEALTH })
A.CULTIVATED_CRYPTPODS = Reagent:New("Cultivated Cryptpods", { A.HEROISM, A.INCREASE_POWER, A.MENDING, A.DAMAGE_SHIELD })
A.DAEDRA_BLOOD_MAGGOTS = Reagent:New("Daedra-Blood Maggots", { A.DEFILE, A.HEAL_ABSORPTION, A.COWARDICE, A.ENTRAPMENT })
A.DRAGONS_BILE = Reagent:New("Dragon's Bile", { A.HEROISM, A.VULNERABILITY, A.INVISIBLE, A.VITALITY })
A.DRAGONS_BLOOD = Reagent:New("Dragon's Blood", { A.LINGERING_HEALTH, A.RESTORE_STAMINA, A.HEROISM, A.DEFILE })
A.DRAGON_RHEUM = Reagent:New("Dragon Rheum", { A.RESTORE_MAGICKA, A.UNCERTAINTY, A.HEROISM, A.SPEED })
A.DRAGONTHORN = Reagent:New("Dragonthorn", { A.INCREASE_POWER, A.RESTORE_STAMINA, A.FRACTURE, A.CRITICAL })
A.EMETIC_RUSSULA = Reagent:New("Emetic Russula", { A.RAVAGE_HEALTH, A.RAVAGE_MAGICKA, A.RAVAGE_STAMINA, A.ENTRAPMENT })
A.FLESHFLY_LARVA = Reagent:New("Fleshfly Larva", { A.RAVAGE_STAMINA, A.VULNERABILITY, A.GRADUAL_RAVAGE_HEALTH, A.VITALITY })
A.FOSSILIZED_VERMINOUS_BONES = Reagent:New("Fossilized Verminous Bones", { A.HEROISM, A.RESTORE_STAMINA, A.FORCE, A.DETECTION })
A.IMP_STOOL = Reagent:New("Imp Stool", { A.COWARDICE, A.RAVAGE_STAMINA, A.INCREASE_ARMOR, A.ENERVATION })
A.LADYS_SMOCK = Reagent:New("Lady's Smock", { A.FORCE, A.RESTORE_MAGICKA, A.BREACH, A.CRITICAL })
A.LUMINOUS_RUSSULA = Reagent:New("Luminous Russula", { A.RAVAGE_STAMINA, A.RESTORE_HEALTH, A.HINDRANCE, A.COWARDICE })
A.MOUNTAIN_FLOWER = Reagent:New("Mountain flower", { A.INCREASE_ARMOR, A.RESTORE_HEALTH, A.COWARDICE, A.RESTORE_STAMINA })
A.MUDCRAB_CHITIN = Reagent:New("Mudcrab Chitin", { A.INCREASE_SPELL_RESIST, A.INCREASE_ARMOR, A.PROTECTION, A.DEFILE })
A.NAMIRAS_ROT = Reagent:New("Namira's Rot", { A.ENERVATION, A.SPEED, A.INVISIBLE, A.UNSTOPPABLE })
A.NIGHTSHADE = Reagent:New("Nightshade", { A.RAVAGE_HEALTH, A.PROTECTION, A.GRADUAL_RAVAGE_HEALTH, A.DEFILE })
A.NIRNROOT = Reagent:New("Nirnroot", { A.RAVAGE_HEALTH, A.UNCERTAINTY, A.INVISIBLE, A.HEAL_ABSORPTION })
A.POWDERED_MOTHER_OF_PEARL = Reagent:New("Powdered Mother of Pearl", { A.MENDING, A.SPEED, A.VITALITY, A.PROTECTION })
A.SCRIB_JELLY = Reagent:New("Scrib Jelly", { A.VEXATION, A.SPEED, A.VULNERABILITY, A.LINGERING_HEALTH })
A.SPIDER_EGG = Reagent:New("Spider Egg", { A.HINDRANCE, A.INVISIBLE, A.DAMAGE_SHIELD, A.DEFILE })
A.STINKHORN = Reagent:New("Stinkhorn", { A.FRACTURE, A.RAVAGE_HEALTH, A.FORCE, A.RAVAGE_STAMINA })
A.TORCHBUG_THORAX = Reagent:New("Torchbug Thorax", { A.FRACTURE, A.UNCERTAINTY, A.DETECTION, A.MENDING })
A.VILE_COAGULANT = Reagent:New("Vile Coagulant", { A.TIMIDITY, A.RAVAGE_HEALTH, A.RESTORE_MAGICKA, A.PROTECTION })
A.VIOLET_COPRINUS = Reagent:New("Violet Coprinus", { A.BREACH, A.RAVAGE_HEALTH, A.INCREASE_POWER, A.RAVAGE_MAGICKA })
A.WATER_HYACINTH = Reagent:New("Water Hyacinth", { A.RESTORE_HEALTH, A.CRITICAL, A.ENTRAPMENT, A.DAMAGE_SHIELD })
A.WHITE_CAP = Reagent:New("White Cap", { A.ENERVATION, A.RAVAGE_MAGICKA, A.INCREASE_SPELL_RESIST, A.DETECTION })
A.WINTERS_GRAVE_TONGUE = Reagent:New("Winter's Grave Tongue", { A.VEXATION, A.HEAL_ABSORPTION, A.DEFILE, A.BREACH })
A.WORMWOOD = Reagent:New("Wormwood", { A.CRITICAL, A.HINDRANCE, A.DETECTION, A.UNSTOPPABLE })

-- If a permutation of three reagents produces the requested three effects,
-- return true. If not, false.
function Alchemy.Winner(effect1, effect2, effect3, reagent1, reagent2, reagent3)
  -- Reagents appear in both pool1 and pool23, so expect
  -- and skip duplicates. We MUST include pool1's
  -- reagents in pool23 because sometimes the only
  -- winning combination requires two from pool1.
  if reagent1 == reagent2 or reagent2 == reagent3 or reagent3 == reagent1 then
    return false
  end

  -- d("Testing r3: "..reagent1.name .." + ".. reagent2.name .." + ".. reagent3.name
  --  .. " " .. effect1.name ..":" ..tostring(effect1:Possible( reagent1, reagent2, reagent3 ))
  --  .. " " .. effect2.name ..":" ..tostring(effect2:Possible( reagent1, reagent2, reagent3 ))
  --  .. " " .. effect3.name ..":" ..tostring(effect3:Possible( reagent1, reagent2, reagent3 ))
  --  )
  if
  effect1:Possible(reagent1, reagent2, reagent3) and effect2:Possible(reagent1, reagent2, reagent3) and
    effect3:Possible(reagent1, reagent2, reagent3)
  then
    -- d("WINNER: " .. reagent1.name .." + ".. reagent2.name .." + ".. reagent3.name)
    return true
  end
  return false
end

-- Return a list of three reagents, sorted by name
function Alchemy.NameLessThan(a, b)
  if a and b then
    return a.name < b.name
  end
  if b then
    -- nil < non-nil
    return true
  end
  if a then
    -- non-nil > nil
    return false
  end
  return false -- nil == nil
end

-- A "reagent_three" or "r3" is a 3-tuple of Reagent.

function Alchemy.ToReagentThreeList(effect1, effect2, effect3)
  -- First reagent must have effect1.
  local pool1 = {}
  -- d("Effects: 1:"..effect1.name.."   2:"..effect2.name.."   3:"..effect3.name)
  for _, reagent in pairs(effect1.reagents) do
    pool1[reagent.name] = reagent
    -- d("Pool1: " .. reagent.name )
  end

  -- Second and third reagents must have any of the three effects.
  local pool23 = {}
  for _, reagents in pairs(
    {
      effect1.reagents,
      effect2.reagents,
      effect3.reagents
    }
  ) do
    for _, reagent in pairs(reagents) do
      pool23[reagent.name] = reagent
      -- d("Pool23: " .. reagent.name )
    end
  end

  local r3list = {}
  local seen = {}
  for _, reagent1 in pairs(pool1) do
    for i, reagent2 in pairs(pool23) do
      for j, reagent3 in pairs(pool23) do
        if i < j then
          -- avoid duplicate work between 2+3
          -- Avoid different permuations of the same 3 reagents
          -- by canonicalizing their names into a single sorted
          -- sequence and using that as the insertion key
          -- for the resulting r3list.
          local rnames = {
            reagent1.name,
            reagent2.name,
            reagent3.name
          }
          table.sort(rnames)
          local rkey = rnames[1] .. "+" .. rnames[2] .. "+" .. rnames[3]
          if not seen[rkey] then
            seen[rkey] = true
            if Alchemy.Winner(effect1, effect2, effect3, reagent1, reagent2, reagent3) then
              -- Sorting here not required, just makes
              -- display a bit tidier.
              local r3 = { reagent1, reagent2, reagent3 }
              table.sort(r3, Alchemy.NameLessThan)
              Log:Add("r3list:" .. r3[1].name .. "  " .. r3[2].name .. "  " .. r3[3].name)
              table.insert(r3list, r3)
            end
          end
        end
      end
    end
  end
  return r3list
end

-- Parser ====================================================================

Alchemy.Parser = {
  class = "alchemy"
}
local Parser = Alchemy.Parser

function Parser:New()
  local o = {
    is_poison = nil, -- if false, "Potion". If true, "Poison"
    effects = {}, -- { VITALITY, INCREASE_ARMOR, RAVAGE_STAMINA }
    r3list = {}, -- { list of { Reagent 3-tuple }, { Reagent 3-tuple} ... }
    mat_list = {}, -- of MatRow
    crafting_type = CRAFTING_TYPE_ALCHEMY
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function Parser:ParseItemLink(item_link)
  Log:StartNewEvent("ParseItemLink: %s %s", self.class, item_link)
  local fields = Util.ToWritFields(item_link)
  local solvent_id = fields.writ1
  self.is_poison = solvent_id == 239 -- Lorkhan's Tears
  local log_t = {}
  log_t.solvent_id = solvent_id
  log_t.is_poison = self.is_poison
  log_t.effects = {}
  for i, effect_id in ipairs(
    {
      fields.writ2,
      fields.writ3,
      fields.writ4
    }
  ) do
    local effect = Alchemy.Effects[effect_id]
    if not effect then
      return Fail("Unknown potion effect:" .. tostring(effect_id))
    end
    log_t.effects[i] = tostring(effect_id) .. " " .. tostring(effect.name)
    table.insert(self.effects, effect)
  end
  log_t.effects = Log:Flatten("", log_t.effects)
  Log:Add(log_t)
  self.r3list = Alchemy.ToReagentThreeList(self.effects[1], self.effects[2], self.effects[3])
  return self
end

function Parser:GetRequiredCraftCt()
  -- Update 21/4.3.0/100026/Wrathbone 2019-01 reduced
  -- required potion/poison counts.
  --
  -- 20x potions or poisons before 4.3.0
  -- 16x potions or poisons after.
  local api_version = GetAPIVersion()
  local result_ct = 20
  if 100026 <= api_version then
    result_ct = 16
  end

  local result_per_craft = 4
  if self.is_poison then
    result_per_craft = 16
  end
  return math.ceil(result_ct / result_per_craft)
end

function Parser:ToMatList()
  -- d("self.r3list ct:"..tostring(#self.r3list))
  if self.mat_list_fail_reason then
    return nil
  end

  -- Find the cheapest of multiple possible 3-tuples.
  local MatRow = WritWorthy.MatRow
  local min_gold = 9999999999
  local min_r3 = nil
  local mat_ct = self:GetRequiredCraftCt()
  for _, r3 in pairs(self.r3list) do
    r3[1].mat = MatRow:FromName(r3[1].name, mat_ct)
    r3[2].mat = MatRow:FromName(r3[2].name, mat_ct)
    r3[3].mat = MatRow:FromName(r3[3].name, mat_ct)

    -- If we cannot get MM prices, then WHICH three
    -- reagents we pick doesn't really matter. We're done
    -- trying to find the cheapest.
    local mat_list = { r3[1].mat, r3[2].mat, r3[3].mat }
    local mat_total = MatRow.ListTotal(mat_list)
    if not mat_total then
      Log:Add("no total")
      min_gold = WritWorthy.GOLD_UNKNOWN
      min_r3 = r3
      break
    end
    -- If we can get MM prices, keep checking for the
    -- cheapest combination of three reagents.
    if mat_total and min_gold and mat_total < min_gold then
      min_gold = mat_total
      min_r3 = r3
    end
  end
  if not min_r3 then
    local effect_name_1 = self.effects[1] and self.effects[1].name or "?"
    local effect_name_2 = self.effects[2] and self.effects[2].name or "?"
    local effect_name_3 = self.effects[3] and self.effects[3].name or "?"
    self.mat_list_fail_reason = "No reagent combo for:" .. effect_name_1 .. " + " .. effect_name_2 .. " + " .. effect_name_3
    -- return Fail(self.mat_list_fail_reason)
    return nil
  end
  -- Return materials for one batch of potion or poison.
  self.mat_list = {}
  if self.is_poison then
    table.insert(self.mat_list, MatRow:FromName("Alkahest", mat_ct))
  else
    table.insert(self.mat_list, MatRow:FromName("Lorkhan's Tears", mat_ct))
  end
  table.insert(self.mat_list, min_r3[1].mat)
  table.insert(self.mat_list, min_r3[2].mat)
  table.insert(self.mat_list, min_r3[3].mat)

  return self.mat_list
end

function Parser:ToKnowList()
  Log:StartNewEvent("ToKnowList: %s", self.class)
  local three_reagents = WritWorthy.RequiredSkill.AL_LABORATORY_USE:ToKnow()
  local four_pots_per = WritWorthy.RequiredSkill.AL_POTION_4X:ToKnow()
  four_pots_per.is_warn = true
  local r = { three_reagents, four_pots_per }
  return r
end

-- From Dolgubon's LLC functions.lua
local function GetItemIDFromLink(itemLink)
  return tonumber(string.match(itemLink, "|H%d:item:(%d+)"))
end

function Parser:ToDolRequest(unique_id)
  local mat_list = self:ToMatList()
  if not (mat_list and mat_list[1] and mat_list[2] and mat_list[3] and mat_list[4]) then
    return nil
  end
  local o = {}
  o[1] = GetItemIDFromLink(mat_list[1].link) -- solvent
  o[2] = GetItemIDFromLink(mat_list[2].link) -- reagent1
  o[3] = GetItemIDFromLink(mat_list[3].link) -- reagent2
  o[4] = GetItemIDFromLink(mat_list[4].link) -- reagent3 (optional, nilable)
  o[5] = mat_list[1].ct -- timesToMake
  o[6] = true -- autocraft
  o[7] = unique_id -- reference
  return {
    ["function"] = "CraftAlchemyItemId",
    ["args"] = o
  }
end
