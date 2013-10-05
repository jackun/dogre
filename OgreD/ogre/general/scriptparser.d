module ogre.general.scriptparser;
import std.conv;
import ogre.exception;
import ogre.general.scriptlexer;
import ogre.general.scriptcompiler;

/** \addtogroup Core
    *  @{
    */
/** \addtogroup General
    *  @{
    */

class ScriptParser //: public ScriptCompilerAlloc
{
public:
    this() {}
    
    ~this() {}
    
    ConcreteNodeListPtr parse(/*const*/ScriptTokenListPtr tokens)
    {
        // MEMCATEGORY_GENERAL because SharedPtr can only free using that category
        ConcreteNodeListPtr nodes; //= ConcreteNodeListPtr(new ConcreteNodeList);
        
        enum: uint {READY, OBJECT};
        uint state = READY;
        
        ConcreteNode *parent = null;
        ConcreteNodePtr node;
        ScriptToken *token = null;
        //ScriptTokenList::iterator i = tokens.begin(), end = tokens.end();
        size_t end = tokens.length;
        
        //foreach(i; tokens)
        for(size_t i=0; i < tokens.length;)
        {
            final switch(state)
            {
                case READY:
                    if(tokens[i].type == TID_WORD)
                    {
                        if(tokens[i].lexeme == "import")
                        {
                            node = ConcreteNodePtr(new ConcreteNode());
                            node.token = tokens[i].lexeme;
                            node.file = tokens[i].file;
                            node.line = tokens[i].line;
                            node.type = CNT_IMPORT;
                            
                            // The next token is the target
                            ++i;
                            if(i == end || (tokens[i].type != TID_WORD && tokens[i].type != TID_QUOTE))
                                throw new InvalidStateError(
                                            text("expected import target at line ", node.line),
                                            "ScriptParser::parse");
                            ConcreteNodePtr temp = ConcreteNodePtr(new ConcreteNode);
                            temp.parent = node.get();
                            temp.file = tokens[i].file;
                            temp.line = tokens[i].line;
                            temp.type = tokens[i].type == TID_WORD ? CNT_WORD : CNT_QUOTE;
                            if(temp.type == CNT_QUOTE)
                                temp.token = tokens[i].lexeme[1..$-1];
                            else
                                temp.token = tokens[i].lexeme;
                            node.children ~= (temp);
                            
                            // The second-next token is the source
                            ++i;
                            ++i;
                            if(i == end || (tokens[i].type != TID_WORD && tokens[i].type != TID_QUOTE))
                                throw new InvalidStateError(
                                            text("expected import source at line ", node.line),
                                            "ScriptParser::parse");
                            temp = ConcreteNodePtr(new ConcreteNode);
                            temp.parent = node.get();
                            temp.file = tokens[i].file;
                            temp.line = tokens[i].line;
                            temp.type = tokens[i].type == TID_WORD ? CNT_WORD : CNT_QUOTE;
                            if(temp.type == CNT_QUOTE)
                                temp.token = tokens[i].lexeme[1..$-1];
                            else
                                temp.token = tokens[i].lexeme;
                            node.children ~= (temp);
                            
                            // Consume all the newlines
                            i = skipNewlines(tokens, i, end);
                            
                            // Insert the node
                            if(parent)
                            {
                                node.parent = parent;
                                parent.children ~= (node);
                            }
                            else
                            {
                                node.parent = null;
                                nodes ~= (node);
                            }
                            node = ConcreteNodePtr();
                        }
                        else if(tokens[i].lexeme == "set")
                        {
                            node = ConcreteNodePtr(new ConcreteNode);
                            node.token = tokens[i].lexeme;
                            node.file = tokens[i].file;
                            node.line = tokens[i].line;
                            node.type = CNT_VARIABLE_ASSIGN;
                            
                            // The next token is the variable
                            ++i;
                            if(i == end || tokens[i].type != TID_VARIABLE)
                                throw new InvalidStateError(
                                            text("expected variable name at line ", node.line),
                                            "ScriptParser::parse");
                            ConcreteNodePtr temp = ConcreteNodePtr(new ConcreteNode);
                            temp.parent = node.get();
                            temp.file = tokens[i].file;
                            temp.line = tokens[i].line;
                            temp.type = CNT_VARIABLE;
                            temp.token = tokens[i].lexeme;
                            node.children ~= (temp);
                            
                            // The next token is the assignment
                            ++i;
                            if(i == end || (tokens[i].type != TID_WORD && tokens[i].type != TID_QUOTE))
                                throw new InvalidStateError(
                                            text("expected variable value at line ", node.line),
                                            "ScriptParser::parse");
                            temp = ConcreteNodePtr(new ConcreteNode());
                            temp.parent = node.get();
                            temp.file = tokens[i].file;
                            temp.line = tokens[i].line;
                            temp.type = tokens[i].type == TID_WORD ? CNT_WORD : CNT_QUOTE;
                            if(temp.type == CNT_QUOTE)
                                temp.token = tokens[i].lexeme[1..$-1];
                            else
                                temp.token = tokens[i].lexeme;
                            node.children ~= (temp);
                            
                            // Consume all the newlines
                            i = skipNewlines(tokens, i, end);
                            
                            // Insert the node
                            if(parent)
                            {
                                node.parent = parent;
                                parent.children ~= (node);
                            }
                            else
                            {
                                node.parent = null;
                                nodes ~= (node);
                            }
                            node = ConcreteNodePtr();
                        }
                        else
                        {
                            node = ConcreteNodePtr(new ConcreteNode);
                            node.file = tokens[i].file;
                            node.line = tokens[i].line;
                            node.type = tokens[i].type == TID_WORD ? CNT_WORD : CNT_QUOTE;
                            if(node.type == CNT_QUOTE)
                                node.token = tokens[i].lexeme[1..$-1];
                            else
                                node.token = tokens[i].lexeme;
                            
                            // Insert the node
                            if(parent)
                            {
                                node.parent = parent;
                                parent.children ~= (node);
                            }
                            else
                            {
                                node.parent = null;
                                nodes ~= (node);
                            }
                            
                            // Set the parent
                            parent = node.get();
                            
                            // Switch states
                            state = OBJECT;
                            
                            node = ConcreteNodePtr();
                        }
                    }
                    else if(tokens[i].type == TID_RBRACKET)
                    {
                        // Go up one level if we can
                        if(parent)
                            parent = parent.parent;
                        
                        node = ConcreteNodePtr(new ConcreteNode);
                        node.token = tokens[i].lexeme;
                        node.file = tokens[i].file;
                        node.line = tokens[i].line;
                        node.type = CNT_RBRACE;
                        
                        // Consume all the newlines
                        i = skipNewlines(tokens, i, end);
                        
                        // Insert the node
                        if(parent)
                        {
                            node.parent = parent;
                            parent.children ~= (node);
                        }
                        else
                        {
                            node.parent = null;
                            nodes ~= (node);
                        }
                        
                        // Move up another level
                        if(parent)
                            parent = parent.parent;
                        
                        node = ConcreteNodePtr();
                    }
                    break;
                case OBJECT:
                    if(tokens[i].type == TID_NEWLINE)
                    {
                        // Look ahead to the next non-newline token and if it isn't an {, this was a property
                        size_t next = skipNewlines(tokens, i, end);
                        if(next == end || tokens[next].type != TID_LBRACKET)
                        {
                            // Ended a property here
                            if(parent)
                                parent = parent.parent;
                            state = READY;
                        }
                    }
                    else if(tokens[i].type == TID_COLON)
                    {
                        node = ConcreteNodePtr(new ConcreteNode);
                        node.token = tokens[i].lexeme;
                        node.file = tokens[i].file;
                        node.line = tokens[i].line;
                        node.type = CNT_COLON;
                        
                        // The following token are the parent objects (base classes).
                        // Require at least one of them.
                        
                        size_t j = i + 1;
                        j = skipNewlines(tokens, j, end);
                        if(j >= end || (tokens[j].type != TID_WORD && tokens[j].type != TID_QUOTE)) {
                            throw new InvalidStateError(
                                        text("expected object identifier at line ", node.line),
                                        "ScriptParser::parse");
                        }
                        
                        while(j < end && (tokens[j].type == TID_WORD || tokens[j].type == TID_QUOTE))
                        {
                            ConcreteNodePtr tempNode = ConcreteNodePtr(new ConcreteNode);
                            tempNode.token = tokens[j].lexeme;
                            tempNode.file = tokens[j].file;
                            tempNode.line = tokens[j].line;
                            tempNode.type = tokens[j].type == TID_WORD ? CNT_WORD : CNT_QUOTE;
                            tempNode.parent = node.get();
                            node.children ~= (tempNode);
                            ++j;
                        }
                        
                        // Move it backwards once, since the end of the loop moves it forwards again anyway
                        j--;
                        i = j;
                        
                        // Insert the node
                        if(parent)
                        {
                            node.parent = parent;
                            parent.children ~= (node);
                        }
                        else
                        {
                            node.parent = null;
                            nodes ~= (node);
                        }
                        node = ConcreteNodePtr();
                    }
                    else if(tokens[i].type == TID_LBRACKET)
                    {
                        node = ConcreteNodePtr(new ConcreteNode());
                        node.token = tokens[i].lexeme;
                        node.file = tokens[i].file;
                        node.line = tokens[i].line;
                        node.type = CNT_LBRACE;
                        
                        // Consume all the newlines
                        i = skipNewlines(tokens, i, end);
                        
                        // Insert the node
                        if(parent)
                        {
                            node.parent = parent;
                            parent.children ~= (node);
                        }
                        else
                        {
                            node.parent = null;
                            nodes ~= (node);
                        }
                        
                        // Set the parent
                        parent = node.get();
                        
                        // Change the state
                        state = READY;
                        
                        node = ConcreteNodePtr();
                    }
                    else if(tokens[i].type == TID_RBRACKET)
                    {
                        // Go up one level if we can
                        if(parent)
                            parent = parent.parent;
                        
                        // If the parent is currently a { then go up again
                        if(parent && parent.type == CNT_LBRACE && parent.parent)
                            parent = parent.parent;
                        
                        node = ConcreteNodePtr(new ConcreteNode());
                        node.token = tokens[i].lexeme;
                        node.file = tokens[i].file;
                        node.line = tokens[i].line;
                        node.type = CNT_RBRACE;
                        
                        // Consume all the newlines
                        i = skipNewlines(tokens, i, end);
                        
                        // Insert the node
                        if(parent)
                        {
                            node.parent = parent;
                            parent.children ~= (node);
                        }
                        else
                        {
                            node.parent = null;
                            nodes ~= (node);
                        }
                        
                        // Move up another level
                        if(parent)
                            parent = parent.parent;
                        
                        node = ConcreteNodePtr();
                        state = READY;
                    }
                    else if(tokens[i].type == TID_VARIABLE)
                    {
                        node = ConcreteNodePtr(new ConcreteNode());
                        node.token = tokens[i].lexeme;
                        node.file = tokens[i].file;
                        node.line = tokens[i].line;
                        node.type = CNT_VARIABLE;
                        
                        // Insert the node
                        if(parent)
                        {
                            node.parent = parent;
                            parent.children ~= (node);
                        }
                        else
                        {
                            node.parent = null;
                            nodes ~= (node);
                        }
                        node = ConcreteNodePtr();
                    }
                    else if(tokens[i].type == TID_QUOTE)
                    {
                        node = ConcreteNodePtr(new ConcreteNode);
                        node.token = tokens[i].lexeme[1..$-1];
                        node.file = tokens[i].file;
                        node.line = tokens[i].line;
                        node.type = CNT_QUOTE;
                        
                        // Insert the node
                        if(parent)
                        {
                            node.parent = parent;
                            parent.children ~= (node);
                        }
                        else
                        {
                            node.parent = null;
                            nodes ~= (node);
                        }
                        node = ConcreteNodePtr();
                    }
                    else if(tokens[i].type == TID_WORD)
                    {
                        node = ConcreteNodePtr(new ConcreteNode);
                        node.token = tokens[i].lexeme;
                        node.file = tokens[i].file;
                        node.line = tokens[i].line;
                        node.type = CNT_WORD;
                        
                        // Insert the node
                        if(parent)
                        {
                            node.parent = parent;
                            parent.children ~= (node);
                        }
                        else
                        {
                            node.parent = null;
                            nodes ~= (node);
                        }
                        node = ConcreteNodePtr();
                    }
                    break;
            }
            
            ++i;
        }
        
        return nodes;
    }
    
