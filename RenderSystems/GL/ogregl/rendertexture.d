module ogregl.rendertexture;
import ogre.rendersystem.rendertexture;
import ogre.singleton;
import ogre.exception;
import ogre.image.pixelformat;
import ogre.rendersystem.rendertarget;
import derelict.opengl3.gl;
import ogregl.hardwarepixelbuffer;
import ogre.image.images;

/** GL surface descriptor. Points to a 2D surface that can be rendered to. 
    */
struct GLSurfaceDesc
{
public:
    GLHardwarePixelBuffer buffer;
    size_t zoffset;
    uint numSamples;
    
    //GLSurfaceDesc() :buffer(0), zoffset(0), numSamples(0) {}
}

/** Base class for GL Render Textures
    */
class GLRenderTexture: RenderTexture
{
public:
    this(string name, const(GLSurfaceDesc) target, bool writeGamma, uint fsaa)
    {
        super(cast(GLHardwarePixelBuffer)target.buffer, target.zoffset);
        mName = name;
        mHwGamma = writeGamma;
        mFSAA = fsaa;
    }

    ~this() {}
    
    override bool requiresTextureFlipping() const { return true; }
    
    enum string CustomAttributeString_FBO = "FBO";
    enum string CustomAttributeString_TARGET = "TARGET";
    enum string CustomAttributeString_GLCONTEXT = "GLCONTEXT";
}

/** Manager/factory for RenderTextures.
    */
class GLRTTManager
{
    //TODO Can't be singleton and abstract too. Subclasses must mixin Singleton then.
    mixin Singleton!GLRTTManager;
    
public:
    ~this() {}
    
    /** Create a texture rendertarget object
        */
    //abstract 
    RenderTexture createRenderTexture(string name, GLSurfaceDesc target, bool writeGamma, uint fsaa)
    {
        throw new NotImplementedError("Abstract function");
    }
    
    /** Check if a certain format is usable as rendertexture format
        */
    //abstract 
    bool checkFormat(PixelFormat format)
    {
        throw new NotImplementedError("Abstract function");
    }
    
    /** Bind a certain render target.
        */
    //abstract 
    void bind(RenderTarget target)
    {
        throw new NotImplementedError("Abstract function");
    }
    
    /** Unbind a certain render target. This is called before binding another RenderTarget, and
            before the context is switched. It can be used to do a copy, or just be a noop if direct
            binding is used.
        */
    //abstract 
    void unbind(RenderTarget target)
    {
        throw new NotImplementedError("Abstract function");
    }
    
    void getBestDepthStencil(GLenum internalFormat, ref GLenum depthFormat, ref GLenum stencilFormat)
    {
        depthFormat = derelict.opengl3.constants.GL_NONE;
        stencilFormat = derelict.opengl3.constants.GL_NONE;
    }
    
    /** Create a multi render target 
        */
    MultiRenderTarget createMultiRenderTarget(string name)
    {
        throw new NotImplementedError("MultiRenderTarget can only be used with GL_EXT_framebuffer_object extension", "GLRTTManager.createMultiRenderTarget");
    }
    
    /** Get the closest supported alternative format. If format is supported, returns format.
        */
    PixelFormat getSupportedAlternative(PixelFormat format)
    {
        if(checkFormat(format))
            return format;
        /// Find first alternative
        PixelComponentType pct = PixelUtil.getComponentType(format);
        final switch(pct)
        {
            case PixelComponentType.PCT_BYTE: format = PixelFormat.PF_A8R8G8B8; break;
            case PixelComponentType.PCT_SHORT: format = PixelFormat.PF_SHORT_RGBA; break;
            case PixelComponentType.PCT_FLOAT16: format = PixelFormat.PF_FLOAT16_RGBA; break;
            case PixelComponentType.PCT_FLOAT32: format = PixelFormat.PF_FLOAT32_RGBA; break;
            case PixelComponentType.PCT_COUNT: break;
        }
        if(checkFormat(format))
            return format;
        /// If none at all, return to default
        return PixelFormat.PF_A8R8G8B8;
    }
}

/** RenderTexture for simple copying from frame buffer
    */
class GLCopyingRenderTexture: GLRenderTexture
{
public:
    this(GLCopyingRTTManager manager, string name, const(GLSurfaceDesc) target, 
                           bool writeGamma, uint fsaa)
    {
        super(name, target, writeGamma, fsaa);
    }
    
    override void getCustomAttribute(string name, void* pData)
    {
        if( name == GLRenderTexture.CustomAttributeString_TARGET )
        {
            GLSurfaceDesc* target = cast(GLSurfaceDesc*)pData;
            target.buffer = cast(GLHardwarePixelBuffer)mBuffer;
            target.zoffset = mZOffset;
        }
    }
}

/** Simple, copying manager/factory for RenderTextures. This is only used as the last fallback if
        both PBuffers and FBOs aren't supported.
    */
class GLCopyingRTTManager: GLRTTManager
{
    mixin Singleton!GLRTTManager;
public:
    this(){}

    ~this(){}
    
    /** @copydoc GLRTTManager::createRenderTexture
        */
    override RenderTexture createRenderTexture(string name, GLSurfaceDesc target, bool writeGamma, uint fsaa)
    {
        return new GLCopyingRenderTexture(this, name, target, writeGamma, fsaa);
    }
    
    /** @copydoc GLRTTManager::checkFormat
        */
    override bool checkFormat(PixelFormat format)
    { 
        return true; 
    }
    
    /** @copydoc GLRTTManager::bind
        */
    override void bind(RenderTarget target)
    {
        // Nothing to do here
    }
    
    /** @copydoc GLRTTManager::unbind
        */
    override void unbind(RenderTarget target)
    {
        // Copy on unbind
        GLSurfaceDesc surface;
        surface.buffer = null;
        target.getCustomAttribute(GLRenderTexture.CustomAttributeString_TARGET, &surface);
        if(surface.buffer !is null)
            (cast(GLTextureBuffer)surface.buffer).copyFromFramebuffer(surface.zoffset);
    }
}