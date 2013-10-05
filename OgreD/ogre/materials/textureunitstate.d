module ogre.materials.textureunitstate;
debug import std.stdio;
//import std.container;
import std.string;
import std.array;

import ogre.compat;
import ogre.config;
import ogre.sharedptr;
import ogre.general.common;
import ogre.general.colourvalue;
import ogre.lod.lodstrategy;
import ogre.math.matrix;
import ogre.math.frustum;
import ogre.math.angles;
import ogre.image.pixelformat;
import ogre.general.log;
import ogre.general.root;
import ogre.general.controller;
import ogre.general.controllermanager;
import ogre.materials.pass;
import ogre.materials.blendmode;
import ogre.materials.materialmanager;
import ogre.resources.texturemanager;
import ogre.resources.texture;
import ogre.math.maths;
import ogre.exception;

/** \addtogroup Core
*  @{
*/
/** \addtogroup Materials
*  @{
*/

/** Class representing the state of a single texture unit during a Pass of a
        Technique, of a Material.
    @remarks
        Texture units are pipelines for retrieving texture data for rendering onto
        your objects in the world. Using them is common to both the fixed-function and 
        the programmable (vertex and fragment program) pipeline, but some of the 
        settings will only have an effect in the fixed-function pipeline (for example, 
        setting a texture rotation will have no effect if you use the programmable
        pipeline, because this is overridden by the fragment program). The effect
        of each setting as regards the 2 pipelines is commented in each setting.
    @par
        When I use the term 'fixed-function pipeline' I mean traditional rendering
        where you do not use vertex or fragment programs (shaders). Programmable 
        pipeline means that for this pass you are using vertex or fragment programs.
    */
class TextureUnitState //: public TextureUnitStateAlloc
{
    //friend class RenderSystem;
public:
    /** Definition of the broad types of texture effect you can apply to a texture unit.
        @note
            Note that these have no effect when using the programmable pipeline, since their
            effect is overridden by the vertex / fragment programs.
        */
    enum TextureEffectType
    {
        /// Generate all texture coords based on angle between camera and vertex.
        ET_ENVIRONMENT_MAP,
        /// Generate texture coords based on a frustum.
        ET_PROJECTIVE_TEXTURE,
        /// Constant u/v scrolling effect.
        ET_UVSCROLL,
        /// Constant u scrolling effect.
        ET_USCROLL,
        /// Constant u/v scrolling effect.
        ET_VSCROLL,
        /// Constant rotation.
        ET_ROTATE,
        /// More complex transform.
        ET_TRANSFORM
    }
    
    /** Enumeration to specify type of envmap.
        @note
            Note that these have no effect when using the programmable pipeline, since their
            effect is overridden by the vertex / fragment programs.
        */
    enum EnvMapType
    {
        /// Envmap based on vector from camera to vertex position, good for planar geometry.
        ENV_PLANAR,
        /// Envmap based on dot of vector from camera to vertex and vertex normal, good for curves.
        ENV_CURVED,
        /// Envmap intended to supply reflection vectors for cube mapping.
        ENV_REFLECTION,
        /// Envmap intended to supply normal vectors for cube mapping.
        ENV_NORMAL
    }
    
    /** Useful enumeration when dealing with procedural transforms.
        @note
            Note that these have no effect when using the programmable pipeline, since their
            effect is overridden by the vertex / fragment programs.
        */
    enum TextureTransformType
    {
        TT_TRANSLATE_U,
        TT_TRANSLATE_V,
        TT_SCALE_U,
        TT_SCALE_V,
        TT_ROTATE
    }
    
    /** Texture addressing modes - default is TAM_WRAP.
        @note
            These settings are relevant in both the fixed-function and the
            programmable pipeline.
        */
    alias uint TextureAddressingMode;
    enum : TextureAddressingMode
    {
        /// Texture wraps at values over 1.0.
        TAM_WRAP,
        /// Texture mirrors (flips) at joins over 1.0.
        TAM_MIRROR,
        /// Texture clamps at 1.0.
        TAM_CLAMP,
        /// Texture coordinates outside the range [0.0, 1.0] are set to the border colour.
        TAM_BORDER
    }
    
    /** Texture addressing mode for each texture coordinate. */
    struct UVWAddressingMode
    {
        TextureAddressingMode u, v, w;
    }
    
    /** Enum identifying the frame indexes for faces of a cube map (not the composite 3D type.
        */
    enum TextureCubeFace
    {
        CUBE_FRONT = 0,
        CUBE_BACK = 1,
        CUBE_LEFT = 2,
        CUBE_RIGHT = 3,
        CUBE_UP = 4,
        CUBE_DOWN = 5
    }
    
    /** Internal structure defining a texture effect.
        */
    class TextureEffect {
        TextureEffectType type;
        int subtype;
        Real arg1, arg2;
        WaveformType waveType;
        Real base;
        Real frequency;
        Real phase;
        Real amplitude;
        Controller!Real controller;
        Frustum frustum;
    }
    
    /** Texture effects in a multimap paired array.
        */
    //typedef multimap<TextureEffectType, TextureEffect>.type EffectMap;
    //FIXME Is it multimap or not ?!
    alias TextureEffect[][TextureEffectType] EffectMap;
    //alias TextureEffect[TextureEffectType] EffectMap;
    
    /** Default constructor.
        */
    this(Pass parent)
    {
        mCurrentFrame = 0;
        mAnimDuration = 0;
        mCubic = false;
        mTextureType = TextureType.TEX_TYPE_2D;
        mDesiredFormat = PixelFormat.PF_UNKNOWN;
        mTextureSrcMipmaps = TextureMipmap.MIP_DEFAULT;
        mTextureCoordSetIndex = 0;
        mBorderColour = ColourValue.Black;
        mTextureLoadFailed = false;
        mIsAlpha = false;
        mHwGamma = false;
        mGamma = 1;
        mRecalcTexMatrix = false;
        mUMod = 0;
        mVMod = 0;
        mUScale = 1;
        mVScale = 1;
        mRotate = 0;
        mTexModMatrix = Matrix4.IDENTITY;
        mMinFilter = FilterOptions.FO_LINEAR;
        mMagFilter = FilterOptions.FO_LINEAR;
        mMipFilter = FilterOptions.FO_POINT;
        mCompareEnabled = false;
        mCompareFunc = CompareFunction.CMPF_GREATER_EQUAL;
        mMaxAniso = MaterialManager.getSingleton().getDefaultAnisotropy();
        mMipmapBias = 0;
        mIsDefaultAniso = true;
        mIsDefaultFiltering = true;
        mBindingType = BindingType.BT_FRAGMENT;
        mContentType = ContentType.CONTENT_NAMED;
        mParent = parent;
        //mAnimController = 0;
        
        mColourBlendMode.blendType = LayerBlendType.LBT_COLOUR;
        mAlphaBlendMode.operation = LayerBlendOperationEx.LBX_MODULATE;
        mAlphaBlendMode.blendType = LayerBlendType.LBT_ALPHA;
        mAlphaBlendMode.source1 = LayerBlendSource.LBS_TEXTURE;
        mAlphaBlendMode.source2 = LayerBlendSource.LBS_CURRENT;
        setColourOperation(LayerBlendOperation.LBO_MODULATE);
        setTextureAddressingMode(TAM_WRAP);

        if( Pass.getHashFunction() == Pass.getBuiltinHashFunction( Pass.BuiltinHashFunction.MIN_TEXTURE_CHANGE ) )
        {
            mParent._dirtyHash();
        }
        
    }
    
    this(Pass parent, TextureUnitState oth )
    {
        mParent = parent;
        //mAnimController = 0;
        this.copyFrom(oth);
    }
    
    /** Default destructor.
        */
    ~this()
    {
        // Unload ensure all controllers destroyed
        _unload();
    }
    
    /** Name-based constructor.
        @param texName
            The basic name of the texture e.g. brickwall.jpg, stonefloor.png.
        @param texCoordSet
            The index of the texture coordinate set to use.
        */
    this(Pass parent, string texName, uint texCoordSet = 0)
    {
        mCurrentFrame = 0;
        mAnimDuration = 0;
        mCubic = false;
        mTextureType = TextureType.TEX_TYPE_2D;
        mDesiredFormat = PixelFormat.PF_UNKNOWN;
        mTextureSrcMipmaps = TextureMipmap.MIP_DEFAULT;
        mTextureCoordSetIndex = 0;
        mBorderColour = ColourValue.Black;
        mTextureLoadFailed = false;
        mIsAlpha = false;
        mHwGamma = false;
        mGamma = 1.0;
        mRecalcTexMatrix = false;
        mUMod = 0;
        mVMod = 0;
        mUScale = 1;
        mVScale = 1;
        mRotate = 0;
        mTexModMatrix = Matrix4.IDENTITY;
        mMinFilter = FilterOptions.FO_LINEAR;
        mMagFilter = FilterOptions.FO_LINEAR;
        mMipFilter = FilterOptions.FO_POINT;
        mCompareEnabled = false;
        mCompareFunc = CompareFunction.CMPF_GREATER_EQUAL;
        mMaxAniso = MaterialManager.getSingleton().getDefaultAnisotropy();
        mMipmapBias = 0;
        mIsDefaultAniso = true;
        mIsDefaultFiltering = true;
        mBindingType = BindingType.BT_FRAGMENT;
        mContentType = ContentType.CONTENT_NAMED;
        mParent = parent;
        //mAnimController = 0;
        
        mColourBlendMode.blendType = LayerBlendType.LBT_COLOUR;
        mAlphaBlendMode.operation = LayerBlendOperationEx.LBX_MODULATE;
        mAlphaBlendMode.blendType = LayerBlendType.LBT_ALPHA;
        mAlphaBlendMode.source1 = LayerBlendSource.LBS_TEXTURE;
        mAlphaBlendMode.source2 = LayerBlendSource.LBS_CURRENT;
        setColourOperation(LayerBlendOperation.LBO_MODULATE);
        setTextureAddressingMode(TAM_WRAP);
        
        setTextureName(texName);
        setTextureCoordSet(texCoordSet);
        
        if( Pass.getHashFunction() == Pass.getBuiltinHashFunction( Pass.BuiltinHashFunction.MIN_TEXTURE_CHANGE ) )
        {
            mParent._dirtyHash();
        }
        
    }
    
    
    //TextureUnitState & operator = (TextureUnitState& oth );
    void copyFrom ( TextureUnitState oth ) //TODO copyFrom.
    {
        assert(mAnimController is null);
        assert(mEffects.length);
        
        // copy basic members (int's, real's)
        //memcpy( this, &oth, cast(ubyte*)(&oth.mFrames) - cast(ubyte*)(&oth) );
        
        mCurrentFrame = oth.mCurrentFrame;
        mAnimDuration = oth.mAnimDuration;
        mCubic = oth.mCubic;
        mTextureType = oth.mTextureType;
        mDesiredFormat = oth.mDesiredFormat;
        mTextureSrcMipmaps = oth.mTextureSrcMipmaps;
        mTextureCoordSetIndex = oth.mTextureCoordSetIndex;
        mAddressMode = oth.mAddressMode;
        mBorderColour = oth.mBorderColour;
        mColourBlendMode = oth.mColourBlendMode;
        mColourBlendFallbackSrc = oth.mColourBlendFallbackSrc;
        mColourBlendFallbackDest = oth.mColourBlendFallbackDest;
        mAlphaBlendMode = oth.mAlphaBlendMode;
        mTextureLoadFailed = oth.mTextureLoadFailed;
        mIsAlpha = oth.mIsAlpha;
        mHwGamma = oth.mHwGamma;
        mRecalcTexMatrix = oth.mRecalcTexMatrix;
        mUMod = oth.mUMod;
        mVMod = oth.mVMod;
        mUScale = oth.mUScale;
        mVScale = oth.mVScale;
        mRotate = oth.mRotate;
        mTexModMatrix = oth.mTexModMatrix;
        mMinFilter = oth.mMinFilter;
        mMagFilter = oth.mMagFilter;
        mMipFilter = oth.mMipFilter;
        mCompareEnabled = oth.mCompareEnabled;
        mCompareFunc = oth.mCompareFunc;
        mMaxAniso = oth.mMaxAniso;
        mMipmapBias = oth.mMipmapBias;
        mIsDefaultAniso = oth.mIsDefaultAniso;
        mIsDefaultFiltering = oth.mIsDefaultFiltering;
        mBindingType = oth.mBindingType;
        mContentType = oth.mContentType;
        mCompositorRefMrtIndex = oth.mCompositorRefMrtIndex;
        
        // copy complex members
        mFrames  = oth.mFrames;
        mFramePtrs = oth.mFramePtrs;
        mName    = oth.mName;
        mEffects = oth.mEffects;
        
        mTextureNameAlias = oth.mTextureNameAlias;
        mCompositorRefName = oth.mCompositorRefName;
        mCompositorRefTexName = oth.mCompositorRefTexName;
        //FIXME Can't sharing controllers with other TUS, reset to null to avoid potential bug.
        foreach (k, vs; mEffects)
        {
            foreach(v; vs)
                v.controller = null;
        }
        
        // Load immediately if Material loaded
        if (isLoaded())
        {
            _load();
        }
        
        // Tell parent to recalculate hash
        if( Pass.getHashFunction() == Pass.getBuiltinHashFunction( Pass.BuiltinHashFunction.MIN_TEXTURE_CHANGE ) )
        {
            mParent._dirtyHash();
        }
    }

