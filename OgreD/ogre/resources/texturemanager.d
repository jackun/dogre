module ogre.resources.texturemanager;
import ogre.singleton;
import ogre.resources.resource;
import ogre.resources.datastream;
import ogre.resources.resourcemanager;
import ogre.resources.texture;
import ogre.image.images;
import ogre.image.pixelformat;
import ogre.compat;
import ogre.general.common;
import ogre.general.root;
import ogre.sharedptr;
import ogre.rendersystem.rendersystem;

/** Class for loading & managing textures.
        @remarks
            Note that this class is abstract - the particular
            RenderSystem that is in use at the time will create
            a concrete subclass of this. Note that the concrete
            class will be available via the abstract singleton
            obtained from TextureManager::getSingleton(), but
            you should not assume that it is available until you
            have a) initialised Ogre (after selecting a RenderSystem
            and calling initialise from the Root object), and b)
            created at least one window - this may be done at the
            same time as part a if you allow Ogre to autocreate one.
     */
class TextureManager : ResourceManager
{
    mixin Singleton!TextureManager;

public:

    /// Use getSingleton() instead.
    this()
    {
        mPreferredIntegerBitDepth = 0;
        mPreferredFloatBitDepth = 0;
        mDefaultNumMipmaps = TextureMipmap.MIP_UNLIMITED;
        mResourceType = "Texture";
        mLoadOrder = 75.0f;
        
        // Subclasses should register (when this is fullyructed)
    }

    ~this()
    {
        // subclasses should unregister with resource group manager

    }

    alias ResourceManager.createOrRetrieve createOrRetrieve;

    /** Create a new texture, or retrieve an existing one with the same
            name if it already exists.
            @param
                texType The type of texture to load/create, defaults to normal 2D textures
            @param
                numMipmaps The number of pre-filtered mipmaps to generate. If left to TextureMipmap.MIP_DEFAULT then
                the TextureManager's default number of mipmaps will be used (see setDefaultNumMipmaps())
                If set to MIP_UNLIMITED mipmaps will be generated until the lowest possible
                level, 1x1x1.
            @param
                gamma The gamma adjustment factor to apply to this texture (brightening/darkening)
            @param 
                isAlpha Only applicable to greyscale images. If true, specifies that
                the image should be loaded into an alpha texture rather than a
                single channel colour texture - useful for fixed-function systems.
            @param 
                desiredFormat The format you would like to have used instead of
                the format being based on the contents of the texture
            @param hwGammaCorrection Pass 'true' to enable hardware gamma correction
                (sRGB) on this texture. The hardware will convert from gamma space
                to linear space when reading from this texture. Only applicable for 
                8-bits per channel textures, will be ignored for other types. Has the advantage
                over pre-applied gamma that the texture precision is maintained.
            @see ResourceManager::createOrRetrieve
        */
    ResourceCreateOrRetrieveResult createOrRetrieve(
       string name,string group, bool isManual = false,
        ManualResourceLoader loader = null,NameValuePairList createParams = null,
        TextureType texType = TextureType.TEX_TYPE_2D, int numMipmaps = TextureMipmap.MIP_DEFAULT, 
        Real gamma = 1.0f, bool isAlpha = false,
        PixelFormat desiredFormat = PixelFormat.PF_UNKNOWN, bool hwGammaCorrection = false)
    {
        ResourceCreateOrRetrieveResult res = super.createOrRetrieve(name, group, isManual, loader, createParams);
        // Was it created?
        if(res.second)
        {
            SharedPtr!Texture tex = res.first;
            tex.getAs().setTextureType(texType);
            tex.getAs().setNumMipmaps((numMipmaps == TextureMipmap.MIP_DEFAULT)? mDefaultNumMipmaps :
                               cast(size_t)numMipmaps);
            tex.getAs().setGamma(gamma);
            tex.getAs().setTreatLuminanceAsAlpha(isAlpha);
            tex.getAs().setFormat(desiredFormat);
            tex.getAs().setHardwareGammaEnabled(hwGammaCorrection);
        }
        return res;
    }
    
