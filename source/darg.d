/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Parses arguments.
 *
 * TODO:
 *  - Generate help strings
 *  - Support sub-commands
 *  - Handle enumeration types
 *  - Handle bundled options
 */
module darg;

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
 * Multiplicity of an argument.
 */
enum Multiplicity
{
    optional,
    zeroOrMore,
    oneOrMore,
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
    size_t upperBound = 1; /// Ditto

    this(string name, size_t lowerBound = 1) pure nothrow
    body
    {
        this.name = name;
        this.lowerBound = lowerBound;
        this.upperBound = lowerBound;
    }

    this(string name, size_t lowerBound, size_t upperBound) pure nothrow
    in { assert(lowerBound < upperBound); }
    body
    {
        this.name = name;
        this.lowerBound = lowerBound;
        this.upperBound = upperBound;
    }

    /**
     * An argument with a multiplicity specifier.
     */
    this(string name, Multiplicity multiplicity) pure nothrow
    {
        this.name = name;

        final switch (multiplicity)
        {
            case Multiplicity.optional:
                this.lowerBound = 0;
                this.upperBound = 1;
                break;
            case Multiplicity.zeroOrMore:
                this.lowerBound = 0;
                this.upperBound = size_t.max;
                break;
            case Multiplicity.oneOrMore:
                this.lowerBound = 1;
                this.upperBound = size_t.max;
                break;
        }
    }

    /**
     * Convert to a usage string.
     */
    @property string usage() const pure
    {
        import std.format : format;

        if (lowerBound == 0)
        {
            if (upperBound == 1)
                return "["~ name ~"]";
            else if (upperBound == upperBound.max)
                return "["~ name ~"...]";

            return "["~ name ~"... (up to %d times)]".format(upperBound);
        }
        else if (lowerBound == 1)
        {
            if (upperBound == 1)
                return name;
            else if (upperBound == upperBound.max)
                return name ~ " ["~ name ~"...]";

            return name ~ " ["~ name ~"... (up to %d times)]"
                .format(upperBound-1);
        }

        if (lowerBound == upperBound)
            return name ~" (multiplicity of %d)"
                .format(upperBound);

        return name ~" ["~ name ~"... (between %d and %d times)]"
            .format(lowerBound-1, upperBound-1);
    }
}

unittest
{
    with (Argument("lion"))
    {
        assert(name == "lion");
        assert(lowerBound == 1);
        assert(upperBound == 1);
    }

    with (Argument("tiger", Multiplicity.optional))
    {
        assert(lowerBound == 0);
        assert(upperBound == 1);
    }

    with (Argument("bear", Multiplicity.zeroOrMore))
    {
        assert(lowerBound == 0);
        assert(upperBound == size_t.max);
    }

    with (Argument("dinosaur", Multiplicity.oneOrMore))
    {
        assert(lowerBound == 1);
        assert(upperBound == size_t.max);
    }
}

/**
 * Help string for an option or positional argument.
 */
struct Help
{
    string help;
}

/**
 * Meta variable name.
 */
struct MetaVar
{
    string name;
}

/**
 * Function signatures that can handle arguments or options.
 */
private alias void OptionHandler() pure;
private alias void ArgumentHandler(string) pure; /// Ditto

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
    static assert( isLongOption("--arg=asdf"));
}

/**
 * Returns true if the given argument is an option. That is, it is either a
 * short option or a long option.
 */
private bool isOption(string arg) pure nothrow
{
    return isShortOption(arg) || isLongOption(arg);
}

private static struct OptionSplit
{
    string head;
    string tail;
}

/**
 * Splits an option on "=".
 */
private auto splitOption(string option) pure
{
    size_t i = 0;
    while (i < option.length && option[i] != '=')
        ++i;

    return OptionSplit(
            option[0 .. i],
            (i < option.length) ? option[i+1 .. $] : null
            );
}

unittest
{
    static assert(splitOption("") == OptionSplit("", null));
    static assert(splitOption("--foo") == OptionSplit("--foo", null));
    static assert(splitOption("--foo=") == OptionSplit("--foo", ""));
    static assert(splitOption("--foo=bar") == OptionSplit("--foo", "bar"));
}

