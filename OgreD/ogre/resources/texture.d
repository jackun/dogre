module ogre.resources.texture;

//import std.container;
import std.string;
import core.sync.mutex;

import ogre.compat;
import ogre.image.pixelformat;
import ogre.image.images;
import ogre.sharedptr;
import ogre.exception;
import ogre.general.generals;
import ogre.rendersystem.hardware;
import ogre.resources.resource;
import ogre.resources.resourcemanager;
import ogre.resources.datastream;
import ogre.resources.texturemanager;
import ogre.resources.resourcegroupmanager;
import ogre.general.log;
public import ogre.sharedptr;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Resources
 *  @{
 */

/** Enum identifying the texture usage
 */
enum TextureUsage : uint
{
    /// @copydoc HardwareBuffer.Usage
    TU_STATIC = HardwareBuffer.Usage.HBU_STATIC,
    TU_DYNAMIC = HardwareBuffer.Usage.HBU_DYNAMIC,
    TU_WRITE_ONLY = HardwareBuffer.Usage.HBU_WRITE_ONLY,
    TU_STATIC_WRITE_ONLY = HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY, 
    TU_DYNAMIC_WRITE_ONLY = HardwareBuffer.Usage.HBU_DYNAMIC_WRITE_ONLY,
    TU_DYNAMIC_WRITE_ONLY_DISCARDABLE = HardwareBuffer.Usage.HBU_DYNAMIC_WRITE_ONLY_DISCARDABLE,
    /// mipmaps will be automatically generated for this texture
    TU_AUTOMIPMAP = 0x100,
    /// this texture will be a render target, i.e. used as a target for render to texture
    /// setting this flag will ignore all other texture usages except TU_AUTOMIPMAP
    TU_RENDERTARGET = 0x200,
    /// default to automatic mipmap generation static textures
    TU_DEFAULT = TU_AUTOMIPMAP | TU_STATIC_WRITE_ONLY
    
}

/** Enum identifying the texture type
 */
enum TextureType
{
    /// 1D texture, used in combination with 1D texture coordinates
    TEX_TYPE_1D = 1,
    /// 2D texture, used in combination with 2D texture coordinates (default)
    TEX_TYPE_2D = 2,
    /// 3D volume texture, used in combination with 3D texture coordinates
    TEX_TYPE_3D = 3,
    /// 3D cube map, used in combination with 3D texture coordinates
    TEX_TYPE_CUBE_MAP = 4,
    /// 2D texture array
    TEX_TYPE_2D_ARRAY = 5
}

/** Enum identifying special mipmap numbers
 */
enum TextureMipmap : int
{
    /// Generate mipmaps up to 1x1
    MIP_UNLIMITED = 0x7FFFFFFF,
    /// Use TextureManager default
    MIP_DEFAULT = -1
}

/** Abstract class representing a Texture resource.
 @remarks
 The actual concrete subclass which will exist for a texture
 is dependent on the rendering system in use (Direct3D, OpenGL etc).
 This class represents the commonalities, and is the one 'used'
 by programmers even though the real implementation could be
 different in reality. Texture objects are created through
 the 'create' method of the TextureManager concrete subclass.
 */
class Texture : Resource
{
public:
    this(ref ResourceManager creator,string name, ResourceHandle handle,
         string group, bool isManual = false, ManualResourceLoader loader = null)
    {   
        super(creator, name, handle, group, isManual, loader);
        mHeight = 512;
        mWidth = 512;
        mDepth = 1;
        mNumRequestedMipmaps = 0;
        mNumMipmaps = 0;
        mMipmapsHardwareGenerated = false;
        mGamma = 1.0f;
        mHwGamma = false;
        mFSAA = 0;
        mTextureType = TextureType.TEX_TYPE_2D;
        mFormat = PixelFormat.PF_UNKNOWN;
        mUsage = TextureUsage.TU_DEFAULT;
        mSrcFormat = PixelFormat.PF_UNKNOWN;
        mSrcWidth = 0;
        mSrcHeight = 0;
        mSrcDepth = 0;
        mDesiredFormat = PixelFormat.PF_UNKNOWN;
        mDesiredIntegerBitDepth = 0;
        mDesiredFloatBitDepth = 0;
        mTreatLuminanceAsAlpha = false;
        mInternalResourcesCreated = false;
        
        if (createParamDictionary("Texture"))
        {
            // Define the parameters that have to be present to load
            // from a generic source; actually there are none, since when
            // predeclaring, you use a texture file which includes all the
            // information required.
        }
        
        // Set some defaults for default load path
        if (TextureManager.getSingletonPtr())
        {
            TextureManager tmgr = TextureManager.getSingleton();
            setNumMipmaps(tmgr.getDefaultNumMipmaps());
            setDesiredBitDepths(tmgr.getPreferredIntegerBitDepth(), tmgr.getPreferredFloatBitDepth());
        }
    }
    
    ~this() {}
    
    /** Sets the type of texture; can only be changed before load() 
     */
    void setTextureType(TextureType ttype ) { mTextureType = ttype; }
    
    /** Gets the type of texture 
     */
    TextureType getTextureType(){ return mTextureType; }
    
    /** Gets the number of mipmaps to be used for this texture.
     */
    size_t getNumMipmaps(){return mNumMipmaps;}
    
    /** Sets the number of mipmaps to be used for this texture.
     @note
     Must be set before calling any 'load' method.
     */
    void setNumMipmaps(size_t num) {mNumRequestedMipmaps = mNumMipmaps = num;}
    
    /** Are mipmaps hardware generated?
     @remarks
     Will only be accurate after texture load, or createInternalResources
     */
    bool getMipmapsHardwareGenerated(){ return mMipmapsHardwareGenerated; }
    
    /** Returns the gamma adjustment factor applied to this texture on loading.
     */
    float getGamma(){ return mGamma; }
    
    /** Sets the gamma adjustment factor applied to this texture on loading the
     data.
     @note
     Must be called before any 'load' method. This gamma factor will
     be premultiplied in and may reduce the precision of your textures.
     You can use setHardwareGamma if supported to apply gamma on 
     sampling the texture instead.
     */
    void setGamma(float g) { mGamma = g; }
    
    /** Sets whether this texture will be set up so that on sampling it, 
     hardware gamma correction is applied.
     @remarks
     24-bit textures are often saved in gamma colour space; this preserves
     precision in the 'darks'. However, if you're performing blending on 
     the sampled colours, you really want to be doing it in linear space. 
     One way is to apply a gamma correction value on loading (see setGamma),
     but this means you lose precision in those dark colours. An alternative
     is to get the hardware to do the gamma correction when reading the 
     texture and converting it to a floating point value for the rest of
     the pipeline. This option allows you to do that; it's only supported
     in relatively recent hardware (others will ignore it) but can improve
     the quality of colour reproduction.
     @note
     Must be called before any 'load' method since it may affect the
     construction of the underlying hardware resources.
     Also note this only useful on textures using 8-bit colour channels.
     */
    void setHardwareGammaEnabled(bool enabled) { mHwGamma = enabled; }
    
    /** Gets whether this texture will be set up so that on sampling it, 
     hardware gamma correction is applied.
     */
    bool isHardwareGammaEnabled(){ return mHwGamma; }
    
    /** Set the level of multisample AA to be used if this texture is a 
     rendertarget.
     @note This option will be ignored if TU_RENDERTARGET is not part of the
     usage options on this texture, or if the hardware does not support it. 
     @param fsaa The number of samples
     @param fsaaHint Any hinting text (@see Root.createRenderWindow)
     */
    void setFSAA(uint fsaa,string fsaaHint) { mFSAA = fsaa; mFSAAHint = fsaaHint; }
    
    /** Get the level of multisample AA to be used if this texture is a 
     rendertarget.
     */
    uint getFSAA(){ return mFSAA; }
    
    /** Get the multisample AA hint if this texture is a rendertarget.
     */
    string getFSAAHint(){ return mFSAAHint; }
    
    /** Returns the height of the texture.
     */
    size_t getHeight(){ return mHeight; }
    
    /** Returns the width of the texture.
     */
    size_t getWidth(){ return mWidth; }
    
    /** Returns the depth of the texture (only applicable for 3D textures).
     */
    size_t getDepth(){ return mDepth; }
    
    /** Returns the height of the original input texture (may differ due to hardware requirements).
     */
    size_t getSrcHeight(){ return mSrcHeight; }
    
    /** Returns the width of the original input texture (may differ due to hardware requirements).
     */
    size_t getSrcWidth(){ return mSrcWidth; }
    
    /** Returns the original depth of the input texture (only applicable for 3D textures).
     */
    size_t getSrcDepth(){ return mSrcDepth; }
    
    /** Set the height of the texture; can only do this before load();
     */
    void setHeight(size_t h) { mHeight = mSrcHeight = h; }
    
    /** Set the width of the texture; can only do this before load();
     */
    void setWidth(size_t w) { mWidth = mSrcWidth = w; }
    
    /** Set the depth of the texture (only applicable for 3D textures);
     can only do this before load();
     */
    void setDepth(size_t d)  { mDepth = mSrcDepth = d; }
    
    /** Returns the TextureUsage identifier for this Texture
     */
    int getUsage()
    {
        return mUsage;
    }
    
    /** Sets the TextureUsage identifier for this Texture; only useful before load()
     
     @param u is a combination of TU_STATIC, TU_DYNAMIC, TU_WRITE_ONLY 
     TU_AUTOMIPMAP and TU_RENDERTARGET (see TextureUsage enum). You are
     strongly advised to use HBU_STATIC_WRITE_ONLY wherever possible, if you need to 
     update regularly, consider HBU_DYNAMIC_WRITE_ONLY.
     */
    void setUsage(int u) { mUsage = u; }
    
    /** Creates the internal texture resources for this texture. 
     @remarks
     This method creates the internal texture resources (pixel buffers, 
     texture surfaces etc) required to begin using this texture. You do
     not need to call this method directly unless you are manually creating
     a texture, in which case something must call it, after having set the
     size and format of the texture (e.g. the ManualResourceLoader might
     be the best one to call it). If you are not defining a manual texture,
     or if you use one of the self-contained load...() methods, then it will be
     called for you.
     */
    void createInternalResources()
    {
        if (!mInternalResourcesCreated)
        {
            createInternalResourcesImpl();
            mInternalResourcesCreated = true;
        }
    }
    
    /** Frees internal texture resources for this texture. 
     */
    void freeInternalResources()
    {
        if (mInternalResourcesCreated)
        {
            freeInternalResourcesImpl();
            mInternalResourcesCreated = false;
        }
    }
    
    /** Copies (and maybe scales to fit) the contents of this texture to
     another texture. */
    void copyToTexture( ref SharedPtr!Texture target )
    {
        if(target.getAs().getNumFaces() != getNumFaces())
        {
            throw new InvalidParamsError(
                "Texture types must match",
                "Texture.copyToTexture");
        }
        size_t numMips = std.algorithm.min(getNumMipmaps(), target.getAs().getNumMipmaps());
        if((mUsage & TextureUsage.TU_AUTOMIPMAP) || (target.getAs().getUsage() & TextureUsage.TU_AUTOMIPMAP))
            numMips = 0;
        foreach(face; 0 .. getNumFaces())
        {
            foreach(mip; 0 .. numMips+1) // mip<=numMips
            {
                target.getAs().getBuffer(face, mip).get().blit(getBuffer(face, mip));
            }
        }
    }
    
    /** Loads the data from an image.
     @note Important: only call this from outside the load() routine of a 
     Resource. Don't call it within (including ManualResourceLoader) - use
     _loadImages() instead. This method is designed to be external, 
     performs locking and checks the load status before loading.
     */
    void loadImage( ref Image img )
    {
        
        LoadingState old = mLoadingState.get();
        if (old!=LoadingState.UNLOADED && old!=LoadingState.PREPARED) return;
        
        if (!mLoadingState.cas(old,LoadingState.LOADING)) return;
        
        // Scope lock for actual loading
        try
        {
            synchronized(mLock)
            {
                Image*[] imagePtrs;//FIXME some pointer stuff
                imagePtrs.insert(&img);
                _loadImages( imagePtrs );
            }
        }
        finally
        {
            // Reset loading in-progress flag in case failed for some reason
            mLoadingState.set(old);
        }
        
        mLoadingState.set(LoadingState.LOADED);
        
        // Notify manager
        if(mCreator)
            mCreator._notifyResourceLoaded(this);
        
        // No deferred loading events since this method is not called in background
        
        
    }
    
    /** Loads the data from a raw stream.
     @note Important: only call this from outside the load() routine of a 
     Resource. Don't call it within (including ManualResourceLoader) - use
     _loadImages() instead. This method is designed to be external, 
     performs locking and checks the load status before loading.
     @param stream Data stream containing the raw pixel data
     @param uWidth Width of the image
     @param uHeight Height of the image
     @param eFormat The format of the pixel data
     */
    void loadRawData( ref DataStream stream, 
                     ushort uWidth, ushort uHeight, PixelFormat eFormat)
    {
        Image img;
        img.loadRawData(stream, uWidth, uHeight, eFormat);
        loadImage(img);
    }
    
    /** Internal method to load the texture from a set of images. 
     @note Do NOT call this method unless you are inside the load() routine
     already, e.g. a ManualResourceLoader. It is not threadsafe and does
     not check or update resource loading status.
     */
    //void _loadImages( ref ConstImagePtrList images )
    void _loadImages( ref ImagePtrList images )
    {
        if(images.length < 1)
            throw new InvalidParamsError("Cannot load empty vector of images",
                                         "Texture.loadImages");
        
        // Set desired texture size and properties from images[0]
        mSrcWidth = mWidth = images[0].getWidth();
        mSrcHeight = mHeight = images[0].getHeight();
        mSrcDepth = mDepth = images[0].getDepth();
        
        // Get source image format and adjust if required
        mSrcFormat = images[0].getFormat();
        if (mTreatLuminanceAsAlpha && mSrcFormat == PixelFormat.PF_L8)
        {
            mSrcFormat = PixelFormat.PF_A8;
        }
        
        if (mDesiredFormat != PixelFormat.PF_UNKNOWN)
        {
            // If have desired format, use it
            mFormat = mDesiredFormat;
        }
        else
        {
            // Get the format according with desired bit depth
            mFormat = PixelUtil.getFormatForBitDepths(mSrcFormat, mDesiredIntegerBitDepth, mDesiredFloatBitDepth);
        }
        
        // The custom mipmaps in the image have priority over everything
        size_t imageMips = images[0].getNumMipmaps();
        
        if(imageMips > 0)
        {
            mNumMipmaps = mNumRequestedMipmaps = images[0].getNumMipmaps();
            // Disable flag for auto mip generation
            mUsage &= ~TextureUsage.TU_AUTOMIPMAP;
        }
        
        // Create the texture
        createInternalResources();
        // Check if we're loading one image with multiple faces
        // or a vector of images representing the faces
        size_t faces;
        bool multiImage; // Load from multiple images?
        if(images.length > 1)
        {
            faces = images.length;
            multiImage = true;
        }
        else
        {
            faces = images[0].getNumFaces();
            multiImage = false;
        }
        
        // Check whether number of faces in images exceeds number of faces
        // in this texture. If so, clamp it.
        if(faces > getNumFaces())
            faces = getNumFaces();
        
        if (TextureManager.getSingleton().getVerbose()) {
            // Say what we're doing
            string str = std.conv.text("Texture: ", mName, ": Loading ", faces, " faces"
                                       , "(", PixelUtil.getFormatName(images[0].getFormat()), ",",
                                       images[0].getWidth(), "x", images[0].getHeight(), "x", images[0].getDepth(),
                                       ")");
            if (!(mMipmapsHardwareGenerated && mNumMipmaps == 0))
            {
                str ~= " with " ~ std.conv.to!string(mNumMipmaps);
                if(mUsage & TextureUsage.TU_AUTOMIPMAP)
                {
                    if (mMipmapsHardwareGenerated)
                        str ~= " hardware";
                    
                    str ~= " generated mipmaps";
                }
                else
                {
                    str ~= " custom mipmaps";
                }
                if(multiImage)
                    str ~= " from multiple Images.";
                else
                    str ~= " from Image.";
            }
            
            // Scoped
            {
                // Print data about first destination surface
                SharedPtr!HardwarePixelBuffer buf = getBuffer(0, 0); 
                str ~= std.conv.text(" Internal format is ", PixelUtil.getFormatName(buf.get().getFormat()), 
                                     ",", buf.get().getWidth(), "x", buf.get().getHeight(), "x", buf.get().getDepth(), ".");
            }
            LogManager.getSingleton().logMessage(LML_NORMAL, str);
        }
        
        // Main loading loop
        // imageMips == 0 if the image has no custom mipmaps, otherwise contains the number of custom mips
        for(size_t mip = 0; mip <= std.algorithm.min(mNumMipmaps, imageMips); ++mip)
        {
            for(size_t i = 0; i < faces; ++i)
            {
                PixelBox src;
                if(multiImage)
                {
                    // Load from multiple images
                    src = images[i].getPixelBox(0, mip);
                }
                else
                {
                    // Load from faces of images[0]
                    src = images[0].getPixelBox(i, mip);
                }
                
                // Sets to treated format in case is difference
                src.format = mSrcFormat;
                
                if(mGamma != 1.0f) {
                    // Apply gamma correction
                    // Do not overwrite original image but do gamma correction in temporary buffer
                    MemoryDataStream buf; // for scoped deletion of conversion buffer
                    buf = new MemoryDataStream(
                        PixelUtil.getMemorySize(
                        src.getWidth(), src.getHeight(), src.getDepth(), src.format));
                    
                    scope(exit) destroy(buf);//TODO Ok, so lets force GC?
                    
                    PixelBox corrected = new PixelBox(src.getWidth(), src.getHeight(), src.getDepth(), src.format, buf.getPtr());
                    PixelUtil.bulkPixelConversion(src, corrected);
                    
                    Image.applyGamma(cast(ubyte*)(corrected.data), mGamma, corrected.getConsecutiveSize(), 
                                     cast(ubyte)(PixelUtil.getNumElemBits(src.format)));
                    
                    // Destination: entire texture. blitFromMemory does the scaling to
                    // a power of two for us when needed
                    getBuffer(i, mip).get().blitFromMemory(corrected);
                }
                else 
                {
                    // Destination: entire texture. blitFromMemory does the scaling to
                    // a power of two for us when needed
                    getBuffer(i, mip).get().blitFromMemory(src);
                }
                
            }
        }
        // Update size (the final size, not including temp space)
        mSize = getNumFaces() * PixelUtil.getMemorySize(mWidth, mHeight, mDepth, mFormat);
        
    }
    
    /** Returns the pixel format for the texture surface. */
    PixelFormat getFormat()
    {
        return mFormat;
    }
    
    /** Returns the desired pixel format for the texture surface. */
    PixelFormat getDesiredFormat()
    {
        return mDesiredFormat;
    }
    
    /** Returns the pixel format of the original input texture (may differ due to
     hardware requirements and pixel format conversion).
     */
    PixelFormat getSrcFormat()
    {
        return mSrcFormat;
    }
    
    /** Sets the pixel format for the texture surface; can only be set before load(). */
    void setFormat(PixelFormat pf)
    {
        mFormat = pf;
        mDesiredFormat = pf;
        mSrcFormat = pf;
    }
    
    /** Returns true if the texture has an alpha layer. */
    bool hasAlpha()
    {
        return PixelUtil.hasAlpha(mFormat);
    }
    
    /** Sets desired bit depth for integer pixel format textures.
     @note
     Available values: 0, 16 and 32, where 0 (the default) means keep original format
     as it is. This value is number of bits for the pixel.
     */
    void setDesiredIntegerBitDepth(ushort bits)
    {
        mDesiredIntegerBitDepth = bits;
    }
    
    /** gets desired bit depth for integer pixel format textures.
     */
    ushort getDesiredIntegerBitDepth()
    {
        return mDesiredIntegerBitDepth;
    }
    
    /** Sets desired bit depth for float pixel format textures.
     @note
     Available values: 0, 16 and 32, where 0 (the default) means keep original format
     as it is. This value is number of bits for a channel of the pixel.
     */
    void setDesiredFloatBitDepth(ushort bits)
    {
        mDesiredFloatBitDepth = bits;
    }
    
    /** gets desired bit depth for float pixel format textures.
     */
    ushort getDesiredFloatBitDepth()
    {
        return mDesiredFloatBitDepth;
    }
    
    /** Sets desired bit depth for integer and float pixel format.
     */
    void setDesiredBitDepths(ushort integerBits, ushort floatBits)
    {
        mDesiredIntegerBitDepth = integerBits;
        mDesiredFloatBitDepth = floatBits;
    }
    
    /** Sets whether luminace pixel format will treated as alpha format when load this texture.
     */
    void setTreatLuminanceAsAlpha(bool asAlpha)
    {
        mTreatLuminanceAsAlpha = asAlpha;
    }
    
    /** Gets whether luminace pixel format will treated as alpha format when load this texture.
     */
    bool getTreatLuminanceAsAlpha()
    {
        return mTreatLuminanceAsAlpha;
    }
    
    /** Return the number of faces this texture has. This will be 6 for a cubemap
     texture and 1 for a 1D, 2D or 3D one.
     */
    size_t getNumFaces()
    {
        return getTextureType() == TextureType.TEX_TYPE_CUBE_MAP ? 6 : 1;
    }
    
    /** Return hardware pixel buffer for a surface. This buffer can then
     be used to copy data from and to a particular level of the texture.
     @param face     Face number, in case of a cubemap texture. Must be 0
     for other types of textures.
     For cubemaps, this is one of 
     +X (0), -X (1), +Y (2), -Y (3), +Z (4), -Z (5)
     @param mipmap   Mipmap level. This goes from 0 for the first, largest
     mipmap level to getNumMipmaps()-1 for the smallest.
     @return A shared pointer to a hardware pixel buffer
     @remarks    The buffer is invalidated when the resource is unloaded or destroyed.
     Do not use it after the lifetime of the containing texture.
     */
    abstract SharedPtr!HardwarePixelBuffer getBuffer(size_t face=0, size_t mipmap=0);
    
    
    /** Populate an Image with the contents of this texture. 
     @param destImage The target image (contents will be overwritten)
     @param includeMipMaps Whether to embed mipmaps in the image
     */
    void convertToImage(ref Image destImage, bool includeMipMaps = false)
    {
        
        size_t numMips = includeMipMaps? getNumMipmaps() + 1 : 1;
        size_t dataSize = Image.calculateSize(numMips,
                                              getNumFaces(), getWidth(), getHeight(), getDepth(), getFormat());
        
        //void* pixData = OGRE_MALLOC(dataSize, Ogre.MEMCATEGORY_GENERAL);
        ubyte[] pixData = new ubyte[dataSize]; //FIXME Uh , scoping of ubyte array. But destImage should be copying it so nevermind?
        //void* pixData = cast(void*)_pixdata.ptr;
        
        // if there are multiple faces and mipmaps we must pack them into the data
        // faces, then mips
        void* currentPixData = cast(void*)pixData.ptr;
        for (size_t face = 0; face < getNumFaces(); ++face)
        {
            for (size_t mip = 0; mip < numMips; ++mip)
            {
                size_t mipDataSize = PixelUtil.getMemorySize(getWidth(), getHeight(), getDepth(), getFormat());
                
                auto pixBox = new PixelBox(getWidth(), getHeight(), getDepth(), getFormat(), currentPixData);
                getBuffer(face, mip).get().blitToMemory(pixBox);
                
                currentPixData = cast(void*)(cast(ubyte*)currentPixData + mipDataSize);
                
            }
        }
        
        
        // load, and tell Image to delete the memory when it's done.
        destImage.loadDynamicImage(pixData, getWidth(), getHeight(), getDepth(), getFormat(), true, 
                                   getNumFaces(), numMips - 1);
        
    }
    
    /** Retrieve a platform or API-specific piece of information from this texture.
     This method of retrieving information should only be used if you know what you're doing.
     @param name The name of the attribute to retrieve
     @param pData Pointer to memory matching the type of data you want to retrieve.
     */
    void getCustomAttribute(string name, void* pData) {}
    
    
    
protected:
    size_t mHeight;
    size_t mWidth;
    size_t mDepth;
    
    size_t mNumRequestedMipmaps;
    size_t mNumMipmaps;
    bool mMipmapsHardwareGenerated;
    float mGamma;
    bool mHwGamma;
    uint mFSAA;
    string mFSAAHint;
    
    TextureType mTextureType;
    PixelFormat mFormat;
    int mUsage; // Bit field, so this can't be TextureUsage
    
    PixelFormat mSrcFormat;
    size_t mSrcWidth, mSrcHeight, mSrcDepth;
    
    PixelFormat mDesiredFormat;
    ushort mDesiredIntegerBitDepth;
    ushort mDesiredFloatBitDepth;
    bool mTreatLuminanceAsAlpha;
    
    bool mInternalResourcesCreated;
    
    /// @copydoc Resource.calculateSize
    override size_t calculateSize()
    {
        return getNumFaces() * PixelUtil.getMemorySize(mWidth, mHeight, mDepth, mFormat);
    }
    
    
    /** Implementation of creating internal texture resources 
     */
    abstract void createInternalResourcesImpl();
    
    /** Implementation of freeing internal texture resources 
     */
    abstract void freeInternalResourcesImpl();
    
    /** Default implementation of unload which calls freeInternalResources */
    override void unloadImpl()
    {
        freeInternalResources();
    }
    
    /** Identify the source file type as a string, either from the extension
     or from a magic number.
     */
    string getSourceFileType()
    {
        if (mName is null)
            return "";
        
        ptrdiff_t pos = mName.lastIndexOf(".");
        if (pos != -1 && pos < (mName.length - 1))
        {
            string ext = mName[pos+1 .. $];
            return ext.toLower();
        }
        else
        {
            // No extension
            DataStream dstream;
            try
            {
                dstream = ResourceGroupManager.getSingleton().openResource(
                    mName, mGroup, true, null);
            }
            catch 
            {
            }
            if (dstream !is null && getTextureType() == TextureType.TEX_TYPE_CUBE_MAP)
            {
                // try again with one of the faces (non-dds)
                try
                {
                    dstream = ResourceGroupManager.getSingleton().openResource(
                        mName ~ "_rt", mGroup, true, null);
                }
                catch 
                {
                }
            }
            
            if (dstream !is null)
            {
                return Image.getFileExtFromMagic(dstream);
            }
        }
        
        return "";
        
    }
    
}

/** Specialisation of SharedPtr to allow SharedPtr to be assigned to SharedPtr!Texture 
 @note Has to be a subclass since we need operator=.
 We could templatise this instead of repeating per Resource subclass, 
 except to do so requires a form VC6 does not support i.e.
 ResourceSubclassPtr<T> : public SharedPtr<T>
 */
//alias SharedPtr!Texture TexturePtr;
//alias Texture SharedPtr!Texture;


/** @} */
/** @} */
