/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Parses arguments.
 */
module argparse;

/**
 * Specifies that an option is not optional.
 */
enum Required;

/**
 * User defined attribute for an option.
 */
struct Opt
{
    string[] names;

    this(string[] names...)
    {
        this.names = names;
    }
}

/**
 * Generic argument parsing exception.
 */
class ArgParseException : Exception
{
    this(string msg) pure nothrow
    {
        super(msg);
    }
}

/**
 * User defined attribute for a positional argument.
 */
struct Arg
{
    /**
     * Name of the argument. Since this is a positional argument, this value is
     * only used in the help string.
     */
    string name;

    /**
     * Lower and upper bounds for the number of values this argument can have.
     * Note that these bounds are inclusive (i.e., [lowerBound, upperBound]).
     */
    size_t lowerBound = 1;
    size_t upperBound = 1; /// Ditto

    /**
     * Constructor.
     */
    this(string name, size_t lowerBound = 1, size_t upperBound = 1) pure nothrow
    {
        // TODO: Check if the name has spaces. (Replace with a dash?)
        this.name = name;
        this.lowerBound = lowerBound;
        this.upperBound = upperBound;
    }

    /**
     * Convenience constructor with an argument multiplicity specifier.
     */
    this(string name, char multiplicity) pure
    {
        this.name = name;

        switch (multiplicity)
        {
            case '?':
                this.lowerBound = 0;
                this.upperBound = 1;
                break;
            case '*':
                this.lowerBound = 0;
                this.upperBound = size_t.max;
                break;
            case '+':
                this.lowerBound = 1;
                this.upperBound = size_t.max;
                break;
            default:
                throw new ArgParseException(
                        "Invalid argument multiplicity specifier:"
                        " must be either '?', '*', or '+'"
                        );
        }
    }
}

unittest
{
    with (Arg("lion"))
    {
        assert(name == "lion");
        assert(lowerBound == 1);
        assert(upperBound == 1);
    }

    with (Arg("tiger", '?'))
    {
        assert(lowerBound == 0);
        assert(upperBound == 1);
    }

    with (Arg("bear", '+'))
    {
        assert(lowerBound == 1);
        assert(upperBound == size_t.max);
    }

    with (Arg("dinosaur", '*'))
    {
        assert(lowerBound == 0);
        assert(upperBound == size_t.max);
    }
}

unittest
{
    import std.exception : collectException;

    assert(collectException!ArgParseException(Arg("fails", 'q')));
    assert(!collectException!ArgParseException(Arg("success", '?')));
    assert(!collectException!ArgParseException(Arg("success", '*')));
    assert(!collectException!ArgParseException(Arg("success", '+')));
}

/**
 * Help string for an option or positional argument.
 */
struct Help
{
    string help;
}

/**
 * Constructs a printable usage string at compile time from the given options
 * structure.
 */
string usageString(Options)(string program) pure nothrow
{
    return "TODO";
}

/**
 * Constructs a printable help string at compile time for the given options
 * structure.
 */
string helpString(Options)() pure nothrow
{
    return "TODO";
}

/**
 * Thrown when parsing arguments fails.
 */
class ArgParseError : Exception
{
    this(string msg)
    {
        super(msg);
    }
}

/**
 * Parses options from the given list of arguments. Note that the first argument
 * is assumed to be the program name and is ignored.
 *
 * Returns: Options structure filled out with values.
 *
 * Throws: ArgParseError if arguments are invalid.
 */
Options parseArgs(Options)(string[] args) pure
{
    Options options;

    return options;
}

/// Ditto
unittest
{
    struct Options
    {
        @Opt("help")
            @Help("Prints help on command line arguments.")
            bool help;

        @Arg("path", 'q')
            @Help("Path to the build description.")
            string path;

        @Opt("dryrun", "n")
            @Help("Don't make any functional changes. Just print what might"
                  " happen.")
            bool dryRun;

        @Opt("threads", "j")
            @Help("The number of threads to use. Default is the number of"
                  " logical cores.")
            string threads;

        @Opt("color")
            @Help("When to colorize the output.")
            string color = "auto";

        @Opt("add")
            @Required
            @Help("Adds the given number to a running total.")
            void add(string num)
            {
                import std.conv : to;
                sum += num.to!int;
            }

        int sum;
    }
}

