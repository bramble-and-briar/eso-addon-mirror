-- High Achiever: the text for each tab. Each builder returns the text and the list X pins from.

local HA = ESOC_HighAchiever
local Lists = {}
HA.Lists = Lists

local C = HA.Colour

local function placeTitle(place)
    local title = place.name
    if place.veteran then
        title = title .. " (veteran)"
    elseif place.normal then
        title = title .. " (normal)"
    end
    return title
end

function Lists.Counts(state)
    if state.total == 0 then return "No achievements found for here" end
    return state.done .. " of " .. state.total .. " achievements done, " .. (state.total - state.done) .. " to go"
end

-- A one-line summary for Settings and the panel.
function Lists.Summary(state)
    return placeTitle(state.place) .. ": " .. Lists.Counts(state)
end

local function rewardText(reward)
    if not reward then return nil end
    if reward.text ~= "" then return reward.kind .. ": " .. reward.text end
    return reward.kind
end

local function pinnedLine()
    local pinned = HA.Pinned()
    if not pinned then return nil end
    local name = HA.Clean(HA.Safe(GetAchievementInfo, pinned) or "")
    if name == "" then return nil end
    return C(HA.GREY, "Pinned on screen: ") .. name
end

-- One achievement as a short block of lines.
local function entryLines(entry, state, lines)
    local head = C(HA.GOLD, entry.name)
    local details = {}
    if entry.progressText then details[#details + 1] = entry.progressText end
    if entry.stage then details[#details + 1] = "stage " .. entry.stage end
    if #details > 0 then head = head .. ": " .. table.concat(details, ", ") end
    if entry.id == HA.Pinned() then head = head .. C(HA.GREEN, "  (pinned)") end
    lines[#lines + 1] = head
    if entry.nextStep then
        lines[#lines + 1] = "   Next: " .. entry.nextStep
    elseif entry.description ~= "" then
        lines[#lines + 1] = "   " .. entry.description
    end
    local reward = rewardText(entry.reward)
    if reward then lines[#lines + 1] = "   " .. C(HA.YELLOW, "Reward: " .. reward) end
    if entry.veteranOnly and state.place.normal then
        lines[#lines + 1] = "   " .. C(HA.RED, "Needs veteran difficulty")
    end
    lines[#lines + 1] = ""
end

local function header(state, lines)
    lines[#lines + 1] = C(HA.GOLD, placeTitle(state.place))
    lines[#lines + 1] = Lists.Counts(state)
    local almost, titles, dyes, other = 0, 0, 0, 0
    for _, entry in ipairs(state.todo) do
        if entry.fraction >= 0.5 then almost = almost + 1 end
        if entry.reward then
            if entry.reward.kind == "Title" then
                titles = titles + 1
            elseif entry.reward.kind == "Dye" then
                dyes = dyes + 1
            elseif entry.reward.kind ~= "Item" then
                other = other + 1
            end
        end
    end
    local bits = {}
    if almost > 0 then bits[#bits + 1] = almost .. " more than half done" end
    if titles > 0 then bits[#bits + 1] = titles .. (titles == 1 and " gives a title" or " give titles") end
    if dyes > 0 then bits[#bits + 1] = dyes .. (dyes == 1 and " gives a dye" or " give dyes") end
    if other > 0 then bits[#bits + 1] = other .. (other == 1 and " gives a collectible" or " give collectibles") end
    if #bits > 0 then lines[#lines + 1] = table.concat(bits, ", ") end
    local pinned = pinnedLine()
    if pinned then lines[#lines + 1] = pinned end
    if not state.indexReady then lines[#lines + 1] = C(HA.GREY, "Still reading achievements; the list will fill in.") end
    lines[#lines + 1] = ""
end

function Lists.Here(state)
    local lines = {}
    header(state, lines)
    if #state.todo == 0 then
        lines[#lines + 1] = state.total > 0 and C(HA.GREEN, "Everything here is done.") or "Nothing to show for here."
    end
    for _, entry in ipairs(state.todo) do entryLines(entry, state, lines) end
    return table.concat(lines, "\n"), state.todo
end

function Lists.Rewards(state)
    local lines = {}
    header(state, lines)
    if #state.rewards == 0 then
        lines[#lines + 1] = "No rewards left to earn here."
    end
    for _, entry in ipairs(state.rewards) do entryLines(entry, state, lines) end
    return table.concat(lines, "\n"), state.rewards
end

function Lists.Done(state)
    local lines = {}
    header(state, lines)
    if #state.doneList == 0 then lines[#lines + 1] = "Nothing done here yet." end
    for _, entry in ipairs(state.doneList) do
        local line = C(HA.GREEN, entry.name)
        if entry.date and entry.date ~= "" then line = line .. C(HA.GREY, "  " .. entry.date) end
        lines[#lines + 1] = line
    end
    return table.concat(lines, "\n"), {}
end

function Lists.Check(state)
    local place = state.place
    local s = state.sources
    local lines = {
        C(HA.GOLD, "Detection check"),
        "Found here: " .. state.total .. " (Zone Guide " .. s.zoneGuide .. ", category " .. s.category
            .. ", name " .. s.name .. ", description " .. s.description .. ")",
        "Achievements read: " .. state.indexSize .. (state.indexReady and "" or " (still reading)"),
        "Place: " .. place.name .. " (" .. place.id .. "), zone " .. place.rootName .. " (" .. place.rootId .. ")"
            .. (place.inside and ", inside" or ""),
        "",
    }
    local names = {}
    for _, category in ipairs(HA.Index.Categories()) do
        local text = category.name
        if #category.subs > 0 then text = text .. " (" .. #category.subs .. ")" end
        names[#names + 1] = text
    end
    lines[#lines + 1] = "Categories: " .. table.concat(names, ", ")
    return table.concat(lines, "\n"), {}
end

Lists.TABS = {
    { name = "Here", build = Lists.Here },
    { name = "Rewards", build = Lists.Rewards },
    { name = "Done", build = Lists.Done },
    { name = "Check", build = Lists.Check },
}