    /// C++ has that *ptr0 = *ptr1;
    void _copy ( TextureUnitState oth )
    {
        // copy basic members (int's, real's)
        //memcpy( this, &oth, cast(ubyte*)(&oth.mFrames) - cast(ubyte*)(&oth) );
        // State
        mCurrentFrame = oth.mCurrentFrame;
        mAnimDuration = oth.mAnimDuration;
        mCubic = oth.mCubic;
        mTextureType = oth.mTextureType;
        mDesiredFormat = oth.mDesiredFormat;
        mTextureSrcMipmaps = oth.mTextureSrcMipmaps;
        mTextureCoordSetIndex = oth.mTextureCoordSetIndex;
        mAddressMode = oth.mAddressMode;
        mBorderColour = oth.mBorderColour;
        mColourBlendMode = oth.mColourBlendMode;
        mColourBlendFallbackSrc = oth.mColourBlendFallbackSrc;
        mColourBlendFallbackDest = oth.mColourBlendFallbackDest;
        mAlphaBlendMode = oth.mAlphaBlendMode;
        mTextureLoadFailed = oth.mTextureLoadFailed;
        mIsAlpha = oth.mIsAlpha;
        mHwGamma = oth.mHwGamma;
        mGamma = oth.mGamma;
        mRecalcTexMatrix = oth.mRecalcTexMatrix;
        mUMod = oth.mUMod;
        mVMod = oth.mVMod;
        mUScale = oth.mUScale;
        mVScale = oth.mVScale;
        mRotate = oth.mRotate;
        mTexModMatrix = oth.mTexModMatrix;
        mMinFilter = oth.mMinFilter;
        mMagFilter = oth.mMagFilter;
        mMipFilter = oth.mMipFilter;
        mCompareEnabled = oth.mCompareEnabled;
        mCompareFunc = oth.mCompareFunc;
        mMaxAniso = oth.mMaxAniso;
        mMipmapBias = oth.mMipmapBias;
        mIsDefaultAniso = oth.mIsDefaultAniso;
        mIsDefaultFiltering = oth.mIsDefaultFiltering;
        mBindingType = oth.mBindingType;
        mContentType = oth.mContentType;
        mCompositorRefMrtIndex = oth.mCompositorRefMrtIndex;
        
        // copy complex members
        mFrames  = oth.mFrames.dup; //TODO dup or just ref? 'Reference' types so dup it
        mFramePtrs = oth.mFramePtrs.dup;
        mName    = oth.mName;
        mEffects = oth.mEffects;
        
        mTextureNameAlias = oth.mTextureNameAlias;
        mCompositorRefName = oth.mCompositorRefName;
        mCompositorRefTexName = oth.mCompositorRefTexName;
        
        // Load immediately if Material loaded
        if (isLoaded())
        {
            _load();
        }
        
        // Tell parent to recalculate hash
        if( Pass.getHashFunction() == Pass.getBuiltinHashFunction( Pass.BuiltinHashFunction.MIN_TEXTURE_CHANGE ) )
        {
            mParent._dirtyHash();
        }
    }
    
    /** Get the name of current texture image for this layer.
        @remarks
            This will either always be a single name for this layer,
            or will be the name of the current frame for an animated
            or otherwise multi-frame texture.
        @note
            Applies to both fixed-function and programmable pipeline.
        */
   string getTextureName()
    {
        // Return name of current frame
        if (mCurrentFrame < mFrames.length)
            return mFrames[mCurrentFrame];
        else
            return "";
    }
    
    /** Sets this texture layer to use a single texture, given the
            name of the texture to use on this layer.
        @note
            Applies to both fixed-function and programmable pipeline.
        */
    void setTextureName(string name, TextureType texType = TextureType.TEX_TYPE_2D)
    {
        setContentType(ContentType.CONTENT_NAMED);
        mTextureLoadFailed = false;
        
        if (texType == TextureType.TEX_TYPE_CUBE_MAP)
        {
            // delegate to cubic texture implementation
            setCubicTextureName(name, true);
        }
        else
        {
            mFrames.length = (1);
            mFramePtrs.length = (1);
            mFrames[0] = name;
            mFramePtrs[0].setNull();
            // defer load until used, so don't grab pointer yet
            mCurrentFrame = 0;
            mCubic = false;
            mTextureType = texType;
            if (name is null || !name.length)
            {
                return;
            }
            
            
            // Load immediately ?
            if (isLoaded())
            {
                _load(); // reload
            }
            // Tell parent to recalculate hash
            if( Pass.getHashFunction() == Pass.getBuiltinHashFunction( Pass.BuiltinHashFunction.MIN_TEXTURE_CHANGE ) )
            {
                mParent._dirtyHash();
            }
        }
        
    }
    
    /** Sets this texture layer to use a single texture, given the
            pointer to the texture to use on this layer.
        @note
            Applies to both fixed-function and programmable pipeline.
        */
    void setTexture( SharedPtr!Texture texPtr)
    {
        if (texPtr.isNull())
        {
            throw new ItemNotFoundError(
                        "Texture Pointer is empty.",
                        "TextureUnitState.setTexture");
        }
        
        setContentType(ContentType.CONTENT_NAMED);
        mTextureLoadFailed = false;
        
        if (texPtr.getAs().getTextureType() == TextureType.TEX_TYPE_CUBE_MAP)
        {
            // delegate to cubic texture implementation
            setCubicTexture([texPtr], true);
        }
        else
        {
            mFrames.length = (1);
            mFramePtrs.length = (1);
            mFrames[0] = texPtr.getAs().getName();
            mFramePtrs[0] = texPtr;
            // defer load until used, so don't grab pointer yet
            mCurrentFrame = 0;
            mCubic = false;
            mTextureType = texPtr.getAs().getTextureType();
            
            // Load immediately ?
            if (isLoaded())
            {
                _load(); // reload
            }
            // Tell parent to recalculate hash
            if( Pass.getHashFunction() == Pass.getBuiltinHashFunction( Pass.BuiltinHashFunction.MIN_TEXTURE_CHANGE ) )
            {
                mParent._dirtyHash();
            }
        }
    }
    
    /** Sets this texture layer to use a combination of 6 texture maps, each one relating to a face of a cube.
        @remarks
            Cubic textures are made up of 6 separate texture images. Each one of these is an orthogonal view of the
            world with a FOV of 90 degrees and an aspect ratio of 1:1. You can generate these from 3D Studio by
            rendering a scene to a reflection map of a transparent cube and saving the output files.
        @par
            Cubic maps can be used either for skyboxes (complete wrap-around skies, like space) or as environment
            maps to simulate reflections. The system deals with these 2 scenarios in different ways:
            <ol>
            <li>
            <p>
            for cubic environment maps, the 6 textures are combined into a single 'cubic' texture map which
            is then addressed using 3D texture coordinates. This is required because you don't know what
            face of the box you're going to need to address when you render an object, and typically you
            need to reflect more than one face on the one object, so all 6 textures are needed to be
            'active' at once. Cubic environment maps are enabled by calling this method with the forUVW
            parameter set to true, and then calling setEnvironmentMap(true).
            </p>
            <p>
            Note that not all cards support cubic environment mapping.
            </p>
            </li>
            <li>
            <p>
            for skyboxes, the 6 textures are kept separate and used independently for each face of the skybox.
            This is done because not all cards support 3D cubic maps and skyboxes do not need to use 3D
            texture coordinates so it is simpler to render each face of the box with 2D coordinates, changing
            texture between faces.
            </p>
            <p>
            Skyboxes are created by calling SceneManager.setSkyBox.
            </p>
            </li>
            </ol>
        @note
            Applies to both fixed-function and programmable pipeline.
        @param name
            The basic name of the texture e.g. brickwall.jpg, stonefloor.png. There must be 6 versions
            of this texture with the suffixes _fr, _bk, _up, _dn, _lf, and _rt (before the extension) which
            make up the 6 sides of the box. The textures must all be the same size and be powers of 2 in width & height.
            If you can't make your texture names conform to this, use the alternative method of the same name which takes
            an array of texture names instead.
        @param forUVW
            Set to @c true if you want a single 3D texture addressable with 3D texture coordinates rather than
            6 separate textures. Useful for cubic environment mapping.
        */
    void setCubicTextureName(string name, bool forUVW = false )
    {
        if (forUVW)
        {
            setCubicTextureName([name], forUVW);
        }
        else
        {
            setContentType(ContentType.CONTENT_NAMED);
            mTextureLoadFailed = false;
            string ext;
            string[6] suffixes = ["_fr", "_bk", "_lf", "_rt", "_up", "_dn"];
            string baseName;
            string[6] fullNames;
            
            ptrdiff_t pos = name.lastIndexOf(".");
            if( pos != -1 )
            {
                baseName = name[0..pos];
                ext = name[pos..$];
            }
            else
                baseName = name;
            
            for (int i = 0; i < 6; ++i)
            {
                fullNames[i] = baseName ~ suffixes[i] ~ ext;
            }
            
            setCubicTextureName(fullNames, forUVW);
        }
    }
    
