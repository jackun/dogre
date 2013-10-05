module ogregl.hardwarepixelbuffer;
import core.stdc.stdlib;

import derelict.opengl3.gl;
import ogre.exception;
import ogre.image.images;
import ogre.image.pixelformat;
import ogre.rendersystem.hardware;
import ogre.resources.texture;
import ogre.resources.datastream;
import ogre.rendersystem.rendertexture;
import ogre.rendersystem.rendersystem;
import ogre.general.root;


import ogregl.config;
import ogregl.pixelformat;
import ogregl.rendertexture;
import ogregl.fborendertexture;
import ogregl.glew;
import ogregl.glu;

alias derelict.opengl3.constants.GL_UNSIGNED_BYTE GL_UNSIGNED_BYTE;
alias derelict.opengl3.constants.GL_RGBA GL_RGBA;

class GLHardwarePixelBuffer: HardwarePixelBuffer
{
protected:  
    /// Lock a box
    override PixelBox lockImpl(Image.Box lockBox,  LockOptions options)
    {
        allocateBuffer();
        if(options != HardwareBuffer.LockOptions.HBL_DISCARD)
        {
            // Download the old contents of the texture
            download(mBuffer);
        }
        mCurrentLockOptions = options;
        mLockedBox = lockBox;
        return mBuffer.getSubVolume(lockBox);
    }
    
    /// Unlock a box
    override void unlockImpl()
    {
        if (mCurrentLockOptions != HardwareBuffer.LockOptions.HBL_READ_ONLY)
        {
            // From buffer to card, only upload if was locked for writing
            upload(mCurrentLock, mLockedBox);
        }
        
        freeBuffer();
    }
    
    // Internal buffer; either on-card or in system memory, freed/allocated on demand
    // depending on buffer usage
    PixelBox mBuffer;
    GLenum mGLInternalFormat; // GL internal format
    LockOptions mCurrentLockOptions;
    
    // Buffer allocation/freeage
    void allocateBuffer()
    {
        if(mBuffer.data !is null)
            // Already allocated
            return;
        //TODO Would be nice, but where to store array?
        //mBuffer.data = new ubyte[mSizeInBytes];
        mBuffer.data = malloc(mSizeInBytes);
        // TODO: use PBO if we're HBU_DYNAMIC
    }

    void freeBuffer()
    {
        // Free buffer if we're STATIC to save memory
        if(mUsage & Usage.HBU_STATIC)
        {
            //delete [] (uint8*)mBuffer.data;
            //destroy(mBuffer.data);
            free(mBuffer.data);
            mBuffer.data = null;
        }
    }

    // Upload a box of pixels to this buffer on the card
    //void upload(const(PixelBox) data, const(Image.Box) dest) //Argh fck you const
    void upload(PixelBox data, Image.Box dest)
    {
        throw new RenderingApiError(
            "Upload not possible for this pixelbuffer type",
            "GLHardwarePixelBuffer.upload");
    }

    // Download a box of pixels from the card
    //void download(const(PixelBox) data) //duh, how do you change a const then
    void download(PixelBox data)
    {
        throw new RenderingApiError("Download not possible for this pixelbuffer type",
                                    "GLHardwarePixelBuffer.download");
    }

public:
    /// Should be called by HardwareBufferManager
    this(size_t inWidth, size_t inHeight, size_t inDepth,
         PixelFormat inFormat,
         HardwareBuffer.Usage usage)
    {
        super(inWidth, inHeight, inDepth, inFormat, usage, false, false);
        mBuffer = new PixelBox(inWidth, inHeight, inDepth, inFormat);
        mGLInternalFormat = derelict.opengl3.constants.GL_NONE;
        mCurrentLockOptions = LockOptions.HBL_NORMAL; //cast(LockOptions)0;
    }
    
    /// @copydoc HardwarePixelBuffer::blitFromMemory
    //TODO ref? scaled = src;
    //override void blitFromMemory(const(PixelBox) src, const(Image.Box) dstBox)
    override void blitFromMemory(PixelBox src, Image.Box dstBox)
    {
        if(!mBuffer.contains(dstBox))
            throw new InvalidParamsError("destination box out of range",
                                         "GLHardwarePixelBuffer.blitFromMemory");
        PixelBox scaled;
        
        if(src.getWidth() != dstBox.getWidth() ||
           src.getHeight() != dstBox.getHeight() ||
           src.getDepth() != dstBox.getDepth())
        {
            // Scale to destination size.
            // This also does pixel format conversion if needed
            allocateBuffer();
            scaled = mBuffer.getSubVolume(dstBox);
            Image.scale(src, scaled, Image.Filter.FILTER_BILINEAR);
        }
        else if(GLPixelUtil.getGLOriginFormat(src.format) == 0)
        {
            // Extents match, but format is not accepted as valid source format for GL
            // do conversion in temporary buffer
            allocateBuffer();
            scaled = mBuffer.getSubVolume(dstBox);
            PixelUtil.bulkPixelConversion(src, scaled);
        }
        else
        {
            allocateBuffer();
            // No scaling or conversion needed
            scaled = src;
        }
        
        upload(scaled, dstBox);
        freeBuffer();
    }
    
