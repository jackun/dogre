module ogregl.glsl.linkprogram;
import std.algorithm: find;
import std.string: indexOf;

import derelict.opengl3.gl;

import ogre.materials.gpuprogram;
import ogre.compat;
import ogre.strings;
import ogre.rendersystem.renderoperation;
import ogre.rendersystem.vertex;
import ogregl.gpuprogram;
import ogregl.glsl.gpuprogram;
import ogregl.glsl.linkprogrammanager;
import ogregl.glsl.extsupport;
import ogregl.glew;
import ogre.exception;
import ogregl.config;

//Note: tried to modernize little-bit from c++ version

GLint getGLGeometryInputPrimitiveType(RenderOperation.OperationType operationType, bool requiresAdjacency)
{
    switch (operationType)
    {
        case RenderOperation.OperationType.OT_POINT_LIST:
            return GL_POINTS;
        case RenderOperation.OperationType.OT_LINE_LIST:
        case RenderOperation.OperationType.OT_LINE_STRIP:
            return requiresAdjacency ? GL_LINES_ADJACENCY : GL_LINES;
        default:
        case RenderOperation.OperationType.OT_TRIANGLE_LIST:
        case RenderOperation.OperationType.OT_TRIANGLE_STRIP:
        case RenderOperation.OperationType.OT_TRIANGLE_FAN:
            return requiresAdjacency ? GL_TRIANGLES_ADJACENCY : GL_TRIANGLES;
    }
}

GLint getGLGeometryOutputPrimitiveType(RenderOperation.OperationType operationType)
{
    switch (operationType)
    {
        case RenderOperation.OperationType.OT_POINT_LIST:
            return GL_POINTS;
        case RenderOperation.OperationType.OT_LINE_STRIP:
            return GL_LINE_STRIP;
        case RenderOperation.OperationType.OT_TRIANGLE_STRIP:
            return GL_TRIANGLE_STRIP;
        default:
            throw new RenderingApiError(
                        "Geometry shader output operation type can only be point list,"
                        "line strip or triangle strip",
                        "GLSLLinkProgram.getGLGeometryOutputPrimitiveType");
    }
}

/// Structure used to keep track of named uniforms in the linked program object
struct GLUniformReference
{
    /// GL location handle
    GLint  mLocation;
    /// Which type of program params will this value come from?
    GpuProgramType mSourceProgType;
    /// The constant definition it relates to
    //immutable //?
    GpuConstantDefinition* mConstantDef;
}

//typedef vector<GLUniformReference>::type GLUniformReferenceList;
//typedef GLUniformReferenceList::iterator GLUniformReferenceIterator;
//alias GLUniformReference[] GLUniformReferenceList;

/** C++ encapsulation of GLSL Program Object

    */