    /** Prepares to loads a texture from a file.
            @param
                name The file to load, or a String identifier in some cases
            @param
                group The name of the resource group to assign the texture to
            @param
                texType The type of texture to load/create, defaults to normal 2D textures
            @param
                numMipmaps The number of pre-filtered mipmaps to generate. If left to TextureMipmap.MIP_DEFAULT then
                the TextureManager's default number of mipmaps will be used (see setDefaultNumMipmaps())
                If set to MIP_UNLIMITED mipmaps will be generated until the lowest possible
                level, 1x1x1.
            @param
                gamma The gamma adjustment factor to apply to this texture (brightening/darkening)
            @param 
                isAlpha Only applicable to greyscale images. If true, specifies that
                the image should be loaded into an alpha texture rather than a
                single channel colour texture - useful for fixed-function systems.
            @param 
                desiredFormat The format you would like to have used instead of
                the format being based on the contents of the texture
            @param hwGammaCorrection Pass 'true' to enable hardware gamma correction
                (sRGB) on this texture. The hardware will convert from gamma space
                to linear space when reading from this texture. Only applicable for 
                8-bits per channel textures, will be ignored for other types. Has the advantage
                over pre-applied gamma that the texture precision is maintained.
        */
    SharedPtr!Texture prepare(string name,string group, 
                       TextureType texType = TextureType.TEX_TYPE_2D, int numMipmaps = TextureMipmap.MIP_DEFAULT, 
                       Real gamma = 2.0f, bool isAlpha = false,
                       PixelFormat desiredFormat = PixelFormat.PF_UNKNOWN, bool hwGammaCorrection = false)
    {
        ResourceCreateOrRetrieveResult res =
            createOrRetrieve(name,group,false,null,null,texType,numMipmaps,gamma,isAlpha,desiredFormat,hwGammaCorrection);
        SharedPtr!Texture tex = res.first;
        tex.getAs().prepare();
        return tex;
    }
    
    /** Loads a texture from a file.
            @param
                name The file to load, or a String identifier in some cases
            @param
                group The name of the resource group to assign the texture to
            @param
                texType The type of texture to load/create, defaults to normal 2D textures
            @param
                numMipmaps The number of pre-filtered mipmaps to generate. If left to TextureMipmap.MIP_DEFAULT then
                the TextureManager's default number of mipmaps will be used (see setDefaultNumMipmaps())
                If set to MIP_UNLIMITED mipmaps will be generated until the lowest possible
                level, 1x1x1.
            @param
                gamma The gamma adjustment factor to apply to this texture (brightening/darkening)
                    during loading
            @param 
                isAlpha Only applicable to greyscale images. If true, specifies that
                the image should be loaded into an alpha texture rather than a
                single channel colour texture - useful for fixed-function systems.
            @param 
                desiredFormat The format you would like to have used instead of
                the format being based on the contents of the texture. Pass PF_UNKNOWN
                to default.
            @param hwGammaCorrection Pass 'true' to enable hardware gamma correction
                (sRGB) on this texture. The hardware will convert from gamma space
                to linear space when reading from this texture. Only applicable for 
                8-bits per channel textures, will be ignored for other types. Has the advantage
                over pre-applied gamma that the texture precision is maintained.
        */
    SharedPtr!Texture load( 
                   string name,string group, 
                    TextureType texType = TextureType.TEX_TYPE_2D, int numMipmaps = TextureMipmap.MIP_DEFAULT, 
                    Real gamma = 1.0f, bool isAlpha = false,
                    PixelFormat desiredFormat = PixelFormat.PF_UNKNOWN, 
                    bool hwGammaCorrection = false)
    {
        ResourceCreateOrRetrieveResult res =
            createOrRetrieve(name,group,false,null,null,texType,numMipmaps,gamma,isAlpha,desiredFormat,hwGammaCorrection);
        SharedPtr!Texture tex = res.first;
        tex.getAs().load();
        return tex;
    }
    
