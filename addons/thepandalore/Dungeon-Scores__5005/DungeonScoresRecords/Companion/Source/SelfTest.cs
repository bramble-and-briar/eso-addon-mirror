internal static partial class Program
{
    private static int SelfTest()
    {
        const string sample = "DungeonScoresSavedVariables = {[\"Default\"]={[\"@Uploader\"]={[\"$AccountWide\"]={[\"history\"]={[1]={[\"finalScore\"]=999999,},},[\"publicationQueue\"]={[1]={[\"queueKey\"]=\"team|na|5|283|100\",[\"requestId\"]=7,[\"payload\"]={[\"schemaVersion\"]=1,[\"teamName\"]=\"Team\",[\"teamMembers\"]={[1]=\"@Uploader\",[2]=\"@Ally\",},[\"finalScore\"]=61000,},},},},},},}";
        var path = Path.GetTempFileName();
        var addOnsPath = Path.Combine(Path.GetTempPath(), "DungeonScoresUploader-" + Guid.NewGuid().ToString("N"));
        var runtimeStatePath = Path.Combine(Path.GetTempPath(), "DungeonScoresRuntime-" + Guid.NewGuid().ToString("N"));
        try
        {
            File.WriteAllText(path, sample);
            TestPublicationQueue(path);
            TestSubmissionResponses();
            TestWatcherPolicy();
            TestPortableStartup(path, addOnsPath, runtimeStatePath);
            TestControlPanelProtocol(path, addOnsPath);
            TestRecordsAddon(addOnsPath);
            TestDeliveryStatus(path, addOnsPath, runtimeStatePath);
            Console.WriteLine("PASS: uploader reads only explicit publicationQueue records and writes the optional records addon.");
            return 0;
        }
        finally
        {
            File.Delete(path);
            if (Directory.Exists(addOnsPath)) Directory.Delete(addOnsPath, true);
            if (Directory.Exists(runtimeStatePath)) Directory.Delete(runtimeStatePath, true);
        }
    }

    private static void TestSubmissionResponses()
    {
        const string guildImprovement = "{\"guildRecord\":{\"requested\":true,\"accepted\":true,\"improved\":true,\"guildName\":\"Vinedusk\"}}";
        if (SubmissionSummary(guildImprovement)
            != "global record handled; new guild record routed to Vinedusk.")
            throw new Exception("guild submission summary changed");

        const string noGuildRoute = "{\"guildRecord\":{\"requested\":false},\"guildEvent\":{\"requested\":false}}";
        if (SubmissionSummary(noGuildRoute)
            != "global record handled; no guild route selected.")
            throw new Exception("unrouted submission summary changed");

        const string reservedName = "{\"error\":\"team-name-reserved\"}";
        if (!IsTerminalSubmissionRejection(reservedName, "team-name-reserved"))
            throw new Exception("terminal submission rejection parsing changed");
    }

    private static void TestPublicationQueue(string path)
    {
        var items = LoadExplicitQueue(path);
        if (items.Count != 1 || items[0].RequestId != 7)
            throw new Exception("explicit queue was not parsed");
        var json = SerializePayload(items[0].Payload);
        if (!json.Contains("\"teamMembers\":[\"@Uploader\",\"@Ally\"]", StringComparison.Ordinal))
            throw new Exception("team roster array was not preserved");
        if (json.Contains("999999", StringComparison.Ordinal))
            throw new Exception("history leaked into upload payload");
        var legacySample = File.ReadAllText(path).Replace("[\"schemaVersion\"]=1,",
            "[\"schemaVersion\"]=1,[\"scoringEpoch\"]=6,", StringComparison.Ordinal);
        File.WriteAllText(path, legacySample);
        var legacyJson = SerializePayload(LoadExplicitQueue(path)[0].Payload);
        if (legacyJson.Contains("scoringEpoch", StringComparison.Ordinal)
            || File.ReadAllText(path) != legacySample)
            throw new Exception("legacy epoch stripping changed the SavedVariables file or leaked into upload");
        var cached = LoadExplicitQueueCached(path);
        if (!ReferenceEquals(cached, LoadExplicitQueueCached(path)))
            throw new Exception("unchanged SavedVariables queue was reparsed");
        var changedSample = legacySample.Replace("61000", "61001", StringComparison.Ordinal);
        File.WriteAllText(path, changedSample);
        var changedQueue = LoadExplicitQueueCached(path);
        if (ReferenceEquals(cached, changedQueue)
            || !SerializePayload(changedQueue[0].Payload).Contains("61001", StringComparison.Ordinal))
            throw new Exception("changed SavedVariables queue reused stale data");
        File.WriteAllText(path, legacySample);
        var credential = CreateBearerToken();
        if (!IsValidBearerToken(credential))
            throw new Exception("publisher credential generation failed");
    }

    private static void TestWatcherPolicy()
    {
        var watcherNow = DateTimeOffset.UtcNow;
        var unchangedWrite = DateTime.UtcNow;
        if (ShouldWatcherSync(true, true, unchangedWrite, unchangedWrite,
                watcherNow.Add(RecordsRefreshInterval).AddSeconds(-1), watcherNow))
            throw new Exception("watcher refreshed public records too early");
        if (!ShouldWatcherSync(true, true, unchangedWrite, unchangedWrite,
                watcherNow.Add(RecordsRefreshInterval), watcherNow))
            throw new Exception("watcher did not refresh public records on schedule");
        if (!ShouldWatcherSync(true, false, unchangedWrite, unchangedWrite, watcherNow, watcherNow)
            || !ShouldWatcherSync(true, true, unchangedWrite.AddSeconds(1), unchangedWrite, watcherNow, watcherNow)
            || !ShouldWatcherSync(false, true, unchangedWrite, unchangedWrite, watcherNow, watcherNow))
            throw new Exception("watcher lifecycle synchronization regressed");
    }

    private static void TestControlPanelProtocol(string savedVariablesPath, string addOnsPath)
    {
        using var listener = new System.Net.Sockets.TcpListener(System.Net.IPAddress.Loopback, 0);
        listener.Start();
        var port = ((System.Net.IPEndPoint)listener.LocalEndpoint).Port;
        var config = new UploaderConfig(ProductionApiEndpoint, null, savedVariablesPath, addOnsPath);
        var server = Task.Run(async () =>
        {
            for (var index = 0; index < 4; index++)
            {
                var client = await listener.AcceptTcpClientAsync();
                await HandleControlClientAsync(client, "test-token", port, config,
                    () => { }, () => { });
            }
        });
        using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(4) };
        var root = $"http://127.0.0.1:{port}/";
        var page = http.GetAsync(root + "test-token/").GetAwaiter().GetResult();
        if (page.StatusCode != System.Net.HttpStatusCode.OK
            || !(page.Content.ReadAsStringAsync().GetAwaiter().GetResult()).Contains("Start monitoring", StringComparison.Ordinal))
            throw new Exception("local control page was unavailable");
        var wrongToken = http.GetAsync(root + "wrong/").GetAwaiter().GetResult();
        if (wrongToken.StatusCode != System.Net.HttpStatusCode.NotFound)
            throw new Exception("local control page accepted the wrong token");
        using var rejected = new HttpRequestMessage(HttpMethod.Post, root + "test-token/stop")
            { Content = new StringContent(string.Empty) };
        if (http.Send(rejected).StatusCode != System.Net.HttpStatusCode.Forbidden)
            throw new Exception("local control action accepted a missing origin");
        using var unknown = new HttpRequestMessage(HttpMethod.Post, root + "test-token/unknown")
            { Content = new StringContent(string.Empty) };
        unknown.Headers.TryAddWithoutValidation("Origin", $"http://127.0.0.1:{port}");
        var unknownResponse = http.Send(unknown);
        if (unknownResponse.StatusCode != System.Net.HttpStatusCode.Conflict
            || !(unknownResponse.Content.ReadAsStringAsync().GetAwaiter().GetResult()).Contains("Unknown control", StringComparison.Ordinal))
            throw new Exception("local control rejected-action response was incorrect");
        server.GetAwaiter().GetResult();
    }

    private static void TestPortableStartup(string path, string addOnsPath, string runtimeStatePath)
    {
        var watcherConfig = new UploaderConfig(ProductionApiEndpoint, null, path, addOnsPath);
        InstallRuntimeAsync(watcherConfig, runtimeStatePath).GetAwaiter().GetResult();
        var watcherLaunch = InstalledWatcherLaunchSpec(runtimeStatePath);
        if (!watcherLaunch.Arguments.Contains("--watch-eso", StringComparer.Ordinal)
            || !watcherLaunch.Arguments.Contains("--config", StringComparer.Ordinal)
            || !watcherLaunch.Arguments.Contains(InstalledConfigPath(runtimeStatePath), StringComparer.Ordinal)
            || (string.Equals(Path.GetFileNameWithoutExtension(watcherLaunch.Executable), "dotnet", StringComparison.OrdinalIgnoreCase)
                && !watcherLaunch.Arguments.Any(argument => argument.EndsWith("DungeonScoresCompanion.dll", StringComparison.OrdinalIgnoreCase)))
            || watcherLaunch.Arguments.Any(argument => argument.StartsWith(AppContext.BaseDirectory, StringComparison.OrdinalIgnoreCase))
            || !WindowsWatcherScript(watcherLaunch).Contains("DungeonScoresCompanion.dll", StringComparison.OrdinalIgnoreCase)
            || !MacLaunchAgent(watcherLaunch).Contains("DungeonScoresCompanion.dll", StringComparison.OrdinalIgnoreCase)
            || !LinuxAutostart(watcherLaunch).Contains("DungeonScoresCompanion.dll", StringComparison.OrdinalIgnoreCase))
            throw new Exception("portable startup command generation failed");
    }

    private static void TestRecordsAddon(string addOnsPath)
    {
        var snapshot = CreateTestSnapshot();
        var companionDirectory = Path.Combine(addOnsPath, "DungeonScoresRecords", "Companion");
        Directory.CreateDirectory(companionDirectory);
        var companionSentinel = Path.Combine(companionDirectory, "sentinel.txt");
        File.WriteAllText(companionSentinel, "preserve");
        WriteRecordsAddonAsync(addOnsPath, snapshot).GetAwaiter().GetResult();
        var recordsLua = File.ReadAllText(Path.Combine(addOnsPath, "DungeonScoresRecords", "Records.lua"));
        var recordsManifest = File.ReadAllText(Path.Combine(addOnsPath, "DungeonScoresRecords", "DungeonScoresRecords.txt"));
        if (recordsLua.Contains("scoringEpoch", StringComparison.Ordinal)
            || !recordsLua.Contains("DungeonScoresRecords = DungeonScoresRecords or {}", StringComparison.Ordinal)
            || !recordsLua.Contains("DungeonScoresRecords.Data = {", StringComparison.Ordinal)
            || recordsLua.Contains("DungeonScoresRecordsData =", StringComparison.Ordinal)
            || !recordsLua.Contains("schemaVersion = 2", StringComparison.Ordinal)
            || !recordsLua.Contains("[283]", StringComparison.Ordinal)
            || !recordsLua.Contains("partyRecords = {", StringComparison.Ordinal)
            || !recordsLua.Contains("highStandings = {", StringComparison.Ordinal)
            || !recordsLua.Contains("raceToBottomRecords = {", StringComparison.Ordinal)
            || !recordsLua.Contains("runOutcome = \"abandoned\"", StringComparison.Ordinal)
            || !recordsLua.Contains("recordPublicationDepth = 10", StringComparison.Ordinal)
            || !recordsLua.Contains("[4] = {", StringComparison.Ordinal)
            || !recordsLua.Contains("EU Megaserver", StringComparison.Ordinal)
            || !recordsLua.Contains("hmMeasurementSupported = true", StringComparison.Ordinal)
            || !recordsLua.Contains("vinedusk-autumn-2026", StringComparison.Ordinal)
            || !recordsLua.Contains("Autumn Sprint", StringComparison.Ordinal)
            || !recordsLua.Contains("recordsEnabled = true", StringComparison.Ordinal)
            || !recordsLua.Contains("recruitmentMode = \"both\"", StringComparison.Ordinal)
            || !recordsLua.Contains("accessMode = \"public\"", StringComparison.Ordinal)
            || !recordsLua.Contains("Team \\\"One\\\"", StringComparison.Ordinal))
            throw new Exception("records addon output was incomplete or not Lua-escaped");
        if (!recordsManifest.Contains("## Title: Dungeon Scores Records", StringComparison.Ordinal))
            throw new Exception("records addon manifest was not generated");
        if (!recordsManifest.Contains("Delivery.lua", StringComparison.Ordinal))
            throw new Exception("delivery receipt file was not loaded by the addon manifest");
        if (!File.Exists(companionSentinel))
            throw new Exception("records refresh removed the bundled companion directory");
        var normalizedLua = recordsLua.Replace("\r\n", "\n", StringComparison.Ordinal);
        if (!normalizedLua.Contains("records = {\n        [283] = {", StringComparison.Ordinal)
            || !normalizedLua.Contains("partyRecords = {\n        [283] = {\n            [4] = {", StringComparison.Ordinal))
            throw new Exception("schema-2 records retained a partition wrapper");
        ExpectInvalidSnapshot(snapshot with { SchemaVersion = 1 });
        ExpectInvalidSnapshot(snapshot with { Records = [snapshot.Records[0], snapshot.Records[0]] });
        ExpectInvalidSnapshot(snapshot with { PartyRecords = [snapshot.PartyRecords![0], snapshot.PartyRecords[0]] });
    }

    private static void TestDeliveryStatus(string savedVariablesPath,
        string addOnsPath, string runtimeStatePath)
    {
        var queue = LoadExplicitQueue(savedVariablesPath);
        var statePath = Path.Combine(runtimeStatePath, "delivery-status.json");
        var submitted = new HashSet<string>(StringComparer.Ordinal) { queue[0].QueueKey };
        var receipts = new Dictionary<string, DeliveryReceipt>(StringComparer.Ordinal);
        WriteDeliveryReceiptsAsync(statePath, addOnsPath, queue, submitted, receipts)
            .GetAwaiter().GetResult();
        var saved = LoadDeliveryReceiptsAsync(statePath).GetAwaiter().GetResult();
        if (!saved.TryGetValue(queue[0].QueueKey, out var oldReceipt)
            || oldReceipt.Status != "outcome-unknown")
            throw new Exception("legacy handled request was falsely reported as delivered");

        SetDeliveryReceipt(saved, queue[0], "delivered");
        WriteDeliveryReceiptsAsync(statePath, addOnsPath, queue, submitted, saved)
            .GetAwaiter().GetResult();
        var lua = File.ReadAllText(Path.Combine(addOnsPath, "DungeonScoresRecords", "Delivery.lua"));
        if (!lua.Contains("DungeonScoresRecords.Delivery = {", StringComparison.Ordinal)
            || lua.Contains("DungeonScoresDeliveryData =", StringComparison.Ordinal)
            || !lua.Contains("schemaVersion = 1", StringComparison.Ordinal)
            || !lua.Contains("status = \"delivered\"", StringComparison.Ordinal)
            || !lua.Contains("team|na|5|283|100", StringComparison.Ordinal))
            throw new Exception("delivery status was not written to the in-game receipt file");
    }

    private static void ExpectInvalidSnapshot(CapturedRecordsResponse snapshot)
    {
        try { ValidateCapturedRecords(snapshot); }
        catch (InvalidDataException) { return; }
        throw new Exception("invalid or duplicate record snapshot was accepted");
    }

    private static CapturedRecordsResponse CreateTestSnapshot() => new(
        2,
        "PC NA + PC EU",
        [
            new CapturedRecord(283, "Fungal Grotto I", 61000, 300000,
                "Team \"One\"", ["@Uploader", "@Ally"], 4, 0, 1, 1, true, true,
                CompanionVersion, "EU Megaserver", "abc123", "2026-10-18", "2026-10-18"),
        ],
        [
            new CapturedRecord(283, "Fungal Grotto I", 61000, 300000,
                "Team \"One\"", ["@Uploader", "@Ally"], 4, 0, 1, 1, true, true,
                CompanionVersion, "EU Megaserver", "abc123", "2026-10-18", "2026-10-18"),
        ],
        [
            new HighStandingRecord("4-player", 1, 283, "Fungal Grotto I",
                61000, 300000, "Team \"One\"", ["@Uploader", "@Ally"],
                4, 0, 1, 1, true, true, CompanionVersion, "EU Megaserver",
                "abc123", "2026-10-18"),
        ],
        [
            new RaceToBottomRecord(1, 283, "Fungal Grotto I", -12000,
                900000, "Team \"One\"", ["@Uploader", "@Ally"], 4, 4,
                18, 0, 1, "abandoned", -10000, 0, 0, CompanionVersion,
                "EU Megaserver", "def456", 1792000010, "2026-10-18"),
            new RaceToBottomRecord(1, 284, "Fungal Grotto II", -8000,
                720000, "Duo Team", ["@Uploader", "@Ally"], 2, 2,
                12, 0, 1, "abandoned", -10000, 0, 0, CompanionVersion,
                "NA Megaserver", "ghi789", 1792000020, "2026-10-18"),
        ],
        10,
        10,
        [
            new GuildConfig("vinedusk", "Vinedusk", true, 10, "eso-members", "Vinedusk", "NA Megaserver",
                "both", "A social PvE guild and Discord community.", "@Recruiter",
                "|H1:guild:773965|hVinedusk|h", "NA Megaserver",
            [
                new GuildEventConfig("vinedusk-autumn-2026", "Autumn Sprint",
                    "EU Megaserver", 1792000000, 1792600000, [283, 284],
                    "public", null, null),
            ]),
        ]);
}
