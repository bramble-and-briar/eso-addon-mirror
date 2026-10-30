using System.Diagnostics;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Win32;

internal static partial class Program
{
    internal static bool IsStartupEnabled()
    {
        var launch = InstalledWatcherLaunchSpec();
        if (OperatingSystem.IsWindows())
        {
            using var key = Registry.CurrentUser.OpenSubKey(StartupRegistryPath, false);
            var value = key?.GetValue(StartupValueName) as string;
            var launcherPath = WindowsWatcherLauncherPath();
            return string.Equals(value, WindowsStartupCommand(), StringComparison.OrdinalIgnoreCase)
                && File.Exists(launcherPath)
                && string.Equals(File.ReadAllText(launcherPath), WindowsWatcherScript(launch), StringComparison.Ordinal);
        }
        var path = StartupDefinitionPath();
        if (!File.Exists(path)) return false;
        var expected = OperatingSystem.IsMacOS()
            ? MacLaunchAgent(launch)
            : LinuxAutostart(launch);
        return string.Equals(File.ReadAllText(path), expected, StringComparison.Ordinal);
    }

    internal static void SetStartupEnabled(bool enabled)
    {
        SetStartupRegistration(enabled);
        if (enabled) StartWatcher(InstalledWatcherLaunchSpec());
        else StopWatcher();
    }

    internal static bool HasStartupRegistration()
    {
        if (OperatingSystem.IsWindows())
        {
            using var key = Registry.CurrentUser.OpenSubKey(StartupRegistryPath, false);
            return !string.IsNullOrWhiteSpace(key?.GetValue(StartupValueName) as string);
        }
        return File.Exists(StartupDefinitionPath());
    }

    internal static void SetStartupRegistration(bool enabled)
    {
        if (OperatingSystem.IsWindows())
        {
            var launcherPath = WindowsWatcherLauncherPath();
            var legacyLauncherPath = WindowsLegacyWatcherLauncherPath();
            using var key = Registry.CurrentUser.CreateSubKey(StartupRegistryPath, true)
                ?? throw new InvalidOperationException("the Windows startup registry could not be opened");
            if (!enabled)
            {
                key.DeleteValue(StartupValueName, false);
                if (File.Exists(launcherPath)) File.Delete(launcherPath);
                if (File.Exists(legacyLauncherPath)) File.Delete(legacyLauncherPath);
                return;
            }
            var launch = InstalledWatcherLaunchSpec();
            Directory.CreateDirectory(Path.GetDirectoryName(launcherPath)!);
            File.WriteAllText(launcherPath, WindowsWatcherScript(launch), new UTF8Encoding(false));
            if (File.Exists(legacyLauncherPath)) File.Delete(legacyLauncherPath);
            key.SetValue(StartupValueName, WindowsStartupCommand(), RegistryValueKind.String);
            return;
        }

        var definitionPath = StartupDefinitionPath();
        if (!enabled)
        {
            if (File.Exists(definitionPath)) File.Delete(definitionPath);
            return;
        }
        var nonWindowsLaunch = InstalledWatcherLaunchSpec();
        Directory.CreateDirectory(Path.GetDirectoryName(definitionPath)!);
        var definition = OperatingSystem.IsMacOS()
            ? MacLaunchAgent(nonWindowsLaunch)
            : LinuxAutostart(nonWindowsLaunch);
        File.WriteAllText(definitionPath, definition, new UTF8Encoding(false));
    }

    private static string WindowsStartupCommand() =>
        $"wscript.exe \"{WindowsWatcherLauncherPath()}\"";

    private static string WindowsWatcherLauncherPath() => Path.Combine(
        StateDirectory(),
        "watch-eso-dotnet.vbs");

    private static string WindowsLegacyWatcherLauncherPath() => Path.Combine(
        StateDirectory(),
        "watch-eso.vbs");

