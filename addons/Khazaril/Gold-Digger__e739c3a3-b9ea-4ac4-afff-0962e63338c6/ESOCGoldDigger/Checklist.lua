-- Gold Digger daily checklist. A task is done when its saved day number is today.

local GP = ESOC_GoldDigger
local Checklist = {}
GP.Checklist = Checklist

Checklist.TASKS = {
    { id = "writs", label = "Daily crafting writs", scope = "character" },
    { id = "gather", label = "Gathering route (alchemy first)", scope = "character" },
    { id = "scry", label = "Scrying", scope = "character" },
    { id = "thieve", label = "Thieving and pickpocketing", scope = "character" },
    { id = "tome", label = "Tamriel Tome challenges", scope = "character", optional = true },
    { id = "list", label = "List today's earnings at the trader", scope = "account" },
    { id = "mail", label = "Collect mail", scope = "account" },
    { id = "bank", label = "Bank and stockpile check", scope = "account" },
}

local function store(task)
    return task.scope == "account" and GP.sv.account.done or GP.character.done
end

function Checklist.IsShown(task)
    return not task.optional or GP.sv.options.includeTome
end

function Checklist.IsDone(task)
    return store(task)[task.id] == GP.Today()
end

function Checklist.SetDone(task, done)
    store(task)[task.id] = done and GP.Today() or nil
    GP.Interface.Refresh()
end

function Checklist.Open()
    local open = {}
    for _, task in ipairs(Checklist.TASKS) do
        if Checklist.IsShown(task) and not Checklist.IsDone(task) then open[#open + 1] = task end
    end
    return open
end
