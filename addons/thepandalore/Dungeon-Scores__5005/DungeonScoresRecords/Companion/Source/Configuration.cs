using System.Security.Cryptography;
using System.Text.Json;

internal static partial class Program
{
    private static async Task<UploaderConfig> LoadConfigurationAsync(string[] args)
    {
        var explicitPath = ArgumentValue(args, "--config");
        string? configPath = null;
        if (explicitPath is not null)
        {
            configPath = Path.GetFullPath(explicitPath);
            if (!File.Exists(configPath))
                throw new FileNotFoundException("the requested configuration file was not found", configPath);
        }
        else
        {
            var currentName = Path.Combine(AppContext.BaseDirectory, "DungeonScoresCompanion.json");
            var legacyName = Path.Combine(AppContext.BaseDirectory, "DungeonScoresUploader.json");
            if (File.Exists(currentName)) configPath = currentName;
            else if (File.Exists(legacyName)) configPath = legacyName;
        }

        if (configPath is not null)
            return JsonSerializer.Deserialize(
                    await File.ReadAllTextAsync(configPath),
                    CompanionJsonContext.Default.UploaderConfig)
                ?? throw new InvalidDataException("configuration is empty");

        return CreateBundledDefaultConfig();
    }

    private static UploaderConfig CreateBundledDefaultConfig()
    {
        var companionDirectory = new DirectoryInfo(Path.GetFullPath(AppContext.BaseDirectory));
        var recordsDirectory = companionDirectory.Parent;
        var addOnsDirectory = recordsDirectory?.Parent;
        var liveDirectory = addOnsDirectory?.Parent;
        if (recordsDirectory is null || addOnsDirectory is null || liveDirectory is null
            || !string.Equals(companionDirectory.Name, "Companion", StringComparison.OrdinalIgnoreCase)
            || !string.Equals(recordsDirectory.Name, "DungeonScoresRecords", StringComparison.OrdinalIgnoreCase)
            || !string.Equals(addOnsDirectory.Name, "AddOns", StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException(
                "no configuration file was found and the companion is not installed at AddOns\\DungeonScoresRecords\\Companion");

        return new UploaderConfig(
            ProductionApiEndpoint,
            null,
            Path.Combine(liveDirectory.FullName, "SavedVariables", "DungeonScores.lua"),
            addOnsDirectory.FullName);
    }

    private static void ValidateConfig(UploaderConfig config)
    {
        if (!Uri.TryCreate(config.ApiEndpoint, UriKind.Absolute, out var endpoint)
            || (endpoint.Scheme != Uri.UriSchemeHttps && endpoint.Host != "localhost"))
            throw new InvalidDataException("ApiEndpoint must be an HTTPS URL");
        if (!string.IsNullOrWhiteSpace(config.BearerToken) && !IsValidBearerToken(config.BearerToken))
            throw new InvalidDataException("BearerToken is not a Dungeon Scores installation credential");
        if (string.IsNullOrWhiteSpace(config.SavedVariablesPath))
            throw new InvalidDataException("SavedVariablesPath is missing");
        _ = ResolveAddOnsPath(config);
    }

    private static string ResolveAddOnsPath(UploaderConfig config)
    {
        if (!string.IsNullOrWhiteSpace(config.AddOnsPath))
            return Path.GetFullPath(config.AddOnsPath);
        var savedVariablesDirectory = Path.GetDirectoryName(Path.GetFullPath(config.SavedVariablesPath));
        if (savedVariablesDirectory is null
            || !string.Equals(Path.GetFileName(savedVariablesDirectory), "SavedVariables", StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException("AddOnsPath is missing and could not be inferred from SavedVariablesPath");
        var liveDirectory = Directory.GetParent(savedVariablesDirectory)?.FullName
            ?? throw new InvalidDataException("SavedVariablesPath has no ESO live directory");
        return Path.Combine(liveDirectory, "AddOns");
    }

    private static bool IsValidBearerToken(string value)
    {
        if (!value.StartsWith("ds_", StringComparison.Ordinal) || value.Length != 46) return false;
        return value.AsSpan(3).IndexOfAnyExcept(
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".AsSpan()) < 0;
    }

    private static string CreateBearerToken()
    {
        var encoded = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32))
            .TrimEnd('=').Replace('+', '-').Replace('/', '_');
        var token = "ds_" + encoded;
        if (!IsValidBearerToken(token)) throw new CryptographicException("generated credential was invalid");
        return token;
    }

    private static async Task<string> LoadOrCreateCredentialAsync(
        string stateDirectory,
        string? configuredToken,
        TextWriter output)
    {
        if (!string.IsNullOrWhiteSpace(configuredToken)) return configuredToken;
        var path = Path.Combine(stateDirectory, "credential.json");
        if (File.Exists(path))
        {
            var saved = JsonSerializer.Deserialize(
                await File.ReadAllTextAsync(path),
                CompanionJsonContext.Default.UploaderCredential);
            if (saved is not null && IsValidBearerToken(saved.BearerToken)) return saved.BearerToken;
            throw new InvalidDataException("the saved credential is invalid");
        }

        Directory.CreateDirectory(stateDirectory);
        var credential = new UploaderCredential(CreateBearerToken());
        await AtomicWriteAsync(
            path,
            JsonSerializer.Serialize(credential, CompanionJsonContext.Default.UploaderCredential));
        output.WriteLine("Created a private local publisher identity for automatic first-submit enrollment.");
        return credential.BearerToken;
    }

    private static async Task<HashSet<string>> LoadSubmittedAsync(string path)
    {
        if (!File.Exists(path)) return new HashSet<string>(StringComparer.Ordinal);
        try
        {
            var values = JsonSerializer.Deserialize(
                await File.ReadAllTextAsync(path),
                CompanionJsonContext.Default.StringArray) ?? [];
            return new HashSet<string>(values, StringComparer.Ordinal);
        }
        catch
        {
            return new HashSet<string>(StringComparer.Ordinal);
        }
    }

    private static Task SaveSubmittedAsync(string path, HashSet<string> submitted) =>
        AtomicWriteAsync(
            path,
            JsonSerializer.Serialize(submitted.Order().ToArray(), CompanionJsonContext.Default.StringArray));

    private static string? ArgumentValue(string[] args, string name)
    {
        for (var index = 0; index + 1 < args.Length; index++)
            if (string.Equals(args[index], name, StringComparison.OrdinalIgnoreCase)) return args[index + 1];
        return null;
    }
}
