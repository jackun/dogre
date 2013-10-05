module ogregl.glsl.program;
import std.algorithm: min;
import std.string: indexOf;

import derelict.opengl3.gl;

import ogre.resources.highlevelgpuprogram;
import ogre.general.generals;
import ogre.strings;
import ogre.resources.resourcemanager;
import ogre.rendersystem.renderoperation;
import ogre.materials.gpuprogram;
import ogre.compat;
import ogre.resources.resource;
import ogregl.glsl.preprocessor;
import ogregl.glsl.extsupport;
import ogre.exception;
import ogregl.glsl.gpuprogram;
import ogregl.glsl.linkprogrammanager;

//FIXME NOTE: Modernized a bit, using GL 2.0 calls. If <2.0 is needed, add functions to Derelict3 and comment/uncomment lines.

RenderOperation.OperationType parseOperationType(string val)
{
    if (val == "point_list")
    {
        return RenderOperation.OperationType.OT_POINT_LIST;
    }
    else if (val == "line_list")
    {
        return RenderOperation.OperationType.OT_LINE_LIST;
    }
    else if (val == "line_strip")
    {
        return RenderOperation.OperationType.OT_LINE_STRIP;
    }
    else if (val == "triangle_strip")
    {
        return RenderOperation.OperationType.OT_TRIANGLE_STRIP;
    }
    else if (val == "triangle_fan")
    {
        return RenderOperation.OperationType.OT_TRIANGLE_FAN;
    }
    else 
    {
        //Triangle list is the default fallback. Keep it this way?
        return RenderOperation.OperationType.OT_TRIANGLE_LIST;
    }
}

string operationTypeToString(RenderOperation.OperationType val)
{
    switch (val)
    {
        case RenderOperation.OperationType.OT_POINT_LIST:
            return "point_list";
            break;
        case RenderOperation.OperationType.OT_LINE_LIST:
            return "line_list";
            break;
        case RenderOperation.OperationType.OT_LINE_STRIP:
            return "line_strip";
            break;
        case RenderOperation.OperationType.OT_TRIANGLE_STRIP:
            return "triangle_strip";
            break;
        case RenderOperation.OperationType.OT_TRIANGLE_FAN:
            return "triangle_fan";
            break;
        case RenderOperation.OperationType.OT_TRIANGLE_LIST:
        default:
            return "triangle_list";
            break;
    }
}
/** Specialisation of HighLevelGpuProgram to provide support for OpenGL 
 Shader Language (GLSL).
 @remarks
 GLSL has no target assembler or entry point specification like DirectX 9 HLSL.
 Vertex and Fragment shaders only have one entry point called "main".  
 When a shader is compiled, microcode is generated but can not be accessed by
 the application.
 GLSL also does not provide assembler low level output after compiling.  The GL Render
 system assumes that the Gpu program is a GL Gpu program so GLSLProgram will create a 
 GLSLGpuProgram that is subclassed from GLGpuProgram for the low level implementation.
 The GLSLProgram class will create a shader object and compile the source but will
 not create a program object.  It's up to GLSLGpuProgram class to request a program object
 to link the shader object to.

 @note
 GLSL supports multiple modular shader objects that can be attached to one program
 object to form a single shader.  This is supported through the "attach" material script
 command.  All the modules to be attached are listed on the same line as the attach command
 separated by white space.
 
 */
class GLSLProgram : HighLevelGpuProgram
{
public:
    /// Command object for attaching another GLSL Program 
    static class CmdAttach : ParamCommand
    {
    public:
        string doGet(Object target) const
        {
            return (cast(GLSLProgram)(target)).getAttachedShaderNames();
        }
        void doSet(Object target, string shaderNames)
        {
            //get all the shader program names: there could be more than one
            string[] vecShaderNames = StringUtil.split(shaderNames, " \t", 0);
            
            //size_t programNameCount = vecShaderNames.length;
            foreach (i; vecShaderNames)
            {
                (cast(GLSLProgram)(target)).attachChildShader(i);
            }
        }
    }
    //FIXME std.conv parses?
    /// Command object for setting matrix packing in column-major order
    static class CmdColumnMajorMatrices : ParamCommand
    {
    public:
        string doGet(Object target) const
        {
            return std.conv.to!string((cast(GLSLProgram)(target)).getColumnMajorMatrices());
        }
        void doSet(Object target, string val)
        {
            (cast(GLSLProgram)(target)).setColumnMajorMatrices(std.conv.to!bool(val));
        }
    }
    