    /** Loads a texture from an Image object.
            @note
                The texture will create as manual texture without loader.
            @param
                name The name to give the resulting texture
            @param
                group The name of the resource group to assign the texture to
            @param
                img The Image object which contains the data to load
            @param
                texType The type of texture to load/create, defaults to normal 2D textures
            @param
                numMipmaps The number of pre-filtered mipmaps to generate. If left to TextureMipmap.MIP_DEFAULT then
                the TextureManager's default number of mipmaps will be used (see setDefaultNumMipmaps())
                If set to MIP_UNLIMITED mipmaps will be generated until the lowest possible
                level, 1x1x1.
            @param
                gamma The gamma adjustment factor to apply to this texture (brightening/darkening)
            @param 
                isAlpha Only applicable to greyscale images. If true, specifies that
                the image should be loaded into an alpha texture rather than a
                single channel colour texture - useful for fixed-function systems.
            @param 
                desiredFormat The format you would like to have used instead of
                the format being based on the contents of the texture
            @param hwGammaCorrection Pass 'true' to enable hardware gamma correction
                (sRGB) on this texture. The hardware will convert from gamma space
                to linear space when reading from this texture. Only applicable for 
                8-bits per channel textures, will be ignored for other types. Has the advantage
                over pre-applied gamma that the texture precision is maintained.
        */
    SharedPtr!Texture loadImage( 
                        string name,string group, ref Image img, 
                         TextureType texType = TextureType.TEX_TYPE_2D,
                         int numMipmaps = TextureMipmap.MIP_DEFAULT, Real gamma = 1.0f, bool isAlpha = false,
                         PixelFormat desiredFormat = PixelFormat.PF_UNKNOWN, bool hwGammaCorrection = false)
    {
        SharedPtr!Texture tex = create(name, group, true);
        
        tex.getAs().setTextureType(texType);
        tex.getAs().setNumMipmaps((numMipmaps == TextureMipmap.MIP_DEFAULT)? mDefaultNumMipmaps :
                           cast(size_t)(numMipmaps));
        tex.getAs().setGamma(gamma);
        tex.getAs().setTreatLuminanceAsAlpha(isAlpha);
        tex.getAs().setFormat(desiredFormat);
        tex.getAs().setHardwareGammaEnabled(hwGammaCorrection);
        tex.getAs().loadImage(img);
        
        return tex;
    }
    
    /** Loads a texture from a raw data stream.
            @note
                The texture will create as manual texture without loader.
            @param name
                The name to give the resulting texture
            @param group
                The name of the resource group to assign the texture to
            @param stream
                Incoming data stream
            @param width, height
                The dimensions of the texture
            @param format
                The format of the data being passed in; the manager reserves
                the right to create a different format for the texture if the 
                original format is not available in this context.
            @param texType
                The type of texture to load/create, defaults to normal 2D textures
            @param numMipmaps
                The number of pre-filtered mipmaps to generate. If left to TextureMipmap.MIP_DEFAULT then
                the TextureManager's default number of mipmaps will be used (see setDefaultNumMipmaps())
                If set to MIP_UNLIMITED mipmaps will be generated until the lowest possible
                level, 1x1x1.
            @param gamma
                The gamma adjustment factor to apply to this texture (brightening/darkening)
                while loading
            @param hwGammaCorrection Pass 'true' to enable hardware gamma correction
                 (sRGB) on this texture. The hardware will convert from gamma space
                 to linear space when reading from this texture. Only applicable for 
                 8-bits per channel textures, will be ignored for other types. Has the advantage
                 over pre-applied gamma that the texture precision is maintained.

        */
    SharedPtr!Texture loadRawData(string name,string group,
                           ref DataStream stream, ushort width, ushort height, 
                           PixelFormat format, TextureType texType = TextureType.TEX_TYPE_2D, 
                           int numMipmaps = TextureMipmap.MIP_DEFAULT, Real gamma = 1.0f, bool hwGammaCorrection = false)
    {
        SharedPtr!Texture tex = create(name, group, true);
        
        tex.getAs().setTextureType(texType);
        tex.getAs().setNumMipmaps((numMipmaps == TextureMipmap.MIP_DEFAULT)? mDefaultNumMipmaps :
                           cast(size_t)numMipmaps);
        tex.getAs().setGamma(gamma);
        tex.getAs().setHardwareGammaEnabled(hwGammaCorrection);
        tex.getAs().loadRawData(stream, width, height, format);
        
        return tex;
    }
    