private static struct ArgSplit
{
    const(string)[] head;
    const(string)[] tail;
}

/**
 * Splits arguments on "--".
 */
private auto splitArgs(const(string)[] args) pure
{
    size_t i = 0;
    while (i < args.length && args[i] != "--")
        ++i;

    return ArgSplit(
            args[0 .. i],
            (i < args.length) ? args[i+1 .. $] : []
            );
}

unittest
{
    static assert(splitArgs([]) == ArgSplit([], []));
    static assert(splitArgs(["a", "b"]) == ArgSplit(["a", "b"], []));
    static assert(splitArgs(["a", "--"]) == ArgSplit(["a"], []));
    static assert(splitArgs(["a", "--", "b"]) == ArgSplit(["a"], ["b"]));
    static assert(splitArgs(["a", "--", "b", "c"]) == ArgSplit(["a"], ["b", "c"]));
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

    alias void Func1() pure;
    alias void Func2(string) pure;
    alias int Func3();
    alias int Func4(string);
    alias void Func5();
    alias void Func6(string);

    static assert(isValidOptionType!Func1);
    static assert(isValidOptionType!Func2);
    static assert(!isValidOptionType!Func3);
    static assert(!isValidOptionType!Func4);
    static assert(!isValidOptionType!Func5);
    static assert(!isValidOptionType!Func6);
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
 * Constructs a printable usage string at compile time from the given options
 * structure.
 */
string usageString(Options)(string program) pure
    if (is(Options == struct))
{
    import std.traits;
    import std.array : replicate;
    import std.string : wrap, toUpper;

    string output = "usage: "~ program;

    string indent = " ".replicate(output.length + 1);

    // List all options
    foreach (member; __traits(allMembers, Options))
    {
        alias symbol = Identity!(__traits(getMember, Options, member));
        alias optUDAs = getUDAs!(symbol, Option);

        static if (optUDAs.length > 0 && optUDAs[0].names.length > 0)
        {
            output ~= " ["~ nameToOption(optUDAs[0].names[0]);

            // Print argument information, if applicable.
            static if (hasArgument!(typeof(symbol)))
            {
                alias metavar = getUDAs!(symbol, MetaVar);
                static if (metavar.length > 0)
                    output ~= "="~ metavar[0].name;
                else static if (is(typeof(symbol) : ArgumentHandler))
                    output ~= "="~ member.toUpper;
                else
                    output ~= "=<"~ typeof(symbol).stringof ~ ">";
            }

            output ~= "]";
        }
    }

    // List all arguments
    foreach (member; __traits(allMembers, Options))
    {
        alias symbol = Identity!(__traits(getMember, Options, member));
        alias argUDAs = getUDAs!(symbol, Argument);

        static if (argUDAs.length > 0)
            output ~= " "~ argUDAs[0].usage;
    }

    return output.wrap(80, null, indent, 4);
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
 * Parses options from the given list of arguments. Note that the first argument
 * is assumed to be the program name and is ignored.
 *
 * Returns: Options structure filled out with values.
 *
 * Throws: ArgParseException if arguments are invalid.
 */
Options parseArgs(Options)(const(string)[] arguments) pure
    if (is(Options == struct))
{
    import std.traits;
    import std.format : format;
    import std.container.array;
    import std.range : chain, enumerate, empty, front, popFront;
    import std.algorithm.iteration : map, filter;

    debug import std.stdio;

    validateOptions!Options;

    Options options;

    auto args = splitArgs(arguments);

    // Arguments that have been parsed
    bool[] parsed;
    parsed.length = args.head.length;

    // Parsing occurs in two passes:
    //
    //  1. Parse all options
    //  2. Parse all positional arguments
    //
    // After the first pass, only positional arguments and invalid options will
    // be left.

    for (size_t i = 0; i < args.head.length; ++i)
    {
        auto opt = splitOption(args.head[i]);

        if (immutable name = optionToName(opt.head))
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
                            if (opt.tail)
                            {
                                static if (is(typeof(symbol) : ArgumentHandler))
                                    __traits(getMember, options, member)(opt.tail);
                                else
                                    __traits(getMember, options, member) =
                                        parseArg!(typeof(symbol))(opt.tail);
                            }
                            else
                            {
                                ++i;

                                if (i >= args.head.length || isOption(args.head[i]))
                                    throw new ArgParseException(
                                            "Expected argument for option '%s'"
                                            .format(opt.head)
                                            );

                                static if (is(typeof(symbol) : ArgumentHandler))
                                    __traits(getMember, options, member)(args.head[i]);
                                else
                                    __traits(getMember, options, member) =
                                        parseArg!(typeof(symbol))(args.head[i]);

                                parsed[i] = true;
                            }
                        }
                        else
                        {
                            if (opt.tail)
                                throw new ArgParseException(
                                        "Option '%s' does not take an argument"
                                        .format(opt.head)
                                        );

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

    // Any left over options are erroneous
    for (size_t i = 0; i < args.head.length; ++i)
    {
        if (!parsed[i] && isOption(args.head[i]))
        {
            throw new ArgParseException(
                "Invalid option '"~ args.head[i] ~"'"
                );
        }
    }

    // Left over arguments
    auto leftOver = args.head
        .enumerate
        .filter!(a => !parsed[a[0]])
        .map!(a => a[1])
        .chain(args.tail);

    // Only positional arguments are left
    foreach (member; __traits(allMembers, Options))
    {
        alias symbol = Identity!(__traits(getMember, options, member));
        alias argUDAs = getUDAs!(symbol, Argument);

        static if (argUDAs.length > 0)
        {
            // Keep consuming arguments until the multiplicity is satisfied
            for (size_t i = 0; i < argUDAs[0].upperBound; ++i)
            {
                // Out of arguments?
                if (leftOver.empty)
                {
                    if (i >= argUDAs[0].lowerBound)
                        break; // Multiplicity is satisfied

                    throw new ArgParseException(
                        "Multiplicity unsatisfied for '"~ member ~"' argument"
                        );
                }

                // Set argument or add to list of arguments.
                static if (argUDAs[0].upperBound <= 1)
                {
                    static if (is(typeof(symbol) : ArgumentHandler))
                        __traits(getMember, options, member)(leftOver.front);
                    else
                        __traits(getMember, options, member) =
                            parseArg!(typeof(symbol))(leftOver.front);
                }
                else
                {
                    static if (is(typeof(symbol) : ArgumentHandler))
                        __traits(getMember, options, member)(leftOver.front);
                    else
                    {
                        import std.range.primitives : ElementType;
                        __traits(getMember, options, member) ~=
                            parseArg!(ElementType!(typeof(symbol)))(leftOver.front);
                    }
                }

                leftOver.popFront();
            }
        }
    }

    if (!leftOver.empty)
        throw new ArgParseException("Too many arguments specified");

    return options;
}

/// Ditto
unittest
{
    static struct Options
    {
        string testValue;

        @Option("test")
        void test(string arg) pure
        {
            testValue = arg;
        }

        @Option("help")
        @Help("Prints help on command line arguments.")
        OptionFlag help;

        @Option("version")
        @Help("Prints version information.")
        OptionFlag version_;

        @Argument("path", Multiplicity.oneOrMore)
        @Help("Path to the build description.")
        string[] path;

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
        @MetaVar("{auto,always,never}")
        string color = "auto";
    }

    auto options = parseArgs!Options([
            "arg1",
            "--help",
            "--version",
            "--test",
            "test test",
            "--dryrun",
            "--threads",
            "42",
            "--color=test",
            "--",
            "arg2",
        ]);

    assert(options == Options(
            "test test",
            OptionFlag.yes,
            OptionFlag.yes,
            ["arg1", "arg2"],
            OptionFlag.yes,
            42,
            "test",
            ));

    debug
    {
        import std.stdio;
        enum usage = usageString!Options("darg");
        write(usage);
    }
}
