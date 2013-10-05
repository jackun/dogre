module ogregl.glsl.preprocessor;
debug import std.stdio;
import std.string;
import std.conv : to;
import std.ascii;
import ogre.general.log;

enum MAX_MACRO_ARGS = 16;

/// Return closest power of two not smaller than given number
static size_t ClosestPow2 (size_t x)
{
    if (!(x & (x - 1)))
        return x;
    while (x & (x + 1))
        x |= (x + 1);
    return x + 1;
}

/**
 * This is a simplistic C/C++-like preprocessor.
 * It takes an non-zero-terminated string on input and outputs a
 * non-zero-terminated string buffer.
 *
 * This preprocessor was designed specifically for GLSL shaders, so
 * if you want to use it for other purposes you might want to check
 * if the feature set it provides is enough for you.
 *
 * Here's a list of supported features:
 * <ul>
 * <li>Fast memory allocation-less operation (mostly).
 * <li>Line continuation (backslash-newline) is swallowed.
 * <li>Line numeration is fully preserved by inserting empty lines where
 *     required. This is crucial if, say, GLSL compiler reports you an error
 *     with a line number.
 * <li>#define: Parametrized and non-parametrized macros. Invoking a macro with
 *     less arguments than it takes assignes empty values to missing arguments.
 * <li>#undef: Forget defined macros
 * <li>#ifdef/#ifndef/#else/#endif: Conditional suppression of parts of code.
 * <li>#if: Supports numeric expression of any complexity, also supports the
 *     defined() pseudo-function.
 * <ul>
 */

bool isspace(char c)
{
    //static string ws = " \t\n\v\f\r";
    //return ws.indexOf(c) > -1;
    return isWhite(c);
}

bool isxdigit(char c)
{
    //static string xd = "0123456789abcdefABCDEF";
    //return xd.indexOf(c) > -1;
    return isHexDigit(c);
}

bool isdigit(char c)
{
    //static string d = "0123456789";
    //return d.indexOf(c) > -1;
    return isDigit(c);
}

bool isalnum(char c)
{
    return isAlphaNum(c);
}

class CPreprocessor
{
    /**
     * A input token.
     *
     * For performance reasons most tokens will point to portions of the
     * input stream, so no unneeded memory allocation is done. However,
     * in some cases we must allocate different memory for token storage,
     * in this case this is signalled by setting the Allocated member
     * to non-zero in which case the destructor will know that it must
     * free memory on object destruction.
     *
     * Again for performance reasons we use malloc/realloc/free here because
     * C++-style new[] lacks the realloc() counterpart.
     */
    static class Token
    {
    public:
        alias uint Kind;
        enum : Kind
        {
            TK_EOS,          // End of input stream
            TK_ERROR,        // An error has been encountered
            TK_WHITESPACE,   // A whitespace span (but not newline)
            TK_NEWLINE,      // A single newline (CR & LF)
            TK_LINECONT,     // Line continuation ('\' followed by LF)
            TK_NUMBER,       // A number
            TK_KEYWORD,      // A keyword
            TK_PUNCTUATION,  // A punctuation character
            TK_DIRECTIVE,    // A preprocessor directive
            TK_STRING,       // A string
            TK_COMMENT,      // A block comment
            TK_LINECOMMENT,  // A line comment
            TK_TEXT          // An unparsed text (cannot be returned from GetToken())
        }
        
        /// Token type
        Kind Type;
        /// True if string was allocated (and must be freed)
        //mutable 
        size_t Allocated;
        //TODO Use D's slicing 'magic'
        //union
        //{
            /// A pointer somewhere into the input buffer
            //const char *String;
            char[] String; //as slice, changing .length seems to do COW
            /// A memory-allocated string
            //char *Buffer;
            char[] Buffer; //as mutable string
        //}
        /// Token length in bytes
        size_t Length;
        
        this () //Allocated (0), String (NULL)
        { }
        
        this (Kind iType) //: Type (iType), Allocated (0), String (NULL)
        { Type = iType; }
        
        this (Kind iType, char[] iString , size_t iLength = 0) 
        //: Type (iType), Allocated (0), String (iString), Length (iLength)
        { Type = iType;
            Buffer = iString; //TODO Hm, so slice to CPreprocessor.Source, until reallocated in Append
            String = Buffer[0..$];
            Length = iString.length; }
        
        this (Token iOther)
        {
            Type = iOther.Type;
            Allocated = iOther.Allocated;
            iOther.Allocated = 0; // !!! not quite correct but effective
            Buffer = iOther.String;
            String = Buffer[0..$];
            Length = iOther.Length;
        }
        
        ~this ()
        { if (Allocated) destroy (Buffer); }
        
        /// Assignment operator -- illegal for class
        /*Token opAssign (const Token &iOther)
        {
            if (Allocated) free (Buffer);
            Type = iOther.Type;
            Allocated = iOther.Allocated;
            iOther.Allocated = 0; // !!! not quite correct but effective
            String = iOther.String;
            Length = iOther.Length;
            return *this;
        }*/
        
        /// Append a string to this token
        void Append (char[] iString/*, size_t iLength*/)
        {
            Token t = new Token (Token.TK_TEXT, iString/*, iLength*/);
            Append (t);
        }
        
        /// Append a token to this token
        void Append (Token iOther)
        {
            if (iOther.String is null)
                return;
            
            //if (String is null)
            if (Buffer is null)
            {
                Buffer = iOther.String;
                String = Buffer[0..$];
                Length = iOther.Length;
                Allocated = iOther.Allocated;
                iOther.Allocated = 0; // !!! not quite correct but effective
                return;
            }

            //TODO Necessery ???
            if (Allocated)
            {
                size_t new_alloc = ClosestPow2 (Length + iOther.Length);
                if (new_alloc < 64)
                    new_alloc = 64;
                if (new_alloc != Allocated)
                {
                    Allocated = new_alloc;
                    //Buffer = (char *)realloc (Buffer, Allocated);
                    Buffer.length = Allocated;
                }
            }
            else if (String.ptr + Length != iOther.String.ptr)
            {
                Allocated = ClosestPow2 (Length + iOther.Length);
                if (Allocated < 64)
                    Allocated = 64;
                //char *newstr = (char *)malloc (Allocated);
                //memcpy (newstr, String, Length);
                //Buffer = newstr;
                //char[] newstr = new char[Allocated];
                //newstr[0..String.length] = String;
                //Buffer = newstr;
                Buffer.length = Allocated; //FIXME probably suffices
            }
            
            if (Allocated)
            //    memcpy (Buffer + Length, iOther.String, iOther.Length);
                Buffer[Length..Length+iOther.Length] = iOther.String;
            Length += iOther.Length;
        }
        