class GLSLLinkProgram
{

static this()
{
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
        msCustomAttributes = [
            CustomAttribute("vertex", GLGpuProgram.getFixedAttributeIndex(VertexElementSemantic.VES_POSITION, 0)),
            CustomAttribute("blendWeights", GLGpuProgram.getFixedAttributeIndex(VertexElementSemantic.VES_BLEND_WEIGHTS, 0)),
            CustomAttribute("normal", GLGpuProgram.getFixedAttributeIndex(VertexElementSemantic.VES_NORMAL, 0)),
            CustomAttribute("colour", GLGpuProgram.getFixedAttributeIndex(VertexElementSemantic.VES_DIFFUSE, 0)),
            CustomAttribute("secondary_colour", GLGpuProgram.getFixedAttributeIndex(VertexElementSemantic.VES_SPECULAR, 0)),
            CustomAttribute("blendIndices", GLGpuProgram.getFixedAttributeIndex(VertexElementSemantic.VES_BLEND_INDICES, 0)),
            CustomAttribute("uv0", GLGpuProgram.getFixedAttributeIndex(VertexElementSemantic.VES_TEXTURE_COORDINATES, 0)),
            CustomAttribute("uv1", GLGpuProgram.getFixedAttributeIndex(VertexElementSemantic.VES_TEXTURE_COORDINATES, 1)),
            CustomAttribute("uv2", GLGpuProgram.getFixedAttributeIndex(VertexElementSemantic.VES_TEXTURE_COORDINATES, 2)),
            CustomAttribute("uv3", GLGpuProgram.getFixedAttributeIndex(VertexElementSemantic.VES_TEXTURE_COORDINATES, 3)),
            CustomAttribute("uv4", GLGpuProgram.getFixedAttributeIndex(VertexElementSemantic.VES_TEXTURE_COORDINATES, 4)),
            CustomAttribute("uv5", GLGpuProgram.getFixedAttributeIndex(VertexElementSemantic.VES_TEXTURE_COORDINATES, 5)),
            CustomAttribute("uv6", GLGpuProgram.getFixedAttributeIndex(VertexElementSemantic.VES_TEXTURE_COORDINATES, 6)),
            CustomAttribute("uv7", GLGpuProgram.getFixedAttributeIndex(VertexElementSemantic.VES_TEXTURE_COORDINATES, 7)),
            CustomAttribute("tangent", GLGpuProgram.getFixedAttributeIndex(VertexElementSemantic.VES_TANGENT, 0)),
            CustomAttribute("binormal", GLGpuProgram.getFixedAttributeIndex(VertexElementSemantic.VES_BINORMAL, 0)),
        ];
}
private:
    /// Container of uniform references that are active in the program object
    GLUniformReference[] mGLUniformReferences;
    
    /// Linked vertex program
    GLSLGpuProgram mVertexProgram;
    /// Linked geometry program
    GLSLGpuProgram mGeometryProgram;
    /// Linked fragment program
    GLSLGpuProgram mFragmentProgram;
    
    /// Flag to indicate that uniform references have already been built
    bool        mUniformRefsBuilt;
    /// GL handle for the program object
    //GLhandleARB mGLHandle;
    GLuint mGLHandle;
    /// Flag indicating that the program object has been successfully linked
    GLint       mLinked;
    /// Flag indicating that the program object has tried to link and failed
    bool        mTriedToLinkAndFailed;
    /// Flag indicating skeletal animation is being performed
    bool mSkeletalAnimation;
    
    /// Build uniform references from active named uniforms
    void buildGLUniformReferences()
    {
        if (!mUniformRefsBuilt)
        {
            //TODO ...
            GpuConstantDefinitionMap vertParams = null;
            GpuConstantDefinitionMap fragParams = null;
            GpuConstantDefinitionMap geomParams = null;
            if (mVertexProgram)
            {
                vertParams = mVertexProgram.getGLSLProgram().getConstantDefinitions().map;
            }
            if (mGeometryProgram)
            {
                geomParams = mGeometryProgram.getGLSLProgram().getConstantDefinitions().map;
            }
            if (mFragmentProgram)
            {
                fragParams = mFragmentProgram.getGLSLProgram().getConstantDefinitions().map;
            }
            
            GLSLLinkProgramManager.getSingleton().extractUniforms(
                mGLHandle, vertParams, geomParams, fragParams, mGLUniformReferences);
            
            mUniformRefsBuilt = true;
        }
    }

    /// Extract attributes
    void extractAttributes()
    {
        //size_t numAttribs = sizeof(msCustomAttributes)/sizeof(CustomAttribute);
        
        foreach(a; msCustomAttributes)
        {
            GLint attrib = glGetAttribLocation(mGLHandle, CSTR(a.name));
            
            if (attrib != -1)
            {
                mValidAttributes.insert(a.attrib);
            }
        }
    }
    
    //typedef set<GLuint>::type AttributeSet;
    alias GLuint[] AttributeSet;
    /// Custom attribute bindings
    AttributeSet mValidAttributes;
    
    /// Name / attribute list
    struct CustomAttribute
    {
        string name;
        GLuint attrib;
    }
    
    static CustomAttribute[] msCustomAttributes;
    
