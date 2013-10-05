module ogregl.fborendertexture;
import derelict.opengl3.gl;
import ogre.rendersystem.rendersystem;
import ogre.rendersystem.rendertarget;
import ogre.rendersystem.rendertexture;
import ogre.general.log;
import ogre.compat;
import ogre.image.pixelformat;
import ogre.image.images;

import ogregl.rendertexture;
import ogregl.glew;
import ogregl.pixelformat;
import ogregl.hardwarepixelbuffer;
import ogregl.framebufferobject;
import ogregl.fbomultirendertarget;

alias derelict.opengl3.constants.GL_NONE GL_NONE;
alias derelict.opengl3.constants.GL_RGBA GL_RGBA;
/// Size of probe texture
enum PROBE_SIZE = 16;

/// Stencil and depth formats to be tried
static const (GLenum[]) stencilFormats =
    [
     derelict.opengl3.constants.GL_NONE,                    // No stencil
     GL_STENCIL_INDEX1_EXT,
     GL_STENCIL_INDEX4_EXT,
     GL_STENCIL_INDEX8_EXT,
     GL_STENCIL_INDEX16_EXT
     ];
static const (size_t[]) stencilBits = [0, 1, 4, 8, 16];

//enum STENCILFORMAT_COUNT (sizeof(stencilFormats)/sizeof(GLenum))

static const (GLenum[]) depthFormats =
    [
     derelict.opengl3.constants.GL_NONE,
     GL_DEPTH_COMPONENT16,
     GL_DEPTH_COMPONENT24,    // Prefer 24 bit depth
     GL_DEPTH_COMPONENT32,
     GL_DEPTH24_STENCIL8 // packed depth / stencil
     ];

static const (size_t[]) depthBits = [0,16,24,32,24];
//#define DEPTHFORMAT_COUNT (sizeof(depthFormats)/sizeof(GLenum))


/** RenderTexture for GL FBO
 */
class GLFBORenderTexture: GLRenderTexture
{
public:
    this(GLFBOManager manager, string name, GLSurfaceDesc target, bool writeGamma, uint fsaa)
    {
        super(name, target, writeGamma, fsaa);
        mFB = new GLFrameBufferObject(manager, fsaa);
        
        // Bind target to surface 0 and initialise
        mFB.bindSurface(0, target);
        // Get attributes
        mWidth = cast(uint)mFB.getWidth();
        mHeight = cast(uint)mFB.getHeight();
    }
    
    override void getCustomAttribute(string name, void* pData)
    {
        if( name == GLRenderTexture.CustomAttributeString_FBO )
        {
            *(cast(GLFrameBufferObject *)pData) = mFB;
        }
        else if (name == "GL_FBOID")
        {
            *(cast(GLuint*)pData) = mFB.getGLFBOID();
        }
        else if (name == "GL_MULTISAMPLEFBOID")
        {
            *(cast(GLuint*)pData) = mFB.getGLMultisampleFBOID();
        }
    }
    
    /// Override needed to deal with multisample buffers
    override void swapBuffers(bool waitForVSync = true)
    {
        mFB.swapBuffers();
    }
    
    /// Override so we can attach the depth buffer to the FBO
    override bool attachDepthBuffer( DepthBuffer depthBuffer )
    {
        bool result;
        if( (result = GLRenderTexture.attachDepthBuffer( depthBuffer )) == true)
            mFB.attachDepthBuffer( depthBuffer );
        
        return result;
    }
    
    override void detachDepthBuffer()
    {
        mFB.detachDepthBuffer();
        GLRenderTexture.detachDepthBuffer();
    }
    
    override void _detachDepthBuffer()
    {
        mFB.detachDepthBuffer();
        GLRenderTexture._detachDepthBuffer();
    }
    
protected:
    GLFrameBufferObject mFB;
}

/** Factory for GL Frame Buffer Objects, and related things.
 */
class GLFBOManager: GLRTTManager
{
public:
    this(bool atimode)
    {
        mATIMode = atimode;
        detectFBOFormats();
        
        glGenFramebuffers(1, &mTempFBO);
    }
    
    ~this()
    {
        if(!mRenderBufferMap.emptyAA())
        {
            LogManager.getSingleton().logMessage("GL: Warning! GLFBOManager destructor called, but not all renderbuffers were released.");
        }
        
        glDeleteFramebuffers(1, &mTempFBO);      
    }
    
