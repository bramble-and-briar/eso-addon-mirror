using System.Text.Json;
using System.Text.RegularExpressions;

internal static partial class Program
{
    private static async Task RefreshRecordsAddonAsync(
        HttpClient client,
        string apiEndpoint,
        string addOnsPath,
        TextWriter output)
    {
        var endpoint = new Uri(new Uri(apiEndpoint.TrimEnd('/') + "/"), "v1/records");
        using var response = await client.GetAsync(endpoint);
        var responseText = await response.Content.ReadAsStringAsync();
        if (!response.IsSuccessStatusCode)
            throw new InvalidDataException($"HTTP {(int)response.StatusCode} {SafeResponse(responseText)}");
        var snapshot = JsonSerializer.Deserialize(
                responseText,
                CompanionJsonContext.Default.CapturedRecordsResponse)
            ?? throw new InvalidDataException("record response was empty");
        ValidateCapturedRecords(snapshot);
        await WriteRecordsAddonAsync(addOnsPath, snapshot);
        var guildEventCount = (snapshot.Guilds ?? []).Sum(guild => guild.Events?.Length ?? 0);
        var guildRecordCount = (snapshot.Guilds ?? []).Count(guild => guild.RecordsEnabled);
        output.WriteLine($"Captured records refreshed: {snapshot.Records.Length} current winner(s), {(snapshot.HighStandings ?? []).Length} high-standing row(s), and {(snapshot.RaceToBottomRecords ?? []).Length} Race-to-the-Bottom row(s) across PC NA and PC EU; {guildRecordCount} guild record route(s); {guildEventCount} active guild event(s).");
    }

    private static void ValidateCapturedRecords(CapturedRecordsResponse snapshot)
    {
        if (snapshot.SchemaVersion != 2 || snapshot.Scope != "PC NA + PC EU" || snapshot.Records is null)
            throw new InvalidDataException("record response schema or scope is unsupported");

        var keys = new HashSet<string>(StringComparer.Ordinal);
        foreach (var record in snapshot.Records)
        {
            ValidateCapturedRecord(record);
            if (!keys.Add($"{record.ZoneId}"))
                throw new InvalidDataException($"duplicate captured record for zone {record.ZoneId}");
        }

        var partyKeys = new HashSet<string>(StringComparer.Ordinal);
        foreach (var record in snapshot.PartyRecords ?? [])
        {
            ValidateCapturedRecord(record);
            if (!partyKeys.Add($"{record.ZoneId}|{record.RunGroupSize}"))
                throw new InvalidDataException($"duplicate party-size record for zone {record.ZoneId}, size {record.RunGroupSize}");
        }

        if (snapshot.WorldPublicationDepth != 10 || snapshot.RaceToBottomPublicationDepth != 10)
            throw new InvalidDataException("public standings depths are unsupported");

        ValidateHighStandings(snapshot.HighStandings ?? []);
        ValidateRaceToBottomStandings(snapshot.RaceToBottomRecords ?? []);
        ValidateGuilds(snapshot.Guilds ?? []);
    }

    private static void ValidateHighStandings(IEnumerable<HighStandingRecord> records)
    {
        var keys = new HashSet<string>(StringComparer.Ordinal);
        foreach (var record in records)
        {
            if (record.RecordClass is not ("overall" or "solo" or "duo" or "trio" or "4-player")
                || record.Rank < 1 || record.Rank > 10
                || !HasValidScoreAndRun(record.ZoneId, record.FinalScore, record.ElapsedMs, record.RunGroupSize)
                || string.IsNullOrWhiteSpace(record.TeamName)
                || string.IsNullOrWhiteSpace(record.ZoneName)
                || !IsPcMegaserver(record.Megaserver)
                || !keys.Add($"{record.ZoneId}|{record.RecordClass}|{record.Rank}"))
                throw new InvalidDataException("invalid or duplicate high-standing record");
        }
    }

    private static void ValidateRaceToBottomStandings(IEnumerable<RaceToBottomRecord> records)
    {
        var keys = new HashSet<string>(StringComparer.Ordinal);
        foreach (var record in records)
        {
            if (record.Rank < 1 || record.Rank > 10
                || !HasValidScoreAndRun(record.ZoneId, record.FinalScore, record.ElapsedMs, record.RunGroupSize)
                || record.RunOutcome is not ("completed" or "abandoned")
                || string.IsNullOrWhiteSpace(record.TeamName)
                || string.IsNullOrWhiteSpace(record.ZoneName)
                || !IsPcMegaserver(record.Megaserver)
                || !keys.Add($"{record.RunGroupSize}|{record.Rank}"))
                throw new InvalidDataException("invalid or duplicate Race-to-the-Bottom record");
        }
    }