    /// @copydoc HardwarePixelBuffer::blitToMemory
    //void blitToMemory(const(Image.Box) srcBox, /*const*/ ref PixelBox dst)
    override void blitToMemory(Image.Box srcBox, ref PixelBox dst)
    {
        if(!mBuffer.contains(srcBox))
            throw new InvalidParamsError("source box out of range",
                                         "GLHardwarePixelBuffer.blitToMemory");
        if(srcBox.left == 0 && srcBox.right == getWidth() &&
           srcBox.top == 0 && srcBox.bottom == getHeight() &&
           srcBox.front == 0 && srcBox.back == getDepth() &&
           dst.getWidth() == getWidth() &&
           dst.getHeight() == getHeight() &&
           dst.getDepth() == getDepth() &&
           GLPixelUtil.getGLOriginFormat(dst.format) != 0)
        {
            // The direct case: the user wants the entire texture in a format supported by GL
            // so we don't need an intermediate buffer
            download(dst);
        }
        else
        {
            // Use buffer for intermediate copy
            allocateBuffer();
            // Download entire buffer
            download(mBuffer);
            if(srcBox.getWidth() != dst.getWidth() ||
               srcBox.getHeight() != dst.getHeight() ||
               srcBox.getDepth() != dst.getDepth())
            {
                // We need scaling
                Image.scale(mBuffer.getSubVolume(srcBox), dst, Image.Filter.FILTER_BILINEAR);
            }
            else
            {
                // Just copy the bit that we need
                PixelUtil.bulkPixelConversion(mBuffer.getSubVolume(srcBox), dst);
            }
            freeBuffer();
        }
    }
    
    ~this()
    {
        // Force free buffer
        //delete [] (uint8*)mBuffer.data;
        destroy(mBuffer.data);
        mBuffer.data = null;
    }
    
    /** Bind surface to frame buffer. Needs FBO extension.
     */
    void bindToFramebuffer(GLenum attachment, size_t zoffset)
    {
        throw new RenderingApiError("Framebuffer bind not possible for this pixelbuffer type",
                                    "GLHardwarePixelBuffer.bindToFramebuffer");
    }

    GLenum getGLFormat() { return mGLInternalFormat; }
}

/** Texture surface.
 */
class GLTextureBuffer: GLHardwarePixelBuffer
{
public:
    /** Texture constructor */
    this(string baseName, GLenum target, GLuint id, 
         GLint face, GLint level, Usage usage, bool softwareMips, 
         bool writeGamma, uint fsaa)
    {
        super(0, 0, 0, PixelFormat.PF_UNKNOWN, usage);
        mTarget = target;
        mFaceTarget = 0;
        mTextureID = id;
        mFace = face;
        mLevel = level;
        mSoftwareMipmap = softwareMips;
        mHwGamma = writeGamma;

        // devise mWidth, mHeight and mDepth and mFormat
        GLint value = 0;
        
        glBindTexture( mTarget, mTextureID );
        
        // Get face identifier
        mFaceTarget = mTarget;
        if(mTarget == GL_TEXTURE_CUBE_MAP)
            mFaceTarget = GL_TEXTURE_CUBE_MAP_POSITIVE_X + face;
        
        // Get width
        glGetTexLevelParameteriv(mFaceTarget, level, GL_TEXTURE_WIDTH, &value);
        mWidth = value;
        
        // Get height
        if(target == GL_TEXTURE_1D)
            value = 1;  // Height always 1 for 1D textures
        else
            glGetTexLevelParameteriv(mFaceTarget, level, GL_TEXTURE_HEIGHT, &value);
        mHeight = value;
        
        // Get depth
        if(target != GL_TEXTURE_3D && target != GL_TEXTURE_2D_ARRAY)
            value = 1; // Depth always 1 for non-3D textures
        else
            glGetTexLevelParameteriv(mFaceTarget, level, GL_TEXTURE_DEPTH, &value);
        mDepth = value;
        
        // Get format
        glGetTexLevelParameteriv(mFaceTarget, level, GL_TEXTURE_INTERNAL_FORMAT, &value);
        mGLInternalFormat = value;
        mFormat = GLPixelUtil.getClosestOGREFormat(value);
        
        // Default
        mRowPitch = mWidth;
        mSlicePitch = mHeight*mWidth;
        mSizeInBytes = PixelUtil.getMemorySize(mWidth, mHeight, mDepth, mFormat);
        
        // Log a message
        static if(OGRE_GL_DBG)
        {
            import ogre.general.log;
            string str = std.conv.text ("GLHardwarePixelBuffer constructed for texture ", mTextureID 
                                        , " face ", mFace, " level ", mLevel, ": "
                                        , "width=", mWidth, " height=", mHeight, " depth=", mDepth
                                        , " format=", PixelUtil.getFormatName(mFormat), " (internal 0x"
                                        , std.string.format("%X", value), ")");
            LogManager.getSingleton().logMessage(LML_NORMAL, str);
        }

        // Set up pixel box
        mBuffer = new PixelBox(mWidth, mHeight, mDepth, mFormat);
        
        if(mWidth==0 || mHeight==0 || mDepth==0)
            /// We are invalid, do not allocate a buffer
            return;
        // Allocate buffer
        //if(mUsage & HBU_STATIC)
        //  allocateBuffer();
        // Is this a render target?
        if(mUsage & TextureUsage.TU_RENDERTARGET)
        {
            // Create render target for each slice
            mSliceTRT.reserve(mDepth);
            for(size_t zoffset=0; zoffset<mDepth; ++zoffset)
            {
                string name = std.conv.text("rtt/", cast(size_t)&this, "/", baseName);
                auto surface = GLSurfaceDesc(this, zoffset, 0);
                //FIXME Get proper singleton type
                RenderTexture trt = GLRTTManager.getSingleton().createRenderTexture(name, surface, writeGamma, fsaa);
                mSliceTRT ~= trt;
                Root.getSingleton().getRenderSystem().attachRenderTarget(mSliceTRT[zoffset]);
            }
        }
    }

