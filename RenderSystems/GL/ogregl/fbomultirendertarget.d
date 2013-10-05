module ogregl.fbomultirendertarget;
import ogre.rendersystem.rendertexture;
import ogregl.fborendertexture;
import ogregl.rendertexture;
import ogre.rendersystem.rendersystem;
import ogregl.framebufferobject;

/** MultiRenderTarget for GL. Requires the FBO extension.
 */
class GLFBOMultiRenderTarget : MultiRenderTarget
{
public:
    this(GLFBOManager manager, string name)
    {
        super(name);
        fbo = new GLFrameBufferObject(manager, 0 /* TODO: multisampling on MRTs? */);
    }
    ~this() {}
    
    override void getCustomAttribute( string name, void *pData )
    {
        if( name == GLRenderTexture.CustomAttributeString_FBO )
        {
            *(cast(GLFrameBufferObject *)pData) = fbo;
        }
    }
    
    
    override bool requiresTextureFlipping() const { return true; }
    
    /// Override so we can attach the depth buffer to the FBO
    override bool attachDepthBuffer( DepthBuffer depthBuffer )
    {
        bool result;
        if( (result = MultiRenderTarget.attachDepthBuffer( depthBuffer ))  == true)
            fbo.attachDepthBuffer( depthBuffer );
        
        return result;
    }
    
    override void detachDepthBuffer()
    {
        fbo.detachDepthBuffer();
        MultiRenderTarget.detachDepthBuffer();
    }
    
    override void _detachDepthBuffer()
    {
        fbo.detachDepthBuffer();
        MultiRenderTarget._detachDepthBuffer();
    }
    
protected:
    override void bindSurfaceImpl(size_t attachment, RenderTexture target)
    {
        /// Check if the render target is in the rendertarget.FBO map
        GLFrameBufferObject fbobj = null;
        target.getCustomAttribute(GLRenderTexture.CustomAttributeString_FBO, &fbobj);
        assert(fbobj !is null);
        fbo.bindSurface(attachment, fbobj.getSurface(0));
        
        // Set width and height
        mWidth = cast(uint)fbo.getWidth();
        mHeight = cast(uint)fbo.getHeight();
    }
    
    override void unbindSurfaceImpl(size_t attachment)
    {
        fbo.unbindSurface(attachment);
        
        // Set width and height
        mWidth = cast(uint)fbo.getWidth();
        mHeight = cast(uint)fbo.getHeight();
    }
    
    GLFrameBufferObject fbo;
}