    this(ResourceManager creator, 
         string name, ResourceHandle handle,
         string group, bool isManual, ManualResourceLoader loader)
    {
        super(creator, name, handle, group, isManual, loader);
        mGLHandle = 0;
        mCompiled = 0;
        mInputOperationType = RenderOperation.OperationType.OT_TRIANGLE_LIST;
        mOutputOperationType = RenderOperation.OperationType.OT_TRIANGLE_LIST;
        mMaxOutputVertices = 3;
        mColumnMajorMatrices = true;

        
        // add parameter command "attach" to the material serializer dictionary
        if (createParamDictionary("GLSLProgram"))
        {
            setupBaseParamDictionary();
            ParamDictionary dict = getParamDictionary();
            
            dict.addParameter(new ParameterDef("preprocessor_defines", 
                                               "Preprocessor defines use to compile the program.",
                                               ParameterType.PT_STRING),msCmdPreprocessorDefines);
            dict.addParameter(new ParameterDef("attach", 
                                               "name of another GLSL program needed by this program",
                                               ParameterType.PT_STRING),msCmdAttach);
            dict.addParameter(new ParameterDef("column_major_matrices", 
                                               "Whether matrix packing in column-major order.",
                                               ParameterType.PT_BOOL),msCmdColumnMajorMatrices);
            dict.addParameter(
                new ParameterDef("input_operation_type",
                             "The input operation type for this geometry program."
                             "Can be 'point_list', 'line_list', 'line_strip', 'triangle_list',"
                             "'triangle_strip' or 'triangle_fan'", ParameterType.PT_STRING),
                msInputOperationTypeCmd);
            dict.addParameter(
                new ParameterDef("output_operation_type",
                             "The input operation type for this geometry program."
                             "Can be 'point_list', 'line_strip' or 'triangle_strip'",
                             ParameterType.PT_STRING),
                msOutputOperationTypeCmd);
            dict.addParameter(
                new ParameterDef("max_output_vertices", 
                             "The maximum number of vertices a single "
                             "run of this geometry program can output",
                             ParameterType.PT_INT),msMaxOutputVerticesCmd);
        }
        // Manually assign language now since we use it immediately
        mSyntaxCode = "glsl";
        
    }

    ~this()
    {
        // Have to call this here rather than in Resource destructor
        // since calling methods in base destructors causes crash
        if (isLoaded())
        {
            unload();
        }
        else
        {
            unloadHighLevel();
        }
    }
    
    GLuint getGLHandle() const { return mGLHandle; }

    void attachToProgramObject( const(GLuint) programObject )
    {
        // attach child objects
        //GLSLProgramContainerIterator childprogramcurrent = mAttachedGLSLPrograms.begin();
        //GLSLProgramContainerIterator childprogramend = mAttachedGLSLPrograms.end();
        
        //while (childprogramcurrent != childprogramend)
        foreach(childShader; mAttachedGLSLPrograms)
        {
            //GLSLProgram* childShader = *childprogramcurrent;
            // TODO bug in ATI GLSL linker : modules without main function must be recompiled each time 
            // they are linked to a different program object
            // don't check for compile errors since there won't be any
            // *** minor inconvenience until ATI fixes their driver
            childShader.compile(false);
            
            childShader.attachToProgramObject( programObject );
            
            //++childprogramcurrent;
        }

        //glAttachObjectARB( programObject, mGLHandle );//GL1.5
        glAttachShader( programObject, mGLHandle );//GL2.0
        GLenum glErr = glGetError();
        if(glErr != GL_NO_ERROR)
        {
            reportGLSLError( glErr, "GLSLProgram.attachToProgramObject",
                            "Error attaching " ~ mName ~ " shader object to GLSL Program Object", programObject );
        }
        
    }
    void detachFromProgramObject( const (GLuint) programObject )
    {
        //glDetachObjectARB(programObject, mGLHandle);
        glDetachShader(programObject, mGLHandle);
        
        GLenum glErr = glGetError();
        if(glErr != GL_NO_ERROR)
        {
            reportGLSLError( glErr, "GLSLProgram.detachFromProgramObject",
                            "Error detaching " ~ mName ~ " shader object from GLSL Program Object", programObject );
        }

        // attach child objects
        foreach(childShader; mAttachedGLSLPrograms)
        {
            childShader.detachFromProgramObject( programObject );
        }
        
    }

    string getAttachedShaderNames() const { return mAttachedShaderNames; }
    
    /// Overridden
    override bool getPassTransformStates() const
    {
        // scenemanager should pass on transform state to the rendersystem
        return true;
    }