    /** Create a manual texture with specified width, height and depth (not loaded from a file).
            @param
                name The name to give the resulting texture
            @param
                group The name of the resource group to assign the texture to
            @param
                texType The type of texture to load/create, defaults to normal 2D textures
            @param
                width, height, depth The dimensions of the texture
            @param
                numMipmaps The number of pre-filtered mipmaps to generate. If left to TextureMipmap.MIP_DEFAULT then
                the TextureManager's default number of mipmaps will be used (see setDefaultNumMipmaps())
                If set to MIP_UNLIMITED mipmaps will be generated until the lowest possible
                level, 1x1x1.
            @param
                format The internal format you wish to request; the manager reserves
                the right to create a different format if the one you select is
                not available in this context.
            @param 
                usage The kind of usage this texture is intended for. It 
                is a combination of TU_STATIC, TU_DYNAMIC, TU_WRITE_ONLY, 
                TU_AUTOMIPMAP and TU_RENDERTARGET (see TextureUsage enum). You are
                strongly advised to use HBU_STATIC_WRITE_ONLY wherever possible, if you need to 
                update regularly, consider HBU_DYNAMIC_WRITE_ONLY.
            @param
                loader If you intend the contents of the manual texture to be 
                regularly updated, to the extent that you don't need to recover 
                the contents if the texture content is lost somehow, you can leave
                this parameter as 0. However, if you intend to populate the
                texture only once, then you should implement ManualResourceLoader
                and pass a pointer to it in this parameter; this means that if the
                manual texture ever needs to be reloaded, the ManualResourceLoader
                will be called to do it.
            @param hwGammaCorrection Pass 'true' to enable hardware gamma correction
                (sRGB) on this texture. The hardware will convert from gamma space
                to linear space when reading from this texture. Only applicable for 
                8-bits per channel textures, will be ignored for other types. Has the advantage
                over pre-applied gamma that the texture precision is maintained.
            @param fsaa The level of multisampling to use if this is a render target. Ignored
                if usage does not include TU_RENDERTARGET or if the device does
                not support it.
        */
    SharedPtr!Texture createManual(string  name,string group,
                                    TextureType texType, uint width, uint height, uint depth, 
                                    int numMipmaps, PixelFormat format, int usage = TextureUsage.TU_DEFAULT, ManualResourceLoader loader = null,
                                    bool hwGammaCorrection = false, uint fsaa = 0,string fsaaHint = null)
    {
    
        TexturePtr ret;
        ret.setNull();
        
        // Check for 3D texture support
        RenderSystemCapabilities caps = Root.getSingleton().getRenderSystem().getCapabilities();
        if (((texType == TextureType.TEX_TYPE_3D) || (texType == TextureType.TEX_TYPE_2D_ARRAY)) &&
            !caps.hasCapability(Capabilities.RSC_TEXTURE_3D))
            return ret;
        
        if (((usage & cast(int)TextureUsage.TU_STATIC) != 0) && (!Root.getSingleton().getRenderSystem().isStaticBufferLockable()))
        {
            usage = (usage & ~cast(int)TextureUsage.TU_STATIC) | cast(int)TextureUsage.TU_DYNAMIC;
        }
        ret = create(name, group, true, loader);
        ret.getAs().setTextureType(texType);
        ret.getAs().setWidth(width);
        ret.getAs().setHeight(height);
        ret.getAs().setDepth(depth);
        ret.getAs().setNumMipmaps((numMipmaps == TextureMipmap.MIP_DEFAULT)? mDefaultNumMipmaps :
                           cast(size_t)numMipmaps);
        ret.getAs().setFormat(format);
        ret.getAs().setUsage(usage);
        ret.getAs().setHardwareGammaEnabled(hwGammaCorrection);
        ret.getAs().setFSAA(fsaa, fsaaHint);
        ret.getAs().createInternalResources();
        return ret;
    }
    
    /** Create a manual texture with a depth of 1 (not loaded from a file).
            @param
                name The name to give the resulting texture
            @param
                group The name of the resource group to assign the texture to
            @param
                texType The type of texture to load/create, defaults to normal 2D textures
            @param
                width, height The dimensions of the texture
            @param
                numMipmaps The number of pre-filtered mipmaps to generate. If left to TextureMipmap.MIP_DEFAULT then
                the TextureManager's default number of mipmaps will be used (see setDefaultNumMipmaps()).
                If set to MIP_UNLIMITED mipmaps will be generated until the lowest possible
                level, 1x1x1.
            @param
                format The internal format you wish to request; the manager reserves
                the right to create a different format if the one you select is
                not available in this context.
            @param 
                usage The kind of usage this texture is intended for. It 
                is a combination of TU_STATIC, TU_DYNAMIC, TU_WRITE_ONLY, 
                TU_AUTOMIPMAP and TU_RENDERTARGET (see TextureUsage enum). You are
                strongly advised to use HBU_STATIC_WRITE_ONLY wherever possible, if you need to 
                update regularly, consider HBU_DYNAMIC_WRITE_ONLY.
            @param
                loader If you intend the contents of the manual texture to be 
                regularly updated, to the extent that you don't need to recover 
                the contents if the texture content is lost somehow, you can leave
                this parameter as 0. However, if you intend to populate the
                texture only once, then you should implement ManualResourceLoader
                and pass a pointer to it in this parameter; this means that if the
                manual texture ever needs to be reloaded, the ManualResourceLoader
                will be called to do it.
             @param hwGammaCorrection Pass 'true' to enable hardware gamma correction
                 (sRGB) on this texture. The hardware will convert from gamma space
                 to linear space when reading from this texture. Only applicable for 
                 8-bits per channel textures, will be ignored for other types. Has the advantage
                 over pre-applied gamma that the texture precision is maintained.
            @param fsaa The level of multisampling to use if this is a render target. Ignored
                if usage does not include TU_RENDERTARGET or if the device does
                not support it.
        */
    SharedPtr!Texture createManual(string  name,string group,
                            TextureType texType, uint width, uint height, int numMipmaps,
                            PixelFormat format, int usage = TextureUsage.TU_DEFAULT, ManualResourceLoader loader = null,
                            bool hwGammaCorrection = false, uint fsaa = 0,string fsaaHint = null)
    {
        return createManual(name, group, texType, width, height, 1, 
                            numMipmaps, format, usage, loader, hwGammaCorrection, fsaa, fsaaHint);
    }
    