    /** Sets this texture layer to use a combination of 6 texture maps, each one relating to a face of a cube.
        @remarks
            Cubic textures are made up of 6 separate texture images. Each one of these is an orthogonal view of the
            world with a FOV of 90 degrees and an aspect ratio of 1:1. You can generate these from 3D Studio by
            rendering a scene to a reflection map of a transparent cube and saving the output files.
        @par
            Cubic maps can be used either for skyboxes (complete wrap-around skies, like space) or as environment
            maps to simulate reflections. The system deals with these 2 scenarios in different ways:
            <ol>
            <li>
            <p>
            For cubic environment maps, the 6 textures are combined into a single 'cubic' texture map which
            is then addressed using 3D texture coordinates. This is required because you don't know what
            face of the box you're going to need to address when you render an object, and typically you
            need to reflect more than one face on the one object, so all 6 textures are needed to be
            'active' at once. Cubic environment maps are enabled by calling this method with the forUVW
            parameter set to @c true, and then calling setEnvironmentMap(true).
            </p>
            <p>
            Note that not all cards support cubic environment mapping.
            </p>
            </li>
            <li>
            <p>
            For skyboxes, the 6 textures are kept separate and used independently for each face of the skybox.
            This is done because not all cards support 3D cubic maps and skyboxes do not need to use 3D
            texture coordinates so it is simpler to render each face of the box with 2D coordinates, changing
            texture between faces.
            </p>
            <p>
            Skyboxes are created by calling SceneManager.setSkyBox.
            </p>
            </li>
            </ol>
        @note
            Applies to both fixed-function and programmable pipeline.
        @param names
            The 6 names of the textures which make up the 6 sides of the box. The textures must all 
            be the same size and be powers of 2 in width & height.
            Must be an Ogre.String array with a length of 6 unless forUVW is set to @c true.
        @param forUVW
            Set to @c true if you want a single 3D texture addressable with 3D texture coordinates rather than
            6 separate textures. Useful for cubic environment mapping.
        */
    void setCubicTextureName(string[] names, bool forUVW = false )
    {
        setContentType(ContentType.CONTENT_NAMED);
        mTextureLoadFailed = false;
        mFrames.length = (forUVW ? 1 : 6);
        // resize pointers, but don't populate until asked for
        mFramePtrs.length = (forUVW ? 1 : 6);
        mAnimDuration = 0;
        mCurrentFrame = 0;
        mCubic = true;
        mTextureType = forUVW ? TextureType.TEX_TYPE_CUBE_MAP : TextureType.TEX_TYPE_2D;
        
        foreach (i; 0..mFrames.length)
        {
            mFrames[i] = names[i];
            mFramePtrs[i].setNull();
        }
        // Tell parent we need recompiling, will cause reload too
        mParent._notifyNeedsRecompile();
    }
    
    /** Sets this texture layer to use a combination of 6 texture maps, each one relating to a face of a cube.
        @remarks
            Cubic textures are made up of 6 separate texture images. Each one of these is an orthogonal view of the
            world with a FOV of 90 degrees and an aspect ratio of 1:1. You can generate these from 3D Studio by
            rendering a scene to a reflection map of a transparent cube and saving the output files.
        @par
            Cubic maps can be used either for skyboxes (complete wrap-around skies, like space) or as environment
            maps to simulate reflections. The system deals with these 2 scenarios in different ways:
            <ol>
            <li>
            <p>
            for cubic environment maps, the 6 textures are combined into a single 'cubic' texture map which
            is then addressed using 3D texture coordinates. This is required because you don't know what
            face of the box you're going to need to address when you render an object, and typically you
            need to reflect more than one face on the one object, so all 6 textures are needed to be
            'active' at once. Cubic environment maps are enabled by calling this method with the forUVW
            parameter set to true, and then calling setEnvironmentMap(true).
            </p>
            <p>
            Note that not all cards support cubic environment mapping.
            </p>
            </li>
            <li>
            <p>
            for skyboxes, the 6 textures are kept separate and used independently for each face of the skybox.
            This is done because not all cards support 3D cubic maps and skyboxes do not need to use 3D
            texture coordinates so it is simpler to render each face of the box with 2D coordinates, changing
            texture between faces.
            </p>
            <p>
            Skyboxes are created by calling SceneManager.setSkyBox.
            </p>
            </li>
            </ol>
        @note
            Applies to both fixed-function and programmable pipeline.
        @param texPtrs
            The 6 pointers to the textures which make up the 6 sides of the box. The textures must all 
            be the same size and be powers of 2 in width & height.
            Must be an Ogre.SharedPtr!Texture array with a length of 6 unless forUVW is set to @c true.
        @param forUVW
            Set to @c true if you want a single 3D texture addressable with 3D texture coordinates rather than
            6 separate textures. Useful for cubic environment mapping.
        */
    void setCubicTexture(SharedPtr!Texture[] texPtrs, bool forUVW = false )
    {
        setContentType(ContentType.CONTENT_NAMED);
        mTextureLoadFailed = false;
        mFrames.length = (forUVW ? 1 : 6);
        // resize pointers, but don't populate until asked for
        mFramePtrs.length = (forUVW ? 1 : 6);
        mAnimDuration = 0;
        mCurrentFrame = 0;
        mCubic = true;
        mTextureType = forUVW ? TextureType.TEX_TYPE_CUBE_MAP : TextureType.TEX_TYPE_2D;
        
        for (uint i = 0; i < mFrames.length; ++i)
        {
            mFrames[i] = texPtrs[i].get().getName();
            mFramePtrs[i] = texPtrs[i];
        }
        // Tell parent we need recompiling, will cause reload too
        mParent._notifyNeedsRecompile();
    }
    
    /** Sets the names of the texture images for an animated texture.
        @remarks
            Animated textures are just a series of images making up the frames of the animation. All the images
            must be the same size, and their names must have a frame number appended before the extension, e.g.
            if you specify a name of "wall.jpg" with 3 frames, the image names must be "wall_0.jpg", "wall_1.jpg"
            and "wall_2.jpg".
        @par
            You can change the active frame on a texture layer by calling the setCurrentFrame method.
        @note
            If you can't make your texture images conform to the naming standard laid out here, you
            can call the alternative setAnimatedTextureName method which takes an array of names instead.
        @note
            Applies to both fixed-function and programmable pipeline.
        @param name
            The base name of the textures to use e.g. wall.jpg for frames wall_0.jpg, wall_1.jpg etc.
        @param numFrames
            The number of frames in the sequence.
        @param duration
            The length of time it takes to display the whole animation sequence, in seconds.
            If 0, no automatic transition occurs.
        */
        
    void setAnimatedTextureName(string name, size_t numFrames, Real duration = 0 )
    {
        setContentType(ContentType.CONTENT_NAMED);
        mTextureLoadFailed = false;
        
        string ext;
        string baseName;
        
        ptrdiff_t pos = std.string.lastIndexOf(name, ".");
        baseName = name[0..pos];
        ext = name[pos..$];
        
        mFrames.length = (numFrames);
        // resize pointers, but don't populate until needed
        mFramePtrs.length = (numFrames);
        mAnimDuration = duration;
        mCurrentFrame = 0;
        mCubic = false;
        
        foreach (i; 0..mFrames.length)
        {
            string str = baseName ~ "_" ~ std.conv.to!string(i) ~ ext;
            mFrames[i] = str;
            mFramePtrs[i].setNull();
        }
        
        // Load immediately if Material loaded
        if (isLoaded())
        {
            _load();
        }
        // Tell parent to recalculate hash
        if( Pass.getHashFunction() == Pass.getBuiltinHashFunction( Pass.BuiltinHashFunction.MIN_TEXTURE_CHANGE ) )
        {
            mParent._dirtyHash();
        }
        
    }
    
    /** Sets the names of the texture images for an animated texture.
        @remarks
            This an alternative method to the one where you specify a single name and let the system derive
            the names of each frame, incase your images can't conform to this naming standard.
        @par
            Animated textures are just a series of images making up the frames of the animation. All the images
            must be the same size, and you must provide their names as an array in the first parameter.
            You can change the active frame on a texture layer by calling the setCurrentFrame method.
        @note
            If you can make your texture images conform to a naming standard of basicName_frame.ext, you
            can call the alternative setAnimatedTextureName method which just takes a base name instead.
        @note
            Applies to both fixed-function and programmable pipeline.
        @param names
            Pointer to array of names of the textures to use, in frame order.
        @param numFrames
            The number of frames in the sequence.
        @param duration
            The length of time it takes to display the whole animation sequence, in seconds.
            If 0, no automatic transition occurs.
        */
        
    void setAnimatedTextureName(string[] names, uint numFrames, Real duration = 0 )
    {
        setContentType(ContentType.CONTENT_NAMED);
        mTextureLoadFailed = false;
        
        mFrames.length = (numFrames);
        // resize pointers, but don't populate until needed
        mFramePtrs.length = (numFrames);
        mAnimDuration = duration;
        mCurrentFrame = 0;
        mCubic = false;
        
        foreach (i; 0..mFrames.length)
        {
            mFrames[i] = names[i];
            mFramePtrs[i].setNull();
        }
        
        // Load immediately if Material loaded
        if (isLoaded())
        {
            _load();
        }
        // Tell parent to recalculate hash
        if( Pass.getHashFunction() == Pass.getBuiltinHashFunction( Pass.BuiltinHashFunction.MIN_TEXTURE_CHANGE ) )
        {
            mParent._dirtyHash();
        }
        
    }
    
    /** Returns the width and height of the texture in the given frame.
        */
    pair!( size_t, size_t ) getTextureDimensions( uint frame = 0 )
    {
        
        SharedPtr!Texture tex = _getTexturePtr(frame);
        if (tex.isNull())
            throw new ItemNotFoundError("Could not find texture " ~ mFrames[ frame ],
                        "TextureUnitState.getTextureDimensions" );
        
        return pair!( size_t, size_t )( tex.getAs().getWidth(), tex.getAs().getHeight() );
    }
    
    /** Changes the active frame in an animated or multi-image texture.
        @remarks
            An animated texture (or a cubic texture where the images are not combined for 3D use) is made up of
            a number of frames. This method sets the active frame.
        @note
            Applies to both fixed-function and programmable pipeline.
        */
    void setCurrentFrame( uint frameNumber )
    {
        if (frameNumber < mFrames.length)
        {
            mCurrentFrame = frameNumber;
            // this will affect the hash
            if( Pass.getHashFunction() == Pass.getBuiltinHashFunction( Pass.BuiltinHashFunction.MIN_TEXTURE_CHANGE ) )
            {
                mParent._dirtyHash();
            }
        }
        else
        {
            throw new InvalidParamsError( "frameNumber parameter value exceeds number of stored frames.",
                        "TextureUnitState.setCurrentFrame");
        }
        
    }
    
    /** Gets the active frame in an animated or multi-image texture layer.
        @note
            Applies to both fixed-function and programmable pipeline.
        */
    uint getCurrentFrame()
    {
        return mCurrentFrame;
    }
    
    /** Gets the name of the texture associated with a frame number.
            Throws an exception if frameNumber exceeds the number of stored frames.
        @note
            Applies to both fixed-function and programmable pipeline.
        */
   string getFrameTextureName(uint frameNumber)
    {
        if (frameNumber >= mFrames.length)
        {
            throw new InvalidParamsError( "frameNumber parameter value exceeds number of stored frames.",
                        "TextureUnitState.getFrameTextureName");
        }
        
        return mFrames[frameNumber];
    }
    
    /** Sets the name of the texture associated with a frame.
        @param name
            The name of the texture.
        @param frameNumber
            The frame the texture name is to be placed in.
        @note
            Throws an exception if frameNumber exceeds the number of stored frames.
            Applies to both fixed-function and programmable pipeline.
        */
    void setFrameTextureName(string name, uint frameNumber)
    {
        mTextureLoadFailed = false;
        if (frameNumber < mFrames.length)
        {
            mFrames[frameNumber] = name;
            // reset pointer (don't populate until requested)
            mFramePtrs[frameNumber].setNull();  
            
            if (isLoaded())
            {
                _load(); // reload
            }
            // Tell parent to recalculate hash
            if( Pass.getHashFunction() == Pass.getBuiltinHashFunction( Pass.BuiltinHashFunction.MIN_TEXTURE_CHANGE ) )
            {
                mParent._dirtyHash();
            }
        }
        else // raise exception for frameNumber out of bounds
        {
            throw new InvalidParamsError( "frameNumber parameter value exceeds number of stored frames.",
                        "TextureUnitState.setFrameTextureName");
        }
    }
    