    /** Bind a certain render target if it is a FBO. If it is not a FBO, bind the
     main frame buffer.
     */
    override void bind(RenderTarget target)
    {
        /// Check if the render target is in the rendertarget.FBO map
        GLFrameBufferObject fbo = null;
        target.getCustomAttribute(GLRenderTexture.CustomAttributeString_FBO, &fbo);
        if(fbo)
            fbo.bind();
        else
            // Old style context (window/pbuffer) or copying render texture
            glBindFramebuffer(GL_FRAMEBUFFER, 0);
    }
    
    /** Unbind a certain render target. No-op for FBOs.
     */
    override void unbind(RenderTarget target) {};
    
    /** Get best depth and stencil supported for given internalFormat
     */
    override void getBestDepthStencil(GLenum internalFormat, ref GLenum depthFormat, ref GLenum stencilFormat)
    {
        FormatProperties props = mProps[internalFormat];
        /// Decide what stencil and depth formats to use
        /// [best supported for internal format]
        size_t bestmode=0;
        int bestscore=-1;
        for(size_t mode=0; mode<props.modes.length; mode++)
        {
            /*#if 0
             /// Always prefer D24S8
             if(stencilBits[props.modes[mode].stencil]==8 &&
             depthBits[props.modes[mode].depth]==24)
             {
             bestmode = mode;
             break;
             }
             #endif*/
            int desirability = 0;
            /// Find most desirable mode
            /// desirability == 0            if no depth, no stencil
            /// desirability == 1000...2000  if no depth, stencil
            /// desirability == 2000...3000  if depth, no stencil
            /// desirability == 3000+        if depth and stencil
            /// beyond this, the total numer of bits (stencil+depth) is maximised
            if(props.modes[mode].stencil)
                desirability += 1000;
            if(props.modes[mode].depth)
                desirability += 2000;
            if(depthBits[props.modes[mode].depth]==24) // Prefer 24 bit for now
                desirability += 500;
            if(depthFormats[props.modes[mode].depth]==GL_DEPTH24_STENCIL8) // Prefer 24/8 packed 
                desirability += 5000;
            desirability += stencilBits[props.modes[mode].stencil] + depthBits[props.modes[mode].depth];
            
            if(desirability>bestscore)
            {
                bestscore = desirability;
                bestmode = mode;
            }
        }
        depthFormat = depthFormats[props.modes[bestmode].depth];
        stencilFormat = stencilFormats[props.modes[bestmode].stencil];
    }
    
    /** Create a texture rendertarget object
     */
    override GLFBORenderTexture createRenderTexture(string name, 
                                           GLSurfaceDesc target, bool writeGamma, uint fsaa)
    {
        GLFBORenderTexture retval = new GLFBORenderTexture(this, name, target, writeGamma, fsaa);
        return retval;
    }
    
    /** Create a multi render target 
     */
    override MultiRenderTarget createMultiRenderTarget(string  name)
    {
        return new GLFBOMultiRenderTarget(this, name);
    }
    
    /** Request a render buffer. If format is GL_NONE, return a zero buffer.
     */
    GLSurfaceDesc requestRenderBuffer(GLenum format, size_t width, size_t height, uint fsaa)
    {
        GLSurfaceDesc retval;
        retval.buffer = null; // Return 0 buffer if GL_NONE is requested
        if(format != GL_NONE)
        {
            RBFormat key = RBFormat(format, width, height, fsaa);
            auto it = key in mRenderBufferMap;
            if(it !is null)
            {
                retval.buffer = it.buffer;
                retval.zoffset = 0;
                retval.numSamples = fsaa;
                // Increase refcount
                ++(*it).refcount;
            }
            else
            {
                // New one
                GLRenderBuffer rb = new GLRenderBuffer(format, width, height, fsaa);
                mRenderBufferMap[key] = RBRef(rb);
                retval.buffer = rb;
                retval.zoffset = 0;
                retval.numSamples = fsaa;
            }
        }
        //std::cerr << "Requested renderbuffer with format " << std::hex << format << std::dec << " of " << width << "x" << height << " :" << retval.buffer << std::endl;
        return retval;
    }
    /** Request the specify render buffer in case shared somewhere. Ignore
     silently if surface.buffer is 0.
     */
    void requestRenderBuffer(GLSurfaceDesc surface)
    {
        if(surface.buffer is null)
            return;
        RBFormat key = RBFormat(surface.buffer.getGLFormat(), surface.buffer.getWidth(), surface.buffer.getHeight(), surface.numSamples);
        auto it = key in mRenderBufferMap;
        assert(it !is null);
        if (it !is null)   // Just in case
        {
            assert(it.buffer == surface.buffer);
            // Increase refcount
            ++(*it).refcount;
        }
    }
    
