module ogre.general.scriptcompiler;
import core.sync.mutex;
import std.conv;
import std.array;
import std.algorithm;
import std.string;
alias std.string.indexOf indexOf;
debug import std.stdio;

import ogre.compat;
import ogre.singleton;
import ogre.general.generals;
import ogre.resources.datastream;
import ogre.general.scriptlexer;
import ogre.general.scriptparser;
import ogre.general.log;
import ogre.resources.resourcegroupmanager;
import ogre.config;
import ogre.materials.material;
import ogre.general.common;
import ogre.materials.gpuprogram;
import ogre.general.scripttranslator;
import ogre.strings;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup General
 *  @{
 */
alias uint ConcreteNodeType;
/** These enums hold the types of the concrete parsed nodes */
enum : ConcreteNodeType
{
    CNT_VARIABLE, //0
    CNT_VARIABLE_ASSIGN,//1
    CNT_WORD,//2
    CNT_IMPORT,//3
    CNT_QUOTE,//4
    CNT_LBRACE,//5
    CNT_RBRACE,//6
    CNT_COLON//7
}

/** The ConcreteNode is the struct that holds an un-conditioned sub-tree of parsed input */
alias SharedPtr!(ConcreteNode*) ConcreteNodePtr;
//typedef list<ConcreteNodePtr>::type ConcreteNodeList;
alias ConcreteNodePtr[] ConcreteNodeList;
alias SharedPtr!ConcreteNodeList ConcreteNodeListPtr;

struct ConcreteNode //: public ScriptCompilerAlloc
{
    string token, file;
    uint line;
    ConcreteNodeType type;
    ConcreteNodeList children;
    ConcreteNode *parent;
}

alias uint AbstractNodeType;
/** This enum holds the types of the possible abstract nodes */
enum : AbstractNodeType
{
    ANT_UNKNOWN,
    ANT_ATOM,
    ANT_OBJECT,
    ANT_PROPERTY,
    ANT_IMPORT,
    ANT_VARIABLE_SET,
    ANT_VARIABLE_ACCESS
}

alias SharedPtr!AbstractNode AbstractNodePtr;
//typedef list<AbstractNodePtr>::type AbstractNodeList;
alias AbstractNodePtr[] AbstractNodeList;
alias SharedPtr!AbstractNodeList AbstractNodeListPtr;

class AbstractNode //: public AbstractNodeAlloc
{
public:
    string file;
    uint line;
    AbstractNodeType type;
    AbstractNode parent;
    Any context; // A holder for translation context data
public:
    this(AbstractNode ptr)
    {
        line = 0;
        type = ANT_UNKNOWN;
        parent = ptr;
    }
    ~this(){}
    /// Returns a new AbstractNode which is a replica of this one.
    abstract AbstractNode clone();// const;
    /// Returns a string value depending on the type of the AbstractNode.
    abstract string getValue();// const;
}

/** This is an abstract node which cannot be broken down further */
class AtomAbstractNode : AbstractNode
{
public:
    string value;
    uint id;
public:
    this(AbstractNode ptr)
    {
        super(ptr);
        id = 0;
        type = ANT_ATOM;
    }
    override AbstractNode clone()// const;
    {
        AtomAbstractNode node = new AtomAbstractNode(parent);
        node.file = file;
        node.line = line;
        node.id = id;
        node.type = type;
        node.value = value;
        return node;
    }
    override string getValue()// const;
    {
        return value;
    }
private:
    void parseNumber() const;//TODO missing in action
    
}

/** This specific abstract node represents a script object */
class ObjectAbstractNode : AbstractNode
{
private:
    string[string] mEnv;
public:
    string name, cls;
    string[] bases;
    uint id;
    bool _abstract;
    AbstractNodeList children;
    AbstractNodeList values;
    AbstractNodeList overrides; // For use when processing object inheritance and overriding
    
public:
    this(AbstractNode ptr)
    {
        super(ptr);
        id = 0;
        _abstract = false;
        type = ANT_OBJECT;
    }
    
    override AbstractNode clone()// const;
    {
        ObjectAbstractNode node = new ObjectAbstractNode(parent);
        node.file = file;
        node.line = line;
        node.type = type;
        node.name = name;
        node.cls = cls;
        node.id = id;
        node._abstract = _abstract;
        foreach(i; children)
        {
            AbstractNodePtr newNode = AbstractNodePtr(i.clone());
            newNode.parent = node;
            node.children ~= newNode;
        }
        foreach(i; values)
        {
            AbstractNodePtr newNode = AbstractNodePtr(i.clone());
            newNode.parent = node;
            node.values ~= newNode;
        }
        node.mEnv = mEnv;
        return node;
    }
    
    override string getValue()// const;
    {
        return cls;
    }
    
    void addVariable(string name)
    {
        mEnv[name] = "";
    }
    
    void setVariable(string name, string value)
    {
        mEnv[name] = value;
    }
    
    pair!(bool,string) getVariable(string name)// const;
    {
        string* i = name in mEnv;
        if(i !is null)
            return pair!(bool,string)(true, *i);
        
        ObjectAbstractNode parentNode = cast(ObjectAbstractNode)this.parent;
        while(parentNode !is null)
        {
            i = name in parentNode.mEnv;
            if(i !is null)
                return pair!(bool,string)(true, *i);
            parentNode = cast(ObjectAbstractNode)parentNode.parent;
        }
        return pair!(bool,string)(false, "");
    }
    
    /*const*/ string[string] getVariables()// const;
    {
        return mEnv;
    }
}

/** This abstract node represents a script property */
class PropertyAbstractNode : AbstractNode
{
public:
    string name;
    uint id;
    AbstractNodeList values;
public:
    this(AbstractNode ptr)
    {
        super(ptr);
        id = 0;
        type = ANT_PROPERTY;
    }
    override AbstractNode clone()// const;
    {
        PropertyAbstractNode node = new PropertyAbstractNode(parent);
        node.file = file;
        node.line = line;
        node.type = type;
        node.name = name;
        node.id = id;
        foreach(i; values)
        {
            AbstractNodePtr newNode = AbstractNodePtr(i.clone());
            newNode.parent = node;
            node.values ~= newNode;
        }
        return node;
    }
    override string getValue() //const;
    {
        return name;
    }
}

/** This abstract node represents an import statement */
class ImportAbstractNode : AbstractNode
{
public:
    string target, source;
public:
    this()
    {
        super(null);
        type = ANT_IMPORT;
    }
    override AbstractNode clone()// const;
    {
        ImportAbstractNode node = new ImportAbstractNode();
        node.file = file;
        node.line = line;
        node.type = type;
        node.target = target;
        node.source = source;
        return node;
    }
    override string getValue() //const;
    {
        return target;
    }
}

/** This abstract node represents a variable assignment */
class VariableAccessAbstractNode : AbstractNode
{
public:
    string name;
public:
    this(AbstractNode ptr)
    {
        super(ptr);
        type = ANT_VARIABLE_ACCESS;
    }
    
    override AbstractNode clone() //const;
    {
        VariableAccessAbstractNode node = new VariableAccessAbstractNode(parent);
        node.file = file;
        node.line = line;
        node.type = type;
        node.name = name;
        return node;
    }
    override string getValue() //const;
    {
        return name;
    }
}

/** This is the main class for the compiler. It calls the parser
 and processes the CST into an AST and then uses translators
 to translate the AST into the final resources.
 */
class ScriptCompiler //: public ScriptCompilerAlloc
{
public: // Externally accessible types
    //typedef map<string,uint>::type IdMap;
    //typedef HashMap<string,uint> IdMap;
    alias uint[string] IdMap;
    
    // The container for errors
    struct Error //: public ScriptCompilerAlloc
    {
        string file, message;
        int line;
        uint code;
    }
    //alias SharedPtr!Error ErrorPtr;
    //typedef list<ErrorPtr>::type ErrorList;
    alias Error[] ErrorList;
    
    // These are the built-in error codes
    enum{
        CE_STRINGEXPECTED,
        CE_NUMBEREXPECTED,
        CE_FEWERPARAMETERSEXPECTED,
        CE_VARIABLEEXPECTED,
        CE_UNDEFINEDVARIABLE,
        CE_OBJECTNAMEEXPECTED,
        CE_OBJECTALLOCATIONERROR,
        CE_INVALIDPARAMETERS,
        CE_DUPLICATEOVERRIDE,
        CE_UNEXPECTEDTOKEN,
        CE_OBJECTBASENOTFOUND,
        CE_UNSUPPORTEDBYRENDERSYSTEM,
        CE_REFERENCETOANONEXISTINGOBJECT
    }
    static string formatErrorCode(uint code)
    {
        switch(code)
        {
            case CE_STRINGEXPECTED:
                return "string expected";
            case CE_NUMBEREXPECTED:
                return "number expected";
            case CE_FEWERPARAMETERSEXPECTED:
                return "fewer parameters expected";
            case CE_VARIABLEEXPECTED:
                return "variable expected";
            case CE_UNDEFINEDVARIABLE:
                return "undefined variable";
            case CE_OBJECTNAMEEXPECTED:
                return "object name expected";
            case CE_OBJECTALLOCATIONERROR:
                return "object allocation error";
            case CE_INVALIDPARAMETERS:
                return "invalid parameters";
            case CE_DUPLICATEOVERRIDE:
                return "duplicate object override";
            case CE_UNSUPPORTEDBYRENDERSYSTEM:
                return "object unsupported by render system";
            case CE_REFERENCETOANONEXISTINGOBJECT:
                return "reference to a non existing object";
            default:
                return "unknown error";
        }
    }
public:
    this()
    {
        //mListener = null;
        initWordMap();
    }
    
    ~this() {}
    
    /// Takes in a string of script code and compiles it into resources
    /**
     * @param str The script code
     * @param source The source of the script code (e.g. a script file)
     * @param group The resource group to place the compiled resources into
     */
    bool compile(string str, string source, string group)
    {
        auto lexer = new ScriptLexer;
        auto parser = new ScriptParser;
        ConcreteNodeListPtr nodes = parser.parse(lexer.tokenize(str, source));
        return compile(nodes, group);
    }
    
    /// Compiles resources from the given concrete node list
    bool compile(/*const*/ ConcreteNodeListPtr nodes, string group)
    {
        // Set up the compilation context
        mGroup = group;
        
        // Clear the past errors
        mErrors.clear();
        
        // Clear the environment
        mEnv.clear();
        
        if(mListener)
            mListener.preConversion(this, nodes);
        
        // Convert our nodes to an AST
        AbstractNodeListPtr ast = convertToAST(nodes);
        // Processes the imports for this script
        processImports(ast);
        // Process object inheritance
        processObjects(ast.get(), ast);
        // Process variable expansion
        processVariables(ast.get());
        
        // Allows early bail-out through the listener
        if(mListener && !mListener.postConversion(this, ast))
            return mErrors.empty();
        
        // Translate the nodes
        foreach(i; ast)
        {
            //logAST(0, i);
            if(i.type == ANT_OBJECT && (cast(ObjectAbstractNode)i.get())._abstract)
                continue;
            //LogManager.getSingleton().logMessage((cast(ObjectAbstractNode)i.get()).name);
            ScriptTranslator translator = ScriptCompilerManager.getSingleton().getTranslator(i);
            
            if(translator)
                translator.translate(this, i);
        }
        
        mImports.clear();
        mImportRequests.clear();
        mImportTable.clear();
        
        return mErrors.empty();
    }
    
    /// Generates the AST from the given string script
    AbstractNodeListPtr _generateAST(string str, string source, bool doImports = false, bool doObjects = false, bool doVariables = false)
    {
        // Clear the past errors
        mErrors.clear();
        
        auto lexer = new ScriptLexer;
        auto parser = new ScriptParser;
        ConcreteNodeListPtr cst = parser.parse(lexer.tokenize(str, source));
        
        // Call the listener to intercept CST
        if(mListener)
            mListener.preConversion(this, cst);
        
        // Convert our nodes to an AST
        AbstractNodeListPtr ast = convertToAST(cst);
        
        if(!ast.isNull() && doImports)
            processImports(ast);
        if(!ast.isNull() && doObjects)
            processObjects(ast.get(), ast);
        if(!ast.isNull() && doVariables)
            processVariables(ast.get());
        
        return ast;
    }
    
    /// Compiles the given abstract syntax tree
    bool _compile(AbstractNodeListPtr nodes, string group, bool doImports = true, bool doObjects = true, bool doVariables = true)
    {
        // Set up the compilation context
        mGroup = group;
        
        // Clear the past errors
        mErrors.clear();
        
        // Clear the environment
        mEnv.clear();
        
        // Processes the imports for this script
        if(doImports)
            processImports(nodes);
        // Process object inheritance
        if(doObjects)
            processObjects(nodes.get(), nodes);
        // Process variable expansion
        if(doVariables)
            processVariables(nodes.get());
        
        // Translate the nodes
        foreach(i; nodes)
        {
            //logAST(0, *i);
            if(i.type == ANT_OBJECT && (cast(ObjectAbstractNode)i.get())._abstract)
                continue;
            ScriptTranslator translator = ScriptCompilerManager.getSingleton().getTranslator(i);
            if(translator)
                translator.translate(this, i);
        }
        
        return mErrors.empty();
    }
    
    /// Adds the given error to the compiler's list of errors
    void addError(uint code, string file, int line, string msg = "")
    {
        //ErrorPtr err = ErrorPtr(new Error);
        Error err;
        err.code = code;
        err.file = file;
        err.line = line;
        err.message = msg;
        
        if(mListener)
        {
            mListener.handleError(this, code, file, line, msg);
        }
        else
        {
            string str = "Compiler error: ";
            str = text(str, formatErrorCode(code), " in ", file, "(", line, ")");
            if(!msg.empty())
                str = str ~ ": " ~ msg;
            LogManager.getSingleton().logMessage(str);
        }
        
        mErrors ~= err;
    }
    
    /// Sets the listener used by the compiler
    void setListener(ScriptCompilerListener listener)
    {
        mListener = listener;
    }
    
    /// Returns the currently set listener
    ScriptCompilerListener getListener()
    {
        return mListener;
    }
    
    /// Returns the resource group currently set for this compiler
    string getResourceGroup()// const
    {
        return mGroup;
    }
    
    /// Adds a name exclusion to the map
    /**
     * Name exclusions identify object types which cannot accept
     * names. This means that excluded types will always have empty names.
     * All values in the object header are stored as object values.
     */
    //void addNameExclusion(string type); //FIXME MIA
    
    /// Removes a name exclusion
    //void removeNameExclusion(string type); //FIXME MIA
    
    /// Internal method for firing the handleEvent method
    bool _fireEvent(ScriptCompilerEvent evt, void *retval)
    {
        if(mListener)
            return mListener.handleEvent(this, evt, retval);
        return false;
    }
    
private: // Tree processing
    AbstractNodeListPtr convertToAST(/*const*/ ConcreteNodeListPtr nodes)
    {
        AbstractTreeBuilder builder = new AbstractTreeBuilder(this);
        AbstractTreeBuilder.visit(builder, nodes.get());
        return builder.getResult();
    }
    
    /// This built-in function processes import nodes
    void processImports(ref AbstractNodeListPtr nodes)
    {
        //FIXME Dup nodes for iteration
        //auto _nodes = nodes.dup;
        // We only need to iterate over the top-level of nodes
        //foreach(cur; _nodes)
        for(size_t i = 0; i < nodes.length; )
        {
            auto cur = nodes[i];
            // We move to the next node here and save the current one.
            // If any replacement happens, then we are still assured that
            // i points to the node *after* the replaced nodes, no matter
            // how many insertions and deletions may happen
            //AbstractNodeList::iterator cur = i++;
            
            if(cur.type == ANT_IMPORT)
            {
                ImportAbstractNode _import = cast(ImportAbstractNode)cur.get();
                // Only process if the file's contents haven't been loaded
                if((_import.source in mImports) is null)
                {
                    // Load the script
                    AbstractNodeListPtr importedNodes = loadImportPath(_import.source);
                    if(!importedNodes.isNull() && !importedNodes.empty())
                    {
                        processImports(importedNodes);
                        processObjects(importedNodes.get(), importedNodes);
                    }
                    if(!importedNodes.isNull() && !importedNodes.empty())
                        mImports[_import.source] = importedNodes;
                }
                
                // Handle the target request now
                // If it is a '*' import we remove all previous requests and just use the '*'
                // Otherwise, ensure '*' isn't already registered and register our request
                if(_import.target == "*")
                {
                    mImportRequests.remove(_import.source);
                    mImportRequests[_import.source] = null;
                    mImportRequests[_import.source] ~= "*";
                }
                else
                {
                    auto iter = mImportRequests[_import.source];
                    if(iter.empty || iter[0] != "*")
                    {
                        mImportRequests.initAA(_import.source);
                        mImportRequests[_import.source] ~= _import.target;
                    }
                }
                
                nodes.removeFromArray(cur);//TODO Works with dup'ing?
            }
            else
                i++;
        }
        
        // All import nodes are removed
        // We have cached the code blocks from all the imported scripts
        // We can process all import requests now
        foreach(k, it; mImports)
        {
            auto j = mImportRequests[k];
            if(!j.empty)
            {
                if(j[0] == "*")
                {
                    // Insert the entire AST into the import table
                    mImportTable = it ~ mImportTable; //TODO order important?
                    continue; // Skip ahead to the next file
                }
                else
                {
                    foreach(i; j)
                    {
                        // Locate this target and insert it into the import table
                        AbstractNodeListPtr newNodes = locateTarget(it.get(), i);
                        if(!newNodes.isNull() && !newNodes.get().empty())
                            //mImportTable ~= newNodes.get();
                            mImportTable = newNodes.get() ~ mImportTable;
                    }
                }
            }
        }
    }
    
    /// Loads the requested script and converts it to an AST
    AbstractNodeListPtr loadImportPath(string name)
    {
        AbstractNodeListPtr retval;
        ConcreteNodeListPtr nodes;
        
        if(mListener)
            nodes = mListener.importFile(this, name);
        
        if(nodes.isNull() && ResourceGroupManager.getSingletonPtr())
        {
            DataStream stream = ResourceGroupManager.getSingleton().openResource(name, mGroup);
            if(stream !is null)
            {
                auto lexer = new ScriptLexer;
                ScriptTokenListPtr tokens = lexer.tokenize(stream.getAsString(), name);
                auto parser = new ScriptParser;
                nodes = parser.parse(tokens);
            }
        }
        
        if(!nodes.isNull())
            retval = convertToAST(nodes);
        
        return retval;
    }
    
    /// Returns the abstract nodes from the given tree which represent the target
    AbstractNodeListPtr locateTarget(AbstractNodeList nodes, string target)
    {
        size_t iter = nodes.length;
        // Search for a top-level object node
        //TODO Top-level, reverse?
        foreach(i; 0..nodes.length)
        {
            auto ii = nodes[i];
            if(ii.type == ANT_OBJECT)
            {
                auto impl = cast(ObjectAbstractNode)ii.get();
                if(impl.name == target)
                    iter = i; //TODO put synchronized somewhere if foreach is optimized to something like OpenMP
            }
        }
        
        // MEMCATEGORY_GENERAL is the only category supported for SharedPtr
        AbstractNodeListPtr newNodes;
        newNodes ~= nodes[iter..$]; //shouldn't raise out-of-range
        return newNodes;
    }
    
    /// Handles object inheritance and variable expansion
    void processObjects(ref AbstractNodeList nodes, /*const*/ AbstractNodeListPtr top)
    {
        foreach(i; nodes)
        {
            if(i.type == ANT_OBJECT)
            {
                ObjectAbstractNode obj = cast(ObjectAbstractNode)i.get();
                
                // Overlay base classes in order.
                foreach (base; obj.bases)
                {
                    // Check the top level first, then check the import table
                    AbstractNodeListPtr newNodes = locateTarget(top.get(), base);
                    if(newNodes.empty())
                        newNodes = locateTarget(mImportTable, base);
                    
                    if (!newNodes.empty()) {
                        foreach(j; newNodes) {
                            overlayObject(j, obj);
                        }
                    } else {
                        addError(CE_OBJECTBASENOTFOUND, obj.file, obj.line,
                                 "base object named \"" ~ base ~ "\" not found in script definition");
                    }
                }
                
                // Recurse into children
                processObjects(obj.children, top);
                
                // Overrides now exist in obj's overrides list. These are non-object nodes which must now
                // Be placed in the children section of the object node such that overriding from parents
                // into children works properly.
                obj.children = obj.overrides ~ obj.children;
            }
        }
    }
    
    /// Handles processing the variables
    void processVariables(ref AbstractNodeList nodes)
    {
        for(size_t i = 0; i<nodes.length;)
        {
            auto cur = nodes[i];
                        
            if(cur.type == ANT_OBJECT)
            {
                // Only process if this object is not abstract
                ObjectAbstractNode obj = cast(ObjectAbstractNode)cur.get();
                if(!obj._abstract)
                {
                    processVariables(obj.children);
                    processVariables(obj.values);
                }
            }
            else if(cur.type == ANT_PROPERTY)
            {
                PropertyAbstractNode prop = cast(PropertyAbstractNode)cur.get();
                processVariables(prop.values);
            }
            else if(cur.type == ANT_VARIABLE_ACCESS)
            {
                VariableAccessAbstractNode var = cast(VariableAccessAbstractNode)cur.get();
                
                // Look up the enclosing scope
                ObjectAbstractNode _scope = null;
                AbstractNode temp = var.parent;
                while(temp)
                {
                    if(temp.type == ANT_OBJECT)
                    {
                        _scope = cast(ObjectAbstractNode)temp;
                        break;
                    }
                    temp = temp.parent;
                }
                
                // Look up the variable in the environment
                pair!(bool,string) varAccess;
                if(_scope)
                    varAccess = _scope.getVariable(var.name);
                if(!_scope || !varAccess.first)
                {
                    auto k = var.name in mEnv;
                    varAccess.first = (k !is null);
                    if(varAccess.first)
                        varAccess.second = *k;
                }
                
                if(varAccess.first)
                {
                    // Found the variable, so process it and insert it into the tree
                    auto lexer = new ScriptLexer;
                    ScriptTokenListPtr tokens = lexer.tokenize(varAccess.second, var.file);
                    auto parser = new ScriptParser;
                    ConcreteNodeListPtr cst = parser.parseChunk(tokens);
                    AbstractNodeListPtr ast = convertToAST(cst);
                    
                    // Set up ownership for these nodes
                    foreach(j; ast)
                        j.parent = var.parent;
                    
                    // Recursively handle variable accesses within the variable expansion
                    processVariables(ast.get());
                    
                    // Insert the nodes in place of the variable
                    //nodes.insert(cur, ast.begin(), ast.end());
                    nodes = nodes[0..i] ~ ast ~ nodes[i+1..$];//TODO i should stay < nodes.length
                }
                else
                {
                    // Error
                    addError(CE_UNDEFINEDVARIABLE, var.file, var.line);
                }
                
                // Remove the variable node
                nodes = nodes[0..i] ~ nodes[i+1..$];
                --i;
            }
            ++i;
        }
    }
    
    /// This function overlays the given object on the destination object following inheritance rules
    void overlayObject(/*const*/ AbstractNodePtr source, ObjectAbstractNode dest)
    {
        if(source.type == ANT_OBJECT)
        {
            ObjectAbstractNode src = cast(ObjectAbstractNode)source.get();
            
            // Overlay the environment of one on top the other first
            foreach(k,v; src.getVariables())
            {
                pair!(bool,string) var = dest.getVariable(k);
                if(!var.first)
                    dest.setVariable(k, v);
            }
            
            // Create a vector storing each pairing of override between source and destination
            //vector<std::pair<AbstractNodePtr,AbstractNodeList::iterator> >::type overrides; 
            pair!(AbstractNodePtr, AbstractNode)[] overrides;
            // A list of indices for each destination node tracks the minimum
            // source node they can index-match against
            size_t[ObjectAbstractNode] indices;
            // A map storing which nodes have overridden from the destination node
            bool[ObjectAbstractNode] overridden;
            
            // Fill the vector with objects from the source node (base)
            // And insert non-objects into the overrides list of the destination
            size_t insertPos = 0;
            foreach(i; 0..src.children.length)
            {
                auto child = src.children[i];
                if(child.type == ANT_OBJECT)
                {
                    overrides ~= pair!(AbstractNodePtr, AbstractNode)(child, null);//dest.children.length);
                }
                else
                {
                    AbstractNodePtr newNode = AbstractNodePtr(child.clone());
                    newNode.parent = dest;
                    dest.overrides ~= newNode;
                }
            }
            
            // Track the running maximum override index in the name-matching phase
            size_t maxOverrideIndex = 0;
            
            // Loop through destination children searching for name-matching overrides
            //foreach(i; dest.children)
            for(size_t i = 0; i<dest.children.length;)
            {
                if(dest.children[i].type == ANT_OBJECT)
                {
                    // Start tracking the override index position for this object
                    size_t overrideIndex = 0;
                    
                    ObjectAbstractNode node = cast(ObjectAbstractNode)dest.children[i].get();
                    indices[node] = maxOverrideIndex;
                    overridden[node] = false;
                    
                    // special treatment for materials with * in their name
                    bool nodeHasWildcard = (node.name.indexOf('*') != -1);
                    
                    // Find the matching name node
                    for(size_t j = 0; j < overrides.length; ++j)
                    {
                        ObjectAbstractNode temp = cast(ObjectAbstractNode)(overrides[j].first.get());
                        // Consider a match a node that has a wildcard and matches an input name
                        bool wildcardMatch = nodeHasWildcard && 
                            (StringUtil.match(temp.name,node.name,true) || 
                             (node.name.length == 1 && temp.name.empty()));
                        if(temp.cls == node.cls && !node.name.empty() && (temp.name == node.name || wildcardMatch))
                        {
                            // Pair these two together unless it's already paired
                            if(overrides[j].second is null)// == dest.children.end())
                            {
                                //FIXME Logic errors?
                                //AbstractNodeList::iterator currentIterator = i;
                                ObjectAbstractNode currentNode = node;
                                if (wildcardMatch)
                                {
                                    //If wildcard is matched, make a copy of current material and put it before the iterator, matching its name to the parent. Use same reinterpret cast as above when node is set
                                    AbstractNodePtr newNode = AbstractNodePtr(dest.children[i].clone());
                                    //currentIterator = dest.children.insert(currentIterator, newNode);
                                    dest.children = dest.children[0..i] ~ newNode ~ dest.children[i..$];
                                    i++;//skip newNode
                                    currentNode = cast(ObjectAbstractNode)newNode.get();
                                    currentNode.name = temp.name;//make the regex match its matcher
                                }
                                overrides[j] = pair!(AbstractNodePtr, AbstractNode)(overrides[j].first, currentNode);//currentIterator);
                                // Store the max override index for this matched pair
                                overrideIndex = j;
                                overrideIndex = (maxOverrideIndex = std.algorithm.max(overrideIndex, maxOverrideIndex));
                                indices[currentNode] = overrideIndex;
                                overridden[currentNode] = true;
                            }
                            else
                            {
                                addError(CE_DUPLICATEOVERRIDE, node.file, node.line);
                            }
                            
                            if(!wildcardMatch)
                                break;
                        }
                    }
                    
                    if (nodeHasWildcard)
                    {
                        //if the node has a wildcard it will be deleted since it was duplicated for every match
                        //AbstractNodeList::iterator deletable=i++;
                        dest.children.removeFromArrayIdx(i);
                    }
                    else
                    {
                        ++i; //Behavior in absence of regex, just increment iterator
                    }
                }
                else 
                {
                    ++i; //Behavior in absence of replaceable object, just increment iterator to find another
                }
            }
            
            // Now make matches based on index
            // Loop through destination children searching for name-matching overrides
            foreach(i; dest.children)
            {
                if(i.type == ANT_OBJECT)
                {
                    ObjectAbstractNode node = cast(ObjectAbstractNode)i.get();
                    if(!overridden[node])
                    {
                        // Retrieve the minimum override index from the map
                        size_t overrideIndex = indices[node];
                        
                        if(overrideIndex < overrides.length)
                        {
                            // Search for minimum matching override
                            for(size_t j = overrideIndex; j < overrides.length; ++j)
                            {
                                ObjectAbstractNode temp = cast(ObjectAbstractNode)(overrides[j].first.get());
                                if(temp.name.empty() && temp.cls == node.cls && overrides[j].second is null)// == dest.children.end())
                                {
                                    overrides[j] = pair!(AbstractNodePtr, AbstractNode)(overrides[j].first, i.get());
                                    break;
                                }
                            }
                        }
                    }
                }
            }
            
            // Loop through overrides, either inserting source nodes or overriding
            ptrdiff_t _insertPos = -1;//dest.children.begin();
            for(size_t i = 0; i < overrides.length; ++i)
            {
                if(overrides[i].second !is null)//!= dest.children.end())
                {
                    // Override the destination with the source (base) object
                    overlayObject(overrides[i].first, 
                                  cast(ObjectAbstractNode)overrides[i].second);
                    //insertPos = overrides[i].second;
                    //TODO Maybe can force slices (Range?) to work as c++ iterators?
                    _insertPos = .countUntil!"a.get() == b"(dest.children, overrides[i].second);
                    if(_insertPos > -1)
                        _insertPos++;
                }
                else
                {
                    // No override was possible, so insert this node at the insert position
                    // into the destination (child) object
                    AbstractNodePtr newNode = AbstractNodePtr(overrides[i].first.clone());
                    newNode.parent = dest;
                    if(_insertPos > -1)//!= dest.children.end())
                    {
                        dest.children = dest.children[0.._insertPos] ~ newNode ~ dest.children[_insertPos..$];
                    }
                    else
                    {
                        dest.children ~= newNode;
                    }
                }
            }
        }
    }
    
    /// Returns true if the given class is name excluded
    bool isNameExcluded(string cls, AbstractNode parent)
    {
        // Run past the listener
        bool excludeName = false;
        auto evt = new ProcessNameExclusionScriptCompilerEvent(cls, parent);
        bool processed = _fireEvent(evt, cast(void*)&excludeName);
        
        if(!processed)
        {
            // Process the built-in name exclusions
            if(cls == "emitter" || cls == "affector")
            {
                // emitters or affectors inside a particle_system are excluded
                while(parent && parent.type == ANT_OBJECT)
                {
                    ObjectAbstractNode obj = cast(ObjectAbstractNode)parent;
                    if(obj.cls == "particle_system")
                        return true;
                    parent = obj.parent;
                }
                return false;
            }
            else if(cls == "pass")
            {
                // passes inside compositors are excluded
                while(parent && parent.type == ANT_OBJECT)
                {
                    ObjectAbstractNode obj = cast(ObjectAbstractNode)parent;
                    if(obj.cls == "compositor")
                        return true;
                    parent = obj.parent;
                }
                return false;
            }
            else if(cls == "texture_source")
            {
                // Parent must be texture_unit
                while(parent && parent.type == ANT_OBJECT)
                {
                    ObjectAbstractNode obj = cast(ObjectAbstractNode)parent;
                    if(obj.cls == "texture_unit")
                        return true;
                    parent = obj.parent;
                }
                return false;
            }
        }
        else
        {
            return excludeName;
        }
        return false;
    }
    
    /// This function sets up the initial values in word id map
    void initWordMap()
    {
        mIds["on"] = ScriptCompiler.ID_ON;
        mIds["off"] = ScriptCompiler.ID_OFF;
        mIds["true"] = ScriptCompiler.ID_TRUE;
        mIds["false"] = ScriptCompiler.ID_FALSE;
        mIds["yes"] = ScriptCompiler.ID_YES;
        mIds["no"] = ScriptCompiler.ID_NO;
        
        // Material ids
        mIds["material"] = ID_MATERIAL;
        mIds["vertex_program"] = ID_VERTEX_PROGRAM;
        mIds["geometry_program"] = ID_GEOMETRY_PROGRAM;
        mIds["fragment_program"] = ID_FRAGMENT_PROGRAM;
        mIds["tesselation_hull_program"] = ID_TESSELATION_HULL_PROGRAM;
        mIds["tesselation_domain_program"] = ID_TESSELATION_DOMAIN_PROGRAM;
        mIds["compute_program"] = ID_COMPUTE_PROGRAM;
        mIds["technique"] = ID_TECHNIQUE;
        mIds["pass"] = ID_PASS;
        mIds["texture_unit"] = ID_TEXTURE_UNIT;
        mIds["vertex_program_ref"] = ID_VERTEX_PROGRAM_REF;
        mIds["geometry_program_ref"] = ID_GEOMETRY_PROGRAM_REF;
        mIds["fragment_program_ref"] = ID_FRAGMENT_PROGRAM_REF;
        mIds["tesselation_hull_program_ref"] = ID_TESSELATION_HULL_PROGRAM_REF;
        mIds["tesselation_domain_program_ref"] = ID_TESSELATION_DOMAIN_PROGRAM_REF;
        mIds["compute_program_ref"] = ID_COMPUTE_PROGRAM_REF;
        mIds["shadow_caster_vertex_program_ref"] = ID_SHADOW_CASTER_VERTEX_PROGRAM_REF;
        mIds["shadow_caster_fragment_program_ref"] = ID_SHADOW_CASTER_FRAGMENT_PROGRAM_REF;
        mIds["shadow_receiver_vertex_program_ref"] = ID_SHADOW_RECEIVER_VERTEX_PROGRAM_REF;
        mIds["shadow_receiver_fragment_program_ref"] = ID_SHADOW_RECEIVER_FRAGMENT_PROGRAM_REF;
        
        mIds["lod_values"] = ID_LOD_VALUES;
        mIds["lod_strategy"] = ID_LOD_STRATEGY;
        mIds["lod_distances"] = ID_LOD_DISTANCES;
        mIds["receive_shadows"] = ID_RECEIVE_SHADOWS;
        mIds["transparency_casts_shadows"] = ID_TRANSPARENCY_CASTS_SHADOWS;
        mIds["set_texture_alias"] = ID_SET_TEXTURE_ALIAS;
        
        mIds["source"] = ID_SOURCE;
        mIds["syntax"] = ID_SYNTAX;
        mIds["default_params"] = ID_DEFAULT_PARAMS;
        mIds["param_indexed"] = ID_PARAM_INDEXED;
        mIds["param_named"] = ID_PARAM_NAMED;
        mIds["param_indexed_auto"] = ID_PARAM_INDEXED_AUTO;
        mIds["param_named_auto"] = ID_PARAM_NAMED_AUTO;
        
        mIds["scheme"] = ID_SCHEME;
        mIds["lod_index"] = ID_LOD_INDEX;
        mIds["shadow_caster_material"] = ID_SHADOW_CASTER_MATERIAL;
        mIds["shadow_receiver_material"] = ID_SHADOW_RECEIVER_MATERIAL;
        mIds["gpu_vendor_rule"] = ID_GPU_VENDOR_RULE;
        mIds["gpu_device_rule"] = ID_GPU_DEVICE_RULE;
        mIds["include"] = ID_INCLUDE;
        mIds["exclude"] = ID_EXCLUDE;
        
        mIds["ambient"] = ID_AMBIENT;
        mIds["diffuse"] = ID_DIFFUSE;
        mIds["specular"] = ID_SPECULAR;
        mIds["emissive"] = ID_EMISSIVE;
        mIds["vertexcolour"] = ID_VERTEXCOLOUR;
        mIds["scene_blend"] = ID_SCENE_BLEND;
        mIds["colour_blend"] = ID_COLOUR_BLEND;
        mIds["one"] = ID_ONE;
        mIds["zero"] = ID_ZERO;
        mIds["dest_colour"] = ID_DEST_COLOUR;
        mIds["src_colour"] = ID_SRC_COLOUR;
        mIds["one_minus_src_colour"] = ID_ONE_MINUS_SRC_COLOUR;
        mIds["one_minus_dest_colour"] = ID_ONE_MINUS_DEST_COLOUR;
        mIds["dest_alpha"] = ID_DEST_ALPHA;
        mIds["src_alpha"] = ID_SRC_ALPHA;
        mIds["one_minus_dest_alpha"] = ID_ONE_MINUS_DEST_ALPHA;
        mIds["one_minus_src_alpha"] = ID_ONE_MINUS_SRC_ALPHA;
        mIds["separate_scene_blend"] = ID_SEPARATE_SCENE_BLEND;
        mIds["scene_blend_op"] = ID_SCENE_BLEND_OP;
        mIds["reverse_subtract"] = ID_REVERSE_SUBTRACT;
        mIds["min"] = ID_MIN;
        mIds["max"] = ID_MAX;
        mIds["separate_scene_blend_op"] = ID_SEPARATE_SCENE_BLEND_OP;
        mIds["depth_check"] = ID_DEPTH_CHECK;
        mIds["depth_write"] = ID_DEPTH_WRITE;
        mIds["depth_func"] = ID_DEPTH_FUNC;
        mIds["depth_bias"] = ID_DEPTH_BIAS;
        mIds["iteration_depth_bias"] = ID_ITERATION_DEPTH_BIAS;
        mIds["always_fail"] = ID_ALWAYS_FAIL;
        mIds["always_pass"] = ID_ALWAYS_PASS;
        mIds["less_equal"] = ID_LESS_EQUAL;
        mIds["less"] = ID_LESS;
        mIds["equal"] = ID_EQUAL;
        mIds["not_equal"] = ID_NOT_EQUAL;
        mIds["greater_equal"] = ID_GREATER_EQUAL;
        mIds["greater"] = ID_GREATER;
        mIds["alpha_rejection"] = ID_ALPHA_REJECTION;
        mIds["alpha_to_coverage"] = ID_ALPHA_TO_COVERAGE;
        mIds["light_scissor"] = ID_LIGHT_SCISSOR;
        mIds["light_clip_planes"] = ID_LIGHT_CLIP_PLANES;
        mIds["transparent_sorting"] = ID_TRANSPARENT_SORTING;
        mIds["illumination_stage"] = ID_ILLUMINATION_STAGE;
        mIds["decal"] = ID_DECAL;
        mIds["cull_hardware"] = ID_CULL_HARDWARE;
        mIds["clockwise"] = ID_CLOCKWISE;
        mIds["anticlockwise"] = ID_ANTICLOCKWISE;
        mIds["cull_software"] = ID_CULL_SOFTWARE;
        mIds["back"] = ID_BACK;
        mIds["front"] = ID_FRONT;
        mIds["normalise_normals"] = ID_NORMALISE_NORMALS;
        mIds["lighting"] = ID_LIGHTING;
        mIds["shading"] = ID_SHADING;
        mIds["flat"] = ID_FLAT;
        mIds["gouraud"] = ID_GOURAUD;
        mIds["phong"] = ID_PHONG;
        mIds["polygon_mode"] = ID_POLYGON_MODE;
        mIds["solid"] = ID_SOLID;
        mIds["wireframe"] = ID_WIREFRAME;
        mIds["points"] = ID_POINTS;
        mIds["polygon_mode_overrideable"] = ID_POLYGON_MODE_OVERRIDEABLE;
        mIds["fog_override"] = ID_FOG_OVERRIDE;
        mIds["none"] = ID_NONE;
        mIds["linear"] = ID_LINEAR;
        mIds["exp"] = ID_EXP;
        mIds["exp2"] = ID_EXP2;
        mIds["colour_write"] = ID_COLOUR_WRITE;
        mIds["max_lights"] = ID_MAX_LIGHTS;
        mIds["start_light"] = ID_START_LIGHT;
        mIds["iteration"] = ID_ITERATION;
        mIds["once"] = ID_ONCE;
        mIds["once_per_light"] = ID_ONCE_PER_LIGHT;
        mIds["per_n_lights"] = ID_PER_N_LIGHTS;
        mIds["per_light"] = ID_PER_LIGHT;
        mIds["point"] = ID_POINT;
        mIds["spot"] = ID_SPOT;
        mIds["directional"] = ID_DIRECTIONAL;
        mIds["light_mask"] = ID_LIGHT_MASK;
        mIds["point_size"] = ID_POINT_SIZE;
        mIds["point_sprites"] = ID_POINT_SPRITES;
        mIds["point_size_min"] = ID_POINT_SIZE_MIN;
        mIds["point_size_max"] = ID_POINT_SIZE_MAX;
        mIds["point_size_attenuation"] = ID_POINT_SIZE_ATTENUATION;
        
        mIds["texture_alias"] = ID_TEXTURE_ALIAS;
        mIds["texture"] = ID_TEXTURE;
        mIds["1d"] = ID_1D;
        mIds["2d"] = ID_2D;
        mIds["3d"] = ID_3D;
        mIds["cubic"] = ID_CUBIC;
        mIds["unlimited"] = ID_UNLIMITED;
        mIds["2darray"] = ID_2DARRAY;
        mIds["alpha"] = ID_ALPHA;
        mIds["gamma"] = ID_GAMMA;
        mIds["anim_texture"] = ID_ANIM_TEXTURE;
        mIds["cubic_texture"] = ID_CUBIC_TEXTURE;
        mIds["separateUV"] = ID_SEPARATE_UV;
        mIds["combinedUVW"] = ID_COMBINED_UVW;
        mIds["tex_coord_set"] = ID_TEX_COORD_SET;
        mIds["tex_address_mode"] = ID_TEX_ADDRESS_MODE;
        mIds["wrap"] = ID_WRAP;
        mIds["clamp"] = ID_CLAMP;
        mIds["mirror"] = ID_MIRROR;
        mIds["border"] = ID_BORDER;
        mIds["tex_border_colour"] = ID_TEX_BORDER_COLOUR;
        mIds["filtering"] = ID_FILTERING;
        mIds["bilinear"] = ID_BILINEAR;
        mIds["trilinear"] = ID_TRILINEAR;
        mIds["anisotropic"] = ID_ANISOTROPIC;
        mIds["compare_test"] = ID_CMPTEST;
        mIds["compare_func"] = ID_CMPFUNC;
        mIds["max_anisotropy"] = ID_MAX_ANISOTROPY;
        mIds["mipmap_bias"] = ID_MIPMAP_BIAS;
        mIds["colour_op"] = ID_COLOUR_OP;
        mIds["replace"] = ID_REPLACE;
        mIds["add"] = ID_ADD;
        mIds["modulate"] = ID_MODULATE;
        mIds["alpha_blend"] = ID_ALPHA_BLEND;
        mIds["colour_op_ex"] = ID_COLOUR_OP_EX;
        mIds["source1"] = ID_SOURCE1;
        mIds["source2"] = ID_SOURCE2;
        mIds["modulate"] = ID_MODULATE;
        mIds["modulate_x2"] = ID_MODULATE_X2;
        mIds["modulate_x4"] = ID_MODULATE_X4;
        mIds["add"] = ID_ADD;
        mIds["add_signed"] = ID_ADD_SIGNED;
        mIds["add_smooth"] = ID_ADD_SMOOTH;
        mIds["subtract"] = ID_SUBTRACT;
        mIds["blend_diffuse_alpha"] = ID_BLEND_DIFFUSE_ALPHA;
        mIds["blend_texture_alpha"] = ID_BLEND_TEXTURE_ALPHA;
        mIds["blend_current_alpha"] = ID_BLEND_CURRENT_ALPHA;
        mIds["blend_manual"] = ID_BLEND_MANUAL;
        mIds["dotproduct"] = ID_DOT_PRODUCT;
        mIds["blend_diffuse_colour"] = ID_BLEND_DIFFUSE_COLOUR;
        mIds["src_current"] = ID_SRC_CURRENT;
        mIds["src_texture"] = ID_SRC_TEXTURE;
        mIds["src_diffuse"] = ID_SRC_DIFFUSE;
        mIds["src_specular"] = ID_SRC_SPECULAR;
        mIds["src_manual"] = ID_SRC_MANUAL;
        mIds["colour_op_multipass_fallback"] = ID_COLOUR_OP_MULTIPASS_FALLBACK;
        mIds["alpha_op_ex"] = ID_ALPHA_OP_EX;
        mIds["env_map"] = ID_ENV_MAP;
        mIds["spherical"] = ID_SPHERICAL;
        mIds["planar"] = ID_PLANAR;
        mIds["cubic_reflection"] = ID_CUBIC_REFLECTION;
        mIds["cubic_normal"] = ID_CUBIC_NORMAL;
        mIds["scroll"] = ID_SCROLL;
        mIds["scroll_anim"] = ID_SCROLL_ANIM;
        mIds["rotate"] = ID_ROTATE;
        mIds["rotate_anim"] = ID_ROTATE_ANIM;
        mIds["scale"] = ID_SCALE;
        mIds["wave_xform"] = ID_WAVE_XFORM;
        mIds["scroll_x"] = ID_SCROLL_X;
        mIds["scroll_y"] = ID_SCROLL_Y;
        mIds["scale_x"] = ID_SCALE_X;
        mIds["scale_y"] = ID_SCALE_Y;
        mIds["sine"] = ID_SINE;
        mIds["triangle"] = ID_TRIANGLE;
        mIds["sawtooth"] = ID_SAWTOOTH;
        mIds["square"] = ID_SQUARE;
        mIds["inverse_sawtooth"] = ID_INVERSE_SAWTOOTH;
        mIds["transform"] = ID_TRANSFORM;
        mIds["binding_type"] = ID_BINDING_TYPE;
        mIds["vertex"] = ID_VERTEX;
        mIds["fragment"] = ID_FRAGMENT;
        mIds["geometry"] = ID_GEOMETRY;
        mIds["tesselation_hull"] = ID_TESSELATION_HULL;
        mIds["tesselation_domain"] = ID_TESSELATION_DOMAIN;
        mIds["compute"] = ID_COMPUTE;
        mIds["content_type"] = ID_CONTENT_TYPE;
        mIds["named"] = ID_NAMED;
        mIds["shadow"] = ID_SHADOW;
        mIds["texture_source"] = ID_TEXTURE_SOURCE;
        mIds["shared_params"] = ID_SHARED_PARAMS;
        mIds["shared_param_named"] = ID_SHARED_PARAM_NAMED;
        mIds["shared_params_ref"] = ID_SHARED_PARAMS_REF;
        
        // Particle system
        mIds["particle_system"] = ID_PARTICLE_SYSTEM;
        mIds["emitter"] = ID_EMITTER;
        mIds["affector"] = ID_AFFECTOR;
        
        // Compositor
        mIds["compositor"] = ID_COMPOSITOR;
        mIds["target"] = ID_TARGET;
        mIds["target_output"] = ID_TARGET_OUTPUT;
        
        mIds["input"] = ID_INPUT;
        mIds["none"] = ID_NONE;
        mIds["previous"] = ID_PREVIOUS;
        mIds["target_width"] = ID_TARGET_WIDTH;
        mIds["target_height"] = ID_TARGET_HEIGHT;
        mIds["target_width_scaled"] = ID_TARGET_WIDTH_SCALED;
        mIds["target_height_scaled"] = ID_TARGET_HEIGHT_SCALED;
        mIds["pooled"] = ID_POOLED;
        //mIds["gamma"] = ID_GAMMA; - already registered
        mIds["no_fsaa"] = ID_NO_FSAA;
        mIds["depth_pool"] = ID_DEPTH_POOL;
        
        mIds["texture_ref"] = ID_TEXTURE_REF;
        mIds["local_scope"] = ID_SCOPE_LOCAL;
        mIds["chain_scope"] = ID_SCOPE_CHAIN;
        mIds["global_scope"] = ID_SCOPE_GLOBAL;
        mIds["compositor_logic"] = ID_COMPOSITOR_LOGIC;
        
        mIds["only_initial"] = ID_ONLY_INITIAL;
        mIds["visibility_mask"] = ID_VISIBILITY_MASK;
        mIds["lod_bias"] = ID_LOD_BIAS;
        mIds["material_scheme"] = ID_MATERIAL_SCHEME;
        mIds["shadows"] = ID_SHADOWS_ENABLED;
        
        mIds["clear"] = ID_CLEAR;
        mIds["stencil"] = ID_STENCIL;
        mIds["render_scene"] = ID_RENDER_SCENE;
        mIds["render_quad"] = ID_RENDER_QUAD;
        mIds["identifier"] = ID_IDENTIFIER;
        mIds["first_render_queue"] = ID_FIRST_RENDER_QUEUE;
        mIds["last_render_queue"] = ID_LAST_RENDER_QUEUE;
        mIds["quad_normals"] = ID_QUAD_NORMALS;
        mIds["camera_far_corners_view_space"] = ID_CAMERA_FAR_CORNERS_VIEW_SPACE;
        mIds["camera_far_corners_world_space"] = ID_CAMERA_FAR_CORNERS_WORLD_SPACE;
        
        mIds["buffers"] = ID_BUFFERS;
        mIds["colour"] = ID_COLOUR;
        mIds["depth"] = ID_DEPTH;
        mIds["colour_value"] = ID_COLOUR_VALUE;
        mIds["depth_value"] = ID_DEPTH_VALUE;
        mIds["stencil_value"] = ID_STENCIL_VALUE;
        
        mIds["check"] = ID_CHECK;
        mIds["comp_func"] = ID_COMP_FUNC;
        mIds["ref_value"] = ID_REF_VALUE;
        mIds["mask"] = ID_MASK;
        mIds["fail_op"] = ID_FAIL_OP;
        mIds["keep"] = ID_KEEP;
        mIds["increment"] = ID_INCREMENT;
        mIds["decrement"] = ID_DECREMENT;
        mIds["increment_wrap"] = ID_INCREMENT_WRAP;
        mIds["decrement_wrap"] = ID_DECREMENT_WRAP;
        mIds["invert"] = ID_INVERT;
        mIds["depth_fail_op"] = ID_DEPTH_FAIL_OP;
        mIds["pass_op"] = ID_PASS_OP;
        mIds["two_sided"] = ID_TWO_SIDED;
        static if(RTSHADER_SYSTEM_BUILD_CORE_SHADERS)
            mIds["rtshader_system"] = ID_RT_SHADER_SYSTEM;
        
        mIds["subroutine"] = ID_SUBROUTINE;
    }
    
private:
    // Resource group
    string mGroup;
    // The word -=> id conversion table
    IdMap mIds;
    // This is an environment map
    alias string[string] Environment;
    Environment mEnv;
    
    alias AbstractNodeListPtr[string] ImportCacheMap;
    ImportCacheMap mImports; // The set of imported scripts to avoid circular dependencies
    alias string[][string] ImportRequestMap;
    ImportRequestMap mImportRequests; // This holds the target objects for each script to be imported
    
    // This stores the imports of the scripts, so they are separated and can be treated specially
    AbstractNodeList mImportTable;
    
    // Error list
    ErrorList mErrors;
    
    // The listener
    ScriptCompilerListener mListener;
private: // Internal helper classes and processors
    class AbstractTreeBuilder
    {
    private:
        AbstractNodeListPtr mNodes;
        AbstractNode mCurrent;
        ScriptCompiler mCompiler;
    public:
        this(ScriptCompiler compiler)
        {
            mCompiler = compiler;
        }
        AbstractNodeListPtr getResult()// const;
        {
            return mNodes;
        }
        
        void visit(ConcreteNode* node)
        {
            AbstractNodePtr asn;
            
            // Import = "import" >> 2 children, mCurrent == null
            if(node.type == CNT_IMPORT && mCurrent is null)
            {
                if(node.children.length > 2)
                {
                    mCompiler.addError(CE_FEWERPARAMETERSEXPECTED, node.file, node.line);
                    return;
                }
                if(node.children.length < 2)
                {
                    mCompiler.addError(CE_STRINGEXPECTED, node.file, node.line);
                    return;
                }
                
                ImportAbstractNode impl = new ImportAbstractNode();
                impl.line = node.line;
                impl.file = node.file;
                
                //ConcreteNodeList::iterator iter = node.children.begin();
                impl.target = node.children[0].token;
                
                //iter++;
                impl.source = node.children[1].token;
                
                asn = AbstractNodePtr(impl);
            }
            // variable set = "set" >> 2 children, children[0] == variable
            else if(node.type == CNT_VARIABLE_ASSIGN)
            {
                if(node.children.length > 2)
                {
                    mCompiler.addError(CE_FEWERPARAMETERSEXPECTED, node.file, node.line);
                    return;
                }
                if(node.children.length < 2)
                {
                    mCompiler.addError(CE_STRINGEXPECTED, node.file, node.line);
                    return;
                }
                if(node.children.front().type != CNT_VARIABLE)
                {
                    mCompiler.addError(CE_VARIABLEEXPECTED, node.children.front().file, node.children.front().line);
                    return;
                }
                
                //ConcreteNodeList::iterator i = node.children.begin();
                string name = node.children[0].token;
                
                //++i;
                string value = node.children[1].token;
                
                if(mCurrent && mCurrent.type == ANT_OBJECT)
                {
                    ObjectAbstractNode ptr = cast(ObjectAbstractNode)mCurrent;
                    ptr.setVariable(name, value);
                }
                else
                {
                    mCompiler.mEnv[name] = value;
                }
            }
            // variable = $*, no children
            else if(node.type == CNT_VARIABLE)
            {
                if(!node.children.empty())
                {
                    mCompiler.addError(CE_FEWERPARAMETERSEXPECTED, node.file, node.line);
                    return;
                }
                
                VariableAccessAbstractNode impl = new VariableAccessAbstractNode(mCurrent);
                impl.line = node.line;
                impl.file = node.file;
                impl.name = node.token;
                
                asn = AbstractNodePtr(impl);
            }
            // Handle properties and objects here
            else if(!node.children.empty())
            {
                // Grab the last two nodes
                ConcreteNodePtr temp1, temp2;
                /*ConcreteNodeList::reverse_iterator riter = node.children.rbegin();
                if(riter != node.children.rend())
                {
                    temp1 = *riter;
                    riter++;
                }
                if(riter != node.children.rend())
                    temp2 = *riter;*/
                
                if(node.children.length>0)
                    temp1 = node.children[$-1];
                if(node.children.length>1)
                    temp2 = node.children[$-2];
                                
                // object = last 2 children == { and }
                if(!temp1.isNull() && !temp2.isNull() &&
                   temp1.type == CNT_RBRACE && temp2.type == CNT_LBRACE)
                {
                    if(node.children.length < 2)//TODO Uhmm, if < 2 then how did it get here?
                    {
                        mCompiler.addError(CE_STRINGEXPECTED, node.file, node.line);
                        return;
                    }
                    
                    ObjectAbstractNode impl = new ObjectAbstractNode(mCurrent);
                    impl.line = node.line;
                    impl.file = node.file;
                    impl._abstract = false;
                    
                    // Create a temporary detail list
                    ConcreteNode*[] temp;
                    if(node.token == "abstract")
                    {
                        impl._abstract = true;
                        foreach(i; node.children)
                            temp ~= i.get();
                    }
                    else
                    {
                        temp ~= node;
                        foreach(i; node.children)
                            temp ~= i.get();
                    }
                    
                    // Get the type of object
                    //list<ConcreteNode*>::type::const_iterator iter = temp.begin();
                    size_t iter = 0;
                    impl.cls = temp[iter].token;
                    ++iter;
                    
                    // Get the name
                    // Unless the type is in the exclusion list
                    if(iter < temp.length && (temp[iter].type == CNT_WORD || temp[iter].type == CNT_QUOTE) &&
                       !mCompiler.isNameExcluded(impl.cls, mCurrent))
                    {
                        impl.name = temp[iter].token;
                        ++iter;
                    }
                    
                    // Everything up until the colon is a "value" of this object
                    while(iter < temp.length && temp[iter].type != CNT_COLON && temp[iter].type != CNT_LBRACE)
                    {
                        if(temp[iter].type == CNT_VARIABLE)
                        {
                            VariableAccessAbstractNode var = new VariableAccessAbstractNode(impl);
                            var.file = temp[iter].file;
                            var.line = temp[iter].line;
                            var.type = ANT_VARIABLE_ACCESS;
                            var.name = temp[iter].token;
                            impl.values ~= AbstractNodePtr(var);
                        }
                        else
                        {
                            AtomAbstractNode atom = new AtomAbstractNode(impl);
                            atom.file = temp[iter].file;
                            atom.line = temp[iter].line;
                            atom.type = ANT_ATOM;
                            atom.value = temp[iter].token;
                            impl.values ~= AbstractNodePtr(atom);
                        }
                        ++iter;
                    }
                    
                    // Find the bases
                    if(iter < temp.length && temp[iter].type == CNT_COLON)
                    {
                        // Children of the ':' are bases
                        foreach(j; temp[iter].children)
                            impl.bases ~= j.token;
                        ++iter;
                    }
                    
                    // Finally try to map the cls to an id
                    auto iter2 = impl.cls in mCompiler.mIds;
                    if(iter2 !is null)
                    {
                        impl.id = *iter2;
                    }
                    else
                    {
                        mCompiler.addError(CE_UNEXPECTEDTOKEN, impl.file, impl.line, "token class, " ~ impl.cls ~ ", unrecognized.");
                    }
                    
                    asn = AbstractNodePtr(impl);
                    mCurrent = impl;
                    
                    // Visit the children of the {
                    AbstractTreeBuilder.visit(this, temp2.children);
                    
                    // Go back up the stack
                    mCurrent = impl.parent;
                }
                // Otherwise, it is a property
                else
                {
                    //FIXME ANT_PROPERTY, for some reason "pass" and "technique" etc drop to here
                    PropertyAbstractNode impl = new PropertyAbstractNode(mCurrent);
                    impl.line = node.line;
                    impl.file = node.file;
                    impl.name = node.token;
                    
                    auto iter2 = impl.name in mCompiler.mIds;
                    if(iter2 !is null)
                        impl.id = *iter2;
                    
                    asn = AbstractNodePtr(impl);
                    mCurrent = impl;
                    
                    // Visit the children of the {
                    AbstractTreeBuilder.visit(this, node.children);
                    
                    // Go back up the stack
                    mCurrent = impl.parent;
                }
            }
            // Otherwise, it is a standard atom
            else
            {
                AtomAbstractNode impl = new AtomAbstractNode(mCurrent);
                impl.line = node.line;
                impl.file = node.file;
                impl.value = node.token;
                
                auto iter2 = impl.value in mCompiler.mIds;
                if(iter2 !is null)
                    impl.id = *iter2;
                
                asn = AbstractNodePtr(impl);
            }
            
            // Here, we must insert the node into the tree
            if(!asn.isNull())
            {
                if(mCurrent)
                {
                    if(mCurrent.type == ANT_PROPERTY)
                    {
                        PropertyAbstractNode impl = cast(PropertyAbstractNode)mCurrent;
                        impl.values ~= asn;
                    }
                    else
                    {
                        ObjectAbstractNode impl = cast(ObjectAbstractNode)mCurrent;
                        impl.children ~= asn;
                    }
                }
                else
                {
                    mNodes ~= asn;
                }
            }
        }
        
        static void visit(AbstractTreeBuilder visitor, /*const*/ ConcreteNodeList nodes)
        {
            foreach(i; nodes)
                visitor.visit(i.get());
        }
    }
    
    //friend class AbstractTreeBuilder;
public: // Public translator definitions
    // This enum are built-in word id values
    enum
    {
        ID_ON = 1,
        ID_OFF = 2,
        ID_TRUE = 1,
        ID_FALSE = 2,
        ID_YES = 1,
        ID_NO = 2
    }
}

/**
 * This struct is a base class for events which can be thrown by the compilers and caught by
 * subscribers. There are a set number of standard events which are used by Ogre's core.
 * New event types may be derived for more custom compiler processing.
 */
class ScriptCompilerEvent
{
public:
    string mType;
    
    this(string type){ mType = type; }
    ~this(){}
//private: // Non-copyable
//    this(const ScriptCompilerEvent&);
//    ScriptCompilerEvent &operator = (const ScriptCompilerEvent&);
}

/** This is a listener for the compiler. The compiler can be customized with
 this listener. It lets you listen in on events occurring during compilation,
 hook them, and change the behavior.
 */
class ScriptCompilerListener
{
public:
    this() {}
    ~this() {}
    
    /// Returns the concrete node list from the given file
    ConcreteNodeListPtr importFile(ScriptCompiler compiler, string name)
    {
        return ConcreteNodeListPtr();
    }
    
    /// Allows for responding to and overriding behavior before a CST is translated into an AST
    void preConversion(ScriptCompiler compiler, ConcreteNodeListPtr nodes)
    {
    
    }
    
    /// Allows vetoing of continued compilation after the entire AST conversion process finishes
    /**
     @remarks   Once the script is turned completely into an AST, including import
     and override handling, this function allows a listener to exit
     the compilation process.
     @return True continues compilation, false aborts
     */
    bool postConversion(ScriptCompiler compiler, /*const*/ AbstractNodeListPtr)
    {
        return true;
    }
    
    /// Called when an error occurred
    void handleError(ScriptCompiler compiler, uint code, string file, int line, string msg)
    {
        string str = text("Compiler error: ", ScriptCompiler.formatErrorCode(code), " in ", file, "(", line, ")");
        if(!msg.empty())
            str = str ~ ": " ~ msg;
        LogManager.getSingleton().logMessage(str);
    }
    
    /// Called when an event occurs during translation, return true if handled
    /**
     @remarks   This function is called from the translators when an event occurs that
     that can be responded to. Often this is overriding names, or it can be a request for
     custom resource creation.
     @arg compiler A reference to the compiler
     @arg evt The event object holding information about the event to be processed
     @arg retval A possible return value from handlers
     @return True if the handler processed the event
     */
    bool handleEvent(ScriptCompiler compiler, ScriptCompilerEvent evt, void *retval)
    {
        return false;
    }
}


/** Manages threaded compilation of scripts. This script loader forwards
 scripts compilations to a specific compiler instance.
 */
class ScriptCompilerManager : ScriptLoader//, public ScriptCompilerAlloc
{
    mixin Singleton!ScriptCompilerManager;
     
private:
    //OGRE_AUTO_MUTEX
    Mutex mLock;
        
    // A list of patterns loaded by this compiler manager
    string[] mScriptPatterns;
    
    // A pointer to the listener used for compiling scripts
    ScriptCompilerListener mListener;
    
    // Stores a map from object types to the translators that handle them
    //vector<ScriptTranslatorManager*>::type mManagers;
    ScriptTranslatorManager[] mManagers;
    
    // A pointer to the built-in ScriptTranslatorManager
    ScriptTranslatorManager mBuiltinTranslatorManager;
    
    // A pointer to the specific compiler instance used
    //OGRE_THREAD_POINTER(ScriptCompiler, mScriptCompiler);
    ScriptCompiler mScriptCompiler;//TODO DMD2 and TLS?
public:
    this()
    {
        //OGRE_THREAD_POINTER_INIT(mScriptCompiler)
        mLock = new Mutex;
        
        //OGRE_LOCK_AUTO_MUTEX
        mScriptPatterns ~= "*.program";
        mScriptPatterns ~= "*.material";
        mScriptPatterns ~= "*.particle";
        mScriptPatterns ~= "*.compositor";
        mScriptPatterns ~= "*.os";
        ResourceGroupManager.getSingleton()._registerScriptLoader(this);
        
        //OGRE_THREAD_POINTER_SET(mScriptCompiler, OGRE_NEW ScriptCompiler());
        mScriptCompiler = new ScriptCompiler;
        
        mBuiltinTranslatorManager = new BuiltinScriptTranslatorManager();
        mManagers ~= mBuiltinTranslatorManager;
    }
    
    ~this()
    {
        //OGRE_THREAD_POINTER_DELETE(mScriptCompiler);
        destroy(mScriptCompiler);
        mScriptCompiler = null;
        
        destroy(mBuiltinTranslatorManager);
        mBuiltinTranslatorManager = null;
    }
    
    /// Sets the listener used for compiler instances
    void setListener(ScriptCompilerListener listener)
    {
        synchronized(mLock)
            mListener = listener;
    }
    
    /// Returns the currently set listener used for compiler instances
    ScriptCompilerListener getListener()
    {
        return mListener;
    }
    
    /// Adds the given translator manager to the list of managers
    void addTranslatorManager(ScriptTranslatorManager man)
    {
        synchronized(mLock)
            mManagers ~= man;
    }
    
    /// Removes the given translator manager from the list of managers
    void removeTranslatorManager(ScriptTranslatorManager man)
    {
        synchronized(mLock)
        {
            mManagers.removeFromArray(man);
        }
    }
    
    /// Clears all translator managers
    void clearTranslatorManagers()
    {
        mManagers.clear();
    }
    
    /// Retrieves a ScriptTranslator from the supported managers
    ScriptTranslator getTranslator(/*const*/ AbstractNodePtr node)
    {
        ScriptTranslator translator = null;
        synchronized(mLock)
        {
            // Start looking from the back
            foreach_reverse(i; mManagers)
            {
                translator = i.getTranslator(node);
                if(translator !is null)
                    break;
            }
        }
        return translator;
    }
    
    /// Adds a script extension that can be handled (e.g. *.material, *.pu, etc.)
    void addScriptPattern(string pattern)
    {
        mScriptPatterns ~= pattern;
    }
    
    /// @copydoc ScriptLoader::getScriptPatterns
    override ref string[] getScriptPatterns() //const
    {
        return mScriptPatterns;
    }
    
    /// @copydoc ScriptLoader::parseScript
    override void parseScript(DataStream stream, string groupName)
    {
        static if (OGRE_THREAD_SUPPORT)
        {
            // check we have an instance for this thread (should always have one for main thread)
            //if (!OGRE_THREAD_POINTER_GET(mScriptCompiler))
            if (mScriptCompiler is null)
            {
                // create a new instance for this thread - will get deleted when
                // the thread dies
                //OGRE_THREAD_POINTER_SET(mScriptCompiler, OGRE_NEW ScriptCompiler());
                mScriptCompiler = new ScriptCompiler;
            }
        }
        
        // Set the listener on the compiler before we continue
        synchronized(mLock)
        {
            //OGRE_THREAD_POINTER_GET(mScriptCompiler)->setListener(mListener);
            mScriptCompiler.setListener(mListener);
        }
        
        mScriptCompiler.compile(stream.getAsString(), stream.getName(), groupName);
    }
    
    /// @copydoc ScriptLoader::getLoadingOrder
    override Real getLoadingOrder() const
    {
        /// Load relatively early, before most script loaders run
        return 90.0;
    }
}

// Standard event types
class PreApplyTextureAliasesScriptCompilerEvent : ScriptCompilerEvent
{
public:
    Material mMaterial;
    AliasTextureNamePairList mAliases;
    static string eventType;
    
    this(Material material, AliasTextureNamePairList aliases)
    {
        super(eventType);
        mMaterial = material;
        mAliases = aliases;
    }
}

class ProcessResourceNameScriptCompilerEvent : ScriptCompilerEvent
{
public:
    alias uint ResourceType;
    enum : ResourceType
    {
        TEXTURE,
        MATERIAL,
        GPU_PROGRAM,
        COMPOSITOR
    }
    ResourceType mResourceType;
    string mName;
    static string eventType;
    
    this(ResourceType resourceType, string name)
    {
        super(eventType);
        mResourceType = resourceType;
        mName = name;
    }
}

class ProcessNameExclusionScriptCompilerEvent : ScriptCompilerEvent
{
public:
    string mClass;
    AbstractNode mParent;
    static string eventType;
    
    this(string cls, AbstractNode parent)
    {
        super(eventType);
        mClass = cls;
        mParent = parent;
    }
}

class CreateMaterialScriptCompilerEvent : ScriptCompilerEvent
{
public:
    string mFile, mName, mResourceGroup;
    static string eventType;
    
    this(string file, string name, string resourceGroup)
    {
        super(eventType);
        mFile = file;
        mName = name;
        mResourceGroup = resourceGroup;
    }
}

class CreateGpuProgramScriptCompilerEvent : ScriptCompilerEvent
{
public:
    string mFile, mName, mResourceGroup, mSource, mSyntax;
    GpuProgramType mProgramType;
    static string eventType;
    
    this(string file, string name, string resourceGroup, string source, 
         string syntax, GpuProgramType programType)
    {
        super(eventType);
        mFile = file;
        mName= name;
        mResourceGroup = resourceGroup;
        mSource = source;
        mSyntax = syntax;
        mProgramType = programType;
    }  
}

class CreateHighLevelGpuProgramScriptCompilerEvent : ScriptCompilerEvent
{
public:
    string mFile, mName, mResourceGroup, mSource, mLanguage;
    GpuProgramType mProgramType;
    static string eventType;
    
    this(string file, string name, string resourceGroup, string source, 
         string language, GpuProgramType programType)
    {
        super(eventType);
        mFile = file;
        mName = name;
        mResourceGroup = resourceGroup;
        mSource = source;
        mLanguage = language;
        mProgramType = programType;
    }
}

class CreateGpuSharedParametersScriptCompilerEvent : ScriptCompilerEvent
{
public:
    string mFile, mName, mResourceGroup;
    static string eventType;
    
    this(string file, string name, string resourceGroup)
    {
        super(eventType);
        mFile = file;
        mName = name;
        mResourceGroup = resourceGroup;
    }
}

class CreateParticleSystemScriptCompilerEvent : ScriptCompilerEvent
{
public:
    string mFile, mName, mResourceGroup;
    static string eventType;
    
    this(string file, string name, string resourceGroup)
    {
        super(eventType);
        mFile = file;
        mName = name;
        mResourceGroup = resourceGroup;
    }
}

class CreateCompositorScriptCompilerEvent : ScriptCompilerEvent
{
public:
    string mFile, mName, mResourceGroup;
    static string eventType;
    
    this(string file, string name, string resourceGroup)
    {
        super(eventType);
        mFile = file;
        mName = name;
        mResourceGroup = resourceGroup;
    }
}

static if(RTSHADER_SYSTEM_BUILD_CORE_SHADERS)
    enum _ID_RT_SHADER_SYSTEM = "ID_RT_SHADER_SYSTEM,";
else
    enum _ID_RT_SHADER_SYSTEM = "";
    
//With mixin, no need to copy/paste stuff, but IDE (probably) can't see these.
/// This enum defines the integer ids for keywords this compiler handles
mixin(`enum
{
    ID_MATERIAL = 3,
    ID_VERTEX_PROGRAM,
    ID_GEOMETRY_PROGRAM,
    ID_FRAGMENT_PROGRAM,
    ID_TECHNIQUE,
    ID_PASS,
    ID_TEXTURE_UNIT,
    ID_VERTEX_PROGRAM_REF,
    ID_GEOMETRY_PROGRAM_REF,
    ID_FRAGMENT_PROGRAM_REF,
    ID_SHADOW_CASTER_VERTEX_PROGRAM_REF,
    ID_SHADOW_CASTER_FRAGMENT_PROGRAM_REF,
    ID_SHADOW_RECEIVER_VERTEX_PROGRAM_REF,
    ID_SHADOW_RECEIVER_FRAGMENT_PROGRAM_REF,
    ID_SHADOW_CASTER_MATERIAL,
    ID_SHADOW_RECEIVER_MATERIAL,
    
    ID_LOD_VALUES,
    ID_LOD_STRATEGY,
    ID_LOD_DISTANCES,
    ID_RECEIVE_SHADOWS,
    ID_TRANSPARENCY_CASTS_SHADOWS,
    ID_SET_TEXTURE_ALIAS,
    
    ID_SOURCE,
    ID_SYNTAX,
    ID_DEFAULT_PARAMS,
    ID_PARAM_INDEXED,
    ID_PARAM_NAMED,
    ID_PARAM_INDEXED_AUTO,
    ID_PARAM_NAMED_AUTO,
    
    ID_SCHEME,
    ID_LOD_INDEX,
    ID_GPU_VENDOR_RULE,
    ID_GPU_DEVICE_RULE,
    ID_INCLUDE, 
    ID_EXCLUDE, 
    
    ID_AMBIENT,
    ID_DIFFUSE,
    ID_SPECULAR,
    ID_EMISSIVE,
    ID_VERTEXCOLOUR,
    ID_SCENE_BLEND,
    ID_COLOUR_BLEND,
    ID_ONE,
    ID_ZERO,
    ID_DEST_COLOUR,
    ID_SRC_COLOUR,
    ID_ONE_MINUS_DEST_COLOUR,
    ID_ONE_MINUS_SRC_COLOUR,
    ID_DEST_ALPHA,
    ID_SRC_ALPHA,
    ID_ONE_MINUS_DEST_ALPHA,
    ID_ONE_MINUS_SRC_ALPHA,
    ID_SEPARATE_SCENE_BLEND,
    ID_SCENE_BLEND_OP,
    ID_REVERSE_SUBTRACT,
    ID_MIN,
    ID_MAX,
    ID_SEPARATE_SCENE_BLEND_OP,
    ID_DEPTH_CHECK,
    ID_DEPTH_WRITE,
    ID_DEPTH_FUNC,
    ID_DEPTH_BIAS,
    ID_ITERATION_DEPTH_BIAS,
    ID_ALWAYS_FAIL,
    ID_ALWAYS_PASS,
    ID_LESS_EQUAL,
    ID_LESS,
    ID_EQUAL,
    ID_NOT_EQUAL,
    ID_GREATER_EQUAL,
    ID_GREATER,
    ID_ALPHA_REJECTION,
    ID_ALPHA_TO_COVERAGE,
    ID_LIGHT_SCISSOR,
    ID_LIGHT_CLIP_PLANES,
    ID_TRANSPARENT_SORTING,
    ID_ILLUMINATION_STAGE,
    ID_DECAL,
    ID_CULL_HARDWARE,
    ID_CLOCKWISE,
    ID_ANTICLOCKWISE,
    ID_CULL_SOFTWARE,
    ID_BACK,
    ID_FRONT,
    ID_NORMALISE_NORMALS,
    ID_LIGHTING,
    ID_SHADING,
    ID_FLAT, 
    ID_GOURAUD,
    ID_PHONG,
    ID_POLYGON_MODE,
    ID_SOLID,
    ID_WIREFRAME,
    ID_POINTS,
    ID_POLYGON_MODE_OVERRIDEABLE,
    ID_FOG_OVERRIDE,
    ID_NONE,
    ID_LINEAR,
    ID_EXP,
    ID_EXP2,
    ID_COLOUR_WRITE,
    ID_MAX_LIGHTS,
    ID_START_LIGHT,
    ID_ITERATION,
    ID_ONCE,
    ID_ONCE_PER_LIGHT,
    ID_PER_LIGHT,
    ID_PER_N_LIGHTS,
    ID_POINT,
    ID_SPOT,
    ID_DIRECTIONAL,
    ID_LIGHT_MASK,
    ID_POINT_SIZE,
    ID_POINT_SPRITES,
    ID_POINT_SIZE_ATTENUATION,
    ID_POINT_SIZE_MIN,
    ID_POINT_SIZE_MAX,
    
    ID_TEXTURE_ALIAS,
    ID_TEXTURE,
    ID_1D,
    ID_2D,
    ID_3D,
    ID_CUBIC,
    ID_2DARRAY,
    ID_UNLIMITED,
    ID_ALPHA,
    ID_GAMMA,
    ID_ANIM_TEXTURE,
    ID_CUBIC_TEXTURE,
    ID_SEPARATE_UV,
    ID_COMBINED_UVW,
    ID_TEX_COORD_SET,
    ID_TEX_ADDRESS_MODE,
    ID_WRAP,
    ID_CLAMP,
    ID_BORDER,
    ID_MIRROR,
    ID_TEX_BORDER_COLOUR,
    ID_FILTERING,
    ID_BILINEAR,
    ID_TRILINEAR,
    ID_ANISOTROPIC,
    ID_CMPTEST,
    ID_ON,
    ID_OFF,
    ID_CMPFUNC,
    ID_MAX_ANISOTROPY,
    ID_MIPMAP_BIAS,
    ID_COLOUR_OP,
    ID_REPLACE,
    ID_ADD,
    ID_MODULATE,
    ID_ALPHA_BLEND,
    ID_COLOUR_OP_EX,
    ID_SOURCE1,
    ID_SOURCE2,
    ID_MODULATE_X2,
    ID_MODULATE_X4,
    ID_ADD_SIGNED,
    ID_ADD_SMOOTH,
    ID_SUBTRACT,
    ID_BLEND_DIFFUSE_COLOUR,
    ID_BLEND_DIFFUSE_ALPHA,
    ID_BLEND_TEXTURE_ALPHA,
    ID_BLEND_CURRENT_ALPHA,
    ID_BLEND_MANUAL,
    ID_DOT_PRODUCT,
    ID_SRC_CURRENT,
    ID_SRC_TEXTURE,
    ID_SRC_DIFFUSE,
    ID_SRC_SPECULAR,
    ID_SRC_MANUAL,
    ID_COLOUR_OP_MULTIPASS_FALLBACK,
    ID_ALPHA_OP_EX,
    ID_ENV_MAP,
    ID_SPHERICAL,
    ID_PLANAR,
    ID_CUBIC_REFLECTION,
    ID_CUBIC_NORMAL,
    ID_SCROLL,
    ID_SCROLL_ANIM,
    ID_ROTATE,
    ID_ROTATE_ANIM,
    ID_SCALE,
    ID_WAVE_XFORM,
    ID_SCROLL_X,
    ID_SCROLL_Y,
    ID_SCALE_X,
    ID_SCALE_Y,
    ID_SINE,
    ID_TRIANGLE,
    ID_SQUARE,
    ID_SAWTOOTH,
    ID_INVERSE_SAWTOOTH,
    ID_TRANSFORM,
    ID_BINDING_TYPE,
    ID_VERTEX,
    ID_FRAGMENT,
    ID_CONTENT_TYPE,
    ID_NAMED,
    ID_SHADOW,
    ID_TEXTURE_SOURCE,
    ID_SHARED_PARAMS,
    ID_SHARED_PARAM_NAMED,
    ID_SHARED_PARAMS_REF,
    
    ID_PARTICLE_SYSTEM,
    ID_EMITTER,
    ID_AFFECTOR,
    
    ID_COMPOSITOR,
    ID_TARGET,
    ID_TARGET_OUTPUT,
    
    ID_INPUT,
    ID_PREVIOUS,
    ID_TARGET_WIDTH,
    ID_TARGET_HEIGHT,
    ID_TARGET_WIDTH_SCALED,
    ID_TARGET_HEIGHT_SCALED,
    ID_COMPOSITOR_LOGIC,
    ID_TEXTURE_REF,
    ID_SCOPE_LOCAL,
    ID_SCOPE_CHAIN,
    ID_SCOPE_GLOBAL,
    ID_POOLED,
    //ID_GAMMA, - already registered for material
    ID_NO_FSAA,
    ID_DEPTH_POOL,
    ID_ONLY_INITIAL,
    ID_VISIBILITY_MASK,
    ID_LOD_BIAS,
    ID_MATERIAL_SCHEME,
    ID_SHADOWS_ENABLED,
    
    ID_CLEAR,
    ID_STENCIL,
    ID_RENDER_SCENE,
    ID_RENDER_QUAD,
    ID_IDENTIFIER,
    ID_FIRST_RENDER_QUEUE,
    ID_LAST_RENDER_QUEUE,
    ID_QUAD_NORMALS,
    ID_CAMERA_FAR_CORNERS_VIEW_SPACE,
    ID_CAMERA_FAR_CORNERS_WORLD_SPACE,
    
    ID_BUFFERS,
    ID_COLOUR,
    ID_DEPTH,
    ID_COLOUR_VALUE,
    ID_DEPTH_VALUE,
    ID_STENCIL_VALUE,
    
    ID_CHECK,
    ID_COMP_FUNC,
    ID_REF_VALUE,
    ID_MASK,
    ID_FAIL_OP,
    ID_KEEP,
    ID_INCREMENT,
    ID_DECREMENT,
    ID_INCREMENT_WRAP,
    ID_DECREMENT_WRAP,
    ID_INVERT,
    ID_DEPTH_FAIL_OP,
    ID_PASS_OP,
    ID_TWO_SIDED,
    `
    ~ _ID_RT_SHADER_SYSTEM ~
    
    `/// Suport for shader model 5.0
    // More program IDs
    ID_TESSELATION_HULL_PROGRAM,
    ID_TESSELATION_DOMAIN_PROGRAM,
    ID_COMPUTE_PROGRAM,
    ID_TESSELATION_HULL_PROGRAM_REF,
    ID_TESSELATION_DOMAIN_PROGRAM_REF,
    ID_COMPUTE_PROGRAM_REF,
    // More binding IDs
    ID_GEOMETRY,
    ID_TESSELATION_HULL,
    ID_TESSELATION_DOMAIN,
    ID_COMPUTE,
    
    // Support for subroutine
    ID_SUBROUTINE,
    
    ID_END_BUILTIN_IDS
}`);
/** @} */
/** @} */