    override bool getPassSurfaceAndLightStates() const
    {
        // scenemanager should pass on light & material state to the rendersystem
        return true;
    }
    
    /** Attach another GLSL Shader to this one. */
    void attachChildShader(string name)
    {
        // is the name valid and already loaded?
        // check with the high level program manager to see if it was loaded
        SharedPtr!HighLevelGpuProgram hlProgram = cast(SharedPtr!HighLevelGpuProgram)HighLevelGpuProgramManager.getSingleton().getByName(name);
        if (!hlProgram.isNull())
        {
            if (hlProgram.getAs().getSyntaxCode() == "glsl")
            {
                // make sure attached program source gets loaded and compiled
                // don't need a low level implementation for attached shader objects
                // loadHighLevelImpl will only load the source and compile once
                // so don't worry about calling it several times
                GLSLProgram childShader = cast(GLSLProgram)hlProgram.get();
                // load the source and attach the child shader only if supported
                if (isSupported())
                {
                    childShader.loadHighLevelImpl();
                    // add to the container
                    mAttachedGLSLPrograms.insert( childShader );
                    mAttachedShaderNames ~= name ~ " ";
                }
            }
        }
    }
    
    /** Sets the preprocessor defines use to compile the program. */
    void setPreprocessorDefines(string defines) { mPreprocessorDefines = defines; }
    /** Sets the preprocessor defines use to compile the program. */
    string getPreprocessorDefines() const { return mPreprocessorDefines; }
    
    /// Overridden from GpuProgram
    override string getLanguage() const
    {
        enum string language = "glsl";
        return language;
    }
    
    /** Sets whether matrix packing in column-major order. */ 
    void setColumnMajorMatrices(bool columnMajor) { mColumnMajorMatrices = columnMajor; }
    /** Gets whether matrix packed in column-major order. */
    bool getColumnMajorMatrices() const { return mColumnMajorMatrices; }
    
    /** Returns the operation type that this geometry program expects to
     receive as input
     */
    RenderOperation.OperationType getInputOperationType() const 
    { return mInputOperationType; }
    /** Returns the operation type that this geometry program will emit
     */
    RenderOperation.OperationType getOutputOperationType() const 
    { return mOutputOperationType; }
    /** Returns the maximum number of vertices that this geometry program can
     output in a single run
     */
    int getMaxOutputVertices() const { return mMaxOutputVertices; }
    
    /** Sets the operation type that this geometry program expects to receive
     */
    void setInputOperationType(RenderOperation.OperationType operationType) 
    { mInputOperationType = operationType; }
    /** Set the operation type that this geometry program will emit
     */
    void setOutputOperationType(RenderOperation.OperationType operationType) 
    { mOutputOperationType = operationType; }
    /** Set the maximum number of vertices that a single run of this geometry program
     can emit.
     */
    void setMaxOutputVertices(int maxOutputVertices) 
    { mMaxOutputVertices = maxOutputVertices; }
    
    /// compile source into shader object
    bool compile( const(bool) checkErrors = true)
    {
        if (mCompiled == 1)
        {
            return true;
        }
        
        // only create a shader object if glsl is supported
        if (isSupported())
        {
            // create shader object
            GLenum shaderType = 0x0000;
            switch (mType)
            {
                case GpuProgramType.GPT_VERTEX_PROGRAM:
                    shaderType = GL_VERTEX_SHADER;
                    break;
                case GpuProgramType.GPT_FRAGMENT_PROGRAM:
                    shaderType = GL_FRAGMENT_SHADER;
                    break;
                case GpuProgramType.GPT_GEOMETRY_PROGRAM:
                    shaderType = GL_GEOMETRY_SHADER;
                    break;
                default:
                    break;//TODO blow up?
            }
            //mGLHandle = glCreateShaderObjectARB(shaderType);
            mGLHandle = glCreateShader(shaderType);
        }
        
        // Add preprocessor extras and main source
        if (mSource.length)
        {
            auto source = CSTR(mSource);
            //glShaderSourceARB(mGLHandle, 1, &source, NULL);
            glShaderSource(mGLHandle, 1, &source, null);//GL2.0, null => expects null-terminated strings
        }
        
        if (checkErrors)
        {
            logObjectInfo("GLSL compiling: " ~ mName, mGLHandle);
        }
        
        glCompileShader(mGLHandle);
        // check for compile errors
        //glGetObjectParameterivARB(mGLHandle, GL_OBJECT_COMPILE_STATUS_ARB, &mCompiled);
        glGetShaderiv(mGLHandle, GL_COMPILE_STATUS, &mCompiled);//GL2.0
        if(checkErrors)
        {
            logObjectInfo(mCompiled ? "GLSL compiled: " : "GLSL compile log: "  ~ mName, mGLHandle);
        }
        
        return (mCompiled == 1);
    }
    