    /** Add a Texture name to the end of the frame container.
        @param name
            The name of the texture.
        @note
            Applies to both fixed-function and programmable pipeline.
        */
    void addFrameTextureName(string name)
    {
        setContentType(ContentType.CONTENT_NAMED);
        mTextureLoadFailed = false;
        
        mFrames.insert(name);
        // Add blank pointer, load on demand
        mFramePtrs.insert(SharedPtr!Texture());
        
        // Load immediately if Material loaded
        if (isLoaded())
        {
            _load();
        }
        // Tell parent to recalculate hash
        if( Pass.getHashFunction() == Pass.getBuiltinHashFunction( Pass.BuiltinHashFunction.MIN_TEXTURE_CHANGE ) )
        {
            mParent._dirtyHash();
        }
    }
    
    /** Deletes a specific texture frame.  The texture used is not deleted but the
            texture will no longer be used by the Texture Unit.  An exception is raised
            if the frame number exceeds the number of actual frames.
        @param frameNumber
            The frame number of the texture to be deleted.
        @note
            Applies to both fixed-function and programmable pipeline.
        */
    void deleteFrameTextureName(size_t frameNumber)
    {
        mTextureLoadFailed = false;
        if (frameNumber < mFrames.length)
        {
            mFrames.removeFromArrayIdx(frameNumber);
            mFramePtrs.removeFromArrayIdx(frameNumber);
            
            if (isLoaded())
            {
                _load();
            }
            // Tell parent to recalculate hash
            if( Pass.getHashFunction() == Pass.getBuiltinHashFunction( Pass.BuiltinHashFunction.MIN_TEXTURE_CHANGE ) )
            {
                mParent._dirtyHash();
            }
        }
        else
        {
            throw new InvalidParamsError( "frameNumber parameter value exceeds number of stored frames.",
                        "TextureUnitState.deleteFrameTextureName");
        }
    }
    /** Gets the number of frames for a texture.
        @note
            Applies to both fixed-function and programmable pipeline.
        */
    uint getNumFrames()
    {
        return cast(uint)mFrames.length;
    }
    
    
    /** The type of unit to bind the texture settings to. */
    enum BindingType
    {
        /** Regular fragment processing unit - the default. */
        BT_FRAGMENT = 0,
        /** Vertex processing unit - indicates this unit will be used for 
                a vertex texture fetch.
            */
        BT_VERTEX = 1,          
        /// Geometry processing unit        
        BT_GEOMETRY = 2,
        /// Tesselation control processing unit
        BT_TESSELATION_HULL = 3,
        /// Tesselation evaluation processing unit
        BT_TESSELATION_DOMAIN = 4,
        /// Compute processing unit
        BT_COMPUTE = 5
    }
    /** Enum identifying the type of content this texture unit contains.
        */
    enum ContentType
    {
        /// Normal texture identified by name
        CONTENT_NAMED = 0,
        /// A shadow texture, automatically bound by engine
        CONTENT_SHADOW = 1,
        /// A compositor texture, automatically linked to active viewport's chain
        CONTENT_COMPOSITOR = 2
    }
    
    /** Sets the type of unit these texture settings should be bound to. 
        @remarks
            Some render systems, when implementing vertex texture fetch, separate
            the binding of textures for use in the vertex program versus those
            used in fragment programs. This setting allows you to target the
            vertex processing unit with a texture binding, in those cases. For
            rendersystems which have a unified binding for the vertex and fragment
            units, this setting makes no difference.
        */
    void setBindingType(BindingType bt)
    {
        mBindingType = bt;
        
    }
    
    /** Gets the type of unit these texture settings should be bound to.  
        */
    BindingType getBindingType()
    {
        return mBindingType;
    }
    
    /** Set the type of content this TextureUnitState references.
        @remarks
            The default is to reference a standard named texture, but this unit
            can also reference automated content like a shadow texture.
        */
    void setContentType(ContentType ct)
    {
        mContentType = ct;
        if (ct == ContentType.CONTENT_SHADOW || ct == ContentType.CONTENT_COMPOSITOR)
        {
            // Clear out texture frames, not applicable
            mFrames.clear();
            // One reference space, set manually through _setTexturePtr
            mFramePtrs.length = 1;
            mFramePtrs[0].setNull();
        }
    }
    /** Get the type of content this TextureUnitState references. */
    ContentType getContentType()
    {
        return mContentType;
    }
    
    /** Returns true if this texture unit is either a series of 6 2D textures, each
            in it's own frame, or is a full 3D cube map. You can tell which by checking
            getTextureType.
        @note
            Applies to both fixed-function and programmable pipeline.
        */
    bool isCubic()
    {
        return mCubic;
    }
    
    /** Returns true if this texture layer uses a composite 3D cubic texture.
        @note
            Applies to both fixed-function and programmable pipeline.
        */
    bool is3D()
    {
        return mTextureType == TextureType.TEX_TYPE_CUBE_MAP;
    }
    
    /** Returns the type of this texture.
        @note
            Applies to both fixed-function and programmable pipeline.
        */
    TextureType getTextureType()
    {
        return mTextureType;
        
    }
    
    /** Sets the desired pixel format when load the texture.
        */
    void setDesiredFormat(PixelFormat desiredFormat)
    {
        mDesiredFormat = desiredFormat;
    }
    
    /** Gets the desired pixel format when load the texture.
        */
    PixelFormat getDesiredFormat()
    {
        return mDesiredFormat;
    }
    
    /** Sets how many mipmaps have been requested for the texture.
        */
    void setNumMipmaps(int numMipmaps)
    {
        mTextureSrcMipmaps = numMipmaps;
    }
    
    /** Gets how many mipmaps have been requested for the texture.
        */
    int getNumMipmaps()
    {
        return mTextureSrcMipmaps;
    }
    
    /** Sets whether this texture is requested to be loaded as alpha if single channel
        */
    void setIsAlpha(bool isAlpha)
    {
        mIsAlpha = isAlpha;
    }
    
    /** Gets whether this texture is requested to be loaded as alpha if single channel
        */
    bool getIsAlpha()
    {
        return mIsAlpha;
    }
    
    /// @copydoc Texture.getGamma
    Real getGamma() const { return mGamma; }
    /// @copydoc Texture.setGamma
    void setGamma(Real gamma) { mGamma = gamma; }
    
    /// @copydoc Texture.setHardwareGammaEnabled
    void setHardwareGammaEnabled(bool enabled)
    {
        mHwGamma = enabled;
    }
    
    /// @copydoc Texture.isHardwareGammaEnabled
    bool isHardwareGammaEnabled()
    {
        return mHwGamma;
    }
    
    /** Gets the index of the set of texture co-ords this layer uses.
        @note
            Only applies to the fixed function pipeline and has no effect if a fragment program is used.
        */
    uint getTextureCoordSet()
    {
        return mTextureCoordSetIndex;
    }
    
    /** Sets the index of the set of texture co-ords this layer uses.
        @note
            Default is 0 for all layers. Only change this if you have provided multiple texture co-ords per
            vertex.
        @note
            Only applies to the fixed function pipeline and has no effect if a fragment program is used.
        */
    void setTextureCoordSet(uint set)
    {
        mTextureCoordSetIndex = set;
    }
    
    /** Sets a matrix used to transform any texture coordinates on this layer.
        @remarks
            Texture coordinates can be modified on a texture layer to create effects like scrolling
            textures. A texture transform can either be applied to a layer which takes the source coordinates
            from a fixed set in the geometry, or to one which generates them dynamically (e.g. environment mapping).
        @par
            It's obviously a bit impractical to create scrolling effects by calling this method manually since you
            would have to call it every framw with a slight alteration each time, which is tedious. Instead
            you can use the ControllerManager class to create a Controller object which will manage the
            effect over time for you. See the ControllerManager.createTextureScroller and it's sibling methods for details.<BR>
            In addition, if you want to set the individual texture transformations rather than concatenating them
            yourself, use setTextureScroll, setTextureScale and setTextureRotate.
        @note
            Has no effect in the programmable pipeline.
        */
    void setTextureTransform(Matrix4 xform)
    {
        mTexModMatrix = xform;
        mRecalcTexMatrix = false;
    }
    
    /** Gets the current texture transformation matrix.
        @remarks
            Causes a reclaculation of the matrix if any parameters have been changed via
            setTextureScroll, setTextureScale and setTextureRotate.
        @note
            Has no effect in the programmable pipeline.
        */
    Matrix4 getTextureTransform()
    {
        if (mRecalcTexMatrix)
            recalcTextureMatrix();
        return mTexModMatrix;
        
    }
    
    /** Sets the translation offset of the texture, ie scrolls the texture.
        @remarks
            This method sets the translation element of the texture transformation, and is easier to use than setTextureTransform if
            you are combining translation, scaling and rotation in your texture transformation. Again if you want
            to animate these values you need to use a Controller
        @note
            Has no effect in the programmable pipeline.
        @param u
            The amount the texture should be moved horizontally (u direction).
        @param v
            The amount the texture should be moved vertically (v direction).
        @see
            ControllerManager, Controller
        */
    void setTextureScroll(Real u, Real v)
    {
        mUMod = u;
        mVMod = v;
        mRecalcTexMatrix = true;
    }
    
    /** As setTextureScroll, but sets only U value.
        @note
            Has no effect in the programmable pipeline.
        */
    void setTextureUScroll(Real value)
    {
        mUMod = value;
        mRecalcTexMatrix = true;
    }
    
    /// Get texture uscroll value.
    Real getTextureUScroll()
    {
        return mUMod;
    }
    
    /** As setTextureScroll, but sets only V value.
        @note
            Has no effect in the programmable pipeline.
        */
    void setTextureVScroll(Real value)
    {
        mVMod = value;
        mRecalcTexMatrix = true;
    }
    /// Get texture vscroll value.
    Real getTextureVScroll()
    {
        return mVMod;
    }
    
    /** As setTextureScale, but sets only U value.
        @note
            Has no effect in the programmable pipeline.
        */
    void setTextureUScale(Real value)
    {
        mUScale = value;
        mRecalcTexMatrix = true;
    }
    
    /// Get texture uscale value.
    Real getTextureUScale()
    {
        return mUScale;
    }
    
    /** As setTextureScale, but sets only V value.
        @note
            Has no effect in the programmable pipeline.
        */
    void setTextureVScale(Real value)
    {
        mVScale = value;
        mRecalcTexMatrix = true;
    }
    
    /// Get texture vscale value.
    Real getTextureVScale()
    {
        return mVScale;
    }
    
    /** Sets the scaling factor applied to texture coordinates.
        @remarks
            This method sets the scale element of the texture transformation, and is easier to use than
            setTextureTransform if you are combining translation, scaling and rotation in your texture transformation. Again if you want
            to animate these values you need to use a Controller (see ControllerManager and it's methods for
            more information).
        @note
            Has no effect in the programmable pipeline.
        @param uScale
            The value by which the texture is to be scaled horizontally.
        @param vScale
            The value by which the texture is to be scaled vertically.
        */
    void setTextureScale(Real uScale, Real vScale)
    {
        mUScale = uScale;
        mVScale = vScale;
        mRecalcTexMatrix = true;
    }
    
