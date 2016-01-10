[buildbadge]: https://travis-ci.org/jasonwhite/darg.svg?branch=master
[buildstatus]: https://travis-ci.org/jasonwhite/darg

# D Argument Parser [![Build Status][buildbadge]][buildstatus]

Better command line argument parsing using D's powerful compile-time code
generation facilities.

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

    if (options.help == OptionFlag.yes)
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
