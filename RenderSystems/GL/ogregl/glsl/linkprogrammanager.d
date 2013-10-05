module ogregl.glsl.linkprogrammanager;
debug import std.stdio;
import std.string: indexOf, strip;
import derelict.opengl3.gl;

import ogre.compat;
import ogre.singleton;
import ogre.materials.gpuprogram;
import ogregl.glsl.linkprogram;
import ogregl.glsl.gpuprogram;
import ogre.strings;
import ogre.general.log;

//TODO NOTE: modernized a bit, using GL2.0 calls

/** Ogre assumes that there are separate vertex and fragment programs to deal with but
        GLSL has one program object that represents the active vertex and fragment shader objects
        during a rendering state.  GLSL Vertex and fragment 
        shader objects are compiled separately and then attached to a program object and then the
        program object is linked.  Since Ogre can only handle one vertex program and one fragment
        program being active in a pass, the GLSL Link Program Manager does the same.  The GLSL Link
        program manager acts as a state machine and activates a program object based on the active
        vertex and fragment program.  Previously created program objects are stored along with a unique
        key in a hash_map for quick retrieval the next time the program object is required.

    */

class GLSLLinkProgramManager
{
    mixin Singleton!GLSLLinkProgramManager;
private:
    
    //typedef map<uint64, GLSLLinkProgram*>::type LinkProgramMap;
    alias GLSLLinkProgram[ulong] LinkProgramMap;
    //typedef LinkProgramMap::iterator LinkProgramIterator;
    
    /// container holding previously created program objects 
    /// aka LinkProgramMap
    GLSLLinkProgram[ulong] mLinkPrograms;
    
    /// active objects defining the active rendering gpu state
    GLSLGpuProgram mActiveVertexGpuProgram;
    GLSLGpuProgram mActiveGeometryGpuProgram;
    GLSLGpuProgram mActiveFragmentGpuProgram;
    GLSLLinkProgram mActiveLinkProgram;
    
    //typedef map<String, GLenum>::type StringToEnumMap;
    alias GLenum[string] StringToEnumMap;
    ///aka StringToEnumMap
    GLenum[string] mTypeEnumMap;
    
    /// Use type to complete other information
    void completeDefInfo(GLenum gltype, GpuConstantDefinition* defToUpdate)
    {
        // decode uniform size and type
        // Note GLSL never packs rows into float4's(from an API perspective anyway)
        // therefore all values are tight in the buffer
        switch (gltype)
        {
            case GL_FLOAT:
                defToUpdate.constType = GpuConstantType.GCT_FLOAT1;
                break;
            case GL_FLOAT_VEC2:
                defToUpdate.constType = GpuConstantType.GCT_FLOAT2;
                break;
                
            case GL_FLOAT_VEC3:
                defToUpdate.constType = GpuConstantType.GCT_FLOAT3;
                break;
                
            case GL_FLOAT_VEC4:
                defToUpdate.constType = GpuConstantType.GCT_FLOAT4;
                break;
            case GL_SAMPLER_1D:
                // need to record samplers for GLSL
                defToUpdate.constType = GpuConstantType.GCT_SAMPLER1D;
                break;
            case GL_SAMPLER_2D:
            case GL_SAMPLER_2D_RECT:
                defToUpdate.constType = GpuConstantType.GCT_SAMPLER2D;
                break;
            case GL_SAMPLER_2D_ARRAY:
                defToUpdate.constType = GpuConstantType.GCT_SAMPLER2DARRAY;
                break;
            case GL_SAMPLER_3D:
                defToUpdate.constType = GpuConstantType.GCT_SAMPLER3D;
                break;
            case GL_SAMPLER_CUBE:
                defToUpdate.constType = GpuConstantType.GCT_SAMPLERCUBE;
                break;
            case GL_SAMPLER_1D_SHADOW:
                defToUpdate.constType = GpuConstantType.GCT_SAMPLER1DSHADOW;
                break;
            case GL_SAMPLER_2D_SHADOW:
            case GL_SAMPLER_2D_RECT_SHADOW:
                defToUpdate.constType = GpuConstantType.GCT_SAMPLER2DSHADOW;
                break;
            case GL_INT:
                defToUpdate.constType = GpuConstantType.GCT_INT1;
                break;
            case GL_INT_VEC2:
                defToUpdate.constType = GpuConstantType.GCT_INT2;
                break;
            case GL_INT_VEC3:
                defToUpdate.constType = GpuConstantType.GCT_INT3;
                break;
            case GL_INT_VEC4:
                defToUpdate.constType = GpuConstantType.GCT_INT4;
                break;
            case GL_FLOAT_MAT2:
                defToUpdate.constType = GpuConstantType.GCT_MATRIX_2X2;
                break;
            case GL_FLOAT_MAT3:
                defToUpdate.constType = GpuConstantType.GCT_MATRIX_3X3;
                break;
            case GL_FLOAT_MAT4:
                defToUpdate.constType = GpuConstantType.GCT_MATRIX_4X4;
                break;
            case GL_FLOAT_MAT2x3:
                defToUpdate.constType = GpuConstantType.GCT_MATRIX_2X3;
                break;
            case GL_FLOAT_MAT3x2:
                defToUpdate.constType = GpuConstantType.GCT_MATRIX_3X2;
                break;
            case GL_FLOAT_MAT2x4:
                defToUpdate.constType = GpuConstantType.GCT_MATRIX_2X4;
                break;
            case GL_FLOAT_MAT4x2:
                defToUpdate.constType = GpuConstantType.GCT_MATRIX_4X2;
                break;
            case GL_FLOAT_MAT3x4:
                defToUpdate.constType = GpuConstantType.GCT_MATRIX_3X4;
                break;
            case GL_FLOAT_MAT4x3:
                defToUpdate.constType = GpuConstantType.GCT_MATRIX_4X3;
                break;
            default:
                defToUpdate.constType = GpuConstantType.GCT_UNKNOWN;
                break;
                
        }
        
        // GL doesn't pad
        defToUpdate.elementSize = GpuConstantDefinition.getElementSize(defToUpdate.constType, false);
        
        
    }