        /// Append given number of newlines to this token
        void AppendNL (int iCount)
        {
            static char[] newlines =
            [ '\n', '\n', '\n', '\n', '\n', '\n', '\n', '\n' ];
            
            while (iCount > 8)
            {
                Append (newlines);//, 8);
                iCount -= 8;
            }
            if (iCount > 0)
                Append (newlines[0..iCount]);//, iCount);
        }
        
        /// Count number of newlines in this token
        int CountNL ()
        {
            if (Type == TK_EOS || Type == TK_ERROR)
                return 0;

            int c = 0;
            /*char[] s = String;
            int l = Length;
            while (l > 0)
            {
                const char *n = (const char *)memchr (s, '\n', l);
                if (!n)
                    return c;
                c++;
                l -= (n - s + 1);
                s = n + 1;
            }*/
            foreach(n; String)
                if(n == '\n') c++;
            return c;
        }
        
        /// Get the numeric value of the token
        bool GetValue (ref long oValue) const
        {
            long val = 0;
            size_t i = 0;
            
            while (isspace (String [i]))
                i++;
            
            long base = 10;
            if (String [i] == '0')
            {
                if (Length > i + 1 && String [i + 1] == 'x')
                    base = 16, i += 2;
                else
                    base = 8;
            }
            
            for (; i < Length; i++)
            {
                int c = cast(int)String [i];
                if (isspace (String [i]))
                    // Possible end of number
                    break;
                
                if (c >= 'a' && c <= 'z')
                    c -= ('a' - 'A');
                
                c -= '0';
                if (c < 0)
                    return false;
                
                if (c > 9)
                    c -= ('A' - '9' - 1);
                
                if (c >= base)
                    return false;
                
                val = (val * base) + c;
            }
            
            // Check that all other characters are just spaces
            for (; i < Length; i++)
                if (!isspace (String [i]))
                    return false;
            
            oValue = val;
            return true;
        }

        
        /// Set the numeric value of the token
        void SetValue (long iValue)
        {
            Length = 0;
            char[] tmp = std.conv.to!string(iValue).dup;
            Append (tmp);
            Type = TK_NUMBER;
        }

        alias Object.opEquals opEquals;
        /// Test two tokens for equality
        bool opEquals (Token iOther)
        {
            if (iOther.Length != Length)
                return false;
            return (String == iOther.String);
        }
    }
    
    /// A macro definition
    package static class Macro
    {
    public:
        /// Macro name
        Token Name;
        /// Number of arguments
        int NumArgs;
        /// The names of the arguments
        Token[] Args;
        /// The macro value
        Token Value;
        /// Unparsed macro body (keeps the whole raw unparsed macro body)
        Token Body;
        /// Next macro in chained list
        Macro Next;
        /// A pointer to function implementation (if macro is really a func)
        alias Token function (CPreprocessor iParent, int iNumArgs, Token[] iArgs) da_ExpandFunc;
        da_ExpandFunc ExpandFunc;
        /// true if macro expansion is in progress
        bool Expanding;
        
        this (Token iName) 
         //:NumArgs (0), Args (NULL), Next (NULL),
         //   ExpandFunc (NULL), Expanding (false)
        { Name = iName; Value = new Token;}
        
        ~this ()
        { destroy(Args); destroy(Next); } //TODO Probably can do without
        
        /// Expand the macro value (will not work for functions)
        Token Expand (int iNumArgs, Token[] iArgs, Macro iMacros)
        {
            Expanding = true;
            
            CPreprocessor cpp = new CPreprocessor;
            cpp.MacroList = iMacros;
            
            // Define a new macro for every argument
            int i;
            for (i = 0; i < iNumArgs; i++)
                cpp.Define (Args [i].String, Args [i].Length,
                            iArgs [i].String, iArgs [i].Length);
            // The rest arguments are empty
            for (; i < NumArgs; i++)
                cpp.Define (Args [i].String, Args [i].Length, ['\0'], 0);
            
            // Now run the macro expansion through the supplimentary preprocessor
            Token xt = cpp.Parse (Value);
            
            Expanding = false;
            
            // Remove the extra macros we have defined
            for (int j = NumArgs - 1; j >= 0; j--)
                cpp.Undef (Args [j].String, Args [j].Length);
            
            cpp.MacroList = null;
            
            return xt;
        }
    }
    
    //friend class CPreprocessor::Macro;
    
    /// The current source text input
    char[] Source;
    /// The end of the source text
    size_t SourceStart; //TODO just index?
    size_t SourceEnd; //TODO just index?
    /// Current line number
    int Line;
    /// True if we are at beginning of line
    bool BOL;
    /// A stack of 32 booleans packed into one value :)
    uint EnableOutput;
    /// The list of macros defined so far
    Macro MacroList; //linked list stuff?
    
    /**
     * Private constructor to re-parse a single token.
     */
    this (Token iToken, int iLine)
    {
        Source = iToken.String;
        SourceEnd = iToken.Length;
        EnableOutput = 1;
        Line = iLine;
        BOL = true;
    }
    