    ~this()
    {
        if(mUsage & TextureUsage.TU_RENDERTARGET)
        {
            // Delete all render targets that are not yet deleted via _clearSliceRTT because the rendertarget
            // was deleted by the user.
            foreach (it; mSliceTRT)
            {
                Root.getSingleton().getRenderSystem().destroyRenderTarget(it.getName());
            }
        }
    }
    
    /// @copydoc GLHardwarePixelBuffer::bindToFramebuffer
    override void bindToFramebuffer(GLenum attachment, size_t zoffset)
    {
        assert(zoffset < mDepth);
        switch(mTarget)
        {
            case GL_TEXTURE_1D:
                glFramebufferTexture1D(GL_FRAMEBUFFER, attachment,
                                       mFaceTarget, mTextureID, mLevel);
                break;
            case GL_TEXTURE_2D:
            case GL_TEXTURE_CUBE_MAP:
                glFramebufferTexture2D(GL_FRAMEBUFFER, attachment,
                                       mFaceTarget, mTextureID, mLevel);
                break;
            case GL_TEXTURE_3D:
            case GL_TEXTURE_2D_ARRAY:
                glFramebufferTexture3D(GL_FRAMEBUFFER, attachment,
                                       mFaceTarget, mTextureID, mLevel, cast(GLint)zoffset);
                break;
            default:
                break;
        }
    }

    /// @copydoc HardwarePixelBuffer::getRenderTarget
    override RenderTexture getRenderTarget(size_t zoffset)
    {
        assert(mUsage & TextureUsage.TU_RENDERTARGET);
        assert(zoffset < mDepth);
        return mSliceTRT[zoffset];
    }