    /// Find where the data for a specific uniform should come from, populate
    bool completeParamSource(string paramName,
                             GpuConstantDefinitionMap vertexConstantDefs, 
                             GpuConstantDefinitionMap geometryConstantDefs,
                             GpuConstantDefinitionMap fragmentConstantDefs,
                             GLUniformReference* refToUpdate)
    {
        if (!vertexConstantDefs.emptyAA)
        {
            auto parami = paramName in vertexConstantDefs;
            if (parami !is null)
            {
                refToUpdate.mSourceProgType = GpuProgramType.GPT_VERTEX_PROGRAM;
                refToUpdate.mConstantDef = parami;
                return true;
            }
            
        }
        if (!geometryConstantDefs.emptyAA)
        {
            auto parami = paramName in geometryConstantDefs;
            if (parami !is null)
            {
                refToUpdate.mSourceProgType = GpuProgramType.GPT_GEOMETRY_PROGRAM;
                refToUpdate.mConstantDef = parami;
                return true;
            }
            
        }
        if (!fragmentConstantDefs.emptyAA)
        {
            auto parami = paramName in fragmentConstantDefs;
            if (parami !is null)
            {
                refToUpdate.mSourceProgType = GpuProgramType.GPT_FRAGMENT_PROGRAM;
                refToUpdate.mConstantDef = parami;
                return true;
            }
        }
        return false;
    }
    
public:
    
    this()
    {
        //mActiveVertexGpuProgram(NULL),mActiveGeometryGpuProgram(NULL), mActiveFragmentGpuProgram(NULL), mActiveLinkProgram(NULL)
        // Fill in the relationship between type names and enums
        mTypeEnumMap["float"] = GL_FLOAT;
        mTypeEnumMap["vec2"] = GL_FLOAT_VEC2;
        mTypeEnumMap["vec3"] = GL_FLOAT_VEC3;
        mTypeEnumMap["vec4"] = GL_FLOAT_VEC4;
        mTypeEnumMap["sampler1D"] = GL_SAMPLER_1D;
        mTypeEnumMap["sampler2D"] = GL_SAMPLER_2D;
        mTypeEnumMap["sampler3D"] = GL_SAMPLER_3D;
        mTypeEnumMap["sampler2DArray"] = GL_SAMPLER_2D_ARRAY;
        mTypeEnumMap["samplerCube"] = GL_SAMPLER_CUBE;
        mTypeEnumMap["sampler1DShadow"] = GL_SAMPLER_1D_SHADOW;
        mTypeEnumMap["sampler2DShadow"] = GL_SAMPLER_2D_SHADOW;
        mTypeEnumMap["int"] = GL_INT;
        mTypeEnumMap["ivec2"] = GL_INT_VEC2;
        mTypeEnumMap["ivec3"] = GL_INT_VEC3;
        mTypeEnumMap["ivec4"] = GL_INT_VEC4;
        mTypeEnumMap["mat2"] = GL_FLOAT_MAT2;
        mTypeEnumMap["mat3"] = GL_FLOAT_MAT3;
        mTypeEnumMap["mat4"] = GL_FLOAT_MAT4;
        // GL 2.1
        mTypeEnumMap["mat2x2"] = GL_FLOAT_MAT2;
        mTypeEnumMap["mat3x3"] = GL_FLOAT_MAT3;
        mTypeEnumMap["mat4x4"] = GL_FLOAT_MAT4;
        mTypeEnumMap["mat2x3"] = GL_FLOAT_MAT2x3;
        mTypeEnumMap["mat3x2"] = GL_FLOAT_MAT3x2;
        mTypeEnumMap["mat3x4"] = GL_FLOAT_MAT3x4;
        mTypeEnumMap["mat4x3"] = GL_FLOAT_MAT4x3;
        mTypeEnumMap["mat2x4"] = GL_FLOAT_MAT2x4;
        mTypeEnumMap["mat4x2"] = GL_FLOAT_MAT4x2;
        
    }
    
