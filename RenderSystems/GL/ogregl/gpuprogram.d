module ogregl.gpuprogram;

import derelict.opengl3.gl;

import ogre.materials.gpuprogram;
import ogre.resources.resourcemanager;
import ogre.rendersystem.vertex;
import ogre.resources.resource;
import ogre.general.log;
import ogre.exception;
import ogre.compat;

/** Generalised low-level GL program, can be applied to multiple types (eg ARB and NV) */
package class GLGpuProgram : GpuProgram
{
private:
    GLenum getGLShaderType(GpuProgramType programType)
    {
        switch (programType)
        {
            case GpuProgramType.GPT_VERTEX_PROGRAM:
            default:
                return GL_VERTEX_PROGRAM_ARB;
            case GpuProgramType.GPT_GEOMETRY_PROGRAM:
                return GL_GEOMETRY_PROGRAM_NV; //FIXME NV stuff
            case GpuProgramType.GPT_FRAGMENT_PROGRAM:
                return GL_FRAGMENT_PROGRAM;
        }
    }
public:
    this(ResourceManager creator, string name, ResourceHandle handle,
         string group, bool isManual = false, ManualResourceLoader loader = null)
    {
        super(creator, name, handle, group, isManual, loader);
        if (createParamDictionary("GLGpuProgram"))
        {
            setupBaseParamDictionary();
        }
    }

    ~this()
    {
        // have to call this here reather than in Resource destructor
        // since calling methods in base destructors causes crash
        unload(); 
    }
    
    /// Execute the binding functions for this program
    void bindProgram() {}
    /// Execute the binding functions for this program
    void unbindProgram() {}
    
    /// Execute the param binding functions for this program
    void bindProgramParameters(SharedPtr!GpuProgramParameters params, ushort mask) {}
    /// Bind just the pass iteration parameters
    void bindProgramPassIterationParameters(SharedPtr!GpuProgramParameters params) {}
    
    
    /// Get the assigned GL program id
    GLuint getProgramID() const
    { return mProgramID; }
    
    /** Get the attribute index for a given semantic. 
        @remarks
            This can be used to identify the attribute index to bind non-builtin
            attributes like tangent and binormal.
        */
    GLuint getAttributeIndex(VertexElementSemantic semantic, uint index)
    {
        return getFixedAttributeIndex(semantic, index);
    }

    /** Test whether attribute index for a given semantic is valid. 
        */
    bool isAttributeValid(VertexElementSemantic semantic, uint index)
    {
        // default implementation
        final switch(semantic)
        {
            case VertexElementSemantic.VES_POSITION:
            case VertexElementSemantic.VES_NORMAL:
            case VertexElementSemantic.VES_DIFFUSE:
            case VertexElementSemantic.VES_SPECULAR:
            case VertexElementSemantic.VES_TEXTURE_COORDINATES:
                return false;
            case VertexElementSemantic.VES_BLEND_WEIGHTS:
            case VertexElementSemantic.VES_BLEND_INDICES:
            case VertexElementSemantic.VES_BINORMAL:
            case VertexElementSemantic.VES_TANGENT:
                return true; // with default binding
        }
        
        return false;
    }
    
    /** Get the fixed attribute bindings normally used by GL for a semantic. */
    static GLuint getFixedAttributeIndex(VertexElementSemantic semantic, uint index)
    {
        // Some drivers (e.g. OS X on nvidia) incorrectly determine the attribute binding automatically
        // and end up aliasing existing built-ins. So avoid! Fixed builtins are: 
        
        //  a  builtin              custom attrib name
        // ----------------------------------------------
        //  0  gl_Vertex            vertex
        //  1  n/a                  blendWeights        
        //  2  gl_Normal            normal
        //  3  gl_Color             colour
        //  4  gl_SecondaryColor    secondary_colour
        //  5  gl_FogCoord          fog_coord
        //  7  n/a                  blendIndices
        //  8  gl_MultiTexCoord0    uv0
        //  9  gl_MultiTexCoord1    uv1
        //  10 gl_MultiTexCoord2    uv2
        //  11 gl_MultiTexCoord3    uv3
        //  12 gl_MultiTexCoord4    uv4
        //  13 gl_MultiTexCoord5    uv5
        //  14 gl_MultiTexCoord6    uv6, tangent
        //  15 gl_MultiTexCoord7    uv7, binormal
        switch(semantic)
        {
            case VertexElementSemantic.VES_POSITION:
                return 0;
            case VertexElementSemantic.VES_BLEND_WEIGHTS:
                return 1;
            case VertexElementSemantic.VES_NORMAL:
                return 2;
            case VertexElementSemantic.VES_DIFFUSE:
                return 3;
            case VertexElementSemantic.VES_SPECULAR:
                return 4;
            case VertexElementSemantic.VES_BLEND_INDICES:
                return 7;
            case VertexElementSemantic.VES_TEXTURE_COORDINATES:
                return 8 + index;
            case VertexElementSemantic.VES_TANGENT:
                return 14;
            case VertexElementSemantic.VES_BINORMAL:
                return 15;
            default:
                assert(false, "Missing attribute!");
                return 0;
        }
        
    }
    
protected:
    /** Overridden from GpuProgram, do nothing */
    override void loadFromSource() {}
    /// @copydoc Resource::unloadImpl
    override void unloadImpl() {}
    
    GLuint mProgramID;
    GLenum mProgramType;
}

