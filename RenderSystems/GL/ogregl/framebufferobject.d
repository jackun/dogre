module ogregl.framebufferobject;
import std.algorithm: min;
import std.conv : text;
import derelict.opengl3.gl;
import ogre.config;
import ogregl.fborendertexture;
import ogregl.depthbuffer;
import ogregl.hardwarepixelbuffer;
import ogre.exception;
import ogre.general.root;
import ogregl.rendertexture;
import ogre.rendersystem.rendersystem;
import ogre.image.pixelformat;

alias derelict.opengl3.constants.GL_NONE GL_NONE;
/** Frame Buffer Object abstraction.
 */
class GLFrameBufferObject
{
public:
    this(GLFBOManager manager, uint fsaa)
    {
        mManager = manager; mNumSamples = fsaa;
        
        // Generate framebuffer object
        glGenFramebuffers(1, &mFB);
        // check multisampling
        if (EXT_framebuffer_blit && EXT_framebuffer_multisample)
        {
            // check samples supported
            glBindFramebuffer(GL_FRAMEBUFFER, mFB);
            GLint maxSamples;
            glGetIntegerv(GL_MAX_SAMPLES, &maxSamples);
            glBindFramebuffer(GL_FRAMEBUFFER, 0);
            mNumSamples = min(mNumSamples, cast(GLsizei)maxSamples);
        }
        else
        {
            mNumSamples = 0;
        }
        // will we need a second FBO to do multisampling?
        if (mNumSamples)
        {
            glGenFramebuffers(1, &mMultisampleFB);
        }
        else
        {
            mMultisampleFB = 0;
        }
        // Initialise state
        mDepth.buffer = null;
        mStencil.buffer = null;
        for(size_t x=0; x<OGRE_MAX_MULTIPLE_RENDER_TARGETS; ++x)
        {
            mColour[x].buffer = null;
        }
    }
    
    ~this()
    {
        mManager.releaseRenderBuffer(mDepth);
        mManager.releaseRenderBuffer(mStencil);
        mManager.releaseRenderBuffer(mMultisampleColourBuffer);
        // Delete framebuffer object
        glDeleteFramebuffers(1, &mFB);        
        if (mMultisampleFB)
            glDeleteFramebuffers(1, &mMultisampleFB);
        
    }
    
    /** Bind a surface to a certain attachment point.
     attachment: 0..OGRE_MAX_MULTIPLE_RENDER_TARGETS-1
     */
    void bindSurface(size_t attachment, GLSurfaceDesc target)
    {
        assert(attachment < OGRE_MAX_MULTIPLE_RENDER_TARGETS);
        mColour[attachment] = target;
        // Re-initialise
        if(mColour[0].buffer)
            initialise();
    }
    
    /** Unbind attachment
     */
    void unbindSurface(size_t attachment)
    {
        assert(attachment < OGRE_MAX_MULTIPLE_RENDER_TARGETS);
        mColour[attachment].buffer = null;
        // Re-initialise if buffer 0 still bound
        if(mColour[0].buffer)
        {
            initialise();
        }
    }
    
    /** Bind FrameBufferObject
     */
    void bind()
    {
        // Bind it to FBO
        GLuint fb = mMultisampleFB ? mMultisampleFB : mFB;
        glBindFramebuffer(GL_FRAMEBUFFER, fb);
    }
    
    /** Swap buffers - only useful when using multisample buffers.
     */
    void swapBuffers()
    {
        if (mMultisampleFB)
        {
            GLint oldfb = 0;
            glGetIntegerv(GL_FRAMEBUFFER_BINDING, &oldfb);
            
            // Blit from multisample buffer to final buffer, triggers resolve
            size_t width = mColour[0].buffer.getWidth();
            size_t height = mColour[0].buffer.getHeight();
            glBindFramebuffer(GL_READ_FRAMEBUFFER, mMultisampleFB);
            glBindFramebuffer(GL_DRAW_FRAMEBUFFER, mFB);
            glBlitFramebuffer(0, 0, cast(GLint)width, cast(GLint)height, 0, 0, cast(GLint)width, cast(GLint)height, GL_COLOR_BUFFER_BIT, GL_NEAREST);
            
            // Unbind
            glBindFramebuffer(GL_FRAMEBUFFER, oldfb);
        }
    }
    
