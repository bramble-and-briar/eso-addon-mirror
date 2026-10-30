using System.Text.Json;

internal static partial class Program
{
    private static string SafeResponse(string value)
    {
        value = value.Replace('\r', ' ').Replace('\n', ' ').Trim();
        return value.Length <= 300 ? value : value[..300];
    }

    private static bool IsTerminalSubmissionRejection(string responseText, string expectedError)
    {
        try
        {
            using var document = JsonDocument.Parse(responseText);
            return document.RootElement.TryGetProperty("error", out var error)
                && string.Equals(error.GetString(), expectedError, StringComparison.Ordinal);
        }
        catch
        {
            return false;
        }
    }

    private static string SubmissionSummary(string responseText)
    {
        try
        {
            using var document = JsonDocument.Parse(responseText);
            var root = document.RootElement;
            var summaries = new List<string> { "global record handled" };
            var routed = false;
            if (root.TryGetProperty("guildRecord", out var guildRecord)
                && guildRecord.TryGetProperty("requested", out var guildRequested)
                && guildRequested.ValueKind == JsonValueKind.True)
            {
                routed = true;
                var guildName = guildRecord.TryGetProperty("guildName", out var guildNameValue)
                    ? guildNameValue.GetString() : null;
                if (guildRecord.TryGetProperty("accepted", out var guildAccepted)
                    && guildAccepted.ValueKind == JsonValueKind.True)
                {
                    var improved = guildRecord.TryGetProperty("improved", out var improvedValue)
                        && improvedValue.ValueKind == JsonValueKind.True;
                    summaries.Add(improved
                        ? $"new guild record routed{(string.IsNullOrWhiteSpace(guildName) ? "" : $" to {guildName}")}"
                        : $"guild result did not improve{(string.IsNullOrWhiteSpace(guildName) ? " the record" : $" {guildName}'s record")}");
                }
                else
                {
                    var reason = guildRecord.TryGetProperty("reason", out var reasonValue)
                        ? reasonValue.GetString() : "not eligible";
                    summaries.Add($"guild record was not routed ({reason})");
                }
            }
            if (root.TryGetProperty("guildEvent", out var guildEvent)
                && guildEvent.TryGetProperty("requested", out var eventRequested)
                && eventRequested.ValueKind == JsonValueKind.True)
            {
                routed = true;
                var guildName = guildEvent.TryGetProperty("guildName", out var guildNameValue)
                    ? guildNameValue.GetString() : null;
                var eventName = guildEvent.TryGetProperty("guildEventName", out var eventNameValue)
                    ? eventNameValue.GetString() : null;
                var label = string.Join(" — ", new[] { guildName, eventName }
                    .Where(value => !string.IsNullOrWhiteSpace(value)));
                if (guildEvent.TryGetProperty("accepted", out var eventAccepted)
                    && eventAccepted.ValueKind == JsonValueKind.True)
                {
                    var improved = guildEvent.TryGetProperty("improved", out var improvedValue)
                        && improvedValue.ValueKind == JsonValueKind.True;
                    summaries.Add(improved
                        ? $"new event team best routed{(label.Length > 0 ? $" to {label}" : "")}"
                        : $"event result did not improve the team's best{(label.Length > 0 ? $" for {label}" : "")}");
                }
                else
                {
                    var reason = guildEvent.TryGetProperty("reason", out var reasonValue)
                        ? reasonValue.GetString() : "not eligible";
                    summaries.Add($"guild event was not routed ({reason})");
                }
            }
            if (!routed) summaries.Add("no guild route selected");
            return string.Join("; ", summaries) + ".";
        }
        catch
        {
            return "accepted or already superseded.";
        }
    }
}
