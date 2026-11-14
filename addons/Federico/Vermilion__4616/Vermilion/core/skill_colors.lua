Vermilion = Vermilion or {}
Vermilion.SkillColors = {}
local M = Vermilion.SkillColors

local api = Vermilion.zenimax.api
local GetAbilityName                          = api.GetAbilityName
local GetAbilityIcon                          = api.GetAbilityIcon
local GetSpecificSkillAbilityKeysByAbilityId  = api.GetSpecificSkillAbilityKeysByAbilityId
local GetSkillLineId                          = api.GetSkillLineId
local string_find                             = string.find

local GROUP_COLORS = {
  basic       = { r = 0.95, g = 0.95, b = 0.95, a = 0.90 },  -- white, light/heavy attacks
  templar     = { r = 0.95, g = 0.75, b = 0.15, a = 0.95 },  -- amber gold
  arcanist    = { r = 0.50, g = 1.00, b = 0.00, a = 0.95 },  -- vivid green
  warden      = { r = 0.00, g = 0.75, b = 0.50, a = 0.95 },  -- sky cyan
  resto       = { r = 0.72, g = 0.50, b = 0.18, a = 0.95 },  -- warm brown
  destru      = { r = 0.75, g = 0.90, b = 1.00, a = 0.95 },  -- pale ice
  dk          = { r = 0.88, g = 0.28, b = 0.08, a = 0.95 },  -- rust orange
  sorc        = { r = 0.28, g = 0.38, b = 0.95, a = 0.95 },  -- electric blue
  nb          = { r = 0.82, g = 0.10, b = 0.18, a = 0.95 },  -- crimson
  necro       = { r = 0.65, g = 0.18, b = 0.82, a = 0.95 },  -- violet
  scribing    = { r = 0.20, g = 0.80, b = 1.00, a = 0.95 },  -- arcane blue
  undaunted   = { r = 0.42, g = 0.42, b = 0.18, a = 0.95 },  -- olive
  support     = { r = 0.42, g = 0.31, b = 0.68, a = 0.95 },  -- muted purple
  vampire     = { r = 0.55, g = 0.05, b = 0.10, a = 0.95 },  -- carmesi (blood)
  werewolf    = { r = 0.60, g = 0.28, b = 0.18, a = 0.95 },  -- blood-moon russet (World, sibling of vampire)
  psijic      = { r = 0.86, g = 0.80, b = 0.52, a = 0.95 },  -- astral gold (Psijic Order)
  mages_guild = { r = 0.10, g = 0.45, b = 0.65, a = 0.95 },  -- celeste oscuro
  item        = { r = 0.95, g = 0.20, b = 0.80, a = 0.95 },  -- magenta (sets / enchants)
  status      = { r = 0.45, g = 0.62, b = 0.60, a = 0.90 },  -- teal-grey, elemental status-effect damage
  -- Weapon skill lines (damage domain; Verdant only ever saw destru/resto).
  twohanded   = { r = 0.80, g = 0.42, b = 0.28, a = 0.95 },  -- burnt orange
  dualwield   = { r = 0.78, g = 0.55, b = 0.30, a = 0.95 },  -- bronze
  bow         = { r = 0.60, g = 0.80, b = 0.50, a = 0.95 },  -- sage green
  onehand     = { r = 0.70, g = 0.74, b = 0.82, a = 0.95 },  -- steel blue-grey
  -- Guild skill lines.
  fighters_guild = { r = 0.78, g = 0.34, b = 0.30, a = 0.95 },  -- brick red
  soul_magic     = { r = 0.60, g = 0.50, b = 0.72, a = 0.95 },  -- lavender
  other       = { r = 0.55, g = 0.55, b = 0.55, a = 0.80 },  -- unknown (grey)
  shield      = { r = 0.85, g = 0.40, b = 0.75, a = 0.95 },
}

