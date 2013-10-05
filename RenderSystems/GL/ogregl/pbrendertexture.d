module ogregl.pbrendertexture;

import ogre.rendersystem.rendertarget;
import ogre.image.pixelformat;
import ogre.rendersystem.rendertexture;
import ogre.image.images;

import ogregl.support;
import ogregl.context;
import ogregl.rendertexture;
import ogregl.pbuffer;
import ogregl.hardwarepixelbuffer;

/** RenderTexture that uses a PBuffer (offscreen rendering context) for rendering.
    */
//class GLPBRTTManager;
class GLPBRenderTexture: GLRenderTexture
{
public:
    this(GLPBRTTManager manager, string name, 
         const(GLSurfaceDesc) target, bool writeGamma, uint fsaa)
    {
        super(name, target, writeGamma, fsaa);
        mManager = manager;

        mPBFormat = PixelUtil.getComponentType((cast(GLSurfaceDesc)target).buffer.getFormat());
        
        mManager.requestPBuffer(mPBFormat, mWidth, mHeight);
    }

    ~this()
    {
        // Release PBuffer
        mManager.releasePBuffer(mPBFormat);
    }
    
    override void getCustomAttribute(string name, void* pData)
    {
        if( name == GLRenderTexture.CustomAttributeString_TARGET )
        {
            GLSurfaceDesc* target = cast(GLSurfaceDesc*)pData;
            target.buffer = cast(GLHardwarePixelBuffer)mBuffer;
            target.zoffset = mZOffset;
        }
        else if (name == GLRenderTexture.CustomAttributeString_GLCONTEXT )
        {
            // Get PBuffer for our internal format
            *(cast(GLContext*)pData) = mManager.getContextFor(mPBFormat, mWidth, mHeight);
        }
    }

protected:
    GLPBRTTManager mManager;
    PixelComponentType mPBFormat;
}

/** Manager for rendertextures and PBuffers (offscreen rendering contexts)
    */
class GLPBRTTManager: GLRTTManager
{
public:
    this(GLSupport support, RenderTarget mainwindow)
    {
        mSupport = support;
        mMainWindow = mainwindow;
        mMainContext = null;
    
        mMainWindow.getCustomAttribute(GLRenderTexture.CustomAttributeString_GLCONTEXT, &mMainContext);
    }

    ~this()
    {
        // Delete remaining PBuffers
        for(size_t x=0; x<PixelComponentType.PCT_COUNT; ++x)
        {
            destroy(mPBuffers[x].pb);
        }
    }
    
    /** @copydoc GLRTTManager::createRenderTexture
        */
    override RenderTexture createRenderTexture(string name, 
                                       GLSurfaceDesc target, bool writeGamma, uint fsaa)
    {
        return new GLPBRenderTexture(this, name, target, writeGamma, fsaa);
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
        // Binding of context is done by GL subsystem, as contexts are also used for RenderWindows
    }
    
    /** @copydoc GLRTTManager::unbind
        */
    override void unbind(RenderTarget target)
    { 
        // Copy on unbind
        GLSurfaceDesc surface;
        surface.buffer = null;
        target.getCustomAttribute(GLRenderTexture.CustomAttributeString_TARGET, &surface);
        if(surface.buffer)
            (cast(GLTextureBuffer)surface.buffer).copyFromFramebuffer(surface.zoffset);
    }
    
    /** Create PBuffer for a certain pixel format and size
        */
    void requestPBuffer(PixelComponentType ctype, size_t width, size_t height)
    {
        //Check size
        if(mPBuffers[ctype].pb)
        {
            if(mPBuffers[ctype].pb.getWidth()<width || mPBuffers[ctype].pb.getHeight()<height)
            {
                // If the current PBuffer is too small, destroy it and create a new one
                destroy(mPBuffers[ctype].pb);
                mPBuffers[ctype].pb = null;
            }
        }
        if(!mPBuffers[ctype].pb)
        {
            // Create pbuffer via rendersystem
            mPBuffers[ctype].pb = mSupport.createPBuffer(ctype, width, height);
        }
        
        ++mPBuffers[ctype].refcount;
    }   
    
    /** Release PBuffer for a certain pixel format
        */
    void releasePBuffer(PixelComponentType ctype)
    {
        --mPBuffers[ctype].refcount;
        if(mPBuffers[ctype].refcount == 0)
        {
            destroy(mPBuffers[ctype].pb);
            mPBuffers[ctype].pb = null;
        }
    }
    
    /** Get GL rendering context for a certain component type and size.
        */
    GLContext getContextFor(PixelComponentType ctype, size_t width, size_t height)
    {
        // Faster to return main context if the RTT is smaller than the window size
        // and ctype is PCT_BYTE. This must be checked every time because the window might have been resized
        if(ctype == PixelComponentType.PCT_BYTE)
        {
            if(width <= mMainWindow.getWidth() && height <= mMainWindow.getHeight())
                return mMainContext;
        }
        assert(mPBuffers[ctype].pb !is null);
        return mPBuffers[ctype].pb.getContext();
    }

protected:
    /** GLSupport reference, used to create PBuffers */
    GLSupport mSupport;
    /** Primary window reference */
    RenderTarget mMainWindow;
    /** Primary window context */
    GLContext mMainContext;
    /** Reference to a PBuffer, with refcount */
    struct PBRef
    {
        //PBRef(): pb(0),refcount(0) {}
        GLPBuffer pb;
        size_t refcount;
    }

    /** Type to map each component type to a PBuffer */
    PBRef[PixelComponentType.PCT_COUNT] mPBuffers;
}