    /** Sets the anticlockwise rotation factor applied to texture coordinates.
        @remarks
            This sets a fixed rotation angle - if you wish to animate this, see the
            ControllerManager.createTextureRotater method.
        @note
            Has no effect in the programmable pipeline.
        @param angle
            The angle of rotation (anticlockwise).
        */
    void setTextureRotate(Radian angle)
    {
        mRotate = angle;
        mRecalcTexMatrix = true;
    }
    
    /// Get texture rotation effects angle value.
    Radian getTextureRotate()
    {
        return mRotate;
    }
    
    /** Gets the texture addressing mode for a given coordinate, 
            i.e. what happens at uv values above 1.0.
        @note
            The default is TAM_WRAP i.e. the texture repeats over values of 1.0.
        */
    UVWAddressingMode getTextureAddressingMode()
    {
        return mAddressMode;
    }
    
    /** Sets the texture addressing mode, i.e. what happens at uv values above 1.0.
        @note
            The default is TAM_WRAP i.e. the texture repeats over values of 1.0.
        @note This is a shortcut method which sets the addressing mode for all
            coordinates at once; you can also call the more specific method
            to set the addressing mode per coordinate.
        @note
            This is a shortcut method which sets the addressing mode for all
            coordinates at once; you can also call the more specific method
            to set the addressing mode per coordinate.
        @note
            This applies for both the fixed-function and programmable pipelines.
        */
    void setTextureAddressingMode( TextureAddressingMode tam)
    {
        mAddressMode.u = tam;
        mAddressMode.v = tam;
        mAddressMode.w = tam;
    }
    
    /** Sets the texture addressing mode, i.e. what happens at uv values above 1.0.
        @note
            The default is TAM_WRAP i.e. the texture repeats over values of 1.0.
        @note
            This applies for both the fixed-function and programmable pipelines.
        */
    void setTextureAddressingMode( TextureAddressingMode u, 
                                  TextureAddressingMode v, TextureAddressingMode w)
    {
        mAddressMode.u = u;
        mAddressMode.v = v;
        mAddressMode.w = w;
    }
    
    /** Sets the texture addressing mode, i.e. what happens at uv values above 1.0.
        @note
            The default is TAM_WRAP i.e. the texture repeats over values of 1.0.
        @note
            This applies for both the fixed-function and programmable pipelines.
        */
    void setTextureAddressingMode( UVWAddressingMode uvw)
    {
        mAddressMode = uvw;
    }
    
    /** Sets the texture border colour.
        @note
            The default is ColourValue.Black, and this value only used when addressing mode
            is TAM_BORDER.
        @note
            This applies for both the fixed-function and programmable pipelines.
        */
    void setTextureBorderColour(ColourValue colour)
    {
        mBorderColour = colour;
    }
    
    /** Sets the texture border colour.
        @note
            The default is ColourValue.Black, and this value only used when addressing mode
            is TAM_BORDER.
        */
   ColourValue getTextureBorderColour()
    {
        return mBorderColour;
    }
    
    /** Setting advanced blending options.
        @remarks
            This is an extended version of the TextureUnitState.setColourOperation method which allows
            extremely detailed control over the blending applied between this and earlier layers.
            See the IMPORTANT note below about the issues between mulitpass and multitexturing that
            using this method can create.
        @par
            Texture colour operations determine how the final colour of the surface appears when
            rendered. Texture units are used to combine colour values from various sources (ie. the
            diffuse colour of the surface from lighting calculations, combined with the colour of
            the texture). This method allows you to specify the 'operation' to be used, ie. the
            calculation such as adds or multiplies, and which values to use as arguments, such as
            a fixed value or a value from a previous calculation.
        @par
            The defaults for each layer are:
            <ul>
            <li>op = LBX_MODULATE</li>
            <li>source1 = LayerBlendSource.LBS_TEXTURE</li>
            <li>source2 = LayerBlendSource.LBS_CURRENT</li>
            </ul>
            ie. each layer takes the colour results of the previous layer, and multiplies them
            with the new texture being applied. Bear in mind that colours are RGB values from
            0.0 - 1.0 so multiplying them together will result in values in the same range,
            'tinted' by the multiply. Note however that a straight multiply normally has the
            effect of darkening the textures - for this reason there are brightening operations
            like LBO_MODULATE_X2. See the LayerBlendOperation and LayerBlendSource enumerated
            types for full details.
        @note
            Because of the limitations on some underlying APIs (Direct3D included)
            the LayerBlendSource.LBS_TEXTURE argument can only be used as the first argument, not the second.
        @par
            The final 3 parameters are only required if you decide to pass values manually
            into the operation, i.e. you want one or more of the inputs to the colour calculation
            to come from a fixed value that you supply. Hence you only need to fill these in if
            you supply LayerBlendSource.LBS_MANUAL to the corresponding source, or use the LBX_BLEND_MANUAL
            operation.
        @warning
            Ogre tries to use multitexturing hardware to blend texture layers
            together. However, if it runs out of texturing units (e.g. 2 of a GeForce2, 4 on a
            GeForce3) it has to fall back on multipass rendering, i.e. rendering the same object
            multiple times with different textures. This is both less efficient and there is a smaller
            range of blending operations which can be performed. For this reason, if you use this method
            you MUST also call TextureUnitState.setColourOpMultipassFallback to specify which effect you
            want to fall back on if sufficient hardware is not available.
        @note
            This has no effect in the programmable pipeline.
        @par
            If you wish to avoid having to do this, use the simpler TextureUnitState.setColourOperation method
            which allows less flexible blending options but sets up the multipass fallback automatically,
            since it only allows operations which have direct multipass equivalents.
        @param op
            The operation to be used, e.g. modulate (multiply), add, subtract.
        @param source1
            The source of the first colour to the operation e.g. texture colour.
        @param source2
            The source of the second colour to the operation e.g. current surface colour.
        @param arg1
            Manually supplied colour value (only required if source1 = LayerBlendSource.LBS_MANUAL).
        @param arg2
            Manually supplied colour value (only required if source2 = LayerBlendSource.LBS_MANUAL).
        @param manualBlend
            Manually supplied 'blend' value - only required for operations
            which require manual blend e.g. LBX_BLEND_MANUAL.
        */
    void setColourOperationEx(
        LayerBlendOperationEx op,
        LayerBlendSource source1 = LayerBlendSource.LBS_TEXTURE,
        LayerBlendSource source2 = LayerBlendSource.LBS_CURRENT,
        
        ColourValue arg1 = ColourValue.White,
        ColourValue arg2 = ColourValue.White,
        
        Real manualBlend = 0.0)
    {
        mColourBlendMode.operation = op;
        mColourBlendMode.source1 = source1;
        mColourBlendMode.source2 = source2;
        mColourBlendMode.colourArg1 = arg1;
        mColourBlendMode.colourArg2 = arg2;
        mColourBlendMode.factor = manualBlend;
    }
    
    /** Determines how this texture layer is combined with the one below it (or the diffuse colour of
            the geometry if this is layer 0).
        @remarks
            This method is the simplest way to blend tetxure layers, because it requires only one parameter,
            gives you the most common blending types, and automatically sets up 2 blending methods: one for
            if single-pass multitexturing hardware is available, and another for if it is not and the blending must
            be achieved through multiple rendering passes. It is, however, quite limited and does not expose
            the more flexible multitexturing operations, simply because these can't be automatically supported in
            multipass fallback mode. If want to use the fancier options, use TextureUnitState.setColourOperationEx,
            but you'll either have to be sure that enough multitexturing units will be available, or you should
            explicitly set a fallback using TextureUnitState.setColourOpMultipassFallback.
        @note
            The default method is LBO_MODULATE for all layers.
        @note
            This option has no effect in the programmable pipeline.
        @param op
            One of the LayerBlendOperation enumerated blending types.
        */
    void setColourOperation(LayerBlendOperation op)
    {
        // Set up the multitexture and multipass blending operations
        final switch (op)
        {
            case LayerBlendOperation.LBO_REPLACE:
                setColourOperationEx(LayerBlendOperationEx.LBX_SOURCE1, LayerBlendSource.LBS_TEXTURE, LayerBlendSource.LBS_CURRENT);
                setColourOpMultipassFallback(SceneBlendFactor.SBF_ONE, SceneBlendFactor.SBF_ZERO);
                break;
            case LayerBlendOperation.LBO_ADD:
                setColourOperationEx(LayerBlendOperationEx.LBX_ADD, LayerBlendSource.LBS_TEXTURE, LayerBlendSource.LBS_CURRENT);
                setColourOpMultipassFallback(SceneBlendFactor.SBF_ONE, SceneBlendFactor.SBF_ONE);
                break;
            case LayerBlendOperation.LBO_MODULATE:
                setColourOperationEx(LayerBlendOperationEx.LBX_MODULATE, LayerBlendSource.LBS_TEXTURE, LayerBlendSource.LBS_CURRENT);
                setColourOpMultipassFallback(SceneBlendFactor.SBF_DEST_COLOUR, SceneBlendFactor.SBF_ZERO);
                break;
            case LayerBlendOperation.LBO_ALPHA_BLEND:
                setColourOperationEx(LayerBlendOperationEx.LBX_BLEND_TEXTURE_ALPHA, LayerBlendSource.LBS_TEXTURE, LayerBlendSource.LBS_CURRENT);
                setColourOpMultipassFallback(SceneBlendFactor.SBF_SOURCE_ALPHA, SceneBlendFactor.SBF_ONE_MINUS_SOURCE_ALPHA);
                break;
        }
        
        
    }
    
    /** Sets the multipass fallback operation for this layer, if you used TextureUnitState.setColourOperationEx
            and not enough multitexturing hardware is available.
        @remarks
            Because some effects exposed using TextureUnitState.setColourOperationEx are only supported under
            multitexturing hardware, if the hardware is lacking the system must fallback on multipass rendering,
            which unfortunately doesn't support as many effects. This method is for you to specify the fallback
            operation which most suits you.
        @par
            You'll notice that the interface is the same as the Material.setSceneBlending method; this is
            because multipass rendering IS effectively scene blending, since each layer is rendered on top
            of the last using the same mechanism as making an object transparent, it's just being rendered
            in the same place repeatedly to get the multitexture effect.
        @par
            If you use the simpler (and hence less flexible) TextureUnitState.setColourOperation method you
            don't need to call this as the system sets up the fallback for you.
        @note
            This option has no effect in the programmable pipeline, because there is no multipass fallback
            and multitexture blending is handled by the fragment shader.
        */
    void setColourOpMultipassFallback(SceneBlendFactor sourceFactor,SceneBlendFactor destFactor)
    {
        mColourBlendFallbackSrc = sourceFactor;
        mColourBlendFallbackDest = destFactor;
    }
    
    /** Get multitexturing colour blending mode.
        */
    LayerBlendModeEx getColourBlendMode()
    {
        return mColourBlendMode;
    }
    
    /** Get multitexturing alpha blending mode.
        */
    LayerBlendModeEx getAlphaBlendMode()
    {
        return mAlphaBlendMode;
    }
    
    /** Get the multipass fallback for colour blending operation source factor.
        */
    SceneBlendFactor getColourBlendFallbackSrc()
    {
        return mColourBlendFallbackSrc;
    }
    
    /** Get the multipass fallback for colour blending operation destination factor.
        */
    SceneBlendFactor getColourBlendFallbackDest()
    {
        return mColourBlendFallbackDest;
    }
    
