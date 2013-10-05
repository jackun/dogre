module ogregl.rendertovertexbuffer;
import std.conv: text;
import derelict.opengl3.gl;
import ogre.rendersystem.rendersystem;
import ogre.rendersystem.hardware;
import ogre.rendersystem.renderoperation;
import ogre.rendersystem.vertex;
import ogre.scene.scenemanager;
import ogre.materials.pass;
import ogre.materials.gpuprogram;
import ogre.general.root;
import ogre.general.log;
import ogre.math.matrix;
import ogre.exception;
import ogre.compat;
import ogregl.hardwarevertexbuffer;
import ogregl.glsl.linkprogrammanager;
import ogregl.compat;
import ogregl.glsl.linkprogram;


static GLint getR2VBPrimitiveType(RenderOperation.OperationType operationType)
{
    switch (operationType)
    {
        case RenderOperation.OperationType.OT_POINT_LIST:
            return GL_POINTS;
        case RenderOperation.OperationType.OT_LINE_LIST:
            return GL_LINES;
        case RenderOperation.OperationType.OT_TRIANGLE_LIST:
            return GL_TRIANGLES;
        default:
            throw new InvalidParamsError("GL RenderToVertexBuffer"
                        "can only output point lists, line lists, or triangle lists",
                        "OgreGLRenderToVertexBuffer.getR2VBPrimitiveType");
    }
}

static GLint getVertexCountPerPrimitive(RenderOperation.OperationType operationType)
{
    //We can only get points, lines or triangles since they are the only
    //legal R2VB output primitive types
    switch (operationType)
    {
        case RenderOperation.OperationType.OT_POINT_LIST:
            return 1;
        case RenderOperation.OperationType.OT_LINE_LIST:
            return 2;
        default:
        case RenderOperation.OperationType.OT_TRIANGLE_LIST:
            return 3;
    }
}

/**
        An object which renders geometry to a vertex.
    @remarks
        This is especially useful together with geometry shaders, as you can
        render procedural geometry which will get saved to a vertex buffer for
        reuse later, without regenerating it again. You can also create shaders
        that run on previous results of those shaders, creating stateful 
        shaders.
    */
class GLRenderToVertexBuffer : RenderToVertexBuffer
{    
private:
    void checkGLError(bool logError, bool throwException, 
                      string sectionName = "")
    {
        string msg;
        bool foundError = false;
        
        // get all the GL errors
        GLenum glErr = glGetError();
        while (glErr != GL_NO_ERROR)
        {
            string glerrStr = gluErrorString(glErr);
            if (glerrStr)
            {
                msg ~= glerrStr;
            }
            glErr = glGetError();
            foundError = true;  
        }
        
        if (foundError && (logError || throwException))
        {
            string fullErrorMessage = "GL Error : " ~ msg ~ " in " ~ sectionName;
            if (logError)
            {
                LogManager.getSingleton().getDefaultLog().logMessage(fullErrorMessage);
            }
            if (throwException)
            {
                throw new RenderingApiError(
                    fullErrorMessage, "OgreGLRenderToVertexBuffer");
            }
        }
    }
public:
    /** C'tor */
    this()
    {
        mFrontBufferIndex = -1;
        mVertexBuffers[0] = SharedPtr!HardwareVertexBuffer();//.setNull();
        mVertexBuffers[1] = SharedPtr!HardwareVertexBuffer();//.setNull();
        
        // create query objects
        glGenQueries(1, &mPrimitivesDrawnQuery);
    }
    
    /** D'tor */
    ~this()
    {
        glDeleteQueries(1, &mPrimitivesDrawnQuery);
    }
    
    /**
            Get the render operation for this buffer 
        */
    override void getRenderOperation(ref RenderOperation op)
    {
        op.operationType = mOperationType;
        op.useIndexes = false;
        op.vertexData = mVertexData;
    }
    