    /// Upload a box of pixels to this buffer on the card
    //override void upload(const(PixelBox) data, const(Image.Box) dest)
    override void upload(PixelBox data, Image.Box dest)
    {
        glBindTexture( mTarget, mTextureID );
        if(PixelUtil.isCompressed(data.format))
        {
            if(data.format != mFormat || !data.isConsecutive())
                throw new InvalidParamsError(
                    "Compressed images must be consecutive, in the source format",
                    "GLTextureBuffer.upload");
            GLenum format = GLPixelUtil.getClosestGLInternalFormat(mFormat, mHwGamma);
            // Data must be consecutive and at beginning of buffer as PixelStorei not allowed
            // for compressed formats
            switch(mTarget) {
                case GL_TEXTURE_1D:
                    // some systems (e.g. old Apple) don't like compressed subimage calls
                    // so prefer non-sub versions
                    if (dest.left == 0)
                    {
                        glCompressedTexImage1D(GL_TEXTURE_1D, mLevel,
                                               format,
                                               cast(GLint)dest.getWidth(),
                                               0,
                                               cast(GLint)data.getConsecutiveSize(),
                                               data.data);
                    }
                    else
                    {
                        glCompressedTexSubImage1D(GL_TEXTURE_1D, mLevel, 
                                                  cast(GLint)dest.left,
                                                  cast(GLint)dest.getWidth(),
                                                  format, cast(GLint)data.getConsecutiveSize(),
                                                  data.data);
                    }
                    break;
                case GL_TEXTURE_2D:
                case GL_TEXTURE_CUBE_MAP:
                    // some systems (e.g. old Apple) don't like compressed subimage calls
                    // so prefer non-sub versions
                    if (dest.left == 0 && dest.top == 0)
                    {
                        glCompressedTexImage2D(mFaceTarget, mLevel,
                                               format,
                                               cast(GLint)dest.getWidth(),
                                               cast(GLint)dest.getHeight(),
                                               0,
                                               cast(GLint)data.getConsecutiveSize(),
                                               data.data);
                    }
                    else
                    {
                        glCompressedTexSubImage2D(mFaceTarget, mLevel, 
                                                  cast(GLint)dest.left, cast(GLint)dest.top, 
                                                  cast(GLint)dest.getWidth(), cast(GLint)dest.getHeight(),
                                                  format, cast(GLint)data.getConsecutiveSize(),
                                                  data.data);
                    }
                    break;
                case GL_TEXTURE_3D:
                case GL_TEXTURE_2D_ARRAY:
                    // some systems (e.g. old Apple) don't like compressed subimage calls
                    // so prefer non-sub versions
                    if (dest.left == 0 && dest.top == 0 && dest.front == 0)
                    {
                        glCompressedTexImage3D(mTarget, mLevel,
                                               format,
                                               cast(GLint)dest.getWidth(),
                                               cast(GLint)dest.getHeight(),
                                               cast(GLint)dest.getDepth(),
                                               0,
                                               cast(GLint)data.getConsecutiveSize(),
                                               data.data);
                    }
                    else
                    {           
                        glCompressedTexSubImage3D(mTarget, mLevel, 
                                                  cast(GLint)dest.left, 
                                                  cast(GLint)dest.top, 
                                                  cast(GLint)dest.front,
                                                  cast(GLint)dest.getWidth(), cast(GLint)dest.getHeight(), 
                                                  cast(GLint)dest.getDepth(),
                                                  format, cast(GLint)data.getConsecutiveSize(),
                                                  data.data);
                    }
                    break;
                default:
                    break;//TODO explode
            }
            
        } 
        else if(mSoftwareMipmap)
        {
            GLint components = cast(GLint)PixelUtil.getComponentCount(mFormat);
            if(data.getWidth() != data.rowPitch)
                glPixelStorei(GL_UNPACK_ROW_LENGTH, cast(GLint)data.rowPitch);
            if(data.getHeight()*data.getWidth() != data.slicePitch)
                glPixelStorei(GL_UNPACK_IMAGE_HEIGHT, cast(GLint)(data.slicePitch/data.getWidth()));
            if(data.left > 0 || data.top > 0 || data.front > 0)
                glPixelStorei(GL_UNPACK_SKIP_PIXELS, cast(GLint)(data.left + data.rowPitch * data.top + data.slicePitch * data.front));
            glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
            
            switch(mTarget)
            {
                case GL_TEXTURE_1D:
                    gluBuild1DMipmaps(
                        GL_TEXTURE_1D, components,
                        cast(GLint)dest.getWidth(),
                        GLPixelUtil.getGLOriginFormat(data.format), GLPixelUtil.getGLOriginDataType(data.format),
                        data.data);
                    break;
                case GL_TEXTURE_2D:
                case GL_TEXTURE_CUBE_MAP:
                    gluBuild2DMipmaps(
                        mFaceTarget,
                        components, cast(GLint)dest.getWidth(), cast(GLint)dest.getHeight(), 
                        GLPixelUtil.getGLOriginFormat(data.format), GLPixelUtil.getGLOriginDataType(data.format), 
                        data.data);
                    break;      
                case GL_TEXTURE_3D:
                case GL_TEXTURE_2D_ARRAY:
                    /* Requires GLU 1.3 which is harder to come by than cards doing hardware mipmapping
                     Most 3D textures don't need mipmaps?
                     gluBuild3DMipmaps(
                     GL_TEXTURE_3D, internalFormat, 
                     data.getWidth(), data.getHeight(), data.getDepth(),
                     GLPixelUtil.getGLOriginFormat(data.format), GLPixelUtil.getGLOriginDataType(data.format),
                     data.data);
                     */
                    glTexImage3D(
                        mTarget, 0, components, 
                        cast(GLint)dest.getWidth(), cast(GLint)dest.getHeight(), 
                        cast(GLint)dest.getDepth(), 0, 
                        GLPixelUtil.getGLOriginFormat(data.format), GLPixelUtil.getGLOriginDataType(data.format),
                        data.data );
                    break;
                default:
                    break;//TODO explode
            }
        } 
        else
        {
            if(data.getWidth() != data.rowPitch)
                glPixelStorei(GL_UNPACK_ROW_LENGTH, cast(GLint)data.rowPitch);
            if(data.getWidth() > 0 && data.getHeight()*data.getWidth() != data.slicePitch)
                glPixelStorei(GL_UNPACK_IMAGE_HEIGHT, cast(GLint)(data.slicePitch/data.getWidth()));
            if(data.left > 0 || data.top > 0 || data.front > 0)
                glPixelStorei(GL_UNPACK_SKIP_PIXELS, cast(GLint)(data.left + data.rowPitch * data.top + data.slicePitch * data.front));
            if((data.getWidth()*PixelUtil.getNumElemBytes(data.format)) & 3) {
                // Standard alignment of 4 is not right
                glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
            }
            switch(mTarget) {
                case GL_TEXTURE_1D:
                    glTexSubImage1D(GL_TEXTURE_1D, mLevel, 
                                    cast(GLint)dest.left,
                                    cast(GLint)dest.getWidth(),
                                    GLPixelUtil.getGLOriginFormat(data.format), GLPixelUtil.getGLOriginDataType(data.format),
                                    data.data);
                    break;
                case GL_TEXTURE_2D:
                case GL_TEXTURE_CUBE_MAP:
                    glTexSubImage2D(mFaceTarget, mLevel, 
                                    cast(GLint)dest.left, cast(GLint)dest.top, 
                                    cast(GLint)dest.getWidth(), cast(GLint)dest.getHeight(),
                                    GLPixelUtil.getGLOriginFormat(data.format), GLPixelUtil.getGLOriginDataType(data.format),
                                    data.data);
                    break;
                case GL_TEXTURE_3D:
                case GL_TEXTURE_2D_ARRAY:
                    glTexSubImage3D(
                        mTarget, mLevel, 
                        cast(GLint)dest.left, cast(GLint)dest.top, cast(GLint)dest.front,
                        cast(GLint)dest.getWidth(), cast(GLint)dest.getHeight(), cast(GLint)dest.getDepth(),
                        GLPixelUtil.getGLOriginFormat(data.format), GLPixelUtil.getGLOriginDataType(data.format),
                        data.data);
                    break;
                default:
                    break;//TODO explode
            }   
        }
        // Restore defaults
        glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
        if (GLEW_VERSION_1_2)
            glPixelStorei(GL_UNPACK_IMAGE_HEIGHT, 0);
        glPixelStorei(GL_UNPACK_SKIP_PIXELS, 0);
        glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
    }