    private static void ValidateGuilds(IEnumerable<GuildConfig> guilds)
    {
        var guildIds = new HashSet<string>(StringComparer.Ordinal);
        var guildEventIds = new HashSet<string>(StringComparer.Ordinal);
        foreach (var guild in guilds)
        {
            if (!IsPublicIdentifier(guild.GuildId) || string.IsNullOrWhiteSpace(guild.GuildName)
                || guild.GuildName.Length > 80 || guild.Events is null || !guildIds.Add(guild.GuildId)
                || guild.RecordPublicationDepth < 1 || guild.RecordPublicationDepth > 10
                || !IsAccessMode(guild.AccessMode)
                || (guild.AccessMode == "eso-members"
                    && (string.IsNullOrWhiteSpace(guild.EsoGuildName) || guild.EsoGuildName.Length > 80
                        || !IsPcMegaserver(guild.Megaserver)))
                || !IsRecruitmentMode(guild.RecruitmentMode)
                || !HasValidRecruitment(guild))
                throw new InvalidDataException("invalid or duplicate guild configuration");

            foreach (var guildEvent in guild.Events)
                ValidateGuildEvent(guildEvent, guildEventIds);
        }
    }

    private static void ValidateGuildEvent(GuildEventConfig guildEvent, HashSet<string> guildEventIds)
    {
        if (!IsPublicIdentifier(guildEvent.GuildEventId)
            || string.IsNullOrWhiteSpace(guildEvent.GuildEventName)
            || guildEvent.GuildEventName.Length > 80
            || !guildEventIds.Add(guildEvent.GuildEventId)
            || (guildEvent.Megaserver is not null && !IsPcMegaserver(guildEvent.Megaserver))
            || (guildEvent.StartsAt is not null && guildEvent.StartsAt < 1)
            || (guildEvent.EndsAt is not null && guildEvent.EndsAt < 1)
            || (guildEvent.StartsAt is not null && guildEvent.EndsAt is not null
                && guildEvent.EndsAt < guildEvent.StartsAt)
            || !IsAccessMode(guildEvent.AccessMode)
            || (guildEvent.AccessMode == "eso-members"
                && (string.IsNullOrWhiteSpace(guildEvent.EsoGuildName)
                    || guildEvent.EsoGuildName.Length > 80
                    || !IsPcMegaserver(guildEvent.AccessMegaserver)))
            || guildEvent.ZoneIds is null
            || guildEvent.ZoneIds.Any(zoneId => zoneId < 1))
            throw new InvalidDataException($"invalid guild event configuration: {guildEvent.GuildEventId}");
    }

    private static bool HasValidRecruitment(GuildConfig guild)
    {
        if (guild.RecruitmentMode == "off") return true;
        return !string.IsNullOrWhiteSpace(guild.RecruitmentCopy)
            && guild.RecruitmentCopy.Length <= 300
            && !string.IsNullOrWhiteSpace(guild.RecruitmentContact)
            && guild.RecruitmentContact.Length <= 120
            && ((guild.RecruitmentMode != "eso-guild" && guild.RecruitmentMode != "both")
                || (!string.IsNullOrWhiteSpace(guild.RecruitmentGuildLink)
                    && guild.RecruitmentGuildLink.Length <= 180
                    && Regex.IsMatch(
                        guild.RecruitmentGuildLink,
                        @"^\|H1:guild:\d{1,10}\|h[^|\r\n]{1,80}\|h$")))
            && (guild.RecruitmentMegaserver is null || IsPcMegaserver(guild.RecruitmentMegaserver));
    }

    private static bool HasValidScoreAndRun(int zoneId, long finalScore, long elapsedMs, int runGroupSize) =>
        zoneId >= 1
        && finalScore >= -100000000
        && finalScore <= 100000000
        && elapsedMs >= 1000
        && elapsedMs <= 24 * 60 * 60 * 1000
        && runGroupSize is >= 1 and <= 4;

    private static bool IsPcMegaserver(string? value) =>
        value is "NA Megaserver" or "EU Megaserver";

    private static bool IsAccessMode(string value) => value is "public" or "eso-members";

    private static bool IsRecruitmentMode(string value) =>
        value is "off" or "eso-guild" or "discord-server" or "both";

    private static void ValidateCapturedRecord(CapturedRecord record)
    {
        if (!HasValidScoreAndRun(record.ZoneId, record.FinalScore, record.ElapsedMs, record.RunGroupSize)
            || string.IsNullOrWhiteSpace(record.TeamName)
            || string.IsNullOrWhiteSpace(record.ZoneName)
            || string.IsNullOrWhiteSpace(record.EventId)
            || !IsPcMegaserver(record.Megaserver))
            throw new InvalidDataException(
                $"invalid captured record for zone {record.ZoneId}");
    }

    private static bool IsPublicIdentifier(string? value)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length > 64) return false;
        var first = value[0];
        if (!((first >= 'a' && first <= 'z') || (first >= '0' && first <= '9'))) return false;
        return value.All(character => character is >= 'a' and <= 'z'
            || character is >= '0' and <= '9' || character is '-' or '_');
    }
}