    /**
            Update the contents of this vertex buffer by rendering
        */
    override void update(ref SceneManager sceneMgr)
    {
        checkGLError(true, false, "start of GLRenderToVertexBuffer.update");
        debug(STDERR) std.stdio.stderr.writeln("GLRenderToVertexBuffer.update");
        
        size_t bufSize = mVertexData.vertexDeclaration.getVertexSize(0) * mMaxVertexCount;
        if (mVertexBuffers[0].isNull() || mVertexBuffers[0].get().getSizeInBytes() != bufSize)
        {
            //Buffers don't match. Need to reallocate.
            mResetRequested = true;
        }
        
        //Single pass only for now
        Pass r2vbPass = mMaterial.getAs().getBestTechnique().getPass(0);
        //Set pass before binding buffers to activate the GPU programs
        sceneMgr._setPass(r2vbPass);
        
        checkGLError(true, false);
        
        bindVerticesOutput(r2vbPass);
        
        RenderOperation renderOp;
        size_t targetBufferIndex;
        if (mResetRequested || mResetsEveryUpdate)
        {
            //Use source data to render to first buffer
            mSourceRenderable.getRenderOperation(renderOp);
            targetBufferIndex = 0;
        }
        else
        {
            //Use current front buffer to render to back buffer
            this.getRenderOperation(renderOp);
            targetBufferIndex = 1 - mFrontBufferIndex;
        }
        
        if (mVertexBuffers[targetBufferIndex].isNull() || 
            mVertexBuffers[targetBufferIndex].get().getSizeInBytes() != bufSize)
        {
            reallocateBuffer(targetBufferIndex);
        }
        
        GLHardwareVertexBuffer vertexBuffer = cast(GLHardwareVertexBuffer)(mVertexBuffers[targetBufferIndex].get());
        GLuint bufferId = vertexBuffer.getGLBufferId();
        
        //Bind the target buffer
        glBindBufferOffsetNV(GL_TRANSFORM_FEEDBACK_BUFFER_NV, 0, bufferId, 0);
        
        glBeginTransformFeedbackNV(getR2VBPrimitiveType(mOperationType));
        
        glEnable(GL_RASTERIZER_DISCARD_NV);    // disable rasterization
        
        glBeginQuery(GL_TRANSFORM_FEEDBACK_PRIMITIVES_WRITTEN_NV, mPrimitivesDrawnQuery);
        
        RenderSystem targetRenderSystem = Root.getSingleton().getRenderSystem();
        //Draw the object
        targetRenderSystem._setWorldMatrix(Matrix4.IDENTITY);
        targetRenderSystem._setViewMatrix(Matrix4.IDENTITY);
        targetRenderSystem._setProjectionMatrix(Matrix4.IDENTITY);
        if (r2vbPass.hasVertexProgram())
        {
            targetRenderSystem.bindGpuProgramParameters(GpuProgramType.GPT_VERTEX_PROGRAM, 
                                                         r2vbPass.getVertexProgramParameters(), GpuParamVariability.GPV_ALL);
        }
        if (r2vbPass.hasGeometryProgram())
        {
            targetRenderSystem.bindGpuProgramParameters(GpuProgramType.GPT_GEOMETRY_PROGRAM,
                                                        r2vbPass.getGeometryProgramParameters(), GpuParamVariability.GPV_ALL);
        }
        targetRenderSystem._render(renderOp);
        
        //Finish the query
        glEndQuery(GL_TRANSFORM_FEEDBACK_PRIMITIVES_WRITTEN_NV);
        glDisable(GL_RASTERIZER_DISCARD_NV);
        glEndTransformFeedbackNV();
        
        //read back query results
        GLuint primitivesWritten;
        glGetQueryObjectuiv(mPrimitivesDrawnQuery, GL_QUERY_RESULT, &primitivesWritten);
        mVertexData.vertexCount = primitivesWritten * getVertexCountPerPrimitive(mOperationType);
        
        checkGLError(true, true, "GLRenderToVertexBuffer.update");
        
        //Switch the vertex binding if necessary
        if (targetBufferIndex != mFrontBufferIndex)
        {
            mVertexData.vertexBufferBinding.unsetAllBindings();
            mVertexData.vertexBufferBinding.setBinding(0, mVertexBuffers[targetBufferIndex]);
            mFrontBufferIndex = targetBufferIndex;
        }
        
        glDisable(GL_RASTERIZER_DISCARD_NV);    // enable rasterization
        
        //Clear the reset flag
        mResetRequested = false;
    }
    
protected:
    void reallocateBuffer(size_t index)
    {
        assert(index == 0 || index == 1);
        if (!mVertexBuffers[index].isNull())
        {
            mVertexBuffers[index].setNull();
        }
        
        mVertexBuffers[index] = HardwareBufferManager.getSingleton().createVertexBuffer(
            mVertexData.vertexDeclaration.getVertexSize(0), mMaxVertexCount, 
//#if OGRE_DEBUG_MODE
//            //Allow to read the contents of the buffer in debug mode
//            HardwareBuffer::HBU_DYNAMIC
//#else
            HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY
//#endif
            );
    }
    
