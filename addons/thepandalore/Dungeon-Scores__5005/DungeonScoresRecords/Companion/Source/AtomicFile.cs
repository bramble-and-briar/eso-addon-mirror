using System.Text;

internal static partial class Program
{
    private static async Task AtomicWriteAsync(string path, string content)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        var temporary = path + ".tmp";
        await File.WriteAllTextAsync(temporary, content, new UTF8Encoding(false));
        File.Move(temporary, path, true);
    }
}