    /** Sets preferred bit depth for integer pixel format textures.
        @param
            bits Number of bits. Available values: 0, 16 and 32, where 0 (the default) means keep
            original format as it is. This value is number of bits for the pixel.
        @param
            reloadTextures If true (the default), will reloading all reloadable textures.
        */
    void setPreferredIntegerBitDepth(ushort bits, bool reloadTextures = true)
    {
        mPreferredIntegerBitDepth = bits;
        
        if (reloadTextures)
        {
            // Iterate through all textures
            foreach (k,v; mResources)
            {
                Texture texture = cast(Texture)v.get();
                // Reload loaded and reloadable texture only
                if (texture.isLoaded() && texture.isReloadable())
                {
                    texture.unload();
                    texture.setDesiredIntegerBitDepth(bits);
                    texture.load();
                }
                else
                {
                    texture.setDesiredIntegerBitDepth(bits);
                }
            }
        }
    }
    
    /** Gets preferred bit depth for integer pixel format textures.
        */
    ushort getPreferredIntegerBitDepth()
    {
        return mPreferredIntegerBitDepth;
    }
    
    /** Sets preferred bit depth for float pixel format textures.
        @param
            bits Number of bits. Available values: 0, 16 and 32, where 0 (the default) means keep
            original format as it is. This value is number of bits for a channel of the pixel.
        @param
            reloadTextures If true (the default), will reloading all reloadable textures.
        */
    void setPreferredFloatBitDepth(ushort bits, bool reloadTextures = true)
    {
        mPreferredFloatBitDepth = bits;
        
        if (reloadTextures)
        {
            // Iterate through all textures
            foreach (k,v; mResources)
            {
                Texture texture = cast(Texture)v.get();
                // Reload loaded and reloadable texture only
                if (texture.isLoaded() && texture.isReloadable())
                {
                    texture.unload();
                    texture.setDesiredFloatBitDepth(bits);
                    texture.load();
                }
                else
                {
                    texture.setDesiredFloatBitDepth(bits);
                }
            }
        }
    }
    
    /** Gets preferred bit depth for float pixel format textures.
        */
    ushort getPreferredFloatBitDepth()
    {
        return mPreferredFloatBitDepth;
    }
    
    /** Sets preferred bit depth for integer and float pixel format.
        @param
            integerBits Number of bits. Available values: 0, 16 and 32, where 0 (the default) means keep
            original format as it is. This value is number of bits for the pixel.
        @param
            floatBits Number of bits. Available values: 0, 16 and 32, where 0 (the default) means keep
            original format as it is. This value is number of bits for a channel of the pixel.
        @param
            reloadTextures If true (the default), will reloading all reloadable textures.
        */
    void setPreferredBitDepths(ushort integerBits, ushort floatBits, bool reloadTextures = true)
    {
        mPreferredIntegerBitDepth = integerBits;
        mPreferredFloatBitDepth = floatBits;
        
        if (reloadTextures)
        {
            // Iterate through all textures
            foreach (k,v; mResources)
            {
                Texture texture = cast(Texture)v.get();
                // Reload loaded and reloadable texture only
                if (texture.isLoaded() && texture.isReloadable())
                {
                    texture.unload();
                    texture.setDesiredBitDepths(integerBits, floatBits);
                    texture.load();
                }
                else
                {
                    texture.setDesiredBitDepths(integerBits, floatBits);
                }
            }
        }
    }
    
