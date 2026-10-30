using System.Text.Json.Serialization;

internal sealed record UploaderConfig(
    string ApiEndpoint,
    string? BearerToken,
    string SavedVariablesPath,
    string? AddOnsPath);

internal sealed record UploaderCredential(string BearerToken);

internal sealed record QueueItem(string QueueKey, long RequestId, object Payload);

internal sealed record DeliveryReceipt(string Status, long UpdatedAt);

internal sealed record CapturedRecordsResponse(
    int SchemaVersion,
    string Scope,
    CapturedRecord[] Records,
    CapturedRecord[]? PartyRecords,
    HighStandingRecord[]? HighStandings,
    RaceToBottomRecord[]? RaceToBottomRecords,
    int WorldPublicationDepth,
    int RaceToBottomPublicationDepth,
    GuildConfig[]? Guilds);

internal sealed record GuildConfig(
    string GuildId,
    string GuildName,
    bool RecordsEnabled,
    int RecordPublicationDepth,
    string AccessMode,
    string? EsoGuildName,
    string? Megaserver,
    string RecruitmentMode,
    string? RecruitmentCopy,
    string? RecruitmentContact,
    string? RecruitmentGuildLink,
    string? RecruitmentMegaserver,
    GuildEventConfig[] Events);

internal sealed record GuildEventConfig(
    string GuildEventId,
    string GuildEventName,
    string? Megaserver,
    long? StartsAt,
    long? EndsAt,
    int[] ZoneIds,
    string AccessMode,
    string? EsoGuildName,
    string? AccessMegaserver);

internal sealed record CapturedRecord(
    int ZoneId,
    string ZoneName,
    long FinalScore,
    long ElapsedMs,
    string TeamName,
    string[] TeamMembers,
    int RunGroupSize,
    int Deaths,
    int HmBossKills,
    int? ExpectedHardModes,
    bool? HmMeasurementSupported,
    bool TrifectaQualified,
    string AddonVersion,
    string Megaserver,
    string EventId,
    string SubmittedAt,
    string CapturedAt);

internal sealed record HighStandingRecord(
    string RecordClass,
    int Rank,
    int ZoneId,
    string ZoneName,
    long FinalScore,
    long ElapsedMs,
    string TeamName,
    string[] TeamMembers,
    int RunGroupSize,
    int Deaths,
    int HmBossKills,
    int? ExpectedHardModes,
    bool? HmMeasurementSupported,
    bool TrifectaQualified,
    string AddonVersion,
    string Megaserver,
    string EventId,
    string SubmittedAt);

internal sealed record RaceToBottomRecord(
    int Rank,
    int ZoneId,
    string ZoneName,
    long FinalScore,
    long ElapsedMs,
    string TeamName,
    string[] TeamMembers,
    int RunGroupSize,
    double? PartyAverageGroupSize,
    int Deaths,
    int HmBossKills,
    int? ExpectedHardModes,
    string RunOutcome,
    int AbandonmentPenalty,
    int AbandonedHardModeCount,
    int AbandonedHardModeScore,
    string AddonVersion,
    string Megaserver,
    string EventId,
    long FinalizedAt,
    string SubmittedAt);

internal sealed record LaunchSpec(string Executable, string[] Arguments);

[JsonSourceGenerationOptions(WriteIndented = true, PropertyNameCaseInsensitive = true)]
[JsonSerializable(typeof(UploaderConfig))]
[JsonSerializable(typeof(UploaderCredential))]
[JsonSerializable(typeof(string[]))]
[JsonSerializable(typeof(Dictionary<string, DeliveryReceipt>))]
[JsonSerializable(typeof(CapturedRecordsResponse))]
internal sealed partial class CompanionJsonContext : JsonSerializerContext;