    /** Release a render buffer. Ignore silently if surface.buffer is 0.
     */
    void releaseRenderBuffer(GLSurfaceDesc surface)
    {
        if(surface.buffer is null)
            return;
        RBFormat key = RBFormat(surface.buffer.getGLFormat(), surface.buffer.getWidth(), surface.buffer.getHeight(), surface.numSamples);
        auto it = key in mRenderBufferMap;
        if(it !is null)
        {
            // Decrease refcount
            --(*it).refcount;
            if((*it).refcount==0)
            {
                // If refcount reaches zero, delete buffer and remove from map
                destroy((*it).buffer);
                mRenderBufferMap.remove(key);
                //std::cerr << "Destroyed renderbuffer of format " << std::hex << key.format << std::dec
                //        << " of " << key.width << "x" << key.height << std::endl;
            }
        }
    }
    
    /** Check if a certain format is usable as FBO rendertarget format
     */
    override bool checkFormat(PixelFormat format) { return mProps[format].valid; }
    
    /** Get a FBO without depth/stencil for temporary use, like blitting between textures.
     */
    GLuint getTemporaryFBO() { return mTempFBO; }
private:
    /** Frame Buffer Object properties for a certain texture format.
     */
    struct FormatProperties
    {
        bool valid; // This format can be used as RTT (FBO)
        
        /** Allowed modes/properties for this pixel format
         */
        struct Mode
        {
            size_t depth;     // Depth format (0=no depth)
            size_t stencil;   // Stencil format (0=no stencil)
        }
        
        //vector<Mode>::type modes;
        Mode[] modes;
    }
    /** Properties for all internal formats defined by OGRE
     */
    FormatProperties[PixelFormat.PF_COUNT] mProps;
    
    /** Stencil and depth renderbuffers of the same format are re-used between surfaces of the 
     same size and format. This can save a lot of memory when a large amount of rendertargets
     are used.
     */
    struct RBFormat
    {
        /*this(GLenum inFormat, size_t inWidth, size_t inHeight, uint fsaa)
         {
         format = inFormat;
         width = inWidth;
         height = inHeight;
         samples = fsaa;
         }*/
        
        GLenum format;
        size_t width;
        size_t height;
        uint samples;
        // Overloaded comparison operator for usage in map
        /*bool operator < (const RBFormat &other) const
         {
         if(format < other.format)
         {
         return true;
         }
         else if(format == other.format)
         {
         if(width < other.width)
         {
         return true;
         }
         else if(width == other.width)
         {
         if(height < other.height)
         return true;
         else if (height == other.height)
         {
         if (samples < other.samples)
         return true;
         }
         }
         }
         return false;
         }*/
    }
    struct RBRef
    {
        //this(GLRenderBuffer *inBuffer){ buffer(inBuffer), refcount(1) }
        GLRenderBuffer buffer;
        size_t refcount;
    }
    
    //typedef map<RBFormat, RBRef>::type RenderBufferMap;
    alias RBRef[RBFormat] RenderBufferMap;
    ///aka RenderBufferMap
    RBRef[RBFormat] mRenderBufferMap;
    // map(format, sizex, sizey) => [GLSurface*,refcount]
    
    /** Temporary FBO identifier
     */
    GLuint mTempFBO;
    
    /// Buggy ATI driver?
    bool mATIMode;
    