    /**
     * Stateless tokenizer: Parse the input text and return the next token.
     * @param iExpand
     *     If true, macros will be expanded to their values
     * @return
     *     The next token from the input stream
     */
    Token GetToken (bool iExpand)
    {
        if (SourceStart >= SourceEnd)
            return new Token (Token.TK_EOS);
        
        size_t begin = SourceStart;
        char c = Source[SourceStart++];
        
        
        if (c == '\n' || (c == '\r' && Source[SourceStart] == '\n'))
        {
            Line++;
            BOL = true;
            if (c == '\r')
                SourceStart++;
            return new Token (Token.TK_NEWLINE, Source[begin..SourceStart], SourceStart - begin);
        }
        else if (isspace (c))
        {
            while (SourceStart < SourceEnd &&
                   Source[SourceStart] != '\r' &&
                   Source[SourceStart] != '\n' &&
                   isspace (Source[SourceStart]))
                SourceStart++;
            
            return new Token (Token.TK_WHITESPACE, Source[begin..SourceStart], SourceStart - begin);
        }
        else if (isdigit (c))
        {
            BOL = false;
            if (c == '0' && SourceStart < SourceEnd && Source [0] == 'x') // hex numbers
            {
                SourceStart++;
                while (SourceStart < SourceEnd && isxdigit (Source[SourceStart]))
                    SourceStart++;
            }
            else
                while (SourceStart < SourceEnd && isdigit (Source[SourceStart]))
                    SourceStart++;
            return new Token (Token.TK_NUMBER, Source[begin..SourceStart], SourceStart - begin);
        }
        else if (c == '_' || isalnum (c))
        {
            BOL = false;
            while (SourceStart < SourceEnd && (Source[SourceStart] == '_' || isalnum (Source[SourceStart])))
                SourceStart++;
            Token t = new Token(Token.TK_KEYWORD, Source[begin..SourceStart], SourceStart - begin);
            if (iExpand)
                t = ExpandMacro (t);
            return t;
        }
        else if (c == '"' || c == '\'')
        {
            BOL = false;
            while (SourceStart < SourceEnd && Source[SourceStart] != c)
            {
                if (Source[SourceStart] == '\\')
                {
                    SourceStart++;
                    if (SourceStart >= SourceEnd)
                        break;
                }
                if (Source[SourceStart] == '\n')
                    Line++;
                SourceStart++;
            }
            if (SourceStart < SourceEnd)
                SourceStart++;
            return new Token (Token.TK_STRING, Source[begin..SourceStart], SourceStart - begin);
        }
        else if (c == '/' && Source[SourceStart] == '/')
        {
            BOL = false;
            SourceStart++;
            while (SourceStart < SourceEnd && Source[SourceStart] != '\r' && Source[SourceStart] != '\n')
                SourceStart++;
            return new Token (Token.TK_LINECOMMENT, Source[begin..SourceStart], SourceStart - begin);
        }
        else if (c == '/' && Source[SourceStart] == '*')
        {
            BOL = false;
            SourceStart++;
            while (SourceStart < SourceEnd && (Source [0] != '*' || Source [1] != '/'))
            {
                if (Source[SourceStart] == '\n')
                    Line++;
                SourceStart++;
            }
            if (SourceStart < SourceEnd && Source[SourceStart] == '*')
                SourceStart++;
            if (SourceStart < SourceEnd && Source[SourceStart] == '/')
                SourceStart++;
            return new Token (Token.TK_COMMENT, Source[begin..SourceStart], SourceStart - begin);
        }
        else if (c == '#' && BOL)
        {
            // Skip all whitespaces after '#'
            while (SourceStart < SourceEnd && isspace (Source[SourceStart]))
                SourceStart++;
            while (SourceStart < SourceEnd && !isspace (Source[SourceStart]))
                SourceStart++;
            return new Token (Token.TK_DIRECTIVE, Source[begin..SourceStart], SourceStart - begin);
        }
        else if (c == '\\' && SourceStart < SourceEnd && (Source[SourceStart] == '\r' || Source[SourceStart] == '\n'))
        {
            // Treat backslash-newline as a whole token
            if (Source[SourceStart] == '\r')
                SourceStart++;
            if (Source[SourceStart] == '\n')
                SourceStart++;
            Line++;
            BOL = true;
            return new Token (Token.TK_LINECONT, Source[begin..SourceStart], SourceStart - begin);
        }
        else
        {
            BOL = false;
            // Handle double-char operators here
            if (c == '>' && (Source[SourceStart] == '>' || Source[SourceStart] == '='))
                SourceStart++;
            else if (c == '<' && (Source[SourceStart] == '<' || Source[SourceStart] == '='))
                SourceStart++;
            else if (c == '!' && Source[SourceStart] == '=')
                SourceStart++;
            else if (c == '=' && Source[SourceStart] == '=')
                SourceStart++;
            else if ((c == '|' || c == '&' || c == '^') && Source[SourceStart] == c)
                SourceStart++;
            return new Token (Token.TK_PUNCTUATION, Source[begin..SourceStart], SourceStart - begin);
        }
    }
    
    /**
     * Handle a preprocessor directive.
     * @param iToken
     *     The whole preprocessor directive line (until EOL)
     * @param iLine
     *     The line where the directive begins (for error reports)
     * @return
     *     The last input token that was not proceeded.
     */
    Token HandleDirective (Token iToken, int iLine)
    {
        // strip and opEquals between char[] and string should work

        // Analyze preprocessor directive
        char[] directive = std.string.strip(iToken.String);// + 1;
        size_t dirlen = directive.length; //iToken.Length - 1;
        //while (dirlen && isspace (directive[dirlen]))
        //    dirlen--, directive++;
        
        int old_line = Line;
        
        // Collect the remaining part of the directive until EOL
        Token t, last;
        do
        {
            t = GetToken (false);
            if (t.Type == Token.TK_NEWLINE)
            {
                // No directive arguments
                last = t;
                t.Length = 0;
                goto Done;
            }
        } while (t.Type == Token.TK_WHITESPACE ||
                 t.Type == Token.TK_LINECONT ||
                 t.Type == Token.TK_COMMENT ||
                 t.Type == Token.TK_LINECOMMENT);
        
        for (;;)
        {
            last = GetToken (false);
            switch (last.Type)
            {
                case Token.TK_EOS:
                    // Can happen and is not an error
                    goto Done;
                    
                case Token.TK_LINECOMMENT:
                case Token.TK_COMMENT:
                    // Skip comments in macros
                    continue;
                    
                case Token.TK_ERROR:
                    return last;
                    
                case Token.TK_LINECONT:
                    continue;
                    
                case Token.TK_NEWLINE:
                    goto Done;
                    
                default:
                    break;
            }
            
            t.Append (last);
            t.Type = Token.TK_TEXT;
        }
    Done:
        
        bool IS_DIRECTIVE(string s)
        {
            return (dirlen == s.length && (directive == s));
        }
        
        bool outputEnabled = ((EnableOutput & (EnableOutput + 1)) == 0);
        bool rc;
        
        if (IS_DIRECTIVE ("define") && outputEnabled)
            rc = HandleDefine (t, iLine);
        else if (IS_DIRECTIVE ("undef") && outputEnabled)
            rc = HandleUnDef (t, iLine);
        else if (IS_DIRECTIVE ("ifdef"))
            rc = HandleIfDef (t, iLine);
        else if (IS_DIRECTIVE ("ifndef"))
        {
            rc = HandleIfDef (t, iLine);
            if (rc)
                EnableOutput ^= 1;
        }
        else if (IS_DIRECTIVE ("if"))
            rc = HandleIf (t, iLine);
        
        else if (IS_DIRECTIVE ("else"))
            rc = HandleElse (t, iLine);
        else if (IS_DIRECTIVE ("endif"))
            rc = HandleEndIf (t, iLine);
        else
        {
            //Error (iLine, "Unknown preprocessor directive", &iToken);
            //return Token (Token.TK_ERROR);
            
            // Unknown preprocessor directive, roll back and pass through
            Line = old_line;
            SourceStart = (iToken.String.ptr - Source.ptr) + iToken.Length; //FIXME like seriously :P
            iToken.Type = Token.TK_TEXT;
            return iToken;
        }

        
        if (!rc)
            return new Token (Token.TK_ERROR);
        return last;
    }
    