    /** Sets the alpha operation to be applied to this texture.
        @remarks
            This works in exactly the same way as setColourOperation, except
            that the effect is applied to the level of alpha (i.e. transparency)
            of the texture rather than its colour. When the alpha of a texel (a pixel
            on a texture) is 1.0, it is opaque, whereas it is fully transparent if the
            alpha is 0.0. Please refer to the setColourOperation method for more info.
        @param op
            The operation to be used, e.g. modulate (multiply), add, subtract
        @param source1
            The source of the first alpha value to the operation e.g. texture alpha
        @param source2
            The source of the second alpha value to the operation e.g. current surface alpha
        @param arg1
            Manually supplied alpha value (only required if source1 = LayerBlendSource.LBS_MANUAL)
        @param arg2
            Manually supplied alpha value (only required if source2 = LayerBlendSource.LBS_MANUAL)
        @param manualBlend
            Manually supplied 'blend' value - only required for operations
            which require manual blend e.g. LBX_BLEND_MANUAL
        @see
            setColourOperation
        @note
            This option has no effect in the programmable pipeline.
        */
    void setAlphaOperation(LayerBlendOperationEx op,
                           LayerBlendSource source1 = LayerBlendSource.LBS_TEXTURE,
                           LayerBlendSource source2 = LayerBlendSource.LBS_CURRENT,
                           Real arg1 = 1.0,
                           Real arg2 = 1.0,
                           Real manualBlend = 0.0)
    {
        mAlphaBlendMode.operation = op;
        mAlphaBlendMode.source1 = source1;
        mAlphaBlendMode.source2 = source2;
        mAlphaBlendMode.alphaArg1 = arg1;
        mAlphaBlendMode.alphaArg2 = arg2;
        mAlphaBlendMode.factor = manualBlend;
    }
    
    /** Generic method for setting up texture effects.
        @remarks
            Allows you to specify effects directly by using the TextureEffectType enumeration. The
            arguments that go with it depend on the effect type. Only one effect of
            each type can be applied to a texture layer.
        @par
            This method is used internally by Ogre but it is better generally for applications to use the
            more intuitive specialised methods such as setEnvironmentMap and setScroll.
        @note
            This option has no effect in the programmable pipeline.
        */
    void addEffect(TextureEffect effect)
    {
        // Ensure controller pointer is null
        effect.controller = null;
        
        if (effect.type == TextureEffectType.ET_ENVIRONMENT_MAP 
            || effect.type == TextureEffectType.ET_UVSCROLL
            || effect.type == TextureEffectType.ET_USCROLL
            || effect.type == TextureEffectType.ET_VSCROLL
            || effect.type == TextureEffectType.ET_ROTATE
            || effect.type == TextureEffectType.ET_PROJECTIVE_TEXTURE)
        {
            //FIXME Replace - must be unique --- Ehhhh? Then why multimap up inhere?
            // Search for existing effect of this type
            //auto i = effect.type in mEffects;
            //if (i !is null)
            if((effect.type in mEffects) !is null && mEffects[effect.type].length)
            {
                auto i = mEffects[effect.type][0];
                // Destroy old effect controller if exist
                if (i.controller)
                {
                    ControllerManager.getSingleton().destroyController(i.controller);
                }
                
                //mEffects.remove(effect.type);
                mEffects[effect.type].clear();
            }
        }
        
        if (isLoaded())
        {
            // Create controller
            createEffectController(effect);
        }
        
        // Record new effect
        //mEffects[effect.type] = effect;
        mEffects.initAA(effect.type);
        mEffects[effect.type].insert(effect);
        
    }
    
    /** Turns on/off texture coordinate effect that makes this layer an environment map.
        @remarks
            Environment maps make an object look reflective by using the object's vertex normals relative
            to the camera view to generate texture coordinates.
        @par
            The vectors generated can either be used to address a single 2D texture which
            is a 'fish-eye' lens view of a scene, or a 3D cubic environment map which requires 6 textures
            for each side of the inside of a cube. The type depends on what texture you set up - if you use the
            setTextureName method then a 2D fisheye lens texture is required, whereas if you used setCubicTextureName
            then a cubic environment map will be used.
        @par
            This effect works best if the object has lots of gradually changing normals. The texture also
            has to be designed for this effect - see the example spheremap.png included with the sample
            application for a 2D environment map; a cubic map can be generated by rendering 6 views of a
            scene to each of the cube faces with orthogonal views.
        @note
            Enabling this disables any other texture coordinate generation effects.
            However it can be combined with texture coordinate modification functions, which then operate on the
            generated coordinates rather than static model texture coordinates.
        @param enable
            True to enable, false to disable
        @param planar
            If set to @c true, instead of being based on normals the environment effect is based on
            vertex positions. This is good for planar surfaces.
        @note
            This option has no effect in the programmable pipeline.
        */
    void setEnvironmentMap(bool enable, EnvMapType envMapType = EnvMapType.ENV_CURVED)
    {
        if (enable)
        {
            TextureEffect eff = new TextureEffect;
            eff.type = TextureEffectType.ET_ENVIRONMENT_MAP;
            
            eff.subtype = envMapType;
            addEffect(eff);
        }
        else
        {
            removeEffect(TextureEffectType.ET_ENVIRONMENT_MAP);
        }
    }
    
    /** Sets up an animated scroll for the texture layer.
        @note
            Useful for creating constant scrolling effects on a texture layer (for varying scrolls, see setTransformAnimation).
        @param uSpeed
            The number of horizontal loops per second (+ve=moving right, -ve = moving left).
        @param vSpeed
            The number of vertical loops per second (+ve=moving up, -ve= moving down).
        @note
            This option has no effect in the programmable pipeline.
        */
    void setScrollAnimation(Real uSpeed, Real vSpeed)
    {
        // Remove existing effects
        removeEffect(TextureEffectType.ET_UVSCROLL);
        removeEffect(TextureEffectType.ET_USCROLL);
        removeEffect(TextureEffectType.ET_VSCROLL);
        
        // don't create an effect if the speeds are both 0
        if(uSpeed == 0.0f && vSpeed == 0.0f) 
        {
            return;
        }
        
        // Create new effect
        TextureEffect eff = new TextureEffect;
        if(uSpeed == vSpeed) 
        {
            eff.type = TextureEffectType.ET_UVSCROLL;
            eff.arg1 = uSpeed;
            addEffect(eff);
        }
        else
        {
            if(uSpeed)
            {
                eff.type = TextureEffectType.ET_USCROLL;
                eff.arg1 = uSpeed;
                addEffect(eff);
            }
            if(vSpeed)
            {
                eff.type = TextureEffectType.ET_VSCROLL;
                eff.arg1 = vSpeed;
                addEffect(eff);
            }
        }
    }
    
    /** Sets up an animated texture rotation for this layer.
        @note
            Useful for constant rotations (for varying rotations, see setTransformAnimation).
        @param speed
            The number of complete anticlockwise revolutions per second (use -ve for clockwise)
        @note
            This option has no effect in the programmable pipeline.
        */
    void setRotateAnimation(Real speed)
    {
        // Remove existing effect
        removeEffect(TextureEffectType.ET_ROTATE);
        // don't create an effect if the speed is 0
        if(speed == 0.0f) 
        {
            return;
        }
        // Create new effect
        TextureEffect eff = new TextureEffect;
        eff.type = TextureEffectType.ET_ROTATE;
        eff.arg1 = speed;
        addEffect(eff);
    }
    
    /** Sets up a general time-relative texture modification effect.
        @note
            This can be called multiple times for different values of ttype, but only the latest effect
            applies if called multiple time for the same ttype.
        @param ttype
            The type of transform, either translate (scroll), scale (stretch) or rotate (spin).
        @param waveType
            The shape of the wave, see WaveformType enum for details.
        @param base
            The base value for the function (range of output = {base, base + amplitude}).
        @param frequency
            The speed of the wave in cycles per second.
        @param phase
            The offset of the start of the wave, e.g. 0.5 to start half-way through the wave.
        @param amplitude
            Scales the output so that instead of lying within 0..1 it lies within 0..1*amplitude for exaggerated effects.
        @note
            This option has no effect in the programmable pipeline.
        */
    void setTransformAnimation(TextureTransformType ttype,
                              WaveformType waveType, Real base = 0, Real frequency = 1, Real phase = 0, Real amplitude = 1 )
    {
        // Remove existing effect
        // note, only remove for subtype, not entire TextureEffectType.ET_TRANSFORM
        // otherwise we won't be able to combine subtypes
        // Get range of items matching this effect
        
        foreach (k,vs; mEffects)
        {
            foreach(v; vs)
            {
                if (v.type == TextureEffectType.ET_TRANSFORM && v.subtype == ttype)
                {
                    if (v.controller)
                    {
                        ControllerManager.getSingleton().destroyController(v.controller);
                    }
                    mEffects[k].removeFromArray(v);
                    
                    // should only be one, so jump out
                    break;
                }
            }
        }
        
        // don't create an effect if the given values are all 0
        if(base == 0.0f && phase == 0.0f && frequency == 0.0f && amplitude == 0.0f) 
        {
            return;
        }
        // Create new effect
        TextureEffect eff = new TextureEffect;
        eff.type = TextureEffectType.ET_TRANSFORM;
        eff.subtype = ttype;
        eff.waveType = waveType;
        eff.base = base;
        eff.frequency = frequency;
        eff.phase = phase;
        eff.amplitude = amplitude;
        addEffect(eff);
    }
    
    /** Enables or disables projective texturing on this texture unit.
        @remarks
            Projective texturing allows you to generate texture coordinates 
            based on a Frustum, which gives the impression that a texture is
            being projected onto the surface. Note that once you have called
            this method, the texture unit continues to monitor the Frustum you 
            passed in and the projection will change if you can alter it. It also
            means that you must ensure that the Frustum object you pass a pointer
            to remains in existence for as long as this TextureUnitState does.
        @par
            This effect cannot be combined with other texture generation effects, 
            such as environment mapping. It also has no effect on passes which 
            have a vertex program enabled - projective texturing has to be done
            in the vertex program instead.
        @param enabled
            Whether to enable / disable.
        @param projectionSettings
            The Frustum which will be used to derive the 
            projection parameters.
        */
    void setProjectiveTexturing(bool enabled,Frustum projectionSettings = null)
    {
        if (enabled)
        {
            TextureEffect eff = new TextureEffect;
            eff.type = TextureEffectType.ET_PROJECTIVE_TEXTURE;
            eff.frustum = projectionSettings;
            addEffect(eff);
        }
        else
        {
            removeEffect(TextureEffectType.ET_PROJECTIVE_TEXTURE);
        }
        
    }
    
    /** Removes all effects applied to this texture layer.
        */
    void removeAllEffects()
    {
        // Iterate over effects to remove controllers
        foreach (k, vs; mEffects)
        {
            foreach (v; vs)
            if (v.controller)
            {
                ControllerManager.getSingleton().destroyController(v.controller);
            }
        }
        
        mEffects.clear();
    }
    
    /** Removes a single effect applied to this texture layer.
        @note
            Because you can only have 1 effect of each type (e.g. 1 texture coordinate generation) applied
            to a layer, only the effect type is required.
        */
    void removeEffect(TextureEffectType type )
    {
        // Get range of items matching this effect
        //std.pair< EffectMap.iterator, EffectMap.iterator > remPair = 
        //    mEffects.equal_range( type );
        // Remove controllers
        if((type in mEffects) is null) return;
        foreach (v; mEffects[type])
        {
            if (v.controller)
            {
                ControllerManager.getSingleton().destroyController(v.controller);
            }
        }
        // Erase         
        mEffects.remove( type );
    }
    
    /** Determines if this texture layer is currently blank.
        @note
            This can happen if a texture fails to load or some other non-fatal error. Worth checking after
            setting texture name.
        */
    bool isBlank()
    {
        if (!mFrames.length)
            return true;
        else
            return mFrames[0] is null || !mFrames[0].length || mTextureLoadFailed;
    }
    