    ~this()
    {
        // iterate through map container and delete link programs
        foreach (k, currentProgram; mLinkPrograms)
        {
            destroy (currentProgram);
        }
    }
    
    /**
            Get the program object that links the two active shader objects together
            if a program object was not already created and linked a new one is created and linked
        */
    GLSLLinkProgram getActiveLinkProgram()
    {
        // if there is an active link program then return it
        if (mActiveLinkProgram !is null)
            return mActiveLinkProgram;
        
        // no active link program so find one or make a new one
        // is there an active key?
        ulong activeKey = 0;
        
        if (mActiveVertexGpuProgram !is null)
        {
            activeKey = cast(ulong)(mActiveVertexGpuProgram.getProgramID()) << 32;
        }
        if (mActiveGeometryGpuProgram !is null)
        {
            activeKey += cast(ulong)(mActiveGeometryGpuProgram.getProgramID()) << 16;
        }
        if (mActiveFragmentGpuProgram !is null)
        {
            activeKey += cast(ulong)(mActiveFragmentGpuProgram.getProgramID());
        }
        
        // only return a link program object if a vertex, geometry or fragment program exist
        if (activeKey > 0)
        {
            // find the key in the hash map
            GLSLLinkProgram* programFound = activeKey in mLinkPrograms;
            // program object not found for key so need to create it
            if (programFound is null)
            {
                mActiveLinkProgram = new GLSLLinkProgram(mActiveVertexGpuProgram, mActiveGeometryGpuProgram,mActiveFragmentGpuProgram);
                mLinkPrograms[activeKey] = mActiveLinkProgram;
            }
            else
            {
                // found a link program in map container so make it active
                mActiveLinkProgram = *programFound;
            }
            
        }
        // make the program object active
        if (mActiveLinkProgram !is null) mActiveLinkProgram.activate();
        
        return mActiveLinkProgram;
        
    }
    
    /** Set the active fragment shader for the next rendering state.
            The active program object will be cleared.
            Normally called from the GLSLGpuProgram::bindProgram and unbindProgram methods
        */
    void setActiveFragmentShader(GLSLGpuProgram fragmentGpuProgram)
    {
        if (fragmentGpuProgram != mActiveFragmentGpuProgram)
        {
            mActiveFragmentGpuProgram = fragmentGpuProgram;
            // ActiveLinkProgram is no longer valid
            mActiveLinkProgram = null;
            // change back to fixed pipeline
            //glUseProgramObjectARB(0);
            glUseProgram(0);//GL2.0
        }
    }

    /** Set the active geometry shader for the next rendering state.
            The active program object will be cleared.
            Normally called from the GLSLGpuProgram::bindProgram and unbindProgram methods
        */
    void setActiveGeometryShader(GLSLGpuProgram geometryGpuProgram)
    {
        if (geometryGpuProgram != mActiveGeometryGpuProgram)
        {
            mActiveGeometryGpuProgram = geometryGpuProgram;
            // ActiveLinkProgram is no longer valid
            mActiveLinkProgram = null;
            // change back to fixed pipeline
            //glUseProgramObjectARB(0);
            glUseProgram(0);//GL2.0
        }
    }

    /** Set the active vertex shader for the next rendering state.
            The active program object will be cleared.
            Normally called from the GLSLGpuProgram::bindProgram and unbindProgram methods
        */
    void setActiveVertexShader(GLSLGpuProgram vertexGpuProgram)
    {
        if (vertexGpuProgram != mActiveVertexGpuProgram)
        {
            mActiveVertexGpuProgram = vertexGpuProgram;
            // ActiveLinkProgram is no longer valid
            mActiveLinkProgram = null;
            // change back to fixed pipeline
            //glUseProgramObjectARB(0);
            glUseProgram(0);//GL2.0
        }
    }
    
