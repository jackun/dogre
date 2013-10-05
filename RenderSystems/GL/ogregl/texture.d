module ogregl.texture;
import std.string : indexOf;
import derelict.opengl3.gl;
import ogre.exception;
import ogre.resources.texture;
import ogre.resources.resourcemanager;
import ogre.resources.resource;
import ogre.rendersystem.hardware;
import ogre.general.root;
import ogre.rendersystem.rendersystem;
import ogre.resources.texturemanager;
import ogre.image.images;
import ogre.sharedptr;
import ogregl.pixelformat;
import ogregl.support;
import ogre.resources.datastream;
import ogre.resources.resourcegroupmanager;
import ogregl.glew;
import ogregl.hardwarepixelbuffer;

alias derelict.opengl3.constants.GL_RGBA GL_RGBA;

static void do_image_io(string name, string group,
                        string ext,
                        ref Image[] images,
                        Resource r)
{
    size_t imgIdx = images.length;
    images ~= new Image();
    
    DataStream dstream = 
        ResourceGroupManager.getSingleton().openResource(
            name, group, true, r);
    
    images[imgIdx].load(dstream, ext);
}

class GLTexture : Texture
{
public:
    // Constructor
    this(ResourceManager creator, string name, ResourceHandle handle,
         string group, bool isManual, ManualResourceLoader loader, 
         GLSupport* support)
    {
        super(creator, name, handle, group, isManual, loader);
        mTextureID = 0; 
        mGLSupport = support;
    }
    
    ~this()
    {
        // have to call this here rather than in Resource destructor
        // since calling virtual methods in base destructors causes crash
        if (isLoaded())
        {
            unload(); 
        }
        else
        {
            freeInternalResources();
        }
    }
    
    void createRenderTexture()
    {
        // Create the GL texture
        // This already does everything necessary
        createInternalResources();
    }
    
    /// @copydoc Texture::getBuffer
    override SharedPtr!HardwarePixelBuffer getBuffer(size_t face, size_t mipmap)
    {
        if(face >= getNumFaces())
            throw new InvalidParamsError("Face index out of range",
                                         "GLTexture.getBuffer");
        if(mipmap > mNumMipmaps)
            throw new InvalidParamsError("Mipmap index out of range",
                                         "GLTexture.getBuffer");
        uint idx = cast(uint)(face*(mNumMipmaps+1) + mipmap);
        assert(idx < mSurfaceList.length);
        return mSurfaceList[idx];
    }
    
    // Takes the OGRE texture type (1d/2d/3d/cube) and returns the appropriate GL one
    GLenum getGLTextureTarget() const
    {
        switch(mTextureType)
        {
            case TextureType.TEX_TYPE_1D:
                return GL_TEXTURE_1D;
            case TextureType.TEX_TYPE_2D:
                return GL_TEXTURE_2D;
            case TextureType.TEX_TYPE_3D:
                return GL_TEXTURE_3D;
            case TextureType.TEX_TYPE_CUBE_MAP:
                return GL_TEXTURE_CUBE_MAP;
            case TextureType.TEX_TYPE_2D_ARRAY:
                return GL_TEXTURE_2D_ARRAY;
            default:
                return 0;
        }
    }
    
    GLuint getGLID() const
    {
        return mTextureID;
    }
    
