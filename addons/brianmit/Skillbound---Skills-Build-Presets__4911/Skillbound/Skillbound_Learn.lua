-- Skillbound_Learn.lua : "Learn this build's skills" (2026-10-01).
-- For the skills on a build's bars: buys the ones you haven't learned and picks the build's
-- morph, with your skill points, after a confirmation that lists what it will spend.
-- Same calls as CPBuild_Skills.lua (confirmed in-game there): SKILL_POINT_ALLOCATION_MANAGER
-- allocators Purchase / Morph; the game sends them to the server on the next frame.
-- Can't: change a morph you already picked the other way (that needs a Rededication
-- shrine), unlock skill lines, or morph a skill before it has enough XP. Those are listed.

local B = Skillbound
local L = B.L
local Capture = B.Capture
local Learn = {}
B.Learn = Learn

local MORPHS = { MORPH_SLOT_BASE, MORPH_SLOT_MORPH_1, MORPH_SLOT_MORPH_2 }

-- which morph slot (base / 1 / 2) a progression of this skill is
local function MorphOf(skillData, p)
    if not p or not p.GetAbilityId then return MORPH_SLOT_BASE end
    for _, m in ipairs(MORPHS) do
        local data = skillData:GetProgressionData(m)
        if data and data.GetAbilityId and data:GetAbilityId() == p:GetAbilityId() then return m end
    end
    return MORPH_SLOT_BASE
end

-- steps = { { s = skillData, kind = "buy" | "morph", morph, name } }, notes = { text }, points needed
function Learn.Plan(build)
    local steps, notes, seen = {}, {}, {}
    local points = SKILL_POINT_ALLOCATION_MANAGER and SKILL_POINT_ALLOCATION_MANAGER:GetAvailableSkillPoints() or 0
    local left = points
    for _, cat in ipairs(Capture.BARS) do
        for slot = Capture.FIRST_SLOT, Capture.ULT_SLOT do
            local e = build.skills and build.skills[cat] and build.skills[cat][slot]
            if e and not seen[e.name] then
                seen[e.name] = true
                local s, p, problem = B.Apply.FindSkill(e)
                if problem == "missing" then
                    notes[#notes + 1] = L("LEARN_NOTE_MISSING", e.name)
                elseif problem == "otherMorph" then
                    notes[#notes + 1] = L("LEARN_NOTE_SHRINE", e.name)
                elseif problem == "notLearned" or (s and not s:IsPurchased()) then
                    local line = s:GetSkillLineData()
                    if line and line.IsAvailable and not line:IsAvailable() then
                        notes[#notes + 1] = L("LEARN_NOTE_LINE", e.name)
                    elseif s.MeetsLinePurchaseRequirement and not s:MeetsLinePurchaseRequirement() then
                        notes[#notes + 1] = L("LEARN_NOTE_RANK", e.name)
                    elseif left < 1 then
                        notes[#notes + 1] = L("LEARN_NOTE_POINTS", e.name)
                    else
                        left = left - 1
                        steps[#steps + 1] = { s = s, kind = "buy", name = e.name }
                        local m = MorphOf(s, p)
                        if m ~= MORPH_SLOT_BASE then
                            notes[#notes + 1] = L("LEARN_NOTE_XP", e.name)   -- a new skill can't be morphed yet
                        end
                    end
                elseif s and p then
                    -- learned: the morph still to pick?
                    local want = MorphOf(s, p)
                    local cur = s.GetCurrentSkillProgressionKey and s:GetCurrentSkillProgressionKey() or MORPH_SLOT_BASE
                    if want ~= MORPH_SLOT_BASE and cur == MORPH_SLOT_BASE then
                        if s.IsAtMorph and not s:IsAtMorph() then
                            notes[#notes + 1] = L("LEARN_NOTE_XP", e.name)
                        elseif left < 1 then
                            notes[#notes + 1] = L("LEARN_NOTE_POINTS", e.name)
                        else
                            left = left - 1
                            steps[#steps + 1] = { s = s, kind = "morph", morph = want, name = e.name }
                        end
                    end
                end
            end
        end
    end
    return steps, notes, points - left, points
end

local function Run(build)
    if IsUnitInCombat("player") then B.Print(L("LEARN_COMBAT")) return end
    if SKILLS_AND_ACTION_BAR_MANAGER and SKILLS_AND_ACTION_BAR_MANAGER.GetSkillPointAllocationMode
        and SKILLS_AND_ACTION_BAR_MANAGER:GetSkillPointAllocationMode() ~= SKILL_POINT_ALLOCATION_MODE_PURCHASE_ONLY then
        B.Print(L("LEARN_RESPEC_OPEN"))
        return
    end
    local steps = Learn.Plan(build)
    local failed = {}
    for _, st in ipairs(steps) do
        local ok = pcall(function()
            local a = SKILL_POINT_ALLOCATION_MANAGER:GetSkillPointAllocatorForSkillData(st.s)
            local done
            if st.kind == "buy" then done = a:Purchase() else done = a:Morph(st.morph) end
            if not done then error("no") end
        end)
        if not ok then failed[#failed + 1] = st.name end
    end
    B.Print(L("LEARN_DONE", #steps - #failed))
    if #failed > 0 then B.Print(L("LEARN_FAILED", table.concat(failed, ", "))) end
    -- the bars can be slotted once the server has the purchases
    B.Later(function() B.callbacks:FireCallbacks("BuildsChanged") end, 1000)
end

function Learn.Ask(build)
    if not build then return end
    if not (SKILLS_DATA_MANAGER and SKILLS_DATA_MANAGER:IsDataReady()) then
        B.Print(L("LEARN_NOT_READY"))
        return
    end
    local steps, notes, used, have = Learn.Plan(build)
    if #steps == 0 then
        B.Print(L(#notes > 0 and "LEARN_NOTHING_BUT" or "LEARN_NOTHING", build.name))
        for _, n in ipairs(notes) do B.Print("  " .. n) end
        return
    end
    local lines = {}
    for _, st in ipairs(steps) do
        lines[#lines + 1] = L(st.kind == "buy" and "LEARN_LINE_BUY" or "LEARN_LINE_MORPH", st.name)
    end
    for _, n in ipairs(notes) do lines[#lines + 1] = B.Colorize(B.COLOR.dim, n) end
    B.W.Confirm(L("LEARN_TITLE"), L("LEARN_ASK", used, have) .. "\n\n" .. table.concat(lines, "\n"), function() Run(build) end)
end