    /** Populate a list of uniforms based on a program object.
        @param programObject Handle to the program object to query
        @param vertexConstantDefs Definition of the constants extracted from the
            vertex program, used to match up physical buffer indexes with program
            uniforms. May be null if there is no vertex program.
        @param geometryConstantDefs Definition of the constants extracted from the
            geometry program, used to match up physical buffer indexes with program
            uniforms. May be null if there is no geometry program.
        @param fragmentConstantDefs Definition of the constants extracted from the
            fragment program, used to match up physical buffer indexes with program
            uniforms. May be null if there is no fragment program.
        @param list The list to populate (will not be cleared before adding, clear
        it yourself before calling this if that's what you want).
        */
    void extractUniforms(GLuint programObject, 
                         /*immutable ?*/GpuConstantDefinitionMap vertexConstantDefs, 
                         /*immutable ?*/GpuConstantDefinitionMap geometryConstantDefs,
                         /*immutable ?*/GpuConstantDefinitionMap fragmentConstantDefs,
                         ref GLUniformReference[] list)
    {
        // scan through the active uniforms and add them to the reference list
        GLint uniformCount = 0;
        
        enum BUFFERSIZE = 200;
        char[BUFFERSIZE] uniformName;
        //GLint location;
        GLUniformReference newGLUniformReference;
        
        // get the number of active uniforms
        //glGetObjectParameterivARB(programObject, GL_OBJECT_ACTIVE_UNIFORMS_ARB, &uniformCount);
        glGetProgramiv(programObject, GL_ACTIVE_UNIFORMS, &uniformCount);
        
        // Loop over each of the active uniforms, and add them to the reference container
        // only do this for user defined uniforms, ignore built in gl state uniforms
        for (int index = 0; index < uniformCount; index++)
        {
            GLint arraySize = 0, strLen = 0;
            GLenum glType;
            //glGetActiveUniformARB(programObject, index, BUFFERSIZE, NULL, 
            //                      &arraySize, &glType, uniformName);
            glGetActiveUniform(programObject, index, BUFFERSIZE, &strLen, 
                               &arraySize, &glType, uniformName.ptr); //GL2.0
            // don't add built in uniforms
            newGLUniformReference.mLocation = glGetUniformLocation(programObject, uniformName.ptr); //GL2.0, had ARB suffix
            if (newGLUniformReference.mLocation >= 0)
            {
                // user defined uniform found, add it to the reference list
                string paramName = std.conv.to!string( uniformName );
                //paramName.length = strLen; //TODO drop '\0'
                
                // Current ATI drivers (Catalyst 7.2 and earlier) and older NVidia drivers will include all array elements as uniforms but we only want the root array name and location
                // Also note that ATI Catalyst 6.8 to 7.2 there is a bug with glUniform that does not allow you to update a uniform array past the first uniform array element
                // ie you can't start updating an array starting at element 1, must always be element 0.
                
                // if the uniform name has a "[" in it then its an array element uniform.
                ptrdiff_t arrayStart = paramName.indexOf("[");
                if (arrayStart != -1)
                {
                    // if not the first array element then skip it and continue to the next uniform
                    if (paramName[arrayStart..$] != "[0]") continue;
                    paramName = paramName[0..arrayStart];
                }
                
                // find out which params object this comes from
                bool foundSource = completeParamSource(paramName,
                                                       vertexConstantDefs, geometryConstantDefs, 
                                                       fragmentConstantDefs, &newGLUniformReference);
                
                // only add this parameter if we found the source
                if (foundSource)
                {
                    assert(cast(size_t)arraySize == newGLUniformReference.mConstantDef.arraySize,
                           "GL doesn't agree with our array size!");//TODO Or struct reffing problem somewhere
                    list.insert(newGLUniformReference);
                }
                
                // Don't bother adding individual array params, they will be
                // picked up in the 'parent' parameter can copied all at once
                // anyway, individual indexes are only needed for lookup from
                // user params
            } // end if
        } // end for
        
    }