    /// Command object for setting macro defines
    static class CmdPreprocessorDefines : ParamCommand
    {
    public:
        string doGet(Object target) const
        {
            return (cast(GLSLProgram)target).getPreprocessorDefines();
        }
        void doSet(Object target, string val)
        {
            (cast(GLSLProgram)target).setPreprocessorDefines(val);
        }
    }

    /// Command object for setting the input operation type (geometry shader only)
    static class CmdInputOperationType : ParamCommand
    {
    public:
        string doGet(Object target) const
        {
            GLSLProgram t = (cast(GLSLProgram)target);
            return operationTypeToString(t.getInputOperationType());
        }
        void doSet(Object target, string val)
        {
            (cast(GLSLProgram)target).setInputOperationType(parseOperationType(val));
        }
    }
    /// Command object for setting the output operation type (geometry shader only)
    static class CmdOutputOperationType : ParamCommand
    {
    public:
        string doGet(Object target) const
        {
            GLSLProgram t = (cast(GLSLProgram)target);
            return operationTypeToString(t.getOutputOperationType());
        }
        void doSet(Object target, string val)
        {
            GLSLProgram t = (cast(GLSLProgram)target);
            t.setOutputOperationType(parseOperationType(val));
        }
    }
    /// Command object for setting the maximum output vertices (geometry shader only)
    static class CmdMaxOutputVertices : ParamCommand
    {
    public:
        string doGet(Object target) const
        {
            GLSLProgram t = (cast(GLSLProgram)target);
            return std.conv.to!string(t.getMaxOutputVertices());
        }
        void doSet(Object target, string val)
        {
            GLSLProgram t = (cast(GLSLProgram)target);
            t.setMaxOutputVertices(std.conv.to!int(val));
        }
    }
protected:
    static CmdPreprocessorDefines msCmdPreprocessorDefines;
    static CmdAttach msCmdAttach;
    static CmdColumnMajorMatrices msCmdColumnMajorMatrices;
    static CmdInputOperationType msInputOperationTypeCmd;
    static CmdOutputOperationType msOutputOperationTypeCmd;
    static CmdMaxOutputVertices msMaxOutputVerticesCmd;
    
    static this()
    {
        msCmdPreprocessorDefines = new CmdPreprocessorDefines;
        msCmdAttach = new CmdAttach;
        msCmdColumnMajorMatrices = new CmdColumnMajorMatrices;
        msInputOperationTypeCmd = new CmdInputOperationType;
        msOutputOperationTypeCmd = new CmdOutputOperationType;
        msMaxOutputVerticesCmd = new CmdMaxOutputVertices;
    }
    
    /** Internal load implementation, must be implemented by subclasses.
     */
    override void loadFromSource()
    {
        // Preprocess the GLSL shader in order to get a clean source
        CPreprocessor cpp = new CPreprocessor;
        
        // Pass all user-defined macros to preprocessor
        if (mPreprocessorDefines.length)
        {
            ptrdiff_t pos = 0;
            while (pos != -1)
            {
                // Find delims
                //ptrdiff_t endPos = mPreprocessorDefines.find_first_of(";,=", pos);
                ptrdiff_t endPos = -1;
                /*foreach(delim; ";,=")
                {
                    endPos = min(endPos, mPreprocessorDefines[pos..$].indexOf(delim));
                }*/
                endPos = mPreprocessorDefines[pos..$].find_first_of(";,=");

                if (endPos != -1)
                {
                    endPos += pos; //Make offset start from the beginning of the string
                    ptrdiff_t macro_name_start = pos;
                    size_t macro_name_len = endPos - pos;
                    pos = endPos;
                    
                    // Check definition part
                    if (mPreprocessorDefines[pos] == '=')
                    {
                        // set up a definition, skip delim
                        ++pos;
                        ptrdiff_t macro_val_start = pos;
                        size_t macro_val_len;
                        
                        //endPos = mPreprocessorDefines.find_first_of(";,", pos);
                        /*foreach(delim; ";,")
                        {
                            endPos = min(endPos, mPreprocessorDefines[pos..$].indexOf(delim));
                        }*/
                        endPos = mPreprocessorDefines[pos..$].find_first_of(";,=");
                        
                        if (endPos == -1)
                        {
                            macro_val_len = mPreprocessorDefines.length - pos;
                            pos = endPos;
                        }
                        else
                        {
                            macro_val_len = endPos;// - pos;
                            pos = endPos+1 + pos;//+ pos to make offset start from the beginning of the string
                        }
                        cpp.Define (
                            mPreprocessorDefines[macro_name_start.. macro_name_start+macro_name_len].dup, macro_name_len,
                            mPreprocessorDefines[macro_val_start.. macro_val_start+macro_val_len].dup, macro_val_len);
                    }
                    else
                    {
                        // No definition part, define as "1"
                        ++pos;
                        cpp.Define (
                            mPreprocessorDefines[macro_name_start.. macro_name_start+macro_name_len].dup, macro_name_len, 1);
                    }
                }
                else
                    pos = endPos;
            }
        }
        
        //size_t out_size = 0;
        //auto src = CSTR(mSource);
        //size_t src_len = mSource.length;
        string srcout = cpp.Parse (mSource);//, src_len, out_size);
        if (srcout is null || !srcout.length)
            // Failed to preprocess, break out
            throw new RenderingApiError(
                        "Failed to preprocess shader " ~ mName,
                        "GLSLProgram.loadFromSource");
                         //__FUNCTION__); //2.063
        
        mSource = srcout;//String (out, out_size);
        //if (out < src || out > src + src_len)
        //    free (out);
    }

