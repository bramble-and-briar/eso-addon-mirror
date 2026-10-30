using System.Net.Http.Headers;
using System.Text;

internal static partial class Program
{
    private const string ProductionApiEndpoint = "https://dungeon-scores-api.sagofett.workers.dev";
    private const string CompanionVersion = "0.5.15";
    private const string StartupRegistryPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string StartupValueName = "DungeonScoresCompanion";
    private const string SyncMutexName = @"Local\DungeonScoresCompanion.Sync.v1";
    private const string WatcherMutexName = @"Local\DungeonScoresCompanion.Watcher.v6";
    private static readonly TimeSpan RecordsRefreshInterval = TimeSpan.FromMinutes(5);

    [STAThread]
    public static int Main(string[] args)
    {
        if (args.Contains("--self-test", StringComparer.OrdinalIgnoreCase)) return SelfTest();
        if (args.Contains("--prepare-control", StringComparer.OrdinalIgnoreCase))
        {
            var config = LoadConfigurationAsync(args).GetAwaiter().GetResult();
            ValidateConfig(config);
            InstallRuntimeAsync(config).GetAwaiter().GetResult();
            Console.WriteLine(Path.Combine(InstalledRuntimeDirectory(), "DungeonScoresCompanion.dll"));
            return 0;
        }
        if (args.Contains("--control", StringComparer.OrdinalIgnoreCase))
            return OpenControlPanelAsync(args).GetAwaiter().GetResult();
        if (args.Contains("--install-startup", StringComparer.OrdinalIgnoreCase))
        {
            var config = LoadConfigurationAsync(args).GetAwaiter().GetResult();
            ValidateConfig(config);
            InstallRuntimeAsync(config).GetAwaiter().GetResult();
            SetStartupEnabled(true);
            Console.WriteLine("Dungeon Scores ESO-start monitoring enabled for this user account.");
            return 0;
        }
        if (args.Contains("--uninstall-startup", StringComparer.OrdinalIgnoreCase))
        {
            SetStartupEnabled(false);
            Console.WriteLine("Dungeon Scores ESO-start monitoring disabled for this user account.");
            return 0;
        }
        if (args.Contains("--watch-eso", StringComparer.OrdinalIgnoreCase)) return WatchForEso(args);
        if (args.Contains("--sync", StringComparer.OrdinalIgnoreCase)
            || args.Contains("--dry-run", StringComparer.OrdinalIgnoreCase)
            || ArgumentValue(args, "--config") is not null)
            return RunOnceSerialized(args, Console.Out, Console.Error);

        return RunOnceSerialized(["--sync"], Console.Out, Console.Error);
    }

    internal static int RunOnceSerialized(string[] args, TextWriter output, TextWriter error)
    {
        using var mutex = new Mutex(false, SyncMutexName);
        var acquired = false;
        try
        {
            try { acquired = mutex.WaitOne(TimeSpan.FromSeconds(1)); }
            catch (AbandonedMutexException) { acquired = true; }
            if (!acquired)
            {
                error.WriteLine("Another Dungeon Scores companion sync is already running.");
                return 5;
            }
            var result = RunOnceAsync(args, output, error).GetAwaiter().GetResult();
            if (!args.Contains("--dry-run", StringComparer.OrdinalIgnoreCase))
                WriteLastSyncStatus(result, null);
            return result;
        }
        finally
        {
            if (acquired) mutex.ReleaseMutex();
        }
    }