    /** This function acts very similar to @see GLFBORenderTexture::attachDepthBuffer
     The difference between D3D & OGL is that D3D setups the DepthBuffer before rendering,
     while OGL setups the DepthBuffer per FBO. So the DepthBuffer (RenderBuffer) needs to
     be attached for OGL.
     */
    void attachDepthBuffer( DepthBuffer depthBuffer )
    {
        GLDepthBuffer glDepthBuffer = cast(GLDepthBuffer)(depthBuffer);
        
        glBindFramebuffer(GL_FRAMEBUFFER, mMultisampleFB ? mMultisampleFB : mFB );
        
        if( glDepthBuffer )
        {
            GLRenderBuffer depthBuf   = glDepthBuffer.getDepthBuffer();
            GLRenderBuffer stencilBuf = glDepthBuffer.getStencilBuffer();
            
            // Attach depth buffer, if it has one.
            if( depthBuf )
                depthBuf.bindToFramebuffer( GL_DEPTH_ATTACHMENT, 0 );
            
            // Attach stencil buffer, if it has one.
            if( stencilBuf )
                stencilBuf.bindToFramebuffer( GL_STENCIL_ATTACHMENT, 0 );
        }
        else
        {
            glFramebufferRenderbuffer( GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT,
                                      GL_RENDERBUFFER, 0);
            glFramebufferRenderbuffer( GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT,
                                      GL_RENDERBUFFER, 0);
        }
    }
    
    void detachDepthBuffer()
    {
        glBindFramebuffer(GL_FRAMEBUFFER, mMultisampleFB ? mMultisampleFB : mFB );
        glFramebufferRenderbuffer( GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, 0 );
        glFramebufferRenderbuffer( GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT,
                                  GL_RENDERBUFFER, 0 );
    }
    
    /// Get the GL id for the FBO
    GLuint getGLFBOID() const { return mFB; }
    /// Get the GL id for the multisample FBO
    GLuint getGLMultisampleFBOID() const { return mMultisampleFB; }
    
    /// Accessors
    size_t getWidth()
    {
        assert(mColour[0].buffer);
        return mColour[0].buffer.getWidth();
    }
    
    size_t getHeight()
    {
        assert(mColour[0].buffer);
        return mColour[0].buffer.getHeight();
    }
    
    PixelFormat getFormat()
    {
        assert(mColour[0].buffer);
        return mColour[0].buffer.getFormat();
    }
    
    GLsizei getFSAA()
    {
        return mNumSamples;
    }
    
    GLFBOManager getManager() { return mManager; }
    GLSurfaceDesc getSurface(size_t attachment) { return mColour[attachment]; }
    
private:
    GLFBOManager mManager;
    GLsizei mNumSamples;
    GLuint mFB;
    GLuint mMultisampleFB;
    GLSurfaceDesc mMultisampleColourBuffer;
    GLSurfaceDesc mDepth;
    GLSurfaceDesc mStencil;
    // Arbitrary number of texture surfaces
    GLSurfaceDesc[OGRE_MAX_MULTIPLE_RENDER_TARGETS] mColour;
    
    
    /** Initialise object (find suitable depth and stencil format).
     Must be called every time the bindings change.
     It fails with an exception (ERR_INVALIDPARAMS) if:
     - Attachment point 0 has no binding
     - Not all bound surfaces have the same size
     - Not all bound surfaces have the same internal format
     */
    