    /** Detect allowed FBO formats */
    void detectFBOFormats()
    {
        // Try all formats, and report which ones work as target
        GLuint fb = 0, tid = 0;
        GLint old_drawbuffer = 0, old_readbuffer = 0;
        GLenum target = GL_TEXTURE_2D;
        
        glGetIntegerv (GL_DRAW_BUFFER, &old_drawbuffer);
        glGetIntegerv (GL_READ_BUFFER, &old_readbuffer);
        
        for(size_t x=0; x<PixelFormat.PF_COUNT; ++x)
        {
            mProps[x].valid = false;
            
            // Fetch GL format token
            GLenum fmt = GLPixelUtil.getGLInternalFormat(cast(PixelFormat)x);
            if(fmt == GL_NONE && x!=0)
                continue;
            
            // No test for compressed formats
            if(PixelUtil.isCompressed(cast(PixelFormat)x))
                continue;
            
            // Buggy ATI cards *crash* on non-RGB(A) formats
            int[4] depths;
            PixelUtil.getBitDepths(cast(PixelFormat)x, depths);
            if(fmt!=GL_NONE && mATIMode && (!depths[0] || !depths[1] || !depths[2]))
                continue;
            
            // Create and attach framebuffer
            glGenFramebuffers(1, &fb);
            glBindFramebuffer(GL_FRAMEBUFFER, fb);
            if (fmt!=GL_NONE)
            {
                // Create and attach texture
                glGenTextures(1, &tid);
                glBindTexture(target, tid);
                
                // Set some default parameters so it won't fail on NVidia cards         
                if (GLEW_VERSION_1_2)
                    glTexParameteri(target, GL_TEXTURE_MAX_LEVEL, 0);
                glTexParameteri(target, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
                glTexParameteri(target, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
                glTexParameteri(target, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
                glTexParameteri(target, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
                
                glTexImage2D(target, 0, fmt, PROBE_SIZE, PROBE_SIZE, 0, GL_RGBA, GL_UNSIGNED_BYTE, null);
                glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                                       target, tid, 0);
            }
            else
            {
                // Draw to nowhere -- stencil/depth only
                glDrawBuffer(GL_NONE);
                glReadBuffer(GL_NONE);
            }
            // Check status
            GLuint status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
            
            // Ignore status in case of fmt==GL_NONE, because no implementation will accept
            // a buffer without *any* attachment. Buffers with only stencil and depth attachment
            // might still be supported, so we must continue probing.
            if(fmt == GL_NONE || status == GL_FRAMEBUFFER_COMPLETE)
            {
                mProps[x].valid = true;
                string str = std.conv.text("FBO ", PixelUtil.getFormatName(cast(PixelFormat)x), 
                                           " depth/stencil support: ");
                
                // For each depth/stencil formats
                for (size_t depth = 0; depth < depthFormats.length; ++depth)
                {
                    if (depthFormats[depth] != GL_DEPTH24_STENCIL8)
                    {
                        // General depth/stencil combination
                        
                        for (size_t stencil = 0; stencil < stencilFormats.length; ++stencil)
                        {
                            //StringUtil::StrStreamType l;
                            //l << "Trying " << PixelUtil::getFormatName((PixelFormat)x) 
                            //  << " D" << depthBits[depth] 
                            //  << "S" << stencilBits[stencil];
                            //LogManager::getSingleton().logMessage(l.str());
                            
                            if (_tryFormat(depthFormats[depth], stencilFormats[stencil]))
                            {
                                /// Add mode to allowed modes
                                str ~= std.conv.text("D", depthBits[depth], "S", stencilBits[stencil], " ");
                                FormatProperties.Mode mode;
                                mode.depth = depth;
                                mode.stencil = stencil;
                                mProps[x].modes ~= mode;
                            }
                        }
                    }
                    else
                    {
                        // Packed depth/stencil format
                        
                        // #if OGRE_PLATFORM == OGRE_PLATFORM_LINUX
                        // It now seems as if this workaround now *breaks* nvidia cards on Linux with the 169.12 drivers on Linux
                        /*#if 0
                         // Only query packed depth/stencil formats for 32-bit
                         // non-floating point formats (ie not R32!) 
                         // Linux nVidia driver segfaults if you query others
                         if (PixelUtil.getNumElemBits((PixelFormat)x) != 32 ||
                         PixelUtil.isFloatingPoint((PixelFormat)x))
                         {
                         continue;
                         }
                         #endif*/
                        
                        if (_tryPackedFormat(depthFormats[depth]))
                        {
                            /// Add mode to allowed modes
                            str ~= std.conv.text("Packed-D", depthBits[depth], "S", 8, " ");
                            FormatProperties.Mode mode;
                            mode.depth = depth;
                            mode.stencil = 0;   // unuse
                            mProps[x].modes ~= mode;
                        }
                    }
                }
                
                LogManager.getSingleton().logMessage(str);
                
            }
            // Delete texture and framebuffer
            glBindFramebuffer(GL_FRAMEBUFFER, 0);
            glDeleteFramebuffers(1, &fb);
            
            // Workaround for NVIDIA / Linux 169.21 driver problem
            // see http://www.ogre3d.org/phpBB2/viewtopic.php?t=38037&start=25
            glFinish();
            
            if (fmt!=GL_NONE)
                glDeleteTextures(1, &tid);
        }
        
        // It seems a bug in nVidia driver: glBindFramebufferEXT should restore
        // draw and read buffers, but in some unclear circumstances it won't.
        glDrawBuffer(old_drawbuffer);
        glReadBuffer(old_readbuffer);
        
        string fmtstring = "";
        for(size_t x=0; x<PixelFormat.PF_COUNT; ++x)
        {
            if(mProps[x].valid)
                fmtstring ~= PixelUtil.getFormatName(cast(PixelFormat)x)~" ";
        }
        LogManager.getSingleton().logMessage("[GL] : Valid FBO targets " ~ fmtstring);
    }
    
    GLuint _tryFormat(GLenum depthFormat, GLenum stencilFormat)
    {
        GLuint status, depthRB = 0, stencilRB = 0;
        bool failed = false; // flag on GL errors
        
        if(depthFormat != GL_NONE)
        {
            /// Generate depth renderbuffer
            glGenRenderbuffers(1, &depthRB);
            /// Bind it to FBO
            glBindRenderbuffer(GL_RENDERBUFFER, depthRB);
            
            /// Allocate storage for depth buffer
            glRenderbufferStorage(GL_RENDERBUFFER, depthFormat,
                                  PROBE_SIZE, PROBE_SIZE);
            
            /// Attach depth
            glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT,
                                      GL_RENDERBUFFER, depthRB);
        }
        
        if(stencilFormat != GL_NONE)
        {
            /// Generate stencil renderbuffer
            glGenRenderbuffers(1, &stencilRB);
            /// Bind it to FBO
            glBindRenderbuffer(GL_RENDERBUFFER, stencilRB);
            glGetError(); // NV hack
            /// Allocate storage for stencil buffer
            glRenderbufferStorage(GL_RENDERBUFFER, stencilFormat,
                                  PROBE_SIZE, PROBE_SIZE); 
            if(glGetError() != GL_NO_ERROR) // NV hack
                failed = true;
            /// Attach stencil
            glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT,
                                      GL_RENDERBUFFER, stencilRB);
            if(glGetError() != GL_NO_ERROR) // NV hack
                failed = true;
        }
        
        status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        /// If status is negative, clean up
        // Detach and destroy
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, 0);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_RENDERBUFFER, 0);
        if (depthRB)
            glDeleteRenderbuffers(1, &depthRB);
        if (stencilRB)
            glDeleteRenderbuffers(1, &stencilRB);
        
