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
 * User defined attribute for an option.
 */
struct Option
{
    string[] names;

    this(string[] names...) pure nothrow
    {
        this.names = names;
    }

    /**
     * Returns true if the given option name is equivalent to this option.
     */
    bool opEquals(string opt) const pure nothrow
    {
        foreach (name; names)
        {
            if (name == opt)
                return true;
        }

        return false;
    }

    unittest
    {
        static assert(Option("foo") == "foo");
        static assert(Option("foo", "f") == "foo");
        static assert(Option("foo", "f") == "f");
        static assert(Option("foo", "bar", "baz") == "foo");
        static assert(Option("foo", "bar", "baz") == "bar");
        static assert(Option("foo", "bar", "baz") == "baz");

        static assert(Option("foo", "bar") != "baz");
    }

    /**
     * Returns the canonical name of this option. That is, its first name.
     */
    string toString() const pure nothrow
    {
        return names.length > 0 ? (nameToOption(names[0])) : null;
    }

    unittest
    {
        static assert(Option().toString is null);
        static assert(Option("foo", "bar", "baz").toString == "--foo");
        static assert(Option("f", "bar", "baz").toString == "-f");
    }
}

/**
 * An option flag. These types of options are handled specially and never have
 * an argument. They can also be inverted with the "--no" prefix (e.g.,
 * "--nofoo").
 */
enum OptionFlag
{
    no,
    yes,
}

/**
 * User defined attribute for a positional argument.
 */
struct Argument
{
    /**
     * Name of the argument. Since this is a positional argument, this value is
     * only used in the help string.
     */
    string name;

    /**
     * Lower and upper bounds for the number of values this argument can have.
     *
     * Note that the boundary interval is closed left and open right (i.e.,
     * [lowerBound, upperBound)).
     */
    size_t lowerBound = 1;
    size_t upperBound = 2; /// Ditto

    /**
     * An argument with exactly 1 value.
     */
    this(string name, size_t lowerBound = 1, size_t upperBound = 2) pure nothrow
    in { assert(lowerBound < upperBound); }
    body
    {
        // TODO: Check if the name has spaces. (Replace with a dash?)
        this.name = name;
        this.lowerBound = lowerBound;
        this.upperBound = upperBound;
    }