    private static string StateDirectory() => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "DungeonScoresUploader");

    private static string InstalledRuntimeDirectory(string? stateDirectory = null) => Path.Combine(
        stateDirectory ?? StateDirectory(),
        "runtime",
        CompanionVersion);

    private static string InstalledConfigPath(string? stateDirectory = null) => Path.Combine(
        InstalledRuntimeDirectory(stateDirectory),
        "watcher-config.json");

    private static bool IsInstalledRuntimeProcess()
    {
        var current = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "DungeonScoresCompanion.dll"));
        var installed = Path.GetFullPath(Path.Combine(InstalledRuntimeDirectory(), "DungeonScoresCompanion.dll"));
        return string.Equals(current, installed,
            OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal);
    }

    private static async Task InstallRuntimeAsync(
        UploaderConfig config,
        string? stateDirectory = null,
        string? sourceDirectory = null)
    {
        var source = Path.GetFullPath(sourceDirectory ?? AppContext.BaseDirectory);
        var runtime = InstalledRuntimeDirectory(stateDirectory);
        Directory.CreateDirectory(runtime);
        foreach (var name in new[]
                 {
                     "DungeonScoresCompanion.dll",
                     "DungeonScoresCompanion.deps.json",
                     "DungeonScoresCompanion.runtimeconfig.json",
                 })
        {
            var sourcePath = Path.Combine(source, name);
            if (!File.Exists(sourcePath))
                throw new FileNotFoundException($"required companion runtime file was not found: {name}", sourcePath);
            var destinationPath = Path.Combine(runtime, name);
            if (!FilesHaveSameContent(sourcePath, destinationPath))
                File.Copy(sourcePath, destinationPath, true);
        }

        var json = System.Text.Json.JsonSerializer.Serialize(
            config,
            CompanionJsonContext.Default.UploaderConfig);
        await AtomicWriteAsync(InstalledConfigPath(stateDirectory), json);
        await AtomicWriteAsync(RuntimeVersionPath(stateDirectory), CompanionVersion);
    }

    private static string RuntimeVersionPath(string? stateDirectory = null) => Path.Combine(
        stateDirectory ?? StateDirectory(), "runtime-version.txt");

    private static string StopRequestPath() => Path.Combine(StateDirectory(), "watcher-stop.txt");

    private static bool IsCurrentRuntimeInstalled() => File.Exists(RuntimeVersionPath())
        && string.Equals(File.ReadAllText(RuntimeVersionPath()), CompanionVersion, StringComparison.Ordinal);

    private static bool FilesHaveSameContent(string first, string second)
    {
        if (!File.Exists(second)) return false;
        var firstInfo = new FileInfo(first);
        var secondInfo = new FileInfo(second);
        if (firstInfo.Length != secondInfo.Length) return false;
        using var firstStream = File.OpenRead(first);
        using var secondStream = File.OpenRead(second);
        return SHA256.HashData(firstStream).SequenceEqual(SHA256.HashData(secondStream));
    }

    private static LaunchSpec InstalledWatcherLaunchSpec(string? stateDirectory = null)
    {
        var executable = Environment.ProcessPath
            ?? throw new InvalidOperationException("the companion host path is unavailable");
        if (!string.Equals(Path.GetFileNameWithoutExtension(executable), "dotnet", StringComparison.OrdinalIgnoreCase))
            executable = OperatingSystem.IsWindows() ? "dotnet.exe" : "dotnet";
        return new LaunchSpec(executable,
        [
            Path.Combine(InstalledRuntimeDirectory(stateDirectory), "DungeonScoresCompanion.dll"),
            "--watch-eso",
            "--config",
            InstalledConfigPath(stateDirectory),
        ]);
    }

    private static string WindowsWatcherScript(LaunchSpec launch)
    {
        var command = string.Join(" ", new[] { launch.Executable }.Concat(launch.Arguments).Select(WindowsQuote));
        return $"CreateObject(\"Wscript.Shell\").Run \"{command.Replace("\"", "\"\"")}\", 0, False\r\n";
    }

    private static string WindowsQuote(string value) =>
        "\"" + value.Replace("\"", "\\\"") + "\"";

    private static string WatcherReadyPath() => Path.Combine(StateDirectory(), "watcher-ready.txt");

    private static bool IsCurrentWatcherReady()
    {
        if (!File.Exists(WatcherReadyPath())) return false;
        var parts = File.ReadAllText(WatcherReadyPath()).Split('|');
        if (parts.Length != 2 || parts[0] != CompanionVersion
            || !int.TryParse(parts[1], out var pid)) return false;
        try
        {
            using var process = Process.GetProcessById(pid);
            return !process.HasExited;
        }
        catch (ArgumentException) { return false; }
        catch (InvalidOperationException) { return false; }
    }

    internal static bool IsWatcherRunning()
    {
        using var mutex = new Mutex(false, WatcherMutexName);
        try
        {
            if (!mutex.WaitOne(0)) return true;
            mutex.ReleaseMutex();
            return false;
        }
        catch (AbandonedMutexException)
        {
            mutex.ReleaseMutex();
            return false;
        }
    }

    internal static bool StopWatcher()
    {
        if (!IsWatcherRunning()) return true;
        var parts = File.Exists(WatcherReadyPath())
            ? File.ReadAllText(WatcherReadyPath()).Split('|') : [];
        if (parts.Length == 2 && parts[0] == CompanionVersion)
            File.WriteAllText(StopRequestPath(), parts[1], new UTF8Encoding(false));
        var deadline = DateTime.UtcNow.AddSeconds(3);
        while (IsWatcherRunning() && DateTime.UtcNow < deadline) Thread.Sleep(150);
        return !IsWatcherRunning();
    }

    private static bool IsStopRequestedForCurrentProcess() => File.Exists(StopRequestPath())
        && string.Equals(File.ReadAllText(StopRequestPath()),
            Environment.ProcessId.ToString(CultureInfo.InvariantCulture), StringComparison.Ordinal);

    private static void StartWatcher(LaunchSpec launch)
    {
        if (IsCurrentWatcherReady() && IsWatcherRunning()) return;
        if (File.Exists(StopRequestPath())) File.Delete(StopRequestPath());
        var startInfo = new ProcessStartInfo(launch.Executable)
        {
            UseShellExecute = false,
            CreateNoWindow = true,
        };
        foreach (var argument in launch.Arguments) startInfo.ArgumentList.Add(argument);
        using var process = Process.Start(startInfo)
            ?? throw new InvalidOperationException("ESO-start monitor could not be launched");
        var expectedReady = $"{CompanionVersion}|{process.Id}";
        var deadline = DateTime.UtcNow.AddSeconds(20);
        while (DateTime.UtcNow < deadline)
        {
            if (process.HasExited)
                throw new InvalidOperationException(
                    $"ESO-start monitor exited before it was ready (code {process.ExitCode}); see last-watcher-status.txt");
            try
            {
                if (File.Exists(WatcherReadyPath())
                    && string.Equals(File.ReadAllText(WatcherReadyPath()), expectedReady, StringComparison.Ordinal))
                    return;
            }
            catch (IOException)
            {
                // The watcher may still be writing the readiness marker.
            }
            Thread.Sleep(200);
        }
        throw new TimeoutException("ESO-start monitor did not become ready within 20 seconds");
    }

    private static string StartupDefinitionPath()
    {
        var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        if (OperatingSystem.IsMacOS())
            return Path.Combine(home, "Library", "LaunchAgents", "com.dungeonscores.companion.plist");
        if (OperatingSystem.IsLinux())
        {
            var configHome = Environment.GetEnvironmentVariable("XDG_CONFIG_HOME");
            if (string.IsNullOrWhiteSpace(configHome)) configHome = Path.Combine(home, ".config");
            return Path.Combine(configHome, "autostart", "dungeon-scores-companion.desktop");
        }
        throw new PlatformNotSupportedException("ESO-start monitoring supports Windows, macOS, and Linux");
    }

    private static string MacLaunchAgent(LaunchSpec launch) => $"""
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key><string>com.dungeonscores.companion</string>
          <key>ProgramArguments</key>
          <array>{string.Join("", new[] { launch.Executable }.Concat(launch.Arguments).Select(value => $"<string>{XmlEscape(value)}</string>"))}</array>
          <key>RunAtLoad</key><true/>
        </dict>
        </plist>
        """;

    private static string LinuxAutostart(LaunchSpec launch) => $"""
        [Desktop Entry]
        Type=Application
        Name=Dungeon Scores Companion
        Comment=Sync Dungeon Scores records when ESO runs
        Exec={string.Join(" ", new[] { launch.Executable }.Concat(launch.Arguments).Select(DesktopExecQuote))}
        Terminal=false
        NoDisplay=true
        X-GNOME-Autostart-enabled=true
        """;

    private static string DesktopExecQuote(string value) =>
        "\"" + value.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("`", "\\`").Replace("$", "\\$") + "\"";

    private static string XmlEscape(string value) => value
        .Replace("&", "&amp;")
        .Replace("<", "&lt;")
        .Replace(">", "&gt;")
        .Replace("\"", "&quot;")
        .Replace("'", "&apos;");

    private static int WatchForEso(string[] args)
    {
        using var watcherMutex = new Mutex(false, WatcherMutexName);
        var acquired = false;
        try
        {
            try { acquired = watcherMutex.WaitOne(TimeSpan.FromSeconds(15)); }
            catch (AbandonedMutexException) { acquired = true; }
            if (!acquired)
            {
                WriteWatcherStatus("ESO-start monitoring stopped: prior watcher did not hand off within 15 seconds");
                return 5;
            }

            UploaderConfig config;
            try
            {
                config = LoadConfigurationAsync(args).GetAwaiter().GetResult();
                ValidateConfig(config);
                if (!IsCurrentRuntimeInstalled())
                    throw new InvalidOperationException("the installed companion version has changed");
                Directory.CreateDirectory(StateDirectory());
                File.WriteAllText(WatcherReadyPath(), $"{CompanionVersion}|{Environment.ProcessId}",
                    new UTF8Encoding(false));
            }
            catch (Exception exception)
            {
                WriteWatcherStatus("ESO-start monitoring stopped: " + exception.Message);
                return 2;
            }

            var wasRunning = false;
            var lastSyncUtc = DateTimeOffset.UtcNow;
            var lastSavedVariablesWrite = GetLastWriteUtc(config.SavedVariablesPath);
            while (IsCurrentRuntimeInstalled() && !IsStopRequestedForCurrentProcess())
            {
                var isRunning = IsEsoRunning();
                var currentWrite = GetLastWriteUtc(config.SavedVariablesPath);
                var nowUtc = DateTimeOffset.UtcNow;
                var shouldSync = ShouldWatcherSync(
                    isRunning,
                    wasRunning,
                    currentWrite,
                    lastSavedVariablesWrite,
                    nowUtc,
                    lastSyncUtc);

                if (shouldSync)
                {
                    Thread.Sleep(1500);
                    var output = new StringWriter(CultureInfo.InvariantCulture);
                    var errors = new StringWriter(CultureInfo.InvariantCulture);
                    var configPath = ArgumentValue(args, "--config");
                    var syncArguments = configPath is null
                        ? new[] { "--sync" }
                        : new[] { "--sync", "--config", configPath };
                    var result = RunOnceSerialized(syncArguments, output, errors);
                    var summary = (output.ToString() + errors.ToString()).Trim();
                    WriteLastSyncStatus(result, summary);
                    WriteWatcherStatus($"{DateTimeOffset.Now:u} result {result}\n{summary}");
                    lastSyncUtc = DateTimeOffset.UtcNow;
                    currentWrite = GetLastWriteUtc(config.SavedVariablesPath);
                }

                lastSavedVariablesWrite = currentWrite;
                wasRunning = isRunning;
                Thread.Sleep(3000);
            }
            return 0;
        }
        finally
        {
            if (acquired) watcherMutex.ReleaseMutex();
        }
    }

    internal static bool ShouldWatcherSync(
        bool isRunning,
        bool wasRunning,
        DateTime? currentSavedVariablesWrite,
        DateTime? lastSavedVariablesWrite,
        DateTimeOffset nowUtc,
        DateTimeOffset lastSyncUtc)
    {
        if (isRunning && !wasRunning) return true;
        if (currentSavedVariablesWrite is not null
            && currentSavedVariablesWrite != lastSavedVariablesWrite) return true;
        if (!isRunning && wasRunning) return true;
        return isRunning && nowUtc - lastSyncUtc >= RecordsRefreshInterval;
    }

    private static bool IsEsoRunning()
    {
        try
        {
            foreach (var process in Process.GetProcesses())
            {
                using (process)
                {
                    var name = process.ProcessName.Replace(" ", "", StringComparison.Ordinal)
                        .Replace("_", "", StringComparison.Ordinal)
                        .Replace("-", "", StringComparison.Ordinal);
                    if (name.Equals("eso", StringComparison.OrdinalIgnoreCase)
                        || name.Equals("eso64", StringComparison.OrdinalIgnoreCase)
                        || name.Equals("eso64.exe", StringComparison.OrdinalIgnoreCase)
                        || name.Equals("elderscrollsonline", StringComparison.OrdinalIgnoreCase))
                        return true;
                }
            }
            return false;
        }
        catch
        {
            return false;
        }
    }

    private static DateTime? GetLastWriteUtc(string path) =>
        File.Exists(path) ? File.GetLastWriteTimeUtc(path) : null;

    private static void WriteWatcherStatus(string text)
    {
        try
        {
            Directory.CreateDirectory(StateDirectory());
            File.WriteAllText(
                Path.Combine(StateDirectory(), "last-watcher-status.txt"),
                text,
                new UTF8Encoding(false));
        }
        catch
        {
            // Status reporting must never terminate the background watcher.
        }
    }

    private static string LastSyncStatusPath() => Path.Combine(StateDirectory(), "last-sync-status.txt");

    private static void WriteLastSyncStatus(int result, string? summary)
    {
        try
        {
            Directory.CreateDirectory(StateDirectory());
            var message = $"{DateTimeOffset.Now:yyyy-MM-dd HH:mm:ss zzz} — "
                + (result == 0 ? "Sync complete" : $"Sync failed (code {result})");
            if (!string.IsNullOrWhiteSpace(summary))
                message += "\n" + summary[..Math.Min(summary.Length, 2000)];
            File.WriteAllText(LastSyncStatusPath(), message, new UTF8Encoding(false));
        }
        catch
        {
            // A status display failure must not change the upload result.
        }
    }
}
