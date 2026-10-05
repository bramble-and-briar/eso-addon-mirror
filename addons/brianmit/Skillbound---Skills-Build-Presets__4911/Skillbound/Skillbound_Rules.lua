-- Skillbound_Rules.lua : automatic switching.
-- A rule: "When <something happens> -> wear <build>" (or ask first). Kinds:
--   pvp (Cyrodiil / Imperial City), bg (battleground), trial, dungeon (group dungeon),
--   house, overland (out in the world, delves too), zone (one zone), boss (a boss by name,
--   like Wizard's Wardrobe's per-boss pages), craft (at a crafting station), fish (fishing),
--   role (your group finder role).
-- craft / fish can switch back afterwards (rule.back): then the build's own "before"
-- snapshot is put back (Undo), which is ideal for a Champion-only layer.
-- sv.rules[i] = { id, kind, value, valueText, build = build id, ask, back, on, zone = zone id (boss
--   rules of a trial plan: only in that zone) }
-- Trial / dungeon plans (2026-10-01, like Wizard's Wardrobe's trial pages, but no boss data
-- table: bosses are learned when you meet them): sv.plans[zoneId] = { name }. A plan = a
-- "zone" rule (the trash build) + one boss rule per boss met there (added automatically,
-- without a build until you pick one). sv.bossesSeen[zoneId] = { [name] = true }.
-- sv.rulesPaused: all rules off for now (launcher right-click / keybind / Rules page switch).

local B = Skillbound
local L = B.L
local Rules = {}
B.Rules = Rules

Rules.KINDS = { "pvp", "bg", "trial", "dungeon", "house", "overland", "zone", "boss", "craft", "fish", "role" }
Rules.CAN_GO_BACK = { craft = true, fish = true }
-- more specific rules win when several match
local RANK = { boss = 5, zone = 4, trial = 3, dungeon = 3, bg = 3, pvp = 3, house = 3, overland = 1 }

local lastZoneId
local temporary          -- { rule, kind } while a craft / fish rule is active (to switch back)

function Rules.Text(rule)
    local key = "RULE_" .. string.upper(rule.kind)
    if rule.kind == "zone" or rule.kind == "boss" then return L(key, rule.valueText or "?") end
    if rule.kind == "role" then return L(key, GetString("SI_LFGROLE", rule.value or 0)) end
    return L(key)
end

function Rules.Add(kind, value, valueText)
    local r = { id = B.NewId(), kind = kind, value = value, valueText = valueText, on = true, ask = false }
    table.insert(B.sv.rules, r)
    B.callbacks:FireCallbacks("RulesChanged")
    return r
end

function Rules.IsPaused() return B.sv.rulesPaused == true end

function Rules.SetPaused(paused)
    B.sv.rulesPaused = paused or nil
    B.Print(L(paused and "RULES_PAUSED" or "RULES_RESUMED"))
    B.callbacks:FireCallbacks("RulesChanged")
end

function Rules.TogglePaused() Rules.SetPaused(not Rules.IsPaused()) end

-- ---------------------------------------------------------------------------
-- Plans (a trial / dungeon: trash build + a build per boss)

local function FindRule(kind, value, valueText, zone)
    for _, r in ipairs(B.sv.rules) do
        if r.kind == kind and r.value == value and r.zone == zone
            and (valueText == nil or zo_strlower(r.valueText or "") == zo_strlower(valueText)) then
            return r
        end
    end
end

function Rules.ZoneName(zoneId) return B.Name(GetZoneNameById(zoneId)) end

