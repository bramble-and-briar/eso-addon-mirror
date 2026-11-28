local C = CrownCrateCodex
local function Stamp(timestamp)
    if not timestamp then return C.L("not yet") end
    if not GetDateStringFromTimestamp then return tostring(timestamp) end
    local seconds = timestamp % 86400
    return GetDateStringFromTimestamp(timestamp) .. string.format(" %02d:%02d UTC", math.floor(seconds / 3600), math.floor(seconds / 60) % 60)
end
function C:StatusRows()
    local imported, live, matched, unknown, catalogued = 0, 0, 0, 0, 0
    for _, opening in ipairs(self.db.history) do
        if opening.source == "tracker" then imported = imported + 1 else live = live + 1 end
        for _, reward in ipairs(opening.rewards) do
            if reward.tierSource == "matched live reward" then matched = matched + 1 end
            if reward.catalogTier then catalogued = catalogued + 1 end
            if not reward.rarity then unknown = unknown + 1 end
        end
    end
    local report = self.db.lastImport or {}
    return {
        { heading = C.L("History retained"), detail = string.format(C.L("%d native openings | %d imported openings | Statistics switches never delete records."), live, imported) },
        { heading = C.L("Automatic Tracker synchronization"), detail = string.format(C.L("%s | Last check: %s | %d added, %d already present, %d unreadable, %d rejected failed rows."),
            report.trackerAvailable and C.L("Tracker data available") or C.L("No Tracker data loaded (Codex records independently)"),
            Stamp(report.timestamp), report.imported or 0, report.existing or 0, report.invalid or 0, report.rejected or 0) },
        { heading = C.L("Recording diagnostics"), detail = string.format(C.L("Last native recording: %s | %d failed requests | %d unreadable successful results."), Stamp(self.db.lastRecorded), self.db.diagnostics.failedOpens, self.db.diagnostics.unreadableOpens) },
        { heading = C.L("Historical rarity provenance"), detail = string.format(C.L("%d cards matched to the UESP catalog | %d live tier matches | %d unresolved rarities. Hover rewards for source revisions."), catalogued, matched, unknown) },
        { heading = C.L("Work happens on events"), detail = C.L("Recording: crate-open responses. Import: login, opening Codex, manual import, and one deferred callback after open responses.") },
        { heading = C.L("Backups are a separate Windows helper"), detail = C.L("The optional helper waits for saved-history file changes. ESO writes them at reload/logout; unsaved openings cannot be backed up."),
            tooltip = C.L("An ESO addon cannot read Windows Task Scheduler or the external backup directory. This is not a claim that the helper is healthy.\nUse the Windows task 'Crown Crate Codex History Backup' and .local/history-backups to check it.\nNo per-frame addon update or repeating import timer is registered.") },
    }
end
