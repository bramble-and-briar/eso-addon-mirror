local BA = BuildAdvisor
-- Examines the character as it is right now (gear, stats, mundus, CP, skills) against the
-- targets for the chosen role and activity (Data/Targets.lua), and says what to keep and
-- what to change. Role and activity come from the player's picks, or are guessed.
BA.Advisor = {}
local Advisor = BA.Advisor

local SECTIONS = { "support", "damage", "survival", "gear", "mundus" }
local OVERCAP_MARGIN = 1000
local CRIT_RATING_PER_PERCENT = 219 -- level 50 conversion; needs validation
local BASE_CRIT_PERCENT = 10

local function Normalize(name) return BA.Scanner.NormalizeSetName(name) end

local function Lookup(list)
    local byKey = {}
    for _, name in ipairs(list) do byKey[Normalize(name)] = name end
    return byKey
end

local function Num(value)
    value = math.floor((value or 0) + 0.5)
    return ZO_CommaDelimitNumber and ZO_CommaDelimitNumber(value) or tostring(value)
end

local function JoinNames(names, max)
    local shown = {}
    for i = 1, zo_min(#names, max or #names) do shown[i] = names[i] end
    return table.concat(shown, ", ")
end

local function Pieces(count)
    return count == 1 and "1 piece" or (count .. " pieces")
end

local function HasTrait(piece, ...)
    local trait = (piece.trait or ""):lower()
    for _, wanted in ipairs({ ... }) do
        if trait:find(wanted, 1, true) then return true end
    end
    return false
end

-------------------------------------------------------------------------------
-- Context: which role and activity to judge against
-------------------------------------------------------------------------------
local function GuessRole(snap)
    local tankSets, healerSets = Lookup(BA.tankSupportSets), Lookup(BA.healerSupportSets)
    local selfishSets = Lookup(BA.tankSelfishSets)
    for key, set in pairs(snap.sets) do
        if tankSets[key] or selfishSets[key] then return "tank", "you're wearing " .. set.name end
    end
    if snap.armorWeights.heavy >= 5 then
        return "tank", string.format("you're wearing %d heavy armor pieces", snap.armorWeights.heavy)
    end
    for key, set in pairs(snap.sets) do
        if healerSets[key] then return "healer", "you're wearing " .. set.name end
    end
    return "damage", "no tank or healer gear found"
end

local function GuessActivity()
    local ok, activity, reason = pcall(function()
        if IsInCyrodiil and IsInCyrodiil() then return "cyrodiil", "you're in Cyrodiil" end
        if GetCurrentZoneDungeonDifficulty() == DUNGEON_DIFFICULTY_VETERAN then
            -- Location can't tell a PUG from an organized group; PUG is the safer assumption.
            if IsPlayerInRaid and IsPlayerInRaid() then return "group12_pug", "you're in a veteran trial" end
            return "group4_pug", "you're in a veteran instance"
        end
        return "overland", "you're not in a veteran instance"
    end)
    if ok then return activity, reason end
    return "overland", "location unknown"
end

function Advisor:GetContext(snap)
    local context = {}
    if BA.char.role then
        context.role, context.roleSource = BA.char.role, "your pick"
    else
        context.role, context.roleSource = GuessRole(snap)
        context.roleGuessed = true
    end
    if BA.char.activity then
        context.activity, context.activitySource = BA.char.activity, "your pick"
    else
        context.activity, context.activitySource = GuessActivity()
        context.activityGuessed = true
    end
    context.target = BA.targets[context.activity] or {}
    context.roleName = BA.rolesById[context.role].name
    context.roleNoun = BA.rolesById[context.role].noun
    context.activityName = BA.activitiesById[context.activity].name
    return context
end

-------------------------------------------------------------------------------
-- Checks. Each adds findings: kind = "change" (fix this), "keep" (good), "info".
-------------------------------------------------------------------------------
local function DamageNumbers(snap)
    local s = snap.stats
    local spell = (s.maxMagicka or 0) >= (s.maxStamina or 0)
    return {
        spell = spell,
        pen = (spell and s.spellPen or s.physPen) or 0,
        power = (spell and s.spellDamage or s.weaponDamage) or 0,
        critRating = (spell and s.spellCrit or s.weaponCrit) or 0,
        powerLabel = spell and "Spell Damage" or "Weapon Damage",
    }
end

local function HasChampion(snap, name)
    local wanted = name:lower()
    for _, star in ipairs(snap.champion) do
        if star.name:lower() == wanted then return true end
    end
    return false
end

-- Penetration the player still needs after the group's debuffs, and Force of Nature's share
-- (it's on the character sheet's side of the ledger only while slotted, so it's counted here).
local function PenetrationTarget(snap, target)
    if not target.enemyResistance then return nil end
    local forceOfNature = 0
    if HasChampion(snap, "Force of Nature") then
        forceOfNature = (target.statusCount or 0) * BA.FORCE_OF_NATURE_PER_STATUS
    end
    return target.enemyResistance - (target.groupPenetration or 0) - forceOfNature, forceOfNature
end

-- "Major Breach, Sundered (Minor Breach)" etc. for the debuffs that remove resistance.
local function PenetrationDebuffNames(target)
    local names = {}
    for _, id in ipairs(target.debuffs or {}) do
        if BA.DEBUFFS[id].pen then names[#names + 1] = BA.DEBUFFS[id].name end
    end
    if (target.extraPenetration or 0) > 0 then names[#names + 1] = "extra debuff sets" end
    return names
end

function Advisor:CheckDamage(r)
    local snap, ctx, t = r.snap, r.ctx, r.ctx.target
    if ctx.role ~= "damage" then
        r:Add("damage", "info", string.format("Penetration and crit aren't the focus for a %s.", ctx.roleNoun))
        return
    end
    local d = DamageNumbers(snap)
    local penTarget, forceOfNature = PenetrationTarget(snap, t)
    if not penTarget then
        r:Add("damage", "info", string.format("Penetration %s. PvP targets vary; balance penetration against survivability.", Num(d.pen)))
    elseif d.pen < penTarget then
        local debuffNames = PenetrationDebuffNames(t)
        local groupNote = #debuffNames > 0
            and string.format(" (%s enemy resistance minus ~%s from %s)", Num(t.enemyResistance), Num(t.groupPenetration), table.concat(debuffNames, ", "))
            or string.format(" (%s enemy resistance, no group debuffs)", Num(t.enemyResistance))
        r:Add("damage", "change", string.format("Penetration %s is %s short of the ~%s you need here%s. Sources: The Lover mundus, Sharpened weapon trait, the Piercing or Force of Nature CP stars, or a penetration set.",
            Num(d.pen), Num(penTarget - d.pen), Num(penTarget), groupNote))
        r.penShort = true
    elseif d.pen > penTarget + OVERCAP_MARGIN then
        r:Add("damage", "change", string.format("Penetration %s is about %s over the ~%s this content needs. The extra is wasted: move it into crit and %s (e.g. Sharpened to Precise, Lover to Thief or Shadow).",
            Num(d.pen), Num(d.pen - penTarget), Num(penTarget), d.powerLabel))
        r.penOver = true
    else
        r:Add("damage", "keep", string.format("Penetration %s is on target (~%s).", Num(d.pen), Num(penTarget)))
    end
    if forceOfNature and forceOfNature > 0 then
        r:Add("damage", "info", string.format("Force of Nature is counted: ~%d status effects on the boss give you ~%s penetration.", t.statusCount, Num(forceOfNature)))
    end

    local critPercent = BASE_CRIT_PERCENT + d.critRating / CRIT_RATING_PER_PERCENT
    r:Add("damage", "info", string.format("Crit chance about %d%% (%s rating), %s %s.", math.floor(critPercent), Num(d.critRating), d.powerLabel, Num(d.power)))
    if t.groupContent and not r.penShort then
        r:Add("damage", "info", "With penetration covered, push crit chance, crit damage (cap 125%) and " .. d.powerLabel .. ".")
    end
    local hasDebuff = t.hasDebuff or {}
    if hasDebuff.brittle or hasDebuff.chilled then
        r:Add("damage", "info", "Your group brings Brittle and Chilled, so the boss takes extra crit damage: you need less crit damage of your own to reach the 125% cap.")
    end
    if hasDebuff.off_balance and not HasChampion(snap, "Exploiter") then
        r:Add("damage", "change", "Off Balance is usually up on bosses here. Slot the Exploiter CP star for extra damage against Off Balance enemies.")
    end
    if (t.statusCount or 0) >= 4 and not HasChampion(snap, "Force of Nature") then
        r:Add("damage", "info", string.format("With ~%d status effects on the boss, the Force of Nature CP star would add ~%s penetration.",
            t.statusCount, Num(t.statusCount * BA.FORCE_OF_NATURE_PER_STATUS)))
    end
end

function Advisor:CheckSurvival(r)
    local snap, ctx, t = r.snap, r.ctx, r.ctx.target
    local health = snap.stats.maxHealth or 0
    local range = t.health and t.health[ctx.role]
    if range then
        local min, max = range[1], range[2]
        if min and health < min then
            r:Add("survival", "change", string.format("Health %s is under the ~%s minimum for %s. Add health with food, The Lord mundus, a health set, or health enchants.",
                Num(health), Num(min), ctx.activityName))
        elseif max and health > max then
            r.healthOver = true
            if ctx.role == "tank" then
                r:Add("survival", "change", string.format("Health %s is above the ~%s a tank needs in %s. See Group Support for better uses of those stats.", Num(health), Num(max), ctx.activityName))
            else
                r:Add("survival", "change", string.format("Health %s is above the ~%s this content needs. Trade some for damage or sustain.", Num(health), Num(max)))
            end
        else
            r:Add("survival", "keep", string.format("Health %s fits %s (%s%s).", Num(health), ctx.activityName, Num(min), max and (" to " .. Num(max)) or "+"))
        end
    end

    local resistTarget = t.resist and t.resist[ctx.role]
    if resistTarget then
        local phys, spell = snap.stats.physResist or 0, snap.stats.spellResist or 0
        local low = zo_min(phys, spell)
        if low < resistTarget then
            r:Add("survival", "change", string.format("Resistance %s physical / %s spell is under ~%s. Heavy armor, Sturdy or Reinforced traits, The Lady mundus, or resistance CP help.",
                Num(phys), Num(spell), Num(resistTarget)))
        elseif ctx.role == "tank" and low > BA.RESIST_CAP + 3000 then
            r:Add("survival", "change", string.format("Resistance %s / %s is well past the %s cap (50%% mitigation). The excess does nothing; trade it for health or group support.",
                Num(phys), Num(spell), Num(BA.RESIST_CAP)))
        else
            r:Add("survival", "keep", string.format("Resistance %s physical / %s spell meets ~%s.", Num(phys), Num(spell), Num(resistTarget)))
        end
    end
    -- roleNotes override the general note, which is mostly written for damage dealers.
    local note = (t.roleNotes and t.roleNotes[ctx.role]) or (ctx.role == "damage" and t.note)
    if note then r:Add("survival", "info", note) end
end

local function SkillsOnBars(snap)
    local slotted = {}
    for _, bar in pairs(snap.bars) do
        for _, skill in ipairs(bar) do slotted[skill.name:lower()] = true end
    end
    return slotted
end

-- Recommends only essential effects that are missing. Other utility counts when slotted,
-- and is offered as examples (for this class) only when nothing on the bars helps the group.
local function CheckUtilitySkills(r, utilityList)
    local slotted = SkillsOnBars(r.snap)
    local have, missingEssential, examples = {}, {}, {}
    for _, utility in ipairs(utilityList) do
        local found
        for _, name in ipairs(utility.names) do
            if slotted[name:lower()] then found = name break end
        end
        local forThisClass = not utility.class or BA.Scanner.CLASS_IDS[utility.class] == r.snap.classId
        if found then
            have[#have + 1] = string.format("%s (%s)", found, utility.effect)
        elseif utility.essential then
            missingEssential[#missingEssential + 1] = utility
        elseif forThisClass then
            examples[#examples + 1] = string.format("%s (%s)", utility.names[1], utility.effect)
        end
    end
    if #have > 0 then r:Add("support", "keep", "Group utility on your bars: " .. table.concat(have, ", ") .. ".") end
    for _, utility in ipairs(missingEssential) do
        r:Add("support", "change", string.format("Nothing on your bars applies %s. Slot one of: %s.", utility.effect, JoinNames(utility.names, 3)))
    end
    if #have == 0 and #examples > 0 then
        r:Add("support", "change", "Nothing on your bars buffs the group or debuffs enemies. Options include " .. JoinNames(examples, 3) .. ".")
    end
    return #have
end

local function FindSets(snap, list)
    local lookup, found = Lookup(list), {}
    for key, set in pairs(snap.sets) do
        if lookup[key] then found[#found + 1] = set.name end
    end
    table.sort(found)
    return found
end

-- The group's penetration math assumes Crusher, which comes from the tank's weapon enchant
-- in 4-man and the off tank's in 12-man.
function Advisor:CheckCrusher(r)
    local crusherFrom = r.ctx.target.crusherFrom
    if not crusherFrom then return end
    for _, piece in ipairs(r.snap.slots) do
        if piece.weaponType and piece.enchant:lower():find("crush", 1, true) then
            r:Add("support", "keep", "Crusher enchant on " .. piece.name .. ".")
            return
        end
    end
    if crusherFrom == "tank" then
        r:Add("support", "change", "No Crusher enchant on your weapons. In 4-man your group counts on the tank for Crusher (~2,108 penetration).")
    else
        r:Add("support", "info", "No Crusher enchant on your weapons. In trials the off tank brings Crusher; if that's you, enchant your weapon with it.")
    end
end

function Advisor:CheckSupport(r)
    local snap, ctx = r.snap, r.ctx
    if ctx.role == "tank" then
        local support, selfish = FindSets(snap, BA.tankSupportSets), FindSets(snap, BA.tankSelfishSets)
        local suggestions = JoinNames(BA.tankSupportSets, 4)
        if #support == 0 and (r.healthOver or #selfish > 0) then
            r:Add("support", "change", string.format("This is a selfish tank setup: %s health and %s, but nothing that helps your group. A tank's value is buffing the group and debuffing enemies. Swap a set for one like %s.",
                Num(snap.stats.maxHealth), #selfish > 0 and table.concat(selfish, ", ") or "no support sets", suggestions))
        elseif #support == 0 then
            r:Add("support", "change", "None of your sets help the group. Tanks bring the most value with sets like " .. suggestions .. ".")
        else
            r:Add("support", "keep", "Group support sets: " .. table.concat(support, ", ") .. ".")
            if #selfish > 0 then
                r:Add("support", "info", table.concat(selfish, ", ") .. " only helps you. Fine while learning; swap it for group support once you're comfortable.")
            end
        end
        self:CheckCrusher(r)
        -- Skills after sets, so the set diagnosis leads the summary.
        CheckUtilitySkills(r, BA.tankUtilitySkills)
    elseif ctx.role == "healer" then
        local support = FindSets(snap, BA.healerSupportSets)
        if #support == 0 then
            r:Add("support", "change", "None of your sets buff the group. Healers bring the most value with sets like " .. JoinNames(BA.healerSupportSets, 4) .. ".")
        else
            r:Add("support", "keep", "Group support sets: " .. table.concat(support, ", ") .. ".")
        end
        CheckUtilitySkills(r, BA.healerUtilitySkills)
    else
        r:Add("support", "info", "Group support is checked for tanks and healers. As damage, your job is damage; see Damage.")
    end
end

function Advisor:CheckGear(r)
    local snap, ctx, t = r.snap, r.ctx, r.ctx.target
    local w = snap.armorWeights
    r:Add("gear", "info", string.format("Armor: %d light, %d medium, %d heavy.", w.light, w.medium, w.heavy))

    local partial = {}
    for _, set in pairs(snap.sets) do
        if set.max and set.max > 1 and set.equipped < set.max then
            partial[#partial + 1] = string.format("%s %d/%d", set.name, set.equipped, set.max)
        end
    end
    table.sort(partial)
    if #partial > 0 then
        r:Add("gear", "change", "Incomplete sets (their top bonus is off): " .. table.concat(partial, ", ") .. ".")
    end

    local notImpen, defensiveOnDamage, noEnchant = 0, 0, 0
    for _, piece in ipairs(snap.slots) do
        if piece.armorWeight then
            if t.pvp and not HasTrait(piece, "impenetrable") then notImpen = notImpen + 1 end
            if not t.pvp and ctx.role == "damage" and HasTrait(piece, "sturdy", "reinforced", "impenetrable", "well-fitted") then
                defensiveOnDamage = defensiveOnDamage + 1
            end
        end
        if not piece.weaponType and piece.enchant == "" then noEnchant = noEnchant + 1 end
    end
    if notImpen > 0 then
        r:Add("gear", "change", string.format("Armor without Impenetrable: %s. In PvP it cuts the crit damage you take.", Pieces(notImpen)))
    end
    if defensiveOnDamage > 0 then
        r:Add("gear", "change", string.format("Armor with defensive traits: %s. For PvE damage, Divines (or Infused on big pieces) does more.", Pieces(defensiveOnDamage)))
    end
    if noEnchant > 0 then
        r:Add("gear", "change", string.format("Armor or jewelry with no enchantment: %s.", Pieces(noEnchant)))
    end
    if #partial == 0 and notImpen == 0 and defensiveOnDamage == 0 and noEnchant == 0 then
        r:Add("gear", "keep", "Sets are complete and traits and enchants fit this role.")
    end
end

local function Contains(list, value)
    for _, entry in ipairs(list) do if entry == value then return true end end
    return false
end

function Advisor:CheckMundusAndChampion(r)
    local snap, ctx = r.snap, r.ctx
    local advice = BA.mundusAdvice[ctx.role]
    local current = snap.mundus[1]
    if not current then
        r:Add("mundus", "change", "No mundus stone active. For a " .. ctx.roleNoun .. ", use " .. table.concat(advice.default, " or ") .. ".")
    elseif r.penShort and advice.penShort and current ~= advice.penShort then
        r:Add("mundus", "change", string.format("Mundus %s: switch to %s to close your penetration gap.", current, advice.penShort))
    elseif r.penOver and current == advice.penShort then
        r:Add("mundus", "change", string.format("Mundus %s adds penetration you don't need here. %s does more.", current, table.concat(advice.default, " or ")))
    elseif Contains(advice.default, current) or current == advice.penShort then
        r:Add("mundus", "keep", "Mundus " .. current .. " suits this role.")
    else
        r:Add("mundus", "info", string.format("Mundus %s. Most %ss use %s.", current, ctx.roleNoun, table.concat(advice.default, " or ")))
    end

    local slotted = #snap.champion
    if slotted < 12 then
        r:Add("mundus", "change", string.format("%d of 12 champion slots are empty. Every slot is free power.", 12 - slotted))
    else
        r:Add("mundus", "keep", "All 12 champion slots are filled.")
    end
end

-------------------------------------------------------------------------------
-- Report
-------------------------------------------------------------------------------
local SCAN_SECTIONS_USED = {
    damage = { "stats" }, survival = { "stats" }, support = { "gear", "skills" },
    gear = { "gear" }, mundus = { "mundus", "champion" },
}

function Advisor:Analyze()
    local snap = BA.Scanner:Snapshot()
    local report = { snap = snap, findings = {} }
    for _, key in ipairs(SECTIONS) do report.findings[key] = {} end
    function report:Add(section, kind, text)
        local list = self.findings[section]
        list[#list + 1] = { kind = kind, text = text }
    end
    report.ctx = self:GetContext(snap)

    -- Damage first: the mundus check uses its penetration result.
    self:CheckDamage(report)
    self:CheckSurvival(report)
    self:CheckSupport(report)
    self:CheckGear(report)
    self:CheckMundusAndChampion(report)

    for section, scanSections in pairs(SCAN_SECTIONS_USED) do
        for _, scanSection in ipairs(scanSections) do
            if snap.errors[scanSection] then
                report:Add(section, "info", "Could not read " .. scanSection .. ": " .. snap.errors[scanSection])
            end
        end
    end
    return report
end

local PREFIX = { change = "CHANGE: ", keep = "GOOD: ", info = "" }

function Advisor:FormatSection(report, section)
    local lines = {}
    for _, finding in ipairs(report.findings[section]) do
        lines[#lines + 1] = PREFIX[finding.kind] .. finding.text
    end
    return table.concat(lines, "\n\n")
end

-- What the chosen role and activity mean for this character: what the group is assumed to
-- bring, what the player is expected to bring, and the targets they're checked against.
local function DescribeExpectations(report)
    local ctx, t, snap = report.ctx, report.ctx.target, report.snap
    local lines = {}

    local debuffNames = {}
    for _, id in ipairs(t.debuffs or {}) do debuffNames[#debuffNames + 1] = BA.DEBUFFS[id].name end
    if #debuffNames > 0 then
        lines[#lines + 1] = "Group assumed to keep up: " .. table.concat(debuffNames, ", ") .. "."
    elseif not t.pvp then
        lines[#lines + 1] = "No group debuffs assumed."
    end

    if ctx.role == "tank" and t.groupContent then
        local duties = { "Major Breach", "taunt" }
        if t.crusherFrom == "tank" then duties[#duties + 1] = "Crusher" end
        lines[#lines + 1] = "You're expected to bring: " .. table.concat(duties, ", ") .. "."
    end

    if ctx.role == "damage" then
        local penTarget, forceOfNature = PenetrationTarget(snap, t)
        if penTarget then
            local fon = forceOfNature > 0 and string.format(" (after ~%s from Force of Nature)", Num(forceOfNature)) or ""
            lines[#lines + 1] = string.format("Your penetration target: ~%s%s.", Num(zo_max(penTarget, 0)), fon)
        end
    end

    local range = t.health and t.health[ctx.role]
    if range then
        local healthText = range[2] and string.format("%s to %s", Num(range[1]), Num(range[2])) or (Num(range[1]) .. "+")
        local resist = t.resist and t.resist[ctx.role]
        lines[#lines + 1] = string.format("Health for a %s: %s%s.", ctx.roleNoun, healthText,
            resist and string.format("; resistance %s", Num(resist)) or "")
    end
    return lines
end

function Advisor:FormatSummary(report)
    local ctx = report.ctx
    local lines = { string.format("Checking as: %s in %s.", ctx.roleName, ctx.activityName) }
    if ctx.roleGuessed then lines[#lines + 1] = "Role guessed: " .. ctx.roleSource .. "." end
    if ctx.activityGuessed then lines[#lines + 1] = "Activity guessed: " .. ctx.activitySource .. "." end
    if ctx.roleGuessed or ctx.activityGuessed then
        lines[#lines + 1] = "Wrong? Set Role and Activity at the top of this menu."
    end
    lines[#lines + 1] = ""
    for _, line in ipairs(DescribeExpectations(report)) do lines[#lines + 1] = line end

    local changes = {}
    for _, section in ipairs(SECTIONS) do
        for _, finding in ipairs(report.findings[section]) do
            if finding.kind == "change" then changes[#changes + 1] = finding.text end
        end
    end
    lines[#lines + 1] = ""
    if #changes == 0 then
        lines[#lines + 1] = "Nothing to change for this role and activity."
    else
        lines[#lines + 1] = #changes == 1 and "1 thing to change:" or string.format("%d things to change. Most important:", #changes)
        -- First sentence only: long tooltips get cut off on console. Details are in each row.
        for i = 1, zo_min(#changes, 3) do
            lines[#lines + 1] = "- " .. (changes[i]:match("^(.-%.)%s") or changes[i])
        end
    end
    return table.concat(lines, "\n")
end
