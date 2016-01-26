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
    @Help("Prints this help.")
    OptionFlag help;

    @Option("threads", "t")
    @Help("Number of threads to use.")
    size_t threads;

    @Argument("file", Multiplicity.zeroOrMore)
    @Help("Input files")
    string[] files;
}

// Generate the usage and help string at compile time.
immutable usage = usageString!Options("program");
immutable help = helpString!Options;

int main(string[] args)
{
    Options options;

    try
    {
        options = parseArgs!Options(args[1 .. $]);
    }
    catch (ArgParseException e)
    {
        writeln(usage);
        return 1;
    }

    if (options.help == OptionFlag.yes)
    {
        writeln(usage);
        writeln(help);
        return 0;
    }

    foreach (f; options.files)
    {
        // Use files
    }

    return 0;
}
```

Running this example with `--help`, we get the following output:

    $ ./example --help
    Usage: program [--help] [--threads=<ulong>] [file...]

    Positional arguments:
     file            Input files

    Optional arguments:
     --help, -h      Prints this help.
     --threads, -t <ulong>
                     Number of threads to use.
    

## License

[MIT License](/LICENSE.md)