    ConcreteNodeListPtr parseChunk(/*const*/ ScriptTokenListPtr tokens)
    {
        // MEMCATEGORY_GENERAL because SharedPtr can only free using that category
        ConcreteNodeListPtr nodes;
        
        ConcreteNodePtr node;
        ScriptToken *token = null;
        foreach(i; tokens)
        {
            token = i.get();
            
            switch(token.type)
            {
                case TID_VARIABLE:
                    node = ConcreteNodePtr(new ConcreteNode);
                    node.file = token.file;
                    node.line = token.line;
                    node.parent = null;
                    node.token = token.lexeme;
                    node.type = CNT_VARIABLE;
                    break;
                case TID_WORD:
                    node = ConcreteNodePtr(new ConcreteNode);
                    node.file = token.file;
                    node.line = token.line;
                    node.parent = null;
                    node.token = token.lexeme;
                    node.type = CNT_WORD;
                    break;
                case TID_QUOTE:
                    node = ConcreteNodePtr(new ConcreteNode);
                    node.file = token.file;
                    node.line = token.line;
                    node.parent = null;
                    node.token = token.lexeme[1..$-1];
                    node.type = CNT_QUOTE;
                default:
                    throw new InvalidStateError(
                                text("unexpected token", token.lexeme, " at line ", token.line),
                                "ScriptParser::parseChunk");
            }
            
            if(!node.isNull())
                nodes ~= node;
        }
        
        return nodes;
    }
private:
    //TODO what uses this?
    ScriptToken *getToken(ScriptTokenListPtr array, size_t i, size_t end, int offset)
    {
        ScriptToken *token = null;
        auto iter = i + offset;
        if(iter < end)
            token = array[i].get();
        return token;
    }
    
    size_t skipNewlines(ScriptTokenListPtr array, size_t i, size_t end)
    {
        while(i < end && array[i].type == TID_NEWLINE)
            ++i;
        return i;
    }
}

/** @} */
/** @} */