    /**
     * Handle a #define directive.
     * @param iBody
     *     The body of the directive (everything after the directive
     *     until end of line).
     * @param iLine
     *     The line where the directive begins (for error reports)
     * @return
     *     true if everything went ok, false if not
     */
    bool HandleDefine (Token iBody, int iLine)
    {
        // Create an additional preprocessor to process macro body
        CPreprocessor cpp = new CPreprocessor(iBody, iLine);
        
        Token t = cpp.GetToken (false);
        if (t.Type != Token.TK_KEYWORD)
        {
            Error (iLine, "Macro name expected after #define");
            return false;
        }
        
        Macro m = new Macro (t);
        m.Body = iBody;
        t = cpp.GetArguments (m.NumArgs, m.Args, false);
        while (t.Type == Token.TK_WHITESPACE)
            t = cpp.GetToken (false);
        
        switch (t.Type)
        {
            case Token.TK_NEWLINE:
            case Token.TK_EOS:
                // Assign "" to token
                t = new Token (Token.TK_TEXT, ['\0'], 0);
                break;
                
            case Token.TK_ERROR:
                destroy(m);
                return false;
                
            default:
                t.Type = Token.TK_TEXT;
                assert (t.String.ptr + t.Length == cpp.Source.ptr);
                t.Length = cpp.SourceEnd - (t.String.ptr - cpp.Source.ptr);
                break;
        }
        
        m.Value = t;
        m.Next = MacroList;
        MacroList = m;
        return true;
    }
    
    /**
     * Undefine a previously defined macro
     * @param iBody
     *     The body of the directive (everything after the directive
     *     until end of line).
     * @param iLine
     *     The line where the directive begins (for error reports)
     * @return
     *     true if everything went ok, false if not
     */
    bool HandleUnDef (Token iBody, int iLine)
    {
        CPreprocessor cpp = new CPreprocessor(iBody, iLine);
        
        Token t = cpp.GetToken (false);
        
        if (t.Type != Token.TK_KEYWORD)
        {
            Error (iLine, "Expecting a macro name after #undef, got", t);
            return false;
        }
        
        // Don't barf if macro does not exist - standard C behaviour
        Undef (t.String, t.Length);
        
        do
        {
            t = cpp.GetToken (false);
        } while (t.Type == Token.TK_WHITESPACE ||
                 t.Type == Token.TK_COMMENT ||
                 t.Type == Token.TK_LINECOMMENT);
        
        if (t.Type != Token.TK_EOS)
            Error (iLine, "Warning: Ignoring garbage after directive", t);
        
        return true;
    }
    
    /**
     * Handle an #ifdef directive.
     * @param iBody
     *     The body of the directive (everything after the directive
     *     until end of line).
     * @param iLine
     *     The line where the directive begins (for error reports)
     * @return
     *     true if everything went ok, false if not
     */
    bool HandleIfDef (Token iBody, int iLine)
    {
        if (EnableOutput & (1 << 31))
        {
            Error (iLine, "Too many embedded #if directives");
            return false;
        }
        
        CPreprocessor cpp = new CPreprocessor(iBody, iLine);
        
        Token t = cpp.GetToken (false);
        
        if (t.Type != Token.TK_KEYWORD)
        {
            Error (iLine, "Expecting a macro name after #ifdef, got", t);
            return false;
        }
        
        EnableOutput <<= 1;
        if (IsDefined (t))
            EnableOutput |= 1;
        
        do
        {
            t = cpp.GetToken (false);
        } while (t.Type == Token.TK_WHITESPACE ||
                 t.Type == Token.TK_COMMENT ||
                 t.Type == Token.TK_LINECOMMENT);
        
        if (t.Type != Token.TK_EOS)
            Error (iLine, "Warning: Ignoring garbage after directive", t);
        
        return true;
    }
    
    /**
     * Handle an #if directive.
     * @param iBody
     *     The body of the directive (everything after the directive
     *     until end of line).
     * @param iLine
     *     The line where the directive begins (for error reports)
     * @return
     *     true if everything went ok, false if not
     */
    bool HandleIf (Token iBody, int iLine)
    {
        Macro defined = new Macro (new Token (Token.TK_KEYWORD, "defined".dup, 7));
        defined.Next = MacroList;
        defined.ExpandFunc = &ExpandDefined;
        defined.NumArgs = 1;
        
        // Temporary add the defined() function to the macro list
        MacroList = defined;
        
        long val;
        bool rc = GetValue (iBody, val, iLine);
        
        // Restore the macro list
        MacroList = defined.Next;
        defined.Next = null;
        
        if (!rc)
            return false;
        
        EnableOutput <<= 1;
        if (val)
            EnableOutput |= 1;
        
        return true;
    }
    