    /** Internal method for creating a dummy low-level program for this
     high-level program. GLSL does not give access to the low level implementation of the
     shader so this method creates an object sub-classed from GLGpuProgram just to be
     compatible with GLRenderSystem.
     */
    override void createLowLevelImpl()
    {
        mAssemblerProgram = SharedPtr!GpuProgram(new GLSLGpuProgram( this ));
        // Shader params need to be forwarded to low level implementation
        mAssemblerProgram.getAs().setAdjacencyInfoRequired(isAdjacencyInfoRequired());
    }

    /// Internal unload implementation, must be implemented by subclasses
    override void unloadHighLevelImpl()
    {
        if (isSupported())
        {
            //glDeleteObjectARB(mGLHandle);
            glDeleteShader(mGLHandle);
            mCompiled = 0;
            mGLHandle = 0;
        }
    }

    /// Overridden from HighLevelGpuProgram
    override void unloadImpl()
    {   
        // We didn't create mAssemblerProgram through a manager, so override this
        // implementation so that we don't try to remove it from one. Since getCreator()
        // is used, it might target a different matching handle!
        mAssemblerProgram.setNull();
        
        unloadHighLevel();
    }
    
    /// Populate the passed parameters with name.index map
    override void populateParameterNames(SharedPtr!GpuProgramParameters params)
    {
        getConstantDefinitions();
        params.get()._setNamedConstants(mConstantDefs);
        // Don't set logical / physical maps here, as we can't access parameters by logical index in GLHL.
    }

    /// Populate the passed parameters with name.index map, must be overridden
    override void buildConstantDefinitions() //const
    {
        // We need an accurate list of all the uniforms in the shader, but we
        // can't get at them until we link all the shaders into a program object.
        
        
        // Therefore instead, parse the source code manually and extract the uniforms
        createParameterMappingStructures(true);
        GLSLLinkProgramManager.getSingleton().extractConstantDefs(
            mSource, mConstantDefs.get(), mName);
        
        // Also parse any attached sources
        foreach (childShader; mAttachedGLSLPrograms)
        {            
            GLSLLinkProgramManager.getSingleton().extractConstantDefs(
                childShader.getSource(), mConstantDefs.get(), childShader.getName());
        }
    }
    
private:
    /// GL handle for shader object
    GLuint mGLHandle;
    /// Flag indicating if shader object successfully compiled
    GLint mCompiled;
    /// The input operation type for this (geometry) program
    RenderOperation.OperationType mInputOperationType;
    /// The output operation type for this (geometry) program
    RenderOperation.OperationType mOutputOperationType;
    /// The maximum amount of vertices that this (geometry) program can output
    int mMaxOutputVertices;
    /// attached Shader names
    string mAttachedShaderNames;
    /// Preprocessor options
    string mPreprocessorDefines;
    /// container of attached programs
    //typedef vector< GLSLProgram* >::type GLSLProgramContainer;
    alias GLSLProgram[] GLSLProgramContainer;
    //typedef GLSLProgramContainer::iterator GLSLProgramContainerIterator;
    GLSLProgram[] mAttachedGLSLPrograms; //aka GLSLProgramContainer
    /// matrix in column major pack format?
    bool mColumnMajorMatrices;
}