    /** Populate a list of uniforms based on GLSL source.
        @param src Reference to the source code
        @param constantDefs The defs to populate (will not be cleared before adding, clear
        it yourself before calling this if that's what you want).
        @param filename The file name this came from, for logging errors.
        */
    //FIXME that string parsing...
    void extractConstantDefs(string src, GpuNamedConstants* constantDefs, 
                             string filename)
    {
        // Parse the output string and collect all uniforms
        // NOTE this relies on the source already having been preprocessed
        // which is done in GLSLProgram::loadFromSource
        string line;
        ptrdiff_t currPos = src.indexOf("uniform");
        while (currPos != -1)
        {
            GpuConstantDefinition def;
            string paramName;
            
            // Now check for using the word 'uniform' in a larger string & ignore
            bool inLargerString = false;
            if (currPos != 0)
            {
                immutable(char) prev = src[currPos - 1];
                if (prev != ' ' && prev != '\t' && prev != '\r' && prev != '\n'
                    && prev != ';')
                    inLargerString = true;
            }
            if (!inLargerString && currPos + 7 < src.length)
            {
                immutable(char) next = src[currPos + 7];
                if (next != ' ' && next != '\t' && next != '\r' && next != '\n')
                    inLargerString = true;
            }
            
            // skip 'uniform'
            currPos += 7;
            
            if (!inLargerString)
            {
                // find terminating semicolon
                ptrdiff_t endPos = src[currPos..$].indexOf(";");
                if (endPos == -1)
                {
                    // problem, missing semicolon, abort
                    break;
                }
                endPos += currPos; //make offset start from the beginning of the string
                line = src[currPos..endPos];
                
                // Remove spaces before opening square braces, otherwise
                // the following split() can split the line at inappropriate
                // places (e.g. "vec3 something [3]" won't work).
                for (ptrdiff_t sqp = line.indexOf (" ["); sqp != -1;
                     sqp = line.indexOf (" ["))
                    line = line[0..sqp] ~ line[sqp+1..$]; //line.erase (sqp, 1);

                // Split into tokens
                string[] parts = StringUtil.split(line, ", \t\r\n");
                
                foreach (i; parts)
                {
                    // Is this a type?
                    auto typei = i in mTypeEnumMap;
                    if (typei !is null)
                    {
                        completeDefInfo(*typei, &def);
                    }
                    else
                    {
                        // if this is not a type, and not empty, it should be a name
                        //StringUtil::trim(*i);
                        i = i.strip();
                        if (!i.length) continue;
                        
                        ptrdiff_t arrayStart = i.indexOf("[");
                        if (arrayStart != -1)
                        {
                            // potential name (if butted up to array)
                            string name = i[0..arrayStart].strip();
                            if (name.length)
                                paramName = name;
                            
                            ptrdiff_t arrayEnd = i[arrayStart..$].indexOf("]");
                            string arrayDimTerm = i[arrayStart + 1 .. arrayStart + arrayEnd/* - 1*/].strip();
                            stderr.writeln("arrayDimTerm: ", arrayStart, " - ", arrayEnd, "  == ", arrayDimTerm);

                            // the array term might be a simple number or it might be
                            // an expression (e.g. 24*3) or refer to a constant expression
                            // we'd have to evaluate the expression which could get nasty
                            // TODO
                            def.arraySize = std.conv.to!int(arrayDimTerm);
                            
                        }
                        else
                        {
                            paramName = i;
                            def.arraySize = 1;
                        }
                        
                        // Name should be after the type, so complete def and add
                        // We do this now so that comma-separated params will do
                        // this part once for each name mentioned 
                        if (def.constType == GpuConstantType.GCT_UNKNOWN)
                        {
                            LogManager.getSingleton().logMessage(
                                "Problem parsing the following GLSL Uniform: '"
                                ~ line ~ "' in file " ~ filename);
                            // next uniform
                            break;
                        }
                        
                        // Complete def and add
                        // increment physical buffer location
                        def.logicalIndex = 0; // not valid in GLSL
                        if (def.isFloat())
                        {
                            def.physicalIndex = constantDefs.floatBufferSize;
                            constantDefs.floatBufferSize += def.arraySize * def.elementSize;
                        }
                        else
                        {
                            def.physicalIndex = constantDefs.intBufferSize;
                            constantDefs.intBufferSize += def.arraySize * def.elementSize;
                        }
                        constantDefs.map[paramName] = def;
                        
                        // Generate array accessors
                        constantDefs.generateConstantDefinitionArrayEntries(paramName, def);
                    }
                    
                }
                
            } // not commented or a larger symbol
            
            // Find next one
            ptrdiff_t off = src[currPos..$].indexOf("uniform");
            if(off != -1)
                currPos += off;
            else
                currPos = -1;//or break;
        }
        
    }

}