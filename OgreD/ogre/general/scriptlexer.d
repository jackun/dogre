module ogre.general.scriptlexer;
import std.array;
import std.conv;
import ogre.exception;
import ogre.sharedptr;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup General
 *  @{
 */
/** These codes represent token IDs which are numerical translations of
 specific lexemes. Specific compilers using the lexer can register their
 own token IDs which are given precedence over these built-in ones.
 */
enum{
    TID_LBRACKET = 0, // {
    TID_RBRACKET, // }
    TID_COLON, // :
    TID_VARIABLE, // $...
    TID_WORD, // *
    TID_QUOTE, // "*"
    TID_NEWLINE, // \n
    TID_UNKNOWN,
    TID_END
}

/** This struct represents a token, which is an ID'd lexeme from the
 parsing input stream.
 */
struct ScriptToken
{
    /// This is the lexeme for this token
    string lexeme, file;
    /// This is the id associated with the lexeme, which comes from a lexeme-token id mapping
    uint type;
    /// This holds the line number of the input stream where the token was found.
    uint line;
}

// Converting to pointer for SharedPtr isNull
alias SharedPtr!(ScriptToken*) ScriptTokenPtr;
//typedef vector<ScriptTokenPtr>::type ScriptTokenList;
alias ScriptTokenPtr[] ScriptTokenList;
alias SharedPtr!ScriptTokenList ScriptTokenListPtr;

class ScriptLexer //: public ScriptCompilerAlloc
{
public:
    this(){}
    
    ~this() {}
    
    /** Tokenizes the given input and returns the list of tokens found */
    ScriptTokenListPtr tokenize(string str, string source)
    {
        // State enums
        enum: uint { READY = 0, COMMENT, MULTICOMMENT, WORD, QUOTE, VAR, POSSIBLECOMMENT }
        
        //TODO Set up some constant characters of interest
        //static if
        version (OGRE_WCHAR_T_STRINGS)
        {
            enum whcar varopener = '$', quote = '\"', slash = '/', backslash = '\\', openbrace = '{', closebrace = '}', colon = ':', star = '*', cr = '\r', lf = '\n';
            wchar c, lastc;
        }
        else
        {        
            enum char varopener = '$', quote = '\"', slash = '/', backslash = '\\', openbrace = '{', closebrace = '}', colon = ':', star = '*', cr = '\r', lf = '\n';
            char c, lastc;
        }
        
        string lexeme;
        uint line = 1, state = READY, lastQuote = 0;
        ScriptTokenListPtr tokens;
        
        // Iterate over the input
        
        foreach(i; str)
        {
            lastc = c;
            c = i;
            
            if(c == quote)
                lastQuote = line;
            
            final switch(state)
            {
                case READY:
                    if(c == slash && lastc == slash)
                    {
                        // Comment start, clear out the lexeme
                        lexeme = "";
                        state = COMMENT;
                    }
                    else if(c == star && lastc == slash)
                    {
                        lexeme = "";
                        state = MULTICOMMENT;
                    }
                    else if(c == quote)
                    {
                        // Clear out the lexeme ready to be filled with quotes!
                        lexeme = "" ~ c;
                        state = QUOTE;
                    }
                    else if(c == varopener)
                    {
                        // Set up to read in a variable
                        lexeme = "" ~ c;
                        state = VAR;
                    }
                    else if(isNewline(c))
                    {
                        lexeme = "" ~ c;
                        setToken(lexeme, line, source, tokens.get());
                    }
                    else if(!isWhitespace(c))
                    {
                        lexeme = "" ~ c;
                        if(c == slash)
                            state = POSSIBLECOMMENT;
                        else
                            state = WORD;
                    }
                    break;
                case COMMENT:
                    // This newline happens to be ignored automatically
                    if(isNewline(c))
                        state = READY;
                    break;
                case MULTICOMMENT:
                    if(c == slash && lastc == star)
                        state = READY;
                    break;
                case POSSIBLECOMMENT:
                    if(c == slash && lastc == slash)
                    {
                        lexeme = "";
                        state = COMMENT;
                        break;  
                    }
                    else if(c == star && lastc == slash)
                    {
                        lexeme = "";
                        state = MULTICOMMENT;
                        break;
                    }
                    else
                    {
                        state = WORD;
                    }
                case WORD:
                    if(isNewline(c))
                    {
                        setToken(lexeme, line, source, tokens.get());
                        lexeme = "" ~ c;
                        setToken(lexeme, line, source, tokens.get());
                        state = READY;
                    }
                    else if(isWhitespace(c))
                    {
                        setToken(lexeme, line, source, tokens.get());
                        state = READY;
                    }
                    else if(c == openbrace || c == closebrace || c == colon)
                    {
                        setToken(lexeme, line, source, tokens.get());
                        lexeme = "" ~ c;
                        setToken(lexeme, line, source, tokens.get());
                        state = READY;
                    }
                    else
                    {
                        lexeme ~= c;
                    }
                    break;
                case QUOTE:
                    if(c != backslash)
                    {
                        // Allow embedded quotes with escaping
                        if(c == quote && lastc == backslash)
                        {
                            lexeme ~= c;
                        }
                        else if(c == quote)
                        {
                            lexeme ~= c;
                            setToken(lexeme, line, source, tokens.get());
                            state = READY;
                        }
                        else
                        {
                            // Backtrack here and allow a backslash normally within the quote
                            if(lastc == backslash)
                                lexeme = lexeme ~ "\\" ~ c;
                            else
                                lexeme ~= c;
                        }
                    }
                    break;
                case VAR:
                    if(isNewline(c))
                    {
                        setToken(lexeme, line, source, tokens.get());
                        lexeme = "" ~ c;
                        setToken(lexeme, line, source, tokens.get());
                        state = READY;
                    }
                    else if(isWhitespace(c))
                    {
                        setToken(lexeme, line, source, tokens.get());
                        state = READY;
                    }
                    else if(c == openbrace || c == closebrace || c == colon)
                    {
                        setToken(lexeme, line, source, tokens.get());
                        lexeme = "" ~ c;
                        setToken(lexeme, line, source, tokens.get());
                        state = READY;
                    }
                    else
                    {
                        lexeme ~= c;
                    }
                    break;
            }
            
            // Separate check for newlines just to track line numbers
            if(c == cr || (c == lf && lastc != cr))
                line++;
            
        }
        
        // Check for valid exit states
        if(state == WORD || state == VAR)
        {
            if(!lexeme.empty())
                setToken(lexeme, line, source, tokens.get());
        }
        else
        {
            if(state == QUOTE)
            {
                throw new InvalidStateError(
                    "no matching \" found for \" at line " ~ to!string(lastQuote),
                    "ScriptLexer.tokenize");
            }
        }
        
        return tokens;
    }
    
private: // Private utility operations
    void setToken(string lexeme, uint line, string source, ref ScriptTokenList tokens)
    {
        //TODO OGRE_WCHAR_T_STRINGS
        version (OGRE_WCHAR_T_STRINGS)
        {
            enum wchar openBracket = '{', closeBracket = '}', colon = ':', 
                quote = '\"', var = '$';
        }
        else
        {
            enum char openBracket = '{', closeBracket = '}', colon = ':', 
                quote = '\"', var = '$';
        }
        
        ScriptTokenPtr token = ScriptTokenPtr(new ScriptToken);
        token.lexeme = lexeme;
        token.line = line;
        token.file = source;
        bool ignore = false;
        
        // Check the user token map first
        if(lexeme.length == 1 && isNewline(lexeme[0]))
        {
            token.type = TID_NEWLINE;
            if(!tokens.empty() && tokens.back().type == TID_NEWLINE)
                ignore = true;
        }
        else if(lexeme.length == 1 && lexeme[0] == openBracket)
            token.type = TID_LBRACKET;
        else if(lexeme.length == 1 && lexeme[0] == closeBracket)
            token.type = TID_RBRACKET;
        else if(lexeme.length == 1 && lexeme[0] == colon)
            token.type = TID_COLON;
        else if(lexeme[0] == var)
            token.type = TID_VARIABLE;
        else
        {
            // This is either a non-zero length phrase or quoted phrase
            if(lexeme.length >= 2 && lexeme[0] == quote && lexeme[$ - 1] == quote)
            {
                token.type = TID_QUOTE;
            }
            else
            {
                token.type = TID_WORD;
            }
        }
        
        if(!ignore)
            tokens ~= token;
    }
    
    bool isWhitespace(T)(T c) const
    {
        //TODO wchar
        return c == ' ' || c == '\r' || c == '\t';
    }
    
    bool isNewline(T)(T c) const
    {
        //TODO wchar
        return c == '\n' || c == '\r';
    }
}

/** @} */
/** @} */