        return status == GL_FRAMEBUFFER_COMPLETE && !failed;
    }
    
    /** Try a certain packed depth/stencil format, and return the status.
     @return true    if this combo is supported
     false   if this combo is not supported
     */
    bool _tryPackedFormat(GLenum packedFormat)
    {
        GLuint packedRB = 0;
        bool failed = false; // flag on GL errors
        
        /// Generate renderbuffer
        glGenRenderbuffers(1, &packedRB);
        
        /// Bind it to FBO
        glBindRenderbuffer(GL_RENDERBUFFER, packedRB);
        
        /// Allocate storage for buffer
        glRenderbufferStorage(GL_RENDERBUFFER, packedFormat, PROBE_SIZE, PROBE_SIZE);
        glGetError(); // NV hack
        
        /// Attach depth
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT,
                                  GL_RENDERBUFFER, packedRB);
        if(glGetError() != GL_NO_ERROR) // NV hack
            failed = true;
        
        /// Attach stencil
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT,
                                  GL_RENDERBUFFER, packedRB);
        if(glGetError() != GL_NO_ERROR) // NV hack
            failed = true;
        
        GLuint status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        
        /// Detach and destroy
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, 0);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_RENDERBUFFER, 0);
        glDeleteRenderbuffers(1, &packedRB);
        
        return status == GL_FRAMEBUFFER_COMPLETE && !failed;
    }
}