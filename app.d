import std.stdio, std.algorithm, std.range, std.conv;
import file = std.file;

private struct Translation
{
    private string english_;
    private string translated_;

    @property string english() { return english_; }
    @property void english(string value) { english_ = unquoteString(value); }

    @property string translated() { return translated_; }
    @property void translated(string value) { translated_ = unquoteString(value); }
}

private string unquoteString(string text)
{
    if (text != "" && text[0] == '"' && text[$-1] == '"') text = text[1..$-1];
    return text;
}

private struct Record
{
    string name, english, translation, restrictions, comment;

    this(string[] data)
    {
        name = unquoteString(data[0]);
        english = unquoteString(data[1]);
        translation = unquoteString(data[2]);
        restrictions = unquoteString(data[3]);
        comment = unquoteString(data[4]);
    }

    this(char[][] data)
    {
        name = unquoteString(data[0].idup);
        english = unquoteString(data[1].idup);
        translation = unquoteString(data[2].idup);
        restrictions = unquoteString(data[3].idup);
        comment = unquoteString(data[4].idup);
    }
}

private enum fileResultChanged = "result_english_changed.txt";
private enum fileResultAdded = "result_english_added.txt";

void main(string[] args)
{
    // auto fileEnglish = "english.csv";
    // auto fileTranslated = "russian.csv";
	if (args.length != 3)
    {
        writeln("Usage:\n", args[0], " english.csv translated.csv");
        return;
    }

    auto fileEnglish = args[1];
    auto fileTranslated = args[2];

    if (!file.exists(fileEnglish))
    {
        writeln("File not found: ", fileEnglish);
        return;
    }

    if (!file.exists(fileTranslated))
    {
        writeln("File not found: ", fileTranslated);
        return;
    }

    Translation[string] data;

    auto fileAdded = File(fileResultAdded, "w");
    auto fileChanged = File(fileResultChanged, "w");

    // Read English
    writeln("---[ Read English ]---");
    auto file = File(fileEnglish, "r");
    auto counter = 0;
    foreach(record; file.byLine.map!(a => a.parse))
    {
        counter++;
        auto recordName = record.name;
        auto recordText = record.english;

        if (counter == 1) continue;

        if (recordName in data)
            writeln("Error. Record already present: ", recordName);
        else
            data[recordName] = Translation(recordText, "");
    }
    
    // Read Translated
    counter = 0;
    writeln("\n---[ English string was changed for: ]---");
    file = File(fileTranslated, "r");
    foreach(record; file.byLine.map!(a => a.parse))
    {
        counter++;
        immutable auto recordName = record.name;
        immutable auto recordTextEnglish = record.english;
        immutable auto recordTextTranslated = record.translation;

        if (counter == 1) continue;

        if (recordName !in data)
            writeln("Record not found in English: ", recordName);
        else
        {
            if (data[recordName].english != recordTextEnglish)
            {
                writeln(recordName);
                fileChanged.writeln(recordName);
            }

            data[recordName].translated = recordTextTranslated;
        }
    }

    // Find new English lines
    writeln("\n---[ New English strings was added: ]---");
    foreach(k, line; data)
    {
        // writeln("name: ", k, "en: ", line.english, ", ru: ", line.translated);
        if (line.translated == "" && line.english != "")
        {
            writeln("New record: ", k);
            fileAdded.writeln(k);
        }
    }

    fileAdded.close();
    fileChanged.close();
}

private Record parse(char[] text)
{
    if (!text.canFind('"'))
    {
        auto d = split(text, ",");
        return Record(d);
    }

    // writeln("Parse line:\n", text);
    
    enum states { Unknown, UnquotedLine, QuotedLine }
    auto currentState = states.Unknown;
    uint currentColumn, currentColumnStartPos;

    auto resultTmp = ["", "", "", "", ""];
    auto skip = false;

    foreach(i, chr; text)
    {
        if (skip)
        {
            skip = false;
            continue;
        }

        // writeln("i: ", i, ", chr: \"", chr, "\" (", to!int(chr), ")");
        if (currentState == states.Unknown)
        {
            currentColumnStartPos = to!uint(i);

            if (chr == ',')
            {
                currentColumnStartPos = to!uint(i + 1);
                currentState = states.Unknown;
                currentColumn++;
                // writeln("New currentColumnStartPos: ", currentColumnStartPos);
            }
            else if (chr == '"')
                currentState = states.QuotedLine;
            else
                currentState = states.UnquotedLine;
        }
        else
        {
            // Unquoted line
            if (currentState == states.UnquotedLine)
            {
                if (chr == ',')
                {
                    // write("Column ", currentColumn, " ");
                    immutable data = text[currentColumnStartPos..i].idup;
                    // writeln(data);
                    // writeln("Range from ", currentColumnStartPos, " to ", i);
                    currentColumnStartPos = to!uint(i + 1);
                    currentState = states.Unknown;
                    // writeln("New currentColumnStartPos: ", currentColumnStartPos);

                    resultTmp[currentColumn] = data;
                    currentColumn++;
                }
            }
            // Quoted line
            else
            {
                auto isLast = (i == text.length - 1);
                auto isComma = (!isLast && text[i + 1] == ',');
                if (chr == '"')
                {
                    if (isLast || isComma)
                    {
                        char[] data;
                        // write("Column ", currentColumn, " ");
                        // writeln("Range from ", currentColumnStartPos, " to ", i);

                        if (isLast)
                            data = text[currentColumnStartPos..$];
                        else if (isComma)
                        {
                            data = text[currentColumnStartPos..i+1];
                            currentColumnStartPos = to!uint(i + 2);
                        }

                        if (isLast || isComma)
                        {
                            currentState = states.Unknown;
                            // writeln(data);
                            // writeln("New currentColumnStartPos: ", currentColumnStartPos);

                            resultTmp[currentColumn] = data.idup;

                            currentColumn++;
                            skip = true;
                        }
                    }
                }
            }
        }
    }

    if (currentColumn <= 4)
        resultTmp[currentColumn] = text[currentColumnStartPos..$].idup;

    return Record(resultTmp);
}