    string getCombinedName()
    {
        string name;
        if (mVertexProgram)
        {
            name ~= "Vertex Program:" ;
            name ~= mVertexProgram.getName();
        }
        if (mFragmentProgram)
        {
            name ~= " Fragment Program:" ;
            name ~= mFragmentProgram.getName();
        }
        if (mGeometryProgram)
        {
            name ~= " Geometry Program:" ;
            name ~= mGeometryProgram.getName();
        }
        return name;
    }

    //FIXME please, string parsing
    /// Compiles and links the the vertex and fragment programs
    void compileAndLink()
    {
        if (mVertexProgram)
        {
            // compile and attach Vertex Program
            if (!mVertexProgram.getGLSLProgram().compile(true))
            {
                // todo error
                return;
            }
            mVertexProgram.getGLSLProgram().attachToProgramObject(mGLHandle);
            setSkeletalAnimationIncluded(mVertexProgram.isSkeletalAnimationIncluded());
            
            // Some drivers (e.g. OS X on nvidia) incorrectly determine the attribute binding automatically
            
            // and end up aliasing existing built-ins. So avoid! 
            // Bind all used attribs - not all possible ones otherwise we'll get 
            // lots of warnings in the log, and also may end up aliasing names used
            // as varyings by accident
            // Because we can't ask GL whether an attribute is used in the shader
            // until it is linked (chicken and egg!) we have to parse the source
            
            //size_t numAttribs = sizeof(msCustomAttributes)/sizeof(CustomAttribute);
            string vpSource = mVertexProgram.getGLSLProgram().getSource();
            foreach(a; msCustomAttributes)
            {
                // we're looking for either: 
                //   attribute vec<n> <semantic_name>
                //   in vec<n> <semantic_name>
                // The latter is recommended in GLSL 1.3 onwards 
                // be slightly flexible about formatting
                ptrdiff_t pos = vpSource.indexOf(a.name);
                bool foundAttr = false;
                while (pos != -1 && !foundAttr)
                {
                    auto tmp = pos < 20 ? 0 : pos-20;
                    ptrdiff_t startpos = vpSource[tmp..$].indexOf("attribute");
                    if (startpos == -1)
                        if((startpos = vpSource[pos-20..$].indexOf("in")) != -1)
                            startpos += pos-20; //Add offset from beginning of the string
                    else
                        startpos += tmp; //Add offset from beginning of the string

                    if (startpos != -1 && startpos < pos)
                    {
                        // final check 
                        string expr = vpSource[startpos .. pos + a.name.length];
                        string[] vec = StringUtil.split(expr);
                        if ((vec[0] == "in" || vec[0] == "attribute") && vec[2] == a.name)
                        {
                            glBindAttribLocation(mGLHandle, a.attrib, CSTR(a.name)); //GL2.0, had ARB suffix
                            foundAttr = true;
                        }
                    }
                    // Find the position of the next occurance if needed
                    pos = pos + a.name.length + vpSource[pos + a.name.length .. $].indexOf(a.name);
                }
            }
        }

        //TODO There's new GL3+ renderer, just ignore/assert here?
        if (mGeometryProgram)
        {
            // compile and attach Geometry Program
            if (!mGeometryProgram.getGLSLProgram().compile(true))
            {
                // todo error
                return;
            }
            
            mGeometryProgram.getGLSLProgram().attachToProgramObject(mGLHandle);
            
            //Don't set adjacency flag. We handle it internally and expose "false"
            
            RenderOperation.OperationType inputOperationType = mGeometryProgram.getGLSLProgram().getInputOperationType();
            glProgramParameteri(mGLHandle,GL_GEOMETRY_INPUT_TYPE,
                                   getGLGeometryInputPrimitiveType(inputOperationType, mGeometryProgram.isAdjacencyInfoRequired()));
            
            RenderOperation.OperationType outputOperationType = mGeometryProgram.getGLSLProgram().getOutputOperationType();
            //uh
            /*switch (outputOperationType)
            {
                case RenderOperation.OperationType.OT_POINT_LIST:
                case RenderOperation.OperationType.OT_LINE_STRIP:
                case RenderOperation.OperationType.OT_TRIANGLE_STRIP:
                case RenderOperation.OperationType.OT_LINE_LIST:
                case RenderOperation.OperationType.OT_TRIANGLE_LIST:
                case RenderOperation.OperationType.OT_TRIANGLE_FAN:
                    break;
                    
            }*/
            glProgramParameteri(mGLHandle,GL_GEOMETRY_OUTPUT_TYPE,
                                   getGLGeometryOutputPrimitiveType(outputOperationType));
            glProgramParameteri(mGLHandle,GL_GEOMETRY_VERTICES_OUT,
                                   mGeometryProgram.getGLSLProgram().getMaxOutputVertices());
        }
        
        if (mFragmentProgram)
        {
            // compile and attach Fragment Program
            if (!mFragmentProgram.getGLSLProgram().compile(true))
            {
                // todo error
                return;
            }       
            mFragmentProgram.getGLSLProgram().attachToProgramObject(mGLHandle);
        }
        
        
        // now the link
        glProgramParameteri(mGLHandle, GL_PROGRAM_BINARY_RETRIEVABLE_HINT, GL_TRUE);
        glLinkProgram( mGLHandle );
        //glGetObjectParameteriv( mGLHandle, GL_OBJECT_LINK_STATUS_ARB, &mLinked );
        glGetProgramiv(mGLHandle, GL_LINK_STATUS, &mLinked);
        mTriedToLinkAndFailed = !mLinked;
        
        // force logging and raise exception if not linked
        GLenum glErr = glGetError();
        if(glErr != GL_NO_ERROR)
        {
            reportGLSLError( glErr, "GLSLLinkProgram.compileAndLink",
                            "Error linking GLSL Program Object : ", mGLHandle, !mLinked, !mLinked );
        }
        
        if(mLinked)
        {
            logObjectInfo(  getCombinedName() ~ " GLSL link result : ", mGLHandle );
        }
        
        if (mLinked)
        {
            if ( GpuProgramManager.getSingleton().getSaveMicrocodesToCache() )
            {
                // add to the microcode to the cache
                string name = getCombinedName();
                
                // get buffer size
                GLint binaryLength = 0;
                glGetProgramiv(mGLHandle, GL_PROGRAM_BINARY_LENGTH, &binaryLength);
                
                // turns out we need this param when loading
                // it will be the first bytes of the array in the microcode
                GLenum binaryFormat = 0; 
                
                // create microcode
                GpuProgramManager.Microcode newMicrocode = 
                    GpuProgramManager.getSingleton().createMicrocode(binaryLength + GLenum.sizeof);
                
                // get binary
                ubyte * programBuffer = newMicrocode.getPtr() + GLenum.sizeof;
                glGetProgramBinary(mGLHandle, binaryLength, null, &binaryFormat, programBuffer);
                
                // save binary format
                memcpy(newMicrocode.getPtr(), &binaryFormat, GLenum.sizeof);
                
                // add to the microcode to the cache
                GpuProgramManager.getSingleton().addMicrocodeToCache(name, newMicrocode);
            }
        }
    }

