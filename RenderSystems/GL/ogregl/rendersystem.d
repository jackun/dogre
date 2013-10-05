module ogregl.rendersystem;

import core.sync.mutex;
import std.string: indexOf;
import std.conv: to;
debug import std.stdio;

import derelict.opengl3.gl; //Using old stuff

import ogre.compat;
import ogre.config;
import ogre.exception;
import ogre.general.colourvalue;
import ogre.general.common;
import ogre.general.log;
import ogre.materials.blendmode;
import ogre.materials.gpuprogram;
import ogre.materials.textureunitstate;
import ogre.math.angles;
import ogre.math.frustum;
import ogre.math.maths;
import ogre.math.matrix;
import ogre.math.plane;
import ogre.rendersystem.hardware;
import ogre.rendersystem.renderoperation;
import ogre.rendersystem.rendersystem;
import ogre.rendersystem.rendertarget;
import ogre.rendersystem.rendertexture;
import ogre.rendersystem.renderwindow;
import ogre.rendersystem.vertex;
import ogre.rendersystem.viewport;
import ogre.resources.highlevelgpuprogram;
import ogre.resources.texture;
import ogre.scene.light;
import ogre.strings;
import ogre.math.vector;
import ogre.resources.resourcemanager;
import ogre.resources.resource;

import ogregl.config;
import ogregl.context;
import ogregl.compat;
import ogregl.glew;
import ogregl.glsl.programfactory;
import ogregl.gpuprogram;
import ogregl.gpuprogrammanager;
import ogregl.rendertexture;
import ogregl.support;
import ogregl.depthbuffer;
import ogregl.framebufferobject;
import ogregl.hardwareocclusionquery;
import ogregl.hardwarebuffermanager;
import ogregl.defaulthardwarebuffermanager;
import ogregl.hardwareindexbuffer;
import ogregl.hardwarepixelbuffer;
import ogregl.hardwarevertexbuffer;
import ogregl.texturemanager;
import ogregl.texture;
import ogregl.fborendertexture;
import ogregl.pbrendertexture;

static if(USE_SDL)
{
    pragma(msg, "Using SDL for GLSupport.");
    import ogregl.sdl.support;
    GLSupport getGLSupport()
    {
        return new SDLGLSupport();
    }
}
else static if(USE_GLX)
{
    pragma(msg, "Using GLX for GLSupport.");
    import ogregl.glx.support;
    GLSupport getGLSupport()
    {
        return new GLXGLSupport();
    }
}
else static if(USE_WIN32)
{
    pragma(msg, "Using WGL for GLSupport.");
    import ogregl.windows.support;
    GLSupport getGLSupport()
    {
        return new Win32GLSupport();
    }
}
else static if(USE_OSX)
{
    //FIXME I don't have a mac so this is left as exercise for the reader
    pragma(msg, "Using OSXGL for GLSupport.");
    GLSupport getGLSupport()
    {
        return new OSXGLSupport();
    }
}

ubyte* VBO_BUFFER_OFFSET(size_t i) { return (cast(ubyte *)0) + i;}


// Callback function used when registering GLGpuPrograms
GpuProgram createGLArbGpuProgram(ResourceManager creator, 
                                  string name, ResourceHandle handle, 
                                  string group, bool isManual, ManualResourceLoader loader,
                                  GpuProgramType gptype, string syntaxCode)
{
    GLArbGpuProgram ret = new GLArbGpuProgram(
        creator, name, handle, group, isManual, loader);
    ret.setType(gptype);
    ret.setSyntaxCode(syntaxCode);
    return ret;
}

GpuProgram createGLGpuNvparseProgram(ResourceManager creator, 
                                      string name, ResourceHandle handle, 
                                      string group, bool isManual, ManualResourceLoader loader,
                                      GpuProgramType gptype, string syntaxCode)
{
    /*GLGpuNvparseProgram ret = new GLGpuNvparseProgram(
        creator, name, handle, group, isManual, loader);
    ret.setType(gptype);
    ret.setSyntaxCode(syntaxCode);
    return ret;*/
    return null;
}

GpuProgram createGL_ATI_FS_GpuProgram(ResourceManager creator, 
                                       string name, ResourceHandle handle, 
                                       string group, bool isManual, ManualResourceLoader loader,
                                       GpuProgramType gptype, string syntaxCode)
{
    
    /*ATI_FS_GLGpuProgram ret = new ATI_FS_GLGpuProgram(
        creator, name, handle, group, isManual, loader);
    ret.setType(gptype);
    ret.setSyntaxCode(syntaxCode);
    return ret;*/
    return null;
}

/**
      Implementation of GL as a rendering system.
     */