    void initialise()
    {
        // Release depth and stencil, if they were bound
        mManager.releaseRenderBuffer(mDepth);
        mManager.releaseRenderBuffer(mStencil);
        mManager.releaseRenderBuffer(mMultisampleColourBuffer);
        // First buffer must be bound
        if(!mColour[0].buffer)
        {
            throw new InvalidParamsError(
                "Attachment 0 must have surface attached",
                "GLFrameBufferObject.initialise");
        }
        
        // If we're doing multisampling, then we need another FBO which contains a
        // renderbuffer which is set up to multisample, and we'll blit it to the final 
        // FBO afterwards to perform the multisample resolve. In that case, the 
        // mMultisampleFB is bound during rendering and is the one with a depth/stencil
        
        // Store basic stats
        size_t width = mColour[0].buffer.getWidth();
        size_t height = mColour[0].buffer.getHeight();
        GLuint format = mColour[0].buffer.getGLFormat();
        ushort maxSupportedMRTs = Root.getSingleton().getRenderSystem().getCapabilities().getNumMultiRenderTargets();
        
        // Bind simple buffer to add colour attachments
        glBindFramebuffer(GL_FRAMEBUFFER, mFB);
        
        // Bind all attachment points to frame buffer
        for(size_t x=0; x<maxSupportedMRTs; ++x)
        {
            if(mColour[x].buffer)
            {
                if(mColour[x].buffer.getWidth() != width || mColour[x].buffer.getHeight() != height)
                {
                    string ss = text("Attachment ", x, " has incompatible size ");
                    ss ~= text(mColour[x].buffer.getWidth(), "x", mColour[x].buffer.getHeight());
                    ss ~= ". It must be of the same as the size of surface 0, ";
                    ss ~= text(width, "x", height);
                    ss ~= ".";
                    throw new InvalidParamsError(ss, "GLFrameBufferObject.initialise");
                }
                if(mColour[x].buffer.getGLFormat() != format)
                {
                    string ss = text("Attachment ", x, " has incompatible format.");
                    throw new InvalidParamsError(ss, "GLFrameBufferObject.initialise");
                }
                mColour[x].buffer.bindToFramebuffer(cast(GLenum)(GL_COLOR_ATTACHMENT0+x), mColour[x].zoffset);
            }
            else
            {
                // Detach
                glFramebufferRenderbuffer(GL_FRAMEBUFFER, cast(GLenum)(GL_COLOR_ATTACHMENT0+x),
                                          GL_RENDERBUFFER, 0);
            }
        }
        
        // Now deal with depth / stencil
        if (mMultisampleFB)
        {
            // Bind multisample buffer
            glBindFramebuffer(GL_FRAMEBUFFER, mMultisampleFB);
            
            // Create AA render buffer (colour)
            // note, this can be shared too because we blit it to the final FBO
            // right after the render is finished
            mMultisampleColourBuffer = mManager.requestRenderBuffer(format, width, height, mNumSamples);
            
            // Attach it, because we won't be attaching below and non-multisample has
            // actually been attached to other FBO
            mMultisampleColourBuffer.buffer.bindToFramebuffer(GL_COLOR_ATTACHMENT0, 
                                                              mMultisampleColourBuffer.zoffset);
            
            // depth & stencil will be dealt with below
            
        }
        
        // Depth buffer is not handled here anymore.
        // See GLFrameBufferObject::attachDepthBuffer() & RenderSystem::setDepthBufferFor()
        
        // Do glDrawBuffer calls
        GLenum[OGRE_MAX_MULTIPLE_RENDER_TARGETS] bufs;
        GLsizei n=0;
        for(uint x=0; x<OGRE_MAX_MULTIPLE_RENDER_TARGETS; ++x)
        {
            // Fill attached colour buffers
            if(mColour[x].buffer)
            {
                bufs[x] = cast(GLenum)(GL_COLOR_ATTACHMENT0 + x);
                // Keep highest used buffer + 1
                n = x+1;
            }
            else
            {
                bufs[x] = GL_NONE;
            }
        }
        if(glDrawBuffers)
        {
            // Drawbuffer extension supported, use it
            glDrawBuffers(n, bufs.ptr);
        }
        else
        {
            // In this case, the capabilities will not show more than 1 simultaneaous render target.
            glDrawBuffer(bufs[0]);
        }
        if (mMultisampleFB)
        {
            // we need a read buffer because we'll be blitting to mFB
            glReadBuffer(bufs[0]);
        }
        else
        {
            // No read buffer, by default, if we want to read anyway we must not forget to set this.
            glReadBuffer(GL_NONE);
        }
        
        // Check status
        GLuint status;
        status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        
        // Bind main buffer
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        
        switch(status)
        {
            case GL_FRAMEBUFFER_COMPLETE:
                // All is good
                break;
            case GL_FRAMEBUFFER_UNSUPPORTED:
                throw new InvalidParamsError(
                            "All framebuffer formats with this texture internal format unsupported",
                            "GLFrameBufferObject.initialise");
            default:
                throw new InvalidParamsError(
                            "Framebuffer incomplete or other FBO status error",
                            "GLFrameBufferObject.initialise");
        }
        
    }
}