    /**
     * Handle an #else directive.
     * @param iBody
     *     The body of the directive (everything after the directive
     *     until end of line).
     * @param iLine
     *     The line where the directive begins (for error reports)
     * @return
     *     true if everything went ok, false if not
     */
    bool HandleElse (Token iBody, int iLine)
    {
        if (EnableOutput == 1)
        {
            Error (iLine, "#else without #if");
            return false;
        }
        
        // Negate the result of last #if
        EnableOutput ^= 1;
        
        if (iBody.Length)
            Error (iLine, "Warning: Ignoring garbage after #else", iBody);
        
        return true;
    }
    
    /**
     * Handle an #endif directive.
     * @param iBody
     *     The body of the directive (everything after the directive
     *     until end of line).
     * @param iLine
     *     The line where the directive begins (for error reports)
     * @return
     *     true if everything went ok, false if not
     */
    bool HandleEndIf (Token iBody, int iLine)
    {
        EnableOutput >>= 1;
        if (EnableOutput == 0)
        {
            Error (iLine, "#endif without #if");
            return false;
        }
        
        if (iBody.Length)
            Error (iLine, "Warning: Ignoring garbage after #endif", iBody);
        
        return true;
    }
    
    /**
     * Get a single function argument until next ',' or ')'.
     * @param oArg
     *     The argument is returned in this variable.
     * @param iExpand
     *     If false, parameters are not expanded and no expressions are
     *     allowed; only a single keyword is expected per argument.
     * @return
     *     The first unhandled token after argument.
     */
    Token GetArgument (ref Token oArg, bool iExpand)
    {
        do
        {
            oArg = GetToken (iExpand);
        } while (oArg.Type == Token.TK_WHITESPACE ||
                 oArg.Type == Token.TK_NEWLINE ||
                 oArg.Type == Token.TK_COMMENT ||
                 oArg.Type == Token.TK_LINECOMMENT ||
                 oArg.Type == Token.TK_LINECONT);
        
        if (!iExpand)
        {
            if (oArg.Type == Token.TK_EOS)
                return oArg;
            else if (oArg.Type == Token.TK_PUNCTUATION &&
                     (oArg.String [0] == ',' ||
             oArg.String [0] == ')'))
            {
                Token t = oArg;
                oArg = new Token (Token.TK_TEXT, ['\0'], 0);
                return t;
            }
            else if (oArg.Type != Token.TK_KEYWORD)
            {
                Error (Line, "Unexpected token", oArg);
                return new Token (Token.TK_ERROR);
            }
        }
        
        uint len = cast(uint)oArg.Length;
        while (true)
        {
            Token t = GetToken (iExpand);
            switch (t.Type)
            {
                case Token.TK_EOS:
                    Error (Line, "Unfinished list of arguments");
                case Token.TK_ERROR:
                    return new Token (Token.TK_ERROR);
                case Token.TK_PUNCTUATION:
                    if (t.String [0] == ',' ||
                        t.String [0] == ')')
                    {
                        // Trim whitespaces at the end
                        oArg.Length = len;
                        return t;
                    }
                    break;
                case Token.TK_LINECONT:
                case Token.TK_COMMENT:
                case Token.TK_LINECOMMENT:
                case Token.TK_NEWLINE:
                    // ignore these tokens
                    continue;
                default:
                    break;
            }
            
            if (!iExpand && t.Type != Token.TK_WHITESPACE)
            {
                Error (Line, "Unexpected token", oArg);
                return new Token (Token.TK_ERROR);
            }
            
            oArg.Append (t);
            
            if (t.Type != Token.TK_WHITESPACE)
                len = cast(uint)oArg.Length;
        }
    }
    
    /**
     * Get all the arguments of a macro: '(' arg1 { ',' arg2 { ',' ... }} ')'
     * @param oNumArgs
     *     Number of parsed arguments is stored into this variable.
     * @param oArgs
     *     This is set to a pointer to an array of parsed arguments.
     * @param iExpand
     *     If false, parameters are not expanded and no expressions are
     *     allowed; only a single keyword is expected per argument.
     */
    Token GetArguments (ref int oNumArgs, ref Token[] oArgs, bool iExpand)
    {
        //Token[MAX_MACRO_ARGS] args;
        Token arg;
        int nargs = 0;
        
        // Suppose we'll leave by the wrong path
        oNumArgs = 0;
        oArgs = null;
        
        Token t;
        do
        {
            t = GetToken (iExpand);
        } while (t.Type == Token.TK_WHITESPACE ||
                 t.Type == Token.TK_COMMENT ||
                 t.Type == Token.TK_LINECOMMENT);
        
        if (t.Type != Token.TK_PUNCTUATION || t.String [0] != '(')
        {
            oNumArgs = 0;
            oArgs = null;
            return t;
        }
        
        while (true)
        {
            if (nargs == MAX_MACRO_ARGS)
            {
                Error (Line, "Too many arguments to macro");
                return new Token (Token.TK_ERROR);
            }
            
            //t = GetArgument (args [nargs++], iExpand);
            t = GetArgument (arg, iExpand);

            switch (t.Type)
            {
                case Token.TK_EOS:
                    Error (Line, "Unfinished list of arguments");
                case Token.TK_ERROR:
                    return new Token (Token.TK_ERROR);
                    
                case Token.TK_PUNCTUATION:
                    if (t.String [0] == ')')
                    {
                        t = GetToken (iExpand);
                        //goto Done;
                        return t;
                    } // otherwise we've got a ','
                    break;
                    
                default:
                    Error (Line, "Unexpected token", t);
                    break;
            }
            //FIXME Before switch or here, after switch?
            oArgs ~= arg;
            oNumArgs++;
        }
        
    /*Done:
        oNumArgs = nargs;
        oArgs = new Token [nargs];
        for (int i = 0; i < nargs; i++)
            oArgs [i] = args [i];*/
        return t;
    }
    