local GROUP_LABELS = {
  basic          = "Light / Heavy Attack",
  templar        = "Templar",
  dk             = "Dragonknight",
  sorc           = "Sorcerer",
  nb             = "Nightblade",
  warden         = "Warden",
  necro          = "Necromancer",
  arcanist       = "Arcanist",
  twohanded      = "Two Handed",
  dualwield      = "Dual Wield",
  bow            = "Bow",
  onehand        = "One Hand & Shield",
  destru         = "Destruction Staff",
  resto          = "Restoration Staff",
  fighters_guild = "Fighters Guild",
  mages_guild    = "Mages Guild",
  undaunted      = "Undaunted",
  soul_magic     = "Soul Magic",
  support        = "Alliance War",
  scribing       = "Scribing",
  psijic         = "Psijic Order",
  vampire        = "Vampire",
  werewolf       = "Werewolf",
  item           = "Item Set / Enchant",
  status         = "Status Effect",
  other          = "Unknown (grey)",
  shield         = "Shields cracked",
}

local GROUP_ORDER = {
  "basic",
  "templar", "dk", "sorc", "nb", "warden", "necro", "arcanist",
  "twohanded", "dualwield", "bow", "onehand", "destru", "resto",
  "fighters_guild", "mages_guild", "undaunted", "soul_magic", "support", "scribing", "psijic",
  "vampire", "werewolf",
  "item", "status",
  "other",
}

local BASIC_ABILITY_IDS = {
  [18350] = true,  -- Light Attack (Lightning staff)
  [18396] = true,  -- Heavy Attack (Lightning staff)
  [19277] = true,  -- Heavy Attack (Lightning staff, channel tick)
  -- Melee IDs below are also covered by the icon pattern; listed for clarity.
  [15435] = true,  -- Light Attack (One Handed)
  [16037] = true,  -- Light Attack (Two Handed)
  [17162] = true,  -- Heavy Attack (Two Handed)
  [15279] = true,
  [15383] = true,
  [15385] = true,
  [16321] = true,
  [16165] = true,
  [16277] = true,
  [16420] = true,
  [17169] = true,
  [17170] = true,
  [18622] = true,
  [16499] = true,
}

local BASIC_NAME_PROBES = { { 15435, 16037 }, { 17162, 15279 } }
local BASIC_NAME_FALLBACK = { "Light Attack", "Heavy Attack" }
local basic_prefixes

local ICON_PATTERNS = {
  { "death_recap_melee_basic",   "basic"          },
  { "death_recap_melee_heavy",   "basic"          },
  { "death_recap_ranged_basic",  "basic"          },
  { "death_recap_ranged_heavy",  "basic"          },
  { "death_recap_melee_axe_",    "basic"          },
  { "death_recap_melee_dagger_", "basic"          },
  { "death_recap_melee_mace_",   "basic"          },
  { "ability_2handed_",          "twohanded"      },
  { "ability_dualwield_",        "dualwield"      },
  { "ability_bow_",              "bow"            },
  { "ability_1handed_",          "onehand"        },
  { "ability_fightersguild_",    "fighters_guild" },
  { "gear_",                     "item"           },
  { "ability_grimoire_",         "scribing"    },
  { "ability_templar_",          "templar"     },
  { "ability_sorcerer_",         "sorc"        },
  { "ability_arcanist_",         "arcanist"    },
  { "ability_warden_",           "warden"      },
  { "ability_dragonknight_",     "dk"          },
  { "ability_necromancer_",      "necro"       },
  { "ability_nightblade_",       "nb"          },
  { "ability_restorationstaff_", "resto"       },
  { "ability_destructionstaff_", "destru"      },
  { "ability_ava_",              "support"     },
  { "ability_undaunted_",        "undaunted"   },
  { "ability_mageguild_",        "mages_guild" },
  { "ability_psijic_",           "psijic"      },
  { "ability_u26_vampire_",      "vampire"     },
  { "ability_vampire_",          "vampire"     },
  { "ability_werewolf_",         "werewolf"    },
}