    /// Download a box of pixels from the card
    //override void download(const (PixelBox) data)
    override void download(PixelBox data)
    {
        if(data.getWidth() != getWidth() ||
           data.getHeight() != getHeight() ||
           data.getDepth() != getDepth())
            throw new InvalidParamsError("only download of entire buffer is supported by GL",
                                         "GLTextureBuffer.download");
        glBindTexture( mTarget, mTextureID );
        if(PixelUtil.isCompressed(data.format))
        {
            if(data.format != mFormat || !data.isConsecutive())
                throw new InvalidParamsError(
                    "Compressed images must be consecutive, in the source format",
                    "GLTextureBuffer.download");
            // Data must be consecutive and at beginning of buffer as PixelStorei not allowed
            // for compressed formate
            glGetCompressedTexImage/*ARB*/(mFaceTarget, mLevel, data.data);
        } 
        else
        {
            if(data.getWidth() != data.rowPitch)
                glPixelStorei(GL_PACK_ROW_LENGTH, cast(GLint)data.rowPitch);
            if(data.getHeight()*data.getWidth() != data.slicePitch)
                glPixelStorei(GL_PACK_IMAGE_HEIGHT, cast(GLint)(data.slicePitch/data.getWidth()));
            if(data.left > 0 || data.top > 0 || data.front > 0)
                glPixelStorei(GL_PACK_SKIP_PIXELS, cast(GLint)(data.left + data.rowPitch * data.top + data.slicePitch * data.front));
            if((data.getWidth()*PixelUtil.getNumElemBytes(data.format)) & 3) {
                // Standard alignment of 4 is not right
                glPixelStorei(GL_PACK_ALIGNMENT, 1);
            }
            // We can only get the entire texture
            glGetTexImage(mFaceTarget, mLevel, 
                          GLPixelUtil.getGLOriginFormat(data.format), GLPixelUtil.getGLOriginDataType(data.format),
                          data.data);
            // Restore defaults
            glPixelStorei(GL_PACK_ROW_LENGTH, 0);
            glPixelStorei(GL_PACK_IMAGE_HEIGHT, 0);
            glPixelStorei(GL_PACK_SKIP_PIXELS, 0);
            glPixelStorei(GL_PACK_ALIGNMENT, 4);
        }
    }
    
    /// Hardware implementation of blitFromMemory
    //override void blitFromMemory(const(PixelBox) src_orig, const(Image.Box) dstBox)
    override void blitFromMemory(PixelBox src_orig, Image.Box dstBox)
    {
        /// Fall back to normal GLHardwarePixelBuffer::blitFromMemory in case 
        /// - FBO is not supported
        /// - Either source or target is luminance due doesn't looks like supported by hardware
        /// - the source dimensions match the destination ones, in which case no scaling is needed
        if(!EXT_framebuffer_object ||
           PixelUtil.isLuminance(src_orig.format) ||
           PixelUtil.isLuminance(mFormat) ||
           (src_orig.getWidth() == dstBox.getWidth() &&
         src_orig.getHeight() == dstBox.getHeight() &&
         src_orig.getDepth() == dstBox.getDepth()))
        {
            GLHardwarePixelBuffer.blitFromMemory(src_orig, dstBox);
            return;
        }
        if(!mBuffer.contains(dstBox))
            throw new InvalidParamsError("destination box out of range",
                                         "GLTextureBuffer.blitFromMemory");
        /// For scoped deletion of conversion buffer
        MemoryDataStream buf;
        PixelBox src;
        
        /// First, convert the srcbox to a OpenGL compatible pixel format
        if(GLPixelUtil.getGLOriginFormat(src_orig.format) == 0)
        {
            /// Convert to buffer internal format
            buf = new MemoryDataStream(
                PixelUtil.getMemorySize(src_orig.getWidth(), src_orig.getHeight(), src_orig.getDepth(),
                                    mFormat));
            src = new PixelBox(src_orig.getWidth(), src_orig.getHeight(), src_orig.getDepth(), mFormat, buf.getPtr());
            PixelUtil.bulkPixelConversion(src_orig, src);
        }
        else
        {
            /// No conversion needed
            src = src_orig;
        }
        
        /// Create temporary texture to store source data
        GLuint id;
        GLenum target = (src.getDepth()!=1)?GL_TEXTURE_3D:GL_TEXTURE_2D;
        GLsizei width = cast(GLsizei)GLPixelUtil.optionalPO2(src.getWidth()); //TODO hope for now overflow
        GLsizei height = cast(GLsizei)GLPixelUtil.optionalPO2(src.getHeight());
        GLsizei depth = cast(GLsizei)GLPixelUtil.optionalPO2(src.getDepth());
        GLenum format = GLPixelUtil.getClosestGLInternalFormat(src.format, mHwGamma);
        
        /// Generate texture name
        glGenTextures(1, &id);
        
        /// Set texture type
        glBindTexture(target, id);
        
        /// Set automatic mipmap generation; nice for minimisation
        glTexParameteri(target, GL_TEXTURE_MAX_LEVEL, 1000 );
        glTexParameteri(target, GL_GENERATE_MIPMAP, GL_TRUE );
        
        /// Allocate texture memory
        if(target == GL_TEXTURE_3D || target == GL_TEXTURE_2D_ARRAY)
            glTexImage3D(target, 0, format, width, height, depth, 0, GL_RGBA, GL_UNSIGNED_BYTE, null);
        else
            glTexImage2D(target, 0, format, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, null);
        
        /// GL texture buffer
        GLTextureBuffer tex = new GLTextureBuffer(null, target, id, 0, 0, cast(Usage)(TextureUsage.TU_AUTOMIPMAP|Usage.HBU_STATIC_WRITE_ONLY), false, false, 0);
        
        /// Upload data to 0,0,0 in temporary texture
        Image.Box tempTarget = new Image.Box(0, 0, 0, src.getWidth(), src.getHeight(), src.getDepth());
        tex.upload(src, tempTarget);
        
        /// Blit
        blitFromTexture(tex, tempTarget, dstBox);
        
        /// Delete temp texture
        glDeleteTextures(1, &id);
    }
    