    /// Get the the binary data of a program from the microcode cache
    void getMicrocodeFromCache()
    {
        GpuProgramManager.Microcode cacheMicrocode = 
            GpuProgramManager.getSingleton().getMicrocodeFromCache(getCombinedName());
        
        GLenum binaryFormat = *(cast(GLenum *)(cacheMicrocode.getPtr()));
        ubyte * programBuffer = cacheMicrocode.getPtr() + GLenum.sizeof;
        size_t sizeOfBuffer = cacheMicrocode.size() - GLenum.sizeof;
        glProgramBinary(mGLHandle, 
                        binaryFormat, 
                        programBuffer,
                        cast(GLint)sizeOfBuffer
                        );
        
        GLint   success = 0;
        glGetProgramiv(mGLHandle, GL_LINK_STATUS, &success);
        if (!success)
        {
            //
            // Something must have changed since the program binaries
            // were cached away.  Fallback to source shader loading path,
            // and then retrieve and cache new program binaries once again.
            //
            compileAndLink();
        }
    }

public:
    /// Constructor should only be used by GLSLLinkProgramManager
    this(GLSLGpuProgram vertexProgram, GLSLGpuProgram geometryProgram, GLSLGpuProgram fragmentProgram)
    {
        mVertexProgram = vertexProgram;
        mGeometryProgram = geometryProgram;
        mFragmentProgram = fragmentProgram;
        mUniformRefsBuilt = false;
        mLinked = false;
        mTriedToLinkAndFailed = false;
    }