local SKILL_LINE_TO_GROUP = {
  [22]  = "templar",  [27]  = "templar",  [28]  = "templar",
  [35]  = "dk",       [36]  = "dk",       [37]  = "dk",
  [38]  = "nb",       [39]  = "nb",       [40]  = "nb",
  [41]  = "sorc",     [42]  = "sorc",     [43]  = "sorc",
  [127] = "warden",   [128] = "warden",   [129] = "warden",
  [131] = "necro",    [132] = "necro",    [133] = "necro",
  [218] = "arcanist", [219] = "arcanist", [220] = "arcanist",
  [297] = "dk",       [298] = "dk",       [299] = "dk",
  [300] = "nb",       [301] = "nb",       [302] = "nb",
  [303] = "templar",  [304] = "templar",  [305] = "templar",
  [306] = "sorc",     [307] = "sorc",     [308] = "sorc",
  [309] = "warden",   [310] = "warden",   [311] = "warden",
  [312] = "necro",    [313] = "necro",    [314] = "necro",
  [315] = "arcanist", [316] = "arcanist", [317] = "arcanist",
  [33]  = "destru",   [34]  = "resto",
  [323] = "destru",   [324] = "resto",
  [44]  = "mages_guild",
  [55]  = "undaunted",
  [48]  = "support",  [67]  = "support",
  [325] = "support",  [326] = "support",
  [130] = "psijic",
  [51]  = "vampire",
  [50]  = "werewolf",
}

local ABILITY_OVERRIDES = {
  [186191] = "arcanist",
  [186243] = "arcanist",
  [186265] = "arcanist",
  [186267] = "arcanist",
  [186203] = "arcanist",
  [61506]  = "support",
  [33524]  = "templar",
  [217608] = "scribing",
  [22228]  = "templar",
  [44013]  = "resto",
  [45518]  = "undaunted",
  [176922] = "item",
  [217469] = "scribing",
  [69773]  = "destru",
  [26824]  = "templar",
  [44391]  = "templar",
  [55677]  = "undaunted",
  [63511]  = "undaunted",
  [184634] = "item",
  [46743]  = "item",
  [148797] = "status",
  [148800] = "status",
  [21481]  = "status",
  [18084]  = "status",
  [21487]  = "status",
  [48016]  = "destru",
  [126895] = "soul_magic",
  [45445]  = "dualwield",
  [21970]  = "basic",
}

local ability_cache = {}

local USER_OVERRIDES = {}

local unknown_log = {}

local function classify_by_icon(abilityId)
  local icon = GetAbilityIcon(abilityId)
  if not icon or icon == "" then return nil end
  for _, p in ipairs(ICON_PATTERNS) do
    if string_find(icon, p[1], 1, true) then
      return p[2]
    end
  end
  return nil
end

