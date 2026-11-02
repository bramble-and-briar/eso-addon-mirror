-- Conservative side-quest validation: unknown data remains visible to diagnostics
-- but cannot inflate the displayed total or create a false 100 percent result.
local RQD = _G.RaccoonQuestData
if type(RQD) ~= "table" then return end

local function AddReason(record, reason)
    record.reasons[#record.reasons + 1] = reason
end

local function HasUsableName(name)
    if type(name) ~= "string" or name == "" then return false end
    local lowered = string.lower(name)
    if lowered == "unknown" or lowered == "unbekannt" or lowered == "quest" then return false end
    local upper = string.upper(name)
    for _, marker in ipairs({ "OUTOFDATE", "QUEST IO BUG", "DEBUG QUEST", "TEST QUEST", "PLACEHOLDER QUEST" }) do
        if string.find(upper, marker, 1, true) then return false end
    end
    return true
end

function RQD:ValidateQuestRecord(record, priorityQuestIds)
    record.reasons = {}
    local exception = self.questExceptions[record.id] or {}
    record.verified = record.completed == true or record.libraryVerified == true or record.explicitInclude == true
    record.classification = "unknown"
    record.eligible = false

    if not record.verified then AddReason(record, "unverified_availability") end
    if not HasUsableName(record.name) then AddReason(record, "missing_or_placeholder_name") end
    if not tonumber(record.zoneId) or tonumber(record.zoneId) <= 0 then AddReason(record, "missing_zone") end

    local nonRepeatable = _G.QUEST_REPEAT_NOT_REPEATABLE or 0
    if record.repeatType ~= nil and record.repeatType ~= nonRepeatable then AddReason(record, "repeatable") end
    local ordinaryQuest = _G.QUEST_TYPE_NONE or 0
    if record.questType ~= nil and record.questType ~= ordinaryQuest then AddReason(record, "non_side_quest_type") end
    if type(priorityQuestIds) == "table" and priorityQuestIds[record.id] then AddReason(record, "priority_quest") end
    if record.explicitExclude then AddReason(record, "explicit_exclude") end

    local content = self:GetZoneContent(record.storyZoneId) or self:GetZoneContent(record.zoneId)
    local contentKind = exception.classification or (content and content.kind) or nil
    record.contentKind = contentKind
    if contentKind == "base" or contentKind == "free" then
        record.classification = "base"
    elseif contentKind == "dlc" then
        record.classification = "dlc"
    else
        AddReason(record, "unknown_content_zone")
    end
    if not record.verified then record.classification = "unknown" end

    local disqualifying = {
        missing_or_placeholder_name = true,
        missing_zone = true,
        repeatable = true,
        non_side_quest_type = true,
        priority_quest = true,
        explicit_exclude = true,
        unverified_availability = true,
        unknown_content_zone = true,
    }
    for _, reason in ipairs(record.reasons) do
        if disqualifying[reason] then return record end
    end
    record.eligible = true
    return record
end