-- bosses met in a zone (names, sorted)
function Rules.BossesSeen(zoneId)
    local list = {}
    for name in pairs((B.sv.bossesSeen or {})[zoneId] or {}) do list[#list + 1] = name end
    table.sort(list)
    return list
end

-- zones you can plan: where you are (when it's a trial / dungeon) + every zone with bosses met
function Rules.PlannableZones()
    local list, seen = {}, {}
    local here = Rules.ZoneId()
    local k = Rules.ZoneKinds()
    if k.trial or k.dungeon then
        list[#list + 1] = here
        seen[here] = true
    end
    for zoneId in pairs(B.sv.bossesSeen or {}) do
        if not seen[zoneId] then
            list[#list + 1] = zoneId
            seen[zoneId] = true
        end
    end
    return list
end

function Rules.AddPlan(zoneId)
    B.sv.plans = B.sv.plans or {}
    B.sv.plans[zoneId] = { name = Rules.ZoneName(zoneId) }
    if not FindRule("zone", zoneId, nil, nil) then
        local r = { id = B.NewId(), kind = "zone", value = zoneId, valueText = Rules.ZoneName(zoneId), on = true, plan = zoneId }
        table.insert(B.sv.rules, r)
    end
    for _, name in ipairs(Rules.BossesSeen(zoneId)) do
        if not FindRule("boss", nil, name, zoneId) then
            table.insert(B.sv.rules, { id = B.NewId(), kind = "boss", valueText = name, zone = zoneId, on = true, plan = zoneId })
        end
    end
    B.callbacks:FireCallbacks("RulesChanged")
end

function Rules.RemovePlan(zoneId)
    if B.sv.plans then B.sv.plans[zoneId] = nil end
    for i = #B.sv.rules, 1, -1 do
        if B.sv.rules[i].plan == zoneId then table.remove(B.sv.rules, i) end
    end
    B.callbacks:FireCallbacks("RulesChanged")
end

-- a boss was met: remember it; in a planned zone it gets its own row right away
local function SawBoss(name)
    local zoneId = Rules.ZoneId()
    B.sv.bossesSeen = B.sv.bossesSeen or {}
    B.sv.bossesSeen[zoneId] = B.sv.bossesSeen[zoneId] or {}
    if B.sv.bossesSeen[zoneId][name] then return end
    B.sv.bossesSeen[zoneId][name] = true
    if B.sv.plans and B.sv.plans[zoneId] and not FindRule("boss", nil, name, zoneId) then
        table.insert(B.sv.rules, { id = B.NewId(), kind = "boss", valueText = name, zone = zoneId, on = true, plan = zoneId })
        B.Print(L("PLAN_NEW_BOSS", name, Rules.ZoneName(zoneId)))
        B.callbacks:FireCallbacks("RulesChanged")
    end
end

function Rules.Remove(id)
    for i, r in ipairs(B.sv.rules) do
        if r.id == id then
            table.remove(B.sv.rules, i)
            break
        end
    end
    B.callbacks:FireCallbacks("RulesChanged")
end

function Rules.Move(id, delta)
    local list = B.sv.rules
    for i, r in ipairs(list) do
        if r.id == id then
            local j = i + delta
            if j >= 1 and j <= #list then list[i], list[j] = list[j], list[i] end
            break
        end
    end
    B.callbacks:FireCallbacks("RulesChanged")
end

-- ---------------------------------------------------------------------------
-- Where you are

function Rules.ZoneId()
    return GetZoneId(GetUnitZoneIndex("player"))
end

local function InTrial()
    return IsPlayerInRaid and IsPlayerInRaid() or false
end

-- every zone kind that fits right now
function Rules.ZoneKinds()
    local k = {}
    if IsInAvAZone and IsInAvAZone() then k.pvp = true end
    if IsActiveWorldBattleground and IsActiveWorldBattleground() then k.bg = true end
    if InTrial() then
        k.trial = true
    elseif IsUnitInDungeon("player") and GetMapContentType() == MAP_CONTENT_DUNGEON then
        k.dungeon = true
    end
    if GetCurrentZoneHouseId and GetCurrentZoneHouseId() ~= 0 then k.house = true end
    if not (k.pvp or k.bg or k.trial or k.dungeon or k.house) then k.overland = true end
    return k
end

-- ---------------------------------------------------------------------------
-- Wearing (or asking)

-- returns true when it put the build on (or asked to)
local function Wear(rule)
    local build = B.Get(rule.build)
    if not build then return false end
    local c = B.Char()
    -- (1.0.0 fix: a rule never re-applies the build you already wear: with a missing food or
    -- piece the plan always had "changes", so every boss / big mob kill asked or re-wore it)
    if c.worn == build.id or c.layer == build.id then return false end
    if rule.ask then
        if ZO_Dialogs_IsShowing and ZO_Dialogs_IsShowing("SKILLBOUND_ASK") then return false end
        ZO_Dialogs_ShowDialog("SKILLBOUND_ASK", { build = build }, { mainTextParams = { build.name, Rules.Text(rule) } })
    else
        B.Print(L("RULE_WEARING", build.name, Rules.Text(rule)))
        B.Apply.Wear(build)
    end
    return true
end

local function Best(kinds, extra)
    if Rules.IsPaused() then return nil end
    local best, bestRank
    for _, r in ipairs(B.sv.rules) do
        if r.on and r.build and B.Get(r.build) then
            local match = kinds[r.kind]
            if r.kind == "zone" then match = r.value == Rules.ZoneId() end
            if r.kind == "boss" then match = extra and extra.boss and r.valueText
                and zo_strlower(extra.boss):find(zo_strlower(r.valueText), 1, true) ~= nil
                and (r.zone == nil or r.zone == Rules.ZoneId()) end
            if match then
                local rank = RANK[r.kind] or 0
                if not best or rank > bestRank then best, bestRank = r, rank end
            end
        end
    end
    return best
end

local function CheckZone()
    local rule = Best(Rules.ZoneKinds())
    if rule then Wear(rule) end
end

local function OnActivated()
    local zoneId = Rules.ZoneId()
    -- /reloadui fires this too: only act on a real zone change
    if zoneId == lastZoneId then return end
    local first = lastZoneId == nil and B.Char().lastZone == zoneId
    lastZoneId = zoneId
    B.Char().lastZone = zoneId
    if first then return end
    B.Later(CheckZone, 1500)
end

local lastBoss = ""
local bossSwitched = false   -- a boss rule changed your build (so the zone's build comes back after)
local function OnBosses()
    local boss = GetUnitName("boss1") or ""
    if boss == "" then boss = GetUnitName("boss2") or "" end
    if boss == lastBoss then return end
    lastBoss = boss
    if boss == "" then
        -- boss gone: back to the zone's build (the "trash" setup), but only when a boss rule had
        -- switched it (the game shows a boss bar for big mobs too: every kill re-checked the zone)
        if bossSwitched then
            bossSwitched = false
            B.Later(CheckZone, 1000)
        end
        return
    end
    -- (only bosses in instances are remembered: world bosses and delve bosses would flood the list)
    local k = Rules.ZoneKinds()
    if k.trial or k.dungeon then SawBoss(B.Name(boss)) end
    local rule = Best({}, { boss = boss })
    if rule and rule.kind == "boss" and Wear(rule) then bossSwitched = true end
end

-- craft / fish: wear now, switch back afterwards (when the rule says so)
local function StartTemporary(kind)
    if temporary then return end
    local rule = Best({ [kind] = true })
    if not rule then return end
    temporary = { rule = rule, kind = kind }
    Wear(rule)
end

local function EndTemporary(kind)
    if not temporary or temporary.kind ~= kind then return end
    local rule = temporary.rule
    temporary = nil
    if rule.back then
        B.Apply.Undo()
    end
end

local fishing, notFishingSince = false, 0
local function FishTick()
    local now = GetFrameTimeSeconds()
    local isFishing = GetInteractionType and GetInteractionType() == INTERACTION_FISH
    if isFishing then
        notFishingSince = now
        if not fishing then
            fishing = true
            StartTemporary("fish")
        end
    elseif fishing and now - notFishingSince > 20 then
        fishing = false
        EndTemporary("fish")
    end
end

local function OnRole(_, unitTag, role)
    local mine = unitTag == "player" or (GetLocalPlayerGroupUnitTag and unitTag == GetLocalPlayerGroupUnitTag())
    if not mine then return end
    role = role or (GetSelectedLFGRole and GetSelectedLFGRole())
    if Rules.IsPaused() then return end
    for _, r in ipairs(B.sv.rules) do
        if r.on and r.kind == "role" and r.value == role and B.Get(r.build) then
            Wear(r)
            return
        end
    end
end

-- turns the fishing check on only when a fishing rule exists
function Rules.Refresh()
    local needFish = false
    for _, r in ipairs(B.sv.rules) do
        if r.on and r.kind == "fish" then needFish = true end
    end
    B.EM:UnregisterForUpdate("Skillbound_Fish")
    if needFish then B.EM:RegisterForUpdate("Skillbound_Fish", 1000, FishTick) end
end

function Rules.Init()
    ESO_Dialogs["SKILLBOUND_ASK"] = {
        title = { text = L("TITLE") },
        mainText = { text = L("RULE_ASK") },
        buttons = {
            { text = L("RULE_ASK_YES"), callback = function(dialog) B.Apply.Wear(dialog.data.build) end },
            { text = SI_DIALOG_CANCEL },
        },
    }
    B.EM:RegisterForEvent("Skillbound_Rules", EVENT_PLAYER_ACTIVATED, OnActivated)
    B.EM:RegisterForEvent("Skillbound_Rules", EVENT_BOSSES_CHANGED, OnBosses)
    B.EM:RegisterForEvent("Skillbound_Rules", EVENT_CRAFTING_STATION_INTERACT, function() StartTemporary("craft") end)
    B.EM:RegisterForEvent("Skillbound_Rules", EVENT_END_CRAFTING_STATION_INTERACT, function() EndTemporary("craft") end)
    if EVENT_GROUP_MEMBER_ROLE_CHANGED then
        B.EM:RegisterForEvent("Skillbound_Rules", EVENT_GROUP_MEMBER_ROLE_CHANGED, OnRole)
    end
    B.callbacks:RegisterCallback("RulesChanged", Rules.Refresh)
    Rules.Refresh()
end