    ~this()
    {
        glDeleteProgram(mGLHandle);
    }
    
    /** Makes a program object active by making sure it is linked and then putting it in use.

        */
    void activate()
    {
        if (!mLinked && !mTriedToLinkAndFailed)
        {           
            glGetError(); //Clean up the error. Otherwise will flood log.
            
            mGLHandle = glCreateProgram();//glCreateProgramObjectARB();
            
            GLenum glErr = glGetError();
            if(glErr != GL_NO_ERROR)
            {
                reportGLSLError( glErr, "GLSLLinkProgram.activate", "Error Creating GLSL Program Object", 0 );
            }
            
            if ( GpuProgramManager.getSingleton().canGetCompiledShaderBuffer() &&
                GpuProgramManager.getSingleton().isMicrocodeAvailableInCache(getCombinedName()) )
            {
                getMicrocodeFromCache();
            }
            else
            {
                compileAndLink();
                
            }
            buildGLUniformReferences();
            extractAttributes();
        }
        if (mLinked)
        {
            GLenum glErr = glGetError();
            if(glErr != GL_NO_ERROR)
            {
                reportGLSLError( glErr, "GLSLLinkProgram.Activate",
                                "Error prior to using GLSL Program Object : ", mGLHandle, false, false);
            }
            
            //glUseProgramObjectARB( mGLHandle );
            glUseProgram( mGLHandle );
            
            glErr = glGetError();
            if(glErr != GL_NO_ERROR)
            {
                reportGLSLError( glErr, "GLSLLinkProgram.Activate",
                                "Error using GLSL Program Object : ", mGLHandle, false, false);
            }
        }
    }
    