    private static async Task<int> RunOnceAsync(string[] args, TextWriter output, TextWriter error)
    {
        var dryRun = args.Contains("--dry-run", StringComparer.OrdinalIgnoreCase);
        UploaderConfig config;
        try
        {
            config = await LoadConfigurationAsync(args);
            ValidateConfig(config);
        }
        catch (Exception exception)
        {
            error.WriteLine($"Invalid configuration: {exception.Message}");
            return 2;
        }

        IReadOnlyList<QueueItem> queue;
        try
        {
            queue = LoadExplicitQueueCached(config.SavedVariablesPath);
        }
        catch (Exception exception)
        {
            error.WriteLine($"Could not read DungeonScores.lua: {exception.Message}");
            return 3;
        }

        var statePath = Path.Combine(StateDirectory(), "submitted.json");
        var deliveryStatePath = Path.Combine(StateDirectory(), "delivery-status.json");
        var submitted = await LoadSubmittedAsync(statePath);
        var deliveryReceipts = await LoadDeliveryReceiptsAsync(deliveryStatePath);
        var pending = queue.Where(item => !submitted.Contains(item.QueueKey)).ToArray();
        output.WriteLine($"Explicitly queued: {queue.Count}; pending: {pending.Length}.");
        var addOnsPath = ResolveAddOnsPath(config);
        if (dryRun)
        {
            foreach (var item in pending) output.WriteLine($"DRY RUN request {item.RequestId}: {item.QueueKey}");
            output.WriteLine($"DRY RUN records addon: {Path.Combine(addOnsPath, "DungeonScoresRecords")}");
            return 0;
        }

        var stateDirectory = Path.GetDirectoryName(statePath)!;
        using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(20) };
        var endpoint = new Uri(new Uri(config.ApiEndpoint.TrimEnd('/') + "/"), "v1/runs");
        var failures = 0;
        if (pending.Length > 0)
        {
            try
            {
                var bearerToken = await LoadOrCreateCredentialAsync(stateDirectory, config.BearerToken, output);
                client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", bearerToken);
            }
            catch (Exception exception)
            {
                foreach (var item in pending) SetDeliveryReceipt(deliveryReceipts, item, "retrying");
                await WriteDeliveryReceiptsAsync(deliveryStatePath, addOnsPath,
                    queue, submitted, deliveryReceipts);
                error.WriteLine($"Could not initialize the local publisher identity: {exception.Message}");
                return 2;
            }

            foreach (var item in pending)
            {
                try
                {
                    var json = SerializePayload(item.Payload);
                    using var response = await client.PostAsync(endpoint,
                        new StringContent(json, Encoding.UTF8, "application/json"));
                    var responseText = await response.Content.ReadAsStringAsync();
                    if (response.IsSuccessStatusCode)
                    {
                        submitted.Add(item.QueueKey);
                        await SaveSubmittedAsync(statePath, submitted);
                        SetDeliveryReceipt(deliveryReceipts, item, "delivered");
                        output.WriteLine($"Request {item.RequestId}: {SubmissionSummary(responseText)}");
                    }
                    else if ((int)response.StatusCode == 409
                        && IsTerminalSubmissionRejection(responseText, "team-name-reserved"))
                    {
                        submitted.Add(item.QueueKey);
                        await SaveSubmittedAsync(statePath, submitted);
                        SetDeliveryReceipt(deliveryReceipts, item, "rejected");
                        failures++;
                        error.WriteLine($"Request {item.RequestId}: not submitted — that team name is globally reserved by a different exact @accountname roster. Choose another team name and queue the score again.");
                    }
                    else
                    {
                        failures++;
                        SetDeliveryReceipt(deliveryReceipts, item, "retrying");
                        error.WriteLine($"Request {item.RequestId}: HTTP {(int)response.StatusCode} {SafeResponse(responseText)}");
                    }
                }
                catch (Exception exception)
                {
                    failures++;
                    SetDeliveryReceipt(deliveryReceipts, item, "retrying");
                    error.WriteLine($"Request {item.RequestId}: {exception.Message}");
                }
            }
        }

        try
        {
            await WriteDeliveryReceiptsAsync(deliveryStatePath, addOnsPath,
                queue, submitted, deliveryReceipts);
        }
        catch (Exception exception)
        {
            failures++;
            error.WriteLine($"Could not update local delivery status: {exception.Message}");
        }

        try
        {
            await RefreshRecordsAddonAsync(client, config.ApiEndpoint, addOnsPath, output);
        }
        catch (Exception exception)
        {
            failures++;
            error.WriteLine($"Could not refresh DungeonScoresRecords: {exception.Message}");
        }
        return failures == 0 ? 0 : 4;
    }
}