local function learn_basic_prefixes()
  local out = {}
  for _, pair in ipairs(BASIC_NAME_PROBES) do
    local a = GetAbilityName(pair[1]) or ""
    local b = GetAbilityName(pair[2]) or ""
    local p = a:match("^(.-)%s*%(")
    if p and #p >= 2 and b:sub(1, #p) == p then out[#out + 1] = p end
  end
  for _, p in ipairs(BASIC_NAME_FALLBACK) do out[#out + 1] = p end
  basic_prefixes = out
  return out
end

local function classify_by_name(abilityId)
  local name = GetAbilityName(abilityId)
  if not name or name == "" then return nil end
  local prefixes = basic_prefixes or learn_basic_prefixes()
  for i = 1, #prefixes do
    local p = prefixes[i]
    if name:sub(1, #p) == p then return "basic" end
  end
  return nil
end

function M.relearn_basic_names()
  basic_prefixes = nil
end

local function classify_by_skill_tree_api(abilityId)
  local skillType, lineIndex = GetSpecificSkillAbilityKeysByAbilityId(abilityId)
  if not skillType or skillType <= 0 then return nil end
  local skillLineId = GetSkillLineId(skillType, lineIndex)
  if not skillLineId then return nil end
  return SKILL_LINE_TO_GROUP[skillLineId]
end

local function classify_by_slotted_name(abilityId)
  local name = GetAbilityName(abilityId)
  if not name or name == "" or not api.GetSlotBoundId then return nil end
  local zc = Vermilion.zenimax.constants
  for _, cat in ipairs({ zc.HOTBAR_CATEGORY_PRIMARY, zc.HOTBAR_CATEGORY_BACKUP }) do
    for slot = 3, 8 do
      local id = api.GetSlotBoundId(slot, cat)
      if id and id > 0 and id ~= abilityId and GetAbilityName(id) == name then
        local g = classify_by_skill_tree_api(id)
        if g then return g end
      end
    end
  end
  return nil
end

local function lookup_group(abilityId, quiet)
  if not abilityId or abilityId <= 0 then return "other" end

  local g = ability_cache[abilityId]
  if g then return g end

  g = USER_OVERRIDES[abilityId]
  if g then ability_cache[abilityId] = g return g end

  g = ABILITY_OVERRIDES[abilityId]
  if g then ability_cache[abilityId] = g return g end

  g = classify_by_name(abilityId)
  if g then ability_cache[abilityId] = g return g end

  g = classify_by_icon(abilityId)
  if g then ability_cache[abilityId] = g return g end

  g = classify_by_skill_tree_api(abilityId)
  if g then ability_cache[abilityId] = g return g end

  g = classify_by_slotted_name(abilityId)
  if g then ability_cache[abilityId] = g return g end

  if BASIC_ABILITY_IDS[abilityId] then
    ability_cache[abilityId] = "basic"
    return "basic"
  end

  if quiet then return "other" end
  local name = GetAbilityName(abilityId) or "?"
  local icon = GetAbilityIcon(abilityId) or "?"
  unknown_log[abilityId] = name .. "  | icon=" .. icon
  ability_cache[abilityId] = "other"
  return "other"
end

-- ── public classification surface (consumed by core/metrics) ───────────────
function M.group_of(abilityId)
  return lookup_group(abilityId)
end

function M.group_of_quiet(abilityId)
  return lookup_group(abilityId, true)
end

local FALLBACK = GROUP_COLORS.other

function M.group_color(group)
  return GROUP_COLORS[group] or FALLBACK
end

function M.get_color(abilityId)
  return GROUP_COLORS[lookup_group(abilityId)] or FALLBACK
end

function M.group_names()
  local out = {}
  for k in pairs(GROUP_COLORS) do if k ~= "shield" then out[#out + 1] = k end end
  table.sort(out)
  return out
end

function M.is_group(group)
  return group ~= "shield" and GROUP_COLORS[group] ~= nil
end


function M.group_label(key)
  return GROUP_LABELS[key] or key
end

function M.groups_ordered()
  local out = {}
  for _, key in ipairs(GROUP_ORDER) do
    local c = GROUP_COLORS[key] or FALLBACK
    out[#out + 1] = { key = key, label = GROUP_LABELS[key] or key, r = c.r, g = c.g, b = c.b, a = c.a }
  end
  return out
end

function M.get_unknowns()
  local out = {}
  for id in pairs(unknown_log) do
    out[#out + 1] = { id = id, name = GetAbilityName(id) or ("#" .. id), icon = GetAbilityIcon(id) or "" }
  end
  table.sort(out, function(a, b) return a.id < b.id end)
  return out
end

function M.unknown_count()
  local n = 0
  for _ in pairs(unknown_log) do n = n + 1 end
  return n
end

function M.set_override(abilityId, group)
  if not abilityId or abilityId <= 0 or not GROUP_COLORS[group] then return false end
  USER_OVERRIDES[abilityId] = group
  ability_cache[abilityId]  = group
  unknown_log[abilityId]    = nil
  return true
end

function M.mark_basic(abilityId)
  return M.set_override(abilityId, "basic")
end

function M.load_persisted(sv)
  if not sv then return end
  if type(sv.skill_overrides) == "table" then
    for id, group in pairs(sv.skill_overrides) do
      if type(id) == "number" then M.set_override(id, group) end
    end
  end
  if type(sv.skill_basic_ids) == "table" then
    for _, id in ipairs(sv.skill_basic_ids) do M.set_override(id, "basic") end
  end
end

function M.print_unknown()
  local lines = {}
  local count = 0
  for id, info in pairs(unknown_log) do
    lines[#lines + 1] = string.format("  [%d] = \"?\",  -- %s", id, info)
    count = count + 1
  end
  if count == 0 then
    d("[skill_colors] No unclassified damage abilities seen yet.")
    return
  end
  table.sort(lines)
  local header = "[skill_colors] Unclassified abilities (" .. count .. ") — add to ABILITY_OVERRIDES / BASIC_ABILITY_IDS:"
  if Vermilion.Constants.DEBUG and Vermilion.CopyBox then
    Vermilion.CopyBox.show("Vermilion /skills", header .. "\n" .. table.concat(lines, "\n"))
  else
    d(header)
    for _, line in ipairs(lines) do d(line) end
  end
end


function M.unknown_lines()
  local lines = {}
  for id, info in pairs(unknown_log) do
    lines[#lines + 1] = string.format("  [%d] = \"?\",  -- %s", id, info)
  end
  if #lines == 0 then return { "(none — all damage abilities classified)" } end
  table.sort(lines)
  table.insert(lines, 1, "add to ABILITY_OVERRIDES / BASIC_ABILITY_IDS:")
  return lines
end

local BUFF_FAMILY_COLORS = {
  offense  = { r = 0.98, g = 0.60, b = 0.45, a = 0.95 },
  defense  = { r = 0.45, g = 0.62, b = 0.90, a = 0.95 },
  sustain  = { r = 0.72, g = 0.94, b = 0.84, a = 0.95 },
  mobility = { r = 0.75, g = 0.65, b = 0.95, a = 0.95 },
  status   = { r = 0.96, g = 0.62, b = 0.28, a = 0.95 },
  control  = { r = 0.80, g = 0.82, b = 0.55, a = 0.95 },
}

local EFFECT_FAMILY_NAMES = {
  burning = "status", poisoned = "status", chilled = "status", concussed = "status",
  overcharged = "status", diseased = "status", hemorrhaging = "status", sundered = "status",
  chill = "status", concussion = "status", poison = "status",
  taunt = "control", taunted = "control", stunned = "control", stun = "control",
  immobilized = "control", immobilize = "control", snared = "control", snare = "control",
  feared = "control", fear = "control", silenced = "control", silence = "control",
  ["off balance"] = "control", ["off-balance"] = "control", knockback = "control", knockdown = "control",
}

local BUFF_FAMILY_WORDS = {
  sorcery = "offense", brutality = "offense", prophecy = "offense", savagery = "offense",
  berserk = "offense", force = "offense", slayer = "offense", courage = "offense",
  empower = "offense", mending = "offense",
  breach = "offense", vulnerability = "offense", fracture = "offense",
  brittle = "offense", mangle = "offense",
  resolve = "defense", ward = "defense", protection = "defense", aegis = "defense",
  evasion = "defense", toughness = "defense", vitality = "defense",
  maim = "defense", defile = "defense", cowardice = "defense", uncertainty = "defense", enervation = "defense",
  intellect = "sustain", endurance = "sustain", fortitude = "sustain", heroism = "sustain",
  lifesteal = "sustain", magickasteal = "sustain", timidity = "sustain",
  expedition = "mobility", gallop = "mobility",
  hindrance = "mobility",
}

local family_cache = {}

function M.buff_family(name)
  if type(name) ~= "string" or name == "" then return nil end
  local hit = family_cache[name]
  if hit ~= nil then return hit or nil end
  local fam = false
  local lower = name:lower()
  local tier, word = lower:match("^(m[ai][jn]or)%s+(%a+)")
  if tier and word then
    fam = BUFF_FAMILY_WORDS[word] or false
  else
    fam = EFFECT_FAMILY_NAMES[lower] or false
  end
  family_cache[name] = fam
  return fam or nil
end

function M.buff_family_color(name)
  local fam = M.buff_family(name)
  return fam and BUFF_FAMILY_COLORS[fam] or nil
end

function M.ability_icon(id) return GetAbilityIcon(id) or "" end
function M.ability_name(id) return GetAbilityName(id) or ("#" .. tostring(id)) end

function M.group_shares(buf, now_ms, predicate)
  buf:trim(now_ms)
  local buckets = {}
  local total   = 0
  for i = buf.head, buf.tail do
    local e   = buf.entries[i]
    local amt = e.amount or 0
    if amt > 0 and (not predicate or predicate(e)) then
      local key = lookup_group(e.ability_id)
      buckets[key] = (buckets[key] or 0) + amt
      total = total + amt
    end
  end
  if total <= 0 then return {} end
  local out = {}
  for g, amt in pairs(buckets) do
    local c = GROUP_COLORS[g] or FALLBACK
    out[#out + 1] = { r = c.r, g = c.g, b = c.b, a = c.a, share = amt / total }
  end
  table.sort(out, function(a, b) return a.share > b.share end)
  return out
end