    /**
     * Parse an expression, compute it and return the result.
     * @param oResult
     *     A token containing the result of expression
     * @param iLine
     *     The line at which the expression starts (for error reports)
     * @param iOpPriority
     *     Operator priority (at which operator we will stop if
     *     proceeding recursively -- used internally. Parser stops
     *     when it encounters an operator with higher or equal priority).
     * @return
     *     The last unhandled token after the expression
     */
    Token GetExpression (ref Token oResult, int iLine, int iOpPriority = 0)
    {        
        do
        {
            oResult = GetToken (true);
        } while (oResult.Type == Token.TK_WHITESPACE ||
                 oResult.Type == Token.TK_NEWLINE ||
                 oResult.Type == Token.TK_COMMENT ||
                 oResult.Type == Token.TK_LINECOMMENT ||
                 oResult.Type == Token.TK_LINECONT);
        
        Token op = new Token (Token.TK_WHITESPACE, ['\0'], 0);
        
        // Handle unary operators here
        if (oResult.Type == Token.TK_PUNCTUATION && oResult.Length == 1)
        {
            if ("+-!~".indexOf(oResult.String [0]) > -1)
            {
                char uop = oResult.String [0];
                op = GetExpression (oResult, iLine, 12);
                long val;
                if (!GetValue (oResult, val, iLine))
                {
                    string tmp = "Unary '"~ uop ~"' not applicable";
                    Error (iLine, tmp, oResult);
                    return new Token (Token.TK_ERROR);
                }
                
                if (uop == '-')
                    oResult.SetValue (-val);
                else if (uop == '!')
                    oResult.SetValue (!val);
                else if (uop == '~')
                    oResult.SetValue (~val);
            }
            else if (oResult.String [0] == '(')
            {
                op = GetExpression (oResult, iLine, 1);
                if (op.Type == Token.TK_ERROR)
                    return op;
                if (op.Type == Token.TK_EOS)
                {
                    Error (iLine, "Unclosed parenthesis in #if expression");
                    return new Token (Token.TK_ERROR);
                }
                
                assert (op.Type == Token.TK_PUNCTUATION &&
                        op.Length == 1 &&
                        op.String [0] == ')');
                op = GetToken (true);
            }
        }
        
        while (op.Type == Token.TK_WHITESPACE ||
               op.Type == Token.TK_NEWLINE ||
               op.Type == Token.TK_COMMENT ||
               op.Type == Token.TK_LINECOMMENT ||
               op.Type == Token.TK_LINECONT)
            op = GetToken (true);
        
        while (true)
        {
            if (op.Type != Token.TK_PUNCTUATION)
                return op;
            
            int prio = 0;
            if (op.Length == 1)
                switch (op.String [0])
            {
                case ')': return op;
                case '|': prio = 4; break;
                case '^': prio = 5; break;
                case '&': prio = 6; break;
                case '<':
                case '>': prio = 8; break;
                case '+':
                case '-': prio = 10; break;
                case '*':
                case '/':
                case '%': prio = 11; break;
                default:
                    break;//TODO blow up?
            }
            else if (op.Length == 2)
                switch (op.String [0])
            {
                case '|': if (op.String [1] == '|') prio = 2; break;
                case '&': if (op.String [1] == '&') prio = 3; break;
                case '=': if (op.String [1] == '=') prio = 7; break;
                case '!': if (op.String [1] == '=') prio = 7; break;
                case '<':
                if (op.String [1] == '=')
                    prio = 8;
                else if (op.String [1] == '<')
                    prio = 9;
                break;
                case '>':
                if (op.String [1] == '=')
                    prio = 8;
                else if (op.String [1] == '>')
                    prio = 9;
                break;
                default:
                break;//TODO blow up?
            }
            
            if (!prio)
            {
                Error (iLine, "Expecting operator, got", op);
                return new Token (Token.TK_ERROR);
            }
            
            if (iOpPriority >= prio)
                return op;
            
            Token rop;
            Token nextop = GetExpression (rop, iLine, prio);
            long vlop, vrop;
            if (!GetValue (oResult, vlop, iLine))
            {
                string tmp = "Left operand of '"~to!string(op.String[0..op.Length])~"' is not a number";
                          //int (op.Length), op.String);
                Error (iLine, tmp, oResult);
                return new Token (Token.TK_ERROR);
            }
            if (!GetValue (rop, vrop, iLine))
            {
                string tmp = "Right operand of '"~to!string(op.String[0..op.Length])~"' is not a number";
                          //int (op.Length), op.String);
                Error (iLine, tmp, rop);
                return new Token (Token.TK_ERROR);
            }
            
            switch (op.String [0])
            {
                case '|':
                    if (prio == 2)
                        oResult.SetValue (vlop || vrop);
                    else
                        oResult.SetValue (vlop | vrop);
                    break;
                case '&':
                    if (prio == 3)
                        oResult.SetValue (vlop && vrop);
                    else
                        oResult.SetValue (vlop & vrop);
                    break;
                case '<':
                    if (op.Length == 1)
                        oResult.SetValue (vlop < vrop);
                    else if (prio == 8)
                        oResult.SetValue (vlop <= vrop);
                    else if (prio == 9)
                        oResult.SetValue (vlop << vrop);
                    break;
                case '>':
                    if (op.Length == 1)
                        oResult.SetValue (vlop > vrop);
                    else if (prio == 8)
                        oResult.SetValue (vlop >= vrop);
                    else if (prio == 9)
                        oResult.SetValue (vlop >> vrop);
                    break;
                case '^': oResult.SetValue (vlop ^ vrop); break;
                case '!': oResult.SetValue (vlop != vrop); break;
                case '=': oResult.SetValue (vlop == vrop); break;
                case '+': oResult.SetValue (vlop + vrop); break;
                case '-': oResult.SetValue (vlop - vrop); break;
                case '*': oResult.SetValue (vlop * vrop); break;
                case '/':
                case '%':
                    if (vrop == 0)
                    {
                        Error (iLine, "Division by zero");
                        return new Token (Token.TK_ERROR);
                    }
                    if (op.String [0] == '/')
                        oResult.SetValue (vlop / vrop);
                    else
                        oResult.SetValue (vlop % vrop);
                    break;
                default:
                    break;//TODO blow up?
            }
            
            op = nextop;
        }
    }
    