    /** Updates program object uniforms using data from GpuProgramParameters.
        normally called by GLSLGpuProgram::bindParameters() just before rendering occurs.
        */
    void updateUniforms(SharedPtr!GpuProgramParameters _params, ushort mask, GpuProgramType fromProgType)
    {
        auto params = _params.get();
        // iterate through uniform reference list and update uniform values
        //GLUniformReferenceIterator currentUniform = mGLUniformReferences.begin();
        //GLUniformReferenceIterator endUniform = mGLUniformReferences.end();
        
        // determine if we need to transpose matrices when binding
        int transpose = GL_TRUE;
        if ((fromProgType == GpuProgramType.GPT_FRAGMENT_PROGRAM && mVertexProgram && (!mVertexProgram.getGLSLProgram().getColumnMajorMatrices())) ||
            (fromProgType == GpuProgramType.GPT_VERTEX_PROGRAM && mFragmentProgram && (!mFragmentProgram.getGLSLProgram().getColumnMajorMatrices())) ||
            (fromProgType == GpuProgramType.GPT_GEOMETRY_PROGRAM && mGeometryProgram && (!mGeometryProgram.getGLSLProgram().getColumnMajorMatrices())))
        {
            transpose = GL_FALSE;
        }
        
        foreach (currentUniform; mGLUniformReferences)
        {
            // Only pull values from buffer it's supposed to be in (vertex or fragment)
            // This method will be called twice, once for vertex program params, 
            // and once for fragment program params.
            if (fromProgType == currentUniform.mSourceProgType)
            {
                const(GpuConstantDefinition*) def = currentUniform.mConstantDef;
                if (def.variability & mask)
                {
                    
                    GLsizei glArraySize = cast(GLsizei)def.arraySize;
                    
                    // get the index in the parameter real list
                    switch (def.constType)
                    {
                        case GpuConstantType.GCT_FLOAT1:
                            glUniform1fv(currentUniform.mLocation, glArraySize, 
                                            params.getFloatPointer(def.physicalIndex));
                            break;
                        case GpuConstantType.GCT_FLOAT2:
                            glUniform2fv(currentUniform.mLocation, glArraySize, 
                                            params.getFloatPointer(def.physicalIndex));
                            break;
                        case GpuConstantType.GCT_FLOAT3:
                            glUniform3fv(currentUniform.mLocation, glArraySize, 
                                            params.getFloatPointer(def.physicalIndex));
                            break;
                        case GpuConstantType.GCT_FLOAT4:
                            glUniform4fv(currentUniform.mLocation, glArraySize, 
                                            params.getFloatPointer(def.physicalIndex));
                            break;
                        case GpuConstantType.GCT_MATRIX_2X2:
                            glUniformMatrix2fv(currentUniform.mLocation, glArraySize, 
                                                  cast(ubyte)transpose, params.getFloatPointer(def.physicalIndex));
                            break;
                        case GpuConstantType.GCT_MATRIX_2X3:
                            if (GLEW_VERSION_2_1)
                            {
                                glUniformMatrix2x3fv(currentUniform.mLocation, glArraySize, 
                                                     cast(ubyte)transpose, params.getFloatPointer(def.physicalIndex));
                            }
                            break;
                        case GpuConstantType.GCT_MATRIX_2X4:
                            if (GLEW_VERSION_2_1)
                            {
                                glUniformMatrix2x4fv(currentUniform.mLocation, glArraySize, 
                                                     cast(ubyte)transpose, params.getFloatPointer(def.physicalIndex));
                            }
                            break;
                        case GpuConstantType.GCT_MATRIX_3X2:
                            if (GLEW_VERSION_2_1)
                            {
                                glUniformMatrix3x2fv(currentUniform.mLocation, glArraySize, 
                                                     cast(ubyte)transpose, params.getFloatPointer(def.physicalIndex));
                            }
                            break;
                        case GpuConstantType.GCT_MATRIX_3X3:
                            glUniformMatrix3fv(currentUniform.mLocation, glArraySize, 
                                               cast(ubyte)transpose, params.getFloatPointer(def.physicalIndex));
                            break;
                        case GpuConstantType.GCT_MATRIX_3X4:
                            if (GLEW_VERSION_2_1)
                            {
                                glUniformMatrix3x4fv(currentUniform.mLocation, glArraySize, 
                                                     cast(ubyte)transpose, params.getFloatPointer(def.physicalIndex));
                            }
                            break;
                        case GpuConstantType.GCT_MATRIX_4X2:
                            if (GLEW_VERSION_2_1)
                            {
                                glUniformMatrix4x2fv(currentUniform.mLocation, glArraySize, 
                                                     cast(ubyte)transpose, params.getFloatPointer(def.physicalIndex));
                            }
                            break;
                        case GpuConstantType.GCT_MATRIX_4X3:
                            if (GLEW_VERSION_2_1)
                            {
                                glUniformMatrix4x3fv(currentUniform.mLocation, glArraySize, 
                                                     cast(ubyte)transpose, params.getFloatPointer(def.physicalIndex));
                            }
                            break;
                        case GpuConstantType.GCT_MATRIX_4X4:
                            glUniformMatrix4fv(currentUniform.mLocation, glArraySize, 
                                               cast(ubyte)transpose, params.getFloatPointer(def.physicalIndex));
                            break;
                        case GpuConstantType.GCT_INT1:
                            glUniform1iv(currentUniform.mLocation, glArraySize, 
                                            cast(GLint*)params.getIntPointer(def.physicalIndex));
                            break;
                        case GpuConstantType.GCT_INT2:
                            glUniform2iv(currentUniform.mLocation, glArraySize, 
                                            cast(GLint*)params.getIntPointer(def.physicalIndex));
                            break;
                        case GpuConstantType.GCT_INT3:
                            glUniform3iv(currentUniform.mLocation, glArraySize, 
                                            cast(GLint*)params.getIntPointer(def.physicalIndex));
                            break;
                        case GpuConstantType.GCT_INT4:
                            glUniform4iv(currentUniform.mLocation, glArraySize, 
                                            cast(GLint*)params.getIntPointer(def.physicalIndex));
                            break;
                        case GpuConstantType.GCT_SAMPLER1D:
                        case GpuConstantType.GCT_SAMPLER1DSHADOW:
                        case GpuConstantType.GCT_SAMPLER2D:
                        case GpuConstantType.GCT_SAMPLER2DSHADOW:
                        case GpuConstantType.GCT_SAMPLER2DARRAY:
                        case GpuConstantType.GCT_SAMPLER3D:
                        case GpuConstantType.GCT_SAMPLERCUBE:
                            // samplers handled like 1-element ints
                            glUniform1iv(currentUniform.mLocation, 1, 
                                            cast(GLint*)params.getIntPointer(def.physicalIndex));
                            break;
                        case GpuConstantType.GCT_UNKNOWN:
                            break;
                        default:
                            break;
                            
                    } // end switch
                    static if(OGRE_GL_DBG)
                    {
                        GLenum glErr = glGetError();
                        if(glErr != GL_NO_ERROR)
                        {
                            reportGLSLError( glErr, "GLSLLinkProgram.updateUniforms", "Error updating uniform", 0 );
                        }
                    }
                } // variability & mask
            } // fromProgType == currentUniform.mSourceProgType
            
        } // end for
    }

