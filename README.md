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
immutable usage = usageString!Options("example");
immutable help = helpString!Options;

int main(string[] args)
{
    Options options;

    try
    {
        options = parseArgs!Options(args[1 .. $]);
    }
    catch (ArgParseError e)
    {
        writeln(e.msg);
        writeln(usage);
        return 1;
    }
    catch (ArgParseHelp e)
    {
        // Help was requested
        writeln(usage);
        write(help);
        return 0;
    }

    foreach (f; options.files)
    {
        // Use files
    }

    return 0;
}
```

    $ ./example --help
    Usage: example [--help] [--threads=<ulong>] [file...]

    Positional arguments:
     file            Input files

    Optional arguments:
     --help, -h      Prints this help.
     --threads, -t <ulong>
                     Number of threads to use.
    
    $ ./example --foobar
    Unknown option '--foobar'
    Usage: program [--help] [--threads=<ulong>] [file...]


## License

[MIT License](/LICENSE.md)