    /**
     * Get the numeric value of a token.
     * If the token was produced by expanding a macro, we will get
     * an TEXT token which can contain a whole expression; in this
     * case we will call GetExpression to parse it. Otherwise we
     * just call the token's GetValue() method.
     * @param iToken
     *     The token to get the numeric value of
     * @param oValue
     *     The variable to put the value into
     * @param iLine
     *     The line where the directive begins (for error reports)
     * @return
     *     true if ok, false if not
     */
    bool GetValue (Token iToken, ref long oValue, int iLine)
    {
        Token r;
        Token *vt = &iToken;
        
        if ((vt.Type == Token.TK_KEYWORD ||
             vt.Type == Token.TK_TEXT ||
             vt.Type == Token.TK_NUMBER) &&
            !vt.String)
        {
            Error (iLine, "Trying to evaluate an empty expression");
            return false;
        }
        
        if (vt.Type == Token.TK_TEXT)
        {
            CPreprocessor cpp = new CPreprocessor (iToken, iLine);
            cpp.MacroList = MacroList;
            
            Token t;
            t = cpp.GetExpression (r, iLine);
            
            cpp.MacroList = null;
            
            if (t.Type == Token.TK_ERROR)
                return false;
            
            if (t.Type != Token.TK_EOS)
            {
                Error (iLine, "Garbage after expression", t);
                return false;
            }
            
            vt = &r;
        }
        
        Macro m;
        switch (vt.Type)
        {
            case Token.TK_EOS:
            case Token.TK_ERROR:
                return false;
                
            case Token.TK_KEYWORD:
                // Try to expand the macro
                if ((m = IsDefined (*vt)) !is null && !m.Expanding)
                {
                    Token x = ExpandMacro (*vt);
                    m.Expanding = true;
                    bool rc = GetValue (x, oValue, iLine);
                    m.Expanding = false;
                    return rc;
                }
                
                // Undefined macro, "expand" to 0 (mimic cpp behaviour)
                oValue = 0;
                break;
                
            case Token.TK_TEXT:
            case Token.TK_NUMBER:
                if (!vt.GetValue (oValue))
                {
                    Error (iLine, "Not a numeric expression", *vt);
                    return false;
                }
                break;
                
            default:
                Error (iLine, "Unexpected token", *vt);
                return false;
        }
        
        return true;
    }
    
    /**
     * Expand the given macro, if it exists.
     * If macro has arguments, they are collected from source stream.
     * @param iToken
     *     A KEYWORD token containing the (possible) macro name.
     * @return
     *     The expanded token or iToken if it is not a macro
     */
    Token ExpandMacro (const (Token) iToken)
    {
        Macro cur = IsDefined (iToken);
        if (cur && !cur.Expanding)
        {
            Token[] args;
            int nargs = 0;
            int old_line = Line;
            
            if (cur.NumArgs != 0)
            {
                Token t = GetArguments (nargs, args, cur.ExpandFunc ? false : true);
                if (t.Type == Token.TK_ERROR)
                {
                    //delete [] args;
                    args = null;
                    return t;
                }
                
                // Put the token back into the source pool; we'll handle it later
                if (t.String)
                {
                    // Returned token should never be allocated on heap
                    assert (t.Allocated == 0);
                    SourceStart = t.String.ptr - Source.ptr;
                    Line -= t.CountNL ();
                }
            }
            
            if (nargs > cur.NumArgs)
            {
                string tmp = std.conv.text("Macro `",cur.Name.String[0..cur.Name.Length],
                                           "' passed ",
                                           nargs," arguments, but takes just ",
                                           cur.NumArgs," or CPreprocessor.GetArguments is busted.");
                Error (old_line, tmp);
                return new Token (Token.TK_ERROR);
            }
            
            Token t = cur.ExpandFunc ?
                cur.ExpandFunc (this, nargs, args) :
                cur.Expand (nargs, args, MacroList);
            t.AppendNL (Line - old_line);
            
            //delete [] args;
            args = null;
            
            return t;
        }
        
        return cast(Token)iToken;
    }
    
    /**
     * Check if a macro is defined, and if so, return it
     * @param iToken
     *     Macro name
     * @return
     *     The macro object or NULL if a macro with this name does not exist
     */
    Macro IsDefined (const (Token) iToken)
    {
        for (Macro cur = MacroList; cur; cur = cur.Next)
            if (cur.Name == iToken)
                return cur;
        
        return null;
    }
    
    /**
     * The implementation of the defined() preprocessor function
     * @param iParent
     *     The parent preprocessor object
     * @param iNumArgs
     *     Number of arguments
     * @param iArgs
     *     The arguments themselves
     * @return
     *     The return value encapsulated in a token
     */
    static Token ExpandDefined (CPreprocessor iParent, int iNumArgs, Token[] iArgs)
    {
        if (iNumArgs != 1)
        {
            iParent.Error (iParent.Line, "The defined() function takes exactly one argument");
            return new Token (Token.TK_ERROR);
        }
        
        string v = iParent.IsDefined (iArgs [0]) ? "1" : "0";
        return new Token (Token.TK_NUMBER, v.dup, 1);
    }
    
    /**
     * Parse the input string and return a token containing the whole output.
     * @param iSource
     *     The source text enclosed in a token
     * @return
     *     The output text enclosed in a token
     */
    Token Parse (const (Token) iSource)
    {
        SourceStart = iSource.String.ptr - Source.ptr;
        SourceEnd = SourceStart + iSource.Length;
        Line = 1;
        BOL = true;
        EnableOutput = 1;
        
        // Accumulate output into this token
        Token output = new Token (Token.TK_TEXT);
        int empty_lines = 0;
        
        // Enable output only if all embedded #if's were true
        bool old_output_enabled = true;
        bool output_enabled = true;
        int output_disabled_line = 0;
        
        while (SourceStart < SourceEnd)
        {
            int old_line = Line;
            Token t = GetToken (true);
            
        NextToken:
            switch (t.Type)
            {
                case Token.TK_ERROR:
                    return t;
                    
                case Token.TK_EOS:
                    return output; // Force termination
                    
                case Token.TK_COMMENT:
                    // C comments are replaced with single spaces.
                    if (output_enabled)
                    {
                        output.Append (" ".dup);
                        output.AppendNL (Line - old_line);
                    }
                    break;
                    
                case Token.TK_LINECOMMENT:
                    // C++ comments are ignored
                    continue;
                    
                case Token.TK_DIRECTIVE:
                    // Handle preprocessor directives
                    t = HandleDirective (t, old_line);
                    
                    output_enabled = ((EnableOutput & (EnableOutput + 1)) == 0);
                    if (output_enabled != old_output_enabled)
                    {
                        if (output_enabled)
                            output.AppendNL (old_line - output_disabled_line);
                        else
                            output_disabled_line = old_line;
                        old_output_enabled = output_enabled;
                    }
                    
                    if (output_enabled)
                        output.AppendNL (Line - old_line - t.CountNL ());
                    goto NextToken;
                    
                case Token.TK_LINECONT:
                    // Backslash-Newline sequences are deleted, no matter where.
                    empty_lines++;
                    break;
                    
                case Token.TK_NEWLINE:
                    if (empty_lines)
                    {
                        // Compensate for the backslash-newline combinations
                        // we have encountered, otherwise line numeration is broken
                        if (output_enabled)
                            output.AppendNL (empty_lines);
                        empty_lines = 0;
                    }
                    // Fallthrough to default
                case Token.TK_WHITESPACE:
                    // Fallthrough to default
                default:
                    // Passthrough all other tokens
                    if (output_enabled)
                        output.Append (t);
                    break;
            }
        }
        
        if (EnableOutput != 1)
        {
            Error (Line, "Unclosed #if at end of source");
            return new Token (Token.TK_ERROR);
        }
        
        return output;
    }
    