    /**
     * An argument with a multiplicity specifier.
     *
     * Possible multiplicity specifiers:
     *  '?' 0 or 1
     *  '*' 0 or more
     *  '+' 1 or more
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
    with (Argument("lion"))
    {
        assert(name == "lion");
        assert(lowerBound == 1);
        assert(upperBound == 2);
    }

    with (Argument("tiger", '?'))
    {
        assert(lowerBound == 0);
        assert(upperBound == 1);
    }

    with (Argument("bear", '*'))
    {
        assert(lowerBound == 0);
        assert(upperBound == size_t.max);
    }

    with (Argument("dinosaur", '+'))
    {
        assert(lowerBound == 1);
        assert(upperBound == size_t.max);
    }
}

unittest
{
    import std.exception : collectException;

    assert( collectException!ArgParseException(Argument("failure", 'q')));
    assert(!collectException!ArgParseException(Argument("success", '?')));
    assert(!collectException!ArgParseException(Argument("success", '*')));
    assert(!collectException!ArgParseException(Argument("success", '+')));
}

/**
 * Help string for an option or positional argument.
 */
struct Help
{
    string help;
}

/**
 * Function signatures that can handle arguments or options.
 */
private alias void OptionHandler();
private alias void ArgumentHandler(string); /// Ditto

/**
 * Constructs a printable usage string at compile time from the given options
 * structure.
 */
string usageString(Options)(string program) pure nothrow
    if (is(Options == struct))
{
    return "TODO";
}

/**
 * Constructs a printable help string at compile time for the given options
 * structure.
 */
string helpString(Options)() pure nothrow
    if (is(Options == struct))
{
    return "TODO";
}

/**
 * Returns true if the given argument is a short option. That is, if it starts
 * with a '-'.
 */
private bool isShortOption(string arg) pure nothrow
{
    return arg.length > 1 && arg[0] == '-' && arg[1] != '-';
}

unittest
{
    static assert(!isShortOption(""));
    static assert(!isShortOption("-"));
    static assert(!isShortOption("a"));
    static assert(!isShortOption("ab"));
    static assert( isShortOption("-a"));
    static assert( isShortOption("-ab"));
    static assert(!isShortOption("--a"));
    static assert(!isShortOption("--abc"));
}

/**
 * Returns true if the given argument is a long option. That is, if it starts
 * with "--".
 */
private bool isLongOption(string arg) pure nothrow
{
    return arg.length > 2 && arg[0 .. 2] == "--" && arg[2] != '-';
}

unittest
{
    static assert(!isLongOption(""));
    static assert(!isLongOption("a"));
    static assert(!isLongOption("ab"));
    static assert(!isLongOption("abc"));
    static assert(!isLongOption("-"));
    static assert(!isLongOption("-a"));
    static assert(!isLongOption("--"));
    static assert( isLongOption("--a"));
    static assert( isLongOption("--arg"));
}

/**
 * Returns true if the given argument is an option. That is, it is either a
 * short option or a long option.
 */
private bool isOption(string arg) pure nothrow
{
    return isShortOption(arg) || isLongOption(arg);
}

/**
 * Returns an option name without the leading ("--" or "-"). If it is not an
 * option, returns null.
 */
private string optionToName(string option) pure nothrow
{
    if (isLongOption(option))
        return option[2 .. $];

    if (isShortOption(option))
        return option[1 .. $];

    return null;
}

unittest
{
    static assert(optionToName("--opt") == "opt");
    static assert(optionToName("-opt") == "opt");
    static assert(optionToName("-o") == "o");
    static assert(optionToName("opt") is null);
    static assert(optionToName("o") is null);
    static assert(optionToName("") is null);
}

/**
 * Returns the appropriate long or short option corresponding to the given name.
 */
private string nameToOption(string name) pure nothrow
{
    switch (name.length)
    {
        case 0:
            return null;
        case 1:
            return "-" ~ name;
        default:
            return "--" ~ name;
    }
}

unittest
{
    static assert(nameToOption("opt") == "--opt");
    static assert(nameToOption("o") == "-o");
    static assert(nameToOption("") is null);
}

/**
 * Checks if the given type is an option handler.
 */
private enum isOptionHandler(T) =
    is(typeof({
        T handler;
        handler();
    }));

/**
 * Check if the given type is valid for an option.
 */
private template isValidOptionType(T)
{
    import std.traits : isBasicType, isSomeString;

    // FIXME: Allow OptionHandler and ArgumentHandler to have attributes

    static if (isBasicType!T ||
               isSomeString!T ||
               is(T : OptionHandler) ||
               is(T : ArgumentHandler)
        )
    {
        enum isValidOptionType = true;
    }
    else static if (is(T A : A[]))
    {
        enum isValidOptionType = isValidOptionType!A;
    }
    else
    {
        enum isValidOptionType = false;
    }
}

unittest
{
    static assert(isValidOptionType!bool);
    static assert(isValidOptionType!int);
    static assert(isValidOptionType!float);
    static assert(isValidOptionType!char);
    static assert(isValidOptionType!string);
    static assert(isValidOptionType!(int[]));

    alias void Func1();
    alias void Func2(string);
    alias int Func3();
    alias int Func4(string);

    static assert(isValidOptionType!Func1);
    static assert(isValidOptionType!Func2);
    static assert(!isValidOptionType!Func3);
    static assert(!isValidOptionType!Func4);
}

/**
 * Checks if the given options are valid.
 */
private void validateOptions(Options)() pure nothrow
{
    import std.traits : Identity, getUDAs, fullyQualifiedName;

    foreach (member; __traits(allMembers, Options))
    {
        alias symbol = Identity!(__traits(getMember, Options, member));
        alias optUDAs = getUDAs!(symbol, Option);
        alias argUDAs = getUDAs!(symbol, Argument);

        // Basic error checking
        static assert(!(optUDAs.length > 0 && argUDAs.length > 0),
            fullyQualifiedName!symbol ~" cannot be both an Option and an Argument"
            );
        static assert(optUDAs.length <= 1,
            fullyQualifiedName!symbol ~" cannot have multiple Option attributes"
            );
        static assert(argUDAs.length <= 1,
            fullyQualifiedName!symbol ~" cannot have multiple Argument attributes"
            );

        static if (argUDAs.length > 0)
            static assert(isValidOptionType!(typeof(symbol)),
                fullyQualifiedName!symbol ~" is not a valid Argument type"
                );

        static if (optUDAs.length > 0)
            static assert(isValidOptionType!(typeof(symbol)),
                fullyQualifiedName!symbol ~" is not a valid Option type"
                );
    }
}

/**
 * Checks if the given option type has an associated argument. Currently, only
 * an OptionFlag does not have an argument.
 */
private template hasArgument(T)
{
    static if (is(T : OptionFlag) || is(T : OptionHandler))
        enum hasArgument = false;
    else
        enum hasArgument = true;
}

unittest
{
    static assert(hasArgument!string);
    static assert(hasArgument!ArgumentHandler);
    static assert(hasArgument!int);
    static assert(hasArgument!bool);
    static assert(!hasArgument!OptionFlag);
    static assert(!hasArgument!OptionHandler);
}

/**
 * Parses an argument.
 *
 * Throws: ArgParseException if the given argument cannot be converted to the
 * requested type.
 */
T parseArg(T)(string arg) pure
{
    import std.conv : to, ConvException;

    try
    {
        return to!T(arg);
    }
    catch (ConvException e)
    {
        throw new ArgParseException(e.msg);
    }
}

unittest
{
    import std.exception : ce = collectException;

    assert(parseArg!int("42") == 42);
    assert(parseArg!string("42") == "42");
    assert(ce!ArgParseException(parseArg!size_t("-42")));
}

/**
 * Parses options from the given list of arguments. Note that the first argument
 * is assumed to be the program name and is ignored.
 *
 * Returns: Options structure filled out with values.
 *
 * Throws: ArgParseException if arguments are invalid.
 */
Options parseArgs(Options)(string[] args)
    if (is(Options == struct))
{
    import std.traits;
    import std.format : format;
    import std.container.array;

    debug import std.stdio;

    validateOptions!Options;

    Options options;

    args = args[1 .. $];
    string[] argsOnly;

    {
        // Split on "--".
        size_t i = 0;
        while (i < args.length && args[i] != "--")
            ++i;

        if (i < args.length)
        {
            args     = args[0 .. i];
            argsOnly = args[i+1 .. $];
        }
    }

    // Arguments that have been parsed
    bool[] parsed;
    parsed.length = args.length;

    // Parsing occurs in two passes:
    //
    //  1. Parse all options
    //  2. Parse all positional arguments
    //
    // After the first pass, only positional arguments and invalid options will
    // be left.

    for (size_t i = 0; i < args.length; ++i)
    {
        if (immutable name = optionToName(args[i]))
        {
            foreach (member; __traits(allMembers, Options))
            {
                alias symbol = Identity!(__traits(getMember, options, member));
                alias optUDAs = getUDAs!(symbol, Option);

                static if (optUDAs.length > 0)
                {
                    if (optUDAs[0] == name)
                    {
                        parsed[i] = true;

                        static if (hasArgument!(typeof(symbol)))
                        {
                            ++i;

                            if (i >= args.length || isOption(args[i]))
                                throw new ArgParseException(
                                        "Expected argument for option '%s'"
                                        .format(args[i-1])
                                        );

                            static if (is(typeof(symbol) : ArgumentHandler))
                                __traits(getMember, options, member)(args[i]);
                            else
                                __traits(getMember, options, member) =
                                    parseArg!(typeof(symbol))(args[i]);

                            parsed[i] = true;
                        }
                        else
                        {
                            static if (is(typeof(symbol) : OptionHandler))
                                __traits(getMember, options, member)();
                            else static if (is(typeof(symbol) : OptionFlag))
                                __traits(getMember, options, member) =
                                    OptionFlag.yes;
                            else
                                static assert(false);
                        }
                    }
                }
            }
        }
    }

    return options;
}

/// Ditto
unittest
{
    static struct Options
    {
        string testValue;

        @Option("test")
        void test(string arg)
        {
            testValue = arg;
        }

        @Option("help")
        @Help("Prints help on command line arguments.")
        OptionFlag help;

        @Argument("path")
        @Help("Path to the build description.")
        string path;

        @Option("dryrun", "n")
        @Help("Don't make any functional changes. Just print what might"
              " happen.")
        OptionFlag dryRun;

        @Option("threads", "j")
        @Help("The number of threads to use. Default is the number of"
              " logical cores.")
        size_t threads;

        @Option("color")
        @Help("When to colorize the output.")
        string color = "auto";
    }

    immutable options = parseArgs!Options(
            ["myprogram", "blah", "--help", "--test", "test test", "--dryrun", "--threads", "42"]
            );

    assert(options == Options(
            "test test",
            OptionFlag.yes,
            null,
            OptionFlag.yes,
            42,
            "auto",
            ));
}