    /** Sets this texture layer to be blank.
        */
    void setBlank()
    {
        setTextureName("");
    }
    
    /** Tests if the texture associated with this unit has failed to load.
        */
    bool isTextureLoadFailing(){ return mTextureLoadFailed; }
    
    /** Tells the unit to retry loading the texture if it had failed to load.
        */
    void retryTextureLoad() { mTextureLoadFailed = false; }
    
    /// Get texture effects in a multimap paired array.
    EffectMap getEffects()
    {
        return mEffects;
    }
    
    /// Get the animated-texture animation duration.
    Real getAnimationDuration()
    {
        return mAnimDuration;
    }
    
    /** Set the texture filtering for this unit, using the simplified interface.
        @remarks
            You also have the option of specifying the minification, magnification
            and mip filter individually if you want more control over filtering
            options. See the alternative setTextureFiltering methods for details.
        @note
            This option applies in both the fixed function and the programmable pipeline.
        @param filterType
            The high-level filter type to use.
        */
    void setTextureFiltering(TextureFilterOptions filterType)
    {
        final switch (filterType)
        {
            case TextureFilterOptions.TFO_NONE:
                setTextureFiltering(FilterOptions.FO_POINT, FilterOptions.FO_POINT, FilterOptions.FO_NONE);
                break;
            case TextureFilterOptions.TFO_BILINEAR:
                setTextureFiltering(FilterOptions.FO_LINEAR, FilterOptions.FO_LINEAR, FilterOptions.FO_POINT);
                break;
            case TextureFilterOptions.TFO_TRILINEAR:
                setTextureFiltering(FilterOptions.FO_LINEAR, FilterOptions.FO_LINEAR, FilterOptions.FO_LINEAR);
                break;
            case TextureFilterOptions.TFO_ANISOTROPIC:
                setTextureFiltering(FilterOptions.FO_ANISOTROPIC, FilterOptions.FO_ANISOTROPIC, Root.getSingleton().getRenderSystem().hasAnisotropicMipMapFilter() ? FilterOptions.FO_ANISOTROPIC : FilterOptions.FO_LINEAR);
                break;
        }
        mIsDefaultFiltering = false;
    }
    /** Set a single filtering option on this texture unit. 
        @param ftype
            The filtering type to set.
        @param opts
            The filtering option to set.
        */
    void setTextureFiltering(FilterType ftype, FilterOptions fo)
    {
        final switch (ftype)
        {
            case FilterType.FT_MIN:
                mMinFilter = fo;
                break;
            case FilterType.FT_MAG:
                mMagFilter = fo;
                break;
            case FilterType.FT_MIP:
                mMipFilter = fo;
                break;
        }
        mIsDefaultFiltering = false;
    }
    /** Set a the detailed filtering options on this texture unit. 
        @param minFilter
            The filtering to use when reducing the size of the texture. 
            Can be FO_POINT, FO_LINEAR or FO_ANISOTROPIC.
        @param magFilter
            The filtering to use when increasing the size of the texture.
            Can be FO_POINT, FO_LINEAR or FO_ANISOTROPIC.
        @param mipFilter
            The filtering to use between mip levels.
            Can be FO_NONE (turns off mipmapping), FO_POINT or FO_LINEAR (trilinear filtering).
        */
    void setTextureFiltering(FilterOptions minFilter, FilterOptions magFilter, FilterOptions mipFilter)
    {
        mMinFilter = minFilter;
        mMagFilter = magFilter;
        mMipFilter = mipFilter;
        mIsDefaultFiltering = false;
    }
    /// Get the texture filtering for the given type.
    FilterOptions getTextureFiltering(FilterType ft)
    {
        
        final switch (ft)
        {
            case FilterType.FT_MIN:
                return mIsDefaultFiltering ? 
                    MaterialManager.getSingleton().getDefaultTextureFiltering(FilterType.FT_MIN) : mMinFilter;
            case FilterType.FT_MAG:
                return mIsDefaultFiltering ? 
                    MaterialManager.getSingleton().getDefaultTextureFiltering(FilterType.FT_MAG) : mMagFilter;
            case FilterType.FT_MIP:
                return mIsDefaultFiltering ? 
                    MaterialManager.getSingleton().getDefaultTextureFiltering(FilterType.FT_MIP) : mMipFilter;
        }
        // to keep compiler happy
        return mMinFilter;
    }
    
    void setTextureCompareEnabled(bool enabled)
    {
        mCompareEnabled=enabled;
    }
    bool getTextureCompareEnabled()
    {
        return mCompareEnabled;
    }
    
    void setTextureCompareFunction(CompareFunction func)
    {
        mCompareFunc=func;
    }
    CompareFunction getTextureCompareFunction()
    {
        return mCompareFunc;
    }
    
    /** Sets the anisotropy level to be used for this texture level.
        @param maxAniso
            The maximal anisotropy level, should be between 2 and the maximum
            supported by hardware (1 is the default, ie. no anisotrophy).
        @note
            This option applies in both the fixed function and the programmable pipeline.
        */
    void setTextureAnisotropy(uint maxAniso)
    {
        mMaxAniso = maxAniso;
        mIsDefaultAniso = false;
    }
    /// Get this layer texture anisotropy level.
    uint getTextureAnisotropy()
    {
        return mIsDefaultAniso? MaterialManager.getSingleton().getDefaultAnisotropy() : mMaxAniso;
    }
    
    
    /** Sets the bias value applied to the mipmap calculation.
        @remarks
            You can alter the mipmap calculation by biasing the result with a 
            single floating point value. After the mip level has been calculated,
            this bias value is added to the result to give the final mip level.
            Lower mip levels are larger (higher detail), so a negative bias will
            force the larger mip levels to be used, and a positive bias
            will cause smaller mip levels to be used. The bias values are in 
            mip levels, so a -1 bias will force mip levels one larger than by the
            default calculation.
        @param bias
            The bias value as described above, can be positive or negative.
        */
    void setTextureMipmapBias(float bias) { mMipmapBias = bias; }
    /** Gets the bias value applied to the mipmap calculation.
        @see TextureUnitState.setTextureMipmapBias
        */
    float getTextureMipmapBias(){ return mMipmapBias; }
    
    /** Set the compositor reference for this texture unit state.
        @remarks 
            Only valid when content type is compositor.
        @param compositorName
            The name of the compositor to reference.
        @param textureName
            The name of the texture to reference.
        @param mrtIndex
            The index of the wanted texture, if referencing an MRT.
        */
    void setCompositorReference(string compositorName,string textureName, size_t mrtIndex = 0)
    {  
        mCompositorRefName = compositorName; 
        mCompositorRefTexName = textureName; 
        mCompositorRefMrtIndex = mrtIndex; 
    }
    
    /** Gets the name of the compositor that this texture referneces. */
   string getReferencedCompositorName(){ return mCompositorRefName; }
    /** Gets the name of the texture in the compositor that this texture references. */
   string getReferencedTextureName(){ return mCompositorRefTexName; }
    /** Gets the MRT index of the texture in the compositor that this texture references. */ 
    size_t getReferencedMRTIndex(){ return mCompositorRefMrtIndex; }
    
    /// Gets the parent Pass object.
    Pass getParent(){ return mParent; }
    
    /** Internal method for preparing this object for load, as part of Material.prepare. */
    void _prepare()
    {
        // Unload first
        //_unload();
        
        // Load textures
        for (uint i = 0; i < mFrames.length; ++i)
        {
            ensurePrepared(i);
        }
    }
    /** Internal method for undoing the preparation this object as part of Material.unprepare. */
    void _unprepare()
    {
        // Unreference textures
        foreach (ti; mFramePtrs)
        {
            ti.setNull();
        }
    }
    /** Internal method for loading this object as part of Material.load. */
    void _load()
    {
        
        // Load textures
        for (uint i = 0; i < mFrames.length; ++i)
        {
            ensureLoaded(i);
        }
        // Animation controller
        if (mAnimDuration != 0)
        {
            createAnimController();
        }
        // Effect controllers
        foreach (k, its; mEffects)
        {
            foreach (it; its)
            createEffectController(it);
        }
        
    }
    /** Internal method for unloading this object as part of Material.unload. */
    void _unload()
    {
        // Destroy animation controller
        if (mAnimController)
        {
            ControllerManager.getSingleton().destroyController(mAnimController);
            mAnimController = null;
        }
        
        // Destroy effect controllers
        foreach (k, vs; mEffects)
        {
            foreach (v; vs)
            if (v.controller)
            {
                ControllerManager.getSingleton().destroyController(v.controller);
                v.controller = null;
            }
        }
        
        // Unreference but don't unload textures. may be used elsewhere
    
        foreach (ti; mFramePtrs)
        {
            ti.setNull();
        }
    }
    /// Returns whether this unit has texture coordinate generation that depends on the camera.
    bool hasViewRelativeTextureCoordinateGeneration()
    {
        // Right now this only returns true for reflection maps
        if((TextureEffectType.ET_ENVIRONMENT_MAP in mEffects) !is null)
        {
            //FIXME mEffects.getVal or just foreach (k,v)?
            foreach(i; mEffects[TextureEffectType.ET_ENVIRONMENT_MAP])
            {
                if (i.subtype == EnvMapType.ENV_REFLECTION)
                    return true;
            }
        }
        
        if ((TextureEffectType.ET_PROJECTIVE_TEXTURE in mEffects) !is null)
            return true;
        
        return false;
    }
    
    /// Is this loaded?
    bool isLoaded()
    {
        return mParent.isLoaded();
    }

    /** Tells the class that it needs recompilation. */
    void _notifyNeedsRecompile()
    {
        mParent._notifyNeedsRecompile();
    }
    
    /** Set the name of the Texture Unit State.
        @remarks
            The name of the Texture Unit State is optional.  Its useful in material scripts where a material could inherit
            from another material and only want to modify a particalar Texture Unit State.
        */
    void setName(string name)
    {
        mName = name;
        if (mTextureNameAlias.emptyAA())
            mTextureNameAlias = mName;
    }
    /// Get the name of the Texture Unit State.
   string getName(){ return mName; }
    
    /** Set the alias name used for texture frame names.
        @param name
            Can be any sequence of characters and does not have to be unique.
        */
    void setTextureNameAlias(string name)
    {
        mTextureNameAlias = name;
    }
    /** Gets the Texture Name Alias of the Texture Unit.
        */
   string getTextureNameAlias(){ return mTextureNameAlias;}
    
    /** Applies texture names to Texture Unit State with matching texture name aliases.
            If no matching aliases are found then the TUS state does not change.
        @remarks
            Cubic, 1d, 2d, and 3d textures are determined from current state of the Texture Unit.
            Assumes animated frames are sequentially numbered in the name.
            If matching texture aliases are found then true is returned.

        @param aliasList
            A map container of texture alias, texture name pairs.
        @param apply
            Set @c true to apply the texture aliases else just test to see if texture alias matches are found.
        @return
            True if matching texture aliases were found in the Texture Unit State.
        */
    bool applyTextureAliases(AliasTextureNamePairList aliasList,bool apply = true)
    {
        bool testResult = false;
        // if TUS has an alias see if its in the alias container
        if (!mTextureNameAlias.emptyAA())
        {
            auto aliasEntry = mTextureNameAlias in aliasList;
            
            if (aliasEntry !is null)
            {
                // match was found so change the texture name in mFrames
                testResult = true;
                
                if (apply)
                {
                    // currently assumes animated frames are sequentially numbered
                    // cubic, 1d, 2d, and 3d textures are determined from current TUS state
                    
                    // if cubic or 3D
                    if (mCubic)
                    {
                        setCubicTextureName(*aliasEntry, mTextureType == TextureType.TEX_TYPE_CUBE_MAP);
                    }
                    else
                    {
                        // if more than one frame then assume animated frames
                        if (mFrames.length > 1)
                            setAnimatedTextureName(*aliasEntry, 
                                                   cast(uint)(mFrames.length), mAnimDuration);
                        else
                            setTextureName(*aliasEntry, mTextureType);
                    }
                }
                
            }
        }
        
        return testResult;
    }
    