    /**
     * Call the error handler
     * @param iLine
     *     The line at which the error happened.
     * @param iError
     *     The error string.
     * @param iToken
     *     If not NULL contains the erroneous token
     */
    void Error (int iLine, string iError, Token iToken = null)
    {
        if (iToken)
            ErrorHandler (ErrorData, iLine, iError, iToken.String, iToken.Length);
        else
            ErrorHandler (ErrorData, iLine, iError, null, 0);
    }
    
public:
    /// Create an empty preprocessor object
    this () //: MacroList (NULL)
    { }
    
    /// Destroy the preprocessor object
    ~this ()
    {
        destroy(MacroList);
    }
    
    /**
     * Define a macro without parameters.
     * @param iMacroName
     *     The name of the defined macro
     * @param iMacroNameLen
     *     The length of the name of the defined macro
     * @param iMacroValue
     *     The value of the defined macro
     * @param iMacroValueLen
     *     The length of the value of the defined macro
     */
    void Define (char[] iMacroName, size_t iMacroNameLen,
                 char[] iMacroValue, size_t iMacroValueLen
                 )
    {
        Macro m = new Macro (new Token (Token.TK_KEYWORD, iMacroName, iMacroNameLen));
        m.Value = new Token (Token.TK_TEXT, iMacroValue, iMacroValueLen);
        m.Next = MacroList;
        MacroList = m;
    }
    
    /**
     * Define a numerical macro.
     * @param iMacroName
     *     The name of the defined macro
     * @param iMacroNameLen
     *     The length of the name of the defined macro
     * @param iMacroValue
     *     The value of the defined macro
     */
    void Define (char[] iMacroName, size_t iMacroNameLen, long iMacroValue)
    {
        Macro m = new Macro (new Token (Token.TK_KEYWORD, iMacroName, iMacroNameLen));
        m.Value.SetValue (iMacroValue);
        m.Next = MacroList;
        MacroList = m;
    }
    
    /**
     * Undefine a macro.
     * @param iMacroName
     *     The name of the macro to undefine
     * @param iMacroNameLen
     *     The length of the name of the macro to undefine
     * @return
     *     true if the macro has been undefined, false if macro doesn't exist
     */
    bool Undef (char[] iMacroName, size_t iMacroNameLen)
    {
        Macro *cur = &MacroList;
        Token name = new Token(Token.TK_KEYWORD, iMacroName, iMacroNameLen);
        while (*cur)
        {
            if (cur.Name == name)
            {
                Macro next = cur.Next;
                (*cur).Next = null;
                destroy (*cur);
                *cur = next;
                return true;
            }
            
            cur = &(*cur).Next;
        }
        
        return false;
    }
    
    /**
     * Parse the input string and return a newly-allocated output string.
     * @note
     *     The returned preprocessed string is NOT zero-terminated
     *     (just like the input string).
     * @param iSource
     *     The source text
     * @param iLength
     *     The length of the source text in characters
     * @param oLength
     *     The length of the output string.
     * @return
     *     The output from preprocessor, allocated with malloc().
     *     The parser can actually allocate more than needed for performance
     *     reasons, but this should not be a problem unless you will want
     *     to store the returned pointer for long time in which case you
     *     might want to realloc() it.
     *     If an error has been encountered, the function returns NULL.
     *     In some cases the function may return an unallocated address
     *     that's *inside* the source buffer. You must free() the result
     *     string only if the returned address is not inside the source text.
     */
    //char[] Parse (char[] iSource, size_t iLength, ref size_t oLength)
    string Parse (string iSource)
    {
        Source = iSource.dup;//FIXME
        Token retval = Parse (new Token (Token.TK_TEXT, Source, Source.length));
        if (retval.Type == Token.TK_ERROR)
            return null;
        
        //oLength = retval.Length;
        retval.Allocated = 0;
        return std.conv.to!string(retval.Buffer);
    }
    
    /**
     * An error handler function type.
     * The default implementation just drops a note to stderr and
     * then the parser ends, returning NULL.
     * @param iData
     *     User-specific pointer from the corresponding CPreprocessor object.
     * @param iLine
     *     The line at which the error happened.
     * @param iError
     *     The error string.
     * @param iToken
     *     If not NULL contains the erroneous token
     * @param iTokenLen
     *     The length of iToken. iToken is never zero-terminated!
     */
    alias void function (
        void *iData, int iLine, string iError,
        char[] iToken, size_t iTokenLen) ErrorHandlerFunc;
    
    /**
     * A pointer to the preprocessor's error handler.
     * You can assign the address of your own function to this variable
     * and implement your own error handling (e.g. throwing an exception etc).
     */
    static ErrorHandlerFunc ErrorHandler = &DefaultError;
    
    /// User-specific storage, passed to Error()
    void *ErrorData;

    static void DefaultError (void *iData, int iLine, string iError,
                              char[] iToken, size_t iTokenLen)
    {
        string line;
        if (iToken)
            line = std.conv.text("line ",iLine,": ",iError,": `",iToken[0..iTokenLen],"'\n");
        else
            line = std.conv.text("line ",iLine,": ",iError,"\n");
        LogManager.getSingleton ().logMessage (line);
    }
}