    /** Updates program object uniforms using data from pass iteration GpuProgramParameters.
        normally called by GLSLGpuProgram::bindMultiPassParameters() just before multi pass rendering occurs.
        */
    void updatePassIterationUniforms(SharedPtr!GpuProgramParameters params)
    {
        if (params.get().hasPassIterationNumber())
        {
            size_t index = params.get().getPassIterationNumberIndex();
                        
            // need to find the uniform that matches the multi pass entry
            foreach (currentUniform; mGLUniformReferences)
            {
                // get the index in the parameter real list
                if (index == currentUniform.mConstantDef.physicalIndex)
                {
                    glUniform1fv( currentUniform.mLocation, 1, params.get().getFloatPointer(index));
                    // there will only be one multipass entry
                    return;
                }
            }
        }
        
    }

    /// Get the GL Handle for the program object
    GLuint getGLHandle() const { return mGLHandle; }
    /** Sets whether the linked program includes the required instructions
        to perform skeletal animation. 
        @remarks
        If this is set to true, OGRE will not blend the geometry according to 
        skeletal animation, it will expect the vertex program to do it.
        */
    void setSkeletalAnimationIncluded(bool included) 
    { mSkeletalAnimation = included; }
    
    /** Returns whether the linked program includes the required instructions
            to perform skeletal animation. 
        @remarks
            If this returns true, OGRE will not blend the geometry according to 
            skeletal animation, it will expect the vertex program to do it.
        */
    bool isSkeletalAnimationIncluded() const { return mSkeletalAnimation; }
    
    /// Get the index of a non-standard attribute bound in the linked code
    GLuint getAttributeIndex(VertexElementSemantic semantic, uint index)
    {
        return GLGpuProgram.getFixedAttributeIndex(semantic, index);
    }

    /// Is a non-standard attribute bound in the linked code?
    bool isAttributeValid(VertexElementSemantic semantic, uint index)
    {
        return mValidAttributes.find(getAttributeIndex(semantic, index)).length != 0; //!= mValidAttributes.end();
    }
    
}