-- Auditable, intentionally small exception registry. Add IDs only with evidence.
local RQD = _G.RaccoonQuestData
if type(RQD) ~= "table" then return end

RQD.questExceptions = RQD.questExceptions or {}
RQD.exclusiveGroups = RQD.exclusiveGroups or {}

-- Example maintenance shape (no speculative production IDs):
-- RQD:RegisterQuestException(1234, { include = true, classification = "base" })
-- RQD:RegisterExclusiveGroup("mutually-exclusive-choice", { 1234, 1235 })

