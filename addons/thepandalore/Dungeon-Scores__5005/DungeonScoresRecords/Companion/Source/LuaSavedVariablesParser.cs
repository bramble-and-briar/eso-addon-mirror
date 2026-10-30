using System.Globalization;
using System.Text;

internal sealed class LuaSavedVariablesParser(string text)
{
    private int position;

    public object? ParseDocument()
    {
        Skip();
        ReadIdentifier();
        Skip();
        Expect('=');
        var value = ParseValue();
        Skip();
        return value;
    }

    private object? ParseValue()
    {
        Skip();
        if (Peek() == '{') return ParseTable();
        if (Peek() == '"') return ParseString();
        if (Peek() == '-' || char.IsDigit(Peek())) return ParseNumber();
        var identifier = ReadIdentifier();
        return identifier switch { "true" => true, "false" => false, "nil" => null, _ => identifier };
    }

    private Dictionary<string, object?> ParseTable()
    {
        Expect('{');
        var result = new Dictionary<string, object?>(StringComparer.Ordinal);
        var implicitIndex = 1;
        while (true)
        {
            Skip();
            if (TryTake('}')) return result;
            string key;
            object? value;
            if (TryTake('['))
            {
                var rawKey = ParseValue();
                Skip();
                Expect(']');
                Skip();
                Expect('=');
                key = Convert.ToString(rawKey, CultureInfo.InvariantCulture) ?? "";
                value = ParseValue();
            }
            else
            {
                var save = position;
                if (char.IsLetter(Peek()) || Peek() == '_')
                {
                    var identifier = ReadIdentifier();
                    Skip();
                    if (TryTake('=')) { key = identifier; value = ParseValue(); }
                    else { position = save; key = (implicitIndex++).ToString(); value = ParseValue(); }
                }
                else { key = (implicitIndex++).ToString(); value = ParseValue(); }
            }
            result[key] = value;
            Skip();
            TryTake(',');
            TryTake(';');
        }
    }

    private string ParseString()
    {
        Expect('"');
        var builder = new StringBuilder();
        while (position < text.Length)
        {
            var character = text[position++];
            if (character == '"') return builder.ToString();
            if (character != '\\') { builder.Append(character); continue; }
            if (position >= text.Length) throw Error("unterminated escape");
            var escaped = text[position++];
            builder.Append(escaped switch
            {
                'n' => '\n',
                'r' => '\r',
                't' => '\t',
                '\\' => '\\',
                '"' => '"',
                _ when char.IsDigit(escaped) => ParseDecimalEscape(escaped),
                _ => escaped,
            });
        }
        throw Error("unterminated string");
    }

    private char ParseDecimalEscape(char first)
    {
        var digits = first.ToString();
        for (var count = 1; count < 3 && position < text.Length && char.IsDigit(text[position]); count++) digits += text[position++];
        return (char)int.Parse(digits, CultureInfo.InvariantCulture);
    }

    private object ParseNumber()
    {
        var start = position;
        if (Peek() == '-') position++;
        while (position < text.Length && (char.IsDigit(text[position]) || text[position] is '.' or 'e' or 'E' or '+' or '-')) position++;
        var token = text[start..position];
        if (long.TryParse(token, NumberStyles.Integer, CultureInfo.InvariantCulture, out var integer)) return integer;
        if (double.TryParse(token, NumberStyles.Float, CultureInfo.InvariantCulture, out var number)) return number;
        throw Error($"invalid number {token}");
    }

    private string ReadIdentifier()
    {
        Skip();
        var start = position;
        while (position < text.Length && (char.IsLetterOrDigit(text[position]) || text[position] == '_')) position++;
        if (position == start) throw Error("identifier expected");
        return text[start..position];
    }

    private void Skip()
    {
        while (position < text.Length)
        {
            if (char.IsWhiteSpace(text[position])) { position++; continue; }
            if (position + 1 < text.Length && text[position] == '-' && text[position + 1] == '-')
            {
                position += 2;
                while (position < text.Length && text[position] != '\n') position++;
                continue;
            }
            break;
        }
    }

    private char Peek() => position < text.Length ? text[position] : '\0';

    private bool TryTake(char expected)
    {
        Skip();
        if (Peek() != expected) return false;
        position++;
        return true;
    }

    private void Expect(char expected)
    {
        if (!TryTake(expected)) throw Error($"expected '{expected}'");
    }

    private InvalidDataException Error(string message) => new($"{message} near character {position}");
}
