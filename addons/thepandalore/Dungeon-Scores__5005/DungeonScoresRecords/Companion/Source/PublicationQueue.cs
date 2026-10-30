using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Security.Cryptography;

internal static partial class Program
{
    private static string? cachedQueuePath;
    private static byte[]? cachedQueueHash;
    private static IReadOnlyList<QueueItem>? cachedQueue;

    internal static IReadOnlyList<QueueItem> LoadExplicitQueue(string path)
    {
        if (!File.Exists(path)) throw new FileNotFoundException("SavedVariables file not found", path);
        return ParseExplicitQueue(File.ReadAllText(path));
    }

    // The watcher refreshes records even when ESO has not written a new save.
    // Hash the actual file bytes before reusing a parse so equal timestamps or
    // file lengths can never hide a newly queued score.
    private static IReadOnlyList<QueueItem> LoadExplicitQueueCached(string path)
    {
        var fullPath = Path.GetFullPath(path);
        var bytes = File.ReadAllBytes(fullPath);
        var hash = SHA256.HashData(bytes);
        if (cachedQueue is not null
            && string.Equals(cachedQueuePath, fullPath, StringComparison.OrdinalIgnoreCase)
            && cachedQueueHash is not null
            && hash.AsSpan().SequenceEqual(cachedQueueHash))
            return cachedQueue;

        using var reader = new StreamReader(new MemoryStream(bytes, writable: false),
            Encoding.UTF8, detectEncodingFromByteOrderMarks: true);
        var parsed = ParseExplicitQueue(reader.ReadToEnd());
        cachedQueuePath = fullPath;
        cachedQueueHash = hash;
        cachedQueue = parsed;
        return parsed;
    }

    private static IReadOnlyList<QueueItem> ParseExplicitQueue(string source)
    {
        var parsed = new LuaSavedVariablesParser(source).ParseDocument();
        var items = new List<QueueItem>();
        Visit(parsed, table =>
        {
            if (!table.TryGetValue("publicationQueue", out var rawQueue)
                || rawQueue is not Dictionary<string, object?> queue)
                return;
            foreach (var request in OrderedValues(queue).OfType<Dictionary<string, object?>>())
            {
                if (!request.TryGetValue("queueKey", out var keyValue)
                    || keyValue is not string queueKey
                    || !request.TryGetValue("requestId", out var requestValue)
                    || !TryLong(requestValue, out var requestId)
                    || !request.TryGetValue("payload", out var payloadValue)
                    || payloadValue is not Dictionary<string, object?> payload)
                {
                    continue;
                }
                // Only the addon's explicit publicationQueue is traversed.
                // There is deliberately no history or highScores fallback.
                // Legacy queue entries may carry the retired partition field.
                // Strip it from the in-memory upload only; never rewrite SavedVariables.
                var publicationPayload = new Dictionary<string, object?>(payload, StringComparer.Ordinal);
                publicationPayload.Remove("scoringEpoch");
                items.Add(new QueueItem(queueKey, requestId, ToJsonShape(publicationPayload)!));
            }
        });
        return items.GroupBy(item => item.QueueKey, StringComparer.Ordinal)
            .Select(group => group.OrderByDescending(item => item.RequestId).First())
            .OrderBy(item => item.RequestId)
            .ToArray();
    }

    private static void Visit(object? value, Action<Dictionary<string, object?>> visitor)
    {
        if (value is not Dictionary<string, object?> table) return;
        visitor(table);
        foreach (var child in table.Values) Visit(child, visitor);
    }

    private static IEnumerable<object?> OrderedValues(Dictionary<string, object?> table) => table
        .OrderBy(pair => long.TryParse(pair.Key, out var number) ? number : long.MaxValue)
        .Select(pair => pair.Value);

    private static object? ToJsonShape(object? value)
    {
        if (value is not Dictionary<string, object?> table) return value;
        var numbered = table
            .Select(pair =>
            {
                var valid = int.TryParse(pair.Key, out var index);
                return (Pair: pair, Valid: valid, Index: valid ? index : 0);
            })
            .ToArray();
        if (numbered.Length > 0 && numbered.All(item => item.Valid)
            && numbered.Select(item => item.Index).Order().SequenceEqual(Enumerable.Range(1, numbered.Length)))
        {
            return numbered.OrderBy(item => item.Index)
                .Select(item => ToJsonShape(item.Pair.Value))
                .ToList();
        }
        return table.ToDictionary(pair => pair.Key, pair => ToJsonShape(pair.Value), StringComparer.Ordinal);
    }

    private static string SerializePayload(object? value)
    {
        using var stream = new MemoryStream();
        using (var writer = new Utf8JsonWriter(stream)) WriteJsonValue(writer, value);
        return Encoding.UTF8.GetString(stream.ToArray());
    }

    private static void WriteJsonValue(Utf8JsonWriter writer, object? value)
    {
        switch (value)
        {
            case null: writer.WriteNullValue(); break;
            case string text: writer.WriteStringValue(text); break;
            case bool flag: writer.WriteBooleanValue(flag); break;
            case long integer: writer.WriteNumberValue(integer); break;
            case int integer: writer.WriteNumberValue(integer); break;
            case double number: writer.WriteNumberValue(number); break;
            case Dictionary<string, object?> table:
                writer.WriteStartObject();
                foreach (var pair in table)
                {
                    writer.WritePropertyName(pair.Key);
                    WriteJsonValue(writer, pair.Value);
                }
                writer.WriteEndObject();
                break;
            case IEnumerable<object?> values:
                writer.WriteStartArray();
                foreach (var item in values) WriteJsonValue(writer, item);
                writer.WriteEndArray();
                break;
            default:
                throw new InvalidDataException($"unsupported publication value type: {value.GetType().Name}");
        }
    }

    private static bool TryLong(object? value, out long number)
    {
        if (value is long direct) { number = direct; return true; }
        if (value is double floating && floating == Math.Truncate(floating))
        {
            number = (long)floating;
            return true;
        }
        return long.TryParse(Convert.ToString(value, CultureInfo.InvariantCulture), out number);
    }
}