    /** Notify this object that its parent has changed. */
    void _notifyParent(Pass parent)
    {
        mParent = parent;
    }
    
    /** Get the texture pointer for the current frame. */
    SharedPtr!Texture _getTexturePtr()
    {
        return _getTexturePtr(mCurrentFrame);
    }
    /** Get the texture pointer for a given frame. */
    SharedPtr!Texture _getTexturePtr(size_t frame)
    {
        if (mContentType == ContentType.CONTENT_NAMED)
        {
            if (frame < mFrames.length && !mTextureLoadFailed)
            {
                ensureLoaded(frame);
                return mFramePtrs[frame];
            }
            else
            {
                // Silent fail with empty texture for internal method
                static SharedPtr!Texture nullTexPtr;
                return nullTexPtr;
            }
        }
        else
        {
            // Manually bound texture, no name or loading
            assert(frame < mFramePtrs.length);
            return mFramePtrs[frame];
        }
        
    }
    
    /** Set the texture pointer for the current frame (internal use only!). */
    void _setTexturePtr(SharedPtr!Texture texptr)
    {
        _setTexturePtr(texptr, mCurrentFrame);
    }
    /** Set the texture pointer for a given frame (internal use only!). */
    void _setTexturePtr(SharedPtr!Texture texptr, size_t frame)
    {
        assert(frame < mFramePtrs.length);
        mFramePtrs[frame] = texptr;
    }
    
    /** Gets the animation controller (as created because of setAnimatedTexture)
            if it exists.
        */
    Controller!Real _getAnimController(){ return mAnimController; }
    
    size_t calculateSize() //const
    {
        size_t memSize = 0;
        
        memSize += uint.sizeof * 3;
        memSize += int.sizeof;
        memSize += float.sizeof;
        memSize += Real.sizeof * 5;
        memSize += bool.sizeof * 8;
        memSize += size_t.sizeof;
        memSize += TextureType.sizeof;
        memSize += PixelFormat.sizeof;
        memSize += UVWAddressingMode.sizeof;
        memSize += ColourValue.sizeof;
        memSize += LayerBlendModeEx.sizeof * 2;
        memSize += SceneBlendFactor.sizeof * 2;
        memSize += Radian.sizeof;
        memSize += Matrix4.sizeof;
        memSize += FilterOptions.sizeof * 3;
        memSize += CompareFunction.sizeof;
        memSize += BindingType.sizeof;
        memSize += ContentType.sizeof;
        memSize += string.sizeof * 4;
        
        memSize += mFrames.length * string.sizeof;
        memSize += mFramePtrs.length * TexturePtr.sizeof;
        memSize += mEffects.length * TextureEffect.sizeof;
        
        return memSize;
    }
    
protected:
    // State
    /// The current animation frame.
    uint mCurrentFrame;
    
    /// Duration of animation in seconds.
    Real mAnimDuration;
    bool mCubic; /// Is this a series of 6 2D textures to make up a cube?
    
    TextureType mTextureType; 
    PixelFormat mDesiredFormat;
    int mTextureSrcMipmaps; /// Request number of mipmaps.
    
    uint mTextureCoordSetIndex;
    UVWAddressingMode mAddressMode;
    ColourValue mBorderColour;
    
    LayerBlendModeEx mColourBlendMode;
    SceneBlendFactor mColourBlendFallbackSrc;
    SceneBlendFactor mColourBlendFallbackDest;
    
    LayerBlendModeEx mAlphaBlendMode;
    //mutable 
    bool mTextureLoadFailed;
    bool mIsAlpha;
    bool mHwGamma;
    Real mGamma;
    
    //mutable 
    bool mRecalcTexMatrix;
    Real mUMod, mVMod;
    Real mUScale, mVScale;
    Radian mRotate;
    //mutable 
    Matrix4 mTexModMatrix;
    
    /// Texture filtering - minification.
    FilterOptions mMinFilter;
    /// Texture filtering - magnification.
    FilterOptions mMagFilter;
    /// Texture filtering - mipmapping.
    FilterOptions mMipFilter;
    
    bool            mCompareEnabled;
    CompareFunction mCompareFunc;
    
    /// Texture anisotropy.
    uint mMaxAniso;
    /// Mipmap bias (always float, not Real).
    float mMipmapBias;
    
    bool mIsDefaultAniso;
    bool mIsDefaultFiltering;
    /// Binding type (fragment or vertex pipeline).
    BindingType mBindingType;
    /// Content type of texture (normal loaded texture, auto-texture).
    ContentType mContentType;
    /// The index of the referenced texture if referencing an MRT in a compositor.
    size_t mCompositorRefMrtIndex;
    
    //-----------------------------------------------------------------------------
    // Complex members (those that can't be copied using memcpy) are at the end to 
    // allow for fast copying of the basic members.
    //
    //vector<String>.type mFrames;
    //mutable vector<SharedPtr!Texture>.type mFramePtrs;
    string[] mFrames;
    SharedPtr!Texture[] mFramePtrs;
    
    string mName;               ///< Optional name for the TUS.
    string mTextureNameAlias;   ///< Optional alias for texture frames.
    EffectMap mEffects;
    /// The data that references the compositor.
    string mCompositorRefName;
    string mCompositorRefTexName;
    //-----------------------------------------------------------------------------
    
    //-----------------------------------------------------------------------------
    // Pointer members (those that can't be copied using memcpy), and MUST
    // preserving even if assign from others
    //
    Pass mParent;
    Controller!Real mAnimController;
    //-----------------------------------------------------------------------------
    
    
    /** Internal method for calculating texture matrix.
        */
    void recalcTextureMatrix()
    {
        // Assumption: 2D texture coords
        Matrix4 xform = Matrix4.IDENTITY;
        
        if (mUScale != 1 || mVScale != 1)
        {
            // Offset to center of texture
            xform[0, 0] = 1/mUScale;
            xform[1, 1] = 1/mVScale;
            // Skip matrix concat since first matrix update
            xform[0, 3] = (-0.5f * xform[0][0]) + 0.5f;
            xform[1, 3] = (-0.5f * xform[1][1]) + 0.5f;
        }
        
        if (mUMod || mVMod)
        {
            Matrix4 xlate = Matrix4.IDENTITY;
            
            xlate[0, 3] = mUMod;
            xlate[1, 3] = mVMod;
            
            xform = xlate * xform;
        }
        
        if (mRotate != Radian(0))
        {
            Matrix4 rot = Matrix4.IDENTITY;
            Radian theta = mRotate; //Radian( mRotate );
            Real cosTheta = Math.Cos(theta);
            Real sinTheta = Math.Sin(theta);
            
            rot[0, 0] = cosTheta;
            rot[0, 1] = -sinTheta;
            rot[1, 0] = sinTheta;
            rot[1, 1] = cosTheta;
            // Offset center of rotation to center of texture
            rot[0, 3] = 0.5f + ( (-0.5f * cosTheta) - (-0.5f * sinTheta) );
            rot[1, 3] = 0.5f + ( (-0.5f * sinTheta) + (-0.5f * cosTheta) );
            
            xform = rot * xform;
        }
        
        mTexModMatrix = xform;
        mRecalcTexMatrix = false;
        
    }
    
    /** Internal method for creating animation controller.
        */
    void createAnimController()
    {
        if (mAnimController)
        {
            ControllerManager.getSingleton().destroyController(mAnimController);
            mAnimController = null;
        }
        mAnimController = ControllerManager.getSingleton().createTextureAnimator(this, mAnimDuration);
        
    }
    
    /** Internal method for creating texture effect controller.
     */
    void createEffectController(TextureEffect effect)
    {
        if (effect.controller)
        {
            ControllerManager.getSingleton().destroyController(effect.controller);
            effect.controller = null;
        }
        
        ControllerManager cMgr = ControllerManager.getSingleton();
        switch (effect.type)
        {
            case TextureEffectType.ET_UVSCROLL:
                effect.controller = cMgr.createTextureUVScroller(this, effect.arg1);
                break;
            case TextureEffectType.ET_USCROLL:
                effect.controller = cMgr.createTextureUScroller(this, effect.arg1);
                break;
            case TextureEffectType.ET_VSCROLL:
                effect.controller = cMgr.createTextureVScroller(this, effect.arg1);
                break;
            case TextureEffectType.ET_ROTATE:
                effect.controller = cMgr.createTextureRotater(this, effect.arg1);
                break;
            case TextureEffectType.ET_TRANSFORM:
                effect.controller = cMgr.createTextureWaveTransformer(this, cast(TextureUnitState.TextureTransformType)effect.subtype, effect.waveType, effect.base,
                                                                      effect.frequency, effect.phase, effect.amplitude);
                break;
            case TextureEffectType.ET_ENVIRONMENT_MAP:
                break;
            default:
                break;
        }
    }
    
    /** Internal method for ensuring the texture for a given frame is prepared. */
    void ensurePrepared(size_t frame)
    {
        if (!mFrames[frame].emptyAA() && !mTextureLoadFailed)
        {
            // Ensure texture is loaded, specified number of mipmaps and
            // priority
            if (mFramePtrs[frame].isNull())
            {
                try {
                    mFramePtrs[frame] = 
                        TextureManager.getSingleton().prepare(mFrames[frame], 
                                                               mParent.getResourceGroup(), mTextureType, 
                                                               mTextureSrcMipmaps, mGamma, mIsAlpha, mDesiredFormat, mHwGamma);
                }
                catch (Exception e) {
                    string msg = "Error loading texture " ~ std.conv.to!string(mFrames[frame])  ~
                        ". Texture layer will be blank. Loading the texture " ~
                            "failed with the following exception: " ~ e.msg;
                            
                    LogManager.getSingleton().logMessage(msg);
                    mTextureLoadFailed = true;
                }
            }
            else
            {
                // Just ensure existing pointer is prepared
                mFramePtrs[frame].getAs().prepare();
            }
        }
    }
    
    /** Internal method for ensuring the texture for a given frame is loaded. */
    void ensureLoaded(size_t frame)
    {
        if (!mFrames[frame].empty() && !mTextureLoadFailed)
        {
            // Ensure texture is loaded, specified number of mipmaps and
            // priority
            if (mFramePtrs[frame].isNull())
            {
                try {
                    mFramePtrs[frame] = 
                        TextureManager.getSingleton().load(mFrames[frame], 
                                                            mParent.getResourceGroup(), mTextureType, 
                                                            mTextureSrcMipmaps, mGamma, mIsAlpha, mDesiredFormat, mHwGamma);
                }
                catch (Exception e) {
                    string msg =  "Error loading texture " ~ std.conv.to!string(mFrames[frame]) ~
                        ". Texture layer will be blank. Loading the texture " ~
                            "failed with the following exception: " ~ e.msg;
                    LogManager.getSingleton().logMessage(msg);
                    mTextureLoadFailed = true;
                }   
            }
            else
            {
                // Just ensure existing pointer is loaded
                mFramePtrs[frame].get().load();
            }
        }
    }
    
    
}
/** @} */
/** @} */