    override void getCustomAttribute(string name, void* pData)
    {
        if (name == "GLID")
            *(cast(GLuint*)pData) = mTextureID;
    }
    
protected:
    /// @copydoc Texture::createInternalResourcesImpl
    override void createInternalResourcesImpl()
    {
        if (!GLEW_VERSION_1_2 && mTextureType == TextureType.TEX_TYPE_3D)
            throw new NotImplementedError(
                "3D Textures not supported before OpenGL 1.2", 
                "GLTexture.createInternalResourcesImpl");
        
        if (!GLEW_VERSION_2_0 && mTextureType == TextureType.TEX_TYPE_2D_ARRAY)
            throw new NotImplementedError(
                "2D texture arrays not supported before OpenGL 2.0", 
                "GLTexture.createInternalResourcesImpl");
        
        // Convert to nearest power-of-two size if required
        mWidth = GLPixelUtil.optionalPO2(mWidth);      
        mHeight = GLPixelUtil.optionalPO2(mHeight);
        mDepth = GLPixelUtil.optionalPO2(mDepth);
        
        
        // Adjust format if required
        mFormat = TextureManager.getSingleton().getNativeFormat(mTextureType, mFormat, mUsage);
        
        // Check requested number of mipmaps
        size_t maxMips = GLPixelUtil.getMaxMipmaps(mWidth, mHeight, mDepth, mFormat);
        mNumMipmaps = mNumRequestedMipmaps;
        if(mNumMipmaps>maxMips)
            mNumMipmaps = maxMips;
        
        // Generate texture name
        glGenTextures( 1, &mTextureID );
        
        // Set texture type
        glBindTexture( getGLTextureTarget(), mTextureID );
        
        // This needs to be set otherwise the texture doesn't get rendered
        if (GLEW_VERSION_1_2)
            glTexParameteri( getGLTextureTarget(), GL_TEXTURE_MAX_LEVEL, cast(GLint)mNumMipmaps );
        
        // Set some misc default parameters so NVidia won't complain, these can of course be changed later
        glTexParameteri(getGLTextureTarget(), GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(getGLTextureTarget(), GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        if (GLEW_VERSION_1_2)
        {
            glTexParameteri(getGLTextureTarget(), GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameteri(getGLTextureTarget(), GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        }
        
        // If we can do automip generation and the user desires this, do so
        mMipmapsHardwareGenerated = 
            Root.getSingleton().getRenderSystem().getCapabilities().hasCapability(Capabilities.RSC_AUTOMIPMAP);
        
        if((mUsage & TextureUsage.TU_AUTOMIPMAP) &&
           mNumRequestedMipmaps && mMipmapsHardwareGenerated)
        {
            glTexParameteri( getGLTextureTarget(), GL_GENERATE_MIPMAP, GL_TRUE );
        }
        
        // Allocate internal buffer so that glTexSubImageXD can be used
        // Internal format
        GLenum format = GLPixelUtil.getClosestGLInternalFormat(mFormat, mHwGamma);
        size_t width = mWidth;
        size_t height = mHeight;
        size_t depth = mDepth;
        
        if(PixelUtil.isCompressed(mFormat))
        {
            // Compressed formats
            size_t size = PixelUtil.getMemorySize(mWidth, mHeight, mDepth, mFormat);
            // Provide temporary buffer filled with zeroes as glCompressedTexImageXD does not
            // accept a 0 pointer like normal glTexImageXD
            // Run through this process for every mipmap to pregenerate mipmap piramid
            ubyte[] tmpdata = new ubyte[size];
            //memset(tmpdata.ptr, 0, size);
            
            for(size_t mip=0; mip<=mNumMipmaps; mip++)
            {
                size = PixelUtil.getMemorySize(width, height, depth, mFormat);
                switch(mTextureType)
                {
                    case TextureType.TEX_TYPE_1D:
                        glCompressedTexImage1D(GL_TEXTURE_1D, cast(GLint)mip, format, 
                                               cast(GLint)width, 0, 
                                               cast(GLint)size, tmpdata.ptr);
                        break;
                    case TextureType.TEX_TYPE_2D:
                        glCompressedTexImage2D(GL_TEXTURE_2D, cast(GLint)mip, format,
                                               cast(GLint)width, cast(GLint)height, 0, 
                                               cast(GLint)size, tmpdata.ptr);
                        break;
                    case TextureType.TEX_TYPE_2D_ARRAY:
                    case TextureType.TEX_TYPE_3D:
                        glCompressedTexImage3D(getGLTextureTarget(), cast(GLint)mip, format,
                                               cast(GLint)width, cast(GLint)height, cast(GLint)depth, 0, 
                                               cast(GLint)size, tmpdata.ptr);
                        break;
                    case TextureType.TEX_TYPE_CUBE_MAP:
                        for(int face=0; face<6; face++) {
                            glCompressedTexImage2D(cast(GLenum)(GL_TEXTURE_CUBE_MAP_POSITIVE_X + face), cast(GLint)mip, format,
                                                   cast(GLint)width, cast(GLint)height, 0, 
                                                   cast(GLint)size, tmpdata.ptr);
                        }
                        break;
                    default:
                        break;
                }
                
                if(width>1)
                    width = width/2;
                if(height>1)
                    height = height/2;
                if(depth>1 && mTextureType != TextureType.TEX_TYPE_2D_ARRAY)
                    depth = depth/2;
            }
            destroy(tmpdata);
        }
        else
        {
            // Run through this process to pregenerate mipmap pyramid
            for(size_t mip=0; mip<=mNumMipmaps; mip++)
            {
                // Normal formats
                switch(mTextureType)
                {
                    case TextureType.TEX_TYPE_1D:
                        glTexImage1D(GL_TEXTURE_1D, cast(GLint)mip, format,
                                     cast(GLint)width, 0, 
                                     GL_RGBA, GL_UNSIGNED_BYTE, null);
                        
                        break;
                    case TextureType.TEX_TYPE_2D:
                        glTexImage2D(GL_TEXTURE_2D, cast(GLint)mip, format,
                                     cast(GLint)width, cast(GLint)height, 0, 
                                     GL_RGBA, GL_UNSIGNED_BYTE, null);
                        break;
                    case TextureType.TEX_TYPE_2D_ARRAY:
                    case TextureType.TEX_TYPE_3D:
                        glTexImage3D(getGLTextureTarget(), cast(GLint)mip, format,
                                     cast(GLint)width, cast(GLint)height, cast(GLint)depth, 0, 
                                     GL_RGBA, GL_UNSIGNED_BYTE, null);
                        break;
                    case TextureType.TEX_TYPE_CUBE_MAP:
                        for(int face=0; face<6; face++) {
                            glTexImage2D(cast(GLenum)(GL_TEXTURE_CUBE_MAP_POSITIVE_X + face), cast(GLint)mip, format,
                                         cast(GLint)width, cast(GLint)height, 0, 
                                         GL_RGBA, GL_UNSIGNED_BYTE, null);
                        }
                        break;
                    default:
                        break;
                }
                if(width>1)
                    width = width/2;
                if(height>1)
                    height = height/2;
                if(depth>1 && mTextureType != TextureType.TEX_TYPE_2D_ARRAY)
                    depth = depth/2;
            }
        }
        _createSurfaceList();
        // Get final internal format
        mFormat = getBuffer(0,0).get().getFormat();
    }

    /// @copydoc Resource::prepareImpl
    override void prepareImpl()
    {
        if( mUsage & TextureUsage.TU_RENDERTARGET ) return;
        
        string baseName, ext;
        size_t pos = mName.indexOf(".");
        if( pos != -1 )
        {
            baseName = mName[0..pos];
            ext = mName[pos+1 ..$];
        }
        else
            baseName = mName;

        LoadedImages loadedImages;// = new LoadedImages;//(new vector<Image>::type());
        
        if(mTextureType == TextureType.TEX_TYPE_1D || mTextureType == TextureType.TEX_TYPE_2D || 
           mTextureType == TextureType.TEX_TYPE_2D_ARRAY || mTextureType == TextureType.TEX_TYPE_3D)
        {
            
            do_image_io(mName, mGroup, ext, loadedImages/*.get()*/, this);
            
            // If this is a cube map, set the texture type flag accordingly.
            if (loadedImages/*.get()*/[0].hasFlag(ImageFlags.IF_CUBEMAP))
                mTextureType = TextureType.TEX_TYPE_CUBE_MAP;
            // If this is a volumetric texture set the texture type flag accordingly.
            if(loadedImages/*.get()*/[0].getDepth() > 1 && mTextureType != TextureType.TEX_TYPE_2D_ARRAY)
                mTextureType = TextureType.TEX_TYPE_3D;
            
        }
        else if (mTextureType == TextureType.TEX_TYPE_CUBE_MAP)
        {
            if(getSourceFileType() == "dds")
            {
                // XX HACK there should be a better way to specify whether 
                // all faces are in the same file or not
                do_image_io(mName, mGroup, ext, loadedImages/*.get()*/, this);
            }
            else
            {
                Image[] images;
                static const (string[]) suffixes = ["_rt", "_lf", "_up", "_dn", "_fr", "_bk"];
                
                for(size_t i = 0; i < 6; i++)
                {
                    string fullName = baseName ~ suffixes[i];
                    if (!ext.length)
                        fullName ~= "." ~ ext;
                    // find & load resource data intro stream to allow resource
                    // group changes if required
                    do_image_io(fullName,mGroup,ext,loadedImages/*.get()*/,this);
                }
            }
        }
        else
            throw new NotImplementedError("**** Unknown texture type ****", "GLTexture.prepare" );
        
        mLoadedImages = loadedImages;
    }

    /// @copydoc Resource::unprepareImpl
    override void unprepareImpl()
    {
        mLoadedImages = null;//.setNull();
    }

    /// @copydoc Resource::loadImpl
    override void loadImpl()
    {
        if( mUsage & TextureUsage.TU_RENDERTARGET )
        {
            createRenderTexture();
            return;
        }

        //FIXME sharedptr stuff
        // Now the only copy is on the stack and will be cleaned in case of
        // exceptions being thrown from _loadImages
        LoadedImages loadedImages = mLoadedImages;
        mLoadedImages = null;//.setNull();
        
        // Call internal _loadImages, not loadImage since that's external and 
        // will determine load status etc again
        //ConstImagePtrList imagePtrs;
        Image*[] imagePtrs;
        for (size_t i=0 ; i < loadedImages.length ; ++i) {
            imagePtrs ~= &(loadedImages[i]);
        }
        
        _loadImages(imagePtrs);
        
    }

    /// @copydoc Texture::freeInternalResourcesImpl
    override void freeInternalResourcesImpl()
    {
        mSurfaceList.clear();
        glDeleteTextures( 1, &mTextureID );
    }
    
    /** internal method, create GLHardwarePixelBuffers for every face and
     mipmap level. This method must be called after the GL texture object was created,
     the number of mipmaps was set (GL_TEXTURE_MAX_LEVEL) and glTexImageXD was called to
     actually allocate the buffer
     */
    void _createSurfaceList()
    {
        mSurfaceList.clear();
        
        // For all faces and mipmaps, store surfaces as SharedPtr!HardwarePixelBuffer
        bool wantGeneratedMips = (mUsage & TextureUsage.TU_AUTOMIPMAP)!=0;
        
        // Do mipmapping in software? (uses GLU) For some cards, this is still needed. Of course,
        // only when mipmap generation is desired.
        bool doSoftware = wantGeneratedMips && !mMipmapsHardwareGenerated && getNumMipmaps(); 
        
        for(int face=0; face<getNumFaces(); face++)
        {
            for(int mip=0; mip<=getNumMipmaps(); mip++)
            {
                GLHardwarePixelBuffer buf = new GLTextureBuffer(mName, getGLTextureTarget(), mTextureID, face, mip,
                                                                cast(HardwareBuffer.Usage)(mUsage), doSoftware && mip==0, mHwGamma, mFSAA);
                mSurfaceList ~= SharedPtr!HardwarePixelBuffer(buf);
                
                /// Check for error
                if(buf.getWidth()==0 || buf.getHeight()==0 || buf.getDepth()==0)
                {
                    throw new RenderingApiError(
                        "Zero sized texture surface on texture "~getName()~
                        " face "~to!string(face)~
                        " mipmap "~to!string(mip)~
                        ". Probably, the GL driver refused to create the texture.", 
                        "GLTexture._createSurfaceList");
                }
            }
        }
    }
    
    /// Used to hold images between calls to prepare and load.
    //typedef SharedPtr<vector<Image>::type > LoadedImages;
    //NO alias SharedPtr!(Image[]) LoadedImages; //TODO SharedPtr? 
    alias Image[] LoadedImages; //TODO SharedPtr? 
    
    /** Vector of images that were pulled from disk by
     prepareLoad but have yet to be pushed into texture memory
     by loadImpl.  Images should be deleted by loadImpl and unprepareImpl.
     */
    LoadedImages mLoadedImages;
    
    
private:
    GLuint mTextureID;
    GLSupport* mGLSupport;
    
    /// Vector of pointers to subsurfaces
    //typedef vector<SharedPtr!HardwarePixelBuffer>::type SurfaceList;
    alias SharedPtr!HardwarePixelBuffer[] SurfaceList;
    /// aka SurfaceList
    SharedPtr!HardwarePixelBuffer[] mSurfaceList;
}

alias SharedPtr!GLTexture GLTexturePtr;