/** Specialisation of the GL low-level program for ARB programs. */
package class GLArbGpuProgram : GLGpuProgram
{
public:
    this(ResourceManager creator, string name, ResourceHandle handle,
        string group, bool isManual = false, ManualResourceLoader loader = null)
    {
        super(creator, name, handle, group, isManual, loader);
        glGenProgramsARB(1, &mProgramID);//FIXME
    }

    ~this()
    {
        // have to call this here reather than in Resource destructor
        // since calling virtual methods in base destructors causes crash
        unload(); 
    }
    
    /// @copydoc GpuProgram::setType
    override void setType(GpuProgramType t)
    {
        GLGpuProgram.setType(t);
        mProgramType = getGLShaderType(t);
    }
    
    /// Execute the binding functions for this program
    override void bindProgram()
    {
        glEnable(mProgramType);
        glBindProgramARB(mProgramType, mProgramID);
    }

    /// Execute the unbinding functions for this program
    override void unbindProgram()
    {
        glBindProgramARB(mProgramType, 0);
        glDisable(mProgramType);
    }

    /// Execute the param binding functions for this program
    override void bindProgramParameters(SharedPtr!GpuProgramParameters _params, ushort mask)
    {
        GLenum type = getGLShaderType(mType);
        
        auto params = _params.get();
        // only supports float constants
        SharedPtr!GpuLogicalBufferStruct floatStruct = params.getFloatLogicalBufferStruct();
        
        
        foreach (k,v; floatStruct.get().map)
        {
            if (v.variability & mask)
            {
                size_t logicalIndex = k;
                float* pFloat = params.getFloatPointer(v.physicalIndex);
                // Iterate over the params, set in 4-float chunks (low-level)
                for (size_t j = 0; j < v.currentSize; j+=4)
                {
                    glProgramLocalParameter4fvARB(type, cast(GLuint)logicalIndex, pFloat);
                    pFloat += 4;
                    ++logicalIndex;
                }
            }
        }
    }

    /// Bind just the pass iteration parameters
    override void bindProgramPassIterationParameters(SharedPtr!GpuProgramParameters _params)
    {
        auto params = _params.get();
        if (params.hasPassIterationNumber())
        {
            GLenum type = getGLShaderType(mType);
            
            size_t physicalIndex = params.getPassIterationNumberIndex();
            size_t logicalIndex = params.getFloatLogicalIndexForPhysicalIndex(physicalIndex);
            const float* pFloat = params.getFloatPointer(physicalIndex);
            glProgramLocalParameter4fvARB(type, cast(GLuint)logicalIndex, pFloat);
        }
    }

    
    /// Get the GL type for the program
    GLuint getProgramType() const
    { return mProgramType; }
    
protected:
    override void loadFromSource()
    {
        if (GL_INVALID_OPERATION == glGetError()) {
            LogManager.getSingleton().logMessage("Invalid Operation before loading program "~mName);
        }
        glBindProgramARB(mProgramType, mProgramID);
        glProgramStringARB(mProgramType, GL_PROGRAM_FORMAT_ASCII_ARB, cast(GLsizei)mSource.length, CSTR(mSource));
        
        if (GL_INVALID_OPERATION == glGetError())
        {
            GLint errPos;
            glGetIntegerv(GL_PROGRAM_ERROR_POSITION_ARB, &errPos);
            string errPosStr = std.conv.to!string(errPos);
            string errStr = std.conv.to!string(glGetString(GL_PROGRAM_ERROR_STRING_ARB));
            // XXX New exception code?
            throw new InternalError(
                        "Cannot load GL vertex program " ~ mName ~
                        ".  Line " ~ errPosStr ~ ":\n" ~ errStr, mName);
        }
        glBindProgramARB(mProgramType, 0);
    }

    /// @copydoc Resource::unloadImpl
    override void unloadImpl()
    {
        glDeleteProgramsARB(1, &mProgramID);
    }
    
}