    void bindVerticesOutput(Pass pass)
    {
        VertexDeclaration declaration = mVertexData.vertexDeclaration;
        bool useVaryingAttributes = false;
        
        //Check if we are FixedFunc/ASM shaders (Static attributes) or GLSL (Varying attributes)
        //We assume that there isn't a mix of GLSL and ASM as this is illegal
        GpuProgram sampleProgram = null;
        if (pass.hasVertexProgram())
        {
            sampleProgram = pass.getVertexProgram().getAs();
        }
        else if (pass.hasGeometryProgram())
        {
            sampleProgram = pass.getGeometryProgram().getAs();
        }
        if ((sampleProgram !is null) && (sampleProgram.getLanguage() == "glsl"))
        {
            useVaryingAttributes = true;
        }
        
        if (useVaryingAttributes)
        {
            //Have GLSL shaders, using varying attributes
            GLSLLinkProgram linkProgram = GLSLLinkProgramManager.getSingleton().getActiveLinkProgram();
            GLuint linkProgramId = linkProgram.getGLHandle();
            
            ///FIXME Eff it, going with NV extensions
            // replaces glGetVaryingLocationNV ??????
            /*string[] varyingVars;
            {
                GLint varyingCount, maxlen;
                GLsizei varSize;
                GLenum varType;
                GetProgramiv (linkProgramId, TRANSFORM_FEEDBACK_VARYING_MAX_LENGTH_EXT, &maxlen);
                char[] buf;
                buf.length = maxlen+1;
                
                GetProgramiv (linkProgramId, TRANSFORM_FEEDBACK_VARYINGS_EXT, &varyingCount);
                foreach(GLuint idx; 0..varyingCount)
                {
                    glGetTransformFeedbackVaryingEXT(linkProgramId, idx, maxlen, null, &varSize, &varType, buf.ptr);
                    varyingVars ~= to!string(buf);//TODO test, seems to cut at '\0', but just in case maybe use length?
                }
            }*/
            
            
            GLint[] locations; //NV uses ints
            //char*[] locations; //ARB is strings
            for (ushort e=0; e < declaration.getElementCount(); e++)
            {
                const (VertexElement) element =declaration.getElement(e);
                string varyingName = getSemanticVaryingName(element.getSemantic(), element.getIndex());
                //FIXME glGetTransformFeedbackVaryingEXT?
                GLint location = glGetVaryingLocationNV(linkProgramId, CSTR(varyingName));
                
                /*char* location;
                foreach(i; 0..varyingVars.length) {
                    if(varyingVars[i] == varyingName) {
                        location = CSTR(varyingVars[i]); break;
                    }
                }*/
                
                if (location < 0)
                //if (location is null)
                {
                    throw new RenderingApiError( 
                                "GLSL link program does not output " ~ varyingName ~
                                " so it cannot fill the requested vertex buffer", 
                                "OgreGLRenderToVertexBuffer.bindVerticesOutput");
                }
                locations ~= location;
            }
            
            //NV version uses ints, ARB string array (?)
            glTransformFeedbackVaryingsNV(
                linkProgramId, cast(GLsizei)locations.length, 
                locations.ptr, GL_INTERLEAVED_ATTRIBS_NV);
        }
        else
        {
            //Either fixed function or assembly (CG = assembly) shaders
            GLint[] attribs;
            for (ushort e=0; e < declaration.getElementCount(); e++)
            {
                const (VertexElement) element = declaration.getElement(e);
                //Type
                attribs ~= getGLSemanticType(element.getSemantic());
                //Number of components
                attribs ~= VertexElement.getTypeCount(element.getType());
                //Index
                attribs ~= element.getIndex();
            }
            
            glTransformFeedbackAttribsNV(
                cast(GLuint)declaration.getElementCount(), 
                attribs.ptr, GL_INTERLEAVED_ATTRIBS_NV);
        }
        
        checkGLError(true, true, "GLRenderToVertexBuffer.bindVerticesOutput");
    }
    
    GLint getGLSemanticType(VertexElementSemantic semantic)
    {
        switch (semantic)
        {
            case VertexElementSemantic.VES_POSITION:
                return GL_POSITION;
            case VertexElementSemantic.VES_TEXTURE_COORDINATES:
                return GL_TEXTURE_COORD_NV;
            case VertexElementSemantic.VES_DIFFUSE:
                return GL_PRIMARY_COLOR;
            case VertexElementSemantic.VES_SPECULAR:
                return GL_SECONDARY_COLOR_NV;
                //TODO : Implement more?
            default:
                throw new RenderingApiError(
                            "Unsupported vertex element sematic in render to vertex buffer", 
                            "OgreGLRenderToVertexBuffer.getGLSemanticType");
                
        }
    }
    
    string getSemanticVaryingName(VertexElementSemantic semantic, ushort index)
    {
        switch (semantic)
        {
            case VertexElementSemantic.VES_POSITION:
                return "gl_Position";
            case VertexElementSemantic.VES_TEXTURE_COORDINATES:
                return text("gl_TexCoord[", index, "]");
            case VertexElementSemantic.VES_DIFFUSE:
                return "gl_FrontColor";
            case VertexElementSemantic.VES_SPECULAR:
                return "gl_FrontSecondaryColor";
                //TODO : Implement more?
            default:
                throw new RenderingApiError(
                            "Unsupported vertex element sematic in render to vertex buffer", 
                            "OgreGLRenderToVertexBuffer.getSemanticVaryingName");
        }
    }
    
    SharedPtr!HardwareVertexBuffer[2] mVertexBuffers;
    size_t mFrontBufferIndex;
    GLuint mPrimitivesDrawnQuery;
}