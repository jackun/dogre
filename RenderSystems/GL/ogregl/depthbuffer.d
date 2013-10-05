module ogregl.depthbuffer;
import derelict.opengl3.gl;
import ogre.rendersystem.rendersystem;
import ogregl.context;
import ogregl.rendersystem;
import ogre.rendersystem.rendertarget;
import ogregl.hardwarepixelbuffer;
import ogregl.framebufferobject;
import ogregl.rendertexture;

alias derelict.opengl3.constants.GL_NONE GL_NONE;

/**
        @copydoc DepthBuffer

        OpenGL supports 3 different methods: FBO, pbuffer & Copy.
        Each one has it's own limitations. Non-FBO methods are solved using "dummy" DepthBuffers.
        That is, a DepthBuffer pointer is attached to the RenderTarget (for the sake of consistency)
        but it doesn't actually contain a Depth surface/renderbuffer (mDepthBuffer & mStencilBuffer are
        null pointers all the time) Those dummy DepthBuffers are identified thanks to their GL context.
        Note that FBOs don't allow sharing with the main window's depth buffer. Therefore even
        when FBO is enabled, a dummy DepthBuffer is still used to manage the windows.
    */
class GLDepthBuffer : DepthBuffer
{
public:
    this( ushort poolId, GLRenderSystem renderSystem, GLContext creatorContext,
                  GLRenderBuffer depth, GLRenderBuffer stencil,
                  uint width, uint height, uint fsaa, uint multiSampleQuality,
                  bool isManual )
    {
        super( poolId, 0, width, height, fsaa, "", isManual );
        mMultiSampleQuality =  multiSampleQuality ;
        mCreatorContext =  creatorContext ;
        mDepthBuffer =  depth ;
        mStencilBuffer =  stencil ;
        mRenderSystem =  renderSystem ;
        
        if( mDepthBuffer )
        {
            switch( mDepthBuffer.getGLFormat() )
            {
                case GL_DEPTH_COMPONENT16:
                    mBitDepth = 16;
                    break;
                case GL_DEPTH_COMPONENT24:
                case GL_DEPTH_COMPONENT32:
                case GL_DEPTH24_STENCIL8:
                    mBitDepth = 32;
                    break;
                default:
                    break;//TODO blow up?
            }
        }
    }

    ~this()
    {
        if( mStencilBuffer && mStencilBuffer != mDepthBuffer )
        {
            destroy(mStencilBuffer);
            mStencilBuffer = null;
        }
        
        if( mDepthBuffer )
        {
            destroy(mDepthBuffer);
            mDepthBuffer = null;
        }
    }
    
    /// @copydoc DepthBuffer::isCompatible
    override bool isCompatible( RenderTarget renderTarget )
    {
        bool retVal = false;
        
        //Check standard stuff first.
        if( mRenderSystem.getCapabilities().hasCapability( Capabilities.RSC_RTT_DEPTHBUFFER_RESOLUTION_LESSEQUAL ) )
        {
            if( !DepthBuffer.isCompatible( renderTarget ) )
                return false;
        }
        else
        {
            if( this.getWidth() != renderTarget.getWidth() ||
               this.getHeight() != renderTarget.getHeight() ||
               this.getFsaa() != renderTarget.getFSAA() )
                return false;
        }
        
        //Now check this is the appropriate format
        GLFrameBufferObject fbo = null;
        renderTarget.getCustomAttribute(GLRenderTexture.CustomAttributeString_FBO, &fbo);
        
        if( fbo is null)
        {
            GLContext windowContext;
            renderTarget.getCustomAttribute( GLRenderTexture.CustomAttributeString_GLCONTEXT, &windowContext );
            
            //Non-FBO targets and FBO depth surfaces don't play along, only dummies which match the same
            //context
            if( !mDepthBuffer && !mStencilBuffer && mCreatorContext == windowContext )
                retVal = true;
        }
        else
        {
            //Check this isn't a dummy non-FBO depth buffer with an FBO target, don't mix them.
            //If you don't want depth buffer, use a Null Depth Buffer, not a dummy one.
            if( mDepthBuffer || mStencilBuffer )
            {
                GLenum internalFormat = fbo.getFormat();
                GLenum depthFormat, stencilFormat;
                mRenderSystem._getDepthStencilFormatFor( internalFormat, depthFormat, stencilFormat );
                
                bool bSameDepth = false;
                
                if( mDepthBuffer )
                    bSameDepth |= mDepthBuffer.getGLFormat() == depthFormat;
                
                bool bSameStencil = false;
                
                if( !mStencilBuffer || mStencilBuffer == mDepthBuffer )
                    bSameStencil = stencilFormat == GL_NONE;
                else
                {
                    if( mStencilBuffer )
                        bSameStencil = stencilFormat == mStencilBuffer.getGLFormat();
                }
                
                retVal = bSameDepth && bSameStencil;
            }
        }
        
        return retVal;
    }
    
    GLContext getGLContext() { return mCreatorContext; }
    GLRenderBuffer getDepthBuffer() { return mDepthBuffer; }
    GLRenderBuffer getStencilBuffer() { return mStencilBuffer; }
    
protected:
    uint                      mMultiSampleQuality;
    GLContext                 mCreatorContext;
    GLRenderBuffer            mDepthBuffer;
    GLRenderBuffer            mStencilBuffer;
    GLRenderSystem            mRenderSystem;
}