    /// Notify TextureBuffer of destruction of render target
    override void _clearSliceRTT(size_t zoffset)
    {
        mSliceTRT[zoffset] = null;
    }

    /// Copy from framebuffer
    void copyFromFramebuffer(size_t zoffset)
    {
        glBindTexture(mTarget, mTextureID);
        switch(mTarget)
        {
            case GL_TEXTURE_1D:
                glCopyTexSubImage1D(mFaceTarget, mLevel, 0, 0, 0, cast(GLint)mWidth);
                break;
            case GL_TEXTURE_2D:
            case GL_TEXTURE_CUBE_MAP:
                glCopyTexSubImage2D(mFaceTarget, mLevel, 0, 0, 0, 0, cast(GLint)mWidth, cast(GLint)mHeight);
                break;
            case GL_TEXTURE_3D:
            case GL_TEXTURE_2D_ARRAY:
                glCopyTexSubImage3D(mFaceTarget, mLevel, 0, 0, cast(GLint)zoffset, 0, 0, cast(GLint)mWidth, cast(GLint)mHeight);
                break;
            default:
                break; //TODO Explode?
        }
    }

    /// @copydoc HardwarePixelBuffer::blit
    //void blit(const(SharedPtr!HardwarePixelBuffer) src, const(Image.Box) srcBox, const(Image.Box) dstBox)
    override void blit(SharedPtr!HardwarePixelBuffer src, Image.Box srcBox, Image.Box dstBox)
    {
        GLTextureBuffer srct = cast(GLTextureBuffer)(src.get());
        /// Check for FBO support first
        /// Destination texture must be 1D, 2D, 3D, or Cube
        /// Source texture must be 1D, 2D or 3D
        
        // This does not seem to work for RTTs after the first update
        // I have no idea why! For the moment, disable 
        if(EXT_framebuffer_object && (src.get().getUsage() & TextureUsage.TU_RENDERTARGET) == 0 &&
           (srct.mTarget==GL_TEXTURE_1D||srct.mTarget==GL_TEXTURE_2D
         ||srct.mTarget==GL_TEXTURE_3D)&&mTarget!=GL_TEXTURE_2D_ARRAY)
        {
            blitFromTexture(srct, srcBox, dstBox);
        }
        else
        {
            GLHardwarePixelBuffer.blit(src, srcBox, dstBox);
        }
    }

