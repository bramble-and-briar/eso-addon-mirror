local A = OneCraft.Alchemy
local S = {}
A.SolventSelector = S
-- Level, champion points, proficiency rank, water item ID, oil item ID.
S.levels = {
    {3, 0, 1, 883, 75357}, {10, 0, 1, 1187, 75358},
    {20, 0, 2, 4570, 75359}, {30, 0, 3, 23265, 75360},
    {40, 0, 4, 23266, 75361}, {50, 10, 5, 23267, 75362},
    {50, 50, 6, 23268, 75363}, {50, 100, 7, 64500, 75364},
    {50, 150, 8, 64501, 75365},
}

function S.Label(index)
    local row = S.levels[index]
    return string.format(row[2] > 0 and A.text.cpFormat or A.text.levelFormat, row[2] > 0 and row[2] or row[1])
end

function S.Item(index, kind)
    local row = S.levels[index]
    return A.inventory[row[3 + kind]], row[3 + kind]
end

function S.Available(index, kind)
    local row = S.levels[index]
    local item = S.Item(index, kind)
    return row[3] <= GetNonCombatBonus(NON_COMBAT_BONUS_ALCHEMY_LEVEL) and item ~= nil
end

function S.ChooseLevel(index)
    if A.IsBusy() then return end
    A.level = index
    A.ReagentSelector.Refresh()
    A.CraftingIntegration.Apply()
    A.AlchemyUI.Refresh()
end

function S.ChooseKind(kind)
    if A.IsBusy() or not S.Available(A.level, kind) then return end
    A.kind = kind
    A.ReagentSelector.Refresh()
    A.CraftingIntegration.Apply()
    A.AlchemyUI.Refresh()
end