package class GLRenderSystem : RenderSystem
{
private:
    /// Rendering loop control
    bool mStopRendering;
    
    /** Array of up to 8 lights, indexed as per API
            Note that a null value indicates a free slot
          */ 
    enum MAX_LIGHTS = 8;
    Light[MAX_LIGHTS] mLights;
    
    /// View matrix to set world against
    Matrix4 mViewMatrix;
    Matrix4 mWorldMatrix;
    Matrix4 mTextureMatrix;
    
    /// Last min & mip filtering options, so we can combine them
    FilterOptions mMinFilter;
    FilterOptions mMipFilter;
    
    /// What texture coord set each texture unit is using
    size_t[OGRE_MAX_TEXTURE_LAYERS] mTextureCoordIndex;
    
    /// Holds texture type settings for every stage
    GLenum[OGRE_MAX_TEXTURE_LAYERS] mTextureTypes;
    
    /// Number of fixed-function texture units
    ushort mFixedFunctionTextureUnits;
    
    void initConfigOptions()
    {
        mGLSupport.addConfig();
    }

    //TODO wtf?
    void initInputDevices();
    //TODO wtf?
    void processInputDevices();
    
    void setGLLight(size_t index, Light lt)
    {
        GLenum gl_index = cast(GLenum)(GL_LIGHT0 + index);
        
        if (!lt)
        {
            // Disable in the scene
            glDisable(gl_index);
        }
        else
        {
            switch (lt.getType())
            {
                case Light.LightTypes.LT_SPOTLIGHT:
                    glLightf( gl_index, GL_SPOT_CUTOFF, 0.5f * lt.getSpotlightOuterAngle().valueDegrees() );
                    glLightf(gl_index, GL_SPOT_EXPONENT, lt.getSpotlightFalloff());
                    break;
                default:
                    glLightf( gl_index, GL_SPOT_CUTOFF, 180.0 );
                    break;
            }
            
            // Color
            ColourValue col = lt.getDiffuseColour();
            
            GLfloat[4] f4vals = [col.r, col.g, col.b, col.a];
            glLightfv(gl_index, GL_DIFFUSE, f4vals.ptr);
            
            col = lt.getSpecularColour();
            f4vals[0] = col.r;
            f4vals[1] = col.g;
            f4vals[2] = col.b;
            f4vals[3] = col.a;
            glLightfv(gl_index, GL_SPECULAR, f4vals.ptr);
            
            
            // Disable ambient light for movables;
            f4vals[0] = 0;
            f4vals[1] = 0;
            f4vals[2] = 0;
            f4vals[3] = 1;
            glLightfv(gl_index, GL_AMBIENT, f4vals.ptr);
            
            setGLLightPositionDirection(lt, gl_index);
            
            
            // Attenuation
            glLightf(gl_index, GL_CONSTANT_ATTENUATION, lt.getAttenuationConstant());
            glLightf(gl_index, GL_LINEAR_ATTENUATION, lt.getAttenuationLinear());
            glLightf(gl_index, GL_QUADRATIC_ATTENUATION, lt.getAttenuationQuadric());
            // Enable in the scene
            glEnable(gl_index);
            
        }
    }

    void makeGLMatrix(ref GLfloat[16] gl_matrix, const(Matrix4) m)
    {
        size_t x = 0;
        for (size_t i = 0; i < 4; i++)
        {
            for (size_t j = 0; j < 4; j++)
            {
                gl_matrix[x] = m[j, i];
                x++;
            }
        }
    }
    
    GLint getBlendMode(SceneBlendFactor ogreBlend) const
    {
        switch(ogreBlend)
        {
            case SceneBlendFactor.SBF_ONE:
                return derelict.opengl3.deprecatedConstants.GL_ONE;
            case SceneBlendFactor.SBF_ZERO:
                return derelict.opengl3.deprecatedConstants.GL_ZERO;
            case SceneBlendFactor.SBF_DEST_COLOUR:
                return GL_DST_COLOR;
            case SceneBlendFactor.SBF_SOURCE_COLOUR:
                return GL_SRC_COLOR;
            case SceneBlendFactor.SBF_ONE_MINUS_DEST_COLOUR:
                return GL_ONE_MINUS_DST_COLOR;
            case SceneBlendFactor.SBF_ONE_MINUS_SOURCE_COLOUR:
                return GL_ONE_MINUS_SRC_COLOR;
            case SceneBlendFactor.SBF_DEST_ALPHA:
                return GL_DST_ALPHA;
            case SceneBlendFactor.SBF_SOURCE_ALPHA:
                return GL_SRC_ALPHA;
            case SceneBlendFactor.SBF_ONE_MINUS_DEST_ALPHA:
                return GL_ONE_MINUS_DST_ALPHA;
            case SceneBlendFactor.SBF_ONE_MINUS_SOURCE_ALPHA:
                return GL_ONE_MINUS_SRC_ALPHA;
            default:
                break;
        }
        // to keep compiler happy
        return derelict.opengl3.deprecatedConstants.GL_ONE;
    }

    GLint getTextureAddressingMode(TextureUnitState.TextureAddressingMode tam) const
    {
        switch(tam)
        {
            default:
            case TextureUnitState.TAM_WRAP:
                return GL_REPEAT;
            case TextureUnitState.TAM_MIRROR:
                return GL_MIRRORED_REPEAT;
            case TextureUnitState.TAM_CLAMP:
                return GL_CLAMP_TO_EDGE;
            case TextureUnitState.TAM_BORDER:
                return GL_CLAMP_TO_BORDER;
        }
        
    }

    void initialiseContext(RenderWindow primary)
    {
        // Set main and current context
        mMainContext = null;
        primary.getCustomAttribute(GLRenderTexture.CustomAttributeString_GLCONTEXT, &mMainContext);
        mCurrentContext = mMainContext;
        
        // Set primary context as active
        if(mCurrentContext)
            mCurrentContext.setCurrent();
        
        // Setup GLSupport
        mGLSupport.initialiseExtensions();
        
        LogManager.getSingleton().logMessage("***************************");
        LogManager.getSingleton().logMessage("*** GL Renderer Started ***");
        LogManager.getSingleton().logMessage("***************************");
        
        // Get extension function pointers
        //static if (OGRE_THREAD_SUPPORT != 1)
            //glewContextInit(mGLSupport);//FIXME glewContextInit missing
            //glxewContextInit();
    }
    
    void setLights()
    {
        for (size_t i = 0; i < mLights.length; ++i)
        {
            if (mLights[i] !is null)
            {
                Light lt = mLights[i];
                setGLLightPositionDirection(lt, cast(GLenum)(GL_LIGHT0 + i));
            }
        }
    }
    
    /// Store last depth write state
    bool mDepthWrite;
    /// Store last stencil mask state
    uint mStencilWriteMask;
    /// Store last colour write state
    bool[4] mColourWrite;
    
    GLenum convertCompareFunction(CompareFunction func) const
    {
        final switch(func)
        {
            case CompareFunction.CMPF_ALWAYS_FAIL:
                return GL_NEVER;
            case CompareFunction.CMPF_ALWAYS_PASS:
                return GL_ALWAYS;
            case CompareFunction.CMPF_LESS:
                return GL_LESS;
            case CompareFunction.CMPF_LESS_EQUAL:
                return GL_LEQUAL;
            case CompareFunction.CMPF_EQUAL:
                return GL_EQUAL;
            case CompareFunction.CMPF_NOT_EQUAL:
                return GL_NOTEQUAL;
            case CompareFunction.CMPF_GREATER_EQUAL:
                return GL_GEQUAL;
            case CompareFunction.CMPF_GREATER:
                return GL_GREATER;
        }
        // to keep compiler happy
        return GL_ALWAYS;
    }

    GLenum convertStencilOp(StencilOperation op, bool invert = false) const
    {
        final switch(op)
        {
            case StencilOperation.SOP_KEEP:
                return GL_KEEP;
            case StencilOperation.SOP_ZERO:
                return derelict.opengl3.deprecatedConstants.GL_ZERO;
            case StencilOperation.SOP_REPLACE:
                return GL_REPLACE;
            case StencilOperation.SOP_INCREMENT:
                return invert ? GL_DECR : GL_INCR;
            case StencilOperation.SOP_DECREMENT:
                return invert ? GL_INCR : GL_DECR;
            case StencilOperation.SOP_INCREMENT_WRAP:
                return invert ? GL_DECR_WRAP : GL_INCR_WRAP;
            case StencilOperation.SOP_DECREMENT_WRAP:
                return invert ? GL_INCR_WRAP : GL_DECR_WRAP;
            case StencilOperation.SOP_INVERT:
                return GL_INVERT;
        }
        // to keep compiler happy
        return GL_KEEP;
    }
    
    /// Internal method for anisotropy validation
    GLfloat _getCurrentAnisotropy(size_t unit)
    {
        GLfloat curAniso = 0;
        glGetTexParameterfv(mTextureTypes[unit], 
                            GL_TEXTURE_MAX_ANISOTROPY_EXT, &curAniso);
        return curAniso ? curAniso : 1;
    }
    
    /// GL support class, used for creating windows etc.
    GLSupport mGLSupport;
    
    /// Internal method to set pos / direction of a light
    void setGLLightPositionDirection(Light lt, GLenum lightindex)
    {
        // Set position / direction
        Vector4 vec;
        // Use general 4D vector which is the same as GL's approach
        vec = lt.getAs4DVector(true);
        
        static if (OGRE_DOUBLE_PRECISION)
        {
            // Must convert to float*
            float[4] tmp = [vec.x, vec.y, vec.z, vec.w];
            glLightfv(lightindex, GL_POSITION, tmp.ptr);
        }
        else
            glLightfv(lightindex, GL_POSITION, vec.ptr());

        // Set spotlight direction
        if (lt.getType() == Light.LightTypes.LT_SPOTLIGHT)
        {
            vec = lt.getDerivedDirection();
            vec.w = 0.0; 
            static if (OGRE_DOUBLE_PRECISION)
            {
                // TODO Must convert to float*
                float[4] tmp2 = [vec.x, vec.y, vec.z, vec.w];
                glLightfv(lightindex, GL_SPOT_DIRECTION, tmp2.ptr);
            }
            else
                glLightfv(lightindex, GL_SPOT_DIRECTION, vec.ptr());
        }
    }
    
    bool mUseAutoTextureMatrix;
    GLfloat[16] mAutoTextureMatrix;
    
    /// Check if the GL system has already been initialised
    bool mGLInitialised;
    
    HardwareBufferManager mHardwareBufferManager;
    GLGpuProgramManager mGpuProgramManager;
    GLSLProgramFactory mGLSLProgramFactory;
    
    ushort mCurrentLights;
    
    GLuint getCombinedMinMipFilter() const
    {
        final switch(mMinFilter)
        {
            case FilterOptions.FO_ANISOTROPIC:
            case FilterOptions.FO_LINEAR:
                switch(mMipFilter)
                {
                    case FilterOptions.FO_ANISOTROPIC:
                    case FilterOptions.FO_LINEAR:
                        // linear min, linear mip
                        return GL_LINEAR_MIPMAP_LINEAR;
                    case FilterOptions.FO_POINT:
                        // linear min, point mip
                        return GL_LINEAR_MIPMAP_NEAREST;
                    case FilterOptions.FO_NONE:
                        // linear min, no mip
                        return GL_LINEAR;
                    default:
                        break;
                }
                break;
            case FilterOptions.FO_POINT:
            case FilterOptions.FO_NONE:
                switch(mMipFilter)
                {
                    case FilterOptions.FO_ANISOTROPIC:
                    case FilterOptions.FO_LINEAR:
                        // nearest min, linear mip
                        return GL_NEAREST_MIPMAP_LINEAR;
                    case FilterOptions.FO_POINT:
                        // nearest min, point mip
                        return GL_NEAREST_MIPMAP_NEAREST;
                    case FilterOptions.FO_NONE:
                        // nearest min, no mip
                        return GL_NEAREST;
                    default:
                        break;
                }
                break;
        }
        
        // should never get here
        return 0;
        
    }
    
    GLGpuProgram mCurrentVertexProgram;
    GLGpuProgram mCurrentFragmentProgram;
    GLGpuProgram mCurrentGeometryProgram;
    
    /* The main GL context - main thread only */
    GLContext mMainContext;
    /* The current GL context  - main thread only */
    GLContext mCurrentContext;
    //typedef list<GLContext*>::type GLContextList;
    alias GLContext[] GLContextList;
    /// List of background thread contexts
    GLContext[] mBackgroundContextList;
    
    /** Manager object for creating render textures.
            Direct render to texture via GL_EXT_framebuffer_object is preferable 
            to pbuffers, which depend on the GL support used and are generally 
            unwieldy and slow. However, FBO support for stencil buffers is poor.
        */
    GLRTTManager mRTTManager;
    
    ushort mActiveTextureUnit;
    
    // local data members of _render that were moved here to improve performance
    // (save allocations)
    //vector<GLuint>::type mRenderAttribsBound;
    //vector<GLuint>::type mRenderInstanceAttribsBound;
    GLuint[] mRenderAttribsBound;
    GLuint[] mRenderInstanceAttribsBound;
    
    
protected:
    override void setClipPlanesImpl(const (PlaneList) clipPlanes)
    {
        // A note on GL user clipping:
        // When an ARB vertex program is enabled in GL, user clipping is completely
        // disabled. There is no way around this, it's just turned off.
        // When using GLSL, user clipping can work but you have to include a 
        // glClipVertex command in your vertex shader. 
        // Thus the planes set here may not actually be respected.
        
        
        size_t i = 0;
        size_t numClipPlanes;
        GLdouble[4] clipPlane;
        
        // Save previous modelview
        glMatrixMode(GL_MODELVIEW);
        glPushMatrix();
        // just load view matrix (identity world)
        GLfloat[16] mat;
        makeGLMatrix(mat, mViewMatrix);
        glLoadMatrixf(mat.ptr);
        
        numClipPlanes = clipPlanes.length;
        for (i = 0; i < numClipPlanes; ++i)
        {
            GLenum clipPlaneId = cast(GLenum)(GL_CLIP_DISTANCE0 + i);
            const Plane plane = clipPlanes[i];
            
            if (i >= 6/*GL_MAX_CLIP_PLANES*/)
            {
                throw new RenderingApiError("Unable to set clip plane", 
                            "GLRenderSystem.setClipPlanes");
            }

            clipPlane[0] = plane.normal.x;
            clipPlane[1] = plane.normal.y;
            clipPlane[2] = plane.normal.z;
            clipPlane[3] = plane.d;
            
            glClipPlane(clipPlaneId, clipPlane.ptr);
            glEnable(clipPlaneId);
        }
        
        // disable remaining clip planes
        for ( ; i < 6/*GL_MAX_CLIP_PLANES*/; ++i)
        {
            glDisable(cast(GLenum)(GL_CLIP_DISTANCE0 + i));
        }
        
        // restore matrices
        glPopMatrix();
    }

    bool activateGLTextureUnit(size_t unit)
    {
        if (mActiveTextureUnit != unit)
        {
            if (GLEW_VERSION_1_2 && unit < getCapabilities().getNumTextureUnits())
            {
                glActiveTexture(cast(GLenum)(GL_TEXTURE0 + unit));
                mActiveTextureUnit = cast(ushort)unit;
                return true;
            }
            else if (!unit)
            {
                // always ok to use the first unit
                return true;
            }
            else
            {
                return false;
            }
        }
        else
        {
            return true;
        }
    }

    void bindVertexElementToGpu( const (VertexElement) elem, 
                                SharedPtr!HardwareVertexBuffer vertexBuffer, const size_t vertexStart,
                                GLuint[] attribsBound, 
                                GLuint[] instanceAttribsBound )
    {
        void* pBufferData = null;
        GLHardwareVertexBuffer hwGlBuffer = cast(GLHardwareVertexBuffer)(vertexBuffer.get()); 
        
        if(mCurrentCapabilities.hasCapability(Capabilities.RSC_VBO))
        {
            glBindBuffer(GL_ARRAY_BUFFER, hwGlBuffer.getGLBufferId());
            pBufferData = VBO_BUFFER_OFFSET(elem.getOffset());
        }
        else
        {
            pBufferData = (cast(GLDefaultHardwareVertexBuffer)vertexBuffer.get()).getDataPtr(elem.getOffset());
        }
        if (vertexStart)
        {
            pBufferData = (cast(ubyte*)pBufferData) + vertexStart * vertexBuffer.get().getVertexSize();
        }
        
        VertexElementSemantic sem = elem.getSemantic();
        bool multitexturing = (getCapabilities().getNumTextureUnits() > 1);
        
        bool isCustomAttrib = false;
        if (mCurrentVertexProgram)
        {
            isCustomAttrib = mCurrentVertexProgram.isAttributeValid(sem, elem.getIndex());
            
            if (hwGlBuffer.getIsInstanceData())
            {
                GLuint attrib = mCurrentVertexProgram.getAttributeIndex(sem, elem.getIndex());
                glVertexAttribDivisor(attrib, cast(GLuint)hwGlBuffer.getInstanceDataStepRate() );
                instanceAttribsBound.insert(attrib);
            }
        }
        
        debug(STDERR) std.stdio.stderr.writeln("GLRenderSystem.bindVertexElementToGpu: Custom:", isCustomAttrib,
                                       " VPrg: ", mCurrentVertexProgram, " Sem: ", sem);
        // Custom attribute support
        // tangents, binormals, blendweights etc always via this route
        // builtins may be done this way too
        if (isCustomAttrib)
        {
            GLuint attrib = mCurrentVertexProgram.getAttributeIndex(sem, elem.getIndex());
            ushort typeCount = VertexElement.getTypeCount(elem.getType());
            GLboolean normalised = GL_FALSE;
            switch(elem.getType())
            {
                case VertexElementType.VET_COLOUR:
                case VertexElementType.VET_COLOUR_ABGR:
                case VertexElementType.VET_COLOUR_ARGB:
                    // Because GL takes these as a sequence of single unsigned bytes, count needs to be 4
                    // VertexElement::getTypeCount treats them as 1 (RGBA)
                    // Also need to normalise the fixed-point data
                    typeCount = 4;
                    normalised = GL_TRUE;
                    break;
                default:
                    break;
            }
            
            glVertexAttribPointer(
                attrib,
                typeCount, 
                GLHardwareBufferManager.getGLType(elem.getType()), 
                normalised, 
                cast(GLsizei)(vertexBuffer.get().getVertexSize()), 
                pBufferData);
            glEnableVertexAttribArray(attrib);
            
            attribsBound.insert(attrib);
        }
        else
        {
            // fixed-function & builtin attribute support
            switch(sem)
            {
                case VertexElementSemantic.VES_POSITION:
                    glVertexPointer(VertexElement.getTypeCount(
                    elem.getType()), 
                                    GLHardwareBufferManager.getGLType(elem.getType()), 
                                    cast(GLsizei)(vertexBuffer.get().getVertexSize()), 
                                    pBufferData);
                    glEnableClientState( GL_VERTEX_ARRAY );
                    break;
                case VertexElementSemantic.VES_NORMAL:
                    glNormalPointer(
                        GLHardwareBufferManager.getGLType(elem.getType()), 
                        cast(GLsizei)(vertexBuffer.get().getVertexSize()), 
                        pBufferData);
                    glEnableClientState( GL_NORMAL_ARRAY );
                    break;
                case VertexElementSemantic.VES_DIFFUSE:
                    glColorPointer(4, 
                                   GLHardwareBufferManager.getGLType(elem.getType()), 
                                   cast(GLsizei)(vertexBuffer.get().getVertexSize()), 
                                   pBufferData);
                    glEnableClientState( GL_COLOR_ARRAY );
                    break;
                case VertexElementSemantic.VES_SPECULAR:
                    if (EXT_secondary_color)
                    {
                        glSecondaryColorPointer(4, 
                                                   GLHardwareBufferManager.getGLType(elem.getType()), 
                                                   cast(GLsizei)(vertexBuffer.get().getVertexSize()), 
                                                   pBufferData);
                        glEnableClientState( GL_SECONDARY_COLOR_ARRAY );
                    }
                    break;
                case VertexElementSemantic.VES_TEXTURE_COORDINATES:
                    
                    if (mCurrentVertexProgram)
                    {
                        // Programmable pipeline - direct UV assignment
                        glClientActiveTexture(GL_TEXTURE0 + elem.getIndex());
                        glTexCoordPointer(
                            VertexElement.getTypeCount(elem.getType()), 
                            GLHardwareBufferManager.getGLType(elem.getType()),
                            cast(GLsizei)(vertexBuffer.get().getVertexSize()), 
                            pBufferData);
                        glEnableClientState( GL_TEXTURE_COORD_ARRAY );
                    }
                    else
                    {
                        // fixed function matching to units based on tex_coord_set
                        for (uint i = 0; i < mDisabledTexUnitsFrom; i++)
                        {
                            // Only set this texture unit's texcoord pointer if it
                            // is supposed to be using this element's index
                            if (mTextureCoordIndex[i] == elem.getIndex() && i < mFixedFunctionTextureUnits)
                            {
                                if (multitexturing)
                                    glClientActiveTexture(GL_TEXTURE0 + i);
                                glTexCoordPointer(
                                    VertexElement.getTypeCount(elem.getType()), 
                                    GLHardwareBufferManager.getGLType(elem.getType()),
                                    cast(GLsizei)(vertexBuffer.get().getVertexSize()), 
                                    pBufferData);
                                glEnableClientState( GL_TEXTURE_COORD_ARRAY );
                            }
                        }
                    }
                    break;
                default:
                    break;
            }
        } // isCustomAttrib
    }

public:
    // Default constructor / destructor
    this()
    {
        DerelictGL.load();
        mThreadInitMutex = new Mutex;
        mDepthWrite = true;
        mStencilWriteMask = 0xFFFFFFFF;
        mActiveTextureUnit = 0;
        //mHardwareBufferManager = null;
        //mGpuProgramManager = null;
        //mGLSLProgramFactory = null;
        //mRTTManager = null;


        size_t i;
        
        LogManager.getSingleton().logMessage(getName() ~ " created.");
        
        //mRenderAttribsBound.reserve(100);
        //mRenderInstanceAttribsBound.reserve(100);
        
        // Get our GLSupport
        mGLSupport = getGLSupport();
        
        //for( i=0; i<MAX_LIGHTS; i++ )
        //    mLights[i] = null;
        
        mWorldMatrix = Matrix4.IDENTITY;
        mViewMatrix = Matrix4.IDENTITY;
        
        initConfigOptions();
        
        mColourWrite[0] = mColourWrite[1] = mColourWrite[2] = mColourWrite[3] = true;
        
        for (i = 0; i < OGRE_MAX_TEXTURE_LAYERS; i++)
        {
            // Dummy value
            mTextureCoordIndex[i] = 99;
            mTextureTypes[i] = 0;
        }
        
        //mActiveRenderTarget = 0;
        //mCurrentContext = 0;
        //mMainContext = 0;
        
        mGLInitialised = false;
        
        mCurrentLights = 0;
        mMinFilter = FilterOptions.FO_LINEAR;
        mMipFilter = FilterOptions.FO_POINT;
        //mCurrentVertexProgram = 0;
        //mCurrentGeometryProgram = 0;
        //mCurrentFragmentProgram = 0;
        
    }

    ~this()
    {
        shutdown();
        
        // Destroy render windows
        foreach (k,v; mRenderTargets)
        {
            destroy(v);
        }
        mRenderTargets.clear();
        
        if(mGLSupport !is null)
            destroy(mGLSupport);
        mGLSupport = null;
    }
    
    // ----------------------------------
    // Overridden RenderSystem functions
    // ----------------------------------
    /** See
          RenderSystem
         */
    override string getName() const
    {
        static string strName = "OpenGL Rendering Subsystem";
        return strName;
    }
    /** See
          RenderSystem
         */
    override ConfigOptionMap getConfigOptions()
    {
        return mGLSupport.getConfigOptions();
    }
    /** See
          RenderSystem
         */
    override void setConfigOption(string name, string value)
    {
        mGLSupport.setConfigOption(name, value);
    }

    /** See
          RenderSystem
         */
    override string validateConfigOptions()
    {
        // XXX Return an error string if something is invalid
        return mGLSupport.validateConfig();
    }
    /** See
          RenderSystem
         */
    override RenderWindow _initialise(bool autoCreateWindow, string windowTitle = "OGRE Render Window")
    {
        mGLSupport.start();
        
        // Create the texture manager
        mTextureManager = GLTextureManager.getSingletonInit!(GLTextureManager)(&mGLSupport);
        
        RenderWindow autoWindow = mGLSupport.createWindow(autoCreateWindow, this, windowTitle);
        
        RenderSystem._initialise(autoCreateWindow, windowTitle);
        
        return autoWindow;
    }

    /** See
          RenderSystem
         */
    override RenderSystemCapabilities createRenderSystemCapabilities()// const
    {
        RenderSystemCapabilities rsc = new RenderSystemCapabilities();
        
        rsc.setCategoryRelevant(CapabilitiesCategory.CAPS_CATEGORY_GL, true);
        rsc.setDriverVersion(mDriverVersion);
        string deviceName = std.conv.to!string(glGetString(GL_RENDERER));
        string vendorName = std.conv.to!string(glGetString(GL_VENDOR));
        rsc.setDeviceName(deviceName);
        rsc.setRenderSystemName(getName());
        
        // determine vendor
        if (vendorName.indexOf("NVIDIA")>-1)
            rsc.setVendor(GPUVendor.GPU_NVIDIA);
        else if (vendorName.indexOf("ATI")>-1)
            rsc.setVendor(GPUVendor.GPU_AMD);
        else if (vendorName.indexOf("AMD")>-1)
            rsc.setVendor(GPUVendor.GPU_AMD);
        else if (vendorName.indexOf("Intel")>-1)
            rsc.setVendor(GPUVendor.GPU_INTEL);
        else if (vendorName.indexOf("S3")>-1)
            rsc.setVendor(GPUVendor.GPU_S3);
        else if (vendorName.indexOf("Matrox")>-1)
            rsc.setVendor(GPUVendor.GPU_MATROX);
        else if (vendorName.indexOf("3DLabs")>-1)
            rsc.setVendor(GPUVendor.GPU_3DLABS);
        else if (vendorName.indexOf("SiS")>-1)
            rsc.setVendor(GPUVendor.GPU_SIS);
        else
            rsc.setVendor(GPUVendor.GPU_UNKNOWN);
        
        static if (RTSHADER_SYSTEM_BUILD_CORE_SHADERS)
        {
            if(mEnableFixedPipeline)
            {
                // Supports fixed-function
                rsc.setCapability(Capabilities.RSC_FIXED_FUNCTION);
            }
        }   
        else
            rsc.setCapability(Capabilities.RSC_FIXED_FUNCTION);

        // Check for hardware mipmapping support.
        if(GLEW_VERSION_1_4)// || GLEW_SGIS_generate_mipmap)//TODO Secretly assume that GLEW_SGIS_generate_mipmap==true
        {
            bool disableAutoMip = false;
            bool DisableMipmapsPlat = false;//TODO Ugly

            //#if OGRE_PLATFORM == OGRE_PLATFORM_APPLE || OGRE_PLATFORM == OGRE_PLATFORM_LINUX
            version(linux)
                DisableMipmapsPlat = true;
            version(OSX)
                DisableMipmapsPlat = true;

            if(DisableMipmapsPlat)
            {
                // Apple & Linux ATI drivers have faults in hardware mipmap generation
                if (rsc.getVendor() == GPUVendor.GPU_AMD)
                    disableAutoMip = true;
            }
            // The Intel 915G frequently corrupts textures when using hardware mip generation
            // I'm not currently sure how many generations of hardware this affects, 
            // so for now, be safe.
            if (rsc.getVendor() == GPUVendor.GPU_INTEL)
                disableAutoMip = true;
            
            // SiS chipsets also seem to have problems with this
            if (rsc.getVendor() == GPUVendor.GPU_SIS)
                disableAutoMip = true;
            
            if (!disableAutoMip)
                rsc.setCapability(Capabilities.RSC_AUTOMIPMAP);
        }
        
        // Check for blending support
        if(GLEW_VERSION_1_3 || 
           ARB_texture_env_combine || 
           EXT_texture_env_combine)
        {
            rsc.setCapability(Capabilities.RSC_BLENDING);
        }
        
        // Check for Multitexturing support and set number of texture units
        if(GLEW_VERSION_1_3 || 
           ARB_multitexture)
        {
            GLint units;
            glGetIntegerv( GL_MAX_TEXTURE_UNITS, &units );

            //FIXME But enum GL_MAX_TEXTURE_IMAGE_UNITS_ARB == GL_MAX_TEXTURE_IMAGE_UNITS == GL_MAX_TEXTURE_IMAGE_UNITS_NV...
            /*if (ARB_fragment_program)
            {
                // Also check GL_MAX_TEXTURE_IMAGE_UNITS_ARB since NV at least
                // only increased this on the FX/6x00 series
                GLint arbUnits;
                glGetIntegerv( GL_MAX_TEXTURE_IMAGE_UNITS_ARB, &arbUnits );
                if (arbUnits > units)
                    units = arbUnits;
            }*/
            rsc.setNumTextureUnits(cast(ushort)units);
        }
        else
        {
            // If no multitexture support then set one texture unit
            rsc.setNumTextureUnits(1);
        }
        
        // Check for Anisotropy support
        if(EXT_texture_filter_anisotropic)
        {
            rsc.setCapability(Capabilities.RSC_ANISOTROPY);
        }
        
        // Check for DOT3 support
        if(GLEW_VERSION_1_3 ||
           ARB_texture_env_dot3 ||
           EXT_texture_env_dot3)
        {
            rsc.setCapability(Capabilities.RSC_DOT3);
        }
        
        // Check for cube mapping
        if(GLEW_VERSION_1_3 || 
           ARB_texture_cube_map ||
           EXT_texture_cube_map)
        {
            rsc.setCapability(Capabilities.RSC_CUBEMAPPING);
        }
        
        
        // Point sprites
        if (GLEW_VERSION_2_0 || ARB_point_sprite)
        {
            rsc.setCapability(Capabilities.RSC_POINT_SPRITES);
        }
        // Check for point parameters
        if (GLEW_VERSION_1_4)
        {
            rsc.setCapability(Capabilities.RSC_POINT_EXTENDED_PARAMETERS);
        }
        if (ARB_point_parameters)
        {
            rsc.setCapability(Capabilities.RSC_POINT_EXTENDED_PARAMETERS_ARB);
        }
        if (EXT_point_parameters)
        {
            rsc.setCapability(Capabilities.RSC_POINT_EXTENDED_PARAMETERS_EXT);
        }
        
        // Check for hardware stencil support and set bit depth
        GLint stencil;
        glGetIntegerv(GL_STENCIL_BITS,&stencil);
        
        if(stencil)
        {
            rsc.setCapability(Capabilities.RSC_HWSTENCIL);
            rsc.setStencilBufferBitDepth(cast(ushort)stencil);
        }
        
        
        if(GLEW_VERSION_1_5 || ARB_vertex_buffer_object)
        {
            if (!ARB_vertex_buffer_object)
            {
                rsc.setCapability(Capabilities.RSC_GL1_5_NOVBO);
            }
            rsc.setCapability(Capabilities.RSC_VBO);
        }
        
        if(ARB_vertex_program)
        {
            rsc.setCapability(Capabilities.RSC_VERTEX_PROGRAM);
            
            // Vertex Program Properties
            rsc.setVertexProgramConstantBoolCount(0);
            rsc.setVertexProgramConstantIntCount(0);
            
            GLint floatConstantCount;
            glGetProgramivARB(GL_VERTEX_PROGRAM_ARB, GL_MAX_PROGRAM_LOCAL_PARAMETERS_ARB, &floatConstantCount);
            rsc.setVertexProgramConstantFloatCount(cast(ushort)floatConstantCount);
            
            rsc.addShaderProfile("arbvp1");
            if (NV_vertex_program2_option)
            {
                rsc.addShaderProfile("vp30");
            }
            
            if (NV_vertex_program3)
            {
                rsc.addShaderProfile("vp40");
            }
            
            if (NV_vertex_program4)
            {
                rsc.addShaderProfile("gp4vp");
                rsc.addShaderProfile("gpu_vp");
            }
        }
        
        if (NV_register_combiners2 &&
            NV_texture_shader)
        {
            rsc.setCapability(Capabilities.RSC_FRAGMENT_PROGRAM);
            rsc.addShaderProfile("fp20");
        }
        
        // NFZ - check for ATI fragment shader support
        if (ATI_fragment_shader)
        {
            rsc.setCapability(Capabilities.RSC_FRAGMENT_PROGRAM);
            // no boolean params allowed
            rsc.setFragmentProgramConstantBoolCount(0);
            // no integer params allowed
            rsc.setFragmentProgramConstantIntCount(0);
            
            // only 8 Vector4 constant floats supported
            rsc.setFragmentProgramConstantFloatCount(8);
            
            rsc.addShaderProfile("ps_1_4");
            rsc.addShaderProfile("ps_1_3");
            rsc.addShaderProfile("ps_1_2");
            rsc.addShaderProfile("ps_1_1");
        }
        
        if (ARB_fragment_program)
        {
            rsc.setCapability(Capabilities.RSC_FRAGMENT_PROGRAM);
            
            // Fragment Program Properties
            rsc.setFragmentProgramConstantBoolCount(0);
            rsc.setFragmentProgramConstantIntCount(0);
            
            GLint floatConstantCount;
            glGetProgramivARB(GL_FRAGMENT_PROGRAM, GL_MAX_PROGRAM_LOCAL_PARAMETERS_ARB, &floatConstantCount);
            rsc.setFragmentProgramConstantFloatCount(cast(ushort)floatConstantCount);
            
            rsc.addShaderProfile("arbfp1");
            if (NV_fragment_program_option)
            {
                rsc.addShaderProfile("fp30");
            }
            
            if (NV_fragment_program2)
            {
                rsc.addShaderProfile("fp40");
            }        
            
            if (NV_fragment_program4)
            {
                rsc.addShaderProfile("gp4fp");
                rsc.addShaderProfile("gpu_fp");
            }
        }
        
        // NFZ - Check if GLSL is supported
        if ( GLEW_VERSION_2_0 || 
            (ARB_shading_language_100 &&
         ARB_shader_objects &&
         ARB_fragment_shader &&
         ARB_vertex_shader) )
        {
            rsc.addShaderProfile("glsl");
        }
        
        // Check if geometry shaders are supported
        if (GLEW_VERSION_2_0 &&
            EXT_geometry_shader4)
        {
            rsc.setCapability(Capabilities.RSC_GEOMETRY_PROGRAM);
            rsc.addShaderProfile("nvgp4");
            
            //Also add the CG profiles
            rsc.addShaderProfile("gpu_gp");
            rsc.addShaderProfile("gp4gp");
            
            rsc.setGeometryProgramConstantBoolCount(0);
            rsc.setGeometryProgramConstantIntCount(0);
            
            GLint floatConstantCount = 0;
            glGetIntegerv(GL_MAX_GEOMETRY_UNIFORM_COMPONENTS, &floatConstantCount);
            rsc.setGeometryProgramConstantFloatCount(cast(ushort)floatConstantCount);
            
            GLint maxOutputVertices;
            glGetIntegerv(GL_MAX_GEOMETRY_OUTPUT_VERTICES,&maxOutputVertices);
            rsc.setGeometryProgramNumOutputVertices(maxOutputVertices);
        }
        
        if (mGLSupport.checkExtension("GL_ARB_get_program_binary"))
        {
            // states 3.0 here: http://developer.download.nvidia.com/opengl/specs/GL_ARB_get_program_binary.txt
            // but not here: http://www.opengl.org/sdk/docs/man4/xhtml/glGetProgramBinary.xml
            // and here states 4.1: http://www.geeks3d.com/20100727/opengl-4-1-allows-the-use-of-binary-shaders/
            rsc.setCapability(Capabilities.RSC_CAN_GET_COMPILED_SHADER_BUFFER);
        }
        
        if (GLEW_VERSION_3_3 || ARB_instanced_arrays)
        {
            // states 3.3 here: http://www.opengl.org/sdk/docs/man3/xhtml/glVertexAttribDivisor.xml
            rsc.setCapability(Capabilities.RSC_VERTEX_BUFFER_INSTANCE_DATA);
        }
        
        //Check if render to vertex buffer (transform feedback in OpenGL)
        if (GLEW_VERSION_2_0 && 
            NV_transform_feedback)
        {
            rsc.setCapability(Capabilities.RSC_HWRENDER_TO_VERTEX_BUFFER);
        }
        
        // Check for texture compression
        if(GLEW_VERSION_1_3 || ARB_texture_compression)
        {   
            rsc.setCapability(Capabilities.RSC_TEXTURE_COMPRESSION);
            
            // Check for dxt compression
            if(EXT_texture_compression_s3tc)
            {
//#if defined(__APPLE__) && defined(__PPC__)
//                // Apple on ATI & PPC has errors in DXT
//                if (mGLSupport.getGLVendor().find("ATI") == std::string::npos)
//#endif
                    rsc.setCapability(Capabilities.RSC_TEXTURE_COMPRESSION_DXT);
            }
            // Check for vtc compression
            if(NV_texture_compression_vtc)
            {
                rsc.setCapability(Capabilities.RSC_TEXTURE_COMPRESSION_VTC);
            }
        }
        
        // Scissor test is standard in GL 1.2 (is it emulated on some cards though?)
        rsc.setCapability(Capabilities.RSC_SCISSOR_TEST);
        // As are user clipping planes
        rsc.setCapability(Capabilities.RSC_USER_CLIP_PLANES);
        
        // 2-sided stencil?
        if (GLEW_VERSION_2_0 || EXT_stencil_two_side)
        {
            rsc.setCapability(Capabilities.RSC_TWO_SIDED_STENCIL);
        }
        // stencil wrapping?
        if (GLEW_VERSION_1_4 || EXT_stencil_wrap)
        {
            rsc.setCapability(Capabilities.RSC_STENCIL_WRAP);
        }
        
        // Check for hardware occlusion support
        if(GLEW_VERSION_1_5 || ARB_occlusion_query)
        {
            // Some buggy driver claim that it is GL 1.5 compliant and
            // not support ARB_occlusion_query
            if (!ARB_occlusion_query)
            {
                rsc.setCapability(Capabilities.RSC_GL1_5_NOHWOCCLUSION);
            }
            
            rsc.setCapability(Capabilities.RSC_HWOCCLUSION);
        }
        else if (NV_occlusion_query)
        {
            // Support NV extension too for old hardware
            rsc.setCapability(Capabilities.RSC_HWOCCLUSION);
        }
        
        // UBYTE4 always supported
        rsc.setCapability(Capabilities.RSC_VERTEX_FORMAT_UBYTE4);
        
        // Infinite far plane always supported
        rsc.setCapability(Capabilities.RSC_INFINITE_FAR_PLANE);
        
        // Check for non-power-of-2 texture support
        if(ARB_texture_non_power_of_two)
        {
            rsc.setCapability(Capabilities.RSC_NON_POWER_OF_2_TEXTURES);
        }
        
        // Check for Float textures
        if(ATI_texture_float || ARB_texture_float)
        {
            rsc.setCapability(Capabilities.RSC_TEXTURE_FLOAT);
        }
        
        // 3D textures should be supported by GL 1.2, which is our minimum version
        rsc.setCapability(Capabilities.RSC_TEXTURE_1D);         
        rsc.setCapability(Capabilities.RSC_TEXTURE_3D);
        
        // Check for framebuffer object extension
        if(EXT_framebuffer_object)
        {
            // Probe number of draw buffers
            // Only makes sense with FBO support, so probe here
            if(GLEW_VERSION_2_0 || 
               ARB_draw_buffers ||
               ATI_draw_buffers)
            {
                GLint buffers;
                glGetIntegerv(GL_MAX_DRAW_BUFFERS, &buffers);
                rsc.setNumMultiRenderTargets(cast(ushort)std.algorithm.min(buffers, cast(GLint)OGRE_MAX_MULTIPLE_RENDER_TARGETS));
                rsc.setCapability(Capabilities.RSC_MRT_DIFFERENT_BIT_DEPTHS);
                if(!GLEW_VERSION_2_0)
                {
                    // Before GL version 2.0, we need to get one of the extensions
                    if(ARB_draw_buffers)
                        rsc.setCapability(Capabilities.RSC_FBO_ARB);
                    if(ATI_draw_buffers)
                        rsc.setCapability(Capabilities.RSC_FBO_ATI);
                }
                // Set FBO flag for all 3 'subtypes'
                rsc.setCapability(Capabilities.RSC_FBO);
                
            }
            rsc.setCapability(Capabilities.RSC_HWRENDER_TO_TEXTURE);
        }
        
        // Check GLSupport for PBuffer support
        if(mGLSupport.supportsPBuffers())
        {
            // Use PBuffers
            rsc.setCapability(Capabilities.RSC_HWRENDER_TO_TEXTURE);
            rsc.setCapability(Capabilities.RSC_PBUFFER);
        }
        
        // Point size
        if (GLEW_VERSION_1_4)
        {
            float ps;
            glGetFloatv(GL_POINT_SIZE_MAX, &ps);
            rsc.setMaxPointSize(ps);
        }
        else
        {
            GLint[2] vSize;
            glGetIntegerv(GL_POINT_SIZE_RANGE,vSize.ptr);
            rsc.setMaxPointSize(vSize[1]);
        }
        
        // Vertex texture fetching
        if (mGLSupport.checkExtension("GL_ARB_vertex_shader"))
        {
            GLint vUnits;
            glGetIntegerv(GL_MAX_VERTEX_TEXTURE_IMAGE_UNITS, &vUnits);
            rsc.setNumVertexTextureUnits(cast(ushort)(vUnits));
            if (vUnits > 0)
            {
                rsc.setCapability(Capabilities.RSC_VERTEX_TEXTURE_FETCH);
            }
            // GL always shares vertex and fragment texture units (for now?)
            rsc.setVertexTextureUnitsShared(true);
        }
        
        // Mipmap LOD biasing?
        if (GLEW_VERSION_1_4 || EXT_texture_lod_bias)
        {
            rsc.setCapability(Capabilities.RSC_MIPMAP_LOD_BIAS);
        }
        
        // Alpha to coverage?
        if (mGLSupport.checkExtension("GL_ARB_multisample"))
        {
            // Alpha to coverage always 'supported' when MSAA is available
            // although card may ignore it if it doesn't specifically support A2C
            rsc.setCapability(Capabilities.RSC_ALPHA_TO_COVERAGE);
        }
        
        // Advanced blending operations
        if(GLEW_VERSION_2_0)
        {
            rsc.setCapability(Capabilities.RSC_ADVANCED_BLEND_OPERATIONS);
        }
        
        return rsc;
    }
    /** See
          RenderSystem
         */
    override void initialiseFromRenderSystemCapabilities(RenderSystemCapabilities caps, RenderTarget primary)
    {
        if(caps.getRenderSystemName() != getName())
        {
            throw new InvalidParamsError(
                        "Trying to initialize GLRenderSystem from RenderSystemCapabilities that do not support OpenGL",
                        "GLRenderSystem.initialiseFromRenderSystemCapabilities");
        }
        
        // set texture the number of texture units
        mFixedFunctionTextureUnits = caps.getNumTextureUnits();
        
        //In GL there can be less fixed function texture units than general
        //texture units. Get the minimum of the two.
        if (caps.hasCapability(Capabilities.RSC_FRAGMENT_PROGRAM))
        {
            GLint maxTexCoords = 0;
            glGetIntegerv(GL_MAX_TEXTURE_COORDS, &maxTexCoords);
            if (mFixedFunctionTextureUnits > maxTexCoords)
            {
                mFixedFunctionTextureUnits = cast(ushort)maxTexCoords;
            }
        }
        
        if(caps.hasCapability(Capabilities.RSC_GL1_5_NOVBO))
        {
            // Assign ARB functions same to GL 1.5 version since
            // interface identical
            /*glBindBufferARB = glBindBuffer;
            glBufferDataARB = glBufferData;
            glBufferSubDataARB = glBufferSubData;
            glDeleteBuffersARB = glDeleteBuffers;
            glGenBuffersARB = glGenBuffers;
            glGetBufferParameterivARB = glGetBufferParameteriv;
            glGetBufferPointervARB = glGetBufferPointerv;
            glGetBufferSubDataARB = glGetBufferSubData;
            glIsBufferARB = glIsBuffer;
            glMapBufferARB = glMapBuffer;
            glUnmapBufferARB = glUnmapBuffer;*/
        }
        
        if(caps.hasCapability(Capabilities.RSC_VBO))
        {
            
            mHardwareBufferManager = HardwareBufferManager.getSingletonInit!GLHardwareBufferManager(new GLHardwareBufferManagerBase);
        }
        else
        {
            mHardwareBufferManager = HardwareBufferManager.getSingletonInit!GLDefaultHardwareBufferManager(new GLDefaultHardwareBufferManagerBase);
        }
        
        // XXX Need to check for nv2 support and make a program manager for it
        // XXX Probably nv1 as well for older cards
        // GPU Program Manager setup
        mGpuProgramManager = GpuProgramManager.getSingletonInit!GLGpuProgramManager();
        
        if(caps.hasCapability(Capabilities.RSC_VERTEX_PROGRAM))
        {
            if(caps.isShaderProfileSupported("arbvp1"))
            {
                mGpuProgramManager.registerProgramFactory("arbvp1", &createGLArbGpuProgram);
            }
            
            if(caps.isShaderProfileSupported("vp30"))
            {
                mGpuProgramManager.registerProgramFactory("vp30", &createGLArbGpuProgram);
            }
            
            if(caps.isShaderProfileSupported("vp40"))
            {
                mGpuProgramManager.registerProgramFactory("vp40", &createGLArbGpuProgram);
            }
            
            if(caps.isShaderProfileSupported("gp4vp"))
            {
                mGpuProgramManager.registerProgramFactory("gp4vp", &createGLArbGpuProgram);
            }
            
            if(caps.isShaderProfileSupported("gpu_vp"))
            {
                mGpuProgramManager.registerProgramFactory("gpu_vp", &createGLArbGpuProgram);
            }
        }
        
        if(caps.hasCapability(Capabilities.RSC_GEOMETRY_PROGRAM))
        {
            //TODO : Should these be &createGLArbGpuProgram or createGLGpuNVparseProgram?
            if(caps.isShaderProfileSupported("nvgp4"))
            {
                mGpuProgramManager.registerProgramFactory("nvgp4", &createGLArbGpuProgram);
            }
            if(caps.isShaderProfileSupported("gp4gp"))
            {
                mGpuProgramManager.registerProgramFactory("gp4gp", &createGLArbGpuProgram);
            }
            if(caps.isShaderProfileSupported("gpu_gp"))
            {
                mGpuProgramManager.registerProgramFactory("gpu_gp", &createGLArbGpuProgram);
            }
        }
        
        if(caps.hasCapability(Capabilities.RSC_FRAGMENT_PROGRAM))
        {
            
            if(caps.isShaderProfileSupported("fp20"))
            {
                mGpuProgramManager.registerProgramFactory("fp20", &createGLGpuNvparseProgram);
            }
            
            if(caps.isShaderProfileSupported("ps_1_4"))
            {
                mGpuProgramManager.registerProgramFactory("ps_1_4", &createGL_ATI_FS_GpuProgram);
            }
            
            if(caps.isShaderProfileSupported("ps_1_3"))
            {
                mGpuProgramManager.registerProgramFactory("ps_1_3", &createGL_ATI_FS_GpuProgram);
            }
            
            if(caps.isShaderProfileSupported("ps_1_2"))
            {
                mGpuProgramManager.registerProgramFactory("ps_1_2", &createGL_ATI_FS_GpuProgram);
            }
            
            if(caps.isShaderProfileSupported("ps_1_1"))
            {
                mGpuProgramManager.registerProgramFactory("ps_1_1", &createGL_ATI_FS_GpuProgram);
            }
            
            if(caps.isShaderProfileSupported("arbfp1"))
            {
                mGpuProgramManager.registerProgramFactory("arbfp1", &createGLArbGpuProgram);
            }
            
            if(caps.isShaderProfileSupported("fp40"))
            {
                mGpuProgramManager.registerProgramFactory("fp40", &createGLArbGpuProgram);
            }
            
            if(caps.isShaderProfileSupported("fp30"))
            {
                mGpuProgramManager.registerProgramFactory("fp30", &createGLArbGpuProgram);
            }
            
            if(caps.isShaderProfileSupported("gp4fp"))
            {
                mGpuProgramManager.registerProgramFactory("gp4fp", &createGLArbGpuProgram);
            }
            
            if(caps.isShaderProfileSupported("gpu_fp"))
            {
                mGpuProgramManager.registerProgramFactory("gpu_fp", &createGLArbGpuProgram);
            }
            
        }
        
        if(caps.isShaderProfileSupported("glsl"))
        {
            // NFZ - check for GLSL vertex and fragment shader support successful
            mGLSLProgramFactory = new GLSLProgramFactory();
            HighLevelGpuProgramManager.getSingleton().addFactory(mGLSLProgramFactory);
            LogManager.getSingleton().logMessage("GLSL support detected");
        }
        
        if(caps.hasCapability(Capabilities.RSC_HWOCCLUSION))
        {
            if(caps.hasCapability(Capabilities.RSC_GL1_5_NOHWOCCLUSION))
            {
                // Assign ARB functions same to GL 1.5 version since
                // interface identical
                /*glBeginQueryARB = glBeginQuery;
                glDeleteQueriesARB = glDeleteQueries;
                glEndQueryARB = glEndQuery;
                glGenQueriesARB = glGenQueries;
                glGetQueryObjectivARB = glGetQueryObjectiv;
                glGetQueryObjectuivARB = glGetQueryObjectuiv;
                glGetQueryivARB = glGetQueryiv;
                glIsQueryARB = glIsQuery;*/
            }
        }
        
        
        /// Do this after extension function pointers are initialised as the extension
        /// is used to probe further capabilities.
        auto cfi = "RTT Preferred Mode" in getConfigOptions();
        // RTT Mode: 0 use whatever available, 1 use PBuffers, 2 force use copying
        int rttMode = 0;
        if (cfi !is null)
        {
            if (cfi.currentValue == "PBuffer")
            {
                rttMode = 1;
            }
            else if (cfi.currentValue == "Copy")
            {
                rttMode = 2;
            }
        }
        
        
        
        
        // Check for framebuffer object extension
        if(caps.hasCapability(Capabilities.RSC_FBO) && rttMode < 1)
        {
            // FIXME Derelict: Going with glDrawBuffers only for now
            // Before GL version 2.0, we need to get one of the extensions
            //if(caps.hasCapability(Capabilities.RSC_FBO_ARB))
            //    GLEW_GET_FUN(__glewDrawBuffers) = glDrawBuffersARB;
            //else if(caps.hasCapability(Capabilities.RSC_FBO_ATI))
            //    GLEW_GET_FUN(__glewDrawBuffers) = glDrawBuffersATI;

            if(caps.hasCapability(Capabilities.RSC_HWRENDER_TO_TEXTURE))
            {
                // Create FBO manager
                LogManager.getSingleton().logMessage("GL: Using GL_EXT_framebuffer_object for rendering to textures (best)");
                mRTTManager = GLFBOManager.getSingletonInit!GLFBOManager(false);
                caps.setCapability(Capabilities.RSC_RTT_SEPARATE_DEPTHBUFFER);
                
                //TODO: Check if we're using OpenGL 3.0 and add RSC_RTT_DEPTHBUFFER_RESOLUTION_LESSEQUAL flag
            }
            
        }
        else
        {
            // Check GLSupport for PBuffer support
            if(caps.hasCapability(Capabilities.RSC_PBUFFER) && rttMode < 2)
            {
                if(caps.hasCapability(Capabilities.RSC_HWRENDER_TO_TEXTURE))
                {
                    // Use PBuffers
                    mRTTManager = GLPBRTTManager.getSingletonInit!GLPBRTTManager(mGLSupport, primary);
                    LogManager.getSingleton().logMessage("GL: Using PBuffers for rendering to textures");
                    
                    //TODO: Depth buffer sharing in pbuffer is left unsupported
                }
            }
            else
            {
                // No pbuffer support either -- fallback to simplest copying from framebuffer
                mRTTManager = GLCopyingRTTManager.getSingletonInit!GLCopyingRTTManager();
                LogManager.getSingleton().logMessage("GL: Using framebuffer copy for rendering to textures (worst)");
                LogManager.getSingleton().logMessage("GL: Warning: RenderTexture size is restricted to size of framebuffer. If you are on Linux, consider using GLX instead of SDL.");
                
                //Copy method uses the main depth buffer but no other depth buffer
                caps.setCapability(Capabilities.RSC_RTT_MAIN_DEPTHBUFFER_ATTACHABLE);
                caps.setCapability(Capabilities.RSC_RTT_DEPTHBUFFER_RESOLUTION_LESSEQUAL);
            }
            
            // Downgrade number of simultaneous targets
            caps.setNumMultiRenderTargets(1);
        }
        
        
        Log defaultLog = LogManager.getSingleton().getDefaultLog();
        if (defaultLog !is null)
        {
            caps.log(defaultLog);
        }
        
        mGLInitialised = true;
    }
    /** See
          RenderSystem
         */
    override void reinitialise() // Used if settings changed mid-rendering
    {
        this.shutdown();
        this._initialise(true);
    }
    /** See
          RenderSystem
         */
    override void shutdown()
    {
        RenderSystem.shutdown();
        
        // Deleting the GLSL program factory
        if (mGLSLProgramFactory)
        {
            // Remove from manager safely
            if (HighLevelGpuProgramManager.getSingletonPtr())
                HighLevelGpuProgramManager.getSingleton().removeFactory(mGLSLProgramFactory);
            destroy(mGLSLProgramFactory);
            mGLSLProgramFactory = null;
        }
        
        // Deleting the GPU program manager and hardware buffer manager.  Has to be done before the mGLSupport.stop().
        destroy(mGpuProgramManager);
        mGpuProgramManager = null;
        
        destroy(mHardwareBufferManager);
        mHardwareBufferManager = null;
        
        destroy(mRTTManager);
        mRTTManager = null;
        
        // Delete extra threads contexts
        foreach (pCurContext; mBackgroundContextList)
        {            
            pCurContext.releaseContext();
            
            destroy(pCurContext);
        }
        mBackgroundContextList.clear();
        
        if(mGLSupport !is null) //Sometimes can be called multiple times :/
            mGLSupport.stop();
        mStopRendering = true;
        
        destroy(mTextureManager);
        mTextureManager = null;
        
        // There will be a new initial window and so forth, thus any call to test
        //  some params will access an invalid pointer, so it is best to reset
        //  the whole state.
        mGLInitialised = 0;
    }
    
    /** See
          RenderSystem
         */
    override void setAmbientLight(float r, float g, float b)
    {
        GLfloat[] lmodel_ambient = [r, g, b, 1.0];
        glLightModelfv(GL_LIGHT_MODEL_AMBIENT, lmodel_ambient.ptr);
    }
    /** See
          RenderSystem
         */
    override void setShadingType(ShadeOptions so)
    {
        switch(so)
        {
            case ShadeOptions.SO_FLAT:
                glShadeModel(GL_FLAT);
                break;
            default:
                glShadeModel(GL_SMOOTH);
                break;
        }
    }
    /** See
          RenderSystem
         */
    override void setLightingEnabled(bool enabled)
    {
        if (enabled) 
        {      
            glEnable(GL_LIGHTING);
        } 
        else 
        {
            glDisable(GL_LIGHTING);
        }
    }
    
    /// @copydoc RenderSystem::_createRenderWindow
    override RenderWindow _createRenderWindow(string name, uint width, uint height, 
                                      bool fullScreen, NameValuePairList miscParams = null)
    {
        if ((name in mRenderTargets) !is null)
        {
            throw new InvalidParamsError(
                "Window with name '" ~ name ~ "' already exists",
                "GLRenderSystem._createRenderWindow" );
        }
        // Log a message
        string ss = std.conv.text("GLRenderSystem::_createRenderWindow \"", 
                                  name, "\", ", width, "x", height, " ");
        if(fullScreen)
            ss ~= "fullscreen ";
        else
            ss ~= "windowed ";
        if(!miscParams.emptyAA)
        {
            ss ~= " miscParams: ";
            foreach(k,v; miscParams)
            {
                ss ~= k ~ "=" ~ v ~ ", ";
            }
            LogManager.getSingleton().logMessage(ss);
        }
        
        // Create the window
        RenderWindow win = mGLSupport.newWindow(name, width, height, 
                                                fullScreen, miscParams);
        
        attachRenderTarget( win );
        
        if (!mGLInitialised) 
        {
            // set up glew and GLSupport
            initialiseContext(win);
            //FIXME When and where reload GL?
            DerelictGL.reload();
            
            string[] tokens = StringUtil.split(mGLSupport.getGLVersion(), ".");
            
            if (tokens.length)
            {
                mDriverVersion.major = std.conv.to!int(tokens[0]);
                if (tokens.length > 1)
                    mDriverVersion.minor = std.conv.to!int(tokens[1]);
                if (tokens.length > 2)
                    mDriverVersion.release = std.conv.to!int(tokens[2]); 
            }
            mDriverVersion.build = 0;
            // Initialise GL after the first window has been created
            // TODO: fire this from emulation options, and don't duplicate Real and Current capabilities
            mRealCapabilities = createRenderSystemCapabilities();
            
            // use real capabilities if custom capabilities are not available
            if(!mUseCustomCapabilities)
                mCurrentCapabilities = mRealCapabilities;
            
            fireEvent("RenderSystemCapabilitiesCreated");
            
            initialiseFromRenderSystemCapabilities(mCurrentCapabilities, win);
            
            // Initialise the main context
            _oneTimeContextInitialization();
            if(mCurrentContext)
                mCurrentContext.setInitialized();
        }
        
        if( win.getDepthBufferPool() != DepthBuffer.PoolId.POOL_NO_DEPTH )
        {
            //Unlike D3D9, OGL doesn't allow sharing the main depth buffer, so keep them separate.
            //Only Copy does, but Copy means only one depth buffer...
            GLContext windowContext;
            win.getCustomAttribute( GLRenderTexture.CustomAttributeString_GLCONTEXT, &windowContext );
            
            GLDepthBuffer depthBuffer = new GLDepthBuffer( DepthBuffer.PoolId.POOL_DEFAULT, this,
                                                           windowContext, null, null,
                                                           win.getWidth(), win.getHeight(),
                                                           win.getFSAA(), 0, true );
            
            if((depthBuffer.getPoolId() in mDepthBufferPool) is null)
                mDepthBufferPool[depthBuffer.getPoolId()] = null;
                
            mDepthBufferPool[depthBuffer.getPoolId()].insert( depthBuffer );
            
            win.attachDepthBuffer( depthBuffer );
        }
        
        return win;
    }
    
    /// @copydoc RenderSystem::_createRenderWindows
    override bool _createRenderWindows(const (RenderWindowDescriptionList) renderWindowDescriptions, 
                              RenderWindowList createdWindows)
    {       
        // Call base render system method.
        if (false == RenderSystem._createRenderWindows(renderWindowDescriptions, createdWindows))
            return false;
        
        // Simply call _createRenderWindow in a loop.
        foreach (i; 0..renderWindowDescriptions.length)
        {
            RenderWindowDescription curRenderWindowDescription = cast(RenderWindowDescription)renderWindowDescriptions[i];            
            RenderWindow curWindow = null;
            
            curWindow = _createRenderWindow(curRenderWindowDescription.name, 
                                            curRenderWindowDescription.width, 
                                            curRenderWindowDescription.height, 
                                            curRenderWindowDescription.useFullScreen, 
                                            curRenderWindowDescription.miscParams);
            
            createdWindows.insert(curWindow);                                            
        }
        
        return true;
    }
    
    /// @copydoc RenderSystem::_createDepthBufferFor
    override DepthBuffer _createDepthBufferFor( RenderTarget renderTarget )
    {
        GLDepthBuffer retVal = null;
        
        //Only FBO & pbuffer support different depth buffers, so everything
        //else creates dummy (empty) containers
        //retVal = mRTTManager._createDepthBufferFor( renderTarget );
        GLFrameBufferObject fbo = null;
        renderTarget.getCustomAttribute(GLRenderTexture.CustomAttributeString_FBO, &fbo);
        
        if( fbo )
        {
            //Presence of an FBO means the manager is an FBO Manager, that's why it's safe to downcast
            //Find best depth & stencil format suited for the RT's format
            GLuint depthFormat, stencilFormat;
            (cast(GLFBOManager)mRTTManager).getBestDepthStencil( fbo.getFormat(),
                                                                 depthFormat, stencilFormat );
            
            GLRenderBuffer depthBuffer = new GLRenderBuffer( depthFormat, fbo.getWidth(),
                                                             fbo.getHeight(), fbo.getFSAA() );
            
            GLRenderBuffer stencilBuffer = depthBuffer;
            if( depthFormat != GL_DEPTH24_STENCIL8 && stencilBuffer )
            {
                stencilBuffer = new GLRenderBuffer( stencilFormat, fbo.getWidth(),
                                                   fbo.getHeight(), fbo.getFSAA() );
            }
            
            //No "custom-quality" multisample for now in GL
            retVal = new GLDepthBuffer( 0, this, mCurrentContext, depthBuffer, stencilBuffer,
                                       cast(uint)fbo.getWidth(), cast(uint)fbo.getHeight(), 
                                       cast(uint)fbo.getFSAA(), 0, false );
        }
        
        return retVal;
    }

    /// Mimics D3D9RenderSystem::_getDepthStencilFormatFor, if no FBO RTT manager, outputs GL_NONE
    void _getDepthStencilFormatFor( GLenum internalColourFormat, ref GLenum depthFormat,
                                   ref GLenum stencilFormat )
    {
        mRTTManager.getBestDepthStencil( internalColourFormat, depthFormat, stencilFormat );
    }
    
    /// @copydoc RenderSystem::createMultiRenderTarget
    override MultiRenderTarget createMultiRenderTarget(string name)
    {
        MultiRenderTarget retval = mRTTManager.createMultiRenderTarget(name);
        attachRenderTarget( retval );
        return retval;
    }
    
    /** See
          RenderSystem
         */
    void destroyRenderWindow(RenderWindow pWin)
    {
        // Find it to remove from list
        
        foreach (tk, target; mRenderTargets)
        {
            if (target == pWin)
            {
                GLContext windowContext;
                pWin.getCustomAttribute(GLRenderTexture.CustomAttributeString_GLCONTEXT, &windowContext);
                
                //1 Window <. 1 Context, should be always true
                assert( windowContext );
                
                bool bFound = false;
                //Find the depth buffer from this window and remove it.
                //DepthBufferMap::iterator itMap = mDepthBufferPool.begin();
                //DepthBufferMap::iterator enMap = mDepthBufferPool.end();
                
                //while( itMap != enMap && !bFound )
                foreach(k,v; mDepthBufferPool)
                {
                    //DepthBufferVec::iterator itor = itMap.second.begin();
                    //DepthBufferVec::iterator end  = itMap.second.end();
                    
                    //while( itor != end )
                    foreach(itor; v)
                    {
                        //A DepthBuffer with no depth & stencil pointers is a dummy one,
                        //look for the one that matches the same GL context
                        GLDepthBuffer depthBuffer = cast(GLDepthBuffer)itor;
                        GLContext glContext = depthBuffer.getGLContext();
                        
                        if( glContext == windowContext &&
                           (depthBuffer.getDepthBuffer() || depthBuffer.getStencilBuffer()) )
                        {
                            bFound = true;

                            v.removeFromArray(itor);
                            destroy(itor);
                            //delete *itor;
                            //itMap.second.erase( itor );
                            break;
                        }
                    }

                    if(bFound) break;
                }
                
                mRenderTargets.remove(tk);
                destroy(pWin);
                break;
            }
        }
    }
    /** See
          RenderSystem
         */
    override string getErrorDescription(long errorNumber) const
    {
        return gluErrorString(cast(GLenum)errorNumber);
    }
    
    /** See
          RenderSystem
         */
    override VertexElementType getColourVertexElementType() const
    {
        return VertexElementType.VET_COLOUR_ABGR;
    }
    /** See
          RenderSystem
         */
    override void setNormaliseNormals(bool normalise)
    {
        if (normalise)
            glEnable(GL_NORMALIZE);
        else
            glDisable(GL_NORMALIZE);
        
    }
    
    // -----------------------------
    // Low-level overridden members
    // -----------------------------
    /** See
          RenderSystem
         */
    override void _useLights(LightList lights, ushort limit)
    {
        // Save previous modelview
        glMatrixMode(GL_MODELVIEW);
        glPushMatrix();
        // just load view matrix (identity world)
        GLfloat[16] mat;
        makeGLMatrix(mat, mViewMatrix);
        glLoadMatrixf(mat.ptr);

        ushort num = 0;
        foreach (i; lights)
        {
            setGLLight(num, i);
            mLights[num] = i;
            ++num;
            if(num >= limit) break;
        }

        // Disable extra lights
        for (; num < mCurrentLights; ++num)
        {
            setGLLight(num, null);
            mLights[num] = null;
        }
        mCurrentLights = std.algorithm.min(limit, lights.length);
        
        setLights();
        
        // restore previous
        glPopMatrix();
        
    }

    /** See
          RenderSystem
         */
    override bool areFixedFunctionLightsInViewSpace() const { return true; }
    /** See
          RenderSystem
         */
    override void _setWorldMatrix(Matrix4 m)
    {
        GLfloat[16] mat;
        mWorldMatrix = m;
        makeGLMatrix( mat, mViewMatrix * mWorldMatrix );
        glMatrixMode(GL_MODELVIEW);
        glLoadMatrixf(mat.ptr);
    }
    /** See
          RenderSystem
         */
    override void _setViewMatrix(Matrix4 m)
    {
        mViewMatrix = m;
        
        GLfloat[16] mat;
        makeGLMatrix( mat, mViewMatrix * mWorldMatrix );
        glMatrixMode(GL_MODELVIEW);
        glLoadMatrixf(mat.ptr);
        
        // also mark clip planes dirty
        if (mClipPlanes.length)
            mClipPlanesDirty = true;
    }
    /** See
          RenderSystem
         */
    override void _setProjectionMatrix(const(Matrix4) m)
    {
        GLfloat[16] mat;
        makeGLMatrix(mat, m);
        if (mActiveRenderTarget.requiresTextureFlipping())
        {
            // Invert transformed y
            mat[1] = -mat[1];
            mat[5] = -mat[5];
            mat[9] = -mat[9];
            mat[13] = -mat[13];
        }
        glMatrixMode(GL_PROJECTION);
        glLoadMatrixf(mat.ptr);
        glMatrixMode(GL_MODELVIEW);
        
        // also mark clip planes dirty
        if (mClipPlanes.length)
            mClipPlanesDirty = true;
    }
    /** See
          RenderSystem
         */
    override void _setSurfaceParams(ColourValue ambient,
                                    ColourValue diffuse, ColourValue specular,
                                    ColourValue emissive, Real shininess,
                                    TrackVertexColour tracking)
    {
        
        // Track vertex colour
        if(tracking != TVC_NONE) 
        {
            GLenum gt = GL_DIFFUSE;
            // There are actually 15 different combinations for tracking, of which
            // GL only supports the most used 5. This means that we have to do some
            // magic to find the best match. NOTE: 
            //  GL_AMBIENT_AND_DIFFUSE != GL_AMBIENT | GL_DIFFUSE
            if(tracking & TVC_AMBIENT) 
            {
                if(tracking & TVC_DIFFUSE)
                {
                    gt = GL_AMBIENT_AND_DIFFUSE;
                } 
                else 
                {
                    gt = GL_AMBIENT;
                }
            }
            else if(tracking & TVC_DIFFUSE) 
            {
                gt = GL_DIFFUSE;
            }
            else if(tracking & TVC_SPECULAR) 
            {
                gt = GL_SPECULAR;              
            }
            else if(tracking & TVC_EMISSIVE) 
            {
                gt = GL_EMISSION;
            }
            glColorMaterial(GL_FRONT_AND_BACK, gt);
            
            glEnable(GL_COLOR_MATERIAL);
        } 
        else 
        {
            glDisable(GL_COLOR_MATERIAL);          
        }
        
        // XXX Cache previous values?
        // XXX Front or Front and Back?
        // TODO GLfloat is float anyway, maybe pass &diffuse.r directly
        GLfloat[4] f4val = [diffuse.r, diffuse.g, diffuse.b, diffuse.a];
        glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, f4val.ptr);
        f4val[0] = ambient.r;
        f4val[1] = ambient.g;
        f4val[2] = ambient.b;
        f4val[3] = ambient.a;
        glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, f4val.ptr);
        f4val[0] = specular.r;
        f4val[1] = specular.g;
        f4val[2] = specular.b;
        f4val[3] = specular.a;
        glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, f4val.ptr);
        f4val[0] = emissive.r;
        f4val[1] = emissive.g;
        f4val[2] = emissive.b;
        f4val[3] = emissive.a;
        glMaterialfv(GL_FRONT_AND_BACK, GL_EMISSION, f4val.ptr);
        glMaterialf(GL_FRONT_AND_BACK, GL_SHININESS, shininess);
    }
    /** See
          RenderSystem
         */
    override void _setPointParameters(Real size, bool attenuationEnabled, 
                             Real constant, Real linear, Real quadratic, Real minSize, Real maxSize)
    {
        
        float[4] val = [1, 0, 0, 1];
        
        if(attenuationEnabled) 
        {
            // Point size is still calculated in pixels even when attenuation is
            // enabled, which is pretty awkward, since you typically want a viewport
            // independent size if you're looking for attenuation.
            // So, scale the point size up by viewport size (this is equivalent to
            // what D3D does as standard)
            size = size * mActiveViewport.getActualHeight();
            minSize = minSize * mActiveViewport.getActualHeight();
            if (maxSize == 0.0f)
                maxSize = mCurrentCapabilities.getMaxPointSize(); // pixels
            else
                maxSize = maxSize * mActiveViewport.getActualHeight();
            
            // XXX: why do I need this for results to be consistent with D3D?
            // Equations are supposedly the same once you factor in vp height
            Real correction = 0.005;
            // scaling required
            val[0] = constant;
            val[1] = linear * correction;
            val[2] = quadratic * correction;
            val[3] = 1;
            
            if (mCurrentCapabilities.hasCapability(Capabilities.RSC_VERTEX_PROGRAM))
                glEnable(GL_VERTEX_PROGRAM_POINT_SIZE);
            
            
        } 
        else 
        {
            if (maxSize == 0.0f)
                maxSize = mCurrentCapabilities.getMaxPointSize();
            if (mCurrentCapabilities.hasCapability(Capabilities.RSC_VERTEX_PROGRAM))
                glDisable(GL_VERTEX_PROGRAM_POINT_SIZE);
        }
        
        // no scaling required
        // GL has no disabled flag for this so just set to constant
        glPointSize(size);
        
        if (mCurrentCapabilities.hasCapability(Capabilities.RSC_POINT_EXTENDED_PARAMETERS))
        {
            glPointParameterfv(GL_POINT_DISTANCE_ATTENUATION, val.ptr);
            glPointParameterf(GL_POINT_SIZE_MIN, minSize);
            glPointParameterf(GL_POINT_SIZE_MAX, maxSize);
        } 
        //TODO Derelict3 has no extra ARB or EXT suffixed versions
        /*else if (mCurrentCapabilities.hasCapability(Capabilities.RSC_POINT_EXTENDED_PARAMETERS_ARB))
        {
            glPointParameterfvARB(GL_POINT_DISTANCE_ATTENUATION, val);
            glPointParameterfARB(GL_POINT_SIZE_MIN, minSize);
            glPointParameterfARB(GL_POINT_SIZE_MAX, maxSize);
        } 
        else if (mCurrentCapabilities.hasCapability(Capabilities.RSC_POINT_EXTENDED_PARAMETERS_EXT))
        {
            glPointParameterfvEXT(GL_POINT_DISTANCE_ATTENUATION, val);
            glPointParameterfEXT(GL_POINT_SIZE_MIN, minSize);
            glPointParameterfEXT(GL_POINT_SIZE_MAX, maxSize);
        }*/
    }
    /** See
          RenderSystem
         */
    override void _setPointSpritesEnabled(bool enabled)
    {
        if (!getCapabilities().hasCapability(Capabilities.RSC_POINT_SPRITES))
            return;
        
        if (enabled)
        {
            glEnable(GL_POINT_SPRITE);
        }
        else
        {
            glDisable(GL_POINT_SPRITE);
        }
        
        // Set sprite texture coord generation
        // Don't offer this as an option since D3D links it to sprite enabled
        for (ushort i = 0; i < mFixedFunctionTextureUnits; ++i)
        {
            activateGLTextureUnit(i);
            glTexEnvi(GL_POINT_SPRITE, GL_COORD_REPLACE, 
                      enabled ? GL_TRUE : GL_FALSE);
        }
        activateGLTextureUnit(0);
        
    }
    /** See
          RenderSystem
         */
    override void _setTexture(size_t stage, bool enabled, const (SharedPtr!Texture) texPtr)
    in
    {
        assert(texPtr !is null);
    }
    body
    {
        GLTexturePtr tex = cast(GLTexturePtr)texPtr;
        
        GLenum lastTextureType = mTextureTypes[stage];
        
        if (!activateGLTextureUnit(stage))
            return;
        
        if (enabled)
        {
            if (!tex.isNull())
            {
                // note used
                tex.get().touch();
                mTextureTypes[stage] = tex.get().getGLTextureTarget();
            }
            else
                // assume 2D
                mTextureTypes[stage] = GL_TEXTURE_2D;
            
            if(lastTextureType != mTextureTypes[stage] && lastTextureType != 0)
            {
                if (stage < mFixedFunctionTextureUnits)
                {
                    if(lastTextureType != GL_TEXTURE_2D_ARRAY)
                        glDisable( lastTextureType );
                }
            }
            
            if (stage < mFixedFunctionTextureUnits)
            {
                if(mTextureTypes[stage] != GL_TEXTURE_2D_ARRAY/*_EXT*/)
                    glEnable( mTextureTypes[stage] );
            }
            
            if(!tex.isNull())
                glBindTexture( mTextureTypes[stage], tex.get().getGLID() );
            else
                glBindTexture( mTextureTypes[stage], (cast(GLTextureManager)mTextureManager).getWarningTextureID() );
        }
        else
        {
            if (stage < mFixedFunctionTextureUnits)
            {
                if (lastTextureType != 0)
                {
                    if(mTextureTypes[stage] != GL_TEXTURE_2D_ARRAY/*_EXT*/)
                        glDisable( mTextureTypes[stage] );
                }
                glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
            }
            // bind zero texture
            glBindTexture(GL_TEXTURE_2D, 0); 
        }
        
        activateGLTextureUnit(0);
    }

    /** See
          RenderSystem
         */
    override void _setTextureCoordSet(size_t stage, size_t index)
    {
        mTextureCoordIndex[stage] = index;
    }

    /** See
          RenderSystem
         */
    override void _setTextureCoordCalculation(size_t stage, TexCoordCalcMethod m, 
                                     const(Frustum) frustum = null)
    {
        if (stage >= mFixedFunctionTextureUnits)
        {
            // Can't do this
            return;
        }
        
        
        GLfloat[16] M;
        Matrix4 projectionBias;
        
        // Default to no extra auto texture matrix
        mUseAutoTextureMatrix = false;
        
        GLfloat[] eyePlaneS = [1.0, 0.0, 0.0, 0.0];
        GLfloat[] eyePlaneT = [0.0, 1.0, 0.0, 0.0];
        GLfloat[] eyePlaneR = [0.0, 0.0, 1.0, 0.0];
        GLfloat[] eyePlaneQ = [0.0, 0.0, 0.0, 1.0];
        
        if (!activateGLTextureUnit(stage))
            return;
        
        switch( m )
        {
            case TexCoordCalcMethod.TEXCALC_NONE:
                glDisable( GL_TEXTURE_GEN_S );
                glDisable( GL_TEXTURE_GEN_T );
                glDisable( GL_TEXTURE_GEN_R );
                glDisable( GL_TEXTURE_GEN_Q );
                break;
                
            case TexCoordCalcMethod.TEXCALC_ENVIRONMENT_MAP:
                glTexGeni( GL_S, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP );
                glTexGeni( GL_T, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP );
                
                glEnable( GL_TEXTURE_GEN_S );
                glEnable( GL_TEXTURE_GEN_T );
                glDisable( GL_TEXTURE_GEN_R );
                glDisable( GL_TEXTURE_GEN_Q );
                
                // Need to use a texture matrix to flip the spheremap
                mUseAutoTextureMatrix = true;
                //memset(mAutoTextureMatrix, 0, GLfloat.sizeof*16);
                mAutoTextureMatrix[] = 0;
                mAutoTextureMatrix[0] = mAutoTextureMatrix[10] = mAutoTextureMatrix[15] = 1.0f;
                mAutoTextureMatrix[5] = -1.0f;
                
                break;
                
            case TexCoordCalcMethod.TEXCALC_ENVIRONMENT_MAP_PLANAR:            
                // XXX This doesn't seem right?!
                static if (GL_VERSION_1_3)
                {
                    glTexGeni( GL_S, GL_TEXTURE_GEN_MODE, GL_REFLECTION_MAP );
                    glTexGeni( GL_T, GL_TEXTURE_GEN_MODE, GL_REFLECTION_MAP );
                    glTexGeni( GL_R, GL_TEXTURE_GEN_MODE, GL_REFLECTION_MAP );
                    
                    glEnable( GL_TEXTURE_GEN_S );
                    glEnable( GL_TEXTURE_GEN_T );
                    glEnable( GL_TEXTURE_GEN_R );
                    glDisable( GL_TEXTURE_GEN_Q );
                }
                else
                {
                    glTexGeni( GL_S, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP );
                    glTexGeni( GL_T, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP );
                    
                    glEnable( GL_TEXTURE_GEN_S );
                    glEnable( GL_TEXTURE_GEN_T );
                    glDisable( GL_TEXTURE_GEN_R );
                    glDisable( GL_TEXTURE_GEN_Q );
                }
                break;
            case TexCoordCalcMethod.TEXCALC_ENVIRONMENT_MAP_REFLECTION:
                
                glTexGeni( GL_S, GL_TEXTURE_GEN_MODE, GL_REFLECTION_MAP );
                glTexGeni( GL_T, GL_TEXTURE_GEN_MODE, GL_REFLECTION_MAP );
                glTexGeni( GL_R, GL_TEXTURE_GEN_MODE, GL_REFLECTION_MAP );
                
                glEnable( GL_TEXTURE_GEN_S );
                glEnable( GL_TEXTURE_GEN_T );
                glEnable( GL_TEXTURE_GEN_R );
                glDisable( GL_TEXTURE_GEN_Q );
                
                // We need an extra texture matrix here
                // This sets the texture matrix to be the inverse of the view matrix
                mUseAutoTextureMatrix = true;
                makeGLMatrix( M, mViewMatrix);
                
                // Transpose 3x3 in order to invert matrix (rotation)
                // Note that we need to invert the Z _before_ the rotation
                // No idea why we have to invert the Z at all, but reflection is wrong without it
                mAutoTextureMatrix[0] = M[0]; mAutoTextureMatrix[1] = M[4]; mAutoTextureMatrix[2] = -M[8];
                mAutoTextureMatrix[4] = M[1]; mAutoTextureMatrix[5] = M[5]; mAutoTextureMatrix[6] = -M[9];
                mAutoTextureMatrix[8] = M[2]; mAutoTextureMatrix[9] = M[6]; mAutoTextureMatrix[10] = -M[10];
                mAutoTextureMatrix[3] = mAutoTextureMatrix[7] = mAutoTextureMatrix[11] = 0.0f;
                mAutoTextureMatrix[12] = mAutoTextureMatrix[13] = mAutoTextureMatrix[14] = 0.0f;
                mAutoTextureMatrix[15] = 1.0f;
                
                break;
            case TexCoordCalcMethod.TEXCALC_ENVIRONMENT_MAP_NORMAL:
                glTexGeni( GL_S, GL_TEXTURE_GEN_MODE, GL_NORMAL_MAP );
                glTexGeni( GL_T, GL_TEXTURE_GEN_MODE, GL_NORMAL_MAP );
                glTexGeni( GL_R, GL_TEXTURE_GEN_MODE, GL_NORMAL_MAP );
                
                glEnable( GL_TEXTURE_GEN_S );
                glEnable( GL_TEXTURE_GEN_T );
                glEnable( GL_TEXTURE_GEN_R );
                glDisable( GL_TEXTURE_GEN_Q );
                break;
            case TexCoordCalcMethod.TEXCALC_PROJECTIVE_TEXTURE:
                glTexGeni(GL_S, GL_TEXTURE_GEN_MODE, GL_EYE_LINEAR);
                glTexGeni(GL_T, GL_TEXTURE_GEN_MODE, GL_EYE_LINEAR);
                glTexGeni(GL_R, GL_TEXTURE_GEN_MODE, GL_EYE_LINEAR);
                glTexGeni(GL_Q, GL_TEXTURE_GEN_MODE, GL_EYE_LINEAR);
                glTexGenfv(GL_S, GL_EYE_PLANE, eyePlaneS.ptr);
                glTexGenfv(GL_T, GL_EYE_PLANE, eyePlaneT.ptr);
                glTexGenfv(GL_R, GL_EYE_PLANE, eyePlaneR.ptr);
                glTexGenfv(GL_Q, GL_EYE_PLANE, eyePlaneQ.ptr);
                glEnable(GL_TEXTURE_GEN_S);
                glEnable(GL_TEXTURE_GEN_T);
                glEnable(GL_TEXTURE_GEN_R);
                glEnable(GL_TEXTURE_GEN_Q);
                
                mUseAutoTextureMatrix = true;
                
                // Set scale and translation matrix for projective textures
                projectionBias = Matrix4.CLIPSPACE2DTOIMAGESPACE;
                
                projectionBias = projectionBias * frustum.getProjectionMatrix();
                if(mTexProjRelative)
                {
                    Matrix4 viewMatrix;
                    frustum.calcViewMatrixRelative(mTexProjRelativeOrigin, viewMatrix);
                    projectionBias = projectionBias * viewMatrix;
                }
                else
                {
                    projectionBias = projectionBias * frustum.getViewMatrix();
                }
                projectionBias = projectionBias * mWorldMatrix;
                
                makeGLMatrix(mAutoTextureMatrix, projectionBias);
                break;
            default:
                break;
        }
        activateGLTextureUnit(0);
    }

    /** See
          RenderSystem
         */
    override void _setTextureBlendMode(size_t stage, const (LayerBlendModeEx) bm)
    {       
        if (stage >= mFixedFunctionTextureUnits)
        {
            // Can't do this
            return;
        }
        
        // Check to see if blending is supported
        if(!mCurrentCapabilities.hasCapability(Capabilities.RSC_BLENDING))
            return;
        
        GLenum src1op, src2op, cmd;
        GLfloat[4] cv1, cv2;
        
        if (bm.blendType == LayerBlendType.LBT_COLOUR)
        {
            cv1[0] = bm.colourArg1.r;
            cv1[1] = bm.colourArg1.g;
            cv1[2] = bm.colourArg1.b;
            cv1[3] = bm.colourArg1.a;
            mManualBlendColours[stage][0] = bm.colourArg1;
            
            
            cv2[0] = bm.colourArg2.r;
            cv2[1] = bm.colourArg2.g;
            cv2[2] = bm.colourArg2.b;
            cv2[3] = bm.colourArg2.a;
            mManualBlendColours[stage][1] = bm.colourArg2;
        }
        
        if (bm.blendType == LayerBlendType.LBT_ALPHA)
        {
            cv1[0] = mManualBlendColours[stage][0].r;
            cv1[1] = mManualBlendColours[stage][0].g;
            cv1[2] = mManualBlendColours[stage][0].b;
            cv1[3] = bm.alphaArg1;
            
            cv2[0] = mManualBlendColours[stage][1].r;
            cv2[1] = mManualBlendColours[stage][1].g;
            cv2[2] = mManualBlendColours[stage][1].b;
            cv2[3] = bm.alphaArg2;
        }
        
        switch (bm.source1)
        {
            case LayerBlendSource.LBS_CURRENT:
                src1op = GL_PREVIOUS;
                break;
            case LayerBlendSource.LBS_TEXTURE:
                src1op = GL_TEXTURE;
                break;
            case LayerBlendSource.LBS_MANUAL:
                src1op = GL_CONSTANT;
                break;
            case LayerBlendSource.LBS_DIFFUSE:
                src1op = GL_PRIMARY_COLOR;
                break;
                // XXX
            case LayerBlendSource.LBS_SPECULAR:
                src1op = GL_PRIMARY_COLOR;
                break;
            default:
                src1op = 0;
        }
        
        switch (bm.source2)
        {
            case LayerBlendSource.LBS_CURRENT:
                src2op = GL_PREVIOUS;
                break;
            case LayerBlendSource.LBS_TEXTURE:
                src2op = GL_TEXTURE;
                break;
            case LayerBlendSource.LBS_MANUAL:
                src2op = GL_CONSTANT;
                break;
            case LayerBlendSource.LBS_DIFFUSE:
                src2op = GL_PRIMARY_COLOR;
                break;
                // XXX
            case LayerBlendSource.LBS_SPECULAR:
                src2op = GL_PRIMARY_COLOR;
                break;
            default:
                src2op = 0;
        }
        
        switch (bm.operation)
        {
            case LayerBlendOperationEx.LBX_SOURCE1:
                cmd = GL_REPLACE;
                break;
            case LayerBlendOperationEx.LBX_SOURCE2:
                cmd = GL_REPLACE;
                break;
            case LayerBlendOperationEx.LBX_MODULATE:
                cmd = GL_MODULATE;
                break;
            case LayerBlendOperationEx.LBX_MODULATE_X2:
                cmd = GL_MODULATE;
                break;
            case LayerBlendOperationEx.LBX_MODULATE_X4:
                cmd = GL_MODULATE;
                break;
            case LayerBlendOperationEx.LBX_ADD:
                cmd = GL_ADD;
                break;
            case LayerBlendOperationEx.LBX_ADD_SIGNED:
                cmd = GL_ADD_SIGNED;
                break;
            case LayerBlendOperationEx.LBX_ADD_SMOOTH:
                cmd = GL_INTERPOLATE;
                break;
            case LayerBlendOperationEx.LBX_SUBTRACT:
                cmd = GL_SUBTRACT;
                break;
            case LayerBlendOperationEx.LBX_BLEND_DIFFUSE_COLOUR:
                cmd = GL_INTERPOLATE;
                break; 
            case LayerBlendOperationEx.LBX_BLEND_DIFFUSE_ALPHA:
                cmd = GL_INTERPOLATE;
                break;
            case LayerBlendOperationEx.LBX_BLEND_TEXTURE_ALPHA:
                cmd = GL_INTERPOLATE;
                break;
            case LayerBlendOperationEx.LBX_BLEND_CURRENT_ALPHA:
                cmd = GL_INTERPOLATE;
                break;
            case LayerBlendOperationEx.LBX_BLEND_MANUAL:
                cmd = GL_INTERPOLATE;
                break;
            case LayerBlendOperationEx.LBX_DOTPRODUCT:
                cmd = mCurrentCapabilities.hasCapability(Capabilities.RSC_DOT3) 
                    ? GL_DOT3_RGB : GL_MODULATE;
                break;
            default:
                cmd = 0;
        }
        
        if (!activateGLTextureUnit(stage))
            return;
        glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_COMBINE);
        
        if (bm.blendType == LayerBlendType.LBT_COLOUR)
        {
            glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_RGB, cmd);
            glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE0_RGB, src1op);
            glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE1_RGB, src2op);
            glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE2_RGB, GL_CONSTANT);
        }
        else
        {
            glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_ALPHA, cmd);
            glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE0_ALPHA, src1op);
            glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE1_ALPHA, src2op);
            glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE2_ALPHA, GL_CONSTANT);
        }
        
        float[4] blendValue = [0, 0, 0, bm.factor];
        switch (bm.operation)
        {
            case LayerBlendOperationEx.LBX_BLEND_DIFFUSE_COLOUR:
                glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE2_RGB, GL_PRIMARY_COLOR);
                glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE2_ALPHA, GL_PRIMARY_COLOR);
                break;
            case LayerBlendOperationEx.LBX_BLEND_DIFFUSE_ALPHA:
                glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE2_RGB, GL_PRIMARY_COLOR);
                glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE2_ALPHA, GL_PRIMARY_COLOR);
                break;
            case LayerBlendOperationEx.LBX_BLEND_TEXTURE_ALPHA:
                glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE2_RGB, GL_TEXTURE);
                glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE2_ALPHA, GL_TEXTURE);
                break;
            case LayerBlendOperationEx.LBX_BLEND_CURRENT_ALPHA:
                glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE2_RGB, GL_PREVIOUS);
                glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE2_ALPHA, GL_PREVIOUS);
                break;
            case LayerBlendOperationEx.LBX_BLEND_MANUAL:
                glTexEnvfv(GL_TEXTURE_ENV, GL_TEXTURE_ENV_COLOR, blendValue.ptr);
                break;
            default:
                break;
        }
        
        switch (bm.operation)
        {
            case LayerBlendOperationEx.LBX_MODULATE_X2:
                glTexEnvi(GL_TEXTURE_ENV, bm.blendType == LayerBlendType.LBT_COLOUR ? 
                          GL_RGB_SCALE : GL_ALPHA_SCALE, 2);
                break;
            case LayerBlendOperationEx.LBX_MODULATE_X4:
                glTexEnvi(GL_TEXTURE_ENV, bm.blendType == LayerBlendType.LBT_COLOUR ? 
                          GL_RGB_SCALE : GL_ALPHA_SCALE, 4);
                break;
            default:
                glTexEnvi(GL_TEXTURE_ENV, bm.blendType == LayerBlendType.LBT_COLOUR ? 
                          GL_RGB_SCALE : GL_ALPHA_SCALE, 1);
                break;
        }
        
        if (bm.blendType == LayerBlendType.LBT_COLOUR){
            glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_RGB, GL_SRC_COLOR);
            glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND1_RGB, GL_SRC_COLOR);
            if (bm.operation == LayerBlendOperationEx.LBX_BLEND_DIFFUSE_COLOUR){
                glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND2_RGB, GL_SRC_COLOR);
            } else {
                glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND2_RGB, GL_SRC_ALPHA);
            }
        } 
        
        glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_ALPHA, GL_SRC_ALPHA);
        glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND1_ALPHA, GL_SRC_ALPHA);
        glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND2_ALPHA, GL_SRC_ALPHA);
        if(bm.source1 == LayerBlendSource.LBS_MANUAL)
            glTexEnvfv(GL_TEXTURE_ENV, GL_TEXTURE_ENV_COLOR, cv1.ptr);
        if (bm.source2 == LayerBlendSource.LBS_MANUAL)
            glTexEnvfv(GL_TEXTURE_ENV, GL_TEXTURE_ENV_COLOR, cv2.ptr);
        
        activateGLTextureUnit(0);
    }

    /** See
          RenderSystem
         */
    override void _setTextureAddressingMode(size_t stage, const (TextureUnitState.UVWAddressingMode) uvw)
    {
        if (!activateGLTextureUnit(stage))
            return;
        glTexParameteri( mTextureTypes[stage], GL_TEXTURE_WRAP_S, 
                        getTextureAddressingMode(uvw.u));
        glTexParameteri( mTextureTypes[stage], GL_TEXTURE_WRAP_T, 
                        getTextureAddressingMode(uvw.v));
        glTexParameteri( mTextureTypes[stage], GL_TEXTURE_WRAP_R, 
                        getTextureAddressingMode(uvw.w));
        activateGLTextureUnit(0);
    }

    /** See
          RenderSystem
         */
    override void _setTextureBorderColour(size_t stage, const (ColourValue) colour)
    {
        GLfloat[4] border = [colour.r, colour.g, colour.b, colour.a];
        if (activateGLTextureUnit(stage))
        {
            glTexParameterfv( mTextureTypes[stage], GL_TEXTURE_BORDER_COLOR, border.ptr);
            activateGLTextureUnit(0);
        }
    }

    /** See
          RenderSystem
         */
    override void _setTextureMipmapBias(size_t unit, float bias)
    {
        if (mCurrentCapabilities.hasCapability(Capabilities.RSC_MIPMAP_LOD_BIAS))
        {
            if (activateGLTextureUnit(unit))
            {
                glTexEnvf(GL_TEXTURE_FILTER_CONTROL, GL_TEXTURE_LOD_BIAS, bias);
                activateGLTextureUnit(0);
            }
        }
        
    }

    /** See
          RenderSystem
         */
    override void _setTextureMatrix(size_t stage, const (Matrix4) xform)
    {
        if (stage >= mFixedFunctionTextureUnits)
        {
            // Can't do this
            return;
        }
        
        GLfloat[16] mat;
        makeGLMatrix(mat, xform);
        
        if (!activateGLTextureUnit(stage))
            return;
        glMatrixMode(GL_TEXTURE);
        
        // Load this matrix in
        glLoadMatrixf(mat.ptr);
        
        if (mUseAutoTextureMatrix)
        {
            // Concat auto matrix
            glMultMatrixf(mAutoTextureMatrix.ptr);
        }
        
        glMatrixMode(GL_MODELVIEW);
        activateGLTextureUnit(0);
    }

    /** See
          RenderSystem
         */
    override void _setSceneBlending(SceneBlendFactor sourceFactor, SceneBlendFactor destFactor, SceneBlendOperation op )
    {
        GLint sourceBlend = getBlendMode(sourceFactor);
        GLint destBlend = getBlendMode(destFactor);
        if(sourceFactor == SceneBlendFactor.SBF_ONE && destFactor == SceneBlendFactor.SBF_ZERO)
        {
            glDisable(GL_BLEND);
        }
        else
        {
            glEnable(GL_BLEND);
            glBlendFunc(sourceBlend, destBlend);
        }
        
        GLint func = derelict.opengl3.constants.GL_FUNC_ADD;
        switch(op)
        {
            case SceneBlendOperation.SBO_ADD:
                func = derelict.opengl3.constants.GL_FUNC_ADD;
                break;
            case SceneBlendOperation.SBO_SUBTRACT:
                func = derelict.opengl3.constants.GL_FUNC_SUBTRACT;
                break;
            case SceneBlendOperation.SBO_REVERSE_SUBTRACT:
                func = derelict.opengl3.constants.GL_FUNC_REVERSE_SUBTRACT;
                break;
            case SceneBlendOperation.SBO_MIN:
                func = derelict.opengl3.constants.GL_MIN;
                break;
            case SceneBlendOperation.SBO_MAX:
                func = derelict.opengl3.constants.GL_MAX;
                break;
            default:
                break;
        }

        //TODO Derelict3 just loads 1.2 glBlendEquation?
        if(GLEW_VERSION_1_2)
            glBlendEquation(func);
        /*if(GLEW_VERSION_1_4 || ARB_imaging)
        {
            glBlendEquation(func);
        }
        else if(EXT_blend_minmax && (func == GL_MIN || func == GL_MAX))
        {
            glBlendEquationEXT(func);
        }*/
    }

    /** See
          RenderSystem
         */
    override void _setSeparateSceneBlending(SceneBlendFactor sourceFactor, SceneBlendFactor destFactor, SceneBlendFactor sourceFactorAlpha, SceneBlendFactor destFactorAlpha, SceneBlendOperation op, SceneBlendOperation alphaOp )
    {
        GLint sourceBlend = getBlendMode(sourceFactor);
        GLint destBlend = getBlendMode(destFactor);
        GLint sourceBlendAlpha = getBlendMode(sourceFactorAlpha);
        GLint destBlendAlpha = getBlendMode(destFactorAlpha);
        
        if(sourceFactor == SceneBlendFactor.SBF_ONE && destFactor == SceneBlendFactor.SBF_ZERO && 
           sourceFactorAlpha == SceneBlendFactor.SBF_ONE && destFactorAlpha == SceneBlendFactor.SBF_ZERO)
        {
            glDisable(GL_BLEND);
        }
        else
        {
            glEnable(GL_BLEND);
            glBlendFuncSeparate(sourceBlend, destBlend, sourceBlendAlpha, destBlendAlpha);
        }
        
        GLint func = derelict.opengl3.constants.GL_FUNC_ADD, 
            alphaFunc = derelict.opengl3.constants.GL_FUNC_ADD;
        
        switch(op)
        {
            case SceneBlendOperation.SBO_ADD:
                func = derelict.opengl3.constants.GL_FUNC_ADD;
                break;
            case SceneBlendOperation.SBO_SUBTRACT:
                func = derelict.opengl3.constants.GL_FUNC_SUBTRACT;
                break;
            case SceneBlendOperation.SBO_REVERSE_SUBTRACT:
                func = derelict.opengl3.constants.GL_FUNC_REVERSE_SUBTRACT;
                break;
            case SceneBlendOperation.SBO_MIN:
                func = derelict.opengl3.constants.GL_MIN;
                break;
            case SceneBlendOperation.SBO_MAX:
                func = derelict.opengl3.constants.GL_MAX;
                break;
            default:
                break;
        }
        
        switch(alphaOp)
        {
            case SceneBlendOperation.SBO_ADD:
                alphaFunc = derelict.opengl3.constants.GL_FUNC_ADD;
                break;
            case SceneBlendOperation.SBO_SUBTRACT:
                alphaFunc = derelict.opengl3.constants.GL_FUNC_SUBTRACT;
                break;
            case SceneBlendOperation.SBO_REVERSE_SUBTRACT:
                alphaFunc = derelict.opengl3.constants.GL_FUNC_REVERSE_SUBTRACT;
                break;
            case SceneBlendOperation.SBO_MIN:
                alphaFunc = derelict.opengl3.constants.GL_MIN;
                break;
            case SceneBlendOperation.SBO_MAX:
                alphaFunc = derelict.opengl3.constants.GL_MAX;
                break;
            default:
                break;
        }
        
        if(GLEW_VERSION_2_0) {
            glBlendEquationSeparate(func, alphaFunc);
        }
        else if(EXT_blend_equation_separate) { //TODO Not in Derelict3, in core GL2.0?
            glBlendEquationSeparate(func, alphaFunc);
        }
    }

    /** See
          RenderSystem
         */
    //FIXME wtf not defined
    void _setSceneBlendingOperation(SceneBlendOperation op){}

    /** See
          RenderSystem
         */
    //FIXME wtf not defined
    void _setSeparateSceneBlendingOperation(SceneBlendOperation op, SceneBlendOperation alphaOp){}
    /** See
          RenderSystem
         */
    override void _setAlphaRejectSettings(CompareFunction func, ubyte value, bool alphaToCoverage)
    {
        bool a2c = false;
        static bool lasta2c = false;
        
        if(func == CompareFunction.CMPF_ALWAYS_PASS)
        {
            glDisable(GL_ALPHA_TEST);
        }
        else
        {
            glEnable(GL_ALPHA_TEST);
            a2c = alphaToCoverage;
            glAlphaFunc(convertCompareFunction(func), value / 255.0f);
        }
        
        if (a2c != lasta2c && getCapabilities().hasCapability(Capabilities.RSC_ALPHA_TO_COVERAGE))
        {
            if (a2c)
                glEnable(GL_SAMPLE_ALPHA_TO_COVERAGE);
            else
                glDisable(GL_SAMPLE_ALPHA_TO_COVERAGE);
            
            lasta2c = a2c;
        }
        
    }
    /** See
          RenderSystem
         */
    override void _setViewport(Viewport vp)
    {
        // Check if viewport is different
        if (!vp)
        {
            mActiveViewport = null;
            _setRenderTarget(null);
        }
        else if (vp != mActiveViewport || vp._isUpdated())
        {
            RenderTarget target = vp.getTarget();
            _setRenderTarget(target);
            mActiveViewport = vp;
            
            GLsizei x, y, w, h;
            
            // Calculate the "lower-left" corner of the viewport
            w = vp.getActualWidth();
            h = vp.getActualHeight();
            x = vp.getActualLeft();
            y = vp.getActualTop();
            if (!target.requiresTextureFlipping())
            {
                // Convert "upper-left" corner to "lower-left"
                y = target.getHeight() - h - y;
            }
            glViewport(x, y, w, h);
            
            // Configure the viewport clipping
            glScissor(x, y, w, h);
            
            vp._clearUpdatedFlag();
        }
    }

    /** See
          RenderSystem
         */
    override void _beginFrame()
    {
        if (mActiveViewport is null)
            throw new InvalidStateError(
                        "Cannot begin frame - no viewport selected.",
                        "GLRenderSystem._beginFrame");
        
        // Activate the viewport clipping
        glEnable(GL_SCISSOR_TEST);
    }

    /** See
          RenderSystem
         */
    override void _endFrame()
    {
        // Deactivate the viewport clipping.
        glDisable(GL_SCISSOR_TEST);
        // unbind GPU programs at end of frame
        // this is mostly to avoid holding bound programs that might get deleted
        // outside via the resource manager
        unbindGpuProgram(GpuProgramType.GPT_VERTEX_PROGRAM);
        unbindGpuProgram(GpuProgramType.GPT_FRAGMENT_PROGRAM);
    }

    /** See
          RenderSystem
         */
    override void _setCullingMode(CullingMode mode)
    {
        mCullingMode = mode;
        // NB: Because two-sided stencil API dependence of the front face, we must
        // use the same 'winding' for the front face everywhere. As the OGRE default
        // culling mode is clockwise, we also treat anticlockwise winding as front
        // face for consistently. On the assumption that, we can't change the front
        // face by glFrontFace anywhere.
        
        GLenum cullMode;
        
        switch( mode )
        {
            case CullingMode.CULL_NONE:
                glDisable( GL_CULL_FACE );
                return;
            default:
            case CullingMode.CULL_CLOCKWISE:
                if (mActiveRenderTarget && 
                    ((mActiveRenderTarget.requiresTextureFlipping() && !mInvertVertexWinding) ||
             (!mActiveRenderTarget.requiresTextureFlipping() && mInvertVertexWinding)))
                {
                    cullMode = GL_FRONT;
                }
                else
                {
                    cullMode = GL_BACK;
                }
                break;
            case CullingMode.CULL_ANTICLOCKWISE:
                if (mActiveRenderTarget && 
                    ((mActiveRenderTarget.requiresTextureFlipping() && !mInvertVertexWinding) ||
             (!mActiveRenderTarget.requiresTextureFlipping() && mInvertVertexWinding)))
                {
                    cullMode = GL_BACK;
                }
                else
                {
                    cullMode = GL_FRONT;
                }
                break;
        }
        
        glEnable( GL_CULL_FACE );
        glCullFace( cullMode );
    }

    /** See
          RenderSystem
         */
    override void _setDepthBufferParams(bool depthTest = true, bool depthWrite = true, CompareFunction depthFunction = CompareFunction.CMPF_LESS_EQUAL)
    {
        _setDepthBufferCheckEnabled(depthTest);
        _setDepthBufferWriteEnabled(depthWrite);
        _setDepthBufferFunction(depthFunction);
    }

    /** See
          RenderSystem
         */
    override void _setDepthBufferCheckEnabled(bool enabled = true)
    {
        if (enabled)
        {
            glClearDepth(1.0f);
            glEnable(GL_DEPTH_TEST);
        }
        else
        {
            glDisable(GL_DEPTH_TEST);
        }
    }

    /** See
          RenderSystem
         */
    override void _setDepthBufferWriteEnabled(bool enabled = true)
    {
        GLboolean flag = enabled ? GL_TRUE : GL_FALSE;
        glDepthMask( flag );  
        // Store for reference in _beginFrame
        mDepthWrite = enabled;
    }

    /** See
          RenderSystem
         */
    override void _setDepthBufferFunction(CompareFunction func = CompareFunction.CMPF_LESS_EQUAL)
    {
        glDepthFunc(convertCompareFunction(func));
    }

    /** See
          RenderSystem
         */
    override void _setDepthBias(float constantBias, float slopeScaleBias)
    {
        if (constantBias != 0 || slopeScaleBias != 0)
        {
            glEnable(GL_POLYGON_OFFSET_FILL);
            glEnable(GL_POLYGON_OFFSET_POINT);
            glEnable(GL_POLYGON_OFFSET_LINE);
            glPolygonOffset(-slopeScaleBias, -constantBias);
        }
        else
        {
            glDisable(GL_POLYGON_OFFSET_FILL);
            glDisable(GL_POLYGON_OFFSET_POINT);
            glDisable(GL_POLYGON_OFFSET_LINE);
        }
    }

    /** See
          RenderSystem
         */
    override void _setColourBufferWriteEnabled(bool red, bool green, bool blue, bool alpha)
    {
        glColorMask(red, green, blue, alpha);
        // record this
        mColourWrite[0] = red;
        mColourWrite[1] = blue;
        mColourWrite[2] = green;
        mColourWrite[3] = alpha;
    }

    /** See
          RenderSystem
         */
    override void _setFog(FogMode mode, ColourValue colour, Real density, Real start, Real end)
    {
        
        GLint fogMode;
        switch (mode)
        {
            case FogMode.FOG_EXP:
                fogMode = GL_EXP;
                break;
            case FogMode.FOG_EXP2:
                fogMode = GL_EXP2;
                break;
            case FogMode.FOG_LINEAR:
                fogMode = GL_LINEAR;
                break;
            default:
                // Give up on it
                glDisable(GL_FOG);
                return;
        }
        
        glEnable(GL_FOG);
        glFogi(GL_FOG_MODE, fogMode);
        GLfloat[4] fogColor = [colour.r, colour.g, colour.b, colour.a];
        glFogfv(GL_FOG_COLOR, fogColor.ptr);
        glFogf(GL_FOG_DENSITY, density);
        glFogf(GL_FOG_START, start);
        glFogf(GL_FOG_END, end);
        // XXX Hint here?
    }
    /** See
          RenderSystem
         */
    override void _convertProjectionMatrix(const (Matrix4) matrix,
                                  ref Matrix4 dest, bool forGpuProgram = false)
    {
        // no any conversion request for OpenGL
        dest = matrix;
    }
    /** See
          RenderSystem
         */
    override void _makeProjectionMatrix(const (Radian) fovy, Real aspect, Real nearPlane, Real farPlane, 
                               ref Matrix4 dest, bool forGpuProgram = false)
    {
        Radian thetaY = Radian( fovy / 2.0f );
        Real tanThetaY = Math.Tan(thetaY);
        //Real thetaX = thetaY * aspect;
        //Real tanThetaX = Math::Tan(thetaX);
        
        // Calc matrix elements
        Real w = (1.0f / tanThetaY) / aspect;
        Real h = 1.0f / tanThetaY;
        Real q, qn;
        if (farPlane == 0)
        {
            // Infinite far plane
            q = Frustum.INFINITE_FAR_PLANE_ADJUST - 1;
            qn = nearPlane * (Frustum.INFINITE_FAR_PLANE_ADJUST - 2);
        }
        else
        {
            q = -(farPlane + nearPlane) / (farPlane - nearPlane);
            qn = -2 * (farPlane * nearPlane) / (farPlane - nearPlane);
        }
        
        // NB This creates Z in range [-1,1]
        //
        // [ w   0   0   0  ]
        // [ 0   h   0   0  ]
        // [ 0   0   q   qn ]
        // [ 0   0   -1  0  ]
        
        dest = Matrix4.ZERO;
        dest[0, 0] = w;
        dest[1, 1] = h;
        dest[2, 2] = q;
        dest[2, 3] = qn;
        dest[3, 2] = -1;
        
    }
    /** See
          RenderSystem
         */
    override void _makeProjectionMatrix(Real left, Real right, Real bottom, Real top, 
                               Real nearPlane, Real farPlane, ref Matrix4 dest, bool forGpuProgram = false)
    {
        Real width = right - left;
        Real height = top - bottom;
        Real q, qn;
        if (farPlane == 0)
        {
            // Infinite far plane
            q = Frustum.INFINITE_FAR_PLANE_ADJUST - 1;
            qn = nearPlane * (Frustum.INFINITE_FAR_PLANE_ADJUST - 2);
        }
        else
        {
            q = -(farPlane + nearPlane) / (farPlane - nearPlane);
            qn = -2 * (farPlane * nearPlane) / (farPlane - nearPlane);
        }
        dest = Matrix4.ZERO;
        dest[0, 0] = 2 * nearPlane / width;
        dest[0, 2] = (right+left) / width;
        dest[1, 1] = 2 * nearPlane / height;
        dest[1, 2] = (top+bottom) / height;
        dest[2, 2] = q;
        dest[2, 3] = qn;
        dest[3, 2] = -1;
    }

    /** See
          RenderSystem
         */
    override void _makeOrthoMatrix(const (Radian) fovy, Real aspect, Real nearPlane, Real farPlane, 
                          ref Matrix4 dest, bool forGpuProgram = false)
    {
        Radian thetaY = Radian(fovy / 2.0f);
        Real tanThetaY = Math.Tan(thetaY);
        
        //Real thetaX = thetaY * aspect;
        Real tanThetaX = tanThetaY * aspect; //Math::Tan(thetaX);
        Real half_w = tanThetaX * nearPlane;
        Real half_h = tanThetaY * nearPlane;
        Real iw = 1.0 / half_w;
        Real ih = 1.0 / half_h;
        Real q;
        if (farPlane == 0)
        {
            q = 0;
        }
        else
        {
            q = 2.0 / (farPlane - nearPlane);
        }
        dest = Matrix4.ZERO;
        dest[0, 0] = iw;
        dest[1, 1] = ih;
        dest[2, 2] = -q;
        dest[2, 3] = - (farPlane + nearPlane)/(farPlane - nearPlane);
        dest[3, 3] = 1;
    }

    /** See
        RenderSystem
        */
    override void _applyObliqueDepthProjection(ref Matrix4 matrix, const (Plane) plane, 
                                      bool forGpuProgram)
    {
        // Thanks to Eric Lenyel for posting this calculation at www.terathon.com
        
        // Calculate the clip-space corner point opposite the clipping plane
        // as (sgn(clipPlane.x), sgn(clipPlane.y), 1, 1) and
        // transform it into camera space by multiplying it
        // by the inverse of the projection matrix
        
        Vector4 q;
        q.x = (Math.Sign(plane.normal.x) + matrix[0, 2]) / matrix[0, 0];
        q.y = (Math.Sign(plane.normal.y) + matrix[1, 2]) / matrix[1, 1];
        q.z = -1.0F;
        q.w = (1.0F + matrix[2, 2]) / matrix[2, 3];
        
        // Calculate the scaled plane vector
        Vector4 clipPlane4d = Vector4(plane.normal.x, plane.normal.y, plane.normal.z, plane.d);
        Vector4 c = clipPlane4d * (2.0F / (clipPlane4d.dotProduct(q)));
        
        // Replace the third row of the projection matrix
        matrix[2, 0] = c.x;
        matrix[2, 1] = c.y;
        matrix[2, 2] = c.z + 1.0F;
        matrix[2, 3] = c.w; 
    }

    /** See
          RenderSystem
         */
    //FIXME not defined
    void setClipPlane (ushort index, Real A, Real B, Real C, Real D)
    {
    }

    /** See
          RenderSystem
         */
    //FIXME not defined
    void enableClipPlane (ushort index, bool enable){}

    /** See
          RenderSystem
         */
    override void _setPolygonMode(PolygonMode level)
    {
        GLenum glmode;
        switch(level)
        {
            case PolygonMode.PM_POINTS:
                glmode = GL_POINT;
                break;
            case PolygonMode.PM_WIREFRAME:
                glmode = GL_LINE;
                break;
            default:
            case PolygonMode.PM_SOLID:
                glmode = GL_FILL;
                break;
        }
        glPolygonMode(GL_FRONT_AND_BACK, glmode);
    }

    /** See
          RenderSystem
         */
    override void setStencilCheckEnabled(bool enabled)
    {
        if (enabled)
        {
            glEnable(GL_STENCIL_TEST);
        }
        else
        {
            glDisable(GL_STENCIL_TEST);
        }
    }

    /** See
          RenderSystem.
         */
    override void setStencilBufferParams(CompareFunction func = CompareFunction.CMPF_ALWAYS_PASS, 
                                uint refValue = 0, uint compareMask = 0xFFFFFFFF, uint writeMask = 0xFFFFFFFF,
                                StencilOperation stencilFailOp = StencilOperation.SOP_KEEP, 
                                StencilOperation depthFailOp = StencilOperation.SOP_KEEP,
                                StencilOperation passOp = StencilOperation.SOP_KEEP, 
                                bool twoSidedOperation = false)
    {
        bool flip;
        mStencilWriteMask = writeMask;
        
        if (twoSidedOperation)
        {
            if (!mCurrentCapabilities.hasCapability(Capabilities.RSC_TWO_SIDED_STENCIL))
                throw new InvalidParamsError("2-sided stencils are not supported",
                            "GLRenderSystem.setStencilBufferParams");
            
            // NB: We should always treat CCW as front face for consistent with default
            // culling mode. Therefore, we must take care with two-sided stencil settings.
            flip = (mInvertVertexWinding && !mActiveRenderTarget.requiresTextureFlipping()) ||
                (!mInvertVertexWinding && mActiveRenderTarget.requiresTextureFlipping());
            if(GLEW_VERSION_2_0) // New GL2 commands
            {
                // Back
                glStencilMaskSeparate(GL_BACK, writeMask);
                glStencilFuncSeparate(GL_BACK, convertCompareFunction(func), refValue, compareMask);
                glStencilOpSeparate(GL_BACK, 
                                    convertStencilOp(stencilFailOp, !flip), 
                                    convertStencilOp(depthFailOp, !flip), 
                                    convertStencilOp(passOp, !flip));
                // Front
                glStencilMaskSeparate(GL_FRONT, writeMask);
                glStencilFuncSeparate(GL_FRONT, convertCompareFunction(func), refValue, compareMask);
                glStencilOpSeparate(GL_FRONT, 
                                    convertStencilOp(stencilFailOp, flip),
                                    convertStencilOp(depthFailOp, flip), 
                                    convertStencilOp(passOp, flip));
            }
            else // EXT_stencil_two_side
            {
                glEnable(GL_STENCIL_TEST_TWO_SIDE_EXT);
                // Back
                glActiveStencilFaceEXT(GL_BACK);
                glStencilMask(writeMask);
                glStencilFunc(convertCompareFunction(func), refValue, compareMask);
                glStencilOp(
                    convertStencilOp(stencilFailOp, !flip), 
                    convertStencilOp(depthFailOp, !flip), 
                    convertStencilOp(passOp, !flip));
                // Front
                glActiveStencilFaceEXT(GL_FRONT);
                glStencilMask(writeMask);
                glStencilFunc(convertCompareFunction(func), refValue, compareMask);
                glStencilOp(
                    convertStencilOp(stencilFailOp, flip),
                    convertStencilOp(depthFailOp, flip), 
                    convertStencilOp(passOp, flip));
            }
        }
        else
        {
            if(!GLEW_VERSION_2_0)
                glDisable(GL_STENCIL_TEST_TWO_SIDE_EXT);
            
            flip = false;
            glStencilMask(writeMask);
            glStencilFunc(convertCompareFunction(func), refValue, compareMask);
            glStencilOp(
                convertStencilOp(stencilFailOp, flip),
                convertStencilOp(depthFailOp, flip), 
                convertStencilOp(passOp, flip));
        }
    }
    /** See
          RenderSystem
         */
    override void _setTextureUnitFiltering(size_t unit, FilterType ftype, FilterOptions fo)
    {
        if (!activateGLTextureUnit(unit))
            return;
        final switch(ftype)
        {
            case FilterType.FT_MIN:
                mMinFilter = fo;
                // Combine with existing mip filter
                glTexParameteri(
                    mTextureTypes[unit],
                    GL_TEXTURE_MIN_FILTER, 
                    getCombinedMinMipFilter());
                break;
            case FilterType.FT_MAG:
                final switch (fo)
                {
                    case FilterOptions.FO_ANISOTROPIC: // GL treats linear and aniso the same
                    case FilterOptions.FO_LINEAR:
                        glTexParameteri(
                            mTextureTypes[unit],
                            GL_TEXTURE_MAG_FILTER, 
                            GL_LINEAR);
                        break;
                    case FilterOptions.FO_POINT:
                    case FilterOptions.FO_NONE:
                        glTexParameteri(
                            mTextureTypes[unit],
                            GL_TEXTURE_MAG_FILTER, 
                            GL_NEAREST);
                        break;
                }
                break;
            case FilterType.FT_MIP:
                mMipFilter = fo;
                // Combine with existing min filter
                glTexParameteri(
                    mTextureTypes[unit],
                    GL_TEXTURE_MIN_FILTER, 
                    getCombinedMinMipFilter());
                break;
        }
        
        activateGLTextureUnit(0);
    }

    /** See
          RenderSystem
         */
    override void _setTextureUnitCompareFunction(size_t unit, CompareFunction _function)
    {
        //TODO: implement (opengl 3 only?)
    }

    /** See
          RenderSystem
         */
    override void _setTextureUnitCompareEnabled(size_t unit, bool compare)
    {
        //TODO: implement (opengl 3 only?)
    }

    /** See
          RenderSystem
         */
    override void _setTextureLayerAnisotropy(size_t unit, uint maxAnisotropy)
    {
        if (!mCurrentCapabilities.hasCapability(Capabilities.RSC_ANISOTROPY))
            return;
        
        if (!activateGLTextureUnit(unit))
            return;
        
        GLfloat largest_supported_anisotropy = 0;
        glGetFloatv(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, &largest_supported_anisotropy);
        if (maxAnisotropy > largest_supported_anisotropy)
            maxAnisotropy = largest_supported_anisotropy ? cast(uint)(largest_supported_anisotropy) : 1;
        if (_getCurrentAnisotropy(unit) != maxAnisotropy)
            glTexParameterf(mTextureTypes[unit], GL_TEXTURE_MAX_ANISOTROPY_EXT, maxAnisotropy);
        
        activateGLTextureUnit(0);
    }

    /** See
          RenderSystem
         */
    override void setVertexDeclaration(VertexDeclaration decl)
    {
    }

    /** See
          RenderSystem
         */
    override void setVertexBufferBinding(VertexBufferBinding binding)
    {
    }

    /** See
          RenderSystem
         */
    override void _render(RenderOperation op)
    {
        // Call super class
        RenderSystem._render(op);
        debug(DBGRENDER) stderr.writeln("_render:", op.operationType);
        
        static if (RTSHADER_SYSTEM_BUILD_CORE_SHADERS)
        {
            if ( ! mEnableFixedPipeline && !mRealCapabilities.hasCapability(Capabilities.RSC_FIXED_FUNCTION)
                && 
                (
                ( mCurrentVertexProgram == null ) ||
                ( mCurrentFragmentProgram == null && op.operationType != RenderOperation.OperationType.OT_POINT_LIST)          
                )
                ) 
            {
                throw new RenderingApiError(
                            "Attempted to render using the fixed pipeline when it is disabled.",
                            "GLRenderSystem._render");
            }
        }
        
        SharedPtr!HardwareVertexBuffer globalInstanceVertexBuffer = getGlobalInstanceVertexBuffer();
        VertexDeclaration globalVertexDeclaration = getGlobalInstanceVertexBufferVertexDeclaration();
        bool hasInstanceData = (op.useGlobalInstancingVertexBufferIsAvailable &&
                                !globalInstanceVertexBuffer.isNull() && globalVertexDeclaration !is null) ||
            op.vertexData.vertexBufferBinding.getHasInstanceData();
        
        size_t numberOfInstances = op.numberOfInstances;
        
        if (op.useGlobalInstancingVertexBufferIsAvailable)
        {
            numberOfInstances *= getGlobalNumberOfInstances();
        }
        
        //const (VertexDeclaration.VertexElementList)
        const(VertexDeclaration.VertexElementList) decl = 
            op.vertexData.vertexDeclaration.getElements();

        size_t maxSource = 0;
        
        foreach (elem; decl)
        {
            size_t source = elem.getSource();
            if ( maxSource < source )
            {
                maxSource = source;   
            }
            
            if (!op.vertexData.vertexBufferBinding.isBufferBound(cast(ushort)source))
                continue; // skip unbound elements
            
            SharedPtr!HardwareVertexBuffer vertexBuffer = cast(SharedPtr!HardwareVertexBuffer)
                op.vertexData.vertexBufferBinding.getBuffer(cast(ushort)source);
            
            bindVertexElementToGpu(elem, vertexBuffer, op.vertexData.vertexStart, 
                                   mRenderAttribsBound, mRenderInstanceAttribsBound);
        }
        
        if( !globalInstanceVertexBuffer.isNull() && globalVertexDeclaration !is null )
        {
            foreach (elem; globalVertexDeclaration.getElements())
            {
                bindVertexElementToGpu(elem, globalInstanceVertexBuffer, 0, 
                                       mRenderAttribsBound, mRenderInstanceAttribsBound);
                
            }
        }
        
        bool multitexturing = (getCapabilities().getNumTextureUnits() > 1);
        if (multitexturing)
            glClientActiveTextureARB(GL_TEXTURE0);
        
        // Find the correct type to render
        GLint primType;
        //Use adjacency if there is a geometry program and it requested adjacency info
        bool useAdjacency = (mGeometryProgramBound && mCurrentGeometryProgram && mCurrentGeometryProgram.isAdjacencyInfoRequired());
        switch (op.operationType)
        {
            case RenderOperation.OperationType.OT_POINT_LIST:
                primType = GL_POINTS;
                break;
            case RenderOperation.OperationType.OT_LINE_LIST:
                primType = useAdjacency ? GL_LINES_ADJACENCY : GL_LINES;
                break;
            case RenderOperation.OperationType.OT_LINE_STRIP:
                primType = useAdjacency ? GL_LINE_STRIP_ADJACENCY : GL_LINE_STRIP;
                break;
            default:
            case RenderOperation.OperationType.OT_TRIANGLE_LIST:
                primType = useAdjacency ? GL_TRIANGLES_ADJACENCY : GL_TRIANGLES;
                break;
            case RenderOperation.OperationType.OT_TRIANGLE_STRIP:
                primType = useAdjacency ? GL_TRIANGLE_STRIP_ADJACENCY : GL_TRIANGLE_STRIP;
                break;
            case RenderOperation.OperationType.OT_TRIANGLE_FAN:
                primType = GL_TRIANGLE_FAN;
                break;
        }
        
        if (op.useIndexes)
        {
            void* pBufferData = null;
            
            if(mCurrentCapabilities.hasCapability(Capabilities.RSC_VBO))
            {
                glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 
                                (cast(GLHardwareIndexBuffer)op.indexData.indexBuffer.get()).getGLBufferId());
                
                pBufferData = VBO_BUFFER_OFFSET(
                    op.indexData.indexStart * op.indexData.indexBuffer.get().getIndexSize());
            }
            else
            {
                pBufferData = (cast(GLDefaultHardwareIndexBuffer)
                    op.indexData.indexBuffer.get()).getDataPtr(
                    op.indexData.indexStart * op.indexData.indexBuffer.get().getIndexSize());
            }
            
            GLenum indexType = (op.indexData.indexBuffer.get().getType() == HardwareIndexBuffer.IndexType.IT_16BIT) ? GL_UNSIGNED_SHORT : GL_UNSIGNED_INT;
            
            do
            {
                // Update derived depth bias
                if (mDerivedDepthBias && mCurrentPassIterationNum > 0)
                {
                    _setDepthBias(mDerivedDepthBiasBase + 
                                  mDerivedDepthBiasMultiplier * mCurrentPassIterationNum, 
                                  mDerivedDepthBiasSlopeScale);
                }
                if(hasInstanceData)
                {
                    glDrawElementsInstanced(primType, cast(GLint)op.indexData.indexCount, indexType, pBufferData, cast(GLint)numberOfInstances);
                }
                else
                {
                    debug(DBGRENDER) stderr.writeln("glDrawElements:", primType, ", Idx:", op.indexData.indexCount, " IdxType:", indexType, 
                                         ", Buffer:", pBufferData);
                    glDrawElements(primType, cast(GLint)op.indexData.indexCount, cast(GLint)indexType, pBufferData);
                }
            } while (updatePassIterationRenderState());
            
        }
        else
        {
            do
            {
                // Update derived depth bias
                if (mDerivedDepthBias && mCurrentPassIterationNum > 0)
                {
                    _setDepthBias(mDerivedDepthBiasBase + 
                                  mDerivedDepthBiasMultiplier * mCurrentPassIterationNum, 
                                  mDerivedDepthBiasSlopeScale);
                }
                
                if(hasInstanceData)
                {
                    //TODO Getting into GL31 territory?
                    glDrawArraysInstanced(primType, 0, cast(GLint)op.vertexData.vertexCount, cast(GLint)numberOfInstances);
                }
                else
                {
                    debug stderr.writeln("glDrawArrays:", primType, ", VCount:",op.vertexData.vertexCount);
                    glDrawArrays(primType, 0, cast(GLint)op.vertexData.vertexCount);
                }
            } while (updatePassIterationRenderState());
        }
        
        glDisableClientState( GL_VERTEX_ARRAY );
        // only valid up to GL_MAX_TEXTURE_UNITS, which is recorded in mFixedFunctionTextureUnits
        if (multitexturing)
        {
            for (int i = 0; i < mFixedFunctionTextureUnits; i++)
            {
                glClientActiveTextureARB(GL_TEXTURE0 + i);
                glDisableClientState( GL_TEXTURE_COORD_ARRAY );
            }
            glClientActiveTextureARB(GL_TEXTURE0);
        }
        else
        {
            glDisableClientState( GL_TEXTURE_COORD_ARRAY );
        }
        glDisableClientState( GL_NORMAL_ARRAY );
        glDisableClientState( GL_COLOR_ARRAY );
        if (EXT_secondary_color)
        {
            glDisableClientState( GL_SECONDARY_COLOR_ARRAY );
        }
        // unbind any custom attributes
        foreach (ai; mRenderAttribsBound)
        {
            glDisableVertexAttribArrayARB(ai); 
        }
        
        // unbind any instance attributes
        foreach (ai; mRenderInstanceAttribsBound)
        {
            glVertexAttribDivisorARB(ai, 0); 
        }
        
        mRenderAttribsBound.clear();
        mRenderInstanceAttribsBound.clear();
        
        glColor4f(1,1,1,1);
        if (EXT_secondary_color)
        {
            glSecondaryColor3fEXT(0.0f, 0.0f, 0.0f);
        }
        
    }
    
    /** See
          RenderSystem
         */
    override void bindGpuProgram(GpuProgram prg)
    {
        if (prg is null)
        {
            throw new RenderingApiError(
                        "Null program bound.",
                        "GLRenderSystem.bindGpuProgram");
        }
        
        GLGpuProgram glprg = cast(GLGpuProgram)(prg);
        
        // Unbind previous gpu program first.
        //
        // Note:
        //  1. Even if both previous and current are the same object, we can't
        //     bypass re-bind completely since the object itself maybe modified.
        //     But we can bypass unbind based on the assumption that object
        //     internally GL program type shouldn't be changed after it has
        //     been created. The behavior of bind to a GL program type twice
        //     should be same as unbind and rebind that GL program type, even
        //     for difference objects.
        //  2. We also assumed that the program's type (vertex or fragment) should
        //     not be changed during it's in using. If not, the following switch
        //     statement will confuse GL state completely, and we can't fix it
        //     here. To fix this case, we must coding the program implementation
        //     itself, if type is changing (during load/unload, etc), and it's inuse,
        //     unbind and notify render system to correct for its state.
        //
        switch (glprg.getType())
        {
            case GpuProgramType.GPT_VERTEX_PROGRAM:
                if (mCurrentVertexProgram != glprg)
                {
                    if (mCurrentVertexProgram)
                        mCurrentVertexProgram.unbindProgram();
                    mCurrentVertexProgram = glprg;
                }
                break;
                
            case GpuProgramType.GPT_FRAGMENT_PROGRAM:
                if (mCurrentFragmentProgram != glprg)
                {
                    if (mCurrentFragmentProgram)
                        mCurrentFragmentProgram.unbindProgram();
                    mCurrentFragmentProgram = glprg;
                }
                break;
            case GpuProgramType.GPT_GEOMETRY_PROGRAM:
                if (mCurrentGeometryProgram != glprg)
                {
                    if (mCurrentGeometryProgram)
                        mCurrentGeometryProgram.unbindProgram();
                    mCurrentGeometryProgram = glprg;
                }
                break;
            default:
                assert(0, "Unsupported program type");//TODO Assert?
        }
        
        // Bind the program
        glprg.bindProgram();
        
        RenderSystem.bindGpuProgram(prg);
    }

    /** See
          RenderSystem
         */
    override void unbindGpuProgram(GpuProgramType gptype)
    {
        
        if (gptype == GpuProgramType.GPT_VERTEX_PROGRAM && mCurrentVertexProgram)
        {
            mActiveVertexGpuProgramParameters.setNull();
            mCurrentVertexProgram.unbindProgram();
            mCurrentVertexProgram = null;
        }
        else if (gptype == GpuProgramType.GPT_GEOMETRY_PROGRAM && mCurrentGeometryProgram)
        {
            mActiveGeometryGpuProgramParameters.setNull();
            mCurrentGeometryProgram.unbindProgram();
            mCurrentGeometryProgram = null;
        }
        else if (gptype == GpuProgramType.GPT_FRAGMENT_PROGRAM && mCurrentFragmentProgram)
        {
            mActiveFragmentGpuProgramParameters.setNull();
            mCurrentFragmentProgram.unbindProgram();
            mCurrentFragmentProgram = null;
        }
        RenderSystem.unbindGpuProgram(gptype);
    }

    /** See
          RenderSystem
         */
    override void bindGpuProgramParameters(GpuProgramType gptype, 
                                  SharedPtr!GpuProgramParameters params, ushort variabilityMask)
    {
        if (variabilityMask & cast(ushort)GpuParamVariability.GPV_GLOBAL)
        {
            // We could maybe use GL_EXT_bindable_uniform here to produce Dx10-style
            // shared constant buffers, but GPU support seems fairly weak?
            // for now, just copy
            params.get()._copySharedParams();
        }
        
        switch (gptype)
        {
            case GpuProgramType.GPT_VERTEX_PROGRAM:
                mActiveVertexGpuProgramParameters = params;
                mCurrentVertexProgram.bindProgramParameters(params, variabilityMask);
                break;
            case GpuProgramType.GPT_GEOMETRY_PROGRAM:
                mActiveGeometryGpuProgramParameters = params;
                mCurrentGeometryProgram.bindProgramParameters(params, variabilityMask);
                break;
            case GpuProgramType.GPT_FRAGMENT_PROGRAM:
                mActiveFragmentGpuProgramParameters = params;
                mCurrentFragmentProgram.bindProgramParameters(params, variabilityMask);
                break;
            default:
                assert(0,"Unsupported program type");
        }
    }

    /** See
          RenderSystem
         */
    override void bindGpuProgramPassIterationParameters(GpuProgramType gptype)
    {
        switch (gptype)
        {
            case GpuProgramType.GPT_VERTEX_PROGRAM:
                mCurrentVertexProgram.bindProgramPassIterationParameters(mActiveVertexGpuProgramParameters);
                break;
            case GpuProgramType.GPT_GEOMETRY_PROGRAM:
                mCurrentGeometryProgram.bindProgramPassIterationParameters(mActiveGeometryGpuProgramParameters);
                break;
            case GpuProgramType.GPT_FRAGMENT_PROGRAM:
                mCurrentFragmentProgram.bindProgramPassIterationParameters(mActiveFragmentGpuProgramParameters);
                break;
            default:
                assert(0,"Unsupported program type");
        }
    }

    /** See
          RenderSystem
         */
    override void setScissorTest(bool enabled, size_t left = 0, size_t top = 0, size_t right = 800, size_t bottom = 600)
    {
        // If request texture flipping, use "upper-left", otherwise use "lower-left"
        bool flipping = mActiveRenderTarget.requiresTextureFlipping();
        //  GL measures from the bottom, not the top
        size_t targetHeight = mActiveRenderTarget.getHeight();
        // Calculate the "lower-left" corner of the viewport
        GLsizei x = 0, y = 0, w = 0, h = 0;
        
        if (enabled)
        {
            glEnable(GL_SCISSOR_TEST);
            // NB GL uses width / height rather than right / bottom
            x = cast(GLsizei)left;
            if (flipping)
                y = cast(GLsizei)top;
            else
                y = cast(GLsizei)(targetHeight - bottom);
            w = cast(GLsizei)(right - left);
            h = cast(GLsizei)(bottom - top);
            glScissor(x, y, w, h);
        }
        else
        {
            glDisable(GL_SCISSOR_TEST);
            // GL requires you to reset the scissor when disabling
            w = mActiveViewport.getActualWidth();
            h = mActiveViewport.getActualHeight();
            x = mActiveViewport.getActualLeft();
            if (flipping)
                y = mActiveViewport.getActualTop();
            else
                y = cast(GLsizei)(targetHeight - mActiveViewport.getActualTop() - h);
            glScissor(x, y, w, h);
        }
    }

    override void clearFrameBuffer(uint buffers, 
                          const(ColourValue) colour = ColourValue.Black, 
                          Real depth = 1.0f, ushort stencil = 0)
    {
        bool colourMask = !mColourWrite[0] || !mColourWrite[1] 
        || !mColourWrite[2] || !mColourWrite[3]; 
        
        GLbitfield flags = 0;
        if (buffers & FrameBufferType.FBT_COLOUR)
        {
            flags |= GL_COLOR_BUFFER_BIT;
            // Enable buffer for writing if it isn't
            if (colourMask)
            {
                glColorMask(true, true, true, true);
            }
            glClearColor(colour.r, colour.g, colour.b, colour.a);
        }
        if (buffers & FrameBufferType.FBT_DEPTH)
        {
            flags |= GL_DEPTH_BUFFER_BIT;
            // Enable buffer for writing if it isn't
            if (!mDepthWrite)
            {
                glDepthMask( GL_TRUE );
            }
            glClearDepth(depth);
        }
        if (buffers & FrameBufferType.FBT_STENCIL)
        {
            flags |= GL_STENCIL_BUFFER_BIT;
            // Enable buffer for writing if it isn't
            glStencilMask(0xFFFFFFFF);
            
            glClearStencil(stencil);
        }
        
        // Should be enable scissor test due the clear region is
        // relied on scissor box bounds.
        GLboolean scissorTestEnabled = glIsEnabled(GL_SCISSOR_TEST);
        if (!scissorTestEnabled)
        {
            glEnable(GL_SCISSOR_TEST);
        }
        
        // Sets the scissor box as same as viewport
        GLint[4] viewport = [0, 0, 0, 0];
        GLint[4] scissor  = [0, 0, 0, 0];
        glGetIntegerv(GL_VIEWPORT, viewport.ptr);
        glGetIntegerv(GL_SCISSOR_BOX, scissor.ptr);
        bool scissorBoxDifference =
            viewport[0] != scissor[0] || viewport[1] != scissor[1] ||
                viewport[2] != scissor[2] || viewport[3] != scissor[3];
        if (scissorBoxDifference)
        {
            glScissor(viewport[0], viewport[1], viewport[2], viewport[3]);
        }
        
        // Clear buffers
        glClear(flags);
        
        // Restore scissor box
        if (scissorBoxDifference)
        {
            glScissor(scissor[0], scissor[1], scissor[2], scissor[3]);
        }
        // Restore scissor test
        if (!scissorTestEnabled)
        {
            glDisable(GL_SCISSOR_TEST);
        }
        
        // Reset buffer write state
        if (!mDepthWrite && (buffers & FrameBufferType.FBT_DEPTH))
        {
            glDepthMask( GL_FALSE );
        }
        if (colourMask && (buffers & FrameBufferType.FBT_COLOUR))
        {
            glColorMask(mColourWrite[0], mColourWrite[1], mColourWrite[2], mColourWrite[3]);
        }
        if (buffers & FrameBufferType.FBT_STENCIL)
        {
            glStencilMask(mStencilWriteMask);
        }
    }

    override HardwareOcclusionQuery createHardwareOcclusionQuery()
    {
        GLHardwareOcclusionQuery ret = new GLHardwareOcclusionQuery(); 
        mHwOcclusionQueries ~= ret;
        return ret;
    }

    override Real getHorizontalTexelOffset()
    {
        // No offset in GL
        return 0.0f;
    }

    override Real getVerticalTexelOffset()
    {
        // No offset in GL
        return 0.0f;
    }

    override Real getMinimumDepthInputValue()
    {
        // Range [-1.0f, 1.0f]
        return -1.0f;
    }

    override Real getMaximumDepthInputValue()
    {
        // Range [-1.0f, 1.0f]
        return 1.0f;
    }

    //TODO init mutex
    Mutex mThreadInitMutex;
    override void registerThread()
    {
        synchronized(mThreadInitMutex)
        {
            // This is only valid once we've created the main context
            if (!mMainContext)
            {
                throw new InvalidParamsError(
                            "Cannot register a background thread before the main context "
                            "has been created.", 
                            "GLRenderSystem.registerThread");
            }
            
            // Create a new context for this thread. Cloning from the main context
            // will ensure that resources are shared with the main context
            // We want a separate context so that we can safely create GL
            // objects in parallel with the main thread
            GLContext newContext = mMainContext.clone();
            mBackgroundContextList.insert(newContext);
            
            // Bind this new context to this thread. 
            newContext.setCurrent();
            
            _oneTimeContextInitialization();
            newContext.setInitialized();
        }
    }

    override void unregisterThread()
    {
        // nothing to do here?
        // Don't need to worry about active context, just make sure we delete
        // on shutdown.
        
    }

    override void preExtraThreadsStarted()
    {
        synchronized(mThreadInitMutex)
        {
            // free context, we'll need this to share lists
            if(mCurrentContext)
                mCurrentContext.endCurrent();
        }
    }

    override void postExtraThreadsStarted()
    {
        synchronized(mThreadInitMutex)
        {
            // reacquire context
            if(mCurrentContext)
                mCurrentContext.setCurrent();
        }
    }
    
    // ----------------------------------
    // GLRenderSystem specific members
    // ----------------------------------
    /** One time initialization for the RenderState of a context. Things that
            only need to be set once, like the LightingModel can be defined here.
         */
    void _oneTimeContextInitialization()
    {
        if (GLEW_VERSION_1_2)
        {
            // Set nicer lighting model -- d3d9 has this by default
            glLightModeli(GL_LIGHT_MODEL_COLOR_CONTROL, GL_SEPARATE_SPECULAR_COLOR);
            glLightModeli(GL_LIGHT_MODEL_LOCAL_VIEWER, 1);        
        }
        if (GLEW_VERSION_1_4)
        {
            glEnable(GL_COLOR_SUM);
            glDisable(GL_DITHER);
        }
        
        // Check for FSAA
        // Enable the extension if it was enabled by the GLSupport
        if (mGLSupport.checkExtension("GL_ARB_multisample"))
        {
            int fsaa_active = false;
            glGetIntegerv(GL_SAMPLE_BUFFERS, cast(GLint*)&fsaa_active);
            if(fsaa_active)
            {
                glEnable(GL_MULTISAMPLE);
                LogManager.getSingleton().logMessage("Using FSAA from GL_ARB_multisample extension.");
            }            
        }
        
        (cast(GLTextureManager)mTextureManager).createWarningTexture();
    }

    /** Switch GL context, dealing with involved internal cached states too
        */
    void _switchContext(GLContext context)
    {
        // Unbind GPU programs and rebind to new context later, because
        // scene manager treat render system as ONE 'context' ONLY, and it
        // cached the GPU programs using state.
        if (mCurrentVertexProgram)
            mCurrentVertexProgram.unbindProgram();
        if (mCurrentGeometryProgram)
            mCurrentGeometryProgram.unbindProgram();
        if (mCurrentFragmentProgram)
            mCurrentFragmentProgram.unbindProgram();
        
        // Disable lights
        for (ushort i = 0; i < mCurrentLights; ++i)
        {
            setGLLight(i, null);
            mLights[i] = null;
        }
        mCurrentLights = 0;
        
        // Disable textures
        _disableTextureUnitsFrom(0);
        
        // It's ready for switching
        if (mCurrentContext)
            mCurrentContext.endCurrent();
        mCurrentContext = context;
        mCurrentContext.setCurrent();
        
        // Check if the context has already done one-time initialisation
        if(!mCurrentContext.getInitialized()) 
        {
            _oneTimeContextInitialization();
            mCurrentContext.setInitialized();
        }
        
        // Rebind GPU programs to new context
        if (mCurrentVertexProgram)
            mCurrentVertexProgram.bindProgram();
        if (mCurrentGeometryProgram)
            mCurrentGeometryProgram.bindProgram();
        if (mCurrentFragmentProgram)
            mCurrentFragmentProgram.bindProgram();
        
        // Must reset depth/colour write mask to according with user desired, otherwise,
        // clearFrameBuffer would be wrong because the value we are recorded may be
        // difference with the really state stored in GL context.
        glDepthMask(mDepthWrite);
        glColorMask(mColourWrite[0], mColourWrite[1], mColourWrite[2], mColourWrite[3]);
        glStencilMask(mStencilWriteMask);
        
    }
    /**
         * Set current render target to target, enabling its GL context if needed
         */
    override void _setRenderTarget(RenderTarget target)
    {
        // Unbind frame buffer object
        if(mActiveRenderTarget)
            mRTTManager.unbind(mActiveRenderTarget);
        
        mActiveRenderTarget = target;
        if (target)
        {
            // Switch context if different from current one
            GLContext newContext = null;
            target.getCustomAttribute(GLRenderTexture.CustomAttributeString_GLCONTEXT, &newContext);
            if(newContext && mCurrentContext != newContext) 
            {
                _switchContext(newContext);
            }
            
            //Check the FBO's depth buffer status
            GLDepthBuffer depthBuffer = cast(GLDepthBuffer)(target.getDepthBuffer());
            
            if( target.getDepthBufferPool() != DepthBuffer.PoolId.POOL_NO_DEPTH &&
               (!depthBuffer || depthBuffer.getGLContext() != mCurrentContext ) )
            {
                //Depth is automatically managed and there is no depth buffer attached to this RT
                //or the Current context doesn't match the one this Depth buffer was created with
                setDepthBufferFor( target );
            }
            
            // Bind frame buffer object
            mRTTManager.bind(target);

            //XXX was EXT_
            if (ARB_framebuffer_sRGB)
            {
                // Enable / disable sRGB states
                if (target.isHardwareGammaEnabled())
                {
                    glEnable(GL_FRAMEBUFFER_SRGB);
                    
                    // Note: could test GL_FRAMEBUFFER_SRGB_CAPABLE_EXT here before
                    // enabling, but GL spec says incapable surfaces ignore the setting
                    // anyway. We test the capability to enable isHardwareGammaEnabled.
                }
                else
                {
                    glDisable(GL_FRAMEBUFFER_SRGB);
                }
            }
        }
    }

    /** Unregister a render target.context mapping. If the context of target 
            is the current context, change the context to the main context so it
            can be destroyed safely. 
            
            @note This is automatically called by the destructor of 
            GLContext.
         */
    void _unregisterContext(GLContext context)
    {
        if(mCurrentContext == context) {
            // Change the context to something else so that a valid context
            // remains active. When this is the main context being unregistered,
            // we set the main context to 0.
            if(mCurrentContext != mMainContext) {
                _switchContext(mMainContext);
            } else {
                /// No contexts remain
                mCurrentContext.endCurrent();
                mCurrentContext = null;
                mMainContext = null;
            }
        }
    }

    /** Returns the main context */
    GLContext _getMainContext() {return mMainContext;} 
    
    /// @copydoc RenderSystem::getDisplayMonitorCount
    override uint getDisplayMonitorCount() const
    {
        return mGLSupport.getDisplayMonitorCount();
    }
    
    /// @copydoc RenderSystem::hasAnisotropicMipMapFilter
    override bool hasAnisotropicMipMapFilter() const { return false; }
    
    /// @copydoc RenderSystem::beginProfileEvent
    override void beginProfileEvent( string eventName )
    {
        markProfileEvent("Begin Event: " ~ eventName);
    }
    
    /// @copydoc RenderSystem::endProfileEvent
    override void endProfileEvent()
    {
        markProfileEvent("End Event");
    }
    
    /// @copydoc RenderSystem::markProfileEvent
    override void markProfileEvent( string eventName )
    {
        if( eventName is null || !eventName.length )
            return;

        //FIXME Ignoring GREMEDY
        //if(GLEW_GREMEDY_string_marker)
        //    glStringMarkerGREMEDY(eventName.length(), eventName.c_str());
    }
}
