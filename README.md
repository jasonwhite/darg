# D Argument Parser

Better command line argument parsing for D.

## Example

```d
import std.stdio;
import darg;

struct Options
{
    @Option("help", "h")
    OptionFlag help;

    @Option("threads", "t")
    size_t threads;

    @Argument("file", Multiplicity.zeroOrMore)
    @Help("Input files")
    string[] files;
}

int main(string[] args)
{
    Options options;

    try
    {
        options = parseArgs!Options(args[1 .. $]);
    }
    catch (ArgParseException e)
    {
        writeln(usageString!Options);
        return 1;
    }

    if (options.help)
    {
        writeln(helpString!Options);
        return 0;
    }

    foreach (f; options.files)
    {
        // Use files
    }
}
```

## License

[MIT License](/LICENSE.md)