    /** Returns whether this render system can natively support the precise texture 
            format requested with the given usage options.
        @remarks
            You can still create textures with this format even if this method returns
            false; the texture format will just be altered to one which the device does
            support.
        @note
            Sometimes the device may just slightly change the format, such as reordering the 
            channels or packing the channels differently, without it making and qualitative 
            differences to the texture. If you want to just detect whether the quality of a
            given texture will be reduced, use isEquivalentFormatSupport instead.
        @param format The pixel format requested
        @param usage The kind of usage this texture is intended for, a combination of 
            the TextureUsage flags.
        @return true if the format is natively supported, false if a fallback would be used.
        */
    bool isFormatSupported(TextureType ttype, PixelFormat format, int usage)
    {
        return getNativeFormat(ttype, format, usage) == format;
    }
    
    /** Returns whether this render system can support the texture format requested
            with the given usage options, or another format with no quality reduction.
        */
    bool isEquivalentFormatSupported(TextureType ttype, PixelFormat format, int usage)
    {
        PixelFormat supportedFormat = getNativeFormat(ttype, format, usage);
        
        // Assume that same or greater number of bits means quality not degraded
        return PixelUtil.getNumElemBits(supportedFormat) >= PixelUtil.getNumElemBits(format);
    }
    
    /** Gets the format which will be natively used for a requested format given the
           raints of the current device.
        */
    //TODO Implemented in RenderSystems. Singleton doesn't like abstracts.
    //abstract 
    PixelFormat getNativeFormat(TextureType ttype, PixelFormat format, int usage)
    {
        assert(0, "TextureManager.getNativeFormat is abstract.");
    }
    
    /** Returns whether this render system has hardware filtering supported for the
            texture format requested with the given usage options.
        @remarks
            Not all texture format are supports filtering by the hardware, i.e. some
            cards support floating point format, but it doesn't supports filtering on
            the floating point texture at all, or only a subset floating point formats
            have flitering supported.
        @par
            In the case you want to write shader to work with floating point texture, and
            you want to produce better visual quality, it's necessary to flitering the
            texture manually in shader (potential requires four or more texture fetch
            instructions, plus several arithmetic instructions) if filtering doesn't
            supported by hardware. But in case on the hardware that supports floating
            point filtering natively, it had better to adopt this capability for
            performance (because only one texture fetch inst.keys) are required) and
            doesn't loss visual quality.
        @par
            This method allow you queries hardware texture filtering capability to deciding
            which verion of the shader to be used. Note it's up to you to write multi-version
            shaders for support various hardware, internal engine can't do that for you
            automatically.
        @note
            Under GL, texture filtering are always supported by driver, but if it's not
            supported by hardware natively, software simulation will be used, and you
            will end up with very slow speed (less than 0.1 fps for example). To slove
            this performance problem, you must disable filtering manually (by use
            <b>filtering none</b> in the material script's texture_unit section, or
            call TextureUnitState::setTextureFiltering with TFO_NONE if populate
            material in code).
        @param ttype The texture type requested
        @param format The pixel format requested
        @param usage The kind of usage this texture is intended for, a combination of 
            the TextureUsage flags.
        @param preciseFormatOnly Whether precise or fallback format mode is used to detecting.
            In case the pixel format doesn't supported by device, false will be returned
            if in precise mode, and natively used pixel format will be actually use to
            check if in fallback mode.
        @return true if the texture filtering is supported.
        */
    //abstract 
    bool isHardwareFilteringSupported(TextureType ttype, PixelFormat format, int usage,
                                              bool preciseFormatOnly = false)
    {
        assert(0,"TextureManager.isHardwareFilteringSupported is abstract.");
    }

    override Resource createImpl(string name, ResourceHandle handle, 
                                 string group, bool isManual, ManualResourceLoader loader, 
                                NameValuePairList createParams)
    {
        assert(0,"TextureManager.createImpl is abstract.");
    }

    /** Sets the default number of mipmaps to be used for loaded textures, for when textures are
            loaded automatically (e.g. by Material class) or when 'load' is called with the default
            parameters by the application.
            If set to MIP_UNLIMITED mipmaps will be generated until the lowest possible
                level, 1x1x1.
            @note
                The default value is 0.
        */
    void setDefaultNumMipmaps(size_t num)
    {
        mDefaultNumMipmaps = num;
    }
    
    /** Gets the default number of mipmaps to be used for loaded textures.
        */
    size_t getDefaultNumMipmaps()
    {
        return mDefaultNumMipmaps;
    }
    
protected:
    
    ushort mPreferredIntegerBitDepth;
    ushort mPreferredFloatBitDepth;
    size_t mDefaultNumMipmaps;
}