    // Blitting implementation
    void blitFromTexture(GLTextureBuffer src, const(Image.Box) srcBox, const(Image.Box) dstBox)
    {
        //std::cerr << "GLTextureBuffer::blitFromTexture " <<
        //src.mTextureID << ":" << srcBox.left << "," << srcBox.top << "," << srcBox.right << "," << srcBox.bottom << " " << 
        //mTextureID << ":" << dstBox.left << "," << dstBox.top << "," << dstBox.right << "," << dstBox.bottom << std::endl;
        /// Store reference to FBO manager
        GLFBOManager fboMan = cast(GLFBOManager)GLRTTManager.getSingleton();
        
        /// Save and clear GL state for rendering
        glPushAttrib(GL_COLOR_BUFFER_BIT | GL_CURRENT_BIT | GL_DEPTH_BUFFER_BIT | GL_ENABLE_BIT | 
                     GL_FOG_BIT | GL_LIGHTING_BIT | GL_POLYGON_BIT | GL_SCISSOR_BIT | GL_STENCIL_BUFFER_BIT |
                     GL_TEXTURE_BIT | GL_VIEWPORT_BIT);
        
        // Important to disable all other texture units
        RenderSystem rsys = Root.getSingleton().getRenderSystem();
        rsys._disableTextureUnitsFrom(0);
        if (GLEW_VERSION_1_2)
        {
            glActiveTexture(GL_TEXTURE0);
        }
        
        
        /// Disable alpha, depth and scissor testing, disable blending, 
        /// disable culling, disble lighting, disable fog and reset foreground
        /// colour.
        glDisable(GL_ALPHA_TEST);
        glDisable(GL_DEPTH_TEST);
        glDisable(GL_SCISSOR_TEST);
        glDisable(GL_BLEND);
        glDisable(GL_CULL_FACE);
        glDisable(GL_LIGHTING);
        glDisable(GL_FOG);
        glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
        
        /// Save and reset matrices
        glMatrixMode(GL_MODELVIEW);
        glPushMatrix();
        glLoadIdentity();
        glMatrixMode(GL_PROJECTION);
        glPushMatrix();
        glLoadIdentity();
        glMatrixMode(GL_TEXTURE);
        glPushMatrix();
        glLoadIdentity();
        
        /// Set up source texture
        glBindTexture(src.mTarget, src.mTextureID);
        
        /// Set filtering modes depending on the dimensions and source
        if(srcBox.getWidth()==dstBox.getWidth() &&
           srcBox.getHeight()==dstBox.getHeight() &&
           srcBox.getDepth()==dstBox.getDepth())
        {
            /// Dimensions match -- use nearest filtering (fastest and pixel correct)
            glTexParameteri(src.mTarget, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
            glTexParameteri(src.mTarget, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        }
        else
        {
            /// Dimensions don't match -- use bi or trilinear filtering depending on the
            /// source texture.
            if(src.mUsage & TextureUsage.TU_AUTOMIPMAP)
            {
                /// Automatic mipmaps, we can safely use trilinear filter which
                /// brings greatly imporoved quality for minimisation.
                glTexParameteri(src.mTarget, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
                glTexParameteri(src.mTarget, GL_TEXTURE_MAG_FILTER, GL_LINEAR);    
            }
            else
            {
                /// Manual mipmaps, stay safe with bilinear filtering so that no
                /// intermipmap leakage occurs.
                glTexParameteri(src.mTarget, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
                glTexParameteri(src.mTarget, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            }
        }
        /// Clamp to edge (fastest)
        glTexParameteri(src.mTarget, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(src.mTarget, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri(src.mTarget, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
        
        /// Set origin base level mipmap to make sure we source from the right mip
        /// level.
        glTexParameteri(src.mTarget, GL_TEXTURE_BASE_LEVEL, src.mLevel);
        
        /// Store old binding so it can be restored later
        GLint oldfb;
        glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &oldfb);
        
        /// Set up temporary FBO
        glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, fboMan.getTemporaryFBO());
        
        GLuint tempTex = 0;
        if(!fboMan.checkFormat(mFormat))
        {
            /// If target format not directly supported, create intermediate texture
            GLenum tempFormat = GLPixelUtil.getClosestGLInternalFormat(fboMan.getSupportedAlternative(mFormat), mHwGamma);
            glGenTextures(1, &tempTex);
            glBindTexture(GL_TEXTURE_2D, tempTex);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0);
            /// Allocate temporary texture of the size of the destination area
            glTexImage2D(GL_TEXTURE_2D, 0, tempFormat, 
                         cast(GLint)GLPixelUtil.optionalPO2(dstBox.getWidth()), 
                         cast(GLint)GLPixelUtil.optionalPO2(dstBox.getHeight()), 
                         0, GL_RGBA, GL_UNSIGNED_BYTE, null);
            glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT,
                                      GL_TEXTURE_2D, tempTex, 0);
            /// Set viewport to size of destination slice
            glViewport(0, 0, cast(GLint)dstBox.getWidth(), cast(GLint)dstBox.getHeight());
        }
        else
        {
            /// We are going to bind directly, so set viewport to size and position of destination slice
            glViewport(cast(GLint)dstBox.left, cast(GLint)dstBox.top, cast(GLint)dstBox.getWidth(), cast(GLint)dstBox.getHeight());
        }
        
        /// Process each destination slice
        for(size_t slice=dstBox.front; slice<dstBox.back; ++slice)
        {
            if(!tempTex)
            {
                /// Bind directly
                bindToFramebuffer(GL_COLOR_ATTACHMENT0_EXT, slice);
            }
            /// Calculate source texture coordinates
            float u1 = cast(float)srcBox.left / cast(float)src.mWidth;
            float v1 = cast(float)srcBox.top / cast(float)src.mHeight;
            float u2 = cast(float)srcBox.right / cast(float)src.mWidth;
            float v2 = cast(float)srcBox.bottom / cast(float)src.mHeight;
            /// Calculate source slice for this destination slice
            float w = cast(float)(slice - dstBox.front) / cast(float)dstBox.getDepth();
            /// Get slice # in source
            w = w * cast(float)(srcBox.getDepth() + srcBox.front);
            /// Normalise to texture coordinate in 0.0 .. 1.0
            w = (w+0.5f) / cast(float)src.mDepth;
            
            /// Finally we're ready to rumble   
            glBindTexture(src.mTarget, src.mTextureID);
            glEnable(src.mTarget);
            glBegin(GL_QUADS);
            glTexCoord3f(u1, v1, w);
            glVertex2f(-1.0f, -1.0f);
            glTexCoord3f(u2, v1, w);
            glVertex2f(1.0f, -1.0f);
            glTexCoord3f(u2, v2, w);
            glVertex2f(1.0f, 1.0f);
            glTexCoord3f(u1, v2, w);
            glVertex2f(-1.0f, 1.0f);
            glEnd();
            glDisable(src.mTarget);
            
            if(tempTex)
            {
                /// Copy temporary texture
                glBindTexture(mTarget, mTextureID);
                switch(mTarget)
                {
                    case GL_TEXTURE_1D:
                        glCopyTexSubImage1D(mFaceTarget, mLevel, 
                                            cast(GLint)dstBox.left, 
                                            0, 0, cast(GLint)dstBox.getWidth());
                        break;
                    case GL_TEXTURE_2D:
                    case GL_TEXTURE_CUBE_MAP:
                        glCopyTexSubImage2D(mFaceTarget, mLevel, 
                                            cast(GLint)dstBox.left, cast(GLint)dstBox.top, 
                                            0, 0, cast(GLint)dstBox.getWidth(), cast(GLint)dstBox.getHeight());
                        break;
                    case GL_TEXTURE_3D:
                    case GL_TEXTURE_2D_ARRAY:
                        glCopyTexSubImage3D(mFaceTarget, mLevel, 
                                            cast(GLint)dstBox.left, cast(GLint)dstBox.top, cast(GLint)slice, 
                                            0, 0, cast(GLint)dstBox.getWidth(), cast(GLint)dstBox.getHeight());
                        break;
                    default:
                        break;
                }
            }
        }
        /// Finish up 
        if(!tempTex)
        {
            /// Generate mipmaps
            if(mUsage & TextureUsage.TU_AUTOMIPMAP)
            {
                glBindTexture(mTarget, mTextureID);
                glGenerateMipmapEXT(mTarget);
            }
        }
        
        /// Reset source texture to sane state
        glBindTexture(src.mTarget, src.mTextureID);
        glTexParameteri(src.mTarget, GL_TEXTURE_BASE_LEVEL, 0);
        
        /// Detach texture from temporary framebuffer
        glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT,
                                     GL_RENDERBUFFER_EXT, 0);
        /// Restore old framebuffer
        glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, oldfb);
        /// Restore matrix stacks and render state
        glMatrixMode(GL_TEXTURE);
        glPopMatrix();
        glMatrixMode(GL_PROJECTION);
        glPopMatrix();
        glMatrixMode(GL_MODELVIEW);
        glPopMatrix();
        glPopAttrib();
        glDeleteTextures(1, &tempTex);
    }
protected:
    // In case this is a texture level
    GLenum mTarget;
    GLenum mFaceTarget; // same as mTarget in case of GL_TEXTURE_xD, but cubemap face for cubemaps
    GLuint mTextureID;
    GLint mFace;
    GLint mLevel;
    bool mSoftwareMipmap;       // Use GLU for mip mapping
    bool mHwGamma;
    
    //typedef vector<RenderTexture*>::type SliceTRT;
    alias RenderTexture[] SliceTRT;
    SliceTRT mSliceTRT;
}

/** Renderbuffer surface.  Needs FBO extension.
 */
class GLRenderBuffer: GLHardwarePixelBuffer
{
public:
    this(GLenum format, size_t width, size_t height, GLsizei numSamples)
    {
        super(width, height, 1, GLPixelUtil.getClosestOGREFormat(format), Usage.HBU_WRITE_ONLY);
        mRenderbufferID = 0;
        mGLInternalFormat = format;
        /// Generate renderbuffer
        glGenRenderbuffers(1, &mRenderbufferID);
        /// Bind it to FBO
        glBindRenderbuffer(GL_RENDERBUFFER, mRenderbufferID);
        
        /// Allocate storage for depth buffer
        if (numSamples > 0)
        {
            glRenderbufferStorageMultisample(GL_RENDERBUFFER, 
                                             numSamples, format, cast(GLint)width, cast(GLint)height);
        }
        else
        {
            glRenderbufferStorage(GL_RENDERBUFFER, format,
                                  cast(GLint)width, cast(GLint)height);
        }
    }

    ~this()
    {
        /// Generate renderbuffer
        glDeleteRenderbuffers(1, &mRenderbufferID);
    }
    
    /// @copydoc GLHardwarePixelBuffer::bindToFramebuffer
    override void bindToFramebuffer(GLenum attachment, size_t zoffset)
    {
        assert(zoffset < mDepth);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, attachment,
                                  GL_RENDERBUFFER, mRenderbufferID);
    }

protected:
    // In case this is a render buffer
    GLuint mRenderbufferID;
}